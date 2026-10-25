# JURY 15: Category expert (tuner and lesson apps, head-to-head)

Juror: a guitar, ukulele and violin teacher and music-tech product analyst who uses GuitarTuna, Fender Tune and Fender Play, Yousician, Simply Guitar, JustinGuitar and Ultimate Guitar every week.

Method:
- I read the DSP (`Sources/TimbreCore/DSP`, `Tuning`, `Timbre/Tune`, `AudioService`) and the judges (`LessonEngine`, `OnsetDetector.RhythmJudge`, `ChordRecognizer`, `LessonSteps`, `SongPerform`).
- I machine-checked the curriculum:
  - all 108 distinct chord shapes in `curriculum.json` against their names and tunings;
  - all 156 interval and chord-quality ear questions;
  - melody against chord chart for every song with an arrangement.
- I read sample lessons from guitar, ukulele, violin, ear, theory and the song collections.
- I opened 25 store frames.
- I pulled current competitor facts from the App Store and reviews (October 2026).

---

## 1. Score for my angle: **7.8 / 10**

Timbre already wins three things outright:
- **The tuner.** Strum-to-tune is a real polyphonic damped-partial solver (`PolyTuner.swift:67-95`). It adds 60 instruments, strobe, intonation and string-health coaching. GuitarTuna, Fender Tune and Fender Play have nothing like it.
- **The breadth of instruments that listen as you learn.** Guitar, ukulele, bass, violin, cello, mandolin, banjo and voice, plus ear, theory and rhythm, all in one $34.99 plan.
- **Correctness.** All 108 chord shapes and all 156 ear answers check out. The guitar path sequences much like JustinGuitar's: Em → E → Am → A, the pendulum hand, "old faithful", CAGED, triads, ii–V–I.

It is not the app an ordinary beginner chooses over the lesson leaders, for four reasons:
- **No song a normal person would ask for.** There are 117 distinct tunes: nursery rhymes, hymns, classical themes and 50 house Originals. GuitarTuna has 20,000+, Yousician 10,000+ songs and lessons, JustinGuitar 1,500+ and Fender Play 1,000+.
- **No human teacher, and no picture for the hardest physical skills.** The bow hold, the violin hold, cello posture, the pick grip, palm muting, p-i-m-a and the F barre are text only.
- **Strumming feedback checks only timing.** Strum steps, progressions and whole-song takes never check the chord (`LessonSteps.swift:1509`, `SongPerform.swift:397`). Yousician and Simply Guitar check chords, and since 2025–26 JustinGuitar's chord exercises detect strums and chord changes.
- **The free tier is stingier than the free tuners.** Chords, scales and capo are Pro, and the guitar has 6 preset tunings against Fender Tune's 26 free.

On my angle it is a very good app with visible seams. It is #1 on the tuner, on breadth and on price, and behind on songs, teaching media and chord feedback. Those three are what this category sells on.

---

## 2. Head-to-head on my angle

### Scoreboard: who is #1 on each user-facing dimension today

