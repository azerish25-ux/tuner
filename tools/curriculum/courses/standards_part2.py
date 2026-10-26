"""Standards & Classics, units 5 to 9: carols, hymns, parlor songs and concert favorites people ask for by name.

Same rules as songs_part3.py: every tune passed the rights check in docs/content/PUBLIC-DOMAIN-CLEARANCE.md (first
published before 1931, every creator whose work is used died before 1956), and only the public-domain melody and
words are used. Each melody was read note by note from the Mutopia Project edition named in the clearance table, then
moved to a guitar key in first position; every key, chord chart, intro, solo, ending and song form here is our own.
Lyric alignment follows the edition's slurs; where verses differ in syllables, the verse's own line splits or joins a
note (noted at the song).

Meters: 3/4 counts quarters; 6/8 counts eighths (beats_per_bar=6, bpm in eighths). 2/4 tunes are written two bars
to one 4/4 bar.
"""
from lib import chord, explain, fretboard, lesson, listen, notes, position, progression, quiz, rhythm, tap, unit
from songbook import Part, song

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
E_MAJ = chord(G, "E", "022100", "x231xx")
E7 = chord(G, "E7", "020100", "x2x1xx")
B7 = chord(G, "B7", "x21202", "x213x4")
G7 = chord(G, "G7", "320001", "32xxx1")
F_MINI = chord(G, "F", "xx3211", "xx3211")
Dm = chord(G, "Dm", "xx0231", "xxx231")
Bm = chord(G, "Bm", "x24432", "x13421")
Bm7 = chord(G, "Bm7", "x20202", "x1x2x3")
C7 = chord(G, "C7", "x32310", "x3241x")
SHAPES = {c["name"]: c for c in [G_MAJ, C, D, D7, Em, Am, A_MAJ, A7, E_MAJ, E7, B7, G7, F_MINI, Dm, Bm, Bm7, C7]}

QUARTERS = [0, 1, 2, 3]
WALTZ = [0, 1, 2]
SIX = [0, 3]
THE_VERSE = "The verse"
THE_CHORUS = "The chorus"
THE_THEME = "The theme"
THE_TUNE = "The tune"


def shape(spec):
    return {"type": "chord", "chord": spec}


def dots(*names):
    """Fretboard dots for some notes, where the songbook plays them in first position (string, fret, finger)."""
    out = []
    for n in names:
        at = position(G, n)
        dot = (at["s"], at["f"], at["g"]) if at["f"] else (at["s"], 0)
        if dot not in out:
            out.append(dot)
    return fretboard(G, out)


def tune_lesson(lid, title, made, steps, xp=35):
    """A song lesson: its teaching steps, then the whole song."""
    return lesson(lid, title, steps + [made.take(title)], minutes=made.minutes(), xp=xp, kind="song",
                  arrangement=made.meta())


# ================================================================ 5. Carols by candlelight

# ---------------------------------------------------------------- Hark! The Herald Angels Sing
# Felix Mendelssohn (1809–1847), Festgesang 1840, fitted to Charles Wesley's words by W. H. Cummings in 1856.
# Mutopia "Mendelssohn" hymn tune. F → G, 4/4.
HARK_VERSE = ("D3 G3 G3:1.5 F#3:0.5 G3 B3 B3 A3 D4 D4 D4:1.5 C4:0.5 B3 A3 B3:2 "
              "D3 G3 G3:1.5 F#3:0.5 G3 B3 B3 A3 D4 A3 A3:1.5 F#3:0.5 F#3 E3 D3:2 "
              "D4 D4 D4 G3 C4 B3 B3 A3 D4 D4 D4 G3 C4 B3 B3 A3 "
              "E4 E4 E4 D4 C4 B3 C4:2 A3 B3:0.5 C4:0.5 D4:1.5 G3:0.5 G3 A3 B3:2")
HARK_REFRAIN = "E4:1.5 E4:0.5 E4 D4 C4 B3 C4:2 A3 B3:0.5 C4:0.5 D4:1.5 G3:0.5 G3 A3 G3:2"
HARK_CHART = "G G,D G,C D,G G Em,A7 D A7,D D,G D7,D D,G D7,D C C,Am Am,G D7,G"
HARK_REFRAIN_CHART = "C C,Am D7,G D7,G"
HARK_V = Part("Verse 1", "verse", HARK_VERSE, chords=HARK_CHART, lyrics=(
    "Hark! the her-ald an-gels sing, _ / 'Glo-ry to the new-born King; / peace on earth, and mer-cy mild, _ / "
    "God and sin-ners re-con-ciled!' / Joy-ful, all ye na-tions, rise, _ / join the tri-umph of the skies; _ / "
    "with th'an-gel-ic host pro-claim, / 'Christ is _ born in Beth-le-hem!'"))
HARK_C = Part("Chorus", "chorus", HARK_REFRAIN, chords=HARK_REFRAIN_CHART,
              lyrics="Hark! the her-ald an-gels sing, / 'Glo-ry _ to the new-born King!'")
HARK_SONG = song(G, 96, [
    Part("Intro", "intro", HARK_REFRAIN, chords=HARK_REFRAIN_CHART),
    HARK_V, HARK_C,
    HARK_V.with_lyrics("Verse 2", (
        "Hail the heav'n~born Prince of Peace! _ / Hail the Sun of Right-eous-ness! / Light and life to all he brings, _ / "
        "ris'n with heal-ing in his wings. / Mild he lays his glo-ry by, _ / born that man no more may die, _ / "
        "born to raise the sons of earth, / born to _ give them sec-ond birth.")),
    HARK_C,
    Part("Outro", "outro", "A3 B3:0.5 C4:0.5 D4:1.5 G3:0.5 G3 A3 G3:2 G2:4", chords="D7,G D7,G G"),
], shapes=SHAPES, words="Charles Wesley (1739), as printed in 1861")

L_HARK = tune_lesson("std-hark-the-herald", "Hark! The Herald Angels Sing", HARK_SONG, [
    explain("Wesley's words, Mendelssohn's tune", "Charles Wesley wrote the words in 1739. In 1856 an English organist "
            "set them to a tune from a choral piece by Felix Mendelssohn, and the carol has been sung that way since.",
            dots("D3", "E3", "F#3", "G3", "A3", "B3", "C4", "D4", "E4")),
    notes(G, ["D3", "G3", "G3", "F#3", "G3", "B3", "B3", "A3"],
          hint="Open D, open G twice, F sharp at fret 4 on string 4, G, then open B twice and A at fret 2 on string 3."),
    explain("A dotted step", "Her-ald is long-short: her- lands on three and holds, and -ald slips in on the and of "
            "four. Count one, two, three, four-and.", rhythm([0, 1, 2, 3.5])),
    tap([0, 1, 2, 3.5], bpm=72, bars=2),
    HARK_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    HARK_SONG.along("Chorus", bpm=72, title=THE_CHORUS),
    explain("Chords for the chorus", "The chorus moves C, A minor, D7 and G. Change on the word that starts each half "
            "bar, and keep the strum light under the high E.", shape(C)),
    progression([(C, 1), (Am, 1), (D7, 1), (G_MAJ, 1)], QUARTERS, bpm=80),
])

# ---------------------------------------------------------------- Away in a Manger
# Words anonymous (1885; third verse by John T. McFarland, 1851–1913, printed 1892); tune "Mueller" by James
# Ramsey Murray (1841–1905), 1887. Mutopia "Mueller". F → G, 3/4.
AWAY = ("D4 D4:1.5 C4:0.5 B3 B3 A3 G3 G3 F#3 E3 D3:2 D3 D3:1.5 E3:0.5 D3 D3 A3 F#3 E3 D3 G3 B3:2 "
        "D4 D4:1.5 C4:0.5 B3 B3 A3 G3 G3 F#3 E3 D3:2 D3 C4:1.5 B3:0.5 A3 B3 A3 G3 A3 E3 F#3 G3:3")
AWAY_CHART = "G G C G D7 D7 G G G G C G D7 G D7 G"
AWAY_V = Part("Verse 1", "verse", AWAY, pickup=1, chords=AWAY_CHART, lyrics=(
    "A-way in a man-ger, no crib for a bed, / the lit-tle Lord Je-sus / laid down his sweet head. / "
    "The stars in the bright sky / looked down where he lay, / the lit-tle Lord Je-sus / a-sleep on the hay."))
AWAY_SONG = song(G, 100, [
    Part("Intro", "intro", "D3 C4:1.5 B3:0.5 A3 B3 A3 G3 A3 E3 F#3 G3:3", pickup=1, chords="D7 G D7 G"),
    AWAY_V,
    AWAY_V.with_lyrics("Verse 2", (
        "The cat-tle are low-ing, the ba-by a-wakes, / but lit-tle Lord Je-sus, no cry-ing he makes. / "
        "I love thee, Lord Je-sus, / look down from the sky, / and stay by my cra-dle / till mor-ning is nigh.")),
    AWAY_V.instrumental("Solo"),
    AWAY_V.with_lyrics("Verse 3", (
        "Be near me, Lord Je-sus, I ask thee to stay / close by me for-ev-er, and love me, I pray. / "
        "Bless all the dear chil-dren / in thy ten-der care, / and fit us for hea-ven / to live with thee there.")),
    Part("Outro", "outro", "A3 E3 F#3 G3:3 G2:3", chords="D7 G G"),
], beats_per_bar=3, shapes=SHAPES, words="Anonymous (1885); verse 3 John T. McFarland (1892)")

L_AWAY = tune_lesson("std-away-in-a-manger", "Away in a Manger", AWAY_SONG, [
    explain("A lullaby carol", "These words first appeared in an American children's book in 1885, and James R. Murray "
            "gave them this gentle tune in 1887. It rocks in three, like a cradle.",
            dots("D3", "E3", "F#3", "G3", "A3", "B3", "C4", "D4")),
    notes(G, ["D4", "D4", "C4", "B3", "B3", "A3", "G3", "G3", "F#3", "E3", "D3"],
          hint="It starts high: D at fret 3 on string 2, then steps down C, B, A, G and F sharp all the way to open D."),
    tap(WALTZ, bpm=84, bars=2, beats_per_bar=3),
    AWAY_SONG.along("Verse 1", bpm=80, title=THE_VERSE),
    quiz("The first line walks down from high D to low D. How far is that?", ["A fifth", "An octave", "A third"], 1,
         "D down to D is an octave: eight steps of the scale, the same note name, one register lower."),
    explain("G, C and D7", "Hold G for most of a line, C for crib for a bed, and D7 to lead home. In three, strum "
            "down on one and lightly on two and three.", shape(D7)),
    progression([(G_MAJ, 2), (C, 1), (G_MAJ, 1), (D7, 2), (G_MAJ, 2)], WALTZ, bpm=96, beats_per_bar=3),
])

# ---------------------------------------------------------------- O Little Town of Bethlehem
# Words Phillips Brooks (1835–1893), 1868; tune "St. Louis" by Lewis H. Redner (1831–1908), 1868.
# Mutopia "St. Louis". F → G, 4/4.
TOWN = ("B3 B3 B3 A#3 B3 D4 C4 E3 A3 G3 F#3:0.5 G3:0.5 A3 D3 B3:3 B3 B3 B3 E4 D4 D4 C4 E3 A3 G3 F#3:0.5 G3:0.5 "
        "B3:1.5 A3:0.5 G3:3 B3 B3 B3 A3 G3 F#3:2 F#3 F#3 E3 F#3 G3 A3 B3:3 B3 B3 B3 A#3 B3 D4 C4 E3 E4 "
        "D4 G3 B3:1.5 A3:0.5 G3:4")
