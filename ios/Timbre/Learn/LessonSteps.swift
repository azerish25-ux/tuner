import Combine
import QuartzCore
import SwiftUI
import TimbreCore

/// A live pitch as the nearest note and how far off it is.
struct HeardNote: Equatable {
    let midi: Int
    let cents: Double
    init?(hz: Double?, reference: Double) {
        guard let hz, hz > 0 else { return nil }
        let exact = PitchMath.midi(frequency: hz, reference: reference)
        midi = Int(exact.rounded())
        cents = (exact - Double(midi)) * 100
    }
}

extension LearnCourse {
    /// Fretted or fingerboard instruments draw string/fret positions; voice and any-instrument courses don't.
    var fretKind: String? { Self.fretKind(of: instrument) }
    static func fretKind(of instrumentId: String?) -> String? {
        guard let instrumentId else { return nil }
        return ["guitar", "ukulele", "bass", "violin", "cello", "mandolin", "banjo"].first { instrumentId.hasPrefix($0) }
    }
    var stringCount: Int {
        switch fretKind { case "guitar": return 6; case "banjo": return 5; case .some: return 4; default: return 0 }
    }
    var fretless: Bool { fretKind == "violin" || fretKind == "cello" }
    /// Singing and play-by-ear courses accept the right note in any octave.
    var anyOctave: Bool { fretKind == nil }
    /// Strummed instruments: rhythm patterns show down and up strokes.
    var strums: Bool { Self.strummed(instrument) }
    static func strummed(_ instrumentId: String?) -> Bool {
        guard let instrumentId else { return false }
        return ["guitar", "ukulele", "banjo", "mandolin"].contains { instrumentId.hasPrefix($0) }
    }

    /// Where to play a note on the course instrument when the lesson doesn't say: the lowest fret
    /// on any string (string 1 is the highest), within the first twelve. The banjo's short fifth string only open.
    func fretting(for midi: Int) -> Fretting? {
        let open = ChordStep.openStrings(self)
        var best: Fretting?
        for (index, pitch) in open.enumerated() {
            let fret = midi - pitch
            guard fret >= 0, fret <= 12 else { continue }
            if fretKind == "banjo" && index == 0 && fret != 0 { continue }
            if let best, best.fret <= fret { continue }
            best = Fretting(string: open.count - index, fret: fret)
        }
        return best
    }

    /// A note as a weak-spot item: on fretted courses with where it's played (the lesson's place, else the
    /// lowest fret), so a note step and a play-along of the same note count as one item.
    func practiceItem(for note: TimedNote) -> PracticeItem {
        .note(midi: note.midi, at: fretKind != nil ? note.at ?? fretting(for: note.midi) : nil)
    }
}

@MainActor private func frequency(_ midi: Int, _ store: AppStore) -> Double { PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz) }

// MARK: - Notes, one at a time

struct NotesStep: View {
    let notes: [TimedNote]
    let hint: LearnText?
    let course: LearnCourse
    let accent: Color
    /// How each note went (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var heard: HeardNote?
    @State private var hold = 0.0
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false
    /// "Hear it" is playing the note.
    @State private var sounding = false
    /// Wrong notes heard while the current note was the target.
    @State private var wrongHere = 0
    /// "Hear it" listening again after its note, and the hand-over to the next step: both end with the step, so
    /// neither reopens the microphone (or finishes the lesson) after it has closed.
    @State private var hearTask: Task<Void, Never>?
    @State private var finishTask: Task<Void, Never>?
    /// VoiceOver: the next note as each one lands, and which way to go while a pitch is held that isn't it yet.
    @State private var voice = NoteStepVoice()

    init(notes: [TimedNote], hint: LearnText?, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, done: @escaping (Double?) -> Void) {
        self.notes = notes; self.hint = hint; self.course = course; self.accent = accent; self.onItem = onItem; self.done = done
        _judge = State(initialValue: NoteSequenceJudge(notes: notes.map(\.midi), anyOctave: course.anyOctave))
    }

