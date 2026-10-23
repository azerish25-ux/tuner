#!/usr/bin/env python3
"""App Store App Preview (6.9-inch iPhone, portrait) from the AppPreviewUITests tour.

Run by .github/workflows/preview.yml, in this order:

  preview.py device                        pick (or create) a 6.9-inch iPhone simulator; prints
                                           DEVICE_ID=... and DEVICE_NAME=... lines for $GITHUB_ENV
  preview.py record --device ID --out DIR  start `simctl io ID recordVideo` in the background (DIR/raw.mp4)
                                           and note the wall-clock moment it started (DIR/record.json)
  preview.py stop --out DIR                stop it with SIGINT and wait until the file is written
  preview.py render --out DIR --log LOG [--attachments DIR] [--offset S]
                                           cut the clips the test marked into DIR/preview.mp4 + DIR/poster.png

The test prints `PREVIEW-CLIP <name> <start> <end> <head|tail>` (wall-clock seconds) for each stretch worth
showing and `PREVIEW-POSTER <time>` for the poster frame. render maps them onto the recording, joins the
clips with short cross-fades and encodes to Apple's App Preview spec: 886x1920 portrait, 30 fps, H.264 High,
a silent stereo AAC track at 44.1 kHz, 15-30 s. `--offset` shifts every cut (positive = later) if the cuts
look early or late. render also writes DIR/PREVIEW.txt (what was cut and where the poster sits) and
DIR/raw-small.mp4 (the whole recording, small, for checking a run).

Re-cut a CI run locally: download the preview-recording artifact (raw.mp4, record.json, test.log) and run
`python3 tools/marketing/preview.py render --out <that folder> --log <that folder>/test.log --offset 0.3`.
Needs ffmpeg and ffprobe (brew install ffmpeg).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

WIDTH, HEIGHT, FPS = 886, 1920, 30
FADE_FRAMES = 10                      # cross-fade between clips: 1/3 s
FADE = FADE_FRAMES / FPS
LONGEST, SHORTEST = 29.5, 15.5        # Apple allows 15-30 s; stay clear of both edges
FLOOR = 1.5                           # a clip is never shortened below this
PUBLISH_LIMIT = 44 * 1024 * 1024      # tools/ci/publish-results.sh leaves out files over 45 MB
APPLE_LIMIT = 500 * 1024 * 1024
PREFERRED = ("iPhone 17 Pro Max", "iPhone 16 Pro Max")

CLIP = re.compile(r"PREVIEW-CLIP (\S+) (\d+(?:\.\d+)?) (\d+(?:\.\d+)?) (head|tail)")
POSTER = re.compile(r"PREVIEW-POSTER (\d+(?:\.\d+)?)")
BEGIN = re.compile(r"PREVIEW-BEGIN (\d+(?:\.\d+)?)")
END = re.compile(r"PREVIEW-END (\w+)")


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


def record_command(args) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    raw, log = out / "raw.mp4", out / "record.log"
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

    @property
    def length(self) -> float:
        return self.end - self.start


def read_marks(texts: list[str]):
    """Clips and poster time (wall clock) of the last run that marked any, from the first text that has them.
    A retried test prints a fresh PREVIEW-BEGIN, so earlier attempts are ignored."""
    for text in texts:
        runs: list[dict] = []
        for line in text.splitlines():
            if BEGIN.search(line):
                runs.append({"clips": [], "poster": None, "result": None})
                continue
            clip, poster, end = CLIP.search(line), POSTER.search(line), END.search(line)
            if (clip or poster or end) and not runs:
                runs.append({"clips": [], "poster": None, "result": None})
            if clip:
                entry = (clip.group(1), float(clip.group(2)), float(clip.group(3)), clip.group(4))
                if entry not in runs[-1]["clips"]:
                    runs[-1]["clips"].append(entry)
            elif poster:
                runs[-1]["poster"] = float(poster.group(1))
            elif end:
                runs[-1]["result"] = end.group(1)
        for found in reversed(runs):
            if found["clips"]:
                return found
    return None


def joined(clips: list[Clip]) -> float:
    return sum(c.length for c in clips) - FADE * max(0, len(clips) - 1)


def snap(seconds: float) -> float:
    return round(seconds * FPS) / FPS


def fit(clips: list[Clip], duration: float):
    """Clamps the clips to the recording, then shortens (from each clip's less important end) or lengthens
    the cut to 15-30 s. Returns the clips, seconds of held last frame to add, and notes."""
    notes: list[str] = []
    kept = []
    for c in clips:
        c.start, c.end = snap(max(0.0, c.start)), snap(min(duration, c.end))
        if c.length >= 0.8:
            kept.append(c)
        else:
            notes.append(f"dropped {c.name}: outside the recording")
    clips = kept
    total = joined(clips)
    if total > LONGEST:
        excess = total - (LONGEST - 0.5)
        room = [max(0.0, c.length - FLOOR) for c in clips]
        share = min(1.0, excess / sum(room)) if sum(room) > 0 else 0.0
        for c, r in zip(clips, room):
            cut = snap(r * share)
            if c.keep == "head":
                c.end -= cut
            else:
                c.start += cut
        while joined(clips) > LONGEST and len(clips) > 1:
            notes.append(f"dropped {clips.pop().name}: too long even at the minimum clip length")
        notes.append(f"shortened from {total:.1f} s to fit Apple's 30 s")
    pad = 0.0
    total = joined(clips)
    if total < SHORTEST and clips:
        need = SHORTEST + 0.3 - total
        last = clips[-1]
        extra = snap(min(need, max(0.0, duration - last.end), 3.0))
        last.end += extra
        need -= extra
        if need > 0:
            pad = snap(need + 1 / FPS)
        notes.append(f"lengthened from {total:.1f} s to Apple's 15 s minimum ({extra:.1f} s more footage, {pad:.1f} s held frame)")
    return clips, pad, notes


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
    """The stretch of the recording the clips use, at constant 30 fps and preview size. simctl writes a frame
    only when the screen changes; the fps filter fills the gaps, so every 1/30 s has a frame to cut on."""
    vf = (f"fps={FPS}:start_time=0,trim=start={base:.4f}:end={top:.4f},setpts=PTS-STARTPTS,"
          f"scale={WIDTH}:{HEIGHT}:force_original_aspect_ratio=increase:flags=lanczos,crop={WIDTH}:{HEIGHT},setsar=1,format=yuv420p")
    ffmpeg(["-i", str(raw), "-an", "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "12", "-g", str(FPS), str(dest)])


def encode(window: Path, clips: list[Clip], base: float, pad: float, dest: Path, color: list[str], crf: int, rate: str) -> float:
    count = len(clips)
    parts = []
    if count > 1:
        parts.append(f"[0:v]split={count}" + "".join(f"[s{i}]" for i in range(count)))
    for i, c in enumerate(clips):
        source = f"[s{i}]" if count > 1 else "[0:v]"
        # Half-frame margins keep each boundary frame on the intended side.
        first, last = c.start - base - 0.5 / FPS, c.end - base - 0.5 / FPS
        parts.append(f"{source}trim=start={max(0.0, first):.4f}:end={last:.4f},setpts=PTS-STARTPTS[c{i}]")
    stream, length = "[c0]", clips[0].length
    for i in range(1, count):
        parts.append(f"{stream}[c{i}]xfade=transition=fade:duration={FADE:.4f}:offset={length - FADE:.4f}[x{i}]")
        stream, length = f"[x{i}]", length + clips[i].length - FADE
    hold = f"tpad=stop_mode=clone:stop_duration={pad:.4f}," if pad > 0 else ""
    parts.append(f"{stream}{hold}fps={FPS},format=yuv420p[v]")
    total = snap(length + pad)
    ffmpeg([
        "-i", str(window),
        "-f", "lavfi", "-t", f"{total:.4f}", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-filter_complex", ";".join(parts), "-map", "[v]", "-map", "1:a",
        "-c:v", "libx264", "-preset", "slow", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
        "-crf", str(crf), "-maxrate", rate, "-bufsize", f"{2 * int(rate.rstrip('M'))}M", "-g", str(FPS), "-r", str(FPS),
        *color,
        "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
        "-t", f"{total:.4f}", "-movflags", "+faststart", str(dest),
    ])
    return total


def poster_time(clips: list[Clip], poster_raw) -> float:
    """Where the marked poster moment lands in the cut; the middle of the first clip without one."""
    if poster_raw is not None:
        offset = 0.0
        for c in clips:
            if c.start <= poster_raw <= c.end:
                return offset + poster_raw - c.start
            offset += c.length - FADE
    return clips[0].length / 2


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


def timecode(seconds: float) -> str:
    whole = int(seconds)
    return f"00:{whole // 60:02d}:{whole % 60:02d}.{int(round((seconds - whole) * 100)):02d}"


def render_command(args) -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            sys.exit(f"{tool} is missing: brew install ffmpeg")
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
    origin = record["started"] - offset          # wall clock at 0 s into the recording
    raw_info = probe(raw)
    duration = float(raw_info["format"]["duration"])

    texts = [Path(p).read_text(errors="replace") for p in (args.log or []) if Path(p).exists()]
    if args.attachments and Path(args.attachments).is_dir():
        texts.append("\n".join(p.read_text(errors="replace") for p in sorted(Path(args.attachments).rglob("*.txt"))))
    marks = read_marks(texts)
    notes: list[str] = []
    if marks:
        clips = [Clip(name, start - origin, end - origin, keep) for name, start, end, keep in marks["clips"]]
        poster_raw = marks["poster"] - origin if marks["poster"] is not None else None
        if marks["result"] != "passed":
            notes.append(f"WARNING: the tour test {marks['result'] or 'did not finish'}; check the cut before using it")
    else:
        # No marks (the test never got going): skip the launch and keep what fits.
        start = min(12.0, duration * 0.25)
        clips = [Clip("fallback", start, min(duration - 1, start + 28), "head")]
        poster_raw = None
        notes.append("WARNING: no PREVIEW-CLIP marks found; this is a plain trim of the recording")
    clips, pad, fitted = fit(clips, duration)
    notes += fitted
    if not clips:
        sys.exit("None of the marked clips fall inside the recording; check record.json and --offset.")

    base = max(0.0, snap(min(c.start for c in clips) - 1))
    top = min(duration, max(c.end for c in clips) + 1)
    window = out / "window.mp4"
    print(f"Cutting {len(clips)} clips from {raw.name} ({duration:.1f} s)")
    cut_window(raw, base, top, window)
    color = color_args(raw_info)
    preview = out / "preview.mp4"
    for crf, rate in ((18, "10M"), (21, "8M"), (24, "6M")):
        total = encode(window, clips, base, pad, preview, color, crf, rate)
        if preview.stat().st_size <= PUBLISH_LIMIT:
            break
    window.unlink(missing_ok=True)

    poster_at = min(max(0.1, poster_time(clips, poster_raw)), total - 0.1)
    ffmpeg(["-ss", f"{poster_at:.3f}", "-i", str(preview), "-frames:v", "1", str(out / "poster.png")])
    if not args.no_evidence:
        ffmpeg(["-i", str(raw), "-an", "-vf", "fps=15,scale=432:-2", "-c:v", "libx264", "-preset", "veryfast", "-crf", "32",
                str(out / "raw-small.mp4")])

    info, problems = check(preview)
    size = preview.stat().st_size
    lines = [
        'App Store App Preview: iPhone 6.9" display, portrait',
        f"preview.mp4: {WIDTH}x{HEIGHT}, {FPS} fps, H.264 High, silent stereo AAC 44.1 kHz, "
        f"{float(info['format']['duration']):.2f} s, {size / 1e6:.1f} MB",
        f"poster.png: the frame at {timecode(poster_at)}. In App Store Connect, set the preview's poster frame to this time.",
        f"recording: {os.environ.get('DEVICE_NAME', 'simulator')}, {duration:.1f} s; start {record.get('startSource')}; offset {offset:+.2f} s",
        "",
        "clips (seconds into the recording -> into the preview):",
    ]
    at = 0.0
    for c in clips:
        lines.append(f"  {c.name:<10} {c.start:7.2f}-{c.end:7.2f} -> {at:5.2f}-{at + c.length:5.2f}  keep {c.keep}")
        at += c.length - FADE
    lines += [""] + notes + ([f"OUT OF SPEC: {p}" for p in problems] or ["Meets the App Preview spec."])
    (out / "PREVIEW.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if problems:
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("device", help="pick or create a 6.9-inch iPhone simulator")
    record = sub.add_parser("record", help="start recording the simulator screen")
    record.add_argument("--device", required=True)
    record.add_argument("--out", required=True)
    stop = sub.add_parser("stop", help="stop the recording")
    stop.add_argument("--out", required=True)
    render = sub.add_parser("render", help="cut the marked clips into the App Preview")
    render.add_argument("--out", required=True)
    render.add_argument("--log", action="append", help="xcodebuild log with the test's PREVIEW-* lines (repeatable)")
    render.add_argument("--attachments", help="exported xcresult attachments (the preview-clips note)")
    render.add_argument("--offset", default="0", help="seconds to shift every cut (positive = later)")
    render.add_argument("--no-evidence", action="store_true", help="skip raw-small.mp4")
    args = parser.parse_args()
    {"device": device_command, "record": record_command, "stop": stop_command, "render": render_command}[args.command](args)


if __name__ == "__main__":
    main()