TOWN_CHART = "G C,Am D7 G G,E7 Am D7 G G B7 Em,C B7 G C D7 G"
TOWN_V = Part("Verse 1", "verse", TOWN, pickup=1, chords=TOWN_CHART, lyrics=(
    "O lit-tle town of Beth-le-hem, / how still we _ see thee lie! / A-bove thy deep and dream-less sleep / "
    "the si-lent _ stars go by. / Yet in thy dark streets shin-eth / the ev-er-last-ing Light; / "
    "the hopes and fears of all the years / are met in thee to-night."))
TOWN_SONG = song(G, 88, [
    Part("Intro", "intro", "B3 B3 B3 A#3 B3 D4 C4 E3 E4 D4 G3 B3:1.5 A3:0.5 G3:4", pickup=1, chords="G C D7 G"),
    TOWN_V,
    TOWN_V.instrumental("Solo"),
    TOWN_V.with_lyrics("Verse 2", (
        "How si-lent-ly, how si-lent-ly, / the won-drous _ gift is giv'n! / So God im-parts to hu-man hearts / "
        "the bless-ings _ of his heav'n. / No ear may hear his com-ing, / but in this world of sin, / "
        "where meek souls will re-ceive him still, / the dear Christ en-ters in.")),
    Part("Outro", "outro", "D4 G3 B3:1.5 A3:0.5 G3:4", chords="D7 G"),
], shapes=SHAPES, words="Phillips Brooks (1868)")

L_TOWN = tune_lesson("std-o-little-town", "O Little Town of Bethlehem", TOWN_SONG, [
    explain("A carol from Philadelphia", "Phillips Brooks wrote these words in 1868 for the children of his "
            "Philadelphia church, and its organist, Lewis Redner, wrote the tune for their Christmas service.",
            dots("D3", "E3", "F#3", "G3", "A3", "A#3", "B3", "C4", "D4", "E4")),
    notes(G, ["B3", "B3", "B3", "A#3", "B3", "D4", "C4", "E3"],
          hint="Open B three times, A sharp at fret 3 on string 3, B again, then D, C and a drop to E on string 4."),
    explain("The note between", "A sharp at fret 3 on string 3 leans into open B, a half step up. It gives O little "
            "town its gentle sway.", dots("A3", "A#3", "B3")),
    TOWN_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    quiz("Which word dips down to the low D in the first verse?", ["Town", "Bethlehem",
                                                                    "Thee, in how still we see thee lie"], 2,
         "How still we see thee lie: the tune falls to open D on thee, then lifts to B on lie."),
    progression([(G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 1)], QUARTERS, bpm=76),
])

# ---------------------------------------------------------------- It Came Upon the Midnight Clear
# Words Edmund H. Sears (1810–1876), 1849; tune "Carol" by Richard Storrs Willis (1819–1900), 1850.
# Mutopia "Carol". B flat → C, 6/8 in eighths. Ties the edition prints as slurs (one long note) are joined.
MIDNIGHT = ("G3 E4:2 B3 D4 C4 A3 G3:2 A3 G3:2 G3 A3 B3 C4 C4 D4 E4 D4:5 G3 E4:2 B3 D4 C4 A3 G3:2 A3 G3:2 G3 "
            "A3:2 A3 B3 A3 G3 C4:5 E4 E4:2 E3 E3 F#3 G#3 A3 A3 B3 C4:2 E4 D4 C4 B3 A3 B3 A3 G3:5 G3 "
            "E4:2 B3 D4 C4 A3 G3:2 A3 G3:2 G3 A3:2 A3 B3 A3 G3 C4:6")
MIDNIGHT_CHART = "C C F,D7 G C C F,G7 C E7 Am D7 G C C F,G7 C"
MIDNIGHT_V = Part("Verse 1", "verse", MIDNIGHT, pickup=1, chords=MIDNIGHT_CHART, lyrics=(
    "It came up-on _ the mid-night clear, / that glo- _ rious song _ of old, / from an-gels bend- _ ing near the earth "
    "/ to touch their harps _ of gold: / 'Peace on the earth, good will to _ men, / from heav-en's _ all~gra- _ cious "
    "King.' / The world in sol- _ emn still-ness lay / to hear the an- _ gels sing."))
MIDNIGHT_SONG = song(G, 150, [
    Part("Intro", "intro", "G3 E4:2 B3 D4 C4 A3 G3:2 A3 G3:2 G3 A3:2 A3 B3 A3 G3 C4:6", pickup=1, chords="C C F,G7 C"),
    MIDNIGHT_V,
    MIDNIGHT_V.instrumental("Solo"),
    MIDNIGHT_V.with_lyrics("Verse 2", (
        "Still through the clo- _ ven skies they come / with peace- _ ful wings _ un-furled, / and still their heav'n- _ "
        "ly mu-sic floats / o'er all the wea- _ ry world; / a-bove its sad and low-ly _ plains / they bend on _ hov-er- _ "
        "ing wing, / and ev-er o'er _ its Ba-bel sounds / the bless-ed an- _ gels sing.")),
    Part("Outro", "outro", "G3 A3:2 A3 B3 A3 G3 C4:6", pickup=1, chords="F,G7 C"),
], beats_per_bar=6, shapes=SHAPES, words="Edmund H. Sears (1849)")

L_MIDNIGHT = tune_lesson("std-it-came-upon", "It Came Upon the Midnight Clear", MIDNIGHT_SONG, [
    explain("A carol in six-eight", "Edmund Sears wrote these words in Massachusetts in 1849, and Richard Storrs Willis "
            "wrote the tune a year later. It swings in two big beats a bar, each split in three.",
            dots("E3", "F#3", "G#3", "G3", "A3", "B3", "C4", "D4", "E4")),
    explain("Long, short", "In six-eight a quarter and an eighth make one big beat: long, short. Count one-two-three, "
            "four-five-six, and play on one, three, four and six.", rhythm([0, 2, 3, 5], beats_per_bar=6)),
    tap([0, 2, 3, 5], bpm=132, bars=2, beats_per_bar=6),
    notes(G, ["G3", "E4", "B3", "D4", "C4", "A3", "G3", "A3", "G3"],
          hint="Open G, a leap to open E on string 1, then B, D, C, A, and back to G with a turn through A."),
    MIDNIGHT_SONG.along("Verse 1", bpm=120, title=THE_VERSE),
    explain("Peace on the earth", "The middle of the verse drops to low E and climbs through G sharp, at fret 1 on "
            "string 3, to A. Under it the chord moves from E7 to A minor.", shape(E7)),
    progression([(C, 1), (F_MINI, 1), (G7, 1), (C, 1)], SIX, bpm=132, beats_per_bar=6),
])

L_MEDLEY_5 = lesson("std-medley-carols", "Carol medley", [
    explain("Carols back to back", "The four carols from this unit, one after another, each a little faster. Keep the "
            "chords soft and let the tune sing."),
    listen("Which carol starts like this?", [["D3"], ["G3"], ["G3"], ["F#3"], ["G3"], ["B3"], ["B3"], ["A3"]],
           ["Away in a Manger", "Hark! The Herald Angels Sing", "O Little Town of Bethlehem"], 1),
    HARK_SONG.along("Chorus", bpm=88, title="Hark! The Herald Angels Sing"),
    AWAY_SONG.along("Verse 1", bpm=96, title="Away in a Manger"),
    quiz("Which of these carols counts in three?", ["O Little Town of Bethlehem", "Hark! The Herald Angels Sing",
                                                    "Away in a Manger"], 2,
         "Away in a Manger is a waltz: one, two, three. The other two count in four."),
    TOWN_SONG.along("Verse 1", bpm=84, title="O Little Town of Bethlehem"),
    MIDNIGHT_SONG.along("Verse 1", bpm=144, title="It Came Upon the Midnight Clear"),
], minutes=7, xp=40, kind="challenge")

# ================================================================ 6. Winter carols

# ---------------------------------------------------------------- Once in Royal David's City
# Words Cecil Frances Alexander (1818–1895), 1848; tune "Irby" by Henry John Gauntlett (1805–1876), 1849.
# Mutopia "Irby". G, 4/4. Verses 1 and 6.
ROYAL = ("D3 F#3 G3:1.5 G3:0.5 G3:0.5 F#3:0.5 G3:0.5 A3:0.5 A3 G3 G3 B3 D4:1.5 B3:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:2 "
         "D3 F#3 G3:1.5 G3:0.5 G3:0.5 F#3:0.5 G3:0.5 A3:0.5 A3 G3 G3 B3 D4:1.5 B3:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:2 "
         "E4 E4 D4:1.5 G3:0.5 C4 C4 B3:2 E4 E4 D4:1.5 B3:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:2")
ROYAL_CHART = "G D7,G G D7,G G D7,G G D7,G C,G D7,G C,G D7,G"
ROYAL_V = Part("Verse 1", "verse", ROYAL, chords=ROYAL_CHART, lyrics=(
    "Once in roy-al Da- _ vid's _ ci-ty / stood a low-ly cat- _ tle _ shed, / where a moth-er laid _ her _ ba-by "
    "/ in a man-ger for _ his _ bed: / Ma-ry was that moth-er mild, / Je-sus Christ her lit- _ tle _ child."))
ROYAL_SONG = song(G, 84, [
    Part("Intro", "intro", "E4 E4 D4:1.5 G3:0.5 C4 C4 B3:2 E4 E4 D4:1.5 B3:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:2",
         chords="C,G D7,G C,G D7,G"),
    ROYAL_V,
    ROYAL_V.instrumental("Solo"),
    ROYAL_V.with_lyrics("Verse 2", (
        "Not in that poor low- _ ly _ sta-ble, / with the ox-en stand- _ ing _ by, / we shall see him; but _ in _ "
        "hea-ven, / set at God's right hand _ on _ high; / when like stars his chil-dren crowned / all in white shall "
        "wait _ a- _ round.")),
    Part("Outro", "outro", "B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:2 G2:4", chords="D7,G G"),
], shapes=SHAPES, words="Cecil Frances Alexander (1848)")

L_ROYAL = tune_lesson("std-royal-davids-city", "Once in Royal David's City", ROYAL_SONG, [
    explain("The first verse alone", "Cecil Frances Alexander wrote these words for children in 1848. Since 1919 a "
            "single young voice has sung the first verse to open the Christmas Eve carols at King's College, Cambridge.",
            dots("D3", "F#3", "G3", "A3", "B3", "C4", "D4", "E4")),
    notes(G, ["D3", "F#3", "G3", "G3", "G3", "F#3", "G3", "A3", "A3", "G3"],
          hint="Open D, F sharp at fret 4 on string 4, open G, then a turn: G, F sharp, G, A, A, G."),
    explain("Two notes, one syllable", "Da-vid's spreads each syllable over two eighth notes. Play both, but sing them "
            "as one smooth sound.", rhythm([0, 0.5, 1, 1.5, 2, 3])),
    ROYAL_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
    quiz("Where is the highest note of the carol?", ["D at fret 3 on string 2", "E on open string 1",
                                                     "B on open string 2"], 1,
         "Mary was that mother mild starts on open E, the top of the tune."),
    progression([(C, 1), (G_MAJ, 1), (D7, 1), (G_MAJ, 1)], QUARTERS, bpm=72),
])

