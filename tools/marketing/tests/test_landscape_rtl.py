"""Coordinate-only contracts; synthetic markers are not native capture evidence."""
import hashlib
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots as shots


class Frame:
    def __init__(self, size, accent, **kwargs):
        self.w, self.h = size
        self.glow = kwargs['glow']
    def px(self, n):
        return round(n * min(self.w, self.h) / 1320)
    def caption(self, *args, **kwargs):
        self.align = kwargs['align']
        return 300
    def card(self, screen, x, top, radius, **kwargs):
        self.screen, self.x, self.corners = screen, x, kwargs['corners']
    def save(self, out):
        return self


class LandscapeRTLTests(unittest.TestCase):
    def render(self, locale, layout):
        image = Image.new('RGB', (2752, 2064), 'black')
        image.paste('red', (0, 0, 100, 2064))
        image.paste('blue', (2652, 0, 2752, 2064))
        original = hashlib.sha256(image.tobytes()).hexdigest()
        with patch.object(shots, 'Frame', Frame), patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
            frame = shots._landscape(layout, 'cyan', image, 'title', 'line', image.size, Path('unused'))
        self.assertEqual(original, hashlib.sha256(image.tobytes()).hexdigest())
        self.assertEqual(frame.screen.getpixel((10, 10)), (255, 0, 0))
        self.assertEqual(frame.screen.getpixel((frame.screen.width - 10, 10)), (0, 0, 255))
        return frame

    def test_all_rtl_leading_edges_visible_and_bias_alternates(self):
        for locale in ('ar-SA', 'fa', 'he', 'ur'):
            a, b = self.render(locale, 'side'), self.render(locale, 'side-right')
            self.assertLess(a.x, 0)
            self.assertGreater(b.x, 0)
            for frame in (a, b):
                self.assertLessEqual(frame.x + frame.screen.width, frame.w)
            self.assertEqual((a.align, b.align), ('right', 'left'))
            self.assertEqual((a.glow[0], b.glow[0]), (.75, .25))

    def test_ltr_original_geometry_and_pixels(self):
        a, b = self.render('en-US', 'side'), self.render('en-US', 'side-right')
        self.assertEqual((a.x, b.x), (511, -125))
        self.assertEqual((a.align, b.align), ('left', 'right'))

    def test_center_layout_identical(self):
        a, b = self.render('en-US', 'light'), self.render('ar-SA', 'light')
        self.assertEqual((a.x, a.align, a.glow, a.corners), (b.x, b.align, b.glow, b.corners))
        self.assertEqual(a.screen.tobytes(), b.screen.tobytes())

if __name__ == '__main__':
    unittest.main()
