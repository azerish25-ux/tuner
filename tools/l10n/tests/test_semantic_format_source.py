import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import apply as ui_apply
import report
import gpt_l10n


class SemanticFormatSourceTests(unittest.TestCase):
    def test_actual_keyboard_target_accepts_placeholder(self):
        self.assertEqual(report.check('Localizable.strings', 'timbre_voice_keyboard_target',
                                     'Target %1$@', '目標 %1$@', 'zh-Hant'), [])

    def test_actual_hold_requirement_preserves_typed_arguments(self):
        key, source = 'timbre_voice_hold_requirement', '%1$@ s hold · ±%2$d cents'
        self.assertEqual(report.check('Localizable.strings', key, source,
                                     '保持 %1$@ 秒 · ±%2$d 音分', 'zh-Hant'), [])
        for bad in ['保持 秒', '保持 %1$d 秒 · ±%2$@ 音分', '保持 %@ 秒 · ±%2$d 音分']:
            self.assertTrue(report.check('Localizable.strings', key, source, bad, 'zh-Hant'))

    def test_unknown_semantic_key_fails_closed(self):
        self.assertTrue(report.check('Localizable.strings', 'timbre_unknown_123', 'Target %@', '目標 %@', 'zh-Hant'))
        self.assertIsNone(ui_apply.format_source('Localizable.strings', 'timbre_unknown_123'))

    def test_modified_source_cannot_waive_actual_placeholder(self):
        self.assertTrue(report.check('Localizable.strings', 'timbre_voice_keyboard_target',
                                     'Target', '目標', 'zh-Hant'))

    def test_literal_keys_remain_contract_even_if_source_is_modified(self):
        self.assertTrue(report.check('Localizable.strings', 'Target %@', 'Target', '目標', 'zh-Hant'))
        self.assertEqual(ui_apply.format_source('AppShortcuts.strings', '${command} in ${applicationName}'),
                         '${command} in ${applicationName}')

    def test_standalone_apply_uses_same_current_english_value(self):
        source = ui_apply.format_source('Localizable.strings', 'timbre_voice_hold_requirement')
        self.assertEqual(source, '%1$@ s hold · ±%2$d cents')
        self.assertEqual(ui_apply.specs(source), ['@', 'd'])

    def test_batch_helper_does_not_reject_semantic_identifiers(self):
        item = {'table': 'Localizable.strings', 'key': 'timbre_voice_keyboard_target', 'source': 'Target %1$@'}
        errors, _ = gpt_l10n.problems(item, '目標 %1$@', 'zh-Hant', report)
        self.assertEqual(errors, [])

    def test_lookup_unescapes_source_preserves_format(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); (root/'en.lproj').mkdir()
            (root/'en.lproj/Localizable.strings').write_text('"timbre_test" = "Say \\"hello\\"\\n%@";\n')
            self.assertEqual(ui_apply.format_source('Localizable.strings', 'timbre_test', root), 'Say "hello"\n%@')

if __name__ == '__main__':
    unittest.main()
