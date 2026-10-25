import SwiftUI
import TimbreCore

/// The Chords and Scales tools (Practice › Tools). Chords is free with its open-position shapes and Check (`FreeTier`);
/// Scales is Pro (the Practice hub opens it).
struct ChordsView: View {
    enum Mode { case chords, scales }
    let mode: Mode
    @EnvironmentObject private var store: AppStore

    var body: some View {
        switch mode {
        // Chords opens on the chord it showed last (`UserSettings.lastChord`).
        case .chords: ChordLibraryView(start: store.settings.lastChord)
        case .scales: ScaleLibraryView()
        }
    }
}

extension UserSettings.ChordChoice {
    /// The saved chord's root (0…11) and quality; nil when its quality is not one the Chords tool offers.
    var resolved: (root: Int, formula: ChordFormula)? {
        guard let quality = ChordFormula.all.first(where: { $0.id == formula }) else { return nil }
        return (root: ((root % 12) + 12) % 12, formula: quality)
    }
}

// MARK: - Chords

/// Chords: a root and a quality, the chord spelled in its key with its formula, and every shape for it in a card
/// that names it ("Barre · 3fr"), rates how hard it is to hold and strums it on a tap: a glint of light crosses the
/// box low to high as each string lights with the sound. "Check" listens with the lessons' chord recognizer
/// (any shape and any inversion count, as in a lesson's chord step) and says when the chord rings true.
/// On the free plan the open-position shapes play and Check listens for any chord that has one; barre and movable
/// shapes wear a lock and open the paywall (`FreeTier.canUseVoicing`).
struct ChordLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var root = 0
    @State private var formula = ChordFormula.all[0]
    /// The shape sounding now and the strings its strum has crossed so far (lit on its box).
    @State private var ringing: ChordShape?
    @State private var ringStrings: Set<Int> = []
    /// Strums per shape: a change replays that card's glint.
    @State private var strums: [ChordShape: Int] = [:]
    @State private var strumTask: Task<Void, Never>?
    /// Check: idle, listening (with what the microphone hears as a chord) or heard.
    @State private var check = ChordCheck.idle
    @State private var heard: String?
    @State private var matchedFrames = 0
    @State private var owner = UUID()
    @State private var celebrate = 0

    /// `start`: the chord to open on (the one shown last); C major without one.
    init(start: UserSettings.ChordChoice? = nil) {
        if let saved = start?.resolved {
            _root = State(initialValue: saved.root)
            _formula = State(initialValue: saved.formula)
        }
    }

    var body: some View {
        let strings = OpenStrings(store)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.tuning.name.localized + " · " + store.instrumentDisplayName).font(.subheadline).foregroundStyle(Palette.inkSoft)
                RootRail(root: $root) { pitchClass in
                    Spelling.name(Spelling.chord(root: pitchClass, intervals: formula.intervals).root)
                }
                qualityRail
                header
                voicings(strings)
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Chords")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock { checkDock }
        .onAppear { store.beginPractice(DailyActivity.Kind.chord.rawValue) }
        .onDisappear {
            strumTask?.cancel()
            store.stopLessonListening(owner: owner)
            store.finishPractice(.chord)
        }
        .onChange(of: root) { _, _ in chordChanged() }
        .onChange(of: formula) { _, _ in chordChanged() }
    }

    /// The chord as written in its key: "C♯m" (not "D♭m"), "E♭7".
    private var chordName: String {
        Spelling.name(Spelling.chord(root: root, intervals: formula.intervals).root) + formula.suffix
    }

    private var qualityRail: some View {
        EdgeRail(spacing: 6, selection: formula.id) {
            ForEach(ChordFormula.all) { f in
                Button(f.suffix.isEmpty ? String(localized: "Major") : f.suffix) { formula = f; Haptics.shared.selection() }
                    .buttonStyle(ChipButtonStyle(selected: formula == f))
                    .id(f.id)
            }
        }
    }

    /// The name large with the quality beside it, and the chord's notes over their degrees (C E G over 1 3 5).
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(chordName).font(Typeface.display(64)).foregroundStyle(Palette.ink)
                    .heroNumeral(minimumScale: 0.6)
                    .shadow(color: Palette.mint.opacity(check == .heard ? 0.55 : 0), radius: 18)
                Text(formula.name).font(.subheadline).foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
                if check == .heard {
                    Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Palette.mint)
                        .symbolEffect(.bounce, value: celebrate)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .accessibilityLabel(Text("Nice — that’s right."))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ToneStrip(tones: chordTones)
        }
        .animation(Motion.pluck, value: check)
    }

    private var chordTones: [ToneStrip.Tone] {
        let intervals = formula.intervals
        let spelled = Spelling.chord(root: root, intervals: intervals)
        var rows: [(order: Int, tone: ToneStrip.Tone)] = []
        for (interval, note) in zip(intervals, spelled.tones) {
            let degree = Spelling.chordDegree(interval, in: intervals)
            rows.append((order: degree.order, tone: ToneStrip.Tone(name: Spelling.name(note), degree: degree.label, isRoot: interval == 0)))
        }
        return rows.sorted { $0.order < $1.order }.map { $0.tone }
    }

    // MARK: Shapes

    /// Curated open and barre shapes in standard guitar tuning; playable finder shapes elsewhere.
    @ViewBuilder private func voicings(_ strings: OpenStrings) -> some View {
        let shapes = ChordLibrary.voicings(root: root, formula: formula, openMidi: strings.midi, limit: 6)
        if shapes.isEmpty {
            EmptyState(symbol: "hand.raised.fingers.spread", title: "No comfortable shape for this chord in this tuning.")
                .stillCard()
        } else {
            VStack(alignment: .trailing, spacing: 12) {
                // Chart or player's view, as in the lessons: the app's one picture choice (Settings › String order).
                ChordPictureToggle()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(shapes, id: \.self) { shape in
                        voicingCard(shape, strings: strings)
                    }
                }
                if shapes.contains(where: { !isOpen($0, strings: strings) }) { proNote }
            }
        }
    }

    /// One shape's card: it strums, or (a Pro shape on the free plan) opens the paywall.
    private func voicingCard(_ shape: ChordShape, strings: OpenStrings) -> some View {
        let open = isOpen(shape, strings: strings)
        return VoicingCard(shape: shape, spec: spec(for: shape), profile: VoicingProfile(shape, formulaId: formula.id),
                           chordName: chordName, lit: ringing == shape ? ringStrings : [], strums: strums[shape] ?? 0,
                           locked: !open) {
            if open { strum(shape, strings: strings) } else { store.presentPaywall("chords.voicing") }
        }
    }

    /// Under the grid on the free plan, when some shapes are Pro: what is free and what isn't.
    private var proNote: some View {
        Label("Open shapes are free. Barre and movable shapes come with Timbre Pro.", systemImage: "lock")
            .font(.footnote).foregroundStyle(Palette.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func isOpen(_ shape: ChordShape, strings: OpenStrings) -> Bool {
        FreeTier.canUseVoicing(shape, root: root, formula: formula, openMidi: strings.midi, pro: commerce.isPro)
    }

    /// Check is free for any chord the free plan has a shape for (and always with Pro).
    private var checkOpen: Bool {
        let strings = OpenStrings(store)
        if commerce.isPro { return true }
        return ChordLibrary.voicings(root: root, formula: formula, openMidi: strings.midi, limit: 6).contains { isOpen($0, strings: strings) }
    }

    private func spec(for shape: ChordShape) -> ChordSpec {
        ChordSpec(name: "", root: root, quality: formula.name, frets: shape.frets.map { $0 ?? -1 },
                  fingers: shape.fingers, baseFret: shape.highestFret <= 4 ? nil : shape.lowestFret)
    }

    /// Strums the shape (the sound runs low to high, about 25 ms a string) and lights its strings in the same
    /// order, a little slower so the eye can follow; they ring lit until the chord fades. A check in progress
    /// pauses while it sounds, so the microphone doesn't take the strum for the player.
    private func strum(_ shape: ChordShape, strings: OpenStrings) {
        let reference = store.settings.referencePitchHz
        var sounding: [(string: Int, midi: Int)] = []
        for (index, fret) in shape.frets.enumerated() {
            guard let fret, index < strings.midi.count else { continue }
            sounding.append((string: index, midi: strings.midi[index] + fret))
        }
        guard !sounding.isEmpty else { return }
        let resume = check == .listening
        if resume { store.stopLessonListening(owner: owner) }
        audio.playTones(sounding.map { PitchMath.frequency(midi: Double($0.midi), reference: reference) }, together: true, noteMs: 1500)
        Haptics.shared.selection()
        strums[shape, default: 0] += 1
        strumTask?.cancel()
        ringing = shape
        ringStrings = []
        let order = sounding.sorted { $0.midi < $1.midi }.map { $0.string }
        let step = reduceMotion ? 0 : 40
        strumTask = Task { @MainActor in
            for string in order {
                withAnimation(Motion.quick) { _ = ringStrings.insert(string) }
                if step > 0 { try? await Task.sleep(for: .milliseconds(step)) }
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(1500))
            if Task.isCancelled { return }
            withAnimation(Motion.settle) { ringing = nil; ringStrings = [] }
            if resume, check == .listening { listen() }
        }
    }

    // MARK: Check

    /// The chord as the recognizer knows it (a sixth or a ninth checked as the chord it colours, `ChordTarget`); nil for
    /// the few it can't check (6/9, 7sus4, 11, 13, m7♭5).
    private var target: ChordTarget? { ChordTarget(root: root, formulaId: formula.id) }

    private func startCheck() {
        guard target != nil else { return }
        heard = nil
        withAnimation(Motion.settle) { check = .listening }
        Haptics.shared.selection()
        listen()
    }

    /// The microphone with the lessons' chord listener (`LessonAnalyzer`, `ChordRecognizer`) on the chord on screen:
    /// three matching readings in a row and it's heard.
    private func listen() {
        guard let target else { return }
        matchedFrames = 0
        let analyzer = LessonAnalyzer(chords: true, target: target, onChord: { estimate, matched in
            guard check == .listening else { return }
            let name = estimate.map { heardName($0) }
            if name != heard { withAnimation(Motion.quick) { heard = name } }
            matchedFrames = matched ? matchedFrames + 1 : 0
            if matchedFrames >= 3 { succeed() }
        })
        store.startLessonListening(owner: owner, analyzer: analyzer) { _, _ in }
    }

    private func succeed() {
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.pluck) { check = .heard }
        SoundFX.shared.play(.correct)
        Haptics.shared.lock()
        // A beat later, once the seal and the heard capsule are on screen, so their bounce and ring play.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            celebrate += 1
        }
    }

    private func stopCheck() {
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { check = .idle; heard = nil }
    }

    /// A new chord: the strum's lights go; a check listens for the new chord (or stops, if it can't hear that kind).
    /// It is kept as the chord shown last: the tool opens on it next time and the Practice hub's tile strums it.
    private func chordChanged() {
        strumTask?.cancel()
        ringing = nil
        ringStrings = []
        let choice = UserSettings.ChordChoice(root: root, formula: formula.id)
        store.updateSettings { $0.lastChord = choice }
        switch check {
        case .idle: break
        case .heard: withAnimation(Motion.settle) { check = .idle; heard = nil }
        case .listening:
            if target == nil { stopCheck() } else { heard = nil; listen() }
        }
    }

    /// What the recognizer hears, spelled in its own key ("Hearing C♯m").
    private func heardName(_ estimate: ChordEstimate) -> String {
        Spelling.name(Spelling.chord(root: estimate.root, intervals: estimate.quality.intervals).root) + estimate.quality.suffix
    }

    @ViewBuilder private var checkDock: some View {
        VStack(spacing: 10) {
            if audio.permissionDenied && check == .listening {
                MicrophoneHint().padding(.horizontal, -Metrics.gutter)
            }
            if target == nil {
                Label("Check listens for major, minor, 7th, sus and power chords.", systemImage: "waveform")
                    .font(.footnote).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: 54)
            } else {
                switch check {
                case .idle: checkButton
                case .listening: listeningBar
                case .heard: heardBar
                }
            }
        }
        .animation(Motion.settle, value: check)
    }

    /// One verb for it, as in the lessons: "Check". A chord with only Pro shapes keeps it, locked.
    private var checkButton: some View {
        let open = checkOpen
        return Button {
            if open { startCheck() } else { store.presentPaywall("chords.check") }
        } label: {
            Label("Check", systemImage: open ? "mic.fill" : "lock.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("chords.check")
        .accessibilityHint(open ? Text("Listens while you play the chord.") : Text("Timbre Pro"))
    }

    /// Listening: what to strum, and what the microphone hears (amber until it is the chord).
    private var listeningBar: some View {
        let right = heard == chordName
        return HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "waveform").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.mint)
                    .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strum \(chordName)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Group {
                        if let heard { Text("Hearing \(heard)") } else { Text("Listening…") }
                    }
                    .font(.footnote).foregroundStyle(heard == nil ? Palette.inkSoft : (right ? Palette.mint : Palette.amber))
                    .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Palette.stageRaised))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1))
            .accessibilityElement(children: .combine)
            Button("Stop", action: stopCheck)
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 104)
                .accessibilityIdentifier("chords.stop")
        }
    }

    /// Heard: a seal and the word, a ring of light leaving the capsule, and Check again.
    private var heardBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.mint)
                    .symbolEffect(.bounce, value: celebrate)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nice — that’s right.").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(chordName).font(.footnote).foregroundStyle(Palette.mint)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Palette.mint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.5), lineWidth: 1))
            .background { HeardRing(trigger: celebrate) }
            .accessibilityElement(children: .combine)
            Button("Check again", action: startCheck)
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 132)
                .accessibilityIdentifier("chords.check")
        }
    }
}

