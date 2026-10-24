"""Full-length song arrangements for the Songs and Originals courses.

A song is a list of parts (intro, verses, choruses, a bridge, a solo, an outro) played back to back. Each part
is a melody in lib.along's "note:beats" notation, optional lyrics and a chord per bar. `song(...)` joins the parts
into the lesson's final take (one play-along with every note, each carrying its lyric syllable) and the lesson's
`arrangement` (tempo, meter, bars, the sections with their bar ranges, the chord chart and the chord shapes).

Parts
- `pickup`: beats of melody before the part's first full bar (an upbeat). The pickup sounds in the last bar of the
  part before; that part's last note is cut short to make room (a note *starting* there is an error). A song whose
  first part has a pickup starts with a lead-in bar of rest.
- The rest of the melody must fill whole bars.
- `chords`: one token per full bar ("G C D7 G"); "C,G" splits a bar in two (the first chord takes the extra beat
  of an odd meter); "N" is no chord. Chords apply to the part's full bars, not to its pickup.

Lyrics (one token per note, in order)
- Words are split into syllables at hyphens: "Twin-kle," is two syllables on two notes.
- "_" holds the previous syllable over the next note (a melisma), or marks a note with no word.
- "/" starts a new lyric line (the first syllable of a part always starts one).
- "~" is a hyphen that shows: "one~horse" sings "one-" and "horse" on two notes and reads "one-horse".
- "al- _ read-y": a hyphen at the end of a word followed by "_" holds the syllable, then the word goes on.
In the curriculum each sung note carries "y": its syllable (ending in "-" when it joins the next into a word), or "_"
for a note that holds the syllable before it; "yl": 1 marks the first syllable of a line. Notes outside the words
(intro, solo) have no "y".
"""
from __future__ import annotations

import math

from lib import T, Text, midi, name, position

KINDS = {"intro", "verse", "chorus", "bridge", "solo", "interlude", "outro"}
HIDDEN_HYPHEN = "-"
HELD = "_"                  # a note that holds the syllable before it
SHOWN_HYPHEN = "‑"     # non-breaking hyphen: kept in the text, never split onto two lines


class Part:
    def __init__(self, label, kind, melody, lyrics=None, chords=None, pickup=0.0, max_fret=None, first_fret=None):
        if kind not in KINDS:
            raise ValueError(f"{label}: unknown kind {kind!r}")
        self.label = label
        self.kind = kind
        self.melody = " ".join(melody.split())
        self.lyrics = lyrics
        self.chords = chords
        self.pickup = float(pickup)
        self.max_fret = max_fret
        self.first_fret = first_fret

    def with_lyrics(self, label, lyrics, kind=None):
        """The same music under other words (verse 2, the last chorus)."""
        return Part(label, kind or self.kind, self.melody, lyrics, self.chords, self.pickup, self.max_fret, self.first_fret)

    def instrumental(self, label, kind="solo"):
        return Part(label, kind, self.melody, None, self.chords, self.pickup, self.max_fret, self.first_fret)

    def __repr__(self):
        return f"Part({self.label!r})"


