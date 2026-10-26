import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gpt_l10n

class SharedOptionContextsTests(unittest.TestCase):
    def test_missing_curriculum_is_empty(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(gpt_l10n.option_contexts(Path(folder)), {})

    def test_distinct_physical_and_pitch_prompts_are_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / 'ios/Sources/TimbreCore/Resources/curriculum.json'
            path.parent.mkdir(parents=True)
            def lesson(ident, prompt, why=''):
                return {'id': ident, 'steps': [{'prompt': {'t': prompt}, 'why': {'t': why},
                    'options': [{'k': 'Lup', 't': 'Up'}, {'k': 'Ldown', 't': 'Down'}]}]}
            lessons = [lesson('a', 'Did the tune go up or down?'),
                       lesson('b', 'Which stroke lands on the beat?', 'Down on the beat.'),
                       lesson('c', 'Did the tune go up or down?'),
                       lesson('d', 'Did the tune go up or down?')]
            path.write_text(json.dumps({'courses': [{'units': [{'lessons': lessons}]}]}))
            result = gpt_l10n.option_contexts(root)
            self.assertEqual(set(result), {'Lup', 'Ldown'})
            self.assertEqual(len(result['Lup']), 2)
            self.assertEqual(result['Lup'][0]['occurrences'], 3)
            self.assertEqual(result['Lup'][0]['example_lessons'], ['a', 'c'])
            self.assertEqual(result['Lup'][1]['explanation'], 'Down on the beat.')

    def test_real_direction_keys_include_all_41_uses(self):
        root = Path(__file__).resolve().parents[3]
        result = gpt_l10n.option_contexts(root)
        for key in ['L2038bdec92', 'Lbf93e5ce8b']:
            rows = result[key]
            self.assertEqual(sum(row['occurrences'] for row in rows), 41)
            self.assertTrue(any('stroke' in row['prompt'] for row in rows))
            self.assertTrue(any('note' in row['prompt'] for row in rows))
        self.assertEqual(sum(row['occurrences'] for row in result['L5b3ab40010']), 8)

if __name__ == '__main__':
    unittest.main()
