"""Rhythm: from a steady beat to syncopation, triplets, swing and other meters. Any instrument; you tap the screen."""
from lib import course, explain, lesson, listen, quiz, rhythm, tap, unit

# Listening steps sound one click per group, all on one pitch. A strong click (an accent) is the
# same click doubled an octave up, so it sounds fuller without changing the note.
CLICK = ["C5"]
STRONG = ["C5", "C6"]


def clicks(count, strong=()):
    """`count` even clicks; the ones at `strong` (0-based) are accented."""
    return [STRONG if i in strong else CLICK for i in range(count)]


def trip(beat):
    """A triplet on `beat`: three even notes in one beat."""
    return [beat, beat + 1 / 3, beat + 2 / 3]


Q = [0, 1, 2, 3]                                   # quarter notes
E8 = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]              # eighth notes
TRIPLETS = trip(0) + trip(1) + trip(2) + trip(3)
SWING = [b + x for b in range(4) for x in (0, 2 / 3)]  # long-short eighths
RIDE = [0, 1, 1 + 2 / 3, 2, 3, 3 + 2 / 3]          # the jazz ride pattern
TWO_THREE = [0, 0.5, 1] + trip(1)[1:] + [2, 2.5, 3] + trip(3)[1:]  # eighths, then triplets, twice

