import QuartzCore
import SwiftUI
import TimbreCore

/// Play-along: notes glide toward the "now" line on their string (or pitch lane); the microphone
/// judges each one for timing and intonation. Count-in, a tempo ladder (75 → 90 → 100 → 110 %), combo, results.
struct AlongStep: View {
    let notes: [TimedNote]
    let bpm: Double
    let beatsPerBar: Int
    let title: LearnText?
    let course: LearnCourse
    let accent: Color
    /// How each note went in the take that counts (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    /// Finished below the lesson tempo: the lesson's stars are capped.
    var onStarCap: (Int) -> Void = { _ in }
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var owner = UUID()
    @State private var phase = Phase.ready
    @State private var ladder: TempoLadder
    /// The last take was good enough to move the ladder up a rung.
    @State private var steppedUp = false
    @State private var judge: PlayAlongJudge
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    /// The grades of the take that counts (the ladder's outcome).
    @State private var countedGrades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var hitTimes: [Int: CFTimeInterval] = [:]
    /// Seconds early (negative) or late of each note played, for the "Early" and "Late" pops.
    @State private var offsets: [Int: Double] = [:]
    @State private var startTime: CFTimeInterval = 0
    @State private var trail: [(CFTimeInterval, Double)] = []
    @State private var lastLevel = -120.0
    @State private var lastOnset: CFTimeInterval = 0
    @State private var calibrating = false
    /// A bar practised on its own from the results (tap a missed note on the timing strip): its notes over and over
    /// at a slower tempo. Nil plays the whole tune.
    @State private var loop: BarLoop?
    /// The tempo of the last whole-tune take, so a loop from its results runs slower than that take did.
    @State private var takeTempo: Double?
    /// When the multiplier last stepped up (×2, ×3, ×4): the board's new colour rolls up it from the hit line.
    @State private var tierUp: CFTimeInterval?
    /// The whole-tune results a loop was started from: Done goes back to them (Try again or Continue from there).
    @State private var parked: ParkedTake?
    /// A take started the click: closing or leaving the app stops it (never the Metronome tool's own click).
    @State private var ownsClick = false
    /// The tune's words, line by line (a song's verse or chorus; empty for a tune without words).
    private let lyrics: LyricSheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    enum Phase { case ready, playing, done }

    /// A finished whole-tune take, kept while a bar loops.
    private struct ParkedTake {
        let judge: PlayAlongJudge
        let grades: [Int: PlayAlongJudge.Grade]
        let hitTimes: [Int: CFTimeInterval]
        let offsets: [Int: Double]
    }

    /// One bar of the tune on repeat: its notes `passes` times back to back (each held no longer than the bar), at `bpm`.
    struct BarLoop: Equatable {
        /// The bar, 0 first.
        let bar: Int
        let notes: [TimedNote]
        let bpm: Double
        static let passes = 4
        /// Three quarters of the take's tempo.
        static let rate = 0.75

        /// The notes of `tune` that start in `bar`, moved to start at beat 0 and repeated `passes` times.
        static func looping(_ tune: [TimedNote], bar: Int, beatsPerBar: Int) -> [TimedNote] {
            let meter = Double(max(1, beatsPerBar))
            let from = Double(bar) * meter, to = from + meter
            let inBar = tune.filter { $0.beat >= from - 0.001 && $0.beat < to - 0.001 }
            return (0..<passes).flatMap { pass -> [TimedNote] in
                inBar.map { note in
                    TimedNote(midi: note.midi, beat: note.beat - from + Double(pass) * meter, beats: min(note.beats, to - note.beat), at: note.at)
                }
            }
        }
    }

