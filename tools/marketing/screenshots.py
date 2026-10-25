#!/usr/bin/env python3
"""App Store screenshots from the CI screenshot tour, art-directed.

python3 tools/marketing/screenshots.py <captures> <out folder> [--ipad] [--page NAME] [--locale CODE] [--font PATH]
python3 tools/marketing/screenshots.py --check

The frames live in one place only: the tables under "## Screenshots" in docs/ios/APP-STORE-LISTING.md ("### iPhone
6.9"", "### iPad 13"", and one "### iPhone 6.9": <page>" per Custom Product Page), each row a caption, a supporting
line, the capture it frames and its look (`layout accent`). Localized captions live in APP-STORE-LISTING-LOCALIZED.md,
a table per locale with the same captures in the same order; the look always comes from the English row.

<captures> is the iOS workflow's exported xcresult attachments (manifest.json beside the PNGs) or any folder of PNGs
named after their captures (`10b-tune-locked.png`). A localized set needs a localized tour: run the UI tests with
TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE, then render with --locale de-DE.

--check (instead of rendering) checks every table of every locale and the listing's paste blocks: at most 10 frames
a set, captions of at most 30 characters, captures the UI tests really take (each in exactly one place), localized
tables naming the English captures in the English order, every count a caption, supporting line, promotional text,
description or App Preview caption quotes (lessons, courses, instruments, tunings, songs, Originals) equal to the
build's own (curriculum.json, catalog.json; "N+" means at least N and not far below), and the name, subtitle,
keywords, promotional text and description within Apple's limits. Untranslated captions (marked "TRANSLATE:") are
listed, not failed; rendering a locale refuses them unless --allow-english.

Rendering picks the captures a table names and composes each one (a capture is turned upright from its EXIF orientation
first: XCUIScreen stores a landscape iPad capture as a portrait bitmap tagged orientation 8). iPhone output is
1320x2868 (6.9-inch); --ipad output is 2752x2064 for a landscape capture, 2064x2752 for a portrait one. Every written
frame is read back and checked against those sizes. It renders what it can, writes sheet.png (the set side by side at
search-result size) and warns when two frames look alike there, then exits non-zero if any frame is missing, was
flagged wrong by its test, was captured more than once, or came out at a size App Store Connect would refuse.

Looks (art.py has the palette): breakout, zoom, callout, wall, light, offset, offset-left, flip; on iPad side,
side-right, light. Where each capture's hero region sits is in FOCUS below, as fractions of the capture.
"""
from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import art  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LISTING = ROOT / "docs/ios/APP-STORE-LISTING.md"
LOCALIZED = ROOT / "docs/ios/APP-STORE-LISTING-LOCALIZED.md"
CURRICULUM = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
CATALOG = ROOT / "ios/Sources/TimbreCore/Resources/catalog.json"
UI_TESTS = ROOT / "ios/TimbreUITests"
CAPTION_LIMIT = 30
FRAME_LIMIT = 10          # App Store Connect takes at most 10 screenshots per device size
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional": 170, "description": 4000, "whats new": 4000}
SIZES = {"iphone": (1320, 2868), "ipad": (2064, 2752)}  # portrait (width, height); landscape swaps them
# Counts a caption or a paste block may quote, checked against the build. A hyphenated "40-lesson" is a description,
# not a count, and is left alone.
COUNT = re.compile(r"(?<![\d\-])(\d[\d,]*)(\+?)\s+(lessons|courses|instruments|tunings|songs|originals)\b", re.IGNORECASE)
# "N+" may sit under the build's count, but not far under: a floor this stale reads as a smaller app.
PLUS_SLACK = 0.8
UNTRANSLATED = "TRANSLATE:"
LOCALES = ["de-DE", "fr-FR", "es-MX", "pt-BR", "it", "ja", "ko", "zh-Hans", "ru"]

# Where each capture's hero sits, as fractions of the upright capture:
#   y0      the top of what a zoom, flip or plain card shows (the rest of the screen runs on below it)
#   x       the columns a zoom keeps, to enlarge it further
#   cut     breakout: where the screen card starts; above it the picture rises out of the card
#   rise    breakout: the top of the picture that rises out
#   keep    breakout: the columns of the rising picture kept (its sides fade away)
#   detail  callout: the region enlarged in the card that breaks out over the screen's edge
FOCUS = {
    "10b-tune-locked": {"cut": 0.455, "rise": 0.075, "keep": (0.20, 0.80)},
    "49d-tune-violin-locked": {"cut": 0.70, "rise": 0.05, "keep": (0.22, 0.78)},
    "65-song-perform": {"y0": 0.032},
    "65b-song-perform-violin": {"y0": 0.032},
    "62-lesson-results": {"y0": 0.035, "x": (0.02, 0.98)},
    "52b-lesson-chord": {"y0": 0.0, "detail": (0.10, 0.085, 0.92, 0.152)},
    "31b-instruments-folk": {"y0": 0.0},
    "63-songs": {"y0": 0.0},
    "50-learn": {"y0": 0.0},
    "11b-tune-strum": {"y0": 0.255},
    "32-journey": {"y0": 0.0},
}


