import SwiftUI
import TimbreCore

/// A lesson, full screen: progress bar on top, one step at a time, results at the end. A song opens on its song
/// sheet (`SongOpener`) and ends on a full performance over the band (`SongPerformStep`, or `SongEncoreStep` for a
/// song that ends on its chords), with a finale and a poster before the results. From the sheet of a whole
/// arrangement, "Practice this part" plays one section along on its own (`SongArrangement.practice`, on the
/// play-along's own runway at the loop's speed), then goes back to the sheet; it counts toward nothing.
///
/// Lessons zoom open out of the card that was tapped (Learn's path, the Songs shelves). Until that presentation has
/// landed (`ArrivalProbe`), nothing on screen animates: an entrance started inside the zoom could be cut off with
/// the view left part-way (bug 64, a song's first step stuck at about 30 % opacity), so the first screen is simply
/// there and the zoom is its entrance.
struct LessonPlayer: View {
    let course: LearnCourse
    let lesson: Lesson
    var onNext: ((Lesson) -> Void)?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var run: LessonRun
    @State private var result: LessonResult?
    @State private var improved = false
    @State private var reward: ProgressUpdate?
    @State private var confirmQuit = false
    @State private var tuneChecked = false
    /// A rhythm step was passed by tapping because the microphone couldn't hear the instrument.
    @State private var practiced = false
    /// A song shows its song sheet before its first step.
    @State private var opening: Bool
    /// The presentation that brought the lesson in has finished.
    @State private var arrived = false
    /// A part of the song picked on its sheet, being played along on its own.
    @State private var part: PartTake?
    /// The part last practised: the sheet picks it again on the way back.
    @State private var lastPart: SongSheet.Loop?

    /// A section of the song set up to play along with on its own: the loop picked on the sheet and its notes.
    private struct PartTake: Equatable {
        let loop: SongSheet.Loop
        let plan: SongArrangement.Practice
    }

