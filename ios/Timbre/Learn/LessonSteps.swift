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
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var heard: HeardNote?
    @State private var hold = 0.0
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false
    /// Wrong notes heard while the current note was the target.
    @State private var wrongHere = 0

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
        VStack(spacing: 16) {
            header
            if isSequence { sequenceChips }
            Spacer(minLength: 0)
            if isSequence { prompt }
            noteRing
            Spacer(minLength: 0)
            targetPicture
            MicrophoneHint()
            HStack {
                // If the microphone misses a right note, the player's word counts (for fewer stars).
                Button("I played it") { finish(score: 0.6) }.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft).opacity(canSkip ? 1 : 0).disabled(!canSkip)
                    .accessibilityIdentifier("lesson.override")
                Spacer()
                Button { hear() } label: { Label("Hear it", systemImage: "speaker.wave.2.fill") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                    .accessibilityIdentifier("lesson.hear")
            }
            .padding(.horizontal, 24).padding(.bottom, 18)
        }
        .onAppear { listen(); Task { try? await Task.sleep(for: .seconds(6)); canSkip = true } }
        .onDisappear { store.stopLessonListening(owner: owner) }
    }

    private var isSequence: Bool { notes.count > 1 }

    /// "Play this note" names the note in the ring: over a single note it heads the step; in a sequence it
    /// sits right on the ring (the one to play now), and the lesson's hint heads the whole run instead.
    private var prompt: some View {
        Text(course.instrument == "voice" ? LocalizedStringKey("Sing this note") : LocalizedStringKey("Play this note"))
            .font(Typeface.label(15)).foregroundStyle(Palette.inkSoft)
    }

    private var header: some View {
        VStack(spacing: 6) {
            if !isSequence { prompt }
            if let hint {
                Text(hint.localized)
                    .font(isSequence ? Typeface.label(15) : .subheadline)
                    .foregroundStyle(isSequence ? Palette.ink : Palette.inkFaint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
            }
        }
        .padding(.top, 10)
    }

    private var noteRing: some View {
        ZStack {
            HoldRing(progress: finished ? 1 : hold, tint: ringTint)
            VStack(spacing: 4) {
                noteLetter
                Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(ringTint).contentTransition(.opacity)
            }
        }
        // Up to 250 pt, smaller on short phones so the neck below still fits.
        .aspectRatio(1, contentMode: .fit)
        .frame(minWidth: 170, maxWidth: 250, minHeight: 170, maxHeight: 250)
        .background { ringBurst }
        .layoutPriority(1)
        // Below its neighbours, so the sparks pass behind the prompt and the chips, never over words.
        .zIndex(-1)
        .accessibilityElement(children: .combine)
    }

    /// A shockwave leaving the ring's edge when a note lands: drawn on a canvas twice the ring's size
    /// (so nothing is cut off) and behind the ring, so it never crosses the note or "Hold it…".
    private var ringBurst: some View {
        GeometryReader { geometry in
            SparkBurst(trigger: burst, color: accent, startFraction: 0.5)
                .frame(width: geometry.size.width * 2, height: geometry.size.height * 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }

    /// The note to play, popping in as the last one is ticked off (a fresh view each time, so a reading
    /// arriving mid-change can never leave it half drawn).
    private var noteLetter: some View {
        let name = NoteName.name(shown?.midi ?? 60)
        return ZStack {
            Text(name.dropLast(name.last?.isNumber == true ? 1 : 0)).font(Typeface.note(88)).foregroundStyle(Palette.ink)
                .id(judge.index)
                .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .opacity))
        }
        .animation(Motion.pluck, value: judge.index)
    }

    /// Where to play it: a strip of the neck with the target string and fret lit and breathing (fretted
    /// and fingerboard courses), or the notes on a staff with the current one lit (voice and any instrument).
    @ViewBuilder private var targetPicture: some View {
        if let at = shownFretting {
            VStack(spacing: 6) {
                FretboardDiagram(strings: course.stringCount, dots: [at], frets: stripFrets, accent: accent, activeString: at.string,
                                 fretless: course.fretless, rowHeight: 18, pulsing: !finished, edges: StringEdges.of(course))
                    .padding(.horizontal, 18)
                Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)"))
                    .font(Typeface.label(13)).foregroundStyle(accent)
                    .contentTransition(.opacity)
            }
            .animation(Motion.quick, value: judge.index)
        } else if course.fretKind == nil, !notes.isEmpty {
            StaffView(notes: notes.map(\.midi), clef: staffClef, accent: accent, activeIndex: finished ? nil : min(judge.index, notes.count - 1))
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
                .padding(.horizontal, 20)
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
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(14))
                    .foregroundStyle(state == 2 ? Palette.onAccent : state == 1 ? Palette.ink : Palette.inkSoft)
                    .frame(minWidth: 38, minHeight: 34)
                    .background(Capsule().fill(state == 2 ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.surface)))
                    .overlay(Capsule().strokeBorder(state == 1 ? accent : state == 0 ? Color.white.opacity(0.14) : .clear, lineWidth: state == 1 ? 1.5 : 1))
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
            switch judge.update(time: CACurrentMediaTime(), midi: note?.midi, cents: note?.cents) {
            case .holding(let p)?: hold = p
            case .hit(let index)?:
                hold = 0; burst += 1
                // Clean is 1; each wrong note on the way halves, thirds… it (as the step's own accuracy).
                if notes.indices.contains(index) { onItem(course.practiceItem(for: notes[index]), 1 / Double(1 + wrongHere)) }
                wrongHere = 0
                SoundFX.shared.play(.correct); Haptics.shared.lock()
                if judge.isFinished { finish(score: judge.accuracy) }
                else if let next = current { store.gameTargetHz = frequency(next.midi, store) }
            case .wrong?:
                wrongHere += 1
                hold = max(0, hold - 0.1)
            default: hold = max(0, hold - 0.1)
            }
        }
    }

    private func hear() {
        guard let current else { return }
        store.stopLessonListening(owner: owner)
        store.audio.playTones([frequency(current.midi, store)], together: false, noteMs: 900, gapMs: 0)
        Task { try? await Task.sleep(for: .milliseconds(1100)); if !finished { listen() } }
    }

    private func finish(score: Double) {
        guard !finished else { return }
        finished = true
        // Notes the microphone never confirmed ("I played it") count as shaky.
        for note in notes[min(judge.index, notes.count)...] { onItem(course.practiceItem(for: note), 0.5) }
        store.stopLessonListening(owner: owner)
        Task { try? await Task.sleep(for: .milliseconds(700)); done(score) }
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

struct ChordStep: View {
    let chord: ChordSpec
    let course: LearnCourse
    let accent: Color
    /// How the chord went (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var verified: Set<Int> = []
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false
    @State private var hearing: String?
    @State private var matchedFrames = 0
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
                Text(finished ? LocalizedStringKey("Every string rings") : LocalizedStringKey("Strum it, or pluck each string")).font(Typeface.label(16)).foregroundStyle(Palette.inkSoft)
                    .accessibilityIdentifier("lesson.chord")
                Text("Fingers in place, then let it ring.").font(.subheadline).foregroundStyle(Palette.inkFaint)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            ZStack {
                // Behind the card: the sparks fly out from under its edges, never over the chord's name.
                SparkBurst(trigger: burst, color: accent, startFraction: 0.6)
                ChordDiagram(chord: chord, accent: accent, ringing: verified, landing: true, edges: StringEdges.of(course))
                    .frame(maxWidth: 260)
                    .padding(22)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.stageRaised))
                    .shadow(color: finished ? accent.opacity(0.45) : .clear, radius: 26)
            }
            if let hearing, !finished {
                Text("Hearing \(hearing)").font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(Palette.stageRaised))
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            MicrophoneHint()
            HStack {
                Button("I played it") { finish(0.6) }.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft).opacity(canSkip ? 1 : 0).disabled(!canSkip)
                    .accessibilityIdentifier("lesson.override")
                Spacer()
                Button { strumIt() } label: { Label("Hear it", systemImage: "speaker.wave.2.fill") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            .padding(.horizontal, 24).padding(.bottom, 18)
        }
        .onAppear { listen(); Task { try? await Task.sleep(for: .seconds(6)); canSkip = true } }
        .onDisappear { store.stopLessonListening(owner: owner) }
    }

    private func listen() {
        if let first = judge.current { store.gameTargetHz = frequency(first, store) }
        // A recognised strum of the right chord counts at once; plucking string by string is the fallback.
        let target = ChordTarget(root: chord.root, formulaId: chord.quality)
        let analyzer = target.map { target in
            LessonAnalyzer(chords: true, target: target, onChord: { estimate, matched in
                guard !finished else { return }
                withAnimation(Motion.quick) { hearing = estimate?.target.symbol }
                matchedFrames = matched ? matchedFrames + 1 : 0
                if matchedFrames >= 3 {
                    withAnimation(Motion.pluck) { verified = Set(order.map(\.index)) }
                    burst += 1; SoundFX.shared.play(.correct); Haptics.shared.lock()
                    finish(1)
                }
            })
        }
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
    }

    private func strumIt() {
        store.stopLessonListening(owner: owner)
        store.audio.playTones(order.map { frequency($0.midi, store) }, together: false, noteMs: 380, gapMs: 30)
        Task { try? await Task.sleep(for: .milliseconds(order.count * 410 + 300)); if !finished { listen() } }
    }

    private func finish(_ score: Double) {
        guard !finished else { return }
        finished = true
        onItem(.chord(chord), score)
        store.stopLessonListening(owner: owner)
        Task { try? await Task.sleep(for: .milliseconds(900)); done(score) }
    }
}