# ---------------------------------------------------------------- In the Bleak Midwinter
# Words Christina Rossetti (1830–1894), 1872; tune "Cranham" by Gustav Holst (1874–1934), The English Hymnal, 1906.
# Mutopia "Cranham". F → G, 4/4. Verses 1 and 4; verse 4 sings "Wise Man" on one long E where verse 1 has two.
BLEAK = ("B3 B3:1.5 C4:0.5 D4 B3 A3:2 G3:2 A3:1.5 B3:0.5 A3 E3 A3:3 r B3:1.5 C4:0.5 D4 B3 A3:2 G3:2 "
         "A3 B3 A3:1.5 G3:0.5 G3:3 r C4:1.5 B3:0.5 C4 D4 E4 E4 B3:2 D4 B3 A3 G3 F#3:3 B3 "
         "B3:1.5 C4:0.5 D4 B3 A3:2 G3:2 A3 B3 A3:1.5 G3:0.5 G3:3 r")
BLEAK_CHART = "G Em Am Am,D7 G Em C,D7 G C,G7 C,Em G,C D G Em C,D7 G"
BLEAK_V = Part("Verse 1", "verse", BLEAK, pickup=1, chords=BLEAK_CHART, lyrics=(
    "In the bleak mid-win-ter, _ / frost-y wind made moan, / earth stood hard as i-ron, / wa-ter like a stone; / "
    "snow had fall-en, snow on snow, / snow _ on _ snow, / in the bleak mid-win-ter, _ / long _ a- _ go."))
BLEAK_SONG = song(G, 84, [
    Part("Intro", "intro", "B3 B3:1.5 C4:0.5 D4 B3 A3:2 G3:2 A3 B3 A3:1.5 G3:0.5 G3:3 r", pickup=1,
         chords="G Em C,D7 G"),
    BLEAK_V,
    BLEAK_V.instrumental("Solo"),
    Part("Verse 2", "verse", BLEAK.replace("E4 E4 B3:2", "E4:2 B3:2"), pickup=1, chords=BLEAK_CHART, lyrics=(
        "What can I give _ him, _ / poor as I _ am? / If I were a shep-herd, / I would bring a lamb; / "
        "if I were a Wise Man, / I would do my part; / yet what I can I give him: / give _ my _ heart.")),
    Part("Outro", "outro", "A3 B3 A3:1.5 G3:0.5 G3:4", chords="C,D7 G"),
], shapes=SHAPES, words="Christina Rossetti (1872)")

L_BLEAK = tune_lesson("std-bleak-midwinter", "In the Bleak Midwinter", BLEAK_SONG, [
    explain("A poem and a quiet tune", "Christina Rossetti wrote this poem in 1872, and Gustav Holst set it to music "
            "for a hymn book in 1906. Its lines are short and calm, like snow falling.",
            dots("E3", "F#3", "G3", "A3", "B3", "C4", "D4", "E4")),
    notes(G, ["B3", "B3", "C4", "D4", "B3", "A3", "G3"],
          hint="Open B twice, C at fret 1 and D at fret 3 on string 2, then back down B, A and G."),
    explain("Hold the long notes", "Many words land on half notes: -ter in mid-winter, i-ron. Let each ring for two "
            "full beats before you move on.", rhythm([0, 2])),
    BLEAK_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    quiz("Long ago stretches three syllables over how many notes?", ["Three", "Four", "Five"], 2,
         "Long takes two notes, a- takes two, and go takes one: five notes for three syllables."),
    explain("Chords that lean", "Under frost-y wind made moan the chords move A minor to D7, a lean that pulls the "
            "line back to G.", shape(Am)),
    progression([(G_MAJ, 1), (Em, 1), (Am, 1), (D7, 1)], QUARTERS, bpm=72),
])

# ---------------------------------------------------------------- The Holly and the Ivy
# Traditional English carol, words and tune collected by Cecil Sharp (1859–1924) at Chipping Campden and printed in
# 1911. Mutopia "The Holly and the Ivy". F → G, 3/4. Verses 1, 2 and 4 (the "blood" verse is left out for 4+).
HOLLY_VERSE = ("G3 G3:0.5 G3:0.5 G3 E4 D4 B3:1.5 G3:0.5 G3:0.5 G3:0.5 G3 E4 D4:2 D4:0.5 C4:0.5 "
               "B3:0.5 A3:0.5 G3 B3:0.5 B3:0.5 E3:0.5 E3:0.5 D3 G3:0.5 A3:0.5 B3:0.5 C4:0.5 B3 A3 G3:3")
HOLLY_REFRAIN = ("G3 G3:0.5 G3:0.5 G3 E4 D4 B3:1.5 G3:0.5 G3:0.5 G3:0.5 G3 E4 D4:2 D4:0.5 C4:0.5 "
                 "B3:0.5 A3:0.5 G3 B3 E3:0.5 E3:0.5 D3 G3:0.5 A3:0.5 B3:0.5 C4:0.5 B3 A3 G3:3")
HOLLY_CHART = "G G G D7 G C,D7 G,D7 G"
HOLLY_V = Part("Verse 1", "verse", HOLLY_VERSE, pickup=1, chords=HOLLY_CHART, lyrics=(
    "The hol-ly and the i-vy, / when they are both full grown, / of _ all the trees that are in the wood, / "
    "the _ hol-ly bears the crown."))
HOLLY_C = Part("Chorus", "chorus", HOLLY_REFRAIN, pickup=1, chords=HOLLY_CHART, lyrics=(
    "The ri-sing of the sun / and the run-ning of the deer, / the _ play-ing of the mer-ry or-gan, / "
    "sweet sing-ing in the choir."))
HOLLY_SONG = song(G, 100, [
    Part("Intro", "intro", "B3:0.5 A3:0.5 G3 B3 E3:0.5 E3:0.5 D3 G3:0.5 A3:0.5 B3:0.5 C4:0.5 B3 A3 G3:3",
         chords="G C,D7 G,D7 G"),
    HOLLY_V, HOLLY_C,
    HOLLY_V.with_lyrics("Verse 2", (
        "The hol-ly bears a blos-som / as white as the li-ly flow'r, _ / and Ma-ry bore sweet Je-sus Christ / "
        "to _ be our sweet Sav-iour.")),
    HOLLY_C,
    HOLLY_V.instrumental("Solo"),
    HOLLY_V.with_lyrics("Verse 3", (
        "The hol-ly bears a prick-le / as sharp as an-y thorn, / and _ Ma-ry bore sweet Je-sus Christ _ / "
        "on Christ-mas Day in the morn.")),
    HOLLY_C,
    Part("Outro", "outro", "B3:0.5 C4:0.5 B3 A3 G3:3 G2:3", chords="G,D7 G G"),
], beats_per_bar=3, shapes=SHAPES, words="Traditional (printed 1911)")

L_HOLLY = tune_lesson("std-holly-and-ivy", "The Holly and the Ivy", HOLLY_SONG, [
    explain("A folk carol", "This carol is centuries old. The song collector Cecil Sharp heard it sung in a "
            "Cotswold town and printed this tune in 1911. It dances in three.",
            dots("D3", "E3", "G3", "A3", "B3", "C4", "D4", "E4")),
    notes(G, ["G3", "G3", "G3", "G3", "E4", "D4", "B3"],
          hint="Four open Gs, then a leap to open E on string 1, down to D at fret 3 on string 2 and open B."),
    explain("The big leap", "From open G to open E is a sixth. Keep your pick close to the strings and cross from "
            "string 3 to string 1 in one move.", dots("G3", "E4")),
    tap([0, 0.5, 1, 2], bpm=88, bars=2, beats_per_bar=3),
    HOLLY_SONG.along("Verse 1", bpm=84, title=THE_VERSE),
    HOLLY_SONG.along("Chorus", bpm=84, title=THE_CHORUS),
    progression([(G_MAJ, 3), (D7, 1), (G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 1)], WALTZ, bpm=92, beats_per_bar=3),
])

# ---------------------------------------------------------------- Angels from the Realms of Glory
# Words James Montgomery (1771–1854), 1816; tune "Regent Square" by Henry Smart (1813–1879), 1867.
# Mutopia "Regent Square". B flat → D, 4/4. Verses 1, 2 and 3.
ANGELS_VERSE = ("A3 F#3 D4 A3 F#4:1.5 E4:0.5 D4 A3 B3 B3 A3 D4 A3 G3 F#3:2 "
                "A3 F#3 D4 A3 F#4:1.5 E4:0.5 D4 C#4 D4 C#4 B3 C#4:0.5 D4:0.5 C#4 B3 A3:2")
ANGELS_REFRAIN = "E4:1.5 E4:0.5 C#4 A3 F#4:1.5 E4:0.5 D4 B3 G4 F#4 E4 D4 D4 C#4 D4:2"
ANGELS_CHART = "D D G,Bm7 A7,D D D Bm7 E7,A"
ANGELS_REFRAIN_CHART = "A D,G G,A7 A7,D"
ANGELS_V = Part("Verse 1", "verse", ANGELS_VERSE, chords=ANGELS_CHART, lyrics=(
    "An-gels from the realms of glo-ry, / wing your flight o'er all the earth; / ye who sang cre-a-tion's sto-ry, "
    "/ now pro-claim Mes- _ si-ah's birth:"))
ANGELS_C = Part("Chorus", "chorus", ANGELS_REFRAIN, chords=ANGELS_REFRAIN_CHART, lyrics=(
    "come and wor-ship, come and wor-ship, / wor-ship Christ, the new-born King."))
ANGELS_SONG = song(G, 104, [
    Part("Intro", "intro", ANGELS_REFRAIN, chords=ANGELS_REFRAIN_CHART),
    ANGELS_V, ANGELS_C,
    ANGELS_V.with_lyrics("Verse 2", (
        "Shep-herds, in the fields a-bid-ing, / watch-ing o'er your flocks by night, / God with us is now re-sid-ing; "
        "/ yon-der shines the _ in-fant light:")),
    ANGELS_C,
    ANGELS_V.instrumental("Solo"),
    ANGELS_V.with_lyrics("Verse 3", (
        "Sag-es, leave your con-tem-pla-tions; / bright-er vi-sions beam a-far; / seek the great De-sire of na-tions; "
        "/ ye have seen his _ na-tal star:")),
    ANGELS_C,
    Part("Outro", "outro", "D4 C#4 D4:2 D3:4", chords="A7,D D"),
], shapes=SHAPES, words="James Montgomery (1816)")