    init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, title: LearnText?, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, onStarCap: @escaping (Int) -> Void = { _ in },
         done: @escaping (Double?) -> Void) {
        let sorted = notes.sorted { $0.beat < $1.beat }
        self.notes = sorted
        self.lyrics = LyricSheet(notes: sorted)
        self.bpm = bpm; self.beatsPerBar = beatsPerBar; self.title = title; self.course = course; self.accent = accent
        self.onItem = onItem; self.onStarCap = onStarCap; self.done = done
        // Starts at the lesson tempo.
        _ladder = State(initialValue: TempoLadder(bpm: bpm))
        _judge = State(initialValue: PlayAlongJudge(notes: notes, bpm: bpm, anyOctave: course.anyOctave))
    }

    /// What a take plays: the whole tune, or the bar on repeat.
    private var take: [TimedNote] { loop?.notes ?? notes }
    private var tempo: Double { loop?.bpm ?? ladder.tempo }
    private var spb: Double { 60 / tempo }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    /// Drums and a bass on the key of the tune (no band bass when the player is the bass).
    private var band: BandArrangement {
        .melody(take, bpm: tempo, beatsPerBar: beatsPerBar, reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }
    /// The bar (0 first) note `index` of the tune starts in.
    private func bar(of index: Int) -> Int {
        guard notes.indices.contains(index) else { return 0 }
        return Int((notes[index].beat / Double(max(1, beatsPerBar))).rounded(.down))
    }
    /// The results' timing strip loops a missed note's bar; not while a bar is already looping.
    private var loopAction: ((Int) -> Void)? {
        guard loop == nil else { return nil }
        return { index in enterLoop(noteIndex: index) }
    }
    /// Slower rungs in amber, the lesson tempo and up in the course colour.
    private func rungTint(_ rung: Int) -> Color { rung >= TempoLadder.lessonRung ? accent : Palette.amber }
    /// The combo multiplier (×1…×4) the HUD shows and the runway's hit line glows with.
    private var multiplier: Int { ComboBadge.multiplier(judge.combo) }
    /// Seconds of music the runway shows ahead of the hit line: two bars or more, so three or four notes are
    /// always on the board whatever the tempo.
    private var lookahead: Double { HighwayRunway.lookahead(secondsPerBeat: spb, beatsPerBar: beatsPerBar) }

    var body: some View {
        VStack(spacing: 14) {
            header
            TimelineView(.animation(paused: phase != .playing)) { timeline in
                let now = CACurrentMediaTime()
                // Seconds since beat 0 on the heard clock (negative during the count-in).
                let clock = now - startTime - countIn
                ZStack {
                    // Hits burst on the hit line inside the drawing (bigger and white-gold when perfect).
                    runway(elapsed: runwayElapsed(now: now), now: phase == .done ? now + 10 : now)
                    if phase == .playing, clock < 0 {
                        Text("\(Int(-clock / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                            .shadow(color: accent.opacity(0.6), radius: 20)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Play-along, \(take.count) notes"))
            // Shrinks on short phones rather than pushing the header off the top; the controls keep one height
            // through ready, playing and done, so the stage never changes size when a take starts or ends.
            .frame(minHeight: 220, maxHeight: fretted ? 420 : 300)
            // The combo and multiplier over the stage's top corners while a take plays.
            .overlay(alignment: .top) {
                if phase == .playing {
                    HighwayHUD(combo: judge.combo, calm: reduceMotion)
                        .transition(.opacity)
                }
            }
            // The results take the stage's place, so nothing above or below moves when they arrive.
            .overlay { if phase == .done { resultsPanel } }
            .background(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).fill(Palette.stageDeep))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous))
            .padding(.horizontal, 12)
            .layoutPriority(1)
            if !lyrics.isEmpty { lyricRow }
            // Its whole height, always: offered only its 44 pt minimum beside the stage (which takes the rest first),
            // the row overflowed that frame by half its height each way, and "Next" sat over the stage's bottom edge
            // (review 14). The stage gives up the room instead.
            upcoming
                .frame(minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(phase == .done ? 0 : 1)
                .accessibilityHidden(phase == .done)
            Spacer(minLength: 0)
            MicrophoneHint()
            controls
        }
        .onAppear { store.audio.prepareBand(band) }
        .onChange(of: ladder.rung) { _, _ in store.audio.prepareBand(band) }
        .onChange(of: loop) { _, _ in store.audio.prepareBand(band) }
        // Leaving the app mid-take drops the take: no click left sounding in a pocket, nothing half-heard graded.
        .onChange(of: scenePhase) { _, now in if now == .background { abandonTake() } }
        .onDisappear {
            if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
            ownsClick = false
            store.audio.stopBand(); store.stopLessonListening(owner: owner)
            #if DEBUG
            store.demoNoteDue = nil
            #endif
        }
        .sheet(isPresented: $calibrating) {
            LatencyCalibrationSheet(accent: accent).environmentObject(store)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            // The step's title, as on every step: two lines at most here, so the stage keeps its room.
            StepTitle(Text(title?.localized ?? String(localized: "Play along")))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                // The combo lives in the stage's HUD; the row keeps its height so the stage never shifts.
                .frame(minHeight: 36)
            HStack(spacing: 8) {
                Text("\(Int(tempo)) BPM · \(take.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if let loop { loopBadge(loop) } else { tempoBadge }
                Spacer(minLength: 8)
                CalibrateButton(audio: store.audio, accent: accent) { calibrating = true }
                    .disabled(phase == .playing)
                    .opacity(phase == .playing ? 0.4 : 1)
                BandControls(audio: store.audio, accent: accent)
            }
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 8)
        // Always its full height: the title never shrinks to make room below.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The tempo level at a glance: 100 % in the course colour, slower in amber.
    private var tempoBadge: some View {
        Text("\(ladder.percent)%")
            .font(Typeface.number(12))
            .foregroundStyle(rungTint(ladder.rung))
            .contentTransition(.numericText(value: Double(ladder.percent)))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(rungTint(ladder.rung).opacity(0.14)))
            .animation(Motion.pluck, value: ladder.rung)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Tempo"))
            .accessibilityValue(Text("\(ladder.percent)%"))
    }

    /// In the tempo badge's place while a bar loops: the bar, in amber with the repeat glyph; tapping it (or its ×)
    /// ends the loop, back to the whole tune.
    private func loopBadge(_ loop: BarLoop) -> some View {
        Button { exitLoop() } label: {
            HStack(spacing: 5) {
                Image(systemName: "repeat").font(.system(size: 11, weight: .bold))
                Text("Bar \(loop.bar + 1)").font(Typeface.label(12))
                Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).opacity(0.7)
            }
            .foregroundStyle(Palette.amber)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Palette.amber.opacity(0.14)))
            // A full-size target: the row is as tall as its round buttons anyway.
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(phase == .playing)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityLabel(Text("Bar \(loop.bar + 1)"))
        .accessibilityHint(Text("Done"))
        .accessibilityIdentifier("along.loop.badge")
    }

    /// In the ladder's place while a bar loops: which bar, how fast and for how long, and (before a take) Done, back
    /// to the whole tune.
    private func loopPanel(_ loop: BarLoop) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "repeat")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.amber)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Palette.amber.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bar \(loop.bar + 1)").font(Typeface.label(16)).foregroundStyle(Palette.ink)
                Text("\(Int(loop.bpm)) BPM · \(BarLoop.passes) bars").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if phase == .ready {
                Button { exitLoop() } label: {
                    Text("Done").font(Typeface.label(14)).foregroundStyle(accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(accent.opacity(0.12)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("along.loop.exit")
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement(children: .contain)
    }

    /// The fretboard runway on fretted courses (its lanes the lowest string first, as the chord pictures), pitch lanes
    /// otherwise.
    @ViewBuilder private func runway(elapsed: Double, now: CFTimeInterval) -> some View {
        if fretted {
            HighwayRunway(notes: take, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: now,
                          strings: course.stringCount, edges: StringEdges.of(course), beatsPerBar: beatsPerBar,
                          heat: multiplier, calm: reduceMotion, offsets: offsets, tierUp: tierUp)
        } else {
            HighwayCanvas(notes: take, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: now,
                          lanes: 0, accent: accent, trail: trail, startTime: startTime + countIn, calm: reduceMotion, offsets: offsets)
        }
    }

    /// Where the runway stands, in seconds since beat 0. Before the start the first notes already wait on the near
    /// part of the board (three or four in view); as the count-in begins they glide back to where it puts them, a
    /// bar from the line, rather than jumping there (with Reduce Motion they do jump).
    private func runwayElapsed(now: CFTimeInterval) -> Double {
        let preview = -0.2 * lookahead
        let actual = now - startTime - countIn
        switch phase {
        case .ready: return preview
        case .done: return actual
        case .playing:
            let t = max(0, now - startTime) / 0.5
            guard !reduceMotion, t < 1 else { return actual }
            let eased = 1 - pow(1 - t, 3)
            return preview + (actual - preview) * eased
        }
    }

    /// The tune's words under the stage, karaoke style, following the take's clock (the first line waits before a
    /// take). Hidden, but keeping its height, while a bar loops and on the results, so the stage never moves.
    private var lyricRow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: phase != .playing)) { _ in
            HighwayLyrics(sheet: lyrics, beat: lyricBeat(CACurrentMediaTime()), accent: accent)
        }
        .padding(.horizontal, Metrics.gutter)
        .opacity(loop == nil && phase != .done ? 1 : 0)
        .accessibilityHidden(loop != nil || phase == .done)
    }

    /// The take's position in beats from its first bar, for the words; nil before a take starts.
    private func lyricBeat(_ now: CFTimeInterval) -> Double? {
        guard phase == .playing, loop == nil else { return nil }
        return (now - startTime - countIn) / spb
    }

    /// The next note by name and where to play it (with the finger to use, on the same white tag the gems wear),
    /// then the notes after it on a rail.
    @ViewBuilder private var upcoming: some View {
        let take = self.take
        let index = min(judge.nextIndex, take.count - 1)
        if take.indices.contains(index) {
            let note = take[index]
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Next").font(Typeface.label(13)).foregroundStyle(Palette.inkFaint)
                    Text(NoteName.name(note.midi)).font(Typeface.display(22)).foregroundStyle(Palette.ink)
                    if fretted, let at = note.at {
                        Text(at.fret == 0 ? LocalizedStringKey("String \(at.string), open") : LocalizedStringKey("String \(at.string), fret \(at.fret)"))
                            .font(Typeface.label(14)).foregroundStyle(nextTint(note))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(nextTint(note).opacity(0.12)))
                        if at.fret > 0, let finger = at.finger, finger > 0 { fingerTag(finger, tint: nextTint(note)) }
                    }
                    Spacer()
                }
                .contentTransition(.numericText())
                UpNextRail(notes: take, from: index + 1, fretted: fretted, strings: course.stringCount, accent: accent)
            }
            .padding(.horizontal, Metrics.gutter)
            .animation(reduceMotion ? nil : Motion.quick, value: index)
        }
    }

    /// The finger to fret the next note with: a white tag with its number, as pinned to the gem's corner.
    private func fingerTag(_ finger: Int, tint: Color) -> some View {
        Text(verbatim: "\(finger)")
            .font(Typeface.number(14, relativeTo: .caption))
            .foregroundStyle(tint.mix(with: .black, by: 0.62))
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.white.opacity(0.95)))
            .overlay(Circle().strokeBorder(tint.mix(with: .black, by: 0.3), lineWidth: 1.5))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Finger \(finger)"))
    }

    /// The next note's string colour on the runway (the course colour on pitch lanes).
    private func nextTint(_ note: TimedNote) -> Color {
        guard fretted, let at = note.at else { return accent }
        return HighwayRunway.color(string: at.string, of: course.stringCount)
    }

    /// The take's results on an opaque panel over the stage, in the same frame the notes ran in.
    private var resultsPanel: some View {
        ZStack {
            Rectangle().fill(Palette.stageDeep)
            RadialGradient(colors: [scoreTint.opacity(0.14), .clear], center: .center, startRadius: 4, endRadius: 220)
            summary.padding(12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    /// The take's score as shown, in percent.
    private var percent: Int { Int((judge.accuracy * 100).rounded()) }
    /// Mint from 90 %, amber below and never red: a weak take is a warm-up to run again, not a failure.
    private var scoreTint: Color { percent >= LessonRun.greatTake ? Palette.mint : Palette.amber }
    /// Under half the take landed: the card leads with another go (Try again takes the filled button).
    private var retryFirst: Bool { percent < LessonRun.warmTake }

    private var verdict: LocalizedStringKey {
        if percent >= LessonRun.greatTake { return "Great work" }
        return retryFirst ? "Just warming up" : "Keep going"
    }

    /// The full card when the stage is tall enough; on short phones the verdict and timing strip give way.
    private var summary: some View {
        ViewThatFits(in: .vertical) {
            summaryCard(compact: false)
            summaryCard(compact: true)
        }
    }

    private func summaryCard(compact: Bool) -> some View {
        let counts = Dictionary(grouping: grades.values, by: { $0 }).mapValues(\.count)
        return VStack(spacing: compact ? 8 : 10) {
            if !compact {
                Text(verdict).font(Typeface.label(14)).foregroundStyle(scoreTint)
            }
            Text("\(percent)%").font(Typeface.note(compact ? 46 : 56)).foregroundStyle(scoreTint)
                .minimumScaleFactor(0.7)
            if steppedUp { tempoUp }
            // In the grades' colours, as on the ribbon and the timing strip.
            HStack(spacing: 18) {
                stat("Perfect", counts[.perfect] ?? 0, TakeRibbon.color(.perfect, accent: accent))
                stat("Good", counts[.good] ?? 0, TakeRibbon.color(.good, accent: accent))
                stat("Early/late", counts[.ok] ?? 0, TakeRibbon.color(.ok, accent: accent))
                stat("Missed", counts[.miss] ?? 0, TakeRibbon.color(.miss, accent: accent))
            }
            if !compact {
                // A dot per note, early above the line and late below; tapping a missed note loops its bar, slower.
                HighwayTimingStrip(count: take.count, judgments: judge.judgments, accent: accent, calm: reduceMotion,
                                   onLoop: loopAction, bar: { bar(of: $0) })
            }
            Text(timingNote).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            if timingIsOff {
                // Consistently early or late usually means the headphones or speaker lag: measure it.
                Button { calibrating = true } label: { Label("Calibrate timing", systemImage: "metronome") }
                    .font(Typeface.label(14)).foregroundStyle(accent)
                    .accessibilityIdentifier("along.calibrate.hint")
            } else if judge.bestCombo >= 2 {
                Text("Best combo \(judge.bestCombo)").font(.footnote).foregroundStyle(Palette.inkSoft)
            }
            if percent >= LessonRun.greatTake && loop == nil { takeShare.padding(.top, 2) }
            if loop == nil && judge.accuracy < 0.8 && ladder.rung > 0 {
                Button { ladder.select(0); reset() } label: { Label("Try it at \(Int(ladder.tempo(at: 0))) BPM", systemImage: "tortoise.fill") }
                    .font(Typeface.label(14)).foregroundStyle(accent).padding(.top, 2)
                    .accessibilityIdentifier("along.slower")
            }
        }
    }

    /// The ladder moved up after a take of 90 % or better.
    private var tempoUp: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.right")
            Text("Tempo up")
            Text("\(ladder.percent)%")
        }
        .font(Typeface.label(13))
        .foregroundStyle(rungTint(ladder.rung))
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(rungTint(ladder.rung).opacity(0.14)))
        .transition(.scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    /// A take of 90 % or more: its poster, a tap from the share sheet (three stars at the lesson tempo, else two).
    private var takeShare: some View {
        let full = (steppedUp ? ladder.rung - 1 : ladder.rung) >= TempoLadder.lessonRung
        return SharePill(preview: "Great work", tint: accent) {
            LessonShareCard(course: course.title.localized, title: title?.localized ?? String(localized: "Play along"), headline: "Great work",
                            stars: full ? 3 : TempoLadder.slowStarCap, accuracy: percent, accent: accent, song: false,
                            streak: store.streak.current)
        }
        .accessibilityIdentifier("along.share")
    }

    /// The take's offsets lean one way by 90 ms or more on average.
    private var timingIsOff: Bool {
        let offsets = judge.judgments.compactMap(\.offset)
        guard offsets.count >= 3 else { return false }
        return abs(offsets.reduce(0, +) / Double(offsets.count)) >= 0.09
    }

    /// Where the timing went: early or late on average, in milliseconds.
    private var timingNote: LocalizedStringKey {
        let offsets = judge.judgments.compactMap(\.offset)
        guard !offsets.isEmpty else { return "Play each note as it reaches the line" }
        let mean = offsets.reduce(0, +) / Double(offsets.count)
        let ms = Int((abs(mean) * 1000).rounded())
        if ms < 35 { return "Right on the beat" }
        return mean > 0 ? "About \(ms) ms late on average" : "About \(ms) ms early on average"
    }

    private func stat(_ label: LocalizedStringKey, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Typeface.number(20)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    @ViewBuilder private var controls: some View {
        switch phase {
        case .ready:
            VStack(spacing: 12) {
                ladderOrLoop
                StepButton(title: "Start", accent: accent) { start() }
            }
        case .playing:
            VStack(spacing: 12) {
                // The take so far, in the ladder's place: the hidden ladder keeps its height, so nothing moves.
                ladderPicker
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay { TakeRibbon(count: take.count, grades: grades, current: judge.nextIndex, accent: accent) }
                StepButton(title: "Listening…", accent: accent, enabled: false) {}
            }
        case .done:
            VStack(spacing: 12) {
                ladderOrLoop
                HStack(spacing: 10) {
                    if loop != nil {
                        // The loop again until it's clean; then Done (back to the whole tune's results) comes first.
                        let clean = judge.accuracy >= TempoLadder.stepUpAccuracy
                        doneButton("Try again", primary: !clean) { reset() }
                            .accessibilityIdentifier("along.again")
                        doneButton("Done", primary: clean) { exitLoop() }
                            .accessibilityIdentifier("along.loop.exit")
                    } else {
                        // A weak take puts another go first: Try again takes the filled button, Continue steps back.
                        doneButton("Try again", primary: retryFirst) { reset() }
                            .accessibilityIdentifier("along.again")
                        doneButton("Continue", primary: !retryFirst) { complete() }
                            .accessibilityIdentifier("lesson.continue")
                    }
                }
                .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
            }
        }
    }

    /// The tempo ladder, or while a bar loops, the loop in its place (the hidden ladder keeps the height).
    @ViewBuilder private var ladderOrLoop: some View {
        if let loop {
            ladderPicker
                .hidden()
                .accessibilityHidden(true)
                .overlay { loopPanel(loop) }
        } else {
            ladderPicker
        }
    }

    /// The results' pair: the one to do next as the primary button in the course colour, the other as the secondary.
    @ViewBuilder private func doneButton(_ title: LocalizedStringKey, primary: Bool, action: @escaping () -> Void) -> some View {
        if primary {
            Button(action: action) { Text(title) }
                .buttonStyle(PrimaryButtonStyle(accent: accent))
        } else {
            Button(action: action) { Text(title) }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    /// The four tempo rungs, the current one filled; below the lesson tempo a note that full tempo earns three stars.
    private var ladderPicker: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(TempoLadder.rungs.indices, id: \.self) { rung in rungButton(rung) }
            }
            Label("Full tempo for 3 stars", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.amber)
                .opacity(ladder.isFullTempo ? 0 : 1)
                .accessibilityHidden(ladder.isFullTempo)
        }
        .padding(.horizontal, Metrics.gutter)
        .animation(Motion.pluck, value: ladder.rung)
    }

    private func rungButton(_ rung: Int) -> some View {
        let selected = ladder.rung == rung
        let tint = rungTint(rung)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button {
            guard ladder.rung != rung else { return }
            ladder.select(rung)
            steppedUp = false
            Haptics.shared.selection()
        } label: {
            VStack(spacing: 1) {
                Text("\(Int((TempoLadder.rungs[rung] * 100).rounded()))%").font(Typeface.label(15))
                Text(Int(ladder.tempo(at: rung)), format: .number).font(Typeface.number(11)).opacity(0.75)
            }
            .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(shape.fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(shape.strokeBorder(selected ? Color.clear : Palette.controlLine, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if rung == TempoLadder.lessonRung {
                    // The lesson's own tempo.
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(selected ? Palette.onAccent : Palette.amber).padding(6)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(phase == .playing)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("along.tempo.\(rung)")
    }

    // MARK: Flow

    /// A fresh judge for what the next take plays (the whole tune or the looped bar), nothing judged yet.
    private func clearTake() {
        judge = PlayAlongJudge(notes: take, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; offsets = [:]; trail = []
        steppedUp = false
        tierUp = nil
    }

    private func reset() {
        clearTake()
        phase = .ready
    }

    /// From the results: the bar holding missed note `noteIndex`, on repeat at three quarters of the take's tempo,
    /// ready to start (four times through after the count-in). Whole-tune takes keep the ladder and the outcome.
    private func enterLoop(noteIndex: Int) {
        let missedBar = bar(of: noteIndex)
        let looped = BarLoop.looping(notes, bar: missedBar, beatsPerBar: beatsPerBar)
        guard !looped.isEmpty else { return }
        // Never under the click's slowest tempo, so the click and the runway agree.
        let bpm = max(Double(MetronomePattern.tempoRange.lowerBound), ((takeTempo ?? ladder.tempo) * BarLoop.rate).rounded())
        if loop == nil { parked = ParkedTake(judge: judge, grades: grades, hitTimes: hitTimes, offsets: offsets) }
        Haptics.shared.selection()
        withAnimation(reduceMotion ? nil : Motion.settle) {
            loop = BarLoop(bar: missedBar, notes: looped, bpm: bpm)
            clearTake()
            phase = .ready
        }
    }

    /// Back to the whole tune: the results the loop was started from (to try the tune again or continue), or the
    /// ready state when there are none.
    private func exitLoop() {
        guard phase != .playing else { return }
        Haptics.shared.selection()
        withAnimation(reduceMotion ? nil : Motion.settle) {
            loop = nil
            if let parked {
                judge = parked.judge; grades = parked.grades; hitTimes = parked.hitTimes; offsets = parked.offsets
                trail = []; steppedUp = false; tierUp = nil
                phase = .done
            } else {
                clearTake()
                phase = .ready
            }
            parked = nil
        }
    }

    private func start() {
        clearTake()
        if loop == nil { takeTempo = tempo }
        startTime = CACurrentMediaTime()
        phase = .playing
        // A lesson's click always starts a fresh count (even over the Metronome tool's), so the count-in, runway and
        // judging start with the click they assume.
        store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)
        ownsClick = true
        // The band rides the metronome from the bar after the count-in (headphones only; else the click).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = take.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        #if DEBUG
        store.demoNoteDue = { judge.nextIndex < take.count && CACurrentMediaTime() - startTime - countIn >= judge.time(of: judge.nextIndex) - 0.02 }
        #endif
        // Re-attacks of a repeated note come from the onset detector (a jump in loudness as a fallback).
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in lastOnset = time })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            let now = CACurrentMediaTime()
            let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            let onset = (level - lastLevel > 6 && level > -50) || now - lastOnset < 0.12
            lastLevel = level
            if let heard, !fretted { trail.append((now, Double(heard.midi) + heard.cents / 100)); if trail.count > 240 { trail.removeFirst(60) } }
            var clock = now - startTime - countIn
            #if DEBUG
            clock = demoJudgedTime(clock, judge: judge, store: store, heard: heard != nil)
            #endif
            apply(judge.update(time: clock, midi: heard?.midi, cents: heard?.cents, onset: onset), now: now)
        }
    }

    private func tick(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // The first click is heard a little after the tap (engine and microphone starting, output
        // latency, far more on Bluetooth; the tap-along calibration when there is one): notes and
        // judging follow the heard clock, not the tap.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        apply(judge.update(time: now - startTime - countIn, midi: nil, cents: nil), now: now)
        if judge.isFinished || now - startTime - countIn > judge.duration + 1.2 { finish() }
    }

    private func apply(_ judgments: [PlayAlongJudge.Judgment], now: CFTimeInterval) {
        for j in judgments {
            grades[j.index] = j.grade
            hitTimes[j.index] = now
            if let offset = j.offset { offsets[j.index] = offset }
            if j.grade == .perfect { Haptics.shared.selection() }
        }
        // The multiplier steps up at 4, 8 and 16 in a row: a firmer tap with the badge's pulse, and the board's
        // colour rolls up to the next tier.
        if let last = judgments.last, last.grade == .perfect || last.grade == .good {
            switch judge.combo {
            case 4, 8, 16:
                Haptics.shared.beat(accent: true)
                tierUp = now
            default: break
            }
        }
        let take = self.take
        if !judgments.isEmpty, judge.nextIndex < take.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(take[judge.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if judge.isFinished { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        let accuracy = judge.accuracy
        var up = false
        // A looped bar is practice: the ladder and the lesson's outcome come from whole-tune takes only.
        if loop == nil {
            // The take that counts keeps its grades for the lesson's weak spots.
            if ladder.improvesOutcome(accuracy) { countedGrades = grades }
            up = ladder.record(accuracy: accuracy)
            // The coach reads timing from whole takes only.
            CoachTakes.shared.record(CoachTake(judge: judge, beatsPerBar: beatsPerBar, item: { course.practiceItem(for: $0) }))
        }
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        ownsClick = false
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        withAnimation(Motion.settle) { phase = .done; steppedUp = up }
        SoundFX.shared.play(accuracy >= 0.7 ? .star : .wrong)
        if up { Haptics.shared.lock() }
    }

    /// The app went to the background mid-take: the click, the band and the microphone stop and the take is dropped
    /// (nothing graded, nothing for the coach). The step is back at Start.
    private func abandonTake() {
        guard phase == .playing else { return }
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        reset()
        store.audio.prepareBand(band)
    }

    /// Continue: the best take at the lesson tempo or faster counts; only slower takes cap the lesson's stars.
    private func complete() {
        let outcome = ladder.outcome
        if let cap = outcome?.starCap { onStarCap(cap) }
        for (index, note) in notes.enumerated() {
            onItem(course.practiceItem(for: note), PlayAlongJudge.credit(countedGrades[index] ?? .miss))
        }
        done(outcome?.score ?? judge.accuracy)
    }
}

/// The header's timing button: opens the tap-along calibration. A dot asks for it on a wireless route that
/// has never been calibrated (Bluetooth lag is the usual reason good playing scores late). A compact `IconButton`:
/// a 34 pt disc in a 44 pt target that never overlaps its neighbour's.
struct CalibrateButton: View {
    @ObservedObject var audio: AudioService
    let accent: Color
    let action: () -> Void

    private var needsIt: Bool { audio.route == .bluetooth && AudioService.calibratedLatency(for: .bluetooth) == nil }

    var body: some View {
        IconButton(symbol: "metronome", size: .compact, tint: Palette.inkSoft, label: "Calibrate timing", action: action)
            .overlay(alignment: .topTrailing) {
                // On the disc's shoulder (the disc sits 5 pt inside the target).
                if needsIt {
                    Circle().fill(Palette.amber).frame(width: 8, height: 8).offset(x: -5, y: 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("along.calibrate")
    }
}

/// The band corner of a play-along header: the band switch and, on the speaker, a quiet note that the
/// band plays in headphones (out loud it would reach the microphone and blur what it hears, so the
/// speaker keeps the plain click).
struct BandControls: View {
    @ObservedObject var audio: AudioService
    let accent: Color
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            if bandOn && !audio.headphones { headphonesChip }
            toggle
        }
        .animation(reduceMotion ? nil : Motion.quick, value: bandOn)
        .animation(reduceMotion ? nil : Motion.quick, value: audio.headphones)
        .onAppear { audio.refreshRoute() }
    }

    /// Words when they fit, just the headphones glyph when they don't (narrow phones, large type).
    private var headphonesChip: some View {
        ViewThatFits(in: .horizontal) {
            chip(Label("Band with headphones", systemImage: "headphones"))
            chip(Label("Band with headphones", systemImage: "headphones").labelStyle(.iconOnly))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("along.band.headphones")
    }

    private func chip(_ content: some View) -> some View {
        content
            .font(Typeface.label(12))
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(minHeight: 26)
            .background(Capsule().fill(Palette.stageRaised))
            .overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
    }

    private var toggle: some View {
        Button {
            bandOn.toggle()
            Haptics.shared.selection()
            audio.refreshBand()
        } label: {
            // A 44 pt target with no negative padding, so it never overlaps the calibrate button beside it.
            toggleFace
                .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Backing band"))
        .accessibilityAddTraits(bandOn ? [.isToggle, .isSelected] : [.isToggle])
        .accessibilityIdentifier("along.band")
    }

    /// A note in a ring, as big as the compact icon buttons beside it: tinted when on, struck through when off; it
    /// hops when the band comes in.
    private var toggleFace: some View {
        ZStack {
            Circle().fill(bandOn ? accent.opacity(0.16) : Palette.surface)
            Circle().strokeBorder(bandOn ? accent.opacity(0.45) : Palette.hairline, lineWidth: 1)
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(bandOn ? accent : Palette.inkFaint)
                .symbolEffect(.bounce, value: reduceMotion ? false : audio.bandPlaying)
            if !bandOn {
                Capsule().fill(Palette.inkFaint).frame(width: 1.5, height: 24).rotationEffect(.degrees(-45))
            }
        }
        .frame(width: 34, height: 34)
    }
}

/// Pitch lanes (voice, ear and any-instrument courses): notes slide in from the right at the height of their
/// pitch to the now line, your pitch trails behind it, and each hit bursts on the line.
struct HighwayCanvas: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    /// Seconds since beat 0 (negative during the count-in).
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    /// String lanes for fretted courses; 0 draws pitch lanes.
    let lanes: Int
    let accent: Color
    let trail: [(CFTimeInterval, Double)]
    let startTime: CFTimeInterval
    /// Reduce Motion: a hit lights the line without bursts or sparks.
    var calm = false
    /// Seconds early (negative) or late of each note played, for the "Early" and "Late" pops.
    var offsets: [Int: Double] = [:]
    /// String lanes lie across the screen, so they follow the necks' string order (`ChordPicture`): string 1 on top
    /// in the Chart view, the thickest in Player view.
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    /// Lane numbers grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    var body: some View {
        let order = stringOrder
        let scale = typeScale
        Canvas { context, size in
            let hitX = size.width * 0.24
            let pps: CGFloat = 150
            let top: CGFloat = 34, bottom = size.height - 30
            var lowest = 60, highest = 72
            if let first = notes.first {
                lowest = first.midi; highest = first.midi
                for note in notes { lowest = min(lowest, note.midi); highest = max(highest, note.midi) }
            }
            let low = Double(lowest - 2), high = Double(highest + 2)
            func laneY(_ note: TimedNote) -> CGFloat {
                if lanes > 0, let at = note.at {
                    return top + (bottom - top) * CGFloat(order.row(ofString: at.string, count: lanes)) / CGFloat(max(1, lanes - 1))
                }
                return pitchY(Double(note.midi))
            }
            func pitchY(_ midi: Double) -> CGFloat { bottom - (bottom - top) * CGFloat((midi - low) / max(1, high - low)) }

            // Lanes.
            if lanes > 0 {
                for lane in 0..<lanes {
                    let y = top + (bottom - top) * CGFloat(lane) / CGFloat(max(1, lanes - 1))
                    let string = order.string(atRow: lane, count: lanes)
                    // Thicker toward the bass, whichever way up the strings lie.
                    let gauge = CGFloat(string - 1)
                    context.fill(Path(CGRect(x: 0, y: y - 0.6 - gauge * 0.15, width: size.width, height: 1.2 + gauge * 0.3)), with: .color(.white.opacity(0.13)))
                    context.draw(Text("\(string)").font(DiagramType.font(11, scale: scale)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: 10, y: y))
                }
            } else {
                for midi in stride(from: Int(low.rounded(.up)), through: Int(high), by: 1) where [0, 2, 4, 5, 7, 9, 11].contains(((midi % 12) + 12) % 12) {
                    let y = pitchY(Double(midi))
                    context.fill(Path(CGRect(x: 0, y: y - 0.5, width: size.width, height: 1)), with: .color(.white.opacity(midi % 12 == 0 ? 0.14 : 0.05)))
                }
            }
            // Beat lines scrolling with the music.
            let firstBeat = Int(floor((elapsed - Double(hitX / pps)) / secondsPerBeat))
            for beat in firstBeat...(firstBeat + Int(Double(size.width / pps) / secondsPerBeat) + 2) {
                let x = hitX + CGFloat((Double(beat) * secondsPerBeat - elapsed)) * pps
                context.fill(Path(CGRect(x: x - 0.5, y: top - 14, width: 1, height: bottom - top + 28)), with: .color(.white.opacity(beat % 4 == 0 ? 0.10 : 0.04)))
            }
            // Now line: a glow, the line, a bright core.
            let glow = Path(CGRect(x: hitX - 24, y: 0, width: 48, height: size.height))
            context.fill(glow, with: .linearGradient(Gradient(colors: [.clear, accent.opacity(0.22), .clear]), startPoint: CGPoint(x: hitX - 24, y: 0), endPoint: CGPoint(x: hitX + 24, y: 0)))
            context.fill(Path(roundedRect: CGRect(x: hitX - 2, y: 8, width: 4, height: size.height - 16), cornerRadius: 2), with: .color(accent))
            context.fill(Path(roundedRect: CGRect(x: hitX - 0.75, y: 10, width: 1.5, height: size.height - 20), cornerRadius: 0.75), with: .color(.white.opacity(0.7)))

            // Notes.
            for i in notes.indices {
                let note = notes[i]
                let start = note.beat * secondsPerBeat - elapsed
                let x0 = hitX + CGFloat(start) * pps
                let width = max(40, CGFloat(note.beats * secondsPerBeat) * pps - 6)
                guard x0 + width > -40, x0 < size.width + 40 else { continue }
                let y = laneY(note)
                let grade = grades[i]
                let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
                let hit = grade != nil && grade != .miss
                // A hit pops white for an instant; its burst takes over.
                if hit && (calm || age > 0.16) { continue }
                var rect = CGRect(x: x0, y: y - 17, width: width, height: 34)
                if hit { rect = rect.insetBy(dx: -CGFloat(age) * 50, dy: -CGFloat(age) * 30) }
                let shape = Path(roundedRect: rect, cornerRadius: 13)
                if grade == .miss {
                    let alpha = max(0.15, 0.7 - age)
                    context.stroke(shape, with: .color(Palette.danger.opacity(alpha)), lineWidth: 2)
                    context.draw(label(note, color: Palette.danger.opacity(alpha)), at: CGPoint(x: rect.minX + 20, y: y))
                } else if hit {
                    context.fill(shape, with: .color(Color.white.opacity(0.9 * (1 - age / 0.16))))
                } else {
                    context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 4), cornerRadius: 13), with: .color(accent.mix(with: .black, by: 0.5)))
                    let shade = Gradient(colors: [accent.mix(with: .white, by: 0.3), accent, accent.mix(with: .black, by: 0.12)])
                    context.fill(shape, with: .linearGradient(shade, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                    let gloss = CGRect(x: rect.minX + 6, y: rect.minY + 3, width: max(0, rect.width - 12), height: 11)
                    context.fill(Path(roundedRect: gloss, cornerRadius: 5), with: .linearGradient(Gradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)]), startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
                    context.stroke(shape, with: .color(.white.opacity(0.3)), lineWidth: 1)
                    context.draw(label(note, color: Palette.onAccent), at: CGPoint(x: rect.minX + 20, y: y))
                }
            }

            // Your pitch, as a glowing trail to the left of the now line (pitch lanes only).
            if lanes == 0, trail.count > 1 {
                var path = Path()
                var started = false
                for (time, midi) in trail {
                    let x = hitX + CGFloat(time - now) * pps
                    guard x > -10 else { continue }
                    let point = CGPoint(x: x, y: pitchY(midi))
                    if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                }
                context.stroke(path, with: .color(Palette.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let last = trail.last, now - last.0 < 0.25 {
                    let p = CGPoint(x: hitX, y: pitchY(last.1))
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(Palette.ink))
                }
            }

            // Hits burst on the now line, perfect ones bigger and white-gold.
            var light = context
            light.blendMode = .plusLighter
            for i in notes.indices {
                guard let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0, age < HitBurst.lifetime else { continue }
                let center = CGPoint(x: hitX, y: laneY(notes[i]))
                let tint: Color = grade == .perfect ? HighwayRunway.perfectGold : accent
                if calm {
                    HitBurst.glow(&light, at: center, tint: tint, age: age)
                } else {
                    HitBurst.draw(&light, at: center, tint: tint, perfect: grade == .perfect, age: age, seed: i, upward: false, scale: 0.85)
                }
            }

            // The verdict pops over the line where each note was judged.
            let bounds = CGRect(x: 8, y: 0, width: size.width - 16, height: size.height)
            for i in notes.indices {
                guard let grade = grades[i], let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0, age < HighwayPop.lifetime else { continue }
                let base = CGPoint(x: hitX, y: max(22, laneY(notes[i]) - 30))
                HighwayPop.draw(&context, grade: grade, offset: offsets[i], lane: accent, at: base, age: age, bounds: bounds, calm: calm)
            }
        }
    }

    private func label(_ note: TimedNote, color: Color) -> Text {
        let name = lanes > 0 ? (note.at.map { "\($0.fret)" } ?? NoteName.pitchClass(note.midi)) : NoteName.pitchClass(note.midi)
        return Text(verbatim: name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(color)
    }
}

/// A note landing on the hit line: a flash, a ring opening out and a spray of sparks; a perfect note's is
/// bigger and white-gold. Drawn additively, from nothing but the time since the hit.
enum HitBurst {
    static let lifetime = 0.6

    static func draw(_ context: inout GraphicsContext, at center: CGPoint, tint: Color, perfect: Bool, age: Double, seed: Int,
                     upward: Bool, scale: CGFloat = 1) {
        guard age >= 0, age < lifetime else { return }
        let p = age / lifetime
        if age < 0.3 {
            let f = 1 - age / 0.3
            let radius = (perfect ? 78 : 46) * scale * CGFloat(0.55 + 0.45 * min(1, age / 0.08))
            let flash = Gradient(colors: [Color.white.opacity((perfect ? 0.95 : 0.7) * f), tint.opacity((perfect ? 0.6 : 0.45) * f), tint.opacity(0)])
            context.fill(circle(center, radius), with: .radialGradient(flash, center: center, startRadius: 0, endRadius: radius))
        }
        if age < 0.45 {
            let q = age / 0.45
            let eased = 1 - (1 - q) * (1 - q)
            let radius = (18 + CGFloat(eased) * (perfect ? 90 : 56)) * scale
            context.stroke(circle(center, radius), with: .color(tint.opacity(0.85 * (1 - q))), lineWidth: (perfect ? 3.5 : 2.5) * CGFloat(1 - q) + 0.5)
        }
        // Sparks: a fan rising off the line, or all the way round.
        let count = perfect ? 14 : 9
        for k in 0..<count {
            let n1 = CanvasNoise.value(seed * 31 + k), n2 = CanvasNoise.value(seed * 17 + k * 7 + 3)
            let angle = upward ? -Double.pi / 2 + (n1 - 0.5) * 2.6 : n1 * 2 * Double.pi
            let speed = (perfect ? 190.0 : 140.0) * (0.6 + 0.6 * n2)
            let x = center.x + CGFloat(cos(angle) * speed * age) * scale
            let y = center.y + CGFloat(sin(angle) * speed * age + 240 * age * age) * scale
            let r = CGFloat(2.8 * (1 - p)) * scale * (k % 3 == 0 ? 1.3 : 1)
            let spark: Color = k % 3 == 0 ? .white : tint
            context.fill(circle(CGPoint(x: x, y: y), r), with: .color(spark.opacity(1 - p)))
        }
    }

    /// Reduce Motion: the light alone, fading where the note landed.
    static func glow(_ context: inout GraphicsContext, at center: CGPoint, tint: Color, age: Double) {
        guard age >= 0, age < 0.35 else { return }
        let f = 1 - age / 0.35
        let radius: CGFloat = 40
        context.fill(circle(center, radius), with: .radialGradient(Gradient(colors: [tint.opacity(0.6 * f), tint.opacity(0)]), center: center, startRadius: 0, endRadius: radius))
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Fretted play-along as a runway down a fretboard: a lane per string, the lowest string on the left in both views
/// (`StringOrder.upright`), as the chord chart and the player's-view neck (`PlayerNeck`) stand their strings, so a
/// shape learned on either comes down the runway the same way round. The lanes lie
/// over dark rosewood whose fret wires and inlays scroll toward you out of the fog, two bars or more of them in
/// view. Each lane ends in a target ring carrying its string's number, the outer two named underneath
/// ("Thinnest", "Thickest"). Notes ride their lane as big glossy gems in the string's colour, the fret over the
/// note name and the finger to use on a white tag at the corner, long ones trailing a sustain tail; a hit bursts on
/// the hit line, and a perfect one lights its whole lane white-gold and sends a burst racing both ways along the
/// line. Its verdict pops over the line ("Perfect", "Good", "Early", "Late", "Missed"). The board warms through
/// colour tiers with the combo multiplier (the HUD's flame at ×2, amber at ×3, white-gold at ×4), each new tier
/// rolling up the board from the hit line.
struct HighwayRunway: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    let strings: Int
    /// Names the outer lanes under their numbers ("Thinnest (1)", "Thickest (6)"), whichever side they are on.
    var edges: StringEdges?
    /// Beats in a bar: the bar lines are the heavier fret wires, with an inlay in each bar.
    var beatsPerBar = 4
    /// The combo multiplier (1…4): the hit line and the board's binding warm up as it climbs.
    var heat = 1
    /// Reduce Motion: a hit lights its target without bursts, beams or sparks.
    var calm = false
    /// No longer read: the lanes stand upright, so they always run from the lowest string on the left
    /// (`StringOrder.upright`) whichever view is chosen. Kept so existing callers still compile.
    var order: StringOrder = .tab
    /// Seconds early (negative) or late of each note played, for the "Early" and "Late" pops.
    var offsets: [Int: Double] = [:]
    /// When the multiplier last stepped up (on the `now` clock): the new tier's colour rolls up the board.
    var tierUp: CFTimeInterval?
    /// The string numbers and edge names grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    /// Seconds of music in view ahead of the hit line: two bars (eight beats at least, twelve at most), never
    /// under 2.8 s on a fast tune, so three or four notes are on the board whatever the tempo.
    static func lookahead(secondsPerBeat: Double, beatsPerBar: Int) -> Double {
        let beats = min(12, max(8, 2 * max(1, beatsPerBar)))
        return max(2.8, Double(beats) * max(0.05, secondsPerBeat))
    }
    private var lookahead: Double { Self.lookahead(secondsPerBeat: secondsPerBeat, beatsPerBar: beatsPerBar) }

    /// The white-gold of a perfect note.
    static let perfectGold = Color(hex: 0xFFE7A3)
    /// Depth of the board's near edge, past the hit line (the bottom of the stage).
    private static let near = -0.15
    /// Notes this long (in beats) and longer trail a sustain tail.
    private static let sustainBeats = 1.5
    /// A gem's width as a share of its lane, and its height at the hit line (points).
    private static let gemWidth: CGFloat = 0.96
    private static let gemHeight: CGFloat = 56
    /// Gems this far scaled down (toward the horizon) drop the note name under the fret, and the finger tag.
    private static let nameScale: CGFloat = 0.5
    /// How long a perfect note's lane stays lit, and its burst runs along the hit line.
    private static let perfectFlash = 0.45

    /// Lowest string warm, highest cool.
    private static let palette: [Color] = [Palette.violet, Palette.sky, Palette.mint, Color(hex: 0xFFE066), Palette.amber, Palette.coral]
    static func color(string: Int, of count: Int) -> Color {
        let index = count <= 1 ? 0 : Int((Double(string - 1) / Double(count - 1) * Double(palette.count - 1)).rounded())
        return palette[min(palette.count - 1, max(0, index))]
    }

    // The fixed shades, made once rather than on every frame.
    private static let sky = Gradient(colors: [Color(hex: 0x14161B), Palette.stageDeep])
    private static let haze = Gradient(colors: [Color(hex: 0x2B3442).opacity(0.6), Color(hex: 0x2B3442).opacity(0)])
    private static let wood = Gradient(colors: [Color(hex: 0x16100D), Color(hex: 0x3B2A1F)])
    private static let roll = Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.4)])
    private static let fog = Gradient(colors: [Color(hex: 0x0C0E12).opacity(0.95), Color(hex: 0x0C0E12).opacity(0.45), Color(hex: 0x0C0E12).opacity(0)])
    private static let vignette = Gradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0)])
    private static let wireMetal = Color(hex: 0xC9CED6)
    private static let bone = Color(hex: 0xEDE3CF)
    private static let hitLine = Color(hex: 0xFFF4DE)

    var body: some View {
        let scale = typeScale
        Canvas { context, size in draw(&context, size: size, scale: scale) }
            .accessibilityHidden(true)
    }

    /// The runway's perspective: depth 0 is the hit line, 1 the horizon, negative past the line toward you.
    private struct Lanes {
        let width: CGFloat
        let hitY: CGFloat
        let horizonY: CGFloat
        let gap: CGFloat
        let strings: Int
        let order: StringOrder

        init(size: CGSize, strings: Int, order: StringOrder) {
            width = size.width
            hitY = size.height - 58
            horizonY = 16
            self.strings = max(1, strings)
            self.order = order
            gap = (size.width - 36) / CGFloat(max(1, strings))
        }

        func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + 0.55) * 1.55) }
        func y(_ d: Double) -> CGFloat { hitY - (hitY - horizonY) * depth(d) }
        func scale(_ d: Double) -> CGFloat { 1 - 0.8 * depth(max(-0.3, d)) }
        /// Lane centre of a string: the lane its row takes, counted from the left.
        func x(_ string: Int, _ d: Double) -> CGFloat { laneX(order.row(ofString: string, count: strings), d) }
        func laneX(_ row: Int, _ d: Double) -> CGFloat {
            let lane = CGFloat(row) - CGFloat(strings - 1) / 2
            return width / 2 + lane * gap * scale(d)
        }
        /// The strings in the outer lanes.
        var leftString: Int { order.string(atRow: 0, count: strings) }
        var rightString: Int { order.string(atRow: strings - 1, count: strings) }
        func left(_ d: Double) -> CGFloat { laneX(0, d) - gap * 0.5 * scale(d) }
        func right(_ d: Double) -> CGFloat { laneX(strings - 1, d) + gap * 0.5 * scale(d) }
        /// A point across the board at a depth: 0 its left edge, 1 its right.
        func across(_ u: CGFloat, _ d: Double) -> CGPoint { CGPoint(x: left(d) + (right(d) - left(d)) * u, y: y(d)) }
        /// How clearly something at depth `d` shows through the fog toward the horizon.
        func clarity(_ d: Double) -> Double { d < 0.55 ? 1 : max(0.15, 1 - (d - 0.55) / 0.45 * 0.85) }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let g = Lanes(size: size, strings: strings, order: StringOrder.upright)
        drawBoard(&context, g, size: size)
        drawTierWave(&context, g)
        drawFrets(&context, g)
        drawLanes(&context, g)
        drawFog(&context, g, size: size)
        drawTargets(&context, g, scale: scale)
        // Far notes first, so near ones draw on top. Colours and labels are made once a frame, not once a gem.
        let shades = (1...max(1, strings)).map { Shade(Self.color(string: $0, of: strings)) }
        var labels = GemLabels()
        for i in notes.indices.reversed() { drawNote(&context, g, index: i, shades: shades, labels: &labels) }
        drawHits(&context, g)
        drawVignette(&context, size: size)
        drawPops(&context, g, size: size)
        drawLabels(&context, g, scale: scale)
    }

    // MARK: Board

    /// Sky with a glow at the vanishing point, and the fretboard: rosewood with its grain running toward you
    /// (so it never needs to scroll), rolled darker at the edges, and bone binding that warms with the multiplier.
    private func drawBoard(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Self.sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let vanish = CGPoint(x: size.width / 2, y: g.horizonY)
        let haze = size.width * 0.6
        context.fill(circle(vanish, haze), with: .radialGradient(Self.haze, center: vanish, startRadius: 0, endRadius: haze))
        var board = Path()
        board.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        board.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        board.closeSubpath()
        context.fill(board, with: .linearGradient(Self.wood, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)))
        var grain = context
        grain.clip(to: board)
        for i in 0..<22 {
            let u = CGFloat((Double(i) + 0.15 + 0.7 * CanvasNoise.value(i + 300)) / 22)
            let mid = g.across(u, 0.3)
            var line = Path()
            line.move(to: g.across(u, 1))
            line.addQuadCurve(to: g.across(u, Self.near), control: CGPoint(x: mid.x + CGFloat(CanvasNoise.value(i + 340) - 0.5) * 10, y: mid.y))
            let tone: Color = i % 3 == 0 ? Color.white.opacity(0.03) : Color.black.opacity(0.18 + 0.15 * CanvasNoise.value(i + 380))
            grain.stroke(line, with: .color(tone), lineWidth: 0.7 + 1.6 * CGFloat(CanvasNoise.value(i + 420)))
        }
        grain.fill(board, with: .linearGradient(Self.roll, startPoint: CGPoint(x: g.left(0), y: 0), endPoint: CGPoint(x: g.right(0), y: 0)))
        if let tier = tierTint {
            // The combo's tier warms the wood from the hit line up, and the glow at the vanishing point with it.
            var glow = context
            glow.blendMode = .plusLighter
            glow.fill(board, with: .linearGradient(Gradient(colors: [tier.opacity(0), tier.opacity(tierStrength)]),
                                                   startPoint: CGPoint(x: 0, y: g.y(0.75)), endPoint: CGPoint(x: 0, y: g.y(Self.near))))
            glow.fill(circle(vanish, haze * 0.7), with: .radialGradient(Gradient(colors: [tier.opacity(tierStrength * 0.9), tier.opacity(0)]),
                                                                       center: vanish, startRadius: 0, endRadius: haze * 0.7))
        }
        var binding = Path()
        binding.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        binding.move(to: CGPoint(x: g.right(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        let edge = heatTint
        if heat >= 2 { context.stroke(binding, with: .color(edge.opacity(0.08 * Double(heat))), lineWidth: 7) }
        context.stroke(binding, with: .linearGradient(Gradient(colors: [edge.opacity(0.05), edge.opacity(heat >= 2 ? 0.65 : 0.35)]),
                                                      startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)), lineWidth: 1.6)
    }

    /// Bone at ×1–2, amber at ×3, white-gold at ×4.
    private var heatTint: Color {
        switch heat {
        case 4...: return Self.perfectGold
        case 3: return Palette.amber
        default: return Self.bone
        }
    }

    /// The board's colour tier: none at ×1, then the HUD dial's colour (flame ×2, amber ×3, white-gold ×4).
    private var tierTint: Color? { heat >= 2 ? ComboBadge.tint(heat) : nil }
    /// How strongly the tier tints the board, stronger each step.
    private var tierStrength: Double {
        switch heat {
        case 4...: return 0.2
        case 3: return 0.15
        default: return 0.1
        }
    }

    /// A tier just reached: a band of its colour rolls from the hit line up to the horizon, and the binding flares.
    private func drawTierWave(_ context: inout GraphicsContext, _ g: Lanes) {
        guard !calm, let tierUp, let tier = tierTint else { return }
        let age = now - tierUp
        let life = 0.8
        guard age >= 0, age < life else { return }
        let p = age / life
        let eased = 1 - pow(1 - p, 2)
        let front = Self.near + (1 - Self.near) * eased
        let back = max(Self.near, front - 0.18)
        var band = Path()
        band.move(to: CGPoint(x: g.left(back), y: g.y(back)))
        band.addLine(to: CGPoint(x: g.right(back), y: g.y(back)))
        band.addLine(to: CGPoint(x: g.right(front), y: g.y(front)))
        band.addLine(to: CGPoint(x: g.left(front), y: g.y(front)))
        band.closeSubpath()
        var light = context
        light.blendMode = .plusLighter
        light.fill(band, with: .linearGradient(Gradient(colors: [tier.opacity(0), tier.opacity(0.5 * (1 - p))]),
                                               startPoint: CGPoint(x: 0, y: g.y(back)), endPoint: CGPoint(x: 0, y: g.y(front))))
        var sides = Path()
        sides.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        sides.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        sides.move(to: CGPoint(x: g.right(1), y: g.horizonY))
        sides.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        light.stroke(sides, with: .color(tier.opacity(0.7 * (1 - p))), lineWidth: 4)
    }

    /// Fret wires scrolling toward you, one per beat with the bar lines heavier, and a pearl inlay mid-bar.
    private func drawFrets(_ context: inout GraphicsContext, _ g: Lanes) {
        let spb = max(0.05, secondsPerBeat)
        let meter = max(1, beatsPerBar)
        let ahead = lookahead
        let firstBeat = Int((elapsed / spb).rounded(.down))
        let lastBeat = firstBeat + Int(ahead / spb) + 1
        for beat in firstBeat...lastBeat {
            let d = (Double(beat) * spb - elapsed) / ahead
            guard d > -0.1, d < 1 else { continue }
            let bar = ((beat % meter) + meter) % meter == 0
            let sc = g.scale(d), clear = g.clarity(d)
            var wire = Path()
            wire.move(to: CGPoint(x: g.left(d), y: g.y(d)))
            wire.addLine(to: CGPoint(x: g.right(d), y: g.y(d)))
            let w: CGFloat = (bar ? 3.2 : 1.6) * sc
            context.stroke(wire.offsetBy(dx: 0, dy: w * 0.8), with: .color(.black.opacity(0.45 * clear)), lineWidth: w)
            context.stroke(wire, with: .color(Self.wireMetal.opacity((bar ? 0.42 : 0.2) * clear)), lineWidth: w)
            context.stroke(wire.offsetBy(dx: 0, dy: -w * 0.25), with: .color(.white.opacity((bar ? 0.35 : 0.15) * clear)), lineWidth: max(0.5, w * 0.35))
        }
        let barSeconds = Double(meter) * spb
        let firstBar = Int((elapsed / barSeconds).rounded(.down)) - 1
        let lastBar = firstBar + Int(ahead / barSeconds) + 2
        for bar in firstBar...lastBar {
            let d = ((Double(bar) + 0.5) * barSeconds - elapsed) / ahead
            guard d > -0.1, d < 1 else { continue }
            let sc = g.scale(d), clear = g.clarity(d)
            let c = CGPoint(x: g.width / 2, y: g.y(d))
            let rx = 7 * sc, ry = 4.2 * sc
            let pearl = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            let shine = Gradient(colors: [Color.white.opacity(0.42 * clear), Color(hex: 0xB9D3DC).opacity(0.16 * clear)])
            context.fill(pearl, with: .radialGradient(shine, center: CGPoint(x: c.x - rx * 0.3, y: c.y - ry * 0.3), startRadius: 0, endRadius: rx))
        }
    }

    /// The strings, a lane each: a coloured glow under a metal core, brighter toward you, flaring for a moment
    /// when one of its notes is hit; a perfect note lights the whole lane white-gold, horizon to hit line. The low
    /// strings are the thicker ones.
    private func drawLanes(_ context: inout GraphicsContext, _ g: Lanes) {
        var light = context
        light.blendMode = .plusLighter
        for s in 1...g.strings {
            let tint = Self.color(string: s, of: strings)
            let gauge = g.strings > 1 ? CGFloat(s - 1) / CGFloat(g.strings - 1) : 0.5
            let half = 0.8 + gauge * 1.1
            let state = target(string: s)
            let lit = state.flash
            let from = CGPoint(x: 0, y: g.horizonY), to = CGPoint(x: 0, y: g.hitY)
            context.fill(lane(g, string: s, half: half * 5 + CGFloat(lit) * 10),
                         with: .linearGradient(Gradient(colors: [tint.opacity(0.02), tint.opacity(0.16 + 0.3 * lit)]), startPoint: from, endPoint: to))
            context.fill(lane(g, string: s, half: half),
                         with: .linearGradient(Gradient(colors: [tint.opacity(0.15), tint.mix(with: .white, by: 0.35).opacity(0.9)]), startPoint: from, endPoint: to))
            let flash = state.perfect
            guard flash > 0, !calm else { continue }
            // Perfect: the lane flashes white-gold its whole length, brightest at the line, and its core burns white.
            light.fill(lane(g, string: s, half: g.gap * 0.42),
                       with: .linearGradient(Gradient(colors: [Self.perfectGold.opacity(0.08 * flash), Self.perfectGold.opacity(0.42 * flash)]),
                                             startPoint: from, endPoint: to))
            light.fill(lane(g, string: s, half: half + 1.5), with: .color(Color.white.opacity(0.75 * flash)))
        }
    }

    /// A lane's strip from the horizon to the near edge, `half` either side of its centre at the hit line.
    private func lane(_ g: Lanes, string s: Int, half: CGFloat) -> Path {
        let far = half * g.scale(1), close = half * g.scale(Self.near)
        var p = Path()
        p.move(to: CGPoint(x: g.x(s, 1) - far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, 1) + far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) + close, y: g.y(Self.near)))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) - close, y: g.y(Self.near)))
        p.closeSubpath()
        return p
    }

    /// Depth fog over the far end of the board: notes rise out of it.
    private func drawFog(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        let end = g.y(0.5)
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: end)),
                     with: .linearGradient(Self.fog, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: end)))
    }

    // MARK: Hit line

    private struct TargetState {
        /// 1 → 0 over the moment after one of the string's notes is hit.
        var flash = 0.0
        /// 1 → 0 over the moment after one of its notes is hit perfectly: the lane's white-gold flash.
        var perfect = 0.0
        /// One of its notes was just missed.
        var missed = false
        /// 0 → 1 as its next note closes in on the line.
        var approach = 0.0
    }

    private func target(string s: Int) -> TargetState {
        var state = TargetState()
        for i in notes.indices where notes[i].at?.string == s {
            if let grade = grades[i] {
                guard let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0 else { continue }
                if grade == .perfect, age < Self.perfectFlash {
                    let f = 1 - age / Self.perfectFlash
                    state.perfect = max(state.perfect, f * f)
                }
                guard age < 0.35 else { continue }
                if grade == .miss { state.missed = true } else { state.flash = max(state.flash, 1 - age / 0.35) }
            } else {
                // Fills over the last 0.45 s before its note, whatever the tempo.
                let due = notes[i].beat * secondsPerBeat - elapsed
                if due > -0.15, due < 0.45 { state.approach = max(state.approach, 1 - max(0, due) / 0.45) }
            }
        }
        return state
    }

    /// A target ring's radius: sized to the gems, within its lane.
    private static func targetRadius(_ g: Lanes) -> CGFloat { min(21, g.gap * 0.38) }

    /// The hit line across the board and a target ring per string, its number inside: recessed, filling as a note
    /// comes in, flashing in the string's colour on a hit (coral on a miss).
    private func drawTargets(_ context: inout GraphicsContext, _ g: Lanes, scale: CGFloat) {
        let from = g.left(0) - 6, to = g.right(0) + 6
        let line = heat >= 3 ? heatTint : Self.hitLine
        let band = CGRect(x: from, y: g.hitY - 13, width: to - from, height: 26)
        context.fill(Path(roundedRect: band, cornerRadius: 13),
                     with: .linearGradient(Gradient(colors: [line.opacity(0), line.opacity(0.1 + 0.04 * Double(heat)), line.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        context.fill(Path(roundedRect: CGRect(x: from, y: g.hitY - 1.5, width: to - from, height: 3), cornerRadius: 1.5), with: .color(line.opacity(0.75)))
        let radius = Self.targetRadius(g)
        for s in 1...g.strings {
            let state = target(string: s)
            let tint = state.missed ? Palette.danger : Self.color(string: s, of: strings)
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let r = radius * (1 + (calm ? 0 : CGFloat(state.flash) * 0.2))
            context.fill(circle(center, radius + 3), with: .color(.black.opacity(0.5)))
            let fill = Gradient(colors: [tint.opacity(0.08 + 0.35 * state.approach + 0.5 * state.flash), tint.opacity(0.04 + 0.2 * state.flash)])
            context.fill(circle(center, r), with: .radialGradient(fill, center: center, startRadius: 0, endRadius: r))
            context.stroke(circle(center, r), with: .color(tint.opacity(0.75 + 0.25 * max(state.approach, state.flash))), lineWidth: 2.5)
            var shine = Path()
            shine.addRelativeArc(center: center, radius: max(1, r - 3.5), startAngle: .degrees(205), delta: .degrees(130))
            context.stroke(shine, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            // The string's number, in its colour, brightening as its note closes in.
            let lift = max(state.approach, state.flash)
            let number = Text(verbatim: "\(s)").font(DiagramType.font(13, weight: .heavy, scale: scale))
                .foregroundStyle(tint.mix(with: .white, by: 0.55 + 0.35 * lift).opacity(0.75 + 0.25 * lift))
            context.draw(number, at: center)
        }
    }

    // MARK: Notes

    /// A string's colours for its gems and tails, mixed once a frame rather than once a gem.
    private struct Shade {
        let tint: Color
        /// The edge a gem stands on, the bevel inside its rim, its face's light and shadow; the same for a gem
        /// flashing white on a hit.
        let edge, bevel, light, dark: Color
        let hitFace, hitBevel, hitLight, hitDark: Color
        /// The finger tag's rim and number, and a sustain tail's edge.
        let tagRim, tagInk, tailEdge: Color

        init(_ tint: Color) {
            self.tint = tint
            edge = tint.mix(with: .black, by: 0.5)
            bevel = tint.mix(with: .black, by: 0.3)
            light = tint.mix(with: .white, by: 0.35)
            dark = tint.mix(with: .black, by: 0.18)
            let hit = tint.mix(with: .white, by: 0.7)
            hitFace = hit
            hitBevel = hit.mix(with: .black, by: 0.3)
            hitLight = hit.mix(with: .white, by: 0.35)
            hitDark = hit.mix(with: .black, by: 0.18)
            tagRim = bevel
            tagInk = tint.mix(with: .black, by: 0.62)
            tailEdge = tint.mix(with: .black, by: 0.45)
        }
    }

    /// The gems' labels (fret numbers, note names, finger numbers), each laid out once a frame at a fixed size and
    /// scaled with its gem, instead of a new font size for every gem on every frame.
    private struct GemLabels {
        private var frets: [Int: GraphicsContext.ResolvedText] = [:]
        private var names: [Int: GraphicsContext.ResolvedText] = [:]
        private var fingers: [Int: GraphicsContext.ResolvedText] = [:]

        /// The sizes the labels are laid out at: their size on a gem at the hit line.
        static let fretSize: CGFloat = 25
        static let nameSize: CGFloat = 13
        static let fingerSize: CGFloat = 14

        mutating func fret(_ fret: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = frets[fret] { return known }
            let text = context.resolve(Text(verbatim: "\(fret)").font(.system(size: Self.fretSize, weight: .heavy, design: .rounded)))
            frets[fret] = text
            return text
        }

        mutating func name(_ midi: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            let pitchClass = ((midi % 12) + 12) % 12
            if let known = names[pitchClass] { return known }
            let text = context.resolve(Text(verbatim: NoteName.pitchClass(midi)).font(.system(size: Self.nameSize, weight: .bold, design: .rounded)))
            names[pitchClass] = text
            return text
        }

        mutating func finger(_ finger: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = fingers[finger] { return known }
            let text = context.resolve(Text(verbatim: "\(finger)").font(.system(size: Self.fingerSize, weight: .heavy, design: .rounded)))
            fingers[finger] = text
            return text
        }
    }

    /// A resolved label in `color`, centred on `point` and drawn at `scale` of its laid-out size (on a copy of the
    /// context, which draws to the same canvas).
    private func drawLabel(_ context: GraphicsContext, _ text: GraphicsContext.ResolvedText, color: Color, at point: CGPoint, scale: CGFloat) {
        var label = text
        label.shading = .color(color)
        var placed = context
        placed.translateBy(x: point.x, y: point.y)
        placed.scaleBy(x: scale, y: scale)
        placed.draw(label, at: .zero, anchor: .center)
    }

    private func drawNote(_ context: inout GraphicsContext, _ g: Lanes, index i: Int, shades: [Shade], labels: inout GemLabels) {
        let note = notes[i]
        guard let at = note.at else { return }
        let ahead = lookahead
        let start = (note.beat * secondsPerBeat - elapsed) / ahead
        let end = ((note.beat + note.beats) * secondsPerBeat - elapsed) / ahead
        guard start < 1.05, end > -0.25 else { return }
        let grade = grades[i]
        let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
        let shade = shades.indices.contains(at.string - 1) ? shades[at.string - 1] : Shade(Self.color(string: at.string, of: strings))
        if note.beats >= Self.sustainBeats {
            // It stops a little short of where the note ends, so a run of long notes still reads as separate notes.
            let gap = 0.2 * secondsPerBeat / ahead
            drawTail(&context, g, string: at.string, start: start, end: end - gap, shade: shade, grade: grade)
        }
        drawGem(&context, g, string: at.string, fret: at.fret, finger: at.fret > 0 ? at.finger : nil, midi: note.midi, start: start,
                shade: shade, grade: grade, age: age, labels: &labels)
    }

    /// A long note's sustain tail up its lane to where the note ends: a ribbon in the string's colour, edged darker
    /// so it reads apart from the string under it, round at its end, with a bright core. While it rings after a hit,
    /// light runs down the core and it burns down where it meets the line; once missed it greys.
    private func drawTail(_ context: inout GraphicsContext, _ g: Lanes, string s: Int, start: Double, end: Double, shade: Shade, grade: PlayAlongJudge.Grade?) {
        let held = grade != nil && grade != .miss
        let a = held ? max(start, 0) : max(start, Self.near)
        let b = min(end, 1)
        guard b > a else { return }
        let missed = grade == .miss
        let color = missed ? Palette.inkFaint : shade.tint
        let edge = missed ? Self.missedTailEdge : shade.tailEdge
        let strength = missed ? 0.3 : held ? 1.0 : 0.8
        let far = g.clarity(b)
        let half = g.gap * 0.16
        let ya = g.y(a), yb = g.y(b)
        let tail = ribbon(g, string: s, from: a, to: b, half: half)
        let fill = Gradient(colors: [color.opacity(0.9 * strength), color.opacity(0.3 * strength * far)])
        context.fill(tail, with: .linearGradient(fill, startPoint: CGPoint(x: 0, y: ya), endPoint: CGPoint(x: 0, y: yb)))
        context.stroke(tail, with: .color(edge.opacity(0.8 * strength)), lineWidth: 1)
        let cap = CGPoint(x: g.x(s, b), y: yb)
        context.fill(circle(cap, half * g.scale(b)), with: .color(color.opacity(0.3 * strength * far)))
        var core = Path()
        core.move(to: CGPoint(x: g.x(s, a), y: ya))
        core.addLine(to: cap)
        context.stroke(core, with: .color(.white.opacity((held ? 0.85 : 0.45) * strength)), lineWidth: 2.2 * g.scale(a))
        guard held, !calm else { return }
        // Light running down the core toward the line while it rings.
        let phase = CGFloat((now * 70).truncatingRemainder(dividingBy: 18))
        context.stroke(core, with: .color(.white.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 4.5 * g.scale(a), lineCap: .round, dash: [4, 14], dashPhase: phase))
        if start <= 0, end > 0 {
            // Ringing: it burns down where it meets the line.
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let flicker = 16 + 5 * CGFloat(sin(now * 38 + Double(s)))
            let flare = Gradient(colors: [Color.white.opacity(0.85), shade.tint.opacity(0.5), shade.tint.opacity(0)])
            context.fill(circle(center, flicker), with: .radialGradient(flare, center: center, startRadius: 0, endRadius: flicker))
        }
    }

    /// A missed tail's edge (the faint ink, darkened).
    private static let missedTailEdge = Palette.inkFaint.mix(with: .black, by: 0.45)

    /// A strip up a string's lane from depth `a` to `b`, `half` either side of its centre at the hit line.
    private func ribbon(_ g: Lanes, string s: Int, from a: Double, to b: Double, half: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: g.x(s, a) - half * g.scale(a), y: g.y(a)))
        p.addLine(to: CGPoint(x: g.x(s, b) - half * g.scale(b), y: g.y(b)))
        p.addLine(to: CGPoint(x: g.x(s, b) + half * g.scale(b), y: g.y(b)))
        p.addLine(to: CGPoint(x: g.x(s, a) + half * g.scale(a), y: g.y(a)))
        p.closeSubpath()
        return p
    }

    /// A note gem: a big glossy tile in its string's colour (nearly its whole lane), the fret over the note's
    /// name and the finger to fret it with on a white tag at its top corner, standing on its own darker edge with
    /// its shadow on the wood, and lighting the board as it nears the line. A hit pops white for an instant (its
    /// burst takes over); a miss runs on past, hollow and coral.
    private func drawGem(_ context: inout GraphicsContext, _ g: Lanes, string s: Int, fret: Int, finger: Int?, midi: Int, start: Double,
                         shade: Shade, grade: PlayAlongJudge.Grade?, age: Double, labels: inout GemLabels) {
        let hit = grade != nil && grade != .miss
        if hit && (calm || age > 0.16) { return }
        let d = hit ? 0 : start
        let sc = g.scale(d)
        var w = g.gap * Self.gemWidth * sc
        var h = min(Self.gemHeight, g.gap * 1.02) * sc
        var alpha = (start > 0.85 ? max(0, (1.05 - start) / 0.2) : 1) * g.clarity(d)
        if hit {
            let pop = 1 + CGFloat(age / 0.16) * 0.5
            w *= pop; h *= pop
            alpha = 1 - age / 0.16
        }
        if grade == .miss { alpha = max(0.2, 0.8 - age) }
        guard alpha > 0.01 else { return }
        let center = CGPoint(x: g.x(s, d), y: g.y(d))
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        let corner = min(w, h) * 0.3
        let face = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
        let fretScale = max(9 / GemLabels.fretSize, sc)
        if grade == .miss {
            context.fill(face, with: .color(Palette.danger.opacity(0.12 * alpha)))
            context.stroke(face, with: .color(Palette.danger.opacity(0.8 * alpha)), lineWidth: 2)
            drawLabel(context, labels.fret(fret, in: context), color: Palette.danger.opacity(alpha), at: center,
                      scale: max(9 / GemLabels.fretSize, 23 * sc / GemLabels.fretSize))
            return
        }
        if grade == nil, d < 0.35 {
            // Its light on the board as it closes in.
            let reach = w * 1.15
            let glow = Gradient(colors: [shade.tint.opacity(0.4 * (1 - d / 0.35) * alpha), shade.tint.opacity(0)])
            context.fill(circle(center, reach), with: .radialGradient(glow, center: center, startRadius: 0, endRadius: reach))
        }
        // Its shadow on the wood, then the edge it stands on.
        let shadow = rect.offsetBy(dx: 0, dy: 8 * sc).insetBy(dx: w * 0.05, dy: h * 0.05)
        context.fill(Path(roundedRect: shadow, cornerRadius: corner, style: .continuous), with: .color(.black.opacity(0.4 * alpha)))
        context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 5 * sc), cornerRadius: corner, style: .continuous),
                     with: .color(shade.edge.opacity(alpha)))
        let faceTint = hit ? shade.hitFace : shade.tint
        let faceLight = hit ? shade.hitLight : shade.light
        let faceDark = hit ? shade.hitDark : shade.dark
        let faceBevel = hit ? shade.hitBevel : shade.bevel
        let gradient = Gradient(colors: [faceLight.opacity(alpha), faceTint.opacity(alpha), faceDark.opacity(alpha)])
        context.fill(face, with: .linearGradient(gradient, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        // A bevel just inside the rim, the gloss over the top, a glint in its corner.
        let bevel = rect.insetBy(dx: 2.5 * sc, dy: 2.5 * sc)
        context.stroke(Path(roundedRect: bevel, cornerRadius: max(0, corner - 2.5 * sc), style: .continuous),
                       with: .color(faceBevel.opacity(0.45 * alpha)), lineWidth: max(0.5, 1.2 * sc))
        let gloss = CGRect(x: rect.minX + 3 * sc, y: rect.minY + 2 * sc, width: max(0, rect.width - 6 * sc), height: rect.height * 0.4)
        context.fill(Path(roundedRect: gloss, cornerRadius: corner * 0.7, style: .continuous),
                     with: .linearGradient(Gradient(colors: [Color.white.opacity(0.5 * alpha), Color.white.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
        context.stroke(face, with: .color(.white.opacity(0.4 * alpha)), lineWidth: 1)
        let glint = CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.11, width: w * 0.16, height: h * 0.09)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.65 * alpha)))
        guard !hit else { return }
        // The fret, and under it the note's name once the gem is near enough to read it.
        let ink = Palette.onAccent
        if sc >= Self.nameScale {
            drawLabel(context, labels.fret(fret, in: context), color: ink.opacity(alpha), at: CGPoint(x: center.x, y: center.y - h * 0.12),
                      scale: fretScale)
            drawLabel(context, labels.name(midi, in: context), color: ink.opacity(0.7 * alpha), at: CGPoint(x: center.x, y: center.y + h * 0.29),
                      scale: max(8 / GemLabels.nameSize, sc))
            if grade == nil, let finger, finger > 0 {
                drawFingerTag(&context, finger, at: CGPoint(x: rect.maxX - 3 * sc, y: rect.minY + 3 * sc), scale: sc, shade: shade,
                              alpha: alpha, labels: &labels)
            }
        } else {
            drawLabel(context, labels.fret(fret, in: context), color: ink.opacity(alpha), at: CGPoint(x: center.x, y: center.y + 0.5 * sc),
                      scale: fretScale)
        }
    }

    /// The finger to fret a note with (1 index … 4 little) on a white tag pinned to the gem's top corner, as the
    /// "Next" row under the stage shows it.
    private func drawFingerTag(_ context: inout GraphicsContext, _ finger: Int, at center: CGPoint, scale sc: CGFloat, shade: Shade, alpha: Double,
                               labels: inout GemLabels) {
        let r = 10.5 * sc
        context.fill(circle(CGPoint(x: center.x, y: center.y + 2 * sc), r), with: .color(.black.opacity(0.35 * alpha)))
        context.fill(circle(center, r), with: .color(Color.white.opacity(0.96 * alpha)))
        context.stroke(circle(center, r), with: .color(shade.tagRim.opacity(alpha)), lineWidth: max(1, 1.6 * sc))
        drawLabel(context, labels.finger(finger, in: context), color: shade.tagInk.opacity(alpha), at: center,
                  scale: max(8 / GemLabels.fingerSize, sc))
    }

    // MARK: Hits

    /// Each hit bursts on the hit line: a beam up its lane, the line lighting up either side (a perfect note lights
    /// all of it), then the burst itself (bigger and white-gold when perfect). Reduce Motion keeps just the target
    /// lighting up.
    private func drawHits(_ context: inout GraphicsContext, _ g: Lanes) {
        guard !calm else { return }
        var light = context
        light.blendMode = .plusLighter
        for i in notes.indices {
            guard let s = notes[i].at?.string, let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
            let age = now - time
            guard age >= 0, age < HitBurst.lifetime else { continue }
            let perfect = grade == .perfect
            let tint = perfect ? Self.perfectGold : Self.color(string: s, of: strings)
            let cx = g.x(s, 0)
            if age < 0.4 {
                let f = 1 - age / 0.4
                let top = 0.45
                let half = g.gap * 0.42
                var beam = Path()
                beam.move(to: CGPoint(x: cx - half, y: g.hitY))
                beam.addLine(to: CGPoint(x: g.x(s, top) - half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: g.x(s, top) + half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: cx + half, y: g.hitY))
                beam.closeSubpath()
                light.fill(beam, with: .linearGradient(Gradient(colors: [tint.opacity((perfect ? 0.55 : 0.35) * f), tint.opacity(0)]),
                                                       startPoint: CGPoint(x: 0, y: g.hitY), endPoint: CGPoint(x: 0, y: g.y(top))))
            }
            if perfect, age < 0.28 {
                let f = 1 - age / 0.28
                let from = g.left(0) - 6, to = g.right(0) + 6
                let band = CGRect(x: from, y: g.hitY - 10, width: to - from, height: 20)
                light.fill(Path(roundedRect: band, cornerRadius: 10),
                           with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.4 * f), tint.opacity(0)]),
                                                 startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
            }
            if perfect { drawLineBurst(&light, g, from: cx, age: age) }
            if age < 0.3 {
                let f = 1 - age / 0.3
                let reach: CGFloat = perfect ? 150 : 100
                let streak = CGRect(x: cx - reach, y: g.hitY - 3, width: reach * 2, height: 6)
                light.fill(Path(roundedRect: streak, cornerRadius: 3),
                           with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.9 * f), tint.opacity(0)]),
                                                 startPoint: CGPoint(x: streak.minX, y: 0), endPoint: CGPoint(x: streak.maxX, y: 0)))
            }
            HitBurst.draw(&light, at: CGPoint(x: cx, y: g.hitY), tint: tint, perfect: perfect, age: age, seed: i, upward: true)
        }
    }

    /// A perfect note's burst along the hit line: a white-gold shock ring opening flat on the board around the
    /// target, and two sparks racing out from it to the ends of the line, each trailing a streak that lights it.
    /// Drawn into an additive context.
    private func drawLineBurst(_ light: inout GraphicsContext, _ g: Lanes, from cx: CGFloat, age: Double) {
        let life = Self.perfectFlash
        guard age >= 0, age < life else { return }
        let p = age / life
        let eased = CGFloat(1 - pow(1 - p, 3))
        let gold = Self.perfectGold
        // The shock ring, lying on the board (flattened by the runway's tilt).
        let radius = 22 + eased * 120
        let ring = CGRect(x: cx - radius, y: g.hitY - radius * 0.28, width: radius * 2, height: radius * 0.56)
        light.stroke(Path(ellipseIn: ring), with: .color(gold.opacity(0.75 * (1 - p))), lineWidth: 1 + 3 * CGFloat(1 - p))
        // Sparks to either end, a touch quicker than the ring.
        let run = min(1, eased * 1.25)
        let ends = [g.left(0) - 6, g.right(0) + 6]
        for end in ends {
            let head = cx + (end - cx) * run
            let fade = 1 - p
            let streak = CGRect(x: min(cx, head), y: g.hitY - 2.5, width: abs(head - cx), height: 5)
            light.fill(Path(roundedRect: streak, cornerRadius: 2.5),
                       with: .linearGradient(Gradient(colors: [gold.opacity(0.15 * fade), gold.opacity(0.85 * fade)]),
                                             startPoint: CGPoint(x: cx, y: 0), endPoint: CGPoint(x: head, y: 0)))
            let glow: CGFloat = 16
            light.fill(circle(CGPoint(x: head, y: g.hitY), glow),
                       with: .radialGradient(Gradient(colors: [Color.white.opacity(0.9 * fade), gold.opacity(0.5 * fade), gold.opacity(0)]),
                                             center: CGPoint(x: head, y: g.hitY), startRadius: 0, endRadius: glow))
        }
    }

    /// Each note's verdict, popping over the hit line where it was judged.
    private func drawPops(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        let lift = Self.targetRadius(g) + 18
        let bounds = CGRect(x: 8, y: 0, width: size.width - 16, height: size.height)
        for i in notes.indices {
            guard let s = notes[i].at?.string, let grade = grades[i], let time = hitTimes[i] else { continue }
            let age = now - time
            guard age >= 0, age < HighwayPop.lifetime else { continue }
            HighwayPop.draw(&context, grade: grade, offset: offsets[i], lane: Self.color(string: s, of: strings),
                            at: CGPoint(x: g.x(s, 0), y: g.hitY - lift), age: age, bounds: bounds, calm: calm)
        }
    }

    // MARK: Finish

    private func drawVignette(_ context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: .zero, endPoint: CGPoint(x: 36, y: 0)))
        context.fill(Path(CGRect(x: size.width - 36, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: CGPoint(x: size.width, y: 0), endPoint: CGPoint(x: size.width - 36, y: 0)))
    }

    /// The outer lanes named in words under their targets ("Thinnest" and "Thickest": the numbers are in the
    /// rings, so they aren't said twice), each on a dark plate so the strings running under it never cut through
    /// the letters.
    private func drawLabels(_ context: inout GraphicsContext, _ g: Lanes, scale: CGFloat) {
        guard let edges, g.strings >= 2 else { return }
        let plate = Palette.stageDeep.opacity(0.8)
        let points = DiagramType.size(DiagramType.floor, scale: scale)
        let y = g.hitY + Self.targetRadius(g) + 7 + points * 0.6
        func styled(_ word: Text) -> Text { word.font(DiagramType.font(points, weight: .semibold)).foregroundStyle(Palette.inkSoft) }
        // Reading inward from the outer lanes, and always whole on the stage.
        if let word = edges.word(g.leftString) {
            edgeLabel(&context, styled(word), from: g.laneX(0, 0) - 16, leading: true, y: y, width: g.width, plate: plate)
        }
        if let word = edges.word(g.rightString) {
            edgeLabel(&context, styled(word), from: g.laneX(g.strings - 1, 0) + 16, leading: false, y: y, width: g.width, plate: plate)
        }
    }

    /// An edge name on its plate, from `x` (where it starts, or ends when it reads leftward), kept clear of the
    /// stage's sides and rounded corners.
    private func edgeLabel(_ context: inout GraphicsContext, _ text: Text, from x: CGFloat, leading: Bool, y: CGFloat, width: CGFloat, plate: Color) {
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: width / 2, height: 40))
        let inset: CGFloat = 16
        let proposed = leading ? x : x - size.width
        let minX = min(max(proposed, inset), max(inset, width - inset - size.width))
        let rect = CGRect(x: minX - 6, y: y - size.height / 2 - 2, width: size.width + 12, height: size.height + 4)
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(plate))
        context.draw(resolved, at: CGPoint(x: minX, y: y), anchor: .leading)
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Around the stage

