import QuartzCore
import SwiftUI
import TimbreCore

/// How a song's final take is played: its melody note by note on the runway, or its chords strummed bar by bar with
/// the words ("Chords & words"), the way most people play a song they sing.
enum SongTakeMode: String, CaseIterable, Identifiable {
    case melody
    case chords

    static let storageKey = "song.takeMode"
    var id: String { rawValue }
}

/// What a finished "Chords & words" take hands back to the performance: its score, and each bar as a note of the
/// finale's timing strip.
struct ChordTakeResult {
    let accuracy: Double
    let points: Int
    let bestCombo: Int
    let grades: [PlayAlongJudge.Grade]
    let judgments: [PlayAlongJudge.Judgment]
    let sections: [TakeSection]
}

/// "Chords & words": a song's final take strummed. The chart's chords come bar by bar over the band, the one to play
/// now big with the next two beside it and the beats of the bar under it, the words running below karaoke style, and
/// each bar judged on its first stroke for its timing and its chord (`ChordAlongJudge`): a wrong chord is named in
/// amber ("Am?"), a bar with nothing heard is missed. The combo, the score, the song map and the take's ribbon run as
/// on the melody take. With VoiceOver each change of chord is named a beat ahead. Stop goes back to the stage.
struct SongChordsTake: View {
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    let tempo: Double
    let beatsPerBar: Int
    /// The chord of each bar from the top of the song.
    let chords: [ChordSpec]
    let lyrics: LyricSheet
    let band: BandArrangement
    let spoken: Bool
    let finished: (ChordTakeResult) -> Void
    let stopped: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var judge: ChordAlongJudge
    @State private var startTime: CFTimeInterval = 0
    @State private var running = false
    @State private var ownsClick = false
    /// Each stroke's time (host clock) and the bar it timed, until its chord comes in.
    @State private var strokes: [CFTimeInterval: Int] = [:]
    @State private var countInBeat: Int?
    /// The last bar whose change of chord was named.
    @State private var named = -1

    init(lesson: Lesson, course: LearnCourse, accent: Color, tempo: Double, beatsPerBar: Int, chords: [ChordSpec], lyrics: LyricSheet,
         band: BandArrangement, spoken: Bool, finished: @escaping (ChordTakeResult) -> Void, stopped: @escaping () -> Void) {
        self.lesson = lesson
        self.course = course
        self.accent = accent
        self.tempo = tempo
        self.beatsPerBar = max(1, beatsPerBar)
        self.chords = chords
        self.lyrics = lyrics
        self.band = band
        self.spoken = spoken
        self.finished = finished
        self.stopped = stopped
        _judge = State(initialValue: ChordAlongJudge(bars: chords.count, bpm: tempo, beatsPerBar: beatsPerBar))
    }

    private var spb: Double { 60 / max(20, tempo) }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private func clock(_ now: CFTimeInterval) -> Double { now - startTime - countIn }

