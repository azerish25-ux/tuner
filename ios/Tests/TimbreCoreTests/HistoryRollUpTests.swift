import Foundation
import XCTest
@testable import TimbreCore

/// Long histories roll up (`LocalStore.rolledUp`) without changing anything streaks and stats read; settings
/// changes can wait for one write (`stageSettings` / `flush`).
final class HistoryRollUpTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func day(_ offset: Int, hour: Double, from reference: Date, calendar: Calendar) -> Date {
        let start = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: reference)) ?? reference
        return start.addingTimeInterval(hour * 3600)
    }

    private func voiceResult() -> VoiceResult {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for index in 0..<110 { attempt.accept(frequency: 220, stable: true, elapsedMs: index * 50) }
        return attempt.finish()
    }

    /// Four hundred old days (most practised, up to four sessions a day across instruments and kinds, some without a
    /// duration or an accuracy), two scored voice takes, and a recent month.
    private func history() -> [PracticeRecord] {
        var records: [PracticeRecord] = []
        let instruments = ["guitar.acoustic.6", "ukulele.standard.4"]
        for offset in 200..<600 where offset % 7 != 3 {
            for session in 0..<(offset % 4 + 1) {
                records.append(PracticeRecord(date: day(offset, hour: Double(8 + session * 3), from: now, calendar: calendar),
                                              instrumentId: instruments[(offset + session) % 2], tuningId: "standard", kind: "tuning",
                                              count: 40 + session, stableCount: session == 3 ? 0 : 20 + session,
                                              meanAbsoluteCents: session == 2 ? nil : Double(session + 2), durationMs: 60_000 * (session + 1)))
            }
            if offset % 5 == 0 {
                records.append(PracticeRecord(date: day(offset, hour: 20, from: now, calendar: calendar), instrumentId: "learn.guitar",
                                              kind: "lesson", count: 3, stableCount: 2, durationMs: 240_000))
            }
            if offset % 11 == 0 {
                records.append(PracticeRecord(date: day(offset, hour: 21, from: now, calendar: calendar), instrumentId: "practice.ear",
                                              kind: "ear", count: 10, stableCount: 7))
            }
        }
        let result = voiceResult()
        for hour in [9.0, 10.0] {
            records.append(PracticeRecord(date: day(300, hour: hour, from: now, calendar: calendar), instrumentId: "voice",
                                          tuningId: VoiceExercise(level: 4).id, kind: "voice", count: 110, stableCount: 110, voiceResult: result))
        }
        for offset in 0..<30 {
            for session in 0..<2 {
                records.append(PracticeRecord(date: day(offset, hour: Double(9 + session * 5), from: now, calendar: calendar),
                                              instrumentId: instruments[session], tuningId: "standard", kind: "tuning",
                                              count: 30, stableCount: 12, meanAbsoluteCents: 3.5, durationMs: 90_000))
            }
        }
        return records.sorted { $0.date > $1.date }
    }

    /// Instruments by most recent use, as the picker's recents read them.
    private func recentInstruments(_ records: [PracticeRecord]) -> [String] {
        var seen = Set<String>()
        return records.sorted { $0.date > $1.date }.compactMap { seen.insert($0.instrumentId).inserted ? $0.instrumentId : nil }
    }

    func testRollUpKeepsStreaksMinutesAndRecentHistory() throws {
        let records = history()
        let rolled = LocalStore.rolledUp(records, now: now, calendar: calendar)
        XCTAssertLessThan(rolled.count, records.count, "old days collapse")
        XCTAssertEqual(rolled, rolled.sorted { $0.date > $1.date }, "newest first, as the store keeps them")

        // Streaks (every practised day, the current and best runs, today) and the total minutes are unchanged.
        XCTAssertEqual(Streaks.summary(records: rolled, now: now, calendar: calendar), Streaks.summary(records: records, now: now, calendar: calendar))
        XCTAssertEqual(rolled.compactMap(\.durationMs).reduce(0, +), records.compactMap(\.durationMs).reduce(0, +))
        XCTAssertEqual(rolled.map(\.count).reduce(0, +), records.map(\.count).reduce(0, +))
        XCTAssertEqual(rolled.map(\.stableCount).reduce(0, +), records.map(\.stableCount).reduce(0, +))
        XCTAssertEqual(recentInstruments(rolled), recentInstruments(records))
        XCTAssertEqual(Set(rolled.map(\.kind)), Set(records.map(\.kind)))

        // The recent months and every scored voice take are kept session by session.
        let cutoff = try XCTUnwrap(calendar.date(byAdding: .day, value: -LocalStore.rollUpAfterDays, to: calendar.startOfDay(for: now)))
        let recentBefore = Dictionary(uniqueKeysWithValues: records.filter { $0.date >= cutoff }.map { ($0.id, $0) })
        let recentAfter = Dictionary(uniqueKeysWithValues: rolled.filter { $0.date >= cutoff }.map { ($0.id, $0) })
        XCTAssertEqual(recentAfter, recentBefore)
        XCTAssertEqual(rolled.filter { $0.voiceResult != nil }.count, 2)

        // Older practice: one record per day, instrument, tuning and kind, dated at that day's last session, its
        // accuracy the mean weighted by stable readings.
        let old = rolled.filter { $0.date < cutoff && $0.voiceResult == nil }
        let keys = old.map { "\(calendar.startOfDay(for: $0.date).timeIntervalSince1970)|\($0.instrumentId)|\($0.tuningId ?? "-")|\($0.kind)" }
        XCTAssertEqual(Set(keys).count, keys.count)
        for record in old {
            let start = calendar.startOfDay(for: record.date)
            let group = records.filter {
                $0.voiceResult == nil && calendar.startOfDay(for: $0.date) == start && $0.instrumentId == record.instrumentId
                    && $0.tuningId == record.tuningId && $0.kind == record.kind
            }
            XCTAssertEqual(record.date, group.map(\.date).max())
            XCTAssertEqual(record.durationMs, group.compactMap(\.durationMs).isEmpty ? nil : group.compactMap(\.durationMs).reduce(0, +))
            let measured = group.filter { $0.meanAbsoluteCents != nil }
            let weight = measured.map(\.stableCount).reduce(0, +)
            if weight > 0 {
                let expected = measured.map { ($0.meanAbsoluteCents ?? 0) * Double($0.stableCount) }.reduce(0, +) / Double(weight)
                XCTAssertEqual(record.meanAbsoluteCents ?? -1, expected, accuracy: 1e-9)
            } else if measured.isEmpty {
                XCTAssertNil(record.meanAbsoluteCents)
            }
        }
    }

    func testRecentHistoryIsNeverRolledUp() {
        let recent = history().filter { $0.date >= now.addingTimeInterval(-30 * 86_400) && $0.voiceResult == nil }
        XCTAssertFalse(recent.isEmpty)
        XCTAssertEqual(LocalStore.rolledUp(recent, now: now, calendar: calendar), recent)
    }

    func testAStorePastItsLimitRollsUpAndKeepsTheStreak() throws {
        let directory = try directory()
        let store = try LocalStore(directory: directory)
        store.historyLimit = 20
        let today = Date()
        var appended: [PracticeRecord] = []
        for offset in 200..<210 {
            for session in 0..<3 {
                appended.append(PracticeRecord(date: day(offset, hour: Double(9 + session * 3), from: today, calendar: .current),
                                               instrumentId: "guitar.acoustic.6", kind: "tuning", count: 20, stableCount: 10,
                                               meanAbsoluteCents: 4, durationMs: 120_000))
            }
        }
        for offset in 1...5 {
            appended.append(PracticeRecord(date: day(offset, hour: 12, from: today, calendar: .current), instrumentId: "practice.ear",
                                           kind: "ear", count: 10, stableCount: 8, durationMs: 60_000))
        }
        for record in appended { try store.append(record) }
        XCTAssertLessThanOrEqual(store.records.count, store.historyLimit)
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.records, store.records)
        XCTAssertEqual(Streaks.summary(records: reopened.records), Streaks.summary(records: appended))
        XCTAssertEqual(reopened.records.filter { $0.kind == "ear" }.count, 5, "the recent days are kept as they were")
    }

    func testStagedSettingsWaitForAFlushOrTheNextWrite() throws {
        let directory = try directory()
        let store = try LocalStore(directory: directory)
        var settings = store.settings
        settings.hapticsEnabled = false
        try store.stageSettings(settings)
        XCTAssertFalse(store.settings.hapticsEnabled, "current at once")
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertTrue(try LocalStore(directory: directory).settings.hapticsEnabled, "not written yet")
        try store.flush()
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertFalse(try LocalStore(directory: directory).settings.hapticsEnabled)

        // A practice record's write carries staged settings with it.
        settings.capo = 3
        try store.stageSettings(settings)
        try store.append(PracticeRecord(instrumentId: "guitar.acoustic.6", kind: "tuning", count: 3, stableCount: 2))
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertEqual(try LocalStore(directory: directory).settings.capo, 3)

        // Invalid settings are refused at once and change nothing.
        var invalid = store.settings
        invalid.confidenceThreshold = .nan
        XCTAssertThrowsError(try store.stageSettings(invalid))
        XCTAssertEqual(store.settings.confidenceThreshold, 0.75)
        XCTAssertFalse(store.hasUnsavedChanges)
    }
}
