import XCTest
@testable import TimbreCore

final class ProgressionTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func day(_ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
    }

    func testLevelsGrowAndReportProgress() {
        XCTAssertEqual(Progression.level(for: 0).number, 1)
        XCTAssertEqual(Progression.level(for: 99).number, 1)
        XCTAssertEqual(Progression.level(for: 100).number, 2)
        XCTAssertEqual(Progression.level(for: 2100).number, 7)
        XCTAssertEqual(Progression.level(for: 2100).name, "Perfect Fifth")
        let level = Progression.level(for: 2450)
        XCTAssertEqual(level.floor, 2100)
        XCTAssertEqual(level.next, 2800)
        XCTAssertEqual(level.progress(2450), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Progression.level(for: 1_000_000).name.hasPrefix("Virtuoso"), true)
    }

    func testDailyQuestsAreStableAndAlwaysIncludeTuning() {
        let a = Quests.daily(for: day(5), calendar: calendar), b = Quests.daily(for: day(5, hour: 23), calendar: calendar)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(a.first?.kind, .tuneAll)
        XCTAssertEqual(Set(a.map(\.id)).count, 3)
        let week = (1...14).map { Quests.daily(for: day($0), calendar: calendar).map(\.id) }
        XCTAssertGreaterThan(Set(week.map { $0.joined() }).count, 1, "the pool rotates")
    }

    func testTuningEarnsXPCompletesTheQuestAndUnlocksBadges() {
        var state = ProgressState()
        var update = state.record(.stringTuned(instrumentId: "guitar", all: false), now: day(5), calendar: calendar)
        XCTAssertEqual(update.xpGained, XPReward.stringTuned)
        XCTAssertEqual(update.achievementsEarned.map(\.id), ["first_tune"])
        update = state.record(.stringTuned(instrumentId: "guitar", all: true), now: day(5), calendar: calendar)
        XCTAssertEqual(update.questsCompleted.map(\.kind), [.tuneAll])
        XCTAssertEqual(update.xpGained, XPReward.stringTuned + XPReward.fullTune + 20)
        XCTAssertTrue(update.achievementsEarned.contains { $0.id == "full_tune" })
        // The same quest pays once a day, and again tomorrow.
        update = state.record(.stringTuned(instrumentId: "guitar", all: true), now: day(5), calendar: calendar)
        XCTAssertFalse(update.questsCompleted.contains { $0.kind == .tuneAll })
        update = state.record(.stringTuned(instrumentId: "guitar", all: true), now: day(6), calendar: calendar)
        XCTAssertEqual(update.questsCompleted.map(\.kind), [.tuneAll])
        XCTAssertEqual(state.stats["stringsTuned"], 4)
        XCTAssertTrue(state.isValid)
    }

    func testLevelUpIsReported() {
        var state = ProgressState()
        state.xp = 95
        let update = state.record(.stringTuned(instrumentId: "uke", all: false), now: day(5), calendar: calendar)
        XCTAssertEqual(update.levelUp?.number, 2)
    }

    func testStreakAndInstrumentBadges() {
        var state = ProgressState()
        _ = state.record(.stringTuned(instrumentId: "a", all: false), streakBest: 7, now: day(5), calendar: calendar)
        XCTAssertTrue(state.achievements.contains("streak_7"))
        _ = state.record(.stringTuned(instrumentId: "b", all: false), now: day(5), calendar: calendar)
        XCTAssertFalse(state.achievements.contains("multi"))
        _ = state.record(.stringTuned(instrumentId: "c", all: false), now: day(5), calendar: calendar)
        XCTAssertTrue(state.achievements.contains("multi"))
    }

    func testStringsTunedTodayOutliveSessionsAndResetTheNextDay() throws {
        var state = ProgressState()
        let six = [0, 1, 2, 3, 4, 5]
        let tune = Quest(kind: .tuneAll, target: 1, xp: 20)
        _ = state.record(.stringTuned(instrumentId: "g", all: false, course: 0, courses: six), now: day(5, hour: 9), calendar: calendar)
        _ = state.record(.stringTuned(instrumentId: "g", all: false, course: 1, courses: six), now: day(5, hour: 9), calendar: calendar)
        // A new session (after a pause or a tab switch) locking the same string again does not count it twice.
        _ = state.record(.stringTuned(instrumentId: "g", all: false, course: 1, courses: six), now: day(5, hour: 18), calendar: calendar)
        XCTAssertEqual(state.stringsTunedToday(instrumentId: "g", courses: six, now: day(5, hour: 19), calendar: calendar), 2)
        XCTAssertTrue(Quests.counter(for: tune, state: state, instrumentId: "g", courses: six, now: day(5, hour: 19), calendar: calendar) == (done: 2, total: 6))
        // Each instrument keeps its own list; chromatic mode (no courses) counts nothing.
        XCTAssertEqual(state.stringsTunedToday(instrumentId: "u", courses: [0, 1, 2, 3], now: day(5), calendar: calendar), 0)
        XCTAssertTrue(Quests.counter(for: tune, state: state, instrumentId: nil, courses: [], now: day(5), calendar: calendar) == (done: 0, total: 1))
        // The list is saved with the rest of the progress.
        let decoded = try JSONDecoder().decode(ProgressState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.stringsTunedToday(instrumentId: "g", courses: six, now: day(5, hour: 19), calendar: calendar), 2)
        XCTAssertTrue(decoded.isValid)
        // The other four strings in a later session complete the quest, though no single session tuned all six.
        var update = ProgressUpdate()
        for course in 2...5 { update = state.record(.stringTuned(instrumentId: "g", all: false, course: course, courses: six), now: day(5, hour: 20), calendar: calendar) }
        XCTAssertEqual(update.questsCompleted.map(\.kind), [.tuneAll])
        XCTAssertNil(state.stats["fullTunes"], "a full tune still means one session")
        XCTAssertTrue(Quests.counter(for: tune, state: state, instrumentId: "g", courses: six, now: day(5, hour: 21), calendar: calendar) == (done: 6, total: 6))
        // Tomorrow starts from zero, and the first event of the day clears the list.
        XCTAssertTrue(Quests.counter(for: tune, state: state, instrumentId: "g", courses: six, now: day(6), calendar: calendar) == (done: 0, total: 6))
        _ = state.record(.earCorrect, now: day(6), calendar: calendar)
        XCTAssertNil(state.tunedToday)
    }

    func testSavesFromBeforeTheNewFieldsStillDecode() throws {
        let old = #"{"xp":120,"stats":{"stringsTuned":3},"questDay":"2026-10-05","questProgress":{"tuneAll":1},"questsClaimed":["tuneAll"],"achievements":["first_tune"],"instrumentsTuned":["g"],"stringSamples":[],"restrung":{}}"#
        let state = try JSONDecoder().decode(ProgressState.self, from: Data(old.utf8))
        XCTAssertNil(state.tunedToday)
        XCTAssertNil(state.dailySetDay)
        XCTAssertTrue(state.isValid)
        // Claimed today with no saved strings: the counter reads full, as before.
        XCTAssertTrue(Quests.counter(for: Quest(kind: .tuneAll, target: 1, xp: 20), state: state, instrumentId: "g", courses: [0, 1, 2, 3, 4, 5], now: day(5), calendar: calendar) == (done: 6, total: 6))
    }

    func testDailySetPaysOnceADayAndCountsTowardBadges() {
        var state = ProgressState()
        var update = state.record(.dailySetCompleted, now: day(5), calendar: calendar)
        XCTAssertTrue(update.dailySetCompleted)
        XCTAssertEqual(update.xpGained, XPReward.dailySet)
        XCTAssertTrue(update.achievementsEarned.contains { $0.id == "daily_1" })
        update = state.record(.dailySetCompleted, now: day(5, hour: 22), calendar: calendar)
        XCTAssertFalse(update.dailySetCompleted)
        XCTAssertEqual(update.xpGained, 0)
        update = state.record(.dailySetCompleted, now: day(6), calendar: calendar)
        XCTAssertTrue(update.dailySetCompleted)
        XCTAssertEqual(state.stats["dailySets"], 2)
    }

    func testMergedUpdatesKeepEveryReward() {
        let quest = Quest(kind: .lessons, target: 2, xp: 30)
        let badge = Achievements.all[0]
        let a = ProgressUpdate(xpGained: 10, questsCompleted: [quest], dailySetCompleted: true)
        let b = ProgressUpdate(xpGained: 5, levelUp: Progression.level(for: 100), questsCompleted: [quest], achievementsEarned: [badge])
        let merged = a.merged(with: b)
        XCTAssertEqual(merged.xpGained, 15)
        XCTAssertEqual(merged.levelUp?.number, 2)
        XCTAssertEqual(merged.questsCompleted.count, 1)
        XCTAssertEqual(merged.achievementsEarned.map(\.id), [badge.id])
        XCTAssertTrue(merged.dailySetCompleted)
    }

    func testAchievementSetKeepsSavedBadgesAndGrows() {
        let all = Achievements.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids are unique")
        XCTAssertGreaterThanOrEqual(all.count, 40)
        // The original sixteen keep their ids, metrics and goals, so saved progress stays valid.
        let original: [(String, String, Int)] = [
            ("first_tune", "stringsTuned", 1), ("full_tune", "fullTunes", 1), ("streak_7", "streakBest", 7), ("strings_100", "stringsTuned", 100),
            ("bullseye", "bullseyes", 1), ("sharpshooter", "sniperBest", 2000), ("golden_ear", "earCorrect", 50), ("level_5", "level", 5),
            ("multi", "instruments", 3), ("own_tuning", "customTunings", 1), ("streak_30", "streakBest", 30), ("strings_1000", "stringsTuned", 1000),
            ("first_lesson", "lessons", 1), ("lessons_25", "lessons", 25), ("lessons_100", "lessons", 100), ("perfect_10", "perfectLessons", 10),
        ]
        for (id, metric, goal) in original {
            let badge = all.first { $0.id == id }
            XCTAssertEqual(badge?.metric, metric, id)
            XCTAssertEqual(badge?.goal, goal, id)
        }
        XCTAssertTrue(all.allSatisfy { $0.goal > 0 && !$0.title.isEmpty && !$0.detail.isEmpty })
        XCTAssertEqual(Achievements.courseId(of: all.first { $0.id == "course_violin" }!), "violin")
        XCTAssertNil(Achievements.courseId(of: all[0]))
        // Derived values win over stored counters; precision locks and perfect ear rounds are counted.
        var state = ProgressState()
        _ = state.record(.stringTuned(instrumentId: "g", all: false, course: 0, courses: [0], precise: true), now: day(5), calendar: calendar)
        _ = state.record(.earRound(questions: 10, correct: 10), now: day(5), calendar: calendar)
        _ = state.record(.earRound(questions: 10, correct: 9), now: day(5), calendar: calendar)
        XCTAssertEqual(state.stats["preciseLocks"], 1)
        XCTAssertEqual(state.stats["earPerfect"], 1)
        XCTAssertTrue(state.achievements.contains("ear_perfect"))
        let earned = state.awardAchievements(metrics: ["minutes": 75, "units": 1])
        XCTAssertEqual(Set(earned.map(\.id)), ["minutes_60", "units_1"])
    }

    func testBadgesReadAsSentencesAndEachHasItsOwnArtwork() {
        let all = Achievements.all
        XCTAssertEqual(Set(all.map(\.artwork)).count, all.count, "one artwork name per badge")
        XCTAssertEqual(all.first { $0.id == "first_tune" }?.artwork, "Medals/medal.first_tune")
        // Titles are sentence case: only the first word is capitalised.
        for badge in all {
            let words = badge.title.split(separator: " ").dropFirst()
            XCTAssertFalse(words.contains { $0.first?.isUppercase == true }, badge.title)
        }
        // Nothing borrows shooting words.
        XCTAssertFalse(all.contains { $0.symbol.contains("scope") || $0.title.lowercased().contains("shoot") })
    }

    func testLearnMetricsCountCoursesUnitsAndSongs() throws {
        let curriculum = try Curriculum.bundled()
        let guitar = try XCTUnwrap(curriculum.course(id: "guitar"))
        var learn = LearnProgress()
        for lesson in guitar.units[0].lessons {
            learn.record(LessonResult(lessonId: lesson.id, stars: 3, accuracy: 1, xp: 20, minutes: 3), courseId: "guitar")
        }
        let song = try XCTUnwrap(curriculum.course(id: "songs")?.lessons.first { $0.kind == .song })
        learn.record(LessonResult(lessonId: song.id, stars: 2, accuracy: 0.8, xp: 20, minutes: 3), courseId: "songs")
        let metrics = Achievements.learnMetrics(learn, curriculum: curriculum)
        XCTAssertEqual(metrics["course.guitar"], guitar.units[0].lessons.count)
        XCTAssertEqual(metrics["course.ukulele"], 0)
        XCTAssertGreaterThanOrEqual(metrics["units"] ?? 0, 1)
        XCTAssertEqual(metrics["songs"], 1 + guitar.units[0].lessons.filter { $0.kind == .song }.count)
        XCTAssertEqual(metrics["courses"], 0)
        // Every per-course badge points at a real course.
        for badge in Achievements.all {
            if let id = Achievements.courseId(of: badge) { XCTAssertNotNil(curriculum.course(id: id), badge.id) }
        }
    }

    func testStringDriftUsesTheMedianRateBetweenSessions() {
        var samples: [StringSample] = []
        // G drifts about −6 cents a day; E barely moves; a same-day retune is ignored.
        for (d, cents) in [(1, -3.0), (2, -6.0), (4, -12.5), (5, -5.8)] { samples.append(StringSample(instrumentId: "g", anchor: "s3", date: day(d), cents: cents)) }
        samples.append(StringSample(instrumentId: "g", anchor: "s3", date: day(5, hour: 13), cents: -40))
        for d in [1, 3, 5] { samples.append(StringSample(instrumentId: "g", anchor: "s1", date: day(d), cents: 1)) }
        samples.append(StringSample(instrumentId: "other", anchor: "s3", date: day(3), cents: 50))
        let drift = StringHealth.drift(samples, instrumentId: "g")
        XCTAssertEqual(drift.first?.anchor, "s3")
        XCTAssertEqual(drift.first?.centsPerDay ?? 0, -6.0, accuracy: 0.3)
        XCTAssertEqual(drift.first?.sessions, 3)
        XCTAssertEqual(drift.last?.anchor, "s1")
        XCTAssertEqual(drift.first?.spanDays ?? 0, 4, accuracy: 0.1)
        // Four days of readings with no restring date: the strings may be new, too early to judge.
        XCTAssertFalse(StringHealth.needsRestring(drift, restrung: nil))
        XCTAssertFalse(StringHealth.needsRestring(drift.filter { $0.anchor == "s1" }, restrung: day(1), now: day(5)))
        XCTAssertTrue(StringHealth.needsRestring([], restrung: day(1), now: day(1).addingTimeInterval(71 * 86_400)))
    }

    func testRestringAdviceWithoutARestringDateWaitsForFiveDaysOfReadings() {
        var samples: [StringSample] = []
        // G goes about 8 cents flat a day.
        for d in [1, 2, 3] { samples.append(StringSample(instrumentId: "g", anchor: "s3", date: day(d), cents: -8)) }
        let early = StringHealth.drift(samples, instrumentId: "g")
        XCTAssertEqual(early.first?.centsPerDay ?? 0, -8, accuracy: 0.01)
        XCTAssertEqual(early.first?.sessions, 2)
        XCTAssertFalse(StringHealth.needsRestring(early, restrung: nil, now: day(3)))
        for d in [5, 7] { samples.append(StringSample(instrumentId: "g", anchor: "s3", date: day(d), cents: -16)) }
        let later = StringHealth.drift(samples, instrumentId: "g")
        XCTAssertGreaterThanOrEqual(later.first?.spanDays ?? 0, StringHealth.minimumSpanDays)
        XCTAssertTrue(StringHealth.needsRestring(later, restrung: nil, now: day(7)))
        // A string that holds its pitch never asks for new strings, however long the readings run.
        let steady = (1...20).map { StringSample(instrumentId: "g", anchor: "s1", date: day($0), cents: -1) }
        XCTAssertFalse(StringHealth.needsRestring(StringHealth.drift(steady, instrumentId: "g"), restrung: nil, now: day(20)))
    }

    func testNewStringsStretchingDoNotAskForARestring() {
        // Restrung on the 1st: the new G stretches and goes 12 cents flat a day for its first week.
        let restrung = day(1)
        var samples = (2...9).map { StringSample(instrumentId: "g", anchor: "s3", date: day($0), cents: -12) }
        let stretching = StringHealth.drift(samples, instrumentId: "g", since: restrung)
        XCTAssertTrue(stretching.isEmpty, "readings from the first ten days after a restring are left out")
        XCTAssertFalse(StringHealth.needsRestring(stretching, restrung: restrung, now: day(9)))
        // Settled, it holds within a cent a day: still no advice, and the stretching days don't count.
        samples += [13, 15, 17].map { StringSample(instrumentId: "g", anchor: "s3", date: day($0), cents: -1.5) }
        let settled = StringHealth.drift(samples, instrumentId: "g", since: restrung)
        XCTAssertEqual(settled.first?.centsPerDay ?? 0, -0.75, accuracy: 0.01)
        XCTAssertFalse(StringHealth.needsRestring(settled, restrung: restrung, now: day(17)))
        // A settled string that really wanders is flagged.
        let worn = [13, 15, 17].map { StringSample(instrumentId: "g", anchor: "s3", date: day($0), cents: -10) }
        XCTAssertTrue(StringHealth.needsRestring(StringHealth.drift(worn, instrumentId: "g", since: restrung), restrung: restrung, now: day(17)))
    }

    func testSamplesRollOff() {
        var state = ProgressState()
        for i in 0..<(ProgressState.sampleLimit + 10) {
            state.sample(StringSample(instrumentId: "g", anchor: "s1", date: Date(timeIntervalSince1970: Double(i)), cents: 0))
        }
        XCTAssertEqual(state.stringSamples.count, ProgressState.sampleLimit)
        XCTAssertEqual(state.stringSamples.first?.date, Date(timeIntervalSince1970: 10))
    }
}

