#!/usr/bin/env python3
"""Release gate: every shipped language carries the strings a store review, a permission prompt or VoiceOver needs.

    python3 tools/l10n/critical.py                    # report what is missing, per category and locale (exit 0)
    python3 tools/l10n/critical.py --github           # the same, with warning annotations
    python3 tools/l10n/critical.py --baseline         # pull requests: exit 1 on a gap the baseline doesn't list
    python3 tools/l10n/critical.py --write-baseline   # record today's gaps as the baseline (a reviewed diff)
    python3 tools/l10n/critical.py --strict           # App Store delivery: exit 1 on any gap in a shipped locale
    python3 tools/l10n/critical.py --strict --locales de,fr,ja   # only these locales ship
    python3 tools/l10n/critical.py --out DIR          # also write DIR/critical-missing.json for the translators

Critical strings (everything else stays a warning in report.py --check):
    legal       the paywall's purchase terms: a string in ios/Timbre/Paywall/ about renewing, trials, cancelling,
                charges, billing, refunds, restoring purchases, the Terms or the privacy policy
    permission  the system permission prompts: NS…UsageDescription in InfoPlist.strings
    voiceover   what VoiceOver says: a string passed to accessibilityLabel / Hint / Value / InputLabels /
                CustomContent / Action(named:), posted as an announcement, or built by a declaration whose
                documentation says it is for VoiceOver (ChordWords in Learn/Diagrams.swift)

Two gates use this script:
    pull requests     `--baseline`: the gaps that predate the gate are listed in tools/l10n/critical-baseline.json,
                      and a new one fails the core job. Adding a critical English string therefore means delivering
                      its translations, or recording the gap with `--write-baseline`, which shows up in review.
    App Store upload  `--strict` (apple-delivery.yml): no gap at all in a shipped locale. Only an internal TestFlight
                      build may skip it, and that build can't be submitted for review.

The English, the tables and what each locale lacks come from report.py's model, so this gate and the translators'
handoff always agree. "Shipped" is CFBundleLocalizations in ios/project.yml (tools/l10n/shipping.py writes it), or
every .lproj when the project doesn't declare it, unless --locales narrows it.
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
import shipping  # noqa: E402
import swiftstrings  # noqa: E402

BASELINE = HERE / "critical-baseline.json"
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
    """The `///` documentation of the innermost documented declaration enclosing line `index` (0-based)."""
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
            if docs:
                return " ".join(reversed(docs))
        i -= 1
    return ""


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
        if VOICEOVER_CALLS.search(lines[index]):
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


def gap_keys(gaps: dict) -> dict:
    """{category: {"table|key": sorted locales}} for the gaps `missing` found."""
    out: dict = {}
    for loc, per in gaps.items():
        for category, items in per.items():
            for item in items:
                out.setdefault(category, {}).setdefault(f"{item['table']}|{item['key']}", set()).add(loc)
    return {category: {key: sorted(locs) for key, locs in sorted(keys.items())} for category, keys in sorted(out.items())}


def load_baseline(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8")).get("gaps", {})


def write_baseline(path: Path, keys: dict) -> int:
    body = {
        "about": "Legal, permission and VoiceOver strings that a shipped locale lacks and that predate the pull-request "
                 "gate (tools/l10n/critical.py --baseline): per category, 'table|key' and the locales without it. A gap "
                 "not listed here fails the core job. Translations shrink it; `critical.py --write-baseline` rewrites "
                 "it, and anything that adds is a reviewed decision to ship English in those locales for now. The App "
                 "Store delivery gate (--strict) ignores this file.",
    }
    # One string per line, its locales beside it: a translation delivered is a one-line diff.
    lines = ["{", f' "about": {json.dumps(body["about"], ensure_ascii=False)},', ' "gaps": {']
    categories = list(keys.items())
    for c, (category, per) in enumerate(categories):
        lines.append(f"  {json.dumps(category)}: {{")
        rows = list(per.items())
        for r, (key, locs) in enumerate(rows):
            comma = "," if r < len(rows) - 1 else ""
            lines.append(f"   {json.dumps(key, ensure_ascii=False)}: {json.dumps(locs)}{comma}")
        lines.append("  }" + ("," if c < len(categories) - 1 else ""))
    lines += [" }", "}"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return sum(len(locs) for per in keys.values() for locs in per.values())


def compare(current: dict, allowed: dict) -> tuple[list, list]:
    """(new, gone): (category, key, locale) gaps not in the baseline, and baseline entries no longer missing."""
    new, gone = [], []
    for category, keys in current.items():
        for key, locs in keys.items():
            known = set(allowed.get(category, {}).get(key, []))
            new.extend((category, key, loc) for loc in locs if loc not in known)
    for category, keys in allowed.items():
        for key, locs in keys.items():
            have = set(current.get(category, {}).get(key, []))
            gone.extend((category, key, loc) for loc in locs if loc not in have)
    return new, gone


def escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def gate_new(new: list, github: bool) -> int:
    """Prints the gaps the baseline doesn't list; 1 when there are any."""
    if not new:
        return 0
    by_key: dict = {}
    for category, key, loc in new:
        by_key.setdefault((category, key), []).append(loc)
    for (category, key), locs in sorted(by_key.items()):
        table, _, text = key.partition("|")
        print(f"NEW {category} [{table}] {text[:110]!r}: {', '.join(sorted(locs))}")
        if github:
            message = (f"New {category} string without translations in {len(locs)} shipped locales: {text[:140]!r}. "
                       f"Deliver the translations (tools/l10n/report.py --import), or record the gap with "
                       f"python3 tools/l10n/critical.py --write-baseline.")
            print(f"::error title=l10n/{category}::{escape(message)}")
    print(f"FAILED: {len(new)} new legal, permission or VoiceOver gaps ({len(by_key)} strings). Deliver the "
          f"translations, or record them deliberately with --write-baseline (the diff shows in review).")
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--strict", action="store_true", help="exit 1 when a shipped locale lacks a critical string")
    parser.add_argument("--baseline", nargs="?", const=BASELINE, type=Path, metavar="FILE",
                        help="exit 1 on a gap the baseline doesn't list (default tools/l10n/critical-baseline.json)")
    parser.add_argument("--write-baseline", nargs="?", const=BASELINE, type=Path, metavar="FILE",
                        help="record today's gaps as the baseline")
    parser.add_argument("--locales", help="comma-separated locales that ship (default: CFBundleLocalizations)")
    parser.add_argument("--github", action="store_true", help="emit GitHub annotations")
    parser.add_argument("--out", type=Path, help="write critical-missing.json here")
    parser.add_argument("--xliff", type=Path, help="an en.xliff from Xcode's export, to settle code keys (l10n.yml)")
    args = parser.parse_args(argv)

    model = report.build(args.xliff)
    available = sorted(model["locales"])
    locales = [loc for loc in shipping.shipped() if loc in model["locales"]]
    if args.locales:
        locales = [loc.strip() for loc in args.locales.split(",") if loc.strip() and loc.strip() != shipping.SOURCE]
        unknown = sorted(set(locales) - set(available))
        if unknown:
            print(f"No string tables for: {', '.join(unknown)}")
            return 2
    gaps = missing(model, locales, Classifier())
    current = gap_keys(gaps)
    print(f"Shipped locales checked: {len(locales)} ({', '.join(locales) or 'English only'})")

    if args.write_baseline:
        pairs = write_baseline(args.write_baseline, current)
        where = args.write_baseline.resolve()
        shown = where.relative_to(report.ROOT) if where.is_relative_to(report.ROOT) else where
        print(f"Baseline written: {pairs} locale × string gaps in {shown}")
        return 0

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
        if keys and args.github and not args.baseline:
            print(f"::{level} title=l10n/{category}::{len(keys)} {category} strings are untranslated in "
                  f"{len({l for v in keys.values() for l in v})} shipped locales ({pairs} gaps). "
                  f"See tools/l10n/critical.py and docs/l10n/HANDOFF.md.")
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        body = {loc: {c: [{"table": i["table"], "key": i["key"], "source": i["source"]} for i in items]
                      for c, items in per.items() if items} for loc, per in gaps.items()}
        (args.out / "critical-missing.json").write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n",
                                                        encoding="utf-8")
    if args.baseline:
        new, gone = compare(current, load_baseline(args.baseline))
        if gone:
            print(f"{len(gone)} baseline gaps are translated now: shrink the baseline with "
                  f"python3 tools/l10n/critical.py --write-baseline")
        if gate_new(new, args.github):
            return 1
        print(f"OK: no gap beyond the baseline ({total} known gaps; the App Store gate requires none).")
        return 0
    if total and args.strict:
        print(f"FAILED: {total} legal, permission or VoiceOver gaps in the shipped locales. Deliver the translations "
              f"(tools/l10n/report.py --import) or ship fewer locales (tools/l10n/shipping.py --min … --apply).")
        return 1
    print("OK" if not total else "Reported (not failing: --baseline gates pull requests, --strict a release)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
