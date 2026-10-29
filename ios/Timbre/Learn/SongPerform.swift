import QuartzCore
import SwiftUI
import TimbreCore

/// The last step of a song lesson, played as a performance: the whole song in one take over the band, which plays
/// the song's own chords (its chart) change by change, thins to drums and bass on a miss and crashes in at ×4. First the
/// stage (the sleeve under a light with its record turning, the song map, the tempo: the song's own, or 75 % for at
/// most two stars), then the take, on the play-along's own runway and session (`HighwayRunway`, `HighwayCanvas`,
/// `PlayAlongSession`) with its count-in and combo HUD, a running score (each note's credit times the combo
/// multiplier), the words under the runway karaoke style (`HighwayLyrics`, with the section playing) and the song
/// map's playhead, then the finale (`SongFinaleView`): the lesson's stars, the score, the timing strip with each
/// section's score under it, and a story-sized poster. The best take at the song's tempo counts, as in every
/// play-along. With VoiceOver, spoken cues name each note ahead of it (`SpokenCues.Timing`) and the result is read out.
/// On a strummed instrument a song with a chart can be performed as "Chords & words" instead (`SongChordsTake`): its
/// chords strummed change by change with the words ("C · G" where a bar changes on its third beat), judged for timing
/// and chord.
struct SongPerformStep: View {
    let notes: [TimedNote]
    let bpm: Double
    let beatsPerBar: Int
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    /// How each note went in the take that counts (for the lesson's weak spots).
    var onItem: (PracticeItem, Double) -> Void
    /// Finished only below the song's tempo: the lesson's stars are capped.
    var onStarCap: (Int) -> Void
    /// The lesson's stars if this step ends with a score (and a star cap, for a slower take).
    var projectedStars: (Double, Int?) -> Int
    let done: (Double?) -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var phase = Phase.stage
    @State private var ladder: TempoLadder
    /// The take under way, or the last one.
    @State private var session: PlayAlongSession
    #if DEBUG
    /// An actual rendered take timestamp, held only for explicitly requested still captures.
    /// Scores, grades, lyrics and runway all stay at this same state; releases and videos never hold.
    @State private var captureTime: CFTimeInterval?
    @State private var capturedFirstTick = false
    #endif

    private var captureIsHeld: Bool {
        #if DEBUG
        return captureTime != nil
        #else
        return false
        #endif
    }

    private var performanceTime: CFTimeInterval {
        #if DEBUG
        if let captureTime { return captureTime }
        #endif
        return CACurrentMediaTime()
    }

    /// The grades of the take that counts (the ladder's outcome).
    @State private var countedGrades: [Int: PlayAlongJudge.Grade] = [:]
    /// The take that counts was strummed ("Chords & words"): it says nothing about the melody's notes.
    @State private var countedChords = false
    /// The take under way is strummed.
    @State private var playingChords = false
    @AppStorage(SongTakeMode.storageKey) private var takeMode: SongTakeMode = .melody
    @State private var take: SongTake?
    /// How each section of the song went in the last take, for the finale.
    @State private var sections: [TakeSection] = []
    @State private var bestPercent: Int?
    @State private var calibrating = false
    /// The take started the click (so leaving stops it, unless the Metronome tool has taken it over since).
    @State private var ownsClick = false
    @State private var audioStart = AudioStartGate()
    /// The count-in beat last felt.
    @State private var countInBeat: Int?
    /// When the take's spoken cues are said.
    @State private var cueTiming = SpokenCues.Timing()
    /// The last attack heard while "Start on first strum" waits.
    @State private var armedOnset: CFTimeInterval = 0
    @AppStorage(StrumStart.storageKey) private var strumChoice: Bool?
    @AppStorage(SpokenCues.storageKey) private var spokenChoice: Bool?
    /// How the player holds the instrument: a left-hander's lanes run mirrored.
    @CurrentHand private var hand
    /// The song's words by line, from the notes' syllables (empty for an instrumental).
    private let lyrics: LyricSheet

    enum Phase { case stage, playing, finale }