enum ChordCheck: Equatable { case idle, listening, heard }

/// A capsule of mint light swelling out from behind the heard capsule and fading, once per success.
private struct HeardRing: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Capsule().strokeBorder(Palette.mint, lineWidth: 2)
            .keyframeAnimator(initialValue: RingFrame(), trigger: trigger) { ring, frame in
                ring.scaleEffect(x: frame.scale, y: 1 + (frame.scale - 1) * 3).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: 0.01)
                    CubicKeyframe(1.08, duration: 0.55)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.8, duration: 0.01)
                    LinearKeyframe(0, duration: 0.55)
                }
            }
            .opacity(reduceMotion ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct RingFrame {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }
}

/// One shape: its name and how hard it is over the box, the fret notation and a play glyph under it. A tap strums
/// it; the strings it rings light low to high, a glint sweeps the box, and the card glows mint while it sounds.
private struct VoicingCard: View {
    let shape: ChordShape
    let spec: ChordSpec
    let profile: VoicingProfile
    let chordName: String
    let lit: Set<Int>
    let strums: Int
    /// A Pro shape on the free plan: its box dimmed, a lock in the corner, and a tap opens the paywall.
    var locked = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ChordPicture.storageKey) private var picture: ChordPicture = .chart

    var body: some View {
        let sounding = !lit.isEmpty
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.title).font(Typeface.label(13, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    DifficultyMeter(level: profile.level)
                }
                diagram
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .opacity(locked ? 0.45 : 1)
                    // Both pictures lay the lowest string on the left, so the glint runs left to right on either.
                    .overlay { if !reduceMotion { StrumGlint(trigger: strums) } }
                HStack(spacing: 8) {
                    Text(shape.notation).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 4)
                    if !locked { playGlyph(sounding) }
                }
            }
            .stillCard(padding: Metrics.tilePadding, tint: sounding ? Palette.mint : nil)
            .overlay(alignment: .topTrailing) { if locked { ProLock().padding(10) } }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("\(chordName), \(profile.title), \(profile.level.name), \(shape.notation)"))
        .accessibilityHint(locked ? Text("Timbre Pro") : Text("Plays the chord."))
    }

    /// The shape as a chart, or in the player's view (the lessons' switch, over the grid), tipping between them as a
    /// lesson's card does.
    private var diagram: some View {
        ZStack {
            if picture == .player {
                PlayerNeck(chord: spec, accent: Palette.mint, ringing: lit, compact: true)
                    .transition(ChordFlip.transition(toPlayer: true, reduceMotion: reduceMotion))
            } else {
                ChordDiagram(chord: spec, showName: false, ringing: lit, reservesFretLabel: true)
                    .transition(ChordFlip.transition(toPlayer: false, reduceMotion: reduceMotion))
            }
        }
    }

    private func playGlyph(_ sounding: Bool) -> some View {
        Image(systemName: sounding ? "speaker.wave.2.fill" : "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(sounding ? Palette.onAccent : Palette.mint)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.variableColor.iterative, isActive: sounding && !reduceMotion)
            .frame(width: 30, height: 30)
            .background(Circle().fill(sounding ? Palette.mint : Palette.mint.opacity(0.14)))
            .overlay(Circle().strokeBorder(Palette.mint.opacity(sounding ? 0 : 0.3), lineWidth: 1))
    }
}

