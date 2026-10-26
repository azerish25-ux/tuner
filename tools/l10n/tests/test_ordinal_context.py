"""Regressions for the exact finger/interval context repair."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / 'docs/l10n/ordinal-context'

def read(path):
    return json.loads(path.read_text())

def pointer(value, path):
    for key in path.strip('/').split('/'):
        value = value[int(key)] if isinstance(value, list) else value[key]
    return value

class OrdinalContextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.curriculum = read(ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json')

    def test_exact_finger_references_use_existing_explicit_keys(self):
        changes = read(EVIDENCE / 'source-object-changes.json')
        self.assertEqual(len(changes), 18)
        for change in changes:
            self.assertEqual(pointer(self.curriculum, change['pointer']), change['new'])
            self.assertTrue(change['new']['t'].endswith(' finger'))

    def test_retained_intervals_keep_reviewed_whole_context(self):
        after = read(EVIDENCE / 'after-contexts.json')
        for key, count in [('L2a4bcae654', 2), ('Lefb3a32162', 8), ('L7a3a4a4221', 5)]:
            self.assertEqual(len(after[key]), count)
            for item in after[key]:
                self.assertEqual(pointer(self.curriculum, item['pointer']), item['value'])
                step_path = item['pointer'].split('/options/')[0]
                self.assertEqual(pointer(self.curriculum, step_path), item['context'])

    def test_live_reviewed_interval_values(self):
        for item in read(EVIDENCE / 'independent-decisions.json'):
            if item['locale'] == 'pa':
                continue  # Punjabi conditional evidence is tested by its import gate.
            table = read(ROOT / 'tools/l10n/learn' / (item['locale'] + '.json'))
            self.assertEqual(table[item['key']], item['new'])
        for item in read(EVIDENCE / 'adjacent-independent-decisions.json'):
            table = read(ROOT / 'tools/l10n/learn' / (item['locale'] + '.json'))
            self.assertEqual(table[item['key']], item['suggested_new'])

    def test_public_evidence_hashes(self):
        for name, expected in read(EVIDENCE / 'artifact-manifest.json').items():
            self.assertEqual(hashlib.sha256((EVIDENCE / name).read_bytes()).hexdigest(), expected)

if __name__ == '__main__':
    unittest.main()
