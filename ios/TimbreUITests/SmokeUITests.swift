import XCTest

/// The pull-request gate's three flows (.github/workflows/ios.yml, job `app`): a fresh install opens on the welcome,
/// the tuner hears a string and locks it, and buying Timbre Pro unlocks a Pro tool. Each runs on storage of its own
/// and touches only what it proves, so the three fit the gate's budget; the full tour with its captures runs nightly
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

    /// The demo pitch (TIMBRE_DEMO_PITCH, debug builds) plays the selected string drifting into tune every six seconds;
    /// the tuner's own tracker must lock it, which ticks the string's chip ("Tuned").
    func testTheTunerLocksAString() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40), "the tuner didn't open")
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
    func testBuyingProUnlocksAProTool() {
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
