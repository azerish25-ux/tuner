#!/usr/bin/env python3
"""Build Timbre's Learn curriculum.

python3 tools/curriculum/build.py            # validate and write
python3 tools/curriculum/build.py --check    # validate only
python3 tools/curriculum/build.py --check --only ear,theory   # validate some courses
python3 tools/curriculum/build.py --check --editions          # also list each songbook edition's key
python3 tools/curriculum/build.py --check --clips             # list the technique clips still to shoot

Reads every course module listed in COURSES (tools/curriculum/courses/<name>.py, each
defining COURSE = course(...)), validates it, assigns string keys, and writes
ios/Sources/TimbreCore/Resources/curriculum.json and the English
ios/Timbre/Resources/en.lproj/Learn.strings. Text keys are a hash of the English text,
so the same sentence is translated once and edits only invalidate what changed.
"""
from __future__ import annotations

import hashlib
import importlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from lib import QUALITIES, TUNINGS, Text, fretted, name  # noqa: E402

COURSES = ["guitar", "ukulele", "bass", "violin", "cello", "mandolin", "banjo", "ear", "theory", "rhythm", "voice", "songs", "originals", "songs_part3",
           "ukulele_songbook", "mandolin_songbook", "violin_songbook"]
LIMITS = {"title": 42, "body": 300, "prompt": 140, "option": 48, "hint": 120, "why": 220, "summary": 120, "subtitle": 80}
RANGES = {"guitar": (40, 88), "ukulele": (60, 81), "bass": (28, 67), "violin": (55, 93), "cello": (36, 76),
          "mandolin": (55, 88), "banjo": (50, 79), None: (36, 96)}

strings: dict[str, str] = {}
errors: list[str] = []


def key_for(text: str) -> str:
    return "L" + hashlib.sha1(text.encode("utf-8")).hexdigest()[:10]


def encode(value, where: str, field: str = ""):
    """Replaces Text objects with {"k", "t"} and checks their length."""
    if isinstance(value, Text):
        limit = LIMITS.get(field)
        if limit and len(value.text) > limit:
            errors.append(f"{where}: {field} longer than {limit}: {value.text!r}")
        if not value.text:
            errors.append(f"{where}: empty {field}")
        key = key_for(value.text)
        strings[key] = value.text
        return {"k": key, "t": value.text}
    if isinstance(value, dict):
        return {k: encode(v, where, k) for k, v in value.items()}
    if isinstance(value, list):
        singular = {"options": "option"}.get(field, field)
        return [encode(v, where, singular) for v in value]
    return value


def instrument_kind(course: dict) -> str | None:
    inst = course.get("instrument") or ""
    return next((kind for kind in TUNINGS if inst.startswith(kind)), None)


def check_note(n: dict, kind: str | None, where: str):
    lo, hi = RANGES.get(kind, RANGES[None])
    if not lo <= n["m"] <= hi:
        errors.append(f"{where}: {name(n['m'])} out of range for {kind or 'this course'}")
    at = n.get("at")
    if at and kind:
        if not 1 <= at["s"] <= len(TUNINGS[kind]):
            errors.append(f"{where}: string {at['s']} doesn't exist")
        elif kind == "banjo" and at["s"] == 5 and at["f"] > 0:
            errors.append(f"{where}: the banjo's short fifth string is played open only")
        elif fretted(kind, at["s"], at["f"]) != n["m"]:
            errors.append(f"{where}: string {at['s']} fret {at['f']} is {name(fretted(kind, at['s'], at['f']))}, not {name(n['m'])}")


# Answers that name a direction ("Up", "Going down", "It climbs", "It falls").
UP = re.compile(r"(going )?up|it (climbs|rises)|higher", re.I)
DOWN = re.compile(r"(going )?down|it (falls|drops)|lower", re.I)


def check_direction(step: dict, at: str):
    """A listen step's answer must match what its sound does: up/down answers follow the first move between
    the note groups (a chord counts at its average pitch); "Which is higher/lower?" over two sounds, with one
    option per sound in playing order ("The first", "String 5"), must pick the higher or lower one."""
    levels = [sum(group) / len(group) for group in step["sound"] if group]
    texts = [o.text for o in step["options"]]
    answer = texts[step["answer"]]
    moves = [b - a for a, b in zip(levels, levels[1:]) if b != a]
    ups = [t for t in texts if UP.fullmatch(t)]
    downs = [t for t in texts if DOWN.fullmatch(t)]
    if len(texts) == 2 and len(ups) == 1 and len(downs) == 1 and moves:
        heard = "up" if moves[0] > 0 else "down"
        said = "up" if answer in ups else "down"
        if heard != said:
            errors.append(f"{at}: the sound goes {heard} first, but the answer is {answer!r}")
    prompt = step["prompt"].text.lower()
    asks = re.search(r"\b(higher|lower)\b", prompt)
    if asks and not ups and len(texts) == 2 and len(levels) == 2 and levels[0] != levels[1]:
        first_wins = (levels[0] > levels[1]) == (asks.group(1) == "higher")
        if step["answer"] != (0 if first_wins else 1):
            errors.append(f"{at}: asks which is {asks.group(1)}, but the answer is {answer!r}")


