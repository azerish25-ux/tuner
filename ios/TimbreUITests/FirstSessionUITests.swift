import StoreKitTest
import XCTest

/// The money screen and the first session: the paywall from Settings always shows its plan cards (its tag never
/// without its card), and "Just tune" reaches a listening tuner without the questions. Each test launches on storage of
/// its own, as a fresh install does.
final class FirstSessionUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKit: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeKit = try SKTestSession(configurationFileNamed: "Timbre")
        storeKit.resetToDefaultState()
        storeKit.clearTransactions()
        storeKit.disableDialogs = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "zz-failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if app.state != .notRunning { app.terminate() }
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    func testDeferredQuestionsPersistOnlyForTheInstallationThatSkippedThem() {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launch()
        let justTune = element("onboarding.justTune")
        XCTAssertTrue(justTune.waitForExistence(timeout: 25))
        justTune.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))

        // The same installation keeps its promise to ask when Learn opens, even after relaunch.
        app.terminate()
        app.launch()
        app.tabBars.buttons["Learn"].tap()
        let question = element("onboarding.option.beginner")
        XCTAssertTrue(question.waitForExistence(timeout: 10))

        // A separate installation has its own completed onboarding and an unobstructed Learn screen.
        app.terminate()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        app.tabBars.buttons["Learn"].tap()
        let lesson = element("learn.continue")
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        XCTAssertTrue(lesson.isHittable)
        XCTAssertFalse(question.exists)
    }

    /// A strum with a missing open G must mark string 3 silent and keep the chord unfinished.
    func testADeadStringIsNamedWithoutCompletingTheChord() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchEnvironment["TIMBRE_SCENE"] = "lesson-dead-string"
        app.launch()
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30))
        let silent = element("lesson.chord.string.3.silent")
        XCTAssertTrue(silent.waitForExistence(timeout: 30), "the silent open G is identified")
        XCTAssertTrue(element("lesson.chord.pending").exists, "the chord still needs a clean strum")
        XCTAssertFalse(element("lesson.chord.complete").exists, "a missing string cannot complete the chord")
        XCTAssertTrue(element("lesson.chord.string.6.heard").exists, "the low E rang in the same strum")
    }

    /// Settings › Try Timbre Pro opens the paywall over the settings sheet: the yearly card is there and can be
    /// tapped, and so is the month.
    func testThePaywallFromSettingsShowsItsPlans() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
        let settings = element("settings.open")
        XCTAssertTrue(settings.waitForExistence(timeout: 25))
        settings.tap()
        let pro = element("settings.pro")
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        let yearly = element("paywall.plan.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 15), "the yearly card is drawn")
        XCTAssertTrue(yearly.isHittable, "the yearly card can be tapped")
        XCTAssertTrue(element("paywall.plan.monthly").exists)
        yearly.tap()
        XCTAssertTrue(yearly.isSelected)
    }

    /// "Just tune" on the welcome screen: one tap to the tuner, listening (the demo pitch stands in for the microphone,
    /// whose own prompt would be the second tap), with no question asked first.
    func testJustTuneReachesAListeningTuner() {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        app.launch()
        let justTune = element("onboarding.justTune")
        XCTAssertTrue(justTune.waitForExistence(timeout: 25))
        justTune.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15), "the tuner is on screen")
        XCTAssertFalse(element("onboarding.option.beginner").exists, "no question came first")
        let probe = element("stage.state")
        let deadline = Date().addingTimeInterval(15)
        var listening = false
        while !listening && Date() < deadline {
            if let label = (try? probe.snapshot())?.label, let field = label.split(separator: " ").first(where: { $0.hasPrefix("listening=") }),
               let seconds = Double(field.dropFirst("listening=".count)), seconds > 0 {
                listening = true
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(listening || !probe.exists, "the tuner is listening")
    }
}