    init(course: LearnCourse, lesson: Lesson, onNext: ((Lesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.onNext = onNext
        _run = State(initialValue: LessonRun(lesson: lesson))
        _opening = State(initialValue: lesson.kind == .song)
        #if DEBUG
        // A store scene (Root/DemoScenes.swift) opens on the step it shows, the tune check already done.
        if let start = DemoScene.lessonStart(lesson) {
            _run = State(initialValue: start)
            _tuneChecked = State(initialValue: true)
            _opening = State(initialValue: false)
        }
        #endif
    }

    private var accent: Color { Palette.accent(course.accent) }

    var body: some View {
        ZStack {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 520).ignoresSafeArea()
            if let result {
                LessonResults(course: course, lesson: lesson, result: result, improved: improved, reward: reward, accent: accent, practice: practiced,
                              next: nextLesson, onContinue: { dismiss() }, onNext: { next in dismiss(); onNext?(next) })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 0) {
                    topBar
                    StringOrderTipSlot(step: opening ? nil : run.step, course: course)  // "String 1 = thinnest, on top", once (Tips/TimbreTips.swift)
                    stage
                }
                // Inside the zoom that brings the lesson in, changes land without animating (see the type's note).
                .transaction { transaction in
                    guard !arrived else { return }
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }
        .background { ArrivalProbe { arrived = true } }
        .task {
            // Should the presentation never report (no coordinator to ask), the lesson counts as arrived anyway.
            try? await Task.sleep(for: .seconds(1.2))
            arrived = true
        }
        .adaptiveAnimation(Motion.page, value: run.index)
        .animation(Motion.reveal, value: result != nil)
        .preferredColorScheme(.dark)
        // "Hear it", chords and listen steps sound like the course's instrument (theory, ear, rhythm: the selected one).
        .onAppear { store.audio.courseVoice = InstrumentVoice(instrumentId: course.instrument) }
        .onDisappear { store.audio.courseVoice = nil }
        .confirmationDialog("Leave this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("Your progress in this lesson won’t be saved.") }
        .onAppear { LiveActivityController.shared.lessonOpened(lesson.id, title: lesson.title.localized, symbol: course.symbol) }
        .onDisappear {
            store.stopLessonListening()
            // Only a lesson's own click stops with it: the Metronome tool's (left running when the lesson opened, and
            // never restarted by a take) keeps going.
            if store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
            LiveActivityController.shared.lessonClosed(lesson.id)
        }
        .statusBarHidden(result == nil)
        // The zoom-in from the Learn tab can be pulled back down; not halfway through (the close button asks first),
        // nor while a part of the song is being practised.
        .interactiveDismissDisabled((run.index > 0 || part != nil) && result == nil)
    }

    private var nextLesson: Lesson? {
        let all = course.lessons
        guard let i = all.firstIndex(where: { $0.id == lesson.id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    /// Under the bar: a song's sheet (or a part of it being practised), the tune check before the first step that
    /// listens, or the step.
    @ViewBuilder private var stage: some View {
        if opening, let part {
            partStage(part)
                .transition(slide(in: .trailing, out: .trailing))
        } else if opening {
            SongOpener(lesson: lesson, course: course, accent: accent, arrived: arrived,
                       start: { withMotion(Motion.page, reduceMotion: reduceMotion) { opening = false } },
                       practice: practiceAction, returning: lastPart)
            .transition(.adaptive(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)),
                                  reduceMotion: reduceMotion))
        } else if let step = run.step, step.usesMicrophone, !tuneChecked, TuneCheckStep.needed(for: course) {
            TuneCheckStep(course: course, accent: accent) { withAnimation { tuneChecked = true } }
                .transition(.opacity)
        } else if let step = run.step {
            stepView(step)
                .id(run.index)
                .transition(slide(in: .trailing, out: .leading))
        }
    }

    /// A step or a part sliding in from `from` and out toward `to`; a fade under Reduce Motion.
    private func slide(in from: Edge, out to: Edge) -> AnyTransition {
        .adaptive(.asymmetric(insertion: .move(edge: from).combined(with: .opacity),
                              removal: .move(edge: to).combined(with: .opacity)),
                  reduceMotion: reduceMotion)
    }

    // MARK: Practising a part

    /// "Practice this part" on the sheet: offered for a whole arrangement, whose sections it can loop.
    private var practiceAction: ((SongSheet.Loop) -> Void)? {
        guard lesson.arrangement != nil, lesson.songTake != nil else { return nil }
        return { loop in openPart(loop) }
    }

    /// The section as a play-along of its own at the loop's speed, a few times through (`SongSheet.passes`).
    private func partPlan(for loop: SongSheet.Loop) -> SongArrangement.Practice? {
        guard let arrangement = lesson.arrangement, let take = lesson.songTake, let section = loop.section.part else { return nil }
        let practice = arrangement.practice(section, in: take.notes, speed: loop.speed, passes: SongSheet.passes(bars: section.bars))
        return practice.notes.isEmpty ? nil : practice
    }

    private func openPart(_ loop: SongSheet.Loop) {
        guard let plan = partPlan(for: loop) else { return }
        lastPart = loop
        Analytics.log("song_part_practice", ["lesson": lesson.id, "speed": "\(Int((loop.speed * 100).rounded()))"])
        withMotion(Motion.page, reduceMotion: reduceMotion) { part = PartTake(loop: loop, plan: plan) }
    }

    private func closePart() {
        Haptics.shared.selection()
        withMotion(Motion.page, reduceMotion: reduceMotion) { part = nil }
    }

    /// The part on the play-along's runway (after the tune check, as any step that listens); Continue, or the back
    /// button, returns to the sheet. Its takes touch neither the lesson's score nor its weak spots.
    @ViewBuilder private func partStage(_ part: PartTake) -> some View {
        if !tuneChecked, TuneCheckStep.needed(for: course) {
            TuneCheckStep(course: course, accent: accent) { withAnimation { tuneChecked = true } }
                .transition(.opacity)
        } else {
            AlongStep(notes: part.plan.notes, bpm: part.plan.bpm, beatsPerBar: part.plan.beatsPerBar, title: part.plan.section.name,
                      course: course, accent: accent, done: { _ in closePart() })
        }
    }

    /// In the lesson header's place while a part is practised: the song, and which bars at what speed.
    private func partHeader(_ part: PartTake) -> some View {
        let section = part.loop.section
        let tint = SongSectionMap.tint(of: section, in: SongSheet.of(lesson).sections, accent: accent)
        let bars = section.bars == 1 ? Text("Bar \(section.start + 1)") : Text("Bars \(section.start + 1)–\(section.start + section.bars)")
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "repeat").font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                Text(verbatim: lesson.title.localized)
                    .font(Typeface.label(14)).foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            (bars + Text(verbatim: " · \(Int((part.loop.speed * 100).rounded()))% · \(Int(part.plan.bpm.rounded())) BPM"))
                .font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .combine)
    }

    /// A song's last step is its performance; every other step plays as it is. A step arriving inside the zoom
    /// (the lesson's first screen) skips its own entrance: the zoom is its entrance.
    @ViewBuilder private func stepView(_ step: LessonStep) -> some View {
        switch songFinale(step) {
        case let .along(notes, bpm, beatsPerBar)?:
            SongPerformStep(notes: notes, bpm: bpm, beatsPerBar: beatsPerBar, lesson: lesson, course: course, accent: accent,
                            onItem: { item, score in run.score(item, score) }, onStarCap: { stars in run.capStars(stars) },
                            projectedStars: { score, cap in projectedStars(score, cap: cap) }, done: { score in advance(score) })
        case .chords?:
            SongEncoreStep(step: step, lesson: lesson, course: course, accent: accent, onPractice: { practiced = true },
                           onItem: { item, score in run.score(item, score) }, onStarCap: { stars in run.capStars(stars) },
                           projectedStars: { score, cap in projectedStars(score, cap: cap) }, done: { score in advance(score) })
        case nil:
            StepView(step: step, course: course, accent: accent, onPractice: { practiced = true },
                     onItem: { item, score in run.score(item, score) }, onStarCap: { stars in run.capStars(stars) },
                     done: { score in advance(score) }, entrance: arrived)
        }
    }

    private enum SongFinale {
        case along([TimedNote], Double, Int)
        case chords
    }

    /// The step on screen is a song's last, played as its performance.
    private func songFinale(_ step: LessonStep) -> SongFinale? {
        guard lesson.kind == .song, run.index == lesson.steps.count - 1 else { return nil }
        switch step {
        case let .playAlong(notes, bpm, beatsPerBar, _): return .along(notes, bpm, beatsPerBar)
        case .progression: return .chords
        default: return nil
        }
    }

    /// The stars the lesson records if the step on screen ends with `score` (`cap`: a take below the song's tempo),
    /// so a song's finale shows the stars its results will.
    private func projectedStars(_ score: Double, cap: Int?) -> Int {
        var preview = run
        if let cap { preview.capStars(cap) }
        preview.complete(score: score)
        let stars = preview.result().stars
        return practiced ? min(1, stars) : stars
    }

    /// The close button beside the lesson's compact header: its name, "Step 2 of 7" and a track with a segment
    /// per step, all in one 44 pt row.
    private var topBar: some View {
        HStack(spacing: 8) {
            if opening, let part {
                // Practising a part: back to the sheet, not out of the lesson.
                BackButton(label: "Back to the song sheet") { closePart() }
                    .accessibilityIdentifier("song.practice.back")
                partHeader(part)
            } else {
                CloseButton(label: "Close lesson") { if run.index == 0 { dismiss() } else { confirmQuit = true } }
                    .accessibilityIdentifier("lesson.close")
                LessonHeader(title: lesson.title.localized, index: run.index, steps: lesson.steps.count, accent: accent)
                    // A song's sheet comes before its steps (and names the song itself): the header shows once they start.
                    .opacity(opening ? 0 : 1)
                    .accessibilityHidden(opening)
            }
        }
        // The button's 34 pt disc sits 5 pt inside its 44 pt target.
        .padding(.leading, 8).padding(.trailing, Metrics.gutter).padding(.top, 4).padding(.bottom, 6)
    }

    private func advance(_ score: Double?) {
        #if DEBUG
        if DemoScene.holds(run.step) { return }  // the store scene's picture is this step, finished
        #endif
        run.complete(score: score)
        guard run.isFinished else { return }
        var outcome = run.result()
        if practiced && outcome.stars > 1 {
            // Tapping the glass isn't playing: practice mode keeps the lesson at one star (and its XP).
            outcome = LessonResult(lessonId: outcome.lessonId, stars: 1, accuracy: outcome.accuracy,
                                   xp: Int((Double(lesson.xp) * 0.8).rounded()), minutes: outcome.minutes, items: outcome.items)
        }
        // A weak-spot review keeps no stars of its own, so it never reads as a new best.
        improved = !LearnProgress.isReview(lesson.id) && outcome.stars > (store.learn.stars[lesson.id] ?? 0)
        store.stopLessonListening()
        reward = store.finishLesson(outcome, courseId: course.id)
        SoundFX.shared.play(.complete)
        Haptics.shared.done()
        result = outcome
    }
}

/// Routes a step to its view. Each view calls `done` with a 0…1 score (nil when not scored).
struct StepView: View {
    let step: LessonStep
    let course: LearnCourse
    let accent: Color
    /// A rhythm step fell back to tapping (no microphone): the lesson tops out at one star.
    var onPractice: () -> Void = {}
    /// How a note or chord went, for the lesson's weak spots.
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    /// The step limits the lesson's stars (a play-along finished below the lesson tempo).
    var onStarCap: (Int) -> Void = { _ in }
    let done: (Double?) -> Void
    /// Off for a lesson's first screen, which arrives inside the zoom that opens the lesson: no entrance of its own.
    var entrance = true

    var body: some View {
        switch step {
        case let .explain(title, body, visual):
            ExplainStep(title: title, text: body, visual: visual, course: course, accent: accent, done: done, entrance: entrance)
        case let .playNotes(notes, hint):
            NotesStep(notes: notes, hint: hint, course: course, accent: accent, onItem: onItem, done: done)
        case let .playAlong(notes, bpm, beatsPerBar, title):
            AlongStep(notes: notes, bpm: bpm, beatsPerBar: beatsPerBar, title: title, course: course, accent: accent,
                      onItem: onItem, onStarCap: onStarCap, done: done)
        case let .playChord(chord):
            ChordStep(chord: chord, course: course, accent: accent, onItem: onItem, done: done)
        case let .strum(chord, pattern, bpm, bars, beatsPerBar):
            RhythmStep(mode: .strum(chord), pattern: pattern, bpm: bpm, bars: bars, meter: beatsPerBar, strums: true, strings: course.stringCount,
                       edges: StringEdges.of(course), accent: accent, onPractice: onPractice, done: done)
        case let .progression(chords, bars, pattern, bpm, beatsPerBar):
            RhythmStep(mode: .progression(chords, bars), pattern: pattern, bpm: bpm, bars: bars.reduce(0, +), meter: beatsPerBar, strums: true, strings: course.stringCount,
                       edges: StringEdges.of(course), accent: accent, onPractice: onPractice, done: done)
        case let .tapRhythm(pattern, bpm, bars, beatsPerBar):
            RhythmStep(mode: .tap, pattern: pattern, bpm: bpm, bars: bars, meter: beatsPerBar, hearsInstrument: course.fretKind != nil, strums: course.strums,
                       strings: course.stringCount, edges: StringEdges.of(course), accent: accent, onPractice: onPractice, done: done)
        case let .listen(prompt, sound, options, answer):
            ChoiceStep(prompt: prompt, options: options, answer: answer, why: nil, visual: .none, sound: sound, course: course, accent: accent, done: done)
        case let .quiz(prompt, options, answer, why, visual):
            ChoiceStep(prompt: prompt, options: options, answer: answer, why: why, visual: visual, sound: nil, course: course, accent: accent, done: done)
        }
    }
}

// MARK: - Shared pieces

/// A lesson's compact header beside its close button: the lesson's name and "Step 2 of 7" on one line, over a track
/// with a segment per step. VoiceOver reads it as one element.
struct LessonHeader: View {
    let title: String
    /// The step on screen, from 0.
    let index: Int
    let steps: Int
    let accent: Color

    private var shown: Int { min(index + 1, max(1, steps)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: title)
                    .font(Typeface.label(14))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("Step \(shown) of \(steps)")
                    .font(Typeface.number(12))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText(value: Double(shown)))
            }
            LessonProgressTrack(index: index, steps: steps, accent: accent)
        }
        // One row beside the 44 pt close button: the words stop growing before they'd crowd it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .adaptiveAnimation(Motion.page, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text("Step \(shown) of \(steps)"))
    }
}

