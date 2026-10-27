import XCTest
@testable import TimbreCore

final class TimbreLocalizationTests: XCTestCase {
    func testCanonicalLanguagePreservesChineseScript() {
        let aliases = ["zh-Hant": "zh-Hant", "zh-Hant-CN": "zh-Hant", "zh_TW": "zh-Hant",
                       "zh-HK": "zh-Hant", "zh-MO": "zh-Hant", "zh-Hans-TW": "zh-CN",
                       "zh-CN": "zh-CN", "zh-SG": "zh-CN", "zh": "zh-CN", "MS_my": "ms",
                       "or-IN": "or", "de-DE": "de", "nb-NO": "no", "xx": "xx"]
        for (alias, expected) in aliases {
            XCTAssertEqual(TimbreLocalization.canonicalLanguage(for: alias), expected, alias)
        }
    }
}
