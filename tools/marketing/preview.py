#!/usr/bin/env python3
"""App Store App Previews (6.9-inch iPhone, portrait) from the AppPreviewUITests tours.

Run by .github/workflows/preview.yml, in this order:

  preview.py device                        pick (or create) a 6.9-inch iPhone simulator; prints
                                           DEVICE_ID=... and DEVICE_NAME=... lines for $GITHUB_ENV
  preview.py record --device ID --out DIR [--handshake DIR --log LOG]
                                           start `simctl io ID recordVideo` in the background (DIR/raw.mp4) and
                                           note when it started (DIR/record.json). With --handshake it first waits
                                           for the tour to begin (the test's `begin` file, or PREVIEW-BEGIN in LOG)
                                           and answers with a `recording` file once the recorder runs
  preview.py stop --out DIR                stop it with SIGINT and wait until the file is written
  preview.py render --out DIR --log LOG [--attachments DIR] [--audio DIR] [--offset S] [--reanchor]
                                           cut the clips the test marked into DIR/preview.mp4 + DIR/poster.png
  preview.py check --out DIR               measure DIR/preview.mp4's sound again against its cut (DIR/cut.json)

What the test marks (wall-clock seconds; AppPreviewUITests.swift):
  PREVIEW-CLIP <name> <start> <end> <head|tail> [<shortest>] [anchor=<sync>]
                                           a stretch worth showing; the end that matters when the cut shortens it;
                                           never below <shortest> seconds; placed by that one sync when anchored
  PREVIEW-SYNC <label> <before> <after>    around each screenshot attached as `sync-<label>`
  PREVIEW-POSTER <time>                    the poster moment (just after the first lock)
  PREVIEW-REGION <label> <x> <y> <w> <h>   a region of the screen, as fractions (`readout`: the tuner's note and badge)
  PREVIEW-CARD <start> <end>               the app's sound for the end card (its motif, played for it)
  PREVIEW-BEAT <downbeat> <beat s> <meter> the band's clock: every cut lands on a beat of it
  PREVIEW-CHECK <name> <pass|fail> <why>   a check the test made (the highway's multiplier); a fail stops the cut
  PREVIEW-MISSED <what>                    a moment the tour waited for and didn't get (noted in PREVIEW.txt)
  PREVIEW-CUT <name>                       which preview ("guitar", "violin"): picks its captions
  PREVIEW-APP <folder>                     where the app wrote what it played (`--audio` overrides)

The recorder's own clock can't be trusted (simctl reported its start 3 s late in the first CI run, and a recording
can stop showing the app), so render finds each sync screenshot in the recording by its picture and maps every clip
through the nearest syncs; an anchored clip goes by its own sync alone, found to 1/60 s. The lock's sync is taken the
moment the app notes its lock, while the badge, the halo and the comet change the screen, so it pins that moment
down. A sync that isn't in the recording near a clip means the recording lost the app there: render then exits with
code 3 (preview.yml records the tour again).

The cut. Clips join with hard cuts (no cross-fade can double-expose two screens), in the tour's order, each trimmed
from its less important end to a whole number of the band's beats so every cut lands on the beat; the preview runs
20–25 s, then an end card. Each clip plays in a frame drawn here: its caption in Sora over a band of the clip's
accent (from the "### App Preview" tables in docs/ios/APP-STORE-LISTING.md), the app's picture below it, 9:41 status
bar and all. The soundtrack is the app's own sound at the moment each clip was filmed (soundtrack.py: the demo string
drifting into tune, the lock bells, the full-tune strum, Show me's chord, the band, the stars, the song's preview),
with each clip's tail ringing 0.6 s under the next; the app's motif under the end card; then loudness-normalised.
Encoded to Apple's App Preview spec: 886x1920 portrait, 30 fps, H.264 High, stereo AAC 44.1 kHz, 15-30 s.

What has to be true before it ships (gates.py measures the files; any failure is NOT FOR UPLOAD and a non-zero exit):
  - sound: no silence over 0.5 s anywhere; every clip sounding; under a "band" caption the band itself (its low end),
    and the app's own note that the band was playing while the clip was filmed;
  - lock: the readout's In tune badge shows in the lock clip, and its first frame is within 80 ms of the lock's bell
    (`--reanchor` places the lock clip by the badge instead, for a re-cut someone has looked at);
  - poster: the poster frame shows the badge (the marked moment, else the first frame after it that does);
  - the test's own checks passed (the highway at ×4).
Exit codes: 1 out of spec or a sound gate; 3 the recording lost the app; 4 the take missed a moment (the lock on camera,
the band, ×4): preview.yml records the tour again on 3 and 4.

render also writes DIR/PREVIEW.txt (clips, syncs, poster time, the gates), DIR/cut.json (the cut's layout, for `check`),
DIR/contact.png (a frame every second, to check the cut at a glance), DIR/sync.png (each sync screenshot beside the
recording's frame it matched) and DIR/raw-small.mp4 (the whole recording, small). `--offset` shifts every cut by hand
(positive = later).

Re-cut a CI run locally: download the preview-recording artifact (raw.mp4, record.json, take.log, attachments/,
app/) and run `python3 tools/marketing/preview.py render --out <folder> --log <folder>/take.log
--attachments <folder>/attachments --audio <folder>/app`. Needs ffmpeg and ffprobe (brew install ffmpeg) and Pillow
(python3 -m pip install pillow).
"""
from __future__ import annotations

import argparse
import json
import math
import operator
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import art  # noqa: E402
import gates  # noqa: E402
import soundtrack  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
LISTING = ROOT / "docs/ios/APP-STORE-LISTING.md"
WIDTH, HEIGHT, FPS = 886, 1920, 30
TARGET = 25.0                         # the cut aims at 20-25 s, end card included
LONGEST, SHORTEST = 29.5, 15.5        # Apple allows 15-30 s; stay clear of both edges
FLOOR = 1.5                           # a clip is never shortened below this (or its own <shortest>)
END_CARD = 2.2                        # seconds of end card, rounded to whole beats when the band's clock is known
TAIL = 0.6                            # a clip's sound rings this long under the next
POSTER_MARGIN = 0.25                  # the poster sits at least this far inside its clip
LOUDNESS = -16.0                      # integrated loudness target (LUFS) for the soundtrack
QUIETEST = -30.0                      # mean volume (dB) under which the preview counts as silent
SYNC_TOLERANCE = 0.08                 # the lock's bell and the badge's first frame, at most this far apart (s)
RETAKE = 4                            # render's exit code when a new take may fix it (the lock, the band, ×4)
PUBLISH_LIMIT = 44 * 1024 * 1024      # tools/ci/publish-results.sh leaves out files over 45 MB
APPLE_LIMIT = 500 * 1024 * 1024
PREFERRED = ("iPhone 17 Pro Max", "iPhone 16 Pro Max")

# The frame: a caption band on top, the app's picture below it, bleeding off the bottom edge (the tab bar's lower half).
BAND = 286                            # caption band height
SCREEN_W = 790                        # the app's picture, scaled to this width
SCREEN_X = (WIDTH - SCREEN_W) // 2
SCREEN_Y = BAND
SCREEN_RADIUS = 66

# Finding the sync screenshots in the recording: tiny grey pictures, 15 a second.
THUMB_W, THUMB_H, THUMB_FPS = 54, 117, 15
SYNC_WINDOW = 45.0      # seconds either side of where the recorder's clock puts a sync
PRESENT = 10.0          # mean difference (pictures normalised to a spread of 32) under which a sync is in the
                        # recording; the same screen scores about 1-3, another screen about 20
