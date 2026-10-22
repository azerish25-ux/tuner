import XCTest

final class TimbreUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Bench"].waitForExistence(timeout: 20), "App must load its catalog and local state")
    }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { screenshot("Failure state") }
        app.terminate()
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func scrollTo(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Control should be reachable by scrolling: \(target)", file: file, line: line)
    }
    private func tab(_ name: String) { app.tabBars.buttons[name].tap() }
    private func dismissPlus() {
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        screenshot("Timbre Plus purchase gate")
        close.tap()
    }
    private func search(_ text: String) {
        tab("Collection")
        let search = element("collection.search")
        if !search.isHittable {
            for _ in 0..<8 { app.swipeDown(); if search.isHittable { break } }
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let old = search.value as? String ?? ""
        if old != "Search instruments" && !old.isEmpty { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        search.typeText(text)
    }
    private func selectPhoto(_ asset: String, search text: String, expectedNote: String, label: String) {
        search(text)
        let row = app.buttons["collection.photo." + asset]
        scrollTo(row)
        row.tap()
        let target = element("bench.targetNote")
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, expectedNote)
        XCTAssertTrue(app.staticTexts[label].exists)
        XCTAssertTrue(element("bench.photo").exists)
    }
    func testBenchLaunchHasPhotographAndNoInventedPitch() {
        XCTAssertTrue(element("bench.photo").exists)
        XCTAssertTrue(element("bench.targetNote").exists)
        XCTAssertEqual(element("bench.liveFrequency").label, "— Hz")
        let deviation = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Pitch deviation")).firstMatch
        XCTAssertEqual(deviation.value as? String, "No measured pitch")
        XCTAssertTrue(app.buttons["listenButton"].exists)
        screenshot("Bench idle with actual instrument photo")
    }
    func testCollectionFreeVariantsAndSelectionPersistAfterRelaunch() {
        selectPhoto("06_bass_4_string_p_bass", search: "4-string bass", expectedNote: "E1", label: "4-string bass")
        screenshot("Free four-string bass tuning")
        search("5-string bass")
        let fiveString = app.buttons["collection.photo.07_bass_5_string_j_bass"]
        scrollTo(fiveString); fiveString.tap(); dismissPlus()
        tab("Bench")
        XCTAssertEqual(element("bench.targetNote").label, "E1", "A locked five-string tuning must not replace the active free bass")
        selectPhoto("10_ukulele_soprano_ukulele", search: "Soprano ukulele", expectedNote: "G4", label: "Soprano ukulele")
        selectPhoto("11_ukulele_concert_ukulele", search: "Concert ukulele", expectedNote: "G4", label: "Concert ukulele")
        selectPhoto("12_ukulele_tenor_ukulele", search: "Tenor ukulele", expectedNote: "G4", label: "Tenor ukulele")
        screenshot("Free tenor ukulele tuning")
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Tenor ukulele"].waitForExistence(timeout: 10))
        XCTAssertEqual(element("bench.targetNote").label, "G4")
        XCTAssertEqual(element("bench.liveFrequency").label, "— Hz")
        tab("Collection")
        screenshot("Collection photographs and remembered instruments")
    }
    func testVoiceEveryExerciseCanBePreviewedAndPracticeRequiresPurchase() {
        tab("Voice")
        for level in 1...8 {
            let button = app.buttons["voice.exercise.\(level)"]
            scrollTo(button)
            XCTAssertTrue(button.isEnabled, "Exercise preview must never be locked by progression")
            button.tap()
            XCTAssertTrue(button.isSelected)
        }
        screenshot("Voice exercise previews")
        let start = app.buttons["voice.start"]
        scrollTo(start); start.tap()
        dismissPlus()
        XCTAssertFalse(app.buttons["Stop practice"].exists, "A purchase gate must not begin recording")
        XCTAssertFalse(app.staticTexts["Skill demonstrated"].exists, "Previewing cannot fabricate evidence")
    }
    func testStudioTempoControlsAndHistoryRequirePlus() {
        tab("Studio")
        let bpm = element("studio.bpm")
        scrollTo(bpm)
        let initial = bpm.label
        let stepper = app.steppers["studio.tempo"]
        XCTAssertTrue(stepper.exists)
        let increment = stepper.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'increment'")).firstMatch
        if increment.exists { increment.tap() } else { stepper.buttons.element(boundBy: 1).tap() }
        XCTAssertNotEqual(bpm.label, initial)
        screenshot("Studio tempo controls")
        let start = app.buttons["studio.startMetronome"]
        scrollTo(start); start.tap(); dismissPlus()
        let history = app.buttons["Practice history"]
        scrollTo(history); history.tap()
        let unlock = app.buttons["history.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        screenshot("History access gate without invented sessions")
        unlock.tap(); dismissPlus()
    }
    func testSettingsReferenceValidationThemeAndPersistence() {
        app.buttons["Settings"].tap()
        let input = app.textFields["settings.referenceInput"]
        scrollTo(input)
        replace(input, with: "500")
        let apply = app.buttons["settings.applyReference"]
        XCTAssertFalse(apply.isEnabled)
        XCTAssertTrue(app.staticTexts["Enter a number from 415 to 466 Hz."].exists)
        replace(input, with: "442")
        // A previous test run may already have saved 442; first choose another valid reference.
        if !apply.isEnabled { replace(input, with: "440"); apply.tap(); replace(input, with: "442") }
        XCTAssertTrue(apply.isEnabled); apply.tap()
        XCTAssertTrue(app.staticTexts["A4 = 442.0 Hz"].exists)
        app.swipeUp() // Move focus away from the decimal keyboard before scrolling to appearance.
        let theme = element("settings.theme")
        scrollTo(theme)
        theme.tap(); app.buttons["Light"].tap()
        XCTAssertEqual(element("settings.theme").value as? String, "light")
        screenshot("Settings light appearance")
        element("settings.theme").tap(); app.buttons["Dark"].tap()
        XCTAssertEqual(element("settings.theme").value as? String, "dark")
        screenshot("Settings dark appearance")
        app.terminate(); app.launch()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["A4 = 442.0 Hz"].waitForExistence(timeout: 5))
        scrollTo(element("settings.theme"))
        XCTAssertEqual(element("settings.theme").value as? String, "dark")
    }
    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
    }
}
