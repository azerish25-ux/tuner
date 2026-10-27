#!/usr/bin/env python3
"""Merge translations into the app's .strings tables.

python3 tools/l10n/apply.py tools/l10n/translations
Each <locale>.json holds {"table": {"source key": "translation"}} for the tables
Localizable.strings, AppShortcuts.strings and InfoPlist.strings. Existing keys are
replaced, new keys appended. A translation whose format arguments (%@, %lld) differ in type or order from its key's,
or whose named tokens (${applicationName}, ${instrument} …) differ from its key's, is
rejected so the app can never crash on a mismatched format string; positional forms
(%2$@ %1$lld) and named tokens may reorder.
"""
import json
import re
import sys
from pathlib import Path

RES = Path(__file__).resolve().parents[2] / "ios/Timbre/Resources"
ARG = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(lld|llu|ld|lu|lf|d|u|f|@|%)")
TOKEN = re.compile(r"\$\{\w+\}")


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def format_signature(text: str) -> tuple | None:
    """Typed argument index/multiplicity plus named tokens.

    Repeated references are supported. Mixed addressing and gapped source slots
    are deliberately unsupported importer templates, not necessarily invalid printf.
    """
    found = [(m.group(1), m.group(2)) for m in ARG.finditer(text) if m.group(2) != "%"]
    if any(position for position, _ in found):
        if not all(position for position, _ in found):
            return None
        indexed = [(int(position), kind) for position, kind in found]
        slots = {position for position, _ in indexed}
        if slots != set(range(1, len(slots) + 1)):
            return None
        if any(len({kind for index, kind in indexed if index == position}) != 1 for position in slots):
            return None
    else:
        indexed = list(enumerate((kind for _, kind in found), start=1))
    return (tuple(sorted(indexed)), tuple(sorted(TOKEN.findall(text))))


def specs(text: str) -> list | None:
    """Compatibility presentation of the typed signature; use formats_match to compare."""
    signature = format_signature(text)
    return None if signature is None else [kind for _, kind in signature[0]] + list(signature[1])


def formats_match(source: str, target: str) -> bool:
    """Invalid/unsupported signatures never match, including two invalid templates."""
    expected = format_signature(source)
    return expected is not None and expected == format_signature(target)


def format_source(table: str, key: str, resources: Path | None = None) -> str | None:
    """Resolve semantic keys against the current English value, never the identifier.

    Literal UI/Shortcut keys remain their own format contract. Unknown semantic IDs
    fail closed; a translator cannot supply a replacement English format contract.
    """
    if table != "Localizable.strings" or not key.startswith("timbre_"):
        return key
    path = (resources or RES) / "en.lproj/Localizable.strings"
    if not path.exists():
        return None
    pairs = re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
                       path.read_text(encoding="utf-8"), re.M)
    def unescape(text):
        return re.sub(r'\\(u[0-9a-fA-F]{4}|.)', lambda m:
                      {"n": "\n", "t": "\t", "r": "\r"}.get(m.group(1),
                      chr(int(m.group(1)[1:], 16)) if m.group(1).startswith("u")
                      and len(m.group(1)) == 5 else m.group(1)), text)
    return {unescape(k): unescape(v) for k, v in pairs}.get(key)


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
                source = format_source(table, key)
                if source is None or not formats_match(source, value):
                    print(f"{locale}/{table}: format mismatch or unsupported mixed/gapped/conflicting argument slots, kept English: {key!r} -> {value!r}")
                    problems += 1
                    continue
                good[key] = value
            added = merge(RES / f"{locale}.lproj" / table, good)
            print(f"{locale}/{table}: {len(good)} entries ({added} new)")
    print("format mismatches:", problems)


if __name__ == "__main__":
    main()