def check_lesson(lesson: dict, kind: str | None, where: str):
    steps = lesson["steps"]
    if not 3 <= len(steps) <= 16:
        errors.append(f"{where}: {len(steps)} steps (3–16)")
    if all(s["type"] == "explain" for s in steps):
        errors.append(f"{where}: nothing to play or answer")
    for i, step in enumerate(steps):
        at = f"{where} step {i + 1} ({step['type']})"
        t = step["type"]
        if t in ("notes", "along"):
            if not step["notes"]:
                errors.append(f"{at}: no notes")
            for n in step["notes"]:
                check_note(n, kind, at)
            if t == "along" and not 30 <= step["bpm"] <= 220:
                errors.append(f"{at}: bpm {step['bpm']}")
        if t in ("quiz", "listen"):
            if not 2 <= len(step["options"]) <= 4 or not 0 <= step["answer"] < len(step["options"]):
                errors.append(f"{at}: answer/options")
            texts = [o.text for o in step["options"]]
            if len(set(texts)) != len(texts):
                errors.append(f"{at}: duplicate options")
        if t == "listen" and not all(step["sound"]):
            errors.append(f"{at}: empty sound")
        elif t == "listen" and 0 <= step["answer"] < len(step["options"]):
            check_direction(step, at)
        if t == "progression" and (not step["chords"] or len(step["chords"]) != len(step["bars"]) or any(n < 1 for n in step["bars"])):
            errors.append(f"{at}: chords and bars")
        if t in ("strum", "tap", "progression"):
            bar = step.get("beatsPerBar") or max(4, int(max(step["pattern"] or [0])) + 1)
            if not step["pattern"] or any(not 0 <= b < bar for b in step["pattern"]) or not 2 <= bar <= 12:
                errors.append(f"{at}: pattern outside its {bar}-beat bar")


# Every song lesson (kind "song") is a full arrangement: intro, verses, choruses, outro, 1.5 to 3 minutes, ending on
# the whole song. One exception: an instrument course's strummed song (its chords, no melody) ends on the whole
# song's chord progression, as long, because a take is a play-along and a strum isn't judged note by note. The
# Songs tab's own courses have no exception.
SONG_TAB_COURSES = {"songs", "originals", "standards"}
SONG_SECONDS = (90, 180)
SECTION_KINDS = {"intro", "verse", "chorus", "bridge", "solo", "interlude", "outro"}
# Chord qualities the chord recognizer (TimbreCore ChordRecognizer.Quality) can hear; a song's chart stays inside them.
RECOGNIZED = {"maj", "min", "7", "maj7", "m7", "sus2", "sus4", "5"}
# A take's notes must start at least this far apart at the song's tempo, so the play-along judge can tell them apart.
MIN_GAP_SECONDS = 0.15
song_lengths: dict[str, list[float]] = {}
lyric_songs: dict[str, list[str]] = {}


def clock(seconds: float) -> str:
    return f"{int(seconds // 60)}:{int(round(seconds % 60)):02d}"


def check_shape(shape: dict, kind: str | None, where: str):
    """A chart's chord shape: a quality the recognizer hears, one fret per string of the course's instrument (a
    course without one charts for guitar), and only notes of the chord, root included."""
    if shape["quality"] not in RECOGNIZED:
        errors.append(f"{where}: {shape['name']} ({shape['quality']}) isn't a chord the recognizer hears")
    instrument = kind or "guitar"
    frets = shape["frets"]
    if len(frets) != len(TUNINGS[instrument]):
        errors.append(f"{where}: {shape['name']} has {len(frets)} strings, not a {instrument} shape")
        return
    played = {fretted(instrument, len(frets) - i, f) % 12 for i, f in enumerate(frets) if f >= 0}
    tones = {(shape["root"] + i) % 12 for i in QUALITIES[shape["quality"]]}
    if not played <= tones or shape["root"] % 12 not in played:
        errors.append(f"{where}: the {shape['name']} shape {frets} doesn't spell {shape['name']} on {instrument}")