| Dimension | #1 today | Timbre | Evidence |
|---|---|---|---|
| Tuner accuracy and UX | **Timbre** | #1 | YIN with least-squares interpolation, bench <0.75 ¢ on plucked strings (`DSPTests.swift:111-138`). Lock bands of 5, 3 and 1 ¢ (`TuningTracker.swift:11-20`). Strum-to-tune (11b) with an honest "≈ estimate" when a string shares a harmonic (`PolyTuner.swift:13-17`). Peg cues with turn arrows now on ukulele too (17). "Pluck all" on violin (49b). Intonation check (46). No competitor in the set has polyphonic tuning; the only App Store one is TC's abandoned PolyTune (2.8★, last update 2017). |
| Instruments and tunings | Split | #1 instruments, #3 guitar tunings | 60 instruments and 102 tunings, against GuitarTuna's 15 instruments. But guitar has only 6 presets (`catalog.json:104-110`), against Fender Tune's 26 free alternates and GuitarTuna's 100+ (Premium). |
| Breadth of lessons that listen | **Timbre** | #1 | 14 courses and 638 lessons, including violin (38), cello (31), mandolin (33) and banjo (30). Nobody else in the set teaches bowed strings, mandolin or banjo with a microphone. |
| Lesson pedagogy and correctness | **JustinGuitar** | #2 | Timbre's content is correct and well paced, and every step is interactive. Justin has hundreds of human video lessons (210 lessons and 36 h in the app's beginner path alone) and grades 1–9. Timbre's guitar course is 153 lessons and 798 min, and its physical technique is text-only (87 such steps have no visual). |
| Song catalogue | **GuitarTuna / UG** (count), **Yousician / Simply** (play-along with real songs) | last | 117 distinct tunes behind the paywall's "159 songs" (`PaywallView.swift:485-486` counts song *lessons*, and Ode to Joy is 8 of them). 50 Originals nobody has heard. Ukulele users see 12 songs (`SongsView.swift:1296-1301`; all collections are `guitar.acoustic.6`, `originals.py:995`, `songs.py:11`). |
| Feedback while playing | **Yousician** | #2 on notes, #4 on chords | Notes: the cents and ms judge is the best in the set (`LessonEngine.swift:50-71`; 55 "120 ms late"; 65). Chords: checked only on single-chord steps. Strum, progression and whole-song takes are onset-timing only (`LessonSteps.swift:1509`, `SongPerform.swift:397`). |
| Practice tools | **Timbre** for range, **Fender Tune** for library depth | #1 / #2 | Strobe, drone/tanpura, intonation, Bullseye, ear games, metronome with trainer, latency calibration. Fender Tune gives 5,000+ chords, 2,000+ scales and 65 drum rhythms free. Timbre has 14 chord qualities and 8 scales (`Chords.swift:11-25, 318-327`), and Chords and Scales are Pro (`PracticeView.swift:571-577`). |
| Progress and motivation | **Timbre ≈ Yousician** | #1 (tie) | XP, levels, quests, streak freezes, 42 badges, SM-2 weak-spot review, a coach that reads string drift with a 10-day settling rule (`Progression.swift:407-412`), week recap (32), Game Center, widgets and a Live Activity. |
| Price and value | **Timbre** | #1 | $34.99/yr, $6.99/mo or $89.99 lifetime, with a 14-day trial and a day-12 reminder (06). Fender Play lists $149.99/yr, Yousician One Instrument $119.99 (Premium Plus $159.99–$179.99), Simply Guitar $119.99–$199.99, GuitarTuna Learn $139.99 (Play $39.99), Justin app $64.99–$129.99. |
| Trust and social proof | Everyone else | last | No ratings yet. Competitors sit at 4.6–4.8 with 27K–481K ratings. |

### Timbre vs GuitarTuna (4.8★, 149K ratings; Play $39.99/yr, Learn $139.99/yr; free tier has ads)

- **Tuner: Timbre wins.**
  - Timbre: strum-to-tune, 60 instruments to GuitarTuna's 15, strobe, intonation, string health, no ads, and every preset tuning free on the five free instruments (`Access.swift:35-41`).
  - GuitarTuna: only standard tunings are free.
- **Songs: GuitarTuna wins decisively.** It has 20,000+ licensed songs with chords and tabs, adds songs weekly (McCartney, Fleetwood Mac, Billie Eilish in 2025–26 notes), and offers "Simplified/Original" chords.
- **Lessons: Timbre wins.** Its 638-lesson structured path is deeper than GuitarTuna's chord trainers and "Learn" videos, and costs a quarter of GuitarTuna Learn.
- **Verdict:** a tuner-first user should pick Timbre. A "chords for the song I heard yesterday" user picks GuitarTuna. GuitarTuna wins the mass market on songs.

### Timbre vs Fender Tune (4.8★, 152K ratings, free) and Fender Play (4.8★, 61K; $149.99/yr list)

- **Fender Tune.** Timbre's auto tuner is better: Fender Tune reviewers report the auto mode gets "stuck on a string", and it has no strum-to-tune. But Fender Tune gives away what Timbre charges for:
  - 26 alternate tunings and custom tunings (Timbre: custom is Pro, `InstrumentsView.swift:300`);
  - 40 reference pitches;
  - 5,000+ chords and 2,000+ scales (Timbre: both Pro);
  - 65 drum grooves.

  On free value, Fender Tune wins.