# MARK: the tables


def _cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def _rows(lines: list[str]) -> list[tuple]:
    """(capture, caption, supporting line, look) for each numbered row of a table."""
    rows = []
    for line in lines:
        if not line.startswith("|"):
            continue
        cells = _cells(line)
        if len(cells) < 4 or not cells[0].isdigit():
            continue  # the header and the divider
        capture = re.search(r"`([^`]+)`", cells[3])
        look = re.search(r"`([^`]+)`", cells[4]) if len(cells) > 4 else None
        rows.append((capture.group(1) if capture else "", cells[1].replace("**", "").strip(), cells[2].strip(),
                     look.group(1) if look else ""))
    return rows


def _english_table(device: str, page: str | None) -> tuple[str, list[str]] | None:
    """The heading and lines of the English table for a device ("iphone", "ipad") and page (None: the main set)."""
    section = False
    heading = None
    collected: list[str] = []
    for line in LISTING.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            if heading:
                break
            section = line.startswith("## Screenshots")
            continue
        if not section:
            continue
        if line.startswith("### "):
            if heading:
                break
            title = line[4:].strip().lower()
            named = title.split(":", 1)[1].strip() if ":" in title else None
            if title.startswith(device) and ((page is None and named is None) or (page and named and named.startswith(page.lower()))):
                heading = line[4:].strip()
            continue
        if heading:
            collected.append(line)
    return (heading, collected) if heading else None


def pages() -> list[str]:
    """The Custom Product Pages with a table of their own ("### iPhone 6.9": violin page" -> "violin")."""
    found = []
    section = False
    for line in LISTING.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            section = line.startswith("## Screenshots")
        elif section and line.startswith("### ") and ":" in line and line[4:].lower().startswith(("iphone", "ipad")):
            found.append(line.split(":", 1)[1].strip().split()[0].lower())
    return list(dict.fromkeys(found))


def plan(device: str, page: str | None = None, locale: str | None = None) -> list[tuple]:
    """The rows of a set. A locale's rows take their captions from its table and their looks from the English rows."""
    table = _english_table(device, page)
    english = _rows(table[1]) if table else []
    if not locale or locale.lower() in ("en", "en-us"):
        return english
    localized = _localized_rows(locale, device)
    looks = {capture: look for capture, _, _, look in english}
    return [(capture, caption, line, looks.get(capture, "")) for capture, caption, line, _ in localized]


def _localized_rows(locale: str, device: str) -> list[tuple]:
    """A locale's caption table for a device, from APP-STORE-LISTING-LOCALIZED.md ("## de-DE: …" then
    "### Screenshot captions: iPhone")."""
    if not LOCALIZED.exists():
        return []
    inside = False
    table = False
    lines: list[str] = []
    for line in LOCALIZED.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            inside = line[3:].split(":", 1)[0].strip().lower() == locale.lower()
            table = False
            continue
        if inside and line.startswith("### "):
            title = line[4:].strip().lower()
            table = title.startswith("screenshot captions") and device in title
            continue
        if inside and table:
            lines.append(line)
    return _rows(lines)


def build_counts() -> dict:
    courses = json.loads(CURRICULUM.read_text(encoding="utf-8"))["courses"]
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

    def title(lesson) -> str:
        value = lesson.get("title")
        return value.get("t", "") if isinstance(value, dict) else str(value)

    songs = [lesson for course in courses for unit in course.get("units", []) for lesson in unit.get("lessons", [])
             if lesson.get("kind") == "song"]
    originals = [lesson for course in courses if course.get("id") == "originals" for unit in course.get("units", [])
                 for lesson in unit.get("lessons", []) if lesson.get("kind") == "song"]
    return {
        "lessons": sum(len(unit.get("lessons", [])) for course in courses for unit in course.get("units", [])),
        "courses": len(courses),
        "instruments": len(catalog["instruments"]),
        "tunings": len(catalog["tunings"]),
        # A song is a title: the same song arranged for two instruments is one song to a buyer.
        "songs": len({title(lesson).strip().lower() for lesson in songs}),
        "originals": len({title(lesson).strip().lower() for lesson in originals}),
    }


