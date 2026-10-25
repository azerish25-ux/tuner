# JURY 16: Category expert (tuner and lesson apps, head-to-head)

Juror: a guitar, ukulele and violin teacher and music-tech analyst who uses GuitarTuna, Fender Tune and Fender Play, Yousician, Simply Guitar, JustinGuitar and Ultimate Guitar every week.

Method:
- **Code read.** I read the new judges: `StrokeChords`, `LessonAnalyzer`, `RhythmStep.judgeChord`, `ChordRing`/`heardStrum`, `ChordAlongJudge`/`SongChordsTake`, `AccessPolicy`/`FreeTier` and the paywall table.
- **Machine checks on `curriculum.json`** (17 courses, 904 lessons):
  - all 188 distinct chord shapes against their names and tunings (mandolin courses collapsed to 4);
  - all 115,112 positioned melody notes, string and fret against pitch;
  - finger numbers against frets on violin, cello, mandolin and ukulele;
  - every songbook edition against its source: transposition, octave folds and rhythm;
  - strong-beat melody notes against the chord chart for every song;
  - mid-bar chord changes against what the band and "Chords & words" can play.
- **Lessons sampled.** I read guitar units 17, 19, 20 and 21 and four song spotlights (units 2, 3, 9 and 13), plus ukulele units 7–9.
- **New standards.** I hand-checked the openings of 13 of the 20 against the hymn and tune sources.
- **Store frames.** I opened 30 frames.
- **Competitors.** I pulled current facts from the App Store pages and IAP trackers (October 2026).

---

## 1. Score for my angle: **8.3 / 10** (round 15: 7.8)

**What the team fixed.** Timbre now gives the most complete *feedback while playing* in the category:
- Every strum and progression stroke is graded for its chord as well as its timing (`LessonSteps.swift:1747`, `:1783-1800`).
- The chord step names the string that isn't ringing and why ("String 3 isn't ringing: arch finger 2", `LessonSteps.swift:824-871`). No competitor does that.
- "Chords & words" lets you strum a whole song with the lyrics.
- The free tier now beats GuitarTuna's outright: 24 guitar tunings, open chords with a microphone Check, capo, eighths and triplets, one custom tuning, 10 charts, and every instrument's standard tuning.
- Ukulele, mandolin and violin got real songbooks: 118 ukulele songs, up from 12.
- Left-handed mode and capo diagrams are done properly.
- Content correctness is again excellent:
  - 188 of 188 chord shapes are correct;
  - 115,112 of 115,112 note positions are correct;
  - the 13 openings I hand-checked among the 20 new standards are faithful, including the later-hymnal variant of *It Came Upon the Midnight Clear*.

**Why it is still not #1 for an ordinary beginner.** It still loses the two things this category sells on:
- **Songs people ask for.** There are 134 distinct tunes: 50 house Originals, 20 carols and hymns, about 22 classical themes, about 12 children's songs, and fiddle and banjo tunes. There is not one song from the radio. GuitarTuna has 20,000+, Yousician thousands, JustinGuitar 1,500+, Fender Play 1,000+.
- **A teacher you can see.** All 8 planned technique clips are still unshot, and "Show me" is still dots without a hand.

**New seams the new features opened:**
- The per-stroke judge marks a correctly played ukulele *chunk* or mandolin *chop* as a **miss**.
- "Chords & words" and the band both play **one chord per bar**. That drops the half-bar changes in 157 of 330 strummed song arrangements.
- The ukulele songbook put *Rondo alla Turca* in C minor with Fm, Eb and Bb7, and broke its famous turn with an octave leap.
- The violin highway labels notes with guitar *fret* numbers.

**Verdict.** Timbre is #1 on the tuner, feedback, instrument breadth, price and free tier, and it is a credible #1 for ukulele and violin beginners. It is not yet the app a "learn guitar" searcher chooses over Simply, Yousician or Justin.

---

## 2. Round-15 checklist (JURY15-category.md), verified

