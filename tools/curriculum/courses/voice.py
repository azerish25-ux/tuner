"""Singing: posture and breath, pitch matching, scales, intervals, five public-domain melodies, and control.

Timbre accepts the right note in any octave from a voice, so melodies are written around C4-C5 and
low and high voices both sing them where they're comfortable. Exercises and practice phrases are sung on "ah",
"loo" or "da"; each song lesson ends on its whole song with its public-domain words, the band playing the intro.
"""
from lib import along, chord, course, explain, keyboard, lesson, listen, notes, quiz, staff, unit
from songbook import Part, song
import tunes

V = None  # no instrument: no fret positions

C_MAJOR = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
SCALE_UP_DOWN = "C4 D4 E4 F4 G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4:2"
LONG_TONES = "G4:4 r:4 E4:4 r:4 C4:8"  # four-beat holds with a full bar to breathe
FIVE_UP_DOWN = "C4:1 D4:1 E4:1 F4:1 G4:2 r:2 G4:1 F4:1 E4:1 D4:1 C4:4"

# ---------------------------------------------------------------- melodies (traditional / public domain)

# "Twinkle Twinkle Little Star": traditional French melody, 1761. C major, 4/4.
TWINKLE_A = "C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2"
TWINKLE_B = "G4 G4 F4 F4 E4 E4 D4:2 G4 G4 F4 F4 E4 E4 D4:2"
TWINKLE = f"{TWINKLE_A} {TWINKLE_B} {TWINKLE_A}"

# "Ode to Joy": Beethoven, Symphony No. 9 (1824). F major so it sits between C4 and C5, 4/4.
ODE_A = "A4 A4 Bb4 C5 C5 Bb4 A4 G4 F4 F4 G4 A4 A4:1.5 G4:0.5 G4:2"
ODE_B = "A4 A4 Bb4 C5 C5 Bb4 A4 G4 F4 F4 G4 A4 G4:1.5 F4:0.5 F4:2"
ODE_C = "G4 G4 A4 F4 G4 A4:0.5 Bb4:0.5 A4 F4 G4 A4:0.5 Bb4:0.5 A4 G4 F4 G4 C4:2"
ODE = f"{ODE_A} {ODE_B} {ODE_C} {ODE_B}"

# "Auld Lang Syne": traditional Scottish melody, published 1799. F major, 4/4, one-beat pickup.
ALS_A = "r:3 C4 F4:1.5 F4:0.5 F4 A4 G4:1.5 F4:0.5 G4 A4 F4:1.5 F4:0.5 A4 C5 D5:3"
ALS_B = "D5 C5:1.5 A4:0.5 A4 F4 G4:1.5 F4:0.5 G4 A4 F4:1.5 D4:0.5 D4 C4 F4:3"
ALS = f"{ALS_A} {ALS_B}"

# "Amazing Grace": the hymn tune "New Britain", early 1800s. F major, 3/4, one-beat pickup.
AG_A = "r:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 F4:2 D4 C4:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 C5:3"
AG_B = "r:2 A4 C5:2 A4:0.5 F4:0.5 A4:2 G4 F4:2 D4 C4:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 F4:3"
AG = ("r:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 F4:2 D4 C4:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 C5:4 r:1 "
      "A4 C5:2 A4:0.5 F4:0.5 A4:2 G4 F4:2 D4 C4:2 C4 F4:2 A4:0.5 F4:0.5 A4:2 G4 F4:3")

# "Shenandoah": American folk song, 1800s. C major, 4/4, one-beat pickup.
SHEN_A = "r:3 G3 C4 C4 C4:2 D4 E4 F4 A4 G4:3 C5 B4 A4:2 G4 A4 G4 E4:2"
SHEN_B = "r:3 G4 A4 A4 A4:2 E4 G4 E4 D4 C4:3 D4 E4 C4 E4 A4 G4:3 C4 D4 E4 C4 D4 C4:4"
SHEN = f"{SHEN_A} {SHEN_B}"

# ---------------------------------------------------------------- whole songs (songbook)
# Each song lesson ends on its whole song: two bars of band to breathe in, the verses with their words, and a last
# line to finish. A voice has no shapes, so the charts carry guitar shapes for whoever accompanies.
GTR = "guitar"
SHAPES = {c["name"]: c for c in [
    chord(GTR, "C", "x32010"), chord(GTR, "F", "xx3211"), chord(GTR, "G", "320003"), chord(GTR, "G7", "320001"),
    chord(GTR, "C7", "x32310"), chord(GTR, "Bb", "x13331"), chord(GTR, "Am", "x02210"), chord(GTR, "Dm", "xx0231"),
]}
BAND_IN = "r:4 r:4"            # two bars of the band before the first verse
THE_VERSE = "The verse"


def voice_song(bpm, parts, beats_per_bar=4, words=None):
    return song(V, bpm, parts, beats_per_bar=beats_per_bar, shapes=SHAPES, words=words)


# Twinkle Twinkle Little Star: Jane Taylor's verses (1806), each with the opening lines as a refrain.
TW_V = Part("Verse 1", "verse", f"{TWINKLE_A} {TWINKLE_B}", chords=f"{tunes.TWINKLE_CHORDS_A} {tunes.TWINKLE_CHORDS_B}",
            lyrics=tunes.TWINKLE_WORDS_1)
