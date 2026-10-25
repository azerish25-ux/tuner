# REVIEW 14: Timbre (iOS), independent jury pass

**Overall: 8.9 / 10.** The team closed every item from review 13, and I checked each one against the stills and the code. The double "In tune" on 10b, the clipped results ring, the song-sheet seam, the arrow-against-pick, the "— · 196.00 Hz" dash, "Step 2 of 5" shown twice, nursery rhymes leading the shelves, the one-line onboarding paywall, the iPad tools grid, and the static drone and ear stages are all fixed. As a tuner it is now unmatched, and as a lesson app it is more coherent than GuitarTuna's. Four things keep it short of "Apps We Love over Yousician, Fender, Simply Guitar":
- **Defects in the store set.** Two new ones sit in the two highest-value frames (#2, #6).
- **Localization drift.** About 18 % of the lessons, the first onboarding line and the paywall's trust line fall back to English in every non-English locale.
- **The paywall hero.** It now sells the goods, but its sleeve titles run into the headline and it leads with Clementine.
- **Content credibility.** The catalogue is public domain plus house Originals. Ukulele, mandolin and banjo sound like guitars or a synth. "Show me" is fingertips without a hand.

## 1. Scores
- **Visual design & polish: 8.9 (+0.2).** It is one confident system. Sora type, mint and amber on near-black, the Liquid Glass tab bar, studio-lit RealityKit heads and 24 sleeve motifs all hold together. The highway (59, 60, 65) is the most handsome screen in the category, and the Songs grid (63, ipad-*-songs) now looks like a real catalogue. Residual seams:
  - Type sits on type on the onboarding paywall: "OH! SUSANNA" touches "Unlock your full plan" (06).
  - A half-faded Share pill sits on store #6 (62).
  - The score is caught mid-roll on store #2 (65).
  - The section-chip playhead cuts through "Cho|rus" (65).
  - Sleeves under about 70 pt print "ORIGI…" (65 header, Up next).
  - The paywall outcome icons mix photo icons with SF-glyph tiles (06, 16, 40).
  - The guitar has two looks. The rendered cards show a grey, untextured headstock with gold tuners (01, 05a, 14, 47); the live stage shows dark wood with near-black buttons (10, 10b, 90).
  - iPad pages still have dead zones. The level card is half empty, the quests column is half empty, and the Learn path is a 220-pt strip.
- **Motion/delight: 9.0 (+0.2).**
  - Spring tokens with a Reduce Motion fallback (Theme.swift:217-244), used in 64 files.
  - 4 Metal shaders (Shaders.metal:43,95,123,155).
  - Zoom transitions, matched geometry, phase animators and numericText across more than 20 files, and about 150 haptic call sites.
  - The drone now breathes and its strings vibrate (42).
  - The ear-training veil (23).
  - "Show me" demonstrations on the 3D neck (ShowMe.swift, ShowMeScene.swift).
  - The metronome pendulum with its trail (22).

  What is missing is a signature moment the store set shows. "Show me", the most cinematic feature, is never captured.
- **Tuner: 9.4 (=).** Strum-to-tune ("Tune A2 up 12¢ first", with the "≈ estimate" honesty, 11b), the strobe chromatic (15), peg cues with turn arrows (10, 19), string health and drift coaching, intonation (46), 60 instruments and 102 tunings, and the "Target 196.00 Hz" idle (49) put it ahead of GuitarTuna. Four things hold it at 9.4:
  - Ukulele, the #2 course, gets no turn arrow because photo stages carry no turn sign (17; StudioStage.swift:13-14).
  - The control on violin and cello reads "Strum" (49b, 49c; AppStore.swift:1082, StrumTuneView.swift:537).
  - The violin and cello peg mapping looks inverted (bug 7).
  - The Pause button overlaps the chromatic dial's bezel (15).
- **Lessons & curriculum: 8.6 (+0.3).** 617 lessons in 14 courses. Guitar is 132 lessons (680 min) and ukulele 60, with 77 free (curriculum.json). On the teaching side there is:
  - a tune check that no longer borrows a step number (52);
  - strum stages in Player view, with the pick travelling ↓ (53-55);
  - the final play-along gating the stars ("Flawless", 62);
  - engraved lead sheets and a song map (64);
  - a 3D "Show me" for chords, notes and strums.

  The gaps against Fender and Simply Guitar:
  - There is no real hand or teacher.
  - Ukulele and banjo have no 3D model, so no "Show me" (ShowMe.swift:11).
  - Ukulele "Hear it" is nylon-guitar samples, mandolin is a steel guitar, banjo and voice are synthesized, and the cello is a *section* (AUDIO-SOURCES.md, Stand-ins).
  - There are no licensed songs.
  - The outline and the player disagree on step titles (bug 5).
- **Retention/habit loop: 9.1 (+0.1).** It runs at Duolingo's level, and the Today plan is now pinned and consistent across 20, 50 and the iPad:
  - streak freezes, quests, XP and levels, 42 badges with progress (ipad-portrait-progress);
  - SM-2 spaced review, coach cards, string-health coaching;
  - the reminder ask at the peak (62);
  - a Live Activity, a Watch app, Game Center and friend streaks.

  One nit: the Play hub shows the same Bullseye task twice (20; PlayHubGames.swift:43).
- **Monetization/paywall: 8.8 (+0.2).** The onboarding paywall now has a drifting rail, a live proof line ("617 lessons · 159 songs · 60 instruments") and three outcomes (06). It keeps the contextual Tanpura hero (40), the honest trial timeline with the day-12 reminder, exit and win-back offers, offer codes and lifetime. Against that:
  - The rail leads with Greensleeves, Clementine and Oh! Susanna. PaywallPlan.swift:127-139 puts the course's own songs before the Originals.
  - The sleeves' titles collide with the headline (PaywallPlanHero.swift:110-118 fades only from 55 % to 94 % of the sleeve, where the titles sit).
  - The Tanpura paywall's timeline sells "E minor" and "Ode to Joy".
  - There is no social proof, and no analytics ID is set (Analytics.swift:31-34: nothing leaves the device), so no paywall test can run.
- **Platform integration: 9.3 (=).**
  - Widgets and Control Center controls (TimbreWidgets.swift:322-337), a Live Activity, and a Watch app with complication and wrist metronome.
  - App Shortcuts, Spotlight, TipKit and Game Center.
  - Offer-code redemption and the manage-subscriptions sheet.
  - Full-page iPad layouts in both orientations.

  Every iPad capture shows the iPadOS 26 window-resize arc in the bottom-right corner.
- **Store readiness: 8.2 (=).**
  - The listing, keywords, age-rating audit and App Preview workflow are excellent.
  - Two store frames carry new defects (#2, #6), and iPad #2 cuts its bottom row of titles at the edge while its caption promises "oud to erhu" over a page of guitars.
  - The listing claims "49 languages (lessons in 10)", yet 989 of 5,610 lesson strings and about 390 UI strings (tools/l10n/pending.json) are untranslated everywhere.
  - The privacy URL is still TODO in the listing, and the app hard-codes a github.io URL (SettingsView.swift:395, PaywallView.swift:1392).

## 2. What stands between this and 9.5 (ranked)
1. **Clean the store set again, and add "Show me" (S).**
   - **#2 (65):** the score is caught mid-numericText ("27,?00"). It changes on every note, so the settle wait never helps. Use `.contentTransition(.identity)` while a store scene runs, or freeze the score for the frame (SongPerform.swift:262-264).
   - **#2 header:** the 40-pt sleeve prints "ORIGI…". Draw sleeves under about 72 pt with the motif only (SongCover.swift, the eyebrow and title layers).
   - **#2 chips:** the playhead line runs through "Chorus". Draw progress as a fill under the label, not a bar across it.
   - **#6 (62):** "New best" is fine, but the Share pill is half-eaten by the fade above the pinned buttons. The comment at LessonResults.swift:100-101 promises everything down to the level bar fits on a phone; the reminder row (124-128) breaks that. In the store scene, either skip the reminder row or put Share in the top-trailing corner. The mask is at 77-84.
   - **iPad #2 (ipad-landscape-instruments):** scroll the page so it ends on a whole row, and show the Folk & world strings shelf (oud, sitar, erhu) so it matches the caption "Guitar to violin, oud to erhu".
   - **All iPad frames:** capture with the simulator in Full Screen Apps mode, so there is no resize arc.
   - **New frame:** add a "Show me" capture and make it frame #3 or the App Preview's second beat. It is the visual answer to Fender's video, and it is invisible today.
2. **Ship the translations, and gate them in CI (M).** Every non-English user meets English before their first pluck:
   - The new welcome subtitle "…and a Today plan to keep you going." (OnboardingView.swift:136) exists in de and ja only in its older "daily quest" form.
   - "Cancel in 2 taps" (PaywallView.swift:926), "Strum to tune", "Show me", "3 chords or fewer" and "Campfire & kids" are missing in all 48 locales.
   - Units 17–22 of guitar and 7–10 of ukulele (989 keys) fall back silently to English in the 9 lesson languages (Curriculum.swift:11; en Learn.strings 5,610 keys against 4,622 in de, ja, fr, es, pt, ko, it, ru and zh-CN).

   Run the l10n pipeline on pending.json and the new Learn keys. Add a CI check that fails when a shipped locale lacks a key, or drop a locale from the listing until it is complete.
3. **A paywall hero without collisions that sells the modern catalogue (S).** Screens 06 and 16.
   - End the rail's mask above the sleeve titles, or crop the sleeves to their art band, so no sleeve type meets the headline (PaywallPlanHero.swift:112-118). Keep the close button on a plain field.
   - Lead the rail with 3 Originals from the plan's instrument (Kite Weather, Porchlight, Low Tide Radio), then the plan's next song. Folk classics go after them (PaywallPlan.swift:127-139 orders `ahead` before the collections).
   - Use one icon language for the outcomes (06, 16, 40).
   - On reason paywalls (Tanpura, 40), make the timeline's day-2 beat about the reason ("Day 2: drone + intonation check"), not "E minor".
4. **One guitar (S/M).** Re-render the seven `render_*` cards (InstrumentRig.swift:85) with the live stage's materials and IBL. The welcome hero (01), onboarding (05a), studio (14), custom tuning (47) and the instrument picker would then show the same dark-wood headstock the user tunes (10). Today the first thing a buyer sees is a grey, untextured-looking headstock.
5. **Ukulele parity (S for code, plus an owner asset).** Ukulele is the second course and the third tab chip, but it has three gaps:
   - **No turn arrow.** The photo stages have no turn sign (17 shows "G4" with no ↻; StudioStage.swift:13-14). Add `turns` to photo-rigs.json for soprano, concert and tenor ukulele, banjo, 12-string and baritone. The sign follows the side of the headstock, as the guitar rig's ±1 does.
   - **No "Show me"** (no usdz).
   - **No real ukulele audio** (see section 3).
6. **Make "Show me" the default teacher (S).** Today it is a small secondary pill (06b, 51, 53). The first time a chord or strum pattern appears in a course, auto-play the demonstration once after the card settles. Fall back to the picture under Reduce Motion or Low Power, as ShowMe.allowed already does. Add a one-line caption ("Watch the fingers land in order").
7. **Get the bowed instruments right (S).**
   - Label the strum control "All strings" or "Pluck all" for `bowed_strings` (StrumTuneView.swift:537; AppStore.swift:1082).
   - Fix the peg mapping (bug 7).

   A violin teacher would spot both in ten seconds.
8. **Make lesson titles agree (S).** On the iPad outline, E minor's step 4 is "Tap on the dots · 70 BPM" (LessonInspector.swift:444-447). The player titles the same step "Strum on the arrows" (LessonSteps.swift:923-926), so steps 4 and 5 read identically (54, then the Em strum). Give the instrument-course tap step its own title ("Strum the open strings"), and use the same function in the outline and the player.
9. **iPad finish (M).**
   - ipad-portrait-learn: the instrument rail is hard-clipped mid-word at its column edge ("Violir"). Fade it (EdgeFadeMask) or size its cards to whole cards.
   - ipad-*-practice: the level card's lower half is empty, and so is the space under the single quest. Fold the quest into the Today card, or add the weekly ring and the next badge.
   - ipad-landscape-tune: the headstock is cut at the left screen edge, and Strum and Pause sit on the panels' border.
   - ipad-*-songs: "Up next" has an empty bottom third. Show 4 rows, or the next unlock.
10. **Small polish (S each).**
    - The Play hub shows the same Bullseye quest twice (20; PlayHubGames.swift:43). Hide the quest row when its game card shows it.
    - The Originals shelf reads 01, 02, 03, 04, 06 because the hero is removed from its own album (SongsView.swift:1331). Keep it in its shelf, or don't print numbers.
    - On 05a2, "Great work" keeps the two-line title's height, leaving a 140-pt gap (FirstTuneStep.swift:179-180).
    - "−10¢ · 81.92 Hz" sits over "Tighten · 10¢ flat", which repeats the cents (10, 14, 17; TuneView.swift:420). Say "Tighten" alone there.
    - "Originals  Song 2:40" (63) should read "Originals · 2:40".
    - The drone dial's "A♭" label pill sits on the tanpura strings (41, 42).
    - The chromatic Pause overlaps the dial bezel (15).
    - Ear training's segmented control is the system grey, unlike every other chip (23).
11. **Guitar depth (owner and L).** 132 guitar lessons (680 min) is real, but Fender Play and Yousician advertise thousands. Spend the next content wave on song-led units (one Original per unit, with a riff, a strum and a lead part), not more theory.

## 3. Outside assets / owner decisions
- **Song licensing.** The catalogue is public domain plus 50 house Originals. Yousician, Simply Guitar and Fender sell on recognisable songs. A licensing deal, even 20–30 well-known tracks (via a partner such as Hal Leonard or Songtradr), is the largest conversion lever left. Failing that, produce real band recordings for the Originals' "Preview with band" and the store video.
- **Recordings.** These are needed for honest "Hear it" audio:
  - ukulele (today nylon-guitar stand-ins);
  - mandolin (a Martin steel guitar, thinned);
  - banjo and sung voice (both synthesized);
  - a solo cello (today a VSCO cello *section*);
  - a multi-velocity flat-top guitar.

  All of these are in AUDIO-SOURCES.md, Stand-ins and Instruments.
- **Teaching media.** Either a rigged hand for "Show me", or teacher video for guitar and ukulele Unit 1–2. That is the remaining gap to Fender Play and Simply Guitar.
- **3D models.** A ukulele and a 5-string banjo usdz (CC-BY like the others, or commissioned).
- **Privacy policy.** Host it on the custom domain, then update the listing and both hard-coded links (SettingsView.swift:395, PaywallView.swift:1392). Until then, confirm the github.io page is live; a dead link is a 5.1.1 rejection.
- **Analytics.** Set `TimbreTelemetryAppID` before launch (Analytics.swift:31-34). Without funnel data (onboarding → paywall → trial → convert) nobody can tune the paywall to reach $10k a month.
- **Translation review.** Human review of the 9 lesson languages after the backfill.
- **Pricing.** Run a test: lifetime at $89.99 is 2.6× the yearly price. Also gather pre-launch social proof (TestFlight quotes, a teacher endorsement) for the paywall and the listing.
- **Violin and cello pegs.** Have a player confirm the layout (bug 7) before the bowed instruments are marketed in the iPad frame.

## 4. Bugs (with evidence)
1. **Store #2 (65): the score is captured mid-transition** ("27,?00", the hundreds digit ghosted). `Text(points).contentTransition(.numericText…)` with `Motion.quick` re-animates on every note (SongPerform.swift:262-264).
2. **Store #6 (62): the Share pill is half hidden** under the fade above "Next lesson". The 28-pt fade mask sits over the pinned buttons (LessonResults.swift:77-84). The reminder row (124-128) pushes "New best / Share" below the fold, against the layout promise at 100-101.
3. **06: sleeve titles collide with the headline.** "OH! SUSANNA" sits directly on "Unlock your full plan", "…sleeves" pokes out at the left edge, and the pill and the close button sit on the sleeves. The mask is solid down to 55 % of the sleeve and clears only at 94 % (PaywallPlanHero.swift:112-118), which is exactly where the sleeve titles are printed.
4. **Localization drift.**
   - 989 Learn keys are missing in de, es, fr, it, ja, ko, pt, ru and zh-CN (5,610 against 4,622). Missing keys fall back to English silently (Curriculum.swift:11).
   - The current welcome subtitle (OnboardingView.swift:136) is absent from de.lproj, which has only the "daily quest" variant at Localizable.strings:1158.
   - "Cancel in 2 taps" (PaywallView.swift:926) is absent from all locales.
   - 392 UI strings are queued in tools/l10n/pending.json.
5. **The lesson outline and the player disagree.** The outline says "Tap on the dots · 70 BPM" (ipad-landscape-learn; LessonInspector.swift:444-447). The player says "Strum on the arrows · 70 BPM" (54; LessonSteps.swift:923-926), then "Strum on the arrows" again for step 5.
6. **The Originals shelf numbering has a hole** (01, 02, 03, 04, 06 on ipad-portrait-songs). The hero is filtered out of its own course shelf (SongsView.swift:1331).
7. **Violin and cello peg mapping looks inverted** (verify with a player). violin.rig.json puts G on the peg farther from the nut (pegCenter y 0.539, against D at 0.516) and E above A (0.548 against 0.525). cello.rig.json does the same (C 1.348 against G 1.293; A 1.371 against D 1.320). On a standard pegbox the outer strings (G and E, C and A) take the pegs nearest the nut, as this app's own guitar and mandolin rigs do. So 49b rings the D peg for "Play G3", and 49c rings the G peg for "Play C2".
8. **"Strum" on bowed instruments** (49b, 49c). `canStrumTune` includes `bowed_strings` (AppStore.swift:1082), and the caption is fixed as "Strum" (StrumTuneView.swift:537).
9. **No turn-direction arrow on any photo-stage instrument**, ukulele included (17 shows "G4" while 10 and 19 show "E2 ↻" and "E1 ↻"). StageCard `turns` is empty for photographs by design (StudioStage.swift:13-14), and photo-rigs.json has no turn data.
10. **ipad-portrait-learn: the instrument rail is cut mid-word** at the column edge ("Violir 0/38 le").
11. **The Play hub repeats one task.** "Win a round of Bullseye +30 XP" appears under Today's quests and again as Bullseye's "Today's challenge" (20, ipad-*-practice; PlayHubGames.swift:43).
12. **The acoustic guitar has two looks.** `render_guitar_acoustic` has a grey headstock face with gold tuners (01, 05a, 14, 47). The live usdz shows dark wood with dark buttons (10, 10b, 90).
13. **Capture gap: 45-journey-pro.png is byte-identical to 32-journey.png.** The Pro state of Progress, with its accuracy chart, is never captured or checked.
14. **Minor overlaps:**
    - The chromatic Pause sits on the dial bezel (15).
    - The drone dial's "A♭" pill sits on the tanpura strings (41).
    - The highway's "Next" pill overlaps the card's bottom edge (59, 60).
    - The scales neck's 6th string is hidden under the floating buttons at rest (44).
    - "Thinnest (1)" crosses the notes ring (56).
