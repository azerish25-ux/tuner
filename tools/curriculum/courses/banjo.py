"""Banjo (5-string, open G): rolls, first chords, traditional tunes, left-hand ornaments and clawhammer.

Chord shapes list strings lowest-first in builder order, which on banjo starts with the short fifth string:
[5th (high G drone), 4th, 3rd, 2nd, 1st]. The fifth string is never fretted in this course. Melodies stay at or
below G4 so lib.position never puts a note on a fretted fifth string; G4 itself is the open fifth string.
Rolls are written note by note with every string fixed ("G3@3"), so the app hears each pluck in order.
"""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, play_chord, progression, quiz, rhythm, strum, tap, unit

B = "banjo"


def shape(spec):
    return {"type": "chord", "chord": spec}


def eighths(*ns):
    return " ".join(f"{n}:0.5" for n in ns)


def claw(*ns):
    """Clawhammer bum-ditty: each melody note is struck on the beat and held through the brush,
    then the thumb plays the open fifth string on the last eighth."""
    return " ".join(f"{n}:1.5 G4@5:0.5" for n in ns)


# ---------------------------------------------------------------- chord shapes ([5th, 4th, 3rd, 2nd, 1st])
G = chord(B, "G", "00000")
C = chord(B, "C", "02012", "02013")
D7 = chord(B, "D7", "x0210", "00210")        # the open G of string 5 isn't in D7, so it sits out
Em = chord(B, "Em", "02002", "02003")         # C with the first finger lifted
PINCH = chord(B, "G", "0xxx0")                # thumb on 5, middle on 1, together

# ---------------------------------------------------------------- rhythms
QUARTERS = [0, 1, 2, 3]
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
THREE_THREE_TWO = [0, 1.5, 3]
BUM_DITTY = [0, 1, 1.5, 2, 3, 3.5]

# ---------------------------------------------------------------- rolls (one bar of eighths each)
FWD_G = eighths("G3@3", "B3@2", "D4@1", "G4@5", "B3@2", "D4@1", "G3@3", "B3@2")
ALT_G = eighths("G3@3", "B3@2", "G4@5", "D4@1", "D3@4", "B3@2", "G4@5", "D4@1")
FWD_C = eighths("G3@3", "C4@2", "E4@1", "G4@5", "C4@2", "E4@1", "G3@3", "C4@2")
ALT_C = eighths("G3@3", "C4@2", "G4@5", "E4@1", "E3@4", "C4@2", "G4@5", "E4@1")
FWD_D7 = eighths("A3@3", "C4@2", "D4@1", "D3@4", "C4@2", "D4@1", "A3@3", "C4@2")   # thumb stays off string 5
ALT_D7 = eighths("A3@3", "C4@2", "D3@4", "D4@1", "A3@3", "C4@2", "D3@4", "D4@1")
FWD_EM = eighths("G3@3", "B3@2", "E4@1", "G4@5", "B3@2", "E4@1", "G3@3", "B3@2")

# ---------------------------------------------------------------- melodies (all traditional)
# Boil Them Cabbage Down, in G after the "Bile Them Cabbage Down" setting.
CABBAGE_BAR = "B3:1 B3:1 B3:0.5 A3:0.5 G3:0.5 B3:0.5"
CABBAGE_1 = f"{CABBAGE_BAR} C4:1.5 C4:1.5 D4:0.5 C4:0.5 {CABBAGE_BAR} A3:1.5 A3:0.5 A3:1 G3:0.5 A3:0.5"
CABBAGE_2 = (f"{CABBAGE_BAR} C4:0.5 D4:0.5 C4:0.5 B3:0.5 C4:1 B3:0.5 C4:0.5 "
             "D4:1 D4:1 B3:0.5 G3:0.5 A3:1 G3:0.5 B3:0.5 A3:0.5 G3:0.5 G3:2")
CABBAGE = f"{CABBAGE_1} {CABBAGE_2}"

# Cripple Creek (collected by Cecil Sharp, 1917), in G, sixteenths written as eighths.
CRIPPLE_HIGH = (f"{eighths('G4', 'F#4', 'G4', 'D4', 'E4', 'D4', 'B3', 'G3')} C4:0.5 D4:0.5 E4:0.5 C4:0.5 D4:1 D4:0.5 E4:0.5 "
                f"{eighths('G4', 'F#4', 'G4', 'D4', 'E4', 'G4', 'D4', 'C4')} B3:0.5 G3:0.5 A3:0.5 B3:0.5 G3:2")
