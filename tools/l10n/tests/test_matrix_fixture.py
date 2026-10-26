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
        self.assertEqual(set(result['fa']), set(matrix_fixture.KEYS) | {'lesson_status'})
        self.assertEqual(result['fa']['lesson_status'], 'pending')

    def write_lessons(self, locale, entries):
        directory = self.root / f'{locale}.lproj'
        directory.mkdir(exist_ok=True)
        (directory / 'Learn.strings').write_text(''.join(
            f'{json.dumps(key)} = {json.dumps(value)};\n' for key, value in entries.items()), encoding='utf-8')

    def test_imported_lessons_enable_exact_expectations(self):
        self.write_table('de', {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        source = {key: 'Source text' for key in matrix_fixture.LESSON_KEYS.values()}
        self.write_lessons('en', source)
        self.write_lessons('de', {key: 'Übersetzter Text' for key in source})
        result = matrix_fixture.fixture(['de'])['de']
        self.assertEqual(result['lesson_status'], 'available')
        self.assertEqual(result['lesson_body'], 'Übersetzter Text')

    def test_partial_import_cannot_silently_skip_lessons(self):
        self.write_table('de', {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        self.write_lessons('en', {key: 'Source text' for key in matrix_fixture.LESSON_KEYS.values()})
        self.write_lessons('de', {})
        with self.assertRaisesRegex(ValueError, 'lesson_title'):
            matrix_fixture.fixture(['de'])

    def test_copied_english_lesson_is_not_a_pass(self):
        self.write_table('de', {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        source = {key: 'Source text' for key in matrix_fixture.LESSON_KEYS.values()}
        self.write_lessons('en', source)
        self.write_lessons('de', source)
        with self.assertRaisesRegex(ValueError, 'untranslated lesson'):
            matrix_fixture.fixture(['de'])

    def test_blank_lesson_or_source_is_rejected(self):
        source = {key: 'Source text' for key in matrix_fixture.LESSON_KEYS.values()}
        translated = {key: 'Übersetzter Text' for key in source}
        for locale in ('en', 'de'):
            self.write_table(locale, {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        for locale, blank_source in (('en', True), ('de', True), ('de', False)):
            with self.subTest(locale=locale, blank_source=blank_source):
                english, local = dict(source), dict(translated)
                (english if blank_source else local)[matrix_fixture.LESSON_KEYS['lesson_body']] = ' \t '
                self.write_lessons('en', english)
                self.write_lessons('de', local)
                with self.assertRaisesRegex(ValueError, 'lesson_body'):
                    matrix_fixture.fixture([locale])

    def test_execution_requires_lesson_marker_when_imported(self):
        expected = {'de': {'lesson_status': 'available'}}
        matrix_fixture.validate_log(expected, 'TIMBRE_L10N_MATRIX_TESTED de\nTIMBRE_L10N_LESSON_TESTED de\n')
        for log in ['', 'TIMBRE_L10N_MATRIX_TESTED de\n',
                    'TIMBRE_L10N_MATRIX_TESTED de\nTIMBRE_L10N_LESSON_PENDING de\n',
                    'TIMBRE_L10N_MATRIX_TESTED de\nTIMBRE_L10N_LESSON_TESTED de\nTIMBRE_L10N_LESSON_PENDING de\n']:
            with self.assertRaises(ValueError):
                matrix_fixture.validate_log(expected, log)

    def test_missing_lessons_are_explicitly_pending_not_tested(self):
        expected = {'bg': {'lesson_status': 'pending'}}
        matrix_fixture.validate_log(expected, 'TIMBRE_L10N_MATRIX_TESTED bg\nTIMBRE_L10N_LESSON_PENDING bg\n')
        with self.assertRaises(ValueError):
            matrix_fixture.validate_log(expected, 'TIMBRE_L10N_MATRIX_TESTED bg\nTIMBRE_L10N_LESSON_TESTED bg\n')
        with self.assertRaises(ValueError):
            matrix_fixture.validate_log({'bg': {'lesson_status': 'unknown'}}, '')

    def test_songs_uses_ui_without_translated_course(self):
        self.write_table('bg', {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        self.assertEqual(matrix_fixture.fixture(['bg'])['bg']['songs'], 'localized Songs')

    def test_songs_preserves_translated_course_title(self):
        self.write_table('it', {key: 'localized ' + key for key in matrix_fixture.KEYS.values()})
        source = {key: 'Source text' for key in matrix_fixture.LESSON_KEYS.values()}
        self.write_lessons('en', dict(source, Le1404b4267='Songs'))
        target = {key: 'testo tradotto' for key in source}
        self.write_lessons('it', dict(target, Le1404b4267='Canzoni'))
        self.assertEqual(matrix_fixture.fixture(['it'])['it']['songs'], 'Canzoni')
        self.write_lessons('it', dict(target, Le1404b4267='Songs'))
        self.assertEqual(matrix_fixture.fixture(['it'])['it']['songs'], 'localized Songs')

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
    def test_fixture_keys_are_the_real_first_guitar_explanation(self):
        curriculum = json.loads(matrix_fixture.report.CURRICULUM.read_text(encoding='utf-8'))
        matches = [lesson for course in curriculum['courses'] for unit in course['units']
                   for lesson in unit['lessons'] if lesson['id'] == 'gtr-1-1']
        self.assertEqual(len(matches), 1)
        lesson = matches[0]
        step = lesson['steps'][0]
        self.assertEqual(step['type'], 'explain')
        english = matrix_fixture.report.read_strings(matrix_fixture.report.RES / 'en.lproj/Learn.strings')
        for field, text in [('lesson_title', lesson['title']), ('lesson_heading', step['title']),
                            ('lesson_body', step['body'])]:
            self.assertEqual(matrix_fixture.LESSON_KEYS[field], text['k'])
            self.assertEqual(english[text['k']], text['t'])

    def test_only_explicit_matrix_requests_cancel_prior_run(self):
        workflow = (matrix_fixture.report.ROOT / '.github/workflows/localization-matrix.yml').read_text()
        condition = "github.event_name == 'workflow_dispatch' || contains(github.event.head_commit.message, '[l10n-matrix]')"
        self.assertIn('cancel-in-progress: ${{ ' + condition + ' }}', workflow)
        self.assertIn('if: ' + condition, workflow)

    def test_checked_in_workflow_covers_every_translated_locale(self):
        matrix_fixture.check_workflow(matrix_fixture.report.ROOT / '.github/workflows/localization-matrix.yml')

    def test_all_48_real_tables_generate_exact_expectations(self):
        result = matrix_fixture.fixture(list(matrix_fixture.report.LANGUAGE_NAMES))
        self.assertEqual(len(result), 48)
        self.assertTrue(all(set(matrix_fixture.KEYS).issubset(labels) for labels in result.values()))
        for locale, labels in result.items():
            available = (matrix_fixture.report.RES / f'{locale}.lproj/Learn.strings').is_file()
            self.assertEqual(labels['lesson_status'], 'available' if available else 'pending')
            self.assertEqual(set(labels) - set(matrix_fixture.KEYS) - {'lesson_status'},
                             set(matrix_fixture.LESSON_KEYS) if available else set())


if __name__ == '__main__':
    unittest.main()
