import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/l10n'))
import report

class TremoloContextTests(unittest.TestCase):
    def test_long_note_answer_reuses_sustained_tremolo(self):
        doc = json.loads((ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json').read_text())
        lesson = doc['courses'][5]['units'][2]['lessons'][3]
        self.assertEqual(lesson['id'], 'man-3-4')
        quiz = lesson['steps'][4]
        self.assertEqual(quiz['answer'], 1)
        self.assertEqual(quiz['options'][1], {'k': 'Le56240b1d1', 't': 'Tremolo through long notes'})
        last = lesson['steps'][3]['notes'][-1]
        self.assertEqual((last['m'], last['b'], last['d']), (57, 12, 3))

    def test_obsolete_short_sustain_key_is_not_shipped(self):
        english = report.read_strings(report.RES / 'en.lproj/Learn.strings')
        self.assertNotIn('L4d1c8b1ea7', english)
        for path in report.RES.glob('*.lproj/Learn.strings'):
            self.assertNotIn('L4d1c8b1ea7', report.read_strings(path), str(path))

if __name__ == '__main__':
    unittest.main()
