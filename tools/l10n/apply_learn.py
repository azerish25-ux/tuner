#!/usr/bin/env python3
"""Write each locale's Learn.strings from tools/l10n/learn/<locale>.json.

python3 tools/l10n/apply_learn.py [--import <dir with <locale>/chunk*.json>]

Lesson text keys are hashes of the English (tools/curriculum/build.py), so a lesson
whose English changes gets a new key and simply falls back to English until it is
translated again. Only keys present in en.lproj/Learn.strings are written; stale
translations stay in the JSON (harmless) but never reach the app.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "ios/Timbre/Resources"
STORE = Path(__file__).resolve().parent / "learn"
LINE = re.compile(r'^"(L[0-9a-f]+)" = "((?:[^"\\]|\\.)*)";$', re.M)


def unescape(text: str) -> str:
    return re.sub(r'\\(.)', lambda m: "\n" if m.group(1) == "n" else m.group(1), text)


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def problems(source: str, translation: str) -> list:
    found = [sym for sym in "♯♭\n%" if source.count(sym) != translation.count(sym)]
    if Counter(re.findall(r"\d+", source)) != Counter(re.findall(r"\d+", translation)):
        found.append("numbers")
    return found


def main() -> None:
    STORE.mkdir(exist_ok=True)
    if len(sys.argv) == 3 and sys.argv[1] == "--import":
        for folder in sorted(Path(sys.argv[2]).iterdir()):
            if not folder.is_dir():
                continue
            merged = {}
            path = STORE / f"{folder.name}.json"
            if path.exists():
                merged = json.loads(path.read_text(encoding="utf-8"))
            for chunk in sorted(folder.glob("chunk*.json")):
                merged.update(json.loads(chunk.read_text(encoding="utf-8")))
            path.write_text(json.dumps(dict(sorted(merged.items())), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            print(f"imported {folder.name}: {len(merged)}")
    english = {k: unescape(v) for k, v in LINE.findall((RES / "en.lproj/Learn.strings").read_text(encoding="utf-8"))}
    bad = 0
    for path in sorted(STORE.glob("*.json")):
        locale = path.stem
        table = json.loads(path.read_text(encoding="utf-8"))
        lines = []
        for key in sorted(english):
            value = table.get(key)
            if not value:
                continue
            issues = problems(english[key], value)
            if issues:
                bad += 1
                print(f"{locale} {key}: {issues} — kept English", file=sys.stderr)
                continue
            lines.append(f'"{key}" = "{escape(value)}";')
        out = RES / f"{locale}.lproj/Learn.strings"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{locale}: {len(lines)}/{len(english)} lesson strings")
    if bad:
        print(f"{bad} translations rejected", file=sys.stderr)


if __name__ == "__main__":
    main()