def count_problems(text: str, counts: dict, where: str) -> list[str]:
    found = []
    for amount, plus, noun in COUNT.findall(text):
        actual = counts[noun.lower()]
        value = int(amount.replace(",", ""))
        if plus:
            if value > actual:
                found.append(f"{where}: says {amount}+ {noun}; the build has {actual}")
            elif value < actual * PLUS_SLACK:
                found.append(f"{where}: says {amount}+ {noun}; the build has {actual}, raise the floor")
        elif value != actual:
            found.append(f"{where}: says {amount} {noun}; the build has {actual}")
    return found


def table_problems(label: str, rows: list, counts: dict, english: list | None = None) -> tuple[list[str], list[str]]:
    """Problems and untranslated rows of one set's table."""
    found: list[str] = []
    untranslated: list[str] = []
    if not rows:
        return [f"{label}: no table"], []
    if len(rows) > FRAME_LIMIT:
        found.append(f"{label}: {len(rows)} frames; App Store Connect takes at most {FRAME_LIMIT}")
    tests = "\n".join(path.read_text(encoding="utf-8") for path in sorted(UI_TESTS.glob("*.swift")))
    for number, (capture, caption, line, look) in enumerate(rows, 1):
        where = f"{label} #{number}"
        taken = tests.count(f'"{capture}"') if capture else 0
        if not capture:
            found.append(f"{where}: the Capture column names no capture (`name`)")
        elif not taken:
            found.append(f"{where}: no UI test takes a capture named {capture}")
        elif taken > 1:
            found.append(f"{where}: {capture} is named in {taken} places in the UI tests; a store frame comes from one capture")
        if english is not None:
            if number > len(english) or english[number - 1][0] != capture:
                found.append(f"{where}: {capture or 'no capture'} where the English set has "
                             f"{english[number - 1][0] if number <= len(english) else 'no frame'}")
        elif not look:
            found.append(f"{where}: no look (`layout accent`) in the last column")
        texts = (caption, line)
        if any(text.startswith(UNTRANSLATED) for text in texts):
            untranslated.append(f"{where}")
            continue
        if len(caption) > CAPTION_LIMIT:
            found.append(f"{where}: “{caption}” is {len(caption)} characters (at most {CAPTION_LIMIT})")
        if english is None:
            for text in texts:
                found += count_problems(text, counts, f"{where} “{text}”")
        elif number <= len(english):
            # A localized line quotes the same numbers as its English row (a stale "499" can't hide in German).
            source = " ".join(english[number - 1][1:3])
            for text in texts:
                for value in re.findall(r"\d[\d,.]*", text):
                    if value.replace(",", "").replace(".", "") not in source.replace(",", ""):
                        found.append(f"{where}: “{text}” quotes {value}, which its English row doesn't")
    if english is not None and len(rows) != len(english):
        found.append(f"{label}: {len(rows)} frames where the English set has {len(english)}")
    return found, untranslated


def _block_after(text: str, heading: str) -> str | None:
    """The first ``` block after a heading that starts with `heading`."""
    match = re.search(r"^#+ " + re.escape(heading) + r"[^\n]*\n(.*?)```\n(.*?)```", text, re.S | re.M | re.I)
    return match.group(2).strip() if match else None


def listing_problems(counts: dict) -> list[str]:
    """The English listing's fields within Apple's limits and its counts equal to the build's."""
    found = []
    text = LISTING.read_text(encoding="utf-8")
    fields = {}
    for row in text.splitlines():
        cells = _cells(row) if row.startswith("|") else []
        if len(cells) >= 2 and cells[0] in ("Name", "Subtitle"):
            fields[cells[0].lower()] = cells[1]
    fields["keywords"] = _block_after(text, "Keywords") or ""
    fields["promotional"] = _block_after(text, "Promotional text") or ""
    fields["description"] = _block_after(text, "Description") or ""
    fields["whats new"] = _block_after(text, "What's New") or ""
    for name, limit in LIMITS.items():
        value = unicodedata.normalize("NFC", fields.get(name, ""))
        if not value:
            found.append(f"listing: no {name}")
        elif len(value) > limit:
            found.append(f"listing: the {name} is {len(value)} characters (at most {limit})")
    keywords = fields["keywords"]
    if ", " in keywords:
        found.append("listing: keywords have a space after a comma (it counts against the 100)")
    indexed = set(re.findall(r"[a-z]+", (fields.get("name", "") + " " + fields.get("subtitle", "")).lower()))
    for word in keywords.split(","):
        if word.strip().lower() in indexed:
            found.append(f"listing: keyword “{word}” is already in the name or subtitle")
    for name in ("promotional", "description", "whats new"):
        found += count_problems(fields[name], counts, f"listing {name}")
    # The App Preview's captions are counted claims too.
    for row in text.splitlines():
        cells = _cells(row) if row.startswith("|") else []
        if len(cells) >= 2 and cells[0].startswith("`") and cells[0].strip("`") in ("lock", "tuned", "showme", "highway", "results", "songs", "end", "end-note"):
            found += count_problems(cells[1], counts, f"App Preview caption “{cells[1]}”")
    return found


