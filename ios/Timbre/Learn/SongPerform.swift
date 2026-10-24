import QuartzCore
import SwiftUI
import TimbreCore

/// The last step of a song lesson, played as a performance: the whole song in one take over the band. First the
/// stage (the sleeve under a light with its record turning, the song map, the tempo: the song's own, or 75 % for at
/// most two stars), then the take, on the play-along's own runway and judge (`HighwayRunway`, `HighwayCanvas`,
/// `PlayAlongJudge`) with its count-in and combo HUD, a running score (each note's credit times the combo
/// multiplier) and the song map's playhead, then the finale (`SongFinaleView`): the lesson's stars, the score, the
/// timing strip and a story-sized poster. The best take at the song's tempo counts, as in every play-along.
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
    /// The runway's lanes follow the diagrams' string order (Settings › String order).
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    @State private var owner = UUID()
    @State private var phase = Phase.stage
    @State private var ladder: TempoLadder
    @State private var judge: PlayAlongJudge
    @State private var grades: [Int: PlayAlongJudge.Grade] = [:]
    /// The grades of the take that counts (the ladder's outcome).
    @State private var countedGrades: [Int: PlayAlongJudge.Grade] = [:]
    @State private var hitTimes: [Int: CFTimeInterval] = [:]
    @State private var offsets: [Int: Double] = [:]
    @State private var startTime: CFTimeInterval = 0
    @State private var trail: [(CFTimeInterval, Double)] = []
    @State private var lastLevel = -120.0
    @State private var lastOnset: CFTimeInterval = 0
    @State private var points = 0
    /// When the multiplier last stepped up (×2, ×3, ×4): the board's new colour rolls up it from the hit line.
    @State private var tierUp: CFTimeInterval?
    @State private var take: SongTake?
    @State private var bestPercent: Int?
    @State private var calibrating = false

    enum Phase { case stage, playing, finale }

    init(notes: [TimedNote], bpm: Double, beatsPerBar: Int, lesson: Lesson, course: LearnCourse, accent: Color,
         onItem: @escaping (PracticeItem, Double) -> Void = { _, _ in }, onStarCap: @escaping (Int) -> Void = { _ in },
         projectedStars: @escaping (Double, Int?) -> Int = { _, _ in 1 }, done: @escaping (Double?) -> Void) {
        let sorted = notes.sorted { $0.beat < $1.beat }
        self.notes = sorted
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
        _judge = State(initialValue: PlayAlongJudge(notes: sorted, bpm: bpm, anyOctave: course.anyOctave))
    }

    private var tempo: Double { ladder.tempo }
    private var spb: Double { 60 / tempo }
    private var countIn: Double { Double(beatsPerBar) * spb }
    private var fretted: Bool { course.fretKind != nil && notes.allSatisfy { $0.at != nil } }
    private var multiplier: Int { ComboBadge.multiplier(judge.combo) }
    private var lookahead: Double { HighwayRunway.lookahead(secondsPerBeat: spb, beatsPerBar: beatsPerBar) }
    /// Drums and a bass in the song's key, as under every play-along (no band bass when the player is the bass).
    private var band: BandArrangement {
        .melody(notes, bpm: tempo, beatsPerBar: beatsPerBar, reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }
    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private var songTitle: String { CoverArt.mainTitle(lesson.title.localized) }

    var body: some View {
        ZStack {
            switch phase {
            case .stage:
                stageView.transition(.opacity)
            case .playing:
                takeView.transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.03)), removal: .opacity))
            case .finale:
                finaleView.transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear { store.audio.prepareBand(band) }
        .onChange(of: ladder.rung) { _, _ in store.audio.prepareBand(band) }
        .onDisappear {
            store.audio.stopMetronome(); store.audio.stopBand(); store.stopLessonListening(owner: owner)
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
                Text(verbatim: songTitle).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text("The whole song, start to finish, with the band.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text("\(Int(tempo)) BPM · \(notes.count) notes").font(Typeface.label(13)).foregroundStyle(accent)
                    .contentTransition(.numericText(value: tempo))
                    .animation(reduceMotion ? nil : Motion.quick, value: tempo)
            }
            .padding(.horizontal, 24)
            SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent, height: 44)
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
            MicrophoneHint()
            tempoChoice
            StepButton(title: "Perform", accent: accent) { start() }
        }
    }

    private var stageHeader: some View {
        HStack(spacing: 8) {
            Label("Final take", systemImage: "music.mic").font(Typeface.label(12)).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(accent).lineLimit(1)
            Spacer(minLength: 8)
            CalibrateButton(audio: store.audio, accent: accent) { calibrating = true }
            BandControls(audio: store.audio, accent: accent)
        }
        .padding(.horizontal, 22).padding(.top, 8)
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

    /// The song's tempo (three stars) or 75 % of it (two at most).
    private var tempoChoice: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                tempoButton(TempoLadder.lessonRung, label: "Full tempo")
                tempoButton(0, label: "Slower")
            }
            Label("Full tempo for 3 stars", systemImage: "star.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.amber)
                .opacity(ladder.isFullTempo ? 0 : 1)
                .accessibilityHidden(ladder.isFullTempo)
        }
        .padding(.horizontal, 20)
        .animation(reduceMotion ? nil : Motion.pluck, value: ladder.rung)
    }

    private func tempoButton(_ rung: Int, label: LocalizedStringKey) -> some View {
        let selected = ladder.rung == rung
        let full = rung >= TempoLadder.lessonRung
        let tint = full ? accent : Palette.amber
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            .overlay(shape.strokeBorder(selected ? Color.clear : Palette.line, lineWidth: 1))
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
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: phase != .playing)) { _ in
                SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent,
                               progress: songProgress(CACurrentMediaTime()), height: 34)
            }
            .padding(.horizontal, 20)
            TakeRibbon(count: notes.count, grades: grades, current: judge.nextIndex, accent: accent)
            Spacer(minLength: 0)
            LessonBarButton(title: "Stop") { stopTake() }
                .padding(.horizontal, 20).padding(.bottom, 12)
                .accessibilityIdentifier("song.stop")
        }
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
                Text(points, format: .number).font(Typeface.number(26, relativeTo: .title2)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(points)))
                    .animation(reduceMotion ? nil : Motion.quick, value: points)
                Text("Score").font(Typeface.label(11)).tracking(1.2).textCase(.uppercase).foregroundStyle(accent)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 22).padding(.top, 8)
    }

    /// The play-along's stage: the runway (pitch lanes without a neck), the count-in over it, the combo HUD.
    private var runwayStage: some View {
        TimelineView(.animation(paused: phase != .playing)) { _ in
            let now = CACurrentMediaTime()
            // Seconds since beat 0 on the heard clock (negative during the count-in).
            let clock = now - startTime - countIn
            ZStack {
                runway(elapsed: runwayElapsed(now: now), now: now)
                if clock < 0 {
                    Text("\(Int(-clock / spb) + 1)").font(Typeface.note(96)).foregroundStyle(Palette.ink)
                        .shadow(color: accent.opacity(0.6), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: Int(now * 20)) { _, _ in tick(now: now) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Play-along, \(notes.count) notes"))
        .frame(minHeight: 240, maxHeight: fretted ? 460 : 340)
        .overlay(alignment: .top) { HighwayHUD(combo: judge.combo, calm: reduceMotion) }
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.stageDeep))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 12)
        .layoutPriority(1)
    }

    /// The fretboard runway on fretted courses, pitch lanes otherwise.
    @ViewBuilder private func runway(elapsed: Double, now: CFTimeInterval) -> some View {
        if fretted {
            HighwayRunway(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: now,
                          strings: course.stringCount, beatsPerBar: beatsPerBar, heat: multiplier, calm: reduceMotion,
                          order: stringOrder, offsets: offsets, tierUp: tierUp)
        } else {
            HighwayCanvas(notes: notes, secondsPerBeat: spb, elapsed: elapsed, grades: grades, hitTimes: hitTimes, now: now,
                          lanes: 0, accent: accent, trail: trail, startTime: startTime + countIn, calm: reduceMotion, offsets: offsets)
        }
    }

    /// The first notes wait near the line before the start, then glide back to where the count-in puts them.
    private func runwayElapsed(now: CFTimeInterval) -> Double {
        let preview = -0.2 * lookahead
        let actual = now - startTime - countIn
        let t = max(0, now - startTime) / 0.5
        guard !reduceMotion, t < 1 else { return actual }
        let eased = 1 - pow(1 - t, 3)
        return preview + (actual - preview) * eased
    }

    /// How far into the song the take is (0 through the count-in).
    private func songProgress(_ now: CFTimeInterval) -> Double {
        let duration = judge.duration
        guard duration > 0 else { return 0 }
        return min(1, max(0, (now - startTime - countIn) / duration))
    }

    // MARK: The finale

    @ViewBuilder private var finaleView: some View {
        if let take {
            SongFinaleView(take: take, lesson: lesson, course: course, accent: accent,
                           stars: projectedStars(take.accuracy, take.full ? nil : TempoLadder.slowStarCap),
                           best: bestPercent, slower: slowerAction, slowerTempo: Int(ladder.tempo(at: 0)),
                           again: { start() }, proceed: { complete() })
        }
    }

    /// After a weak take at the song's tempo: the same song at 75 %.
    private var slowerAction: (() -> Void)? {
        guard let take, take.full, take.accuracy < 0.6 else { return nil }
        return { ladder.select(0); start() }
    }

    // MARK: Flow

    private func start() {
        judge = PlayAlongJudge(notes: notes, bpm: tempo, anyOctave: course.anyOctave)
        grades = [:]; hitTimes = [:]; offsets = [:]; trail = []; points = 0; tierUp = nil
        startTime = CACurrentMediaTime()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.settle) { phase = .playing }
        Haptics.shared.selection()
        Analytics.log("song_perform", ["lesson": lesson.id, "tempo": String(ladder.percent)])
        store.audio.setMetronome(bpm: Int(tempo), beats: beatsPerBar, subdivision: 1, accents: true)
        // The band rides the metronome from the bar after the count-in (headphones only; else the click).
        store.audio.playBand(band, firstBar: 1)
        store.gameTargetHz = notes.first.map { PitchMath.frequency(midi: Double($0.midi), reference: store.settings.referencePitchHz) }
        #if DEBUG
        store.demoNoteDue = { judge.nextIndex < notes.count && CACurrentMediaTime() - startTime - countIn >= judge.time(of: judge.nextIndex) - 0.02 }
        #endif
        // Re-attacks of a repeated note come from the onset detector (a jump in loudness as a fallback).
        let analyzer = LessonAnalyzer(chords: false, onOnset: { time in lastOnset = time })
        store.startLessonListening(owner: owner, analyzer: analyzer) { hz, level in
            let now = CACurrentMediaTime()
            let heard = HeardNote(hz: hz, reference: store.settings.referencePitchHz)
            let onset = (level - lastLevel > 6 && level > -50) || now - lastOnset < 0.12
            lastLevel = level
            if let heard, !fretted {
                trail.append((now, Double(heard.midi) + heard.cents / 100))
                if trail.count > 240 { trail.removeFirst(60) }
            }
            apply(judge.update(time: now - startTime - countIn, midi: heard?.midi, cents: heard?.cents, onset: onset), now: now)
        }
    }

    private func tick(now: CFTimeInterval) {
        guard phase == .playing else { return }
        // Notes and judging follow the heard clock (the first click as it reached the ears), not the tap.
        if let heard = store.audio.heardStart(near: startTime) { startTime = heard }
        apply(judge.update(time: now - startTime - countIn, midi: nil, cents: nil), now: now)
        if judge.isFinished || now - startTime - countIn > judge.duration + 1.2 { finish() }
    }

    private func apply(_ judgments: [PlayAlongJudge.Judgment], now: CFTimeInterval) {
        for j in judgments {
            grades[j.index] = j.grade
            hitTimes[j.index] = now
            if let offset = j.offset { offsets[j.index] = offset }
            if j.grade != .miss { points += Int((PlayAlongJudge.credit(j.grade) * 100).rounded()) * multiplier }
            if j.grade == .perfect { Haptics.shared.selection() }
        }
        // The multiplier steps up at 4, 8 and 16 in a row: a firmer tap with the HUD's pulse, and the board's
        // colour rolls up to the next tier.
        if let last = judgments.last, last.grade == .perfect || last.grade == .good {
            switch judge.combo {
            case 4, 8, 16:
                Haptics.shared.beat(accent: true)
                tierUp = now
            default: break
            }
        }
        if !judgments.isEmpty, judge.nextIndex < notes.count {
            store.gameTargetHz = PitchMath.frequency(midi: Double(notes[judge.nextIndex].midi), reference: store.settings.referencePitchHz)
        }
        if judge.isFinished { finish() }
    }

    private func finish() {
        guard phase == .playing else { return }
        let accuracy = judge.accuracy
        // The take that counts keeps its grades for the lesson's weak spots.
        if ladder.improvesOutcome(accuracy) { countedGrades = grades }
        // The stage keeps the tempo chosen: a great take doesn't move it on as the practice ladder does.
        let rung = ladder.rung
        ladder.record(accuracy: accuracy)
        ladder.select(rung)
        // A good take ends on the band's final chord; otherwise it fades with the click.
        store.audio.finishBand(celebrate: accuracy >= 0.7)
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        bestPercent = ladder.outcome.map { Int(($0.score * 100).rounded()) }
        take = SongTake(accuracy: accuracy, points: points, bestCombo: judge.bestCombo,
                        grades: notes.indices.map { grades[$0] ?? .miss }, judgments: judge.judgments,
                        notes: notes.count, tempo: Int(tempo), full: ladder.isFullTempo)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.settle) { phase = .finale }
        if accuracy >= 0.7 { SoundFX.shared.play(.complete) }
        Haptics.shared.done()
    }

    /// Stop mid-take: back to the stage, nothing counted.
    private func stopTake() {
        guard phase == .playing else { return }
        store.audio.stopMetronome()
        store.audio.stopBand()
        store.stopLessonListening(owner: owner)
        #if DEBUG
        store.demoNoteDue = nil
        #endif
        store.audio.prepareBand(band)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.settle) { phase = .stage }
    }

    /// Continue: the best take at the song's tempo or faster counts; only slower takes cap the lesson's stars.
    private func complete() {
        let outcome = ladder.outcome
        if let cap = outcome?.starCap { onStarCap(cap) }
        for (index, note) in notes.enumerated() {
            onItem(course.practiceItem(for: note), PlayAlongJudge.credit(countedGrades[index] ?? .miss))
        }
        done(outcome?.score ?? judge.accuracy)
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
        if case let .progression(_, _, _, bpm, _) = step { return Int(bpm.rounded()) }
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
