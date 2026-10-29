import XCTest
import TimbreCore
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

    func testJustTuneCompletionIsOnDiskBeforeItsActionReturns() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        let storageID = UUID().uuidString
        let questions = OnboardingDeferral(defaults: defaults, storageID: storageID)
        questions.deferQuestions()

        store.completeTunerOnboarding()

        // Reopen synchronously: no sleep, run-loop turn, background scene transition, or test-only flush.
        // The production action itself must have persisted the welcome dismissal.
        let reopened = try LocalStore(directory: directory)
        XCTAssertEqual(reopened.settings.onboardingCompleted, true)
        XCTAssertTrue(OnboardingDeferral(defaults: defaults, storageID: storageID).pending)
        XCTAssertFalse(OnboardingDeferral(defaults: defaults, storageID: UUID().uuidString).pending)
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