    private var current: TimedNote? { judge.index < notes.count ? notes[judge.index] : nil }
    /// The note on screen: the one to play, or the last one once they're all done.
    private var shown: TimedNote? { current ?? notes.last }
    /// Where the shown note sits on the neck (the lesson's position, else the lowest fret for it).
    private var shownFretting: Fretting? {
        guard course.fretKind != nil, let note = shown else { return nil }
        return note.at ?? course.fretting(for: note.midi)
    }
    /// One width for the whole sequence, so the strip doesn't jump between notes.
    private var stripFrets: Int {
        let highest = notes.compactMap { $0.at ?? course.fretting(for: $0.midi) }.map(\.fret).max() ?? 0
        return min(12, max(5, highest + 1))
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    ScrollView {
                        noteContent
                            .padding(.bottom, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    stepBar
                }
            } else {
                VStack(spacing: 16) {
                    noteContent
                    stepBar
                }
            }
        }
        .onAppear { listen(); Task { try? await Task.sleep(for: .seconds(6)); withAnimation(Motion.settle) { canSkip = true } } }
        .onDisappear { hearTask?.cancel(); finishTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; pick the note up again on return.
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !sounding { listen() } }
    }

    /// At accessibility sizes the teaching content can scroll without pushing the lesson header or actions
    /// outside the viewport. The normal-size stack keeps its existing spacing and flexible spacers.
    @ViewBuilder private var noteContent: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 16) { teachingContent }
        } else {
            teachingContent
        }
    }

    @ViewBuilder private var teachingContent: some View {
        header
        if readsStaff { stepStaff } else if isSequence { sequenceChips }
        Spacer(minLength: 0)
        if isSequence { prompt }
        noteRing
        Spacer(minLength: 0)
        targetPicture
        MicrophoneHint()
    }

    private var stepBar: some View {
        LessonStepBar(canSkip: canSkip, accent: accent, sounding: sounding,
                      skip: { finish(score: 0.6) }, hear: { hear() })
    }

    private var isSequence: Bool { notes.count > 1 }

    /// Violin, cello and mandolin players learn to read: their notes are written on a staff (treble clef, bass clef
    /// for cello) rather than spelled out in letters.
    private var readsStaff: Bool { ["violin", "cello", "mandolin"].contains(course.fretKind ?? "") && !notes.isEmpty }

    /// The step's notes engraved, the one to play glowing and those played in the accent.
    private var stepStaff: some View {
        NotationPhrase(notes: notes, clef: Clef.reading(instrument: course.instrument, midis: notes.map(\.midi)), accent: accent,
                       current: finished ? nil : min(judge.index, notes.count - 1), done: finished ? notes.count : judge.index)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised))
            .padding(.horizontal, Metrics.gutter)
            .animation(Motion.quick, value: judge.index)
            .accessibilityIdentifier("lesson.notes.staff")
    }

    /// "Play this note" names the note in the ring: over a single note it heads the step; in a sequence it
    /// sits right on the ring (the one to play now), and the lesson's hint heads the whole run instead.
    private var prompt: some View {
        Text(course.instrument == "voice" ? LocalizedStringKey("Sing this note") : LocalizedStringKey("Play this note"))
            .font(Typeface.label(.body)).foregroundStyle(Palette.inkSoft)
    }

    private var header: some View {
        VStack(spacing: 6) {
            if !isSequence { prompt }
            if let hint {
                Text(hint.localized)
                    .font(isSequence ? Typeface.label(.body) : .subheadline)
                    .foregroundStyle(isSequence ? Palette.ink : Palette.inkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
            }
        }
        .padding(.top, 10)
    }

    private var noteRing: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ZStack {
                        HoldRing(progress: finished ? 1 : hold, tint: ringTint)
                        noteLetter
                    }
                    .frame(width: 290, height: 290)
                    .background { ringBurst }
                    Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(ringTint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Metrics.gutter)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity)
            } else {
                ZStack {
                    HoldRing(progress: finished ? 1 : hold, tint: ringTint)
                    VStack(spacing: 4) {
                        noteLetter
                        Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(ringTint).contentTransition(.opacity)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: 150, maxWidth: 290, minHeight: 150, maxHeight: 290)
                .background { ringBurst }
                .layoutPriority(1)
            }
        }
        // Below its neighbours, so the sparks pass behind the prompt and the chips, never over words.
        .zIndex(-1)
        // The note to play, as said ("D, string 4, open"), and how the pitch heard stands.
        .accessibilityElement(children: .ignore)
        // The complete laid-out note and wrapped status own the focus bounds, not the burst's
        // doubled canvas. Hiding that decoration alone does not constrain a parent's AX frame.
        .contentShape(.accessibility, Rectangle())
        .accessibilityLabel(Text(verbatim: shown.map { spokenPhrase($0) } ?? ""))
        .accessibilityValue(Text(status))
        .accessibilityIdentifier("lesson.notes.target")
        // The note to play is what this step is about: VoiceOver reads the step from here.
        .lessonStepArrival()
    }

    /// A note as VoiceOver says it: its name in the app's language and, on a fretted or fingerboard course, where it
    /// is played ("F sharp, string 1, fret 2"; on a violin's or cello's fingerboard by finger, "String 1, finger 1").
    private func spokenPhrase(_ note: TimedNote) -> String {
        let name = NoteNames.spokenInApp(NoteName.pitchClass(note.midi))
        guard course.fretKind != nil, let at = note.at ?? course.fretting(for: note.midi) else { return name }
        return name + ", " + NotePlace.words(at, board: fingerboard)
    }

    /// A violin's or cello's fingerboard: its notes are placed by finger, never by fret.
    private var fingerboard: Fingerboard? { Fingerboard(instrument: course.instrument) }

    /// What VoiceOver says while a pitch is held that isn't the note in tune yet: which way to go ("A little flat.
    /// Tighten" on a fretted string; "Go higher" for a voice or a fingerboard), or the note it is ("That’s G"). Nil
    /// while nothing is heard or the note is in tune (the ring fills).
    private func spokenGuidance(_ note: HeardNote?) -> String? {
        guard let note, let target = current?.midi else { return nil }
        let right = course.anyOctave ? (note.midi - target) % 12 == 0 : note.midi == target
        guard right else { return String(localized: "That’s \(NoteNames.spokenInApp(NoteName.pitchClass(note.midi)))") }
        guard abs(note.cents) > judge.toleranceCents else { return nil }
        let pegs = course.fretKind != nil && !course.fretless
        if note.cents < 0 {
            return String(localized: "A little flat") + ". " + (pegs ? String(localized: "Tighten") : String(localized: "Go higher"))
        }
        return String(localized: "A little sharp") + ". " + (pegs ? String(localized: "Loosen") : String(localized: "Go lower"))
    }

    /// A shockwave leaving the ring's edge when a note lands: drawn on a canvas twice the ring's size
    /// (so nothing is cut off) and behind the ring, so it never crosses the note or "Hold it…". It spreads out to
    /// the sides only: above and below the ring it fades out within a few points, so neither the ring of shock nor a
    /// spark ever runs through the words over the ring or the neck strip under it ("Thinnest (1)").
    private var ringBurst: some View {
        GeometryReader { geometry in
            let size = geometry.size
            SparkBurst(trigger: burst, color: accent, startFraction: 0.5)
                .frame(width: size.width * 2, height: size.height * 2)
                .mask { Self.burstBand(ring: size.height) }
                .position(x: size.width / 2, y: size.height / 2)
        }
        // The wrapper is decorative too. The note target's separate accessibility content shape
        // prevents this oversized canvas from enlarging its parent's focus bounds.
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// The burst's canvas (twice the ring's height `ring`) is opaque across the ring's own height and clear from
    /// 12 points past its top and bottom edges.
    private static func burstBand(ring: CGFloat) -> LinearGradient {
        let canvas = max(1, ring * 2)
        let top = ring / 2, bottom = ring * 1.5
        func at(_ y: CGFloat) -> CGFloat { min(1, max(0, y / canvas)) }
        return LinearGradient(stops: [
            .init(color: .clear, location: at(top - 12)),
            .init(color: .white, location: at(top + 2)),
            .init(color: .white, location: at(bottom - 2)),
            .init(color: .clear, location: at(bottom + 12))
        ], startPoint: .top, endPoint: .bottom)
    }

    /// The note to play, handing over as the last one is ticked off: the old letter is fully gone before the new one
    /// fades in (`NoteHandover`), so two never overlap and none is left half drawn.
    private var noteLetter: some View {
        let name = NoteName.name(shown?.midi ?? 60)
        return NoteHandover(String(name.dropLast(name.last?.isNumber == true ? 1 : 0)), font: Typeface.hero(88), turn: min(judge.index, max(0, notes.count - 1)))
    }

    /// Where to play it: a strip of the neck with the target string and fret lit and breathing (fretted
    /// and fingerboard courses), or the notes on a staff with the current one lit (voice and any instrument).
    @ViewBuilder private var targetPicture: some View {
        if let at = shownFretting {
            VStack(spacing: 6) {
                FretboardDiagram(strings: course.stringCount, dots: [at], frets: stripFrets, accent: accent, activeString: at.string,
                                 fretless: course.fretless, rowHeight: 18, pulsing: !finished, edges: StringEdges.of(course), fretNumbers: true,
                                 fingerboard: fingerboard)
                    .padding(.horizontal, 18)
                Text(verbatim: NotePlace.words(at, board: fingerboard))
                    .font(Typeface.label(.footnote)).foregroundStyle(accent)
                    .contentTransition(.opacity)
            }
            .animation(Motion.quick, value: judge.index)
        } else if course.fretKind == nil, !notes.isEmpty {
            StaffView(notes: notes.map(\.midi), clef: staffClef, accent: accent, activeIndex: finished ? nil : min(judge.index, notes.count - 1))
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised))
                .padding(.horizontal, Metrics.gutter)
                .animation(Motion.quick, value: judge.index)
        }
    }

    /// Low sequences (a man's voice, a bass line) read in bass clef.
    private var staffClef: String {
        let midis = notes.map(\.midi)
        guard !midis.isEmpty else { return "treble" }
        return Double(midis.reduce(0, +)) / Double(midis.count) < 57 ? "bass" : "treble"
    }

    private var ringTint: Color {
        if finished { return accent }
        guard let heard, let target = current?.midi else { return Palette.inkSoft }
        let right = course.anyOctave ? (heard.midi - target) % 12 == 0 : heard.midi == target
        return right && abs(heard.cents) <= judge.toleranceCents ? accent : Palette.amber
    }

    private var status: LocalizedStringKey {
        if finished { return "Got it" }
        guard let heard, let target = current?.midi else { return "Listening…" }
        let right = course.anyOctave ? (heard.midi - target) % 12 == 0 : heard.midi == target
        if right { return abs(heard.cents) <= judge.toleranceCents ? "Hold it…" : heard.cents < 0 ? "A little flat" : "A little sharp" }
        return "That’s \(NoteName.pitchClass(heard.midi))"
    }

    private var sequenceChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                let state = index < judge.index ? 2 : index == judge.index ? 1 : 0
                // Notes still to come: soft ink on a raised chip with a hairline, readable on the green wash.
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(.footnote))
                    .foregroundStyle(state == 2 ? Palette.onAccent : state == 1 ? Palette.ink : Palette.inkSoft)
                    .frame(minWidth: 38, minHeight: 34)
                    .background(Capsule().fill(state == 2 ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.surface)))
                    .overlay(Capsule().strokeBorder(state == 1 ? accent : state == 0 ? Palette.controlLine : .clear, lineWidth: state == 1 ? 1.5 : 1))
            }
        }
        .animation(Motion.pluck, value: judge.index)
    }

    private func listen() {
        if let current { store.gameTargetHz = frequency(current.midi, store) }
        store.startLessonListening(owner: owner) { hz, _ in
            let note = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            heard = note
            guard !finished else { return }
            let now = CACurrentMediaTime()
            switch judge.update(time: now, midi: note?.midi, cents: note?.cents) {
            case .holding(let p)?: hold = p
            case .hit(let index)?:
                hold = 0; burst += 1
                // Clean is 1; each wrong note on the way halves, thirds… it (as the step's own accuracy).
                if notes.indices.contains(index) { onItem(course.practiceItem(for: notes[index]), 1 / Double(1 + wrongHere)) }
                wrongHere = 0
                SoundFX.shared.play(.correct); Haptics.shared.lock()
                if judge.isFinished { finish(score: judge.accuracy) }
                else if let next = current {
                    store.gameTargetHz = frequency(next.midi, store)
                    // A blind learner hears where the next note is without taking a hand off the instrument.
                    if UIAccessibility.isVoiceOverRunning { voice.next(spokenPhrase(next), now: now) }
                }
            case .wrong?:
                wrongHere += 1
                hold = max(0, hold - 0.1)
            default: hold = max(0, hold - 0.1)
            }
            if UIAccessibility.isVoiceOverRunning && !finished { voice.heard(spokenGuidance(note), now: now) }
        }
    }

    private func hear() {
        guard let current else { return }
        hearTask?.cancel()
        store.stopLessonListening(owner: owner)
        store.audio.playTones([frequency(current.midi, store)], together: false, noteMs: 900, gapMs: 0)
        sounding = true
        hearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled else { return }
            sounding = false
            if !finished { listen() }
        }
    }

    private func finish(score: Double) {
        guard !finished else { return }
        finished = true
        hearTask?.cancel()
        // Notes the microphone never confirmed ("I played it") count as shaky.
        for note in notes[min(judge.index, notes.count)...] { onItem(course.practiceItem(for: note), 0.5) }
        store.stopLessonListening(owner: owner)
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            done(score)
        }
    }
}

