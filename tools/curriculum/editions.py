"""Instrument editions of the song collections (Songs, Standards & Classics, Originals): every whole song moved to a
key that suits another instrument and fretted where that instrument's player would play it, so the Songs tab has a
real songbook on ukulele, mandolin and violin, not only on guitar.

An edition keeps the song itself. Its form (sections and bars), rhythm, words and chord chart move whole, by one
interval, to the new key; the chart's chords take the instrument's own shapes; the melody is placed string by string.
- Ukulele: keys of C, G, F, D or A, A minor, D minor or E minor. The fourth string is tuned high (re-entrant G), so a
  melody stays on strings 1 to 3, as ukulele players read a tune.
- Mandolin and violin (both G D A E): G, D, A or C, E minor, A minor or B minor, in first position (frets or half
  steps 0 to 7, two to a finger).
A note the new key can't reach (a low guitar intro or bass run) moves by an octave; nothing else changes.

Choosing the key is a small search over every candidate key and octave, scored by how far the tune leaves first
position, how many notes must move by an octave, how hard the chart's shapes are and how usual the key is on the
instrument. Tunes the instrument's own course already teaches are left out (one version of a tune per instrument).

Each edition is a short song lesson: the key (with its home chord or the first notes on the neck), the chords to
hold (ukulele), the verse's chords in time (ukulele and mandolin), the first phrase at your own pace, the verse or
chorus slower, then the whole song.
"""
from __future__ import annotations

import copy

from lib import NAMES, T, TUNINGS, chord, explain, fretboard, lesson, parse_chord_name, position, unit

FLAT_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
SHARP_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "Bb", "B"]
KEY_NAMES = {(0, False): "C", (2, False): "D", (4, False): "E", (5, False): "F", (7, False): "G", (9, False): "A",
             (10, False): "B flat", (9, True): "A minor", (2, True): "D minor", (4, True): "E minor",
             (11, True): "B minor", (7, True): "G minor"}
QUALITY_SUFFIX = {"maj": "", "min": "m", "7": "7", "maj7": "maj7", "m7": "m7", "sus2": "sus2", "sus4": "sus4", "5": "5"}

# ---------------------------------------------------------------- shapes
# (frets, fingers, difficulty 1 easy … 4 hard) by root pitch class and quality. Frets list the strings from the lowest-
# numbered course's far side, as lib.chord reads them: ukulele G C E A, mandolin and violin G D A E.

UKULELE_SHAPES = {
    "maj": {0: ("0003", "0003", 1), 1: ("1114", "1114", 3), 2: ("2220", "1230", 2), 3: ("0331", "0341", 3),
            4: ("4442", "2341", 4), 5: ("2010", "2010", 1), 6: ("3121", "3121", 3), 7: ("0232", "0132", 1),
            8: ("5343", "3121", 4), 9: ("2100", "2100", 1), 10: ("3211", "3211", 2), 11: ("4322", "3211", 3)},
    "min": {0: ("0333", "0123", 2), 1: ("1104", "1204", 3), 2: ("2210", "2310", 1), 3: ("3321", "3421", 3),
            4: ("0432", "0321", 2), 5: ("1013", "1024", 2), 6: ("2120", "2130", 2), 7: ("0231", "0231", 2),
            8: ("1342", "1342", 3), 9: ("2000", "2000", 1), 10: ("3111", "3111", 3), 11: ("4222", "3111", 3)},
    "7": {0: ("0001", "0001", 1), 1: ("1112", "1112", 3), 2: ("2223", "1112", 2), 3: ("3334", "1112", 3),
          4: ("1202", "1203", 2), 5: ("2313", "2314", 3), 7: ("0212", "0213", 1), 9: ("0100", "0100", 1),
          10: ("1211", "1211", 2), 11: ("2322", "1211", 2)},
    "maj7": {0: ("0002", "0001", 1), 2: ("2224", "1113", 2), 4: ("1302", "1302", 3), 5: ("2413", "2413", 3),
             7: ("0222", "0123", 2), 9: ("1100", "1200", 1), 10: ("3210", "3210", 2)},
    "m7": {0: ("3333", "1111", 2), 1: ("1102", "1203", 2), 2: ("2213", "2314", 2), 4: ("0202", "0102", 1),
           5: ("1313", "1324", 3), 6: ("2424", "1324", 3), 7: ("0211", "0211", 2), 9: ("0000", "0000", 1),
           11: ("2222", "1111", 2)},
    "sus2": {0: ("0233", "0134", 2), 2: ("2200", "1200", 1), 5: ("0013", "0012", 1), 7: ("0230", "0120", 1),
             9: ("2402", "1302", 2)},
    "sus4": {0: ("0013", "0012", 1), 2: ("0230", "0120", 1), 4: ("4400", "3400", 2), 5: ("3011", "3011", 2),
             7: ("0233", "0123", 2), 9: ("2200", "1200", 1)},
    "5": {0: ("0033", "0034", 2), 2: ("2255", "1134", 3), 4: ("4477", "1134", 4), 5: ("5013", "4013", 3),
          7: ("0235", "0124", 2), 9: ("2400", "1300", 1), 11: ("4622", "3411", 4)},
}

