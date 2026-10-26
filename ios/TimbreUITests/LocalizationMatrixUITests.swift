import XCTest

/// Opt-in per-language welcome and tab checks, with screenshots of the actual application.
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
