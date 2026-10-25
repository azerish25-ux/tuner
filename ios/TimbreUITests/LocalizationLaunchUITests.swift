import XCTest

/// A first launch opens in the device's language and runs in its direction: German reads German from the welcome on,
/// Arabic lays out right to left. Each test launches on storage of its own, as a fresh install does, with no language
/// picked in Timbre.
final class LocalizationLaunchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func launch(language: String, locale: String, onboarded: Bool) {
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        if onboarded { app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1" }
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAGermanDeviceWelcomesInGerman() {
        launch(language: "de", locale: "de_DE", onboarded: false)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        XCTAssertFalse(start.label.isEmpty)
        XCTAssertNotEqual(start.label, "Get started", "the welcome is in German, not English")
        shot("l10n-de-welcome")
    }

    func testAGermanDeviceNamesTheTabsInGerman() {
        launch(language: "de", locale: "de_DE", onboarded: true)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 25))
        XCTAssertTrue(tabs.buttons["Stimmen"].exists, "Tune")
        XCTAssertTrue(tabs.buttons["Lernen"].exists, "Learn")
        XCTAssertTrue(tabs.buttons["Fortschritt"].exists, "Progress")
        XCTAssertFalse(tabs.buttons["Learn"].exists)
        shot("l10n-de-tabs")
    }

    func testAnArabicDeviceRunsRightToLeft() {
        launch(language: "ar", locale: "ar_SA", onboarded: true)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 25))
        // "Tune" and "Progress" in Arabic: the first tab and the last.
        let tune = tabs.buttons["\u{636}\u{628}\u{637}"]
        let progress = tabs.buttons["\u{627}\u{644}\u{62A}\u{642}\u{62F}\u{651}\u{645}"]
        XCTAssertTrue(tune.exists)
        XCTAssertTrue(progress.exists)
        if tune.exists && progress.exists {
            XCTAssertGreaterThan(tune.frame.midX, progress.frame.midX, "the first tab sits on the right")
        }
        shot("l10n-ar-tabs")
    }
}