DISTINCT = 1.15         # the match beats the best one 1.5 s away by this factor: it pins the moment down
LOST = 3                # render's exit code when the recording lost the app in a clip

CLIP = re.compile(r"PREVIEW-CLIP (\S+) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (head|tail)(?: (\d+(?:\.\d+)?))?((?: \w+=\S+)*)")
SYNC = re.compile(r"PREVIEW-SYNC (\S+) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)")
POSTER = re.compile(r"PREVIEW-POSTER (\d+(?:\.\d+)?)")
REGION = re.compile(r"PREVIEW-REGION (\S+) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)")
CARD = re.compile(r"PREVIEW-CARD (\d+(?:\.\d+)?) (\d+(?:\.\d+)?)")
CHECK = re.compile(r"PREVIEW-CHECK (\S+) (pass|fail)(?: (.*))?$")
MISSED = re.compile(r"PREVIEW-MISSED (.+)$")
BEAT = re.compile(r"PREVIEW-BEAT (\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (\d+)")
CUT = re.compile(r"PREVIEW-CUT (\S+)")
APP = re.compile(r"PREVIEW-APP (.+)$")
BEGIN = re.compile(r"PREVIEW-BEGIN (\d+(?:\.\d+)?)")
END = re.compile(r"PREVIEW-END (\w+)")

# Each clip's accent when the listing's table names none: the tuner mint, Show me the guitar course's mint, the
# highway the Originals' sky, rewards the stars' gold, Songs the stage light.
DEFAULT_TINTS = {"lock": "mint", "tuned": "mint", "showme": "mint", "highway": "sky", "results": "gold",
                 "songs": "spotlight", "end": "mint"}


def run(cmd: list[str]) -> str:
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def version(text: str) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r"\d+", text))


# MARK: device


def rank(name: str):
    """Lower is better: the named 6.9-inch models first, then any Pro Max, newest model first."""
    if name in PREFERRED:
        return (0, PREFERRED.index(name))
    if re.search(r"\bPro Max\b", name):
        return (1, tuple(-n for n in version(name)))
    return None


def device_command(_args) -> None:
    listing = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"]))["devices"]
    # The newest iOS only (the preview shows the current system look); a Pro Max is created there if it has none.
    newest = max((r for r in listing if "iOS" in r), key=version, default=None)
    candidates = [d for d in listing.get(newest, []) if rank(d["name"]) is not None] if newest else []
    if candidates:
        best = min(candidates, key=lambda d: rank(d["name"]))
        udid, name, runtime = best["udid"], best["name"], newest
    else:
        types = json.loads(run(["xcrun", "simctl", "list", "devicetypes", "-j"]))["devicetypes"]
        runtimes = [r for r in json.loads(run(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))["runtimes"]
                    if r.get("platform") == "iOS" or ".iOS-" in r.get("identifier", "")]
        if not runtimes:
            sys.exit("No iOS simulator runtime is installed.")
        chosen = max(runtimes, key=lambda r: version(r.get("version", "")))
        choices = [t for t in (chosen.get("supportedDeviceTypes") or types) if rank(t["name"]) is not None]
        if not choices:
            sys.exit("No 6.9-inch (Pro Max) iPhone simulator type is available.")
        kind = min(choices, key=lambda t: rank(t["name"]))
        udid = run(["xcrun", "simctl", "create", "Timbre App Preview", kind["identifier"], chosen["identifier"]]).strip()
        name, runtime = kind["name"], chosen["identifier"]
    print(f"Using {name} on {runtime}: {udid}", file=sys.stderr)
    print(f"DEVICE_ID={udid}")
    print(f"DEVICE_NAME={name}")


# MARK: record / stop


