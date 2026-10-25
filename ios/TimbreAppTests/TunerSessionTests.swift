import Combine
import Observation
import XCTest
import TimbreCore
@testable import Timbre

/// The tuner's state (`TunerSession`): what it tunes to, its locks and its session record, observed apart from the
/// store so a reading redraws only what reads it.
@MainActor
final class TunerSessionTests: XCTestCase {
    private func reading(cents: Double?, stable: Bool = true) -> TuningReading {
        TuningReading(frequency: cents == nil ? nil : 440, cents: cents, stable: stable, inTune: false, status: "flat")
    }

    func testAutomaticDetectionMovesAfterThreeReadingsRunning() {
        let tuner = TunerSession()
        XCTAssertFalse(tuner.heard(course: 2))
        XCTAssertFalse(tuner.heard(course: 2))
        XCTAssertTrue(tuner.heard(course: 2))
        XCTAssertEqual(tuner.selectedCourse, 2)
        XCTAssertFalse(tuner.heard(course: 2), "already on it")
        XCTAssertFalse(tuner.heard(course: 3))
        tuner.heardNothing()
        XCTAssertFalse(tuner.heard(course: 3))
        XCTAssertFalse(tuner.heard(course: 3))
        XCTAssertTrue(tuner.heard(course: 3), "a gap starts the run again")
    }

    func testTheLastStringToLockCompletesTheTuneOnce() {
        let tuner = TunerSession()
        let strings = [1, 2, 3]
        var lock = tuner.lock(1, of: strings)
        XCTAssertTrue(lock.fresh)
        XCTAssertFalse(lock.completed)
        lock = tuner.lock(1, of: strings)
        XCTAssertFalse(lock.fresh || lock.completed, "a string locks once a session")
        _ = tuner.lock(2, of: strings)
        lock = tuner.lock(3, of: strings)
        XCTAssertTrue(lock.fresh && lock.completed)
        XCTAssertTrue(tuner.allLocked(strings))
        XCTAssertEqual(tuner.lockAll(strings), [], "nothing left to lock")
        tuner.resetMeasurements()
        XCTAssertEqual(tuner.lockedCourses, [])
        XCTAssertEqual(tuner.lockAll(strings), strings)
    }

    func testASessionIsWorthARecordAfterThreeReadingsAndFourSeconds() {
        let tuner = TunerSession()
        let start = Date(timeIntervalSince1970: 1_000)
        tuner.beginSession(at: start, uptime: 100)
        tuner.beginSession(at: Date(), uptime: 200)
        for cents in [3.0, -1.0, 2.0] { tuner.count(reading(cents: cents)) }
        tuner.count(reading(cents: nil))
        tuner.count(reading(cents: 9, stable: false))
        XCTAssertNil(tuner.summary(uptime: 103.9), "under four seconds")
        let summary = tuner.summary(uptime: 106)
        XCTAssertEqual(summary?.started, start, "a session already running keeps its start")
        XCTAssertEqual(summary?.readings, 4, "a reading with no pitch isn't counted")
        XCTAssertEqual(summary?.stableReadings, 3)
        XCTAssertEqual(summary?.meanAbsoluteCents ?? 0, 2, accuracy: 1e-9)
        XCTAssertEqual(summary?.durationMs, 6_000)
        tuner.gameTargetHz = 440
        tuner.count(reading(cents: 1))
        XCTAssertEqual(tuner.readingCount, 4, "a game's readings never count as tuning")
        tuner.restartMeasuring(listening: false)
        XCTAssertNil(tuner.summary(uptime: 106))
    }

    func testChromaticNotesStayInRange() {
        let tuner = TunerSession()
        tuner.startChromatic()
        XCTAssertTrue(tuner.referenceMode && tuner.automatic)
        tuner.heard(note: 200)
        XCTAssertEqual(tuner.referenceMidi, 119)
        tuner.choose(referenceNote: 3)
        XCTAssertEqual(tuner.referenceMidi, 12)
        XCTAssertFalse(tuner.automatic, "a note chosen by hand stays")
    }

    /// A view reading `store.selectedCourse` is told when automatic detection moves the string; the store itself
    /// publishes nothing, so no other screen redraws.
    func testAStringChangeReachesItsReadersAndNoOtherScreen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        store.automatic = true
        let a = try XCTUnwrap(store.courses.first { $0.label == "A2" })
        XCTAssertNotEqual(store.selectedCourse, a.index)
        var storeChanges = 0
        let watcher = store.objectWillChange.sink { _ in storeChanges += 1 }
        let observed = expectation(description: "a reader of store.selectedCourse is told")
        withObservationTracking { _ = store.selectedCourse } onChange: { observed.fulfill() }
        for _ in 0..<5 { store.accept(store.target(for: a), confidence: 0.95, level: -30) }
        XCTAssertEqual(store.selectedCourse, a.index)
        XCTAssertEqual(storeChanges, 0, "the store published nothing")
        watcher.cancel()
        wait(for: [observed], timeout: 1)
    }
}