/// The pick crossing the strings: a narrow band of mint light sweeping the box from the lowest string to the
/// highest in about a third of a second, each time `trigger` changes.
private struct StrumGlint: View {
    let trigger: Int

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            LinearGradient(colors: [.clear, Palette.mint.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 36)
                .blendMode(.plusLighter)
                .keyframeAnimator(initialValue: GlintFrame(), trigger: trigger) { glint, frame in
                    glint.offset(x: -36 + frame.progress * (width + 36)).opacity(frame.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.progress) {
                        LinearKeyframe(0, duration: 0.01)
                        CubicKeyframe(1, duration: 0.32)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1, duration: 0.04)
                        LinearKeyframe(1, duration: 0.2)
                        LinearKeyframe(0, duration: 0.12)
                    }
                }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct GlintFrame {
        var progress: CGFloat = 0
        var opacity: Double = 0
    }
}

/// Easy, Medium or Hard: three rising bars, as many lit as the level, and the word, in the steel of a difficulty.
struct DifficultyMeter: View {
    let level: VoicingProfile.Level

    var body: some View {
        HStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...3, id: \.self) { bar in
                    Capsule()
                        .fill(bar <= level.rawValue ? level.tint : Palette.line)
                        .frame(width: 3, height: 4 + CGFloat(bar) * 3)
                }
            }
            Text(level.name).font(.caption2.weight(.semibold)).foregroundStyle(level.tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(level.name))
    }
}

