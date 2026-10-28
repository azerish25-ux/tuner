"""Settings source/resource gates; native navigation, shaping and actual captures remain separate evidence."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/l10n"))
import report
import shipping


def source(path):
    return (ROOT / path).read_text()


class SettingsLocalizationContract(unittest.TestCase):
    def test_every_existing_temperament_key_is_present_in_every_shipping_language(self):
        pitch = source("ios/Sources/TimbreCore/Catalog/PitchMath.swift")
        identifiers = set(re.findall(r'Temperament\(id: "([^"]+)"', pitch))
        self.assertEqual(identifiers, {"equal", "just", "pythagorean", "meantone", "werckmeister"})
        locales = shipping.declared()
        self.assertEqual(len(locales), shipping.RELEASE_LANGUAGE_COUNT)
        for language in locales:
            table = report.read_strings(ROOT / f"ios/Timbre/Resources/{language}.lproj/Localizable.strings")
            for identifier in identifiers:
                with self.subTest(language=language, identifier=identifier):
                    self.assertTrue(table.get("timbre_bench_temperament_" + identifier, "").strip())

    def test_picker_uses_app_resolver_not_literal_english_data_names(self):
        view = source("ios/Timbre/Settings/SettingsView.swift")
        self.assertIn("Text(verbatim: SettingsOptionLabel.temperamentName($0)).tag($0.id)", view)
        self.assertNotIn("Text($0.name)", view)
        labels = source("ios/Timbre/Settings/SettingsOptionLabel.swift")
        self.assertIn('NSLocalizedString("timbre_bench_temperament_" + temperament.id, bundle: .app, value: temperament.name', labels)
        native = source("ios/TimbreAppTests/SettingsOptionLabelTests.swift")
        for token in ["Bundle.main.localizations", 'TimbreLocalization.language = "ar"',
                      'SettingsOptionLabel.temperamentName(.equal), "متساوي"', "MISSING_SETTING_TRANSLATION"]:
            self.assertIn(token, native)

    def test_only_scientific_token_is_isolated_without_font_or_layout_workarounds(self):
        view = source("ios/Timbre/Settings/SettingsView.swift")
        picker = view.split("private var precisionPicker:", 1)[1].split("private static func precisionName", 1)[0]
        self.assertIn('Self.precisionName(precision) + Text(verbatim: " " + SettingsOptionLabel.precisionTolerance(precision))', picker)
        labels = source("ios/Timbre/Settings/SettingsOptionLabel.swift")
        self.assertIn(r'"\u{2066}±\(Int(precision.bandCents))¢\u{2069}"', labels)
        for workaround in ["layoutDirection", "minimumScaleFactor", "lineLimit", "dynamicTypeSize", ".clipped("]:
            self.assertNotIn(workaround, picker)
            self.assertNotIn(workaround, labels)

    def test_settings_capture_requires_positive_visible_identity(self):
        view = source("ios/Timbre/Settings/SettingsView.swift")
        for identifier in ["settings.scroll", "settings.done"]:
            self.assertIn(f'.accessibilityIdentifier("{identifier}")', view)
        native = source("ios/TimbreUITests/AccessibilityMatrixUITests.swift")
        visible = native.split("private var settingsVisible:", 1)[1].split("private func openSettings", 1)[0]
        for token in ['app.scrollViews["settings.scroll"]', 'app.buttons["settings.done"]',
                      "scroll.exists && scroll.isHittable && done.exists && done.isHittable"]:
            self.assertIn(token, visible)
        capture = native.split("private func capture(_ screen:", 1)[1]
        self.assertLess(capture.index('screen == "settings" && !settingsVisible'), capture.index("XCTAttachment(screenshot:"))
        self.assertIn('return XCTFail("Refusing to label a non-Settings screen as Settings")', capture)
        opening = native.split("private func openSettings()", 1)[1].split("func testSettingsOpens", 1)[0]
        self.assertNotIn("guard strum.exists else { return true }", opening)
        self.assertIn("self.settingsVisible", opening)
        self.assertIn('guard element("tune.stage").exists, open.exists, open.isHittable else { break }', opening)
        self.assertIn("testSettingsOpensClosesAndReopensWithPositiveScreenIdentity", native)
        self.assertIn("XCTAssertFalse(settingsVisible", native)
        self.assertIn("done.waitForNonExistence(timeout: 10)", native)
        self.assertNotIn('app.buttons["Done"]', native)
        # The matrix remains diagnostic: an audit timeout is recorded as incomplete, not converted into a pass.
        self.assertIn('found.lines.append("The audit did not complete:', capture)
        self.assertIn(".textClipped, .dynamicType, .contrast, .hitRegion", capture)

    def test_native_precision_oracles_are_independent_and_include_negative_controls(self):
        native = source("ios/TimbreAppTests/SettingsOptionLabelTests.swift")
        for token in ["CTRunGetStringIndices", "CTRunGetPositions", "XCTAssertLessThan", "XCTAssertGreaterThan",
                      'let raw = "مبتدئ ±" + digit + "¢"', '"The Arabic name must not flip"',
                      "DynamicTypeSize.large, .accessibility5", "LayoutDirection.leftToRight, .rightToLeft",
                      'Text(verbatim: "±")', 'Text(verbatim: "¢")', "Text(verbatim: digit)",
                      "XCTAssertEqual(actual, oracle", "XCTAssertNotEqual(actual, wrong)",
                      "CGBitmapInfo.byteOrder32Big", '(.beginner, "±5¢"), (.standard, "±3¢"), (.pro, "±1¢")']:
            self.assertIn(token, native)
        oracle = native.split("let expected = HStack", 1)[1].split("let reversed = HStack", 1)[0]
        self.assertNotIn("SettingsOptionLabel", oracle)
        self.assertNotIn(r"\u{2066}", oracle)
        self.assertNotIn(".clipped()", native)


if __name__ == "__main__":
    unittest.main()