def wait_for_start(proc: subprocess.Popen, log: Path, timeout: float):
    """The wall-clock moment simctl reports the recording started, or None."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        if re.search(r"recording started", log.read_text(errors="replace"), re.I):
            return time.time()
        if proc.poll() is not None:
            return None
        time.sleep(0.02)
    return None


def wait_for_tour(handshake: Path, log: Path | None, timeout: float = 45 * 60) -> str:
    """Blocks until the tour begins: the test's `begin` file in the shared folder, or (if the simulator can't
    write there) a PREVIEW-BEGIN line in the xcodebuild log written after this wait started."""
    skip = log.stat().st_size if log and log.exists() else 0
    deadline = time.time() + timeout
    while time.time() < deadline:
        if (handshake / "begin").exists():
            return "the test's begin file"
        if log and log.exists() and log.stat().st_size > skip:
            with open(log, "rb") as handle:
                handle.seek(skip)
                if b"PREVIEW-BEGIN" in handle.read():
                    return "PREVIEW-BEGIN in the log"
        time.sleep(0.2)
    sys.exit("The tour never began; nothing recorded.")


def record_command(args) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    raw, log = out / "raw.mp4", out / "record.log"
    handshake = Path(args.handshake) if args.handshake else None
    if handshake:
        handshake.mkdir(parents=True, exist_ok=True)
        print(f"Waiting for the tour to begin ({handshake})")
        print(f"The tour began ({wait_for_tour(handshake, Path(args.log) if args.log else None)}); starting the recorder")
    # Run simctl itself (not through xcrun), so SIGINT reaches the recorder.
    tool = run(["xcrun", "-f", "simctl"]).strip() or "simctl"
    # The unmasked framebuffer (square corners, like a QuickTime device recording); older simctl lacks --mask.
    for extra in (["--mask=ignored"], []):
        cmd = [tool, "io", args.device, "recordVideo", "--codec=h264", *extra, "--force", str(raw)]
        with open(log, "w") as handle:
            spawned = time.time()
            proc = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=handle, stderr=subprocess.STDOUT, start_new_session=True)
        started = wait_for_start(proc, log, timeout=15)
        if proc.poll() is None:
            break
        print(f"recordVideo stopped at once ({proc.returncode}): {log.read_text(errors='replace').strip()}", file=sys.stderr)
    else:
        sys.exit("Could not start the screen recording.")
    info = {
        "pid": proc.pid,
        "command": cmd,
        "spawned": spawned,
        "started": started if started else spawned + 1.0,
        "startSource": "simctl reported 'Recording started'" if started else "estimated: 1 s after launching simctl",
    }
    (out / "record.json").write_text(json.dumps(info, indent=2))
    if handshake:
        (handshake / "recording").write_text(str(info["started"]))
    print(f"Recording {raw} (pid {proc.pid}; start {info['startSource']})")


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def stop_command(args) -> None:
    out = Path(args.out)
    path = out / "record.json"
    if not path.exists():
        print("No recording to stop.")
        return
    info = json.loads(path.read_text())
    pid = info["pid"]
    if alive(pid):
        os.kill(pid, signal.SIGINT)
        deadline = time.time() + 120
        while alive(pid) and time.time() < deadline:
            time.sleep(0.2)
        if alive(pid):
            print("recordVideo ignored SIGINT; terminating it.", file=sys.stderr)
            os.kill(pid, signal.SIGTERM)
            time.sleep(3)
    else:
        print("recordVideo had already stopped.", file=sys.stderr)
    info["stopped"] = time.time()
    path.write_text(json.dumps(info, indent=2))
    raw = out / "raw.mp4"
    size = raw.stat().st_size if raw.exists() else 0
    print(f"raw.mp4: {size / 1e6:.1f} MB, recorded for {info['stopped'] - info['started']:.1f} s")
    if size == 0:
        print((out / "record.log").read_text(errors="replace"), file=sys.stderr)
        sys.exit("The recording is empty.")


# MARK: render


@dataclass
class Clip:
    name: str
    start: float      # seconds into the recording
    end: float
    keep: str         # "head" or "tail": the end that matters when the clip is shortened
    floor: float = FLOOR
    shift: float = 0.0  # recording time minus wall clock here (the sync mapping plus --offset)
    anchor: str | None = None  # the one sync that places this clip

    @property
    def length(self) -> float:
        return self.end - self.start

    @property
    def wall_start(self) -> float:
        return self.start - self.shift


def read_marks(texts: list[str]):
    """Clips, syncs, poster, regions, the end card's sound, the test's checks and misses, beat clock, cut name and app
    folder of the last run that marked any clips, from the first text that has them. A retried test prints a fresh
    PREVIEW-BEGIN, so earlier attempts are ignored."""
    for text in texts:
        runs: list[dict] = []

        def fresh() -> dict:
            return {"clips": [], "syncs": [], "poster": None, "result": None, "beat": None, "cut": None, "app": None,
                    "regions": {}, "card": None, "checks": [], "missed": []}

        for line in text.splitlines():
            if BEGIN.search(line):
                runs.append(fresh())
                continue
            found = {name: pattern.search(line) for name, pattern in
                     (("clip", CLIP), ("sync", SYNC), ("poster", POSTER), ("end", END), ("beat", BEAT), ("cut", CUT), ("app", APP),
                      ("region", REGION), ("card", CARD), ("check", CHECK), ("missed", MISSED))}
            if any(found.values()) and not runs:
                runs.append(fresh())
            current = runs[-1] if runs else None
            if found["clip"]:
                m = found["clip"]
                options = dict(item.split("=", 1) for item in m.group(6).split()) if m.group(6) else {}
                entry = (m.group(1), float(m.group(2)), float(m.group(3)), m.group(4),
                         float(m.group(5)) if m.group(5) else FLOOR, options.get("anchor"))
                if entry not in current["clips"]:
                    current["clips"].append(entry)
            elif found["region"]:
                m = found["region"]
                current["regions"][m.group(1)] = tuple(float(m.group(i)) for i in range(2, 6))
            elif found["card"]:
                current["card"] = (float(found["card"].group(1)), float(found["card"].group(2)))
            elif found["check"]:
                m = found["check"]
                entry = (m.group(1), m.group(2), (m.group(3) or "").strip())
                if entry not in current["checks"]:
                    current["checks"].append(entry)
            elif found["missed"]:
                text_missed = found["missed"].group(1).strip()
                if text_missed not in current["missed"]:
                    current["missed"].append(text_missed)
            elif found["sync"]:
                m = found["sync"]
                entry = (m.group(1), float(m.group(2)), float(m.group(3)))
                if entry not in current["syncs"]:
                    current["syncs"].append(entry)
            elif found["poster"]:
                current["poster"] = float(found["poster"].group(1))
            elif found["beat"]:
                m = found["beat"]
                current["beat"] = (float(m.group(1)), float(m.group(2)), int(m.group(3)))
            elif found["cut"]:
                current["cut"] = found["cut"].group(1)
            elif found["app"]:
                current["app"] = found["app"].group(1).strip()
            elif found["end"]:
                current["result"] = found["end"].group(1)
        for candidate in reversed(runs):
            if candidate["clips"]:
                return candidate
    return None


# MARK: finding the syncs


@dataclass
class Sync:
    """A screenshot the test took between `before` and `after` (wall clock), and where it is in the recording."""
    label: str
    before: float
    after: float
    picture: Path | None = None
    at: float | None = None           # seconds into the recording of the best-matching frame
    score: float | None = None        # its difference from the screenshot
    runner_up: float | None = None    # the best difference at least 1.5 s away
    fine: bool = False                # found again at 60 frames a second (a clip's anchor)

    @property
    def wall(self) -> float:
        return (self.before + self.after) / 2

    @property
    def present(self) -> bool:
        return self.score is not None and self.score <= PRESENT

    @property
    def distinct(self) -> bool:
        return self.present and self.runner_up is not None and self.runner_up >= self.score * DISTINCT + 0.05

    @property
    def offset(self) -> float:
        """Seconds into the recording minus wall clock, at this moment."""
        return self.at - self.wall


def sync_pictures(folder: Path | None) -> dict[str, Path]:
    """The test's `sync-<label>` screenshots among the exported xcresult attachments, by label."""
    found: dict[str, Path] = {}
    manifest = folder / "manifest.json" if folder else None
    if not manifest or not manifest.exists():
        return found
    for test in json.loads(manifest.read_text()):
        for item in test.get("attachments", []):
            named = re.match(r"sync-(.+)_\d+_[0-9A-Fa-f-]{36}", item.get("suggestedHumanReadableName", ""))
            if named and (folder / item["exportedFileName"]).exists():
                found[named.group(1)] = folder / item["exportedFileName"]
    return found


def index_recording(raw: Path, out: Path) -> list[bytes]:
    """One decode of the recording for two things: raw-small.mp4 (the whole run, small, for checking it) and a
    tiny grey picture of every 1/15 s, for finding the sync screenshots."""
    tiny = out / "tiny.gray"
    graph = (f"[0:v]fps={THUMB_FPS}:start_time=0,split=2[a][b];[a]scale=432:-2[small];"
             f"[b]scale={THUMB_W}:{THUMB_H}:flags=area,format=gray[tiny]")
    ffmpeg(["-i", str(raw), "-filter_complex", graph,
            "-map", "[small]", "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "32", str(out / "raw-small.mp4"),
            "-map", "[tiny]", "-f", "rawvideo", str(tiny)])
    data = tiny.read_bytes()
    tiny.unlink()
    size = THUMB_W * THUMB_H
    return [data[i:i + size] for i in range(0, len(data) - size + 1, size)]


def tiny_picture(path: Path) -> bytes:
    return subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-i", str(path),
                           "-vf", f"scale={THUMB_W}:{THUMB_H}:flags=area,format=gray", "-frames:v", "1", "-f", "rawvideo", "-"],
                          check=True, capture_output=True).stdout


def normalised(pixels: bytes) -> list[int]:
    """Mean 0, spread 32: a PNG screenshot and a video frame of the same screen differ in levels, not layout."""
    count = len(pixels)
    mean = sum(pixels) / count
    spread = max(4.0, (sum(map(operator.mul, pixels, pixels)) / count - mean * mean) ** 0.5)
    scale = 32 / spread
    return [int((value - mean) * scale) for value in pixels]


def distance(a: list[int], b: list[int]) -> float:
    return sum(map(abs, map(operator.sub, a, b))) / len(a)


def locate(syncs: list[Sync], frames: list[bytes], origin: float) -> None:
    """Finds each sync screenshot among the recording's frames within SYNC_WINDOW of where the clock puts it."""
    cache: dict[int, list[int]] = {}

    def frame(i: int) -> list[int]:
        if i not in cache:
            if len(cache) > 4000:
                cache.clear()
            cache[i] = normalised(frames[i])
        return cache[i]

    for sync in syncs:
        if not sync.picture:
            continue
        shot = tiny_picture(sync.picture)
        if len(shot) != THUMB_W * THUMB_H:
            continue
        target = normalised(shot)
        centre = (sync.wall - origin) * THUMB_FPS
        low = max(0, int(centre - SYNC_WINDOW * THUMB_FPS))
        high = min(len(frames), int(centre + SYNC_WINDOW * THUMB_FPS) + 1)
        if low >= high:
            continue
        coarse = {i: distance(target, frame(i)) for i in range(low, high, 2)}
        best = min(coarse, key=coarse.get)
        fine = {i: distance(target, frame(i)) for i in range(max(low, best - 2), min(high, best + 3))}
        best = min(fine, key=fine.get)
        away = [d for i, d in coarse.items() if abs(i - best) > 1.5 * THUMB_FPS]
        sync.at, sync.score = best / THUMB_FPS, fine[best]
        sync.runner_up = min(away) if away else None


