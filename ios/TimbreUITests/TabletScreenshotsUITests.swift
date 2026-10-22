import XCTest

/// Actual 13-inch simulator layouts and screenshots; no purchase or audio bypass.
final class TabletScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(element("bench.photo").waitForExistence(timeout: 20), "The real bundled catalog and initial instrument must load")
        waitForPortrait(true)
        XCTAssertGreaterThanOrEqual(app.frame.width, 1000, "Run this case on a real 13-inch iPad simulator, not an iPhone")
    }

    override func tearDownWithError() throws {
        if app != nil, testRun?.hasSucceeded == false { screenshot("iPad failure state") }
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testThirteenInchPortraitAndLandscapeScreens() {
        assertInitialBench()
        screenshot("iPad 13 inch — Bench portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForPortrait(false)
        assertInitialBench()
        screenshot("iPad 13 inch — Bench landscape")

        XCUIDevice.shared.orientation = .portrait
        waitForPortrait(true)
        selectTab("Browse")
        let guitar = app.buttons["collection.photo.01_guitar_acoustic_guitar"]
        scrollTo(guitar)
        XCTAssertTrue(element("collection.search").exists)
        XCTAssertTrue(guitar.exists && guitar.isHittable)
        screenshot("iPad 13 inch — Browse collection")

        selectTab("Singing")
        let firstExercise = app.buttons["voice.exercise.1"]
        scrollTo(firstExercise)
        XCTAssertTrue(firstExercise.isEnabled, "Every exercise must be available to preview")
        screenshot("iPad 13 inch — Singing exercise preview")
        let selectedKey = app.buttons["voice.key.57"]
        scrollTo(selectedKey)
        XCTAssertTrue(selectedKey.isSelected, "The real default A3 target must be visible on the piano")
        XCTAssertTrue(element("voice.root").exists)
        screenshot("iPad 13 inch — Singing target piano")

        selectTab("Studio")
        let tempo = element("studio.bpm")
        scrollTo(tempo)
        XCTAssertEqual(tempo.label, "96 beats per minute")
        let start = app.buttons["studio.startMetronome"]
        scrollTo(start)
        XCTAssertTrue(start.isEnabled)
        screenshot("iPad 13 inch — Studio rhythm controls")

        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.exists && settings.isHittable)
        settings.tap()
        let reference = element("settings.currentReference")
        scrollTo(reference)
        XCTAssertEqual(reference.label, "A4 = 440.0 Hz")
        screenshot("iPad 13 inch — Settings")
    }

    private func assertInitialBench() {
        XCTAssertTrue(element("bench.photo").exists)
        XCTAssertEqual(element("bench.targetNote").label, "E2")
        XCTAssertEqual(element("bench.liveFrequency").label, "— Hz", "An idle simulator must not invent a microphone reading")
    }

    private func selectTab(_ name: String) {
        // iPadOS 26 can put native tabs in the top toolbar rather than a UITabBar.
        let broad = app.buttons.matching(identifier: name).firstMatch
        if broad.waitForExistence(timeout: 5), broad.isHittable { broad.tap(); return }
        let tab = app.tabBars.buttons.matching(identifier: name).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5) && tab.isHittable, "The actual native \(name) tab must be reachable")
        tab.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func scrollTo(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.exists && target.isHittable, "The actual iPad control must be reachable by scrolling", file: file, line: line)
    }

    private func waitForPortrait(_ portrait: Bool) {
        let application = app!
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = application.frame
            return frame.width > 0 && (portrait ? frame.height > frame.width : frame.width > frame.height)
        }, object: application)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 10), .completed, "The operating system must actually rotate the app")
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
