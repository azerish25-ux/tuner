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
        XCTAssertTrue(update.questsCompleted.isEmpty)
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
        XCTAssertTrue(StringHealth.needsRestring(drift, restrung: nil))
        XCTAssertFalse(StringHealth.needsRestring(drift.filter { $0.anchor == "s1" }, restrung: day(1), now: day(5)))
        XCTAssertTrue(StringHealth.needsRestring([], restrung: day(1), now: day(1).addingTimeInterval(71 * 86_400)))
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
