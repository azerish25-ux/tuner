# JURY 16: Delight & Fun / Innovation (juror: "delight")

I am the creative director on the panel. I judge the moments people talk about later, and whether the store page lets a stranger feel them before downloading. I checked everything below myself:
- the iPhone and iPad frames in `review16/`;
- the new App Preview, re-cut frame by frame with ffmpeg at 4, 10 and 30 fps, with its soundtrack decoded and measured in 50 ms windows (RMS, onsets, and FFT pitch identification of every sound in it);
- the code behind every motion, sound and haptic claim.

---

## 1. Score: **8.7 / 10** (round 15: 8.3)

**Verdict.** The team shipped almost the whole delight wave, and most of it is excellent:
- **Haptics actually reach the hand.** `setAllowHapticsAndSystemSoundsDuringRecording(true)` is now set (AudioService.swift:821), so the detents and the lock thump are no longer silenced while the tuner listens.
- **"Tune by feel" exists and is a world first** (Haptics.swift:94-160). The phone throbs at the real beat rate between the string and its note, |f·(2^(c/1200)−1)| taken an octave up below 220 Hz, slows as the string comes in, stands still at the lock, then gives one thump. No tuner has done this.
- **The rewards now speak the music:**
  - a full tune strums the instrument's own open strings, rolled low to high, each with its bell, while the same strings light one by one on the 3D model before the card rises (SoundFX.swift:85-94, SoundSynth.tuned :394-414; InstrumentStage.swift:654-698; Celebration.swift:3-27);
  - stars ring 1-3-5 in the lesson's key (SoundFX.swift:121-128, `RewardKey.of`);
  - there is a three-note motif (:370-380);
  - the star is a single string tied into a pentagram that rings and then stands still (RewardStar.swift:3-43);
  - the burst is a ring of string harmonics whose nodes hold still (SparkBurst.swift:3-27).
- **The band follows the player.** It plays the song's chords bar by bar (SongPerform.swift:104-109), thins to drums and bass on a miss, fills back in after four in a row, crashes at ×4 and chokes a broken run (PlayAlongCues.swift:14-27, Band.swift:187-289).
- **Bullseye has a soul now:** resonance rings, a bell at the target's pitch, a soft knock for a near miss, a beating wobble for a miss, and a hidden tune.
- **The copy leads with facts:** "Low E, dead on." (05a2), "6 of 6, clean" (62), "6 for 6, on the beat".

I would put the craft inside the app at 9.3.

Three things hold the score down:
1. **Most players will never hear the band, and the store says they will.** It is still headphones-only (AudioService.swift:655). A beginner on the speaker gets a woodblock. The new App Preview proves it: under the caption "Play songs with the band", its soundtrack is a click every 0.68 s with digital silence between the clicks.
2. **The sound-on preview mistimes or drops the moments it exists to sell:**
   - The lock bell rings 0.78 s before the lock appears.
   - "✓ In tune" is on screen for 4 frames.
   - The poster is the frame before the lock.
   - "Hear how you did" plays 2.7 s of a still frame over silence.
   - The end card is silent.
   - About 7.5 of the 23.2 seconds are digital zero.
3. **The signature lock doesn't hold.** The "In tune" badge collapses about 130 ms after it lands, so both #1 store frames (iPhone 10b, iPad tune), captioned as a locked string, read "Hold it…".

Meanwhile the most original thing the team has ever built, Tune by feel, is off by default, sits several rows down in Settings, and is missing from the listing.

---

## 2. Head-to-head on Delight & Fun / Innovation

