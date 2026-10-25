#!/usr/bin/env python3
"""TimbreCore's line coverage against a floor that only rises.

    swift test --package-path ios --parallel --enable-code-coverage
    python3 tools/ci/coverage.py                  # exit 1 when TimbreCore's line coverage is under the floor
    python3 tools/ci/coverage.py --raise-floor    # move the floor up to one point under today's coverage

Reads the coverage export SwiftPM writes beside the build (`swift test --show-codecov-path`) and counts the lines of
the files under ios/Sources/TimbreCore only (not the tests). The floor lives in tools/ci/coverage-floor.json; a run
that measures well above it says so, and `--raise-floor` ratchets it up.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PACKAGE = ROOT / "ios"
FLOOR = HERE / "coverage-floor.json"
SOURCES = "/Sources/TimbreCore/"


def export_path() -> Path | None:
    """The JSON coverage export of the last `swift test --enable-code-coverage`."""
    for flag in ("--show-codecov-path", "--show-coverage-path"):
        result = subprocess.run(["swift", "test", "--package-path", str(PACKAGE), flag],
                                capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            path = Path(result.stdout.strip().splitlines()[-1])
            if path.exists():
                return path
    found = sorted((PACKAGE / ".build").glob("**/codecov/*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    return found[0] if found else None


def measure(path: Path) -> tuple[float, int, int, dict]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    covered = count = 0
    per_folder: dict = {}
    for data in doc.get("data", []):
        for entry in data.get("files", []):
            name = entry.get("filename", "")
            if SOURCES not in name:
                continue
            lines = entry.get("summary", {}).get("lines", {})
            covered += lines.get("covered", 0)
            count += lines.get("count", 0)
            folder = name.split(SOURCES, 1)[1].split("/", 1)[0]
            seen = per_folder.setdefault(folder, [0, 0])
            seen[0] += lines.get("covered", 0)
            seen[1] += lines.get("count", 0)
    share = 100.0 * covered / count if count else 0.0
    return share, covered, count, per_folder


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--export", type=Path, help="the coverage JSON (default: ask SwiftPM)")
    parser.add_argument("--raise-floor", action="store_true", help="set the floor one point under today's coverage")
    args = parser.parse_args(argv)

    path = args.export or export_path()
    if not path:
        print("No coverage export: run `swift test --package-path ios --enable-code-coverage` first")
        return 1
    share, covered, count, per_folder = measure(path)
    if not count:
        print(f"The coverage export {path} lists no file under ios{SOURCES}")
        return 1
    floor_doc = json.loads(FLOOR.read_text(encoding="utf-8")) if FLOOR.exists() else {}
    floor = float(floor_doc.get("lines", 0))
    print(f"TimbreCore line coverage: {share:.1f} % ({covered:,} of {count:,} lines); floor {floor:.1f} %")
    for folder, (done, total) in sorted(per_folder.items()):
        print(f"    {folder:12} {100.0 * done / total if total else 0:5.1f} %  ({done:,}/{total:,})")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(f"## TimbreCore coverage\n\n{share:.1f} % of {count:,} lines (floor {floor:.1f} %)\n")
    if args.raise_floor:
        floor_doc["lines"] = max(floor, float(int(share) - 1))
        FLOOR.write_text(json.dumps(floor_doc, indent=1) + "\n", encoding="utf-8")
        print(f"Floor now {floor_doc['lines']:.1f} %")
        return 0
    if share + 1e-9 < floor:
        print(f"FAILED: coverage fell under the floor ({share:.1f} % < {floor:.1f} %). Cover the new code with tests.")
        return 1
    if share - floor >= 3:
        print(f"The floor can rise: python3 tools/ci/coverage.py --raise-floor (on a run with coverage) sets "
              f"{int(share) - 1} %")
    return 0


if __name__ == "__main__":
    sys.exit(main())
