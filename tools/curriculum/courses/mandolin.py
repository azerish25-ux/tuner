"""Mandolin: paired strings, the D major scale, tremolo, the bluegrass chop and traditional fiddle tunes.

Fingering: mandolin frets are close together, so first position spans frets 0-7 and each finger covers
two frets (index 1-2, middle 3-4, ring 5-6, little 7-8). lib.position numbers fingers one per fret, so
`play` and `tune` below re-number the suggested finger of every fretted note. Strings and frets are untouched.
"""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, play_chord, progression, quiz, rhythm, staff, strum, tap, unit
from songbook import Part, song
import tunes

M = "mandolin"
FINGER = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4}


def _fingered(step):
    for n in step["notes"]:
        at = n.get("at")
        if at and at["f"] in FINGER:
            at["g"] = FINGER[at["f"]]
    return step


def play(seq, hint=None):
    """Notes at your own pace, first position up to fret 7."""
    return _fingered(notes(M, seq, hint=hint, max_fret=7))


def tune(melody, bpm, beats_per_bar=4, title=None):
    """Play along, first position up to fret 7."""
    return _fingered(along(M, melody, bpm, beats_per_bar=beats_per_bar, title=title, max_fret=7))


def shape(spec):
    return {"type": "chord", "chord": spec}


def eighths(*ns):
    return " ".join(f"{n}:0.5" for n in ns)


# ---------------------------------------------------------------- chord shapes (pair 4, G, first)
G = chord(M, "G", "0023", "0012")
D = chord(M, "D", "2002", "1002")
C = chord(M, "C", "0230", "0120")
Em = chord(M, "Em", "0220", "0120")            # C with the second finger back one fret
A = chord(M, "A", "2245", "1234")              # no open pairs: the first chop shape
C_CHOP = chord(M, "C", "5578", "1234")         # the A shape, three frets up
D_CHOP = chord(M, "D", [7, 7, 9, 10], [1, 2, 3, 4])  # the A shape, five frets up
G_CHOP = chord(M, "G", "7523", "4312")

# ---------------------------------------------------------------- rhythms
QUARTERS = [0, 1, 2, 3]
HALVES = [0, 2]
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
SIXTEENTHS = [i / 4 for i in range(16)]
BACKBEAT = [1, 3]
CHOPS = BACKBEAT                     # every backbeat stroke is a chop: choked at once, no chord rings on
WALTZ = [0, 1, 2]
THREE_THREE_TWO = [0, 1.5, 3]

# ---------------------------------------------------------------- melodies
OPEN_UP = "G3@4:2 D4@3:2 A4@2:2 E5@1:2"
D_UP = "D4:1 E4:1 F#4:1 G4:1 A4:1 B4:1 C#5:1 D5:1"
D_DOWN = "D5:1 C#5:1 B4:1 A4:1 G4:1 F#4:1 E4:1 D4:1"
D_EIGHTHS = eighths("D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5", "D5", "C#5", "B4", "A4", "G4", "F#4", "E4", "D4")

ODE_1 = "F#4:1 F#4:1 G4:1 A4:1 A4:1 G4:1 F#4:1 E4:1 D4:1 D4:1 E4:1 F#4:1 F#4:1.5 E4:0.5 E4:2"
ODE_2 = "F#4:1 F#4:1 G4:1 A4:1 A4:1 G4:1 F#4:1 E4:1 D4:1 D4:1 E4:1 F#4:1 E4:1.5 D4:0.5 D4:2"
ODE = f"{ODE_1} {ODE_2}"

# Amazing Grace ("New Britain", 1835), in 3/4 with a two-beat rest before the pickup.
AMAZING_1 = "r:2 A3:1 D4:2 F#4:0.5 D4:0.5 F#4:2 E4:1 D4:2 B3:1 A3:2"
AMAZING_1_ALONE = AMAZING_1.removesuffix("A3:2") + "A3:3"  # held to the bar line when played on its own
AMAZING_2 = "A3:1 D4:2 F#4:0.5 D4:0.5 F#4:2 E4:1 A4:3"
AMAZING = f"{AMAZING_1} {AMAZING_2}"

# Boil Them Cabbage Down (traditional), in D after the "Bile Them Cabbage Down" setting.
CABBAGE_1 = ("F#5:1 F#5:1 F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 G5:1.5 G5:1.5 A5:0.5 G5:0.5 "
             "F#5:1 F#5:1 F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 E5:1.5 E5:0.5 E5:1 D5:0.5 E5:0.5")
CABBAGE_2 = ("F#5:1 F#5:1 F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 G5:0.5 A5:0.5 G5:0.5 F#5:0.5 G5:1 F#5:0.5 G5:0.5 "
             "A5:1 A5:1 F#5:0.5 D5:0.5 E5:1 D5:0.5 F#5:0.5 E5:0.5 D5:0.5 D5:2")
CABBAGE = f"{CABBAGE_1} {CABBAGE_2}"

# Angeline the Baker (traditional, from Stephen Foster's "Angelina Baker", 1850), simplified.
ANGELINE_LOW_1 = "A4:1 B4:1 D5:1.5 A4:0.5 B4:1 D5:2 B4:1 A4:1 B4:1 D5:0.5 B4:0.5 A4:1 B4:4"
ANGELINE_LOW_2 = "A4:1 B4:1 D5:1.5 E5:0.5 F#5:1 E5:1 D5:2 F#5:1 E5:1 D5:1 B4:1 A4:1.5 B4:0.5 A4:2"
ANGELINE_LOW = f"{ANGELINE_LOW_1} {ANGELINE_LOW_2}"
ANGELINE_HIGH = ("A5:1 G5:1 F#5:1 E5:1 F#5:1 E5:1 D5:1 F#5:1 A5:1 F#5:1 E5:1 D5:1 B4:1.5 D5:0.5 B4:2 "
                 "A5:1 G5:1 F#5:1 E5:1 F#5:1 E5:1 D5:2 F#5:1 E5:1 D5:1 B4:1 A4:4")
ANGELINE = f"{ANGELINE_LOW} {ANGELINE_HIGH}"

# Soldier's Joy (traditional, in print in Scotland by 1780), first part.
SOLDIER_BAR = eighths("A4", "F#4", "D4", "F#4", "A4", "F#4", "D4", "F#4")
SOLDIERS_1 = f"{SOLDIER_BAR} A4:1 D5:1 D5:1 C#5:0.5 B4:0.5 {SOLDIER_BAR} G4:1 E4:1 E4:1 F#4:0.5 G4:0.5"
SOLDIERS_2 = (f"{SOLDIER_BAR} A4:1 D5:1 D5:1 F#5:0.5 G5:0.5 "
              f"{eighths('A5', 'F#5', 'D5', 'F#5', 'G5', 'E5', 'C#5', 'E5')} D5:2 D4:2")
