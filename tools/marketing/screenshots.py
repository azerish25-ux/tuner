#!/usr/bin/env python3
"""App Store screenshots from the CI screenshot tour.

python3 tools/marketing/screenshots.py <ci screenshots folder> <out folder> [--ipad]
python3 tools/marketing/screenshots.py --check

The captions live in one place only: the "### iPhone" and "### iPad" tables under "## Screenshots" in
docs/ios/APP-STORE-LISTING.md. This script reads them, so the listing and the images can't disagree.
Before rendering (and with --check, instead of rendering) it checks the tables: at most 10 frames a device
(App Store Connect's limit), a caption of at most 30 characters, a capture the UI tests really take, and every count a caption or supporting line quotes
(lessons, courses, instruments, tunings) equal to the build's own (curriculum.json, catalog.json).

Each store frame must come from exactly one capture in the UI tests, and that capture must be deterministic:
TimbreUITests keeps a frame under its own name only when it checked that the screen shows what the caption
says (`storeFrame`); otherwise the test fails and keeps the picture as "<name>-wrong". The tuner's lock (#1),
Kite Weather on the highway mid-chorus (#2, `65-song-perform`, from test14StoreSongPerform), "Show me" playing
E minor on the 3D guitar (#3, `51b-lesson-showme`, from test15StoreShowMe: kept only when the stage's probe says
the model is showing and the picture fell inside the chord's ring on the demonstration's own clock) and the chord
(#4) come from store scenes (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift), Strum to tune (iPhone #8,
`11b-tune-strum`, from test13StoreStrum) from the demo pitch's one fixed strum (StrumDemo), and the results (#7)
from a play-along the demo pitch plays clean, kept only with three stars and with Share and the level bar clear of
the fade over the buttons; none from an unchecked timed shot. On iPad the
instrument browser (#2) is a full page of its own, never a sheet over the live tuner. Every capture starts from the same seeded player (DemoData in ios/Timbre/TimbreApp.swift: the same
streak, lit flame, level and XP on every frame) and is taken once its screen has settled (`stillScreenshot`,
ios/TimbreUITests/StillScreen.swift).

Rendering reads the xcresult attachment manifest written by the iOS workflow, picks the captures the
table names and lays each one on a "Still Point" stage under its caption. A capture is turned upright from
its EXIF orientation first (XCUIScreen stores a landscape iPad capture as a portrait bitmap tagged
orientation 8), and the frame takes the capture's orientation: iPhone output is 1320x2868 (6.9-inch;
2868x1320 in landscape), --ipad output is 2064x2752 (13-inch portrait) or 2752x2064 (landscape). Every
written frame is read back and checked against those sizes. It renders what it can, then exits non-zero
if any frame is missing, was flagged wrong by its test, was captured more than once, or came out at a size
App Store Connect would refuse.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "ios/Timbre/Resources/Fonts"
LISTING = ROOT / "docs/ios/APP-STORE-LISTING.md"
CURRICULUM = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
CATALOG = ROOT / "ios/Sources/TimbreCore/Resources/catalog.json"
UI_TESTS = ROOT / "ios/TimbreUITests"
CAPTION_LIMIT = 30
# App Store Connect takes at most 10 screenshots per device size.
FRAME_LIMIT = 10
INK, SOFT, MINT, AMBER, STAGE = (245, 243, 239), (163, 168, 177), (76, 242, 184), (255, 181, 71), (6, 7, 8)
COUNT = re.compile(r"(\d[\d,]*)(\+?)\s+(lessons|courses|instruments|tunings)\b", re.IGNORECASE)
# App Store Connect's sizes for the 6.9-inch iPhone and the 13-inch iPad, portrait (width, height); landscape swaps them.
SIZES = {"iphone": (1320, 2868), "ipad": (2064, 2752)}


def plan(device: str) -> list:
    """(capture, caption, supporting line) for each row of the listing's table under '### <device>'."""
    rows, section, table = [], False, False
    for line in LISTING.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section, table = line.startswith("## Screenshots"), False
        elif section and line.startswith("### "):
            table = line[4:].strip().lower().startswith(device)
        elif section and table and line.startswith("|"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) < 4 or not cells[0].isdigit():
                continue  # the header and the divider
            capture = re.search(r"`([^`]+)`", cells[3])
            caption = cells[1].replace("**", "").strip()
            rows.append((capture.group(1) if capture else "", caption, cells[2]))
    return rows


