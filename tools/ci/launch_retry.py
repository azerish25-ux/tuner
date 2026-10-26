#!/usr/bin/env python3
"""The UI tests of a failed xcodebuild run that failed only because the app never launched, for one more try.

    python3 tools/ci/launch_retry.py ci-out/test.log ci-out/relaunch.txt

A simulator still settling after its boot can lose app launches for minutes: XCUITest reports "Failed to launch …
Timed out while launching application via Xcode" or "Application … does not have a process ID", and the test ends
there, before it has checked anything. The exact XCUITest background-assertion timeout also qualifies as simulator lifecycle infrastructure; ordinary assertion text does not. Those tests are written to the second file as `-only-testing:` arguments, one a
line (an empty file when there are none), so the job can run them once more.

Exits 0 when every failed test failed only that way, so the outcome rests on that one more try; 1 when any test failed
for another reason, or the run failed with no failed test in its log (the runner crashed, a build problem): that
failure stands whatever the second try does.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

CASE = re.compile(r"Test Case '-\[(?P<module>\w+)\.(?P<cls>\w+) (?P<test>\w+)\]' (?P<state>started|passed|failed)")
ERROR = re.compile(r"\berror: -\[(?P<module>\w+)\.(?P<cls>\w+) (?P<test>\w+)\] : (?P<message>.*)$")
LAUNCH = re.compile(r"Failed to launch .* via Xcode|Timed out while launching application|does not have a process ID")


BACKGROUND_ASSERTION = re.compile(
    r"^Failed to get background assertion for target app with pid [1-9]\d*: "
    r"Timed out while acquiring background assertion\.$"
)


def classify(text: str) -> tuple[list[str], list[str]]:
    """The failed tests (as `module/class/test`) that failed only at launch, and those that failed otherwise."""
    failed: list[str] = []
    errors: dict[str, list[str]] = {}
    for line in text.splitlines():
        if match := ERROR.search(line):
            name = f"{match['module']}/{match['cls']}/{match['test']}"
            errors.setdefault(name, []).append(match["message"])
        elif (match := CASE.search(line)) and match["state"] == "failed":
            name = f"{match['module']}/{match['cls']}/{match['test']}"
            if name not in failed:
                failed.append(name)
    launch_only = [name for name in failed if errors.get(name) and all(LAUNCH.search(m) or BACKGROUND_ASSERTION.fullmatch(m) for m in errors[name])]
    others = [name for name in failed if name not in launch_only]
    return launch_only, others


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: launch_retry.py <xcodebuild test log> <file for the -only-testing arguments>", file=sys.stderr)
        return 2
    log, out = Path(argv[1]), Path(argv[2])
    text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    launch_only, others = classify(text)
    out.write_text("".join(f"-only-testing:{name}\n" for name in launch_only))
    for name in launch_only:
        print(f"Failed only at launch, tried once more: {name}")
    for name in others:
        print(f"Failed: {name}")
    if others or not launch_only:
        if not others:
            print("The run failed with no failed test in its log: nothing to try again")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