| # | Round-15 item | Status | Evidence (this build) |
|---|---|---|---|
| 1 | Strumming graded on timing only | **Fixed, with two new defects** (items 2 and 3 below) | `RhythmStep.start()` builds `LessonAnalyzer(chords: false, strokes: checksChords, …, onStroke: judgeChord)` (`LessonSteps.swift:1747-1748`). `StrokeChords` reads each stroke's own 60–230 ms frame with a fresh recogniser (`StrokeChords.swift:16-24, 55-86`). Wrong chord: capped at OK and named "Am?". Silent down-stroke: miss (`LessonSteps.swift:1783-1800`). The chord is fed to the coach (`wrongChords`, `:1846-1850, 1865`). Your songs practice inherits it (`ChartPracticeView.swift:35-50`). |
| 2 | Recognisable songs; inflated count | **Count mostly fixed; songs not fixed** | The paywall now counts titles: "140+ songs" (`PaywallView.swift:533-540`, frame 06). But the 144 titles include "Greensleeves: the chords", "Greensleeves: the melody", "Oh! Susanna: the verse", "Ode to Joy on bass", "Your arrangement" and "Walking the blues in A". That is about **134 distinct tunes**. The 20 new standards are 9 carols and hymns, 4 parlour songs, *Jupiter*, *Spring*, *Rondo alla Turca*, *Stars and Stripes*, *The Liberty Bell*, *Carmen* and *Morning Mood*. Correct, but not what a 25-year-old asks for. Swing Low, Home on the Range, Wayfaring Stranger and Hava Nagila were all declined in `PUBLIC-DOMAIN-CLEARANCE.md:88-131`, which is legally careful. |
| 3 | Ukulele Songs tab had 12 songs | **Fixed** | The ukulele chip now has 118 distinct songs (`ukulele-songbook`, 107 lessons in 25 units), and mandolin and violin 75 each. Quality problems are in item 4 below. |
| 4 | Physical technique text-only | **Not fixed** (plumbing only) | `LessonVisual.clip` and `LessonClipView` exist (`Curriculum.swift:256-258`, `LessonClip.swift:13-27`). `build.py --clips` lists 8 clips "to shoot" and 0 bundled. No lesson uses `clip`, so 357 explain steps still have `visual: none`. `ShowMeHandRig` is a protocol with no rig (`ShowMeScene.swift:206-209`; frame 51b shows pads, not a hand). |
| 5 | "Every string rings" ticked unheard strings | **Fixed** (honestly limited by physics) | `heardStrum` runs `PolyTuner` on the chord's strings. A string that is clear of the other strings' harmonics and silent is named, with a finger-specific tip (`LessonSteps.swift:824-871`, `ChordRing.swift:26-45`). Strings that share a harmonic (on Em, strings 4, 2 and 1) are still vouched for by the chord reading. |
| 6 | Left-handed stops at the tuner | **Fixed** | Handedness is now read in 13 files: Diagrams, Highway, PlayerNeck, ShowMe, Scales, the stage and onboarding. `ChordDiagram` follows `CurrentHand` by default (`Diagrams.swift:531-538`). There is also an upside-down mode (`LocalStore.swift:93-101`). |
| 7 | Free tier stingier than free tuners | **Fixed** | `FreeTier.swift:3-38`: open chords with Check, capo, quarters, eighths and triplets, click and wood sounds, 1 custom tuning, 10 charts. `AccessPolicy.canTune` makes every instrument's standard tuning free, and the 5 free instruments get every preset (`Access.swift:39-55`). The paywall table still contradicts this (item 6 below). |
| 8 | Guitar had 6 tunings | **Fixed** | Guitar 24, bass 7 (BEAD, 5-string, drop C), ukulele 5 (low G, D, slack-key), violin 5 (cross-tunings), banjo 4. 132 in total, all `VERIFIED` in `catalog.json`. That is on par with Fender Tune's 26 alternates, and all guitar presets are free (GuitarTuna paywalls them). |
| 9 | No "Chords & words" mode | **Added, but one chord per bar** | `SongChordsTake` (`SongChords.swift:26-260`) plus `ChordAlongJudge` (`PlayAlongSession.swift:228-300`). It judges the first stroke of each bar against `chartChords`, which is the downbeat chord only (`SongPerform.swift:111-116`, `SongSheet.swift:746`). See item 3 below. |
| 10 | Capo lessons drew no capo | **Fixed** | 49 capo chord specs. The box draws the capo in place of the nut, numbers fingers from it and captions "G shape · capo 2" (`Diagrams.swift:506-613`). I checked gtr-16-6's E (`xx2454`, capo 2, fingers from the capo). |
| 11 | Banjo D7 without its third | **Fixed** | bjo-3-2 names the two-finger D7 honestly and adds the full `x0214` (D A C F♯). `ChordRecognizer.matches` now accepts a heard subset with the right root in the bass (`ChordRecognizer.swift:80-82`). |
| 12 | Accuracy proven only on synthetic signals | **Harness only** | `RealWorldAccuracyTests.swift` and budgets exist, but `Tests/Fixtures/RealWorld/expected.json` has `"clips": []`. Still no real-world evidence. |
| 13 | Wrong "Hear it" timbres (ukulele, mandolin, banjo) | **Not fixed** (owner) | `AUDIO-SOURCES.md:41-48`: the ukulele is still classical-guitar samples, the mandolin a Martin HD-28, and the banjo synthesized. |
| 14 | Short free lesson runway | **Not changed** | Still the first unit only (`FreeTier.swift:11`; guitar has 5 free lessons, about 20 min). The onboarding now gives a first chord before the paywall (05c), which helps. |

---

## 3. Head-to-head on my angle

### Scoreboard: #1 per user-facing dimension today

