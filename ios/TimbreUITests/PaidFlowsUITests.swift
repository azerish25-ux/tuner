import XCTest
import StoreKitTest

/// Exercises the actual purchase button and verified StoreKit entitlement in the app.
/// Requires Timbre.storekit in this target's resources and the scheme's StoreKit config.
/// Run serially with other StoreKit tests; no production purchase or fake entitlement flag.
final class PaidFlowsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var session: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false
        session = try SKTestSession(configurationFileNamed: "Timbre")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Browse"].waitForExistence(timeout: 20))
    }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false { screenshot("Paid flow failure") }
        app?.terminate()
        session?.clearTransactions()
        session = nil
    }
    func testLocalPurchaseUnlocksTwelveStringVoiceAndStudio() throws {
        app.tabBars.buttons["Browse"].tap()
        let search = element("collection.search")
        scrollTo(search)
        search.tap()
        let existing = search.value as? String ?? ""
        if !existing.isEmpty && existing != "Search instruments" { search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)) }
        search.typeText("12-string")
        let twelveString = app.buttons["collection.photo.03_guitar_12_string_acoustic_guitar"]
        scrollTo(twelveString); twelveString.tap()
        let buy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unlock all features ·")).firstMatch
        XCTAssertTrue(buy.waitForExistence(timeout: 20), "Local StoreKit product must load; never fall back to a real Apple Account purchase")
        scrollTo(buy)
        buy.tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 20), "Only a verified local StoreKit purchase should unlock Plus")
        screenshot("Verified StoreKit lifetime unlock")
        continueButton.tap()
        app.tabBars.buttons["Browse"].tap()
        scrollTo(twelveString); twelveString.tap()
        XCTAssertTrue(element("bench.targetNote").waitForExistence(timeout: 10))
        XCTAssertEqual(element("bench.targetNote").label, "E2")
        XCTAssertTrue(app.staticTexts["12-string acoustic guitar"].exists)
        screenshot("Paid twelve-string guitar paired course bench")

        app.tabBars.buttons["Singing"].tap()
        let exercise = app.buttons["voice.exercise.2"]
        scrollTo(exercise); exercise.tap()
        let g3 = app.buttons["voice.key.55"]
        scrollTo(g3); g3.tap()
        XCTAssertTrue(g3.isSelected, "The visual piano key must select the actual singing target")
        XCTAssertEqual(element("voice.root").value as? String, "G3")
        let start = app.buttons["voice.start"]
        scrollTo(start); start.tap()
        // The reference tone precedes the permission request by one second. Wait for
        // the real SpringBoard permission control rather than tapping before it exists.
        resolveMicrophonePermission()
        let lastAttempt = app.staticTexts["Your last attempt"]
        XCTAssertTrue(lastAttempt.waitForExistence(timeout: 25), "The timed exercise must finish with an honest result even without measured simulator singing")
        scrollTo(lastAttempt)
        XCTAssertTrue(app.staticTexts["Not measured"].firstMatch.exists, "No microphone pitch evidence must not produce an accuracy score")
        screenshot("Paid voice timed attempt with no fabricated measurement")

        app.tabBars.buttons["Studio"].tap()
        let metronome = app.buttons["studio.startMetronome"]
        scrollTo(metronome)
        XCTAssertTrue(metronome.isEnabled)
        screenshot("Paid Studio controls and tuning desk")
        metronome.tap()
        XCTAssertTrue(metronome.label.contains("Stop"), "A verified purchase must allow actual metronome playback")
        screenshot("Paid metronome running")
        XCUIDevice.shared.press(.home)
        app.activate()
        app.tabBars.buttons["Studio"].tap()
        scrollTo(metronome)
        XCTAssertTrue(metronome.label.contains("Start"), "Metronome playback must stop when the app leaves the foreground")
        screenshot("Metronome stopped after backgrounding")
        let history = app.buttons["Practice history"]
        scrollTo(history); history.tap()
        XCTAssertFalse(app.buttons["history.unlock"].exists, "Verified purchase must unlock history")
        screenshot("Paid history without invented practice evidence")
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func resolveMicrophonePermission() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.microphonePermissionButton(springboard: springboard) != nil
        }, object: app)
        // A previous legitimate grant can mean no alert appears. The unchanged
        // result assertions below still require a real capture and timed attempt.
        guard XCTWaiter.wait(for: [appeared], timeout: 10) == .completed else { return }
        for attempt in 1...3 {
            var previousFrame = CGRect.zero
            var stableObservations = 0
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let button = self.microphonePermissionButton(springboard: springboard), button.isHittable else { return false }
                let frame = button.frame
                stableObservations = frame == previousFrame ? stableObservations + 1 : 0
                previousFrame = frame
                return frame.width > 0 && stableObservations >= 2
            }, object: app)
            if XCTWaiter.wait(for: [settled], timeout: 6) == .completed,
               let button = microphonePermissionButton(springboard: springboard) {
                button.tap()
            }
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.microphonePermissionButton(springboard: springboard) == nil
            }, object: app)
            if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { return }
            let hierarchy = XCTAttachment(string: "App-owned alerts:\n\(app.alerts.debugDescription)\nSpringBoard-owned alerts:\n\(springboard.alerts.debugDescription)")
            hierarchy.name = "Microphone permission still visible after attempt \(attempt)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = hierarchy.name
            screen.lifetime = .keepAlways
            add(screen)
        }
        XCTFail("The actual microphone permission alert must be dismissed before waiting for voice completion")
    }
    private func microphonePermissionButton(springboard: XCUIApplication) -> XCUIElement? {
        // iOS versions expose this system prompt under either application. Match
        // its actual microphone copy so an unrelated OK/Allow is never accepted.
        for owner in [app!, springboard] {
            for alert in owner.alerts.allElementsBoundByIndex {
                let copy = ([alert.label] + alert.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ")
                guard copy.localizedCaseInsensitiveContains("microphone") else { continue }
                for title in ["Allow", "OK"] {
                    let button = alert.buttons[title]
                    if button.exists { return button }
                }
            }
        }
        return nil
    }
    private func scrollTo(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if target.exists && target.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(target.exists && target.isHittable, "Expected paid-flow control must be reachable", file: file, line: line)
    }
    private func screenshot(_ name: String) {
        guard let app else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