CRIPPLE_LOW = (f"{eighths('B3', 'A3', 'B3', 'G3', 'A3', 'G3', 'E3', 'G3')} B3:0.5 G3:0.5 B3:0.5 G3:0.5 D3:1 G3:0.5 A3:0.5 "
               f"{eighths('B3', 'A3', 'B3', 'G3', 'A3', 'G3', 'E3', 'D3')} D3:0.5 E3:0.5 G3:0.5 A3:0.5 G3:2")
CRIPPLE = f"{CRIPPLE_HIGH} {CRIPPLE_LOW}"

# Cumberland Gap (recorded 1924 by Uncle Am Stuart), in G, an octave down.
CUMBERLAND_1 = ("D4:1 B3:0.5 A3:0.5 G3:0.5 B3:0.5 A3:0.5 C4:0.5 B3:0.5 E4:1 F#4:0.5 E4:2 "
                "D4:1 B3:0.5 A3:0.5 G3:0.5 B3:0.5 A3:0.5 G3:0.5 E3:0.5 G3:1 A3:0.5 G3:2")
CUMBERLAND_2 = (f"{eighths('D4', 'E4', 'D4', 'B3', 'G3', 'B3', 'E4', 'B3')} {eighths('E4', 'D4', 'E4', 'F#4', 'E4', 'F#4', 'G4', 'E4')} "
                f"{eighths('D4', 'E4', 'D4', 'B3', 'G3', 'B3', 'A3', 'G3')} E3:0.5 G3:1 A3:0.5 G3:2")
CUMBERLAND = f"{CUMBERLAND_1} {CUMBERLAND_2}"

# Shady Grove (published 1915), A dorian, an octave down; one high A changed to F sharp to stay off string 5.
SHADY_1 = ("A3:0.5 B3:0.5 A3:0.5 B3:0.5 A3:1 B3:1 D4:0.5 B3:0.5 A3:0.5 G3:2 B3:0.5 A3:1 A3:1 B3:1 D4:1 "
           "E4:4 E4:2 E4:2 D4:1 B3:0.5 A3:0.5 G3:2 B3:1 B3:1 D4:1 B3:1 A3:4")
SHADY_TURN = "G4:0.5 F#4:0.5 G4:0.5 F#4:0.5 G4:1 F#4:1 E4:0.5 D4:0.5 B3:0.5 A3:0.5 G3:2"
SHADY_2 = (f"{SHADY_TURN} G4:0.5 F#4:0.5 G4:0.5 F#4:0.5 G4:1 G4:0.5 F#4:0.5 E4:4 "
           f"{SHADY_TURN} A3:0.5 B3:0.5 A3:0.5 B3:0.5 D4:1 B3:1 A3:4")
SHADY = f"{SHADY_1} {SHADY_2}"

# Old Joe Clark (reported from East Tennessee in 1905), in G, after the Viola Ruth setting.
OJC_A = ("G3:1 G3:1 D4:0.5 C4:0.5 B3:1 G3:0.5 B3:0.5 A3:0.5 F#3:0.5 D3:1.5 D3:0.5 "
         "G3:1 G3:1 D4:0.5 C4:0.5 B3:1 G3:0.5 B3:0.5 A3:0.5 D3:0.5 G3:2")
OJC_B = ("D4:1 D4:0.5 E4:0.5 F4:0.5 E4:0.5 D4:0.5 C4:0.5 D4:0.5 E4:0.5 F4:0.5 E4:0.5 D4:1.5 G3:0.5 "
         "D4:1 D4:0.5 E4:0.5 F4:0.5 E4:0.5 D4:0.5 B3:0.5 G3:0.5 B3:0.5 A3:0.5 D3:0.5 G3:2")
OJC = f"{OJC_A} {OJC_B}"

# Skip to My Lou (1840s play-party song), in G: one melody note per half bar, the way clawhammer plays it.
SKIP = "B3:2 G3:2 B3:2 D4:2 A3:2 F#3:2 A3:2 C4:2 B3:2 G3:2 B3:2 D4:2 A3:2 B3:2 G3:4"
SKIP_CLAW_1 = claw("B3", "G3", "B3", "D4", "A3", "F#3", "A3", "C4")
SKIP_CLAW = f"{SKIP_CLAW_1} {claw('B3', 'G3', 'B3', 'D4', 'A3', 'B3')} G3:1.5 G4@5:0.5 G3:2"

