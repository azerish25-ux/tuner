import XCTest
import TimbreCore
@testable import Timbre

/// One resolver for the app language: strings built in code follow a language picked in Settings, as SwiftUI's
/// `Text` does through the root view's locale, and "system" is exactly what Foundation would use.
final class LocalizationTests: XCTestCase {
    override func tearDown() {
        TimbreLocalization.language = TimbreLocalization.system
        super.tearDown()
    }

    func testStringsBuiltInCodeFollowAPickedLanguage() {
        TimbreLocalization.language = "de"
        XCTAssertEqual(String(localized: "Get started"), "Los geht's")
        XCTAssertEqual(LocalizedText(key: "Get started", defaultValue: "Get started").localized, "Los geht's")
        TimbreLocalization.language = TimbreLocalization.system
        XCTAssertEqual(TimbreLocalization.bundle, Bundle.main)
        XCTAssertEqual(String(localized: "Get started"), String(localized: "Get started", bundle: .main))
    }

    func testEachSettingResolvesToALanguageTheAppHas() {
        let launched = Bundle.main.preferredLocalizations.first
        XCTAssertEqual(TimbreLocalization.resolvedLanguage(for: TimbreLocalization.system), launched)
        XCTAssertEqual(TimbreLocalization.resolvedLanguage(for: "de"), "de")
        XCTAssertEqual(TimbreLocalization.resolvedLanguage(for: "xx"), launched, "a language the app doesn't have")
        XCTAssertTrue(TimbreLocalization.isRightToLeft("ar"))
        XCTAssertFalse(TimbreLocalization.isRightToLeft("de"))
        TimbreLocalization.language = "xx"
        XCTAssertEqual(TimbreLocalization.bundle, Bundle.main)
    }
}
