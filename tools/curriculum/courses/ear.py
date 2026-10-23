"""Ear training: from higher-or-lower to melodic dictation. No instrument needed (instrument=None).

Listening steps are built by the helpers below, which work out the right answer from the sound
itself, so an answer index can never disagree with what plays. Roots and registers change from
step to step so nobody can answer by absolute pitch. `notes` steps ask the learner to sing or play
back what they just heard; with no instrument they carry no fret positions.
"""
from lib import QUALITIES, course, explain, keyboard, lesson, listen, midi, notes, quiz, staff, unit

# ---------------------------------------------------------------- shared wording

FIRST, SECOND = "The first", "The second"
ECHO = "Sing or play back the note you just heard."
ECHO_ALL = "Sing or play back the notes you just heard, in order."
ECHO_CHORD = "Sing or play back the chord's notes, low to high."

INTERVAL = {0: "Unison", 1: "Minor second", 2: "Major second", 3: "Minor third", 4: "Major third",
            5: "Perfect fourth", 7: "Perfect fifth", 8: "Minor sixth", 9: "Major sixth", 12: "Octave"}
CHORD = {"maj": "Major", "min": "Minor", "dim": "Diminished", "aug": "Augmented", "7": "Dominant seventh"}
SYLLABLES = {"do": 0, "re": 2, "mi": 4, "fa": 5, "sol": 7, "la": 9, "ti": 11}


# ---------------------------------------------------------------- listening helpers

def higher(a, b):
    """Two notes; which is higher."""
    return listen("Which is higher?", [[a], [b]], [FIRST, SECOND], 0 if midi(a) > midi(b) else 1)


def updown(a, b):
    """Two notes; does the second go up or down."""
    return listen("Does the second note go up or down?", [[a], [b]], ["Up", "Down"], 0 if midi(b) > midi(a) else 1)


def same(a, b):
    return listen("Same note or different?", [[a], [b]], ["Same", "Different"], 0 if midi(a) == midi(b) else 1)


def _pair(bottom, size, way):
    a = midi(bottom)
    return {"up": [[a], [a + size]], "down": [[a + size], [a]], "together": [[a, a + size]]}[way]


def step(bottom, size, way="up"):
    """A half step (1) or whole step (2) above `bottom`, played rising or falling."""
    return listen("Half step or whole step?", _pair(bottom, size, way), ["Half step", "Whole step"], size - 1)


def skip(bottom, size, way="up"):
    """Seconds (1-2 half steps) are steps; thirds (3-4) are skips."""
    return listen("Step or skip?", _pair(bottom, size, way), ["Step", "Skip"], 0 if size <= 2 else 1)


def interval(bottom, size, choices, way="up"):
    """An interval `size` half steps above `bottom`; choices are sizes in half steps."""
    return listen("Which interval do you hear?", _pair(bottom, size, way), [INTERVAL[c] for c in choices], choices.index(size))


def chord_q(root, quality, choices, broken=False):
    """A root-position chord; broken plays it note by note first, then together."""
    r = midi(root)
    tones = [r + i for i in QUALITIES[quality]]
    sound = [[t] for t in tones] + [tones] if broken else [tones]
    prompt = "Major or minor?" if choices == ["maj", "min"] else "Which kind of chord is this?"
    return listen(prompt, sound, [CHORD[c] for c in choices], choices.index(quality))


def home(tonic, cadence=False):
    """Sets the key: the tonic chord with its root in the bass, or a full I-IV-V-I cadence."""
    t = midi(tonic)
    one = [t - 12, t, t + 4, t + 7]
    if not cadence:
        return [one]
    four = [t - 7, t, t + 5, t + 9]
    five = [t - 5, t - 1, t + 2, t + 7]
    return [one, four, five, one]


def tune(tonic, solfege):
    """MIDI notes for "do re mi" in the key of `tonic`. A trailing , drops a note an octave; ' raises it."""
    t = midi(tonic)
    return [t + SYLLABLES[s.rstrip(",'")] - 12 * s.count(",") + 12 * s.count("'") for s in solfege.split()]


def label(solfege):
    return " ".join(s.rstrip(",'") for s in solfege.split()).capitalize()


def is_home(tonic, syl):
    note = tune(tonic, syl)[0]
    return listen("Is the last note do, the home note?", home(tonic) + [[note]], ["Yes", "No"],
                  0 if syl.rstrip(",'") == "do" else 1)


def degree(tonic, syl, choices, cadence=False):
    """Key first, then one scale degree; choices are syllables."""
    note = tune(tonic, syl)[0]
    plain = [c.rstrip(",'") for c in choices]
    return listen("Which scale degree is the last note?", home(tonic, cadence) + [[note]],
                  [label(c) for c in choices], plain.index(syl.rstrip(",'")))


