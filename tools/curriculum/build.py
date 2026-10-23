#!/usr/bin/env python3
"""Build Timbre's Learn curriculum.

python3 tools/curriculum/build.py            # validate and write
python3 tools/curriculum/build.py --check    # validate only
python3 tools/curriculum/build.py --check --only ear,theory   # validate some courses

Reads every course module listed in COURSES (tools/curriculum/courses/<name>.py, each
defining COURSE = course(...)), validates it, assigns string keys, and writes
ios/Sources/TimbreCore/Resources/curriculum.json and the English
ios/Timbre/Resources/en.lproj/Learn.strings. Text keys are a hash of the English text,
so the same sentence is translated once and edits only invalidate what changed.
"""
from __future__ import annotations

import hashlib
import importlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from lib import TUNINGS, Text, fretted, name  # noqa: E402

COURSES = ["guitar", "ukulele", "bass", "violin", "cello", "mandolin", "banjo", "ear", "theory", "rhythm", "voice", "songs"]
LIMITS = {"title": 42, "body": 300, "prompt": 140, "option": 48, "hint": 120, "why": 220, "summary": 120, "subtitle": 80}
RANGES = {"guitar": (40, 88), "ukulele": (60, 81), "bass": (28, 67), "violin": (55, 93), "cello": (36, 76),
          "mandolin": (55, 88), "banjo": (50, 79), None: (36, 96)}

strings: dict[str, str] = {}
errors: list[str] = []


def key_for(text: str) -> str:
    return "L" + hashlib.sha1(text.encode("utf-8")).hexdigest()[:10]


def encode(value, where: str, field: str = ""):
    """Replaces Text objects with {"k", "t"} and checks their length."""
    if isinstance(value, Text):
        limit = LIMITS.get(field)
        if limit and len(value.text) > limit:
            errors.append(f"{where}: {field} longer than {limit}: {value.text!r}")
        if not value.text:
            errors.append(f"{where}: empty {field}")
        key = key_for(value.text)
        strings[key] = value.text
        return {"k": key, "t": value.text}
    if isinstance(value, dict):
        return {k: encode(v, where, k) for k, v in value.items()}
    if isinstance(value, list):
        singular = {"options": "option"}.get(field, field)
        return [encode(v, where, singular) for v in value]
    return value


def instrument_kind(course: dict) -> str | None:
    inst = course.get("instrument") or ""
    return next((kind for kind in TUNINGS if inst.startswith(kind)), None)


def check_note(n: dict, kind: str | None, where: str):
    lo, hi = RANGES.get(kind, RANGES[None])
    if not lo <= n["m"] <= hi:
        errors.append(f"{where}: {name(n['m'])} out of range for {kind or 'this course'}")
    at = n.get("at")
    if at and kind:
        if not 1 <= at["s"] <= len(TUNINGS[kind]):
            errors.append(f"{where}: string {at['s']} doesn't exist")
        elif fretted(kind, at["s"], at["f"]) != n["m"]:
            errors.append(f"{where}: string {at['s']} fret {at['f']} is {name(fretted(kind, at['s'], at['f']))}, not {name(n['m'])}")


def check_lesson(lesson: dict, kind: str | None, where: str):
    steps = lesson["steps"]
    if not 3 <= len(steps) <= 16:
        errors.append(f"{where}: {len(steps)} steps (3–16)")
    if all(s["type"] == "explain" for s in steps):
        errors.append(f"{where}: nothing to play or answer")
    for i, step in enumerate(steps):
        at = f"{where} step {i + 1} ({step['type']})"
        t = step["type"]
        if t in ("notes", "along"):
            if not step["notes"]:
                errors.append(f"{at}: no notes")
            for n in step["notes"]:
                check_note(n, kind, at)
            if t == "along" and not 30 <= step["bpm"] <= 220:
                errors.append(f"{at}: bpm {step['bpm']}")
        if t in ("quiz", "listen"):
            if not 2 <= len(step["options"]) <= 4 or not 0 <= step["answer"] < len(step["options"]):
                errors.append(f"{at}: answer/options")
            texts = [o.text for o in step["options"]]
            if len(set(texts)) != len(texts):
                errors.append(f"{at}: duplicate options")
        if t == "listen" and not all(step["sound"]):
            errors.append(f"{at}: empty sound")
        if t == "progression" and (not step["chords"] or len(step["chords"]) != len(step["bars"]) or any(n < 1 for n in step["bars"])):
            errors.append(f"{at}: chords and bars")
        if t in ("strum", "tap", "progression"):
            bar = step.get("beatsPerBar") or max(4, int(max(step["pattern"] or [0])) + 1)
            if not step["pattern"] or any(not 0 <= b < bar for b in step["pattern"]) or not 2 <= bar <= 12:
                errors.append(f"{at}: pattern outside its {bar}-beat bar")


def main() -> int:
    courses, lesson_ids = [], set()
    only = next((a.split(",") for a in sys.argv[sys.argv.index("--only") + 1:][:1]), None) if "--only" in sys.argv else None
    if only and "--check" not in sys.argv:
        print("--only needs --check (a partial build would drop courses)")
        return 2
    for module in COURSES:
        if only and module not in only:
            continue
        path = HERE / "courses" / f"{module}.py"
        if not path.exists():
            print(f"(skipping {module}: not written yet)")
            continue
        course = importlib.import_module(f"courses.{module}").COURSE
        kind = instrument_kind(course)
        for u, unit in enumerate(course["units"]):
            for lesson in unit["lessons"]:
                where = f"{course['id']}/{lesson['id']}"
                if lesson["id"] in lesson_ids:
                    errors.append(f"{where}: duplicate lesson id")
                lesson_ids.add(lesson["id"])
                if u == 0:
                    lesson["free"] = True
                check_lesson(lesson, kind, where)
        courses.append(encode(course, course["id"]))
    total = sum(len(u["lessons"]) for c in courses for u in c["units"])
    if errors:
        print("\n".join(errors))
        print(f"{len(errors)} problems")
        return 1
    print(f"OK: {len(courses)} courses, {total} lessons, {len(strings)} strings")
    if "--check" in sys.argv:
        return 0
    out = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
    out.write_text(json.dumps({"version": 1, "courses": courses}, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    table = ROOT / "ios/Timbre/Resources/en.lproj/Learn.strings"
    esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")  # noqa: E731
    table.write_text("".join(f'"{k}" = "{esc(v)}";\n' for k, v in sorted(strings.items())), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
