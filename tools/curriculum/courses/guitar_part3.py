"""Guitar, part 3 (units 17–22): the CAGED system, triads up the neck, seventh chords and jazz voicings, the major
scale and two of its modes in position, the major pentatonic with expressive lead, and song form with an arrangement
of your own. courses/guitar.py appends these UNITS after unit 16.

Shapes, rhythms, helpers and shared text come from guitar.py and guitar_part2.py, so identical sentences translate
once; load courses.guitar (as build.py does), never this module on its own.
Up the neck, chord diagrams start at the shape's lowest fretted note (lib.chord sets baseFret) and every shape spans
four frets at most, so its box shows it whole. Every chord a step asks for is one the recognizer hears (major, minor,
7, maj7, m7). Melodies in a position pass first_fret (one finger per fret from there) and fix their strings with
"note@string". Bends and vibrato stay ideas the ear checks: the mic judges pitch, so every scored note is a plain
fretted or open note, and a slide or trill is scored on the notes it lands on.
Melodies are public domain or our own: the opening of Joy to the World (Lowell Mason, 1839) and Down by the Riverside
(printed 1918) come from the Songs courses, where they were checked; every lick, mode study and solo here is new.
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, play_chord, progression, quiz, rhythm, tap, unit
from songbook import Part, song
from courses.guitar import (
    C, D, D7, F_MINI, FIRST_SECOND, FOLK, G, G7, G_MAJ, HALVES, HOME, MAJOR_MINOR, QUARTERS, SHAPES, UP_DOWN,
    Am, Em, shape, tones,
)
from courses.guitar_part2 import (
    BOX_1, C_BAR, D_BAR, G_BAR, LICK_1, SAME_DIFFERENT, TRAVIS_G, eighths, fingered, over, swung,
)
from courses.songs_part2 import JOY_1
from courses.songs_part3 import DBR_C, DBR_LAST, DBR_STUDY, DBR_V, dbr_words


# ---------------------------------------------------------------- helpers

def pinned(melody: str, strings: dict) -> str:
    """Fixes each note of a melody to the string `strings` names for it ("G2": 6), keeping rests and lengths."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        out.append(token if n.lower() == "r" or "@" in n else f"{n}@{strings[n]}:{length or 1}")
    return " ".join(out)


def chain(segments, bpm, title, beats_per_bar=4):
    """One play-along from segments that each sit in their own position: [(melody, {max_fret, first_fret}), …].
    ':L' and ':S' are the long and short halves of a swung beat, as in guitar_part2.swung."""
    notes_, offset = [], 0.0
    for melody, kw in segments:
        part = along(G, melody.replace(":L", ":0.6667").replace(":S", ":0.3333"), bpm=bpm, **kw)
        for n in part["notes"]:
            notes_.append({**n, "b": round(n["b"] + offset, 3), "d": round(n["d"], 3)})
        offset += sum(float(t.partition(":")[2].replace("L", "0.6667").replace("S", "0.3333") or 1) for t in melody.split())
    step = along(G, "r:1", bpm=bpm, beats_per_bar=beats_per_bar, title=title)
    step["notes"] = notes_
    return step


# ================================================================ 17. The CAGED system

# G in five shapes, up the neck in CAGED order from open G: G, E (fret 3), D (5), C (7), A (10), then G again at 12.
G_D5 = chord(G, "G", "xx5787", "xx1243")                          # D shape, root on string 4
G_C7 = chord(G, "G", [-1, 10, 9, 7, 8, 7], [0, 4, 3, 1, 2, 1])    # C shape, root on string 5
G_A10 = chord(G, "G", [-1, 10, 12, 12, 12, 10], [0, 1, 3, 3, 3, 1])  # A shape, root on string 5
D_C2 = chord(G, "D", "x54232", "x43121")                          # C shape for D
C_G5 = chord(G, "C", "xx5558", "xx1114")                          # G shape for C, top four strings
UP_AND_BACK = [(G_MAJ, 1), (G_BAR, 1), (G_D5, 1), (G_C7, 1), (G_A10, 1), (G_C7, 1), (G_D5, 1), (G_BAR, 1)]
AT_FRET_3 = [(G_BAR, 1), (C_BAR, 1), (D_C2, 1), (G_BAR, 1)]
AT_FRET_5 = [(G_D5, 1), (C_G5, 1), (D_BAR, 1), (G_D5, 1)]
HIGH = {"max_fret": 12}

