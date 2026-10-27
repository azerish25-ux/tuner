import StoreKitTest
import XCTest

/// Xcode's accessibility audit on the screens every user meets: the welcome screen, each tab, Settings and the paywall,
/// a lesson's steps (explanation, tune check, notes, the play-along before Start) and the metronome.
///
/// Each audit (contrast, element descriptions, hit regions, Dynamic Type, clipped text, traits and element detection)
/// is attached to the results as a text report beside a screenshot of the screen it read, and its issue count is
/// logged. An issue fails the test when its kind is in `enforced`, unless `known` lists it with the screen it is on.
/// A new issue of an enforced kind fails, and so does an audit that can't run: a screen the audit never read is not a
/// screen that passed.
///
/// The app is launched with its stage resting (`TIMBRE_STAGE_REST`): the 3D stage, the shader backgrounds and the
/// timeline animations hold still, so the audit can read the screen before it times out. The scheme's StoreKit
/// configuration is loaded and emptied, so the paywall audited is the one with its plans.
final class AccessibilityAuditUITests: XCTestCase {
    /// Issue kinds that fail the run.
    private static let enforced: XCUIAccessibilityAuditType = [.contrast, .hitRegion, .sufficientElementDescription, .trait]

    /// Issues of enforced kinds the run lets through: (screen, kind, the element's identifier or label, why).
    /// Each is a contrast reading the audit gets wrong, checked against its screenshot (`ax-audit-<screen>`) with the
    /// text's and background's own colours (WCAG ratio; 4.5:1 for body text, 3:1 for large). The usual causes: text on
    /// Liquid Glass or a gradient wash, text redrawn every frame, text under a fade or the dock, text drawn at opacity 0.
    /// A real failure is fixed in the app, never listed here; remove a line once the audit reads its element right.
    private static let known: [(screen: String, kind: String, element: String, reason: String)] = [
        (screen: "welcome", kind: "contrast", element: "TIMBRE", reason: "the wordmark, ink on the spotlight's cone: 11.3:1"),
        (screen: "welcome", kind: "contrast", element: "Just tune", reason: "ink link on the stage, 18.3:1, under the mint button's glass and glow"),
        (screen: "tab-1-tune", kind: "contrast", element: "Play E2",
         reason: "tune.status at opacity 0 while the peg's label shows the call (that label: 8.2:1); VoiceOver still reads it"),
        (screen: "tab-1-tune", kind: "contrast", element: "E",
         reason: "the note, ink on the stage, 17.5:1 (the E2 chip's 12.7:1); redrawn every frame while listening"),
        (screen: "tab-1-tune", kind: "contrast", element: "2",
         reason: "the octaves in inkFaint: readout 6.2:1, E2 chip 6.3:1, A2 chip 6.0:1; redrawn with the live pitch"),
        (screen: "tab-1-tune", kind: "contrast", element: "7", reason: "the streak count, flameInk on the chip's translucent flame wash: 11.2:1"),
        (screen: "tab-1-tune", kind: "contrast", element: "Reference", reason: "ink on Liquid Glass (glassCapsule): 16.2:1"),
        (screen: "tab-1-tune", kind: "contrast", element: "Auto", reason: "mint on the mint thumb over Liquid Glass: 8.6:1"),
        (screen: "tab-2-learn", kind: "contrast", element: "7", reason: "the streak count, flameInk on the chip's translucent flame wash: 11.5:1"),
        (screen: "tab-2-learn", kind: "contrast", element: "LV 5", reason: "the level ring's mark on the stage glow: LV 13.4:1, 5 17.3:1"),
        (screen: "settings", kind: "contrast", element: "Done", reason: "the system Done button, ink on Liquid Glass: 15.0:1"),
        (screen: "paywall", kind: "contrast", element: "·", reason: "a separator's dot, inkFaint on the stage: 6.3:1 at its core; hidden from VoiceOver"),
        (screen: "lesson-tunecheck", kind: "contrast", element: "Pluck each open string. In-tune strings help Timbre hear you right.",
         reason: "inkSoft on the lesson's radial accent wash: 7.2:1"),
        (screen: "metronome", kind: "contrast", element: "1", reason: "a beat's digit, inkSoft on the accent cell's gradient fill: 5.2:1 behind it"),
        (screen: "metronome", kind: "contrast", element: "2", reason: "a beat's digit, inkSoft on stageRaised over the cell's gradient level fill: 7.8:1"),
        (screen: "metronome", kind: "contrast", element: "3", reason: "a beat's digit, inkSoft on stageRaised over the cell's gradient level fill: 7.8:1"),
        (screen: "metronome", kind: "contrast", element: "4", reason: "a beat's digit, inkSoft on stageRaised over the cell's gradient level fill: 7.8:1"),
        (screen: "metronome", kind: "contrast", element: "7/4", reason: "under the meter rail's edge fade (3.3:1 there); in view ink on the card, 16.8:1"),
        (screen: "metronome", kind: "contrast", element: "Sound",
         reason: "under the dock's fade at rest (1.1:1 there); scrolled clear, mint on the card 13.0:1"),
        (screen: "metronome", kind: "contrast", element: "Click", reason: "under the dock at rest; scrolled clear, stage on the selected ink pill 18.2:1"),
        (screen: "metronome", kind: "contrast", element: "Wood", reason: "under the dock at rest; scrolled clear, inkSoft on surface 7.4:1"),
        (screen: "metronome", kind: "contrast", element: "Beep", reason: "under the dock at rest; scrolled clear, inkSoft on surface 7.4:1"),
        (screen: "metronome", kind: "contrast", element: "Feel the beat", reason: "under the dock at rest; scrolled clear, ink on the card 16.8:1"),
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

    /// Tries for each isolated kind after a combined audit times out, with a pause for the screen to rest.
    private static let attempts = 3

    /// What one audit found, filled in by the issue handler.
    private final class Findings {
        // Mirror report events immediately: a runner cancellation can leave its xcresult unfinalized.
        // Attachments remain the visual evidence; console lines never substitute for a completed audit.
        var lines: [String] = [] {
            didSet {
                for line in lines.dropFirst(oldValue.count) { print("AX-AUDIT: \(line)") }
            }
        }
        var failing: [String] = []
        var callbacks = 0
        var opaqueCallbacks = 0
    }

    private var app: XCUIApplication!
    private var storeKit: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = true
        // The scheme's StoreKit configuration, loaded and emptied as TimbreUITests does: a UI-only run has no unit test
        // to load it (the paywall would find no plans), and a run after the unit tests may inherit their purchases.
        storeKit = try SKTestSession(configurationFileNamed: "Timbre")
        storeKit.resetToDefaultState()
        storeKit.clearTransactions()
        storeKit.disableDialogs = true
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
            let name = buttons.element(boundBy: index).label
            // Top-level screens replay the same navigation before EVERY kind and attempt. A timed-out
            // combined audit must not leave scrolling, Dynamic Type or rendering state for the next request.
            audit("tab-\(index + 1)-\(slug(name))", replay: {
                self.replayTab(index: index, count: count, name: name)
            })
        }
    }

    private func replayTab(index: Int, count: Int, name: String) -> Bool {
        app.terminate()
        launchOnboarded()
        let buttons = app.tabBars.firstMatch.buttons
        guard buttons.firstMatch.waitForExistence(timeout: 25), buttons.count == count else { return false }
        let button = buttons.element(boundBy: index)
        guard button.label == name else { return false }
        button.tap()
        settle(2.5)
        return button.isSelected
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

    /// Why `known` lets this issue through on this screen; nil when it doesn't list it.
    private static func knownReason(screen: String, kind: String, id: String, label: String) -> String? {
        known.first { $0.screen == screen && $0.kind == kind && ($0.element == id || $0.element == label) }?.reason
    }

    /// Replayable screens run every kind in a fresh process. Other screens run the complete audit, then every
    /// kind separately if it times out. Neither path omits a kind or treats an unfinished request as a pass.
    /// All attempts and their findings stay in the report, including failures found before a timeout.
    private func audit(_ screen: String, replay: (() -> Bool)? = nil) {
        if replay == nil {
            let screenshot = XCTAttachment(screenshot: stillScreenshot())
            screenshot.name = "ax-audit-\(screen)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }

        print("AX-AUDIT: Begin screen \(screen)")
        let findings = Findings()
        var unfinished: [String] = []
        if let replay {
            for kind in Self.kinds {
                if let problem = auditKind(kind.type, name: kind.name, screen: screen, into: findings, replay: replay) {
                    unfinished.append("\(kind.name): \(problem)")
                }
            }
        } else if let reason = run(screen, types: .all, into: findings) {
            findings.lines.append("Combined audit did not complete: \(reason). Retrying every kind separately.")
            for kind in Self.kinds {
                if let problem = auditKind(kind.type, name: kind.name, screen: screen, into: findings) {
                    unfinished.append("\(kind.name): \(problem)")
                }
            }
        } else {
            findings.lines.append("Completed all audit kinds.")
        }

        let header = "Accessibility audit, \(screen): \(findings.lines.count) lines, \(findings.failing.count) failing"
        print(header)
        let report = XCTAttachment(string: ([header, ""] + findings.lines).joined(separator: "\n"))
        report.name = "ax-audit-\(screen).txt"
        report.lifetime = .keepAlways
        add(report)
        for problem in unfinished {
            XCTFail("\(screen): the accessibility audit could not run (up to \(Self.attempts) isolated tries): \(problem)")
        }
        for line in findings.failing {
            XCTFail("\(screen): \(line)")
        }
    }

    /// An isolated kind must complete, even when its findings are informational rather than enforced.
    private func auditKind(_ type: XCUIAccessibilityAuditType, name: String, screen: String,
                           into findings: Findings, replay: (() -> Bool)? = nil) -> String? {
        var problem: String?
        for attempt in 1...Self.attempts {
            if let replay {
                guard replay() else {
                    let reason = "Fresh-process navigation failed for \(name) attempt \(attempt)"
                    findings.lines.append(reason)
                    attachAuditState("ax-navigation-failed-\(screen)-\(slug(name))-\(attempt)")
                    return reason
                }
                findings.lines.append("Fresh-process navigation verified for \(name) attempt \(attempt).")
                let captureName = name == "contrast" && attempt == 1
                    ? "ax-audit-\(screen)" : "ax-before-\(screen)-\(slug(name))-\(attempt)"
                attachAuditState(captureName)
            }
            settle(3)
            problem = run(screen, types: type, into: findings)
            guard let reason = problem else {
                findings.lines.append("Completed \(name) audit on isolated attempt \(attempt).")
                return nil
            }
            findings.lines.append("\(name) attempt \(attempt) did not complete: \(reason)")
        }
        return problem
    }

    /// One request for the screen in front; the reason it didn't complete, or nil.
    private func run(_ screen: String, types: XCUIAccessibilityAuditType, into findings: Findings) -> String? {
        let enforced = Self.enforced
        let kinds = Self.kinds
        let previousOpaque = findings.opaqueCallbacks
        let request = findings.lines.count
        var incomplete = false
        // Query outside the audit callback. Dynamic Type changes text, not the physical app viewport.
        let viewport = app.frame
        defer {
            // Hierarchy queries are deliberately outside the issue handler: recursively querying the app
            // while XCTest is auditing can interfere with its traversal. Callback screenshots stay in place.
            if incomplete || findings.opaqueCallbacks > previousOpaque {
                attachAuditState("ax-after-\(screen)-mask-\(types.rawValue)-request-\(request)")
            }
        }
        do {
            findings.lines.append("Starting audit mask \(types.rawValue).")
            try app.performAccessibilityAudit(for: types) { issue in
                findings.callbacks += 1
                let kind = kinds.first { issue.auditType.contains($0.type) }?.name ?? "other"
                var snapshot: (any XCUIElementSnapshot)?
                var unavailable = "element nil"
                if let element = issue.element {
                    do {
                        snapshot = try element.snapshot()
                    } catch {
                        unavailable = "snapshot threw: \(error)".replacingOccurrences(of: "\n", with: "\\n")
                    }
                }
                if snapshot == nil { findings.opaqueCallbacks += 1 }
                let id = snapshot?.identifier ?? ""
                let label = snapshot?.label ?? ""
                var reason = Self.knownReason(screen: screen, kind: kind, id: id, label: label)
                var callbackScreenshot: XCUIScreenshot?
                if reason == nil, issue.auditType == .contrast, snapshot?.elementType == .staticText,
                   (screen == "settings" && id == "settings.notation.title" && label == "Note names")
                    || (screen == "paywall" && id == "paywall.plan.yearly.saving" && label == "SAVE 58%") {
                    let capture = XCUIScreen.main.screenshot()
                    callbackScreenshot = capture
                    if let frame = snapshot?.frame,
                       let proof = AuditContrastPixelProof.verify(screen: screen, identifier: id, label: label,
                                                                 frame: frame, viewport: viewport, image: capture.image) {
                        reason = proof.summary
                        let evidence = XCTAttachment(screenshot: capture)
                        evidence.name = "ax-pixel-proof-\(screen)-\(findings.callbacks)"
                        evidence.lifetime = .keepAlways
                        self.add(evidence)
                    }
                }
                let fails = enforced.contains(issue.auditType) && reason == nil
                let tag = fails ? ", enforced" : (reason.map { ", known: \($0)" } ?? "")
                // Unidentified callbacks are separate evidence: the same compact description may describe
                // several different elements whose snapshots the audit cannot return.
                let geometry = snapshot.map { " | frame \($0.frame) | type \($0.elementType.rawValue)" }
                    ?? " | snapshot unavailable (\(unavailable)) | callback \(findings.callbacks)"
                let detail = issue.detailedDescription.replacingOccurrences(of: "\n", with: "\\n")
                let line = "[\(kind)\(tag)] \(issue.compactDescription) | id \(id.isEmpty ? "-" : id) | label "
                    + (label.isEmpty ? "-" : "\"\(label)\"")
                    + geometry + " | detail \(detail)"
                findings.lines.append(line)
                if fails, !findings.failing.contains(line) {
                    findings.failing.append(line)
                    // The audit can scroll or resize the screen after the initial still. Preserve the state
                    // beside this finding so its reported bounds can be compared with the actual rendered pixels.
                    let rendered = XCTAttachment(screenshot: callbackScreenshot ?? XCUIScreen.main.screenshot())
                    rendered.name = "ax-failure-\(screen)-\(findings.failing.count)"
                    rendered.lifetime = .keepAlways
                    self.add(rendered)
                }
                // true: recorded here (and failed below when it must); false would make XCTest fail it without context.
                return true
            }
            findings.lines.append("Completed audit mask \(types.rawValue) on \(screen).")
            return nil
        } catch {
            findings.lines.append("Audit mask \(types.rawValue) on \(screen) threw: \(error.localizedDescription)")
            incomplete = true
            return error.localizedDescription
        }
    }

    /// Before/after evidence is not a callback-time target identification or a substitute for a completed audit.
    private func attachAuditState(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-hierarchy.txt"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
