import XCTest
@testable import TimbreCore

final class CoachNotesTests: XCTestCase {
    private let em = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0])
    private let c = ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    /// 15:06 UTC, so records an hour before "n days ago" stay on that day.
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func note(_ midi: Int) -> PracticeItem { .note(midi: midi, at: nil) }
    private func timed(_ midi: Int) -> TimedNote { TimedNote(midi: midi, beat: 0, beats: 1) }
    private func lesson(_ id: String, _ steps: [LessonStep]) -> Lesson {
        Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: 3, xp: 20, free: true, steps: steps)
    }
    private func result(_ id: String, stars: Int, accuracy: Double, items: [ItemScore] = []) -> LessonResult {
        LessonResult(lessonId: id, stars: stars, accuracy: accuracy, xp: 20, minutes: 4, items: items)
    }
    private func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400 - 3_600) }

    /// Em, C, Em, C a bar each at 60 BPM, on time except the change into C, 410 ms late both times.
    private func lateIntoC() throws -> CoachTake {
        var offsets: [Int: Double] = [:]
        for stroke in 0..<16 where stroke != 4 && stroke != 12 { offsets[stroke] = 0.02 }
        return try XCTUnwrap(CoachTake.strummed(chords: [em, c, em, c], bars: [1, 1, 1, 1], pattern: [0, 1, 2, 3], beatsPerBar: 4, bpm: 60,
                                                offsets: offsets, strays: [4: 0.41, 12: 0.41]))
    }

    // MARK: After a lesson

    func testALateChordChangeLeadsWithItsTempo() throws {
        let progression = lesson("g-2-3", [.progression(chords: [em, c], bars: [1, 1], pattern: [0, 1, 2, 3], bpm: 60, beatsPerBar: 4)])
        let context = Coach.LessonContext(lesson: progression, courseId: "guitar",
                                          result: result("g-2-3", stars: 2, accuracy: 0.8, items: [ItemScore(item: .chord(c), score: 0.7)]),
                                          takes: [try lateIntoC()], canReview: true)
        let notes = Coach.lessonNotes(context)
        XCTAssertEqual(notes.first?.fact, .change(from: .chord(em), to: .chord(c), milliseconds: 410, beat: 1, missed: 0, count: 2, bpm: 60))
        XCTAssertEqual(notes.first?.action, .metronome(bpm: 45), "one rung down the ladder")
        XCTAssertEqual(notes.first?.tone, .fix)
        XCTAssertEqual(notes.dropFirst().first?.fact, .slipped(items: [.chord(c)], percent: 70))
        XCTAssertEqual(notes.dropFirst().first?.action, .review(courseId: "guitar"))
        XCTAssertEqual(notes.count, 2)
    }

    func testTappedRhythmSaysNothingAboutTiming() throws {
        let progression = lesson("g-2-3", [.progression(chords: [em, c], bars: [1, 1], pattern: [0, 1, 2, 3], bpm: 60, beatsPerBar: 4)])
        let context = Coach.LessonContext(lesson: progression, courseId: "guitar", result: result("g-2-3", stars: 1, accuracy: 0.8),
                                          takes: [try lateIntoC()], tapped: true)
        XCTAssertFalse(Coach.lessonNotes(context).contains { $0.topic == .timing })
    }

    func testNotesAgainstChordsNamesTheWeakSkill() {
        let items = [ItemScore(item: note(64), score: 0.95), ItemScore(item: note(67), score: 0.93),
                     ItemScore(item: .chord(em), score: 0.6), ItemScore(item: .chord(c), score: 0.7)]
        let notes = Coach.lessonNotes(Coach.LessonContext(lesson: lesson("a", []), courseId: "guitar",
                                                          result: result("a", stars: 2, accuracy: 0.8, items: items), canReview: true))
        XCTAssertEqual(notes.first?.fact, .split(strong: .notes, strongPercent: 94, weak: .chords, weakPercent: 65))
        XCTAssertEqual(notes.first?.action, .review(courseId: "guitar"))
        // The chords that slipped, weakest first, and only chords (the notes were fine).
        XCTAssertEqual(notes.dropFirst().first?.fact, .slipped(items: [.chord(em), .chord(c)], percent: 60))
    }

    func testOnlyOneKindOfItemIsNamedTogether() {
        let items = [ItemScore(item: note(64), score: 0.4), ItemScore(item: .chord(em), score: 0.5), ItemScore(item: note(67), score: 0.7)]
        let notes = Coach.lessonNotes(Coach.LessonContext(lesson: lesson("a", []), courseId: "guitar",
                                                          result: result("a", stars: 1, accuracy: 0.5, items: items)))
        XCTAssertEqual(notes.first?.fact, .slipped(items: [note(64), note(67)], percent: 40))
        XCTAssertNil(notes.first?.action, "no drill to offer")
    }

    func testAFullTempoTakeIsWhatStandsBetweenItAndThreeStars() {
        let along = lesson("g-1-4", [.playAlong(notes: [timed(64)], bpm: 80, beatsPerBar: 4, title: nil)])
        let items = [ItemScore(item: note(64), score: 0.95), ItemScore(item: note(67), score: 0.92), ItemScore(item: note(71), score: 0.96)]
        let notes = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar",
                                                          result: result("g-1-4", stars: 2, accuracy: 0.93, items: items), canReview: true))
        XCTAssertEqual(notes.first?.fact, .belowTempo(percent: 93, bpm: 80))
        XCTAssertEqual(notes.first?.action, .lesson(id: "g-1-4"))
        XCTAssertEqual(notes.dropFirst().first?.fact, .clean(items: 3), "and every note came out clean")
        XCTAssertEqual(notes.dropFirst().first?.tone, .praise)
        XCTAssertNil(notes.dropFirst().first?.action)
        // Three stars: nothing to chase, only the praise.
        let full = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result("g-1-4", stars: 3, accuracy: 0.93, items: items)))
        XCTAssertEqual(full.map(\.fact), [.clean(items: 3)])
    }

    /// The open strings (E2 A2 D3 G3 B3 E4) played along at 80 BPM, on the beat except the move from D3 into G3,
    /// `late` seconds behind it.
    private func openStrings(late: Double) -> CoachTake {
        let hits = [40, 45, 50, 55, 59, 64].enumerated().map { index, midi in
            CoachHit(item: note(midi), beat: Double(index), offset: midi == 55 ? late : 0.01)
        }
        return CoachTake(kind: .melody, hits: hits, bpm: 80, beatsPerBar: 4)
    }

    func testAFlawlessRunGetsTheNextLevelNotAFix() {
        let along = lesson("g-1-1", [.playAlong(notes: [timed(40)], bpm: 80, beatsPerBar: 4, title: nil)])
        let items = [40, 45, 50, 55, 59, 64].map { ItemScore(item: note($0), score: 0.98) }
        let takes = [openStrings(late: 0.2), openStrings(late: 0.2)]
        // "Flawless · 98 %": the late move is the next level to reach, praised in the accent, with no slower tempo to drill.
        let flawless = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result("g-1-1", stars: 3, accuracy: 0.98, items: items),
                                                             takes: takes, canReview: true))
        XCTAssertEqual(flawless.first?.fact, .nextLevel(from: note(50), to: note(55), milliseconds: 200, beat: 4))
        XCTAssertEqual(flawless.first?.tone, .praise)
        XCTAssertNil(flawless.first?.action)
        XCTAssertEqual(flawless.dropFirst().first?.fact, .clean(items: 6), "and the clean run after it")
        XCTAssertFalse(flawless.contains { $0.tone == .fix })
        // Something that slipped is no fix to make under "Flawless" either.
        let slipped = items + [ItemScore(item: note(52), score: 0.5)]
        let quiet = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result("g-1-1", stars: 3, accuracy: 0.98, items: slipped),
                                                          takes: takes, canReview: true))
        XCTAssertEqual(quiet.map(\.fact), [.nextLevel(from: note(50), to: note(55), milliseconds: 200, beat: 4)])
        // "Great work" at 95 %: the same take is a fix, with the tempo to practise the move at.
        let great = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result("g-1-1", stars: 3, accuracy: 0.95, items: items),
                                                          takes: takes, canReview: true))
        XCTAssertEqual(great.first?.fact, .change(from: note(50), to: note(55), milliseconds: 200, beat: 4, missed: 0, count: 2, bpm: 80))
        XCTAssertEqual(great.first?.action, .metronome(bpm: 60))
        XCTAssertEqual(great.first?.tone, .fix)
    }

    /// Review 13's results: four clean steps and a 50 % "Keep going" play-along used to average 90 % into three stars
    /// and "Great work", under a coach note that a move didn't land. The final take now holds the lesson at two stars,
    /// the coach never blames the tempo for it, and its specific fix leads.
    func testAKeepGoingPlayAlongHoldsTheStarsAndTheCoachAgrees() {
        let quiz = LessonStep.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)
        let along = lesson("g-1-2", [quiz, quiz, quiz, quiz, .playAlong(notes: [timed(40)], bpm: 80, beatsPerBar: 4, title: nil)])
        var run = LessonRun(lesson: along, now: now)
        for _ in 0..<4 { run.complete(score: 1) }
        run.complete(score: 0.5)
        let result = run.result(now: now.addingTimeInterval(180))
        XCTAssertEqual(result.stars, 2)
        XCTAssertFalse(Coach.isFlawless(result))

        // Nothing more specific to say: the take to beat, with the lesson to play again.
        let plain = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result))
        XCTAssertEqual(plain.first?.fact, .finalTake(percent: 50, needed: 90))
        XCTAssertEqual(plain.first?.action, .lesson(id: "g-1-2"))
        XCTAssertEqual(plain.first?.tone, .fix)
        XCTAssertFalse(plain.contains { $0.topic == .tempo }, "90 % overall, but the tempo isn't what held it back")

        // A move that never landed says how to get there, so it leads; the take to beat follows.
        let missed = [40, 45, 50, 55].enumerated().map { index, midi in
            CoachHit(item: note(midi), beat: Double(index), offset: midi == 55 ? nil : 0.01)
        }
        let take = CoachTake(kind: .melody, hits: missed, bpm: 80, beatsPerBar: 4)
        let notes = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: result, takes: [take]))
        XCTAssertEqual(notes.first?.topic, .timing)
        XCTAssertEqual(notes.first?.tone, .fix)
        XCTAssertEqual(notes.dropFirst().first?.fact, .finalTake(percent: 50, needed: 90))

        // A Great work take at a slower tempo is still the tempo's note, not the take's.
        var slow = LessonRun(lesson: along, now: now)
        for _ in 0..<4 { slow.complete(score: 1) }
        slow.capStars(TempoLadder.slowStarCap)
        slow.complete(score: 0.95)
        let capped = Coach.lessonNotes(Coach.LessonContext(lesson: along, courseId: "guitar", result: slow.result(now: now)))
        XCTAssertEqual(capped.first?.fact, .belowTempo(percent: 99, bpm: 80))
        XCTAssertFalse(capped.contains { $0.topic == .take })
    }

    func testFlawlessIsThreeStarsAtNinetyEightPercent() {
        XCTAssertTrue(Coach.isFlawless(result("a", stars: 3, accuracy: 0.98)))
        XCTAssertTrue(Coach.isFlawless(result("a", stars: 3, accuracy: 1)))
        XCTAssertFalse(Coach.isFlawless(result("a", stars: 3, accuracy: 0.97)))
        XCTAssertFalse(Coach.isFlawless(result("a", stars: 2, accuracy: 1)))
    }

    func testSingleNotesMoveAndChordsChange() {
        XCTAssertFalse(Coach.changesChord(from: note(50), to: note(55)), "a melody moves")
        XCTAssertTrue(Coach.changesChord(from: .chord(em), to: .chord(c)))
        XCTAssertTrue(Coach.changesChord(from: note(52), to: .chord(c)))
    }

    func testAReviewDoesNotSendYouBackToTheDrill() {
        let id = LearnProgress.reviewId(courseId: "guitar")
        let notes = Coach.lessonNotes(Coach.LessonContext(lesson: lesson(id, []), courseId: "guitar",
                                                          result: result(id, stars: 2, accuracy: 0.7, items: [ItemScore(item: .chord(c), score: 0.6)]),
                                                          canReview: true))
        XCTAssertEqual(notes.first?.fact, .slipped(items: [.chord(c)], percent: 60))
        XCTAssertNil(notes.first?.action)
    }

    func testNothingSpecificMeansNoNote() {
        XCTAssertEqual(Coach.lessonNotes(Coach.LessonContext(lesson: lesson("a", []), courseId: "guitar", result: result("a", stars: 3, accuracy: 1))), [])
        // Two clean items are too few to praise.
        let two = [ItemScore(item: note(64), score: 1), ItemScore(item: note(67), score: 0.95)]
        XCTAssertEqual(Coach.lessonNotes(Coach.LessonContext(lesson: lesson("a", []), courseId: "guitar", result: result("a", stars: 3, accuracy: 1, items: two))), [])
    }

    func testSkillOfALessonIsWhatMostStepsPractise() {
        let chords = lesson("a", [.explain(title: LearnText("t"), body: LearnText("b"), visual: .none), .playChord(chord: em),
                                  .strum(chord: em, pattern: [0, 1, 2, 3], bpm: 70, bars: 2, beatsPerBar: 4), .playNotes(notes: [timed(64)], hint: nil)])
        XCTAssertEqual(CoachSkill.of(chords), .chords)
        let tie = lesson("b", [.playChord(chord: em), .playNotes(notes: [timed(64)], hint: nil)])
        XCTAssertEqual(CoachSkill.of(tie), .notes, "a tie goes to the earlier skill")
        XCTAssertNil(CoachSkill.of(lesson("c", [.explain(title: LearnText("t"), body: LearnText("b"), visual: .none)])))
    }

    // MARK: On Progress

    func testADriftingStringIsWorthAWordOnceItIsSettled() {
        let drift = [StringDrift(anchor: "s1", centsPerDay: -0.5, sessions: 3, spanDays: 8), StringDrift(anchor: "s3", centsPerDay: -7.2, sessions: 3, spanDays: 8)]
        let notes = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true, drift: drift))
        XCTAssertEqual(notes.map(\.fact), [.drift(anchor: "s3", centsPerDay: -7)])
        XCTAssertEqual(notes.first?.action, .tune)
        XCTAssertEqual(notes.first?.id, "drift.s3")
        // A few days of readings on strings that may be new: not yet.
        let fresh = [StringDrift(anchor: "s3", centsPerDay: -9, sessions: 2, spanDays: 2)]
        XCTAssertEqual(Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true, drift: fresh)), [])
        // Strings put on 80 days ago are due anyway.
        let old = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true,
                                                          restrung: now.addingTimeInterval(-80 * 86_400)))
        XCTAssertEqual(old.map(\.fact), [.oldStrings(weeks: 11)])
    }

    func testTheStreakNudgeComesOnlyBeforeTodaysPractice() {
        let set = [Coach.TodayStep(activity: DailyActivity(kind: .tune, minutes: 1), done: true),
                   Coach.TodayStep(activity: DailyActivity(kind: .ear, minutes: 4), done: false),
                   Coach.TodayStep(activity: DailyActivity(kind: .rhythm, minutes: 4), done: false)]
        let before = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 7, practicedToday: false, today: set))
        XCTAssertEqual(before.map(\.fact), [.streak(days: 7)])
        XCTAssertEqual(before.first?.action, .tune, "a one-minute tune-up keeps it")
        XCTAssertEqual(before.first?.tone, .habit)
        let after = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 7, practicedToday: true, today: set))
        XCTAssertEqual(after.map(\.fact), [.today(done: 1, total: 3, next: .ear, minutes: 4)])
        XCTAssertEqual(after.first?.action, .today)
        let untouched = set.map { Coach.TodayStep(activity: $0.activity, done: false) }
        XCTAssertEqual(Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 7, practicedToday: true, today: untouched)), [],
                       "no nagging about a set not started")
    }

    func testTheCourseSplitPointsAtTheWeakestLessonOrTheDrill() {
        let course = LearnCourse(id: "c", title: LearnText("C"), subtitle: LearnText("s"), instrument: "guitar.acoustic.6", symbol: "guitars.fill", accent: "mint",
                                 units: [LearnUnit(id: "u", title: LearnText("U"), summary: LearnText("s"), lessons: [
                                    lesson("n1", [.playNotes(notes: [timed(64)], hint: nil)]),
                                    lesson("n2", [.playAlong(notes: [timed(64)], bpm: 80, beatsPerBar: 4, title: nil)]),
                                    lesson("c1", [.playChord(chord: em)]),
                                    lesson("c2", [.strum(chord: c, pattern: [0, 1, 2, 3], bpm: 70, bars: 2, beatsPerBar: 4)])
                                 ])])
        var learn = LearnProgress()
        learn.bestAccuracy = ["n1": 0.96, "n2": 0.92, "c1": 0.7, "c2": 0.62]
        let split = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true, course: course, learn: learn))
        XCTAssertEqual(split.map(\.fact), [.split(strong: .notes, strongPercent: 94, weak: .chords, weakPercent: 66)])
        XCTAssertEqual(split.first?.action, .lesson(id: "c2"), "the weakest chord lesson")

        // With Em slipping in a chord lesson, the drill covers the weak skill: it leads, and the split points at it.
        learn.record(result("c1", stars: 1, accuracy: 0.7, items: [ItemScore(item: .chord(em), score: 0.5)]), courseId: "c", now: now)
        learn.bestAccuracy = ["n1": 0.96, "n2": 0.92, "c1": 0.7, "c2": 0.62]
        let drill = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true, course: course,
                                                            learn: learn, canReview: true))
        XCTAssertEqual(drill.map(\.fact), [.slipped(items: [.chord(em)], percent: 50), .split(strong: .notes, strongPercent: 94, weak: .chords, weakPercent: 66)])
        XCTAssertEqual(drill.map(\.action), [.review(courseId: "c"), .review(courseId: "c")])
    }

    func testGrowthIsPraisedWithItsNumbers() {
        var records: [PracticeRecord] = []
        // 28 minutes this week against 20 the week before; tune-ups at ±0.9 ¢ now, ±2.2 ¢ a few weeks ago.
        for day in 0...6 { records.append(PracticeRecord(date: daysAgo(day), instrumentId: "practice.ear", kind: "ear", count: 10, stableCount: 8, durationMs: 240_000)) }
        for day in 8...12 { records.append(PracticeRecord(date: daysAgo(day), instrumentId: "practice.ear", kind: "ear", count: 10, stableCount: 8, durationMs: 240_000)) }
        for (day, cents) in [(0, 0.8), (1, 0.9), (2, 1.0), (15, 2.0), (20, 2.4), (25, 2.2)] {
            records.append(PracticeRecord(date: daysAgo(day), instrumentId: "guitar", kind: "tuning", count: 100, stableCount: 80, meanAbsoluteCents: cents))
        }
        let notes = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: records, streakDays: 13, practicedToday: true))
        XCTAssertEqual(notes.map(\.fact), [.moreTime(minutes: 28, percent: 40), .closerTuning(cents: 0.9, before: 2.2)])
        XCTAssertTrue(notes.allSatisfy { $0.tone == .praise && $0.action == nil })
        // A quieter week earns no praise (and no scolding).
        let quiet = records.filter { $0.date < daysAgo(3) }
        XCTAssertFalse(Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: quiet, streakDays: 0, practicedToday: false)).contains { $0.topic == .growth })
    }

    func testRecentTakesSpeakOnProgressToo() throws {
        let notes = Coach.journeyNotes(Coach.JourneyContext(now: now, calendar: utc, records: [], streakDays: 0, practicedToday: true, takes: [try lateIntoC()]))
        XCTAssertEqual(notes.first?.topic, .timing)
        XCTAssertEqual(notes.first?.action, .metronome(bpm: 45))
    }

    // MARK: Ranking

    func testRankingKeepsOneNotePerTopicBestFirst() {
        let notes = [
            CoachNote(fact: .drift(anchor: "s3", centsPerDay: -7), action: .tune, priority: 0.7),
            CoachNote(fact: .oldStrings(weeks: 11), action: .tune, priority: 0.5),
            CoachNote(fact: .streak(days: 7), action: .tune, priority: 0.64),
            CoachNote(fact: .moreTime(minutes: 28, percent: 40), action: nil, priority: 0.3),
            CoachNote(fact: .lean(milliseconds: 120, notes: 8, bpm: 80), action: .metronome(bpm: 80), priority: 0.9)
        ]
        XCTAssertEqual(Coach.rank(notes).map(\.id), ["lean", "drift.s3", "streak"])
        XCTAssertEqual(Coach.rank(notes, limit: 5).map(\.id), ["lean", "drift.s3", "streak", "week"])
        // Equal priorities keep their order.
        let tied = [CoachNote(fact: .clean(items: 3), action: nil, priority: 0.3), CoachNote(fact: .moreTime(minutes: 28, percent: 40), action: nil, priority: 0.3)]
        XCTAssertEqual(Coach.rank(tied).map(\.id), ["clean", "week"])
        XCTAssertEqual(CoachNote(fact: .clean(items: 3), action: nil, priority: 4).priority, 1, "priorities stay within 0…1")
    }
}
