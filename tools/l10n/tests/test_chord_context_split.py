"""Guard semantic chord/scale splits without granting translation approval."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import chord_context_split as split
import report


class ChordContextSplitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = split.read(split.DATA / 'manifest.json')
        cls.changes = split.read(split.DATA / 'changes.json')
        cls.curriculum = split.read(split.ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json')
        cls.english = report.read_strings(split.ROOT / 'ios/Timbre/Resources/en.lproj/Learn.strings')

    def validate(self, curriculum=None, english=None, changes=None):
        return split.validate_source(curriculum if curriculum is not None else self.curriculum,
                                     english if english is not None else self.english,
                                     self.manifest, changes if changes is not None else self.changes)

    def test_exact_source_migration_has_no_readiness_claim(self):
        self.validate()
        self.assertFalse(split.verify_source()['release_ready'])

    def test_all_previous_6083_sources_remain(self):
        self.assertEqual(len(self.english), 6090)
        self.assertEqual(len(set(self.english) - set(self.manifest['new_sources'])), 6083)

    def test_answer_change_is_rejected(self):
        changed = copy.deepcopy(self.curriculum)
        quiz = split.pointer(changed, '/courses/8/units/6/lessons/4/steps/6')
        quiz['answer'] = (quiz['answer'] + 1) % len(quiz['options'])
        with self.assertRaisesRegex(ValueError, 'curriculum content guard'):
            self.validate(curriculum=changed)

    def test_wrong_new_source_is_rejected(self):
        source = dict(self.english)
        source['Lbdeb73715c'] = 'B♭ major scale'
        with self.assertRaisesRegex(ValueError, 'English source guard'):
            self.validate(english=source)

    def test_duplicate_change_is_rejected(self):
        changes = copy.deepcopy(self.changes)
        changes[1] = changes[0]
        with self.assertRaisesRegex(ValueError, 'duplicate pointer guard'):
            self.validate(changes=changes)

    def test_wrong_old_context_is_rejected(self):
        changes = copy.deepcopy(self.changes)
        changes[0]['old']['t'] = 'Incorrect reconstructed source'
        with self.assertRaisesRegex(ValueError, 'nonlocalized content guard'):
            self.validate(changes=changes)

    def test_major_chord_does_not_change_theory_scale_title(self):
        chord = split.pointer(self.curriculum, '/courses/0/units/4/lessons/1/title')
        scale = split.pointer(self.curriculum, '/courses/8/units/4/lessons/2/title')
        self.assertEqual(chord['t'], 'G major chord')
        self.assertEqual(scale['t'], 'G major')
        self.assertNotEqual(chord['k'], scale['k'])

    def test_minor_scale_reuses_existing_key(self):
        title = split.pointer(self.curriculum, '/courses/3/units/4/lessons/2/title')
        self.assertEqual(title, {'k': 'Lc819139d43', 't': 'A minor scale'})
        self.assertNotIn(title['k'], self.manifest['new_sources'])

    def test_b_flat_chord_and_key_are_distinct(self):
        key = split.pointer(self.curriculum, '/courses/8/units/4/lessons/4/steps/2/options/1')
        chord = split.pointer(self.curriculum, '/courses/8/units/6/lessons/4/steps/6/options/0')
        self.assertEqual(key['t'], 'B♭ major')
        self.assertEqual(chord['t'], 'B♭ major chord')
        self.assertNotEqual(key['k'], chord['k'])

    def test_drafts_cannot_pass_as_independent_review(self):
        row = copy.deepcopy(split.read(split.DATA / 'pending-addendum.json')['items'][0])
        row['translation'] = 'A draft target'
        contexts = split.read(split.DATA / 'contexts.json')['after']
        baseline = {row['key']: row['before_target']} if row['before_target'] is not None else {}
        with self.assertRaisesRegex(ValueError, 'independent review missing'):
            split.validate_review(row, self.english, contexts, baseline, locale=row['locale'])

    def test_same_pointer_semantic_drift_is_rejected_by_review(self):
        row = copy.deepcopy(split.read(split.DATA / 'pending-addendum.json')['items'][0])
        row['translation'] = 'A draft target'
        contexts = split.read(split.DATA / 'contexts.json')['after']
        contexts[row['key']][0]['context']['answer'] = 'unrelated semantic edit'
        with self.assertRaisesRegex(ValueError, 'full context guard'):
            split.validate_review(row, self.english, contexts, {}, locale=row['locale'])

    def test_all_51_target_addenda_remain_pending(self):
        queue = split.read(split.DATA / 'pending-addendum.json')
        self.assertEqual(len(queue['items']), 816)
        for locale in queue['locales']:
            rows = [r for r in queue['items'] if r['locale'] == locale]
            self.assertEqual(len(rows), 16)
            self.assertEqual(sum(r['operation'] == 'add_if_absent' for r in rows), 7)
            self.assertTrue(all(r['translation'] is None and r['reviewed_by'] is None for r in rows))


if __name__ == '__main__':
    unittest.main()
