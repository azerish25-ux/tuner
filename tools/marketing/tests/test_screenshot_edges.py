"""Crop guard follows actual compositor geometry, not assumed off-canvas bleed."""
from pathlib import Path
import sys
import unittest
import hashlib
import json
from unittest.mock import patch
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots as shots


class ScreenshotEdgeTests(unittest.TestCase):
    def test_native_flip_end_clamp_checks_actual_crop_for_both_phone_roles(self):
        for role, size in [('iphone', (1206, 2622)), ('iphone-large', (1320, 2868))]:
            with self.subTest(role=role):
                image = Image.new('RGB', size)
                box, scale, top, bottom = shots._flip_geometry(image, size, .118)
                self.assertGreater(top, 0)
                self.assertEqual(box[3], size[1])
                self.assertEqual(top + int((box[3] - box[1]) * scale), bottom)
                with patch.dict(shots.FOCUS, {'fixture': {'y0': .118}}):
                    self.assertEqual(shots.top_row('flip', 'fixture', role, image), box[1])

    def test_flip_preserves_full_source_even_when_it_would_have_bled(self):
        image = Image.new('RGB', (1206, 2622))
        box, scale, top, _ = shots._flip_geometry(image, image.size, 0)
        self.assertGreaterEqual(top, round(64 * 1206 / 1320))
        with patch.dict(shots.FOCUS, {'fixture': {'y0': 0}}):
            self.assertEqual(shots.top_row('flip', 'fixture', 'iphone', image),
                             None)

    def test_grey_subtitle_is_not_missed_by_white_only_threshold(self):
        image = Image.new('RGB', (100, 100), (20, 18, 16))
        ImageDraw.Draw(image).rectangle((20, 48, 40, 52), fill=(150, 154, 160))
        self.assertEqual(shots.sliced(image, 50), 21)
        self.assertEqual(shots.sliced(image, 60), 0)

    def test_dark_neutral_background_does_not_count_as_text(self):
        self.assertEqual(shots.sliced(Image.new('RGB', (100, 100), (90, 90, 90)), 50), 0)

    def test_measured_native_roles_keep_independent_crop_fractions(self):
        self.assertEqual(shots.focus_for('11b-tune-strum', 'iphone')['y0'], .140)
        self.assertEqual(shots.focus_for('11b-tune-strum', 'iphone-large')['y0'], .128)
        self.assertEqual(shots.FOCUS['11b-tune-strum']['y0'], .118)

    def test_real_native_large_edges_reject_old_cut_and_accept_measured_gap(self):
        fixtures = Path(__file__).parent / 'fixtures/native-large-strum'
        evidence = json.loads((fixtures / 'evidence.json').read_text())
        self.assertEqual(evidence['native_size'], [1320, 2868])
        for fixture in evidence['captures']:
            path = fixtures / fixture['strip_file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), fixture['strip_sha256'])
            with Image.open(path) as strip:
                self.assertEqual(strip.size, (1320, 120))
                self.assertGreaterEqual(shots.sliced(strip, 338 - evidence['strip_top']), shots.SLICE_COLUMNS)
                # Use actual production role geometry, then evaluate retained native pixels at its edge.
                row = shots.top_row('flip', '11b-tune-strum', 'iphone-large', Image.new('RGB', (1320, 2868)))
                self.assertEqual(row, 367)
                self.assertEqual(shots.sliced(strip, row - evidence['strip_top']), 0)

    def test_strum_crop_is_below_measured_medium_toolbar(self):
        image = Image.new('RGB', (1206, 2622))
        row = shots.top_row('flip', '11b-tune-strum', 'iphone', image)
        self.assertGreaterEqual(row, 360)
        self.assertLess(row, 400)  # Native EN/DE instruction starts at row408.


if __name__ == '__main__':
    unittest.main()