- **Fender Play.** Fender wins on teaching media and songs: 3,000+ multi-angle video lessons from real instructors, 1,000+ licensed songs, isolated tracks and looping. Timbre wins on:
  - feedback (Fender's Feedback Mode is still beta);
  - price, about a quarter of Fender's;
  - instrument breadth (Fender covers only guitar, bass and ukulele);
  - a path that grades every step.

  A returning adult who wants "Wonderwall" picks Fender.

### Timbre vs Yousician (4.6★, 139K; One Instrument $119.99/yr, Premium Plus $159.99–$179.99)

- **Feedback: Yousician wins on chords and songs.** It judges notes *and* chords in thousands of songs. Timbre's highway is as good or better on single notes:
  - cents-aware grades (perfect needs ≤70 ms and ≤20 ¢);
  - a tempo ladder that caps stars below lesson tempo (`LessonEngine.swift:98-166`);
  - latency calibration.

  But Timbre's chord steps stop listening for the chord the moment you strum in time.
- **Breadth and price: Timbre wins.** It covers violin, cello, mandolin, banjo and ear and theory courses at a quarter to a fifth of the price. Its gamification is calmer, which addresses the "fast, game-style interface" complaint in reviews.
- **Verdict:** Yousician wins for a guitarist who wants hit songs. Timbre wins for a string player, a ukulele beginner on a budget, or anyone who wants a real tuner.

### Timbre vs Simply Guitar (4.7★, 400K; $119.99–$199.99/yr)

- **Simply wins the first week.** A friendly video teacher, a famous song within days, and chord checking that ordinary people trust.
- **Timbre wins depth and range.** It continues to barre chords, CAGED, triads, jazz voicings and modes (guitar units 13–22), which Simply's reviews say it lacks. It also covers seven more instruments, a far better tuner, and about a third of the price.
- **Verdict:** a total beginner choosing on the store page picks Simply, because of video and songs. Timbre must win them with the tuner and convert them later.

### Timbre vs JustinGuitar (4.8★, 27K; app $64.99–$129.99/yr; website lessons free)

- **Justin wins pedagogy and trust.** A world-class human teacher, free on the web and YouTube, 1,500+ songs in the app, and, since 2025–26, chord detection in "Perfect Fast Changes" and strum exercises.
- **Timbre's content follows the same proven order.** Its correctness is excellent, and each step listens and grades, which Justin's videos do not. But it has no face, no voice, and no picture of a hand.
- **Verdict:** Justin is #1 for guitar pedagogy. Timbre is #1 for "a teacher in the phone for my violin or ukulele that hears me".

### Timbre vs Ultimate Guitar (4.7★, 481K; Pro $39.99/yr)

- UG wins songs: 29K+ interactive tabs with backing tracks.
- Timbre's "Your songs" accepts a UG-style chord sheet pasted in (`ChordPro.swift:358-430`) and plays it with auto-scroll, a recording and chord analysis. This is the right answer to licensing, but it is capped at 3 free charts (`ChartPlayback.swift:258`), and its practice steps inherit the timing-only judge.

---

## 3. Everything that costs points, ranked

**1. BLOCKER · M: Strumming is graded on timing only.** Screens 55 and 60, the whole-song take (65), every Originals progression, and the App Preview's "chord lesson".
- **Where:**
  - `LessonSteps.swift:1509`: `LessonAnalyzer(chords: false, …)` in `RhythmStep.start()`, used for `.strum` and `.progression`.
  - `LessonSteps.swift:1524-1529`: grades are onset distance only.
  - `SongPerform.swift:397`: `chords: false`.
  - The only chord checks are the single-chord step (`LessonSteps.swift:768`), the explain "try it" (`LessonExplain.swift:679`) and the Chords tool (`ChordsView.swift:219`).
- **What is wrong:** a learner can strum open strings, a wrong chord, or tap the body through "C – Am – F – G" and earn "Flawless", three stars and 100 %. That breaks the listing's promise, "Timbre listens as you play: … whole chords and strumming rhythm" (`APP-STORE-LISTING.md:91`). Yousician, Simply Guitar and now JustinGuitar check the chord.
- **Fix:**
  - In `RhythmStep.start()`, build `LessonAnalyzer(chords: true, target: chordAt(beat), onChord:, onOnset:)`, retargeting per bar from `chords`/`bars`. Add a `retarget(_:)` to `LessonAnalyzer` that calls `recognizer.reset()` and swaps `target`.
  - In `register(_:)`, keep the onset grade, then confirm the stroke: the recognizer must `matches(target)` in any 4096-hop frame within 60–250 ms after the onset.
  - Wrong chord: cap the stroke at `.ok`, store `heard` and paint the beat chip amber with "Am?".
  - No chord at all (muted or tapped): `.miss`.
  - Feed chord accuracy into `CoachTake.strummed` so the coach can say "C → F lands late *and* half the time it's still C".
  - Mirror this in Your songs practice.

**2. BLOCKER (category) · L (owner) + S (code): No recognisable songs, and the count is inflated.** Screens 63, 64, 06, ipad-*-songs.
- **What is wrong:**
  - 117 distinct tunes: nursery rhymes, hymns, carols, classical themes, fiddle tunes and 50 Originals.
  - The paywall says "159 songs" (`PaywallView.swift:481-486` counts `kind == .song` lessons, so Ode to Joy counts 8×, Amazing Grace 7×, Twinkle 4×).
  - The Originals have no real recording, so "Preview with band" is the synthesized groove.

  The #1 reason people pay in this category is playing songs they know.
- **Fix:**
  - **Code:** count distinct tunes (`SongsView` already keys tunes by `tuneKey`, `SongsView.swift:1211`) and print "117 songs".
  - **Content:**
    - Add the public-domain songs ordinary people actually request, with clearance per `PUBLIC-DOMAIN-CLEARANCE.md`: Swing Low, Sweet Chariot; Wayfaring Stranger; Home on the Range; Shenandoah on guitar; The Yellow Rose of Texas; Hava Nagila. Schedule Happy Birthday for 1 January 2027, when the life+80 term the doc cites runs out.
    - Owner: license 30–100 hits (section 5).

**3. MAJOR · M: Ukulele, the #2 course, has a 12-song Songs tab.**
- **Where:** `SongsView.swift:1296-1301` shows only courses whose `instrument` matches the chip. Songs, Originals and Standards are all `guitar.acoustic.6` (`songs.py:11`, `originals.py:995`).
- **What is wrong:** a ukulele buyer opens Songs → Ukulele and finds 12 songs. On guitar they would get 117.
- **Fix:** in `tools/curriculum/songbook.py`, emit a "Ukulele songbook" course for every chord-based song:
  - transpose to C, G, F or Am;
  - map chords through the uke shape table already in `ukulele.py`;
  - re-fret the melody on G-C-E-A with re-entrant awareness (prefer strings 1–3);
  - reuse the sleeves.

  This gives about 100 uke songs for no licensing cost. Do the same for mandolin (G-D-A-E) on the fiddle tunes.

**4. MAJOR · M: Physical technique is text-only.**
- **Where:** 87 explain steps about holding, bowing, picking or muting have `visual: none`, including:
  - "A soft, round bow hold" (`violin.py:264`);
  - "Collarbone and chin rest" (`violin.py:248`);
  - "Sit tall, near the edge" (`cello.py:244`);
  - "Hold the pick" (mandolin);
  - "Palm muting", "Pluck into your palm" (p-i-m-a), "Pull, don't squeeze" (F barre) and "Three fingers push" (bends).
- **What is wrong:** no violin teacher would teach a bow hold in words. Every lesson competitor shows a hand on video.
- **Fix:** add `LessonVisual.clip(name:)` (a 3–5 s looping HEVC or a photo set) and an `explain(..., clip="bow_hold")` path in `lib.py`. Shoot about 40 clips (section 5). Until then, use annotated photographs of a hand on the existing usdz models.

**5. MAJOR · M: "Every string rings" ticks strings it never heard.** Screen 52b.
- **Where:** `LessonSteps.swift:768-776`. After 3 matching chroma frames it sets `verified = Set(order.map(\.index))`, every string, and line 468 prints "Every string rings".
- **What is wrong:** chroma cannot tell a muted string 4 from a ringing one when another string carries the same pitch class. The lesson's own advice ("A dull thud means a finger is touching that string", gtr-3-1) is exactly the fault this screen hides.
- **Fix:** run `PolyTuner(strings: chord.sounding pitches)` on the first strum. Mark strings the solver reports `isHeard == false` (or `.shared` with low confidence) as muted, keep them unticked, and say "String 3 isn't ringing: arch finger 2". `PolyTuner` already separates partials a fraction of a hertz apart (`PolyTuner.swift:76-90`). No app in the category tells you *which* string is muted. This would be a first.

**6. MAJOR · M: Left-handed mode stops at the tuner.**
- **Where:** handedness is read only in `StringRail.swift:16` and `StrumModel.swift:325`. `Diagrams.swift:51-82` (StringOrder and ChordPicture), the highway lanes, Player view, `ShowMeScene` and the Scales neck ignore it.
- **What is wrong:** about 10 % of players are left-handed. Their "Player view" and 3D "Show me" are mirror images of their own instrument. GuitarTuna lists left-hand mode, and UG's is free.
- **Fix:** add `.left` handling to `StringOrder`. Flip the x of Player-view necks, highway lanes and the strum stage, and set `scale.x = -1` on the Show-me model root. Leave Chart view unmirrored, as printed chord books are.

**7. MAJOR · S: The free tier gives away less than the free tuners.**
- **Where:**
  - Chords, Scales, Drone and Intonation are Pro (`PracticeView.swift:571-577`).
  - Capo and transpose are Pro (`SettingsView.swift:150,162`).
  - Metronome subdivisions and the trainer are Pro (`MetronomeView.swift:286,355`).
  - Custom tunings are Pro (`InstrumentsView.swift:300`).
- **What is wrong:** Fender Tune is free with 26 alternate and custom tunings, 5,000+ chords, 2,000+ scales and 65 drum rhythms. GuitarTuna's free tier has a chord library and metronome. A "best free tuner" reviewer will mark Timbre down for paywalling a capo.
- **Fix:** make the open-position chord library (with Check), capo, eighth and triplet subdivisions, and one custom tuning free. Keep barre and movable voicings, the trainer, drone, intonation, temperaments and lessons in Pro.

**8. MAJOR · S: Guitar has 6 preset tunings.**
- **Where:** `catalog.json:104-110`: Standard, Drop D, E♭, Open G, Open D, DADGAD.
- **What is wrong:** players search "drop C tuner" or "open E tuning". Fender Tune ships 26 and GuitarTuna 100+. The keywords even target "tuning" (`APP-STORE-LISTING.md:66`).
- **Fix:** add D standard, C standard, B standard, Drop C♯, Drop C, Drop B, Double drop D, Open C, Open E, Open A, Open E minor, Open C6, CGCGCE, Nashville (high-strung), Half-step-down Drop D♯ and Lute (G). Do the same on bass: Drop C, BEAD and 6-string.

**9. MAJOR · M/L: A song can only be performed as its melody.**
- **Where:** screens 63 ("Play real melodies, start to finish") and 65. `SongPerform` judges `TimedNote`s only (`SongPerform.swift:5-10`).
- **What is wrong:** an ordinary player wants to strum and sing a whole song. The chord chart exists (`SongArrangement.chords`), but no take uses it.
- **Fix:** add a second mode, "Chords & words". Use the same runway, with one chord block per change from `arrangement.chords` and the pattern from the lesson's progression steps. Judge it with fix #1's onset-plus-chord judge, scroll lyrics karaoke-style, and keep the same tempo ladder and stars.

**10. MINOR · S: Capo lessons draw no capo.**
- **Where:** gtr-16-1, gtr-16-2, gtr-16-spotlight and gtr-16-6. "A" = `[5,4,2,2,2,5]` with fingers `[2,1,0,0,0,3]`, and F♯m and B likewise.
- **What is wrong:** the diagram (`Diagrams.swift:565`) draws fret-2 notes as unnumbered dots with no capo bar. A beginner reads it as a strange A chord with three un-fingered notes. The musical text is right ("a G shape on capo 2 reads A").
- **Fix:** add `capo: Int?` to `ChordSpec`. Draw a capo bar across the fret, number fingers relative to it, and caption "G shape · capo 2".

**11. MINOR · S: The banjo D7 is taught without its third and fails its own check.**
- **Where:** `banjo.py:31` teaches `x0210` (D A C D). `ChordRecognizer.matches` (`ChordRecognizer.swift:241-249`) ranks it D5 at about 0.74 against D7 at about 0.67, plus the shared bass bonus. That is outside the 0.05 tolerance, so a correctly played D7 falls back to string-by-string plucking.
- **Fix:** either:
  - teach `0-2-1-4` (adds F♯) and call x0210 "the two-finger D7"; or
  - in `matches`, accept a target whose pitch classes are a superset of a heard reading with the same root in the bass.

**12. MINOR · M: Tuner and judge accuracy is proven only on synthetic signals.**
- **Where:** `DSPTests.swift:111-138`, `PolyTunerTests.swift`, `ChordRecognizerTests.swift:50-96`, `SynthesizedSignals.swift`.
- **What is wrong:** "cent-level precision" and "listens as you play" have no real-world evidence: no recordings of cheap guitars, phone mics, TV in the room, or a child's ukulele.
- **Fix:** add a `Tests/Fixtures/RealWorld/` corpus with an expected-results JSON (owner records it), and fail CI below published targets. That also lets the listing claim "tested on 1,000 real strums".

**13. MINOR · S (owner): "Hear it" timbres are wrong for ukulele, mandolin and banjo.**
- **Where:** `AUDIO-SOURCES.md:39-48`. Ukulele plays classical-guitar samples, mandolin plays a Martin guitar, and banjo is synthesized.
- **What is wrong:** a ukulele teacher hears it in one note.
- **Fix:** see section 5.

**14. MINOR · S: The free lesson runway is short.**
- **Where:** guitar has 5 free lessons (Unit 1, about 20 min). The paywall hits at "Three notes on string 2", before the first song.
- **What is wrong:** JustinGuitar's beginner course is free on the web, and Yousician lets you play daily for free.
- **Fix:** test opening Unit 2 (Ode to Joy, Mary, and the "Letters in a Shoebox" spotlight). Gate at the first Original's full take, where desire peaks. This is A/B material once analytics is on.

---

## 4. How to take #1 (ranked by impact)

1. **Make strumming feedback the best in the category (fix #1 + fix #5).** Judge every stroke for time *and* chord, and name the dead string ("String 3 isn't ringing").
   - The DSP for both already exists in `ChordRecognizer` and `PolyTuner`; it is wiring, not research.
   - Nobody else tells a beginner *which* string is muted.
   - Put it in the App Preview's chord beat.
2. **Songs people know, on every instrument.**
   - (a) Ukulele and mandolin editions of all chord songs (fix #3): about 100 uke songs for free.
   - (b) 20 more public-domain songs people actually request, plus Happy Birthday on 1 January 2027.
   - (c) Real band recordings of the 10 best Originals so they sound like records, not exercises.
   - (d) A licensed starter pack of 30–100 hits (owner).
   - (e) "Your songs": raise the free cap to 10 and make it the headline answer to "can I play *my* song?" Paste any chord sheet and Timbre listens.
3. **A teacher you can see.** 40 short clips for the text-only technique steps (fix #4), and a rigged hand in "Show me". Lead the violin and cello courses with them: no competitor has listening violin lessons, so a filmed bow hold makes Timbre the only credible app for string beginners.
4. **"Chords & words" song performance (fix #9).** Strum the whole song with lyrics and chord-checked strokes. This is the moment Yousician and Simply sell, and Timbre has every part except the mode.
5. **Win "best free tuner" outright (fixes #7, #8).**
   - 22+ guitar presets.
   - Capo, open chords, subdivisions and one custom tuning free.
   - Keep everything else in Pro.

   The tuner is the funnel (GuitarTuna and Fender Tune each have 150K ratings). Being strictly better than Fender Tune for free is how you get the installs that the $34.99 plan converts.
6. **Left-handed everywhere (fix #6)** and **capo-aware diagrams (fix #10).** These are cheap, and a lefty reviewer notices them in the first lesson.
7. **Honest, positioned store copy.**
   - "117 songs", not 159.
   - Lead with "The tuner and teacher for every string instrument: guitar, ukulele, violin, cello, mandolin, banjo, bass and voice, from $34.99 a year".
   - Price-anchor against Fender Play and Yousician on the paywall ("¼ the price of the big lesson apps").
8. **Prove accuracy (fix #12).** Run a real-recording benchmark against GuitarTuna and Fender Tune on the same strums. Publish the result on the website and the listing; it is the credibility a new brand lacks.

---

## 5. What only the owner can do

- **Song licensing:**
  - 30–100 recognisable songs (Hal Leonard, Musicnotes or Songtradr-style sync and print deals, or indie labels and artists who want exposure);
  - or artist partnerships like Yousician's Artist Sessions.

  Budget roughly $15–60k advances plus revenue share. This is the single biggest conversion lever.
- **Teacher video:** one guitar, ukulele and violin/cello teacher for about 40 technique clips and Unit 1–2 intros. Two shoot days, about $8–15k.
- **Recordings:**
  - ukulele (soprano and low-G), mandolin, 5-string banjo, solo cello;
  - a sung voice for the voice course;
  - full-band stems for the 10 strongest Originals.
- **3D:** a rigged hand for "Show me", plus ukulele and banjo usdz models.
- **A real-world test corpus:** about 1,000 labelled strums and notes on 20 instruments, with cheap and good guitars and several iPhones.
- **Social proof:** a TestFlight cohort of 200, a few teacher endorsements (a uke or violin teacher would be unique), and early ratings before launch. Competitors sit on 27K–481K ratings.
- **Decide the left-handed and free-tier policy, and run paywall and price tests** once analytics is on (`TimbreTelemetryAppID`). Lifetime at $89.99 against Fender's $149.99 per year is a strong anchor; test $99.99.
- **Bowed pegs:** have a violinist confirm the current pegbox mapping before marketing it. `violin.rig.json` now puts G and E on the pegs nearest the nut, against the artist rig, and published guides disagree on the convention (Gear4music: "G … upper-left peg; D … lower-left").

---

## 6. Sources

- [GuitarTuna on the US App Store](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): 4.8★, 149K ratings, 20,000+ songs, the IAP list, and 2025–26 notes adding licensed songs.
- [App Pricing Lab: GuitarTuna IAPs](https://apppricinglab.com/iap/apple/527588389): Play $39.99/yr, Tools $29.99/yr, Learn $139.99/yr.
- [Yousician support: GuitarTuna tunings](https://support.yousician.com/hc/en-us/articles/360014233198-How-to-change-tunings-and-other-tuner-options): "over a 100 popular tunings", with only standard free.
- [GuitarTuna on ScreensDesign](https://screensdesign.com/showcase/guitartuna-tune-play-guitar): onboarding, soft paywall, Smart Scroll.
- [American Songwriter: best guitar tuner apps (2025, modified 2026)](https://americansongwriter.com/best-guitar-tuner-apps): GuitarTuna free tier with ads and paid tiers, Fender Tune, Chordify polyphonic tuning.
- [Fender Tune on the App Store](https://apps.apple.com/app/id1107017950): 4.8★, 152K ratings, 26 alternate tunings, 5,000+ chords, 2,000+ scales, 65 drum rhythms, version 4.17.0 iOS 27 redesign.
- [Fender Play on the US App Store](https://apps.apple.com/us/app/fender-play-learn-guitar/id1226057939): 4.8★, 61K ratings, 3,000+ lessons, 1,000+ songs, the IAP list, and 8.0 notes.
- [Guitar World: Fender Play review](https://guitarworld.com/reviews/fender-play-review): $19.99/mo, $149.99/yr, Feedback Mode in beta.
- [Yousician on the US App Store](https://apps.apple.com/us/app/yousician-learn-guitar-piano/id959883039): 4.6★, 139K ratings, 10,000+ lessons and songs, One Instrument $119.99/yr, Premium Plus $159.99–$179.99.
- [American Songwriter: Yousician review](https://americansongwriter.com/yousician-review/): pricing tiers and the game-style criticism.
- [AI Guitar Lessons & Teacher by Yousician](https://apps.apple.com/us/app/-/id1640426327): June, an AI teacher with real-time feedback.
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): 4.7★, 400K ratings, IAPs $19.99–$199.99.
- [American Songwriter: Simply Guitar review](https://americansongwriter.com/simply-guitar-review): video instructor, feedback, beginner focus.
- [JustinGuitar Lessons & Songs on the US App Store](https://apps.apple.com/us/app/justinguitar-lessons-songs/id1176125504): 4.8★, 27K ratings, 210 video lessons, 1,500+ songs, and 2025–26 chord-detection notes.
- [Guitar World: JustinGuitar review](https://www.guitarworld.com/reviews/justinguitar-review): free website lessons and grades 1–9.
- [Ultimate Guitar on the US App Store](https://apps.apple.com/us/app/ultimate-guitar-chords-tabs/id357828853): 4.7★, 481K ratings, Pro $39.99/yr, 29K+ tabs with backing tracks.
- [PolyTune (TC Electronic) on the App Store](https://apps.apple.com/app/id364009203): polyphonic tuning, 2.8★, last updated 2017.
- [Gear4music: violin tuning](https://www.gear4music.com/blog/violin-tuning) and [Violinspiration: tuning with the pegs](https://violinspiration.com/how-to-tune-a-violin-with-the-pegs/): peg-to-string layout.
- [Violinist.com: peg discussion](https://www.violinist.com/discussion/archive/25584): peg-to-nut string runs.