SOLDIERS = f"{SOLDIERS_1} {SOLDIERS_2}"

# Arkansas Traveler (traditional, in print by 1847), after the 1852 Mount manuscript.
TRAVELER_TURN = "D4:0.5 E4:0.5 F#4:0.5 D4:0.5 B3:1 B3:0.5 D4:0.5"
TRAVELER_END = f"{eighths('D5', 'C#5', 'D5', 'A4', 'B4', 'D5', 'A4', 'G4')} F#4:0.5 D4:0.5 E4:0.5 F#4:0.5 D4:2"
TRAVELER_LOW = (f"{TRAVELER_TURN} A3:1 A3:0.5 B3:0.5 D4:1 D4:1 E4:1 E4:1 F#4:1 F#4:1 D4:0.5 E4:0.5 F#4:0.5 D4:0.5 B3:1 D4:1 "
                f"{TRAVELER_TURN} A3:1 A3:0.5 B3:0.5 D4:1 A4:1 {TRAVELER_END}")
TRAVELER_TUMBLE = (f"{eighths('A5', 'G5', 'F#5', 'A5', 'G5', 'F#5', 'E5', 'G5')} "
                   f"{eighths('F#5', 'E5', 'D5', 'F#5', 'E5', 'C#5')} A4:1")
TRAVELER_HIGH_1 = f"{TRAVELER_TUMBLE} D5:0.5 D5:0.5 D5:1 E5:0.5 E5:0.5 E5:1 F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 E5:2"
TRAVELER_HIGH = f"{TRAVELER_HIGH_1} {TRAVELER_TUMBLE} {TRAVELER_END}"
TRAVELER = f"{TRAVELER_LOW} {TRAVELER_HIGH}"

# Old Joe Clark (traditional, reported from East Tennessee in 1905), in A, after the Viola Ruth setting.
OJC_A = ("A4:1 A4:1 E5:0.5 D5:0.5 C#5:1 A4:0.5 C#5:0.5 B4:0.5 G#4:0.5 E4:1.5 E4:0.5 "
         "A4:1 A4:1 E5:0.5 D5:0.5 C#5:1 A4:0.5 C#5:0.5 B4:0.5 E4:0.5 A4:2")
OJC_B = ("E5:1 E5:0.5 F#5:0.5 G5:0.5 F#5:0.5 E5:0.5 D5:0.5 E5:0.5 F#5:0.5 G5:0.5 F#5:0.5 E5:1.5 A4:0.5 "
         "E5:1 E5:0.5 F#5:0.5 G5:0.5 F#5:0.5 E5:0.5 C#5:0.5 A4:0.5 C#5:0.5 B4:0.5 E4:0.5 A4:2")
OJC = f"{OJC_A} {OJC_B}"
# The same first part with a hammer-on and pull-off (A, B, A) in place of the two plain A notes.
OJC_DRESSED_A = ("A4:0.5 B4:0.5 A4:1 E5:0.5 D5:0.5 C#5:1 A4:0.5 C#5:0.5 B4:0.5 G#4:0.5 E4:1.5 E4:0.5 "
                 "A4:0.5 B4:0.5 A4:1 E5:0.5 D5:0.5 C#5:1 A4:0.5 C#5:0.5 B4:0.5 E4:0.5 A4:2")
OJC_DRESSED = f"{OJC_DRESSED_A} {OJC_B}"

# Ornaments: the picked note is short, the note you slide or hammer to is long.
SLIDE_D = "E4:0.5 F#4:1.5 E4:0.5 F#4:1.5 E4:0.5 F#4:1.5 D4:2"
SLIDE_A = "B4:0.5 C#5:1.5 B4:0.5 C#5:1.5 B4:0.5 C#5:1.5 A4:2"
SLIDE_SCALE = "D4:1 E4:0.5 F#4:1.5 G4:1 A4:1 B4:0.5 C#5:1.5 D5:1"
HAMMERS = "A4:0.5 B4:1.5 A4:0.5 B4:1.5 D4:0.5 E4:1.5 D4:0.5 E4:1.5"
PULLS = "B4:0.5 A4:1.5 B4:0.5 A4:1.5 E4:0.5 D4:1.5 E4:0.5 D4:1.5"
HAMMER_PULL = "A4:0.5 B4:0.5 A4:1 D4:0.5 E4:0.5 D4:1 A4:0.5 B4:0.5 A4:0.5 F#4:0.5 D4:2"

# Crosspicking: one note per pair across three pairs, grouped 3 + 3 + 2.
RIPPLE_G = eighths("D4", "B4", "G5", "D4", "B4", "G5", "D4", "B4")
RIPPLE_C = eighths("E4", "C5", "E5", "E4", "C5", "E5", "E4", "C5")
RIPPLE_D = eighths("D4", "A4", "F#5", "D4", "A4", "F#5", "D4", "A4")

# ---------------------------------------------------------------- whole songs (songbook)
# Each song lesson ends on its whole song in first position (frets 0-7). Fiddle tunes take the jam's form: a kick-off
# on the open A pair, each part twice (AABB), once more through, and the "shave and a haircut" tag; slow tunes leave
# long notes for tremolo. Chart shapes are the chords above plus a few the charts need.
SHAPES = {c["name"]: c for c in [G, D, C, Em, A, chord(M, "A7", "2243"), chord(M, "D7", "2032"), chord(M, "E", "1224")]}
THE_VERSE = "The verse"
KICK_A = "A4:0.5 A4:0.5 A4 A4:0.5 A4:0.5 A4 A4:2 r:2"     # two bars on the open A pair to count the band in
SHAVE_D = "D5 A4:0.5 A4:0.5 B4 A4 r C#5 D5:2"             # "shave and a haircut, two bits" (1899), the jam's tag


def mando_song(bpm, parts, beats_per_bar=4, words=None):
    return song(M, bpm, parts, beats_per_bar=beats_per_bar, shapes=SHAPES, words=words, max_fret=7, fingers=FINGER)


# The first song, unit 1 (free): Mary Had a Little Lamb on three notes in D, F sharp, E and D on the D pair (open, fret
# 2 with the first finger, fret 4 with the second): unit 2's D major scale starts here.
MARY_FIRST = tunes.mary3(2)
MARY_FIRST_SONG = mando_song(84, tunes.mary3_parts(2, "D D A D D D A D"), words=tunes.MARY_CREDIT)


