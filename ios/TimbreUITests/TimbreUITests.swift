import XCTest

final class TimbreUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Tune"].waitForExistence(timeout: 20), "App must load its catalog and local state")
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
    private func scrollUpTo(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeDown()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Saved reference caption must be reachable", file: file, line: line)
    }
    private func tab(_ name: String) {
        let names = ["Collection": "Browse", "Bench": "Tune", "Voice": "Singing"]
        app.tabBars.buttons[names[name] ?? name].tap()
    }
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
        if !apply.isEnabled {
            replace(input, with: "440")
            dismissReferenceKeyboard()
            scrollTo(apply); apply.tap()
            scrollUpTo(input); replace(input, with: "442")
        }
        XCTAssertTrue(apply.isEnabled)
        // The decimal keyboard can overlap this Form row. Finish editing through
        // the real toolbar before reaching and tapping the actual Apply control.
        dismissReferenceKeyboard()
        scrollTo(apply); apply.tap()
        let currentReference = app.staticTexts["settings.currentReference"]
        scrollUpTo(currentReference)
        XCTAssertEqual(currentReference.label, "A4 = 442.0 Hz")
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
        scrollTo(currentReference)
        XCTAssertEqual(currentReference.label, "A4 = 442.0 Hz", "Saved reference must survive relaunch")
        scrollTo(element("settings.theme"))
        XCTAssertEqual(element("settings.theme").value as? String, "dark")
    }
    func testLocalizedGermanAndPersianNavigationAtAccessibilityTextSize() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.buttons["Settings"].tap()
        chooseLanguage("Deutsch")
        XCTAssertTrue(app.navigationBars["Einstellungen"].exists)
        screenshot("German settings at accessibility text size")
        chooseLanguage("فارسی")
        XCTAssertTrue(app.navigationBars["تنظیمات"].exists)
        screenshot("Persian settings at accessibility text size and RTL")
        // Return using the system navigation back control, which follows the active layout direction.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["آواز"].waitForExistence(timeout: 5))
        app.tabBars.buttons["آواز"].tap()
        let firstExercise = app.buttons["voice.exercise.1"]
        scrollTo(firstExercise)
        XCTAssertTrue(firstExercise.exists && firstExercise.isHittable)
        screenshot("Persian voice exercise preview in RTL")
        app.buttons["settings.open"].tap()
        chooseLanguage("English")
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
    private func chooseLanguage(_ name: String) {
        let picker = element("settings.language")
        scrollTo(picker); picker.tap()
        let option = app.buttons[name].firstMatch
        // A native menu can reopen at its previous scroll position. With AX text
        // only a few of the 49 real choices fit, so search both directions.
        let directions = ["English", "Deutsch"].contains(name) ? [true, false] : [false, true]
        for downward in directions {
            for _ in 0..<24 {
                if option.exists && option.isHittable { option.tap(); return }
                if downward { app.swipeDown() } else { app.swipeUp() }
            }
        }
        XCTAssertTrue(option.exists && option.isHittable, "The actual native language choice must be reachable: \(name)")
        option.tap()
    }
    private func dismissReferenceKeyboard() {
        let done = app.buttons["settings.dismissKeyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable, "The keyboard's real Done control must be accessible")
        done.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed, "Done must dismiss the decimal keyboard before applying a reference")
    }
    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
    }
}
