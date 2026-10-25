#!/usr/bin/env python3
"""Rewrites review-round, bug-number and QA references in Swift comments into plain technical comments.

    python3 tools/ci/sweep_comments.py                 # dry run over ios/: print the diff and what needs a person
    python3 tools/ci/sweep_comments.py --write         # apply it
    python3 tools/ci/sweep_comments.py --write ios/Timbre/Learn/LessonSteps.swift   # only these files

The comments in this codebase already explain the behaviour; the references only say which review found it. So the
sweep removes the reference and keeps the explanation:

    "came out as "ORIGI…" (review 14)."              ->  "came out as "ORIGI…"."
    "(bug 64, a song's first step stuck at 30 %)"    ->  "(a song's first step stuck at 30 %)"
    "(bug 5: the outline said …"                     ->  "(the outline said …"
    "the name ("Cho|rus", review 14)."               ->  "the name ("Cho|rus")."
    "// (review 14). The stage gives up the room."   ->  the "." joins the line above; "// The stage gives up the room."

Store-frame references ("frame #4", "store frame 51b") are removed the same way in product code; the capture tests
and the capture scenes (Root/DemoScenes.swift) keep them, as the hygiene lint does. Only comment text changes: code
and string literals are never touched. A reference the rules can't remove cleanly ("Review 13's results: …") is
listed for a person to rewrite. Run the hygiene lint afterwards (tools/ci/lint_tells.py --update-baseline).
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import lint_tells  # noqa: E402
from swift_source import scan  # noqa: E402

_REVIEW = r"(?i:review(?:\s+round)?\s*#?\s*\d+(?:['’]s)?(?:\s+\d{1,3}[a-z]?\b)?)"
_BUG = r"(?i:bug\s*#?\s*\d+[a-z]?)"
_QA = r"QA\s*#?\s*[A-Z]?\d+"
_FRAME = r"(?i:(?:app\s+)?store\s+frames?\s*#?\s*\d+[a-z]?|frame\s*#\s*\d+[a-z]?|store\s*#\s*\d+)"


def _patterns(frames: bool) -> tuple[re.Pattern, re.Pattern, re.Pattern]:
    ref = "(?:" + "|".join([_REVIEW, _BUG, _QA] + ([_FRAME] if frames else [])) + r")\b"
    refs = ref + r"(?:\s*[,;]\s*(?:and\s+)?" + ref + r")*"
    only = re.compile(r"[ \t]*\(\s*" + refs + r"\s*\)")         # "(review 14, bug 2)"
    lead = re.compile(r"\(\s*" + refs + r"\s*[:,;]\s*")          # "(bug 5: the outline …"
    trail = re.compile(r"\s*[,;]\s*" + refs + r"\s*\)")          # "("Cho|rus", review 14)"
    return only, lead, trail


_WITH_FRAMES = _patterns(True)
_WITHOUT_FRAMES = _patterns(False)
_MARKER = re.compile(r"^(\s*)(///?|/\*+|\*)(\s?)(.*)$", re.S)


def _rewrite(text: str, patterns) -> str:
    only, lead, trail = patterns
    text = only.sub("", text)
    text = lead.sub("(", text)
    return trail.sub(")", text)


def _remaining_rules(rel: str) -> list:
    return [lint_tells.RULES_BY_ID[r] for r in ("review-ref", "bug-ref", "qa-ref", "store-frame")
            if lint_tells.RULES_BY_ID[r].applies(rel)]


def sweep_source(source: str, rel: str = "ios/Timbre/Example.swift") -> tuple[str, list[tuple[int, str]]]:
    """(rewritten source, [(line, text)] references left for a person)."""
    frames = lint_tells.RULES_BY_ID["store-frame"].applies(rel)
    patterns = _WITH_FRAMES if frames else _WITHOUT_FRAMES
    _, comments = scan(source)
    edits = []
    for comment in comments:
        new = _rewrite(comment.text, patterns)
        if new != comment.text:
            edits.append((comment.start, comment.end, new))
    out = source
    edited_offsets = []
    for start, end, new in reversed(edits):
        out = out[:start] + new + out[end:]
    # Offsets of edited comments in the new text, to find the lines they sit on.
    shift = 0
    for start, end, new in edits:
        edited_offsets.append(start + shift)
        shift += len(new) - (end - start)
    lines = out.splitlines(keepends=True)
    edited_lines = sorted({out.count("\n", 0, offset) for offset in edited_offsets})
    for index in edited_lines:
        _join_orphan_punctuation(lines, index)
    out = "".join(lines)

    manual = []
    _, comments = scan(out)
    rules = _remaining_rules(rel)
    out_lines = out.splitlines()
    for comment in comments:
        for rule in rules:
            for match in rule.pattern.finditer(comment.text):
                line = out.count("\n", 0, comment.start + match.start()) + 1
                manual.append((line, out_lines[line - 1].strip()))
    return out, sorted(set(manual))


def _join_orphan_punctuation(lines: list[str], index: int) -> None:
    """`// (review 14). The stage…` became `//. The stage…`: the full stop belongs to the sentence on the line above."""
    if index >= len(lines):
        return
    body = lines[index].rstrip("\r\n")
    ending = lines[index][len(body):]
    stripped = body.lstrip()
    if not stripped.startswith("//"):
        return
    indent = body[: len(body) - len(stripped)]
    marker = "///" if stripped.startswith("///") else "//"
    rest = stripped[len(marker):]
    m = re.match(r"\s*([.,;:])(?:\s+|$)(.*)$", rest, re.S)
    if not m:
        return
    mark, remainder = m.group(1), m.group(2)
    if index > 0:
        above = lines[index - 1].rstrip("\r\n")
        above_ending = lines[index - 1][len(above):]
        if above.lstrip().startswith(marker) and not above.lstrip().startswith(marker + "/"):
            if not re.search(r"[.,;:!?]$", above.rstrip()):
                lines[index - 1] = above.rstrip() + mark + above_ending
            lines[index] = (indent + marker + (" " + remainder if remainder else "")).rstrip() + ending
            return
    lines[index] = (indent + marker + (" " + remainder if remainder else "")).rstrip() + ending


def swift_paths(root: Path, targets: list[str]) -> list[Path]:
    if not targets:
        return lint_tells.swift_files(root)
    out = []
    for target in targets:
        path = (root / target) if not Path(target).is_absolute() else Path(target)
        out.extend(sorted(path.rglob("*.swift")) if path.is_dir() else [path])
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("paths", nargs="*", help="files or folders (default: every Swift file under ios/)")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this checkout)")
    parser.add_argument("--write", action="store_true", help="rewrite the files (default: print the diff only)")
    args = parser.parse_args(argv)

    changed, manual = 0, []
    for path in swift_paths(args.root, args.paths):
        rel = path.resolve().relative_to(args.root.resolve()).as_posix()
        source = path.read_text(encoding="utf-8")
        new, left = sweep_source(source, rel)
        manual.extend(f"{rel}:{line}: {text}" for line, text in left)
        if new == source:
            continue
        changed += 1
        if args.write:
            path.write_text(new, encoding="utf-8")
        else:
            sys.stdout.writelines(difflib.unified_diff(source.splitlines(keepends=True), new.splitlines(keepends=True),
                                                       fromfile=f"a/{rel}", tofile=f"b/{rel}"))
    verb = "rewrote" if args.write else "would rewrite"
    print(f"\nComment sweep {verb} {changed} files.")
    if manual:
        print(f"{len(manual)} references need a person (the sentence depends on them):")
        for line in manual:
            print("    " + line)
    return 0 if args.write or changed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