// MARK: - Rhythm: tap or strum on the pattern

struct RhythmStep: View {
    enum Mode { case tap, strum(ChordSpec?), progression([ChordSpec], [Int]) }
    let mode: Mode
    let pattern: [Double]
    let bpm: Double
    let bars: Int
    /// Beats in a bar when the lesson sets it (3/4, 6/8 in eighths); otherwise 4, or longer if the pattern needs it.
    var meter: Int?
    /// On an instrument course a tap step is played on the instrument, so hands stay on the strings.
    var hearsInstrument = false
    /// Strummed instruments: the pattern reads as down and up strokes, and a pick sweeps the strings.
    var strums = false
    /// Strings on the course instrument, drawn under the sweep.
    var strings = 0
    /// The thinnest and thickest strings, named on the sweep and the chord boxes.
    var edges: StringEdges?
    let accent: Color
    /// Called when the step is passed by tapping because the microphone can't hear the instrument.
    var onPractice: () -> Void = {}
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var startTime: CFTimeInterval = 0
    @State private var appeared = CACurrentMediaTime()
    @State private var hits: [Double] = []
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var pulse = 0
    @State private var score = 0.0
    /// No microphone (refused, or it failed to start): the screen stands in for the instrument.
    @State private var micOff = false

    enum Phase { case ready, playing, done }
    private var beatsPerBar: Int { meter ?? max(4, Int((pattern.max() ?? 3) + 1)) }
    private var spb: Double { 60 / bpm }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var barLength: Double { Double(beatsPerBar) * spb }
    private var expected: [Double] { (0..<bars).flatMap { bar in pattern.map { countIn + (Double(bar * beatsPerBar) + $0) * spb } } }
    private var isTap: Bool { if case .tap = mode { return true } else { return false } }
    /// The instrument is what counts here (strum steps, and tap steps on an instrument course).
    private var instrumentStep: Bool { !isTap || hearsInstrument }
    /// Tapping the screen: the rhythm course's own steps, or an instrument step without a microphone.
    private var tapping: Bool { !instrumentStep || micOff }
    /// An instrument step passed by tapping: practice mode, one star at most.
    private var practice: Bool { instrumentStep && micOff }
    private var sweepStyle: StrumSweep.Style { strums ? .strum : .pluck }
    /// Strum and progression steps play over drums, a bass on the roots and a pad on the chords.
    private var band: BandArrangement? {
        let reference = store.settings.referencePitchHz
        switch mode {
        case .tap: return nil
        case .strum(let chord):
            return BandArrangement.chords(chord.map { [$0] } ?? [], bars: [bars], pattern: pattern, bpm: bpm, beatsPerBar: beatsPerBar, reference: reference)
        case .progression(let chords, let lengths):
            return BandArrangement.chords(chords, bars: lengths, pattern: pattern, bpm: bpm, beatsPerBar: beatsPerBar, reference: reference)
        }
    }

