# Timbre: Review 12 (independent, strict)

## 1. Scores

**Overall: 8.4 / 10.** The tuner is the best in its category, and the app is cohesive and premium. It loses the 9.5 bar on content and sound (unknown songs, a synthesized band) and on a few visible rough edges, one of them on the money screen.

- **Visual design & polish: 8.6.** The dark stage, mint and gold palette, Sora type and studio-lit 3D headstocks are a real identity. Points come off for a broken paywall card, three string orientations, dense 10 to 11 pt captions and empty iPad space.
- **Motion & delight: 8.6.** There are 4 Metal shaders (lock shimmer, strobe ripple and lamp, heat star), spring tokens (Theme.swift:217), zoom transitions, fingertip landings, a Core Haptics engine and the island reward pill. All of this is judged from code, so it is unproven in screenshots.
- **Tuner: 9.3.** It beats GuitarTuna and Fender Tune. It has polyphonic "Strum to tune" (11b), a strobe, 60 instruments and 102 tunings, a 3D peg lock, string health drift, intonation, temperaments and custom tunings. The one weakness is the unlabeled header ring ("5").
- **Lessons & curriculum: 7.6.** There are 557 lessons that listen, with a highway, chord recognition, strum timing and engraved sheets. Against Yousician, Simply Guitar and Fender Play it has no human or video teaching and no song a user knows (50 Originals plus nursery or classical public-domain songs), and the band is synthesized (see #1).
- **Retention / habit loop: 8.6.** It has a Today plan, quests, XP and levels, streak plus freeze, 42 badges, a coach, string health, reminders, a Live Activity, Song of the day and a share card. It has no social layer, and the spaced review is a TODO.
- **Monetization / paywall: 8.0.** The paywall is personalised, with a trial timeline, win-back and offer codes. Against that, the yearly card renders broken, the price is low for a lesson app, and a $89.99 lifetime plan cannibalises the yearly.
- **Platform integration: 9.2.** Widgets, Controls, Live Activity, a Watch app with widgets, App Intents, Spotlight, TipKit, Game Center, MusicKit, a Foundation Models coach and Liquid Glass are all present.
- **Store readiness: 8.0.** The listing, captions and preview workflow are done. Missing or weak: the privacy URL is a placeholder, the screenshot set has mixed seed states, the strongest differentiator (11b) is not among the screenshots, and the Songs shot is weak.

## 2. What stands between this and 9.5 (ranked; all doable in this repo)

1. **(M) Ship the recorded band and instruments.** The bundled `Resources/Samples/manifest.json` lists only `guitar` (AUDIO-SOURCES.md: "0.8 MB in 16 files"). The 70 piano and 26 bass m4a files are in the bundle but unreferenced, and there is no drum kit. So "Preview with band", play-alongs and progressions (64, 59–61) fall back to `BandSynth` (sine-drop kick, noise snare, detuned pad), and violin and cello "Hear it" use `ToneSynth`. The fix:
   - Run `tools/build-ios-samples.py` for piano, bass, drums, violin, cello and harp. They are CC0 and pinned, and fit inside the 35 MB budget.
   - Make `verify-ios-resources.py` fail on orphan folders or a missing drum set.
   - Result: users hear a real kit, bass and grand piano under every song.
2. **(S) Paywall plan card (06, 16, 40).** "Yearly" wraps as "Year-/ly" next to the SAVE 58% chip (PaywallView.swift:827). The fix is `.lineLimit(1).fixedSize()` with layout priority, and the chip moves under the price if space is short. The mint "14 DAYS FREE" tag is cut in half because it is offset −10 pt inside the `TimbreGlassGroup`, which clips it (lines 754, 842–844 and 862–865). Draw the tag outside the glass container, with z-index above it.
3. **(M) One string orientation, with Chart as the default.** One lesson currently shows four layouts:
   - a vertical neck with the thinnest string on the left (51, 52b, "Player view", the default at PlayerNeck.swift:40);
   - tab boxes with string 1 on top (52, 56, 57, and Scales 44; Diagrams.swift around 158–260);
   - a horizontal strum neck with string 6 on top (53–55; LessonMotion.swift:70 and 293);
   - and a Learn preview that draws the same Em as a mirrored chart (LessonInspector.swift:306).

   Make `ChordPicture` drive every neck. Default to Chart, the songbook and Yousician convention, with Player view as an opt-in.
4. **(M) Songs tab above the fold (63, iPad songs).** On iPhone the catalogue starts below the hero plus a 6-line empty "Your songs" explainer, and "Add a song" appears twice. Collapse the empty state into one row placed after the first shelf so two shelves show on the first screen. On iPad, fill the hero's empty left 60% with the song map and a chord strip (SongsView.swift around 114; YourSongsShelf.swift).
5. **(S) Store screenshot set.** Polyphonic "Strum to tune" (11b) is the single feature GuitarTuna can't match, and it is missing from the caption table (APP-STORE-LISTING.md:94). It should replace #7, the instrument browser. The captures also need fixing:
   - Seed one state for every capture. Streaks currently show 7 with a grey flame in 10b and 32 but 8 in 50, 62 and 63.
   - Wait for the animations to settle before capturing. The Em fingertips have not landed in 51, the XP counter is mid-count in 62, and the outcomes are mid-stagger in 06.
6. **(S) The Voice exercise rail clips its selected first card.** The 24 shows "…st" at the left edge. `EdgeRail` centers the selection (PracticeChrome.swift:45 and 67, `anchor: .center`) and pushes card 1 past the bleed. Use a leading anchor for the first item, or clamp.
7. **(S) False onboarding promise (05b).** "You skip Units 1–6. They stay open for a refresher." (OnboardingView.swift:502) is untrue on the free plan, where Units 2–6 are Pro (`AccessPolicy`). This is a trust hit one screen before the paywall. Say they unlock with Pro, or show the lock.
8. **(M) Dashboard legibility.** The Play (20), Progress (32) and Today cards use 10–11 pt inkFaint captions ("+20 XP", "resets in 24 h", "Average ¢ off"), which miss 4.5:1 contrast. Raise the caption tokens to 12–13 pt and fix the copy. Label the header ring "Lv 5", which on every tab is currently a bare "5" in a circle.
9. **(S) Floating tab bar.** Body text and mint CTAs read through the glass (20 shows "Ear training 38 correct", and in 63 the bar tints mint). Add a soft scroll-edge effect or bottom fade, plus a content margin, in the root tab container.
10. **(M) Spaced review.** PracticeView.swift:465 is still `// TODO: open the due review itself`. Build a 3-minute "Review" from missed quiz and along items (the "Practice weak spots" data already exists) and put it in the Today plan. It is a Duolingo-grade retention lever.
11. **(M) A social layer through Game Center.** GameCenter.swift has leaderboards only. Add Challenges for Pitch Sniper and song scores, with "Challenge a friend" on the results screen (62) and on Pitch Sniper (20), plus a friend streak on the Progress share card.
12. **(M) iPad Tune composition.** In landscape the right half is empty; in portrait the headstock takes about 65% and the readout is pushed to the bottom third. Add a right-hand pane with a live cents trace (reuse `VoiceTrace`) and string health, keeping the readout centred in its column.
13. **(S) Ear training (23) is the plainest screen in the app.** It shows a generic waveform orb and an empty "Recent" list. Reuse the Play hub's interval staircase as the answer visual, reveal note names and the interval after each answer, and prefill Recent with one example.
14. **(S) Song covers (iPad songs).** The play button moves between bottom-right and top-right from cover to cover, and the instrument avatar clusters ("+3", "+1") collide with the title and play button. Fix one grid (index top-left, play bottom-right) and move the instruments under the art next to the chord chips (SongCover.swift).

**Outside assets and owner decisions:**
- License recognisable songs (SONG-LICENSING-PLAYBOOK stage 1). This is the largest content gap against every competitor.
- Add human teaching: short filmed or 3D-animated hand clips for the chords, strumming and barre lessons.
- Pricing: $34.99 a year and $89.99 lifetime are well under the $90–180 lesson apps charge. Test $49.99–59.99 a year with a 7-day trial, and set lifetime at $149 or more, or drop it.
- Host the privacy and support pages on a custom domain. The app links a personal github.io page, and the listing still says `<privacy policy URL>` (line 63).
- Collect early ratings and reviews and press quotes to use as paywall social proof.

## 3. Bugs

- **Paywall yearly card (06, 16, 40):** the "Year-/ly" wrap and the clipped "14 DAYS FREE" tag. PaywallView.swift:754, 827 and 862.
- **Voice rail (24):** the selected card is clipped at the leading edge. PracticeChrome.swift:45 and 67.
- **Custom tuning chip (48):** the chip truncates to "My tuni…" inside a horizontal scroller. The fix is `.fixedSize()` on the label at InstrumentsView.swift:237. The eyebrow also switches between "TUNINGS" and "ACOUSTIC GUITAR TUNINGS".
- **Same chord drawn mirrored:** the Learn preview (iPad Learn) draws Em as a chart (string 6 on the left), and the lesson opens it in Player view (string 1 on the left). LessonInspector.swift:306 ignores `ChordPicture`.
- **Samples:** about 5 MB of piano and bass audio ships unreferenced in the manifest, and the drum, violin and cello sets are missing. `Resources/Samples/manifest.json`, `tools/build-ios-samples.py`.
- **Onboarding (05b):** the copy is factually wrong for free users. OnboardingView.swift:502.
- **Store listing:**
  - The description contains a stray, unpunctuated internal note: "The trial timeline is on the paywall" (line 57).
  - The privacy URL is a placeholder (line 63).
  - The age-rating line (13) uses the old "4+" wording. Answer Apple's current questionnaire, which now asks about user-imported charts.
- **Screenshot inconsistency:** the streak shows 7 in one capture and 8 in another, and the flame colour also changes, across captures that go to the store (10b vs 50/63; 32 vs iPad Progress).
