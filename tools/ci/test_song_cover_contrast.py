#!/usr/bin/env python3
"""Scoped source/compositing regression; not a substitute for native cover captures.

Run: python3 tools/ci/test_song_cover_contrast.py
Add --screenshots DIR to verify the original screenshot receipt with Pillow.
Add --source FILE to test a historical SongCover.swift without changing the checkout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
RECEIPT = json.loads((ROOT / "docs/ios/accessibility/c5-song-cover-contrast.json").read_text())
SOURCE_PATH = ROOT / "ios/Timbre/Songs/SongCover.swift"
THEME = (ROOT / "ios/Timbre/Design/Theme.swift").read_text()


def palette(name: str) -> tuple[int, int, int]:
    match = re.search(rf"static let {name} = Color\(hex: 0x([0-9A-Fa-f]{{6}})\)", THEME)
    if match is None:
        raise AssertionError(f"Missing concrete palette token: {name}")
    return tuple(bytes.fromhex(match[1]))


def luminance(rgb: tuple[float, ...] | list[int]) -> float:
    def linear(value: float) -> float:
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
    return sum(weight * linear(channel) for weight, channel in zip((0.2126, 0.7152, 0.0722), rgb))


def contrast(a: tuple[float, ...] | list[int], b: tuple[float, ...] | list[int]) -> float:
    low, high = sorted((luminance(a), luminance(b)))
    return (high + 0.05) / (low + 0.05)


def white_overlay(rgb: tuple[int, ...], opacity: float) -> tuple[float, ...]:
    return tuple(channel * (1 - opacity) + 255 * opacity for channel in rgb)


def top_light_maxima(source: str) -> tuple[float, float]:
    match = re.search(r"white\.opacity\(art\.field \? ([0-9.]+) : ([0-9.]+)\)", source)
    if match is None:
        raise AssertionError("Re-measure the cover: its top-light composition changed")
    return float(match[1]), float(match[2])


class SongCoverContrastTests(unittest.TestCase):
    def test_catalogue_number_retains_full_role_ink(self):
        source = SOURCE_PATH.read_text()
        catalogue = source.split("private func catalogue(", 1)[1].split("switch art.imprint", 1)[0]
        self.assertIn("art.field ? Palette.stage : Palette.ink", catalogue)
        self.assertRegex(catalogue, r"\.foregroundStyle\(ink\)")
        self.assertNotRegex(catalogue, r"ink\.opacity\(")

    def test_original_visible_number_is_a_real_contrast_failure(self):
        core, background, brightest = [sample["rgb"] for sample in RECEIPT["samples"][:3]]
        self.assertAlmostEqual(contrast(core, background), 3.1008981076, places=8)
        # Even the entire recorded frame's darkest/brightest pair is below 4.5.
        self.assertLess(contrast(core, brightest), 4.5)

    def test_light_field_ink_with_the_complete_top_light_range(self):
        maximum, _ = top_light_maxima(SOURCE_PATH.read_text())
        background = RECEIPT["samples"][1]["rgb"]
        ratios = [contrast(white_overlay(palette("stage"), maximum * step / 100), background)
                  for step in range(101)]
        self.assertGreaterEqual(min(ratios), 4.5, f"Light field minimum: {min(ratios):.3f}:1")

    def test_dark_sleeve_ink_with_the_complete_top_light_range(self):
        _, maximum = top_light_maxima(SOURCE_PATH.read_text())
        for sample in RECEIPT["samples"][3:]:
            with self.subTest(sample=sample["name"]):
                ratios = [contrast(white_overlay(palette("ink"), maximum * step / 100), sample["rgb"])
                          for step in range(101)]
                self.assertGreaterEqual(min(ratios), 4.5, f"Dark sleeve minimum: {min(ratios):.3f}:1")


def verify_original_screenshot(directory: Path) -> None:
    from PIL import Image

    path = directory / RECEIPT["image"]
    if hashlib.sha256(path.read_bytes()).hexdigest() != RECEIPT["image_sha256"]:
        raise AssertionError("Not the recorded c5 screenshot")
    image = Image.open(path)
    if list(image.size) != RECEIPT["image_size_px"] or image.info.get("srgb") != 0:
        raise AssertionError("Unexpected screenshot geometry or colour-space metadata")
    for sample in RECEIPT["samples"]:
        if list(image.getpixel(tuple(sample["xy_px"]))) != sample["rgb"]:
            raise AssertionError(f"Pixel receipt mismatch: {sample['name']}")
    print(f"Verified original PNG SHA-256 and {len(RECEIPT['samples'])} exact sRGB pixel samples.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--source", type=Path)
    args, remaining = parser.parse_known_args()
    if args.source:
        SOURCE_PATH = args.source
    if args.screenshots:
        verify_original_screenshot(args.screenshots)
    unittest.main(argv=[__file__, *remaining])