/// A big note name handing over to the next one in two beats: the old name fades out completely, then the new one
/// fades in. It stays one view throughout (no insertion or removal), so a reading landing mid-change can never
/// strand a half-faded name on screen.
struct NoteHandover: View {
    let name: String
    let font: Font
    var color: Color = Palette.ink
    /// Which note of a run this is: a change hands over even to the same name (E, then E again).
    var turn = 0
    @State private var shown: String
    @State private var visible = true
    @State private var swap: Task<Void, Never>?

    init(_ name: String, font: Font, color: Color = Palette.ink, turn: Int = 0) {
        self.name = name
        self.font = font
        self.color = color
        self.turn = turn
        _shown = State(initialValue: name)
    }

    var body: some View {
        Text(verbatim: shown)
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.identity)
            .opacity(visible ? 1 : 0)
            .onChange(of: name) { _, next in handOver(to: next) }
            .onChange(of: turn) { _, _ in handOver(to: name) }
            .onDisappear { swap?.cancel() }
    }

    private func handOver(to next: String) {
        swap?.cancel()
        withAnimation(.easeIn(duration: 0.12)) { visible = false }
        swap = Task { @MainActor in
            // Past the fade-out: the old name is gone before the new one is set.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            shown = next
            withAnimation(Motion.fade) { visible = true }
        }
    }
}

/// A ring that fills while a note is held in tune.
struct HoldRing: View {
    let progress: Double
    let tint: Color
    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.06))
            Circle().stroke(.white.opacity(0.08), lineWidth: 10)
            Circle().trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: 12)
                .animation(.linear(duration: 0.08), value: progress)
        }
    }
}

// MARK: - Chord: place the fingers, check each string, let it ring

/// A chord to play and let ring. One strum is heard string by string (`ChordRing`, a `PolyTuner` pass on the chord's
/// own pitches): the strings that rang tick, and a string that didn't is named with what usually stops it ("String 3
/// isn't ringing: arch finger 2"). Every string ringing, with the chord heard right, finishes the step; plucking the
/// strings one by one, lowest first, is the other way through.
struct ChordStep: View {
    let chord: ChordSpec
    let course: LearnCourse
    let accent: Color
    /// How the chord went (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var textDirection
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var verified: Set<Int> = []
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false
    @State private var hearing: String?
    @State private var matchedFrames = 0
    /// When the running chord reading last matched the chord, and what it last heard.
    @State private var lastMatch: CFTimeInterval = 0
    @State private var lastReading: ChordEstimate?
    /// Strings the last strum left silent (lowest string first), and what to do about the first of them.
    @State private var deadStrings: Set<Int> = []
    @State private var tip: String?
    /// Strums that left a string silent before every string rang.
    @State private var deadStrums = 0
    /// "Hear it" is playing the chord string by string; `demoString` is the one sounding now (lit on the box).
    @State private var sounding = false
    @State private var demoString: Int?
    @State private var hearTask: Task<Void, Never>?
    /// The hand-over to the next step, a beat after the chord rings; it ends with the step.
    @State private var finishTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    /// The chord chart (the default) or the player's view: the switch on the card, the app's one picture choice.
    @AppStorage(ChordPicture.storageKey) private var chordView: ChordPicture = .chart
    /// "Show me": the chord on the instrument's 3D model in place of the picture, its fingertips landing in finger order
    /// as each note sounds (`ShowMeStage`); the strings the microphone hears then ring on the model.
    @State private var showMe = false
    @State private var showMeReady = false
    @State private var showMeFailed = false
    /// The 3D demonstration's clock (its first fingertip lands then) and the strings its strum is ringing.
    @State private var showLandStart: Date?
    @State private var demoRing: Set<Int> = []
    /// The first time the chord appears in the course its demonstration plays by itself on the model before the
    /// microphone opens (`firstTask` brings it in once the card has settled, or gives up on it).
    @State private var firstShowing = false
    @State private var firstTask: Task<Void, Never>?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// The player's hold: the string checks sit over the strings wherever the picture draws them.
    @CurrentHand private var hand
    private let order: [(index: Int, midi: Int)]

    init(chord: ChordSpec, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, done: @escaping (Double?) -> Void) {
        self.chord = chord; self.course = course; self.accent = accent; self.onItem = onItem; self.done = done
        let open = ChordStep.openStrings(course)
        // Lowest string first, muted strings skipped.
        let order = chord.frets.enumerated().compactMap { i, fret -> (index: Int, midi: Int)? in
            guard fret >= 0, i < open.count else { return nil }
            return (index: i, midi: open[i] + fret)
        }
        self.order = order
        _judge = State(initialValue: NoteSequenceJudge(notes: order.map(\.midi), holdSeconds: 0.25, toleranceCents: 40))
    }