/// The combo multiplier: ×2 from 4 perfect or good notes in a row, ×3 from 8, ×4 from 16. A ring around the
/// run's length fills toward the next step, and the badge pulses (and its flame hops) as it steps up. Its counting
/// and colours also drive the play-along's stage HUD (`HighwayHUD`).
struct ComboBadge: View {
    let combo: Int
    /// Reduce Motion: no pulse, no hop.
    var calm = false

    static func multiplier(_ combo: Int) -> Int { combo >= 16 ? 4 : combo >= 8 ? 3 : combo >= 4 ? 2 : 1 }

    /// 0…1 of the way to the next step; full at ×4.
    static func progress(_ combo: Int) -> Double {
        switch combo {
        case ..<4: return Double(max(0, combo)) / 4
        case 4..<8: return Double(combo - 4) / 4
        case 8..<16: return Double(combo - 8) / 8
        default: return 1
        }
    }

    /// The flame's orange, amber at ×3, white-gold at ×4.
    static func tint(_ multiplier: Int) -> Color {
        switch multiplier {
        case 4...: return HighwayRunway.perfectGold
        case 3: return Palette.amber
        default: return Palette.flame
        }
    }

    var body: some View {
        let level = Self.multiplier(combo)
        let tint = Self.tint(level)
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(tint.opacity(0.22), lineWidth: 3)
                Circle().trim(from: 0, to: max(0.001, Self.progress(combo)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(combo, format: .number).font(Typeface.number(10)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 26, height: 26)
            .animation(calm ? nil : Motion.quick, value: combo)
            HStack(spacing: 2) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                    .symbolEffect(.bounce, value: calm ? 0 : level)
                Text("×\(level)").font(Typeface.number(18))
                    .contentTransition(.numericText(value: Double(level)))
            }
            .foregroundStyle(tint)
        }
        .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(level >= 4 ? 0.65 : 0.3), lineWidth: 1))
        .shadow(color: tint.opacity(level >= 3 ? 0.5 : 0), radius: 10)
        .phaseAnimator([1.0, 1.24], trigger: level) { content, scale in
            content.scaleEffect(CGFloat(calm ? 1 : scale))
        } animation: { _ in Motion.pop }
        .animation(calm ? nil : Motion.pluck, value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combo ×\(combo)"))
    }
}

