import XCTest

/// Xcode's accessibility audit on the screens every user meets: the welcome screen, each tab, Settings and the paywall,
/// a lesson's steps (explanation, tune check, notes, the play-along before Start) and the metronome.
///
/// Each audit (contrast, element descriptions, hit regions, Dynamic Type, clipped text, traits and element detection)
/// is attached to the results as a text report beside a screenshot of the screen it read, and its issue count is
/// logged. An issue fails the test when its kind is in `enforced`, unless `known` lists it: an issue that predates the
/// enforcement, listed with the screen it is on and kept until its owner fixes it. A new issue of an enforced kind
/// fails, and so does an audit that can't run: a screen the audit never read is not a screen that passed.
///
/// The app is launched with its stage resting (`TIMBRE_STAGE_REST`): the 3D stage, the shader backgrounds and the
/// timeline animations hold still, so the audit can read the screen before it times out.
final class AccessibilityAuditUITests: XCTestCase {
    /// Issue kinds that fail the run.
    private static let enforced: XCUIAccessibilityAuditType = [.contrast, .hitRegion, .sufficientElementDescription, .trait]

    /// Issues of enforced kinds that predate their enforcement: (screen, kind, the element's identifier or label).
    /// Each one belongs to the team that owns the screen; remove the line with the fix.
    private static let known: [(screen: String, kind: String, element: String)] = [
        (screen: "welcome", kind: "contrast", element: "TIMBRE"),
        (screen: "tab-2-learn", kind: "hit region", element: "8 of 15 stars"),
        (screen: "tab-2-learn", kind: "contrast", element: "LV 5"),
    ]

    private static let kinds: [(type: XCUIAccessibilityAuditType, name: String)] = [
        (type: .contrast, name: "contrast"),
        (type: .sufficientElementDescription, name: "element description"),
        (type: .hitRegion, name: "hit region"),
        (type: .dynamicType, name: "Dynamic Type"),
        (type: .textClipped, name: "clipped text"),
        (type: .trait, name: "traits"),
        (type: .elementDetection, name: "element detection"),
    ]

    /// Tries before an audit that can't complete counts as a failure, with a pause between them for the screen to rest.
    private static let attempts = 3

