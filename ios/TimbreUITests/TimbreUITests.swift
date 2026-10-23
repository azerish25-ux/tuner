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

    private func launch(onboarded: Bool = true, demo: Bool = true, studio: Bool = false, pitch: Bool = false, stageDebug: Bool = false) {
        if stageDebug { app.launchEnvironment["TIMBRE_STAGE_DEBUG"] = "1" }
        if pitch { app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1" }
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
    /// Swipes until the element is on screen, then lets the scroll come to rest: a tap during
    /// momentum only stops the scroll and never reaches the button.
    private func scrollTo(_ target: XCUIElement) {
        var swiped = false
        for _ in 0..<10 where !(target.exists && target.isHittable) { app.swipeUp(velocity: .slow); swiped = true }
        if swiped { settle(1.2) }
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
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        // The demo pitch drifts into tune over four seconds and re-plucks every six.
        settle(8); shot("10-tune-3d")
        settle(2.5); shot("10b-tune-locked")
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
        launch(studio: true, pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        settle(3); shot("14-tune-studio")
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
        tab("Practice"); settle()
        scrollTo(element("practice.intonation"))
        element("practice.intonation").tap(); settle(1.5); shot("46-intonation")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        tab("Tune"); settle()
        element("tune.instrument").tap(); settle(1.5)
        element("tunings.custom").tap(); settle(1.5); shot("47-custom-tuning")
        XCTAssertTrue(element("custom.save").waitForExistence(timeout: 10))
        element("custom.save").tap(); settle(1.5); shot("48-custom-tuning-saved")
    }

    func test07StageDiagnostics() throws {
        launch(stageDebug: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        let debug = element("stage.debug")
        XCTAssertTrue(debug.waitForExistence(timeout: 20))
        for _ in 0..<20 where !debug.label.hasPrefix("loaded") { settle(1) }
        print("STAGE DEBUG: \(debug.label)")
        let note = XCTAttachment(string: debug.label)
        note.name = "stage-debug"; note.lifetime = .keepAlways
        add(note)
        shot("90-stage-diagnostics")
    }
}
