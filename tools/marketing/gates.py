"""What the App Preview has to prove before it ships, measured on the files themselves (preview.py runs these).

Sound, on the delivered preview.mp4 (decoded with ffmpeg, measured in pure Python):

- no stretch of silence longer than LONGEST_SILENCE anywhere, end card included (silence: a window under SILENT_DB);
- every clip sounding in at least CLIP_SOUNDING of its windows, and a clip whose caption promises the band in at least
  BAND_SOUNDING of them (a click with silence between clicks reads as about 20 %);
- under a "band" caption, the low end (below LOW_HZ) of the clip at BAND_LOW_DB or louder in the median window: drums
  and bass are there, not only a click.

Picture, on the simulator's recording:

- `mint_series`: how much of a region (the tuner's readout) is drawn in the app's mint, frame by frame. The In tune
  badge, the note's glow and its octave turn mint at a lock, so the readout's mint more than doubles there;
- `badge_onset`: the first frame of that jump, so the cut can check the lock's bell against the badge's first frame,
  and that the poster shows the lock;
- `refine_sync`: where a sync screenshot is in the recording to 1/60 s (the coarse search runs at 15 frames a second).
"""
from __future__ import annotations

import math
import operator
import subprocess
from array import array
from dataclasses import dataclass
from pathlib import Path

RATE = 22050                 # analysis sample rate
WINDOW = 0.1                 # seconds per level window
SILENT_DB = -60.0            # a window quieter than this (RMS, dBFS) is silent
LONGEST_SILENCE = 0.5        # seconds of silence allowed anywhere
CLIP_SOUNDING = 0.6          # share of a clip's windows that must sound
BAND_SOUNDING = 0.8          # ... when its caption promises the band
LOW_HZ = 250                 # the band's low end: kick and bass
BAND_LOW_DB = -45.0          # the median window's low end under a "band" caption, at least
MINT = (76, 242, 184)        # Palette.mint (0x4CF2B8)
BADGE_RISE = 1.6             # the readout's mint at a lock, against before it, at least this many times
BADGE_FLOOR = 0.004          # ... and at least this much more of the region (0.4 %)


def ffmpeg_bytes(args: list[str]) -> bytes:
    return subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", *args], check=True,
                          capture_output=True).stdout


# MARK: sound


