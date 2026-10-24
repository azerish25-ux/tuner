"""Building blocks for Timbre's Learn curriculum.

Course modules (tools/curriculum/courses/*.py) describe lessons with these helpers;
build.py validates everything (pitches match the frets, chord shapes spell their
chord, answers exist, text is short enough) and writes curriculum.json plus the
English Learn.strings table.

Conventions
- Strings are numbered from the highest-pitched (1) to the lowest; fret 0 is open.
- Notes are MIDI numbers (C4 = 60) or names like "E2", "F#3", "Bb4".
- Beats count from 0 at the first beat after the count-in.
"""
from __future__ import annotations

import re

# Open-string MIDI by instrument (string 1 first).
TUNINGS = {
    "guitar": [64, 59, 55, 50, 45, 40],      # E4 B3 G3 D3 A2 E2
    "ukulele": [69, 64, 60, 67],             # A4 E4 C4 G4 (re-entrant)
    "bass": [43, 38, 33, 28],                # G2 D2 A1 E1
    "violin": [76, 69, 62, 55],              # E5 A4 D4 G3 (fretless: "fret" = semitones above the open string)
    "cello": [57, 50, 43, 36],               # A3 D3 G2 C2 (fretless)
    "mandolin": [76, 69, 62, 55],            # E5 A4 D4 G3, paired courses
    "banjo": [62, 59, 55, 50, 67],           # D4 B3 G3 D3, short 5th string G4 (open G)
}
INSTRUMENT_IDS = {"guitar": "guitar.acoustic.6", "ukulele": "ukulele.soprano.4", "bass": "bass.electric.4",
                  "violin": "violin.standard.4", "cello": "cello.standard.4", "mandolin": "mandolin.standard.8", "banjo": "banjo.five.5"}
FRETLESS = {"violin", "cello"}
NAMES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
QUALITIES = {  # intervals above the root
    "maj": [0, 4, 7], "min": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "sus2": [0, 2, 7], "sus4": [0, 5, 7], "5": [0, 7], "dim": [0, 3, 6], "aug": [0, 4, 8], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "9": [0, 4, 7, 10, 2],
}


def midi(note) -> int:
    """MIDI number from 60 or "C4" / "F#3" / "Bb2"."""
    if isinstance(note, int):
        return note
    m = re.fullmatch(r"([A-Ga-g])([#b]?)(-?\d)", note.strip())
    if not m:
        raise ValueError(f"bad note {note!r}")
    letter, accidental, octave = m.groups()
    pc = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[letter.upper()]
    pc += {"#": 1, "b": -1, "": 0}[accidental]
    return (int(octave) + 1) * 12 + pc


def name(m: int) -> str:
    return f"{NAMES[m % 12]}{m // 12 - 1}"


def fretted(instrument: str, string: int, fret: int) -> int:
    return TUNINGS[instrument][string - 1] + fret


def position(instrument: str, note, max_fret: int = 4, prefer_string: int | None = None, first_fret: int | None = None):
    """Where to play a note: lowest fret within max_fret (first position), on the requested string if possible.
    first_fret: the hand's position (e.g. 5 for a box at the fifth fret); fingers count from it."""
    m = midi(note)
    options = [(s, m - open_) for s, open_ in enumerate(TUNINGS[instrument], start=1) if 0 <= m - open_ <= max_fret]
    if prefer_string:
        options = [o for o in options if o[0] == prefer_string] or options
    if not options:
        options = [(s, m - open_) for s, open_ in enumerate(TUNINGS[instrument], start=1) if 0 <= m - open_ <= 12]
    if not options:
        raise ValueError(f"{name(m)} is out of range on {instrument}")
    if first_fret:
        in_reach = [o for o in options if first_fret - 1 <= o[1] <= first_fret + 4]
        options = in_reach or options
        s, f = max(options, key=lambda o: (o[1] >= first_fret, -abs(o[1] - first_fret - 1.5)))
        finger = max(1, min(4, f - first_fret + 1)) if f >= first_fret else 1
        return {"s": s, "f": f, **({"g": finger} if f else {})}
    s, f = min(options, key=lambda o: (o[1], -o[0]))
    return {"s": s, "f": f, **({"g": min(4, f)} if f else {})}


