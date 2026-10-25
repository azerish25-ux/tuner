"""Guitar, part 2 (units 11–16): fingerpicking, blues, lead technique, moving barre chords, rhythm styles and a
first arrangement. courses/guitar.py appends these UNITS after unit 10.

Shapes, rhythms, helpers and shared text come from guitar.py, so identical sentences translate once. That makes
the two modules import each other: load courses.guitar (as build.py does), never this module on its own.
Melodies stay in first position except the lead lessons (box 1 at fret 5, box 2 at fret 7).
Capo chords are written at the frets actually pressed (capo on fret 2 = fret 2) and named by the chord that
sounds; strings held by the capo get finger 0. Bends are taught as a concept: the mic judges pitch, so the
only bend step is hearing the target note at its own fret.
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, play_chord, progression, quiz, rhythm, strum, tap, unit
from songbook import Part, song
import tunes
from courses.guitar import (
    A, A7, B7, BOX, BOX_DOTS, C, D, D7, E, E7, EIGHTHS, F_MINI, FIRST_SECOND, FOLK, G, G_MAJ, HALVES, HOME, HOOK,
    MAJOR_MINOR, QUARTERS, SHAPES, SHUFFLE, SKIP, SOLO, THE_CHORUS, THE_VERSE, UP_DOWN, Am, Bm, Em, introduce, shape,
    spotlight, tones,
)
# The Originals this part's song spotlights play from.
from courses.originals import FUNK as NEON_STRUM, NEON_HOOK, NEON_SONG, PORCH_SONG
from courses.originals_part2 import GRAVEL, SALT, SPARK, SPRAY


# ---------------------------------------------------------------- helpers

def eighths(pattern: str) -> str:
    """'A2@5 A3@3 …' with every note an eighth."""
    return " ".join(f"{t}:0.5" for t in pattern.split())


def over(bars, bpm, title, **kw):
    """A play-along over held chords: [(chord shape, melody), …]. Every fretted note must belong to the shape held
    under it and takes that shape's finger (none where a capo holds the string)."""
    step = along(G, " ".join(m for _, m in bars), bpm=bpm, title=title, **kw)
    i = 0
    for spec, melody in bars:
        count = sum(1 for t in melody.split() if t.partition(":")[0].lower() != "r")
        for n in step["notes"][i:i + count]:
            at = n["at"]
            if at["f"]:
                j = len(spec["frets"]) - at["s"]
                assert spec["frets"][j] == at["f"], f"{spec['name']}: string {at['s']} fret {at['f']} isn't in the shape"
                if spec["fingers"][j]:
                    at["g"] = spec["fingers"][j]
                else:
                    at.pop("g", None)
        i += count
    return step


def swung(melody, bpm, title, **kw):
    """A play-along in shuffle feel: ':L' and ':S' are the long and short parts of a beat (2/3 and 1/3)."""
    step = along(G, melody.replace(":L", ":0.6667").replace(":S", ":0.3333"), bpm=bpm, title=title, **kw)
    for n in step["notes"]:
        n["b"], n["d"] = round(n["b"], 3), round(n["d"], 3)
    return step


def walk(*steps):
    """A boogie walk: each note twice, long-short."""
    return " ".join(f"{n}:L {n}:S" for n in steps)


def fingered(step, fingers):
    """Overrides suggested fingers by note index, e.g. a slide keeps one finger: {2: 3}."""
    for i, g in fingers.items():
        step["notes"][i]["at"]["g"] = g
    return step


def on_capo(step):
    """Notes stopped by the capo: no finger to suggest."""
    for n in step["notes"]:
        n["at"].pop("g", None)
    return step


