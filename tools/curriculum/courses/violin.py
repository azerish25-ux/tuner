"""Violin: from the first bow stroke to fiddle tunes, with every fingered note checked for intonation.

The violin is fretless: a "fret" is the number of half steps above the open string, and the
fretboard visuals draw it as tape marks. Everything stays in first position, where the fingers
fall a whole step (1), two or three half steps more (low 2 / high 2), a fifth step (3) and a
seventh (4) above the open string.
"""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, quiz, rhythm, staff, tap, unit
from songbook import Part, song
import tunes

V = "violin"
REACH = 7  # first position: fourth finger stops the string seven half steps above open
# Half steps above the open string -> the finger a violinist uses in first position.
# lib numbers fingers one per half step (guitar and cello style), which puts C sharp on
# the A string under finger 3; on violin it's high 2.
FINGER = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4}


def _fingered(step):
    for n in step["notes"]:
        at = n["at"]
        if at["f"]:
            at["g"] = FINGER[at["f"]]
    return step


def play(seq, hint=None):
    """Hold notes in tune at your own pace. seq: notes, or (note, string) to fix the string."""
    return _fingered(notes(V, seq, hint, max_fret=REACH))


def tune(melody, bpm, beats_per_bar=4, title=None):
    """Play along; "|" marks bar lines for readability only."""
    return _fingered(along(V, melody.replace("|", " "), bpm, beats_per_bar, title, max_fret=REACH))


def board(dots):
    return fretboard(V, dots, frets=REACH)


# Shared wording: identical sentences are translated once.
PLUCK = ("Before you use the bow, pluck. Rest your right thumb against the side of the fingerboard "
         "and pull the string with your first finger. Players call this pizzicato.")
BRIDGE = ("The bridge is the thin wooden arch that holds the strings up. String pressure alone keeps it "
          "standing. If it starts to lean, ask a teacher or shop to set it straight.")
BOW_PARTS = ("The wooden stick runs from the frog, where you hold it, to the tip. Horsehair stretches "
             "between them. Tighten the screw until a pencil just fits between hair and stick.")
ROSIN = ("Bare hair slides over the string without a sound. Rub the cake of rosin along the hair a few "
         "times before you play. A light coat is enough.")
FINE_TUNERS = ("The small screws on the tailpiece are fine tuners. Turn one clockwise to raise the pitch, "
               "counterclockwise to lower it. Quarter turns are plenty.")
PEGS = ("If a fine tuner runs out of room, use the peg. Turn it a little while pushing it inward so it "
        "holds. If a string is far off, ask a teacher; pegs can slip.")
TWO_DIRECTIONS = ("A down-bow pulls the bow to the right, from frog to tip. An up-bow pushes it back to the "
                  "left. In music, a down-bow mark looks like a little table and an up-bow like a V.")
CONTACT = ("Play halfway between the bridge and the end of the fingerboard. Keep the bow parallel to the "
           "bridge, like a train on its track.")
CROSSING = ("To cross strings, change levels with your elbow, not your wrist. Arrive at the new level just "
            "before the bow changes direction.")
NO_FRETS = ("Your instrument has no frets, so your ear places every note. Many players stick thin tapes on "
            "the fingerboard as a guide while they learn.")
NUDGE = ("Timbre accepts a note within 30 cents, about a third of a half step. If you're sharp, nudge the "
         "finger toward the scroll. If you're flat, nudge it toward the bridge.")
DOTTED = ("Each line ends long, short, long: a dotted quarter, an eighth and a half note. A dot after a "
          "note adds half its length.")
BEETHOVEN = "Beethoven wrote this tune for his Ninth Symphony in 1824. It moves mostly by step, so your fingers walk."
FOLK_LIGHTLY = "Lightly Row is an old German children's song. It walks up and down the D major scale on the D and A strings."
SAME_LETTER = ["Yes, an octave apart", "No, different notes"]
WHICH = ["The first", "The second"]
STEPS = ["A whole step", "A half step"]
D_MAJOR = ["D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5"]
G_TWO = ["G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"]

# Tunes (public domain or traditional). Bars are 4 beats unless noted.
TWINKLE_1 = "A4 A4 E5 E5 | F#5 F#5 E5:2 | D5 D5 C#5 C#5 | B4 B4 A4:2"
TWINKLE_2 = "E5 E5 D5 D5 | C#5 C#5 B4:2 | E5 E5 D5 D5 | C#5 C#5 B4:2"
LIGHTLY_A = "A4 F#4 F#4:2 | G4 E4 E4:2 | D4 E4 F#4 G4 | A4 A4 A4:2"
LIGHTLY_B = "E4 E4 E4 E4 | E4 F#4 G4:2 | F#4 F#4 F#4 F#4 | F#4 G4 A4:2"
LIGHTLY_END = "A4 F#4 F#4:2 | G4 E4 E4:2 | D4 F#4 A4 A4 | D4:4"
ODE_1 = "F#4 F#4 G4 A4 | A4 G4 F#4 E4 | D4 D4 E4 F#4 | F#4:1.5 E4:0.5 E4:2"
ODE_2 = "F#4 F#4 G4 A4 | A4 G4 F#4 E4 | D4 D4 E4 F#4 | E4:1.5 D4:0.5 D4:2"
ODE_MID = "E4 E4 F#4 D4 | E4 F#4:0.5 G4:0.5 F#4 D4 | E4 F#4:0.5 G4:0.5 F#4 E4 | D4 E4 A3:2"
CABBAGE_1 = "A4 A4:0.5 A4:0.5 A4 A4 | B4 B4:0.5 B4:0.5 B4 B4 | A4 A4:0.5 A4:0.5 A4 F#4 | E4:4"
CABBAGE_2 = "A4 A4:0.5 A4:0.5 A4 A4 | B4 B4:0.5 B4:0.5 B4 B4 | A4 C#5:0.5 C#5:0.5 E5 C#5 | D5:4"
# Minuet in G (Petzold), 3/4.
MINUET_A = "D5 G4:0.5 A4:0.5 B4:0.5 C5:0.5 | D5 G4 G4 | E5 C5:0.5 D5:0.5 E5:0.5 F#5:0.5 | G5 G4 G4"
MINUET_B = "C5 D5:0.5 C5:0.5 B4:0.5 A4:0.5 | B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 | F#4 G4:0.5 A4:0.5 B4:0.5 G4:0.5 | A4:3"
MINUET_C = "C5 D5:0.5 C5:0.5 B4:0.5 A4:0.5 | B4 C5:0.5 B4:0.5 A4:0.5 G4:0.5 | A4 B4:0.5 A4:0.5 G4:0.5 F#4:0.5 | G4:3"
JOE_A1 = "E5 F#5 G5 F#5 | E5 D5 C#5:2 | E5 F#5 G5 F#5 | E5:2 E5 r"
JOE_A2 = "E5 F#5 G5 F#5 | E5 D5 C#5:2 | A4 C#5 B4 G4 | A4:2 A4 r"
JOE_B1 = "A4:1.5 A4:0.5 A4:2 | E5 D5 C#5:2 | A4:1.5 A4:0.5 A4 A4 | G4:2 r:2"
JOE_B2 = "A4:1.5 A4:0.5 A4:2 | E5 D5 C#5:2 | A4 C#5 B4 G4 | A4:2 A4 r"
SOLDIER_ROCK = "A4:0.5 F#4:0.5 D4:0.5 F#4:0.5 A4:0.5 F#4:0.5 D4:0.5 F#4:0.5"
SOLDIER_1 = SOLDIER_ROCK + " | A4 D5 D5 C#5:0.5 B4:0.5 | " + SOLDIER_ROCK + " | G4 E4 E4 F#4:0.5 G4:0.5"
SOLDIER_2 = (SOLDIER_ROCK + " | A4 D5 D5 F#5:0.5 G5:0.5 | "
             "A5:0.5 F#5:0.5 D5:0.5 F#5:0.5 G5:0.5 E5:0.5 C#5:0.5 E5:0.5 | D5 D4:2 r")
