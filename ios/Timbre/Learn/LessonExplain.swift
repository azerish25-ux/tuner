import SwiftUI
import TimbreCore

// MARK: - Explain

/// An explanation: the lesson's picture on a card, then the words. A picture of notes is a demonstration, shown
/// then played: a chord's fingers land in finger order and a neck's dots drop in note by note, each as its note
/// sounds; a staff or a keyboard lights each note as it sounds. "Hear it" plays it again. The card grows into
/// whatever room the words leave, so the lesson's own picture fills the screen instead of decoration.
struct ExplainStep: View {
    let title: LearnText
    let text: LearnText
    let visual: LessonVisual
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var sounding = false
    /// Height of the title and text, to know how much room is left under them.
    @State private var wordsHeight: CGFloat = 0
    /// Chord cards are a demonstration: the fingers land in order while each note sounds, the chord rings,
    /// then it's the learner's turn to play it back (heard by the microphone when it's already allowed).
    @State private var demo = Demo.idle
    @State private var demoReplay = 0
    @State private var demoTask: Task<Void, Never>?
    /// When the neck's first dot lands (nil: still, every dot in place).
    @State private var neckStart: Date?
    /// The staff or keyboard note sounding now, while "Hear it" plays them one by one.
    @State private var playingIndex: Int?
    @State private var owner = UUID()
    @State private var matchedFrames = 0
    @State private var burst = 0

