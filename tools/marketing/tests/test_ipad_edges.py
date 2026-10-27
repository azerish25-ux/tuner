"""Native landscape content stays inside the canvas; only a verified status strip is removed."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots as shots

class IPadEdgesTests(unittest.TestCase):
    def test_side_cards_retain_both_native_edges_and_mirror_placement(self):
        for light in (False, True):
            width = int(2752 * (.80 if light else .86))
            inset = int(2752 / 1760 * 80)
            left = shots._landscape_x(2752, width, inset, light=light, left=True)
            right = shots._landscape_x(2752, width, inset, light=light, left=False)
            for x in (left, right):
                self.assertGreaterEqual(x, inset)
                self.assertLessEqual(x + width, 2752 - inset)
            self.assertLessEqual(abs(left + right + width - 2752), 1)

    def test_actual_twelve_native_status_boundaries_are_clear(self):
        root = Path(__file__).parent / 'fixtures/native-ipad-status'
        evidence = json.loads((root / 'evidence.json').read_text())
        self.assertEqual(evidence['native_size'], [2752, 2064])
        self.assertEqual(len(evidence['captures']), 12)
        self.assertEqual({r['locale'] for r in evidence['captures']}, {'en-US', 'de-DE', 'ar-SA'})
        for row in evidence['captures']:
            path = root / row['strip_file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['strip_sha256'])
            with Image.open(path) as strip:
                self.assertEqual(strip.size, (2752, 35))
                for look in ('side mint', 'side-right sky', 'light'):
                    cut = shots.top_row(look, row['capture'], 'ipad', Image.new('RGB',(2752,2064)))
                    self.assertEqual(cut, 60)
                    self.assertEqual(shots.sliced(strip, cut - evidence['strip_top']), 0)

if __name__ == '__main__':
    unittest.main()
