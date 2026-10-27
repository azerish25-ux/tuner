import XCTest

/// Opt-in per-language welcome, tab and imported-lesson checks, with screenshots of the actual application.
final class LocalizationMatrixUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testLocalizedWelcomeAndTabs() throws {
        let selected = ProcessInfo.processInfo.environment["TIMBRE_L10N_MATRIX"] ?? ""
        try XCTSkipIf(selected.isEmpty, "Run the localization matrix workflow to select languages")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalizationWelcomeExpected", withExtension: "json"))
        let expected = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        let languages = selected.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        XCTAssertFalse(languages.contains(""), "Empty locale in matrix selection")
        XCTAssertEqual(Set(languages).count, languages.count, "Duplicate matrix locales")
        XCTAssertEqual(Set(expected.keys), Set(languages), "Fixture and runner selections differ")
        for language in languages {
            let labels = try XCTUnwrap(expected[language], "Missing expectations for \(language)")
            let application = XCUIApplication()
            app = application
            application.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
            application.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
            application.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language.replacingOccurrences(of: "-", with: "_")]
            application.launch()
            let start = application.descendants(matching: .any).matching(identifier: "onboarding.start").firstMatch
            XCTAssertTrue(start.waitForExistence(timeout: 30), "\(language): welcome did not appear")
            XCTAssertEqual(start.label, try XCTUnwrap(labels["start"]), "\(language): start button")
            for field in ["headline", "subline"] {
                let value = try XCTUnwrap(labels[field])
                let element = application.staticTexts.matching(NSPredicate(format: "label == %@", value)).firstMatch
                XCTAssertTrue(element.waitForExistence(timeout: 5), "\(language): missing translated \(field)")
            }
            capture(application, name: "l10n-\(language)-welcome")
            if language == "bg" {
                try assertNoClipping(application, identifiers: ["onboarding.headline"], labels: [try XCTUnwrap(labels["headline"])])
            }
            application.terminate()
            application.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
            application.launch()
            let tabs = application.tabBars.firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 30), "\(language): tabs did not appear")
            for field in ["tune", "learn", "songs", "practice", "progress"] {
                let value = try XCTUnwrap(labels[field])
                XCTAssertTrue(tabs.buttons[value].exists, "\(language): missing translated tab \(field)")
            }
            capture(application, name: "l10n-\(language)-tuner")
            if language == "bg" { try assertInstrumentFits(application) }
            if labels["lesson_status"] == "available" {
                try assertLocalizedLesson(application, language: language, labels: labels)
            } else {
                XCTAssertEqual(labels["lesson_status"], "pending", "Unknown lesson fixture status")
                print("TIMBRE_L10N_LESSON_PENDING \(language)")
            }
            try assertUnavailableSongRequest(application, language: language, labels: labels)
            application.terminate()
            if language == "bg" {
                application.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
                application.launch()
                let instrument = application.buttons["tune.instrument"]
                XCTAssertTrue(instrument.waitForExistence(timeout: 30))
                capture(application, name: "l10n-\(language)-tuner-ax5")
                try assertInstrumentFits(application)
                try assertAccessibleTunerCanScroll(application, language: language)
                application.terminate()
            }
            print("TIMBRE_L10N_MATRIX_TESTED \(language)")
        }
    }

    /// Automated runs have no telemetry app ID, so this checks the real unavailable-build alert without sending.
    private func assertUnavailableSongRequest(_ app: XCUIApplication, language: String, labels: [String: String]) throws {
        let title = try XCTUnwrap(labels["request_title"])
        let message = try XCTUnwrap(labels["request_unavailable"])
        let support = try XCTUnwrap(labels["request_support"])
        let cancel = try XCTUnwrap(labels["request_cancel"])
        let tune = app.tabBars.firstMatch.buttons[try XCTUnwrap(labels["tune"])]
        let alert = app.alerts.firstMatch
        // Also restore Tune if a throwing assertion interrupts the route, before the caller terminates the app.
        defer {
            let dismiss = alert.buttons[cancel]
            if alert.exists && dismiss.exists && dismiss.isHittable { dismiss.tap() }
            XCTAssertTrue(tune.waitForExistence(timeout: 15), "\(language): Tune tab missing after request check")
            XCTAssertTrue(tune.isHittable, "\(language): Tune tab is not reachable after request check")
            tune.tap()
            XCTAssertTrue(tune.isSelected, "\(language): Tune must remain selected for the next launch")
            XCTAssertTrue(app.buttons["tune.instrument"].waitForExistence(timeout: 15), "\(language): tuner did not reopen")
        }
        let songs = app.tabBars.firstMatch.buttons[try XCTUnwrap(labels["songs"])]
        XCTAssertTrue(songs.waitForExistence(timeout: 15))
        XCTAssertTrue(songs.isHittable)
        songs.tap()
        XCTAssertTrue(songs.isSelected, "\(language): Songs tab did not open")
        let request = app.buttons["songs.request"]
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<24 {
            if request.exists && request.isHittable && request.frame.minY >= app.frame.minY &&
                request.frame.maxY <= tabBar.frame.minY { break }
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(request.exists && request.isHittable, "\(language): request footer is not reachable")
        XCTAssertEqual(request.label, title, "\(language): request footer label")
        XCTAssertGreaterThanOrEqual(request.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(request.frame.maxY, tabBar.frame.minY)
        request.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 15), "\(language): request alert did not open")
        let heading = alert.staticTexts[title]
        let body = alert.staticTexts[message]
        let contact = alert.buttons[support]
        let dismiss = alert.buttons[cancel]
        for node in [alert, heading, body, contact, dismiss] {
            XCTAssertTrue(node.exists, "\(language): missing request alert element")
            XCTAssertTrue(node.isHittable, "\(language): request alert element is not visible")
            XCTAssertFalse(node.frame.isEmpty, "\(language): request alert element has no visible bounds")
            XCTAssertGreaterThanOrEqual(node.frame.minX, app.frame.minX)
            XCTAssertGreaterThanOrEqual(node.frame.minY, app.frame.minY)
            XCTAssertLessThanOrEqual(node.frame.maxX, app.frame.maxX)
            XCTAssertLessThanOrEqual(node.frame.maxY, app.frame.maxY)
        }
        XCTAssertEqual(alert.textFields.count, 0, "\(language): unavailable requests must not show a submission field")
        capture(app, name: "l10n-\(language)-song-request-unavailable")
        dismiss.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10), "\(language): localized Cancel did not dismiss the request alert")
        print("TIMBRE_L10N_REQUEST_UNAVAILABLE_TESTED \(language)")
    }

    /// Exercise the real Learn route using the phone-language launch arguments, not a manual language override.
    private func assertLocalizedLesson(_ app: XCUIApplication, language: String, labels: [String: String]) throws {
        app.tabBars.firstMatch.buttons[try XCTUnwrap(labels["learn"])].tap()
        let node = app.descendants(matching: .any).matching(identifier: "learn.lesson.gtr-1-1").firstMatch
        _ = node.waitForExistence(timeout: 5)
        // A fresh Learn tab starts above the path: reveal the first unit below the course and Continue cards.
        for _ in 0..<8 where !node.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(node.isHittable, "\(language): first guitar lesson cannot be opened")
        node.tap()
        let close = app.descendants(matching: .any).matching(identifier: "lesson.close").firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        for field in ["lesson_title", "lesson_heading", "lesson_body"] {
            let value = try XCTUnwrap(labels[field])
            // LessonHeader hides its children and supplies its own label, so the title need not be a StaticText.
            let query = field == "lesson_title" ? app.descendants(matching: .any) : app.staticTexts
            let text = query.matching(NSPredicate(format: "label == %@", value)).firstMatch
            if field != "lesson_title" {
                // Long translations can put the explanation below the fold; reveal it before requiring existence.
                for _ in 0..<4 where !text.isHittable { app.swipeUp(velocity: .slow) }
            }
            XCTAssertTrue(text.waitForExistence(timeout: 15), "\(language): missing localized \(field)")
            XCTAssertTrue(text.isHittable, "\(language): localized \(field) is not visible")
        }
        capture(app, name: "l10n-\(language)-lesson")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 15), "\(language): lesson did not close")
        let tune = app.tabBars.firstMatch.buttons[try XCTUnwrap(labels["tune"])]
        XCTAssertTrue(tune.waitForExistence(timeout: 15))
        tune.tap() // Keep the subsequent accessibility-size tuner launch on the same tab.
        XCTAssertTrue(app.buttons["tune.instrument"].waitForExistence(timeout: 15), "\(language): tuner did not reopen")
        print("TIMBRE_L10N_LESSON_TESTED \(language)")
    }

    /// Large localized text must remain reachable, not be squeezed into a screen-height stack.
    private func assertAccessibleTunerCanScroll(_ app: XCUIApplication, language: String) throws {
        let scroll = app.scrollViews["tune.accessible.scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "Accessibility tuner must scroll")
        let tabBar = app.tabBars.firstMatch
        for identifier in ["tune.status", "tune.string.rail"] {
            let target = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            for _ in 0..<10 {
                if target.exists && target.isHittable && target.frame.maxY <= tabBar.frame.minY { break }
                scroll.swipeUp(velocity: .slow)
            }
            XCTAssertTrue(target.exists && target.isHittable, "\(identifier) must be reachable at AX5")
            XCTAssertGreaterThanOrEqual(target.frame.minY, app.frame.minY, "\(identifier) above viewport")
            XCTAssertLessThanOrEqual(target.frame.maxY, tabBar.frame.minY, "\(identifier) behind tab bar")
            capture(app, name: "l10n-\(language)-ax5-\(identifier)")
        }
        // A reachable rail container does not prove that its last horizontally scrolling control is usable.
        // Fresh storage opens the standard guitar: course 6 is its high E string, at the right-hand end.
        let rail = app.scrollViews["tune.string.scroll"].firstMatch
        XCTAssertTrue(rail.waitForExistence(timeout: 10), "The horizontal string scroll view must exist at AX5")
        XCTAssertTrue(rail.isHittable, "Swipe the chip row, above its multiline end captions")
        let lastString = app.buttons["string.6"]
        XCTAssertTrue(lastString.waitForExistence(timeout: 10))
        for _ in 0..<6 {
            if lastString.isHittable,
               lastString.frame.minX >= app.frame.minX,
               lastString.frame.maxX <= app.frame.maxX { break }
            rail.swipeLeft(velocity: .slow)
        }
        XCTAssertTrue(lastString.isHittable, "The high E string must be reachable by scrolling at AX5")
        XCTAssertGreaterThanOrEqual(lastString.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(lastString.frame.maxX, app.frame.maxX)
        lastString.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: lastString)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                       "The revealed high E string must respond to a tap at AX5")
        capture(app, name: "l10n-\(language)-ax5-last-string-selected")
    }

    private func assertInstrumentFits(_ app: XCUIApplication) throws {
        let instrument = app.buttons["tune.instrument"]
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(instrument.isHittable)
        XCTAssertTrue(settings.isHittable)
        XCTAssertFalse(instrument.frame.intersects(settings.frame), "The title and settings must not overlap")
        XCTAssertGreaterThanOrEqual(instrument.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(instrument.frame.maxX, app.frame.maxX)
        try assertNoClipping(app, identifiers: ["tune.instrument", "tune.instrument.name"], labels: [instrument.label])
    }

    /// Keep the clipping gate scoped to the labels under test; the screenshot also needs visual inspection.
    private func assertNoClipping(_ app: XCUIApplication, identifiers: Set<String>, labels: Set<String>) throws {
        try app.performAccessibilityAudit(for: .textClipped) { issue in
            let snapshot = try? issue.element?.snapshot()
            return !identifiers.contains(snapshot?.identifier ?? "") && !labels.contains(snapshot?.label ?? "")
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
