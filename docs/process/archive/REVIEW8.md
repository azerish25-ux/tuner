# Independent review round 8: overall 8.1/10 (round 7: 7.9)
Screenshots: /tmp/claude-0/-home-claude/8e09460e-cfac-5eb2-9c8f-db780efe8fda/scratchpad/review8/*.png
**Fixed since round 7:**
- The peg cue now holds in steady state (10, 11, 14, 17–19). The selected string is raised and finished strings get a ✓ badge (11, 18).
- The paywall has one track, and its bullets match the reason it opened (40).
- The reminder row is now on the results screen (62).
- The play-along shows a timing strip, uses amber "Keep going" instead of red, and offers "Try it at 45 BPM" (61).
- The strum step labels a late hit "120 ms late" (55), and the chord step shows a ✓ per string (52b).
- Progress shows Lv and ±¢, a heatmap with weekday initials and today marked, and a week recap with Share (45).
- The pendulum swings (22), the drone tonics sit in a grid (41) and ear training has an empty-state hint (23).
- Song covers and Song of the Day were redone (63), and the debug probe is gone from shots 40–49.

**New problems:**
- **Regression:** the violin is drawn as a mandolin (49b).
- Half of the store screenshot frames are wrong.

## 1. Scores
| Area | Score | Why |
|---|---|---|
| Visual design & polish | 8.4 | Studio Noir is consistent and premium, and the 3D and photo stages are best in class. The onboarding title overlaps its subtitle (05a), and there is still dead space (21, 52b, 12, 30, 48, 56). |
| Motion / delight | 7.8 | The pendulum, combo HUD, timing strip, lock burst and reward chips work. Explain steps and the metronome beat row are still static. |
| Tuner | 8.5 | The peg ring and ↻ show on every guitar, uke and bass shot. But the violin shows a mandolin with no cue (49b), and idle bowed or mandolin stages sit on a wide shot (49, 49c). |
| Lessons & curriculum | 8.0 | 499 lessons, and the play-along now gives real feedback. But "A few years" is placed at Unit 2, 21% of steps are static explain steps, one answer key is wrong, and lesson text exists in 10 of 49 languages. |
| Retention / habit loop | 8.4 | The streak with freezes, daily set, quests, reminder row, week recap with Share, streak milestones, widgets and Live Activity are all there. The share poster on results is below the fold (62). |
| Monetization / paywall | 8.0 | The single honest track, contextual headline, and 3 tiers with correct maths (58%, $2.92) work. The hero is still a collage, the copy reads like jargon, and the plan contradicts the "A few years" answer. There is no social proof yet. |
| Platform integration | 8.3 | Three widgets (Home and Lock Screen), two Controls, a Live Activity and App Shortcuts. There is no Watch app and no Game Center. |
| Store readiness | 6.8 | The listing is thorough and the counts are checked. But 4 of the 8 iPhone frames don't show what their captions claim, and the privacy URL is still a placeholder. |

## 2. What stands between this and 9.5 (ranked)
1. **(S) Make the store shots deterministic** (10b, 31, 32, 52b).
   - Frames #7 and #8 are the "7-string electric guitar" paywall. The press-and-drag in `showShelf` (TimbreUITests.swift:199–209) lands as a tap on a Pro card, so 32 and 33 capture the paywall sheet.
   - Frame #1 (10b) shows "Hold it… 0¢" with no ✓. Frame #3 (52b) lights 2 of 6 strings.
   - Replace the silent fallbacks (:284–286, :413–420) with XCTFail.
   - Add a `TIMBRE_SCENE` launch argument that renders each hero state directly: a locked string with ring and ✓, all six chord strings lit, the highway mid-combo. That removes the race against the demo-pitch clock.
2. **(S) Fix the violin stage** (49b). See B1. It is a Pro hero instrument and currently shows the wrong instrument.
3. **(S) Place "A few years" players properly** (05b, 06).
   - Intermediate skips only Unit 1 (Sources/TimbreCore/Learn/LessonEngine.swift:363–372). So a player with years of experience is promised "Three notes on string 2" on the plan and on the paywall's Today node, right before the $34.99 ask.
   - Map intermediate to Unit 5–7 ("More open chords" or "Songs with chords"). Map advanced and pro to Unit 10 ("Barre chords and the pentatonic").
   - Make the plan subtitle match the placement.
   - Better still, add a 45-second placement check (G–C–D change, then D DU UDU) built from the existing chord and strum steps.
4. **(M) One paywall hero, with clearer copy** (06, 16, 31, 40).
   - The hero is a guitar thumbnail, a mini highway and an orphan "Combo ×4". Its lanes run red→purple, the opposite of the real highway (59, 60). When the sheet scrolls, "Combo ×4" slides under the ✕ (33).
   - Replace it with one full-width animated scene: the person's instrument with gems flowing off its strings, and the combo inside the lanes (PaywallPreview.swift:162, :310).
   - Headline: change "X and 59 more on their own stage" (PaywallView.swift:253) to "Tune your cello, and 59 more instruments".
   - Track: "Today ▸ Your first chord" followed by "Day 9 First chords" repeats itself (PaywallView.swift:600). Show the next distinct outcome instead, for example "Day 9 · Play Kite Weather".
5. **(M) Fill the "Your instruments" shelf** (12, 30, 48). The screen that sells "60 instruments" shows one card, with 55% of the row empty (Instruments/InstrumentsView.swift:34). Show the person's instruments, then two "Try next" cards (uke, bass, with PRO tags), then an "Add" ghost card.
6. **(M) Make the beat row the metronome's hero** (21, 22). About 200 pt sits empty above four tiny beat pills. Use full-width cells about 72 pt tall, and flash the amber accent beat. Add subdivision ticks and a ring that pulses around the BPM on every beat. Put Tap and Start right under it (Practice/MetronomeView.swift).
7. **(M) Fill the screen on lesson steps** (52b, 56, 57, 06b).
   - 52b leaves about 260 pt between the chord card and a lone "Hear it". On 56 and 57 the answers float mid-screen, and the 06b card has an empty top.
   - Pin "Hear it" and "Can't hear? Skip" to the bottom action bar, and grow the diagrams to about 60% of the height.
   - Add fret numbers under the columns. The 06b, 51 and 56 diagrams show only finger numbers, while Scales (44) already numbers its frets (Learn/LessonSteps.swift `ChordStep` :312, CourseArt.swift).
8. **(M) Explain steps that play** (51, 53, 06b). Explain steps are 741 of 3,478 steps and are still static. When "Hear it" plays, drop the dots in finger order and light each string as it sounds. On the strum explainer, sweep the pick across the pad in time with the beat row (Learn/LessonMotion.swift).
9. **(M) Idle bowed and mandolin stages should frame the target peg** (49, 49c). They show "— · 196.00 Hz" on a small, whole instrument. Dolly to the target peg with a pulsing "Play G3" ring, as the guitar does (07) (Stage/InstrumentStage.swift, idle `focus` and `target` framing).
10. **(S) Put the share moment in the first frame** (62). The 3-star poster arrives below the fold after a delay (Learn/LessonResults.swift:36, :75). Add a "Share" pill under "New best on this lesson". On 61, offer the same pill for scores of 90% or more.
11. **(S) Song of the Day is duplicated** (63). Kite Weather is both the hero and the first Originals card in the same view. Start the shelf with the next song, and show bars-learned progress on each cover (Songs/).
12. **(S) Welcome chips** (01, 02). The chip row is cut through the Violin PRO badge. Fade the trailing edge, or show 4 chips plus "More".

**Need outside assets or owner decisions:**
- The privacy policy URL (APP-STORE-LISTING.md:61 still reads `<privacy policy URL>`).
- Real ratings or testimonials for paywall social proof, and the final App Preview cut with its music.
- Licensed popular songs, Game Center leaderboards (Pitch Sniper), and whether to build a Watch companion.
- Lesson text exists in 10 of 49 UI languages: either fund translation, or say "tuner" only in the other 39 store descriptions.
- Final prices, trial length (14 days vs 7) and intro or win-back offers in App Store Connect.

## 3. Bugs
- **B1 49b: the "Violin" tuner renders a mandolin headstock** (8 posts, pearl buttons, F-scroll) with no peg ring. Round 7 showed the real violin scroll with its G3 ring.
  - The RealityView make closure (Stage/InstrumentStage.swift:424) captures the modelID it was built with.
  - `load` (:94–113) never checks, after `await Entity(contentsOf:)`, that this is still the wanted model, so a late mandolin load can land after the violin's.
  - Fix: keep a `wanted` id or generation counter, and bail after the await if it changed or `Task.isCancelled`.
- **B2 05a: the title overlaps its subtitle.** "Pluck your thickest string" wraps, and its second line is drawn over "E2 · Acoustic guitar". The stage's `.frame(maxHeight: .infinity)` (Onboarding/FirstTuneStep.swift:144) squeezes the header (:165–177). Give the header VStack `.layoutPriority(1)` and `.fixedSize(horizontal: false, vertical: true)`.
- **B3 31, 32, 33: the wrong screens were captured** (the paywall). The cause is the test harness (TimbreUITests.swift:189–209, :324–331). Shots 31 and 32 are store frames #7 and #8.
- **B4 33: the "Combo ×4" label slides under the sticky ✕** when the paywall scrolls (Paywall/PaywallPreview.swift:162).
- **B5 The paywall highway's lane colours are reversed** against the lesson highway: red is on the left there, purple on the left in 59 and 60 (PaywallPreview.swift).
- **B6 Wrong answer key in the curriculum.** In Kite Weather, "Does the hook climb or fall at first?" plays D4 B3 D4 E4 F#4. It falls first, but the key says "It climbs" (tools/curriculum/courses/originals.py:141, answer 0 → 1, then rebuild curriculum.json).
- **B7 10b and 52b: fallback frames are saved silently as store shots.** 10b shows no ✓, although the listing caption says "peg ringed and ticked". 52b has 2 of 6 strings lit (TimbreUITests.swift:284–286, :413–420).
- **B8 Listing: the privacy URL is still a placeholder** (APP-STORE-LISTING.md:61). Store frames #7 and #8 point at captures that currently show the paywall.
