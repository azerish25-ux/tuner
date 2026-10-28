import StoreKitTest
import XCTest

/// The money screen and the first session: the paywall from Settings always shows its plan cards (its tag never
/// without its card), and "Just tune" reaches a listening tuner without the questions. Each test launches on storage of
/// its own, as a fresh install does.
final class FirstSessionUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKit: SKTestSession!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeKit = try SKTestSession(configurationFileNamed: "Timbre")
        storeKit.resetToDefaultState()
        storeKit.clearTransactions()
        storeKit.disableDialogs = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "zz-failure-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if app.state != .notRunning { app.terminate() }
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func assertHittable(_ target: XCUIElement, timeout: TimeInterval = 10,
                                file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "The control must be exposed, not merely present behind onboarding", file: file, line: line)
    }

    /// The real welcome must expose the complete Urdu promise and every action without squeezing the script.
    /// Small-width ink bounds are also checked by WelcomeHeadlineLayoutTests; this exercises the actual scroll path.
    func testUrduWelcomeKeepsItsFullHeadingAndReachableActionsAtNormalAndAX5() {
        let categories = ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"]
        for category in categories {
            app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
            app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
            app.launchArguments = ["-AppleLanguages", "(ur)", "-AppleLocale", "ur_PK",
                                   "-UIPreferredContentSizeCategoryName", category]
            app.launch()
            let headline = element("onboarding.headline")
            XCTAssertTrue(headline.waitForExistence(timeout: 30))
            XCTAssertEqual(headline.label, "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔")
            XCTAssertEqual(app.staticTexts.matching(identifier: "onboarding.headline").count, 1,
                           "The complete heading must remain one native, spoken text element")
            revealWelcome(headline, edge: .top)
            captureWelcome(category + "-heading-top")
            revealWelcome(headline, edge: .bottom)
            captureWelcome(category + "-heading-bottom")
            for (id, label) in [("onboarding.start", "شروع کریں"), ("onboarding.justTune", "صرف ٹیون کریں"),
                                ("onboarding.restore", "میرے پاس پہلے سے Timbre Pro ہے")] {
                let action = element(id)
                XCTAssertEqual(action.label, label)
                revealWelcome(action)
                captureWelcome(category + "-" + id)
            }
            // Return to an earlier action, then use it. Existence or a single hittable pixel is not success.
            let start = element("onboarding.start")
            revealWelcome(start)
            XCTAssertTrue(start.isEnabled)
            start.tap()
            XCTAssertTrue(headline.waitForNonExistence(timeout: 15), "Get started must leave the welcome")
            XCTAssertTrue(element("onboarding.option.beginner").waitForExistence(timeout: 15))
            app.terminate()
        }
    }

    private enum WelcomeEdge { case top, bottom, whole }

    private func captureWelcome(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "urdu-welcome-" + name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "urdu-welcome-" + name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    /// A heading taller than the screen is read by scrolling from its first line to its last. Controls, unlike
    /// that heading, must fit completely inside the scroll viewport. All observations are retained with the image.
    private func revealWelcome(_ target: XCUIElement, edge: WelcomeEdge = .whole) {
        let scroll = app.scrollViews["onboarding.welcome.scroll"].firstMatch
        XCTAssertTrue(scroll.exists, "The Urdu welcome needs a real vertical scroll view")
        var observations: [String] = []
        defer {
            let trace = XCTAttachment(string: observations.joined(separator: "\n"))
            trace.name = "urdu-welcome-scroll-" + target.identifier + "-\(edge)"
            trace.lifetime = .keepAlways
            add(trace)
        }
        for attempt in 0..<16 {
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 0, dy: 4)
            let frame = target.frame
            let wanted: CGRect
            switch edge {
            case .top: wanted = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: min(24, frame.height))
            case .bottom: wanted = CGRect(x: frame.minX, y: frame.maxY - min(24, frame.height), width: frame.width, height: min(24, frame.height))
            case .whole: wanted = frame
            }
            let valid = !viewport.isNull && !viewport.isEmpty && !wanted.isNull && !wanted.isEmpty
                && [wanted.minX, wanted.maxX, wanted.minY, wanted.maxY].allSatisfy { $0.isFinite }
            let contained = valid && viewport.contains(wanted)
            observations.append("attempt=\(attempt) viewport=\(viewport) target=\(frame) wanted=\(wanted) contained=\(contained)")
            if contained && target.isHittable { return }
            guard valid, wanted.height <= viewport.height,
                  wanted.minX >= viewport.minX, wanted.maxX <= viewport.maxX, !contained else { break }
            let distance = min(viewport.height * 0.45, max(-viewport.height * 0.45, viewport.midY - wanted.midY))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: viewport.minX + 24, dy: viewport.midY))
            let to = origin.withOffset(CGVector(dx: viewport.minX + 24, dy: viewport.midY + distance))
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        captureWelcome("unreachable-" + target.identifier)
        XCTFail("The welcome target must be visible inside its own scroll viewport and hittable: \(target.identifier), \(edge)")
    }

    func testDeferredQuestionsPersistOnlyForTheInstallationThatSkippedThem() {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launch()
        let justTune = element("onboarding.justTune")
        XCTAssertTrue(justTune.waitForExistence(timeout: 25))
        justTune.tap()
        XCTAssertTrue(justTune.waitForNonExistence(timeout: 15), "The welcome must actually dismiss")
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        assertHittable(app.tabBars.buttons["Learn"])

        // The same installation keeps its promise to ask when Learn opens, even after relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        XCTAssertTrue(justTune.waitForNonExistence(timeout: 10), "Relaunch must not return to the welcome")
        assertHittable(app.tabBars.buttons["Learn"])
        app.tabBars.buttons["Learn"].tap()
        let question = element("onboarding.option.beginner")
        XCTAssertTrue(question.waitForExistence(timeout: 10))

        // A separate installation has its own completed onboarding and an unobstructed Learn screen.
        app.terminate()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        app.tabBars.buttons["Learn"].tap()
        let lesson = element("learn.continue")
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        XCTAssertTrue(lesson.isHittable)
        XCTAssertFalse(question.exists)
    }

    /// A strum with a missing open G must mark string 3 silent and keep the chord unfinished.
    func testADeadStringIsNamedWithoutCompletingTheChord() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchEnvironment["TIMBRE_SCENE"] = "lesson-dead-string"
        app.launch()
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30))
        let silent = element("lesson.chord.string.3.silent")
        XCTAssertTrue(silent.waitForExistence(timeout: 30), "the silent open G is identified")
        XCTAssertTrue(element("lesson.chord.pending").exists, "the chord still needs a clean strum")
        XCTAssertFalse(element("lesson.chord.complete").exists, "a missing string cannot complete the chord")
        XCTAssertTrue(element("lesson.chord.string.6.heard").exists, "the low E rang in the same strum")
    }

    /// Settings › Try Timbre Pro opens the paywall over the settings sheet: the yearly card is there and can be
    /// tapped, and so is the month.
    func testThePaywallFromSettingsShowsItsPlans() {
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launch()
        let settings = element("settings.open")
        XCTAssertTrue(settings.waitForExistence(timeout: 25))
        settings.tap()
        let pro = element("settings.pro")
        XCTAssertTrue(pro.waitForExistence(timeout: 10))
        pro.tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        let yearly = element("paywall.plan.yearly")
        XCTAssertTrue(yearly.waitForExistence(timeout: 15), "the yearly card is drawn")
        XCTAssertTrue(yearly.isHittable, "the yearly card can be tapped")
        XCTAssertTrue(element("paywall.plan.monthly").exists)
        yearly.tap()
        XCTAssertTrue(yearly.isSelected)
    }

    /// "Just tune" on the welcome screen: one tap to the tuner, listening (the demo pitch stands in for the microphone,
    /// whose own prompt would be the second tap), with no question asked first.
    func testJustTuneReachesAListeningTuner() {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        app.launch()
        let justTune = element("onboarding.justTune")
        XCTAssertTrue(justTune.waitForExistence(timeout: 25))
        justTune.tap()
        XCTAssertTrue(justTune.waitForNonExistence(timeout: 15), "The welcome must actually dismiss")
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15), "the tuner is on screen")
        assertHittable(app.tabBars.buttons["Learn"])
        XCTAssertFalse(element("onboarding.option.beginner").exists, "no question came first")
        let probe = element("stage.state")
        let deadline = Date().addingTimeInterval(15)
        var listening = false
        while !listening && Date() < deadline {
            if let label = (try? probe.snapshot())?.label, let field = label.split(separator: " ").first(where: { $0.hasPrefix("listening=") }),
               let seconds = Double(field.dropFirst("listening=".count)), seconds > 0 {
                listening = true
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(listening || !probe.exists, "the tuner is listening")
    }
}