def decode_audio(path: Path, lowpass: int | None = None) -> array:
    """The file's first audio stream as mono 16-bit samples at RATE; `lowpass` keeps only what is below it (two
    second-order low passes, 24 dB an octave)."""
    filters = ["-af", f"lowpass=f={lowpass}:p=2,lowpass=f={lowpass}:p=2"] if lowpass else []
    raw = ffmpeg_bytes(["-i", str(path), "-map", "0:a:0", "-ac", "1", "-ar", str(RATE), *filters, "-f", "s16le", "-"])
    samples = array("h")
    samples.frombytes(raw[:len(raw) // 2 * 2])
    return samples


def levels(samples: array, window: float = WINDOW) -> list[float]:
    """RMS in dBFS of each whole window (-120 for digital silence)."""
    size = max(1, int(RATE * window))
    found = []
    for start in range(0, len(samples) - size + 1, size):
        chunk = samples[start:start + size]
        power = sum(map(operator.mul, chunk, chunk)) / size
        found.append(-120.0 if power <= 0 else 10 * math.log10(power / 32768.0 ** 2))
    return found


def silences(found: list[float], window: float = WINDOW, longest: float = LONGEST_SILENCE) -> list[tuple[float, float]]:
    """Stretches of silent windows longer than `longest`, as (start, end) seconds."""
    runs = []
    start = None
    for index, level in enumerate(found + [0.0]):
        if level < SILENT_DB:
            start = index if start is None else start
        elif start is not None:
            if (index - start) * window > longest + 1e-6:
                runs.append((start * window, index * window))
            start = None
    return runs


@dataclass
class Section:
    """A stretch of the cut: a clip (with its caption) or the end card."""
    name: str
    start: float
    end: float
    caption: str = ""

    @property
    def promises_band(self) -> bool:
        return "band" in self.caption.lower()


def sound_report(path: Path, sections: list[Section]) -> tuple[list[str], list[str], list[str]]:
    """Lines describing the preview's sound; the silences and quiet clips that keep it from shipping; and the clips
    whose caption promises the band without one (a new take can fix those: the band joins late on a busy runner)."""
    full = levels(decode_audio(path))
    low = levels(decode_audio(path, LOW_HZ))
    lines, problems, bandless = [], [], []
    total = len(full) * WINDOW
    quiet = silences(full)
    longest = max((end - start for start, end in quiet), default=0.0)
    lines.append(f"sound: {sum(1 for v in full if v >= SILENT_DB) / max(1, len(full)):.0%} of {total:.1f} s sounding; "
                 f"longest silence {longest:.1f} s (at most {LONGEST_SILENCE} s allowed, silence under {SILENT_DB:.0f} dBFS)")
    for start, end in quiet:
        touched = [s for s in sections if s.start < end and s.end > start]
        where = ", ".join(s.name for s in touched) or "the cut"
        # Silence inside a "band" clip is the band missing (the click alone leaves gaps): a new take can fix it.
        into = bandless if any(s.promises_band for s in touched) else problems
        into.append(f"{end - start:.1f} s of silence at {start:.1f}-{end:.1f} s ({where})")
    for section in sections:
        first, last = int(section.start / WINDOW + 0.5), int(section.end / WINDOW + 0.5)
        own = full[first:last]
        if not own:
            continue
        sounding = sum(1 for v in own if v >= SILENT_DB) / len(own)
        needed = BAND_SOUNDING if section.promises_band else CLIP_SOUNDING
        note = f"  {section.name:<9} {sounding:4.0%} sounding"
        if section.promises_band:
            bottom = sorted(low[first:last])
            median = bottom[len(bottom) // 2] if bottom else -120.0
            note += f", low end (under {LOW_HZ} Hz) {median:6.1f} dBFS in the median window"
            if median < BAND_LOW_DB:
                bandless.append(f"{section.name}: “{section.caption}” but no band under it (low end {median:.0f} dBFS, "
                                f"at least {BAND_LOW_DB:.0f}): only the click recorded")
        lines.append(note)
        if sounding < needed:
            into = bandless if section.promises_band else problems
            into.append(f"{section.name}: sounding in {sounding:.0%} of its windows (at least {needed:.0%})")
    return lines, problems, bandless


# MARK: picture


def video_size(path: Path) -> tuple[int, int]:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "csv=p=0:s=x", str(path)], check=True, capture_output=True, text=True).stdout.strip()
    width, height = out.split("x")[:2]
    return int(width), int(height)


def _window(path: Path, start: float, end: float, fps: int, extra: str, pixel: str) -> tuple[bytes, float]:
    """Frames of [start, end) at `fps`, through `extra` filters, as raw `pixel` bytes; and the time of the first.
    Seeks to two seconds before `start` and trims from there, so the first frame is dense even where the recorder
    wrote no frame for a while (it writes one only when the screen changes)."""
    seek = max(0.0, start - 2.0)
    lead = start - seek
    graph = f"fps={fps}:start_time=0,trim=start={lead:.4f}:end={lead + max(0.05, end - start):.4f},setpts=PTS-STARTPTS"
    if extra:
        graph += "," + extra
    data = ffmpeg_bytes(["-ss", f"{seek:.3f}", "-i", str(path), "-an", "-vf", graph, "-f", "rawvideo", "-pix_fmt", pixel, "-"])
    return data, start


def mint_series(path: Path, region: tuple[float, float, float, float], start: float, end: float,
                fps: int = 60, columns: int = 160) -> list[tuple[float, float]]:
    """(time, share of the region drawn in mint) for each frame of [start, end). `region` is (x, y, width, height) as
    fractions of the frame."""
    width, height = video_size(path)
    x, y, w, h = region
    box = [max(0, int(x * width)), max(0, int(y * height)), max(8, int(w * width)), max(8, int(h * height))]
    box[2] = min(box[2], width - box[0]) // 2 * 2
    box[3] = min(box[3], height - box[1]) // 2 * 2
    rows = max(2, int(columns * box[3] / max(1, box[2])))
    extra = f"crop={box[2]}:{box[3]}:{box[0]}:{box[1]},scale={columns}:{rows}:flags=area"
    data, first = _window(path, start, end, fps, extra, "rgb24")
    size = columns * rows * 3
    series = []
    for index in range(len(data) // size):
        frame = data[index * size:(index + 1) * size]
        series.append((first + index / fps, mint_share(frame)))
    return series


def mint_share(rgb: bytes) -> float:
    """The share of pixels drawn in the mint family (its own hue at any brightness: the badge, its outline, the glow)."""
    count = len(rgb) // 3
    if not count:
        return 0.0
    hits = 0
    for i in range(0, count * 3, 3):
        r, g, b = rgb[i], rgb[i + 1], rgb[i + 2]
        if g > 60 and r < 0.6 * g and 0.55 * g < b < 0.95 * g:
            hits += 1
    return hits / count


@dataclass
class Badge:
    onset: float      # the first frame of the jump (seconds in the video)
    before: float     # the mint share before it
    peak: float       # and at its height

    def shown(self, share: float) -> bool:
        """Whether a frame with this share shows the lock (at least halfway up the jump)."""
        return share >= self.before + 0.5 * (self.peak - self.before)


def badge_onset(series: list[tuple[float, float]], expected: float) -> Badge | None:
    """The lock's jump in the readout's mint nearest `expected`: the largest rise over a fifth of a second, its first
    frame halfway up. None when nothing in the window rises by BADGE_RISE times and BADGE_FLOOR."""
    if len(series) < 8:
        return None
    step = max(1, int(round(0.2 / max(1e-6, series[1][0] - series[0][0]))))
    best, best_rise = None, 0.0
    for i in range(len(series) - step):
        rise = series[i + step][1] - series[i][1]
        # Prefer the rise nearest the expected moment among those of about the same size.
        score = rise - 0.0005 * abs(series[i][0] - expected)
        if score > best_rise:
            best, best_rise = i, score
    if best is None:
        return None
    earlier = [v for t, v in series[:best + 1] if t >= series[best][0] - 0.8] or [series[best][1]]
    before = sorted(earlier)[len(earlier) // 2]
    later = [v for _, v in series[best + 1:best + 1 + 3 * step]] or [series[best + step][1]]
    peak = max(later)
    if peak < before * BADGE_RISE or peak - before < BADGE_FLOOR:
        return None
    halfway = before + 0.5 * (peak - before)
    for t, value in series[max(0, best - step):]:
        if value >= halfway:
            return Badge(t, before, peak)
    return None


def gray_frames(path: Path, start: float, end: float, fps: int, width: int, height: int) -> list[bytes]:
    data, _ = _window(path, start, end, fps, f"scale={width}:{height}:flags=area,format=gray", "gray")
    size = width * height
    return [data[i:i + size] for i in range(0, len(data) - size + 1, size)]


def refine_sync(path: Path, target: list[int], around: float, normalise, distance, width: int, height: int,
                span: float = 0.6, fps: int = 60) -> tuple[float, float] | None:
    """(seconds into the recording, difference) of the frame within `span` of `around` that best matches `target` (a
    normalised tiny grey picture, as preview.py makes them), at `fps`. None when nothing could be decoded."""
    start = max(0.0, around - span)
    frames = gray_frames(path, start, around + span, fps, width, height)
    if not frames:
        return None
    scored = [(distance(target, normalise(frame)), index) for index, frame in enumerate(frames)]
    score, index = min(scored)
    return start + index / fps, score