# Left-hand ornaments: the picked note is short, the note you hammer, pull or slide to is long.
HAMMERS = "G3@3:0.5 A3@3:1.5 G3@3:0.5 A3@3:1.5 D3@4:0.5 E3@4:1.5 D3@4:0.5 E3@4:1.5"
HAMMER_ROLL = "G3@3:0.5 A3@3:0.5 B3@2:1 G3@3:0.5 A3@3:0.5 B3@2:1 G3@3:0.5 A3@3:0.5 B3@2:0.5 D4@1:0.5 G3@3:2"
PULLS = "E4@1:0.5 D4@1:1.5 E4@1:0.5 D4@1:1.5 A3@3:0.5 G3@3:1.5 A3@3:0.5 G3@3:1.5"
HAMMER_PULL = "G3@3:0.5 A3@3:0.5 G3@3:1 E4@1:0.5 D4@1:0.5 B3@2:1 G3@3:0.5 A3@3:0.5 G3@3:0.5 E3@4:0.5 D3@4:2"
SLIDES = "A3@3:0.5 B3@3:1.5 A3@3:0.5 B3@3:1.5 A3@3:0.5 B3@3:1.5 G3@3:2"
SLIDE_BAR = f"{eighths('A3@3', 'B3@3', 'D4@1', 'G4@5', 'B3@2', 'D4@1')} G3@3:1"
SLIDE_ROLL = f"{SLIDE_BAR} {SLIDE_BAR}"
LEFT_HAND = "G3@3:0.5 A3@3:0.5 B3@2:1 E4@1:0.5 D4@1:0.5 B3@2:1 A3@3:0.5 B3@3:0.5 D4@1:1 G3@3:2"

# Clawhammer drills.
STRIKE_THUMB = "D4@1:1 G4@5:1 D4@1:1 G4@5:1 B3@2:1 G4@5:1 B3@2:1 G4@5:1"
DOWN_STRINGS = "G3@3:1 G4@5:1 B3@2:1 G4@5:1 D4@1:1 G4@5:1 G3@3:2"
BUM_G = claw("B3", "D4", "B3", "G3")
BUM_C = claw("C4", "E4", "C4", "E3")
BUM_TUNE = f"{claw('B3', 'D4', 'C4', 'E4', 'D4', 'B3')} G3:4"

# ================================================================ 1. Hello, banjo

UNIT_1 = unit("bjo-1", "Hello, banjo", "Meet the five strings, tune to open G and find the short drone string.", [
    lesson("bjo-1-1", "Meet your banjo", [
        explain("Five strings, one short", "A banjo has four full-length strings and a fifth that starts partway up the neck, "
                "at its own little tuning peg. That short string is the banjo's signature sound.", part("strings")),
        explain("Counting the strings", "String 1 is the thin one nearest the floor. Strings 2, 3 and 4 follow toward your face. "
                "The short one on top is string 5.", fretboard(B, [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0)])),
        quiz("Which string is the short one?", ["String 1", "String 5", "String 4"], 1,
             "The fifth string lies next to string 4 but starts at the fifth fret, with its peg on the side of the neck."),
        notes(B, [("D4", 1)], hint="Pluck string 1, the thin one nearest the floor."),
        notes(B, [("G4", 5)], hint="Now the short string, string 5. Pluck it with your thumb."),
    ], minutes=3, xp=15),
    lesson("bjo-1-2", "Open G tuning", [
        explain("All five make G", "Standard banjo tuning is open G. From string 4 to string 1 it reads D, G, B, D, "
                "and the short fifth string is a high G. Strummed open, they make a G chord.", shape(G)),
        notes(B, [("D3", 4), ("G3", 3), ("B3", 2), ("D4", 1)], hint="Strings 4, 3, 2 and 1: D, G, B, D."),
        notes(B, [("G4", 5)], hint="String 5: high G."),
        quiz("What chord do the open strings make?", ["D", "C", "G"], 2,
             "G, B and D are the notes of a G chord. That is why this tuning is called open G."),
        explain("Tune up to the note", "Loosen a little below the note, then tighten up to it. "
                "Approaching from below keeps the string from slipping flat later.", part("head")),
        strum(G, QUARTERS, bpm=60, bars=2),
    ], minutes=4, xp=20),
    lesson("bjo-1-3", "Thumb, index, middle", [
        explain("Three picks, three fingers", "Bluegrass banjo uses a plastic thumb pick and two metal finger picks, on index "
                "and middle. The finger picks point down, curving the same way as your fingertips."),
        explain("Who plays what", "For now your thumb plays strings 3, 4 and 5, your index plays string 2 and your middle "
                "plays string 1. Rest your ring and little fingers lightly on the head.",
                fretboard(B, [(5, 0), (4, 0), (3, 0), (2, 0), (1, 0)])),
        quiz("Which finger plays string 2?", ["Middle", "Thumb", "Index"], 2,
             "Thumb takes strings 3, 4 and 5, index takes string 2 and middle takes string 1."),
        along(B, "G3@3:1 B3@2:1 D4@1:2 G3@3:1 B3@2:1 D4@1:2", bpm=60, title="Thumb, index, middle"),
        along(B, "D3@4:1 B3@2:1 G4@5:1 D4@1:1 D3@4:1 B3@2:1 G4@5:1 D4@1:1", bpm=60, title="All five strings"),
    ], minutes=4, xp=20),
    lesson("bjo-1-4", "The drone string", [
        explain("A note that never changes", "The fifth string is a drone: you play it open, between melody notes, "
                "and it rings over everything. In these lessons you never fret it."),
        listen("First string 5, then string 1. Which is higher?", [["G4"], ["D4"]], ["String 5", "String 1"], 0),
        quiz("Why does the fifth string sound so high?", ["It is the thickest string", "It is short and tuned to high G",
             "It is always fretted"], 1,
             "Being short lets it hold a high G. It sits on top of the melody like a bell."),
        along(B, "D4@1:1 G4@5:1 B3@2:1 G4@5:1 G3@3:1 G4@5:1 D3@4:1 G4@5:1", bpm=60, title="Drone between notes"),
        along(B, "B3@2:1 G4@5:1 D4@1:1 G4@5:1 B3@2:1 G4@5:1 G3@3:2", bpm=66, title="Thumb on the drone"),
    ], minutes=4, xp=20),
    lesson("bjo-1-5", "Open G challenge", [
        explain("Show what you know", "Tuned to open G, picks on, thumb ready for the drone. "
                "Play each string cleanly and let it ring."),
        notes(B, [("B3", 2), ("G4", 5), ("D3", 4), ("D4", 1), ("G3", 3)], hint="B, high G, low D, high D, G. Find each string by its note."),
        quiz("Which finger plays string 1?", ["Index", "Middle", "Thumb"], 1,
             "Thumb takes strings 3, 4 and 5, index takes string 2 and middle takes string 1."),
        strum(G, QUARTERS, bpm=66, bars=2),
        listen("String 3, then string 5. Which is higher?", [["G3"], ["G4"]], ["String 3", "String 5"], 1),
        along(B, "G3@3:1 B3@2:1 D4@1:1 G4@5:1 D3@4:1 B3@2:1 D4@1:1 G4@5:1 G3@3:4", bpm=66, title="Open G roll call"),
    ], minutes=4, xp=30, kind="challenge"),
])

