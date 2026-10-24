# Writing Timbre lessons

Lessons are Python data in `tools/curriculum/courses/<course>.py` (one `COURSE = course(...)` per file),
built with the helpers in `lib.py` and checked by `python3 tools/curriculum/build.py --check --only <course>`.
`courses/guitar.py` unit 1 is the reference for tone and pacing. Read `lib.py` before writing.

## Shape
- A course has 5–10 units; a unit has 4–7 lessons; the last lesson of every unit is a `kind="challenge"`
  that mixes what the unit taught (no new ideas). Songs are `kind="song"`.
- A lesson is 3–6 minutes: 5–9 steps. Open with one short `explain`, alternate doing and knowing,
  end on something played (`along`, `strum`, `notes`) or a confident win. Never more than two
  `explain` steps in a row. Every lesson has at least two steps the learner performs or answers.
- Difficulty climbs slowly. Repeat new material in the next two lessons. Tempos start at 60–70 bpm
  and rarely exceed 100 for beginners. Melodies stay in first position (frets 0–4) unless the lesson
  is about moving up the neck.
- XP: 15 for short lessons, 20 normal, 25 long, 30–40 challenges and songs.

## Voice
- American English. Second person, present tense, warm and direct, like a good teacher sitting next
  to you. No exclamation marks except in a rare celebration. No emoji. No filler ("Let's dive in").
- One idea per `explain`: title ≤ 42 characters, body ≤ 300 (aim for 120–200). Plain words; define a
  term the first time it appears. Give a physical cue the learner can feel ("thumb behind the neck").
- Quiz options are short and plausible; put the reason in `why`. Mix the position of the right answer.
- Reuse identical sentences where the meaning is identical (they translate once).

## Music
- Strings are numbered 1 (thinnest/highest) to N; frets 0 = open. `lib.position` picks first-position
  frets; force a string with `"E4@1"` in `along` or `("E4", 1)` in `notes`.
- Chord shapes are strings lowest string first (`"x32010"` = guitar C); the builder rejects shapes whose
  notes aren't in the chord. Fingers: 1 index … 4 little, 0 for open/muted.
- Only public-domain or traditional melodies (composer died before 1930, or traditional and published
  before 1929). Name the song plainly ("Ode to Joy", "Greensleeves", "Shenandoah").

## Songs (the Songs and Originals courses)
- Every song lesson is a full arrangement built with `songbook.song(...)` from `Part`s (intro, verses,
  choruses, a bridge where the tune has one, a solo, an outro): 90–180 seconds at its tempo, checked by
  `build.py --check`. Its last step is `SONG.take(...)` (the whole song) and the lesson passes
  `arrangement=SONG.meta()` and `minutes=SONG.minutes()`. Earlier steps teach parts with `SONG.along(...)`.
- Write the arrangement from the real tune and its real harmony: one chord token per bar ("C,G" splits a
  bar). Each part's melody fills whole bars after its `pickup`. Keep a song inside its unit's range and
  difficulty; vary a second verse or the last chorus rather than adding harder technique.
- Lyrics only where the text is in the public domain (written before 1929), or our own for Originals
  (credit `words="Timbre"`). Never quote modern or copyrighted lyrics, not even a line. Instrumental
  pieces have no words. One lyric token per note; `songbook.py` documents "-", "~", "_" and "/".
- Lyric lines are short enough to read under the highway (about 40 characters) and stay inside one section.
- Rhythm patterns are beat positions inside one bar: `[0, 1, 2, 3]` quarters, `[0, 0.5, 1, 1.5, ...]` eighths.
- `listen` sounds are groups of notes played in order; a group with several notes sounds as a chord.

## Don'ts
- Don't edit `lib.py`, `build.py`, other courses, or anything outside your course files. Don't commit.
- Don't invent step types or fields. If you need something the helpers can't express, say so in your report.
