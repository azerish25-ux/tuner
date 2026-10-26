"""Ukulele, part 2 (units 7–10): new keys and chords, strum styles, fingerpicking and chord melody, and a campfire-to-
stage set of four songs. courses/ukulele.py appends these UNITS after unit 6.

Shapes, rhythms and shared text come from ukulele.py, so identical sentences translate once; load courses.ukulele (as
build.py does), never this module on its own. Melodies keep G on string 2, fret 3 (`on_two`), like every tune in the
course, and stay in the first four frets.
The strum lane draws down strokes on the beat and up strokes between beats, so every pattern here is one that a hand
swinging down-up plays as drawn. A chunk (a strum the palm stops dead) is a stroke with an attack, so it counts.
The songs are the Standards course's public-domain tunes and words (Down by the Riverside, The Water Is Wide, Molly
Malone, The Skye Boat Song, all checked in docs/content/PUBLIC-DOMAIN-CLEARANCE.md) and the hymn tune of Amazing
Grace from tunes.py, moved into ukulele keys and arranged here with picked chords between the verses.
"""
from lib import TUNINGS, along, chord, explain, fretboard, lesson, listen, name, notes, play_chord, progression, quiz, rhythm, strum, tap, unit
from songbook import Part, song, transpose, transpose_chords
import tunes
from courses.ukulele import (
    A7, C, C7, D, DOWNS, D_DU, E7, EIGHTHS, ISLAND, SHAPES, SOUND_G, THE_CHORUS, THE_VERSE, U, Am, Bb, Dm, Em, F, G, G7,
    on_two,
)
from courses.songs_part3 import (
    DBR_C, DBR_LAST, DBR_V, MOLLY_C, MOLLY_SONG, MOLLY_V, SKYE_C, SKYE_SONG, SKYE_V, WATER_SONG, WATER_V1, dbr_words,
)

# ---------------------------------------------------------------- chord shapes (string 4 first)
D7 = chord(U, "D7", "2223", "1112")      # finger 1 flat across strings 4, 3 and 2
Bm = chord(U, "Bm", "4222", "3111")      # finger 1 flat across strings 3, 2 and 1
Gm = chord(U, "Gm", "0231", "0231")
CHART = {**SHAPES, "D7": D7, "Bm": Bm, "Gm": Gm}

SOUND_D7 = ["A4", "D4", "F#4", "C5"]
SOUND_GM = ["G4", "D4", "G4", "Bb4"]
HOME_HANGING = ["Home", "Hanging"]
HOME_PROMPT = "Does this end at home or leave you hanging?"

# ---------------------------------------------------------------- strum patterns (beats in one bar)
CHUNK = [0, 1, 2, 2.5, 3]                                  # down, chunk, down-up, chunk
CHUNKS = [1, 3]                                            # the chunks (muted strokes) in CHUNK
ISLAND_CHUNK = [1]                                         # the island strum with its down on 2 chunked
SWING = [round(b + o, 3) for b in range(4) for o in (0, 2 / 3)]
ACCENTS = [0, 1.5, 3]                                      # 3 + 3 + 2 eighths
WALTZ_DU = [0, 1, 1.5, 2, 2.5]                             # 3/4: D, DU, DU
BIG_BEATS = [0, 3]                                         # 6/8 counted in eighths


def shape(spec):
    return {"type": "chord", "chord": spec}


def on(spec, string):
    """The note a chord shape sounds on one string, and its finger: ("A4", 2)."""
    fret = spec["frets"][4 - string]
    return name(TUNINGS[U][string - 1] + fret), (spec["fingers"][4 - string] if fret > 0 else 0)


def picked(spec, strings, beats, fingers=True):
    """The shape picked string by string: strings like [4, 3, 2, 1], one length per note (or one for all).
    fingers: mark each fretted note with its finger ("A4@4~2:1"), for a song part."""
    lengths = beats if isinstance(beats, list) else [beats] * len(strings)
    out = []
    for s, length in zip(strings, lengths):
        note, finger = on(spec, s)
        out.append(f"{note}@{s}{f'~{finger}' if fingers and finger else ''}:{length:g}")
    return " ".join(out)


def held(bars, bpm, title, **kw):
    """A play-along over held chords: [(chord shape, melody), …]. Every fretted note must belong to the shape held under
    it, and takes that shape's finger."""
    step = along(U, " ".join(m for _, m in bars), bpm=bpm, title=title, **kw)
    i = 0
    for spec, melody in bars:
        count = sum(1 for t in melody.split() if t.partition(":")[0].lower() != "r")
        for n in step["notes"][i:i + count]:
            at = n["at"]
            if at["f"]:
                j = 4 - at["s"]
                assert spec["frets"][j] == at["f"], f"{spec['name']}: string {at['s']} fret {at['f']} isn't in the shape"
                at["g"] = spec["fingers"][j]
        i += count
    return step