def melody(tonic, choices, answer, cadence=False):
    """Key first, then the melody choices[answer]."""
    return listen("Which melody did you hear?", home(tonic, cadence) + [[m] for m in tune(tonic, choices[answer])],
                  [label(c) for c in choices], answer)


def echo(*seq, hint=None):
    return notes(None, list(seq), hint=hint or (ECHO if len(seq) == 1 else ECHO_ALL))


def echo_tune(tonic, solfege, hint=None):
    return notes(None, tune(tonic, solfege), hint=hint or ECHO_ALL)


# ---------------------------------------------------------------- 1 Higher or lower

UNIT_1 = unit("ear-1", "Higher or lower", "Tell which of two notes is higher, from wide leaps down to the smallest step.", [
    lesson("ear-1-1", "High and low", [
        explain("High and low", "Pitch is how high or low a note sounds. On a keyboard, low notes sit on the left and high notes on "
                "the right. Your ear already knows the difference; here you sharpen it.", keyboard(["C3", "C5"])),
        higher("C3", "C5"),
        higher("A5", "A3"),
        higher("E3", "B4"),
        explain("Up or down", "When the second note is higher, the melody moves up. When it's lower, it moves down. Trace the "
                "direction in the air with your hand as you listen.", staff(["G4", "D5"])),
        updown("D3", "D5"),
        updown("G5", "C4"),
        updown("F3", "C5"),
    ], minutes=3, xp=15),
    lesson("ear-1-2", "Smaller leaps", [
        explain("Closer together", "The closer two notes are, the harder they are to tell apart. Let each note finish before you "
                "answer. Every answer, right or wrong, trains your ear."),
        updown("C4", "G4"),
        updown("A4", "E4"),
        higher("F4", "D4"),
        explain("Hum the gap", "Not sure? Hum the first note, then slide your voice to the second. Feel whether your voice climbs "
                "or sinks. Your body knows the direction."),
        updown("Bb3", "D4"),
        higher("E5", "C5"),
        updown("F3", "D3"),
    ]),
    lesson("ear-1-3", "Next-door notes", [
        explain("Next-door notes", "Many melodies move to the very next note of the scale: a small step. Steps sound smooth and "
                "close. Listen for a gentle lift or dip instead of a jump.", staff(["C4", "D4", "E4"])),
        updown("C4", "D4"),
        updown("A4", "G4"),
        higher("E5", "D5"),
        updown("F3", "G3"),
        explain("Keep the first note", "Hold the first note in your head while the second one plays. Then compare them, like "
                "checking two heights side by side."),
        updown("B4", "A4"),
        higher("D4", "E4"),
    ]),
    lesson("ear-1-4", "The smallest step", [
        explain("The half step", "The smallest step in most music is the half step, also called a semitone: from one key on a "
                "keyboard to the very next. It's a tiny move, and you can learn to hear it.", keyboard(["E4", "F4"])),
        updown("E4", "F4"),
        updown("C5", "B4"),
        higher("G3", "Ab3"),
        explain("Trust your first impression", "With tiny steps, your first impression is usually right. Answer, and don't "
                "talk yourself out of it."),
        updown("F#4", "G4"),
        updown("D5", "C#5"),
        higher("Bb4", "A4"),
    ]),
    lesson("ear-1-5", "Higher or lower challenge", [
        explain("All sizes, all registers", "Wide leaps, small steps and half steps, high and low, all mixed together. Take a "
                "breath before each one."),
        updown("E4", "B4"),
        higher("G5", "F5"),
        updown("C3", "Db3"),
        updown("A4", "C4"),
        higher("F#4", "G4"),
        updown("Eb5", "D5"),
        updown("B2", "G3"),
        higher("C6", "B5"),
    ], minutes=5, xp=30, kind="challenge"),
])

# ---------------------------------------------------------------- 2 Same or different