| Dimension | #1 today | Timbre | Evidence |
|---|---|---|---|
| Tuner accuracy and UX | **Timbre** | #1 | Strum-to-tune with an honest "≈ estimate" (11b). Peg cues on 3D and photo rigs (10, 17, 49b). "Pluck all" on bowed instruments. Tune by feel, a haptic beat that slows to the lock (`SettingsView.swift:355-359`). 60 instruments. No competitor has polyphonic tuning. |
| Instruments and tunings | **Timbre** | #1 | 60 instruments and 132 tunings, against GuitarTuna's 15 instruments and Fender Tune's 26 guitar alternates. |
| Feedback while playing | **Timbre, narrowly, over Yousician** | #1 | Notes judged in cents and ms. Chords judged per stroke. The silent string named with its fix: no one else does that. JustinGuitar 3.27.3 now "detect[s] strums and chord changes more reliably" with a ring per chord. Yousician judges chords in thousands of real songs. Timbre loses points on chunks and chops (item 2) and on half-bar changes (item 3). |
| Lesson pedagogy and correctness | **JustinGuitar** | #2 | Timbre's content is flawless on my checks, and the sequencing (CAGED, triads, ii–V–I, modes, song spotlights in every unit) is a real curriculum. Justin has 210 filmed lessons and a human face. Timbre's technique is still words and dots. |
| Song catalogue | **GuitarTuna / UG** (count), **Yousician / Simply** (play-along to hits) | last | 134 distinct public-domain or house tunes. There is no licensed song. |
| Practice tools | **Fender Tune** (library depth, free), **Timbre** (range) | #2 | Timbre: strobe, drone/tanpura, intonation, ear games, Bullseye, a metronome with a trainer, Your songs. But only 14 chord qualities and 8 scales (`Chords.swift:11-26, 329-338`), and no drum grooves. Fender Tune gives 5,000+ chords, 2,000+ scales and 65 rhythms free. |
| Motivation | **Timbre ≈ Yousician** | #1 (tie) | XP, quests, streak freezes, badges, a coach with chord-change and wrong-chord notes, week recap, Game Center, widgets and a Live Activity. |
| Price and value | **Timbre** | #1 | $34.99/yr, $6.99/mo or $89.99 lifetime, with a 14-day trial and a day-12 reminder (06, 40). Yousician One Instrument $119.99, Premium+ $139.99–$179.99. Simply $119.99–$199.99. Fender Play up to $149.99. Justin $64.99–$129.99. GuitarTuna Learn $139.99 (Play $39.99). |
| Free tier | **Timbre ≈ Fender Tune** | #1 (tie) | Timbre free: 60-instrument tuner, all guitar, bass, ukulele, violin and cello presets, strum-to-tune, open chords with a microphone Check, the first unit of every course, a shelf of songs. Fender Tune free: 5,000 chords, 2,000 scales, drums. GuitarTuna free: standard tunings only, with ads. |
| Trust and social proof | everyone else | last | 0 ratings. Competitors sit at 4.6–4.8 with 27K–481K. |

### Timbre vs GuitarTuna (4.8★, 149K; Play $39.99/yr, Learn $139.99/yr; free with ads)

| Area | Winner | Why |
|---|---|---|
| Tuner, tunings, free tier | **Timbre, clearly** | Polyphonic strum-to-tune and 60 instruments against 15. All 24 guitar presets free (GuitarTuna gates alternates: reviewers report drop tunings need a subscription). No ads. |
| Feedback | **Timbre** | GuitarTuna's games are chord-change trainers. Timbre judges every stroke and names the dead string. |
| Songs | **GuitarTuna, decisively** | 20,000+ songs with chords and tabs, and new licensed songs in recent release notes. |

**Why a beginner picks Timbre over it today:** if they came for a tuner, or play ukulele or violin. Timbre is the better tuner, free, ad-free, and it then teaches. A "chords for the song I just heard" beginner still installs GuitarTuna.

### Timbre vs Fender Tune (4.8★, 152K; free) and Fender Play (4.8★, 61K; up to $149.99/yr)

| Area | Winner | Why |
|---|---|---|
| Fender Tune: tuning | **Timbre** | Better auto tuner, polyphonic strum-to-tune, 60 instruments, guitar presets at parity (24 against 26 + custom). |
| Fender Tune: free library | **Fender Tune** | Its free chord, scale and drum library is still far deeper: 5,000+ chords, 2,000+ scales and 65 drum rhythms, against 14 chord qualities, 8 scales (scales are Pro) and no drums. |
| Fender Play: teaching media and songs | **Fender Play** | 3,000+ filmed lessons from instructors, 1,000+ licensed songs. |
| Fender Play: feedback, breadth, price | **Timbre** | Fender's MatchMySound scoring is lesson-level. Timbre judges every note and stroke. Fender covers guitar, bass and ukulele only. Timbre costs about a quarter of the list price. |