    init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, lesson: Lesson, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, onStarCap: @escaping (Int) -> Void = { _ in },
         projectedStars: @escaping (Double, Int?) -> Int = { _, _ in 1 }, done: @escaping (Double?) -> Void) {
        let sorted = notes.sorted { $0.beat < $1.beat }
        self.notes = sorted
        self.lyrics = LyricSheet(notes: sorted)
        self.bpm = bpm
        self.beatsPerBar = max(1, beatsPerBar)
        self.lesson = lesson
        self.course = course
        self.accent = accent
        self.onItem = onItem
        self.onStarCap = onStarCap
        self.projectedStars = projectedStars
        self.done = done
        _ladder = State(initialValue: TempoLadder(bpm: bpm))
        let fretted = course.fretKind != nil && sorted.allSatisfy { $0.at != nil }
        _session = State(initialValue: PlayAlongSession(notes: sorted, bpm: bpm, beatsPerBar: beatsPerBar, anyOctave: course.anyOctave,
                                                        keepsTrail: !fretted))
    }

    private var tempo: Double { ladder.tempo }
    private var spb: Double { 60 / tempo }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    /// A violin's or cello's fingerboard: its notes read as fingers, not frets.
    private var board: Fingerboard? { fretted ? Fingerboard(instrument: course.instrument) : nil }
    private var multiplier: Int { session.multiplier }
    private var lookahead: Double { HighwayRunway.lookahead(secondsPerBeat: spb, beatsPerBar: beatsPerBar) }
    /// Spoken cues: on while VoiceOver runs, unless turned off.
    private var spoken: Bool { voiceOver && (spokenChoice ?? true) }
    /// "Start on first strum": the player's choice, else on while VoiceOver runs (where the microphone can hear).
    private var strumStarts: Bool { StrumStart.offered && (strumChoice ?? voiceOver) }
    private var strumBinding: Binding<Bool> {
        Binding(get: { strumStarts }, set: { strumChoice = $0 })
    }
    /// Listening for the first note on the stage.
    private var armed: Bool { strumStarts && phase == .stage }
    /// The band on the song's own chords from its chart, change by change (a bar that changes on its third beat changes
    /// under the melody there too); drums and a bass in its key when the chart names none; no band bass when the player
    /// is the bass.
    private var band: BandArrangement {
        let bars = chartBars
        return SongPlayback.band(take: notes, harmony: bars.isEmpty ? nil : bars, bpm: tempo, meter: beatsPerBar,
                                 reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }
    /// The chart's chords for every bar from the top of the song, each change inside a bar included.
    private var chartBars: [ChordBar] {
        let chart = LeadChart.of(lesson)
        return chart.hasChords ? chart.filledBars(from: 0, count: chart.bars) : []
    }
    /// "Chords & words" is offered: a strummed instrument, and a chart with chords.
    private var chordsAvailable: Bool { course.strums && LeadChart.of(lesson).hasChords }
    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private var songTitle: String { CoverArt.mainTitle(lesson.title.localized) }

    var body: some View {
        ZStack {
            switch phase {
            case .stage:
                stageView.transition(.opacity)
            case .playing:
                if playingChords {
                    chordsView.transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)), removal: .opacity))
                } else {
                    takeView.transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)), removal: .opacity))
                }
            case .finale:
                finaleView.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear {
            store.audio.prepareBand(band)
            arm()
        }
        #if DEBUG
        // A store scene (Root/DemoScenes.swift) performs the song by itself, from a chosen bar.
        .task {
            guard let beat = DemoScene.performBeat(lesson, beatsPerBar: beatsPerBar),
                  await DemoScene.waitForPerformCue() else { return }
            try? await Task.sleep(for: DemoScene.performDelay)
            if !Task.isCancelled { startScene(atBeat: beat) }
        }
        #endif
        .onChange(of: ladder.rung) { _, _ in store.audio.prepareBand(band) }
        .onChange(of: armed) { _, _ in arm() }
        // A take can't go on in the pocket: the app going to the background ends it, nothing counted.
        .onChange(of: scenePhase) { _, now in if now == .background { stopTake() } }
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

    // MARK: The stage

    private var stageView: some View {
        VStack(spacing: 16) {
            stageHeader
            Spacer(minLength: 0)
            spotlitSleeve
            VStack(spacing: 6) {
                Text(verbatim: songTitle).font(Typeface.display(.title)).tracking(-0.6).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text("The whole song, start to finish, with the band.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(Typeface.label(13)).foregroundStyle(accent)
                    .contentTransition(.numericText(value: tempo))
                    .animation(reduceMotion ? nil : Motion.quick, value: tempo)
            }
            .padding(.horizontal, Metrics.gutter)
            SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent, height: 44)
                .padding(.horizontal, Metrics.gutter)
            Spacer(minLength: 0)
            if armed { StrumToStartHint(accent: accent).transition(.opacity) }
            MicrophoneHint()
            if chordsAvailable { modeChoice }
            tempoChoice
            StepButton(title: "Perform") { start() }
        }
        .animation(reduceMotion ? nil : Motion.quick, value: armed)
    }

    private var stageHeader: some View {
        HStack(spacing: 8) {
            Label { Eyebrow("Final take", color: accent, style: .display) } icon: { Image(systemName: "music.mic") }
                .font(Typeface.eyebrowDisplay).foregroundStyle(accent).lineLimit(1)
            Spacer(minLength: 8)
            if StrumStart.offered { StrumStartToggle(isOn: strumBinding, accent: accent, listening: armed) }
            CalibrateButton(audio: store.audio, accent: accent) { calibrating = true }
            // "Chords & words" is judged on its strokes: there the speaker keeps to the click.
            BandControls(audio: store.audio, accent: accent, speaker: takeMode == .chords && chordsAvailable ? .click : .drums)
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 8)
    }

    /// The sleeve under a pool of light, its record out and turning: the song is on.
    private var spotlitSleeve: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [accent.opacity(0.32), .clear], center: .center, startRadius: 4, endRadius: 160))
                .frame(width: 320, height: 110)
                .offset(y: 90)
            SongCover(art: art, corner: 12)
                .frame(width: 164, height: 164)
                .shadow(color: art.primary.opacity(0.45), radius: 26, y: 14)
                .background(alignment: .trailing) {
                    VinylRecord(color: art.primary, spinning: !reduceMotion)
                        .frame(width: 150, height: 150)
                        .offset(x: 52)
                }
                .offset(x: -26)
        }
        .frame(height: 196)
        .accessibilityHidden(true)
    }

    /// The melody on the runway, or the chords with the words.
    private var modeChoice: some View {
        HStack(spacing: 8) {
            modeButton(.melody, label: "Melody", symbol: "music.note")
            modeButton(.chords, label: "Chords & words", symbol: "guitars")
        }
        .padding(.horizontal, Metrics.gutter)
        .animation(reduceMotion ? nil : Motion.pluck, value: takeMode)
    }

    private func modeButton(_ mode: SongTakeMode, label: LocalizedStringKey, symbol: String) -> some View {
        let selected = takeMode == mode
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button {
            guard takeMode != mode else { return }
            takeMode = mode
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                Text(label).font(Typeface.label(15)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(shape.fill(selected ? AnyShapeStyle(accent.opacity(0.18)) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(shape.strokeBorder(selected ? accent.opacity(0.6) : Palette.controlLine, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("song.mode.\(mode.rawValue)")
    }

    /// The song's tempo (three stars) or 75 % of it (two at most).
    private var tempoChoice: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                tempoButton(TempoLadder.lessonRung, label: "Full tempo")
                tempoButton(0, label: "Slower")
            }
            Label("Full tempo for 3 stars", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.starGold)
                .opacity(ladder.isFullTempo ? 0 : 1)
                .accessibilityHidden(ladder.isFullTempo)
        }
        .padding(.horizontal, Metrics.gutter)
        .animation(reduceMotion ? nil : Motion.pluck, value: ladder.rung)
    }

    private func tempoButton(_ rung: Int, label: LocalizedStringKey) -> some View {
        let selected = ladder.rung == rung
        let full = rung >= TempoLadder.lessonRung
        let tint = full ? accent : Palette.amber
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button {
            guard ladder.rung != rung else { return }
            ladder.select(rung)
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: full ? "star.fill" : "tortoise.fill").font(.system(size: 12, weight: .bold))
                Text(label).font(Typeface.label(15)).lineLimit(1).minimumScaleFactor(0.75)
                Text(Int(ladder.tempo(at: rung)), format: .number).font(Typeface.number(12)).opacity(0.75)
            }
            .foregroundStyle(selected ? Palette.onAccent : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(shape.fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(shape.strokeBorder(selected ? Color.clear : Palette.controlLine, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("song.tempo.\(rung)")
    }

    // MARK: The take

    private var takeView: some View {
        VStack(spacing: 12) {
            takeHeader
            runwayStage
            if !lyrics.isEmpty {
                lyricRow
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: phase != .playing || captureIsHeld)) { _ in
                SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent,
                               progress: songProgress(performanceTime), height: 34)
            }
            .padding(.horizontal, Metrics.gutter)
            TakeRibbon(count: notes.count, grades: session.grades, current: session.nextIndex, accent: accent)
            Spacer(minLength: 0)
            LessonBarButton(title: "Stop") { stopTake() }
                .background { StopKey { stopTake() } }
                .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
                .accessibilityIdentifier("song.stop")
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if let captureTime {
                Text(verbatim: String(session.clock(at: captureTime) / spb))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.clear)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "Capture held"))
                    .accessibilityValue(Text(verbatim: String(session.clock(at: captureTime) / spb)))
                    .accessibilityIdentifier("performance.capture.frozen")
            }
        }
        #endif
    }

    /// The sleeve, the title and tempo, and the score counting up.
    private var takeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            SongCover(art: art, corner: 6).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: songTitle).font(Typeface.display(20)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(session.points, format: .number).font(Typeface.number(.title)).foregroundStyle(Palette.ink)
                    .contentTransition(HighwayHUD.digitTransition(session.points))
                    .animation(reduceMotion ? nil : Motion.quick, value: session.points)
                Eyebrow("Score", color: accent, style: .display)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("performance.score")
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 8)
    }

    /// The play-along's stage: the runway (pitch lanes without a neck), the count-in over it, the combo HUD.
    private var runwayStage: some View {
        TimelineView(.animation(paused: phase != .playing || captureIsHeld)) { _ in
            let now = performanceTime
            // Seconds since beat 0 on the heard clock (negative during the count-in).
            let clock = session.clock(at: now)
            ZStack {
                runway(elapsed: session.runwayClock(at: now, waiting: -0.2 * lookahead, glide: !reduceMotion), now: now)
                if clock < 0 {
                    Text("\(Int(-clock / spb) + 1)").font(Typeface.hero(96)).foregroundStyle(Palette.ink)
                        .shadow(color: accent.opacity(0.6), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
        }
        .modifier(RunwayAccessibility(label: Text("Play-along, \(notes.count) notes"), value: runwayValue, spoken: spoken,
                                      canSpeak: voiceOver) { spokenChoice = !spoken })
        .frame(minHeight: 240, maxHeight: fretted ? 460 : 340)
        .overlay(alignment: .top) { HighwayHUD(combo: session.combo, calm: reduceMotion) }
        .background(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).fill(Palette.stageDeep))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous))
        .padding(.horizontal, 12)
        .layoutPriority(1)
    }

    /// What VoiceOver reads on the runway while the take plays: the note coming up.
    private var runwayValue: Text {
        let index = session.nextIndex
        guard notes.indices.contains(index) else { return Text(verbatim: "") }
        return Text("Next: \(NotePlace.spoken(notes[index], fretted: fretted, board: board))")
    }

    /// The words under the runway: the line being sung lit syllable by syllable, the next one dim, and over them the
    /// section playing ("Verse 2"). Before the first word, the first line waits.
    private var lyricRow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: phase != .playing || captureIsHeld)) { _ in
            let beat = lyricBeat(performanceTime)
            HighwayLyrics(sheet: lyrics, beat: beat, accent: accent, section: sectionName(atBeat: beat),
                          sectionStartBar: lesson.arrangement?.section(atBeat: max(0, beat ?? 0))?.bar)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// Where the take is, in beats from the song's first bar (nil before it starts, negative through the count-in).
    private func lyricBeat(_ now: CFTimeInterval) -> Double? {
        guard phase == .playing else { return nil }
        return session.clock(at: now) / spb
    }

    /// The section of the arrangement playing (the first through the count-in).
    private func sectionName(atBeat beat: Double?) -> String? {
        guard let arrangement = lesson.arrangement else { return nil }
        return arrangement.section(atBeat: max(0, beat ?? 0))?.name.localized
    }

    /// The fretboard runway on fretted courses (mirrored for a left-hander), pitch lanes otherwise. The first notes
    /// wait near the line before the start, then glide back to where the count-in puts them.
    @ViewBuilder private func runway(elapsed: Double, now: CFTimeInterval) -> some View {
        if fretted {
            HighwayRunway(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: session.grades, hitTimes: session.hitTimes,
                          now: now, strings: course.stringCount, beatsPerBar: beatsPerBar, heat: multiplier, calm: reduceMotion,
                          mirrored: hand.mirrorsUpright, offsets: session.offsets, tierUp: session.tierUp, fingerboard: board)
        } else {
            HighwayCanvas(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: session.grades, hitTimes: session.hitTimes,
                          now: now, lanes: 0, accent: accent, trail: session.trail, startTime: session.startTime + session.countIn,
                          calm: reduceMotion, offsets: session.offsets)
        }
    }

    /// How far into the song the take is (0 through the count-in).
    private func songProgress(_ now: CFTimeInterval) -> Double { session.progress(at: now) }

    // MARK: Chords & words

    private var chordsView: some View {
        SongChordsTake(sheet: ChordTakeSheet.of(lesson, in: course), accent: accent, tempo: tempo, beatsPerBar: beatsPerBar,
                       bars: chartBars, lyrics: lyrics, band: band, spoken: spoken,
                       finished: { result in finishChords(result) },
                       stopped: {
                           store.audio.prepareBand(band)
                           withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .stage }
                       })
    }

    // MARK: The finale

    @ViewBuilder private var finaleView: some View {
        if let take {
            SongFinaleView(take: take, lesson: lesson, course: course, accent: accent,
                           stars: projectedStars(take.accuracy, take.full ? nil : TempoLadder.slowStarCap),
                           best: bestPercent, slower: slowerAction, slowerTempo: Int(ladder.tempo(at: 0)),
                           again: { start() }, proceed: { complete() })
                // Each section's score under the timing strip.
                .environment(\.takeSections, sections)
        }
    }

    /// After a weak take at the song's tempo: the same song at 75 %.
    private var slowerAction: (() -> Void)? {
        guard let take, take.full, take.accuracy < 0.6 else { return nil }
        return { ladder.select(0); start() }
    }

    // MARK: Flow

    /// Perform: the melody on the runway, or the chords with the words when that is the take chosen (and offered).
    private func start() {
        if takeMode == .chords && chordsAvailable {
            startChords()
        } else {
            startMelody()
        }
    }

    /// The strummed take runs itself (`SongChordsTake`, from the moment it is on screen).
    private func startChords() {
        playingChords = true
        countInBeat = nil
        withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .playing }
        Haptics.shared.selection()
    }

    private func startMelody(afterReady: (() -> Void)? = nil) {
        guard !audioStart.isPending else { return }
        let requestedTempo = tempo
        playingChords = false
        ownsClick = true
        audioStart.begin(store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)) {
            startMelodyReady(tempo: requestedTempo)
            afterReady?()
        }
    }

    private func startMelodyReady(tempo: Double) {
        #if DEBUG
        captureTime = nil
        capturedFirstTick = false
        #endif
        playingChords = false
        session = PlayAlongSession(notes: notes, bpm: tempo, beatsPerBar: beatsPerBar, anyOctave: course.anyOctave, keepsTrail: !fretted)
        session.begin(at: CACurrentMediaTime())
        cueTiming = SpokenCues.Timing(session)
        countInBeat = nil
        withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .playing }
        Haptics.shared.selection()
        BandFeel.shared.reset(duck: spoken)
        if spoken { Earcons.shared.prepare() }
        Analytics.log("song_perform", ["lesson": lesson.id, "tempo": String(ladder.percent)])
        // The band rides the metronome from the bar after the count-in (in full in headphones, its drums on the speaker).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = notes.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        #if DEBUG
        store.demoNoteDue = { session.nextIndex < notes.count && session.clock(at: CACurrentMediaTime()) >= session.judge.time(of: session.nextIndex) - 0.02 }
        #endif
        // Re-attacks of a repeated note come from the onset detector (a jump in loudness as a fallback).
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in
            guard !captureIsHeld else { return }
            session.onset(at: time)
        })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            guard phase == .playing, !captureIsHeld else { return }
            let now = CACurrentMediaTime()
            let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            var clock = session.clock(at: now)
            #if DEBUG
            clock = demoJudgedTime(clock, judge: session.judge, store: store, heard: heard != nil)
            #endif
            react(session.hear(midi: heard?.midi, cents: heard?.cents, level: level, at: now, clock: clock))
        }
    }

    /// "Start on first strum": on the stage the microphone listens, and a note of the song played on the instrument
    /// (an attack, then its pitch) starts the take. Off again once it starts or the switch is off.
    private func arm() {
        guard armed else {
            if phase == .stage { store.stopLessonListening(owner: owner) }
            return
        }
        let wanted = StrumStart.pitchClasses(notes)
        armedOnset = 0
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in armedOnset = time })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            guard armed, phase == .stage, !audioStart.isPending, level > -50, CACurrentMediaTime() - armedOnset < 0.3,
                  let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz),
                  wanted.contains(PitchMath.pitchClass(midi: heard.midi)) else { return }
            start()
        }
    }

    private func tick(now: CFTimeInterval) {
        guard phase == .playing, !captureIsHeld else { return }
        #if DEBUG
        if !capturedFirstTick, DemoScene.current == .songPerform, TestSupport.isOn(.sceneStill) {
            capturedFirstTick = true
            DemoScene.performDiagnostic("first-rendered-tick", beat: session.clock(at: now) / spb)
        }
        #endif
        // Notes and judging follow the heard clock (the first click as it reached the ears), not the tap.
        if let heard = store.audio.heardStart(near: session.startTime) { session.follow(start: heard) }
        let beat = session.countInBeat(at: now)
        if beat != countInBeat {
            countInBeat = beat
            if let beat { TakeFeedback.countIn(beat) }
        }
        if spoken, let cue = cueTiming.due(at: session.clock(at: now)) { speak(cue, now: now) }
        react(session.tick(at: now))
        #if DEBUG
        if phase == .playing, let hold = DemoScene.captureHoldBeat(beatsPerBar: beatsPerBar),
           session.clock(at: now) / spb >= hold {
            // Stop input first at the actual timestamp, without rewriting a note, grade or score.
            captureTime = now
            DemoScene.performDiagnostic("capture-frozen", beat: session.clock(at: now) / spb)
            store.demoNoteDue = nil
            store.stopLessonListening(owner: owner)
            store.audio.stopBand()
            if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool {
                store.audio.stopMetronome()
            }
            ownsClick = false
        }
        #endif
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
        if !update.judgments.isEmpty, session.nextIndex < notes.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(notes[session.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if update.finished { finish() }
    }

    private func finish() {
        guard phase == .playing, !playingChords else { return }
        let accuracy = session.accuracy
        // The take that counts keeps its grades for the lesson's weak spots.
        if ladder.improvesOutcome(accuracy) {
            countedGrades = session.grades
            countedChords = false
        }
        // The stage keeps the tempo chosen: a great take doesn't move it on as the practice ladder does.
        let rung = ladder.rung
        ladder.record(accuracy: accuracy)
        ladder.select(rung)
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        BandFeel.shared.reset()
        ownsClick = false
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        bestPercent = ladder.outcome.map { Int(($0.score * 100).rounded()) }
        let points = session.points
        sections = scoredSections()
        take = SongTake(accuracy: accuracy, points: points, bestCombo: session.judge.bestCombo,
                        grades: notes.indices.map { session.grades[$0] ?? .miss }, judgments: session.judge.judgments,
                        notes: notes.count, tempo: Int(tempo), full: ladder.isFullTempo)
        // A whole take at the song's own tempo goes to Game Center: a featured song's board (and any challenge on it),
        // and "Challenge a friend" on the results. Slower takes never count there.
        if ladder.isFullTempo { GameCenter.shared.performed(lesson: lesson.id, points: points, notes: notes.count) }
        withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .finale }
        if accuracy >= 0.7 { SoundFX.shared.play(.complete) }
        Haptics.shared.done()
        if voiceOver {
            let result = SpokenCues.result(hits: session.hits, of: notes.count, perfect: session.count(.perfect),
                                           percent: Int((accuracy * 100).rounded()))
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                if phase == .finale { SpokenCues.say(result) }
            }
        }
    }

    /// A strummed take ended: the same finale, its bars as the timing strip's notes. It counts toward the lesson's
    /// stars as a melody take does, but not toward the melody's weak spots, and not on Game Center's boards.
    private func finishChords(_ result: ChordTakeResult) {
        guard phase == .playing, playingChords else { return }
        let accuracy = result.accuracy
        if ladder.improvesOutcome(accuracy) {
            countedGrades = [:]
            countedChords = true
        }
        let rung = ladder.rung
        ladder.record(accuracy: accuracy)
        ladder.select(rung)
        bestPercent = ladder.outcome.map { Int(($0.score * 100).rounded()) }
        sections = result.sections
        take = SongTake(accuracy: accuracy, points: result.points, bestCombo: result.bestCombo, grades: result.grades,
                        judgments: result.judgments, notes: result.grades.count, tempo: Int(tempo), full: ladder.isFullTempo)
        withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .finale }
        if accuracy >= 0.7 { SoundFX.shared.play(.complete) }
        Haptics.shared.done()
        if voiceOver {
            let hits = result.grades.filter { $0 != .miss }.count
            let perfect = result.grades.filter { $0 == .perfect }.count
            let said = SpokenCues.result(hits: hits, of: result.grades.count, perfect: perfect, percent: Int((accuracy * 100).rounded()))
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                if phase == .finale { SpokenCues.say(said) }
            }
        }
    }

    /// The song's sections as the take went: each one's notes (an upbeat it is sung from included) scored as the
    /// play-along scores a take.
    private func scoredSections() -> [TakeSection] {
        let parts = sheet.sections
        let meter = Double(max(1, beatsPerBar))
        return parts.enumerated().map { index, part in
            let from = Double(part.start) * meter - (part.part?.pickup ?? 0)
            let next = index + 1 < parts.count ? parts[index + 1] : nil
            let to = next.map { Double($0.start) * meter - ($0.part?.pickup ?? 0) } ?? .infinity
            let name = part.title?.localized ?? part.chord?.name ?? SongSectionMap.spoken(part)
            let count = notes.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }.count
            return TakeSection(id: part.id, name: name, start: part.start, bars: part.bars,
                               score: session.score(fromBeat: from, toBeat: to), notes: count, short: TakeSection.short(of: part))
        }
    }

    /// Stop mid-take (or the app went to the background): back to the stage, nothing counted, except as a try in a
    /// Game Center challenge on the song that is going on (its points so far). The click stops if the take started it
    /// and the Metronome tool hasn't taken it over.
    private func stopTake() {
        let starting = audioStart.isPending
        audioStart.cancel()
        // A strummed take stops itself (`SongChordsTake`).
        guard phase == .playing || starting, !playingChords else { return }
        if ladder.isFullTempo { GameCenter.shared.performStopped(lesson: lesson.id, points: session.points, notes: notes.count) }
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        BandFeel.shared.reset()
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        store.audio.prepareBand(band)
        withMotion(Motion.settle, reduceMotion: reduceMotion) { phase = .stage }
    }

    /// Continue: the best take at the song's tempo or faster counts; only slower takes cap the lesson's stars.
    private func complete() {
        let outcome = ladder.outcome
        if let cap = outcome?.starCap { onStarCap(cap) }
        if !countedChords {
            for (index, note) in notes.enumerated() {
                onItem(course.practiceItem(for: note), PlayAlongJudge.credit(countedGrades[index] ?? .miss))
            }
        }
        done(outcome?.score ?? session.accuracy)
    }
}

