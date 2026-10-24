"""Songs, part 1 (units 1–3): first songs, folk favorites and classical themes I.

Melody only, all public domain or traditional, arranged in first position (frets 0–4).
Each song lesson ends on the whole song (songbook.song): intro, verses and choruses, outro, with the
public-domain words where the tune has them. courses/songs.py joins these UNITS with part 2's.
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, progression, quiz, rhythm, tap, unit
from songbook import Part, song

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
G_MAJ = chord(G, "G", "320003", "21xxx3")
C = chord(G, "C", "x32010", "x32x1x")
D7 = chord(G, "D7", "xx0212", "xxx213")
Dm = chord(G, "Dm", "xx0231", "xxx231")
# Chart-only shapes (the songs' chord charts; no strum step asks for them).
F_MINI = chord(G, "F", "xx3211", "xx3211")
Am = chord(G, "Am", "x02210", "xx231x")
E7 = chord(G, "E7", "020100", "x2x1xx")
A7 = chord(G, "A7", "x02020", "xx1x3x")
D = chord(G, "D", "xx0232", "xxx132")
Em = chord(G, "Em", "022000", "x23xxx")
Bm = chord(G, "Bm", "x24432", "x13421")
B7 = chord(G, "B7", "x21202", "x213x4")
FsM = chord(G, "F#m", "244222", "134111")
A_MAJ = chord(G, "A", "x02220", "xx123x")
E_MAJ = chord(G, "E", "022100", "x231xx")
SHAPES = {c["name"]: c for c in [G_MAJ, C, D7, Dm, F_MINI, Am, E7, A7, D, Em, Bm, B7, FsM, A_MAJ, E_MAJ]}

# ---------------------------------------------------------------- rhythms (beats inside one bar)
QUARTERS = [0, 1, 2, 3]
TWO = [0, 1]                       # a 2/4 bar, one strum per beat

# ---------------------------------------------------------------- shared text (translated once)
FIRST_HALF = "First half"
SECOND_HALF = "Second half"
UP_DOWN = ["Up", "Down"]
THE_VERSE = "The verse"
THE_CHORUS = "The chorus"


def shape(spec):
    return {"type": "chord", "chord": spec}


# ================================================================ 1. First songs

# Mary Had a Little Lamb (rhyme by Sarah Josepha Hale, 1830; traditional American tune), in C.
MARY_1 = "E4:1 D4:1 C4:1 D4:1 E4:1 E4:1 E4:2 D4:1 D4:1 D4:2 E4:1 G4:1 G4:2"
MARY_2 = "E4:1 D4:1 C4:1 D4:1 E4:1 E4:1 E4:1 E4:1 D4:1 D4:1 E4:1 D4:1 C4:4"
MARY = f"{MARY_1} {MARY_2}"
# Twinkle, Twinkle, Little Star ("Ah! vous dirai-je, maman", French, printed 1761), in G.
TWINKLE_A = "G3:1 G3:1 D4:1 D4:1 E4:1 E4:1 D4:2 C4:1 C4:1 B3:1 B3:1 A3:1 A3:1 G3:2"
TWINKLE_B = "D4:1 D4:1 C4:1 C4:1 B3:1 B3:1 A3:2 D4:1 D4:1 C4:1 C4:1 B3:1 B3:1 A3:2"
TWINKLE = f"{TWINKLE_A} {TWINKLE_B} {TWINKLE_A}"
# Ode to Joy (Beethoven, Symphony No. 9, 1824), in C, with its middle section.
ODE_A1 = "E4:1 E4:1 F4:1 G4:1 G4:1 F4:1 E4:1 D4:1 C4:1 C4:1 D4:1 E4:1 E4:1.5 D4:0.5 D4:2"
ODE_A2 = "E4:1 E4:1 F4:1 G4:1 G4:1 F4:1 E4:1 D4:1 C4:1 C4:1 D4:1 E4:1 D4:1.5 C4:0.5 C4:2"
ODE_B = "D4:1 D4:1 E4:1 C4:1 D4:1 E4:0.5 F4:0.5 E4:1 C4:1 D4:1 E4:0.5 F4:0.5 E4:1 D4:1 C4:1 D4:1 G3:2"
ODE = f"{ODE_A1} {ODE_A2} {ODE_B} {ODE_A2}"
# Frère Jacques (French round, printed around 1780), in G.
FRERE_1 = "G3:1 A3:1 B3:1 G3:1 G3:1 A3:1 B3:1 G3:1"
FRERE_2 = "B3:1 C4:1 D4:2 B3:1 C4:1 D4:2"
FRERE_3 = "D4:0.5 E4:0.5 D4:0.5 C4:0.5 B3:1 G3:1 D4:0.5 E4:0.5 D4:0.5 C4:0.5 B3:1 G3:1"
FRERE_4 = "G3:1 D3:1 G3:2 G3:1 D3:1 G3:2"
FRERE = f"{FRERE_1} {FRERE_2} {FRERE_3} {FRERE_4}"
# Jingle Bells, chorus (James Lord Pierpont, 1857), in C.
JINGLE_1 = "E4:1 E4:1 E4:2 E4:1 E4:1 E4:2 E4:1 G4:1 C4:1.5 D4:0.5 E4:4"
JINGLE_2 = "F4:1 F4:1 F4:1.5 F4:0.5 F4:1 E4:1 E4:1 E4:0.5 E4:0.5 E4:1 D4:1 D4:1 E4:1 D4:2 G4:2"
JINGLE_3 = "F4:1 F4:1 F4:1 F4:1 F4:1 E4:1 E4:1 E4:0.5 E4:0.5 G4:1 G4:1 F4:1 D4:1 C4:4"
JINGLE = f"{JINGLE_1} {JINGLE_2} {JINGLE_1} {JINGLE_3}"
# When the Saints Go Marching In (traditional spiritual), in C. Each phrase starts after a rest on beat one.
SAINTS_A = "r:1 C4:1 E4:1 F4:1 G4:4 r:1 C4:1 E4:1 F4:1 G4:4 r:1 C4:1 E4:1 F4:1 G4:2 E4:2 C4:2 E4:2 D4:4"
# "Oh Lord, I want to be in that num-ber": "num-ber" on G, then F.
SAINTS_B = "r:1 E4:1 E4:1 D4:1 C4:3 C4:1 E4:2 G4:1 G4:1 G4:1 F4:3 r:2 E4:1 F4:1 G4:2 E4:2 C4:2 D4:2 C4:4"
SAINTS = f"{SAINTS_A} {SAINTS_B}"

# ---------------------------------------------------------------- unit 1: the whole songs
TRAD = "Traditional"

# Mary Had a Little Lamb: four verses of Hale's rhyme (1830), the last line as intro and outro tag.
MARY_V = Part("Verse 1", "verse", MARY, chords="C C G C C C G C", lyrics=(
    "Ma-ry had a lit-tle lamb, / lit-tle lamb, lit-tle lamb, / Ma-ry had a lit-tle lamb, its / fleece was white as snow."))
MARY_SONG = song(G, 80, [
    Part("Intro", "intro", "D4 D4 E4 D4 C4:4", chords="G C"),
    MARY_V,
    MARY_V.with_lyrics("Verse 2", "Ev-ery-where that Ma-ry went, / Ma-ry went, Ma-ry went, / ev-ery-where that Ma-ry went, the / "
                                  "lamb was sure to go."),
    MARY_V.with_lyrics("Verse 3", "Fol-lowed her to school one day, / school one day, school one day, / fol-lowed her to school one day, "
                                  "which / was a-gainst the rule."),
    MARY_V.with_lyrics("Verse 4", "Made the chil-dren laugh and play, / laugh and play, laugh and play, / made the chil-dren laugh and "
                                  "play to / see a lamb at school."),
    Part("Outro", "outro", "E4 D4 C4 D4 E4 E4 E4:2 D4 D4 E4 D4 C4:4", chords="C C G C",
         lyrics="Ma-ry had a lit-tle lamb, / fleece was white as snow."),
], shapes=SHAPES, words="Sarah Josepha Hale (1830)")

# Twinkle, Twinkle, Little Star: Jane Taylor's verses (1806), each with the opening lines as a refrain.
TW_CHORDS_A = "G C,G C,G D,G"
TW_CHORDS_B = "G,C G,D G,C G,D"
TW_VERSE = Part("Verse 1", "verse", f"{TWINKLE_A} {TWINKLE_B}", chords=f"{TW_CHORDS_A} {TW_CHORDS_B}", lyrics=(
    "Twin-kle, twin-kle, lit-tle star, / how I won-der what you are! / Up a-bove the world so high, / like a dia-mond in the sky."))
TW_CHORUS = Part("Chorus", "chorus", TWINKLE_A, chords=TW_CHORDS_A,
                 lyrics="Twin-kle, twin-kle, lit-tle star, / how I won-der what you are!")
TWINKLE_SONG = song(G, 80, [
    Part("Intro", "intro", "C4 C4 B3 B3 A3 A3 G3:2", chords="C,G D,G"),
    TW_VERSE, TW_CHORUS,
    TW_VERSE.with_lyrics("Verse 2", "When the blaz-ing sun is gone, / when he noth-ing shines up-on, / then you show your lit-tle light, / "
                                    "twin-kle, twin-kle, all the night."),
    TW_CHORUS,
    TW_VERSE.with_lyrics("Verse 3", "Then the trav-'ller in the dark / thanks you for your ti-ny spark; / could not see which way to go / "
                                    "if you did not twin-kle so."),
    TW_CHORUS,
    Part("Outro", "outro", "C4 C4 B3 B3 A3 A3 G3:2 D4:2 B3:2 G3:4", chords="C,G D,G G G"),
], shapes=SHAPES, words="Jane Taylor (1806)")

# Ode to Joy: two stanzas of Schiller's An die Freude (1785), in the German Beethoven set.
ODE_V = Part("Verse 1", "verse", ODE, chords="C G C G C G C G,C G C G G C G C G,C", lyrics=(
    "Freu-de, schö-ner Göt-ter-fun-ken, / Toch-ter aus E-ly-si-um, / wir be-tre-ten feu-er-trun-ken, / Himm-li-sche, dein Hei-lig-tum! / "
    "Dei-ne Zau-ber bin-den _ wie-der, / was die _ Mo-de streng ge-teilt; / al-le Men-schen wer-den Brü-der, / wo dein sanf-ter Flü-gel weilt."))
ODE_SONG = song(G, 72, [
    Part("Intro", "intro", "C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2", chords="C G,C"),
    ODE_V,
    ODE_V.with_lyrics("Verse 2", "Wem der gro-ße Wurf ge-lun-gen, / ei-nes Freun-des Freund zu sein, / wer ein hol-des Weib er-run-gen, / "
                                 "mi-sche sei-nen Ju-bel ein! / Ja, wer auch nur ei-ne _ See-le / sein nennt _ auf dem Er-den-rund! / "
                                 "Und wer's nie ge-konnt, der steh-le / wei-nend sich aus die-sem Bund!"),
    Part("Outro", "outro", ODE_A2, chords="C G C G,C", lyrics="Al-le Men-schen wer-den Brü-der, / wo dein sanf-ter Flü-gel weilt."),
], shapes=SHAPES, words="Friedrich Schiller (1785)")

# Frère Jacques: the French round (about 1780) and its English words, with the bells as intro and outro.
FRERE_V = Part("Verse 1", "verse", FRERE, chords="G G G G G G G G", lyrics=(
    "Frè-re Jac-ques, frè-re Jac-ques, / dor-mez~vous? Dor-mez~vous? / Son-nez les ma-ti-nes, son-nez les ma-ti-nes, / "
    "ding, ding, dong! Ding, ding, dong!"))
FRERE_SONG = song(G, 80, [
    Part("Intro", "intro", FRERE_4, chords="G G"),
    FRERE_V,
    FRERE_V.with_lyrics("Verse 2", "Are you sleep-ing, are you sleep-ing, / Broth-er John? Broth-er John? / Morn-ing bells are ring-ing, "
                                   "morn-ing bells are ring-ing, / ding, dang, dong! Ding, dang, dong!"),
    FRERE_V.instrumental("Solo"),
    FRERE_V.with_lyrics("Verse 3", "Frè-re Jac-ques, frè-re Jac-ques, / dor-mez~vous? Dor-mez~vous? / Son-nez les ma-ti-nes, "
                                   "son-nez les ma-ti-nes, / ding, ding, dong! Ding, ding, dong!"),
    Part("Outro", "outro", f"D4:0.5 E4:0.5 D4:0.5 C4:0.5 B3 G3 {FRERE_4} G3:4", chords="G G G G",
         lyrics="Son-nez les ma-ti-nes, / ding, ding, dong! Ding, ding, dong! _"),
], shapes=SHAPES, words="Traditional (France, about 1780)")

# Jingle Bells: Pierpont's verse (1857), the chorus twice. The verse's high A in bar 15 comes down to G (first position).
JINGLE_VERSE = ("G3 E4 D4 C4 G3:3 G3:0.5 G3:0.5 G3 E4 D4 C4 A3:4 A3 F4 E4 D4 B3:4 G4 G4 F4 D4 E4:4"
                " G3 E4 D4 C4 G3:4 G3 E4 D4 C4 A3:3 A3 A3 F4 E4 D4 G4 G4 G4 G4 G4 F4 E4 D4 C4:2 G4:2")
JINGLE_CHORUS = Part("Chorus", "chorus", JINGLE, chords="C C C C F C D7 G C C C C F C G C", lyrics=(
    "Jin-gle bells, jin-gle bells, jin-gle all the way! / Oh, what fun it is to ride in a one~horse o-pen sleigh, hey! / "
    "Jin-gle bells, jin-gle bells, jin-gle all the way! / Oh, what fun it is to ride in a one~horse o-pen sleigh!"))
JINGLE_SONG = song(G, 80, [
    Part("Intro", "intro", "G4 G4 F4 D4 C4:4", chords="G C"),
    Part("Verse", "verse", JINGLE_VERSE, chords="C C C F F G G C C C C F F G G C,G", lyrics=(
        "Dash-ing through the snow / in a one~horse o-pen sleigh, / o'er the fields we go, / laugh-ing all the way; / "
        "bells on bob-tails ring, / mak-ing spir-its bright, / what fun it is to ride and sing / a sleigh-ing song to-night! Oh!")),
    JINGLE_CHORUS,
    JINGLE_CHORUS,
    Part("Outro", "outro", "G4 G4 F4 D4 C4:4", chords="G C", lyrics="one~horse o-pen sleigh!"),
], shapes=SHAPES, words="James Lord Pierpont (1857)")

# When the Saints Go Marching In: two verses, each with the "Oh Lord" chorus; the last line as intro and outro.
SAINTS_TAG = "r:2 E4 F4 G4:2 E4:2 C4:2 D4:2 C4:4"
SAINTS_V = Part("Verse 1", "verse", SAINTS_A, chords="C C C C C C C G",
                lyrics="Oh when the saints / go march-ing in, / oh when the saints go march-ing in,")
SAINTS_C = Part("Chorus", "chorus", SAINTS_B, chords="C C C F C C G C",
                lyrics="Oh Lord, I want to be in that num-ber, / when the saints go march-ing in.")
SAINTS_SONG = song(G, 76, [
    Part("Intro", "intro", SAINTS_TAG, chords="C C G C"),
    SAINTS_V, SAINTS_C,
    SAINTS_V.with_lyrics("Verse 2", "Oh when the sun / re-fuse to shine, / oh when the sun re-fuse to shine,"),
    SAINTS_C,
    Part("Outro", "outro", SAINTS_TAG, chords="C C G C", lyrics="when the saints go march-ing in."),
], shapes=SHAPES, words="Traditional spiritual")


UNIT_1 = unit("songs-1", "First songs", "Six famous tunes, one note at a time, on the top strings. Slow tempos, big wins.", [
    lesson("song-mary", "Mary Had a Little Lamb", [
        explain("Edison's first recording", "In 1877, Thomas Edison recited this rhyme to test his new phonograph. "
                "The tune uses C and D on string 2, then open E, and G at fret 3 on string 1.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 3, 3)])),
        notes(G, ["E4", "D4", "C4", "D4", "E4", "E4", "E4"], hint="E D C D E E E: open string 1, then string 2 at frets 3 and 1, and back."),
        notes(G, ["D4", "D4", "D4", "E4", "G4", "G4"], hint="D D D at fret 3 on string 2. Then open E, and G at fret 3 on string 1."),
        listen("Did the tune go up or down?", [["E4"], ["G4"], ["G4"]], UP_DOWN, 0),
        along(G, MARY_1, bpm=60, title=FIRST_HALF),
        MARY_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        MARY_SONG.take("Mary Had a Little Lamb"),
    ], minutes=MARY_SONG.minutes(), xp=30, kind="song", arrangement=MARY_SONG.meta()),
    lesson("song-twinkle", "Twinkle, Twinkle, Little Star", [
        explain("A French folk tune", "This melody was first printed in France in 1761, and Mozart later wrote twelve variations on it. "
                "It leaps up, then steps down across strings 2 and 3.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
        notes(G, ["G3", "G3", "D4", "D4", "E4", "E4", "D4"], hint="Open G, a leap up to D at fret 3 on string 2, open E, and back to D."),
        notes(G, ["C4", "C4", "B3", "B3", "A3", "A3", "G3"], hint="Step down in pairs: C at fret 1, open B, A at fret 2 on string 3, open G."),
        quiz("Which other song uses this same tune?", ["Jingle Bells", "The alphabet song", "Yankee Doodle"], 1,
             "The alphabet song and Baa, Baa, Black Sheep both borrow this French melody."),
        along(G, TWINKLE_A, bpm=60, title="Opening phrase"),
        TWINKLE_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        TWINKLE_SONG.take("Twinkle, Twinkle, Little Star"),
    ], minutes=TWINKLE_SONG.minutes(), xp=30, kind="song", arrangement=TWINKLE_SONG.meta()),
    lesson("song-ode-to-joy", "Ode to Joy", [
        explain("Beethoven's Ninth", "Beethoven finished his Ninth Symphony in 1824, and this melody is now the anthem of the European Union. "
                "Here you'll play the whole tune, middle section included.",
                fretboard(G, [(3, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4"], hint="The opening: E E F G G F E D, one step at a time."),
        explain("Two notes in one beat", "In the middle section, E and F share a single beat. "
                "Count one, two-and, three, four, and play E on two and F on the and.", rhythm([0, 1, 1.5, 2, 3])),
        tap([0, 1, 1.5, 2, 3], bpm=60, bars=2),
        notes(G, ["D4", "E4", "F4", "E4", "C4", "D4", "E4", "F4", "E4", "D4", "C4", "D4", "G3"],
              hint="The middle: quick E F pairs on string 1, then down to open G on string 3."),
        along(G, ODE_B, bpm=60, title="The middle section"),
        ODE_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        ODE_SONG.take("Ode to Joy"),
    ], minutes=ODE_SONG.minutes(), xp=35, kind="song", arrangement=ODE_SONG.meta()),
    lesson("song-frere-jacques", "Frère Jacques", [
        explain("A tune that chases itself", "Frère Jacques is a French round, first printed around 1780: a second player starts "
                "the same tune two bars later, and the parts fit together.",
                fretboard(G, [(4, 0), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
        quiz("In a round, the second player…", ["Plays a different tune", "Starts the same tune later", "Plays the tune backward"], 1,
             "Everyone plays the same melody, each starting a little later. The phrases are built to fit on top of each other."),
        notes(G, ["D4", "E4", "D4", "C4", "B3", "G3"], hint="The quick part: D E D C on strings 2 and 1, then B and G."),
        along(G, FRERE_3, bpm=60, title="The quick part"),
        notes(G, ["G3", "D3", "G3"], hint="The ending dips from open G to open D on string 4, then comes back."),
        FRERE_SONG.along("Verse 1", bpm=66, title=THE_VERSE),
        FRERE_SONG.take("Frère Jacques"),
    ], minutes=FRERE_SONG.minutes(), xp=30, kind="song", arrangement=FRERE_SONG.meta()),
    lesson("song-jingle-bells", "Jingle Bells", [
        explain("A sleigh-ride song", "James Lord Pierpont published this song in 1857 as One Horse Open Sleigh. "
                "You'll play its famous chorus, all on strings 1 and 2.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["E4", "G4", "C4", "D4", "E4"], hint="Open E, G at fret 3, down to C and D on string 2, then home to E."),
        explain("Long, then quick", "In that phrase, C rings for a beat and a half and D slips in on the and of four. "
                "Count one, two, three, four-and.", rhythm([0, 1, 2, 3.5])),
        tap([0, 1, 2, 3.5], bpm=66, bars=2),
        along(G, JINGLE_1, bpm=60, title="First line"),
        notes(G, ["F4", "F4", "F4", "F4", "F4", "E4", "E4", "E4", "E4"], hint="The second line sits on F at fret 1, then settles onto open E."),
        JINGLE_SONG.along("Chorus", bpm=66, title=THE_CHORUS),
        JINGLE_SONG.along("Verse", bpm=66, title=THE_VERSE),
        JINGLE_SONG.take("Jingle Bells"),
    ], minutes=JINGLE_SONG.minutes(), xp=35, kind="song", arrangement=JINGLE_SONG.meta()),
    lesson("song-saints", "When the Saints Go Marching In", [
        explain("A New Orleans favorite", "This traditional spiritual became a jazz standard after Louis Armstrong recorded it in 1938. "
                "It uses C, D, E, F and G on strings 2 and 1.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["C4", "E4", "F4", "G4"], hint="The opening: C on string 2, then E, F and G climbing string 1."),
        explain("Start after a rest", "A pickup is a few notes that lead into a strong beat. Here beat one is silent, "
                "and C, E and F lead into a long G.", rhythm([1, 2, 3])),
        tap([1, 2, 3], bpm=72, bars=2),
        along(G, SAINTS_A, bpm=66, title=FIRST_HALF),
        notes(G, ["E4", "E4", "D4", "C4", "C4", "E4", "G4", "G4", "G4", "F4"], hint="The chorus: E E D C, then C E G G G F."),
        SAINTS_SONG.along("Chorus", bpm=66, title=THE_CHORUS),
        SAINTS_SONG.take("When the Saints Go Marching In"),
    ], minutes=SAINTS_SONG.minutes(), xp=35, kind="song", arrangement=SAINTS_SONG.meta()),
    lesson("song-medley-first-songs", "First songs medley", [
        explain("Six songs, one sitting", "No new notes here: all six tunes from this unit, each a little faster than before. "
                "Name the opening by ear, then play."),
        listen("Which song starts like this?", [["E4"], ["D4"], ["C4"], ["D4"], ["E4"], ["E4"], ["E4"]],
               ["Mary Had a Little Lamb", "Ode to Joy", "Jingle Bells"], 0),
        along(G, MARY, bpm=84, title="Mary Had a Little Lamb"),
        along(G, TWINKLE, bpm=84, title="Twinkle, Twinkle, Little Star"),
        along(G, FRERE, bpm=84, title="Frère Jacques"),
        listen("Which song starts like this?", [["C4"], ["E4"], ["F4"], ["G4"]],
               ["Ode to Joy", "When the Saints Go Marching In", "Frère Jacques"], 1),
        along(G, ODE, bpm=80, title="Ode to Joy"),
        along(G, JINGLE, bpm=84, title="Jingle Bells"),
        along(G, SAINTS, bpm=84, title="When the Saints Go Marching In"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 2. Folk favorites

# Oh! Susanna, verse (Stephen Foster, 1848), in G. Starts with a two-note pickup.
SUSANNA_1 = "r:2 G3:1 A3:1 B3:1 D4:1 D4:1 E4:1 D4:1 B3:1 G3:1 A3:1 B3:1 B3:1 A3:1 G3:1 A3:2"
SUSANNA_2 = "G3:1 A3:1 B3:1 D4:1 D4:1 E4:1 D4:1 B3:1 G3:1 A3:1 B3:1 B3:1 A3:1 A3:1 G3:4"
SUSANNA = f"{SUSANNA_1} {SUSANNA_2}"
SUSANNA_CHORDS = [(G_MAJ, 3), (D7, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 1)]
# Camptown Races, verse (Stephen Foster, 1850), in G. Same chord plan as Oh! Susanna.
# "sing this song": the last note of the bar is split for the words.
CAMP_1 = "D4:1 D4:1 B3:1 D4:1 E4:1 D4:1 B3:1 B3:1 B3:1 A3:3 B3:1 A3:3"
CAMP_2 = "D4:1 D4:1 B3:1 D4:1 E4:1 D4:1 B3:1 B3:1 A3:1 A3:1 B3:1 A3:1 G3:4"
CAMP = f"{CAMP_1} {CAMP_2}"
# Old MacDonald Had a Farm, verse (traditional, printed 1917), in G. Chords change every two beats.
OLD_1 = "G3:1 G3:1 G3:1 D3:1 E3:1 E3:1 D3:2 B3:1 B3:1 A3:1 A3:1 G3:3 D3:1"
OLD_2 = "G3:1 G3:1 G3:1 D3:1 E3:1 E3:1 D3:2 B3:1 B3:1 A3:1 A3:1 G3:4"
OLD = f"{OLD_1} {OLD_2}"
OLD_LINE = [(G_MAJ, 2), (C, 1), (G_MAJ, 2), (D7, 1), (G_MAJ, 2)]   # in two-beat bars
# Yankee Doodle, verse (traditional, 18th century), in C.
YANKEE_1 = "C4:1 C4:1 D4:1 E4:1 C4:1 E4:1 D4:1 G3:1 C4:1 C4:1 D4:1 E4:1 C4:2 B3:2"
YANKEE_2 = "C4:1 C4:1 D4:1 E4:1 F4:1 E4:1 D4:1 C4:1 B3:1 G3:1 A3:1 B3:1 C4:2 C4:2"
YANKEE = f"{YANKEE_1} {YANKEE_2}"
# Aura Lee (George R. Poulton, 1861), in C: the verse twice, then the high part.
AURA_A = "G3:1 C4:1 B3:1 C4:1 D4:1 A3:1 D4:2 C4:1 B3:1 A3:1 B3:1 C4:4"
AURA_B = ("E4:1 E4:1 E4:2 E4:1 E4:1 E4:2 E4:1 D4:1 C4:1 D4:1 E4:4"
          " E4:1 E4:1 F4:1 E4:1 D4:1 A3:1 D4:2 C4:1 B3:1 A3:1 B3:1 C4:4")
AURA = f"{AURA_A} {AURA_A} {AURA_B}"
# Drunken Sailor (traditional sea shanty), D Dorian: verse, then chorus.
SAILOR_V = ("A3:1 A3:0.5 A3:0.5 A3:1 A3:0.5 A3:0.5 A3:1 D3:1 F3:1 A3:1"
            " G3:1 G3:0.5 G3:0.5 G3:1 G3:0.5 G3:0.5 G3:1 C3:1 E3:1 G3:1"
            " A3:1 A3:0.5 A3:0.5 A3:1 A3:0.5 A3:0.5 A3:1 B3:1 C4:1 D4:1"
            " C4:1 A3:1 G3:1 E3:1 D3:2 D3:2")
# "and up she ris-es": the last beat of each line splits in two for the words.
SAILOR_C = ("A3:2 A3:2 A3:1 D3:1 F3:1 A3:0.5 A3:0.5 G3:2 G3:2 G3:1 C3:1 E3:1 G3:0.5 G3:0.5"
            " A3:2 A3:2 A3:1 B3:1 C4:1 D4:0.5 D4:0.5 C4:1 A3:1 G3:1 E3:1 D3:2 D3:2")
SAILOR = f"{SAILOR_V} {SAILOR_C}"
SAILOR_CHORDS = [(Dm, 2), (C, 2), (Dm, 2), (C, 1), (Dm, 1)]

# ---------------------------------------------------------------- unit 2: the whole songs

# Oh! Susanna: two of Foster's verses (1848), each with the chorus. The intro is the verse's last bar.
SUS_LINE_A = "B3 D4 D4 E4 D4 B3 G3 A3 B3 B3 A3 G3 A3:2"          # ends on A: half way
SUS_LINE_B = "B3 D4 D4 E4 D4 B3 G3 A3 B3 B3 A3 A3"                # ends, with the next bar, on G
SUS_VERSE = (f"G3 A3 {SUS_LINE_A} G3 A3 {SUS_LINE_B} G3:2 G3 A3 {SUS_LINE_A} G3 A3 {SUS_LINE_B} G3:4")
SUS_CHORUS = f"C4:2 C4:2 E4 E4:2 E4 D4 D4 B3 G3 A3:2 G3 A3 {SUS_LINE_B} G3:4"
SUS_V = Part("Verse 1", "verse", SUS_VERSE, pickup=2, chords="G G G D7 G G D7 G G G G D7 G G D7 G", lyrics=(
    "I come from Al-a-bam-a with my ban-jo on my knee, _ / I'm go-ing to Lou-i-si-an-a, my true love for to see. / "
    "It rained all night the day I left, the weath-er it was dry, _ / the sun so hot I froze to death; Su-san-na, _ don't you cry."))
SUS_C = Part("Chorus", "chorus", SUS_CHORUS, chords="C C G D7 G G D7 G", lyrics=(
    "Oh! Su-san-na, oh don't you cry for me, / for I come from Al-a-bam-a with my ban-jo on my knee."))
SUS_SONG = song(G, 80, [
    Part("Intro", "intro", "B3 B3 A3 A3 G3:4", chords="D7 G"),
    SUS_V, SUS_C,
    SUS_V.with_lyrics("Verse 2", "I had a dream the oth-er night, when ev-ery-thing was still; _ / I thought I saw Su-san-na _ dear, "
                                 "a-com-ing down the hill. / The buck-wheat cake was in her mouth, the tear was in her eye; _ / says I, "
                                 "I'm com-ing from the South, Su-san-na, _ don't you cry."),
    SUS_C,
    Part("Outro", "outro", f"G3 A3 {SUS_LINE_B} G3:4", pickup=2, chords="G G D7 G",
         lyrics="for I come from Al-a-bam-a with my ban-jo on my knee."),
], shapes=SHAPES, words="Stephen Foster (1848)")

# Camptown Races: Foster's first verse (1850), the chorus twice around a verse on the guitar alone.
CAMP_C = Part("Chorus", "chorus", "G3:1.5 G3:0.5 B3 D4 G4:4 E4:1.5 E4:0.5 G4 E4 D4:4 D4:0.5 D4:0.5 D4 B3 D4 "
                                  "E4 D4:0.5 D4:0.5 B3 B3 A3 A3 B3 A3:0.5 A3:0.5 A3 G3:3", chords="G G C G G G D7 G", lyrics=(
    "Gon-na run all night! / Gon-na run all day! / I'll bet my mon-ey on the bob-tail nag, / some-bod-y bet on the bay."))
CAMP_V = Part("Verse 1", "verse", CAMP, chords="G G D7 D7 G G D7 G", lyrics=(
    "The Camp-town la-dies sing this song, / doo-dah! doo-dah! / The Camp-town race-track's five miles long, / oh, doo-dah _ day!"))
CAMP_SONG = song(G, 80, [
    Part("Intro", "intro", "A3 A3 B3 A3 G3:4", chords="D7 G"),
    CAMP_V, CAMP_C,
    CAMP_V.instrumental("Solo"),
    CAMP_C,
    Part("Outro", "outro", "A3 A3 B3 A3:0.5 A3:0.5 A3 G3:3", chords="D7 G", lyrics="some-bod-y bet on the bay."),
], shapes=SHAPES, words="Stephen Foster (1850)")

# Old MacDonald Had a Farm: three animals, each verse with its "here a moo, there a moo".
OLD_MIDDLE = ("D3:0.5 D3:0.5 G3 G3 G3 D3:0.5 D3:0.5 G3 G3 G3 G3:0.5 G3:0.5 G3 G3:0.5 G3:0.5 G3 "
              "G3:0.5 G3:0.5 G3:0.5 G3:0.5 G3 G3")
OLD_LINE_CHORDS = "G C,G G,D7 G"


def old_verse(label, animal, sound):
    words = (f"Old Mac-Don-ald had a farm, / E~I~E~I~O, and / on that farm he had a {animal}, / E~I~E~I~O. / "
             f"With a {sound} {sound} here and a {sound} {sound} there, / here a {sound}, there a {sound}, ev-ery-where a {sound} {sound}. / "
             "Old Mac-Don-ald had a farm, / E~I~E~I~O.")
    return Part(label, "verse", f"{OLD_1} {OLD_2} {OLD_MIDDLE} {OLD_2}", lyrics=words,
                chords=f"{OLD_LINE_CHORDS} {OLD_LINE_CHORDS} G G G G {OLD_LINE_CHORDS}")


OLD_SONG = song(G, 80, [
    Part("Intro", "intro", "B3 B3 A3 A3 G3:4", chords="G,D7 G"),
    old_verse("Verse 1", "cow", "moo"),
    old_verse("Verse 2", "duck", "quack"),
    old_verse("Verse 3", "pig", "oink"),
    Part("Outro", "outro", "B3 B3 A3 A3 G3:4", chords="G,D7 G", lyrics="E~I~E~I~O!"),
], shapes=SHAPES, words="Traditional (printed 1917)")

# Yankee Doodle: two verses with the chorus (low, as it falls under the verse), a solo and a last chorus.
# Verse 2 splits two notes for its extra syllables.
YANKEE_CHORUS = "A3 B3 A3 G3 A3 B3 C4:2 G3 A3 G3 F3 E3:2 C3:2 A3 B3 A3 G3 A3 B3 C4 A3 G3 C4 B3 D4 C4:2 C4:2"
YANKEE_V2 = ("C4 C4 D4 E4 C4 E4 D4 G3:0.5 G3:0.5 C4 C4 D4 E4 C4:2 B3:2 "
             "C4 C4 D4 E4 F4 E4 D4 C4 B3 G3 A3 B3 C4 C4 C4:2")
YANKEE_C = Part("Chorus", "chorus", YANKEE_CHORUS, chords="F C G C F F G C", lyrics=(
    "Yan-kee Doo-dle, keep it up, / Yan-kee Doo-dle dan-dy, / mind the mu-sic and the step, / and with the girls be hand-y."))
YANKEE_V = Part("Verse 1", "verse", YANKEE, chords="C G C G C F G C", lyrics=(
    "Yan-kee Doo-dle went to town / a-rid-ing on a po-ny, / stuck a feath-er in his cap / and called it mac-a-ro-ni."))
YANKEE_SONG = song(G, 88, [
    Part("Intro", "intro", "G3 C4 B3 D4 C4:2 C4:2", chords="G C"),
    YANKEE_V, YANKEE_C,
    Part("Verse 2", "verse", YANKEE_V2, chords="C G C G C F G C", lyrics=(
        "Fa-ther and I went down to camp, / a-long with Cap-tain Good-in', / and there we saw the men and boys / as thick as hast-y pud-din'.")),
    YANKEE_C,
    YANKEE_V.instrumental("Solo"),
    YANKEE_C,
    Part("Outro", "outro", "G3 C4 B3 D4 C4:2 C4:2", chords="G C", lyrics="with the girls be hand-y!"),
], shapes=SHAPES, words="Traditional (18th century)")

# Aura Lee: both of Fosdick's verses (1861), each with its chorus.
AURA_V = Part("Verse 1", "verse", f"{AURA_A} {AURA_A}", chords="C D7 G C C D7 G C", lyrics=(
    "As the black-bird in the spring, / 'neath the wil-low tree, / sat and piped, I heard him sing, / sing of Au-ra Lee."))
AURA_C = Part("Chorus", "chorus", AURA_B, chords="C E7 Am C C D7 G C", lyrics=(
    "Au-ra Lee, Au-ra Lee, / maid of gold-en hair; / sun-shine came a-long with thee, / swal-lows in the air."))
AURA_SONG = song(G, 66, [
    Part("Intro", "intro", "E4 E4 F4 E4 D4 A3 D4:2 C4 B3 A3 B3 C4:4", chords="C D7 G C"),
    AURA_V, AURA_C,
    AURA_V.with_lyrics("Verse 2", "In thy blush the rose was born; / mu-sic, when you spake, / through thine az-ure eye the morn, / "
                                  "spark-ling, seemed to break."),
    AURA_C.with_lyrics("Chorus", "Au-ra Lee, Au-ra Lee, / birds of crim-son wing / nev-er song have sung to me / as in that sweet spring."),
    Part("Outro", "outro", "C4 B3 A3 B3 C4:4", chords="G C", lyrics="sing of Au-ra Lee."),
], shapes=SHAPES, words="W. W. Fosdick (1861)")

# Drunken Sailor: three verses, each with the "Way hay" chorus.
SAILOR_V1 = Part("Verse 1", "verse", SAILOR_V, chords="Dm Dm C C Dm Dm C Dm", lyrics=(
    "What shall we do with a drunk-en sail-or? / What shall we do with a drunk-en sail-or? / What shall we do with a drunk-en sail-or / "
    "ear-ly in the morn-ing?"))
SAILOR_CH = Part("Chorus", "chorus", SAILOR_C, chords="Dm Dm C C Dm Dm C Dm", lyrics=(
    "Way hay and up she ris-es, / way hay and up she ris-es, / way hay and up she ris-es / ear-ly in the morn-ing."))


def sailor_verse(label, line):
    return SAILOR_V1.with_lyrics(label, f"{line}, / {line}, / {line} / ear-ly in the morn-ing.")


SAILOR_SONG = song(G, 80, [
    Part("Intro", "intro", "C4 A3 G3 E3 D3:2 D3:2", chords="C Dm"),
    SAILOR_V1, SAILOR_CH,
    sailor_verse("Verse 2", "Put him in the long-boat till he's so-ber"), SAILOR_CH,
    sailor_verse("Verse 3", "Shave his bel-ly with a rust-y ra-zor"), SAILOR_CH,
    Part("Outro", "outro", "C4 A3 G3 E3 D3:2 D3:2", chords="C Dm", lyrics="ear-ly in the morn-ing!"),
], shapes=SHAPES, words="Traditional sea shanty")


UNIT_2 = unit("songs-2", "Folk favorites", "Campfire songs and a sea shanty, with easy chords to strum on the simplest ones.", [
    lesson("song-oh-susanna", "Oh! Susanna", [
        explain("A Gold Rush anthem", "Stephen Foster published this song in 1848, and gold seekers heading to California "
                "made it their anthem. The verse sits on strings 3, 2 and 1.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
        notes(G, ["B3", "D4", "D4", "E4", "D4", "B3", "G3", "A3"], hint="Open B, D at fret 3, open E, then back down to open G and A at fret 2."),
        along(G, SUSANNA_1.replace("A3:2", "A3:4"), bpm=60, title=FIRST_HALF),
        notes(G, ["B3", "B3", "A3", "A3", "G3"], hint="The last bar: B B A A, then home to open G."),
        SUS_SONG.along("Chorus", bpm=66, title=THE_CHORUS),
        explain("Two chords: G and D7", "G sounds like home, and D7 pulls back toward it. The verse is three bars of G, "
                "one of D7, two of G, then D7 and G.", shape(D7)),
        progression(SUSANNA_CHORDS, QUARTERS, bpm=66),
        SUS_SONG.take("Oh! Susanna"),
    ], minutes=SUS_SONG.minutes(), xp=30, kind="song", arrangement=SUS_SONG.meta()),
    lesson("song-camptown-races", "Camptown Races", [
        explain("Same chords, new race", "Stephen Foster wrote this racing song in 1850, two years after Oh! Susanna. "
                "It uses the same notes and the same two chords.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
        notes(G, ["D4", "D4", "B3", "D4", "E4", "D4", "B3"], hint="D D B D, up to open E, then D and B. Strings 2 and 1."),
        explain("Short, then long", "Twice in the first line, a quick B leads into an A that rings for three beats. "
                "Pick the A once and let it ring.", rhythm([0, 1])),
        tap([0, 1], bpm=66, bars=2),
        along(G, CAMP_1, bpm=60, title="First line"),
        CAMP_SONG.along("Chorus", bpm=66, title=THE_CHORUS),
        progression(SUSANNA_CHORDS, QUARTERS, bpm=72),
        CAMP_SONG.take("Camptown Races"),
    ], minutes=CAMP_SONG.minutes(), xp=30, kind="song", arrangement=CAMP_SONG.meta()),
    lesson("song-old-macdonald", "Old MacDonald Had a Farm", [
        explain("Down to string 4", "This farmyard song was first printed in 1917, but people sang versions of it long before. "
                "Its tune reaches down to D and E on string 4.",
                fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0)])),
        notes(G, ["G3", "G3", "G3", "D3", "E3", "E3", "D3"], hint="Open G three times, down to open D, E at fret 2 on string 4, back to D."),
        notes(G, ["B3", "B3", "A3", "A3", "G3"], hint="Then up: open B twice, A at fret 2 on string 3, and home to open G."),
        along(G, OLD_1, bpm=63, title="First line"),
        OLD_SONG.along("Verse 1", bpm=72, title=THE_VERSE),
        explain("Count in twos", "Here each chord lasts two beats, so the strum counts one, two. "
                "The order is G, G, C, G, then G, D7, G, G. Change early.", shape(C)),
        progression(OLD_LINE + OLD_LINE, TWO, bpm=66, beats_per_bar=2),
        OLD_SONG.take("Old MacDonald Had a Farm"),
    ], minutes=OLD_SONG.minutes(), xp=30, kind="song", arrangement=OLD_SONG.meta()),
    lesson("song-yankee-doodle", "Yankee Doodle", [
        explain("A song that changed sides", "British soldiers first sang this tune to mock American colonists. "
                "By the end of the Revolution, the Americans had made it their own.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1)])),
        notes(G, ["C4", "C4", "D4", "E4", "C4", "E4", "D4", "G3"], hint="C C D E, C E D, then a drop to open G on string 3."),
        along(G, YANKEE_1, bpm=66, title=FIRST_HALF),
        quiz("The first half ends on B. How does that feel?", ["Finished", "Unfinished, like a question"], 1,
             "B sits just below C and leans toward it. The second half answers by landing on C."),
        notes(G, ["F4", "E4", "D4", "C4", "B3", "G3", "A3", "B3", "C4"], hint="The last line: down from F on string 1, dip to open G, then climb back to C."),
        along(G, YANKEE, bpm=72, title="Yankee Doodle"),
        notes(G, ["A3", "B3", "A3", "G3", "A3", "B3", "C4", "G3", "A3", "G3", "F3", "E3", "C3"],
              hint="The chorus sits low: A at fret 2 on string 3, open B, then F and E on string 4 and C on string 5."),
        YANKEE_SONG.along("Chorus", bpm=72, title=THE_CHORUS),
        YANKEE_SONG.take("Yankee Doodle"),
    ], minutes=YANKEE_SONG.minutes(), xp=30, kind="song", arrangement=YANKEE_SONG.meta()),
    lesson("song-aura-lee", "Aura Lee", [
        explain("From 1861 to rock and roll", "George Poulton published this ballad in 1861. "
                "Nearly a century later, its melody became the tune of Love Me Tender.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1)])),
        notes(G, ["G3", "C4", "B3", "C4", "D4", "A3", "D4"], hint="Up to C, down to open B and back, then D, a dip to A, and D again."),
        along(G, AURA_A, bpm=60, title="Opening phrase"),
        explain("Let it sing", "Aura Lee is a slow ballad. Keep each finger down until the next note sounds, "
                "so the notes join smoothly."),
        notes(G, ["E4", "E4", "F4", "E4", "D4", "A3", "D4"], hint="The high part: open E, F at fret 1, then down to D, A, and D again."),
        along(G, AURA_B, bpm=60, title="The high part"),
        AURA_SONG.take("Aura Lee"),
    ], minutes=AURA_SONG.minutes(), xp=35, kind="song", arrangement=AURA_SONG.meta()),
    lesson("song-drunken-sailor", "Drunken Sailor", [
        explain("Pull together", "Sailors sang shanties like this one so a whole crew could haul a rope on the same beat. "
                "This one is in a minor key, which sounds darker.",
                fretboard(G, [(5, 3, 3), (4, 0), (4, 2, 2), (4, 3, 3), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
        notes(G, ["A3", "D3", "F3", "A3", "G3", "C3", "E3", "G3"],
              hint="A, down to open D, then F at fret 3 and A. Then G, down to C on string 5, E and G."),
        explain("Long, short-short", "The verse opens on one repeated note: long, short-short, long, short-short. "
                "Tap it before you play it.", rhythm([0, 1, 1.5, 2, 3, 3.5])),
        tap([0, 1, 1.5, 2, 3, 3.5], bpm=66, bars=2),
        notes(G, ["A3", "B3", "C4", "D4", "C4", "A3", "G3", "E3", "D3"], hint="Climb A B C D, then fall C A G E down to open D."),
        along(G, SAILOR_V, bpm=60, title="Verse"),
        SAILOR_SONG.along("Chorus", bpm=72, title=THE_CHORUS),
        explain("D minor and C", "Two chords carry the whole shanty. They trade places every two bars, then every bar at the end. "
                "Strum D minor from string 4.", shape(Dm)),
        progression(SAILOR_CHORDS, QUARTERS, bpm=66),
        SAILOR_SONG.take("Drunken Sailor"),
    ], minutes=SAILOR_SONG.minutes(), xp=35, kind="song", arrangement=SAILOR_SONG.meta()),
    lesson("song-medley-folk", "Folk medley", [
        explain("Campfire set list", "No new notes or chords: all six songs from this unit, one after another, "
                "each a little faster than before."),
        listen("Which song starts like this?", [["D4"], ["D4"], ["B3"], ["D4"], ["E4"], ["D4"], ["B3"]],
               ["Oh! Susanna", "Camptown Races", "Yankee Doodle"], 1),
        along(G, SUSANNA, bpm=76, title="Oh! Susanna"),
        along(G, CAMP, bpm=76, title="Camptown Races"),
        along(G, OLD, bpm=80, title="Old MacDonald Had a Farm"),
        along(G, YANKEE, bpm=92, title="Yankee Doodle"),
        along(G, AURA, bpm=72, title="Aura Lee"),
        progression(SAILOR_CHORDS, QUARTERS, bpm=72),
        along(G, SAILOR, bpm=80, title="Drunken Sailor"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 3. Classical themes I

# Canon in D (Johann Pachelbel, d. 1706), simplified: the ground bass an octave up, the first violin line,
# and a closing D.
CANON_BASS = "D4:1 A3:1 B3:1 F#3:1 G3:1 D3:1 G3:1 A3:1"
CANON_1 = "F#4:1 E4:1 D4:1 C#4:1 B3:1 A3:1 B3:1 C#4:1"
CANON_2 = "D4:1 C#4:1 B3:1 A3:1 G3:1 F#3:1 G3:1 E3:1"
CANON = f"{CANON_BASS} {CANON_1} {CANON_2} D3:4"
# Largo, English horn theme (Antonín Dvořák, Symphony No. 9 "From the New World", 1893), in C.
LARGO_1 = "E4:1.5 G4:0.5 G4:2 E4:1.5 D4:0.5 C4:2 D4:1.5 E4:0.5 G4:1.5 E4:0.5 D4:4"
LARGO_2 = "E4:1.5 G4:0.5 G4:2 E4:1.5 D4:0.5 C4:2 D4:1.5 E4:0.5 D4:1.5 C4:0.5 C4:4"
LARGO = f"{LARGO_1} {LARGO_2}"
# Brahms' Lullaby (Wiegenlied, Op. 49 No. 4, 1868), in G, 3/4. Each half ends by leading into the next bar.
BRAHMS_1 = ("r:2 B3:0.5 B3:0.5 D4:2 B3:0.5 B3:0.5 D4:2 B3:0.5 D4:0.5 G4:1 F#4:1.5 E4:0.5"
            " E4:1 D4:1 A3:0.5 B3:0.5 C4:1 A3:1 A3:0.5 B3:0.5 C4:2 A3:0.5 C4:0.5 F#4:0.5 E4:0.5 D4:1 F#4:1 G4:2")
BRAHMS_2 = ("G3:0.5 G3:0.5 G4:2 E4:0.5 C4:0.5 D4:2 B3:0.5 G3:0.5 C4:1 D4:1 E4:1 D4:2"
            " G3:0.5 G3:0.5 G4:2 E4:0.5 C4:0.5 D4:2 B3:0.5 G3:0.5 C4:1 B3:1 A3:1 G3:3")
BRAHMS = f"{BRAHMS_1} {BRAHMS_2}"
# Minuet in G (Christian Petzold, Notebook for Anna Magdalena Bach, 1725), first section an octave down, 3/4.
MINUET_1 = "D4:1 G3:0.5 A3:0.5 B3:0.5 C4:0.5 D4:1 G3:1 G3:1 E4:1 C4:0.5 D4:0.5 E4:0.5 F#4:0.5 G4:1 G3:1 G3:1"
MINUET_2 = "C4:1 D4:0.5 C4:0.5 B3:0.5 A3:0.5 B3:1 C4:0.5 B3:0.5 A3:0.5 G3:0.5 F#3:1 G3:0.5 A3:0.5 B3:0.5 G3:0.5 A3:3"
MINUET_3 = "C4:1 D4:0.5 C4:0.5 B3:0.5 A3:0.5 B3:1 C4:0.5 B3:0.5 A3:0.5 G3:0.5 A3:1 B3:0.5 A3:0.5 G3:0.5 F#3:0.5 G3:3"
MINUET = f"{MINUET_1} {MINUET_2} {MINUET_1} {MINUET_3}"
# In the Hall of the Mountain King (Edvard Grieg, Peer Gynt, 1875), opening theme in E minor on the low strings.
KING_1 = "E2:0.5 F#2:0.5 G2:0.5 A2:0.5 B2:0.5 G2:0.5 B2:1 A#2:0.5 F#2:0.5 A#2:1 A2:0.5 F2:0.5 A2:1"
KING_2 = "E2:0.5 F#2:0.5 G2:0.5 A2:0.5 B2:0.5 G2:0.5 B2:0.5 E3:0.5 D3:0.5 B2:0.5 G2:0.5 B2:0.5 D3:2"
KING = f"{KING_1} {KING_2}"
# Für Elise (Beethoven, 1810), opening simplified: A minor, an octave down, 3/8 counted in eighth notes.
ELISE_1 = ("r:2 E4:0.5 D#4:0.5 E4:0.5 D#4:0.5 E4:0.5 B3:0.5 D4:0.5 C4:0.5 A3:1 r:0.5 C3:0.5 E3:0.5 A3:0.5"
           " B3:1 r:0.5 E3:0.5 G#3:0.5 B3:0.5 C4:1 r:0.5 E3:0.5 E4:0.5 D#4:0.5")
ELISE_2 = ("E4:0.5 D#4:0.5 E4:0.5 B3:0.5 D4:0.5 C4:0.5 A3:1 r:0.5 C3:0.5 E3:0.5 A3:0.5"
           " B3:1 r:0.5 E3:0.5 C4:0.5 B3:0.5 A3:3")
ELISE = f"{ELISE_1} {ELISE_2}"

# ---------------------------------------------------------------- unit 3: the whole pieces (instrumental)

# Canon in D: the ground, the two violin lines, the famous running line (an octave down, in first position) and a
# broken-chord variation over the ground's eight chords, one a beat.
CANON_CHORDS = "D,A,Bm,F#m G,D,G,A"
CANON_RUN = ("D3:0.5 F#3:0.5 A3:0.5 G3:0.5 F#3:0.5 D3:0.5 F#3:0.5 E3:0.5 "
             "D3:0.5 B2:0.5 D3:0.5 A2:0.5 G2:0.5 B2:0.5 A2:0.5 G2:0.5")
CANON_BROKEN = ("D4:0.5 A3:0.5 C#4:0.5 A3:0.5 B3:0.5 F#3:0.5 A3:0.5 F#3:0.5 "
                "G3:0.5 D3:0.5 F#3:0.5 D3:0.5 G3:0.5 B3:0.5 A3:0.5 C#4:0.5")
CANON_THEME = Part("Theme", "verse", f"{CANON_1} {CANON_2}", chords=f"{CANON_CHORDS} {CANON_CHORDS}")
CANON_SONG = song(G, 66, [
    Part("Intro", "intro", f"{CANON_BASS} {CANON_BASS}", chords=f"{CANON_CHORDS} {CANON_CHORDS}"),
    CANON_THEME,
    Part("Variation 1", "solo", f"{CANON_RUN} {CANON_RUN}", chords=f"{CANON_CHORDS} {CANON_CHORDS}"),
    CANON_THEME,
    Part("Variation 2", "solo", f"{CANON_BROKEN} {CANON_BROKEN}", chords=f"{CANON_CHORDS} {CANON_CHORDS}"),
    CANON_THEME,
    Part("Outro", "outro", f"{CANON_BASS} F#3:2 A3:2 D3:4", chords=f"{CANON_CHORDS} D D"),
], shapes=SHAPES)

# Largo: the theme, its middle strain (an octave down, in first position), the theme again.
LARGO_THEME = Part("Theme", "verse", LARGO, chords="C C G G C C G C")
LARGO_SONG = song(G, 66, [
    Part("Intro", "intro", "E3:2 G3:2 C4:4", chords="C C"),
    LARGO_THEME,
    Part("Bridge", "bridge", "G3:1.5 A3:0.5 C4:2 A3:1.5 G3:0.5 E3:2 G3:1.5 A3:0.5 C4:1.5 A3:0.5 G3:4 "
                             "G3:1.5 A3:0.5 C4:2 A3:1.5 G3:0.5 E3:2 D3:1.5 E3:0.5 G3:1.5 E3:0.5 D3:4", chords="C Am F G C Am G G"),
    LARGO_THEME,
    Part("Outro", "outro", "D4:1.5 E4:0.5 D4:1.5 C4:0.5 C4:4", chords="G C"),
], shapes=SHAPES)

# Brahms' Lullaby: both halves of the tune, twice, after a rocking intro.
BRAHMS_A = ("B3:0.5 B3:0.5 D4:2 B3:0.5 B3:0.5 D4:2 B3:0.5 D4:0.5 G4:1 F#4:1.5 E4:0.5 E4:1 D4:1 A3:0.5 B3:0.5 "
            "C4:1 A3:1 A3:0.5 B3:0.5 C4:2 A3:0.5 C4:0.5 F#4:0.5 E4:0.5 D4:1 F#4:1 G4:3")
BRAHMS_B = ("G3:0.5 G3:0.5 G4:2 E4:0.5 C4:0.5 D4:2 B3:0.5 G3:0.5 C4 D4 E4 D4:2 "
            "G3:0.5 G3:0.5 G4:2 E4:0.5 C4:0.5 D4:2 B3:0.5 G3:0.5 C4 B3 A3 G3:3")
BRAHMS_PA = Part("Part A", "verse", BRAHMS_A, pickup=1, chords="G G D7 D7 D7 D7 D7 G")
BRAHMS_PB = Part("Part B", "chorus", BRAHMS_B, pickup=1, chords="C G D7 G C G D7 G")
BRAHMS_SONG = song(G, 72, [
    Part("Intro", "intro", "G3 B3 D4 G4:3 D3 F#3 A3 D4:3", chords="G G D7 D7"),
    BRAHMS_PA, BRAHMS_PB, BRAHMS_PA, BRAHMS_PB,
    Part("Outro", "outro", "C4 B3 A3 G3:3", chords="D7 G"),
], beats_per_bar=3, shapes=SHAPES)

# Minuet in G: the first section, the second (its first half two octaves under the original, to stay in first
# position) and the first again, as the dance repeats.
MINUET_B = ("B3 G3:0.5 A3:0.5 B3:0.5 G3:0.5 A3 D3:0.5 E3:0.5 F#3:0.5 D3:0.5 G3 E3:0.5 F#3:0.5 G3:0.5 D3:0.5 "
            "C#3 B2:0.5 C#3:0.5 A2 A2:0.5 B2:0.5 C#3:0.5 D3:0.5 E3:0.5 F#3:0.5 G3 F#3 E3 F#3 A2 C#3 D3:3 "
            "D4 G3:0.5 F#3:0.5 G3 E4 G3:0.5 F#3:0.5 G3 D4 C4 B3 A3:0.5 G3:0.5 F#3:0.5 G3:0.5 A3 "
            "D3:0.5 E3:0.5 F#3:0.5 G3:0.5 A3:0.5 B3:0.5 C4 B3 A3 B3:0.5 D4:0.5 G3 F#3 G3:3")
MINUET_A = Part("Part A", "verse", MINUET, chords="G G C G C G D D G G C G C G D G")
MINUET_SONG = song(G, 72, [
    Part("Intro", "intro", "G3 B3 D4 G3:3", chords="G G"),
    MINUET_A,
    Part("Part B", "bridge", MINUET_B, chords="G D Em A D Em A D G C G D G Am D G"),
    MINUET_A,
], beats_per_bar=3, shapes=SHAPES)

# In the Hall of the Mountain King: the theme low, up a fifth, up an octave and low again, then the crash.
KING_FIFTH = ("B2:0.5 C#3:0.5 D3:0.5 E3:0.5 F#3:0.5 D3:0.5 F#3:1 F3:0.5 C#3:0.5 F3:1 E3:0.5 C3:0.5 E3:1 "
              "B2:0.5 C#3:0.5 D3:0.5 E3:0.5 F#3:0.5 D3:0.5 F#3:0.5 B3:0.5 A3:0.5 F#3:0.5 D3:0.5 F#3:0.5 A3:2")
KING_HIGH = ("E3:0.5 F#3:0.5 G3:0.5 A3:0.5 B3:0.5 G3:0.5 B3:1 A#3:0.5 F#3:0.5 A#3:1 A3:0.5 F3:0.5 A3:1 "
             "E3:0.5 F#3:0.5 G3:0.5 A3:0.5 B3:0.5 G3:0.5 B3:0.5 E4:0.5 D4:0.5 B3:0.5 G3:0.5 B3:0.5 D4:2")
KING_THEME = Part("Theme", "verse", f"{KING} {KING}", chords="Em B7,Am Em G Em B7,Am Em G")
KING_SONG = song(G, 92, [
    Part("Intro", "intro", "E2 r:1 B2 r:1 E2 r:1 B2 r:1", chords="Em Em"),
    KING_THEME,
    Part("Theme up a fifth", "verse", f"{KING_FIFTH} {KING_FIFTH}", chords="Bm Bm,Em Bm D Bm Bm,Em Bm D"),
    Part("Theme up an octave", "chorus", f"{KING_HIGH} {KING_HIGH}", chords="Em B7,Am Em G Em B7,Am Em G"),
    KING_THEME,
    Part("Coda", "outro", "E3:0.5 E3:0.5 E3:0.5 E3:0.5 B2:0.5 B2:0.5 B2:0.5 B2:0.5 G2:0.5 G2:0.5 G2:0.5 G2:0.5 "
                          "E2:0.5 E2:0.5 E2:0.5 E2:0.5 B2 r:1 B2 r:1 E2:2 r:2", chords="Em Em B7 Em"),
], shapes=SHAPES)

# Für Elise: the rondo's opening section and its brighter middle, A A B A B A, then two closing bars.
ELISE_A = ("E4:0.5 D#4:0.5 E4:0.5 D#4:0.5 E4:0.5 B3:0.5 D4:0.5 C4:0.5 A3:1 r:0.5 C3:0.5 E3:0.5 A3:0.5 "
           "B3:1 r:0.5 E3:0.5 G#3:0.5 B3:0.5 C4:1 r:0.5 E3:0.5 E4:0.5 D#4:0.5 "
           "E4:0.5 D#4:0.5 E4:0.5 B3:0.5 D4:0.5 C4:0.5 A3:1 r:0.5 C3:0.5 E3:0.5 A3:0.5 B3:1 r:0.5 E3:0.5 C4:0.5 B3:0.5 A3:3")
ELISE_B = ("B3:0.5 C4:0.5 D4:0.5 E4:1.5 G3:0.5 F4:0.5 E4:0.5 D4:1.5 F3:0.5 E4:0.5 D4:0.5 "
           "C4:1.5 E3:0.5 D4:0.5 C4:0.5 B3:1 r:0.5 E3:0.5 E4:0.5 r:0.5 D#4:0.5 E4:0.5 D#4:0.5 E4:0.5 r:1")
ELISE_PA = Part("Part A", "verse", ELISE_A, pickup=1, chords="Am Am E Am Am Am E Am")
ELISE_PB = Part("Part B", "bridge", ELISE_B, pickup=1.5, chords="C G Am E E")
ELISE_SONG = song(G, 80, [
    ELISE_PA, ELISE_PA, ELISE_PB, ELISE_PA, ELISE_PB, ELISE_PA,
    Part("Coda", "outro", "A3:1 r:0.5 C3:0.5 E3:0.5 A3:0.5 A2:3", chords="Am Am"),
], beats_per_bar=3, shapes=SHAPES)


UNIT_3 = unit("songs-3", "Classical themes I", "Famous themes by Pachelbel, Dvořák, Brahms, Petzold, Grieg and Beethoven, in first position.", [
    lesson("song-canon-in-d", "Canon in D", [
        explain("Eight notes, over and over", "Johann Pachelbel wrote this canon over 300 years ago. Its bass repeats "
                "the same eight notes the whole way through while violins weave melodies above.",
                fretboard(G, [(4, 0), (4, 2, 2), (4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 2, 2), (2, 3, 3), (1, 0), (1, 2, 2)])),
        notes(G, ["D4", "A3", "B3", "F#3", "G3", "D3", "G3", "A3"], hint="The bass, moved up an octave: D, A, B, F sharp, G, D, G, A."),
        quiz("What does the bass do all through the Canon?", ["Repeats the same eight notes", "Plays a new tune each time", "Stays silent until the end"], 0,
             "A repeating bass like this is called a ground. Everything else in the piece is built on top of it."),
        along(G, f"{CANON_BASS} {CANON_BASS}", bpm=60, title="The bass, twice"),
        explain("Sharps on the way down", "A sharp is one fret above its letter. The melody uses C sharp on string 2, fret 2, "
                "and F sharp on string 4, fret 4. Reach that one with your little finger.",
                fretboard(G, [(2, 2, 2), (4, 4, 4)])),
        notes(G, ["F#4", "E4", "D4", "C#4", "B3", "A3", "B3", "C#4"], hint="The first violin line: down from F sharp on string 1, then back up to C sharp."),
        along(G, f"{CANON_1} {CANON_2}", bpm=60, title="The melody"),
        CANON_SONG.take("Canon in D"),
    ], minutes=CANON_SONG.minutes(), xp=35, kind="song", arrangement=CANON_SONG.meta()),
    lesson("song-largo", "Largo, New World Symphony", [
        explain("A melody from America", "Antonín Dvořák wrote this theme for English horn in 1893, in his Symphony "
                "From the New World, while he was living in New York.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 3, 3)])),
        notes(G, ["E4", "G4", "G4", "E4", "D4", "C4"], hint="Open E, G at fret 3 on string 1, back to E, then D and C on string 2."),
        explain("Long, short, long", "Most bars open with a long note and a quick one. Count one, two-and, three: "
                "the quick note lands on the and of two.", rhythm([0, 1.5, 2])),
        tap([0, 1.5, 2], bpm=60, bars=2),
        along(G, LARGO_1, bpm=60, title="First line"),
        notes(G, ["D4", "E4", "D4", "C4", "C4"], hint="The ending: D, E, D, then settle on C and let it ring."),
        LARGO_SONG.take("Largo"),
    ], minutes=LARGO_SONG.minutes(), xp=30, kind="song", arrangement=LARGO_SONG.meta()),
    lesson("song-brahms-lullaby", "Brahms' Lullaby", [
        explain("A gift for a baby", "Johannes Brahms wrote this lullaby in 1868 for a friend's newborn son. "
                "It sways in three, like a cradle: a long note, then two quick ones.", rhythm([0, 2, 2.5], beats_per_bar=3)),
        tap([0, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
        notes(G, ["B3", "B3", "D4", "B3", "B3", "D4"], hint="The opening rocks between open B and D at fret 3 on string 2."),
        along(G, BRAHMS_1.replace("G4:2", "G4:3"), bpm=66, beats_per_bar=3, title=FIRST_HALF),
        notes(G, ["G3", "G3", "G4"], hint="Open G on string 3, then the same note an octave higher: G at fret 3 on string 1."),
        along(G, f"r:2 {BRAHMS_2}", bpm=66, beats_per_bar=3, title=SECOND_HALF),
        BRAHMS_SONG.take("Brahms' Lullaby"),
    ], minutes=BRAHMS_SONG.minutes(), xp=35, kind="song", arrangement=BRAHMS_SONG.meta()),
    lesson("song-minuet-in-g", "Minuet in G", [
        explain("From Bach's family notebook", "This minuet appears in a 1725 notebook Bach gave his wife, Anna Magdalena. "
                "Scholars now credit it to his fellow composer Christian Petzold.",
                fretboard(G, [(4, 4, 4), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0), (1, 2, 2), (1, 3, 3)])),
        notes(G, ["D4", "G3", "A3", "B3", "C4", "D4", "G3", "G3"], hint="D at fret 3 on string 2, then climb from open G: A, B, C, D. Then two open Gs."),
        explain("A dance in three", "A minuet is a dance in three. Most bars start with a long beat, then quick pairs: "
                "one, two-and, three-and.", rhythm([0, 1, 1.5, 2, 2.5], beats_per_bar=3)),
        tap([0, 1, 1.5, 2, 2.5], bpm=63, bars=2, beats_per_bar=3),
        notes(G, ["E4", "C4", "D4", "E4", "F#4", "G4"], hint="Open E, back to C and D on string 2, then E, F sharp and G on string 1."),
        along(G, f"{MINUET_1} {MINUET_2}", bpm=63, beats_per_bar=3, title=FIRST_HALF),
        notes(G, ["A3", "B3", "A3", "G3", "F#3", "G3"], hint="The ending: A B A G, then F sharp at fret 4 on string 4, and home to G."),
        notes(G, ["B3", "A3", "D3", "G3", "C#3", "B2", "A2", "D3"],
              hint="The second section starts low: open B, A, open D, then C sharp at fret 4 and B at fret 2 on string 5, and open A."),
        MINUET_SONG.along("Part B", bpm=63, title="The middle section"),
        MINUET_SONG.take("Minuet in G"),
    ], minutes=MINUET_SONG.minutes(), xp=35, kind="song", arrangement=MINUET_SONG.meta()),
    lesson("song-mountain-king", "In the Hall of the Mountain King", [
        explain("The trolls' march", "Grieg wrote this for the play Peer Gynt in 1875. It pictures trolls in their king's hall, "
                "and it starts quietly and keeps speeding up.",
                fretboard(G, [(6, 0), (6, 1, 1), (6, 2, 2), (6, 3, 3), (5, 0), (5, 1, 1), (5, 2, 2), (4, 0), (4, 2, 2)])),
        notes(G, ["E2", "F#2", "G2", "A2", "B2", "G2", "B2"], hint="Climb from open string 6: F sharp at fret 2, G at fret 3, open A, B at fret 2."),
        notes(G, ["A#2", "F#2", "A#2", "A2", "F2", "A2"], hint="The creeping part: A sharp at fret 1 on string 5, then open A with F at fret 1 on string 6."),
        quiz("Where is A sharp on string 5?", ["Fret 1", "Fret 2", "Open"], 0,
             "A sharp is one fret above A, and A is open string 5. So A sharp is fret 1."),
        along(G, KING_1, bpm=60, title="First two bars"),
        along(G, KING, bpm=66, title="The theme"),
        along(G, f"{KING} {KING}", bpm=80, title="Twice, a little faster"),
        KING_SONG.along("Theme up a fifth", bpm=80, title="Up a fifth"),
        KING_SONG.take("In the Hall of the Mountain King"),
    ], minutes=KING_SONG.minutes(), xp=35, kind="song", arrangement=KING_SONG.meta()),
    lesson("song-fur-elise", "Für Elise", [
        explain("Published 40 years late", "Beethoven wrote this piano piece in 1810, but it wasn't published until 1867, "
                "forty years after he died. This simplified version keeps the famous opening.",
                fretboard(G, [(5, 3, 3), (4, 2, 2), (3, 1, 1), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (2, 4, 4), (1, 0)])),
        notes(G, ["E4", "D#4", "E4", "D#4", "E4", "B3", "D4", "C4", "A3"],
              hint="Rock between open E and D sharp at fret 4 on string 2, then walk down B, D, C to A."),
        explain("Quick notes in threes", "Each bar has three beats. After the long A comes a short rest, then three quick notes "
                "climb: C, E, A. Lift your finger for the rest, but keep counting.", rhythm([0, 1.5, 2, 2.5], beats_per_bar=3)),
        tap([0, 1.5, 2, 2.5], bpm=60, bars=2, beats_per_bar=3),
        notes(G, ["A3", "C3", "E3", "A3", "B3", "E3", "G#3", "B3"],
              hint="A, then C on string 5, E and A. Then B, E, G sharp at fret 1 on string 3, and B."),
        along(G, ELISE_1, bpm=60, beats_per_bar=3, title="The opening"),
        along(G, ELISE, bpm=66, beats_per_bar=3, title="Für Elise"),
        notes(G, ["E4", "G3", "F4", "E4", "D4", "F3", "E4", "D4", "C4", "E3", "D4", "C4"],
              hint="The middle: each phrase dips to a low note, then steps down. E G F E, D F E D, C E D C."),
        ELISE_SONG.along("Part B", bpm=66, title="The middle section"),
        ELISE_SONG.take("Für Elise"),
    ], minutes=ELISE_SONG.minutes(), xp=35, kind="song", arrangement=ELISE_SONG.meta()),
    lesson("song-medley-classical-1", "Classical medley", [
        explain("A short recital", "No new notes: the six themes from this unit, from Pachelbel to Beethoven, "
                "each a little faster than before."),
        listen("Which piece starts like this?", [["E4"], ["D#4"], ["E4"], ["D#4"], ["E4"], ["B3"], ["D4"], ["C4"], ["A3"]],
               ["Minuet in G", "Für Elise", "Canon in D"], 1),
        along(G, CANON, bpm=72, title="Canon in D"),
        along(G, LARGO, bpm=72, title="Largo"),
        along(G, BRAHMS, bpm=76, beats_per_bar=3, title="Brahms' Lullaby"),
        quiz("Which of these pieces is in three?", ["Canon in D", "Minuet in G", "In the Hall of the Mountain King"], 1,
             "A minuet is a dance in three. The Canon and the trolls' march both count in four."),
        along(G, MINUET, bpm=76, beats_per_bar=3, title="Minuet in G"),
        along(G, f"{KING} {KING}", bpm=96, title="In the Hall of the Mountain King"),
        along(G, ELISE, bpm=84, beats_per_bar=3, title="Für Elise"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNITS = [UNIT_1, UNIT_2, UNIT_3]
