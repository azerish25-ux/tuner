import Foundation
import XCTest

final class CaptureLockEvidenceTests: XCTestCase {
    private func run(_ times: [Double], unlocked: Set<Int> = []) -> [CaptureLockEvidence.Sample] {
        times.enumerated().map { index, time in
            .init(time: time, locked: !unlocked.contains(index), active: true, target: 146.832, stage: "3d")
        }
    }
    private var continuous: [CaptureLockEvidence.Sample] { run((0...20).map { 100 + Double($0) * 0.1 }) }

    func testFreshContinuousRunPassesInsideSameWindow() {
        XCTAssertTrue(CaptureLockEvidence.held(continuous, since: 100, now: 102.1, stages: ["3d"]))
    }
    func testOneSnapshotCannotProveDuration() {
        XCTAssertFalse(CaptureLockEvidence.held(run([102]), since: 100, now: 102, stages: ["3d"]))
    }
    func testStaleOldAndOverWindowEvidenceFail() {
        XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 100, now: 103, stages: ["3d"]))
        XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 103, now: 103, stages: ["3d"]))
        XCTAssertFalse(CaptureLockEvidence.held(run((0...70).map { 100 + Double($0) * 0.1 }),
                                              since: 100, now: 107.01, stages: ["3d"]))
    }
    func testGapOrUnlockedSampleBreaksContinuity() {
        XCTAssertFalse(CaptureLockEvidence.held(run([100, 100.1, 101, 101.1, 101.2, 102]), since: 100, now: 102, stages: ["3d"]))
        XCTAssertFalse(CaptureLockEvidence.held(run((0...20).map { 100 + Double($0) * 0.1 }, unlocked: [10]),
                                              since: 100, now: 102, stages: ["3d"]))
    }
    func testInactiveOrWrongStageCannotCertify() {
        let inactive = continuous.map { CaptureLockEvidence.Sample(time: $0.time, locked: true, active: false, target: $0.target, stage: $0.stage) }
        XCTAssertFalse(CaptureLockEvidence.held(inactive, since: 100, now: 102, stages: ["3d"]))
        XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 100, now: 102, stages: ["2d"]))
    }
    func testTargetChangeBreaksContinuity() {
        var samples = continuous
        samples[10] = .init(time: 101, locked: true, active: true, target: 196, stage: "3d")
        XCTAssertFalse(CaptureLockEvidence.held(samples, since: 100, now: 102, stages: ["3d"]))
    }
    func testFutureNonfiniteAndOutOfOrderEvidenceFail() {
        XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 100, now: 101.9, stages: ["3d"]))
        XCTAssertFalse(CaptureLockEvidence.held(Array(continuous.reversed()), since: 100, now: 102, stages: ["3d"]))
        var samples = continuous
        samples.append(.init(time: .nan, locked: true, active: true, target: 146, stage: "3d"))
        XCTAssertFalse(CaptureLockEvidence.held(samples, since: 100, now: 102, stages: ["3d"]))
    }
    func testNonfiniteDurationsAndWindowsFail() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 100, now: 102,
                                                  seconds: invalid, window: 7, stages: ["3d"]))
            XCTAssertFalse(CaptureLockEvidence.held(continuous, since: 100, now: 102,
                                                  seconds: 1.5, window: invalid, stages: ["3d"]))
        }
    }
    func testDuplicateTimestampsCannotCountAsFreshEvidence() {
        var samples = continuous
        samples.insert(samples[10], at: 10)
        XCTAssertFalse(CaptureLockEvidence.held(samples, since: 100, now: 102, stages: ["3d"]))
    }
    func testMalformedCompleteRecordFailsButPartialTailWaits() throws {
        let row = try XCTUnwrap(String(data: try JSONEncoder().encode(continuous[0]), encoding: .utf8))
        XCTAssertEqual(CaptureLockEvidence.samples(Data((row + "\n{partial").utf8)).count, 1)
        XCTAssertTrue(CaptureLockEvidence.samples(Data((row + "\n{bad}\n").utf8)).isEmpty)
    }
}
