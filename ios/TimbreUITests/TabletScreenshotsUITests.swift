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
        assertLandscapeControlsInsideApp()
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
        var previousFrame = CGRect.zero
        var stableObservations = 0
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = application.frame
            guard frame.width > 0 && (portrait ? frame.height > frame.width : frame.width > frame.height) else {
                stableObservations = 0
                previousFrame = frame
                return false
            }
            stableObservations = frame == previousFrame ? stableObservations + 1 : 0
            previousFrame = frame
            // The orientation property changes before UIKit finishes rotating its
            // window. Require repeated stable bounds and the real toolbar layout.
            let settings = application.buttons["settings.open"]
            guard settings.exists && settings.isHittable else { return false }
            return stableObservations >= 3 && frame.insetBy(dx: -1, dy: -1).contains(settings.frame)
        }, object: application)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 15), .completed, "The operating system must finish rotating and settle the actual app bounds")
    }

    private func assertLandscapeControlsInsideApp() {
        let bounds = app.frame
        XCTAssertGreaterThan(bounds.width, bounds.height)
        let controls = [element("settings.open"), element("listenButton")]
        for control in controls {
            XCTAssertTrue(control.exists && control.isHittable, "The landscape control must remain reachable")
            XCTAssertTrue(bounds.insetBy(dx: -1, dy: -1).contains(control.frame), "The complete landscape control must fit inside the actual app bounds: \(control.identifier), \(control.frame), app \(bounds)")
            XCTAssertLessThanOrEqual(control.frame.maxX, bounds.maxX + 1, "The landscape right edge must not clip an essential control")
        }
        let evidence = XCTAttachment(string: "App bounds: \(bounds)\nSettings: \(controls[0].frame)\nListen: \(controls[1].frame)")
        evidence.name = "Actual iPad landscape layout bounds"
        evidence.lifetime = .keepAlways
        add(evidence)
    }

    private func screenshot(_ name: String) {
        // Capture the physical display, avoiding application-region crop transforms
        // during iPad rotation. This is the unmodified OS screenshot.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
