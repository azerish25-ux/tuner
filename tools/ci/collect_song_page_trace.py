#!/usr/bin/env python3
"""Collect bounded, opt-in simulator traces; never infer causal completeness or audit eligibility."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys

BUNDLE_ID = "com.shahradazerisharghi.timbre"
MAX_BYTES = 4 * 1024 * 1024
MAX_SESSIONS = 3
MAX_SCANNED_ENTRIES = 64
TRACE_PREFIX = "song-page-trace"
CURRENT = "song-page-trace.ndjson"
ALLOWED = {CURRENT, "song-page-trace.previous.ndjson"}
UUID_PATTERN = re.compile(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\Z")


class CollectionError(Exception):
    pass


def valid_uuid(value):
    return isinstance(value, str) and UUID_PATTERN.fullmatch(value) is not None


def no_symlinks(path, allow_missing=False):
    """Check every existing component, including the leaf, without following links."""
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        try:
            info = current.lstat()
        except FileNotFoundError:
            if allow_missing:
                return
            raise CollectionError("Missing source path") from None
        if stat.S_ISLNK(info.st_mode):
            raise CollectionError("Symlink path rejected")


def bounded_read(path, limit):
    no_symlinks(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
        raise CollectionError("Nonregular or oversized source file")
    if not hasattr(os, "O_NOFOLLOW"):
        raise CollectionError("No-follow file reads are unavailable")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_size > limit:
            raise CollectionError("Nonregular or oversized source file")
        data = stream.read(limit + 1)
        after = os.fstat(stream.fileno())
    no_symlinks(path)
    identity = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns)
    if (len(data) > limit or identity(before) != identity(after) or len(data) != after.st_size
            or identity(after) != identity(path.lstat())):
        raise CollectionError("Source file changed while reading or exceeded its bound")
    return data


def scoped_container(raw, device):
    if not isinstance(raw, str):
        raise CollectionError("Container response is not text")
    raw = raw.rstrip("\r\n")
    if (not raw.startswith("/") or any(p in (".", "..") for p in raw.split("/"))
            or "\n" in raw or "\r" in raw or "\x00" in raw):
        raise CollectionError("Invalid absolute container path")
    path = Path(raw)
    parts = path.parts
    if (len(parts) < 9 or parts[-8:-6] != ("CoreSimulator", "Devices")
            or parts[-5:-1] != ("data", "Containers", "Data", "Application")
            or not valid_uuid(parts[-6]) or parts[-6].upper() != device
            or not valid_uuid(parts[-1])):
        raise CollectionError("Container is outside the requested simulator data scope")
    no_symlinks(path)
    if not path.is_dir() or path.resolve(strict=True) != path:
        raise CollectionError("Container is not the exact resolved directory")
    metadata = bounded_read(path / ".com.apple.mobile_container_manager.metadata.plist", 1024 * 1024)
    try:
        value = plistlib.loads(metadata)
    except Exception as error:
        raise CollectionError("Malformed container metadata") from error
    if not isinstance(value, dict) or value.get("MCMMetadataIdentifier") != BUNDLE_ID:
        raise CollectionError("Container metadata has the wrong bundle identifier")
    return path


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError("Nonfinite JSON value: " + value)


def event_count(data, session):
    if not data or not data.endswith(b"\n"):
        raise CollectionError("Trace is empty or lacks its final LF")
    count = 0
    for line in data.split(b"\n")[:-1]:
        try:
            event = json.loads(line.decode("utf-8"), object_pairs_hook=unique_object,
                               parse_constant=invalid_constant)
        except (UnicodeError, ValueError, RecursionError) as error:
            raise CollectionError("Malformed trace JSON") from error
        if (not isinstance(event, dict) or type(event.get("schema")) is not int
                or event["schema"] != 1 or event.get("sessionID") != session
                or event.get("diagnosticOnly") is not True):
            raise CollectionError("Trace event schema, session or diagnostic scope mismatch")
        count += 1
    return count


def trace_plan(container):
    root = container / "Library/Application Support/TimbreUITests"
    no_symlinks(root)
    if not root.is_dir():
        raise CollectionError("Missing test-storage directory")
    sessions = []
    plan = []
    scanned = 0

    def entries(directory):
        nonlocal scanned
        result = []
        with os.scandir(directory) as iterator:
            for entry in iterator:
                scanned += 1
                if scanned > MAX_SCANNED_ENTRIES:
                    raise CollectionError("Test-storage scan exceeded its entry bound")
                if entry.is_symlink():
                    raise CollectionError("Symlink in test-storage directory")
                result.append(Path(entry.path))
        return sorted(result)

    for folder in entries(root):
        if folder.name.startswith(TRACE_PREFIX):
            raise CollectionError("Trace file outside a session directory")
        if not folder.is_dir():
            continue  # Ordinary AppStore data is neither copied nor interpreted.
        if not valid_uuid(folder.name):
            raise CollectionError("Invalid session directory")
        candidates = [f for f in entries(folder) if f.name.startswith(TRACE_PREFIX)]
        if not candidates:
            continue
        if len(sessions) >= MAX_SESSIONS:
            raise CollectionError("Too many trace sessions")
        names = {f.name for f in candidates}
        if CURRENT not in names or not names.issubset(ALLOWED):
            raise CollectionError("Missing current trace or unexpected trace file")
        sessions.append(folder.name)
        for source in sorted(candidates):
            data = bounded_read(source, MAX_BYTES)
            count = event_count(data, folder.name)
            plan.append((folder.name, source.name, data, count))
    if not sessions:
        raise CollectionError("No trace sessions found")
    return sessions, plan


def output_directory(value):
    path = Path(value).absolute()
    if "CoreSimulator" in path.parts:
        raise CollectionError("Output must be outside simulator storage")
    no_symlinks(path, allow_missing=True)
    if path.exists() and (not path.is_dir() or any(path.iterdir())):
        raise CollectionError("Output must be a new or empty directory")
    return path


def collect(device, output, runner=None):
    """Return a structured report. Copy nothing unless every source trace validates."""
    report = {"schema": 1, "diagnosticOnly": True, "bundleID": BUNDLE_ID,
              "deviceID": device, "status": "rejected", "sessions": [], "files": [],
              "eventCount": 0, "errors": [], "causalCompleteness": "not asserted"}
    destination = None
    try:
        destination = output_directory(output)
        if not valid_uuid(device):
            raise CollectionError("A canonical simulator UUID is required")
        device = device.upper()
        report["deviceID"] = device
        run = runner or subprocess.run
        result = run(["xcrun", "simctl", "get_app_container", device, BUNDLE_ID, "data"],
                     capture_output=True, text=True, timeout=30, check=False)
        if result.returncode != 0:
            raise CollectionError("simctl get_app_container failed")
        container = scoped_container(result.stdout, device)
        if destination == container or container in destination.parents:
            raise CollectionError("Output cannot modify app data")
        sessions, plan = trace_plan(container)
        destination.mkdir(parents=True, exist_ok=True)
        for session, name, data, count in plan:
            directory = destination / session
            directory.mkdir(exist_ok=True)
            with (directory / name).open("xb") as stream:
                stream.write(data)
            report["files"].append({"path": session + "/" + name, "bytes": len(data),
                                    "sha256": hashlib.sha256(data).hexdigest(), "events": count})
            report["eventCount"] += count
        report["sessions"] = sessions
        report["status"] = "collected"
    except (CollectionError, OSError, subprocess.SubprocessError) as error:
        report["errors"].append(str(error))
    if destination is not None:
        try:
            no_symlinks(destination, allow_missing=True)
            destination.mkdir(parents=True, exist_ok=True)
            with (destination / "manifest.json").open("x", encoding="utf-8") as stream:
                json.dump(report, stream, indent=2, sort_keys=True)
                stream.write("\n")
        except (CollectionError, OSError) as error:
            report["status"] = "rejected"
            report["errors"].append("Cannot write manifest: " + str(error))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    report = collect(args.device, args.output)
    print(json.dumps(report, sort_keys=True))
    return 0 if report["status"] == "collected" else 1


if __name__ == "__main__":
    sys.exit(main())
