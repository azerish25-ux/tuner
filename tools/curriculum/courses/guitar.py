"""Guitar: from the first open string to barre chords. Unit 1 is the style reference for every course."""
from lib import along, chord, course, explain, fretboard, fretted, lesson, listen, notes, part, play_chord, progression, quiz, rhythm, strum, tap, unit
from songbook import Part, song
import tunes
# The Timbre Originals the song spotlights play from (see "song spotlights" below).
from courses.originals import (
    BALLAD as BALLAD_STRUM, CELLAR, CELLAR_1, CELLAR_SONG, DUST_3, DUST_4, GLASS_SONG, KITE_SONG, OFFBEAT, RADIO_HOOK,
    RUST_3, RUST_HOOK, RUST_SONG,
)
from courses.originals_part2 import GHOST, HALO, HALO_RIFF, LETTERS, LETTERS_HOOK

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
Em = chord(G, "Em", "022000", "x23xxx")
E = chord(G, "E", "022100", "x231xx")          # Em plus finger 1
Am = chord(G, "Am", "x02210", "xx231x")        # the E shape, one string thinner
A = chord(G, "A", "x02220", "xx123x")
C = chord(G, "C", "x32010", "x32x1x")
G_MAJ = chord(G, "G", "320003", "21xxx3")
D = chord(G, "D", "xx0232", "xxx132")
Dm = chord(G, "Dm", "xx0231", "xxx231")
F_MINI = chord(G, "F", "xx3211", "xx3211")
F_FIVE = chord(G, "F", "x33211", "x34211")
F_BARRE = chord(G, "F", "133211", "134211")
D7 = chord(G, "D7", "xx0212", "xxx213")
E7 = chord(G, "E7", "020100", "x2x1xx")        # E without finger 3
A7 = chord(G, "A7", "x02020", "xx1x3x")        # A without finger 2
G7 = chord(G, "G7", "320001", "32xxx1")
B7 = chord(G, "B7", "x21202", "x213x4")
Dsus4 = chord(G, "Dsus4", "xx0233", "xxx134")
Dsus2 = chord(G, "Dsus2", "xx0230", "xxx13x")
Asus4 = chord(G, "Asus4", "x02230", "xx124x")
E5 = chord(G, "E5", "022xxx", "x23xxx")        # the bottom of Em
A5 = chord(G, "A5", "x022xx", "xx23xx")
G5 = chord(G, "G5", "355xxx", "134xxx")
A5_UP = chord(G, "A5", "577xxx", "134xxx")
C5 = chord(G, "C5", "x355xx", "x134xx")
D5 = chord(G, "D5", "x577xx", "x134xx")        # C5 slid up two frets
Bm = chord(G, "Bm", "x24432", "x13421")
Bm_EASY = chord(G, "Bm", "xx4432", "xx3421")

# ---------------------------------------------------------------- rhythms (beats inside one 4/4 bar)
ONCE = [0]
HALVES = [0, 2]
QUARTERS = [0, 1, 2, 3]
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
SKIP = [0, 1, 1.5, 2, 3, 3.5]            # down, down-up, down, down-up
FOLK = [0, 1, 1.5, 2.5, 3, 3.5]          # down, down-up, up-down-up
PUSH = [0, 1.5, 3]                       # one, the and of two, four
SHUFFLE = [round(b + o, 3) for b in range(4) for o in (0, 2 / 3)]

# ---------------------------------------------------------------- melodies (all public domain)
ODE_1 = "E4:1 E4:1 F4:1 G4:1 G4:1 F4:1 E4:1 D4:1 C4:1 C4:1 D4:1 E4:1 E4:1.5 D4:0.5 D4:2"
ODE_2 = "E4:1 E4:1 F4:1 G4:1 G4:1 F4:1 E4:1 D4:1 C4:1 C4:1 D4:1 E4:1 D4:1.5 C4:0.5 C4:2"
ODE = f"{ODE_1} {ODE_2}"                 # Beethoven, Symphony No. 9 (1824)
MARY_1 = "E4:1 D4:1 C4:1 D4:1 E4:1 E4:1 E4:2 D4:1 D4:1 D4:2 E4:1 G4:1 G4:2"
MARY_2 = "E4:1 D4:1 C4:1 D4:1 E4:1 E4:1 E4:1 E4:1 D4:1 D4:1 E4:1 D4:1 C4:4"
MARY = f"{MARY_1} {MARY_2}"              # Lowell Mason (1830)
SAINTS_1 = "r:1 C3:1 E3:1 F3:1 G3:4 r:1 C3:1 E3:1 F3:1 G3:4 r:1 C3:1 E3:1 F3:1 G3:2 E3:2 C3:2 E3:2 D3:4"
SAINTS_2 = "r:1 E3:1 E3:1 D3:1 C3:3 C3:1 E3:2 G3:1 G3:1 G3:1 F3:3 r:2 E3:1 F3:1 G3:2 E3:2 C3:2 D3:2 C3:4"
SAINTS = f"{SAINTS_1} {SAINTS_2}"        # traditional spiritual, recorded 1923
AMAZING_1 = "r:2 D3:1 G3:2 B3:0.5 G3:0.5 B3:2 A3:1 G3:2 E3:1 D3:2 D3:1 G3:2 B3:0.5 G3:0.5 B3:2 A3:1 D4:6"
AMAZING_2 = "B3:1 D4:2 B3:0.5 G3:0.5 B3:2 A3:1 G3:2 E3:1 D3:2 D3:1 G3:2 B3:0.5 G3:0.5 B3:2 A3:1 G3:6"
AMAZING = AMAZING_1.replace("D4:6", "D4:5") + " " + AMAZING_2   # "New Britain" (1829)
GREEN_1 = "r:2 A3:1 C4:2 D4:1 E4:1.5 F4:0.5 E4:1 D4:2 B3:1 G3:1.5 A3:0.5 B3:1 C4:2 A3:1 A3:1.5 G#3:0.5 A3:1 B3:2 G#3:1 E3:3"
GREEN_A = (GREEN_1.replace("E3:3", "E3:2 A3:1")
           + " C4:2 D4:1 E4:1.5 F4:0.5 E4:1 D4:2 B3:1 G3:1.5 A3:0.5 B3:1 C4:1.5 B3:0.5 A3:1 G#3:1.5 F#3:0.5 G#3:1 A3:3")
GREEN_B = ("G4:3 G4:1.5 F#4:0.5 E4:1 D4:2 B3:1 G3:1.5 A3:0.5 B3:1 C4:2 A3:1 A3:1.5 G#3:0.5 A3:1 B3:2 G#3:1 E3:3"
           " G4:3 G4:1.5 F#4:0.5 E4:1 D4:2 B3:1 G3:1.5 A3:0.5 B3:1 C4:1.5 B3:0.5 A3:1 G#3:1.5 F#3:0.5 G#3:1 A3:3")
GREEN = f"{GREEN_A} {GREEN_B}"           # Greensleeves, English, 16th century
CLEM_1 = "r:2 G3:0.5 G3:0.5 G3:1 D3:1 B3:0.5 B3:0.5 B3:1 G3:1 G3:0.5 B3:0.5 D4:1.5 D4:0.5 C4:0.5 B3:0.5 A3:3"
CLEM = (CLEM_1.replace("A3:3", "A3:2 A3:0.5 B3:0.5")
        + " C4:1 C4:1 B3:0.5 A3:0.5 B3:1 G3:1 G3:0.5 B3:0.5 A3:1 D3:1 F#3:0.5 A3:0.5 G3:3")   # Clementine (1884)

# Original material.
RIFF_A = "E2:0.5 E2:0.5 G2:0.5 E2:0.5 A2@5:0.5 E2:0.5 G2:1"
RIFF_B = "E2:0.5 E2:0.5 B2:0.5 E2:0.5 D3@5:0.5 B2:0.5 E2:1"
RIFF = f"{RIFF_A} {RIFF_B}"
BOX_LOW = "A2@6:1 C3@6:1 D3@5:1 E3@5:1 D3@5:1 C3@6:1 A2@6:2"
BOX_MID = "G3@4:1 A3@4:1 C4@3:1 D4@3:1 C4@3:1 A3@4:1 G3@4:2"
BOX_TOP = "E4@2:1 G4@2:1 A4@1:1 C5@1:1 A4@1:1 G4@2:1 E4@2:2"
BOX = ("A2@6:1 C3@6:1 D3@5:1 E3@5:1 G3@4:1 A3@4:1 C4@3:1 D4@3:1 E4@2:1 G4@2:1 A4@1:1 C5@1:1"
       " A4@1:1 G4@2:1 E4@2:1 D4@3:1 C4@3:1 A3@4:1 G3@4:1 E3@5:1 D3@5:1 C3@6:1 A2@6:2")
BOX_DOTS = [(6, 5, 1), (6, 8, 4), (5, 5, 1), (5, 7, 3), (4, 5, 1), (4, 7, 3),
            (3, 5, 1), (3, 7, 3), (2, 5, 1), (2, 8, 4), (1, 5, 1), (1, 8, 4)]
SOLO_Q = "A4@1:1 C5@1:1 A4@1:1 G4@2:1 E4@2:3 r:1"
SOLO_A = "G4@2:0.5 A4@1:0.5 G4@2:0.5 E4@2:0.5 D4@3:1 C4@3:1 A3@4:4"
SOLO = f"{SOLO_Q} {SOLO_A}"

# Chord plans: (chord, bars).
GREEN_VERSE = [(Am, 1), (C, 1), (G_MAJ, 1), (Em, 1), (Am, 1), (F_MINI, 1), (E, 2),
               (Am, 1), (C, 1), (G_MAJ, 1), (Em, 1), (Am, 1), (E, 1), (Am, 2)]
GREEN_CHORUS = [(C, 2), (G_MAJ, 1), (Em, 1), (Am, 1), (F_MINI, 1), (E, 2),
                (C, 2), (G_MAJ, 1), (Em, 1), (Am, 1), (E, 1), (Am, 2)]
