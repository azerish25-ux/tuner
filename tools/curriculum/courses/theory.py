"""Music theory: from the musical alphabet to the chord progressions behind songs. No instrument needed.

Mostly quizzes on staff, keyboard and rhythm pictures, with listening steps wherever hearing the idea
helps, and a few notes steps where the learner plays or sings what they just learned.
"""
from lib import QUALITIES, course, explain, keyboard, lesson, listen, midi, notes, parse_chord_name, quiz, rhythm, staff, tap, unit

FIRST, SECOND = "The first", "The second"
MAJOR = [2, 2, 1, 2, 2, 2, 1]          # whole, whole, half, whole, whole, whole, half
NATURAL_MINOR = [2, 1, 2, 2, 1, 2, 2]
MIXOLYDIAN = [2, 2, 1, 2, 2, 1, 2]     # major with a lowered seventh


def scale(root, pattern=MAJOR):
    out = [midi(root)]
    for size in pattern:
        out.append(out[-1] + size)
    return out


def is_major(root, pattern=MAJOR):
    return listen("Is this a major scale?", [[m] for m in scale(root, pattern)], ["Yes", "No"], 0 if pattern == MAJOR else 1)


def letters(a, b):
    """Do two notes share a letter name (are they octaves apart)?"""
    return listen("Do these two notes share a letter name?", [[a], [b]], ["Yes", "No"],
                  0 if (midi(a) - midi(b)) % 12 == 0 else 1)


def chords(names):
    """Listening voicings for "C F G7 Am": root in the bass (A2 to G3), the chord tones kept between C4 and B4."""
    out = []
    for n in names.split():
        pc, quality = parse_chord_name(n)
        bass = 48 + pc if pc <= 7 else 36 + pc
        out.append([bass] + sorted(60 + (pc + i) % 12 for i in QUALITIES[quality]))
    return out


WHY_HIGHER = "It sits higher on the staff, so it sounds higher."
WHY_C = "C sits just left of the group of two black keys."
WHY_D = "D sits between the two black keys of the pair."
WHY_F = "F sits just left of the group of three black keys."
WHY_G = "The second line up is G, where the treble clef curls."
WHY_B = "The middle line is B, the Boy of Every Good Boy Does Fine."
WHY_E5 = "The top space is E, the last letter of FACE."
WHY_MIDDLE_C = "One ledger line below the treble staff is middle C."
WHY_A5 = "One ledger line above the treble staff is A."
WHY_F_CLEF = "The bass clef is the F clef: its dots frame the F line."
CADENCES = ["Plagal (IV–I)", "Authentic (V–I)", "Deceptive (V–vi)"]

# ---------------------------------------------------------------- 1 Notes and the musical alphabet

UNIT_1 = unit("thy-1", "Notes and the alphabet", "Seven letters, repeating octaves, and where every note lives on a keyboard.", [
    lesson("thy-1-1", "The musical alphabet", [
        explain("Seven letters", "Music names its notes with just seven letters: A, B, C, D, E, F, G. After G the alphabet "
                "starts again at A, a little higher each time around.",
                keyboard(["A3", "B3", "C4", "D4", "E4", "F4", "G4"])),
        quiz("What comes after G?", ["H", "A", "C"], 1, "The musical alphabet stops at G and starts again at A."),
        quiz("Which letter comes just before C?", ["B", "D", "A"], 0, "Going down, the alphabet runs C, B, A, then G."),
        explain("Up and down the alphabet", "Moving forward through the letters, A to B to C, the notes go up. Moving "
                "backward, they go down. The letters loop like the hours on a clock."),
        quiz("What are the next two letters after F?", ["G, H", "E, D", "G, A"], 2,
             "F, G, then back around to A."),
        quiz("Which list goes down?", ["C D E F", "E D C B", "A B C D"], 1,
             "Backward through the alphabet means lower notes: E, D, C, B."),
        notes(None, ["C4", "D4", "E4"], hint="Play or sing C, D, E, climbing up the alphabet."),
    ], minutes=3, xp=15),
    lesson("thy-1-2", "Octaves", [
        explain("Same letter, higher", "Notes that share a letter sound alike even when one is higher. The distance from one "
                "C to the next C is an octave. The higher note vibrates exactly twice as fast.", keyboard(["C4", "C5"])),
        letters("A3", "A4"),
        letters("D4", "A4"),
        quiz("A4 vibrates 440 times a second. How fast does A5 vibrate?", ["220 times", "880 times", "450 times"], 1,
             "An octave up doubles the vibration: 440 becomes 880."),
        explain("Octave numbers", "Notes carry a number that tells you which octave they're in. Middle C, near the center of "
                "a piano, is C4. The number goes up by one at every C.", keyboard(["C4"])),
        quiz("Which note is just above B3?", ["B4", "C3", "C4"], 2,
             "Octave numbers change at C, so the next note up from B3 is C4."),
        letters("E5", "E4"),
        notes(None, ["C4", "C5"], hint="Play or sing middle C, then the C an octave higher."),
    ]),
    lesson("thy-1-3", "The keyboard map", [
        explain("Twos and threes", "A keyboard's black keys come in groups of two and three. They're your map. C is the white "
                "key just left of each group of two.", keyboard(["C4", "C5"])),
        quiz("Which note is highlighted?", ["D", "C", "E"], 1, WHY_C, keyboard(["C4"])),
        explain("F and the group of three", "F is the white key just left of each group of three black keys. Find C and F "
                "first, and every other white key is a short count away.", keyboard(["F4"])),
        quiz("Which note is highlighted?", ["F", "G", "B"], 0, WHY_F, keyboard(["F4"])),
        quiz("Which note is highlighted?", ["C", "E", "D"], 2, WHY_D, keyboard(["D4"])),
        quiz("Which note is highlighted?", ["A", "G", "B"], 2,
             "B is the white key just right of the group of three black keys.", keyboard(["B4"])),
        notes(None, ["F4", "G4", "A4"], hint="Play or sing F, G, A, starting from the F you just found."),
    ]),
    lesson("thy-1-4", "Every white key", [
        explain("Count from C", "From C, the white keys run C, D, E, F, G, A, B, then C again. Seven white keys hold one of "
                "each letter.", keyboard(["C4", "D4", "E4", "F4", "G4", "A4", "B4"])),
        quiz("Which note is highlighted?", ["G", "A", "F"], 0,
             "G sits between the first two black keys of the group of three.", keyboard(["G4"])),
        quiz("Which note is highlighted?", ["D", "F", "E"], 2,
             "E is the white key just right of the group of two black keys.", keyboard(["E4"])),
        quiz("Which note is highlighted?", ["A", "B", "G"], 0,
             "A sits between the last two black keys of the group of three.", keyboard(["A3"])),
        quiz("How many white keys run from one C up to the next B?", ["Seven", "Eight", "Twelve"], 0,
             "C, D, E, F, G, A, B: seven letters, seven white keys."),
        notes(None, ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"],
              hint="Play or sing up the white keys from middle C to the next C."),
    ]),
    lesson("thy-1-5", "Notes and letters challenge", [
        explain("Letters, octaves, keys", "The alphabet, octaves and the keyboard map, all together. Use the black-key groups "
                "to find your way."),
        quiz("Which two letters come right after E?", ["F, G", "D, C", "F, H"], 0, "E, F, G: forward through the alphabet."),
        quiz("Which note is highlighted?", ["C", "F", "B"], 1, WHY_F, keyboard(["F3"])),
        letters("G3", "G4"),
        quiz("Middle C is C4. What's the C an octave above it?", ["C3", "C5", "C8"], 1,
             "Each octave up adds one to the number."),
        quiz("Which note is highlighted?", ["E", "D", "C"], 1, WHY_D, keyboard(["D5"])),
        letters("B3", "F4"),
        notes(None, ["G4", "A4", "B4", "C5"], hint="Play or sing G, A, B, C. The alphabet wraps from G back to A."),
    ], minutes=5, xp=30, kind="challenge"),
])