/// The lesson's progress: a segment per step, the steps done filled in the accent, the one on screen lit softly with
/// a glow, the rest dim. A long lesson (over 16 steps) would make slivers, so it gets one continuous bar instead.
struct LessonProgressTrack: View {
    /// The step on screen, from 0 (`steps` once every step is done).
    let index: Int
    let steps: Int
    let accent: Color
    private static let thickness: CGFloat = 6

    var body: some View {
        Group {
            if steps >= 2 && steps <= 16 { segments } else { bar }
        }
        .frame(height: Self.thickness)
        .accessibilityHidden(true)
    }

    private var fill: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.85), accent], startPoint: .leading, endPoint: .trailing)
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(0..<steps, id: \.self) { k in
                Capsule().fill(Color.white.opacity(0.09))
                    .overlay(Capsule().fill(fill).opacity(k < index ? 1 : k == index ? 0.4 : 0))
                    .shadow(color: accent.opacity(k == index ? 0.55 : 0), radius: 5)
            }
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            let share = steps > 0 ? CGFloat(min(index, steps)) / CGFloat(steps) : 1
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09))
                Capsule().fill(fill)
                    .frame(width: max(Self.thickness, proxy.size.width * share))
                    .shadow(color: accent.opacity(0.5), radius: 6)
            }
        }
    }
}

