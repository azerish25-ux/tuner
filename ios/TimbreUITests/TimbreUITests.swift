import XCTest

/// End-to-end flows that double as a visual tour: every screen is captured so the
/// design can be reviewed from CI results.
final class TimbreUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 { shot("zz-failure-\(name)") }
        app.terminate()
    }

    private func launch(onboarded: Bool = true, demo: Bool = true, studio: Bool = false) {
        app.launchEnvironment["TIMBRE_STAGE_DEBUG"] = "1"
        if onboarded { app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1" }
        if demo { app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1" }
        if studio { app.launchEnvironment["TIMBRE_STAGE_MODE"] = "studio" }
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func tab(_ name: String) { app.tabBars.buttons[name].firstMatch.tap() }
    private func settle(_ seconds: Double = 1.2) { Thread.sleep(forTimeInterval: seconds) }
    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<10 where !(target.exists && target.isHittable) { app.swipeUp() }
    }

    func test01Onboarding() throws {
        launch(onboarded: false, demo: false)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        settle(); shot("01-onboarding-welcome")
        start.tap(); settle(); shot("02-onboarding-instrument")
        element("onboarding.continue").tap(); settle(); shot("03-onboarding-experience")
        element("onboarding.continue").tap(); settle(); shot("04-onboarding-goal")
        element("onboarding.continue").tap(); settle(); shot("05-onboarding-microphone")
        app.buttons["Not now"].tap()
        let free = element("paywall.free")
        XCTAssertTrue(free.waitForExistence(timeout: 15))
        settle(2); shot("06-paywall-onboarding")
        scrollTo(free)
        free.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        settle(2.5); shot("07-tune-first-run")
    }

    func test02TuneScreen() throws {
        launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        settle(3); shot("10-tune-3d")
        let debug = element("stage.debug")
        if debug.waitForExistence(timeout: 10) {
            print("STAGE DEBUG: \(debug.label)")
            let note = XCTAttachment(string: debug.label)
            note.name = "stage-debug"; note.lifetime = .keepAlways
            add(note)
        } else {
            print("STAGE DEBUG: no stage.debug element")
        }
        element("string.3").tap(); settle(1.5); shot("11-tune-string-selected")
        element("tune.instrument").tap(); settle(1.5); shot("12-instrument-picker")
        app.buttons["Done"].firstMatch.tap(); settle()
        element("settings.open").tap(); settle(1.5); shot("13-settings")
        // Pro upsell from inside the settings sheet presents the paywall on top of it.
        element("settings.pro").tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        settle(1.5); shot("16-paywall-from-settings")
    }

    func test03StudioStage() throws {
        launch(studio: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        settle(2); shot("14-tune-studio")
        tab("Instruments"); settle(1.5)
        element("instruments.chromatic").tap(); settle(2); shot("15-tune-chromatic")
    }

    func test04PracticeTour() throws {
        launch()
        tab("Practice"); settle(1.5); shot("20-practice-hub")
        element("practice.metronome").tap(); settle(1.2); shot("21-metronome")
        element("metronome.start").tap(); settle(1.0); shot("22-metronome-running")
        element("metronome.start").tap()
        app.navigationBars.buttons.firstMatch.tap(); settle()
        element("practice.ear").tap(); settle(2); shot("23-ear-training")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.voice"))
        element("practice.voice").tap(); settle(1.5); shot("24-voice-range")
    }

    func test05OtherTabs() throws {
        launch()
        tab("Instruments"); settle(2); shot("30-instruments")
        app.swipeUp(); settle(); shot("31-instruments-scrolled")
        tab("Journey"); settle(2); shot("32-journey")
        app.swipeUp(); settle(); shot("33-journey-scrolled")
    }

    func test06PurchaseUnlocksPro() throws {
        launch()
        tab("Practice"); settle()
        scrollTo(element("practice.drone"))
        element("practice.drone").tap()
        let purchase = element("paywall.purchase")
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        settle(2); shot("40-paywall")
        scrollTo(purchase)
        purchase.tap()
        XCTAssertTrue(element("practice.drone").waitForExistence(timeout: 20))
        settle(2)
        scrollTo(element("practice.drone"))
        element("practice.drone").tap(); settle(1.5); shot("41-drone")
        element("drone.start").tap(); settle(1.5); shot("42-drone-running")
        element("drone.start").tap()
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.chords"))
        element("practice.chords").tap(); settle(1.5); shot("43-chords")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.scales"))
        element("practice.scales").tap(); settle(1.5); shot("44-scales")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        tab("Journey"); settle(2); shot("45-journey-pro")
    }
}
