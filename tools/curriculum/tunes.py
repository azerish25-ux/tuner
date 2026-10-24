"""Tunes that several instrument courses arrange: each melody once, in one reference key, with its chords and its
public-domain words. A course moves a tune to its own key and octave (songbook.transpose / transpose_chords), fixes
the odd note its unit can't reach yet, and builds its own arrangement around it: an intro and outro, a solo or a
variation in the instrument's own idiom.

Words are split for songbook (one token per note; see songbook.py for "-", "_", "~" and "/"). Every text here is in
the public domain: written before 1929 (most long before), credited in the WORDS_* constants.
"""
from songbook import transpose, transpose_chords  # noqa: F401  (re-exported for the courses)

# ================================================================ Ode to Joy
# Beethoven, Symphony No. 9 (1824). C major, 4/4: A1 A2 B A2, sixteen bars. Words: Schiller, An die Freude (1785),
# in the German Beethoven set. The B section ends on the low G; courses that can't reach it take it up an octave.
ODE_A1 = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:1.5 D4:0.5 D4:2"
ODE_A2 = "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2"
ODE_B = "D4 D4 E4 C4 D4 E4:0.5 F4:0.5 E4 C4 D4 E4:0.5 F4:0.5 E4 D4 C4 D4 G3:2"
ODE_TAIL = "C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2"           # the last line: an intro and an ending
ODE_CHORDS_A1 = "C G C G"
ODE_CHORDS_A2 = "C G C G,C"
ODE_CHORDS_B = "G C G C,G"
ODE_CHORDS = f"{ODE_CHORDS_A1} {ODE_CHORDS_A2} {ODE_CHORDS_B} {ODE_CHORDS_A2}"
ODE_WORDS_1 = ("Freu-de, schö-ner Göt-ter-fun-ken, / Toch-ter aus E-ly-si-um, / wir be-tre-ten feu-er-trun-ken, / "
               "Himm-li-sche, dein Hei-lig-tum! / Dei-ne Zau-ber bin-den _ wie-der, / was die _ Mo-de streng ge-teilt; / "
               "al-le Men-schen wer-den Brü-der, / wo dein sanf-ter Flü-gel weilt.")
ODE_WORDS_2 = ("Wem der gro-ße Wurf ge-lun-gen, / ei-nes Freun-des Freund zu sein, / wer ein hol-des Weib er-run-gen, / "
               "mi-sche sei-nen Ju-bel ein! / Ja, wer auch nur ei-ne _ See-le / sein nennt _ auf dem Er-den-rund! / "
               "Und wer's nie ge-konnt, der steh-le / wei-nend sich aus die-sem Bund!")
ODE_WORDS_END = "Al-le Men-schen wer-den Brü-der, / wo dein sanf-ter Flü-gel weilt."
ODE_CREDIT = "Friedrich Schiller (1785)"


def ode(shift, low_g=None):
    """The sixteen-bar tune moved by `shift` semitones: (A1, A2, B, tail). low_g: the note that ends the B section,
    when the instrument can't reach the low G (already moved)."""
    b = transpose(ODE_B, shift)
    if low_g:
        b = b.rsplit(" ", 1)[0] + f" {low_g}:2"
    return transpose(ODE_A1, shift), transpose(ODE_A2, shift), b, transpose(ODE_TAIL, shift)


