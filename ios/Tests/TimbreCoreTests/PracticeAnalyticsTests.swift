import XCTest
@testable import TimbreCore

final class PracticeAnalyticsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_735_732_800)
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private func record(daysAgo: Double, instrument: String = "guitar.acoustic.6", mean: Double? = 10, duration: Int? = 60000) -> PracticeRecord {
        PracticeRecord(date: now.addingTimeInterval(-daysAgo * 86400), instrumentId: instrument, kind: "tuning", count: 10, stableCount: mean == nil ? 0 : 8, meanAbsoluteCents: mean, durationMs: duration)
    }
    func testSevenDayActivityUsesCalendarDaysAndFiltersFutureAndInstrument() {
        let records = [record(daysAgo: 0, duration: 60000), record(daysAgo: 0.01, duration: 30000), record(daysAgo: 6, duration: 120000), record(daysAgo: 7), record(daysAgo: -1), record(daysAgo: 0, instrument: "voice")]
        let summary = PracticeAnalytics.summary(records: records, instrumentId: "guitar.acoustic.6", now: now, calendar: calendar)
        XCTAssertEqual(summary.activity.count, 7)
        XCTAssertEqual(summary.activity.last?.sessionCount, 2)
        XCTAssertEqual(summary.activity.last?.durationMs, 90000)
        XCTAssertEqual(summary.activity.first?.durationMs, 120000)
        XCTAssertEqual(summary.weekDurationMs, 210000)
        XCTAssertEqual(summary.records.count, 4)
        XCTAssertEqual(summary.activity[1].durationMs, 0)
    }
    func testMissingHistoricalDurationIsUnknownRatherThanZero() {
        let summary = PracticeAnalytics.summary(records: [record(daysAgo: 0, duration: nil), record(daysAgo: 0, duration: 5000)], now: now, calendar: calendar)
        XCTAssertNil(summary.activity.last?.durationMs)
        XCTAssertEqual(summary.activity.last?.measuredDurationMs, 5000)
        XCTAssertEqual(summary.activity.last?.missingDurationCount, 1)
        XCTAssertNil(summary.weekDurationMs)
        XCTAssertEqual(summary.measuredWeekDurationMs, 5000)
    }
    func testComparisonRequiresThreeMeasuredPerSideAndUsesPerSessionMeans() {
        let records = [record(daysAgo: 0, mean: 6), record(daysAgo: 1, mean: 9), record(daysAgo: 2, mean: 12), record(daysAgo: 3, mean: nil), record(daysAgo: 15, mean: 20), record(daysAgo: 16, mean: 20), record(daysAgo: 17, mean: 20)]
        let comparison = PracticeAnalytics.compareWindows(records: records, now: now)
        XCTAssertEqual(comparison.recent.sessionCount, 4)
        XCTAssertEqual(comparison.recent.measuredSessions, 3)
        XCTAssertEqual(comparison.recent.meanAbsCentsError, 9)
        XCTAssertEqual(comparison.changeCents, -11)
        XCTAssertNil(PracticeAnalytics.compareWindows(records: Array(records.dropLast()), now: now).changeCents)
        XCTAssertNil(PracticeAnalytics.compareWindows(records: records.map { var copy = $0; copy.instrumentId = "voice"; return copy }, now: now).changeCents)
        XCTAssertNil(PracticeAnalytics.compareWindows(records: records + [record(daysAgo: 1, instrument: "violin.standard.4")], now: now).changeCents)
    }
    func testExactFourteenDayBoundaryAndInvalidAccuracy() {
        let records = [record(daysAgo: 14), record(daysAgo: 28), record(daysAgo: 28.01), record(daysAgo: 0, mean: .nan), record(daysAgo: 0, mean: -1), record(daysAgo: 0, mean: nil)]
        let comparison = PracticeAnalytics.compareWindows(records: records, now: now)
        XCTAssertEqual(comparison.recent.sessionCount, 4)
        XCTAssertEqual(comparison.recent.measuredSessions, 1)
        XCTAssertEqual(comparison.earlier?.sessionCount, 1)
        XCTAssertNil(comparison.changeCents)
        let empty = PracticeAnalytics.compareWindows(records: [], now: now)
        XCTAssertNil(empty.recent.meanAbsCentsError)
        XCTAssertNil(empty.earlier)
    }
    func testCalendarTimezoneControlsDayGroupingAcrossMidnight() {
        var west = calendar; west.timeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let midnight = Date(timeIntervalSince1970: 1_735_689_600)
        let event = PracticeRecord(date: midnight.addingTimeInterval(3600), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 1, stableCount: 1, durationMs: 1000)
        let day = PracticeAnalytics.activityDays(records: [event], now: midnight.addingTimeInterval(12 * 3600), calendar: west)
        XCTAssertEqual(day.suffix(2).first?.sessionCount, 1)
        XCTAssertEqual(day.last?.sessionCount, 0)
    }
    func testVoiceBestAndAttemptsExcludeUnscoredWarmupAndRange() {
        func result(level: Int, cents: Double) -> VoiceResult {
            let exercise = VoiceExercise(level: level)
            let attempt = VoiceAttempt(exercise: exercise)
            for time in stride(from: 0, to: exercise.durationMs, by: 50) {
                attempt.accept(frequency: PitchMath.frequency(midi: Double(exercise.note(at: time))) * PitchMath.ratio(cents: cents), stable: true, elapsedMs: time)
            }
            return attempt.finish()
        }
        let results = [(2, result(level: 2, cents: 20)), (2, result(level: 2, cents: 0)), (1, result(level: 1, cents: 0)), (7, result(level: 7, cents: 0))]
        let records = results.enumerated().map { index, item in PracticeRecord(date: now.addingTimeInterval(Double(index)), instrumentId: "voice", tuningId: VoiceExercise(level: item.0).id, kind: "voice", count: item.1.readingCount, stableCount: item.1.stableReadingCount, voiceResult: item.1, durationMs: 6000) }
        let challenges = PracticeAnalytics.challenges(records: records)
        XCTAssertEqual(challenges.count, 1)
        XCTAssertEqual(challenges.first?.challengeId, VoiceExercise(level: 2).id)
        XCTAssertEqual(challenges.first?.attempts, 2)
        XCTAssertEqual(challenges.first?.bestScore, 100)
        XCTAssertEqual(challenges.first?.lastPlayedAt, now.addingTimeInterval(1))
    }
}
