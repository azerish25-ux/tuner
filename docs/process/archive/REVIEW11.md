# Timbre: Review 11 (independent; 71 screenshots plus code)

## 1. Scores
**Overall: 8.4 / 10.** A premium, cohesive tuner that beats GuitarTuna and Fender Tune. As a lessons app it is still a tier below Yousician and Simply Guitar on repertoire, notation and teaching media.
- **Visual design & polish 8.5.** The Studio Noir look, the lit 3D headstocks and the onboarding are agency grade. iPad layouts are half empty, and some screens look generic (chromatic ring, flat chord grids).
- **Motion/delight 8.5.** Lock shimmer, strobe and heat-star shaders, highway, celebrations and sleeve zoom are a rich system. The weakest moments are explain cards that just sit there.
- **Tuner 9.2.** Polyphonic strum-to-tune, 3D and photo stages, strobe, temperaments, intonation and string health make it best in class. Minus: the cents and Hz readouts disagree, and the control rail is cryptic.
- **Lessons & curriculum 7.8.** 499 lessons with listening steps, a highway, song sheets and Perform takes. But there are only 74 distinct songs (public domain plus 20 originals), no real notation, synthesized audio and no instructor media.
- **Retention/habit loop 8.7.** Streak with freeze, quests, XP and levels, 42 achievements, coach, weekly recap, reminder at results, song of the day, widgets and a Live Activity.
- **Monetization/paywall 8.4.** Contextual heroes, a trial timeline, a reminder on day 12 and win-back. No social proof, the hero reads as a game, and gating the violin tuner is risky.
- **Platform integration 8.2.** 4 widgets, 2 Controls, a Live Activity, App Intents/Siri, Spotlight, TipKit and Game Center. Liquid Glass is used once, the Foundation Models coach is compiled out, and there is no Watch app.
- **Store readiness 7.4.** iPad frames will render sideways, status bars are not 9:41, store frame #8 says "0 lessons", and the privacy URL is a placeholder.

## 2. What stands between this and 9.5 (ranked)
1. **Engraved notation + TAB (L).** 64-songs-lesson. SongSheet.swift:876 `LeadSheetView`, SongOpener.swift:310. Today the lead sheet is a strip of letter-labelled bars ("D B D E F♯"). Users would instead see a 5-line staff with clef, key signature, beamed rhythms and a TAB staff below it (Staff/Tab/Both), with the playhead and lyrics aligned. Reuse it in violin, cello and mandolin note steps. Every top competitor shows real tab.
2. **Animated player's-view neck for chord and explain steps (M/L).** 06b, 51, 52b, 43. Diagrams.swift, LessonExplain.swift. Today these are flat grids filling the card. Instead: a perspective neck (the highway renderer) where fingertips land in order 1→2→3, muted strings fade to ×, and strings shimmer in sync with "Hear it". Add a flip between tab view and player view.
3. **Real iPad compositions (M).** ipad-landscape-practice and ipad-portrait-practice (bottom ~45% empty), ipad-landscape-learn (a ~110 pt path ribbon in a 900 pt void). LearnView.swift:6-40, PracticeView.swift:88-102, CardColumns.swift. Learn: the path on the left and a lesson inspector on the right (steps, chord, sleeve, Start). Play: ear games as tall tiles, plus a tools grid that fills to the fold.
4. **Songs shelf credibility (S).** ipad-landscape-songs, 63-songs. SongsView.swift:839-856. "3 chords or fewer" shows Ode to Joy ×3 and Mary Had a Little Lamb ×2 (one copy per course). Dedupe by title, show the learner's instrument version with instrument badges on a single sleeve, and make covers consistent (some have a play button, some don't).
5. **Store-frame pipeline (S).** tools/marketing/screenshots.py:153, .github/workflows/ios.yml, Timbre/TimbreApp.swift:73-76.
   - iPad landscape PNGs carry EXIF orientation 8, which the renderer ignores, so iPad frames 1–4 come out sideways in a portrait 2064×2752 canvas. They should be 2752×2064.
   - Add `simctl status_bar override --time 9:41` before the UI tests.
   - Seed lesson records so frame #8 doesn't say "0 lessons" next to a 7-day streak.