def offset_near(wall: float, syncs: list[Sync], fallback: float) -> tuple[float, str]:
    """Recording time minus wall clock around `wall`: the median of the three nearest syncs that pin their moment
    down; else of the five nearest found at all (a still screen matches a little loosely); else the recorder's clock."""
    for wanted, count in ((lambda s: s.distinct, 3), (lambda s: s.present, 5)):
        usable = sorted((s for s in syncs if wanted(s)), key=lambda s: abs(s.wall - wall))[:count]
        if usable:
            offsets = sorted(s.offset for s in usable)
            return offsets[len(offsets) // 2], "syncs " + ", ".join(s.label for s in sorted(usable, key=lambda s: s.wall))
    return fallback, "recorder clock"


def still(frames: list[bytes], start: float, end: float) -> bool:
    """No change at all between the recording's frames in [start, end]: the recorder had stopped getting frames."""
    low, high = int(start * THUMB_FPS), min(len(frames) - 1, int(end * THUMB_FPS))
    return high > low and all(frames[i] == frames[low] for i in range(low, high + 1))


def sync_sheet(syncs: list[Sync], small: Path, dest: Path) -> None:
    """Each sync screenshot beside the recording's frame it matched, left to right in the order taken."""
    found = [s for s in syncs if s.picture and s.at is not None]
    if not found or not small.exists():
        return
    inputs: list[str] = []
    parts: list[str] = []
    for i, s in enumerate(found):
        inputs += ["-i", str(s.picture), "-ss", f"{s.at:.3f}", "-i", str(small)]
        parts.append(f"[{2 * i}:v]scale=-2:240,setsar=1[p{i}]")
        parts.append(f"[{2 * i + 1}:v]trim=end_frame=1,scale=-2:240,setsar=1[v{i}]")
    pairs = "".join(f"[p{i}][v{i}]" for i in range(len(found)))
    parts.append(f"{pairs}hstack=inputs={2 * len(found)}[sheet]")
    try:
        ffmpeg([*inputs, "-filter_complex", ";".join(parts), "-map", "[sheet]", "-frames:v", "1", str(dest)])
    except subprocess.CalledProcessError:
        print("Could not draw sync.png", file=sys.stderr)


# MARK: captions


def captions(cut: str | None) -> dict[str, tuple[str, str]]:
    """Clip name -> (caption, accent) from the listing's "### App Preview" table for this cut (the main preview's
    table, or the one whose heading names the cut, e.g. "### App Preview: violin page")."""
    found: dict[str, tuple[str, str]] = {}
    if not LISTING.exists():
        return found
    wanted = (cut or "guitar").lower()
    table = False
    for line in LISTING.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            heading = line.lstrip("#").strip().lower()
            if line.startswith("### ") and heading.startswith("app preview"):
                named = heading.split(":", 1)[1].strip() if ":" in heading else "guitar"
                table = named.startswith(wanted)
            else:
                table = False if line.startswith(("## ", "### ")) else table
            continue
        if table and line.startswith("|"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) < 2 or cells[0].lower() in ("clip", "") or set(cells[0]) <= set("-: "):
                continue
            name = cells[0].strip("`")
            caption = cells[1].replace("**", "").strip()
            accent = cells[2].strip("` ").lower() if len(cells) > 2 and cells[2].strip() else DEFAULT_TINTS.get(name, "mint")
            found[name] = (caption, accent)
    return found


# MARK: fitting the cut


def snap(seconds: float) -> float:
    return round(seconds * FPS) / FPS


def trim(clip: Clip, seconds: float) -> None:
    """Takes `seconds` off the clip's less important end."""
    if clip.keep == "head":
        clip.end -= seconds
    else:
        clip.start += seconds


def fit(clips: list[Clip], duration: float, end_card: float):
    """Clamps the clips to the recording, then shortens them (each from its less important end, none below its
    floor) until the cut and its end card run at most TARGET seconds, dropping the last clip only if even the floors
    don't fit 30 s. Returns the clips, seconds of end card and notes."""
    notes: list[str] = []
    kept = []
    for c in clips:
        c.start, c.end = snap(max(0.0, c.start)), snap(min(duration, c.end))
        if c.length >= 0.8:
            kept.append(c)
        else:
            notes.append(f"dropped {c.name}: outside the recording")
    clips = kept
    total = sum(c.length for c in clips) + end_card
    if total > TARGET:
        excess = total - TARGET
        room = [max(0.0, c.length - max(FLOOR, c.floor)) for c in clips]
        share = min(1.0, excess / sum(room)) if sum(room) > 0 else 0.0
        for c, r in zip(clips, room):
            trim(c, snap(r * share))
        while sum(c.length for c in clips) + end_card > LONGEST and len(clips) > 1:
            notes.append(f"dropped {clips.pop().name}: too long even at the clips' shortest")
    total = sum(c.length for c in clips) + end_card
    if total < SHORTEST and clips:
        end_card += SHORTEST + 0.3 - total
        notes.append(f"end card held {end_card:.1f} s to reach Apple's 15 s minimum")
    return clips, end_card, notes


def on_the_beat(clips: list[Clip], end_card: float, beat: float | None):
    """Each clip trimmed to a whole number of beats (from its less important end, never below its floor when it can
    be helped), and the end card too, so every cut falls on the band's beat. The highway clip starts on a downbeat
    already, so its beats line up with the cut's."""
    if not beat or beat <= 0.15:
        return end_card, []
    notes = []
    for c in clips:
        whole = math.floor(c.length / beat + 1e-6)
        if whole < 2:
            continue
        target = whole * beat
        if target < max(FLOOR, c.floor) - 1e-6 and whole + 1 <= c.length / beat + 0.5:
            target = (whole + 1) * beat
        if target < c.length:
            trim(c, c.length - target)
    card = max(2, round(end_card / beat)) * beat
    notes.append(f"cuts on the beat: {60 / beat:.0f} BPM, a cut every whole beat from the start")
    return card, notes


# MARK: the frame


def chrome(caption: str, accent: str, screen_h: int, dest: Path) -> None:
    """The frame around a clip, as an RGBA picture: the caption over the accent's band, the stage around the app's
    picture, and a transparent window (rounded on top) where the picture shows through."""
    from PIL import Image, ImageDraw
    canvas = art.backdrop((WIDTH, HEIGHT), accent, glow=(0.5, 0.05)).convert("RGBA")
    if caption:
        font, lines = art.fit_lines(caption, "SemiBold", 80, 58, WIDTH - 2 * SCREEN_X)
        step = int(font.size * 1.08)
        top = (BAND - step * len(lines)) // 2 + 6
        art.text_block(canvas, lines, font, WIDTH / 2, top, art.INK, leading=1.08)
    # A thin rim of the accent around the picture, then the window cut out of the frame.
    window = Image.new("L", (WIDTH, HEIGHT), 0)
    box = [SCREEN_X, SCREEN_Y, SCREEN_X + SCREEN_W - 1, SCREEN_Y + screen_h + SCREEN_RADIUS]
    ImageDraw.Draw(window).rounded_rectangle(box, radius=SCREEN_RADIUS, fill=255)
    rim = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(rim).rounded_rectangle([box[0] - 3, box[1] - 3, box[2] + 3, box[3] + 3], radius=SCREEN_RADIUS + 3, fill=255)
    canvas.paste(Image.new("RGBA", (WIDTH, HEIGHT), art.mix(art.STAGE, art.tint(accent), 0.45) + (255,)), (0, 0), rim)
    alpha = canvas.getchannel("A")
    alpha.paste(0, (0, 0), window)
    canvas.putalpha(alpha)
    canvas.save(dest)


def end_card(title: str, line: str, note: str, accent: str, dest: Path) -> None:
    """The last frame: the icon, the name, what it does, and the two facts that decide a tuner install."""
    canvas = art.backdrop((WIDTH, HEIGHT), accent, glow=(0.5, 0.40), wash=1.2).convert("RGBA")
    icon = art.app_icon(236)
    art.drop_shadow(canvas, (WIDTH / 2 - 118, 560, WIDTH / 2 + 118, 796), 53, 30, 150, 18)
    canvas.alpha_composite(icon, (WIDTH // 2 - 118, 560))
    y = art.text_block(canvas, [title], art.sora("SemiBold", 104), WIDTH / 2, 850, art.INK)
    font, lines = art.fit_lines(line, "Medium", 54, 40, WIDTH - 120)
    y = art.text_block(canvas, lines, font, WIDTH / 2, y + 30, art.INK, leading=1.15)
    if note:
        small, rows = art.fit_lines(note, "Medium", 38, 30, WIDTH - 140, lines=1)
        art.text_block(canvas, rows, small, WIDTH / 2, y + 36, art.mix(art.INK, art.tint(accent), 0.35))
    canvas.convert("RGB").save(dest)


# MARK: encoding


def probe(path: Path) -> dict:
    return json.loads(run(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)]))


def ffmpeg(args: list[str]) -> None:
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y", *args], check=True)


def color_args(raw_info: dict) -> list[str]:
    """Keep the recording's colour tags (BT.709 when it has none): scaling leaves the pixels as they were."""
    video = next(s for s in raw_info["streams"] if s["codec_type"] == "video")
    tags = {"color_primaries": "bt709", "color_trc": "bt709", "colorspace": "bt709"}
    for flag, key in (("color_primaries", "color_primaries"), ("color_trc", "color_transfer"), ("colorspace", "color_space")):
        value = video.get(key)
        if value and value not in ("unknown", "reserved"):
            tags[flag] = value
    return [arg for flag, value in tags.items() for arg in (f"-{flag}", value)]


def cut_window(raw: Path, base: float, top: float, dest: Path) -> None:
    """The stretch of the recording the clips use, at constant 30 fps and the frame's picture width. simctl writes a
    frame only when the screen changes; the fps filter fills the gaps, so every 1/30 s has a frame to cut on."""
    vf = (f"fps={FPS}:start_time=0,trim=start={base:.4f}:end={top:.4f},setpts=PTS-STARTPTS,"
          f"scale={SCREEN_W}:-2:flags=lanczos,setsar=1,format=yuv420p")
    ffmpeg(["-i", str(raw), "-an", "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "12", "-g", str(FPS), str(dest)])


def encode(window: Path, clips: list[Clip], base: float, frames: list[Path], card: Path, card_length: float,
           audio: Path, dest: Path, color: list[str], crf: int, rate: str) -> float:
    """One pass: each clip trimmed out of the window, set in its frame, the end card after them (hard cuts), and the
    soundtrack loudness-normalised under it."""
    count = len(clips)
    inputs = ["-i", str(window)]
    for c, frame in zip(clips, frames):
        inputs += ["-loop", "1", "-framerate", str(FPS), "-t", f"{c.length + 1:.3f}", "-i", str(frame)]
    inputs += ["-loop", "1", "-framerate", str(FPS), "-t", f"{card_length + 1:.3f}", "-i", str(card)]
    inputs += ["-i", str(audio)]
    parts = [f"[0:v]split={count}" + "".join(f"[s{i}]" for i in range(count))] if count > 1 else []
    for i, c in enumerate(clips):
        source = f"[s{i}]" if count > 1 else "[0:v]"
        # Half-frame margins keep each boundary frame on the intended side.
        first, last = c.start - base - 0.5 / FPS, c.end - base - 0.5 / FPS
        frames_in = round(c.length * FPS)
        parts.append(f"{source}trim=start={max(0.0, first):.4f}:end={last:.4f},setpts=PTS-STARTPTS[p{i}]")
        parts.append(f"[{i + 1}:v]format=rgba,split[f{i}a][f{i}b]")
        parts.append(f"[f{i}a][p{i}]overlay={SCREEN_X}:{SCREEN_Y}:shortest=1[u{i}]")
        parts.append(f"[u{i}][f{i}b]overlay=0:0:shortest=1,trim=end_frame={frames_in},fps={FPS},format=yuv420p,setsar=1[c{i}]")
    card_frames = round(card_length * FPS)
    parts.append(f"[{count + 1}:v]trim=end_frame={card_frames},fps={FPS},format=yuv420p,setsar=1[card]")
    parts.append("".join(f"[c{i}]" for i in range(count)) + f"[card]concat=n={count + 1}:v=1:a=0[v]")
    parts.append(f"[{count + 2}:a]loudnorm=I={LOUDNESS}:LRA=11:TP=-1.5,aresample=44100[a]")
    total = (sum(round(c.length * FPS) for c in clips) + card_frames) / FPS
    ffmpeg([
        *inputs,
        "-filter_complex", ";".join(parts), "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
        "-crf", str(crf), "-maxrate", rate, "-bufsize", f"{2 * int(rate.rstrip('M'))}M", "-g", str(FPS), "-r", str(FPS),
        *color,
        "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
        "-t", f"{total:.4f}", "-movflags", "+faststart", str(dest),
    ])
    return total


def loudness(path: Path) -> tuple[float, float]:
    """Mean and max volume of the file's audio in dB (ffmpeg volumedetect); -inf for silence."""
    result = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-i", str(path), "-map", "0:a:0", "-af", "volumedetect",
                             "-f", "null", "-"], capture_output=True, text=True)
    mean = re.search(r"mean_volume: (-?[\d.]+|-inf) dB", result.stderr)
    peak = re.search(r"max_volume: (-?[\d.]+|-inf) dB", result.stderr)

    def value(m):
        return float("-inf") if not m or m.group(1) == "-inf" else float(m.group(1))
    return value(mean), value(peak)


def poster_time(clips: list[Clip], poster_wall: float | None) -> tuple[float, str]:
    """Where the marked poster moment lands in the cut, clamped POSTER_MARGIN inside its clip so it is never the
    first or last frame of a cut; the middle of the first clip without a mark."""
    offset = 0.0
    if poster_wall is not None:
        for c in clips:
            if c.wall_start - 0.5 <= poster_wall <= c.wall_start + c.length + 0.5:
                inside = min(max(poster_wall - c.wall_start, POSTER_MARGIN), c.length - POSTER_MARGIN)
                return snap(offset + inside), c.name
            offset += c.length
    return snap(clips[0].length / 2), clips[0].name


def check(path: Path) -> tuple[dict, list[str]]:
    """The App Store App Preview checks for a 6.9-inch iPhone, portrait."""
    info = probe(path)
    video = next((s for s in info["streams"] if s["codec_type"] == "video"), {})
    audio = next((s for s in info["streams"] if s["codec_type"] == "audio"), None)
    problems = []
    if video.get("codec_name") != "h264" or video.get("profile") != "High":
        problems.append(f"video is {video.get('codec_name')} {video.get('profile')}, not H.264 High")
    if (video.get("width"), video.get("height")) != (WIDTH, HEIGHT):
        problems.append(f"video is {video.get('width')}x{video.get('height')}, not {WIDTH}x{HEIGHT}")
    if video.get("avg_frame_rate") != f"{FPS}/1":
        problems.append(f"frame rate is {video.get('avg_frame_rate')}, not {FPS}")
    if video.get("pix_fmt") != "yuv420p":
        problems.append(f"pixel format is {video.get('pix_fmt')}, not yuv420p")
    if not audio or audio.get("codec_name") != "aac" or int(audio.get("sample_rate", 0)) != 44100 or audio.get("channels") != 2:
        problems.append("no stereo 44.1 kHz AAC audio track")
    duration = float(info["format"]["duration"])
    if not 15 <= duration <= 30:
        problems.append(f"duration is {duration:.2f} s, not 15-30 s")
    if path.stat().st_size > APPLE_LIMIT:
        problems.append("file is over 500 MB")
    return info, problems


def contact_sheet(preview: Path, total: float, dest: Path) -> None:
    """A frame every second, eight to a row, to check the cut at a glance."""
    count = max(1, int(total))
    rows = math.ceil(count / 8)
    try:
        ffmpeg(["-i", str(preview), "-vf", f"fps=1,scale=180:-2,tile=8x{rows}:padding=6:color=black", "-frames:v", "1", str(dest)])
    except subprocess.CalledProcessError:
        print("Could not draw contact.png", file=sys.stderr)


def timecode(seconds: float) -> str:
    whole = int(seconds)
    return f"00:{whole // 60:02d}:{whole % 60:02d}.{int(round((seconds - whole) * 100)):02d}"


def refine(syncs: list[Sync], labels: set[str], raw: Path) -> None:
    """The syncs that anchor a clip, found again to 1/60 s around their coarse match (15 frames a second): a clip
    placed by one sync alone is only as exact as that sync."""
    for sync in syncs:
        if sync.label not in labels or not sync.present or not sync.picture or sync.at is None:
            continue
        shot = tiny_picture(sync.picture)
        if len(shot) != THUMB_W * THUMB_H:
            continue
        try:
            found = gates.refine_sync(raw, normalised(shot), sync.at, normalised, distance, THUMB_W, THUMB_H)
        except subprocess.CalledProcessError:
            found = None
        if found and found[1] <= PRESENT:
            sync.at, sync.score = found
            sync.fine = True


@dataclass
class LockCheck:
    """The lock clip's bell against its badge's first frame in the recording."""
    lines: list[str] = field(default_factory=list)
    retakes: list[str] = field(default_factory=list)
    badge: gates.Badge | None = None
    series: list[tuple[float, float]] = field(default_factory=list)


def check_lock(clips: list[Clip], app_audio: soundtrack.AppAudio, region, raw: Path, reanchor: bool) -> LockCheck:
    """Finds the readout's In tune badge in the recording around the lock's bell (the app's own cue, on the clip's
    mapping) and measures how far apart they are. With `reanchor`, a drift moves the clip's picture onto the bell."""
    result = LockCheck()
    lock = next((c for c in clips if c.name == "lock"), None)
    if lock is None:
        return result
    if not region:
        result.lines.append("lock: no readout region marked (PREVIEW-REGION readout); the badge and the poster aren't checked")
        return result
    noted = [e["t"] for e in app_audio.moments("lock") if lock.wall_start - 1 <= e["t"] <= lock.wall_start + lock.length + 1]
    if not noted:
        result.retakes.append("the app noted no lock while the lock clip was filmed")
        return result
    bell = app_audio.first_cue(noted[0] - 0.3, noted[0] + 0.3)
    expected = (bell.time if bell else noted[0]) + lock.shift
    try:
        result.series = gates.mint_series(raw, region, max(0.0, expected - 1.2), expected + 1.6)
    except subprocess.CalledProcessError:
        result.series = []
    result.badge = gates.badge_onset(result.series, expected)
    if result.badge is None:
        result.lines.append(f"lock: no In tune badge in the readout within 1.2 s of the bell ({expected:.2f} s in the recording)")
        result.retakes.append("the lock's In tune badge never shows in the lock clip")
        return result
    drift = result.badge.onset - expected
    source = "its cue" if bell else "the app's lock"
    result.lines.append(f"lock: the bell ({source}) at {expected:.3f} s in the recording, the badge's first frame at "
                        f"{result.badge.onset:.3f} s: {drift * 1000:+.0f} ms (at most ±{SYNC_TOLERANCE * 1000:.0f}); readout mint "
                        f"{result.badge.before:.1%} before, {result.badge.peak:.1%} locked")
    if abs(drift) > SYNC_TOLERANCE:
        if reanchor:
            lock.start, lock.end, lock.shift = lock.start + drift, lock.end + drift, lock.shift + drift
            result.lines.append(f"lock: re-anchored on the badge (--reanchor): the picture moved {drift * 1000:+.0f} ms")
        else:
            result.retakes.append(f"sound and picture drift {drift * 1000:+.0f} ms at the lock (the bell against the badge's "
                                  f"first frame; at most ±{SYNC_TOLERANCE * 1000:.0f} ms)")
    if not lock.start + 0.1 <= result.badge.onset <= lock.end - 0.3:
        result.retakes.append(f"the lock ({result.badge.onset:.2f} s) falls outside its clip ({lock.start:.2f}-{lock.end:.2f} s)")
    return result


def share_at(series: list[tuple[float, float]], moment: float) -> float | None:
    """The readout's mint share in the frame nearest `moment` (None outside the measured stretch)."""
    if not series or not series[0][0] - 0.02 <= moment <= series[-1][0] + 0.02:
        return None
    return min(series, key=lambda point: abs(point[0] - moment))[1]


def verify_poster(clips: list[Clip], poster_at: float, poster_clip: str, lock: LockCheck) -> tuple[float, str, str | None]:
    """The poster's time in the cut, what was verified, and the problem when no frame of the lock clip shows the badge.
    The marked moment first; else the first frame from a quarter second after the badge's onset that shows it."""
    if lock.badge is None or not lock.series:
        return poster_at, "not verified (no badge measured)", None
    offset = 0.0
    clip = None
    for c in clips:
        if c.name == "lock":
            clip = c
            break
        offset += c.length
    if clip is None:
        return poster_at, "not verified (no lock clip)", None

    def shows(cut_time: float) -> float | None:
        share = share_at(lock.series, clip.start + (cut_time - offset))
        return share if share is not None and lock.badge.shown(share) else None

    if poster_clip == "lock" and shows(poster_at) is not None:
        return poster_at, f"verified: the badge shows (readout mint {shows(poster_at):.1%})", None
    first = max(offset + POSTER_MARGIN, offset + (lock.badge.onset - clip.start) + 0.25)
    last = offset + clip.length - POSTER_MARGIN
    moment = snap(first)
    while moment <= last:
        if shows(moment) is not None:
            return moment, f"moved to the first frame that shows the badge (readout mint {shows(moment):.1%})", None
        moment = snap(moment + 1 / FPS)
    return poster_at, "NOT verified", ("the poster can't show the lock: no frame of the lock clip from a quarter second after "
                                       "the badge's first frame still shows it (the tuner's lock doesn't hold on screen)")


def render_command(args) -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            sys.exit(f"{tool} is missing: brew install ffmpeg")
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit("Pillow is missing: python3 -m pip install pillow")
    out = Path(args.out)
    raw = out / "raw.mp4"
    if not raw.exists() or raw.stat().st_size == 0:
        sys.exit(f"No recording at {raw}")
    try:
        offset = float(args.offset or 0)
    except ValueError:
        sys.exit(f"--offset must be a number of seconds, not {args.offset!r}")
    if not (out / "record.json").exists():
        sys.exit(f"No {out / 'record.json'}: it says when the recording started (written by `preview.py record`).")
    record = json.loads((out / "record.json").read_text())
    clock = -record["started"]                   # the recorder's word: recording time = wall clock + clock
    raw_info = probe(raw)
    duration = float(raw_info["format"]["duration"])
    raw_video = next(s for s in raw_info["streams"] if s["codec_type"] == "video")
    screen_h = round(SCREEN_W * int(raw_video["height"]) / int(raw_video["width"]))
    screen_h += screen_h % 2

    texts = [Path(p).read_text(errors="replace") for p in (args.log or []) if Path(p).exists()]
    attachments = Path(args.attachments) if args.attachments and Path(args.attachments).is_dir() else None
    if attachments:
        texts.append("\n".join(p.read_text(errors="replace") for p in sorted(attachments.rglob("*.txt"))))
    marks = read_marks(texts)
    print(f"Indexing {raw.name} ({duration:.1f} s)")
    (out / "sync.png").unlink(missing_ok=True)
    frames = index_recording(raw, out)
    notes: list[str] = []
    problems: list[str] = []     # out of spec, or a sound gate: the cut can't ship
    retakes: list[str] = []      # the take missed a moment: a new take may fix it
    syncs: list[Sync] = []
    lost: list[str] = []
    sources: dict[str, str] = {}
    poster_wall = None
    beat = None
    cut_name = None
    regions: dict = {}
    card_stretch = None
    app_folder = Path(args.audio) if args.audio else None
    if marks:
        cut_name = marks["cut"]
        if not app_folder and marks["app"]:
            app_folder = Path(marks["app"])
        pictures = sync_pictures(attachments)
        syncs = [Sync(label, before, after, pictures.get(label)) for label, before, after in marks["syncs"]]
        locate(syncs, frames, record["started"])
        refine(syncs, {entry[5] for entry in marks["clips"] if entry[5]}, raw)
        missing = [s for s in syncs if s.picture and not s.present]
        clips = []
        for name, start, end, keep, floor, anchor in marks["clips"]:
            pinned = next((s for s in syncs if s.label == anchor and s.present), None) if anchor else None
            if pinned:
                shift = pinned.offset
                sources[name] = f"sync {pinned.label}" + (", to 1/60 s" if pinned.fine else "")
            else:
                shift, sources[name] = offset_near((start + end) / 2, syncs, clock)
                if anchor:
                    notes.append(f"WARNING: {name}'s own sync ({anchor}) isn't in the recording; placed by {sources[name]}")
            clips.append(Clip(name, start + shift + offset, end + shift + offset, keep, floor, shift + offset, anchor))
            # A screenshot taken in or right around the clip that the recording doesn't show: the app is missing there.
            gone = [s.label for s in missing if start - 4 <= s.wall <= end + 4]
            if gone:
                lost.append(f"{name} (sync {', '.join(gone)} not in the recording)")
        poster_wall = marks["poster"]
        beat = marks["beat"][1] if marks["beat"] else None
        regions = marks["regions"]
        card_stretch = marks["card"]
        if marks["result"] != "passed":
            notes.append(f"WARNING: the tour test {marks['result'] or 'did not finish'}; check the cut before using it")
        if syncs and not any(s.picture for s in syncs):
            notes.append("WARNING: no sync screenshots among the attachments; the cut follows the recorder's clock")
        notes += [f"WARNING: the tour missed a moment: {missed}" for missed in marks["missed"]]
        for name, verdict, why in marks["checks"]:
            if verdict == "fail":
                retakes.append(f"the tour's check {name} failed: {why}")
            else:
                notes.append(f"check {name}: {why or 'passed'}")
    else:
        # No marks (the test never got going): skip the launch and keep what fits.
        start = min(12.0, duration * 0.25)
        clips = [Clip("fallback", start, min(duration - 1, start + 20), "head", FLOOR, clock + offset)]
        notes.append("WARNING: no PREVIEW-CLIP marks found; this is a plain trim of the recording")
    marked = sum(max(0.0, c.length) for c in clips) + END_CARD
    clips, card_length, fitted = fit(clips, duration, END_CARD)
    notes += fitted
    if not clips:
        sys.exit("None of the marked clips fall inside the recording; check record.json and --offset.")
    card_length, beaten = on_the_beat(clips, card_length, beat)
    notes += beaten
    for c in clips:
        if still(frames, c.start, c.end):
            notes.append(f"WARNING: {c.name} doesn't move at all: the recorder may have stopped getting frames there")

    # The lock: its bell against the badge's first frame (with --reanchor the clip may move here, before the cut).
    app_audio = soundtrack.AppAudio(app_folder if app_folder and app_folder.is_dir() else None)
    lock = check_lock(clips, app_audio, regions.get("readout"), raw, args.reanchor)
    retakes += lock.retakes

    # The frames: a caption band per clip, and the end card.
    words = captions(cut_name)
    art_dir = out / "frames"
    art_dir.mkdir(exist_ok=True)
    frame_paths = []
    for i, c in enumerate(clips):
        caption, accent = words.get(c.name, ("", DEFAULT_TINTS.get(c.name, "mint")))
        if not caption:
            notes.append(f"WARNING: no caption for clip {c.name} in {LISTING.name}'s App Preview table")
        path = art_dir / f"{i:02d}-{c.name}.png"
        chrome(caption, accent, screen_h, path)
        frame_paths.append(path)
    title, end_accent = words.get("end", ("Tune. Learn. Play songs.", "mint"))
    note = words.get("end-note", ("Free tuner · No ads · No account", "mint"))[0]
    card = art_dir / "end.png"
    end_card("Timbre", title, note, end_accent, card)

    # The soundtrack: each clip's own sound, from the app's log, and the app's motif under the end card.
    pieces = []
    at = 0.0
    for c in clips:
        pieces.append((app_audio.segment(c.wall_start, c.length + TAIL), at, c.length))
        at += c.length
    if card_stretch:
        pieces.append((app_audio.segment(card_stretch[0], card_length), at, card_length))
    else:
        notes.append("WARNING: no PREVIEW-CARD mark: the end card has no sound of its own")
    total_audio = at + card_length
    mix = soundtrack.lay(pieces, total_audio, TAIL)
    audio_path = out / "soundtrack.wav"
    peak = soundtrack.write_wav(audio_path, mix)
    if not app_audio.present:
        notes.append(f"WARNING: no app audio at {app_folder or '(no folder)'}: the preview is silent")
    notes += [f"app audio note: {text}" for text in app_audio.notes]

    base = max(0.0, snap(min(c.start for c in clips) - 1))
    top = min(duration, max(c.end for c in clips) + 1)
    window = out / "window.mp4"
    print(f"Cutting {len(clips)} clips")
    cut_window(raw, base, top, window)
    color = color_args(raw_info)
    preview = out / "preview.mp4"
    for crf, rate in ((18, "10M"), (21, "8M"), (24, "6M")):
        total = encode(window, clips, base, frame_paths, card, card_length, audio_path, preview, color, crf, rate)
        if preview.stat().st_size <= PUBLISH_LIMIT:
            break
    window.unlink(missing_ok=True)

    poster_at, poster_clip = poster_time(clips, poster_wall)
    poster_at, poster_verdict, poster_problem = verify_poster(clips, poster_at, poster_clip, lock)
    if poster_problem:
        retakes.append(poster_problem)
    poster_at = min(max(0.1, poster_at), total - 0.1)
    ffmpeg(["-ss", f"{poster_at:.3f}", "-i", str(preview), "-frames:v", "1", str(out / "poster.png")])
    sync_sheet(syncs, out / "raw-small.mp4", out / "sync.png")
    contact_sheet(preview, total, out / "contact.png")

    info, spec = check(preview)
    problems += [f"OUT OF SPEC: {p}" for p in spec]
    mean, loudest = loudness(preview)
    if mean < QUIETEST:
        problems.append(f"the soundtrack is silent or nearly (mean {mean:.1f} dB, under {QUIETEST:.0f} dB)")

    # The sound gates, on the delivered file; and the app's own word on the band while each "band" clip was filmed.
    sections = []
    at = 0.0
    for c in clips:
        sections.append(gates.Section(c.name, at, at + c.length, words.get(c.name, ("", ""))[0]))
        at += c.length
    sections.append(gates.Section("end card", at, at + card_length))
    sound_lines, silent, bandless = gates.sound_report(preview, sections)
    problems += silent
    retakes += bandless
    for section, c in zip(sections, clips):
        if section.promises_band and app_audio.band_playing(c.wall_start, c.wall_start + c.length) is False:
            retakes.append(f"{c.name}: the app's band wasn't playing all through the clip (its `band` events)")
    write_cut(out / "cut.json", cut_name, sections, poster_at, total)

    size = preview.stat().st_size
    pinned = sorted(s.offset for s in syncs if s.distinct)
    lines = [
        f'App Store App Preview ({cut_name or "guitar"}): iPhone 6.9" display, portrait',
        f"preview.mp4: {WIDTH}x{HEIGHT}, {FPS} fps, H.264 High, stereo AAC 44.1 kHz, "
        f"{float(info['format']['duration']):.2f} s, {size / 1e6:.1f} MB (the marked clips and end card ran {marked:.1f} s)",
        f"soundtrack: mean {mean:.1f} dB, max {loudest:.1f} dB (normalised to {LOUDNESS:.0f} LUFS; the app's mix peaked at "
        f"{peak:.2f}); {len(app_audio.cues)} sound effects and {len(app_audio.runs)} stretches of engine sound logged",
        f"poster.png: the frame at {timecode(poster_at)} (in {poster_clip}), {poster_verdict}. In App Store Connect, set the "
        "preview's poster frame to this time.",
        f"recording: {os.environ.get('DEVICE_NAME', 'simulator')}, {duration:.1f} s; start {record.get('startSource')}; "
        f"manual offset {offset:+.2f} s",
    ]
    if pinned:
        lines.append(f"syncs vs the recorder's clock: {pinned[len(pinned) // 2] - clock:+.2f} s (median of {len(pinned)} pinned syncs)")
    lines += ["", "clips (seconds into the recording -> into the preview; caption; placed by):"]
    at = 0.0
    for c in clips:
        caption = words.get(c.name, ("(none)", ""))[0]
        lines.append(f"  {c.name:<9} {c.start:7.2f}-{c.end:7.2f} -> {at:5.2f}-{at + c.length:5.2f}  keep {c.keep}  "
                     f"“{caption}”  ({sources.get(c.name, 'recorder clock')})")
        at += c.length
    lines.append(f"  {'end card':<9} {'':15}    {at:5.2f}-{at + card_length:5.2f}  “{title}”")
    if syncs:
        lines += ["", "syncs (the test's screenshots, found in the recording; sync.png shows each beside its frame):"]
        for s in syncs:
            if not s.picture:
                lines.append(f"  {s.label:<14} no screenshot among the attachments")
            elif s.at is None:
                lines.append(f"  {s.label:<14} outside the recording")
            else:
                verdict = "pinned" if s.distinct else ("found, not distinctive" if s.present else "NOT IN THE RECORDING")
                runner = f"{s.runner_up:5.1f}" if s.runner_up is not None else "  -  "
                lines.append(f"  {s.label:<14} at {s.at:7.2f} s  diff {s.score:5.1f} (next {runner})  "
                             f"vs clock {s.offset - clock:+7.2f} s  {verdict}{', to 1/60 s' if s.fine else ''}")
    lines += [""] + lock.lines + sound_lines + [""] + notes
    if lost:
        lines += [f"LOST: the recording doesn't show the app in {item}" for item in lost]
    lines += [f"NOT FOR UPLOAD: {p}" for p in problems + retakes]
    if lost:
        lines.append("NOT FOR UPLOAD: record the tour again.")
    elif not problems and not retakes:
        lines.append("Meets the App Preview spec and its gates.")
    (out / "PREVIEW.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if lost:
        sys.exit(LOST)
    if problems:
        sys.exit(1)
    if retakes:
        sys.exit(RETAKE)


def write_cut(path: Path, cut_name: str | None, sections: list[gates.Section], poster_at: float, total: float) -> None:
    """The cut's layout beside preview.mp4, so `check` can measure the file again on its own."""
    path.write_text(json.dumps({
        "cut": cut_name or "guitar",
        "total": round(total, 3),
        "poster": round(poster_at, 3),
        "sections": [{"name": s.name, "start": round(s.start, 3), "end": round(s.end, 3), "caption": s.caption} for s in sections],
    }, indent=2) + "\n")


def check_command(args) -> None:
    """The sound gates again on a rendered preview (DIR/preview.mp4 and DIR/cut.json)."""
    out = Path(args.out)
    preview, layout = out / "preview.mp4", out / "cut.json"
    if not preview.exists() or not layout.exists():
        sys.exit(f"{out} needs preview.mp4 and cut.json (both written by `preview.py render`)")
    cut = json.loads(layout.read_text())
    sections = [gates.Section(s["name"], float(s["start"]), float(s["end"]), s.get("caption", "")) for s in cut["sections"]]
    lines, silent, bandless = gates.sound_report(preview, sections)
    print("\n".join(lines))
    for problem in silent + bandless:
        print(f"NOT FOR UPLOAD: {problem}")
    sys.exit(1 if silent or bandless else 0)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("device", help="pick or create a 6.9-inch iPhone simulator")
    record = sub.add_parser("record", help="start recording the simulator screen")
    record.add_argument("--device", required=True)
    record.add_argument("--out", required=True)
    record.add_argument("--handshake", help="folder shared with the test: wait for its `begin`, answer with `recording`")
    record.add_argument("--log", help="xcodebuild log to watch for PREVIEW-BEGIN while waiting")
    stop = sub.add_parser("stop", help="stop the recording")
    stop.add_argument("--out", required=True)
    render = sub.add_parser("render", help="cut the marked clips into the App Preview")
    render.add_argument("--out", required=True)
    render.add_argument("--log", action="append", help="xcodebuild log with the test's PREVIEW-* lines (repeatable)")
    render.add_argument("--attachments", help="exported xcresult attachments (the preview-clips note)")
    render.add_argument("--audio", help="the folder the app wrote what it played to (default: the test's PREVIEW-APP)")
    render.add_argument("--offset", default="0", help="seconds to shift every cut (positive = later)")
    render.add_argument("--reanchor", action="store_true",
                        help="place the lock clip by its badge when it drifts from the bell (a re-cut someone has looked at)")
    again = sub.add_parser("check", help="measure a rendered preview's sound again (preview.mp4 and cut.json)")
    again.add_argument("--out", required=True)
    args = parser.parse_args()
    commands = {"device": device_command, "record": record_command, "stop": stop_command, "render": render_command,
                "check": check_command}
    commands[args.command](args)


if __name__ == "__main__":
    main()