L_ANGELS = tune_lesson("std-angels-from-the-realms", "Angels from the Realms of Glory", ANGELS_SONG, [
    explain("A newspaper carol", "James Montgomery printed these words in his Sheffield newspaper on Christmas Eve, "
            "1816. Henry Smart's tune, from 1867, gives it a grand, marching sound.",
            dots("F#3", "G3", "A3", "B3", "C#4", "D4", "E4", "F#4", "G4")),
    notes(G, ["A3", "F#3", "D4", "A3", "F#4", "E4", "D4", "A3"],
          hint="A on string 3, F sharp at fret 4 on string 4, D at fret 3 on string 2, A, then F sharp at fret 2 "
               "on string 1, E and D."),
    explain("In D major", "This key has two sharps, F sharp and C sharp. C sharp sits at fret 2 on string 2.",
            dots("C#4", "D4", "F#4")),
    ANGELS_SONG.along("Verse 1", bpm=88, title=THE_VERSE),
    ANGELS_SONG.along("Chorus", bpm=88, title=THE_CHORUS),
    quiz("Where is the highest note of the chorus?", ["Open E", "G at fret 3 on string 1", "D at fret 3 on string 2"], 1,
         "Worship Christ starts on G at fret 3 on string 1, the top of the whole carol."),
    progression([(A_MAJ, 1), (D, 1), (G_MAJ, 1), (A7, 1), (D, 1)], QUARTERS, bpm=88),
])

L_MEDLEY_6 = lesson("std-medley-winter", "Winter medley", [
    explain("Four winter carols", "The carols from this unit, back to back. Most move in long notes: let each one ring "
            "full length before the next."),
    listen("Which carol starts like this?", [["G3"], ["G3"], ["G3"], ["G3"], ["E4"], ["D4"], ["B3"]],
           ["In the Bleak Midwinter", "Angels from the Realms of Glory", "The Holly and the Ivy"], 2),
    ROYAL_SONG.along("Verse 1", bpm=80, title="Once in Royal David's City"),
    BLEAK_SONG.along("Verse 1", bpm=80, title="In the Bleak Midwinter"),
    quiz("Which of these counts in three?", ["Angels from the Realms of Glory", "The Holly and the Ivy",
                                             "In the Bleak Midwinter"], 1,
         "The Holly and the Ivy is in three. The other two count in four."),
    HOLLY_SONG.along("Chorus", bpm=96, title="The Holly and the Ivy"),
    ANGELS_SONG.along("Chorus", bpm=96, title="Angels from the Realms of Glory"),
], minutes=7, xp=40, kind="challenge")

# ================================================================ 7. Hymns everyone knows

# ---------------------------------------------------------------- Holy, Holy, Holy
# Words Reginald Heber (1783–1826), printed 1826; tune "Nicaea" by John Bacchus Dykes (1823–1876), 1861.
# Mutopia "Nicaea". D → G, 4/4. Verses 1 and 4; verse 4 splits the long D for its extra syllable (in earth, and sky,
# and sea).
HOLY = ("G3 G3 B3 B3 D4:2 D4:2 E4:2 E4 E4 D4:2 B3:2 D4:1.5 D4:0.5 D4 D4 G4:2 F#4 D4 A3 D4 E4:1.5 D4:0.5 D4:4 "
        "G3 G3 B3 B3 D4:2 D4:2 E4:1.5 E4:0.5 E4 E4 D4:2 D4:2 G4:2 D4 D4 E4:2 B3:2 C4 A3 A3:1.5 G3:0.5 G3:4")
HOLY_CHART = "G,Em D7,G C G D,G A7,D D,A7 D,D7 G,Em D7,G C G Em,G7 C,G Am,D7 G"
HOLY_V = Part("Verse 1", "verse", HOLY, chords=HOLY_CHART, lyrics=(
    "Ho-ly, ho-ly, ho-ly! / Lord God Al-might-y! / Ear-ly in the morn-ing / our song shall rise to thee. / "
    "Ho-ly, ho-ly, ho-ly! / Mer-ci-ful and might-y, / God in three Per-sons, / bless-ed Trin-i-ty!"))
HOLY_SONG = song(G, 92, [
    Part("Intro", "intro", "G4:2 D4 D4 E4:2 B3:2 C4 A3 A3:1.5 G3:0.5 G3:4", chords="Em,G7 C,G Am,D7 G"),
    HOLY_V,
    HOLY_V.instrumental("Solo"),
    Part("Verse 2", "verse", HOLY.replace("D4:4", "D4:2 D4:2"), chords=HOLY_CHART, lyrics=(
        "Ho-ly, ho-ly, ho-ly! / Lord God Al-might-y! / All thy works shall praise thy name, / "
        "in earth, and sky, and sea. / Ho-ly, ho-ly, ho-ly! / Mer-ci-ful and might-y, / God in three Per-sons, / "
        "bless-ed Trin-i-ty!")),
    Part("Outro", "outro", "C4 A3 A3:1.5 G3:0.5 G3:2 B2:2 G2:4", chords="Am,D7 G G"),
], shapes=SHAPES, words="Reginald Heber (1826)")

L_HOLY = tune_lesson("std-holy-holy-holy", "Holy, Holy, Holy", HOLY_SONG, [
    explain("A hymn for the morning", "Reginald Heber wrote these words, printed in 1826, and John Bacchus Dykes wrote "
            "the tune in 1861. Its first line climbs the notes of a G major chord.",
            dots("G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4")),
    notes(G, ["G3", "G3", "B3", "B3", "D4", "D4"],
          hint="Up the G chord: open G twice, open B twice, then D at fret 3 on string 2, held long."),
    quiz("Holy, holy, holy climbs which notes?", ["G, A and B", "D, E and F sharp", "G, B and D"], 2,
         "G, B and D are the notes of a G major chord, so the tune climbs the chord itself."),
    HOLY_SONG.along("Verse 1", bpm=80, title=THE_VERSE),
    explain("Halves and wholes", "This hymn moves in long notes: halves of two beats and a whole note of four at the "
            "end. Count every beat, even while a note rings.", rhythm([0, 2], beats_per_bar=4)),
    progression([(G_MAJ, 1), (Em, 1), (D7, 1), (G_MAJ, 1), (C, 2), (G_MAJ, 2)], [0, 2], bpm=80),
])

# ---------------------------------------------------------------- Nearer, My God, to Thee
# Words Sarah Flower Adams (1805–1848), 1841; tune "Bethany" by Lowell Mason (1792–1872), 1856.
# Mutopia "Nearer My God to Thee". G, 4/4. Verses 1 and 2.
NEARER = ("B3:2 A3:1.5 G3:0.5 G3:1.5 E3:0.5 E3:2 D3:2 G3 B3 A3:3 r B3:2 A3:1.5 G3:0.5 G3:1.5 E3:0.5 E3:2 "
          "D3 G3 F#3 A3 G3:3 r D4:2 E4:1.5 D4:0.5 D4 B3 D4:2 D4:2 E4:1.5 D4:0.5 D4 B3 A3:2 "
          "B3:2 A3:1.5 G3:0.5 G3:1.5 E3:0.5 E3:2 D3 G3 F#3 A3 G3:4")
NEARER_CHART = "G,D7 C G D G,D7 C D7 G G,C G G,C G,D7 G,D7 C D7 G"
NEARER_V = Part("Verse 1", "verse", NEARER, chords=NEARER_CHART, lyrics=(
    "Near-er, my God, to thee, / near-er to thee! / E'en though it be a cross / that rais-eth _ me, / "
    "still all my song shall be, / near-er, my God, to thee; / near-er, my God, to thee, / near-er to _ thee!"))
NEARER_SONG = song(G, 76, [
    Part("Intro", "intro", "B3:2 A3:1.5 G3:0.5 G3:1.5 E3:0.5 E3:2 D3 G3 F#3 A3 G3:4", chords="G,D7 C D7 G"),
    NEARER_V,
    NEARER_V.with_lyrics("Verse 2", (
        "Though like the wan-der-er, / the sun gone down, / dark-ness be o-ver me, / my rest a _ stone, / "
        "yet in my dreams I'd be / near-er, my God, to thee; / near-er, my God, to thee, / near-er to _ thee!")),
    Part("Outro", "outro", "D3 G3 F#3 A3 G3:4", chords="D7 G"),
], shapes=SHAPES, words="Sarah Flower Adams (1841)")

L_NEARER = tune_lesson("std-nearer-my-god", "Nearer, My God, to Thee", NEARER_SONG, [
    explain("A hymn from 1856", "Sarah Flower Adams wrote these words in London in 1841, and Lowell Mason, an American "
            "music teacher, gave them this tune in 1856.",
            dots("D3", "E3", "F#3", "G3", "A3", "B3", "D4", "E4")),
    notes(G, ["B3", "A3", "G3", "G3", "E3", "E3"],
          hint="Open B, A at fret 2 on string 3, open G twice, then E at fret 2 on string 4 twice."),
    explain("Dotted rhythm", "Each line has a long-short pair: a dotted quarter, then a quick eighth, as in -er, my "
            "and God, to. Let the long note lean into the short one.", rhythm([0, 2, 3.5])),
    tap([0, 2, 3.5], bpm=66, bars=2),
    NEARER_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
    progression([(G_MAJ, 1), (C, 1), (G_MAJ, 1), (D, 1)], [0, 2], bpm=72),
])


# ---------------------------------------------------------------- Abide with Me
# Words Henry Francis Lyte (1793–1847), 1847; tune "Eventide" by William Henry Monk (1823–1889), 1861.
# Mutopia "Eventide". E flat → G, 4/4. Verses 1, 2 and 3 (the verses about death and the grave are left out).
ABIDE = ("B3:2 B3 A3 G3:2 D4:2 E4 D4 D4 C4 B3:4 B3:2 C4 D4 E4:2 D4:2 C4 A3 B3 C#4 D4:4 "
         "B3:2 B3 A3 G3:2 D4:2 D4 C4 C4 B3 A3:4 A3:2 B3 C4 B3 A3 G3 C4 B3:2 A3:2 G3:4")
ABIDE_CHART = "G,D Em,G C,D7 G G,D7 C,G Am,A7 D G,D Em,G C Am Am,G G,C G,D7 G"
ABIDE_V = Part("Verse 1", "verse", ABIDE, chords=ABIDE_CHART, lyrics=(
    "A-bide with me; fast falls the e-ven-tide; / the dark-ness deep-ens; Lord, with me a-bide. / "
    "When oth-er help-ers fail and com-forts flee, / help of the help-less, O a-bide with me."))
ABIDE_SONG = song(G, 88, [
    Part("Intro", "intro", "A3:2 B3 C4 B3 A3 G3 C4 B3:2 A3:2 G3:4", chords="Am,G G,C G,D7 G"),
    ABIDE_V,
    ABIDE_V.with_lyrics("Verse 2", (
        "Swift to its close / ebbs out life's lit-tle day; / earth's joys grow dim, / its glo-ries pass a-way; / "
        "change and de-cay in all a-round I see; / O thou who chang-est not, a-bide with me.")),
    ABIDE_V.with_lyrics("Verse 3", (
        "I need thy pres-ence ev-ery pass-ing hour; / what but thy grace / can foil the tempt-er's power? / "
        "Who, like thy-self, my guide and stay can be? / Through cloud and sun-shine, O a-bide with me.")),
    Part("Outro", "outro", "B3:2 A3:2 G3:4", chords="G,D7 G"),
], shapes=SHAPES, words="Henry Francis Lyte (1847)")