    /// Open-string MIDI lowest string first, matching chord shapes.
    static func openStrings(_ course: LearnCourse) -> [Int] { openStrings(kind: course.fretKind) }
    static func openStrings(kind: String?) -> [Int] {
        switch kind {
        case "guitar": return [40, 45, 50, 55, 59, 64]
        case "ukulele": return [67, 60, 64, 69]
        case "bass": return [28, 33, 38, 43]
        case "mandolin", "violin": return [55, 62, 69, 76]
        case "cello": return [36, 43, 50, 57]
        case "banjo": return [67, 50, 55, 59, 62]
        default: return []
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(finished ? LocalizedStringKey("Every string rings") : LocalizedStringKey("Strum it, or pluck each string"))
                    .font(Typeface.label(.body)).foregroundStyle(finished ? Palette.ink : Palette.inkSoft)
                    .accessibilityIdentifier(finished ? "lesson.chord.complete" : "lesson.chord.pending")
                    .lessonStepArrival()
                guidance
            }
            .padding(.top, 12)
            // The string checks over the chart (under the player's view, where its lanes are widest, as the runway's
            // targets; both run from the lowest string on the left) and the chord itself, filling the room between
            // the words and the bar.
            GeometryReader { geometry in
                let fit = diagramFit(geometry.size)
                // The 3D model's strings lie as the player's view's do: the checks go under it.
                let player = chordView == .player || showMe
                VStack(spacing: 14) {
                    if !player { stringChecks(width: fit.width, player: false) }
                    diagramCard(fit, player: player)
                    if player { stringChecks(width: fit.width, player: true) }
                    hearingPill
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: player)
            }
            MicrophoneHint()
            // Once every string rings, the step is done: no way round it is offered any more.
            LessonStepBar(canSkip: canSkip && !finished, accent: accent, sounding: sounding, skip: { finish(0.6) }, hear: { strumIt() })
        }
        .onAppear {
            // A chord new to the course is shown first, and heard after: the microphone opens once the demonstration
            // is over, so it never plays over the learner (nor is it judged).
            let first = playsFirstOnModel
            if first { showFirstOnModel() } else { listen() }
            Task { try? await Task.sleep(for: .seconds(6)); withAnimation(Motion.settle) { canSkip = true } }
            // The 3D model loads quietly once the step has settled, so "Show me" is immediate (once per lesson); at
            // once when it is coming by itself.
            if let model = showMeModel { ModelCache.shared.prefetch(model, after: first ? 0.2 : 1.2) }
        }
        .onDisappear { hearTask?.cancel(); finishTask?.cancel(); firstTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; listen again on return (after a first-time demonstration on its way).
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !sounding && !firstShowing { listen() } }
        // The picture choice changing elsewhere brings the picture back.
        .onChange(of: chordView) { _, _ in setShowMe(false) }
    }

    /// Under the heading: how to play it, or, once a strum left a string silent, which one and what to do.
    @ViewBuilder private var guidance: some View {
        if let tip, !finished {
            Label(tip, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.amber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.gutter)
                .transition(.opacity)
                .id(tip)
        } else {
            Text("Fingers in place, then let it ring.").font(.subheadline).foregroundStyle(Palette.inkFaint)
                .transition(.opacity)
        }
    }

    /// The chord box's width and stretch: as wide as the screen allows, its frets drawn taller to fill the height.
    /// Around the box's header (its name and the chart / player switch) and edge names go the checks (44), the
    /// card's padding (44), "Hearing" (34), the gaps between them (28) and a little air for larger text (8); with a 3D
    /// model, "Show me" and the line under it in the card (44, 20 and their gaps).
    private func diagramFit(_ room: CGSize) -> (width: CGFloat, stretch: CGFloat) {
        let showMeRow: CGFloat = showMeModel != nil ? Metrics.minTarget + 8 + 20 + 4 : 0
        return ChordDiagram.fit(chord, room: CGSize(width: room.width - 40 - 44, height: room.height - 158 - showMeRow))
    }

    /// The strings to light on the box: the ones heard, and the ones a demonstration is sounding.
    private var ringing: Set<Int> {
        let sounding = verified.union(demoRing)
        return demoString.map { sounding.union([$0]) } ?? sounding
    }

    /// The chord's name with the chart / player's-view switch, over the chart or the neck in the same room (the card
    /// holds still as they flip); either lights the strings heard, and the neck shimmers each as it starts to ring.
    private func diagramCard(_ fit: (width: CGFloat, stretch: CGFloat), player: Bool) -> some View {
        let edges = StringEdges.of(course)
        let model = showMeModel
        let threeD = showMe && showMeReady && model != nil
        return VStack(spacing: 8) {
            // One switch, "Chart · Player view · 3D" wherever the card has a model, whichever is up.
            ChordCardHeader(name: chord.name, accent: accent, threeD: model != nil ? showMeBinding : nil)
            // Bottom-aligned, so the chart's, the player's view's and the stage's string names sit in one place.
            ZStack(alignment: .bottom) {
                if !threeD {
                    chordPicture(fit, edges: edges)
                        .transition(.opacity)
                }
                if showMe, let model {
                    ShowMeStage(modelID: model, strings: chord.frets.count, fretless: course.fretless, shot: .fretting(ShowMeShape(chord: chord)),
                                accent: accent, ringing: ringing, landStart: showLandStart, landingStep: ShowMe.landingStep, edges: edges,
                                revealed: threeD,
                                label: Text("\(chord.name) chord"), value: ChordWords.shape(chord),
                                onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
                }
            }
            .frame(width: fit.width, height: ChordDiagram.boxHeight(chord, width: fit.width, stretch: fit.stretch, named: edges != nil))
            if model != nil {
                VStack(spacing: 4) {
                    ShowMeButton(accent: accent, loading: showMe && !showMeReady, showing: threeD, invite: !showMe && !firstShowing && !finished) {
                        setShowMe(true)
                    }
                    ShowMeCaption(text: ShowMe.caption(for: chord), accent: accent, live: threeD && sounding)
                }
            }
        }
        .frame(width: fit.width)
        .padding(22)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).fill(Palette.stageRaised))
        .shadow(color: finished ? accent.opacity(0.45) : .clear, radius: 26)
        // Behind the card: the sparks fly out from under its edges, never over the chord's name.
        .background { SparkBurst(trigger: burst, color: accent, startFraction: 0.6).frame(width: fit.width * 1.7, height: fit.width * 1.7) }
    }

    /// The chart or the player's view (the stored choice), flipping between them in the same room.
    private func chordPicture(_ fit: (width: CGFloat, stretch: CGFloat), edges: StringEdges?) -> some View {
        let player = chordView == .player
        return ZStack {
            if player {
                PlayerNeck(chord: chord, accent: accent, ringing: ringing, edges: edges)
                    .transition(ChordFlip.transition(toPlayer: true, reduceMotion: reduceMotion))
            } else {
                ChordDiagram(chord: chord, accent: accent, showName: false, ringing: ringing, landing: true, edges: edges,
                             fretNumbers: true, stretch: fit.stretch)
                    .transition(ChordFlip.transition(toPlayer: false, reduceMotion: reduceMotion))
            }
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: player)
    }

    // MARK: Show me

    /// The course instrument's 3D model, when the chord can be shown on it and the stage may run now.
    private var showMeModel: String? {
        guard !showMeFailed, chord.frets.count == course.stringCount else { return nil }
        return ShowMe.model(for: course, catalog: store.catalog, reduceMotion: reduceMotion)
    }

    private var showMeBinding: Binding<Bool> {
        Binding(get: { showMe }, set: { on in setShowMe(on) })
    }

    /// "Show me" puts the instrument on the card (the demonstration plays once it is in place) or, already there, plays
    /// it again; the switch back shows the picture. `tapped` is false when the step brings the model in by itself.
    private func setShowMe(_ on: Bool, tapped: Bool = true) {
        guard on else {
            guard showMe else { return }
            withMotion(Motion.reveal, reduceMotion: reduceMotion) {
                showMe = false
                showMeReady = false
            }
            return
        }
        if tapped { Haptics.shared.selection() }
        if showMe {
            if showMeReady { showMeDemo(lead: 0.05) }
            return
        }
        showMeReady = false
        showMe = true
    }

    /// The model on the card and the 3D demonstration playing.
    private var threeD: Bool { showMe && showMeReady && showMeModel != nil }

    private func showMeAppeared() {
        guard showMe, !showMeReady else { return }
        withAnimation(Motion.reveal) { showMeReady = true }
        firstTask?.cancel()
        firstShowing = false
        remember()
        showMeDemo(lead: ShowMe.lead)
    }

    /// The model couldn't be shown: the picture stays, without "Show me"; a first-time wait for it ends and the
    /// microphone opens.
    private func showMeUnavailable() {
        showMeFailed = true
        showMe = false
        showMeReady = false
        if firstShowing { endFirst() }
    }

    // MARK: Show me, the first time

    /// The first time this chord appears in the course (and the demonstration may play by itself: not with Reduce
    /// Motion or VoiceOver), it is shown on the model before the step listens.
    private var playsFirstOnModel: Bool {
        guard !reduceMotion, !voiceOver, showMeModel != nil else { return false }
        return ShowMe.firstTime(ShowMeKey.chord(chord), course: course, settings: store.settings)
    }

    /// Brings the model in once the card has settled (the demonstration plays as it arrives, then the microphone
    /// opens: `showMeDemo`). A model not in place in `ShowMe.patience` is given up on: the picture stays and the
    /// step listens.
    private func showFirstOnModel() {
        firstShowing = true
        firstTask?.cancel()
        firstTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ShowMe.settle))
            guard !Task.isCancelled, firstShowing else { return }
            if !showMe { setShowMe(true, tapped: false) }
            try? await Task.sleep(for: .seconds(ShowMe.patience))
            guard !Task.isCancelled, firstShowing, !showMeReady else { return }
            setShowMe(false)
            endFirst()
        }
    }

    /// The first-time demonstration won't come by itself: the step listens as usual.
    private func endFirst() {
        firstTask?.cancel()
        firstTask = nil
        firstShowing = false
        if !finished && !sounding { listen() }
    }

    /// The course has now shown this chord on the model: from here on it waits for "Show me".
    private func remember() {
        let key = ShowMeKey.chord(chord)
        guard !store.settings.hasShownDemo(key, in: course.id) else { return }
        store.updateSettings { $0.markDemoShown(key, in: course.id) }
    }

    /// The chord's demonstration on the model, as on the lesson's explanation: the fingertips land in finger order,
    /// each finger's note sounding as it presses, then the chord rings across the strings, low to high; then the
    /// microphone listens again.
    private func showMeDemo(lead: Double) {
        hearTask?.cancel()
        store.stopLessonListening(owner: owner)
        let step = ShowMe.landingStep
        let notes = ShowMe.demoNotes(chord, open: ChordStep.openStrings(course))
        let strings = order.map(\.index)
        let chordTones = order.map { frequency($0.midi, store) }
        demoString = nil
        demoRing = []
        sounding = true
        showLandStart = Date().addingTimeInterval(lead)
        hearTask = Task { @MainActor in
            // One clock for the whole demonstration, so each note meets its fingertip.
            let clock = ContinuousClock()
            let start = clock.now
            for note in notes {
                try? await clock.sleep(until: start + .seconds(lead + Double(note.rank) * step))
                guard !Task.isCancelled else { return }
                store.audio.playTones([frequency(note.midi, store)], together: false, noteMs: 380, gapMs: 0)
                demoString = note.string
            }
            let ringAt = lead + Double((notes.last?.rank ?? -1) + 1) * step
            try? await clock.sleep(until: start + .seconds(ringAt))
            guard !Task.isCancelled else { return }
            demoString = nil
            if !chordTones.isEmpty { store.audio.playTones(chordTones, together: true, noteMs: 1500) }
            for (k, string) in strings.enumerated() {
                try? await clock.sleep(until: start + .seconds(ringAt + Double(k) * 0.04))
                guard !Task.isCancelled else { return }
                demoRing.insert(string)
            }
            try? await clock.sleep(until: start + .seconds(ringAt + 1.6))
            guard !Task.isCancelled else { return }
            demoRing = []
            sounding = false
            if !finished { listen() }
        }
    }

    /// One check per string over its line in the box (lowest string first, as drawn), or under its lane on the
    /// player's view: the note it should ring, a ring on the one to pluck next, filled with a tick once heard. A
    /// strummed chord ticks them all in a ripple.
    private func stringChecks(width: CGFloat, player: Bool) -> some View {
        let open = ChordStep.openStrings(course)
        let count = chord.frets.count
        // Right over the box's string lines, wherever `ChordDiagram` draws them (past its fret-number column), or
        // where the neck's lanes meet its near edge (in the runway's order: the lowest string on the left, as on the
        // box), each mirrored as the picture is for a left-handed player.
        let xs = player ? PlayerNeck.stringPositions(chord, width: width, mirrored: hand.mirrorsUpright)
                        : ChordDiagram(chord: chord, fretNumbers: true, mirrored: hand.mirrorsChordChart).stringPositions(width: width)
        let gap = count > 1 ? abs(xs[count - 1] - xs[0]) / CGFloat(count - 1) : 40
        let side = min(40, max(26, gap - 8))
        let next: Int? = order.indices.contains(judge.index) && !finished ? order[judge.index].index : nil
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                LessonStringCheck(note: i < open.count ? NoteName.pitchClass(open[i] + max(0, chord.frets[i])) : "",
                                  number: count - i, mark: mark(i, next: next, open: open), accent: accent, side: side)
                    .environment(\.layoutDirection, textDirection)
                    .position(x: xs[i], y: 22)
                    .animation(reduceMotion ? Motion.reduced : Motion.pluck.delay(Double(i) * 0.04), value: verified.contains(i))
            }
        }
        .frame(width: width, height: 44)
        // The x coordinates come from a physical instrument canvas, never reading order.
        .environment(\.layoutDirection, .leftToRight)
        .animation(Motion.quick, value: judge.index)
    }

    private func mark(_ i: Int, next: Int?, open: [Int]) -> LessonStringCheck.Mark {
        if chord.frets[i] < 0 || i >= open.count { return .muted }
        if verified.contains(i) { return .heard }
        if deadStrings.contains(i) { return .silent }
        return next == i ? .next : .waiting
    }

    /// What the microphone hears as a chord; its row is kept while hidden, so the box doesn't jump.
    private var hearingPill: some View {
        let showing = hearing != nil && !finished
        return Text("Hearing \(hearing ?? chord.name)").font(Typeface.label(.footnote)).foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(Palette.stageRaised))
            .opacity(showing ? 1 : 0)
            .animation(Motion.quick, value: showing)
            .accessibilityHidden(!showing)
    }

    private func listen() {
        if let first = judge.current { store.gameTargetHz = frequency(first, store) }
        // A strum is heard string by string (`heardStrum`); the running chord reading names what's heard and vouches
        // for the strings one strum can't tell apart. Plucking string by string is the other way through.
        let target = ChordTarget(root: chord.root, formulaId: chord.quality)
        let pitches = order.map { frequency($0.midi, store) }
        let analyzer = LessonAnalyzer(chords: target != nil, target: target, strings: pitches, onChord: { estimate, matched in
            guard !finished else { return }
            withAnimation(Motion.quick) { hearing = estimate?.target.symbol }
            lastReading = estimate
            matchedFrames = matched ? matchedFrames + 1 : 0
            if matched { lastMatch = CACurrentMediaTime() }
        }, onStrum: { reading in heardStrum(reading, pitches: pitches, target: target) })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, _ in
            guard !finished else { return }
            let note = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            if case .hit(let i)? = judge.update(time: CACurrentMediaTime(), midi: note?.midi, cents: note?.cents) {
                withAnimation(Motion.pluck) { _ = verified.insert(order[i].index) }
                SoundFX.shared.play(.hit); Haptics.shared.selection()
                if judge.isFinished { burst += 1; SoundFX.shared.play(.correct); Haptics.shared.lock(); finish(judge.accuracy) }
                else if let next = judge.current { store.gameTargetHz = frequency(next, store) }
            }
        }
        #if DEBUG
        DemoScene.strumWithSilentString(pitches: pitches) { reading in heardStrum(reading, pitches: pitches, target: target) }
        #endif
    }

    /// One strum, every string at once: the strings that rang tick, and the first silent one is named with what usually
    /// stops it. Every string ringing (those one strum can't tell apart vouched for by the chord reading) finishes the
    /// step. A strum of another chord says nothing about strings: the pill says what was heard.
    private func heardStrum(_ reading: PolyReading, pitches: [Double], target: ChordTarget?) {
        guard !finished, !sounding, reading.strings.count == order.count else { return }
        let states = ChordRing.states(reading, pitches: pitches)
        let chordHeard = CACurrentMediaTime() - lastMatch < 1.2
        // The shape's own notes count too: a 9 is checked as its 7 (`ChordTarget`), and its ninth is no wrong note.
        let shape = Set(order.map { $0.midi % 12 })
        if let target, !chordHeard, let heard = lastReading, !heard.heardPitchClasses().isSubset(of: target.pitchClasses.union(shape)) { return }
        let dead = states.indices.filter { states[$0] == .dead }.map { order[$0].index }
        if dead.isEmpty && (chordHeard || states.allSatisfy { $0 == .rings }) {
            withAnimation(Motion.pluck) {
                deadStrings = []
                tip = nil
                verified = Set(order.map(\.index))
            }
            burst += 1; SoundFX.shared.play(.correct); Haptics.shared.lock()
            finish(deadStrums > 0 ? 0.85 : 1)
            return
        }
        let rang = states.indices.filter { states[$0] == .rings }.map { order[$0].index }
        withAnimation(Motion.pluck) {
            verified.formUnion(rang)
            deadStrings = Set(dead)
        }
        guard let advice = deadStringAdvice(dead) else { return }
        deadStrums += 1
        withAnimation(Motion.quick) { tip = advice }
        Haptics.shared.selection()
        if UIAccessibility.isVoiceOverRunning { UIAccessibility.post(notification: .announcement, argument: advice) }
    }

    /// What a silent string usually means, for the thickest one: a fretted string pressed too far from its fret; an
    /// open one touched by the finger on the string beside it (the thicker side first, where fingers lean from).
    private func deadStringAdvice(_ dead: [Int]) -> String? {
        let count = chord.frets.count
        guard let i = dead.min(), i < count else { return nil }
        let number = count - i
        let fret = chord.frets[i]
        if fret > 0 {
            if let finger = finger(on: i) { return String(localized: "String \(number) isn’t ringing: press finger \(finger) right behind the fret") }
            if chord.capo == fret { return String(localized: "String \(number) isn’t ringing: press the capo right behind the fret") }
            return String(localized: "String \(number) isn’t ringing: press it right behind the fret")
        }
        for j in [i - 1, i + 1] where j >= 0 && j < count && chord.frets[j] > 0 {
            if let finger = finger(on: j) { return String(localized: "String \(number) isn’t ringing: arch finger \(finger)") }
        }
        return String(localized: "String \(number) isn’t ringing: strum across it")
    }

    /// The finger the chord's shape puts on string `index` (lowest string first), if it names one.
    private func finger(on index: Int) -> Int? {
        guard let fingers = chord.fingers, fingers.indices.contains(index), fingers[index] > 0 else { return nil }
        return fingers[index]
    }

    /// The chord string by string, lowest first, each string lighting on the box as it sounds; then it listens again.
    /// Asked for before a first-time demonstration's model came in, it stands in for it (the model waits for "Show me").
    private func strumIt() {
        if firstShowing && !showMe {
            firstTask?.cancel()
            firstTask = nil
            firstShowing = false
        }
        hearTask?.cancel()
        demoRing = []
        store.stopLessonListening(owner: owner)
        store.audio.playTones(order.map { frequency($0.midi, store) }, together: false, noteMs: 380, gapMs: 30)
        sounding = true
        let strings = order.map(\.index)
        hearTask = Task { @MainActor in
            for string in strings {
                demoString = string
                try? await Task.sleep(for: .milliseconds(410))
                guard !Task.isCancelled else { return }
            }
            demoString = nil
            sounding = false
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            if !finished { listen() }
        }
    }

    private func finish(_ score: Double) {
        guard !finished else { return }
        finished = true
        onItem(.chord(chord), score)
        store.stopLessonListening(owner: owner)
        finishTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            done(score)
        }
    }
}