UNIT_2 = unit("ear-2", "Same or different", "Hear when two notes match, then match a note with your voice or instrument.", [
    lesson("ear-2-1", "Same or different?", [
        explain("Same or different", "Two notes match when they have exactly the same pitch. Listen for whether the second note "
                "lands right on the first or slips away from it.", staff(["A4", "A4"])),
        same("A4", "A4"),
        same("C4", "E4"),
        same("G3", "G3"),
        quiz("Two voices sing exactly the same pitch. What's that called?", ["A chord", "Unison", "An octave"], 1,
             "Singing in unison means singing the very same note."),
        same("E5", "D5"),
        same("Bb3", "B3"),
        same("F4", "F4"),
    ]),
    lesson("ear-2-2", "Match a note", [
        explain("Sing it back", "To match a pitch, listen, hear the note again in your head, then sing or play it. Timbre shows "
                "whether you're high or low. Slide until you land on it."),
        same("D4", "D4"),
        echo("D4"),
        same("F4", "E4"),
        echo("E4", hint="Sing or play back the second note you heard."),
        explain("Slide into tune", "If you're off, don't stop. Slide slowly up or down until the note locks in. That slide is "
                "how your ear and voice learn to agree."),
        same("G4", "G4"),
        echo("G4"),
    ]),
    lesson("ear-2-3", "Hold it in your head", [
        explain("Inner hearing", "Before you sing, replay the note silently in your head. Musicians call this audiation: "
                "hearing music that isn't sounding. It's the heart of a good ear."),
        higher("E4", "G4"),
        echo("G4", hint="Sing or play back the higher note."),
        higher("C5", "A4"),
        echo("A4", hint="Sing or play back the lower note."),
        same("Bb3", "B3"),
        echo("B3", hint="Sing or play back the second note you heard."),
    ]),
    lesson("ear-2-4", "Two notes back", [
        explain("Two in a row", "Now match two notes in a row. Sing the first, then move to the second. Notice whether your "
                "voice climbs or drops to get there."),
        updown("C4", "E4"),
        echo("C4", "E4"),
        updown("A4", "F4"),
        echo("A4", "F4"),
        updown("G4", "A4"),
        echo("G4", "A4"),
    ]),
    lesson("ear-2-5", "Pitch match challenge", [
        explain("Hear it, then match it", "Same or different, single notes and pairs. Listen all the way through before you "
                "sing, and slide until each note settles."),
        same("E4", "Eb4"),
        same("B3", "B3"),
        echo("B3"),
        higher("F4", "D4"),
        echo("F4", hint="Sing or play back the higher note."),
        updown("E4", "G4"),
        echo("E4", "G4"),
    ], minutes=5, xp=30, kind="challenge"),
])

# ---------------------------------------------------------------- 3 Steps and skips

UNIT_3 = unit("ear-3", "Steps and skips", "Hear half steps and whole steps, then the wider skip of a third.", [
    lesson("ear-3-1", "Half steps and whole steps", [
        explain("Half and whole steps", "A half step moves to the very next key. A whole step skips one key, so it equals two "
                "half steps. Both sound like steps, but a whole step opens a little wider.", keyboard(["E4", "F4", "G4"])),
        step("E4", 1),
        step("C4", 2),
        quiz("How many half steps make a whole step?", ["One", "Two", "Three"], 1,
             "A whole step skips one key, so it's two half steps."),
        step("A3", 2, "down"),
        step("F#4", 1, "down"),
        step("D4", 2),
        echo("D4", "E4"),
    ]),
    lesson("ear-3-2", "Seconds", [
        explain("Steps are seconds", "Musicians call a step a second, because it moves to the next letter: C to D. A half step "
                "is a minor second. A whole step is a major second.", staff(["C4", "D4"])),
        interval("G4", 2, [1, 2]),
        interval("B3", 1, [1, 2]),
        quiz("E up to F is a...", ["Major second", "Minor second", "Third"], 1,
             "E and F have no key between them: a half step, so a minor second."),
        interval("D5", 2, [1, 2], "down"),
        quiz("C up to D is a...", ["Major second", "Minor second", "Third"], 0,
             "C to D skips the black key between them: a whole step, so a major second."),
        interval("E4", 1, [1, 2]),
        echo("E4", "F4"),
    ]),
    lesson("ear-3-3", "Steps and skips", [
        explain("Steps and skips", "A step moves to the next letter. A skip jumps over one, like C to E, skipping D. That gap "
                "is called a third. Skips sound more open than steps.", staff(["C4", "E4"])),
        skip("C4", 4),
        skip("G4", 2),
        skip("A3", 3, "down"),
        quiz("D up to F is a...", ["Step", "Skip"], 1, "D to F jumps over E, so it's a skip: a third."),
        skip("E5", 1, "down"),
        skip("D4", 3),
        echo("D4", "F4"),
    ]),
    lesson("ear-3-4", "Major and minor thirds", [
        explain("Two sizes of third", "A major third spans four half steps and sounds bright. A minor third spans three and "
                "sounds darker, a little wistful. Listen for the brightness.", keyboard(["C4", "E4"])),
        interval("C4", 4, [3, 4]),
        interval("A3", 3, [3, 4]),
        quiz("C up to E spans how many half steps?", ["Three", "Four", "Five"], 1,
             "C, C♯, D, D♯, E: four half steps, so it's a major third."),
        interval("F4", 4, [3, 4], "down"),
        interval("E5", 3, [3, 4], "down"),
        interval("E4", 3, [3, 4]),
        echo("E4", "G4"),
    ]),
    lesson("ear-3-5", "Steps and skips challenge", [
        explain("Steps, skips and sizes", "Half steps, whole steps and thirds, rising and falling. Decide step or skip first, "
                "then the exact size."),
        step("C#4", 1),
        skip("A4", 4),
        interval("Eb4", 2, [1, 2]),
        interval("B3", 4, [3, 4], "down"),
        skip("G3", 2, "down"),
        step("D5", 2, "down"),
        interval("F#4", 3, [3, 4]),
        echo("F#4", "A4"),
    ], minutes=5, xp=30, kind="challenge"),
])

