import contextlib
import io
import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import report


class PluralImportTests(unittest.TestCase):
    key = 'Every %lld bars'
    source = 'Every %lld bars'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.resources = self.root / 'resources'
        self.here = self.root / 'l10n'
        self.incoming = self.root / 'incoming'
        for path in [self.here / 'translations', self.here / 'learn', self.incoming]:
            path.mkdir(parents=True)
        self.template = {'NSStringLocalizedFormatKey': '%#@n@', 'n': {
            'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType',
            'NSStringFormatValueTypeKey': 'lld', 'one': 'Every bar', 'other': self.source}}
        self.write_plist('en', {self.key: self.template})
        self.patches = [patch.object(report, 'RES', self.resources), patch.object(report, 'HERE', self.here),
                        patch.object(report.subprocess, 'run')]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def write_plist(self, locale, content):
        path = self.resources / f'{locale}.lproj/Localizable.stringsdict'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(content, sort_keys=False))
        return path

    def import_forms(self, forms, key=None):
        self.incoming.joinpath('de.json').write_text(json.dumps({'locale': 'de', 'strings': [{
            'table': 'Localizable.stringsdict', 'key': key or self.key,
            'source': self.source, 'translation': forms}]}), encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()) as output:
            report.import_todo(self.incoming)
        return output.getvalue()

    def test_numberless_one_uses_the_english_one_contract(self):
        self.assertEqual(report.check('Localizable.stringsdict', self.key, self.source,
                                      {'one': 'Jeden Takt', 'other': 'Alle %lld Takte'}, 'de'), [])

    def test_one_can_display_the_count_and_dual_can_spell_it_out(self):
        for forms in [{'one': 'Every %lld bar', 'other': 'Every %lld bars'},
                      {'zero': 'No bars', 'one': 'Every bar', 'two': 'Every two bars',
                       'other': 'Every %lld bars'}]:
            with self.subTest(forms=forms):
                self.assertEqual(report.check('Localizable.stringsdict', self.key, self.source, forms, 'de'), [])

    def test_invalid_forms_and_argument_types_are_rejected(self):
        for forms in [{'one': 'Jeden Takt'}, {'one': '', 'other': 'Alle %lld Takte'},
                      {'other': 3}, {'other': 'Alle %@ Takte'}, {'other': 'Alle Takte'},
                      {'other': 'Alle %lld Takte', 'singular': 'Takt'},
                      {'one': 'Every %@ bar', 'other': 'Every %lld bars'},
                      {'one': 'Every %lld %lld bar', 'other': 'Every %lld bars'}]:
            with self.subTest(forms=forms):
                self.assertTrue(report.check('Localizable.stringsdict', self.key, self.source, forms, 'de'))

    def test_unknown_printf_conversions_and_unavailable_argument_positions_are_rejected(self):
        for text in ['Every %lld bars %s', 'Every %lld bars %n', 'Every %2$lld bars',
                     'Every %0$lld bars', 'Every %lld bars %']:
            with self.subTest(text=text):
                self.assertTrue(report.check('Localizable.stringsdict', self.key, self.source,
                                             {'other': text}, 'de'))
        self.assertEqual(report.check('Localizable.stringsdict', self.key, self.source,
                                      {'other': 'Every %1$lld bars (100%%)'}, 'de'), [])

    def test_import_writes_real_plist_and_preserves_unrelated_entries(self):
        self.write_plist('de', {'Unrelated': {'keep': 'unchanged'}})
        output = self.import_forms({'one': 'Jeden Takt', 'other': 'Alle %lld Takte'})
        actual = report.read_stringsdict(self.resources / 'de.lproj/Localizable.stringsdict')
        self.assertIn(self.key, actual)
        self.assertEqual(actual['Unrelated'], {'keep': 'unchanged'})
        self.assertEqual(actual[self.key]['NSStringLocalizedFormatKey'], '%#@n@')
        self.assertEqual(actual[self.key]['n']['NSStringFormatValueTypeKey'], 'lld')
        self.assertEqual(actual[self.key]['n']['one'], 'Jeden Takt')
        self.assertEqual(actual[self.key]['n']['other'], 'Alle %lld Takte')
        self.assertIn('imported 1 translations, rejected 0', output)

    def test_rejected_plural_leaves_existing_file_bytes_unchanged(self):
        path = self.write_plist('de', {self.key: self.template})
        original = path.read_bytes()
        self.import_forms({'other': 'Alle %@ Takte'})
        self.assertEqual(path.read_bytes(), original)

    def test_unknown_key_cannot_create_an_unbound_plural(self):
        output = self.import_forms({'other': 'Alle %lld Takte'}, key='Unknown %lld')
        self.assertFalse((self.resources / 'de.lproj/Localizable.stringsdict').exists())
        self.assertIn('rejected 1', output)

    def test_reimport_replaces_old_categories_with_complete_delivery(self):
        old = dict(self.template)
        old['n'] = dict(self.template['n'], few='Old %lld')
        self.write_plist('de', {self.key: old})
        self.import_forms({'one': 'Jeden Takt', 'other': 'Alle %lld Takte'})
        actual = report.read_stringsdict(self.resources / 'de.lproj/Localizable.stringsdict')
        self.assertNotIn('few', actual[self.key]['n'])


class BundledPluralCompatibilityTests(unittest.TestCase):
    def test_every_existing_plural_retains_its_valid_locale_number_contract(self):
        english = report.read_stringsdict(report.RES / 'en.lproj/Localizable.stringsdict')
        checked = 0
        for path in sorted(report.RES.glob('*.lproj/Localizable.stringsdict')):
            locale = path.parent.name[:-6]
            for key, entry in report.read_stringsdict(path).items():
                if key not in english:
                    continue
                for name, rule in entry.items():
                    if not isinstance(rule, dict) or rule.get('NSStringFormatSpecTypeKey') != 'NSStringPluralRuleType':
                        continue
                    forms = {form: value for form, value in rule.items() if form in report.PLURAL_FORMS}
                    with self.subTest(locale=locale, key=key, variable=name):
                        self.assertEqual(report.check('Localizable.stringsdict', key,
                                         report.plural_source(english[key]), forms, locale), [])
                    checked += 1
        self.assertGreater(checked, 300)


if __name__ == '__main__':
    unittest.main()
