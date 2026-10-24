"""Ukulele: from the four open strings (G C E A, re-entrant) to a first set of public-domain songs."""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, play_chord, progression, quiz, rhythm, staff, strum, tap, unit

U = "ukulele"

# Chord shapes, string 4 (G) first: "0003" is C.
C = chord(U, "C", "0003", "0003")
Am = chord(U, "Am", "2000", "2000")
F = chord(U, "F", "2010", "2010")
G = chord(U, "G", "0232", "0132")
G7 = chord(U, "G7", "0212", "0213")
C7 = chord(U, "C7", "0001", "0001")
Dm = chord(U, "Dm", "2210", "2310")
Em = chord(U, "Em", "0432", "0321")
D = chord(U, "D", "2220", "1230")
A = chord(U, "A", "2100", "2100")
E7 = chord(U, "E7", "1202", "1203")

# Strum patterns (beats in one 4/4 bar).
DOWNS = [0, 1, 2, 3]
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
D_DU = [0, 1, 1.5, 2, 3, 3.5]             # down, down-up, down, down-up
ISLAND = [0, 1, 1.5, 2.5, 3, 3.5]         # D, DU, UDU

# Chord sounds for listening steps (string 4 to string 1).
SOUND_C = ["G4", "C4", "E4", "C5"]
SOUND_AM = ["A4", "C4", "E4", "A4"]
SOUND_F = ["A4", "C4", "F4", "A4"]
SOUND_G = ["G4", "D4", "G4", "B4"]
SOUND_G7 = ["G4", "D4", "F4", "B4"]
SOUND_C7 = ["G4", "C4", "E4", "Bb4"]
SOUND_EM = ["G4", "E4", "G4", "B4"]
SOUND_E7 = ["G#4", "D4", "E4", "B4"]

# Melodies. G4@2 keeps G on string 2, fret 3, so tunes stay on strings 1-3.
ODE_1 = "E4 E4 F4 G4@2 G4@2 F4 E4 D4 C4 C4 D4 E4 E4:1.5 D4:0.5 D4:2"
ODE_2 = "E4 E4 F4 G4@2 G4@2 F4 E4 D4 C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2"
TWINKLE_A = "C4 C4 G4@2 G4@2 A4 A4 G4@2:2 F4 F4 E4 E4 D4 D4 C4:2"
TWINKLE_B = "G4@2 G4@2 F4 F4 E4 E4 D4:2 G4@2 G4@2 F4 F4 E4 E4 D4:2"
AURA_LEE = "D4 G4@2 F#4 G4@2 A4 E4 A4:2 G4@2 F#4 E4 F#4 G4@2:4"
# Oh! Susanna, verse (2/4: two beats to a bar, eighth notes are half a beat).
SUSANNA_1 = "C4:0.5 D4:0.5 E4:0.5 G4@2:0.5 G4@2:0.5 A4:0.5 G4@2:0.5 E4:0.5 C4:0.5 D4:0.5 E4:0.5 E4:0.5 D4:0.5 C4:0.5"
SUSANNA_2 = "C4:0.5 D4:0.5 E4:0.5 G4@2:0.5 G4@2:0.5 A4:0.5 G4@2:0.5 E4:0.5 C4:0.5 D4:0.5 E4:0.5 E4:0.5 D4:0.5 D4:0.5 C4:2"
# Camptown Races (2/4).
CAMPTOWN_1 = "G4@2:0.5 G4@2:0.5 E4:0.5 G4@2:0.5 A4:0.5 G4@2:0.5 E4:1 E4:1 D4:1 E4:1 D4:1"
CAMPTOWN_2 = "G4@2:0.5 G4@2:0.5 E4:0.5 G4@2:0.5 A4:0.5 G4@2:0.5 E4:1 D4:1 E4:0.5 D4:0.5 C4:2"
# Clementine (3/4, key of F), starting with a two-beat rest before the pickup.
CLEMENTINE_1 = "F4:0.5 F4:0.5 F4:1.5 C4:0.5 A4:0.5 A4:0.5 A4:1.5 F4:0.5 F4:0.5 A4:0.5 C5:1.5 C5:0.5 Bb4:0.5 A4:0.5"
CLEMENTINE_2 = "G4@2:0.5 A4:0.5 Bb4:1.5 Bb4:0.5 A4:0.5 G4@2:0.5 A4:1.5 F4:0.5 F4:0.5 A4:0.5 G4@2:1.5 C4:0.5 E4:0.5 G4@2:0.5 F4:3"
# Red River Valley (4/4, key of F), each line starts with a two-beat pickup.
RIVER_1 = "C4 F4 A4:2 A4 G4@2 F4:2 G4@2 F4 D4 F4:5"
RIVER_2 = "C4 F4 A4:2 A4 A4 C5:2 Bb4 A4 G4@2:4"
RIVER_3 = "C4 F4 A4:2 A4 G4@2 F4:2 G4@2 A4 C5 Bb4:5"
RIVER_4 = "D4 C#4 C4:2 F4 F4 A4:2 G4@2 G4@2 F4:4"