/// The notes after the next one, in order: tiles in their string's colour with the fret over the note name
/// (just the note on pitch lanes). They slide along as each note is played, fading toward the end of the rail.
struct UpNextRail: View {
    let notes: [TimedNote]
    /// The first note on the rail (the one after "Next").
    let from: Int
    let fretted: Bool
    let strings: Int
    let accent: Color
    static let length = 6

    private var shown: [Int] { from < notes.count ? Array(from..<min(notes.count, from + Self.length)) : [] }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
                .opacity(shown.isEmpty ? 0 : 1)
            ForEach(shown, id: \.self) { index in
                tile(notes[index], rank: index - from)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .scale(scale: 0.6).combined(with: .opacity)))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func tile(_ note: TimedNote, rank: Int) -> some View {
        let tint = color(note)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous)
        return VStack(spacing: 0) {
            if fretted, let at = note.at {
                Text(at.fret, format: .number).font(Typeface.number(16)).foregroundStyle(Palette.ink)
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(11)).foregroundStyle(tint)
            } else {
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(15)).foregroundStyle(Palette.ink)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: 42, height: 42)
        .background(shape.fill(tint.opacity(0.16)))
        .overlay(shape.strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .overlay(alignment: .bottom) { Capsule().fill(tint).frame(width: 18, height: 3).offset(y: 1.5) }
        .opacity(1 - Double(rank) * 0.13)
    }

    private func color(_ note: TimedNote) -> Color {
        guard fretted, let at = note.at else { return accent }
        return HighwayRunway.color(string: at.string, of: strings)
    }
}