**Why a beginner picks Timbre over them today:**
- Over Fender Tune: for a better free tuner that also teaches.
- Over Fender Play: for price, for real-time feedback, or for an instrument Fender doesn't teach (violin, cello, mandolin, banjo, voice).

A returning adult who wants Fender's video teacher and "Wonderwall" picks Fender Play.

### Timbre vs Yousician (4.6★, 139K; One Instrument $119.99/yr, Premium+ $139.99–$179.99)

| Area | Winner | Why |
|---|---|---|
| Feedback depth | **Timbre** | Per-stroke chord judging, dead-string naming, a cents-aware highway with a tempo ladder, and latency calibration. |
| Feedback at scale, on real songs | **Yousician** | Its recognition is proven at scale on real songs, and its catalogue includes hits. |
| Breadth and price | **Timbre** | Violin, cello, mandolin, banjo and ukulele with a microphone, against Yousician's guitar, bass and singing. About a quarter of the price. |

**Why a beginner picks Timbre over it today:** a ukulele or violin player, anyone on a budget, or anyone who dislikes Yousician's game-show pace. A guitarist who wants to play along to hits stays with Yousician.

### Timbre vs Simply Guitar (4.7★, 400K; $119.99–$199.99; guitar only)

| Area | Winner | Why |
|---|---|---|
| The first week | **Simply** | A filmed teacher, famous songs in days, and trusted chord checking. |
| Feedback specifics, depth, breadth, price | **Timbre** | Simply says *that* a chord was wrong. Timbre says *which* string and which finger. Timbre continues past where Simply's reviews say it stops (barre chords, CAGED, triads, jazz voicings, modes). It covers six more instruments, has a far better tuner, and costs about a third. |

**Why a beginner picks Timbre over it today:** price, a non-guitar instrument, or a tuner-first install. On the store page, with a famous song and a face, Simply still wins the total beginner.

### Timbre vs JustinGuitar (4.8★, 27K; app $64.99–$129.99/yr; web lessons free)

| Area | Winner | Why |
|---|---|---|
| Pedagogy and trust | **Justin** | 210 video lessons and 36 h, a human voice, 1,500+ songs, and now chord-change detection (3.25.0 and 3.27.3). |
| Listening | **Timbre** | Timbre's guitar path follows the same proven order. It listens to every step, names dead strings, and covers ukulele, violin and five more instruments Justin doesn't teach in the app. |

**Why a beginner picks Timbre over it today:** a ukulele or violin student, or a guitarist who wants to be *heard* (not just watch) at half Justin's top price. For guitar pedagogy, Justin is still #1.

### Timbre vs Ultimate Guitar (4.7★, 481K; Pro $39.99–$59.99/yr)

- **UG wins songs:** 29K+ Pro tabs with backing tracks.
- **Timbre's answer is "Your songs":** paste a chord sheet, and Timbre now listens to each strum of it. 10 charts are free. But it practises only the drill and the opening bars (`ChartPracticeView.swift:35-50`), with no full-song "Chords & words" take on a pasted chart.

---

## 4. Everything that costs points, ranked

**1. BLOCKER (category) · L (owner) + M (code) · No song an ordinary person would ask for.**
- **Where:** screens 63, 64, 06, ipad-portrait-songs; `SongOfTheDay.swift:3-5, 105-108` (Originals and Standards lead); `PUBLIC-DOMAIN-CLEARANCE.md:108-134` (the requested PD songs are excluded, correctly).
- **What is wrong:**
  - 134 distinct tunes: 50 Originals, 20 carols and hymns, about 22 classical themes, about 12 children's songs, fiddle and banjo tunes, and *Jupiter* and *Stars and Stripes*. Nothing from the radio.
  - The Songs tab opens on an unknown Original (*First Frost*, then *Dust on the Dashboard* and *Lantern Hill*).
  - The careful PD policy means the public-domain route can no longer reach the songs people know. Only licensing can.
- **Fix:**
  - Owner: license a starter pack (section 6).
  - **Code, now:**
    - Add a "Songs you know" shelf above everything, of the most recognised tunes (Canon in D, Für Elise, Ode to Joy, Greensleeves, Amazing Grace, Jingle Bells, Silent Night, Danny Boy, The Entertainer, Can-can, In the Hall of the Mountain King).
    - Make Song of the Day pick from that shelf until the learner has played three of them.
  - Replace the course subtitle "Play real melodies, start to finish" (`Learn.strings:4781`) with "Play the melody or strum the chords and sing". "Chords & words" exists and the header hides it.

