import QuartzCore
import SwiftUI
import TimbreCore

/// How a song's final take is played: its melody note by note on the runway, or its chords strummed change by change
/// with the words ("Chords & words"), the way most people play a song they sing.
enum SongTakeMode: String, CaseIterable, Identifiable {
    case melody
    case chords

    static let storageKey = "song.takeMode"
    var id: String { rawValue }
}

/// What a finished "Chords & words" take hands back to the performance: its score, and each chord strummed as a note
/// of the finale's timing strip.
struct ChordTakeResult {
    let accuracy: Double
    let points: Int
    let bestCombo: Int
    let grades: [PlayAlongJudge.Grade]
    let judgments: [PlayAlongJudge.Judgment]
    let sections: [TakeSection]
}

/// A strummed take's chords in playing order: every bar's downbeat and every change to another chord inside a bar,
/// each with its bar and its beat from the top of the take. Twinkle's first two bars ("C · G | D · G") are four.
struct ChordSlots {
    struct Slot {
        let bar: Int
        /// Beats from the top of the take.
        let beat: Double
        let chord: ChordSpec
    }

    /// Rising, one per beat at most: the chords `ChordAlongJudge` judges, in its order.
    let slots: [Slot]
    /// Each bar's slots, in order.
    let ofBar: [[Int]]

    init(bars: [ChordBar], meter: Int) {
        let length = Double(max(1, meter))
        var slots: [Slot] = []
        var ofBar: [[Int]] = []
        for (index, bar) in bars.enumerated() {
            var mine: [Int] = []
            for change in bar.changes where change.beat < length - 1e-6 {
                let beat = Double(index) * length + change.beat
                if let last = slots.last, beat - last.beat <= 1e-6 { continue }
                mine.append(slots.count)
                slots.append(Slot(bar: index, beat: beat, chord: change.chord))
            }
            ofBar.append(mine)
        }
        self.slots = slots
        self.ofBar = ofBar
    }

    var beats: [Double] { slots.map(\.beat) }
}

/// What a "Chords & words" take shows around its chords: the song's name and sleeve, its sections (the song map and
/// the finale's ribbon) and where each named part starts, for the eyebrow over the words. A song lesson's comes from
/// its song sheet (`of(_:in:)`); a chart the player brought makes its own (`ChartPracticeView`).
struct ChordTakeSheet {
    let title: String
    /// The sleeve beside the title; nil shows the chart glyph.
    let art: CoverArt?
    let sections: [SongSheet.Section]
    /// The song's bars, for the map.
    let bars: Int
    /// Where each named part starts, in beats from the top, with its name.
    let parts: [(beat: Double, name: String)]
    /// What the take is logged as when it starts.
    let event: String
    let properties: [String: String]

    /// The part playing at `beat` (the first through the count-in).
    func part(atBeat beat: Double) -> String? {
        parts.last { $0.beat <= beat + 1e-6 }?.name ?? parts.first?.name
    }

    /// A song lesson's: its sleeve, its song sheet's sections and its arrangement's parts.
    @MainActor static func of(_ lesson: Lesson, in course: LearnCourse) -> ChordTakeSheet {
        let sheet = SongSheet.of(lesson)
        var parts: [(beat: Double, name: String)] = []
        if let arrangement = lesson.arrangement {
            parts = arrangement.sections.map { (beat: arrangement.startBeat(of: $0), name: $0.name.localized) }
        }
        return ChordTakeSheet(title: CoverArt.mainTitle(lesson.title.localized), art: CoverArt.of(lesson, in: course),
                              sections: sheet.sections, bars: sheet.bars, parts: parts, event: "song_perform",
                              properties: ["lesson": lesson.id, "mode": SongTakeMode.chords.rawValue])
    }
}

/// "Chords & words": a song's final take strummed. The chart's chords come bar by bar over the band, the bar to play
/// now big (both its chords, "C · G", where it changes inside, the one sounding lit) with the next two bars beside it
/// and the beats of the bar under it, split where the chord changes; the words run below karaoke style. Every chord is
/// judged on its own first stroke for its timing and its chord (`ChordAlongJudge`), a half-bar change as much as a
/// downbeat: a wrong chord is named in amber ("Am?"), a chord with nothing heard is missed. The combo, the score, the
/// song map and the take's ribbon run as on the melody take. With VoiceOver each change of chord is named ahead of it
/// (`SpokenCueTiming`). Stop goes back to the stage.
struct SongChordsTake: View {
    let sheet: ChordTakeSheet
    let accent: Color
    let tempo: Double
    let beatsPerBar: Int
    /// The song's chords bar by bar from the top, each change inside a bar included.
    let bars: [ChordBar]
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
    /// Each stroke's time (host clock) and the chord it timed, until its sound comes in.
    @State private var strokes: [CFTimeInterval: Int] = [:]
    @State private var countInBeat: Int?
    /// The last chord whose change was named.
    @State private var named = -1
    private let plan: ChordSlots