UNIT_1 = unit("rhy-1", "The beat", "Find the pulse, count to four, and tap in time.", [
    lesson("rhy-1-1", "Find the pulse", [
        explain("The beat is a steady pulse", "The beat is the steady pulse you tap your foot to. It never rushes or drags, like footsteps on an easy walk. Every rhythm sits on top of it.",
                rhythm(Q)),
        explain("Tap with the click", "Hold your fingertip just above the screen and tap each time the click sounds. Let it bounce off the glass like a drumstick. Aim to land with the click, not after it."),
        tap(Q, bpm=60, bars=2),
        quiz("How does a beat feel?", ["Steady and even", "Fast, then slow", "Loud, then quiet"], 0,
             "A beat keeps the same space between pulses, like a clock ticking."),
        listen("How many clicks did you hear?", clicks(4), ["Three", "Four", "Five"], 1),
        tap(Q, bpm=66, bars=2),
    ], minutes=3, xp=15),
    lesson("rhy-1-2", "Count to four", [
        explain("Count out loud: 1, 2, 3, 4", "Most music groups beats in fours. Count 1, 2, 3, 4 out loud with the click, then start again at 1. Saying the numbers helps your hands keep time.",
                rhythm(Q)),
        tap(Q, bpm=60, bars=2),
        explain("Bars and beat 1", "A bar is one group of beats. Here each bar holds four beats, written 4/4. Beat 1 starts every bar, so lean on it a little as you count.",
                rhythm(Q)),
        listen("The strong click is beat 1. How many beats are in each bar?", clicks(8, (0, 4)), ["Three", "Four", "Six"], 1),
        quiz("Which beat starts every bar?", ["Beat 4", "Beat 1", "Beat 2"], 1,
             "Counting starts again at 1 at the top of every bar."),
        tap(Q, bpm=70, bars=4),
    ], minutes=4, xp=20),
    lesson("rhy-1-3", "Quarter notes and longer", [
        explain("Quarter notes", "A note that lasts one beat is a quarter note. Four of them fill a bar of 4/4, so tapping on every beat means tapping quarter notes.",
                rhythm(Q)),
        tap(Q, bpm=66, bars=2),
        explain("Count more than you tap", "Now tap only on 1 and 3. Each tap is a half note, two beats long. Keep counting all four; the beats you skip still happen.",
                rhythm([0, 2])),
        tap([0, 2], bpm=66, bars=2),
        quiz("You tap on 1 and 3. What happens on 2 and 4?", ["You keep counting", "The music stops", "You tap twice as fast"], 0,
             "The beat never stops. You count through the beats you don't tap."),
        explain("A whole note: just beat 1", "A whole note lasts all four beats. Tap once on 1 and count 2, 3, 4 under your breath so the next 1 lands on time.",
                rhythm([0])),
        tap([0], bpm=66, bars=4),
        tap(Q, bpm=75, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-1-4", "Tempo", [
        explain("Tempo is the speed of the beat", "Tempo is how fast the beat goes, counted in beats per minute, or bpm. At 60 bpm the beat comes once a second, like a clock.",
                rhythm(Q)),
        tap(Q, bpm=60, bars=2),
        quiz("At 60 bpm, how often does the beat come?", ["Twice a second", "Once a second", "Once every two seconds"], 1,
             "60 beats in 60 seconds is one beat each second."),
        tap(Q, bpm=75, bars=2),
        explain("Smaller as it speeds up", "Faster tempos need less effort, not more. Keep your hand loose and tap from the knuckle, not the wrist or shoulder.",
                rhythm(Q)),
        tap([0, 2], bpm=80, bars=2),
        quiz("The tempo goes up. What should your taps do?", ["Get bigger and harder", "Wait a little behind the click", "Stay small and light"], 2,
             "Small, relaxed motions are quicker and easier to keep even."),
        tap(Q, bpm=90, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-1-5", "Steady hands", [
        explain("Put it together", "This challenge mixes beats, bars, longer notes and tempo. Count out loud the whole way, and keep your taps small and relaxed."),
        tap(Q, bpm=70, bars=2),
        listen("The strong click is beat 1. How many beats are in each bar?", clicks(12, (0, 4, 8)), ["Two", "Three", "Four"], 2),
        tap([0, 2], bpm=75, bars=2),
        quiz("Which note lasts a whole bar of 4/4?", ["A half note", "A whole note", "A quarter note"], 1,
             "A whole note lasts four beats, the full bar of 4/4."),
        tap([0], bpm=75, bars=4),
        quiz("What does 90 bpm mean?", ["90 beats every minute", "90 bars every minute", "90 taps in each bar"], 0,
             "bpm counts beats per minute, so 90 bpm is a little faster than one beat a second."),
        tap(Q, bpm=90, bars=4),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_2 = unit("rhy-2", "Eighth notes", 'Split each beat in two and count "and."', [
    lesson("rhy-2-1", "Two taps per beat", [
        explain("Split the beat in two", "An eighth note lasts half a beat, so two fit in every beat. Eight of them fill a bar of 4/4.",
                rhythm(E8)),
        explain("Count 1 and 2 and", 'Say the number on each beat and "and" exactly halfway between: 1 and 2 and 3 and 4 and. Tap on every word.',
                rhythm(E8)),
        tap(E8, bpm=60, bars=2),
        quiz("How many eighth notes fit in one beat?", ["One", "Two", "Four"], 1,
             "An eighth note is half a beat, so two fill each beat."),
        listen("The strong clicks are the beats. How many beats did you hear?", clicks(8, (0, 2, 4, 6)), ["Four", "Eight", "Two"], 0),
        tap(E8, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-2-2", "Quarters and eighths", [
        explain("Mix long and short", "Now some beats get one tap and some get two. Keep saying every \"and,\" even the ones you don't tap.",
                rhythm([0, 1, 1.5, 2, 3])),
        tap([0, 1, 1.5, 2, 3], bpm=60, bars=2),
        quiz("How do you count this pattern?", ["1, 2 and, 3, 4", "1 and 2, 3, 4", "1, 2, 3 and 4"], 1,
             "Beat 1 has two taps, 1 and. Beats 2, 3 and 4 get one tap each.", visual=rhythm([0, 0.5, 1, 2, 3])),
        tap([0, 0.5, 1, 2, 3], bpm=60, bars=2),
        listen("The strong clicks are the beats. How many beats did you hear?", clicks(6, (0, 2, 4)), ["Six", "Three", "Two"], 1),
        tap([0, 1, 1.5, 2, 3, 3.5], bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-2-3", "Read the counts", [
        explain("Every tap has a name", 'In eighths, each tap lands on a number or an "and." Before you tap a new pattern, say its counts once out loud.',
                rhythm([0, 0.5, 1, 2, 2.5, 3])),
        quiz("Which counts match this pattern?", ["1, 2 and, 3 and 4", "1 and 2, 3 and 4", "1 and 2 and 3 and 4"], 1,
             "Beats 1 and 3 have two taps each; beats 2 and 4 have one.", visual=rhythm([0, 0.5, 1, 2, 2.5, 3])),
        tap([0, 0.5, 1, 2, 2.5, 3], bpm=63, bars=2),
        quiz("Which counts match this pattern?", ["1, 2 and 3 and 4", "1 and 2, 3, 4 and", "1, 2, 3 and 4 and"], 0,
             "Beat 1 has one tap, beats 2 and 3 have two, and beat 4 has one.", visual=rhythm([0, 1, 1.5, 2, 2.5, 3])),
        tap([0, 1, 1.5, 2, 2.5, 3], bpm=66, bars=2),
        tap([0, 0.5, 1, 1.5, 2, 3], bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-2-4", "Even eighths", [
        explain("Make both halves equal", 'The "and" should land exactly halfway between beats. If your eighths sound like a gallop, slow down and say the counts as you tap.',
                rhythm(E8)),
        tap(E8, bpm=70, bars=2),
        quiz("Your eighths sound uneven. What helps most?", ["Tap harder on each beat", "Slow down and count out loud", "Speed up until it smooths out"], 1,
             'Slowing down gives you time to place each "and" in the middle. Counting keeps it there.'),
        tap(E8, bpm=80, bars=2),
        explain("Keep your fingertip close", "Hover just above the glass between taps. A short, light motion is easier to keep even at faster tempos.",
                rhythm(E8)),
        tap([0, 0.5, 1, 1.5, 2, 2.5, 3], bpm=85, bars=2),
        tap(E8, bpm=90, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-2-5", "Eighth-note check", [
        explain("Put it together", 'This challenge mixes quarters and eighths. Say each pattern\'s counts once, then tap it with every "and" right in the middle.'),
        tap([0, 1, 1.5, 2, 3], bpm=70, bars=2),
        quiz("Which counts match this pattern?", ["1 and 2 and 3, 4", "1, 2, 3 and 4 and", "1 and 2, 3 and 4"], 2,
             "Beats 1 and 3 have two taps each; beats 2 and 4 have one.", visual=rhythm([0, 0.5, 1, 2, 2.5, 3])),
        tap([0, 0.5, 1, 2, 2.5, 3], bpm=75, bars=2),
        listen("The strong clicks are the beats. How many beats did you hear?", clicks(8, (0, 2, 4, 6)), ["Eight", "Two", "Four"], 2),
        tap([0, 1, 1.5, 2, 2.5, 3, 3.5], bpm=80, bars=2),
        tap(E8, bpm=90, bars=4),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_3 = unit("rhy-3", "Rests and syncopation", "Leave space on purpose, then tap between the beats.", [
    lesson("rhy-3-1", "Rests are counted", [
        explain("A rest is counted silence", "A rest is a silence with a set length. You still count it; you just don't tap. A quarter rest lasts one beat.",
                rhythm([0, 1, 3])),
        tap([0, 1, 3], bpm=60, bars=2),
        quiz("What do you do on a rest?", ["Skip to the next note", "Count it silently", "Tap softly"], 1,
             "A rest takes up time just like a note. Counting it keeps your place."),
        tap([0, 2, 3], bpm=63, bars=2),
        explain("Rest on beat 1", "Leaving beat 1 empty is the hardest rest. Nod your head on 1 so you feel it without tapping, then come in on 2.",
                rhythm([1, 2, 3])),
        tap([1, 2, 3], bpm=63, bars=2),
        tap([0, 1, 2], bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-3-2", "Tap the and", [
        explain("Rest, then tap the and", 'An eighth rest lasts half a beat. Count 1 and 2 and, rest on 2, and tap its "and" instead. It feels like a small push into beat 3.',
                rhythm([0, 1.5, 2, 3])),
        tap([0, 1.5, 2, 3], bpm=60, bars=2),
        quiz("Where is the second tap?", ["On beat 2", 'On the "and" of 2', "On beat 3"], 1,
             'It sits halfway between beats 2 and 3, on the "and" of 2.', visual=rhythm([0, 1.5, 2, 3])),
        tap([0, 1, 2.5, 3], bpm=63, bars=2),
        tap([0, 1.5, 2, 3.5], bpm=66, bars=2),
        tap([0, 1.5, 2, 3], bpm=72, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-3-3", "Syncopation", [
        explain("Syncopation: off the beat", "Syncopation puts a strong note between the beats, where your ear doesn't expect one. It makes a rhythm lean forward.",
                rhythm([0, 1.5, 3])),
        explain("Count every eighth", 'This pattern lands on 1, the "and" of 2, and 4. Count 1 and 2 and 3 and 4 and, and tap only those three spots.',
                rhythm([0, 1.5, 3])),
        tap([0, 1.5, 3], bpm=60, bars=2),
        listen("Count the clicks from 1 to 8. Where do the strong ones fall?", clicks(8, (0, 3, 6)), ["1, 3, 5 and 7", "1, 4 and 7", "1 and 5"], 1),
        tap([0, 1.5, 3], bpm=70, bars=4),
        quiz("What makes a rhythm syncopated?", ["A faster tempo", "Notes only on beat 1", "Strong notes between the beats"], 2,
             'Syncopation shifts the weight off the beat, onto an "and" or a weak beat.'),
        tap([0, 1.5, 2, 3], bpm=70, bars=2),
    ], minutes=5, xp=25),
    lesson("rhy-3-4", "Offbeats", [
        explain("Tap only the ands", 'Offbeats are the "and" between beats. Nod on the numbers and tap only the ands, like the chop of a reggae guitar.',
                rhythm([0.5, 1.5, 2.5, 3.5])),
        tap([0.5, 1.5, 2.5, 3.5], bpm=60, bars=4),
        listen("The first click is beat 1. Are the strong clicks on the numbers or the ands?", clicks(8, (1, 3, 5, 7)),
               ["On the numbers", "On the ands"], 1),
        quiz("Where do offbeats land?", ["On beats 1 and 3", 'Between the beats, on the "and"', "On every beat"], 1,
             'Offbeats fall halfway between the beats, on every "and."'),
        tap([0.5, 1.5, 2.5, 3.5], bpm=70, bars=4),
        tap([0, 1.5, 3], bpm=72, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-3-5", "Space and push", [
        explain("Put it together", 'This challenge mixes rests, the "and" on its own, syncopation and offbeats. Count every eighth out loud, even when you don\'t tap.'),
        tap([0, 1, 3], bpm=70, bars=2),
        tap([1, 2, 3], bpm=70, bars=2),
        quiz("Which of these is syncopated?", ["1, 2, 3, 4", '1, the "and" of 2, 4', "1 and 2 and 3 and 4 and"], 1,
             'Tapping the "and" of 2 and skipping 3 moves the weight off the beat.'),
        tap([0, 1.5, 3], bpm=75, bars=2),
        listen("Count the clicks from 1 to 8. Where do the strong ones fall?", clicks(8, (0, 2, 5)), ["1, 3 and 6", "1, 4 and 7", "1, 3, 5 and 7"], 0),
        tap([0.5, 1.5, 2.5, 3.5], bpm=75, bars=2),
        tap([0, 1.5, 2, 3.5], bpm=80, bars=4),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_4 = unit("rhy-4", "Ties and dots", "Hold notes across the beat with ties and dotted rhythms.", [
    lesson("rhy-4-1", "Ties", [
        explain("A tie joins two notes", "A tie is a curved line joining two notes. You play the first and hold it through the second, so the tied note gets no new tap.",
                rhythm([0, 1, 3])),
        tap([0, 1, 3], bpm=60, bars=2),
        quiz("Beat 2 is tied to beat 3. What do you do on 3?", ["Tap again", "Keep holding, no new tap", "Stop the sound and wait"], 1,
             "A tie stretches one note. You count 3, but the note from beat 2 keeps sounding."),
        explain("Tie across the beat", 'Tie the "and" of 2 into beat 3. Tap on the "and," then let beat 3 pass while the note rings. It\'s syncopation, written another way.',
                rhythm([0, 1, 1.5, 3])),
        tap([0, 1, 1.5, 3], bpm=60, bars=2),
        tap([0, 1, 1.5, 3], bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-4-2", "What a dot does", [
        explain("A dot adds half", "A dot after a note adds half its length. A half note lasts two beats, so a dotted half lasts three. Tap 1, count 2 and 3, tap 4.",
                rhythm([0, 3])),
        tap([0, 3], bpm=60, bars=2),
        quiz("A quarter note lasts one beat. How long is a dotted quarter?", ["Two beats", "Half a beat", "One and a half beats"], 2,
             "Half of one beat is a half beat. Add it and you get one and a half."),
        explain("The dotted quarter", 'A dotted quarter lasts one and a half beats, so the next note lands on an "and." Count 1 and 2 and: tap 1, then the "and" of 2.',
                rhythm([0, 1.5, 2, 3])),
        tap([0, 1.5, 2, 3], bpm=60, bars=2),
        quiz("You tapped this pattern with a rest in Unit 3. What changes with a dot?", ["The first note rings longer", "The taps move", "The tempo slows"], 0,
             "The taps land in the same places. Only the length of the first note changes.", visual=rhythm([0, 1.5, 2, 3])),
        tap([0, 1.5, 2, 3], bpm=70, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-4-3", "Long, short", [
        explain("Dotted quarter, then eighth", 'A dotted quarter plus an eighth fills two beats: long, short. Count 1 and 2 and; tap 1 and the "and" of 2.',
                rhythm([0, 1.5, 2, 3.5])),
        tap([0, 1.5, 2, 3.5], bpm=60, bars=2),
        quiz("A dotted quarter and an eighth together last how long?", ["One and a half beats", "Two beats", "Three beats"], 1,
             "One and a half plus a half is two."),
        tap([0, 1.5, 2, 3.5], bpm=70, bars=2),
        quiz("Which lasts as long as a dotted quarter?", ["A quarter tied to an eighth", "Two eighth notes", "A half note"], 0,
             "The tie adds half a beat to the quarter, just like the dot does."),
        tap([0, 1.5, 2, 3], bpm=75, bars=2),
        tap([0, 1.5, 2, 3.5], bpm=80, bars=4),
    ], minutes=4, xp=20),
    lesson("rhy-4-4", "Held notes", [
        explain("Put it together", "This challenge mixes ties and dots. Count every eighth out loud; a held note still takes up its full time."),
        tap([0, 1, 3], bpm=70, bars=2),
        quiz("How long is a dotted half note?", ["Two beats", "Three beats", "Four beats"], 1,
             "A half note is two beats; the dot adds one more."),
        tap([0, 1, 1.5, 3], bpm=70, bars=2),
        tap([0, 3], bpm=75, bars=2),
        quiz("A tie connects two notes. How many times do you tap?", ["Once", "Twice", "Three times"], 0,
             "You tap the first note and hold through the second."),
        tap([0, 1.5, 2, 3], bpm=80, bars=2),
        tap([0, 1.5, 2, 3.5], bpm=85, bars=4),
    ], minutes=5, xp=30, kind="challenge"),
])

UNIT_5 = unit("rhy-5", "Triplets and swing", "Split the beat in three, then swing your eighths.", [
    lesson("rhy-5-1", "Three to a beat", [
        explain("Triplets split the beat in three", "A triplet fits three even notes into one beat. Count 1-trip-let, 2-trip-let, with each syllable the same length.",
                rhythm(TRIPLETS)),
        tap(trip(0) + [1, 2, 3], bpm=60, bars=2),
        quiz("How many triplet notes fit in one beat?", ["Two", "Three", "Four"], 1,
             "Triplets split each beat into three equal parts."),
        tap(trip(0) + [1] + trip(2) + [3], bpm=60, bars=2),
        listen("Are the clicks in groups of two or three?", clicks(12, (0, 3, 6, 9)), ["Groups of two", "Groups of three"], 1),
        tap(TRIPLETS, bpm=60, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-5-2", "Twos and threes", [
        explain("Switch between two and three", "Eighths split the beat in two; triplets split it in three. The beat itself stays put. Only the way you divide it changes.",
                rhythm(TWO_THREE)),
        tap([0, 0.5] + trip(1) + [2, 3], bpm=60, bars=2),
        listen("Are the clicks in groups of two or three?", clicks(8, (0, 2, 4, 6)), ["Groups of two", "Groups of three"], 0),
        quiz("You count 1-trip-let, 2-trip-let. What are you tapping?", ["Eighth notes", "Quarter notes", "Triplets"], 2,
             "Three syllables per beat means three notes per beat: triplets."),
        tap(TWO_THREE, bpm=60, bars=2),
        tap(TRIPLETS, bpm=66, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-5-3", "Swing feel", [
        explain("Swing: long, short", 'In swing, each pair of eighths turns long-short. The "and" moves late, onto the last part of a triplet. Think doo-ba, doo-ba.',
                rhythm(SWING)),
        tap(TRIPLETS, bpm=60, bars=2),
        explain("Skip the middle triplet", 'Count 1-trip-let and tap only on "1" and "let." The gap in the middle is the swing.',
                rhythm(SWING)),
        tap(SWING, bpm=60, bars=2),
        quiz('In swing, where does the "and" land?', ["Exactly halfway", "Right after the beat", "Late, on the last triplet"], 2,
             'Swing delays the "and" to the last triplet, which gives the long-short lilt.'),
        tap(SWING, bpm=72, bars=2),
    ], minutes=4, xp=20),
    lesson("rhy-5-4", "The ride pattern", [
        explain("The jazz ride pattern", 'Jazz drummers play this on the ride cymbal: 1, 2, a swung "and," 3, 4, a swung "and." It sounds like ding, ding-a ding.',
                rhythm(RIDE)),
        tap(RIDE, bpm=60, bars=2),
        quiz('How do you tap a swung "and"?', ["Late, on the last triplet", "Exactly halfway", "On the next beat"], 0,
             'A swung "and" waits for the last triplet of the beat.'),
        tap(RIDE, bpm=70, bars=2),
        explain("Straight or swung", "Straight eighths split the beat evenly; swung eighths go long-short. Tap one, then the other, and feel the difference.",
                rhythm(E8)),
        tap(E8, bpm=70, bars=2),
        tap(SWING, bpm=70, bars=2),
        tap(RIDE, bpm=80, bars=4),
    ], minutes=5, xp=25),
    lesson("rhy-5-5", "Threes and swing", [
        explain("Put it together", "This challenge mixes triplets, straight eighths and swing. Keep the beat steady while the way you split it changes."),
        tap(TRIPLETS, bpm=66, bars=2),
        listen("Are the clicks in groups of two or three?", clicks(9, (0, 3, 6)), ["Groups of two", "Groups of three"], 1),
        tap(TWO_THREE, bpm=66, bars=2),
        quiz("Swing turns each pair of eighths into what?", ["Two equal halves", "Long, then short", "Short, then long"], 1,
             'The first eighth stretches and the "and" arrives late.'),
        tap(SWING, bpm=75, bars=2),
        tap(RIDE, bpm=85, bars=4),
    ], minutes=5, xp=30, kind="challenge"),
])

# Tap steps outside 4/4 end on the bar's last beat where the music allows, so the bar length is
# clear from the pattern itself (tap steps carry no beats-per-bar).
UNIT_6 = unit("rhy-6", "Other meters", "Waltz in three, march in two, rock in 6/8, and place the accents.", [
    lesson("rhy-6-1", "Waltz time: 3/4", [
        explain("Three beats to a bar", "In 3/4 time each bar has three beats: ONE, two, three. It's the waltz. Count 1, 2, 3 and lean on 1.",
                rhythm([0, 1, 2], 3)),
        tap([0, 1, 2], bpm=70, bars=4),
        listen("The strong click is beat 1. How many beats are in each bar?", clicks(9, (0, 3, 6)), ["Two", "Three", "Four"], 1),
        explain("Long, short in three", "A half note fills two of the three beats. Tap 1, count 2, tap 3. It feels like the big step and small step of a waltz.",
                rhythm([0, 2], 3)),
        tap([0, 2], bpm=70, bars=4),
        quiz("How many beats are in a bar of 3/4?", ["Two", "Four", "Three"], 2,
             "The top number of a time signature tells you how many beats are in each bar."),
        tap([0, 1, 1.5, 2], bpm=80, bars=4),
    ], minutes=4, xp=20),
    lesson("rhy-6-2", "March time: 2/4", [
        explain("Two beats to a bar", "2/4 has two beats per bar: ONE, two, like marching feet. The bars go by quickly, so beat 1 comes around often.",
                rhythm([0, 1], 2)),
        tap([0, 1], bpm=80, bars=4),
        listen("The strong click is beat 1. How many beats are in each bar?", clicks(8, (0, 2, 4, 6)), ["Two", "Three", "Four"], 0),
        tap([0, 0.5, 1], bpm=80, bars=4),
        quiz("Which meter feels like a march?", ["3/4", "2/4", "6/8"], 1,
             "Two beats per bar match left, right, left, right."),
        tap([0, 0.5, 1, 1.5], bpm=90, bars=4),
    ], minutes=4, xp=20),
    lesson("rhy-6-3", "Six-eight time", [
        explain("Six eighths, two groups", "In 6/8 each bar holds six eighth notes in two groups of three: ONE two three FOUR five six. It feels like two big, rocking beats.",
                rhythm([0, 1, 2, 3, 4, 5], 6)),
        tap([0, 1, 2, 3, 4, 5], bpm=100, bars=2),
        quiz("How does 6/8 usually feel?", ["Three beats, each split in two", "Two beats, each split in three", "Six equal beats, no pattern"], 1,
             "The six eighths fall into two groups of three, so you feel two big beats."),
        explain("Long, short in 6/8", "A favorite 6/8 pattern goes long-short, long-short: tap 1, 3, 4 and 6. It rocks like a lullaby or a sea shanty.",
                rhythm([0, 2, 3, 5], 6)),
        tap([0, 2, 3, 5], bpm=100, bars=4),
        listen("Six clicks per bar. Which meter is this?", clicks(12, (0, 3, 6, 9)), ["3/4: three groups of two", "6/8: two groups of three"], 1),
        tap([0, 2, 3, 5], bpm=110, bars=4),
    ], minutes=5, xp=25),
    lesson("rhy-6-4", "Accents", [
        explain("Accents shape a rhythm", "An accent is a note played stronger than the ones around it. Move the accents and the feel changes, even when every note stays the same.",
                rhythm(E8)),
        listen("Count the clicks from 1 to 8. Where do the strong ones fall?", clicks(8, (0, 3, 6)), ["1 and 5", "1, 3, 5 and 7", "1, 4 and 7"], 2),
        explain("Tap only the accents", 'Count all eight eighths and tap just the accents: 1, the "and" of 2, and 4. This 3-3-2 pattern drives a lot of pop and Latin music.',
                rhythm([0, 1.5, 3])),
        tap([0, 1.5, 3], bpm=80, bars=4),
        quiz("What is an accent?", ["A note played longer", "A note played stronger", "A note left out"], 1,
             "An accent is about weight, not length. The note is simply played stronger."),
        explain("The backbeat", "Rock, pop and soul put the accent on beats 2 and 4. This is the backbeat. Count all four and tap only 2 and 4, like a snare drum.",
                rhythm([1, 3])),
        tap([1, 3], bpm=90, bars=4),
        listen("The first click is beat 1. Where are the strong clicks?", clicks(8, (1, 3, 5, 7)), ["On 1 and 3", "On 2 and 4", "On every click"], 1),
        tap([1, 3], bpm=100, bars=4),
    ], minutes=5, xp=25),
    lesson("rhy-6-5", "Every meter", [
        explain("Put it together", "This challenge moves between meters and accents. Before each tap step, count one bar under your breath to find beat 1."),
        tap([0, 1, 2], bpm=80, bars=4),
        listen("The strong click is beat 1. How many beats are in each bar?", clicks(12, (0, 3, 6, 9)), ["Four", "Three", "Two"], 1),
        tap([0, 0.5, 1, 1.5], bpm=90, bars=4),
        quiz("How many eighth notes are in a bar of 6/8?", ["Six", "Three", "Eight"], 0,
             "Six eighth notes per bar, felt in two groups of three."),
        tap([0, 2, 3, 5], bpm=110, bars=4),
        listen("Six clicks per bar. Which meter is this?", clicks(12, (0, 2, 4, 6, 8, 10)), ["3/4: three groups of two", "6/8: two groups of three"], 0),
        tap([1, 3], bpm=100, bars=4),
    ], minutes=5, xp=35, kind="challenge"),
])

COURSE = course("rhythm", "Rhythm", "Feel the beat, count it, and tap it in time", None, "metronome", "coral", [
    UNIT_1, UNIT_2, UNIT_3, UNIT_4, UNIT_5, UNIT_6,
])