/// The take so far, under the stage while it plays: the grades counted, and a ribbon with a segment per note
/// that takes its grade's colour as it is judged (white-gold perfect, the course colour good, amber late or
/// early, coral missed); the note being waited for stands taller. A whole song is too many notes for one row: past
/// `window` notes the ribbon shows the stretch around the current note, a quarter of it already played.
struct TakeRibbon: View {
    let count: Int
    let grades: [Int: PlayAlongJudge.Grade]
    let current: Int
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The most segments drawn at once.
    static let window = 48

    /// The notes the ribbon shows: all of them, or a window that follows the take.
    private var shown: Range<Int> {
        let total = max(0, count)
        guard total > Self.window else { return 0..<total }
        let first = min(max(0, current - Self.window / 4), total - Self.window)
        return first..<(first + Self.window)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                stat(.perfect, symbol: "star.fill", name: "Perfect")
                stat(.good, symbol: "checkmark", name: "Good")
                stat(.ok, symbol: "clock", name: "Early/late")
                stat(.miss, symbol: "xmark", name: "Missed")
            }
            HStack(spacing: shown.count > 32 ? 1 : 2) {
                ForEach(shown, id: \.self) { index in
                    Capsule()
                        .fill(segment(index))
                        .frame(height: index == current ? 10 : 6)
                }
            }
            .frame(height: 10)
            .animation(reduceMotion ? nil : Motion.quick, value: grades.count)
            .animation(reduceMotion ? nil : Motion.quick, value: shown.lowerBound)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func segment(_ index: Int) -> Color {
        guard let grade = grades[index] else { return Color.white.opacity(index == current ? 0.4 : 0.1) }
        return Self.color(grade, accent: accent)
    }

