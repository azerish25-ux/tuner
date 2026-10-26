import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gpt_l10n

class SharedLessonContextsTests(unittest.TestCase):
    def test_missing_curriculum_is_empty(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(gpt_l10n.shared_lesson_contexts(Path(folder)), {})

    def test_physical_and_song_titles_are_distinct_but_duplicates_count_once(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path = root / 'ios/Sources/TimbreCore/Resources/curriculum.json'
            path.parent.mkdir(parents=True)
            word = {'k': 'Lbridge', 't': 'The bridge'}
            along = {'type': 'along', 'title': word, 'notes': [{'m': 60, 'y': 'lyrics'}]}
            physical = {'type': 'explain', 'title': word,
                        'body': {'k': 'Lbody', 't': 'The wooden arch holding strings.'}}
            quiz = {'type': 'quiz', 'prompt': {'k': 'Lprompt', 't': 'Which song section?'},
                    'options': [word], 'answer': 0}
            path.write_text(json.dumps({'courses': [{'units': [{'lessons': [
                {'steps': [along, along, physical, physical, quiz]}]}]}]}))
            result = gpt_l10n.shared_lesson_contexts(root)
            self.assertEqual(len(result['Lbridge']), 3)
            self.assertEqual(sum(x['occurrences'] for x in result['Lbridge']), 5)
            self.assertNotIn('Lbody', result)
            self.assertNotIn('lyrics', json.dumps(result))
            self.assertEqual({x['role'] for x in result['Lbridge']},
                             {'steps:along', 'steps:explain', 'steps:quiz'})
            self.assertTrue(any('body' in x['text'] for x in result['Lbridge']))

    def test_real_shared_directions_keep_physical_prompt_context(self):
        result = gpt_l10n.shared_lesson_contexts(Path(__file__).resolve().parents[3])
        rows = result['L2038bdec92']
        self.assertEqual(sum(x['occurrences'] for x in rows), 41)
        self.assertTrue(any('stroke' in str(x['text']) for x in rows))
        self.assertTrue(any('note' in str(x['text']) for x in rows))

if __name__ == '__main__':
    unittest.main()
