#!/usr/bin/env python3
"""Engineering-hygiene lint for the Swift sources under ios/: blocks the tells of an unreviewed, generated codebase.

    python3 tools/ci/lint_tells.py                    # check; exit 1 on a new error-level finding
    python3 tools/ci/lint_tells.py --github           # the same, with GitHub annotations (CI)
    python3 tools/ci/lint_tells.py --list RULE        # every occurrence of one rule, baseline included
    python3 tools/ci/lint_tells.py --update-baseline  # shrink the baseline to what is left (never grows it)
    python3 tools/ci/lint_tells.py --strict           # treat warn-level rules as errors too

Rules (comment rules read comments only; code rules read code with comments and string literals blanked):

    review-ref     error  comment  a review round ("review 14", "review 15's 51b", "REVIEW15")
    bug-ref        error  comment  a bug number with no tracker ("bug 64", "bug #5", "bug 06b")
    qa-ref         error  comment  a QA round item ("QA M11")
    store-frame    error  comment  a store screenshot named in product code ("store frame 51b", "frame #4");
                                   production targets only: the capture tests and the capture scenes
                                   (Root/DemoScenes.swift, Support/) exist to make those frames and may name them
    wip            error  comment  "WIP"
    agent-chatter  error  comment  a juror, the jury or the foreman, or an AI assistant by name
    icon-orb       warn   code     `IconOrb(`: the orb icon tile the design system is retiring
    type-scale     warn   code     a literal `Typeface` size off the type scale (12/13/15/17/20/28/40/64; `hero` exempt)
    test-coupling  note   comment  screenshots, UI tests, App Preview or the simulator explained in product code

A comment should say what the code guarantees and why, in the code's own terms; history belongs in git and in a
tracked issue (link it). Fix a finding by rewriting the comment that way (tools/ci/sweep_comments.py does the
mechanical part), not by adding to the baseline.

Baseline (tools/ci/hygiene-baseline.json): occurrences that predate the gate, counted per file, rule and matched
text, so moving code within a file or rewording around a reference changes nothing. A file may hold at most its
baseline count; more fails. Removing occurrences never fails: `--update-baseline` then ratchets the counts down. Warn
rules report new occurrences without failing until they are armed (`--strict`, or their level set to "error" here).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from swift_source import line_of, line_starts, scan  # noqa: E402

BASELINE = HERE / "hygiene-baseline.json"
SCAN_ROOT = "ios"
SKIP_DIRS = {".build", "build", ".swiftpm", "DerivedData"}
PRODUCTION = ("ios/Timbre/", "ios/Sources/", "ios/TimbreWidgets/", "ios/TimbreWatch/", "ios/TimbreWatchWidgets/")
TYPE_SCALE = {12.0, 13.0, 15.0, 17.0, 20.0, 28.0, 40.0, 64.0}


@dataclass(frozen=True)
class Rule:
    id: str
    level: str          # "error" fails the check; "warn" reports; "note" reports quietly
    where: str          # "comment" or "code"
    pattern: re.Pattern
    advice: str
    paths: tuple = ()   # path prefixes the rule applies to (empty: every scanned file)
    exempt: tuple = ()  # path prefixes it never applies to

    def applies(self, rel: str) -> bool:
        if self.paths and not rel.startswith(self.paths):
            return False
        return not (self.exempt and rel.startswith(self.exempt))

    def accept(self, match: re.Match) -> bool:
        if self.id == "type-scale":
            return float(match.group(1)) not in TYPE_SCALE
        return True


REF_ADVICE = ("Say what the code guarantees and why, in the code's own terms, or link a tracked issue. "
              "Review rounds and bug numbers mean nothing to the next reader.")
RULES = [
    Rule("review-ref", "error", "comment",
         re.compile(r"\breview(?:\s+round)?\s*#?\s*\d+(?:['’]s)?\b|\bREVIEW\d+\b", re.I), REF_ADVICE),
    Rule("bug-ref", "error", "comment", re.compile(r"\bbug\s*#?\s*\d+[a-z]?\b", re.I), REF_ADVICE),
    Rule("qa-ref", "error", "comment", re.compile(r"\bQA\s*#?\s*[A-Z]?\d+\b"), REF_ADVICE),
    Rule("store-frame", "error", "comment",
         re.compile(r"\b(?:app\s+)?store\s+frames?\b|\bframe\s*#\s*\d+[a-z]?\b|\bstore\s*#\s*\d+\b", re.I),
         "Product code shouldn't know which store screenshot it appears in. Describe the behaviour the capture relies on.",
         paths=PRODUCTION, exempt=("ios/Timbre/Support/", "ios/Timbre/Root/DemoScenes.swift")),
    Rule("wip", "error", "comment", re.compile(r"\bWIP\b"), "Finish the work or open an issue; don't ship WIP markers."),
    Rule("agent-chatter", "error", "comment",
         re.compile(r"\b(?:jurors?|jury|foreman|Claude|ChatGPT|Copilot|GPT-\d)\b", re.I),
         "Comments address the code's reader, not a reviewer or an assistant."),
    Rule("icon-orb", "warn", "code", re.compile(r"\bIconOrb\("),
         "IconOrb is being retired (WP8): use the design system's plain glyph instead."),
    Rule("type-scale", "warn", "code",
         re.compile(r"\bTypeface\.(?:display|displayLight|displayItalic|note|number|label)\(\s*(\d+(?:\.\d+)?)\b"),
         "Use a size on the type scale (12/13/15/17/20/28/40/64) or a Typeface role; hero numerals use Typeface.hero."),
    Rule("test-coupling", "note", "comment",
         re.compile(r"\b(?:screenshots?|UI[- ]tests?|XCUITest|App Preview|simulators?)\b", re.I),
         "Product code explained by its tests or captures: state the behaviour and why it matters to a user.",
         paths=PRODUCTION, exempt=("ios/Timbre/Support/", "ios/Timbre/Root/DemoScenes.swift")),
]
RULES_BY_ID = {rule.id: rule for rule in RULES}


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    match: str
    text: str

    @property
    def key(self) -> str:
        return f"{self.rule}: {normalize(self.match)}"


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip()).lower().replace("’", "'")


def swift_files(root: Path) -> list[Path]:
    out = []
    for folder, dirs, files in os.walk(root / SCAN_ROOT):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.endswith((".xcodeproj", ".xcresult")))
        out.extend(Path(folder) / f for f in sorted(files) if f.endswith(".swift"))
    return out


def lint_source(rel: str, source: str) -> list[Finding]:
    code, comments = scan(source)
    starts = line_starts(source)
    lines = source.splitlines()
    found: list[Finding] = []
    for rule in RULES:
        if not rule.applies(rel):
            continue
        if rule.where == "comment":
            for comment in comments:
                for match in rule.pattern.finditer(comment.text):
                    if rule.accept(match):
                        line = line_of(starts, comment.start + match.start())
                        found.append(Finding(rule.id, rel, line, match.group(0), lines[line - 1].strip()))
        else:
            for match in rule.pattern.finditer(code):
                if rule.accept(match):
                    line = line_of(starts, match.start())
                    found.append(Finding(rule.id, rel, line, match.group(0), lines[line - 1].strip()))
    return found


def lint_tree(root: Path) -> list[Finding]:
    found = []
    for path in swift_files(root):
        rel = path.relative_to(root).as_posix()
        found.extend(lint_source(rel, path.read_text(encoding="utf-8", errors="replace")))
    return found


def tally(findings: list[Finding]) -> dict:
    counts: dict = {}
    for f in findings:
        per_file = counts.setdefault(f.path, {})
        per_file[f.key] = per_file.get(f.key, 0) + 1
    return counts


def load_baseline(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8")).get("allowed", {})


def write_baseline(path: Path, allowed: dict) -> None:
    body = {
        "about": "Occurrences that predate the hygiene lint (tools/ci/lint_tells.py), per file and 'rule: matched text'. "
                 "It only ever shrinks: fix code, then run `python3 tools/ci/lint_tells.py --update-baseline`.",
        "allowed": {p: dict(sorted(keys.items())) for p, keys in sorted(allowed.items()) if keys},
    }
    path.write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def compare(findings: list[Finding], allowed: dict) -> tuple[list[tuple[Finding, int, int]], list[str]]:
    """(over, shrinkable): findings in a file/key over its allowance as (finding, found, allowed); and the baseline
    entries that are now larger than what is left."""
    counts = tally(findings)
    over = []
    for f in findings:
        have, may = counts[f.path][f.key], allowed.get(f.path, {}).get(f.key, 0)
        if have > may:
            over.append((f, have, may))
    shrinkable = []
    for path, keys in allowed.items():
        for key, may in keys.items():
            have = counts.get(path, {}).get(key, 0)
            if have < may:
                shrinkable.append(f"{path}: {key} ({may} allowed, {have} left)")
    return over, shrinkable


def escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this checkout)")
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--github", action="store_true", help="emit GitHub annotations")
    parser.add_argument("--strict", action="store_true", help="warn-level rules fail too")
    parser.add_argument("--list", metavar="RULE", help="print every occurrence of RULE (or 'all') and exit")
    parser.add_argument("--update-baseline", action="store_true", help="lower baseline counts to what is left")
    parser.add_argument("--reset-baseline", action="store_true", help="write the current findings as the baseline")
    args = parser.parse_args(argv)

    findings = lint_tree(args.root)
    if args.list:
        for f in findings:
            if args.list in ("all", f.rule):
                print(f"{f.path}:{f.line}: [{f.rule}] {f.text}")
        return 0
    if args.reset_baseline:
        write_baseline(args.baseline, tally(findings))
        print(f"Baseline written: {len(findings)} occurrences in {len(tally(findings))} files")
        return 0
    allowed = load_baseline(args.baseline)
    if args.update_baseline:
        current = tally(findings)
        shrunk = {path: {key: min(may, current.get(path, {}).get(key, 0)) for key, may in keys.items()}
                  for path, keys in allowed.items()}
        shrunk = {path: {k: v for k, v in keys.items() if v} for path, keys in shrunk.items()}
        write_baseline(args.baseline, shrunk)
        print(f"Baseline lowered: {sum(map(sum, (k.values() for k in allowed.values())))} → "
              f"{sum(map(sum, (k.values() for k in shrunk.values())))} allowed occurrences")
        return 0

    over, shrinkable = compare(findings, allowed)
    failing = [(f, have, may) for f, have, may in over
               if RULES_BY_ID[f.rule].level == "error" or (args.strict and RULES_BY_ID[f.rule].level == "warn")]
    for f, have, may in over:
        rule = RULES_BY_ID[f.rule]
        fails = (f, have, may) in failing
        level = "error" if fails else ("warning" if rule.level == "warn" else "notice")
        message = (f"[{f.rule}] '{f.match}': {have} in this file, {may} allowed by the baseline. {rule.advice}")
        print(f"{level.upper()} {f.path}:{f.line}: {message}\n    {f.text}")
        if args.github:
            print(f"::{level} file={f.path},line={f.line},title=hygiene/{f.rule}::{escape(message)}")
    totals: dict = {}
    for f in findings:
        totals[f.rule] = totals.get(f.rule, 0) + 1
    baseline_total = sum(sum(keys.values()) for keys in allowed.values())
    print("Hygiene lint: " + ", ".join(f"{rule.id} {totals.get(rule.id, 0)}" for rule in RULES)
          + f" (baseline allows {baseline_total})")
    if shrinkable:
        print(f"{len(shrinkable)} baseline entries can shrink; run `python3 tools/ci/lint_tells.py --update-baseline`:")
        for line in shrinkable[:20]:
            print("    " + line)
    if failing:
        print(f"FAILED: {len(failing)} new error-level occurrences. {REF_ADVICE}")
        return 1
    print("OK: no new error-level occurrences")
    return 0


if __name__ == "__main__":
    sys.exit(main())
