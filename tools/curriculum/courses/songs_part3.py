"""Standards & Classics: famous public-domain songs and themes, start to finish on guitar.

Every tune here passed the rights check in docs/content/PUBLIC-DOMAIN-CLEARANCE.md: first published before 1931, and
every composer, lyricist and arranger whose work is used died before 1956 (or the work is traditional). Only the
traditional melody and the public-domain words are used, never a later arrangement or a later lyric. Melodies were
checked against published transcriptions (cited in the clearance table) and arranged here for guitar in first
position, except where a lesson says otherwise. Each song lesson ends on the whole song (songbook.song).

Meters: 3/4 counts quarters; 6/8 and 9/8 count eighths (beats_per_bar=6 or 9, bpm in eighths).
"""
from lib import chord, course, explain, fretboard, lesson, listen, notes, progression, quiz, rhythm, tap, unit
from songbook import Part, song, transpose

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
G_MAJ = chord(G, "G", "320003", "21xxx3")
C = chord(G, "C", "x32010", "x32x1x")
D = chord(G, "D", "xx0232", "xxx132")
D7 = chord(G, "D7", "xx0212", "xxx213")
Em = chord(G, "Em", "022000", "x23xxx")
Am = chord(G, "Am", "x02210", "xx231x")
A_MAJ = chord(G, "A", "x02220", "xx123x")
A7 = chord(G, "A7", "x02020", "xx1x3x")
E7 = chord(G, "E7", "020100", "x2x1xx")
B7 = chord(G, "B7", "x21202", "x213x4")
G7 = chord(G, "G7", "320001", "32xxx1")
F_MINI = chord(G, "F", "xx3211", "xx3211")
SHAPES = {c["name"]: c for c in [
    G_MAJ, C, D, D7, Em, Am, A_MAJ, A7, E7, B7, G7, F_MINI,
    chord(G, "E", "022100", "x231xx"), chord(G, "Bm", "x24432", "x13421"), chord(G, "C7", "x32310", "x3241x"),
    chord(G, "Gm", "355333", "134111"),
]}

# ---------------------------------------------------------------- rhythms (beats inside one bar)
QUARTERS = [0, 1, 2, 3]
HALVES = [0, 2]
WALTZ = [0, 1, 2]
SIX = [0, 3]                       # 6/8 counted in eighths: the two big beats

# ---------------------------------------------------------------- shared text (translated once)
THE_VERSE = "The verse"
THE_CHORUS = "The chorus"
THE_THEME = "The theme"


def shape(spec):
    return {"type": "chord", "chord": spec}


# ================================================================ 1. Campfire singalongs

# ---------------------------------------------------------------- She'll Be Coming 'Round the Mountain
# Traditional (from the spiritual "When the Chariot Comes"; printed in Carl Sandburg's American Songbag, 1927). G, 4/4.
SHE_LINE_4 = "D3:0.5 D3:0.5 D3:0.5 D3:0.5 B3:0.5 A3:0.5 E3:0.5 F#3:0.5 G3:4"
SHE_TUNE = ("D3:0.5 E3:0.5 G3:0.5 G3:0.5 G3:0.5 G3:0.5 E3:0.5 D3:0.5 B2:0.5 D3:0.5 G3:3 G3:0.5 A3:0.5 "
            "B3:0.5 B3:0.5 B3:0.5 B3:0.5 D4:0.5 B3:0.5 A3:0.5 G3:0.5 A3:3 D4:0.5 C4:0.5 "
            "B3:0.5 B3:0.5 B3:0.5 B3:0.5 A3:0.5 G3:0.5 G3:0.5 D3:0.5 E3:0.5 E3:0.5 E3:0.5 E3:0.5 A3:0.5 G3:0.5 F#3:0.5 E3:0.5 "
            f"{SHE_LINE_4}")
SHE_CHORDS = "G G G D7 G C,D7 G,D7 G"


def she_words(pickup, line):
    """A verse: the pickup ("She'll be") and the six-syllable line ("com-ing 'round the moun-tain"), five times."""
    return (f"{pickup} {line} / when she comes, / {pickup.lower()} {line} / when she comes, / {pickup.lower()} {line}, / "
            f"{pickup.lower()} {line}, / {pickup.lower()} {line} / when she comes.")


SHE_V = Part("Verse 1", "verse", SHE_TUNE, pickup=1, chords=SHE_CHORDS,
             lyrics=she_words("She'll be", "com-ing 'round the moun-tain"))
SHE_SONG = song(G, 96, [
    Part("Intro", "intro", f"G3:0.5 G3:0.5 G3:0.5 G3:0.5 E3:0.5 D3:0.5 B2:0.5 D3:0.5 G3:4 {SHE_LINE_4}", chords="G G G,D7 G"),
    SHE_V,
    SHE_V.with_lyrics("Verse 2", she_words("She'll be", "driv-ing six white hors-es")),
    SHE_V.instrumental("Solo"),
    SHE_V.with_lyrics("Verse 3", she_words("Oh, we'll", "all go out to meet her")),
    Part("Outro", "outro", f"F#3:0.5 E3:0.5 {SHE_LINE_4}", pickup=1, chords="G,D7 G",
         lyrics="she'll be com-ing 'round the moun-tain / when she comes!"),
], shapes=SHAPES, words="Traditional (printed 1927)")