def build_counts() -> dict:
    courses = json.loads(CURRICULUM.read_text(encoding="utf-8"))["courses"]
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    return {
        "lessons": sum(len(unit.get("lessons", [])) for course in courses for unit in course.get("units", [])),
        "courses": len(courses),
        "instruments": len(catalog["instruments"]),
        "tunings": len(catalog["tunings"]),
    }


def problems(device: str, rows: list, counts: dict) -> list:
    found = []
    if not rows:
        return [f"{device}: no screenshot table under '## Screenshots' / '### {device}' in {LISTING.name}"]
    if len(rows) > FRAME_LIMIT:
        found.append(f"{device}: {len(rows)} frames; App Store Connect takes at most {FRAME_LIMIT}")
    tests = "\n".join(path.read_text(encoding="utf-8") for path in sorted(UI_TESTS.glob("*.swift")))
    for number, (capture, caption, line) in enumerate(rows, 1):
        where = f"{device} #{number}"
        taken = tests.count(f'"{capture}"') if capture else 0
        if not capture:
            found.append(f"{where}: the Capture column names no capture (`name`)")
        elif not taken:
            found.append(f"{where}: no UI test takes a capture named {capture}")
        elif taken > 1:
            found.append(f"{where}: {capture} is named in {taken} places in the UI tests; a store frame comes from one capture")
        if len(caption) > CAPTION_LIMIT:
            found.append(f"{where}: “{caption}” is {len(caption)} characters (at most {CAPTION_LIMIT})")
        for text in (caption, line):
            for amount, plus, noun in COUNT.findall(text):
                actual = counts[noun.lower()]
                if plus or int(amount.replace(",", "")) != actual:
                    found.append(f"{where}: “{text}” says {amount}{plus} {noun}; the build has {actual}")
    return found


def attachments(folder: Path) -> dict:
    """Capture name -> every exported file attached under that name (more than one means it was taken twice)."""
    found = {}
    for test in json.loads((folder / "manifest.json").read_text()):
        for item in test["attachments"]:
            name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(\.\w+)?$", "", item["suggestedHumanReadableName"]).split("_0_")[0]
            found.setdefault(name, []).append(folder / item["exportedFileName"])
    return found


def stage(size):
    from PIL import Image, ImageDraw, ImageFilter
    w, h = size
    base = Image.new("RGB", size, STAGE)
    glow = Image.new("L", size, 0)
    draw = ImageDraw.Draw(glow)
    draw.ellipse([w * 0.05, h * 0.18, w * 0.95, h * 0.78], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.18))
    warm = Image.new("RGB", size, (40, 30, 20))
    return Image.composite(warm, base, glow)


def rounded(shot, radius: int):
    from PIL import Image, ImageDraw
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius=radius, fill=255)
    out = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    out.paste(shot, (0, 0), mask)
    return out


def wrap(text: str, font, width: float) -> list:
    """One line when it fits; otherwise the two-line break whose longer line is shortest."""
    if font.getlength(text) <= width:
        return [text]
    words = text.split()
    splits = [[" ".join(words[:i]), " ".join(words[i:])] for i in range(1, len(words))]
    return min(splits, key=lambda lines: max(font.getlength(line) for line in lines)) if splits else [text]


def upright(shot_path: Path):
    """The capture as it appears on screen: its EXIF orientation applied (a landscape iPad capture is stored as a
    portrait bitmap tagged orientation 8, which would otherwise be laid on the frame on its side)."""
    from PIL import Image, ImageOps
    with Image.open(shot_path) as image:
        return ImageOps.exif_transpose(image).convert("RGB")


def frame_size(device: str, shot) -> tuple:
    """The store size for this device in the capture's orientation."""
    w, h = SIZES[device]
    return (h, w) if shot.width > shot.height else (w, h)


