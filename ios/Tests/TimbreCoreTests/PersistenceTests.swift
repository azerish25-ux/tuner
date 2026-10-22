import Foundation
import XCTest
@testable import TimbreCore

final class PersistenceTests: XCTestCase {
    func testHistoryIsRetainedUntilExplicitDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(directory: directory)
        for index in 0..<502 {
            try store.append(PracticeRecord(date: Date(timeIntervalSince1970: Double(index)), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 3, stableCount: 2, durationMs: 2000))
        }
        XCTAssertEqual(try LocalStore(directory: directory).records.count, 502)
        try store.clearHistory()
        XCTAssertTrue(try LocalStore(directory: directory).records.isEmpty)
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func testSettingsAndRecordsSurviveReopen() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        var settings = store.settings
        settings.referencePitchHz = 442; settings.hapticsEnabled = false
        settings.lastTuningIds = ["guitar.acoustic.6": "guitar.drop-d"]
        try store.saveSettings(settings)
        let record = PracticeRecord(instrumentId: "guitar.acoustic.6", kind: "tuner", count: 20, stableCount: 15, meanAbsoluteCents: 12.5)
        try store.append(record)
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.settings, settings)
        XCTAssertEqual(reopened.records, [record])
        XCTAssertTrue(reopened.demonstratedLevels.isEmpty)
    }
    func testFailedWriteDoesNotChangeMemory() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        // A directory at the file destination reliably rejects an atomic file replacement.
        try FileManager.default.createDirectory(at: directory.appendingPathComponent(LocalStore.fileName), withIntermediateDirectories: true)
        var settings = store.settings; settings.referencePitchHz = 442
        XCTAssertThrowsError(try store.saveSettings(settings))
        XCTAssertEqual(store.settings.referencePitchHz, 440)
        XCTAssertThrowsError(try store.append(PracticeRecord(instrumentId: "test", kind: "tuner", count: 1, stableCount: 1)))
        XCTAssertTrue(store.records.isEmpty)
    }
    func testCorruptionIsReportedWithoutSilentlyResettingFile() throws {
        let directory = try directory(), url = directory.appendingPathComponent(LocalStore.fileName)
        let bytes = Data("not valid JSON".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try LocalStore(directory: directory))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testInvalidUpdateDoesNotReplaceSavedState() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        try store.saveSettings(store.settings)
        var settings = store.settings; settings.confidenceThreshold = .nan
        XCTAssertThrowsError(try store.saveSettings(settings))
        XCTAssertEqual(try LocalStore(directory: directory).settings.confidenceThreshold, 0.75)
        XCTAssertThrowsError(try store.append(PracticeRecord(instrumentId: "guitar", kind: "tuner", count: 1, stableCount: 2)))
    }
    func testHistoryClearIsPersistedAndRetainsSettings() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        var settings = store.settings; settings.reducedMotion = true
        try store.saveSettings(settings)
        try store.append(PracticeRecord(instrumentId: "guitar", kind: "tuner", count: 0, stableCount: 0))
        try store.clearHistory()
        let reopened = try LocalStore(directory: directory)
        XCTAssertTrue(reopened.records.isEmpty)
        XCTAssertTrue(reopened.demonstratedLevels.isEmpty)
        XCTAssertTrue(reopened.settings.reducedMotion)
    }
    func testOnlyMeasuredCurrentVoiceEvidenceAdvancesProgress() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        let exercise = VoiceExercise(level: 4), attempt = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for index in 0..<110 { attempt.accept(frequency: 220, stable: true, elapsedMs: index * 50) }
        let result = attempt.finish()
        XCTAssertTrue(result.demonstrated)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: "voice.pitch.v1.4", kind: "voice", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertTrue(store.demonstratedLevels.isEmpty)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: exercise.id, kind: "tuner", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertTrue(store.demonstratedLevels.isEmpty)
        try store.append(PracticeRecord(instrumentId: "voice", tuningId: exercise.id, kind: "voice", count: 110, stableCount: 110, voiceResult: result))
        XCTAssertEqual(store.demonstratedLevels, [4])
        XCTAssertEqual(try LocalStore(directory: directory).demonstratedLevels, [4])
    }
    func testRecentSelectionsBoundedAndDeduplicatedInOrder() throws {
        let store = try LocalStore(directory: directory())
        var settings = store.settings
        settings.recentInstrumentIds = ["a", "b", "a"] + (0..<20).map(String.init)
        try store.saveSettings(settings)
        XCTAssertEqual(store.settings.recentInstrumentIds.count, LocalStore.recentInstrumentLimit)
        XCTAssertEqual(Array(store.settings.recentInstrumentIds.prefix(2)), ["a", "b"])
    }
    func testReferencePitchAndWrittenTranspositionEnforceSourceBounds() throws {
        let directory = try directory(), store = try LocalStore(directory: directory)
        for pitch in [415.0, 466.0] {
            var settings = store.settings; settings.referencePitchHz = pitch
            try store.saveSettings(settings)
            XCTAssertEqual(try LocalStore(directory: directory).settings.referencePitchHz, pitch)
        }
        for pitch in [414.999, 466.001, 300, 500] {
            var settings = store.settings; settings.referencePitchHz = pitch
            XCTAssertThrowsError(try store.saveSettings(settings))
            XCTAssertEqual(store.settings.referencePitchHz, 466)
        }
        for transposition in [-12, 12] {
            var settings = store.settings; settings.transposition = transposition
            try store.saveSettings(settings)
            XCTAssertEqual(try LocalStore(directory: directory).settings.transposition, transposition)
        }
        for transposition in [-24, -13, 13, 24] {
            var settings = store.settings; settings.transposition = transposition
            XCTAssertThrowsError(try store.saveSettings(settings))
            XCTAssertEqual(store.settings.transposition, 12)
        }
    }
}
