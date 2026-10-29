#!/usr/bin/env python3
"""App Store screenshots from the CI screenshot tour, art-directed.

python3 tools/marketing/screenshots.py <captures> <out folder> [--ipad | --iphone-large] [--page NAME] [--locale CODE] [--font PATH]
python3 tools/marketing/screenshots.py --check

The frames live in one place only: the tables under "## Screenshots" in docs/ios/APP-STORE-LISTING.md ("### iPhone
(medium Dynamic Island)", "### iPad 13"", and one "### iPhone ...: <page>" per Custom Product Page), each row a caption, a supporting
line, the capture it frames and its look (`layout accent`). Localized captions live in tools/l10n/store/<locale>.json,
with the same captures in the same order; the look always comes from the English row.

<captures> is the iOS workflow's exported xcresult attachments (manifest.json beside the PNGs) or any folder of PNGs
named after their captures (`10b-tune-locked.png`). A localized set needs a localized tour: run the UI tests with
TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE, then render with --locale de-DE.

--check (instead of rendering) checks every table of every locale and the listing's paste blocks: at most 10 frames
a set, captions of at most 30 characters, captures the UI tests really take (each in exactly one place), localized
tables naming the English captures in the English order, every count a caption, supporting line, promotional text,
description or App Preview caption quotes (lessons, courses, instruments, tunings, songs, Originals) equal to the
build's own (curriculum.json, catalog.json; "N+" means at least N and not far below), and the name, subtitle,
keywords, promotional text and description within Apple's limits. All 50 JSON drafts are checked strictly;
missing or untranslated content fails. Legacy Markdown rendering remains a fallback for fixture tests.

Rendering picks the captures a table names and composes each one (a capture is turned upright from its EXIF orientation
first: XCUIScreen stores a landscape iPad capture as a portrait bitmap tagged orientation 8). iPhone output is
1206x2622 (medium Dynamic Island iPhone), or --iphone-large 1320x2868 (large Dynamic Island, requiring a separate native capture); --ipad output is 2752x2064 for a landscape capture, 2064x2752 for a portrait one. Every written
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
from screenshot_roles import ROLES, screenshot_role

ROOT = Path(__file__).resolve().parents[2]
LISTING = ROOT / "docs/ios/APP-STORE-LISTING.md"
LOCALIZED = ROOT / "docs/ios/APP-STORE-LISTING-LOCALIZED.md"
CURRICULUM = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
CATALOG = ROOT / "ios/Sources/TimbreCore/Resources/catalog.json"
UI_TESTS = ROOT / "ios/TimbreUITests"
CAPTION_LIMIT = 30
FRAME_LIMIT = 10          # App Store Connect takes at most 10 screenshots per device size
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotional": 170, "description": 4000, "whats new": 4000}
SIZES = {kind: tuple(sorted(role.native_size)) for kind, role in ROLES.items()}  # portrait (width, height); landscape swaps them
# Counts a caption or a paste block may quote, checked against the build. A hyphenated "40-lesson" is a description,
# not a count, and is left alone.
COUNT = re.compile(r"(?<![\d\-])(\d[\d,]*)(\+?)\s+(lessons|courses|instruments|tunings|songs|originals)\b", re.IGNORECASE)
# "N+" may sit under the build's count, but not far under: a floor this stale reads as a smaller app.
PLUS_SLACK = 0.8
UNTRANSLATED = "TRANSLATE:"
LOCALES = [r["locale"] for r in json.loads((ROOT / "tools/l10n/store-locales.json").read_text())["locales"] if r["locale"] != "en-US"]

# Where each capture's hero sits, as fractions of the upright capture:
#   y0      the top of what a zoom, flip or plain card shows (the rest of the screen runs on below it)
#   x       the columns a zoom keeps, to enlarge it further
#   detail  callout: a native-content detector for the region enlarged over the screen's edge
#
# A zoom or flip starts below the status bar (it ends at 0.044 of a 6.3-inch capture) or at the very top, never across
# it; render refuses a frame whose top edge cuts through text (`sliced`).
FOCUS = {
    "65-song-perform": {"y0": 0.032},
    "65b-song-perform-violin": {"y0": 0.032},
    # Below the status bar, above the stars' rings' brightest part.
    "62-lesson-results": {"y0": 0.06, "x": (0.02, 0.98)},
    "62b-lesson-results-violin": {"y0": 0.06, "x": (0.02, 0.98)},
    # The callout enlarges the six ticked strings themselves: the step's headline stays at its own size in the screen.
    "52b-lesson-chord": {"y0": 0.0, "detail": "ticked-strings"},
    "31b-instruments-folk": {"y0": 0.0},
    "63-songs": {"y0": 0.0},
    "50-learn": {"y0": 0.0},
    # Below the complete toolbar (including its grey subtitle and pause button), above the lead instruction.
    # Measured medium EN/DE native captures: row367 is clear; old row309 sliced the subtitle.
    # Native large EN/DE independently measured: row367 is also clear, using its own fraction.
    "11b-tune-strum": {"y0": 0.118, "y0_by_device": {"iphone": 0.140, "iphone-large": 0.128}},
    "32-journey": {"y0": 0.0},
}

# A frame's top edge may not cut through text ("9:41" or a screen title sliced in half): a capture row there with this
# many bright or secondary-neutral text columns is a slice. Include grey subtitles, not just white titles;
# this is a conservative pixel guard, not OCR or a substitute for visual review.
SLICE_COLUMNS = 8
SLICE_LEVEL = 200


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
    """The Custom Product Pages with a table of their own ("### iPhone ...: violin page" -> "violin")."""
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
    device = screenshot_role(device).caption_device
    table = _english_table(device, page)
    english = _rows(table[1]) if table else []
    if not locale or locale.lower() in ("en", "en-us"):
        return english
    if page:
        raise ValueError("Localized Custom Product Page asset sets are not authored; default captions must not be substituted.")
    localized = _localized_rows(locale, device)
    looks = {capture: look for capture, _, _, look in english}
    return [(capture, caption, line, looks.get(capture, "")) for capture, caption, line, _ in localized]


def _localized_rows(locale: str, device: str) -> list[tuple]:
    """A locale's caption table for a device, from APP-STORE-LISTING-LOCALIZED.md ("## de-DE: …" then
    "### Screenshot captions: iPhone")."""
    store_path = ROOT / "tools/l10n/store" / f"{locale}.json"
    if store_path.exists():
        data = json.loads(store_path.read_text(encoding="utf-8"))
        return [(row["capture"], row["caption"], row["supporting_line"], "")
                for row in data.get(device + "_screenshot_captions", [])]
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


def counted_tune(title: str) -> str | None:
    """Match SongOfTheDay.countedTune: treatments share a tune; exercises do not count."""
    main = next((part for part in re.split(r'[:(（：]', title) if part), title)
    for treatment in (', fingerpicked', ' on bass'):
        if main.lower().endswith(treatment):
            main = main[:-len(treatment)]
    key = ''.join(character for character in main.lower() if character.isalpha() or character.isnumeric())
    return key if key and key not in {'yourarrangement', 'walkingthebluesina'} else None


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
    def lessons_of(course) -> list:
        return [lesson for unit in course.get("units", []) for lesson in unit.get("lessons", [])]

    def songbook(course) -> bool:
        # A course of songs and challenges only (Curriculum.isSongbook): its lessons count as songs, by title.
        kinds = {lesson.get("kind", "lesson") for lesson in lessons_of(course)}
        return "song" in kinds and "lesson" not in kinds

    teaching = [course for course in courses if not songbook(course)]
    counts = {
        "lessons": sum(len(lessons_of(course)) for course in teaching),
        "courses": len(teaching),
        "instruments": len(catalog["instruments"]),
        "tunings": len(catalog["tunings"]),
        # Match the app's distinctTuneCount, including treatment/punctuation aliases and exercises.
        "songs": len({key for lesson in songs if (key := counted_tune(title(lesson))) is not None}),
        "originals": len({title(lesson).strip().lower() for lesson in originals}),
    }
    # The translators' source writes the song count as a round floor ("{songs_floor}+").
    counts["songs_floor"] = counts["songs"] // 10 * 10
    return counts


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


def _tables_after(text: str, heading: str) -> list[list[list[str]]]:
    """Every table (rows of cells, header included, divider left out) between the `#` heading starting with `heading`
    and the next heading."""
    tables: list[list[list[str]]] = []
    inside = False
    current: list[list[str]] = []
    for line in text.splitlines() + [""]:
        if line.startswith("#"):
            if inside:
                break
            inside = line.lstrip("#").strip().lower().startswith(heading.lower())
            continue
        if inside and line.startswith("|"):
            cells = _cells(line)
            if not set("".join(cells)) <= set("-: "):
                current.append(cells)
        elif current:
            tables.append(current)
            current = []
    if current:
        tables.append(current)
    return tables


def _table_after(text: str, heading: str) -> list[list[str]]:
    """The first table under the heading starting with `heading` (empty without one)."""
    tables = _tables_after(text, heading)
    return tables[0] if tables else []


def page_keywords() -> dict[str, list[str]]:
    """Each Custom Product Page's keywords, from the listing's "## Custom Product Pages" table (the column headed
    "Keywords…"; "—" for a page that takes none)."""
    rows = _table_after(LISTING.read_text(encoding="utf-8"), "Custom Product Pages")
    if not rows:
        return {}
    column = next((i for i, cell in enumerate(rows[0]) if cell.lower().startswith("keywords")), None)
    found: dict[str, list[str]] = {}
    for cells in rows[1:]:
        if column is None or column >= len(cells):
            continue
        cell = cells[column].strip()
        found[cells[0]] = [] if cell.startswith("—") else [w.strip().strip("`") for w in cell.split(",") if w.strip()]
    return found


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
    words = [word.strip().lower() for word in keywords.split(",") if word.strip()]
    for word in sorted({w for w in words if words.count(w) > 1}):
        found.append(f"listing: keyword “{word}” is in the field twice")
    # A Custom Product Page can be assigned only keywords from the field (Apple: "from your latest approved app
    # version"), each page its own: so a page's word is in the field even when the name or subtitle has it too.
    assigned: dict[str, str] = {}
    for page, page_words in page_keywords().items():
        for word in page_words:
            if word.lower() not in words:
                found.append(f"Custom Product Page {page}: “{word}” isn't in the keyword field, so the page can't be assigned it")
            if word.lower() in assigned:
                found.append(f"Custom Product Pages {assigned[word.lower()]} and {page} both take “{word}”: give each keyword to one page")
            assigned.setdefault(word.lower(), page)
    indexed = set(re.findall(r"[a-z]+", (fields.get("name", "") + " " + fields.get("subtitle", "")).lower()))
    for word in words:
        if word in indexed and word not in assigned:
            found.append(f"listing: keyword “{word}” is already in the name or subtitle (only a Custom Product Page's word may be)")
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
    import importlib.util
    spec = importlib.util.spec_from_file_location("store_metadata", ROOT / "tools/l10n/store.py")
    store = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(store)
    problems = store.check_all()
    source = store.load("en-US")
    for key, value in source["counts"].items():
        if counts.get(key) != value:
            problems.append(f"store source: {key} says {value}; build has {counts.get(key)}")
    return problems, []


def source_problems(counts: dict) -> list[str]:
    """The translators' source (APP-STORE-LISTING-LOCALIZED.md) against the build and the English listing: each
    variable's value is the build's, and with the values filled in, the promotional text, description, What's New and
    the caption tables read exactly as the English listing does."""
    if not LOCALIZED.exists():
        return []
    text = LOCALIZED.read_text(encoding="utf-8")
    match = re.search(r"^## Source for translators[^\n]*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not match:
        return ["localized: no “## Source for translators” section"]
    source = match.group(1)
    english = LISTING.read_text(encoding="utf-8")
    found: list[str] = []
    for cells in _table_after("## variables\n" + source, "variables"):
        named = re.fullmatch(r"`\{(\w+)\}`", cells[0]) if cells else None
        if named and named.group(1) in counts and len(cells) > 1:
            value = cells[1].replace(",", "")
            if not value.isdigit() or int(value) != counts[named.group(1)]:
                found.append(f"localized source: {{{named.group(1)}}} says {cells[1]}; the build has {counts[named.group(1)]}")

    def fill(value: str) -> str:
        return re.sub(r"\{(\w+)\}", lambda m: str(counts.get(m.group(1), m.group(0))), value)

    for heading in ("Promotional text", "Description", "What's New"):
        theirs, ours = _block_after(source, heading), _block_after(english, heading)
        if theirs is None or ours is None:
            found.append(f"localized source: no {heading.lower()} block to compare")
        elif fill(theirs) != ours:
            first = next((a for a, b in zip(fill(theirs).splitlines(), ours.splitlines()) if a != b), "(a line added or removed)")
            found.append(f"localized source: the {heading.lower()} isn't the English listing's (first difference: “{first[:80]}”)")
    for device, heading in (("iphone", "Screenshot captions: iPhone"), ("ipad", "Screenshot captions: iPad")):
        theirs = [(fill(c[1]), fill(c[2])) for c in _table_after(source, heading) if len(c) >= 3 and c[0].isdigit()]
        ours = [(caption, line) for _, caption, line, _ in plan(device)]
        if theirs != ours:
            found.append(f"localized source: the {device} caption table isn't the English set's (copy the English rows, "
                         "numbers as variables)")
    preview = {"main preview": _preview_table(english, None), "violin page": _preview_table(english, "violin")}
    for table in _tables_after(source, "App Preview captions"):
        label = table[0][1].lower() if table and len(table[0]) > 1 else ""
        theirs = {c[0].strip("`"): fill(c[1]) for c in table[1:] if len(c) >= 2}
        if label in preview and theirs != preview[label]:
            found.append(f"localized source: the App Preview captions ({label}) aren't the English table's")
    return found


def _preview_table(text: str, page: str | None) -> dict[str, str]:
    """Clip -> caption of the listing's "### App Preview" table (the main one, or the page's)."""
    heading = "App Preview: " + page if page else "App Preview ("
    return {c[0].strip("`"): c[1].replace("**", "").strip() for c in _table_after(text, heading)[1:] if len(c) >= 2}


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
    found += source_problems(counts)
    problems, untranslated = localized_problems(counts)
    found += problems
    if untranslated:
        per_locale: dict[str, int] = {}
        for row in untranslated:
            locale = row.split()[0]
            per_locale[locale] = per_locale.get(locale, 0) + 1
        print(f"UNTRANSLATED (for the translators; not a failure): {len(untranslated)} caption rows: "
              + ", ".join(f"{locale} {count}" for locale, count in per_locale.items()))
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
    """The store size for this device in the capture's orientation."""
    w, h = SIZES[device]
    return (h, w) if shot.width > shot.height else (w, h)


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

    def caption_plan(self, title: str, line: str, left: float, right: float, align: str = "centre"):
        """Measure shaped glyph ink on an *unclipped* mask, not just font advances.

        Baseline/ascender anchors can put Arabic descenders below the nominal line
        advance. The same runs are used to measure and draw the final composition.
        """
        from PIL import Image, ImageDraw
        width = right - left
        font, lines = art.fit_lines(title, "SemiBold", self.px(136), self.px(96), width)
        small, rows = art.fit_lines(line, "Medium", self.px(56), self.px(52), width) if line else (None, [])
        x, anchor = {"centre": ((left + right) / 2, "ma"), "left": (left, "la"), "right": (right, "ra")}[align]
        runs = []
        y = 0
        step = art.line_step(font, lines, 1.04)
        for text in lines:
            runs.append((x, y, text, font, anchor, False))
            bottom = y + font.getbbox(text, anchor=anchor, **art.text_layout())[3]
            y += step
        if lines:
            y = max(y, bottom)
        if rows:
            y += self.px(26)
            step = art.line_step(small, rows, 1.18)
            for text in rows:
                runs.append((x, y, text, small, anchor, True))
                bottom = y + small.getbbox(text, anchor=anchor, **art.text_layout())[3]
                y += step
            y = max(y, bottom)
        pad = self.px(200)
        mask = Image.new("L", (self.w + 2 * pad, int(y) + 2 * pad), 0)
        draw = ImageDraw.Draw(mask)
        for x, row, text, font, anchor, _ in runs:
            draw.text((x + pad, row + pad), text, font=font, fill=255, anchor=anchor, **art.text_layout())
        bounds = mask.getbbox()
        ink = tuple(value - pad for value in bounds) if bounds else (left, 0, left, 0)
        return runs, int(y), ink

    def caption(self, title: str, line: str, top: float, left: float, right: float, align: str = "centre") -> int:
        """Draw measured type, failing closed if actual ink crosses the safe canvas."""
        from PIL import ImageDraw
        runs, foot, ink = self.caption_plan(title, line, left, right, align)
        bounds = (ink[0], ink[1] + top, ink[2], ink[3] + top)
        if bounds[0] < 0 or bounds[2] > self.w or bounds[1] < 0 or bounds[3] > self.h - self.px(64):
            raise ValueError(f"Caption ink {bounds} exceeds canvas/footer safe area {self.size}: {title}")
        self.caption_bounds = bounds
        draw = ImageDraw.Draw(self.canvas)
        soft = None
        for x, row, text, font, anchor, supporting in runs:
            if supporting and soft is None:
                sample = self.canvas.getpixel((int(min(max(x, 0), self.w - 1)),
                                               int(min(top + row + font.size // 2, self.h - 1))))
                soft = art.mix(self.ink, sample[:3], 0.40)
            draw.text((x, top + row), text, font=font, fill=soft if supporting else self.ink,
                      anchor=anchor, **art.text_layout())
        return int(top + foot)

    def card(self, picture, x: int, y: int, radius: int, rim: bool = True, shadow: int = 150):
        """A screen card: shadow, picture with rounded corners, a thin rim of the accent."""
        box = (x, y, x + picture.width, y + picture.height)
        art.drop_shadow(self.canvas, box, radius, self.px(46), shadow if not self.light else 70, self.px(24))
        # A nominal bleed may end on-canvas after native-height clamping. Match
        # the always-rounded rim/shadow even then; never expose square pixels.
        self.canvas.alpha_composite(art.rounded(picture, radius), (int(x), int(y)))
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


def focus_for(capture: str, device: str) -> dict:
    """Keep measured crop adjustments role-specific even when caption tables are shared."""
    focus = dict(FOCUS.get(capture, {}))
    if device in focus.get("y0_by_device", {}):
        focus["y0"] = focus["y0_by_device"][device]
    return focus


def compose(look: str, shot_path: Path, capture: str, title: str, line: str, device: str, out: Path) -> tuple:
    shot = upright(shot_path)
    role = screenshot_role(device)
    if role.caption_device == "iphone" and shot.size != role.native_size:
        raise ValueError(f"{device}: need actual native {role.native_size} capture, got {shot.size}")
    size = frame_size(device, shot)
    parts = look.split()
    layout = parts[0] if parts else "zoom"
    accent = parts[1] if len(parts) > 1 else "mint"
    landscape = size[0] > size[1]
    focus = focus_for(capture, device)
    if landscape:
        layout = layout if layout in ("side", "side-right", "light") else "side"
        return _landscape(layout, accent, shot, title, line, size, out)
    if device == "ipad":
        layout = "light" if layout == "light" else "zoom"
    handler = {"breakout": _breakout, "zoom": _zoom, "callout": _callout, "wall": _wall, "light": _light,
               "offset": _offset, "offset-left": _offset, "flip": _flip}.get(layout, _zoom)
    frame = handler(layout, accent, shot, focus, title, line, size)
    return frame.save(out)


def _contained_screen(shot, box, width, height):
    """Fit a chosen native region without stretching or silently cropping its foot."""
    box = tuple(int(round(value)) for value in box)
    if width <= 0 or height <= 0 or box[2] <= box[0] or box[3] <= box[1]:
        raise ValueError("Native screen has no positive available composition area")
    scale = min(width / (box[2] - box[0]), height / (box[3] - box[1]))
    return _scaled(shot, scale, box), scale


def _zoom(layout, accent, shot, focus, title, line, size):
    """A large native hero region; complete actions remain above the safe footer."""
    frame = Frame(size, accent)
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    x0, x1 = focus.get("x", (0.0, 1.0))
    y0 = focus.get("y0", 0.0)
    top = foot + frame.px(70)
    picture, _ = _contained_screen(shot, (x0 * shot.width, y0 * shot.height, x1 * shot.width, shot.height),
                                   frame.w - 2 * frame.px(64), frame.h - top - frame.px(64))
    frame.card(picture, (frame.w - picture.width) // 2, top, _screen_radius(picture.width))
    return frame


def _breakout(layout, accent, shot, focus, title, line, size):
    """The native instrument stage, intact, over a deep accent spotlight.

    An axis-aligned feather cannot isolate an instrument from overlapping native
    controls in every language. Keep the real stage and all its pegs/actions,
    rather than dissolving meaningful UI into the marketing background.
    """
    frame = Frame(size, accent, glow=(0.5, 0.38))
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    top = foot + frame.px(70)
    screen, _ = _contained_screen(shot, (0, 0, shot.width, shot.height),
                                  frame.w - 2 * frame.px(70), frame.h - top - frame.px(64))
    frame.card(screen, (frame.w - screen.width) // 2, top, _screen_radius(screen.width), shadow=190)
    return frame


def _ticked_strings_region(shot):
    """Locate the six native note/badge shapes and their surrounding ink-free band.

    SwiftUI uses different chord-header layouts by available width and language;
    neither screen-height fractions nor locale-specific guesses are safe here.
    This conservative detector requires six aligned, near-square mint/white
    components. It preserves their full native pixels, including the white ticks
    on either side in RTL/LTR, and refuses ambiguous/unrecognized captures.
    """
    width = shot.width
    region = shot.convert("RGB").crop((0, 0, width, round(shot.height * .45)))
    # Muted instructions count as protected ink too, not only white headlines.
    pixels = region.get_flattened_data() if hasattr(region, "get_flattened_data") else region.getdata()
    ink = bytearray((min(pixel) >= 100 and max(pixel) - min(pixel) <= 55)
                    or (pixel[0] < 130 and pixel[1] > 170 and 90 < pixel[2] < 230
                        and pixel[1] > pixel[2] * 1.05) for pixel in pixels)
    remaining = ink.copy()
    candidates = []
    for index, value in enumerate(remaining):
        if not value:
            continue
        remaining[index] = 0
        stack = [index]
        x0, y0, x1, y1, count = width, region.height, 0, 0, 0
        while stack:
            index = stack.pop()
            y, x = divmod(index, width)
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
            count += 1
            neighbours = (index - width if y else -1,
                          index + width if index + width < len(remaining) else -1,
                          index - 1 if x else -1,
                          index + 1 if x + 1 < width else -1)
            for neighbour in neighbours:
                if neighbour >= 0 and remaining[neighbour]:
                    remaining[neighbour] = 0
                    stack.append(neighbour)
        w, h = x1 - x0 + 1, y1 - y0 + 1
        if .06 * width < w < .14 * width and .75 < w / h < 1.25 and count > .4 * w * h:
            candidates.append((x0, y0, x1 + 1, y1 + 1))
    groups = {tuple(sorted(box for box in candidates if abs(box[1] - anchor[1]) < .02 * width))
              for anchor in candidates}
    groups = [group for group in groups if len(group) == 6]
    if len(groups) != 1:
        raise ValueError("Callout needs six unambiguous native ticked strings; review the source capture")
    markers = groups[0]
    x0, y0 = min(box[0] for box in markers), min(box[1] for box in markers)
    x1, y1 = max(box[2] for box in markers), max(box[3] for box in markers)
    # This also protects nearby native selectors: search all columns, not just Em.
    above = next((y + 1 for y in range(y0 - 1, -1, -1) if any(ink[y * width:(y + 1) * width])), None)
    below = next((y for y in range(y1, region.height) if any(ink[y * width:(y + 1) * width])), None)
    padding = round(max(box[3] - box[1] for box in markers) * .18)
    box = (x0 - padding, y0 - padding, x1 + padding, y1 + padding)
    if (above is None or below is None or box[0] < 0 or box[2] > width
            or box[1] <= above or box[3] >= below):
        raise ValueError("Native string callout has no verified whitespace; review the source capture")
    return box, (above, below)


def _callout_geometry(frame, shot, focus, scale, x, top, width):
    """Enlarge within native-content bounds; never mirror physical string order."""
    if focus["detail"] != "ticked-strings":
        raise ValueError("Callout requires a supported native-content detector")
    box, (clear_top, clear_bottom) = _ticked_strings_region(shot)
    y0 = round(focus.get("y0", 0.0) * shot.height)
    gap = frame.px(12)
    safe_top = top + (clear_top - y0) * scale + gap
    safe_bottom = top + (clear_bottom - y0) * scale - gap
    zoom = min(scale * 1.55, (frame.w - 2 * frame.px(48)) / (box[2] - box[0]),
               (safe_bottom - safe_top) / (box[3] - box[1]))
    if zoom <= scale:
        raise ValueError("Native string callout cannot be enlarged without covering protected UI")
    picture = _scaled(shot, zoom, box)
    centre_y = top + ((box[1] + box[3]) / 2 - y0) * scale
    cy = round(max(safe_top, min(centre_y - picture.height / 2, safe_bottom - picture.height)))
    wanted_x = x - frame.px(150) if art.text_layout()["direction"] == "rtl" else x + width - picture.width + frame.px(150)
    cx = max(frame.px(48), min(frame.w - frame.px(48) - picture.width, wanted_x))
    return picture, cx, cy


def _callout(layout, accent, shot, focus, title, line, size):
    """A complete native screen with a bounded enlargement of its six strings."""
    frame = Frame(size, accent)
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    top = foot + frame.px(70)
    y0 = focus.get("y0", 0.0)
    screen, scale = _contained_screen(shot, (0, y0 * shot.height, shot.width, shot.height),
                                      int(frame.w * 0.78), frame.h - top - frame.px(64))
    x = frame.w - screen.width - frame.px(70) if art.text_layout()["direction"] == "rtl" else frame.px(70)
    frame.card(screen, x, top, _screen_radius(screen.width))
    if focus.get("detail"):
        picture, cx, cy = _callout_geometry(frame, shot, focus, scale, x, top, screen.width)
        # A drop shadow here would darken protected native labels even outside
        # the card bounds. A crisp accent rim separates the enlarged detail.
        frame.card(picture, cx, cy, frame.px(26), shadow=0)
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
    frame.card(screen, (frame.w - width) // 2, top, _screen_radius(width), shadow=200)
    return frame


def _light(layout, accent, shot, focus, title, line, size):
    """The one light frame: the screen on warm paper, a soft shadow under it."""
    frame = Frame(size, accent, light=True, glow=(0.5, 0.55))
    m = frame.px(84)
    foot = frame.caption(title, line, frame.px(150), m, frame.w - m)
    top = foot + frame.px(80)
    y0 = focus.get("y0", 0.0)
    screen, _ = _contained_screen(shot, (0, y0 * shot.height, shot.width, shot.height),
                                  int(frame.w * 0.82), frame.h - top - frame.px(64))
    frame.card(screen, (frame.w - screen.width) // 2, top, _screen_radius(screen.width), rim=False)
    return frame


def _offset(layout, accent, shot, focus, title, line, size):
    """Offset the screen without cutting native labels at either horizontal edge."""
    left = layout == "offset-left"
    if art.text_layout()["direction"] == "rtl":
        left = not left  # Reflect placement, never source pixels or glyphs.
    frame = Frame(size, accent, glow=(0.75 if left else 0.25, 0.12))
    m = frame.px(96)
    foot = frame.caption(title, line, frame.px(160), m, frame.w - m - frame.px(40), align="right" if left else "left")
    top = foot + frame.px(80)
    y0 = focus.get("y0", 0.0)
    screen, _ = _contained_screen(shot, (0, y0 * shot.height, shot.width, shot.height),
                                  int(frame.w * 0.86), frame.h - top - frame.px(64))
    # Retain both edges and the complete native tab bar, at one uniform scale.
    inset = frame.px(36)
    x = inset if left else frame.w - screen.width - inset
    frame.card(screen, x, top, _screen_radius(screen.width))
    return frame


def _flip_geometry(shot, size, y0, bottom=None):
    """Fit the complete measured native crop between a top inset and the caption.

    Caption height is language/font dependent; callers pass its actual safe top.
    The default is retained for the source-edge guard, whose source row is now
    invariant: fitting never hides a different top row off-canvas.
    """
    unit = min(size) / 1320
    px = lambda value: int(round(value * unit))
    bottom = size[1] - px(560) if bottom is None else bottom
    start = int(round(y0 * shot.height))
    scale = min((size[0] - 2 * px(64)) / shot.width, (bottom - px(64)) / (shot.height - start))
    screen_height = max(1, int((shot.height - start) * scale))
    return (0, start, shot.width, shot.height), scale, bottom - screen_height, bottom


def _flip(layout, accent, shot, focus, title, line, size):
    """The whole measured screen region above an ink-measured footer caption."""
    frame = Frame(size, accent, glow=(0.5, 0.86))
    m = frame.px(84)
    _, advance, ink = frame.caption_plan(title, line, m, frame.w - m)
    caption_top = frame.h - frame.px(64) - max(advance, ink[3])
    box, scale, top, bottom = _flip_geometry(shot, size, focus.get("y0", 0.0), caption_top - frame.px(110))
    screen = _scaled(shot, scale, box)
    frame.card(screen, (frame.w - screen.width) // 2, top, _screen_radius(screen.width))
    frame.caption(title, line, caption_top, m, frame.w - m)
    return frame


LANDSCAPE_STATUS_ROWS = 60  # Verified native 2752x2064 EN/DE status/content whitespace.
LANDSCAPE_CORNER_RADIUS = 16  # Source pixels: stays inside the native Done pill's 20px inset.


def _landscape_x(canvas_width: int, screen_width: int, inset: int, *, light: bool, left: bool) -> int:
    """Centre the height-fitted screen; caption alignment still alternates/reflects.

    A tall translated heading can make the complete native screen much narrower
    than the old bleed. Edge-pinning then leaves an unbalanced empty half-frame.
    """
    return (canvas_width - screen_width) // 2


def _landscape(layout, accent, shot, title, line, size, out: Path) -> tuple:
    """iPad landscape: an aligned heading above the centred, complete native viewport."""
    light = layout == "light"
    left = layout != "side-right"
    rtl = art.text_layout()["direction"] == "rtl"
    if rtl and not light:
        left = not left  # Reflect placement, never native pixels or glyphs.
    frame = Frame(size, accent, light=light, glow=(0.5 if light else (0.25 if left else 0.75), 0.10))
    m = frame.px(120)
    align = "centre" if light else ("left" if left else "right")
    foot = frame.caption(title, line, frame.px(96), m, frame.w - m, align=align)
    top = foot + frame.px(64)
    screen, _ = _contained_screen(shot, (0, LANDSCAPE_STATUS_ROWS, shot.width, shot.height),
                                  int(frame.w * (0.80 if light else 0.86)),
                                  frame.h - top - frame.px(64))
    x = _landscape_x(frame.w, screen.width, frame.px(80), light=light, left=left)
    # Done starts four native pixels below the crop: an inset decorative rim
    # would erase its top cap. Keep the native control, not an intrusive border.
    frame.card(screen, x, top, max(1, round(LANDSCAPE_CORNER_RADIUS * screen.width / shot.width)), rim=False)
    return frame.save(out)


def top_row(look: str, capture: str, device: str, shot) -> int | None:
    """The capture's row at the visible top edge of its frame's screen picture; None where the layout starts at the
    capture's own top."""
    size = frame_size(device, shot)
    if size[0] > size[1]:
        return LANDSCAPE_STATUS_ROWS
    parts = look.split()
    layout = parts[0] if parts else "zoom"
    if device == "ipad":
        layout = "light" if layout == "light" else "zoom"
    if layout == "breakout":
        return None
    y0 = focus_for(capture, device).get("y0", 0.0)
    row = y0 * shot.height
    if layout == "flip":
        # Fitting preserves the actual source row without any off-canvas bleed.
        box, scale, top, _ = _flip_geometry(shot, size, y0)
        row = box[1] + max(0, -top) / scale
    return int(row) if row >= 1 else None


def sliced(shot, row: int) -> int:
    """Count bright or secondary neutral text at the visible edge, including grey subtitles."""
    rgb = shot.convert("RGB")
    pixels = rgb.load()
    rows = range(max(0, row - 2), min(rgb.height, row + 3))

    def text_pixel(pixel):
        r, g, b = pixel
        luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance >= SLICE_LEVEL or (luminance >= 100 and max(pixel) - min(pixel) <= 24)

    return sum(1 for x in range(rgb.width) if any(text_pixel(pixels[x, y]) for y in rows))


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
    if shot.size not in ((w, h), (h, w)):
        return f"{shot_path.name} is {shot.width}x{shot.height} upright; need a native {w}x{h} or {h}x{w} capture"
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
    os.environ["TIMBRE_CAPTION_LOCALE"] = locale or "en-US"
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
        shot = upright(captures[name][0])
        row = top_row(look, name, device, shot)
        if row is not None and sliced(shot, row) >= SLICE_COLUMNS:
            unusable.append(f"{where}: its top edge cuts through text at row {row} of the capture ({sliced(shot, row)} "
                            "text-like columns): move its y0 in FOCUS into a gap")
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
    if "--ipad" in flags and "--iphone-large" in flags:
        sys.exit("Choose one explicit screenshot role, not both --ipad and --iphone-large")
    device = "ipad" if "--ipad" in flags else "iphone-large" if "--iphone-large" in flags else "iphone"
    sys.exit(render(Path(positional[0]), Path(positional[1]), device, page, locale, "--allow-english" in flags))


if __name__ == "__main__":
    main()