/// One string of a chord in the row over its box: the note it should ring in soft ink, ringed in the accent when
/// it's the one to pluck next, filled with a tick once heard, ringed in amber when the last strum left it silent; a
/// string the chord mutes is a faint cross.
struct LessonStringCheck: View {
    enum Mark: String { case muted, waiting, next, heard, silent }
    let note: String
    /// String number (1 is the thinnest), for VoiceOver.
    let number: Int
    let mark: Mark
    let accent: Color
    var side: CGFloat = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(mark == .muted ? "×" : note)
            .font(Typeface.label(side >= 36 ? .body : .footnote))
            .foregroundStyle(ink)
            .frame(width: side, height: side)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(rim, lineWidth: mark == .next || mark == .silent ? 2 : 1))
            .overlay(alignment: .topTrailing) { tick }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("String \(number), \(note)"))
            .accessibilityValue(spokenMark)
            // Locale-independent state for capture verification; spoken labels/values stay localized.
            .accessibilityIdentifier("lesson.chord.string.\(number).\(mark.rawValue)")
            .accessibilityHidden(mark == .muted)
    }

    private var spokenMark: String {
        switch mark {
        case .heard: return String(localized: "Got it")
        case .silent: return String(localized: "Not ringing")
        default: return ""
        }
    }

    /// The tick, popping onto the chip's shoulder as the string is heard.
    @ViewBuilder private var tick: some View {
        if mark == .heard {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 15, height: 15)
                .background(Circle().fill(Palette.ink))
                .offset(x: 3, y: -3)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
        }
    }

    private var ink: Color {
        switch mark {
        case .muted: return Palette.inkFaint
        case .waiting: return Palette.inkSoft
        case .next: return Palette.ink
        case .heard: return Palette.onAccent
        case .silent: return Palette.amber
        }
    }

    private var fill: Color {
        switch mark {
        case .muted: return Palette.surface.opacity(0.5)
        case .waiting, .next: return Palette.surface
        case .heard: return accent
        case .silent: return Palette.amber.opacity(0.14)
        }
    }

    private var rim: Color {
        switch mark {
        case .muted, .heard: return .clear
        case .waiting: return Palette.controlLine
        case .next: return accent
        case .silent: return Palette.amber
        }
    }
}

