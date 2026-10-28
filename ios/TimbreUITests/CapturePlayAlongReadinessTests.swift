import XCTest

final class CapturePlayAlongReadinessTests: XCTestCase {
    private typealias Control = CapturePlayAlongReadiness.Control
    private var ready: [Control] {
        [.init(identifier: "lesson.continue", label: "Start"), .init(identifier: "along.tempo.0")]
    }
    private var tuneCheck: [Control] {
        [.init(identifier: "lesson.tunecheck.title"), .init(identifier: "lesson.tunecheck.skip")]
    }

    func testVerifiedStartAndTempoAreReady() {
        XCTAssertEqual(CapturePlayAlongReadiness.observed(ready, startLabel: "Start"), .ready)
    }

    func testLateTuneCheckMustCompleteBeforeReadyCapture() {
        // The prior day's check may expire between the listening question and this microphone step.
        XCTAssertEqual(CapturePlayAlongReadiness.observed(tuneCheck, startLabel: "Start"), .tuneCheck)
        XCTAssertEqual(CapturePlayAlongReadiness.observed([], startLabel: "Start"), .unexpected)
        XCTAssertEqual(CapturePlayAlongReadiness.observed(ready, startLabel: "Start"), .ready)
    }

    func testPartialMixedAndDisabledCheckCannotBeHandledAsTuneCheck() {
        for controls in [Array(tuneCheck.prefix(1)), Array(tuneCheck.suffix(1)), tuneCheck + ready,
                         [tuneCheck[0], Control(identifier: "lesson.tunecheck.skip", enabled: false)]] {
            XCTAssertEqual(CapturePlayAlongReadiness.observed(controls, startLabel: "Start"), .unexpected)
        }
    }

    func testContinuePlayingDoneAndQuestionStatesAreNotReady() {
        for label in ["Continue", "Check", "Listening…", ""] {
            let controls = [Control(identifier: "lesson.continue", label: label), ready[1]]
            XCTAssertEqual(CapturePlayAlongReadiness.observed(controls, startLabel: "Start"), .unexpected)
        }
        for identifier in ["along.again", "lesson.notes.target", "lesson.option.0"] {
            XCTAssertEqual(CapturePlayAlongReadiness.observed(ready + [.init(identifier: identifier)], startLabel: "Start"), .unexpected)
        }
    }

    func testMissingDisabledOrDuplicateControlsCannotProveReadiness() {
        for controls in [Array(ready.prefix(1)), Array(ready.suffix(1)), ready + [ready[0]],
                         [Control(identifier: "lesson.continue", label: "Start", enabled: false), ready[1]],
                         [ready[0], Control(identifier: "along.tempo.0", enabled: false)]] {
            XCTAssertEqual(CapturePlayAlongReadiness.observed(controls, startLabel: "Start"), .unexpected)
        }
    }

    func testStartMustMatchTheRequestedLocaleWithoutEnglishFallback() {
        let localized = [Control(identifier: "lesson.continue", label: "開始"), ready[1]]
        XCTAssertEqual(CapturePlayAlongReadiness.observed(localized, startLabel: "開始"), .ready)
        XCTAssertEqual(CapturePlayAlongReadiness.observed(ready, startLabel: "開始"), .unexpected)
        for missing in [nil, ""] as [String?] {
            XCTAssertEqual(CapturePlayAlongReadiness.observed(ready, startLabel: missing), .unexpected)
        }
    }
}