def check_arrangement(lesson: dict, kind: str | None, course_id: str, where: str):
    """A song's arrangement agrees with its last step (the whole song): same tempo and meter, bars that hold every
    note, one note at a time (the judge follows a single line), sections that cover the bars in order, a chord chart
    inside them with a recognizable shape for each chord, lyrics only on notes, and a length of 1.5 to 3 minutes."""
    arr = lesson["arrangement"]
    take = lesson["steps"][-1]
    if take["type"] != "along":
        errors.append(f"{where}: an arranged song ends on its whole take")
        return
    bpb = arr["beatsPerBar"]
    if arr["bpm"] != take["bpm"] or bpb != take.get("beatsPerBar", 4):
        errors.append(f"{where}: arrangement tempo or meter differs from the take")
    end = max(n["b"] + n["d"] for n in take["notes"])
    bars = arr["bars"]
    if not (bars - 1) * bpb < end <= bars * bpb + 1e-6:
        errors.append(f"{where}: {bars} bars but the notes end at beat {end:g}")
    cursor = 0
    for section in arr["sections"]:
        if section["kind"] not in SECTION_KINDS:
            errors.append(f"{where}: section kind {section['kind']!r}")
        if section["bar"] != cursor or section["bars"] < 1:
            errors.append(f"{where}: section {section['name'].text!r} at bar {section['bar']} ({section['bars']} bars), expected bar {cursor}")
        cursor = section["bar"] + section["bars"]
    if cursor != bars:
        errors.append(f"{where}: sections cover {cursor} of {bars} bars")
    notes_ = sorted(take["notes"], key=lambda n: n["b"])
    for a, b in zip(notes_, notes_[1:]):
        if b["b"] < a["b"] + a["d"] - 1e-6:
            errors.append(f"{where}: notes overlap at beat {b['b']:g}; a take is one line")
            break
        if (b["b"] - a["b"]) * 60 / arr["bpm"] < MIN_GAP_SECONDS - 1e-9:
            errors.append(f"{where}: notes {b['b'] - a['b']:g} beats apart at beat {b['b']:g}, too quick to judge")
            break
    for shape in arr["shapes"]:
        check_shape(shape, kind, where)
    names = {shape["name"] for shape in arr["shapes"]}
    last = (-1, -1.0)
    for change in arr["chords"]:
        at = (change["bar"], change["beat"])
        if at <= last or not 0 <= change["bar"] < bars or not 0 <= change["beat"] < bpb:
            errors.append(f"{where}: chord change at bar {change['bar']} beat {change['beat']}")
        if change["name"] != "N" and change["name"] not in names:
            errors.append(f"{where}: no shape for {change['name']}")
        last = at
    seconds = bars * bpb * 60 / arr["bpm"]
    if not SONG_SECONDS[0] <= seconds <= SONG_SECONDS[1]:
        errors.append(f"{where}: the song runs {clock(seconds)} (1:30 to 3:00)")
    song_lengths.setdefault(course_id, []).append(seconds)
    sung = [n for n in take["notes"] if n.get("y") not in (None, "_")]
    held = None
    for n in take["notes"]:
        if "yl" in n and n.get("y") in (None, "_"):
            errors.append(f"{where}: a lyric line starts on a note without a syllable")
        if "y" in n and (not isinstance(n["y"], str) or not n["y"].strip("-")):
            errors.append(f"{where}: empty syllable")
        if n.get("y") == "_" and held is None:
            errors.append(f"{where}: a held note with no syllable before it")
        held = n.get("y")
    if sung:
        lyric_songs.setdefault(course_id, []).append(lesson["id"])
        if not sung[0].get("yl"):
            errors.append(f"{where}: the first sung syllable must start a line")
        if not arr.get("words"):
            errors.append(f"{where}: sung words need their credit")
    elif arr.get("words"):
        errors.append(f"{where}: words credited but none sung")
    # A lyric line (read as the app's LyricSheet reads it) is sung inside one section; a section starts at its bar,
    # less its upbeat.
    starts = [s["bar"] * bpb - s.get("pickup", 0) for s in arr["sections"]]

    def section_at(beat):
        return max((i for i, start in enumerate(starts) if start <= beat + 1e-6), default=0)

    line = None
    for n in sorted(take["notes"], key=lambda n: n["b"]) + [{"b": float("inf"), "d": 0}]:
        if "y" not in n or n.get("yl") or (line is None and n["y"] != "_"):
            if line and section_at(line[0]) != section_at(line[1] - 0.01):
                errors.append(f"{where}: a lyric line at beat {line[0]:g} crosses into the next section")
            line = [n["b"], n["b"] + n["d"]] if "y" in n and n["y"] != "_" else None
        elif line:
            line[1] = n["b"] + n["d"]


