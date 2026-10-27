"""Geometry and pixel-order tests; synthetic bars are not native capture evidence."""
import hashlib
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots as shots
from test_landscape_rtl import Frame


class PortraitOffsetEdgesTests(unittest.TestCase):
    def render(self, locale, layout, size):
        source = Image.new('RGB', size, 'black')
        source.paste('red', (0, 0, 50, source.height))
        source.paste('blue', (source.width - 50, 0, source.width, source.height))
        before = hashlib.sha256(source.tobytes()).hexdigest()
        with patch.object(shots, 'Frame', Frame), patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
            frame = shots._offset(layout, 'cyan', source, {'y0': .06}, 'title', 'line', size)
        self.assertEqual(before, hashlib.sha256(source.tobytes()).hexdigest())
        self.assertEqual(frame.screen.getpixel((10, 10)), (255, 0, 0))
        self.assertEqual(frame.screen.getpixel((frame.screen.width - 10, 10)), (0, 0, 255))
        self.assertGreaterEqual(frame.x, frame.px(36))
        self.assertLessEqual(frame.x + frame.screen.width, frame.w - frame.px(36))
        self.assertEqual(frame.corners, (True, True, False, False))
        return frame

    def test_both_edges_retained_without_mirroring_in_all_directions(self):
        for size in ((1206, 2622), (1320, 2868)):
            for locale in ('en-US', 'ar-SA', 'fa', 'he', 'ur'):
                for layout in ('offset', 'offset-left'):
                    with self.subTest(size=size, locale=locale, layout=layout):
                        self.render(locale, layout, size)

    def test_rtl_reflects_placement_and_caption_not_pixels(self):
        size = (1206, 2622)
        ltr = self.render('en-US', 'offset', size)
        rtl = self.render('ar-SA', 'offset', size)
        self.assertEqual(ltr.x, ltr.w - rtl.x - rtl.screen.width)
        self.assertEqual((ltr.align, rtl.align), ('left', 'right'))
        self.assertEqual(ltr.screen.tobytes(), rtl.screen.tobytes())

    def test_old_offset_geometry_is_detectably_outside_canvas(self):
        for width in (1206, 1320):
            screen_width = int(width * .86)
            old_x = width - screen_width + round(70 * width / 1320)
            self.assertGreater(old_x + screen_width, width)

if __name__ == '__main__':
    unittest.main()
