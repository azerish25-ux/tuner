import XCTest

/// The nightly accessibility matrix (nightly.yml, job `a11y-matrix`): the screens where layout breaks first, under one
/// setting per run, each captured and audited for clipped text, Dynamic Type, contrast and hit regions. The findings are
/// attached for review beside the pictures (`matrix-<variant>-<screen>`); a screen that can't be reached fails.
///
/// The variant comes from the workflow (`TEST_RUNNER_TIMBRE_MATRIX`):
///   ax5       the largest accessibility text size
///   bold      Bold Text (the workflow turns it on in the simulator)
///   contrast  Increase Contrast (the workflow turns it on in the simulator)
///   lefty     left-handed, chosen in Settings
///   upside    left-handed on a right-handed instrument turned over, chosen in Settings
///   ar        Arabic, right to left
/// Without one the run is the plain baseline.
final class AccessibilityMatrixUITests: XCTestCase {
    /// What one audit found, filled in by its issue handler.
    private final class Found {
        var lines: [String] = []
    }

    private var app: XCUIApplication!
    private static let variant = ProcessInfo.processInfo.environment["TIMBRE_MATRIX"].flatMap { $0.isEmpty ? nil : $0 } ?? "baseline"

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        var arguments = Self.variant == "ar" ? ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
                                             : ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if Self.variant == "ax5" {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func settle(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<10 where !(target.exists && target.isHittable) { app.swipeUp(velocity: .slow) }
        for _ in 0..<14 where !(target.exists && target.isHittable) { app.swipeDown(velocity: .slow) }
        settle(1)
    }

    /// The tab at `index` in the bar (by position, so Arabic names don't matter).
    private func tab(_ index: Int) -> Bool {
        let buttons = app.tabBars.firstMatch.buttons
        guard buttons.firstMatch.waitForExistence(timeout: 25), buttons.count > index else {
            XCTFail("no tab \(index + 1) in the bar")
            return false
        }
        let button = buttons.element(boundBy: index)
        guard button.isHittable else {
            navigationEvidence("tab-\(index)-unreachable")
            XCTFail("tab \(index + 1) is covered or not reachable")
            return false
        }
        button.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            button.exists && button.isHittable && button.isSelected
        }, object: nil)
        guard XCTWaiter.wait(for: [selected], timeout: 20) == .completed else {
            navigationEvidence("tab-\(index)-not-selected")
            XCTFail("tab \(index + 1) did not become selected and reachable")
            return false
        }
        return true
    }

    func testMatrixScreens() throws {
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40), "the tuner didn't open")
        if Self.variant == "lefty" || Self.variant == "upside" {
            guard chooseHandedness() else { return }
        }
        settle(2)
        capture("tuner")

        guard openSettings() else { return }
        capture("settings")
        guard closeSettings() else { return }

        // A first lesson: the explanation, the tune check, a notes step, then the play-along before Start.
        guard tab(1) else { return }
        let lesson = element("learn.lesson.gtr-1-2")
        scrollTo(lesson)
        guard lesson.exists && lesson.isHittable else {
            navigationEvidence("learn-lesson-unreachable")
            return XCTFail("the first guitar lesson isn't reachable on Learn's path")
        }
        lesson.tap()
        let next = element("lesson.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        settle(2)
        capture("lesson-explain")
        for _ in 0..<4 where next.exists {
            next.tap()
            _ = next.waitForNonExistence(timeout: 6)
        }
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 4) {
            settle(1)
            capture("lesson-tunecheck")
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 10)
        }
        settle(1.5)
        capture("lesson-notes")
        let played = element("lesson.override")
        for _ in 0..<2 {
            guard played.waitForExistence(timeout: 20) else { break }
            played.tap()
            _ = played.waitForNonExistence(timeout: 8)
        }
        let first = element("lesson.option.0")
        guard first.waitForExistence(timeout: 20) else { return XCTFail("the quiz didn't come after the notes steps") }
        settle(1.2)
        capture("lesson-quiz")
        first.tap(); settle(1)
        element("lesson.continue").tap(); settle(2)
        element("lesson.option.1").tap(); settle(1)
        element("lesson.continue").tap(); settle(2)
        capture("lesson-along-ready")
    }

    /// A Settings screenshot needs positive screen identity, not merely the absence of the Strum sheet.
    private var settingsVisible: Bool {
        let scroll = app.scrollViews["settings.scroll"].firstMatch
        let done = app.buttons["settings.done"].firstMatch
        return scroll.exists && scroll.isHittable && done.exists && done.isHittable
    }

    /// Opens the real sheet and confirms its controls. A dropped tap can be retried only while still on the tuner;
    /// a wrong sheet fails immediately. Navigation evidence is separate from the diagnostic audit's findings.
    private func openSettings() -> Bool {
        let open = element("settings.open")
        guard open.waitForExistence(timeout: 10), open.isHittable else {
            navigationEvidence("settings-open-unreachable")
            XCTFail("the tuner's Settings button is not reachable")
            return false
        }
        for attempt in 1...3 {
            open.tap()
            let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.settingsVisible }, object: nil)
            // The four accessibility queries can themselves exceed five seconds after an audit.
            // Keep the same positive identity, but allow repeated snapshots to settle before retrying.
            if XCTWaiter.wait(for: [appeared], timeout: 20) == .completed { return true }
            navigationEvidence("settings-open-attempt-\(attempt)")
            if settingsVisible { return true }
            let strum = element("strum.close")
            if strum.exists {
                XCTFail("the Settings button opened Strum to tune: the Strum control lies over it")
                if strum.isHittable { strum.tap() }
                return false
            }
            guard element("tune.stage").exists, open.exists, open.isHittable else { break }
        }
        XCTFail("Settings did not become visible: both settings.scroll and settings.done must be reachable")
        return false
    }

    func testSettingsOpensClosesAndReopensWithPositiveScreenIdentity() {
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40))
        XCTAssertFalse(settingsVisible, "The tuner must never satisfy the Settings screen assertion")
        for _ in 0..<2 {
            guard openSettings() else { return }
            XCTAssertTrue(settingsVisible)
            if Self.variant == "ar" {
                let temperament = element("settings.temperament")
                scrollTo(temperament)
                XCTAssertTrue(temperament.exists && temperament.isHittable)
                let selected = [temperament.label, temperament.value as? String ?? ""].joined(separator: " ")
                XCTAssertTrue(selected.contains("متساوي"), "Arabic's selected temperament must use the app translation")
                XCTAssertFalse(selected.contains("Equal"), "English data names must not leak into Arabic Settings")
            }
            guard closeSettings() else { return }
            XCTAssertFalse(settingsVisible)
            XCTAssertTrue(element("settings.open").isHittable, "The tuner must be reachable after Done")
        }
    }

    /// Settings › Handedness: left-handed, or left-handed strung upside down.
    private func chooseHandedness() -> Bool {
        guard openSettings() else { return false }
        let row = element("settings.handedness")
        scrollTo(row)
        guard row.exists && row.isHittable else {
            XCTFail("no reachable handedness row in Settings")
            return false
        }
        row.tap()
        settle(1)
        let choice = app.buttons[Self.variant == "upside" ? "Left-handed, strung upside down" : "Left-handed"].firstMatch
        guard choice.waitForExistence(timeout: 5), choice.isHittable else {
            XCTFail("the handedness menu didn't open")
            return false
        }
        choice.tap()
        settle(1)
        return closeSettings()
    }

    /// The same localized Done control closes every language; no coordinate dismissal can hide a failed route.
    private func closeSettings() -> Bool {
        let done = app.buttons["settings.done"].firstMatch
        guard done.exists && done.isHittable else {
            navigationEvidence("settings-close-unreachable")
            XCTFail("Settings Done is not reachable")
            return false
        }
        done.tap()
        guard done.waitForNonExistence(timeout: 10),
              element("settings.open").waitForExistence(timeout: 10),
              element("settings.open").isHittable else {
            navigationEvidence("settings-close-incomplete")
            XCTFail("Settings did not close to the reachable tuner")
            return false
        }
        return true
    }

    private func navigationEvidence(_ phase: String) {
        let name = "matrix-\(Self.variant)-\(phase)"
        let picture = XCTAttachment(screenshot: app.screenshot())
        picture.name = name
        picture.lifetime = .keepAlways
        add(picture)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    /// A picture of the screen in front and its audit (clipped text, Dynamic Type, contrast, hit regions) as a report.
    private func capture(_ screen: String) {
        if screen == "settings" && !settingsVisible {
            navigationEvidence("settings-capture-rejected")
            return XCTFail("Refusing to label a non-Settings screen as Settings")
        }
        let name = "matrix-\(Self.variant)-\(screen)"
        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = name
        picture.lifetime = .keepAlways
        add(picture)
        let found = Found()
        do {
            try app.performAccessibilityAudit(for: [.textClipped, .dynamicType, .contrast, .hitRegion]) { issue in
                let snapshot = try? issue.element?.snapshot()
                let id = snapshot?.identifier ?? ""
                let label = snapshot?.label ?? ""
                found.lines.append("\(issue.compactDescription) | id \(id.isEmpty ? "-" : id) | label \(label.isEmpty ? "-" : "\"\(label)\"")")
                return true
            }
        } catch {
            found.lines.append("The audit did not complete: \(error.localizedDescription)")
        }
        let lines = found.lines
        let report = XCTAttachment(string: (["\(name): \(lines.count) findings", ""] + lines).joined(separator: "\n"))
        report.name = name + ".txt"
        report.lifetime = .keepAlways
        add(report)
    }
}
