import XCTest
@testable import TimbreCore
final class PostTuningAdPolicyTests: XCTestCase {
    private func claim(_ p: PostTuningAdPolicy, id: String = "session", now: Int = 20000, entitlement: AdEntitlement = .free, consent: Bool = true, ready: Bool = true, foreground: Bool = true, duration: Int = 20000, stable: Int = 10) -> Bool {
        p.claimCompletion(sessionId: id, durationMs: duration, stableReadingCount: stable, elapsedRealtimeMs: now, entitlement: entitlement, canRequestAds: consent, adReady: ready, foreground: foreground)
    }
    func testOnlyExplicitMeasuredEligibleFreeCompletionsClaim() {
        XCTAssertTrue(claim(PostTuningAdPolicy()))
        XCTAssertFalse(claim(PostTuningAdPolicy(), duration: 14999))
        XCTAssertFalse(claim(PostTuningAdPolicy(), stable: 2))
        XCTAssertTrue(claim(PostTuningAdPolicy(), duration: 15000, stable: 3))
        for state in [AdEntitlement.unknown, .pending, .paid, .reviewAccess] { XCTAssertFalse(claim(PostTuningAdPolicy(), entitlement: state)) }
        for state in [AdEntitlement.expired, .refunded] { XCTAssertTrue(claim(PostTuningAdPolicy(), entitlement: state)) }
        XCTAssertFalse(claim(PostTuningAdPolicy(), consent: false))
        XCTAssertFalse(claim(PostTuningAdPolicy(), ready: false))
        XCTAssertFalse(claim(PostTuningAdPolicy(), foreground: false))
    }
    func testSkippedCompletionsCannotSurpriseUserLater() {
        let p = PostTuningAdPolicy()
        XCTAssertFalse(claim(p, ready: false))
        XCTAssertFalse(claim(p, now: 300000))
    }
    func testCooldownAndReplayProtection() {
        let p = PostTuningAdPolicy()
        XCTAssertTrue(claim(p))
        XCTAssertFalse(claim(p, id: "second", now: 139999))
        XCTAssertFalse(claim(p, id: "second", now: 300000))
        XCTAssertTrue(claim(p, id: "third", now: 140000))
        XCTAssertFalse(claim(p, id: "fourth", now: 0))
        XCTAssertFalse(claim(p, now: 500000))
    }
    func testInvalidIDsAndBoundedMemorySuppressRatherThanEvict() {
        let p = PostTuningAdPolicy()
        XCTAssertFalse(claim(p, id: " "))
        XCTAssertFalse(claim(p, id: String(repeating: "a", count: 129)))
        XCTAssertFalse(claim(p, now: -1))
        for index in 0..<1024 { XCTAssertFalse(claim(p, id: "skip-\(index)", ready: false)) }
        XCTAssertFalse(claim(p, id: "new", now: 900000))
        XCTAssertFalse(claim(p, id: "skip-0", now: 900000))
    }
}