CLEM_CHORDS = [(G_MAJ, 3), (D7, 2), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)]
TWELVE_BAR = [(E7, 4), (A7, 2), (E7, 2), (B7, 1), (A7, 1), (E7, 1), (B7, 1)]
WALTZ = [0, 1, 2]

# ---------------------------------------------------------------- shared text (translated once)
ONE_FINGER = "One finger per fret: fret 1 gets finger 1, fret 2 gets finger 2, fret 3 gets finger 3."
MAJOR_MINOR = ["Major", "Minor"]
FIRST_SECOND = ["The first", "The second"]
UP_DOWN = ["Up", "Down"]
HOME = ["Yes, it feels finished", "No, it wants to go on"]


def shape(spec):
    return {"type": "chord", "chord": spec}


def tones(spec):
    """The notes a chord shape sounds, lowest first, for listen steps."""
    return [fretted(G, 6 - i, f) for i, f in enumerate(spec["frets"]) if f >= 0]


def with_fingers(step, fingers):
    """Fingers for the fretted notes of a chord played string by string, matching its chord diagram."""
    held = [n["at"] for n in step["notes"] if n.get("at") and n["at"]["f"] > 0]
    assert len(held) == len(fingers), f"{len(held)} fretted notes, {len(fingers)} fingers"
    for at, g in zip(held, fingers):
        at["g"] = g
    return step


# ---------------------------------------------------------------- whole songs (songbook)
# Each song lesson ends on its whole song: the tune the lesson teaches, with an intro, verses (the public-domain
# words, where the tune has them), a solo and an outro, on the strings its unit has taught. Charts use the shapes
# above; the mini F stands in for F.
SHAPES = {c["name"]: c for c in [Em, E, Am, A, C, G_MAJ, D, Dm, F_MINI, D7, E7, A7, G7, B7]}
THE_VERSE = "The verse"
THE_CHORUS = "The chorus"
HOOK = "The hook"
RIFF_TITLE = "The riff"

# ---------------------------------------------------------------- song spotlights
# Every unit from 2 on has one, just before its challenge: a Timbre Original (courses/originals.py, originals_part2.py)
# whose chords, key and feel fit what the unit taught, played with that skill: its riff or hook on the strings just
# learned, its strum on the unit's chords, a fill or a solo, then a section of the song. No Original is used twice.
# Sections come from the Original's own arrangement (Song.along: its tune and words); fills and solos are new, written
# over the Original's chords. Each lesson is a plain "lesson": the whole song stays in the Originals course.
SONGBOOK = "The whole song is in Songs, under Originals."


def spotlight(unit_id, original, steps, minutes=5):
    """A unit's song spotlight: "gtr-5-spotlight", "Song spotlight: Kite Weather"."""
    return lesson(f"{unit_id}-spotlight", f"Song spotlight: {original}", steps, minutes=minutes, xp=25)


def introduce(title, body, visual=None):
    """A spotlight's opening explain: the Original and the skill it uses, then where the whole song lives."""
    return explain(title, f"{body} {SONGBOOK}", visual)