    enum Demo { case idle, showing, yourTurn, heard }
    /// Seconds between fingers in the chord demonstration (the diagram's landing step and the notes' spacing).
    private static let demoStep = 0.45
    /// Seconds between the neck's dots, and between a staff's or a keyboard's notes: an easy melody pace.
    private static let noteStep = 0.42
    /// A diagram card grows into the room under the words up to this height (taller screens keep the rest).
    private static let diagramCardLimit: CGFloat = 600

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let base = Self.heroHeight(proxy.size.height)
                let spare = spareRoom(proxy.size.height, hero: base)
                let cardHeight = heroHeight(base: base, spare: spare)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        hero(height: cardHeight)
                            .scaleEffect(shown ? 1 : 0.94).opacity(shown ? 1 : 0)
                        words
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { wordsHeight = $0 }
                            .offset(y: shown ? 0 : 18).opacity(shown ? 1 : 0)
                        if base + spare - cardHeight >= 150 {
                            // Only on very tall screens, past the card's limit: the course's instrument or motif.
                            LessonBackdrop(course: course, accent: accent)
                                .frame(height: base + spare - cardHeight - 22)
                                .opacity(shown ? 0.85 : 0)
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            StepButton(title: "Continue", accent: accent) { Haptics.shared.selection(); done(nil) }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { shown = true }
            switch visual {
            case let .chord(spec): runDemo(spec, replay: false)
            case .fretboard: playNeck(replay: false)
            default: break
            }
        }
        .onDisappear { demoTask?.cancel(); store.stopLessonListening(owner: owner) }
    }

    /// Every explanation gets the same generous picture area, so short steps don't leave the lower half bare.
    private static func heroHeight(_ available: CGFloat) -> CGFloat { min(360, max(220, available * 0.46)) }

    /// What the hero and the words leave empty above the button (paddings 18 + 12, spacing 22).
    private func spareRoom(_ available: CGFloat, hero: CGFloat) -> CGFloat {
        guard wordsHeight > 0 else { return 0 }
        return max(0, available - hero - wordsHeight - 22 - 30)
    }

    /// The picture takes the room the words leave: all of it for the backdrop, a strum and the instrument
    /// photo; diagrams (neck, chord, staff, keyboard) up to a card's limit.
    private func heroHeight(base: CGFloat, spare: CGFloat) -> CGFloat {
        switch visual {
        case .none, .rhythm, .instrument: return base + spare
        default: return max(base, min(base + spare, Self.diagramCardLimit))
        }
    }

    /// The stroke drawn over a rhythm: a pick on strummed instruments, a plucking finger on the others, a tap pad without one.
    private var sweepStyle: StrumSweep.Style {
        guard course.fretKind != nil else { return .tap }
        return course.strums ? .strum : .pluck
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.localized).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text(text.localized).font(.title3).foregroundStyle(Palette.inkSoft).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The card

    /// The lesson's picture on a card, or (without one) the course instrument or motif on the stage.
    @ViewBuilder private func hero(height: CGFloat) -> some View {
        if visual == .none {
            LessonBackdrop(course: course, accent: accent).frame(height: height)
        } else {
            // The picture and its "Hear it" sit together in the middle of the card.
            VStack(spacing: 16) {
                picture(height: max(0, height - 36 - controlsHeight))
                controls
            }
            .frame(maxWidth: .infinity, minHeight: max(0, height - 36))
            .padding(18)
            .background(card)
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
    }

    /// Room the row under the picture takes ("Hear it", and the chord's "your turn" line), spacing included.
    private var controlsHeight: CGFloat {
        switch visual {
        case .chord: return 16 + 44 + 10 + 20
        case .fretboard: return neckMidis.contains { $0 != nil } ? 16 + 44 : 0
        case .staff, .keyboard: return 16 + 44
        default: return 0
        }
    }

    @ViewBuilder private var controls: some View {
        switch visual {
        case let .chord(spec):
            VStack(spacing: 10) {
                hearButton { runDemo(spec, replay: true) }
                yourTurn
            }
        case .fretboard:
            if neckMidis.contains(where: { $0 != nil }) { hearButton { playNeck(replay: true) } }
        case let .staff(midi, _):
            hearButton { playNotes(midi) }
        case let .keyboard(midi):
            hearButton { playNotes(midi.sorted()) }
        default:
            EmptyView()
        }
    }

    @ViewBuilder private func picture(height: CGFloat) -> some View {
        switch visual {
        case let .rhythm(pattern, beatsPerBar):
            // The stroke sweeps above the pattern in time with its playhead, filling the card.
            RhythmLoop(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, arrows: course.strums,
                       sweep: sweepStyle, strings: max(1, course.stringCount), edges: StringEdges.of(course))
                .frame(height: max(180, height))
        case let .chord(spec):
            chordBox(spec, width: chordWidth(spec, height: height))
        case let .fretboard(strings, dots, frets, start):
            neck(strings: strings, dots: dots, frets: frets, start: start, height: height)
        case let .staff(midi, clef):
            StaffView(notes: midi, clef: clef, accent: accent, activeIndex: playingIndex)
        case let .keyboard(midi):
            KeyboardView(highlighted: keyboardLit(midi), accent: accent)
        case let .instrument(part):
            InstrumentPartView(part: part, instrumentId: course.instrument, accent: accent, height: max(260, height))
        default:
            LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument)
        }
    }

    /// The chord box, its fingers landing in finger order on the demonstration's clock.
    private func chordBox(_ spec: ChordSpec, width: CGFloat) -> some View {
        ChordDiagram(chord: spec, accent: accent, landing: true, landingOrder: .fingers, landingStep: Self.demoStep,
                     replay: demoReplay, edges: StringEdges.of(instrumentId: course.instrument, strings: spec.frets.count))
            .frame(maxWidth: width)
            // Played back right: sparks from behind the box, on a canvas of their own size.
            .background { SparkBurst(trigger: burst, color: accent, startFraction: 0.45).frame(width: width * 1.55, height: width * 1.55) }
    }

    /// The chord box as big as the card allows: its name (about 44 pt), the box (5.4 rows tall for every string
    /// gap across) and the edge names (about 18 pt), never narrower than it used to be or wider than 320 pt.
    private func chordWidth(_ chord: ChordSpec, height: CGFloat) -> CGFloat {
        let count = CGFloat(max(2, chord.frets.count))
        let fromHeight = (height - 62) * count / 5.4
        return min(320, max(220, fromHeight))
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return shape.fill(Palette.stageRaised)
            .overlay(RadialGradient(colors: [accent.opacity(0.12), .clear], center: .top, startRadius: 4, endRadius: 260).clipShape(shape))
    }

    private func hearButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Hear it", systemImage: "speaker.wave.2.fill")
                .font(Typeface.label(15)).foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, isActive: sounding)
                .padding(.horizontal, 18).frame(minHeight: 44)
                .background(Capsule().fill(accent.opacity(0.12)))
                .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }

    /// One note in the course instrument's voice.
    private func sound(_ midi: Int, ms: Int = 380) {
        store.audio.playTones([PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz)],
                              together: false, noteMs: ms, gapMs: 0)
    }

    // MARK: Neck: the dots drop in, note by note

    /// Each dot's note on the course instrument, in `dots` order; nil when the tuning isn't known.
    private var neckMidis: [Int?] {
        guard case let .fretboard(strings, dots, _, _) = visual else { return [] }
        let open = ChordStep.openStrings(course)
        return dots.map { dot in
            guard open.count == strings, dot.string >= 1, dot.string <= strings else { return nil }
            return open[strings - dot.string] + dot.fret
        }
    }

    /// The order the dots land and sound in: lowest note first (as the tune climbs), as written when unknown.
    private var neckOrder: [Int] {
        let midis = neckMidis
        return midis.indices.sorted { a, b in (midis[a] ?? a, a) < (midis[b] ?? b, b) }
    }

    /// The neck as tall as the card allows (rows of 24 to 36 pt), the dots dropping in on their notes'
    /// clock and each one's string lit while its note sounds. With Reduce Motion the dots stay in place
    /// and only the strings light.
    private func neck(strings: Int, dots: [Fretting], frets: Int, start: Int, height: CGFloat) -> some View {
        let fixed: CGFloat = 54 + (start > 1 ? 16 : 0)
        let rowHeight = min(36, max(24, (height - fixed) / CGFloat(max(4, strings))))
        let order = neckOrder
        return TimelineView(.animation(minimumInterval: 1 / 60, paused: neckStart == nil)) { timeline in
            let state = neckState(at: timeline.date, order: order, dots: dots)
            FretboardDiagram(strings: strings, dots: dots, frets: frets, accent: accent, start: start, activeString: state.active,
                             fretless: course.fretless, rowHeight: rowHeight,
                             edges: StringEdges.of(instrumentId: course.instrument, strings: strings), landing: state.landing)
        }
    }

    /// How far each dot has landed and which string sounds, `date` into the demonstration.
    private func neckState(at date: Date, order: [Int], dots: [Fretting]) -> (landing: [Double]?, active: Int?) {
        guard let neckStart else { return (nil, nil) }
        let elapsed = date.timeIntervalSince(neckStart)
        var rank = Array(repeating: 0, count: dots.count)
        for (position, index) in order.enumerated() where dots.indices.contains(index) { rank[index] = position }
        let landing: [Double]? = reduceMotion ? nil : dots.indices.map { LessonSpring.value(elapsed - Double(rank[$0]) * Self.noteStep) }
        let current = elapsed >= 0 ? Int(elapsed / Self.noteStep) : -1
        let active: Int? = order.indices.contains(current) ? dots[safe: order[current]]?.string : nil
        return (landing, active)
    }

    /// The dots drop in one by one, each as its note sounds; `replay` starts at once (the Hear it button).
    private func playNeck(replay: Bool) {
        demoTask?.cancel()
        let lead = replay ? 0.05 : 0.3
        let midis = neckMidis
        let order = neckOrder
        neckStart = Date().addingTimeInterval(lead)
        sounding = true
        demoTask = Task { @MainActor in
            // One clock for the whole demonstration, so each note meets its dot.
            let clock = ContinuousClock()
            let start = clock.now
            for (position, index) in order.enumerated() {
                try? await clock.sleep(until: start + .seconds(lead + Double(position) * Self.noteStep))
                guard !Task.isCancelled else { return }
                if let midi = midis[safe: index] ?? nil { sound(midi) }
            }
            try? await clock.sleep(until: start + .seconds(lead + Double(order.count) * Self.noteStep + 0.4))
            guard !Task.isCancelled else { return }
            neckStart = nil
            sounding = false
        }
    }

    // MARK: Staff and keyboard: each note lights as it sounds

    /// On the keyboard, the key sounding now while the notes play; all of them otherwise.
    private func keyboardLit(_ midi: [Int]) -> Set<Int> {
        let sorted = midi.sorted()
        guard let playingIndex, sorted.indices.contains(playingIndex) else { return Set(midi) }
        return [sorted[playingIndex]]
    }

    /// The notes one by one, each lit as it sounds; two to four notes (an interval, a chord) then ring together.
    private func playNotes(_ midi: [Int]) {
        demoTask?.cancel()
        sounding = true
        demoTask = Task { @MainActor in
            for (index, note) in midi.enumerated() {
                playingIndex = index
                sound(note, ms: 400)
                try? await Task.sleep(for: .seconds(Self.noteStep + 0.06))
                guard !Task.isCancelled else { return }
            }
            playingIndex = nil
            if (2...4).contains(midi.count) {
                let reference = store.settings.referencePitchHz
                store.audio.playTones(midi.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1200)
                try? await Task.sleep(for: .milliseconds(1300))
                guard !Task.isCancelled else { return }
            }
            sounding = false
        }
    }

    // MARK: Chord: the fingers land, the chord rings, your turn

    /// After the demonstration: the learner's cue to play it back, then a tick when the microphone hears it.
    /// Its row is always there, so the card doesn't grow when it appears.
    private var yourTurn: some View {
        Group {
            if demo == .heard {
                Label("Nice — that’s right.", systemImage: "checkmark.seal.fill").foregroundStyle(accent)
            } else {
                Label("Your turn — play it back", systemImage: "hand.point.up.left.fill").foregroundStyle(Palette.ink)
            }
        }
        .font(Typeface.label(14))
        .multilineTextAlignment(.center)
        .frame(minHeight: 20)
        .opacity(demo == .yourTurn || demo == .heard ? 1 : 0)
        .animation(Motion.settle, value: demo)
        .accessibilityHidden(demo == .idle || demo == .showing)
    }

    /// Fingers land one by one (finger 1 first) as each one's note sounds, then the whole chord rings;
    /// `replay` lands them again (the Hear it button).
    private func runDemo(_ chord: ChordSpec, replay: Bool) {
        demoTask?.cancel()
        store.stopLessonListening(owner: owner)
        if replay { demoReplay += 1 }
        demo = .showing
        // The diagram starts landing 0.25 s after it appears, 0.05 s after a replay.
        let lead = replay ? 0.05 : 0.25
        let notes = demoNotes(chord)
        demoTask = Task { @MainActor in
            // One clock for the whole demonstration, so each note meets its finger.
            let clock = ContinuousClock()
            let start = clock.now
            for note in notes {
                try? await clock.sleep(until: start + .seconds(lead + Double(note.rank) * Self.demoStep))
                guard !Task.isCancelled else { return }
                sound(note.midi)
            }
            let ringAt = lead + Double((notes.last?.rank ?? -1) + 1) * Self.demoStep
            try? await clock.sleep(until: start + .seconds(ringAt))
            guard !Task.isCancelled else { return }
            strum(chord)
            try? await clock.sleep(until: start + .seconds(ringAt + 1.8))
            guard !Task.isCancelled else { return }
            demo = .yourTurn
            listenForPlayback(chord)
        }
    }

    /// Each landing's note (the lowest string a finger holds), in landing order.
    private func demoNotes(_ chord: ChordSpec) -> [(rank: Int, midi: Int)] {
        let open = ChordStep.openStrings(course)
        let ranks = ChordDiagram(chord: chord, landingOrder: .fingers).landingRanks
        var byRank: [Int: Int] = [:]
        for (i, fret) in chord.frets.enumerated() where fret > 0 && i < open.count && i < ranks.count {
            if byRank[ranks[i]] == nil { byRank[ranks[i]] = open[i] + fret }
        }
        return byRank.keys.sorted().compactMap { rank in byRank[rank].map { (rank: rank, midi: $0) } }
    }

    /// The learner plays the chord back: three matching readings in a row count. Only when the microphone
    /// is already allowed; the chord step that follows is where it's required.
    private func listenForPlayback(_ chord: ChordSpec) {
        guard LessonMicrophone.granted, let target = ChordTarget(root: chord.root, formulaId: chord.quality) else { return }
        matchedFrames = 0
        let analyzer = LessonAnalyzer(chords: true, target: target, onChord: { _, matched in
            guard demo == .yourTurn else { return }
            matchedFrames = matched ? matchedFrames + 1 : 0
            guard matchedFrames >= 3 else { return }
            demo = .heard
            burst += 1
            SoundFX.shared.play(.correct); Haptics.shared.lock()
            store.stopLessonListening(owner: owner)
        })
        store.startLessonListening(owner: owner, analyzer: analyzer) { _, _ in }
    }

    /// Sounds the chord as shaped on the course instrument (as the Chords tool does); a plain triad when the course has none.
    private func strum(_ chord: ChordSpec) {
        let open = ChordStep.openStrings(course)
        var midis = chord.frets.enumerated().compactMap { i, fret -> Int? in fret >= 0 && i < open.count ? open[i] + fret : nil }
        if midis.isEmpty, let target = ChordTarget(root: chord.root, formulaId: chord.quality) {
            midis = target.quality.intervals.map { 48 + target.root + $0 }
        }
        guard !midis.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        store.audio.playTones(midis.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1500)
        Haptics.shared.selection()
        sounding = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1900))
            sounding = false
        }
    }
}

/// A damped spring from 0 to 1 (response 0.35 s, a slight overshoot), for things that land: 0 before `t` reaches 0.
enum LessonSpring {
    static func value(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / 0.35, zeta = 0.62
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }
}

extension AnyTransition {
    /// One note name handing over to the next: the old one fades out first, then the new one fades in,
    /// so two names never sit on top of each other mid-change.
    static var noteHandover: AnyTransition {
        .asymmetric(insertion: AnyTransition.opacity.animation(.easeOut(duration: 0.2).delay(0.12)),
                    removal: AnyTransition.opacity.animation(.easeIn(duration: 0.1)))
    }
}