/// A song that ends on a chord progression: its strum take as every lesson plays it (`RhythmStep`, through
/// `StepView`), then the same finale as a played-along song: its stars, its score and its poster.
struct SongEncoreStep: View {
    let step: LessonStep
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    var onPractice: () -> Void = {}
    var onItem: (PracticeItem, Double) -> Void = { _, _ in }
    var onStarCap: (Int) -> Void = { _ in }
    var projectedStars: (Double, Int?) -> Int = { _, _ in 1 }
    let done: (Double?) -> Void
    @State private var take: SongTake?
    @State private var best: Double?
    @State private var attempt = 0

    private var tempo: Int {
        if case let .progression(_, _, _, bpm, _, _, _) = step { return Int(bpm.rounded()) }
        return 0
    }

    var body: some View {
        ZStack {
            if let take {
                SongFinaleView(take: take, lesson: lesson, course: course, accent: accent, stars: projectedStars(best ?? take.accuracy, nil),
                               best: best.map { Int(($0 * 100).rounded()) },
                               again: { withAnimation(Motion.settle) { self.take = nil; attempt += 1 } },
                               proceed: { done(best ?? take.accuracy) })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                StepView(step: step, course: course, accent: accent, onPractice: onPractice, onItem: onItem, onStarCap: onStarCap,
                         done: { score in finished(score) })
                    .id(attempt)
                    .transition(.opacity)
            }
        }
    }

