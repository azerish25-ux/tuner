"""Originals: new songs written for Timbre in the styles people play today, easiest first.

Every title and melody here is an original composition, so nothing needs a license. Melodies are
lib.along strings ("note:beats") in first position (frets 0–4); 3/4 counts quarters and 6/8 counts
eighths (beats_per_bar=6). Swung melodies write L and S for the long and short halves of a beat
(see swing()). Unit 1 uses only the open chords from guitar units 3–5; later units add sevenths,
sus chords, power chords and barres in the order the guitar course teaches them.
"""
from lib import along, chord, course, explain, fretboard, fretted, lesson, listen, midi, name, notes, play_chord, progression, quiz, rhythm, strum, tap, unit

G = "guitar"

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
Dsus4 = chord(G, "Dsus4", "xx0233", "xxx134")
Am7 = chord(G, "Am7", "x02010", "xx2x1x")      # A minor, finger 3 lifted
Dm7 = chord(G, "Dm7", "xx0211", "xxx211")      # finger 1 flat across strings 2 and 1
Cmaj7 = chord(G, "Cmaj7", "x32000", "x32xxx")  # C, finger 1 lifted
G7 = chord(G, "G7", "320001", "32xxx1")
Asus4 = chord(G, "Asus4", "x02230", "xx124x")
E5 = chord(G, "E5", "022xxx", "x23xxx")
A5 = chord(G, "A5", "x022xx", "xx23xx")
G5 = chord(G, "G5", "355xxx", "134xxx")
C5 = chord(G, "C5", "x355xx", "x134xx")
D5 = chord(G, "D5", "x577xx", "x134xx")        # C5 slid up two frets
F_BARRE = chord(G, "F", "133211", "134211")
Bm = chord(G, "Bm", "x24432", "x13421")
Fmaj7 = chord(G, "Fmaj7", "xx3210", "xx321x")  # the mini F with string 1 open
Em7 = chord(G, "Em7", "020000", "x2xxxx")      # one finger

# ---------------------------------------------------------------- rhythms (beats inside one bar)
HALVES = [0, 2]
QUARTERS = [0, 1, 2, 3]
SKIP = [0, 1, 1.5, 2, 3, 3.5]            # down, down-up, down, down-up
FOLK = [0, 1, 1.5, 2.5, 3, 3.5]          # down, down-up, up-down-up
OFFBEAT = [0.5, 1.5, 2.5, 3.5]           # reggae: a chop on every and
SHUFFLE = [round(b + o, 3) for b in range(4) for o in (0, 2 / 3)]
LAZY = [0, 2, 2.667]                     # lo-fi: one, then three and a late, swung up
SIX_EIGHT = [0, 2, 3, 5]                 # 6/8 in eighths: counts one, three, four, six
WALTZ = [0, 1, 2]
FUNK = [0, 0.5, 1.5, 2.5, 3]             # one-and, and, and, four
EIGHTHS = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]
PUSH = [0, 1.5, 3]                       # one, the and of two, four
DOOWOP = [0, 1, 2, 3, 3.667]             # every beat, plus a swung pickup into the next bar
SURF = [0, 0.5, 1, 2, 2.5, 3]            # down-up-down, down-up-down: a gallop
DRIVE = [0, 1, 1.5, 2, 2.5, 3, 3.5]      # one, then down-up eighths to the end of the bar
BALLAD = [0, 2, 3, 3.5]                  # big on one, let it ring, build on three and four
HIGHLIFE = [0, 1.5, 2, 3, 3.5]           # one, the and of two, three, four-and
SOUL = [0, 1.5, 2.5, 3.5]                # one, then soft ups on the ands

# ---------------------------------------------------------------- shared text (translated once)
HOOK = "The hook"
VERSE = "The verse"
CHORUS = "The chorus"
FIRST_LINE = "First line"
MAJOR_MINOR = ["Major", "Minor"]
HOME = ["Yes, it feels finished", "No, it wants to go on"]
CLIMB_FALL = ["It climbs", "It falls"]
FIRST_SECOND = ["The first", "The second"]
SET_LIST = "No new chords or notes: the five songs from this unit, each a touch faster. Name each hook by ear, then play."


def shape(spec):
    return {"type": "chord", "chord": spec}


def tones(spec):
    """The notes a chord shape sounds, lowest first, for listen steps."""
    return [fretted(G, 6 - i, f) for i, f in enumerate(spec["frets"]) if f >= 0]


def swing(melody):
    """Long-short eighths: "B3:L D4:S" is a beat split two-thirds, one-third, like the shuffle strum."""
    return melody.replace(":L", ":0.667").replace(":S", ":0.333")


def transpose(melody, semitones):
    """The same melody moved up or down; used for the key change in Rooftop Choir."""
    out = []
    for token in melody.split():
        n, _, length = token.partition(":")
        out.append(token if n.lower() == "r" else f"{name(midi(n) + semitones)}:{length}")
    return " ".join(out)


# ================================================================ 1. Open-chord originals

# Kite Weather: campfire pop in G, 88 bpm. G D Em C, looped.
KITE_VERSE = ("B3:1 B3:0.5 A3:0.5 G3:1 G3:0.5 A3:0.5 A3:1 A3:0.5 G3:0.5 A3:2"
              " B3:1 B3:0.5 A3:0.5 G3:1 B3:0.5 D4:0.5 E4:1 D4:0.5 C4:0.5 G3:2")
KITE_HOOK = ("D4:1.5 B3:0.5 D4:1 E4:1 F#4:1.5 E4:0.5 D4:2"
             " E4:1 D4:0.5 B3:0.5 G3:1 B3:1 C4:1 B3:0.5 A3:0.5 G3:2")
KITE = f"{KITE_VERSE} {KITE_HOOK}"
KITE_CHORDS = [(G_MAJ, 1), (D, 1), (Em, 1), (C, 1)] * 2

