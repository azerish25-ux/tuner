import QuartzCore
import SwiftUI
import TimbreCore

/// Play-along: notes glide toward the "now" line on their string (or pitch lane); the microphone
/// judges each one for timing and intonation. Count-in, a tempo ladder (75 → 90 → 100 → 110 %), combo, results.
/// Over a band that follows the song's chords when the tune is a stretch of a song with a chart (its drums and a bass
/// on the tune's key otherwise), thinning on a miss and filling back in on a run. With VoiceOver, spoken cues name
/// each note ahead of it (`SpokenCues.Timing`) and the results are read out; "Start on first strum" lets the instrument
/// start a take, a keyboard or page-turner pedal drives Start, Try again and Continue, and Esc drops a take. A violin's
/// or cello's notes read and are said as fingers (`FingerPlace`), never as frets.
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
    /// The take under way, or the last one.
    @State private var session: PlayAlongSession
    /// The grades of the take that counts (the ladder's outcome).
    @State private var countedGrades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var calibrating = false
    /// A bar practised on its own from the results (tap a missed note on the timing strip): its notes over and over
    /// at a slower tempo. Nil plays the whole tune.
    @State private var loop: BarLoop?
    /// The tempo of the last whole-tune take, so a loop from its results runs slower than that take did.
    @State private var takeTempo: Double?
    /// The whole-tune results a loop was started from: Done goes back to them (Try again or Continue from there).
    @State private var parked: PlayAlongSession?
    /// A take started the click: closing or leaving the app stops it (never the Metronome tool's own click).
    @State private var ownsClick = false
    @State private var audioStart = AudioStartGate()
    /// The song's chords under the tune, bar by bar (each change inside a bar too), when it is a stretch of a song
    /// with a chart.
    @State private var chart: [ChordBar]?
    /// The count-in beat last felt.
    @State private var countInBeat: Int?
    /// When the take's spoken cues are said.
    @State private var cueTiming = SpokenCues.Timing()
    /// The last attack heard while "Start on first strum" waits.
    @State private var armedOnset: CFTimeInterval = 0
    @AppStorage(StrumStart.storageKey) private var strumChoice: Bool?
    @AppStorage(SpokenCues.storageKey) private var spokenChoice: Bool?
    @AccessibilityFocusState private var resultsFocused: Bool
    /// How the player holds the instrument: a left-hander's lanes run mirrored.
    @CurrentHand private var hand
    /// The tune's words, line by line (a song's verse or chorus; empty for a tune without words).
    private let lyrics: LyricSheet
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    enum Phase: Equatable { case ready, playing, done }

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
        let fretted = course.fretKind != nil && sorted.allSatisfy { $0.at != nil }
        _session = State(initialValue: PlayAlongSession(notes: sorted, bpm: bpm, beatsPerBar: beatsPerBar, anyOctave: course.anyOctave,
                                                        keepsTrail: !fretted))
    }

    /// What a take plays: the whole tune, or the bar on repeat.
    private var take: [TimedNote] { loop?.notes ?? notes }
    private var tempo: Double { loop?.bpm ?? ladder.tempo }
    private var spb: Double { 60 / tempo }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    /// A violin's or cello's fingerboard: its notes read as fingers, not frets.
    private var board: Fingerboard? { fretted ? Fingerboard(instrument: course.instrument) : nil }
    /// Spoken cues: on while VoiceOver runs, unless turned off.
    private var spoken: Bool { voiceOver && (spokenChoice ?? true) }
    /// "Start on first strum": the player's choice, else on while VoiceOver runs (where the microphone can hear).
    private var strumStarts: Bool { StrumStart.offered && (strumChoice ?? voiceOver) }
    private var strumBinding: Binding<Bool> {
        Binding(get: { strumStarts }, set: { strumChoice = $0 })
    }
    /// Listening for the first note before a take.
    private var armed: Bool { strumStarts && phase == .ready }
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
    private var multiplier: Int { session.multiplier }
    /// Seconds of music the runway shows ahead of the hit line: two bars or more, so three or four notes are
    /// always on the board whatever the tempo.
    private var lookahead: Double { HighwayRunway.lookahead(secondsPerBeat: spb, beatsPerBar: beatsPerBar) }

    /// The band under a take: on the song's chords, change by change, where the tune has a chart (a looped bar keeps
    /// its chords), else drums and a bass on the tune's key; no band bass when the player is the bass.
    private func arrangement(under chords: [ChordBar]?) -> BandArrangement {
        let reference = store.settings.referencePitchHz
        let bass = course.fretKind != "bass"
        if let loop {
            var held: [ChordBar]?
            if let chords, chords.indices.contains(loop.bar) { held = Array(repeating: chords[loop.bar], count: BarLoop.passes) }
            return SongPlayback.band(take: loop.notes, harmony: held, bpm: tempo, meter: beatsPerBar, reference: reference, bass: bass)
        }
        return SongPlayback.band(take: notes, harmony: chords, bpm: tempo, meter: beatsPerBar, reference: reference, bass: bass)
    }
    private var band: BandArrangement { arrangement(under: chart) }

    var body: some View {
        VStack(spacing: 0) {
            if typeSize.isAccessibilitySize {
                ScrollViewReader { scroll in
                    ScrollView { stepContent }
                        .onChange(of: phase) { _, phase in
                            if phase != .ready { scroll.scrollTo("along.runway", anchor: .top) }
                        }
                }
            } else {
                stepContent
            }
        }
        .onAppear {
            let found = LeadChart.bars(underStep: notes, meter: beatsPerBar, in: course)
            chart = found
            store.audio.prepareBand(arrangement(under: found))
            arm()
        }
        .onChange(of: ladder.rung) { _, _ in store.audio.prepareBand(band) }
        .onChange(of: loop) { _, _ in store.audio.prepareBand(band) }
        .onChange(of: armed) { _, _ in arm() }
        // Leaving the app mid-take drops the take: no click left sounding in a pocket, nothing half-heard graded.
        .onChange(of: scenePhase) { _, now in if now == .background { abandonTake() } }
        .onDisappear {
            audioStart.cancel()
            if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
            ownsClick = false
            store.audio.stopBand(); store.stopLessonListening(owner: owner)
            BandFeel.shared.reset()
            #if DEBUG
            store.demoNoteDue = nil
            #endif
        }
        .sheet(isPresented: $calibrating) {
            LatencyCalibrationSheet(accent: accent).environmentObject(store)
        }
    }

    // MARK: Pieces

    private var stepContent: some View {
        VStack(spacing: 14) {
            header
            stage
                .id("along.runway")
            if !lyrics.isEmpty { lyricRow }
            // Its whole height, always: the stage gives up the room instead, so "Next" never sits over its edge.
            upcoming
                .frame(minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(phase == .done ? 0 : 1)
                .accessibilityHidden(phase == .done)
            Spacer(minLength: 0)
            MicrophoneHint()
            controls
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // The step's title, as on every step: two lines at most here, so the stage keeps its room.
                StepTitle(Text(title?.localized ?? String(localized: "Play along")))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if StrumStart.offered {
                    StrumStartToggle(isOn: strumBinding, accent: accent, listening: armed)
                        .disabled(phase == .playing)
                        .opacity(phase == .playing ? 0.4 : 1)
                }
            }
            // The combo lives in the stage's HUD; the row keeps its height so the stage never shifts.
            .frame(minHeight: 36)
            let detailsLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            detailsLayout {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(tempo)) BPM · \(take.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.8)
                    if let loop { loopBadge(loop) } else { tempoBadge }
                    Spacer(minLength: 8)
                }
                HStack(spacing: 8) {
                    CalibrateButton(audio: store.audio, accent: accent) { calibrating = true }
                        .disabled(phase == .playing)
                        .opacity(phase == .playing ? 0.4 : 1)
                    BandControls(audio: store.audio, accent: accent)
                }
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .trailing)
            }
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 8)
        // Always its full height: the title never shrinks to make room below.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The runway with the count-in over it, the combo HUD in its top corners and the results in its place once a
    /// take ends.
    private var stage: some View {
        TimelineView(.animation(paused: phase != .playing)) { _ in
            let now = CACurrentMediaTime()
            // Seconds since beat 0 on the heard clock (negative during the count-in).
            let clock = session.clock(at: now)
            ZStack {
                // Hits burst on the hit line inside the drawing (bigger and white-gold when perfect).
                runway(elapsed: runwayElapsed(now: now), now: phase == .done ? now + 10 : now)
                if phase == .playing, clock < 0 {
                    Text("\(Int(-clock / spb) + 1)").font(Typeface.hero(96)).foregroundStyle(Palette.ink)
                        .shadow(color: accent.opacity(0.6), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }
                if armed { StrumToStartHint(accent: accent).transition(.opacity) }
            }
            .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
        }
        .animation(reduceMotion ? nil : Motion.quick, value: armed)
        .modifier(RunwayAccessibility(label: Text("Play-along, \(take.count) notes"), value: runwayValue, spoken: spoken,
                                      canSpeak: voiceOver) { spokenChoice = !spoken })
        // Shrinks on short phones rather than pushing the header off the top; the controls keep one height
        // through ready, playing and done, so the stage never changes size when a take starts or ends.
        .frame(minHeight: typeSize.isAccessibilitySize ? 420 : 220,
               maxHeight: typeSize.isAccessibilitySize ? 420 : (fretted ? 420 : 300))
        // The combo and multiplier over the stage's top corners while a take plays.
        .overlay(alignment: .top) {
            if phase == .playing {
                HighwayHUD(combo: session.combo, calm: reduceMotion)
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
    }

    /// What VoiceOver reads on the runway: the note coming up while a take plays, how it went once it is over.
    private var runwayValue: Text {
        switch phase {
        case .ready:
            return armed ? Text("Play a note to start") : Text(verbatim: "")
        case .playing:
            let index = session.nextIndex
            guard take.indices.contains(index) else { return Text(verbatim: "") }
            return Text("Next: \(NotePlace.spoken(take[index], fretted: fretted, board: board))")
        case .done:
            return Text(verbatim: resultSpoken)
        }
    }

    /// The tempo level at a glance: 100 % in the course colour, slower in amber.
    private var tempoBadge: some View {
        Text("\(ladder.percent)%")
            .font(Typeface.number(.caption))
            .fixedSize()
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
                Text("Bar \(loop.bar + 1)").font(Typeface.label(.caption))
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
            Glyph("repeat", size: Glyph.lead, tint: Palette.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bar \(loop.bar + 1)").font(Typeface.label(.body)).foregroundStyle(Palette.ink)
                Text("\(Int(loop.bpm)) BPM · \(BarLoop.passes) bars").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if phase == .ready {
                Button { exitLoop() } label: {
                    Text("Done").font(Typeface.label(.body)).foregroundStyle(accent)
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

    /// The fretboard runway on fretted courses (its lanes the lowest string first, as the chord pictures, mirrored for
    /// a left-hander), pitch lanes otherwise.
    @ViewBuilder private func runway(elapsed: Double, now: CFTimeInterval) -> some View {
        if fretted {
            HighwayRunway(notes: take, secondsPerBeat: spb, elapsed: elapsed, grades: session.grades, hitTimes: session.hitTimes,
                          now: now, strings: course.stringCount, edges: StringEdges.of(course), beatsPerBar: beatsPerBar,
                          heat: multiplier, calm: reduceMotion, mirrored: hand.mirrorsUpright, offsets: session.offsets,
                          tierUp: session.tierUp, fingerboard: board)
        } else {
            HighwayCanvas(notes: take, secondsPerBeat: spb, elapsed: elapsed, grades: session.grades, hitTimes: session.hitTimes,
                          now: now, lanes: 0, accent: accent, trail: session.trail, startTime: session.startTime + session.countIn,
                          calm: reduceMotion, offsets: session.offsets)
        }
    }

    /// Where the runway stands, in seconds since beat 0. Before the start the first notes already wait on the near
    /// part of the board (three or four in view); as the count-in begins they glide back to where it puts them, a
    /// bar from the line, rather than jumping there (with Reduce Motion they do jump).
    private func runwayElapsed(now: CFTimeInterval) -> Double {
        let preview = -0.2 * lookahead
        switch phase {
        case .ready: return preview
        case .done: return session.clock(at: now)
        case .playing: return session.runwayClock(at: now, waiting: preview, glide: !reduceMotion)
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
        return session.clock(at: now) / spb
    }

    /// The next note by name and where to play it (on a fretted neck with the finger to use, on the same white tag the
    /// gems wear; on a fingerboard the place is the finger), then the notes after it on a rail.
    @ViewBuilder private var upcoming: some View {
        let take = self.take
        let index = min(session.nextIndex, take.count - 1)
        if take.indices.contains(index) {
            let note = take[index]
            VStack(alignment: .leading, spacing: 10) {
                // Keep the cue together, but let its complete playing-place label move below it.
                ChordFlowLayout(spacing: 10, lineSpacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("Next").font(Typeface.label(.footnote)).foregroundStyle(Palette.inkFaint)
                        Text(NoteName.name(note.midi)).font(Typeface.display(.title3)).foregroundStyle(Palette.ink)
                    }
                    if fretted, let at = note.at { place(at, tint: nextTint(note)) }
                }
                // Letters and places cross-fade: rolling them like digits doubles a note's octave figure.
                .contentTransition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Next: \(NotePlace.spoken(note, fretted: fretted, board: board))"))
                .accessibilityIdentifier("along.next")
                UpNextRail(notes: take, from: index + 1, fretted: fretted, strings: course.stringCount, accent: accent, fingerboard: board)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.gutter)
            .animation(reduceMotion ? nil : Motion.quick, value: index)
        }
    }

    /// Where to play the next note, on a chip in its string's colour: "String 2, fret 3" and the finger's tag on a
    /// fretted neck; "String 1, finger 1" on a fingerboard, where the finger is the place.
    @ViewBuilder private func place(_ at: Fretting, tint: Color) -> some View {
        AlongPlaceLabel(words: NotePlace.words(at, board: board), tint: tint)
        if board == nil, at.fret > 0, let finger = at.finger, finger > 0 { fingerTag(finger, tint: tint) }
    }

    /// The finger to fret the next note with: a white tag with its number, as pinned to the gem's corner.
    private func fingerTag(_ finger: Int, tint: Color) -> some View {
        Text(verbatim: "\(finger)")
            .font(Typeface.number(.footnote))
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
    private var percent: Int { Int((session.accuracy * 100).rounded()) }
    /// Mint from 90 %, amber below and never red: a weak take is a warm-up to run again, not a failure.
    private var scoreTint: Color { percent >= LessonRun.greatTake ? Palette.mint : Palette.amber }
    /// Under half the take landed: the card leads with another go (Try again takes the filled button).
    private var retryFirst: Bool { percent < LessonRun.warmTake }
    /// What a great take did, as a fact ("6 for 6, on the beat").
    private var fact: LocalizedStringKey { TakeFact.headline(hits: session.hits, of: take.count, meanOffset: session.meanOffset) }

    private var verdict: LocalizedStringKey {
        if percent >= LessonRun.greatTake { return fact }
        return retryFirst ? "Just warming up" : "Keep going"
    }

    /// The take's result as VoiceOver reads it: "5 of 6 notes, 2 perfect. 83 %".
    private var resultSpoken: String {
        SpokenCues.result(hits: session.hits, of: take.count, perfect: session.count(.perfect), percent: percent)
    }

    /// The full card when the stage is tall enough; on short phones the verdict and timing strip give way.
    private var summary: some View {
        ViewThatFits(in: .vertical) {
            summaryCard(compact: false)
            summaryCard(compact: true)
        }
    }

    private func summaryCard(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            VStack(spacing: compact ? 8 : 10) {
                if !compact {
                    Text(verdict).font(Typeface.label(.body)).foregroundStyle(scoreTint)
                }
                Text("\(percent)%").font(Typeface.note(compact ? .display : .hero)).foregroundStyle(scoreTint)
                    .minimumScaleFactor(0.7)
            }
            // Where VoiceOver lands when a take ends: the whole result in one sentence.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: resultSpoken))
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($resultsFocused)
            if steppedUp { tempoUp }
            // In the grades' colours, as on the ribbon and the timing strip.
            HStack(spacing: 18) {
                stat("Perfect", session.count(.perfect), TakeRibbon.color(.perfect, accent: accent))
                stat("Good", session.count(.good), TakeRibbon.color(.good, accent: accent))
                stat("Early/late", session.count(.ok), TakeRibbon.color(.ok, accent: accent))
                stat("Missed", session.count(.miss), TakeRibbon.color(.miss, accent: accent))
            }
            if !compact {
                // A dot per note, early above the line and late below; tapping a missed note loops its bar, slower.
                HighwayTimingStrip(count: take.count, judgments: session.judge.judgments, accent: accent, calm: reduceMotion,
                                   onLoop: loopAction, bar: { bar(of: $0) })
            }
            Text(timingNote).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            if timingIsOff {
                // Consistently early or late usually means the headphones or speaker lag: measure it.
                Button { calibrating = true } label: { Label("Calibrate timing", systemImage: "metronome") }
                    .font(Typeface.label(.body)).foregroundStyle(accent)
                    .accessibilityIdentifier("along.calibrate.hint")
            } else if session.judge.bestCombo >= 2 {
                Text("Best combo \(session.judge.bestCombo)").font(.footnote).foregroundStyle(Palette.inkSoft)
            }
            if percent >= LessonRun.greatTake && loop == nil { takeShare.padding(.top, 2) }
            if loop == nil && session.accuracy < 0.8 && ladder.rung > 0 {
                Button { ladder.select(0); reset() } label: { Label("Try it at \(Int(ladder.tempo(at: 0))) BPM", systemImage: "tortoise.fill") }
                    .font(Typeface.label(.body)).foregroundStyle(accent).padding(.top, 2)
                    .accessibilityIdentifier("along.slower")
                    .lessonControl(.slower) { ladder.select(0); reset() }
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

    /// A take of 90 % or more: its poster, a tap from the share sheet (three stars at the lesson tempo, else two),
    /// headed with what the take did.
    private var takeShare: some View {
        let full = (steppedUp ? ladder.rung - 1 : ladder.rung) >= TempoLadder.lessonRung
        let headline = fact
        return SharePill(preview: headline, tint: accent) {
            LessonShareCard(course: course.title.localized, title: title?.localized ?? String(localized: "Play along"), headline: headline,
                            stars: full ? 3 : TempoLadder.slowStarCap, accuracy: percent, accent: accent, song: false,
                            streak: store.streak.current)
        }
        .accessibilityIdentifier("along.share")
    }

    /// The take's offsets lean one way by 90 ms or more on average.
    private var timingIsOff: Bool {
        guard session.judge.judgments.compactMap(\.offset).count >= 3, let mean = session.meanOffset else { return false }
        return abs(mean) >= 0.09
    }

    /// Where the timing went: early or late on average, in milliseconds.
    private var timingNote: LocalizedStringKey {
        guard let mean = session.meanOffset else { return "Play each note as it reaches the line" }
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
                StepButton(title: "Start") { start() }
            }
        case .playing:
            VStack(spacing: 12) {
                // The take so far, in the ladder's place: the hidden ladder keeps its height, so nothing moves.
                ladderPicker
                    .hidden()
                    .accessibilityHidden(true)
                    .overlay { TakeRibbon(count: take.count, grades: session.grades, current: session.nextIndex, accent: accent) }
                StepButton(title: "Listening…", enabled: false) {}
                    // Esc on a keyboard drops the take, back to Start, as Stop does in a song.
                    .background { StopKey { abandonTake() } }
            }
        case .done:
            VStack(spacing: 12) {
                ladderOrLoop
                AlongActionLayout(spacing: 10) {
                    if loop != nil {
                        // The loop again until it's clean; then Done (back to the whole tune's results) comes first.
                        let clean = session.accuracy >= TempoLadder.stepUpAccuracy
                        doneButton("Try again", primary: !clean) { reset() }
                            .accessibilityIdentifier("along.again")
                            .lessonControl(.again) { reset() }
                        doneButton("Done", primary: clean) { exitLoop() }
                            .accessibilityIdentifier("along.loop.exit")
                            .lessonControl(.primary) { exitLoop() }
                    } else {
                        // A weak take puts another go first: Try again takes the filled button, Continue steps back.
                        doneButton("Try again", primary: retryFirst) { reset() }
                            .accessibilityIdentifier("along.again")
                            .lessonControl(.again) { reset() }
                        doneButton("Continue", primary: !retryFirst) { complete() }
                            .accessibilityIdentifier("lesson.continue")
                            .lessonControl(.primary) { complete() }
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

    /// The results' pair: the one to do next as the primary button, the other as the secondary.
    private func doneButton(_ title: LocalizedStringKey, primary: Bool, action: @escaping () -> Void) -> some View {
        AlongDoneButton(title: title, primary: primary, action: action)
    }

    /// The four tempo rungs, the current one filled; below the lesson tempo a note that full tempo earns three stars.
    private var ladderPicker: some View {
        VStack(spacing: 6) {
            if typeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(TempoLadder.rungs.indices, id: \.self) { rung in rungButton(rung) }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(TempoLadder.rungs.indices, id: \.self) { rung in rungButton(rung) }
                }
            }
            Label("Full tempo for 3 stars", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.starGold)
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
            TempoRungFace(percent: Int((TempoLadder.rungs[rung] * 100).rounded()), bpm: Int(ladder.tempo(at: rung)))
            .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
            .background(shape.fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(shape.strokeBorder(selected ? Color.clear : Palette.controlLine, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if rung == TempoLadder.lessonRung {
                    // The lesson's own tempo.
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(selected ? Palette.onAccent : Palette.starGold).padding(6)
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

    /// A fresh take for what the next one plays (the whole tune or the looped bar), nothing judged yet.
    private func clearTake() {
        session = PlayAlongSession(notes: take, bpm: tempo, beatsPerBar: beatsPerBar, anyOctave: course.anyOctave, keepsTrail: !fretted)
        steppedUp = false
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
        if loop == nil { parked = session }
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
                session = parked
                steppedUp = false
                phase = .done
            } else {
                clearTake()
                phase = .ready
            }
            parked = nil
        }
    }

    private func start() {
        guard !audioStart.isPending else { return }
        let requestedTempo = tempo
        ownsClick = true
        audioStart.begin(store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)) {
            startReady(tempo: requestedTempo)
        }
    }

    private func startReady(tempo: Double) {
        session = PlayAlongSession(notes: take, bpm: tempo, beatsPerBar: beatsPerBar, anyOctave: course.anyOctave, keepsTrail: !fretted)
        steppedUp = false
        if loop == nil { takeTempo = tempo }
        session.begin(at: CACurrentMediaTime())
        cueTiming = SpokenCues.Timing(session)
        countInBeat = nil
        phase = .playing
        BandFeel.shared.reset(duck: spoken)
        if spoken { Earcons.shared.prepare() }
        // A lesson's click always starts a fresh count (even over the Metronome tool's), so the count-in, runway and
        // judging start with the click they assume.
        // The band rides the metronome from the bar after the count-in (in full in headphones, its drums on the speaker).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = take.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        #if DEBUG
        store.demoNoteDue = { session.nextIndex < take.count && session.clock(at: CACurrentMediaTime()) >= session.judge.time(of: session.nextIndex) - 0.02 }
        #endif
        // Re-attacks of a repeated note come from the onset detector (a jump in loudness as a fallback).
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in session.onset(at: time) })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            guard phase == .playing else { return }
            let now = CACurrentMediaTime()
            let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            var clock = session.clock(at: now)
            #if DEBUG
            clock = demoJudgedTime(clock, judge: session.judge, store: store, heard: heard != nil)
            #endif
            react(session.hear(midi: heard?.midi, cents: heard?.cents, level: level, at: now, clock: clock))
        }
    }

    /// "Start on first strum": while the take waits, the microphone listens, and a note of the tune played on the
    /// instrument (an attack, then its pitch) starts it. Off again once the take starts or the switch is off.
    private func arm() {
        guard armed else {
            if phase == .ready { store.stopLessonListening(owner: owner) }
            return
        }
        let wanted = StrumStart.pitchClasses(take)
        armedOnset = 0
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in armedOnset = time })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            guard armed, phase == .ready, !audioStart.isPending, level > -50, CACurrentMediaTime() - armedOnset < 0.3,
                  let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz),
                  wanted.contains(PitchMath.pitchClass(midi: heard.midi)) else { return }
            Haptics.shared.selection()
            start()
        }
    }

    private func tick(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // The first click is heard a little after the tap (engine and microphone starting, output
        // latency, far more on Bluetooth; the tap-along calibration when there is one): notes and
        // judging follow the heard clock, not the tap.
        if let heard = store.audio.heardStart(near: session.startTime) { session.follow(start: heard) }
        let beat = session.countInBeat(at: now)
        if beat != countInBeat {
            countInBeat = beat
            if let beat { TakeFeedback.countIn(beat) }
        }
        if spoken, let cue = cueTiming.due(at: session.clock(at: now)) { speak(cue, now: now) }
        react(session.tick(at: now))
    }

    /// Names the note of `cue` as planned (`SpokenCues.Timing`): in full, or just its place when the note before it is
    /// close; on a fingerboard its string and finger, never a fret.
    private func speak(_ cue: CuePlan.Cue, now: CFTimeInterval) {
        let notes = session.notes
        guard notes.indices.contains(cue.index) else { return }
        let lead = notes[cue.index].beat * session.secondsPerBeat - session.clock(at: now)
        SpokenCues.schedule(notes[cue.index], fretted: fretted, lead: lead, brief: cue.brief, fingerboard: board)
    }

    private func react(_ update: PlayAlongSession.Update) {
        guard !update.isEmpty else { return }
        TakeFeedback.react(update, combo: session.combo, spoken: spoken)
        let take = self.take
        if !update.judgments.isEmpty, session.nextIndex < take.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(take[session.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if update.finished { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        let accuracy = session.accuracy
        var up = false
        // A looped bar is practice: the ladder and the lesson's outcome come from whole-tune takes only.
        if loop == nil {
            // The take that counts keeps its grades for the lesson's weak spots.
            if ladder.improvesOutcome(accuracy) { countedGrades = session.grades }
            up = ladder.record(accuracy: accuracy)
            // The coach reads timing from whole takes only.
            CoachTakes.shared.record(CoachTake(judge: session.judge, beatsPerBar: beatsPerBar, item: { course.practiceItem(for: $0) }))
        }
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        BandFeel.shared.reset()
        ownsClick = false
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        withAnimation(Motion.settle) { phase = .done; steppedUp = up }
        SoundFX.shared.play(accuracy >= 0.7 ? .star : .wrong)
        if up { Haptics.shared.lock() }
        if voiceOver {
            // VoiceOver moves to the result and reads it, once the panel has arrived.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                if phase == .done { resultsFocused = true }
            }
        }
    }

    /// The app went to the background mid-take: the click, the band and the microphone stop and the take is dropped
    /// (nothing graded, nothing for the coach). The step is back at Start.
    private func abandonTake() {
        let starting = audioStart.isPending
        audioStart.cancel()
        guard phase == .playing || starting else { return }
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        BandFeel.shared.reset()
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
        done(outcome?.score ?? session.accuracy)
    }
}

/// A complete tempo choice: percentage and BPM each keep their own line as text grows.
struct TempoRungFace: View {
    let percent: Int
    let bpm: Int

    var body: some View {
        VStack(spacing: 1) {
            Text("\(percent)%").font(Typeface.label(15))
            Text(bpm, format: .number).font(Typeface.number(.caption)).opacity(0.75)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}

/// The runway as VoiceOver reads it: one element naming the play-along, with what is coming up (or how it went) as
/// its value, and, while VoiceOver runs, an action turning the spoken cues off or on.
struct RunwayAccessibility: ViewModifier {
    let label: Text
    let value: Text
    let spoken: Bool
    /// VoiceOver is running: the spoken cues can be switched.
    let canSpeak: Bool
    let toggleSpoken: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAction(named: spoken ? Text("Turn spoken cues off") : Text("Turn spoken cues on")) {
                guard canSpeak else { return }
                toggleSpoken()
            }
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

/// The band corner of a header: the band switch and, on the speaker, a quiet note of what headphones add. While the
/// microphone listens the speaker plays the band's drums alone (the bass and the chords would reach it as notes; drums
/// don't), and on a take judged on its strokes it keeps to the click (drum hits would read as strokes); where nothing
/// listens it plays the whole band and the note isn't needed.
struct BandControls: View {
    /// What the band plays out of the phone's speaker where this switch sits.
    enum Speaker {
        /// The whole band: nothing is listening (a preview, a loop).
        case fullBand
        /// Its drums: a melody take, heard for its notes.
        case drums
        /// The click alone: a take judged on its strokes.
        case click
    }

    @ObservedObject var audio: AudioService
    let accent: Color
    var speaker = Speaker.drums
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            if bandOn && !audio.headphones && speaker != .fullBand { headphonesChip }
            toggle
        }
        .animation(reduceMotion ? nil : Motion.quick, value: bandOn)
        .animation(reduceMotion ? nil : Motion.quick, value: audio.headphones)
        .onAppear { audio.refreshRoute() }
    }

    /// What headphones bring: the full band over the speaker's drums, or the band at all over the click.
    private var headphonesWords: LocalizedStringKey {
        speaker == .click ? "Band with headphones" : "Full band in headphones"
    }

    /// Words when they fit, just the headphones glyph when they don't (narrow phones, large type).
    private var headphonesChip: some View {
        ViewThatFits(in: .horizontal) {
            chip(Label(headphonesWords, systemImage: "headphones"))
            chip(Label(headphonesWords, systemImage: "headphones").labelStyle(.iconOnly))
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
    /// On string lanes of a fingerboard (violin, cello), notes show their finger rather than a fret.
    var fingerboard: Fingerboard?
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

    /// A note's label: on string lanes its fret (its finger on a fingerboard), on pitch lanes its name.
    private func label(_ note: TimedNote, color: Color) -> Text {
        var name = NoteName.pitchClass(note.midi)
        if lanes > 0, let at = note.at {
            name = fingerboard.map { FingerPlace(at, on: $0).shortLabel } ?? "\(at.fret)"
        }
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

// MARK: - Around the stage

/// The combo multiplier: ×2 from 4 perfect or good notes in a row, ×3 from 8, ×4 from 16. A ring around the
/// run's length fills toward the next step, and the badge pulses (and its flame hops) as it steps up. Its counting
/// and colours also drive the play-along's stage HUD (`HighwayHUD`).
struct ComboBadge: View {
    let combo: Int
    /// Reduce Motion: no pulse, no hop.
    var calm = false

    static func multiplier(_ combo: Int) -> Int { PlayAlongSession.multiplier(combo) }

    /// 0…1 of the way to the next step; full at ×4.
    static func progress(_ combo: Int) -> Double {
        switch combo {
        case ..<4: return Double(max(0, combo)) / 4
        case 4..<8: return Double(combo - 4) / 4
        case 8..<16: return Double(combo - 8) / 8
        default: return 1
        }
    }

    /// The flame's orange, gold at ×3, white-gold at ×4: a reward's warmth, never the status amber.
    static func tint(_ multiplier: Int) -> Color {
        switch multiplier {
        case 4...: return HighwayRunway.perfectGold
        case 3: return Palette.starGold
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
                Text(combo, format: .number).font(Typeface.number(.caption)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 26, height: 26)
            .animation(calm ? nil : Motion.quick, value: combo)
            HStack(spacing: 2) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                    .symbolEffect(.bounce, value: calm ? 0 : level)
                Text("×\(level)").font(Typeface.number(.headline))
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

/// A full playing-place label: bounded width may add lines, never discard or shrink its words.
struct AlongPlaceLabel: View {
    let words: String
    let tint: Color

    var body: some View {
        Text(verbatim: words).font(Typeface.label(.body)).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

/// Keep the same two action instances and keyboard roles when their intrinsic labels require a column.
/// Placement is in logical coordinates; SwiftUI supplies the normal single RTL mirror.
struct AlongActionLayout: Layout {
    var spacing: CGFloat = 10

    static func fitsRow(_ widths: [CGFloat], available: CGFloat, spacing: CGFloat) -> Bool {
        guard !widths.isEmpty else { return true }
        return CGFloat(widths.count) * (widths.max() ?? 0) + CGFloat(widths.count - 1) * spacing <= available
    }

    private func frames(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        guard !subviews.isEmpty else { return [] }
        let row = Self.fitsRow(subviews.map { $0.sizeThatFits(.unspecified).width }, available: width, spacing: spacing)
        let cellWidth = row ? max(0, (width - CGFloat(subviews.count - 1) * spacing) / CGFloat(subviews.count)) : width
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }
        let rowHeight = heights.max() ?? 0
        var y: CGFloat = 0
        return heights.enumerated().map { index, height in
            let rect = CGRect(x: row ? CGFloat(index) * (cellWidth + spacing) : 0, y: row ? 0 : y,
                              width: cellWidth, height: row ? rowHeight : height)
            if !row { y += height + spacing }
            return rect
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
        let ideal = CGFloat(widths.count) * (widths.max() ?? 0) + CGFloat(max(0, widths.count - 1)) * spacing
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? ideal
        return CGSize(width: width, height: frames(subviews, width: width).map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, rect) in zip(subviews, frames(subviews, width: bounds.width)) {
            view.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
    }
}

/// Full-size localized labels retain breathing room inside the existing capsule styles, including when wrapped.
struct AlongDoneButton: View {
    let title: LocalizedStringKey
    let primary: Bool
    let action: () -> Void

    private var label: some View {
        Text(title).fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
    }

    var body: some View {
        if primary {
            Button(action: action) { label }.buttonStyle(PrimaryButtonStyle())
        } else {
            Button(action: action) { label }.buttonStyle(SecondaryButtonStyle())
        }
    }
}

/// The notes after the next one, in order: tiles in their string's colour with the fret over the note name (a
/// fingerboard's finger, "↓2" for a low 2; just the note on pitch lanes). They slide along as each note is played,
/// their tiles fading toward the end of the rail while the figures and names stay at full strength (every string's
/// colour reads at 4.5:1 or more on its tile). Music reads left to right in every language, as the runway's lanes do,
/// so the rail never turns round in Arabic or Hebrew.
struct UpNextRail: View {
    let notes: [TimedNote]
    /// The first note on the rail (the one after "Next").
    let from: Int
    let fretted: Bool
    let strings: Int
    let accent: Color
    /// A violin's or cello's fingerboard: tiles show the finger, not a fret.
    var fingerboard: Fingerboard?
    static let length = 6

    private var shown: [Int] { from < notes.count ? Array(from..<min(notes.count, from + Self.length)) : [] }

    var body: some View {
        ChordFlowLayout(spacing: 8, lineSpacing: 8) {
            // VoiceOver skips the rail (the "Next" line says the note); the arrow is still named in words, never by its
            // symbol's name.
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
                .opacity(shown.isEmpty ? 0 : 1)
                .accessibilityLabel(Text("Next"))
                .frame(minHeight: 42)
            ForEach(shown, id: \.self) { index in
                tile(notes[index], rank: index - from)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .scale(scale: 0.6).combined(with: .opacity)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    /// The tile's figure: the fret, or a fingerboard's finger with its low or high arrow.
    private func figure(_ at: Fretting) -> String {
        guard let fingerboard else { return "\(at.fret)" }
        return FingerPlace(at, on: fingerboard).shortLabel
    }

    /// A tile fades with its rank (fill, edge and bar); its words never do: faded with it, the second string's blue
    /// would drop under 4.5:1 from the third tile on.
    private func tile(_ note: TimedNote, rank: Int) -> some View {
        let tint = color(note)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous)
        let fade = 1 - Double(rank) * 0.13
        return VStack(spacing: 0) {
            if fretted, let at = note.at {
                Text(verbatim: figure(at)).font(Typeface.number(.body)).foregroundStyle(Palette.ink)
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(.caption)).foregroundStyle(tint)
            } else {
                Text(NoteName.pitchClass(note.midi)).font(Typeface.label(15)).foregroundStyle(Palette.ink)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minWidth: 42, minHeight: 42)
        .background(shape.fill(tint.opacity(0.16 * fade)))
        .overlay(shape.strokeBorder(tint.opacity(0.55 * fade), lineWidth: 1))
        .overlay(alignment: .bottom) { Capsule().fill(tint.opacity(fade)).frame(width: 18, height: 3).offset(y: 1.5) }
    }

    private func color(_ note: TimedNote) -> Color {
        guard fretted, let at = note.at else { return accent }
        return HighwayRunway.color(string: at.string, of: strings)
    }
}

/// The take so far, under the stage while it plays: the grades counted, and a ribbon with a segment per note (per
/// chord, on a strummed take) that takes its grade's colour as it is judged (white-gold perfect, the course colour
/// good, amber late or early, coral missed); the note being waited for stands taller. A whole song is too many notes
/// for one row: past `window` notes the ribbon shows the stretch around the current note, a quarter of it already
/// played.
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
            // The take runs left to right in every language, as the runway and the rail above do.
            .environment(\.layoutDirection, .leftToRight)
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
                .contentTransition(HighwayHUD.digitTransition(value))
        }
        // A zero reads in the faint ink (4.5:1 and more), not as a dimmed colour.
        .foregroundStyle(value == 0 ? Palette.inkFaint : Self.color(grade, accent: accent))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(value, format: .number))
    }
}

#if DEBUG
/// The demo pitch plays each play-along note the moment it falls due, from a loop on the main thread. A stalled frame
/// (a runway drawn in software) only delays when that reading reaches the judge, so a demo take is judged at the
/// moment the note was due to sound, as a steady player would play it, not when the stalled frame got round to it.
@MainActor func demoJudgedTime(_ clock: Double, judge: PlayAlongJudge, store: AppStore, heard: Bool) -> Double {
    guard store.demoNoteDue != nil, heard, judge.nextIndex < judge.notes.count else { return clock }
    return min(clock, judge.time(of: judge.nextIndex) + 0.01)
}
#endif