/// A playing step's bar at the bottom: "Hear it" across it, and after a few seconds "I played it" sliding in beside
/// it (if the microphone misses a right note, the player's word counts, for fewer stars).
struct LessonStepBar: View {
    let canSkip: Bool
    let accent: Color
    var sounding = false
    let skip: () -> Void
    let hear: () -> Void

    var body: some View {
        LessonActionBar {
            if canSkip {
                LessonBarButton(title: "I played it", action: skip)
                    .accessibilityIdentifier("lesson.override")
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            HearItButton(accent: accent, sounding: sounding, expands: true, action: hear)
        }
    }
}

// MARK: - Tune check before playing

/// Out-of-tune strings are the main reason a listening app marks right notes wrong, so the first
/// playing step of the day starts with a quick check of every open string (skippable). It runs from the lowest string
/// to the highest, left to right as the tuner's rail does (mirrored for a left-handed player, as that rail is), and
/// with VoiceOver it speaks the way: which string, how far off, tighten or loosen, in tune (`TuneCheckVoice`).
struct TuneCheckStep: View {
    let course: LearnCourse
    let accent: Color
    let done: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var index = 0
    @State private var cents: Double?
    @State private var holdStart: CFTimeInterval?
    @State private var burst = 0
    @State private var ringSide: CGFloat = 220
    /// Strings ticked off. It runs one ahead of `index` for a beat after a string locks: that string shows
    /// done (chip filled, note in the accent) before the next one takes over.
    @State private var tuned = 0
    @State private var finished = false
    /// The big note's opacity: a locked note fades out completely before the next string takes over.
    @State private var noteVisible = true
    /// The beat after a lock (the string showing done, then the hand-over); it ends with the step, so it never
    /// points the demo pitch or the tuner at a lesson string after the lesson has closed.
    @State private var lockTask: Task<Void, Never>?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    /// Spoken guidance for VoiceOver: the string, the cents and which way to turn.
    @State private var voice = TuneCheckVoice()

    /// A string just locked and is showing done before the check moves on.
    private var settling: Bool { tuned > index }

    /// One open string on the rail: its number (1 is the thinnest) and its note.
    private struct RailString {
        let number: Int
        let midi: Int
    }

    /// The open strings in the order the check runs: the lowest first, as the tuner's rail and every tuner checks
    /// them. A banjo's short drone string is left out.
    private var rail: [RailString] {
        let open = ChordStep.openStrings(course)
        let count = open.count
        // The open strings run lowest first: the one at `offset` is string `count - offset`.
        let all = open.enumerated()
            .filter { !(course.fretKind == "banjo" && $0.offset == 0) }
            .map { RailString(number: count - $0.offset, midi: $0.element) }
        return all.sorted { $0.midi != $1.midi ? $0.midi < $1.midi : $0.number > $1.number }
    }

    /// The chips run right to left for a left-handed player, as the tuner's rail does.
    private var mirrored: Bool { store.settings.handedness.isLeftHanded }

    /// The notes to check, in rail order.
    private var strings: [Int] { rail.map(\.midi) }

    /// String number (1 is the thinnest) of the string being checked.
    private var stringNumber: Int? {
        let rail = self.rail
        return index < rail.count ? rail[index].number : nil
    }

