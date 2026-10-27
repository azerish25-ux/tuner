import StoreKitTest
import XCTest

/// The pull-request gate's focused flows (.github/workflows/ios.yml, job `app`): a fresh install opens on the welcome,
/// the tuner hears a string and locks it, its Quest remains noninteractive text, and buying Timbre Pro unlocks a Pro tool.
/// Each runs on storage of its own and touches only what it proves; the full tour with its captures runs nightly
/// (TimbreUITests, nightly.yml).
final class SmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "smoke-failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func settle(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    /// Swipes until the element is on screen and hittable (down the list, then back up).
    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) { app.swipeUp(velocity: .slow) }
        for _ in 0..<12 where !(target.exists && target.isHittable) { app.swipeDown(velocity: .slow) }
        settle(1)
    }

    func testAFreshInstallOpensOnTheWelcome() {
        app.launch()
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 40), "the welcome screen didn't appear")
        XCTAssertTrue(start.isHittable)
    }

    /// The fraction's RTL layout container must not turn a plain progress sentence into a tap target.
    func testTuningQuestIsOneStaticTextElementNotAnInteractiveTarget() throws {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40))
        let quests = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Quest · tune every string, 0 of 6, +20 XP"))
        XCTAssertTrue(quests.firstMatch.waitForExistence(timeout: 10))
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "quest-static-text-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "quest-static-text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(quests.count, 1, "The entire Quest sentence must be spoken once")
        let quest = quests.firstMatch
        XCTAssertEqual(quest.elementType, .staticText, "A counter is text, not an interactive container")
        XCTAssertEqual(quest.label, "Quest · tune every string, 0 of 6, +20 XP")
        // XCTest preserves raw descendants even for SwiftUI .combine/.ignore. The native tree
        // contains one combined StaticText with its title and fraction beneath it, not sibling utterances.
        let heading = "Quest · tune every string"
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", heading)).count, 1)
        XCTAssertEqual(quest.staticTexts.matching(NSPredicate(format: "label == %@", heading)).count, 1)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "0 of 6")).count, 1)
        XCTAssertEqual(quest.staticTexts.matching(NSPredicate(format: "label == %@", "0 of 6")).count, 1)
        try app.performAccessibilityAudit(for: .hitRegion)
    }

    /// Progress has unearned badge buttons at compact and regular widths; Practice's next-badge card is iPad-only.
    func testFractionInsideAnUnearnedBadgePreservesItsButtonRole() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launch()
        let progress = app.tabBars.buttons["Progress"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 40))
        progress.tap()
        let badge = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND value CONTAINS %@", "badge.", " of ")).firstMatch
        scrollTo(badge)
        XCTAssertTrue(badge.exists && badge.isHittable, "Require a real unearned badge, not an absent conditional card")
        XCTAssertEqual(badge.elementType, .button, "A fraction inside a real action must not replace its Button role")
        let counter = badge.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+ of [0-9]+")).firstMatch
        XCTAssertTrue(counter.exists, "The tested Button must actually contain the production fraction")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "fraction-enclosing-button-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    /// The demo pitch (TIMBRE_DEMO_PITCH, debug builds) plays the selected string drifting into tune every six seconds;
    /// the tuner's own tracker must lock it, which ticks the string's chip ("Tuned").
    func testTheTunerLocksAString() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40), "the tuner didn't open")
        let strings = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "string."))
        XCTAssertTrue(strings.firstMatch.waitForExistence(timeout: 10), "string controls lost their individual accessibility identifiers")
        let tuned = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "string.", "Tuned")).firstMatch
        // Listening starts by itself once the microphone is allowed (the workflow grants it); start it by hand if not.
        // The button reads "Listen" while it isn't listening and "Pause listening" while it is.
        settle(4)
        let listen = element("listenButton")
        if !tuned.exists, listen.exists, listen.label == "Listen" { listen.tap() }
        // Hands off while the hold runs: a query stalls the app's main thread, and a gap in the readings restarts it.
        settle(8)
        XCTAssertTrue(tuned.waitForExistence(timeout: 30), "no string locked on the demo pitch")
    }

    /// The drone is a Pro tool: on the free plan it opens the paywall. The StoreKit configuration in the scheme
    /// (Tests/Fixtures/Timbre.storekit) completes the purchase without a dialog, and the drone then opens.
    func testBuyingProUnlocksAProTool() throws {
        // The unit tests ran purchases in this simulator's StoreKit environment first: start from no transactions.
        let session = try SKTestSession(configurationFileNamed: "Timbre")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
        let practice = app.tabBars.buttons["Practice"].firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 40), "no Practice tab")
        practice.tap()
        settle(1.5)
        let drone = element("practice.drone")
        scrollTo(drone)
        drone.tap()
        let purchase = element("paywall.purchase")
        XCTAssertTrue(purchase.waitForExistence(timeout: 20), "the drone didn't ask for Pro")
        settle(1.5)
        scrollTo(purchase)
        purchase.tap()
        // StoreKit testing can take a minute on a busy runner: wait for the paywall itself to go.
        XCTAssertTrue(purchase.waitForNonExistence(timeout: 150), "the paywall stayed up after the purchase")
        XCTAssertTrue(drone.waitForExistence(timeout: 20))
        settle(1.5)
        scrollTo(drone)
        drone.tap()
        XCTAssertTrue(element("drone.start").waitForExistence(timeout: 15), "the drone is still locked after buying Pro")
        XCTAssertFalse(element("paywall.purchase").exists, "the paywall came back")
    }
}

/// How long a cold launch takes (`XCTApplicationLaunchMetric`), measured nightly against the run's baseline.
final class LaunchPerformanceUITests: XCTestCase {
    func testLaunchTime() {
        let app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
            app.launch()
            app.terminate()
        }
    }
}
