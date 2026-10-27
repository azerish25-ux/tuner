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
                self.assertTrue(content[KEY].startswith('%lld / %lld'), path.name)
                self.assertEqual(content[KEY].count('%@'), 1, path.name)
                self.assertEqual(content[KEY].count('%lld'), 2, path.name)
        self.assertEqual(found, 48)
        # English is the unchanged source key: 48 translated locales plus source = 49.
        self.assertTrue(KEY.startswith("%lld / %lld"))
        self.assertEqual(found + 1, 49)

    def test_both_call_sites_share_helper_without_direction_override(self):
        source = (ROOT / 'ios/Timbre/Practice/PracticeView.swift').read_text()
        self.assertEqual(source.count('PracticeXPProgress(done: xp - level.floor,'), 2)
        helper = (ROOT / 'ios/Timbre/Practice/PracticeXPProgress.swift').read_text()
        self.assertIn('guard template.hasPrefix(prefix) else { return nil }', helper)
        self.assertIn('.accessibilityLabel(spoken)', helper)
        self.assertIn('Text("\\(done) / \\(total) XP · next: \\(Text(LocalizedStringKey(next)))")', helper)
        self.assertNotIn('.layoutDirection', helper)
        self.assertIn('arguments: [Int64(counts.0), Int64(counts.1), next]', helper)

    def test_native_oracle_uses_physical_offsets_and_old_negative_control(self):
        native = (ROOT / 'ios/TimbreAppTests/PracticeXPProgressTests.swift').read_text()
        for token in ['let template = "%lld / %lld XP · \\(word): %@"',
                      'CTLineGetOffsetForStringIndex', 'XCTAssertLessThan(first, second',
                      'XCTAssertGreaterThan', '٢٥٥ / ٥٠٠', '12345', 'XCTAttachment(image: image)']:
            self.assertIn(token, native)


if __name__ == '__main__':
    unittest.main()
