import XCTest
@testable import Timbre

final class PreviewCueTests: XCTestCase {
    func testExplicitMissingCueCannotStartOnTheStandaloneTimer() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertFalse(PreviewTune.cued(since: Date().addingTimeInterval(-120), cuePath: missing.path))
    }

    func testExplicitCueStartsOnceItsFileExists() throws {
        let cue = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: cue)
        defer { try? FileManager.default.removeItem(at: cue) }
        XCTAssertTrue(PreviewTune.cued(since: Date(), cuePath: cue.path))
    }

    func testStandaloneSceneRetainsItsDelayWhenNoCueWasRequested() {
        XCTAssertFalse(PreviewTune.cued(since: Date(), cuePath: nil))
        XCTAssertTrue(PreviewTune.cued(since: Date().addingTimeInterval(-13), cuePath: nil))
    }
}