# ================================================================ 2. Rolls

UNIT_2 = unit("bjo-2", "Rolls", "The right-hand patterns behind the rolling bluegrass sound: pinch, alternating thumb and forward roll.", [
    lesson("bjo-2-1", "The pinch", [
        explain("Thumb and middle together", "A pinch is your thumb and middle finger plucking at the same moment, on "
                "strings 5 and 1. It sounds like a little two-note chord and often starts or ends a phrase.", shape(PINCH)),
        listen("Pinch, or one note at a time?", [["G4", "D4"]], ["Together, a pinch", "One after the other"], 0),
        strum(PINCH, QUARTERS, bpm=60, bars=2),
        quiz("Which strings does a pinch play?", ["4 and 3", "5 and 1", "2 and 1"], 1,
             "Thumb on the short fifth string and middle on string 1, at the same moment."),
        strum(PINCH, QUARTERS, bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("bjo-2-2", "Alternating thumb roll", [
        explain("Thumb, index, thumb, middle", "This roll is eight even notes: thumb on 3, index on 2, thumb on 5, middle on 1, "
                "then thumb on 4, index on 2, thumb on 5, middle on 1.", rhythm(EIGHTHS)),
        tap(EIGHTHS, bpm=60, bars=2),
        along(B, f"{ALT_G} {ALT_G}", bpm=56, title="Alternating thumb, slowly"),
        quiz("Which finger plays every other note?", ["Index", "Middle", "Thumb"], 2,
             "Thumb, index, thumb, middle: the thumb plays every other note, which gives the roll its name."),
        along(B, f"{ALT_G} {ALT_G}", bpm=66, title="Alternating thumb roll"),
    ], minutes=4, xp=20),
    lesson("bjo-2-3", "Forward roll", [
        explain("Thumb, index, middle, again", "The forward roll moves one way, thumb then index then middle, over and over. "
                "Eight notes make thumb, index, middle twice, then thumb, index.", rhythm(THREE_THREE_TWO)),
        along(B, f"{FWD_G} {FWD_G}", bpm=56, title="Forward roll, slowly"),
        quiz("How does a forward roll fit into eight notes?", ["4 + 4", "3 + 3 + 2", "2 + 2 + 2 + 2"], 1,
             "Thumb, index, middle twice, then thumb, index. The accent shifts as it goes, which makes the rolling sound."),
        tap(THREE_THREE_TWO, bpm=66, bars=2),
        along(B, f"{FWD_G} {FWD_G}", bpm=66, title="Forward roll"),
    ], minutes=4, xp=20),
    lesson("bjo-2-4", "Rolls in time", [
        explain("Even beats, any roll", "A roll is only as good as its timing. Keep all eight notes even, like a ticking "
                "clock, and land the first note of each bar right on the beat."),
        along(B, f"{ALT_G} {ALT_G}", bpm=72, title="Alternating thumb at 72"),
        along(B, f"{FWD_G} {FWD_G}", bpm=72, title="Forward roll at 72"),
        quiz("You lose the beat in the middle of a roll. What now?", ["Stop and start the bar over", "Slow down until it feels right",
             "Keep the right hand moving and rejoin"], 2,
             "In a band the beat never waits. Keep the pattern going and catch the next bar."),
        strum(PINCH, QUARTERS, bpm=72, bars=1),
        along(B, f"{ALT_G} {FWD_G} {ALT_G} {FWD_G}", bpm=70, title="Switching rolls"),
    ], minutes=5, xp=25),
    lesson("bjo-2-5", "Roll challenge", [
        explain("Rolls, start to finish", "Pinch, alternating thumb and forward roll, all on open strings. "
                "Keep the eighths even and let every string ring."),
        tap(EIGHTHS, bpm=72, bars=2),
        strum(PINCH, QUARTERS, bpm=76, bars=2),
        quiz("Which roll goes thumb, index, middle, over and over?", ["Alternating thumb roll", "Forward roll", "Pinch"], 1),
        along(B, f"{ALT_G} {ALT_G}", bpm=76, title="Alternating thumb roll"),
        along(B, f"{FWD_G} {FWD_G}", bpm=76, title="Forward roll"),
    ], minutes=5, xp=30, kind="challenge"),
])

# ================================================================ 3. Chords with rolls

UNIT_3 = unit("bjo-3", "Chords with rolls", "Fret G, C, D7 and E minor and keep the roll going through the changes.", [
    lesson("bjo-3-1", "The C chord", [
        explain("C: three fingers", "First finger on fret 1 of string 2, second finger on fret 2 of string 4, third finger "
                "on fret 2 of string 1. Strings 3 and 5 ring open.", shape(C)),
        play_chord(C),
        strum(C, QUARTERS, bpm=60, bars=2),
        quiz("Do you fret the fifth string for C?", ["Yes, at fret 2", "No, it rings open", "Yes, at fret 5"], 1,
             "The open high G belongs to the C chord, so it rings as it is. You never fret it in these lessons."),
        along(B, f"{FWD_C} {FWD_C}", bpm=56, title="Forward roll on C"),
        along(B, f"{ALT_C} {ALT_C}", bpm=60, title="Alternating thumb on C"),
    ], minutes=5, xp=25),
    lesson("bjo-3-2", "D7", [
        explain("D7: two fingers", "First finger on fret 1 of string 2, second finger on fret 2 of string 3. "
                "Strings 4 and 1 ring open. Leave the fifth string out; its G clashes with D7.", shape(D7)),
        play_chord(D7),
        strum(D7, QUARTERS, bpm=60, bars=2),
        listen("Which chord wants to move on?", [["D3", "A3", "C4", "D4"], ["G3", "B3", "D4", "G4"]], ["The first", "The second"], 0),
        quiz("What does your thumb do on D7?", ["Plays string 5 as usual", "Frets string 5", "Stays on strings 3 and 4"], 2,
             "The open G of string 5 isn't part of D7. For now your thumb keeps to strings 3 and 4."),
        along(B, f"{ALT_D7} {ALT_D7}", bpm=56, title="Alternating thumb on D7"),
    ], minutes=5, xp=25),
    lesson("bjo-3-3", "G, C and D7", [
        explain("Three chords, many songs", "G is home, C steps away and D7 pulls you back. "
                "Change on the first beat of each bar and keep your right hand moving."),
        progression([(G, 1), (C, 1), (D7, 1), (G, 1)], QUARTERS, bpm=60),
        quiz("Which chord pulls you back to G?", ["C", "D7", "G"], 1,
             "D7 contains C, which leans down to B in the G chord. That pull is why so many songs end D7 to G."),
        along(B, f"{FWD_G} {FWD_C} {FWD_D7} {FWD_G}", bpm=56, title="Forward roll through the changes"),
        progression([(G, 1), (C, 1), (D7, 1), (G, 1)], EIGHTHS, bpm=60),
        along(B, f"{ALT_G} {ALT_C} {ALT_D7} {ALT_G}", bpm=60, title="Alternating thumb through the changes"),
    ], minutes=5, xp=25),
    lesson("bjo-3-4", "E minor", [
        explain("E minor: lift one finger", "Make C, then lift your first finger off string 2. Two fingers stay on fret 2, "
                "strings 4 and 1, and the chord turns darker: E minor.", shape(Em)),
        play_chord(Em),
        listen("Major or minor?", [["E3", "G3", "B3", "E4"]], ["Major, bright", "Minor, darker"], 1),
        strum(Em, QUARTERS, bpm=60, bars=2),
        along(B, f"{FWD_EM} {FWD_EM}", bpm=60, title="Forward roll on E minor"),
        progression([(G, 1), (Em, 1), (C, 1), (D7, 1)], EIGHTHS, bpm=60),
    ], minutes=5, xp=25),
    lesson("bjo-3-5", "Chord challenge", [
        explain("Fret, roll, change", "Four chords and two rolls. Keep the right hand steady even while the left hand "
                "is busy changing."),
        play_chord(C),
        play_chord(D7),
        strum(Em, QUARTERS, bpm=70, bars=1),
        quiz("Which string sits out on D7?", ["String 1", "String 3", "String 5"], 2,
             "The open G of string 5 isn't part of D7. For now your thumb keeps to strings 3 and 4."),
        along(B, f"{ALT_G} {ALT_C} {ALT_D7} {ALT_G}", bpm=64, title="Alternating thumb: G, C, D7, G"),
        along(B, f"{FWD_G} {FWD_EM} {FWD_C} {FWD_D7} {FWD_G}", bpm=66, title="Forward roll: G, E minor, C, D7, G"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 4. First melodies

UNIT_4 = unit("bjo-4", "First melodies", "Four traditional tunes, with the drone string ringing in among the melody.", [
    lesson("bjo-4-1", "Boil Them Cabbage Down", [
        explain("Melody on top", "Here the melody is the main event: pick each note with the finger that owns its string. "
                "Strings 3, 2 and 1 carry this whole tune."),
        notes(B, ["B3", "A3", "G3", "C4", "D4"], hint="String 2 open, string 3 fret 2, string 3 open, string 2 fret 1, string 1 open."),
        along(B, CABBAGE_1, bpm=72, title="First half"),
        quiz("Which note does the tune end on?", ["B", "D", "G"], 2,
             "Tunes in G come home to G, here the open third string."),
        along(B, CABBAGE_2, bpm=72, title="Second half"),
        along(B, CABBAGE, bpm=80, title="Boil Them Cabbage Down"),
    ], minutes=5, xp=30, kind="song"),
    lesson("bjo-4-2", "Cripple Creek", [
        explain("High part, low part", "Cripple Creek has a high part that uses the fifth string as a melody note, and a low "
                "part down on strings 3 and 4. Take each part slowly first."),
        notes(B, [("G4", 5), ("F#4", 1), ("E4", 1)], hint="String 5 open, then string 1 at fret 4 and fret 2."),
        along(B, CRIPPLE_HIGH, bpm=66, title="High part"),
        quiz("Where does the high G in the first bar come from?", ["String 1, fret 5", "The open fifth string", "String 3, open"], 1,
             "The drone doubles as a melody note here. Your thumb plays it, right on the beat."),
        along(B, CRIPPLE_LOW, bpm=66, title="Low part"),
        along(B, CRIPPLE, bpm=72, title="Cripple Creek"),
    ], minutes=5, xp=30, kind="song"),
    lesson("bjo-4-3", "Cumberland Gap", [
        explain("A tune named for a mountain pass", "Cumberland Gap is the pass early settlers took into Kentucky. "
                "The tune climbs to E and F♯ on string 1, so your second and fourth fingers get busy."),
        notes(B, ["E4", "F#4", "E4", "D4"], hint="String 1: fret 2, fret 4, fret 2, then open."),
        along(B, CUMBERLAND_1, bpm=70, title="First part"),
        quiz("Where do you play F♯ in this tune?", ["String 2, fret 4", "String 1, fret 4", "String 5, fret 1"], 1,
             "F♯ is four frets above the open D of string 1. The fifth string is never fretted here."),
        along(B, CUMBERLAND_2, bpm=70, title="Second part"),
        along(B, CUMBERLAND, bpm=76, title="Cumberland Gap"),
    ], minutes=5, xp=30, kind="song"),
    lesson("bjo-4-4", "Shady Grove", [
        explain("Mountain minor", "Shady Grove has the dark, old sound players call mountain minor. "
                "It comes to rest on A instead of G, and the high G of the fifth string sings against it."),
        notes(B, ["A3", "B3", "D4", "E4"], hint="String 3 fret 2, string 2 open, string 1 open, string 1 fret 2."),
        along(B, SHADY_1, bpm=72, title="First part"),
        listen("Which sounds darker?", [["A3", "C4", "E4"], ["G3", "B3", "D4"]], ["The first", "The second"], 0),
        along(B, SHADY_2, bpm=72, title="Second part"),
        along(B, SHADY, bpm=78, title="Shady Grove"),
    ], minutes=5, xp=30, kind="song"),
    lesson("bjo-4-5", "Tune challenge", [
        explain("Four tunes, steady time", "Play each tune through at a steady tempo. If a note slips, keep your picking hand "
                "moving and catch the next beat. That is how real jams work."),
        along(B, CABBAGE, bpm=84, title="Boil Them Cabbage Down"),
        quiz("Which tune comes to rest on A instead of G?", ["Cripple Creek", "Cumberland Gap", "Shady Grove"], 2,
             "Shady Grove is in mountain minor, centered on A. The others come home to G."),
        along(B, CRIPPLE_HIGH, bpm=72, title="Cripple Creek, high part"),
        along(B, CUMBERLAND, bpm=80, title="Cumberland Gap"),
        along(B, SHADY_2, bpm=80, title="Shady Grove, second part"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 5. Hammer-ons, pull-offs and slides

UNIT_5 = unit("bjo-5", "Hammer-ons, pull-offs, slides", "Sound notes with the fretting hand, then use them in Old Joe Clark.", [
    lesson("bjo-5-1", "Hammer-ons", [
        explain("Hammer-on", "Pick an open string, then snap a fingertip down just behind fret 2. "
                "The new note sounds from the tap alone, with no second pick.", fretboard(B, [(3, 2, 2)])),
        notes(B, [("G3", 3), ("A3", 3)], hint="Pick string 3 open, then hammer fret 2 with your second finger."),
        along(B, HAMMERS, bpm=60, title="Open to fret 2"),
        quiz("How many times do you pick for a hammer-on?", ["Twice, once per note", "Once, for the first note", "Not at all"], 1,
             "The pick sounds the first note. The second comes from your finger striking the string."),
        along(B, HAMMER_ROLL, bpm=64, title="Hammer and roll"),
    ], minutes=4, xp=20),
    lesson("bjo-5-2", "Pull-offs", [
        explain("Pull-off", "Fret a note, pick it, then pull your finger slightly sideways as you lift. "
                "That flick plucks the open string, so a second note sounds without the pick."),
        notes(B, [("E4", 1), ("D4", 1)], hint="Pick string 1 at fret 2, then pull off to open."),
        along(B, PULLS, bpm=60, title="Fret 2 to open"),
        quiz("Which way does your finger move in a pull-off?", ["Straight up, off the string", "Along the string to the next fret",
             "Slightly sideways, plucking the string"], 2,
             "Lifting straight up only stops the note. A small sideways flick plucks the open string."),
        along(B, HAMMER_PULL, bpm=64, title="Hammer, then pull"),
    ], minutes=4, xp=20),
    lesson("bjo-5-3", "Slides", [
        explain("The bluegrass slide", "Fret string 3 at fret 2, pick it, and slide the same finger up to fret 4 while "
                "pressing. A to B in one smooth glide is a classic banjo sound.", fretboard(B, [(3, 2, 2), (3, 4, 2)])),
        along(B, SLIDES, bpm=60, title="String 3, fret 2 to 4"),
        quiz("What keeps a slide sounding?", ["A second pick stroke", "Steady pressure while you move", "Lifting at the end"], 1,
             "Only the first note is picked. Keep pressing as you glide, or the note dies on the way."),
        along(B, SLIDE_ROLL, bpm=64, title="Slide into a roll"),
        along(B, LEFT_HAND, bpm=66, title="Hammer, pull, slide"),
    ], minutes=4, xp=20),
    lesson("bjo-5-4", "Old Joe Clark", [
        explain("The old-time F", "Old Joe Clark is in G, but its second part uses F instead of F♯, on string 1 at fret 3. "
                "That lowered note gives the tune its old-time sound."),
        notes(B, ["E4", "F4", "E4", "D4"], hint="String 1: fret 2, fret 3, fret 2, open. Try hammering from 2 to 3."),
        along(B, OJC_A, bpm=70, title="First part"),
        quiz("Which note gives the second part its old-time color?", ["F instead of F♯", "C instead of C♯", "G, the home note"], 0,
             "G major uses F♯. Lowering it to F gives the mixolydian sound that runs through old-time and bluegrass music."),
        along(B, OJC_B, bpm=70, title="Second part"),
        along(B, OJC, bpm=78, title="Old Joe Clark"),
    ], minutes=6, xp=35, kind="song"),
    lesson("bjo-5-5", "Left-hand challenge", [
        explain("Left hand, meet right hand", "Hammer-ons, pull-offs and slides, then Old Joe Clark. "
                "Pick only where you need to and let your fretting hand do the rest."),
        along(B, HAMMER_ROLL, bpm=70, title="Hammer and roll"),
        along(B, HAMMER_PULL, bpm=70, title="Hammer, then pull"),
        quiz("Which move glides a fretted note up to a higher fret?", ["A hammer-on", "A pull-off", "A slide"], 2),
        along(B, SLIDE_ROLL, bpm=70, title="Slide into a roll"),
        along(B, OJC, bpm=84, title="Old Joe Clark"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ================================================================ 6. Clawhammer

UNIT_6 = unit("bjo-6", "Clawhammer", "A different right hand: strike down with a fingernail and catch the drone with your thumb.", [
    lesson("bjo-6-1", "A new right hand", [
        explain("Claw shape", "Clawhammer uses no picks. Curl your hand into a loose claw and strike down on a string with "
                "the back of your index or middle fingernail, moving from the wrist and forearm."),
        explain("The thumb catches string 5", "As your hand strikes, the thumb comes to rest on the fifth string. "
                "On the next beat it pushes through that string as your hand lifts."),
        quiz("Which way does your fingernail move in clawhammer?", ["Up, like a finger pick", "Down, toward the floor", "Side to side"], 1,
             "Clawhammer strikes down with the nail. The fingers never pluck upward."),
        along(B, STRIKE_THUMB, bpm=60, title="Strike, then thumb"),
        along(B, DOWN_STRINGS, bpm=64, title="Down the strings"),
    ], minutes=4, xp=20),
    lesson("bjo-6-2", "Bum-ditty", [
        explain("Bum, dit, ty", "The basic clawhammer rhythm sounds like its name. Bum: strike one note on the beat. "
                "Dit: brush down across the strings. Ty: your thumb plays string 5.", rhythm(BUM_DITTY)),
        tap(BUM_DITTY, bpm=60, bars=2),
        quiz("Which part of bum-ditty does the thumb play?", ["Bum, the first", "Dit, the middle", "Ty, the last"], 2,
             "Bum is a single note, dit is a brush and ty is the thumb on the fifth string."),
        strum(G, BUM_DITTY, bpm=60, bars=2),
        along(B, BUM_G, bpm=60, title="Bum, brush, thumb"),
        strum(G, BUM_DITTY, bpm=70, bars=2),
    ], minutes=5, xp=25),
    lesson("bjo-6-3", "Melody in the bum", [
        explain("The melody rides on bum", "In clawhammer the melody notes fall on the bum strikes. The brush and thumb "
                "fill in around them, so tune and rhythm come out together."),
        along(B, BUM_C, bpm=60, title="Bum-ditty on C"),
        progression([(G, 1), (C, 1), (G, 1), (C, 1)], BUM_DITTY, bpm=60),
        quiz("Where do the melody notes go in bum-ditty?", ["On the ty, the thumb", "On the bum, the strike", "On the dit, the brush"], 1,
             "The bum lands on the beat, so that is where the melody goes. Dit and ty keep the rhythm rolling."),
        along(B, BUM_TUNE, bpm=64, title="A melody in bum-ditty"),
    ], minutes=5, xp=25),
    lesson("bjo-6-4", "Skip to My Lou", [
        explain("A play-party tune", "Skip to My Lou was a party game in the 1840s. In clawhammer each melody note is a bum, "
                "followed by a brush and the thumb on string 5."),
        along(B, SKIP, bpm=70, title="The melody alone"),
        tap(BUM_DITTY, bpm=66, bars=2),
        quiz("What does your thumb play after each brush?", ["The melody note", "The open fifth string", "Nothing; it rests"], 1,
             "Bum, dit, ty: the ty is always the thumb on the short fifth string."),
        along(B, SKIP_CLAW_1, bpm=66, title="First half, clawhammer"),
        along(B, SKIP_CLAW, bpm=72, title="Skip to My Lou"),
    ], minutes=5, xp=30, kind="song"),
    lesson("bjo-6-5", "Clawhammer challenge", [
        explain("Strike, brush, thumb", "Everything in clawhammer comes back to bum-ditty. "
                "Keep the motion loose and the thumb ready, and the melody takes care of itself."),
        tap(BUM_DITTY, bpm=72, bars=2),
        strum(G, BUM_DITTY, bpm=72, bars=2),
        quiz("Which hand shape does clawhammer use?", ["Fingers plucking up with picks", "A flat pick", "A loose claw, striking down"], 2),
        along(B, BUM_C, bpm=70, title="Bum-ditty on C"),
        along(B, SKIP_CLAW, bpm=78, title="Skip to My Lou"),
    ], minutes=5, xp=35, kind="challenge"),
])

COURSE = course("banjo", "Banjo", "Five-string, open G: rolls, old-time tunes and clawhammer", "banjo.five.5",
                "music.note", "amber", [UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6])