/// Every step's title, the same on every kind of step (an explanation, a quiz, a strum, the tune check, a play-along):
/// Sora 28 on the title curve, leading, wrapping onto as many lines as it needs, and a heading for VoiceOver. The
/// title never changes size or alignment from one step to the next.
struct StepTitle: View {
    private let text: Text

    init(_ text: Text) { self.text = text }
    init(_ key: LocalizedStringKey) { self.text = Text(key) }

    var body: some View {
        text.font(Typeface.stepTitle).tracking(-0.4).foregroundStyle(Palette.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The big bottom button every step ends with: the app's one primary button (`PrimaryButtonStyle`) in the step's
/// accent, disabled looking disabled.
struct StepButton: View {
    let title: LocalizedStringKey
    var accent: Color = Palette.mint
    var enabled = true
    /// Off inside a `LessonActionBar`, which keeps the margins for the whole row.
    var inset = true
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title) }
            .buttonStyle(PrimaryButtonStyle(accent: accent))
            .disabled(!enabled)
            .padding(.horizontal, inset ? Metrics.gutter : 0).padding(.bottom, inset ? 12 : 0)
            .accessibilityIdentifier("lesson.continue")
    }
}

/// The row pinned to the bottom of a step: its own actions ("Hear it", "I played it") side by side, beside the
/// main button when there is one; stacked at the largest text sizes, so no label is squeezed.
/// One glass group (iOS 26): the step's own actions are Liquid Glass beside the solid main button, rendered in one
/// pass, and an action arriving ("I played it" after a few seconds) materializes as glass rather than popping in.
struct LessonActionBar<Content: View>: View {
    private let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var glass

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        // The group reaches a little less than the gap, so two glass buttons never bridge at rest.
        TimbreGlassGroup(spacing: 8) {
            layout { content }
        }
        .environment(\.timbreGlassSpace, glass)
        .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
    }
}

