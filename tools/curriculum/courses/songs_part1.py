"""Songs, part 1 (units 1–3): first songs, folk favorites and classical themes I.

Melody only, all public domain or traditional, arranged in first position (frets 0–4).
courses/songs.py joins these UNITS with part 2's.
"""
from lib import along, chord, explain, fretboard, lesson, listen, notes, progression, quiz, rhythm, tap, unit

G = "guitar"

# ---------------------------------------------------------------- chord shapes (lowest string first)
G_MAJ = chord(G, "G", "320003", "21xxx3")
C = chord(G, "C", "x32010", "x32x1x")
D7 = chord(G, "D7", "xx0212", "xxx213")
Dm = chord(G, "Dm", "xx0231", "xxx231")

# ---------------------------------------------------------------- rhythms (beats inside one bar)
QUARTERS = [0, 1, 2, 3]
TWO = [0, 1]                       # a 2/4 bar, one strum per beat

# ---------------------------------------------------------------- shared text (translated once)
FIRST_HALF = "First half"
SECOND_HALF = "Second half"
UP_DOWN = ["Up", "Down"]


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
SAINTS_B = "r:1 E4:1 E4:1 D4:1 C4:3 C4:1 E4:2 G4:1 G4:1 F4:4 r:2 E4:1 F4:1 G4:2 E4:2 C4:2 D4:2 C4:4"
SAINTS = f"{SAINTS_A} {SAINTS_B}"

UNIT_1 = unit("songs-1", "First songs", "Six famous tunes, one note at a time, on the top strings. Slow tempos, big wins.", [
    lesson("song-mary", "Mary Had a Little Lamb", [
        explain("Edison's first recording", "In 1877, Thomas Edison recited this rhyme to test his new phonograph. "
                "The tune uses C and D on string 2, then open E and G on string 1.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 3, 3)])),
        notes(G, ["E4", "D4", "C4", "D4", "E4", "E4", "E4"], hint="E D C D E E E: open string 1, then string 2 at frets 3 and 1, and back."),
        notes(G, ["D4", "D4", "D4", "E4", "G4", "G4"], hint="D D D at fret 3 on string 2. Then open E, and G at fret 3 on string 1."),
        listen("Did the tune go up or down?", [["E4"], ["G4"], ["G4"]], UP_DOWN, 0),
        along(G, MARY_1, bpm=60, title=FIRST_HALF),
        along(G, MARY, bpm=66, title="Mary Had a Little Lamb"),
        along(G, MARY, bpm=80, title="Mary, a little faster"),
    ], minutes=5, xp=30, kind="song"),
    lesson("song-twinkle", "Twinkle, Twinkle, Little Star", [
        explain("A French folk tune", "This melody was first printed in France in 1761, and Mozart later wrote twelve variations on it. "
                "It leaps up, then steps down across strings 2 and 3.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
        notes(G, ["G3", "G3", "D4", "D4", "E4", "E4", "D4"], hint="Open G, a leap up to D at fret 3 on string 2, open E, and back to D."),
        notes(G, ["C4", "C4", "B3", "B3", "A3", "A3", "G3"], hint="Step down in pairs: C at fret 1, open B, A at fret 2 on string 3, open G."),
        quiz("Which other song uses this same tune?", ["Jingle Bells", "The alphabet song", "Yankee Doodle"], 1,
             "The alphabet song and Baa, Baa, Black Sheep both borrow this French melody."),
        along(G, TWINKLE_A, bpm=60, title="Opening phrase"),
        along(G, TWINKLE, bpm=66, title="Twinkle, Twinkle, Little Star"),
        along(G, TWINKLE, bpm=80, title="Twinkle, a little faster"),
    ], minutes=5, xp=30, kind="song"),
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
        along(G, ODE, bpm=72, title="Ode to Joy"),
    ], minutes=6, xp=35, kind="song"),
    lesson("song-frere-jacques", "Frère Jacques", [
        explain("A tune that chases itself", "Frère Jacques is a French round, first printed around 1780: a second player starts "
                "the same tune two bars later, and the parts fit together.",
                fretboard(G, [(4, 0), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3), (1, 0)])),
        quiz("In a round, the second player…", ["Plays a different tune", "Starts the same tune later", "Plays the tune backward"], 1,
             "Everyone plays the same melody, each starting a little later. The phrases are built to fit on top of each other."),
        notes(G, ["D4", "E4", "D4", "C4", "B3", "G3"], hint="The quick part: D E D C on strings 2 and 1, then B and G."),
        along(G, FRERE_3, bpm=60, title="The quick part"),
        notes(G, ["G3", "D3", "G3"], hint="The ending dips from open G to open D on string 4, then comes back."),
        along(G, FRERE, bpm=66, title="Frère Jacques"),
        along(G, FRERE, bpm=80, title="Frère Jacques, a little faster"),
    ], minutes=5, xp=30, kind="song"),
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
        along(G, JINGLE, bpm=66, title="Jingle Bells"),
        along(G, JINGLE, bpm=80, title="Jingle Bells, a little faster"),
    ], minutes=6, xp=35, kind="song"),
    lesson("song-saints", "When the Saints Go Marching In", [
        explain("A New Orleans favorite", "This traditional spiritual became a jazz standard after Louis Armstrong recorded it in 1938. "
                "It uses C, D, E, F and G on strings 2 and 1.",
                fretboard(G, [(2, 1, 1), (2, 3, 3), (1, 0), (1, 1, 1), (1, 3, 3)])),
        notes(G, ["C4", "E4", "F4", "G4"], hint="The opening: C on string 2, then E, F and G climbing string 1."),
        explain("Start after a rest", "A pickup is a few notes that lead into a strong beat. Here beat one is silent, "
                "and C, E and F lead into a long G.", rhythm([1, 2, 3])),
        tap([1, 2, 3], bpm=72, bars=2),
        along(G, SAINTS_A, bpm=66, title=FIRST_HALF),
        notes(G, ["E4", "E4", "D4", "C4", "C4", "E4", "G4", "G4", "F4"], hint="The middle: E E D C, then C E G G F."),
        along(G, SAINTS_B, bpm=66, title=SECOND_HALF),
        along(G, SAINTS, bpm=76, title="When the Saints Go Marching In"),
    ], minutes=6, xp=35, kind="song"),
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
CAMP_1 = "D4:1 D4:1 B3:1 D4:1 E4:1 D4:1 B3:2 B3:1 A3:3 B3:1 A3:3"
CAMP_2 = "D4:1 D4:1 B3:1 D4:1 E4:1 D4:1 B3:2 A3:1 A3:1 B3:1 A3:1 G3:4"
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
SAILOR_C = ("A3:2 A3:2 A3:1 D3:1 F3:1 A3:1 G3:2 G3:2 G3:1 C3:1 E3:1 G3:1"
            " A3:2 A3:2 A3:1 B3:1 C4:1 D4:1 C4:1 A3:1 G3:1 E3:1 D3:2 D3:2")