def tokens(melody):
    """(note or None for a rest, string or None, beats) for each token of a melody string."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        beats = float(length or 1)
        if n.lower() == "r":
            out.append((None, None, beats))
        else:
            n, _, s = n.partition("@")
            out.append((n, int(s) if s else None, beats))
    return out


def syllables(lyrics, where):
    """The lyric tokens of a part: (text or None, starts_line)."""
    out = []
    new_line = True
    for word in lyrics.split():
        if word == "/":
            new_line = True
            continue
        if word == "_":
            out.append((None, False))
            continue
        pieces = []
        current = ""
        for ch in word:
            if ch == "-":
                pieces.append(current + HIDDEN_HYPHEN)
                current = ""
            elif ch == "~":
                pieces.append(current + SHOWN_HYPHEN + HIDDEN_HYPHEN)
                current = ""
            else:
                current += ch
        if current or not pieces:
            pieces.append(current)            # "al-" then "_": the word goes on after a held note
        for piece in pieces:
            if not piece.strip(HIDDEN_HYPHEN + SHOWN_HYPHEN):
                raise ValueError(f"{where}: empty syllable in {word!r}")
            out.append((piece, new_line))
            new_line = False
    return out


class Song:
    def __init__(self, instrument, bpm, parts, beats_per_bar, shapes, words, max_fret, first_fret):
        self.instrument = instrument
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.parts = parts
        self.shapes = shapes or {}
        self.words = words
        self.max_fret = max_fret
        self.first_fret = first_fret
        self.notes, self.sections, self.changes, self.bars = self._build()

    # ------------------------------------------------------------ building

    def _place(self, part, note, string):
        if not self.instrument:
            return None
        max_fret = part.max_fret or self.max_fret
        first_fret = part.first_fret if part.first_fret is not None else self.first_fret
        at = position(self.instrument, note, max_fret=max_fret, prefer_string=string, first_fret=first_fret)
        if string and at["s"] != string:
            raise ValueError(f"{part.label}: {note} can't be played on string {string} within fret {max_fret}")
        return at

    def _part_notes(self, part, start):
        """The part's notes from beat `start` (where its pickup begins), with lyrics, and its length in beats."""
        where = f"{part.label}"
        beat = start
        notes = []
        for n, s, beats in tokens(part.melody):
            if n is not None:
                at = self._place(part, n, s)
                notes.append({"m": midi(n), "b": round(beat, 4), "d": beats, **({"at": at} if at else {})})
            beat += beats
        length = beat - start
        body = length - part.pickup
        if body <= 0 or abs(body / self.bpb - round(body / self.bpb)) > 1e-6:
            raise ValueError(f"{where}: {body:g} beats after a {part.pickup:g}-beat pickup is not whole {self.bpb}-beat bars")
        if part.lyrics:
            words = syllables(part.lyrics, where)
            if len(words) != len(notes):
                raise ValueError(f"{where}: {len(words)} lyric tokens for {len(notes)} notes\n  "
                                 + " ".join(f"{name(n['m'])}={w[0] or '_'}" for n, w in zip(notes, words)))
            for note, (text, line) in zip(notes, words):
                if text is not None:
                    note["y"] = text
                    if line:
                        note["yl"] = 1
                elif line:
                    raise ValueError(f"{where}: a line can't start on a held note")
                else:
                    note["y"] = HELD
        return notes, int(round(body / self.bpb))

    def _chords(self, part, bar, bars):
        if part.chords is None:
            return []
        cells = part.chords.split()
        if len(cells) != bars:
            raise ValueError(f"{part.label}: {len(cells)} chord bars for {bars} bars")
        out = []
        for index, cell in enumerate(cells):
            names = cell.split(",")
            split = [math.ceil(self.bpb / len(names))] + [self.bpb // len(names)] * (len(names) - 1)
            offset = 0
            for chord_name, beats in zip(names, split):
                if chord_name != "N" and chord_name not in self.shapes:
                    raise ValueError(f"{part.label}: no shape for chord {chord_name}")
                out.append((bar + index, offset, chord_name))
                offset += beats
        return out

    def _build(self):
        notes, sections, cells = [], [], []
        bar = 0
        for index, part in enumerate(self.parts):
            if index == 0 and part.pickup > 0:
                bar = 1                                   # a lead-in bar holds the opening pickup
            start = bar * self.bpb - part.pickup
            part_notes, part_bars = self._part_notes(part, start)
            if index > 0 and part.pickup > 0:
                for note in notes:
                    if note["b"] >= start - 1e-6:
                        raise ValueError(f"{part.label}: its pickup collides with a note of {self.parts[index - 1].label}")
                    if note["b"] + note["d"] > start + 1e-6:
                        note["d"] = round(start - note["b"], 4)
            notes += part_notes
            first = 0 if index == 0 else bar
            sections.append({"name": T(part.label), "kind": part.kind, "bar": first, "bars": bar + part_bars - first,
                             **({"pickup": part.pickup} if index > 0 and part.pickup else {})})
            cells += self._chords(part, bar, part_bars)
            bar += part_bars
        # The chord chart as changes: a chord carried on into the next bar is not repeated.
        changes, current = [], None
        for chord_bar, beat, chord_name in cells:
            if chord_name != current:
                changes.append({"bar": chord_bar, "beat": beat, "name": chord_name})
                current = chord_name
        return notes, sections, changes, bar

    # ------------------------------------------------------------ output

    @property
    def seconds(self):
        return self.bars * self.bpb * 60 / self.bpm

    def take(self, title):
        """The lesson's last step: the whole song as one play-along."""
        return {"type": "along", "notes": [dict(n) for n in self.notes], "bpm": self.bpm, "beatsPerBar": self.bpb,
                **({"title": T(title)} if title else {})}

    def along(self, *labels, bpm=None, title=None, lead_in=True):
        """A play-along of some of the song's parts (by label, in order), with their lyrics: the verse on its own to
        learn it. The first part's pickup sits in a lead-in bar."""
        parts = []
        for label in labels:
            found = [p for p in self.parts if p.label == label]
            if not found:
                raise ValueError(f"no part named {label!r}")
            parts.append(found[0])
        excerpt = Song(self.instrument, bpm or self.bpm, parts, self.bpb, self.shapes, None, self.max_fret, self.first_fret)
        return excerpt.take(title)

    def meta(self):
        used = []
        for change in self.changes:
            if change["name"] != "N" and change["name"] not in used:
                used.append(change["name"])
        return {"bpm": self.bpm, "beatsPerBar": self.bpb, "bars": self.bars, "sections": self.sections,
                "chords": self.changes, "shapes": [self.shapes[n] for n in used],
                **({"words": T(self.words)} if self.words else {})}

    def minutes(self, practice=5):
        """The lesson's length: the steps that teach the song, then the whole song."""
        return int(round(practice + self.seconds / 60))

    def report(self):
        lyric = sum(1 for n in self.notes if "y" in n)
        return f"{self.bars} bars, {len(self.notes)} notes, {lyric} sung, {self.seconds:.0f} s"


def song(instrument, bpm, parts, beats_per_bar=4, shapes=None, words=None, max_fret=4, first_fret=None):
    """A full arrangement. shapes: {"G": chord spec, ...} for every chord the parts name. words: who wrote the lyrics."""
    return Song(instrument, bpm, parts, beats_per_bar, shapes, words, max_fret, first_fret)


def lyric_text(notes):
    """The lyric lines of some notes, as plain text, for checking by eye."""
    lines, line = [], ""
    for n in notes:
        y = n.get("y")
        if y is None or y == HELD:
            continue
        if n.get("yl") and line:
            lines.append(line)
            line = ""
        joined = y.endswith(HIDDEN_HYPHEN)
        piece = y[:-1] if joined else y
        line += piece + ("" if joined else " ")
    if line:
        lines.append(line)
    return [l.strip() for l in lines]