/// "Hear it" in a step's bottom bar: a tinted button in the step's accent, its speaker waving while it sounds. The
/// secondary button's capsule, height and type (`SecondaryButtonStyle(tint:)`), so it sits level with the step's
/// primary button; on iOS 26 it is glass washed in the accent (`LessonActionBar`'s group).
struct HearItButton: View {
    var accent: Color = Palette.mint
    var sounding = false
    /// Takes the bar's width (a playing step, where listening is the main thing); otherwise it hugs its label.
    var expands = false
    let action: () -> Void
    @Environment(\.timbreGlassSpace) private var glass

    var body: some View {
        let shape = Capsule()
        Button(action: action) {
            Label("Hear it", systemImage: "speaker.wave.2.fill")
                .font(Typeface.button).foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, isActive: sounding)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 22)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: Metrics.buttonHeight)
                .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
                .timbreGlass(accent.opacity(0.16), in: shape) { shape.fill(accent.opacity(0.12)) }
                .timbreGlassID("lesson.hear", in: glass)
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }
}

/// A quieter button for a step's bottom bar ("I played it", "My strings are tuned — skip"): the secondary button's
/// capsule, height, type and control outline (`SecondaryButtonStyle`); clear glass on iOS 26.
struct LessonBarButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @Environment(\.timbreGlassSpace) private var glass

    var body: some View {
        let shape = Capsule()
        Button(action: action) {
            Text(title).font(Typeface.button).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .overlay(shape.strokeBorder(Palette.controlLine, lineWidth: 1))
                .timbreGlass(in: shape) { shape.fill(Palette.stageRaised) }
                .timbreGlassID("lesson.secondary", in: glass)
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// A burst of sparks for right answers and hit notes. Place it behind text: it is decoration.
struct SparkBurst: View {
    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        guard t < 0.9 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let fade = 1 - t / 0.9
        // Sparks and ring leave from `startFraction` of the half-size, and travel `reach` (160 pt by default).
        let origin = Double(min(size.width, size.height) / 2 * startFraction)
        let scale = Double((reach ?? 160) / 160)
        for i in 0..<22 {
            let angle: Double = Double(i) / 22 * 2 * .pi + Double(trigger) * 0.37
            let speed: Double = (90 + Double((i * 37) % 60)) * scale
            let d: Double = origin + speed * t * (1 - t / 1.8)
            let p = CGPoint(x: center.x + CGFloat(cos(angle) * d), y: center.y + CGFloat(sin(angle) * d))
            let r = CGFloat(3.2 * fade)
            let tint: Color = i % 3 == 0 ? Palette.amber : color
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(fade)))
        }
        guard ring else { return }
        let radius = CGFloat(origin + (20 + 160 * t) * scale)
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: ringRect), with: .color(color.opacity(max(0, 0.5 - t * 0.6))), lineWidth: 2)
    }

    let trigger: Int
    var color: Color = Palette.mint
    /// How far sparks and the ring travel (160 pt when nil).
    var reach: CGFloat?
    /// Where they start: 0 the centre, 1 the edge of the frame (a shockwave leaving a ring or a card).
    var startFraction: CGFloat = 0
    /// The expanding ring; off where it would cross nearby text.
    var ring = true
    @State private var started = Date.distantPast
    /// A burst is in the air: the timeline only runs for its 0.9 s, so an idle burst (most of the time, on most
    /// screens) costs nothing and doesn't hold the display at its full rate.
    @State private var live = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !live)) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            Canvas { context, size in draw(&context, size: size, t: t) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let launched = Date()
            started = launched
            live = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.95))
                // A later burst keeps the timeline running for its own 0.9 s.
                if started == launched { live = false }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Microphone permission is off: say so, offer Settings, let the step be skipped.
