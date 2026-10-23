"""Guitar: from the first open string to barre chords. Unit 1 is the style reference for every course."""
from lib import along, chord, course, explain, fretboard, lesson, listen, notes, part, play_chord, quiz, rhythm, strum, tap, unit

G = "guitar"
Em = chord(G, "Em", "022000", "x23xxx")

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
        listen("Which is higher?", [["E2"], ["E4"]], ["The first", "The second"], 1),
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
        explain("Two fingers, six strings", "E minor uses two fingers on fret 2, strings 5 and 4. Every string rings.",
                {"type": "chord", "chord": Em}),
        play_chord(Em),
        explain("Strum down", "Brush across all six strings from thick to thin, one smooth motion. Keep your wrist loose.",
                rhythm([0, 1, 2, 3])),
        strum(Em, [0, 1, 2, 3], bpm=60, bars=2),
        tap([0, 1, 2, 3], bpm=70, bars=2),
    ], minutes=5, xp=25),
])

COURSE = course("guitar", "Guitar", "From your first note to barre chords", "guitar.acoustic.6", "guitars", "mint", [
    UNIT_1,
])