| Competitor (current store facts) | Who wins my angle | Why (evidence) |
|---|---|---|
| **GuitarTuna**: 4.8★ / 149K; *contains ads* (a reviewer reports an ad after every song); chord games; chords and tabs for 20,000+ songs; Play, Tools and Learn subscriptions; v7.104 "small improvements" | **Timbre, clearly on the tuning moment; GuitarTuna on game breadth** | Timbre's lock has a peg that turns with the error, a bell at the string's own pitch, a comet, then the finale: a camera pull-back while the instrument strums its own in-tune strings and lights them on the model. Add Tune by feel and Strum to tune ("Tune A2 up 12¢ first", 11b) and GuitarTuna's needle and ping is a different era. GuitarTuna still has more games, and songs people recognise, but its ads are anti-delight. |
| **Fender Tune**: 4.8★ / 145K; free; Auto, Manual and Chromatic modes; 5,000 chords and 2,000 scales; no celebratory or game feature on its page | **Timbre, by a mile** | A utility. Nothing in it is a moment. |
| **Fender Play**: 4.8★ / 60.6K; 3,000+ video lessons; 1,000+ songs (Nirvana, Billie Eilish, Taylor Swift); full-band backing tracks; Chord Challenge high scores; $9.99/mo or $89.99/yr | **Split: Timbre on Innovation and game feel, Fender on warmth and fun out loud** | Timbre's highway at ×4 (65), its section ribbon and its 3D "Show me" are more interactive than anything in Fender Play. Fender has real hands on real guitars and a real band you hear without headphones. Timbre's "Show me" still teaches with fingertip pads and no hand (51b; ShowMe.swift:11-16), and its band is silent on the speaker. |
| **Yousician**: 4.6★ / 139K; Editors' Choice; 10,000+ lessons, exercises and songs, new songs weekly; a separate AI-teacher app ("June", 4.4★ / 102) | **Yousician on Fun; Timbre on Innovation and motion** | Yousician's fun *is* the backing track out of the speaker, plus a weekly refresh. Timbre's band is smarter (it reacts to how you play, which nothing in Yousician does) but inaudible for speaker players. Timbre has no weekly content cadence. |
| **Simply Guitar**: 4.7★ / ~400K; Editors' Choice; Queen, Aretha Franklin, Billie Eilish; video lessons; a seasonal "Halloween Haunted Hits" event | **Simply on Fun (recognition, seasonal events); Timbre on craft and Innovation** | Strumming "We Will Rock You" beats strumming "Kite Weather" for a first-week player. Timbre answers with Originals sleeves and a hidden *Ode to Joy* in Bullseye, but it hides that tune in only half the games (#6). |
| **JustinGuitar**: 4.9★ / 22K; 210 videos with Justin; 1,500+ songs; a full-band song player with vocals, tempo and lyrics | **Justin on personality and the band; Timbre on game feel and Innovation** | Justin *is* the voice. Timbre's voice is now crisp and factual, a real gain, but it is a rules engine, not a person. Justin's full-band player sounds on any speaker. |

**ADA context (2026).**
- Delight and Fun went to *grug* (daily "neolithic grunts") and *Is This Seat Taken?*.
- Inclusivity went to *Guitar Wiz*, a guitar toolkit with spoken instructions.
- Innovation went to a Vision Pro NBA app and *Blue Prince*.

Juries reward one unmistakable idea, shown well. Timbre now *has* that idea: a phone that beats like two strings, then goes still. It isn't showing it to anyone.

---

## 3. Everything that costs points, ranked

### 1. On the speaker, the band (and everything it "follows") is silent (major · L)
- **Where:**
  - AudioService.swift:655: `let audible = bandAllowed && headphones && …`;
  - Band.swift:252-256: "The band only ever plays in headphones";
  - PlayAlongCues.swift:8-11;
  - the App Preview, 10.9–16.4 s.
- **What's wrong:**
  - **The marketing.** Under the caption "Play songs with the band", the preview's audio is a ~1.5 kHz woodblock every 0.68 s (88 BPM) with digital silence (−∞ dB) between the clicks. No drums, bass or chords play, and neither does the guitar part being "played".
  - **The product.** Most beginners play on the speaker. For them the thin, fill, crash and choke, the chord band and the final chord (`finishBand(celebrate:)`) never happen. "The band follows you" is the best fun idea in the category, and it reaches only headphone users.
  - **The status.** This is round 15's #4, unfixed.
