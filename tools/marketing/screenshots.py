#!/usr/bin/env python3
"""App Store screenshots from the CI screenshot tour.

python3 tools/marketing/screenshots.py <ci screenshots folder> <out folder> [--ipad]
Reads the xcresult attachment manifest written by the iOS workflow, picks the tour
captures named below, and lays each one on a "Still Point" stage with a headline.
iPhone output is 1320x2868 (6.9-inch); --ipad output is 2064x2752 (13-inch).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "ios/Timbre/Resources/Fonts"
INK, SOFT, BRASS, STAGE = (245, 239, 230), (179, 169, 158), (217, 178, 111), (14, 12, 11)

PHONE = [
    ("11-tune-string-selected", "Tune until it\nstands still.", "Live 3D pegs turn with your pitch"),
    ("30-instruments", "Sixty instruments.\nOne stage.", "Guitar, bass, ukulele, violin family, mandolin and more"),
    ("15-tune-chromatic", "Strobe precision\nfor any note.", "Voice, piano, winds — anything you play"),
    ("20-practice-hub", "Ten minutes\na day.", "A daily set built around your instrument"),
    ("23-ear-training", "Hear the\ndifference.", "Pitch, intervals and chord training"),
    ("32-journey", "Watch yourself\nimprove.", "Streaks, accuracy and milestones, on device"),
    ("22-metronome-running", "Keep perfect\ntime.", "Accents, odd meters, tap tempo and speed trainer"),
]
PAD = [
    ("ipad-landscape-tune", "Tune until it stands still.", "Live 3D pegs turn with your pitch"),
    ("ipad-portrait-tune", "A precision tuner for sixty instruments.", "With the practice that keeps you in tune"),
    ("ipad-landscape-instruments", "Every instrument has its own mechanism.", "Pegs, machines and strings in real time"),
    ("ipad-landscape-practice", "Ten minutes a day.", "Ear training, chords, scales, drone and voice"),
]


def attachments(folder: Path) -> dict:
    found = {}
    for test in json.loads((folder / "manifest.json").read_text()):
        for item in test["attachments"]:
            found[item["suggestedHumanReadableName"].split("_0_")[0]] = folder / item["exportedFileName"]
    return found


def stage(size) -> Image.Image:
    w, h = size
    base = Image.new("RGB", size, STAGE)
    glow = Image.new("L", size, 0)
    draw = ImageDraw.Draw(glow)
    draw.ellipse([w * 0.05, h * 0.18, w * 0.95, h * 0.78], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.18))
    warm = Image.new("RGB", size, (64, 44, 24))
    return Image.composite(warm, base, glow)


def rounded(shot: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius=radius, fill=255)
    out = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    out.paste(shot, (0, 0), mask)
    return out


def compose(shot_path: Path, title: str, subtitle: str, size, out: Path, portrait=True):
    w, h = size
    canvas = stage(size).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    display = ImageFont.truetype(str(FONTS / "InstrumentSerif-Regular.ttf"), int(w * (0.098 if portrait else 0.05)))
    small = ImageFont.truetype(str(FONTS / "ibm_plex_mono.ttf"), int(w * (0.026 if portrait else 0.014)))
    eyebrow = ImageFont.truetype(str(FONTS / "ibm_plex_mono.ttf"), int(w * (0.022 if portrait else 0.012)))
    top = int(h * 0.055)
    draw.text((w / 2, top), "T I M B R E", font=eyebrow, fill=BRASS, anchor="ma")
    y = top + int(h * 0.035)
    for line in title.split("\n"):
        draw.text((w / 2, y), line, font=display, fill=INK, anchor="ma")
        y += int(display.size * 1.02)
    draw.text((w / 2, y + int(h * 0.012)), subtitle, font=small, fill=SOFT, anchor="ma")
    y += int(h * 0.05)

    shot = Image.open(shot_path).convert("RGB")
    target_w = int(w * (0.8 if portrait else 0.84))
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    framed = rounded(shot, int(target_w * (0.11 if portrait else 0.03)))
    shadow = Image.new("RGBA", (framed.width + 160, framed.height + 160), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([80, 100, framed.width + 80, framed.height + 80], radius=int(target_w * 0.1), fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    x = (w - framed.width) // 2
    canvas.alpha_composite(shadow, (x - 80, y - 80))
    canvas.alpha_composite(framed, (x, y))
    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle([x, y, x + framed.width - 1, y + framed.height - 1], radius=int(target_w * (0.11 if portrait else 0.03)),
                             outline=(70, 60, 50), width=3)
    canvas.convert("RGB").save(out, quality=95)


def main():
    folder, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    ipad = "--ipad" in sys.argv
    found = attachments(folder)
    plan, size = (PAD, (2064, 2752)) if ipad else (PHONE, (1320, 2868))
    for number, (name, title, subtitle) in enumerate(plan, 1):
        if name not in found:
            print("missing", name)
            continue
        target = out / f"{'ipad' if ipad else 'iphone'}-{number:02d}.jpg"
        compose(found[name], title, subtitle, size, target, portrait=not ipad)
        print("wrote", target)


if __name__ == "__main__":
    main()
