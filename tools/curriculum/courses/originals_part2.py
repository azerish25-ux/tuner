"""Originals, part 2: thirty more songs written for Timbre, in the styles on the radio and the streaming charts today.

courses/originals.py places these six units between its own four, easiest first: three-chord sing-alongs, four-chord
pop, grooves on seventh chords, power-chord rock, story songs in three and six, and barre-chord pop. Every title, melody
and lyric is an original composition (words credited "Timbre"); chord progressions are shared by all of popular music,
melodies and words are not, so none of these borrows a line from anywhere. Melodies are sung lines in first position
(frets 0-4), one note at a time; 3/4 counts quarters and 6/8 counts eighths (beats_per_bar=6).

Sung parts are written a line at a time with `Lines`: each melody phrase carries one line of words, so a second verse is
checked against the same phrases line by line, not only in total.
"""
from lib import chord, explain, fretboard, fretted, lesson, listen, notes, play_chord, progression, quiz, rhythm, strum, tap, unit
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
D5 = chord(G, "D5", "x577xx", "x134xx")            # C5 slid up two frets
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
              hint="G at fret 3 on string 1 and open E, twice. Then G again and D at fret 3 on string 2, twice."),
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

# ================================================================ C. Grooves and seventh chords

# Late Checkout: lo-fi in C, 72 bpm, swung. Dm7, G7, Cmaj7 and Am7 on a loop (two, five, one, six).
LATE_V = Lines(swing("r:1 F4:1 E4:L D4:S C4:1 B3:L A3:S B3:3"),
               swing("r:1 E4:1 D4:L C4:S B3:1 A3:L G3:S A3:3"),
               swing("r:1 A3:1 C4:L D4:S F4:1 E4:L D4:S D4:1 B3:2"),
               swing("r:1 G4:1 E4:L D4:S E4:1 C4:L B3:S A3:3"))
LATE_HOOK = swing("r:1 E4:1 D4:L C4:S r:1 E4:1 D4:L B3:S r:2")
LATE_WAIT = swing("r:1 G4:1 E4:L D4:S E4:1 D4:L C4:S A3:3")
LATE_C = Lines(LATE_HOOK, swing("r:1 G4:1 E4:L D4:S E4:1 C4:L B3:S C4:3"), LATE_HOOK, LATE_WAIT)
LATE_CHART = "Dm7 G7 Cmaj7 Am7 Dm7 G7 Cmaj7 Am7"
LATE_CHORUS = LATE_C.part("Chorus", "chorus", "Late check-out, late check-out, / stay in the warm for a while; / "
                          "late check-out, late check-out, / let the whole cit-y just wait.", LATE_CHART)
LATE = song(G, 72, [
    Part("Intro", "intro", LATE_HOOK, chords="Dm7 G7"),
    LATE_V.part("Verse 1", "verse", "Do not dis-turb on the door, / cof-fee gone cold on the tray; / "
                "rain on the win-dow, a slow drum, / let's give the morn-ing a-way.", LATE_CHART),
    LATE_CHORUS,
    LATE_V.part("Verse 2", "verse", "Cit-y is honk-ing be-low, / both of our phones on the floor; / "
                "hum-ming a tune that I don't know, / and I don't want an-y-more.", LATE_CHART),
    LATE_CHORUS,
    Lines(swing("r:1 A3:L C4:S E4:1 C4:1 C4:L B3:S A3:3"), swing("r:1 D4:L F4:S F4:1 E4:1 D4:L C4:S B3:3")).part(
        "Bridge", "bridge", "Ev-ery Mon-day comes too soon, / so let's lose this af-ter-noon.", "Am7 Am7 Dm7 G7"),
    LATE_CHORUS,
    Lines(swing("r:1 G4:1 E4:L D4:S E4:1 D4:L C4:S C4:3")).part("Outro", "outro", "let the whole cit-y just wait.", "Dm7 Cmaj7"),
], shapes={s["name"]: s for s in [Dm7, G7, Cmaj7, Am7]}, words=WORDS)

# Saltwater Sunday: one-drop reggae in A minor, 76 bpm. Am7 and D7 trade bars (the Dorian sound); the chorus lifts to F and G.
SALT_V = Lines("r:1 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:1 A3:1 A3:2",
               "r:0.5 A3:1 C4:0.5 C4:0.5 E4:1 D4:0.5 F#4:1 E4:0.5 D4:0.5 D4:2",
               "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:0.5 A3:4",
               "r:0.5 A3:0.5 C4:0.5 D4:1 E4:0.5 F#4:0.5 E4:0.5 D4:4")
SALT_HOOK = "r:0.5 A3:0.5 C4:0.5 C4:0.5 E4:1 C4:1 D4:1 B3:1 D4:2"
SALT_C = Lines(SALT_HOOK, "r:0.5 E4:0.5 E4:0.5 E4:0.5 G4:1 E4:1 C4:0.5 C4:0.5 B3:1 A3:2",
               SALT_HOOK, "r:0.5 C4:0.5 C4:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 F#4:1 E4:0.5 D4:2")
SALT_CHART = "Am7 D7 Am7 D7 Am7 D7 Am7 D7"
SALT_CHORUS = SALT_C.part("Chorus", "chorus", "Salt-wa-ter Sun-day, roll on slow, / no-where to be and no-where to go; / "
                          "salt-wa-ter Sun-day, stay a-while, / ev-ery-bod-y wear-ing a sun-burned smile.", "F G Am7 Am7 F G Am7 D7")
SALT = song(G, 76, [
    Part("Intro", "intro", SALT_HOOK, chords="F G"),
    SALT_V.part("Verse 1", "verse", "Sun-day morn-ing, the tide rolls in, / salt in my hair and sand on my skin, / "
                "un-cle's grill-ing on the shore, / who could ev-er ask for more?", SALT_CHART),
    SALT_CHORUS,
    SALT_V.part("Verse 2", "verse", "Boats are bob-bing, the kids hold hands, / sun on the wa-ter, gold on the sand, / "
                "Gran-ny's hum-ming her old song, / ev-ery-bod-y sings a-long.", SALT_CHART),
    SALT_CHORUS,
    Lines("r:0.5 A3:0.5 C4:0.5 F4:1 E4:0.5 C4:0.5 A3:0.5 B3:4", "r:0.5 C4:0.5 C4:0.5 E4:1 F4:0.5 E4:0.5 C4:0.5 D4:4").part(
        "Bridge", "bridge", "Mon-day's com-ing round the bend, / but the sun's not set-ting yet.", "F G F G"),
    SALT_CHORUS,
    Lines("r:0.5 A3:0.5 C4:0.5 C4:0.5 E4:1 C4:1 C4:1 B3:1 A3:2").part(
        "Outro", "outro", "salt-wa-ter Sun-day, roll on slow.", "F Am7"),
], shapes={s["name"]: s for s in [Am7, D7, F_MINI, G_MAJ]}, words=WORDS)

# Pocket Change: funk in E minor, 100 bpm. A vamp on Em7, the chorus on A7, a bridge on Cmaj7 and B7.
POCKET_V = Lines("r:0.5 E4:0.5 E4:0.5 G4:0.5 r:0.5 E4:0.5 D4:0.5 E4:0.5 D4:0.5 B3:1.5 r:2",
                 "r:0.5 B3:0.5 B3:0.5 D4:0.5 r:0.5 B3:0.5 A3:0.5 B3:0.5 A3:0.5 G3:1.5 r:2",
                 "r:0.5 E4:0.5 E4:0.5 G4:0.5 r:0.5 E4:0.5 D4:0.5 E4:0.5 D4:0.5 B3:1.5 r:2",
                 "r:0.5 C#4:0.5 C#4:0.5 E4:0.5 r:0.5 C#4:0.5 B3:0.5 C#4:0.5 B3:0.5 A3:1.5 r:2")
POCKET_HOOK = "A3:0.5 C4:0.5 C#4:0.5 r:0.5 A3:0.5 C4:0.5 C#4:0.5 r:0.5"
POCKET_MOVE = "E4:0.5 E4:0.5 G4:0.5 E4:0.5 C#4:1 r:1"
POCKET_LOW = "B3:0.5 D4:0.5 E4:0.5 r:0.5 B3:0.5 D4:0.5 E4:0.5 r:0.5"
POCKET_GROOVE = "G4:0.5 G4:0.5 E4:0.5 D4:0.5 E4:1 r:1"
POCKET_C = Lines(POCKET_HOOK, POCKET_MOVE, POCKET_LOW, POCKET_GROOVE, POCKET_HOOK, POCKET_MOVE, POCKET_LOW, POCKET_GROOVE)
POCKET_CHART = "Em7 Em7 Em7 Em7 Em7 Em7 A7 A7"
POCKET_CHORUS = POCKET_C.part("Chorus", "chorus", "Pock-et change, pock-et change, / jing-ling when I move; / "
                              "pock-et change, pock-et change, / all I need's the groove. / Pock-et change, pock-et change, / "
                              "spend it on the beat; / pock-et change, pock-et change, / danc-ing on my feet.",
                              "A7 A7 Em7 Em7 A7 A7 Em7 Em7")
POCKET = song(G, 100, [
    Part("Intro", "intro", f"{POCKET_LOW} {POCKET_GROOVE} {POCKET_LOW} {POCKET_GROOVE}", chords="Em7 Em7 Em7 Em7"),
    POCKET_V.part("Verse 1", "verse", "Rent's paid up and the fridge is bare, / three old quar-ters and a bus fare, / "
                  "band's set up on the cor-ner, though, / and my feet are read-y to go.", POCKET_CHART),
    POCKET_CHORUS,
    POCKET_V.part("Verse 2", "verse", "Shoes got holes and my shirt's on loan, / bor-rowed hat and a bor-rowed phone, / "
                  "pock-et change, but I got the beat, / and the sound is free on the street.", POCKET_CHART),
    POCKET_CHORUS,
    Lines("E4:1 D4:0.5 E4:1 G4:0.5 E4:0.5 D4:0.5 E4:2 r:2", "D#4:1 F#4:1 D#4:1 B3:1 A3:2 r:2",
          "E4:0.5 E4:0.5 G4:1 E4:0.5 E4:0.5 E4:0.5 G4:0.5 E4:2 r:2", "B3:1 D#4:1 F#4:1 D#4:1 B3:2 r:2").part(
        "Bridge", "bridge", "Turn your pock-ets in-side out, / shake 'em to the floor; / "
        "ev-ery pen-ny, ev-ery but-ton, / that's what danc-ing's for.", "Cmaj7 Cmaj7 B7 B7 Cmaj7 Cmaj7 B7 B7"),
    POCKET_CHORUS,
    Lines(POCKET_LOW, POCKET_GROOVE, POCKET_LOW, "E4:1 r:3").part(
        "Outro", "outro", "pock-et change, pock-et change, / all I need's the groove, / pock-et change, pock-et change, / yeah!",
        "Em7 Em7 Em7 Em7"),
], shapes={s["name"]: s for s in [Em7, A7, Cmaj7, B7]}, words=WORDS)

# Kitchen Slow Dance: a soul ballad in 6/8, 108 counts a minute. Cmaj7, Am7, Dm7 and G7, then Fmaj7 and Em7 in the chorus.
KITCHEN_V = Lines("E4:2 D4:1 C4:2 B3:1 A3:2 C4:1 E4:3",
                  "F4:2 E4:1 D4:2 C4:1 B3:6",
                  "r:1 G3:1 C4:1 E4:1 G4:1 E4:1 D4:2 C4:1 C4:3",
                  "r:3 A3:1 C4:1 D4:1 F4:2 D4:4")