- **Fix:**
  1. **Now (S), a speaker band.** On the speaker, play only the kit layer. Drums are aperiodic, YIN's confidence rejects them, and the click already plays out loud. The BandTrack already renders rhythm and harmony in separate layers (Band.swift:187-190). Gate the harmony on `headphones`, not the whole band. Thin, fill and crash then work on the speaker too.
  2. **Next (L), the full band on the speaker.** The band is rendered sample-exact, so its waveform is known. Add an NLMS reference canceller (≈2048 taps at 48 kHz) on the analysis input, fed the band buffer at `heardLatency`. Alternatively, use `setVoiceProcessingEnabled(true)` for lessons only, never the tuner. Ship it as "Band on speaker" once a 10 s self-test passes on that route.
  3. **Until (1) ships,** change the preview caption to "Play along with the band in headphones", or show a headphones glyph.

### 2. The App Preview with sound misses or mistimes its own signature moments (major · M)
- **Where:**
  - `review16/preview/preview.mp4`;
  - tools/marketing/preview.py:847-853 (each clip's audio is taken on the app's clock at `c.wall_start`, and its picture from the sync mapping);
  - TimbreUITests/AppPreviewUITests.swift:171-178 (the `lock` sync is taken after the hold, on a static screen), :248 (the results clip), :177 (`poster(at: lock + 1.0)`).
