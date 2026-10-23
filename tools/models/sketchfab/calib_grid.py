#!/usr/bin/env python3
"""Draw a metric grid over the calibration renders so nut and saddle points can be read off.

python3 tools/models/sketchfab/calib_grid.py build/convert
Grid lines every centimetre on the head view (labelled every 5 cm), every 5 cm on the whole
view (labelled every 10 cm). Coordinates are the normalised frame: x right, z up, metres.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def grid(png: Path, view: dict, step: float, label_every: int, out: Path):
    im = Image.open(png).convert("RGB")
    d = ImageDraw.Draw(im, "RGBA")
    res, scale = view["res"], view["scale"]
    cx, _, cz = view["center"]
    to_px = lambda x: (x - cx) / scale * res + res / 2
    to_pz = lambda z: res / 2 - (z - cz) / scale * res
    small = font(13)
    k0 = int((cx - scale / 2) / step) - 1
    for k in range(k0, k0 + int(scale / step) + 3):
        x = k * step
        px = to_px(x)
        major = k % label_every == 0
        d.line([(px, 0), (px, res)], fill=(0, 255, 200, 150 if major else 55), width=1)
        if major:
            d.text((px + 2, 2), f"x{x * 100:+.0f}", font=small, fill=(0, 255, 200, 255))
    k0 = int((cz - scale / 2) / step) - 1
    for k in range(k0, k0 + int(scale / step) + 3):
        z = k * step
        pz = to_pz(z)
        major = k % label_every == 0
        d.line([(0, pz), (res, pz)], fill=(255, 200, 0, 150 if major else 55), width=1)
        if major:
            d.text((2, pz + 2), f"z{z * 100:.0f}", font=small, fill=(255, 200, 0, 255))
    im.save(out, quality=90)


def main():
    folder = Path(sys.argv[1])
    for calib_path in sorted(folder.glob("*.calib.json")):
        model = calib_path.name.replace(".calib.json", "")
        calib = json.loads(calib_path.read_text())
        if (folder / f"{model}_calib_whole.png").exists():
            grid(folder / f"{model}_calib_whole.png", calib["whole"], 0.05, 2, folder / f"{model}_whole_grid.jpg")
        if (folder / f"{model}_calib_head.png").exists():
            grid(folder / f"{model}_calib_head.png", calib["head"], 0.01, 5, folder / f"{model}_head_grid.jpg")
        ids = folder / f"{model}_calib_ids.png"
        if ids.exists():
            grid(ids, calib["head"], 0.01, 5, folder / f"{model}_ids_grid.jpg")
            shot = Image.open(folder / f"{model}_ids_grid.jpg")
            rows = calib.get("headObjects", [])[:80]
            panel = Image.new("RGB", (460, shot.height), (24, 24, 24))
            d = ImageDraw.Draw(panel)
            for k, m in enumerate(rows):
                y = 6 + k * 14
                d.rectangle([6, y, 20, y + 11], fill=tuple(int(c * 255) for c in m["color"]))
                d.text((26, y - 1), f"{m['name'][:40]} ({m['vertices']})", font=font(11), fill=(230, 230, 230))
            both = Image.new("RGB", (shot.width + panel.width, shot.height))
            both.paste(shot, (0, 0)); both.paste(panel, (shot.width, 0))
            both.save(folder / f"{model}_ids_key.jpg", quality=88)
            (folder / f"{model}_ids_grid.jpg").unlink()


if __name__ == "__main__":
    main()
