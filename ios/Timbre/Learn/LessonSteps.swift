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
    var fretKind: String? {
        guard let instrument else { return nil }
        return ["guitar", "ukulele", "bass", "violin", "cello", "mandolin", "banjo"].first { instrument.hasPrefix($0) }
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
}

@MainActor private func frequency(_ midi: Int, _ store: AppStore) -> Double { PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz) }

// MARK: - Notes, one at a time

struct NotesStep: View {
    let notes: [TimedNote]
    let hint: LearnText?
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var heard: HeardNote?
    @State private var hold = 0.0
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false

    init(notes: [TimedNote], hint: LearnText?, course: LearnCourse, accent: Color, done: @escaping (Double?) -> Void) {
        self.notes = notes; self.hint = hint; self.course = course; self.accent = accent; self.done = done
        _judge = State(initialValue: NoteSequenceJudge(notes: notes.map(\.midi), anyOctave: course.anyOctave))
    }

    private var current: TimedNote? { judge.index < notes.count ? notes[judge.index] : nil }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(course.instrument == "voice" ? LocalizedStringKey("Sing this note") : LocalizedStringKey("Play this note")).font(Typeface.label(15)).foregroundStyle(Palette.inkSoft)
                if let hint { Text(hint.localized).font(.subheadline).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center).padding(.horizontal, 30) }
            }
            .padding(.top, 10)
            if notes.count > 1 { sequenceChips }
            Spacer(minLength: 0)
            ZStack {
                HoldRing(progress: finished ? 1 : hold, tint: ringTint)
                VStack(spacing: 4) {
                    let name = NoteName.name(current?.midi ?? notes.last?.midi ?? 60)
                    Text(name.dropLast(name.last?.isNumber == true ? 1 : 0)).font(Typeface.note(88)).foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text(status).font(.subheadline.weight(.semibold)).foregroundStyle(ringTint).contentTransition(.opacity)
                }
                SparkBurst(trigger: burst, color: accent)
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if course.fretKind != nil, let at = current?.at {
                FretboardDiagram(strings: course.stringCount, dots: [at], frets: max(5, at.fret + 1), accent: accent, activeString: at.string, fretless: course.fretless)
                    .padding(.horizontal, 20)
                Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)")).font(.footnote).foregroundStyle(Palette.inkSoft)
            }
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
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(14))
                    .foregroundStyle(state == 2 ? Palette.onAccent : state == 1 ? Palette.ink : Palette.inkFaint)
                    .frame(minWidth: 38, minHeight: 34)
                    .background(Capsule().fill(state == 2 ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.stageRaised)))
                    .overlay(Capsule().strokeBorder(state == 1 ? accent : .clear, lineWidth: 1.5))
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
            case .hit?:
                hold = 0; burst += 1
                SoundFX.shared.play(.correct); Haptics.shared.lock()
                if judge.isFinished { finish(score: judge.accuracy) }
                else if let next = current { store.gameTargetHz = frequency(next.midi, store) }
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

    init(chord: ChordSpec, course: LearnCourse, accent: Color, done: @escaping (Double?) -> Void) {
        self.chord = chord; self.course = course; self.accent = accent; self.done = done
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
    static func openStrings(_ course: LearnCourse) -> [Int] {
        switch course.fretKind {
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
                Text("Fingers in place, then let it ring.").font(.subheadline).foregroundStyle(Palette.inkFaint)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            ZStack {
                ChordDiagram(chord: chord, accent: accent, ringing: verified, landing: true)
                    .frame(maxWidth: 260)
                    .padding(22)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.stageRaised))
                    .shadow(color: finished ? accent.opacity(0.45) : .clear, radius: 26)
                SparkBurst(trigger: burst, color: accent)
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
    /// On an instrument course a tap step also hears the instrument, so hands can stay on the strings.
    var hearsInstrument = false
    /// Strummed instruments: a tap step shows its pattern as down and up strokes too.
    var strums = false
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var startTime: CFTimeInterval = 0
    @State private var hits: [Double] = []
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var pulse = 0
    @State private var score = 0.0

    enum Phase { case ready, playing, done }
    private var beatsPerBar: Int { meter ?? max(4, Int((pattern.max() ?? 3) + 1)) }
    private var spb: Double { 60 / bpm }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var expected: [Double] { (0..<bars).flatMap { bar in pattern.map { countIn + (Double(bar * beatsPerBar) + $0) * spb } } }
    private var isTap: Bool { if case .tap = mode { return true } else { return false } }
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

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text(isTap ? (hearsInstrument ? LocalizedStringKey("Play or tap on the dots") : LocalizedStringKey("Tap on the dots")) : LocalizedStringKey("Strum on the arrows")).font(Typeface.display(26)).foregroundStyle(Palette.ink)
                Text("\(Int(bpm)) BPM · \(bars) bars").font(.subheadline).foregroundStyle(Palette.inkSoft)
                if !isTap { BandControls(audio: store.audio, accent: accent).padding(.top, 2) }
            }
            .padding(.top, 14)
            if case .strum(let chord?) = mode { ChordDiagram(chord: chord, accent: accent, landing: true).frame(maxWidth: 150) }
            if case .progression(let chords, let lengths) = mode {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    ProgressionStrip(chords: chords, bars: lengths, current: currentChord(lengths), accent: accent)
                }
            }
            TimelineView(.animation(paused: phase != .playing)) { timeline in
                let now = CACurrentMediaTime()
                let elapsed = now - startTime - countIn
                let bar = max(0, Int(elapsed / (Double(beatsPerBar) * spb)))
                let within = elapsed < 0 ? nil : (elapsed / spb - Double(bar * beatsPerBar)) / Double(beatsPerBar)
                let barGrades = Dictionary(uniqueKeysWithValues: grades.compactMap { i, g in i / pattern.count == bar ? (i % pattern.count, g) : nil })
                VStack(spacing: 10) {
                    if phase == .playing, elapsed < 0 {
                        Text("\(Int(-elapsed / spb) + 1)").font(Typeface.note(64)).foregroundStyle(accent).contentTransition(.numericText())
                    } else {
                        Text(phase == .done ? LocalizedStringKey("") : LocalizedStringKey("Bar \(min(bars, bar + 1)) of \(bars)")).font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
                    }
                    RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: phase == .playing ? within : nil, judged: barGrades, arrows: !isTap || strums)
                        .padding(.horizontal, 16)
                        .onChange(of: Int(now * 30)) { _, _ in expire(now: now) }
                }
            }
            .frame(height: 170)
            Spacer(minLength: 0)
            if phase == .done {
                Text("\(Int((score * 100).rounded()))% on the beat").font(Typeface.display(28)).foregroundStyle(accent)
            } else if isTap {
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
            } else {
                MicrophoneHint()
            }
            Spacer(minLength: 0)
            switch phase {
            case .ready: StepButton(title: "Start", accent: accent) { start() }
            case .playing: StepButton(title: "Listening…", accent: accent, enabled: false) {}
            case .done:
                HStack(spacing: 10) {
                    Button("Try again") { start() }.font(Typeface.label(16)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
                    StepButton(title: "Continue", accent: accent) { done(score) }.padding(.horizontal, -20).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear { store.audio.prepareBand(band) }
        .onDisappear { store.audio.stopMetronome(); store.audio.stopBand(); store.stopLessonListening(owner: owner) }
    }

    /// Which chord of a progression is under the playhead (by bar).
    private func currentChord(_ lengths: [Int]) -> Int {
        guard phase == .playing else { return 0 }
        let elapsed = CACurrentMediaTime() - startTime - countIn
        let bar = max(0, Int(elapsed / (Double(beatsPerBar) * spb)))
        var total = 0
        for (i, n) in lengths.enumerated() { total += n; if bar < total { return i } }
        return max(0, lengths.count - 1)
    }

    private func start() {
        hits = []; grades = [:]; score = 0
        startTime = CACurrentMediaTime()
        phase = .playing
        store.audio.setMetronome(bpm: Int(bpm), beats: beatsPerBar, subdivision: 1, accents: true)
        // From the bar after the count-in, on headphones; the speaker keeps the click alone.
        store.audio.playBand(band, firstBar: 1)
        if !isTap || hearsInstrument {
            let analyzer = LessonAnalyzer(chords: false, onOnset: { time in register(time) })
            store.startLessonListening(owner: owner, lowHz: 60, highHz: 1400, analyzer: analyzer) { _, _ in }
        }
    }

    private func tapped() {
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
        phase = .done
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

    private var strings: [Int] { ChordStep.openStrings(course).enumerated().filter { !(course.fretKind == "banjo" && $0.offset == 0) }.map(\.element) }

    static func needed(for course: LearnCourse) -> Bool {
        guard let instrument = course.instrument, course.fretKind != nil else { return false }
        return UserDefaults.standard.string(forKey: "tunecheck.\(instrument)") != Quests.dayKey(Date())
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Quick tune check").font(Typeface.display(28)).foregroundStyle(Palette.ink)
                Text("Pluck each open string. In-tune strings help Timbre hear you right.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            .padding(.top, 14)
            HStack(spacing: 8) {
                ForEach(Array(strings.enumerated()), id: \.offset) { i, midi in
                    Text(NoteName.pitchClass(midi)).font(Typeface.label(15))
                        .foregroundStyle(i < index ? Palette.onAccent : i == index ? Palette.ink : Palette.inkFaint)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(i < index ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.stageRaised)))
                        .overlay(Circle().strokeBorder(i == index ? accent : .clear, lineWidth: 2))
                }
            }
            .animation(Motion.pluck, value: index)
            Spacer(minLength: 0)
            ZStack {
                VStack(spacing: 14) {
                    Text(index < strings.count ? NoteName.name(strings[index]) : "✓").font(Typeface.note(76)).foregroundStyle(Palette.ink)
                    centsMeter
                    Text(hint).font(.headline).foregroundStyle(meterColor)
                }
                SparkBurst(trigger: burst, color: accent)
            }
            Spacer(minLength: 0)
            MicrophoneHint()
            Button("My strings are tuned — skip") { finish() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                .padding(.bottom, 18)
                .accessibilityIdentifier("lesson.tunecheck.skip")
        }
        .onAppear { listen() }
        .onDisappear { store.stopLessonListening(owner: owner) }
    }

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

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ChordDiagram(chord: chords[min(current, chords.count - 1)], accent: accent).frame(width: 140)
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
