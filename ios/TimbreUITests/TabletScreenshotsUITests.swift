import XCTest

/// 13-inch iPad captures in portrait and landscape.
final class TabletScreenshotsUITests: XCTestCase {
    func testTabletLayouts() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "tune.stage").firstMatch.waitForExistence(timeout: 30))
        func shot(_ name: String) {
            Thread.sleep(forTimeInterval: 2)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways
            add(attachment)
        }
        shot("ipad-portrait-tune")
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("ipad-landscape-tune")
        app.buttons["Instruments"].firstMatch.tap()
        shot("ipad-landscape-instruments")
        app.buttons["Practice"].firstMatch.tap()
        shot("ipad-landscape-practice")
        XCUIDevice.shared.orientation = .portrait
    }
}