# ---------------------------------------------------------------- 2 Sharps, flats and half steps

UNIT_2 = unit("thy-2", "Sharps, flats and half steps", "The black keys, the smallest step, and notes with two names.", [
    lesson("thy-2-1", "Half steps", [
        explain("The smallest step", "A half step moves from one key to the very next, black or white, with nothing in "
                "between. It's the smallest distance on a keyboard and in most music.", keyboard(["C4", "C#4"])),
        quiz("What is a half step above E?", ["F", "F♯", "G"], 0, "E and F have no black key between them."),
        explain("Two white-key half steps", "Look for the gaps with no black key: E to F and B to C. These white keys sit "
                "right next to each other, so they're only a half step apart.", keyboard(["E4", "F4", "B4", "C5"])),
        quiz("Which pair of white keys is a half step apart?", ["C and D", "B and C", "F and G"], 1,
             "B and C have no black key between them."),
        listen("Half step or whole step?", [["E4"], ["F4"]], ["Half step", "Whole step"], 0),
        quiz("How many half steps from C up to E?", ["Two", "Three", "Four"], 2,
             "C, C♯, D, D♯, E: four moves of one key each."),
        notes(None, ["E4", "F4", "B4", "C5"], hint="Play or sing the two white-key half steps: E to F, then B to C."),
    ]),
    lesson("thy-2-2", "Sharps and flats", [
        explain("Sharp and flat", "A sharp (♯) raises a note by a half step. A flat (♭) lowers it by a half step. The black "
                "key just above C is C♯; the one just below D is D♭.", keyboard(["C#4"])),
        quiz("What does a sharp do to a note?", ["Raises it a half step", "Lowers it a half step", "Raises it a whole step"], 0),
        quiz("This black key sits just above F. What's its sharp name?", ["F♯", "G♯", "E♯"], 0,
             "Raise F by a half step and you get F♯.", keyboard(["F#4"])),
        quiz("The same key sits just below G. What's its flat name?", ["F♭", "G♭", "A♭"], 1,
             "Lower G by a half step and you get G♭.", keyboard(["F#4"])),
        explain("Two names, one key", "Each black key can be named from the white key below it, with a sharp, or the white "
                "key above it, with a flat. C♯ and D♭ are the same key."),
        quiz("What is a half step below B?", ["B♭", "C", "B♯"], 0, "Lower B by a half step and you get B♭."),
        quiz("Which note is highlighted?", ["C♯", "D♯", "A♯"], 1,
             "It's the right-hand key of the pair, just above D: D♯.", keyboard(["D#4"])),
        notes(None, ["C4", "C#4", "D4"], hint="Play or sing C, C♯, D: two half steps up."),
    ]),
    lesson("thy-2-3", "Whole steps", [
        explain("Two half steps", "A whole step equals two half steps: it skips exactly one key. C to D is a whole step, with "
                "C♯ in between. E to F♯ is too.", keyboard(["C4", "D4"])),
        quiz("What is a whole step above C?", ["C♯", "D", "E"], 1, "C to D skips one key, C♯."),
        quiz("What is a whole step above E?", ["F", "F♯", "G"], 1,
             "E to F is only a half step, so a whole step up is F♯."),
        listen("Half step or whole step?", [["G3"], ["A3"]], ["Half step", "Whole step"], 1),
        quiz("What is a whole step above B?", ["C", "C♯", "D"], 1,
             "B to C is a half step, so a whole step up is C♯."),
        listen("Half step or whole step?", [["C5"], ["B4"]], ["Half step", "Whole step"], 0),
        quiz("What is a whole step below F?", ["E", "E♭", "D"], 1,
             "F down to E is a half step; one more key down is E♭."),
        notes(None, ["E4", "F#4", "G#4"], hint="Play or sing two whole steps up from E: E, F♯, G♯."),
    ]),
    lesson("thy-2-4", "One key, two names", [
        explain("Enharmonic notes", "Two names for the same pitch are called enharmonic. C♯ and D♭ are one key with two "
                "names. Which name you use depends on the key you're in.", keyboard(["C#4"])),
        quiz("Which pair names the same key?", ["C♯ and D", "D♯ and E", "C♯ and D♭"], 2,
             "C♯ is a half step above C; D♭ is a half step below D. Same key."),
        quiz("What's another name for G♯?", ["A♭", "G♭", "A♯"], 0, "G♯ and A♭ are the same black key."),
        explain("White keys too", "White keys can have sharp or flat names as well. E and F are a half step apart, so E♯ is "
                "the same key as F, and F♭ is the same key as E.", keyboard(["E4", "F4"])),
        quiz("E♯ is played on which key?", ["F", "E", "F♯"], 0, "E♯ is a half step above E, which is F."),
        quiz("What's another name for C?", ["C♭", "B♯", "D♭"], 1, "B♯ is a half step above B, which is C."),
        quiz("The black key between F and G is F♯. What's its other name?", ["E♯", "G♭", "A♭"], 1,
             "Lower G by a half step and you get G♭."),
        notes(None, ["Bb3", "C4", "D4"], hint="Play or sing B♭, C, D. B♭ is the same key as A♯."),
    ]),
    lesson("thy-2-5", "Sharps and flats challenge", [
        explain("Steps and names", "Half steps, whole steps, sharps, flats and two-name notes, all mixed together. Picture the "
                "keyboard as you answer."),
        quiz("What is a half step above B?", ["C", "C♯", "A♯"], 0, "B and C have no black key between them."),
        quiz("What is a whole step above A?", ["A♯", "B", "C"], 1, "A to B skips one key, A♯."),
        quiz("What's another name for E♭?", ["D♯", "E♯", "F♭"], 0, "E♭ and D♯ are the same black key."),
        listen("Half step or whole step?", [["F#4"], ["G4"]], ["Half step", "Whole step"], 0),
        quiz("Which note is highlighted?", ["G♯", "A♯", "F♯"], 1,
             "It's the top key of the group of three, just below B: A♯, also called B♭.", keyboard(["Bb4"])),
        quiz("What is a whole step below D?", ["C", "C♯", "D♭"], 0, "D to C skips one key, C♯."),
        listen("Half step or whole step?", [["D4"], ["C4"]], ["Half step", "Whole step"], 1),
        notes(None, ["D4", "E4", "F#4", "G4"], hint="Play or sing D, E, F♯, G: whole, whole, then half."),
    ], minutes=5, xp=30, kind="challenge"),
])

# ---------------------------------------------------------------- 3 Reading the staff