struct MicrophoneHint: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        if store.audio.permissionDenied {
            VStack(spacing: 8) {
                Label("Timbre needs the microphone to hear you play.", systemImage: "mic.slash.fill").font(.subheadline).foregroundStyle(Palette.inkSoft)
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
            }
            .padding(Metrics.tilePadding).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
            .padding(.horizontal, Metrics.gutter)
        }
    }
}

// MARK: - Explain

// `ExplainStep` lives in LessonExplain.swift.

// MARK: - Choices (listen and quiz)

struct ChoiceStep: View {
    let prompt: LearnText
    let options: [LearnText]
    let answer: Int
    let why: LearnText?
    let visual: LessonVisual
    let sound: [[Int]]?
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var picked: Int?
    @State private var shake = 0
    @State private var burst = 0
    @State private var playing = false
    /// The question's notes as they play: one sequence at a time, and none outlives the step (a stale one would
    /// sound over the next question and switch off the next step's microphone).
    @State private var playTask: Task<Void, Never>?
    /// The question's and the answers' heights, to know how much room the picture between them can take.
    @State private var promptHeight: CGFloat = 0
    @State private var answersHeight: CGFloat = 0

    private var correct: Bool { picked == answer }
    private var compact: Bool { options.count >= 3 && options.allSatisfy { $0.localized.count <= 8 } }
    /// The listen card at its plain size: the rings (156), the words under them (54) and its padding (32).
    private static let listenHeight: CGFloat = 242
    /// Below this the picture keeps its plain size and the step scrolls instead.
    private static let smallestFill: CGFloat = 120

