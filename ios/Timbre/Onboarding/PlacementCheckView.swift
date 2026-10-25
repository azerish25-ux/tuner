import SwiftUI
import TimbreCore

/// The 45-second placement check, offered on the plan to players who said they've played for years: three chords
/// (G, C and D), then a strum, on the lessons' own step views (`StepView`) with steps taken from their course
/// (`PlacementCheck.steps`). How it went moves their answer a level up or down (`PlacementCheck.verdict`); the plan,
/// the paywall's first lesson and the lesson Learn opens all follow the answer it hands back.
struct PlacementCheckView: View {
    let course: LearnCourse
    let steps: [LessonStep]
    /// The answer the check starts from.
    let level: String
    /// Called once: the answer to plan with (the checked one, or the old one when kept); nil when closed early.
    let onDone: (String?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.intro
    @State private var index = 0
    @State private var stepStarted = Date()
    @State private var chordScores: [Double] = []
    @State private var chordSeconds: [Double] = []
    @State private var strumScore: Double?
    /// The strum was tapped on the screen (the microphone couldn't hear it): no evidence either way.
    @State private var tapped = false
    @State private var checkedLevel = ""
    /// Start units (0-based) before and after the check, and the number the ring shows on its way between them.
    @State private var fromUnit = 0
    @State private var toUnit = 0
    @State private var shownUnit = 1
    @State private var burst = 0
    @State private var done = false

    private enum Phase { case intro, playing, result }

    private var accent: Color { Palette.accent(course.accent) }

    var body: some View {
        ZStack {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                content.frame(maxHeight: .infinity)
            }
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: phase)
        .animation(Motion.adaptive(Motion.page, reduceMotion: reduceMotion), value: index)
        .preferredColorScheme(.dark)
        // "Hear it" and the strum's band sound like the course's instrument, as in a lesson.
        .onAppear { store.audio.courseVoice = InstrumentVoice(instrumentId: course.instrument) }
        .onDisappear {
            store.audio.courseVoice = nil
            store.stopLessonListening()
            store.audio.stopMetronome()
        }
    }

    // MARK: Pieces

