"""The App Preview's soundtrack, laid from what the app itself played during the tour.

The app writes it down as it plays (`PreviewRecorder` in ios/Timbre/Root/DemoScenes.swift, TIMBRE_PREVIEW_AUDIO):

- events.jsonl: `cue` lines (a sound effect starting: its WAV, volume and player), `launch` lines (each with the
  engine file of that launch), `stream` lines (another file in the engine file's format) and `event` lines (a scene's
  moments: a lock, the full tune, a take's clock, the band starting or stopping, the motif). Every time is seconds
  since 1970 on the host's clock, the same clock the UI test marks its clips with.
- cue-<fingerprint>.wav: each sound effect once, the exact bytes AVAudioPlayer played (the lock bells, the full-tune
  strum, stars, the lesson cues, the motif).
- engine-<launch>.pcm: what the lessons' engine rendered (tones, the click, the band), mono 16-bit, as records of a
  little-endian header (Float64 start, UInt32 frames, UInt32 sample rate) and the samples. Silence is left out.
- string-<launch>.pcm (a `stream`): the demo string the tuner was given, in the instrument's own reference voice at
  the pitch of each reading, so the preview hears the string drift into tune with the readout.

`AppAudio.segment(start, length)` gives the sound of any wall-clock stretch at 44.1 kHz, so each clip of the cut
carries exactly the sound the app made while it was filmed. Nothing here synthesizes a sound. Pure Python (array,
wave, struct), no NumPy.
"""
from __future__ import annotations

import json
import math
import struct
import wave
from array import array
from dataclasses import dataclass, field
from pathlib import Path

RATE = 44100
HEADER = struct.Struct("<dII")


@dataclass
class Cue:
    time: float
    file: str
    volume: float
    player: str
    until: float = float("inf")    # the same player starting again cuts this one off


@dataclass
class Run:
    """One stretch of engine output: consecutive buffers chained end to end."""
    start: float
    rate: int
    samples: array = field(default_factory=lambda: array("h"))

    @property
    def end(self) -> float:
        return self.start + len(self.samples) / self.rate


class AppAudio:
    def __init__(self, folder: Path | None):
        self.folder = folder
        self.cues: list[Cue] = []
        self.runs: list[Run] = []
        self.events: list[dict] = []
        self.notes: list[str] = []
        self._sounds: dict[str, tuple[array, int]] = {}
        if folder and (folder / "events.jsonl").exists():
            self._read(folder)

    @property
    def present(self) -> bool:
        return bool(self.cues or self.runs)

    def moments(self, name: str) -> list[dict]:
        """The app's `event` lines of this name, in time order."""
        return sorted((e for e in self.events if e.get("name") == name and isinstance(e.get("t"), (int, float))),
                      key=lambda e: e["t"])

    def first_cue(self, after: float, before: float) -> Cue | None:
        """The first sound effect that started in [after, before)."""
        return next((c for c in self.cues if after <= c.time < before), None)

    def band_playing(self, start: float, end: float) -> bool | None:
        """Whether the band played through the wall-clock stretch, from the app's `band` events; None without any."""
        changes = self.moments("band")
        if not changes:
            return None
        state = False
        for change in changes:
            if change["t"] <= start:
                state = bool(change.get("playing"))
            elif change["t"] < end and not change.get("playing"):
                return False
        return state

    def _read(self, folder: Path) -> None:
        engines: list[str] = []
        for line in (folder / "events.jsonl").read_text(errors="replace").splitlines():
            try:
                item = json.loads(line)
            except ValueError:
                continue
            kind = item.get("kind")
            if kind == "cue" and isinstance(item.get("t"), (int, float)):
                self.cues.append(Cue(float(item["t"]), str(item.get("file", "")), float(item.get("volume", 1.0)),
                                     str(item.get("player", ""))))
            elif kind == "launch" and item.get("engine"):
                engines.append(str(item["engine"]))
            elif kind == "stream" and item.get("file"):
                engines.append(str(item["file"]))
            elif kind == "event":
                self.events.append(item)
            elif kind == "note":
                self.notes.append(str(item.get("text", "")))
        self.cues.sort(key=lambda c: c.time)
        last: dict[str, Cue] = {}
        for cue in self.cues:
            if cue.player in last:
                last[cue.player].until = cue.time
            last[cue.player] = cue
        for name in dict.fromkeys(engines):
            path = folder / name
            if path.exists():
                self.runs += self._read_engine(path)
        self.runs.sort(key=lambda r: r.start)

    @staticmethod
    def _read_engine(path: Path) -> list[Run]:
        """The engine's buffers, chained: a buffer that starts within 40 ms of the previous one's end continues it (the
        tap dates each buffer from its host time, which jitters by a few milliseconds)."""
        data = path.read_bytes()
        runs: list[Run] = []
        offset = 0
        while offset + HEADER.size <= len(data):
            start, frames, rate = HEADER.unpack_from(data, offset)
            offset += HEADER.size
            size = frames * 2
            if frames == 0 or rate == 0 or offset + size > len(data):
                break
            chunk = array("h")
            chunk.frombytes(data[offset:offset + size])
            offset += size
            current = runs[-1] if runs else None
            if current and current.rate == rate and abs(start - current.end) < 0.04:
                current.samples.extend(chunk)
            else:
                runs.append(Run(start, rate, chunk))
        return runs

    def _sound(self, name: str) -> tuple[array, int] | None:
        if name in self._sounds:
            return self._sounds[name]
        path = self.folder / name if self.folder else None
        if not path or not path.exists():
            return None
        try:
            with wave.open(str(path), "rb") as handle:
                channels, width, rate = handle.getnchannels(), handle.getsampwidth(), handle.getframerate()
                raw = handle.readframes(handle.getnframes())
        except (wave.Error, EOFError):
            return None
        if width != 2:
            return None
        samples = array("h")
        samples.frombytes(raw)
        if channels > 1:
            samples = array("h", (int(sum(samples[i:i + channels]) / channels) for i in range(0, len(samples), channels)))
        self._sounds[name] = (samples, rate)
        return self._sounds[name]

    def segment(self, start: float, length: float) -> array:
        """Mono float samples at RATE for the wall-clock stretch [start, start + length)."""
        count = max(0, int(round(length * RATE)))
        out = array("f", bytes(4 * count))
        end = start + length
        for run in self.runs:
            if run.end <= start or run.start >= end:
                continue
            _add(out, run.samples, run.rate, run.start - start, 1.0, float("inf"))
        for cue in self.cues:
            if cue.time >= end or cue.time < start - 8:
                continue
            sound = self._sound(cue.file)
            if not sound:
                continue
            samples, rate = sound
            if cue.time + len(samples) / rate <= start:
                continue
            _add(out, samples, rate, cue.time - start, cue.volume, cue.until - start)
        return out