    private var title: LocalizedStringKey {
        if tapping { return "Tap on the dots" }
        return strums ? "Strum on the arrows" : "Play on the dots"
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            if case .strum(let chord?) = mode { ChordDiagram(chord: chord, accent: accent, landing: true, edges: edges).frame(maxWidth: 150) }
            if case .progression(let chords, let lengths) = mode {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    ProgressionStrip(chords: chords, bars: lengths, current: currentChord(lengths), accent: accent, edges: edges)
                }
            }
            meterView
            Spacer(minLength: 0)
            stage
            Spacer(minLength: 0)
            MicrophoneHint()
            controls
        }
        .onAppear {
            micOff = LessonMicrophone.unavailable(store.audio)
            store.audio.prepareBand(band)
        }
        .onReceive(store.audio.$permissionDenied) { denied in if denied { micOff = true } }
        .onReceive(store.audio.$error) { error in
            // The microphone failed to start mid-take: the screen takes over.
            if error != nil, phase == .playing, instrumentStep, !store.audio.running { micOff = true }
        }
        .onDisappear { store.audio.stopMetronome(); store.audio.stopBand(); store.stopLessonListening(owner: owner) }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(title).font(Typeface.display(26)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text("\(Int(bpm)) BPM · \(bars) bars").font(.subheadline).foregroundStyle(Palette.inkSoft)
            if practice || !isTap {
                HStack(spacing: 8) {
                    if practice { PracticeModeTag() }
                    if !isTap { BandControls(audio: store.audio, accent: accent) }
                }
                .padding(.top, 2)
            }
        }
        .padding(.top, 14)
        .animation(Motion.quick, value: micOff)
    }

    /// The bar counter (or the count-in) over the pattern with its playhead and judged hits.
    private var meterView: some View {
        TimelineView(.animation(paused: phase != .playing)) { _ in
            let now = CACurrentMediaTime()
            let running = phase == .playing
            let elapsed = running ? now - startTime - countIn : 0
            // Ready shows bar 1 (the clock hasn't started), done the last bar with its grades.
            let bar = phase == .done ? max(0, bars - 1) : min(max(0, bars - 1), max(0, Int(elapsed / barLength)))
            let within: Double? = running && elapsed >= 0 ? min(1, (elapsed - Double(bar) * barLength) / barLength) : nil
            let barGrades = Dictionary(uniqueKeysWithValues: grades.compactMap { i, g in i / pattern.count == bar ? (i % pattern.count, g) : nil })
            VStack(spacing: 10) {
                if running, elapsed < 0 {
                    Text("\(Int(-elapsed / spb) + 1)").font(Typeface.note(64)).foregroundStyle(accent).contentTransition(.numericText())
                } else if phase == .done {
                    Color.clear.frame(height: 18)
                } else {
                    Text("Bar \(bar + 1) of \(bars)").font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
                }
                RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: within, judged: barGrades, arrows: !isTap || strums)
                    .padding(.horizontal, 16)
                    .onChange(of: Int(now * 30)) { _, _ in expire(now: now) }
            }
        }
        .frame(height: 170)
    }

    /// The middle of the screen: the score when done, the tap pad when tapping, else the stroke to make,
    /// a pick sweeping the strings in time with the click.
    @ViewBuilder private var stage: some View {
        if phase == .done {
            Text("\(Int((score * 100).rounded()))% on the beat").font(Typeface.display(28)).foregroundStyle(ScoreTint.color(score))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else if tapping {
            tapPad
        } else {
            TimelineView(.animation(paused: reduceMotion)) { _ in
                StrumSweep(pattern: pattern, beatsPerBar: beatsPerBar, strings: max(1, strings), style: sweepStyle, accent: accent,
                           secondsPerBeat: spb, time: sweepTime(CACurrentMediaTime()), bars: phase == .playing ? bars : nil, edges: edges)
            }
            // Tall enough for the stroke rail above the strings (`StrumSweep`), filling the room under the bar.
            .frame(maxWidth: .infinity, maxHeight: 360)
            .padding(.horizontal, 24)
            .layoutPriority(1)
        }
    }

    private var tapPad: some View {
        Button { tapped() } label: {
            Circle().fill(accent.opacity(0.14)).overlay(Circle().strokeBorder(accent, lineWidth: 3))
                .overlay(Image(systemName: "hand.tap.fill").font(.system(size: 40)).foregroundStyle(accent))
                .frame(width: 170, height: 170)
                .scaleEffect(pulse % 2 == 0 ? 1 : 0.94)
        }
        .buttonStyle(.plain)
        .disabled(phase != .playing)
        .accessibilityLabel("Tap")
        .accessibilityIdentifier("lesson.tap")
    }

    @ViewBuilder private var controls: some View {
        switch phase {
        case .ready: StepButton(title: "Start", accent: accent) { start() }
        case .playing: StepButton(title: "Listening…", accent: accent, enabled: false) {}
        case .done:
            HStack(spacing: 10) {
                Button("Try again") { start() }.font(Typeface.label(16)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
                StepButton(title: "Continue", accent: accent) {
                    if practice { onPractice() }
                    done(score)
                }
                .padding(.horizontal, -20).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
    }

    /// Seconds since beat 1 for the sweep: the real clock while playing (so it lands with the click),
    /// a preview loop at the step's tempo before Start; nil holds it still.
    private func sweepTime(_ now: CFTimeInterval) -> Double? {
        guard !reduceMotion else { return nil }
        switch phase {
        case .playing: return now - startTime - countIn
        case .ready: return now - appeared
        case .done: return nil
        }
    }

    /// Which chord of a progression is under the playhead (by bar).
    private func currentChord(_ lengths: [Int]) -> Int {
        guard phase == .playing else { return 0 }
        let elapsed = CACurrentMediaTime() - startTime - countIn
        let bar = max(0, Int(elapsed / barLength))
        var total = 0
        for (i, n) in lengths.enumerated() { total += n; if bar < total { return i } }
        return max(0, lengths.count - 1)
    }

    private func start() {
        hits = []; grades = [:]; score = 0
        startTime = CACurrentMediaTime()
        withAnimation(Motion.quick) { phase = .playing }
        store.audio.setMetronome(bpm: Int(bpm), beats: beatsPerBar, subdivision: 1, accents: true)
        // From the bar after the count-in, on headphones; the speaker keeps the click alone.
        store.audio.playBand(band, firstBar: 1)
        // Only the instrument counts on an instrument step; the screen is the fallback without a microphone.
        if instrumentStep && !micOff {
            let analyzer = LessonAnalyzer(chords: false, onOnset: { time in register(time) })
            store.startLessonListening(owner: owner, lowHz: 60, highHz: 1400, analyzer: analyzer) { _, _ in }
        }
    }

    private func tapped() {
        guard tapping else { return }
        pulse += 1
        Haptics.shared.selection()
        register(CACurrentMediaTime())
    }

    private func register(_ time: CFTimeInterval) {
        guard phase == .playing else { return }
        let t = time - startTime
        let times = expected
        guard let index = times.indices.filter({ grades[$0] == nil }).min(by: { abs(times[$0] - t) < abs(times[$1] - t) }) else { return }
        let offset = abs(times[index] - t)
        guard offset <= 0.18 else { return }
        grades[index] = offset <= 0.05 ? .perfect : offset <= 0.1 ? .good : .ok
        SoundFX.shared.play(.hit)
    }

    private func expire(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // Beats are where the click is heard (after engine start and output latency), not where Start was tapped.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        let t = now - startTime
        for (i, time) in expected.enumerated() where grades[i] == nil && t > time + 0.2 { grades[i] = .miss }
        if t > (expected.last ?? 0) + 0.4 { finish() }
    }

    private func finish() {
        let points = grades.values.reduce(0.0) { $0 + ($1 == .perfect ? 1 : $1 == .good ? 0.8 : $1 == .ok ? 0.5 : 0) }
        score = expected.isEmpty ? 1 : points / Double(expected.count)
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: score >= 0.7)
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { phase = .done }
        SoundFX.shared.play(score >= 0.7 ? .correct : .wrong)
    }
}

// MARK: - Tune check before playing

/// Out-of-tune strings are the main reason a listening app marks right notes wrong, so the first
/// playing step of the day starts with a quick check of every open string (skippable).
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

    private var strings: [Int] { ChordStep.openStrings(course).enumerated().filter { !(course.fretKind == "banjo" && $0.offset == 0) }.map(\.element) }

    /// String number (1 is the highest) of the string being checked; the open strings run lowest first.
    private var stringNumber: Int? {
        guard index < strings.count else { return nil }
        let skipped = course.fretKind == "banjo" ? 1 : 0
        return ChordStep.openStrings(course).count - (index + skipped)
    }

    static func needed(for course: LearnCourse) -> Bool {
        guard let instrument = course.instrument, course.fretKind != nil else { return false }
        return UserDefaults.standard.string(forKey: "tunecheck.\(instrument)") != Quests.dayKey(Date())
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Quick tune check").font(Typeface.display(28)).foregroundStyle(Palette.ink)
                Text("Pluck each open string. In-tune strings help Timbre hear you right.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
            }
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
                                 activeString: number, fretless: course.fretless, rowHeight: 15, pulsing: true, edges: StringEdges.of(course))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
            MicrophoneHint()
            Button("My strings are tuned — skip") { finish() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                .padding(.bottom, 18)
                .accessibilityIdentifier("lesson.tunecheck.skip")
        }
        .onAppear { listen() }
        .onDisappear { store.stopLessonListening(owner: owner) }
    }

    /// The string to tune, top to bottom: its note, the rings (rippling while it's heard, still between
    /// plucks) around an orb that points the way to turn, then the meter and what to do in words.
    /// Nothing sits on top of the rings.
    private var listeningCluster: some View {
        VStack(spacing: 12) {
            // A fresh view per string that pops in, so a reading landing mid-change can't freeze it half drawn.
            ZStack {
                Text(index < strings.count ? NoteName.name(strings[index]) : "✓").font(Typeface.note(64)).foregroundStyle(Palette.ink)
                    .id(index)
                    .transition(.asymmetric(insertion: .scale(scale: 0.7).combined(with: .opacity), removal: .opacity))
            }
            .animation(Motion.pluck, value: index)
            // Up to 220 pt; on short phones the space gives first, and the rings step aside when it's too small for them.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 220, maxHeight: 220)
                .onGeometryChange(for: CGFloat.self) { min($0.size.width, $0.size.height) } action: { ringSide = $0 }
                .overlay {
                    if ringSide >= 110 {
                        RingMotif(accent: cents == nil ? accent : meterColor, symbol: orbSymbol, active: cents != nil)
                            .opacity(0.9)
                    }
                }
            centsMeter
            Text(hint).font(.headline).foregroundStyle(meterColor)
        }
        .layoutPriority(1)
    }

    /// The orb in the rings: which way to turn the peg, a check in tune, a waveform while waiting for a pluck.
    private var orbSymbol: String {
        guard let cents else { return "waveform" }
        if abs(cents) <= 8 { return "checkmark" }
        return cents < 0 ? "arrow.up" : "arrow.down"
    }

    /// Done strings filled, the current one ringed; the ones still to come in soft ink on a raised chip
    /// with a hairline (readable on the green wash, well over 3:1). A string bursts as it's ticked off.
    private var stringChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(strings.enumerated()), id: \.offset) { i, midi in
                Text(NoteName.pitchClass(midi)).font(Typeface.label(15))
                    .foregroundStyle(i < index ? Palette.onAccent : i == index ? Palette.ink : Palette.inkSoft)
                    .frame(width: Self.chip, height: Self.chip)
                    .background(Circle().fill(i < index ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.surface)))
                    .overlay(Circle().strokeBorder(i == index ? accent : i > index ? Color.white.opacity(0.14) : .clear, lineWidth: i == index ? 2 : 1))
            }
        }
        .animation(Motion.pluck, value: index)
        .background(alignment: .leading) {
            // Behind the chips, centred on the one just tuned (outside the animation, so it doesn't slide):
            // sparks leave from the chip's rim, no ring, so nothing reaches across the title or the note.
            SparkBurst(trigger: burst, color: accent, reach: 70, startFraction: 0.32, ring: false)
                .frame(width: 140, height: 140)
                .offset(x: CGFloat(max(0, index - 1)) * (Self.chip + 8) + Self.chip / 2 - 70)
        }
    }

    private static let chip: CGFloat = 44

    private var meterColor: Color {
        guard let cents else { return Palette.inkSoft }
        return abs(cents) <= 8 ? accent : Palette.amber
    }

    private var hint: LocalizedStringKey {
        guard let cents else { return "Pluck the string" }
        if abs(cents) <= 8 { return "In tune — hold it" }
        return cents < 0 ? "Tune up a little" : "Tune down a little"
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
            guard index < strings.count, let hz else { cents = nil; holdStart = nil; return }
            let target = frequency(strings[index], store)
            let off = PitchMath.cents(target: target, measured: hz)
            guard abs(off) < 300 else { cents = nil; return }
            cents = off
            let now = CACurrentMediaTime()
            if abs(off) <= 8 {
                if holdStart == nil { holdStart = now }
                if now - (holdStart ?? now) >= 0.5 {
                    holdStart = nil; cents = nil
                    SoundFX.shared.play(.hit); Haptics.shared.lock(); burst += 1
                    index += 1
                    if index >= strings.count { finish() } else { store.gameTargetHz = frequency(strings[index], store) }
                }
            } else { holdStart = nil }
        }
    }

    private func finish() {
        store.stopLessonListening(owner: owner)
        if let instrument = course.instrument { UserDefaults.standard.set(Quests.dayKey(Date()), forKey: "tunecheck.\(instrument)") }
        done()
    }
}

/// The chords of a progression in a row; the one to play now is big, the next one waits beside it.
struct ProgressionStrip: View {
    let chords: [ChordSpec]
    let bars: [Int]
    let current: Int
    let accent: Color
    /// Names the outer strings under the chord to play now.
    var edges: StringEdges?

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ChordDiagram(chord: chords[min(current, chords.count - 1)], accent: accent, edges: edges).frame(width: 140)
                .id(current).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            if current + 1 < chords.count {
                VStack(spacing: 4) {
                    Text("Next").font(.caption).foregroundStyle(Palette.inkFaint)
                    ChordDiagram(chord: chords[current + 1], accent: Palette.inkSoft).frame(width: 84).opacity(0.7)
                }
            }
        }
        .animation(Motion.settle, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chords.map(\.name).joined(separator: ", ")))
    }
}