# Porchlight: slow ballad in D, 70 bpm.
PORCH_VERSE = "F#4:1.5 E4:0.5 D4:2 C#4:1.5 D4:0.5 E4:2 D4:1.5 B3:0.5 B3:1 D4:1 A3:4"
PORCH_CHORUS = "E4:1 E4:0.5 F#4:0.5 G4:2 G4:1 F#4:0.5 E4:0.5 D4:2 E4:1.5 F#4:0.5 E4:1 C#4:1 D4:4"
PORCH = f"{PORCH_VERSE} {PORCH_CHORUS}"
PORCH_CHORDS = [(D, 1), (A, 1), (G_MAJ, 1), (D, 1), (Em, 1), (G_MAJ, 1), (A, 1), (D, 1)]

# Moth and Ember: stomp-clap indie folk in A minor, 96 bpm. Am C G D, looped.
MOTH_VERSE = "A3:1 A3:0.5 B3:0.5 C4:1 A3:1 G3:1 G3:0.5 A3:0.5 C4:2 B3:1 B3:0.5 C4:0.5 D4:1 B3:1 A3:3 r:1"
MOTH_HOOK = ("A3:0.5 C4:0.5 E4:1 E4:0.5 D4:0.5 C4:1 C4:0.5 E4:0.5 G4:1 G4:0.5 E4:0.5 C4:1"
             " D4:1 D4:0.5 E4:0.5 D4:1 B3:1 A3:4")
MOTH = f"{MOTH_VERSE} {MOTH_HOOK}"
MOTH_CHORDS = [(Am, 1), (C, 1), (G_MAJ, 1), (D, 1)] * 2

# Low Tide Radio: reggae in E minor (Dorian), 80 bpm. Em and A trade bars.
RADIO_VERSE = ("r:1 G3:0.5 A3:0.5 B3:1 B3:1 A3:1 C#4:1 B3:0.5 A3:0.5"
               " r:2 G3:0.5 A3:0.5 B3:1 D4:1 E4:1 C#4:1 B3:2")
RADIO_HOOK = ("r:0.5 E4:0.5 E4:0.5 D4:0.5 E4:1 B3:1 r:0.5 C#4:0.5 C#4:0.5 B3:0.5 C#4:1 A3:1"
              " r:0.5 E4:0.5 E4:0.5 D4:0.5 E4:0.5 F#4:0.5 G4:1 F#4:1 E4:0.5 C#4:0.5 E4:2")
RADIO = f"{RADIO_VERSE} {RADIO_HOOK}"
RADIO_CHORDS = [(Em, 1), (A, 1)] * 4

# Dust on the Dashboard: country boom-chick in A, 100 bpm. Every line starts after a beat of rest.
DUST_1 = "r:1 A3:0.5 B3:0.5 C#4:1 E4:1 E4:0.5 F#4:0.5 E4:0.5 C#4:0.5 A3:2"
DUST_2 = "r:1 D4:0.5 D4:0.5 F#4:1 D4:1 C#4:1 B3:0.5 C#4:0.5 A3:2"
DUST_3 = "r:1 B3:0.5 B3:0.5 E4:1 D4:1 B3:0.5 C#4:0.5 B3:0.5 G#3:0.5 B3:2"
DUST_4 = "r:1 A3:0.5 B3:0.5 C#4:1 E4:1 D4:0.5 C#4:0.5 B3:0.5 G#3:0.5 A3:2"
DUST = f"{DUST_1} {DUST_2} {DUST_3} {DUST_4}"
DUST_CHORDS = [(A, 2), (D, 1), (A, 1), (E, 2), (A, 2)]