def _add(out: array, samples: array, rate: int, at: float, gain: float, stop: float) -> None:
    """Adds `samples` (16-bit, at `rate`) into `out` (float, at RATE) starting `at` seconds in, until `stop` seconds
    (a 5 ms fade when cut off there)."""
    count = len(out)
    first = max(0, math.ceil(at * RATE))
    last = min(count, math.floor((at + len(samples) / rate) * RATE), math.floor(stop * RATE) if stop < float("inf") else count)
    if last <= first:
        return
    scale = gain / 32768.0
    fade = int(0.005 * RATE)
    cut = stop < float("inf") and last == math.floor(stop * RATE)
    if rate == RATE:
        shift = int(round(at * RATE))
        for k in range(first, last):
            index = k - shift
            if 0 <= index < len(samples):
                value = samples[index] * scale
                if cut and last - k < fade:
                    value *= (last - k) / fade
                out[k] += value
        return
    step = rate / RATE
    origin = at * RATE
    limit = len(samples) - 1
    for k in range(first, last):
        position = (k - origin) * step
        index = int(position)
        if index < 0 or index >= limit:
            continue
        frac = position - index
        value = (samples[index] * (1 - frac) + samples[index + 1] * frac) * scale
        if cut and last - k < fade:
            value *= (last - k) / fade
        out[k] += value


def lay(pieces: list[tuple[array, float, float]], total: float, tail: float) -> array:
    """The cut's soundtrack: each piece (samples, where it starts in the cut, its own length) laid in place with a
    6 ms fade-in; anything past its own length is its tail, faded out over `tail` under the next clip (an L-cut, so a
    bell or a chord isn't chopped by the picture's hard cut)."""
    count = int(round(total * RATE))
    out = array("f", bytes(4 * count))
    attack = int(0.006 * RATE)
    for samples, at, own in pieces:
        begin = int(round(at * RATE))
        own_count = int(round(own * RATE))
        tail_count = max(1, int(round(tail * RATE)))
        for i, value in enumerate(samples):
            k = begin + i
            if k >= count:
                break
            if i < attack:
                value *= i / attack
            if i >= own_count:
                into = i - own_count
                if into >= tail_count:
                    break
                value *= 1 - into / tail_count
            out[k] += value
    return out


def write_wav(path: Path, samples: array, ceiling: float = 0.89) -> float:
    """A stereo 16-bit WAV at RATE; the mix is scaled down only if it would clip. Returns the peak before scaling."""
    peak = max((abs(v) for v in samples), default=0.0)
    scale = ceiling / peak if peak > ceiling else 1.0
    stereo = array("h")
    for value in samples:
        level = int(max(-32767, min(32767, value * scale * 32767)))
        stereo.append(level)
        stereo.append(level)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(stereo.tobytes())
    return peak