L_SHE = lesson("std-shell-be-coming", "She'll Be Coming 'Round the Mountain", [
    explain("A railroad song", "This tune began as a spiritual. In the 1890s railroad crews in the Midwest gave it new words, "
            "and Carl Sandburg printed it in 1927. It climbs from low B up to D on string 2.",
            fretboard(G, [(5, 2, 2), (4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    notes(G, ["D3", "E3", "G3", "G3", "G3", "G3", "E3", "D3", "B2", "D3", "G3"],
          hint="The first line: open D, E, four open Gs, a dip to B on string 5, then home to G."),
    quiz("The words She'll be come before beat one. What are they?", ["A pickup", "A rest", "A chorus"], 0,
         "A pickup is a few notes that lead into the first strong beat. Here they run up to the word com-."),
    SHE_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    explain("Three chords: G, C and D7", "Most of the song sits on G. D7 comes at the end of the second line, and C "
            "colors the fourth. Change on the word that starts the bar.", shape(C)),
    progression([(G_MAJ, 3), (D7, 1), (G_MAJ, 1), (C, 1), (G_MAJ, 2)], QUARTERS, bpm=80),
    SHE_SONG.take("She'll Be Coming 'Round the Mountain"),
], minutes=SHE_SONG.minutes(), xp=30, kind="song", arrangement=SHE_SONG.meta())

# ---------------------------------------------------------------- Down by the Riverside
# African American spiritual (first printed in Plantation Melodies, Chicago, 1918). G, 4/4, the gospel A sharp.
DBR_DOWN = "r:0.5 B3:0.5 B3:0.5 A#3:0.5 B3:0.5 A3:0.5"
DBR_VERSE = (f"B3:0.5 A#3:0.5 B3:0.5 D3 E3:0.5 G3:0.5 A3:0.5 B3 {DBR_DOWN} G3 "
             "r:0.5 A3:0.5 A3:0.5 G3:0.5 A3:0.5 G3:0.5 F#3 "
             f"{DBR_DOWN} G3:0.5 B3:0.25 A#3:0.25 B3:0.5 D3 E3:0.5 G3:0.5 A3:0.5 B3 "
             f"{DBR_DOWN} G3:0.5 B3:0.25 B3:0.25 B3:0.5 A3 C4:0.5 B3 A3 G3:4")
DBR_STUDY = "C4:0.5 C4:0.5 C4:0.5 C4:0.5 C4:0.5 C4:0.5 G3:0.5 A3:0.25 A3:0.25 B3:0.5 B3:0.5 B3:0.5 B3:0.5 B3:0.5 B3:0.5 B3:0.5 B3:0.25 B3:0.25"
DBR_LAST = "B3:0.5 A3 C4:0.5 B3 A3"
DBR_CHORUS = f"G3:0.5 A3:0.5 B3:0.5 B3:0.5 {DBR_STUDY} {DBR_LAST} G3:2 G3:0.5 A3:0.5 B3:0.5 B3:0.5 {DBR_STUDY} {DBR_LAST} G3:4"


def dbr_words(line):
    """A verse around one six-syllable line ("lay down my bur-den _")."""
    return (f"Gon-na {line} / down by the riv-er-side, / down by the riv-er-side, / down by the riv-er-side; / "
            f"gon-na {line} / down by the riv-er-side, / ain't gon-na stud-y war no more.")


DBR_STUDY_WORDS = "I ain't gon-na stud-y war no more,"
DBR_V = Part("Verse 1", "verse", DBR_VERSE, pickup=1, chords="G G D7 G G G D7 G", lyrics=dbr_words("lay down my bur-den _"))
DBR_C = Part("Chorus", "chorus", DBR_CHORUS, pickup=2, chords="C G D7 G C G D7 G", lyrics=(
    f"{DBR_STUDY_WORDS} / {DBR_STUDY_WORDS} / I ain't gon-na stud-y war no more _ / "
    f"{DBR_STUDY_WORDS} / {DBR_STUDY_WORDS} / I ain't gon-na stud-y war no more _"))
DBR_SONG = song(G, 92, [
    Part("Intro", "intro", f"{DBR_STUDY} {DBR_LAST} G3:4", chords="C G D7 G"),
    DBR_V, DBR_C,
    DBR_V.with_lyrics("Verse 2", dbr_words("lay down my sword and shield")),
    DBR_C,
    DBR_V.instrumental("Solo"),
    DBR_C,
    Part("Outro", "outro", f"G3:0.5 A3:0.5 B3:0.5 B3:0.5 {DBR_LAST} G3:4", pickup=2, chords="D7 G",
         lyrics="I ain't gon-na stud-y war no more. _"),
], shapes=SHAPES, words="Traditional spiritual (printed 1918)")

L_DBR = lesson("std-down-by-the-riverside", "Down by the Riverside", [
    explain("A song of peace", "This African American spiritual is older than the Civil War and was first printed in 1918. "
            "Its line ain't gonna study war no more became a song of the peace movement.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (3, 3, 3), (2, 0), (2, 1, 1)])),
    notes(G, ["B3", "D3", "E3", "G3", "A3", "B3"], hint="Lay down my burden: open B, a drop to open D, then up through E, G and A to B."),
    explain("The note in between", "A sharp sits between A and B, at fret 3 on string 3. It slides up into open B, "
            "the bluesy lift that gives gospel its sound.", fretboard(G, [(3, 2, 2), (3, 3, 3), (2, 0)])),
    notes(G, ["B3", "B3", "A#3", "B3", "A3", "G3"], hint="Down by the riverside: B, B, A sharp at fret 3, B, then A and G."),
    DBR_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    DBR_SONG.along("Chorus", bpm=72, title=THE_CHORUS),
    progression([(C, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)], QUARTERS, bpm=80),
    DBR_SONG.take("Down by the Riverside"),
], minutes=DBR_SONG.minutes(), xp=30, kind="song", arrangement=DBR_SONG.meta())

# ---------------------------------------------------------------- Loch Lomond
# Scottish traditional (first printed in Vocal Melodies of Scotland, 1841). G, 4/4.
LOCH_HALF = "G3 G3:0.5 A3:0.5 B3 A3:0.5 G3:0.5"
LOCH_END = "C4:0.5 B3:0.5 A3:0.5 G3:0.5 E3 D3:0.5 E3:0.5"
LOCH_VERSE = (f"{LOCH_HALF} A3 A3:0.5 G3:0.5 E3 D3:0.5 D3:0.5 G3 G3 G3 B3:0.5 D4:0.5 E4:2 D4 D4 "
              f"E4 E4:0.5 D4:0.5 B3 B3:0.5 D4:0.5 {LOCH_END} G3 B3:0.5 D4:0.5 E4 D4:0.5 B3:0.5 A3 A3 G3:2")
LOCH_CHORUS = (f"{LOCH_HALF} A3:0.5 B3:0.5 A3:0.5 G3:0.5 E3 D3:0.5 E3:0.5 G3 G3 G3 B3:0.5 D4:0.5 E4:2 D4 D4 "
               f"E4 G4:0.5 E4:0.5 D4 B3:0.5 D4:0.5 {LOCH_END} G3:0.5 G3:0.5 B3:0.5 D4:0.5 E4 D4:0.5 B3:0.5 A3:2 G3:2")
LOCH_CHORDS = "G Am,D7 G C,G C,G Am,Em G D7,G"
LOCH_V = Part("Verse", "verse", f"D3 {LOCH_VERSE}", pickup=1, chords=LOCH_CHORDS, lyrics=(
    "By yon bon-nie banks / and by yon bon-nie braes, / where the sun shines bright / on Loch Lo-mond, / "
    "where me and my true love / were ev-er wont to gae, / on the bon-nie, bon-nie banks / o' Loch Lo-mond."))
LOCH_C = Part("Chorus", "chorus", f"D3 {LOCH_CHORUS}", pickup=1, chords=LOCH_CHORDS, lyrics=(
    "O ye'll tak' the high road, / and I'll tak' the low road, / and I'll be in Scot-land a-fore ye, / "
    "but me and my true love will / nev-er meet a-gain / on the bon-nie, bon-nie banks / o' Loch Lo-mond."))
LOCH_SONG = song(G, 72, [
    Part("Intro", "intro", f"E4 G4:0.5 E4:0.5 D4 B3:0.5 D4:0.5 {LOCH_END} G3:0.5 G3:0.5 B3:0.5 D4:0.5 E4 D4:0.5 B3:0.5 A3:2 G3:2",
         chords="C,G Am,Em G D7,G"),
    LOCH_V, LOCH_C,
    LOCH_V.instrumental("Solo"),
    LOCH_C,
    Part("Outro", "outro", "E4 D4:0.5 B3:0.5 A3 A3 G3:4", chords="G,D7 G"),
], shapes=SHAPES, words="Traditional (printed 1841)")

L_LOCH = lesson("std-loch-lomond", "Loch Lomond", [
    explain("The high road and the low road", "This Scottish song was first printed in 1841. The low road is often heard as "
            "the road a soldier's spirit takes home, faster than the living on the high road.",
            fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 3, 3)])),
    notes(G, ["D3", "G3", "G3", "A3", "B3", "A3", "G3"], hint="By yon bonnie banks: open D, then G, G, A, B and back down to G."),
    explain("Quarters and pairs", "This tune moves in quarter notes and pairs of eighths. Count one, two-and, three, "
            "four-and, and the lilt comes by itself.", rhythm([0, 1, 1.5, 2, 3, 3.5])),
    tap([0, 1, 1.5, 2, 3, 3.5], bpm=66, bars=2),
    LOCH_SONG.along("Verse", bpm=60, title=THE_VERSE),
    LOCH_SONG.along("Chorus", bpm=60, title=THE_CHORUS),
    LOCH_SONG.take("Loch Lomond"),
], minutes=LOCH_SONG.minutes(), xp=30, kind="song", arrangement=LOCH_SONG.meta())

# ---------------------------------------------------------------- Molly Malone
# "Cockles and Mussels", printed 1876; credited to James Yorkston (1839–1906) in 1884. G, 3/4.
MOLLY_A = "G3 G3:1.5 G3:0.5 G3:0.5 B3:1.5 G3 A3 A3:1.5 A3:0.5"
MOLLY_CRY = "B3:0.5 D4:1.5 C4 B3:0.5 D4:1.5 C4 B3:1.5 G3:0.5 A3 G3:3"
MOLLY_VERSE = (f"D3 {MOLLY_A} A3:0.5 C4:1.5 A3 B3 A3 G3 D4 C4 B3 B3:0.5 A3:0.5 A3 A3 A3:2 D3:0.5 D3:0.5 "
               f"{MOLLY_A} A3:0.5 C4:1.5 A3:0.5 A3:0.5 {MOLLY_CRY}")
MOLLY_CHORUS = f"D3 G3:1.5 G3:0.5 G3 G3:0.5 B3:1.5 G3 A3:1.5 A3:0.5 A3 A3:0.5 C4:1.5 A3:0.5 A3:0.5 {MOLLY_CRY}"
MOLLY_CRY_WORDS = "cry-ing, Cock-les and mus-sels, / a-live, a-live, oh!"
MOLLY_V = Part("Verse 1", "verse", MOLLY_VERSE, pickup=1, chords="G G Am D7 G Em A7 D7 G G Am D7 G Em G,D7 G", lyrics=(
    "In Dub-lin's fair cit-y, / where the girls are so pret-ty, / I first set my eyes on / sweet Mol-ly Ma-lone, / "
    f"as she wheeled her wheel-bar-row / through streets broad and nar-row, / {MOLLY_CRY_WORDS}"))
MOLLY_C = Part("Chorus", "chorus", MOLLY_CHORUS, pickup=1, chords="G G Am D7 G Em G,D7 G", lyrics=(
    f"A-live, a-live, oh! _ / A-live, a-live, oh! _ / {MOLLY_CRY_WORDS}"))
MOLLY_SONG = song(G, 120, [
    Part("Intro", "intro", MOLLY_CRY, chords="G Em G,D7 G"),
    MOLLY_V, MOLLY_C,
    MOLLY_V.with_lyrics("Verse 2", "She was a fish-mon-ger, / but sure 'twas no won-der, _ / for so were her fa-ther / "
                                   f"and moth-er be-fore, / and they each wheeled their bar-row / through streets broad and nar-row, / {MOLLY_CRY_WORDS}"),
    MOLLY_C,
    MOLLY_V.with_lyrics("Verse 3", "She died of a fe-ver, / and no one could save her, _ / and that was the end of / "
                                   f"sweet Mol-ly Ma-lone; / now her ghost wheels her bar-row / through streets broad and nar-row, / {MOLLY_CRY_WORDS}"),
    MOLLY_C,
    Part("Outro", "outro", "C4 B3:1.5 G3:0.5 A3 G3:3", pickup=1, chords="G,D7 G", lyrics="a-live, a-live, oh!"),
], beats_per_bar=3, shapes=SHAPES, words="Traditional (printed 1876; James Yorkston, 1884)")

L_MOLLY = lesson("std-molly-malone", "Molly Malone", [
    explain("Dublin's own song", "This song was printed in 1876 and credited in 1884 to James Yorkston of Edinburgh. "
            "It is now Dublin's unofficial anthem, and Molly and her cart stand as a statue in the city.",
            fretboard(G, [(4, 0), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    notes(G, ["D3", "G3", "G3", "G3", "G3", "B3", "G3"], hint="In Dublin's fair city: open D, four open Gs, up to open B and back to G."),
    explain("A waltz in three", "Count one, two, three and lean on one. In many bars the middle note is long: "
            "one, two, and a quick note just before the next one.", rhythm([0, 1, 2.5], beats_per_bar=3)),
    tap([0, 1, 2.5], bpm=72, bars=2, beats_per_bar=3),
    MOLLY_SONG.along("Chorus", bpm=90, title=THE_CHORUS),
    MOLLY_SONG.along("Verse 1", bpm=96, title=THE_VERSE),
    progression([(G_MAJ, 2), (Am, 1), (D7, 1), (G_MAJ, 1), (Em, 1), (A7, 1), (D7, 1)], WALTZ, bpm=96, beats_per_bar=3),
    MOLLY_SONG.take("Molly Malone"),
], minutes=MOLLY_SONG.minutes(), xp=30, kind="song", arrangement=MOLLY_SONG.meta())

# ---------------------------------------------------------------- The Water Is Wide
# English ballad, the tune and words as Cecil Sharp (1859–1924) published them in Folk Songs from Somerset (1906). G, 4/4.
WATER_REST = ("D3:2 D3:0.5 G3:0.5 F#3 G3:2 G3:0.5 A3:0.5 B3 C4 A3:1.5 A3:0.5 B3:0.5 C4:0.5 "
              "D4:2 C4:0.5 B3:0.5 A3:0.5 G3:0.5 B3:2.5 A3:0.5 G3:0.5 E3:0.5 D3:2 E3:0.5 G3 F#3:0.5 G3:4")
WATER_V1 = Part("Verse 1", "verse", f"D3:0.5 G3:0.5 G3:0.5 A3:0.5 B3:2 A3:0.5 A3:0.5 G3:0.5 E3:0.5 {WATER_REST}", pickup=2,
                chords="G,C G,D C,G Am,D7 G,C G,Em G,D7 G", lyrics=(
                    "The wa-ter is wide, / I can-not get o'er, / and nei-ther have I / wings to fly; _ / give me a boat / "
                    "that will car-ry two, / and both shall row, / my love and I."))
WATER_SONG = song(G, 63, [
    Part("Intro", "intro", "D4:2 C4:0.5 B3:0.5 A3:0.5 G3:0.5 B3:2.5 A3:0.5 G3:0.5 E3:0.5 D3:2 E3:0.5 G3 F#3:0.5 G3:4",
         chords="G,C G,Em G,D7 G"),
    WATER_V1,
    Part("Verse 2", "verse", f"D3:0.5 G3:0.5 G3:0.5 A3:0.5 B3:2 A3:0.5 G3 E3:0.5 {WATER_REST}", pickup=2,
         chords="G,C G,D C,G Am,D7 G,C G,Em G,D7 G", lyrics=(
             "A ship there is / and she sails the sea, / she's load-ed deep / as deep can be; _ / but not so deep / "
             "as the love I'm in, / I know not if / I sink or swim.")),
    WATER_V1.instrumental("Solo"),
    Part("Outro", "outro", "A3:0.5 G3:0.5 E3:0.5 D3:2 E3:0.5 G3 F#3:0.5 G3:4", pickup=1.5, chords="G,D7 G",
         lyrics="and both shall row, / my love and I."),
], shapes=SHAPES, words="Traditional (Cecil Sharp, 1906)")

L_WATER = lesson("std-the-water-is-wide", "The Water Is Wide", [
    explain("An old English ballad", "Cecil Sharp collected and published this ballad in 1906, from verses that go back to "
            "the 1700s. Play it slowly and let every long note ring.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    notes(G, ["D3", "G3", "G3", "A3", "B3", "A3", "A3", "G3", "E3", "D3"],
          hint="The water is wide, I cannot get o'er: up from open D to B, then gently back down to D."),
    explain("Count through long notes", "Wide rings for two beats and two for two and a half. Keep counting while the "
            "string rings, so the next word lands on time."),
    WATER_SONG.along("Verse 1", bpm=56, title=THE_VERSE),
    quiz("Which word holds over two notes in the first verse?", ["Fly", "Wide", "Boat"], 0,
         "Fly starts on C and slides down to a long A. Singers call one syllable over several notes a melisma."),
    progression([(G_MAJ, 2), (C, 1), (Am, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)], HALVES, bpm=66),
    WATER_SONG.take("The Water Is Wide"),
], minutes=WATER_SONG.minutes(), xp=30, kind="song", arrangement=WATER_SONG.meta())

L_MEDLEY_1 = lesson("std-medley-campfire", "Campfire medley", [
    explain("Around the fire", "No new notes: the five songs from this unit, one after another, a little faster than before. "
            "Name each one from its first notes."),
    listen("Which song starts like this?", [["D3"], ["E3"], ["G3"], ["G3"], ["G3"], ["G3"]],
           ["She'll Be Coming 'Round the Mountain", "Loch Lomond", "Molly Malone"], 0),
    SHE_SONG.along("Verse 1", bpm=104, title="She'll Be Coming 'Round the Mountain"),
    DBR_SONG.along("Chorus", bpm=96, title="Down by the Riverside"),
    listen("Which song starts like this?", [["D3"], ["G3"], ["G3"], ["A3"], ["B3"]],
           ["Molly Malone", "Loch Lomond", "Down by the Riverside"], 1),
    LOCH_SONG.along("Chorus", bpm=76, title="Loch Lomond"),
    MOLLY_SONG.along("Chorus", bpm=126, title="Molly Malone"),
    WATER_SONG.along("Verse 1", bpm=66, title="The Water Is Wide"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ 2. Ballads and carols

# ---------------------------------------------------------------- All Through the Night
# Welsh air "Ar Hyd y Nos" (Edward Jones, Relicks of the Welsh Bards, 1784); English words Harold Boulton (1884). G, 4/4.
NIGHT_A = "G3:1.5 F#3:0.5 E3 G3 A3:1.5 G3:0.5 F#3 D3 E3:2 F#3:1.5 F#3:0.5 G3:4"
NIGHT_B = "C4 B3 C4 D4 E4 D4 C4 B3 C4 B3 A3 G3 B3 A3 G3 F#3"
NIGHT_A_CHORDS = "G D C,D G"
NIGHT_B_CHORDS = "C C,G Am,G G,D"
NIGHT_V = Part("Verse 1", "verse", f"{NIGHT_A} {NIGHT_A} {NIGHT_B} {NIGHT_A}",
               chords=f"{NIGHT_A_CHORDS} {NIGHT_A_CHORDS} {NIGHT_B_CHORDS} {NIGHT_A_CHORDS}", lyrics=(
                   "Sleep, my child, and peace at-tend thee, / all through the night; / guard-ian an-gels God will send thee, / "
                   "all through the night. / Soft the drow-sy hours are creep-ing, / hill and vale in slum-ber steep-ing, / "
                   "I my lov-ing vig-il keep-ing / all through the night."))
NIGHT_SONG = song(G, 76, [
    Part("Intro", "intro", NIGHT_A, chords=NIGHT_A_CHORDS),
    NIGHT_V,
    Part("Solo", "solo", f"{NIGHT_B} {NIGHT_A}", chords=f"{NIGHT_B_CHORDS} {NIGHT_A_CHORDS}"),
    NIGHT_V.with_lyrics("Verse 2", "While the moon her watch is keep-ing / all through the night, / while the wea-ry world is sleep-ing / "
                                   "all through the night, / o'er thy spir-it gent-ly steal-ing, / vis-ions of de-light re-veal-ing, / "
                                   "breathes a pure and ho-ly feel-ing / all through the night."),
    Part("Outro", "outro", "E3:2 F#3:1.5 F#3:0.5 G3:4", chords="C,D G", lyrics="all through the night."),
], shapes=SHAPES, words="Harold Boulton (1884)")

L_NIGHT = lesson("std-all-through-the-night", "All Through the Night", [
    explain("A Welsh lullaby", "The tune Ar Hyd y Nos was printed in Wales in 1784, and Harold Boulton wrote these English "
            "words in 1884. One phrase comes three times, with a higher one in the middle.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
    notes(G, ["G3", "F#3", "E3", "G3", "A3", "G3", "F#3", "D3"],
          hint="Sleep, my child, and peace attend thee: open G, down to F sharp and E, then G, A, G, F sharp and D."),
    quiz("Which phrase of the verse climbs highest?", ["The third", "The first", "The last"], 0,
         "The third phrase, soft the drowsy hours, rises to C, D and E. The other three phrases share one tune."),
    NIGHT_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
    progression([(G_MAJ, 1), (D, 1), (C, 1), (G_MAJ, 1)], HALVES, bpm=72),
    NIGHT_SONG.take("All Through the Night"),
], minutes=NIGHT_SONG.minutes(), xp=30, kind="song", arrangement=NIGHT_SONG.meta())

# ---------------------------------------------------------------- The Skye Boat Song
# Words Sir Harold Boulton (1859–1935), tune collected by Anne Campbell MacLeod (1855–1921), Songs of the North (1884).
# G, 6/8 counted in eighths.
SKYE_SPEED = "D3:1.5 E3:0.5 D3 G3:2"
SKYE_CHORUS = (f"{SKYE_SPEED} G3:0.5 G3:0.5 A3:1.5 B3:0.5 A3 D4:3 B3:1.5 A3:0.5 B3 E3:2 E3 D3:6 "
               f"{SKYE_SPEED} G3 A3:1.5 B3:0.5 A3 D4:3 B3:1.5 A3:0.5 B3 E3:2 E3 D3:6")
SKYE_LOUD = "B3:1.5 G3:0.5 B3 B3:3 A3:1.5 F#3:0.5 A3 A3:3 G3:1.5 E3:0.5 G3 G3:2 G3"
SKYE_VERSE = f"{SKYE_LOUD} E3:6 {SKYE_LOUD} E3:3 D3:3"
SKYE_C = Part("Chorus", "chorus", SKYE_CHORUS, chords="G,Em Am,D7 G,Em D,D7 G,Em Am,D7 G,Em D,D7", lyrics=(
    "Speed, bon-nie boat, like a bird on the wing, / On-ward! the sail-ors cry; / Car-ry the lad that's born to be King / "
    "o-ver the sea to Skye."))
SKYE_V = Part("Verse 1", "verse", SKYE_VERSE, chords="G D Em,C Am,D7 G D Em,C Am,D7", lyrics=(
    "Loud the winds howl, loud the waves roar, / thun-der-claps rend the air; / baf-fled, our foes stand by the shore, / "
    "fol-low they will not dare. _"))
SKYE_SONG = song(G, 144, [
    Part("Intro", "intro", f"{SKYE_SPEED} G3 A3:1.5 B3:0.5 A3 D4:3 B3:1.5 A3:0.5 B3 E3:2 E3 D3:6", chords="G,Em Am,D7 G,Em D,D7"),
    SKYE_C, SKYE_V, SKYE_C,
    SKYE_V.with_lyrics("Verse 2", "Though the waves leap, soft shall ye sleep, / O-cean's a roy-al bed; / rocked in the deep, "
                                  "Flo-ra will keep / watch by your wea-ry head. _"),
    SKYE_C,
    Part("Outro", "outro", "B3:1.5 A3:0.5 B3 E3:2 E3 D3:6", chords="G,Em D", lyrics="o-ver the sea to Skye."),
], beats_per_bar=6, shapes=SHAPES, words="Sir Harold Boulton (1884)")

L_SKYE = lesson("std-skye-boat-song", "The Skye Boat Song", [
    explain("Over the sea to Skye", "Harold Boulton set these words in 1884 to a Highland rowing tune collected by Anne "
            "MacLeod. They tell of Bonnie Prince Charlie escaping to the Isle of Skye in 1746.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 3, 3)])),
    explain("Six-eight time", "This song rocks in six-eight: two big beats a bar, each split in three. Count one-two-three, "
            "four-five-six, like oars pulling and coming back.", rhythm(SIX, beats_per_bar=6)),
    tap([0, 1.5, 2, 3], bpm=120, bars=2, beats_per_bar=6),
    notes(G, ["D3", "E3", "D3", "G3", "G3", "G3", "A3", "B3", "A3", "D4"],
          hint="Speed, bonnie boat, like a bird on the wing: open D, E, D, three open Gs, then A, B, A and up to D."),
    SKYE_SONG.along("Chorus", bpm=120, title=THE_CHORUS),
    SKYE_SONG.along("Verse 1", bpm=120, title=THE_VERSE),
    SKYE_SONG.take("The Skye Boat Song"),
], minutes=SKYE_SONG.minutes(), xp=30, kind="song", arrangement=SKYE_SONG.meta())

# ---------------------------------------------------------------- O Christmas Tree (O Tannenbaum)
# Words Ernst Anschütz (Leipzig, 1824), to a traditional German folk tune. G, 3/4, sung in German.
TANNE_A = "G3:0.75 G3:0.25 G3:1.5 A3:0.5 B3:0.75 B3:0.25 B3:1.5 B3:0.5 A3:0.5 B3:0.5 C4 F#3"
TANNE_TUNE = f"D3 {TANNE_A} A3 G3 D4:0.5 D4:0.5 B3 E4:1.5 D4:0.5 D4:0.5 C4:0.5 C4:1.5 C4:0.5 C4:0.5 A3:0.5 D4:1.5 C4:0.5 C4:0.5 B3:0.5 B3 D3 {TANNE_A} A3 G3:2"
TANNE_CHORDS = "G G Am,D7 G Em D7 D7 G G G Am,D7 G"
TANNE_V = Part("Verse 1", "verse", TANNE_TUNE, pickup=1, chords=TANNE_CHORDS, lyrics=(
    "O Tan-nen-baum, o Tan-nen-baum, / wie treu sind dei-ne Blät-ter! / Du grünst nicht nur zur Som-mer-zeit, / "
    "nein auch im Win-ter, wenn es schneit. / O Tan-nen-baum, o Tan-nen-baum, / wie treu sind dei-ne Blät-ter!"))
TANNE_SONG = song(G, 92, [
    Part("Intro", "intro", f"{TANNE_A} A3 G3:2", chords="G G Am,D7 G"),
    TANNE_V,
    TANNE_V.with_lyrics("Verse 2", "O Tan-nen-baum, o Tan-nen-baum, / du kannst mir sehr ge-fal-len! / Wie oft hat nicht zur "
                                   "Weih-nachts-zeit / ein Baum von dir mich hoch er-freut! / O Tan-nen-baum, o Tan-nen-baum, / "
                                   "du kannst mir sehr ge-fal-len!"),
    TANNE_V.instrumental("Solo"),
    TANNE_V.with_lyrics("Verse 3", "O Tan-nen-baum, o Tan-nen-baum, / dein Kleid will mich was leh-ren: / die Hoff-nung und "
                                   "Be-stän-dig-keit / gibt Mut und Kraft zu je-der Zeit! / O Tan-nen-baum, o Tan-nen-baum, / "
                                   "dein Kleid will mich was leh-ren!"),
    Part("Outro", "outro", "A3:0.5 B3:0.5 C4 F#3 A3 G3:2", chords="Am,D7 G"),
], beats_per_bar=3, shapes=SHAPES, words="Ernst Anschütz (1824)")

L_TANNE = lesson("std-o-christmas-tree", "O Christmas Tree", [
    explain("A German carol from 1824", "Ernst Anschütz wrote these words in Leipzig in 1824, to a much older folk tune. "
            "You'll sing them in German, the language they were written in.",
            fretboard(G, [(4, 0), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
    notes(G, ["D3", "G3", "G3", "G3", "A3", "B3", "B3", "B3"],
          hint="O Tannenbaum, o Tannenbaum: open D, three open Gs, then A at fret 2 and three open Bs."),
    explain("Long, short, long", "Tan-nen is a dotted note and a very short one, then baum rings on. Say the words as "
            "you tap, and the rhythm follows.", rhythm([0, 0.75, 1, 2.5], beats_per_bar=3)),
    tap([0, 0.75, 1, 2.5], bpm=66, bars=2, beats_per_bar=3),
    TANNE_SONG.along("Verse 1", bpm=76, title=THE_VERSE),
    progression([(G_MAJ, 2), (Am, 1), (G_MAJ, 1), (Em, 1), (D7, 2), (G_MAJ, 1)], WALTZ, bpm=84, beats_per_bar=3),
    TANNE_SONG.take("O Christmas Tree"),
], minutes=TANNE_SONG.minutes(), xp=30, kind="song", arrangement=TANNE_SONG.meta())

# ---------------------------------------------------------------- O Come, All Ye Faithful (Adeste Fideles)
# Latin hymn and tune, J. F. Wade's Cantus Diversi (1751); English words Frederick Oakeley (1841). G, 4/4.
FAITH_ADORE = "G3 F#3 G3 A3 G3:2 D3 B3 B3 A3 B3 C4 B3:2 A3 B3 C4 B3 A3 G3 F#3:2 G3 C4 B3:2 A3:1.5 G3:0.5 G3:4"
FAITH_TUNE = ("G3 G3:2 D3 G3 A3:2 D3:2 B3 A3 B3 C4 B3:2 A3 G3 G3:2 F#3 E3 F#3 G3 A3 B3 F#3:2 E3:1.5 D3:0.5 D3:4 "
              f"D4:2 C4 B3 C4:2 B3:2 A3 B3 G3 A3 F#3:1.5 E3:0.5 D3 G3 {FAITH_ADORE}")
FAITH_CHORDS = "G D G,C G,D Em,D D D,A7 D G D7,G Am,D D,G G G G,C G,D C,G D,C G,D7 G"
FAITH_V = Part("Verse 1", "verse", FAITH_TUNE, pickup=1, chords=FAITH_CHORDS, lyrics=(
    "O come, all ye faith-ful, / joy-ful and tri-um-phant, / O come ye, O come ye to Beth-le-hem; _ _ / "
    "come and be-hold him, / born the King of an- _ gels; / O come, let us a-dore him, / O come, let us a-dore him, / "
    "O come, let us a-dore him, / Christ the Lord. _ _"))
FAITH_SONG = song(G, 84, [
    Part("Intro", "intro", "C4 B3 A3 G3 F#3:2 G3 C4 B3:2 A3:1.5 G3:0.5 G3:4", chords="C,G D,C G,D7 G"),
    FAITH_V,
    FAITH_V.with_lyrics("Verse 2", "A-des-te fi-de-les, / lae-ti tri-um-phan-tes, / ve-ni-te, ve-ni-te in Beth-le-hem; _ _ / "
                                   "na-tum vi-de-te / Re-gem an-ge-lo- _ rum: / ve-ni-te a-do-re-mus, / ve-ni-te a-do-re-mus, / "
                                   "ve-ni-te a-do-re-mus / Do-mi-num. _ _"),
    Part("Outro", "outro", "B3 C4 B3 A3 G3 F#3:2 G3 C4 B3:2 A3:1.5 G3:0.5 G3:4", pickup=1, chords="C,G D,C G,D7 G",
         lyrics="O come, let us a-dore him, / Christ the Lord. _ _"),
], shapes=SHAPES, words="Latin hymn (1751); English words Frederick Oakeley (1841)")

L_FAITH = lesson("std-o-come-all-ye-faithful", "O Come, All Ye Faithful", [
    explain("Latin and English", "The Latin hymn Adeste Fideles was printed with this tune in 1751, and Frederick Oakeley's "
            "English words followed in 1841. You'll sing a verse in each language.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
    notes(G, ["G3", "G3", "D3", "G3", "A3", "D3"], hint="O come, all ye faithful: open G twice, down to open D, back to G, A, and D again."),
    FAITH_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    quiz("How many times does the refrain sing O come, let us adore him?", ["Three", "One", "Two"], 0,
         "Three times, each a little higher, before Christ the Lord brings the tune home."),
    progression([(G_MAJ, 1), (D, 1), (G_MAJ, 1), (C, 1), (D, 2), (A7, 1), (D, 1)], HALVES, bpm=76),
    FAITH_SONG.take("O Come, All Ye Faithful"),
], minutes=FAITH_SONG.minutes(), xp=35, kind="song", arrangement=FAITH_SONG.meta())

# ---------------------------------------------------------------- The First Noel (instrumental)
# English carol (first printed in William Sandys' Christmas Carols Ancient and Modern, 1823). D, 3/4.
NOEL_LINE = "D3:1.5 E3:0.5 F#3:0.5 G3:0.5 A3:2 B3:0.5 C#4:0.5 D4 C#4 B3"
NOEL_HALF = f"{NOEL_LINE} A3:2 B3:0.5 C#4:0.5 D4 C#4 B3 A3 B3 C#4 D4 A3 G3"
NOEL_VERSE = f"F#3:0.5 E3:0.5 {NOEL_HALF} F#3:2 F#3:0.5 E3:0.5 {NOEL_HALF} F#3:3"
NOEL_REFRAIN = "F#3:0.5 E3:0.5 D3:1.5 E3:0.5 F#3:0.5 G3:0.5 A3:2 D4:0.5 C#4:0.5 B3:2 B3 A3:2 A3 D4 C#4 B3 A3 B3 C#4 D4 A3 G3 F#3:3"
NOEL_HALF_CHORDS = "D D,A D,G D,A D,G D,A D,A7 D"
NOEL_SONG = song(G, 104, [
    Part("Intro", "intro", "D4 C#4 B3 A3 B3 C#4 D4 A3 G3 F#3:3", chords="D,G A D,A7 D"),
    Part("Verse", "verse", NOEL_VERSE, pickup=1, chords=f"{NOEL_HALF_CHORDS} {NOEL_HALF_CHORDS}"),
    Part("Refrain", "chorus", NOEL_REFRAIN, pickup=1, chords="D D,A G D D,G D,A D,A7 D"),
    Part("Verse 2", "verse", NOEL_VERSE, pickup=1, chords=f"{NOEL_HALF_CHORDS} {NOEL_HALF_CHORDS}"),
    Part("Refrain", "chorus", NOEL_REFRAIN, pickup=1, chords="D D,A G D D,G D,A D,A7 D"),
    Part("Outro", "outro", "A3 B3 C#4 D4:3", chords="A D"),
], beats_per_bar=3, shapes=SHAPES)

L_NOEL = lesson("std-the-first-noel", "The First Noel", [
    explain("A carol from Cornwall", "This carol was first printed in 1823, in a collection of old Christmas carols. "
            "Its tune walks up the scale and back, which is why it is so easy to remember.",
            fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 2, 2), (2, 3, 3)])),
    notes(G, ["F#3", "E3", "D3", "E3", "F#3", "G3", "A3", "B3", "C#4", "D4"],
          hint="Up the D scale: F sharp and E, open D, then E, F sharp, open G, A, open B, C sharp at fret 2 and D."),
    explain("Two quick notes first", "The tune starts with two quick notes, F sharp and E, before beat one. Then a long D "
            "and a run of eighths climb to A.", rhythm([0, 1.5, 2, 2.5], beats_per_bar=3)),
    tap([0, 1.5, 2, 2.5], bpm=72, bars=2, beats_per_bar=3),
    NOEL_SONG.along("Verse", bpm=84, title=THE_VERSE),
    NOEL_SONG.along("Refrain", bpm=84, title="The refrain"),
    progression([(D, 1), (A_MAJ, 1), (G_MAJ, 1), (D, 1)], WALTZ, bpm=88, beats_per_bar=3),
    NOEL_SONG.take("The First Noel"),
], minutes=NOEL_SONG.minutes(), xp=30, kind="song", arrangement=NOEL_SONG.meta())

L_MEDLEY_2 = lesson("std-medley-ballads", "Ballads and carols medley", [
    explain("A winter evening", "Five songs from this unit: two ballads and three carols. No new notes, just one after "
            "another, each a little faster than before."),
    listen("Which song starts like this?", [["G3"], ["F#3"], ["E3"], ["G3"], ["A3"], ["G3"], ["F#3"], ["D3"]],
           ["All Through the Night", "O Come, All Ye Faithful", "The First Noel"], 0),
    NIGHT_SONG.along("Verse 1", bpm=80, title="All Through the Night"),
    SKYE_SONG.along("Chorus", bpm=152, title="The Skye Boat Song"),
    TANNE_SONG.along("Verse 1", bpm=96, title="O Christmas Tree"),
    quiz("Which of these counts in six?", ["The Skye Boat Song", "O Christmas Tree", "All Through the Night"], 0,
         "The Skye Boat Song rocks in six-eight. O Christmas Tree is in three, and All Through the Night in four."),
    FAITH_SONG.along("Verse 1", bpm=88, title="O Come, All Ye Faithful"),
    NOEL_SONG.along("Verse", bpm=108, title="The First Noel"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ 3. Pipes, waltzes and dances

# ---------------------------------------------------------------- Scotland the Brave
# Traditional pipe march (printed by 1878; Scottish printing 1891). D, 4/4. Played as an instrumental: the words
# usually sung to it date from about 1950 and are not used.
BRAVE_1 = "D3 D3:0.75 E3:0.25 F#3:0.5 D3:0.5 F#3:0.5 A3:0.5"
BRAVE_2 = "D4 D4:0.75 C#4:0.25 D4:0.5 A3:0.5 F#3:0.5 D3:0.5"
BRAVE_3 = "G3 B3:0.75 G3:0.25 F#3:0.25 A3:0.75 F#3:0.5 D3:0.5"
BRAVE_TURN = "E3 A3:0.75 B3:0.25 A3:0.5 G3:0.5 F#3:0.5 E3:0.5"
BRAVE_HOME = "E3 D3:0.75 C#3:0.25 D3 r:1"
BRAVE_A = f"{BRAVE_1} {BRAVE_2} {BRAVE_3} {BRAVE_TURN} {BRAVE_1} {BRAVE_2} {BRAVE_3} {BRAVE_HOME}"
BRAVE_B = ("E4 E4:0.75 D#4:0.25 E4:0.5 C#4:0.5 A3:0.5 C#4:0.5 D4 F#4:0.75 E4:0.25 D4:0.5 C#4:0.5 B3:0.5 A3:0.5 "
           "D4 D4:0.75 D4:0.25 C#4 C#4:0.75 C#4:0.25 B3:0.5 D4:0.5 C#4:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 E3:0.5 "
           f"{BRAVE_1} {BRAVE_2} {BRAVE_3} {BRAVE_HOME}")
BRAVE_PA = Part("Part A", "verse", BRAVE_A, chords="D D G,D A7 D D G,D A7,D")
BRAVE_PB = Part("Part B", "chorus", BRAVE_B, chords="A D G,A E7,A7 D D G,D A7,D")
BRAVE_SONG = song(G, 80, [
    Part("Intro", "intro", "A2 D3 F#3 A3 D4:2 r:2", chords="A7 D"),
    BRAVE_PA, BRAVE_PB, BRAVE_PA, BRAVE_PB,
    Part("Outro", "outro", f"{BRAVE_1} D4:4", chords="D D"),
], shapes=SHAPES)

L_BRAVE = lesson("std-scotland-the-brave", "Scotland the Brave", [
    explain("A pipe-band favorite", "This Scottish march was in print by 1878, and pipe bands play it all over the world. "
            "Pipers play it without words, and so will you.",
            fretboard(G, [(5, 4, 4), (4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 2, 2), (2, 3, 3)])),
    explain("A marching snap", "A dotted note and a quick one give a march its snap: long, then short. In the first bar, "
            "the second D is long and E slips in just before beat two.", rhythm([0, 1, 1.75, 2, 2.5, 3, 3.5])),
    tap([0, 1, 1.75, 2, 2.5, 3, 3.5], bpm=60, bars=2),
    notes(G, ["D3", "D3", "E3", "F#3", "D3", "F#3", "A3", "D4"], hint="Up the D chord: open D twice, E, F sharp at fret 4, D, F sharp, A, then D on string 2."),
    BRAVE_SONG.along("Part A", bpm=60, title="The first part"),
    BRAVE_SONG.along("Part B", bpm=60, title="The second part"),
    BRAVE_SONG.take("Scotland the Brave"),
], minutes=BRAVE_SONG.minutes(), xp=30, kind="song", arrangement=BRAVE_SONG.meta())

# ---------------------------------------------------------------- Korobeiniki
# Russian folk tune to Nikolay Nekrasov's poem (1861), published 1898. E minor, 4/4. Only the folk melody is used.
KORO_A = "B3 F#3:0.5 G3:0.5 A3 G3:0.5 F#3:0.5 E3 E3:0.5 G3:0.5 B3 A3:0.5 G3:0.5 F#3:1.5 G3:0.5 A3 B3 G3 E3 E3 r"
KORO_B = "r:0.5 A3 C4:0.5 E4 D4:0.5 C4:0.5 B3:1.5 G3:0.5 B3 A3:0.5 G3:0.5 F#3 F#3:0.5 G3:0.5 A3 B3 G3 E3 E3 r"
KORO = f"{KORO_A} {KORO_B}"
KORO_CHORDS = "Em Em B7 Em Am G B7 Em"


def doubled_quarters(melody):
    """Every quarter note as two eighths (a down-up pick); other lengths stay."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        if float(length or 1) == 1 and n.lower() != "r":
            out += [f"{n}:0.5", f"{n}:0.5"]
        else:
            out.append(token)
    return " ".join(out)


KORO_SONG = song(G, 96, [
    Part("Intro", "intro", "E2 B2 E3 B2 E2 B2 E3 B2 A2 E3 C3 E3 B2 F#3 D#3 B2", chords="Em Em Am B7"),
    Part("Theme", "verse", KORO, chords=KORO_CHORDS),
    Part("Theme low", "verse", transpose(KORO, -12), chords=KORO_CHORDS),
    Part("Variation", "solo", doubled_quarters(KORO), chords=KORO_CHORDS),
    Part("Theme again", "chorus", KORO, chords=KORO_CHORDS),
    Part("Coda", "outro", "B3 F#3:0.5 G3:0.5 A3 B3 G3 E3 E3:2", chords="B7 Em"),
], shapes=SHAPES)

L_KORO = lesson("std-korobeiniki", "Korobeiniki", [
    explain("The peddlers' song", "Nikolay Nekrasov's poem about traveling peddlers was printed in 1861, and this folk tune "
            "was published with it in 1898. A video game made it famous worldwide almost a century later.",
            fretboard(G, [(4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
    notes(G, ["B3", "F#3", "G3", "A3", "G3", "F#3", "E3"], hint="The opening: open B, down to F sharp at fret 4 on string 4, up G and A, then G, F sharp, E."),
    notes(G, ["A3", "C4", "E4", "D4", "C4", "B3", "G3"], hint="The second half reaches higher: A, C at fret 1 on string 2, open E, then down D, C, B and G."),
    KORO_SONG.along("Theme", bpm=80, title=THE_THEME),
    quiz("This tune is in E minor. Which note sounds like home?", ["E", "B", "A"], 0,
         "Both halves end on E, the home note of E minor. You hear it as the place the tune settles."),
    progression([(Em, 2), (B7, 1), (Em, 1), (Am, 1), (G_MAJ, 1), (B7, 1), (Em, 1)], QUARTERS, bpm=88),
    KORO_SONG.take("Korobeiniki"),
], minutes=KORO_SONG.minutes(), xp=35, kind="song", arrangement=KORO_SONG.meta())

# ---------------------------------------------------------------- The Blue Danube
# Johann Strauss II (1825–1899), first performed 1867; the main waltz, as in the Mutopia piano edition. G, 3/4.
DANUBE_1 = ("G2 B2 D3 D3:2 D4 D4:2 B3 B3:2 G2 G2 B2 D3 D3:2 D4 D4:2 C4 C4:2 F#2 F#2 A2 E3 E3:2 E4 E4:2 C4 C4:2 F#2 "
            "F#2 A2 E3 E3:2 E4 E4:2 B3 B3:2 G2")
DANUBE_2 = "G2 B2 D3 G3:2 G4 G4:2 D4 D4:2 G2 G2 B2 D3 G3:2 G4 G4:2 E4 E4:2 A2 A2 C3 E3 E3:4 C#3 D3 B3:4 G3 B2 B2:2 A2 E3:2 D3 G3:3"
DANUBE_CHORDS = "G G G G G G D7 D7 D7 D7 D7 D7 D7 D7 D7,G G G G G G G G G,E7 Am Am Am A7,D G G G,D7 D7 G"
DANUBE_WALTZ = Part("Waltz", "verse", f"G2 {DANUBE_1} {DANUBE_2}", pickup=1, chords=DANUBE_CHORDS)
DANUBE_SONG = song(G, 116, [
    Part("Intro", "intro", "G2 B2 D3 G2 B2 D3 A2 C3 D3 A2 C3:2", chords="G G D7 D7"),
    DANUBE_WALTZ,
    DANUBE_WALTZ.instrumental("Waltz again", kind="chorus"),
    Part("Coda", "outro", "D3 B2 G2 C3 A2 F#2 B2 D3 G3 G2:3", chords="G D7 G G"),
], beats_per_bar=3, shapes=SHAPES)

L_DANUBE = lesson("std-blue-danube", "The Blue Danube", [
    explain("The waltz of waltzes", "Johann Strauss II first performed this waltz in Vienna in 1867, and Vienna still plays "
            "it every New Year's Day. Its tune climbs a chord, then answers with two high notes.",
            fretboard(G, [(6, 2, 2), (6, 3, 3), (5, 0), (5, 2, 2), (4, 0), (3, 0), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
    notes(G, ["G2", "G2", "B2", "D3", "D3", "D4", "D4", "B3", "B3"],
          hint="G at fret 3 on string 6 twice, B on string 5, open D, then leap up to D at fret 3 on string 2 and down to open B."),
    explain("From string 6 to string 2", "Each phrase starts low on the bass strings and leaps up an octave. Look at the "
            "high note before you play the low ones, so your hand knows where it's going.",
            fretboard(G, [(6, 3, 3), (4, 0), (2, 3, 3)])),
    tap(WALTZ, bpm=96, bars=2, beats_per_bar=3),
    DANUBE_SONG.along("Waltz", bpm=96, title="The waltz"),
    progression([(G_MAJ, 6), (D7, 9), (G_MAJ, 1)], WALTZ, bpm=108, beats_per_bar=3),
    DANUBE_SONG.take("The Blue Danube"),
], minutes=DANUBE_SONG.minutes(), xp=35, kind="song", arrangement=DANUBE_SONG.meta())

# ---------------------------------------------------------------- Can-can
# The Galop infernal from Jacques Offenbach's Orpheus in the Underworld (1858). G, 4/4.
CAN_RUN = "G3:2 A3:0.5 C4:0.5 B3:0.5 A3:0.5 D4 D4 D4:0.5 E4:0.5 B3:0.5 C4:0.5 A3 A3 A3:0.5 C4:0.5 B3:0.5 A3:0.5"
CAN_THEME = (f"{CAN_RUN} G3:0.5 G4:0.5 F#4:0.5 E4:0.5 D4:0.5 C4:0.5 B3:0.5 A3:0.5 "
             f"{CAN_RUN} G3:0.5 D4:0.5 A3:0.5 B3:0.5 G3:2")
CAN_CHORDS = "G,D7 G D7 G,D7 G,D7 G D7 G"
CAN_SONG = song(G, 100, [
    Part("Intro", "intro", "D4 r:1 D4 r:1 D4 r:1 D4 r:1 D4:0.5 E4:0.5 F#4:0.5 G4:0.5 F#4:2 D4:4", chords="D7 D7 D7 D7"),
    Part("Theme", "verse", CAN_THEME, chords=CAN_CHORDS),
    Part("Theme again", "chorus", CAN_THEME, chords=CAN_CHORDS),
    Part("Low theme", "solo", transpose(CAN_THEME, -12), chords=CAN_CHORDS),
    Part("Last theme", "chorus", CAN_THEME, chords=CAN_CHORDS),
    Part("Coda", "outro", "G3:0.5 D4:0.5 A3:0.5 B3:0.5 G3:2 D4 r:1 G2:2", chords="G D7,G"),
], shapes=SHAPES)

L_CAN = lesson("std-can-can", "Can-can", [
    explain("A galop from the underworld", "Jacques Offenbach wrote this galop for his 1858 operetta Orpheus in the "
            "Underworld. Paris dance halls later made it the music of the can-can.",
            fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
    notes(G, ["G3", "A3", "C4", "B3", "A3", "D4", "D4"], hint="A long open G, then A, C, B, A, and two Ds at fret 3 on string 2."),
    explain("Fast and light", "Most of the tune runs in eighth notes. Keep the pick small and alternate down and up, "
            "so you never fall behind.", rhythm([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])),
    tap([0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5], bpm=80, bars=2),
    notes(G, ["G3", "G4", "F#4", "E4", "D4", "C4", "B3", "A3"], hint="The big run: open G, leap to G at fret 3 on string 1, then step all the way down to A."),
    CAN_SONG.along("Theme", bpm=84, title=THE_THEME),
    CAN_SONG.take("Can-can"),
], minutes=CAN_SONG.minutes(), xp=35, kind="song", arrangement=CAN_SONG.meta())

L_MEDLEY_3 = lesson("std-medley-dances", "Dance hall medley", [
    explain("From the pipes to Paris", "Four tunes from this unit: a pipe march, a Russian folk song, a Viennese waltz "
            "and a French galop. Each one a little faster than before."),
    listen("Which tune starts like this?", [["B3"], ["F#3"], ["G3"], ["A3"], ["G3"], ["F#3"], ["E3"]],
           ["Korobeiniki", "Can-can", "Scotland the Brave"], 0),
    BRAVE_SONG.along("Part A", bpm=72, title="Scotland the Brave"),
    KORO_SONG.along("Theme", bpm=96, title="Korobeiniki"),
    quiz("Which of these is a waltz, in three?", ["The Blue Danube", "Can-can", "Scotland the Brave"], 0,
         "A waltz counts one, two, three. The can-can and the pipe march both count in four."),
    DANUBE_SONG.along("Waltz", bpm=108, title="The Blue Danube"),
    CAN_SONG.along("Theme", bpm=96, title="Can-can"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ 4. Ragtime, marches and the stage

# ---------------------------------------------------------------- The Entertainer
# Scott Joplin (1868–1917), published 1902. The first strain, as in the Mutopia edition, two octaves down and in
# doubled note values (a sixteenth there is an eighth here). C, 4/4.
ENT_HALF = "E3:0.5 C4 E3:0.5 C4 E3:0.5"
ENT_THEME = (f"D3:0.5 D#3:0.5 {ENT_HALF} C4:3 C4:0.5 D4:0.5 D#4:0.5 E4:0.5 C4:0.5 D4:0.5 E4 B3:0.5 D4 C4:3 "
             f"D3:0.5 D#3:0.5 {ENT_HALF} C4:3.5 A3:0.5 G3:0.5 F#3:0.5 A3:0.5 C4:0.5 E4 D4:0.5 C4:0.5 A3:0.5 D4:3 "
             f"D3:0.5 D#3:0.5 {ENT_HALF} C4:3 C4:0.5 D4:0.5 D#4:0.5 E4:0.5 C4:0.5 D4:0.5 E4 B3:0.5 D4 C4:3 C4:0.5 D4:0.5 "
             "E4:0.5 C4:0.5 D4:0.5 E4 C4:0.5 D4:0.5 C4:0.5 E4:0.5 C4:0.5 D4:0.5 E4 C4:0.5 D4:0.5 C4:0.5 "
             "E4:0.5 C4:0.5 D4:0.5 E4 B3:0.5 D4 C4:4")
ENT_CHORDS = "C C C,G7 C C C,D7 D7 G7 C C C,G7 C C C C,G7 C"
ENT_INTRO = "D4:0.5 E4:0.5 C4:0.5 A3 B3:0.5 G3 D3:0.5 E3:0.5 C3:0.5 A2 B2:0.5 G2 D3:0.5 E3:0.5 C3:0.5 A2 B2:0.5 A2:0.5 G#2:0.5 G2 r:1 G3:2"
ENT_SONG = song(G, 112, [
    Part("Intro", "intro", ENT_INTRO, chords="G7 G7 G7 G7"),
    Part("Theme", "verse", ENT_THEME, pickup=1, chords=ENT_CHORDS),
    Part("Theme again", "chorus", ENT_THEME, pickup=1, chords=ENT_CHORDS),
    Part("Interlude", "interlude", ENT_INTRO, chords="G7 G7 G7 G7"),
    Part("Last theme", "chorus", ENT_THEME, pickup=1, chords=ENT_CHORDS),
    Part("Coda", "outro", "G3 E3 C3:2 C3:4", chords="G7,C C"),
], shapes=SHAPES)

L_ENT = lesson("std-the-entertainer", "The Entertainer", [
    explain("Ragtime from 1902", "Scott Joplin published The Entertainer in 1902, and a 1973 film made it famous again. "
            "In ragtime the tune leans off the beat while the bass keeps steady time.",
            fretboard(G, [(4, 0), (4, 1, 1), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (2, 4, 4), (1, 0)])),
    notes(G, ["D3", "D#3", "E3", "C4", "E3", "C4", "E3", "C4"],
          hint="Open D, D sharp at fret 1, E at fret 2 on string 4, then leap to C at fret 1 on string 2 and back, three times."),
    explain("Syncopation", "Syncopation puts the accent between the beats. In the opening, each C lands on an and. "
            "Count one-and-two-and and feel the C pull ahead.", rhythm([0, 0.5, 1.5, 2, 3, 3.5])),
    tap([0, 0.5, 1.5, 2, 3, 3.5], bpm=72, bars=2),
    notes(G, ["C4", "D4", "E4", "C4", "D4", "E4", "C4", "D4", "C4", "E4", "C4", "D4", "E4", "B3", "D4", "C4"],
          hint="The ending run circles C, D and E on strings 2 and 1, then lands through B and D on C."),
    ENT_SONG.along("Theme", bpm=84, title=THE_THEME),
    ENT_SONG.take("The Entertainer"),
], minutes=ENT_SONG.minutes(), xp=40, kind="song", arrangement=ENT_SONG.meta())

# ---------------------------------------------------------------- The Liberty Bell
# John Philip Sousa (1854–1932), published 1893. The first strain and the trio, as in the Mutopia edition
# (from F and B flat to G and C). 6/8 counted in eighths.
BELL_STRAIN = ("B3 r B3 B3 A#3 B3 G4 r D4 D4 r B3 C4:2 C4 C4:2 D4 E4:5 C4 "
               "A3 r A3 A3 G#3 A3 F#4 r E4 E4 r C4 B3 r B3 B3 r C4 D4:5 D4")
BELL_TRIO = "C3:3 C3:3 C3:3 G3:3 C4 r C4 C4 r C4 C4:5 G2 C3:3 C3:3 C3:3 G3:3 D4 r D4 D4 r C#4 D4:5 E3"
BELL_SONG = song(G, 176, [
    Part("Intro", "intro", "D3:3 D3:3 D3 r D3 D3 r D3", chords="D7 D7"),
    Part("March", "verse", BELL_STRAIN, chords="G G C C D7 D7 G D7"),
    Part("March again", "chorus", BELL_STRAIN, chords="G G C C D7 D7 G D7"),
    Part("Trio", "bridge", BELL_TRIO, chords="C C C C C C G7 G7"),
    Part("Trio again", "bridge", BELL_TRIO, chords="C C C C C C G7 G7"),
    Part("Interlude", "interlude", "D3:3 D3:3 D3 r D3 D3 r D3", chords="D7 D7"),
    Part("Last march", "chorus", BELL_STRAIN, chords="G G C C D7 D7 G D7"),
    Part("Coda", "outro", "B3 r B3 B3 A#3 B3 G3:6", chords="G G"),
], beats_per_bar=6, shapes=SHAPES)

L_BELL = lesson("std-the-liberty-bell", "The Liberty Bell", [
    explain("A march by Sousa", "John Philip Sousa published The Liberty Bell in 1893, and a British TV comedy later made "
            "it its theme. It's in six-eight: two big beats a bar, like left, right.",
            fretboard(G, [(4, 2, 2), (4, 4, 4), (3, 0), (3, 1, 1), (3, 2, 2), (3, 3, 3), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
    explain("Rests keep it crisp", "Many beats start with a short silence. Stop the string with your fretting hand, "
            "then come back in on the next eighth.", rhythm([0, 2, 3, 4, 5], beats_per_bar=6)),
    tap([0, 2, 3, 4, 5], bpm=120, bars=2, beats_per_bar=6),
    notes(G, ["B3", "B3", "B3", "A#3", "B3", "G4", "D4", "D4", "B3"],
          hint="Open B three times, A sharp at fret 3 on string 3, B again, then up to G on string 1 and down D, D, B."),
    BELL_SONG.along("March", bpm=132, title="The march"),
    BELL_SONG.along("Trio", bpm=132, title="The trio"),
    BELL_SONG.take("The Liberty Bell"),
], minutes=BELL_SONG.minutes(), xp=40, kind="song", arrangement=BELL_SONG.meta())

# ---------------------------------------------------------------- Carmen: Prelude
# Georges Bizet (1838–1875), Carmen (1875): the opening march and the Toreador Song tune from the Prelude, as in the
# Mutopia piano edition (Schirmer, 1895), two octaves down, note values doubled. A major, then F major, 4/4.
CARMEN_TOP = "A3 A3:0.5 A3:0.5 A3:0.5"
CARMEN_MARCH = (f"{CARMEN_TOP} E3:0.5 D3:0.5 E3:0.5 {CARMEN_TOP} B3:0.5 C#4:0.5 B3:0.5 A3 A3:0.5 A3:0.5 B3:0.5 A3:0.5 G#3:0.5 A3:0.5 B3:4 "
                "D4 D4:0.5 D4:0.5 D4:0.5 A3:0.5 G3:0.5 A3:0.5 D4 D4:0.5 D4:0.5 D4:0.5 E4:0.5 F#4:0.5 E4:0.5 D4 D4:0.5 C#4:0.5 B3 B3:0.5 A3:0.5 G#3:4 "
                f"{CARMEN_TOP} E3:0.5 D3:0.5 E3:0.5 {CARMEN_TOP} B3:0.5 C#4:0.5 B3:0.5 A3 A3:0.5 A3:0.5 B3:0.5 A3:0.5 G#3:0.5 A3:0.5 B3:4 "
                "E4 E4:0.5 E4:0.5 E4:0.5 D4:0.5 C4:0.5 D4:0.5 E4 E4:0.5 E4:0.5 E4:0.5 D4:0.5 C4:0.5 D4:0.5 E4 E3:0.5 F#3:0.5 G#3 E3:0.5 C#4:0.5 B3:2 A3 r")
CARMEN_TOREADOR = ("C4:2 D4:1.5 C4:0.5 A3:2 A3:2 A3:1.5 G3:0.5 A3:1.5 Bb3:0.5 A3:3 r Bb3:2 G3:1.5 C4:0.5 A3:3 r "
                   "F3:2 D3:1.5 G3:0.5 C3:3 r G3:4 G3 D4 C4 Bb3 A3 G3 A3 Bb3 A3:3 r E3:2 A3:2 A3:2 G#3:1.5 B3:0.5 E4:8")
CARMEN_SONG = song(G, 120, [
    Part("March", "verse", CARMEN_MARCH, chords="A A A E7 D D D,E7 E7 A A A E7 C C E7 E7,A"),
    Part("Toreador Song", "chorus", CARMEN_TOREADOR, chords="F F C7 F C7 F Gm C C7 C7 C7 F A E7 E7 E7"),
    Part("March again", "verse", CARMEN_MARCH, chords="A A A E7 D D D,E7 E7 A A A E7 C C E7 E7,A"),
    Part("Coda", "outro", "A3 E3 C#3 E3 A2:4", chords="A A"),
], shapes=SHAPES)

L_CARMEN = lesson("std-carmen-prelude", "Carmen: Prelude", [
    explain("The bullfighters arrive", "Georges Bizet's opera Carmen opened in Paris in 1875. Its prelude starts with this "
            "festive march, then plays the tune of the famous Toreador Song.",
            fretboard(G, [(4, 0), (4, 2, 2), (3, 1, 1), (3, 2, 2), (2, 0), (2, 2, 2), (2, 3, 3), (1, 0), (1, 2, 2)])),
    notes(G, ["A3", "A3", "A3", "A3", "E3", "D3", "E3"], hint="Four As at fret 2 on string 3, then down to E at fret 2 on string 4, open D and E."),
    explain("Two tunes, two keys", "The march is in A major, with C sharp and G sharp. The Toreador tune moves to F major, "
            "with B flat at fret 3 on string 3. Watch for the change.", fretboard(G, [(3, 1, 1), (3, 3, 3), (2, 2, 2)])),
    CARMEN_SONG.along("March", bpm=96, title="The march"),
    CARMEN_SONG.along("Toreador Song", bpm=96, title="The Toreador Song"),
    quiz("What happens at the end of the Toreador tune?", ["It climbs to a long E", "It stops on F", "It slows to a halt"], 0,
         "It climbs to a long high E, the note that leads back home to A major for the march."),
    CARMEN_SONG.take("Carmen: Prelude"),
], minutes=CARMEN_SONG.minutes(), xp=40, kind="song", arrangement=CARMEN_SONG.meta())

# ---------------------------------------------------------------- Morning Mood
# Edvard Grieg (1843–1907), Peer Gynt (1875; suite published 1888). The five-note theme, moved through keys as the
# sun rises. 6/8 counted in eighths.
MORNING = "D4:2 B3 A3:2 G3 A3:2 B3 D4:2 B3 A3:2 G3 A3:2 B3 A3:2 B3 D4:2 B3 D4:2 E4 B3:2 E4 D4:2 B3 A3:2 G3"


def morning(shift):
    return transpose(MORNING, shift)


MORNING_SONG = song(G, 120, [
    Part("Intro", "intro", "G3:6 D3:6", chords="G G"),
    Part("Flute", "verse", MORNING, chords="G G G G Em G"),
    Part("Oboe", "verse", morning(-12), chords="G G G G Em G"),
    Part("Sunrise", "bridge", morning(-7), chords="C C C C Am C"),
    Part("Higher", "bridge", morning(-5), chords="D D D D Bm D"),
    Part("Full sun", "chorus", MORNING, chords="G G G G Em G"),
    Part("Coda", "outro", "D4:2 B3 A3:2 G3 G3:6 G2:6", chords="G G G"),
], beats_per_bar=6, shapes=SHAPES)

L_MORNING = lesson("std-morning-mood", "Morning Mood", [
    explain("Sunrise in music", "Edvard Grieg wrote Morning Mood in 1875 for the play Peer Gynt. The flute plays the theme, "
            "the oboe answers, and the music climbs like the rising sun.",
            fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
    explain("Only five notes", "The theme uses just G, A, B, D and E. A five-note scale like this is called pentatonic, "
            "and it sounds calm and open.", fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
    notes(G, ["D4", "B3", "A3", "G3", "A3", "B3"], hint="D at fret 3 on string 2, open B, A at fret 2 on string 3, open G, then back up A and B."),
    quiz("How many different notes does the theme use?", ["Five", "Seven", "Three"], 0,
         "G, A, B, D and E: a pentatonic scale. There is no C and no F sharp in the whole theme."),
    MORNING_SONG.along("Flute", bpm=96, title=THE_THEME),
    MORNING_SONG.along("Sunrise", bpm=96, title="The sunrise"),
    MORNING_SONG.take("Morning Mood"),
], minutes=MORNING_SONG.minutes(), xp=35, kind="song", arrangement=MORNING_SONG.meta())

L_MEDLEY_4 = lesson("std-medley-stage", "Showstoppers medley", [
    explain("The big finish", "The four pieces from this unit, back to back: ragtime, a march, an opera prelude and a "
            "sunrise. Each a little faster than before."),
    listen("Which piece starts like this?", [["D3"], ["D#3"], ["E3"], ["C4"], ["E3"], ["C4"]],
           ["The Entertainer", "The Liberty Bell", "Morning Mood"], 0),
    ENT_SONG.along("Theme", bpm=100, title="The Entertainer"),
    BELL_SONG.along("March", bpm=160, title="The Liberty Bell"),
    quiz("Which of these pieces uses only five notes in its theme?", ["Morning Mood", "The Entertainer", "Carmen: Prelude"], 0,
         "Morning Mood's theme is pentatonic: G, A, B, D and E. The others use many more."),
    CARMEN_SONG.along("March", bpm=108, title="Carmen: Prelude"),
    MORNING_SONG.along("Flute", bpm=108, title="Morning Mood"),
], minutes=6, xp=40, kind="challenge")

# ================================================================ the course

UNITS = [
    unit("std-1", "Campfire singalongs", "Folk songs and a spiritual everyone can sing, with simple chord charts to strum.", [
        L_SHE, L_DBR, L_LOCH, L_MOLLY, L_WATER, L_MEDLEY_1,
    ]),
    unit("std-2", "Ballads and carols", "A Welsh lullaby, a Highland boat song and three carols, in German, Latin and English.", [
        L_NIGHT, L_SKYE, L_TANNE, L_FAITH, L_NOEL, L_MEDLEY_2,
    ]),
    unit("std-3", "Pipes, waltzes and dances", "A pipe march, a Russian folk dance, the Blue Danube and the can-can.", [
        L_BRAVE, L_KORO, L_DANUBE, L_CAN, L_MEDLEY_3,
    ]),
    unit("std-4", "Ragtime, marches and the stage", "Joplin, Sousa, Bizet and Grieg: syncopation, six-eight and key changes.", [
        L_ENT, L_BELL, L_CARMEN, L_MORNING, L_MEDLEY_4,
    ]),
]

COURSE = course("standards", "Standards & Classics", "Famous tunes everyone knows, start to finish", "guitar.acoustic.6",
                "music.note.list", "violet", UNITS)