    var body: some View {
        VStack(spacing: 12) {
            header
            stage
            if !lyrics.isEmpty { lyricRow }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { _ in
                SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent,
                               progress: progress(CACurrentMediaTime()), height: 34)
            }
            .padding(.horizontal, Metrics.gutter)
            TakeRibbon(count: chords.count, grades: judge.grades, current: currentBar(CACurrentMediaTime()) ?? 0, accent: accent)
            Spacer(minLength: 0)
            LessonBarButton(title: "Stop") { stop() }
                .background { StopKey { stop() } }
                .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
                .accessibilityIdentifier("song.stop")
        }
        .onAppear { begin() }
        .onChange(of: scenePhase) { _, now in if now == .background { stop() } }
        .onDisappear { leave() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            SongCover(art: art, corner: 6).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: CoverArt.mainTitle(lesson.title.localized)).font(Typeface.display(20)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("Chords & words · \(Int(tempo)) BPM").font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(judge.points, format: .number).font(Typeface.number(.title)).foregroundStyle(Palette.ink)
                    .contentTransition(HighwayHUD.digitTransition(judge.points))
                    .animation(reduceMotion ? nil : Motion.quick, value: judge.points)
                Eyebrow("Score", color: accent, style: .display)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 8)
    }

    /// The chord to play now, the two after it, the beats of the bar and the last bar's call, with the count-in over it
    /// and the combo in its top corners.
    private var stage: some View {
        TimelineView(.animation(paused: !running)) { _ in
            let now = CACurrentMediaTime()
            let time = clock(now)
            ZStack {
                ChordLane(chords: chords, bar: currentBar(now), beat: beat(in: time), meter: beatsPerBar, accent: accent,
                          grades: judge.grades, calls: judge.calls, calm: reduceMotion)
                if time < 0 {
                    Text("\(Int(-time / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                        .shadow(color: accent.opacity(0.6), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: Int(now * 20)) { _, _ in tick(now) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Chords & words"))
        .accessibilityValue(Text(verbatim: spokenNow))
        .frame(minHeight: 220, maxHeight: 340)
        .overlay(alignment: .top) { HighwayHUD(combo: judge.combo, calm: reduceMotion) }
        .background(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).fill(Palette.stageDeep))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous))
        .padding(.horizontal, 12)
        .layoutPriority(1)
    }

    /// The chord now, as VoiceOver reads the stage.
    private var spokenNow: String {
        guard let bar = currentBar(CACurrentMediaTime()), chords.indices.contains(bar) else { return "" }
        return SongSheet.spoken(chords[bar])
    }

    private var lyricRow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { _ in
            let beat = running ? clock(CACurrentMediaTime()) / spb : nil
            HighwayLyrics(sheet: lyrics, beat: beat, accent: accent, section: section(atBeat: beat))
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func section(atBeat beat: Double?) -> String? {
        guard let arrangement = lesson.arrangement else { return nil }
        return arrangement.section(atBeat: max(0, beat ?? 0))?.name.localized
    }

    /// The bar under way (nil through the count-in and after the last).
    private func currentBar(_ now: CFTimeInterval) -> Int? {
        let time = clock(now)
        guard time >= 0 else { return nil }
        let bar = Int(time / judge.secondsPerBar)
        return bar < chords.count ? bar : nil
    }

    /// The beat of the bar under way, 0 first.
    private func beat(in time: Double) -> Int? {
        guard time >= 0 else { return nil }
        let within = time.truncatingRemainder(dividingBy: judge.secondsPerBar)
        return min(beatsPerBar - 1, Int(within / spb))
    }

    private func progress(_ now: CFTimeInterval) -> Double {
        guard judge.duration > 0 else { return 0 }
        return min(1, max(0, clock(now) / judge.duration))
    }

    // MARK: Flow

    private func begin() {
        guard !running else { return }
        startTime = CACurrentMediaTime()
        running = true
        BandFeel.shared.reset(duck: spoken)
        if spoken { Earcons.shared.prepare() }
        Analytics.log("song_perform", ["lesson": lesson.id, "mode": SongTakeMode.chords.rawValue])
        store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)
        ownsClick = true
        store.audio.playBand(band, firstBar: 1)
        // Each stroke is timed as it is heard; its chord follows a quarter second later, from the same stroke.
        let analyzer = LessonAnalyzer(chords: false, strokes: true,
                                      onOnset: { time in strummed(at: time) },
                                      onStroke: { time, heard in rang(at: time, heard: heard) })
        store.startLessonListening(owner: owner, lowHz: 60, highHz: 1400, analyzer: analyzer) { _, _ in }
    }

    private func strummed(at time: CFTimeInterval) {
        guard running, let bar = judge.stroke(at: time - startTime - countIn) else { return }
        strokes[time] = bar
    }

    private func rang(at time: CFTimeInterval, heard: ChordEstimate?) {
        guard running, let stroke = strokes.keys.min(by: { abs($0 - time) < abs($1 - time) }), abs(stroke - time) <= 0.05,
              let bar = strokes.removeValue(forKey: stroke), chords.indices.contains(bar) else { return }
        let chord = chords[bar]
        let right = ChordTarget(root: chord.root, formulaId: chord.quality).map { target in heard?.matches(target) ?? false } ?? (heard != nil)
        react(judge.chord(bar: bar, right: right, heard: heard?.symbol, at: CACurrentMediaTime()))
    }

    private func tick(_ now: CFTimeInterval) {
        guard running else { return }
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        let time = clock(now)
        let since = now - startTime
        let beat: Int? = since >= 0 && since < countIn ? min(beatsPerBar - 1, Int(since / spb)) : nil
        if beat != countInBeat {
            countInBeat = beat
            if let beat { TakeFeedback.countIn(beat) }
        }
        if spoken { nameNextChange(at: time) }
        react(judge.tick(at: time, now: now))
        if judge.isFinished || time > judge.duration + 1 { finish() }
    }

    /// With VoiceOver: each change of chord named a beat before its bar ("E minor").
    private func nameNextChange(at time: Double) {
        let next = named + 1
        guard chords.indices.contains(next), time >= judge.time(of: next) - spb else { return }
        named = next
        if next == 0 || chords[next].symbol != chords[next - 1].symbol { SpokenCues.say(SongSheet.spoken(chords[next])) }
    }

    private func react(_ update: PlayAlongSession.Update) {
        guard !update.isEmpty else { return }
        TakeFeedback.react(update, combo: judge.combo, spoken: spoken)
        if update.finished { finish() }
    }

    private func finish() {
        guard running else { return }
        running = false
        let accuracy = judge.accuracy
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        BandFeel.shared.reset()
        ownsClick = false
        store.stopLessonListening(owner: owner)
        let sections = sheet.sections.map { part in
            TakeSection(id: part.id, name: part.title?.localized ?? part.chord?.name ?? SongSectionMap.spoken(part),
                        start: part.start, bars: part.bars, score: judge.score(bars: part.start..<(part.start + part.bars)))
        }
        finished(ChordTakeResult(accuracy: accuracy, points: judge.points, bestCombo: judge.bestCombo,
                                 grades: chords.indices.map { judge.grades[$0] ?? .miss }, judgments: judge.judgments,
                                 sections: sections))
    }

    /// Stop (or the app went to the background): the click, the band and the microphone stop; nothing counts.
    private func stop() {
        guard running else { return }
        running = false
        tearDown()
        stopped()
    }

    /// Leaving mid-take (the lesson closed): as Stop, without going back to the stage. After a take the final chord
    /// rings on.
    private func leave() {
        guard running else { return }
        running = false
        tearDown()
    }

    private func tearDown() {
        if ownsClick && store.audio.metronomeRunning && !store.audio.metronomeOwnedByTool { store.audio.stopMetronome() }
        ownsClick = false
        store.audio.stopBand()
        BandFeel.shared.reset()
        store.stopLessonListening(owner: owner)
    }
}