KITCHEN_HOOK = "E4:3 G4:2 E4:0.5 D4:0.5 E4:3 B3:3"
KITCHEN_AWAKE = "r:1 A3:1 C4:1 F4:2 D4:1 C4:6"
KITCHEN_C = Lines(KITCHEN_HOOK, "r:1 A3:1 C4:1 F4:2 E4:1 D4:6", "E4:2 F4:1 G4:2 E4:0.5 D4:0.5 E4:3 B3:3", KITCHEN_AWAKE)
KITCHEN_CHART = "Cmaj7 Am7 Dm7 G7 Cmaj7 Am7 Dm7 G7"
KITCHEN_CHORUS_CHART = "Fmaj7 Em7 Dm7 G7 Fmaj7 Em7 Dm7 Cmaj7"
KITCHEN_CHORUS = KITCHEN_C.part("Chorus", "chorus", "Slow dance in the kitch-en, / let the dish-es wait; / "
                                "one more song in the kitch-en, / on-ly us a-wake.", KITCHEN_CHORUS_CHART)
KITCHEN = song(G, 108, [
    Part("Intro", "intro", KITCHEN_HOOK, chords="Fmaj7 Em7"),
    KITCHEN_V.part("Verse 1", "verse", "Dish-es pil-ing in the sink, / ra-di-o turned low, / "
                   "you take my hand a-cross the floor, / and you won't let go.", KITCHEN_CHART),
    KITCHEN_CHORUS,
    KITCHEN_V.part("Verse 2", "verse", "Twen-ty years of mid-night tunes, / same old kitch-en light, / "
                   "your sock feet slid-ing on the tiles, / hold-ing me so tight.", KITCHEN_CHART),
    KITCHEN_CHORUS,
    Lines("C4:2 B3:1 C4:2 E4:1 G4:2 E4:1 C4:3", "r:1 D4:1 E4:1 F4:2 E4:1 D4:6").part(
        "Bridge", "bridge", "Kids grew up and moved a-way, / but this song still stays.", "Am7 Am7 Dm7 G7"),
    KITCHEN_CHORUS,
    Lines(KITCHEN_AWAKE).part("Outro", "outro", "on-ly us a-wake.", "Dm7 Cmaj7"),
], beats_per_bar=6, shapes={s["name"]: s for s in [Cmaj7, Am7, Dm7, G7, Fmaj7, Em7]}, words=WORDS)

# Houseplants: bedroom pop in G, 88 bpm. Gmaj7, Em7, Cmaj7 and D; the chorus adds Bm7.
HOUSE_V = Lines("r:1 B3:1 A3:0.5 B3:0.5 D4:1 B3:1 G3:3",
                "r:1 E4:1 D4:1 C4:0.5 B3:0.5 A3:4",
                "r:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 B3:0.5 D4:1 E4:3",
                "r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:0.5 A3:4")
HOUSE_HOOK = "G4:1 E4:0.5 G4:1 E4:0.5 D4:1 F#4:4"
HOUSE_WEEK = "F#4:1 D4:0.5 D4:0.5 F#4:1 E4:1 D4:4"
HOUSE_ME = "r:1 E4:1 D4:0.5 B3:0.5 D4:1 B3:4"
HOUSE_C = Lines(HOUSE_HOOK, HOUSE_WEEK, HOUSE_HOOK, HOUSE_ME)
HOUSE_CHART = "Gmaj7 Em7 Cmaj7 D Gmaj7 Em7 Cmaj7 D"
HOUSE_CHORUS_CHART = "Cmaj7 D Bm7 Em7 Cmaj7 D Gmaj7 Gmaj7"
HOUSE_CHORUS = HOUSE_C.part("Chorus", "chorus", "Keep the house-plants a-live, / wa-ter them twice a week; / "
                            "keep the house-plants a-live, / may-be they'll keep me.", HOUSE_CHORUS_CHART)
HOUSE = song(G, 88, [
    Part("Intro", "intro", f"{HOUSE_HOOK} {HOUSE_WEEK}", chords="Cmaj7 D Bm7 Em7"),
    HOUSE_V.part("Verse 1", "verse", "Fern on the win-dow-sill, / i-vy on the shelf, / "
                 "ev-ery morn-ing I say hel-lo / like I'm talk-ing to my-self.", HOUSE_CHART),
    HOUSE_CHORUS,
    HOUSE_V.part("Verse 2", "verse", "Spi-der plant's got ba-bies, / snake plant's stand-ing tall, / "
                 "if they can sur-vive the win-ter, / then I'll make it through it all.", HOUSE_CHART),
    HOUSE_CHORUS,
    Lines("r:0.5 B3:1 B3:0.5 D4:0.5 E4:1 D4:0.5 B3:2 G3:2", "r:0.5 E4:0.5 E4:0.5 G4:0.5 E4:0.5 G4:0.5 E4:0.5 D4:0.5 F#4:4").part(
        "Bridge", "bridge", "Some days the bed is heav-y, / but the leaves still turn to the sun.", "Em7 Em7 Cmaj7 D"),
    HOUSE_CHORUS,
    Lines(HOUSE_HOOK, HOUSE_ME).part("Outro", "outro", "keep the house-plants a-live, / may-be they'll keep me.",
                                     "Cmaj7 D Gmaj7 Gmaj7"),
], shapes={s["name"]: s for s in [Gmaj7, Em7, Cmaj7, D, Bm7]}, words=WORDS)

