import XCTest

/// Xcode's accessibility audit on the screens every user meets: the welcome screen, each tab, Settings and the paywall.
///
/// Each audit (contrast, element descriptions, hit regions, Dynamic Type, clipped text, traits and element detection)
/// is attached to the results as a text report beside a screenshot of the screen it read, and its issue count is
/// logged. An issue fails the test only when its kind is in `enforced`. A kind joins that set once every screen's
/// report is clear of it, so the audit tightens one kind at a time and a fixed screen can't regress.
final class AccessibilityAuditUITests: XCTestCase {
    /// Issue kinds that fail the run. Empty until the first reports have been triaged.
    private static let enforced: XCUIAccessibilityAuditType = []

    private static let kinds: [(type: XCUIAccessibilityAuditType, name: String)] = [
        (type: .contrast, name: "contrast"),
        (type: .sufficientElementDescription, name: "element description"),
        (type: .hitRegion, name: "hit region"),
        (type: .dynamicType, name: "Dynamic Type"),
        (type: .textClipped, name: "clipped text"),
        (type: .trait, name: "traits"),
        (type: .elementDetection, name: "element detection"),
    ]

    /// What one audit found, filled in by the issue handler.
    private final class Findings {
        var lines: [String] = []
        var enforced = 0
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
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

    private func slug(_ text: String) -> String {
        let words = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        return words.isEmpty ? "tab" : words.joined(separator: "-")
    }

    /// Runs the audit on the screen in front, then attaches its report and a screenshot as `ax-audit-<screen>`.
    private func audit(_ screen: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "ax-audit-\(screen)"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let findings = Findings()
        let enforced = Self.enforced
        let kinds = Self.kinds
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let kind = kinds.first { issue.auditType.contains($0.type) }?.name ?? "other"
                let fails = enforced.contains(issue.auditType)
                let snapshot = try? issue.element?.snapshot()
                let id = snapshot.map { $0.identifier.isEmpty ? "-" : $0.identifier } ?? "-"
                let label = snapshot.map { $0.label.isEmpty ? "-" : "\"\($0.label)\"" } ?? "-"
                findings.lines.append("[\(kind)\(fails ? ", enforced" : "")] \(issue.compactDescription) | id \(id) | label \(label)")
                if fails { findings.enforced += 1 }
                // true: recorded here and not failed; false: XCTest fails the test with it.
                return !fails
            }
        } catch {
            findings.lines.append("The audit did not run: \(error.localizedDescription)")
        }

        let header = "Accessibility audit, \(screen): \(findings.lines.count) issues, \(findings.enforced) in enforced kinds"
        print(header)
        let report = XCTAttachment(string: ([header, ""] + findings.lines).joined(separator: "\n"))
        report.name = "ax-audit-\(screen).txt"
        report.lifetime = .keepAlways
        add(report)
    }
}