# Mandolin and violin share G D A E: one table. Violin charts show the chord's notes on the four strings (what a
# second player could double-stop), as the violin course's charts do.
GDAE_SHAPES = {
    "maj": {0: ("0230", "0120", 1), 2: ("2002", "1002", 1), 4: ("1224", "1224", 3), 5: ("2331", "1342", 3),
            7: ("0023", "0012", 1), 9: ("2240", "1130", 1), 10: ("3011", "3011", 2)},
    "min": {0: ("0133", "0134", 3), 2: ("2001", "2001", 1), 4: ("0220", "0120", 1), 6: ("2442", "1341", 3),
            7: ("0013", "0013", 1), 9: ("2235", "1124", 2), 11: ("4022", "3011", 2)},
    "7": {0: ("3230", "2130", 2), 2: ("2032", "1032", 2), 4: ("1020", "1020", 1), 7: ("0021", "0021", 1),
          9: ("2243", "1132", 2), 11: ("2122", "2134", 2)},
    "maj7": {7: ("0022", "0012", 1)},
    "m7": {4: ("0020", "0010", 1), 9: ("2233", "1123", 2)},
    "sus2": {2: ("2000", "1000", 1), 9: ("2220", "1230", 2)},
    "sus4": {2: ("2003", "1004", 1), 9: ("2255", "1134", 3)},
    "5": {2: ("2005", "1004", 2), 7: ("0053", "0043", 2), 9: ("2200", "1200", 1)},
}

# ---------------------------------------------------------------- keys (tonic pitch class, minor) → how usual (0 best)
UKULELE_KEYS = {(0, False): 0, (7, False): 0.5, (5, False): 1, (2, False): 1.5, (9, False): 2.5,
                (9, True): 0, (2, True): 1, (4, True): 1}
GDAE_KEYS = {(7, False): 0, (2, False): 0, (9, False): 0.5, (0, False): 0.5,
             (4, True): 0.5, (9, True): 0.5, (11, True): 1.5}
FLAT_KEYS = {(5, False), (10, False), (2, True), (7, True)}


