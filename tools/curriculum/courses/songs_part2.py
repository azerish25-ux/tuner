"""Songs, part 2 (units 4–6): spirituals and Americana, holiday songs, and harder classical themes.

Melody only, all public domain or traditional. Melodies are lib.along strings ("note:beats"); 3/4 counts
quarters, 2/4 counts quarters in two-beat bars, and 6/8 counts eighths (beats_per_bar=6).
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, progression, quiz, rhythm, tap, unit

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
G_MAJ = chord(G, "G", "320003", "21xxx3")
C = chord(G, "C", "x32010", "x32x1x")
D = chord(G, "D", "xx0232", "xxx132")
D7 = chord(G, "D7", "xx0212", "xxx213")
G7 = chord(G, "G7", "320001", "32xxx1")
Em = chord(G, "Em", "022000", "x23xxx")
A7 = chord(G, "A7", "x02020", "xx1x3x")
B7 = chord(G, "B7", "x21202", "x213x4")

# ---------------------------------------------------------------- rhythms (beats inside one bar)
ONCE = [0]
HALVES = [0, 2]
QUARTERS = [0, 1, 2, 3]
WALTZ = [0, 1, 2]                 # 3/4: every beat
DUPLE = [0, 1]                    # 2/4: every beat
COMPOUND = [0, 3]                 # 6/8 counted in eighths: the two big beats

# ---------------------------------------------------------------- shared text (translated once)
MAJOR_MINOR = ["Major", "Minor"]
FIRST_SECOND = ["The first", "The second"]

# ================================================================ 4. Spirituals and Americana

# When the Saints Go Marching In: traditional spiritual. G major, 4/4; each line starts on beat two.
SAINTS_1 = "r:1 G3 B3 C4 D4:4 r:1 G3 B3 C4 D4:4 r:1 G3 B3 C4 D4:2 B3:2 G3:2 B3:2 A3:4"
SAINTS_2 = "r:1 B3 B3 A3 G3:3 G3 B3:2 D4 D4 C4:4 r:2 B3 C4 D4:2 B3:2 G3:2 A3:2 G3:4"
SAINTS = f"{SAINTS_1} {SAINTS_2}"
SAINTS_CHORDS = [(G_MAJ, 7), (D7, 1), (G_MAJ, 2), (G7, 1), (C, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)]

L_SAINTS = lesson("song-saints", "When the Saints Go Marching In", [
    explain("A spiritual that went to New Orleans", "This traditional spiritual became a jazz standard, and Louis Armstrong "
            "recorded it in 1938. In G, the melody sits on strings 3 and 2.",
            fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    tap([1, 2, 3], bpm=72, bars=2),
    notes(G, ["B3", "B3", "A3", "G3", "G3", "B3", "D4", "D4", "C4"], hint="The middle line: B B A G, then G B D D C."),
    along(G, SAINTS, bpm=72, title="When the Saints Go Marching In"),
    progression(SAINTS_CHORDS, HALVES, bpm=76),
    along(G, SAINTS, bpm=96, title="The Saints, up to speed"),
], minutes=5, xp=30, kind="song")

# ================================================================ 5. Holiday and celebration

# ================================================================ 6. Classical themes II

# ================================================================ units

UNITS = [
    unit("song-u4", "Spirituals and Americana", "Hymns, marches and a Shaker dance tune from America's songbook.", [
        L_SAINTS,
    ]),
    unit("song-u5", "Holiday and celebration", "Carols and a New Year's song, in two, three, four and six.", [
    ]),
    unit("song-u6", "Classical themes II", "Grieg, Mozart and two old airs: minor keys, sharps and flats, and third position.", [
    ]),
]
