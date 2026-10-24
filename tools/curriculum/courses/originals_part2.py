"""Originals, part 2: thirty more songs written for Timbre, in the styles on the radio and the streaming charts today.

courses/originals.py places these six units between its own four, easiest first: three-chord sing-alongs, four-chord
pop, grooves on seventh chords, power-chord rock, story songs in three and six, and barre-chord pop. Every title, melody
and lyric is an original composition (words credited "Timbre"); chord progressions are shared by all of popular music,
melodies and words are not, so none of these borrows a line from anywhere. Melodies are sung lines in first position
(frets 0-4), one note at a time; 3/4 counts quarters and 6/8 counts eighths (beats_per_bar=6).

Sung parts are written a line at a time with `Lines`: each melody phrase carries one line of words, so a second verse is
checked against the same phrases line by line, not only in total.
"""
from lib import chord, explain, fretted, lesson, listen, notes, play_chord, progression, quiz, rhythm, strum, tap, unit
from songbook import Part, song, syllables, tokens

G = "guitar"
WORDS = "Timbre"

# ---------------------------------------------------------------- chord shapes (lowest string first)
Em = chord(G, "Em", "022000", "x23xxx")
E = chord(G, "E", "022100", "x231xx")
Am = chord(G, "Am", "x02210", "xx231x")
A = chord(G, "A", "x02220", "xx123x")
C = chord(G, "C", "x32010", "x32x1x")
G_MAJ = chord(G, "G", "320003", "21xxx3")
D = chord(G, "D", "xx0232", "xxx132")
Dm = chord(G, "Dm", "xx0231", "xxx231")
F_MINI = chord(G, "F", "xx3211", "xx3211")
E7 = chord(G, "E7", "020100", "x2x1xx")
A7 = chord(G, "A7", "x02020", "xx1x3x")
B7 = chord(G, "B7", "x21202", "x213x4")
D7 = chord(G, "D7", "xx0212", "xxx213")
G7 = chord(G, "G7", "320001", "32xxx1")
Dsus4 = chord(G, "Dsus4", "xx0233", "xxx134")
Dsus2 = chord(G, "Dsus2", "xx0230", "xxx13x")
Asus2 = chord(G, "Asus2", "x02200", "xx12xx")
Asus4 = chord(G, "Asus4", "x02230", "xx124x")
Esus4 = chord(G, "Esus4", "022200", "x234xx")
Am7 = chord(G, "Am7", "x02010", "xx2x1x")
Dm7 = chord(G, "Dm7", "xx0211", "xxx211")
Em7 = chord(G, "Em7", "020000", "x2xxxx")
Cmaj7 = chord(G, "Cmaj7", "x32000", "x32xxx")
Fmaj7 = chord(G, "Fmaj7", "xx3210", "xx321x")
Gmaj7 = chord(G, "Gmaj7", "320002", "32xxx1")
Dmaj7 = chord(G, "Dmaj7", "xx0222", "xxx111")
Bm7 = chord(G, "Bm7", "x20202", "x1x2x3")
BM_EASY = chord(G, "Bm", "xx4432", "xx3421")       # B minor on the top four strings, before the barre
E5 = chord(G, "E5", "022xxx", "x23xxx")
A5 = chord(G, "A5", "x022xx", "xx23xx")
D5 = chord(G, "D5", "xx023x", "xxx13x")            # open D string under fret 2 and 3
G5 = chord(G, "G5", "355xxx", "134xxx")
C5 = chord(G, "C5", "x355xx", "x134xx")
F5 = chord(G, "F5", "133xxx", "134xxx")
B5 = chord(G, "B5", "x244xx", "x134xx")
F_BARRE = chord(G, "F", "133211", "134211")
Bm = chord(G, "Bm", "x24432", "x13421")
Fsm = chord(G, "F#m", "244222", "134111")
Csm = chord(G, "C#m", "x46654", "x13421")
B_BARRE = chord(G, "B", "x24442", "x12341")
Bb = chord(G, "Bb", "x13331", "x12341")
Gm = chord(G, "Gm", "355333", "134111")

# ---------------------------------------------------------------- rhythms (beats inside one bar)
QUARTERS = [0, 1, 2, 3]
HALVES = [0, 2]
FOLK = [0, 1, 1.5, 2.5, 3, 3.5]          # down, down-up, up-down-up
SKIP = [0, 1, 1.5, 2, 3, 3.5]            # down, down-up, down, down-up
TWO_STEP = [0, 1, 1.5, 2, 3, 3.5]        # bass on one and three, a strum and a quick up on two and four
BACKBEAT = [1, 3]                        # reggae: one bright upstroke on two and four
SKANK = [1, 1.5, 3, 3.5]                 # reggae: a double chop, chk-a, on two and four
OFFBEAT = [0.5, 1.5, 2.5, 3.5]           # a chop on every and
LAZY = [0, 2, 2.667]                     # lo-fi: one, then three and a late, swung up
SCRATCH = [0, 0.5, 1.5, 2, 2.5, 3.5]     # funk: one-and, the and of two, three-and, the and of four
SOUL = [0, 1.5, 2.5, 3.5]                # one, then soft ups on the ands
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
DRIVE = [0, 1, 1.5, 2, 2.5, 3, 3.5]      # one, then down-up eighths to the end of the bar
PUSH = [0, 1.5, 3]                       # one, the and of two, four
STAB = [0, 1.5, 2.5, 3]                  # one, the and of two, the and of three, four: a pushed pop strum
BALLAD = [0, 2, 3, 3.5]                  # big on one, let it ring, build on three and four
WALTZ = [0, 1, 2]
WALTZ_UP = [0, 1, 1.5, 2, 2.5]           # 3/4: down, down-up, down-up
SIX_EIGHT = [0, 2, 3, 5]                 # 6/8 in eighths: counts one, three, four, six
ROLLING = [0, 1, 2, 3, 4, 5]             # 6/8: every eighth

# ---------------------------------------------------------------- shared text (translated once)
HOOK = "The hook"
VERSE = "The verse"
CHORUS = "The chorus"
RIFF = "The riff"
MAJOR_MINOR = ["Major", "Minor"]
HOME = ["Yes, it feels finished", "No, it wants to go on"]
CLIMB_FALL = ["It climbs", "It falls"]
FIRST_SECOND = ["The first", "The second"]
SET_LIST = "No new chords or notes: the five songs from this unit, each a touch faster. Name each hook by ear, then play."
SET_TITLE = "Five songs, one set"


def shape(spec):
    return {"type": "chord", "chord": spec}


def tones(spec):
    """The notes a chord shape sounds, lowest first, for listen steps."""
    return [fretted(G, 6 - i, f) for i, f in enumerate(spec["frets"]) if f >= 0]


