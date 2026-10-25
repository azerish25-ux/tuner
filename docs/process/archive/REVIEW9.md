# Timbre: review 9 (59 screenshots, iPhone 17 Pro sim)

## 1. Scores
**Overall: 8.6 / 10.** This is a serious, coherent product, and nothing else in the category has a tuner this good. It is held back from 9.5 by three visible defects in the conversion funnel, song lessons that feel generic, and several screens that are just dark cards with an SF Symbol in them.

| Area | Score | One line |
|---|---|---|
| Visual design & polish | 8.5 | "Studio Noir" is consistent and the 3D headstocks look premium. But onboarding overlaps text right before the paywall, and Play hub, Drone and Intonation look bare. |
| Motion / delight | 8.5 | First-tune reward, peg ring with turn arrow, highway combo and star results all land. There is no signature moment inside lessons or songs. |
| Tuner | 9.2 | 3D pegs, strobe, Strum to tune (polyphonic), string health, 60 instruments and courses are already ahead of GuitarTuna and Fender. Strum lanes need clearer colour semantics. |
| Lessons & curriculum | 8.3 | 499 lessons, 13 courses and mic-graded steps make it broad and correct (all chord and scale diagrams checked). Song lessons open on a generic strum card, and string orientation flips within a lesson. |
| Retention / habit loop | 8.6 | Daily set, quests, XP levels, streak freeze, 42 badges, weak-spot review, in-context reminder and week share. There is no personal "coach voice" turning data into advice. |
| Monetization / paywall | 8.4 | Personal plan outcomes, trial timeline, lifetime option and a free-tuner exit are solid. The hero is not feature-specific, there is no price anchor, and the timeline label is broken. |
| Platform integration | 8.0 | 3 widgets, Live Activity/Dynamic Island, 2 Controls, App Intents with snippet. Missing: Watch, Spotlight entities, configurable widgets, TipKit. |
| Store readiness | 8.6 | The listing is complete with a scripted screenshot pipeline and counts checked against the build. Review notes are stale and keywords leak value. |

## 2. What stands between this and 9.5 (ranked)
1. **Fix the funnel defects first (S).** Screenshots 05b and 06. Files: `Onboarding/OnboardingView.swift:424-451, 494-514` and `Paywall/PaywallView.swift:631-634`. The user should see a clean "Your plan" header with the lesson title above its unit label, and the trial timeline should read "Day 2 · Play “Greensleeves”" on at most two lines. These are the last two screens before the purchase decision.
2. **Give song lessons a song-specific opener and a finale (L).** Screenshots 63 and 64. Files: `Learn/LessonExplain.swift:57-90` (visual for `kind == .song`), `Learn/LessonPlayer.swift:42-50`, `Songs/SongsView.swift:101-108`, `Audio/Band.swift`.
   - **Opener:** the cover zooms into a "song sheet" showing key, BPM, a chord strip (G–D–Em–C with mini diagrams), a section map (Intro/Verse/Chorus) and a "Preview with band" button.
   - **Finale:** the last step is a full "Perform" take over the band, with score, stars and a story-sized share card.
   - This is the moment that sells Pro, and today it looks like any other lesson.
3. **Keep one string orientation through a lesson (M).** Screenshots 52, 53–55, 56 and 59. Files: `Learn/LessonMotion.swift:85` (the strum stage always puts the thickest string on top), `Learn/Diagrams.swift:129`, `Learn/Highway.swift:847`. The strum/soundhole stage and the tune-check rail should follow Settings › String order like the fretboard does, and a one-time TipKit coach mark should say "String 1 = thinnest, on top". Beginners currently see the neck flip between steps.
4. **Turn the Play hub tiles into live previews (M).** Screenshot 20. File: `Practice/PracticeView.swift:119+`.
   - Pitch Sniper: an idling scope sweeping across cents rings.
   - Ear trainer: an animated interval staircase.
   - Every tile shows best score, level, a "Today's challenge" chip and its XP.
   - Tools get live glyphs: a ticking pendulum, a drone ripple.
5. **Make paywall heroes feature-specific and add a price anchor (M).** Screenshots 40, 16 and 06. File: `Paywall/PaywallView.swift:300-309` (`heroFigure` only knows instruments).
   - The Drone paywall opens on pulsing tanpura strings, and an ear-game paywall on the sniper scope.
   - The yearly row shows ~~$83.88~~ $34.99.
   - A "What's in Pro" disclosure opens a 6-row Free vs Pro table.
6. **Make the Drone a real tanpura (M).** Screenshots 41 and 42. File: `Practice/DroneView.swift`. Four strings (Pa–Sa–Sa–Sa) pluck in cycle with visible vibration around a tonic dial. With the mic on, the player's pitch draws a live trace against the drone inside a ±5¢ band ("held 8 s"). Today the screen is one orb.
7. **Deepen the Chords & Scales library (M).** Screenshots 43 and 44. File: `Practice/ChordsView.swift:99` (`voicingCard`) plus the scales neck.
   - Voicings get names ("Open", "Barre · 3fr", "Triad · 8fr"), a difficulty and a strum animation on tap.
   - A "Check it" button reuses the lesson chord listener.
   - Scales show the 12-fret neck with CAGED position pills 1–5 and a "Play along" mode that lights each note as you hit it. Today it shows one 5-fret box.
