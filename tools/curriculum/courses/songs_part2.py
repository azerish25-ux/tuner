"""Songs, part 2 (units 4–6): hymns and Americana, holiday songs, and harder classical themes.

Melody only, all public domain or traditional. Melodies are lib.along strings ("note:beats"); 3/4 counts
quarters, 2/4 counts quarters in two-beat bars, and 6/8 counts eighths (beats_per_bar=6).
Units 4 and 5 stay in first position; unit 6 adds third position (Symphony No. 40, max fret 7).
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, play_chord, progression, quiz, rhythm, tap, unit

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
G_MAJ = chord(G, "G", "320003", "21xxx3")
C = chord(G, "C", "x32010", "x32x1x")
D = chord(G, "D", "xx0232", "xxx132")
D7 = chord(G, "D7", "xx0212", "xxx213")
A7 = chord(G, "A7", "x02020", "xx1x3x")

# ---------------------------------------------------------------- rhythms (beats inside one bar)
HALVES = [0, 2]
QUARTERS = [0, 1, 2, 3]
WALTZ = [0, 1, 2]                 # 3/4: every beat
DUPLE = [0, 1]                    # 2/4: every beat
COMPOUND = [0, 3]                 # 6/8 counted in eighths: the two big beats

# ---------------------------------------------------------------- shared text (translated once)
MAJOR_MINOR = ["Major", "Minor"]


def shape(spec):
    return {"type": "chord", "chord": spec}


# ================================================================ 4. Hymns and Americana

# Clementine (American ballad, published 1884). C major, 3/4, pickup on beat three.
CLEM_1 = "r:2 C4:0.5 C4:0.5 C4 G3 E4:0.5 E4:0.5 E4 C4 C4:0.5 E4:0.5 G4:1.5 G4:0.5 F4:0.5 E4:0.5 D4:2"
CLEM_2 = "D4:0.5 E4:0.5 F4 F4 E4:0.5 D4:0.5 E4 C4 C4:0.5 E4:0.5 D4 G3 B3:0.5 D4:0.5 C4:3"
CLEM = f"{CLEM_1} {CLEM_2}"
CLEM_CHORDS = [(C, 3), (G_MAJ, 2), (C, 1), (G_MAJ, 1), (C, 1)]

L_CLEM = lesson("song-clementine", "Clementine", [
    explain("A Gold Rush ballad", "This American song was published in 1884 and looks back to the California Gold Rush of 1849. "
            "It's in three, on strings 3, 2 and 1.",
            fretboard(G, [(3, 0), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
    quiz("Clementine starts with two quick notes before beat one. What are they called?", ["A pickup", "A chord", "A rest"], 0,
         "A pickup is a few notes that lead into the first strong beat. Here they fall on the and of beat three."),
    notes(G, ["G4", "G4", "F4", "E4", "D4", "D4", "E4", "F4", "F4"], hint="The turn in the middle: G at fret 3 on string 1, down to D, then back up to F."),
    along(G, CLEM, bpm=72, beats_per_bar=3, title="Clementine"),
    progression(CLEM_CHORDS, WALTZ, bpm=80, beats_per_bar=3),
    along(G, CLEM, bpm=96, beats_per_bar=3, title="Clementine, up to speed"),
], minutes=5, xp=30, kind="song")

# Amazing Grace: hymn tune "New Britain" (printed 1829), words John Newton (1779). G major, 3/4.
AMAZING_1 = "r:2 D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:2 E3 D3:2 D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 D4:5"
AMAZING_2 = "B3 D4:2 B3:0.5 G3:0.5 B3:2 A3 G3:2 E3 D3:2 D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:3"
AMAZING = f"{AMAZING_1} {AMAZING_2}"
AMAZING_CHORDS = [(G_MAJ, 2), (C, 1), (G_MAJ, 3), (D7, 2), (G_MAJ, 2), (C, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 2)]

L_AMAZING = lesson("song-amazing-grace", "Amazing Grace", [
    explain("Words from 1779, tune from 1829", "John Newton wrote the words in 1779. The tune, called New Britain, "
            "was first printed in 1829 and joined to his words in 1835.",
            fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 3, 3)])),
    tap([0, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
    notes(G, ["B3", "D4", "B3", "G3", "B3", "A3", "G3", "E3", "D3"], hint="The high line: up to D at fret 3 on string 2, then B G, B A, G E D."),
    along(G, AMAZING, bpm=66, beats_per_bar=3, title="Amazing Grace"),
    progression(AMAZING_CHORDS, WALTZ, bpm=72, beats_per_bar=3),
    along(G, AMAZING, bpm=84, beats_per_bar=3, title="Amazing Grace, flowing"),
], minutes=5, xp=30, kind="song")

# My Country, 'Tis of Thee: Samuel F. Smith's words (1831) to the tune of "God Save the King" (1740s). G major, 3/4.
AMERICA_1 = "G3 G3 A3 F#3:1.5 G3:0.5 A3 B3 B3 C4 B3:1.5 A3:0.5 G3 A3 G3 F#3 G3:3"
AMERICA_2 = ("D4 D4 D4 D4:1.5 C4:0.5 B3 C4 C4 C4 C4:1.5 B3:0.5 A3"
             " B3 C4:0.5 B3:0.5 A3:0.5 G3:0.5 B3:1.5 C4:0.5 D4 E4:0.5 C4:0.5 B3 A3 G3:3")
AMERICA = f"{AMERICA_1} {AMERICA_2}"
AMERICA_CHORDS = [(G_MAJ, 1), (D7, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 3), (C, 1), (D7, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)]

L_AMERICA = lesson("song-my-country", "My Country, 'Tis of Thee", [
    explain("One tune, two countries", "Samuel Francis Smith wrote these American words in 1831, to a tune Britain "
            "already sang as God Save the King.",
            fretboard(G, [(4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
    explain("Long, short, long", "A dot makes a note half again as long. In bar two, F sharp rings for a beat and a half, "
            "G slips in on the and of two, and A lands on three.", rhythm([0, 1.5, 2], beats_per_bar=3)),
    tap([0, 1.5, 2], bpm=66, bars=2, beats_per_bar=3),
    notes(G, ["B3", "C4", "B3", "A3", "G3", "B3", "C4", "D4", "E4", "C4", "B3", "A3", "G3"],
          hint="The last line: B C B A G, then B C D, up to open E, and down C B A G."),
    along(G, AMERICA, bpm=66, beats_per_bar=3, title="My Country, 'Tis of Thee"),
    progression(AMERICA_CHORDS, WALTZ, bpm=72, beats_per_bar=3),
    along(G, AMERICA, bpm=80, beats_per_bar=3, title="My Country, a little faster"),
], minutes=6, xp=35, kind="song")

# Simple Gifts: Shaker song by Joseph Brackett (1848). C major, 4/4, two-beat pickup.
SIMPLE_A = ("r:2 G3 G3 C4 C4:0.5 D4:0.5 E4:0.5 C4:0.5 E4:0.5 F4:0.5 G4 G4:0.5 G4:0.5 E4 D4:0.5 C4:0.5 D4 D4 D4 D4"
            " D4:0.5 E4:0.5 D4:0.5 B3:0.5 G3 G3 C4:0.5 B3:0.5 C4:0.5 D4:0.5 E4 D4:0.5 D4:0.5 E4 F4 G4:1.5 G4:0.5"
            " D4 D4:0.5 E4:0.5 D4 C4:0.5 C4:0.5 D4 C4:0.5 B3:0.5 C4:2")
SIMPLE_B = ("G4:2 E4:1.5 D4:0.5 E4:0.5 F4:0.5 E4:0.5 D4:0.5 C4:1.5 D4:0.5 E4 E4:0.5 F4:0.5 G4 E4 D4 D4:0.5 E4:0.5 D4:1.5 G3:0.5"
            " C4:2 C4:1.5 D4:0.5 E4 E4:0.5 F4:0.5 G4 G4:0.5 G4:0.5 D4 D4 E4 E4:0.5 D4:0.5 C4 C4 C4:2")
SIMPLE = f"{SIMPLE_A} {SIMPLE_B}"
SIMPLE_CHORDS = [(C, 2), (G_MAJ, 2), (C, 2), (G_MAJ, 1), (C, 4), (G_MAJ, 1), (C, 2), (G_MAJ, 1), (C, 1)]

L_SIMPLE = lesson("song-simple-gifts", "Simple Gifts", [
    explain("A Shaker dance song", "Joseph Brackett wrote Simple Gifts in 1848 for the Shakers, who danced as they sang. "
            "Aaron Copland later built part of his ballet Appalachian Spring around it.",
            fretboard(G, [(3, 0), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
    notes(G, ["G4", "E4", "D4", "E4", "F4", "E4", "D4", "C4"], hint="The second part starts high: G at fret 3 on string 1, then E D, and E F E D C."),
    along(G, SIMPLE_B, bpm=60, title="The second part"),
    quiz("Two notes share each beat in this tune. How do you count them?", ["One-and, two-and", "One, two, three", "One-e-and-a"], 0,
         "Two even notes per beat are eighth notes. Say the number on the first and \"and\" on the second."),
    along(G, SIMPLE, bpm=66, title="Simple Gifts"),
    progression(SIMPLE_CHORDS, HALVES, bpm=72),
    along(G, SIMPLE, bpm=84, title="Simple Gifts, dancing"),
], minutes=6, xp=35, kind="song")

L_MEDLEY_4 = lesson("song-medley-americana", "Americana medley", [
    explain("Four songs, one sitting", "No new ideas: the four songs from this unit, each a little faster than before. "
            "Three of them sway in three. Simple Gifts dances in four."),
    listen("Which song starts like this?", [["G3"], ["G3"], ["A3"], ["F#3"], ["G3"], ["A3"]],
           ["Amazing Grace", "My Country, 'Tis of Thee", "Clementine"], 1),
    along(G, CLEM, bpm=104, beats_per_bar=3, title="Clementine"),
    progression(AMAZING_CHORDS, WALTZ, bpm=84, beats_per_bar=3),
    along(G, AMAZING, bpm=88, beats_per_bar=3, title="Amazing Grace"),
    quiz("What does a dot after a note do?", ["Makes it half again as long", "Makes it short and detached", "Raises it one fret"], 0,
         "A dotted quarter lasts a beat and a half. The note after it is usually quick, to fill out the beat."),
    along(G, AMERICA, bpm=84, beats_per_bar=3, title="My Country, 'Tis of Thee"),
    along(G, SIMPLE, bpm=92, title="Simple Gifts"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ 5. Holiday and celebration

# Good King Wenceslas: "Tempus adest floridum", Piae Cantiones (1582); J. M. Neale's words (1853). G major, 4/4.
WENCES_1 = "G3 G3 G3 A3 G3 G3 D3:2 E3 D3 E3 F#3 G3:2 G3:2"
WENCES_3 = "D4 C4 B3 A3 B3 A3 G3:2 E3 D3 E3 F#3 G3:2 G3:2"
WENCES_4 = "D3 D3 E3 F#3 G3 G3 A3:2 D4 C4 B3 A3 G3:2 C4:2 G3:4"
WENCES = f"{WENCES_1} {WENCES_1} {WENCES_3} {WENCES_4}"
WENCES_CHORDS = [(G_MAJ, 2), (D7, 1), (G_MAJ, 3), (D7, 1), (G_MAJ, 3), (D7, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 2), (C, 1), (G_MAJ, 1)]

L_WENCES = lesson("song-good-king-wenceslas", "Good King Wenceslas", [
    explain("A spring song turned carol", "This tune was printed in 1582 in Piae Cantiones, a songbook from Finland, "
            "as a song about spring. John Mason Neale gave it Christmas words in 1853.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    notes(G, ["D3", "D3", "E3", "F#3", "G3", "G3", "A3"], hint="The last line climbs from open D on string 4: E, F sharp at fret 4, open G, then A."),
    notes(G, ["D4", "C4", "B3", "A3", "G3", "C4", "G3"], hint="Then from D at fret 3 on string 2, step down to G, touch C, and land on G."),
    along(G, WENCES, bpm=72, title="Good King Wenceslas"),
    progression(WENCES_CHORDS, HALVES, bpm=80),
    along(G, WENCES, bpm=96, title="Good King Wenceslas, brisk"),
], minutes=5, xp=30, kind="song")

# Deck the Halls: Welsh "Nos Galan" (1700s); English words 1862. G major, 4/4.
DECK_1 = "D4:1.5 C4:0.5 B3 A3 G3 A3 B3 G3 A3:0.5 B3:0.5 C4:0.5 A3:0.5 B3:1.5 A3:0.5 G3 F#3 G3:2"
DECK_3 = "A3:1.5 B3:0.5 C4 A3 B3:1.5 C4:0.5 D4 A3 B3:0.5 C#4:0.5 D4 E4:0.5 F#4:0.5 G4 F#4 E4 D4:2"
DECK_4 = "D4:1.5 C4:0.5 B3 A3 G3 A3 B3 G3 E4:0.5 E4:0.5 E4:0.5 E4:0.5 D4:1.5 C4:0.5 B3 A3 G3:2"
DECK = f"{DECK_1} {DECK_1} {DECK_3} {DECK_4}"
DECK_CHORDS = [(G_MAJ, 2), (D7, 1), (G_MAJ, 3), (D7, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1), (A7, 1), (D7, 1), (G_MAJ, 2), (C, 1), (G_MAJ, 1)]

L_DECK = lesson("song-deck-the-halls", "Deck the Halls", [
    explain("A Welsh New Year's tune", "Deck the Halls comes from Nos Galan, a Welsh New Year's Eve song from the 1700s. "
            "The English words came in 1862.",
            fretboard(G, [(4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 2, 2), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
    notes(G, ["B3", "C#4", "D4", "E4", "F#4", "G4", "F#4", "E4", "D4"],
          hint="The third line climbs: C sharp at fret 2 on string 2, D, then E, F sharp and G on string 1."),
    along(G, DECK_3, bpm=66, title="The third line"),
    along(G, DECK, bpm=72, title="Deck the Halls"),
    explain("A7: two fingers", "A7 needs two fingers on fret 2: finger 1 on string 4, finger 3 on string 2. "
            "Start your strum on string 5. That C sharp on string 2 is the one the melody climbs through.", shape(A7)),
    play_chord(A7),
    progression(DECK_CHORDS, HALVES, bpm=80),
    along(G, DECK, bpm=96, title="Deck the Halls, merrily"),
], minutes=6, xp=35, kind="song")

# We Wish You a Merry Christmas: traditional, English West Country. G major, 3/4, pickup on beat three.
WISH_A = ("r:2 D3 G3 G3:0.5 A3:0.5 G3:0.5 F#3:0.5 E3 E3 E3 A3 A3:0.5 B3:0.5 A3:0.5 G3:0.5 F#3 D3 D3"
          " B3 B3:0.5 C4:0.5 B3:0.5 A3:0.5 G3 E3 D3:0.5 D3:0.5 E3 A3 F#3 G3:2")
WISH_B = "D3 G3 G3 G3 F#3:2 F#3 G3 F#3 E3 D3:2 A3 B3 A3 G3 D4 D3 D3:0.5 D3:0.5 E3 A3 F#3 G3:3"
WISH = f"{WISH_A} {WISH_B}"
WISH_CHORDS = [(G_MAJ, 1), (C, 1), (A7, 1), (D7, 1), (G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 2),
               (D7, 1), (C, 1), (D7, 1), (G_MAJ, 1), (D7, 2), (G_MAJ, 1)]

L_WISH = lesson("song-we-wish-you", "We Wish You a Merry Christmas", [
    explain("Carolers at the door", "This carol comes from England's West Country, where singers went door to door "
            "on winter nights and hoped for a treat in return.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    tap([0, 1, 1.5, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
    quiz("D at fret 3 on string 2 and open string 4 are both D. How far apart are they?", ["One octave", "One fret", "Nothing: same pitch"], 0,
         "An octave is the same letter, eight steps higher or lower. The two Ds blend, but one sounds brighter."),
    notes(G, ["B3", "A3", "G3", "D4", "D3", "D3", "D3", "E3", "A3", "F#3", "G3"],
          hint="B A G, then leap from D at fret 3 on string 2 down to open D. Then E, A, F sharp, G."),
    along(G, WISH, bpm=72, beats_per_bar=3, title="We Wish You a Merry Christmas"),
    progression(WISH_CHORDS, WALTZ, bpm=80, beats_per_bar=3),
    along(G, WISH, bpm=96, beats_per_bar=3, title="We Wish You, up to speed"),
], minutes=6, xp=35, kind="song")

# Auld Lang Syne: Scottish; Burns's words (1788) printed with this melody in 1799. G major, 4/4, verse and chorus.
ALS_VERSE = ("r:3 D3 G3:1.5 G3:0.5 G3 B3 A3:1.5 G3:0.5 A3 B3 G3:1.5 G3:0.5 B3 D4 E4:3"
             " E4 D4:1.5 B3:0.5 B3 G3 A3:1.5 G3:0.5 A3 B3 G3:1.5 E3:0.5 E3 D3 G3:3")
ALS_CHORUS = ("E4 D4:1.5 B3:0.5 B3 G3 A3:1.5 G3:0.5 A3 E4 D4:1.5 B3:0.5 B3 D4 E4:3"
              " G4 D4:1.5 B3:0.5 B3 G3 A3:1.5 G3:0.5 A3 B3 G3:1.5 E3:0.5 E3 D3 G3:3")
ALS = f"{ALS_VERSE} {ALS_CHORUS}"
ALS_CHORDS = [(G_MAJ, 1), (D7, 1), (G_MAJ, 1), (C, 1), (G_MAJ, 1), (D7, 1), (C, 1), (G_MAJ, 2),
              (D7, 1), (G_MAJ, 1), (C, 1), (G_MAJ, 1), (D7, 1), (C, 1), (G_MAJ, 1)]

L_ALS = lesson("song-auld-lang-syne", "Auld Lang Syne", [
    explain("Old long since", "Auld lang syne is Scots for old long since, meaning days gone by. Robert Burns sent the words "
            "to a songbook in 1788, and this melody was printed with them in 1799.",
            fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0), (1, 3, 3)])),
    tap([0, 1.5, 2, 3], bpm=66, bars=2),
    notes(G, ["B3", "D4", "E4", "G4", "D4", "B3", "B3", "G3"], hint="The chorus reaches up: B, D, open E, then G at fret 3 on string 1. Back down: D, B B G."),
    along(G, f"r:3 {ALS_CHORUS}", bpm=60, title="The chorus"),
    along(G, ALS, bpm=66, title="Auld Lang Syne"),
    progression(ALS_CHORDS, HALVES, bpm=72),
    along(G, ALS, bpm=80, title="Auld Lang Syne, all together"),
], minutes=6, xp=35, kind="song")

# Joy to the World: "Antioch", arranged by Lowell Mason (1839) from Handel. G major, 2/4.
JOY_1 = "G4 F#4:0.75 E4:0.25 D4:1.5 C4:0.5 B3 A3 G3:1.5 D4:0.5 E4:1.5 E4:0.5 F#4:1.5 F#4:0.5 G4:1.5 G4:0.5"
JOY_2 = ("G4:0.5 F#4:0.5 E4:0.5 D4:0.5 D4:0.75 C4:0.25 B3:0.5 G4:0.5"
         " G4:0.5 F#4:0.5 E4:0.5 D4:0.5 D4:0.75 C4:0.25 B3:0.5 B3:0.5")
JOY_3 = ("B3:0.5 B3:0.5 B3:0.5 B3:0.25 C4:0.25 D4:1.5 C4:0.25 B3:0.25 A3:0.5 A3:0.5 A3:0.5 A3:0.25 B3:0.25 C4:1.5 B3:0.25 A3:0.25"
         " G3:0.5 G4 E4:0.5 D4:0.75 C4:0.25 B3:0.5 C4:0.5 B3 A3 G3:2")
JOY = f"{JOY_1} {JOY_2} {JOY_3}"
JOY_CHORDS = [(G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 6), (D7, 3), (C, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)]

L_JOY = lesson("song-joy-to-the-world", "Joy to the World", [
    explain("Handel's echoes", "Lowell Mason arranged this tune in 1839, borrowing phrases from Handel's Messiah. "
            "It opens with a G major scale, straight down from G to G.",
            fretboard(G, [(1, 3, 3), (1, 2, 2), (1, 0), (2, 3, 3), (2, 1, 1), (2, 0), (3, 2, 2), (3, 0)])),
    explain("Two beats to a bar", "This carol counts in two. In bar one, G fills beat one, F sharp takes most of beat two, "
            "and E slips in at the very end.", rhythm([0, 1, 1.75], beats_per_bar=2)),
    tap([0, 1, 1.75], bpm=60, bars=2, beats_per_bar=2),
    notes(G, ["B3", "B3", "B3", "B3", "C4", "D4", "C4", "B3", "A3", "A3", "A3", "A3", "B3", "C4"],
          hint="The middle repeats open B and steps up to D, then repeats A at fret 2 on string 3 and steps up to C."),
    along(G, JOY, bpm=60, beats_per_bar=2, title="Joy to the World"),
    progression(JOY_CHORDS, DUPLE, bpm=72, beats_per_bar=2),
    along(G, JOY, bpm=80, beats_per_bar=2, title="Joy to the World, ringing"),
], minutes=6, xp=35, kind="song")

# Silent Night: Franz Xaver Gruber (1818). D major, 6/8 counted in eighths.
SILENT_1 = "A3:3 B3:1 A3:2 F#3:6 A3:3 B3:1 A3:2 F#3:6 E4:4 E4:2 C#4:6 D4:4 D4:2 A3:6"
SILENT_2 = "B3:4 B3:2 D4:3 C#4:1 B3:2 A3:3 B3:1 A3:2 F#3:6 B3:4 B3:2 D4:3 C#4:1 B3:2 A3:3 B3:1 A3:2 F#3:6"
SILENT_3 = "E4:4 E4:2 G4:3 E4:1 C#4:2 D4:6 F#4:6 D4:2 A3:2 F#3:2 A3:3 G3:1 E3:2 D3:12"
SILENT = f"{SILENT_1} {SILENT_2} {SILENT_3}"
SILENT_CHORDS = [(D, 4), (A7, 2), (D, 2), (G_MAJ, 2), (D, 2), (G_MAJ, 2), (D, 2), (A7, 2), (D, 3), (A7, 1), (D, 2)]

L_SILENT = lesson("song-silent-night", "Silent Night", [
    explain("First sung with a guitar", "Franz Xaver Gruber wrote Silent Night in 1818 for Christmas Eve in Oberndorf, Austria. "
            "At its first performance, the only accompaniment was a guitar.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 2, 2), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
    explain("Six eighths to a bar", "Silent Night is in 6/8: six quick counts per bar, grouped one-two-three, four-five-six. "
            "Each group sways like one slow beat.", rhythm([0, 3, 4], beats_per_bar=6)),
    tap([0, 3, 4], bpm=96, bars=2, beats_per_bar=6),
    notes(G, ["E4", "E4", "G4", "E4", "C#4", "D4", "F#4", "D4", "A3", "F#3", "A3", "G3", "E3", "D3"],
          hint="The ending climbs to G at fret 3 on string 1, rings on F sharp, then walks down to open D."),
    along(G, SILENT, bpm=80, beats_per_bar=6, title="Silent Night"),
    explain("The D chord", "D uses the top four strings. Finger 1 on string 3, fret 2; finger 2 on string 1, fret 2; "
            "finger 3 on string 2, fret 3. Strum from open string 4.", shape(D)),
    play_chord(D),
    progression(SILENT_CHORDS, COMPOUND, bpm=108, beats_per_bar=6),
], minutes=6, xp=35, kind="song")

L_MEDLEY_5 = lesson("song-medley-holiday", "Holiday medley", [
    explain("A holiday concert", "No new ideas: six songs in two, three, four and six, each a little faster than before. "
            "Feel where every bar begins."),
    listen("Which carol starts like this?", [["G4"], ["F#4"], ["E4"], ["D4"], ["C4"], ["B3"], ["A3"], ["G3"]],
           ["Deck the Halls", "Joy to the World", "Silent Night"], 1),
    along(G, WENCES, bpm=104, title="Good King Wenceslas"),
    along(G, DECK, bpm=104, title="Deck the Halls"),
    progression(WISH_CHORDS, WALTZ, bpm=92, beats_per_bar=3),
    quiz("Silent Night is in 6/8. How are its six counts grouped?", ["Two groups of three", "Three groups of two", "Six even beats"], 0,
         "6/8 sways in two big beats, each split into three: one-two-three, four-five-six."),
    along(G, ALS, bpm=88, title="Auld Lang Syne"),
    along(G, JOY, bpm=88, beats_per_bar=2, title="Joy to the World"),
    along(G, SILENT, bpm=96, beats_per_bar=6, title="Silent Night"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ 6. Classical themes II

# Eine kleine Nachtmusik, K. 525 (Mozart, 1787): the opening four bars, G major, an octave down.
KLEINE = ("G3 r:0.5 D3:0.5 G3 r:0.5 D3:0.5 G3:0.5 D3:0.5 G3:0.5 B3:0.5 D4 r:1"
          " C4 r:0.5 A3:0.5 C4 r:0.5 A3:0.5 C4:0.5 A3:0.5 F#3:0.5 A3:0.5 D3 r:1")

L_KLEINE = lesson("song-eine-kleine", "Eine kleine Nachtmusik", [
    explain("A little night music", "Mozart finished this serenade for strings in 1787. Its opening leaps up through "
            "the notes of a G chord, then answers with the notes of D7.",
            fretboard(G, [(4, 0), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    explain("Rests are music too", "A rest is a silent beat. Touch the string with your fretting fingers so the silence is "
            "crisp, then come back in exactly on time.", rhythm([0, 1.5, 2, 3.5])),
    tap([0, 1.5, 2, 3.5], bpm=72, bars=2),
    notes(G, ["C4", "A3", "C4", "A3", "C4", "A3", "F#3", "A3", "D3"],
          hint="The answer: C at fret 1 on string 2, A at fret 2 on string 3, F sharp at fret 4 on string 4, then open D."),
    along(G, KLEINE, bpm=72, title="Eine kleine Nachtmusik"),
    listen("The opening climbs through a chord. Major or minor?", [["G3"], ["B3"], ["D4"], ["G3", "B3", "D4"]], MAJOR_MINOR, 0),
    along(G, f"{KLEINE} {KLEINE}", bpm=100, title="Twice, with sparkle"),
], minutes=5, xp=30, kind="song")

# Greensleeves: English, 16th century. E minor, 3/4, on the low strings; verse then chorus.
GREEN_VERSE = ("r:2 E3 G3:2 A3 B3:1.5 C4:0.5 B3 A3:2 F#3 D3:1.5 E3:0.5 F#3 G3:2 E3 E3:1.5 D#3:0.5 E3 F#3:2 D#3 B2:2"
               " E3 G3:2 A3 B3:1.5 C4:0.5 B3 A3:2 F#3 D3:1.5 E3:0.5 F#3 G3:1.5 F#3:0.5 E3 D#3:1.5 C#3:0.5 D#3 E3:3")
GREEN_CHORUS = ("D4:3 D4:1.5 C#4:0.5 B3 A3:2 F#3 D3:1.5 E3:0.5 F#3 G3:2 E3 E3:1.5 D#3:0.5 E3 F#3:2 D#3 B2:3"
                " D4:3 D4:1.5 C#4:0.5 B3 A3:2 F#3 D3:1.5 E3:0.5 F#3 G3:1.5 F#3:0.5 E3 D#3:1.5 C#3:0.5 D#3 E3:3")
GREEN = f"{GREEN_VERSE} {GREEN_CHORUS}"

L_GREEN = lesson("song-greensleeves", "Greensleeves", [
    explain("Shakespeare knew this tune", "Greensleeves was sung in England by the 1580s, and Shakespeare mentions it "
            "in The Merry Wives of Windsor. Here it's in E minor, low and dark.",
            fretboard(G, [(5, 2, 2), (4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    explain("Sharps that lean home", "In E minor, D sharp sits one fret below E and pulls toward it. Find D sharp at "
            "string 4, fret 1, and C sharp at string 5, fret 4.", fretboard(G, [(4, 1, 1), (5, 4, 4)])),
    notes(G, ["G3", "F#3", "E3", "D#3", "C#3", "D#3", "E3"], hint="Each half ends: G, F sharp, E, then D sharp, C sharp, D sharp, and home to E."),
    notes(G, ["D4", "D4", "C#4", "B3", "A3", "F#3", "D3"], hint="The chorus starts high: D at fret 3 on string 2, C sharp at fret 2, open B, then down to open D."),
    along(G, GREEN, bpm=66, beats_per_bar=3, title="Greensleeves"),
    listen("Greensleeves is built on this chord. Major or minor?", [["E3", "G3", "B3"]], MAJOR_MINOR, 1),
    along(G, GREEN, bpm=84, beats_per_bar=3, title="Greensleeves, flowing"),
], minutes=6, xp=35, kind="song")

# Danny Boy: the Londonderry Air, first printed in Petrie's collection (1855). D major, 4/4, pickup of three eighths.
DANNY_A = ("r:2.5 A2:0.5 D3:0.5 E3:0.5 F#3:1.5 E3:0.5 F#3:0.5 B3:0.5 A3:0.5 F#3:0.5 E3:0.5 D3:0.5 B2:1.5 D3:0.5 F#3:0.5 G3:0.5"
           " A3:1.5 B3:0.5 A3:0.5 F#3:0.5 D3:0.5 F#3:0.5 E3:2.5 C#3:0.5 D3:0.5 E3:0.5"
           " F#3:1.5 E3:0.5 F#3:0.5 B3:0.5 A3:0.5 F#3:0.5 E3:0.5 D3:0.5 B2:1.5 C#3:0.5 D3:0.5 E3:0.5"
           " F#3:1.5 G3:0.5 F#3:0.5 E3:0.5 B2:0.5 C#3:0.5 D3:2.5")
DANNY_B = ("A3:0.5 B3:0.5 C#4:0.5 D4:1.5 C#4:0.5 C#4:0.5 B3:0.5 A3:0.5 B3:0.5 A3:0.5 F#3:0.5 D3:1.5 A3:0.5 B3:0.5 C#4:0.5"
           " D4:1.5 C#4:0.5 C#4:0.5 B3:0.5 A3:0.5 F#3:0.5 E3:2.5")
DANNY_PEAK = ("A3:0.5 A3:0.5 A3:0.5 F#4:1.5 E4:0.5 E4:0.5 D4:0.5 B3:0.5 D4:0.5 A3:0.5 F#3:0.5 D3:1.5 C#3:0.5 D3:0.5 E3:0.5"
              " F#3:1.5 G3:0.5 F#3:0.5 E3:0.5 D3:0.5 C#3:0.5 D3:2.5")
DANNY = f"{DANNY_A} {DANNY_B} {DANNY_PEAK}"
DANNY_CHORDS = [(D, 1), (G_MAJ, 1), (D, 1), (A7, 1), (D, 1), (G_MAJ, 1), (A7, 1), (D, 1),
                (G_MAJ, 1), (D, 1), (G_MAJ, 1), (A7, 1), (D, 2), (A7, 1), (D, 1)]

L_DANNY = lesson("song-danny-boy", "Danny Boy (Londonderry Air)", [
    explain("An Irish air from 1855", "This melody was first printed in George Petrie's collection of Irish music in 1855. "
            "The words of Danny Boy were set to it much later, in 1913.",
            fretboard(G, [(5, 0), (5, 2, 2), (5, 4, 4), (4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2),
                          (2, 0), (2, 2, 2), (2, 3, 3), (1, 0), (1, 2, 2)])),
    notes(G, ["A3", "A3", "A3", "F#4", "E4", "E4", "D4", "B3", "D4", "A3", "F#3", "D3"],
          hint="The high point: three As, up to F sharp at fret 2 on string 1, then E E D B D, A F sharp D."),
    along(G, f"r:2.5 {DANNY_PEAK}", bpm=60, title="The high point"),
    quiz("This tune runs from string 5 to string 1. What keeps every string in reach?",
         ["Thumb low behind the neck", "Thumb hooked over the top", "Gripping harder"], 0,
         "With your thumb low behind the neck, your fingers arch and reach from string 5 to string 1 without straining."),
    along(G, DANNY, bpm=60, title="Danny Boy"),
    progression(DANNY_CHORDS, HALVES, bpm=66),
    along(G, DANNY, bpm=72, title="Danny Boy, with feeling"),
], minutes=6, xp=35, kind="song")

# Symphony No. 40 in G minor, K. 550 (Mozart, 1788): the opening theme, an octave down, in third position.
POS_3 = {"max_fret": 7, "first_fret": 3}
MOZART_40 = ("r:3 Eb4:0.5 D4:0.5 D4 Eb4:0.5 D4:0.5 D4 Eb4:0.5 D4:0.5 D4 Bb4 r:1 Bb4:0.5 A4:0.5"
             " G4 G4:0.5 F4:0.5 Eb4 Eb4:0.5 D4:0.5 C4 C4 r:1 D4:0.5 C4:0.5"
             " C4 D4:0.5 C4:0.5 C4 D4:0.5 C4:0.5 C4 A4 r:1 A4:0.5 G4:0.5"
             " F#4@1 F#4@1:0.5 Eb4:0.5 D4 D4:0.5 C4:0.5 Bb3 Bb3 r:2")

L_MOZART_40 = lesson("song-mozart-40", "Mozart's Symphony No. 40", [
    explain("Mozart in a minor key", "Mozart finished his Symphony No. 40 in 1788. It's one of only two symphonies he wrote "
            "in a minor key, and it opens with this restless, sighing theme."),
    explain("Third position", "Slide your hand up so finger 1 rests at fret 3. Each finger now covers one fret: 3, 4, 5 and 6. "
            "Move your thumb up too, behind finger 2.",
            fretboard(G, [(3, 3, 1), (3, 5, 3), (2, 3, 1), (2, 4, 2), (2, 6, 4), (1, 2, 1), (1, 3, 1), (1, 5, 3), (1, 6, 4)], frets=5, start=2)),
    quiz("In third position, which finger plays fret 3?", ["Finger 1", "Finger 3", "Finger 4"], 0,
         "A position is named for where finger 1 sits. In third position, finger 1 plays fret 3 and finger 4 reaches fret 6."),
    notes(G, ["Eb4", "D4", "D4", "Eb4", "D4", "D4", "Eb4", "D4", "D4", "Bb4"],
          hint="E flat at fret 4 and D at fret 3 on string 2, then finger 4 up to B flat at fret 6 on string 1.", **POS_3),
    notes(G, [("F#4", 1), ("F#4", 1), "Eb4", "D4", "D4", "C4", "Bb3"],
          hint="The last phrase: F sharp, reaching finger 1 back to fret 2. Then E flat, D, C at fret 5 on string 3, and B flat.", **POS_3),
    along(G, MOZART_40, bpm=63, title="Symphony No. 40", **POS_3),
    along(G, MOZART_40, bpm=88, title="Symphony No. 40, faster", **POS_3),
], minutes=6, xp=35, kind="song")

L_MEDLEY_6 = lesson("song-medley-classical-2", "Concert hall medley", [
    explain("Encore", "No new ideas: two Mozart themes, two old airs and third position, each a little faster than before. "
            "Breathe between pieces."),
    listen("Which piece starts like this?", [["G3"], ["D3"], ["G3"], ["D3"], ["G3"], ["D3"], ["G3"], ["B3"], ["D4"]],
           ["Danny Boy", "Greensleeves", "Eine kleine Nachtmusik"], 2),
    along(G, f"{KLEINE} {KLEINE}", bpm=112, title="Eine kleine Nachtmusik"),
    along(G, GREEN, bpm=92, beats_per_bar=3, title="Greensleeves"),
    quiz("In E minor, which note leans up into E?", ["D sharp", "F sharp", "C sharp"], 0,
         "D sharp sits one fret below E. That half step pulls hard toward home, which is why Greensleeves uses it at every cadence."),
    along(G, DANNY, bpm=80, title="Danny Boy"),
    progression(DANNY_CHORDS, QUARTERS, bpm=76),
    along(G, MOZART_40, bpm=100, title="Symphony No. 40", **POS_3),
], minutes=6, xp=40, kind="challenge")

# ================================================================ units

UNITS = [
    unit("song-u4", "Hymns and Americana", "A Gold Rush ballad, two beloved hymns and a Shaker song from America's songbook.", [
        L_CLEM,
        L_AMAZING,
        L_AMERICA,
        L_SIMPLE,
        L_MEDLEY_4,
    ]),
    unit("song-u5", "Holiday and celebration", "Carols and a New Year's song, in two, three, four and six.", [
        L_WENCES,
        L_DECK,
        L_WISH,
        L_ALS,
        L_JOY,
        L_SILENT,
        L_MEDLEY_5,
    ]),
    unit("song-u6", "Classical themes II", "Two Mozart themes and two old airs: rests, minor keys, a wide range and third position.", [
        L_KLEINE,
        L_GREEN,
        L_DANNY,
        L_MOZART_40,
        L_MEDLEY_6,
    ]),
]