def bars(chart, *specs):
    """A progression step's changes from a chart ("G C G D"): each token one bar, a repeated chord held on."""
    by_name = {s["name"]: s for s in specs}
    out = []
    for name in chart.split():
        if out and out[-1][0]["name"] == name:
            out[-1] = (out[-1][0], out[-1][1] + 1)
        else:
            out.append((by_name[name], 1))
    return out


def swing(melody):
    """Long-short eighths: "B3:L D4:S" is a beat split two-thirds, one-third, like the shuffle strum."""
    return melody.replace(":L", ":0.667").replace(":S", ":0.333")


class Lines:
    """A sung part written a line at a time: each melody phrase carries one line of words, so a second verse's words
    are checked against the same phrases, line by line."""

    def __init__(self, *phrases):
        self.phrases = [" ".join(p.split()) for p in phrases]
        self.melody = " ".join(self.phrases)

    def part(self, label, kind, words, chords, pickup=0.0):
        lines = [w.strip() for w in words.split(" / ")]
        if len(lines) != len(self.phrases):
            raise ValueError(f"{label}: {len(lines)} lines of words for {len(self.phrases)} phrases")
        for phrase, line in zip(self.phrases, lines):
            count = sum(1 for n, *_ in tokens(phrase) if n is not None)
            sung = len(syllables(line, label))
            if sung != count:
                raise ValueError(f"{label}: {line!r} has {sung} syllables for {count} notes ({phrase})")
        return Part(label, kind, self.melody, " / ".join(lines), chords, pickup)

    def play(self, label, kind, chords):
        """The same phrases with no words: an intro, a solo or an outro."""
        return Part(label, kind, self.melody, None, chords)


def song_lesson(lid, title, steps, arranged, xp=35):
    return lesson(lid, title, steps, minutes=arranged.minutes(), xp=xp, kind="song", arrangement=arranged.meta())


# ================================================================ A. Three-chord sing-alongs

# Lantern Hill: a campfire sing-along in G, 92 bpm. G, C and D.
LANTERN_V = Lines("r:1 B3:0.5 B3:0.5 B3:0.5 A3:0.5 B3:0.5 D4:0.5 E4:1.5 C4:2.5",
                  "r:1 B3:0.5 B3:0.5 D4:0.5 B3:0.5 A3:0.5 G3:0.5 A3:4",
                  "r:1 D4:0.5 D4:0.5 D4:0.5 B3:0.5 D4:0.5 E4:0.5 G4:1.5 E4:2.5",
                  "r:1 A3:0.5 A3:0.5 D4:0.5 A3:0.5 F#3:0.5 A3:0.5 G3:4")
LANTERN_HOOK = "E4:1.5 D4:0.5 E4:1 G4:1 G4:1 E4:1 D4:2"
LANTERN_HOME = "F#4:1.5 E4:0.5 D4:1 A3:1 B3:1 A3:1 G3:2"
LANTERN_C = Lines(LANTERN_HOOK, "F#4:1.5 F#4:0.5 E4:1 D4:1 D4:1 B3:1 B3:2", LANTERN_HOOK, LANTERN_HOME)
LANTERN_CHART = "G C G D G C D G"
LANTERN_CHORUS = LANTERN_C.part("Chorus", "chorus", "Meet me up on Lan-tern Hill, / where the whole town's ly-ing still; / "
                                "hold your lan-tern, let it glow, / ev-ery-one we love's be-low.", "C G D G C G D G")
LANTERN = song(G, 92, [
    Part("Intro", "intro", f"{LANTERN_HOOK} {LANTERN_HOME}", chords="C G D G"),
    LANTERN_V.part("Verse 1", "verse", "Grab a blan-ket and a lan-tern, / tell your moth-er you'll be late; / "
                   "all the kids from Ma-ple Hol-low / climb-ing up be-yond the gate.", LANTERN_CHART),
    LANTERN_CHORUS,
    LANTERN_V.part("Verse 2", "verse", "Dan-ny brought a beat~up six~string, / knows three chords and how to play; / "
                   "Kel-ly sings the high part bad-ly, / and we sing it an-y-way.", LANTERN_CHART),
    LANTERN_CHORUS,
    Lines("r:2 G3:0.5 C4:0.5 C4:0.5 D4:0.5 E4:2 C4:2", "r:1 B3:0.5 D4:0.5 D4:1 B3:1 D4:4",
          "r:1 C4:0.5 D4:0.5 E4:1 E4:1 G4:1 E4:1 C4:2", "r:1 A3:0.5 A3:0.5 D4:1 E4:1 F#4:2 E4:2").part(
        "Bridge", "bridge", "Some-day we'll be scat-tered / all a-cross the map; / when the crick-ets start to sing / "
        "you'll know where to find me.", "C C G G C C D D"),
    LANTERN_CHORUS,
    Lines(LANTERN_HOME, "E4:2 D4:2 G3:4").part("Outro", "outro", "ev-ery-one we love's be-low, / be-low. _", "D G C G"),
], shapes={s["name"]: s for s in [G_MAJ, C, D]}, words=WORDS)

# Gravel Road Two-Step: dance-hall country in A, 116 bpm. A, D and E; the verse lines start after beat one.
GRAVEL_V = Lines("r:1 E4:0.5 E4:0.5 C#4:1 A3:0.5 C#4:0.5 D4:1 C#4:1 A3:2",
                 "r:1 E4:0.5 E4:0.5 C#4:1 A3:0.5 C#4:0.5 B3:1 A3:1 B3:2",
                 "r:1 E4:0.5 E4:0.5 F#4:1 E4:0.5 C#4:0.5 D4:1 F#4:1 E4:2",
                 "r:1 B3:0.5 B3:0.5 B3:1 G#3:0.5 B3:0.5 C#4:1 B3:1 A3:2")
GRAVEL_HOOK = "F#4:1 E4:0.5 D4:1 E4:0.5 F#4:1 E4:0.5 C#4:0.5 A3:1 C#4:2"
GRAVEL_C = Lines(GRAVEL_HOOK, "E4:1 D4:0.5 B3:0.5 B3:1 G#3:0.5 B3:0.5 C#4:1 B3:1 A3:2",
                 GRAVEL_HOOK, "E4:1 D4:0.5 B3:0.5 E4:1 D4:0.5 B3:0.5 C#4:1 B3:1 A3:2")
GRAVEL_CHART = "A D A E A D E A"
GRAVEL_CHORUS = GRAVEL_C.part("Chorus", "chorus", "Grav-el road two~step un-der the moon, / kick up the dust to a fid-dle tune; / "
                              "grav-el road two~step, hold on to me, / spin me a-round like we're sev-en-teen.", "D A E A D A E A")
GRAVEL_VERSE = GRAVEL_V.part("Verse 1", "verse", "Hay bales stacked by the dance hall door, / string lights swing in the sum-mer air, / "
                             "Grand-pa's shin-ing his Sun-day boots, / Grand-ma's fix-ing her sil-ver hair.", GRAVEL_CHART)