    private func finished(_ score: Double?) {
        let accuracy = max(0, min(1, score ?? 0))
        best = max(best ?? 0, accuracy)
        withAnimation(Motion.settle) {
            take = SongTake(accuracy: accuracy, points: nil, bestCombo: nil, grades: [], judgments: [], notes: 0, tempo: tempo, full: true)
        }
    }
}

#if DEBUG
extension SongPerformStep {
    /// The `song-perform` store scene (Root/DemoScenes.swift): the take starts `beat` beats into the song. Its clock
    /// moves on to there and every note before it is judged as the demo pitch plays them, on time, so the combo, the
    /// score, the ribbon, the words and the song map stand where a clean take would; the demo pitch plays on from there,
    /// and the band joins at the song's own bar.
    fileprivate func startScene(atBeat beat: Double) {
        guard phase == .stage else { return }
        DemoScene.performDiagnostic("start-requested", beat: beat)
        startMelody { startSceneReady(atBeat: beat) }
    }

    private func startSceneReady(atBeat beat: Double) {
        DemoScene.performDiagnostic("audio-ready", beat: session.clock(at: CACurrentMediaTime()) / spb)
        // The clock starts a bar before `beat`: the first frames after a jump this size (the runway's first draw of the
        // whole song, the band starting) can hold the main thread for a second, and a note due then would be a miss.
        // The readiness callback runs after output is ready and the take's clock has started.
        let lead = Double(max(1, beatsPerBar))
        let from = max(0, beat - lead)
        session.skip(session.countIn + from * spb)
        // The click's first bar is the song's bar `from` starts: the band plays that bar there.
        store.audio.playBand(band, firstBar: -Int((from / lead).rounded()))
        let now = CACurrentMediaTime()
        for _ in notes.indices {
            let index = session.nextIndex
            guard index < session.notes.count, session.notes[index].beat < beat else { break }
            session.onset(at: now)
            react(session.hear(midi: session.notes[index].midi, cents: 0, level: -20, at: now, clock: session.judge.time(of: index)))
            if session.nextIndex == index { break }
        }
    }
}
#endif
