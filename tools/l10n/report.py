#!/usr/bin/env python3
"""The translators' handoff: every English string a shipped locale lacks, per locale.

    python3 tools/l10n/report.py                 # regenerate the handoff (idempotent)
    python3 tools/l10n/report.py --check         # CI: warn about missing strings and an out-of-date handoff
    python3 tools/l10n/report.py --check --strict  # the core job: also exit 1 when the committed handoff is stale
    python3 tools/l10n/report.py --import DIR    # merge translators' filled TODO files, apply them, regenerate
    python3 tools/l10n/report.py --xliff en.xliff  # settle code keys with Xcode's own export (l10n.yml)

Writes
    tools/l10n/todo/<locale>.json   what each locale still needs, with context and length hints
    tools/l10n/todo/index.json      the counts, per locale and table
    tools/l10n/pending.json         every UI string some locale lacks (the old queue's format)
    docs/l10n/HANDOFF.md            the translators' brief, with the counts

English comes from
    Localizable.strings   the Swift sources (swiftstrings.py) and en.lproj/Localizable.strings (the timbre_* keys)
    Localizable.stringsdict  en.lproj/Localizable.stringsdict (plurals)
    AppShortcuts.strings  the App Shortcut phrases in the Swift sources
    InfoPlist.strings     the Timbre target's Info.plist strings in ios/project.yml
    Learn.strings         en.lproj/Learn.strings (tools/curriculum/build.py), for the lesson languages only

Launch-critical strings come first in every TODO file and on the handoff page (`launch` on the entry): the paywall's
purchase terms, the permission prompts and what VoiceOver says (tools/l10n/critical.py, which the App Store upload
enforces), then the onboarding funnel from the welcome screen to the paywall.

Nothing here translates: it lists what people translate, and merges what they deliver.
"""
from __future__ import annotations

import argparse
import ast
import difflib
import json
import math
import os
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RES = ROOT / "ios/Timbre/Resources"
TODO = HERE / "todo"
HANDOFF = ROOT / "docs/l10n/HANDOFF.md"
PENDING = HERE / "pending.json"
HISTORY = HERE / "source/learn-history.json"
CURRICULUM = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
CODE = ["ios/Timbre", "ios/TimbreWidgets", "ios/TimbreWatch", "ios/TimbreWatchWidgets"]
DECLS = ["ios/Sources"]
UI_TABLES = ["InfoPlist.strings", "AppShortcuts.strings", "Localizable.strings", "Localizable.stringsdict"]
LEARN = "Learn.strings"
FIRST_SEEN = ["ios/project.yml", "ios/Timbre/Onboarding/", "ios/Timbre/Paywall/", "ios/Timbre/Root/", "ios/Timbre/Tune/",
              "ios/Timbre/Learn/", "ios/Timbre/Songs/", "ios/Timbre/Practice/", "ios/Timbre/Design/",
              "ios/Timbre/Journey/", "ios/Timbre/Instruments/", "ios/Timbre/YourSongs/", "ios/Timbre/Settings/"]
#: The onboarding funnel, welcome to paywall: launch-critical after the legal, permission and VoiceOver strings.
FUNNEL = ("ios/Timbre/Onboarding/",)
#: Launch-critical kinds in the order translators take them.
LAUNCH = ("legal", "permission", "voiceover", "funnel")
INFO_KEYS = re.compile(r"^\s+(CFBundleDisplayName|NS\w+UsageDescription):\s*(.+?)\s*$")
SPEC = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:lld|ld|llu|lu|d|u|lf|f|@|%)|\$\{\w+\}")
LANGUAGE_NAMES = {
    "ar": "Arabic", "bg": "Bulgarian", "bn": "Bengali", "ca": "Catalan", "cs": "Czech", "da": "Danish",
    "de": "German", "el": "Greek", "es": "Spanish", "et": "Estonian", "fa": "Persian", "fi": "Finnish",
    "fr": "French", "gu": "Gujarati", "he": "Hebrew", "hi": "Hindi", "hr": "Croatian", "hu": "Hungarian",
    "id": "Indonesian", "is": "Icelandic", "it": "Italian", "ja": "Japanese", "kn": "Kannada", "ko": "Korean",
    "lt": "Lithuanian", "lv": "Latvian", "ml": "Malayalam", "mr": "Marathi", "nl": "Dutch", "no": "Norwegian",
    "pa": "Punjabi", "pl": "Polish", "pt": "Portuguese", "ro": "Romanian", "ru": "Russian", "sk": "Slovak",
    "sl": "Slovenian", "sv": "Swedish", "sw": "Swahili", "ta": "Tamil", "te": "Telugu", "th": "Thai",
    "tr": "Turkish", "uk": "Ukrainian", "ur": "Urdu", "vi": "Vietnamese", "zh-CN": "Chinese (Simplified)",
    "zu": "Zulu",
}

sys.path.insert(0, str(HERE))
import apply as ui_apply  # noqa: E402
import apply_learn  # noqa: E402
import swiftstrings  # noqa: E402


# ------------------------------------------------------------------------------------------------- tables

def unescape(text: str) -> str:
    return re.sub(r'\\(u[0-9a-fA-F]{4}|.)', lambda m: {"n": "\n", "t": "\t", "r": "\r"}.get(
        m.group(1), chr(int(m.group(1)[1:], 16)) if m.group(1).startswith("u") and len(m.group(1)) == 5 else m.group(1)),
        text)


def read_strings(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    pairs = re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text, re.M)
    return {unescape(k): unescape(v) for k, v in pairs}