**2. MAJOR · S · The new per-stroke judge marks a correct chunk, chop or mute as a MISS.**
- **Where:** `LessonSteps.swift:1783-1800`. `judgeChord`: `if heard == nil && down { grades[index] = .miss }`, where "down" means any whole-beat stroke. Affected lessons:
  - uke-8-1 "The chunk": strum steps on C and F with pattern `[0,1,2,2.5,3]`, chunks on 1 and 3;
  - uke-8-2 "Island strum with a chunk";
  - uke-8-6;
  - man-4-4 "The chop", man-4-5, man-4-6 and man-6-5 (pattern `[1,3]`, choked chords);
  - gtr-15-3 "Reggae: the offbeat chop";
  - Originals *Low Tide Radio* and *Saltwater Sunday*.
- **What is wrong:**
  - The lesson teaches "a strum that stops dead … a short, dry click".
  - `StrokeChords` reads 60–230 ms after the onset (`StrokeChords.swift:16-20`), and a chunk has no chord there by design.
  - So a perfect chunk on beats 2 and 4 is a *miss*. uke-8-1's best possible take scores 3/5 = 60 %, plays the "wrong" sound (`score >= 0.7`, `:1856-1860`) and loses stars. **A correct take is graded as a failed one.** Continue still works (`:1474-1478`).
  - The mandolin chop is choked within about 100 ms, so it will mostly read nil.
  - On man-4-4 (`[1,3]`, both chops), a correct take scores 0 %. `chordsMostlyWrong` then caps it at 1 star (`:1179-1182`, `:1477`).
  - The app rewards letting the chop ring, which is the fault the lesson's own quiz warns about ("Your chop keeps ringing. What fixes it?").
- **Fix:**
  - Add `muted: [Double]` (pattern beats that are chunks, chops or scratches) to `strum`/`progression` steps in `tools/curriculum/lib.py` and to the step model.
  - In `judgeChord`, a muted beat passes when `heard == nil` or when the reading is short. Optionally check that the RMS 150 ms after the onset is below 30 % of the attack.
  - Draw muted beats as an "×" chip in `LessonBeatRow`.
  - Add a real-recording clip of each technique to the corpus.

**3. MAJOR · M · "Chords & words" and the band play one chord per bar, dropping the half-bar changes in 157 of 330 strummed song arrangements.**
- **Where:**
  - `SongSheet.swift:746` (`LeadChart.chords`: "the chord on each bar's downbeat") and `:964-974` (`filledChords`);
  - `SongPerform.swift:104-116` (`band` and `chartChords`);
  - `Band.swift:11-13` (`Bar` holds one `root`);
  - `PlayAlongSession.swift:278-285` (`ChordAlongJudge.stroke`: one stroke per bar);
  - `SongChords.swift:132` (`ChordLane(chords:)` per bar).
- **What is wrong:**
  - **Wrong harmonic rhythm.** In "Chords & words" the learner strums the wrong harmonic rhythm. Twinkle (songs course) changes chord 34 times mid-bar in 42 bars ("C G | D G"). Timbre shows and judges "C | D".
  - **Wrong band harmony in both modes.** Under the melody take *and* the chords take, the band holds the downbeat chord under the second half. In bar 1 of Twinkle it sustains D under the melody's G. The hymns and carols have 30–37 mid-bar changes each.
  - **The data already has the changes.** `LeadChart` holds "every change of chord in playing order" (`SongSheet.swift:747-749`); the take and the band throw it away.
- **Fix:**
  - Make `BandArrangement.Bar` carry `segments: [(beat: Double, root: Int?, tones: [Int])]` and render each segment in `BandSynth`.
  - Make `ChordAlongJudge` judge *changes*, not bars: slot `i` sits at `changes[i].beat`, with the stroke window ±0.15 s around it.
  - In `ChordLane`, show a split bar ("C · G") with the beat ticks under each half.
  - Add a test that, for every song, `band.segments` equals `arrangement.chords`.

**4. MAJOR · M · The ukulele songbook's key choice and octave folding break some tunes.**
- **Where:** `tools/curriculum/editions.py`:
  - `:151-156` (`tonic` reads the key from the **last** chord);
  - `:78-79` (`UKULELE_KEYS`);
  - `:236-256` (`best_plan`; the guard at `:252` allows 3 % folded notes);
  - `:158-163` (`spell` uses sharp names in G).
- **What is wrong:**
  - **Rondo alla Turca** ends in A major, so its uke edition is moved to C. That puts the A-minor theme in **C minor**, with Cm, Fm, Eb and Bb7, the four hardest common ukulele shapes. Its famous turn "B A G♯ A C" becomes "D4 C4 **B4** C4 E♭4", a major-seventh leap where the source moves by a step (uke-sb-std-rondo-alla-turca, notes 12–16).
  - **Carmen: Prelude** on ukulele moves A→G and spells its E♭ section "**D#**" (bars 16–27; chords `D#`, `Fm`, `Bb7`).
  - **37 of 107** ukulele arrangements contain isolated notes moved by an octave. Scotland the Brave has 8 new leaps of a seventh or more, and the Rondo has 10. Mandolin and violin editions move whole phrases only, which is fine.
