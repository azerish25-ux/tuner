#!/usr/bin/env python3
"""List source strings that have no translation yet.

python3 tools/l10n/extract.py <exported en.xliff> > tools/l10n/pending.json
The xliff comes from the "Localization export" workflow (ci-results/l10n).
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}
RES = Path(__file__).resolve().parents[2] / "ios/Timbre/Resources"


def existing(table: str) -> set:
    path = RES / "en.lproj" / table
    if not path.exists():
        return set()
    return set(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', path.read_text(encoding="utf-8"), re.M))


def main() -> None:
    root = ET.parse(sys.argv[1]).getroot()
    pending = []
    for file in root.findall("x:file", NS):
        table = Path(file.get("original")).name
        known = existing(table)
        for unit in file.findall(".//x:trans-unit", NS):
            key = unit.get("id")
            if key in known or key in {"CFBundleName"}:
                continue
            note = unit.find("x:note", NS)
            pending.append({"table": table, "key": key, "source": unit.find("x:source", NS).text or "",
                            "note": (note.text or "") if note is not None else ""})
    json.dump(pending, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