def localized_problems(counts: dict) -> tuple[list[str], list[str]]:
    """Each locale's name, subtitle and keywords within the limits, the translators' source's variables known, and its
    caption tables matching the English sets."""
    found: list[str] = []
    untranslated: list[str] = []
    if not LOCALIZED.exists():
        return [f"no {LOCALIZED.name}"], []
    text = LOCALIZED.read_text(encoding="utf-8")
    for variable in set(re.findall(r"\{(\w+)\}", text)):
        if variable not in counts:
            found.append(f"localized source: {{{variable}}} is not one of {', '.join(sorted(counts))}")
    sections = re.split(r"^## ", text, flags=re.M)
    for locale in LOCALES:
        section = next((s for s in sections if s.split(":", 1)[0].strip().lower() == locale.lower()), None)
        if section is None:
            found.append(f"{locale}: no section")
            continue
        for name, limit in (("Name", 30), ("Subtitle", 30), ("Keywords", 100)):
            value = _block_after("## " + section, name)
            if value is None:
                found.append(f"{locale}: no {name.lower()} block")
            elif len(unicodedata.normalize("NFC", value)) > limit:
                found.append(f"{locale}: the {name.lower()} is {len(value)} characters (at most {limit})")
        for device in ("iphone", "ipad"):
            rows = _localized_rows(locale, device)
            problems, todo = table_problems(f"{locale} {device}", rows, counts, english=plan(device))
            found += problems
            untranslated += todo
    return found, untranslated


def check() -> int:
    counts = build_counts()
    print("build: " + ", ".join(f"{value} {name}" for name, value in counts.items()))
    found: list[str] = []
    sets = [("iphone", None), ("ipad", None)] + [("iphone", page) for page in pages()]
    for device, page in sets:
        rows = plan(device, page)
        label = f"{device}{' · ' + page if page else ''}"
        problems, _ = table_problems(label, rows, counts)
        found += problems
        for number, (capture, caption, line, look) in enumerate(rows, 1):
            print(f"{label} {number}. {caption} | {line} | {capture} | {look}")
    found += listing_problems(counts)
    problems, untranslated = localized_problems(counts)
    found += problems
    if untranslated:
        print(f"UNTRANSLATED ({len(untranslated)} rows, for the translators; not a failure): " + ", ".join(untranslated))
    for problem in found:
        print("PROBLEM", problem)
    print(f"{len(LOCALES) + 1} listing locales checked: {'all pass' if not found else f'{len(found)} problems'}")
    return 1 if found else 0


# MARK: captures


def attachments(folder: Path) -> dict:
    """Capture name -> every file under that name (more than one means it was taken twice): the xcresult export's
    manifest, or loose PNGs named after their captures."""
    found: dict[str, list[Path]] = {}
    manifest = folder / "manifest.json"
    if manifest.exists():
        for test in json.loads(manifest.read_text()):
            for item in test["attachments"]:
                name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(\.\w+)?$", "", item["suggestedHumanReadableName"]).split("_0_")[0]
                found.setdefault(name, []).append(folder / item["exportedFileName"])
    else:
        for path in sorted(folder.glob("*.png")):
            found.setdefault(path.stem, []).append(path)
    return found


def upright(shot_path: Path):
    """The capture as it appears on screen: its EXIF orientation applied."""
    from PIL import Image, ImageOps
    with Image.open(shot_path) as image:
        return ImageOps.exif_transpose(image).convert("RGB")


def frame_size(device: str, shot) -> tuple:
    w, h = art_size = SIZES[device]
    return (h, w) if shot.width > shot.height else art_size


# MARK: composing