/// The chords as they come: the one to play now, big, in the course colour, over the beats of its bar (the one
/// sounding lit), the next two beside it, smaller and dimmer as they get further off. Under it, the last bar's call:
/// a tick in mint, the chord that rang instead in amber ("Am?"), a cross in coral for a bar missed.
struct ChordLane: View {
    let chords: [ChordSpec]
    /// The bar under way; nil through the count-in (the first chord waits) and after the last.
    let bar: Int?
    let beat: Int?
    let meter: Int
    let accent: Color
    let grades: [Int: PlayAlongJudge.Grade]
    let calls: [Int: String]
    var calm = false

    private var current: Int { bar ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline, spacing: 18) {
                if chords.indices.contains(current) {
                    Text(verbatim: chords[current].name)
                        .font(Typeface.display(72, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                        .shadow(color: accent.opacity(0.45), radius: 18)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .contentTransition(calm ? .identity : .opacity)
                }
                ForEach(1...2, id: \.self) { ahead in
                    if chords.indices.contains(current + ahead) {
                        Text(verbatim: chords[current + ahead].name)
                            .font(Typeface.display(ahead == 1 ? .title : .title3))
                            .foregroundStyle(Palette.inkSoft.opacity(ahead == 1 ? 1 : 0.7))
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
            }
            .animation(calm ? nil : Motion.quick, value: current)
            beats
            call
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// The bar's beats, the one sounding lit.
    private var beats: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(1, meter), id: \.self) { index in
                Circle()
                    .fill(index == beat ? accent : Palette.inkFaint.opacity(0.35))
                    .frame(width: index == 0 ? 12 : 9, height: index == 0 ? 12 : 9)
            }
        }
        .frame(height: 14)
    }

    /// How the bar before went.
    @ViewBuilder private var call: some View {
        let last = current - 1
        Group {
            if bar != nil, last >= 0, let grade = grades[last] {
                switch grade {
                case .miss:
                    Label("Missed", systemImage: "xmark").foregroundStyle(Palette.danger)
                case .ok where calls[last] != nil:
                    Text(verbatim: (calls[last] ?? "") + "?").foregroundStyle(Palette.amber)
                case .ok:
                    Label("Early/late", systemImage: "clock").foregroundStyle(Palette.amber)
                case .perfect, .good:
                    Label(chords.indices.contains(last) ? chords[last].name : "", systemImage: "checkmark").foregroundStyle(Palette.mint)
                }
            } else {
                Text(verbatim: " ")
            }
        }
        .font(Typeface.label(15))
        .frame(height: 22)
        .transition(.opacity)
    }
}
