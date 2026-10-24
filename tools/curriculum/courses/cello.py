"""Cello: from the first bow stroke to fourth position and The Swan, with every fingered note checked for intonation.

The cello is fretless: a "fret" is the number of half steps above the open string, and the fretboard
visuals draw it as tape marks. In first position each finger owns one half step, starting a whole step
above the open string (1 = 2, 2 = 3, 3 = 4, 4 = 5 half steps up), which is exactly lib's first_fret
numbering. Fourth position moves the same hand frame up so first finger sits five half steps up.
Notes a half step outside the frame need an extension; this course chooses keys that avoid them.
"""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, quiz, rhythm, staff, tap, unit
from songbook import Part, song
import tunes

C = "cello"
FIRST, FOURTH = 2, 5  # where first finger falls, in half steps above the open string


def play(seq, hint=None, pos=FIRST):
    """Hold notes in tune at your own pace. seq: note, (note, string) or (note, string, finger) when a line
    mixes positions (a shift)."""
    items = [i if isinstance(i, tuple) else (i, None) for i in seq]
    step = notes(C, [i[:2] for i in items], hint, max_fret=4 if pos == FIRST else 8, first_fret=pos)
    return _override(step, [i[2] if len(i) > 2 else None for i in items])


def tune(melody, bpm, beats_per_bar=4, title=None, pos=FIRST):
    """Play along. "|" marks bar lines for readability; "D4~1" overrides the finger where a line shifts."""
    tokens, fingers = [], []
    for token in melody.split():
        if token == "|":
            continue
        note, colon, length = token.partition(":")
        note, _, finger = note.partition("~")
        tokens.append(note + colon + length)
        if note.lower() != "r":
            fingers.append(int(finger) if finger else None)
    step = along(C, " ".join(tokens), bpm, beats_per_bar, title, max_fret=4 if pos == FIRST else 8, first_fret=pos)
    return _override(step, fingers)


def _override(step, fingers):
    for n, g in zip(step["notes"], fingers):
        if g and n["at"]["f"]:
            n["at"]["g"] = g
    return step


def board(dots):
    return fretboard(C, dots, frets=6)


def bass(notes_):
    return staff(notes_, clef="bass")


# Shared wording: identical sentences are translated once (several also appear in the violin course).
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
FRAME = [(2, 2, 1), (2, 3, 2), (2, 4, 3), (2, 5, 4)]
D_MAJOR = ["D3", "E3", "F#3", "G3", "A3", "B3", "C#4", "D4"]
G_MAJOR = ["G2", "A2", "B2", "C3", "D3", "E3", "F#3", "G3"]
C_LOW = ["C2", "D2", "E2", "F2", "G2", "A2", "B2", "C3"]

# Tunes (public domain or traditional). Bars are 4 beats unless noted.
TWINKLE_1 = "D3 D3 A3 A3 | B3 B3 A3:2 | G3 G3 F#3 F#3 | E3 E3 D3:2"
TWINKLE_2 = "A3 A3 G3 G3 | F#3 F#3 E3:2 | A3 A3 G3 G3 | F#3 F#3 E3:2"
LIGHTLY_A = "A3 F#3 F#3:2 | G3 E3 E3:2 | D3 E3 F#3 G3 | A3 A3 A3:2"
LIGHTLY_B = "E3 E3 E3 E3 | E3 F#3 G3:2 | F#3 F#3 F#3 F#3 | F#3 G3 A3:2"
LIGHTLY_END = "A3 F#3 F#3:2 | G3 E3 E3:2 | D3 F#3 A3 A3 | D3:4"
ODE_1 = "E2 E2 F2 G2 | G2 F2 E2 D2 | C2 C2 D2 E2 | E2:1.5 D2:0.5 D2:2"
ODE_2 = "E2 E2 F2 G2 | G2 F2 E2 D2 | C2 C2 D2 E2 | D2:1.5 C2:0.5 C2:2"
ODE_UP = ("E3 E3 F3 G3 | G3 F3 E3 D3 | C3 C3 D3 E3 | E3:1.5 D3:0.5 D3:2 | "
          "E3 E3 F3 G3 | G3 F3 E3 D3 | C3 C3 D3 E3 | D3:1.5 C3:0.5 C3:2")
# Brahms, Wiegenlied Op. 49 No. 4 (1868), 3/4, with a two-beat rest before the pickup.
LULLABY_1 = ("r:2 B2:0.5 B2:0.5 | D3:2 B2:0.5 B2:0.5 | D3:2 B2:0.5 D3:0.5 | G3 F#3:1.5 E3:0.5 | "
             "E3 D3 A2:0.5 B2:0.5 | C3 A2 A2:0.5 B2:0.5 | C3:2 A2:0.5 C3:0.5 | F#3:0.5 E3:0.5 D3 F#3 | G3:2")
LULLABY_2 = ("G2:0.5 G2:0.5 | G3:2 E3:0.5 C3:0.5 | D3:2 B2:0.5 G2:0.5 | C3 D3 E3 | D3:2 G2:0.5 G2:0.5 | "
             "G3:2 E3:0.5 C3:0.5 | D3:2 B2:0.5 G2:0.5 | C3 B2 A2 | G2:3")
MOON_A = "C3 C3 C3 D3 | E3:2 D3:2 | C3 E3 D3 D3 | C3:4"
MOON_B = "D3 D3 D3 D3 | A2:2 A2:2 | D3 C3 B2 A2 | G2:4"
# Saint-Saëns, Le cygne (1886): opening phrase an octave below the original, rhythm simplified, 6/4.
SWAN = "G3:3 F#3 B2:2 | E3:3 D3 G2:2 | A2:5 B2 | C3:6"
# Amazing Grace (New Britain), 3/4. The high D after the open A shifts to fourth position (first finger),
# then the hand returns to first position for the rest.
GRACE_1 = "r:2 D3 | G3:2 B3:0.5 G3:0.5 | B3:2 A3 | G3:2 E3 | D3:2 D3 | G3:2 B3:0.5 G3:0.5 | B3:2 A3 | D4~1:5 B3"
GRACE_2 = "D4:2 B3:0.5 G3:0.5 | B3:2 A3 | G3:2 E3 | D3:2 D3 | G3:2 B3:0.5 G3:0.5 | B3:2 A3 | G3:3"
UP_AND_BACK_4 = "A3@1 B3 D4 E4 | F4 E4 D4:2 | D4 B3 A3@1:2 | A3@1:4"

