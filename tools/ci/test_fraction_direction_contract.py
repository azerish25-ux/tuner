"""Guard semantic counter structure and the independent native rendering oracle."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class FractionDirectionContract(unittest.TestCase):
    def test_separate_localized_runs_and_single_spoken_label(self):
        source = (ROOT / "ios/Timbre/Design/Kit.swift").read_text()
        fraction = source.split("static func fraction(", 1)[1].split("// MARK:", 1)[0]
        self.assertIn("HStack(spacing: 0)", fraction)
        tokens = ['Text("\\(done)").lineLimit(1)', 'Text(verbatim: "\\u{2009}/\\u{2009}").lineLimit(1)',
                  'Text("\\(total)").lineLimit(1)']
        positions = [fraction.index(token) for token in tokens]
        self.assertEqual(positions, sorted(positions))
        self.assertIn(".environment(\\.layoutDirection, .leftToRight)", fraction)
        self.assertIn(".accessibilityElement(children: .ignore)", fraction)
        self.assertEqual(fraction.count('.accessibilityLabel(Text("\\(done) of \\(total)"))'), 1)

    def test_counter_retains_noninteractive_text_semantics_without_layout_workarounds(self):
        source = (ROOT / "ios/Timbre/Design/Kit.swift").read_text()
        fraction = source.split("static func fraction(", 1)[1].split("// MARK:", 1)[0]
        self.assertIn(".accessibilityAddTraits(.isStaticText)", fraction)
        for workaround in [".accessibilityHidden", ".allowsHitTesting", ".tapTarget", ".frame(",
                           ".onTapGesture", "Button(", ".isButton"]:
            self.assertNotIn(workaround, fraction)
        tune = (ROOT / "ios/Timbre/Tune/TuneView.swift").read_text()
        quest = tune.split("private var questLine:", 1)[1].split("private var sideControls:", 1)[0]
        self.assertIn(".accessibilityElement(children: .combine)", quest)
        self.assertNotIn(".tapTarget", quest)

    def test_native_quest_regression_requires_single_static_text_and_unfiltered_hit_audit(self):
        source = (ROOT / "ios/TimbreUITests/SmokeUITests.swift").read_text()
        test = source.split("func testTuningQuestIsOneStaticTextElementNotAnInteractiveTarget()", 1)[1].split("func testTheTunerLocksAString()", 1)[0]
        for token in ["XCTAssertEqual(quests.count, 1", "XCTAssertEqual(quest.elementType, .staticText",
                      'XCTAssertEqual(quest.label, "Quest · tune every string, 0 of 6, +20 XP")',
                      "XCTAssertEqual(quest.staticTexts.matching",
                      'NSPredicate(format: "label == %@", "Quest · tune every string, 0 of 6, +20 XP")',
                      "try app.performAccessibilityAudit(for: .hitRegion)",
                      'hierarchy.lifetime = .keepAlways', 'screenshot.lifetime = .keepAlways']:
            self.assertIn(token, test)
        self.assertNotIn("try?", test)

    def test_enclosing_button_regression_uses_compact_available_production_fraction(self):
        source = (ROOT / "ios/TimbreUITests/SmokeUITests.swift").read_text()
        test = source.split('func testFractionInsideAnUnearnedBadgePreservesItsButtonRole()', 1)[1].split('func testTheTunerLocksAString()', 1)[0]
        for token in ['"Progress"', '"badge."', '" of "', 'XCTAssertEqual(badge.elementType, .button',
                      'XCTAssertTrue(counter.exists', 'scrollTo(badge)']:
            self.assertIn(token, test)
        self.assertNotIn('practice.nextBadge', source)

    def test_oracle_is_independent_and_exact(self):
        source = (ROOT / "ios/TimbreAppTests/FractionDirectionTests.swift").read_text()
        oracle = source.split("func testRenderedOperandsMatchIndependentPhysicalOrderOracle()", 1)[1].split("func testCompactRingCounterStaysInsideItsInteriorAtNormalAndAXSizes", 1)[0]
        self.assertNotIn("Text.fraction", oracle)
        for token in ["٠١٢٣٤٥٦٧٨٩", "۰۱۲۳۴۵۶۷۸۹", '"he_IL"', '"en_US"',
                      "[(3, 6), (12, 34)]", "try XCTUnwrap(character.wholeNumberValue",
                      "let doneDigits = try numeral(done)", "let totalDigits = try numeral(total)",
                      "Text(verbatim: doneDigits)",
                      "Text(verbatim: totalDigits)", "XCTAssertEqual(actual, expectedPixels",
                      "XCTAssertNotEqual(actual, swappedPixels", "LayoutDirection.leftToRight, .rightToLeft"]:
            self.assertIn(token, oracle)
        self.assertIn("XCTAssertEqual(leftToRight, rightToLeft", source)
        self.assertIn("XCTAssertNotEqual(threeOfSix, sixOfThree)", source)
        self.assertIn("CGBitmapInfo.byteOrder32Big", source)

    def test_compact_regression_has_unclipped_ink_bounds_and_negative_control(self):
        source = (ROOT / "ios/TimbreAppTests/FractionDirectionTests.swift").read_text()
        for token in ["DynamicTypeSize.large, .accessibility5", ".heroNumeral(cap: .xxxLarge, minimumScale: 0.5)",
                      ".frame(width: 28)", "XCTAssertEqual(actualPixels, expectedPixels",
                      "XCTAssertNotEqual(actualPixels, swappedPixels", "XCTAssertTrue(try inkFitsInterior(actualPixels)",
                      "XCTAssertFalse(try inkFitsInterior(negative)", "left >= 106 && right < 134"]:
            self.assertIn(token, source)
        self.assertNotIn(".clipped()", source)
        fraction = (ROOT / "ios/Timbre/Design/Kit.swift").read_text().split("static func fraction(", 1)[1].split("// MARK:", 1)[0]
        self.assertNotIn(".fixedSize()", fraction)


if __name__ == "__main__":
    unittest.main()
