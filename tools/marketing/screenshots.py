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
INK, SOFT, MINT, AMBER, STAGE = (245, 243, 239), (163, 168, 177), (76, 242, 184), (255, 181, 71), (6, 7, 8)

PHONE = [
    ("10b-tune-locked", "Strobe-precise tuning\nfor 60 instruments", "No ads. Guitar, bass and ukulele free forever."),
    ("60-along-playing", "Lessons that listen\nand tell you what to fix", "Cents and timing feedback on every note"),
    ("50-learn", "400+ lessons\nin 12 courses", "Guitar, ukulele, bass, violin, cello, mandolin, banjo and more"),
    ("62-lesson-results", "Five minutes a day,\nevery day", "Stars, streaks, levels and daily quests"),
    ("52b-lesson-chord", "It hears your chords", "Strum it and Timbre checks every string"),
    ("30-instruments", "Every instrument\non its own stage", "Real 3D instruments and photographs that move as you tune"),
    ("32-journey", "Watch yourself\nimprove", "Accuracy, string health and achievements, on device"),
]
PAD = [
    ("ipad-landscape-tune", "Strobe-precise tuning for 60 instruments.", "No ads. Guitar, bass and ukulele free forever."),
    ("ipad-portrait-tune", "Tune until it stands still.", "Real instruments that turn their pegs as you play"),
    ("ipad-landscape-instruments", "Every instrument on its own stage.", "Pegs, machines and strings in real time"),
    ("ipad-landscape-practice", "Five minutes a day.", "Lessons, ear games and practice tools"),
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
    warm = Image.new("RGB", size, (40, 30, 20))
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
    display = ImageFont.truetype(str(FONTS / "Sora-SemiBold.ttf"), int(w * (0.074 if portrait else 0.04)))
    small = ImageFont.truetype(str(FONTS / "Sora-Medium.ttf"), int(w * (0.03 if portrait else 0.016)))
    eyebrow = ImageFont.truetype(str(FONTS / "Sora-SemiBold.ttf"), int(w * (0.024 if portrait else 0.013)))
    top = int(h * 0.055)
    draw.text((w / 2, top), "T I M B R E", font=eyebrow, fill=AMBER, anchor="ma")
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
                             outline=(46, 50, 58), width=3)
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