SUSANNA = f"r:1 {SUSANNA_1} D4:1 {SUSANNA_2}"
CAMPTOWN = f"{CAMPTOWN_1} {CAMPTOWN_2}"
CLEMENTINE = f"r:2 {CLEMENTINE_1} G4@2:2 {CLEMENTINE_2}"
RIVER = f"r:2 {RIVER_1} {RIVER_2.replace('G4@2:4', 'G4@2:6')} {RIVER_3} {RIVER_4}"

UNIT_1 = unit("uke-1", "Hello, ukulele", "Hold it, meet G C E A, play your first notes.", [
    lesson("uke-1-1", "Meet your ukulele", [
        explain("Four strings, one small body", "Rest the body against your chest with the neck pointing left. The string nearest the floor is string 1. It plays the highest open note.",
                part("strings")),
        explain("Turn to tune", "Each string has a tuning peg on the head. Turning it changes the pitch. Timbre listens and tells you which way.",
                part("head")),
        quiz("Which string is string 1?", ["The one nearest your face", "The one nearest the floor", "The one in the middle"], 1,
             "Strings count up from the floor side: 1, 2, 3, 4."),
        notes(U, [("A4", 1)], hint="Pluck string 1 with your thumb and let it ring."),
        notes(U, [("E4", 2)], hint="Now string 2, the next one up."),
    ], minutes=3, xp=15),
    lesson("uke-1-2", "G C E A, the open strings", [
        explain("G C E A", "From string 4 down to string 1, the open strings are G, C, E, A. Try: Good Cooks Eat Apples.",
                fretboard(U, [(4, 0), (3, 0), (2, 0), (1, 0)])),
        notes(U, [("G4", 4), ("C4", 3)], hint="Play strings 4 and 3, one at a time."),
        notes(U, [("E4", 2), ("A4", 1)], hint="Now strings 2 and 1."),
        quiz("What is string 3 called?", ["G", "C", "E", "A"], 1, visual=fretboard(U, [(3, 0)])),
        listen("Which is higher?", [["C4"], ["A4"]], ["The first", "The second"], 1),
        tap(DOWNS, bpm=60, bars=2),
        along(U, "G4@4:2 C4@3:2 E4@2:2 A4@1:2 E4@2:2 C4@3:2 G4@4:4", bpm=60, title="Open-string roll call"),
    ], minutes=4, xp=20),
    lesson("uke-1-3", "The high G string", [
        explain("String 4 breaks the pattern", "On most instruments the strings get lower as you go up. On ukulele, string 4 (G) is higher than string 3 (C). This is called re-entrant tuning.",
                fretboard(U, [(4, 0), (3, 0)])),
        listen("Which sounds higher?", [["G4"], ["C4"]], ["The first", "The second"], 0),
        explain("Why it's tuned that way", "The high G keeps every chord close together and bright. It is the sweet, ringing sound people know as ukulele."),
        notes(U, [("C4", 3), ("G4", 4)], hint="String 3, then string 4. Hear the jump up?"),
        quiz("Which open string plays the lowest note?", ["String 4, G", "String 1, A", "String 3, C"], 2,
             "With re-entrant tuning, C on string 3 is the lowest note on the ukulele."),
        along(U, "C4@3 G4@4 C4@3 G4@4 E4@2 A4@1 E4@2:2", bpm=66, title="Low, high, low, high"),
    ], minutes=4, xp=20),
    lesson("uke-1-4", "Your first fretted notes", [
        explain("Press just behind the fret", "Put your fingertip just behind the metal fret, not on top of it. Press firmly enough for a clean ring.",
                fretboard(U, [(1, 2, 2)])),
        notes(U, [("B4", 1)], hint="String 1, fret 2, second finger."),
        notes(U, [("C5", 1)], hint="String 1, fret 3, third finger."),
        quiz("Where do you press?", ["Just behind the fret", "On top of the fret", "Between two frets, in the middle"], 0),
        notes(U, ["A4", "B4", "C5"], hint="Open, fret 2, fret 3: A, B, C."),
        along(U, "A4 B4 C5:2 C5 B4 A4:2", bpm=66, title="Up and back"),
    ], minutes=4, xp=20),
    lesson("uke-1-5", "Notes on strings 2 and 3", [
        explain("Same fingers, new strings", "Fret 2 on string 3 is D. Fret 1 on string 2 is F. Fret 3 on string 2 is G, the same note as open string 4.",
                fretboard(U, [(3, 2, 2), (2, 1, 1), (2, 3, 3)])),
        notes(U, ["C4", "D4"], hint="String 3: open, then fret 2."),
        notes(U, ["E4", "F4", ("G4", 2)], hint="String 2: open, fret 1, fret 3."),
        listen("Same note or different?", [["G4"], ["G4"]], ["Same", "Different"], 0),
        quiz("Fret 3 on string 2 matches which open string?", ["String 4, G", "String 1, A", "String 3, C"], 0,
             "Both are G. Two places, one note."),
        along(U, "C4 D4 E4 F4 G4@2:2 r:2 G4@2 F4 E4 D4 C4:4", bpm=66, title="Five-note climb"),
    ], minutes=4, xp=20),
    lesson("uke-1-6", "Challenge: first notes", [
        explain("Put it together", "Open strings, the high G and your first fretted notes. Take it slowly and let each note ring."),
        quiz("Name the open strings from 4 to 1.", ["A E C G", "E A D G", "G C E A", "G D A E"], 2),
        listen("Which one is the open G string?", [["C4"], ["G4"]], ["The first", "The second"], 1),
        notes(U, [("G4", 4), ("C4", 3), ("E4", 2), ("A4", 1)], hint="All four open strings, 4 to 1."),
        notes(U, ["D4", "F4", "B4", "C5"], hint="Your fretted notes: D, F, B, C."),
        along(U, "C4 E4 G4@2 A4 C5:2 A4:2 G4@2 E4 D4 F4 E4:2 C4:2", bpm=70, title="First-notes medley"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_2 = unit("uke-2", "First chords", "C, A minor, F, G7 and G: the chords behind countless songs.", [
    lesson("uke-2-1", "Your first chord: C", [
        explain("One finger, four strings", "C uses your third finger on fret 3 of string 1. The other three strings ring open.",
                {"type": "chord", "chord": C}),
        play_chord(C),
        explain("Strum with your thumb", "Brush down across all four strings with the pad of your thumb, from string 4 to string 1. Keep your wrist loose.",
                rhythm(DOWNS)),
        tap(DOWNS, bpm=60, bars=2),
        strum(C, DOWNS, bpm=60, bars=2),
        quiz("Which finger plays the C chord?", ["First finger", "Third finger", "Little finger"], 1,
             "Your third finger reaches fret 3 without a stretch."),
        strum(C, DOWNS, bpm=66, bars=4),
    ], minutes=4, xp=20),
    lesson("uke-2-2", "A minor and your first change", [
        explain("A minor: one finger again", "Put your second finger on fret 2 of string 4 and strum all four strings. A minor sounds darker than C.",
                {"type": "chord", "chord": Am}),
        play_chord(Am),
        listen("Which chord sounds darker?", [SOUND_C, SOUND_AM], ["The first", "The second"], 1),
        explain("Change early, not late", "Lift the finger you don't need and place the new one while the last strum still rings. Look ahead to the next chord."),
        strum(C, DOWNS, bpm=60, bars=2),
        strum(Am, DOWNS, bpm=60, bars=2),
        progression([(C, 2), (Am, 2), (C, 2), (Am, 2)], DOWNS, bpm=60),
    ], minutes=4, xp=20),
    lesson("uke-2-3", "F: two fingers", [
        explain("F uses two fingers", "First finger on fret 1 of string 2, second finger on fret 2 of string 4. Strings 3 and 1 ring open.",
                {"type": "chord", "chord": F}),
        play_chord(F),
        quiz("Which chord shares a finger with F?", ["C", "A minor", "Neither"], 1,
             "Your second finger sits on fret 2 of string 4 for both. Keep it down when you change."),
        strum(F, DOWNS, bpm=60, bars=2),
        progression([(Am, 2), (F, 2), (Am, 2), (F, 2)], DOWNS, bpm=60),
        progression([(C, 2), (Am, 2), (F, 2), (C, 2)], DOWNS, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-2-4", "G7, the chord that leads home", [
        explain("G7: a triangle of fingers", "First finger on fret 1 of string 2, second on fret 2 of string 3, third on fret 2 of string 1. Strum all four.",
                {"type": "chord", "chord": G7}),
        play_chord(G7),
        explain("A chord that wants to go home", "G7 sounds unfinished. Play C after it and the tension lets go. That pull is why so many songs put G7 before C."),
        listen("Does this end at home or leave you hanging?", [SOUND_C, SOUND_G7], ["Home", "Hanging"], 1),
        strum(G7, DOWNS, bpm=60, bars=2),
        progression([(G7, 2), (C, 2), (G7, 2), (C, 2)], DOWNS, bpm=60),
    ], minutes=4, xp=20),
    lesson("uke-2-5", "G: three fingers", [
        explain("G major", "First finger on fret 2 of string 3, second on fret 2 of string 1, third on fret 3 of string 2. Arch your fingers so string 4 rings.",
                {"type": "chord", "chord": G}),
        play_chord(G),
        quiz("G and G7 both press which spot?", ["Fret 1 of string 2", "Fret 3 of string 1", "Fret 2 of string 3"], 2,
             "Both chords put a finger on fret 2 of string 3. Use it as your anchor."),
        strum(G, DOWNS, bpm=60, bars=2),
        listen("Which one is G7, the one with more tension?", [SOUND_G, SOUND_G7], ["The first", "The second"], 1),
        progression([(C, 2), (G, 2), (C, 2), (G, 2)], DOWNS, bpm=60),
    ], minutes=4, xp=20),
    lesson("uke-2-6", "Challenge: five chords", [
        explain("Five chords, one hand", "C, A minor, F, G7 and G cover hundreds of songs. Make each shape clean, then keep the beat as you change."),
        quiz("Which chord uses only one finger?", ["F", "G7", "G", "C"], 3),
        play_chord(Am),
        play_chord(F),
        play_chord(G),
        strum(G7, DOWNS, bpm=66, bars=2),
        progression([(C, 2), (Am, 2), (F, 2), (G7, 2)], DOWNS, bpm=66),
        progression([(C, 2), (F, 2), (G, 2), (C, 2)], DOWNS, bpm=66),
    ], minutes=6, xp=30, kind="challenge"),
])

UNIT_3 = unit("uke-3", "Strumming", "Steady downs, down-ups and the island strum.", [
    lesson("uke-3-1", "Steady down strums", [
        explain("Your hand is a clock", "Strum down on every beat: 1, 2, 3, 4. Use the nail of your index finger. When you change chords, your hand keeps moving.",
                rhythm(DOWNS)),
        tap(DOWNS, bpm=66, bars=2),
        strum(C, DOWNS, bpm=70, bars=4),
        quiz("What should your hand do while you change chords?", ["Keep the beat going", "Stop and wait", "Speed up"], 0,
             "A late chord is better than a broken beat. Keep strumming, even if a string buzzes."),
        strum(Am, DOWNS, bpm=70, bars=4),
        progression([(C, 2), (Am, 2), (F, 2), (G7, 2)], DOWNS, bpm=70),
    ], minutes=4, xp=20),
    lesson("uke-3-2", "Down and up", [
        explain("Up strums live between beats", "Count 1 and 2 and 3 and 4 and. Strum down on the numbers, up on each and. Your hand never stops moving.",
                rhythm(EIGHTHS)),
        tap(EIGHTHS, bpm=60, bars=2),
        explain("Lighter on the way up", "Up strums mostly catch strings 1 and 2. Brush them with the pad of your finger, a little softer than the downs."),
        strum(C, EIGHTHS, bpm=60, bars=2),
        strum(G7, EIGHTHS, bpm=60, bars=2),
        quiz("Where do up strums fall?", ["On the and between beats", "On beats 1 and 3", "Only at the end of a bar"], 0),
        progression([(C, 2), (G7, 2), (C, 2), (G7, 2)], EIGHTHS, bpm=60),
    ], minutes=5, xp=20),
    lesson("uke-3-3", "Down, down-up", [
        explain("Leave a gap", "Down on 1, down-up on 2, down on 3, down-up on 4. Your hand still swings up after 1 and 3; it just misses the strings.",
                rhythm(D_DU)),
        tap(D_DU, bpm=60, bars=2),
        strum(C, D_DU, bpm=60, bars=2),
        strum(F, D_DU, bpm=60, bars=2),
        quiz("What does your hand do on the and of 1?", ["Swings up without touching", "Stops", "Strums up hard"], 0,
             "A silent up stroke keeps your hand in time for the next down.", visual=rhythm(D_DU)),
        progression([(C, 2), (Am, 2), (F, 2), (C, 2)], D_DU, bpm=66),
    ], minutes=4, xp=20),
    lesson("uke-3-4", "The island strum", [
        explain("D, DU, UDU", "Down on 1, down-up on 2, skip the down on 3, then up, down-up. The missing down gives it a lilt.",
                rhythm(ISLAND)),
        tap(ISLAND, bpm=60, bars=2),
        quiz("Which strum do you skip in the island strum?", ["The down on 1", "The up after 4", "The down on 3"], 2,
             "Your hand still moves down on 3, it just misses the strings. That keeps the up after it in time."),
        strum(C, ISLAND, bpm=60, bars=2),
        tap(ISLAND, bpm=66, bars=2),
        strum(C, ISLAND, bpm=66, bars=4),
    ], minutes=5, xp=25),
    lesson("uke-3-5", "Island strum with changes", [
        explain("Change on the last up", "The last up strum of a bar can be loose or open. Use it to move to the next chord, so beat 1 lands clean."),
        play_chord(G7),
        tap(ISLAND, bpm=70, bars=2),
        strum(C, ISLAND, bpm=66, bars=2),
        progression([(C, 2), (Am, 2)], ISLAND, bpm=66),
        progression([(F, 2), (G7, 2)], ISLAND, bpm=66),
        progression([(C, 1), (Am, 1), (F, 1), (G7, 1), (C, 2)], ISLAND, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-3-6", "Challenge: strum patterns", [
        explain("Three patterns, five chords", "Downs, down-ups and the island strum. Keep your hand moving and let the chords come to you."),
        tap(D_DU, bpm=70, bars=2),
        strum(C, DOWNS, bpm=72, bars=2),
        strum(Am, EIGHTHS, bpm=66, bars=2),
        strum(F, D_DU, bpm=66, bars=2),
        quiz("Which pattern is the island strum?", ["D, DU, UDU", "D, D, D, D", "DU, DU, DU, DU"], 0),
        listen("Which chord sounds darker?", [SOUND_F, SOUND_AM], ["The first", "The second"], 1),
        strum(G7, ISLAND, bpm=70, bars=2),
        progression([(C, 2), (Am, 2), (F, 2), (G7, 2), (C, 2)], ISLAND, bpm=72),
    ], minutes=6, xp=30, kind="challenge"),
])

UNIT_4 = unit("uke-4", "Melodies", "Play tunes note by note on strings 1 to 3.", [
    lesson("uke-4-1", "The C major scale", [
        explain("Eight notes, three strings", "C D E F G A B C. Start on open string 3 and climb across strings 2 and 1. Every note sits in the first three frets.",
                fretboard(U, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
        notes(U, ["C4", "D4", "E4", "F4"], hint="String 3 open and fret 2, then string 2 open and fret 1."),
        notes(U, [("G4", 2), "A4", "B4", "C5"], hint="String 2 fret 3, then string 1: open, fret 2, fret 3."),
        quiz("How many different note names are in the scale?", ["Eight", "Seven", "Five"], 1,
             "C to C is eight notes, but the top C repeats the first. Seven names, then they start again."),
        along(U, "C4 D4 E4 F4 G4@2 A4 B4 C5 C5 B4 A4 G4@2 F4 E4 D4 C4", bpm=66, title="C major, up and down"),
    ], minutes=4, xp=20),
    lesson("uke-4-2", "Ode to Joy", [
        explain("A melody you already know", "Beethoven wrote this tune in 1824. It moves mostly by step, from one note to the next, on strings 2 and 3.",
                staff(["E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4"])),
        notes(U, ["E4", "E4", "F4", ("G4", 2), ("G4", 2), "F4", "E4", "D4"], hint="The opening: E E F G, G F E D."),
        along(U, ODE_1, bpm=66, title="Ode to Joy, first line"),
        quiz("The first line ends on D. Where does the second line end?", ["On G", "On C, home", "On D again"], 1,
             "Same start, different finish. The second line comes home to C."),
        along(U, ODE_2, bpm=66, title="Ode to Joy, second line"),
        progression([(C, 1), (G, 1), (C, 1), (G, 1), (C, 1), (G, 1), (C, 2)], DOWNS, bpm=72),
        along(U, f"{ODE_1} {ODE_2}", bpm=72, title="Ode to Joy"),
    ], minutes=5, xp=30, kind="song"),
    lesson("uke-4-3", "Twinkle, Twinkle, Little Star", [
        explain("A leap, then steps down", "This traditional tune leaps from C up to G, then walks back down one note at a time. Every line ends on a longer note.",
                staff(["C4", "C4", "G4", "G4", "A4", "A4", "G4"])),
        notes(U, ["C4", ("G4", 2), "A4"], hint="Open string 3, string 2 fret 3, open string 1."),
        along(U, TWINKLE_A, bpm=70, title="First line"),
        listen("Does this phrase go up or down?", [["G4"], ["F4"], ["E4"], ["D4"]], ["Up", "Down"], 1),
        along(U, TWINKLE_B, bpm=70, title="Middle line"),
        along(U, f"{TWINKLE_A} {TWINKLE_B} {TWINKLE_A}", bpm=76, title="Twinkle, Twinkle, Little Star"),
    ], minutes=5, xp=30, kind="song"),
    lesson("uke-4-4", "Long notes and short notes", [
        explain("Notes have length", "A quarter note lasts one beat, a half note two, a whole note four. Hold each one until the next note starts.",
                rhythm([0, 1, 2])),
        tap([0, 1, 2], bpm=66, bars=2),
        along(U, "C4 E4 G4@2:2 A4:2 G4@2:2 F4 E4 D4:2 C4:4", bpm=66, title="Hold it"),
        explain("The dot", "A dot adds half the note's length. A dotted half note lasts three beats; a dotted quarter lasts one and a half.",
                rhythm([0, 1.5, 2, 3])),
        tap([0, 1.5, 2, 3], bpm=60, bars=2),
        quiz("How many beats does a dotted half note last?", ["Two", "Four", "Three"], 2),
        along(U, "E4:1.5 D4:0.5 C4:2 E4:1.5 D4:0.5 C4:2 G4@2:1.5 F4:0.5 E4 D4 C4:4", bpm=66, title="Long, short, long"),
    ], minutes=5, xp=25),
    lesson("uke-4-5", "Aura Lee", [
        explain("A slow love song from 1861", "\"Aura Lee\" was published in 1861, with music by George R. Poulton. Play it slowly and let each note ring into the next."),
        explain("A new note: F sharp", "Fret 2 on string 2 is F sharp, one fret above F. A sharp raises a note by one fret.",
                fretboard(U, [(2, 2, 2)])),
        notes(U, ["D4", ("G4", 2), "F#4", ("G4", 2)], hint="String 3 fret 2, then string 2 frets 3, 2, 3."),
        along(U, AURA_LEE, bpm=66, title="First phrase"),
        quiz("A sharp sign raises a note by how much?", ["One fret", "Two frets", "One string"], 0),
        along(U, f"{AURA_LEE} {AURA_LEE}", bpm=70, title="Aura Lee"),
    ], minutes=5, xp=30, kind="song"),
    lesson("uke-4-6", "Challenge: three tunes", [
        explain("Scales, steps and leaps", "Watch the note highway and keep your place, even if you miss a note. The beat goes on, so you do too."),
        notes(U, ["C4", "D4", "E4", "F4", ("G4", 2), "A4", "B4", "C5"], hint="The C major scale, up."),
        quiz("Where is F sharp on string 2?", ["Fret 1", "Fret 2", "Fret 3"], 1, visual=fretboard(U, [(2, 2)])),
        listen("Which is higher?", [["B4"], ["G4"]], ["The first", "The second"], 0),
        along(U, f"{ODE_1} {ODE_2}", bpm=76, title="Ode to Joy"),
        along(U, TWINKLE_A, bpm=80, title="Twinkle, Twinkle, Little Star"),
        along(U, AURA_LEE, bpm=72, title="Aura Lee"),
    ], minutes=6, xp=35, kind="challenge"),
])

UNIT_5 = unit("uke-5", "More chords", "D minor, E minor, D, A and E7, then the four-chord song.", [
    lesson("uke-5-1", "D minor", [
        explain("Dm: F plus one finger", "Second finger on fret 2 of string 4, third on fret 2 of string 3, first on fret 1 of string 2. String 1 rings open.",
                {"type": "chord", "chord": Dm}),
        play_chord(Dm),
        quiz("Which chord is D minor closest to?", ["C", "F", "G"], 1,
             "D minor is F with one more finger, on fret 2 of string 3."),
        strum(Dm, DOWNS, bpm=60, bars=2),
        progression([(F, 2), (Dm, 2), (F, 2), (Dm, 2)], DOWNS, bpm=60),
        progression([(C, 2), (Dm, 2), (G7, 2), (C, 2)], D_DU, bpm=66),
    ], minutes=4, xp=20),
    lesson("uke-5-2", "E minor", [
        explain("Em: a staircase", "First finger on fret 2 of string 1, second on fret 3 of string 2, third on fret 4 of string 3. String 4 rings open.",
                {"type": "chord", "chord": Em}),
        play_chord(Em),
        listen("Major or minor?", [SOUND_EM], ["Major, bright", "Minor, dark"], 1),
        strum(Em, DOWNS, bpm=60, bars=2),
        quiz("E minor and G both leave which string open?", ["String 1, A", "String 3, C", "String 4, G"], 2),
        progression([(G, 2), (Em, 2), (G, 2), (Em, 2)], DOWNS, bpm=60),
        progression([(C, 2), (Em, 2), (F, 2), (G, 2)], ISLAND, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-5-3", "D and A", [
        explain("D: three in a row", "Put fingers 1, 2 and 3 side by side on fret 2 of strings 4, 3 and 2. String 1 rings open.",
                {"type": "chord", "chord": D}),
        play_chord(D),
        explain("A: two fingers", "Second finger on fret 2 of string 4, first finger on fret 1 of string 3. Strings 2 and 1 ring open.",
                {"type": "chord", "chord": A}),
        play_chord(A),
        quiz("Which chord has three fingers on the same fret?", ["A", "D minor", "D"], 2),
        progression([(D, 2), (A, 2), (D, 2), (A, 2)], DOWNS, bpm=60),
        progression([(D, 2), (G, 2), (A, 2), (D, 2)], D_DU, bpm=66),
    ], minutes=5, xp=25),
    lesson("uke-5-4", "E7 leads to A minor", [
        explain("E7", "First finger on fret 1 of string 4, second on fret 2 of string 3, third on fret 2 of string 1. String 2 rings open.",
                {"type": "chord", "chord": E7}),
        play_chord(E7),
        explain("Another chord that pulls", "G7 pulls toward C. In the same way, E7 pulls toward A minor. Play them back to back and listen for the release."),
        listen("Does this end at home or leave you hanging?", [SOUND_AM, SOUND_E7], ["Home", "Hanging"], 1),
        strum(E7, DOWNS, bpm=60, bars=2),
        progression([(Am, 2), (E7, 2), (Am, 2), (E7, 1), (Am, 1)], DOWNS, bpm=60),
        progression([(Am, 2), (Dm, 2), (E7, 2), (Am, 2)], D_DU, bpm=66),
    ], minutes=5, xp=20),
    lesson("uke-5-5", "Four chords, endless songs", [
        explain("I, V, vi, IV", "Number the notes of the C scale and you can name chords by number: C is I, G is V, A minor is vi, F is IV. This order runs through countless songs."),
        quiz("In the key of C, which chord is IV?", ["G", "A minor", "F", "D minor"], 2,
             "Count up the scale from C: C, D, E, F. F is the fourth note, so F is the IV chord."),
        progression([(C, 2), (G, 2), (Am, 2), (F, 2)], DOWNS, bpm=60),
        quiz("Which chord is vi in C?", ["A minor", "E minor", "D minor"], 0,
             "Lowercase numbers mean minor chords. The sixth note of C major is A."),
        progression([(C, 1), (G, 1), (Am, 1), (F, 1), (C, 1), (G, 1), (Am, 1), (F, 1)], DOWNS, bpm=66),
        tap(ISLAND, bpm=66, bars=2),
        progression([(C, 1), (G, 1), (Am, 1), (F, 1), (C, 1), (G, 1), (Am, 1), (F, 1)], ISLAND, bpm=66),
    ], minutes=5, xp=25),
    lesson("uke-5-6", "Challenge: ten chords", [
        explain("Ten chords now", "C, A minor, F, G, G7, D minor, E minor, D, A and E7. Clean shapes first, then steady strums."),
        play_chord(Dm),
        play_chord(Em),
        play_chord(E7),
        quiz("In the key of C, which chord is V?", ["F", "G", "E minor", "A minor"], 1),
        progression([(D, 2), (A, 2), (D, 2), (A, 2)], ISLAND, bpm=70),
        progression([(Am, 2), (Dm, 2), (E7, 2), (Am, 2)], D_DU, bpm=70),
        progression([(C, 1), (G, 1), (Am, 1), (F, 1), (C, 1), (G, 1), (Am, 1), (F, 1)], ISLAND, bpm=72),
    ], minutes=6, xp=35, kind="challenge"),
])

UNIT_6 = unit("uke-6", "Songs", "Four public-domain songs with melody and chords.", [
    lesson("uke-6-1", "Oh! Susanna", [
        explain("Counting in two", "Stephen Foster wrote this song in 1848. It counts in two: 1 and 2 and. Most notes are quick eighth notes.",
                rhythm([0, 0.5, 1, 1.5], beats_per_bar=2)),
        notes(U, ["C4", "D4", "E4", ("G4", 2), ("G4", 2), "A4", ("G4", 2), "E4"], hint="The opening: C D E G, G A G E."),
        along(U, f"r:1 {SUSANNA_1} D4:2", bpm=66, beats_per_bar=2, title="First line"),
        quiz("The first line ends on D. Where does the second line end?", ["On G", "On C, home", "On D again"], 1,
             "Same start, different finish. The second line comes home to C."),
        along(U, f"r:1 {SUSANNA_2}", bpm=66, beats_per_bar=2, title="Second line"),
        progression([(C, 3), (G7, 1), (C, 2), (G7, 1), (C, 1)], [0, 1], bpm=72, beats_per_bar=2),
        along(U, SUSANNA, bpm=76, beats_per_bar=2, title="Oh! Susanna"),
    ], minutes=6, xp=35, kind="song"),
    lesson("uke-6-2", "Camptown Races", [
        explain("Call and answer", "Another Foster song, from 1850. The melody bounces between G and E, and a short two-note call answers each line."),
        notes(U, [("G4", 2), ("G4", 2), "E4", ("G4", 2), "A4", ("G4", 2), "E4"], hint="G G E G A G E."),
        along(U, CAMPTOWN_1, bpm=66, beats_per_bar=2, title="First line"),
        along(U, CAMPTOWN_2, bpm=66, beats_per_bar=2, title="Second line"),
        quiz("Which note ends the song?", ["D", "G", "C"], 2, "Like most songs in C, it comes home to C."),
        progression([(C, 6), (G7, 1), (C, 1)], [0, 1, 1.5], bpm=72, beats_per_bar=2),
        along(U, CAMPTOWN, bpm=76, beats_per_bar=2, title="Camptown Races"),
    ], minutes=5, xp=35, kind="song"),
    lesson("uke-6-3", "Clementine", [
        explain("Three beats to a bar", "Count 1 2 3, 1 2 3, with the weight on 1. This is waltz time. \"Clementine\", first printed in 1884, sways in three.",
                rhythm([0, 1, 2], beats_per_bar=3)),
        tap([0, 1, 2], bpm=72, bars=2, beats_per_bar=3),
        notes(U, ["F4", "C4", "A4", "C5", "Bb4"], hint="String 2 fret 1, open 3, open 1, then string 1 frets 3 and 1."),
        along(U, f"r:2 {CLEMENTINE_1} G4@2:3", bpm=72, beats_per_bar=3, title="First line"),
        along(U, f"r:2 {CLEMENTINE_2}", bpm=72, beats_per_bar=3, title="Second line"),
        explain("C7: one finger", "First finger on fret 1 of string 1. With F, it carries the whole song.",
                {"type": "chord", "chord": C7}),
        progression([(F, 3), (C7, 2), (F, 1), (C7, 1), (F, 1)], [0, 1, 2], bpm=80, beats_per_bar=3),
        along(U, CLEMENTINE, bpm=80, beats_per_bar=3, title="Clementine"),
    ], minutes=6, xp=35, kind="song"),
    lesson("uke-6-4", "Red River Valley", [
        explain("A slow cowboy song", "This traditional tune was in print by 1896. Each line ends on a long note, so count it out before the next one."),
        notes(U, ["C4", "F4", "A4", ("G4", 2), "Bb4", "C5"], hint="Open 3, string 2 fret 1, open 1, string 2 fret 3, string 1 frets 1 and 3."),
        along(U, f"r:2 {RIVER_1} {RIVER_2}", bpm=80, title="First half"),
        along(U, f"r:2 {RIVER_3} {RIVER_4}", bpm=80, title="Second half"),
        quiz("The last line starts D, C sharp, C. How do those notes move?", ["A big leap up", "Down one fret at a time", "The same note three times"], 1,
             "Each note is one fret lower on string 3: fret 2, fret 1, open."),
        progression([(F, 6), (C7, 2)], D_DU, bpm=72),
        along(U, RIVER, bpm=84, title="Red River Valley"),
    ], minutes=6, xp=35, kind="song"),
    lesson("uke-6-5", "Back a song with chords", [
        explain("Chords under the tune", "When you strum a song, the melody lives in your head or in a friend's voice. Change chords where the tune leans, and keep the strum steady."),
        progression([(C, 3), (G7, 1), (C, 2), (G7, 1), (C, 1)], ISLAND, bpm=76),
        quiz("A song in F usually ends on which chord?", ["C7", "F", "B flat"], 1,
             "Songs come home to their key chord. In F, that's F."),
        listen("Does this end at home or leave you hanging?", [SOUND_C7, SOUND_F], ["Home", "Hanging"], 0),
        progression([(F, 6), (C7, 2)], ISLAND, bpm=72),
        progression([(F, 3), (C7, 2), (F, 1), (C7, 1), (F, 1)], [0, 1, 2], bpm=84, beats_per_bar=3),
    ], minutes=5, xp=25),
    lesson("uke-6-6", "Challenge: your first set", [
        explain("Your first set list", "Four songs, a handful of chords and three strums. Play them like a small concert: count in, keep going, finish strong."),
        along(U, SUSANNA, bpm=80, beats_per_bar=2, title="Oh! Susanna"),
        progression([(C, 6), (G7, 1), (C, 1)], [0, 1, 1.5], bpm=76, beats_per_bar=2),
        along(U, CAMPTOWN, bpm=80, beats_per_bar=2, title="Camptown Races"),
        along(U, CLEMENTINE, bpm=84, beats_per_bar=3, title="Clementine"),
        progression([(F, 6), (C7, 2)], ISLAND, bpm=76),
        along(U, RIVER, bpm=88, title="Red River Valley"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("ukulele", "Ukulele", "From G C E A to your first songs", "ukulele.soprano.4", "music.note", "amber", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6,
])
