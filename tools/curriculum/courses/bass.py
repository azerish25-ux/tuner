"""Bass: from the four open strings to walking lines and grooves. Strings: 1 G2, 2 D2, 3 A1, 4 E1."""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, quiz, rhythm, tap, unit
from songbook import Part, song
import tunes

B = "bass"

DOWNS = [0, 1, 2, 3]
HALVES = [0, 2]
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
DOTTED = [0, 1.5, 2, 3]                    # dotted quarter, eighth, quarter, quarter


def rep(token: str, times: int) -> str:
    return " ".join([token] * times)


# Unit 2: roots.
ROOTS_ADE = f"{rep('A1', 4)} {rep('D2', 4)} {rep('A1', 4)} {rep('E1', 4)}"
ROOTS_G = f"{rep('G1', 8)} {rep('C2', 4)} {rep('G1', 4)} {rep('D2', 4)} {rep('C2', 4)} {rep('G1', 4)} {rep('D2', 4)}"

# Unit 3: the G major scale shape (second position, index on fret 2) and "Ode to Joy" in G.
G_SCALE = "G1@4 A1@4 B1@3 C2@3 D2@3 E2@2 F#2@2 G2@2 G2@2 F#2@2 E2@2 D2@3 C2@3 B1@3 A1@4 G1@4"
ODE_1 = "B1 B1 C2 D2 D2 C2 B1 A1 G1 G1 A1 B1 B1:1.5 A1:0.5 A1:2"
ODE_2 = "B1 B1 C2 D2 D2 C2 B1 A1 G1 G1 A1 B1 A1:1.5 G1:0.5 G1:2"

# Unit 4: root, fifth, octave.
RF_HALVES = "A1:2 E2:2 A1:2 E2:2 D2:2 A2:2 D2:2 A2:2 E1:2 B1:2 E1:2 B1:2 A1:2 E2:2 A1:4"
RFO_AE = "A1 E2 A2 E2 A1 E2 A2 E2 E1 B1 E2 B1 E1 B1 E2 B1"
RFO_GC = "G1@4 D2@3 G2@2 D2@3 G1@4 D2@3 G2@2 D2@3 C2@3 G2@2 C3@1 G2@2 C2@3 G2@2 C3@1 G2@2"

# Unit 5: walking blues. Root, third, fifth, sixth, with approach notes before each change.
WALK_A, WALK_D, WALK_E = "A1 C#2 E2 F#2", "D2 F#2 A2 B2", "E1 G#1 B1 C#2"
BLUES_A_1 = f"{WALK_A} {WALK_A} {WALK_A} A1 C#2 E2 C#2"            # bars 1-4: A, into D
BLUES_A_2 = "D2 F#2 A2 B2 D2 F#2 A2 G#1 A1 C#2 E2 F#2 A1 C#2 E2 F1"  # bars 5-8: D, D, A, A into E
BLUES_A_3 = "E1 G#1 B1 C#2 D2 F#2 A2 G#1 A1 C#2 E2 F1 E1 G#1 B1 G#1"  # bars 9-12: E, D, A, E back to A
BLUES_A = f"{BLUES_A_1} {BLUES_A_2} {BLUES_A_3}"
BLUES_E_1 = "E1 G#1 B1 C#2 E1 G#1 B1 C#2 E1 G#1 B1 C#2 E1 G#1 B1 G#1 A1 C#2 E2 F#2 A1 C#2 E2 F1"   # bars 1-6
BLUES_E_2 = "E1 G#1 B1 C#2 E1 G#1 B1 A#1 B1 D#2 F#2 A#1 A1 C#2 E2 F1 E1 G#1 B1 A#1 B1 D#2 F#2 F1"  # bars 7-12
BLUES_E = f"{BLUES_E_1} {BLUES_E_2}"

# Unit 6: grooves. The Motown-style line is original to Timbre (C, A minor, D minor, G).
ROCK = (f"{rep('E1:0.5', 8)} {rep('G1:0.5', 4)} {rep('A1:0.5', 4)} "
        f"{rep('E1:0.5', 8)} {rep('B1:0.5', 4)} {rep('A1:0.5', 4)}")
LONG_SHORT = "A1:1.5 A1:0.5 E2 A1 D2:1.5 D2:0.5 A2 D2 E1:1.5 E1:0.5 B1 E1 A1:1.5 A1:0.5 A1:2"
BOUNCE = "E1:0.5 E1:0.5 r:1 G1:0.5 A1:0.5 r:1 E1:0.5 E1:0.5 r:1 D2:0.5 B1:0.5 r:1"
MOTOWN_1 = "C2 r:0.5 C2:0.5 E2:0.5 G2:0.5 E2:0.5 Bb1:0.5 A1 r:0.5 A1:0.5 C2:0.5 E2:0.5 C2:0.5 C#2:0.5"
MOTOWN_2 = "D2 r:0.5 D2:0.5 F2:0.5 A2:0.5 F2:0.5 F#1:0.5 G1 r:0.5 G1:0.5 B1:0.5 D2:0.5 G2:0.5 B1:0.5"
MOTOWN = f"{MOTOWN_1} {MOTOWN_2}"