    /// Close, and one segment per step filling as the check goes. The close disc's edge sits on the gutter (its
    /// 44 pt target reaches 5 pt past the 34 pt disc).
    private var topBar: some View {
        HStack(spacing: 14) {
            CloseButton { close() }
                .accessibilityIdentifier("placement.close")
                .opacity(phase == .result ? 0 : 1)
                .disabled(phase == .result)
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { step in
                    Capsule().fill(segmentFilled(step) ? accent : Palette.line).frame(height: 4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(min(index + 1, steps.count)) of \(steps.count)"))
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Metrics.gutter - 5).padding(.top, 6)
    }

    private func segmentFilled(_ step: Int) -> Bool {
        switch phase {
        case .intro: return false
        case .playing: return step <= index
        case .result: return true
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .intro:
            intro.transition(.opacity)
        case .playing:
            StepView(step: steps[index], course: course, accent: accent, onPractice: { tapped = true }, done: { score in advance(score) })
                .id(index)
                .transition(.adaptive(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                  removal: .move(edge: .leading).combined(with: .opacity)),
                                      reduceMotion: reduceMotion))
        case .result:
            result.transition(.adaptive(.opacity.combined(with: .scale(scale: 0.96)), reduceMotion: reduceMotion))
        }
    }

    // MARK: Intro

    private var chords: [ChordSpec] {
        steps.compactMap { step -> ChordSpec? in
            if case let .playChord(chord) = step { return chord }
            return nil
        }
    }

    private var strum: (pattern: [Double], bpm: Double)? {
        for step in steps {
            if case let .strum(_, pattern, bpm, _, _) = step { return (pattern, bpm) }
        }
        return nil
    }

    private var intro: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow("Placement check", color: accent, style: .display)
                    Text("Show us how you play").font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Change between three chords, then strum a pattern. About 45 seconds, and your plan moves to match.")
                        .font(.body).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    chordRow
                    strumCard
                }
                .padding(.horizontal, Metrics.gutter).padding(.top, 18).padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Start the check") { begin() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.gutter).padding(.top, 8)
                .accessibilityIdentifier("placement.start")
            Button("Not now") { close() }
                .font(.subheadline).foregroundStyle(Palette.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 44).padding(.bottom, 6)
        }
    }

    /// The three chords, in the order they're asked for, in the picture the learner chose (the chart by default).
    private var chordRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(chords.enumerated()), id: \.offset) { _, chord in
                ChordPictureView(chord: chord, accent: accent, landing: !reduceMotion, compact: true)
                    .frame(maxWidth: .infinity)
                    .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
            }
        }
    }

    @ViewBuilder private var strumCard: some View {
        if let strum {
            HStack(spacing: 14) {
                Glyph("metronome", size: Glyph.lead, tint: accent)
                VStack(alignment: .leading, spacing: 6) {
                    StrokeArrows(pattern: strum.pattern, accent: accent)
                    Text("\(Int(strum.bpm)) BPM · \(PlacementCheck.bars) bars").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .stillCard()
        }
    }

    // MARK: Result

    private var moved: Int { toUnit - fromUnit }

    private var result: some View {
        let unit = course.units[min(toUnit, course.units.count - 1)]
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    unitRing.padding(.top, 24)
                    VStack(spacing: 8) {
                        resultTitle
                            .font(Typeface.display(30)).tracking(-0.5).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        resultDetail
                            .font(.subheadline).foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Metrics.proseInset)
                    scoreChips
                    unitCard(unit)
                }
                .padding(.horizontal, Metrics.gutter).padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            // The burst flies out past the ring, over the top of the scroll area.
            .scrollClipDisabled()
            Button("See my plan") { Haptics.shared.selection(); finishWith(checkedLevel) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.gutter).padding(.top, 8)
                .padding(.bottom, moved == 0 ? 14 : 0)
                .accessibilityIdentifier("placement.done")
            if moved != 0 {
                Button("Keep my answer") { finishWith(level) }
                    .font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 44).padding(.bottom, 6)
                    .accessibilityIdentifier("placement.keep")
            }
        }
        .onAppear(perform: revealUnit)
    }

    /// The start unit in a ring; it counts from the answer's unit to the checked one, with a burst on the way up.
    private var unitRing: some View {
        ZStack {
            SparkBurst(trigger: burst, color: accent, startFraction: 0.45).frame(width: 320, height: 320)
            Circle().fill(accent.opacity(0.12))
            Circle().strokeBorder(accent, lineWidth: 3).shadow(color: accent.opacity(0.5), radius: 18)
            VStack(spacing: 0) {
                Eyebrow("Unit", color: accent, style: .display)
                Text(shownUnit, format: .number).font(Typeface.number(64, relativeTo: .largeTitle)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(shownUnit)))
            }
            if moved != 0 {
                Image(systemName: moved > 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.onAccent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(moved > 0 ? accent : Palette.amber))
                    .offset(x: 56, y: -56)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 160, height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Unit \(toUnit + 1) · \(course.units[min(toUnit, course.units.count - 1)].title.localized)"))
    }

    @ViewBuilder private var resultTitle: some View {
        if moved > 0 {
            Text("Moving you up")
        } else if moved < 0 {
            Text("Starting a little earlier")
        } else {
            Text("Right where you said")
        }
    }

    @ViewBuilder private var resultDetail: some View {
        if moved > 0 {
            Text("Clean, quick changes and a steady strum: your plan starts further in.")
        } else if moved < 0 {
            Text("The changes and the strum need a little more time, so your plan starts a few units earlier.")
        } else {
            Text("Your plan starts where your answer put it.")
        }
    }

    /// How each chord rang, and the strum on the beat when it was heard; the strum under the chords when one row is too narrow.
    private var scoreChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                chordChips
                strumChip
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) { chordChips }
                strumChip
            }
        }
    }

    private var chordChips: some View {
        ForEach(Array(zip(chords, chordScores).enumerated()), id: \.offset) { _, pair in
            chordChip(pair.0, score: pair.1)
        }
    }

    @ViewBuilder private var strumChip: some View {
        if let strumScore {
            Text("\(Int((strumScore * 100).rounded()))% on the beat")
                .font(Typeface.label(13)).foregroundStyle(Palette.ink).lineLimit(1)
                .padding(.horizontal, 12).frame(minHeight: 34)
                .background(Capsule().fill(Palette.stageRaised))
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
                .fixedSize()
        }
    }

    private func chordChip(_ chord: ChordSpec, score: Double) -> some View {
        let clean = score >= 0.9
        let rough = score < 0.6
        return HStack(spacing: 5) {
            Image(systemName: clean ? "checkmark.circle.fill" : rough ? "exclamationmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(clean ? accent : rough ? Palette.amber : Palette.inkSoft)
            Text(verbatim: chord.name).font(Typeface.label(14)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 10).frame(minHeight: 34)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        .fixedSize()
    }

    /// The unit the plan now starts at and its first lesson.
    private func unitCard(_ unit: LearnUnit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(Text("Unit \(toUnit + 1) · \(unit.title.localized)"), color: accent, style: .display).lineLimit(1)
            Text("First lesson").font(.subheadline).foregroundStyle(Palette.inkSoft)
            if let first = unit.lessons.first {
                Text(first.title.localized).font(Typeface.display(22)).tracking(-0.3).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .stillCard(tint: accent)
        .accessibilityElement(children: .combine)
    }

    // MARK: Flow

    private func begin() {
        Haptics.shared.selection()
        stepStarted = Date()
        phase = .playing
        Analytics.log("onboarding_placement_check", ["result": "started", "course": course.id, "level": level])
    }

    /// One step done: a chord's score and how long it took to ring, or the strum's share on the beat.
    private func advance(_ score: Double?) {
        guard !done, phase == .playing else { return }
        let seconds = Date().timeIntervalSince(stepStarted)
        if case .playChord = steps[index] {
            chordScores.append(score ?? 0)
            chordSeconds.append(seconds)
        } else {
            strumScore = tapped ? nil : score
        }
        if index + 1 < steps.count {
            index += 1
            stepStarted = Date()
        } else {
            finish()
        }
    }

    private func finish() {
        store.stopLessonListening()
        let outcome = PlacementCheck.verdict(chords: chordScores, seconds: chordSeconds, strum: strumScore)
        let checked = PlacementCheck.level(level, after: outcome)
        let ids = course.units.map(\.id)
        checkedLevel = checked
        fromUnit = CoursePlacement.startUnit(level: level, courseId: course.id, unitIds: ids)
        toUnit = CoursePlacement.startUnit(level: checked, courseId: course.id, unitIds: ids)
        shownUnit = fromUnit + 1
        phase = .result
        Haptics.shared.done()
        Analytics.log("onboarding_placement_check", ["result": outcome.rawValue, "course": course.id, "from": level, "to": checked])
    }

    /// The ring counts from the answer's unit to the checked one once the result is up.
    private func revealUnit() {
        guard toUnit != fromUnit else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            withMotion(Motion.settle, reduceMotion: reduceMotion) { shownUnit = toUnit + 1 }
            if toUnit > fromUnit {
                burst += 1
                SoundFX.shared.play(.levelUp)
                Haptics.shared.lock()
            }
        }
    }

    private func close() {
        guard !done else { return }
        store.stopLessonListening()
        if phase == .playing { Analytics.log("onboarding_placement_check", ["result": "closed", "step": String(index + 1)]) }
        done = true
        onDone(nil)
    }

    private func finishWith(_ answer: String) {
        guard !done else { return }
        done = true
        onDone(answer)
    }
}

/// A strum pattern as strokes: on the beat down, between beats up, with a wider gap where a stroke is left out.
private struct StrokeArrows: View {
    let pattern: [Double]
    let accent: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { position, beat in
                Image(systemName: Self.isDown(beat) ? "arrow.down" : "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Self.isDown(beat) ? accent : Palette.ink)
                    .padding(.leading, gap(before: position))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spoken))
    }

    private func gap(before position: Int) -> CGFloat {
        guard position > 0 else { return 0 }
        return pattern[position] - pattern[position - 1] > 0.5 ? 16 : 6
    }

    private static func isDown(_ beat: Double) -> Bool { beat.truncatingRemainder(dividingBy: 1) < 0.25 }

    private var spoken: String {
        pattern.map { Self.isDown($0) ? String(localized: "Down") : String(localized: "Up") }.joined(separator: ", ")
    }
}