    static func color(_ grade: PlayAlongJudge.Grade, accent: Color) -> Color {
        switch grade {
        case .perfect: return HighwayRunway.perfectGold
        case .good: return accent
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }

    private func stat(_ grade: PlayAlongJudge.Grade, symbol: String, name: LocalizedStringKey) -> some View {
        let value = grades.values.reduce(0) { $0 + ($1 == grade ? 1 : 0) }
        return HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            Text(value, format: .number).font(Typeface.number(15))
                .contentTransition(.numericText(value: Double(value)))
        }
        .foregroundStyle(Self.color(grade, accent: accent))
        .opacity(value == 0 ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(value, format: .number))
    }
}

#if DEBUG
/// The demo pitch (UI tests) plays each play-along note the moment it falls due, from a loop on the main thread. A
/// stalled frame (the simulator drawing the runway in software) only delays when that reading reaches the judge, so
/// a demo take is judged at the moment the note was due to sound, as a steady player would play it, not when the
/// stalled frame got round to it.
@MainActor func demoJudgedTime(_ clock: Double, judge: PlayAlongJudge, store: AppStore, heard: Bool) -> Double {
    guard store.demoNoteDue != nil, heard, judge.nextIndex < judge.notes.count else { return clock }
    return min(clock, judge.time(of: judge.nextIndex) + 0.01)
}
#endif