L_ABIDE = tune_lesson("std-abide-with-me", "Abide with Me", ABIDE_SONG, [
    explain("An evening hymn", "Henry Francis Lyte wrote these words in 1847, and William Henry Monk wrote the tune "
            "Eventide for them in 1861. Football crowds in England have sung it before the cup final since 1927.",
            dots("G3", "A3", "B3", "C4", "C#4", "D4", "E4")),
    notes(G, ["B3", "B3", "A3", "G3", "D4", "E4", "D4", "D4", "C4", "B3"],
          hint="Open B twice, A at fret 2 on string 3, open G, then D at fret 3 and E on string 1, back through D and "
               "C to B."),
    explain("Slow and even", "Every note here is a quarter, a half or a whole. Count four steady beats a bar and let "
            "the long notes ring.", rhythm([0, 2, 3])),
    ABIDE_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
    quiz("Which note leads into the D at the end of the second line?", ["C", "C sharp", "B"], 1,
         "C sharp, at fret 2 on string 2, rises a half step into D, the way a leading note does."),
    progression([(G_MAJ, 1), (Em, 1), (C, 1), (D7, 1), (G_MAJ, 1)], [0, 2], bpm=76),
])

# ---------------------------------------------------------------- O God, Our Help in Ages Past
# Words Isaac Watts (1674–1748), 1719; tune "St Anne" by William Croft (1678–1727), 1708.
# Mutopia "St. Anne". C, 4/4. Verses 1, 2, 3, 4 and the last.
ANNE = "G3 E3 A3 G3 C4 C4 B3 C4 G3 C4 G3 A3 F#3 G3:3 B3 C4 A3 D4 B3 C4 A3 B3 G3 A3 C4 D4 B3 C4:4"
ANNE_CHART = "Am,C G7,C Am,D7 G F,G Am,G F,G C"
ANNE_V = Part("Verse 1", "verse", ANNE, pickup=1, chords=ANNE_CHART, lyrics=(
    "O God, our help in a-ges past, / our hope for years to come, / our shel-ter from the storm-y blast, / "
    "and our e-ter-nal home."))
ANNE_SONG = song(G, 92, [
    Part("Intro", "intro", "A3 C4 D4 B3 C4:4", chords="F,G C"),
    ANNE_V,
    ANNE_V.with_lyrics("Verse 2", (
        "Un-der the shad-ow of thy throne / still may we dwell se-cure; / suf-fi-cient is thine arm a-lone, / "
        "and our de-fence is sure.")),
    ANNE_V.with_lyrics("Verse 3", (
        "Be-fore the hills in or-der stood, / or earth re-ceived her frame, / from ev-er-last-ing thou art God, / "
        "to end-less years the same.")),
    ANNE_V.instrumental("Solo"),
    ANNE_V.with_lyrics("Verse 4", (
        "A thou-sand a-ges in thy sight / are like an eve-ning gone, / short as the watch that ends the night / "
        "be-fore the ris-ing sun.")),
    ANNE_V.with_lyrics("Verse 5", (
        "O God, our help in a-ges past, / our hope for years to come, / be thou our guard while trou-bles last, / "
        "and our e-ter-nal home.")),
    Part("Outro", "outro", "F3 A3 C4 F4 E4:4", chords="F C"),
], shapes=SHAPES, words="Isaac Watts (1719)")

L_ANNE = tune_lesson("std-o-god-our-help", "O God, Our Help in Ages Past", ANNE_SONG, [
    explain("A hymn from 1708", "William Croft wrote this tune, St Anne, in 1708, and Isaac Watts's words were first "
            "printed in 1719. Each verse is four short lines, the plainest hymn shape there is.",
            dots("E3", "F#3", "G3", "A3", "B3", "C4", "D4")),
    notes(G, ["G3", "E3", "A3", "G3", "C4", "C4", "B3", "C4"],
          hint="Open G, E at fret 2 on string 4, A at fret 2 on string 3, G, then C at fret 1 on string 2, C, open B "
               "and C."),
    explain("One pickup a line", "Every line starts on the beat before the bar: O, our, our, and. Count four, "
            "then sing the first word on it.", rhythm([3])),
    ANNE_SONG.along("Verse 1", bpm=80, title=THE_VERSE),
    explain("A minor and G7", "The chart leans on A minor, F and G7. God, our sits on A minor, and a-ges past moves "
            "from G7 to C.", shape(G7)),
    progression([(Am, 1), (G7, 1), (C, 1), (F_MINI, 1), (G_MAJ, 1), (C, 1)], [0, 2], bpm=80),
])

# ---------------------------------------------------------------- For the Beauty of the Earth
# Words Folliott S. Pierpoint (1835–1917), 1864; tune "Dix" by Conrad Kocher (1786–1872), 1838, as shortened by
# W. H. Monk (1823–1889) in 1861. Mutopia "Dix". G, 4/4. Verses 1, 2 and 3.
BEAUTY_LINE = "G3 F#3:0.5 G3:0.5 A3 G3 C4 C4 B3:2 E3 F#3 G3 E3 D3 D3 D3:2"
BEAUTY_VERSE = f"{BEAUTY_LINE} {BEAUTY_LINE}"
BEAUTY_REFRAIN = "B3 A3 G3 B3 D4:1.5 C4:0.5 B3:2 E3 F#3 G3 C4 B3 A3 G3:2"
BEAUTY_CHART = "G,D C,G C D7,G G,D C,G C D7,G"
BEAUTY_REFRAIN_CHART = "G D7,G C D7,G"
BEAUTY_V = Part("Verse 1", "verse", BEAUTY_VERSE, chords=BEAUTY_CHART, lyrics=(
    "For the _ beau-ty of the earth, / for the glo-ry of the skies, / for the _ love which from our birth / "
    "o-ver and a-round us lies:"))
BEAUTY_C = Part("Chorus", "chorus", BEAUTY_REFRAIN, chords=BEAUTY_REFRAIN_CHART, lyrics=(
    "Lord of all, to thee we raise / this our hymn of grate-ful praise."))
BEAUTY_SONG = song(G, 96, [
    Part("Intro", "intro", BEAUTY_REFRAIN, chords=BEAUTY_REFRAIN_CHART),
    BEAUTY_V, BEAUTY_C,
    BEAUTY_V.with_lyrics("Verse 2", (
        "For the _ beau-ty of each hour / of the day and of the night, / hill and _ vale, and tree and flow'r, / "
        "sun and moon, and stars of light:")),
    BEAUTY_C,
    BEAUTY_V.instrumental("Solo"),
    BEAUTY_V.with_lyrics("Verse 3", (
        "For the _ joy of hu-man love, / bro-ther, sis-ter, par-ent, child, / friends on _ earth, and friends a-bove, / "
        "for all gen-tle thoughts and mild:")),
    BEAUTY_C,
    Part("Outro", "outro", "B3 A3 G3:2 G2:4", chords="D7,G G"),
], shapes=SHAPES, words="Folliott S. Pierpoint (1864)")

L_BEAUTY = tune_lesson("std-for-the-beauty", "For the Beauty of the Earth", BEAUTY_SONG, [
    explain("A hymn of thanks", "Folliott Pierpoint wrote these words in 1864, on a spring day in the English "
            "countryside. They are sung to Dix, a German tune from 1838.",
            dots("D3", "E3", "F#3", "G3", "A3", "B3", "C4", "D4")),
    notes(G, ["G3", "F#3", "G3", "A3", "G3", "C4", "C4", "B3"],
          hint="Open G, F sharp at fret 4 on string 4, G, A at fret 2 on string 3, G, then C at fret 1 on string 2 "
               "twice and open B."),
    explain("Two quick notes", "For the starts with two eighth notes on the: F sharp and G, one syllable sung over "
            "both. Play them evenly inside one beat.", rhythm([0, 1, 1.5, 2, 3])),
    BEAUTY_SONG.along("Verse 1", bpm=80, title=THE_VERSE),
    BEAUTY_SONG.along("Chorus", bpm=80, title=THE_CHORUS),
    progression([(G_MAJ, 1), (D, 1), (C, 1), (G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 1)], [0, 2], bpm=88),
])

L_MEDLEY_HYMNS = lesson("std-medley-hymns", "Hymn medley", [
    explain("Five hymns", "The hymns from this unit, back to back, from the oldest tune to the newest. Let the long "
            "notes ring and the chords change on the word."),
    listen("Which hymn starts like this?", [["G3"], ["G3"], ["B3"], ["B3"], ["D4"]],
           ["Abide with Me", "Holy, Holy, Holy", "Nearer, My God, to Thee"], 1),
    ANNE_SONG.along("Verse 1", bpm=88, title="O God, Our Help in Ages Past"),
    BEAUTY_SONG.along("Chorus", bpm=92, title="For the Beauty of the Earth"),
    quiz("Which of these tunes is the oldest?", ["Bethany (Nearer, My God), 1856", "Nicaea (Holy, Holy, Holy), 1861",
                                                 "St Anne (O God, Our Help), 1708"], 2,
         "William Croft wrote St Anne in 1708, almost 150 years before the other two."),
    NEARER_SONG.along("Verse 1", bpm=72, title="Nearer, My God, to Thee"),
    HOLY_SONG.along("Verse 1", bpm=88, title="Holy, Holy, Holy"),
    ABIDE_SONG.along("Verse 1", bpm=80, title="Abide with Me"),
], minutes=8, xp=40, kind="challenge")

# ================================================================ 8. Parlor songs and a planet

# ---------------------------------------------------------------- Home! Sweet Home!
# Henry Bishop (1786–1855), music, and John Howard Payne (1791–1852), words, from the opera Clari (1823).
# Mutopia "Home, Sweet Home". F → G, 4/4. Verses 1 and 2 with the refrain.
HOME_VERSE = ("G3:0.75 A3:0.25 B3:1.5 C4:0.5 C4:1.5 D4:0.5 D4:1.5 B3:0.5 B3 D4 C4:1.5 B3:0.5 C4 A3 B3:3 G3:0.75 A3:0.25 "
              "B3:1.5 C4:0.5 C4:1.5 D4:0.5 D4:2 B3 D4 C4:1.5 B3:0.5 C4 A3 G3:2 r D4:0.5 D4:0.5 "
              "G4:1.5 F#4:0.5 E4:1.5 D4:0.5 D4:2 B3 D4 C4:1.5 B3:0.5 C4 A3 B3:3 D4:0.5 D4:0.5 "
              "G4:1.5 F#4:0.5 E4:1.5 D4:0.5 D4:2 B3 D4 D4 C4:2 A3 G3:3 r")
HOME_REFRAIN = "D4:4 C4:2 A3:2 G3 r A3 r B3:2 r D4 G4:1.5 F#4:0.5 E4:1.5 D4:0.5 D4:2 B3 D4 C4:1.5 B3:0.5 C4 A3 G3:3 r"
HOME_CHART = "G,D7 G D7 G G,D7 G D7 G G,C G D7 G G,C G D7 G"
HOME_REFRAIN_CHART = "G C G,D7 G G,C G D7 G"
HOME_V = Part("Verse 1", "verse", HOME_VERSE, pickup=1, chords=HOME_CHART, lyrics=(
    "'Mid _ pleas- _ ures and pal-a-ces _ / though _ we may roam, / be it ev- _ er so hum-ble, / there's no _ "
    "place like home. / A _ charm _ from the skies / seems to hal- _ low us there, / which, _ seek _ through the "
    "world, / is ne'er met with else-where."))
