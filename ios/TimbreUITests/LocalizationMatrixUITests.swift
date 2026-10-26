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
            for field in ["tune", "learn", "progress"] {
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
            application.terminate()
            if language == "bg" {
                application.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
                application.launch()
                let instrument = application.buttons["tune.instrument"]
                XCTAssertTrue(instrument.waitForExistence(timeout: 30))
                capture(application, name: "l10n-\(language)-tuner-ax5")
                try assertInstrumentFits(application)
                application.terminate()
            }
            print("TIMBRE_L10N_MATRIX_TESTED \(language)")
        }
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