8. **Add on-device coach notes (M).** Screenshots 62, 32 and 33. Files: `Learn/LessonResults.swift`, `Journey/WeekRecap.swift`, `Journey/JourneyView.swift`. Examples: "Em→C was 410 ms late on beat 3, so try the 45 BPM loop" and "G drifts 7¢ a day, so restring". Use FoundationModels on iOS 26 devices with a template fallback. The data (timing strip, string health, weak spots) is already collected; it just never speaks.
9. **Deepen platform integration (M; Watch is L).** Files: `TimbreWidgets/TimbreWidgets.swift:70-175`, `Intents/InstrumentEntity.swift`.
   - `AppIntentConfiguration` widgets (choose an instrument or Next song).
   - Spotlight-indexed songs, lessons and instruments (`IndexedEntity`).
   - TipKit for Strum to tune and manual string mode.
   - A StandBy-friendly metronome.
   - An Apple Watch haptic metronome with a streak complication.
10. **Make Strum to tune clearer (S).** Screenshot 11b. Files: `Tune/StrumMeters.swift:137`, `Tune/StrumTuneView.swift:260-264`. Lanes should be neutral, with colour only for status (mint when locked, amber when off) and string identity on the label chip. Replace the "Hollow: approximate…" sentence with a "≈ estimate" badge. When 5 of 6 strings lock, the last lane should zoom into the single-string fine-tune with a matched transition.
11. **Finish the highway (S/M).** Screenshots 59–61. Files: `Learn/Highway.swift:847`, `Learn/HighwayHUD.swift`, `Learn/HighwayPop.swift`. Remove the duplicated lane labels. Use bigger gems with finger numbers, a hit-line burst and lane flash on Perfect, and board colour tiers by combo. On the results screen, a per-note strip should loop the missed bar when tapped.
12. **Merchandise the Songs tab (S).** Screenshot 63. File: `Songs/SongsView.swift` (tiles around line 515). Stop printing the title twice under the covers. Add difficulty dots, length and chord chips ("G D Em C"), plus shelves for "Because you learned E minor" and "3 chords or fewer".
13. **Raise the type floor in diagrams (S).** Screenshots 46, 52, 56 and 59. Files: `Learn/Diagrams.swift:116, 221, 348`, `Practice/IntonationView.swift`. String names, fret numbers, "Saddle" and lane names render at about 9–10 pt. Set a floor of 11 pt relative to `.caption2`.

**Needs outside assets or an owner decision**
- Licensed popular songs: the biggest perceived-value gap against Yousician and Simply Guitar. Originals and public-domain songs alone will cap conversion.
- Filmed or recorded instructor demos per unit, and an illustrator pass on badges, ear-game art and alternate icons.
- Real ratings, testimonials and press quotes for the paywall and store page. The privacy policy URL in the listing is still a placeholder.
- A pricing and trial test (14 vs 7 days, $34.99 vs $44.99), plus intro, win-back and offer codes set up in App Store Connect.

## 3. Bugs
- **05b-onboarding-plan:** "Your plan" overlaps its subtitle, and "The mini F" overlaps "UNIT 7 · SONGS WITH CHORDS" (captured after a 2 s settle). File: `OnboardingView.swift:424-451, 494-501`. Suspect: the `repeatForever` `withAnimation` in `onAppear` (l.427) leaks into layout, together with `.contentTransition` and `.animation(value: start?.id)` (l.514). Scope the float to the art with `phaseAnimator`.
- **06-paywall-onboarding:** the Day 2 milestone reads "Play “Greensleeve / s: the chord…". It breaks mid-word, and it uses the lesson title ("Greensleeves: the chords") instead of the song name. Files: `PaywallView.swift:633-634`, `PaywallPlan.swift` (milestone title).
- **64-songs-lesson:** the first step of a song lesson is still at about 30% opacity 1.5 s after opening, so the text is almost unreadable. File: `LessonExplain.swift:85-86`. The reveal is a `withAnimation` in `onAppear` inside the zoom `fullScreenCover` (`SongsView.swift:101-108`). Lessons opened from Learn render fine.
- **52 → 53/54 → 56:** with the default Tab order, the strum stage puts the thickest string on top while the fretboards put the thinnest on top. File: `LessonMotion.swift:85`.
- **24-voice-range:** contour labels use sharps (C#3, D#4), while the tuner, drone, chords and scales use flats (Db, Eb). Files: `VoiceView.swift` / `VoiceKeyboard.swift`.
- **40-paywall:** "Unlock the Tanpura drone" shows a guitar note-highway hero. File: `PaywallView.swift:300`.
- **59/60:** highway lane labels are doubled ("1" over "Thinnest (1)", "6" over "Thickest (6)"). File: `Highway.swift:847`.
- **11b:** the low-E lane is drawn red while it is in tune (−3¢ ✓), which reads as an error. File: `StrumMeters.swift`.
- **63-songs:** each Originals tile prints its title twice, once on the cover and once in the caption ("Porchlight / Porchlight"). File: `SongsView.swift`.
- **21/22, 43, 44, 12:** horizontally scrolling chip rows ("7/4", "sus…", "…al minor", "Open G", "Bowe…") hard-clip at card edges. The welcome screen's fade mask (`OnboardingView.swift:797-810`) should be reused.
- **`APP-STORE-LISTING.md:120`:** the review notes say "Practice → Drone", but the tab is "Play". At l.18, keywords spend characters on "music" (a category word) and the plural "songs", against the doc's own singular rule.