class Instrument:
    def __init__(self, kind, prefix, shapes, keys, low, high, intro_title, intro_body, strums, chord_steps, fingers=None,
                 max_fret=7):
        self.kind = kind
        self.prefix = prefix
        self.shapes = shapes
        self.keys = keys
        self.low, self.high = low, high
        self.intro_title = intro_title
        self.intro_body = intro_body
        self.strums = strums
        self.chord_steps = chord_steps
        self.fingers = fingers or {}
        self.max_fret = max_fret
        self._places = {}

    # ------------------------------------------------------------ where a note is played
    def place(self, m):
        """Where `m` is played (a fresh dict each time; the search asks for the same notes thousands of times)."""
        if m not in self._places:
            self._places[m] = self._place(m)
        found = self._places[m]
        return dict(found) if found is not None else None

    def _place(self, m):
        if self.kind == "ukulele":
            # Strings 1 to 3 only: the fourth string (G4) sounds inside the tune's range, so a ukulele melody leaves it
            # to the chords. Lowest fret wins.
            options = [(s, m - TUNINGS["ukulele"][s - 1]) for s in (1, 2, 3) if 0 <= m - TUNINGS["ukulele"][s - 1] <= 12]
            if not options:
                return None
            s, f = min(options, key=lambda o: (o[1], o[0]))
            return {"s": s, "f": f}
        if not self.low <= m <= self.high:
            return None
        at = position(self.kind, m, max_fret=self.max_fret)
        if at["f"] in self.fingers:
            at["g"] = self.fingers[at["f"]]
        return at

    def note_cost(self, m, at):
        """First position is free; higher frets cost more. On mandolin and violin a tune also prefers to sit above the
        G string's open D (D4), where those instruments sing."""
        f = at["f"]
        if self.kind == "ukulele":
            return 0 if f <= 4 else 0.5 if f == 5 else 2 if f <= 7 else 4 if f <= 10 else 6
        return (0 if f <= 7 else 1.5 if f <= 9 else 4) + (0.4 if m < 62 else 0)

    def shape(self, root, quality, spelled):
        entry = self.shapes.get(quality, {}).get(root % 12)
        if entry is None:
            return None, None
        frets, fingers, difficulty = entry
        return chord(self.kind, spelled, frets, fingers), difficulty


def fold(m, low, high):
    """`m` moved by octaves into low…high, and whether it moved; None when no octave fits."""
    moved = m
    while moved < low:
        moved += 12
    while moved > high:
        moved -= 12
    return (moved, moved != m) if low <= moved <= high else (None, True)


def tonic(arrangement):
    """The song's home chord, read from its last chord: (pitch class, minor)."""
    last = [c["name"] for c in arrangement["chords"] if c["name"] != "N"][-1]
    root, quality = parse_chord_name(last)
    return root, quality in ("min", "m7")


def spell(symbol, shift, key):
    if symbol == "N":
        return symbol
    root, quality = parse_chord_name(symbol)
    names = FLAT_NAMES if key in FLAT_KEYS else NAMES if key in ((0, False), (9, True)) else SHARP_NAMES
    return names[(root + shift) % 12] + QUALITY_SUFFIX[quality]


class Plan:
    """One song in one key: its notes, placements and chord shapes, and what it costs to play.

    The tune moves by `shift`; a section that still leaves the instrument's range (a low guitar intro, a riff on the
    bass strings) moves whole by an octave, so its line keeps its shape; only a note that still can't be reached then
    moves on its own."""

    def __init__(self, inst, take, arrangement, shift, octave, key, source_key):
        self.inst = inst
        self.shift = shift + 12 * octave
        self.key = key
        self.cost = float(inst.keys[key]) * 6 - (4 if key == source_key else 0)
        self.notes = []
        self.folded = 0
        self.lifted = 0
        spans = [section_span(arrangement, i)[:2] for i in range(len(arrangement["sections"]))]
        groups = [[] for _ in spans]
        for n in take["notes"]:
            index = next((i for i, (start, end) in enumerate(spans) if start - 1e-6 <= n["b"] < end - 1e-6), len(spans) - 1)
            groups[index].append(n)
        for group in groups:
            if not group:
                continue
            offset = min((0, 12, -12, 24, -24), key=lambda o: (self._misses(group, o), abs(o)))
            self.lifted += len(group) if offset else 0
            for n in group:
                m, moved = fold(n["m"] + self.shift + offset, inst.low, inst.high)
                at = inst.place(m) if m is not None else None
                if at is None:
                    self.cost = float("inf")
                    return
                self.folded += moved
                self.cost += inst.note_cost(m, at) + (3 if moved else 0) + (0.5 if offset else 0)
                self.notes.append({"m": m, "b": n["b"], "d": n["d"], "at": at, **{k: n[k] for k in ("y", "yl") if k in n}})
        self.notes.sort(key=lambda n: n["b"])
        self.specs = {}
        for change in arrangement["chords"]:
            if change["name"] == "N" or change["name"] in self.specs:
                continue
            root, quality = parse_chord_name(change["name"])
            spelled = spell(change["name"], shift, key)
            spec, difficulty = inst.shape(root + shift, quality, spelled)
            if spec is None:
                self.cost = float("inf")
                return
            self.specs[change["name"]] = spec
            self.cost += difficulty * (3 if inst.chord_steps else 1)
        if inst.kind == "ukulele":
            self._finger_ukulele()

    def _misses(self, group, offset):
        """How badly a section sits at this octave: notes out of range count most, then notes past first position."""
        total = 0.0
        for n in group:
            m = n["m"] + self.shift + offset
            at = self.inst.place(m) if self.inst.low <= m <= self.inst.high else None
            total += 10 if at is None else self.inst.note_cost(m, at)
        return total

    def _finger_ukulele(self):
        """One finger per fret in first position; a tune that climbs past fret 5 shifts its hand to fifth position
        for those notes (index at fret 5), and a lone fret-5 note in a first-position tune takes the little finger."""
        top = max(n["at"]["f"] for n in self.notes)
        for n in self.notes:
            f = n["at"]["f"]
            if f == 0:
                continue
            n["at"]["g"] = f if f <= 4 else 4 if top <= 5 else min(4, f - 4)