// MARK: - Shared by Chords and Scales

/// The tuning's open strings, one per physical string (paired courses count once), lowest-numbered course first,
/// with their names as the tuning spells them (E♭ standard reads E♭ A♭ D♭ G♭ B♭ E♭).
struct OpenStrings: Equatable {
    let midi: [Int]
    let names: [String]

    @MainActor init(_ store: AppStore) {
        var seen = Set<String>()
        var midi: [Int] = []
        var names: [String] = []
        for course in store.courses where seen.insert(course.anchorId ?? "\(course.index)").inserted {
            midi.append(course.targetMidi)
            names.append(Self.name(label: course.label, midi: course.targetMidi))
        }
        self.midi = midi
        self.names = names
    }

    /// The letter and accidentals of a course label ("Eb2", "F#3") with proper signs, in the player's naming system.
    static func name(label: String, midi: Int) -> String {
        guard let letter = label.first, "ABCDEFG".contains(letter) else { return NoteNames.name(midi % 12, preferFlats: true) }
        let marks = label.dropFirst().prefix { "#b♯♭".contains($0) }
        let signs = marks.map { mark -> String in
            if mark == "#" { return "♯" }
            if mark == "b" { return "♭" }
            return String(mark)
        }
        return NoteNames.spell(String(letter) + signs.joined(), system: Spelling.system)
    }
}

