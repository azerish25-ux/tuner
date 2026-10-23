#!/usr/bin/env python3
"""Write a short failure summary of an xcodebuild/swift log next to it, and emit
GitHub error annotations, so failures are readable without opening the full log."""
import re
import sys
from pathlib import Path

PATTERNS = [
    re.compile(r"\berror:"),
    re.compile(r"Test Case '.*' failed"),
    re.compile(r"XCTAssert\w* failed|failed - "),
    re.compile(r"\*\* (BUILD|TEST|ARCHIVE) FAILED \*\*"),
    re.compile(r"Testing failed:"),
    re.compile(r"Fatal error|fatalError|Thread \d+: "),
    re.compile(r"✘|Test .* recorded an issue"),
]

def main() -> None:
    log = Path(sys.argv[1])
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else log.with_suffix(".summary.txt")
    if not log.exists():
        out.write_text(f"missing log {log}\n")
        return
    lines = log.read_text(errors="replace").splitlines()
    picked: list[str] = []
    seen: set[str] = set()
    for index, line in enumerate(lines):
        if any(p.search(line) for p in PATTERNS):
            block = lines[max(0, index - 2): index + 4]
            key = line.strip()
            if key in seen:
                continue
            seen.add(key)
            picked.append(f"--- line {index + 1}")
            picked.extend(block)
            if len(seen) >= 80:
                break
    tail = lines[-60:]
    errors = list(dict.fromkeys(l.strip() for l in lines if re.search(r"\.swift:\d+:\d+: error:", l)))
    out.write_text("\n".join(["# Errors"] + errors + ["", "# Matches"] + picked + ["", "# Tail"] + tail) + "\n")
    for key in list(seen)[:10]:
        message = key.replace("%", "%25").replace("\r", "").replace("\n", " ")[:900]
        print(f"::error::{message}")

if __name__ == "__main__":
    main()