# Amazing Grace (New Britain), 3/4, with a two-beat rest before the pickup.
GRACE_1 = "r:2 D4 | G4:2 B4:0.5 G4:0.5 | B4:2 A4 | G4:2 E4 | D4:2 D4 | G4:2 B4:0.5 G4:0.5 | B4:2 A4 | D5:5 B4"
GRACE_2 = "D5:2 B4:0.5 G4:0.5 | B4:2 A4 | G4:2 E4 | D4:2 D4 | G4:2 B4:0.5 G4:0.5 | B4:2 A4 | G4:3"
# Arkansas Traveler, after an 1852 manuscript; one beat here is an eighth note of the 2/4 original.
TRAVELER_OPEN = "D4:0.5 E4:0.5 F#4:0.5 D4:0.5 B3 B3:0.5 D4:0.5"
TRAVELER_1 = (TRAVELER_OPEN + " | A3 A3:0.5 B3:0.5 D4 D4 | E4 E4 F#4 F#4 | D4:0.5 E4:0.5 F#4:0.5 D4:0.5 B3 D4 | "
              + TRAVELER_OPEN + " | A3 A3:0.5 B3:0.5 D4 A4")
TRAVELER_CADENCE = "D5:0.5 C#5:0.5 D5:0.5 A4:0.5 B4:0.5 D5:0.5 A4:0.5 G4:0.5 | F#4:0.5 D4:0.5 E4:0.5 F#4:0.5 D4:2"
TRAVELER_HIGH = ("A5:0.5 G5:0.5 F#5:0.5 A5:0.5 G5:0.5 F#5:0.5 E5:0.5 G5:0.5 | "
                 "F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 E5:0.5 C#5:0.5 A4")
TRAVELER_2 = (TRAVELER_HIGH + " | D5:0.5 D5:0.5 D5 E5:0.5 E5:0.5 E5 | F#5:0.5 E5:0.5 D5:0.5 F#5:0.5 E5:2 | "
              + TRAVELER_HIGH + " | " + TRAVELER_CADENCE)


# ---------------------------------------------------------------- whole songs (songbook)
# Each song lesson ends on its whole song, in first position with the fingers of its unit. Songs with public-domain
# words carry them; fiddle tunes stay instrumental and take the fiddler's form: a kick-off, each part twice (AABB),
# once more through, and the "shave and a haircut" tag. Chart shapes are the chord's notes on the four strings.
SHAPES = {c["name"]: c for c in [
    chord(V, "A", "2240"), chord(V, "D", "x002"), chord(V, "E", "x224"), chord(V, "G", "0023"), chord(V, "C", "5233"),
    chord(V, "A7", "2243"), chord(V, "D7", "x032"), chord(V, "Em", "0220"), chord(V, "Am", "2230"), chord(V, "E7", "x254"),
]}
THE_VERSE = "The verse"


def bars(melody):
    """A melody with its "|" bar marks dropped, for songbook."""
    return " ".join(melody.replace("|", " ").split())


def fiddle_song(bpm, part_a, part_b, chart_a, chart_b, kick_off, kick_chords, tag, tag_chords):
    """A fiddle tune as it's played at a jam: kick-off, AABB, then AB, and a tag."""
    a = Part("Part A", "verse", bars(part_a), chords=chart_a)
    b = Part("Part B", "chorus", bars(part_b), chords=chart_b)
    return song(V, bpm, [Part("Intro", "intro", kick_off, chords=kick_chords), a, a, b, b, a, b,
                         Part("Outro", "outro", tag, chords=tag_chords)], shapes=SHAPES, max_fret=REACH, fingers=FINGER)


SHAVE_D = "D5 A4:0.5 A4:0.5 B4 A4 r C#5 D5:2"          # "shave and a haircut, two bits" (1899), the fiddler's tag
KICK_A = "A4:0.5 A4:0.5 A4 A4:0.5 A4:0.5 A4 A4:2 r:2"  # two bars on the open A to count the band in

# Twinkle, unit 3: A and E strings only. Jane Taylor's verses, the refrain, and a first variation.
V_TW_A, V_TW_B = tunes.transpose(tunes.TWINKLE_A, 9), tunes.transpose(tunes.TWINKLE_B, 9)
V_TW_CA, V_TW_CB = tunes.transpose_chords(tunes.TWINKLE_CHORDS_A, 9), tunes.transpose_chords(tunes.TWINKLE_CHORDS_B, 9)
V_TW_V = Part("Verse 1", "verse", f"{V_TW_A} {V_TW_B}", chords=f"{V_TW_CA} {V_TW_CB}", lyrics=tunes.TWINKLE_WORDS_1)
V_TW_C = Part("Chorus", "chorus", V_TW_A, chords=V_TW_CA, lyrics=tunes.TWINKLE_REFRAIN)
TWINKLE_SONG = song(V, 72, [
    Part("Intro", "intro", "D5 D5 C#5 C#5 B4 B4 A4:2", chords="D,A E,A"),
    V_TW_V, V_TW_C,
    Part("Variation 1", "solo", tunes.doubled(V_TW_A), chords=V_TW_CA),
    V_TW_V.with_lyrics("Verse 2", tunes.TWINKLE_WORDS_2), V_TW_C,
    V_TW_V.with_lyrics("Verse 3", tunes.TWINKLE_WORDS_3), V_TW_C,
    Part("Outro", "outro", "C#5 C#5 B4 B4 A4:4", chords="A,E A"),
], shapes=SHAPES, words=tunes.TWINKLE_CREDIT, max_fret=REACH, fingers=FINGER)

# Lightly Row, unit 4: both verses of the English words, a variation between them.
LIGHTLY_TUNE = bars(" ".join([LIGHTLY_A, LIGHTLY_END, LIGHTLY_B, LIGHTLY_END]))
LIGHTLY_CHART = "D A7 D D D A7 D D A7 A7 D D D A7 D D"
LIGHTLY_V = Part("Verse 1", "verse", LIGHTLY_TUNE, chords=LIGHTLY_CHART, lyrics=tunes.LIGHTLY_WORDS_1)
LIGHTLY_SONG = song(V, 76, [
    Part("Intro", "intro", "D4 F#4 A4 A4 D4:4", chords="D D"),
    LIGHTLY_V,
    Part("Variation 1", "solo", tunes.doubled(bars(f"{LIGHTLY_A} {LIGHTLY_END}")), chords="D A7 D D D A7 D D"),
    LIGHTLY_V.with_lyrics("Verse 2", tunes.LIGHTLY_WORDS_2),
    Part("Outro", "outro", "D4 F#4 A4 A4 D4:4", chords="D D"),
], shapes=SHAPES, words=tunes.LIGHTLY_CREDIT, max_fret=REACH, fingers=FINGER)