# ---------------------------------------------------------------- 4 Intervals I

UNIT_4 = unit("ear-4", "Intervals I", "Unison, octave, fifth and fourth, each linked to a tune you can hum.", [
    lesson("ear-4-1", "Unison and octave", [
        explain("Intervals", "An interval is the distance between two notes. A unison is no distance at all: the same note "
                "twice. An octave is the same letter eight notes higher; it sounds like one note, only brighter.",
                keyboard(["C4", "C5"])),
        explain("Tunes to remember", "Jingle Bells opens on one note repeated: a unison. Take Me Out to the Ball Game opens "
                "with a leap up an octave. Hum each opening to recall the sound."),
        interval("D4", 12, [0, 12]),
        interval("G3", 0, [0, 12]),
        quiz("Why is it called an octave?", ["It spans eight letter names", "It has eight sharps", "It lasts eight beats"], 0,
             "C, D, E, F, G, A, B, C: eight letter names, counting both ends."),
        interval("A4", 12, [0, 12], "down"),
        interval("A3", 12, [0, 12]),
        echo("A3", "A4"),
    ]),
    lesson("ear-4-2", "The perfect fifth", [
        explain("The perfect fifth", "A perfect fifth spans seven half steps, like C up to G. It sounds open and strong. "
                "Twinkle, Twinkle, Little Star leaps up a fifth after its first two notes.", keyboard(["C4", "G4"])),
        interval("C4", 7, [7, 12]),
        interval("F3", 12, [7, 12]),
        quiz("What's a perfect fifth above D?", ["G", "A", "B"], 1,
             "Count five letters: D, E, F, G, A. D to A spans seven half steps."),
        interval("Bb3", 7, [0, 7, 12]),
        interval("E4", 7, [7, 12], "down"),
        interval("D4", 7, [7, 12]),
        echo("D4", "A4"),
    ]),
    lesson("ear-4-3", "The perfect fourth", [
        explain("The perfect fourth", "A perfect fourth spans five half steps, like C up to F. It sounds like a call to "
                "attention. Amazing Grace opens with a rising fourth.", keyboard(["C4", "F4"])),
        interval("G3", 5, [5, 7]),
        interval("Eb4", 7, [5, 7]),
        explain("Fourth or fifth?", "Both sound open. The fifth is wider and feels settled. The fourth feels like it wants to "
                "move on. If you're unsure, hum the tune for each."),
        interval("B3", 5, [5, 7]),
        quiz("Which is wider?", ["A perfect fourth", "A perfect fifth"], 1,
             "A fifth spans seven half steps; a fourth spans five."),
        interval("F#4", 7, [5, 7, 12]),
        interval("E4", 5, [5, 7]),
        echo("E4", "A4"),
    ], minutes=5, xp=25),
    lesson("ear-4-4", "Falling and together", [
        explain("Intervals go both ways", "An interval keeps its name whether it rises or falls. G down to C is still a fifth. "
                "Listen to the size of the gap, not the direction.", staff(["G4", "C4"])),
        interval("C4", 7, [5, 7, 12], "down"),
        interval("A3", 5, [5, 7], "down"),
        interval("F4", 12, [7, 12], "down"),
        explain("Both at once", "When two notes sound together, listen to the blend. An octave melts into one sound. A fifth "
                "sounds hollow and strong. A fourth sounds open but restless."),
        interval("D3", 7, [5, 7, 12], "together"),
        interval("Bb3", 12, [5, 7, 12], "together"),
        interval("G4", 5, [5, 7], "together"),
        echo("G4", "C4", hint="Sing or play a falling fifth: G down to C."),
    ], minutes=5, xp=25),
    lesson("ear-4-5", "Intervals I challenge", [
        explain("Four intervals, every way", "Unison, octave, fifth and fourth, rising, falling and together. If you get "
                "stuck, hum the tune for each."),
        interval("E4", 5, [0, 5, 7, 12]),
        interval("C3", 12, [5, 7, 12], "together"),
        interval("A4", 7, [5, 7], "down"),
        interval("Db4", 0, [0, 12]),
        interval("G3", 7, [5, 7, 12]),
        interval("B4", 5, [5, 7, 12], "down"),
        interval("C4", 5, [5, 7]),
        echo("C4", "F4"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 5 Intervals II

UNIT_5 = unit("ear-5", "Intervals II", "Thirds, sixths and seconds in their major and minor sizes.", [
    lesson("ear-5-1", "Thirds you know", [
        explain("Thirds with a tune", "When the Saints Go Marching In opens with a major third, bright and bold. Greensleeves "
                "opens with a minor third, softer and sadder. Hum both to fix the sounds."),
        interval("C4", 4, [3, 4]),
        interval("A3", 3, [3, 4]),
        quiz("How many half steps are in a minor third?", ["Two", "Three", "Four"], 1,
             "A minor third spans three half steps, like A to C. A major third spans four."),
        interval("Eb4", 4, [3, 4]),
        interval("B3", 4, [3, 4], "together"),
        interval("D4", 3, [3, 4]),
        echo("D4", "F4"),
    ]),
    lesson("ear-5-2", "Sixths", [
        explain("Sixths", "A major sixth spans nine half steps; My Bonnie Lies Over the Ocean opens with one. A minor sixth "
                "spans eight and sounds darker. The Entertainer leaps up one right after its quick opening notes."),
        interval("G3", 9, [8, 9]),
        interval("E4", 8, [8, 9]),
        quiz("C up to A is which interval?", ["Minor sixth", "Major sixth", "Perfect fifth"], 1,
             "C to A spans nine half steps: a major sixth."),
        interval("D4", 9, [7, 8, 9]),
        interval("F3", 8, [8, 9], "down"),
        interval("Bb3", 9, [7, 9, 12]),
        interval("C4", 9, [8, 9]),
        echo("C4", "A4"),
    ], minutes=5, xp=25),
    lesson("ear-5-3", "Seconds you know", [
        explain("Seconds with a tune", "Frère Jacques opens with a major second, a whole step up. Für Elise opens by rocking "
                "down and up a minor second, a half step. Small sizes, big difference."),
        interval("C4", 2, [1, 2]),
        interval("D#4", 1, [1, 2], "down"),
        quiz("Which interval is a half step?", ["Major second", "Minor second", "Minor third"], 1,
             "A minor second is one half step. A major second is two."),
        interval("A4", 2, [1, 2], "down"),
        interval("F#3", 1, [1, 2]),
        interval("Bb4", 2, [1, 2, 3]),
        echo("E4", "D#4", "E4", hint="Sing or play the rocking half step: E, D♯, E."),
    ]),
    lesson("ear-5-4", "Mixing sizes", [
        explain("Narrow it down", "First judge the size: a step, a skip or a wide leap. Then judge the color: bright for major, "
                "darker for minor. Two easy choices beat one hard guess."),
        interval("G4", 2, [2, 3, 4]),
        interval("C4", 9, [4, 7, 9]),
        interval("E3", 3, [2, 3, 4], "down"),
        interval("Ab3", 8, [7, 8, 9]),
        quiz("Which sounds darker?", ["A major sixth", "A minor sixth"], 1,
             "Minor intervals sound darker than their major partners."),
        interval("D4", 4, [3, 4, 9], "together"),
        interval("F4", 1, [1, 2, 3], "down"),
        echo("F#4", "F4"),
    ], minutes=5, xp=25),
    lesson("ear-5-5", "Intervals II challenge", [
        explain("Every size so far", "Seconds, thirds and sixths, major and minor, mixed with the fourths and fifths you "
                "already know."),
        interval("E4", 3, [3, 4, 5]),
        interval("Bb3", 9, [7, 8, 9]),
        interval("C5", 2, [1, 2], "down"),
        interval("G3", 8, [8, 9, 12]),
        interval("D4", 4, [3, 4, 7], "together"),
        interval("F#4", 1, [1, 2, 3]),
        interval("A3", 5, [4, 5, 7], "down"),
        echo("D4", "A3"),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 6 Chord qualities

UNIT_6 = unit("ear-6", "Chord qualities", "Hear major and minor chords, then diminished, augmented and dominant seventh.", [
    lesson("ear-6-1", "Major or minor?", [
        explain("Chord colors", "A chord is three or more notes sounding together. A major chord sounds bright and settled. "
                "A minor chord sounds darker. Only the middle note differs between them.", keyboard(["C4", "E4", "G4"])),
        chord_q("C4", "maj", ["maj", "min"]),
        chord_q("A3", "min", ["maj", "min"]),
        quiz("A major chord turns minor. How many of its notes change?", ["One", "Two", "All three"], 0,
             "Only the middle note, the third, drops a half step: C E G becomes C E♭ G."),
        chord_q("F4", "maj", ["maj", "min"], broken=True),
        chord_q("G3", "maj", ["maj", "min"]),
        chord_q("A3", "min", ["maj", "min"], broken=True),
        echo("A3", "C4", "E4", hint=ECHO_CHORD),
    ]),
    lesson("ear-6-2", "Major and minor everywhere", [
        explain("Listen to the middle", "Unsure? Focus on the middle note. In a major chord it sits four half steps above the "
                "bottom. In minor it sits one half step lower, which darkens everything.", keyboard(["D4", "F4", "A4"])),
        chord_q("E4", "min", ["maj", "min"]),
        chord_q("Bb3", "maj", ["maj", "min"]),
        chord_q("C5", "min", ["maj", "min"]),
        chord_q("G4", "maj", ["maj", "min"], broken=True),
        quiz("Which notes spell a C minor chord?", ["C E G", "C E♭ G", "C F A"], 1,
             "Lower the middle note of C major by a half step: E becomes E♭."),
        chord_q("F#3", "min", ["maj", "min"]),
        chord_q("D4", "maj", ["maj", "min"], broken=True),
        echo("D4", "F#4", "A4", hint=ECHO_CHORD),
    ], minutes=5, xp=25),
    lesson("ear-6-3", "Diminished and augmented", [
        explain("Tense chords", "A diminished chord stacks two minor thirds and sounds tight and uneasy. An augmented chord "
                "stacks two major thirds and sounds stretched, like a question left hanging.", keyboard(["B3", "D4", "F4"])),
        chord_q("B3", "dim", ["maj", "dim"]),
        chord_q("C4", "aug", ["aug", "maj"]),
        chord_q("E4", "maj", ["maj", "dim"]),
        quiz("Which chord stacks two major thirds?", ["Diminished", "Minor", "Augmented"], 2,
             "A major third plus a major third, like C E G♯, makes an augmented chord."),
        chord_q("F#4", "dim", ["maj", "min", "dim"]),
        chord_q("Ab3", "aug", ["min", "dim", "aug"]),
        chord_q("B3", "dim", ["min", "dim", "aug"], broken=True),
        echo("B3", "D4", "F4", hint=ECHO_CHORD),
    ], minutes=5, xp=25),
    lesson("ear-6-4", "The dominant seventh", [
        explain("Add a seventh", "A dominant seventh chord is a major chord plus one more note on top: a minor seventh above "
                "the root, the note the chord is named for. It sounds bluesy and restless.", keyboard(["G3", "B3", "D4", "F4"])),
        chord_q("G3", "7", ["maj", "7"]),
        chord_q("C4", "maj", ["maj", "7"]),
        chord_q("E4", "7", ["min", "7"], broken=True),
        quiz("Which notes spell G7?", ["G B D F", "G B D", "G B♭ D F"], 0,
             "G7 is G major (G B D) plus F, a minor seventh above G."),
        chord_q("A3", "7", ["maj", "min", "7"]),
        chord_q("F4", "maj", ["maj", "min", "7"]),
        chord_q("C4", "7", ["maj", "min", "dim", "7"], broken=True),
        echo("C4", "E4", "G4", "Bb4", hint=ECHO_CHORD),
    ], minutes=5, xp=25),
    lesson("ear-6-5", "Chord qualities challenge", [
        explain("Five colors", "Major, minor, diminished, augmented and dominant seventh: bright, dark, tight, stretched, "
                "restless. Name the color, then the chord."),
        chord_q("D4", "min", ["maj", "min", "dim"]),
        chord_q("Bb3", "7", ["maj", "7", "aug"]),
        chord_q("E4", "aug", ["maj", "min", "aug"]),
        chord_q("G4", "maj", ["maj", "min", "7"]),
        chord_q("C#4", "dim", ["min", "dim", "aug", "7"]),
        chord_q("F3", "min", ["maj", "dim", "aug", "min"], broken=True),
        chord_q("A3", "7", ["maj", "min", "dim", "7"], broken=True),
        echo("A3", "C#4", "E4", "G4", hint=ECHO_CHORD),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 7 Scale degrees

UNIT_7 = unit("ear-7", "Scale degrees", "Hear each note's place in a key, from do, the home note, to ti.", [
    lesson("ear-7-1", "Do, the home note", [
        explain("Home base", "Every key has a home note called the tonic. Singers call it do. Here you'll hear a chord that "
                "sets the key, then a single note to place.", keyboard(["C4", "E4", "G4"])),
        is_home("C4", "do"),
        is_home("F4", "sol"),
        is_home("A3", "do'"),
        explain("Do, re, mi", "The notes of a major scale are do, re, mi, fa, sol, la, ti, then do again. Each is a scale "
                "degree, numbered from do: do is 1, re is 2, up to ti, 7.",
                staff(["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"])),
        degree("D4", "do", ["do", "sol"]),
        degree("G3", "sol", ["do", "sol"]),
        notes(None, ["C4", "D4", "E4"], hint="Sing or play do, re, mi in C major: C, D, E."),
    ]),
    lesson("ear-7-2", "Do, mi and sol", [
        explain("The chord tones", "Do, mi and sol are the notes of the home chord, so they sound stable and at rest. Mi "
                "sounds sweet, sol sounds strong and open, and do sounds finished."),
        degree("C4", "mi", ["do", "mi", "sol"]),
        degree("F4", "sol", ["do", "mi", "sol"]),
        quiz("In C major, which note is sol?", ["E", "F", "G"], 2,
             "Count up from do: C do, D re, E mi, F fa, G sol."),
        degree("Bb3", "mi", ["do", "mi", "sol"]),
        degree("A3", "do'", ["do", "mi", "sol"]),
        degree("E4", "sol,", ["do", "mi", "sol"]),
        notes(None, ["G3", "B3", "D4"], hint="Sing or play do, mi, sol in G major: G, B, D."),
    ]),
    lesson("ear-7-3", "Notes that lean", [
        explain("Notes that lean", "Re, fa, la and ti sound unfinished. Ti sits a half step below do and pulls hard upward. "
                "Fa leans down to mi. Re and la want to step to a neighbor.", staff(["B3", "C4"])),
        degree("C4", "ti,", ["do", "re", "ti"]),
        degree("G3", "re", ["do", "re", "mi"]),
        degree("F4", "fa", ["fa", "sol", "la"]),
        quiz("Which note pulls most strongly up to do?", ["Re", "Ti", "La"], 1,
             "Ti sits just a half step below do, so it leans hard toward it."),
        degree("D4", "la", ["fa", "sol", "la"]),
        degree("A3", "ti,", ["la", "ti", "do"]),
        degree("Bb3", "fa", ["mi", "fa", "sol"]),
        notes(None, ["B3", "C4"], hint="Sing or play ti rising to do in C major: B, then C."),
    ], minutes=5, xp=25),
    lesson("ear-7-4", "All seven, after a cadence", [
        explain("Set the key with a cadence", "A cadence is a short chord pattern that ends a phrase. Hearing one sets the key "
                "firmly. Sing do quietly to yourself, then measure the new note from there."),
        degree("C4", "re", ["re", "mi", "fa"], cadence=True),
        degree("G3", "la", ["sol", "la", "ti"], cadence=True),
        degree("Eb4", "sol", ["mi", "fa", "sol", "la"], cadence=True),
        quiz("Why play a cadence before the note?", ["To set the key", "To set the tempo", "To warm up your voice"], 0,
             "The chords point to do, so you can hear every other note in relation to it."),
        degree("A3", "fa", ["fa", "sol", "la", "ti"], cadence=True),
        degree("D4", "ti,", ["la", "ti", "do"], cadence=True),
        degree("F4", "mi", ["re", "mi", "fa", "sol"], cadence=True),
        notes(None, ["C4", "D4", "E4", "F4", "G4"], hint="Sing or play up the scale from do in C major: C, D, E, F, G."),
    ], minutes=5, xp=25),
    lesson("ear-7-5", "Scale degrees challenge", [
        explain("Find do, then the note", "Chords set the key, then one note plays. Find do first, then name the note. Every "
                "key works the same way."),
        degree("A3", "mi", ["do", "mi", "sol"]),
        degree("D4", "fa", ["re", "mi", "fa"], cadence=True),
        degree("Bb3", "ti,", ["ti", "do", "re"], cadence=True),
        degree("G4", "la", ["sol", "la", "ti", "do"]),
        degree("E4", "sol", ["mi", "fa", "sol", "la"], cadence=True),
        degree("F3", "re", ["do", "re", "mi", "fa"], cadence=True),
        degree("C4", "la", ["fa", "sol", "la", "ti"], cadence=True),
        notes(None, ["D4", "C#4", "D4"], hint="Sing or play do, ti, do in D major: D, C♯, D."),
    ], minutes=6, xp=35, kind="challenge"),
])

# ---------------------------------------------------------------- 8 Melodic dictation

UNIT_8 = unit("ear-8", "Melodic dictation", "Hear short melodies, pick out the one you heard, and sing it back.", [
    lesson("ear-8-1", "Three-note melodies", [
        explain("Melodic dictation", "Dictation means hearing a melody and writing it down. Here you pick it from a list. Find "
                "do from the chord, then follow each move: up or down, step or skip."),
        melody("C4", ["do re mi", "do mi re", "mi re do"], 0),
        echo_tune("C4", "do re mi"),
        melody("F4", ["do re mi", "mi re do", "re mi do"], 1),
        melody("G3", ["do mi sol", "sol mi do", "do sol mi"], 2),
        explain("Sketch the shape", "Before naming notes, trace the shape with your hand: up, down or bending. Most wrong "
                "answers have the wrong shape, so you can rule them out fast."),
        melody("D4", ["do re do", "do ti, do", "re do ti,"], 1),
        echo_tune("D4", "do ti, do"),
    ]),
    lesson("ear-8-2", "Skips in a melody", [
        explain("Skips stand out", "Steps sound smooth; skips jump out. When you hear a jump, check whether it lands on a note "
                "of the home chord: do, mi or sol."),
        melody("A3", ["do mi sol", "do re mi", "do mi re"], 0),
        melody("Bb3", ["sol mi do", "sol fa mi", "mi sol do"], 1),
        echo_tune("Bb3", "sol fa mi"),
        quiz("A melody goes do, mi, sol. How does it move?", ["Two skips up", "Two steps up", "A step, then a skip"], 0,
             "Do to mi skips re, and mi to sol skips fa."),
        melody("E4", ["mi do sol,", "mi re do", "mi sol do"], 0),
        melody("C4", ["do sol mi", "do la sol", "do sol la"], 2),
        echo_tune("C4", "do sol la"),
    ]),
    lesson("ear-8-3", "Four-note melodies", [
        explain("Four notes", "Longer melodies use the same tools. Lock in the first note against do, then take the rest one "
                "move at a time."),
        melody("G3", ["do re mi do", "do re mi re", "do mi re do"], 0),
        melody("D4", ["mi re do re", "mi fa sol mi", "mi re do ti,"], 2),
        echo_tune("D4", "mi re do ti,"),
        melody("F4", ["sol la sol mi", "sol mi re do", "sol fa mi re"], 1),
        quiz("A melody stops on ti. How does it sound?", ["Unfinished", "Finished", "Out of tune"], 0,
             "Ti leans up to do, so a melody that stops on ti feels like it's waiting."),
        melody("A3", ["do mi re do", "do mi sol do'", "do mi sol mi"], 1),
        melody("C4", ["mi fa mi re", "mi re do re", "mi re mi fa"], 1),
        echo_tune("C4", "mi re do re"),
    ], minutes=5, xp=25),
    lesson("ear-8-4", "Below do", [
        explain("Below do", "Melodies often dip under do to ti, la or sol below. They're the same notes, just lower. Many "
                "tunes start on sol below and leap up to do."),
        melody("C4", ["sol, do re", "sol, ti, do", "do sol, do"], 0),
        melody("F4", ["do ti, la, sol,", "do ti, do re", "do la, ti, do"], 2),
        echo_tune("F4", "do la, ti, do"),
        quiz("Amazing Grace starts on sol below do and leaps up. To which note?", ["Do", "Mi", "Sol"], 0,
             "Sol up to do is a perfect fourth, the interval you learned with this tune."),
        melody("G3", ["do sol, la, ti,", "do ti, la, sol,", "do re ti, do"], 1),
        melody("Bb3", ["sol, la, ti, do", "sol, do ti, do", "la, ti, do re"], 0),
        echo_tune("Bb3", "sol, la, ti, do"),
    ]),
    lesson("ear-8-5", "Dictation challenge", [
        explain("Hear it, find it, sing it", "Chords first, then the melody. Find do, trace the shape, name each note, then "
                "sing or play it back."),
        melody("E4", ["do re mi fa", "do mi re fa", "do re fa mi"], 2),
        echo_tune("E4", "do re fa mi"),
        melody("A3", ["sol mi do re", "sol mi re do", "sol fa mi do"], 1, cadence=True),
        melody("D4", ["do ti, la, ti,", "do ti, do re", "do re do ti,"], 2),
        melody("Ab3", ["mi sol do' ti", "mi sol la sol", "mi fa sol la"], 1),
        echo_tune("Ab3", "mi sol la sol"),
        melody("C4", ["sol, do mi sol", "sol, ti, re sol", "do mi sol do'"], 0, cadence=True),
        echo_tune("C4", "sol, do mi sol"),
    ], minutes=6, xp=40, kind="challenge"),
])

COURSE = course("ear", "Ear Training", "Hear intervals and chords, and sing back what you hear", None, "ear", "violet", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6, UNIT_7, UNIT_8,
])