def best_plan(inst, take, arrangement):
    root, minor = tonic(arrangement)
    source_key = (root % 12, minor)
    plans = []
    for key in inst.keys:
        if key[1] != minor:
            continue
        shift = (key[0] - root) % 12
        if shift > 6:
            shift -= 12
        for octave in (-2, -1, 0, 1, 2, 3):
            plan = Plan(inst, take, arrangement, shift, octave, key, source_key)
            if plan.cost < float("inf"):
                plans.append(plan)
    # A tune that only fits by breaking its line here and there (more than a few single notes jumping an octave) is
    # left out rather than mangled: the guitar's version stays the one to play.
    plans = [p for p in plans if p.folded <= max(2, len(p.notes) * 0.03)]
    if not plans:
        return None
    return min(plans, key=lambda p: (p.cost, abs(p.shift)))


# ---------------------------------------------------------------- the lesson

def section_span(arrangement, index):
    """Beats (start, end) of a section, its upbeat included and the next section's upbeat left out, and its pickup."""
    bpb = arrangement["beatsPerBar"]
    sections = arrangement["sections"]
    section = sections[index]
    pickup = section.get("pickup", 0) if index > 0 else 0
    start = section["bar"] * bpb - pickup
    if index + 1 < len(sections):
        after = sections[index + 1]
        end = after["bar"] * bpb - after.get("pickup", 0)
    else:
        end = arrangement["bars"] * bpb
    return start, end, pickup


def learning_sections(arrangement):
    """The sections worth learning on their own, best first: verses, then choruses, then the rest but intro and outro."""
    sections = arrangement["sections"]
    order = [i for i, s in enumerate(sections) if s["kind"] == "verse"]
    order += [i for i, s in enumerate(sections) if s["kind"] == "chorus"]
    order += [i for i, s in enumerate(sections) if s["kind"] in ("solo", "bridge", "interlude")]
    return order or list(range(len(sections)))


def excerpt(notes_, arrangement, index):
    """A section's notes from beat 0 (its upbeat in a lead-in bar), as songbook's Song.along plays one part."""
    bpb = arrangement["beatsPerBar"]
    start, end, pickup = section_span(arrangement, index)
    offset = start - (bpb - pickup) if pickup else start
    out = []
    for n in notes_:
        if start - 1e-6 <= n["b"] < end - 1e-6:
            out.append({**n, "at": dict(n["at"]), "b": round(n["b"] - offset, 4)})
    return out


def bar_chords(arrangement, index, renamed):
    """The section's chord in each of its bars, or None when a chord changes inside a bar (or a bar has none)."""
    section = arrangement["sections"][index]
    changes = arrangement["chords"]
    out = []
    for bar in range(section["bar"], section["bar"] + section["bars"]):
        if any(c["bar"] == bar and c["beat"] > 0 for c in changes):
            return None
        current = [c for c in changes if (c["bar"], c["beat"]) <= (bar, 0)]
        if not current or current[-1]["name"] == "N":
            return None
        out.append(renamed[current[-1]["name"]])
    return out