def fiddle_tune(bpm, part_a, part_b, chart_a, chart_b, kick=KICK_A, kick_chords="A7 A7", tag=SHAVE_D, tag_chords="D A7,D",
                twice=False):
    """Kick-off, AABB, then AB (or AABB again), and the tag."""
    a = Part("Part A", "verse", part_a, chords=chart_a)
    b = Part("Part B", "chorus", part_b, chords=chart_b)
    body = [a, a, b, b, a, a, b, b] if twice else [a, a, b, b, a, b]
    return mando_song(bpm, [Part("Intro", "intro", kick, chords=kick_chords), *body, Part("Outro", "outro", tag, chords=tag_chords)])


# Ode to Joy, unit 2: D major on pairs 3 and 2. The middle section's low A isn't taught yet, so it ends on the open
# A pair; between the verses, every quarter note picked down-up as two eighths.
M_A1, M_A2, M_B, M_TAIL = tunes.ode(2, low_g="A4")
M_ODE_CHART = tunes.transpose_chords(tunes.ODE_CHORDS, 2)
M_ODE_V = Part("Verse 1", "verse", f"{M_A1} {M_A2} {M_B} {M_A2}", chords=M_ODE_CHART, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = mando_song(76, [
    Part("Intro", "intro", M_TAIL, chords="D A,D"),
    M_ODE_V,
    Part("Variation 1", "solo", tunes.doubled(f"{M_A1} {M_A2}"), chords="D A D A D A D A,D"),
    M_ODE_V.with_lyrics("Verse 2", tunes.ODE_WORDS_2),
    Part("Outro", "outro", M_A2, chords="D A D A,D", lyrics=tunes.ODE_WORDS_END),
], words=tunes.ODE_CREDIT)

# Amazing Grace, unit 3: in D, two of Newton's verses with tremolo on the long notes, then the tune an octave up on
# the E pair.
M_AMAZING = tunes.transpose(tunes.AMAZING, 7)
M_AMAZING_CHART = tunes.transpose_chords(tunes.AMAZING_CHORDS, 7)
M_AMAZING_V = Part("Verse 1", "verse", M_AMAZING, pickup=1, chords=M_AMAZING_CHART, lyrics=tunes.AMAZING_WORDS_1)
AMAZING_SONG = mando_song(66, [
    Part("Intro", "intro", "D4:2 F#4:0.5 D4:0.5 F#4:2 E4 D4:3 D4:3", chords="D D,A7 D D"),
    M_AMAZING_V,
    M_AMAZING_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    Part("Solo", "solo", tunes.transpose(tunes.AMAZING, 19), pickup=1, chords=M_AMAZING_CHART),
    Part("Outro", "outro", tunes.transpose(tunes.AMAZING_TAIL, 7), pickup=1, chords="D D,A7 D", lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, words=tunes.AMAZING_CREDIT)

# Boil Them Cabbage Down, unit 5: up on the E pair, then an octave down on pairs 3 and 2.
CABBAGE_CHART = "D G D A D G D,A D"
CABBAGE_SONG = mando_song(80, [
    Part("Intro", "intro", KICK_A, chords="A7 A7"),
    Part("Part A", "verse", CABBAGE, chords=CABBAGE_CHART),
    Part("Part A", "verse", CABBAGE, chords=CABBAGE_CHART),
    Part("Variation 1", "solo", tunes.transpose(CABBAGE, -12), chords=CABBAGE_CHART),
    Part("Part A", "verse", CABBAGE, chords=CABBAGE_CHART),
    Part("Outro", "outro", SHAVE_D, chords="D A7,D"),
])

# Angeline the Baker, unit 5: both parts end on A, so the tag brings it home to D.
ANGELINE_SONG = fiddle_tune(84, ANGELINE_LOW, ANGELINE_HIGH, "D G D G D D D A", "D D D G D D D A")

# Soldier's Joy, unit 5: the first part as the lesson plays it, and the second part, which climbs to A on the E pair
# and steps down in pairs.
SOLDIERS_B = ("A5 F#5 G5 E5 F#5 D5 D5 F#5:0.5 G5:0.5 A5 F#5 G5 E5 F#5 A4 A4 F#5:0.5 G5:0.5 "
              f"A5 F#5 G5 E5 F#5 D5 D5 F#5:0.5 G5:0.5 {eighths('A5', 'F#5', 'G5', 'E5', 'F#5', 'D5', 'E5', 'C#5')} D5:2 D4:2")
SOLDIERS_SONG = fiddle_tune(76, SOLDIERS, SOLDIERS_B, "D D D A7 D D D,A7 D", "D,A7 D D,A7 D D,A7 D D,A7 D")

# Arkansas Traveler, unit 5: the low part from the G pair, the high part tumbling down the E pair.
TRAVELER_SONG = fiddle_tune(76, TRAVELER_LOW, TRAVELER_HIGH, "D D A7,D D D D D,A7 D", "D D,A7 D,A7 D,A7 D D,A7 D,A7 D")

# Old Joe Clark, unit 5: in A, four bars a part, so AABB twice; the kick-off on E and the tag in A.
OJC_SONG = fiddle_tune(80, OJC_A, OJC_B, "A A,E A A", "A,G A A A",
                       kick="E5:0.5 E5:0.5 E5 E5:0.5 E5:0.5 E5 E5:2 r:2", kick_chords="E E",
                       tag="A5 E5:0.5 E5:0.5 F#5 E5 r G5 A5:2", tag_chords="A G,A", twice=True)

# ================================================================ 1. Hello, mandolin

UNIT_1 = unit("man-1", "Hello, mandolin", "Meet the paired strings, tune them and play all four open notes.", [
    lesson("man-1-1", "Meet your mandolin", [
        explain("Eight strings, four notes", "A mandolin has eight strings in four pairs, called courses. "
                "The two strings of a pair are tuned to the same note and played together, so you treat each pair as one string.",
                part("strings")),
        explain("Counting the pairs", "The pair nearest your face is the lowest, pair 4. The pair nearest the floor is the "
                "highest, pair 1. When a lesson says string 3, it means the third pair.",
                fretboard(M, [(4, 0), (3, 0), (2, 0), (1, 0)])),
        quiz("How do you play a pair?", ["Both strings at once, as one note", "Only the thicker string", "One string, then the other"], 0,
             "The two strings sit close together, so one pick stroke catches both. Together they ring as one fuller note."),
        play([("G3", 4)], hint="Pick the lowest pair, pair 4, and let it ring."),
        play([("E5", 1)], hint="Now the highest pair, pair 1."),
    ], minutes=3, xp=15),
    lesson("man-1-2", "Tune the pairs", [
        explain("Two strings, one pitch", "Each pair has to match the tuner and match itself. If its two strings disagree, "
                "you hear a slow wobble. Tune one string, then bring its partner to the same note.", part("head")),
        play([("D4", 3)], hint="Pair 3, the D pair. Tune both strings until the wobble stops."),
        play([("A4", 2)], hint="Now pair 2, the A pair."),
        quiz("One pair has a slow wobble. What is wrong?", ["Its two strings don't match", "The pick is too thick", "You are pressing too hard"], 0,
             "That wobble is called beating: the two strings are slightly apart. Tune them until it smooths out."),
        explain("Tune up to the note", "Loosen a little below the note, then tighten up to it. "
                "Approaching from below keeps the string from slipping flat later."),
        play([("G3", 4), ("E5", 1)], hint="Pair 4, then pair 1. Bring each string up to the note from below."),
    ], minutes=4, xp=20),
    lesson("man-1-3", "Hold the pick", [
        explain("A relaxed pinch", "Hold the pick between the pad of your thumb and the side of your curled index finger. "
                "Let only the tip show. Keep your wrist loose, as if shaking water off your hand.", clip="mandolin_pick_grip"),
        quiz("How much of the pick should show?", ["Half of it", "Just the tip", "As much as possible"], 1,
             "A short tip gives you control and a clean sound. Too much pick snags on the paired strings."),
        explain("Down through the pair", "Push the pick down through both strings of a pair in one small motion and stop "
                "just past them. Rest the heel of your hand lightly near the bridge.", rhythm(QUARTERS)),
        tap(QUARTERS, bpm=60, bars=2),
        tune("D4@3:1 D4@3:1 D4@3:1 D4@3:1 A4@2:1 A4@2:1 A4@2:1 A4@2:1", bpm=60, title="Four down, four down"),
        tune("G3@4:1 G3@4:1 D4@3:1 D4@3:1 A4@2:1 A4@2:1 E5@1:1 E5@1:1", bpm=64, title="Two on each pair"),
    ], minutes=4, xp=20),
    lesson("man-1-4", "The open strings", [
        explain("G D A E", "From low to high, the pairs are G, D, A and E. Try: Good Dogs Always Eat. "
                "A violin is tuned the same way, so fiddle tunes sit naturally on a mandolin.",
                fretboard(M, [(4, 0), (3, 0), (2, 0), (1, 0)])),
        play([("G3", 4), ("D4", 3), ("A4", 2), ("E5", 1)], hint="Low to high: G, D, A, E."),
        quiz("What is pair 2 called?", ["D", "A", "E", "G"], 1, visual=fretboard(M, [(2, 0)])),
        listen("Which pair sounds lower?", [["E5"], ["G3"]], ["The first", "The second"], 1),
        play([("E5", 1), ("A4", 2), ("D4", 3), ("G3", 4)], hint="Now high to low: E, A, D, G."),
        tune(f"{OPEN_UP} E5@1:2 A4@2:2 D4@3:2 G3@4:2", bpm=66, title="Up and back down"),
    ], minutes=4, xp=20),
    lesson("man-1-5", "Open-string challenge", [
        explain("Show what you know", "Tuned pairs, a relaxed pick and four open notes. "
                "Play each one cleanly, with both strings of the pair ringing."),
        quiz("Which pair is the highest in pitch?", ["Pair 4, G", "Pair 2, A", "Pair 1, E"], 2,
             "Pairs count from the highest, pair 1, to the lowest, pair 4."),
        play([("A4", 2), ("G3", 4), ("E5", 1), ("D4", 3)], hint="A, G, E, D. Find each pair by its name."),
        listen("Same note or different?", [["D4"], ["D4"]], ["Same", "Different"], 0),
        tap(QUARTERS, bpm=72, bars=2),
        tune("G3:1 D4:1 A4:1 E5:1 A4:1 D4:1 G3:2 D4:1 A4:1 E5:2 A4:1 D4:1 G3:2", bpm=70, title="Open-string run"),
    ], minutes=4, xp=30, kind="challenge"),
    lesson("man-1-6", "Mary Had a Little Lamb", [
        explain("Your first song", "Mary Had a Little Lamb lives on the D pair: open D, E at fret 2 with your first "
                "finger, and F sharp at fret 4 with your second.", fretboard(M, [(3, 0), (3, 2, 1), (3, 4, 2)])),
        play([("E4", 3)], hint="Pair 3, fret 2, first finger. That's E."),
        play([("F#4", 3)], hint="Pair 3, fret 4, second finger. That's F sharp."),
        play(["F#4", "E4", "D4", "E4", "F#4", "F#4", "F#4"], hint="F sharp, E, D, E, then F sharp three times."),
        tune(MARY_FIRST[0], bpm=66, title="First half"),
        MARY_FIRST_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
        MARY_FIRST_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_FIRST_SONG.minutes(), xp=30, kind="song", arrangement=MARY_FIRST_SONG.meta()),
])

# ================================================================ 2. First notes

UNIT_2 = unit("man-2", "First notes", "Fret notes cleanly, learn two frets per finger and play the D major scale.", [
    lesson("man-2-1", "Your first fretted notes", [
        explain("Press just behind the fret", "Press both strings of a pair with one fingertip, just behind the metal fret. "
                "Mandolin strings are tight, so use the very tip and press only as hard as a clean note needs.",
                fretboard(M, [(3, 2, 1)])),
        play([("E4", 3)], hint="Pair 3, fret 2, first finger."),
        play([("F#4", 3)], hint="Pair 3, fret 4, second finger."),
        quiz("Where does your fingertip go?", ["Just behind the fret", "On top of the fret", "Halfway between two frets"], 0,
             "Right behind the fret takes the least pressure and gives the cleanest note."),
        play(["D4", "E4", "F#4"], hint="Open, fret 2, fret 4: D, E, F♯."),
        tune("D4:1 E4:1 F#4:2 F#4:1 E4:1 D4:2", bpm=66, title="Up and back"),
    ], minutes=4, xp=20),
    lesson("man-2-2", "One finger, two frets", [
        explain("Small frets, spread fingers", "Mandolin frets are close together, so each finger covers two. "
                "First finger plays frets 1 and 2, second finger 3 and 4, third finger 5 and 6, little finger 7.",
                fretboard(M, [(3, 2, 1), (3, 4, 2), (3, 5, 3), (3, 7, 4)], frets=7)),
        play([("G4", 3)], hint="Pair 3, fret 5, third finger."),
        quiz("Which finger plays fret 4?", ["Fourth finger", "Second finger", "First finger"], 1,
             "Each finger covers two frets on mandolin, so the second finger handles frets 3 and 4."),
        explain("Same shape, next pair", "The A pair works the same way: open is A, fret 2 is B, fret 4 is C♯ and fret 5 is D. "
                "Your hand stays where it is.", fretboard(M, [(2, 0), (2, 2, 1), (2, 4, 2), (2, 5, 3)])),
        play(["A4", "B4", "C#5", "D5"], hint="Open, then first, second and third fingers on pair 2."),
        tune("A4:1 B4:1 C#5:1 D5:1 D5:1 C#5:1 B4:1 A4:1", bpm=66, title="Climb and come back"),
    ], minutes=4, xp=20),
    lesson("man-2-3", "The D major scale", [
        explain("Eight notes, two pairs", "Join the two shapes and you have the D major scale: D, E, F♯, G on pair 3, "
                "then A, B, C♯, D on pair 2. It is home for a great many fiddle tunes.",
                staff(["D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5"])),
        play(["D4", "E4", "F#4", "G4"], hint="Pair 3: open, fret 2, fret 4, fret 5."),
        play(["A4", "B4", "C#5", "D5"], hint="Pair 2: open, fret 2, fret 4, fret 5."),
        quiz("What comes after G in the D major scale?", ["B on fret 2", "A, the open second pair", "G♯ on fret 6"], 1,
             "After G on pair 3 comes A. Play it on the open A pair rather than reaching for fret 7."),
        tune(D_UP, bpm=60, title="D major, up"),
        tune(D_DOWN, bpm=60, title="D major, down"),
    ], minutes=5, xp=25),
    lesson("man-2-4", "Ode to Joy", [
        explain("A tune from the scale", "Beethoven's melody uses only the first five notes of D major, on pairs 3 and 2. "
                "Keep your fingers hovering close to the strings between notes.",
                staff(["F#4", "F#4", "G4", "A4", "A4", "G4", "F#4", "E4"])),
        play(["F#4", "G4", "A4"], hint="F♯ and G on pair 3, then the open A pair."),
        tune(ODE_1, bpm=72, title="First phrase"),
        quiz("Where does the second phrase land?", ["On E", "On A", "On D, the home note"], 2,
             "The first phrase stops on E and sounds unfinished. The second lands on D and sounds like home."),
        tune(ODE_2, bpm=72, title="Second phrase"),
        tune(ODE, bpm=76, title="Ode to Joy"),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=30, kind="song", arrangement=ODE_SONG.meta()),
    lesson("man-2-5", "Up to the E pair", [
        explain("Pair 1, same fingers", "On the E pair, fret 2 is F♯, fret 3 is G and fret 5 is A. "
                "First, second and third fingers, just as before.",
                fretboard(M, [(1, 0), (1, 2, 1), (1, 3, 2), (1, 5, 3)])),
        play(["E5", "F#5", "G5", "A5"], hint="Pair 1: open, fret 2, fret 3, fret 5."),
        quiz("Which finger plays fret 3?", ["First finger", "Third finger", "Second finger"], 2,
             "Fret 3 sits in the second finger's zone, frets 3 and 4."),
        tune("A4:1 B4:1 C#5:1 D5:1 E5:1 F#5:1 G5:1 A5:1", bpm=62, title="A to A over two pairs"),
        listen("Which is higher?", [["A5"], ["A4"]], ["The first", "The second"], 0),
        tune("A5:1 G5:1 F#5:1 E5:1 D5:1 C#5:1 B4:1 A4:1", bpm=62, title="And back down"),
    ], minutes=4, xp=20),
    lesson("man-2-6", "First-notes challenge", [
        explain("Put it together", "Fingers one, two and three on frets 2, 4 and 5, with open pairs in between. "
                "Play smoothly and let each note ring until the next."),
        play(["D4", "F#4", "A4", "D5"], hint="Every other note of the scale: D, F♯, A, D."),
        quiz("You need C♯ on pair 2. Which fret?", ["Fret 2", "Fret 3", "Fret 4"], 2,
             "On pair 2, fret 2 is B, fret 3 is C and fret 4 is C♯."),
        listen("Does the tune go up or down?", [["D5"], ["C#5"], ["B4"], ["A4"]], ["Up", "Down"], 1),
        tune("D4:1 E4:1 F#4:1 G4:1 A4:1 B4:1 C#5:1 D5:1 E5:1 F#5:1 G5:1 A5:1", bpm=66, title="D all the way up to A"),
        tune(ODE, bpm=84, title="Ode to Joy, up to speed"),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 3. Down, up and tremolo

UNIT_3 = unit("man-3", "Down, up and tremolo", "Alternate your pick in eighth notes and make long notes sing with tremolo.", [
    lesson("man-3-1", "Down and up", [
        explain("Down on the beat, up between", "Pick down on each beat and up on the and in between. "
                "Your hand swings like a pendulum, down, up, down, up, even when a note waits.", rhythm(EIGHTHS)),
        tap(EIGHTHS, bpm=60, bars=2),
        quiz("Which stroke lands on the beat?", ["Down", "Up", "Either one"], 0,
             "Down on the beat and up in between keeps your hand in time, like a drummer's sticks."),
        tune(f"{eighths(*['A4'] * 8)} {eighths(*['D4'] * 8)}", bpm=60, title="Eighths on open pairs"),
        tune(eighths("D4", "D4", "E4", "E4", "F#4", "F#4", "G4", "G4", "A4", "A4", "B4", "B4", "C#5", "C#5", "D5", "D5"),
             bpm=60, title="Down-up, up the scale"),
    ], minutes=4, xp=20),
    lesson("man-3-2", "Crossing pairs", [
        explain("Keep the pendulum going", "When you move to another pair, your hand keeps its down-up swing. "
                "The forearm carries you across; the wrist keeps the beat."),
        tap(EIGHTHS, bpm=66, bars=2),
        tune(eighths("D4", "A4", "D4", "A4", "D4", "A4", "D4", "A4", "G3", "D4", "G3", "D4", "G3", "D4", "G3", "D4"),
             bpm=60, title="Rocking between pairs"),
        quiz("You cross to a new pair on an and. Which stroke?", ["Down", "Up", "Whichever is closer"], 1,
             "Every and gets an up stroke. Let the pendulum decide, not the string."),
        tune(D_EIGHTHS, bpm=60, title="D major in eighths"),
    ], minutes=4, xp=20),
    lesson("man-3-3", "Tremolo", [
        explain("Make a note last", "A mandolin note fades quickly. Tremolo keeps it singing: pick down and up fast and "
                "evenly on one pair, so the note sounds unbroken."),
        tune(eighths(*["A4"] * 16), bpm=72, title="Steady eighths on A"),
        tune(" ".join(["A4:0.25"] * 32), bpm=50, title="Sixteenths on A"),
        quiz("What makes a good tremolo?", ["Big, loud strokes", "Only down strokes", "Small, even strokes"], 2,
             "Keep the pick close to the strings and the strokes even. Speed comes later, once the motion is relaxed."),
        explain("Count it, then let go", "Start by counting four strokes to each beat. As it gets easier, stop counting and "
                "keep the motion quick and steady. The beat lives in your foot, not in your pick."),
        tune("D4:2 F#4:2 A4:2 D5:2", bpm=60, title="Tremolo through long notes"),
    ], minutes=5, xp=25),
    lesson("man-3-4", "Amazing Grace", [
        explain("Tremolo on a slow tune", "Amazing Grace moves in three beats to the bar. Tremolo through each long note "
                "and change notes right on the beat. Two notes are new: A and B on the G pair.",
                rhythm(WALTZ, beats_per_bar=3)),
        play(["A3", "B3"], hint="Pair 4, fret 2 with your first finger, then fret 4 with your second."),
        tap(WALTZ, bpm=66, bars=2, beats_per_bar=3),
        tune(AMAZING_1_ALONE, bpm=66, beats_per_bar=3, title="First line"),
        quiz("How do you hold the long A at the end?", ["Pick once and wait", "Tremolo through long notes", "Mute it right away"], 1,
             "A single pick fades long before three beats are up. Tremolo keeps it ringing to the end of the bar."),
        tune(f"r:2 {AMAZING_2}", bpm=66, beats_per_bar=3, title="Second line"),
        tune(AMAZING, bpm=66, beats_per_bar=3, title="Amazing Grace"),
        AMAZING_SONG.along("Verse 1", bpm=60, title=THE_VERSE),
        AMAZING_SONG.take("Amazing Grace"),
    ], minutes=AMAZING_SONG.minutes(), xp=30, kind="song", arrangement=AMAZING_SONG.meta()),
    lesson("man-3-5", "Picking challenge", [
        explain("Steady hand, singing notes", "Down on the beat, up in between, and tremolo whenever a note needs to last. "
                "Keep every stroke small."),
        tap(EIGHTHS, bpm=72, bars=2),
        tune(eighths("D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5", "E5", "F#5", "G5", "A5") + " A5:2",
             bpm=66, title="Eighths up to A"),
        quiz("Which stroke plays the and of beat 2?", ["Up", "Down"], 0, "Every and gets an up stroke, wherever the note is."),
        tune(" ".join(["A4:0.25"] * 16 + ["D5:0.25"] * 16), bpm=56, title="Sixteenths, two notes"),
        tune(AMAZING, bpm=72, beats_per_bar=3, title="Amazing Grace, flowing"),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 4. Chords and the chop

UNIT_4 = unit("man-4", "Chords and the chop", "G, D, C, E minor and A, then the short, choked chord that drives bluegrass.", [
    lesson("man-4-1", "G and D", [
        explain("Your first chord: G", "First finger on fret 2 of pair 2, second finger on fret 3 of pair 1. "
                "Pairs 4 and 3 ring open.", shape(G)),
        play_chord(G),
        explain("Strum down", "Brush the pick down across all four pairs in one smooth motion, low to high. "
                "Small and light is enough; mandolin chords are bright.", rhythm(QUARTERS)),
        strum(G, QUARTERS, bpm=60, bars=2),
        explain("D: two fingers on fret 2", "First finger on fret 2 of pair 4, second finger on fret 2 of pair 1. "
                "Pairs 3 and 2 ring open.", shape(D)),
        play_chord(D),
        progression([(G, 1), (D, 1), (G, 1), (D, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("man-4-2", "C and E minor", [
        explain("C: a small step", "First finger on fret 2 of pair 3, second finger on fret 3 of pair 2. "
                "Pairs 4 and 1 ring open.", shape(C)),
        play_chord(C),
        strum(C, QUARTERS, bpm=60, bars=2),
        explain("E minor: one fret back", "From C, slide your second finger back to fret 2. "
                "The chord turns darker, though only one finger moved.", shape(Em)),
        play_chord(Em),
        listen("Major or minor?", [["G3", "E4", "B4", "E5"]], ["Major, bright", "Minor, darker"], 1),
        progression([(G, 1), (C, 1), (Em, 1), (D, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("man-4-3", "A: four fingers", [
        explain("A with every finger", "Fret 2 on pairs 4 and 3, fret 4 on pair 2, fret 5 on pair 1: fingers one, two, "
                "three and four. No pair rings open.", shape(A)),
        play_chord(A),
        strum(A, QUARTERS, bpm=60, bars=2),
        quiz("Why does it matter that no pair rings open?", ["It makes the chord louder", "You can silence it by easing off",
             "It keeps the chord in tune"], 1,
             "With every pair held down, relaxing your fingers stops the sound at once. That is the secret of the chop."),
        progression([(D, 1), (A, 1), (D, 1), (A, 1)], HALVES, bpm=63),
        progression([(G, 1), (C, 1), (D, 1), (A, 1)], QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("man-4-4", "The chop", [
        explain("Strike, then choke", "The chop is a short chord on beats 2 and 4. Strum down, then ease your fretting "
                "fingers off the strings without lifting them, so the sound stops right away.", rhythm(BACKBEAT)),
        tap(BACKBEAT, bpm=70, bars=2),
        quiz("Which beats get the chop?", ["1 and 3", "2 and 4", "Every beat"], 1,
             "Bass and guitar take beats 1 and 3. The mandolin answers on 2 and 4, like a snare drum."),
        strum(A, BACKBEAT, muted=CHOPS, bpm=66, bars=2),
        explain("Short is the sound", "Let the chord sound for only a moment. If it hangs on, relax your fingers sooner. "
                "Your fingertips stay touching the strings the whole time."),
        strum(A, BACKBEAT, muted=CHOPS, bpm=76, bars=4),
    ], minutes=5, xp=25),
    lesson("man-4-5", "Chops in G, C and D", [
        explain("Move the A shape", "Your A shape works anywhere on the neck. Slide it up three frets for C and five frets "
                "for D. Keep all four fingers in place as you move.", shape(C_CHOP)),
        play_chord(C_CHOP),
        strum(C_CHOP, BACKBEAT, muted=CHOPS, bpm=70, bars=2),
        play_chord(D_CHOP),
        explain("A chop for G", "G needs a new stretch: first finger fret 2 on pair 2, second finger fret 3 on pair 1, "
                "third finger fret 5 on pair 3, little finger fret 7 on pair 4.", shape(G_CHOP)),
        play_chord(G_CHOP),
        progression([(G_CHOP, 2), (C_CHOP, 2), (G_CHOP, 2), (D_CHOP, 2)], BACKBEAT, muted=CHOPS, bpm=70),
    ], minutes=6, xp=25),
    lesson("man-4-6", "Bluegrass backup", [
        explain("Rhythm for the band", "Strum open chords to learn the sound, then chop on 2 and 4 to drive the band. "
                "Keep the beat steady through every change."),
        progression([(G, 1), (C, 1), (D, 1), (G, 1)], QUARTERS, bpm=70),
        listen("Major or minor?", [["A3", "E4", "C#5", "A5"]], ["Major, bright", "Minor, darker"], 0),
        quiz("Your chop keeps ringing. What fixes it?", ["Strum harder", "Lift your fingers off the neck",
             "Ease off with your fretting fingers sooner"], 2,
             "The chop is choked by the fretting hand. Relax the pressure but keep your fingertips on the strings."),
        strum(G_CHOP, BACKBEAT, muted=CHOPS, bpm=80, bars=2),
        progression([(G_CHOP, 1), (C_CHOP, 1), (G_CHOP, 1), (D_CHOP, 1)], BACKBEAT, muted=CHOPS, bpm=80),
        progression([(G_CHOP, 2), (C_CHOP, 2), (D_CHOP, 2), (G_CHOP, 2)], BACKBEAT, muted=CHOPS, bpm=88),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 5. Fiddle tunes

UNIT_5 = unit("man-5", "Fiddle tunes", "Five traditional jam tunes, simplified, from Boil Them Cabbage Down to Old Joe Clark.", [
    lesson("man-5-1", "Boil Them Cabbage Down", [
        explain("A first jam tune", "This one lives on the E and A pairs and keeps coming back to F♯. "
                "Pick down on the beat and up in between, just like your eighth-note drills."),
        play(["F#5", "G5", "A5", "D5"], hint="F♯, G and A on pair 1 at frets 2, 3 and 5, then D on pair 2, fret 5."),
        tune(CABBAGE_1, bpm=70, title="First half"),
        quiz("Where does the tune come to rest?", ["On F♯", "On D", "On A"], 1,
             "Like most tunes in D, it ends on D, the home note."),
        tune(CABBAGE_2, bpm=70, title="Second half"),
        tune(CABBAGE, bpm=76, title="Boil Them Cabbage Down"),
        CABBAGE_SONG.take("Boil Them Cabbage Down"),
    ], minutes=CABBAGE_SONG.minutes(), xp=30, kind="song", arrangement=CABBAGE_SONG.meta()),
    lesson("man-5-2", "Angeline the Baker", [
        explain("Five notes, one sweet tune", "The low part of Angeline the Baker uses only D, E, F♯, A and B. "
                "Both parts end on A instead of D, which sends the tune around again."),
        tune(ANGELINE_LOW_1, bpm=80, title="Low part, first half"),
        tune(ANGELINE_LOW_2, bpm=80, title="Low part, second half"),
        quiz("Which note do both parts end on?", ["D", "B", "A"], 2,
             "Ending on A instead of D leaves the tune hanging, so it rolls straight into the next time through."),
        tune(ANGELINE_LOW, bpm=84, title="Low part"),
        tune(ANGELINE_HIGH, bpm=80, title="High part"),
        tune(ANGELINE, bpm=84, title="Angeline the Baker"),
        ANGELINE_SONG.take("Angeline the Baker"),
    ], minutes=ANGELINE_SONG.minutes(), xp=35, kind="song", arrangement=ANGELINE_SONG.meta()),
    lesson("man-5-3", "Soldier's Joy", [
        explain("A very old favorite", "Soldier's Joy was in print in Scotland by 1780 and has filled American jams ever since. "
                "Its first part bounces between D, F♯ and A."),
        play(["A4", "F#4", "D4", "F#4"], hint="Open A pair, pair 3 fret 4, open D, then fret 4 again."),
        tune(SOLDIERS_1, bpm=70, title="First phrase"),
        quiz("D, F♯ and A together spell which chord?", ["A major chord", "G major chord", "D major chord"], 2,
             "D, F♯ and A are the three notes of D major. Fiddle tunes often trace their chords like this."),
        tune(SOLDIERS_2, bpm=70, title="Second phrase"),
        tune(SOLDIERS, bpm=76, title="Soldier's Joy, first part"),
        SOLDIERS_SONG.along("Part B", bpm=66, title="Second part"),
        SOLDIERS_SONG.take("Soldier's Joy"),
    ], minutes=SOLDIERS_SONG.minutes(), xp=35, kind="song", arrangement=SOLDIERS_SONG.meta()),
    lesson("man-5-4", "Arkansas Traveler", [
        explain("Low part, high part", "Arkansas Traveler starts low, down on the G pair, then jumps up to the E pair "
                "for a part that tumbles down the scale. It was in print by the 1840s."),
        play(["A3", "B3", "D4"], hint="Pair 4, frets 2 and 4, then the open D pair."),
        tune(TRAVELER_LOW, bpm=72, title="Low part"),
        quiz("Where does the high part begin?", ["On the open D pair", "On A, fret 5 of the E pair", "On the open G pair"], 1,
             "It opens on A at fret 5 of pair 1, then walks down through G, F♯ and E."),
        tune(TRAVELER_HIGH_1, bpm=70, title="High part, first half"),
        tune(TRAVELER_HIGH, bpm=72, title="High part"),
        tune(TRAVELER, bpm=76, title="Arkansas Traveler"),
        TRAVELER_SONG.take("Arkansas Traveler"),
    ], minutes=TRAVELER_SONG.minutes(), xp=35, kind="song", arrangement=TRAVELER_SONG.meta()),
    lesson("man-5-5", "Old Joe Clark", [
        explain("A new key and a twist", "Old Joe Clark is in A, so you use C♯ and G♯. In the second part, G♯ drops to "
                "plain G on fret 3 of the E pair. That one note gives the tune its old-time sound."),
        play(["G#4", "A4", "G5"], hint="G♯ on pair 3, fret 6; the open A pair; then G on pair 1, fret 3."),
        tune(OJC_A, bpm=72, title="First part"),
        quiz("Which note gives the second part its old-time sound?", ["C instead of C♯", "G instead of G♯", "A, the home note"], 1,
             "A major uses G♯. Lowering it to G gives the mixolydian sound that runs through old-time and bluegrass music."),
        tune(OJC_B, bpm=72, title="Second part"),
        tune(OJC, bpm=80, title="Old Joe Clark"),
        OJC_SONG.take("Old Joe Clark"),
    ], minutes=OJC_SONG.minutes(), xp=35, kind="song", arrangement=OJC_SONG.meta()),
    lesson("man-5-6", "Jam-session challenge", [
        explain("Call the tunes", "Play each tune through at a steady tempo. If a note slips, keep your picking hand "
                "moving and catch the next beat. That is how real jams work."),
        tune(CABBAGE, bpm=84, title="Boil Them Cabbage Down"),
        tune(ANGELINE_LOW, bpm=88, title="Angeline the Baker, low part"),
        quiz("Which tune swaps G♯ for G?", ["Soldier's Joy", "Angeline the Baker", "Old Joe Clark"], 2,
             "Old Joe Clark is in A but uses G in its second part. That lowered note is its signature."),
        tune(SOLDIERS, bpm=84, title="Soldier's Joy"),
        tune(TRAVELER_HIGH, bpm=80, title="Arkansas Traveler, high part"),
        tune(OJC, bpm=88, title="Old Joe Clark"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 6. Slides, hammer-ons and crosspicking

UNIT_6 = unit("man-6", "Slides, hammers and crosspicking", "Add the left-hand moves and rolling right hand that make a tune sound like bluegrass.", [
    lesson("man-6-1", "Slides", [
        explain("Slide into a note", "Pick a note, then keep pressing as you glide the same finger up to a higher fret. "
                "The new note sounds without a second pick stroke. Light, steady pressure is the trick.",
                fretboard(M, [(3, 2, 1), (3, 4, 1)])),
        tune(SLIDE_D, bpm=60, title="Pair 3, fret 2 to 4"),
        quiz("What sounds the second note in a slide?", ["A second pick stroke", "Lifting the finger quickly",
             "Your finger pressing as it moves"], 2,
             "Only the first note is picked. Keep pressure on the string as you slide, or the note dies on the way."),
        tune(SLIDE_A, bpm=60, title="Pair 2, fret 2 to 4"),
        tune(SLIDE_SCALE, bpm=64, title="Slides up the scale"),
    ], minutes=4, xp=20),
    lesson("man-6-2", "Hammer-ons and pull-offs", [
        explain("Hammer-on", "Pick an open pair, then snap a fingertip down just behind fret 2. "
                "The new note sounds from the tap alone, with no second pick stroke."),
        tune(HAMMERS, bpm=60, title="Open to fret 2"),
        explain("Pull-off", "The reverse: with a finger on fret 2, pick, then pull the finger slightly sideways as you lift. "
                "That flick plucks the open note below."),
        tune(PULLS, bpm=60, title="Fret 2 to open"),
        quiz("Which moves sound a note without the pick?", ["Only hammer-ons", "Hammer-ons, pull-offs and slides",
             "Only tremolo"], 1,
             "All three sound a second note with the fretting hand. The pick plays only the first."),
        tune(HAMMER_PULL, bpm=64, title="Hammer, pull, repeat"),
    ], minutes=5, xp=25),
    lesson("man-6-3", "Dress up a tune", [
        explain("Ornaments in Old Joe Clark", "Fiddle tunes come alive with small ornaments. Here the two plain A notes "
                "that open Old Joe Clark become A, B, A: a hammer-on and a pull-off."),
        tune("A4:0.5 B4:0.5 A4:1 A4:0.5 B4:0.5 A4:1 A4:0.5 B4:0.5 A4:1 E4:2", bpm=60, title="A, B, A"),
        quiz("In A, B, A, how many times do you pick?", ["Once", "Twice", "Three times"], 0,
             "Pick the first A, hammer on to B and pull off back to A. One pick, three notes."),
        tune(OJC_DRESSED_A, bpm=68, title="First part, dressed up"),
        tune(OJC_DRESSED, bpm=76, title="Old Joe Clark, dressed up"),
    ], minutes=5, xp=25),
    lesson("man-6-4", "Crosspicking", [
        explain("Rolling across three pairs", "Crosspicking picks single notes across three pairs in a repeating pattern, "
                "so a chord sounds like a ripple. Eight notes split three, three and two.", rhythm(THREE_THREE_TWO)),
        tap(THREE_THREE_TWO, bpm=66, bars=2),
        tune(f"{RIPPLE_G} {RIPPLE_G}", bpm=60, title="Ripple over G"),
        quiz("How are the eight notes of a crosspicking bar grouped?", ["4 + 4", "2 + 2 + 2 + 2", "3 + 3 + 2"], 2,
             "A three-note pattern repeated across a bar of eight makes the accent shift each time. That is the rolling feel."),
        tune(f"{RIPPLE_C} {RIPPLE_C}", bpm=60, title="Ripple over C"),
        tune(f"{RIPPLE_G} {RIPPLE_C} {RIPPLE_G} {RIPPLE_D}", bpm=64, title="Ripple through G, C and D"),
    ], minutes=5, xp=25),
    lesson("man-6-5", "Bluegrass mandolin challenge", [
        explain("Everything in one session", "Slides, hammer-ons, chops and crosspicking. "
                "Take each one at your own pace, and keep the beat steady above all."),
        tune(SLIDE_SCALE, bpm=70, title="Slides up the scale"),
        tune(HAMMER_PULL, bpm=70, title="Hammer, pull, repeat"),
        progression([(G_CHOP, 1), (C_CHOP, 1), (G_CHOP, 1), (D_CHOP, 1)], BACKBEAT, muted=CHOPS, bpm=84),
        quiz("Which beats does the chop land on?", ["2 and 4", "1 and 3"], 0,
             "Bass and guitar take beats 1 and 3. The mandolin answers on 2 and 4, like a snare drum."),
        tune(f"{RIPPLE_G} {RIPPLE_C} {RIPPLE_G} {RIPPLE_D}", bpm=72, title="Ripple through G, C and D"),
        tune(OJC_DRESSED, bpm=84, title="Old Joe Clark, dressed up"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("mandolin", "Mandolin", "From paired strings to fiddle tunes and the bluegrass chop", "mandolin.standard.8",
                "music.note.list", "violet", [UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6])