UNIT_1 = unit("orig-1", "Open-chord originals", "Five new songs on the open chords you know: campfire pop, a ballad, "
              "stomp-folk, reggae and country.", [
    lesson("orig-kite-weather", "Kite Weather", [
        explain("Campfire pop", "Kite Weather is bright, easy pop: four chords on a loop, G, D, E minor and C, at a relaxed "
                "88 beats per minute. Listen for the hook jumping up to F sharp in its second bar.", rhythm(FOLK)),
        listen("Does the hook climb or fall at first?", [["D4"], ["B3"], ["D4"], ["E4"], ["F#4"]], CLIMB_FALL, 0),
        progression(KITE_CHORDS, FOLK, bpm=76),
        notes(G, ["D4", "B3", "D4", "E4", "F#4", "E4", "D4"],
              hint="D at fret 3 on string 2, open B and back, then open E and F sharp at fret 2 on string 1."),
        along(G, KITE_HOOK, bpm=72, title=HOOK),
        along(G, KITE_VERSE, bpm=76, title=VERSE),
        progression(KITE_CHORDS, FOLK, bpm=88),
        along(G, KITE, bpm=88, title="Kite Weather"),
    ], minutes=6, xp=30, kind="song"),
    lesson("orig-porchlight", "Porchlight", [
        explain("A slow ballad in D", "Porchlight drifts along at 70 beats per minute. A ballad is a slow song that tells a story, "
                "so give every chord room to ring. Listen for the long note that closes each line.", rhythm(HALVES)),
        listen("Does this phrase end at home?", [["E4"], ["F#4"], ["E4"], ["C#4"], ["D4"]], HOME, 0),
        progression(PORCH_CHORDS, HALVES, bpm=66),
        notes(G, ["E4", "E4", "F#4", "G4", "G4", "F#4", "E4", "D4"],
              hint="The chorus climbs string 1: open E, F sharp at fret 2, G at fret 3, then steps back down to D."),
        along(G, PORCH_CHORUS, bpm=63, title=CHORUS),
        progression(PORCH_CHORDS, QUARTERS, bpm=70),
        along(G, PORCH, bpm=70, title="Porchlight"),
    ], minutes=5, xp=30, kind="song"),
    lesson("orig-moth-and-ember", "Moth and Ember", [
        explain("Stomp-clap folk", "Moth and Ember is the kind of song a whole room stomps along to: heavy downstrokes, "
                "a chant of a hook, 96 beats per minute. It starts dark in A minor and brightens on D.", rhythm(SKIP)),
        listen("Listen to the first chord. Major or minor?", [tones(Am)], MAJOR_MINOR, 1),
        progression(MOTH_CHORDS, SKIP, bpm=80),
        notes(G, ["A3", "C4", "E4", "E4", "D4", "C4"],
              hint="Climb A minor: A at fret 2 on string 3, C at fret 1 on string 2, open E. Then step back down."),
        along(G, MOTH_HOOK, bpm=76, title=HOOK),
        quiz("The hook's second bar copies the first, a few notes higher. What is that called?", ["A sequence", "A chord", "A rest"], 0,
             "A sequence repeats a melodic shape from a new starting note. It makes a hook easy to remember."),
        progression(MOTH_CHORDS, SKIP, bpm=96),
        along(G, MOTH, bpm=96, title="Moth and Ember"),
    ], minutes=6, xp=30, kind="song"),
    lesson("orig-low-tide-radio", "Low Tide Radio", [
        explain("Reggae: chop the offbeat", "Low Tide Radio is laid-back reggae at 80 beats per minute. The guitar plays only on "
                "the and of each beat, a short chop called a skank, while bass and drums hold the beat.", rhythm(OFFBEAT)),
        tap(OFFBEAT, bpm=72, bars=2),
        explain("Short and dry", "Strum down on each and, then ease your fretting fingers off the strings so the chord stops. "
                "Chk, chk, chk, chk. The silence between chops is half the groove."),
        strum(Em, OFFBEAT, bpm=72, bars=2),
        progression(RADIO_CHORDS, OFFBEAT, bpm=80),
        notes(G, ["E4", "E4", "D4", "E4", "B3", "C#4", "C#4", "B3", "C#4", "A3"],
              hint="Open E and D at fret 3 on string 2, then C sharp at fret 2 on string 2, open B and A."),
        along(G, RADIO_HOOK, bpm=72, title=HOOK),
        along(G, RADIO, bpm=80, title="Low Tide Radio"),
    ], minutes=6, xp=30, kind="song"),
    lesson("orig-dust-on-the-dashboard", "Dust on the Dashboard", [
        explain("Country boom-chick", "Dust on the Dashboard rolls along at 100 beats per minute. Country players split the bar: "
                "boom, a bass note on beats one and three, then chick, a strum on two and four.", rhythm(QUARTERS)),
        explain("Pick the root, then strum", "On boom, pick only the chord's lowest note, its root: open string 5 for A, "
                "open string 4 for D, open string 6 for E. On chick, brush the thinner strings.", shape(A)),
        quiz("Which string is the boom for a D chord?", ["Open string 6", "Open string 5", "Open string 4"], 2,
             "D's root is open string 4, the same string a D strum starts from."),
        progression(DUST_CHORDS, QUARTERS, bpm=84),
        notes(G, ["A3", "B3", "C#4", "E4", "E4", "F#4", "E4", "C#4", "A3"],
              hint="A at fret 2 on string 3, open B, C sharp at fret 2 on string 2, then open E and F sharp at fret 2."),
        along(G, f"{DUST_1} {DUST_2}", bpm=84, title=FIRST_LINE),
        progression(DUST_CHORDS, QUARTERS, bpm=100),
        along(G, DUST, bpm=100, title="Dust on the Dashboard"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-open-chord-set", "Open-chord set", [
        explain("Five songs, one set", SET_LIST),
        listen("Which song's hook starts like this?", [["D4"], ["B3"], ["D4"], ["E4"], ["F#4"]],
               ["Kite Weather", "Porchlight", "Low Tide Radio"], 0),
        along(G, KITE, bpm=92, title="Kite Weather"),
        progression(PORCH_CHORDS, QUARTERS, bpm=76),
        along(G, MOTH_HOOK, bpm=100, title="Moth and Ember"),
        quiz("In reggae, where does the guitar chop?", ["On every beat", "On the and of each beat", "Only on beat one"], 1,
             "The skank lands between the beats, while bass and drums hold the downbeats."),
        progression(RADIO_CHORDS, OFFBEAT, bpm=84),
        along(G, DUST, bpm=104, title="Dust on the Dashboard"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 2. Sevenths, sus and swing

# Rust Belt Shuffle: 12-bar blues shuffle in E, 80 bpm. The melody rests on bar 12, the turnaround.
RUST_1 = "B3:L D4:S E4:1 E4:L D4:S B3:1 G3:L G#3:S B3:2 r:1 B3:L D4:S E4:1 G4:L E4:S D4:1 E4:3 r:1"
RUST_2 = "C#4:L E4:S G4:1 E4:L D4:S C#4:1 A3:3 r:1 B3:L D4:S E4:1 G4:L E4:S D4:1 E4:3 r:1"
RUST_3 = "F#4:1 F#4:L E4:S D#4:1 B3:1 E4:1 E4:L D4:S C#4:1 A3:1 G#3:L B3:S E4:3"
RUST_HOOK = swing(RUST_1.replace("E4:3 r:1", "E4:4"))
RUST = swing(f"{RUST_1} {RUST_2} {RUST_3}")
TWELVE_BAR = [(E7, 4), (A7, 2), (E7, 2), (B7, 1), (A7, 1), (E7, 1), (B7, 1)]

# Carousel at Closing Time: waltz in D minor, 3/4, 96 bpm.
CAROUSEL_A = "D4:1 A3:1 D4:1 C#4:1 E4:1 G4:1 F4:2 E4:0.5 D4:0.5 E4:1 C#4:1 A3:1"
CAROUSEL_HOOK = f"{CAROUSEL_A} D4:3"
CAROUSEL = f"{CAROUSEL_A} C4:1 A3:1 C4:1 C4:1 E4:1 G4:1 F4:1.5 E4:0.5 C#4:1 D4:3"
CAROUSEL_CHORDS = [(Dm, 1), (A7, 1), (Dm, 1), (A7, 1), (F_MINI, 1), (C, 1), (A7, 1), (Dm, 1)]

# Cedar Smoke: indie folk in G, 6/8 counted in eighths, 100 bpm.
CEDAR_A = "D4:2 B3:1 D4:2 E4:1 E4:2 D4:1 B3:3 C4:2 E4:1 G4:2 E4:1 D4:3 A3:3"
CEDAR_HOOK = f"{CEDAR_A} G3:6"
CEDAR = f"{CEDAR_A} D4:2 B3:1 D4:2 G4:1 G4:2 F#4:1 E4:3 E4:2 D4:1 C4:2 A3:1 F#4:2 E4:1 D4:2 A3:1 G3:6"
CEDAR_CHORDS = [(G_MAJ, 1), (Em, 1), (C, 1), (Dsus4, 1), (G_MAJ, 1), (Em, 1), (C, 1), (D, 1), (G_MAJ, 1)]

# Rain on the Skylight: lo-fi in C, 72 bpm, swung. Am7 Dm7 G Cmaj7, looped.
RAIN_1 = "r:1 E4:L D4:S C4:1 E4:1 D4:L C4:S A3:2 r:1 r:1 D4:L B3:S G3:1 B3:1 B3:L C4:S E4:3"
RAIN_2 = "r:1 E4:L D4:S C4:1 G4:1 F4:L E4:S D4:1 C4:1 A3:1 B3:L D4:S G4:L F4:S D4:1 B3:1 C4:4"
RAIN_HOOK = swing(f"{RAIN_1} C4:4")
RAIN = swing(f"{RAIN_1} {RAIN_2}")
RAIN_CHORDS = [(Am7, 1), (Dm7, 1), (G_MAJ, 1), (Cmaj7, 1)] * 2

# Neon Laundromat: funk vamp on A7, 96 bpm. The hook leaves gaps where the beat falls.
NEON_1 = "A3:0.5 A3:0.5 r:0.5 C4:0.5 r:0.5 C#4:0.5 E4:1"
NEON_2 = "G4:0.5 E4:0.5 r:0.5 D4:0.5 r:0.5 C#4:0.5 A3:1"
NEON_HOOK = f"{NEON_1} {NEON_2}"
NEON = f"{NEON_HOOK} {NEON_1} G4:0.5 E4:0.5 D4:0.5 E4:0.5 r:1 A3:1"

UNIT_2 = unit("orig-2", "Sevenths, sus and swing", "Blues, a waltz, 6/8 folk, lo-fi and funk, with seventh chords, "
              "sus chords and swung rhythms.", [
    lesson("orig-rust-belt-shuffle", "Rust Belt Shuffle", [
        explain("The 12-bar shuffle", "Rust Belt Shuffle is a blues at 80 beats per minute: twelve bars of E7, A7 and B7, "
                "strummed long-short. The melody swings the same way, so lean into every long note.", rhythm(SHUFFLE)),
        listen("Which chord has the seventh?", [tones(E), tones(E7)], FIRST_SECOND, 1),
        progression(TWELVE_BAR, SHUFFLE, bpm=70),
        notes(G, ["B3", "D4", "E4", "E4", "D4", "B3", "G3", "G#3", "B3"],
              hint="Open B, D at fret 3, open E and back. Then G and G sharp on string 3, sliding into open B."),
        along(G, RUST_HOOK, bpm=66, title="First four bars"),
        quiz("Bar two slides from G to G sharp. Which one belongs to E7?", ["G", "G sharp"], 1,
             "E7 is E, G sharp, B and D. G is the blue note: it rubs against the chord, then slides into it."),
        progression(TWELVE_BAR, SHUFFLE, bpm=80),
        along(G, RUST, bpm=80, title="Rust Belt Shuffle"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-carousel-at-closing-time", "Carousel at Closing Time", [
        explain("A waltz in D minor", "Carousel at Closing Time turns in three, like a fairground ride winding down: "
                "oom-pah-pah at 96 beats per minute. Count one, two, three, with the weight on one.",
                rhythm(WALTZ, beats_per_bar=3)),
        listen("Does this end at home?", [tones(A7), tones(Dm)], HOME, 0),
        progression(CAROUSEL_CHORDS, WALTZ, bpm=84, beats_per_bar=3),
        notes(G, ["D4", "A3", "D4", "C#4", "E4", "G4", "F4", "E4", "D4"],
              hint="D at fret 3 on string 2, A on string 3, then C sharp at fret 2, open E and G at fret 3 on string 1."),
        along(G, CAROUSEL_HOOK, bpm=80, beats_per_bar=3, title=HOOK),
        progression(CAROUSEL_CHORDS, WALTZ, bpm=96, beats_per_bar=3),
        along(G, CAROUSEL, bpm=96, beats_per_bar=3, title="Carousel at Closing Time"),
    ], minutes=5, xp=30, kind="song"),
    lesson("orig-cedar-smoke", "Cedar Smoke", [
        explain("Indie folk in 6/8", "Cedar Smoke sways in 6/8: six quick counts per bar, felt as two big beats, "
                "one-two-three, four-five-six. At 100 counts a minute it rocks like a slow boat.",
                rhythm(SIX_EIGHT, beats_per_bar=6)),
        tap(SIX_EIGHT, bpm=90, bars=2, beats_per_bar=6),
        explain("Dsus4, then D", "Bar four holds Dsus4: a D chord with your little finger on string 1, fret 3. "
                "It hangs in the air. Bar eight drops to plain D, and the song lands.", shape(Dsus4)),
        progression(CEDAR_CHORDS, SIX_EIGHT, bpm=90, beats_per_bar=6),
        notes(G, ["D4", "B3", "D4", "E4", "E4", "D4", "B3"],
              hint="D at fret 3 on string 2, open B and back, then open E on string 1, and down again."),
        along(G, CEDAR_HOOK, bpm=84, beats_per_bar=6, title=HOOK),
        progression(CEDAR_CHORDS, SIX_EIGHT, bpm=100, beats_per_bar=6),
        along(G, CEDAR, bpm=100, beats_per_bar=6, title="Cedar Smoke"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-rain-on-the-skylight", "Rain on the Skylight", [
        explain("Lo-fi chill", "Rain on the Skylight is lo-fi: soft seventh chords over a lazy, swung beat at 72 beats per minute. "
                "Strum down on one, then down-up on three, the up a little late.", rhythm(LAZY)),
        explain("Sevenths the easy way", "Am7 is A minor with finger 3 lifted. Cmaj7 is C with finger 1 lifted. For Dm7, "
                "finger 2 goes on string 3, fret 2, and finger 1 lies flat across strings 2 and 1 at fret 1.", shape(Am7)),
        play_chord(Dm7),
        listen("Which chord is Cmaj7?", [tones(C), tones(Cmaj7)], FIRST_SECOND, 1),
        progression(RAIN_CHORDS, LAZY, bpm=66),
        along(G, RAIN_HOOK, bpm=66, title=HOOK),
        progression(RAIN_CHORDS, LAZY, bpm=72),
        along(G, RAIN, bpm=72, title="Rain on the Skylight"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-neon-laundromat", "Neon Laundromat", [
        explain("A funk vamp", "Neon Laundromat stays on one chord, A7, the whole way through. A vamp like this lives on rhythm: "
                "tight, choppy strums at 96 beats per minute and a hook that dodges the beat.", rhythm(FUNK)),
        tap(FUNK, bpm=80, bars=2),
        explain("Land hard on the one", "Funk players call beat one the one. Hit it hard, keep your strumming hand swinging "
                "in eighths, and ease your fingers off after each strum so it goes chk.", shape(A7)),
        strum(A7, FUNK, bpm=80, bars=4),
        notes(G, ["A3", "A3", "C4", "C#4", "E4", "G4", "E4", "D4", "C#4", "A3"],
              hint="A at fret 2 on string 3, C and C sharp at frets 1 and 2 on string 2, open E, G at fret 3, then back down."),
        along(G, NEON_HOOK, bpm=80, title=HOOK),
        strum(A7, FUNK, bpm=96, bars=4),
        along(G, NEON, bpm=96, title="Neon Laundromat"),
    ], minutes=6, xp=30, kind="song"),
    lesson("orig-seventh-chord-set", "Swing and sevenths set", [
        explain("Five songs, one set", SET_LIST),
        listen("Which song's hook starts like this?", [["D4"], ["A3"], ["D4"], ["C#4"], ["E4"], ["G4"]],
               ["Cedar Smoke", "Carousel at Closing Time", "Rain on the Skylight"], 1),
        progression(TWELVE_BAR, SHUFFLE, bpm=84),
        along(G, CAROUSEL, bpm=100, beats_per_bar=3, title="Carousel at Closing Time"),
        quiz("How many quick counts fill a bar of 6/8?", ["Three", "Four", "Six"], 2,
             "6/8 has six eighth-note counts, felt as two groups of three."),
        along(G, CEDAR, bpm=108, beats_per_bar=6, title="Cedar Smoke"),
        progression(RAIN_CHORDS, LAZY, bpm=76),
        strum(A7, FUNK, bpm=100, bars=4),
        along(G, NEON, bpm=100, title="Neon Laundromat"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 3. Riffs, power chords and throwbacks

# Static on Channel Nine: punk in G, 104 bpm. G5 D5 E5 C5, looped; a low verse, then a shouted chorus.
STATIC_VERSE = ("B3:0.5 B3:0.5 B3:0.5 B3:0.5 D4:1 B3:1 A3:0.5 A3:0.5 A3:0.5 A3:0.5 D4:1 A3:1"
                " B3:0.5 B3:0.5 B3:0.5 B3:0.5 E4:1 B3:1 G3:1 A3:1 B3:1 D4:1")
STATIC_CHORUS = "G4:1.5 G4:0.5 G4:1 D4:1 F#4:1.5 F#4:0.5 F#4:1 D4:1 E4:1.5 E4:0.5 E4:1 G4:1 E4:0.5 D4:0.5 B3:1 G3:2"
STATIC = f"{STATIC_VERSE} {STATIC_CHORUS}"
STATIC_CHORDS = [(G5, 1), (D5, 1), (E5, 1), (C5, 1)] * 2

# Basement Weather: garage rock in A, 92 bpm. A riff on the low strings, answered by power chords.
CELLAR_1 = "A2:0.5 A2:0.5 C3:0.5 A2:0.5 D3:1 C3:0.5 A2:0.5"
CELLAR_2 = "G2:0.5 G2:0.5 A2:0.5 G2:0.5 E2:1 r:1"
CELLAR = f"{CELLAR_1} {CELLAR_2} {CELLAR_1} G2:0.5 G2:0.5 A2:0.5 C3:0.5 A2:2"
CELLAR_CHORDS = [(A5, 1), (G5, 1), (C5, 1), (D5, 1)] * 2

# Jukebox Moon: 1950s doo-wop ballad in C, 72 bpm, swung. C Am F G7, twice, then home to C.
JUKEBOX_1 = "G3:L C4:S E4:2 D4:L C4:S C4:2 A3:L C4:S E4:1 F4:L E4:S F4:1 C4:2 D4:L E4:S F4:1 D4:1 B3:1"
JUKEBOX_2 = "G3:L C4:S E4:2 G4:L E4:S E4:2 C4:L D4:S E4:1 F4:L G4:S F4:1 E4:L D4:S C4:1 D4:1 B3:1 G3:1 B3:1 C4:4"
JUKEBOX_HOOK = swing(JUKEBOX_1)
JUKEBOX = swing(f"{JUKEBOX_1} {JUKEBOX_2}")
JUKEBOX_CHORDS = [(C, 1), (Am, 1), (F_MINI, 1), (G7, 1)] * 2 + [(C, 1)]

# Boardwalk Comet: surf rock in A minor, 104 bpm. Am G F E, twice, then home to A minor.
BOARDWALK_1 = ("A3:1 C4:0.5 E4:1 D4:0.5 C4:1 B3:1 D4:0.5 G4:1 E4:0.5 D4:1"
               " A3:1 C4:0.5 F4:1 E4:0.5 C4:1 G#3:1 B3:0.5 E4:2.5")
BOARDWALK_2 = ("E4:0.5 E4:0.5 E4:0.5 E4:0.5 G4:1 E4:1 D4:0.5 D4:0.5 D4:0.5 D4:0.5 G4:1 D4:1"
               " C4:0.5 C4:0.5 C4:0.5 C4:0.5 F4:1 C4:1 E4:1 D4:0.5 C4:0.5 B3:1 G#3:1 A3:4")
BOARDWALK = f"{BOARDWALK_1} {BOARDWALK_2}"
BOARDWALK_CHORDS = [(Am, 1), (G_MAJ, 1), (F_MINI, 1), (E, 1)] * 2 + [(Am, 1)]

# Mile Marker Zero: heartland rock in D, 100 bpm. Sus chords lean forward, then settle.
MILE_VERSE = "A3:1 D4:1 D4:0.5 E4:0.5 F#4:1 G4:1.5 F#4:0.5 E4:1 D4:1 B3:1.5 B3:0.5 D4:1 B3:1 D4:1 D4:1 E4:2"
MILE_CHORUS = "F#4:1 F#4:0.5 G4:0.5 F#4:1 D4:1 G4:1 G4:0.5 F#4:0.5 E4:1 D4:1 D4:1 D4:0.5 E4:0.5 D4:1 B3:1 C#4:1 C#4:0.5 D4:0.5 E4:2 D4:4"
MILE = f"{MILE_VERSE} {MILE_CHORUS}"
MILE_CHORDS = [(D, 1), (Dsus4, 1), (G_MAJ, 1), (Asus4, 1), (D, 1), (Dsus4, 1), (G_MAJ, 1), (A, 1), (D, 1)]

UNIT_3 = unit("orig-3", "Riffs, power chords and throwbacks", "Punk, garage rock, doo-wop, surf and heartland rock, "
              "with power chords, a riff and sus chords.", [
    lesson("orig-static-on-channel-nine", "Static on Channel Nine", [
        explain("Punk drive", "Static on Channel Nine is punk: four power chords, palm-muted eighths, 104 beats per minute. "
                "The verse mutters on low notes; the chorus is a gang shout, so dig in.", rhythm(EIGHTHS)),
        explain("D5: slide C5 up", "You know C5, with finger 1 on string 5, fret 3. Slide the whole shape up two frets and "
                "it becomes D5. G5 sits at fret 3 too, one string lower than C5.", shape(D5)),
        play_chord(D5),
        progression(STATIC_CHORDS, EIGHTHS, bpm=88),
        notes(G, ["G4", "G4", "G4", "D4", "F#4", "F#4", "F#4", "D4"],
              hint="G at fret 3 on string 1, down to D at fret 3 on string 2, then F sharp at fret 2 and D again."),
        along(G, STATIC_CHORUS, bpm=88, title=CHORUS),
        progression(STATIC_CHORDS, EIGHTHS, bpm=104),
        along(G, STATIC, bpm=104, title="Static on Channel Nine"),
    ], minutes=6, xp=30, kind="song"),
    lesson("orig-basement-weather", "Basement Weather", [
        explain("Garage rock", "Basement Weather is garage rock at 92 beats per minute: a riff on the low strings, then "
                "power chords that punch back. Rest your palm at the bridge to keep the riff tight.",
                fretboard(G, [(6, 0), (6, 3, 3), (5, 0), (5, 3, 3), (4, 0)])),
        notes(G, ["A2", "A2", "C3", "A2", "D3", "C3", "A2"],
              hint="Open string 5, C at fret 3 on the same string, then open string 4, and back."),
        along(G, f"{CELLAR_1} {CELLAR_1}", bpm=76, title="First bar, twice"),
        notes(G, ["G2", "G2", "A2", "G2", "E2"], hint="G at fret 3 on string 6, open A, G again, then open low E."),
        along(G, CELLAR, bpm=80, title="The riff"),
        explain("Punch back", "Answer the riff with power chords on one, the and of two, and four: A5, G5, C5, D5. "
                "Between hits, ease your fretting fingers off so the chords stop short.", rhythm(PUSH)),
        progression(CELLAR_CHORDS, PUSH, bpm=92),
        along(G, CELLAR, bpm=92, title="Basement Weather"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-jukebox-moon", "Jukebox Moon", [
        explain("Fifties doo-wop", "Jukebox Moon is a slow dance in 1950s doo-wop style: C, A minor, F and G7, around and around, "
                "at 72 beats per minute. Strum every beat, with a quick swung up into each new bar.", rhythm(DOOWOP)),
        listen("Does this end at home?", [tones(G7), tones(C)], HOME, 0),
        progression(JUKEBOX_CHORDS, DOOWOP, bpm=66),
        notes(G, ["G3", "C4", "E4", "D4", "C4", "C4", "A3", "C4", "E4"],
              hint="Open G, C at fret 1 on string 2, open E, then D and C. Next, A at fret 2 on string 3 and back up."),
        along(G, JUKEBOX_HOOK, bpm=66, title=HOOK),
        progression(JUKEBOX_CHORDS, DOOWOP, bpm=72),
        along(G, JUKEBOX, bpm=72, title="Jukebox Moon"),
    ], minutes=5, xp=30, kind="song"),
    lesson("orig-boardwalk-comet", "Boardwalk Comet", [
        explain("Surf rock", "Boardwalk Comet is surf rock: a twangy melody over A minor, G, F and E, galloping along at "
                "104 beats per minute. Picture reverb, salt spray and a wave about to break.", rhythm(SURF)),
        tap(SURF, bpm=88, bars=2),
        progression(BOARDWALK_CHORDS, SURF, bpm=88),
        notes(G, ["A3", "C4", "E4", "D4", "C4", "B3", "D4", "G4", "E4", "D4"],
              hint="A on string 3, C at fret 1, open E and back down. Then open B, D, and up to G at fret 3."),
        along(G, f"{BOARDWALK_1} A3:4", bpm=84, title=FIRST_LINE),
        quiz("Over the E chord the tune plays G sharp, not G. Where is G sharp on string 3?", ["Open", "Fret 1", "Fret 2"], 1,
             "G is open string 3, so G sharp is one fret up. It leans hard toward A, the home note."),
        progression(BOARDWALK_CHORDS, SURF, bpm=104),
        along(G, BOARDWALK, bpm=104, title="Boardwalk Comet"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-mile-marker-zero", "Mile Marker Zero", [
        explain("Heartland rock", "Mile Marker Zero is open-road rock at 100 beats per minute: big ringing chords and a chorus "
                "for driving with the windows down. Listen for D lifting to Dsus4 and back.", rhythm(DRIVE)),
        listen("Which chord sounds settled?", [tones(Dsus4), tones(D)], FIRST_SECOND, 1),
        explain("Asus4, then A", "Asus4 is A with your little finger added on string 2, fret 3. Like Dsus4, it leans forward "
                "and wants to fall back home.", shape(Asus4)),
        progression(MILE_CHORDS, DRIVE, bpm=84),
        notes(G, ["F#4", "F#4", "G4", "F#4", "D4", "G4", "G4", "F#4", "E4", "D4"],
              hint="F sharp at fret 2 and G at fret 3 on string 1, then down to D at fret 3 on string 2."),
        along(G, MILE_CHORUS, bpm=84, title=CHORUS),
        progression(MILE_CHORDS, DRIVE, bpm=100),
        along(G, MILE, bpm=100, title="Mile Marker Zero"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-throwback-set", "Throwback set", [
        explain("Five songs, one set", SET_LIST),
        listen("Which song's hook starts like this?", [["G4"], ["G4"], ["G4"], ["D4"]],
               ["Static on Channel Nine", "Mile Marker Zero", "Jukebox Moon"], 0),
        along(G, STATIC, bpm=108, title="Static on Channel Nine"),
        progression(CELLAR_CHORDS, PUSH, bpm=96),
        along(G, CELLAR, bpm=96, title="Basement Weather"),
        quiz("Which of these styles swings, long-short?", ["Surf", "Punk", "Doo-wop"], 2,
             "Doo-wop rides a gentle swing. Punk and surf drive on straight, even eighths."),
        along(G, JUKEBOX, bpm=76, title="Jukebox Moon"),
        progression(BOARDWALK_CHORDS, SURF, bpm=108),
        along(G, MILE, bpm=104, title="Mile Marker Zero"),
    ], minutes=6, xp=40, kind="challenge"),
])

# ================================================================ 4. Barres and big finishes

# Late Bus Home: indie pop in D, 100 bpm. D Bm G A, twice, then home to D. Lines start just after the beat.
BUS_A = ("r:0.5 A3:0.5 D4:0.5 E4:0.5 F#4:1 E4:1 D4:1 B3:1 r:0.5 B3:0.5 C#4:0.5 D4:0.5"
            " r:0.5 B3:0.5 D4:0.5 E4:0.5 G4:1 F#4:1 E4:1 C#4:1 A3:2")
BUS_HOOK = f"{BUS_A} D4:4"
BUS = (f"{BUS_A} r:0.5 A3:0.5 D4:0.5 E4:0.5 F#4:0.5 G4:0.5 F#4:1 D4:1 B3:1 r:0.5 F#4:0.5 E4:0.5 D4:0.5"
       " B3:1 D4:1 G4:1 F#4:0.5 E4:0.5 E4:2 C#4:1 A3:1 D4:4")
BUS_CHORDS = [(D, 1), (Bm, 1), (G_MAJ, 1), (A, 1)] * 2 + [(D, 1)]

# Glass Satellites: power ballad in A minor, 76 bpm. Am F C G, twice, then home to A minor.
GLASS_A = "C4:1 E4:1 E4:1.5 D4:0.5 C4:1 A3:1 A3:2 G3:1 C4:1 E4:1.5 F4:0.5 G4:2 D4:1 B3:1"
GLASS_HOOK = f"{GLASS_A} A3:4"
GLASS = f"{GLASS_A} C4:1 E4:1 G4:1.5 E4:0.5 F4:1 E4:1 C4:2 G3:1 C4:1 E4:1 D4:1 D4:1.5 C4:0.5 B3:2 A3:4"
GLASS_CHORDS = [(Am, 1), (F_BARRE, 1), (C, 1), (G_MAJ, 1)] * 2 + [(Am, 1)]

# Market Day: highlife-flavored pop in G, 104 bpm. G Bm C D, twice, then home to G.
MARKET_1 = "D4:0.5 B3:0.5 D4:0.5 E4:1 D4:0.5 B3:1 D4:0.5 B3:0.5 D4:0.5 F#4:1 D4:0.5 B3:1"
MARKET_A = f"{MARKET_1} E4:0.5 C4:0.5 E4:0.5 G4:1 E4:0.5 C4:1 F#4:0.5 E4:0.5 D4:1 A3:2"
MARKET_HOOK = f"{MARKET_A} G3:4"
MARKET = (f"{MARKET_A} {MARKET_1} E4:0.5 C4:0.5 E4:0.5 G4:1 F#4:0.5 E4:1"
          " F#4:0.5 E4:0.5 D4:0.5 C4:0.5 B3:1 A3:1 G3:4")
MARKET_CHORDS = [(G_MAJ, 1), (Bm, 1), (C, 1), (D, 1)] * 2 + [(G_MAJ, 1)]

# Velvet Hour: neo-soul in C, 74 bpm. Four seventh chords stepping down, looped.
VELVET_A = "E4:1.5 F4:0.5 E4:1 C4:1 D4:1.5 E4:0.5 D4:1 B3:1 C4:1.5 D4:0.5 C4:1 A3:1 B3:1 G3:1 B3:0.5 C4:0.5 E4:1"
VELVET_HOOK = f"{VELVET_A} C4:4"
VELVET = f"{VELVET_A} G4:1.5 F4:0.5 E4:1 C4:1 G4:1 E4:1 D4:1 B3:1 F4:1 D4:0.5 C4:0.5 A3:2 G3:0.5 B3:0.5 C4:3"
VELVET_CHORDS = [(Fmaj7, 1), (Em7, 1), (Dm7, 1), (Cmaj7, 1)] * 2

# Rooftop Choir: anthem in C, 92 bpm. The chorus, one bar on A, then the same chorus a whole step up, in D.
ROOF_C = "G3:1 C4:1 E4:1.5 D4:0.5 D4:1 B3:1 G3:2 A3:1 C4:1 F4:1.5 E4:0.5 F4:1 E4:1 C4:2"
ROOF_LIFT = f"A3:1 C#4:1 E4:2 {transpose(ROOF_C, 2)} D4:4"
ROOF = f"{ROOF_C} {ROOF_LIFT}"
ROOF_C_CHORDS = [(C, 1), (G_MAJ, 1), (Am, 1), (F_BARRE, 1)]
ROOF_D_CHORDS = [(A, 1), (D, 1), (A, 1), (Bm, 1), (G_MAJ, 1), (D, 1)]

UNIT_4 = unit("orig-4", "Barres and big finishes", "Indie pop, a power ballad, highlife, neo-soul and an anthem with "
              "a key change, with F and B minor barres.", [
    lesson("orig-late-bus-home", "Late Bus Home", [
        explain("Bedroom pop", "Late Bus Home is indie pop for the ride back through a sleeping city: D, B minor, G and A "
                "at 100 beats per minute. Each line starts just after the beat, so wait a breath.", rhythm(FOLK)),
        explain("B minor, full or easy", "Play the full B minor barre at fret 2 if you can. If not, use the top four strings: "
                "fret 4 on strings 4 and 3, fret 3 on string 2, fret 2 on string 1.", shape(Bm)),
        play_chord(Bm),
        progression(BUS_CHORDS, FOLK, bpm=84),
        notes(G, ["A3", "D4", "E4", "F#4", "E4", "D4", "B3"],
              hint="A at fret 2 on string 3, D at fret 3 on string 2, then open E and F sharp at fret 2 on string 1."),
        along(G, BUS_HOOK, bpm=84, title=HOOK),
        progression(BUS_CHORDS, FOLK, bpm=100),
        along(G, BUS, bpm=100, title="Late Bus Home"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-glass-satellites", "Glass Satellites", [
        explain("The power ballad", "Glass Satellites is a slow, soaring ballad at 76 beats per minute: A minor, F, C and G. "
                "Strum big on one and let it ring, then build on three and four.", rhythm(BALLAD)),
        explain("F, the full barre", "Lay finger 1 flat across all six strings at fret 1 and build an E shape in front of it. "
                "Not there yet? Use the mini F on the top four strings for now.", shape(F_BARRE)),
        play_chord(F_BARRE),
        progression(GLASS_CHORDS, BALLAD, bpm=66),
        notes(G, ["C4", "E4", "E4", "D4", "C4", "A3", "A3"],
              hint="C at fret 1 on string 2, open E twice, D at fret 3, C again, then A at fret 2 on string 3."),
        along(G, GLASS_HOOK, bpm=66, title=CHORUS),
        progression(GLASS_CHORDS, BALLAD, bpm=76),
        along(G, GLASS, bpm=76, title="Glass Satellites"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-market-day", "Market Day", [
        explain("Highlife sunshine", "Market Day borrows from highlife, the bright guitar pop of Ghana and Nigeria: G, B minor, "
                "C and D at 104 beats per minute. The hook bounces off the beat, so keep your body moving.", rhythm(HIGHLIFE)),
        tap(HIGHLIFE, bpm=88, bars=2),
        progression(MARKET_CHORDS, HIGHLIFE, bpm=88),
        notes(G, ["D4", "B3", "D4", "E4", "D4", "B3"], hint="D at fret 3 on string 2, open B, D again, open E, then back to D and B."),
        along(G, MARKET_HOOK, bpm=88, title=HOOK),
        quiz("Bar two keeps bar one's rhythm but swaps one note. Why?", ["To fit the new chord", "To speed up", "To end the song"], 0,
             "Bar two moves E up to F sharp, a note of B minor. Same rhythm, new chord, new note."),
        progression(MARKET_CHORDS, HIGHLIFE, bpm=104),
        along(G, MARKET, bpm=104, title="Market Day"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-velvet-hour", "Velvet Hour", [
        explain("Neo-soul", "Velvet Hour is neo-soul at 74 beats per minute: four lush seventh chords stepping down, Fmaj7, "
                "Em7, Dm7 and Cmaj7. Strum once on one, then brush soft ups on the ands.", rhythm(SOUL)),
        explain("Two new shapes", "Fmaj7 is the mini F with string 1 left open. Em7 takes one finger: finger 2 on string 5, "
                "fret 2, every other string open. Dm7 and Cmaj7 you know from Rain on the Skylight.", shape(Fmaj7)),
        play_chord(Em7),
        progression(VELVET_CHORDS, SOUL, bpm=66),
        quiz("The chords walk down F, E, D. Where does the loop land?", ["On C", "On F", "On G"], 0,
             "Each chord sits one step below the last, and the walk ends on C, the home chord."),
        along(G, VELVET_HOOK, bpm=66, title=HOOK),
        progression(VELVET_CHORDS, SOUL, bpm=74),
        along(G, VELVET, bpm=74, title="Velvet Hour"),
    ], minutes=6, xp=35, kind="song"),
    lesson("orig-rooftop-choir", "Rooftop Choir", [
        explain("An anthem with a key change", "Rooftop Choir is a stadium-sized anthem at 92 beats per minute. You play the "
                "chorus in C, then one bar of A lifts everything a whole step, and the chorus returns in D.", rhythm(EIGHTHS)),
        quiz("A key change up a whole step moves every note up…", ["One fret", "Two frets", "Twelve frets"], 1,
             "A whole step is two half steps, and each fret is a half step. C becomes D, and G becomes A."),
        progression(ROOF_C_CHORDS, EIGHTHS, bpm=80),
        along(G, ROOF_C, bpm=80, title="Chorus in C"),
        progression(ROOF_D_CHORDS, EIGHTHS, bpm=80),
        along(G, ROOF_LIFT, bpm=80, title="The lift to D"),
        progression(ROOF_C_CHORDS + ROOF_D_CHORDS, EIGHTHS, bpm=92),
        along(G, ROOF, bpm=92, title="Rooftop Choir"),
    ], minutes=6, xp=40, kind="song"),
    lesson("orig-encore-set", "Encore set", [
        explain("Five songs, one set", SET_LIST),
        listen("Which song's hook starts like this?", [["E4"], ["F4"], ["E4"], ["C4"], ["D4"], ["E4"], ["D4"], ["B3"]],
               ["Velvet Hour", "Glass Satellites", "Market Day"], 0),
        along(G, BUS, bpm=104, title="Late Bus Home"),
        progression(GLASS_CHORDS, BALLAD, bpm=80),
        along(G, GLASS, bpm=80, title="Glass Satellites"),
        quiz("Which chord lifts Rooftop Choir from C into D?", ["A", "G", "F"], 0,
             "A leads home to D. Landing on it turns the whole song toward the new key."),
        along(G, MARKET, bpm=108, title="Market Day"),
        progression(VELVET_CHORDS, SOUL, bpm=78),
        along(G, ROOF, bpm=96, title="Rooftop Choir"),
    ], minutes=6, xp=40, kind="challenge"),
])

UNITS = [UNIT_1, UNIT_2, UNIT_3, UNIT_4]

COURSE = course("originals", "Originals", "Original songs in today's styles", "guitar.acoustic.6", "sparkles", "sky", UNITS)
