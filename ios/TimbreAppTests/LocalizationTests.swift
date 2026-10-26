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

    func testFreshSettingsAutomaticallyFollowPhoneLanguage() {
        XCTAssertEqual(UserSettings().language, TimbreLocalization.system)
        TimbreLocalization.language = UserSettings().language
        XCTAssertEqual(TimbreLocalization.bundle, Bundle.main)
        XCTAssertEqual(TimbreLocalization.locale(for: TimbreLocalization.system), Locale.current)
    }

    func testPhoneRegionsResolveThroughFoundationToAvailableAppLanguages() {
        // The production system path is Bundle.main, so use Foundation's own regional negotiation.
        let available = Bundle.main.localizations
        for (phone, expected) in [("de-DE", "de"), ("es-MX", "es"), ("pt-BR", "pt"),
                                  ("fa-IR", "fa"), ("ar-SA", "ar"), ("fr-CA", "fr")] {
            XCTAssertEqual(Bundle.preferredLocalizations(from: available, forPreferences: [phone]).first,
                           expected, "phone language \(phone)")
        }
    }

    func testLessonsUseTheSameAutomaticAndManualResolver() {
        let key = "L0009cb1a16"
        let english = "One string sounds dull. What's the likely cause?"
        let text = LearnText(key: key, english)
        TimbreLocalization.language = TimbreLocalization.system
        XCTAssertEqual(text.localized, Bundle.main.localizedString(forKey: key, value: english, table: "Learn"))
        TimbreLocalization.language = "de"
        XCTAssertEqual(text.localized, "Eine Saite klingt dumpf. Was ist die wahrscheinliche Ursache?")
        TimbreLocalization.language = TimbreLocalization.system
        XCTAssertEqual(TimbreLocalization.bundle, Bundle.main, "System restores phone language after override")
        XCTAssertEqual(text.localized, Bundle.main.localizedString(forKey: key, value: english, table: "Learn"))
    }

    func testMissingLessonTextIsFallbackNotResolverFailure() {
        TimbreLocalization.language = "fa"
        XCTAssertEqual(TimbreLocalization.resolvedLanguage(for: "fa"), "fa")
        // Deliberately nonexistent key: remains valid even after Persian lessons are delivered.
        let missing = LearnText(key: "TEST_MISSING_LESSON_KEY", "Temporary English fallback")
        XCTAssertEqual(missing.localized, "Temporary English fallback")
        XCTAssertNotEqual(TimbreLocalization.bundle, Bundle.main)
    }

    func testPersianOwnershipLinkStartsInItsReadingDirection() {
        TimbreLocalization.language = "fa"
        XCTAssertEqual(String(localized: "I already have Timbre Pro"), "از قبل Timbre Pro را دارم")
    }

}
