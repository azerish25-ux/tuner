import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import matrix_fixture


class MatrixFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.resources = patch.object(matrix_fixture.report, 'RES', self.root)
        self.resources.start()

    def tearDown(self):
        self.resources.stop()
        self.temp.cleanup()

    def write_table(self, locale, entries):
        directory = self.root / f'{locale}.lproj'
        directory.mkdir()
        (directory / 'Localizable.strings').write_text(''.join(
            f'{json.dumps(key)} = {json.dumps(value)};\n' for key, value in entries.items()
        ), encoding='utf-8')

    def test_exact_unicode_and_newline_preserved(self):
        values = {key: 'ترجمهٔ ' + key for key in matrix_fixture.KEYS.values()}
        self.write_table('fa', values)
        result = matrix_fixture.fixture(['fa'])
        self.assertEqual(result['fa']['headline'], values[matrix_fixture.KEYS['headline']])
        self.assertIn('\n', result['fa']['headline'])
        self.assertEqual(len(result['fa']), 6)

    def test_unknown_locale_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unknown locale'):
            matrix_fixture.fixture(['missing'])

    def test_missing_label_rejected(self):
        self.write_table('de', {})
        with self.assertRaisesRegex(ValueError, 'headline'):
            matrix_fixture.fixture(['de'])

    def test_english_fallback_rejected(self):
        self.write_table('de', {key: key for key in matrix_fixture.KEYS.values()})
        with self.assertRaisesRegex(ValueError, 'untranslated'):
            matrix_fixture.fixture(['de'])

    def test_invalid_selection_rejected(self):
        for locales in ([], [''], ['fa', 'fa'], ['../fa'], ['fa/extra'], [' fa'], ['fa', '']):
            with self.subTest(locales=locales), self.assertRaises(ValueError):
                matrix_fixture.fixture(locales)

    def test_blank_label_rejected(self):
        values = {key: 'translated ' + key for key in matrix_fixture.KEYS.values()}
        values[matrix_fixture.KEYS['start']] = '  '
        self.write_table('de', values)
        with self.assertRaisesRegex(ValueError, 'start'):
            matrix_fixture.fixture(['de'])

    def test_workflow_missing_and_duplicate_locales_rejected(self):
        locales = list(matrix_fixture.report.LANGUAGE_NAMES)
        self.assertEqual(len(locales), 48)
        for locale in locales:
            (self.root / f'{locale}.lproj').mkdir()
        workflow = self.root / 'workflow.yml'
        for selection in (locales, locales[:-1], locales + [locales[0]], locales[:-1] + ['xx']):
            workflow.write_text("          - '" + ','.join(selection) + "'\n")
            if selection == locales:
                matrix_fixture.check_workflow(workflow)
            else:
                with self.assertRaises(ValueError):
                    matrix_fixture.check_workflow(workflow)

    def test_source_language_allowed(self):
        self.write_table('en', {key: key for key in matrix_fixture.KEYS.values()})
        self.assertEqual(matrix_fixture.fixture(['en'])['en']['start'], 'Get started')


class MatrixIntegrationTests(unittest.TestCase):
    def test_checked_in_workflow_covers_every_translated_locale(self):
        matrix_fixture.check_workflow(matrix_fixture.report.ROOT / '.github/workflows/localization-matrix.yml')

    def test_all_48_real_tables_generate_exact_expectations(self):
        result = matrix_fixture.fixture(list(matrix_fixture.report.LANGUAGE_NAMES))
        self.assertEqual(len(result), 48)
        self.assertTrue(all(set(labels) == set(matrix_fixture.KEYS) for labels in result.values()))


if __name__ == '__main__':
    unittest.main()