STRUMS = {2: [0, 1], 3: [0, 1, 2], 4: [0, 1, 2, 3], 6: [0, 3], 9: [0, 3, 6], 12: [0, 3, 6, 9]}
TITLES = {"verse": "The verse", "chorus": "The chorus"}


def edition(inst, source):
    """The source song lesson as this instrument's edition, or None when no key suits it."""
    arrangement = source["arrangement"]
    take = source["steps"][-1]
    plan = best_plan(inst, take, arrangement)
    if plan is None:
        return None
    bpb = arrangement["beatsPerBar"]
    bpm = arrangement["bpm"]
    renamed = {old: spec["name"] for old, spec in plan.specs.items()}

    chart = copy.copy(arrangement)
    chart["chords"] = [{**c, "name": renamed.get(c["name"], c["name"])} for c in arrangement["chords"]]
    used = []
    for change in chart["chords"]:
        if change["name"] != "N" and change["name"] not in used:
            used.append(change["name"])
    by_name = {spec["name"]: spec for spec in plan.specs.values()}
    chart["shapes"] = [by_name[n] for n in used]

    whole = {"type": "along", "notes": plan.notes, "bpm": bpm, "beatsPerBar": bpb, **({"title": take["title"]} if "title" in take else {})}
    order = learning_sections(arrangement)
    learn = next((i for i in order if len(excerpt(plan.notes, arrangement, i)) >= 4), order[0])
    part = excerpt(plan.notes, arrangement, learn)
    kind = arrangement["sections"][learn]["kind"]
    first = [{"m": n["m"], "b": float(i), "d": 1.0, "at": dict(n["at"])} for i, n in enumerate(part[:8])]

    home = by_name[renamed[[c["name"] for c in arrangement["chords"] if c["name"] != "N"][-1]]]
    key_name = KEY_NAMES[plan.key]
    if inst.kind == "ukulele":
        visual = {"type": "chord", "chord": home}
    else:
        dots = []
        for n in first:
            dot = (n["at"]["s"], n["at"]["f"], n["at"].get("g")) if n["at"]["f"] else (n["at"]["s"], 0)
            if dot[:2] not in [d[:2] for d in dots]:
                dots.append(tuple(d for d in dot if d is not None))
        visual = fretboard(inst.kind, dots, frets=max(5, max(n["at"]["f"] for n in first)))
    steps = [explain(inst.intro_title.format(key=key_name), inst.intro_body.format(key=key_name), visual)]

    strummed = None
    for index in order:
        bars = bar_chords(arrangement, index, renamed)
        if bars:
            strummed = bars[:8]
            break
    if inst.chord_steps and strummed:
        held = []
        for name in strummed:
            if name not in held:
                held.append(name)
        steps += [{"type": "chord", "chord": by_name[name]} for name in held[:2]]
    steps.append({"type": "notes", "notes": first})
    if inst.strums and strummed and bpb in STRUMS:
        changes = []
        for name in strummed:
            if changes and changes[-1][0] == name:
                changes[-1][1] += 1
            else:
                changes.append([name, 1])
        steps.append({"type": "progression", "chords": [by_name[n] for n, _ in changes], "bars": [b for _, b in changes],
                      "pattern": STRUMS[bpb], "bpm": max(40, round(bpm * 0.8)),
                      **({"beatsPerBar": bpb} if bpb != 4 else {})})
    steps.append({"type": "along", "notes": part, "bpm": max(36, round(bpm * 0.8)), "beatsPerBar": bpb,
                  "title": T(TITLES.get(kind, "The theme"))})
    steps.append(whole)
    seconds = arrangement["bars"] * bpb * 60 / bpm
    lid = f"{inst.prefix}-{source['id']}"
    return lesson(lid, source["title"], steps, minutes=int(round(4 + seconds / 60)), xp=30, kind="song",
                  arrangement=chart), plan


