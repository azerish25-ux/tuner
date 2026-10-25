#!/usr/bin/env python3
"""Compiler warnings as errors, from build logs: the gate that keeps the build clean while concurrency is cleared.

    python3 tools/ci/build_warnings.py ci-out/build.log                 # fail on any warning in our code (exit 1)
    python3 tools/ci/build_warnings.py ci-out/build.log --github --out ci-out/warnings

Every `path:line:col: warning:` line of an xcodebuild or `swift build` log is read once (a warning repeated across
architectures or targets counts once) and sorted into:

    sdk           raised inside Xcode's SDKs (a deprecated StoreKitTest type a test imports): reported, allowed
    allowed       matched by tools/ci/warnings-allowlist.json (each entry says why): reported, allowed
    concurrency   complete concurrency checking (SWIFT_STRICT_CONCURRENCY=complete, ios/project.yml; StrictConcurrency in
                  ios/Package.swift): counted per file for the team that owns it, allowed until TimbreCore and the
                  app move to the Swift 6 language mode
    other         everything else: fails, as SWIFT_TREAT_WARNINGS_AS_ERRORS would

Why a log gate and not SWIFT_TREAT_WARNINGS_AS_ERRORS: complete concurrency checking is on as warnings while each team
clears its own files, and the compiler can't promote every other warning to an error while leaving those alone. The
gate does exactly that; once the concurrency count is 0 the build setting replaces it.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ALLOWLIST = HERE / "warnings-allowlist.json"
WARNING = re.compile(r"^(?P<path>/[^:\n]+?\.(?:swift|h|m|mm|c|cpp|metal)):(?P<line>\d+):(?:(?P<col>\d+):)? "
                     r"warning: (?P<message>.+?)\s*$", re.M)
CONCURRENCY = re.compile(
    r"this is an error in the Swift 6 language mode|\bSendable\b|actor-isolated|global actor|main actor|@MainActor|"
    r"\bnonisolated\b|isolation|isolated\b|data race|concurrency-safe|concurrently-executing|\bsending\b|"
    r"captured var|Capture of .* with non-[Ss]endable|task-isolated|in a synchronous .*context|"
    r"not concurrency-safe|preconcurrency", re.I)


def repo_path(path: str) -> str | None:
    """The path inside this repository (`ios/…`), or None for a file outside it (an SDK header)."""
    marker = "/ios/"
    if "/Applications/" in path or ".sdk/" in path or ".platform/" in path:
        return None
    index = path.find(marker)
    return path[index + 1:] if index >= 0 else None


def read(logs: list[Path]) -> list[dict]:
    seen, found = set(), []
    for log in logs:
        text = log.read_text(encoding="utf-8", errors="replace")
        for match in WARNING.finditer(text):
            key = (match.group("path"), match.group("line"), match.group("message"))
            if key in seen:
                continue
            seen.add(key)
            found.append({"path": match.group("path"), "repo": repo_path(match.group("path")),
                          "line": int(match.group("line")), "message": match.group("message")})
    return found


def classify(found: list[dict], allowlist: list[dict]) -> dict:
    buckets = {"sdk": [], "allowed": [], "concurrency": [], "other": []}
    for item in found:
        if item["repo"] is None:
            buckets["sdk"].append(item)
            continue
        rule = next((r for r in allowlist if re.search(r["path"], item["repo"]) and re.search(r["message"], item["message"])), None)
        if rule:
            buckets["allowed"].append(item | {"why": rule.get("why", "")})
        elif CONCURRENCY.search(item["message"]):
            buckets["concurrency"].append(item)
        else:
            buckets["other"].append(item)
    return buckets


def escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("--allowlist", type=Path, default=ALLOWLIST)
    parser.add_argument("--github", action="store_true", help="emit GitHub annotations")
    parser.add_argument("--out", type=Path, help="write warnings.json and concurrency-by-file.json here")
    args = parser.parse_args(argv)

    logs = [log for log in args.logs if log.exists()]
    if not logs:
        print("No build log to read: " + ", ".join(map(str, args.logs)))
        return 1
    allowlist = json.loads(args.allowlist.read_text(encoding="utf-8")).get("allow", []) if args.allowlist.exists() else []
    buckets = classify(read(logs), allowlist)

    per_file: dict = {}
    for item in buckets["concurrency"]:
        per_file[item["repo"]] = per_file.get(item["repo"], 0) + 1
    print(f"Warnings: {len(buckets['other'])} to fix, {len(buckets['concurrency'])} concurrency "
          f"(in {len(per_file)} files), {len(buckets['allowed'])} allow-listed, {len(buckets['sdk'])} in SDK headers")
    for item in buckets["sdk"] + buckets["allowed"]:
        print(f"    allowed: {item['path'].rsplit('/', 1)[-1]}:{item['line']}: {item['message'][:140]}")
    for path, count in sorted(per_file.items(), key=lambda kv: (-kv[1], kv[0]))[:25]:
        print(f"    concurrency: {path}: {count}")
    if per_file and args.github:
        print(f"::notice title=Concurrency warnings::{len(buckets['concurrency'])} in {len(per_file)} files "
              f"(complete checking, Swift 5 mode). Each team clears its own; the list is in the job's results.")
    for item in buckets["other"]:
        print(f"ERROR {item['repo']}:{item['line']}: {item['message']}")
        if args.github:
            print(f"::error file={item['repo']},line={item['line']},title=Warning treated as an error::{escape(item['message'])}")
    if args.out:
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "warnings.json").write_text(json.dumps(buckets, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        (args.out / "concurrency-by-file.json").write_text(
            json.dumps(dict(sorted(per_file.items())), indent=1) + "\n", encoding="utf-8")
    if buckets["other"]:
        print(f"FAILED: {len(buckets['other'])} warnings in our code. Fix them (or, for a warning the code can't avoid, "
              f"add it to tools/ci/warnings-allowlist.json with the reason).")
        return 1
    print("OK: no warning outside concurrency checking and the allow-list")
    return 0


if __name__ == "__main__":
    sys.exit(main())