    static func needed(for course: LearnCourse) -> Bool {
        guard let instrument = course.instrument, course.fretKind != nil else { return false }
        return UserDefaults.standard.string(forKey: "tunecheck.\(instrument)") != Quests.dayKey(Date())
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 14) { teachingContent }
                            .padding(.bottom, 14)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    skipBar
                }
            } else {
                VStack(spacing: 14) {
                    teachingContent
                    skipBar
                }
            }
        }
        .onAppear { listen(); introduce(after: 1.4) }
        .onDisappear { lockTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; listen for the string again on return.
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !settling { listen() } }
    }

    // Keep the normal stack's order and spacing; accessibility text scrolls independently of its action.
    @ViewBuilder private var teachingContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            StepTitle("Quick tune check")
                .accessibilityIdentifier("lesson.tunecheck.title")
            Text("Pluck each open string. In-tune strings help Timbre hear you right.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("lesson.tunecheck.instructions")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 14)
        // Words and the note stay above the chips' sparks.
        .zIndex(1)
        stringChips
        Spacer(minLength: 0)
        listeningCluster
            .zIndex(1)
        Spacer(minLength: 0)
        if let number = stringNumber {
            // The string to pluck, lit on a strip of the neck.
            FretboardDiagram(strings: course.stringCount, dots: [Fretting(string: number, fret: 0)], frets: 4, accent: accent,
                             activeString: number, fretless: course.fretless, rowHeight: 15, pulsing: true, edges: StringEdges.of(course),
                             fingerboard: Fingerboard(instrument: course.instrument))
                .padding(.horizontal, Metrics.gutter)
                .transition(.opacity)
        }
        MicrophoneHint()
    }

    private var skipBar: some View {
        LessonActionBar {
            // The screen's one action: a pedal or the space bar moves past it too.
            LessonBarButton(title: "My strings are tuned — skip", role: .primary, identifier: "lesson.tunecheck.skip") { finish() }
        }
    }

    /// VoiceOver names the string to pluck: after the step's title has been read as it arrives, then as each string
    /// takes over.
    private func introduce(after delay: Double) {
        guard index < rail.count else { return }
        let string = rail[index]
        let current = index
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !finished, index == current else { return }
            voice.introduce(number: string.number, note: NoteName.pitchClass(string.midi))
        }
    }

    /// The string to tune, top to bottom: its note, the rings (rippling while it's heard, still between
    /// plucks) around an orb that points the way to turn, then the meter and what to do in words.
    /// Nothing sits on top of the rings.
    private var listeningCluster: some View {
        VStack(spacing: 12) {
            // One view throughout. The locked note turns to the accent, then fades out completely; only then does the
            // next string take over (chips, neck and note together) and its note fade in: never two at once, and
            // never the last string's note beside the next string's chip.
            Text(verbatim: index < strings.count ? NoteName.name(strings[index]) : "✓").font(Typeface.note(.hero))
                .foregroundStyle(settling ? accent : Palette.ink)
                .contentTransition(.identity)
                .opacity(noteVisible ? 1 : 0)
                .animation(Motion.quick, value: tuned)
            // Up to 220 pt; on short phones the space gives first, and the rings step aside when it's too small for them.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 220, maxHeight: 220)
                .onGeometryChange(for: CGFloat.self) { min($0.size.width, $0.size.height) } action: { ringSide = $0 }
                .overlay {
                    if ringSide >= 110 {
                        RingMotif(accent: orbColor, symbol: orbSymbol, active: reading.listening)
                            .opacity(0.9)
                    }
                }
            centsMeter
            Text(hint).font(.headline).foregroundStyle(meterColor)
                .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                .accessibilityIdentifier("lesson.tunecheck.hint")
        }
        .layoutPriority(1)
    }

    /// What the check shows for the string being tuned, read once from the latest reading: the orb's symbol and
    /// colour, the meter and the hint all come from it, so they can never disagree (an amber tick beside "Tune up a
    /// little").
    private enum Reading: Equatable {
        case waiting, flat, sharp, inTune, locked
        /// A pitch is heard and still being judged (the rings ripple).
        var listening: Bool { self == .flat || self == .sharp || self == .inTune }
    }

    /// Within this many cents the string is in tune: the hold that locks it uses the same band.
    private static let inTuneCents = 8.0

    private var reading: Reading {
        if settling { return .locked }
        guard let cents else { return .waiting }
        if abs(cents) <= Self.inTuneCents { return .inTune }
        return cents < 0 ? .flat : .sharp
    }

    /// The orb in the rings: which way to turn the peg, a check in tune, a waveform while waiting for a pluck.
    private var orbSymbol: String {
        switch reading {
        case .waiting: return "waveform"
        case .flat: return "arrow.up"
        case .sharp: return "arrow.down"
        case .inTune, .locked: return "checkmark"
        }
    }

    /// The orb waits in the accent; while a pitch is heard it takes the meter's colour.
    private var orbColor: Color { reading == .waiting ? accent : meterColor }

    /// Done strings filled, the current one ringed; the ones still to come in soft ink on a raised chip
    /// with a hairline (readable on the green wash, well over 3:1). Each chip carries its string's number under
    /// the note, as the neck strip numbers its rows (the two E strings never look alike). A string fills and
    /// bursts the moment it locks; the ring moves on to the next a beat later, with the note and the neck.
    private var stringChips: some View {
        let ordered = Array(rail.enumerated())
        let shown = mirrored ? Array(ordered.reversed()) : ordered
        let burstAt = mirrored ? max(0, rail.count - tuned) : max(0, tuned - 1)
        return HStack(spacing: 8) {
            ForEach(shown, id: \.offset) { i, string in
                stringChip(string, done: i < tuned, current: i == index && i >= tuned)
            }
        }
        // The chips keep their size: the note and the number stop growing before they would crowd the chip.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(Motion.pluck, value: index)
        .animation(Motion.pluck, value: tuned)
        .background(alignment: .leading) {
            // A local reward behind the newly tuned chip, not a second full-size listening orb.
            // Keep its original canvas/origin, but fade only the decoration into a reserved band:
            // ring:false still draws inner rings and outer nodes, so zIndex alone cannot protect text.
            SparkBurst(trigger: burst, color: accent, reach: 70, startFraction: 0.32, ring: false)
                .frame(width: 140, height: 140)
                .mask { Self.chipRewardMask }
                .offset(x: CGFloat(burstAt) * (Self.chip + 8) + Self.chip / 2 - 70)
        }
        // Stable even between rewards: no layout jump when a string locks, and no text is masked.
        .padding(.vertical, Self.chipRewardFade)
        // Strings lie in space, not in reading order: right-to-left languages don't turn them round.
        .environment(\.layoutDirection, .leftToRight)
    }

    private static let chip: CGFloat = 44
    static let chipRewardFade: CGFloat = 8
    static var chipRewardHeight: CGFloat { chip + 2 * chipRewardFade }

    /// Only the reward is masked. The opaque centre covers the chip; the outer eight points fade
    /// to clear before the band ends, leaving the stack's existing 14-point text gap untouched.
    static var chipRewardMask: some View {
        let edge = chipRewardFade / chipRewardHeight
        return LinearGradient(stops: [.init(color: .clear, location: 0),
                                      .init(color: .white, location: edge),
                                      .init(color: .white, location: 1 - edge),
                                      .init(color: .clear, location: 1)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: chipRewardHeight)
    }

    private func stringChip(_ string: RailString, done: Bool, current: Bool) -> some View {
        let ink = done ? Palette.onAccent : current ? Palette.ink : Palette.inkSoft
        return VStack(spacing: -1) {
            Text(NoteName.pitchClass(string.midi)).font(Typeface.label(.body))
            Text(verbatim: "\(string.number)").font(Typeface.number(.caption)).opacity(0.75)
        }
        .foregroundStyle(ink)
        .lineLimit(1)
        .frame(width: Self.chip, height: Self.chip)
        .background(Circle().fill(done ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.surface)))
        .overlay(Circle().strokeBorder(current ? accent : done ? .clear : Palette.controlLine, lineWidth: current ? 2 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("String \(string.number)"))
        .accessibilityValue(Text(verbatim: NoteName.pitchClass(string.midi)))
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private var meterColor: Color {
        switch reading {
        case .waiting: return Palette.inkSoft
        case .flat, .sharp: return Palette.amber
        case .inTune, .locked: return accent
        }
    }

    private var hint: LocalizedStringKey {
        switch reading {
        case .waiting: return "Pluck the string"
        case .flat: return "Tune up a little"
        case .sharp: return "Tune down a little"
        case .inTune: return "In tune — hold it"
        case .locked: return "In tune"
        }
    }

    private var centsMeter: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                Capsule().fill(accent.opacity(0.35)).frame(width: w * 16 / 100, height: 8).offset(x: w / 2 - w * 8 / 100)
                if let cents {
                    Capsule().fill(meterColor).frame(width: 6, height: 30)
                        .offset(x: w / 2 + w * CGFloat(max(-50, min(50, cents))) / 100 - 3)
                        .shadow(color: meterColor.opacity(0.7), radius: 8)
                        .animation(.interpolatingSpring(stiffness: 220, damping: 22), value: cents)
                }
            }
            .frame(height: 30)
        }
        .frame(height: 30)
        .padding(.horizontal, 40)
        .accessibilityHidden(true)
    }

    private func listen() {
        guard index < strings.count else { return finish() }
        store.gameTargetHz = frequency(strings[index], store)
        store.startLessonListening(owner: owner) { hz, _ in
            // While a locked string shows done, readings wait for the next one.
            guard !finished, !settling else { return }
            guard index < strings.count, let hz else { cents = nil; holdStart = nil; voice.quiet(); return }
            let target = frequency(strings[index], store)
            let off = PitchMath.cents(target: target, measured: hz)
            guard abs(off) < 300 else { cents = nil; voice.quiet(); return }
            cents = off
            let now = CACurrentMediaTime()
            voice.step(cents: off, inTune: abs(off) <= Self.inTuneCents, now: now)
            if abs(off) <= Self.inTuneCents {
                if holdStart == nil { holdStart = now }
                if now - (holdStart ?? now) >= 0.5 { lock() }
            } else { holdStart = nil }
        }
    }

    /// The string is in tune: it shows done at once (chip filled, sparks, the note in the accent, "In tune").
    /// A beat later its note fades out completely, and only then does the next string take over, so the chips, the
    /// note and the neck move on together and the old note is never on screen beside the new chip.
    private func lock() {
        holdStart = nil; cents = 0
        SoundFX.shared.play(.hit); Haptics.shared.lock(); burst += 1
        voice.locked()
        tuned = index + 1
        lockTask?.cancel()
        lockTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, !finished else { return }
            withAnimation(.easeIn(duration: 0.14)) { noteVisible = false }
            try? await Task.sleep(for: .milliseconds(170))
            guard !Task.isCancelled, !finished else { return }
            cents = nil
            index = tuned
            if index >= strings.count { finish(); return }
            store.gameTargetHz = frequency(strings[index], store)
            withAnimation(Motion.fade) { noteVisible = true }
            introduce(after: 0.5)
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        lockTask?.cancel()
        store.stopLessonListening(owner: owner)
        if let instrument = course.instrument { UserDefaults.standard.set(Quests.dayKey(Date()), forKey: "tunecheck.\(instrument)") }
        done()
    }
}

