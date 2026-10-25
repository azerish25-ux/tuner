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
            if readsStaff { stepStaff } else if isSequence { sequenceChips }
            Spacer(minLength: 0)
            if isSequence { prompt }
            noteRing
            Spacer(minLength: 0)
            targetPicture
            MicrophoneHint()
            LessonStepBar(canSkip: canSkip, accent: accent, sounding: sounding, skip: { finish(score: 0.6) }, hear: { hear() })
        }
        .onAppear { listen(); Task { try? await Task.sleep(for: .seconds(6)); withAnimation(Motion.settle) { canSkip = true } } }
        .onDisappear { hearTask?.cancel(); finishTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; pick the note up again on return.
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !sounding { listen() } }
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
                    .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
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
        // As big as the room between the words and the neck allows (up to 290 pt on the tallest phones, so no band of
        // empty stage is left around it), smaller on short phones so the neck and the bar below still fit.
        .aspectRatio(1, contentMode: .fit)
        .frame(minWidth: 150, maxWidth: 290, minHeight: 150, maxHeight: 290)
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

    /// The note to play, handing over as the last one is ticked off: the old letter is fully gone before the new one
    /// fades in (`NoteHandover`), so two never overlap and none is left half drawn.
    private var noteLetter: some View {
        let name = NoteName.name(shown?.midi ?? 60)
        return NoteHandover(String(name.dropLast(name.last?.isNumber == true ? 1 : 0)), font: Typeface.note(88), turn: min(judge.index, max(0, notes.count - 1)))
    }

    /// Where to play it: a strip of the neck with the target string and fret lit and breathing (fretted
    /// and fingerboard courses), or the notes on a staff with the current one lit (voice and any instrument).
    @ViewBuilder private var targetPicture: some View {
        if let at = shownFretting {
            VStack(spacing: 6) {
                FretboardDiagram(strings: course.stringCount, dots: [at], frets: stripFrets, accent: accent, activeString: at.string,
                                 fretless: course.fretless, rowHeight: 18, pulsing: !finished, edges: StringEdges.of(course), fretNumbers: true)
                    .padding(.horizontal, 18)
                Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)"))
                    .font(Typeface.label(13)).foregroundStyle(accent)
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
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(14))
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
/// strand a half-faded name on screen (bug 52).
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

struct ChordStep: View {
    let chord: ChordSpec
    let course: LearnCourse
    let accent: Color
    /// How the chord went (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var owner = UUID()
    @State private var judge: NoteSequenceJudge
    @State private var verified: Set<Int> = []
    @State private var burst = 0
    @State private var finished = false
    @State private var canSkip = false
    @State private var hearing: String?
    @State private var matchedFrames = 0
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
            listen()
            Task { try? await Task.sleep(for: .seconds(6)); withAnimation(Motion.settle) { canSkip = true } }
            // The 3D model loads quietly once the step has settled, so "Show me" is immediate (once per lesson).
            if let model = showMeModel { ModelCache.shared.prefetch(model, after: 1.2) }
        }
        .onDisappear { hearTask?.cancel(); finishTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; listen again on return.
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !sounding { listen() } }
        // The picture choice changing elsewhere brings the picture back.
        .onChange(of: chordView) { _, _ in setShowMe(false) }
    }

    /// The chord box's width and stretch: as wide as the screen allows, its frets drawn taller to fill the height.
    /// Around the box's header (its name and the chart / player switch) and edge names go the checks (44), the
    /// card's padding (44), "Hearing" (34), the gaps between them (28) and a little air for larger text (8); with a 3D
    /// model, the "Show me" row in the card (44 and its gap).
    private func diagramFit(_ room: CGSize) -> (width: CGFloat, stretch: CGFloat) {
        let showMeRow: CGFloat = showMeModel != nil ? Metrics.minTarget + 8 : 0
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
            if showMe && model != nil {
                ShowMeCardHeader(name: chord.name, on: showMeBinding, accent: accent)
            } else {
                ChordCardHeader(name: chord.name, accent: accent)
            }
            ZStack {
                if !threeD {
                    chordPicture(fit, edges: edges)
                        .transition(.opacity)
                }
                if showMe, let model {
                    ShowMeStage(modelID: model, strings: chord.frets.count, fretless: course.fretless, shot: .fretting(ShowMeShape(chord: chord)),
                                accent: accent, ringing: ringing, landStart: showLandStart, landingStep: ShowMe.landingStep, edges: edges,
                                label: Text("\(chord.name) chord"), value: ChordWords.shape(chord),
                                onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
                }
            }
            .frame(width: fit.width, height: ChordDiagram.boxHeight(chord, width: fit.width, stretch: fit.stretch, named: edges != nil))
            if model != nil {
                ShowMeButton(accent: accent, loading: showMe && !showMeReady) { setShowMe(true) }
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
    /// it again; the switch back shows the picture.
    private func setShowMe(_ on: Bool) {
        guard on else {
            guard showMe else { return }
            withMotion(Motion.reveal, reduceMotion: reduceMotion) {
                showMe = false
                showMeReady = false
            }
            return
        }
        Haptics.shared.selection()
        if showMe {
            if showMeReady { showMeDemo(lead: 0.05) }
            return
        }
        showMeReady = false
        showMe = true
    }

    private func showMeAppeared() {
        guard showMe, !showMeReady else { return }
        withAnimation(Motion.reveal) { showMeReady = true }
        showMeDemo(lead: ShowMe.lead)
    }

    /// The model couldn't be shown: the picture stays, without "Show me".
    private func showMeUnavailable() {
        showMeFailed = true
        showMe = false
        showMeReady = false
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
        // box).
        let xs = player ? PlayerNeck.stringPositions(chord, width: width)
                        : ChordDiagram(chord: chord, fretNumbers: true).stringPositions(width: width)
        let gap = count > 1 ? abs(xs[count - 1] - xs[0]) / CGFloat(count - 1) : 40
        let side = min(40, max(26, gap - 8))
        let next: Int? = order.indices.contains(judge.index) && !finished ? order[judge.index].index : nil
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                LessonStringCheck(note: i < open.count ? NoteName.pitchClass(open[i] + max(0, chord.frets[i])) : "",
                                  number: count - i, mark: mark(i, next: next, open: open), accent: accent, side: side)
                    .position(x: xs[i], y: 22)
                    .animation(reduceMotion ? Motion.reduced : Motion.pluck.delay(Double(i) * 0.04), value: verified.contains(i))
            }
        }
        .frame(width: width, height: 44)
        .animation(Motion.quick, value: judge.index)
    }

    private func mark(_ i: Int, next: Int?, open: [Int]) -> LessonStringCheck.Mark {
        if chord.frets[i] < 0 || i >= open.count { return .muted }
        if verified.contains(i) { return .heard }
        return next == i ? .next : .waiting
    }

    /// What the microphone hears as a chord; its row is kept while hidden, so the box doesn't jump.
    private var hearingPill: some View {
        let showing = hearing != nil && !finished
        return Text("Hearing \(hearing ?? chord.name)").font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 7).background(Capsule().fill(Palette.stageRaised))
            .opacity(showing ? 1 : 0)
            .animation(Motion.quick, value: showing)
            .accessibilityHidden(!showing)
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

    /// The chord string by string, lowest first, each string lighting on the box as it sounds; then it listens again.
    private func strumIt() {
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
/// it's the one to pluck next, filled with a tick once heard; a muted string is a faint cross.
struct LessonStringCheck: View {
    enum Mark { case muted, waiting, next, heard }
    let note: String
    /// String number (1 is the thinnest), for VoiceOver.
    let number: Int
    let mark: Mark
    let accent: Color
    var side: CGFloat = 40
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(mark == .muted ? "×" : note)
            .font(Typeface.label(side >= 36 ? 15 : 13))
            .foregroundStyle(ink)
            .frame(width: side, height: side)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(rim, lineWidth: mark == .next ? 2 : 1))
            .overlay(alignment: .topTrailing) { tick }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("String \(number), \(note)"))
            .accessibilityValue(mark == .heard ? String(localized: "Got it") : "")
            .accessibilityHidden(mark == .muted)
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
        }
    }

    private var fill: Color {
        switch mark {
        case .muted: return Palette.surface.opacity(0.5)
        case .waiting, .next: return Palette.surface
        case .heard: return accent
        }
    }

    private var rim: Color {
        switch mark {
        case .muted, .heard: return .clear
        case .waiting: return Palette.controlLine
        case .next: return accent
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

// MARK: - Rhythm: tap or strum on the pattern

/// A rhythm take, laid out to use the whole screen: the title (a strum's chord beside it, a progression's strip under
/// it), the beat lane with every down and up stroke and the pick riding it as the playhead, then the instrument's
/// strings filling everything down to the button, the pick sweeping them in time with the click. The count-in shows
/// big over the strings as the take starts, the score over them once it's done. Before Start both picks preview the
/// pattern at the step's tempo, on one clock.
/// The strings always lie in Player view (`StrumSweep.order`: the thickest on top), so both picks go down the screen on
/// a ↓; the chord beside the title is a fretting picture and follows the picture choice, as every chord box does.
/// Before Start, "Show me" under the strings plays the pattern on the course instrument's 3D model in their place
/// (`ShowMeStage`, seen the same way up, its pick on the preview's clock) while two bars of it sound; Start brings the
/// strings back before the click and the microphone start. Without a model, with Reduce Motion or in Low Power Mode
/// the strings stay alone.
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
    /// The course, for "Show me": before the take, the pattern strummed on its instrument's 3D model.
    var course: LearnCourse?
    let accent: Color
    /// Called when the step is passed by tapping because the microphone can't hear the instrument.
    var onPractice: () -> Void = {}
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var startTime: CFTimeInterval = 0
    @State private var appeared = CACurrentMediaTime()
    @State private var hits: [Double] = []
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    /// How far off each judged stroke was, in seconds (negative early).
    @State private var offsets: [Int: Double] = [:]
    /// The nearest stroke heard outside a beat's window: the reason it's missed ("240 ms early").
    @State private var strays: [Int: Double] = [:]
    @State private var pulse = 0
    @State private var score = 0.0
    /// No microphone (refused, or it failed to start): the screen stands in for the instrument.
    @State private var micOff = false
    /// The bar before the first stroke is clicking: its count shows big over the strings.
    @State private var counting = false
    /// This step started the click that's running, so it stops it when it goes. A click it didn't start (the
    /// Metronome tool's) is left alone until a take restarts the click fresh.
    @State private var ownsClick = false
    /// "Show me", before Start: the course instrument's 3D model in place of the strings, its pick sweeping the pattern
    /// on the preview's clock (`ShowMeStage`) while two bars of it sound. Start brings the strings back for the take, so
    /// the demonstration never sounds while the step listens.
    @State private var showMe = false
    @State private var showMeReady = false
    @State private var showMeFailed = false
    /// Beat 1 of the preview's loop as a date: the 3D stage's clock.
    @State private var showOrigin = Date()
    /// The demonstration's strokes, sounding.
    @State private var showMeTask: Task<Void, Never>?

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
        VStack(spacing: 14) {
            header
            if case .progression(let chords, let lengths) = mode {
                // The chord under the playhead only changes during a take; the strip holds still otherwise.
                TimelineView(.animation(minimumInterval: 0.1, paused: phase != .playing)) { _ in
                    ProgressionStrip(chords: chords, bars: lengths, current: currentChord(lengths), accent: accent, edges: edges)
                }
            }
            meterView
            stage
            MicrophoneHint()
            controls
        }
        .onAppear {
            micOff = LessonMicrophone.unavailable(store.audio)
            store.audio.prepareBand(band)
        }
        // The 3D model loads quietly once the step has settled, so "Show me" is immediate (once per lesson); never
        // once a take is under way.
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, phase == .ready, let model = showMeModel else { return }
            ModelCache.shared.prefetch(model)
        }
        .onReceive(store.audio.$permissionDenied) { denied in if denied { micOff = true } }
        .onReceive(store.audio.$error) { error in
            // The microphone failed to start mid-take: the screen takes over.
            if error != nil, phase == .playing, instrumentStep, !store.audio.running { micOff = true }
        }
        // Leaving the app mid-take drops the take: no click left sounding in a pocket, nothing half-heard graded.
        // A demonstration stops where it is ("Show me" plays it again).
        .onChange(of: scenePhase) { _, now in if now == .background { stopShowMeSound(); abandonTake() } }
        .onDisappear {
            showMeTask?.cancel()
            if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
            store.audio.stopBand()
            store.stopLessonListening(owner: owner)
        }
    }

    // MARK: Header

    /// The title, the tempo and the band; a strum's chord sits beside them small under its name (the chart or the
    /// player's view, as chosen), so the strings below keep the room.
    @ViewBuilder private var header: some View {
        if case .strum(let chord?) = mode {
            HStack(alignment: .center, spacing: 16) {
                headerWords
                ChordPictureView(chord: chord, accent: accent, landing: true, compact: true).frame(width: 112)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 10)
        } else {
            headerWords
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 14)
        }
    }

    /// The step's title (leading, as on every step), the tempo and the band.
    private var headerWords: some View {
        VStack(alignment: .leading, spacing: 6) {
            StepTitle(title)
            Text("\(Int(bpm)) BPM · \(bars) bars").font(.subheadline).foregroundStyle(Palette.inkSoft)
            if practice || !isTap {
                HStack(spacing: 8) {
                    if practice { PracticeModeTag() }
                    if !isTap { BandControls(audio: store.audio, accent: accent) }
                }
                .padding(.top, 2)
            }
        }
        .animation(Motion.quick, value: micOff)
    }

    // MARK: Beat lane

    /// "Bar 1 of 2" over the beat lane, the lane with its pick (the playhead) and each stroke's call. Before Start
    /// the pick previews the pattern on the same clock as the strings below; once done the last bar keeps its calls.
    private var meterView: some View {
        TimelineView(.animation(paused: !laneMoves)) { _ in
            let now = CACurrentMediaTime()
            let elapsed = phase == .playing ? now - startTime - countIn : 0
            // Ready shows bar 1 (the clock hasn't started), done the last bar with its calls.
            let bar = phase == .done ? max(0, bars - 1) : min(max(0, bars - 1), max(0, Int(elapsed / barLength)))
            VStack(spacing: 6) {
                Text("Bar \(bar + 1) of \(bars)").font(Typeface.label(13)).foregroundStyle(Palette.inkSoft)
                    .opacity(phase == .done ? 0 : 1)
                LessonBeatRow(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: playhead(now: now, elapsed: elapsed, bar: bar),
                              calls: calls(inBar: bar), arrows: !isTap || strums, restingPick: phase != .done)
                    .padding(.horizontal, 12)
                    .onChange(of: Int(now * 30)) { _, _ in expire(now: now) }
            }
        }
    }

    /// The lane moves while a take plays, and previews the pattern before Start (unless Reduce Motion is on).
    private var laneMoves: Bool { phase == .playing || (phase == .ready && !reduceMotion) }

    /// 0…1 through the bar on the lane: the take's clock (nil while counting in), the preview's before Start.
    private func playhead(now: CFTimeInterval, elapsed: Double, bar: Int) -> Double? {
        switch phase {
        case .playing:
            guard elapsed >= 0 else { return nil }
            return min(1, (elapsed - Double(bar) * barLength) / barLength)
        case .ready:
            guard !reduceMotion, barLength > 0 else { return nil }
            let into = (now - appeared) / barLength
            return into - into.rounded(.down)
        case .done:
            return nil
        }
    }

    /// The count-in, big: "1 2 3 4" (one numeral per click of the bar before the first stroke), each lighting
    /// in the accent as its click sounds; the ones gone by stay lit softly. With Reduce Motion they don't pop.
    private func countInRow(elapsed: Double, largest: CGFloat = 56) -> some View {
        let into = max(0, elapsed + countIn) / spb
        let beat = min(beatsPerBar - 1, Int(into))
        let through = max(0, into - Double(beat))
        let size: CGFloat = min(largest, beatsPerBar <= 4 ? 56 : beatsPerBar <= 6 ? 44 : 30)
        return HStack(spacing: size * 0.36) {
            ForEach(0..<beatsPerBar, id: \.self) { k in
                Text("\(k + 1)")
                    .font(Typeface.note(size))
                    .foregroundStyle(k == beat ? accent : k < beat ? Palette.inkSoft : Palette.inkFaint.opacity(0.5))
                    .scaleEffect(k == beat ? (reduceMotion ? 1 : 1 + 0.22 * exp(-through * 7)) : 0.78)
                    .shadow(color: k == beat ? accent.opacity(0.5) : .clear, radius: 14)
            }
        }
        .lineLimit(1)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(beat + 1)"))
    }

    /// How each stroke of `bar` went, by its place in the pattern: a judged stroke with its timing, a miss with
    /// the nearest stroke heard outside its window (or none).
    private func calls(inBar bar: Int) -> [Int: BeatCall] {
        guard !pattern.isEmpty else { return [:] }
        var out: [Int: BeatCall] = [:]
        for (i, grade) in grades where i / pattern.count == bar {
            out[i % pattern.count] = BeatCall(grade: grade, offset: grade == .miss ? strays[i] : offsets[i])
        }
        return out
    }

    // MARK: Stage

    /// The rest of the screen, all of it: the strings with the pick sweeping them (or the tap pad), the count-in
    /// over them as a take starts and the score over them once it's done. On a short phone under a long header
    /// the strings give way rather than squeeze (the lane above already shows every stroke). Before Start, "Show me"
    /// sits under the strings when the course instrument has a 3D model and there is room for both.
    private var stage: some View {
        GeometryReader { proxy in
            let offered = showMeOffered(height: proxy.size.height)
            VStack(spacing: 8) {
                GeometryReader { inner in
                    stageContent(inner.size)
                }
                if offered {
                    showMeRow.transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// The strings (or the tap pad) in `size`, with the count-in or the score over them.
    private func stageContent(_ size: CGSize) -> some View {
        let side = min(size.width, size.height)
        return ZStack {
            if tapping {
                tapPad(side: min(240, side, max(120, side * 0.62)))
                    .opacity(phase == .done ? 0.3 : 1)
            } else if size.height >= Self.smallestStage {
                stringsStage.opacity(phase == .done ? 0.35 : 1)
            }
            // Both badges shrink to a short stage (a small phone under a progression's chords).
            if counting { countInBadge(largest: min(56, max(24, size.height * 0.5))).transition(.opacity) }
            if phase == .done { scoreBadge(compact: size.height < 90).transition(.scale(scale: 0.9).combined(with: .opacity)) }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Below this the strings would be cramped.
    private static let smallestStage: CGFloat = 110
    /// "Show me"'s row under the strings, with its gap.
    private static let showMeRowHeight: CGFloat = Metrics.minTarget + 8

    /// The strings with the pick sweeping them; with "Show me" on, the 3D model takes their place once it is in place,
    /// its pick on the preview's clock (the beat lane's), so both picks keep together.
    @ViewBuilder private var stringsStage: some View {
        let model = showMe && phase == .ready ? showMeModel : nil
        ZStack {
            if model == nil || !showMeReady {
                strumStage.transition(.opacity)
            }
            if let model, let course {
                ShowMeStage(modelID: model, strings: course.stringCount, fretless: course.fretless,
                            shot: .strum(ShowMeStrum(pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm, origin: showOrigin)),
                            accent: accent, edges: edges, label: Text("Strum pattern"),
                            value: String(localized: "Down strokes go from the thickest string to the thinnest, up strokes back."),
                            onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
            }
        }
    }

    /// The strings with the pick sweeping them in time with the click: a preview loop before Start, still once done.
    private var strumStage: some View {
        TimelineView(.animation(paused: reduceMotion || phase == .done)) { _ in
            StrumSweep(pattern: pattern, beatsPerBar: beatsPerBar, strings: max(1, strings), style: sweepStyle, accent: accent,
                       secondsPerBeat: spb, time: sweepTime(CACurrentMediaTime()), bars: phase == .playing ? bars : nil, edges: edges)
        }
    }

    /// The count-in over the strings, on a dark pill so it reads over the wood.
    private func countInBadge(largest: CGFloat) -> some View {
        TimelineView(.animation) { _ in
            countInRow(elapsed: CACurrentMediaTime() - startTime - countIn, largest: largest)
        }
        .padding(.horizontal, 26).padding(.vertical, largest < 40 ? 4 : 12)
        .background(Capsule().fill(Palette.stage.opacity(0.8)))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .allowsHitTesting(false)
    }

    /// The take's score over the dimmed strings, in its grade's colour.
    private func scoreBadge(compact: Bool) -> some View {
        let tint = ScoreTint.color(score)
        return Text("\(Int((score * 100).rounded()))% on the beat")
            .font(Typeface.display(compact ? 22 : 28)).foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.vertical, compact ? 6 : 14)
            .background(Capsule().fill(Palette.stage.opacity(0.85)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1.5))
            .shadow(color: tint.opacity(0.35), radius: 18)
    }

    private func tapPad(side: CGFloat) -> some View {
        Button { tapped() } label: {
            Circle().fill(accent.opacity(0.14)).overlay(Circle().strokeBorder(accent, lineWidth: 3))
                .overlay(Image(systemName: "hand.tap.fill").font(.system(size: max(28, side * 0.24))).foregroundStyle(accent))
                .frame(width: side, height: side)
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
            LessonActionBar {
                LessonBarButton(title: "Try again") { start() }
                StepButton(title: "Continue", accent: accent, inset: false) {
                    if practice { onPractice() }
                    done(score)
                }
            }
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

    // MARK: Show me: the pattern strummed on the instrument, in 3D

    /// The course instrument's 3D model, when this step strums the strings on screen (not the tap pad) and the stage
    /// may run now (not with Reduce Motion, in Low Power Mode or hot).
    private var showMeModel: String? {
        guard !showMeFailed, strums, !tapping, let course, course.strums, course.stringCount == strings else { return nil }
        return ShowMe.model(for: course, catalog: store.catalog, reduceMotion: reduceMotion)
    }

    /// "Show me" is offered before the take only (the microphone is not listening then), under strings with room to
    /// spare for it.
    private func showMeOffered(height: CGFloat) -> Bool {
        phase == .ready && showMeModel != nil && height >= Self.smallestStage + Self.showMeRowHeight
    }

    private var showMeBinding: Binding<Bool> {
        Binding(get: { showMe }, set: { on in setShowMe(on) })
    }

    /// Under the strings: the switch back to them while the model shows, and "Show me".
    private var showMeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { showMeControls }
            VStack(spacing: 6) { showMeControls }
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: showMe)
    }

    @ViewBuilder private var showMeControls: some View {
        if showMe {
            ShowMeToggle(on: showMeBinding, accent: accent, label: "Neck view")
                .transition(.opacity)
        }
        ShowMeButton(accent: accent, loading: showMe && !showMeReady) { setShowMe(true) }
    }

    /// "Show me" puts the instrument in place of the strings (the strokes sound once it is there) or, already there,
    /// sounds them again; the switch brings the strings back.
    private func setShowMe(_ on: Bool) {
        guard on else {
            guard showMe else { return }
            stopShowMeSound()
            withMotion(Motion.reveal, reduceMotion: reduceMotion) {
                showMe = false
                showMeReady = false
            }
            return
        }
        guard phase == .ready else { return }
        Haptics.shared.selection()
        if showMe {
            if showMeReady { soundShowMe(lead: 0.15) }
            return
        }
        // On the preview's own clock (`appeared`), so the model's pick runs with the beat lane's.
        showOrigin = Date().addingTimeInterval(appeared - CACurrentMediaTime())
        showMeReady = false
        showMe = true
    }

    /// The model is in place: it takes over from the strings and the strokes sound once the camera has glided in.
    private func showMeAppeared() {
        guard showMe, !showMeReady, phase == .ready else { return }
        withAnimation(Motion.reveal) { showMeReady = true }
        soundShowMe(lead: ShowMe.lead)
    }

    /// The model couldn't be shown: the strings stay, without "Show me".
    private func showMeUnavailable() {
        stopShowMeSound()
        showMeFailed = true
        showMe = false
        showMeReady = false
    }

    /// The take starts: the demonstration stops and the strings come back, before the click and the microphone start.
    private func closeShowMe() {
        stopShowMeSound()
        guard showMe else { return }
        withMotion(Motion.quick, reduceMotion: reduceMotion) {
            showMe = false
            showMeReady = false
        }
    }

    private func stopShowMeSound() {
        showMeTask?.cancel()
        showMeTask = nil
    }

    /// Two bars of the pattern's strokes from the first one at least `lead` away (the camera's glide in), on the
    /// model's clock: the step's chord strummed down across every string, up across the top three, each sounding as
    /// the pick reaches the first string (as on the lesson's explanation).
    private func soundShowMe(lead: Double) {
        stopShowMeSound()
        let notes = showMeNotes
        guard !pattern.isEmpty, !notes.isEmpty, barLength > 0, phase == .ready else { return }
        let reference = store.settings.referencePitchHz
        let downTones = notes.map { PitchMath.frequency(midi: Double($0), reference: reference) }
        let upTones = notes.sorted().suffix(3).map { PitchMath.frequency(midi: Double($0), reference: reference) }
        let origin = showOrigin
        let bar = barLength
        let beat = spb
        let from = Date().timeIntervalSince(origin) + lead
        let hits = pattern.sorted()
        let firstBar = Int((from / bar).rounded(.down))
        var strokes: [(at: Double, down: Bool)] = []
        for index in firstBar...(firstBar + 2) {
            for hit in hits {
                let at = Double(index) * bar + hit * beat
                if at >= from - 0.0001 { strokes.append((at: at, down: hit.truncatingRemainder(dividingBy: 1) == 0)) }
            }
        }
        let run = Array(strokes.prefix(hits.count * 2))
        showMeTask = Task { @MainActor in
            for stroke in run {
                let wait = origin.addingTimeInterval(stroke.at - 0.09).timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                // Never once the take has started (Start cancels this too).
                guard !Task.isCancelled, phase == .ready, showMe else { return }
                store.audio.playTones(stroke.down ? downTones : upTones, together: true, noteMs: stroke.down ? 520 : 320)
            }
        }
    }

    /// What the demonstration strums, lowest string first: the step's chord (a progression's first), or the
    /// instrument's first open chord.
    private var showMeNotes: [Int] {
        guard let course else { return [] }
        let chord: ChordSpec?
        switch mode {
        case .tap: chord = nil
        case .strum(let spec): chord = spec
        case .progression(let chords, _): chord = chords.first
        }
        return ShowMe.strumNotes(chord, open: ChordStep.openStrings(course), fretKind: course.fretKind)
    }

    // MARK: The take

    private func start() {
        // The demonstration never sounds over the take: it stops before the click and the microphone start.
        closeShowMe()
        hits = []; grades = [:]; offsets = [:]; strays = [:]; score = 0
        startTime = CACurrentMediaTime()
        withAnimation(Motion.quick) { phase = .playing; counting = true }
        // A fresh count from its first click (`setMetronome` restarts any click already running, the Metronome
        // tool's included), so the count-in, the band and the judging all count from a click that starts now.
        store.audio.setMetronome(bpm: Int(bpm), beats: beatsPerBar, subdivision: 1, accents: true)
        ownsClick = true
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
        let open = times.indices.filter { grades[$0] == nil }
        if let index = open.min(by: { abs(times[$0] - t) < abs(times[$1] - t) }), abs(times[index] - t) <= 0.18 {
            let offset = abs(times[index] - t)
            grades[index] = offset <= 0.05 ? .perfect : offset <= 0.1 ? .good : .ok
            offsets[index] = t - times[index]
            SoundFX.shared.play(.hit)
            return
        }
        // Outside every window: kept as the reason the nearest stroke is missed, unless it's played after all.
        guard let nearest = times.indices.min(by: { abs(times[$0] - t) < abs(times[$1] - t) }),
              grades[nearest] == nil || grades[nearest] == .miss else { return }
        let off = t - times[nearest]
        if abs(off) <= 0.45, abs(off) < abs(strays[nearest] ?? .infinity) { strays[nearest] = off }
    }

    private func expire(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // Beats are where the click is heard (after engine start and output latency), not where Start was tapped.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        let t = now - startTime
        if counting && t >= countIn { withAnimation(Motion.quick) { counting = false } }
        if LessonMicrophone.demo, instrumentStep, !micOff { demoStrokes(at: t) }
        for (i, time) in expected.enumerated() where grades[i] == nil && t > time + 0.2 { grades[i] = .miss }
        if t > (expected.last ?? 0) + 0.4 { finish() }
    }

    /// Screenshot and App Preview runs (the demo pitch has no strokes to hear): the player strums on time,
    /// a little human, and one stroke in eight lands a touch late, so the beat row shows its call.
    private func demoStrokes(at t: Double) {
        let jitter = [0.012, -0.018, 0.026, -0.008]
        for (i, time) in expected.enumerated() where grades[i] == nil {
            let off = i % 8 == 1 ? 0.12 : jitter[i % jitter.count]
            if t >= time + off { register(startTime + time + off) }
        }
    }

    private func finish() {
        let points = grades.values.reduce(0.0) { $0 + ($1 == .perfect ? 1 : $1 == .good ? 0.8 : $1 == .ok ? 0.5 : 0) }
        score = expected.isEmpty ? 1 : points / Double(expected.count)
        // The coach reads chord-change timing from strummed takes heard on the instrument.
        if instrumentStep && !micOff {
            switch mode {
            case .strum(let chord?):
                CoachTakes.shared.record(CoachTake.strummed(chords: [chord], bars: [bars], pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm, offsets: offsets, strays: strays))
            case .progression(let chords, let lengths):
                CoachTakes.shared.record(CoachTake.strummed(chords: chords, bars: lengths, pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm, offsets: offsets, strays: strays))
            default:
                break
            }
        }
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: score >= 0.7)
        ownsClick = false
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { phase = .done; counting = false }
        SoundFX.shared.play(score >= 0.7 ? .correct : .wrong)
    }

    /// The app went to the background mid-take: the click, the band and the microphone stop and the take is
    /// dropped (nothing graded, nothing for the coach). The step is back at Start.
    private func abandonTake() {
        guard phase == .playing else { return }
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        store.stopLessonListening(owner: owner)
        hits = []; grades = [:]; offsets = [:]; strays = [:]; score = 0
        counting = false
        phase = .ready
        appeared = CACurrentMediaTime()
        // `stopBand` forgets the prepared arrangement; the next take wants it again.
        store.audio.prepareBand(band)
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
    /// Strings ticked off. It runs one ahead of `index` for a beat after a string locks: that string shows
    /// done (chip filled, note in the accent) before the next one takes over.
    @State private var tuned = 0
    @State private var finished = false
    /// The big note's opacity: a locked note fades out completely before the next string takes over.
    @State private var noteVisible = true
    /// The beat after a lock (the string showing done, then the hand-over); it ends with the step, so it never
    /// points the demo pitch or the tuner at a lesson string after the lesson has closed.
    @State private var lockTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    /// The strip's string order, which the rail reads: the app's one picture choice (`ChordPicture`).
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab

    /// A string just locked and is showing done before the check moves on.
    private var settling: Bool { tuned > index }

    /// One open string on the rail: its number (1 is the thinnest) and its note.
    private struct RailString {
        let number: Int
        let midi: Int
    }

    /// The open strings in the order the check runs and the rail shows them: a checklist read against the neck strip
    /// right under it, so the string the strip draws on top comes first, on the left (string 1 in the Chart view, the
    /// thickest in Player view), as the Intonation tool's rail reads its neck. A banjo's short drone string is left out.
    private var rail: [RailString] {
        let open = ChordStep.openStrings(course)
        let count = open.count
        // The open strings run lowest first: the one at `offset` is string `count - offset`.
        let all = open.enumerated()
            .filter { !(course.fretKind == "banjo" && $0.offset == 0) }
            .map { RailString(number: count - $0.offset, midi: $0.element) }
        let order = stringOrder
        return all.sorted { order.row(ofString: $0.number, count: count) < order.row(ofString: $1.number, count: count) }
    }

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
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                StepTitle("Quick tune check")
                Text("Pluck each open string. In-tune strings help Timbre hear you right.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
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
                                 activeString: number, fretless: course.fretless, rowHeight: 15, pulsing: true, edges: StringEdges.of(course))
                    .padding(.horizontal, Metrics.gutter)
                    .transition(.opacity)
            }
            MicrophoneHint()
            LessonActionBar {
                LessonBarButton(title: "My strings are tuned — skip") { finish() }
                    .accessibilityIdentifier("lesson.tunecheck.skip")
            }
        }
        .onAppear { listen() }
        .onDisappear { lockTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The microphone stops in the background; listen for the string again on return.
        .onChange(of: scenePhase) { _, phase in if phase == .active && !finished && !settling { listen() } }
    }

    /// The string to tune, top to bottom: its note, the rings (rippling while it's heard, still between
    /// plucks) around an orb that points the way to turn, then the meter and what to do in words.
    /// Nothing sits on top of the rings.
    private var listeningCluster: some View {
        VStack(spacing: 12) {
            // One view throughout. The locked note turns to the accent, then fades out completely; only then does the
            // next string take over (chips, neck and note together) and its note fade in: never two at once, and
            // never the last string's note beside the next string's chip.
            Text(verbatim: index < strings.count ? NoteName.name(strings[index]) : "✓").font(Typeface.note(64))
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
        }
        .layoutPriority(1)
    }

    /// What the check shows for the string being tuned, read once from the latest reading: the orb's symbol and
    /// colour, the meter and the hint all come from it, so they can never disagree (bug 52: an amber tick beside
    /// "Tune up a little").
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
        HStack(spacing: 8) {
            ForEach(Array(rail.enumerated()), id: \.offset) { i, string in
                stringChip(string, done: i < tuned, current: i == index && i >= tuned)
            }
        }
        // The chips keep their size: the note and the number stop growing before they would crowd the chip.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(Motion.pluck, value: index)
        .animation(Motion.pluck, value: tuned)
        .background(alignment: .leading) {
            // Behind the chips, centred on the one just tuned (outside the animation, so it doesn't slide):
            // sparks leave from the chip's rim, no ring, so nothing reaches across the title or the note.
            SparkBurst(trigger: burst, color: accent, reach: 70, startFraction: 0.32, ring: false)
                .frame(width: 140, height: 140)
                .offset(x: CGFloat(max(0, tuned - 1)) * (Self.chip + 8) + Self.chip / 2 - 70)
        }
    }

    private static let chip: CGFloat = 44

    private func stringChip(_ string: RailString, done: Bool, current: Bool) -> some View {
        let ink = done ? Palette.onAccent : current ? Palette.ink : Palette.inkSoft
        return VStack(spacing: -1) {
            Text(NoteName.pitchClass(string.midi)).font(Typeface.label(15))
            Text(verbatim: "\(string.number)").font(Typeface.number(11)).opacity(0.75)
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
            guard index < strings.count, let hz else { cents = nil; holdStart = nil; return }
            let target = frequency(strings[index], store)
            let off = PitchMath.cents(target: target, measured: hz)
            guard abs(off) < 300 else { cents = nil; return }
            cents = off
            let now = CACurrentMediaTime()
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