def compose(shot_path: Path, title: str, subtitle: str, device: str, out: Path) -> tuple:
    """Lays the capture under its caption on a frame of the device's store size, in the capture's orientation;
    returns the frame's size."""
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    shot = upright(shot_path)
    size = frame_size(device, shot)
    w, h = size
    phone = device == "iphone"
    # Type scales with the frame's short side, so a landscape iPad frame sets its caption as the portrait one does.
    base = min(w, h)
    canvas = stage(size).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    display = ImageFont.truetype(str(FONTS / "Sora-SemiBold.ttf"), int(base * (0.074 if phone else 0.04)))
    small = ImageFont.truetype(str(FONTS / "Sora-Medium.ttf"), int(base * (0.03 if phone else 0.016)))
    eyebrow = ImageFont.truetype(str(FONTS / "Sora-SemiBold.ttf"), int(base * (0.024 if phone else 0.013)))
    top = int(h * 0.055)
    line_height = int(display.size * 1.02)
    draw.text((w / 2, top), "T I M B R E", font=eyebrow, fill=AMBER, anchor="ma")
    # Room for two title lines on every image, so the screenshots sit at one height across the set;
    # a one-line caption centres in that room.
    lines = wrap(title, display, w * 0.88)[:2]
    y = top + int(h * 0.035) + (2 - len(lines)) * line_height // 2
    for line in lines:
        draw.text((w / 2, y), line, font=display, fill=INK, anchor="ma")
        y += line_height
    draw.text((w / 2, y + int(h * 0.012)), subtitle, font=small, fill=SOFT, anchor="ma")
    shot_top = top + int(h * 0.035) + 2 * line_height + int(h * 0.05)

    # As wide as the design allows, but never taller than the room left: every corner of the device stays on the image.
    target_w = int(min(w * (0.8 if phone else 0.84), (h - shot_top - h * 0.012) * shot.width / shot.height))
    scale = target_w / shot.width
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    # The screen's own corners: a phone's are deep; an iPad's are gentle, measured on its short side.
    radius = int(target_w * 0.11) if phone else int(min(shot.width, shot.height) * 0.035)
    framed = rounded(shot, radius)
    shadow = Image.new("RGBA", (framed.width + 160, framed.height + 160), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([80, 100, framed.width + 80, framed.height + 80], radius=int(target_w * 0.1), fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    x = (w - framed.width) // 2
    canvas.alpha_composite(shadow, (x - 80, shot_top - 80))
    canvas.alpha_composite(framed, (x, shot_top))
    ImageDraw.Draw(canvas).rounded_rectangle([x, shot_top, x + framed.width - 1, shot_top + framed.height - 1],
                                             radius=radius, outline=(46, 50, 58), width=3)
    canvas.convert("RGB").save(out, quality=95)
    return size


def size_problem(device: str, path: Path, shot_path: Path):
    """Why the written frame can't go to App Store Connect (a size it doesn't take, or the capture's orientation
    lost on the way), or None."""
    from PIL import Image
    with Image.open(path) as image:
        size = image.size
    w, h = SIZES[device]
    if size not in ((w, h), (h, w)):
        return f"{path.name} is {size[0]}x{size[1]}; App Store Connect takes {w}x{h} or {h}x{w}"
    shot = upright(shot_path)
    if (size[0] > size[1]) != (shot.width > shot.height):
        return f"{path.name} is {size[0]}x{size[1]} but its capture is {shot.width}x{shot.height} upright"
    return None


def main():
    counts = build_counts()
    if "--check" in sys.argv:
        found = []
        for device in ("iphone", "ipad"):
            rows = plan(device)
            found += problems(device, rows, counts)
            for number, (capture, caption, line) in enumerate(rows, 1):
                print(f"{device} {number}. {caption} | {line} | {capture}")
        for problem in found:
            print("PROBLEM", problem)
        sys.exit(1 if found else 0)

    if len(sys.argv) < 3:
        sys.exit(__doc__)
    folder, out = Path(sys.argv[1]), Path(sys.argv[2])
    ipad = "--ipad" in sys.argv
    device = "ipad" if ipad else "iphone"
    rows = plan(device)
    found = problems(device, rows, counts)
    if found:
        sys.exit("The listing's screenshot table needs fixing first:\n" + "\n".join(found))
    out.mkdir(parents=True, exist_ok=True)
    captures = attachments(folder)
    unusable = []
    for number, (name, title, subtitle) in enumerate(rows, 1):
        where = f"{device} #{number} ({name})"
        if name + "-wrong" in captures:
            unusable.append(f"{where}: its UI test found the screen didn't show the caption (see the test log and {name}-wrong)")
            continue
        if name not in captures:
            unusable.append(f"{where}: no capture in this run")
            continue
        if len(captures[name]) > 1:
            unusable.append(f"{where}: captured {len(captures[name])} times in this run, so the frame is ambiguous")
            continue
        target = out / f"{device}-{number:02d}.jpg"
        size = compose(captures[name][0], title, subtitle, device, target)
        problem = size_problem(device, target, captures[name][0])
        if problem:
            unusable.append(f"{where}: {problem}")
            continue
        print("wrote", target, f"{size[0]}x{size[1]}")
    if unusable:
        sys.exit("Store frames that need a good run first:\n" + "\n".join(unusable))


if __name__ == "__main__":
    main()
