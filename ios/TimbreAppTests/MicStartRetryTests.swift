import XCTest
@testable import Timbre

/// The microphone's second try (`MicStartRetry`): a start the audio refused for a moment goes once more; a refusal a
/// moment won't change, or a second failure, reaches the alert.
@MainActor
final class MicStartRetryTests: XCTestCase {
    /// The engine's unspecified failure, 'what' (com.apple.coreaudio.avfaudio 2003329396).
    private var unspecified: NSError { NSError(domain: "com.apple.coreaudio.avfaudio", code: 2_003_329_396) }

    func testAnUnspecifiedEngineFailureGoesOnceMore() {
        XCTAssertTrue(MicStartRetry.shouldRetry(after: unspecified, attempt: 0))
    }

    func testTheSecondFailureReachesTheAlert() {
        XCTAssertFalse(MicStartRetry.shouldRetry(after: unspecified, attempt: 1))
    }

    func testAMissingMicrophoneIsNotRetriedButMissingOutputIs() {
        XCTAssertFalse(MicStartRetry.shouldRetry(after: AudioFailure.noInput, attempt: 0))
        XCTAssertTrue(MicStartRetry.shouldRetry(after: AudioFailure.noOutput, attempt: 0))
    }

    func testRefusalsAMomentWontChangeAreNotRetried() {
        // '!pri' (a call holds the hardware), 'siri', '!rec' (recording not allowed), '!cat', 'ent?', and -50.
        for code in [561_017_449, 1_936_290_409, 561_145_187, 560_161_140, 1_701_737_535, -50] {
            let error = NSError(domain: NSOSStatusErrorDomain, code: code)
            XCTAssertFalse(MicStartRetry.shouldRetry(after: error, attempt: 0), "code \(code)")
        }
    }

    func testABusyOrInactiveSessionGoesOnceMore() {
        // '!act' (busy: I/O still running), 'inac' (the session isn't active).
        for code in [560_030_580, 1_768_841_571] {
            let error = NSError(domain: NSOSStatusErrorDomain, code: code)
            XCTAssertTrue(MicStartRetry.shouldRetry(after: error, attempt: 0), "code \(code)")
        }
    }
}