- **Fix:**
  - Read the tonic from the first section's chords, or the most-bars key, not the last chord.
  - Add a per-instrument chord-difficulty cost: on ukulele, Eb, Fm, Cm, Bb7, F♯m and Db each cost about 2. Keep Am as an option for minor pieces.
  - Spell chords by function. A ♭VI or ♭III in a sharp key is flat: in G major, E♭ not D♯.
  - Reject a plan when any folded note turns a source step of 2 semitones or less into a leap of 10 or more.
  - Offer a **low-G edition** (`ukulele.soprano.4.low_g` already exists) when folding is needed.

**5. MAJOR · S · The violin and cello highway shows guitar fret numbers.**
- **Where:** `Highway.swift:1149` (`label`: `note.at.map { "\($0.fret)" }`); screen 65b, the violin Custom Product Page's frame #2.
- **What is wrong:**
  - F♯ on the E string is drawn as a big **"2"** with a small finger badge "1".
  - Every violin and cello method numbers fingers, not semitones, so a beginner reading "2" puts down finger 2: a wrong note, taught by the store frame.
  - On cello, fret 2/4/5 → fingers 1/3/4, the same confusion.
- **Fix:** for fretless `fretKind` (violin, viola, cello, double bass):
  - make the tile's big glyph the finger number (`at.finger`, "0" for open);
  - mark low and high positions with a small arrow ("↓2" low 2, "2" high 2);
  - put the note name under it, and drop the semitone number.
  - Keep fret numbers on fretted instruments.

**6. MAJOR · S · The paywall's Free/Pro table contradicts the free tier.**
- **Where:** `PaywallView.swift:706-724`. The rows "Chords, scales, intonation and drone: Free ✗", "Strobe, temperaments and custom tunings: Free ✗" and "Alternate tunings for every instrument: Free ✗" conflict with:
  - `FreeTier.swift:5-11` (open chords with Check and one custom tuning are free);
  - `PracticeView.swift:579` (the Chords tool is `pro: false`);
  - `Access.swift:44-55` (every preset of guitar, bass, ukulele, violin and cello is free).

  The comment at `:721` still says "three charts free" (the limit is 10).
- **What is wrong:** it undersells exactly what the team just made free, the thing that beats GuitarTuna. A reviewer comparing tables will report "chords are Pro".
- **Fix:** rows should read:
  - "Open chords with Check": ✓ / ✓
  - "Barre and movable chords, scales, intonation, drone": ✗ / ✓
  - "Custom tunings": 1 / unlimited
  - "Alternate tunings": "guitar, bass, ukulele, violin, cello" / "all 60"
  - "Strobe and temperaments": ✗ / ✓

**7. MAJOR · M (owner) · Physical technique is still words and dots.**
- **Where:**
  - 357 explain steps with `visual: none`;
  - `lib.py:170-197` (8 `PLANNED_CLIPS`, 0 bundled);
  - `LessonClip.swift:13-27` (renders nothing without media);
  - `ShowMeScene.swift:206-209` (no `ShowMeHandRig`);
  - frames 51b and 52b.
- **What is wrong:** the bow hold, the violin hold, cello posture, the pick grip, palm muting, p-i-m-a, the F barre and bends are taught in text. Every lesson competitor shows a hand.
- **Fix:**
  - Owner: shoot the 8 listed clips first, then about 30 more.
  - Code, until then: a 3-photo stepper per clip name (the `LessonClip.hasPhoto` path exists) from a single phone shoot.

**8. MAJOR · S · The store and listing undersell the new feedback.**
- **Where:**
  - `APP-STORE-LISTING.md:9` still instructs "No 'whole chords' for strumming until the strum steps judge the chord", and `:102` says only "the timing of your strumming".
  - No store frame or preview beat shows a wrong-chord call ("Am?") or "String 3 isn't ringing". `preview/PREVIEW.txt`: lock, tuned, showme, highway, results, songs.
- **What is wrong:** the one feedback feature no competitor has is invisible on the store.
- **Fix:**
  - Listing: "Timbre hears every strum: the right chord, on time, and which string didn't ring."
  - Replace store frame #3 (52b, every string ticked) with a capture of the dead-string tip on a C chord.
  - Add a 2 s "Am?" amber beat to the preview after "Show me".

**9. MINOR · S · Cello (7 songs), banjo (6) and bass (2) have tiny song shelves.**
- **Where:** a distinct-title count per instrument chip.
- **What is wrong:** `APP-STORE-LISTING.md:242, 246` sells cello and banjo Custom Product Pages.
- **Fix:**
  - Run `songbook.py` for cello (C-G-D-A, bass clef, first and fourth positions). Most of the 66 violin-songbook tunes fit an octave and a fifth lower.
  - Make a bass "root-and-fifth" edition from every chord chart.