- **What's wrong** (all measured on the delivered file):
  - **The picture runs 0.5–1.0 s behind the sound in the tuner clips.**
    - The E2 lock bell (E3 bell, partials E4 and B4 identified) starts at **1.95 s**. "✓ In tune · 3¢" and the peg tick first appear at **2.73 s**, 0.78 s later.
    - The full-tune strum starts at 4.40 s (roll onsets 4.40, 4.49, 4.61, 4.74, 4.85, 4.97; bloom at 5.25 s). The last string visibly locks at about 4.8 s.
    - The cause: the `lock` sync screenshot is taken during the hold, when the screen barely changes, so its match is ambiguous by about a second ("pinned" at diff 0.6 against a next-best of 1.1). The cut was planned with the lock at 1.71 s; it shows at 2.73 s. The "held 1.5 s" lock that APP-STORE-LISTING.md:208 promises shows for 0.68 s before the cut.
  - **The poster (2.70 s) is the frame before the lock:** "−3¢ · 82.27 Hz", "Hold it…", Quest 0/6. The listing says the poster shows "✓ In tune, the peg's tick".
  - **The lock's badge shows for 4 frames** (2.73–2.83 s), then reverts to "−1¢ · 82.37 Hz · Hold it…" while the halo and comet play (see #3).
  - **No sound of a string being tuned.** The preview opens on 1.95 s of digital silence while the string drifts from −9¢. A tuner preview where you never hear the string wastes the one sound everybody knows.
  - **No band under the highway** (#1). The PreviewRecorder swaps the route to read as headphones so the band would be recorded (DemoScenes.swift:319-321, 383-385), but the soundtrack contains no band at all. The render didn't notice.
  - **The highway clip opens on a broken combo:** 0, ×1 and "× 2" misses (t11), climbing only to ×2 (t15). The listing promises "at ×4".
  - **"Hear how you did" (16.36–19.09 s) is one frozen frame over digital silence.** The clip is `keep: .tail`, taken after the stars landed, so the three star bells in G and the harmonic burst never make the cut.
  - **The Songs clip and the end card are silent** (19.1–23.2 s): no motif, although the app has one.
  - **Over 7 s of the 23.2 s are exact digital zero.** That counts 1.95 s at the start, 7.25–8.65 s, the gaps between clicks and the last 6.8 s. Mean −24.3 dB is a loudness-normalised average over a mostly empty track.
  - **The reward pill collides with the status bar** at 4.1–5.3 s and 6.8–7.4 s ("9:4✦" and "+5 XP" over the signal bars; #10).
- **Fix (keep the 23–25 s budget):**
  1. **Sync on events, not static screens.** Take each `sync(...)` within 50 ms of the app's own event (`appEvent("lock")`), while the comet moves. In `render`, find the bell onset in the audio and the badge or halo's first frame in the video. Fail the render if |Δ| > 80 ms.
  2. **Poster = the lock + 0.3 s, verified.** Template-match the "In tune" badge in the poster frame before writing PREVIEW.txt.
  3. **Log the demo pitch's string as engine audio** at about −12 dB. Its Karplus–Strong drift is the "string" a viewer expects to hear, and it makes the highway notes audible too.
  4. **Make the render fail when the highway clip has no band.** Check for energy below 250 Hz between clicks.
  5. **Use a clean take for the highway.** Use the store scene's take (`song-perform` from bar 16, every earlier note clean) and cut from combo ≥ 40 so ×4 and the crash are on camera.
  6. **Take the results clip from `finale − 0.2` with `keep: .head`**, so the stars land 1-3-5 with the burst.
  7. **Put the app's `.motif` cue under the end card.** Have the tour log it once, at onboarding's welcome (OnboardingView.swift:283-292), so "nothing is synthesized here" stays true.

### 3. The lock doesn't hold: "In tune" vanishes ~130 ms after it lands, and both #1 store frames show "Hold it…" (major · S)
- **Where:**
  - TuneView.swift:362-363: the badge is `reading.inTune`, frame by frame, with no latch;
  - TuningTracker.swift:76: any gap of more than 150 ms between published frames resets the hold;
  - TuningTracker.swift:6: `holdMs = 650`, so the badge needs another 0.65 s in band to come back;
  - AppStore.swift:665-676: the lock frame also persists settings and records progress on the main thread, a plausible hitch;
  - frames 10b, ipad-landscape-tune and preview 2.73–3.41 s.
- **What's wrong:**
  - In the preview, the badge lasts 4 frames and then "Hold it…" returns under the expanding halo.
  - **10b, store frame #1** ("a string locked… its peg ringed and ticked, the lock's comet running down the string"): D3 is counted (Quest 3/6), but the readout says "0¢ · Hold it…", the D3 chip has no tick, and the comet is a faint smear below the nut.
  - **iPad store frame #1** shows the same: 3/6, "Hold it…".
  - The app's defining moment, the string standing still, reads as *not yet*.
- **Fix:**
  - Add `lockedAt` to the store. Show the badge, and keep the status line quiet, for max(1.5 s, while within the band) after `enteredTune`, whatever the tracker does.
  - In `TuningTracker.accept`, don't restart the hold across a gap when the frames on both sides are in band.
  - Debounce `updateSettings` for the lock (about 300 ms later).
  - Recapture 10b and the iPad frame at lock + 0.15 s, while the comet is still over the headstock. Check the badge in `storeFrame`.

### 4. Tune by feel, the category's most original interaction, is off by default, several rows down in Settings, and unmarketed (major · S)
- **Where:**
  - SettingsView.swift:355-360: Settings › Feedback, below Tuning and Display; the 13-settings frame shows no trace of it;
  - TuneView.swift:75: no control on the tuner;
  - no offer in onboarding (FirstTuneStep.swift);
  - APP-STORE-LISTING.md: not one word on "feel", "haptic", the hidden tune, or a band that follows you; the description is a feature list.
- **What's wrong:** It is the tagline made physical ("Tune until it stands still"), an accessibility story, and an editorial headline. Nobody will find it, and no editor will read about it. The other signature moments are missing from the listing too: the bells at your string's pitch, your instrument strumming itself in tune, the band that drops out when you miss, a hidden song in a pitch game.
- **Fix:**
  - **In the first tune of onboarding:** "Want to feel it? Turn on Tune by feel" with a 3 s Feel test.
  - **On the tuner:** a `hand.tap` toggle in the side controls (beside Strum), and a one-time tip after the 3rd full tune.
  - **Default on** when VoiceOver is running.
  - **In the listing:** a first bullet under TUNE ANYTHING: "Tune by feel: your iPhone pulses with the beat between string and note, slower as they meet, and goes still in tune". Put a line in the promotional text too.
  - **Craft:** at 8 beats a second with ~47 readings a second, the pulse is stepped. Schedule each cycle as a `CHHapticParameterCurve`, not per-frame `sendParameters`.

### 5. The streak has two metaphors: a stage lamp at the milestone, Duolingo's flame everywhere else (minor · S)
- **Where:**
  - StreakCelebration.swift:3-7 and :146 (`StageLamp`), against 25 `flame.fill` uses;
  - the header pill (20, 32, 62);
  - Celebration.swift:59 and :428;
  - the "1-day streak" chip (05a2);
  - Progress tiles (32).
- **What's wrong:** The lamp is a lovely, ownable idea, but a player sees it only at 3, 7, 30 and 100 days. Every day they see a flame, which invites the Duolingo comparison the team set out to avoid.
- **Fix:** Draw a small custom lamp glyph (`StageLamp` at 14 pt, the beam as a wedge) and use it everywhere a streak is shown. Keep the flame only for the highway combo, where "on fire" is the right meaning.

### 6. Bullseye's hidden tune is the best shareable idea in the app, and it is half-hidden (minor · S)
- **Where:**
  - PitchSniperView.swift:20-21 and :220 (`hiddenTune: gamesStarted % 2 == 1`): the first game of every visit has no tune, because `@State` resets;
  - :182-183: the reveal plays only on tap, as ten equal 420 ms tones;
  - PitchSniper.swift:28-30: repeated notes are dropped, so *Ode to Joy* loses EE-F-GG and its rhythm;
  - the Practice card says "Play the note. Hold the bullseye." (20) and never mentions the tune;
  - no music bed under a round;
  - the miss wobble is always A3 (SoundFX.swift:361-366), a foreign pitch in a pitch game.
- **Fix:**
  - Make every game a hidden tune. Keep "Random notes" as an option.
  - Card copy: "Ten notes. One hidden song."
  - After note 6, offer "Name that tune?" with three choices for bonus XP.
  - The reveal auto-plays the real opening, in rhythm, from the song's own lesson chart, in the instrument's voice. Your bullseye bells replay in place, then "You just played *Ode to Joy* by ear" with a share card.
  - Pitch the wobble to the target ± 7 Hz.

### 7. The results screens' finishing details (minor · S)
- **Where:**
  - HighwayTimingStrip.swift:289-295 and :312-318;
  - preview t17;
  - LessonResults.swift:181;
  - frame 62.
- **What's wrong:**
  - **The section ribbon.** Intro and Outro tiles are too narrow for their labels, so `ViewThatFits` falls back to `Color.clear`: two blank tiles. Beneath them the summary reads "Strongest: Intro, 100%". `max(by:)` picks the first of several 100 % sections, so it praises the one tile you can't read, and the easiest part of the song.
  - **The burst on 62 (store frame #7).** The outer amber ring cuts through "6 of 6, clean", "The open strings" and the status bar. The coach then repeats the headline: "Clean run: 6 of 6 … Nothing slipped."
- **Fix:**
  - Ribbon: give tiles a minimum width with "In" and "Out" abbreviations. Tie-break "Strongest" by note count and skip sections with fewer than 8 notes. When every section is ≥ 90 %, say "Every section 90 %+".
  - Burst: pass `ring: false` (or reach 120) behind results text.
  - Coach: when the headline is the clean fact, the coach gives the next step ("Next: the same at 110 %").

### 8. On the speaker, the highway's game feel is haptic-only (minor · S)
- **Where:** PlayAlongCues.swift:16-26.
- **What's wrong:** Tier-ups, the ×4 crash and run breaks are a tap or a headphone-only band one-shot. On the speaker a ×4 is silent, and rhythm-game feel is half audio.
- **Fix:** Reuse the `Earcons` approach (PlayAlongCues.swift:78-131: shaped noise with no pitch, so the microphone never takes it for a note). Add a rising noise swish for each tier and a soft tape-stop noise when a ×3 or ×4 run breaks. Both are safe on the speaker.

### 9. "Show me" teaches with pads, not a hand; ukulele and banjo get no 3D (minor · L)
- **Where:**
  - ShowMe.swift:11-16 ("Instruments without a model (ukulele, banjo)…", "a fretting hand rig… plugs in");
  - ShowMeScene.swift:205-210 and :401-405;
  - frames 51b and preview 7.5–10.9 s.
- **What's wrong:** The engineering is superb: fingertips land on the model's own frets, each string sounds as its finger lands, and the strum lights the strings. But it remains a diagram in 3D next to Fender Play's hands. Ukulele is the #2 course, and the subtitle sells it.
- **Fix:** A stylised, rigged low-poly hand posed from `ShowMeShape.presses` (the protocol already exists), plus a ukulele USDZ with its rig. This needs the owner (§5).

### 10. The reward pill grows over the system status bar (minor · S)
- **Where:**
  - GameUI.swift:690 and :696 (compact pill = 132 + 2 × 64 pt = 260 pt wide, centred on a 126 pt island);
  - preview 4.1–5.3 s and 6.8–7.4 s.
- **What's wrong:** The sparkle sits on the "1" of 9:41 and "+5 XP" sits under the signal bars. It reads as a glitch, and it fires on every string lock.
- **Fix:** Cap the compact side wings at about 36 pt (the text inside the island width), or hide the status bar while the pill is open.

### 11. The ear games still feel like a quiz, with a few off-voice sounds (minor · M)
- **Where:**
  - 23: two buttons and a "?" bar;
  - EarTrainingView.swift:499 (`.wrong` is a pitched D3→B2 pluck, SoundFX.swift:288-292);
  - :532 (`.complete` is a C-major arpeggio after a round in any key);
  - :428 ("Great work", the last one in the app).
- **Fix:**
  - Use an unpitched wrong cue (the `Earcons` thud).
  - End the round on the last question's key.
  - Headline: "9 of 10 by ear".
  - Give ear training one game mechanic: a streak of right answers raises a "tuning fork" glow, or a sung-back mode on the pitch track.

### 12. Smaller seams (minor · S)
- **06b "Meet your guitar".** All six strings glow mint while the copy says "The thickest string… We call it string 6". The guitar is a painted illustration, unlike the 3D instrument everywhere else. Light and pluck only string 6 (its E2 bell), on the 3D model.
- **Metronome** (Sources/TimbreCore/Audio/OutputAudio.swift:107). Wood is now free, but there are still only three voices: Click, Wood, Beep. Add Rim, Cowbell, Shaker and "Kit" from the shipped drum samples.
- **The celebration card's glyph.** `StillStrings` is six plain bars (preview 7.1 s). Animate them ringing to stillness, the RewardStar idea at card scale.

---

## 4. How to take #1 (ranked by impact)

1. **Make the band audible for everyone, then let it follow them (S, then L).**
   - Ship the speaker kit layer this week (#1, step 1).
   - Then ship the reference canceller.
   - "The band drops out when you miss and comes back when you lock in" is a sentence an App Store editor would write. It only counts if most players can hear it.
2. **Re-cut the preview as a sound-first trailer (M).**
   - Open on the string's own pluck drifting in, its beating audible.
   - The bell lands *on* the badge and holds 1.5 s.
   - Pull back as the guitar strums itself in tune.
   - E minor in 3D.
   - Kite Weather at ×4: crash, band, lyrics.
   - Stars ring G-B-D.
   - The motif on the end card.
   - Event-based sync and a verified poster (#2) make this repeatable.
   - Add a 2.5 s shot that *shows* Tune by feel: the phone on a knee, a pulse ring slowing to stillness, caption "Feel it stand still".
3. **Make "Feel it stand still" the headline (S).**
   - Offer it in onboarding, the tuner and the listing (#4).
   - Put it on Apple Watch: tune with the phone on the music stand and feel the beat on your wrist (the Watch already plays a felt metronome).
   - Pitch it to Apple editorial as an accessibility-first tuner. 2026's Inclusivity winner was a guitar app.
4. **Latch the lock, then recapture store #1 on iPhone and iPad (S).** The first frame a searcher sees must show the string standing still: badge, tick, comet over the headstock (#3).
5. **Make Bullseye "Mystery Song" (S/M).**
   - Every game hides a tune, with "Name that tune?" mid-round.
   - The reveal plays the real melody in rhythm.
   - A shareable "I found Ode to Joy by ear" card.
   - A weekly Mystery Song league on the existing Game Center boards. That gives you a weekly content cadence (Yousician's and GuitarTuna's "new songs weekly") without licensing a single song.
6. **One streak metaphor, the lamp, everywhere (S).** Retire the flame outside the highway combo (#5).
7. **Weekly fresh fun (M).** "This week's Original" on the Songs hero with a highway leaderboard. You own 50 Originals; release them as events, as Simply does with its seasonal "Haunted Hits".
8. **A teacher's hands (L).** A rigged stylised hand and a ukulele model for "Show me" (#9). This is the one place Fender Play still wins outright on wonder.

---

## 5. What only the owner can do

- **Test haptics and Tune by feel on real iPhones** (15, 16, 17), with the tuner listening and in a lesson. The simulator has no haptics. Confirm the beat is felt and still at the lock, and the detents survive while the mic records.
- **Approve the preview's sound.** Choose a device capture from a real iPhone with audio, or the rendered mix once #2 is fixed. Also choose which Original plays under the highway.
- **Commission a sound designer** ($3–8k): master the motif and a ~12-cue UI kit for phone speakers, and record a short "speaker-safe" drum kit for the speaker band.
- **Record real ukulele, mandolin and banjo sets** (a session day plus editing, ~$1.5–3k). Today the ukulele is a nylon guitar, the mandolin a steel guitar and the banjo synthesized (AUDIO-SOURCES.md, Stand-ins). **Record band stems for the Originals** (real drums, bass and keys). The house owns the songs, so they can go in the app and the preview.
- **Buy or commission a rigged stylised hand and a ukulele USDZ** (~$0.5–2k).
- **Put money on a few licensed hits** if the business case holds. Recognition is the fun that Simply and Yousician sell.
- **Submit an Apple featuring nomination** once #1–#4 ship, with the "feel it stand still" story and a device video of the beat.

---

## 6. Sources

- [GuitarTuna on the App Store](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): 4.8★ / 149K, contains advertising, chord games, 20,000+ songs, subscription tiers, v7.104.
- [Yousician on the App Store](https://apps.apple.com/us/app/yousician-learn-guitar-bass/id959883039): 4.6★ / 139K, Editors' Choice, 10,000+ lessons and songs, new songs weekly, prices.
- [AI Guitar Lessons & Teacher by Yousician on the App Store](https://apps.apple.com/us/app/-/id1640426327): the AI teacher "June", 4.4★ / 102.
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): 4.7★ / ~400K, Editors' Choice, named songs, video lessons, the "Halloween Haunted Hits" event.
- [Justin Guitar Lessons & Songs on the App Store](https://apps.apple.com/US/app/id1176125504): 4.9★ / 22K, 210 videos, 1,500+ songs, full-band song player.
- [Fender Play (AppFollow listing)](https://apps.appfollow.io/ios/fender-play-learn-guitar/1226057939?country=us): 4.8★ / 60.6K, 3,000+ lessons, 1,000+ songs, full-band backing tracks, Chord Challenge, $9.99/mo or $89.99/yr.
- [Fender Tune (App Pricing Lab)](https://apppricinglab.com/app/apple/1107017950): 4.8★ / 145.1K, free, tuner modes, chord and scale libraries, no celebratory features.
- [Apple Newsroom: 2026 Apple Design Award winners](https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/): grug and Is This Seat Taken? (Delight and Fun), Guitar Wiz (Inclusivity), NBA and Blue Prince (Innovation).
- Not reachable this session: Apple Newsroom's 2025 ADA page (permission timed out). No 2025 ADA claim is made above.