TW_C = Part("Chorus", "chorus", TWINKLE_A, chords=tunes.TWINKLE_CHORDS_A, lyrics=tunes.TWINKLE_REFRAIN)
TWINKLE_SONG = voice_song(72, [
    Part("Intro", "intro", BAND_IN, chords="C G"),
    TW_V, TW_C,
    TW_V.with_lyrics("Verse 2", tunes.TWINKLE_WORDS_2), TW_C,
    TW_V.with_lyrics("Verse 3", tunes.TWINKLE_WORDS_3), TW_C,
    Part("Outro", "outro", "F4 F4 E4 E4 D4 D4 C4:2", chords="F,C G,C", lyrics="how I won-der what you are!"),
], words=tunes.TWINKLE_CREDIT)

# Ode to Joy, in F: two stanzas of Schiller's An die Freude (1785), the words Beethoven set.
VO_A1, VO_A2, VO_B, _ = tunes.ode(5)
VO_CHART = tunes.transpose_chords(tunes.ODE_CHORDS, 5, flats=True)
VO_ODE_V = Part("Verse 1", "verse", f"{VO_A1} {VO_A2} {VO_B} {VO_A2}", chords=VO_CHART, lyrics=tunes.ODE_WORDS_1)
ODE_SONG = voice_song(76, [
    Part("Intro", "intro", BAND_IN, chords="F C"),
    VO_ODE_V,
    VO_ODE_V.with_lyrics("Verse 2", tunes.ODE_WORDS_2),
    Part("Outro", "outro", VO_A2, chords="F C F C,F", lyrics=tunes.ODE_WORDS_END),
], words=tunes.ODE_CREDIT)

# Auld Lang Syne, in F: Burns's first verse and the chorus (1788), the verse again on "loo", the chorus once more.
ALS_VERSE = f"{ALS_A.replace('r:3 ', '', 1)} {ALS_B.rsplit(' ', 1)[0]} F4:4"
ALS_CHORUS = ("D5 C5:1.5 A4:0.5 A4 F4 G4:1.5 F4:0.5 G4 D5 C5:1.5 A4:0.5 A4 C5 D5:3"
              " F5 C5:1.5 A4:0.5 A4 F4 G4:1.5 F4:0.5 G4 A4 F4:1.5 D4:0.5 D4 C4 F4:4")
ALS_V = Part("Verse 1", "verse", ALS_VERSE, pickup=1, chords="F C7 F Bb F C7 Bb F", lyrics=(
    "Should auld ac-quain-tance be for-got, / and nev-er brought to mind? / Should auld ac-quain-tance be for-got, / "
    "and days of auld lang syne?"))
ALS_C = Part("Chorus", "chorus", ALS_CHORUS, pickup=1, chords="F C7 F Bb F C7 Bb F", lyrics=(
    "For auld lang syne, my dear, _ / for auld lang _ syne, _ _ / we'll take a cup o' kind-ness yet / for days of auld lang syne."))
ALS_SONG = voice_song(72, [
    Part("Intro", "intro", BAND_IN, chords="Bb F"),
    ALS_V, ALS_C,
    ALS_V.instrumental("Solo"),
    ALS_C,
    Part("Outro", "outro", "A4 F4:1.5 D4:0.5 D4 C4 F4:4", pickup=1, chords="Bb F", lyrics="for days of auld lang syne."),
], words="Robert Burns (1788)")

# Amazing Grace, in F: four of John Newton's verses (1779), with a breath after "me".
VO_AMAZING = tunes.transpose(tunes.AMAZING, 10).replace("C5:5", "C5:4 r:1", 1)
VO_AMAZING_CHART = tunes.transpose_chords(tunes.AMAZING_CHORDS, 10, flats=True)
VO_AMAZING_V = Part("Verse 1", "verse", VO_AMAZING, pickup=1, chords=VO_AMAZING_CHART, lyrics=tunes.AMAZING_WORDS_1)
AMAZING_SONG = voice_song(72, [
    Part("Intro", "intro", "r:3 r:3", chords="F C7"),
    VO_AMAZING_V,
    VO_AMAZING_V.with_lyrics("Verse 2", tunes.AMAZING_WORDS_2),
    VO_AMAZING_V.with_lyrics("Verse 3", tunes.AMAZING_WORDS_3),
    VO_AMAZING_V.with_lyrics("Verse 4", tunes.AMAZING_WORDS_4),
    Part("Outro", "outro", tunes.transpose(tunes.AMAZING_TAIL, 10), pickup=1,
         chords=tunes.transpose_chords(tunes.AMAZING_TAIL_CHORDS, 10, flats=True), lyrics=tunes.AMAZING_WORDS_END),
], beats_per_bar=3, words=tunes.AMAZING_CREDIT)

# Shenandoah: three traditional verses (sung by the 1800s), "Shenandoah" in three syllables as sailors sang it.
SHEN_V = Part("Verse 1", "verse", f"{SHEN_A.replace('r:3 ', '', 1)} {SHEN_B}", pickup=1,
              chords="C Dm C G Am C F C C Am C G C", lyrics=(
    "Oh Shen-an-doah, I long to see you, / a-way, you roll-ing riv-er. / Oh Shen-an-doah, I long to see you, / "
    "a-way, I'm bound a-way, 'cross the wide Mis-sou-ri."))
