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
        // Include actual phone spellings such as Bokmål nb and script-qualified Simplified Chinese/Punjabi.
        let cases = [("en-CA", "en"), ("ar-SA", "ar"), ("bg-BG", "bg"), ("bn-BD", "bn"),
                     ("ca-ES", "ca"), ("cs-CZ", "cs"), ("da-DK", "da"), ("de-DE", "de"),
                     ("el-GR", "el"), ("es-MX", "es"), ("et-EE", "et"), ("fa-IR", "fa"),
                     ("fi-FI", "fi"), ("fr-CA", "fr"), ("gu-IN", "gu"), ("he-IL", "he"),
                     ("hi-IN", "hi"), ("hr-HR", "hr"), ("hu-HU", "hu"), ("id-ID", "id"),
                     ("is-IS", "is"), ("it-IT", "it"), ("ja-JP", "ja"), ("kn-IN", "kn"),
                     ("ko-KR", "ko"), ("lt-LT", "lt"), ("lv-LV", "lv"), ("ml-IN", "ml"),
                     ("mr-IN", "mr"), ("ms-MY", "ms"), ("or-IN", "or"), ("nl-NL", "nl"), ("nb-NO", "no"), ("pa-Guru-IN", "pa"),
                     ("pl-PL", "pl"), ("pt-BR", "pt"), ("ro-RO", "ro"), ("ru-RU", "ru"),
                     ("sk-SK", "sk"), ("sl-SI", "sl"), ("sv-SE", "sv"), ("sw-KE", "sw"),
                     ("ta-IN", "ta"), ("te-IN", "te"), ("th-TH", "th"), ("tr-TR", "tr"),
                     ("uk-UA", "uk"), ("ur-PK", "ur"), ("vi-VN", "vi"), ("zh-Hans-CN", "zh-CN"),
                     ("zh-Hant-TW", "zh-Hant"), ("zu-ZA", "zu")]
        XCTAssertEqual(cases.count, 52)
        XCTAssertEqual(Set(cases.map { $0.1 }), Set(available.filter { $0 != "Base" }))
        for (phone, expected) in cases {
            XCTAssertEqual(Bundle.preferredLocalizations(from: available, forPreferences: [phone]).first,
                           expected, "phone language \(phone)")
        }
    }

    func testExplicitRegionalAliasesResolveToTheCorrectScript() throws {
        let aliases = ["zh-Hant": "zh-Hant", "zh-TW": "zh-Hant", "zh-HK": "zh-Hant", "zh-MO": "zh-Hant",
                       "zh-Hans": "zh-CN", "zh-CN": "zh-CN", "zh-SG": "zh-CN", "ms-MY": "ms", "or-IN": "or"]
        for (alias, canonical) in aliases {
            XCTAssertEqual(TimbreLocalization.resolvedLanguage(for: alias), canonical)
            XCTAssertEqual(Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: [alias]).first, canonical)
            TimbreLocalization.language = alias
            let path = try XCTUnwrap(Bundle.main.path(forResource: canonical, ofType: "lproj"))
            let expected = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(TimbreLocalization.bundle.bundleURL, expected.bundleURL)
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

    @MainActor
    func testSongsTabUsesInterfaceLanguageWhenCourseTextIsMissing() {
        TimbreLocalization.language = "bg"
        let missing = LearnCourse(id: "songs", title: LearnText(key: "TEST_MISSING_SONGS_TITLE", "Songs"),
                                  subtitle: LearnText(""), instrument: nil, symbol: "music.note.list", accent: "mint", units: [])
        XCTAssertEqual(SongsView.title(in: Curriculum(courses: [missing])), "Песни")
        XCTAssertEqual(SongsView.title(in: Curriculum(courses: [])), "Песни")
    }

    @MainActor
    func testSongsTabPreservesAnAvailableTranslatedCourseTitle() throws {
        TimbreLocalization.language = "it"
        let curriculum = try Curriculum.bundled()
        let title = try XCTUnwrap(curriculum.course(id: "songs")?.title)
        XCTAssertNotEqual(title.localized, title.defaultValue)
        XCTAssertEqual(SongsView.title(in: curriculum), title.localized)
    }

}
