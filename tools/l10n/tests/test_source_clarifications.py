import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gpt_l10n

class SourceClarificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.path = self.root / 'tools/l10n/source-clarifications.json'
        self.curriculum = self.root / 'ios/Sources/TimbreCore/Resources/curriculum.json'
        self.path.parent.mkdir(parents=True)
        self.curriculum.parent.mkdir(parents=True)
        self.step = {'sound': [[64], [63]], 'prompt': {'k': 'Lkey', 't': 'A short bend'}}
        digest = hashlib.sha256(json.dumps(self.step, sort_keys=True, ensure_ascii=False,
                                         separators=(',', ':')).encode()).hexdigest()
        self.note = {'key': 'Lkey', 'source': 'A short bend',
                     'source_sha256': hashlib.sha256(b'A short bend').hexdigest(),
                     'clarification': 'Under target pitch, not short duration.',
                     'evidence': [{'pointer': '/step', 'sha256': digest}]}
        self.curriculum.write_text(json.dumps({'step': self.step}))

    def tearDown(self):
        self.temp.cleanup()

    def write(self, notes=None):
        self.path.write_text(json.dumps({'notes': notes if notes is not None else [self.note]}))

    def test_absent_notes_are_optional(self):
        self.assertEqual(gpt_l10n.source_clarifications(self.root), {})

    def test_exact_source_and_context_pass(self):
        self.write()
        self.assertEqual(gpt_l10n.source_clarifications(self.root)['Lkey'], self.note)

    def test_changed_audio_rejected_even_with_same_english(self):
        self.write()
        self.step['sound'][1][0] = 64
        self.curriculum.write_text(json.dumps({'step': self.step}))
        with self.assertRaisesRegex(ValueError, 'context drift'):
            gpt_l10n.source_clarifications(self.root)

    def test_changed_source_rejected(self):
        self.note['source'] = 'A long bend'
        self.write()
        with self.assertRaisesRegex(ValueError, 'hash drift'):
            gpt_l10n.source_clarifications(self.root)

    def test_missing_evidence_and_duplicates_rejected(self):
        self.write([self.note, self.note])
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            gpt_l10n.source_clarifications(self.root)
        self.note['evidence'] = []
        self.write()
        with self.assertRaisesRegex(ValueError, 'invalid'):
            gpt_l10n.source_clarifications(self.root)

    def test_real_curriculum_notes_are_bound(self):
        result = gpt_l10n.source_clarifications(Path(__file__).resolve().parents[3])
        self.assertEqual(len(result), 10)
        self.assertIn('target pitch', result['L38ebe33d09']['clarification'])
        self.assertIn('not held down', result['L342ffe164f']['clarification'])

if __name__ == '__main__':
    unittest.main()
