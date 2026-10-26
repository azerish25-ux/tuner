import XCTest

/// Runs before each listing capture set. Requested launch arguments alone do not
/// establish that the app actually displayed the expected language, especially
/// for a listing-only language whose documented UI fallback is English.
final class ListingCaptureEvidenceUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        XCUIDevice.shared.orientation = .portrait
    }

    func testRequestedLanguageActuallyAppears() throws {
        try XCTSkipIf(CaptureLocalization.listingLocale.isEmpty, "Only the listing-assets workflow selects this evidence check")
        XCUIDevice.shared.orientation = .portrait
        let application = XCUIApplication()
        app = application
        application.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        application.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        application.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        application.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        application.launchArguments = CaptureLocalization.launchArguments
        application.launch()
        CaptureLocalization.recordLaunch(context: "language-evidence")
        let stage = application.descendants(matching: .any).matching(identifier: "tune.stage").firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 30), "The actual app did not reach its tuner")

        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = "listing-language-" + CaptureLocalization.listingLocale
        picture.lifetime = .keepAlways
        add(picture)
        let tabs = [("tune", "Tune"), ("learn", "Learn"), ("songs", "Songs"), ("practice", "Practice"), ("progress", "Progress")]
        var observed: [String: String] = [:]
        for (field, source) in tabs {
            let expected = try XCTUnwrap(CaptureLocalization.tabLabel(source), "Missing shipped capture fixture: \(field)")
            // iPadOS can place these in its top navigation rather than a UITabBar.
            let button = application.buttons.matching(NSPredicate(format: "label == %@", expected)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 10), "\(CaptureLocalization.language): missing translated tab \(field)")
            XCTAssertTrue(button.isHittable, "\(field): the expected app tab is not visible")
            XCTAssertEqual(button.label, expected, "\(field): actual app label differs from its shipped table")
            observed[field] = button.label
        }
        CaptureLocalization.recordVerified(fields: tabs.map { $0.0 }, observed: observed)
    }
}