# Ode to Joy, unit 4: D major; the middle section dips to A on the G string.
V_A1, V_A2, V_B, V_TAIL = tunes.ode(2)
V_ODE_CHART = tunes.transpose_chords(tunes.ODE_CHORDS, 2)
V_ODE_V = Part("Verse 1", "verse", f"{V_A1} {V_A2} {V_B} {V_A2}", chords=V_ODE_CHART, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = song(V, 76, [
    Part("Intro", "intro", V_TAIL, chords="D A,D"),
    V_ODE_V,
    Part("Variation 1", "solo", tunes.doubled(f"{V_A1} {V_A2}"), chords="D A D A D A D A,D"),
    V_ODE_V.with_lyrics("Verse 2", tunes.ODE_WORDS_2),
    Part("Outro", "outro", V_A2, chords="D A D A,D", lyrics=tunes.ODE_WORDS_END),
], shapes=SHAPES, words=tunes.ODE_CREDIT, max_fret=REACH, fingers=FINGER)

# Boil Them Cabbage Down, unit 4: the eight-bar tune four times, the third as a sawing variation.
CABBAGE_TUNE = bars(f"{CABBAGE_1} {CABBAGE_2}")
CABBAGE_CHART = "D G D A D G A D"
CABBAGE_A = Part("Part A", "verse", CABBAGE_TUNE, chords=CABBAGE_CHART)
CABBAGE_SONG = song(V, 80, [
    Part("Intro", "intro", KICK_A, chords="A A"),
    CABBAGE_A, CABBAGE_A,
    Part("Variation 1", "solo", tunes.doubled(CABBAGE_TUNE), chords=CABBAGE_CHART),
    CABBAGE_A,
    Part("Outro", "outro", SHAVE_D, chords="D A7,D"),
], shapes=SHAPES, max_fret=REACH, fingers=FINGER)

# Minuet in G, unit 5: the A section, Petzold's second half (it opens high, fourth finger on B), and the A section
# again, as dancers would have heard it.
MINUET_PART_B = ("B5 G5:0.5 A5:0.5 B5:0.5 G5:0.5 | A5 D5:0.5 E5:0.5 F#5:0.5 D5:0.5 | G5 E5:0.5 F#5:0.5 G5:0.5 D5:0.5 | "
                 "C#5 B4:0.5 C#5:0.5 A4 | A4:0.5 B4:0.5 C#5:0.5 D5:0.5 E5:0.5 F#5:0.5 | G5 F#5 E5 | F#5 A4 C#5 | D5:3 | "
                 "D5 G4:0.5 F#4:0.5 G4 | E5 G4:0.5 F#4:0.5 G4 | D5 C5 B4 | A4:0.5 G4:0.5 F#4:0.5 G4:0.5 A4 | "
                 "D4:0.5 E4:0.5 F#4:0.5 G4:0.5 A4:0.5 B4:0.5 | C5 B4 A4 | B4:0.5 D5:0.5 G4 F#4 | G4:3")
MINUET_A_PART = Part("Part A", "verse", bars(" ".join([MINUET_A, MINUET_B, MINUET_A, MINUET_C])),
                     chords="G G C G C G D7 D G G C G C G D7 G")
MINUET_SONG = song(V, 72, [
    Part("Intro", "intro", "A4 B4:0.5 A4:0.5 G4:0.5 F#4:0.5 G4:3", chords="D7 G"),
    MINUET_A_PART,
    Part("Part B", "chorus", bars(MINUET_PART_B), chords="G D G A7 D A7 D,A7 D G C G D G Am G,D7 G"),
    MINUET_A_PART,
], beats_per_bar=3, shapes=SHAPES, max_fret=REACH, fingers=FINGER)

# Old Joe Clark, unit 5: in A, with the old-time G natural.
JOE_SONG = fiddle_song(80, f"{JOE_A1} {JOE_A2}", f"{JOE_B1} {JOE_B2}", "A A A E A A A,G A", "A A A G A A A,G A",
                       "E5:0.5 E5:0.5 E5 E5:0.5 E5:0.5 E5 E5:2 r:2", "E E", "A5 E5:0.5 E5:0.5 F#5 E5 r G5 A5:2", "A G,A")

# Soldier's Joy, unit 5: the first part as the lesson plays it, and the second part, which climbs to A on the E string
# and steps down in pairs.
SOLDIER_B = ("A5 F#5 G5 E5 | F#5 D5 D5 F#5:0.5 G5:0.5 | A5 F#5 G5 E5 | F#5 A4 A4 F#5:0.5 G5:0.5 | "
             "A5 F#5 G5 E5 | F#5 D5 D5 F#5:0.5 G5:0.5 | A5:0.5 F#5:0.5 G5:0.5 E5:0.5 F#5:0.5 D5:0.5 E5:0.5 C#5:0.5 | D5 D4:2 r")
SOLDIER_SONG = fiddle_song(72, f"{SOLDIER_1} {SOLDIER_2}", SOLDIER_B, "D D D A7 D D D,A7 D",
                           "D,A7 D D,A7 D D,A7 D D,A7 D", KICK_A, "A7 A7", SHAVE_D, "D A7,D")

# Amazing Grace, unit 6: in G an octave above the guitar's, three of Newton's verses and a solo.
V_AMAZING = tunes.transpose(tunes.AMAZING, 12)
V_AMAZING_V = Part("Verse 1", "verse", V_AMAZING, pickup=1, chords=tunes.AMAZING_CHORDS, lyrics=tunes.AMAZING_WORDS_1)
AMAZING_SONG = song(V, 76, [
    Part("Intro", "intro", "G4:2 B4:0.5 G4:0.5 B4:2 A4 G4:3 G4:3", chords="G G,D7 G G"),
    V_AMAZING_V,
    V_AMAZING_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    V_AMAZING_V.instrumental("Solo"),
    V_AMAZING_V.with_lyrics("Verse 3", tunes.AMAZING_WORDS_3),
    Part("Outro", "outro", tunes.transpose(tunes.AMAZING_TAIL, 12), pickup=1, chords=tunes.AMAZING_TAIL_CHORDS,
         lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, shapes=SHAPES, words=tunes.AMAZING_CREDIT, max_fret=REACH, fingers=FINGER)

# Arkansas Traveler, unit 6: the low part and the high part, slurred pairs and all.
TRAVELER_SONG = fiddle_song(80, f"{TRAVELER_1} {TRAVELER_CADENCE}", TRAVELER_2, "D D A7,D D D D D,A7 D",
                            "D D,A7 D,A7 D,A7 D D,A7 D,A7 D", KICK_A, "A7 A7", SHAVE_D, "D A7,D")


# The first song, unit 1 (free): Mary Had a Little Lamb on three notes in A, C sharp, B and A on the A string (open,
# first finger, second finger another whole step above it), plucked first and then bowed. Unit 3 places the same two fingers.
MARY_FIRST = tunes.mary3(9)
MARY_FIRST_SONG = song(V, 76, tunes.mary3_parts(9, "A A E A A A E A"), shapes=SHAPES, words=tunes.MARY_CREDIT,
                       max_fret=REACH, fingers=FINGER)


UNIT_1 = unit("vln-1", "Hello, violin", "Hold it, bow it, tune it, play the open strings and your first song.", [
    lesson("vln-1-1", "Meet your violin", [
        explain("Four strings, low to high",
                "With the violin under your chin, the strings run G, D, A, E from left to right. G is the thickest "
                "and lowest. E is the thinnest and highest, and we call it string 1.",
                part("strings")),
        explain("The bridge", BRIDGE, part("bridge")),
        quiz("Which string is the highest?", ["E", "G", "D", "A"], 0,
             "E is the thinnest string and the highest. Strings count from E (1) to G (4)."),
        explain("Pluck first", PLUCK),
        play([("A4", 2)], hint="Rest the violin on your lap like a small guitar. Pluck string 2, the A, and let it ring."),
        play([("E5", 1)], hint="Now string 1, the E."),
        play([("G3", 4)], hint="Now the thickest string, the G."),
    ]),
    lesson("vln-1-2", "Hold the violin", [
        explain("Collarbone and chin rest",
                "Set the violin's lower edge on your left collarbone and turn your head to rest your jaw on the chin "
                "rest. The weight of your head holds it. No clamping.", clip="violin_hold"),
        explain("A light left hand",
                "Point the scroll forward and to your left, about level with the floor. Your left hand cradles the "
                "neck, thumb across from your first finger. Keep the wrist straight and soft."),
        quiz("What holds the violin up?",
             ["Your collarbone and the weight of your head", "A tight left-hand grip", "Your shoulder, lifted up"], 0,
             "Let your head rest on the chin rest. A squeezing hand or a raised shoulder makes you tense, and "
             "tension pulls notes out of tune."),
        play([("D4", 3)], hint="Hold the violin in place and pluck the D string, string 3."),
        listen("Which is lower?", [["G3"], ["D4"]], WHICH, 0),
        tune("A4:2 A4:2 D4:2 D4:2 | E5:2 E5:2 G3:4", bpm=60, title="Pluck along"),
    ]),
    lesson("vln-1-3", "Hold the bow", [
        explain("Parts of the bow", BOW_PARTS),
        explain("A soft, round bow hold",
                "Bend your thumb and set its tip where the frog meets the stick. Drape your fingers over the stick, "
                "with your little finger standing curved on top. Keep the whole hand soft.", clip="violin_bow_hold"),
        quiz("Where does your thumb go?",
             ["Bent, where the frog meets the stick", "Straight, under the hair", "Flat on top of the stick"], 0,
             "A bent thumb at the frog lets the hand stay soft and balance the bow."),
        explain("Rosin makes it sing", ROSIN),
        play([("A4", 2)], hint="Set the bow on the A string, halfway between bridge and fingerboard. Pull it slowly to the right."),
        play([("D4", 3)], hint="Now the D string. Lift your elbow a little, then pull slowly."),
        tune("A4:4 A4:4 D4:4 D4:4", bpm=60, title="Long bows"),
    ]),
    lesson("vln-1-4", "The open strings", [
        explain("G D A E",
                "From low to high: G, D, A, E. Each string is five letter names above the last, an interval called "
                "a fifth. Try: Good Dogs Always Eat.",
                board([(4, 0), (3, 0), (2, 0), (1, 0)])),
        explain("One level per string",
                "Your right elbow sets which string the bow plays. Raise it for G, lower it for E. Each string has "
                "its own level, like the steps of a stair."),
        play([("G3", 4), ("D4", 3)], hint="Bow the G string, then D. Your elbow is highest for G."),
        play([("A4", 2), ("E5", 1)], hint="Now A, then E. Lower your elbow one step for each."),
        quiz("Which string needs the highest elbow?", ["G", "D", "A", "E"], 0,
             "The G string sits farthest to the left, so your arm lifts to reach it. E needs the lowest arm."),
        listen("Which is higher?", [["G3"], ["E5"]], WHICH, 1),
        tune("G3:4 D4:4 A4:4 E5:4", bpm=60, title="Open-string roll call"),
    ]),
    lesson("vln-1-5", "Tune your violin", [
        explain("Tune A first",
                "Orchestras tune to A. Timbre shows how far each string is from its note in cents; 100 cents make "
                "a half step, the smallest step on a piano. Tune A, then D, G and E.",
                part("strings")),
        explain("Fine tuners for small moves", FINE_TUNERS, part("bridge")),
        quiz("A string is a little flat. What do you do?",
             ["Turn its fine tuner clockwise", "Turn its fine tuner counterclockwise", "Push on the bridge"], 0,
             "Flat means too low. Clockwise tightens the string and raises the pitch."),
        explain("Pegs for big moves", PEGS, part("head")),
        play([("A4", 2)], hint="Tune your A string, then bow it and hold it steady."),
        play([("D4", 3), ("G3", 4), ("E5", 1)], hint="Now D, G and E. Tune each one, then bow it and hold it."),
    ]),
    lesson("vln-1-6", "Open-string checkup", [
        explain("Check your setup",
                "Violin on your collarbone, soft bow hold, bow halfway between bridge and fingerboard. Now play "
                "everything from this unit."),
        quiz("Which string is string 3?", ["D", "A", "G", "E"], 0, visual=board([(3, 0)])),
        play([("E5", 1), ("A4", 2), ("D4", 3), ("G3", 4)], hint="Bow each open string from high to low. Hold each one steady."),
        listen("Which is lower?", [["A4"], ["D4"]], WHICH, 1),
        quiz("Which string do you tune first?", ["A", "E", "G", "D"], 0,
             "Orchestras tune to A, so start there and tune the others after it."),
        tune("D4:2 D4:2 A4:2 A4:2 | G3:2 G3:2 D4:4 | E5:2 E5:2 A4:2 A4:2 | D4:4", bpm=60, title="Up and down the stairs"),
    ], minutes=5, xp=30, kind="challenge"),
    lesson("vln-1-7", "Mary Had a Little Lamb", [
        explain("Your first song", "Mary Had a Little Lamb lives on the A string: open A, first finger a whole step up for "
                "B, second finger another whole step up for C sharp. Pluck it first, then bow it.",
                board([(2, 0), (2, 2, 1), (2, 4, 2)])),
        play([("B4", 2)], hint="First finger on the A string, a whole step up. That's B."),
        play([("C#5", 2)], hint="Second finger a whole step above your first. That's C sharp."),
        play(["C#5", "B4", "A4", "B4", "C#5", "C#5", "C#5"], hint="C sharp, B, A, B, then C sharp three times."),
        tune(MARY_FIRST[0], bpm=60, title="First half"),
        MARY_FIRST_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        MARY_FIRST_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_FIRST_SONG.minutes(), xp=30, kind="song", arrangement=MARY_FIRST_SONG.meta()),
])

UNIT_2 = unit("vln-2", "Bowing", "Long, even bows, clean string crossings and your first rhythms.", [
    lesson("vln-2-1", "Down-bow, up-bow", [
        explain("Two directions", TWO_DIRECTIONS),
        quiz("Which way does a down-bow move?", ["From frog toward tip", "From tip toward frog", "Toward the bridge"], 0),
        explain("The contact point", CONTACT),
        play([("A4", 2), ("A4", 2)], hint="One slow down-bow, then one slow up-bow on A. Keep the sound even to the end."),
        tune("A4:4 A4:4 A4:4 A4:4", bpm=60, title="Whole bows on A"),
        tune("D4:4 D4:4 E5:4 E5:4 | G3:4 G3:4 A4:4 A4:4", bpm=60, title="Whole bows on every string"),
    ]),
    lesson("vln-2-2", "Quarter notes, half notes", [
        explain("Quarter notes, half bows",
                "A quarter note lasts one beat. Quick notes need less bow, so use the middle half of the bow and "
                "keep every stroke the same length.",
                rhythm([0, 1, 2, 3])),
        tap([0, 1, 2, 3], bpm=70, bars=2),
        tune("A4 A4 A4 A4 | D4 D4 D4 D4 | A4 A4 A4 A4 | D4:4", bpm=70, title="Quarters on A and D"),
        explain("Half notes, slower bows",
                "A half note lasts two beats. Use a longer, slower bow so the sound doesn't fade on the second beat.",
                rhythm([0, 1, 2])),
        tap([0, 1, 2], bpm=70, bars=2),
        quiz("Which note needs more bow?", ["A half note", "A quarter note", "They need the same"], 0,
             "A half note lasts twice as long, so it gets a longer, slower stroke."),
        tune("A4 A4 A4:2 | D4 D4 D4:2 | E5 E5 E5:2 | A4:4", bpm=70, title="Short, short, long"),
    ]),
    lesson("vln-2-3", "String crossings", [
        explain("Move from the elbow", CROSSING),
        play([("A4", 2), ("E5", 1), ("A4", 2), ("E5", 1)], hint="A, E, A, E. Let your elbow rock between the two levels."),
        tune("A4:2 E5:2 A4:2 E5:2 | D4:2 A4:2 D4:2 A4:2", bpm=66, title="Rocking between strings"),
        quiz("What moves the bow to a new string?", ["Your elbow, changing levels", "Your fingers, squeezing", "Tilting the violin"], 0),
        explain("Skipping a string",
                "Going from G to A skips the D string, so your elbow makes a bigger move. Travel smoothly and don't "
                "let the middle string sound."),
        tune("G3:2 D4:2 A4:2 E5:2 | A4:2 D4:2 G3:4 | G3:2 A4:2 D4:2 E5:2 | D4:2 A4:2 G3:4", bpm=60,
             title="All four, up and back"),
    ]),
    lesson("vln-2-4", "Eighth notes", [
        explain("Two notes per beat",
                "An eighth note lasts half a beat, so two fit in each beat. Use small, quick bows near the middle of "
                "the bow.",
                rhythm([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])),
        tap([0, 0.5, 1, 1.5, 2, 3], bpm=66, bars=2),
        tune("A4:0.5 A4:0.5 A4:0.5 A4:0.5 A4 A4 | D4:0.5 D4:0.5 D4:0.5 D4:0.5 D4 D4 | "
             "A4:0.5 A4:0.5 A4:0.5 A4:0.5 A4 A4 | A4:4", bpm=66, title="Quick-quick, slow"),
        quiz("How many eighth notes fit in one beat?", ["Two", "One", "Four"], 0),
        explain("Long, short-short",
                "Now mix them: a quarter, two eighths, then two quarters. Fiddlers lean on this rhythm. Say it "
                "first: long, short-short, long, long.",
                rhythm([0, 1, 1.5, 2, 3])),
        tap([0, 1, 1.5, 2, 3], bpm=66, bars=2),
        tune("A4 A4:0.5 A4:0.5 A4 A4 | E5 E5:0.5 E5:0.5 E5 E5 | D4 D4:0.5 D4:0.5 D4 D4 | A4:4", bpm=66,
             title="Long, short-short"),
    ]),
    lesson("vln-2-5", "Bowing checkup", [
        explain("Bows and rhythms",
                "Straight bows at the contact point, crossings led by the elbow, and steady rhythms. Here's a mix of "
                "all three."),
        tap([0, 1, 1.5, 2, 3], bpm=70, bars=2),
        quiz("Where is the contact point?",
             ["Halfway between bridge and fingerboard", "Right on top of the bridge", "Over the end of the fingerboard"], 0),
        tune("G3:2 D4:2 A4:2 E5:2 | E5 E5 A4 A4 | D4 D4 G3:2", bpm=66, title="Crossings warm-up"),
        quiz("How long does a half note last?", ["Two beats", "One beat", "Half a beat"], 0),
        tune("D4 D4:0.5 D4:0.5 D4 D4 | A4 A4:0.5 A4:0.5 A4 A4 | E5:0.5 E5:0.5 E5:0.5 E5:0.5 A4 A4 | D4:4", bpm=70,
             title="Open-string groove"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_3 = unit("vln-3", "First fingers: A and E", "Place fingers 1, 2 and 3, play the A major scale and your first song.", [
    lesson("vln-3-1", "First finger: B", [
        explain("No frets, only ears", NO_FRETS, board([(2, 2, 1), (2, 4, 2), (2, 5, 3)])),
        explain("First finger on A",
                "Put your first fingertip on the A string at the first tape. That's B, a whole step above A; a whole "
                "step is two half steps. Press until the string meets the fingerboard.",
                board([(2, 0), (2, 2, 1)])),
        play([("A4", 2), ("B4", 2)], hint="Open A, then B with your first finger. Hold B until it settles in tune."),
        explain("Sharp or flat? Move", NUDGE),
        play([("B4", 2), ("A4", 2), ("B4", 2)], hint="B, open A, B. Lift the finger and set it down in the same spot."),
        listen("Open A, then B. How far apart?", [["A4"], ["B4"]], STEPS, 0),
        tune("A4:2 B4:2 A4:2 B4:2 | B4 B4 A4:2 | B4:4", bpm=60, title="A and B"),
    ]),
    lesson("vln-3-2", "Second finger: C sharp", [
        explain("High 2",
                "Second finger plays C sharp, a whole step above B, so leave a gap after first finger. This spot is "
                "called high 2, because it sits close to where third finger will go.",
                board([(2, 2, 1), (2, 4, 2)])),
        play([("A4", 2), ("B4", 2), ("C#5", 2)], hint="A, B, C sharp. Keep first finger down while second plays."),
        listen("From B to the next note: what kind of step?", [["B4"], ["C#5"]], STEPS, 0),
        quiz("How far is C sharp above B?", ["A whole step", "A half step", "Two whole steps"], 0,
             "B to C sharp is two half steps, so second finger leaves a gap after first."),
        play([("B4", 2), ("C#5", 2), ("B4", 2), ("A4", 2)], hint="B, C sharp, B, A. Land each note in tune before you move on."),
        tune("A4 B4 C#5:2 | C#5 B4 A4:2 | A4 B4 C#5 B4 | A4:4", bpm=66, title="Up and back"),
    ]),
    lesson("vln-3-3", "Third finger: D", [
        explain("Third finger touches second",
                "Third finger plays D, a half step above C sharp, so it sits right against second finger. On the A "
                "string the pattern is 1, then 2 and 3 together.",
                board([(2, 2, 1), (2, 4, 2), (2, 5, 3)])),
        play([("A4", 2), ("B4", 2), ("C#5", 2), ("D5", 2)], hint="A, B, C sharp, D. Leave each finger down as you add the next."),
        explain("Listen for the ring",
                "When your D is in tune, the open D string vibrates along with it. The two share a letter name, eight "
                "notes apart: an octave. Listen for the violin sounding fuller."),
        play([("D5", 2), ("D4", 3), ("D5", 2)], hint="Third-finger D, open D, then third-finger D again. Listen for the ring."),
        listen("Same letter name?", [["D4"], ["D5"]], SAME_LETTER, 0),
        quiz("Which fingers touch on the A string?", ["2 and 3", "1 and 2", "3 and 4"], 0,
             "B to C sharp is a whole step, so 1 and 2 have a gap. C sharp to D is a half step, so 2 and 3 touch."),
        tune("A4 B4 C#5 D5 | D5 C#5 B4 A4 | A4:2 D5:2 | A4:4", bpm=66, title="Four-note scale"),
    ]),
    lesson("vln-3-4", "The E string", [
        explain("Same shape, one string over",
                "On the E string, first finger plays F sharp, high second G sharp, and third A. It's the A-string "
                "shape, one string higher. Lower your bow arm to the E level.",
                board([(1, 2, 1), (1, 4, 2), (1, 5, 3)])),
        play([("E5", 1), ("F#5", 1), ("G#5", 1), ("A5", 1)], hint="E, F sharp, G sharp, A. Same shape as on the A string."),
        quiz("Your third finger on E plays A. What can you check it against?",
             ["The open A string", "The open G string", "Nothing; trust your hand"], 0,
             "The open A string is an octave below, so it rings along when your A is in tune."),
        explain("The A major scale",
                "Join the halves: A, B, C sharp, D on the A string, then E, F sharp, G sharp, A on the E string. "
                "Eight notes, A to A, one shape played twice.",
                staff(["A4", "B4", "C#5", "D5", "E5", "F#5", "G#5", "A5"])),
        play(["A4", "B4", "C#5", "D5", "E5", "F#5", "G#5", "A5"], hint="Up the A major scale, slowly. Cross to E for the top four notes."),
        tune("A4 B4 C#5 D5 | E5 F#5 G#5 A5 | A5 G#5 F#5 E5 | D5 C#5 B4 A4", bpm=66, title="A major scale"),
    ]),
    lesson("vln-3-5", "Twinkle, Twinkle, Little Star", [
        explain("A tune you know",
                "This French melody from the 1700s uses only notes you've learned: A, B, C sharp, D on the A "
                "string, and E and F sharp on the E string.",
                staff(["A4", "A4", "E5", "E5", "F#5", "F#5", "E5"])),
        tune(TWINKLE_1, bpm=66, title="Opening line"),
        tune(TWINKLE_2, bpm=66, title="Middle line"),
        listen("Which line is this?", [["E5"], ["E5"], ["D5"], ["D5"], ["C#5"], ["C#5"], ["B4"]],
               ["The middle line", "The opening line"], 0),
        quiz("Which finger plays F sharp on the E string?", ["First", "Second", "Third"], 0),
        tune(" ".join([TWINKLE_1, TWINKLE_2, TWINKLE_1]), bpm=72, title="Twinkle, Twinkle, Little Star"),
        TWINKLE_SONG.take("Twinkle, Twinkle, Little Star"),
    ], minutes=TWINKLE_SONG.minutes(), xp=30, kind="song", arrangement=TWINKLE_SONG.meta()),
    lesson("vln-3-6", "A and E checkup", [
        explain("Fingers 1, 2, 3",
                "Whole step, whole step, half step: that's the pattern on A and E. Land each note in tune and let "
                "the open strings ring with you."),
        listen("Second finger to third: what kind of step?", [["C#5"], ["D5"]], ["A half step", "A whole step"], 0),
        play([("B4", 2), ("C#5", 2), ("D5", 2), ("D4", 3)], hint="B, C sharp, D, then open D. Listen for the ring."),
        quiz("Which note does high 2 play on the E string?", ["G sharp", "G", "F sharp"], 0),
        play([("F#5", 1), ("G#5", 1), ("A5", 1), ("A4", 2)], hint="F sharp, G sharp, A on the E string, then open A an octave lower."),
        tune("A5 G#5 F#5 E5 | D5 C#5 B4 A4 | A4 B4 C#5 D5 | E5:4", bpm=72, title="Scale down and up"),
        tune(TWINKLE_1, bpm=80, title="Twinkle, a little faster"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_4 = unit("vln-4", "D and G strings", "The same finger pattern on two lower strings, D major and three tunes.", [
    lesson("vln-4-1", "The D string", [
        explain("Same shape, lower string",
                "On the D string, first finger plays E, high second F sharp, and third G. It's the A-string pattern, "
                "one string lower. Raise your bow arm a step.",
                board([(3, 2, 1), (3, 4, 2), (3, 5, 3)])),
        play([("D4", 3), ("E4", 3), ("F#4", 3), ("G4", 3)], hint="D, E, F sharp, G. Second and third fingers touch."),
        explain("G rings with G",
                "Third-finger G on the D string is an octave above the open G string. When it's in tune, the G "
                "string hums along."),
        play([("G4", 3), ("G3", 4), ("G4", 3)], hint="Third-finger G, open G, third-finger G. Listen for the ring."),
        quiz("On the D string, which fingers touch?", ["2 and 3", "1 and 2", "None of them"], 0,
             "It's the A-string pattern again: whole step, whole step, half step. The half step is between 2 and 3."),
        tune("D4 E4 F#4 G4 | G4 F#4 E4 D4 | D4:2 G4:2 | D4:4", bpm=66, title="D string scale"),
    ]),
    lesson("vln-4-2", "The D major scale", [
        explain("D to D",
                "Play D, E, F sharp, G on the D string, then A, B, C sharp, D on the A string. The D major scale is "
                "one finger shape played twice.",
                staff(D_MAJOR)),
        play(D_MAJOR, hint="Up the D major scale. Cross to the A string on the fifth note."),
        listen("Up or down?", [["D5"], ["C#5"], ["B4"], ["A4"]], ["Going up", "Going down"], 1),
        quiz("Which notes are sharp in D major?", ["F and C", "F only", "C and G"], 0,
             "D major has two sharps, F sharp and C sharp. Both are high 2."),
        tune("D4 E4 F#4 G4 | A4 B4 C#5 D5 | D5 C#5 B4 A4 | G4 F#4 E4 D4", bpm=66, title="D major scale"),
        tune("D4 D4:0.5 D4:0.5 E4 E4:0.5 E4:0.5 | F#4 F#4:0.5 F#4:0.5 G4 G4:0.5 G4:0.5 | "
             "A4 A4:0.5 A4:0.5 B4 B4:0.5 B4:0.5 | C#5 C#5:0.5 C#5:0.5 D5:2", bpm=60, title="Scale in long, short-short"),
    ]),
    lesson("vln-4-3", "Lightly Row", [
        explain("A German folk song", FOLK_LIGHTLY, staff(["A4", "F#4", "F#4", "G4", "E4", "E4"])),
        tune(LIGHTLY_A + " " + LIGHTLY_END, bpm=66, title="First part"),
        quiz("Which finger plays the F sharps?", ["High 2 on the D string", "First finger on the A string", "Third finger on the D string"], 0),
        tune(LIGHTLY_B + " " + LIGHTLY_END, bpm=66, title="Second part"),
        tune(" ".join([LIGHTLY_A, LIGHTLY_END, LIGHTLY_B, LIGHTLY_END]), bpm=76, title="Lightly Row"),
        LIGHTLY_SONG.take("Lightly Row"),
    ], minutes=LIGHTLY_SONG.minutes(), xp=30, kind="song", arrangement=LIGHTLY_SONG.meta()),
    lesson("vln-4-4", "The G string", [
        explain("The lowest string",
                "On the G string, first finger plays A, high second B, and third C. Same shape again. Raise your "
                "bow arm to its highest level.",
                board([(4, 2, 1), (4, 4, 2), (4, 5, 3)])),
        play([("G3", 4), ("A3", 4), ("B3", 4), ("C4", 4)], hint="G, A, B, C. Swing your left elbow a little under the violin to reach."),
        play([("A3", 4), ("A4", 2)], hint="First-finger A on the G string, then the open A string. Same letter, an octave apart."),
        explain("Half of a long scale",
                "G, A, B, C on the G string plus D, E, F sharp, G on the D string make G major. It's the first "
                "octave of a two-octave scale you'll finish in the next unit.",
                staff(G_TWO[:8])),
        play(G_TWO[:8], hint="Up the G major scale. Same shape on both strings."),
        listen("Same letter name?", [["G3"], ["G4"]], SAME_LETTER, 0),
        tune("G3 A3 B3 C4 | D4 E4 F#4 G4 | G4 F#4 E4 D4 | C4 B3 A3 G3", bpm=66, title="G major, first octave"),
    ]),
    lesson("vln-4-5", "Ode to Joy", [
        explain("Beethoven's melody", BEETHOVEN, staff(["F#4", "F#4", "G4", "A4", "A4", "G4", "F#4", "E4"])),
        tune(ODE_1, bpm=66, title="First line"),
        explain("Long, short, long", DOTTED, rhythm([0, 1.5, 2])),
        tap([0, 1.5, 2], bpm=66, bars=2),
        tune(ODE_2, bpm=66, title="Second line"),
        tune(ODE_1 + " " + ODE_2, bpm=76, title="Ode to Joy"),
        ODE_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=30, kind="song", arrangement=ODE_SONG.meta()),
    lesson("vln-4-6", "Boil Them Cabbage Down", [
        explain("Your first fiddle tune",
                "This old American fiddle tune rides the rhythm you bowed on open strings: long, short-short, long, "
                "long. Fiddlers play it at jams everywhere.",
                rhythm([0, 1, 1.5, 2, 3])),
        tap([0, 1, 1.5, 2, 3], bpm=70, bars=2),
        tune(CABBAGE_1, bpm=70, title="First half"),
        tune(CABBAGE_2, bpm=70, title="Second half"),
        quiz("Which string does this tune never use?", ["G", "D", "A", "E"], 0, "It lives on the D, A and E strings."),
        tune(" ".join([CABBAGE_1, CABBAGE_2, CABBAGE_1, CABBAGE_2]), bpm=80, title="Boil Them Cabbage Down"),
        CABBAGE_SONG.take("Boil Them Cabbage Down"),
    ], minutes=CABBAGE_SONG.minutes(), xp=30, kind="song", arrangement=CABBAGE_SONG.meta()),
    lesson("vln-4-7", "D and G checkup", [
        explain("Four strings, one shape",
                "Whole step, whole step, half step works on every string so far. Raise your bow arm for the low "
                "strings and let the octaves ring."),
        play([("G4", 3), ("G3", 4), ("A3", 4), ("A4", 2)], hint="Two octave checks: G with open G, then A with open A."),
        quiz("In D major, which finger plays C sharp?", ["High 2 on the A string", "Third on the A string", "First on the A string"], 0),
        listen("Up or down?", [["G3"], ["A3"], ["B3"], ["C4"]], ["Going up", "Going down"], 0),
        tune("D4 E4 F#4 G4 | A4 B4 C#5 D5 | D5 C#5 B4 A4 | G4 F#4 E4 D4", bpm=76, title="D major scale"),
        tune(LIGHTLY_B + " " + LIGHTLY_END, bpm=80, title="Lightly Row, second part"),
        tune(CABBAGE_2, bpm=84, title="Cabbage, up to speed"),
    ], minutes=6, xp=35, kind="challenge"),
])

UNIT_5 = unit("vln-5", "Low 2 and high 2", "Move second finger to change keys: G major in two octaves, A minor and fiddle tunes.", [
    lesson("vln-5-1", "Low 2", [
        explain("Second finger slides back",
                "Slide second finger back until it touches first. On the A string that's C natural, a half step "
                "below C sharp. Players call it low 2.",
                board([(2, 2, 1), (2, 3, 2), (2, 5, 3)])),
        play([("A4", 2), ("B4", 2), ("C5", 2), ("D5", 2)], hint="A, B, C, D. Second finger touches first; leave a gap before third."),
        listen("B, then high 2 or low 2?", [["B4"], ["C#5"]], ["High 2, C sharp", "Low 2, C natural"], 0),
        listen("And this one?", [["B4"], ["C5"]], ["High 2, C sharp", "Low 2, C natural"], 1),
        play([("C#5", 2), ("C5", 2), ("C#5", 2), ("C5", 2)], hint="High 2, low 2, high 2, low 2. Move only your second finger."),
        tune("A4 B4 C5 D5 | D5 C5 B4 A4 | A4 B4 C#5 D5 | D5 C#5 B4 A4", bpm=66, title="Low 2, then high 2"),
    ]),
    lesson("vln-5-2", "G major, two octaves", [
        explain("Low 2 up high",
                "G major needs C natural on the A string and G natural on the E string, so second finger sits low "
                "there. On the G and D strings it stays high.",
                board([(4, 4, 2), (3, 4, 2), (2, 3, 2), (1, 3, 2)])),
        play([("A4", 2), ("B4", 2), ("C5", 2), ("D5", 2)], hint="The A string in G major: second finger low, touching first."),
        play([("E5", 1), ("F#5", 1), ("G5", 1)], hint="Now E, F sharp, G on the E string. Low 2 again."),
        quiz("Where does second finger go on the E string in G major?", ["Low, touching first", "High, touching third", "It isn't used"], 0,
             "G natural is a half step above F sharp, so second finger tucks right against first."),
        explain("All four strings",
                "Start on open G and climb to G on the E string: fifteen notes, two octaves. High 2 on the low "
                "strings, low 2 on the high ones.",
                staff(G_TWO)),
        tune("G3 A3 B3 C4 | D4 E4 F#4 G4 | A4 B4 C5 D5 | E5 F#5 G5:2 | F#5 E5 D5 C5 | B4 A4 G4 F#4 | E4 D4 C4 B3 | A3 G3:3",
             bpm=66, title="G major, two octaves"),
    ]),
    lesson("vln-5-3", "A minor", [
        explain("A darker scale",
                "A minor starts with first-finger A on the G string. Second finger is high on the G string for B, "
                "then low on the D string for F natural.",
                board([(4, 2, 1), (4, 4, 2), (4, 5, 3), (3, 2, 1), (3, 3, 2), (3, 5, 3)])),
        play(["A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4"], hint="A minor, up. High 2 on the G string, low 2 on the D string."),
        listen("Major or minor?", [["A4"], ["B4"], ["C#5"], ["D5"], ["E5"]], ["Major", "Minor"], 0),
        listen("And this one?", [["A4"], ["B4"], ["C5"], ["D5"], ["E5"]], ["Major", "Minor"], 1),
        quiz("What makes this scale minor?", ["Its third note is a half step lower", "It starts on a lower string", "It's played slower"], 0,
             "A to C sounds dark; A to C sharp sounds bright. One half step changes the whole mood."),
        tune("A3 B3 C4 D4 | E4 F4 G4 A4 | A4 G4 F4 E4 | D4 C4 B3 A3", bpm=66, title="A minor scale"),
    ]),
    lesson("vln-5-4", "Minuet in G", [
        explain("A dance in three",
                "This minuet comes from the notebook Bach gave his wife Anna Magdalena in 1725. It's now credited "
                "to Christian Petzold. Count three beats to a bar.",
                rhythm([0, 1, 1.5, 2, 2.5], beats_per_bar=3)),
        tap([0, 1, 1.5, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
        tune(MINUET_A, bpm=66, beats_per_bar=3, title="Bars 1 to 4"),
        quiz("Which C does the minuet use?", ["C natural, low 2", "C sharp, high 2"], 0,
             "The minuet is in G major, so C is natural and second finger sits low on the A string."),
        tune(MINUET_B, bpm=66, beats_per_bar=3, title="Bars 5 to 8"),
        play([("F#4", 3), ("G4", 3), ("F#4", 3)], hint="F sharp is high 2 on the D string: low on A, high on D."),
        tune(" ".join([MINUET_A, MINUET_B, MINUET_A, MINUET_C]), bpm=72, beats_per_bar=3, title="Minuet in G"),
        play([("B5", 1), ("A5", 1), ("G5", 1)], hint="The second half starts high: fourth finger reaches B on the E string. Then third, then low 2."),
        MINUET_SONG.take("Minuet in G"),
    ], minutes=MINUET_SONG.minutes(), xp=35, kind="song", arrangement=MINUET_SONG.meta()),
    lesson("vln-5-5", "Old Joe Clark", [
        explain("High 2 and low 2 together",
                "Old Joe Clark is an Appalachian fiddle tune. It's in A but uses G natural: high 2 for C sharp on "
                "the A string, low 2 for G on the E string."),
        play([("E5", 1), ("F#5", 1), ("G5", 1), ("F#5", 1)], hint="E, F sharp, G, F sharp. Keep second finger low, touching first."),
        tune(JOE_A1 + " " + JOE_A2, bpm=70, title="First part"),
        quiz("Which G does this tune use on the E string?", ["G natural, low 2", "G sharp, high 2"], 0,
             "G natural instead of G sharp gives Old Joe Clark its old-time sound."),
        tune(JOE_B1 + " " + JOE_B2, bpm=70, title="Second part"),
        tune(" ".join([JOE_A1, JOE_A2, JOE_B1, JOE_B2]), bpm=80, title="Old Joe Clark"),
        JOE_SONG.take("Old Joe Clark"),
    ], minutes=JOE_SONG.minutes(), xp=30, kind="song", arrangement=JOE_SONG.meta()),
    lesson("vln-5-6", "Soldier's Joy", [
        explain("A tune from the 1700s",
                "Soldier's Joy was printed in Scotland in the 1700s and is still played at dances across America. "
                "Its first part rocks on A, F sharp and D, the notes of a D major chord."),
        play([("A4", 2), ("F#4", 3), ("D4", 3), ("F#4", 3)], hint="Open A, high-2 F sharp on D, open D, F sharp. Rock your elbow between strings."),
        tune(SOLDIER_1, bpm=60, title="First half"),
        tune(SOLDIER_2, bpm=60, title="Second half"),
        quiz("Which finger plays G on the E string?", ["Low 2", "High 2", "Third"], 0,
             "Soldier's Joy is in D major, so G is natural: high 2 for F sharp on D, low 2 for G on E."),
        tune(SOLDIER_1 + " " + SOLDIER_2, bpm=66, title="Soldier's Joy"),
        SOLDIER_SONG.along("Part B", bpm=60, title="Second part"),
        SOLDIER_SONG.take("Soldier's Joy"),
    ], minutes=SOLDIER_SONG.minutes(), xp=35, kind="song", arrangement=SOLDIER_SONG.meta()),
    lesson("vln-5-7", "Second finger checkup", [
        explain("Low or high?",
                "Every key sets your second finger. Before you play, ask: high 2 or low 2, and on which string?"),
        listen("F sharp, then high 2 or low 2?", [["F#5"], ["G5"]], ["Low 2, G natural", "High 2, G sharp"], 0),
        play([("C5", 2), ("C#5", 2), ("G5", 1), ("G#5", 1)], hint="Low 2 and high 2 on the A string, then low 2 and high 2 on the E string."),
        quiz("In A major, where does second finger sit on the A and E strings?", ["High on both", "Low on both", "Low on A, high on E"], 0),
        tune("G3 A3 B3 C4 | D4 E4 F#4 G4 | A4 B4 C5 D5 | E5 F#5 G5:2 | F#5 E5 D5 C5 | B4 A4 G4 F#4 | E4 D4 C4 B3 | A3 G3:3",
             bpm=72, title="G major, two octaves"),
        tune(MINUET_A, bpm=72, beats_per_bar=3, title="Minuet, bars 1 to 4"),
        tune(JOE_A1 + " " + JOE_A2, bpm=84, title="Old Joe Clark, first part"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNIT_6 = unit("vln-6", "Expression", "Loud and soft, slurs, your fourth finger, a first step toward vibrato, and Ode to Joy complete.", [
    lesson("vln-6-1", "Loud and soft", [
        explain("Three ways to play louder",
                "Add arm weight, use more bow speed, and move the contact point closer to the bridge. Use all three "
                "together. For soft, do the opposite."),
        explain("Forte and piano",
                "Music marks loud with f, for forte, and soft with p, for piano. Growing louder is a crescendo; "
                "fading away is a diminuendo."),
        quiz("To play forte, where does the bow move?", ["Closer to the bridge", "Over the fingerboard", "Nowhere; just squeeze"], 0,
             "Near the bridge the string takes more weight and speed, so it sounds louder without scratching."),
        play([("A4", 2), ("A4", 2), ("D5", 2), ("D5", 2)], hint="Each note twice: forte, then piano. Stay in tune while the volume changes."),
        tune("D4:4 D4:4 A4:4 A4:4 | G4:4 G4:4 D4:4", bpm=60, title="Long tones: grow, then fade"),
        tune(LIGHTLY_A + " " + LIGHTLY_END, bpm=72, title="Lightly Row, soft then loud"),
    ]),
    lesson("vln-6-2", "Slurs", [
        explain("Two notes, one bow",
                "A curved line over notes is a slur: play them all in one bow. Your left hand changes notes while "
                "the bow keeps moving.",
                staff(["A4", "B4", "C#5", "D5"])),
        play([("A4", 2), ("B4", 2), ("B4", 2), ("A4", 2)], hint="Slur A to B in one down-bow, then B to A in one up-bow."),
        explain("Share the bow",
                "Two notes in one bow means each gets half of it. Plan ahead and start a slur with enough bow left "
                "for both notes."),
        quiz("What does a slur tell you?", ["Play the notes in one bow", "Play the notes louder", "Stop the bow between notes"], 0),
        tune("A4 B4 C#5 D5 | E5 D5 C#5 B4 | A4:4", bpm=66, title="Scale in slurred pairs"),
        tune(ODE_MID, bpm=66, title="Slurred eighths"),
    ]),
    lesson("vln-6-3", "Your fourth finger", [
        explain("A whole step above third",
                "Fourth finger reaches a whole step above third. On the D string that's A, the same note as the open "
                "A string. Keep the finger curved and let your hand lean toward it.",
                board([(3, 5, 3), (3, 7, 4)])),
        play([("A4", 3), ("A4", 2), ("A4", 3)], hint="Fourth-finger A on the D string, open A, then fourth finger again. Match them exactly."),
        quiz("Why use fourth finger instead of an open string?",
             ["It avoids a string crossing and sounds warmer", "It's always louder", "Open strings are out of tune"], 0,
             "A fingered note keeps the line on one string and blends with the notes around it. Open strings ring brighter."),
        play([("D5", 2), ("E5", 2), ("E5", 1)], hint="Third-finger D, fourth-finger E on the A string, then open E. Listen for the match."),
        tune("D4 E4 F#4 G4 | A4@3:4 | A4@3 G4 F#4 E4 | D4:4", bpm=66, title="D to A on one string"),
        tune("A4@3 F#4 F#4:2 | G4 E4 E4:2 | D4 E4 F#4 G4 | A4@3 A4@3 A4@3:2", bpm=66, title="Lightly Row on one string"),
    ]),
    lesson("vln-6-4", "Amazing Grace", [
        explain("A slow hymn tune",
                "Amazing Grace is sung to an early American tune called New Britain. Its pairs of quick notes are "
                "slurs. Let the long notes sing with full, slow bows.",
                staff(["D4", "G4", "B4", "G4", "B4", "A4"])),
        tap([0, 2, 2.5], bpm=72, bars=2, beats_per_bar=3),
        play([("G4", 3), ("B4", 2), ("G4", 3)], hint="G to B and back crosses strings. Rock smoothly from the elbow."),
        tune(GRACE_1, bpm=72, beats_per_bar=3, title="First phrase"),
        quiz("How do you bow a quick pair, like B to G?", ["Both notes in one bow", "One bow for each note"], 0,
             "They're slurred, so they share one bow."),
        tune("r:2 B4 | " + GRACE_2, bpm=72, beats_per_bar=3, title="Second phrase"),
        tune(GRACE_1 + " " + GRACE_2, bpm=76, beats_per_bar=3, title="Amazing Grace"),
        AMAZING_SONG.take("Amazing Grace"),
    ], minutes=AMAZING_SONG.minutes(), xp=35, kind="song", arrangement=AMAZING_SONG.meta()),
    lesson("vln-6-5", "Getting ready for vibrato", [
        explain("What vibrato is",
                "Vibrato is a small, even wave in pitch that makes long notes glow. The fingertip rolls slightly back "
                "from the note and returns, again and again, moved by the hand and arm."),
        explain("In tune comes first",
                "Vibrato can't rescue a note that's out of tune; it only colors one that's centered. Most players "
                "add it once their fingers land in tune without searching."),
        quiz("When is a note ready for vibrato?", ["When it's already in tune", "When it's a little sharp", "When the bow moves fast"], 0),
        explain("A first motion, no bow",
                "Set second finger on the A string. Keep the fingertip in place, soften the knuckle, and slowly rock "
                "your hand toward the scroll and back. Small and even. A teacher's eye helps here."),
        play([("C#5", 2), ("D5", 2), ("E5", 2)], hint="Now bow these without vibrato and center each one. That center is where vibrato starts."),
        tune("D5:4 C#5:4 B4:4 A4:4", bpm=60, title="Long, centered tones"),
    ]),
    lesson("vln-6-6", "Arkansas Traveler", [
        explain("Fiddle slurs",
                "Arkansas Traveler was in print by 1847. Fiddlers slur its quickest notes in pairs, which gives the "
                "tune its skip. Start slow and keep the pairs even."),
        tune(TRAVELER_1, bpm=72, title="First part"),
        tune(TRAVELER_CADENCE, bpm=72, title="First part, ending"),
        quiz("Why do fiddlers slur quick pairs?", ["It saves bow and adds a lilt", "It makes every note louder", "It keeps the strings in tune"], 0),
        play([("A5", 1), ("G5", 1), ("F#5", 1), ("A5", 1)], hint="A, G, F sharp, A on the E string: third finger, low 2, first, third."),
        tune(TRAVELER_2, bpm=72, title="Second part"),
        tune(" ".join([TRAVELER_1, TRAVELER_CADENCE, TRAVELER_2]), bpm=80, title="Arkansas Traveler"),
        TRAVELER_SONG.take("Arkansas Traveler"),
    ], minutes=TRAVELER_SONG.minutes(), xp=35, kind="song", arrangement=TRAVELER_SONG.meta()),
    lesson("vln-6-7", "Recital: Ode to Joy", [
        explain("Your recital",
                "Put it all together: in-tune fingers, straight bows, slurs and dynamics. Start piano, grow through "
                "the middle, and finish forte."),
        play([("A4", 3), ("A4", 2), ("E5", 2), ("E5", 1)], hint="Warm up: fourth finger against the open strings, A and then E."),
        quiz("Which marking means grow louder?", ["Crescendo", "Diminuendo", "Piano"], 0),
        tune(ODE_1 + " " + ODE_2, bpm=72, title="Ode to Joy, first half"),
        tune(ODE_MID + " " + ODE_2, bpm=72, title="Ode to Joy, second half"),
        tune(" ".join([ODE_1, ODE_2, ODE_MID, ODE_2]), bpm=80, title="Ode to Joy"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("violin", "Violin", "Bow, finger and play in tune, from open strings to fiddle tunes",
                "violin.standard.4", "music.note", "amber", [
                    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6,
                ])
