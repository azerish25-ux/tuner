import XCTest
@testable import TimbreCore

final class StreakCacheTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func record(_ daysAgo: Int, seconds: TimeInterval = 0) -> PracticeRecord {
        PracticeRecord(date: now.addingTimeInterval(-Double(daysAgo) * 86400 + seconds), instrumentId: "guitar.acoustic.6", kind: "tuning",
                       count: 1, stableCount: 1, durationMs: 60_000)
    }

    func testMatchesAFreshCountAndRecountsWhenTheRecordsChange() {
        var cache = StreakCache()
        let records = [record(0), record(1), record(2)]
        let first = cache.summary(records: records, revision: 1, frozen: [], now: now, calendar: calendar)
        XCTAssertEqual(first, Streaks.summary(records: records, now: now, calendar: calendar))
        XCTAssertEqual(first.current, 3)
        // Same revision: the kept count, even when handed other records.
        XCTAssertEqual(cache.summary(records: [], revision: 1, frozen: [], now: now, calendar: calendar).current, 3)
        // A new revision counts again.
        XCTAssertEqual(cache.summary(records: [record(0)], revision: 2, frozen: [], now: now, calendar: calendar).current, 1)
    }

    func testRecountsWhenFrozenDaysChange() {
        var cache = StreakCache()
        let records = [record(3), record(4)]
        XCTAssertEqual(cache.summary(records: records, revision: 1, frozen: [], now: now, calendar: calendar).current, 0)
        let frozen = [calendar.startOfDay(for: record(2).date), calendar.startOfDay(for: record(1).date)]
        XCTAssertEqual(cache.summary(records: records, revision: 1, frozen: frozen, now: now, calendar: calendar).current, 2)
    }

    func testRecountsOnANewDay() {
        var cache = StreakCache()
        let records = [record(0)]
        XCTAssertTrue(cache.summary(records: records, revision: 1, frozen: [], now: now, calendar: calendar).practicedToday)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let next = cache.summary(records: records, revision: 1, frozen: [], now: tomorrow, calendar: calendar)
        XCTAssertFalse(next.practicedToday)
        XCTAssertEqual(next.current, 1, "yesterday's run lasts until the end of today")
    }

    func testARecordFromLaterCountsWhenItsTimeComes() {
        var cache = StreakCache()
        let later = record(0, seconds: 60)
        let records = [record(1), later]
        XCTAssertFalse(cache.summary(records: records, revision: 1, frozen: [], now: now, calendar: calendar).practicedToday)
        XCTAssertTrue(cache.summary(records: records, revision: 1, frozen: [], now: later.date, calendar: calendar).practicedToday)
    }

    func testInvalidateCountsAgain() {
        var cache = StreakCache()
        XCTAssertEqual(cache.summary(records: [record(0)], revision: 1, frozen: [], now: now, calendar: calendar).current, 1)
        cache.invalidate()
        XCTAssertEqual(cache.summary(records: [], revision: 1, frozen: [], now: now, calendar: calendar).current, 0)
    }
}
