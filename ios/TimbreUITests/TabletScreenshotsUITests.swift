import XCTest

/// 13-inch iPad captures in portrait and landscape.
final class TabletScreenshotsUITests: XCTestCase {
    func testTabletLayouts() throws {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
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
        Thread.sleep(forTimeInterval: 8)  // let the 3D stage load and the demo string settle in tune
        shot("ipad-portrait-tune")
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("ipad-landscape-tune")
        // The instrument browser is the tuner's picker sheet.
        app.descendants(matching: .any).matching(identifier: "tune.instrument").firstMatch.tap()
        shot("ipad-landscape-instruments")
        app.buttons["Done"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["Play"].firstMatch.tap()
        shot("ipad-landscape-practice")
        app.buttons["Songs"].firstMatch.tap()
        shot("ipad-landscape-songs")
        XCUIDevice.shared.orientation = .portrait
    }
}
