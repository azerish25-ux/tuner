import XCTest
@testable import Timbre

@MainActor
final class OnboardingDeferralTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() async throws {
        try await super.setUp()
        suite = "onboarding-deferral-tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        suite = nil
        try await super.tearDown()
    }

    func testFreshStorageDoesNotInheritDeferredQuestionsFromAnotherInstall() {
        let firstID = UUID().uuidString
        OnboardingDeferral(defaults: defaults, storageID: firstID).deferQuestions()

        XCTAssertFalse(OnboardingDeferral(defaults: defaults, storageID: UUID().uuidString).pending)
        XCTAssertTrue(OnboardingDeferral(defaults: defaults, storageID: firstID).pending)
    }

    func testResolvingOneStorageDoesNotResolveAnother() {
        let firstID = UUID().uuidString
        let secondID = UUID().uuidString
        let first = OnboardingDeferral(defaults: defaults, storageID: firstID)
        let second = OnboardingDeferral(defaults: defaults, storageID: secondID)
        first.deferQuestions()
        second.deferQuestions()
        first.resolve()

        XCTAssertFalse(OnboardingDeferral(defaults: defaults, storageID: firstID).pending)
        XCTAssertTrue(OnboardingDeferral(defaults: defaults, storageID: secondID).pending)
    }

    func testNormalLaunchPreservesExistingDeferredAnswerAndResolution() {
        defaults.set(true, forKey: "onboarding.questionsDeferred")
        let normal = OnboardingDeferral(defaults: defaults, storageID: nil)
        XCTAssertTrue(normal.pending)
        normal.resolve()
        XCTAssertFalse(defaults.bool(forKey: "onboarding.questionsDeferred"))
        XCTAssertFalse(OnboardingDeferral(defaults: defaults, storageID: nil).pending)
    }

    func testAutomatedStorageCannotChangeNormalLaunchPreference() {
        defaults.set(true, forKey: "onboarding.questionsDeferred")
        let automated = OnboardingDeferral(defaults: defaults, storageID: UUID().uuidString)
        XCTAssertFalse(automated.pending)
        automated.deferQuestions()
        automated.resolve()
        XCTAssertTrue(OnboardingDeferral(defaults: defaults, storageID: nil).pending)
    }
}
