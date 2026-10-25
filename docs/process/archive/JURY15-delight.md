# JURY 15: Delight & Fun / Innovation (juror: "delight")

I am the creative director on the panel. I judge the moments people talk about later, the ones that make someone turn the phone to a friend. I checked every claim below myself: the 65 iPhone frames, the iPad frames, the 29 s App Preview (re-extracted frame by frame with ffmpeg, plus an audio level measurement) and the code.

---

## 1. Score: **8.3 / 10**

**Verdict.** Under the hood this is the best-crafted tuner in the category, and in places the most inventive one:
- The peg on the 3D headstock turns in proportion to the measured pitch error and settles home in tune (InstrumentStage.swift:579-597).
- The string carries a slow standing wave whose strobe ripple drifts with the cents and freezes on the lock (:616-626).
- A Metal comet runs down the string when it locks (Shaders.metal:43).
- The lock bell rings at the pitch of the string just tuned (SoundFX.swift:36-45).
- The UI sounds are Karplus–Strong plucks in a Freeverb room, not stock bleeps.
- A strobe disc behaves as a liquid surface, a tanpura's Sa and Pa strings vibrate, and a coach says "Your G string drifts 7¢ flat a day. Time for new strings" (32, CoachVoice.swift:66).

I have never seen a music app do that last one.

Four failures keep it out of ADA range on my angle:
- **The haptic design is very likely switched off by iOS** exactly where it matters. The microphone is always recording, and `allowHapticsAndSystemSoundsDuringRecording` is never set.
- **The App Preview shows none of the signature moments.** It is silent. Its poster frame is a double exposure. It never shows a string lock. The celebration appears for about 0.1 s inside a fade, the "chord" clip shows the wrong step, and it ends on 9 static seconds of Songs with the status bar printed over a title.
- **The fun loop has no band.** On the speaker every play-along is a bare click. Even in headphones, a song "with the band" is drums plus one bass note held through the whole song.
- **Every reward is a template:** three SF Symbol stars with "Great work", Duolingo's flame screen, and the same 22-dot burst everywhere.

The craft is a 9. The delight that actually reaches a user, or an App Store visitor, today is an 8.

---

## 2. Head-to-head on Delight & Fun / Innovation