def read_stringsdict(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("rb") as handle:
        return plistlib.load(handle)


def plural_source(entry: dict) -> str:
    """The English `other` form of a stringsdict entry (the text a translator starts from)."""
    for name, value in entry.items():
        if isinstance(value, dict) and "other" in value:
            return value["other"]
    return entry.get("NSStringLocalizedFormatKey", "")


def locales() -> list:
    return sorted(p.name[:-6] for p in RES.glob("*.lproj") if p.name not in ("en.lproj", "Base.lproj"))


def lesson_locales() -> list:
    found = {p.parent.name[:-6] for p in RES.glob("*.lproj/Learn.strings")} | {p.stem for p in (HERE / "learn").glob("*.json")}
    return sorted(found - {"en"})


def translatable(key: str) -> bool:
    """False for keys with nothing to translate: a format alone, a note name, a symbol ("%@", "C%lld", "✓")."""
    return bool(re.search(r"[^\W\d_]{2,}", SPEC.sub(" ", key)))


# ---------------------------------------------------------------------------------------------- English (UI)

def literal_pattern(parts: list) -> re.Pattern:
    """A regex matching the key a literal can have, whatever the types of its interpolations."""
    has_interp = any(isinstance(p, swiftstrings.Interp) for p in parts)
    out = []
    for p in parts:
        if isinstance(p, swiftstrings.Interp):
            out.append(r"%(?:\d+\$)?(?:lld|ld|llu|lu|d|u|lf|f|\.\d+f|@)")
        else:
            out.append(re.escape(p.replace("%", "%%") if has_interp else p))
    return re.compile("".join(out) + r"\Z", re.S)


def tightness(lines: list, line: int, slot: str) -> list:
    """Hints that the text sits somewhere tight: from the code of the statement around `line`."""
    near = " ".join(lines[line - 1:line + 3]) if 0 < line <= len(lines) else ""
    hints = []
    if ".lineLimit(1)" in near:
        hints.append("one line")
    if "minimumScaleFactor" in near:
        hints.append("shrinks to fit")
    if any(word in near for word in ("Typeface.label(", ".caption2", "Capsule()", ".badge(")):
        hints.append("small label")
    if slot.startswith(("Button(", "Tab(", "Toggle(", ".badge(", "Label(")):
        hints.append("control label")
    if slot.startswith(("AppShortcut(shortTitle", ".configurationDisplayName", "ControlWidget")):
        hints.append("system UI label")
    return hints


def max_length_for(source: str, hints: list):
    if not hints or not any(h in ("one line", "shrinks to fit", "small label", "control label", "system UI label")
                            for h in hints):
        return None
    plain = SPEC.sub("00", source)
    if len(plain) > 60:
        return None
    return max(len(plain) + 6, math.ceil(len(plain) * 1.5))


def comment_above(lines: list, line: int) -> str:
    """The // comment lines right above `line`, joined."""
    out = []
    k = line - 2
    while k >= 0 and len(out) < 4:
        text = lines[k].strip()
        if text.startswith("// MARK") or text.startswith("//MARK"):
            break
        if text.startswith("//"):
            out.insert(0, text.lstrip("/ ").strip())
            k -= 1
        else:
            break
    trailing = re.search(r"//\s*(.+)$", lines[line - 1]) if 0 < line <= len(lines) else None
    if trailing and '"' not in trailing.group(1):
        out.append(trailing.group(1).strip())
    return " ".join(out)


def legacy_references() -> dict:
    """Where each timbre_* key is used: the Swift sources and the bundled catalogue JSON."""
    found = {}
    files = [p for folder in CODE + DECLS for p in sorted((ROOT / folder).rglob("*.swift"))]
    files += sorted((ROOT / "ios/Sources/TimbreCore/Resources").glob("*.json"))
    for path in files:
        for number, text in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for key in re.findall(r"\btimbre_\w+", text):
                found.setdefault(key, f"{path.relative_to(ROOT)}:{number}")
    return found


def info_plist_strings() -> dict:
    """The Timbre target's localizable Info.plist values (ios/project.yml)."""
    out = {}
    text = (ROOT / "ios/project.yml").read_text(encoding="utf-8")
    block = text.split("\n  Timbre:\n", 1)[-1].split("\n  TimbreWidgets:\n", 1)[0]
    for line in block.splitlines():
        m = INFO_KEYS.match(line)
        if m:
            out[m.group(1)] = m.group(2).strip().strip('"')
    return out


def xliff_keys(path: Path) -> dict:
    """{table: {key: note}} from an Xcode export."""
    ns = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
    out = {}
    for file in ET.parse(path).getroot().findall("x:file", ns):
        table = Path(file.get("original")).name
        if not file.get("original", "").startswith("Timbre/"):
            continue
        for unit in file.findall(".//x:trans-unit", ns):
            note = unit.find("x:note", ns)
            text = (note.text or "") if note is not None else ""
            out.setdefault(table, {})[unit.get("id")] = "" if text == "No comment provided by engineer." else text
    return out


def ui_english(all_locale_keys: set, xliff: Path | None) -> tuple[dict, list, set]:
    """{(table, key): item} for the UI tables; the interpolated literals' patterns and every key-like text in the
    code, untranslatable ones included (so neither counts as stale)."""
    items = {}
    en_strings = read_strings(RES / "en.lproj/Localizable.strings")
    en_dict = read_stringsdict(RES / "en.lproj/Localizable.stringsdict")
    exported = xliff_keys(xliff) if xliff else {}
    known = set(all_locale_keys) | set(en_strings) | set(en_dict) | set(exported.get("Localizable.strings", {}))
    literals, lexers = swiftstrings.scan(ROOT, [f for f in CODE + DECLS if (ROOT / f).exists()])
    lines_of = {rel: lexer.s.splitlines() for rel, lexer in lexers.items()}
    patterns = []

    def add(table, key, source, where, slot="", lines=None, line=0, note="", check=False):
        if table == "Localizable.strings" and key in en_dict:
            table = "Localizable.stringsdict"
        item = items.get((table, key))
        if item is None:
            hints = tightness(lines, line, slot) if lines else []
            item = {"table": table, "key": key, "source": source, "where": [], "context": note,
                    "max_length": max_length_for(source, hints), "hints": hints}
            if check:
                item["key_check"] = ("the interpolation types in this key are inferred: confirm it with an Xcode "
                                     "export (l10n.yml) before applying")
            items[(table, key)] = item
        if where and where not in item["where"] and len(item["where"]) < 2:
            item["where"].append(where)
        if not item["context"] and note:
            item["context"] = note

    plain = [lit for lit in literals if not lit.table]
    literals = [lit for lit in literals if lit.table]
    seen = {lit.key for lit in literals} | {lit.key for lit in plain}
    for lit in literals:
        lines = lines_of.get(lit.file, [])
        note = comment_above(lines, lit.line)
        where = f"{lit.file}:{lit.line}"
        key, check = lit.key, lit.guessed
        if lit.table == "Localizable.strings" and any(isinstance(p, swiftstrings.Interp) for p in lit.parts):
            pattern = literal_pattern(lit.parts)
            patterns.append(pattern)
            matches = sorted(k for k in known if pattern.match(k))
            if lit.key in matches:
                check = False
            elif len(matches) == 1:
                key, check = matches[0], False
            elif matches:
                key, check = max(matches, key=lambda k: (k in exported.get("Localizable.strings", {}),
                                                         k in all_locale_keys, k)), False
        seen.add(key)
        if not translatable(key):
            continue
        if lit.table == "Localizable.strings" and key in en_strings:
            add("Localizable.strings", key, en_strings[key], where, lit.slot, lines, lit.line, note)
            continue
        source = key
        if key in en_dict:
            source = plural_source(en_dict[key])
        add(lit.table, key, source, where, lit.slot, lines, lit.line, note, check)
    # Text shown through a dynamic lookup (badge and level names, ear-training answers in TimbreCore): a plain literal
    # anywhere in the code that the tables already hold as a key stays in the English.
    for lit in plain:
        key = lit.key
        if key in all_locale_keys and translatable(key) and ("Localizable.strings", key) not in items \
                and ("Localizable.stringsdict", key) not in items and key not in en_strings:
            lines = lines_of.get(lit.file, [])
            add("Localizable.strings", key, key, f"{lit.file}:{lit.line}",
                note=comment_above(lines, lit.line) or "shown through a lookup (LocalizedStringKey of a value)")
    # Keys Xcode's export saw that the scanner didn't (only with --xliff).
    for table, units in exported.items():
        if table not in ("Localizable.strings", "AppShortcuts.strings"):
            continue
        for key, note in units.items():
            if translatable(key) and (table, key) not in items and key not in en_strings \
                    and ("Localizable.stringsdict", key) not in items:
                add(table, key, key, "", note=note or "found by Xcode's export")
    # The timbre_* keys: English is the value.
    refs = legacy_references()
    for key, value in en_strings.items():
        if ("Localizable.strings", key) not in items and translatable(value):
            add("Localizable.strings", key, value, refs.get(key, ""), note="")
    for key, entry in en_dict.items():
        if ("Localizable.stringsdict", key) not in items:
            add("Localizable.stringsdict", key, plural_source(entry), "", note="")
    for key, value in info_plist_strings().items():
        note = {"CFBundleDisplayName": "The app's name under its icon (keep the brand name).",
                "NSMicrophoneUsageDescription": "The system's microphone permission prompt.",
                "NSAppleMusicUsageDescription": "The system's Apple Music permission prompt."}.get(
            key, "A system permission prompt.")
        add("InfoPlist.strings", key, value, "ios/project.yml", note=note)
    order = {t: n for n, t in enumerate(UI_TABLES)}

    def place(item):
        """What a new user meets first comes first: permission prompts, onboarding, the paywall, the tuner …"""
        where = item["where"][0] if item["where"] else ""
        path, _, line = where.partition(":")
        first = next((n for n, prefix in enumerate(FIRST_SEEN) if path.startswith(prefix)), len(FIRST_SEEN))
        return (order.get(item["table"], 9), first, path, int(line) if line.isdigit() else 0, item["key"])
    items = {(i["table"], i["key"]): i for i in sorted(items.values(), key=place)}
    for item in items.values():
        if item["table"] == "Localizable.stringsdict":
            item["context"] = ("Plural. Give every plural form your language uses (zero, one, two, few, many, "
                               "other) as a JSON object, e.g. {\"one\": \"…\", \"other\": \"…\"}. " + item["context"]).strip()
    return items, patterns, seen


# ------------------------------------------------------------------------------------------- English (Learn)

def learn_limits() -> dict:
    source = (ROOT / "tools/curriculum/build.py").read_text(encoding="utf-8")
    m = re.search(r"^LIMITS = (\{.*?\})$", source, re.M)
    return ast.literal_eval(m.group(1)) if m else {}


def learn_english() -> dict:
    """{key: item} for Learn.strings, in curriculum order, with where each string sits in the course."""
    english = {k: v for k, v in read_strings(RES / "en.lproj/Learn.strings").items()}
    limits = learn_limits()
    limits.setdefault("option", limits.get("options"))
    order = {}
    course_data = json.loads(CURRICULUM.read_text(encoding="utf-8")) if CURRICULUM.exists() else {"courses": []}

    def visit(value, place, field=None):
        if isinstance(value, dict):
            if set(value) == {"k", "t"}:
                if value["k"] not in order:
                    order[value["k"]] = (len(order), place, field)
                return
            for name, inner in value.items():
                visit(inner, place, name)
        elif isinstance(value, list):
            for inner in value:
                visit(inner, place, field)

    for course in course_data["courses"]:
        cname = course["title"]["t"] if isinstance(course.get("title"), dict) else course["id"]
        visit({"title": course["title"], "subtitle": course.get("subtitle")}, f"{cname} course")
        for number, unit in enumerate(course["units"], 1):
            utitle = unit["title"]["t"]
            visit({"title": unit["title"], "summary": unit.get("summary")}, f"{cname} · Unit {number} “{utitle}”")
            for lesson in unit["lessons"]:
                ltitle = lesson["title"]["t"]
                base = f"{cname} · Unit {number} · {lesson['kind']} {lesson['id']} “{ltitle}”"
                visit({"title": lesson["title"]}, base)
                for index, step in enumerate(lesson.get("steps", []), 1):
                    visit(step, f"{base} · step {index} ({step.get('type', '')})")
                rest = {k: v for k, v in lesson.items() if k not in ("title", "steps")}
                visit(rest, f"{base} · arrangement")
    items = {}
    unplaced = len(order)
    for key, text in english.items():
        position, place, field = order.get(key, (unplaced, "", ""))
        singular = {"options": "option"}.get(field, field)
        role = {"name": "song section label (Intro, Verse 1 …) on a small chip",
                "words": "lyric credit (a name and year: usually keep as is)",
                "options": "quiz answer", "why": "explanation after a quiz answer", "hint": "hint under an exercise",
                "prompt": "question or instruction", "body": "lesson card text", "title": "title",
                "summary": "unit summary", "subtitle": "course subtitle"}.get(field, field or "")
        limit = limits.get(singular)
        if field == "name":
            limit = max(12, math.ceil(len(text) * 1.5))
        items[key] = {"table": LEARN, "key": key, "source": text,
                      "context": f"{place} · {role}".strip(" ·"), "max_length": limit, "order": position}
    return dict(sorted(items.items(), key=lambda kv: (kv[1]["order"], kv[0])))


def learn_history(english: dict, stale_keys: set) -> dict:
    """Old English for lesson keys that left en.lproj/Learn.strings (so a changed sentence can reuse its old
    translation). Kept in tools/l10n/source/learn-history.json; refreshed from git history when it is there."""
    history = json.loads(HISTORY.read_text(encoding="utf-8")) if HISTORY.exists() else {}
    wanted = {k for k in stale_keys if k not in history}
    if wanted:
        try:
            revs = subprocess.run(["git", "log", "--format=%H", "--", "ios/Timbre/Resources/en.lproj/Learn.strings"],
                                  cwd=ROOT, capture_output=True, text=True, timeout=30).stdout.split()
            for rev in revs[:200]:
                if not wanted:
                    break
                old = subprocess.run(["git", "show", f"{rev}:ios/Timbre/Resources/en.lproj/Learn.strings"],
                                     cwd=ROOT, capture_output=True, text=True, timeout=30).stdout
                for key, value in re.findall(r'^"(L[0-9a-f]+)" = "((?:[^"\\]|\\.)*)";$', old, re.M):
                    if key in wanted:
                        history[key] = unescape(value)
                        wanted.discard(key)
        except (OSError, subprocess.SubprocessError):
            pass
    return {k: v for k, v in sorted(history.items()) if k in stale_keys and k not in english}


# --------------------------------------------------------------------------------------------- the report

def check(table: str, key: str, source: str, value, loc: str) -> list:
    """Why a translation can't ship (the same checks apply.py and apply_learn.py make), or []."""
    if table == "Localizable.stringsdict":
        if not isinstance(value, dict) or "other" not in value:
            return ["a plural needs a JSON object with at least an \"other\" form"]
        return [f"{form}: format arguments differ from the English" for form, text in value.items()
                if ui_apply.specs(source) != ui_apply.specs(str(text))]
    if not isinstance(value, str) or not value.strip():
        return ["empty"]
    if table == LEARN:
        return [("the numbers differ from the English" if p == "numbers" else
                 "the line breaks differ from the English" if p == "\n" else
                 f"the count of {p} differs from the English") for p in apply_learn.problems(source, value, loc)]
    if ui_apply.specs(key if table != "InfoPlist.strings" else source) != ui_apply.specs(value):
        return ["format arguments or ${…} tokens differ from the English"]
    return []


def similarity(new: str, old: str) -> float:
    """How likely `old` is an earlier wording of `new` (0 when not): close as text, or sharing most of its words."""
    a, b = new.casefold(), old.casefold()
    if a == b:
        return 1.0
    if abs(len(a) - len(b)) > max(len(a), len(b)) * 0.6:
        return 0.0
    matcher = difflib.SequenceMatcher(None, a, b, autojunk=False)
    if matcher.real_quick_ratio() < 0.6 or matcher.quick_ratio() < 0.6:
        return 0.0
    char = matcher.ratio()
    if char >= 0.85:
        return char
    words_a, words_b = re.findall(r"%\S+|\w+", a), re.findall(r"%\S+|\w+", b)
    word = difflib.SequenceMatcher(None, words_a, words_b, autojunk=False).ratio()
    shared = {w for w in set(words_a) & set(words_b) if len(w) >= 3}
    if word >= 0.6 and len(shared) >= 2 and char >= 0.6:
        return (char + word) / 2
    return 0.0


def best_previous(source: str, candidates) -> list:
    """Stale English variants close to `source`, best first: [(score, old English)]."""
    scored = [(similarity(source, old), old) for old in candidates]
    return sorted(((score, old) for score, old in scored if score > 0), key=lambda pair: (-pair[0], pair[1]))


def clean(item: dict) -> dict:
    out = {"table": item["table"], "key": item["key"], "source": item["source"]}
    if item.get("context"):
        out["context"] = item["context"]
    if item.get("where"):
        out["where"] = item["where"]
    if item.get("hints"):
        out["layout"] = ", ".join(item["hints"])
    if item.get("max_length"):
        out["max_length"] = item["max_length"]
    if item.get("key_check"):
        out["key_check"] = item["key_check"]
    return out


def build(xliff: Path | None = None, launch: bool = False) -> dict:
    """Everything the handoff needs, computed from the repository; with `launch`, the launch-critical entries are
    tagged and listed first (`mark_launch`)."""
    locs, lesson_locs = locales(), lesson_locales()
    tables = {loc: {t: read_strings(RES / f"{loc}.lproj/{t}") for t in ("Localizable.strings", "AppShortcuts.strings",
                                                                      "InfoPlist.strings", LEARN)} for loc in locs}
    dicts = {loc: read_stringsdict(RES / f"{loc}.lproj/Localizable.stringsdict") for loc in locs}
    delivered = {}
    for loc in locs:
        path = HERE / "translations" / f"{loc}.json"
        delivered[loc] = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        learn_path = HERE / "learn" / f"{loc}.json"
        delivered[loc][LEARN] = json.loads(learn_path.read_text(encoding="utf-8")) if learn_path.exists() else {}
    all_keys = set()
    for loc in locs:
        all_keys |= set(tables[loc]["Localizable.strings"]) | set(dicts[loc])
        all_keys |= set(delivered[loc].get("Localizable.strings", {}))
    ui, patterns, seen = ui_english(all_keys, xliff)
    learn = learn_english()

    # Stale: keys a locale holds that the English no longer has (an edited or removed string).
    english_ui = {(t, k) for t, k in ui}
    stale = {}
    for loc in locs:
        rows = []
        for table in ("Localizable.strings", "AppShortcuts.strings", "InfoPlist.strings"):
            for key, value in tables[loc][table].items():
                if (table, key) in english_ui or key in seen or (table == "Localizable.strings" and (
                        ("Localizable.stringsdict", key) in english_ui or any(p.match(key) for p in patterns))):
                    continue
                if table == "InfoPlist.strings" and key == "CFBundleName":
                    continue
                rows.append({"table": table, "key": key, "translation": value})
        for key in dicts[loc]:
            if ("Localizable.stringsdict", key) not in english_ui:
                rows.append({"table": "Localizable.stringsdict", "key": key, "translation": ""})
        if loc in lesson_locs:
            for key, value in delivered[loc][LEARN].items():
                if key not in learn:
                    rows.append({"table": LEARN, "key": key, "translation": value})
        stale[loc] = rows
    stale_learn_keys = {r["key"] for rows in stale.values() for r in rows if r["table"] == LEARN}
    history = learn_history(learn, stale_learn_keys)

    # Candidate earlier versions of each missing string (English edited: the old translation may be reused).
    stale_ui_sources = {}
    for loc in locs:
        for row in stale[loc]:
            if row["table"] in ("Localizable.strings", "AppShortcuts.strings"):
                stale_ui_sources.setdefault(row["key"], set()).add(loc)
    stale_learn_sources = {text: key for key, text in history.items()}

    report = {"locales": {}, "lesson_locales": lesson_locs, "ui_total": len(ui), "learn_total": len(learn),
              "history": history}
    previous_cache = {}
    for loc in locs:
        todo, awaiting = [], []
        wanted = list(ui.values()) + (list(learn.values()) if loc in lesson_locs else [])
        for item in wanted:
            table, key = item["table"], item["key"]
            if table == "Localizable.stringsdict":
                have = key in dicts[loc]
            elif table == "Localizable.strings":
                have = key in tables[loc][table] or key in dicts[loc]
            else:
                have = key in tables[loc][table]
            if have:
                continue
            entry = clean(item)
            entry["status"] = "new"
            given = delivered[loc].get(table, {}).get(key) if table != "Localizable.stringsdict" else None
            if isinstance(given, str) and given.strip():
                problems = check(table, key, item["source"], given, loc)
                if not problems:
                    awaiting.append({"table": table, "key": key})
                    continue
                entry["status"] = "rejected"
                entry["problem"] = ", ".join(problems)
                entry["previous"] = {"translation": given}
            elif table in ("Localizable.strings", "AppShortcuts.strings", LEARN):
                cache_key = (table, item["source"])
                if cache_key not in previous_cache:
                    pool = stale_learn_sources if table == LEARN else stale_ui_sources
                    previous_cache[cache_key] = best_previous(item["source"], pool)
                for ratio, old in previous_cache[cache_key]:
                    if table == LEARN:
                        old_key = stale_learn_sources[old]
                        translation = delivered[loc][LEARN].get(old_key)
                    else:
                        translation = tables[loc]["Localizable.strings"].get(old) or tables[loc]["AppShortcuts.strings"].get(old)
                    if translation:
                        entry["status"] = "changed"
                        entry["previous"] = {"source": old, "translation": translation}
                        break
            todo.append(entry)
        report["locales"][loc] = {"todo": todo, "awaiting_apply": awaiting, "stale": stale[loc]}
    if launch:
        mark_launch(report)
    return report


def mark_launch(report: dict) -> None:
    """Tags each launch-critical TODO entry with its kind (`launch`) and moves those entries to the front of every
    locale's list, in LAUNCH order; the rest keep their order (the order a new user meets them)."""
    import critical  # imported here: critical.py imports this module

    classifier = critical.Classifier()
    kinds: dict = {}
    for entry in report["locales"].values():
        for item in entry["todo"]:
            if item["table"] == LEARN:
                continue
            ident = (item["table"], item["key"])
            if ident not in kinds:
                found = classifier.categories(item)
                if not found and any(w.startswith(FUNNEL) for w in item.get("where", [])):
                    found = {"funnel"}
                kinds[ident] = next((kind for kind in LAUNCH if kind in found), None)
            if kinds[ident]:
                item["launch"] = kinds[ident]
        rank = {kind: n for n, kind in enumerate(LAUNCH)}
        entry["todo"].sort(key=lambda item: rank.get(item.get("launch"), len(LAUNCH)))


# ---------------------------------------------------------------------------------------------- rendering

def counts(entry: dict) -> dict:
    out = {}
    for item in entry["todo"]:
        group = "lessons" if item["table"] == LEARN else "ui"
        out[group] = out.get(group, 0) + 1
    return out


def render_todo(loc: str, entry: dict, carried: dict) -> str:
    items = []
    for item in entry["todo"]:
        row = dict(item)
        value = carried.get((item["table"], item["key"]), "")
        if value:
            problems = check(item["table"], item["key"], item["source"], value, loc)
            if problems:  # typed in but not importable: say why, keep the text to fix
                row["status"] = "rejected"
                row["problem"] = ", ".join(problems)
        row["translation"] = value
        items.append(row)
    by_table = {}
    for item in entry["todo"]:
        by_table[item["table"]] = by_table.get(item["table"], 0) + 1
    head = {
        "locale": loc,
        "language": LANGUAGE_NAMES.get(loc, loc),
        "about": "Generated by tools/l10n/report.py: fill in the \"translation\" fields and change nothing else. "
                 "Brief: docs/l10n/HANDOFF.md.",
        "counts": dict(sorted(by_table.items())),
    }
    # One string per line: small files, and a delivered translation is a one-line diff.
    lines = [json.dumps(head, ensure_ascii=False, indent=1)[:-2] + ",", ' "strings": [']
    lines += ["  " + json.dumps(row, ensure_ascii=False) + ("," if n < len(items) - 1 else "") for n, row in enumerate(items)]
    lines += [" ]", "}"]
    return "\n".join(lines) + "\n"


def render_index(report: dict) -> str:
    rows = {}
    for loc, entry in report["locales"].items():
        by_table = {}
        for item in entry["todo"]:
            by_table[item["table"]] = by_table.get(item["table"], 0) + 1
        launch = {}
        for item in entry["todo"]:
            if item.get("launch"):
                launch[item["launch"]] = launch.get(item["launch"], 0) + 1
        rows[loc] = {"missing": dict(sorted(by_table.items())), "launch_critical": dict(sorted(launch.items())),
                     "changed": sum(1 for i in entry["todo"] if i["status"] == "changed"),
                     "rejected": sum(1 for i in entry["todo"] if i["status"] == "rejected"),
                     "awaiting_apply": len(entry["awaiting_apply"]), "stale": len(entry["stale"]),
                     "lessons": loc in report["lesson_locales"]}
    stale = {}
    for entry in report["locales"].values():
        for row in entry["stale"]:
            stale.setdefault(row["table"], set()).add(row["key"])
    doc = {"about": "Generated by tools/l10n/report.py. Per locale: strings still to translate, by table. "
                    "`stale`: keys some locale still holds whose English is no longer in the app (safe to drop).",
           "english": {"ui": report["ui_total"], "lessons": report["learn_total"]}, "locales": rows,
           "stale": {table: sorted(keys) for table, keys in sorted(stale.items())}}
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def render_pending(report: dict) -> str:
    seen = {}
    for entry in report["locales"].values():
        for item in entry["todo"]:
            if item["table"] == LEARN:
                continue
            row = seen.setdefault((item["table"], item["key"]), {
                "table": item["table"], "key": item["key"], "source": item["source"],
                "note": item.get("context", "") or ", ".join(item.get("where", [])), "locales": 0})
            row["locales"] += 1
    rows = sorted(seen.values(), key=lambda r: (r["table"], r["key"]))
    return json.dumps(rows, ensure_ascii=False, indent=1) + "\n"


def group_locales(report: dict) -> list:
    """[(ui missing, lesson missing, [locales])], locales with the same counts together."""
    groups = {}
    for loc, entry in report["locales"].items():
        c = counts(entry)
        groups.setdefault((c.get("ui", 0), c.get("lessons", 0)), []).append(loc)
    return sorted(((ui, les, locs) for (ui, les), locs in groups.items()), key=lambda g: (-g[1], -g[0], g[2]))


def lesson_breakdown(report: dict) -> list:
    """[(course, total, "unit 17 (52), unit 18 (57) …")] of the lesson strings missing in the first lesson locale."""
    if not report["lesson_locales"]:
        return []
    first = report["locales"][report["lesson_locales"][0]]["todo"]
    courses = {}
    for item in first:
        if item["table"] != LEARN:
            continue
        m = re.match(r"(.+?) · Unit (\d+)|(.+?) course", item.get("context", ""))
        course = (m.group(1) or m.group(3)) if m else "other"
        unit = f"unit {m.group(2)}" if m and m.group(2) else "course title"
        units = courses.setdefault(course, {})
        units[unit] = units.get(unit, 0) + 1
    return [(course, sum(units.values()), ", ".join(f"{u} ({n})" for u, n in units.items()))
            for course, units in courses.items()]


def render_launch(report: dict) -> list:
    """The handoff's first section: what the launch needs translated before anything else, with counts."""
    locs = report["locales"]
    names = {"legal": "Purchase terms (legal)", "permission": "Permission prompts", "voiceover": "VoiceOver",
             "funnel": "Onboarding, welcome to paywall"}
    strings: dict = {}
    pairs: dict = {}
    for entry in locs.values():
        for item in entry["todo"]:
            kind = item.get("launch")
            if kind:
                strings.setdefault(kind, set()).add((item["table"], item["key"]))
                pairs[kind] = pairs.get(kind, 0) + 1
    out = ["## Launch-critical first", ""]
    if not strings:
        return out + ["Every launch-critical string is translated in every locale.", ""]
    out += ["These come first in every TODO file (`launch` on the entry says which kind). The App Store upload refuses a "
            "build when a shipped language lacks a purchase term, a permission prompt or a VoiceOver string "
            "(`tools/l10n/critical.py --strict`), and the onboarding is the first thing a new user reads.", "",
            "| Kind | Strings | Locale-string pairs |", "|---|---:|---:|"]
    for kind in LAUNCH:
        if kind in strings:
            out.append(f"| {names[kind]} | {len(strings[kind])} | {pairs[kind]:,} |")
    total = len(set().union(*strings.values()))
    out += [f"| **All launch-critical** | **{total}** | **{sum(pairs.values()):,}** |", ""]
    return out


def render_handoff(report: dict) -> str:
    locs = report["locales"]
    total_ui = sum(counts(e).get("ui", 0) for e in locs.values())
    total_lessons = sum(counts(e).get("lessons", 0) for e in locs.values())
    ui_keys = {(i["table"], i["key"]) for e in locs.values() for i in e["todo"] if i["table"] != LEARN}
    changed = sum(1 for e in locs.values() for i in e["todo"] if i["status"] == "changed")
    rejected = sum(1 for e in locs.values() for i in e["todo"] if i["status"] == "rejected")
    awaiting = sum(len(e["awaiting_apply"]) for e in locs.values())
    stale = sum(len(e["stale"]) for e in locs.values())
    lesson_names = ", ".join(f"{LANGUAGE_NAMES.get(l, l)} ({l})" for l in report["lesson_locales"])
    out = []
    w = out.append
    w("# Timbre translation handoff")
    w("")
    w("<!-- Generated by tools/l10n/report.py. Edit the template in that script, not this file. -->")
    w("")
    w("This is the brief for whoever translates Timbre: people, or GPT run as described in "
      "[TRANSLATING-WITH-GPT.md](TRANSLATING-WITH-GPT.md) (with a terminology sheet from "
      "[GLOSSARY-TEMPLATE.md](GLOSSARY-TEMPLATE.md) and a human review of legal, permission and funnel text). "
      "The English is the source. Everything on this page and in the TODO files is generated from the code and the "
      "curriculum: the iOS workflow warns on every run while anything is missing, and fails when this page is out of "
      "date (see *For developers*). A string a locale lacks shows in English.")
    w("")
    out.extend(render_launch(report))
    w("## What is missing now")
    w("")
    w(f"- **App interface:** {len(ui_keys):,} distinct strings are missing somewhere, "
      f"{total_ui:,} locale-string pairs in all.")
    w(f"- **Lessons:** {total_lessons:,} locale-string pairs across the {len(report['lesson_locales'])} lesson "
      f"languages ({lesson_names}).")
    if changed:
        w(f"- **Changed English:** {changed:,} of these locale-string pairs replace a string whose English was edited. "
          f"The TODO entry carries the old English and its old translation under `previous`, to update rather than "
          f"start over.")
    if rejected:
        w(f"- **Rejected:** {rejected} delivered translations failed a check (format arguments, numbers or ♯/♭ "
          f"differ from the English). The entry says why under `problem`.")
    if awaiting:
        w(f"- **Delivered, not applied yet:** {awaiting} translations are in `tools/l10n/translations` or "
          f"`tools/l10n/learn` but not in the app's tables. A developer runs `python3 tools/l10n/report.py --import "
          f"tools/l10n/todo` (or the two apply scripts) to apply them.")
    w("")
    w("| Locales | App strings missing | Lesson strings missing |")
    w("|---|---:|---:|")
    for ui, lessons, group in group_locales(report):
        if not ui and not lessons:
            continue
        w(f"| {', '.join(group)} | {ui} | {lessons if group[0] in report['lesson_locales'] else '—'} |")
    done = [l for l, e in locs.items() if not e["todo"]]
    if done:
        w(f"| complete: {', '.join(done)} | 0 | 0 |")
    w("")
    breakdown = lesson_breakdown(report)
    if breakdown:
        w("Where the missing lesson strings are (the same in every lesson language):")
        w("")
        w("| Course | Strings | Where (strings) |")
        w("|---|---:|---|")
        for course, number, units in breakdown:
            w(f"| {course} | {number} | {units} |")
        w("")
    w("Lessons ship in the lesson languages only; the other locales show lessons in English by design. Interface "
      "strings ship in every locale.")
    w("")
    w("## What to translate")
    w("")
    w("One file per language: `tools/l10n/todo/<locale>.json` (for example `tools/l10n/todo/de.json`). Each line "
      "of `strings` is one string: the launch-critical ones first (above), then the rest in the order a new user "
      "meets them: permission prompts, onboarding, the paywall and the tuner, then the lessons in course order. "
      "Its fields:")
    w("")
    w("| Field | Meaning |")
    w("|---|---|")
    w("| `table` | Where it ships: `Localizable.strings` (app interface), `Learn.strings` (lessons), "
      "`AppShortcuts.strings` (Siri phrases), `InfoPlist.strings` (system permission prompts), "
      "`Localizable.stringsdict` (plurals). |")
    w("| `key` | The identifier. Never change it. For interface strings it is the English itself. |")
    w("| `source` | The English to translate. |")
    w("| `context` | Where the text appears and what it does (a code comment, or the course, unit, lesson and step). |")
    w("| `where` | The code location, for a developer answering a question. |")
    w("| `layout` | Present when the text sits somewhere tight: `one line`, `small label`, `control label`, "
      "`shrinks to fit`. |")
    w("| `max_length` | Aim for at most this many characters. For lessons it is the limit the English is written "
      "to; for interface strings it is a soft limit from the layout. Longer text shrinks or truncates. |")
    w("| `launch` | Present on launch-critical strings, which come first: `legal`, `permission`, `voiceover` or "
      "`funnel` (see *Launch-critical first*). |")
    w("| `status` | `new`; `changed` (the English was edited: start from `previous.translation`); `rejected` "
      "(a translation failed a check: `problem` says why, and the text is in `translation` or "
      "`previous.translation`). |")
    w("| `translation` | **Your text goes here.** Leave it empty to skip a string. |")
    w("")
    w("Rules the import checks (a translation that breaks one is kept out and listed again as `rejected`):")
    w("")
    w("- Keep every format argument: `%@`, `%lld`, `%d`, `%lf`, `%.1f` and their count and order. To reorder, use "
      "positional forms: `%2$@ … %1$lld`. Keep `%%` (a percent sign) as it is.")
    w("- Keep named tokens exactly: `${applicationName}`, `${instrument}`, `${key}`, `${bpm}`.")
    w("- Lessons: keep every number, `♯`, `♭` and line break (`\\n`) of the English. Note letters stay as in the "
      "English, except that German lessons write H for B natural and B for B flat (a German `B♭` becomes `B`; the "
      "check knows this).")
    w("- Keep the brand names Timbre and Timbre Pro, game names the English capitalizes (Bullseye), and song "
      "titles that are names. Lyric credits (a name and a year) are usually kept as they are.")
    w("- Voice: warm, direct, second person. Match the register the app already uses in your language (see its "
      "`Localizable.strings`) and keep it consistent. No exclamation marks or emoji the English doesn't have.")
    w("- Plurals (`Localizable.stringsdict`): put a JSON object in `translation` with the forms your language "
      "uses, e.g. `{\"one\": \"%lld Minute\", \"other\": \"%lld Minuten\"}`.")
    w("")
    w("Reuse what is already translated: the app's current tables are in `ios/Timbre/Resources/<locale>.lproj/` "
      "(`Localizable.strings`, `Learn.strings`), and the delivered lesson translations in `tools/l10n/learn/<locale>.json`.")
    w("")
    w("## How to deliver")
    w("")
    w("1. Fill the `translation` fields of `tools/l10n/todo/<locale>.json`. Partial files are fine.")
    w("2. Send the file back (or commit it on a branch). Keep the file name and the JSON structure.")
    w("3. A developer imports it (below). Anything rejected comes back in the next TODO file with the reason.")
    w("")
    w("Formats used in the repository, for reference:")
    w("")
    w("- `tools/l10n/translations/<locale>.json`: `{\"Localizable.strings\": {\"English key\": \"translation\"}, "
      "\"AppShortcuts.strings\": {…}, \"InfoPlist.strings\": {…}}`, the interface translations `apply.py` merges.")
    w("- `tools/l10n/learn/<locale>.json`: `{\"L0a1b2c3d4e\": \"translation\"}`, the lesson translations "
      "`apply_learn.py` writes. Lesson keys are a hash of the English, so an edited sentence gets a new key.")
    w("")
    w("## For developers")
    w("")
    w("```sh")
    w("python3 tools/l10n/report.py                      # regenerate the TODO files, pending.json and this page")
    w("python3 tools/l10n/report.py --import tools/l10n/todo   # merge filled TODO files, apply, regenerate")
    w("python3 tools/l10n/report.py --check --strict     # what CI runs: fails when this page is out of date")
    w("python3 tools/l10n/critical.py --baseline         # what CI runs: fails on a new untranslated critical string")
    w("python3 tools/l10n/shipping.py                    # coverage per locale, and the languages that ship")
    w("```")
    w("")
    w("`--import DIR` reads every `<locale>.json` in DIR (the TODO format), checks each translation, merges the good "
      "ones into `tools/l10n/translations/<locale>.json` and `tools/l10n/learn/<locale>.json`, then runs the two "
      "apply scripts and regenerates the handoff. By hand, the apply steps are:")
    w("")
    w("```sh")
    w("python3 tools/l10n/apply.py tools/l10n/translations   # interface tables, every locale")
    w("python3 tools/l10n/apply_learn.py                     # lesson tables, the lesson languages")
    w("```")
    w("")
    w("Run `report.py` after adding or editing English (a new `Text(\"…\")`, a curriculum change) and commit "
      "`tools/l10n/todo`, `tools/l10n/pending.json`, `tools/l10n/source` and this page with the change. The core job "
      "of the iOS workflow (`.github/workflows/ios.yml`) runs `report.py --check --strict` on every run: it prints a "
      "warning annotation with the per-locale counts, adds the table to the job summary, publishes fresh TODO files "
      "with the core results (branch `ci-results/core`, folder `l10n`), and fails when the committed handoff is out "
      "of date.")
    w("")
    w("The same job runs `critical.py --baseline`: a legal, permission or VoiceOver string that a shipped locale lacks "
      "and that `tools/l10n/critical-baseline.json` doesn't list fails it. Deliver the translations, or record the gap "
      "with `python3 tools/l10n/critical.py --write-baseline` (the diff shows the reviewer which English goes out). "
      "The App Store upload (`apple-delivery.yml`) allows no gap at all; only an internal TestFlight build, which "
      "can't be submitted for review, may skip that check.")
    w("")
    w("Which languages ship is the owner's decision: `CFBundleLocalizations` in `ios/project.yml`, every `.lproj` "
      "today. `python3 tools/l10n/shipping.py --min 95 --apply` ships only the locales with at least 95 % of the "
      "interface translated (add `--critical` to also require every launch-critical string), and `--all --apply` "
      "ships every one again. The translations stay in the repository either way. The delivery workflow's "
      "`ship_min_coverage` input applies a bar to one upload without committing it.")
    w("")
    w("Interface strings are found by `tools/l10n/swiftstrings.py`, a scanner that reads Swift without Xcode. "
      "It infers the type of each interpolation (`%lld` for Int, `%@` for text); when a new string's key carries "
      "`key_check`, the inferred specifier is a guess. Confirm it with Xcode's export: run the *Localization export* "
      "workflow (`l10n.yml`) and pass its `en.xliff` with `--xliff`.")
    w("")
    if stale:
        keys = len({(r["table"], r["key"]) for e in locs.values() for r in e["stale"]})
        w(f"Stale entries: {keys:,} keys that some locale still holds have no English in the app any more ({stale:,} "
          f"locale-key pairs; the keys are listed under `stale` in `tools/l10n/todo/index.json`). They are harmless, "
          f"and they are where `changed` entries find their old translations.")
        w("")
    return "\n".join(out)


def outputs(report: dict, carried_by_loc: dict) -> dict:
    """{path: content} for every generated file."""
    files = {}
    for loc, entry in report["locales"].items():
        if entry["todo"]:
            files[TODO / f"{loc}.json"] = render_todo(loc, entry, carried_by_loc.get(loc, {}))
    files[TODO / "index.json"] = render_index(report)
    files[PENDING] = render_pending(report)
    files[HANDOFF] = render_handoff(report)
    if report["history"]:
        files[HISTORY] = json.dumps(report["history"], ensure_ascii=False, indent=1) + "\n"
    return files


def carried_translations(folder: Path) -> dict:
    """Translations already typed into TODO files, so regenerating never loses them."""
    out = {}
    for path in sorted(folder.glob("*.json")):
        if path.name == "index.json":
            continue
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for item in doc.get("strings", []) if isinstance(doc, dict) else []:
            value = item.get("translation")
            if value:
                out.setdefault(doc.get("locale", path.stem), {})[(item.get("table"), item.get("key"))] = value
    return out


def write(files: dict, stale_todo: list) -> int:
    changed = 0
    for path, content in files.items():
        if path.exists() and path.read_text(encoding="utf-8") == content:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        changed += 1
    for path in stale_todo:
        path.unlink()
        changed += 1
    return changed


# ------------------------------------------------------------------------------------------------- import

def import_todo(folder: Path) -> None:
    """Merges filled TODO files into tools/l10n/translations and tools/l10n/learn."""
    merged = rejected = 0
    for path in sorted(folder.glob("*.json")):
        if path.name == "index.json":
            continue
        doc = json.loads(path.read_text(encoding="utf-8"))
        loc = doc.get("locale", path.stem)
        ui_path, learn_path = HERE / "translations" / f"{loc}.json", HERE / "learn" / f"{loc}.json"
        ui_doc = json.loads(ui_path.read_text(encoding="utf-8")) if ui_path.exists() else {}
        learn_doc = json.loads(learn_path.read_text(encoding="utf-8")) if learn_path.exists() else {}
        for item in doc.get("strings", []):
            value, table, key = item.get("translation"), item.get("table"), item.get("key")
            if not value:
                continue
            problems = check(table, key, item.get("source", ""), value, loc)
            if problems:
                print(f"{loc} {table} {key!r}: {', '.join(problems)}: not imported")
                rejected += 1
                continue
            if table == "Localizable.stringsdict":
                print(f"{loc}: plural {key!r}: add it to {loc}.lproj/Localizable.stringsdict by hand: {value!r}")
                continue
            if table == LEARN:
                learn_doc[key] = value
            else:
                ui_doc.setdefault(table, {})[key] = value
            merged += 1
        if ui_doc:
            ui_path.write_text(json.dumps(ui_doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        if learn_doc and (loc in lesson_locales() or learn_path.exists()):
            learn_path.write_text(json.dumps(dict(sorted(learn_doc.items())), ensure_ascii=False, indent=1) + "\n",
                                  encoding="utf-8")
    print(f"imported {merged} translations, rejected {rejected}")
    subprocess.run([sys.executable, str(HERE / "apply.py"), str(HERE / "translations")], check=True)
    subprocess.run([sys.executable, str(HERE / "apply_learn.py")], check=True)


# ---------------------------------------------------------------------------------------------------- main

def annotate(report: dict, files: dict, stale_todo: list, strict: bool = False) -> list:
    """GitHub annotations and a job summary (CI); returns the generated files that differ from the committed ones."""
    parts = []
    for ui, lessons, group in group_locales(report):
        if not ui and not lessons:
            continue
        label = group[0] if len(group) == 1 else f"{len(group)} locales ({', '.join(group)})"
        text = f"{label}: {ui} app"
        if group[0] in report["lesson_locales"]:
            text += f" + {lessons} lesson"
        parts.append(text)
    if parts:
        print("::warning title=Untranslated strings::" + "; ".join(parts)
              + ". Translators' TODO: tools/l10n/todo/<locale>.json, brief: docs/l10n/HANDOFF.md.")
    # A string's source line ("where": "File.swift:123") moves with every edit above it; the handoff is out of date
    # only when what translators need changed (a key, a source text, a file, a note), not when a line number did.
    def unlined(text: str) -> str:
        return re.sub(r'(\.(?:swift|yml|py|json|plist)):\d+', r'\1', text)
    outdated = [str(p.relative_to(ROOT)) for p, c in files.items()
                if not p.exists() or unlined(p.read_text(encoding="utf-8")) != unlined(c)]
    outdated += [str(p.relative_to(ROOT)) for p in stale_todo]
    if outdated:
        print(f"::{'error' if strict else 'warning'} title=Translation handoff out of date::Run "
              "python3 tools/l10n/report.py and commit " + ", ".join(sorted(outdated)[:6]) + (" …" if len(outdated) > 6 else ""))
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        lines = ["## Translations", "", "| Locales | App strings missing | Lesson strings missing |", "|---|---:|---:|"]
        for ui, lessons, group in group_locales(report):
            lines.append(f"| {', '.join(group)} | {ui} | {lessons if group[0] in report['lesson_locales'] else '—'} |")
        lines += ["", "Brief: docs/l10n/HANDOFF.md. " + ("The committed handoff is out of date." if outdated else "")]
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    return outdated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="CI: print warnings, write nothing in the repository")
    parser.add_argument("--strict", action="store_true", help="with --check: exit 1 when the handoff is out of date")
    parser.add_argument("--out", type=Path, help="with --check: also write the generated files under this folder")
    parser.add_argument("--import", dest="import_dir", type=Path, help="merge filled TODO files from this folder")
    parser.add_argument("--xliff", type=Path, help="an en.xliff from Xcode's export, to settle code keys")
    args = parser.parse_args()
    if args.import_dir:
        import_todo(args.import_dir)
    report = build(args.xliff, launch=True)
    carried = carried_translations(TODO)
    files = outputs(report, carried)
    stale_todo = [p for p in sorted(TODO.glob("*.json")) if p not in files] if TODO.exists() else []
    if args.check:
        outdated = annotate(report, files, stale_todo, strict=args.strict)
        if args.out:
            for path, content in files.items():
                target = args.out / path.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content, encoding="utf-8")
        if outdated and args.strict:
            print(f"FAILED: the committed handoff is out of date ({len(outdated)} files). Run "
                  f"python3 tools/l10n/report.py and commit the result.")
            for path in sorted(outdated)[:20]:
                print("    " + path)
            return 1
        return 0
    changed = write(files, stale_todo)
    for ui, lessons, group in group_locales(report):
        lesson_text = f"{lessons} lesson strings" if group[0] in report["lesson_locales"] else "lessons in English by design"
        print(f"{', '.join(group)}: {ui} app strings missing; {lesson_text}")
    print(f"{changed} files updated" if changed else "handoff up to date")
    return 0


if __name__ == "__main__":
    if "--check" in sys.argv and "--strict" not in sys.argv:
        try:
            sys.exit(main())
        except Exception as error:  # noqa: BLE001 - a report-only run never fails CI
            print(f"::warning title=Translation report failed::{type(error).__name__}: {error}")
            sys.exit(0)
    sys.exit(main())
