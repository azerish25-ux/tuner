#!/usr/bin/env python3
"""Merge translations into the app's .strings tables.

python3 tools/l10n/apply.py tools/l10n/translations
Each <locale>.json holds {"table": {"source key": "translation"}} for the tables
Localizable.strings, AppShortcuts.strings and InfoPlist.strings. Existing keys are
replaced, new keys appended. A translation whose format arguments (%@, %lld,
${applicationName}) differ in type or order from its key's is rejected so the app can
never crash on a mismatched format string; positional forms (%2$@ %1$lld) may reorder.
"""
import json
import re
import sys
from pathlib import Path

RES = Path(__file__).resolve().parents[2] / "ios/Timbre/Resources"
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f|%)|\$\{applicationName\}")
ARG = re.compile(r"%(?:(\d+)\$)?(lld|ld|d|@|f|\.\d+f|%)|(\$\{applicationName\})")


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def specs(text: str) -> list:
    """Argument types in the order the format consumes them; positional specifiers (%2$@) are
    put back in argument order so a translation may reorder its arguments."""
    found = [(m.group(1), m.group(2) or m.group(3)) for m in ARG.finditer(text) if m.group(2) != "%"]
    if any(position for position, _ in found):
        if not all(position for position, _ in found):
            return ["mixed"]
        return [kind for _, kind in sorted(found, key=lambda item: int(item[0]))]
    return [kind for _, kind in found]


def merge(path: Path, entries: dict) -> int:
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    index = {}
    for number, line in enumerate(lines):
        match = re.match(r'^"((?:[^"\\]|\\.)*)"\s*=', line)
        if match:
            index[match.group(1)] = number
    added = 0
    for key, value in entries.items():
        line = f'"{escape(key)}" = "{escape(value)}";'
        if escape(key) in index:
            lines[index[escape(key)]] = line
        else:
            lines.append(line)
            added += 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return added


def main() -> None:
    folder = Path(sys.argv[1])
    problems = 0
    for file in sorted(folder.glob("*.json")):
        locale = file.stem
        tables = json.loads(file.read_text(encoding="utf-8"))
        for table, entries in tables.items():
            good = {}
            for key, value in entries.items():
                if not isinstance(value, str) or not value.strip():
                    continue
                if specs(key) != specs(value):
                    print(f"{locale}/{table}: format mismatch, kept English: {key!r} -> {value!r}")
                    problems += 1
                    continue
                good[key] = value
            added = merge(RES / f"{locale}.lproj" / table, good)
            print(f"{locale}/{table}: {len(good)} entries ({added} new)")
    print("format mismatches:", problems)


if __name__ == "__main__":
    main()