# Ode to Joy, unit 2: strings 1 and 2, plus the open G that ends the middle section.
O_A1, O_A2, O_B, O_TAIL = tunes.ode(0)
ODE_V = Part("Verse 1", "verse", f"{O_A1} {O_A2} {O_B} {O_A2}", chords=tunes.ODE_CHORDS, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = song(G, 72, [
    Part("Intro", "intro", O_TAIL, chords="C G,C"),
    ODE_V,
    Part("Solo", "solo", f"{O_A1} {O_A2}", chords=f"{tunes.ODE_CHORDS_A1} {tunes.ODE_CHORDS_A2}"),
    ODE_V.with_lyrics("Verse 2", tunes.ODE_WORDS_2),
    Part("Outro", "outro", O_A2, chords=tunes.ODE_CHORDS_A2, lyrics=tunes.ODE_WORDS_END),
], shapes=SHAPES, words=tunes.ODE_CREDIT)

# Mary Had a Little Lamb: four verses of Sarah Josepha Hale's rhyme (1830), a solo between the second and third.
MARY_V = Part("Verse 1", "verse", MARY, chords="C C G C C C G C", lyrics=(
    "Ma-ry had a lit-tle lamb, / lit-tle lamb, lit-tle lamb, / Ma-ry had a lit-tle lamb, its / fleece was white as snow."))
MARY_SONG = song(G, 76, [
    Part("Intro", "intro", "D4 D4 E4 D4 C4:4", chords="G C"),
    MARY_V,
    MARY_V.with_lyrics("Verse 2", "Ev-ery-where that Ma-ry went, / Ma-ry went, Ma-ry went, / ev-ery-where that Ma-ry went, the / "
                                  "lamb was sure to go."),
    MARY_V.instrumental("Solo"),
    MARY_V.with_lyrics("Verse 3", "Fol-lowed her to school one day, / school one day, school one day, / fol-lowed her to school one day, "
                                  "which / was a-gainst the rule."),
    MARY_V.with_lyrics("Verse 4", "Made the chil-dren laugh and play, / laugh and play, laugh and play, / made the chil-dren laugh and "
                                  "play to / see a lamb at school."),
    Part("Outro", "outro", "E4 D4 C4 D4 E4 E4 E4:2 D4 D4 E4 D4 C4:4", chords="C C G C",
         lyrics="Ma-ry had a lit-tle lamb, / fleece was white as snow."),
], shapes=SHAPES, words="Sarah Josepha Hale (1830)")

# When the Saints Go Marching In, unit 6: low on strings 5, 4 and 3; the solo takes the verse up an octave, onto
# strings 2 and 1 from unit 2.
SAINTS_TAG = "r:2 E3 F3 G3:2 E3:2 C3:2 D3:2 C3:4"
SAINTS_V = Part("Verse 1", "verse", SAINTS_1, chords="C C C C C C C G",
                lyrics="Oh when the saints / go march-ing in, / oh when the saints go march-ing in,")
SAINTS_C = Part("Chorus", "chorus", SAINTS_2, chords="C C C F C C C,G C",
                lyrics="Oh Lord, I want to be in that num-ber, / when the saints go march-ing in.")
SAINTS_SONG = song(G, 80, [
    Part("Intro", "intro", SAINTS_TAG, chords="C C C,G C"),
    SAINTS_V, SAINTS_C,
    SAINTS_V.with_lyrics("Verse 2", "Oh when the sun / re-fuse to shine, / oh when the sun re-fuse to shine,"),
    SAINTS_C,
    Part("Solo", "solo", tunes.transpose(SAINTS_1, 12), chords="C C C C C C C G"),
    SAINTS_C,
    Part("Outro", "outro", SAINTS_TAG, chords="C C C,G C", lyrics="when the saints go march-ing in."),
], shapes=SHAPES, words="Traditional spiritual")

# Amazing Grace, unit 6: in G on strings 4, 3 and 2, three of Newton's verses and a solo.
AMAZING_V = Part("Verse 1", "verse", tunes.AMAZING, pickup=1, chords=tunes.AMAZING_CHORDS, lyrics=tunes.AMAZING_WORDS_1)
AMAZING_SONG = song(G, 72, [
    Part("Intro", "intro", "G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:3 G3:3", chords="G G,D7 G G"),
    AMAZING_V,
    AMAZING_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    AMAZING_V.instrumental("Solo"),
    AMAZING_V.with_lyrics("Verse 3", tunes.AMAZING_WORDS_3),
    Part("Outro", "outro", tunes.AMAZING_TAIL, pickup=1, chords=tunes.AMAZING_TAIL_CHORDS, lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, shapes=SHAPES, words=tunes.AMAZING_CREDIT)

# Greensleeves, unit 7: A minor, two verses (the second from the 1584 broadside), each with the chorus. Chords as
# the lesson strums them.
GREEN_V = Part("Verse 1", "verse", GREEN_A.replace("r:2 ", "", 1), pickup=1,
               chords="Am C G Em Am F E E Am C G Em Am E Am", lyrics=(
    "A-las, my love, _ you do me wrong, _ / to cast me off dis-cour-teous- _ ly, / for I have lov-ed you well and long, _ / "
    "de-light-ing in your com-pa-ny."))
GREEN_C = Part("Chorus", "chorus", GREEN_B, chords="C C G Em Am F E E C C G Em Am E Am", lyrics=(
    "Green-sleeves was all my joy, / and Green-sleeves was my de- _ _ light, _ _ / Green-sleeves was my heart of gold, _ / "
    "and who but my La-dy Green-sleeves."))
GREEN_SONG = song(G, 72, [
    Part("Intro", "intro", "G3:1.5 A3:0.5 B3 C4:1.5 B3:0.5 A3 G#3:1.5 F#3:0.5 G#3 A3:3", chords="Em Am E Am"),
    GREEN_V, GREEN_C,
    GREEN_V.with_lyrics("Verse 2", "I have been read- _ y at your hand, _ / to grant what-ev-er you would _ crave; / I have both "
                                   "wa-ged life and land, / your _ love and good-will for to _ have."),
    GREEN_C,
    Part("Outro", "outro", "G#3:1.5 F#3:0.5 G#3 A3:3", chords="E Am"),
], beats_per_bar=3, shapes=SHAPES, words="Traditional (England, 1580s)")
# The strummed song (gtr-7-2): verse, chorus, verse, chorus, once per bar in three.
GREEN_WHOLE = GREEN_VERSE + GREEN_CHORUS + GREEN_VERSE + GREEN_CHORUS

# Clementine, unit 7: in G on strings 4, 3 and 2, three verses with the chorus and a solo.
CLEM_TUNE = CLEM.replace("r:2 ", "", 1)
CLEM_CHART = "G G G D7 D7 G D7 G"
CLEM_V = Part("Verse 1", "verse", CLEM_TUNE, pickup=1, chords=CLEM_CHART, lyrics=tunes.CLEM_WORDS_1)
CLEM_C = Part("Chorus", "chorus", CLEM_TUNE, pickup=1, chords=CLEM_CHART, lyrics=tunes.CLEM_CHORUS)
CLEM_SONG = song(G, 72, [
    Part("Intro", "intro", "A3 D3 F#3:0.5 A3:0.5 G3:3", chords="D7 G"),
    CLEM_V, CLEM_C,
    CLEM_V.with_lyrics("Verse 2", tunes.CLEM_WORDS_2), CLEM_C,
    CLEM_V.instrumental("Solo"),
    CLEM_V.with_lyrics("Verse 3", tunes.CLEM_WORDS_3), CLEM_C,
    Part("Outro", "outro", "G3:0.5 B3:0.5 A3 D3 F#3:0.5 A3:0.5 G3:3", pickup=1, chords="D7 G", lyrics=tunes.CLEM_WORDS_END),
], beats_per_bar=3, shapes=SHAPES, words=tunes.CLEM_CREDIT)


# ================================================================ 1. Hello, guitar

UNIT_1 = unit("gtr-1", "Hello, guitar", "Hold it, tune it, play your first notes.", [
    lesson("gtr-1-1", "Meet your guitar", [
        explain("Six strings, one job", "The thickest string is the lowest. It sits nearest your face when you play. We call it string 6.",
                part("strings")),
        explain("Turn to tune", "Each string has a tuning peg on the head. Turning it changes the pitch. Timbre listens and tells you which way.",
                part("head")),
        quiz("Which string is string 6?", ["The thickest", "The thinnest", "The middle one"], 0,
             "Strings count from the thinnest (1) to the thickest (6)."),
        notes(G, [("E2", 6)], hint="Pluck the thickest string and let it ring."),
        notes(G, [("E4", 1)], hint="Now the thinnest one, string 1."),
    ], minutes=3, xp=15),
    lesson("gtr-1-2", "The open strings", [
        explain("E A D G B E", "From thick to thin: E, A, D, G, B, E. Try: Every Amateur Does Get Better Eventually.",
                fretboard(G, [(6, 0), (5, 0), (4, 0), (3, 0), (2, 0), (1, 0)])),
        notes(G, [("E2", 6), ("A2", 5), ("D3", 4)], hint="Play strings 6, 5 and 4, one at a time."),
        notes(G, [("G3", 3), ("B3", 2), ("E4", 1)], hint="Now strings 3, 2 and 1."),
        quiz("What is string 5 called?", ["A", "D", "B", "G"], 0, visual=fretboard(G, [(5, 0)])),
        listen("Which is higher?", [["E2"], ["E4"]], FIRST_SECOND, 1),
        along(G, "E2@6:2 A2@5:2 D3@4:2 G3@3:2 B3@2:2 E4@1:2", bpm=60, title="Open-string roll call"),
    ], minutes=4, xp=20),
    lesson("gtr-1-3", "Your first fretted notes", [
        explain("Press just behind the fret", "Put your fingertip just behind the metal fret, not on top of it. Press firmly enough for a clean ring.",
                fretboard(G, [(1, 1, 1)])),
        notes(G, [("F4", 1)], hint="String 1, fret 1, first finger."),
        notes(G, [("G4", 1)], hint="String 1, fret 3, third finger."),
        notes(G, ["E4", "F4", "G4"], hint="Open, fret 1, fret 3: E, F, G."),
        quiz("Where do you press?", ["Just behind the fret", "On top of the fret", "Between two frets, in the middle"], 0),
        along(G, "E4:1 F4:1 G4:2 G4:1 F4:1 E4:2", bpm=70, title="Up and back"),
    ], minutes=4, xp=20),
    lesson("gtr-1-4", "Your first chord: E minor", [
        explain("Two fingers, six strings", "E minor uses two fingers on fret 2, strings 5 and 4. Every string rings.", shape(Em)),
        play_chord(Em),
        explain("Strum down", "Brush across all six strings from thick to thin, one smooth motion. Keep your wrist loose.",
                rhythm(QUARTERS)),
        tap(QUARTERS, bpm=70, bars=2),
        strum(Em, QUARTERS, bpm=60, bars=2),
    ], minutes=5, xp=25),
    lesson("gtr-1-5", "First-steps challenge", [
        explain("No new ideas, just you", "This challenge mixes the whole unit: the open strings, E, F and G on string 1, and E minor. "
                "Take a breath between steps."),
        quiz("From thick to thin, the open strings are…", ["E B G D A E", "E A D G B E", "A D G B E A"], 1,
             "Every Amateur Does Get Better Eventually: E A D G B E, string 6 to string 1."),
        along(G, "E4@1:2 B3@2:2 G3@3:2 D3@4:2 A2@5:2 E2@6:2", bpm=60, title="Roll call, thin to thick"),
        listen("Which is lower?", [["A2"], ["G3"]], FIRST_SECOND, 0),
        along(G, "E4:1 F4:1 G4:2 F4:1 E4:1 F4:2 G4:1 F4:1 E4:2", bpm=72, title="E, F and G"),
        play_chord(Em),
        strum(Em, QUARTERS, bpm=66, bars=4),
    ], minutes=4, xp=30, kind="challenge"),
])

# ================================================================ 2. First melodies

UNIT_2 = unit("gtr-2", "First melodies", "Notes on strings 1 and 2, reading tab, and your first two tunes.", [
    lesson("gtr-2-1", "Three notes on string 2", [
        explain("String 2: B, C and D", "String 2 works like string 1. Open, it's B. Fret 1 with your first finger is C. "
                "Fret 3 with your third finger is D.", fretboard(G, [(2, 0), (2, 1, 1), (2, 3, 3)])),
        notes(G, [("B3", 2)], hint="Pluck string 2 open. That's B."),
        notes(G, [("C4", 2)], hint="String 2, fret 1, first finger. That's C."),
        notes(G, [("D4", 2)], hint="String 2, fret 3, third finger. That's D."),
        quiz("Which finger plays fret 3?", ["First", "Second", "Third", "Fourth"], 2, ONE_FINGER),
        explain("Thumb behind the neck", "Rest your thumb on the back of the neck, behind your second finger. "
                "Your fingers can then arch and land on their tips."),
        along(G, "B3:1 C4:1 D4:2 D4:1 C4:1 B3:2", bpm=66, title="Up and back on string 2"),
    ], minutes=4, xp=20),
    lesson("gtr-2-2", "Reading tab", [
        explain("Tab is a map", "Tab draws six lines, one per string, with string 1 on top. A number on a line is the fret to press. "
                "A 0 means play that string open.", fretboard(G, [(1, 0), (2, 1, 1), (2, 3, 3)])),
        quiz("In tab, a 3 on the top line means…", ["String 6, fret 3", "String 1, fret 3", "Play three strings"], 1,
             "The top line is string 1, the thinnest. The number is the fret."),
        notes(G, [("E4", 1), ("F4", 1), ("G4", 1)], hint="Top line: 0, 1, 3."),
        quiz("A 0 on the second line means…", ["Play string 2 open", "Don't play string 2", "Press string 2 at fret 10"], 0),
        notes(G, [("D4", 2), ("C4", 2), ("B3", 2)], hint="Second line: 3, 1, 0."),
        quiz("Which note is this?", ["F", "C", "B", "D"], 1, visual=fretboard(G, [(2, 1, 1)])),
        along(G, "G4:1 F4:1 E4:1 D4:1 C4:1 D4:1 E4:2", bpm=66, title="Down the stairs"),
    ], minutes=4, xp=20),
    lesson("gtr-2-3", "Long and short notes", [
        explain("A note that lasts two beats", "A half note rings for two beats. Pick once, count one, two, and let it sustain "
                "until the next note.", rhythm([0, 1, 2])),
        tap([0, 1, 2], bpm=66, bars=2),
        quiz("How long does a half note last?", ["One beat", "Two beats", "Four beats"], 1,
             "Half of a four-beat bar is two beats. A quarter note lasts one beat."),
        explain("Cross with a small move", "Going from string 2 to string 1 is a tiny move. Keep your picking hand close "
                "to the strings so the next note is ready."),
        notes(G, [("D4", 2), ("E4", 1)], hint="Fret 3 on string 2, then open string 1. Lift your finger as you pick."),
        notes(G, ["C4", "D4", "E4", "F4", "G4"], hint="C and D on string 2, then E, F and G on string 1."),
        along(G, "C4:1 D4:1 E4:2 F4:1 G4:1 E4:2 D4:1 C4:1 B3:2 C4:4", bpm=66, title="Across the strings"),
    ], minutes=4, xp=20),
    lesson("gtr-2-4", "Ode to Joy", [
        explain("A tune by Beethoven", "This melody comes from Beethoven's Ninth Symphony. It uses C, D, E, F and G, "
                "and it moves mostly one step at a time.", fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4"], hint="The first line, slowly: E E F G G F E D."),
        notes(G, ["C4", "C4", "D4", "E4", "E4", "D4", "D4"], hint="Then: C C D E E D D."),
        explain("Long, short, long", "Each line ends with a lilt: a longer note, a quick one, then a held one. "
                "Count one-and-two, and slip the quick note in on the and.", rhythm([0, 1.5, 2])),
        tap([0, 1.5, 2], bpm=66, bars=2),
        along(G, ODE_1, bpm=66, title="First line"),
        along(G, ODE, bpm=72, title="Ode to Joy"),
        ODE_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=30, kind="song", arrangement=ODE_SONG.meta()),
    lesson("gtr-2-5", "Mary Had a Little Lamb", [
        explain("Three notes and a jump", "This nursery tune walks on C, D and E, then jumps up to G. "
                "The jump is open string 1 to fret 3.", fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 3, 3)])),
        notes(G, ["E4", "D4", "C4", "D4", "E4", "E4", "E4"], hint="E D C D E E E: open string 1, down to string 2 and back."),
        notes(G, ["D4", "D4", "D4", "E4", "G4", "G4"], hint="D D D on string 2, then E and G on string 1."),
        quiz("Which note is this?", ["G", "C", "D", "F"], 2, visual=fretboard(G, [(2, 3, 3)])),
        along(G, MARY_1, bpm=66, title="First half"),
        along(G, MARY, bpm=72, title="Mary Had a Little Lamb"),
        MARY_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_SONG.minutes(), xp=30, kind="song", arrangement=MARY_SONG.meta()),
    # Letters in a Shoebox (C, 72 bpm): the chorus sits on strings 1 and 2 and opens with Ode to Joy's long-short lilt.
    spotlight("gtr-2", "Letters in a Shoebox", [
        introduce("A ballad on two strings", "Letters in a Shoebox is a Timbre Original, a slow ballad in C. Its chorus "
                  "lives on strings 1 and 2, and its hook opens with the long, short lilt you played in Ode to Joy.",
                  fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["C4", "D4", "E4", "F4", "G4", "D4"], hint="The hook: C and D on string 2, then E, F and G on string 1, "
              "and back to D."),
        tap([0, 1.5, 2, 3], bpm=63, bars=2),
        along(G, LETTERS_HOOK, bpm=60, title=HOOK),
        listen("Does the chorus end at home?", [["E4"], ["D4"], ["C4"], ["D4"], ["C4"]], HOME, 0),
        LETTERS.along("Chorus", bpm=63, title=THE_CHORUS),
        LETTERS.along("Chorus", bpm=72, title="Letters in a Shoebox"),
    ]),
    lesson("gtr-2-6", "Melody challenge", [
        explain("Six notes, two strings", "No new ideas: E, F and G on string 1, B, C and D on string 2. "
                "Start slow, then hold a steady tempo.",
                fretboard(G, [(1, 0), (1, 1, 1), (1, 3, 3), (2, 0), (2, 1, 1), (2, 3, 3)])),
        quiz("Which note is open string 2?", ["E", "G", "D", "B"], 3),
        listen("Did the tune go up or down?", [["G4"], ["F4"], ["E4"]], UP_DOWN, 1),
        notes(G, ["B3", "C4", "D4", "E4", "F4", "G4"], hint="All six notes, low to high."),
        along(G, "G4:1 F4:1 E4:1 D4:1 C4:1 B3:1 C4:2", bpm=72, title="Six notes down"),
        along(G, ODE, bpm=80, title="Ode to Joy, a little faster"),
        along(G, MARY, bpm=84, title="Mary Had a Little Lamb, faster"),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 3. First chords

UNIT_3 = unit("gtr-3", "First chords", "E minor, E, A minor and A, played cleanly, and your first chord changes.", [
    lesson("gtr-3-1", "Clean chords", [
        explain("Tips, not pads", "Press with your fingertips, arched like a bridge, so no finger leans on the string below it. "
                "Short nails make this much easier.", shape(Em)),
        play_chord(Em),
        explain("Check each string", "Pick the strings one at a time, thick to thin. A dull thud means a finger is touching "
                "that string. Adjust and pick it again."),
        with_fingers(along(G, "E2@6:1 B2@5:1 E3@4:1 G3@3:1 B3@2:1 E4@1:3", bpm=60, title="E minor, string by string"), [2, 3]),
        quiz("One string sounds dull. What's the likely cause?", ["A finger is touching it", "You strummed too slowly", "The pick is too thin"], 0,
             "A fingertip leaning on a neighboring string stops it ringing. Arch your fingers more."),
        strum(Em, QUARTERS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-3-2", "E major: add one finger", [
        explain("E minor plus one", "Keep your E minor shape and add your first finger on string 3, fret 1. "
                "That one note turns minor into major.", shape(E)),
        play_chord(E),
        explain("Bright and dark", "Major chords tend to sound bright and settled. Minor chords sound darker. "
                "E and E minor differ by just one note."),
        listen("Major or minor?", [tones(E)], MAJOR_MINOR, 0),
        listen("Major or minor?", [tones(Em)], MAJOR_MINOR, 1),
        with_fingers(along(G, "E2@6:1 B2@5:1 E3@4:1 G#3@3:1 B3@2:1 E4@1:3", bpm=60, title="E, string by string"), [2, 3, 1]),
        strum(E, QUARTERS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-3-3", "A minor", [
        explain("Same shape, one string over", "A minor is the E shape moved one string thinner: fingers 2 and 3 on fret 2, "
                "finger 1 on string 2, fret 1.", shape(Am)),
        play_chord(Am),
        explain("Start on the root", "The root is the note a chord is named after. In A minor it's open string 5, "
                "so start your strum there and skip string 6."),
        quiz("Which string do you skip in A minor?", ["String 1", "String 6", "String 5"], 1,
             "A minor's root is open string 5. Start the strum there."),
        listen("Which chord is minor?", [tones(E), tones(Am)], FIRST_SECOND, 1),
        with_fingers(along(G, "A2@5:1 E3@4:1 A3@3:1 C4@2:1 E4@1:4", bpm=60, title="A minor, string by string"), [2, 3, 1]),
        strum(Am, QUARTERS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-3-4", "A major", [
        explain("Three fingers in a row", "A packs fingers 1, 2 and 3 side by side on fret 2, on strings 4, 3 and 2. "
                "Strum from string 5.", shape(A)),
        play_chord(A),
        explain("Crowded? Angle them", "If your fingers feel cramped, slant them so each sits just behind the fret "
                "at a slight angle. Keep string 1 clear so it rings."),
        quiz("Which fret holds all three fingers in A?", ["Fret 2", "Fret 1", "Fret 3"], 0),
        listen("Which chord is minor?", [tones(A), tones(Am)], FIRST_SECOND, 1),
        with_fingers(along(G, "A2@5:1 E3@4:1 A3@3:1 C#4@2:1 E4@1:4", bpm=60, title="A, string by string"), [1, 2, 3]),
        strum(A, QUARTERS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-3-5", "From E minor to A minor", [
        explain("Move the shape, not the fingers", "From E minor to A minor, fingers 2 and 3 hop together to strings 4 and 3. "
                "Then finger 1 lands on string 2. Your hand barely moves.", shape(Am)),
        play_chord(Em),
        play_chord(Am),
        explain("Change early, land on one", "Strum once, then use the rest of the bar to change. Aim to land the new chord "
                "right on beat one. Speed comes later, by itself.", rhythm(ONCE)),
        strum(Em, ONCE, bpm=60, bars=2),
        strum(Am, ONCE, bpm=60, bars=2),
        quiz("How should your fingers travel between chords?", ["One at a time", "As high as possible", "Together, as one shape"], 2,
             "Moving the fingers as a unit is faster and lands cleaner. Keep them low, just above the strings."),
        progression([(Em, 1), (Am, 1), (Em, 1), (Am, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-3-6", "From A to E", [
        explain("See the shape first", "Every finger moves from A to E. Picture the E shape before you lift, "
                "then move all three together. Aim finger 2 at string 5.", shape(E)),
        play_chord(A),
        play_chord(E),
        strum(A, ONCE, bpm=60, bars=2),
        strum(E, ONCE, bpm=60, bars=2),
        listen("Which chord is minor?", [tones(Am), tones(A)], FIRST_SECOND, 0),
        progression([(A, 1), (E, 1), (A, 1), (E, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    # Dust on the Dashboard (A, 100 bpm): every verse ends on E, E, A, A; its tune there uses the notes of the E and A
    # shapes (G sharp, A, C sharp) plus D and the open strings.
    spotlight("gtr-3", "Dust on the Dashboard", [
        introduce("Country on E and A", "Dust on the Dashboard is a Timbre Original: country in A. Every verse ends on two "
                  "bars of E and two of A, the change you just learned. See the shape, move early and land on beat one.",
                  shape(E)),
        listen("Does this end at home?", [tones(E), tones(A)], HOME, 0),
        progression([(E, 2), (A, 2)], ONCE, bpm=60),
        progression([(E, 2), (A, 2)] * 2, HALVES, bpm=63),
        notes(G, ["B3", "E4", "D4", "B3", "C#4", "B3", "G#3", "B3"], hint="Over E: open B, open E, D at fret 3 on string 2, "
              "C sharp at fret 2, then G sharp at fret 1 on string 3."),
        along(G, f"{DUST_3} {DUST_4}", bpm=66, title="The end of the verse"),
        progression([(E, 2), (A, 2)] * 2, QUARTERS, bpm=72),
    ]),
    lesson("gtr-3-7", "Chord-change challenge", [
        explain("Four chords, clean changes", "No new ideas: E minor, E, A minor and A. Land each shape cleanly, "
                "then keep the changes steady."),
        quiz("Which finger turns E minor into E?", ["Finger 4 on string 1", "Finger 2 on string 6", "Finger 1 on string 3"], 2,
             "Finger 1 on string 3, fret 1 is the one note that makes E major."),
        listen("Major or minor?", [tones(Em)], MAJOR_MINOR, 1),
        play_chord(Am),
        play_chord(A),
        progression([(Em, 1), (Am, 1), (Em, 1), (Am, 1)], HALVES, bpm=66),
        progression([(A, 1), (E, 1), (A, 1), (E, 1)], HALVES, bpm=66),
        progression([(Em, 2), (Am, 2), (A, 2), (E, 2)], QUARTERS, bpm=66),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 4. Strumming

RADIO_LINE = " ".join(RADIO_HOOK.split()[:12])      # Low Tide Radio's hook, first line: two bars, over E minor and A

UNIT_4 = unit("gtr-4", "Strumming", "Downstrokes, down-up eighths, accents and a strumming hand that never stops.", [
    lesson("gtr-4-1", "One strum per beat", [
        explain("Quarter notes", "A quarter note lasts one beat. Strum down on every beat and count out loud: "
                "one, two, three, four.", rhythm(QUARTERS)),
        tap(QUARTERS, bpm=70, bars=2),
        strum(Em, QUARTERS, bpm=70, bars=2),
        explain("Strum from the wrist", "Let the motion come from a loose wrist and forearm, like shaking water off your hand. "
                "A stiff arm sounds harsh."),
        quiz("How many quarter-note strums fill a bar of four?", ["Two", "Four", "Eight"], 1),
        strum(Am, QUARTERS, bpm=70, bars=4),
        strum(E, QUARTERS, bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-4-2", "Down and up", [
        explain("Eighth notes: down-up", "Split each beat in two. Strum down on the number and up on the and: "
                "one and two and. That's eight strums per bar.", rhythm(EIGHTHS)),
        tap(EIGHTHS, bpm=60, bars=2),
        strum(Em, EIGHTHS, bpm=60, bars=2),
        quiz("Where does the up strum fall?", ["On the and", "On the number", "Only on beat four"], 0,
             "Down on the number, up on the and. Your hand goes down and up once per beat."),
        explain("Lighter going up", "Up strums are naturally softer. Brush just the thinner three or four strings "
                "on the way up. That gives the groove its lift."),
        strum(Am, EIGHTHS, bpm=60, bars=2),
        strum(A, EIGHTHS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-4-3", "Accent beat one", [
        explain("Lean on one", "An accent is a note played a little louder. Strum beat one harder than the rest. "
                "It tells everyone where the bar begins.", rhythm(QUARTERS)),
        strum(E, QUARTERS, bpm=72, bars=4),
        quiz("Which beat gets the accent?", ["Beat three", "Every and", "Beat one"], 2,
             "Beat one starts the bar. A slightly louder first strum keeps you, and anyone listening, in time."),
        explain("Count the bars", "Say the bar number on beat one: one, two, three, four; two, two, three, four. "
                "You always know where you are."),
        tap(QUARTERS, bpm=72, bars=4),
        strum(Am, EIGHTHS, bpm=66, bars=4),
        strum(Em, QUARTERS, bpm=76, bars=4),
    ], minutes=5, xp=20),
    lesson("gtr-4-4", "Keep the hand moving", [
        explain("A pendulum hand", "Your strumming hand swings down and up all the time, like a pendulum. "
                "To skip a strum, keep swinging and simply miss the strings.", rhythm(SKIP)),
        tap(SKIP, bpm=66, bars=2),
        strum(Em, SKIP, bpm=60, bars=2),
        quiz("To skip a strum, your hand…", ["Keeps moving and misses the strings", "Stops and waits", "Strums twice as hard"], 0,
             "A hand that never stops keeps steady time. The skipped strum is a swing that doesn't touch the strings."),
        strum(Am, SKIP, bpm=60, bars=2),
        strum(E, SKIP, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-4-5", "The folk strum", [
        explain("Down, down-up, up-down-up", "This pattern drives countless songs. On beat three your hand swings down "
                "without touching the strings, then catches the up strum.", rhythm(FOLK)),
        tap(FOLK, bpm=60, bars=2),
        strum(Em, FOLK, bpm=60, bars=2),
        quiz("In this pattern, which beat has no strum on the number?", ["One", "Two", "Three", "Four"], 2,
             "On three the hand swings down past the strings, then strums up on the and."),
        strum(A, FOLK, bpm=60, bars=2),
        strum(Am, FOLK, bpm=66, bars=2),
        strum(E, FOLK, bpm=66, bars=2),
    ], minutes=5, xp=25),
    # Low Tide Radio (E minor, 80 bpm): reggae, E minor and A a bar each, the guitar only on the ands: the pendulum hand.
    spotlight("gtr-4", "Low Tide Radio", [
        introduce("Reggae on the ands", "Low Tide Radio is a Timbre Original: laid-back reggae on E minor and A. The guitar "
                  "plays only the ands. Keep your hand swinging down and up, miss the strings on each number and catch "
                  "every and.", rhythm(OFFBEAT)),
        tap(OFFBEAT, bpm=66, bars=2),
        strum(Em, OFFBEAT, bpm=66, bars=2),
        progression([(Em, 1), (A, 1)] * 2, HALVES, bpm=60),
        quiz("Where does the guitar play in Low Tide Radio?", ["Only on the ands", "On every number", "Only on beat one"], 0,
             "Bass and drums hold the numbers. The guitar answers between them, on the ands."),
        progression([(Em, 1), (A, 1)] * 4, OFFBEAT, bpm=66),
        along(G, f"{RADIO_LINE} {RADIO_LINE}", bpm=63, title=HOOK),
        progression([(Em, 1), (A, 1)] * 4, OFFBEAT, bpm=76),
    ], minutes=6),
    lesson("gtr-4-6", "Strumming challenge", [
        explain("Steady hand, four chords", "No new ideas: quarters, eighths and the folk strum on the chords you know. "
                "Keep the hand swinging and lean on beat one."),
        tap(FOLK, bpm=70, bars=2),
        strum(Em, QUARTERS, bpm=76, bars=2),
        strum(Am, EIGHTHS, bpm=70, bars=2),
        quiz("Down-up eighths: where are the up strums?", ["On every and", "On every number", "Only on two and four"], 0),
        strum(E, FOLK, bpm=70, bars=2),
        progression([(Em, 2), (A, 2), (Am, 2), (E, 2)], FOLK, bpm=70),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 5. More open chords

UNIT_5 = unit("gtr-5", "More open chords", "C, G, D and D minor, two classic progressions, and the one-minute change.", [
    lesson("gtr-5-1", "C major", [
        explain("A three-step staircase", "C climbs like a staircase: finger 3 on string 5, fret 3; finger 2 on string 4, fret 2; "
                "finger 1 on string 2, fret 1.", shape(C)),
        play_chord(C),
        quiz("Which string do you skip in C?", ["String 1", "String 3", "String 6"], 2,
             "C's root is on string 5, fret 3. Start the strum there."),
        strum(C, QUARTERS, bpm=66, bars=2),
        explain("A minor to C: one finger", "Fingers 1 and 2 stay exactly where they are. Only finger 3 moves, "
                "from string 3 to string 5, fret 3.", shape(C)),
        progression([(Am, 1), (C, 1), (Am, 1), (C, 1)], HALVES, bpm=60),
    ], minutes=4, xp=20),
    lesson("gtr-5-2", "G major", [
        explain("Wide and bright", "G spreads out: finger 2 on string 6, fret 3; finger 1 on string 5, fret 2; "
                "finger 3 on string 1, fret 3. All six strings ring.", shape(G_MAJ)),
        play_chord(G_MAJ),
        quiz("In G, which strings ring open?", ["Strings 2, 3 and 4", "Strings 1 and 6", "None of them"], 0, visual=shape(G_MAJ)),
        strum(G_MAJ, QUARTERS, bpm=66, bars=2),
        explain("Lead with the bass", "When you change, land the finger for the lowest string first. It's the first note "
                "your strum hits, which buys a moment for the rest."),
        progression([(G_MAJ, 1), (C, 1), (G_MAJ, 1), (C, 1)], HALVES, bpm=60),
    ], minutes=4, xp=20),
    lesson("gtr-5-3", "D and D minor", [
        explain("A small triangle", "D lives on the thinnest three strings: finger 1 on string 3, fret 2; finger 3 on string 2, "
                "fret 3; finger 2 on string 1, fret 2.", shape(D)),
        play_chord(D),
        quiz("Where does a D chord's strum start?", ["String 6", "String 5", "String 4"], 2,
             "D's root is open string 4. Strings 5 and 6 stay quiet."),
        strum(D, QUARTERS, bpm=66, bars=2),
        explain("D minor: one note lower", "For D minor, the note on string 1 drops to fret 1. Reshuffle: finger 1 on string 1, "
                "finger 2 on string 3, finger 3 stays on string 2.", shape(Dm)),
        play_chord(Dm),
        listen("Which chord is minor?", [tones(D), tones(Dm)], FIRST_SECOND, 1),
        strum(Dm, QUARTERS, bpm=66, bars=2),
    ], minutes=5, xp=25),
    lesson("gtr-5-4", "G, C and D", [
        explain("Three chords, endless songs", "A key is a song's home base. In the key of G, the chords G, C and D do most "
                "of the work. Countless folk and rock songs use only these three."),
        listen("Does this end at home?", [tones(G_MAJ), tones(C), tones(D)], HOME, 1),
        progression([(G_MAJ, 1), (C, 1), (D, 1), (G_MAJ, 1)], HALVES, bpm=60),
        quiz("You keep landing late on a change. What helps most?", ["Strumming harder", "Skipping that chord", "Slowing down and moving early"], 2,
             "Slow, early changes build the habit. Speed follows on its own."),
        progression([(G_MAJ, 2), (C, 2), (D, 2), (G_MAJ, 2)], QUARTERS, bpm=66),
        progression([(G_MAJ, 1), (C, 1), (D, 1), (G_MAJ, 1)], FOLK, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-5-5", "A minor, C, G, D", [
        explain("Four chords in a row", "A progression is a chord sequence that repeats. A minor, C, G, D starts dark "
                "and brightens as it climbs."),
        progression([(Am, 1), (C, 1), (G_MAJ, 1), (D, 1)], HALVES, bpm=60),
        progression([(Am, 1), (C, 1), (G_MAJ, 1), (D, 1)], QUARTERS, bpm=66),
        explain("The one-minute change", "Away from the app, pick two chords and switch for one minute, one strum each. "
                "Count your clean changes and beat that score tomorrow. Start with D and D minor."),
        quiz("In a one-minute change, what do you count?", ["Clean changes", "Strings that buzz", "Seconds per chord"], 0),
        progression([(D, 1), (Dm, 1), (D, 1), (Dm, 1)], QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-5-6", "Open-chord challenge", [
        explain("Eight open chords", "No new ideas: C, G, D and D minor join E minor, E, A minor and A. "
                "Change early, strum steady and let each chord ring."),
        quiz("Which chord skips strings 5 and 6?", ["C", "G", "Am", "D"], 3),
        listen("Major or minor?", [tones(Dm)], MAJOR_MINOR, 1),
        progression([(G_MAJ, 2), (C, 2), (D, 2), (G_MAJ, 2)], FOLK, bpm=66),
        strum(Dm, QUARTERS, bpm=70, bars=2),
        progression([(Am, 1), (C, 1), (G_MAJ, 1), (D, 1)], EIGHTHS, bpm=70),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 6. Melodies on strings 3 and 4

UNIT_6 = unit("gtr-6", "Melodies on strings 3 and 4", "G and A on string 3, D, E and F on string 4, the C major scale "
              "and two traditional tunes.", [
    lesson("gtr-6-1", "Notes on string 3", [
        explain("String 3: G and A", "Open string 3 is G. Put finger 2 on fret 2 and you get A. "
                "The same rule holds: the finger matches the fret.", fretboard(G, [(3, 0), (3, 2, 2)])),
        notes(G, [("G3", 3)], hint="Pluck string 3 open. That's G."),
        notes(G, [("A3", 3)], hint="String 3, fret 2, second finger. That's A."),
        quiz("Which finger plays fret 2?", ["First", "Second", "Third"], 1, ONE_FINGER),
        notes(G, ["G3", "A3", "B3", "C4", "D4"], hint="G and A on string 3, then B, C and D on string 2."),
        along(G, "G3:1 A3:1 B3:1 C4:1 D4:2 C4:1 B3:1 A3:2 G3:2", bpm=66, title="G up to D and back"),
    ], minutes=4, xp=20),
    lesson("gtr-6-2", "Notes on string 4", [
        explain("String 4: D, E and F", "Open string 4 is D. Fret 2 is E and fret 3 is F. "
                "Keep your thumb low behind the neck so your fingers can reach.", fretboard(G, [(4, 0), (4, 2, 2), (4, 3, 3)])),
        notes(G, [("D3", 4)], hint="Pluck string 4 open. That's D."),
        notes(G, [("E3", 4), ("F3", 4)], hint="Fret 2, then fret 3: E, then F."),
        quiz("Open string 4 and string 2, fret 3 share which name?", ["G", "E", "D"], 2,
             "Both are D, an octave apart: the same note name, one higher than the other."),
        listen("Which D is higher?", [["D3"], ["D4"]], FIRST_SECOND, 1),
        notes(G, ["D3", "E3", "F3", "G3", "A3"], hint="D, E and F on string 4, then G and A on string 3."),
        along(G, "D3:1 E3:1 F3:1 G3:1 A3:2 G3:1 F3:1 E3:2 D3:2", bpm=66, title="Five notes, up and back"),
    ], minutes=4, xp=20),
    lesson("gtr-6-3", "The C major scale", [
        explain("One more note: C", "Put finger 3 on string 5, fret 3. That's C, the note the C major scale starts on.",
                fretboard(G, [(5, 3, 3)])),
        notes(G, [("C3", 5)], hint="String 5, fret 3, third finger. That's C."),
        explain("A scale is a ladder", "A scale climbs note by note from one letter to the same letter an octave higher. "
                "C major uses only plain letter names: C D E F G A B C.",
                fretboard(G, [(5, 3, 3), (4, 0), (4, 2, 2), (4, 3, 3), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1)])),
        notes(G, ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4"], hint="String 5 fret 3, then strings 4, 3 and 2. Go slowly."),
        quiz("How many different letter names are in C major?", ["Five", "Six", "Seven", "Eight"], 2,
             "C D E F G A B, then C again an octave higher."),
        along(G, "C3:1 D3:1 E3:1 F3:1 G3:1 A3:1 B3:1 C4:1 C4:1 B3:1 A3:1 G3:1 F3:1 E3:1 D3:1 C3:1", bpm=60,
              title="C major, up and down"),
    ], minutes=5, xp=25),
    lesson("gtr-6-4", "When the Saints Go Marching In", [
        explain("A New Orleans favorite", "This traditional spiritual became a jazz standard. "
                "It uses C, D, E, F and G on strings 5, 4 and 3.",
                fretboard(G, [(5, 3, 3), (4, 0), (4, 2, 2), (4, 3, 3), (3, 0)])),
        notes(G, ["C3", "E3", "F3", "G3"], hint="The opening: C, E, F, then open G."),
        explain("Start after a rest", "A pickup is a few notes that lead into a strong beat. Here beat one is silent, "
                "and C, E and F lead into a long G.", rhythm([1, 2, 3])),
        tap([1, 2, 3], bpm=72, bars=2),
        along(G, SAINTS_1, bpm=72, title="First half"),
        notes(G, ["E3", "E3", "D3", "C3", "C3", "E3", "G3", "G3", "G3", "F3"], hint="The chorus: E E D C, then C E G G G F."),
        along(G, SAINTS_2, bpm=72, title="Second half"),
        along(G, SAINTS, bpm=80, title="When the Saints Go Marching In"),
        SAINTS_SONG.take("When the Saints Go Marching In"),
    ], minutes=SAINTS_SONG.minutes(), xp=35, kind="song", arrangement=SAINTS_SONG.meta()),
    lesson("gtr-6-5", "Amazing Grace", [
        explain("Three beats to a bar", "Amazing Grace is in three: count one, two, three, with the weight on one. "
                "Its notes sit on strings 4, 3 and 2.", rhythm([0, 1, 2], beats_per_bar=3)),
        quiz("How many beats are in each bar here?", ["Two", "Three", "Four"], 1,
             "A bar of three feels like a gentle sway: strong, weak, weak."),
        tap(WALTZ, bpm=66, bars=2, beats_per_bar=3),
        notes(G, ["D3", "G3", "B3", "G3", "B3", "A3"], hint="The opening: D, G, B G, B, A. Open strings 4, 3 and 2, plus A."),
        notes(G, ["G3", "E3", "D3", "D3"], hint="Then down: G, E, D, D."),
        along(G, AMAZING_1, bpm=66, beats_per_bar=3, title="First half"),
        notes(G, ["B3", "D4", "B3", "G3", "B3", "A3", "G3"], hint="The high part: open B up to D at fret 3, then down through B, G and A."),
        along(G, AMAZING, bpm=72, beats_per_bar=3, title="Amazing Grace"),
        AMAZING_SONG.take("Amazing Grace"),
    ], minutes=AMAZING_SONG.minutes(), xp=35, kind="song", arrangement=AMAZING_SONG.meta()),
    lesson("gtr-6-6", "Lower-strings challenge", [
        explain("From string 5 to string 1", "No new ideas: every note from C on string 5 up to G on string 1, plus both tunes. "
                "Keep your thumb low and your fingers arched."),
        quiz("Where is A on string 3?", ["Fret 1", "Fret 2", "Fret 3"], 1),
        listen("Did the tune go up or down?", [["C3"], ["E3"], ["G3"]], UP_DOWN, 0),
        notes(G, ["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4", "D4", "E4", "F4", "G4"],
              hint="C major from string 5, up to G on string 1."),
        along(G, "G4:2 F4:1 E4:1 D4:1 C4:1 B3:1 A3:1 G3:1 F3:1 E3:1 D3:1 C3:4", bpm=66, title="All the way down"),
        along(G, SAINTS, bpm=84, title="The Saints, up to speed"),
        along(G, AMAZING, bpm=76, beats_per_bar=3, title="Amazing Grace, flowing"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 7. Songs with chords

UNIT_7 = unit("gtr-7", "Songs with chords", "A mini F, D7, and two traditional songs with both chords and melody.", [
    lesson("gtr-7-1", "The mini F", [
        explain("F without the barre", "This small F uses four strings. Finger 1 lies flat across strings 1 and 2 at fret 1, "
                "finger 2 goes on string 3, fret 2, and finger 3 on string 4, fret 3.", shape(F_MINI)),
        play_chord(F_MINI),
        explain("Roll, don't crush", "Tilt finger 1 slightly onto its thumb side. The bonier edge presses two strings "
                "more easily. Check that string 2 rings."),
        strum(F_MINI, QUARTERS, bpm=63, bars=2),
        explain("A minor, C, D, F", "This progression climbs step by step from A minor and lands on your new F. "
                "Strum twice per chord and change early."),
        progression([(Am, 1), (C, 1), (D, 1), (F_MINI, 1)], HALVES, bpm=60),
        progression([(Am, 1), (C, 1), (D, 1), (F_MINI, 1)], QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-7-2", "Greensleeves: the chords", [
        explain("Greensleeves", "This English tune is over 400 years old. Its chords are all ones you know: A minor, C, G, "
                "E minor, F and E. It's in three: strum once per bar, then on every beat.", rhythm(WALTZ, beats_per_bar=3)),
        quiz("Which strings does the mini F leave silent?", ["Strings 5 and 6", "Strings 1 and 2", "Only string 3"], 0,
             "The mini F starts on string 4. Begin your strum there and skip strings 5 and 6."),
        tap(WALTZ, bpm=63, bars=2, beats_per_bar=3),
        progression(GREEN_VERSE[:7], ONCE, bpm=60, beats_per_bar=3),
        progression(GREEN_VERSE, ONCE, bpm=63, beats_per_bar=3),
        progression(GREEN_CHORUS, ONCE, bpm=63, beats_per_bar=3),
        progression(GREEN_VERSE, WALTZ, bpm=66, beats_per_bar=3),
        progression(GREEN_WHOLE, WALTZ, bpm=66, beats_per_bar=3),
    ], minutes=8, xp=30, kind="song"),
    lesson("gtr-7-3", "Greensleeves: the melody", [
        explain("Sharps: one fret higher", "A sharp raises a note by one fret. Greensleeves uses G sharp on string 3, fret 1, "
                "and F sharp on string 4, fret 4. Reach that one with your little finger.", fretboard(G, [(3, 1, 1), (4, 4, 4)])),
        notes(G, [("G#3", 3), ("A3", 3), ("B3", 2)], hint="G sharp, A, B: string 3 at frets 1 and 2, then open string 2."),
        notes(G, ["A3", "C4", "D4", "E4", "F4", "E4", "D4", "B3"], hint="The opening: A, C D, E F E, D B."),
        along(G, GREEN_1, bpm=66, beats_per_bar=3, title="First phrase"),
        quiz("A sharp moves a note…", ["One fret higher", "One fret lower", "To the next string"], 0,
             "Sharp means one fret higher. G sharp sits between G and A."),
        notes(G, ["G4", "F#4", "E4", "D4", "B3"], hint="The chorus starts high: G on string 1, fret 3, then F sharp at fret 2."),
        along(G, GREEN_A, bpm=72, beats_per_bar=3, title="Greensleeves, verse"),
        along(G, GREEN, bpm=72, beats_per_bar=3, title="Greensleeves"),
        GREEN_SONG.take("Greensleeves"),
    ], minutes=GREEN_SONG.minutes(), xp=35, kind="song", arrangement=GREEN_SONG.meta()),
    lesson("gtr-7-4", "D7 and the Clementine chords", [
        explain("D7 leans toward G", "A seventh chord adds a note that pulls toward home. D7 wants to move to G. "
                "Fingers: 2 on string 3, fret 2; 1 on string 2, fret 1; 3 on string 1, fret 2.", shape(D7)),
        play_chord(D7),
        listen("Does this end at home?", [tones(G_MAJ), tones(D7)], HOME, 1),
        strum(D7, QUARTERS, bpm=66, bars=2),
        explain("Clementine", "This American ballad from the 1880s needs only G and D7. It's in three, like Amazing Grace. "
                "Strum once per bar, then on every beat."),
        progression(CLEM_CHORDS, ONCE, bpm=60, beats_per_bar=3),
        progression(CLEM_CHORDS, WALTZ, bpm=66, beats_per_bar=3),
    ], minutes=4, xp=25),
    lesson("gtr-7-5", "Clementine", [
        explain("Three strings and a stretch", "Clementine's melody sits on strings 4, 3 and 2. Its last line uses F sharp again: "
                "string 4, fret 4, little finger.", fretboard(G, [(4, 0), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
        notes(G, ["G3", "G3", "G3", "D3", "B3", "B3"], hint="The opening: G G G, down to open D, up to open B."),
        quiz("Which chord pulls toward G?", ["D7", "C", "E minor"], 0,
             "D7's extra note leans toward G. When G arrives, the tension lets go."),
        along(G, CLEM_1, bpm=66, beats_per_bar=3, title="First half"),
        notes(G, ["A3", "D3", "F#3", "A3", "G3"], hint="The last line: A, open D, F sharp at fret 4, A, then home to G."),
        along(G, CLEM, bpm=72, beats_per_bar=3, title="Clementine"),
        CLEM_SONG.take("Clementine"),
    ], minutes=CLEM_SONG.minutes(), xp=35, kind="song", arrangement=CLEM_SONG.meta()),
    lesson("gtr-7-6", "Songbook challenge", [
        explain("Two songs, start to finish", "No new ideas: the mini F, D7 and both songs from this unit. "
                "Change chords early and let the melodies sing."),
        quiz("Which chord pulls hardest toward G?", ["E minor", "C", "D7"], 2),
        progression([(Am, 1), (C, 1), (D, 1), (F_MINI, 1)], QUARTERS, bpm=70),
        listen("Major or minor?", [tones(F_MINI)], MAJOR_MINOR, 0),
        progression(GREEN_VERSE, WALTZ, bpm=72, beats_per_bar=3),
        along(G, GREEN_A, bpm=76, beats_per_bar=3, title="Greensleeves, verse"),
        progression(CLEM_CHORDS, WALTZ, bpm=76, beats_per_bar=3),
        along(G, CLEM, bpm=80, beats_per_bar=3, title="Clementine, up to speed"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 8. Seventh and sus chords

UNIT_8 = unit("gtr-8", "Seventh and sus chords", "E7, A7, G7 and B7, sus chords, the shuffle and your first 12-bar blues.", [
    lesson("gtr-8-1", "E7 and A7", [
        explain("E7: lift one finger", "Play E, then lift finger 3 off string 4. The open D that rings is the seventh, "
                "a note that adds bluesy tension.", shape(E7)),
        play_chord(E7),
        listen("Which chord has the seventh?", [tones(E), tones(E7)], FIRST_SECOND, 1),
        explain("A7: the same trick", "Play A, then lift finger 2 off string 3. Open G rings, and A becomes A7.", shape(A7)),
        play_chord(A7),
        quiz("How do you turn E into E7 here?", ["Add finger 4", "Move up one fret", "Lift finger 3"], 2),
        strum(E7, QUARTERS, bpm=66, bars=2),
        strum(A7, QUARTERS, bpm=66, bars=2),
    ], minutes=5, xp=25),
    lesson("gtr-8-2", "G7 and B7", [
        explain("G7: a new high note", "G7 keeps the low G but puts F on top: finger 3 on string 6, fret 3; "
                "finger 2 on string 5, fret 2; finger 1 on string 1, fret 1.", shape(G7)),
        play_chord(G7),
        listen("Does this end at home?", [tones(G7), tones(C)], HOME, 0),
        explain("B7: all four fingers", "Build B7 from string 5: finger 2 at fret 2, finger 1 on string 4, fret 1, finger 3 "
                "on string 3, fret 2, little finger on string 1, fret 2. String 2 rings open.", shape(B7)),
        play_chord(B7),
        quiz("Which chord does B7 lead to most naturally?", ["D", "C", "E minor"], 2,
             "B7 pulls toward E. Its tension melts into E minor or E."),
        strum(B7, QUARTERS, bpm=60, bars=2),
        progression([(B7, 1), (Em, 1), (B7, 1), (Em, 1)], QUARTERS, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-8-3", "The shuffle", [
        explain("Long-short, long-short", "A shuffle splits each beat unevenly: a long strum down, a short one up. "
                "It's the heartbeat of the blues. Think hum-pty, dum-pty.", rhythm(SHUFFLE)),
        tap(SHUFFLE, bpm=72, bars=2),
        quiz("In a shuffle, each beat splits into…", ["Long, then short", "Two equal halves", "Short, then long"], 0),
        strum(E7, SHUFFLE, bpm=66, bars=2),
        strum(A7, SHUFFLE, bpm=66, bars=2),
        strum(B7, SHUFFLE, bpm=66, bars=2),
        strum(G7, SHUFFLE, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-8-4", "12-bar blues in E", [
        explain("Twelve bars of blues", "Many blues songs follow one 12-bar plan. In E: four bars of E7, two of A7, "
                "two of E7, then one each of B7, A7, E7 and B7."),
        quiz("How many bars of E7 open the 12-bar blues?", ["Two", "Four", "Twelve"], 1),
        progression([(E7, 2), (A7, 2), (E7, 2), (A7, 2)], SHUFFLE, bpm=60),
        explain("The turnaround", "The last four bars move faster: B7, A7, E7, then B7, which turns you around "
                "to the top. Change early and keep the shuffle going."),
        progression(TWELVE_BAR[3:], SHUFFLE, bpm=60),
        progression(TWELVE_BAR, SHUFFLE, bpm=63),
        progression(TWELVE_BAR, SHUFFLE, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-8-5", "Sus chords", [
        explain("Suspended chords", "A sus chord swaps the note that makes it major or minor for a neighbor. "
                "It sounds open and unresolved until it settles home.", shape(Dsus4)),
        play_chord(Dsus4),
        listen("Which chord sounds settled?", [tones(Dsus4), tones(D)], FIRST_SECOND, 1),
        progression([(Dsus4, 1), (D, 1), (Dsus4, 1), (D, 1)], QUARTERS, bpm=66),
        explain("Dsus2 and Asus4", "Lift finger 2 off string 1 to get Dsus2. For Asus4, play A and add your little finger "
                "on string 2, fret 3.", shape(Dsus2)),
        play_chord(Dsus2),
        play_chord(Asus4),
        progression([(Asus4, 1), (A, 1), (Dsus2, 1), (D, 1)], QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-8-6", "Blues challenge", [
        explain("Sevenths, sus and shuffle", "No new ideas: seventh chords, sus chords and the 12-bar shuffle. "
                "Keep the long-short swing steady through every change."),
        listen("Which chord has the seventh?", [tones(A), tones(A7)], FIRST_SECOND, 1),
        quiz("Which chord uses all four fingers?", ["E7", "A7", "B7"], 2),
        strum(G7, QUARTERS, bpm=70, bars=2),
        progression([(Dsus4, 1), (D, 1), (Asus4, 1), (A, 1)], QUARTERS, bpm=70),
        progression(TWELVE_BAR, SHUFFLE, bpm=76),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 9. Power chords and riffs

UNIT_9 = unit("gtr-9", "Power chords and riffs", "Power chords, open and movable, palm muting and a riff of your own.", [
    lesson("gtr-9-1", "E5 and A5", [
        explain("Two notes, big sound", "A power chord plays only the root and the fifth, the note five letters up. "
                "Neither major nor minor, it stays punchy, even loud. E5 is the bottom of E minor.", shape(E5)),
        play_chord(E5),
        strum(E5, QUARTERS, bpm=72, bars=2),
        explain("A5: one string over", "Move the same two fingers to strings 4 and 3. With open string 5, that's A5. "
                "Aim your strum at strings 5, 4 and 3 only.", shape(A5)),
        play_chord(A5),
        quiz("Which notes make a power chord?", ["Root and third", "Three open strings", "Root and fifth"], 2),
        strum(A5, EIGHTHS, bpm=72, bars=2),
    ], minutes=4, xp=20),
    lesson("gtr-9-2", "Palm muting", [
        explain("Rest the edge of your hand", "Lay the outer edge of your picking hand on the strings, right where they meet "
                "the bridge. Strum, and the notes turn short and chunky."),
        strum(E5, EIGHTHS, bpm=76, bars=2),
        quiz("Where does your palm rest for palm muting?", ["Over the sound hole", "On the frets", "Near the neck", "Right at the bridge"], 3,
             "At the bridge the strings still sound, just shorter. Move forward and they go dead."),
        explain("Mute, then open", "Rock often builds with muted eighths, then lands on an open chord. "
                "Lift your palm for the big strum and let it ring."),
        strum(A5, EIGHTHS, bpm=76, bars=2),
        strum(E5, EIGHTHS, bpm=80, bars=4),
    ], minutes=4, xp=20),
    lesson("gtr-9-3", "Movable power chords", [
        explain("One shape, every chord", "Finger 1 on string 6, fret 3, then fingers 3 and 4 two frets higher on strings 5 "
                "and 4. That's G5. Slide it and the name follows the fret.", shape(G5)),
        play_chord(G5),
        quiz("Your root is on string 6, fret 5. Which power chord is it?", ["G5", "A5", "C5"], 1,
             "Count up string 6: E open, F at 1, G at 3, A at 5."),
        play_chord(A5_UP),
        explain("Root on string 5", "The same shape works from string 5. Finger 1 on string 5, fret 3 gives C5. "
                "Let the tip of finger 1 touch string 6 to keep it quiet.", shape(C5)),
        play_chord(C5),
        progression([(G5, 1), (A5_UP, 1), (C5, 1), (A5_UP, 1)], QUARTERS, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-9-4", "Your first riff", [
        explain("A riff is a hook", "A riff is a short, catchy phrase that repeats. This one bounces off open low E. "
                "Rest your palm at the bridge to keep it tight.",
                fretboard(G, [(6, 0), (6, 3, 2), (5, 0), (5, 2, 1), (5, 5, 4)])),
        notes(G, [("E2", 6), ("G2", 6), ("A2", 5)], hint="Open E, string 6 at fret 3, then open A.", first_fret=2),
        along(G, f"{RIFF_A} {RIFF_A}", bpm=66, title="First bar, twice", max_fret=7, first_fret=2),
        explain("Reach for fret 5", "The second bar climbs string 5: fret 2, then fret 5 with your little finger, "
                "then back to fret 2. Keep finger 1 parked near fret 2."),
        notes(G, [("B2", 5), ("D3", 5), ("B2", 5)], hint="String 5: fret 2, fret 5 with your little finger, fret 2 again.",
              max_fret=7, first_fret=2),
        along(G, f"{RIFF_B} {RIFF_B}", bpm=66, title="Second bar, twice", max_fret=7, first_fret=2),
        quiz("What makes a riff a riff?", ["It repeats", "It's played once", "It uses only chords"], 0),
        along(G, f"{RIFF} {RIFF}", bpm=72, title="The whole riff", max_fret=7, first_fret=2),
    ], minutes=5, xp=25),
    lesson("gtr-9-5", "Riffs and power chords", [
        explain("Answer the riff", "Songs often answer a riff with power chords. Play the riff, then hit the chords "
                "on one, the and of two, and four.", rhythm(PUSH)),
        along(G, RIFF, bpm=72, title="The riff", max_fret=7, first_fret=2),
        tap(PUSH, bpm=72, bars=2),
        strum(G5, PUSH, bpm=72, bars=2),
        quiz("Slide G5 up two frets. What do you get?", ["F5", "B5", "A5"], 2,
             "Two frets above G is A. The chord's name moves with its root."),
        progression([(G5, 1), (A5_UP, 1), (C5, 1), (A5_UP, 1)], PUSH, bpm=72),
        along(G, f"{RIFF} {RIFF}", bpm=76, title="Riff, up to speed", max_fret=7, first_fret=2),
    ], minutes=5, xp=25),
    lesson("gtr-9-6", "Riff challenge", [
        explain("Power and precision", "No new ideas: power chords, open and movable, palm muting and your riff. "
                "Lock in with the click and keep the mutes tight."),
        quiz("Your root is on string 5, fret 3. Which power chord is it?", ["C5", "D5", "B5"], 0,
             "String 5 counts up from A: B at 2, C at 3."),
        listen("Which one is a power chord?", [tones(E5), tones(E)], FIRST_SECOND, 0),
        progression([(E5, 1), (A5, 1), (E5, 1), (A5, 1)], EIGHTHS, bpm=84),
        progression([(G5, 1), (A5_UP, 1), (C5, 1), (A5_UP, 1)], PUSH, bpm=84),
        along(G, f"{RIFF} {RIFF}", bpm=84, title="The riff, full speed", max_fret=7, first_fret=2),
    ], minutes=5, xp=35, kind="challenge"),
])

# ================================================================ 10. Barre chords and the pentatonic

UNIT_10 = unit("gtr-10", "Barre chords and the pentatonic", "The F barre and B minor, the A minor pentatonic scale "
               "and your first solo.", [
    lesson("gtr-10-1", "On the way to F", [
        explain("Three steps to F", "Full barre chords take weeks, so build up to them. You know the mini F. "
                "Next comes a five-string F, then the full barre.", shape(F_MINI)),
        play_chord(F_MINI),
        explain("Add string 5", "Move finger 3 to string 5, fret 3, and put your little finger on string 4, fret 3. "
                "Five strings ring and the F sounds fuller.", shape(F_FIVE)),
        play_chord(F_FIVE),
        quiz("Barre chords feel hard at first. What helps most?", ["A few minutes every day", "Squeezing as hard as you can", "Skipping them for now"], 0,
             "Strength and feel build slowly. Short, daily practice beats one long, painful session."),
        strum(F_FIVE, QUARTERS, bpm=63, bars=2),
        progression([(C, 1), (F_FIVE, 1), (C, 1), (F_FIVE, 1)], QUARTERS, bpm=63),
    ], minutes=5, xp=25),
    lesson("gtr-10-2", "The full F barre", [
        explain("One finger, six strings", "Lay finger 1 flat across all six strings at fret 1. Fingers 2, 3 and 4 make "
                "an E shape in front of it. F is E moved up one fret.", shape(F_BARRE)),
        explain("Pull, don't squeeze", "Let your arm's weight pull the barre in, as if gently drawing the neck toward you. "
                "Your thumb only steadies. Roll finger 1 onto its side."),
        play_chord(F_BARRE),
        with_fingers(along(G, "F2@6:1 C3@5:1 F3@4:1 A3@3:1 C4@2:1 F4@1:3", bpm=60, title="F, string by string"),
                     [1, 3, 4, 2, 1, 1]),
        quiz("The F barre is which open shape, moved up a fret?", ["A minor", "D", "E"], 2),
        strum(F_BARRE, QUARTERS, bpm=60, bars=2),
        progression([(C, 1), (F_BARRE, 1), (C, 1), (F_BARRE, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-10-3", "B minor", [
        explain("B minor: barre at fret 2", "Finger 1 barres strings 1 to 5 at fret 2. Fingers 2, 3 and 4 build an A minor "
                "shape two frets higher. Skip string 6.", shape(Bm)),
        explain("An easier B minor", "Not ready to barre? Play the top four strings only: fret 4 on strings 4 and 3, "
                "fret 3 on string 2, fret 2 on string 1.", shape(Bm_EASY)),
        play_chord(Bm_EASY),
        play_chord(Bm),
        listen("Major or minor?", [tones(Bm)], MAJOR_MINOR, 1),
        quiz("Which chord is E moved up one fret with a barre?", ["G", "Bm", "F"], 2),
        strum(Bm, QUARTERS, bpm=60, bars=2),
        progression([(D, 1), (Bm, 1), (G_MAJ, 1), (A, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-10-4", "The A minor pentatonic", [
        explain("Five notes for soloing", "The minor pentatonic scale has five notes. In A minor they're A, C, D, E and G. "
                "It's the sound of countless blues and rock solos."),
        explain("Box 1 at fret 5", "Finger 1 covers fret 5 on every string. Fingers 3 and 4 take frets 7 and 8. "
                "Two notes per string, one finger per fret.", fretboard(G, BOX_DOTS, frets=4, start=5)),
        notes(G, [("A2", 6), ("C3", 6), ("D3", 5), ("E3", 5)], hint="Fret 5, fret 8 on string 6, then fret 5, fret 7 on string 5.",
              max_fret=8, first_fret=5),
        along(G, BOX_LOW, bpm=60, title="Strings 6 and 5", max_fret=8, first_fret=5),
        quiz("Which notes are in A minor pentatonic?", ["A B C D E", "A C E G B", "A B D E G", "A C D E G"], 3),
        along(G, BOX_MID, bpm=60, title="Strings 4 and 3", max_fret=8, first_fret=5),
        along(G, BOX_TOP, bpm=60, title="Strings 2 and 1", max_fret=8, first_fret=5),
        along(G, BOX, bpm=63, title="Box 1, up and down", max_fret=8, first_fret=5),
    ], minutes=5, xp=25),
    lesson("gtr-10-5", "Your first solo", [
        explain("Phrase like you speak", "A solo is a melody built from short phrases. Play a few notes, leave a gap, "
                "then answer. Ending on A, the root, sounds like a full stop."),
        along(G, SOLO_Q.replace("E4@2:3 r:1", "E4@2:4"), bpm=63, title="The question", max_fret=8, first_fret=5),
        along(G, SOLO_A, bpm=63, title="The answer", max_fret=8, first_fret=5),
        quiz("Which note sounds most like a full stop in A minor?", ["A", "D", "G"], 0,
             "A is the root, the home of A minor. Ending a phrase on it sounds finished."),
        listen("Does this end at home?", [["E4"], ["D4"], ["C4"], ["A3"]], HOME, 0),
        along(G, SOLO, bpm=66, title="Your first solo", max_fret=8, first_fret=5),
    ], minutes=5, xp=25),
    lesson("gtr-10-6", "Final challenge", [
        explain("Everything together", "No new ideas: barre chords, B minor, the pentatonic box and your solo. "
                "Breathe, keep the beat, and play it like you mean it."),
        quiz("Which finger covers fret 5 in box 1?", ["Finger 3", "Finger 1", "Finger 4"], 1),
        progression([(Am, 1), (F_BARRE, 1), (C, 1), (G_MAJ, 1)], QUARTERS, bpm=66),
        progression([(D, 1), (Bm, 1), (G_MAJ, 1), (A, 1)], QUARTERS, bpm=66),
        listen("Major or minor?", [tones(F_BARRE)], MAJOR_MINOR, 0),
        along(G, BOX, bpm=72, title="Box 1, up and down", max_fret=8, first_fret=5),
        along(G, SOLO, bpm=72, title="Your solo, with feeling", max_fret=8, first_fret=5),
    ], minutes=6, xp=40, kind="challenge"),
])

# Units 11–16 live in guitar_part2.py and units 17–22 in guitar_part3.py; both import the shapes, rhythms and shared
# text above (so this stays last).
try:
    from courses.guitar_part2 import UNITS as PART_2
except ModuleNotFoundError as missing:
    if missing.name != "courses.guitar_part2":
        raise
    PART_2 = []
try:
    from courses.guitar_part3 import UNITS as PART_3
except ModuleNotFoundError as missing:
    if missing.name != "courses.guitar_part3":
        raise
    PART_3 = []

COURSE = course("guitar", "Guitar", "From your first note to fingerstyle, blues and lead", "guitar.acoustic.6", "guitars", "mint", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6, UNIT_7, UNIT_8, UNIT_9, UNIT_10, *PART_2, *PART_3,
])