def doubled(melody):
    """Every quarter note played twice as two eighths (down-up with the bow or the pick); longer and shorter notes
    stay as they are. The first variation string players learn on a tune they know."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        if float(length or 1) == 1 and n.lower() != "r":
            out += [f"{n}:0.5", f"{n}:0.5"]
        else:
            out.append(token)
    return " ".join(out)


# ================================================================ Twinkle, Twinkle, Little Star
# "Ah! vous dirai-je, maman" (France, printed 1761). C major, 4/4. Words: Jane Taylor, The Star (1806).
TWINKLE_A = "C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2"
TWINKLE_B = "G4 G4 F4 F4 E4 E4 D4:2 G4 G4 F4 F4 E4 E4 D4:2"
TWINKLE_CHORDS_A = "C F,C F,C G,C"
TWINKLE_CHORDS_B = "C,F C,G C,F C,G"
TWINKLE_WORDS_1 = ("Twin-kle, twin-kle, lit-tle star, / how I won-der what you are! / Up a-bove the world so high, / "
                   "like a dia-mond in the sky.")
TWINKLE_WORDS_2 = ("When the blaz-ing sun is gone, / when he noth-ing shines up-on, / then you show your lit-tle light, / "
                   "twin-kle, twin-kle, all the night.")
TWINKLE_WORDS_3 = ("Then the trav-'ller in the dark / thanks you for your ti-ny spark; / could not see which way to go / "
                   "if you did not twin-kle so.")
TWINKLE_REFRAIN = "Twin-kle, twin-kle, lit-tle star, / how I won-der what you are!"
TWINKLE_CREDIT = "Jane Taylor (1806)"

# ================================================================ Amazing Grace
# The hymn tune "New Britain" (printed 1829). G major, 3/4, a one-beat pickup, fifteen bars ("me" is held over two).
# Words: John Newton (1779).
AMAZING_LINE_1 = "D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:2 E3 D3:2 D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 D4:5"
AMAZING_LINE_2 = "B3 D4:2 B3:0.5 G3:0.5 B3:2 A3 G3:2 E3 D3:2 D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:3"
AMAZING = f"{AMAZING_LINE_1} {AMAZING_LINE_2}"
AMAZING_TAIL = "D3 G3:2 B3:0.5 G3:0.5 B3:2 A3 G3:3"     # "was blind, but now I see": pickup and three bars
AMAZING_CHORDS = "G G C G G G,D7 D G G G C G G G,D7 G"
AMAZING_TAIL_CHORDS = "G G,D7 G"
AMAZING_WORDS_1 = ("A-maz-ing _ grace! how sweet the sound / that saved a _ wretch like me! / I once was _ lost, but now am found, / "
                   "was blind, but _ now I see.")
AMAZING_WORDS_2 = ("'Twas grace that _ taught my heart to fear, / and grace my _ fears re-lieved; / how pre-cious _ did "
                   "that grace ap-pear / the hour I _ first be-lieved!")
AMAZING_WORDS_3 = ("Through man-y _ dan-gers, toils and snares, / I have al- _ read-y come; / 'tis grace hath _ brought "
                   "me safe thus far, / and grace will _ lead me home.")
AMAZING_WORDS_4 = ("The Lord has _ prom-ised good to me, / his word my _ hope se-cures; / he will my _ shield and por-tion be, / "
                   "as long as _ life en-dures.")
AMAZING_WORDS_END = "was blind, but _ now I see."
AMAZING_CREDIT = "John Newton (1779)"

# ================================================================ Clementine
# American ballad (published 1884), 3/4, a one-beat pickup, eight bars; the chorus has the same tune.
CLEM_CHORUS = ("Oh my dar-ling, oh my dar-ling, oh my dar-ling Clem-en-tine, / "
               "you are lost and gone for-ev-er, dread-ful sor-ry, Clem-en-tine.")
CLEM_WORDS_1 = ("In a cav-ern, in a can-yon, ex-ca-vat-ing for a mine, / "
                "dwelt a min-er, for-ty~nin-er, and his daugh-ter Clem-en-tine.")
CLEM_WORDS_2 = ("Light she was and like a fair-y, and her shoes were num-ber nine, / "
                "her-ring box-es, with-out top-ses, san-dals were for Clem-en-tine.")
CLEM_WORDS_3 = ("Drove she duck-lings to the wa-ter ev-ery morn-ing just at nine, / "
                "hit her foot a-gainst a splin-ter, fell in-to the foam-ing brine.")
CLEM_WORDS_END = "dread-ful sor-ry, Clem-en-tine."
CLEM_CREDIT = "Percy Montrose (1884)"

# ================================================================ Oh! Susanna
# Stephen Foster (1848). A verse is two eight-bar halves of 2/4 (each with a two-eighth pickup); the chorus is one.
SUSANNA_WORDS_1A = ("I come from Al-a-bam-a with my ban-jo on my knee, _ / "
                    "I'm go-ing to Lou-i-si-an-a, my true love for to see.")
SUSANNA_WORDS_1B = ("It rained all night the day I left, the weath-er it was dry, _ / "
                    "the sun so hot I froze to death; Su-san-na, _ don't you cry.")
SUSANNA_WORDS_2A = ("I had a dream the oth-er night, when ev-ery-thing was still; _ / "
                    "I thought I saw Su-san-na _ dear, a~com-ing down the hill.")
SUSANNA_WORDS_2B = ("The buck-wheat cake was in her mouth, the tear was in her eye; _ / "
                    "says I, I'm com-ing from the South, Su-san-na, _ don't you cry.")
SUSANNA_CHORUS = "Oh! Su-san-na, oh don't you cry for me, / for I come from Al-a-bam-a with my ban-jo on my knee."
SUSANNA_CREDIT = "Stephen Foster (1848)"

# ================================================================ Lightly Row
# German children's song ("Hänschen klein"), English words from 19th-century American school songbooks.
# Four-bar phrases: A, END, B, END.
LIGHTLY_WORDS_1 = ("Light-ly row, light-ly row, / o'er the glass-y waves we go; / smooth-ly glide, smooth-ly glide / "
                   "on the si-lent tide. / Let the winds and wa-ters be / min-gled with our mel-o-dy; / "
                   "sing and float, sing and float / in our lit-tle boat.")
LIGHTLY_WORDS_2 = ("Far a-way, far a-way, / ech-o in the rocks at play / call-eth not, call-eth not / "
                   "to this lone-ly spot. / On-ly with the sea-bird's note / shall our dy-ing mu-sic float; / "
                   "light-ly row, light-ly row, / ech-o's voice is low.")
LIGHTLY_CREDIT = "Traditional"