# ---------------------------------------------------------------- whole songs (songbook)
# Chord-chart shapes, string 4 (E) first: the notes a bassist can stack under each chord.
SHAPES = {c["name"]: c for c in [
    chord(B, "G", "3200", "2100"), chord(B, "D", "x542", "x431"), chord(B, "C", "x320", "x210"),
    chord(B, "A7", "x020", "x010"), chord(B, "D7", "x545", "x324"), chord(B, "E7", "0201", "0201"),
]}


def roots(*chords):
    """A bar of the chord's root on every beat, for each chord: the bassist's first job."""
    return " ".join(" ".join([{"G": "G1", "D": "D2", "C": "C2"}[c]] * 4) for c in chords)


# Ode to Joy on bass, unit 3: the melody in G in the scale shape, roots under the band between the verses. The
# middle section's low D is under the E string, so it lands on the D an octave up.
B_A1, B_A2, B_B, B_TAIL = tunes.ode(-29, low_g="D2")
B_ODE_CHART = tunes.transpose_chords(tunes.ODE_CHORDS, 7)
B_ODE_V = Part("Verse 1", "verse", f"{B_A1} {B_A2} {B_B} {B_A2}", chords=B_ODE_CHART, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = song(B, 72, [
    Part("Intro", "intro", f"{roots('G', 'D', 'G')} D2 D2 G1:2", chords="G D G D,G"),
    B_ODE_V,
    Part("Interlude", "interlude", f"{roots('G', 'D', 'G', 'D', 'G', 'D', 'G')} D2 D2 G1 G1", chords="G D G D G D G D,G"),
    B_ODE_V.with_lyrics("Verse 2", tunes.ODE_WORDS_2),
    Part("Outro", "outro", B_A2, chords=tunes.transpose_chords(tunes.ODE_CHORDS_A2, 7), lyrics=tunes.ODE_WORDS_END),
], shapes=SHAPES, words=tunes.ODE_CREDIT, max_fret=5, first_fret=2)

# Walking the blues in A: three times through the form (blues players call each one a chorus), the second a boogie
# line that climbs to the seventh and walks back down.
BLUES_CHART = "A7 A7 A7 A7 D7 D7 A7 A7 E7 D7 A7 E7"
BOOGIE_A, BOOGIE_D = "A1 C#2 E2 F#2 G2 F#2 E2 C#2", "D2 F#2 A2 B2 C3 B2 A2 F#2"
BOOGIE_BLUES = f"{BOOGIE_A} {BOOGIE_A} {BOOGIE_D} {BOOGIE_A} E1 G#1 B1 C#2 D2 F#2 A2 G#1 A1 C#2 E2 F1 E1 G#1 B1 G#1"
BLUES_SONG = song(B, 72, [
    Part("Intro", "intro", BLUES_A_3, chords="E7 D7 A7 E7"),
    Part("Chorus", "chorus", BLUES_A, chords=BLUES_CHART),
    Part("Solo", "solo", BOOGIE_BLUES, chords=BLUES_CHART),
    Part("Chorus", "chorus", BLUES_A, chords=BLUES_CHART),
    Part("Outro", "outro", "A1 C#2 E2 G2 A1:4", chords="A7 A7"),
], shapes=SHAPES, max_fret=5)

# The first song, unit 1 (free): Mary Had a Little Lamb on three notes in G, deep down: B (string 3, fret 2), open A
# and G (string 4, fret 3), the notes unit 1 plays plus one.
MARY_FIRST = tunes.mary3(-29)
MARY_FIRST_SONG = song(B, 84, tunes.mary3_parts(-29, "G G D G G G D G"), shapes=SHAPES, words=tunes.MARY_CREDIT)

UNIT_1 = unit("bass-1", "Hello, bass", "Meet E A D G, pluck with two fingers, play your first notes and a song.", [
    lesson("bass-1-1", "Meet your bass", [
        explain("Four strings, low and deep", "The thickest string is the lowest. It sits nearest your face when you play. We call it string 4.",
                part("strings")),
        explain("Turn to tune", "Each string has a tuning peg on the head. Turning it changes the pitch. Timbre listens and tells you which way.",
                part("head")),
        quiz("Which string is string 4?", ["The thickest", "The thinnest", "The middle one"], 0,
             "Strings count from the thinnest (1) to the thickest (4)."),
        notes(B, [("E1", 4)], hint="Pluck the thickest string and let it ring."),
        notes(B, [("G2", 1)], hint="Now the thinnest one, string 1."),
    ], minutes=3, xp=15),
    lesson("bass-1-2", "The open strings", [
        explain("E A D G", "From thick to thin: E, A, D, G. They match the four lowest guitar strings, an octave down. Try: Every Amp Drives Grooves.",
                fretboard(B, [(4, 0), (3, 0), (2, 0), (1, 0)])),
        notes(B, [("E1", 4), ("A1", 3)], hint="Play strings 4 and 3, one at a time."),
        notes(B, [("D2", 2), ("G2", 1)], hint="Now strings 2 and 1."),
        quiz("What is string 3 called?", ["D", "E", "G", "A"], 3, visual=fretboard(B, [(3, 0)])),
        listen("Which is higher?", [["A1"], ["D2"]], ["The first", "The second"], 1),
        along(B, "E1@4:2 A1@3:2 D2@2:2 G2@1:2 D2@2:2 A1@3:2 E1@4:4", bpm=60, title="Open-string roll call"),
    ], minutes=4, xp=20),
    lesson("bass-1-3", "Plucking with two fingers", [
        explain("Index, middle, index, middle", "Pluck with the pads of your index and middle fingers, taking turns. Rest your thumb on the pickup or on string 4."),
        explain("Pull through the string", "Pluck across the string, not up and away. Your finger comes to rest on the next thicker string. This rest stroke sounds full and strong."),
        tap(DOWNS, bpm=60, bars=2),
        along(B, rep("E1", 8), bpm=60, title="Index, middle on E"),
        quiz("Where does your finger stop after a rest stroke?", ["In the air above the strings", "On the fretboard", "On the next thicker string"], 2,
             "Pulling through to the next string keeps the motion small and the tone strong."),
        along(B, f"{rep('A1', 4)} {rep('D2', 4)} {rep('G2', 4)} A1:4", bpm=66, title="Walk the open strings"),
    ], minutes=4, xp=20),
    lesson("bass-1-4", "Your first fretted notes", [
        explain("Press just behind the fret", "Put your fingertip just behind the metal fret, not on top of it. Press firmly enough for a clean ring.",
                fretboard(B, [(4, 3, 3)])),
        notes(B, [("G1", 4)], hint="String 4, fret 3, third finger."),
        notes(B, [("C2", 3)], hint="String 3, fret 3, third finger."),
        quiz("Where do you press?", ["Just behind the fret", "On top of the fret", "Between two frets, in the middle"], 0),
        notes(B, ["E1", "G1", "A1", "C2"], hint="Open E, fret 3, open A, fret 3."),
        along(B, "E1 G1 A1 C2 A1 G1 E1:2", bpm=66, title="Up and back"),
    ], minutes=4, xp=20),
    lesson("bass-1-5", "Challenge: first notes", [
        explain("Put it together", "Open strings, two-finger plucking and your first fretted notes. Keep your fingers taking turns and let each note ring."),
        quiz("Name the open strings from 4 to 1.", ["E A D G", "G D A E", "G C E A"], 0),
        listen("Which one is the open E string?", [["A1"], ["E1"]], ["The first", "The second"], 1),
        notes(B, [("E1", 4), ("A1", 3), ("D2", 2), ("G2", 1)], hint="All four open strings, 4 to 1."),
        tap(DOWNS, bpm=66, bars=2),
        along(B, "E1 E1 G1 G1 A1 A1 C2 C2 D2 D2 C2 C2 A1 G1 E1:2", bpm=70, title="First-notes groove"),
    ], minutes=5, xp=30, kind="challenge"),
    lesson("bass-1-6", "Mary Had a Little Lamb", [
        explain("Your first song", "Mary Had a Little Lamb needs three notes: B at fret 2 on string 3, open A, and G at "
                "fret 3 on string 4. Second finger for B, third for G.", fretboard(B, [(3, 2, 2), (3, 0), (4, 3, 3)])),
        notes(B, [("B1", 3)], hint="String 3, fret 2, second finger. That's B."),
        notes(B, ["B1", "A1", "G1", "A1", "B1", "B1", "B1"], hint="B A G A B B B: string 3, then G on string 4."),
        along(B, MARY_FIRST[0], bpm=66, title="First half"),
        MARY_FIRST_SONG.along("Verse 1", bpm=72, title="The verse"),
        MARY_FIRST_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_FIRST_SONG.minutes(), xp=30, kind="song", arrangement=MARY_FIRST_SONG.meta()),
])

UNIT_2 = unit("bass-2", "Roots and timing", "Play the root of each chord and lock in with the beat.", [
    lesson("bass-2-1", "What a root is", [
        explain("The root names the chord", "Every chord is built on one note, its root. The root of an A chord is A. Bass players play roots so the band knows where home is."),
        quiz("What is the root of a D chord?", ["D", "A", "G"], 0),
        listen("Root or not? Listen to the lowest note.", [["A1", "A3", "C#4", "E4"]], ["Root", "Not the root"], 0),
        notes(B, ["A1", "D2", "E1"], hint="Roots of A, D and E: all open strings."),
        tap(DOWNS, bpm=66, bars=2),
        along(B, ROOTS_ADE, bpm=66, title="Roots of A, D and E"),
    ], minutes=4, xp=20),
    lesson("bass-2-2", "Lock in with the beat", [
        explain("The drummer's best friend", "Bass and kick drum land together. Aim for the exact moment of the click, not just near it. Timbre shows if you're early or late."),
        tap(DOWNS, bpm=70, bars=2),
        along(B, rep("A1", 8), bpm=70, title="Quarter notes on A"),
        quiz("You keep landing a little after the click. What helps?", ["Play softer", "Feel the beat coming and pluck a touch earlier", "Speed up the song"], 1,
             "Your finger needs a moment to move. Start the pluck slightly earlier so the note speaks right on the beat."),
        tap(HALVES, bpm=70, bars=2),
        along(B, "E1:2 E1:2 A1:2 A1:2 D2:2 D2:2 A1:4", bpm=70, title="Half notes"),
    ], minutes=4, xp=20),
    lesson("bass-2-3", "Rests and muting", [
        explain("Rests count too", "A rest is a beat of silence. Stop the string by touching it lightly with a free finger, so the rest is as clean as the note.",
                rhythm([0, 1, 3])),
        tap([0, 1, 3], bpm=66, bars=2),
        along(B, "A1 A1 r:1 A1 D2 D2 r:1 D2 E1 E1 r:1 E1 A1:2 r:2", bpm=66, title="Play, play, rest, play"),
        quiz("How do you stop a ringing string?", ["Pluck it again", "Press it harder", "Touch it lightly with a free finger"], 2,
             "Muting is half of bass playing. Rest a finger lightly on the string to silence it."),
        along(B, "E1:2 r:2 A1:2 r:2 D2 D2 r:2 A1:4", bpm=66, title="Space between notes"),
    ], minutes=4, xp=20),
    lesson("bass-2-4", "Roots from a chord chart", [
        explain("Follow the chart", "A chord chart tells you which chord is coming. Play its root on every beat until the chart changes."),
        notes(B, ["G1", "C2", "D2"], hint="G on string 4 fret 3, C on string 3 fret 3, then open D."),
        along(B, f"{rep('G1', 4)} {rep('C2', 4)} {rep('D2', 4)} {rep('G1', 4)}", bpm=66, title="G, C, D, G"),
        quiz("The chart says C. Which note do you play?", ["G", "E", "C"], 2),
        tap(DOWNS, bpm=72, bars=2),
        along(B, ROOTS_G, bpm=72, title="Roots in G"),
    ], minutes=5, xp=20),
    lesson("bass-2-5", "Challenge: roots in time", [
        explain("Steady roots", "Roots on the beat, clean rests and changes right on time. Keep your plucking fingers taking turns the whole way."),
        tap([0, 1, 3], bpm=72, bars=2),
        quiz("What is the root of an E chord?", ["A", "B", "E", "G"], 2),
        along(B, "A1 A1 A1 A1 D2 D2 D2 D2 E1 E1 E1 E1 A1:2 r:2", bpm=72, title="A, D, E"),
        listen("Root or not? Listen to the lowest note.", [["E2", "A3", "C#4", "E4"]], ["Root", "Not the root"], 1),
        along(B, "G1 G1 r:1 G1 C2 C2 r:1 C2 D2 D2 D2 D2 G1:2 r:2", bpm=72, title="G, C, D with rests"),
        along(B, ROOTS_G, bpm=76, title="Roots in G"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_3 = unit("bass-3", "The E and A strings", "Every note from fret 0 to 5 on strings 4 and 3, and the major scale shape.", [
    lesson("bass-3-1", "Notes on the E string", [
        explain("E to A on one string", "On string 4, each fret is one note higher: E, F, F sharp, G, G sharp, then A at fret 5. Fret 5 sounds the same as open string 3.",
                fretboard(B, [(4, 0), (4, 1, 1), (4, 2, 2), (4, 3, 3), (4, 4, 4), (4, 5, 4)])),
        notes(B, [("F1", 4), ("G1", 4), ("A1", 4)], hint="String 4: fret 1, fret 3, fret 5.", max_fret=5),
        listen("Same note or different?", [["A1"], ["A1"]], ["Same", "Different"], 0),
        quiz("Which fret on string 4 matches open string 3?", ["Fret 3", "Fret 5", "Fret 7"], 1,
             "Both are A. Each string is tuned to fret 5 of the string below it."),
        along(B, "E1@4 F1@4 G1@4 A1@4 G1@4 F1@4 E1@4:2", bpm=66, max_fret=5, title="Up the E string"),
        tap([0, 1, 2], bpm=66, bars=2),
        along(B, "E1 G1 A1@4:2 E1 G1 A1@4 G1 E1:2 G1:2 E1:4", bpm=66, max_fret=5, title="E-string riff"),
    ], minutes=4, xp=20),
    lesson("bass-3-2", "Notes on the A string", [
        explain("A to D on string 3", "String 3 works the same way: A, B flat, B, C, C sharp, then D at fret 5. Fret 5 matches open string 2.",
                fretboard(B, [(3, 0), (3, 1, 1), (3, 2, 2), (3, 3, 3), (3, 4, 4), (3, 5, 4)])),
        notes(B, [("B1", 3), ("C2", 3), ("D2", 3)], hint="String 3: fret 2, fret 3, fret 5.", max_fret=5),
        quiz("What is fret 3 on string 3?", ["C", "B", "D"], 0, visual=fretboard(B, [(3, 3)])),
        along(B, "A1 B1 C2 D2@3 C2 B1 A1:2", bpm=66, max_fret=5, title="Up the A string"),
        listen("Which is higher?", [["C2"], ["B1"]], ["The first", "The second"], 0),
        along(B, "A1 C2 D2@3:2 A1 C2 D2@3 C2 A1:2 C2:2 A1:4", bpm=66, max_fret=5, title="A-string riff"),
    ], minutes=4, xp=20),
    lesson("bass-3-3", "One note, two places", [
        explain("Fret 5 or the open string", "A on fret 5 of string 4 sounds the same as open string 3. Open strings ring longer; fretted notes are easier to stop and shape.",
                fretboard(B, [(4, 5, 4), (3, 0)])),
        notes(B, [("A1", 4), ("A1", 3)], hint="Fret 5 on string 4, then open string 3.", max_fret=5),
        notes(B, [("D2", 3), ("D2", 2)], hint="Fret 5 on string 3, then open string 2.", max_fret=5),
        quiz("Which fret on string 3 matches open string 2?", ["Fret 3", "Fret 4", "Fret 5"], 2,
             "Both are D. Each string is tuned to fret 5 of the string below it."),
        along(B, "E1@4 G1@4 A1@4 C2@3 D2@3 C2@3 A1@4 G1@4", bpm=66, max_fret=5, title="Stay on two strings"),
        along(B, "E1 G1 A1@4 G1 E1 G1 A1@4:2 A1@3 C2 D2@3 C2 A1@3 C2 D2@2:2", bpm=66, max_fret=5, title="Fretted or open"),
    ], minutes=4, xp=20),
    lesson("bass-3-4", "The major scale shape", [
        explain("One finger per fret", "Let each finger cover one fret: index on fret 2, middle on 3, ring on 4, little on 5. Your thumb rests behind the neck, across from your middle finger.",
                fretboard(B, [(4, 2, 1), (4, 3, 2), (4, 4, 3), (4, 5, 4)])),
        notes(B, [("F#1", 4), ("G1", 4), ("G#1", 4), ("A1", 4)], hint="Fingers 1, 2, 3, 4 on frets 2 to 5.", max_fret=5, first_fret=2),
        explain("The major scale shape", "Start on G, fret 3 of string 4, with your middle finger. Climb across three strings: G A B C D E F sharp G. The same shape works from any root.",
                fretboard(B, [(4, 3, 2), (4, 5, 4), (3, 2, 1), (3, 3, 2), (3, 5, 4), (2, 2, 1), (2, 4, 3), (2, 5, 4)])),
        notes(B, [("G1", 4), ("A1", 4), ("B1", 3), ("C2", 3)], hint="Middle, little; then index, middle on string 3.", max_fret=5, first_fret=2),
        notes(B, [("D2", 3), ("E2", 2), ("F#2", 2), ("G2", 2)], hint="Little finger; then index, ring, little on string 2.", max_fret=5, first_fret=2),
        quiz("You move the shape so it starts on fret 5 of string 4. Which scale is it now?", ["A major", "G major", "C major"], 0,
             "Fret 5 on string 4 is A, so the same shape plays A major."),
        along(B, G_SCALE, bpm=60, max_fret=5, first_fret=2, title="G major, up and down"),
    ], minutes=5, xp=25),
    lesson("bass-3-5", "Ode to Joy on bass", [
        explain("Beethoven, down low", "Ode to Joy works on bass too. Play it in G on strings 4 and 3, with your hand in the scale shape: index on fret 2."),
        notes(B, ["B1", "C2", "D2"], hint="String 3: frets 2, 3 and 5.", max_fret=5, first_fret=2),
        along(B, ODE_1, bpm=66, max_fret=5, first_fret=2, title="Ode to Joy, first line"),
        quiz("The first line ends on A. Where does the second line end?", ["On G, home", "On A again", "On D"], 0,
             "Same start, different finish. The second line comes home to G."),
        along(B, ODE_2, bpm=66, max_fret=5, first_fret=2, title="Ode to Joy, second line"),
        along(B, f"{ODE_1} {ODE_2}", bpm=72, max_fret=5, first_fret=2, title="Ode to Joy"),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=30, kind="song", arrangement=ODE_SONG.meta()),
    lesson("bass-3-6", "Challenge: E and A strings", [
        explain("Name it, find it, play it", "Frets 0 to 5 on strings 4 and 3 give you every note from E up to D. Say each note's name as you play it."),
        quiz("What is fret 3 on string 4?", ["A", "F", "G"], 2, visual=fretboard(B, [(4, 3)])),
        notes(B, [("F1", 4), ("A1", 4), ("B1", 3), ("D2", 3)], hint="F, A, B, D on strings 4 and 3.", max_fret=5),
        listen("Which is higher?", [["G1"], ["D2"]], ["The first", "The second"], 1),
        along(B, G_SCALE, bpm=66, max_fret=5, first_fret=2, title="G major, up and down"),
        along(B, f"{ODE_1} {ODE_2}", bpm=76, max_fret=5, first_fret=2, title="Ode to Joy"),
    ], minutes=5, xp=35, kind="challenge"),
])

UNIT_4 = unit("bass-4", "Root, fifth, octave", "Outline chords with the root, its fifth and its octave.", [
    lesson("bass-4-1", "The fifth", [
        explain("One string over, two frets up", "The fifth of a chord sits on the next thinner string, two frets higher than the root. For open A, that's fret 2 of string 2: E.",
                fretboard(B, [(3, 0), (2, 2, 2)])),
        notes(B, ["A1", "E2"], hint="Open string 3, then string 2 fret 2."),
        notes(B, ["E1", "B1"], hint="Open string 4, then string 3 fret 2."),
        quiz("What is the fifth of D?", ["A", "G", "B"], 0,
             "Count up the D major scale: D, E, F sharp, G, A. A is the fifth note."),
        notes(B, ["D2", "A2"], hint="Open string 2, then string 1 fret 2."),
        along(B, "A1 E2 A1 E2 D2 A2 D2 A2 E1 B1 E1 B1 A1:4", bpm=66, title="Root, fifth"),
    ], minutes=4, xp=20),
    lesson("bass-4-2", "Root and fifth over chords", [
        explain("Root on 1, fifth on 3", "Play the root on beat 1 and the fifth on beat 3. Two notes per bar outline the whole chord and leave room for the drums.",
                rhythm(HALVES)),
        tap(HALVES, bpm=66, bars=2),
        along(B, RF_HALVES, bpm=66, title="A, D, E in halves"),
        quiz("In a root-fifth pattern, which note lands on beat 1?", ["The root", "The fifth", "Either one"], 0,
             "The root on beat 1 tells everyone which chord they're in."),
        listen("Which sounds lower?", [["E1"], ["B1"]], ["The first", "The second"], 0),
        along(B, "A1 A1 E2 E2 D2 D2 A2 A2 E1 E1 B1 B1 A1 E2 A1:2", bpm=70, title="Root, root, fifth, fifth"),
    ], minutes=4, xp=20),
    lesson("bass-4-3", "The octave", [
        explain("Two strings over, two frets up", "The octave is the same note name, higher. From a root on string 4 or 3, go two strings thinner and two frets up. Open A becomes fret 2 of string 1.",
                fretboard(B, [(3, 0), (1, 2, 2)])),
        notes(B, ["A1", "A2"], hint="Open string 3, then string 1 fret 2."),
        notes(B, ["E1", "E2"], hint="Open string 4, then string 2 fret 2."),
        listen("Same note name or different?", [["A1"], ["A2"]], ["Same name, an octave apart", "Different notes"], 0),
        quiz("G is on fret 3 of string 4. Where is the G an octave higher?", ["Fret 3 of string 3", "Fret 5 of string 2", "Fret 5 of string 1"], 1,
             "Two strings thinner, two frets up: fret 5 of string 2. Open string 1 is the same G."),
        along(B, "A1 A2 A1 A2 E1 E2 E1 E2 A1 A2 E1 E2 A1:4", bpm=66, title="Octave jumps"),
    ], minutes=4, xp=20),
    lesson("bass-4-4", "Root, fifth, octave", [
        explain("A three-note shape", "Root, fifth, octave, then back to the fifth. Over A: open string 3, fret 2 of string 2, fret 2 of string 1. It fits any major or minor chord.",
                fretboard(B, [(3, 0), (2, 2, 2), (1, 2, 2)])),
        notes(B, ["A1", "E2", "A2", "E2"], hint="Open 3, string 2 fret 2, string 1 fret 2, back to string 2."),
        along(B, RFO_AE, bpm=66, title="A and E"),
        explain("Move it to a fretted root", "From G on fret 3 of string 4, use your index finger for the root and your ring finger for the fifth and octave, both on fret 5.",
                fretboard(B, [(4, 3, 1), (3, 5, 3), (2, 5, 3)])),
        notes(B, [("G1", 4), ("D2", 3), ("G2", 2), ("D2", 3)], hint="Index on the root, ring finger on fret 5 for the fifth and the octave.", max_fret=5, first_fret=3),
        quiz("You slide the shape so the root is fret 3 of string 3. Which chord is it now?", ["G", "C", "D"], 1,
             "Fret 3 of string 3 is C. Same shape, new root."),
        along(B, RFO_GC, bpm=66, max_fret=5, first_fret=3, title="G and C"),
    ], minutes=5, xp=25),
    lesson("bass-4-5", "Challenge: outline the chords", [
        explain("Outline the chords", "Root on the beat, fifth and octave to fill the bar. Keep the root strong and the other notes even."),
        quiz("What is the fifth of E?", ["A", "G", "B"], 2),
        listen("Same note name or different?", [["E1"], ["E2"]], ["Same name, an octave apart", "Different notes"], 0),
        tap(HALVES, bpm=72, bars=2),
        along(B, RF_HALVES, bpm=72, title="A, D, E in halves"),
        along(B, RFO_AE, bpm=72, title="A and E"),
        along(B, RFO_GC, bpm=72, max_fret=5, first_fret=3, title="G and C"),
    ], minutes=5, xp=35, kind="challenge"),
])

UNIT_5 = unit("bass-5", "Walking bass", "The 12-bar blues, walking lines and chromatic approach notes.", [
    lesson("bass-5-1", "The 12-bar blues", [
        explain("Twelve bars, three chords", "The blues repeats a 12-bar loop: four bars of A, two of D, two of A, then E, D, A, E. Count the bars and you always know where you are."),
        quiz("How many bars of A open the 12-bar blues?", ["Two", "Four", "Eight"], 1),
        along(B, f"{rep('A1', 16)} {rep('D2', 8)} {rep('A1', 8)} {rep('E1', 4)} {rep('D2', 4)} {rep('A1', 4)} {rep('E1', 4)}", bpm=72, title="12-bar roots in A"),
        quiz("Which chord comes in bar 9?", ["D", "A", "E"], 2,
             "Bars 9 to 12 go E, D, A, E. The E in bar 12 turns the loop around."),
        tap(HALVES, bpm=72, bars=2),
        along(B, f"{rep('A1:2 E2:2', 4)} {rep('D2:2 A2:2', 2)} {rep('A1:2 E2:2', 2)} E1:2 B1:2 D2:2 A2:2 A1:2 E2:2 E1:2 B1:2",
              bpm=72, title="12-bar root and fifth"),
    ], minutes=5, xp=25),
    lesson("bass-5-2", "Walking up the chord", [
        explain("A new note on every beat", "A walking bass line plays a new note on every beat. Start with root, third, fifth, sixth: over A that's A, C sharp, E, F sharp.",
                fretboard(B, [(3, 0), (3, 4, 4), (2, 2, 2), (2, 4, 4)])),
        notes(B, ["A1", "C#2", "E2", "F#2"], hint="Open 3, fret 4; then string 2, frets 2 and 4."),
        along(B, f"{WALK_A} {WALK_A}", bpm=66, title="Walking in A"),
        quiz("What makes a bass line walk?", ["A new note on every beat", "Long, held roots", "Only open strings"], 0),
        notes(B, ["D2", "F#2", "A2", "B2"], hint="Open 2, fret 4; then string 1, frets 2 and 4."),
        along(B, f"{WALK_D} {WALK_D} {WALK_E} {WALK_E}", bpm=66, title="Walking in D and E"),
    ], minutes=5, xp=20),
    lesson("bass-5-3", "Chromatic approach notes", [
        explain("Lean into the next chord", "On beat 4, play a note one fret away from the next root. It pulls the ear forward, so the change feels like it arrives.",
                fretboard(B, [(3, 4, 4), (2, 0)])),
        notes(B, ["C#2", "D2"], hint="String 3 fret 4, then open string 2: one fret up into D."),
        quiz("You're heading to D in the next bar. Which note on beat 4 pulls best?", ["G", "C sharp", "A"], 1,
             "C sharp is one fret below D. A half step slides right into the new root."),
        along(B, "A1 C#2 E2 F#2 A1 C#2 E2 C#2 D2 F#2 A2 B2 D2 F#2 A2 G#1", bpm=66, title="Walk into D and back"),
        listen("One fret apart, or more?", [["G#1"], ["A1"]], ["One fret", "More than one"], 0),
        along(B, "A1 C#2 E2 C#2 D2 F#2 A2 G#1 A1 C#2 E2 F1 E1 G#1 B1 G#1", bpm=66, title="Approach every change"),
    ], minutes=5, xp=25),
    lesson("bass-5-4", "Walking the blues in A", [
        explain("Put the walk on the form", "Same 12 bars, now with a walking line. Bars that lead into a new chord end on an approach note."),
        along(B, BLUES_A_1, bpm=66, title="Bars 1 to 4"),
        along(B, BLUES_A_2, bpm=66, title="Bars 5 to 8"),
        along(B, BLUES_A_3, bpm=66, title="Bars 9 to 12"),
        quiz("Why does bar 12 end on G sharp?", ["It's the root of E", "It leads back to A at the top", "It ends the song"], 1,
             "Bar 12 turns the form around. G sharp sits one fret below A, the chord that starts the next time through."),
        along(B, BLUES_A, bpm=72, title="Walking blues in A"),
        BLUES_SONG.take("Walking the blues in A"),
    ], minutes=BLUES_SONG.minutes(), xp=30, kind="song", arrangement=BLUES_SONG.meta()),
    lesson("bass-5-5", "Challenge: walking blues in E", [
        explain("Same form, new key", "The 12-bar blues works in any key. In E the chords are E, A and B. Walk with roots, thirds, fifths and sixths, and approach each change."),
        quiz("In the key of E, which chord comes in bar 9?", ["B", "A", "E"], 0),
        notes(B, ["B1", "D#2", "F#2", "G#2"], hint="String 3 fret 2; string 2 frets 1 and 4; string 1 fret 1."),
        along(B, BLUES_E_1, bpm=70, title="Bars 1 to 6"),
        along(B, BLUES_E_2, bpm=70, title="Bars 7 to 12"),
        along(B, BLUES_E, bpm=76, title="Walking blues in E"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNIT_6 = unit("bass-6", "Grooves", "Eighth-note rock, dotted rhythms, space, and a Motown-style line.", [
    lesson("bass-6-1", "Eighth-note rock groove", [
        explain("Eight even notes", "Count 1 and 2 and 3 and 4 and. Play a note on every count with your fingers taking turns. Even volume is the goal.",
                rhythm(EIGHTHS)),
        tap(EIGHTHS, bpm=66, bars=2),
        along(B, f"{rep('E1:0.5', 8)} {rep('A1:0.5', 8)}", bpm=66, title="Eighths on E and A"),
        quiz("Your eighth notes start to rush. What helps?", ["Play louder", "Lock to the click and relax your hand", "Use one finger only"], 1),
        along(B, ROCK, bpm=72, title="Rock groove in E"),
        along(B, ROCK, bpm=80, title="Rock groove in E"),
    ], minutes=4, xp=20),
    lesson("bass-6-2", "Dotted rhythms", [
        explain("Long, then short", "A dotted quarter lasts one and a half beats. Play on 1, hold through 2, then play on the and of 2, then on 3 and 4.",
                rhythm(DOTTED)),
        tap(DOTTED, bpm=66, bars=2),
        along(B, LONG_SHORT, bpm=66, title="Long-short on A, D and E"),
        quiz("How long does a dotted quarter note last?", ["Two beats", "One beat", "One and a half beats"], 2),
        tap([0, 1.5, 3], bpm=66, bars=2),
        along(B, "A1:1.5 A1:1.5 E2 D2:1.5 D2:1.5 A2 E1:1.5 E1:1.5 B1 A1:1.5 E2:1.5 A1", bpm=66, title="Three, three, two"),
    ], minutes=5, xp=20),
    lesson("bass-6-3", "Leave some space", [
        explain("Silence is part of the groove", "Short notes with clean rests make a line bounce. Ease off the fretting finger, still touching the string, to stop each note right on time."),
        tap([0, 0.5, 2, 2.5], bpm=66, bars=2),
        along(B, f"{BOUNCE} {BOUNCE}", bpm=66, title="Short and bouncy"),
        quiz("How do you stop a fretted note cleanly?", ["Let it ring out", "Pluck the next string", "Ease off but keep touching it"], 2,
             "Release the pressure while your finger stays on the string. The note stops without a buzz."),
        along(B, f"{BOUNCE} {BOUNCE}", bpm=76, title="Short and bouncy"),
    ], minutes=4, xp=20),
    lesson("bass-6-4", "A Motown-style line", [
        explain("Busy, but always in the pocket", "Motown-era bass lines moved a lot: chord tones, notes that lean into the next chord, and pushes off the beat. This line is new, written in that spirit."),
        notes(B, ["C2", "E2", "G2", "Bb1", "A1"], hint="The first bar: C, E, G, then B flat leaning into A."),
        listen("One fret apart, or more?", [["Bb1"], ["A1"]], ["One fret", "More than one"], 0),
        tap([0, 1.5, 2, 2.5, 3, 3.5], bpm=60, bars=2),
        along(B, MOTOWN_1, bpm=60, title="Bars 1 and 2"),
        along(B, MOTOWN_2, bpm=60, title="Bars 3 and 4"),
        quiz("What does B flat do at the end of bar 1?", ["Repeats the root", "Leads down a fret into A", "Ends the line"], 1,
             "It's an approach note, one fret above A, the root of the next chord. It slides you into the next bar."),
        along(B, f"{MOTOWN} {MOTOWN}", bpm=72, title="Motown-style line"),
    ], minutes=6, xp=30),
    lesson("bass-6-5", "Challenge: groove set", [
        explain("Three grooves, one pocket", "Eighth notes, dotted rhythms and a moving line. Stay with the click, keep your fingers taking turns and enjoy the groove."),
        along(B, ROCK, bpm=80, title="Rock groove in E"),
        tap(DOTTED, bpm=72, bars=2),
        along(B, LONG_SHORT, bpm=72, title="Long-short on A, D and E"),
        quiz("In an eighth-note groove, which counts get a note?", ["Only the numbers", "Only beats 1 and 3", "Every number and every and"], 2),
        along(B, f"{BOUNCE} {BOUNCE}", bpm=80, title="Short and bouncy"),
        along(B, f"{MOTOWN} {MOTOWN}", bpm=76, title="Motown-style line"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("bass", "Bass", "From open strings to walking lines and grooves", "bass.electric.4", "waveform", "coral", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6,
])