def tune_key(title):
    """A tune's key as the app matches versions: its main title, letters and digits only (SongsView.tuneKey)."""
    main = title.split(":")[0]
    return "".join(ch for ch in main.lower() if ch.isalnum())


def songbook(inst, sources, skip_course, summaries, report=None):
    """Units of editions, one per source unit that keeps a song. sources: [(unit, lessons)] in path order;
    skip_course: the instrument's own course (its tunes are left out); summaries: unit id → summary text."""
    taught = {tune_key(l["title"].text) for u in skip_course["units"] for l in u["lessons"] if l["kind"] == "song"}
    units = []
    for source_unit in sources:
        lessons = []
        for item in source_unit["lessons"]:
            if item["kind"] != "song" or "arrangement" not in item or tune_key(item["title"].text) in taught:
                continue
            made = edition(inst, item)
            if made is None:
                if report is not None:
                    report.append(f"{inst.kind}: {item['id']} left out (its line doesn't fit the instrument)")
                continue
            lesson_, plan = made
            if report is not None:
                report.append(f"{inst.kind}: {item['id']} in {KEY_NAMES[plan.key]} ({plan.shift:+d}), {plan.lifted} notes "
                              f"in sections moved an octave, {plan.folded} single notes moved, cost {plan.cost:.0f}")
            lessons.append(lesson_)
        if lessons:
            summary = summaries.get(source_unit["id"], source_unit["summary"])
            units.append(unit(f"{inst.prefix}-{source_unit['id']}", source_unit["title"], T(summary), lessons))
    return units


UKULELE = Instrument(
    "ukulele", "uke-sb", UKULELE_SHAPES, UKULELE_KEYS, 60, 81,
    intro_title="In {key}",
    intro_body="This edition is in {key}. Your fourth string is tuned high, so the tune stays on strings 1 to 3, and every "
               "chord in the chart is a ukulele shape.",
    strums=True, chord_steps=True)
MANDOLIN = Instrument(
    "mandolin", "man-sb", GDAE_SHAPES, GDAE_KEYS, 55, 88,
    intro_title="In {key}",
    intro_body="This edition is in {key}, in first position: two frets to a finger across the four pairs, and every chord "
               "in the chart is a mandolin shape.",
    strums=True, chord_steps=False, fingers={1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4})
VIOLIN = Instrument(
    "violin", "vln-sb", GDAE_SHAPES, GDAE_KEYS, 55, 88,
    intro_title="In {key}",
    intro_body="This edition is in {key}, in first position: the tune moves across the four strings with fingers 1 to 4, "
               "and the chord chart is there for whoever plays along with you.",
    strums=False, chord_steps=False, fingers={1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4})

# Unit summaries for every edition: what the unit holds on any instrument (an edition leaves out the tunes its
# instrument's course already teaches, so none counts its songs). A source summary that already fits is kept.
SUMMARIES = {
    "songs-1": "The tunes everyone learns first: slow tempos, short phrases, big wins.",
    "songs-2": "Campfire and folk songs with easy chord charts, to play or to sing over.",
    "songs-3": "Famous classical themes, from a Baroque canon to a Romantic lullaby.",
    "song-u4": "Old favorites from America's songbook, to strum and to sing.",
    "song-u6": "Two Mozart themes and two old airs, with minor keys and a wide range.",
    "std-1": "Campfire folk songs everyone can sing, with simple chord charts to strum.",
    "std-2": "Lullabies, ballads and carols to play slowly and let ring.",
    "orig-1": "New songs on open chords: campfire pop, a ballad, stomp-folk, reggae and country.",
    "orig-8": "Punk-pop, riff rock, dark 6/8 rock, an indie anthem and desert rock, on power chords.",
    "orig-9": "A ballad, a sea story in 6/8, a music-box waltz, a bright folk strummer and a dark song in a minor key.",
    "orig-4": "Indie pop, a power ballad, highlife, neo-soul and an anthem with a key change.",
    "orig-10": "Synth-pop, gospel-pop, dark pop, indie pop and a 6/8 finale, full of syncopation.",
}
