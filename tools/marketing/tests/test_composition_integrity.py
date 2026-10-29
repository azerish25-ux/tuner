"""Native-region pixel regressions plus direction-independent layout safety.

Fixtures are exact crops with source hashes, not fabricated UI. The rest of the
structural test canvas is synthetic; full native renders need separate review.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import art
import screenshots as shots


class RecordedFrame(shots.Frame):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.cards = []

    def card(self, picture, x, y, radius, **kwargs):
        self.cards.append((picture.copy(), x, y, radius, kwargs))
        return super().card(picture, x, y, radius, **kwargs)


class CompositionIntegrityTests(unittest.TestCase):
    def source(self, capture, fixture="native-arabic-composition"):
        root = Path(__file__).parent / "fixtures" / fixture
        evidence = json.loads((root / 'evidence.json').read_text())
        row = next(row for row in evidence['captures'] if row['capture'] == capture)
        crop = root / row['crop_file']
        self.assertEqual(hashlib.sha256(crop.read_bytes()).hexdigest(), row['crop_sha256'])
        source = Image.new('RGB', tuple(evidence['native_size']))
        with Image.open(crop) as region:
            self.assertEqual(region.size, (row['crop_box'][2] - row['crop_box'][0],
                                           row['crop_box'][3] - row['crop_box'][1]))
            source.paste(region, tuple(row['crop_box'][:2]))
        return source

    def compose(self, capture, source, locale, handler):
        before = hashlib.sha256(source.tobytes()).hexdigest()
        role = 'iphone-large' if source.size == (1320, 2868) else 'iphone'
        _, title, line, look = next(row for row in shots.plan(role, locale=locale) if row[0] == capture)
        with patch.object(shots, 'Frame', RecordedFrame), patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
            frame = handler(look.split()[0], look.split()[1], source,
                            shots.focus_for(capture, role), title, line, source.size)
        self.assertEqual(hashlib.sha256(source.tobytes()).hexdigest(), before)
        self.assertLessEqual(frame.caption_bounds[3], frame.h - frame.px(64))
        return frame

    def assert_native_region(self, frame, source, region, source_box=None, card_index=0):
        """Native protected pixels must equal one uniform resize, without overlays/fades."""
        picture, x, y, _, _ = frame.cards[card_index]
        box = source_box or (0, 0, source.width, source.height)
        expected = source.crop(box).resize(picture.size, Image.Resampling.LANCZOS)
        sx, sy = picture.width / (box[2] - box[0]), picture.height / (box[3] - box[1])
        mapped = (math.ceil((region[0] - box[0]) * sx), math.ceil((region[1] - box[1]) * sy),
                  math.floor((region[2] - box[0]) * sx), math.floor((region[3] - box[1]) * sy))
        actual_box = (mapped[0] + x, mapped[1] + y, mapped[2] + x, mapped[3] + y)
        self.assertGreaterEqual(actual_box[0], 0)
        self.assertGreaterEqual(actual_box[1], 0)
        self.assertLessEqual(actual_box[2], frame.w)
        self.assertLessEqual(actual_box[3], frame.h - frame.px(64))
        actual = frame.canvas.convert('RGB').crop(actual_box)
        self.assertIsNone(ImageChops.difference(actual, expected.crop(mapped)).getbbox())
        self.assertLess(abs(sx - sy), 1 / (box[2] - box[0]) + 1 / (box[3] - box[1]))

    def test_native_tuner_actions_and_pegs_have_no_feather_mask(self):
        source = self.source('10b-tune-locked')
        for locale in ('ar-SA', 'en-US'):
            with self.subTest(locale=locale):
                frame = self.compose('10b-tune-locked', source, locale, shots._breakout)
                self.assertEqual(len(frame.cards), 1)
                self.assert_native_region(frame, source, (35, 360, 1150, 1250))

    def test_native_bottom_navigation_and_result_actions_are_complete(self):
        for capture, handler, region in (
            ('50-learn', shots._offset, (60, 2380, 1140, 2565)),
            ('62-lesson-results', shots._zoom, (60, 2330, 1140, 2500)),
        ):
            source = self.source(capture)
            for locale in ('ar-SA', 'en-US'):
                with self.subTest(capture=capture, locale=locale):
                    frame = self.compose(capture, source, locale, handler)
                    picture, x, y, _, _ = frame.cards[0]
                    self.assertLessEqual(y + picture.height, frame.h - frame.px(64))
                    focus = shots.FOCUS[capture]
                    x0, x1 = focus.get('x', (0, 1))
                    box = tuple(round(v) for v in (x0 * source.width, focus['y0'] * source.height,
                                                  x1 * source.width, source.height))
                    self.assert_native_region(frame, source, region, box)

    def test_callout_cannot_cover_native_instruction_or_em_in_either_direction(self):
        source = self.source('52b-lesson-chord')
        frames = []
        for locale in ('ar-SA', 'en-US'):
            with self.subTest(locale=locale):
                frame = self.compose('52b-lesson-chord', source, locale, shots._callout)
                self.assertEqual(len(frame.cards), 2)
                self.assert_native_region(frame, source, (230, 380, 1000, 510))
                self.assert_native_region(frame, source, (430, 822, 760, 915))
                callout, cx, cy, _, options = frame.cards[1]
                main, x, top, _, _ = frame.cards[0]
                self.assertEqual(options['shadow'], 0)  # Shadows must not darken protected labels.
                detail_box, _ = shots._ticked_strings_region(source)
                self.assert_native_region(frame, source, (214, 566, 1042, 691), detail_box, card_index=1)
                # The real callout compositor must not opt its on-canvas bottom
                # corners out of the rounded mask (the original native defect).
                self.assertNotEqual(frame.canvas.getpixel((x + 2, top + main.height - 3))[:3], (0, 0, 0))
                self.assertNotEqual(frame.canvas.getpixel((x + main.width - 3, top + main.height - 3))[:3], (0, 0, 0))
                _, clearance = shots._ticked_strings_region(source)
                self.assertGreaterEqual(cy, top + clearance[0] * main.height / source.height + frame.px(11))
                self.assertLessEqual(cy + callout.height, top + clearance[1] * main.height / source.height - frame.px(11))
                self.assertLessEqual(cx + callout.width, frame.w - frame.px(48))
                self.assertGreaterEqual(cx, frame.px(48))
                frames.append(frame)
        # Caption heights may change the scale, but physical string order must not.
        box, _ = shots._ticked_strings_region(source)
        for frame in frames:
            picture = frame.cards[1][0]
            expected = source.crop(box).resize(picture.size, Image.Resampling.LANCZOS)
            self.assertEqual(picture.tobytes(), expected.tobytes())

    def test_large_native_callout_preserves_full_badges_em_and_selector(self):
        source = self.source('52b-lesson-chord', 'native-english-large-composition')
        box, clearance = shots._ticked_strings_region(source)
        self.assertEqual(box, (208, 544, 1181, 719))
        self.assertEqual(clearance, (510, 810))
        # The original height-fraction crop clipped badges and covered the selector.
        self.assertGreater(round(.208 * source.height), 567)
        self.assertGreater(round(.310 * source.height), 819)
        for locale in ('en-US', 'ar-SA'):
            with self.subTest(locale=locale):
                frame = self.compose('52b-lesson-chord', source, locale, shots._callout)
                self.assert_native_region(frame, source, (140, 360, 1190, 518))
                self.assert_native_region(frame, source, (140, 805, 1190, 942))
                # Includes every pixel of all six original note/checkmark shapes;
                # rounded corners, border, or RTL placement may not erase them.
                self.assert_native_region(frame, source, (231, 567, 1158, 696), box, card_index=1)
                picture = frame.cards[1][0]
                expected = source.crop(box).resize(picture.size, Image.Resampling.LANCZOS)
                self.assertEqual(picture.tobytes(), expected.tobytes())
                self.assertGreater(picture.width / (box[2] - box[0]), frame.cards[0][0].width / source.width)

    def test_native_callout_tracks_content_instead_of_screen_height(self):
        # Structural transformations of a native crop, not new native evidence.
        source = self.source('52b-lesson-chord', 'native-english-large-composition')
        box, clearance = shots._ticked_strings_region(source)
        shifted = Image.new('RGB', source.size)
        shifted.paste(source.crop((0, 350, source.width, 1100)), (0, 430))
        moved_box, moved_clearance = shots._ticked_strings_region(shifted)
        self.assertEqual(moved_box, (box[0], box[1] + 80, box[2], box[3] + 80))
        self.assertEqual(moved_clearance, tuple(y + 80 for y in clearance))

    def test_native_callout_fails_closed_when_shape_or_whitespace_is_missing(self):
        source = self.source('52b-lesson-chord', 'native-english-large-composition')
        for invalid in (Image.new('RGB', source.size), source.copy()):
            invalid.paste('black', (200, 540, 370, 720))
            with self.assertRaisesRegex(ValueError, 'six unambiguous'):
                shots._ticked_strings_region(invalid)
        source.paste('white', (50, 550, 120, 551))
        with self.assertRaisesRegex(ValueError, 'whitespace'):
            shots._ticked_strings_region(source)

    def test_visible_card_corners_match_the_rounded_rim(self):
        frame = shots.Frame((300, 600), 'mint')
        before = frame.canvas.copy()
        picture = Image.new('RGB', (200, 400), 'black')
        with patch.object(art, 'drop_shadow'):
            frame.card(picture, 50, 100, 30)
        for x, y in ((51, 101), (248, 101), (51, 498), (248, 498)):
            self.assertEqual(frame.canvas.getpixel((x, y)), before.getpixel((x, y)))
        self.assertEqual(frame.canvas.getpixel((150, 300))[:3], (0, 0, 0))

    def test_flip_uses_actual_glyph_ink_and_a_safe_footer_in_rtl_and_ltr(self):
        for locale in ('ar-SA', 'en-US'):
            for role, size in (('iphone', (1206, 2622)), ('iphone-large', (1320, 2868))):
                with self.subTest(locale=locale, role=role):
                    source = Image.new('RGB', size)
                    _, title, line, _ = next(row for row in shots.plan(role, locale=locale) if row[0] == '11b-tune-strum')
                    with patch.object(shots, 'Frame', RecordedFrame), patch.dict(os.environ, TIMBRE_CAPTION_LOCALE=locale):
                        frame = shots._flip('flip', 'mint', source, shots.focus_for('11b-tune-strum', role), title, line, size)
                        runs, advance, ink = frame.caption_plan(title, line, frame.px(84), frame.w - frame.px(84))
                        # Independently rasterize beyond the canvas, so clipped ink cannot hide from QA.
                        mask = Image.new('L', (size[0], size[1] + 500))
                        draw = ImageDraw.Draw(mask)
                        top = frame.caption_bounds[1] - ink[1]
                        for x, y, text, font, anchor, _ in runs:
                            draw.text((x, top + y), text, font=font, fill=255, anchor=anchor, **art.text_layout())
                        self.assertEqual(mask.getbbox(), frame.caption_bounds)
                        self.assertLessEqual(mask.getbbox()[3], size[1] - frame.px(64))
                        with self.assertRaisesRegex(ValueError, 'Caption ink'):
                            frame.caption(title, line, size[1] - ink[3] + 1, frame.px(84), frame.w - frame.px(84))
                    picture, x, y, _, _ = frame.cards[0]
                    self.assertGreaterEqual(y, frame.px(64))
                    self.assertNotEqual(frame.canvas.getpixel((x + 2, y + 2))[:3], (0, 0, 0))
                    self.assertNotEqual(frame.canvas.getpixel((x + picture.width - 3, y + 2))[:3], (0, 0, 0))
                    self.assertLess(y + picture.height, frame.caption_bounds[1])

    def test_fit_never_crops_or_stretches_native_screen(self):
        for size in ((1206, 2622), (1320, 2868)):
            source = Image.new('RGB', size)
            source.paste('red', (0, 0, 20, source.height))
            source.paste('blue', (source.width - 20, 0, source.width, source.height))
            source.paste('lime', (20, source.height - 20, source.width - 20, source.height))
            image, scale = shots._contained_screen(source, (0, 0, *size), 1000, 1800)
            self.assertEqual(image.getpixel((3, image.height // 2)), (255, 0, 0))
            self.assertEqual(image.getpixel((image.width - 4, image.height // 2)), (0, 0, 255))
            self.assertEqual(image.getpixel((image.width // 2, image.height - 4)), (0, 255, 0))
            self.assertLessEqual(image.height, 1800)
            self.assertLessEqual(image.width, 1000)
            self.assertEqual(image.size, (int(size[0] * scale), int(size[1] * scale)))


if __name__ == '__main__':
    unittest.main()