UNIT_3 = unit("thy-3", "Reading the staff", "Treble clef lines and spaces, ledger lines, and a first look at bass clef.", [
    lesson("thy-3-1", "Lines and spaces", [
        explain("The staff", "Music is written on a staff: five lines with four spaces between them. Notes sit on a line or "
                "in a space. The higher a note sits, the higher it sounds.", staff(["E4", "G4", "B4", "D5", "F5"])),
        quiz("How many lines does a staff have?", ["Four", "Five", "Six"], 1, "Five lines, with four spaces between them."),
        quiz("Which note is higher?", [FIRST, SECOND], 0, WHY_HIGHER, staff(["D5", "F4"])),
        explain("Line, space, line", "Moving up one letter moves from a line to the next space, or from a space to the next "
                "line. Notes on neighboring lines are two letters apart.", staff(["E4", "F4", "G4"])),
        quiz("Which note is higher?", [FIRST, SECOND], 1, WHY_HIGHER, staff(["G4", "C5"])),
        quiz("A note on a line moves up one letter. Where does it land?",
             ["The next space up", "The next line up", "Two lines up"], 0, "Letters alternate: line, space, line, space."),
        listen("Which is higher?", [["F4"], ["D5"]], [FIRST, SECOND], 1),
    ]),
    lesson("thy-3-2", "Treble clef lines", [
        explain("The treble clef", "The treble clef, or G clef, curls around the second line from the bottom. That line is "
                "the G above middle C. Higher instruments and voices read it.", staff(["G4"])),
        quiz("Which note is on the second line of the treble staff?", ["E", "G", "B"], 1,
             "The treble clef curls around that line to mark G."),
        explain("Every Good Boy Does Fine", "From bottom to top, the treble staff's lines are E, G, B, D, F. Remember them as "
                "Every Good Boy Does Fine.", staff(["E4", "G4", "B4", "D5", "F5"])),
        quiz("Which note is this?", ["E", "F", "G"], 0, "The bottom line is E, the Every of Every Good Boy Does Fine.",
             staff(["E4"])),
        quiz("Which note is this?", ["D", "B", "G"], 1, WHY_B, staff(["B4"])),
        quiz("Which note is this?", ["D", "F", "E"], 1, "The top line is F, the Fine of Every Good Boy Does Fine.",
             staff(["F5"])),
        quiz("Which note is this?", ["C", "B", "D"], 2, "The fourth line up is D, the Does of Every Good Boy Does Fine.",
             staff(["D5"])),
        notes(None, ["E4", "G4", "B4"], hint="Play or sing the bottom three lines: E, G, B."),
    ]),
    lesson("thy-3-3", "Treble clef spaces", [
        explain("FACE in the spaces", "The four spaces of the treble staff spell a word from bottom to top: F, A, C, E. The "
                "spaces spell FACE.", staff(["F4", "A4", "C5", "E5"])),
        quiz("Which note is this?", ["F", "A", "E"], 0, "The bottom space is F, the first letter of FACE.", staff(["F4"])),
        quiz("Which note is this?", ["A", "C", "B"], 1, "The third space up is C: F, A, C.", staff(["C5"])),
        quiz("Which note is this?", ["E", "G", "A"], 2, "The second space up is A: F, A.", staff(["A4"])),
        explain("Lines and spaces together", "Put them together and the staff climbs E, F, G, A, B, C, D, E, F: line, space, "
                "line, space, all the way up.", staff(["E4", "F4", "G4", "A4", "B4", "C5", "D5", "E5", "F5"])),
        quiz("Which note is this?", ["D", "E", "F"], 1, WHY_E5, staff(["E5"])),
        quiz("Which note is this?", ["G", "F", "A"], 0, WHY_G, staff(["G4"])),
        notes(None, ["F4", "A4", "C5", "E5"], hint="Play or sing the spaces from bottom to top: F, A, C, E."),
    ]),
    lesson("thy-3-4", "Ledger lines and middle C", [
        explain("Ledger lines", "When a note goes above or below the staff, short extra lines called ledger lines extend it. "
                "Middle C sits on one ledger line just below the treble staff.", staff(["C4"])),
        quiz("Which note is this?", ["C", "A", "E"], 0, WHY_MIDDLE_C, staff(["C4"])),
        quiz("Which note is this?", ["C", "D", "B"], 1, "D hangs in the space just below the bottom line.", staff(["D4"])),
        explain("Above the staff", "Above the top line, the pattern keeps going. G sits just above the top line, and A sits "
                "on the first ledger line above.", staff(["G5", "A5"])),
        quiz("Which note is this?", ["G", "A", "F"], 1, WHY_A5, staff(["A5"])),
        quiz("Which note is this?", ["B", "G", "A"], 2,
             "Count down: middle C on the first ledger line, B below it, A on the second ledger line.", staff(["A3"])),
        notes(None, ["C4", "D4", "E4"], hint="Play or sing middle C, then D and E, climbing from the ledger line onto the staff."),
    ]),
    lesson("thy-3-5", "Bass clef basics", [
        explain("The bass clef", "Low instruments and voices read the bass clef, or F clef. Its two dots surround the fourth "
                "line up, marking the F below middle C.", staff(["F3"], clef="bass")),
        quiz("Which note do the bass clef's dots mark?", ["G", "F", "C"], 1, WHY_F_CLEF),
        explain("Good Boys Do Fine Always", "The bass staff's lines, bottom to top, are G, B, D, F, A: Good Boys Do Fine "
                "Always. The spaces are A, C, E, G: All Cows Eat Grass.", staff(["G2", "B2", "D3", "F3", "A3"], clef="bass")),
        quiz("Which note is this?", ["G", "E", "B"], 0,
             "The bottom line of the bass staff is G, the Good of Good Boys Do Fine Always.", staff(["G2"], clef="bass")),
        quiz("Which note is this?", ["A", "E", "C"], 2, "The second space up is C: All Cows.", staff(["C3"], clef="bass")),
        quiz("Which note is this?", ["A", "F", "D"], 0,
             "The top line of the bass staff is A, the Always of Good Boys Do Fine Always.", staff(["A3"], clef="bass")),
        quiz("Where is middle C in bass clef?", ["On a ledger line above the staff", "On the middle line", "In the bottom space"],
             0, "Middle C sits one ledger line above the bass staff, and one below the treble staff."),
        notes(None, ["A2", "C3", "E3", "G3"], hint="Play or sing the bass clef spaces: A, C, E, G."),
    ], minutes=5, xp=25),
    lesson("thy-3-6", "Staff reading challenge", [
        explain("Read it at a glance", "Lines, spaces, ledger lines and both clefs. Use your memory sentences, then try to "
                "recognize each note at a glance."),
        quiz("Which note is this?", ["B", "D", "G"], 2, WHY_G, staff(["G4"])),
        quiz("Which note is this?", ["C", "E", "A"], 0, WHY_MIDDLE_C, staff(["C4"])),
        quiz("Which note is this?", ["F", "E", "D"], 1, WHY_E5, staff(["E5"])),
        quiz("Which note is this?", ["F", "D", "A"], 0, WHY_F_CLEF, staff(["F3"], clef="bass")),
        quiz("Which note is this?", ["D", "B", "F"], 1, WHY_B, staff(["B4"])),
        quiz("Which note is this?", ["G", "A", "B"], 1, WHY_A5, staff(["A5"])),
        quiz("Which note is this?", ["E", "G", "C"], 0, "The third space up in bass clef is E: All Cows Eat.",
             staff(["E3"], clef="bass")),
        notes(None, ["C4", "E4", "G4", "C5"], hint="Play or sing middle C, then E, G, and the C in the third space."),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 4 Rhythm and time

UNIT_4 = unit("thy-4", "Rhythm and time", "Note values from whole to sixteenth, dots and rests, and the meters 4/4, 3/4 and 6/8.", [
    lesson("thy-4-1", "Beats and bars", [
        explain("The beat", "The beat is the steady pulse you tap your foot to. Beats are grouped into bars, also called "
                "measures. In most music, each bar holds four beats.", rhythm([0, 1, 2, 3])),
        tap([0, 1, 2, 3], bpm=70, bars=2),
        explain("Count every bar", "Count each bar out loud: 1, 2, 3, 4. Beat 1, the downbeat, usually feels strongest. Lean "
                "into it a little."),
        quiz("What's another word for a bar?", ["Measure", "Beat", "Rest"], 0, "Bar and measure mean the same thing."),
        quiz("Which beat usually feels strongest?", ["Beat 4", "Beat 1", "Beat 3"], 1, "Beat 1, the downbeat, starts each bar."),
        tap([0], bpm=70, bars=4),
    ], minutes=3, xp=15),
    lesson("thy-4-2", "Whole, half and quarter notes", [
        explain("Note values", "A note's shape tells you how long it lasts. In a four-beat bar, a whole note lasts all four "
                "beats, a half note two, and a quarter note one.", rhythm([0])),
        quiz("How many beats does a half note last?", ["One", "Two", "Four"], 1, "Two half notes fill a four-beat bar.",
             rhythm([0, 2])),
        tap([0, 2], bpm=70, bars=2),
        quiz("How many quarter notes fill a bar of four beats?", ["Two", "Four", "Eight"], 1,
             "A quarter note lasts one beat, so four fill the bar.", rhythm([0, 1, 2, 3])),
        quiz("Which lasts longest?", ["A quarter note", "A whole note", "A half note"], 1,
             "A whole note lasts four beats, a half note two, a quarter note one."),
        explain("Mix them", "A bar can mix values, as long as they add up. A half note plus two quarter notes fills four "
                "beats: 2 + 1 + 1.", rhythm([0, 2, 3])),
        tap([0, 2, 3], bpm=70, bars=2),
    ]),
    lesson("thy-4-3", "Eighth and sixteenth notes", [
        explain("Eighth notes", "An eighth note lasts half a beat, so two fit in each beat. Count them 1 and 2 and 3 and 4 "
                "and, saying and between the beats.", rhythm([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])),
        tap([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], bpm=60, bars=2),
        quiz("How many eighth notes fit in one beat?", ["One", "Two", "Four"], 1, "An eighth note lasts half a beat."),
        explain("Sixteenth notes", "A sixteenth note lasts a quarter of a beat, so four fit in each beat. Count them 1 e and "
                "a, 2 e and a.", rhythm([0, 0.25, 0.5, 0.75, 1, 2, 3])),
        quiz("How many sixteenth notes equal one quarter note?", ["Two", "Four", "Eight"], 1,
             "A quarter note is one beat, and four sixteenths fit in a beat."),
        quiz("How many eighth notes fill a bar of four beats?", ["Four", "Six", "Eight"], 2,
             "Two per beat, four beats: eight eighth notes."),
        tap([0, 1, 1.5, 2, 3], bpm=65, bars=2),
        tap([0, 0.25, 0.5, 0.75, 1, 2, 3], bpm=60, bars=2),
    ], minutes=5, xp=25),
    lesson("thy-4-4", "Dots and rests", [
        explain("Dotted notes", "A dot after a note adds half its value. A half note lasts two beats, so a dotted half lasts "
                "three. A dotted quarter lasts one and a half.", rhythm([0, 3])),
        quiz("How many beats does a dotted half note last?", ["Two", "Three", "Four"], 1,
             "Half of two is one, so the dot adds one beat: 2 + 1 = 3."),
        tap([0, 3], bpm=70, bars=2),
        explain("Rests", "A rest is a measured silence. Each note value has a matching rest: a quarter rest lasts one beat, a "
                "half rest two. Keep counting through them.", rhythm([0, 1, 3])),
        tap([0, 1, 3], bpm=70, bars=2),
        quiz("How long does a dotted quarter note last?", ["One beat", "One and a half beats", "Two beats"], 1,
             "A quarter is one beat; the dot adds half of that."),
        quiz("A four-beat bar has a half note and a quarter note. What fills the gap?",
             ["A quarter rest", "A half rest", "A whole rest"], 0, "2 + 1 = 3, so one beat is left: a quarter rest."),
        tap([0, 1.5, 2, 3], bpm=65, bars=2),
    ]),
    lesson("thy-4-5", "Time signatures", [
        explain("Reading a time signature", "The two stacked numbers at the start of a piece are the time signature. The top "
                "number counts beats per bar. The bottom shows which note gets one beat: 4 means a quarter note.",
                rhythm([0, 1, 2, 3])),
        quiz("In 4/4, how many quarter-note beats are in a bar?", ["Three", "Four", "Six"], 1,
             "The top 4 means four beats; the bottom 4 makes each one a quarter note."),
        explain("3/4 time", "In 3/4, each bar holds three quarter-note beats. Count 1, 2, 3, with the weight on 1. It's the "
                "lilt of a waltz.", rhythm([0, 1, 2], 3)),
        quiz("Which time signature is a waltz usually in?", ["4/4", "3/4", "6/8"], 1, "A waltz counts in threes: 1, 2, 3."),
        explain("6/8 time", "In 6/8, each bar holds six eighth notes in two groups of three. It feels like two big beats, "
                "each split in three: 1 2 3, 4 5 6.", rhythm([0, 1, 2, 3, 4, 5], 6)),
        quiz("How is 6/8 usually felt?", ["Six equal beats", "Two beats, each split in three", "Three beats, each split in two"],
             1, "The eighths group 1 2 3, 4 5 6, so you feel two strong pulses per bar."),
        quiz("In 3/4, which single note fills a whole bar?", ["A whole note", "A dotted half note", "A half note"], 1,
             "Three beats: a half note (2) plus its dot (1)."),
    ], minutes=5, xp=25),
    lesson("thy-4-6", "Rhythm challenge", [
        explain("Count it, then tap it", "Note values, dots, rests and time signatures together. Count out loud as you tap; "
                "your voice keeps your hands honest."),
        quiz("How many beats does a whole note last in 4/4?", ["Two", "Three", "Four"], 2),
        tap([0, 2, 3], bpm=75, bars=2),
        quiz("How many sixteenth notes fit in one beat?", ["Two", "Four", "Six"], 1),
        tap([0, 0.5, 1, 2, 2.5, 3], bpm=70, bars=2),
        quiz("What does a dot add to a note?", ["Half its value", "One beat", "Twice its value"], 0),
        quiz("A bar of 3/4 has a quarter note and a quarter rest. What's missing?", ["One beat", "Two beats", "Nothing"], 0,
             "3/4 holds three beats; 1 + 1 = 2, so one beat remains."),
        quiz("How many eighth notes are in a bar of 6/8?", ["Three", "Six", "Eight"], 1),
        tap([0, 1.5, 2, 3], bpm=70, bars=2),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 5 Major scales and keys

C_SCALE = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]

UNIT_5 = unit("thy-5", "Major scales and keys", "The whole-and-half-step recipe, four major keys, and their key signatures.", [
    lesson("thy-5-1", "The C major scale", [
        explain("A scale", "A scale is a set of notes climbing in order from a home note to the same note an octave up. C "
                "major uses only white keys: C, D, E, F, G, A, B, C.", keyboard(C_SCALE)),
        quiz("How many different letters are in a major scale?", ["Five", "Seven", "Eight"], 1,
             "Seven letters, then the first one returns an octave higher."),
        listen("Is this scale going up or down?", [[n] for n in C_SCALE], ["Up", "Down"], 0),
        explain("Where the half steps fall", "In C major, most neighbors are a whole step apart. Only E to F and B to C are "
                "half steps. That uneven spacing gives the scale its sound.", keyboard(["E4", "F4", "B4", "C5"])),
        quiz("In C major, which steps are half steps?", ["C to D and F to G", "E to F and B to C", "D to E and A to B"], 1,
             "E and F, and B and C, have no black key between them."),
        quiz("What's the home note of C major?", ["C", "G", "A"], 0,
             "The home note, called the tonic, gives the scale its name."),
        notes(None, C_SCALE, hint="Play or sing the C major scale, up from middle C."),
    ]),
    lesson("thy-5-2", "The major scale recipe", [
        explain("Whole, whole, half", "Every major scale follows one recipe of steps: whole, whole, half, whole, whole, whole, "
                "half. Start on any note, follow it, and you build a major scale.", keyboard(C_SCALE)),
        quiz("Which is the major scale recipe? (W = whole, H = half)", ["W W H W W W H", "W H W W H W W", "W W W H W W H"], 0,
             "Whole, whole, half, whole, whole, whole, half."),
        quiz("Number the scale's notes 1 to 8. Where are the half steps?", ["2–3 and 6–7", "3–4 and 7–8", "4–5 and 7–8"], 1,
             "Whole, whole, then half from 3 to 4; whole, whole, whole, then half from 7 to 8."),
        is_major("D4"),
        is_major("C4", NATURAL_MINOR),
        quiz("Starting on G, a whole step up lands on...", ["A", "A♭", "B"], 0, "G to A skips one key, G♯."),
        notes(None, ["D4", "E4", "F#4", "G4"], hint="Play or sing the first four notes of D major: whole, whole, half."),
    ]),
    lesson("thy-5-3", "G major", [
        explain("Building G major", "Start on G and follow the recipe: G, A, B, C, D, E, then a whole step to F♯ and a half "
                "step home to G. G major has one sharp: F♯.", keyboard(["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"])),
        quiz("Why does G major need F♯ instead of F?", ["E to F is only a half step", "F is too low to sing",
                                                         "Sharps sound brighter"], 0,
             "The recipe needs a whole step from note 6 to 7, then a half step from 7 up to G."),
        quiz("Which note is in G major?", ["F", "F♯", "B♭"], 1, "G major's seventh note is F♯."),
        is_major("G3"),
        is_major("G3", MIXOLYDIAN),
        quiz("How many sharps are in G major?", ["None", "One", "Two"], 1, "Just one: F♯."),
        notes(None, scale("G3"), hint="Play or sing the G major scale. Remember the F♯."),
    ]),
    lesson("thy-5-4", "D major and F major", [
        explain("D major: two sharps", "From D, the recipe gives D, E, F♯, G, A, B, C♯, D. D major has two sharps: F♯ and C♯.",
                keyboard(scale("D4"))),
        quiz("Which two sharps are in D major?", ["F♯ and C♯", "F♯ and G♯", "C♯ and D♯"], 0,
             "D to E is whole, so E to F♯; A to B is whole, so B to C♯."),
        explain("F major: one flat", "From F, the recipe needs a half step from A to the fourth note, so it's B♭, not B. F "
                "major: F, G, A, B♭, C, D, E, F. One flat: B♭.", keyboard(scale("F4"))),
        quiz("Which note is in F major?", ["B", "B♭", "F♯"], 1, "F major's fourth note is B♭, a half step above A."),
        is_major("F3"),
        quiz("Which key has two sharps?", ["G major", "F major", "D major"], 2, "D major has F♯ and C♯."),
        is_major("D4", MIXOLYDIAN),
        notes(None, ["F4", "G4", "A4", "Bb4", "C5"], hint="Play or sing up F major from F to C. The fourth note is B♭."),
    ]),
    lesson("thy-5-5", "Key signatures", [
        explain("Key signatures", "Rather than writing F♯ every time, music in G major puts one sharp at the start of each "
                "line. That's the key signature: it lists the notes that are always sharp or flat.",
                staff(["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"])),
        quiz("A key signature has one sharp, F♯. Which major key is it?", ["C major", "G major", "D major"], 1,
             "G major is the major key with just F♯."),
        quiz("A key signature has one flat, B♭. Which major key is it?", ["F major", "B♭ major", "G major"], 0,
             "F major is the major key with just B♭."),
        explain("A sharp shortcut", "Sharps always appear in the same order: F♯, C♯, G♯, and so on. The last sharp is a half "
                "step below the key's name. One sharp, F♯: G major."),
        quiz("A key signature has two sharps, F♯ and C♯. Which major key is it?", ["A major", "E major", "D major"], 2,
             "The last sharp, C♯, is a half step below D."),
        quiz("Which major key has no sharps or flats?", ["C major", "G major", "F major"], 0, "C major uses only white keys."),
        quiz("The key signature shows B♭. Which Bs are played as B♭?", ["Only the first one", "Every B", "Only the high ones"], 1,
             "A key signature applies to every B in every octave, unless the music marks otherwise."),
        notes(None, scale("D4"), hint="Play or sing D major, with its two sharps: F♯ and C♯."),
    ]),
    lesson("thy-5-6", "Scales and keys challenge", [
        explain("Build it, name it", "The recipe, four keys and their signatures. When unsure, build the scale from its home "
                "note: whole, whole, half, whole, whole, whole, half."),
        quiz("Which note belongs in G major?", ["C♯", "F♯", "B♭"], 1, "G major's only sharp is F♯."),
        is_major("Bb3"),
        quiz("One flat in the key signature means which key?", ["F major", "D major", "C major"], 0),
        quiz("Which scale has the notes D, E, F♯, G, A, B, C♯?", ["G major", "D major", "A major"], 1),
        is_major("A3", NATURAL_MINOR),
        quiz("In every major scale, which step is a half step?", ["From 2 to 3", "From 3 to 4", "From 5 to 6"], 1,
             "Whole, whole, half: the first half step falls between notes 3 and 4."),
        quiz("Which key signature belongs to G major?", ["One sharp", "Two sharps", "One flat"], 0),
        notes(None, scale("F3"), hint="Play or sing F major, with its B♭."),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 6 Intervals

UNIT_6 = unit("thy-6", "Intervals", "Name the distance between two notes by number and quality, and measure it in half steps.", [
    lesson("thy-6-1", "Counting interval numbers", [
        explain("Count the letters", "An interval's number comes from counting letter names, including both ends. C up to E "
                "counts C, D, E: three letters, so it's a third.", staff(["C4", "E4"])),
        quiz("C up to G is a...", ["Fourth", "Fifth", "Sixth"], 1, "C, D, E, F, G: five letters."),
        quiz("D up to F is a...", ["Second", "Third", "Fourth"], 1, "D, E, F: three letters."),
        quiz("What interval is this?", ["Fourth", "Third", "Second"], 0, "E, F, G, A: four letters.", staff(["E4", "A4"])),
        explain("Sharps don't change the count", "Sharps and flats don't change an interval's number. C to E♭ and C to E are "
                "both thirds: C, D, E either way. They differ in size, which comes next.", staff(["C4", "Eb4"])),
        quiz("F up to D is a...", ["Fifth", "Sixth", "Seventh"], 1, "F, G, A, B, C, D: six letters."),
        quiz("A up to E♭ is a...", ["Fourth", "Fifth", "Sixth"], 1,
             "A, B, C, D, E: five letters. The flat doesn't change the count."),
        quiz("G up to the next G is a...", ["Seventh", "Octave", "Ninth"], 1, "G, A, B, C, D, E, F, G: eight letters, an octave."),
    ]),
    lesson("thy-6-2", "Thirds by size", [
        explain("Count half steps for size", "Two intervals with the same number can differ in size. To measure exactly, count "
                "half steps. C up to E is four; C up to E♭ is three.", keyboard(["C4", "E4"])),
        quiz("How many half steps from D up to F?", ["Two", "Three", "Four"], 1, "D, D♯, E, F: three moves."),
        explain("Major and minor thirds", "A third of four half steps is a major third, like C to E. A third of three is a "
                "minor third, like C to E♭ or A to C.", keyboard(["A3", "C4"])),
        quiz("E up to G♯ is a...", ["Minor third", "Major third"], 1, "E to G♯ spans four half steps."),
        quiz("A up to C is a...", ["Minor third", "Major third"], 0, "A to C spans three half steps."),
        listen("Which interval do you hear?", [["F4"], ["A4"]], ["Minor third", "Major third"], 1),
        quiz("G up to B♭ is a...", ["Minor third", "Major third"], 0, "G to B♭ spans three half steps."),
        listen("Which interval do you hear?", [["D4"], ["F4"]], ["Minor third", "Major third"], 0),
    ]),
    lesson("thy-6-3", "Perfect intervals", [
        explain("Perfect intervals", "Unisons, fourths, fifths and octaves are called perfect. A perfect fourth spans five "
                "half steps, a perfect fifth seven, and an octave twelve.", keyboard(["C4", "F4", "G4"])),
        quiz("How many half steps are in a perfect fifth?", ["Five", "Seven", "Eight"], 1, "C up to G: seven half steps."),
        quiz("C up to F is a...", ["Perfect fourth", "Perfect fifth", "Major third"], 0, "C to F spans five half steps."),
        listen("Which interval do you hear?", [["D4"], ["A4"]], ["Perfect fourth", "Perfect fifth", "Octave"], 1),
        explain("Watch out for B and F", "Most white-key fifths are perfect, but B up to F spans only six half steps. It's "
                "called a diminished fifth. When in doubt, count half steps.", keyboard(["B3", "F4"])),
        quiz("Which of these fifths is smaller than perfect?", ["C to G", "B to F", "E to B"], 1,
             "B to F spans six half steps; a perfect fifth needs seven."),
        quiz("A up to D is a...", ["Perfect fourth", "Perfect fifth", "Minor third"], 0,
             "A, B, C, D: four letters, five half steps."),
        listen("Which interval do you hear?", [["G3"], ["C4"]], ["Perfect fourth", "Perfect fifth", "Octave"], 0),
    ]),
    lesson("thy-6-4", "Seconds, sixths and sevenths", [
        explain("Major and minor everywhere", "Seconds, thirds, sixths and sevenths come in major and minor sizes. Minor is "
                "always one half step smaller than major.", keyboard(["C4", "A4"])),
        explain("The sizes in half steps", "Minor second 1, major second 2. Minor third 3, major third 4. Minor sixth 8, major "
                "sixth 9. Minor seventh 10, major seventh 11."),
        quiz("C up to A is a...", ["Minor sixth", "Major sixth", "Perfect fifth"], 1, "C to A spans nine half steps."),
        quiz("C up to B♭ is a...", ["Major seventh", "Minor seventh", "Major sixth"], 1, "C to B♭ spans ten half steps."),
        quiz("E up to F is a...", ["Minor second", "Major second", "Minor third"], 0, "E to F is a single half step."),
        quiz("How many half steps are in a major seventh?", ["Ten", "Eleven", "Twelve"], 1, "One half step short of an octave."),
        listen("Which interval do you hear?", [["G3"], ["E4"]], ["Minor sixth", "Major sixth", "Minor seventh"], 1),
        quiz("E up to C is a...", ["Minor sixth", "Major sixth", "Perfect fifth"], 0,
             "E, F, G, A, B, C makes a sixth. It spans eight half steps, so it's minor."),
        listen("Which interval do you hear?", [["C4"], ["D4"]], ["Minor second", "Major second", "Minor third"], 1),
    ], minutes=5, xp=25),
    lesson("thy-6-5", "Intervals challenge", [
        explain("Number, then size", "Count letters for the number. Count half steps for the size. Together they name any "
                "interval."),
        quiz("F up to A is a...", ["Minor third", "Major third", "Perfect fourth"], 1,
             "F, G, A is a third, and four half steps makes it major."),
        quiz("D up to A is a...", ["Perfect fourth", "Perfect fifth", "Major sixth"], 1, "D to A spans seven half steps."),
        listen("Which interval do you hear?", [["E4"], ["B4"]], ["Perfect fourth", "Perfect fifth", "Major sixth"], 1),
        quiz("B up to D is a...", ["Minor third", "Major third", "Perfect fourth"], 0,
             "B, C, D is a third of three half steps: minor."),
        quiz("How many half steps are in a major sixth?", ["Eight", "Nine", "Ten"], 1),
        listen("Which interval do you hear?", [["A3"], ["D4"]], ["Major third", "Perfect fourth", "Perfect fifth"], 1),
        quiz("G up to F is a...", ["Major seventh", "Minor seventh", "Octave"], 1,
             "G to F covers seven letters and ten half steps: a minor seventh."),
        listen("Which interval do you hear?", [["Bb3"], ["G4"]], ["Minor sixth", "Major sixth", "Octave"], 1),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 7 Chords

UNIT_7 = unit("thy-7", "Chords", "Stack thirds into triads, build major and minor chords, and number the chords of a key.", [
    lesson("thy-7-1", "Building a triad", [
        explain("Stacking thirds", "A triad is three notes stacked in thirds. Start on any note, skip a letter, take the next, "
                "skip again. C, skip D, E, skip F, G: C E G.", keyboard(["C4", "E4", "G4"])),
        quiz("Which notes make a triad built on G?", ["G B D", "G A B", "G C E"], 0, "G, skip A, B, skip C, D."),
        explain("Root, third, fifth", "The note a triad is built on is its root. The middle note is the third and the top "
                "note is the fifth, named for their distance above the root.", keyboard(["C4", "E4", "G4"])),
        quiz("In the triad F A C, which note is the root?", ["F", "A", "C"], 0, "F is the bottom note the triad is built on."),
        quiz("In the triad D F A, which note is the fifth?", ["D", "F", "A"], 2, "D up to A is a fifth: D, E, F, G, A."),
        quiz("Using only white keys, which triad is built on E?", ["E F G", "E G B", "E A C"], 1, "E, skip F, G, skip A, B."),
        notes(None, ["C4", "E4", "G4"], hint="Play or sing the C triad one note at a time: C, E, G."),
    ]),
    lesson("thy-7-2", "Major and minor triads", [
        explain("Major triads", "A major triad has a major third on the bottom, four half steps, then a minor third on top. "
                "C E G is major. So are F A C and G B D.", keyboard(["F4", "A4", "C5"])),
        listen("Major or minor?", [["C4", "E4", "G4"]], ["Major", "Minor"], 0),
        explain("Minor triads", "Flip the thirds and you get minor: a minor third on the bottom, then a major third. Lower the "
                "middle note of C major and you get C minor: C E♭ G.", keyboard(["C4", "Eb4", "G4"])),
        quiz("Which notes spell D minor?", ["D F♯ A", "D F A", "D F A♭"], 1,
             "D to F is a minor third; F to A is a major third."),
        quiz("Which notes spell E major?", ["E G B", "E G♯ B", "E A B"], 1,
             "E to G♯ is a major third; G♯ to B is a minor third."),
        listen("Major or minor?", [["A3", "C4", "E4"]], ["Major", "Minor"], 1),
        quiz("Is A C E major or minor?", ["Major", "Minor"], 1, "A to C is a minor third, three half steps."),
        notes(None, ["A3", "C4", "E4"], hint="Play or sing A minor one note at a time: A, C, E."),
    ]),
    lesson("thy-7-3", "The chords of a key", [
        explain("Chords from a scale", "Build a triad on each note of a scale, using only that scale's notes, and you get the "
                "key's family of chords. C major has seven, one per note.", keyboard(C_SCALE[:7])),
        quiz("Using only C major notes, what triad is built on D?", ["D major", "D minor", "D diminished"], 1,
             "D F A: a minor third, then a major third."),
        quiz("Using only C major notes, what triad is built on G?", ["G major", "G minor", "G diminished"], 0,
             "G B D: a major third, then a minor third."),
        explain("The diminished chord", "The triad on B is different: B D F. Both thirds are minor, so it's a diminished "
                "triad. It sounds tense and wants to move.", keyboard(["B3", "D4", "F4"])),
        listen("Which kind of chord is this?", [["B3", "D4", "F4"]], ["Major", "Minor", "Diminished"], 2),
        quiz("In C major, which chords are major?", ["C, F and G", "C, D and E", "D, E and A"], 0,
             "C E G, F A C and G B D each have a major third on the bottom."),
        quiz("Using only C major notes, what triad is built on A?", ["A major", "A minor", "A diminished"], 1,
             "A C E: a minor third, then a major third."),
        notes(None, ["B3", "D4", "F4"], hint="Play or sing the diminished triad on B: B, D, F."),
    ]),
    lesson("thy-7-4", "Roman numerals", [
        explain("Numbering chords", "Musicians number a key's chords with Roman numerals: I for the chord on note 1, up to vii "
                "for note 7. Uppercase means major, lowercase minor, and ° diminished."),
        explain("The major key pattern", "Every major key follows one pattern: I, ii, iii, IV, V, vi, vii°. In C major that's "
                "C, D minor, E minor, F, G, A minor and B diminished.", keyboard(C_SCALE[:7])),
        quiz("In C major, which chord is IV?", ["F major", "E minor", "G major"], 0, "The fourth note of C major is F."),
        quiz("In C major, which chord is vi?", ["A major", "A minor", "F major"], 1,
             "The sixth note is A, and lowercase vi means minor."),
        quiz("In G major, which chord is V?", ["C major", "D major", "D minor"], 1,
             "Count up from G: G, A, B, C, D. The fifth note is D, and V is major."),
        quiz("Why is ii written in lowercase?", ["It's a minor chord", "It's a quiet chord", "It's played higher"], 0),
        quiz("In G major, which chord is IV?", ["C major", "C minor", "D major"], 0, "G, A, B, C: the fourth note is C."),
        listen("Which kind of chord is this?", [["D4", "F4", "A4"]], ["Major", "Minor", "Diminished"], 1),
    ], minutes=5, xp=25),
    lesson("thy-7-5", "Chords challenge", [
        explain("Spell it, hear it, number it", "Stack thirds, check their sizes, then place the chord in its key: major on I, "
                "IV and V, minor on ii, iii and vi, diminished on vii°."),
        quiz("Which notes spell G major?", ["G B D", "G B♭ D", "G C E"], 0),
        quiz("Which notes spell A minor?", ["A C♯ E", "A C E", "A D F"], 1),
        listen("Major or minor?", [["D4", "F#4", "A4"]], ["Major", "Minor"], 0),
        quiz("In C major, which chord is ii?", ["D minor", "D major", "E minor"], 0),
        listen("Which kind of chord is this?", [["E4", "G4", "Bb4"]], ["Major", "Minor", "Diminished"], 2),
        quiz("In F major, which chord is V?", ["B♭ major", "C major", "C minor"], 1, "F, G, A, B♭, C: the fifth note is C."),
        quiz("Which triad is diminished?", ["B D F", "D F A", "G B D"], 0, "B to D and D to F are both minor thirds."),
        notes(None, ["G3", "B3", "D4"], hint="Play or sing the G major triad: G, B, D."),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 8 Progressions

UNIT_8 = unit("thy-8", "Progressions", "How chords move in songs: I–IV–V, the pop loop, ii–V–I, the 12-bar blues and cadences.", [
    lesson("thy-8-1", "I, IV and V", [
        explain("Three chords", "Countless folk, rock and country songs use just three chords: I, IV and V. In C major, "
                "that's C, F and G. Together they hold every note of the scale.", keyboard(["C4", "E4", "G4"])),
        quiz("In G major, what are I, IV and V?", ["G, C and D", "G, B and D", "G, A and D"], 0,
             "Count up from G: note 1 is G, note 4 is C, note 5 is D."),
        listen("Does this end on the home chord?", chords("C F G C"), ["Yes", "No"], 0),
        listen("Does this end on the home chord?", chords("C F C G"), ["Yes", "No"], 1),
        explain("Home, away, and back", "I feels like home. IV moves away. V builds tension that pulls back to I. That trip, "
                "out and back again, shapes a huge number of songs."),
        quiz("Which chord pulls most strongly back to I?", ["IV", "V", "vi"], 1, "V builds tension that resolves to I."),
        quiz("In D major, which chord is IV?", ["G major", "A major", "E minor"], 0, "D, E, F♯, G: the fourth note is G."),
        notes(None, ["C4", "F4", "G4", "C4"], hint="Play or sing the roots of I, IV, V, I in C: C, F, G, C."),
    ]),
    lesson("thy-8-2", "The pop progression", [
        explain("I–V–vi–IV", "This four-chord loop runs under a huge number of pop songs. In C major it's C, G, A minor, F. "
                "The minor vi adds a touch of shade before IV lifts back toward home."),
        listen("Which progression do you hear?", chords("C G Am F"), ["I–V–vi–IV", "I–IV–V–I"], 0),
        quiz("In G major, what is I–V–vi–IV?", ["G, D, E minor, C", "G, C, D, G", "G, D, C, E minor"], 0,
             "In G: I is G, V is D, vi is E minor, IV is C."),
        listen("Which progression do you hear?", chords("D A Bm G"), ["I–IV–V–I", "I–V–vi–IV"], 1),
        explain("Same chords, new start", "Start the same loop on vi and you get vi–IV–I–V: A minor, F, C, G. The chords are "
                "identical, but beginning on minor makes it sound more serious."),
        listen("Which progression do you hear?", chords("Am F C G"), ["I–V–vi–IV", "vi–IV–I–V"], 1),
        quiz("In F major, which chord is vi?", ["D minor", "D major", "A minor"], 0,
             "F, G, A, B♭, C, D: the sixth note is D, and vi is minor."),
        notes(None, ["C4", "G4", "A4", "F4"], hint="Play or sing the roots of I–V–vi–IV in C: C, G, A, F."),
    ]),
    lesson("thy-8-3", "ii–V–I", [
        explain("The jazz workhorse", "ii–V–I is the most common progression in jazz. In C major: D minor, G, C. Each root "
                "falls a fifth to the next, so the move feels like coming home."),
        quiz("In C major, what is ii–V–I?", ["D minor, G, C", "D, G, C minor", "E minor, G, C"], 0,
             "ii is D minor, V is G, and I is C."),
        listen("Which progression do you hear?", chords("Dm G C"), ["ii–V–I", "IV–V–I"], 0),
        explain("Add sevenths", "Jazz players usually add sevenths: Dm7, G7, Cmaj7. The extra notes make each move even "
                "smoother. The roots and the trip home stay the same."),
        listen("Which progression do you hear?", chords("Dm7 G7 Cmaj7"), ["IV–V–I", "ii–V–I"], 1),
        quiz("In F major, what is ii–V–I?", ["G minor, C, F", "G, C, F", "B♭, C, F"], 0,
             "F, G, A, B♭, C: ii is G minor and V is C."),
        quiz("In ii–V–I, how do the roots move?", ["Down a fifth each time", "Up a step each time", "Down a step each time"], 0,
             "D down to G, then G down to C: a fifth each time."),
        listen("Which progression do you hear?", chords("Gm7 C7 Fmaj7"), ["ii–V–I", "I–V–vi–IV"], 0),
        notes(None, ["D4", "G3", "C4"], hint="Play or sing the roots of ii–V–I in C: D, down to G, up to C."),
    ], minutes=5, xp=25),
    lesson("thy-8-4", "The 12-bar blues", [
        explain("Twelve bars", "The 12-bar blues is a 12-bar chord plan behind countless blues, rock and jazz tunes. It uses I, "
                "IV and V, often all as dominant seventh chords for a bluesy edge."),
        listen("Is this the 12-bar blues?", chords("A7 A7 A7 A7 D7 D7 A7 A7 E7 D7 A7 A7"), ["Yes", "No"], 0),
        explain("The plan", "Four bars of I. Two of IV, two of I. One of V, one of IV, two of I. Then it repeats. In A: A7 four "
                "times, D7 twice, A7 twice, E7, D7, A7 twice."),
        quiz("How many bars of I open the 12-bar blues?", ["Two", "Four", "Eight"], 1),
        quiz("In the 12-bar blues, which chord is in bar 9?", ["I", "IV", "V"], 2, "Bar 9 is the one bar of V, before IV in bar 10."),
        listen("Is this the 12-bar blues?", chords("A7 A7 D7 D7 A7 A7 E7 E7 D7 D7 A7 A7"), ["Yes", "No"], 1),
        quiz("In the key of E, what are the three blues chords?", ["E7, A7 and B7", "E7, G7 and A7", "E7, A7 and C7"], 0,
             "In E, I is E, IV is A and V is B."),
        listen("Is this the 12-bar blues?", chords("E7 E7 E7 E7 A7 A7 E7 E7 B7 A7 E7 E7"), ["Yes", "No"], 0),
        notes(None, ["A3", "D4", "E4", "A3"], hint="Play or sing the roots of the blues in A: A, D, E, back to A."),
    ], minutes=5, xp=25),
    lesson("thy-8-5", "Cadences", [
        explain("Cadences", "A cadence is the chord move that ends a phrase, like punctuation. V to I is the strongest, a full "
                "stop. It's called an authentic cadence."),
        listen("Does this phrase sound finished?", chords("C F G C"), ["Finished", "Unfinished"], 0),
        explain("Other endings", "IV to I is a plagal cadence, the soft amen at the end of many hymns. Stopping on V is a half "
                "cadence, like a comma. V to vi is deceptive: you expect home and get a surprise."),
        listen("Does this phrase sound finished?", chords("C Am F G"), ["Finished", "Unfinished"], 1),
        quiz("Which cadence ends a phrase on V?", ["Authentic", "Half", "Plagal"], 1, "A half cadence pauses on V, like a comma."),
        listen("Which cadence do you hear?", chords("C F G Am"), ["Authentic (V–I)", "Deceptive (V–vi)"], 1),
        quiz("Which cadence is called the amen cadence?", ["Plagal (IV–I)", "Authentic (V–I)", "Half (ends on V)"], 0),
        listen("Which cadence do you hear?", chords("C Am F C"), CADENCES, 0),
        listen("Which cadence do you hear?", chords("G C D G"), CADENCES, 1),
    ], minutes=5, xp=25),
    lesson("thy-8-6", "Progressions challenge", [
        explain("How songs work", "Home, away and back again. Name the progression, then the cadence that ends it. Listen for "
                "where the music wants to rest."),
        listen("Which progression do you hear?", chords("G C D G"), ["I–IV–V–I", "I–V–vi–IV", "ii–V–I"], 0),
        quiz("In D major, what is I–V–vi–IV?", ["D, A, B minor, G", "D, G, A, D", "D, A, G, B minor"], 0,
             "In D: I is D, V is A, vi is B minor, IV is G."),
        listen("Which progression do you hear?", chords("Em7 A7 Dmaj7"), ["I–IV–V–I", "I–V–vi–IV", "ii–V–I"], 2),
        quiz("In which bar does the 12-bar blues first move to IV?", ["Bar 3", "Bar 5", "Bar 9"], 1,
             "Four bars of I, then IV arrives in bar 5."),
        listen("Which cadence do you hear?", chords("F Bb C Dm"), CADENCES, 2),
        listen("Which progression do you hear?", chords("A E F#m D"), ["I–IV–V–I", "I–V–vi–IV", "vi–IV–I–V"], 1),
        quiz("Which cadence sounds most final?", ["Half", "Authentic", "Deceptive"], 1, "V to I is the full stop of music."),
        notes(None, ["G3", "C4", "D4", "G3"], hint="Play or sing the roots of I–IV–V–I in G: G, C, D, G."),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("theory", "Music Theory", "How music works, from note names to the chords behind songs", None, "book.closed", "sky", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6, UNIT_7, UNIT_8,
])