UNIT_17 = unit("gtr-17", "The CAGED system", "Five open shapes become five places to play G, and chords that stay near "
               "your hand.", [
    lesson("gtr-17-1", "One chord, five shapes", [
        explain("CAGED: five shapes", "Every major chord can borrow the shape of open C, A, G, E or D, moved up the neck. "
                "Climbing from any one, the shapes come in that order, C A G E D, and each locks onto the next.", shape(G_MAJ)),
        play_chord(G_MAJ),
        quiz("CAGED is named after…", ["Five frets", "Five open chord shapes", "Five strings"], 1,
             "C, A, G, E and D: the five open shapes that every major chord can borrow, anywhere on the neck."),
        explain("Next up: the E shape", "Climb from open G and the next shape is the E shape: your G barre at fret 3. "
                "Its root on string 6 is the same G as in the open chord.", shape(G_BAR)),
        play_chord(G_BAR),
        listen("Same chord or different?", [tones(G_MAJ), tones(G_BAR)], SAME_DIFFERENT, 0),
        progression([(G_MAJ, 1), (G_BAR, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-17-2", "The D shape", [
        explain("The D shape at fret 5", "Open D moved up five frets is G. Finger 1 holds string 4 at fret 5, where the nut "
                "used to be. Fingers 2, 4 and 3 rebuild the D triangle above it.", shape(G_D5)),
        play_chord(G_D5),
        over([(G_D5, "G3@4:1 D4@3:1 G4@2:1 B4@1:1"), (G_D5, "G4@2:1 D4@3:1 G3@4:2")], bpm=60,
             title="The D shape, string by string", **HIGH),
        quiz("Where is the D shape's root?", ["String 1, under finger 3", "String 3, under finger 2", "String 4, under finger 1"], 2,
             "Open D's root is open string 4. Moved up, finger 1 holds it: G at fret 5. String 2, fret 8 is a G too."),
        explain("A shared note", "The E shape at fret 3 and the D shape at fret 5 share one note: G on string 4, fret 5. "
                "Keep your eyes on it as you move between them."),
        progression([(G_BAR, 1), (G_D5, 1)] * 2, HALVES, bpm=60),
        progression([(G_MAJ, 1), (G_BAR, 1), (G_D5, 1), (G_BAR, 1)], HALVES, bpm=63),
    ], minutes=5, xp=25),
    lesson("gtr-17-3", "The C shape", [
        explain("The C shape at fret 7", "Open C moved up seven frets is G. Finger 1 lies across strings 3, 2 and 1 at fret 7, "
                "finger 2 takes string 2 at fret 8, and fingers 3 and 4 stretch to strings 4 and 5.", shape(G_C7)),
        play_chord(G_C7),
        over([(G_C7, "G3@5:1 B3@4:1 D4@3:1 G4@2:1"), (G_C7, "B4@1:1 G4@2:1 D4@3:1 G3@5:1")], bpm=60,
             title="The C shape, string by string", **HIGH),
        quiz("Like open C, the C shape's root is on…", ["String 5", "String 6", "String 4"], 0,
             "Open C's root is string 5, fret 3. Here your little finger holds it: G at fret 10."),
        explain("Any chord, same shape", "Slide the C shape down to fret 2 and it's D, with its root on string 5, fret 5. "
                "The name always follows the root.", shape(D_C2)),
        play_chord(D_C2),
        progression([(G_D5, 1), (G_C7, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-17-4", "The A shape, and around again", [
        explain("The A shape at fret 10", "Barre strings 5 to 1 at fret 10 and lay finger 3 across strings 4, 3 and 2 at "
                "fret 12. It's your A-shape barre, and it's G again.", shape(G_A10)),
        play_chord(G_A10),
        explain("Fret 12 starts the cycle again", "Past the A shape, the G shape comes back at fret 12: open G, one octave "
                "higher. From there the five shapes repeat in the same order."),
        quiz("Going up the neck, which shape comes after A?", ["C", "G", "E"], 1,
             "The order loops: C, A, G, E, D, then C again. After A comes G."),
        listen("Which G is higher?", [tones(G_BAR), tones(G_A10)], FIRST_SECOND, 1),
        progression([(G_C7, 1), (G_A10, 1)] * 2, HALVES, bpm=60),
        progression(UP_AND_BACK, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-17-5", "Chords near your hand", [
        explain("Stay in one spot", "With CAGED you rarely have to jump. Around fret 5, G is the D shape, C is the G shape "
                "and D is the A shape. Three chords, one spot.", shape(C_G5)),
        play_chord(C_G5),
        quiz("Which shape plays C right beside the D-shape G?", ["The E shape", "The C shape", "The G shape"], 2,
             "C's G shape uses frets 5 and 8, right where your hand already is."),
        progression([(G_D5, 1), (C_G5, 1)] * 2, HALVES, bpm=60),
        play_chord(D_BAR),
        progression(AT_FRET_5, HALVES, bpm=63),
        explain("Or stay at fret 3", "The same idea works lower: G as the E shape at fret 3, C as the A shape at fret 3, "
                "and D as the C shape at fret 2.", shape(C_BAR)),
        progression(AT_FRET_3, HALVES, bpm=63),
    ], minutes=5, xp=25),
    lesson("gtr-17-6", "CAGED challenge", [
        explain("Five shapes, one neck", "No new ideas: G in all five shapes, and G, C and D near fret 3 and fret 5. "
                "Name each shape as you land it."),
        quiz("G with the D shape sits at…", ["Fret 3", "Fret 5", "Fret 7"], 1),
        play_chord(G_C7),
        listen("Same chord or different?", [tones(G_C7), tones(G_A10)], SAME_DIFFERENT, 0),
        progression(UP_AND_BACK, HALVES, bpm=66),
        progression(AT_FRET_3, QUARTERS, bpm=66),
        progression(AT_FRET_5, FOLK, bpm=66),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 18. Triads up the neck

# Triads on strings 3, 2 and 1. A major triad has three shapes, one per inversion: root at the bottom (frets f, f, f-2),
# the third at the bottom (f, f-1, f-1) and the fifth at the bottom (f, f+1, f). Minor lowers the third one fret.
C_TRI = chord(G, "C", "xxx553", "xxx341")                         # C E G, root at the bottom
C_TRI_1 = chord(G, "C", "xxx988", "xxx211")                       # E G C
C_TRI_2 = chord(G, "C", "xxx010", "xxx010")                       # G C E, the top of open C
G_TRI_1 = chord(G, "G", "xxx433", "xxx211")                       # B D G
G_TRI_2 = chord(G, "G", "xxx787", "xxx121")                       # D G B
D_TRI = chord(G, "D", "xxx775", "xxx341")                         # D F# A
D_TRI_2 = chord(G, "D", "xxx232", "xxx132")                       # A D F#, the top of open D
Am_TRI = chord(G, "Am", "xxx210", "xxx210")                       # A C E, the top of open A minor
Am_TRI_1 = chord(G, "Am", "xxx555", "xxx111")                     # C E A
Em_TRI = chord(G, "Em", "xxx987", "xxx321")                       # E G B
Em_TRI_2 = chord(G, "Em", "xxx453", "xxx231")                     # B E G
LOW_FOUR = [(G_TRI_1, 1), (Em_TRI_2, 1), (C_TRI, 1), (D_TRI_2, 1)]      # frets 2 to 5
HIGH_FOUR = [(G_TRI_2, 1), (Em_TRI, 1), (C_TRI_1, 1), (D_TRI, 1)]      # frets 5 to 9
LOW_ARPS = [(G_TRI_1, "B3@3 D4@2 G4@1 D4@2"), (Em_TRI_2, "B3@3 E4@2 G4@1 E4@2"),
            (C_TRI, "C4@3 E4@2 G4@1 E4@2"), (D_TRI_2, "A3@3 D4@2 F#4@1 D4@2")]
HIGH_ARPS = [(G_TRI_2, "D4@3 G4@2 B4@1 G4@2"), (Em_TRI, "E4@3 G4@2 B4@1 G4@2"),
             (C_TRI_1, "E4@3 G4@2 C5@1 G4@2"), (D_TRI, "D4@3 F#4@2 A4@1 F#4@2")]
TOP = {"max_fret": 10}


def quarters(arps):
    return [(spec, " ".join(f"{n}:1" for n in line.split())) for spec, line in arps]


def doubled_eighths(arps):
    return [(spec, eighths(f"{line} {line}")) for spec, line in arps]


UNIT_18 = unit("gtr-18", "Triads up the neck", "Three-note chords on the top strings: major and minor, every inversion, "
               "and progressions that barely move.", [
    lesson("gtr-18-1", "Triads on the top strings", [
        explain("Three notes make a chord", "A triad is the smallest full chord: a root, a third and a fifth. On strings 3, 2 "
                "and 1, triads ring clear and bright, and they work anywhere on the neck.", shape(C_TRI)),
        play_chord(C_TRI),
        over([(C_TRI, "C4@3:1 E4@2:1 G4@1:2")] * 2, bpm=60, title="C, root at the bottom", **TOP),
        quiz("Which notes make a C major triad?", ["C, E and G", "C, D and E", "C, F and A"], 0,
             "Root, third, fifth: from C, skip a letter to E, then skip another to G."),
        explain("Same notes, new order", "Move the lowest note to the top and you get an inversion. With E at the bottom, C "
                "sits at frets 9, 8 and 8. With G at the bottom, it's the top of your open C.", shape(C_TRI_1)),
        play_chord(C_TRI_1),
        play_chord(C_TRI_2),
        listen("Same chord or different?", [tones(C_TRI), tones(C_TRI_1)], SAME_DIFFERENT, 0),
    ], minutes=5, xp=25),
    lesson("gtr-18-2", "Inversions of G and D", [
        explain("Three shapes for every chord", "Every major triad on these strings uses one of three shapes, one per "
                "inversion. Learn them on G and D and you can find any major chord.", shape(G_TRI_1)),
        play_chord(G_TRI_1),
        quiz("G at frets 4, 3 and 3 has the same shape as…", ["C at frets 5, 5 and 3", "C at frets 9, 8 and 8", "No other chord"], 1,
             "Both put the third at the bottom: one fret up on string 3, the other two level. Same shape, five frets apart."),
        play_chord(G_TRI_2),
        explain("D, twice", "D at frets 7, 7 and 5 has the root-position shape of your C at fret 5. Lower down, frets 2, 3 "
                "and 2 are the top of your open D.", shape(D_TRI)),
        play_chord(D_TRI),
        progression([(G_TRI_2, 1), (D_TRI, 1)] * 2, HALVES, bpm=60),
        progression([(G_TRI_1, 1), (D_TRI_2, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-18-3", "Minor triads", [
        explain("Lower the third", "A minor triad is a major triad with its third one fret lower. On these strings, A minor "
                "at frets 2, 1 and 0 is the top of your open A minor.", shape(Am_TRI)),
        play_chord(Am_TRI),
        listen("Major or minor?", [tones(Am_TRI)], MAJOR_MINOR, 1),
        explain("A minor at fret 5", "Barre fret 5 across strings 3, 2 and 1 and you have A minor with C at the bottom. "
                "One finger, three notes.", shape(Am_TRI_1)),
        play_chord(Am_TRI_1),
        explain("E minor beside it", "E minor at frets 4, 5 and 3 puts B at the bottom. It sits right beside A minor at fret 5, "
                "so the change is tiny.", shape(Em_TRI_2)),
        play_chord(Em_TRI_2),
        progression([(Am_TRI_1, 1), (Em_TRI_2, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-18-4", "Triads through a progression", [
        explain("Move to the nearest shape", "Pick the inversion closest to your hand and a progression barely moves. G, E minor, "
                "C and D all live between frets 2 and 5.", shape(G_TRI_1)),
        progression([(G_TRI_1, 1), (Em_TRI_2, 1)] * 2, HALVES, bpm=60),
        quiz("From G at frets 4, 3, 3 to E minor at 4, 5, 3, which notes stay?", ["Only D", "None of them", "B and G"], 2,
             "B on string 3 and G on string 1 stay put. Only string 2 moves, from D up to E."),
        progression(LOW_FOUR, HALVES, bpm=60),
        explain("Higher up the neck", "The same four chords sit higher too: G at frets 7, 8 and 7, E minor at 9, 8 and 7, "
                "C at 9, 8 and 8, and D at 7, 7 and 5.", shape(Em_TRI)),
        play_chord(Em_TRI),
        progression(HIGH_FOUR, HALVES, bpm=60),
        progression(LOW_FOUR, QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-18-5", "Triad arpeggios", [
        explain("Pick them apart", "Play a triad's notes one at a time and you have an arpeggio. Through a progression, "
                "the notes make a melody of their own.", shape(G_TRI_1)),
        over(quarters(LOW_ARPS), bpm=60, title="Arpeggios, frets 2 to 5", max_fret=5),
        quiz("What is an arpeggio?", ["A chord played one note at a time", "A chord strummed twice", "A scale played fast"], 0),
        over(doubled_eighths(LOW_ARPS), bpm=60, title="Arpeggios in eighths", max_fret=5),
        explain("Listen to the top", "The top notes here run G, G, G, F sharp: almost still while the chords change under "
                "them. A note that two chords share is a common tone, and it's why triads sound so smooth."),
        listen("Did the top note go up or down?", [["G4"], ["F#4"]], UP_DOWN, 1),
        over(quarters(HIGH_ARPS), bpm=60, title="Arpeggios, frets 5 to 9", **TOP),
    ], minutes=5, xp=25),
    lesson("gtr-18-6", "Triad challenge", [
        explain("Small shapes, whole neck", "No new ideas: major and minor triads, their inversions, G, E minor, C and D in two "
                "places, and the arpeggios. Keep every move small."),
        quiz("A minor triad is a major triad with…", ["Its root one fret higher", "Its third one fret lower", "An extra note on top"], 1),
        listen("Major or minor?", [tones(Em_TRI)], MAJOR_MINOR, 1),
        play_chord(C_TRI_1),
        progression(LOW_FOUR, FOLK, bpm=66),
        progression(HIGH_FOUR, QUARTERS, bpm=66),
        over(doubled_eighths(LOW_ARPS), bpm=72, title="Arpeggios in eighths", max_fret=5),
        over(quarters(HIGH_ARPS), bpm=72, title="Arpeggios, frets 5 to 9", **TOP),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 19. Seventh chords and jazz voicings

Cmaj7 = chord(G, "Cmaj7", "x32000", "x32000")      # C with finger 1 lifted
Fmaj7 = chord(G, "Fmaj7", "xx3210", "xx3210")      # the mini F with string 1 open
Am7 = chord(G, "Am7", "x02010", "x02010")          # A minor with finger 3 lifted
Dm7 = chord(G, "Dm7", "xx0211", "xx0211")
Em7 = chord(G, "Em7", "020000", "020000")
Cmaj7_5 = chord(G, "Cmaj7", "x35453", "x13241")    # root on string 5
Dm7_5 = chord(G, "Dm7", "x57565", "x13121")        # the A minor barre shape, little finger lifted
D7_5 = chord(G, "D7", "x57575", "x13141")          # the A7 barre shape
G7_3 = chord(G, "G7", "353433", "131211")          # the E7 barre shape, root on string 6
Am7_5 = chord(G, "Am7", "575555", "131111")        # the E minor 7 barre shape
Gmaj7 = chord(G, "Gmaj7", "3x443x", "2x341x")      # root on string 6, string 5 muted
CHARLESTON = [0, round(1 + 2 / 3, 3)]              # one, and the swung and of two
TWO_FIVE_ONE_C = [(Dm7_5, 1), (G7_3, 1), (Cmaj7_5, 2)]
TWO_FIVE_ONE_G = [(Am7_5, 1), (D7_5, 1), (Gmaj7, 2)]

UNIT_19 = unit("gtr-19", "Seventh chords and jazz voicings", "Major, minor and dominant sevenths, open and barred, the "
               "ii–V–I, and swing comping.", [
    lesson("gtr-19-1", "Major seventh chords", [
        explain("Add the seventh", "A major seventh chord adds the note one fret below the root's octave. It turns a plain "
                "major chord soft and dreamy. Open Cmaj7 is C with finger 1 lifted.", shape(Cmaj7)),
        play_chord(Cmaj7),
        listen("Which chord has the seventh?", [tones(C), tones(Cmaj7)], FIRST_SECOND, 1),
        quiz("Cmaj7 is C plus which note?", ["B flat", "D", "B"], 2,
             "The major seventh sits one fret below the root's octave: B, just under C."),
        explain("Fmaj7: free the top string", "Play the mini F, but let finger 1 press string 2 only. Open string 1, E, "
                "is the major seventh of F.", shape(Fmaj7)),
        play_chord(Fmaj7),
        progression([(Cmaj7, 1), (Fmaj7, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-19-2", "Minor seventh chords", [
        explain("Mellow minor", "A minor seventh chord adds the note two frets below the root's octave. It sounds mellow, "
                "between dark and bright. Am7 is A minor with finger 3 lifted.", shape(Am7)),
        play_chord(Am7),
        listen("Which chord has the seventh?", [tones(Am), tones(Am7)], FIRST_SECOND, 1),
        explain("Dm7 and Em7", "Dm7: finger 2 on string 3, fret 2, and finger 1 flat across strings 2 and 1 at fret 1. "
                "Em7: just finger 2 on string 5, fret 2.", shape(Dm7)),
        play_chord(Dm7),
        play_chord(Em7),
        quiz("Am7 is A minor plus which note?", ["G", "G sharp", "F"], 0,
             "The minor seventh sits two frets below the root's octave: G, two frets under A."),
        progression([(Cmaj7, 1), (Am7, 1), (Dm7, 1), (G7, 1)], QUARTERS, bpm=63),
    ], minutes=5, xp=25),
    lesson("gtr-19-3", "Sevenths with the root on string 5", [
        explain("Cmaj7 at fret 3", "Finger 1 holds string 5 at fret 3 and lies across to string 1. Finger 3 takes string 4, "
                "finger 2 string 3 and finger 4 string 2.", shape(Cmaj7_5)),
        play_chord(Cmaj7_5),
        explain("Dm7 and D7 at fret 5", "Dm7 is your A minor barre with the little finger lifted. D7 is the A-shape barre "
                "with fingers 3 and 4 on strings 4 and 2. Both are named after string 5.", shape(Dm7_5)),
        play_chord(Dm7_5),
        play_chord(D7_5),
        listen("Which chord has the seventh?", [tones(D_BAR), tones(D7_5)], FIRST_SECOND, 1),
        quiz("Dm7 at fret 5. Where is its root?", ["String 4, fret 7", "String 5, fret 5", "String 1, fret 5"], 1,
             "Like every A-shape chord, it's named after its note on string 5."),
        progression([(Cmaj7_5, 1), (Dm7_5, 1)] * 2, HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-19-4", "The ii–V–I", [
        explain("Two, five, one", "Jazz's favorite move: the chord on the second note of the key, then the fifth, then home. "
                "In C that's Dm7, G7 and Cmaj7."),
        explain("G7 as a barre", "Play the E7 shape as a barre at fret 3: finger 1 across all six strings, finger 3 on string 5 "
                "and finger 2 on string 3. Its root is on string 6.", shape(G7_3)),
        play_chord(G7_3),
        progression(TWO_FIVE_ONE_C, HALVES, bpm=60),
        quiz("In the key of C, which chord is the ii?", ["G7", "Em7", "Dm7"], 2,
             "Count up from C: C is one, D is two. The seventh chord built on D is D minor seven."),
        listen("Does this end at home?", [tones(Dm7_5), tones(G7_3), tones(Cmaj7_5)], HOME, 0),
        explain("Short and crisp", "Jazz players often let each chord ring for just a moment. Squeeze as you strum, ease off "
                "right after, and the chords start to swing."),
        progression(TWO_FIVE_ONE_C, QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-19-5", "Swing comping", [
        explain("The Charleston", "Swing guitarists comp: short chords that answer the band. The Charleston rhythm hits beat "
                "one and the swung and of two, then leaves space.", rhythm(CHARLESTON)),
        tap(CHARLESTON, bpm=80, bars=2),
        explain("ii–V–I in G", "In G, the two, five, one is Am7, D7 and Gmaj7. Am7 is the E minor seven barre at fret 5; "
                "Gmaj7 skips string 5, with its root on string 6, fret 3.", shape(Am7_5)),
        play_chord(Am7_5),
        play_chord(Gmaj7),
        progression(TWO_FIVE_ONE_G, HALVES, bpm=66),
        progression(TWO_FIVE_ONE_G, CHARLESTON, bpm=72),
        progression(TWO_FIVE_ONE_C, CHARLESTON, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-19-6", "Jazz chord challenge", [
        explain("Sevenths, swung", "No new ideas: major, minor and dominant sevenths, open and barred, and the ii–V–I in C "
                "and G. Keep the chords short and the swing steady."),
        quiz("Which seventh sits one fret below the root's octave?", ["The minor seventh", "The major seventh"], 1),
        listen("Which chord has the seventh?", [tones(Fmaj7), tones(F_MINI)], FIRST_SECOND, 0),
        progression([(Cmaj7, 1), (Am7, 1), (Dm7, 1), (G7, 1)], QUARTERS, bpm=72),
        progression(TWO_FIVE_ONE_C, CHARLESTON, bpm=80),
        progression(TWO_FIVE_ONE_G, CHARLESTON, bpm=80),
        progression([(Cmaj7_5, 1), (Am7_5, 1), (Dm7_5, 1), (G7_3, 1)], QUARTERS, bpm=76),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 20. The major scale in position

# G major in second position: finger 1 at fret 2, one finger per fret up to fret 5. Each note's string.
POS_2 = {"max_fret": 5, "first_fret": 2}
IN_POS_2 = {"G2": 6, "A2": 6, "B2": 5, "C3": 5, "D3": 5, "E3": 4, "F#3": 4, "G3": 4,
            "A3": 3, "B3": 3, "C4": 3, "D4": 2, "E4": 2, "F#4": 1, "G4": 1, "A4": 1}
LOW_DOTS = [(6, 3, 2), (6, 5, 4), (5, 2, 1), (5, 3, 2), (5, 5, 4), (4, 2, 1), (4, 4, 3), (4, 5, 4)]
HIGH_DOTS = [(3, 2, 1), (3, 4, 3), (3, 5, 4), (2, 3, 2), (2, 5, 4), (1, 2, 1), (1, 3, 2)]
SCALE_UP = "G2 A2 B2 C3 D3 E3 F#3 G3 A3 B3 C4 D4 E4 F#4 G4".split()
OCTAVE = pinned(" ".join(SCALE_UP[:8] + SCALE_UP[6::-1][:-1]) + " G2:2", IN_POS_2)          # G2 up to G3 and back
TOP_OCTAVE = pinned(" ".join(SCALE_UP[7:] + SCALE_UP[13:7:-1]) + " G3:2", IN_POS_2)       # G3 up to G4 and back
TWO_OCTAVES = pinned(" ".join(SCALE_UP + SCALE_UP[13:0:-1]) + " G2:4", IN_POS_2)
THIRDS = pinned("G2 B2 A2 C3 B2 D3 C3 E3 D3 F#3 E3 G3 F#3 A3 G3:2", IN_POS_2)
JOY = pinned(JOY_1, IN_POS_2)                                                               # 2/4
DORIAN_SCALE = [("A2", 6), ("B2", 5), ("C3", 5), ("D3", 5), ("E3", 4), ("F#3", 4), ("G3", 4), ("A3", 3)]
MIXO_SCALE = [("D3", 5), ("E3", 4), ("F#3", 4), ("G3", 4), ("A3", 3), ("B3", 3), ("C4", 3), ("D4", 2)]
# Our own melodies. A Dorian leans on F sharp, its bright sixth; D Mixolydian on C, its lowered seventh.
DORIAN = pinned("A3 C4 E4 D4 C4:0.5 B3:0.5 A3 F#3 G3 A3 B3 C4 D4 E4 F#4 E4 D4 C4 B3:0.5 A3:0.5 G3 F#3 A3:4", IN_POS_2)
MIXO = pinned("D3 F#3 A3 C4 B3:0.5 A3:0.5 G3 A3:2 D4 C4 A3 F#3 G3:0.5 F#3:0.5 E3 D3:2", IN_POS_2)

UNIT_20 = unit("gtr-20", "The major scale in position", "G major in two octaves at fret 2, scale degrees and chords, and "
               "the Dorian and Mixolydian modes.", [
    lesson("gtr-20-1", "The major scale shape", [
        explain("Whole steps and half steps", "A half step is one fret, a whole step two. Every major scale climbs whole, "
                "whole, half, whole, whole, whole, half. That pattern gives major its sound."),
        explain("G major at fret 2", "Put finger 1 at fret 2 and give each finger its own fret, up to fret 5. From G on "
                "string 6, fret 3, the scale climbs across strings 6, 5 and 4.", fretboard(G, LOW_DOTS, frets=4, start=2)),
        notes(G, [("G2", 6), ("A2", 6), ("B2", 5), ("C3", 5)], hint="String 6: frets 3 and 5, fingers 2 and 4. String 5: "
              "frets 2 and 3, fingers 1 and 2.", **POS_2),
        notes(G, [("D3", 5), ("E3", 4), ("F#3", 4), ("G3", 4)], hint="String 5, fret 5, then string 4: frets 2, 4 and 5. "
              "Home on G.", **POS_2),
        quiz("Where do the half steps fall in a major scale?", ["Between notes 3 and 4, and 7 and 8", "Between every pair",
                                                              "Between notes 1 and 2"], 0,
             "Whole, whole, half: the first half step is from 3 to 4. Whole, whole, whole, half: the second is from 7 to 8."),
        listen("Does this end at home?", [["D3"], ["E3"], ["F#3"]], HOME, 1),
        along(G, OCTAVE, bpm=60, title="One octave, up and down", **POS_2),
    ], minutes=5, xp=25),
    lesson("gtr-20-2", "Two octaves in position", [
        explain("The second octave", "The same position carries on: A, B and C on string 3, D and E on string 2, F sharp and "
                "G on string 1. Your hand never moves.", fretboard(G, HIGH_DOTS, frets=4, start=2)),
        notes(G, [("A3", 3), ("B3", 3), ("C4", 3), ("D4", 2), ("E4", 2), ("F#4", 1), ("G4", 1)],
              hint="String 3: frets 2, 4, 5. String 2: frets 3, 5. String 1: frets 2, 3.", **POS_2),
        along(G, TOP_OCTAVE, bpm=60, title="The top octave", **POS_2),
        quiz("In this position, which finger plays fret 5?", ["Finger 3", "Finger 4", "Finger 1"], 1,
             "Finger 1 sits at fret 2, so fret 5 belongs to finger 4, your little finger."),
        along(G, TWO_OCTAVES, bpm=60, title="Two octaves, G to G", **POS_2),
        explain("A carol built on the scale", "Joy to the World, arranged by Lowell Mason in 1839, opens with the G major "
                "scale straight down from the top. You know every note already."),
        along(G, JOY, bpm=63, beats_per_bar=2, title="Joy to the World, in position", **POS_2),
    ], minutes=5, xp=25),
    lesson("gtr-20-3", "Scale degrees and chords", [
        explain("Number the notes", "Number the scale from G: G is 1, A is 2, and so on up to F sharp, 7. Musicians use these "
                "numbers to talk about melodies and chords in any key."),
        quiz("In G major, which note is 5?", ["C", "E", "D"], 2, "Count up from G: G 1, A 2, B 3, C 4, D 5."),
        explain("A chord on every note", "Stack every other scale note on each degree and you get the key's chords. Chords on "
                "1, 4 and 5 are major; on 2, 3 and 6 they're minor. In G: G, C and D, then A minor, B minor and E minor."),
        quiz("In G major, which chord is built on 6?", ["E minor", "E", "C"], 0,
             "The sixth note is E, and chords on 2, 3 and 6 are minor. Stack E, G and B: E minor."),
        progression([(G_MAJ, 1), (Em, 1), (C, 1), (D, 1)], QUARTERS, bpm=66),
        listen("Does this end at home?", [["G3"], ["B3"], ["D4"], ["G4"]], HOME, 0),
        along(G, THIRDS, bpm=60, title="The scale in thirds", **POS_2),
    ], minutes=5, xp=25),
    lesson("gtr-20-4", "A Dorian", [
        explain("Same notes, new home", "Play G major's notes but treat A as home, and the scale turns minor. This sound is "
                "A Dorian, a mode of G major: same position, new starting note."),
        notes(G, DORIAN_SCALE, hint="Start on A, string 6, fret 5, with finger 4, and climb the same frets to A on string 3.",
              **POS_2),
        quiz("Which note makes A Dorian brighter than plain A minor?", ["C", "F sharp", "G"], 1,
             "Plain A minor has F. Dorian keeps G major's F sharp: a bright spot in a minor scale."),
        listen("Major or minor?", [["A3", "C4", "E4"]], MAJOR_MINOR, 1),
        along(G, DORIAN, bpm=60, title="A Dorian melody", **POS_2),
        along(G, DORIAN, bpm=69, title="A Dorian melody, flowing", **POS_2),
    ], minutes=5, xp=25),
    lesson("gtr-20-5", "D Mixolydian", [
        explain("Start on D", "Now treat D as home. G major's notes from D to D make D Mixolydian: a major scale with its "
                "seventh one fret lower. It's all over folk, rock and fiddle tunes."),
        notes(G, MIXO_SCALE, hint="From D on string 5, fret 5, up the same position to D on string 2, fret 3.", **POS_2),
        quiz("D major has C sharp. D Mixolydian has…", ["C sharp", "B flat", "C"], 2,
             "Mixolydian lowers the seventh by one fret, so G major's C becomes its flavor note."),
        listen("Which chord has the seventh?", [tones(D), tones(D7)], FIRST_SECOND, 1),
        along(G, MIXO, bpm=63, title="D Mixolydian melody", **POS_2),
        explain("Mode by mode", "Any note of the major scale can be home. From G it's major, from A Dorian, from D "
                "Mixolydian, from E plain minor. Same frets, different moods."),
        along(G, f"{MIXO} {MIXO}", bpm=72, title="D Mixolydian, twice", **POS_2),
    ], minutes=5, xp=25),
    lesson("gtr-20-6", "Scale challenge", [
        explain("One position, three moods", "No new ideas: G major in two octaves, the scale in thirds, A Dorian and "
                "D Mixolydian. Keep one finger per fret."),
        quiz("Whole, whole, half, whole, whole, whole, half spells…", ["The major scale", "The minor pentatonic", "The blues"], 0),
        along(G, TWO_OCTAVES, bpm=72, title="Two octaves, G to G", **POS_2),
        quiz("Which mode starts on the second note of G major?", ["D Mixolydian", "A Dorian", "E minor"], 1),
        along(G, THIRDS, bpm=69, title="The scale in thirds", **POS_2),
        along(G, JOY, bpm=72, beats_per_bar=2, title="Joy to the World, in position", **POS_2),
        along(G, DORIAN, bpm=72, title="A Dorian melody", **POS_2),
        along(G, MIXO, bpm=76, title="D Mixolydian melody", **POS_2),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 21. Major pentatonic and expressive lead

# A major pentatonic: the minor box 1 slid down to fret 2 (it is also F sharp minor pentatonic).
MAJ = {"max_fret": 6, "first_fret": 2}
MAJ_DOTS = [(6, 2, 1), (6, 5, 4), (5, 2, 1), (5, 4, 3), (4, 2, 1), (4, 4, 3),
            (3, 2, 1), (3, 4, 3), (2, 2, 1), (2, 5, 4), (1, 2, 1), (1, 5, 4)]
MAJ_UP = "A2@6 B2@5 C#3@5 E3@4 F#3@4 A3@3 B3@3 C#4@2 E4@2 F#4@1 A4@1".split()
MAJ_BOX = " ".join(f"{n}:1" for n in MAJ_UP + MAJ_UP[9:0:-1]) + " A2@6:4"
SWEET = "A3@3:0.5 B3@3:0.5 C#4@2 E4@2 C#4@2:0.5 B3@3:0.5 A3@3:4"
# Our own licks. Lick 1 hammers E to F sharp and A to B; lick 2 slides finger 3 from B up to C sharp on string 3.
COUNTRY_1 = "E3@4:0.5 F#3@4:0.5 A3@3:0.5 B3@3:0.5 C#4@2 A3@3"
COUNTRY_2 = "B3@3:0.5 C#4@3:1.5 B3@3:0.5 A3@3:0.5 F#3@4"
COUNTRY = f"{COUNTRY_1} {COUNTRY_2} {COUNTRY_1} A3@3:4"
SLIDE_FINGERS = {len(COUNTRY_1.split()) + i: 3 for i in range(3)}     # B, C sharp and B under finger 3
TRILL_EIGHTHS = " ".join(["A3@3:0.5 B3@3:0.5"] * 4) + " A3@3:4"
TRILL = " ".join(["A3@3:0.25 B3@3:0.25"] * 4) + " A3@3:2 " + " ".join(["E3@4:0.25 F#3@4:0.25"] * 4) + " E3@4:2"
SLIDE_INTO = "C#4@2 A3@3 B3@3:0.5 A3@3:0.5 F#3@4 E3@4 F#3@4 A3@3:2"
# Sour answered by sweet: a swung minor lick in box 1, then a swung major answer at fret 2. Both end on A.
SWEET_SWUNG = "C#4@2:L E4@2:S C#4@2:L B3@3:S A3@3:1 F#3@4:1 A3@3:4"
SPACE = "A3@3:0.5 B3@3:0.5 C#4@2 r:2 C#4@2:0.5 E4@2:0.5 F#4@1 r:2 E4@2 C#4@2 B3@3 A3@3 A3@3:4"
ANSWER = "C#4@2 B3@3:0.5 A3@3:0.5 F#3@4:2"
VARIED = f"{ANSWER} {ANSWER} C#4@2 E4@2 F#4@1 E4@2 C#4@2:0.5 B3@3:0.5 A3@3:3"

UNIT_21 = unit("gtr-21", "Major pentatonic and expressive lead", "The major pentatonic, country hammer-ons and slides, "
               "trills, phrasing, and sweet and sour over the blues.", [
    lesson("gtr-21-1", "The major pentatonic", [
        explain("Slide the box down", "Move your minor pentatonic box from fret 5 down to fret 2 and treat A as home: it turns "
                "sweet and major. That's A major pentatonic: A, B, C sharp, E and F sharp.", fretboard(G, MAJ_DOTS, frets=4, start=2)),
        notes(G, [("A2", 6), ("B2", 5), ("C#3", 5), ("E3", 4), ("F#3", 4), ("A3", 3)],
              hint="From A on string 6, fret 5, then frets 2 and 4 on strings 5 and 4, and A at fret 2 on string 3.", **MAJ),
        quiz("Which notes are in A major pentatonic?", ["A, C, D, E, G", "A, B, C, D, E", "A, B, C sharp, E, F sharp"], 2,
             "Five notes of the A major scale, its two half steps left out. The minor box at fret 5 holds A, C, D, E and G."),
        along(G, MAJ_BOX, bpm=60, title="A major pentatonic, up and down", **MAJ),
        explain("One box, two keys", "This box at fret 2 is also F sharp minor pentatonic, from its F sharp. The note you "
                "treat as home decides which one you're playing."),
        along(G, f"{SWEET} {SWEET}", bpm=63, title="A sweet phrase", **MAJ),
    ], minutes=5, xp=25),
    lesson("gtr-21-2", "Country hammer-ons and slides", [
        explain("Hammer into the major", "Country players love hammer-ons inside this box: E to F sharp on string 4, A to B on "
                "string 3. Pick the first note, then hammer the second.",
                fretboard(G, [(4, 2, 1), (4, 4, 3), (3, 2, 1), (3, 4, 3)], frets=4, start=2)),
        notes(G, [("E3", 4), ("F#3", 4)], hint="String 4: pick fret 2, then hammer finger 3 onto fret 4.", **MAJ),
        along(G, f"{COUNTRY_1} {COUNTRY_1}", bpm=60, title="Lick 1: two hammer-ons", **MAJ),
        explain("Slide up to C sharp", "Now slide finger 3 on string 3 from fret 4 to fret 6, B up to C sharp, then glide "
                "back into the box.", fretboard(G, [(3, 4, 3), (3, 6, 3)], frets=5, start=2)),
        fingered(notes(G, [("B3", 3), ("C#4", 3)], hint="Finger 3 on string 3, fret 4. Pick, then slide to fret 6 without "
                       "lifting.", **MAJ), {0: 3, 1: 3}),
        quiz("During a slide, what keeps the note sounding?", ["Picking again at the end", "Steady pressure as you glide",
                                                               "A lighter touch"], 1,
             "Ease off and the note dies. Keep the same pressure all the way to the new fret."),
        fingered(along(G, f"{COUNTRY_2} A3@3:4", bpm=60, title="Lick 2: the slide", **MAJ), {0: 3, 1: 3, 2: 3}),
        fingered(along(G, COUNTRY, bpm=66, title="Both licks", **MAJ), SLIDE_FINGERS),
    ], minutes=5, xp=25),
    lesson("gtr-21-3", "Trills and slides into notes", [
        explain("A trill", "A trill flutters between two notes: one pick, then hammer-on, pull-off, over and over. Keep it "
                "even before you make it fast."),
        notes(G, [("A3", 3), ("B3", 3), ("A3", 3), ("B3", 3)], hint="String 3: frets 2 and 4. Pick once, then hammer and "
              "pull with finger 3.", **MAJ),
        along(G, TRILL_EIGHTHS, bpm=60, title="A slow trill", **MAJ),
        along(G, TRILL, bpm=60, title="Trills on strings 3 and 4", **MAJ),
        explain("Slide into a note", "Start one fret below the note you want and slide up into it as you pick. The target is "
                "what counts: land it right on the beat."),
        quiz("When you slide into a note, which one lands on the beat?", ["The target", "The fret below", "Both at once"], 0,
             "The slide starts just before the beat, so the note you're aiming for arrives right on it."),
        along(G, f"{SLIDE_INTO} {SLIDE_INTO}", bpm=63, title="Slide into each phrase", **MAJ),
    ], minutes=5, xp=25),
    lesson("gtr-21-4", "Sweet and sour", [
        explain("Two boxes, one blues", "Over a blues in A, both boxes work. Major pentatonic at fret 2 sounds sweet; minor "
                "at fret 5 sounds tough. Good players move between them.", fretboard(G, MAJ_DOTS, frets=4, start=2)),
        swung(SWEET_SWUNG, bpm=63, title="Sweet, at fret 2", **MAJ),
        swung(LICK_1, bpm=63, title="Sour, at fret 5", **BOX_1),
        quiz("Which box sounds sweeter over A7?", ["A major, at fret 2", "A minor, at fret 5"], 0,
             "The major pentatonic holds C sharp, the third of A7. The minor box's C rubs against it, and that rub is the blues."),
        explain("Sour, then sweet", "Ask a tough question at fret 5, then answer it sweetly at fret 2. Shift your hand on the "
                "long note, and land both phrases on A."),
        chain([(LICK_1, BOX_1), (SWEET_SWUNG, MAJ)], bpm=63, title="Question and answer"),
        chain([(LICK_1, BOX_1), (SWEET_SWUNG, MAJ)], bpm=72, title="Question and answer, flowing"),
    ], minutes=5, xp=25),
    lesson("gtr-21-5", "Phrase like a singer", [
        explain("Leave space", "Great solos breathe. Play a short phrase, rest about as long as it lasted, then answer. "
                "The silence makes the next notes count."),
        along(G, SPACE, bpm=63, title="Phrases and rests", **MAJ),
        quiz("After a two-beat phrase, how long might you rest?", ["Never: keep playing", "About as long again",
                                                                  "Always a whole bar"], 1),
        explain("Repeat, then change the end", "Play a phrase twice the same way, then change only its ending. Listeners hear "
                "the repeat and lean in for the twist."),
        along(G, VARIED, bpm=63, title="Repeat and vary", **MAJ),
        explain("Vibrato on the long notes", "Hold each long note and rock it with a small, even push and release. Keep it "
                "narrow: the pitch should waver, never wander off."),
        along(G, VARIED, bpm=69, title="Repeat and vary, with vibrato", **MAJ),
    ], minutes=5, xp=25),
    lesson("gtr-21-6", "Expressive lead challenge", [
        explain("Sweet, sour and singing", "No new ideas: the major pentatonic, hammer-ons, slides, trills and both boxes over "
                "the blues. Leave space, and finish on A."),
        quiz("Slide the minor box from fret 5 to fret 2 and it plays…", ["D minor pentatonic", "G major", "A major pentatonic"], 2),
        along(G, MAJ_BOX, bpm=72, title="A major pentatonic, up and down", **MAJ),
        fingered(along(G, COUNTRY, bpm=72, title="Both licks", **MAJ), SLIDE_FINGERS),
        along(G, TRILL, bpm=66, title="Trills on strings 3 and 4", **MAJ),
        chain([(LICK_1, BOX_1), (SWEET_SWUNG, MAJ)], bpm=76, title="Question and answer"),
        along(G, VARIED, bpm=76, title="Repeat and vary", **MAJ),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 22. Song form and arranging

# AABA in G, four bars a section.
SECTION_A = [(G_MAJ, 1), (Em, 1), (C, 1), (D, 1)]
SECTION_B = [(C, 2), (D, 2)]
TRAVIS_D7 = eighths("D3@4 C4@2 A2@5 A3@3 D3@4 C4@2 A2@5 A3@3")
PICKED_VERSE = [(G_MAJ, TRAVIS_G), (G_MAJ, TRAVIS_G), (D7, TRAVIS_D7), (G_MAJ, TRAVIS_G)]
STRUM_CHORUS = [(C, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)]
LIFT_CHORUS = [(C_TRI, 1), (G_TRI_2, 1), (D_TRI, 1), (G_TRI_2, 1)]
LAST_LINE = DBR_LAST                                    # "study war no more": B A C B A
INTRO_LINE = f"{DBR_STUDY} {LAST_LINE} G3:4"
TAG = f"{LAST_LINE} G3:4 {LAST_LINE} G3:4"
FILLED = f"{LAST_LINE} G3 G2@6 D3@4 B2@5"              # the held G filled with the chord's bass notes
TUNE_AND_FILLS = "D4 B3 A3 G3 A3:2 D3@4 F#3@4 B3 A3 G3 E3 G3:2 D3@4 B2@5"

# Down by the Riverside, the learner's arrangement: a Travis-picked intro, the verse and chorus (words and tune as the
# Standards course has them), a G major pentatonic solo of our own over the verse's chords, the second verse and chorus,
# and the tag. The solo's last bar leaves the verse's one-beat pickup free.
TRAVIS_G_IN = "G2@6~2:0.5 B3@2:0.5 D3@4:0.5 G3@3:0.5 G2@6~2:0.5 B3@2:0.5 D3@4:0.5 G3@3:0.5"
TRAVIS_D7_IN = TRAVIS_D7
OPEN_PENT = [(6, 3, 3), (5, 0), (5, 2, 2), (4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0), (1, 3, 3)]
DBR_SOLO = ("G3:0.5 A3:0.5 B3 D4 B3 D4:0.5 E4:0.5 D4:0.5 B3:0.5 G3:2 A3 D4 A3:0.5 G3:0.5 E3 D3 E3 G3:2 "
            "B3:0.5 D4:0.5 E4 G4 E4 D4:0.5 B3:0.5 D4 B3:0.5 A3:0.5 G3 A3:0.5 B3:0.5 A3:0.5 G3:0.5 E3 D3 G2:4")
DBR_ARR = song(G, 84, [
    Part("Intro", "intro", f"{TRAVIS_G_IN} {TRAVIS_G_IN} {TRAVIS_D7_IN} G2@6~2:4", chords="G G D7 G"),
    DBR_V, DBR_C,
    Part("Solo", "solo", DBR_SOLO, chords="G G D7 G G G D7 G"),
    DBR_V.with_lyrics("Verse 2", dbr_words("walk with the Prince of Peace")),
    DBR_C,
    Part("Outro", "outro", f"G3:0.5 A3:0.5 B3:0.5 B3:0.5 {LAST_LINE} G3:4", pickup=2, chords="D7 G",
         lyrics="I ain't gon-na stud-y war no more. _"),
], shapes=SHAPES, words="Traditional spiritual (printed 1918)")
THE_VERSE = "The verse"
THE_CHORUS = "The chorus"

UNIT_22 = unit("gtr-22", "Song form and arranging", "Verse, chorus and AABA, intros and tags, texture and fills, and "
               "your own arrangement of Down by the Riverside.", [
    lesson("gtr-22-1", "How songs are built", [
        explain("Sections", "Most songs are built from a few sections: verses that tell the story, a chorus that repeats the "
                "hook, and sometimes a bridge for contrast. Knowing the plan keeps you from getting lost."),
        quiz("What does a chorus usually carry?", ["The hook everyone sings", "The intro", "The guitar solo"], 0,
             "The chorus returns with the same words and tune. It's the part people remember and sing along to."),
        explain("AABA", "Many older songs use AABA: a tune, the same tune again, a contrasting bridge, then the tune once more. "
                "Each section often runs eight bars; here they run four."),
        quiz("In AABA form, which section is the bridge?", ["The first A", "The B", "The last A"], 1),
        progression(SECTION_A + SECTION_A + SECTION_B + SECTION_A, QUARTERS, bpm=72),
        listen("Does this end at home?", [tones(C), tones(D)], HOME, 1),
    ], minutes=5, xp=25),
    lesson("gtr-22-2", "Intros and endings", [
        explain("Borrow the last line", "The easiest intro is the song's last line, played before the first verse. It sets the "
                "key, the tempo and the mood, and the singer knows exactly where to come in."),
        along(G, INTRO_LINE, bpm=72, title="An intro from the last line"),
        quiz("Why start with the song's last line?", ["It's the hardest part", "It replaces the chorus", "It sets the key and tempo"], 2),
        explain("The tag", "To end, repeat the last line, often twice more, and let the final chord ring. A tag tells everyone "
                "the song is closing."),
        progression(STRUM_CHORUS + [(D7, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)], QUARTERS, bpm=72),
        listen("Does this end at home?", [tones(D7), tones(G_MAJ)], HOME, 0),
        along(G, TAG, bpm=72, title="A tag ending"),
    ], minutes=5, xp=25),
    lesson("gtr-22-3", "Picked verse, strummed chorus", [
        explain("Change the texture", "Arrangers lift a chorus by changing what the guitar does. Fingerpick the verse softly, "
                "then strum the chorus, and the same chords suddenly sound bigger."),
        over(PICKED_VERSE, bpm=66, title="Verse: Travis on G and D7"),
        progression(STRUM_CHORUS, FOLK, bpm=66),
        quiz("What lifts the chorus here?", ["A change of texture", "A faster tempo", "A new key"], 0),
        explain("Build, don't jump", "Each section can add a little: a picked verse, a strummed chorus, then triads up the neck "
                "for the last chorus. Save your biggest sound for the end."),
        progression(LIFT_CHORUS, FOLK, bpm=66),
        over(PICKED_VERSE, bpm=72, title="Verse: Travis, flowing"),
    ], minutes=5, xp=25),
    lesson("gtr-22-4", "Fill the long notes", [
        explain("Fill the gaps", "When the melody holds a long note, a solo guitarist fills the space: a bass note or two from "
                "the chord, then back to the tune in time."),
        along(G, f"{LAST_LINE} G3:4", bpm=66, title="The line, plain"),
        along(G, FILLED, bpm=66, title="The line, with fills"),
        quiz("Where do fills belong?", ["On top of every melody note", "Where the melody holds", "Only in the intro"], 1),
        explain("Fill with chord tones", "Fill with notes of the chord under the long note. Over G: G, B and D. Over D7: D, "
                "F sharp, A and C. They can't clash with the band."),
        along(G, TUNE_AND_FILLS, bpm=66, title="Tune and fills"),
        along(G, f"{FILLED} {TUNE_AND_FILLS}", bpm=72, title="Tune and fills, flowing"),
    ], minutes=5, xp=25),
    lesson("gtr-22-5", "Down by the Riverside: your arrangement", [
        explain("Your arrangement", "Down by the Riverside, a spiritual first printed in 1918, gets the full treatment: a "
                "Travis-picked intro, two verses and choruses, a pentatonic solo, and a tag."),
        DBR_ARR.along("Intro", bpm=66, title="Intro: Travis on G and D7"),
        DBR_ARR.along("Verse 1", bpm=66, title=THE_VERSE),
        DBR_ARR.along("Chorus", bpm=66, title=THE_CHORUS),
        explain("A solo in G major pentatonic", "The solo uses G major pentatonic in open position: G, A, B, D and E. It follows "
                "the verse's chords and ends a beat early, so the singer can come back in.", fretboard(G, OPEN_PENT)),
        DBR_ARR.along("Solo", bpm=69, title="Your solo"),
        quiz("Which parts of this arrangement have no words?", ["The verses", "The choruses", "The intro and the solo"], 2),
        DBR_ARR.take("Down by the Riverside"),
    ], minutes=DBR_ARR.minutes(), xp=35, kind="song", arrangement=DBR_ARR.meta()),
    lesson("gtr-22-6", "Arranger's showcase", [
        explain("Your arrangement, start to finish", "No new ideas: form, intros, tags, texture, fills and your Down by the "
                "Riverside. Play it straight through, like a set."),
        quiz("In AABA, how many times does the A tune come?", ["Three", "Two", "Four"], 0),
        DBR_ARR.along("Intro", bpm=76, title="Intro: Travis on G and D7"),
        progression(STRUM_CHORUS, FOLK, bpm=76),
        DBR_ARR.along("Verse 1", "Chorus", bpm=76, title="Verse and chorus"),
        DBR_ARR.along("Solo", bpm=80, title="Your solo"),
        along(G, TAG, bpm=80, title="A tag ending"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNITS = [UNIT_17, UNIT_18, UNIT_19, UNIT_20, UNIT_21, UNIT_22]