GRAVEL = song(G, 116, [
    Part("Intro", "intro", f"{GRAVEL_HOOK} E4:1 D4:0.5 B3:0.5 E4:1 D4:0.5 B3:0.5 C#4:1 B3:1 A3:2", chords="D A E A"),
    GRAVEL_VERSE, GRAVEL_CHORUS,
    GRAVEL_V.part("Verse 2", "verse", "Kids run wild in the park-ing lot, / dust comes up like a gold-en cloud, / "
                  "band kicks in with a two~step beat, / ev-ery-bod-y is sing-ing loud.", GRAVEL_CHART),
    GRAVEL_CHORUS,
    GRAVEL_VERSE.instrumental("Solo"),
    Lines("r:1 A3:1 D4:1 D4:1 F#4:2 D4:2", "r:1 C#4:1 E4:1 C#4:1 A3:4",
          "r:0.5 A3:0.5 D4:1 D4:0.5 E4:0.5 F#4:1 F#4:2 E4:2", "r:1 B3:0.5 B3:0.5 E4:1 D4:1 B3:2 r:2").part(
        "Bridge", "bridge", "I've seen the cit-y, / the bright lights shine, / but give me this old dance hall / "
        "on a Sat-ur-day.", "D D A A D D E E"),
    GRAVEL_CHORUS,
    Part("Outro", "outro", f"{GRAVEL_HOOK} E4:1 D4:0.5 B3:0.5 B3:1 G#3:0.5 B3:0.5 A3:4", chords="D A E A"),
], shapes={s["name"]: s for s in [A, D, E]}, words=WORDS)

# First Frost: an indie-folk waltz in D, 3/4, 108 bpm. D, G and A; every line is four bars, the last one a breath.
FROST_V = Lines("D4:1 D4:1 E4:1 F#4:1 E4:1 D4:1 B3:3 r:3",
                "D4:1 D4:1 E4:1 F#4:1 G4:1 F#4:1 E4:3 r:3",
                "D4:1 D4:1 E4:1 F#4:1 E4:1 D4:1 B3:3 r:3",
                "E4:1 E4:1 C#4:1 A3:1 B3:1 C#4:1 D4:3 r:3")
FROST_HOOK = "G4:2 D4:1 G4:2 D4:0.5 E4:0.5 F#4:1 E4:1 D4:1 A3:3"
FROST_C = Lines(FROST_HOOK, "C#4:1 C#4:1 D4:1 E4:1 C#4:1 A3:1 F#4:1 E4:1 D4:1 D4:3",
                FROST_HOOK, "C#4:1 C#4:1 D4:1 E4:1 C#4:1 A3:1 F#4:1 E4:1 C#4:1 D4:3")
FROST_CHART = "D D G D D D A A D D G D A A D D"
FROST_CHORUS = FROST_C.part("Chorus", "chorus", "First frost, first frost, the gar-den's a-sleep, / pull up the quilt and come clos-er to me; / "
                            "first frost, first frost, the long nights are here, / hold on to me 'til the spring-time is near.",
                            "G G D D A A D D G G D D A A D D")
FROST = song(G, 108, [
    Part("Intro", "intro", FROST_HOOK, chords="G G D D"),
    FROST_V.part("Verse 1", "verse", "Win-dow's gone white in the night, / breath like a ghost on the glass, / "
                 "ket-tle is sing-ing a-gain, / sum-mer has gone, let it pass.", FROST_CHART),
    FROST_CHORUS,
    FROST_V.part("Verse 2", "verse", "Dig out the scarf that you knit, / leaves in a pile by the gate, / "
                 "dog does-n't want to come in, / kids won't be-lieve that it's late.", FROST_CHART),
    FROST_CHORUS,
    Lines("B3:1 D4:1 G4:1 G4:1 F#4:1 E4:1 E4:3 r:3", "G4:1 F#4:1 E4:1 D4:1 E4:1 F#4:1 E4:3 r:3").part(
        "Bridge", "bridge", "Some-where the geese are a-way, / fly-ing on south from the snow.", "G G A A G G A A"),
    FROST_CHORUS,
    Part("Outro", "outro", FROST_HOOK.replace("A3:3", "D4:3"), chords="G G D D"),
], beats_per_bar=3, shapes={s["name"]: s for s in [D, G_MAJ, A]}, words=WORDS)

# Hammock Season: easy reggae in C, 76 bpm. C, G and A minor, the guitar on two and four.
HAMMOCK_V = Lines("r:1 G3:0.5 A3:0.5 C4:1 C4:0.5 D4:0.5 E4:1 D4:0.5 C4:0.5 C4:2",
                  "r:1 G3:0.5 A3:0.5 B3:1 B3:0.5 C4:0.5 D4:1 C4:0.5 B3:0.5 G3:2",
                  "r:1 C4:0.5 C4:0.5 E4:1 E4:0.5 D4:0.5 C4:1 B3:0.5 A3:0.5 A3:2",
                  "r:1 B3:0.5 B3:0.5 D4:1 E4:0.5 D4:0.5 B3:1 A3:0.5 B3:0.5 G3:2")
HAMMOCK_HOOK = "r:0.5 E4:0.5 E4:0.5 D4:1 C4:1.5 r:0.5 D4:0.5 D4:0.5 C4:1 B3:1.5"
HAMMOCK_HOME = "r:1 B3:0.5 B3:0.5 D4:0.5 D4:0.5 E4:0.5 D4:0.5 C4:4"
HAMMOCK_C = Lines(HAMMOCK_HOOK, "r:1 C4:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 B3:4", HAMMOCK_HOOK, HAMMOCK_HOME)
HAMMOCK_CHART = "C C G G Am Am G G"
HAMMOCK_CHORUS = HAMMOCK_C.part("Chorus", "chorus", "Ham-mock sea-son, ham-mock sea-son, / noth-ing to do but sway; / "
                                "ham-mock sea-son, ham-mock sea-son, / let the whole world float a-way.", "C G Am G C G G C")
HAMMOCK = song(G, 76, [
    Part("Intro", "intro", f"{HAMMOCK_HOOK} {HAMMOCK_HOME}", chords="C G G C"),
    HAMMOCK_V.part("Verse 1", "verse", "Two old trees and a rope in be-tween, / with the light com-ing down through the green; / "
                   "got no place that I need to be soon, / let the breeze rock me all af-ter-noon.", HAMMOCK_CHART),
    HAMMOCK_CHORUS,
    HAMMOCK_V.part("Verse 2", "verse", "Lem-on-ade with the ice in a jar, / and a neigh-bor's old beat~up gui-tar; / "
                   "ev-ery cloud is a ship sail-ing by, / and I'm count-ing them, one at a time.", HAMMOCK_CHART),
    HAMMOCK_CHORUS,
    Lines("r:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 C4:0.5 A3:0.5 B3:4", "r:1 C4:0.5 C4:0.5 E4:1.5 D4:0.5 D4:4").part(
        "Bridge", "bridge", "Hang your trou-bles on a branch, / let 'em swing a-way.", "Am G Am G"),
    HAMMOCK_CHORUS,
    Lines(HAMMOCK_HOOK, "r:0.5 E4:0.5 E4:0.5 D4:1 C4:1.5 C4:4").part(
        "Outro", "outro", "Ham-mock sea-son, ham-mock sea-son, / ham-mock sea-son. _", "C G C C"),
], shapes={s["name"]: s for s in [C, G_MAJ, Am]}, words=WORDS)