def pattern(spec, strings, beat):
    """A picking pattern for `held`: the shape's notes on these strings, every one `beat` long."""
    return picked(spec, strings, beat, fingers=False)


def moved(part, semitones, label=None, flats=True):
    """A Standards part in a ukulele key: the tune moved (G on string 2), the chart moved, the same words."""
    return Part(label or part.label, part.kind, on_two(transpose(part.melody, semitones)), part.lyrics,
                transpose_chords(part.chords, semitones, flats=flats) if semitones % 12 else part.chords, part.pickup)


def labeled(song_, label):
    return next(p for p in song_.parts if p.label == label)


# ================================================================ 7. New keys

UNIT_7 = unit("uke-7", "New keys", "B flat, D7, B minor and G minor, the keys of G, F and D, and moving a song to any key.", [
    lesson("uke-7-1", "B flat: a small barre", [
        explain("Bb: finger 1 lies flat", "Lay finger 1 across strings 2 and 1 at fret 1. Finger 2 goes on string 3, fret 2, "
                "and finger 3 on string 4, fret 3.", shape(Bb)),
        play_chord(Bb),
        explain("Roll, don't crush", "Tilt finger 1 slightly onto its thumb side. The bonier edge presses two strings "
                "more easily. Check that string 2 rings."),
        strum(Bb, DOWNS, bpm=60, bars=2),
        quiz("Which chord shares finger 1's spot on string 2 with B flat?", ["C", "F", "A minor"], 1,
             "F also puts finger 1 on string 2, fret 1. Keep it there as you change."),
        progression([(F, 2), (Bb, 2), (F, 2), (Bb, 2)], DOWNS, bpm=60),
        progression([(F, 1), (Bb, 1), (C7, 1), (F, 1)], D_DU, bpm=63),
    ], minutes=5, xp=20),
    lesson("uke-7-2", "D7 and the key of G", [
        explain("D7: a barre and one finger", "Lay finger 1 across strings 4, 3 and 2 at fret 2, and put finger 2 on string 1, "
                "fret 3.", shape(D7)),
        play_chord(D7),
        explain("The key of G", "In G, the chords G, C and D7 do most of the work, with E minor for a darker color. "
                "D7 pulls back to G the way G7 pulls to C."),
        listen(HOME_PROMPT, [SOUND_G, SOUND_D7], HOME_HANGING, 1),
        progression([(G, 2), (D7, 2), (G, 2), (D7, 2)], DOWNS, bpm=60),
        progression([(G, 1), (C, 1), (D7, 1), (G, 1)], D_DU, bpm=63),
        progression([(G, 1), (Em, 1), (C, 1), (D7, 1)], ISLAND, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-7-3", "B minor and the key of D", [
        explain("Bm: one flat finger", "Lay finger 1 across strings 3, 2 and 1 at fret 2, then reach finger 3 to string 4, "
                "fret 4.", shape(Bm)),
        play_chord(Bm),
        quiz("D and B minor both press fret 2 on which strings?", ["Strings 4 and 1", "Only string 1", "Strings 3 and 2"], 2,
             "Both chords hold fret 2 on strings 3 and 2. Only the outer strings change."),
        explain("The key of D", "In D, the chords D, G and A7 carry the song, and B minor adds a sad one. A7 is a single "
                "finger: string 3, fret 1.", shape(A7)),
        play_chord(A7),
        progression([(D, 2), (A7, 2), (D, 2), (A7, 2)], DOWNS, bpm=60),
        progression([(D, 1), (Bm, 1), (G, 1), (A7, 1)], D_DU, bpm=63),
    ], minutes=5, xp=25),
    lesson("uke-7-4", "Same numbers, new key", [
        explain("Songs travel by numbers", "A song's chords are steps of its key: I, IV and V. Change key and the numbers "
                "stay. In C that's C, F and G7; in G, it's G, C and D7; in F, F, B flat and C7."),
        progression([(C, 1), (F, 1), (G7, 1), (C, 1)], D_DU, bpm=66),
        progression([(G, 1), (C, 1), (D7, 1), (G, 1)], D_DU, bpm=66),
        quiz("In the key of F, which chord is IV?", ["B flat", "C7", "D minor"], 0,
             "Count up from F: F, G, A, B flat. The fourth note is B flat."),
        progression([(F, 1), (Bb, 1), (C7, 1), (F, 1)], D_DU, bpm=66),
        explain("Pick the singer's key", "If a song sits too high or too low to sing, move it to another key. Same numbers, "
                "same song, just a better fit for the voice."),
        quiz("In the key of D, which chord is V?", ["G", "A7", "B minor"], 1,
             "Count up from D: D, E, F sharp, G, A. A is the fifth note, so A7 is the V chord."),
        progression([(D, 1), (G, 1), (A7, 1), (D, 1)], D_DU, bpm=66),
    ], minutes=5, xp=25),
    lesson("uke-7-5", "G minor and minor keys", [
        explain("Gm: three fingers", "Finger 2 on string 3, fret 2, finger 3 on string 2, fret 3, and finger 1 on string 1, "
                "fret 1. String 4 rings open.", shape(Gm)),
        play_chord(Gm),
        listen("Major or minor?", [SOUND_GM], ["Major, bright", "Minor, dark"], 1),
        explain("The key of D minor", "D minor's family is D minor, G minor and A7. A7 pulls home to D minor, the way E7 "
                "pulls to A minor."),
        progression([(Dm, 2), (Gm, 2), (Dm, 2), (A7, 2)], DOWNS, bpm=60),
        progression([(Dm, 1), (Gm, 1), (A7, 1), (Dm, 1)], D_DU, bpm=63),
        progression([(Am, 1), (Dm, 1), (E7, 1), (Am, 1)], ISLAND, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-7-6", "Challenge: new keys", [
        explain("Four keys, one hand", "No new ideas: B flat, D7, B minor and G minor, and the keys of C, G, F and D. "
                "Clean shapes first, then a steady strum."),
        play_chord(Bb),
        play_chord(Bm),
        quiz("In the key of G, which chord is V?", ["C", "E minor", "D7"], 2),
        progression([(F, 1), (Bb, 1), (C7, 1), (F, 1)], ISLAND, bpm=70),
        progression([(D, 1), (Bm, 1), (G, 1), (A7, 1)], ISLAND, bpm=70),
        progression([(Dm, 1), (Gm, 1), (A7, 1), (Dm, 1)], D_DU, bpm=70),
        progression([(G, 1), (Em, 1), (C, 1), (D7, 1)], ISLAND, bpm=72),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 8. Strum styles

RAGTIME = [(C, 1), (A7, 1), (D7, 1), (G7, 1)]

UNIT_8 = unit("uke-8", "Strum styles", "The chunk, the island strum with a backbeat, swing and the ragtime chords, "
              "accents in 3-3-2, and the waltz.", [
    lesson("uke-8-1", "The chunk", [
        explain("A strum that clicks", "A chunk is a strum that stops dead. Strum down and let the side of your palm land on "
                "the strings at the same moment: a short, dry click, like a snare drum."),
        explain("Down, chunk, down-up, chunk", "Strum down on 1, chunk on 2, down-up on 3, chunk on 4. The chunks fall where "
                "a drummer hits the snare.", rhythm(CHUNK)),
        tap(CHUNK, bpm=66, bars=2),
        strum(C, CHUNK, muted=CHUNKS, bpm=63, bars=2),
        quiz("Where do the chunks land?", ["Beats 2 and 4", "Beats 1 and 3", "Only on 1"], 0,
             "Two and four are the backbeat, where the snare drum plays. A chunk there gives the strum a drummer's punch."),
        strum(F, CHUNK, muted=CHUNKS, bpm=63, bars=2),
        progression([(C, 1), (Am, 1), (F, 1), (G7, 1)], CHUNK, muted=CHUNKS, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-8-2", "Island strum with a chunk", [
        explain("Swap one down for a chunk", "Take the island strum, D, DU, UDU, and turn the down on 2 into a chunk. The "
                "rhythm stays the same; the groove gets a backbeat.", rhythm(ISLAND)),
        tap(ISLAND, bpm=66, bars=2),
        strum(C, ISLAND, muted=ISLAND_CHUNK, bpm=63, bars=2),
        quiz("In this strum, which stroke becomes the chunk?", ["The up after 2", "The down on 2", "The down on 1"], 1,
             "Beat 1 rings out, beat 2 clicks. Everything else stays where the island strum had it."),
        progression([(C, 1), (G, 1), (Am, 1), (F, 1)], ISLAND, muted=ISLAND_CHUNK, bpm=66),
        progression([(G, 1), (Em, 1), (C, 1), (D7, 1)], ISLAND, muted=ISLAND_CHUNK, bpm=72),
        progression([(F, 1), (Bb, 1), (C7, 1), (F, 1)], ISLAND, muted=ISLAND_CHUNK, bpm=76),
    ], minutes=5, xp=20),
    lesson("uke-8-3", "Swing and the ragtime chords", [
        explain("Long-short, long-short", "Swing splits each beat unevenly: a long down, then a short up. Say hum-pty, dum-pty "
                "as you strum. It's the bounce of old ukulele tunes.", rhythm(SWING)),
        tap(SWING, bpm=72, bars=2),
        strum(C, SWING, bpm=66, bars=2),
        explain("The ragtime progression", "C, A7, D7, G7, then home to C. Each seventh chord pulls to the next, a little chain "
                "of tension. It powered countless songs a century ago."),
        quiz("Which chord does D7 pull toward here?", ["C", "A7", "G7"], 2,
             "D7 leads to G, and G7 leads home to C. Each chord sets up the next."),
        progression(RAGTIME, SWING, bpm=66),
        progression(RAGTIME + [(C, 2)], SWING, bpm=72),
    ], minutes=5, xp=25),
    lesson("uke-8-4", "Accents in 3-3-2", [
        explain("Push the and of 2", "Strum steady down-up eighths, but hit three of them harder: 1, the and of 2, and 4. "
                "The accents fall 3, 3 and 2 eighths apart.", rhythm(ACCENTS)),
        tap(ACCENTS, bpm=66, bars=2),
        strum(C, EIGHTHS, accents=ACCENTS, bpm=60, bars=2),
        quiz("Which eighths get the accents?", ["1, the and of 2, and 4", "1 and 3", "Every and"], 0,
             "Count 1 2 3, 1 2 3, 1 2 across the bar's eight eighths. Each 1 is an accent."),
        explain("Where it comes from", "George Formby's split stroke on the banjo ukulele puts its big strums in the same three "
                "places, with single strings in between. Master the accents first."),
        strum(Am, EIGHTHS, accents=ACCENTS, bpm=63, bars=2),
        progression([(C, 1), (Am, 1), (F, 1), (G7, 1)], EIGHTHS, accents=ACCENTS, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-8-5", "Waltz strums", [
        explain("Three beats, down-up", "In three, strum down on 1, then down-up on 2 and on 3: D, DU, DU. Lean on 1 so the "
                "sway is clear.", rhythm(WALTZ_DU, beats_per_bar=3)),
        tap(WALTZ_DU, bpm=72, bars=2, beats_per_bar=3),
        strum(F, WALTZ_DU, bpm=72, bars=2, beats_per_bar=3),
        quiz("How many strums fill this bar of three?", ["Three", "Five", "Six"], 1,
             "Down on 1, then down-up on 2 and on 3: one plus two plus two."),
        progression([(F, 2), (C7, 2), (F, 2), (C7, 1), (F, 1)], WALTZ_DU, bpm=72, beats_per_bar=3),
        progression([(C, 1), (Am, 1), (Dm, 1), (G7, 1)], WALTZ_DU, bpm=76, beats_per_bar=3),
        progression([(G, 2), (D7, 2), (G, 2), (D7, 1), (G, 1)], WALTZ_DU, bpm=80, beats_per_bar=3),
    ], minutes=5, xp=20),
    lesson("uke-8-6", "Challenge: strum styles", [
        explain("Five grooves", "No new ideas: chunks, the island strum with a chunk, swing, the 3-3-2 accents and the "
                "waltz. Keep the hand moving and let the accents speak."),
        tap(SWING, bpm=76, bars=2),
        progression([(C, 1), (Am, 1), (F, 1), (G7, 1)], CHUNK, muted=CHUNKS, bpm=72),
        progression([(C, 1), (G, 1), (Am, 1), (F, 1)], ISLAND, muted=ISLAND_CHUNK, bpm=76),
        quiz("In a swing strum, each beat splits into…", ["Two equal halves", "Short, then long", "Long, then short"], 2),
        progression(RAGTIME + [(C, 2)], SWING, bpm=76),
        progression([(C, 1), (Am, 1), (F, 1), (G7, 1)], EIGHTHS, accents=ACCENTS, bpm=72),
        progression([(F, 2), (C7, 2), (F, 2), (C7, 1), (F, 1)], WALTZ_DU, bpm=84, beats_per_bar=3),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 9. Fingerpicking and chord melody

OUT = [4, 3, 2, 1]                  # thumb, index, middle, ring
ROLL = [4, 3, 2, 1, 2, 3]           # out and back, six eighths in a bar of three
ALTERNATE = [3, 2, 4, 1, 3, 2, 4, 1]   # thumb on 3 and 4 on the beats, fingers on 2 and 1 between
ROLLS = [Am, F, C, G7]
# Amazing Grace ("New Britain", 1829) in F: the tune from tunes.py up a minor seventh, its chart down a whole step.
AG = on_two(transpose(tunes.AMAZING, 10))
AG_LINE_1 = "r:2 " + on_two(transpose(tunes.AMAZING_LINE_1, 10)).replace("C5:5", "C5:6")
AG_CHART = transpose_chords(tunes.AMAZING_CHORDS, 10, flats=True)


def rolled(spec, last=False):
    """One bar of three, out and back; the last bar before a verse holds its fourth note so the pickup has room."""
    if last:
        return picked(spec, [4, 3, 2, 1], [0.5, 0.5, 0.5, 1.5])
    return picked(spec, ROLL, 0.5)


AG_V = Part("Verse 1", "verse", AG, pickup=1, chords=AG_CHART, lyrics=tunes.AMAZING_WORDS_1)
AG_SONG = song(U, 80, [
    Part("Intro", "intro", " ".join([rolled(F), rolled(Bb), rolled(F), rolled(C7, last=True)]), chords="F Bb F C7"),
    AG_V,
    AG_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    Part("Interlude", "interlude", " ".join([rolled(F), rolled(F), rolled(Bb), rolled(F), rolled(F), rolled(C7), rolled(F),
                                             rolled(C7, last=True)]), chords="F F Bb F F C7 F C7"),
    AG_V.with_lyrics("Verse 3", tunes.AMAZING_WORDS_3),
    Part("Outro", "outro", on_two(transpose(tunes.AMAZING_TAIL, 10)), pickup=1,
         chords=transpose_chords(tunes.AMAZING_TAIL_CHORDS, 10, flats=True), lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, shapes=CHART, words=tunes.AMAZING_CREDIT)

UNIT_9 = unit("uke-9", "Fingerpicking and chord melody", "One finger per string, rolling patterns, the alternating thumb, "
              "and a tune picked from inside its chords.", [
    lesson("uke-9-1", "One finger per string", [
        explain("A finger for each string", "Rest your thumb on string 4, index on string 3, middle on string 2 and ring finger "
                "on string 1. Each one plucks only its own string.", fretboard(U, [(4, 0), (3, 0), (2, 0), (1, 0)])),
        notes(U, [("G4", 4), ("C4", 3), ("E4", 2), ("A4", 1)], hint="Thumb, index, middle, ring: strings 4, 3, 2 and 1."),
        quiz("Which finger plucks string 1?", ["The ring finger", "The thumb", "The index finger"], 0,
             "Thumb on 4, index on 3, middle on 2, ring on 1: one finger per string."),
        held([(C, pattern(C, OUT, 1))] * 2, bpm=60, title="C, string 4 to string 1"),
        explain("A zigzag, not a ladder", "Because string 4 is a high G, the pattern zigzags: high, low, then climbing. "
                "That sparkle is the sound of fingerpicked ukulele."),
        held([(spec, pattern(spec, OUT, 1)) for spec in ROLLS], bpm=60, title="A minor, F, C, G7"),
        held([(spec, pattern(spec, OUT + OUT, 0.5)) for spec in ROLLS], bpm=60, title="A minor, F, C, G7, in eighths"),
    ], minutes=5, xp=20),
    lesson("uke-9-2", "Rolling patterns", [
        explain("Out and back", "Pluck strings 4, 3, 2 and 1, then come back on 2 and 3: thumb, index, middle, ring, middle, "
                "index. Six notes fill a bar of three.", rhythm([0, 0.5, 1, 1.5, 2, 2.5], beats_per_bar=3)),
        held([(C, pattern(C, ROLL, 0.5))] * 2, bpm=60, beats_per_bar=3, title="C, out and back"),
        quiz("After the ring finger plucks string 1, which finger comes next?", ["The thumb", "The middle", "The index"], 1,
             "The roll turns around at the top: ring on string 1, then middle on 2 and index on 3."),
        held([(Am, pattern(Am, ROLL, 0.5)), (F, pattern(F, ROLL, 0.5))] * 2, bpm=60, beats_per_bar=3, title="A minor to F"),
        explain("Change on the thumb", "Land the new chord as the thumb starts the next bar. The fingers keep rolling; only "
                "the shape under them changes."),
        held([(spec, pattern(spec, ROLL, 0.5)) for spec in ROLLS], bpm=63, beats_per_bar=3, title="A minor, F, C, G7"),
        held([(spec, pattern(spec, ROLL, 0.5)) for spec in [C, Am, Dm, G7]], bpm=66, beats_per_bar=3, title="C, A minor, D minor, G7"),
    ], minutes=5, xp=25),
    lesson("uke-9-3", "The alternating thumb", [
        explain("Thumb on every beat", "Now the thumb rocks between strings 3 and 4 on the beats while your fingers pluck "
                "strings 2 and 1 in between. It's the ukulele's version of Travis picking.", rhythm(EIGHTHS)),
        held([(C, pattern(C, [3, 4, 3, 4], 1))] * 2, bpm=60, title="C, thumb alone"),
        held([(C, pattern(C, ALTERNATE, 0.5))] * 2, bpm=60, title="C, add the fingers"),
        quiz("In this pattern, what does the thumb do?", ["Plays only on beat 1", "Rests while the fingers play",
                                                          "Rocks between strings 3 and 4"], 2,
             "The thumb keeps the pulse, a note on every beat, while the fingers fill the gaps."),
        held([(G7, pattern(G7, ALTERNATE, 0.5))] * 2, bpm=60, title="G7, the same pattern"),
        held([(C, pattern(C, ALTERNATE, 0.5)), (G7, pattern(G7, ALTERNATE, 0.5))] * 2, bpm=63, title="C to G7"),
        held([(spec, pattern(spec, ALTERNATE, 0.5)) for spec in [C, F, G7, C]], bpm=66, title="C, F, G7, C"),
    ], minutes=5, xp=25),
    lesson("uke-9-4", "Melody inside the chord", [
        explain("Hold the chord, pick the tune", "In chord melody, your fretting hand holds the chord and you pick the tune from "
                "inside it. Hold F, and C, F and A are already under your fingers.", shape(F)),
        notes(U, ["C4", "F4", "A4", "F4", "A4"], hint="Hold F: open string 3, string 2 at fret 1, open string 1. "
              "That's how Amazing Grace begins."),
        explain("Add a free finger", "When the tune leaves the chord, reach with a free finger. Over F, finger 3 takes G on "
                "string 2, fret 3, then lifts as the tune comes back."),
        along(U, AG_LINE_1, bpm=66, beats_per_bar=3, title="Amazing Grace, first half"),
        quiz("Over B flat, where is the tune's D?", ["String 3, fret 2", "String 1, fret 5", "String 4, fret 7"], 0,
             "B flat's finger 2 already holds D on string 3, fret 2. The tune walks right through the chord."),
        along(U, f"r:2 {AG}", bpm=72, beats_per_bar=3, title="Amazing Grace"),
    ], minutes=5, xp=25),
    lesson("uke-9-5", "Amazing Grace, fingerpicked", [
        explain("A whole chord-melody arrangement", "Rolled chords between the verses and the melody inside the chords. The "
                "tune is the hymn New Britain, printed in 1829, with John Newton's words.", shape(Bb)),
        AG_SONG.along("Intro", bpm=66, title="The picked intro"),
        AG_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        quiz("Why does the intro's last bar end on a long note?", ["Because the tune ends there", "To leave room for the pickup",
                                                                   "To change key"], 1,
             "The verse starts a beat early, on its pickup. A long last note keeps that beat clear."),
        AG_SONG.along("Interlude", bpm=72, title="Picked chords"),
        AG_SONG.take("Amazing Grace"),
    ], minutes=AG_SONG.minutes(), xp=35, kind="song", arrangement=AG_SONG.meta()),
    lesson("uke-9-6", "Challenge: fingerpicking", [
        explain("Fingers, thumb and tune", "No new ideas: one finger per string, the out-and-back roll, the alternating thumb "
                "and the melody inside the chord."),
        quiz("Thumb, index, middle, ring play which strings?", ["Strings: 1, 2, 3 and 4", "3, 4, 1 and 2", "4, 3, 2 and 1"], 2),
        held([(spec, pattern(spec, ROLL, 0.5)) for spec in ROLLS], bpm=69, beats_per_bar=3, title="A minor, F, C, G7"),
        held([(C, pattern(C, ALTERNATE, 0.5)), (G7, pattern(G7, ALTERNATE, 0.5))] * 2, bpm=72, title="C to G7"),
        along(U, f"r:2 {AG}", bpm=76, beats_per_bar=3, title="Amazing Grace"),
        AG_SONG.along("Interlude", bpm=80, title="Picked chords"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 10. Campfire to stage

# Down by the Riverside in G, an octave above the Standards melody: G, C and D7, the gospel A sharp on string 1, fret 1.
DBR_U_V = moved(DBR_V, 12)
DBR_U_C = moved(DBR_C, 12)
DBR_U = song(U, 88, [
    Part("Intro", "intro", f"{picked(G, OUT, 1)} {picked(C, OUT, 1)} {picked(D7, OUT, 1)} {picked(G, [4, 3, 2], [1, 1, 2])}",
         chords="G C D7 G"),
    DBR_U_V, DBR_U_C,
    Part("Interlude", "interlude", " ".join(picked(spec, OUT, 1) for spec in [C, G, D7, G, C, G, D7])
         + f" {picked(G, [4, 3, 2], [1, 1, 2])}", chords="C G D7 G C G D7 G"),
    DBR_U_V.with_lyrics("Verse 2", dbr_words("walk with the Prince of Peace")),
    DBR_U_C,
    Part("Outro", "outro", on_two(transpose(f"G3:0.5 A3:0.5 B3:0.5 B3:0.5 {DBR_LAST} G3:4", 12)), pickup=2, chords="D7 G",
         lyrics="I ain't gon-na stud-y war no more. _"),
], shapes=CHART, words="Traditional spiritual (printed 1918)")
DBR_VERSE_CHORDS = [(G, 2), (D7, 1), (G, 3), (D7, 1), (G, 1)]
DBR_CHORUS_CHORDS = [(C, 1), (G, 1), (D7, 1), (G, 1)] * 2

# The Water Is Wide in F (Cecil Sharp, 1906), with picked chords of our own between the verses.
WATER_U_V1 = moved(WATER_V1, 10)
WATER_U_V2 = moved(labeled(WATER_SONG, "Verse 2"), 10)
HOLD_TWO = picked(F, [4, 3], [1, 3])            # a last bar that leaves the verse's two-beat pickup free
WATER_U = song(U, 63, [
    Part("Intro", "intro", f"{picked(F, OUT, 1)} {picked(Bb, OUT, 1)} {picked(C7, OUT, 1)} {HOLD_TWO}", chords="F Bb C7 F"),
    WATER_U_V1,
    Part("Interlude", "interlude", " ".join(picked(spec, OUT, 1) for spec in [F, Bb, F, C7, F, Dm, C7]) + f" {HOLD_TWO}",
         chords="F Bb F C7 F Dm C7 F"),
    WATER_U_V2,
    moved(labeled(WATER_SONG, "Outro"), 10),
], shapes=CHART, words="Traditional (Cecil Sharp, 1906)")
# The verse's chords in two-beat halves (one chord each), as a progression counted in two.
WATER_HALVES = [(F, 1), (Bb, 1), (F, 1), (C, 1), (Bb, 1), (F, 1), (Gm, 1), (C7, 1),
                (F, 1), (Bb, 1), (F, 1), (Dm, 1), (F, 1), (C7, 1), (F, 2)]

# Molly Malone in F, 3/4 (printed 1876; James Yorkston, 1884): three verses, each with its chorus, rolled chords before
# the last verse.
MOLLY_U_V1 = moved(MOLLY_V, 10)
MOLLY_U_C = moved(MOLLY_C, 10)
MOLLY_U = song(U, 120, [
    Part("Intro", "intro", " ".join([rolled(F), rolled(Dm), rolled(Gm), rolled(C7, last=True)]), chords="F Dm Gm C7"),
    MOLLY_U_V1, MOLLY_U_C,
    moved(labeled(MOLLY_SONG, "Verse 2"), 10), MOLLY_U_C,
    Part("Interlude", "interlude", " ".join([rolled(F), rolled(Gm), rolled(C7), rolled(C7, last=True)]), chords="F Gm C7 C7"),
    moved(labeled(MOLLY_SONG, "Verse 3"), 10), MOLLY_U_C,
    moved(labeled(MOLLY_SONG, "Outro"), 10),
], beats_per_bar=3, shapes=CHART, words="Traditional (printed 1876; James Yorkston, 1884)")
MOLLY_CHORDS = [(F, 2), (Gm, 1), (C7, 1), (F, 1), (Dm, 1), (G7, 1), (C7, 1)]

# The Skye Boat Song in F, 6/8 counted in eighths (Harold Boulton, 1884). Picked intro of our own, three notes to each
# big beat; the ending lands on F.
SKYE_U_C = moved(SKYE_C, 10)
SKYE_U = song(U, 144, [
    Part("Intro", "intro", " ".join(picked(spec, [3, 2, 1], 1) for spec in [F, Dm, Gm, C7, F, Dm, C, C7]),
         chords="F,Dm Gm,C7 F,Dm C,C7"),
    SKYE_U_C, moved(SKYE_V, 10), SKYE_U_C,
    moved(labeled(SKYE_SONG, "Verse 2"), 10), SKYE_U_C,
    Part("Outro", "outro", on_two(transpose("B3:1.5 A3:0.5 B3 E3:2 E3 D3:6", 10)), chords="F,Dm F",
         lyrics="o-ver the sea to Skye."),
], beats_per_bar=6, shapes=CHART, words="Sir Harold Boulton (1884)")
# The chorus's chords by big beat (three eighths each).
SKYE_HALVES = [(F, 1), (Dm, 1), (Gm, 1), (C7, 1), (F, 1), (Dm, 1), (C, 1), (C7, 1)] * 2

UNIT_10 = unit("uke-10", "Campfire to stage", "Four public-domain songs arranged for ukulele, and how to lead a room "
               "through them.", [
    lesson("uke-10-1", "Down by the Riverside", [
        explain("A spiritual for a crowd", "Down by the Riverside, first printed in 1918, is made for singing together. On "
                "ukulele it sits in G, with G, C and D7, and a gospel A sharp on string 1, fret 1."),
        notes(U, ["B4", "B4", "A#4", "B4", "A4", ("G4", 2)], hint="Down by the riverside: B, B, A sharp, B, then A and G."),
        DBR_U.along("Verse 1", bpm=72, title=THE_VERSE),
        progression(DBR_VERSE_CHORDS, CHUNK, muted=CHUNKS, bpm=80),
        DBR_U.along("Chorus", bpm=72, title=THE_CHORUS),
        progression(DBR_CHORUS_CHORDS, SWING, bpm=80),
        DBR_U.take("Down by the Riverside"),
    ], minutes=DBR_U.minutes(), xp=35, kind="song", arrangement=DBR_U.meta()),
    lesson("uke-10-2", "The Water Is Wide", [
        explain("A ballad to pick", "Cecil Sharp printed this English ballad in 1906. In F it uses F, B flat, C and C7, "
                "G minor and D minor, often two to a bar. Pick the chords between verses and let them ring."),
        notes(U, ["C4", "F4", "F4", ("G4", 2), "A4"], hint="The water is wide: open string 3, F at fret 1 twice, G at fret 3, "
              "then open A."),
        WATER_U.along("Verse 1", bpm=56, title=THE_VERSE),
        explain("Two chords in a bar", "Many bars here change halfway. Count the verse in two-beat halves, one chord each, "
                "and change on every other click."),
        progression(WATER_HALVES, [0, 1], bpm=63, beats_per_bar=2),
        WATER_U.along("Interlude", bpm=63, title="Picked chords"),
        WATER_U.take("The Water Is Wide"),
    ], minutes=WATER_U.minutes(), xp=35, kind="song", arrangement=WATER_U.meta()),
    lesson("uke-10-3", "Lead the singalong", [
        explain("Count everyone in", "Before the first strum, count out loud at the song's tempo: one, two, three, four. "
                "Everyone starts together, at the speed you set."),
        tap(DOWNS, bpm=88, bars=2),
        explain("Keep going, no matter what", "Miss a chord? Keep strumming and catch the next one. A singing room follows "
                "the beat, not every note."),
        progression(DBR_VERSE_CHORDS, CHUNK, muted=CHUNKS, bpm=88),
        quiz("You fumble a change mid-song. What now?", ["Keep strumming and catch the next chord", "Stop and start over",
                                                          "Slow down until it's fixed"], 0,
             "The beat carries everyone. Drop a chord if you must, never the rhythm."),
        explain("Signal the end", "Before the last line, nod or call out last time. Slow the final line a touch and let the "
                "last chord ring."),
        progression(DBR_CHORUS_CHORDS + [(G, 1)], SWING, bpm=88),
    ], minutes=5, xp=25),
    lesson("uke-10-4", "Molly Malone", [
        explain("Dublin's song, in three", "Molly Malone was printed in 1876. It's a waltz: lean on beat 1 and let the tune "
                "sway. In F it uses F, G minor, C7, D minor and G7."),
        notes(U, ["C4", "F4", "F4", "F4", "F4", "A4", "F4"], hint="In Dublin's fair city: open string 3, F at fret 1 four times, "
              "open A, back to F."),
        MOLLY_U.along("Chorus", bpm=96, title=THE_CHORUS),
        progression(MOLLY_CHORDS, WALTZ_DU, bpm=96, beats_per_bar=3),
        MOLLY_U.along("Verse 1", bpm=104, title=THE_VERSE),
        quiz("Which chord pulls hardest back to F?", ["G minor", "C7", "D minor"], 1,
             "C7 is the V chord in F. Its seventh leans straight back home."),
        MOLLY_U.take("Molly Malone"),
    ], minutes=MOLLY_U.minutes(), xp=35, kind="song", arrangement=MOLLY_U.meta()),
    lesson("uke-10-5", "The Skye Boat Song", [
        explain("Six counts, two sways", "This rowing song is in six-eight: six quick counts to a bar, felt as two big sways. "
                "Count 1 2 3, 4 5 6, and lean on 1 and 4.", rhythm(BIG_BEATS, beats_per_bar=6)),
        tap(BIG_BEATS, bpm=120, bars=2, beats_per_bar=6),
        SKYE_U.along("Chorus", bpm=120, title=THE_CHORUS),
        progression(SKYE_HALVES, [0], bpm=132, beats_per_bar=3),
        SKYE_U.along("Verse 1", bpm=126, title=THE_VERSE),
        quiz("In six-eight, where do the big beats fall?", ["On every count", "On 1, 3 and 5", "On 1 and 4"], 2,
             "Six eighths group in two threes: 1 2 3, 4 5 6. The first of each three carries the sway."),
        SKYE_U.take("The Skye Boat Song"),
    ], minutes=SKYE_U.minutes(), xp=35, kind="song", arrangement=SKYE_U.meta()),
    lesson("uke-10-6", "Challenge: your stage set", [
        explain("Your stage set", "No new ideas: four songs, counted in, kept going and finished clean. Play them back to back "
                "like a short concert."),
        DBR_U.along("Chorus", bpm=88, title="Down by the Riverside"),
        WATER_U.along("Verse 1", bpm=63, title="The Water Is Wide"),
        listen("Which song starts like this?", [["C4"], ["F4"], ["F4"], ["F4"], ["F4"], ["A4"], ["F4"]],
               ["Molly Malone", "The Water Is Wide", "Down by the Riverside"], 0),
        progression(MOLLY_CHORDS, WALTZ_DU, bpm=108, beats_per_bar=3),
        MOLLY_U.along("Chorus", bpm=120, title="Molly Malone"),
        SKYE_U.along("Chorus", bpm=138, title="The Skye Boat Song"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNITS = [UNIT_7, UNIT_8, UNIT_9, UNIT_10]