UNIT_GROOVE = unit("orig-7", "Grooves and seventh chords", "Lo-fi, one-drop reggae, funk, a 6/8 slow dance and bedroom "
                   "pop, on seventh chords that make a groove glow.", [
    song_lesson("orig-late-checkout", "Late Checkout", [
        explain("Lo-fi on a loop", "Late Checkout is lo-fi at 72 beats per minute: Dm7, G7, Cmaj7 and Am7 on a loop. Strum "
                "down on one, then down-up on three with the up a little late, and swing the tune the same way.", rhythm(LAZY)),
        explain("G7", "G7 is G with string 1 at fret 1 instead of fret 3: fingers 3 and 2 on strings 6 and 5, finger 1 on "
                "string 1. It leans hard toward C.", shape(G7)),
        play_chord(G7),
        listen("Which chord is Cmaj7?", [tones(C), tones(Cmaj7)], FIRST_SECOND, 1),
        progression(bars(LATE_CHART, Dm7, G7, Cmaj7, Am7), LAZY, bpm=64),
        LATE.along("Chorus", bpm=64, title=HOOK),
        progression(bars(LATE_CHART, Dm7, G7, Cmaj7, Am7), LAZY, bpm=72),
        LATE.take("Late Checkout"),
    ], LATE),
    song_lesson("orig-saltwater-sunday", "Saltwater Sunday", [
        explain("One-drop reggae", "Saltwater Sunday is reggae in A minor at 76 beats per minute. The guitar plays a double "
                "chop on two and four, chk-a, chk-a, while the drums drop their weight on three.", rhythm(SKANK)),
        tap(SKANK, bpm=70, bars=2),
        explain("D7 over A minor", "D7: finger 2 on string 3, fret 2, finger 1 on string 2, fret 1, finger 3 on string 1, "
                "fret 2. Am7 to D7 and back is the sunny, minor-but-bright sound of the whole song.", shape(D7)),
        strum(Am7, SKANK, bpm=70, bars=2),
        progression(bars(SALT_CHART, Am7, D7), SKANK, bpm=70),
        SALT.along("Chorus", bpm=70, title=CHORUS),
        progression(bars(SALT_CHART, Am7, D7), SKANK, bpm=76),
        SALT.take("Saltwater Sunday"),
    ], SALT),
    song_lesson("orig-pocket-change", "Pocket Change", [
        explain("Funk scratch", "Pocket Change is funk at 100 beats per minute: a vamp on Em7, with A7 for the chorus. Your "
                "strumming hand never stops moving in eighths; only some strokes ring.", rhythm(SCRATCH)),
        tap(SCRATCH, bpm=84, bars=2),
        explain("Scratch between the hits", "Between the strokes that ring, lay your fretting fingers lightly across the "
                "strings and keep strumming: the muted strokes go chk. Press down only for the hits.", shape(Em7)),
        strum(Em7, SCRATCH, bpm=84, bars=4),
        notes(G, ["A3", "C4", "C#4", "A3", "C4", "C#4"],
              hint="A at fret 2 on string 3, then C and C sharp at frets 1 and 2 on string 2. Twice."),
        POCKET.along("Chorus", bpm=84, title=HOOK),
        progression(bars(POCKET_CHART, Em7, A7), SCRATCH, bpm=100),
        POCKET.take("Pocket Change"),
    ], POCKET),
    song_lesson("orig-kitchen-slow-dance", "Kitchen Slow Dance", [
        explain("A slow dance in 6/8", "Kitchen Slow Dance is a soul ballad in 6/8 at 108 counts a minute, two slow sways a "
                "bar. Cmaj7, Am7, Dm7 and G7 carry the verse; Fmaj7 and Em7 open up the chorus.",
                rhythm(SIX_EIGHT, beats_per_bar=6)),
        explain("Fmaj7 and Em7", "Fmaj7 is the mini F with string 1 left open. Em7 takes one finger: finger 2 on string 5, "
                "fret 2, every other string open.", shape(Fmaj7)),
        play_chord(Em7),
        progression(bars(KITCHEN_CHART, Cmaj7, Am7, Dm7, G7), SIX_EIGHT, bpm=96, beats_per_bar=6),
        notes(G, ["E4", "G4", "E4", "D4", "E4", "B3"],
              hint="Open E, G at fret 3 on string 1, E, D at fret 3 on string 2, open E again, then open B."),
        KITCHEN.along("Chorus", bpm=96, title=CHORUS),
        progression(bars(KITCHEN_CHORUS_CHART, Fmaj7, Em7, Dm7, G7, Cmaj7), SIX_EIGHT, bpm=108, beats_per_bar=6),
        KITCHEN.take("Kitchen Slow Dance"),
    ], KITCHEN),
    song_lesson("orig-houseplants", "Houseplants", [
        explain("Bedroom pop in sevenths", "Houseplants is soft bedroom pop at 88 beats per minute: Gmaj7, Em7, Cmaj7 and D. "
                "Seventh chords make it dreamy. Strum once on one, then brush soft ups on the ands.", rhythm(SOUL)),
        explain("Gmaj7 and Bm7", "Gmaj7 is G with string 1 at fret 2 instead of fret 3. Bm7 puts three fingers at fret 2, on "
                "strings 5, 3 and 1, and lets strings 4 and 2 ring open.", shape(Gmaj7)),
        play_chord(Bm7),
        progression(bars(HOUSE_CHART, Gmaj7, Em7, Cmaj7, D), SOUL, bpm=76),
        notes(G, ["G4", "E4", "G4", "E4", "D4", "F#4"],
              hint="G at fret 3 on string 1 and open E, twice, then D at fret 3 on string 2 and F sharp at fret 2 on string 1."),
        HOUSE.along("Chorus", bpm=76, title=HOOK),
        progression(bars(HOUSE_CHORUS_CHART, Cmaj7, D, Bm7, Em7, Gmaj7), SOUL, bpm=88),
        HOUSE.take("Houseplants"),
    ], HOUSE),
    lesson("orig-groove-set", "Groove set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's hook starts like this?", [["A3"], ["C4"], ["C#4"], ["A3"], ["C4"], ["C#4"]],
               ["Saltwater Sunday", "Late Checkout", "Pocket Change"], 2),
        LATE.along("Chorus", bpm=76, title="Late Checkout"),
        progression(bars(SALT_CHART, Am7, D7), SKANK, bpm=80),
        SALT.along("Chorus", bpm=80, title="Saltwater Sunday"),
        quiz("Which chord has a major seventh?", ["G7", "Cmaj7", "Am7"], 1,
             "Cmaj7 adds B, a half step under C. G7 and Am7 add a flat seventh, a whole step under the root."),
        POCKET.along("Chorus", bpm=104, title="Pocket Change"),
        progression(bars(KITCHEN_CHART, Cmaj7, Am7, Dm7, G7), SIX_EIGHT, bpm=112, beats_per_bar=6),
        HOUSE.along("Chorus", bpm=92, title="Houseplants"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ D. Power-chord punk and rock

# Last Bell: punk-pop in C, 152 bpm. C5, G5, A5 and F5: the four-chord loop as power chords, all downstrokes.
LAST_V = Lines("C4:1 C4:0.5 E4:1 E4:0.5 G4:0.5 E4:0.5 D4:2 r:2",
               "C4:1 C4:0.5 E4:1 E4:0.5 G4:0.5 E4:0.5 C4:2 r:2",
               "E4:1 E4:0.5 G4:1 G4:0.5 G4:0.5 E4:0.5 D4:2 r:2",
               "E4:1 D4:0.5 C4:1 C4:0.5 D4:0.5 E4:0.5 C4:2 r:2")
LAST_PRE = Lines("E4:1 D4:1 C4:1 B3:1 D4:4", "C4:0.5 C4:0.5 F4:1 C4:0.5 C4:0.5 F4:1 D4:1 E4:1 G4:2").part(
    "Pre-chorus", "verse", "Five, four, three, two, one, / here it comes, here it comes, the last bell!", "A5 G5 F5 G5")
LAST_HOOK = "G4:1 E4:1 G4:1 E4:1 D4:0.5 D4:0.5 E4:1 D4:2"
LAST_CLOUDS = "E4:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 C4:0.5 C4:0.5 C4:0.5 A3:0.5 C4:3"
LAST_C = Lines(LAST_HOOK, LAST_CLOUDS, "G4:1 E4:0.5 E4:0.5 G4:1 E4:0.5 C4:0.5 D4:0.5 D4:0.5 E4:1 D4:2",
               "C4:0.5 C4:0.5 C4:0.5 E4:1 D4:0.5 C4:0.5 A3:0.5 C4:1 C4:3")
LAST_CHART = "C5 G5 A5 F5 C5 G5 A5 F5"
LAST_CHORUS = LAST_C.part("Chorus", "chorus", "Last bell, last bell, ring it out loud, / throw all your home-work up in-to the clouds; / "
                          "sum-mer's be-gin-ning and we're on our way, / no-bod-y's tak-ing this day a-way!", LAST_CHART)
LAST_VERSE = LAST_V.part("Verse 1", "verse", "Clock says two and fif-ty-nine, / sneak-ers laced and first in line, / "
                         "teach-er's talk-ing way too slow, / one more min-ute, then we go.", LAST_CHART)
LAST = song(G, 152, [
    Part("Intro", "intro", f"{LAST_HOOK} {LAST_CLOUDS}", chords="C5 G5 A5 F5"),
    LAST_VERSE, LAST_PRE, LAST_CHORUS,
    LAST_V.part("Verse 2", "verse", "Bus-es wait-ing at the door, / pa-pers scat-tered on the floor, / "
                "three whole months of sun to burn, / nev-er want-ing to re-turn.", LAST_CHART),
    LAST_PRE, LAST_CHORUS,
    LAST_VERSE.instrumental("Solo"),
    Lines("r:1 E4:1 E4:0.5 E4:0.5 G4:1 E4:4", "r:1 C4:0.5 F4:1 C4:0.5 C4:0.5 D4:0.5 C4:4",
          "r:1 E4:1 G4:1 G4:1 E4:4", "r:1 D4:1 G4:1 G4:1 D4:4").part(
        "Bridge", "bridge", "Hey, Mis-ter Ben-nett, / we'll miss you a lit-tle, / but not right now, / no, not right now!",
        "A5 A5 F5 F5 C5 C5 G5 G5"),
    LAST_CHORUS,
    Lines("G4:1 E4:1 G4:1 E4:1 D4:2 B3:2", "G4:1 E4:1 G4:1 E4:1 C4:4").part(
        "Outro", "outro", "Whoa, oh, whoa, oh, oh, oh, / last bell, last bell, go!", "C5 G5 C5 C5"),
], shapes={s["name"]: s for s in [C5, G5, A5, F5]}, words=WORDS)

# Copper Wire: riff rock in E, 112 bpm. The riff on the low strings, the voice over it, power chords in the chorus.
COPPER_RIFF = "E2:0.5 E2:0.5 G2:0.5 E2:0.5 A2:1 G2:0.5 E2:0.5 E2:0.5 E2:0.5 G2:0.5 E2:0.5 B2:0.5 A2:0.5 G2:0.5 A2:0.5"
COPPER_V = Lines("r:1 B3:0.5 B3:0.5 D4:1 B3:1 E4:1 D4:1 B3:2",
                 "r:1 B3:0.5 B3:0.5 D4:1 B3:1 A3:1 G3:1 E3:2",
                 "r:1 B3:0.5 B3:0.5 D4:1 B3:1 E4:1 D4:1 E4:2",
                 "r:1 D4:0.5 B3:0.5 D4:1 G3:1 A3:1 B3:1 A3:2")
COPPER_HOOK = "E4:1 G4:0.5 E4:2.5 D4:1 G4:0.5 D4:2.5"
COPPER_C = Lines(COPPER_HOOK, "r:1 B3:0.5 B3:0.5 E4:1 D4:1 E4:1 D4:1 B3:2",
                 COPPER_HOOK, "r:1 B3:0.5 D4:0.5 F#4:1 D4:1 F#4:1 E4:1 B3:2")
COPPER_CHART = "E5 E5 E5 E5 E5 E5 G5 A5"
COPPER_CHORUS_CHART = "A5 G5 E5 E5 A5 G5 B5 B5"
COPPER_CHORUS = COPPER_C.part("Chorus", "chorus", "Cop-per wire, cop-per wire, / run-ning hot in-side my hands; / "
                              "cop-per wire, cop-per wire, / lights the town up where I stand.", COPPER_CHORUS_CHART)
COPPER = song(G, 112, [
    Part("Intro", "intro", f"{COPPER_RIFF} {COPPER_RIFF}", chords="E5 E5 E5 E5"),
    COPPER_V.part("Verse 1", "verse", "Six old strings of cop-per wire, / one cracked speak-er, one bad plug, / "
                  "fin-gers burn-ing like a fire, / play it loud and play it rough.", COPPER_CHART),
    COPPER_CHORUS,
    Part("Riff", "interlude", f"{COPPER_RIFF} {COPPER_RIFF}", chords="E5 E5 E5 E5"),
    COPPER_V.part("Verse 2", "verse", "Neigh-bors knock-ing on the door, / Ma says, Hon-ey, not so loud, / "
                  "one more chord and then one more, / gon-na make this whole street proud.", COPPER_CHART),
    COPPER_CHORUS,
    Part("Solo", "solo", "E4:0.5 G4:0.5 E4:0.5 D4:0.5 B3:1 D4:1 E4:0.5 G4:0.5 E4:0.5 D4:0.5 B3:2 "
                         "A3:0.5 B3:0.5 D4:0.5 E4:0.5 G4:1 E4:1 D4:0.5 B3:0.5 A3:0.5 G3:0.5 E3:2 "
                         f"{COPPER_RIFF} {COPPER_RIFF}", chords="E5 E5 G5 A5 E5 E5 E5 E5"),
    COPPER_CHORUS,
    Part("Outro", "outro", f"{COPPER_RIFF} E3:2 B2:2 E2:4", chords="E5 E5 E5 E5"),
], shapes={s["name"]: s for s in [E5, G5, A5, B5]}, words=WORDS)

# Cold Lake: dark alternative rock in 6/8, E minor, 120 counts a minute. E5, C5, G5 and D5.
COLD_V = Lines("E3:1 G3:1 B3:1 B3:1 A3:1 G3:1 A3:2 G3:1 E3:3",
               "G3:1 C4:1 B3:1 C4:1 B3:1 A3:1 G3:2 A3:1 E3:3",
               "B3:1 B3:1 B3:1 D4:1 C4:1 B3:1 B3:1 A3:1 G3:1 B3:3",
               "A3:1 A3:1 A3:1 D4:1 C4:1 A3:1 A3:1 G3:1 F#3:1 A3:3")
COLD_HOOK = "G4:3 E4:3 G4:3 D4:3"
COLD_C = Lines(COLD_HOOK, "F#4:2 E4:1 D4:2 E4:1 E4:2 D4:1 B3:3", COLD_HOOK, "F#4:2 E4:1 D4:2 E4:1 D4:2 A3:1 D4:3")
COLD_CHART = "E5 E5 C5 C5 G5 G5 D5 D5"
COLD_CHORUS_CHART = "C5 G5 D5 E5 C5 G5 D5 D5"
COLD_CHORUS = COLD_C.part("Chorus", "chorus", "Cold lake, cold lake, / keep-ing ev-ery word we said; / "
                          "cold lake, cold lake, / fro-zen like the day you left.", COLD_CHORUS_CHART)
COLD = song(G, 120, [
    Part("Intro", "intro", COLD_HOOK, chords="C5 G5"),
    COLD_V.part("Verse 1", "verse", "Out on the ice where the cold wind blows, / I hear your voice in the hol-low pines; / "
                "ev-ery-thing qui-et and ev-ery-thing slow, / nev-er a word from you, nev-er a sign.", COLD_CHART),
    COLD_CHORUS,
    COLD_V.part("Verse 2", "verse", "Lights on the shore where you used to live, / some-bod-y new in your bed-room now; / "
                "I hold my breath and I lis-ten for you, / noth-ing but si-lence, and noth-ing to give.", COLD_CHART),
    COLD_CHORUS,
    Lines("E4:2 E4:1 G4:1 E4:1 C4:1 D4:2 E4:1 F#4:3", "G4:1 F#4:1 E4:1 D4:2 B3:1 E4:6").part(
        "Bridge", "bridge", "Spring will come and the ice will break, / I'll still be stand-ing here.", "C5 D5 E5 E5"),
    COLD_CHORUS,
    Lines("G4:3 E4:3 G4:3 E4:3").part("Outro", "outro", "Cold lake, cold lake.", "C5 E5"),
], beats_per_bar=6, shapes={s["name"]: s for s in [E5, C5, G5, D5]}, words=WORDS)

# Parking Lot Cathedral: indie-rock anthem in D, 128 bpm. D5, A5, B5 and G5.
PARK_V = Lines("r:0.5 A3:1 A3:0.5 D4:0.5 D4:0.5 E4:0.5 F#4:0.5 E4:1 D4:1 D4:2",
               "r:0.5 E4:1 C#4:0.5 E4:1 C#4:0.5 B3:0.5 B3:2 A3:2",
               "r:0.5 F#4:1 F#4:0.5 F#4:1 E4:0.5 D4:0.5 B3:1 D4:1 F#4:2",
               "r:0.5 G4:1 F#4:0.5 E4:1 D4:0.5 B3:0.5 D4:4")
PARK_HOOK = "D4:1 D4:0.5 F#4:1 E4:0.5 G4:1 E4:4"
PARK_SKY = "r:1 F#4:1 F#4:1 E4:0.5 F#4:0.5 G4:4"
PARK_C = Lines(PARK_HOOK, PARK_SKY, PARK_HOOK, "r:1 F#4:1 D4:1 B3:0.5 D4:0.5 D4:4")
PARK_CHART = "D5 D5 A5 A5 B5 B5 G5 G5"
PARK_CHORUS_CHART = "D5 A5 B5 G5 D5 A5 B5 G5"
PARK_CHORUS = PARK_C.part("Chorus", "chorus", "Park-ing lot ca-the-dral, / sing-ing to the sky; / "
                          "ev-ery voice a can-dle, / lift them up so high.", PARK_CHORUS_CHART)
PARK_VERSE = PARK_V.part("Verse 1", "verse", "Mid-night in the su-per-mar-ket lot, / four old cars in a cir-cle, / "
                         "head-lights on and the mu-sic up, / doors swung o-pen like wings.", PARK_CHART)
PARK = song(G, 128, [
    Part("Intro", "intro", f"{PARK_HOOK} {PARK_SKY}", chords="D5 A5 B5 G5"),
    PARK_VERSE, PARK_CHORUS,
    PARK_V.part("Verse 2", "verse", "Some-one's sing-ing on a sil-ver hood, / ev-ery-one is a choir now, / "
                "ech-oes bounce off the load-ing dock, / roof-tops ring-ing like bells.", PARK_CHART),
    PARK_CHORUS,
    PARK_VERSE.instrumental("Solo"),
    Lines("r:0.5 F#4:1 E4:0.5 D4:1 B3:0.5 B3:0.5 D4:1 B3:0.5 A3:0.5 B3:2",
          "r:0.5 D4:1 B3:0.5 D4:1 B3:0.5 G3:0.5 B3:2 G3:2",
          "r:0.5 A3:1 D4:0.5 F#4:1 E4:0.5 D4:0.5 F#4:2 E4:2",
          "r:0.5 E4:1 C#4:0.5 E4:1 C#4:0.5 A3:0.5 C#4:1 D4:1 E4:2").part(
        "Bridge", "bridge", "Morn-ing comes and the lot's just a lot, / carts and cracks in the con-crete, / "
        "still we know what we had here, / some-thing ho-ly and some-thing sweet.", "B5 B5 G5 G5 D5 D5 A5 A5"),
    PARK_CHORUS,
    Lines(PARK_HOOK, "r:1 F#4:1 E4:1 D4:0.5 E4:0.5 D4:4").part(
        "Outro", "outro", "Park-ing lot ca-the-dral, / sing-ing to the sky.", "D5 A5 G5 D5"),
], shapes={s["name"]: s for s in [D5, A5, B5, G5]}, words=WORDS)

# Halogen: desert rock in D minor, 104 bpm. A low riff on strings 4 and 5; F5, C5 and G5 open up the chorus.
HALO_RIFF = "D3:0.5 D3:0.5 F3:0.5 D3:0.5 G3:0.5 F3:0.5 D3:1 C3:0.5 C3:0.5 D3:0.5 F3:0.5 D3:2"
HALO_V = Lines("r:0.5 A3:0.5 A3:0.5 C4:1 A3:0.5 G3:0.5 F3:0.5 A3:1 G3:1 D3:2",
               "r:0.5 A3:0.5 A3:0.5 C4:1 A3:0.5 G3:0.5 F3:0.5 G3:1 A3:1 A3:2",
               "r:0.5 D4:0.5 D4:0.5 F4:1 D4:0.5 C4:0.5 A3:0.5 C4:1 D4:1 A3:2",
               "r:0.5 G3:0.5 G3:0.5 A3:0.5 C4:1 C4:0.5 A3:0.5 G3:0.5 C4:1 A3:0.5 G3:2")
HALO_HOOK = "F4:1 E4:0.5 C4:1.5 r:1 G4:1 E4:0.5 C4:1.5 r:1"
HALO_DARK = "r:1 D4:0.5 D4:0.5 F4:1 E4:1 D4:4"
HALO_C = Lines(HALO_HOOK, HALO_DARK, HALO_HOOK, "r:1 D4:1 D4:0.5 G4:1 F4:0.5 D4:4")
HALO_CHART = "D5 D5 D5 D5 D5 D5 C5 C5"
HALO_CHORUS_CHART = "F5 C5 G5 D5 F5 C5 G5 G5"
HALO_CHORUS = HALO_C.part("Chorus", "chorus", "Ha-lo-gen, ha-lo-gen, / cut-ting through the dark; / "
                          "ha-lo-gen, ha-lo-gen, / lead me where you are.", HALO_CHORUS_CHART)
HALO = song(G, 104, [
    Part("Intro", "intro", f"{HALO_RIFF} {HALO_RIFF}", chords="D5 D5 D5 D5"),
    HALO_V.part("Verse 1", "verse", "High-way's emp-ty and the moon's gone down, / miles of noth-ing and a long white line, / "
                "some-thing run-ning through the beams of light, / ha-lo-gen burn-ing through the des-ert night.", HALO_CHART),
    HALO_CHORUS,
    Part("Riff", "interlude", f"{HALO_RIFF} {HALO_RIFF}", chords="D5 D5 D5 D5"),
    HALO_V.part("Verse 2", "verse", "Mo-tel's va-cant and the pool is dry, / stars so close that I could touch the sky, / "
                "roll the win-dow down and sing it out, / ha-lo-gen shin-ing on the road a-head.", HALO_CHART),
    HALO_CHORUS,
    Lines("r:0.5 C4:0.5 C4:0.5 F4:1 E4:0.5 C4:1 A3:2 C4:2", "r:1 D4:1 D4:0.5 D4:0.5 G4:1 F4:4",
          "r:0.5 C4:0.5 C4:0.5 F4:1 E4:0.5 F4:0.5 G4:0.5 F4:2 C4:2", "r:1 E4:1 C#4:0.5 E4:1 C#4:0.5 A3:4").part(
        "Bridge", "bridge", "I don't know where the road ends, / long as I can drive; / "
        "ev-ery mile I put be-hind me / makes me feel a-live.", "F5 F5 G5 G5 F5 F5 A5 A5"),
    HALO_CHORUS,
    Part("Outro", "outro", f"{HALO_RIFF} D3:1 F3:1 A3:2 D3:4", chords="D5 D5 D5 D5"),
], shapes={s["name"]: s for s in [D5, C5, F5, G5, A5]}, words=WORDS)

UNIT_ROCK = unit("orig-8", "Power-chord punk and rock", "Punk-pop, riff rock, dark 6/8 rock, an indie anthem and desert "
                 "rock, on power chords and low-string riffs.", [
    song_lesson("orig-last-bell", "Last Bell", [
        explain("Punk-pop", "Last Bell is punk-pop at 152 beats per minute: C5, G5, A5 and F5, the four-chord loop as power "
                "chords. All downstrokes in steady eighths, palm resting on the strings by the bridge.", rhythm(EIGHTHS)),
        explain("F5", "F5 is the G5 shape two frets lower: finger 1 on string 6, fret 1, fingers 3 and 4 on strings 5 and 4 "
                "at fret 3.", shape(F5)),
        play_chord(F5),
        progression(bars(LAST_CHART, C5, G5, A5, F5), EIGHTHS, bpm=120),
        notes(G, ["G4", "E4", "G4", "E4", "D4", "D4", "E4", "D4"],
              hint="G at fret 3 on string 1 and open E, twice. Then D at fret 3 on string 2, twice, open E and D."),
        LAST.along("Chorus", bpm=120, title=CHORUS),
        progression(bars(LAST_CHART, C5, G5, A5, F5), EIGHTHS, bpm=152),
        LAST.take("Last Bell"),
    ], LAST),
    song_lesson("orig-copper-wire", "Copper Wire", [
        explain("Riff rock", "Copper Wire is built on a riff: a short, catchy line on the low strings that the whole band locks "
                "onto. It runs at 112 beats per minute in E, with power chords in the chorus.",
                fretboard(G, [(6, 0), (6, 3, 3), (5, 0), (5, 2, 2)])),
        notes(G, ["E2", "E2", "G2", "E2", "A2", "G2", "E2"],
              hint="Open string 6 twice, G at fret 3, open E, open string 5, G again, then open E."),
        notes(G, ["E2", "E2", "G2", "E2", "B2", "A2", "G2", "A2"],
              hint="The second bar turns around: B at fret 2 on string 5, open A, G at fret 3 on string 6, open A."),
        COPPER.along("Intro", bpm=92, title=RIFF),
        progression(bars(COPPER_CHORUS_CHART, A5, G5, E5, B5), PUSH, bpm=96),
        COPPER.along("Chorus", bpm=96, title=CHORUS),
        COPPER.along("Intro", bpm=112, title=RIFF),
        COPPER.take("Copper Wire"),
    ], COPPER),
    song_lesson("orig-cold-lake", "Cold Lake", [
        explain("Dark rock in 6/8", "Cold Lake is dark alternative rock in 6/8 at 120 counts a minute: E5, C5, G5 and D5. "
                "Keep the verse quiet and low so the chorus can open up.", rhythm(SIX_EIGHT, beats_per_bar=6)),
        listen("Does the hook climb or fall at first?", [["G4"], ["E4"], ["G4"], ["D4"]], CLIMB_FALL, 1),
        progression(bars(COLD_CHART, E5, C5, G5, D5), SIX_EIGHT, bpm=100, beats_per_bar=6),
        notes(G, ["G4", "E4", "G4", "D4"], hint="G at fret 3 on string 1, open E, G again, then D at fret 3 on string 2. Let each ring."),
        COLD.along("Chorus", bpm=100, title=HOOK),
        COLD.along("Verse 1", bpm=104, title=VERSE),
        progression(bars(COLD_CHORUS_CHART, C5, G5, D5, E5), SIX_EIGHT, bpm=120, beats_per_bar=6),
        COLD.take("Cold Lake"),
    ], COLD),
    song_lesson("orig-parking-lot-cathedral", "Parking Lot Cathedral", [
        explain("Indie-rock anthem", "Parking Lot Cathedral is indie rock at 128 beats per minute: D5, A5, B5 and G5, the "
                "four-chord loop again, now as power chords. Big, open, driving eighths.", rhythm(DRIVE)),
        explain("B5", "B5 is the A5 shape moved up two frets: finger 1 on string 5, fret 2, fingers 3 and 4 on strings 4 and 3 "
                "at fret 4.", shape(B5)),
        play_chord(B5),
        progression(bars(PARK_CHORUS_CHART, D5, A5, B5, G5), DRIVE, bpm=104),
        notes(G, ["D4", "D4", "F#4", "E4", "G4", "E4"],
              hint="D at fret 3 on string 2, twice, F sharp at fret 2 on string 1, open E, G at fret 3, open E."),
        PARK.along("Chorus", bpm=104, title=CHORUS),
        progression(bars(PARK_CHORUS_CHART, D5, A5, B5, G5), DRIVE, bpm=128),
        PARK.take("Parking Lot Cathedral"),
    ], PARK),
    song_lesson("orig-halogen", "Halogen", [
        explain("Desert rock", "Halogen is desert rock in D minor at 104 beats per minute: a hypnotic riff on strings 4 and 5, "
                "a low, steady voice, then F5, C5 and G5 opening up the chorus.",
                fretboard(G, [(4, 0), (4, 3, 3), (3, 0), (5, 3, 3)])),
        notes(G, ["D3", "D3", "F3", "D3", "G3", "F3", "D3"],
              hint="Open string 4 twice, F at fret 3, open D, open string 3, F again, then open D."),
        HALO.along("Intro", bpm=84, title=RIFF),
        progression(bars(HALO_CHORUS_CHART, F5, C5, G5, D5), PUSH, bpm=88),
        notes(G, ["F4", "E4", "C4", "G4", "E4", "C4"],
              hint="F at fret 1 on string 1, open E, C at fret 1 on string 2, then G at fret 3 on string 1, E and C."),
        HALO.along("Chorus", bpm=88, title=CHORUS),
        progression(bars(HALO_CHORUS_CHART, F5, C5, G5, D5), PUSH, bpm=104),
        HALO.take("Halogen"),
    ], HALO),
    lesson("orig-power-chord-set", "Power-chord set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's riff starts like this?", [["E2"], ["E2"], ["G2"], ["E2"], ["A2"]],
               ["Halogen", "Copper Wire", "Last Bell"], 1),
        LAST.along("Chorus", bpm=156, title="Last Bell"),
        COPPER.along("Intro", bpm=116, title="Copper Wire"),
        quiz("Which notes make up E5?", ["E and B", "E, G and B", "E and G"], 0,
             "A power chord is a root and its fifth, with no third, so it is neither major nor minor."),
        progression(bars(COLD_CHART, E5, C5, G5, D5), SIX_EIGHT, bpm=126, beats_per_bar=6),
        COLD.along("Chorus", bpm=126, title="Cold Lake"),
        PARK.along("Chorus", bpm=132, title="Parking Lot Cathedral"),
        HALO.along("Intro", bpm=108, title="Halogen"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ E. Story songs and slow burners

# Letters in a Shoebox: a singer-songwriter ballad in C, 72 bpm. The verse walks C, G, A minor, E minor, F, C, F, G.
LETTERS_V = Lines("r:0.5 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:0.5 D4:1.5 B3:2.5",
                  "r:0.5 C4:1 B3:0.5 A3:0.5 B3:0.5 C4:0.5 B3:0.5 G3:4",
                  "r:0.5 A3:0.5 A3:0.5 C4:1 A3:0.5 C4:0.5 F4:0.5 E4:1.5 C4:2.5",
                  "r:0.5 A3:0.5 C4:0.5 F4:1 E4:0.5 D4:0.5 C4:0.5 D4:4")
LETTERS_HOOK = "C4:1.5 D4:0.5 E4:1 F4:1 G4:2 D4:2"
LETTERS_TURN = "r:1 E4:1 D4:0.5 C4:1 D4:0.5 C4:4"
LETTERS_C = Lines(LETTERS_HOOK, "r:1 E4:1 D4:0.5 E4:1 G4:0.5 E4:4", LETTERS_HOOK, LETTERS_TURN)
LETTERS_CHART = "C G Am Em F C F G"
LETTERS_CHORUS_CHART = "F G C Am F G C C"
LETTERS_CHORUS = LETTERS_C.part("Chorus", "chorus", "Let-ters in a shoe-box, / love that time can't burn; / "
                                "ev-ery line a heart-beat / wait-ing for its turn.", LETTERS_CHORUS_CHART)
LETTERS = song(G, 72, [
    Part("Intro", "intro", LETTERS_HOOK, chords="F G"),
    LETTERS_V.part("Verse 1", "verse", "Found a shoe-box in the at-tic, / tied up with a bit of string, / "
                   "six-ty years of Grand-pa's let-ters / to a girl he called his spring.", LETTERS_CHART),
    LETTERS_CHORUS,
    LETTERS_V.part("Verse 2", "verse", "Ink gone brown and pa-per thin-ning, / ev-ery one be-gins, My Dear, / "
                   "ev-ery one ends, Yours for-ev-er, / and he signed them ev-ery year.", LETTERS_CHART),
    LETTERS_CHORUS,
    Lines("r:0.5 E4:1 C4:0.5 C4:0.5 E4:0.5 D4:0.5 C4:0.5 B3:4", "r:0.5 C4:1 A3:0.5 C4:0.5 F4:0.5 E4:0.5 C4:0.5 D4:4").part(
        "Bridge", "bridge", "Grand-ma, I read ev-ery one, / now I know where I come from.", "Am Em F G"),
    LETTERS_CHORUS,
    Lines(LETTERS_TURN).part("Outro", "outro", "wait-ing for its turn.", "Am C"),
], shapes={s["name"]: s for s in [C, G_MAJ, Am, Em, F_MINI]}, words=WORDS)

# Keeper's Daughter: a story song in 6/8, E minor, 120 counts a minute. E minor, D, C and B7; three verses tell it.
LIGHT_V = Lines("E4:1 E4:1 D4:1 B3:1 D4:1 E4:1 G4:2 F#4:1 E4:3",
                "F#4:2 E4:1 D4:2 A3:1 D4:2 E4:1 F#4:3",
                "E4:1 E4:1 E4:1 G4:2 E4:1 C4:2 D4:1 E4:3",
                "D#4:1 D#4:1 F#4:3 D#4:1 D#4:2 A3:1 B3:3")
LIGHT_HOOK = "B3:3 E4:3 G4:1 E4:1 C4:1 E4:2 C4:1"
LIGHT_C = Lines(LIGHT_HOOK, "D4:1 D4:1 D4:1 G4:1 F#4:1 E4:1 F#4:6",
                "B3:1 E4:1 E4:1 G4:1 F#4:1 E4:1 G4:1 E4:1 C4:1 E4:3",
                "D#4:1 F#4:1 F#4:1 F#4:1 E4:1 D#4:1 E4:6")
LIGHT_CHART = "Em Em D D C C B7 B7"
LIGHT_CHORUS_CHART = "Em C G D Em C B7 Em"
LIGHT_CHORUS = LIGHT_C.part("Chorus", "chorus", "Burn, burn, light on the wa-ter, / shine through the rain and the foam; / "
                            "the keep-er's daugh-ter is keep-ing the light / un-til they're all com-ing home.", LIGHT_CHORUS_CHART)
LIGHT = song(G, 120, [
    Part("Intro", "intro", LIGHT_HOOK, chords="Em C"),
    LIGHT_V.part("Verse 1", "verse", "Up on the point where the gray gulls cry, / Mar-y keeps the lamp at night; / "
                 "her fa-ther's boat went out at dawn, / and the sea turned black and white.", LIGHT_CHART),
    LIGHT_CHORUS,
    LIGHT_V.part("Verse 2", "verse", "Rain on the glass like a hun-dred drums, / Mar-y climbs the i-ron stair; / "
                 "she trims the wick and lifts the flame, / sings his name in-to the air.", LIGHT_CHART),
    LIGHT_CHORUS,
    LIGHT_V.part("Verse 3", "verse", "Just be-fore morn-ing a lan-tern swings, / small and yel-low, far from shore; / "
                 "she runs down to the har-bor wall, / he's come home to her once more.", LIGHT_CHART),
    LIGHT_CHORUS,
    Lines("r:3 F#4:1 E4:1 D#4:1 E4:6").part("Outro", "outro", "all com-ing home.", "B7 Em"),
], beats_per_bar=6, shapes={s["name"]: s for s in [Em, D, C, B7, G_MAJ]}, words=WORDS)

# Snow Globe Town: a music-box waltz in G, 3/4, 120 bpm. Every line is four bars.
SNOW_V = Lines("B3:1 B3:1 B3:1 D4:1 C4:1 B3:1 A3:2 B3:1 A3:3",
               "E4:1 E4:1 E4:1 G4:1 F#4:1 E4:1 E4:2 D4:1 C4:3",
               "B3:1 B3:1 D4:1 G4:1 F#4:1 E4:1 D4:2 E4:1 F#4:3",
               "E4:1 E4:1 E4:1 F#4:1 E4:1 D4:1 B3:2 A3:1 G3:3")
SNOW_HOOK = "E4:2 D4:1 C4:3 D4:2 C4:1 B3:3"
SNOW_C = Lines(SNOW_HOOK, "A3:1 D4:1 F#4:1 E4:2 D4:1 E4:3 B3:3", "E4:1 E4:1 E4:1 G4:3 D4:2 C4:1 B3:3",
               "A3:1 D4:1 E4:1 F#4:1 E4:1 D4:1 G4:6")
SNOW_CHART = "G G D D Em Em C C G G D D C D G G"
SNOW_CHORUS_CHART = "C C G G D D Em Em C C G G D D G G"
SNOW_CHORUS = SNOW_C.part("Chorus", "chorus", "Snow globe town, snow globe town, / no-bod-y ev-er grows old; / "
                          "shake me a-gain, snow globe town, / let me come home from the cold.", SNOW_CHORUS_CHART)
SNOW = song(G, 120, [
    Part("Intro", "intro", SNOW_HOOK, chords="C C G G"),
    SNOW_V.part("Verse 1", "verse", "Lit-tle glass town on a wood-en stand, / church and a mill and a tick-et booth; / "
                "shake it a-gain and the snow comes down / on the old streets where I spent my youth.", SNOW_CHART),
    SNOW_CHORUS,
    SNOW_V.part("Verse 2", "verse", "Snow on the roof of the old high school, / lamps in the square and a skat-ing pond; / "
                "ev-ery-one there is the age they were, / still as it was on the day I left.", SNOW_CHART),
    SNOW_CHORUS,
    Lines("B3:1 E4:1 G4:1 F#4:2 E4:1 D#4:3 r:3", "E4:1 E4:1 G4:1 E4:2 D4:1 F#4:6").part(
        "Bridge", "bridge", "Some-day the glass might crack, / but the snow will still fall.", "Em Em B7 B7 C C D D"),
    SNOW_CHORUS,
    Lines("E4:2 D4:1 C4:3 D4:2 B3:1 G3:3").part("Outro", "outro", "Snow globe town, snow globe town.", "C C G G"),
], beats_per_bar=3, shapes={s["name"]: s for s in [G_MAJ, D, Em, C, B7]}, words=WORDS)

# Thistle and Thread: a bright folk strummer in A, 116 bpm. A, Asus4, Asus2, D and E.
THISTLE_V = Lines("A3:1 C#4:0.5 C#4:0.5 E4:1 C#4:0.5 B3:0.5 D4:1 E4:1 A3:2",
                  "A3:1 C#4:0.5 C#4:0.5 E4:1 C#4:0.5 B3:0.5 B3:1 B3:1 E4:2",
                  "F#4:1 F#4:0.5 E4:0.5 D4:1 A3:0.5 D4:0.5 F#4:1 E4:1 D4:2",
                  "E4:1 C#4:0.5 C#4:0.5 E4:1 C#4:0.5 A3:0.5 B3:1 G#3:1 B3:2")
THISTLE_HOOK = "F#4:1 E4:0.5 D4:0.5 E4:2 E4:1 C#4:0.5 B3:0.5 A3:2"
THISTLE_STINGS = "E4:1 D4:0.5 B3:0.5 E4:1 B3:1 C#4:1 B3:0.5 A3:0.5 A3:2"
THISTLE_C = Lines(THISTLE_HOOK, THISTLE_STINGS, THISTLE_HOOK, "E4:1 E4:0.5 E4:0.5 G#4:1 E4:1 B3:1 B3:0.5 C#4:0.5 B3:2")
THISTLE_CHART = "A Asus4 A Asus2 D D A E"
THISTLE_CHORUS_CHART = "D A E A D A E E"
THISTLE_CHORUS = THISTLE_C.part("Chorus", "chorus", "This-tle and thread, this-tle and thread, / one of us stings and one of us mends; / "
                                "this-tle and thread, this-tle and thread, / sewn up to-geth-er right to the end.",
                                THISTLE_CHORUS_CHART)
THISTLE = song(G, 116, [
    Part("Intro", "intro", f"{THISTLE_HOOK} {THISTLE_STINGS}", chords="D A E A"),
    THISTLE_V.part("Verse 1", "verse", "You came to town with your col-lar up, / burrs on your sleeves and a frown-ing face; / "
                   "me with a nee-dle and spool of thread, / put-ting each thing in its prop-er place.", THISTLE_CHART),
    THISTLE_CHORUS,
    THISTLE_V.part("Verse 2", "verse", "You were the wind in a slam-ming door, / I was the hinge that would hold it still; / "
                   "you were the this-tle and I the thread, / stitched up to-geth-er a-gainst our will.", THISTLE_CHART),
    THISTLE_CHORUS,
    THISTLE_C.play("Solo", "solo", THISTLE_CHORUS_CHART),
    Lines("D4:1 D4:0.5 E4:0.5 F#4:1 E4:0.5 D4:0.5 A3:1 B3:1 D4:2",
          "E4:1 E4:0.5 E4:0.5 G#4:1 E4:0.5 D4:0.5 B3:1 B3:1 B3:2",
          "F#4:1 E4:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 E4:1 F#4:1 E4:2",
          "E4:1 E4:0.5 E4:0.5 G#4:1 F#4:0.5 E4:0.5 E4:1 D4:1 B3:2").part(
        "Bridge", "bridge", "Some-times you pull and I tear a seam, / some-times the col-ors don't match at all; / "
        "hold it up high in the win-dow light, / and it's the pret-ti-est quilt of all.", "D D E E D D E E"),
    THISTLE_CHORUS,
    Lines(THISTLE_HOOK, "E4:1 C#4:0.5 B3:0.5 A3:6").part(
        "Outro", "outro", "This-tle and thread, this-tle and thread, / this-tle and thread.", "D A A A"),
], shapes={s["name"]: s for s in [A, Asus4, Asus2, D, E]}, words=WORDS)

# Ghost Light: a slow minor-key ballad in A minor, 70 bpm. A minor, F, C and E major, whose G sharp pulls back home.
GHOST_V = Lines("r:0.5 E4:1 D4:0.5 C4:0.5 E4:1 C4:0.5 B3:0.5 A3:1.5 B3:0.5 C4:1.5",
                "r:0.5 F4:1 E4:0.5 C4:0.5 F4:1 E4:0.5 C4:0.5 A3:1.5 G3:0.5 A3:1.5",
                "r:0.5 G4:1 E4:0.5 C4:0.5 G4:1 E4:0.5 D4:0.5 E4:1.5 D4:0.5 C4:1.5",
                "r:0.5 B3:1 C4:0.5 B3:0.5 G#3:1 B3:0.5 E4:0.5 D4:1.5 C4:0.5 B3:1.5")
GHOST_HOOK = "F4:1.5 E4:2.5 G4:1.5 D4:2.5"
GHOST_C = Lines(GHOST_HOOK, "r:1 E4:0.5 E4:0.5 G4:1 E4:0.5 D4:0.5 C4:4", GHOST_HOOK, "r:1 B3:0.5 D4:0.5 E4:2 D4:2 B3:2")
GHOST_CHART = "Am Am F F C C E E"
GHOST_CHORUS_CHART = "F G C Am F G E E"
GHOST_CHORUS = GHOST_C.part("Chorus", "chorus", "Ghost light, ghost light, / for the ones who are gone; / "
                            "ghost light, ghost light, / they're still danc-ing on.", GHOST_CHORUS_CHART)
GHOST = song(G, 70, [
    Part("Intro", "intro", GHOST_HOOK, chords="F G"),
    GHOST_V.part("Verse 1", "verse", "Chains on the doors of the Pal-ace Hall, / dust on the seats in the bal-co-ny, / "
                 "left on the boards is a sin-gle light / burn-ing a-lone like a mem-o-ry.", GHOST_CHART),
    GHOST_CHORUS,
    GHOST_V.part("Verse 2", "verse", "Once I was young in a yel-low dress, / danc-ing in line with the com-pa-ny; / "
                 "you worked the lights up a-bove the stage, / leav-ing one on at the end for me.", GHOST_CHART),
    GHOST_CHORUS,
    Lines("r:0.5 F4:1 E4:0.5 D4:1 A3:1 C4:1 B3:1 A3:2", "r:1 B3:0.5 B3:0.5 D4:1 E4:1 D4:1 B3:3").part(
        "Bridge", "bridge", "Hold the cur-tain, one more bow, / they're all ap-plaud-ing now.", "Dm Am E E"),
    GHOST_CHORUS,
    Lines("F4:1.5 E4:2.5 B3:1.5 A3:2.5").part("Outro", "outro", "Ghost light, ghost light.", "F Am"),
], shapes={s["name"]: s for s in [Am, F_MINI, C, E, G_MAJ, Dm]}, words=WORDS)

UNIT_STORY = unit("orig-9", "Story songs and slow burners", "A ballad, a sea story in 6/8, a music-box waltz, a bright "
                  "folk strummer and a dark song in A minor.", [
    song_lesson("orig-letters-in-a-shoebox", "Letters in a Shoebox", [
        explain("A singer-songwriter ballad", "Letters in a Shoebox tells a story in C at 72 beats per minute. The verse walks "
                "C, G, A minor, E minor, F, C, F and G, a chain of chords that has carried ballads for centuries.", rhythm(BALLAD)),
        listen("Which chord is E minor?", [tones(C), tones(Em)], FIRST_SECOND, 1),
        progression(bars(LETTERS_CHART, C, G_MAJ, Am, Em, F_MINI), BALLAD, bpm=64),
        notes(G, ["C4", "D4", "E4", "F4", "G4", "D4"],
              hint="C at fret 1 on string 2, D at fret 3, open E, F at fret 1 on string 1, G at fret 3, then D again."),
        LETTERS.along("Chorus", bpm=64, title=CHORUS),
        LETTERS.along("Verse 1", bpm=66, title=VERSE),
        progression(bars(LETTERS_CHART, C, G_MAJ, Am, Em, F_MINI), BALLAD, bpm=72),
        LETTERS.take("Letters in a Shoebox"),
    ], LETTERS),
    song_lesson("orig-keepers-daughter", "Keeper's Daughter", [
        explain("A story in 6/8", "Keeper's Daughter is a story song in 6/8 at 120 counts a minute: E minor, D, C and B7. "
                "Three verses tell the story, and the chorus answers each one.", rhythm(SIX_EIGHT, beats_per_bar=6)),
        listen("Does this end at home?", [tones(B7), tones(Em)], HOME, 0),
        progression(bars(LIGHT_CHART, Em, D, C, B7), SIX_EIGHT, bpm=100, beats_per_bar=6),
        notes(G, ["B3", "E4", "G4", "E4", "C4", "E4", "C4"],
              hint="Open B, open E, G at fret 3 on string 1, open E, then C at fret 1 on string 2, E and C."),
        LIGHT.along("Chorus", bpm=100, title=CHORUS),
        LIGHT.along("Verse 1", bpm=104, title=VERSE),
        progression(bars(LIGHT_CHORUS_CHART, Em, C, G_MAJ, D, B7), SIX_EIGHT, bpm=120, beats_per_bar=6),
        LIGHT.take("Keeper's Daughter"),
    ], LIGHT),
    song_lesson("orig-snow-globe-town", "Snow Globe Town", [
        explain("A music-box waltz", "Snow Globe Town is a quick waltz in G at 120 beats per minute, like a music box: one "
                "strong beat, two light ones. G, D, E minor and C, with B7 in the bridge.", rhythm(WALTZ_UP, beats_per_bar=3)),
        tap(WALTZ, bpm=100, bars=2, beats_per_bar=3),
        progression(bars(SNOW_CHORUS_CHART, C, G_MAJ, D, Em), WALTZ_UP, bpm=100, beats_per_bar=3),
        notes(G, ["E4", "D4", "C4", "D4", "C4", "B3"],
              hint="Open E, D at fret 3 on string 2, C at fret 1, D, C, then open B: a slow fall, like snow."),
        SNOW.along("Chorus", bpm=100, title=HOOK),
        progression(bars(SNOW_CHART, G_MAJ, D, Em, C), WALTZ_UP, bpm=120, beats_per_bar=3),
        SNOW.take("Snow Globe Town"),
    ], SNOW),
    song_lesson("orig-thistle-and-thread", "Thistle and Thread", [
        explain("A folk strummer", "Thistle and Thread is a bright folk strummer in A at 116 beats per minute. Asus4 and Asus2 "
                "decorate the A chord: change one finger and the chord sparkles.", rhythm(SKIP)),
        explain("Asus4 and Asus2", "From A, put finger 4 on string 2, fret 3 for Asus4. Lift the finger off string 2 and let it "
                "ring open for Asus2. Both fall back to A.", shape(Asus4)),
        play_chord(Asus2),
        progression(bars(THISTLE_CHART, A, Asus4, Asus2, D, E), SKIP, bpm=96),
        notes(G, ["F#4", "E4", "D4", "E4", "E4", "C#4", "B3", "A3"],
              hint="F sharp at fret 2 on string 1, open E, D at fret 3 on string 2, E twice, C sharp, open B, then A."),
        THISTLE.along("Chorus", bpm=96, title=HOOK),
        progression(bars(THISTLE_CHORUS_CHART, D, A, E), SKIP, bpm=116),
        THISTLE.take("Thistle and Thread"),
    ], THISTLE),
    song_lesson("orig-ghost-light", "Ghost Light", [
        explain("A minor-key ballad", "Ghost Light is a slow, dark ballad in A minor at 70 beats per minute. The verse sinks "
                "from A minor through F and C to E major, which pulls hard back to A minor.", rhythm(BALLAD)),
        listen("Listen to the verse's last chord. Major or minor?", [tones(E)], MAJOR_MINOR, 0),
        quiz("E major in A minor brings one new note. Which?", ["F sharp", "G sharp", "C sharp"], 1,
             "A minor's own notes have G. E major needs G sharp, a half step under A, so it leans hard toward home."),
        progression(bars(GHOST_CHART, Am, F_MINI, C, E), BALLAD, bpm=62),
        notes(G, ["F4", "E4", "G4", "D4"], hint="F at fret 1 on string 1, open E, G at fret 3, then D at fret 3 on string 2. Hold each long."),
        GHOST.along("Chorus", bpm=62, title=HOOK),
        progression(bars(GHOST_CHART, Am, F_MINI, C, E), BALLAD, bpm=70),
        GHOST.take("Ghost Light"),
    ], GHOST),
    lesson("orig-story-set", "Story-song set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's hook starts like this?", [["E4"], ["D4"], ["C4"], ["D4"], ["C4"], ["B3"]],
               ["Ghost Light", "Snow Globe Town", "Keeper's Daughter"], 1),
        LETTERS.along("Chorus", bpm=76, title="Letters in a Shoebox"),
        progression(bars(LIGHT_CHART, Em, D, C, B7), SIX_EIGHT, bpm=126, beats_per_bar=6),
        LIGHT.along("Chorus", bpm=126, title="Keeper's Daughter"),
        quiz("How many beats fill a bar of 3/4?", ["Two", "Three", "Four"], 1,
             "3/4 counts one, two, three, with the weight on one: the waltz."),
        SNOW.along("Chorus", bpm=126, title="Snow Globe Town"),
        THISTLE.along("Chorus", bpm=120, title="Thistle and Thread"),
        GHOST.along("Chorus", bpm=74, title="Ghost Light"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ F. Barre chords and syncopation

# Slow Motion Strobe: synth-pop in A, 118 bpm. F sharp minor, D, A and E (vi-IV-I-V), a pushed strum.
STROBE_V = Lines("F#4:1 E4:0.5 C#4:0.5 E4:1 C#4:1 D4:1 C#4:0.5 A3:0.5 A3:2",
                 "E4:1 C#4:0.5 C#4:0.5 E4:1 C#4:1 B3:1 B3:0.5 G#3:0.5 B3:2",
                 "r:0.5 C#4:0.5 C#4:0.5 F#4:1 E4:0.5 C#4:0.5 A3:0.5 D4:1 C#4:1 A3:2",
                 "r:0.5 C#4:0.5 C#4:0.5 E4:1 E4:0.5 E4:0.5 C#4:0.5 B3:1 G#3:1 B3:2")
STROBE_PRE = Lines("r:1 D4:0.5 E4:0.5 F#4:1 E4:1 E4:1 D4:1 B3:2", "r:1 D4:0.5 E4:0.5 F#4:1 E4:1 G#4:1 F#4:1 E4:2").part(
    "Pre-chorus", "verse", "Ev-ery flash a pho-to-graph, / ev-ery sec-ond built to last.", "D E D E")
STROBE_HOOK = "E4:1 G#4:1 F#4:0.5 E4:0.5 C#4:0.5 E4:0.5 F#4:1.5 E4:2.5"
STROBE_WHITE = "r:0.5 C#4:0.5 C#4:0.5 E4:1 C#4:0.5 E4:0.5 F#4:0.5 E4:4"
STROBE_C = Lines(STROBE_HOOK, STROBE_WHITE, STROBE_HOOK, STROBE_WHITE)
STROBE_CHART = "F#m D A E F#m D A E"
STROBE_CHORUS = STROBE_C.part("Chorus", "chorus", "Slow mo-tion, un-der the strobe light, / ev-ery heart-beat flash-ing white; / "
                              "slow mo-tion, stay in this mo-ment, / you and me and no one else.", STROBE_CHART)
STROBE = song(G, 118, [
    Part("Intro", "intro", f"{STROBE_HOOK} {STROBE_WHITE}", chords="F#m D A E"),
    STROBE_V.part("Verse 1", "verse", "Bass in the floor-boards, lights in my eyes, / ev-ery-one's danc-ing, no-bod-y's shy; / "
                  "then I see you stand-ing in the light, / and the whole world's slow-ing down to-night.", STROBE_CHART),
    STROBE_PRE, STROBE_CHORUS,
    STROBE_V.part("Verse 2", "verse", "Glit-ter on col-lars, smoke in the air, / ev-ery-one sing-ing, no-bod-y cares; / "
                  "then you see me stand-ing in the light, / and the whole world's slow-ing down to-night.", STROBE_CHART),
    STROBE_PRE, STROBE_CHORUS,
    Lines("r:0.5 F#4:0.5 F#4:0.5 F#4:1 E4:0.5 D4:0.5 E4:0.5 E4:2 B3:2",
          "r:0.5 F#4:0.5 F#4:0.5 F#4:1 E4:0.5 C#4:0.5 A3:0.5 C#4:4",
          "r:0.5 D4:0.5 D4:0.5 E4:0.5 F#4:1 E4:0.5 D4:0.5 E4:1 F#4:1 G#4:2",
          "r:0.5 E4:0.5 E4:0.5 E4:1 C#4:0.5 E4:0.5 C#4:0.5 A3:4").part(
        "Bridge", "bridge", "Some-one's gon-na turn the lights on, / some-one's gon-na call a cab, / "
        "but right now we're in the in-be-tween, / and it's all we'll ev-er have.", "D E F#m F#m D E A A"),
    STROBE_CHORUS,
    Lines(STROBE_HOOK, STROBE_WHITE).part("Outro", "outro", "Slow mo-tion, un-der the strobe light, / you and me and no one else.",
                                          "F#m D E A"),
], shapes={s["name"]: s for s in [Fsm, D, A, E]}, words=WORDS)

# Bright Side of the Block: gospel-pop in D, 100 bpm. D, F sharp minor, G and A; B minor in the chorus.
BRIGHT_V = Lines("r:0.5 A3:0.5 A3:0.5 D4:1 D4:0.5 E4:0.5 F#4:0.5 F#4:4",
                 "r:0.5 B3:0.5 B3:0.5 D4:1 D4:0.5 E4:0.5 D4:0.5 C#4:4",
                 "r:0.5 A3:0.5 D4:0.5 F#4:1 E4:0.5 D4:0.5 E4:0.5 C#4:4",
                 "r:0.5 B3:0.5 D4:0.5 G4:1 F#4:0.5 E4:0.5 D4:0.5 E4:4")
BRIGHT_HOOK = "D4:1 E4:0.5 G4:1 F#4:0.5 E4:0.5 G4:0.5 E4:4"
BRIGHT_BLOCK = "F#4:1.5 E4:1.5 C#4:0.5 E4:0.5 D4:4"
BRIGHT_HOME = "r:0.5 A3:0.5 B3:0.5 D4:1 D4:0.5 E4:0.5 E4:0.5 D4:4"
BRIGHT_C = Lines(BRIGHT_HOOK, BRIGHT_BLOCK, BRIGHT_HOOK, BRIGHT_HOME)
BRIGHT_CHART = "D F#m G A D F#m G A"
BRIGHT_CHORUS_CHART = "G A F#m Bm G A D D"
BRIGHT_CHORUS = BRIGHT_C.part("Chorus", "chorus", "Come on down to the bright side, / bright side of the block; / "
                              "ev-ery door is o-pen wide / on the bright side of the block.", BRIGHT_CHORUS_CHART)
BRIGHT = song(G, 100, [
    Part("Intro", "intro", f"{BRIGHT_HOOK} {BRIGHT_BLOCK}", chords="G A F#m Bm"),
    BRIGHT_V.part("Verse 1", "verse", "Sun comes up on Mar-ket Street, / Ro-sa's sweep-ing off her step, / "
                  "Mis-ter Lee is hum-ming low, / not a soul is wor-ried yet.", BRIGHT_CHART),
    BRIGHT_CHORUS,
    BRIGHT_V.part("Verse 2", "verse", "Bar-ber's got his chairs out-side, / dom-i-noes on card-board crates, / "
                  "ba-by's danc-ing in the shade, / ev-ery-bod-y cel-e-brates.", BRIGHT_CHART),
    BRIGHT_CHORUS,
    Lines("r:0.5 F#4:0.5 F#4:0.5 F#4:1 D4:0.5 B3:0.5 D4:0.5 C#4:4",
          "r:0.5 G4:0.5 G4:0.5 G4:1 E4:0.5 D4:0.5 E4:0.5 E4:4",
          "r:0.5 F#4:0.5 F#4:0.5 F#4:1 D4:0.5 B3:0.5 D4:0.5 C#4:4",
          "r:0.5 D4:0.5 E4:0.5 G4:1 F#4:0.5 E4:0.5 D4:0.5 E4:4").part(
        "Bridge", "bridge", "Ev-ery-bod-y, clap your hands, / ev-ery-bod-y, stomp your feet, / "
        "if you got a voice, then sing, / sing it down the Mar-ket Street.", "Bm F#m G A Bm F#m G A"),
    BRIGHT_CHORUS,
    Lines(BRIGHT_HOME, BRIGHT_HOME).part("Outro", "outro", "on the bright side of the block, / on the bright side of the block.",
                                         "G A D D"),
], shapes={s["name"]: s for s in [D, Fsm, G_MAJ, A, Bm]}, words=WORDS)

# Over You Soon: dark pop in B minor, 84 bpm. B minor, G, D and A, soft ups on the ands.
HOLLOW_V = Lines("r:0.5 F#4:0.5 F#4:0.5 F#4:1 E4:0.5 D4:0.5 B3:0.5 D4:2 B3:2",
                 "r:0.5 F#4:0.5 E4:0.5 D4:1 C#4:0.5 D4:0.5 E4:0.5 C#4:4",
                 "r:0.5 D4:0.5 D4:0.5 F#4:1 E4:0.5 F#4:0.5 G4:0.5 F#4:2 D4:2",
                 "r:0.5 F#4:0.5 E4:0.5 D4:1 C#4:0.5 B3:0.5 A3:0.5 A3:4")
HOLLOW_HOOK = "G4:1 F#4:0.5 D4:2.5 F#4:1 E4:0.5 D4:2.5"
HOLLOW_ROOM = "r:0.5 E4:0.5 E4:0.5 E4:1 C#4:0.5 E4:0.5 C#4:0.5 B3:4"
HOLLOW_SOON = "r:0.5 E4:0.5 E4:0.5 G4:1 F#4:1 E4:0.5 F#4:4"
HOLLOW_C = Lines(HOLLOW_HOOK, HOLLOW_ROOM, HOLLOW_HOOK, HOLLOW_SOON)
HOLLOW_CHART = "Bm G D A Bm G D A"
HOLLOW_CHORUS_CHART = "G D A Bm G D A Bm"
HOLLOW_CHORUS = HOLLOW_C.part("Chorus", "chorus", "Hol-low moon, hol-low moon, / light-ing up an emp-ty room; / "
                              "hol-low moon, hol-low moon, / I'll be o-ver you soon.", HOLLOW_CHORUS_CHART)
HOLLOW = song(G, 84, [
    Part("Intro", "intro", f"{HOLLOW_HOOK} {HOLLOW_ROOM}", chords="G D A Bm"),
    HOLLOW_V.part("Verse 1", "verse", "Clock says three, the fan keeps turn-ing, / street-light leak-ing through the blinds, / "
                  "phone face-down up-on your pil-low, / you're still liv-ing in my mind.", HOLLOW_CHART),
    HOLLOW_CHORUS,
    HOLLOW_V.part("Verse 2", "verse", "Sweat-er hang-ing on the door-knob, / cof-fee cups for two a-gain, / "
                  "I keep talk-ing to the ceil-ing, / tell-ing it where I have been.", HOLLOW_CHART),
    HOLLOW_CHORUS,
    Lines("r:0.5 B3:0.5 B3:0.5 E4:1 D4:0.5 E4:0.5 G4:0.5 F#4:2 E4:2", "r:0.5 D4:0.5 D4:0.5 G4:1 F#4:0.5 E4:0.5 D4:0.5 E4:4").part(
        "Bridge", "bridge", "They all say that time will fix it, / time's just sit-ting here with me.", "Em Em G A"),
    HOLLOW_CHORUS,
    Lines(HOLLOW_HOOK, HOLLOW_SOON).part("Outro", "outro", "Hol-low moon, hol-low moon, / I'll be o-ver you soon.",
                                         "G D A Bm"),
], shapes={s["name"]: s for s in [Bm, G_MAJ, D, A, Em]}, words=WORDS)

# Spray Paint Sunrise: indie pop in E, 124 bpm. E, B, C sharp minor and A, with two barres.
SPRAY_V = Lines("r:0.5 B3:0.5 B3:0.5 E4:1 E4:0.5 D#4:0.5 E4:0.5 D#4:0.5 B3:3.5",
                "C#4:1 C#4:0.5 C#4:0.5 E4:1 C#4:0.5 B3:0.5 C#4:1 B3:1 A3:2",
                "r:0.5 B3:0.5 B3:0.5 E4:1 E4:0.5 F#4:0.5 G#4:0.5 F#4:0.5 D#4:3.5",
                "C#4:1 C#4:0.5 E4:0.5 G#4:1 E4:0.5 C#4:0.5 C#4:1 B3:1 A3:2")
SPRAY_PRE = Lines("r:0.5 C#4:1 C#4:0.5 B3:0.5 E4:1 C#4:0.5 D#4:2 B3:2", "r:0.5 C#4:1 E4:0.5 E4:0.5 F#4:1 E4:0.5 F#4:1 F#4:3").part(
    "Pre-chorus", "verse", "Some-day they'll paint it o-ver, / but not to-day, not to-day!", "A B A B")
SPRAY_HOOK = "G#4:1 F#4:0.5 E4:1 B3:1.5 D#4:1 C#4:0.5 D#4:0.5 F#4:2"
SPRAY_HERE = "r:1 E4:0.5 E4:0.5 G#4:2 E4:0.5 E4:0.5 C#4:3"
SPRAY_C = Lines(SPRAY_HOOK, SPRAY_HERE, SPRAY_HOOK, "r:0.5 E4:0.5 E4:0.5 G#4:1 F#4:0.5 E4:0.5 C#4:0.5 C#4:4")
SPRAY_CHART = "E B C#m A E B C#m A"
SPRAY_CHORUS = SPRAY_C.part("Chorus", "chorus", "Spray paint sun-rise, gold on the gray, / we were here, we were here; / "
                            "spray paint sun-rise, burn-ing a-way, / we were young and we were here.", SPRAY_CHART)
SPRAY_TRAIN = "r:0.5 E4:0.5 E4:0.5 G#4:1 E4:0.5 C#4:0.5 E4:0.5 E4:4"
SPRAY = song(G, 124, [
    Part("Intro", "intro", f"{SPRAY_HOOK} {SPRAY_HERE}", chords="E B C#m A"),
    SPRAY_V.part("Verse 1", "verse", "Half past five at the un-der-pass, / two cans of blue and a can of gold, / "
                 "trains go by and they shake the wall, / paint-ing our names where the con-crete's cold.", SPRAY_CHART),
    SPRAY_PRE, SPRAY_CHORUS,
    SPRAY_V.part("Verse 2", "verse", "Dogs start bark-ing a-cross the tracks, / sun com-ing up in a streak of red, / "
                 "you've got paint all a-cross your nose, / laugh-ing so loud that we wake the dead.", SPRAY_CHART),
    SPRAY_PRE, SPRAY_CHORUS,
    Lines(SPRAY_TRAIN, "r:1 E4:1 D#4:0.5 E4:1 F#4:0.5 D#4:4", SPRAY_TRAIN, "r:1 D#4:1 C#4:0.5 D#4:1 E4:0.5 F#4:4").part(
        "Bridge", "bridge", "Peo-ple on the morn-ing train / look up from their phones, / see a sun that some-one made, / "
        "and they're not a-lone.", "C#m A E B C#m A B B"),
    SPRAY_CHORUS,
    Lines(SPRAY_HOOK, "r:0.5 E4:0.5 E4:0.5 G#4:1 F#4:0.5 E4:0.5 D#4:0.5 E4:4").part(
        "Outro", "outro", "spray paint sun-rise, burn-ing a-way, / we were young and we were here.", "E B A E"),
], shapes={s["name"]: s for s in [E, B_BARRE, Csm, A]}, words=WORDS)

# Constellation Prize: the finale, an anthem in 6/8 in F, 126 counts a minute. F, C, D minor and B flat.
STARS_V = Lines("A3:2 C4:1 F4:1 E4:1 C4:1 D4:2 C4:1 A3:3",
                "E4:2 D4:1 C4:2 G3:1 C4:2 D4:1 E4:3",
                "A3:2 D4:1 F4:1 E4:1 D4:1 E4:2 D4:1 A3:3",
                "D4:2 C4:1 Bb3:2 C4:1 D4:2 E4:1 C4:3")
STARS_HOOK = "D4:1 F4:1 F4:1 G4:2 F4:1 F4:2 E4:1 F4:3"
STARS_HOME = "C4:1 E4:1 D4:1 E4:2 G4:1 F4:2 E4:1 F4:3"
STARS_C = Lines(STARS_HOOK, "C4:1 E4:1 E4:1 G4:2 E4:1 F4:2 E4:1 D4:3", "D4:1 F4:1 F4:1 G4:2 F4:1 F4:2 E4:1 C4:3", STARS_HOME)
STARS_CHART = "F F C C Dm Dm Bb C"
STARS_CHORUS_CHART = "Bb F C Dm Bb F C F"
STARS_CHORUS = STARS_C.part("Chorus", "chorus", "I won the con-stel-la-tion prize, / a mil-lion lights a-cross the skies; / "
                            "and ev-ery star is shin-ing free, / I'm right where I'm sup-posed to be.", STARS_CHORUS_CHART)
STARS = song(G, 126, [
    Part("Intro", "intro", STARS_HOOK, chords="Bb F"),
    STARS_V.part("Verse 1", "verse", "Came in last at the tal-ent show, / string snapped half-way through my song; / "
                 "walked home un-der the street-lamp glow, / laugh-ing 'cause it all went wrong.", STARS_CHART),
    STARS_CHORUS,
    STARS_V.part("Verse 2", "verse", "No blue rib-bon and no gold cup, / tro-phy went to some-one else; / "
                 "but the sky was a mil-lion bright, / and I sang it to my-self.", STARS_CHART),
    STARS_CHORUS,
    Lines("D4:2 C4:1 D4:2 E4:1 F4:2 E4:1 D4:3", "D4:2 C4:1 D4:2 F4:1 F4:2 D4:1 Bb3:3",
          "C4:2 C4:1 F4:2 G4:1 F4:2 E4:1 C4:3", "E4:2 D4:1 E4:2 G4:1 G4:2 E4:1 E4:3").part(
        "Bridge", "bridge", "Nev-er gon-na be the first, / nev-er gon-na win the race, / "
        "but I'll take the sky I've got / and the light up-on my face.", "Dm Dm Bb Bb F F C C"),
    STARS_CHORUS,
    Lines(STARS_HOME).part("Outro", "outro", "I'm right where I'm sup-posed to be.", "C F"),
], beats_per_bar=6, shapes={s["name"]: s for s in [F_BARRE, C, Dm, Bb]}, words=WORDS)

UNIT_BARRE = unit("orig-10", "Barre chords and syncopation", "Synth-pop, gospel-pop, dark pop, indie pop and a 6/8 finale, "
                  "with five new barre chords.", [
    song_lesson("orig-slow-motion-strobe", "Slow Motion Strobe", [
        explain("Synth-pop on guitar", "Slow Motion Strobe is synth-pop at 118 beats per minute: F sharp minor, D, A and E. "
                "The strum is pushed: two of its hits land on the and, just before the beat.", rhythm(STAB)),
        explain("F sharp minor, the barre", "Barre finger 1 across all six strings at fret 2, then put fingers 3 and 4 on "
                "strings 5 and 4 at fret 4: the E minor shape, moved up two frets.", shape(Fsm)),
        play_chord(Fsm),
        tap(STAB, bpm=96, bars=2),
        progression(bars(STROBE_CHART, Fsm, D, A, E), STAB, bpm=96),
        STROBE.along("Chorus", bpm=96, title=CHORUS),
        progression(bars(STROBE_CHART, Fsm, D, A, E), STAB, bpm=118),
        STROBE.take("Slow Motion Strobe"),
    ], STROBE, xp=40),
    song_lesson("orig-bright-side-of-the-block", "Bright Side of the Block", [
        explain("Gospel-pop", "Bright Side of the Block is a gospel-pop sing-along in D at 100 beats per minute: D, F sharp "
                "minor, G and A. Clap on two and four and sing the chorus like the whole street joins in.", rhythm(SKIP)),
        explain("B minor, the full barre", "Barre finger 1 across strings 5 to 1 at fret 2, then build an A minor shape two "
                "frets up with fingers 2, 3 and 4. Leave string 6 silent.", shape(Bm)),
        play_chord(Bm),
        progression(bars(BRIGHT_CHART, D, Fsm, G_MAJ, A), SKIP, bpm=84),
        notes(G, ["D4", "E4", "G4", "F#4", "E4", "G4", "E4"],
              hint="D at fret 3 on string 2, open E, G at fret 3 on string 1, F sharp at fret 2, E, G, then E."),
        BRIGHT.along("Chorus", bpm=84, title=CHORUS),
        progression(bars(BRIGHT_CHORUS_CHART, G_MAJ, A, Fsm, Bm, D), SKIP, bpm=100),
        BRIGHT.take("Bright Side of the Block"),
    ], BRIGHT, xp=40),
    song_lesson("orig-over-you-soon", "Over You Soon", [
        explain("Dark pop", "Over You Soon is dark pop in B minor at 84 beats per minute: B minor, G, D and A. Strum once on "
                "one, then soft ups on the ands, and keep it hushed.", rhythm(SOUL)),
        listen("Listen to the first chord. Major or minor?", [tones(Bm)], MAJOR_MINOR, 1),
        progression(bars(HOLLOW_CHART, Bm, G_MAJ, D, A), SOUL, bpm=72),
        notes(G, ["G4", "F#4", "D4", "F#4", "E4", "D4"],
              hint="G at fret 3 on string 1, F sharp at fret 2, D at fret 3 on string 2, then F sharp, open E and D."),
        HOLLOW.along("Chorus", bpm=72, title=HOOK),
        HOLLOW.along("Verse 1", bpm=76, title=VERSE),
        progression(bars(HOLLOW_CHORUS_CHART, G_MAJ, D, A, Bm), SOUL, bpm=84),
        HOLLOW.take("Over You Soon"),
    ], HOLLOW, xp=40),
    song_lesson("orig-spray-paint-sunrise", "Spray Paint Sunrise", [
        explain("Indie pop in E", "Spray Paint Sunrise is indie pop at 124 beats per minute: E, B, C sharp minor and A, the "
                "four-chord loop with two barres. Drive steady eighths and let it run.", rhythm(DRIVE)),
        explain("B and C sharp minor", "B is an A shape barred at fret 2: finger 1 across strings 5 to 1, three fingers at "
                "fret 4. C sharp minor is an A minor shape barred at fret 4.", shape(B_BARRE)),
        play_chord(Csm),
        progression(bars(SPRAY_CHART, E, B_BARRE, Csm, A), DRIVE, bpm=100),
        notes(G, ["G#4", "F#4", "E4", "B3", "D#4", "C#4", "D#4", "F#4"],
              hint="G sharp at fret 4 on string 1, F sharp, open E, open B, then D sharp at fret 4 on string 2, C sharp, D sharp."),
        SPRAY.along("Chorus", bpm=100, title=CHORUS),
        progression(bars(SPRAY_CHART, E, B_BARRE, Csm, A), DRIVE, bpm=124),
        SPRAY.take("Spray Paint Sunrise"),
    ], SPRAY, xp=40),
    song_lesson("orig-constellation-prize", "Constellation Prize", [
        explain("The big finish in 6/8", "Constellation Prize closes the course: an anthem in 6/8 at 126 counts a minute, in "
                "F. F and B flat are both barres, with C and D minor between them.", rhythm(SIX_EIGHT, beats_per_bar=6)),
        explain("B flat, the A-shape barre", "Barre finger 1 across strings 5 to 1 at fret 1, then put fingers 2, 3 and 4 on "
                "strings 4, 3 and 2 at fret 3. Leave string 6 silent.", shape(Bb)),
        play_chord(Bb),
        progression(bars(STARS_CHORUS_CHART, Bb, F_BARRE, C, Dm), SIX_EIGHT, bpm=104, beats_per_bar=6),
        notes(G, ["D4", "F4", "F4", "G4", "F4", "F4", "E4", "F4"],
              hint="D at fret 3 on string 2, F at fret 1 on string 1 twice, G at fret 3, F twice, open E, then F."),
        STARS.along("Chorus", bpm=104, title=HOOK),
        progression(bars(STARS_CHART, F_BARRE, C, Dm, Bb), SIX_EIGHT, bpm=126, beats_per_bar=6),
        STARS.take("Constellation Prize"),
    ], STARS, xp=40),
    lesson("orig-barre-set", "Barre-chord set", [
        explain(SET_TITLE, SET_LIST),
        listen("Which song's hook starts like this?", [["G4"], ["F#4"], ["D4"], ["F#4"], ["E4"], ["D4"]],
               ["Over You Soon", "Slow Motion Strobe", "Bright Side of the Block"], 0),
        STROBE.along("Chorus", bpm=122, title="Slow Motion Strobe"),
        progression(bars(BRIGHT_CHART, D, Fsm, G_MAJ, A), SKIP, bpm=104),
        BRIGHT.along("Chorus", bpm=104, title="Bright Side of the Block"),
        quiz("F sharp minor is which shape, barred at fret 2?", ["E minor", "A", "D"], 0,
             "Barre at fret 2 and the E minor shape sits in front of your first finger: F sharp minor."),
        SPRAY.along("Chorus", bpm=128, title="Spray Paint Sunrise"),
        progression(bars(STARS_CHORUS_CHART, Bb, F_BARRE, C, Dm), SIX_EIGHT, bpm=130, beats_per_bar=6),
        STARS.along("Chorus", bpm=130, title="Constellation Prize"),
    ], minutes=6, xp=40, kind="challenge"),
])
