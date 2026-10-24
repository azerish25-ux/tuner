import SwiftUI
import TimbreCore

/// A lesson, full screen: progress bar on top, one step at a time, results at the end.
struct LessonPlayer: View {
    let course: LearnCourse
    let lesson: Lesson
    var onNext: ((Lesson) -> Void)?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var run: LessonRun
    @State private var result: LessonResult?
    @State private var improved = false
    @State private var reward: ProgressUpdate?
    @State private var confirmQuit = false
    @State private var tuneChecked = false
    /// A rhythm step was passed by tapping because the microphone couldn't hear the instrument.
    @State private var practiced = false

    init(course: LearnCourse, lesson: Lesson, onNext: ((Lesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.onNext = onNext
        _run = State(initialValue: LessonRun(lesson: lesson))
        #if DEBUG
        // A store scene (Root/DemoScenes.swift) opens on the step it shows, the tune check already done.
        if let start = DemoScene.lessonStart(lesson) { _run = State(initialValue: start); _tuneChecked = State(initialValue: true) }
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
                    if let step = run.step, step.usesMicrophone, !tuneChecked, TuneCheckStep.needed(for: course) {
                        TuneCheckStep(course: course, accent: accent) { withAnimation { tuneChecked = true } }
                            .transition(.opacity)
                    } else if let step = run.step {
                        StepView(step: step, course: course, accent: accent, onPractice: { practiced = true },
                                 onItem: { item, score in run.score(item, score) }, onStarCap: { stars in run.capStars(stars) },
                                 done: { score in advance(score) })
                            .id(run.index)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: run.index)
        .animation(.easeInOut(duration: 0.4), value: result != nil)
        .preferredColorScheme(.dark)
        // "Hear it", chords and listen steps sound like the course's instrument (theory, ear, rhythm: the selected one).
        .onAppear { store.audio.courseVoice = InstrumentVoice(instrumentId: course.instrument) }
        .onDisappear { store.audio.courseVoice = nil }
        .confirmationDialog("Leave this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("Your progress in this lesson won’t be saved.") }
        .onAppear { LiveActivityController.shared.lessonOpened(lesson.id, title: lesson.title.localized, symbol: course.symbol) }
        .onDisappear { store.stopLessonListening(); store.audio.stopMetronome(); LiveActivityController.shared.lessonClosed(lesson.id) }
        .statusBarHidden(result == nil)
        // The zoom-in from the Learn tab can be pulled back down; not halfway through (the close button asks first).
        .interactiveDismissDisabled(run.index > 0 && result == nil)
    }

    private var nextLesson: Lesson? {
        let all = course.lessons
        guard let i = all.firstIndex(where: { $0.id == lesson.id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { if run.index == 0 { dismiss() } else { confirmQuit = true } } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.inkSoft)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Close lesson").accessibilityIdentifier("lesson.close")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule().fill(LinearGradient(colors: [accent.opacity(0.85), accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, proxy.size.width * run.progress))
                        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.35)).frame(height: 3).padding(.horizontal, 6).padding(.top, 2) }
                        .shadow(color: accent.opacity(0.5), radius: 8)
                }
            }
            .frame(height: 14)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: run.progress)
            .accessibilityElement().accessibilityLabel(Text("Step \(run.index + 1) of \(lesson.steps.count)"))
        }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
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

    var body: some View {
        switch step {
        case let .explain(title, body, visual):
            ExplainStep(title: title, text: body, visual: visual, course: course, accent: accent, done: done)
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

/// The big bottom button every step ends with.
struct StepButton: View {
    let title: LocalizedStringKey
    var accent: Color = Palette.mint
    var enabled = true
    /// Off inside a `LessonActionBar`, which keeps the margins for the whole row.
    var inset = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Typeface.label(18)).foregroundStyle(enabled ? Palette.onAccent : Palette.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(enabled ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.stageRaised)))
                .overlay(alignment: .bottom) {
                    if enabled { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.18)).frame(height: 5).offset(y: 5).mask(RoundedRectangle(cornerRadius: 18, style: .continuous).offset(y: 5)) }
                }
                .shadow(color: enabled ? accent.opacity(0.35) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .padding(.horizontal, inset ? 20 : 0).padding(.bottom, inset ? 12 : 0)
        .accessibilityIdentifier("lesson.continue")
    }
}

/// The row pinned to the bottom of a step: its own actions ("Hear it", "I played it") side by side, beside the
/// main button when there is one; stacked at the largest text sizes, so no label is squeezed.
struct LessonActionBar<Content: View>: View {
    private let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        layout { content }
            .padding(.horizontal, 20).padding(.bottom, 12)
    }
}

/// "Hear it" in a step's bottom bar: a tinted button in the step's accent, its speaker waving while it sounds.
struct HearItButton: View {
    var accent: Color = Palette.mint
    var sounding = false
    /// Takes the bar's width (a playing step, where listening is the main thing); otherwise it hugs its label.
    var expands = false
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            Label("Hear it", systemImage: "speaker.wave.2.fill")
                .font(Typeface.label(17)).foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, isActive: sounding)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 22)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: 56)
                .background(shape.fill(accent.opacity(0.12)))
                .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }
}

/// A quieter button for a step's bottom bar ("I played it", "My strings are tuned — skip").
struct LessonBarButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            Text(title).font(Typeface.label(16)).foregroundStyle(Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.75)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(shape.fill(Palette.stageRaised))
                .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            Canvas { context, size in draw(&context, size: size, t: t) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in started = Date() }
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
            .padding(14).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.stageRaised))
            .padding(.horizontal, 20)
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
                        Text(prompt.localized).font(Typeface.display(26)).tracking(-0.4).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { promptHeight = $0 }
                        middle(room)
                        answers
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { answersHeight = $0 }
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            if let picked { feedback(picked) }
            StepButton(title: picked == nil ? "Check" : "Continue", accent: picked == nil || correct ? accent : Palette.danger, enabled: picked != nil) {
                done(correct ? 1 : 0)
            }
        }
        .onAppear { if let sound { play(sound) } }
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

    /// The room between the question and the answers (the paddings, 18 + 12, and the two 20 pt gaps aside);
    /// nil until both are measured, or when it's too small to fill.
    private func middleRoom(_ size: CGSize) -> CGSize? {
        guard promptHeight > 0, answersHeight > 0 else { return nil }
        let height = size.height - 30 - 40 - promptHeight - answersHeight
        return height >= Self.smallestFill ? CGSize(width: max(0, size.width - 44), height: height) : nil
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
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
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
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }

    private func optionRow(_ index: Int, _ option: LearnText) -> some View {
        let isPicked = picked == index
        let reveal = picked != nil
        let tint: Color = reveal && index == answer ? accent : reveal && isPicked ? Palette.danger : Palette.line
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
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(reveal && (index == answer || isPicked) ? tint.opacity(0.12) : Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint, lineWidth: reveal && (index == answer || isPicked) ? 2 : 1))
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
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill((correct ? accent : Palette.amber).opacity(0.10)))
        .padding(.horizontal, 20).padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func play(_ sound: [[Int]]) {
        playing = true
        Task { @MainActor in
            for group in sound {
                let hz = group.map { PitchMath.frequency(midi: Double($0), reference: store.settings.referencePitchHz) }
                store.audio.playTones(hz, together: group.count > 1, noteMs: group.count > 1 ? 900 : 650, gapMs: 120)
                try? await Task.sleep(for: .milliseconds(group.count > 1 ? 1350 : 800))
            }
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
