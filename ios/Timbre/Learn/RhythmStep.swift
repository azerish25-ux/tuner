import Combine
import QuartzCore
import SwiftUI
import TimbreCore

// MARK: - Rhythm: tap or strum on the pattern

/// A rhythm take, laid out to use the whole screen: the title (a strum's chord beside it, a progression's strip under
/// it), the beat lane with every down and up stroke and the pick riding it as the playhead, then the instrument's
/// strings filling everything down to the button, the pick sweeping them in time with the click. The count-in shows
/// big over the strings as the take starts, the score over them once it's done. Before Start both picks preview the
/// pattern at the step's tempo, on one clock.
/// The strings lie as the player sees them looking down (`StrumSweep`: the thickest on top, the neck to the left; the
/// neck to the right for a left-handed player, string 1 on top for one playing a right-handed instrument turned over),
/// so the pick goes down the screen on a ↓; the chord beside the title is a fretting picture and follows the picture
/// choice, as every chord box does.
/// On a strummed instrument heard through the microphone every stroke is graded for what it rang as well as its timing
/// (`StrumTake`, `StrokeChords`): another chord holds the stroke to OK and names what rang ("Am?"), no chord at all
/// misses a down stroke. A muted beat (a chunk, a chop) asks for the opposite: no chord, or one stopped dead, and a
/// chop left ringing is held to OK ("Let it stop"). An accented beat must stand out from the rest ("Push the and of
/// 2"). A take where most played strokes rang the wrong chord keeps the lesson to one star.
/// Before Start, "Show me" under the strings plays the pattern on the course instrument's 3D model in their place
/// (`ShowMeStage`, seen the same way up, its pick on the preview's clock) while two bars of it sound; Start brings the
/// strings back before the click and the microphone start. Without a model, with Reduce Motion or in Low Power Mode
/// the strings stay alone. The first time the pattern appears in the course the model comes in by itself once the step
/// has settled (`ShowMe.firstTime`), with a line under "Show me" saying what the pick does. A tap step on an
/// instrument course is strummed on the open strings, and is titled so (`RhythmStepTitle`).
struct RhythmStep: View {
    enum Mode { case tap, strum(ChordSpec?), progression([ChordSpec], [Int]) }
    let mode: Mode
    let pattern: [Double]
    let bpm: Double
    let bars: Int
    /// Beats in a bar when the lesson sets it (3/4, 6/8 in eighths); otherwise 4, or longer if the pattern needs it.
    var meter: Int?
    /// Beats of the pattern played muted (chunks, chops) and accented, as `pattern` counts them.
    var muted: [Double] = []
    var accents: [Double] = []
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
    /// The take limits the lesson's stars (most of its strokes rang the wrong chord).
    var onStarCap: (Int) -> Void = { _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var startTime: CFTimeInterval = 0
    @State private var appeared = CACurrentMediaTime()
    /// The take stroke by stroke: timing, what each stroke rang, the muted and accented beats. Strokes are stamped
    /// with their host time, so each one's reading, a moment later, finds it.
    @State private var take = StrumTake(pattern: [], bars: 0, bpm: 60)
    /// "Start on first strum": before a take, the microphone waits for the instrument and the count-in starts on it.
    @AppStorage("lesson.startOnStrum") private var startOnStrum = false
    @State private var armed = false
    @State private var armedAt: CFTimeInterval = 0
    @State private var pulse = 0
    @State private var score = 0.0
    /// No microphone (refused, or it failed to start): the screen stands in for the instrument.
    @State private var micOff = false
    /// The bar before the first stroke is clicking: its count shows big over the strings.
    @State private var counting = false
    /// This step started the click that's running, so it stops it when it goes. A click it didn't start (the
    /// Metronome tool's) is left alone until a take restarts the click fresh.
    @State private var ownsClick = false
    @State private var audioStart = AudioStartGate()
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
    /// The height the stage has, so a first-time demonstration only comes in where "Show me" has room under it.
    @State private var stageRoom: CGFloat = 0
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    /// How the player holds the instrument (Settings › Handedness): the strum stage is drawn as they see it.
    @CurrentHand private var hand

    enum Phase { case ready, playing, done }
    private var beatsPerBar: Int { meter ?? max(4, Int((pattern.max() ?? 3) + 1)) }
    private var spb: Double { 60 / bpm }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var barLength: Double { Double(beatsPerBar) * spb }
    /// When each stroke is due, from the take's start (`StrumTake.expected`).
    private var expected: [Double] { take.expected }
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

    /// The step's title, from the one place the iPad outline also reads it (`RhythmStepTitle`).
    private var title: LocalizedStringKey {
        RhythmStepTitle.of(kind, onInstrument: instrumentStep, strums: strums, tapping: tapping)
    }

    private var kind: RhythmStepTitle.Kind {
        switch mode {
        case .tap: return .tap
        case .strum: return .strum
        case .progression: return .progression
        }
    }

    /// Strokes are graded for their chord as well as their timing: a strummed instrument heard through the microphone,
    /// on a step with chords (a tap step's open strings have none to check).
    private var checksChords: Bool {
        guard instrumentStep, !micOff, !LessonMicrophone.demo, LearnCourse.strummed(course?.instrument) else { return false }
        switch mode {
        case .tap: return false
        case .strum(let chord): return chord.flatMap(Self.target) != nil
        case .progression(let chords, _): return chords.contains { Self.target($0) != nil }
        }
    }

    private static func target(_ chord: ChordSpec) -> ChordTarget? { ChordTarget(root: chord.root, formulaId: chord.quality) }

    /// Each stroke is read a moment after it (`StrokeChords`): on a strummed instrument heard through the microphone,
    /// for a chord to check, a muted beat to hear stop or an accent to hear stand out.
    private var readsStrokes: Bool {
        guard instrumentStep, !micOff, !LessonMicrophone.demo, LearnCourse.strummed(course?.instrument), !isTap else { return false }
        return checksChords || !muted.isEmpty || !accents.isEmpty
    }

    /// The chord each bar asks for (a progression's chords for their bars, the last one again past the end); none
    /// where chords aren't checked.
    private var barTargets: [ChordTarget?] {
        guard checksChords else { return [] }
        switch mode {
        case .tap:
            return []
        case .strum(let chord):
            return [chord.flatMap(Self.target)]
        case .progression(let chords, let lengths):
            var targets: [ChordTarget?] = []
            for (i, n) in lengths.enumerated() {
                let chord = i < chords.count ? chords[i] : chords.last
                targets += Array(repeating: chord.flatMap(Self.target), count: max(0, n))
            }
            targets.append(chords.last.flatMap(Self.target))
            return targets
        }
    }

    /// A fresh take of this step's pattern.
    private func freshTake() -> StrumTake {
        StrumTake(pattern: pattern, beatsPerBar: beatsPerBar, bars: bars, bpm: bpm, muted: muted, accents: accents, chords: barTargets)
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
        // Once the step has settled: the first time this pattern appears in the course its demonstration plays by
        // itself on the model (before Start, so never while the step listens); otherwise the model loads quietly, so
        // "Show me" is immediate (once per lesson). Never once a take is under way.
        .task {
            try? await Task.sleep(for: .seconds(ShowMe.settle))
            guard !Task.isCancelled, phase == .ready else { return }
            if playsFirstOnModel {
                setShowMe(true, tapped: false)
                return
            }
            arm()
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, phase == .ready, let model = showMeModel else { return }
            ModelCache.shared.prefetch(model)
        }
        .onChange(of: startOnStrum) { _, on in if on { arm() } else { disarm() } }
        .onReceive(store.audio.$permissionDenied) { denied in if denied { micOff = true } }
        .onReceive(store.audio.$error) { error in
            // The microphone failed to start mid-take: the screen takes over.
            if error != nil, phase == .playing, instrumentStep, !store.audio.running { micOff = true }
        }
        // Leaving the app mid-take drops the take: no click left sounding in a pocket, nothing half-heard graded.
        // A demonstration stops where it is ("Show me" plays it again).
        .onChange(of: scenePhase) { _, now in
            if now == .background { stopShowMeSound(); disarm(); abandonTake() } else if now == .active { arm() }
        }
        .onDisappear {
            audioStart.cancel()
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
                    if !isTap { BandControls(audio: store.audio, accent: accent, speaker: .click) }
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
                Text("Bar \(bar + 1) of \(bars)").font(Typeface.label(.footnote)).foregroundStyle(Palette.inkSoft)
                    .opacity(phase == .done ? 0 : 1)
                LessonBeatRow(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: playhead(now: now, elapsed: elapsed, bar: bar),
                              calls: calls(inBar: bar), arrows: !isTap || strums, restingPick: phase != .done, muted: muted, accents: accents)
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

    /// How each stroke of `bar` went, by its place in the pattern: a judged stroke with its timing and what else cost
    /// it, a miss with the nearest stroke heard outside its window (or none).
    private func calls(inBar bar: Int) -> [Int: BeatCall] {
        guard !take.pattern.isEmpty else { return [:] }
        var out: [Int: BeatCall] = [:]
        for (i, grade) in take.grades where take.bar(of: i) == bar {
            out[take.slot(of: i)] = BeatCall(grade: grade, offset: grade == .miss ? take.strays[i] : take.offsets[i], call: take.calls[i])
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
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { stageRoom = $0 }
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
    /// "Show me"'s row under the strings and the line under it (what to watch), with their gaps.
    private static let showMeRowHeight: CGFloat = Metrics.minTarget + 8 + 20 + 4

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
                       secondsPerBeat: spb, time: sweepTime(CACurrentMediaTime()), bars: phase == .playing ? bars : nil, edges: edges,
                       mirrored: hand.hand.nutOnRight, stringOrder: hand.strumOrder)
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

    /// The take's score over the dimmed strings, in its grade's colour; under it the one thing to work on first, when
    /// strokes were read: a chop that rang, an accent to push, or how many strokes rang the right chord.
    private func scoreBadge(compact: Bool) -> some View {
        let tint = ScoreTint.color(score)
        return VStack(spacing: 2) {
            Text("\(Int((score * 100).rounded()))% on the beat")
                .font(Typeface.display(compact ? .title3 : .title)).foregroundStyle(tint)
            if !compact, let note = takeNote {
                Text(note)
                    .font(Typeface.label(.footnote)).foregroundStyle(Palette.inkSoft)
            }
        }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.vertical, compact ? 6 : 14)
            .background(Capsule().fill(Palette.stage.opacity(0.85)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.45), lineWidth: 1.5))
            .shadow(color: tint.opacity(0.35), radius: 18)
    }

    /// The one thing to work on first once the take is over, when its strokes were read: muted strokes that rang, an
    /// accent to push, or how many played strokes rang the right chord; nil with nothing to say.
    private var takeNote: String? {
        if take.calls.values.contains(.ringing) { return String(localized: "Muted strokes rang: let them stop") }
        if let beat = take.accentToPush { return Self.push(beat) }
        guard !take.chordRight.isEmpty else { return nil }
        return String(localized: "\(take.chordRight.values.filter { $0 }.count) of \(take.chordRight.count) chords right")
    }

    /// "Push beat 3", "Push the and of 2": the accent to play harder, by its count.
    static func push(_ beat: Double) -> String {
        let number = Int(beat.rounded(.down)) + 1
        if beat.truncatingRemainder(dividingBy: 1) == 0 { return String(localized: "Push beat \(number)") }
        return String(localized: "Push the and of \(number)")
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
        case .ready:
            if offersStrumStart {
                VStack(spacing: 10) {
                    strumStartToggle
                    StepButton(title: "Start", accent: accent) { start() }
                }
            } else {
                StepButton(title: "Start", accent: accent) { start() }
            }
        case .playing: StepButton(title: "Listening…", accent: accent, enabled: false) {}
        case .done:
            LessonActionBar {
                LessonBarButton(title: "Try again", role: .again) { start() }
                StepButton(title: "Continue", accent: accent, inset: false) {
                    if practice { onPractice() }
                    if take.chordsMostlyWrong { onStarCap(1) }
                    done(score)
                }
            }
        }
    }

    // MARK: Start on first strum

    /// Offered where the instrument is heard (not while the screen stands in for it).
    private var offersStrumStart: Bool { instrumentStep && !micOff && !LessonMicrophone.demo }

    /// "Start on first strum", over Start: on, the microphone waits before the take and its first stroke starts the
    /// count-in, so both hands stay on the instrument.
    private var strumStartToggle: some View {
        Button {
            Haptics.shared.selection()
            startOnStrum.toggle()
        } label: {
            Label("Start on first strum", systemImage: startOnStrum ? "mic.fill" : "mic")
                .font(Typeface.label(.footnote))
                .foregroundStyle(startOnStrum ? accent : Palette.inkSoft)
                .symbolEffect(.variableColor.iterative, isActive: armed && !reduceMotion)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(minHeight: Metrics.minTarget)
                .background(Capsule().fill(startOnStrum ? accent.opacity(0.12) : Palette.stageRaised))
                .overlay(Capsule().strokeBorder(startOnStrum ? accent.opacity(0.5) : Palette.controlLine, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(startOnStrum ? .isSelected : [])
        .accessibilityIdentifier("lesson.strumStart")
    }

    /// Before a take, with "Start on first strum" on: nothing is sounding the strings from the speaker (no "Show me").
    private var armable: Bool {
        startOnStrum && offersStrumStart && phase == .ready && !showMe && LessonMicrophone.granted
    }

    /// Opens the microphone for the first stroke; it starts the take.
    private func arm() {
        guard armable, !armed else { return }
        armed = true
        armedAt = CACurrentMediaTime()
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in strumToStart(at: time) })
        store.startLessonListening(owner: owner, lowHz: 60, highHz: 1400, analyzer: analyzer) { _, _ in }
    }

    private func disarm() {
        guard armed else { return }
        armed = false
        if phase == .ready { store.stopLessonListening(owner: owner) }
    }

    /// A stroke while armed starts the take (not the microphone's own start-up, in its first moments).
    private func strumToStart(at time: CFTimeInterval) {
        guard armed, phase == .ready, time - armedAt > 0.4 else { return }
        armed = false
        Haptics.shared.selection()
        start()
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

    /// Under the strings: the switch between them and the model, and "Show me"; under them, what to watch.
    private var showMeRow: some View {
        VStack(spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { showMeControls }
                VStack(spacing: 6) { showMeControls }
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
            ShowMeCaption(text: ShowMe.caption(pattern: pattern, beatsPerBar: beatsPerBar), accent: accent,
                          live: showMe && showMeReady)
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: showMe)
    }

    @ViewBuilder private var showMeControls: some View {
        ShowMeToggle(on: showMeBinding, accent: accent, label: "Neck view")
        ShowMeButton(accent: accent, loading: showMe && !showMeReady, showing: showMe && showMeReady, invite: !showMe) {
            setShowMe(true)
        }
    }

    /// "Show me" puts the instrument in place of the strings (the strokes sound once it is there) or, already there,
    /// sounds them again; the switch brings the strings back. `tapped` is false when the step brings the model in by
    /// itself (the first time).
    private func setShowMe(_ on: Bool, tapped: Bool = true) {
        guard on else {
            guard showMe else { return }
            stopShowMeSound()
            withMotion(Motion.reveal, reduceMotion: reduceMotion) {
                showMe = false
                showMeReady = false
            }
            arm()
            return
        }
        guard phase == .ready else { return }
        if tapped { Haptics.shared.selection() }
        // The demonstration sounds from the speaker: the first-strum microphone waits until it's over.
        disarm()
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
        remember()
        soundShowMe(lead: ShowMe.lead)
    }

    /// This pattern's key in the course's memory of demonstrations.
    private var demoKey: String { ShowMeKey.strum(pattern: pattern, beatsPerBar: beatsPerBar) }

    /// The first time this pattern appears in the course (the strum explanation before it usually shows it first),
    /// its demonstration plays by itself, where "Show me" is offered, and not with Reduce Motion or VoiceOver.
    private var playsFirstOnModel: Bool {
        guard !reduceMotion, !voiceOver, let course, showMeModel != nil,
              stageRoom >= Self.smallestStage + Self.showMeRowHeight else { return false }
        return ShowMe.firstTime(demoKey, course: course, settings: store.settings)
    }

    /// The course has now shown this pattern on the model: from here on it waits for "Show me".
    private func remember() {
        guard let course, !store.settings.hasShownDemo(demoKey, in: course.id) else { return }
        let key = demoKey
        store.updateSettings { $0.markDemoShown(key, in: course.id) }
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

    /// What the demonstration strums, lowest string first: the step's chord (a progression's first), or on a tap step
    /// the open strings, as its title says ("Strum the open strings").
    private var showMeNotes: [Int] {
        guard let course else { return [] }
        let open = ChordStep.openStrings(course)
        switch mode {
        case .tap: return ShowMe.strumNotes(nil, open: open, fretKind: nil)
        case .strum(let spec): return ShowMe.strumNotes(spec, open: open, fretKind: course.fretKind)
        case .progression(let chords, _): return ShowMe.strumNotes(chords.first, open: open, fretKind: course.fretKind)
        }
    }

    // MARK: The take

    private func start() {
        guard !audioStart.isPending else { return }
        ownsClick = true
        audioStart.begin(store.audio.setMetronome(bpm: Int(bpm), beats: beatsPerBar, subdivision: 1, accents: true)) {
            startReady()
        }
    }

    private func startReady() {
        // The demonstration never sounds over the take: it stops before the click and the microphone start.
        closeShowMe()
        armed = false
        take = freshTake()
        score = 0
        startTime = CACurrentMediaTime()
        withAnimation(Motion.quick) { phase = .playing; counting = true }
        // A fresh count from its first click (`setMetronome` restarts any click already running, the Metronome
        // tool's included), so the count-in, the band and the judging all count from a click that starts now.
        // From the bar after the count-in, on headphones; the speaker keeps the click alone, so its drum hits are never
        // heard as strokes.
        store.audio.playBand(band, firstBar: 1, onSpeaker: false)
        // Only the instrument counts on an instrument step; the screen is the fallback without a microphone. Each
        // stroke's reading (its chord, attack and ring) follows a moment after its timing (`read`).
        if instrumentStep && !micOff {
            let analyzer = LessonAnalyzer(chords: false, strokes: readsStrokes, onOnset: { time in register(time) },
                                          onStrokeRead: { time, stroke in read(stroke, at: time) })
            store.startLessonListening(owner: owner, lowHz: 60, highHz: 1400, analyzer: analyzer) { _, _ in }
        }
    }

    private func tapped() {
        guard tapping else { return }
        pulse += 1
        Haptics.shared.selection()
        register(CACurrentMediaTime())
    }

    /// A stroke heard (or a tap) at host time `time`: scored by its timing when it lands in a beat's window.
    private func register(_ time: CFTimeInterval) {
        guard phase == .playing else { return }
        if take.heard(at: time - startTime, stamp: time) != nil { SoundFX.shared.play(.hit) }
    }

    /// A stroke's reading, about a quarter second after it (`StrokeChords`), graded for what it rang (`StrumTake`).
    private func read(_ stroke: StrokeChords.Stroke, at time: CFTimeInterval) {
        guard phase == .playing else { return }
        take.read(stroke, stamp: time)
    }

    private func expire(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // Beats are where the click is heard (after engine start and output latency), not where Start was tapped.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        let t = now - startTime
        if counting && t >= countIn { withAnimation(Motion.quick) { counting = false } }
        if LessonMicrophone.demo, instrumentStep, !micOff { demoStrokes(at: t) }
        take.expire(at: t)
        // With strokes read, the last one's reading comes in a quarter second after it.
        if take.isOver(at: t, reading: readsStrokes) { finish() }
    }

    /// On the demo pitch (debug builds' captures, which have no strokes to hear) the player strums on time, a little
    /// human, and one stroke in eight lands a touch late, so the beat row shows its call.
    private func demoStrokes(at t: Double) {
        let jitter = [0.012, -0.018, 0.026, -0.008]
        for (i, time) in expected.enumerated() where take.grades[i] == nil {
            let off = i % 8 == 1 ? 0.12 : jitter[i % jitter.count]
            if t >= time + off { register(startTime + time + off) }
        }
    }

    private func finish() {
        score = take.finish()
        // The coach reads chord-change timing from strummed takes heard on the instrument.
        if instrumentStep && !micOff {
            switch mode {
            case .strum(let chord?):
                CoachTakes.shared.record(CoachTake.strummed(chords: [chord], bars: [bars], pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm,
                                                            offsets: take.offsets, strays: take.strays, wrongChords: take.wrongChords))
            case .progression(let chords, let lengths):
                CoachTakes.shared.record(CoachTake.strummed(chords: chords, bars: lengths, pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm,
                                                            offsets: take.offsets, strays: take.strays, wrongChords: take.wrongChords))
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
        announceTake()
    }

    /// VoiceOver hears how the take went as it ends, not only when it finds the badge: the score, then the one thing
    /// to work on first.
    private func announceTake() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        var words = String(localized: "\(Int((score * 100).rounded()))% on the beat")
        if let note = takeNote { words += ". " + note }
        UIAccessibility.post(notification: .announcement, argument: words)
    }

    /// The app went to the background mid-take: the click, the band and the microphone stop and the take is
    /// dropped (nothing graded, nothing for the coach). The step is back at Start.
    private func abandonTake() {
        let starting = audioStart.isPending
        audioStart.cancel()
        guard phase == .playing || starting else { return }
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        store.stopLessonListening(owner: owner)
        take = freshTake()
        score = 0
        counting = false
        phase = .ready
        appeared = CACurrentMediaTime()
        // `stopBand` forgets the prepared arrangement; the next take wants it again.
        store.audio.prepareBand(band)
    }
}

/// A rhythm step's title, in one place for the lesson player (`RhythmStep`) and the iPad outline (`LessonInspector`),
/// so the two never name a step differently. On an instrument course a tap step is strummed on the open strings: its
/// title says so, and it doesn't read like the strum step with the chord that usually follows it.
enum RhythmStepTitle {
    enum Kind { case tap, strum, progression }

    /// `onInstrument`: the step is played on the course instrument (strum and progression steps, and tap steps on an
    /// instrument course); `strums`: on a strummed instrument; `tapping`: the screen stands in for it (no microphone).
    static func of(_ kind: Kind, onInstrument: Bool, strums: Bool, tapping: Bool) -> LocalizedStringKey {
        if tapping || !onInstrument { return "Tap on the dots" }
        guard strums else { return "Play on the dots" }
        if case .tap = kind { return "Strum the open strings" }
        return "Strum on the arrows"
    }

    /// The title of `step` on `course` when it is a rhythm step (nil otherwise), as the lesson player sets it up;
    /// `micOff` when the screen will stand in for the instrument.
    static func of(_ step: LessonStep, course: LearnCourse, micOff: Bool) -> LocalizedStringKey? {
        switch step {
        case .strum:
            return of(.strum, onInstrument: true, strums: true, tapping: micOff)
        case .progression:
            return of(.progression, onInstrument: true, strums: true, tapping: micOff)
        case .tapRhythm:
            let onInstrument = course.fretKind != nil
            return of(.tap, onInstrument: onInstrument, strums: course.strums, tapping: !onInstrument || micOff)
        default:
            return nil
        }
    }
}