HOME_C = Part("Chorus", "chorus", HOME_REFRAIN, chords=HOME_REFRAIN_CHART, lyrics=(
    "Home! Home! _ Sweet, sweet home! / There's no _ place like home, / oh, there's no _ place like home!"))
HOME_SONG = song(G, 92, [
    Part("Intro", "intro", "G4:1.5 F#4:0.5 E4:1.5 D4:0.5 D4:2 B3 D4 C4:1.5 B3:0.5 C4 A3 G3:3 r",
         chords="G,C G D7 G"),
    HOME_V, HOME_C,
    HOME_V.with_lyrics("Verse 2", (
        "I _ gaze _ on the moon / as I _ tread _ the drear wild, / and _ feel _ that my moth-er / now thinks _ of "
        "her child, / as she looks _ on that moon / from our own _ cot-tage door, / through the wood- _ bine whose "
        "fra-grance / shall cheer me no more.")),
    HOME_C,
    Part("Outro", "outro", "C4:1.5 B3:0.5 C4 A3 G3:4", chords="D7 G"),
], shapes=SHAPES, words="John Howard Payne (1823)")

L_HOME = tune_lesson("std-home-sweet-home", "Home! Sweet Home!", HOME_SONG, [
    explain("A song from an opera", "Henry Bishop wrote this tune for a London opera in 1823, to words by the American "
            "actor John Howard Payne. Within a few years it was one of the best-loved songs in the world.",
            dots("G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4")),
    notes(G, ["G3", "A3", "B3", "C4", "C4", "D4", "D4", "B3"],
          hint="Open G, A at fret 2 on string 3, open B, C at fret 1 and D at fret 3 on string 2, then back to B."),
    explain("A quick pickup", "The verse starts just before beat one, on a dotted eighth and a sixteenth. Count "
            "four-e-and-a: 'Mid lands on four, and its short turn on a.", rhythm([0, 3, 3.75])),
    HOME_SONG.along("Verse 1", bpm=76, title=THE_VERSE),
    HOME_SONG.along("Chorus", bpm=76, title=THE_CHORUS),
    quiz("The chorus begins on one long note. How long is it?", ["Two beats", "Four beats", "One beat"], 1,
         "Home! is a whole note: hold D at fret 3 on string 2 for the whole bar."),
    progression([(G_MAJ, 1), (D7, 1), (G_MAJ, 1), (C, 1), (D7, 1), (G_MAJ, 1)], [0, 2], bpm=84),
])

# ---------------------------------------------------------------- Hard Times Come Again No More
# Stephen Foster (1826–1864), words and music, 1854. Mutopia edition (Foster's Melodies, Horace Waters, New York).
# E flat → D, 4/4. Verses 1 and 2 with the chorus.
HARD_VERSE = ("D3:0.5 E3:0.5 F#3 F#3:0.5 F#3:0.5 F#3:0.5 A3 F#3:0.5 E3:0.5 D3:0.5 D3:0.5 E3:0.5 F#3 B3:0.75 A3:0.25 "
              "A3 F#3 F#3:0.5 D3:0.5 E3:0.75 E3:0.25 D3:2 r D3:0.5 E3:0.5 F#3 F#3:0.5 F#3:0.5 F#3:0.5 A3 F#3:0.5 "
              "E3:0.5 D3:0.5 D3:0.5 E3:0.5 F#3 B3 A3 F#3 F#3:0.5 D3:0.5 E3:0.75 E3:0.25 D3:2 r:2")
HARD_TAIL = "F#3 F#3:0.5 F#3:0.5 F#3:0.5 A3 F#3:0.5 E3:0.75 D3:0.25 D3:0.5 E3:0.5 F#3 B3 A3 F#3 F#3:0.5 D3:0.5 E3:0.75 E3:0.25 D3:3 r"
HARD_REFRAIN = ("F#3:0.5 G3:0.5 A3 r:0.5 A3:0.5 A3 G#3:0.5 A3:0.5 B3:2 A3 r D4 A3 B3 A3 "
                f"F#3:0.5 F#3:0.5 E3:0.75 D3:0.25 E3 D3:0.5 E3:0.5 {HARD_TAIL}")
HARD_CHART = "D A7,D D,A7 D D A7,D D,A7 D"
HARD_REFRAIN_CHART = "D G,D D D,A7 D A7,D D,A7 D"
HARD_V = Part("Verse 1", "verse", HARD_VERSE, pickup=1, chords=HARD_CHART, lyrics=(
    "Let us pause in life's pleas-ures / and count its man-y tears, / while we all sup sor-row with the poor; / "
    "there's a song that will lin-ger / for-ev-er in our ears; / oh, hard times, come a-gain no more."))
HARD_C = Part("Chorus", "chorus", HARD_REFRAIN, pickup=1, chords=HARD_REFRAIN_CHART, lyrics=(
    "'Tis the song, the sigh of the wear-y: / hard times, hard times, / come a-gain no more; / man-y days you have "
    "lin-gered / a-round my cab-in door; / oh, hard times, come a-gain no more."))
HARD_SONG = song(G, 76, [
    Part("Intro", "intro", HARD_TAIL, chords="D A7,D D,A7 D"),
    HARD_V, HARD_C,
    HARD_V.with_lyrics("Verse 2", (
        "While we seek mirth and beau-ty / and mu-sic light and gay, / there are frail forms / faint-ing at the door; "
        "/ though their voic-es are si-lent, / their plead-ing looks will say: / oh, hard times, come a-gain no more.")),
    HARD_C,
    Part("Outro", "outro", "A3 F#3 F#3:0.5 D3:0.5 E3:0.75 E3:0.25 D3:4", chords="D,A7 D"),
], shapes=SHAPES, words="Stephen Foster (1854)")

L_HARD = tune_lesson("std-hard-times", "Hard Times Come Again No More", HARD_SONG, [
    explain("Foster's quiet song", "Stephen Foster published this song in 1854. It asks the listener to stop and think "
            "of people who have less, and singers still return to it today.",
            dots("D3", "E3", "F#3", "G3", "G#3", "A3", "B3", "D4")),
    notes(G, ["D3", "E3", "F#3", "F#3", "F#3", "F#3", "A3", "F#3"],
          hint="Open D, E and F sharp on string 4, three more F sharps, then A at fret 2 on string 3 and back to "
               "F sharp."),
    explain("Many repeated notes", "The verse sings several words on one note. Keep each F sharp short and even, "
            "and let the words carry the line.", rhythm([0, 1, 1.5, 2, 2.5, 3.5])),
    HARD_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
    HARD_SONG.along("Chorus", bpm=66, title=THE_CHORUS),
    explain("D, G and A7", "The chorus lifts to G under the long note on wear-y, then rests on D for hard times. "
            "A7 brings each line home.", shape(A7)),
    progression([(D, 1), (G_MAJ, 1), (D, 1), (A7, 1), (D, 1)], [0, 2], bpm=72),
])

# ---------------------------------------------------------------- The Last Rose of Summer
# Thomas Moore (1779–1852), words, to the Irish air "Aislean an Oigfear", in A Selection of Irish Melodies (1813).
# Mutopia "The Last Rose of Summer" (grace notes left out). D, 3/4. Verses 1 and 2.
ROSE = ("D3:0.75 E3:0.25 F#3 D4:0.75 C#4:0.25 B3:0.75 A3:0.25 A3 F#3:0.5 r:0.5 D3:0.75 E3:0.25 "
        "F#3:0.5 A3 F#3:0.5 E3:0.75 D3:0.25 D3:2 D3:0.75 E3:0.25 F#3 D4:0.75 C#4:0.25 B3:0.75 A3:0.25 "
        "A3 F#3:0.5 r:0.5 D3:0.75 E3:0.25 F#3:0.5 A3 F#3:0.5 E3:0.75 D3:0.25 D3:1.5 r:0.5 A3:0.75 F#3:0.25 "
        "D4:1.5 C#4:0.5 B3:0.75 A3:0.25 A3 F#3 A3:0.75 F#3:0.25 D4:1.5 C#4:0.5 B3:0.5 A#3:0.5 "
        "B3:0.75 C#4:0.25 D4 D3:0.75 E3:0.25 F#3 D4:0.75 C#4:0.25 B3:0.75 A3:0.25 A3 F#3:0.5 r:0.5 D3:0.75 E3:0.25 "
        "F#3 A3:0.75 F#3:0.25 E3:0.75 D3:0.25 D3:3")
ROSE_CHART = "D,G D D,A7 D D,G D D,A7 D D,G D Bm Bm,A7 D,G D D,A7 D"
ROSE_V = Part("Verse 1", "verse", ROSE, pickup=1, chords=ROSE_CHART, lyrics=(
    "'Tis the last rose _ of _ sum-mer, / left _ bloom- _ ing a- _ lone; / all her love-ly _ com- _ pan-ions / "
    "are _ fad- _ _ ed and gone; / no _ flow-er of her kin-dred, / no _ rose- _ bud is nigh, _ _ / to re-flect "
    "back _ her _ blush-es, / or _ give _ _ sigh for sigh."))
ROSE_SONG = song(G, 72, [
    Part("Intro", "intro", "F#3 D4:0.75 C#4:0.25 B3:0.75 A3:0.25 A3 F#3:0.5 r:0.5 D3:0.75 E3:0.25 "
                           "F#3 A3:0.75 F#3:0.25 E3:0.75 D3:0.25 D3:3", chords="D,G D D,A7 D"),
    ROSE_V,
    ROSE_V.instrumental("Solo"),
    ROSE_V.with_lyrics("Verse 2", (
        "I'll not leave thee, _ thou _ lone one, / to _ pine _ on the _ stem; / since the love-ly _ are _ sleep-ing, / "
        "go _ sleep _ _ thou with them. / Thus _ kind-ly I _ scat-ter / thy _ leaves _ o'er the bed _ _ / where thy "
        "mates of _ the _ gar-den / lie _ scent- _ _ less and dead.")),
    Part("Outro", "outro", "F#3 A3:0.75 F#3:0.25 E3:0.75 D3:0.25 D3:3", chords="D,A7 D"),
], beats_per_bar=3, shapes=SHAPES, words="Thomas Moore (1813)")

L_ROSE = tune_lesson("std-last-rose", "The Last Rose of Summer", ROSE_SONG, [
    explain("An Irish air", "Thomas Moore set these words to an old Irish air and printed them in 1813. Later, "
            "Mendelssohn wrote a fantasia on the tune, and Flotow put it in his opera Martha.",
            dots("D3", "E3", "F#3", "A3", "A#3", "B3", "C#4", "D4")),
    notes(G, ["D3", "E3", "F#3", "D4", "C#4", "B3", "A3"],
          hint="Open D, E and F sharp on string 4, then a leap to D at fret 3 on string 2, and down C sharp, B and A."),
    explain("Dotted turns", "Most beats split long-short: a dotted eighth and a sixteenth. Play the long note full and "
            "let the short one lead into the next beat.", rhythm([0, 0.75, 1, 1.75, 2, 2.75], beats_per_bar=3)),
    tap([0, 0.75, 1, 1.75, 2, 2.75], bpm=60, bars=2, beats_per_bar=3),
    ROSE_SONG.along("Verse 1", bpm=60, title=THE_VERSE),
    explain("A turn to B minor", "In the middle, no rosebud is nigh climbs through A sharp to B. The chord turns to B "
            "minor there, the saddest moment of the song.", shape(Bm)),
    progression([(D, 1), (G_MAJ, 1), (D, 1), (A7, 1), (Bm, 2), (A7, 1), (D, 1)], WALTZ, bpm=72, beats_per_bar=3),
])

