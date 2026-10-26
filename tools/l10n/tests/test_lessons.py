import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lessons
import gpt_l10n
import report
import shipping


class LessonScopeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.resources = patch.object(report, 'RES', self.root)
        self.resources.start()
        self.table('en', {'L1': 'Play 2 notes.'})
        (self.root / 'fa.lproj').mkdir()

    def tearDown(self):
        self.resources.stop()
        self.temp.cleanup()

    def table(self, locale, entries):
        directory = self.root / f'{locale}.lproj'
        directory.mkdir(exist_ok=True)
        (directory / 'Learn.strings').write_text(''.join(
            f'{json.dumps(key)} = {json.dumps(value, ensure_ascii=False)};\n'
            for key, value in entries.items()), encoding='utf-8')

    def test_missing_files_still_require_lessons(self):
        self.assertEqual(report.lesson_locales(), ['fa'])
        row = lessons.audit()['fa']
        self.assertEqual(row['required'], 1)
        self.assertEqual(row['complete'], 0)
        self.assertEqual(row['missing'], ['L1'])

    def test_report_queues_missing_or_english_copied_lessons(self):
        item = {'table': report.LEARN, 'key': 'L1', 'source': 'Play 2 notes.'}
        with patch.object(report, 'ui_english', return_value=({}, [], set())), \
                patch.object(report, 'learn_english', return_value={'L1': item}), \
                patch.object(report, 'learn_history', return_value={}):
            for copied in (False, True):
                with self.subTest(copied=copied):
                    if copied:
                        self.table('fa', {'L1': 'Play 2 notes.'})
                    model = report.build()
                    self.assertEqual(model['lesson_locales'], ['fa'])
                    self.assertEqual([i['key'] for i in model['locales']['fa']['todo']], ['L1'])

    def test_english_copy_is_not_complete(self):
        self.table('fa', {'L1': 'Play 2 notes.'})
        self.assertEqual(lessons.audit()['fa']['complete'], 0)
        self.assertIn('L1', lessons.audit()['fa']['rejected'])

    def test_empty_and_invalid_translations_are_incomplete(self):
        for value in ['', 'دو نت بنوازید.', '  Play 2 notes.  ']:
            with self.subTest(value=value):
                self.table('fa', {'L1': value})
                self.assertEqual(lessons.audit()['fa']['complete'], 0)

    def test_valid_applied_translation_is_covered(self):
        self.table('fa', {'L1': '2 نت بنوازید.'})
        self.assertEqual(lessons.audit()['fa']['complete'], 1)

    def test_identity_requires_source_bound_locale_key_review(self):
        self.table('fa', {'L1': 'Play 2 notes.'})
        approved = {'fa': {'L1': {'source': 'Play 2 notes.', 'reason': 'fixture only',
                                  'reviewed_by': 'unit-test fixture'}}}
        with patch.object(report, 'lesson_invariants', return_value=approved):
            self.assertEqual(lessons.audit()['fa']['complete'], 1)
            self.assertFalse(report.reviewed_lesson_identity('de', 'L1', 'Play 2 notes.'))
            self.assertFalse(report.reviewed_lesson_identity('fa', 'L1', 'Play 3 notes.'))
            del approved['fa']['L1']['reviewed_by']
            self.assertEqual(lessons.audit()['fa']['complete'], 0)

    def test_no_sources_fail_closed(self):
        self.table('en', {})
        with self.assertRaises(ValueError):
            lessons.audit()

    def test_unapplied_delivery_is_not_shipping_coverage(self):
        model = {'ui_total': 1, 'learn_total': 1, 'lesson_locales': ['fa'],
                 'locales': {'fa': {'todo': [], 'awaiting_apply': [
                     {'table': 'Learn.strings', 'key': 'L1'},
                     {'table': 'Localizable.strings', 'key': 'Hi'}]}}}
        result = shipping.coverage(model)['fa']
        self.assertEqual(result['lessons'], 0)
        self.assertEqual(result['ui'], 0)

    def test_prompt_supports_new_locale_without_lesson_map(self):
        batch = self.root / 'batch.json'
        batch.write_text(json.dumps({'kind': 'lessons', 'language': 'Persian', 'items': []}))
        glossary = self.root / 'glossary.md'
        glossary.write_text('Fixture glossary')
        gpt_l10n.prompt(self.root, 'fa', batch, glossary)
        self.assertIn('(none yet)', batch.with_suffix('.prompt.txt').read_text())
        self.assertFalse((self.root / 'tools/l10n/learn/fa.json').exists())

    def test_repository_requires_all_48_targets(self):
        with patch.object(report, 'RES', report.ROOT / 'ios/Timbre/Resources'):
            self.assertEqual(len(report.lesson_locales()), 48)
            self.assertEqual(report.lesson_locales(), report.locales())


if __name__ == '__main__':
    unittest.main()
