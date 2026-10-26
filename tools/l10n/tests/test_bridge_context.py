import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / 'docs/l10n/bridge-context'
sys.path.insert(0, str(ROOT / 'tools/l10n'))
import report

def read(path):
    return json.loads(path.read_text())

def pointer(value, path):
    for key in path.strip('/').split('/'):
        value = value[int(key)] if isinstance(value, list) else value[key]
    return value

class BridgeContextTests(unittest.TestCase):
    def test_exact_two_physical_titles_are_remapped(self):
        doc = read(ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json')
        rows = read(DATA / 'generated-localized-diff.json')
        self.assertEqual(len(rows), 2)
        for row in rows:
            self.assertEqual(pointer(doc, row['pointer']), row['new'])
            self.assertEqual(row['new']['k'], 'Lc9e2d70b52')
        found = []
        def walk(value):
            if isinstance(value, dict):
                if value.get('k') in {'L690a93e955', 'Lc9e2d70b52'}:
                    found.append(value['k'])
                for item in value.values():
                    walk(item)
            elif isinstance(value, list):
                for item in value:
                    walk(item)
        walk(doc)
        self.assertEqual(found.count('L690a93e955'), 3)
        self.assertEqual(found.count('Lc9e2d70b52'), 2)

    def test_all_original_live_decisions_are_applied(self):
        english = report.read_strings(report.RES / 'en.lproj/Learn.strings')
        rows = read(DATA / 'independent-live-review.json')['rows']
        self.assertEqual(len(rows), 40)
        for row in rows:
            self.assertEqual(english[row['key']], row['source'])
            table = read(ROOT / 'tools/l10n/learn' / (row['locale'] + '.json'))
            self.assertEqual(table[row['key']], row['new'])

    def test_public_evidence_hashes(self):
        for name, digest in read(DATA / 'artifact-manifest.json')['files'].items():
            self.assertEqual(hashlib.sha256((DATA / name).read_bytes()).hexdigest(), digest)

if __name__ == '__main__':
    unittest.main()