    /// The question on top, the answers anchored at the bottom over the button, and the picture (or the listen
    /// card) growing to fill the room between them, so nothing floats mid-screen. When the feedback slides in,
    /// the picture gives up the room it needs.
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let room = middleRoom(proxy.size)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StepTitle(Text(prompt.localized))
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { promptHeight = $0 }
                        middle(room)
                        answers
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { answersHeight = $0 }
                    }
                    .padding(.horizontal, Metrics.gutter).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if let picked { feedback(picked) }
            StepButton(title: picked == nil ? "Check" : "Continue", accent: picked == nil || correct ? accent : Palette.danger, enabled: picked != nil) {
                done(correct ? 1 : 0)
            }
        }
        .onAppear { if let sound { play(sound) } }
        .onDisappear { playTask?.cancel(); playTask = nil }
    }

    private var answers: some View {
        Group {
            if compact {
                // Short answers (notes, numbers) as big tiles.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in optionRow(index, option) }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in optionRow(index, option) }
                }
            }
        }
        .modifier(Shake(amount: shake))
    }

    /// The room between the question and the answers (the paddings, 18 + 12, the two 20 pt gaps and the gutters
    /// aside); nil until both are measured, or when it's too small to fill.
    private func middleRoom(_ size: CGSize) -> CGSize? {
        guard promptHeight > 0, answersHeight > 0 else { return nil }
        let height = size.height - 30 - 40 - promptHeight - answersHeight
        return height >= Self.smallestFill ? CGSize(width: max(0, size.width - 2 * Metrics.gutter), height: height) : nil
    }

    /// The listen card and the picture, filling `room` together; with neither, the course's instrument or motif
    /// (as on an explanation without a picture), and the answers still sit at the bottom.
    private func middle(_ room: CGSize?) -> some View {
        VStack(spacing: 20) {
            if let sound { listenButton(sound, fill: visual == .none ? room?.height : nil) }
            if visual != .none {
                visualCard(room.flatMap { visualRoom($0) })
            } else if sound == nil, let room {
                LessonBackdrop(course: course, accent: accent).frame(height: room.height).opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: room?.height ?? 0)
    }

    /// The picture's share of the room: all of it, or what a listen card above it leaves.
    private func visualRoom(_ room: CGSize) -> CGSize? {
        let height = sound == nil ? room.height : room.height - Self.listenHeight - 20
        return height >= Self.smallestFill ? CGSize(width: room.width, height: height) : nil
    }

    private func visualCard(_ room: CGSize?) -> some View {
        let inner = room.map { CGSize(width: max(0, $0.width - 32), height: max(0, $0.height - 32)) }
        return LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument, room: inner)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: room?.height ?? 0)
            .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised))
    }

    /// A big play button with sound rings that ripple while the question plays; given `fill`, it grows to that
    /// height, the rings up to 280 pt.
    private func listenButton(_ sound: [[Int]], fill: CGFloat?) -> some View {
        let rings = fill.map { min(280, max(156, $0 - 86)) } ?? 156
        return Button { play(sound) } label: {
            VStack(spacing: 8) {
                ZStack {
                    RingMotif(accent: accent, active: playing)
                    Image(systemName: playing ? "speaker.wave.3.fill" : "play.fill").font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.onAccent).frame(width: 76, height: 76)
                        .background(Circle().fill(accent)).shadow(color: accent.opacity(0.5), radius: 16)
                        .symbolEffect(.variableColor.iterative, isActive: playing)
                }
                .frame(height: rings)
                VStack(spacing: 2) {
                    Text("Hear it").font(Typeface.label(17)).foregroundStyle(Palette.ink)
                    Text("Tap to play again").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, minHeight: max(0, (fill ?? 0) - 32))
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }

    private func optionRow(_ index: Int, _ option: LearnText) -> some View {
        let isPicked = picked == index
        let reveal = picked != nil
        let tint: Color = reveal && index == answer ? accent : reveal && isPicked ? Palette.danger : Palette.controlLine
        return Button {
            guard picked == nil else { return }
            // The feedback slides in and the picture above makes room for it.
            withAnimation(Motion.settle) { picked = index }
            if index == answer { SoundFX.shared.play(.correct); Haptics.shared.lock(); burst += 1 }
            else { SoundFX.shared.play(.wrong); Haptics.shared.selection(); withAnimation(.default) { shake += 1 } }
        } label: {
            HStack(spacing: 12) {
                if compact { Spacer(minLength: 0) }
                Text(option.localized).font(compact ? Typeface.display(26) : .body.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Spacer(minLength: compact ? 0 : 8)
                if reveal && index == answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                else if reveal && isPicked { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.danger) }
            }
            .padding(.horizontal, 18).frame(minHeight: compact ? 84 : 58)
            .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(reveal && (index == answer || isPicked) ? tint.opacity(0.12) : Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(tint, lineWidth: reveal && (index == answer || isPicked) ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(picked != nil && !isPicked && index != answer)
        // A right answer bursts out from behind its own tile, never over the words.
        .background {
            if index == answer {
                SparkBurst(trigger: burst, color: accent, reach: 120, startFraction: 0.35).frame(width: 260, height: 260)
            }
        }
        .accessibilityIdentifier("lesson.option.\(index)")
    }

    private func feedback(_ picked: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: correct ? "checkmark.seal.fill" : "lightbulb.fill").font(.title2).foregroundStyle(correct ? accent : Palette.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text(correct ? LocalizedStringKey("Nice — that’s right.") : LocalizedStringKey("Not quite.")).font(Typeface.label(17)).foregroundStyle(Palette.ink)
                if let why { Text(why.localized).font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true) }
                else if !correct { Text("The answer is \(options[answer].localized).").font(.subheadline).foregroundStyle(Palette.inkSoft) }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill((correct ? accent : Palette.amber).opacity(0.10)))
        .padding(.horizontal, Metrics.gutter).padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Plays the question's notes group by group; a replay stops the sequence already playing first.
    private func play(_ sound: [[Int]]) {
        playTask?.cancel()
        playing = true
        playTask = Task { @MainActor in
            for group in sound {
                guard !Task.isCancelled else { return }
                let hz = group.map { PitchMath.frequency(midi: Double($0), reference: store.settings.referencePitchHz) }
                store.audio.playTones(hz, together: group.count > 1, noteMs: group.count > 1 ? 900 : 650, gapMs: 120)
                try? await Task.sleep(for: .milliseconds(group.count > 1 ? 1350 : 800))
            }
            guard !Task.isCancelled else { return }
            playing = false
        }
    }
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    init(amount: Int) { animatableData = CGFloat(amount) }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 6), y: 0))
    }
}