final class PitchSniperTests: XCTestCase {
    private let guitar = [40, 45, 50, 55, 59, 64]

    func testRoundsAreDeterministicAndPlayable() {
        let a = PitchSniper(notes: guitar, fretted: true, seed: 7), b = PitchSniper(notes: guitar, fretted: true, seed: 7)
        XCTAssertEqual(a.rounds, b.rounds)
        XCTAssertEqual(a.rounds.count, 10)
        XCTAssertTrue(a.rounds.allSatisfy { (40...68).contains($0.midi) })
        XCTAssertTrue(zip(a.rounds, a.rounds.dropFirst()).allSatisfy { $0.midi != $1.midi }, "no note twice in a row")
        XCTAssertEqual(a.rounds[0].frequency, 440 * pow(2, Double(a.rounds[0].midi - 69) / 12), accuracy: 1e-9)
    }

    func testFastBullseyesScoreMoreAndBuildACombo() {
        var game = PitchSniper(notes: guitar, fretted: false, seed: 3)
        // Round 1: on target almost at once.
        XCTAssertEqual(game.update(cents: 30, at: 0), nil)
        XCTAssertEqual(game.update(cents: 3, at: 0.5), .holding(0))
        guard case .finished(.bullseye(let first)) = game.update(cents: -2, at: 1.2) else { return XCTFail("expected a bullseye") }
        // Round 2: on target late, with the combo multiplier.
        _ = game.update(cents: nil, at: 2.0)
        XCTAssertEqual(game.update(cents: 2, at: 7.5), .holding(0))
        guard case .finished(.bullseye(let second)) = game.update(cents: 1, at: 8.2) else { return XCTFail("expected a bullseye") }
        XCTAssertGreaterThan(first, 400)
        XCTAssertEqual(game.combo, 2)
        XCTAssertGreaterThan(second, 100 * 2 - 1)
        XCTAssertEqual(game.score, first + second)
    }

    func testDriftingOutOfTheBullseyeRestartsTheHoldAndTimeoutsReset() {
        var game = PitchSniper(notes: guitar, fretted: false, seed: 3)
        _ = game.update(cents: 2, at: 0)
        _ = game.update(cents: 12, at: 0.4)      // left the bullseye: hold restarts
        XCTAssertEqual(game.update(cents: 2, at: 0.5), .holding(0))
        XCTAssertEqual(game.update(cents: 15, at: 8.1), .finished(.near(points: 50)))
        XCTAssertEqual(game.combo, 0)
        _ = game.update(cents: nil, at: 9)
        XCTAssertEqual(game.update(cents: nil, at: 17.5), .finished(.miss))
        XCTAssertEqual(game.skip(), .finished(.miss))
        XCTAssertEqual(game.index, 3)
        XCTAssertFalse(game.won)
    }
}