6. **Labelled tuner controls (S).** 07, 10, 11, 17. TuneView.swift:383-387. Today the rail is four identical circles and only "Strum" has a label; a wand versus a hand icon for auto/manual is unguessable. Make it a glass "AUTO | MANUAL" segmented pill under the stage and a labelled "Reference" tone button.
7. **Chromatic stage worthy of the 3D ones (M).** 15-tune-chromatic. ChromaticStage.swift, Shaders.metal. The dotted rings read as a loading spinner, yet this is the free tuner for every non-guitar instrument. Build a Peterson-style lit strobe disc with a note wheel and needle arc, using the existing `timbreStrobeRipple`.
8. **Strum cues that agree (S).** 53, 54, 55. LessonMotion.swift:66-94. The copy says "Strum down" and the beat row shows ↓, but in the default tab order the pick and chevrons travel up the screen. Always draw the strum lane in player's view (thickest string on top), or caption it "toward the floor".
9. **Apple Intelligence coach (S/M).** CoachVoice.swift:3/281-289 (no `COACH_MODEL` in project.yml). Ship the on-device Foundation Models coach on iOS 26 with the templates as fallback. Also stop Coach and String health from printing the same G-string sentence on one screen (32: CoachVoice.swift:64 and JourneyView.swift:296).
10. **Liquid Glass pass (M).** `glassEffect` is used only at Components.swift:70. Use a `GlassEffectContainer` with morphing for the tuner rail, chip rails, the lesson bottom bars (Hear it/Continue), paywall plan cards and sheet toolbars. This is what ADA jurors and editors look for in 2026.
11. **Readable song map (S).** 64. SongSheet.swift:520-562. Tiles truncate to "Bars 5–…", "Bars 2…", and the intro/outro bookends are blank boxes. Show section names only (bars on press or VoiceOver), glyphs for intro/outro, and minimum widths with a scrolling map.
12. **Paywall hero sells the plan, not a game (S).** 06, 16. PaywallScenes.swift:21-41. Today the guitar is cut by the top edge above a "Combo ×3" runway. Show the user's first-song sleeve plus their instrument, a "Day 2: Greensleeves" path, and a trust line ("Cancel in 2 taps · we remind you on day 12").
13. **Apple Watch companion (L).** New target. A haptic downbeat metronome on the wrist, a streak/quest complication and a one-tap "Start today's set". It is an editorial hook none of the four competitors does well.

**Outside assets / owner decisions**
- Licensed pop/rock repertoire. This is the single biggest gap against Yousician and Simply Guitar.
- Recorded multisampled instruments and real backing stems. All audio is Karplus-Strong or synth, so "Preview with band" will sound like MIDI next to the competitors.
- Short instructor hand-cam clips for the chord and strum explain steps.
- Make violin and cello tuning free. The welcome screen shows "Violin PRO" while the subtitle sells violin, and people searching "violin tuner" will 1-star a paywalled tuner. Settle pricing and trial length at the same time.
- A layered Icon Composer `.icon` (current icon: flat amber PNGs against a mint UI), the privacy URL, and real ratings or quotes for paywall social proof.

## 3. Bugs
- **Cents and Hz disagree.** 10-tune-3d shows "−11¢ · 81.93 Hz" (that is −10.0¢), 05a "−3¢ · 82.30 Hz" (−2.3¢), 11 "−13¢ · 145.78 Hz" (−12.4¢), 18 "−13¢ · 259.77 Hz" (−12.3¢). Hysteresis holds the cents while the Hz tracks the filter. Readout.swift:79-86: update `shownHertz` only when `shown` changes.
- **Selected scale chip off-screen.** 44-scales: "Minor pentatonic" is off the right edge while the title reads "C minor pentatonic". `EdgeRail` sets `position = selection` in onAppear, before layout. PracticeChrome.swift:36-46: set it after layout, for example in a `.task`.
- **START pill covers stars.** ipad-landscape-learn: the bobbing "START" pill sits on the previous node's ★★★. LearnView.swift:461-468: give it clearance or put it beside the node.
- **Song map labels.** 64: labels truncate and the intro/outro tiles are blank (SongSheet.swift:530-556).
- **Accidentals spelled three ways.** ASCII "Bb/Eb/Db" in 41 (drone wheel), 24 (voice graph) and 12/47 ("Eb standard"); "D♭ E♭" glyphs in 43 and 44; "E ♭ / B ♭" with a gap in the 44 note chips. NoteNames.swift:9-10, PitchMath.swift:12, VoiceKeyboard.swift:17 should share one ♯/♭ formatter.
- **Drone wheel.** 41/42: notes descend clockwise (G, F♯, F, E… from the top) and the tanpura art hides the top note. DroneView.swift/DroneTanpura.swift.
- **Repeated insight.** 32/45: Coach and String health print the same "G string drifts 7¢ flat a day" message.
- **"0 lessons" vs Learn.** 32 and ipad-*-progress: "Your week" says "0 lessons" while Learn shows 3 finished. The demo seed writes no `kind: "lesson"` records (TimbreApp.swift:73-76).
- **iPad frames sideways.** iPad landscape store frames will render sideways (screenshots.py:153 ignores EXIF orientation).
- **Clipped badge on first screen.** 01/02: the welcome screen's instrument row clips "Violin PRO" at the right edge, so the first screen shows a cut-off paywall badge.
