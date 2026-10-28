"""Native landscape content stays inside the canvas; only a verified status strip is removed."""
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from PIL import Image, ImageChops
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots as shots
from test_composition_integrity import RecordedFrame

class IPadEdgesTests(unittest.TestCase):
    def test_side_cards_retain_both_native_edges_and_centre_placement(self):
        for light in (False, True):
            width = int(2752 * (.80 if light else .86))
            inset = int(2752 / 1760 * 80)
            left = shots._landscape_x(2752, width, inset, light=light, left=True)
            right = shots._landscape_x(2752, width, inset, light=light, left=False)
            for x in (left, right):
                self.assertGreaterEqual(x, inset)
                self.assertLessEqual(x + width, 2752 - inset)
            self.assertEqual(left, right)
            self.assertEqual(left, (2752 - width) // 2)

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

    def test_real_native_lower_controls_and_top_right_done_are_unchanged(self):
        root = Path(__file__).parent / 'fixtures/native-ipad-composition'
        evidence = json.loads((root / 'evidence.json').read_text())
        for row in evidence['captures']:
            path = root / row['crop_file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['crop_sha256'])
            source = Image.new('RGB', tuple(evidence['native_size']))
            with Image.open(path) as crop:
                source.paste(crop, tuple(row['crop_box'][:2]))
            original = hashlib.sha256(source.tobytes()).hexdigest()
            for locale in (row['locale'], 'ar-SA'):
                with self.subTest(native=row['locale'], caption=locale, capture=row['capture']):
                    _, title, line, look = next(r for r in shots.plan('ipad', locale=locale)
                                                if r[0] == row['capture'])
                    with patch.object(shots, 'Frame', RecordedFrame), patch.object(RecordedFrame, 'save', lambda self, out: self), \
                            patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
                        frame = shots._landscape(*look.split(), source, title, line, source.size, Path('unused'))
                    self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(), original)
                    picture, x, y, radius, _ = frame.cards[0]
                    self.assertLessEqual(y + picture.height, frame.h - frame.px(64))
                    self.assertLess(frame.caption_bounds[3], y)
                    expected = source.crop((0, shots.LANDSCAPE_STATUS_ROWS, *source.size)).resize(picture.size, Image.Resampling.LANCZOS)
                    self.assertEqual(picture.tobytes(), expected.tobytes())
                    sx, sy = picture.width / source.width, picture.height / (source.height - shots.LANDSCAPE_STATUS_ROWS)
                    self.assertLess(abs(sx - sy), .001)
                    # Keep the entire actual Done pill and tuner footer controls,
                    # not just their text; decorative corner masks must not cut them.
                    protected = ((2584, 64, 2733, 153) if row['capture'].endswith('instruments')
                                 else (190, 1895, 950, 2020))
                    mapped = (math.ceil(protected[0] * sx), math.ceil((protected[1] - 60) * sy),
                              math.floor(protected[2] * sx), math.floor((protected[3] - 60) * sy))
                    actual = frame.canvas.convert('RGB').crop((mapped[0] + x, mapped[1] + y,
                                                               mapped[2] + x, mapped[3] + y))
                    self.assertIsNone(ImageChops.difference(actual, expected.crop(mapped)).getbbox())

    def test_portrait_tablet_zoom_and_light_keep_complete_lower_native_edge(self):
        # Structural portrait/RTL coverage only; not a fabricated native iPad run.
        size = (2064, 2752)
        source = Image.new('RGB', size)
        source.paste('lime', (300, size[1] - 30, size[0] - 300, size[1]))
        for locale in ('en-US', 'de-DE', 'ar-SA'):
            for handler in (shots._zoom, shots._light):
                with self.subTest(locale=locale, layout=handler.__name__):
                    _, title, line, _ = shots.plan('ipad', locale=locale)[0]
                    with patch.object(shots, 'Frame', RecordedFrame), patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
                        frame = handler('light' if handler == shots._light else 'zoom', 'mint', source,
                                        {}, title, line, size)
                    picture, x, y, _, _ = frame.cards[0]
                    self.assertLessEqual(y + picture.height, size[1] - frame.px(64))
                    self.assertLess(frame.caption_bounds[3], y)
                    expected = source.resize(picture.size, Image.Resampling.LANCZOS)
                    self.assertEqual(picture.tobytes(), expected.tobytes())
                    self.assertEqual(frame.canvas.getpixel((x + picture.width // 2, y + picture.height - 10))[:3], (0, 255, 0))

if __name__ == '__main__':
    unittest.main()