# ---------------------------------------------------------------- text

class Text:
    """Lesson text; keys are assigned at build time from the lesson id and position."""
    def __init__(self, text: str):
        self.text = " ".join(text.split())

    def __repr__(self):
        return f"Text({self.text!r})"


def T(text):
    return text if isinstance(text, Text) or text is None else Text(text)


# ---------------------------------------------------------------- visuals

def fretboard(instrument: str, dots, frets: int = 5, start: int = 1):
    """dots: [(string, fret)] or [(string, fret, finger)]. start: fret at the left edge (5 for a box at fret 5)."""
    out = []
    for d in dots:
        s, f, *g = d
        out.append({"s": s, "f": f, **({"g": g[0]} if g else {})})
    return {"type": "fretboard", "strings": len(TUNINGS[instrument]), "dots": out, "frets": frets, "start": start}


def staff(notes, clef="treble"):
    return {"type": "staff", "midi": [midi(n) for n in notes], "clef": clef}


def keyboard(notes):
    return {"type": "keyboard", "midi": [midi(n) for n in notes]}


def rhythm(pattern, beats_per_bar=4):
    return {"type": "rhythm", "pattern": list(pattern), "beatsPerBar": beats_per_bar}


def part(name_):
    return {"type": "instrument", "part": name_}


# ---------------------------------------------------------------- chords

def chord(instrument: str, chord_name: str, frets: str | list, fingers: str | list | None = None, root=None, quality=None):
    """A chord shape. frets lowest string first: "x32010" (guitar C) or [-1,3,2,0,1,0]; 10+ as list."""
    if isinstance(frets, str):
        frets = [-1 if c in "xX" else int(c) for c in frets]
    if isinstance(fingers, str):
        fingers = [0 if c in "x0-" else int(c) for c in fingers]
    root_pc, qual = parse_chord_name(chord_name) if root is None else (root, quality)
    strings = len(TUNINGS[instrument])
    assert len(frets) == strings, f"{chord_name}: {len(frets)} frets for {strings} strings"
    played = [fretted(instrument, strings - i, f) for i, f in enumerate(frets) if f >= 0]
    tones = {(root_pc + i) % 12 for i in QUALITIES[qual]}
    pcs = {p % 12 for p in played}
    assert pcs <= tones, f"{chord_name} shape {frets} plays {sorted(NAMES[p] for p in pcs - tones)} outside the chord"
    assert root_pc in pcs, f"{chord_name} shape {frets} lacks its root"
    playable = [f for f in frets if f > 0]
    base = min(playable) if playable and max(playable) > 4 else 1
    spec = {"name": chord_name, "root": root_pc, "quality": qual, "frets": frets}
    if fingers:
        spec["fingers"] = fingers
    if base > 1:
        spec["baseFret"] = base
    return spec


def parse_chord_name(chord_name: str):
    m = re.fullmatch(r"([A-G])([#b]?)(.*)", chord_name)
    if not m:
        raise ValueError(chord_name)
    letter, acc, rest = m.groups()
    pc = (midi(f"{letter}{acc}4") - 60) % 12
    qual = {"": "maj", "m": "min", "7": "7", "maj7": "maj7", "m7": "m7", "sus2": "sus2", "sus4": "sus4", "5": "5",
            "dim": "dim", "aug": "aug", "6": "6", "m6": "m6", "9": "9"}.get(rest)
    if qual is None:
        raise ValueError(f"unknown chord quality in {chord_name}")
    return pc, qual


# ---------------------------------------------------------------- steps

def explain(title, body, visual=None):
    return {"type": "explain", "title": T(title), "body": T(body), "visual": visual or {"type": "none"}}