    init(sheet: ChordTakeSheet, accent: Color, tempo: Double, beatsPerBar: Int, bars: [ChordBar], lyrics: LyricSheet,
         band: BandArrangement, spoken: Bool, finished: @escaping (ChordTakeResult) -> Void, stopped: @escaping () -> Void) {
        self.sheet = sheet
        self.accent = accent
        self.tempo = tempo
        self.beatsPerBar = max(1, beatsPerBar)
        self.bars = bars
        self.lyrics = lyrics
        self.band = band
        self.spoken = spoken
        self.finished = finished
        self.stopped = stopped
        let plan = ChordSlots(bars: bars, meter: beatsPerBar)
        self.plan = plan
        let length = Double(max(1, bars.count) * max(1, beatsPerBar))
        _judge = State(initialValue: ChordAlongJudge(beats: plan.beats, length: length, bpm: tempo, beatsPerBar: beatsPerBar))
    }

    private var spb: Double { 60 / max(20, tempo) }
    private var countIn: Double { Double(beatsPerBar) * spb }
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
            TakeRibbon(count: plan.slots.count, grades: judge.grades, current: currentSlot(CACurrentMediaTime()) ?? 0, accent: accent)
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
            cover.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: sheet.title).font(Typeface.display(.title3)).foregroundStyle(Palette.ink)
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

    /// The song's sleeve, or for a chart without one, the chart glyph on a tile.
    @ViewBuilder private var cover: some View {
        if let art = sheet.art {
            SongCover(art: art, corner: 6)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.14))
                .overlay { Glyph(.chart, size: Glyph.row, tint: accent) }
                .accessibilityHidden(true)
        }
    }

    /// The bar to play now, the two after it, the beats of the bar and the last chord's call, with the count-in over it
    /// and the combo in its top corners.
    private var stage: some View {
        TimelineView(.animation(paused: !running)) { _ in
            let now = CACurrentMediaTime()
            let time = clock(now)
            ZStack {
                ChordLane(bars: bars, plan: plan, bar: currentBar(now), slot: currentSlot(now), beat: beat(in: time), meter: beatsPerBar,
                          accent: accent, grades: judge.grades, calls: judge.calls, calm: reduceMotion)
                if time < 0 {
                    Text("\(Int(-time / spb) + 1)").font(Typeface.hero(96)).foregroundStyle(Palette.ink)
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

    /// The chord sounding now, as VoiceOver reads the stage.
    private var spokenNow: String {
        guard let slot = currentSlot(CACurrentMediaTime()), plan.slots.indices.contains(slot) else { return "" }
        return SongSheet.spoken(plan.slots[slot].chord)
    }

    private var lyricRow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { _ in
            let beat = running ? clock(CACurrentMediaTime()) / spb : nil
            HighwayLyrics(sheet: lyrics, beat: beat, accent: accent, section: sheet.part(atBeat: max(0, beat ?? 0)))
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// The bar under way (nil through the count-in and after the last).
    private func currentBar(_ now: CFTimeInterval) -> Int? {
        let time = clock(now)
        guard time >= 0 else { return nil }
        let bar = Int(time / judge.secondsPerBar)
        return bar < bars.count ? bar : nil
    }

    /// The chord sounding (its place in `plan`), on the same clock as the bar: nil through the count-in and after the
    /// last.
    private func currentSlot(_ now: CFTimeInterval) -> Int? {
        let time = clock(now)
        guard time >= 0, let index = judge.index(at: time + judge.latency), plan.slots.indices.contains(index) else { return nil }
        return index
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
        Analytics.log(sheet.event, sheet.properties)
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
        guard running, let index = judge.stroke(at: time - startTime - countIn) else { return }
        strokes[time] = index
    }

    private func rang(at time: CFTimeInterval, heard: ChordEstimate?) {
        guard running, let stroke = strokes.keys.min(by: { abs($0 - time) < abs($1 - time) }), abs(stroke - time) <= 0.05,
              let index = strokes.removeValue(forKey: stroke), plan.slots.indices.contains(index) else { return }
        let chord = plan.slots[index].chord
        let right = ChordTarget(root: chord.root, formulaId: chord.quality).map { target in heard?.matches(target) ?? false } ?? (heard != nil)
        react(judge.chord(index, right: right, heard: heard?.symbol, at: CACurrentMediaTime()))
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

    /// With VoiceOver: each change of chord named ahead of it ("E minor"), a half-bar change as much as a downbeat.
    private func nameNextChange(at time: Double) {
        let next = named + 1
        guard plan.slots.indices.contains(next), time >= judge.time(of: next) - SpokenCueTiming.lead(secondsPerBeat: spb) else { return }
        named = next
        let chord = plan.slots[next].chord
        if next == 0 || chord.symbol != plan.slots[next - 1].chord.symbol { SpokenCues.say(SongSheet.spoken(chord)) }
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
        let meter = Double(beatsPerBar)
        let sections = sheet.sections.map { part -> TakeSection in
            let from = Double(part.start) * meter, to = Double(part.start + part.bars) * meter
            return TakeSection(id: part.id, name: part.title?.localized ?? part.chord?.name ?? SongSectionMap.spoken(part),
                               start: part.start, bars: part.bars, score: judge.score(fromBeat: from, toBeat: to),
                               notes: judge.indices(fromBeat: from, toBeat: to).count, short: TakeSection.short(of: part))
        }
        finished(ChordTakeResult(accuracy: accuracy, points: judge.points, bestCombo: judge.bestCombo,
                                 grades: plan.slots.indices.map { judge.grades[$0] ?? .miss }, judgments: judge.judgments,
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

/// The chords as they come: the bar to play now, big, each of its chords in turn ("C · G" where it changes on beat 3:
/// the one sounding in ink, the one to come soft, the one played faint), over the beats of the bar (the one sounding
/// lit, a gap and a bigger dot where the chord changes), the next two bars beside it, smaller and dimmer as they get
/// further off. Under it, the last chord's call: a tick in mint, the chord that rang instead in amber ("Am?"), a cross
/// in coral for a chord missed. Music reads left to right in every language, so the lane never turns round.
struct ChordLane: View {
    let bars: [ChordBar]
    let plan: ChordSlots
    /// The bar under way; nil through the count-in (the first bar waits) and after the last.
    let bar: Int?
    /// The chord sounding, by its place in `plan`; nil through the count-in and after the last.
    let slot: Int?
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
                if bars.indices.contains(current) {
                    barLine
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .shadow(color: accent.opacity(0.45), radius: 18)
                        .contentTransition(calm ? .identity : .opacity)
                        .layoutPriority(1)
                }
                ForEach(1...2, id: \.self) { ahead in
                    if bars.indices.contains(current + ahead) {
                        Text(verbatim: bars[current + ahead].name)
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
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The bar's chords in one line, each toned by where the take is.
    private var barLine: Text {
        let slots = current < plan.ofBar.count ? plan.ofBar[current] : []
        var line = Text(verbatim: "")
        for (offset, index) in slots.enumerated() {
            if offset > 0 { line = line + Text(verbatim: " · ").foregroundStyle(Palette.inkFaint) }
            line = line + Text(verbatim: plan.slots[index].chord.name).foregroundStyle(tone(index, first: offset == 0))
        }
        return line.font(Typeface.display(.hero))
    }

    /// The chord sounding in ink, the ones to come soft, the ones played faint; before the take, the bar's first in ink.
    private func tone(_ index: Int, first: Bool) -> Color {
        guard let slot else { return first ? Palette.ink : Palette.inkSoft }
        if index == slot { return Palette.ink }
        return index < slot ? Palette.inkFaint : Palette.inkSoft
    }

    /// The beats (0 first) on which the chord changes inside the bar under way.
    private var changeBeats: Set<Int> {
        guard bars.indices.contains(current) else { return [] }
        return Set(bars[current].later.map { Int($0.beat.rounded(.down)) })
    }

    /// The bar's beats, the one sounding lit; where the chord changes, a gap and a bigger dot open its stretch.
    private var beats: some View {
        let starts = changeBeats
        return HStack(spacing: 10) {
            ForEach(0..<max(1, meter), id: \.self) { index in
                Circle()
                    .fill(index == beat ? accent : Palette.inkFaint.opacity(0.35))
                    .frame(width: index == 0 || starts.contains(index) ? 12 : 9, height: index == 0 || starts.contains(index) ? 12 : 9)
                    .padding(.leading, index > 0 && starts.contains(index) ? 10 : 0)
            }
        }
        .frame(height: 14)
    }

    /// How the chord before the one sounding went.
    @ViewBuilder private var call: some View {
        let last = (slot ?? 0) - 1
        Group {
            if slot != nil, last >= 0, let grade = grades[last] {
                switch grade {
                case .miss:
                    Label("Missed", systemImage: "xmark").foregroundStyle(Palette.danger)
                case .ok where calls[last] != nil:
                    Text(verbatim: (calls[last] ?? "") + "?").foregroundStyle(Palette.amber)
                case .ok:
                    Label("Early/late", systemImage: "clock").foregroundStyle(Palette.amber)
                case .perfect, .good:
                    Label(plan.slots.indices.contains(last) ? plan.slots[last].chord.name : "", systemImage: "checkmark")
                        .foregroundStyle(Palette.mint)
                }
            } else {
                Text(verbatim: " ")
            }
        }
        .font(Typeface.label(.body))
        .frame(height: 22)
        .transition(.opacity)
    }
}