/// VoiceOver for the tune check (and any check that tunes one string at a time): the string to pluck when it takes
/// over ("String 4, D"), then while it is heard, about every 1.5 s, how far off it is and which way to turn the peg
/// ("12 cents flat. Tighten"), "Hold it…" inside the band, and "In tune" when it locks. Announcements queue behind
/// what VoiceOver is saying rather than cutting it off. A plain class polled with each reading, so speaking never
/// redraws a view; silent without VoiceOver.
@MainActor
final class TuneCheckVoice {
    /// Seconds between spoken updates while the string is heard.
    static let interval: TimeInterval = 1.5
    /// A pitch must hold this long before the first update, so a passing blip stays quiet.
    static let settle: TimeInterval = 0.5
    private var heldSince: TimeInterval?
    private var lastSpoken: TimeInterval = 0

    /// The string to tune now.
    func introduce(number: Int, note: String) {
        heldSince = nil
        lastSpoken = 0
        Self.post(String(localized: "String \(number), \(note)"))
    }

    /// A reading of the string: `cents` off its pitch (negative flat); `inTune` inside the lock band.
    func step(cents: Double, inTune: Bool, now: TimeInterval) {
        let held = heldSince ?? now
        heldSince = held
        guard now - held >= Self.settle, now - lastSpoken >= Self.interval else { return }
        lastSpoken = now
        Self.post(Self.words(cents: cents, inTune: inTune))
    }

    /// No pitch heard: the next one starts its wait again.
    func quiet() { heldSince = nil }

    func locked() {
        heldSince = nil
        lastSpoken = 0
        Self.post(String(localized: "In tune"))
    }

    /// "12 cents flat. Tighten", "8 cents sharp. Loosen", or "Hold it…" inside the band.
    static func words(cents: Double, inTune: Bool) -> String {
        if inTune { return String(localized: "Hold it…") }
        let amount = Int(abs(cents).rounded())
        if cents < 0 { return String(localized: "\(amount) cents flat") + ". " + String(localized: "Tighten") }
        return String(localized: "\(amount) cents sharp") + ". " + String(localized: "Loosen")
    }

    private static func post(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let queued = NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: true])
        UIAccessibility.post(notification: .announcement, argument: queued)
    }
}

/// VoiceOver for the notes step: the note to play next as each one lands ("Next: D, string 4, open"), and while a
/// pitch is held that isn't the note in tune yet, on the tuner's cadence (`TunerAnnouncer`: after half a second, then
/// about every 1.5 s), which way to go ("A little flat. Tighten", "That’s G"). The next note cuts off whatever was being
/// said, so a quick player never hears a stale one; guidance queues behind it, and waits a full interval after it. A
/// plain class fed with each reading, so speaking never redraws a view; silent without VoiceOver.
@MainActor
final class NoteStepVoice {
    private var heldSince: TimeInterval?
    private var lastSpoken: TimeInterval = 0
    private var lastWords: String?

    /// The note to play now, the one before it having landed.
    func next(_ phrase: String, now: TimeInterval) {
        heldSince = nil
        lastWords = nil
        lastSpoken = now
        Self.post(String(localized: "Next: \(phrase)"), queued: false)
    }

    /// A reading: `words` while a pitch that isn't the note in tune is held, nil otherwise (silence, or in tune).
    func heard(_ words: String?, now: TimeInterval) {
        guard let words else {
            heldSince = nil
            lastWords = nil
            return
        }
        if words != lastWords {
            heldSince = now
            lastWords = words
        }
        guard let held = heldSince, now - held >= TunerAnnouncer.settle, now - lastSpoken >= TunerAnnouncer.interval else { return }
        lastSpoken = now
        Self.post(words, queued: true)
    }

    private static func post(_ text: String, queued: Bool) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let announcement = NSAttributedString(string: text, attributes: [.accessibilitySpeechQueueAnnouncement: queued])
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

/// The chords of a progression in a row, in the picture the learner chose (the chart or the player's view); the one
/// to play now is big, the next one waits beside it.
struct ProgressionStrip: View {
    let chords: [ChordSpec]
    let bars: [Int]
    let current: Int
    let accent: Color
    /// Names the outer strings under the chord to play now (on the chart; the small neck numbers its lanes instead).
    var edges: StringEdges?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ChordPictureView(chord: chords[min(current, chords.count - 1)], accent: accent, edges: edges, compact: true).frame(width: 140)
                .id(current).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if current + 1 < chords.count {
                VStack(spacing: 4) {
                    Text("Next").font(.caption).foregroundStyle(Palette.inkFaint)
                    ChordPictureView(chord: chords[current + 1], accent: Palette.inkSoft, compact: true).frame(width: 84).opacity(0.7)
                }
            }
        }
        .animation(Motion.settle, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chords.map(\.name).joined(separator: ", ")))
    }
}