**10. MINOR · S · "140+ songs" is about 134.**
- **Where:** `PaywallView.swift:533-540` counts raw titles.
- **What is wrong:** "Greensleeves: the chords", "…: the melody" and "Greensleeves" count 3. "Oh! Susanna" variants count 3. "Ode to Joy on bass", "Twinkle Twinkle Little Star" (voice, no commas), "Amazing Grace, fingerpicked", and the exercises "Your arrangement" and "Walking the blues in A" each count too.
- **Fix:** normalise titles (strip `: …`, `, fingerpicked`, ` on bass`, punctuation), exclude exercise songs, and print "130+" until the count passes 140.

**11. MINOR · M · The practice library is thin next to Fender Tune's free one.**
- **Where:** `Chords.swift:11-26` (14 qualities: no dim7, m7♭5, 7sus4, 13, maj9, m9, 6/9 or slash chords); `Chords.swift:329-338` (8 scales); `PracticeView.swift:580` (Scales is Pro); no drum grooves in the metronome (22).
- **Fix:**
  - Add dim7, m7♭5, 7sus4, 6/9, 9, maj9, m9, 11 and 13, plus slash chords with the bass on strings 6 and 5.
  - Add harmonic and melodic minor modes, Lydian, Phrygian, whole-tone and diminished.
  - Make the major, minor and pentatonic scales free.
  - Add 12 drum grooves from `BandSynth` to the metronome (rock, pop, shuffle, waltz, 6/8, bossa, reggae, funk, country train, ballad, march, swing).

**12. MINOR · S · The recogniser knows 8 qualities, so 9ths, 6ths, add9, dim and aug strokes go unchecked.**
- **Where:** `ChordRecognizer.swift:99` (`major, minor, dominant7, major7, minor7, sus2, sus4, power`); `LessonSteps.swift:1148-1156` (`checksChords` is false when `target` is nil). For example, gtr-15-2's E9 and D9.
- **Fix:** add templates for 6, m6, 9, add9, dim, dim7 and aug. Until then, judge a 9 or 6 chord against its triad (E9 → E7).

**13. MINOR · S · The "Accents in 3-3-2" step can't hear accents.**
- **Where:** uke-8-4 (all 8 eighths strummed; graded only on timing and chord).
- **Fix:** in `StrokeChords`, return each stroke's peak RMS. On steps with `accents: [beats]`, require the accented strokes to be at least 4 dB above the median, and show "Push the and of 2" when not.

**14. MINOR · S · Store frames 07 and 17 show the Live Activity drawn over the status bar.**
- **Where:** frame 17 is the ukulele Custom Product Page's lead frame (`APP-STORE-LISTING.md:243`): "9:41" covered by the tuner glyph, "+5 XP" over the signal bars.
- **Fix:** end the practice activity before store captures (`LiveActivityController`), or recapture.

**15. MINOR (owner) · "Hear it" timbres.**
- The ukulele is classical-guitar samples, the mandolin a steel guitar, and the banjo synthesized (`AUDIO-SOURCES.md:41-48`). A ukulele teacher hears it in one note.

**16. MINOR (owner) · Real-world accuracy remains unproven.**
- `Tests/Fixtures/RealWorld/expected.json` has `"clips": []`.

---

## 5. How to take #1 on my angle (ranked by impact)

1. **Songs people know, now and later.**
   - (a) **Owner: license 30–100 hits** (section 6). It is the single move that changes what a "learn guitar" searcher picks.
   - (b) **This week:** a "Songs you know" shelf first, Song of the Day from it, and the Songs header saying you can strum and sing (item 1).
   - (c) Make **Your songs** the headline answer to "can I play *my* song?" Add a full-song "Chords & words" take on any pasted chart, with the new per-stroke judge and the band following the chart. With 10 free charts, that is UG's catalogue with Timbre's ears.
2. **Make the new feedback flawless, then show it.**
   - Muted strokes (item 2) and half-bar changes (item 3) must be right. A teacher will find both in the first week.
   - Then put "String 3 isn't ringing: arch finger 2" and the "Am?" call in store frame #3 and in the preview (item 8).
   - This is the only feedback claim no competitor can match.
