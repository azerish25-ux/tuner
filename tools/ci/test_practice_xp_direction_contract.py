"""Guard existing localization keys; native shaping/rendering remains mandatory."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
KEY = '%lld / %lld XP · next: %@'


class PracticeXPDirectionContract(unittest.TestCase):
    def test_all_existing_translations_keep_supported_prefix_and_key(self):
        translations = list((ROOT / 'tools/l10n/translations').glob('*.json'))
        found = 0
        for path in translations:
            content = json.loads(path.read_text()).get('Localizable.strings', {})
            if KEY in content:
                found += 1
                self.assertTrue(content[KEY].startswith(('%lld / %lld', '%lld／%lld')), path.name)
                if content[KEY].startswith('%lld／%lld'):
                    self.assertEqual(path.stem, 'zh-Hant', 'New separator use needs explicit review')
                self.assertEqual(content[KEY].count('%@'), 1, path.name)
                self.assertEqual(content[KEY].count('%lld'), 2, path.name)
        self.assertEqual(found, 51)
        # English is the unchanged source key: 51 translated locales plus source = 52.
        self.assertTrue(KEY.startswith("%lld / %lld"))
        self.assertEqual(found + 1, 52)

    def test_both_call_sites_share_helper_without_direction_override(self):
        source = (ROOT / 'ios/Timbre/Practice/PracticeView.swift').read_text()
        self.assertEqual(source.count('PracticeXPProgress(done: xp - level.floor,'), 2)
        helper = (ROOT / 'ios/Timbre/Practice/PracticeXPProgress.swift').read_text()
        self.assertIn('guard let fraction = fractionPrefixes.first(where: { template.hasPrefix($0.prefix) }) else { return nil }', helper)
        self.assertIn('(prefix: \"%lld／%lld\", separator: \"／\")', helper)
        self.assertIn('String(template.dropFirst(fraction.prefix.count))', helper)
        self.assertIn('fraction.separator', helper)
        self.assertIn('.accessibilityLabel(spoken)', helper)
        self.assertIn('Text("\\(done) / \\(total) XP · next: \\(Text(LocalizedStringKey(next)))")', helper)
        self.assertNotIn('.layoutDirection', helper)
        self.assertIn('arguments: [Int64(counts.0), Int64(counts.1), next]', helper)

    def test_fullwidth_native_controls_and_spoken_label_are_selected(self):
        native = (ROOT / 'ios/TimbreAppTests/PracticeXPProgressTests.swift').read_text()
        for token in ['testTraditionalChineseFullwidthFractionPreservesTranslationAndSpokenText',
                      '255／500 XP · 下一個：XP', 'pixels(view.spoken', 'XCTAssertEqual(spoken, expected',
                      '%lld／%lld XP %@ %lld', '%lld／%lld XP %@ %@', '%lld ∕ %lld XP %@',
                      '"zh-Hant"', 'Timbre.NSLocalizedString(PracticeXPProgress.key']:
            self.assertIn(token, native)

    def test_native_translation_lookup_uses_app_language_override(self):
        native = (ROOT / 'ios/TimbreAppTests/PracticeXPProgressTests.swift').read_text()
        # Foundation would ignore the app's selected language; an unqualified call
        # is ambiguous between Foundation and the app's same-signature shim.
        self.assertIn('TimbreLocalization.language = "zh-Hant"', native)
        self.assertIn('XCTAssertEqual(Timbre.NSLocalizedString(PracticeXPProgress.key, comment: ""), template)', native)
        self.assertNotIn('XCTAssertEqual(NSLocalizedString(PracticeXPProgress.key', native)
        self.assertNotIn('Foundation.NSLocalizedString(PracticeXPProgress.key', native)

    def test_native_oracle_uses_physical_offsets_and_old_negative_control(self):
        native = (ROOT / 'ios/TimbreAppTests/PracticeXPProgressTests.swift').read_text()
        for token in ['let template = "%lld / %lld XP · \\(word): %@"',
                      'CTLineGetOffsetForStringIndex', 'XCTAssertLessThan(first, second',
                      'XCTAssertGreaterThan', '٢٥٥ / ٥٠٠', '12345', 'XCTAttachment(image: image)']:
            self.assertIn(token, native)


if __name__ == '__main__':
    unittest.main()