# ---------------------------------------------------------------- whole songs (songbook)
# Each song lesson ends on its whole song, in first position (fourth position only where its unit shifts). Songs
# with public-domain words carry them; Brahms and Saint-Saëns stay instrumental. Chart shapes are the chord's notes
# on the four strings, C string first.
SHAPES = {c["name"]: c for c in [
    chord(C, "D", "2x00"), chord(C, "A", "x224"), chord(C, "A7", "x254"), chord(C, "G", "x002"), chord(C, "C", "0023"),
    chord(C, "F", "5233"), chord(C, "Am", "x223"), chord(C, "Em", "x022"), chord(C, "D7", "0x00"), chord(C, "G7", "x032"),
]}
THE_VERSE = "The verse"


def bars(melody):
    """A melody with its "|" bar marks dropped, for songbook."""
    return " ".join(melody.replace("|", " ").split())


def cello_song(bpm, parts, beats_per_bar=4, words=None):
    return song(C, bpm, parts, beats_per_bar=beats_per_bar, shapes=SHAPES, words=words, max_fret=4, first_fret=FIRST)


# Twinkle, unit 3: D and A strings. Jane Taylor's verses, the refrain, and a first variation.
C_TW_A, C_TW_B = tunes.transpose(tunes.TWINKLE_A, -10), tunes.transpose(tunes.TWINKLE_B, -10)
C_TW_CA, C_TW_CB = tunes.transpose_chords(tunes.TWINKLE_CHORDS_A, 2), tunes.transpose_chords(tunes.TWINKLE_CHORDS_B, 2)
C_TW_V = Part("Verse 1", "verse", f"{C_TW_A} {C_TW_B}", chords=f"{C_TW_CA} {C_TW_CB}", lyrics=tunes.TWINKLE_WORDS_1)
C_TW_C = Part("Chorus", "chorus", C_TW_A, chords=C_TW_CA, lyrics=tunes.TWINKLE_REFRAIN)
TWINKLE_SONG = cello_song(72, [
    Part("Intro", "intro", "G3 G3 F#3 F#3 E3 E3 D3:2", chords="G,D A,D"),
    C_TW_V, C_TW_C,
    Part("Variation 1", "solo", tunes.doubled(C_TW_A), chords=C_TW_CA),
    C_TW_V.with_lyrics("Verse 2", tunes.TWINKLE_WORDS_2), C_TW_C,
    C_TW_V.with_lyrics("Verse 3", tunes.TWINKLE_WORDS_3), C_TW_C,
    Part("Outro", "outro", "F#3 F#3 E3 E3 D3:4", chords="D,A D"),
], words=tunes.TWINKLE_CREDIT)

# Lightly Row, unit 3: both verses of the English words, a variation between them.
LIGHTLY_TUNE = bars(" ".join([LIGHTLY_A, LIGHTLY_END, LIGHTLY_B, LIGHTLY_END]))
LIGHTLY_CHART = "D A7 D D D A7 D D A7 A7 D D D A7 D D"
LIGHTLY_V = Part("Verse 1", "verse", LIGHTLY_TUNE, chords=LIGHTLY_CHART, lyrics=tunes.LIGHTLY_WORDS_1)
LIGHTLY_SONG = cello_song(76, [
    Part("Intro", "intro", "D3 F#3 A3 A3 D3:4", chords="D D"),
    LIGHTLY_V,
    Part("Variation 1", "solo", tunes.doubled(bars(f"{LIGHTLY_A} {LIGHTLY_END}")), chords="D A7 D D D A7 D D"),
    LIGHTLY_V.with_lyrics("Verse 2", tunes.LIGHTLY_WORDS_2),
    Part("Outro", "outro", "D3 F#3 A3 A3 D3:4", chords="D D"),
], words=tunes.LIGHTLY_CREDIT)