def pin(melody: str, strings: dict) -> str:
    """Each note of a melody fixed to the string `strings` names for it ("E4": 2); rests and lengths kept."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        out.append(token if n.lower() == "r" or "@" in n else f"{n}@{strings[n]}:{length or 1}")
    return " ".join(out)


def in_place(arranged, label, strings, bpm, title, capo=None, **position):
    """A section of an Original (a songbook.Song), its tune and words as written, with every note on the string
    `strings` names: the same section in a position up the neck, or over a capo. A note at the capo's fret is held by
    the capo (no finger), and none may sit below it. position: max_fret and first_fret, as for along()."""
    part = next(p for p in arranged.parts if p.label == label)
    moved = Part(part.label, part.kind, pin(part.melody, strings), part.lyrics, part.chords, part.pickup)
    step = song(G, bpm, [moved], beats_per_bar=arranged.bpb, shapes=arranged.shapes, **position).take(title)
    for n in step["notes"] if capo else []:
        assert n["at"]["f"] >= capo, f"{label}: a note below the capo"
        if n["at"]["f"] == capo:
            n["at"].pop("g", None)
    return step


# ================================================================ 11. Fingerpicking

EM_BASS = "E2@6:1 B2@5:1 E2@6:1 B2@5:1"
AM_BASS = "A2@5:1 E3@4:1 A2@5:1 E3@4:1"
PIMA_AM = eighths("A2@5 A3@3 C4@2 E4@1 A2@5 A3@3 C4@2 E4@1")
PIMA_C = eighths("C3@5 G3@3 C4@2 E4@1 C3@5 G3@3 C4@2 E4@1")
# Travis: thumb alternates two bass strings on the beats; m (string 2) and i (string 3) pluck the ands.
TRAVIS_C = eighths("C3@5 C4@2 E3@4 G3@3 C3@5 C4@2 E3@4 G3@3")
TRAVIS_AM = eighths("A2@5 C4@2 E3@4 A3@3 A2@5 C4@2 E3@4 A3@3")
TRAVIS_G = eighths("G2@6 B3@2 D3@4 G3@3 G2@6 B3@2 D3@4 G3@3")
TRAVIS_PROG = [(C, TRAVIS_C), (Am, TRAVIS_AM), (G_MAJ, TRAVIS_G), (C, TRAVIS_C)]
# p-i-m-a-m-i in 3/4, one bar per chord.
ARP_AM = eighths("A2@5 A3@3 C4@2 E4@1 C4@2 A3@3")
ARP_F = eighths("F3@4 A3@3 C4@2 F4@1 C4@2 A3@3")
ARP_C = eighths("C3@5 G3@3 C4@2 E4@1 C4@2 G3@3")
ARP_G = eighths("G2@6 G3@3 B3@2 G4@1 B3@2 G3@3")
ARP_E = eighths("E2@6 G#3@3 B3@2 E4@1 B3@2 G#3@3")
BALLAD = [(Am, ARP_AM), (F_MINI, ARP_F), (C, ARP_C), (G_MAJ, ARP_G), (Am, ARP_AM), (F_MINI, ARP_F), (E, ARP_E), (Am, ARP_AM)]
# Porchlight (song spotlight): p-i-m-a twice a bar, the thumb on each chord's root, over its verse and chorus chords.
PIMA_D = eighths("D3@4 A3@3 D4@2 F#4@1 D3@4 A3@3 D4@2 F#4@1")
PIMA_A = eighths("A2@5 A3@3 C#4@2 E4@1 A2@5 A3@3 C#4@2 E4@1")
PIMA_G = eighths("G2@6 G3@3 B3@2 G4@1 G2@6 G3@3 B3@2 G4@1")
PIMA_EM = eighths("E2@6 G3@3 B3@2 E4@1 E2@6 G3@3 B3@2 E4@1")
PORCH_VERSE = [(D, PIMA_D), (A, PIMA_A), (G_MAJ, PIMA_G), (D, PIMA_D)]
PORCH_CHORUS = [(Em, PIMA_EM), (G_MAJ, PIMA_G), (A, PIMA_A), (D, PIMA_D)]

UNIT_11 = unit("gtr-11", "Fingerpicking", "Thumb on the bass, p-i-m-a, Travis picking and a fingerpicked ballad.", [
    lesson("gtr-11-1", "Thumb on the bass", [
        explain("Your thumb keeps the beat", "Fingerpicking means plucking with your fingers instead of a pick. Your thumb owns "
                "the bass strings, 6, 5 and 4, and plays on the beat like a bass drum.", rhythm(QUARTERS)),
        notes(G, [("E2", 6), ("A2", 5), ("D3", 4)], hint="Thumb only: push down through strings 6, 5 and 4, one at a time."),
        quiz("Which strings does your thumb usually play?", ["Strings 1, 2 and 3", "Strings 4, 5 and 6", "Only string 6"], 1,
             "The thumb takes the bass strings. Your fingers take the thinner ones."),
        explain("Root, then fifth", "Hold A minor. Your thumb plays the root on string 5, then rocks over to string 4, the chord's "
                "fifth. Root, fifth, root, fifth: that's an alternating bass.", shape(Am)),
        over([(Am, AM_BASS), (Am, "A2@5:1 E3@4:1 A2@5:2")], bpm=66, title="A minor, alternating bass"),
        over([(Em, EM_BASS), (Em, "E2@6:1 B2@5:1 E2@6:2")], bpm=66, title="E minor, alternating bass"),
        over([(Em, EM_BASS), (Am, AM_BASS)] * 2, bpm=69, title="E minor to A minor"),
    ], minutes=5, xp=25),
    lesson("gtr-11-2", "p, i, m and a", [
        explain("Letters for your fingers", "Fingerstyle borrows Spanish names: p for the thumb, i index, m middle, a ring. "
                "Rest i on string 3, m on string 2 and a on string 1, ready to pluck.", fretboard(G, [(3, 0), (2, 0), (1, 0)])),
        notes(G, [("G3", 3), ("B3", 2), ("E4", 1)], hint="i, m, a: index on string 3, middle on 2, ring on 1."),
        quiz("Which finger is a?", ["The index finger", "The thumb", "The ring finger"], 2,
             "p thumb, i index, m middle, a ring. The little finger usually rests."),
        over([(Em, "E2@6:1 G3@3:1 B3@2:1 E4@1:1")] * 2, bpm=66, title="E minor, p-i-m-a"),
        explain("Pluck into your palm", "Each finger plucks up and slightly toward your palm, then relaxes. Keep your hand still "
                "above the strings and let the fingers do the moving."),
        over([(Am, PIMA_AM)] * 2, bpm=63, title="A minor, p-i-m-a"),
        over([(C, PIMA_C)] * 2, bpm=63, title="C, p-i-m-a"),
        over([(Am, PIMA_AM), (C, PIMA_C)] * 2, bpm=66, title="A minor to C"),
    ], minutes=5, xp=25),
    lesson("gtr-11-3", "Travis picking", [
        explain("Thumb steady, fingers between", "Travis picking, named after Merle Travis, keeps the thumb alternating on every "
                "beat while the fingers pluck in between, on the ands.", rhythm(EIGHTHS)),
        over([(C, "C3@5:1 E3@4:1 C3@5:1 E3@4:1")] * 2, bpm=66, title="C, thumb alone"),
        quiz("In Travis picking, what does the thumb do?", ["Plays only on beat one", "Rests while the fingers play",
                                                             "Alternates bass notes on every beat"], 2,
             "The thumb is the steady pulse: a bass note on every beat, rocking between two strings."),
        explain("Add the fingers", "Keep the thumb going. Between thumb notes, m plucks string 2 and i plucks string 3: "
                "thumb, m, thumb, i. Go slowly until it runs by itself.", shape(C)),
        over([(C, TRAVIS_C)] * 2, bpm=60, title="C, Travis pattern"),
        quiz("Between thumb notes, which finger plucks string 2?", ["i", "m", "a"], 1,
             "In this pattern m takes string 2 and i takes string 3. The a finger rests for now."),
        over([(C, TRAVIS_C)] * 4, bpm=66, title="C, keep it rolling"),
    ], minutes=5, xp=25),
    lesson("gtr-11-4", "Travis through the changes", [
        explain("The thumb moves first", "When the chord changes, the thumb lands on the new root right on beat one. "
                "The fingers keep plucking strings 2 and 3 as before.", shape(G_MAJ)),
        over([(G_MAJ, TRAVIS_G)] * 2, bpm=60, title="G, Travis pattern"),
        over([(Am, TRAVIS_AM)] * 2, bpm=60, title="A minor, Travis pattern"),
        quiz("The chord changes. Where does your thumb go?", ["To string 1", "To the new chord's root", "Nowhere; it waits a beat"], 1,
             "The bass tells the ear which chord you're on. Landing the root on beat one makes the change clear."),
        over(TRAVIS_PROG, bpm=60, title="C, A minor, G"),
        explain("Let it ring", "Hold each chord for the whole bar so every note rings into the next. "
                "Lift a finger only when the next shape needs it."),
        over(TRAVIS_PROG * 2, bpm=66, title="Travis, flowing"),
    ], minutes=5, xp=25),
    lesson("gtr-11-5", "A fingerpicked ballad", [
        explain("Rolling arpeggios", "An arpeggio plays a chord one note at a time. This one rolls p, i, m, a, then back down "
                "m, i. Six notes fill a bar of three, two to a beat.", rhythm([0, 0.5, 1, 1.5, 2, 2.5], beats_per_bar=3)),
        over([(Am, ARP_AM)] * 2, bpm=60, beats_per_bar=3, title="A minor, p-i-m-a-m-i"),
        quiz("After a plucks string 1, which finger comes next?", ["p", "m", "i"], 1,
             "The roll turns around at the top: p, i, m, a, then m and i on the way back."),
        over([(Am, ARP_AM), (F_MINI, ARP_F)] * 2, bpm=60, beats_per_bar=3, title="A minor to F"),
        explain("The ballad", "One bar each: A minor, F, C, G, then A minor, F, E, A minor. Your thumb finds each new root: "
                "strings 5, 4, 5 and 6."),
        over(BALLAD[:4], bpm=60, beats_per_bar=3, title="First line"),
        over(BALLAD, bpm=63, beats_per_bar=3, title="The ballad"),
    ], minutes=5, xp=25),
    # Porchlight (D, 70 bpm): a slow ballad on D, A, G and E minor, fingerpicked; the chorus tune on strings 1 and 2.
    spotlight("gtr-11", "Porchlight", [
        introduce("A ballad, fingerpicked", "Porchlight is a Timbre Original: a slow ballad in D. Fingerpick it: your thumb "
                  "on each chord's root, then i, m and a up strings 3, 2 and 1. Let every note ring into the next.",
                  shape(D)),
        quiz("In D, which string does your thumb play?", ["String 4", "String 5", "String 6"], 0,
             "D's root is open string 4. Strings 5 and 6 stay quiet in this chord."),
        over([(D, PIMA_D), (A, PIMA_A)] * 2, bpm=60, title="D to A, p-i-m-a"),
        over(PORCH_VERSE, bpm=60, title="The verse, picked"),
        over(PORCH_CHORUS, bpm=60, title="The chorus, picked"),
        PORCH_SONG.along("Chorus", bpm=63, title=THE_CHORUS),
        over(PORCH_VERSE + PORCH_CHORUS, bpm=66, title="Porchlight, picked"),
    ]),
    lesson("gtr-11-6", "Fingerpicking challenge", [
        explain("Thumb, fingers, flow", "No new ideas: the alternating bass, p-i-m-a, Travis picking and the ballad. "
                "Keep the thumb steady and let every note ring."),
        quiz("In p-i-m-a, which letter is the thumb?", ["i", "a", "p", "m"], 2),
        over([(Em, EM_BASS), (Am, AM_BASS)] * 2, bpm=76, title="E minor to A minor"),
        over([(Am, PIMA_AM), (C, PIMA_C)] * 2, bpm=72, title="A minor to C"),
        quiz("Between thumb notes, which finger plucks string 3?", ["m", "a", "i"], 2),
        over(TRAVIS_PROG * 2, bpm=72, title="Travis, flowing"),
        over(BALLAD, bpm=69, beats_per_bar=3, title="The ballad, flowing"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 12. Blues

TWELVE_A = [(A7, 4), (D7, 2), (A7, 2), (E7, 1), (D7, 1), (A7, 1), (E7, 1)]
QUICK_A = [(A7, 1), (D7, 1), (A7, 2), (D7, 2), (A7, 2), (E7, 1), (D7, 1), (A7, 1), (E7, 1)]
QUICK_E = [(E7, 1), (A7, 1), (E7, 2), (A7, 2), (E7, 2), (B7, 1), (A7, 1), (E7, 1), (B7, 1)]
# Boogie lines: root, third, fifth, sixth up; seventh, sixth, fifth, third down. One bar each.
A_UP, A_DOWN = walk("A2@5", "C#3@5", "E3@4", "F#3@4"), walk("G3@3", "F#3@4", "E3@4", "C#3@5")
D_UP, D_DOWN = walk("D3@4", "F#3@4", "A3@3", "B3@2"), walk("C4@2", "B3@2", "A3@3", "F#3@4")
E_UP, E_DOWN = walk("E2@6", "G#2@6", "B2@5", "C#3@5"), walk("D3@4", "C#3@5", "B2@5", "G#2@6")
BOOGIE = " ".join([A_UP, A_DOWN, A_UP, A_DOWN, D_UP, D_DOWN, A_UP, A_DOWN, E_UP, D_UP, A_UP, E_UP])
TURN = "A3@3:1 G#3@3:1 G3@3:1 F#3@4:1 F3@4:1 E3@4:3"       # bars 11 and 12: A down to E, a fret at a time
LICK_1 = "A4@1:L C5@1:S A4@1:L G4@2:S E4@2:1 G4@2:1 A4@1:4"        # box 1, high A
LICK_2 = "E4@2:L D4@3:S C4@3:L D4@3:S C4@3:L A3@4:S G3@4:1 A3@4:4"   # box 1, low A
LICKS = f"{LICK_1} {LICK_2}"
BOX_1 = {"max_fret": 8, "first_fret": 5}
# Neon Laundromat (song spotlight): the boogie walk in even eighths, a bass line under its A7 vamp; its chorus chords.
NEON_BOOGIE = eighths("A2@5 A2@5 C#3@5 C#3@5 E3@4 E3@4 F#3@4 F#3@4 G3@3 G3@3 F#3@4 F#3@4 E3@4 E3@4 C#3@5 C#3@5")
NEON_CHORUS = [(A7, 2), (E7, 2), (A7, 2), (E7, 1), (A7, 1)]

UNIT_12 = unit("gtr-12", "Blues", "The 12-bar in A, the quick change, a boogie bass line, the turnaround and your first blues licks.", [
    lesson("gtr-12-1", "The blues in A", [
        explain("One, four, five", "Blues chords sit on the first, fourth and fifth notes of the key. In E that's E7, A7 and B7. "
                "Move to the key of A and they become A7, D7 and E7."),
        quiz("In the key of A, which chord does the job B7 did in E?", ["D7", "E7", "G7"], 1,
             "B7 is five letters up from E. Five letters up from A is E, so E7 takes its place."),
        progression([(A7, 2), (D7, 2), (A7, 2), (D7, 2)], SHUFFLE, bpm=63),
        explain("Twelve bars in A", "Four bars of A7, two of D7, two of A7, then one each of E7, D7, A7 and E7. "
                "The last E7 turns you back to the top."),
        progression(TWELVE_A[3:], SHUFFLE, bpm=63),
        progression(TWELVE_A, SHUFFLE, bpm=66),
        progression(TWELVE_A, SHUFFLE, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-12-2", "The quick change", [
        explain("Visit the four chord early", "In a quick change, bar 2 jumps to the four chord and straight back. "
                "In A: A7, D7, A7, A7. It adds motion right from the start."),
        progression([(A7, 1), (D7, 1), (A7, 2)], SHUFFLE, bpm=63),
        quiz("In a quick change in A, which chord is bar 2?", ["A7", "E7", "D7"], 2,
             "The four chord in A is D7. The quick change visits it in bar 2, then returns to A7."),
        progression(QUICK_A, SHUFFLE, bpm=66),
        explain("Now in E", "The quick change works in any key. In E: E7, A7, E7, E7. Watch for B7 near the end, "
                "your four-finger chord.", shape(B7)),
        progression(QUICK_E, SHUFFLE, bpm=66),
        listen("Does this end at home?", [tones(A7), tones(D7), tones(E7)], HOME, 1),
        progression(QUICK_A, SHUFFLE, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-12-3", "A boogie bass line", [
        explain("Walk the chord", "A boogie line walks up the chord and back, each note twice, long-short like the shuffle. "
                "Over A7 it climbs A, C sharp, E, F sharp, G, then walks back down.", rhythm(SHUFFLE)),
        notes(G, [("A2", 5), ("C#3", 5), ("E3", 4), ("F#3", 4), ("G3", 3)],
              hint="Open A, fret 4 on string 5, frets 2 and 4 on string 4, then open G."),
        swung(f"{A_UP} {A_DOWN}", bpm=60, title="Boogie in A"),
        quiz("How do the two notes of each pair feel?", ["Short, then long", "Long, then short", "Exactly even"], 1,
             "It's the shuffle again: a long note on the beat, a short one just before the next."),
        explain("Move it to D and E", "The same walk starts from D on string 4 and from E on string 6. "
                "Over D7: D, F sharp, A, B, C. Over E7: E, G sharp, B, C sharp, D."),
        swung(f"{D_UP} {D_DOWN}", bpm=60, title="Boogie in D"),
        swung(f"{E_UP} {E_DOWN}", bpm=60, title="Boogie in E"),
        swung(" ".join([A_UP, A_DOWN, D_UP, D_DOWN, A_UP, A_DOWN]), bpm=63, title="Boogie, A to D and back"),
    ], minutes=5, xp=25),
    lesson("gtr-12-4", "The turnaround", [
        explain("A lick that turns you around", "Bars 11 and 12 often get a turnaround, a short lick that leads back to the top. "
                "This one walks down from A to E, one fret at a time.",
                fretboard(G, [(3, 2, 2), (3, 1, 1), (3, 0), (4, 4, 4), (4, 3, 3), (4, 2, 2)])),
        notes(G, [("A3", 3), ("G#3", 3), ("G3", 3)], hint="String 3: fret 2, fret 1, then open."),
        notes(G, [("F#3", 4), ("F3", 4), ("E3", 4)], hint="String 4: fret 4, then 3, then 2. Let the E ring."),
        along(G, TURN, bpm=63, title="The turnaround"),
        quiz("Where does a turnaround usually go?", ["Bars 1 and 2", "Bars 11 and 12", "Bars 5 and 6"], 1,
             "The last two bars. It leads the ear back to bar 1 for another time around."),
        explain("Ten bars, then the lick", "Strum the first ten bars with the quick change, then switch to the lick for "
                "bars 11 and 12. That's how a blues band ends each time around."),
        progression(QUICK_A[:7], SHUFFLE, bpm=66),
        along(G, TURN, bpm=66, title="Bars 11 and 12"),
        progression(QUICK_A, SHUFFLE, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-12-5", "Blues licks in A", [
        explain("The pentatonic meets the blues", "Your A minor pentatonic box fits right over a blues in A. Its C rubs "
                "against the C sharp in A7, and that rub is the sound of the blues.", fretboard(G, BOX_DOTS, frets=4, start=5)),
        along(G, BOX, bpm=66, title="Box 1, up and down", **BOX_1),
        swung(LICK_1, bpm=63, title="Lick 1", **BOX_1),
        quiz("Over a blues in A, which note sounds most like home?", ["G", "A", "C"], 1,
             "A is the root of the key. Licks that end on A sound settled; G and C leave you hanging."),
        swung(LICK_2, bpm=63, title="Lick 2", **BOX_1),
        explain("Call and answer", "Blues phrases talk to each other. Play lick 1 as the question, then answer with lick 2, "
                "which lands on the low A."),
        swung(LICKS, bpm=66, title="Question and answer", **BOX_1),
        swung(LICKS, bpm=72, title="Blues licks, up to speed", **BOX_1),
    ], minutes=5, xp=25),
    # Neon Laundromat (A7, 96 bpm): a funk vamp whose hook slides C to C sharp, the blues rub; the boogie walk, played
    # straight, is its bass line; the chorus is A7 and E7.
    spotlight("gtr-12", "Neon Laundromat", [
        introduce("Funk on one chord", "Neon Laundromat is a Timbre Original: funk that sits on one chord, A7. Its hook "
                  "slides from C to C sharp, the same rub your blues licks make, and its chorus drops to E7.",
                  fretboard(G, [(3, 2, 2), (2, 1, 1), (2, 2, 2), (1, 0)])),
        notes(G, ["A3", "C4", "C#4", "E4"], hint="A at fret 2 on string 3, then C and C sharp at frets 1 and 2 on string 2, "
              "then open E."),
        along(G, NEON_HOOK, bpm=72, title=HOOK),
        quiz("Over A7, which note rubs against the chord?", ["C", "C sharp", "E"], 0,
             "A7 is A, C sharp, E and G. C, from your pentatonic box, rubs against its C sharp, and the hook slides from "
             "one to the other."),
        explain("Boogie, played straight", "Neon Laundromat doesn't shuffle. Play your boogie walk in even eighths and it "
                "becomes a bass line under the A7: A, C sharp, E, F sharp, G, and back down.", rhythm(EIGHTHS)),
        along(G, f"{NEON_BOOGIE} {NEON_BOOGIE}", bpm=72, title="Boogie, played straight"),
        tap(NEON_STRUM, bpm=72, bars=2),
        progression(NEON_CHORUS, NEON_STRUM, bpm=72),
        NEON_SONG.along("Verse 1", bpm=76, title=THE_VERSE),
    ], minutes=6),
    lesson("gtr-12-6", "Blues challenge", [
        explain("Twelve bars, your way", "No new ideas: the 12-bar in A and E, the quick change, the boogie line, "
                "the turnaround and your licks. Keep the shuffle swinging."),
        quiz("In a quick change in E, which chord is bar 2?", ["B7", "A7", "E7"], 1),
        progression(QUICK_E, SHUFFLE, bpm=76),
        swung(BOOGIE, bpm=66, title="Boogie, all 12 bars"),
        listen("Does this end at home?", [tones(E7), tones(A7)], HOME, 0),
        along(G, TURN, bpm=72, title="The turnaround"),
        swung(LICKS, bpm=76, title="Question and answer", **BOX_1),
        progression(QUICK_A, SHUFFLE, bpm=80),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 13. Lead technique

UP_NECK = {"max_fret": 10, "first_fret": 5}   # box 1 plus the slide up to fret 9
BOX_2 = {"max_fret": 10, "first_fret": 7}
HAMMERS = "G3@4:0.5 A3@4:1.5 C4@3:0.5 D4@3:1.5 E4@2:0.5 G4@2:1.5 A4@1:0.5 C5@1:1.5"
PULLS = "C5@1:0.5 A4@1:1.5 G4@2:0.5 E4@2:1.5 D4@3:0.5 C4@3:1.5 A3@4:0.5 G3@4:1.5"
HAMMER_PHRASE = "C4@3:0.5 D4@3:1.5 C4@3:1 A3@4:1 G3@4:0.5 A3@4:3.5"
HP_PHRASE = "C4@3:0.5 D4@3:0.5 C4@3:1 A3@4:1 C4@3:1 G3@4:0.5 A3@4:0.5 G3@4:1 E3@5:1 G3@4:1 A3@4:4"
SLIDE_PHRASE = "C4@3:1 D4@3:0.5 E4@3:1.5 D4@3:1 C4@3:1 A3@4:3"      # finger 3 slides 7 to 9 and back
VIBRATO = "C5@1:1 A4@1:3 G4@2:1 E4@2:3 C4@3:1 A3@4:3"
BOX2_DOTS = [(6, 8, 2), (6, 10, 4), (5, 7, 1), (5, 10, 4), (4, 7, 1), (4, 10, 4),
             (3, 7, 1), (3, 9, 3), (2, 8, 2), (2, 10, 4), (1, 8, 2), (1, 10, 4)]
BOX2_LOW = "C3@6:1 D3@6:1 E3@5:1 G3@5:1 A3@4:1 C4@4:1 A3@4:1 G3@5:1 E3@5:1 D3@6:1 C3@6:2"
BOX2_HIGH = "D4@3:1 E4@3:1 G4@2:1 A4@2:1 C5@1:1 D5@1:1 C5@1:1 A4@2:1 G4@2:1 E4@3:1 D4@3:2"
BOX2 = ("C3@6:1 D3@6:1 E3@5:1 G3@5:1 A3@4:1 C4@4:1 D4@3:1 E4@3:1 G4@2:1 A4@2:1 C5@1:1 D5@1:1"
        " C5@1:1 A4@2:1 G4@2:1 E4@3:1 D4@3:1 C4@4:1 A3@4:1 G3@5:1 E3@5:1 D3@6:1 C3@6:2")
LINK = "A3@4:1 C4@3:1 D4@3:0.5 E4@3:1.5 G4@2:1 A4@2:3"         # box 1, slide on string 3, finish in box 2
LINK_FINGERS = {3: 3, 4: 2, 5: 4}
SAME_DIFFERENT = ["Same", "Different"]
# Saltwater Sunday (song spotlight): a break of our own over its verse, Am7 | D7 | Am7 | D7. Bars 1 and 2 in box 1
# (C hammered to D, pulled back); bars 3 and 4 slide finger 3 from D to E on string 3 into box 2. A chord note starts
# every bar and every beat three.
SALT_BREAK_1 = "A3@4:0.5 C4@3:0.5 D4@3:0.5 C4@3:0.5 A3@4:1 G3@4:1 A3@4:1 C4@3:1 D4@3:2"
SALT_BREAK_2 = "C4@3:1 D4@3:0.5 E4@3:1.5 G4@2:1 A4@2:1 G4@2:0.5 E4@3:0.5 D4@3:2"
SALT_BREAK = f"{SALT_BREAK_1} {SALT_BREAK_2}"
SALT_SLIDE = {2: 3, 3: 2, 5: 2, 6: 3, 7: 1}      # box 2 fingers after the slide (finger 1 at fret 7)
SALT_FINGERS = {len(SALT_BREAK_1.split()) + i: g for i, g in SALT_SLIDE.items()}

UNIT_13 = unit("gtr-13", "Lead technique", "Hammer-ons, pull-offs, slides, bends and vibrato, and a second pentatonic box.", [
    lesson("gtr-13-1", "Hammer-ons", [
        explain("Sound a note without picking", "A hammer-on sounds a second note with the fretting hand alone. Pick a note, "
                "then bring another finger down hard, just behind a higher fret. The string keeps ringing.",
                fretboard(G, [(3, 5, 1), (3, 7, 3)], frets=4, start=5)),
        notes(G, [("G3", 3), ("A3", 3)], hint="Pick open string 3, then hammer finger 2 onto fret 2. Don't pick the second note."),
        notes(G, [("C4", 3), ("D4", 3)], hint="String 3: pick fret 5 with finger 1, then hammer finger 3 onto fret 7.", **BOX_1),
        quiz("What makes a hammer-on ring clearly?", ["Picking both notes hard", "A fast, firm landing right behind the fret",
                                                      "Pressing finger 1 harder"], 1,
             "Speed and aim matter more than force. Land on the fingertip, right behind the fret, and the string keeps singing."),
        listen("Did the tune go up or down?", [["C4"], ["D4"]], UP_DOWN, 0),
        along(G, HAMMERS, bpm=60, title="Hammer-ons in box 1", **BOX_1),
        along(G, HAMMER_PHRASE, bpm=63, title="A phrase with hammer-ons", **BOX_1),
    ], minutes=5, xp=25),
    lesson("gtr-13-2", "Pull-offs", [
        explain("Hammer-ons in reverse", "A pull-off drops to a lower note. With both fingers down, pick the higher note, then "
                "flick the top finger off sideways so it plucks the string as it leaves.",
                fretboard(G, [(3, 5, 1), (3, 7, 3)], frets=4, start=5)),
        notes(G, [("A3", 3), ("G3", 3)], hint="Fret 2 on string 3, then flick finger 2 off to sound open G."),
        notes(G, [("D4", 3), ("C4", 3)], hint="Fingers 1 and 3 on frets 5 and 7. Pick, then pull finger 3 off.", **BOX_1),
        quiz("In a pull-off, the top finger…", ["Lifts straight up", "Stays down", "Flicks off sideways, plucking the string"], 2,
             "Lifting straight up lets the note die. A small sideways flick plucks the lower note into life."),
        listen("Did the tune go up or down?", [["D4"], ["C4"]], UP_DOWN, 1),
        along(G, PULLS, bpm=60, title="Pull-offs in box 1", **BOX_1),
        along(G, HP_PHRASE, bpm=63, title="Hammer, then pull", **BOX_1),
    ], minutes=5, xp=25),
    lesson("gtr-13-3", "Slides", [
        explain("Glide to the next note", "To slide, pick a note and keep pressing as you glide the same finger to a new fret. "
                "The pressure carries the sound; only the first note is picked.",
                fretboard(G, [(3, 7, 3), (3, 9, 3)], frets=4, start=6)),
        fingered(notes(G, [("D4", 3), ("E4", 3)], hint="Finger 3 on string 3, fret 7. Pick, then slide up to fret 9 without lifting.",
                       **UP_NECK), {0: 3, 1: 3}),
        quiz("During a slide, what keeps the note sounding?", ["Picking again at the end", "Steady pressure as you glide",
                                                               "A lighter touch"], 1,
             "Ease off and the note dies. Keep the same pressure all the way to the new fret."),
        fingered(notes(G, [("E4", 3), ("D4", 3)], hint="Now back: pick fret 9 and slide down to fret 7.", **UP_NECK), {0: 3, 1: 3}),
        fingered(along(G, SLIDE_PHRASE, bpm=63, title="A phrase with a slide", **UP_NECK), {2: 3}),
        along(G, HP_PHRASE, bpm=66, title="Hammer, then pull", **BOX_1),
        fingered(along(G, SLIDE_PHRASE, bpm=69, title="Slide, up to speed", **UP_NECK), {2: 3}),
    ], minutes=5, xp=25),
    lesson("gtr-13-4", "Bends and vibrato", [
        explain("Bend to a target", "A bend pushes the string across the fret to raise its pitch. A whole-step bend, the size "
                "of two frets, from fret 7 must sound exactly like fret 9.", fretboard(G, [(3, 7, 3), (3, 9)], frets=4, start=6)),
        notes(G, [("E4", 3)], hint="String 3, fret 9: this is your bend target. Let it ring and remember it.", **BOX_2),
        explain("Three fingers push", "Put finger 3 on fret 7 with fingers 1 and 2 behind it on the same string. Push all three "
                "toward the ceiling, turning your wrist as if turning a doorknob."),
        quiz("Your bend from fret 7 sounds lower than fret 9. What now?", ["Push a little further", "Pick harder", "Release the bend"], 0,
             "A bend that falls short sounds sour. Push until it matches the target you heard."),
        listen("Target, then a short bend. Same note or different?", [["E4"], ["Eb4"]], SAME_DIFFERENT, 1),
        explain("Vibrato makes notes sing", "Vibrato is a small bend and release, repeated quickly on a held note. "
                "Keep it narrow and even so the note stays in tune."),
        along(G, VIBRATO, bpm=60, title="Make the long notes sing", **BOX_1),
        along(G, SOLO, bpm=66, title="Your solo, with feeling", **BOX_1),
    ], minutes=5, xp=25),
    lesson("gtr-13-5", "Box 2 and the link", [
        explain("A second box", "The same five notes repeat up the neck. Box 2 starts where box 1 ends: finger 1 at fret 7 on "
                "strings 5, 4 and 3, finger 2 at fret 8 on strings 6, 2 and 1.", fretboard(G, BOX2_DOTS, frets=4, start=7)),
        notes(G, [("C3", 6), ("D3", 6), ("E3", 5), ("G3", 5)], hint="String 6: frets 8 and 10. String 5: frets 7 and 10.", **BOX_2),
        along(G, BOX2_LOW, bpm=60, title="Strings 6, 5 and 4", **BOX_2),
        quiz("Which notes are in box 2?", ["A B C D E", "A C D E G", "A C E G B"], 1,
             "The same five notes as box 1, A C D E G, in a new place on the neck."),
        along(G, BOX2_HIGH, bpm=60, title="Strings 3, 2 and 1", **BOX_2),
        explain("The link: slide up", "To travel from box 1 to box 2, slide finger 3 from fret 7 to fret 9 on string 3. "
                "You arrive in box 2 with your hand already in place."),
        fingered(along(G, LINK, bpm=60, title="From box 1 to box 2", **UP_NECK), LINK_FINGERS),
        along(G, BOX2, bpm=63, title="Box 2, up and down", **BOX_2),
    ], minutes=5, xp=25),
    # Saltwater Sunday (A minor, 76 bpm): reggae where Am7 and D7 trade bars; a hammer, pull and slide break across both
    # boxes, then the Original's chorus.
    spotlight("gtr-13", "Saltwater Sunday", [
        introduce("Lead over a reggae groove", "Saltwater Sunday is a Timbre Original: laid-back reggae in A minor, where "
                  "Am7 and D7 trade bars. Both pentatonic boxes fit over them. Hammer, pull and slide, and land on a chord "
                  "note as each bar begins.", fretboard(G, BOX_DOTS, frets=4, start=5)),
        along(G, SALT_BREAK_1, bpm=60, title="Hammer and pull, in box 1", **BOX_1),
        quiz("Over D7, which of these box notes belongs to the chord?", ["C", "E", "G"], 0,
             "D7 is D, F sharp, A and C. C, its seventh, sounds settled; E and G only pass through."),
        fingered(along(G, SALT_BREAK_2, bpm=60, title="Slide up into box 2", **UP_NECK), SALT_SLIDE),
        fingered(along(G, SALT_BREAK, bpm=63, title="Your break over Am7 and D7", **UP_NECK), SALT_FINGERS),
        SALT.along("Chorus", bpm=66, title=THE_CHORUS),
        fingered(along(G, SALT_BREAK, bpm=72, title="Your break over Am7 and D7", **UP_NECK), SALT_FINGERS),
    ], minutes=6),
    lesson("gtr-13-6", "Lead challenge", [
        explain("Phrases with feeling", "No new ideas: hammer-ons, pull-offs, slides, bend targets, vibrato and both boxes. "
                "Play each phrase cleanly, then make it sing."),
        quiz("A whole-step bend from fret 7 should match…", ["Fret 8", "Fret 9", "Fret 12"], 1),
        along(G, HP_PHRASE, bpm=72, title="Hammer, then pull", **BOX_1),
        listen("Target, then a bend. Same note or different?", [["E4"], ["E4"]], SAME_DIFFERENT, 0),
        fingered(along(G, LINK, bpm=66, title="From box 1 to box 2", **UP_NECK), LINK_FINGERS),
        along(G, BOX2, bpm=72, title="Box 2, up and down", **BOX_2),
        fingered(along(G, f"{HP_PHRASE} {LINK}", bpm=69, title="Box 1 to box 2, with feeling", **UP_NECK),
                 {len(HP_PHRASE.split()) + i: g for i, g in LINK_FINGERS.items()}),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 14. Moving barre chords

G_BAR = chord(G, "G", "355433", "134211")     # E shape, root on string 6
A_BAR = chord(G, "A", "577655", "134211")
Fsm = chord(G, "F#m", "244222", "134111")     # E minor shape
B_BAR = chord(G, "B", "x24442", "x13331")     # A shape, root on string 5
C_BAR = chord(G, "C", "x35553", "x13331")
D_BAR = chord(G, "D", "x57775", "x13331")
E_BAR = chord(G, "E", "x79997", "x13331")
Cm = chord(G, "Cm", "x35543", "x13421")       # A minor shape, like B minor
Csm = chord(G, "C#m", "x46654", "x13421")     # the same shape one fret up
SPRAY_LOOP = [(E, 1), (B_BAR, 1), (Csm, 1), (A, 1)]   # Spray Paint Sunrise's verse and chorus

UNIT_14 = unit("gtr-14", "Moving barre chords", "E and A shapes up the neck, major and minor, the closer shape, and a "
               "progression in A.", [
    lesson("gtr-14-1", "The E shape moves", [
        explain("F is only the start", "Your F barre is an E shape with a barre at fret 1. Slide the whole thing up and the name "
                "follows the root on string 6: at fret 3 it's G, at fret 5 it's A.", shape(G_BAR)),
        play_chord(G_BAR),
        quiz("An E-shape barre at fret 5. Which chord?", ["G", "A", "B"], 1,
             "String 6 counts up from E: F at 1, G at 3, A at 5. The barre's fret names the chord."),
        play_chord(A_BAR),
        explain("Minor: lift finger 2", "Lift finger 2 and let the barre cover string 3. That's the E minor shape, and it moves "
                "the same way: F sharp minor at fret 2, A minor at fret 5.", shape(Fsm)),
        play_chord(Fsm),
        listen("Major or minor?", [tones(Fsm)], MAJOR_MINOR, 1),
        progression([(G_BAR, 1), (A_BAR, 1), (G_BAR, 1), (A_BAR, 1)], HALVES, bpm=60),
        progression([(Fsm, 1), (A_BAR, 1), (Fsm, 1), (A_BAR, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-14-2", "The A shape moves", [
        explain("A shape, root on string 5", "B minor was an A minor shape with a barre. The major A shape moves too: barre strings "
                "1 to 5, then lay finger 3 flat across strings 4, 3 and 2, two frets higher.", shape(B_BAR)),
        play_chord(B_BAR),
        quiz("An A-shape barre at fret 3. Which chord?", ["C", "D", "B"], 0, "String 5 counts up from A: B at 2, C at 3, D at 5."),
        play_chord(C_BAR),
        explain("The minor A shape moves too", "For minor, use your B minor fingers: 2, 3 and 4 build the A minor pattern in front "
                "of the barre. At fret 3 that's C minor.", shape(Cm)),
        play_chord(Cm),
        listen("Which chord is minor?", [tones(C_BAR), tones(Cm)], FIRST_SECOND, 1),
        progression([(B_BAR, 1), (C_BAR, 1), (B_BAR, 1), (C_BAR, 1)], HALVES, bpm=60),
        progression([(C_BAR, 1), (Cm, 1), (C_BAR, 1), (Cm, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-14-3", "E shape or A shape?", [
        explain("Every chord has two homes", "Most chords can be an E shape, root on string 6, or an A shape, root on string 5. "
                "Pick whichever sits closer to where your hand already is."),
        quiz("You're playing G at fret 3. Where's the closest C?", ["E shape at fret 8", "A shape at fret 3", "A shape at fret 8"], 1,
             "C's root is on string 5, fret 3. Stay at fret 3 and switch to the A shape."),
        progression([(G_BAR, 1), (C_BAR, 1), (G_BAR, 1), (C_BAR, 1)], HALVES, bpm=60),
        explain("Keep the barre, swap the shape", "From G to C at fret 3, finger 1 stays on the barre. Only the fingers in front "
                "of it change. It's the smoothest barre change there is."),
        quiz("D as an A shape sits at which fret?", ["Fret 3", "Fret 7", "Fret 5"], 2, "String 5: A open, B at 2, C at 3, D at 5."),
        play_chord(D_BAR),
        progression([(G_BAR, 1), (C_BAR, 1), (D_BAR, 1), (G_BAR, 1)], HALVES, bpm=60),
        progression([(G_BAR, 2), (C_BAR, 2), (D_BAR, 2), (G_BAR, 2)], QUARTERS, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-14-4", "F sharp minor, D, A, E", [
        explain("A new key: A major", "F sharp minor, D, A and E all live in the key of A. Start with F sharp minor as a barre "
                "and the other three open.", shape(Fsm)),
        quiz("F sharp minor as an E-shape barre sits at…", ["Fret 2", "Fret 4", "Fret 1"], 0, "String 6: F at fret 1, F sharp at fret 2."),
        progression([(Fsm, 1), (D, 1), (Fsm, 1), (D, 1)], HALVES, bpm=60),
        progression([(Fsm, 1), (D, 1), (A, 1), (E, 1)], HALVES, bpm=60),
        explain("Now all barres", "Play it up the neck: F sharp minor at fret 2, D as an A shape at fret 5, A as an E shape "
                "at fret 5, and E as an A shape at fret 7.", shape(E_BAR)),
        play_chord(E_BAR),
        progression([(Fsm, 1), (D_BAR, 1), (A_BAR, 1), (E_BAR, 1)], HALVES, bpm=60),
        progression([(Fsm, 1), (D_BAR, 1), (A_BAR, 1), (E_BAR, 1)], QUARTERS, bpm=63),
    ], minutes=5, xp=25),
    lesson("gtr-14-5", "Smooth barre changes", [
        explain("Relax between chords", "Let the barre go soft for an instant as you move, then squeeze as you land. "
                "Gripping hard all the way tires your hand and slows the change."),
        progression([(A_BAR, 1), (D_BAR, 1), (A_BAR, 1), (D_BAR, 1)], HALVES, bpm=60),
        quiz("When should your fretting hand squeeze?", ["All the time", "Only as the chord lands", "Never"], 1,
             "Squeeze to land, relax to move. Constant force wears out your hand in minutes."),
        explain("Strum through the move", "On the last up strum before a change, lift the barre and keep strumming. The open "
                "strings sound for a moment, the rhythm never stops, and you land on time."),
        progression([(Bm, 1), (G_BAR, 1), (D_BAR, 1), (A_BAR, 1)], QUARTERS, bpm=63),
        listen("Does this end at home?", [tones(D_BAR), tones(A_BAR)], HOME, 1),
        progression([(Bm, 1), (G_BAR, 1), (D_BAR, 1), (A_BAR, 1)], FOLK, bpm=66),
        progression([(A_BAR, 1), (D_BAR, 1), (E_BAR, 1), (A_BAR, 1)], FOLK, bpm=66),
    ], minutes=5, xp=25),
    # Spray Paint Sunrise (E, 124 bpm): E, B, C sharp minor and A; B and C sharp minor are A-shape barres at frets 2 and 4.
    spotlight("gtr-14", "Spray Paint Sunrise", [
        introduce("Two barres, one family", "Spray Paint Sunrise is a Timbre Original: indie pop in E on E, B, C sharp "
                  "minor and A. B and C sharp minor are both A-shape barres, two frets apart, so one hand shape does most "
                  "of the work.", shape(B_BAR)),
        quiz("C sharp minor as an A minor shape barre sits at…", ["Fret 4", "Fret 2", "Fret 6"], 0,
             "String 5 counts up from A: B at 2, C at 3, C sharp at 4."),
        play_chord(Csm),
        listen("Major or minor?", [tones(Csm)], MAJOR_MINOR, 1),
        progression([(B_BAR, 1), (Csm, 1)] * 2, HALVES, bpm=60),
        progression(SPRAY_LOOP * 2, HALVES, bpm=63),
        SPRAY.along("Chorus", bpm=84, title=THE_CHORUS),
        progression(SPRAY_LOOP * 2, FOLK, bpm=72),
    ], minutes=6),
    lesson("gtr-14-6", "Barre challenge", [
        explain("Up and down the neck", "No new ideas: E and A shapes, major and minor, choosing the closer shape and smooth "
                "changes. Relax between chords and land on beat one."),
        quiz("An E-shape barre at fret 3 is…", ["F", "G", "A"], 1),
        listen("Major or minor?", [tones(Cm)], MAJOR_MINOR, 1),
        progression([(G_BAR, 1), (C_BAR, 1), (D_BAR, 1), (G_BAR, 1)], FOLK, bpm=70),
        quiz("Root on string 5 means which shape?", ["The E shape", "The A shape"], 1),
        progression([(Fsm, 1), (D_BAR, 1), (A_BAR, 1), (E_BAR, 1)], QUARTERS, bpm=70),
        progression([(Bm, 1), (G_BAR, 1), (D_BAR, 1), (A_BAR, 1)], FOLK, bpm=72),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 15. Rhythm styles

E9 = chord(G, "E9", "x76777", "x21333")
D9 = chord(G, "D9", "x54555", "x21333")       # the E9 shape, two frets down
Am_HIGH = chord(G, "Am", "xx7555", "xx3111")  # top four strings of the A minor barre at fret 5
D_HIGH = chord(G, "D", "xx7775", "xx3331")    # top four strings of the D barre at fret 5
SIXTEENTHS = [i / 4 for i in range(16)]
FUNK = [0, 0.75, 1.5, 2, 2.75, 3.5]           # the hits; the hand keeps moving in sixteenths, scratching between them
REGGAE = [1, 3]
POP = [0, 1.5, 2.5, 3, 3.5]                   # down, up on the and of two and three, down-up on four
BOOMS = [(G_MAJ, "G2@6:2 D3@4:2"), (C, "C3@5:2 E3@4:2"), (D, "D3@4:2 A2@5:2"), (G_MAJ, "G2@6:4")]
SPARK_LOOP = [(C, 1), (G_MAJ, 1), (Am, 1), (F_MINI, 1)]   # Sparkler Season's verse and chorus

UNIT_15 = unit("gtr-15", "Rhythm styles", "Funk sixteenths and scratches, the reggae chop, country boom-chick and a "
               "syncopated pop strum.", [
    lesson("gtr-15-1", "Sixteenth notes", [
        explain("Four to a beat", "Sixteenth notes split each beat in four: one-e-and-a, two-e-and-a. Your strumming hand "
                "doubles its speed, down-up-down-up inside every beat.", rhythm(SIXTEENTHS)),
        tap(SIXTEENTHS, bpm=60, bars=2),
        quiz("How many sixteenth notes fill one beat?", ["Two", "Four", "Three"], 1, "One-e-and-a: four even slices of every beat."),
        strum(Em, SIXTEENTHS, bpm=60, bars=2),
        explain("The funk chord: E9", "Funk loves the ninth chord. Finger 2 on string 5, fret 7, finger 1 on string 4, fret 6, "
                "and finger 3 flat across strings 3, 2 and 1 at fret 7.", shape(E9)),
        play_chord(E9),
        strum(E9, SIXTEENTHS, bpm=60, bars=2),
    ], minutes=5, xp=25),
    lesson("gtr-15-2", "Funk: scratches and hits", [
        explain("Mute, then hit", "Keep your hand moving in sixteenths, but relax your fretting fingers so most strums are dead, "
                "scratchy clicks. Press down only for the hits.", rhythm(FUNK)),
        tap(FUNK, bpm=60, bars=2),
        strum(E9, FUNK, bpm=60, bars=2),
        quiz("What makes a scratch?", ["Fretting fingers resting lightly on the strings", "Strumming with your palm",
                                       "Plucking with your thumb"], 0,
             "Touching without pressing stops the strings from ringing. The strum turns into a crisp, percussive click."),
        explain("Short hits, and D9", "Squeeze for each hit, then relax right away so it stays short. Slide the whole E9 shape "
                "down two frets and you have D9.", shape(D9)),
        strum(D9, FUNK, bpm=63, bars=2),
        progression([(E9, 1), (D9, 1), (E9, 1), (D9, 1)], FUNK, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-15-3", "Reggae: the offbeat chop", [
        explain("Chop on two and four", "Reggae guitar answers the drums with short, bright chords on beats two and four. "
                "Strum just the thin strings and cut each chord off right away.", rhythm(REGGAE)),
        tap(REGGAE, bpm=72, bars=2),
        explain("Small, high shapes", "Use the top four strings only. This A minor is the top of your A minor barre at fret 5: "
                "finger 3 on string 4, fret 7, finger 1 barring the rest.", shape(Am_HIGH)),
        strum(Am_HIGH, REGGAE, bpm=72, bars=2),
        quiz("How long should a reggae chop ring?", ["As long as possible", "Barely at all", "Exactly one beat"], 1,
             "Squeeze, strum, release. The chop is a short bark, and the space after it is the groove."),
        explain("D, up top", "Now the top of your D barre: finger 3 flat across strings 4, 3 and 2 at fret 7, "
                "finger 1 on string 1 at fret 5.", shape(D_HIGH)),
        progression([(Am_HIGH, 1), (D_HIGH, 1), (Am_HIGH, 1), (D_HIGH, 1)], REGGAE, bpm=72),
    ], minutes=5, xp=25),
    lesson("gtr-15-4", "Country boom-chick", [
        explain("Bass, strum, bass, strum", "Country rhythm splits the bar: a single bass note on beats one and three, a quick "
                "strum of the thin strings on two and four. Boom, chick, boom, chick.", rhythm(QUARTERS)),
        over([(G_MAJ, "G2@6:2 G2@6:2")] * 2, bpm=72, title="The booms in G"),
        quiz("In boom-chick, what happens on beats two and four?", ["A single bass note", "A short strum of the thin strings",
                                                                     "Nothing at all"], 1),
        strum(G_MAJ, QUARTERS, bpm=72, bars=2),
        explain("Alternate the bass", "Move the second boom to another string: in G, string 6 then string 4. In C, string 5 "
                "then 4. In D, string 4 then open string 5."),
        over(BOOMS, bpm=72, title="Booms in G, C and D"),
        progression([(G_MAJ, 2), (C, 2), (G_MAJ, 2), (D, 2)], QUARTERS, bpm=72),
        progression([(G_MAJ, 1), (C, 1), (D, 1), (G_MAJ, 1)], QUARTERS, bpm=80),
    ], minutes=5, xp=25),
    lesson("gtr-15-5", "The syncopated pop strum", [
        explain("Skip the downbeats", "Syncopation puts the strum where you don't expect it. Down on one, up on the and of two, "
                "up on the and of three, then down-up on four.", rhythm(POP)),
        tap(POP, bpm=66, bars=2),
        strum(G_MAJ, POP, bpm=66, bars=2),
        quiz("In this pattern, what does your hand do on beat two?", ["Strums down hard", "Swings down past the strings",
                                                                      "Stops and waits"], 1,
             "The pendulum never stops. On two the hand swings down without touching, ready for the up strum."),
        progression([(G_MAJ, 1), (D, 1), (Em, 1), (C, 1)], POP, bpm=66),
        explain("Change a little early", "Pop players often change chords on the last up strum, the and of four, so the new "
                "chord arrives a hair early. It pushes the song forward."),
        progression([(G_MAJ, 1), (D, 1), (Em, 1), (C, 1)], POP, bpm=72),
        progression([(C, 1), (G_MAJ, 1), (Am, 1), (F_MINI, 1)], POP, bpm=72),
    ], minutes=5, xp=25),
    # Sparkler Season (C, 104 bpm): C, G, A minor and F, with the syncopated pop strum; its hook on strings 1 and 2.
    spotlight("gtr-15", "Sparkler Season", [
        introduce("The pop strum on four chords", "Sparkler Season is a Timbre Original: a summer anthem in C on C, G, A "
                  "minor and F. Give it the syncopated pop strum, and change a hair early, on the and of four.", rhythm(POP)),
        tap(POP, bpm=72, bars=2),
        progression(SPARK_LOOP * 2, POP, bpm=72),
        notes(G, ["E4", "D4", "E4", "D4", "G4", "D4", "G4", "E4", "D4"],
              hint="Open E and D at fret 3 on string 2, twice, then G at fret 3 on string 1, and back down to D."),
        SPARK.along("Chorus", bpm=80, title=THE_CHORUS),
        quiz("Why change chords on the and of four?", ["So the new chord rings on beat one", "To slow the song down",
                                                       "To skip a chord"], 0,
             "Moving on the last up strum gets your hand there a hair early, so the new chord is ready for beat one."),
        progression(SPARK_LOOP * 2, POP, bpm=88),
    ]),
    lesson("gtr-15-6", "Rhythm styles challenge", [
        explain("Four grooves, one hand", "No new ideas: funk sixteenths, the reggae chop, boom-chick and the syncopated pop "
                "strum. Keep the hand swinging and change only what it hits."),
        tap(FUNK, bpm=66, bars=2),
        progression([(E9, 1), (D9, 1), (E9, 1), (D9, 1)], FUNK, bpm=69),
        quiz("Reggae chops land on which beats?", ["One and three", "Two and four", "Every beat"], 1),
        progression([(Am_HIGH, 1), (D_HIGH, 1), (Am_HIGH, 1), (D_HIGH, 1)], REGGAE, bpm=76),
        over(BOOMS, bpm=80, title="Booms in G, C and D"),
        progression([(G_MAJ, 2), (C, 2), (D, 2), (G_MAJ, 2)], QUARTERS, bpm=84),
        progression([(G_MAJ, 1), (D, 1), (Em, 1), (C, 1)], POP, bpm=76),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 16. Putting it together

# Capo on fret 2: open shapes at the frets actually pressed, named by what sounds. Finger 0 = held by the capo.
CAPO_G = chord(G, "A", "542225", "210003")
CAPO_C = chord(G, "D", "x54232", "x32010")
CAPO_D = chord(G, "E", "xx2454", "xxx132")
CAPO_Em = chord(G, "F#m", "244222", "023000")
CAPO_A = chord(G, "B", "x24442", "xx123x")
# Gravel Road Two-Step (song spotlight), in A with the capo on fret 2: G, C and D shapes sound A, D and E. Its chorus tune
# moves with the capo: no open strings, fret 2 is the capo, and the fingers think in G.
GRAVEL_VERSE = [(CAPO_G, 1), (CAPO_C, 1), (CAPO_G, 1), (CAPO_D, 1), (CAPO_G, 1), (CAPO_C, 1), (CAPO_D, 1), (CAPO_G, 1)]
GRAVEL_CHORUS = [(CAPO_C, 1), (CAPO_G, 1), (CAPO_D, 1), (CAPO_G, 1)] * 2
GRAVEL_CAPO = {"F#4": 1, "E4": 2, "D4": 2, "C#4": 2, "B3": 3, "A3": 3, "G#3": 4}
# Oh! Susanna (Stephen Foster, 1848), in G, 2/4, rhythm simplified to eighths. Checked against the 1851
# Gumbo Chaff banjo tutor (in D). The verse opens with a two-note pickup.
SUS_LINE = "B3:0.5 D4:0.5 D4:0.5 E4:0.5 D4:0.5 B3:0.5 G3:0.5 A3:0.5"
SUS_V1 = f"r:1 G3:0.5 A3:0.5 {SUS_LINE} B3:0.5 B3:0.5 A3:0.5 G3:0.5 A3:2"
SUS_V = f"r:1 G3:0.5 A3:0.5 {SUS_LINE} B3:0.5 B3:0.5 A3:0.5 G3:0.5 A3:1 G3:0.5 A3:0.5 {SUS_LINE} B3:0.5 B3:0.5 A3:0.5 A3:0.5 G3:2"
SUS_C1 = "C4:1 C4:1 E4:0.5 E4:1 E4:0.5 D4:0.5 D4:0.5 B3:0.5 G3:0.5 A3:2"
SUS_C = SUS_C1.replace("A3:2", f"A3:1 G3:0.5 A3:0.5 {SUS_LINE} B3:0.5 B3:0.5 A3:0.5 A3:0.5 G3:2")
SUS = f"{SUS_V} {SUS_C}"
SUS_VERSE = [(G_MAJ, 3), (D7, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)]            # 2/4 bars, after the pickup
SUS_CHORUS = [(C, 2), (G_MAJ, 1), (D7, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)]
BOOM_2 = [0, 1]                                                                # 2/4 boom-chick: bass on one, strum on two
INTRO = [(G_MAJ, eighths("G2@6 B3@2 D3@4 G3@3"))] * 2 + [(D7, eighths("D3@4 C4@2 A2@5 A3@3")), (G_MAJ, eighths("G2@6 B3@2 D3@4 G3@3"))]

# The whole song, three ways (songbook): the verses alone (gtr-16-3), verse and chorus (gtr-16-4), and the learner's
# arrangement with Travis-picked intro, break and ending (gtr-16-5). A verse is two eight-bar halves, each with its
# two-eighth pickup; the words are two of Foster's verses and his chorus.
PICKUP = "G3:0.5 A3:0.5"
SUS_TO_KNEE = f"{SUS_LINE} B3:0.5 B3:0.5 A3:0.5 G3:0.5 A3:1"       # "...with my banjo on my knee": half way
SUS_TO_SEE = f"{SUS_LINE} B3:0.5 B3:0.5 A3:0.5 A3:0.5"             # "...my true love for to see", home on G next
SUS_HALF = "G G G D7 G G G,D7 G"
SUS_TRAVIS_HALF = "G G G D7 G G D7 G"                               # the Travis break holds each bar's chord
SUS_VERSE_TUNE = f"{PICKUP} {SUS_TO_KNEE} {PICKUP} {SUS_TO_SEE} G3:1 {PICKUP} {SUS_TO_KNEE} {PICKUP} {SUS_TO_SEE} G3:2"
SUS_VERSE_1 = Part("Verse 1", "verse", SUS_VERSE_TUNE, pickup=1, chords=f"{SUS_HALF} {SUS_HALF}",
              lyrics=f"{tunes.SUSANNA_WORDS_1A} / {tunes.SUSANNA_WORDS_1B}")
SUS_VERSE_2 = SUS_VERSE_1.with_lyrics("Verse 2", f"{tunes.SUSANNA_WORDS_2A} / {tunes.SUSANNA_WORDS_2B}")
SUS_CH = Part("Chorus", "chorus", SUS_C, chords="C C G D7 G G G,D7 G", lyrics=tunes.SUSANNA_CHORUS)
SUS_INTRO = Part("Intro", "intro", f"{SUS_LINE} B3:0.5 B3:0.5 A3:0.5 A3:0.5 G3:2", chords="G G G,D7 G")
SUS_TAG = f"{PICKUP} {SUS_TO_SEE} G3:2"
# Travis picking, one bar of 2/4 per chord: thumb on the beat, fingers on the ands. A bar before a verse ends on a
# held bass note so the verse's pickup has room.
TRAVIS_G2 = "G2@6~2:0.5 B3@2:0.5 D3@4:0.5 G3@3:0.5"
TRAVIS_D7_2 = "D3@4:0.5 C4@2:0.5 A2@5:0.5 A3@3:0.5"
TRAVIS_END = "G2@6~2:2"

SUS_VERSES = song(G, 69, [
    SUS_INTRO, SUS_VERSE_1, SUS_VERSE_2,
    Part("Solo", "solo", tunes.transpose(SUS_VERSE_TUNE, -12), pickup=1, chords=f"{SUS_HALF} {SUS_HALF}"),
    Part("Outro", "outro", SUS_TAG, pickup=1, chords="G G G,D7 G",
         lyrics="the sun so hot I froze to death; Su-san-na, _ don't you cry."),
], beats_per_bar=2, shapes=SHAPES, words=tunes.SUSANNA_CREDIT)
SUS_SONG = song(G, 72, [
    SUS_INTRO, SUS_VERSE_1, SUS_CH, SUS_VERSE_2, SUS_CH, SUS_CH,
    Part("Outro", "outro", SUS_TAG, pickup=1, chords="G G G,D7 G",
         lyrics="for I come from Al-a-bam-a with my ban-jo on my knee."),
], beats_per_bar=2, shapes=SHAPES, words=tunes.SUSANNA_CREDIT)
SUS_ARRANGED = song(G, 72, [
    Part("Intro", "intro", f"{TRAVIS_G2} {TRAVIS_G2} {TRAVIS_D7_2} {TRAVIS_END}", chords="G G D7 G"),
    SUS_VERSE_1, SUS_CH,
    Part("Solo", "solo", f"{TRAVIS_G2} {TRAVIS_G2} {TRAVIS_G2} {TRAVIS_D7_2} {TRAVIS_G2} {TRAVIS_G2} {TRAVIS_D7_2} {TRAVIS_END}",
         chords=SUS_TRAVIS_HALF),
    SUS_VERSE_2, SUS_CH,
    Part("Outro", "outro", f"{TRAVIS_G2} {TRAVIS_D7_2} {TRAVIS_G2} {TRAVIS_END}", chords="G D7 G G"),
], beats_per_bar=2, shapes=SHAPES, words=tunes.SUSANNA_CREDIT)

UNIT_16 = unit("gtr-16", "Putting it together", "A capo, G and D shapes on capo 2, and Oh! Susanna arranged with a verse "
               "and a chorus.", [
    lesson("gtr-16-1", "The capo", [
        explain("A clamp across the neck", "A capo clamps every string at one fret. On fret 2, each open string sounds two frets "
                "higher, and your open chord shapes all move up with it."),
        notes(G, [("E4", 1), ("B3", 2)], hint="Before the capo: pluck strings 1 and 2 open. That's E and B."),
        on_capo(notes(G, [("F#4", 1), ("C#4", 2)], hint="Now clamp the capo just behind fret 2 and pluck them again: F sharp and C sharp.")),
        quiz("Capo on fret 2. You play a G shape. Which chord sounds?", ["G", "A", "B"], 1,
             "Two frets up from G is A. The shape stays G; the sound moves up with the capo."),
        explain("Think in shapes", "With a capo you still think G, C and D, the shapes you know. The diagrams here name the chord "
                "you actually hear, so a G shape on capo 2 reads A.", shape(CAPO_G)),
        play_chord(CAPO_G),
        play_chord(CAPO_C),
        progression([(CAPO_G, 1), (CAPO_C, 1), (CAPO_G, 1), (CAPO_C, 1)], HALVES, bpm=60),
    ], minutes=5, xp=25),
    lesson("gtr-16-2", "G and D shapes on capo 2", [
        explain("The G family, two frets up", "On capo 2, G, C, D and E minor shapes sound as A, D, E and F sharp minor. "
                "Same fingers, new key: A major.", shape(CAPO_Em)),
        play_chord(CAPO_D),
        play_chord(CAPO_Em),
        progression([(CAPO_G, 1), (CAPO_Em, 1), (CAPO_C, 1), (CAPO_D, 1)], HALVES, bpm=63),
        quiz("Capo on fret 2. A D shape sounds as…", ["D", "E", "F"], 1, "Two frets above D is E."),
        explain("The D family", "D shapes work the same way. On capo 2, D, G and A shapes sound as E, A and B: "
                "the key of E with easy open fingerings.", shape(CAPO_A)),
        play_chord(CAPO_A),
        progression([(CAPO_D, 1), (CAPO_G, 1), (CAPO_A, 1), (CAPO_D, 1)], FOLK, bpm=66),
    ], minutes=5, xp=25),
    lesson("gtr-16-3", "Oh! Susanna: the verse", [
        explain("Verse, then chorus", "Most songs alternate two sections. The verse tells the story; the chorus repeats the hook. "
                "Stephen Foster's Oh! Susanna (1848) has both. Capo off: it's in G.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
        notes(G, ["G3", "A3", "B3", "D4", "D4", "E4"], hint="The pickup and first bar: open G, A at fret 2, then open B, D at fret 3 twice, and open E."),
        along(G, SUS_V1, bpm=66, beats_per_bar=2, title="First line"),
        quiz("Which section usually comes back with the same words?", ["The verse", "The chorus", "The intro"], 1,
             "Verses change their words as the story moves on. The chorus returns unchanged, and that's what people sing along to."),
        along(G, SUS_V, bpm=66, beats_per_bar=2, title="The verse"),
        explain("Chords under the verse", "Back the verse with G and D7, boom-chick style: bass on one, strum on two. "
                "Three bars of G, one of D7, two of G, then D7 and G.", shape(D7)),
        progression(SUS_VERSE, BOOM_2, bpm=72, beats_per_bar=2),
        along(G, SUS_V, bpm=72, beats_per_bar=2, title="The verse, flowing"),
        SUS_VERSES.take("Oh! Susanna"),
    ], minutes=SUS_VERSES.minutes(), xp=35, kind="song", arrangement=SUS_VERSES.meta()),
    lesson("gtr-16-4", "Oh! Susanna: the chorus", [
        explain("The hook starts higher", "The chorus opens on C, string 2, fret 1, then jumps to open E. Its chords are C, G and "
                "D7, and its second half matches the verse's ending.",
                fretboard(G, [(2, 1, 1), (1, 0), (2, 3, 3), (2, 0), (3, 0), (3, 2, 2)])),
        notes(G, ["C4", "C4", "E4", "E4", "E4"], hint="The opening: C twice on string 2, fret 1, then open E three times."),
        notes(G, ["D4", "D4", "B3", "G3", "A3"], hint="Then down: D twice, open B, open G, and A at fret 2."),
        along(G, SUS_C1, bpm=63, beats_per_bar=2, title="First line"),
        quiz("The three E's go short, long, short. Where does the long one start?", ["On the beat", "Halfway through the beat"], 1,
             "It starts on the and and rings across the next beat. That push is syncopation, like your pop strum."),
        along(G, SUS_C, bpm=66, beats_per_bar=2, title="The chorus"),
        progression(SUS_CHORUS, BOOM_2, bpm=72, beats_per_bar=2),
        along(G, SUS, bpm=69, beats_per_bar=2, title="Oh! Susanna"),
        SUS_SONG.take("Oh! Susanna"),
    ], minutes=SUS_SONG.minutes(), xp=35, kind="song", arrangement=SUS_SONG.meta()),
    lesson("gtr-16-5", "Your arrangement", [
        explain("Plan the song", "An arrangement decides what you play, and when. Yours: a Travis-picked intro, the verse as "
                "melody, the chorus strummed boom-chick, then the chorus melody to finish."),
        over(INTRO, bpm=72, beats_per_bar=2, title="Intro: Travis on G"),
        quiz("What does an intro do?", ["Sets the key and tempo before the melody", "Replaces the verse", "Repeats the chorus words"], 0,
             "A few bars of chords tell everyone where home is and how fast to go."),
        along(G, SUS_V, bpm=72, beats_per_bar=2, title="Verse: the melody"),
        progression(SUS_CHORUS, BOOM_2, bpm=72, beats_per_bar=2),
        explain("End on the hook", "Finish with the chorus melody and let the last G ring. Ending on the tune everyone just "
                "heard feels complete."),
        listen("Does this end at home?", [tones(D7), tones(G_MAJ)], HOME, 0),
        along(G, SUS_C, bpm=72, beats_per_bar=2, title="Chorus: the melody"),
        SUS_ARRANGED.take("Oh! Susanna"),
    ], minutes=SUS_ARRANGED.minutes(), xp=35, kind="song", arrangement=SUS_ARRANGED.meta()),
    # Gravel Road Two-Step (A, 116 bpm): dance-hall country on A, D and E, played on capo 2 with G-family shapes; the
    # two-step is the boom-chick with a quick up; the chorus tune moves up with the capo.
    spotlight("gtr-16", "Gravel Road Two-Step", [
        introduce("Country with a capo", "Gravel Road Two-Step is a Timbre Original: dance-hall country in A, on A, D and E. "
                  "Clamp the capo on fret 2 and play it with G, C and D shapes, the ones you know best.", shape(CAPO_G)),
        quiz("Capo on fret 2. Which shape sounds as E?", ["The D shape", "The C shape", "The G shape"], 0,
             "Two frets above D is E. On capo 2 the G shape gives A, and the C shape gives D."),
        progression(GRAVEL_VERSE[:4], HALVES, bpm=63),
        explain("The two-step", "Pick the chord's root on beats one and three, and strum on two and four, each with a quick "
                "up after it. Boom, chick-a, boom, chick-a: the dancers' steps.", rhythm(SKIP)),
        progression(GRAVEL_VERSE, SKIP, bpm=72),
        in_place(GRAVEL, "Chorus", GRAVEL_CAPO, bpm=72, title=THE_CHORUS, capo=2, max_fret=7, first_fret=3),
        progression(GRAVEL_CHORUS, SKIP, bpm=84),
    ]),
    lesson("gtr-16-6", "Final showcase", [
        explain("Your showcase", "No new ideas: the capo, G and D shapes, and your Oh! Susanna arrangement. "
                "Play it as if someone's listening. Maybe someone is."),
        quiz("Capo on fret 2. A C shape sounds as…", ["C", "D", "E"], 1),
        progression([(CAPO_G, 1), (CAPO_Em, 1), (CAPO_C, 1), (CAPO_D, 1)], FOLK, bpm=70),
        progression([(CAPO_D, 1), (CAPO_G, 1), (CAPO_A, 1), (CAPO_D, 1)], FOLK, bpm=72),
        over(INTRO, bpm=80, beats_per_bar=2, title="Capo off: the intro"),
        along(G, SUS_V, bpm=80, beats_per_bar=2, title="Verse: the melody"),
        progression(SUS_CHORUS, BOOM_2, bpm=80, beats_per_bar=2),
        along(G, SUS, bpm=84, beats_per_bar=2, title="Oh! Susanna, up to speed"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNITS = [UNIT_11, UNIT_12, UNIT_13, UNIT_14, UNIT_15, UNIT_16]