# ---------------------------------------------------------------- Jupiter
# Gustav Holst (1874–1934), the central tune of Jupiter from The Planets (1914–1916, published 1921), as the hymn
# tune "Thaxted" (1921). Mutopia "Thaxted". C, 3/4. Instrumental.
JUPITER_A = "A3:1.5 C4:0.5 B3:0.75 G3:0.25 C4:0.5 D4:0.5 C4 B3 A3:0.5 B3:0.5 A3 G3 E3:2 E3:0.5 G3:0.5"
JUPITER_B = "A3:1.5 C4:0.5 B3:0.75 G3:0.25 C4:0.5 D4:0.5 E4 E4 E4:0.5 D4:0.5 C4 D4 C4:2"
JUPITER = (f"E3:0.5 G3:0.5 {JUPITER_A} {JUPITER_B} G3:0.5 E3:0.5 D3:1.5 D3:0.5 C3:0.5 E3:0.5 D3 G3 G3:0.5 E3:0.5 "
           "D3:1.5 D3:0.5 E3:0.5 G3:0.5 A3:2 A3:0.5 B3:0.5 C4:0.75 C4:0.25 B3 A3 G3 C4 E3 D3:0.5 C3:0.5 D3 E3 "
           f"G3:2 E3:0.5 G3:0.5 {JUPITER_A} {JUPITER_B} r")
JUPITER_CHART = "F,G C,G F,G Am F,G C C,G C G,C G,C G,C Am,G C,F C G,C G F,G C,G F,G Am F,G C C,G C"
JUPITER_SONG = song(G, 84, [
    Part("Intro", "intro", "C4:0.75 C4:0.25 B3 A3 G3 C4 E3 D3:0.5 C3:0.5 D3 E3 G3:2 r", chords="C,F C G,C G"),
    Part("Theme", "verse", JUPITER, pickup=1, chords=JUPITER_CHART),
    Part("Theme again", "chorus", JUPITER, pickup=1, chords=JUPITER_CHART),
    Part("Coda", "outro", "E4:0.5 D4:0.5 C4 D4 C4:3 C3:3", chords="C,G C C"),
], beats_per_bar=3, shapes=SHAPES)

L_JUPITER = tune_lesson("std-jupiter", "Jupiter", JUPITER_SONG, [
    explain("A tune from The Planets", "Gustav Holst wrote The Planets between 1914 and 1916. This broad tune is the "
            "heart of Jupiter. In 1921 he made it a hymn tune and named it Thaxted, after the town where he lived.",
            dots("C3", "D3", "E3", "G3", "A3", "B3", "C4", "D4", "E4")),
    notes(G, ["E3", "G3", "A3", "C4", "B3", "G3", "C4", "D4", "C4", "B3"],
          hint="E at fret 2 on string 4, open G, A at fret 2, then C at fret 1 on string 2, open B, G, and up C, D, C, B."),
    explain("Down to low C", "The middle of the tune dips to C at fret 3 on string 5. Reach for it with your third "
            "finger, then come straight back up to string 4.", dots("C3", "D3", "E3")),
    JUPITER_SONG.along("Theme", bpm=72, title=THE_THEME),
    quiz("How does Jupiter's tune count?", ["In four", "In two", "In three"], 2,
         "Like a slow waltz: one, two, three. Each phrase starts with two eighth notes before beat one."),
    progression([(F_MINI, 1), (G_MAJ, 1), (C, 1), (Am, 1)], WALTZ, bpm=84, beats_per_bar=3),
])

L_MEDLEY_7 = lesson("std-medley-parlor", "Parlor medley", [
    explain("Songs for the piano room", "Before records, families sang these songs around the piano at home. Here they "
            "are back to back, with Holst's big tune to finish."),
    listen("Which song starts like this?", [["D3"], ["E3"], ["F#3"], ["D4"], ["C#4"], ["B3"], ["A3"]],
           ["Home! Sweet Home!", "Hard Times Come Again No More", "The Last Rose of Summer"], 2),
    HOME_SONG.along("Chorus", bpm=84, title="Home! Sweet Home!"),
    HARD_SONG.along("Chorus", bpm=72, title="Hard Times Come Again No More"),
    quiz("Which two of these count in three?", ["The Last Rose of Summer and Jupiter", "Home! Sweet Home! and Jupiter",
                                                "Hard Times and The Last Rose of Summer"], 0,
         "The Last Rose of Summer and Jupiter are both in three. Home! Sweet Home! and Hard Times count in four."),
    ROSE_SONG.along("Verse 1", bpm=66, title="The Last Rose of Summer"),
    JUPITER_SONG.along("Theme", bpm=80, title="Jupiter"),
], minutes=8, xp=40, kind="challenge")

# ================================================================ 9. Concert favorites

# ---------------------------------------------------------------- Spring
# Antonio Vivaldi (1678–1741), Spring from The Four Seasons (published 1725): the opening ritornello, the birdsong
# and the brooks from the solo violin part, as in the Mutopia edition, two octaves down. E, 4/4. Instrumental.
SPRING_BAR = "G#3:0.5 G#3:0.5 G#3:0.5 F#3:0.25 E3:0.25 B3:1.5 B3:0.25 A3:0.25"
SPRING_TURN = "G#3:0.5 A3:0.25 B3:0.25 A3:0.5 G#3:0.5"
SPRING_A = (f"E3:0.5 {SPRING_BAR} {SPRING_BAR} {SPRING_TURN} F#3:0.5 D#3:0.5 B2:0.5 E3:0.5 {SPRING_BAR} {SPRING_BAR} "
            f"{SPRING_TURN} F#3 r")
SPRING_UP = "B3:0.5 A3:0.25 G#3:0.25 A3:0.5 B3:0.5"
SPRING_B = (f"E3:0.5 {SPRING_UP} C#4:0.5 B3 E3:0.5 {SPRING_UP} C#4:0.5 B3 E3:0.5 C#4:0.5 B3 A3:0.5 G#3:0.5 F#3:0.25 "
            f"E3:0.25 F#3 E3 r:0.5 E3:0.5 {SPRING_UP} C#4:0.5 B3 E3:0.5 {SPRING_UP} C#4:0.5 B3 E3:0.5 C#4:0.5 B3 A3:0.5 "
            "G#3:0.5 F#3:0.25 E3:0.25 F#3 E3:2")
SPRING_BIRDS = ("B3 B3 B3 B3 " + "B3:0.5 " * 15 + "C#4:0.25 D#4:0.25 "
                "E4:0.25 D#4:0.25 C#4:0.25 B3:0.25 A3:0.25 G#3:0.25 F#3:0.25 E3:0.25 r:2")
SPRING_BROOKS = ("E3:0.5 G#2:0.25 A2:0.25 B2:0.25 A2:0.25 B2:0.25 A2:0.25 G#2:0.25 A2:0.25 G#2:0.25 A2:0.25 B2:0.25 "
                 "A2:0.25 B2:0.25 A2:0.25 G#2:0.25 A2:0.25 G#2:0.25 A2:0.25 B2:0.25 A2:0.25 B2:0.25 A2:0.25 G#2:0.25 "
                 "A2:0.25 G#2:0.25 A2:0.25 B2:0.25 C#3:0.25 B2:0.25 C#3:0.25 "
                 + "D#3:0.25 E3:0.25 D#3:0.25 E3:0.25 F#3:0.25 E3:0.25 F#3:0.25 E3:0.25 " * 2
                 + "D#3:0.25 E3:0.25 D#3:0.25 E3:0.25 F#3:0.25 G#3:0.25 F#3:0.25 G#3:0.25 A3:0.25 G#3:0.25 A3:0.25 "
                 "G#3:0.25 F#3:0.25 A3:0.25 G#3:0.25 F#3:0.25 "
                 "G#3:0.5 F#3:0.25 E3:0.25 D#3:0.25 C#3:0.25 B2:0.25 A2:0.25 G#2:0.5 B2:0.5 E3")
SPRING_SONG = song(G, 88, [
    Part("Intro", "intro", "E2:0.5 G#2:0.5 B2:0.5 E3:0.5 G#3:0.5 B3:0.5 G#3:0.5 E3:0.5 B2:0.5 D#3:0.5 F#3:0.5 A3:0.5 B3:2",
         chords="E B7"),
    Part("Theme", "verse", SPRING_A, pickup=0.5, chords="E E E,B7 E E E,B7"),
    Part("Second theme", "chorus", SPRING_B, pickup=0.5, chords="E,A E,A A,B7 E A,E A B7,E"),
    Part("Birdsong", "bridge", SPRING_BIRDS, chords="E E B7 E"),
    Part("The brooks", "interlude", SPRING_BROOKS, chords="E E B7 B7 B7,E"),
    Part("Theme again", "verse", SPRING_A, pickup=0.5, chords="E E E,B7 E E E,B7"),
    Part("Second theme again", "chorus", SPRING_B, pickup=0.5, chords="E,A E,A A,B7 E A,E A B7,E"),
    Part("Coda", "outro", "B2:0.5 E3:0.5 G#3:0.5 B3:0.5 E4:2 E2:4", chords="E E"),
], shapes=SHAPES)

L_SPRING = tune_lesson("std-spring", "Spring", SPRING_SONG, [
    explain("Spring, from The Four Seasons", "Antonio Vivaldi published four violin concertos called The Four Seasons "
            "in 1725. Spring opens with this bright tune, then the solo violin plays birdsong and running brooks.",
            dots("B2", "D#3", "E3", "F#3", "G#3", "A3", "B3", "C#4")),
    notes(G, ["E3", "G#3", "G#3", "G#3", "F#3", "E3", "B3"],
          hint="E at fret 2 on string 4, G sharp at fret 1 on string 3 three times, F sharp at fret 4 on string 4, E, "
               "then open B."),
    explain("E major", "The key of E has four sharps. In first position G sharp is at fret 1 on string 3, D sharp at "
            "fret 1 on string 4, and C sharp at fret 2 on string 2.", dots("D#3", "G#3", "C#4")),
    explain("Sixteenths", "Each beat can split into four sixteenths. In the theme, the quick F sharp, E pair falls in "
            "the second half of beat two.", rhythm([0, 0.5, 1, 1.5, 1.75, 2, 3.5, 3.75])),
    tap([0, 0.5, 1, 1.5, 1.75, 2, 3.5, 3.75], bpm=60, bars=2),
    SPRING_SONG.along("Theme", bpm=72, title=THE_THEME),
    SPRING_SONG.along("Birdsong", bpm=72, title="The birdsong"),
    progression([(E_MAJ, 2), (B7, 1), (E_MAJ, 1)], QUARTERS, bpm=88),
])