# Ode to Joy, unit 4: the first verse low on the C and G strings, the second an octave up on G and D. The low
# middle section ends on the open G (the G below is under the C string).
O_LOW = tunes.ode(-24, low_g="G2")
O_UP = tunes.ode(-12)
ODE_LOW = Part("Verse 1", "verse", f"{O_LOW[0]} {O_LOW[1]} {O_LOW[2]} {O_LOW[1]}", chords=tunes.ODE_CHORDS, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = cello_song(72, [
    Part("Intro", "intro", O_LOW[3], chords="C G,C"),
    ODE_LOW,
    Part("Solo", "solo", f"{O_UP[0]} {O_UP[1]}", chords=f"{tunes.ODE_CHORDS_A1} {tunes.ODE_CHORDS_A2}"),
    Part("Verse 2", "verse", f"{O_UP[0]} {O_UP[1]} {O_UP[2]} {O_UP[1]}", chords=tunes.ODE_CHORDS, lyrics=tunes.ODE_WORDS_2),
    Part("Outro", "outro", O_UP[1], chords=tunes.ODE_CHORDS_A2, lyrics=tunes.ODE_WORDS_END),
], words=tunes.ODE_CREDIT)

# Brahms' Lullaby (Wiegenlied, 1868), unit 4: both halves twice, rocking G-string arpeggios between them.
LULLABY_A = Part("Part A", "verse", bars(LULLABY_1).replace("r:2 ", "", 1).rsplit(" ", 1)[0] + " G3:3", pickup=1,
                 chords="G G G C,D7 D7 D7 D7 G")
LULLABY_B = Part("Part B", "chorus", bars(LULLABY_2), pickup=1, chords="C G D7 G C G D7 G")
LULLABY_SONG = cello_song(72, [
    Part("Intro", "intro", "C3 B2 A2 G2:3", chords="D7 G"),
    LULLABY_A, LULLABY_B,
    Part("Interlude", "interlude", "G2 B2 D3 G3:3 C3 E3 G3 D3:3", chords="G G C D7"),
    LULLABY_A, LULLABY_B,
    Part("Outro", "outro", "D3:3 G2:3", chords="D7 G"),
], beats_per_bar=3)

# Au clair de la lune, unit 4: two verses of the French words (18th century), the tune alone between them.
MOON_TUNE = bars(" ".join([MOON_A, MOON_A, MOON_B, MOON_A]))
MOON_CHART_A = "C C,G C,G C"
MOON_CHART_B = "G D G,D7 G"
MOON_V = Part("Verse 1", "verse", MOON_TUNE, chords=f"{MOON_CHART_A} {MOON_CHART_A} {MOON_CHART_B} {MOON_CHART_A}", lyrics=(
    "Au clair de la lu-ne, / mon a-mi Pier-rot, / prê-te-moi ta plu-me / pour é-crire un mot. / "
    "Ma chan-delle est mor-te, / je n'ai plus de feu; / ou-vre-moi ta por-te / pour l'a-mour de Dieu."))
MOON_SONG = cello_song(80, [
    Part("Intro", "intro", "C3 E3 D3 D3 C3:4", chords="C,G C"),
    MOON_V,
    Part("Solo", "solo", bars(f"{MOON_B} {MOON_A}"), chords=f"{MOON_CHART_B} {MOON_CHART_A}"),
    MOON_V.with_lyrics("Verse 2", "Au clair de la lu-ne, / Pier-rot ré-pon-dit: / je n'ai pas de plu-me, / je suis dans mon lit. / "
                                  "Va chez la voi-si-ne, / je crois qu'elle y est, / car dans sa cui-si-ne / on bat le bri-quet."),
    Part("Outro", "outro", "C3 E3 D3 D3 C3:4", chords="C,G C"),
], words="Traditional (France, 18th century)")

# The Swan (Saint-Saëns, 1886), unit 5: its opening phrase twice, each answered and closed, over rippling broken
# chords like the piano's. Slow bows; every note in first position.
RIPPLE_G = "G2 D3 G3 B3 G3 D3"
SWAN_ANSWER = "B3:3 A3 D3:2 G3:3 F#3 B2:2 C3:3 A2 D3:2 G2:6"
SWAN_SONG = cello_song(72, [
    Part("Intro", "intro", f"{RIPPLE_G} {RIPPLE_G}", chords="G G"),
    Part("Theme", "verse", bars(SWAN), chords="G Em Am C"),
    Part("Part B", "chorus", SWAN_ANSWER, chords="G Em D7 G"),
    Part("Interlude", "interlude", "C2 G2 E3 G3 E3 G2 D2 A2 F#3 A3 F#3 A2", chords="C D"),
    Part("Theme", "verse", bars(SWAN), chords="G Em Am C"),
    Part("Coda", "outro", "B3:3 A3 D3:2 E3:3 D3 G2:2 A2:3 D3:3 G2:6", chords="G C D7 G"),
], beats_per_bar=6)

# Amazing Grace, unit 5: in G; the high D after the open A is a shift to fourth position, first finger, as the
# lesson teaches. Three of Newton's verses and a solo.
VC_AMAZING = f"{tunes.AMAZING_LINE_1.replace('D4:5', 'D4~1:5')} {tunes.AMAZING_LINE_2}"
VC_AMAZING_V = Part("Verse 1", "verse", VC_AMAZING, pickup=1, chords=tunes.AMAZING_CHORDS, lyrics=tunes.AMAZING_WORDS_1)
AMAZING_SONG = cello_song(76, [
    Part("Intro", "intro", "G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:3 G3:3", chords="G G,D7 G G"),
    VC_AMAZING_V,
    VC_AMAZING_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    VC_AMAZING_V.instrumental("Solo"),
    VC_AMAZING_V.with_lyrics("Verse 3", tunes.AMAZING_WORDS_3),
    Part("Outro", "outro", tunes.AMAZING_TAIL, pickup=1, chords=tunes.AMAZING_TAIL_CHORDS, lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, words=tunes.AMAZING_CREDIT)


UNIT_1 = unit("vc-1", "Hello, cello", "Sit, set the endpin, hold the bow and play the four open strings.", [
    lesson("vc-1-1", "Meet your cello", [
        explain("Four strings, low to high",
                "From low to high the strings are C, G, D and A. C is the thickest and lowest. A is the thinnest "
                "and highest, and we call it string 1.",
                part("strings")),
        explain("The bridge", BRIDGE, part("bridge")),
        quiz("Which string is the lowest?", ["C", "A", "D", "G"], 0,
             "C is the thickest string and the lowest. Strings count from A (1) to C (4)."),
        explain("Pluck first", PLUCK),
        play([("A3", 1)], hint="Pluck string 1, the A, and let it ring."),
        play([("D3", 2)], hint="Now string 2, the D."),
        play([("C2", 4)], hint="Now the thickest string, the C. Let it rumble."),
    ]),
    lesson("vc-1-2", "Sit with your cello", [
        explain("Sit tall, near the edge",
                "Sit near the front edge of a chair, feet flat and knees apart, as if you could stand up easily. "
                "The cello rests between your knees."),
        explain("Set the endpin",
                "Pull out the endpin until the cello's top edge meets your chest at the breastbone and the C peg "
                "sits near your left ear. Tighten the screw. A rest or strap keeps it from sliding.",
                part("head")),
        quiz("Where does the top edge of the cello touch you?", ["Your chest, at the breastbone", "Your left shoulder", "Under your chin"], 0,
             "The cello leans back against your chest, and your knees steady it lightly from the sides."),
        play([("D3", 2), ("G2", 3)], hint="Sitting tall, pluck D, then G. Keep your shoulders loose."),
        listen("Which is lower?", [["G2"], ["D3"]], WHICH, 0),
        tune("A3:2 A3:2 D3:2 D3:2 | G2:2 G2:2 C2:4", bpm=60, title="Pluck along"),
    ]),
    lesson("vc-1-3", "Hold the bow", [
        explain("Parts of the bow", BOW_PARTS),
        explain("A round, heavy hand",
                "Bend your thumb and set its tip where the frog meets the stick, across from your middle finger. "
                "Drape all four fingers over the stick and let the hand hang heavy."),
        quiz("Where does your thumb go?",
             ["Bent, where the frog meets the stick", "Straight, under the hair", "Flat on top of the stick"], 0,
             "A bent thumb at the frog lets the hand stay soft and balance the bow."),
        explain("Rosin makes it sing", ROSIN),
        play([("D3", 2)], hint="Set the bow on the D string, halfway between bridge and fingerboard. Pull it slowly to the right."),
        play([("A3", 1)], hint="Now the A string. Move your whole arm to its level, then pull slowly."),
        tune("D3:4 D3:4 A3:4 A3:4", bpm=60, title="Long bows"),
    ]),
    lesson("vc-1-4", "The open strings", [
        explain("C G D A",
                "From low to high: C, G, D, A. Each string is five letter names above the last, an interval called "
                "a fifth. Try: Cats Go Dancing Around.",
                board([(4, 0), (3, 0), (2, 0), (1, 0)])),
        explain("One level per string",
                "Your right arm sets which string the bow plays. Each string has its own arm level, like the steps "
                "of a stair. Move the whole arm, not just the hand."),
        play([("C2", 4), ("G2", 3)], hint="Bow the C string, then G. Let your arm settle at each level."),
        play([("D3", 2), ("A3", 1)], hint="Now D, then A."),
        quiz("Which string is string 1?", ["A", "C", "D", "G"], 0, visual=board([(1, 0)])),
        listen("Which is higher?", [["C2"], ["A3"]], WHICH, 1),
        tune("C2:4 G2:4 D3:4 A3:4", bpm=60, title="Open-string roll call"),
    ]),
    lesson("vc-1-5", "Tune your cello", [
        explain("Tune A first",
                "Orchestras tune to A. Timbre shows how far each string is from its note in cents; 100 cents make "
                "a half step, the smallest step on a piano. Tune A, then D, G and C.",
                part("strings")),
        explain("Fine tuners for small moves", FINE_TUNERS, part("bridge")),
        quiz("A string is a little flat. What do you do?",
             ["Turn its fine tuner clockwise", "Turn its fine tuner counterclockwise", "Push on the bridge"], 0,
             "Flat means too low. Clockwise tightens the string and raises the pitch."),
        explain("Pegs for big moves", PEGS, part("head")),
        play([("A3", 1)], hint="Tune your A string, then bow it and hold it steady."),
        play([("D3", 2), ("G2", 3), ("C2", 4)], hint="Now D, G and C. Tune each one, then bow it and hold it."),
    ]),
    lesson("vc-1-6", "Open-string checkup", [
        explain("Check your setup",
                "Sit tall with the endpin set, soft bow hold, bow halfway between bridge and fingerboard. Now play "
                "everything from this unit."),
        quiz("Which string is string 3?", ["G", "D", "C", "A"], 0, visual=board([(3, 0)])),
        play([("A3", 1), ("D3", 2), ("G2", 3), ("C2", 4)], hint="Bow each open string from high to low. Hold each one steady."),
        listen("Which is lower?", [["D3"], ["G2"]], WHICH, 1),
        quiz("Which string do you tune first?", ["A", "C", "G", "D"], 0,
             "Orchestras tune to A, so start there and tune the others after it."),
        tune("D3:2 D3:2 A3:2 A3:2 | G2:2 G2:2 D3:4 | C2:2 C2:2 G2:2 G2:2 | D3:4", bpm=60, title="Up and down the stairs"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_2 = unit("vc-2", "Bowing", "Long, even bows, clean string crossings and your first rhythms.", [
    lesson("vc-2-1", "Down-bow, up-bow", [
        explain("Two directions", TWO_DIRECTIONS),
        quiz("Which way does a down-bow move?", ["From frog toward tip", "From tip toward frog", "Toward the bridge"], 0),
        explain("The contact point", CONTACT),
        play([("D3", 2), ("D3", 2)], hint="One slow down-bow, then one slow up-bow on D. Keep the sound even to the end."),
        tune("D3:4 D3:4 D3:4 D3:4", bpm=60, title="Whole bows on D"),
        tune("A3:4 A3:4 G2:4 G2:4 | C2:4 C2:4 D3:4 D3:4", bpm=60, title="Whole bows on every string"),
    ]),
    lesson("vc-2-2", "Quarter notes, half notes", [
        explain("Quarter notes, half bows",
                "A quarter note lasts one beat. Quick notes need less bow, so use the middle half of the bow and "
                "keep every stroke the same length.",
                rhythm([0, 1, 2, 3])),
        tap([0, 1, 2, 3], bpm=70, bars=2),
        tune("D3 D3 D3 D3 | A3 A3 A3 A3 | D3 D3 D3 D3 | A3:4", bpm=70, title="Quarters on D and A"),
        explain("Half notes, slower bows",
                "A half note lasts two beats. Use a longer, slower bow so the sound doesn't fade on the second beat.",
                rhythm([0, 1, 2])),
        tap([0, 1, 2], bpm=70, bars=2),
        quiz("Which note needs more bow?", ["A half note", "A quarter note", "They need the same"], 0,
             "A half note lasts twice as long, so it gets a longer, slower stroke."),
        tune("D3 D3 D3:2 | G2 G2 G2:2 | C2 C2 C2:2 | D3:4", bpm=70, title="Short, short, long"),
    ]),
    lesson("vc-2-3", "String crossings", [
        explain("Move from the elbow", CROSSING),
        play([("D3", 2), ("A3", 1), ("D3", 2), ("A3", 1)], hint="D, A, D, A. Let your arm rock between the two levels."),
        tune("D3:2 A3:2 D3:2 A3:2 | G2:2 D3:2 G2:2 D3:2", bpm=66, title="Rocking between strings"),
        quiz("What moves the bow to a new string?", ["Your arm, changing levels", "Your fingers, squeezing", "Turning the cello"], 0),
        explain("Skipping a string",
                "Going from C to D skips the G string, so your arm makes a bigger move. Travel smoothly and don't "
                "let the middle string sound."),
        tune("C2:2 G2:2 D3:2 A3:2 | D3:2 G2:2 C2:4 | C2:2 D3:2 G2:2 A3:2 | G2:2 D3:2 C2:4", bpm=60,
             title="All four, up and back"),
    ]),
    lesson("vc-2-4", "Eighth notes", [
        explain("Two notes per beat",
                "An eighth note lasts half a beat, so two fit in each beat. Use small, quick bows near the middle of "
                "the bow.",
                rhythm([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])),
        tap([0, 0.5, 1, 1.5, 2, 3], bpm=66, bars=2),
        tune("D3:0.5 D3:0.5 D3:0.5 D3:0.5 D3 D3 | A3:0.5 A3:0.5 A3:0.5 A3:0.5 A3 A3 | "
             "D3:0.5 D3:0.5 D3:0.5 D3:0.5 D3 D3 | D3:4", bpm=66, title="Quick-quick, slow"),
        quiz("How many eighth notes fit in one beat?", ["Two", "One", "Four"], 0),
        explain("Long, short-short",
                "Now mix them: a quarter, two eighths, then two quarters. Fiddlers lean on this rhythm. Say it "
                "first: long, short-short, long, long.",
                rhythm([0, 1, 1.5, 2, 3])),
        tap([0, 1, 1.5, 2, 3], bpm=66, bars=2),
        tune("D3 D3:0.5 D3:0.5 D3 D3 | A3 A3:0.5 A3:0.5 A3 A3 | G2 G2:0.5 G2:0.5 G2 G2 | D3:4", bpm=66,
             title="Long, short-short"),
    ]),
    lesson("vc-2-5", "Bowing checkup", [
        explain("Bows and rhythms",
                "Straight bows at the contact point, crossings led by the elbow, and steady rhythms. Here's a mix of "
                "all three."),
        tap([0, 1, 1.5, 2, 3], bpm=70, bars=2),
        quiz("Where is the contact point?",
             ["Halfway between bridge and fingerboard", "Right on top of the bridge", "Over the end of the fingerboard"], 0),
        tune("C2:2 G2:2 D3:2 A3:2 | A3 A3 D3 D3 | G2 G2 C2:2", bpm=66, title="Crossings warm-up"),
        quiz("How long does a half note last?", ["Two beats", "One beat", "Half a beat"], 0),
        tune("D3 D3:0.5 D3:0.5 D3 D3 | G2 G2:0.5 G2:0.5 G2 G2 | A3:0.5 A3:0.5 A3:0.5 A3:0.5 D3 D3 | D3:4", bpm=70,
             title="Open-string groove"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_3 = unit("vc-3", "First position: D and A", "One finger per half step: play D major and your first melodies.", [
    lesson("vc-3-1", "First finger: E", [
        explain("No frets, only ears", NO_FRETS, board(FRAME)),
        explain("One finger per half step",
                "A half step is the smallest step in music. In first position your fingers sit a half step apart, "
                "starting a whole step (two half steps) above the open string. Thumb behind the neck, across from "
                "second finger.",
                board(FRAME)),
        play([("D3", 2), ("E3", 2)], hint="Open D, then E with your first finger. Hold E until it settles in tune."),
        explain("Sharp or flat? Move", NUDGE),
        play([("A3", 1), ("B3", 1)], hint="Same finger on the A string: open A, then B."),
        listen("Open D, then E. How far apart?", [["D3"], ["E3"]], STEPS, 0),
        tune("D3:2 E3:2 D3:2 E3:2 | A3:2 B3:2 A3:4", bpm=60, title="First finger on D and A"),
    ]),
    lesson("vc-3-2", "Third finger: F sharp", [
        explain("Skip a finger",
                "Third finger plays F sharp, a whole step above E. Let second finger hover over its spot between 1 "
                "and 3, so your hand keeps its shape.",
                board([(2, 2, 1), (2, 4, 3)])),
        play([("D3", 2), ("E3", 2), ("F#3", 2)], hint="D, E, F sharp. Keep first finger down while third plays."),
        listen("From E to the next note: what kind of step?", [["E3"], ["F#3"]], STEPS, 0),
        quiz("Why does second finger stay over its spot?", ["It keeps the hand's spacing", "It plays F sharp", "It holds the cello up"], 0,
             "Each finger owns a half step. Keeping all four in place makes every note land in the same spot each time."),
        play([("A3", 1), ("B3", 1), ("C#4", 1)], hint="Same fingers on the A string: open A, B, C sharp."),
        tune("D3 E3 F#3:2 | F#3 E3 D3:2 | A3 B3 C#4:2 | C#4 B3 A3:2", bpm=66, title="Up and back"),
    ]),
    lesson("vc-3-3", "Fourth finger: G", [
        explain("All four fingers",
                "Fourth finger plays G, a half step above F sharp. D, E, F sharp, G is the first half of the D "
                "major scale: open, 1, 3, 4.",
                board([(2, 2, 1), (2, 4, 3), (2, 5, 4)])),
        play([("D3", 2), ("E3", 2), ("F#3", 2), ("G3", 2)], hint="D, E, F sharp, G: open, 1, 3, 4."),
        explain("G rings with G",
                "Fourth-finger G on the D string is an octave above the open G string: the same letter, eight notes "
                "higher. When it's in tune, the G string hums along."),
        play([("G3", 2), ("G2", 3), ("G3", 2)], hint="Fourth-finger G, open G, then fourth-finger G again. Listen for the ring."),
        listen("Same letter name?", [["G2"], ["G3"]], SAME_LETTER, 0),
        tune("D3 E3 F#3 G3 | G3 F#3 E3 D3 | D3:2 G3:2 | D3:4", bpm=66, title="D string scale"),
    ]),
    lesson("vc-3-4", "The D major scale", [
        explain("D to D",
                "Play D, E, F sharp, G on the D string, then A, B, C sharp, D on the A string. The same fingers "
                "twice: open, 1, 3, 4.",
                bass(D_MAJOR)),
        play(D_MAJOR, hint="Up the D major scale. Cross to the A string on the fifth note."),
        listen("Up or down?", [["D4"], ["C#4"], ["B3"], ["A3"]], ["Going up", "Going down"], 1),
        quiz("Which fingers play D major on each string?", ["Open, 1, 3, 4", "Open, 1, 2, 3", "Open, 2, 3, 4"], 0),
        tune("D3 E3 F#3 G3 | A3 B3 C#4 D4 | D4 C#4 B3 A3 | G3 F#3 E3 D3", bpm=66, title="D major scale"),
        tune("D3 D3:0.5 D3:0.5 E3 E3:0.5 E3:0.5 | F#3 F#3:0.5 F#3:0.5 G3 G3:0.5 G3:0.5 | "
             "A3 A3:0.5 A3:0.5 B3 B3:0.5 B3:0.5 | C#4 C#4:0.5 C#4:0.5 D4:2", bpm=60, title="Scale in long, short-short"),
    ]),
    lesson("vc-3-5", "Twinkle, Twinkle, Little Star", [
        explain("A tune you know",
                "This French melody from the 1700s uses only notes you've learned: D, E, F sharp, G on the D "
                "string, and A and B on the A string.",
                bass(["D3", "D3", "A3", "A3", "B3", "B3", "A3"])),
        tune(TWINKLE_1, bpm=66, title="Opening line"),
        tune(TWINKLE_2, bpm=66, title="Middle line"),
        listen("Which line is this?", [["A3"], ["A3"], ["G3"], ["G3"], ["F#3"], ["F#3"], ["E3"]],
               ["The middle line", "The opening line"], 0),
        quiz("Which finger plays B on the A string?", ["First", "Second", "Third"], 0),
        tune(" ".join([TWINKLE_1, TWINKLE_2, TWINKLE_1]), bpm=72, title="Twinkle, Twinkle, Little Star"),
        TWINKLE_SONG.take("Twinkle, Twinkle, Little Star"),
    ], minutes=TWINKLE_SONG.minutes(), xp=30, kind="song", arrangement=TWINKLE_SONG.meta()),
    lesson("vc-3-6", "Lightly Row", [
        explain("A German folk song", FOLK_LIGHTLY, bass(["A3", "F#3", "F#3", "G3", "E3", "E3"])),
        tune(LIGHTLY_A + " " + LIGHTLY_END, bpm=66, title="First part"),
        quiz("Which finger plays the F sharps?", ["Third, on the D string", "Second, on the D string", "First, on the A string"], 0),
        tune(LIGHTLY_B + " " + LIGHTLY_END, bpm=66, title="Second part"),
        tune(" ".join([LIGHTLY_A, LIGHTLY_END, LIGHTLY_B, LIGHTLY_END]), bpm=76, title="Lightly Row"),
        LIGHTLY_SONG.take("Lightly Row"),
    ], minutes=LIGHTLY_SONG.minutes(), xp=30, kind="song", arrangement=LIGHTLY_SONG.meta()),
    lesson("vc-3-7", "D and A checkup", [
        explain("Keep the frame",
                "Open, 1, 3, 4 on the D and A strings. Keep the hand's shape, land each note in tune, and let the "
                "octaves ring."),
        listen("Third finger to fourth: what kind of step?", [["F#3"], ["G3"]], ["A half step", "A whole step"], 0),
        play([("G3", 2), ("G2", 3), ("D4", 1), ("D3", 2)], hint="Two octave checks: G with open G, then fourth-finger D with open D."),
        quiz("Which finger plays C sharp on the A string?", ["Third", "Second", "Fourth"], 0),
        tune("D4 C#4 B3 A3 | G3 F#3 E3 D3 | D3 E3 F#3 G3 | A3:4", bpm=72, title="Scale down and up"),
        tune(LIGHTLY_B + " " + LIGHTLY_END, bpm=80, title="Lightly Row, second part"),
        tune(TWINKLE_1, bpm=80, title="Twinkle, a little faster"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_4 = unit("vc-4", "G and C strings", "Two low strings, C major and G major scales, and three classic melodies.", [
    lesson("vc-4-1", "The G string", [
        explain("Same fingers, lower string",
                "On the G string, first finger plays A, third finger B, and fourth finger C. Same spacing as on D. "
                "Let your arm settle at the G string level.",
                board([(3, 2, 1), (3, 4, 3), (3, 5, 4)])),
        play([("G2", 3), ("A2", 3), ("B2", 3), ("C3", 3)], hint="G, A, B, C: open, 1, 3, 4."),
        explain("G major",
                "G, A, B, C on the G string plus D, E, F sharp, G on the D string make the G major scale. Same "
                "fingers on both strings.",
                bass(G_MAJOR)),
        play(G_MAJOR, hint="Up the G major scale. Same shape on both strings."),
        quiz("Which finger plays C on the G string?", ["Fourth", "Third", "Second"], 0),
        tune("G2 A2 B2 C3 | D3 E3 F#3 G3 | G3 F#3 E3 D3 | C3 B2 A2 G2", bpm=66, title="G major scale"),
    ]),
    lesson("vc-4-2", "The C string", [
        explain("The deepest string",
                "On the C string, first finger plays D, third finger E, and fourth finger F. The thick string needs "
                "a slow, heavy bow to speak.",
                board([(4, 2, 1), (4, 4, 3), (4, 5, 4)])),
        play([("C2", 4), ("D2", 4), ("E2", 4), ("F2", 4)], hint="C, D, E, F: open, 1, 3, 4. Give each note time to speak."),
        explain("C major, low octave",
                "C, D, E, F on the C string plus G, A, B, C on the G string is the C major scale. It has no sharps "
                "at all.",
                bass(C_LOW)),
        play(C_LOW, hint="Up the C major scale. At the top, listen for C ringing with the open C string."),
        listen("Same letter name?", [["C2"], ["C3"]], SAME_LETTER, 0),
        tune("C2 D2 E2 F2 | G2 A2 B2 C3 | C3 B2 A2 G2 | F2 E2 D2 C2", bpm=60, title="C major scale"),
    ]),
    lesson("vc-4-3", "Second finger: F natural", [
        explain("Second finger joins in",
                "Second finger plays F natural on the D string, a half step below F sharp, and C natural on the A "
                "string. C major needs both.",
                board([(2, 2, 1), (2, 3, 2), (2, 5, 4), (1, 2, 1), (1, 3, 2)])),
        play([("D3", 2), ("E3", 2), ("F3", 2), ("G3", 2)], hint="D, E, F, G: open, 1, 2, 4. Second finger sits right next to first."),
        listen("E, then second finger or third?", [["E3"], ["F3"]], ["Second: F natural", "Third: F sharp"], 0),
        listen("And this one?", [["E3"], ["F#3"]], ["Second: F natural", "Third: F sharp"], 1),
        explain("One finger, one half step",
                "Cellists give each finger its own half step, so F takes second finger and F sharp takes third. A "
                "note just past the hand, like F sharp on the C string, needs an extension, a wider hand. This "
                "course picks keys that avoid it."),
        play(["C3", "D3", "E3", "F3", "G3", "A3", "B3", "C4"], hint="C major, second octave: second finger for F and for the top C."),
        tune("C2 D2 E2 F2 | G2 A2 B2 C3 | D3 E3 F3 G3 | A3 B3 C4:2 | B3 A3 G3 F3 | E3 D3 C3 B2 | A2 G2 F2 E2 | D2 C2:3",
             bpm=66, title="C major, two octaves"),
    ]),
    lesson("vc-4-4", "Ode to Joy", [
        explain("Beethoven's melody", BEETHOVEN, bass(["E2", "E2", "F2", "G2", "G2", "F2", "E2", "D2"])),
        tune(ODE_1, bpm=66, title="First line"),
        explain("Long, short, long", DOTTED, rhythm([0, 1.5, 2])),
        tap([0, 1.5, 2], bpm=66, bars=2),
        tune(ODE_2, bpm=66, title="Second line"),
        tune(ODE_1 + " " + ODE_2, bpm=72, title="Ode to Joy"),
        tune(ODE_UP, bpm=72, title="Ode to Joy, an octave up"),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=35, kind="song", arrangement=ODE_SONG.meta()),
    lesson("vc-4-5", "Brahms' Lullaby", [
        explain("A cradle song from 1868",
                "Brahms wrote this lullaby in 1868. It rocks in three on the G and D strings. Use long, slow bows "
                "and let each phrase breathe.",
                rhythm([0, 2, 2.5], beats_per_bar=3)),
        tap([0, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
        tune(LULLABY_1, bpm=66, beats_per_bar=3, title="First half"),
        play([("G3", 2), ("F#3", 2), ("E3", 2)], hint="G, F sharp, E: fingers 4, 3, 1. This is the lullaby's high point."),
        tune("r:2 " + LULLABY_2, bpm=66, beats_per_bar=3, title="Second half"),
        tune(LULLABY_1 + " " + LULLABY_2, bpm=72, beats_per_bar=3, title="Brahms' Lullaby"),
        LULLABY_SONG.take("Brahms' Lullaby"),
    ], minutes=LULLABY_SONG.minutes(), xp=30, kind="song", arrangement=LULLABY_SONG.meta()),
    lesson("vc-4-6", "Au clair de la lune", [
        explain("A French folk song",
                "Au clair de la lune is a French folk song from the 1700s. It lives on the G and D strings, with C "
                "under your fourth finger.",
                bass(["C3", "C3", "C3", "D3", "E3", "D3"])),
        tune(MOON_A + " " + MOON_A, bpm=72, title="First part"),
        play([("D3", 2), ("C3", 3), ("B2", 3), ("A2", 3), ("G2", 3)], hint="D, C, B, A, G: open D, then fingers 4, 3, 1 and open G."),
        tune(MOON_B + " " + MOON_A, bpm=72, title="Second part"),
        quiz("Which notes in this tune are open strings?", ["D and G", "C and A", "E and B"], 0),
        tune(" ".join([MOON_A, MOON_A, MOON_B, MOON_A]), bpm=80, title="Au clair de la lune"),
        MOON_SONG.take("Au clair de la lune"),
    ], minutes=MOON_SONG.minutes(), xp=30, kind="song", arrangement=MOON_SONG.meta()),
    lesson("vc-4-7", "Low strings checkup", [
        explain("Four strings, one hand",
                "Open, 1, 3, 4 on every string, with second finger for F and C natural. Slow, heavy bows on the "
                "low strings."),
        listen("D, E, then which finger?", [["D3"], ["E3"], ["F#3"]], ["Third: F sharp", "Second: F natural"], 0),
        play([("C3", 3), ("C2", 4), ("G3", 2), ("G2", 3)], hint="Two octave checks: C with open C, then G with open G."),
        quiz("Which of these keys has no sharps?", ["C major", "G major", "D major"], 0),
        tune("G2 A2 B2 C3 | D3 E3 F#3 G3 | G3 F#3 E3 D3 | C3 B2 A2 G2", bpm=76, title="G major scale"),
        tune(ODE_UP, bpm=80, title="Ode to Joy, an octave up"),
        tune(MOON_B + " " + MOON_A, bpm=84, title="Au clair, second part"),
    ], minutes=6, xp=35, kind="challenge"),
])

UNIT_5 = unit("vc-5", "Shifting basics", "Slide to fourth position, check it by ear, and play The Swan and Amazing Grace.", [
    lesson("vc-5-1", "Your first shift", [
        explain("What a shift is",
                "A shift moves your whole hand to a new place on the string. Lighten the finger, slide it along the "
                "string without lifting, and let your thumb travel with the hand."),
        explain("Fourth position",
                "In fourth position, first finger plays D on the A string, the note fourth finger played in first "
                "position. Your thumb settles where the neck curves into the body.",
                fretboard(C, [(1, 2, 1), (1, 5, 1)], frets=8)),
        play([("B3", 1), ("D4", 1)], hint="B with first finger, then slide that finger up to D. Keep it light on the way.", pos=FOURTH),
        quiz("What travels during a shift?", ["The whole hand, thumb included", "Only the finger", "Only the thumb"], 0,
             "Moving the hand as one unit keeps your finger spacing, so the next notes land in tune too."),
        play([("D4", 1), ("B3", 1), ("D4", 1)], hint="Shift up, back, and up again on first finger. Land each note in tune.", pos=FOURTH),
        tune("A3@1:2 B3:2 | D4:4 | D4:2 B3:2 | A3@1:4", bpm=60, title="First-finger shifts", pos=FOURTH),
    ]),
    lesson("vc-5-2", "Fourth position on A", [
        explain("D, E, F",
                "In fourth position on the A string, first finger plays D, third finger E, and fourth finger F. "
                "Same frame as first position: one finger per half step.",
                fretboard(C, [(1, 5, 1), (1, 7, 3), (1, 8, 4)], frets=4, start=5)),
        play([("D4", 1), ("E4", 1), ("F4", 1)], hint="D, E, F: fingers 1, 3, 4. Up here the notes sit a little closer together.", pos=FOURTH),
        listen("From E to the next note: what kind of step?", [["E4"], ["F4"]], ["A half step", "A whole step"], 0),
        play([("A3", 1), ("B3", 1), ("D4", 1), ("E4", 1)], hint="Open A, B, shift on first finger to D, then E with third.", pos=FOURTH),
        quiz("In fourth position on the A string, which finger plays E?", ["Third", "First", "Fourth"], 0),
        tune(UP_AND_BACK_4, bpm=60, title="Up to fourth position and back", pos=FOURTH),
    ]),
    lesson("vc-5-3", "Fourth position on D", [
        explain("Check it with the open A",
                "In fourth position on the D string, first finger plays G and third plays A, the same note as the "
                "open A string. Play them one after the other and match them.",
                fretboard(C, [(1, 0), (2, 5, 1), (2, 7, 3)], frets=8)),
        play([("G3", 2), ("A3", 2)], hint="First-finger G, then third-finger A, both on the D string.", pos=FOURTH),
        play([("A3", 2), ("A3", 1), ("A3", 2)], hint="Fourth-position A, open A, fourth-position A. Make them one sound.", pos=FOURTH),
        listen("Which pair matches?", [["A3"], ["A3"], ["A3"], ["Bb3"]], ["The first pair", "The second pair"], 0),
        explain("Shift on the D string",
                "Play E with first finger in first position, then slide that finger up to G. That's three half "
                "steps, the same distance as B to D on the A string."),
        play([("E3", 2), ("G3", 2)], hint="First-finger E, then slide to first-finger G. Let the thumb travel too.", pos=FOURTH),
        tune("D3@2 E3 G3 A3@2 | A3@2 G3 E3 D3@2 | D3@2 E3 G3 A3@2 | A3@1:4", bpm=60, title="Shifting on the D string", pos=FOURTH),
    ]),
    lesson("vc-5-4", "The Swan", [
        explain("Saint-Saëns, 1886",
                "The Swan comes from The Carnival of the Animals, written by Camille Saint-Saëns in 1886. This is "
                "its opening phrase, an octave lower and simplified.",
                bass(["G3", "F#3", "B2", "E3", "D3", "G2", "A2", "B2", "C3"])),
        explain("A singing bow",
                "Long notes need slow bows. Keep the bow close to the bridge and spread it evenly, so each note "
                "lasts to its very end without fading."),
        play([("G3", 2), ("F#3", 2), ("B2", 3)], hint="G, F sharp, B: fourth and third finger on D, then third finger on G."),
        tune("G3:3 F#3 B2:2 | E3:3 D3 G2:2", bpm=72, beats_per_bar=6, title="Bars 1 and 2"),
        tune("A2:5 B2 | C3:6", bpm=72, beats_per_bar=6, title="Bars 3 and 4"),
        quiz("How do you keep a long note from fading?", ["Spread the bow evenly", "Press harder at the end", "Use a quick bow"], 0),
        tune(SWAN, bpm=72, beats_per_bar=6, title="The Swan"),
        SWAN_SONG.take("The Swan"),
    ], minutes=SWAN_SONG.minutes(), xp=30, kind="song", arrangement=SWAN_SONG.meta()),
    lesson("vc-5-5", "Amazing Grace", [
        explain("Shift on the open string",
                "In Amazing Grace, the high D comes right after open A. While the A rings, slide your hand up to "
                "fourth position and land on D with first finger."),
        tap([0, 2, 2.5], bpm=72, bars=2, beats_per_bar=3),
        play([("B3", 1), ("A3", 1), ("D4", 1, 1)], hint="B, open A, then first-finger D in fourth position. Move while the A sounds."),
        tune(GRACE_1, bpm=72, beats_per_bar=3, title="First phrase"),
        quiz("When is the easiest moment to shift?", ["During an open string", "In the middle of a long note", "Never; stretch instead"], 0,
             "While an open string sounds, your left hand is free, so the shift can't be heard."),
        tune("r:2 B3 | " + GRACE_2, bpm=72, beats_per_bar=3, title="Second phrase"),
        tune(GRACE_1 + " " + GRACE_2, bpm=76, beats_per_bar=3, title="Amazing Grace"),
        AMAZING_SONG.take("Amazing Grace"),
    ], minutes=AMAZING_SONG.minutes(), xp=35, kind="song", arrangement=AMAZING_SONG.meta()),
    lesson("vc-5-6", "Shifting checkup", [
        explain("Light, together, in tune",
                "Lighten the finger, move hand and thumb together, and check where you land. The open strings will "
                "tell you if you're right."),
        play([("A3", 2), ("A3", 1)], hint="Fourth-position A on the D string, then open A. Match them.", pos=FOURTH),
        listen("From E to the next note: what kind of step?", [["E4"], ["F4"]], ["A half step", "A whole step"], 0),
        quiz("In fourth position, which note does first finger play on the A string?", ["D", "B", "E"], 0),
        tune(UP_AND_BACK_4, bpm=66, title="Up to fourth position and back", pos=FOURTH),
        tune(SWAN, bpm=72, beats_per_bar=6, title="The Swan"),
        tune(GRACE_1, bpm=76, beats_per_bar=3, title="Amazing Grace, first phrase"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("cello", "Cello", "Sit, bow and play in tune, from open strings to The Swan",
                "cello.standard.4", "music.note", "coral", [
                    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5,
                ])