# Glow-in-the-Dark Stars: bedroom pop in E minor and G, 84 bpm. E minor, C and G; lines float in after the beat.
GLOW_V = Lines("r:0.5 G3:0.5 G3:0.5 B3:0.5 B3:0.5 D4:1 B3:0.5 B3:0.5 E4:1.5 C4:2",
               "r:0.5 D4:0.5 D4:0.5 B3:0.5 D4:1 B3:0.5 A3:0.5 A3:0.5 B3:1.5 G3:2",
               "r:0.5 B3:0.5 D4:0.5 D4:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:0.5 E4:0.5 C4:2",
               "r:1 D4:1.5 B3:0.5 A3:1 B3:2 G3:2")
GLOW_HOOK = "r:1 E4:1 E4:1 G4:0.5 E4:0.5 G4:2 D4:2"
GLOW_SKY = "r:1 E4:0.5 E4:0.5 G4:1 F#4:1 E4:4"
GLOW_C = Lines(GLOW_HOOK, GLOW_SKY, "r:0.5 E4:0.5 E4:0.5 E4:0.5 G4:1 E4:1 D4:2 B3:2",
               "r:0.5 B3:0.5 B3:0.5 E4:1 D4:0.5 E4:1 G4:1 E4:3")
GLOW_CHART = "Em C G G Em C G G"
GLOW_CHORUS = GLOW_C.part("Chorus", "chorus", "Oh, glow~in~the~dark stars, / you were my first sky; / "
                          "and I still see you shin-ing / ev-ery time I close my eyes.", "C G Em Em C G Em C")
GLOW_HEAVEN = "r:1 D4:1.5 B3:0.5 A3:1 B3:2 G3:2"
GLOW = song(G, 84, [
    Part("Intro", "intro", f"{GLOW_HOOK} {GLOW_SKY}", chords="C G Em Em"),
    GLOW_V.part("Verse 1", "verse", "Twen-ty plas-tic stars on the ceil-ing, / Dad stuck 'em up when I was sev-en; / "
                "I'd count 'em ev-ery night till I was sleep-ing, / green lit-tle heav-en.", GLOW_CHART),
    GLOW_CHORUS,
    GLOW_V.part("Verse 2", "verse", "Card-board box-es stacked in the hall-way, / Mom says she's fine, but she's been cry-ing; / "
                "I leave the stars up there for some-one some-day, / green lit-tle heav-en.", GLOW_CHART),
    GLOW_CHORUS,
    Lines("r:1 G3:0.5 G3:0.5 C4:1 C4:0.5 D4:0.5 E4:1 D4:1 C4:2", "r:1 B3:0.5 B3:0.5 D4:1 B3:1 D4:1 E4:1 D4:2").part(
        "Bridge", "bridge", "May-be some-day I'll have a kid, / stick a sky a-bove their bed.", "C C G G"),
    GLOW_CHORUS,
    Lines(GLOW_HEAVEN, GLOW_HEAVEN).part("Outro", "outro", "green lit-tle heav-en, / green lit-tle heav-en.", "G G Em G"),
], shapes={s["name"]: s for s in [Em, C, G_MAJ]}, words=WORDS)