SAILOR = f"{SAILOR_V} {SAILOR_C}"
SAILOR_CHORDS = [(Dm, 2), (C, 2), (Dm, 2), (C, 1), (Dm, 1)]

UNIT_2 = unit("songs-2", "Folk favorites", "Campfire songs and a sea shanty, with easy chords to strum on the simplest ones.", [
    lesson("song-oh-susanna", "Oh! Susanna", [
        explain("A Gold Rush anthem", "Stephen Foster published this song in 1848, and gold seekers heading to California "
                "made it their anthem. The verse sits on strings 3, 2 and 1.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
        notes(G, ["B3", "D4", "D4", "E4", "D4", "B3", "G3", "A3"], hint="Open B, D at fret 3, open E, then back down to open G and A."),
        along(G, SUSANNA_1.replace("A3:2", "A3:4"), bpm=60, title=FIRST_HALF),
        notes(G, ["B3", "B3", "A3", "A3", "G3"], hint="The last bar: B B A A, then home to open G."),
        along(G, SUSANNA, bpm=66, title="Oh! Susanna"),
        explain("Two chords: G and D7", "G sounds like home, and D7 pulls back toward it. The verse is three bars of G, "
                "one of D7, two of G, then D7 and G.", shape(D7)),
        progression(SUSANNA_CHORDS, QUARTERS, bpm=66),
    ], minutes=5, xp=30, kind="song"),
    lesson("song-camptown-races", "Camptown Races", [
        explain("Same chords, new race", "Stephen Foster wrote this racing song in 1850, two years after Oh! Susanna. "
                "It uses the same notes and the same two chords.",
                fretboard(G, [(3, 0), (3, 2, 2), (2, 0), (2, 3, 3), (1, 0)])),
        notes(G, ["D4", "D4", "B3", "D4", "E4", "D4", "B3"], hint="D D B D, up to open E, then D and B. Strings 2 and 1."),
        explain("Short, then long", "Twice in the first line, a quick B leads into an A that rings for three beats. "
                "Pick the A once and let it ring.", rhythm([0, 1])),
        tap([0, 1], bpm=66, bars=2),
        along(G, CAMP_1, bpm=60, title="First line"),
        along(G, CAMP, bpm=66, title="Camptown Races"),
        progression(SUSANNA_CHORDS, QUARTERS, bpm=72),
    ], minutes=5, xp=30, kind="song"),
    lesson("song-old-macdonald", "Old MacDonald Had a Farm", [
        explain("Down to string 4", "This farmyard song was first printed in 1917, but people sang versions of it long before. "
                "Its tune reaches down to D and E on string 4.",
                fretboard(G, [(4, 0), (4, 2, 2), (3, 0), (3, 2, 2), (2, 0)])),
        notes(G, ["G3", "G3", "G3", "D3", "E3", "E3", "D3"], hint="Open G three times, down to open D, E at fret 2 on string 4, back to D."),
        notes(G, ["B3", "B3", "A3", "A3", "G3"], hint="Then up: open B twice, A at fret 2 on string 3, and home to open G."),
        along(G, OLD_1, bpm=63, title="First line"),
        along(G, OLD, bpm=72, title="Old MacDonald Had a Farm"),
        explain("Count in twos", "Here each chord lasts two beats, so the strum counts one, two. "
                "The order is G, G, C, G, then G, D7, G, G. Change early.", shape(C)),
        progression(OLD_LINE + OLD_LINE, TWO, bpm=66, beats_per_bar=2),
    ], minutes=5, xp=30, kind="song"),
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
        along(G, YANKEE, bpm=88, title="Yankee Doodle, up to speed"),
    ], minutes=5, xp=30, kind="song"),
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
        along(G, AURA, bpm=66, title="Aura Lee"),
    ], minutes=6, xp=35, kind="song"),
    lesson("song-drunken-sailor", "Drunken Sailor", [
        explain("Pull together", "Sailors sang shanties like this one so a whole crew could haul a rope on the same beat. "
                "This one is in a minor key, which sounds darker.",
                fretboard(G, [(5, 3, 3), (4, 0), (4, 2, 2), (4, 3, 3), (3, 0), (3, 2, 2), (2, 0), (2, 1, 1), (2, 3, 3)])),
        notes(G, ["A3", "D3", "F3", "A3", "G3", "C3", "E3", "G3"],
              hint="A, down to open D, F and A. Then G, down to C on string 5, E and G."),
        explain("Long, short-short", "The verse opens on one repeated note: long, short-short, long, short-short. "
                "Tap it before you play it.", rhythm([0, 1, 1.5, 2, 3, 3.5])),
        tap([0, 1, 1.5, 2, 3, 3.5], bpm=66, bars=2),
        notes(G, ["A3", "B3", "C4", "D4", "C4", "A3", "G3", "E3", "D3"], hint="Climb A B C D, then fall C A G E down to open D."),
        along(G, SAILOR_V, bpm=60, title="Verse"),
        along(G, SAILOR, bpm=72, title="Drunken Sailor"),
        explain("D minor and C", "Two chords carry the whole shanty. They trade places every two bars, then every bar at the end. "
                "Strum D minor from string 4.", shape(Dm)),
        progression(SAILOR_CHORDS, QUARTERS, bpm=66),
    ], minutes=6, xp=35, kind="song"),
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
        along(G, CANON, bpm=66, title="Canon in D"),
    ], minutes=6, xp=35, kind="song"),
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
        along(G, LARGO, bpm=66, title="Largo"),
    ], minutes=5, xp=30, kind="song"),
    lesson("song-brahms-lullaby", "Brahms' Lullaby", [
        explain("A gift for a baby", "Johannes Brahms wrote this lullaby in 1868 for a friend's newborn son. "
                "It sways in three, like a cradle: a long note, then two quick ones.", rhythm([0, 2, 2.5], beats_per_bar=3)),
        tap([0, 2, 2.5], bpm=66, bars=2, beats_per_bar=3),
        notes(G, ["B3", "B3", "D4", "B3", "B3", "D4"], hint="The opening rocks between open B and D at fret 3 on string 2."),
        along(G, BRAHMS_1.replace("G4:2", "G4:3"), bpm=66, beats_per_bar=3, title=FIRST_HALF),
        notes(G, ["G3", "G3", "G4"], hint="Open G on string 3, then the same note an octave higher: G at fret 3 on string 1."),
        along(G, f"r:2 {BRAHMS_2}", bpm=66, beats_per_bar=3, title=SECOND_HALF),
        along(G, BRAHMS, bpm=72, beats_per_bar=3, title="Brahms' Lullaby"),
    ], minutes=6, xp=35, kind="song"),
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
        along(G, MINUET, bpm=72, beats_per_bar=3, title="Minuet in G"),
    ], minutes=6, xp=35, kind="song"),
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
        along(G, f"{KING} {KING}", bpm=92, title="Faster, like Grieg"),
    ], minutes=6, xp=35, kind="song"),
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
        along(G, ELISE, bpm=80, beats_per_bar=3, title="Für Elise, flowing"),
    ], minutes=6, xp=35, kind="song"),
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