SHEN_SONG = voice_song(66, [
    Part("Intro", "intro", BAND_IN, chords="C G"),
    SHEN_V,
    SHEN_V.with_lyrics("Verse 2", "Oh Shen-an-doah, I love your daugh-ter, / a-way, you roll-ing riv-er. / For her I'd cross "
                                  "your roam-ing wa-ters, / a-way, I'm bound a-way, 'cross the wide Mis-sou-ri."),
    SHEN_V.with_lyrics("Verse 3", "'Tis sev-en years since last I saw you, / a-way, you roll-ing riv-er. / 'Tis sev-en years "
                                  "since last I saw you, / a-way, we're bound a-way, 'cross the wide Mis-sou-ri."),
    Part("Outro", "outro", "D4 E4 C4 E4 A4 G4:3 C4 D4 E4 C4 D4 C4:4", pickup=1, chords="Am C G C",
         lyrics="a-way, I'm bound a-way, 'cross the wide Mis-sou-ri."),
], words="Traditional (19th century)")

# Hints shared across lessons (identical text translates once).
HUM = "Hum C, E and G, one at a time. Keep it light."
TRILL = "Lip trill on G, E, then C. If your lips stop, press your cheeks lightly."
HOLD_C = 'Sing C on "ah" and hold it steady until it locks in.'
FIVE_UP = "Do, re, mi, fa, sol: C up to G."
SCALE_UP = "Do to do: C up to the next C."
SCALE_DOWN = "Back down from C to C. Keep each lower note bright so it doesn't sag flat."

# The first song, unit 1 (free): Mary Had a Little Lamb on three notes, E D C, with the band two bars ahead.
MARY_FIRST = tunes.mary3(0)
MARY_FIRST_SONG = voice_song(84, tunes.mary3_parts(0, tunes.MARY_CHORDS, intro=BAND_IN), words=tunes.MARY_CREDIT)

