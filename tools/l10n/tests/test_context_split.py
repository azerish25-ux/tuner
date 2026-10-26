"""The context migration must fail closed, including same-pointer semantic edits."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import context_split as migration


class ContextSplitGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = migration.read(migration.DATA / 'checked-manifest.json')
        cls.recorded = migration.read(migration.DATA / 'checked-contexts.json')
        cls.row = next(r for r in cls.manifest['rows']
                       if r['locale'] == 'ar' and r['operation'] == 'replace_if_exact')
        cls.add = next(r for r in cls.manifest['rows']
                       if r['locale'] == 'ar' and r['operation'] == 'add_if_absent')

    def setUp(self):
        self.row = copy.deepcopy(self.__class__.row)
        self.before = copy.deepcopy(self.recorded['before'])
        self.after = copy.deepcopy(self.recorded['after'])
        self.baseline = {self.row['key']: self.row['old']}
        self.source = {r['key']: r['source'] for r in self.manifest['rows']}

    def validate(self):
        migration.validate_row(self.row, self.baseline, self.before, self.after, self.source, locale=self.row['locale'])

    def test_reviewed_row_passes(self):
        self.validate()

    def test_wrong_locale_rejected(self):
        with self.assertRaisesRegex(ValueError, 'locale guard'):
            migration.validate_row(self.row, self.baseline, self.before, self.after,
                                   self.source, locale='gu')

    def test_wrong_table_rejected(self):
        self.row['table'] = 'Localizable.strings'
        with self.assertRaisesRegex(ValueError, 'table guard'):
            self.validate()

    def test_wrong_source_rejected(self):
        self.source[self.row['key']] += '!'
        with self.assertRaisesRegex(ValueError, 'source guard'):
            self.validate()

    def test_wrong_old_value_rejected(self):
        self.baseline[self.row['key']] += '!'
        with self.assertRaisesRegex(ValueError, 'old value guard'):
            self.validate()

    def test_wrong_target_hash_rejected(self):
        self.row['new'] += '!'
        with self.assertRaisesRegex(ValueError, 'new value hash guard'):
            self.validate()

    def test_same_pointer_wrong_answer_rejected(self):
        self.after[self.row['key']][0]['context']['answer'] = 0
        with self.assertRaisesRegex(ValueError, 'after full context guard'):
            self.validate()

    def test_same_pointer_wrong_pattern_rejected(self):
        self.after[self.row['key']][0]['context']['visual']['pattern'][1] = 1.5
        with self.assertRaisesRegex(ValueError, 'after full context guard'):
            self.validate()

    def test_premigration_shared_context_rejected(self):
        self.after = self.before
        with self.assertRaisesRegex(ValueError, 'after full context guard'):
            self.validate()

    def test_wrong_before_context_rejected(self):
        self.before[self.row['key']].pop()
        with self.assertRaisesRegex(ValueError, 'before full context guard'):
            self.validate()

    def test_preexisting_addition_rejected(self):
        self.row = copy.deepcopy(self.add)
        self.baseline[self.row['key']] = 'unexpected'
        with self.assertRaisesRegex(ValueError, 'absence guard'):
            self.validate()

    def test_missing_absence_guard_rejected(self):
        self.row = copy.deepcopy(self.add)
        self.row['absence_guard'] = False
        with self.assertRaisesRegex(ValueError, 'absence guard'):
            self.validate()

    def test_wrong_pointer_list_rejected(self):
        self.row['context_pointers'] = []
        with self.assertRaisesRegex(ValueError, 'after exact pointer guard'):
            self.validate()

    def test_wrong_context_count_rejected(self):
        self.row['required_after_context_count'] += 1
        with self.assertRaisesRegex(ValueError, 'after context count guard'):
            self.validate()

    def test_unrelated_nonlocalized_change_rejected(self):
        with self.assertRaisesRegex(ValueError, 'nonlocalized value changed'):
            migration.localized_diff({'answer': 2}, {'answer': 1})

    def test_live_source_contexts_and_applied_delta(self):
        import report
        root = migration.ROOT
        curriculum = migration.read(root / 'ios/Sources/TimbreCore/Resources/curriculum.json')
        actual_contexts = migration.contexts(curriculum)
        self.assertEqual(actual_contexts, self.recorded['after'])
        source = report.read_strings(root / 'ios/Timbre/Resources/en.lproj/Learn.strings')
        for locale in self.manifest['locales']:
            current = migration.read(root / f'tools/l10n/learn/{locale}.json')
            rows = [r for r in self.manifest['rows'] if r['locale'] == locale]
            baseline = dict(current)
            for row in rows:
                self.assertEqual(current[row['key']], row['new'])
                if row['operation'] == 'add_if_absent':
                    del baseline[row['key']]
                else:
                    baseline[row['key']] = row['old']
            for row in rows:
                migration.validate_row(row, baseline, self.recorded['before'], actual_contexts,
                                       source, locale=locale)

    def test_gujarati_neutralization_is_mutually_exclusive(self):
        supplement = migration.read(migration.DATA / 'addendum.json')
        row = next(r for r in self.manifest['rows']
                   if r['locale'] == 'gu' and r['key'] == 'Lced02810fc')
        baseline = {row['key']: 'મધ્યમા'}
        migration.validate_row(row, baseline, self.before, self.after, self.source, locale='gu')
        with self.assertRaisesRegex(ValueError, 'old value guard'):
            migration.validate_row(supplement['conditional_gujarati_restoration'], baseline,
                                   self.before, self.after, self.source, locale='gu')
        baseline[row['key']] = 'મધ્ય'
        with self.assertRaisesRegex(ValueError, 'old value guard'):
            migration.validate_row(row, baseline, self.before, self.after, self.source, locale='gu')
        migration.validate_row(supplement['conditional_gujarati_restoration'], baseline,
                               self.before, self.after, self.source, locale='gu')


if __name__ == '__main__':
    unittest.main()