# ---------------------------------------------------------------- Rondo alla Turca
# Wolfgang Amadeus Mozart (1756–1791), Piano Sonata K. 331, third movement (published 1784): the A minor theme, the
# C major middle and the A major march, as in the Mutopia edition, two octaves down. 2/4 written as 4/4.
TURCA_RUN = "B2:0.25 A2:0.25 G#2:0.25 A2:0.25"
TURCA_OPEN = (f"C3:0.5 r:0.5 D3:0.25 C3:0.25 B2:0.25 C3:0.25 E3:0.5 r:0.5 F3:0.25 E3:0.25 D#3:0.25 E3:0.25 "
              "B3:0.25 A3:0.25 G#3:0.25 A3:0.25 B3:0.25 A3:0.25 G#3:0.25 A3:0.25")
TURCA_A = (f"{TURCA_RUN} {TURCA_OPEN} C4 A3:0.5 C4:0.5 B3:0.5 A3:0.5 G3:0.5 A3:0.5 B3:0.5 A3:0.5 G3:0.5 A3:0.5 "
           "B3:0.5 A3:0.5 G3:0.5 F#3:0.5 E3 r")
TURCA_A2 = (f"{TURCA_RUN} {TURCA_OPEN} C4:0.5 r:0.5 A3:0.5 B3:0.5 C4:0.5 B3:0.5 A3:0.5 G#3:0.5 A3:0.5 E3:0.5 F3:0.5 "
            "D3:0.5 C3 B2 A2 r")
TURCA_B = ("E3:0.5 F3:0.5 G3:0.5 G3:0.5 A3:0.25 G3:0.25 F3:0.25 E3:0.25 D3 E3:0.5 F3:0.5 "
           "G3:0.5 G3:0.5 A3:0.25 G3:0.25 F3:0.25 E3:0.25 D3 C3:0.5 D3:0.5 "
           "E3:0.5 E3:0.5 F3:0.25 E3:0.25 D3:0.25 C3:0.25 B2 C3:0.5 D3:0.5 "
           "E3:0.5 E3:0.5 F3:0.25 E3:0.25 D3:0.25 C3:0.25 B2 r")
TURCA_C = ("A3:0.5 B3:0.5 C#4 A3:0.5 B3:0.5 C#4:0.5 B3:0.5 A3:0.5 G#3:0.5 F#3:0.5 G#3:0.5 A3:0.5 B3:0.5 G#3:0.5 E3:0.5 "
           "A3:0.5 B3:0.5 C#4 A3:0.5 B3:0.5 C#4:0.5 B3:0.5 A3:0.5 G#3:0.5 F#3:0.5 B3:0.5 G#3:0.5 E3:0.5 A3 r")
TURCA_SONG = song(G, 88, [
    Part("Intro", "intro", "A2:0.5 C3:0.5 E3:0.5 A3:0.5 E3:0.5 C3:0.5 A2 E2:0.5 G#2:0.5 B2:0.5 E3:0.5 B3:2",
         chords="Am E"),
    Part("Theme", "verse", TURCA_A, pickup=1, chords="Am E,Am Em B7,Em"),
    Part("Theme answer", "verse", TURCA_A2, pickup=1, chords="Am E,Am Am,Dm E7,Am"),
    Part("Middle section", "bridge", TURCA_B, pickup=1, chords="C,G7 C,G Am,E Am,E"),
    Part("Theme answer again", "verse", TURCA_A2, pickup=1, chords="Am E,Am Am,Dm E7,Am"),
    Part("Turkish march", "chorus", TURCA_C, pickup=1, chords="A D,E A E,A"),
    Part("March again", "chorus", TURCA_C, pickup=1, chords="A D,E A E,A"),
    Part("Last theme", "verse", TURCA_A, pickup=1, chords="Am E,Am Em B7,Em"),
    Part("Last answer", "verse", TURCA_A2, pickup=1, chords="Am E,Am Am,Dm E7,Am"),
    Part("Coda", "outro", "A2 C#3 E3 A3 A2:4", chords="A A"),
], shapes=SHAPES)

L_TURCA = tune_lesson("std-rondo-alla-turca", "Rondo alla Turca", TURCA_SONG, [
    explain("Mozart's Turkish march", "Mozart published this rondo in 1784 as the last movement of a piano sonata. Its "
            "march copies the sound of Turkish military bands, which Vienna loved at the time.",
            dots("G#2", "A2", "B2", "C3", "D3", "D#3", "E3", "F3")),
    notes(G, ["B2", "A2", "G#2", "A2", "C3", "D3", "C3", "B2", "C3"],
          hint="B at fret 2 on string 5, open A, G sharp at fret 4 on string 6, A, then C at fret 3 on string 5, open D, "
               "C, B and C."),
    explain("A turn around one note", "The theme circles A: B, A, G sharp, A. Each circle is four sixteenths. Then it "
            "climbs a step and circles again.", rhythm([0, 0.25, 0.5, 0.75, 1, 2, 2.25, 2.5, 2.75, 3])),
    tap([0, 0.25, 0.5, 0.75, 1, 2, 2.25, 2.5, 2.75, 3], bpm=56, bars=2),
    TURCA_SONG.along("Theme", bpm=66, title=THE_THEME),
    explain("Into A major", "The march moves from A minor to A major: C becomes C sharp, at fret 2 on string 2. "
            "The tune sounds suddenly bright.", dots("A3", "B3", "C#4")),
    TURCA_SONG.along("Turkish march", bpm=72, title="The march"),
    progression([(Am, 1), (E_MAJ, 1), (Am, 1), (E7, 1)], [0, 2], bpm=80),
])

# ---------------------------------------------------------------- The Stars and Stripes Forever
# John Philip Sousa (1854–1932), 1896 (published 1897): the trio tune, as in the Mutopia piano edition (Cincinnati:
# John Church Company, 1897). A flat → G, cut time written as 4/4. Instrumental: no later lyric or parody is used.
STARS = ("D4:2 C4 B3 B3:2 A#3 B3 B3:6 A#3 B3 B3:2 A#3 B3 D4:2 B3:1.5 D4:0.5 C4:4 A3:2 A3:2 A3:2 G#3 A3 "
         "A3:2 G#3 A3 C4:6 B3 A3 B3 D4:3 E4:3 E4 A3:6 D4:2 D4:2 C4 B3 B3:2 A#3 B3 B3:6 A#3 B3 B3:2 A#3 B3 "
         "C4 B3 A3:1.5 F#4:0.5 A3:4 G3:2 G3:2 G3:2 F#3 G3 Bb3:2 A3 G3 G3:5 G3 A3 B3 D4:0.5 r:0.5 G3 A3 B3 "
         "D4:0.5 r:0.5 D3 E3 B3 A3:4 G3 r:3")
STARS_CHART = "G G G G G G D7 D7 D7 D7 D7 D7 G C D D G G G G B7 B7 Am Em Am C7 G G G G D7 G"
STARS_SONG = song(G, 132, [
    Part("Intro", "intro", "G3 G3 A3 B3 D4:0.5 r:0.5 G3 A3 B3 D4:0.5 r:0.5 D3 E3 B3 A3:4", chords="G G G D7"),
    Part("Trio", "verse", STARS, chords=STARS_CHART),
    Part("Trio again", "chorus", STARS, chords=STARS_CHART),
    Part("Coda", "outro", "D4:0.5 r:0.5 B3:0.5 r:0.5 G3:0.5 r:0.5 G4 G2:4", chords="G G"),
], shapes=SHAPES)

L_STARS = tune_lesson("std-stars-and-stripes", "The Stars and Stripes Forever", STARS_SONG, [
    explain("Sousa's best-known march", "John Philip Sousa wrote this march at the end of 1896, and it was published "
            "in 1897. It is the official national march of the United States. This is its big trio tune.",
            dots("D3", "E3", "F#3", "G3", "G#3", "A3", "A#3", "B3", "C4", "D4", "E4")),
    notes(G, ["D4", "C4", "B3", "B3", "A#3", "B3"],
          hint="D at fret 3 on string 2, C at fret 1, open B, then a dip to A sharp at fret 3 on string 3 and back to B."),
    explain("Long notes in a march", "The trio holds notes across the bar line. Keep counting through them: one, two, "
            "three, four, then on into the next bar.", rhythm([0, 2, 3])),
    STARS_SONG.along("Trio", bpm=100, title="The trio"),
    quiz("The tune keeps dipping a half step below B. Which note is that?", ["A", "A sharp", "G sharp"], 1,
         "A sharp, at fret 3 on string 3, sits a half step below open B and leans right back into it."),
    progression([(G_MAJ, 2), (D7, 2), (G_MAJ, 1), (C, 1), (D, 1), (G_MAJ, 1)], [0, 2], bpm=100),
])

L_MEDLEY_8 = lesson("std-medley-concert", "Concert medley", [
    explain("From Venice to Washington", "Vivaldi, Mozart and Sousa, back to back: a violin concerto, a piano rondo and "
            "a band march, each arranged for your guitar."),
    listen("Which piece starts like this?", [["B2"], ["A2"], ["G#2"], ["A2"], ["C3"]],
           ["Spring", "Rondo alla Turca", "The Stars and Stripes Forever"], 1),
    SPRING_SONG.along("Theme", bpm=80, title="Spring"),
    TURCA_SONG.along("Theme", bpm=76, title="Rondo alla Turca"),
    quiz("Which of these pieces was written for a band?", ["Spring", "Rondo alla Turca",
                                                           "The Stars and Stripes Forever"], 2,
         "Sousa wrote his marches for a military band. Spring is for violin and strings, and the rondo is for piano."),
    STARS_SONG.along("Trio", bpm=116, title="The Stars and Stripes Forever"),
], minutes=7, xp=40, kind="challenge")

# ================================================================ the units

UNITS = [
    unit("std-5", "Carols by candlelight", "Four Christmas carols to sing by candlelight: Wesley and Mendelssohn, "
         "a lullaby, and two tunes from America.", [
             L_HARK, L_AWAY, L_TOWN, L_MIDNIGHT, L_MEDLEY_5,
         ]),
    unit("std-6", "Winter carols", "King's College's opening carol, Holst's midwinter carol, a folk carol and a "
         "grand processional.", [
             L_ROYAL, L_BLEAK, L_HOLLY, L_ANGELS, L_MEDLEY_6,
         ]),
    unit("std-7", "Hymns everyone knows", "Five great hymns in long, singing notes, from 1708 to 1861.", [
        L_ANNE, L_HOLY, L_ABIDE, L_NEARER, L_BEAUTY, L_MEDLEY_HYMNS,
    ]),
    unit("std-8", "Parlor songs and a planet", "Three songs families sang around the piano, then Holst's Jupiter.", [
        L_HOME, L_HARD, L_ROSE, L_JUPITER, L_MEDLEY_7,
    ]),
    unit("std-9", "Concert favorites", "Vivaldi's Spring, Mozart's Turkish rondo and Sousa's best-known march.", [
        L_SPRING, L_TURCA, L_STARS, L_MEDLEY_8,
    ]),
]
