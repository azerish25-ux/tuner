import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import apply as ui_apply
import gpt_l10n
import report


class FormatSlotsAndCardinalsTests(unittest.TestCase):
    def test_unsafe_positional_slots_fail_closed_in_both_parsers(self):
        for text in ['%9$@', '%0$@', '%1$@ %1$d', '%1$@ %3$d', '%@ %2$d']:
            with self.subTest(text=text):
                self.assertIsNone(ui_apply.specs(text))
                self.assertIsNone(gpt_l10n.spec_list(text))
                self.assertFalse(ui_apply.formats_match(text, text))

    def test_valid_reordering_preserves_types_tokens_and_escaped_percent(self):
        self.assertTrue(ui_apply.formats_match('%1$@ %2$lld %% ${applicationName}',
                                               '${applicationName} %2$lld %% %1$@'))
        self.assertTrue(ui_apply.formats_match('%@ %lld', '%2$lld %1$@'))
        self.assertFalse(ui_apply.formats_match('%@ %lld', '%2$@ %1$lld'))
        self.assertEqual(gpt_l10n.spec_list('%%@'), [])

    def test_repeated_references_preserve_index_type_and_multiplicity(self):
        self.assertTrue(ui_apply.formats_match('%1$@ then %1$@', '%1$@ / %1$@'))
        self.assertFalse(ui_apply.formats_match('%1$@ %1$@', '%1$@ %2$@'))
        self.assertFalse(ui_apply.formats_match('%1$@ %1$@', '%1$@'))
        self.assertFalse(ui_apply.formats_match('%1$@ %2$d', '%1$@ %1$d'))

    def test_semantic_import_and_batch_reject_out_of_bounds(self):
        item = dict(table='Localizable.strings', key='timbre_voice_keyboard_target', source='Target %1$@')
        self.assertTrue(report.check(**item, value='目標 %9$@', loc='zh-Hant'))
        self.assertTrue(gpt_l10n.problems(item, '目標 %9$@', 'zh-Hant', report)[0])

    def test_absent_new_resources_have_correct_cardinal_categories(self):
        with tempfile.TemporaryDirectory() as temp:
            for loc, expected in [('zh-Hant', ['other']), ('ms', ['other']), ('or', ['one', 'other'])]:
                self.assertEqual(gpt_l10n.plural_forms(Path(temp), loc), expected)

    def test_new_locale_cardinals_require_exact_categories(self):
        for loc in ['ms', 'zh-Hant']:
            self.assertEqual(report.check('Localizable.stringsdict', 'Every %lld bars', 'Every %lld bars',
                                           {'other': '%lld bars'}, loc), [])
            self.assertTrue(report.check('Localizable.stringsdict', 'Every %lld bars', 'Every %lld bars',
                                          {'one': 'bar', 'other': '%lld bars'}, loc))
        self.assertTrue(report.check('Localizable.stringsdict', 'Every %lld bars', 'Every %lld bars',
                                      {'other': '%lld bars'}, 'or'))
        self.assertEqual(report.check('Localizable.stringsdict', 'Every %lld bars', 'Every %lld bars',
                                       {'one': 'bar', 'other': '%lld bars'}, 'or'), [])

    def test_batch_helper_uses_plural_count_contract_not_english_other_signature(self):
        item = dict(table='Localizable.stringsdict', key='Every %lld bars', source='Every %lld bars')
        self.assertEqual(gpt_l10n.problems(item, {'one': 'bar', 'other': '%lld bars'}, 'or', report)[0], [])
        self.assertTrue(gpt_l10n.problems(item, {'one': 'bar', 'other': '%@ bars'}, 'or', report)[0])

    def test_cardinals_still_require_numeric_type_and_current_source(self):
        for forms in [{'other': '%@ bars'}, {'other': '%9$lld bars'}, {'other': 'bars'}]:
            self.assertTrue(report.check('Localizable.stringsdict', 'Every %lld bars', 'Every %lld bars', forms, 'ms'))
        self.assertTrue(report.check('Localizable.stringsdict', 'Every %lld bars', 'Changed %lld source',
                                      {'other': '%lld bars'}, 'ms'))

if __name__ == '__main__':
    unittest.main()