def check_strummed_song(lesson: dict, kind: str | None, course_id: str, where: str):
    """A strummed song (no arrangement) ends on the whole song's chord progression: 1.5 to 3 minutes of recognizable
    chords."""
    last = lesson["steps"][-1]
    if last["type"] != "progression" or kind is None or course_id in SONG_TAB_COURSES:
        errors.append(f"{where}: a song needs its full arrangement")
        return
    bpb = last.get("beatsPerBar") or max(4, int(max(last["pattern"] or [0])) + 1)
    seconds = sum(last["bars"]) * bpb * 60 / last["bpm"]
    if not SONG_SECONDS[0] <= seconds <= SONG_SECONDS[1]:
        errors.append(f"{where}: the strummed song runs {clock(seconds)} (1:30 to 3:00)")
    for shape in last["chords"]:
        check_shape(shape, kind, where)
    song_lengths.setdefault(course_id, []).append(seconds)


def median(values: list[float]) -> float:
    ordered = sorted(values)
    half = len(ordered) // 2
    return ordered[half] if len(ordered) % 2 else (ordered[half - 1] + ordered[half]) / 2


def main() -> int:
    courses, lesson_ids = [], set()
    only = next((a.split(",") for a in sys.argv[sys.argv.index("--only") + 1:][:1]), None) if "--only" in sys.argv else None
    if only and "--check" not in sys.argv:
        print("--only needs --check (a partial build would drop courses)")
        return 2
    for module in COURSES:
        if only and module not in only:
            continue
        path = HERE / "courses" / f"{module}.py"
        if not path.exists():
            print(f"(skipping {module}: not written yet)")
            continue
        course = importlib.import_module(f"courses.{module}").COURSE
        if not course:
            print(f"(skipping {module}: no units yet)")
            continue
        kind = instrument_kind(course)
        for u, unit in enumerate(course["units"]):
            for lesson in unit["lessons"]:
                where = f"{course['id']}/{lesson['id']}"
                if lesson["id"] in lesson_ids:
                    errors.append(f"{where}: duplicate lesson id")
                lesson_ids.add(lesson["id"])
                if u == 0:
                    lesson["free"] = True
                check_lesson(lesson, kind, where)
                if "arrangement" in lesson:
                    check_arrangement(lesson, kind, course["id"], where)
                elif lesson["kind"] == "song":
                    check_strummed_song(lesson, kind, course["id"], where)
        courses.append(encode(course, course["id"]))
    total = sum(len(u["lessons"]) for c in courses for u in c["units"])
    if errors:
        print("\n".join(errors))
        print(f"{len(errors)} problems")
        return 1
    print(f"OK: {len(courses)} courses, {total} lessons, {len(strings)} strings")
    if song_lengths:
        every = [s for lengths in song_lengths.values() for s in lengths]
        sung = sum(len(ids) for ids in lyric_songs.values())
        print(f"Songs: {len(every)} whole songs, {sung} with lyrics, "
              f"{clock(min(every))} min / {clock(median(every))} median / {clock(max(every))} max")
        for course_id, lengths in song_lengths.items():
            print(f"  {course_id:10} {len(lengths):3} songs, {len(lyric_songs.get(course_id, [])):2} with lyrics, "
                  f"{clock(min(lengths))} / {clock(median(lengths))} / {clock(max(lengths))}")
    if "--clips" in sys.argv:
        from lib import PLANNED_CLIPS, bundled_clips
        for name, step in sorted(PLANNED_CLIPS.items()):
            print(f"  clip {name:22} {'bundled' if name in bundled_clips() else 'to shoot'}: {step}")
    if "--editions" in sys.argv:
        from courses.songbook_sources import REPORT
        print("\n".join(REPORT))
    if "--check" in sys.argv:
        return 0
    out = ROOT / "ios/Sources/TimbreCore/Resources/curriculum.json"
    out.write_text(json.dumps({"version": 1, "courses": courses}, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    table = ROOT / "ios/Timbre/Resources/en.lproj/Learn.strings"
    esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")  # noqa: E731
    table.write_text("".join(f'"{k}" = "{esc(v)}";\n' for k, v in sorted(strings.items())), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