class Frame:
    """One store frame being composed: its canvas, type and the caption block's foot."""

    def __init__(self, size: tuple, accent: str, light: bool = False, glow: tuple = (0.5, 0.12)):
        self.size = size
        self.w, self.h = size
        self.accent = accent
        self.light = light
        self.unit = min(size) / 1320  # type and margins scale with the short side
        self.canvas = art.backdrop(size, accent, light=light, glow=glow).convert("RGBA")
        self.ink = art.PAPER_INK if light else art.INK

    def px(self, value: float) -> int:
        return int(round(value * self.unit))

    def caption(self, title: str, line: str, top: float, left: float, right: float, align: str = "centre") -> int:
        """The caption (Sora SemiBold, 136 px down to 120 at 1320 wide) and the supporting line under it (Sora Medium,
        56 px, the ink at 60 %); returns the foot of the block."""
        from PIL import ImageDraw
        width = right - left
        font, lines = art.fit_lines(title, "SemiBold", self.px(136), self.px(120), width)
        small, rows = art.fit_lines(line, "Medium", self.px(56), self.px(52), width) if line else (None, [])
        draw = ImageDraw.Draw(self.canvas)
        x, anchor = {"centre": ((left + right) / 2, "ma"), "left": (left, "la"), "right": (right, "ra")}[align]
        y = top
        for text in lines:
            draw.text((x, y), text, font=font, fill=self.ink, anchor=anchor)
            y += int(font.size * 1.04)
        if rows:
            y += self.px(26)
            sample = self.canvas.getpixel((int(min(max(x, 0), self.w - 1)), int(min(y + small.size // 2, self.h - 1))))
            soft = art.mix(self.ink, sample[:3], 0.40)
            for text in rows:
                draw.text((x, y), text, font=small, fill=soft, anchor=anchor)
                y += int(small.size * 1.18)
        return int(y)

    def card(self, picture, x: int, y: int, radius: int, corners=(True, True, True, True), rim: bool = True, shadow: int = 150):
        """A screen card: shadow, picture with rounded corners, a thin rim of the accent."""
        box = (x, y, x + picture.width, y + picture.height)
        art.drop_shadow(self.canvas, box, radius, self.px(46), shadow if not self.light else 70, self.px(24))
        self.canvas.alpha_composite(art.rounded(picture, radius, corners), (int(x), int(y)))
        if rim:
            colour = art.mix(art.STAGE, art.tint(self.accent), 0.5) if not self.light else (205, 198, 186)
            art.outline(self.canvas, (x, y, x + picture.width - 1, y + picture.height - 1), radius, colour + (255,), max(2, self.px(3)))

    def save(self, out: Path) -> tuple:
        self.canvas.convert("RGB").save(out, quality=95)
        return self.size


def _scaled(shot, scale: float, box: tuple):
    """The part of `shot` inside `box` (pixels), scaled."""
    from PIL import Image
    part = shot.crop(tuple(int(round(v)) for v in box))
    return part.resize((max(1, int(part.width * scale)), max(1, int(part.height * scale))), Image.LANCZOS)


def _screen_radius(width: int) -> int:
    return int(width * 0.105)


def compose(look: str, shot_path: Path, capture: str, title: str, line: str, device: str, out: Path) -> tuple:
    shot = upright(shot_path)
    size = frame_size(device, shot)
    layout, _, accent = (look.split(None, 1) + ["mint"])[:2][0], None, (look.split() + ["", "mint"])[1] or "mint"
    landscape = size[0] > size[1]
    focus = FOCUS.get(capture, {})
    if landscape:
        layout = layout if layout in ("side", "side-right", "light") else "side"
        return _landscape(layout, accent, shot, title, line, size, out)
    if device == "ipad":
        layout = "light" if layout == "light" else "zoom"
    handler = {"breakout": _breakout, "zoom": _zoom, "callout": _callout, "wall": _wall, "light": _light,
               "offset": _offset, "offset-left": _offset, "flip": _flip}.get(layout, _zoom)
    frame = handler(layout, accent, shot, focus, title, line, size)
    return frame.save(out)


def _zoom(layout, accent, shot, focus, title, line, size):
    """The hero region, enlarged to the frame's width less its sides, bleeding off the bottom."""
    frame = Frame(size, accent)
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    x0, x1 = focus.get("x", (0.0, 1.0))
    y0 = focus.get("y0", 0.0)
    width = frame.w - 2 * frame.px(64)
    scale = width / ((x1 - x0) * shot.width)
    top = foot + frame.px(70)
    visible = (frame.h - top + frame.px(80)) / scale
    box = (x0 * shot.width, y0 * shot.height, x1 * shot.width, min(shot.height, y0 * shot.height + visible))
    picture = _scaled(shot, scale, box)
    frame.card(picture, frame.px(64), top, _screen_radius(width), corners=(True, True, False, False))
    return frame


def _breakout(layout, accent, shot, focus, title, line, size):
    """The 3D headstock rising out of the screen: the screen card holds the readout and the string chips, enlarged;
    above its top edge the picture goes on (the headstock, its peg ringed and ticked), unframed, fading out at its
    sides and top, and over the card's rim, so it stands out of the screen and over the frame's stage."""
    from PIL import Image, ImageDraw, ImageFilter
    frame = Frame(size, accent, glow=(0.5, 0.30))
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    cut, rise = focus.get("cut", 0.45), focus.get("rise", 0.07)
    keep = focus.get("keep", (0.2, 0.8))
    side = frame.px(70)
    width = frame.w - 2 * side
    bleed = frame.px(70)
    # As wide as the frame allows, but the rise and the card together fit between the caption and the bottom edge.
    scale = min(width / shot.width, (frame.h + bleed - foot - frame.px(30)) / ((1 - rise) * shot.height))
    width = int(shot.width * scale)
    x = (frame.w - width) // 2
    card = _scaled(shot, scale, (0, cut * shot.height, shot.width, shot.height))
    card_top = frame.h + bleed - card.height
    frame.card(card, x, card_top, _screen_radius(width), corners=(True, True, False, False))
    # The rising picture: from `rise` down to a little past the cut, so it laps over the card's rim.
    lap = int(frame.px(90) / scale)
    lifted = _scaled(shot, scale, (0, rise * shot.height, shot.width, min(shot.height, cut * shot.height + lap)))
    mask = Image.new("L", lifted.size, 0)
    left, right = keep[0] * lifted.width, keep[1] * lifted.width
    feather = lifted.width * 0.07
    ImageDraw.Draw(mask).rounded_rectangle([left + feather, feather * 1.4, right - feather, lifted.height - feather * 0.6],
                                            radius=int(feather * 2), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather * 0.8))
    lifted_top = card_top - (lifted.height - int(lap * scale))
    glow = Image.new("RGBA", lifted.size, art.tint(accent) + (0,))
    glow.putalpha(mask.point(lambda v: int(v * 0.22)).filter(ImageFilter.GaussianBlur(feather * 1.5)))
    frame.canvas.alpha_composite(glow, (x, lifted_top))
    rising = lifted.convert("RGBA")
    rising.putalpha(mask)
    frame.canvas.alpha_composite(rising, (x, lifted_top))
    return frame


def _callout(layout, accent, shot, focus, title, line, size):
    """The whole screen, its key detail enlarged in a card that breaks out over the screen's right edge."""
    frame = Frame(size, accent)
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    width = int(frame.w * 0.78)
    scale = width / shot.width
    x = frame.px(70)
    top = foot + frame.px(70)
    visible = (frame.h - top + frame.px(80)) / scale
    y0 = focus.get("y0", 0.0)
    screen = _scaled(shot, scale, (0, y0 * shot.height, shot.width, min(shot.height, y0 * shot.height + visible)))
    frame.card(screen, x, top, _screen_radius(width), corners=(True, True, False, False))
    detail = focus.get("detail")
    if detail:
        dx0, dy0, dx1, dy1 = detail
        zoom = scale * 1.55
        picture = _scaled(shot, zoom, (dx0 * shot.width, dy0 * shot.height, dx1 * shot.width, dy1 * shot.height))
        # Over the detail's own place in the screen, pushed right so it breaks out past the screen's edge.
        centre_y = top + ((dy0 + dy1) / 2 - y0) * shot.height * scale
        cx = min(frame.w - frame.px(40) - picture.width, x + width - picture.width + frame.px(150))
        cy = int(centre_y - picture.height / 2 + frame.px(40))
        frame.card(picture, cx, cy, frame.px(34), shadow=190)
    return frame


def _wall(layout, accent, shot, focus, title, line, size):
    """The instrument browser in front of a wall of the app's own instrument photographs (the cutouts its cards show),
    dimmed behind the caption."""
    from PIL import Image, ImageEnhance
    frame = Frame(size, accent, glow=(0.5, 0.30))
    photos = sorted(p for p in art.ASSETS.glob("[0-9][0-9]_*.imageset/*.png"))
    if photos:
        columns, tile = 5, frame.w // 4.6
        step = len(photos) / 40
        chosen = [photos[int(i * step)] for i in range(40)]
        rows = int(frame.h / (tile * 0.86)) + 1
        index = 0
        for row in range(rows):
            for column in range(columns):
                if index >= len(chosen):
                    index = 0
                with Image.open(chosen[index]) as source:
                    picture = source.convert("RGBA")
                index += 1
                picture.thumbnail((int(tile * 0.92), int(tile * 0.92)), Image.LANCZOS)
                fade = 0.30 + 0.25 * (row / rows)
                alpha = picture.getchannel("A").point(lambda v, f=fade: int(v * f))
                picture = ImageEnhance.Brightness(picture).enhance(0.9)
                picture.putalpha(alpha)
                px = int(column * tile - (tile * 0.5 if row % 2 else tile * 0.1) + (tile - picture.width) / 2)
                py = int(row * tile * 0.86 + (tile - picture.height) / 2) - frame.px(60)
                frame.canvas.alpha_composite(picture, (max(-picture.width + 1, px), max(-picture.height + 1, py)))
        # A shade behind the caption, so it reads over the wall.
        shade = art.backdrop((frame.w, frame.px(760)), accent, glow=(0.5, 0.2)).convert("RGBA")
        gradient = Image.linear_gradient("L").resize(shade.size).point(lambda v: int(235 * (1 - v / 255) ** 0.6))
        shade.putalpha(gradient)
        frame.canvas.alpha_composite(shade, (0, 0))
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    width = int(frame.w * 0.74)
    scale = width / shot.width
    top = max(foot + frame.px(120), int(frame.h * 0.30))
    visible = (frame.h - top + frame.px(80)) / scale
    y0 = focus.get("y0", 0.0)
    screen = _scaled(shot, scale, (0, y0 * shot.height, shot.width, min(shot.height, y0 * shot.height + visible)))
    frame.card(screen, (frame.w - width) // 2, top, _screen_radius(width), corners=(True, True, False, False), shadow=200)
    return frame


def _light(layout, accent, shot, focus, title, line, size):
    """The one light frame: the screen on warm paper, a soft shadow under it."""
    frame = Frame(size, accent, light=True, glow=(0.5, 0.55))
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    width = int(frame.w * 0.82)
    scale = width / shot.width
    top = foot + frame.px(80)
    visible = (frame.h - top + frame.px(80)) / scale
    y0 = focus.get("y0", 0.0)
    screen = _scaled(shot, scale, (0, y0 * shot.height, shot.width, min(shot.height, y0 * shot.height + visible)))
    frame.card(screen, (frame.w - width) // 2, top, _screen_radius(width), corners=(True, True, False, False), rim=False)
    return frame


def _offset(layout, accent, shot, focus, title, line, size):
    """The caption set to one side, the screen shifted the other way, bleeding off that edge and the bottom."""
    left = layout == "offset-left"
    frame = Frame(size, accent, glow=(0.75 if left else 0.25, 0.12))
    m = frame.px(96)
    foot = frame.caption(title, line, frame.px(160), m, frame.w - m - frame.px(40), align="right" if left else "left")
    width = int(frame.w * 0.86)
    scale = width / shot.width
    top = foot + frame.px(80)
    visible = (frame.h - top + frame.px(80)) / scale
    y0 = focus.get("y0", 0.0)
    screen = _scaled(shot, scale, (0, y0 * shot.height, shot.width, min(shot.height, y0 * shot.height + visible)))
    x = -frame.px(110) if left else frame.w - width + frame.px(110)
    corners = (False, True, False, False) if left else (True, False, False, False)
    frame.card(screen, x, top, _screen_radius(width), corners=corners)
    return frame


def _flip(layout, accent, shot, focus, title, line, size):
    """The screen from the top, bleeding off it, the caption at the foot."""
    frame = Frame(size, accent, glow=(0.5, 0.86))
    m = frame.px(84)
    width = frame.w - 2 * frame.px(64)
    scale = width / shot.width
    caption_room = frame.px(560)
    bottom = frame.h - caption_room
    y0 = focus.get("y0", 0.0)
    visible = (bottom + frame.px(60)) / scale
    screen = _scaled(shot, scale, (0, y0 * shot.height, shot.width, min(shot.height, y0 * shot.height + visible)))
    frame.card(screen, frame.px(64), bottom - screen.height, _screen_radius(width), corners=(False, False, True, True))
    frame.caption(title, line, bottom + frame.px(110), m, frame.w - m)
    return frame


def _landscape(layout, accent, shot, title, line, size, out: Path) -> tuple:
    """iPad landscape: the caption in a column on one side and the screen bleeding off the other (`side`,
    `side-right`), or the light frame with the caption on top."""
    frame = Frame(size, accent, light=layout == "light", glow=(0.2 if layout == "side" else 0.8, 0.45))
    if layout == "light":
        m = frame.px(120)
        foot = frame.caption(title, line, frame.px(110), m, frame.w - m)
        height = frame.h - foot - frame.px(80) + frame.px(120)
        scale = height / shot.height
        screen = _scaled(shot, scale, (0, 0, shot.width, shot.height))
        frame.card(screen, (frame.w - screen.width) // 2, foot + frame.px(80), frame.px(46), corners=(True, True, False, False), rim=False)
        return frame.save(out)
    column = int(frame.w * 0.30)
    scale = (frame.h * 0.84) / shot.height
    screen = _scaled(shot, scale, (0, 0, shot.width, shot.height))
    top = (frame.h - screen.height) // 2
    if layout == "side":
        frame.card(screen, column + frame.px(40), top, frame.px(46), corners=(True, False, False, True))
        area = (frame.px(110), column - frame.px(10))
    else:
        frame.card(screen, frame.w - column - frame.px(40) - screen.width, top, frame.px(46), corners=(False, True, True, False))
        area = (frame.w - column + frame.px(10), frame.w - frame.px(110))
    # The caption sits a little above the middle of its column.
    from PIL import Image
    probe = Image.new("RGBA", frame.size)
    trial = Frame.__new__(Frame)
    trial.__dict__.update(frame.__dict__)
    trial.canvas = probe
    height = trial.caption(title, line, 0, area[0], area[1], align="left")
    frame.caption(title, line, int(frame.h * 0.46 - height / 2), area[0], area[1], align="left")
    return frame.save(out)


def size_problem(device: str, path: Path, shot_path: Path):
    """Why the written frame can't go to App Store Connect (a size it doesn't take, or the capture's orientation lost on
    the way), or None."""
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


def sheet(paths: list[Path], dest: Path) -> list[str]:
    """The set side by side at search-result height (about 300 px), and the pairs too alike to tell apart there."""
    from PIL import Image, ImageChops, ImageStat
    if not paths:
        return []
    thumbs = []
    for path in paths:
        with Image.open(path) as image:
            thumb = image.convert("RGB")
            thumb.thumbnail((10_000, 300), Image.LANCZOS)
            thumbs.append(thumb)
    gap = 12
    canvas = Image.new("RGB", (sum(t.width for t in thumbs) + gap * (len(thumbs) + 1), 300 + 2 * gap), (30, 30, 30))
    x = gap
    for thumb in thumbs:
        canvas.paste(thumb, (x, gap))
        x += thumb.width + gap
    canvas.save(dest)
    tiny = [t.resize((24, 52)) for t in thumbs]
    alike = []
    for i in range(len(tiny)):
        for j in range(i + 1, len(tiny)):
            if tiny[i].size == tiny[j].size:
                difference = sum(ImageStat.Stat(ImageChops.difference(tiny[i], tiny[j])).mean) / 3
                if difference < 14:
                    alike.append(f"{paths[i].name} and {paths[j].name} look alike at thumbnail size ({difference:.0f})")
    return alike


def render(folder: Path, out: Path, device: str, page: str | None, locale: str | None, allow_english: bool) -> int:
    counts = build_counts()
    english = plan(device, page)
    rows = plan(device, page, locale)
    label = f"{device}{' · ' + page if page else ''}{' · ' + locale if locale else ''}"
    found, untranslated = table_problems(label, rows, counts, english=english if locale else None)
    if found:
        sys.exit("The screenshot table needs fixing first:\n" + "\n".join(found))
    if untranslated and not allow_english:
        sys.exit(f"{len(untranslated)} rows of {label} are untranslated ({', '.join(untranslated)}); "
                 "translate them, or pass --allow-english for a draft")
    out.mkdir(parents=True, exist_ok=True)
    captures = attachments(folder)
    unusable = []
    written = []
    prefix = "-".join(part for part in (device, page, locale) if part)
    for number, (name, title, subtitle, look) in enumerate(rows, 1):
        where = f"{label} #{number} ({name})"
        title = title.removeprefix(UNTRANSLATED).strip()
        subtitle = subtitle.removeprefix(UNTRANSLATED).strip()
        if name + "-wrong" in captures:
            unusable.append(f"{where}: its UI test found the screen didn't show the caption (see the test log and {name}-wrong)")
            continue
        if name not in captures:
            unusable.append(f"{where}: no capture in this run")
            continue
        if len(captures[name]) > 1:
            unusable.append(f"{where}: captured {len(captures[name])} times in this run, so the frame is ambiguous")
            continue
        target = out / f"{prefix}-{number:02d}.jpg"
        size = compose(look, captures[name][0], name, title, subtitle, device, target)
        problem = size_problem(device, target, captures[name][0])
        if problem:
            unusable.append(f"{where}: {problem}")
            continue
        written.append(target)
        print("wrote", target, f"{size[0]}x{size[1]}", look)
    for warning in sheet(written, out / f"{prefix}-sheet.png"):
        print("WARNING", warning)
    if unusable:
        sys.exit("Store frames that need a good run first:\n" + "\n".join(unusable))
    return 0


def main():
    arguments = sys.argv[1:]

    def option(flag: str) -> str | None:
        if flag in arguments:
            index = arguments.index(flag)
            if index + 1 < len(arguments):
                value = arguments[index + 1]
                del arguments[index:index + 2]
                return value
            sys.exit(f"{flag} needs a value")
        return None

    font = option("--font")
    if font:
        os.environ["TIMBRE_CAPTION_FONT"] = font
        art.EXTRA_FONT = font
    page = option("--page")
    locale = option("--locale")
    if "--check" in arguments:
        sys.exit(check())
    flags = {a for a in arguments if a.startswith("--")}
    positional = [a for a in arguments if not a.startswith("--")]
    if len(positional) < 2:
        sys.exit(__doc__)
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit("Pillow is missing: python3 -m pip install pillow")
    device = "ipad" if "--ipad" in flags else "iphone"
    sys.exit(render(Path(positional[0]), Path(positional[1]), device, page, locale, "--allow-english" in flags))


if __name__ == "__main__":
    main()
