#!/usr/bin/env python3
"""Release gate: every shipped language carries the strings a store review, a permission prompt or VoiceOver needs.

    python3 tools/l10n/critical.py                    # report what is missing, per category and locale (exit 0)
    python3 tools/l10n/critical.py --github           # the same, with warning annotations (the core CI job)
    python3 tools/l10n/critical.py --strict           # exit 1 when a shipped locale lacks one (apple-delivery.yml)
    python3 tools/l10n/critical.py --strict --locales de,fr,ja   # only these locales ship
    python3 tools/l10n/critical.py --out DIR          # also write DIR/critical-missing.json for the translators

Critical strings (everything else stays a warning in report.py --check):
    legal       the paywall's purchase terms: a string in ios/Timbre/Paywall/ about renewing, trials, cancelling,
                charges, billing, refunds, restoring purchases, the Terms or the privacy policy
    permission  the system permission prompts: NS…UsageDescription in InfoPlist.strings
    voiceover   what VoiceOver says: a string passed to accessibilityLabel / Hint / Value / InputLabels /
                CustomContent / Action(named:), posted as an announcement, or built by a declaration whose
                documentation says it is for VoiceOver (ChordWords in Learn/Diagrams.swift)

The English, the tables and what each locale lacks come from report.py's model, so this gate and the translators'
handoff always agree. "Shipped" is every .lproj in ios/Timbre/Resources unless --locales narrows it (the owner may
trim CFBundleLocalizations to the locales that are complete).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import report  # noqa: E402
import swiftstrings  # noqa: E402

CATEGORIES = ("legal", "permission", "voiceover")
LEGAL_FOLDERS = ("ios/Timbre/Paywall/",)
LEGAL_WORDS = re.compile(r"\b(?:renew\w*|subscri\w*|cancel\w*|charge[sd]?|billed|billing|trials?|refund\w*|terms|"
                         r"privacy|restore\w*|Apple Account|Apple ID|payments?)\b", re.I)
PERMISSION_KEY = re.compile(r"^NS\w+UsageDescription$")
VOICEOVER_SLOTS = re.compile(r"^\.accessibility(?:Label|Hint|Value|InputLabels|CustomContent|Action)\(")
VOICEOVER_CALLS = re.compile(r"\.accessibility(?:Label|Hint|Value|InputLabels|CustomContent)\(|"
                             r"AccessibilityNotification\.Announcement|UIAccessibility\.post|accessibilityAction\(named:")
VOICEOVER_DOCS = re.compile(r"\bVoiceOver\b|\bscreen reader\b", re.I)
DECL = re.compile(r"^(\s*)(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:(?:public|internal|private|fileprivate|static|final|override|"
                  r"nonisolated|mutating|lazy|indirect)\s+)*(?:func|var|let|enum|struct|class|actor|extension|init|"
                  r"subscript)\b")


def declaration_docs(lines: list[str], index: int) -> str:
    """The `///` documentation of every declaration enclosing line `index` (0-based), innermost first."""
    found = []
    text = lines[index]
    limit = len(text) - len(text.lstrip())
    i = index - 1
    while i >= 0 and limit > 0:
        line = lines[i]
        m = DECL.match(line)
        if m and line.strip() and len(m.group(1)) < limit:
            limit = len(m.group(1))
            j = i - 1
            while j >= 0 and re.match(r"^\s*@[\w.]+(?:\(.*\))?\s*$", lines[j]):
                j -= 1  # attributes on their own line (@MainActor)
            docs = []
            while j >= 0 and lines[j].lstrip().startswith("///"):
                docs.append(lines[j].strip()[3:].strip())
                j -= 1
            found.append(" ".join(reversed(docs)))
        i -= 1
    return " ".join(found)


class Classifier:
    def __init__(self) -> None:
        folders = [f for f in report.CODE + report.DECLS if (report.ROOT / f).exists()]
        literals, lexers = swiftstrings.scan(report.ROOT, folders)
        self.slots: dict[str, set] = {}
        for lit in literals:
            self.slots.setdefault(f"{lit.file}:{lit.line}", set()).add(lit.slot or "")
        self.lines = {rel: lexer.s.splitlines() for rel, lexer in lexers.items()}

    def voiceover(self, where: str) -> bool:
        if any(VOICEOVER_SLOTS.match(slot) for slot in self.slots.get(where, ())):
            return True
        path, _, number = where.partition(":")
        lines = self.lines.get(path)
        if not lines or not number.isdigit() or int(number) > len(lines):
            return False
        index = int(number) - 1
        statement = " ".join(lines[max(0, index - 1): index + 2])
        if VOICEOVER_CALLS.search(statement):
            return True
        return bool(VOICEOVER_DOCS.search(declaration_docs(lines, index)))

    def categories(self, item: dict) -> set:
        table, key, source = item["table"], item["key"], item.get("source", "")
        found = set()
        if table == "InfoPlist.strings" and PERMISSION_KEY.match(key):
            found.add("permission")
        for where in item.get("where", []):
            if where.startswith(LEGAL_FOLDERS) and LEGAL_WORDS.search(source):
                found.add("legal")
            if table in ("Localizable.strings", "Localizable.stringsdict") and self.voiceover(where):
                found.add("voiceover")
        return found


def missing(model: dict, locales: list[str], classifier: Classifier) -> dict:
    """{locale: {category: [todo item]}} for the critical strings each shipped locale lacks."""
    out = {}
    for loc in locales:
        per = {c: [] for c in CATEGORIES}
        for item in model["locales"][loc]["todo"]:
            if item["table"] == report.LEARN:
                continue
            for category in classifier.categories(item):
                per[category].append(item)
        out[loc] = per
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--strict", action="store_true", help="exit 1 when a shipped locale lacks a critical string")
    parser.add_argument("--locales", help="comma-separated locales that ship (default: every .lproj)")
    parser.add_argument("--github", action="store_true", help="emit GitHub annotations")
    parser.add_argument("--out", type=Path, help="write critical-missing.json here")
    parser.add_argument("--xliff", type=Path, help="an en.xliff from Xcode's export, to settle code keys (l10n.yml)")
    args = parser.parse_args(argv)

    model = report.build(args.xliff)
    available = sorted(model["locales"])
    locales = available
    if args.locales:
        locales = [loc.strip() for loc in args.locales.split(",") if loc.strip()]
        unknown = sorted(set(locales) - set(available))
        if unknown:
            print(f"No string tables for: {', '.join(unknown)}")
            return 2
    gaps = missing(model, locales, Classifier())

    level = "error" if args.strict else "warning"
    total = 0
    for category in CATEGORIES:
        keys = {}
        for loc in locales:
            for item in gaps[loc][category]:
                keys.setdefault((item["table"], item["key"]), []).append(loc)
        pairs = sum(len(v) for v in keys.values())
        total += pairs
        print(f"{category}: {len(keys)} strings missing in at least one shipped locale ({pairs} locale × string gaps)")
        for (table, key), locs in sorted(keys.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:12]:
            shown = "all shipped locales" if len(locs) == len(locales) else ", ".join(locs)
            print(f"    [{table}] {key[:110]!r}: {shown}")
        if keys and args.github:
            print(f"::{level} title=l10n/{category}::{len(keys)} {category} strings are untranslated in "
                  f"{len({l for v in keys.values() for l in v})} shipped locales ({pairs} gaps). "
                  f"See tools/l10n/critical.py and docs/l10n/HANDOFF.md.")
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        body = {loc: {c: [{"table": i["table"], "key": i["key"], "source": i["source"]} for i in items]
                      for c, items in per.items() if items} for loc, per in gaps.items()}
        (args.out / "critical-missing.json").write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n",
                                                        encoding="utf-8")
    if total and args.strict:
        print(f"FAILED: {total} legal, permission or VoiceOver gaps in the shipped locales. Deliver the translations "
              f"(tools/l10n/report.py --import) or ship fewer locales (--locales).")
        return 1
    print("OK" if not total else "Reported (not failing: run with --strict to gate a release)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