| Competitor | Who wins my angle | Why (evidence) |
|---|---|---|
| **GuitarTuna** (4.8★, 149K ratings; chord games, tabs for 20,000+ songs, video tutorials; *contains ads*) | **Timbre, narrowly** | Timbre's tuning moment is in another league: the 3D headstock with a turning peg, a pitched lock bell, the lock comet, per-cent haptic detents (if enabled, see #1) and strum-to-tune that names the string to fix first (11b). GuitarTuna's tuner is a needle and a ping. GuitarTuna wins on game *breadth* (several chord games against Timbre's Bullseye and ear trainer) and on hearing songs people know. Its ads cost it delight. |
| **Fender Tune** | **Timbre, clearly** | Fender Tune is a utility. Nothing in it is a "moment". |
| **Fender Play** (4K multi-camera video, thousands of artist songs, Feedback Mode with high scores, backing tracks; $149.99/yr) | **Split: Timbre on fun and novelty, Fender on warmth** | Timbre's highway (65), combo tiers, the bar loop from a missed note and the 3D "Show me" are more interactive than anything in Fender Play. Fender's real teachers and real songs with a real band are the warmth Timbre lacks. Timbre's "teacher" is fingertip dots with no hand (51b), and its band is a tonic drone (#3). |
| **Yousician** (4.6★/139K, Editors' Choice, Apps We Love; licensed library, weekly Challenges, backing synced to tab) | **Yousician on Fun, Timbre on Innovation** | Yousician's fun *is* the song: a recorded backing track out of the speaker while you play. Timbre's highway looks better (60, 65), with a ×1–×4 multiplier that warms the board, Perfect/Early/Late pops and lyrics karaoke. But on a phone speaker it plays only a click (AudioService.swift:544), and the "Kite Weather" performance plays one bass note for 228 notes. Yousician also renews the fun weekly (Challenges); Timbre has daily quests but no new-content cadence. |
| **Simply Guitar** (4.7★/~400K, Editors' Choice; Queen, Aretha, Billie Eilish; video lessons) | **Simply on Fun, Timbre on craft and Innovation** | Recognition is delight: strumming "We Will Rock You" beats strumming "Porchlight". Timbre's Originals have beautiful generative sleeves (63) but no recognition value. Timbre wins every craft and motion comparison. |
| **JustinGuitar** (4.9★/22K; 210 videos with Justin, 1,500 songs, full-band song player) | **Justin on personality, Timbre on game feel and Innovation** | Justin *is* the brand voice. Timbre's voice is precise and well-mannered, but it says "Great work" at six of its peak moments (#9). JustinGuitar's full-band player is the band experience Timbre's speaker users never get. |

**ADA context.** In 2025 the Innovation (game) winner was *PBJ – The Musical*, cited for rhythm, soundtrack and haptics working together. Moises was an Innovation finalist. The 2026 Inclusivity winner was *Guitar Wiz*, a guitar toolkit. The jury rewards exactly the sound-and-haptic integration Timbre has built in code but does not let anyone feel or see.

---

## 3. Everything that costs points, ranked

### 1. Haptics are very likely muted whenever the tuner or a lesson is listening (blocker if confirmed on a device · S)
- **Where:** AudioService.swift:243-250 (`configureSession`: `.playAndRecord`, `.measurement`). There are zero occurrences of `setAllowHapticsAndSystemSoundsDuringRecording` in the repository.
- **What's wrong:** Apple's documentation for `allowHapticsAndSystemSoundsDuringRecording` gives its default as `false`: "system sounds and haptics" don't play while recording from input. Timbre fires all of its tuning feel while the input runs:
  - the per-cent detent inside ±5¢ (Haptics.swift:38-45, called at AppStore.swift:609);
  - the lock thump (AppStore.swift:618);
  - the highway's Perfect and tier-up taps (Highway.swift:713, 720);
  - Bullseye (PitchSniperView.swift:205-206);
  - the onboarding first lock (FirstTuneStep.swift:374).

  The simulator has no haptics, so CI can never catch this. The fallback `UIImpactFeedbackGenerator` is the first thing iOS suppresses.
- **Fix:**
  1. In `configureSession()`, right after `setCategory`, add `try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)`.
  2. Add a "Feel test" row under Settings → Diagnostics that fires `detent` and `lock` while listening.
  3. Check on an iPhone 15/16/17 with the tuner running.

### 2. The App Preview hides every signature moment (blocker · M)
- **Where:**
  - `review15/preview/preview.mp4`;
  - tools/marketing/preview.py:49 (`FADE_FRAMES = 10`), :502 (xfade), :509 (`anullsrc`), :520-526 and :638 (poster time);
  - TimbreUITests/AppPreviewUITests.swift:84-160 (tuner) and :200-255 (highway, results, songs).
- **What's wrong:**
  - **Silent.** I measured mean and max volume at -91 dB. A music app's preview without music forfeits its best argument, and anyone who unmutes hears nothing.
  - **The poster frame is a double exposure.** PREVIEW.txt sets it at 00:03.45, inside the 0.33 s cross-fade (clip 1 ends at 3.73, clip 2 starts at 3.40). The frame shows two headstocks, "E" over "B", and "Tighten" over "Hold it…".
  - **No string ever locks on camera.** The tune-lock clip ends at 91.43 s; the lock sync is at 91.47 s. Frames from 2.0 to 3.4 s show 0¢ and "Hold it…", never "✓ In tune" or the peg check. E4 in clip 2 also cuts away on "Hold it…".
  - **The celebration is visible for about 0.1 s**, at the start of a fade (≈7.0 s), with "Tighten · 11¢ flat" showing through behind "All strings in tune".
  - **The "chord" clip (7.7–11.3 s) shows the wrong step.** It is the *Strum down* explanation (Step 3 of 5) with a 2D pick sliding, not the chord heard with every string lit (52b). The 7.9–8.5 s frames mix "Listening…" and "Continue" mid-fade (t11).
  - **The highway clip uses the weakest content in the app.** It is the 6-note "Open-string roll call" at 60 BPM, combo 2, ×1. The store frame 65 (Kite Weather, combo 74, ×4, lyrics) exists as a store scene.
  - **No "Show me" 3D**, the most cinematic feature.
  - **The ending wastes the last third.** Songs sits static from 19.4 to 28.4 s, then the final frame scrolls the "Dust on the Dashboard" title under the status bar ("Da9:41shboa").
  - **AUTO flips to MANUAL on camera** from 3.4 s, because the test taps chips. It undercuts "auto string detection".
- **Fix (keep the 30 s budget):**

  | Time | Shot | What changes |
  |---|---|---|
  | 0–5 s | Drift → lock on the 3D headstock | Extend the clip 1.5 s past the lock sync so the shimmer, "✓ In tune" and the peg check play out. Hands off: select strings by playing them (demo pitch), not by tapping chips. |
  | 5–9 s | Last string → camera pull-back to the whole guitar | The `showWhole` dolly (TuneView.swift:98) plays with the card held back 1 s. Poster = the locked frame, chosen ≥ FADE away from any cut (clamp `poster_time` out of `[start−FADE, start]`). |
  | 9–13 s | "Show me" Em on the 3D neck | The `showMe` store scene. |
  | 13–21 s | Kite Weather highway at ×4 | The DemoScene perform from bar 16. |
  | 21–25 s | Results | Stars land. |
  | 25–28 s | Songs | Zoom into a sleeve. |
  | 28–30 s | End card | — |

  Audio: replace `anullsrc` with a mix rendered from the app's own deterministic synths (SoundSynth cues, lock bells at the tuned pitches, the band render for Kite Weather at the clip's bar). Originals are house-owned, so there is no licence issue.

### 3. Song performances play "with the band", but the band holds one note (major · S)
- **Where:**
  - SongPerform.swift:83-86 builds `band` with `.melody(...)`.
  - Band.swift:44-55 gives every bar `Bar(root: tonic)`.
  - SongPlayback.band (SongSheet.swift:1113-1128) already builds a chord-by-chord band, and SongOpener.swift:560-563 uses it for "Preview with band".
- **What's wrong:** The song's own preview has the chords. The performance the player works up to plays drums and a tonic bass under G–D–Em–C (Kite Weather) for 2:33. The bass sits on G under the C bars. The reward for learning a whole song sounds poorer than its 4-bar preview.
- **Fix:** In SongPerform, build the band from `LeadChart.of(lesson).chords` (one `ChordSpec?` per bar) through `SongPlayback.band(notes:chords:bars:bpm:meter:reference:bass:)`, falling back to `.melody` only when the chart has no chords. Do the same for `AlongStep` when the lesson carries a chart.

### 4. On the phone speaker, every play-along is a click (major · L)
- **Where:**
  - AudioService.swift:544 (`audible = bandAllowed && headphones && …`);
  - BandControls (Highway.swift:806-808: "out loud it would reach the microphone");
  - SongOpener.swift:12-13.
- **What's wrong:** Most beginners play on the speaker. For them the highway (60) and Kite Weather (65) are a metronome and silence, and the band's final chord (`finishBand(celebrate:)`, Highway.swift:745) never sounds. This is the single biggest fun gap against Yousician, Simply and JustinGuitar, which all play backing out loud.
- **Fix:** The band is rendered offline, sample-exact (`BandTrack`), so the app *knows* the reference signal.
  1. Run a reference echo canceller on the lesson input: an NLMS adaptive filter, about 2048 taps at 48 kHz, fed the band buffer at the heard-latency offset already measured (`heardLatency`).
  2. Alternatively, enable `inputNode.setVoiceProcessingEnabled(true)` for lessons only, never for the tuner.
  3. Ship it as "Band on speaker", default on once a 10 s self-test passes on that route.

### 5. Reward moments are category templates (major · M)
- **Where:**
  - **Lesson results:** LessonResults.swift:588-602, three `Image(systemName: "star.fill")` with the "Flawless / Great work / Nice work" headline (:66-73).
  - **Song finale:** SongStoryCard.swift:71-75 and :114-121, the same.
  - **Streak:** StreakCelebration.swift:54-164, a flame, a rolling number, a row of seven day-flames, then Continue and Share. That is Duolingo's streak screen beat for beat.
  - **Full tune:** Celebration.swift:18-26, a checkmark in a mint circle over a dimmed card, Share and Done, auto-closing after 6 s (:100).
  - **One burst for everything:** SparkBurst (LessonPlayer.swift:587-608), 22 dots and a ring, behind results, streak, song finale, ear training and chord steps.
- **What's wrong:** Strip the palette and these could belong to any habit app. The one signature thing in the app's visual language, a string that vibrates and stands still, never appears in a reward. The shaders show the team can do better: StarHeat's white-hot star is lovely. But it sits on SF Symbols.
- **Fix:** A music-native reward kit:
  1. Replace SparkBurst with a "harmonic" burst. Rings expand at the nodes of a vibrating string (1/2, 1/3, 1/4 of the radius), coloured by lane, and freeze on landing. That is the strobe language, reused.
  2. Make the full-tune moment the 3D instrument itself. The camera pulls back (`showWhole`), each string lights low to high on the model with its bell, then a light sweep runs across the body. Only after that does the card rise. Today the card and a 35 % dim cover the pull-back.
  3. Give the streak the app's own metaphor: a stage lamp that brightens per day, or a setlist. A Duolingo flame invites the comparison.
  4. Draw stars with a custom shape (a pick-shaped star or a string-knot star) rather than `star.fill`.

### 6. The sound identity breaks at its own peaks (major · S)
- **Where:**
  - SoundFX.swift:194-207: `.tuned` is always Csus4→C.
  - LessonResults.swift:613 and SongStoryCard.swift:261: the same `.star` cue three times.
  - StreakCelebration.swift:150 and LessonResults.swift:661: streak and level-up share `.levelUp`.
  - LessonResults.swift:625-629: the XP count-up is silent.
- **What's wrong:**
  - After tuning a guitar to E standard, or a ukulele to GCEA, you hear a C major strum. The one cue meant to sound like your instrument in tune is in the wrong key.
  - Three identical stars miss the oldest trick in game audio, a rising 1-3-5.
  - There is no sonic logo anywhere: launch, onboarding welcome, Pro unlock.
- **Fix:**
  - Change `.tuned` into `tuned(frequencies:)`. It strums the targets just tuned (`store.courses.map(store.target(for:))`), the same synthesis as the lock bells, then lets the ringing chord bloom. Optionally follow it with the first chord of the "Ready to play" lesson.
  - Pitch the stars to the lesson's key (`KeyEstimate.tonic`), playing 1, 3 and 5 as bells via `playLock(midi:)`.
  - Add a soft tick per XP step.
  - Give the streak its own cue.
  - Write a three-note Timbre motif, for example a perfect fifth resolving to the octave, and use it on welcome, Pro unlock and level-up.

### 7. Bullseye is silent and still dressed as a sniper scope (major · S)
- **Where:** PitchSniperView.swift:
  - :200-216: `advance` plays haptics only, with no SoundFX on bullseye, near or miss, and the game has no music.
  - :229-278: Reticle, with a rotating radar sweep and four crosshair ticks. The iPad Play hub (ipad-landscape-practice) shows the same scope.
  - :145: the results headline "Good shooting".
  - :5: the doc comment still reads "Pitch Sniper".
- **What's wrong:** A pitch game with no sound is half a game. "Good shooting" contradicts the store listing's 4+ rationale ("Bullseye… so nothing borrows shooting words", APP-STORE-LISTING.md).
- **Fix:**
  - Play the target note as a quiet drone under the round.
  - Ring the bell at the target pitch on a bullseye, and add a soft detuned wobble on a miss.
  - Replace the radar and crosshair with concentric resonance rings, the strobe language, or an archery target face.
  - Change the headline to "Nice ear" or "Round won".
  - See tip 5 for the hidden melody.

### 8. The signature 3D effects are too subtle to read at marketing scale (major · S)
- **Where:**
  - InstrumentStage.swift:616: string amplitude 0.0012–0.0054 m (1.2–5.4 mm on a full-size model);
  - LockShimmer 1.15 s (Shaders.swift:59);
  - frames 10b, 10, 14, and preview frames 2.4–3.6 s.
- **What's wrong:** In 10b, the store's #1 frame, the string doesn't visibly vibrate and the shimmer has passed. At 886 px in the preview, the lock reads as a faint pale ring. The most original thing in the app does not show up in the places where people decide to download.
- **Fix:**
  - Add a `marketingScale` stage input for the DemoScenes, with three times the amplitude and a 1.8 s shimmer.
  - Capture 10b *during* the comet, not after it.
  - Consider a stronger in-app default for the halo on lock (`haloSegment` scale, :643).

### 9. Generic copy at the peak moments (minor · S)
- **Where:**
  - FirstTuneStep.swift:182 and :202: "Great work" on the first lock of the app's life (05a2).
  - Highway.swift:402 and :471-472: the share card is hard-coded to "Great work" even after a 100 % "Right on the beat" take (61).
  - LessonResults.swift:69 and SongStoryCard.swift:73.
- **What's wrong:** The coach writes like a great teacher ("until your hand knows the way", CoachVoice.swift:88). The headlines write like a template.
- **Fix:** Lead with the fact.
  - First lock: "Low E, dead on." or "82.41 Hz. That's an E."
  - A 100 % take: "Six for six, on the beat."
  - Results: when the coach note is `.clean`, the headline becomes its fact.
  - Keep "Flawless" only for songs.

### 10. "Show me" teaches with dots, not a hand; ukulele and banjo get none (minor · L)
- **Where:**
  - ShowMeScene.swift:901-992 (2D fingertip marks projected over the model);
  - ShowMe.swift:11-12 (no model for ukulele or banjo);
  - frame 51b.
- **What's wrong:** It is impressive engineering: fingertips land on the model's own frets by the equal-temperament rule. But next to Fender Play's 4K multi-camera hands it reads as a diagram in 3D. Ukulele is the #2 course.
- **Fix:** A rigged, low-poly stylised fretting hand (no uncanny realism), posed from the existing `ShowMeShape.presses`, with finger curls as blend shapes. Add a ukulele USDZ.

### 11. The highway's game-feel stops at the visuals (minor · S)
- **Where:** Highway.swift:708-724 (tier-ups get a haptic and a colour roll, but no sound); HighwayPop "Missed".
- **What's wrong:** Rhythm-game feel is half audio. Nothing is heard when a combo breaks or a tier climbs. There are no section results ("Chorus 96 %") at the end, though the song map already knows its sections (65). And `HighwayTimingStrip` exists without a section summary.
- **Fix:**
  - A muted string-choke cue on a combo break (headphones only).
  - A crash on ×4. The band already has `crash` in BandSynth.
  - On the finale, a section ribbon using the song-map chips.

### 12. Ear training's "correct" cue puts foreign pitches into an ear exercise (minor · S)
- **Where:** SoundFX.swift:142-148 (an E5→B5 pluck pair); EarTrainingView.swift:492.
- **Fix:** For ear drills, use the unpitched woodblock, or replay the question's own second note as the reward.

### 13. Small reveals caught in store-adjacent frames (minor · S)
- **Where:** 06b and ShowMe.swift:473.
- **What's wrong:**
  - In 06b, "Your turn — play it back" cross-fades over "Watch the fingers land" (both visible).
  - In 51b, while the demonstration is showing, the disc glyph is `play.fill`, so the store frame reads as "not playing".
- **Fix:**
  - Swap the captions sequentially: out, then in.
  - While showing, use `arrow.counterclockwise` with "Again".

### 14. The metronome is thin on sound (minor · S)
- **Where:** MetronomeView.swift:298-330.
- **What's wrong:** Three voices (Click, Wood, Beep), all Pro-gated. A metronome is a daily-touch tool, and its sound *is* its delight.
- **Fix:** Make Wood free. Add Cowbell, Rim, Shaker and a sampled "Kit", taken from the `drums` set already shipped (29 Virtuosity files).

---

## 4. How to take #1 (ranked by impact)

1. **"Feel it stand still": make the tuner something you feel (S, then M).**
   - First ship the one-line haptics fix (#1).
   - Then replace the cent detents with *haptic beating*: a continuous Core Haptics event whose intensity pulses at the beat frequency between the string and its target. That is |f·(2^(c/1200) − 1)| Hz, scaled into a feelable 0.5–8 Hz range.
   - Far off, it throbs fast. Close in, the pulses slow. Locked, it goes still, followed by one firm thump.
   - This is how players tune by ear, turned into touch, and it *is* the tagline on 01 ("Tune until it stands still"). No tuner has done it.
   - Put the screen-off version in Settings ("Tune by feel"). It is also an accessibility story; Guitar Wiz won an ADA in 2026 on accessibility.

2. **Rebuild the App Preview around three legible signatures, with sound (M).** The cut is laid out under #2.
   - 0–5 s: the lock, with its bell and comet, held 1.5 s.
   - 5–9 s: the camera pull-back as all six strings ring.
   - Then "Show me" in 3D, Kite Weather at ×4 with the band audible, the stars rising 1-3-5, and an end card.
   - The poster is never a fade frame.
   - This is the highest-leverage marketing fix available, and it costs no new features.

3. **Make the band the fun (S, then L).**
   - Use a chord-aware band for performances (#3, an afternoon's work).
   - Then "Band on speaker" through a reference canceller (#4).
   - Then a *reactive* band that thins to drums when you miss, comes back on a streak, and adds a crash and a fill at ×4. "The band follows you" is a sentence a reviewer would write. Rocksmith hints at it; no phone app does it.

4. **A music-native reward language (M).**
   - The full-tune finale strums *your* instrument's in-tune open strings, built from the bells you just rang, and then the first chord of your next lesson.
   - Stars ring as a rising triad in the song's key.
   - Bursts become string harmonics.
   - The streak becomes a stage lamp or a setlist, not Duolingo's flame.
   - One three-note sonic logo threads it together.
   - Retire every "Great work".

5. **Give Bullseye a soul (S/M).**
   - Each round's ten targets are the notes of a hidden melody, from public domain or the Originals.
   - Every bullseye rings its note.
   - At the end the melody plays back in full: "You just played *Ode to Joy* by ear."
   - Drop the scope; use resonance rings.
   - That is a moment people share.

6. **Hero-scale the 3D effects for every capture (S).** Store frames 10b and 51b, and the preview, should show the string *moving* and the comet *mid-run* (#8). The most original thing in the app should be the most visible thing in its marketing.

7. **Hand and ukulele for "Show me" (L).** A stylised hand on the existing finger data and a ukulele model turn "a diagram in 3D" into "a teacher's hands". This is the one place Fender Play's video beats Timbre outright.

8. **Weekly fresh fun (M).** Yousician's weekly Challenges are its retention engine. Timbre owns 50 Originals: release one a week as "This week's song", with a highway leaderboard. The Game Center boards already exist (GameCenterIDs.swift).

---

## 5. What only the owner can do

- **Commission a sound designer** for a sonic identity: a three-note motif and a UI kit of about 12 cues, mastered for phone speakers. Budget roughly $3–8k. The synthesized cues are tasteful but anonymous.
- **Record real ukulele, mandolin and banjo sample sets.** Today ukulele is a nylon guitar, mandolin a steel guitar and banjo synthesized (AUDIO-SOURCES.md, Stand-ins). A day with session players plus editing runs about $1.5–3k. **Record band stems for the Originals** too: the house owns them, so real drums, bass and keys stems are clear to ship and to use in the preview.
- **Test haptics on real iPhones.** Confirm #1 on a device with the tuner and a lesson listening. Nobody else can feel it.
- **Make a device capture of the App Preview with audio** (QuickTime from a real iPhone), or approve the rendered mix. Also approve which Original plays in the preview.
- **Buy or commission a rigged stylised hand** (about $500–2k) and a ukulele USDZ.
- **Set a budget for a handful of licensed hits**, if the business case holds. Recognition is the delight Simply and Yousician sell.
- **Submit to Apple's featuring nomination** once #1–#3 ship, with the "feel it stand still" story. That is the pitch an editor can write a headline about.

---

## 6. Sources

- [GuitarTuna on the App Store](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): 4.8★/149K, chord games, 20,000+ songs, ads, prices.
- [Yousician on the App Store](https://apps.apple.com/us/app/yousician-learn-guitar-bass/id959883039): 4.6★/139K, Editors' Choice, Apps We Love, prices.
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): 4.7★/~400K, Editors' Choice, songs named, video lessons.
- [JustinGuitar Lessons & Songs on the App Store](https://apps.apple.com/US/app/id1176125504): 4.9★/22K, 210 videos, 1,500 songs, full-band player.
- [Fender Play subscription page](https://fender.com/products/fender-play-subscription): 4K multi-camera video, Feedback Mode, backing tracks, $149.99/yr.
- [Fender Tune on the App Store](https://apps.apple.com/us/app/-/id1107017950) (listed; the page could not be fetched in this session).
- [Can you learn guitar with Yousician (Happy New Guitar Day)](https://www.happynewguitarday.com/can-you-learn-guitar-with-yousician/): gameplay synced to a backing track, weekly Challenges.
- [Apple: 2025 Apple Design Award winners and finalists](https://www.apple.com/sn/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards): PBJ – The Musical (Innovation, rhythm plus haptics), Moises finalist.
- [Apple: 2026 Apple Design Award winners](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/): Guitar Wiz (Inclusivity), grug (Delight and Fun).
- [Apple Developer: allowHapticsAndSystemSoundsDuringRecording](https://developer.apple.com/documentation/avfaudio/avaudiosession/allowhapticsandsystemsoundsduringrecording): "The default value of this property is false."
- [Apple Developer: setAllowHapticsAndSystemSoundsDuringRecording(_:)](https://developer.apple.com/documentation/avfaudio/avaudiosession/setallowhapticsandsystemsoundsduringrecording(_:))
- [Haptic feedback and AVAudioSession conflicts (DEV Community)](https://dev.to/maxnxi/haptic-feedback-and-avaudiosession-conflicts-in-ios-troubleshooting-recording-issues-2ocl): haptics failing while recording; the setter as the fix.
- [Apple Developer: CHHapticEngine](https://developer.apple.com/documentation/corehaptics/chhapticengine)