    /// What one audit found, filled in by the issue handler.
    private final class Findings {
        var lines: [String] = []
        var failing: [String] = []
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testWelcomeScreen() throws {
        app.launch()
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 25))
        settle(1.5)
        audit("welcome")
    }

    /// Every tab in the bar, found by position, so a renamed or translated tab is still audited.
    func testEveryTab() throws {
        launchOnboarded()
        let buttons = app.tabBars.firstMatch.buttons
        XCTAssertTrue(buttons.firstMatch.waitForExistence(timeout: 25))
        let count = buttons.count
        XCTAssertGreaterThan(count, 0)
        for index in 0..<count {
            let button = buttons.element(boundBy: index)
            let name = button.label
            button.tap()
            settle(2.5)
            audit("tab-\(index + 1)-\(slug(name))")
        }
    }

    func testSettingsAndPaywall() throws {
        launchOnboarded()
        let open = element("settings.open")
        XCTAssertTrue(open.waitForExistence(timeout: 25))
        open.tap()
        settle(1.5)
        audit("settings")
        // The upsell row is absent once Pro is active; then there is no paywall to reach from here.
        let pro = element("settings.pro")
        guard pro.waitForExistence(timeout: 5) else { return }
        pro.tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        settle(1.5)
        audit("paywall")
    }

    /// A first lesson, step by step: its explanation, the tune check, a notes step (listening, nothing heard yet) and
    /// the play-along before Start. The notes steps are passed with "I played it", as a player without a microphone
    /// would; the quiz and the listening question are answered.
    func testLessonSteps() throws {
        launchOnboarded()
        let learn = app.tabBars.buttons["Learn"].firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: 25))
        learn.tap()
        settle(2)
        let lesson = element("learn.lesson.gtr-1-2")
        scrollTo(lesson)
        lesson.tap()
        let next = element("lesson.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        settle(2)
        audit("lesson-explain")
        for _ in 0..<4 where next.exists {
            next.tap()
            _ = next.waitForNonExistence(timeout: 6)
        }
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 4) {
            settle(1)
            audit("lesson-tunecheck")
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 10)
        }
        settle(1.5)
        audit("lesson-notes")
        // Two notes steps: "I played it" shows after a few seconds on each.
        let played = element("lesson.override")
        for _ in 0..<2 {
            guard played.waitForExistence(timeout: 20) else { break }
            played.tap()
            _ = played.waitForNonExistence(timeout: 8)
        }
        let first = element("lesson.option.0")
        XCTAssertTrue(first.waitForExistence(timeout: 20), "the quiz didn't come after the notes steps")
        settle(1.2)
        first.tap(); settle(1)
        element("lesson.continue").tap(); settle(2)
        element("lesson.option.1").tap(); settle(1)
        element("lesson.continue").tap(); settle(2)
        audit("lesson-along-ready")
    }

    func testMetronome() throws {
        launchOnboarded()
        let practice = app.tabBars.buttons["Practice"].firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 25))
        practice.tap()
        settle(1.5)
        let metronome = element("practice.metronome")
        scrollTo(metronome)
        metronome.tap()
        XCTAssertTrue(element("metronome.start").waitForExistence(timeout: 10))
        settle(1.5)
        audit("metronome")
    }

    // MARK: Helpers

    private func launchOnboarded() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func settle(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    private func scrollTo(_ target: XCUIElement) {
        for _ in 0..<8 where !(target.exists && target.isHittable) { app.swipeUp(velocity: .slow) }
        for _ in 0..<12 where !(target.exists && target.isHittable) { app.swipeDown(velocity: .slow) }
        settle(1)
    }

    private func slug(_ text: String) -> String {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "tab" : words.joined(separator: "-")
    }

    /// Whether `known` lists this issue for this screen.
    private static func isKnown(screen: String, kind: String, id: String, label: String) -> Bool {
        known.contains { $0.screen == screen && $0.kind == kind && ($0.element == id || $0.element == label) }
    }

    /// Runs the audit on the screen in front (again, after a pause, when it can't complete), then attaches its report
    /// and a screenshot as `ax-audit-<screen>`. Fails on an issue of an enforced kind that `known` doesn't list, and
    /// when no attempt completes.
    private func audit(_ screen: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "ax-audit-\(screen)"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        var findings = Findings()
        var problem: String?
        for attempt in 1...Self.attempts {
            findings = Findings()
            problem = run(screen, into: findings)
            guard let reason = problem else { break }
            findings.lines.append("Attempt \(attempt) did not complete: \(reason)")
            if attempt < Self.attempts { settle(3) }
        }

        let header = "Accessibility audit, \(screen): \(findings.lines.count) lines, \(findings.failing.count) failing"
        print(header)
        let report = XCTAttachment(string: ([header, ""] + findings.lines).joined(separator: "\n"))
        report.name = "ax-audit-\(screen).txt"
        report.lifetime = .keepAlways
        add(report)
        if let problem {
            XCTFail("\(screen): the accessibility audit could not run (\(Self.attempts) tries): \(problem)")
        }
        for line in findings.failing {
            XCTFail("\(screen): \(line)")
        }
    }

    /// One audit of the screen in front; the reason it didn't complete, or nil.
    private func run(_ screen: String, into findings: Findings) -> String? {
        let enforced = Self.enforced
        let kinds = Self.kinds
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let kind = kinds.first { issue.auditType.contains($0.type) }?.name ?? "other"
                let snapshot = try? issue.element?.snapshot()
                let id = snapshot?.identifier ?? ""
                let label = snapshot?.label ?? ""
                let known = Self.isKnown(screen: screen, kind: kind, id: id, label: label)
                let fails = enforced.contains(issue.auditType) && !known
                let tag = fails ? ", enforced" : (known ? ", known" : "")
                let line = "[\(kind)\(tag)] \(issue.compactDescription) | id \(id.isEmpty ? "-" : id) | label "
                    + (label.isEmpty ? "-" : "\"\(label)\"")
                findings.lines.append(line)
                if fails { findings.failing.append(line) }
                // true: recorded here (and failed below when it must); false would make XCTest fail it without context.
                return true
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
