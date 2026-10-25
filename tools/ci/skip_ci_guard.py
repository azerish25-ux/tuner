#!/usr/bin/env python3
"""Pull requests: no commit that touches ios/ may skip CI or be a work-in-progress snapshot.

    python3 tools/ci/skip_ci_guard.py --base origin/main --head HEAD [--github]

A commit fails the check when it changes a file under ios/ and its message
    - asks CI to skip it: [skip ci], [ci skip], [no ci], [skip actions], [actions skip] or a `skip-checks: true` trailer;
    - or its subject starts with "WIP".

Such a commit was never built or tested on its own, and a squash merge would carry its untested state into the branch.
GitHub runs no workflow at all for a pull request whose newest commit asks to skip CI, so the required gate never
reports and the pull request can't merge; this check covers the commits before it.

Commits already reachable from the SHA in tools/ci/skip-ci-grandfathered.txt predate the rule and are not checked.
Needs the history of both ends (actions/checkout with fetch-depth: 0).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GRANDFATHERED = HERE / "skip-ci-grandfathered.txt"
SKIP = re.compile(r"\[(?:skip ci|ci skip|no ci|skip actions|actions skip)\]|^skip-checks:\s*true\s*$", re.I | re.M)
WIP = re.compile(r"^\s*WIP\b", re.I)


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def grandfathered() -> str | None:
    if not GRANDFATHERED.exists():
        return None
    for line in GRANDFATHERED.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            return line
    return None


def touches_ios(sha: str) -> bool:
    parents = git("rev-list", "--parents", "-n", "1", sha).split()[1:]
    if parents:
        changed = git("diff", "--name-only", parents[0], sha).splitlines()
    else:
        changed = git("show", "--format=", "--name-only", sha).splitlines()
    return any(path.startswith("ios/") for path in changed)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--base", required=True, help="the branch the pull request merges into (e.g. origin/main)")
    parser.add_argument("--head", required=True, help="the pull request's head commit")
    parser.add_argument("--github", action="store_true", help="emit GitHub annotations")
    args = parser.parse_args(argv)

    old = grandfathered()
    if old:
        try:
            git("cat-file", "-e", f"{old}^{{commit}}")
        except subprocess.CalledProcessError:
            old = None  # not in this clone: nothing to exempt
    shas = git("rev-list", f"{args.base}..{args.head}").split()
    failures = []
    for sha in shas:
        if old and subprocess.run(["git", "merge-base", "--is-ancestor", sha, old], cwd=ROOT).returncode == 0:
            continue
        message = git("log", "-1", "--format=%B", sha)
        subject = message.splitlines()[0] if message.strip() else ""
        reason = "asks CI to skip it" if SKIP.search(message) else ("is a WIP snapshot" if WIP.match(subject) else None)
        if reason and touches_ios(sha):
            failures.append((sha, subject, reason))
    print(f"Checked {len(shas)} commits in {args.base}..{args.head}")
    for sha, subject, reason in failures:
        print(f"FAIL {sha[:10]} {subject[:100]!r}: changes ios/ and {reason}")
        if args.github:
            print(f"::error title=Commit skips CI::{sha[:10]} ({subject[:80]}) changes ios/ and {reason}. "
                  "Squash it into a tested commit; every commit that touches ios/ is built and tested.")
    if failures:
        print(f"FAILED: {len(failures)} commits touch ios/ without CI. Rebase them into tested commits.")
        return 1
    print("OK: every commit that touches ios/ runs CI")
    return 0


if __name__ == "__main__":
    sys.exit(main())