/// The twelve roots as chips, each written the way the chord or scale on screen is spelled in its key (C♯ for C♯
/// minor, D♭ for D♭ major). The rail runs under the screen's edges and fades there while more chips wait.
struct RootRail: View {
    @Binding var root: Int
    let name: (Int) -> String

    var body: some View {
        EdgeRail(spacing: 6, selection: root) {
            ForEach(0..<12, id: \.self) { pitchClass in
                Button {
                    root = pitchClass
                    Haptics.shared.selection()
                } label: {
                    Text(name(pitchClass)).contentTransition(.opacity)
                }
                .buttonStyle(ChipButtonStyle(selected: root == pitchClass))
                .accessibilityAddTraits(root == pitchClass ? .isSelected : [])
                .id(pitchClass)
            }
        }
    }
}

/// The notes of a chord or scale in tiles, each over its degree (C E G over 1 3 5; E♭ over ♭3); the root's tile gold,
/// as roots are on the neck.
struct ToneStrip: View {
    struct Tone: Hashable {
        let name: String
        let degree: String
        let isRoot: Bool
    }

    let tones: [Tone]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(tones.enumerated()), id: \.offset) { _, tone in tile(tone) }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tones.map(\.name).joined(separator: ", ")))
    }

    private func tile(_ tone: Tone) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous)
        return VStack(spacing: 2) {
            // The sign in the system face: Sora's fallback sets ♭ full width ("E ♭").
            NoteGlyphs.text(tone.name, sign: .system(.subheadline, weight: .semibold)).font(Typeface.label(15, relativeTo: .subheadline))
                .foregroundStyle(tone.isRoot ? Palette.starGold : Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(tone.degree).font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkFaint)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .frame(minWidth: 0, maxWidth: 54)
        .background(shape.fill(tone.isRoot ? Palette.starGold.opacity(0.12) : Palette.stageRaised))
        .overlay(shape.strokeBorder(tone.isRoot ? Palette.starGold.opacity(0.4) : Palette.hairline, lineWidth: 1))
        .contentTransition(.opacity)
    }
}