UNIT_1 = unit("voc-1", "Finding your voice", "Stand tall, breathe low, hold your first steady note and sing a song.", [
    lesson("voc-1-1", "Stand and breathe", [
        explain("Stand tall, stay loose", "Stand with your feet hip-width apart and knees soft. Let your shoulders drop and your head float up, as if a string lifts it. Keep your jaw loose."),
        explain("Breathe low", "Rest a hand on your belly and breathe in slowly. Your belly and lower ribs widen while your shoulders stay still. That low breath powers your voice."),
        quiz("When you breathe in to sing, what should move?", ["Your shoulders", "Your belly and lower ribs", "Nothing at all"], 1,
             "A low breath widens your ribs and belly. Lifting your shoulders tightens your neck and throat."),
        explain("Any octave counts", "Timbre listens for the note's name, so a C sung low or high both count. Pick the octave that feels easy, never strained.",
                keyboard(["C3", "C4", "C5"])),
        notes(V, ["C4"], hint='Breathe low, then sing C on "ah" in a comfortable octave. Hold it steady.'),
        notes(V, ["C4"], hint="Once more: stand tall, breathe low, and let the note ring."),
    ], minutes=3, xp=15),
    lesson("voc-1-2", "Hold one note", [
        explain("Sustain with even air", "To sustain is to hold a note at one steady pitch. Let the air out slowly and evenly, like fogging a mirror without stopping."),
        notes(V, ["C4"], hint=HOLD_C),
        quiz("Your note wobbles and fades. What helps most?", ["Singing louder", "Tightening your throat", "Slow, even air"], 2,
             "Steady air makes a steady note. Extra volume and tension make it harder to control."),
        notes(V, ["E4"], hint='Now E. Same low breath, same easy "ah."'),
        explain("Open vowel, open throat", 'Sing "ah" with your jaw dropped and the tip of your tongue resting behind your lower teeth. The sound flows out instead of getting squeezed.'),
        notes(V, ["G4"], hint='G this time. Drop your jaw and keep the "ah" open.'),
        along(V, "C4:3 r:1 E4:3 r:1 G4:4", bpm=60, title="Hold and breathe"),
    ], minutes=4, xp=20),
    lesson("voc-1-3", "Match a pitch", [
        explain("Hear it, then sing it", "Matching pitch means singing the same note you hear. Listen, imagine the note for a moment, then sing softly and adjust until it settles."),
        listen("Which is higher?", [["C4"], ["E4"]], ["The first", "The second"], 1),
        notes(V, ["E4"], hint="Sing E softly, then adjust until it settles."),
        explain("Flat and sharp", "Flat means under the target pitch; sharp means over it. If you're flat, lift a little. If you're sharp, ease down. Small moves work best."),
        quiz("Timbre says you're flat. What do you do?", ["Sing a little higher", "Sing a little lower", "Sing louder"], 0,
             "Flat means under the note, so lift the pitch slightly."),
        listen("Same note or different?", [["D4"], ["D4"]], ["Same", "Different"], 0),
        notes(V, ["D4", "G4"], hint="Two notes this time: D, then G. Take a breath between them."),
    ], minutes=4, xp=20),
    lesson("voc-1-4", "Warm up gently", [
        explain("Hum to warm up", "Humming with your lips closed is a gentle warm-up. You should feel a light buzz on your lips and nose. Keep it soft and easy."),
        notes(V, ["C4", "E4", "G4"], hint=HUM),
        explain("Lip trills", "Close your lips loosely and blow so they flutter like a motorboat, then add your voice. It keeps your throat relaxed while your voice wakes up."),
        notes(V, ["G4", "E4", "C4"], hint=TRILL),
        quiz("A note feels tight or scratchy. What do you do?", ["Push harder through it", "Clear your throat hard", "Stop, rest, and try it softer"], 2,
             "Strain is a signal to ease off. Rest, sip some water, and come back lighter."),
        along(V, "C4:2 D4:2 E4:3 r:1 E4:2 D4:2 C4:4", bpm=60, title="Easy hum"),
    ], minutes=4, xp=20),
    lesson("voc-1-5", "First notes", [
        explain("Put it together", "Stand tall, breathe low, and start each note softly. Rest between steps if your voice feels tired."),
        notes(V, ["C4"], hint=HOLD_C),
        listen("Which is higher?", [["G4"], ["E4"]], ["The first", "The second"], 0),
        notes(V, ["E4", "G4"], hint="E, then G. Hear each one before you sing it."),
        quiz("What does sharp mean?", ["Under the target pitch", "Louder than the note", "Over the target pitch"], 2,
             "Sharp is over the target pitch; flat is under it."),
        notes(V, ["D4"], hint="Sing D softly, then adjust until it settles."),
        along(V, "C4:2 E4:2 G4:3 r:1 G4:2 E4:2 C4:4", bpm=60, title="Up and home"),
    ], minutes=5, xp=30, kind="challenge"),
    lesson("voc-1-6", "Mary Had a Little Lamb", [
        explain("Your first song", "Mary Had a Little Lamb needs three notes: E, D and C, each a step from the next. "
                "Sing it where it feels easy; Timbre hears the right note in any octave.", keyboard(["E4", "D4", "C4"])),
        notes(V, ["E4", "D4", "C4"], hint="E, D, C: three steps down to home."),
        notes(V, ["E4", "D4", "C4", "D4", "E4", "E4", "E4"], hint="Ma-ry had a lit-tle lamb: E D C D E E E."),
        along(V, MARY_FIRST[0], bpm=66, title="First half"),
        MARY_FIRST_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
        MARY_FIRST_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_FIRST_SONG.minutes(), xp=30, kind="song", arrangement=MARY_FIRST_SONG.meta()),
])

UNIT_2 = unit("voc-2", "Pitch matching", "Hear a note, sing it back, and move by small steps.", [
    lesson("voc-2-1", "Hear it first", [
        explain("Imagine before you sing", "Before you sing, hear the note in your head for a second. That pause lets your voice aim for the pitch instead of hunting for it."),
        notes(V, ["D4"], hint="Hear D in your head, then sing it."),
        listen("Same note or different?", [["F4"], ["E4"]], ["Same", "Different"], 1),
        notes(V, ["F4"], hint="Hear F in your head, then sing it."),
        quiz("Your first try lands flat. What next?", ["Lift a little and hold", "Give up on that note", "Jump up a lot"], 0,
             "Small changes find the note fastest. Lift gently and let it settle."),
        notes(V, ["A4"], hint="Hear A in your head, then sing it."),
        notes(V, ["D4", "F4", "A4"], hint="Three notes in a row: D, F, A."),
    ], minutes=4, xp=20),
    lesson("voc-2-2", "Unison and repeats", [
        explain("Unison: the same note", "Unison means two sounds on exactly the same pitch. When they match, they blend into one; when they're slightly off, you hear a wobble."),
        listen("Same note or different?", [["E4"], ["F4"]], ["Same", "Different"], 1),
        notes(V, ["E4"], hint="Sing E and hold it in tune."),
        explain("Repeat a note cleanly", 'To sing the same note twice, stop the air for a moment, then start again on a soft "da." Don\'t slide between them.'),
        notes(V, ["E4", "E4", "E4"], hint='Sing E three times on "da," with a tiny gap each time.'),
        along(V, "E4 E4 E4:2 G4 G4 G4:2 E4 E4 D4 D4 C4:4", bpm=60, title="Same note, fresh start"),
    ], minutes=4, xp=20),
    lesson("voc-2-3", "Steps and half steps", [
        explain("A step is the next note", "A step moves to the next note of a scale, up or down. Steps are the smallest, easiest moves to sing in tune.",
                staff(["C4", "D4", "E4"])),
        notes(V, ["C4", "D4", "E4"], hint="Step up: C, D, E."),
        listen("Did it go up or down?", [["E4"], ["D4"]], ["Up", "Down"], 1),
        explain("The half step", "A half step is the smallest step, like E to F, with no note between. Most neighboring scale notes, like C and D, are a whole step apart: two half steps.",
                keyboard(["E4", "F4"])),
        notes(V, ["E4", "F4", "E4"], hint="E, up a half step to F, and back."),
        listen("Half step or whole step?", [["E4"], ["F4"]], ["Half step", "Whole step"], 0),
        along(V, "C4 D4 E4 F4 E4:2 D4:2 C4:4", bpm=60, title="Step by step"),
    ], minutes=4, xp=20),
    lesson("voc-2-4", "Match and move", [
        explain("Put it together", "Hear each note in your head first, start softly, and adjust in small moves. Give repeated notes a fresh start."),
        notes(V, ["G4"], hint="Hear G in your head, then sing it."),
        listen("Did it go up or down?", [["F4"], ["G4"]], ["Up", "Down"], 0),
        notes(V, ["B4", "C5", "B4"], hint="B, up a half step to C, and back."),
        quiz("Which is a half step?", ["C to D", "G to A", "E to F"], 2,
             "E to F has no note between them. C to D and G to A are whole steps."),
        listen("Same note or different?", [["A4"], ["A4"]], ["Same", "Different"], 0),
        along(V, "G4 G4 A4:2 G4 F4 E4:2 F4 F4 E4 D4 C4:4", bpm=66, title="Steps and repeats"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_3 = unit("voc-3", "Scales", "Sing do-re-mi, the major scale, and five-note patterns.", [
    lesson("voc-3-1", "Do, re, mi", [
        explain("Solfege names the steps", "Solfege gives each step of the scale a syllable: do, re, mi, fa, sol, la, ti, do. Do is home, wherever the scale starts.",
                staff(C_MAJOR)),
        notes(V, ["C4", "D4", "E4"], hint="Sing do, re, mi on C, D, E."),
        quiz("Which syllable is home, the first step of the scale?", ["Do", "Mi", "Sol"], 0,
             "Do is the first step and the note a scale comes back to."),
        notes(V, ["E4", "D4", "C4"], hint="Now back down: mi, re, do."),
        listen("Did it go up or down?", [["C4"], ["D4"], ["E4"]], ["Up", "Down"], 0),
        along(V, "C4 D4 E4:2 E4 D4 C4:2 C4 D4 E4 D4 C4:4", bpm=60, title="Do, re, mi"),
    ], minutes=4, xp=20),
    lesson("voc-3-2", "Do to sol", [
        explain("Five steps: do to sol", "Do, re, mi, fa, sol: the first five steps carry many simple tunes. Sing them up and back down on one breath if it feels easy.",
                staff(["C4", "D4", "E4", "F4", "G4"])),
        notes(V, ["C4", "D4", "E4", "F4", "G4"], hint=FIVE_UP),
        quiz("Between which two steps is there a half step?", ["Do and re", "Fa and sol", "Mi and fa"], 2,
             "Mi to fa (E to F) is a half step. The other steps from do to sol are whole steps."),
        notes(V, ["G4", "F4", "E4", "D4", "C4"], hint="Sol back down to do: G down to C."),
        listen("Did it go up or down?", [["G4"], ["F4"], ["E4"]], ["Up", "Down"], 1),
        along(V, FIVE_UP_DOWN, bpm=66, title="Up five, down five"),
    ], minutes=4, xp=20),
    lesson("voc-3-3", "The major scale", [
        explain("All eight steps", "The major scale runs from do up to the next do: eight notes. Mi to fa and ti to do are half steps; every other step is a whole step.",
                staff(C_MAJOR)),
        notes(V, C_MAJOR, hint=SCALE_UP),
        quiz("Where are the half steps in a major scale?", ["Mi-fa and ti-do", "Do-re and sol-la", "Re-mi and la-ti"], 0,
             "Mi-fa and ti-do are half steps. That pattern gives the major scale its sound."),
        explain("Lighter at the top", "Take a low breath before you start so you don't run out near the top. Let high notes get lighter, not louder, and keep your jaw loose."),
        notes(V, list(reversed(C_MAJOR)), hint=SCALE_DOWN),
        along(V, SCALE_UP_DOWN, bpm=60, title="Major scale, up and down"),
    ], minutes=5, xp=25),
    lesson("voc-3-4", "Five-note patterns", [
        explain("Patterns train your ear", "Short patterns like do-re-mi-re-do build accuracy fast. Sing one, then start it a step higher and let the scale guide you."),
        notes(V, ["C4", "D4", "E4", "D4", "C4"], hint="Do, re, mi, re, do."),
        listen("Which pattern did you hear?", [["C4"], ["D4"], ["E4"], ["D4"], ["C4"]], ["Up, then back down", "Down, then back up", "Straight up"], 0),
        notes(V, ["C4", "D4", "E4", "F4", "G4", "F4", "E4", "D4", "C4"], hint="Do up to sol and back: C to G to C."),
        quiz("Sing C-D-E-D-C, then the same shape one step higher. What's the top note now?", ["E", "F", "G"], 1,
             "One step higher, the shape becomes D, E, F, E, D."),
        along(V, "C4 D4 E4 D4 C4:2 r:2 D4 E4 F4 E4 D4:2 r:2 E4 F4 G4 F4 E4:2 r:2 F4 G4 A4 G4 F4:4", bpm=66, title="Climb the pattern"),
    ], minutes=4, xp=20),
    lesson("voc-3-5", "Scale check", [
        explain("Put it together", "Breathe low before each scale, keep the top light, and keep lower notes bright on the way down."),
        notes(V, ["C4", "D4", "E4", "F4", "G4"], hint=FIVE_UP),
        quiz("How many notes are in a major scale, do to do?", ["Five", "Seven", "Eight"], 2,
             "Do, re, mi, fa, sol, la, ti, do: eight notes, with do at both ends."),
        notes(V, C_MAJOR, hint=SCALE_UP),
        listen("Which pattern did you hear?", [["E4"], ["D4"], ["C4"], ["D4"], ["E4"]], ["Up, then back down", "Down, then back up", "Straight down"], 1),
        notes(V, list(reversed(C_MAJOR)), hint=SCALE_DOWN),
        along(V, f"{SCALE_UP_DOWN} C4 D4 E4 D4 C4:4", bpm=66, title="Scale and pattern"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_4 = unit("voc-4", "Intervals you can sing", "Leap by thirds, fifths and octaves, and land in tune.", [
    lesson("voc-4-1", "Thirds", [
        explain("Skip a step: the third", "An interval is the distance between two notes. Skip one scale step and you get a third, like do to mi. Hear mi in your head before you leave do.",
                staff(["C4", "E4"])),
        notes(V, ["C4", "E4", "C4"], hint="Do to mi and back: C, E, C."),
        listen("A step or a skip?", [["C4"], ["E4"]], ["A step", "A skip (a third)"], 1),
        notes(V, ["D4", "F4", "D4"], hint="Another third: D, F, D."),
        quiz("Which pair is a third?", ["C and D", "C and G", "C and E"], 2,
             "C to E skips over D, so it spans three scale notes: a third."),
        along(V, "C4 E4 D4 F4 E4 G4 F4 A4 G4:4", bpm=60, title="Thirds up the scale"),
    ], minutes=4, xp=20),
    lesson("voc-4-2", "Fifths", [
        explain("Do to sol: the fifth", "Do to sol spans five scale notes, a fifth. It sounds open and strong. Picture the steps in between, then jump straight to sol.",
                staff(["C4", "G4"])),
        notes(V, ["C4", "G4", "C4"], hint="Do to sol and back: C, G, C."),
        listen("Third or fifth?", [["C4"], ["G4"]], ["Third", "Fifth"], 1),
        notes(V, ["C4", "E4", "G4"], hint="Do, mi, sol: two thirds stack up to a fifth."),
        quiz("Counting both ends, how many scale notes from do to sol?", ["Three", "Five", "Eight"], 1,
             "Do, re, mi, fa, sol: five notes, so it's a fifth."),
        listen("Third or fifth?", [["D4"], ["F4"]], ["Third", "Fifth"], 0),
        along(V, "C4 E4 G4:2 G4 E4 C4:2 C4 G4 E4 G4 C4:4", bpm=60, title="Do, mi, sol"),
    ], minutes=4, xp=20),
    lesson("voc-4-3", "The octave", [
        explain("Same name, eight notes up", "An octave leaps from do to the next do, eight scale notes up. The two notes share a name and blend so well they almost sound like one.",
                staff(["C4", "C5"])),
        listen("Octave or fifth?", [["C4"], ["C5"]], ["Octave", "Fifth"], 0),
        explain("Leap without reaching", "Before an octave leap, breathe low and keep your chin level. Think of the top note as light and easy, not a stretch upward."),
        notes(V, ["C4", "G4", "C5"], hint="C, then G, then the high C. Use the G as a stepping stone."),
        quiz("Why do the two notes of an octave blend so well?", ["They're the same pitch", "The top one vibrates twice as fast", "They're always sung loudly"], 1,
             "The top note vibrates exactly twice as fast as the bottom one, so their waves line up."),
        listen("Octave or fifth?", [["D4"], ["A4"]], ["Octave", "Fifth"], 1),
        along(V, "C4:2 C5:2 B4 A4 G4:2 F4 E4 D4 E4 C4:4", bpm=60, title="Leap and step down"),
    ], minutes=5, xp=25),
    lesson("voc-4-4", "Leaps and landings", [
        explain("Put it together", "Hear each leap in your head before you sing it. Land lightly on the top note, then step home."),
        notes(V, ["C4", "E4", "G4", "C5"], hint="Do, mi, sol, high do."),
        listen("Third or fifth?", [["E4"], ["G4"]], ["Third", "Fifth"], 0),
        notes(V, ["C5", "G4", "E4", "C4"], hint="High do, sol, mi, do: back down."),
        quiz("What is the interval from do to the next do?", ["A fifth", "A third", "An octave"], 2,
             "Do to the next do spans eight scale notes: an octave."),
        listen("Octave or fifth?", [["F4"], ["C5"]], ["Octave", "Fifth"], 1),
        along(V, "C4 E4 G4 C5 G4 E4 C4:2 D4 F4 A4:2 G4 E4 C4:2", bpm=66, title="Leaps and landings"),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_5 = unit("voc-5", "Melodies", "Five public-domain tunes, melody only, at an easy pace.", [
    lesson("voc-5-1", "Twinkle Twinkle Little Star", [
        explain("A tune you already know", 'This traditional melody leaps up, then steps back down home. Sing it on "loo" and give each repeated note a fresh start.',
                staff(["C4", "C4", "G4", "G4", "A4", "A4", "G4"])),
        notes(V, ["C4", "G4", "A4", "G4"], hint="The opening leap: C up to G, step to A, back to G."),
        along(V, TWINKLE_A, bpm=60, title="First phrase"),
        listen("The middle phrase: does it go up or down?", [["G4"], ["G4"], ["F4"], ["F4"], ["E4"], ["E4"], ["D4"]], ["Up", "Down"], 1),
        along(V, TWINKLE_B, bpm=66, title="Middle phrase"),
        along(V, TWINKLE, bpm=72, title="Twinkle Twinkle Little Star"),
        TWINKLE_SONG.take("Twinkle Twinkle Little Star"),
    ], minutes=TWINKLE_SONG.minutes(), xp=30, kind="song", arrangement=TWINKLE_SONG.meta()),
    lesson("voc-5-2", "Ode to Joy", [
        explain("Beethoven's famous tune", "This melody from Beethoven's Ninth Symphony moves almost entirely by step. Keep it smooth and even, like walking up and down a staircase.",
                staff(["A4", "A4", "Bb4", "C5", "C5", "Bb4", "A4", "G4"])),
        notes(V, ["F4", "G4", "A4", "Bb4", "C5"], hint="The five notes the tune lives on: F up to C."),
        along(V, ODE_A, bpm=66, title="First phrase"),
        quiz("The first phrase ends with a dotted note. How does it feel?", ["Long, then short", "Short, then long", "Two equal notes"], 0,
             "The dotted note is held longer, then a short note leads into the last one."),
        along(V, ODE_B, bpm=66, title="Second phrase"),
        along(V, ODE_C, bpm=66, title="Middle phrase"),
        along(V, ODE, bpm=76, title="Ode to Joy"),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=30, kind="song", arrangement=ODE_SONG.meta()),
    lesson("voc-5-3", "Auld Lang Syne", [
        explain("Start with a pickup", "This traditional Scottish melody starts with a pickup, a note before the first full bar. Sing it lightly, then lean on the next note.",
                staff(["C4", "F4", "F4", "F4", "A4"])),
        notes(V, ["F4", "A4", "C5", "D5"], hint="The climb in the third bar: F, A, C, up to D."),
        along(V, ALS_A, bpm=60, title="First half"),
        quiz("What is a pickup?", ["The loudest note of a song", "A rest at the end", "A note before the first full bar"], 2,
             "A pickup leads into beat 1 of the first full bar."),
        along(V, f"r:3 {ALS_B}", bpm=60, title="Second half"),
        along(V, ALS, bpm=72, title="Auld Lang Syne"),
        ALS_SONG.take("Auld Lang Syne"),
    ], minutes=ALS_SONG.minutes(), xp=30, kind="song", arrangement=ALS_SONG.meta()),
    lesson("voc-5-4", "Amazing Grace", [
        explain("Three beats to a bar", "This American hymn tune from the early 1800s is in 3/4: count 1, 2, 3. Long notes often turn into a quick pair, so keep the pair light.",
                staff(["C4", "F4", "A4", "F4", "A4", "G4"])),
        notes(V, ["F4", "A4", "F4"], hint="The quick turn: F, up to A, back to F."),
        along(V, AG_A, bpm=60, beats_per_bar=3, title="First half"),
        quiz("How many beats are in each bar of this hymn?", ["Two", "Three", "Four"], 1,
             "It's in 3/4: three beats per bar, with the weight on 1."),
        along(V, AG_B, bpm=60, beats_per_bar=3, title="Second half"),
        along(V, AG, bpm=72, beats_per_bar=3, title="Amazing Grace"),
        AMAZING_SONG.take("Amazing Grace"),
    ], minutes=AMAZING_SONG.minutes(), xp=35, kind="song", arrangement=AMAZING_SONG.meta()),
    lesson("voc-5-5", "Shenandoah", [
        explain("A slow river song", "This American folk song from the 1800s moves slowly, with wide leaps. Breathe at each rest, and hear every leap before you sing it."),
        notes(V, ["G3", "C4"], hint="The opening leap: low G up to C. Any octave counts."),
        along(V, SHEN_A, bpm=60, title="First half"),
        notes(V, ["G4", "C5", "B4", "A4"], hint="The big leap: G up to high C, then step down."),
        along(V, SHEN_B, bpm=60, title="Second half"),
        quiz("Where should you breathe in this song?", ["In the middle of a long note", "At the rests between phrases", "Never; sing it in one breath"], 1,
             "The rests mark the ends of phrases. Breathe there so each line has full support."),
        along(V, SHEN, bpm=66, title="Shenandoah"),
        SHEN_SONG.take("Shenandoah"),
    ], minutes=SHEN_SONG.minutes(), xp=40, kind="song", arrangement=SHEN_SONG.meta()),
    lesson("voc-5-6", "Medley", [
        explain("Put it together", "Five tunes back to back, one phrase each. Breathe at every rest, and give repeated notes a fresh start."),
        along(V, TWINKLE_A, bpm=72, title="Twinkle Twinkle Little Star"),
        along(V, ODE_A, bpm=76, title="Ode to Joy"),
        quiz("Which of these songs is in 3/4?", ["Ode to Joy", "Twinkle Twinkle Little Star", "Amazing Grace"], 2,
             "Amazing Grace counts 1, 2, 3 in every bar."),
        along(V, AG_A, bpm=72, beats_per_bar=3, title="Amazing Grace"),
        along(V, ALS_A, bpm=72, title="Auld Lang Syne"),
        along(V, SHEN_B, bpm=66, title="Shenandoah"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNIT_6 = unit("voc-6", "Control", "Hold notes steady, shape loud and soft, and warm up well.", [
    lesson("voc-6-1", "Hold it steady", [
        explain("Steady air, steady pitch", "Pitch drifts when the air behind it changes. Keep a low, even breath and watch the note stay centered from start to finish."),
        notes(V, ["G4"], hint="Hold G and keep it centered."),
        explain("Finish before you're empty", "Notes often sag flat as your air runs out. Stop a little before you're empty, then take a fresh low breath."),
        quiz("Your long notes go flat at the end. What helps?", ["End the note sooner and breathe", "Squeeze out the last air", "Sing the end louder"], 0,
             "Pitch sags when you run low on air. Ending a bit early keeps the whole note in tune."),
        along(V, LONG_TONES, bpm=60, title="Long and steady"),
        along(V, "C4:3 r:1 D4:3 r:1 E4:3 r:1 F4:3 r:1 G4:4", bpm=60, title="Climbing long notes"),
    ], minutes=4, xp=20),
    lesson("voc-6-2", "Vibrato basics", [
        explain("What vibrato is", "Vibrato is a gentle, regular wave in pitch, around five to seven times a second. It grows out of a relaxed throat and steady breath, not out of shaking."),
        quiz("Where does healthy vibrato come from?", ["Shaking your jaw", "Pulsing your belly", "A relaxed throat and steady breath"], 2,
             "Vibrato appears when the voice is free and supported. Forcing it from the jaw or belly makes a wobble."),
        explain("Straight tone first", "Learn to hold a straight, steady note before you chase vibrato. When your voice is relaxed and supported, vibrato often appears on its own."),
        notes(V, ["A4"], hint="A straight, steady A. No wave, just a clear line."),
        quiz("What's the best first goal for a new singer?", ["A wide, fast wobble", "A steady, straight tone", "As much vibrato as possible"], 1,
             "A steady tone is the foundation. Vibrato that grows from it sounds natural."),
        along(V, "E4:3 r:1 G4:3 r:1 A4:3 r:1 G4:4", bpm=60, title="Straight and steady"),
    ], minutes=4, xp=20),
    lesson("voc-6-3", "Loud and soft", [
        explain("Dynamics: loud and soft", "Dynamics are how loud or soft you sing. Get louder with more breath energy, not by squeezing your throat. The pitch should stay put."),
        notes(V, ["E4"], hint="Sing E softly, then louder on the same pitch."),
        quiz("As you get louder, what can happen to pitch?", ["It can drift sharp", "It drops an octave", "Nothing ever changes"], 0,
             "Extra push tends to raise the pitch, and very soft notes can sag flat. Watch the note either way."),
        explain("Swell and fade", "A swell grows from soft to louder and back on one breath. Start quietly, grow gently, then fade, all on the same pitch."),
        notes(V, ["G4"], hint="Swell on G: soft, louder, soft. Keep it centered."),
        along(V, "C4:3 r:1 E4:3 r:1 G4:3 r:1 E4:4", bpm=60, title="Swell each note"),
    ], minutes=4, xp=20),
    lesson("voc-6-4", "Your warm-up routine", [
        explain("Five minutes before you sing", "A short warm-up eases your voice in: breathe low, hum, lip trill, then sing a scale. Start in the middle of your range and stay comfortable."),
        notes(V, ["C4", "E4", "G4"], hint=HUM),
        notes(V, ["G4", "E4", "C4"], hint=TRILL),
        along(V, FIVE_UP_DOWN, bpm=66, title="Up five, down five"),
        quiz("Your voice feels tired after practice. What's best?", ["Push through another hour", "Clear your throat hard", "Rest it and sip water"], 2,
             "Rest helps a tired voice recover. If hoarseness lingers for a few weeks, check with a doctor."),
        along(V, SCALE_UP_DOWN, bpm=60, title="Major scale, up and down"),
    ], minutes=5, xp=25),
    lesson("voc-6-5", "Control check", [
        explain("Put it together", "Warm up first. Then hold each note steady, shape it soft and loud, and breathe before you run out."),
        notes(V, ["C4", "E4", "G4"], hint=HUM),
        along(V, LONG_TONES, bpm=60, title="Long and steady"),
        quiz("What is vibrato?", ["A regular wave in pitch", "Singing slightly flat", "A very loud note"], 0,
             "Vibrato is a gentle, even wave around the note, a few times a second."),
        notes(V, ["E4"], hint="Sing E softly, then louder on the same pitch."),
        quiz("To sing louder, what do you add?", ["Throat squeeze", "Breath energy", "Jaw tension"], 1,
             "Breath energy makes a bigger sound without strain."),
        along(V, ODE_A, bpm=72, title="Ode to Joy"),
    ], minutes=5, xp=35, kind="challenge"),
])

COURSE = course("voice", "Singing", "Find your voice and sing in tune", "voice", "music.mic", "mint", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6,
])