UNIT_SINGALONG = unit("orig-5", "Three-chord sing-alongs", "Five songs on three chords each: a campfire chorus, a country "
                      "two-step, a waltz, easy reggae and bedroom pop.", [
    song_lesson("orig-lantern-hill", "Lantern Hill", [
        explain("Campfire sing-along", "Lantern Hill is a campfire song on three chords, G, C and D, at 92 beats per minute. "
                "The chorus is made for a crowd, so by the second time around, sing it out.", rhythm(FOLK)),
        listen("Does the chorus end at home?", [["F#4"], ["E4"], ["D4"], ["A3"], ["B3"], ["A3"], ["G3"]], HOME, 0),
        progression(bars(LANTERN_CHART, G_MAJ, C, D), FOLK, bpm=76),
        notes(G, ["E4", "D4", "E4", "G4", "G4", "E4", "D4"],
              hint="Open E, D at fret 3 on string 2, open E again, then G at fret 3 on string 1 and back down."),
        LANTERN.along("Chorus", bpm=76, title=HOOK),
        LANTERN.along("Verse 1", bpm=80, title=VERSE),
        progression(bars(LANTERN_CHART, G_MAJ, C, D), FOLK, bpm=92),
        LANTERN.take("Lantern Hill"),
    ], LANTERN, xp=30),
    song_lesson("orig-gravel-road-two-step", "Gravel Road Two-Step", [
        explain("Country two-step", "Gravel Road Two-Step is dance-hall country in A at 116 beats per minute. Pick the root "
                "on one and three, strum on two and four, and add a quick up after each strum.", rhythm(TWO_STEP)),
        quiz("In a two-step, where do the bass notes fall?", ["Beats one and three", "Beats two and four", "On every and"], 0,
             "The bass walks with the dancers' feet on one and three; the strums fill two and four."),
        progression(bars(GRAVEL_CHART, A, D, E), TWO_STEP, bpm=96),
        notes(G, ["F#4", "E4", "D4", "E4", "F#4", "E4", "C#4", "A3", "C#4"],
              hint="F sharp at fret 2 on string 1, open E, D at fret 3 on string 2, then C sharp at fret 2 and A on string 3."),
        GRAVEL.along("Chorus", bpm=96, title=CHORUS),
        GRAVEL.along("Verse 1", bpm=100, title=VERSE),
        progression(bars(GRAVEL_CHART, A, D, E), TWO_STEP, bpm=116),
        GRAVEL.take("Gravel Road Two-Step"),
    ], GRAVEL, xp=30),
    song_lesson("orig-first-frost", "First Frost", [
        explain("An indie-folk waltz", "First Frost counts in three at 108 beats per minute: one, two, three, with the weight "
                "on one. D, G and A carry it all, and every line ends on a long, held note.", rhythm(WALTZ, beats_per_bar=3)),
        listen("Listen to the first chord. Major or minor?", [tones(D)], MAJOR_MINOR, 0),
        progression(bars(FROST_CHART, D, G_MAJ, A), WALTZ, bpm=92, beats_per_bar=3),
        notes(G, ["G4", "D4", "G4", "D4", "E4", "F#4", "E4", "D4", "A3"],
              hint="G at fret 3 on string 1, D at fret 3 on string 2, twice. Then E, F sharp at fret 2, E, D and A."),
        FROST.along("Chorus", bpm=92, title=HOOK),
        progression(bars(FROST_CHART, D, G_MAJ, A), WALTZ, bpm=108, beats_per_bar=3),
        FROST.take("First Frost"),
    ], FROST, xp=30),
    song_lesson("orig-hammock-season", "Hammock Season", [
        explain("Reggae on two and four", "Hammock Season is easy reggae in C at 76 beats per minute. The guitar plays only "
                "on beats two and four: one short, bright upstroke on the top strings, then silence.", rhythm(BACKBEAT)),
        tap(BACKBEAT, bpm=70, bars=2),
        explain("Up, then let go", "Brush up across strings 1 to 3, then relax your fretting hand so the chord stops at once. "
                "Chk on two, chk on four. The quiet beats are what make it sway.", shape(C)),
        strum(C, BACKBEAT, bpm=70, bars=2),
        progression(bars(HAMMOCK_CHART, C, G_MAJ, Am), BACKBEAT, bpm=70),
        HAMMOCK.along("Chorus", bpm=70, title=HOOK),
        progression(bars(HAMMOCK_CHART, C, G_MAJ, Am), BACKBEAT, bpm=76),
        HAMMOCK.take("Hammock Season"),
    ], HAMMOCK, xp=30),
    song_lesson("orig-glow-in-the-dark-stars", "Glow-in-the-Dark Stars", [
        explain("Bedroom pop", "Glow-in-the-Dark Stars is soft bedroom pop at 84 beats per minute: E minor, C and G, "
                "strummed light. Most lines start just after the beat, so let them float in.", rhythm(FOLK)),
        listen("Listen to the first chord. Major or minor?", [tones(Em)], MAJOR_MINOR, 1),
        progression(bars(GLOW_CHART, Em, C, G_MAJ), FOLK, bpm=72),
        notes(G, ["E4", "E4", "G4", "E4", "G4", "D4"],
              hint="Open E twice, G at fret 3 on string 1, open E, G again, then D at fret 3 on string 2."),
        GLOW.along("Chorus", bpm=72, title=CHORUS),
        quiz("E minor, C and G share one note. Which?", ["G", "D", "A"], 0,
             "E minor is E, G and B; C is C, E and G; G is G, B and D. G sits in all three, so the changes feel smooth."),
        progression(bars(GLOW_CHART, Em, C, G_MAJ), FOLK, bpm=84),
        GLOW.take("Glow-in-the-Dark Stars"),
    ], GLOW, xp=30),
    lesson("orig-sing-along-set", "Sing-along set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's hook starts like this?", [["G4"], ["D4"], ["G4"], ["D4"], ["E4"], ["F#4"]],
               ["Lantern Hill", "First Frost", "Hammock Season"], 1),
        LANTERN.along("Chorus", bpm=96, title="Lantern Hill"),
        progression(bars(GRAVEL_CHART, A, D, E), TWO_STEP, bpm=120),
        GRAVEL.along("Chorus", bpm=120, title="Gravel Road Two-Step"),
        quiz("In reggae, where does the guitar play?", ["On beats one and three", "On beats two and four", "On every beat"], 1,
             "Reggae's guitar answers the beat: a short upstroke on two and four, silence in between."),
        FROST.along("Chorus", bpm=112, title="First Frost"),
        progression(bars(HAMMOCK_CHART, C, G_MAJ, Am), BACKBEAT, bpm=80),
        GLOW.along("Chorus", bpm=88, title="Glow-in-the-Dark Stars"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ B. Four-chord pop anthems

# Sparkler Season: the I-V-vi-IV anthem in C, 104 bpm. C, G, A minor and F, with a pre-chorus that climbs to the hook.
SPARK_V = Lines("r:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 C4:0.5 C4:0.5 B3:4",
                "r:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 C4:0.5 A3:0.5 A3:4",
                "r:0.5 G3:0.5 G3:0.5 C4:0.5 C4:0.5 E4:0.5 D4:0.5 E4:0.5 C4:0.5 D4:3.5",
                "r:0.5 A3:0.5 C4:0.5 E4:0.5 E4:0.5 E4:0.5 D4:0.5 C4:0.5 A3:0.5 C4:3.5")
SPARK_PRE = Lines("r:1 A3:0.5 C4:0.5 E4:1 E4:1 D4:1 D4:1 B3:2", "r:1 A3:0.5 C4:0.5 F4:1 E4:1 D4:1 E4:1 G4:2").part(
    "Pre-chorus", "verse", "Ev-ery spark gets one short flight, / so we bet-ter make it bright.", "Am G F G")
SPARK_HOOK = "E4:1 D4:0.5 E4:1 D4:0.5 G4:1 D4:0.5 G4:1 E4:0.5 D4:2"
SPARK_HIGH = "C4:1 B3:0.5 C4:1 D4:0.5 E4:1 C4:0.5 F4:1 E4:0.5 C4:2"
SPARK_C = Lines(SPARK_HOOK, SPARK_HIGH, SPARK_HOOK, "C4:1 B3:0.5 C4:1 D4:0.5 E4:1 D4:0.5 C4:1 A3:0.5 C4:2")
SPARK_CHART = "C G Am F C G Am F"
SPARK_CHORUS = SPARK_C.part("Chorus", "chorus", "Spark-ler sea-son, write your name in light, / hold it high and let it burn to-night; / "
                            "spark-ler sea-son, burn-ing out so fast, / let's make ev-ery lit-tle sec-ond last.", SPARK_CHART)
SPARK = song(G, 104, [
    Part("Intro", "intro", f"{SPARK_HOOK} {SPARK_HIGH}", chords="C G Am F"),
    SPARK_V.part("Verse 1", "verse", "Lawn chairs lined up on the curb, / ice cream run-ning down your wrist, / "
                 "ev-ery-bod-y count-ing down to dark, / and you light one up and make a wish.", SPARK_CHART),
    SPARK_PRE, SPARK_CHORUS,
    SPARK_V.part("Verse 2", "verse", "Lit-tle kids in glow-stick crowns, / dogs are hid-ing un-der beds, / "
                 "you write my name a-cross the night sky, / and it fades be-fore I read the end.", SPARK_CHART),
    SPARK_PRE, SPARK_CHORUS,
    Lines("r:0.5 A3:0.5 C4:1 C4:0.5 B3:0.5 C4:0.5 D4:0.5 C4:4",
          "r:0.5 C4:0.5 E4:1 D4:0.5 E4:1 C4:0.5 D4:1 B3:1 D4:2",
          "r:0.5 C4:0.5 C4:0.5 D4:0.5 E4:1 D4:0.5 E4:0.5 E4:0.5 F4:3.5",
          "r:0.5 D4:0.5 D4:0.5 D4:0.5 G4:1 F4:0.5 E4:0.5 D4:4").part(
        "Bridge", "bridge", "Years from now I'll lose the date, / for-get the street, for-get the year, / "
        "but I'll re-mem-ber how it felt / to have you stand-ing right here.", "Am F C G Am F G G"),
    SPARK_CHORUS,
    Lines(SPARK_HOOK, "r:2 E4:2 C4:4").part("Outro", "outro", "Spark-ler sea-son, write your name in light, / in light.", "C G Am C"),
], shapes={s["name"]: s for s in [C, G_MAJ, Am, F_MINI]}, words=WORDS)

# Roller Rink: retro dance pop in G, 120 bpm. G, E minor, C and D (I-vi-IV-V), steady eighths.
ROLLER_V = Lines("G3:1 B3:0.5 D4:1 D4:0.5 E4:0.5 D4:0.5 B3:2 r:2",
                 "C4:1 C4:0.5 E4:1 E4:0.5 D4:0.5 C4:0.5 A3:2 r:2",
                 "G3:1 B3:0.5 D4:1 D4:0.5 E4:0.5 D4:0.5 B3:1 G3:1 r:2",
                 "C4:1 C4:0.5 E4:1 G4:0.5 E4:0.5 E4:0.5 D4:2 r:2")
ROLLER_PRE = Lines("r:1 E4:0.5 E4:0.5 G4:1 E4:1 F#4:1 D4:1 r:2", "r:1 E4:1 E4:0.5 G4:1 F#4:0.5 F#4:4").part(
    "Pre-chorus", "verse", "Then the speak-er crack-les, / lights go soft and blue,", "C D Em D")
ROLLER_HOOK = "r:0.5 D4:0.5 E4:0.5 G4:1 G4:0.5 G4:0.5 F#4:0.5 E4:3 r:1"
ROLLER_WAIT = "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 E4:0.5 F#4:3 r:1"
ROLLER_NIGHT = "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 B3:0.5 D4:3 r:1"
ROLLER_C = Lines(ROLLER_HOOK, ROLLER_WAIT, ROLLER_HOOK, ROLLER_NIGHT)
ROLLER_CHART = "G Em C D G Em C D"
ROLLER_CHORUS = ROLLER_C.part("Chorus", "chorus", "When they call the cou-ple skate, / take my hand, don't make me wait; / "
                              "ev-ery-thing is sil-ver bright, / you and me on Fri-day night.", ROLLER_CHART)
ROLLER = song(G, 120, [
    Part("Intro", "intro", f"{ROLLER_HOOK} {ROLLER_WAIT}", chords="G Em C D"),
    ROLLER_V.part("Verse 1", "verse", "Rent-ed skates and lac-es tied, / dis-co ball throws spots of light, / "
                  "you're the best at skat-ing back-wards, / I'm the best at hold-ing tight.", ROLLER_CHART),
    ROLLER_PRE, ROLLER_CHORUS,
    ROLLER_V.part("Verse 2", "verse", "Mu-sic from an old cas-sette, / pret-zels and a cher-ry pop, / "
                  "lights go low and some-one whis-tles, / and we spin and nev-er stop.", ROLLER_CHART),
    ROLLER_PRE, ROLLER_CHORUS,
    Lines("r:0.5 C4:0.5 C4:0.5 E4:1 E4:0.5 G4:0.5 E4:0.5 F#4:4",
          "r:0.5 B3:0.5 B3:0.5 E4:1 D4:0.5 B3:0.5 G3:0.5 B3:4",
          "r:0.5 C4:0.5 C4:0.5 E4:1 E4:0.5 G4:0.5 G4:0.5 F#4:4",
          "r:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 E4:0.5 F#4:4").part(
        "Bridge", "bridge", "When the lights come up at ten / and they're sweep-ing up the floor, / "
        "I'll be lac-ing up my skates / just to go a-round once more.", "C D Em Em C D D D"),
    ROLLER_CHORUS,
    Lines(ROLLER_NIGHT, "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 B3:0.5 G3:4").part(
        "Outro", "outro", "you and me on Fri-day night, / you and me on Fri-day night.", "C D C G"),
], shapes={s["name"]: s for s in [G_MAJ, Em, C, D]}, words=WORDS)

# Echo Canyon: the same loop started on the six, E minor, C, G and D, at 80 bpm: a big, dark, half-time anthem.
ECHO_V = Lines("r:1 B3:0.5 B3:0.5 B3:1 A3:1 G3:1 A3:1 E3:2",
               "r:0.5 D4:1 B3:0.5 D4:1 B3:0.5 G3:0.5 G3:0.5 A3:3.5",
               "r:1 B3:0.5 B3:0.5 D4:1 B3:1 G3:1 A3:1 E3:2",
               "r:1 D4:0.5 D4:0.5 E4:1 D4:0.5 B3:0.5 A3:1 B3:1 A3:2")
ECHO_HOOK = "G4:1 E4:0.5 G4:1 E4:1.5 G4:1 D4:0.5 G4:1 D4:1.5"
ECHO_LOUD = "r:1 D4:0.5 E4:0.5 F#4:1 E4:1 G4:2 E4:2"
ECHO_BACK = "r:1 D4:0.5 E4:0.5 F#4:1 E4:1 E4:4"
ECHO_C = Lines(ECHO_HOOK, ECHO_LOUD, "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 G4:1 E4:1 D4:3", ECHO_BACK)
ECHO_CHART = "Em C G D Em C G D"
ECHO_CHORUS = ECHO_C.part("Chorus", "chorus", "E-cho Can-yon, E-cho Can-yon, / give my voice back loud-er; / "
                          "ev-ery word I nev-er said / com-ing back to me.", "C G D Em C G D Em")
ECHO = song(G, 80, [
    Part("Intro", "intro", f"{ECHO_HOOK} {ECHO_LOUD}", chords="C G D Em"),
    ECHO_V.part("Verse 1", "verse", "Left at sun-rise, win-dows down, / no one knew where I was bound; / "
                "climbed up where the red rocks lean, / loud-est qui-et I've ev-er seen.", ECHO_CHART),
    ECHO_CHORUS,
    ECHO_V.part("Verse 2", "verse", "Been so long since I felt sure, / been so care-ful, been so small; / "
                "cupped my hands a-round my mouth / and I let go with one long call.", ECHO_CHART),
    ECHO_CHORUS,
    Lines("r:0.5 C4:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 C4:0.5 B3:1 D4:3",
          "r:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 F#4:0.5 E4:0.5 F#4:4").part(
        "Bridge", "bridge", "I was a whis-per for so long, / now I'm thun-der, now I'm strong.", "C G D D"),
    ECHO_CHORUS,
    Lines(ECHO_HOOK, ECHO_BACK).part("Outro", "outro", "Oh, oh, oh, oh, oh, oh, oh, oh, / com-ing back to me.", "C G D Em"),
], shapes={s["name"]: s for s in [Em, C, G_MAJ, D]}, words=WORDS)

# Open Windows: pop in 6/8 in C, 120 counts a minute. C, F, A minor and G, then F, C, G and A minor in the chorus.
OPEN_V = Lines("G3:2 C4:1 E4:2 D4:1 C4:1 C4:1 A3:1 C4:3",
               "E4:2 D4:1 C4:2 B3:1 B3:2 A3:1 B3:3",
               "G3:2 C4:1 E4:2 G4:1 F4:2 E4:1 C4:3",
               "E4:2 C4:1 A3:2 C4:1 B3:2 A3:1 G3:3")
OPEN_HOOK = "C4:1 D4:1 E4:1 F4:2 E4:1 G4:2 E4:1 G4:2 C4:1"
OPEN_YOU = "B3:2 C4:1 D4:2 E4:1 D4:3 B3:3"
OPEN_C = Lines(OPEN_HOOK, "D4:2 B3:1 D4:2 D4:1 E4:2 D4:1 C4:3", OPEN_HOOK, OPEN_YOU)
OPEN_CHART = "C F Am G C F Am G"
OPEN_CHORUS = OPEN_C.part("Chorus", "chorus", "O-pen the win-dows, let the air in, / let the light come pour-ing through; / "
                          "o-pen the win-dows, I'm be-gin-ning / to for-get a-bout you.", "F C G Am F C G G")
OPEN = song(G, 120, [
    Part("Intro", "intro", OPEN_HOOK, chords="F C"),
    OPEN_V.part("Verse 1", "verse", "Win-ter moved in when you moved out, / took the light and took the sound; / "
                "blan-kets nailed up on the glass, / watched the whole long sea-son pass.", OPEN_CHART),
    OPEN_CHORUS,
    OPEN_V.part("Verse 2", "verse", "March came knock-ing on the front door, / sun came pour-ing through the blind; / "
                "pulled the blan-kets off the panes, / let the fresh air say my name.", OPEN_CHART),
    OPEN_CHORUS,
    Lines("A3:1 C4:1 E4:1 E4:2 D4:1 C4:3 A3:3", "G3:1 C4:1 E4:1 G4:2 E4:1 E4:1 D4:5").part(
        "Bridge", "bridge", "Dust in the sun-light, danc-ing, / ev-ery-thing's mov-ing a-gain.", "Am F C G"),
    OPEN_CHORUS,
    Lines("B3:2 C4:1 D4:2 E4:1 D4:3 C4:3").part("Outro", "outro", "to for-get a-bout you.", "G C"),
], beats_per_bar=6, shapes={s["name"]: s for s in [C, F_MINI, Am, G_MAJ]}, words=WORDS)

# Scoreboard Lights: a stadium anthem in D, 100 bpm. D, A, B minor and G, with B minor on the top four strings.
SCORE_V = Lines("r:0.5 A3:0.5 A3:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 E4:1 C#4:1 A3:2",
                "r:0.5 B3:0.5 B3:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 D4:4",
                "r:1 A3:0.5 D4:0.5 D4:0.5 F#4:0.5 E4:0.5 F#4:0.5 E4:0.5 E4:3.5",
                "r:0.5 B3:0.5 D4:0.5 F#4:0.5 E4:0.5 D4:1 B3:0.5 B3:4")
SCORE_PRE = Lines("G4:1 F#4:0.5 E4:0.5 D4:2 E4:0.5 E4:0.5 E4:0.5 F#4:0.5 E4:2",
                  "G4:1 F#4:0.5 E4:0.5 D4:2 E4:0.5 F#4:0.5 G4:0.5 F#4:0.5 E4:2").part(
    "Pre-chorus", "verse", "Clock's run-ning down, ev-ery-bod-y up, / hands in the air and the drums kick in.", "G A G A")
SCORE_HOOK = "r:0.5 A3:0.5 B3:0.5 D4:0.5 G4:1.5 F#4:0.5 E4:4"
SCORE_BRIGHT = "r:0.5 B3:0.5 B3:0.5 D4:0.5 F#4:1.5 E4:0.5 D4:4"
SCORE_C = Lines(SCORE_HOOK, SCORE_BRIGHT, "r:0.5 F#4:0.5 F#4:0.5 G4:1 F#4:0.5 F#4:0.5 E4:0.5 E4:4",
                "r:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 B3:0.5 D4:4")
SCORE_CHART = "D A Bm G D A Bm G"
SCORE_CHORUS = SCORE_C.part("Chorus", "chorus", "Un-der the score-board lights, / the whole town's shin-ing bright; / "
                            "sing it loud and sing it proud, / we're the heart-beat of the crowd.", SCORE_CHART)
SCORE_FIELD = "r:0.5 B3:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 D4:2 B3:2"
SCORE = song(G, 100, [
    Part("Intro", "intro", f"{SCORE_HOOK} {SCORE_BRIGHT}", chords="D A Bm G"),
    SCORE_V.part("Verse 1", "verse", "Band is tun-ing up be-hind the fence, / whole town's in the bleach-er seats, / "
                 "my best friend's face is blue and gold, / and my heart is skip-ping beats.", SCORE_CHART),
    SCORE_PRE, SCORE_CHORUS,
    SCORE_V.part("Verse 2", "verse", "Ev-ery-bod-y's breath is mak-ing clouds, / some-one's mom is sell-ing pie, / "
                 "and when you look a-cross at me, / Fri-day's light-ing up the sky.", SCORE_CHART),
    SCORE_PRE, SCORE_CHORUS,
    Lines(SCORE_FIELD, "r:0.5 A3:1 D4:0.5 F#4:1 E4:0.5 D4:0.5 C#4:4", SCORE_FIELD, "r:1 C#4:0.5 D4:0.5 E4:1 F#4:1 E4:4").part(
        "Bridge", "bridge", "One day this field will be emp-ty, / grass grown up through the lines, / "
        "but I'll be hear-ing the drum-line / ev-ery Fri-day night.", "Bm G D A Bm G A A"),
    SCORE_CHORUS,
    Lines(SCORE_HOOK, "r:0.5 B3:0.5 B3:0.5 D4:0.5 E4:1.5 D4:0.5 D4:4").part(
        "Outro", "outro", "Un-der the score-board lights, / the whole town's shin-ing bright.", "D A G D"),
], shapes={s["name"]: s for s in [D, A, BM_EASY, G_MAJ]}, words=WORDS)

UNIT_POP = unit("orig-6", "Four-chord pop anthems", "The four-chord loop five ways: two summer anthems, a roller-rink "
                "bop, a pop song in 6/8 and a stadium chorus.", [
    song_lesson("orig-sparkler-season", "Sparkler Season", [
        explain("The four-chord anthem", "Sparkler Season rides the most famous loop in pop: C, G, A minor and F, the one, "
                "five, six and four of C. Hundreds of hits share these chords; a new tune and new words make each one its own.",
                rhythm(FOLK)),
        explain("F, the easy way", "The mini F covers strings 4 to 1: finger 1 flat across strings 2 and 1 at fret 1, "
                "finger 2 on string 3, fret 2, finger 3 on string 4, fret 3.", shape(F_MINI)),
        play_chord(F_MINI),
        progression(bars(SPARK_CHART, C, G_MAJ, Am, F_MINI), FOLK, bpm=88),
        notes(G, ["E4", "D4", "E4", "D4", "G4", "D4", "G4", "E4", "D4"],
              hint="Open E and D at fret 3 on string 2, twice, then G at fret 3 on string 1, and back down to D."),
        SPARK.along("Chorus", bpm=88, title=HOOK),
        progression(bars(SPARK_CHART, C, G_MAJ, Am, F_MINI), FOLK, bpm=104),
        SPARK.take("Sparkler Season"),
    ], SPARK),
    song_lesson("orig-roller-rink", "Roller Rink", [
        explain("Retro roller-rink pop", "Roller Rink is bright dance pop at 120 beats per minute: G, E minor, C and D, the "
                "one, six, four and five. Strum even eighths and feel the kick drum land on every beat.", rhythm(EIGHTHS)),
        listen("Which chord is E minor?", [tones(G_MAJ), tones(Em)], FIRST_SECOND, 1),
        progression(bars(ROLLER_CHART, G_MAJ, Em, C, D), EIGHTHS, bpm=100),
        notes(G, ["D4", "E4", "G4", "G4", "G4", "F#4", "E4"],
              hint="D at fret 3 on string 2, open E, G at fret 3 on string 1 three times, F sharp at fret 2, open E."),
        ROLLER.along("Chorus", bpm=100, title=HOOK),
        ROLLER.along("Verse 1", bpm=104, title=VERSE),
        progression(bars(ROLLER_CHART, G_MAJ, Em, C, D), EIGHTHS, bpm=120),
        ROLLER.take("Roller Rink"),
    ], ROLLER),
    song_lesson("orig-echo-canyon", "Echo Canyon", [
        explain("Start on the six", "Echo Canyon plays E minor, C, G and D at 80 beats per minute. Big strum on one, let it "
                "ring, then build on three and four. The half-time beat makes it feel huge.", rhythm(BALLAD)),
        quiz("Kite Weather plays G, D, E minor and C. Echo Canyon plays E minor, C, G and D. What changed?",
             ["The starting chord", "The chords themselves", "The key"], 0,
             "Same four chords, same key. Starting on E minor puts the sad chord first, so the loop sounds darker."),
        progression(bars(ECHO_CHART, Em, C, G_MAJ, D), BALLAD, bpm=70),
        notes(G, ["G4", "E4", "G4", "E4", "G4", "D4", "G4", "D4"],
              hint="G at fret 3 on string 1 and open E, twice. Then G and D at fret 3 on string 2, twice."),
        ECHO.along("Chorus", bpm=70, title=HOOK),
        ECHO.along("Verse 1", bpm=72, title=VERSE),
        progression(bars(ECHO_CHART, Em, C, G_MAJ, D), BALLAD, bpm=80),
        ECHO.take("Echo Canyon"),
    ], ECHO),
    song_lesson("orig-open-windows", "Open Windows", [
        explain("Pop in 6/8", "Open Windows sways in 6/8 at 120 counts a minute: six quick counts felt as two big swings. "
                "C, F, A minor and G roll under a chorus that opens wide.", rhythm(SIX_EIGHT, beats_per_bar=6)),
        tap(SIX_EIGHT, bpm=100, bars=2, beats_per_bar=6),
        progression(bars(OPEN_CHART, C, F_MINI, Am, G_MAJ), SIX_EIGHT, bpm=100, beats_per_bar=6),
        notes(G, ["C4", "D4", "E4", "F4", "E4", "G4", "E4", "G4", "C4"],
              hint="C at fret 1 on string 2, D at fret 3, open E, F at fret 1 on string 1, E, G at fret 3, E, G, then C."),
        OPEN.along("Chorus", bpm=100, title=HOOK),
        progression(bars(OPEN_CHART, C, F_MINI, Am, G_MAJ), SIX_EIGHT, bpm=120, beats_per_bar=6),
        OPEN.take("Open Windows"),
    ], OPEN),
    song_lesson("orig-scoreboard-lights", "Scoreboard Lights", [
        explain("A Friday-night anthem", "Scoreboard Lights is a stadium anthem in D at 100 beats per minute: D, A, B minor "
                "and G, the same one, five, six, four loop in a new key. Drive steady eighths.", rhythm(DRIVE)),
        explain("B minor, the easy way", "This B minor uses the top four strings only: fret 4 on strings 4 and 3, fret 3 on "
                "string 2, fret 2 on string 1. The full barre comes later.", shape(BM_EASY)),
        play_chord(BM_EASY),
        progression(bars(SCORE_CHART, D, A, BM_EASY, G_MAJ), DRIVE, bpm=84),
        notes(G, ["A3", "B3", "D4", "G4", "F#4", "E4"],
              hint="A at fret 2 on string 3, open B, D at fret 3 on string 2, then G at fret 3 on string 1, F sharp, open E."),
        SCORE.along("Chorus", bpm=84, title=CHORUS),
        progression(bars(SCORE_CHART, D, A, BM_EASY, G_MAJ), DRIVE, bpm=100),
        SCORE.take("Scoreboard Lights"),
    ], SCORE),
    lesson("orig-pop-anthem-set", "Pop anthem set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's hook starts like this?", [["G4"], ["E4"], ["G4"], ["E4"], ["G4"], ["D4"]],
               ["Roller Rink", "Echo Canyon", "Sparkler Season"], 1),
        SPARK.along("Chorus", bpm=108, title="Sparkler Season"),
        progression(bars(ROLLER_CHART, G_MAJ, Em, C, D), EIGHTHS, bpm=124),
        ROLLER.along("Chorus", bpm=124, title="Roller Rink"),
        quiz("Which of these is the four-chord loop in C?", ["C, G, A minor, F", "C, F, G, C", "C, D, E, F"], 0,
             "The one, five, six and four of C are C, G, A minor and F."),
        ECHO.along("Chorus", bpm=84, title="Echo Canyon"),
        progression(bars(OPEN_CHART, C, F_MINI, Am, G_MAJ), SIX_EIGHT, bpm=126, beats_per_bar=6),
        SCORE.along("Chorus", bpm=104, title="Scoreboard Lights"),
    ], minutes=6, xp=40, kind="challenge"),
])