3. **A teacher you can see.** Shoot the 8 planned clips (bow hold first: no competitor has listening violin lessons), then 30 more. Plug a stylised hand into `ShowMeHandRig`. Video plus listening beats video alone (Fender, Justin) and listening alone (Yousician).
4. **Own ukulele and violin outright** (the listing's subtitle bet).
   - Fix the ukulele songbook's keys, spellings and folds, and add low-G editions (item 4).
   - Violin finger labels on the highway (item 5).
   - Real ukulele and mandolin samples (owner).
   - A cello songbook (item 9).
   - Then Timbre is the clear #1 app for those two searches, where Yousician, Simply and Fender have nothing.
5. **Win "best free practice app", not just "best free tuner".**
   - Correct the paywall table (item 6).
   - Free basic scales and 12 drum grooves (item 11).
   - With the current free tuner, that is strictly more than Fender Tune for free, which is the funnel the $34.99 plan converts.
6. **Prove accuracy.** Fill the real-world corpus (the harness is ready) and publish "tested on N real strums on M phones" next to GuitarTuna and Fender Tune on the same clips.
7. **Price anchor on the paywall.** "Lessons that listen, for a quarter of the big lesson apps" is now literally true: $34.99 against Yousician's $119.99 and Fender Play's $149.99.

---

## 6. What only the owner can do

- **Song licensing:**
  - 30–100 recognisable songs (print, sync and mechanical through Hal Leonard, Musicnotes or Songtradr-style deals, or indie artists who want exposure).
  - Budget roughly $15–60k in advances plus revenue share.
  - Start with the songs every teacher uses in month one: Knockin' on Heaven's Door, Horse with No Name, Riptide, Wonderwall, Let It Be, Stand by Me, Hallelujah, Brown Eyed Girl, Three Little Birds, Somewhere Over the Rainbow (Kamakawiwoʻole arrangement for ukulele).
- **Teacher video:** one guitar, one ukulele and one violin/cello teacher for the 8 planned clips and about 30 more, plus short unit intros. Two shoot days, about $8–15k.
- **Recordings:**
  - soprano and low-G ukulele, mandolin and 5-string banjo sample sets (about 30 notes each, two velocities);
  - full-band stems for the 10 strongest Originals;
  - real chunk, chop and mute strokes for the corpus.
- **3D:** a stylised rigged hand for "Show me", and ukulele and banjo `usdz` models.
- **The real-world corpus:** about 1,000 labelled notes, strums, chords and muted-string strums across 20 instruments and several iPhones and rooms. This fills `Tests/Fixtures/RealWorld/`.
- **Social proof:** a TestFlight cohort of about 200, endorsements from a ukulele teacher and a violin teacher, and early ratings before launch.
- **Policy calls:**
  - whether the free tier opens unit 2 (Ode to Joy and the first song spotlight);
  - a $99.99 lifetime test;
  - whether to lead the US listing with Mueller ("Away in a Manger", US) rather than Kirkpatrick (UK), as *O Little Town* already uses the US St Louis tune.

---

## 7. Sources

- [GuitarTuna on the US App Store](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): 4.8★, 149K ratings, version 7.104.0, 20,000+ songs, 15 instruments, left-hand mode.
- [App Pricing Lab: GuitarTuna IAPs](https://apppricinglab.com/iap/apple/527588389): Play $39.99/yr, Tools $29.99/yr, Learn $139.99/yr (checked 2026-03-21).
- [Fender Tune on the App Store](https://apps.apple.com/app/id1107017950): 4.8★, 152K, version 4.17.0 (iOS 27 redesign), 26 alternate tunings, 5,000+ chords, 2,000+ scales, 65 drum rhythms, free.
- [Fender Play on the US App Store](https://apps.apple.com/us/app/fender-play-learn-guitar/id1226057939): 4.8★, 61K, version 8.0.2, 3,000+ lessons, 1,000+ songs, MatchMySound feedback, guitar, bass and ukulele.
- [App Pricing Lab: Fender Play IAPs](https://apppricinglab.com/iap/apple/1226057939): $44.99–$149.99 annual (checked 2026-04-14).
- [Yousician on the US App Store](https://apps.apple.com/us/app/yousician-learn-guitar-piano/id959883039): 4.6★, 139K, version 5.41.0, 10,000+ lessons and exercises, guitar, bass and singing.
- [App Pricing Lab: Yousician IAPs](https://apppricinglab.com/iap/apple/959883039): One Instrument $119.99/yr, Premium Plus $139.99–$179.99/yr (checked 2026-04-03).
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): 4.7★, 400K, version 10.31, guitar only, IAPs $19.99–$199.99.
- [JustinGuitar Lessons & Songs on the App Store](https://apps.apple.com/app/id1176125504): 4.8★, 27K, version 3.27.3 ("chord exercises detect strums and chord changes more reliably"), 3.25.0 chord detection in Perfect Fast Changes, 1,500+ songs, 210 video lessons, $64.99–$129.99.
- [JustinGuitar Community: chord detection issues](https://community.justinguitar.com/t/chord-detection-issues/397102): user reports on the app's chord detection.
- [Ultimate Guitar on the US App Store](https://apps.apple.com/us/app/ultimate-guitar-chords-tabs/id357828853): 4.7★, 481K, 29K+ Pro tabs with backing tracks, UG Courses with 2,500+ lessons, Pro $39.99–$59.99/yr.
- [flutetunes: It Came Upon the Midnight Clear](https://www.flutetunes.com/tunes.php?id=300): Willis's melody in 6/8. Its third note was originally C (in B♭), sung a third lower in later hymnals. That matches Timbre's G–E–B–D opening in C.
