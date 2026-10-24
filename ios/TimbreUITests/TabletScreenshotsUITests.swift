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
        // The tuner holds a real lock (ios/Timbre/Root/DemoScenes.swift): two strings ticked, the third locked in tune.
        app.launchEnvironment["TIMBRE_SCENE"] = "tune-locked"
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
        Thread.sleep(forTimeInterval: 8)  // hands off: the 3D stage loads and the scene's strings lock
        shot("ipad-portrait-tune")
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("ipad-landscape-tune")
        // The instrument browser is the tuner's picker sheet.
        app.descendants(matching: .any).matching(identifier: "tune.instrument").firstMatch.tap()
        shot("ipad-landscape-instruments")
        // Close the sheet; on iPad it can still be settling, so wait for Done and fall back to a swipe.
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 6) { done.tap() } else { app.swipeDown(velocity: .fast) }
        Thread.sleep(forTimeInterval: 1)
        app.buttons["Play"].firstMatch.tap()
        shot("ipad-landscape-practice")
        app.buttons["Songs"].firstMatch.tap()
        shot("ipad-landscape-songs")
        XCUIDevice.shared.orientation = .portrait
    }
}
