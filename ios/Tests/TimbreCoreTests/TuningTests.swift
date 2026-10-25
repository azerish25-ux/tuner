import XCTest
@testable import TimbreCore

final class TuningTests: XCTestCase {
    func testRequiresFullContinuous650MillisecondHold() {
        let tracker = TuningTracker()
        for ms in stride(from: 0, through: 600, by: 50) {
            let reading = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: ms)
            XCTAssertFalse(reading.inTune)
            XCTAssertEqual(reading.status, .settling)
        }
        let confirmed = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 650)
        XCTAssertTrue(confirmed.inTune)
        XCTAssertTrue(confirmed.stable)
        XCTAssertEqual(confirmed.status, .inTune)
    }
    func testLowConfidenceAndMissingFramesClearHoldAndNumbers() {
        let tracker = TuningTracker()
        _ = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 0)
        let uncertain = tracker.accept(frequency: 440, confidence: 0.74, target: 440, timestampMs: 600)
        XCTAssertNil(uncertain.frequency)
        XCTAssertNil(uncertain.cents)
        XCTAssertEqual(uncertain.status, .uncertain)
        XCTAssertFalse(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 650).inTune)
        let absent = tracker.accept(frequency: nil, confidence: 0, target: 440, timestampMs: 700)
        XCTAssertEqual(absent.status, .noSignal)
        XCTAssertFalse(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 1350).inTune)
    }
    func testClassificationUsesTargetInsteadOfNearestChromaticNote() {
        let tracker = TuningTracker()
        let wrongNote = tracker.accept(frequency: 466.1637615, confidence: 1, target: 440, timestampMs: 0)
        XCTAssertEqual(wrongNote.cents!, 100, accuracy: 0.0001)
        XCTAssertEqual(wrongNote.status, .sharp)
        XCTAssertEqual(tracker.accept(frequency: 430, confidence: 1, target: 440, timestampMs: 50).status, .flat)
    }
    func testTargetChangesAndClockReversalRestartHold() {
        let tracker = TuningTracker()
        _ = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 1000)
        XCTAssertFalse(tracker.accept(frequency: 220, confidence: 1, target: 220, timestampMs: 1650).inTune)
        XCTAssertFalse(tracker.accept(frequency: 220, confidence: 1, target: 220, timestampMs: 0).inTune)
    }
    func testStabilityRequiresThreeAgreeingFramesAndResets() {
        let tracker = StabilityTracker()
        XCTAssertFalse(tracker.update(440))
        XCTAssertFalse(tracker.update(440.1))
        XCTAssertTrue(tracker.update(439.9))
        XCTAssertFalse(tracker.update(450))
        XCTAssertFalse(tracker.update(nil))
        XCTAssertEqual(tracker.consecutiveFrames, 0)
    }
    func testCadenceStateChangeReanchorsAndClockReversalPublishes() {
        let cadence = ReadingCadence()
        XCTAssertTrue(cadence.shouldPublish(nowMs: 0))
        XCTAssertFalse(cadence.shouldPublish(nowMs: 10))
        XCTAssertTrue(cadence.shouldPublish(nowMs: 20, force: true))
        XCTAssertFalse(cadence.shouldPublish(nowMs: 50))
        XCTAssertTrue(cadence.shouldPublish(nowMs: 70))
        XCTAssertTrue(cadence.shouldPublish(nowMs: 0))
    }
    func testAdaptiveWindowCoversPianoLowTuningMargin() {
        XCTAssertEqual(AnalysisWindowPolicy.windowSizeFor(minFrequencyHz: 82.41, sampleRateHz: 48000), 2048)
        XCTAssertEqual(AnalysisWindowPolicy.windowSizeFor(minFrequencyHz: 41.2, sampleRateHz: 48000), 4096)
        XCTAssertEqual(AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: 20, sampleRateHz: 48000), 8192)
        XCTAssertEqual(AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: 20, sampleRateHz: 48000, preferredWindow: 2048), 8192)
        XCTAssertTrue(AnalysisWindowPolicy.covers(minFrequencyHz: 20, sampleRateHz: 48000, windowSize: 8192))
    }
    func testPrecisionBandDecidesWhereAHoldStarts() {
        // Four cents sharp settles toward a lock at Beginner (±5¢) but is simply sharp at Standard (±3¢) and Pro (±1¢).
        let fourSharp = 440 * pow(2, 4.0 / 1200)
        let expected: [(TuningPrecision, TuningStatus)] = [(.beginner, .settling), (.standard, .sharp), (.pro, .sharp)]
        for (precision, status) in expected {
            let tracker = TuningTracker(bandCents: precision.bandCents)
            XCTAssertEqual(tracker.accept(frequency: fourSharp, confidence: 1, target: 440, timestampMs: 0).status, status, "\(precision)")
        }
        // Pro still locks after the full hold inside ±1¢.
        let pro = TuningTracker(bandCents: TuningPrecision.pro.bandCents)
        let close = 440 * pow(2, -0.6 / 1200)
        for ms in stride(from: 0, to: InTuneRule.holdMs, by: 50) {
            XCTAssertFalse(pro.accept(frequency: close, confidence: 1, target: 440, timestampMs: ms).inTune)
        }
        XCTAssertTrue(pro.accept(frequency: close, confidence: 1, target: 440, timestampMs: InTuneRule.holdMs).inTune)
        // Leaving the band ends the hold.
        XCTAssertEqual(pro.accept(frequency: 440 * pow(2, 1.5 / 1200), confidence: 1, target: 440, timestampMs: InTuneRule.holdMs + 50).status, .sharp)
        // A nonsensical band falls back to the default rather than never (or always) locking.
        let broken = TuningTracker(bandCents: .nan)
        XCTAssertEqual(broken.accept(frequency: fourSharp, confidence: 1, target: 440, timestampMs: 0).status, .settling)
    }
    func testPrecisionSettingIsOptionalAndDefaultsToBeginner() throws {
        XCTAssertEqual(UserSettings().precision, .beginner)
        XCTAssertEqual(UserSettings().precision.bandCents, InTuneRule.bandCents)
        // A save from before the setting existed has no key at all and still decodes.
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(UserSettings())) as? [String: Any])
        old.removeValue(forKey: "tuningPrecision")
        XCTAssertEqual(try JSONDecoder().decode(UserSettings.self, from: JSONSerialization.data(withJSONObject: old)).precision, .beginner)
        var settings = UserSettings()
        settings.precision = .pro
        let reopened = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(reopened.precision, .pro)
        XCTAssertEqual(reopened.precision.bandCents, 1)
        XCTAssertEqual(TuningPrecision.standard.bandCents, 3)
        // A value from a later version reads as Beginner instead of failing.
        settings.tuningPrecision = "future"
        XCTAssertEqual(settings.precision, .beginner)
    }
    func testUnobservedGapCannotCountAsContinuousHold() {
        let tracker = TuningTracker()
        _ = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 0)
        XCTAssertFalse(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 650).inTune)
        for ms in stride(from: 700, through: 1300, by: 50) {
            _ = tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: ms)
        }
        XCTAssertTrue(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 1350).inTune)
    }

    /// Locks `tracker` on 440 Hz with readings every 50 ms from `start`; returns the time of the locking reading.
    private func lock(_ tracker: TuningTracker, from start: Int = 0) -> Int {
        for ms in stride(from: start, to: start + InTuneRule.holdMs, by: 50) {
            XCTAssertFalse(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: ms).inTune)
        }
        let locked = start + InTuneRule.holdMs
        XCTAssertTrue(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: locked).inTune)
        return locked
    }

    func testALockSurvivesAShortGapWithTheBandEitherSide() {
        let tracker = TuningTracker()
        let locked = lock(tracker)
        // 200 ms with no reading (a busy moment), then the string is still in the band: still in tune.
        let after = tracker.accept(frequency: 440 * pow(2, 1.0 / 1200), confidence: 1, target: 440, timestampMs: locked + 200)
        XCTAssertTrue(after.inTune)
        XCTAssertEqual(after.status, .inTune)
        XCTAssertTrue(tracker.accept(frequency: 440, confidence: 1, target: 440, timestampMs: locked + 250).inTune)
    }

    func testAGapNeverCountsTowardAHoldOrKeepsALockThatLeftTheBand() {
        // Before the lock: a 200 ms gap starts the hold again.
        let building = TuningTracker()
        _ = building.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 0)
        _ = building.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 450)
        XCTAssertEqual(building.accept(frequency: 440, confidence: 1, target: 440, timestampMs: 650).status, .settling)
        // After the lock: a gap followed by a pitch outside the band ends it.
        let outside = TuningTracker()
        let locked = lock(outside)
        XCTAssertEqual(outside.accept(frequency: 440 * pow(2, 9.0 / 1200), confidence: 1, target: 440, timestampMs: locked + 200).status, .sharp)
        XCTAssertFalse(outside.accept(frequency: 440, confidence: 1, target: 440, timestampMs: locked + 250).inTune)
        // A silence longer than the lock may bridge starts the hold again.
        let silent = TuningTracker()
        let held = lock(silent)
        XCTAssertEqual(silent.accept(frequency: 440, confidence: 1, target: 440, timestampMs: held + InTuneRule.lockGapMs + 50).status, .settling)
        // So does a reading with no pitch inside the gap, or another string.
        let quiet = TuningTracker()
        let quietLock = lock(quiet)
        XCTAssertEqual(quiet.accept(frequency: nil, confidence: 0, target: 440, timestampMs: quietLock + 100).status, .noSignal)
        XCTAssertFalse(quiet.accept(frequency: 440, confidence: 1, target: 440, timestampMs: quietLock + 300).inTune)
        let other = TuningTracker()
        let otherLock = lock(other)
        XCTAssertFalse(other.accept(frequency: 220, confidence: 1, target: 220, timestampMs: otherLock + 200).inTune)
    }

    func testStatusIsATypedValueThatReadsItsOldNames() throws {
        let reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
        XCTAssertEqual(reading.status, .noSignal)
        XCTAssertEqual(TuningStatus(stringLiteral: "not a status"), .uncertain)
        for status in TuningStatus.allCases {
            let data = try JSONEncoder().encode([status])
            XCTAssertEqual(String(data: data, encoding: .utf8), "[\"\(status.rawValue)\"]")
            XCTAssertEqual(try JSONDecoder().decode([TuningStatus].self, from: data), [status])
        }
    }
}