def notes(instrument: str | None, seq, hint=None, max_fret: int = 4, first_fret: int | None = None):
    """Play notes in order at your own pace. seq: notes, or (note, string) to fix the string."""
    out = []
    for item in seq:
        n, s = (item if isinstance(item, tuple) else (item, None))
        at = position(instrument, n, max_fret=max_fret, prefer_string=s, first_fret=first_fret) if instrument else None
        if at and s and at["s"] != s:
            raise ValueError(f"{n} can't be played on string {s} within fret {max_fret}")
        out.append({"m": midi(n), "b": float(len(out)), "d": 1.0, **({"at": at} if at else {})})
    return {"type": "notes", "notes": out, **({"hint": T(hint)} if hint else {})}


def along(instrument: str | None, melody: str, bpm: float, beats_per_bar: int = 4, title=None, max_fret: int = 4, first_fret: int | None = None):
    """Play along. melody: "E4:1 D4:1 C4:2 r:1 ..." (note:beats; r = rest), optionally note@string."""
    out, beat = [], 0.0
    for token in melody.split():
        n, _, length = token.partition(":")
        length = float(length or 1)
        if n.lower() != "r":
            n, _, s = n.partition("@")
            at = position(instrument, n, max_fret=max_fret, prefer_string=int(s) if s else None, first_fret=first_fret) if instrument else None
            if at and s and at["s"] != int(s):
                raise ValueError(f"{n} can't be played on string {s} within fret {max_fret}")
            out.append({"m": midi(n), "b": beat, "d": length, **({"at": at} if at else {})})
        beat += length
    return {"type": "along", "notes": out, "bpm": bpm, "beatsPerBar": beats_per_bar, **({"title": T(title)} if title else {})}


def play_chord(spec):
    return {"type": "chord", "chord": spec}


def strum(spec, pattern, bpm, bars=2, beats_per_bar=None):
    """pattern: beats within one bar where to strum, e.g. [0, 1, 2, 3] or [0, 1, 1.5, 2.5, 3].
    beats_per_bar: 3 for 3/4, 6 for 6/8 counted in eighths; default 4."""
    return {"type": "strum", "chord": spec, "pattern": list(pattern), "bpm": bpm, "bars": bars,
            **({"beatsPerBar": beats_per_bar} if beats_per_bar else {})}


def progression(changes, pattern, bpm, beats_per_bar=None):
    """Strum chords in time. changes: [(chord spec, bars), ...]; the pattern repeats in every bar."""
    return {"type": "progression", "chords": [c for c, _ in changes], "bars": [b for _, b in changes],
            "pattern": list(pattern), "bpm": bpm, **({"beatsPerBar": beats_per_bar} if beats_per_bar else {})}


def tap(pattern, bpm, bars=2, beats_per_bar=None):
    """beats_per_bar: 3 for 3/4, 2 for 2/4, 6 for 6/8 counted in eighths; default 4."""
    return {"type": "tap", "pattern": list(pattern), "bpm": bpm, "bars": bars,
            **({"beatsPerBar": beats_per_bar} if beats_per_bar else {})}


def listen(prompt, sounds, options, answer):
    """sounds: list of note groups played one after another; each group sounds together (a chord)."""
    return {"type": "listen", "prompt": T(prompt), "sound": [[midi(n) for n in group] for group in sounds],
            "options": [T(o) for o in options], "answer": answer}


def quiz(prompt, options, answer, why=None, visual=None):
    return {"type": "quiz", "prompt": T(prompt), "options": [T(o) for o in options], "answer": answer,
            **({"why": T(why)} if why else {}), "visual": visual or {"type": "none"}}


# ---------------------------------------------------------------- structure

def lesson(lid, title, steps, minutes=4, xp=20, kind="lesson", free=False, arrangement=None):
    """arrangement: a song's full arrangement (songbook.Song.meta()); its last step is then the whole song."""
    return {"id": lid, "title": T(title), "kind": kind, "minutes": minutes, "xp": xp, "free": free, "steps": steps,
            **({"arrangement": arrangement} if arrangement else {})}


def unit(uid, title, summary, lessons):
    return {"id": uid, "title": T(title), "summary": T(summary), "lessons": lessons}


def course(cid, title, subtitle, instrument, symbol, accent, units):
    return {"id": cid, "title": T(title), "subtitle": T(subtitle), "instrument": instrument, "symbol": symbol, "accent": accent, "units": units}
