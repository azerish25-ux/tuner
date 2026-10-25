# Jury 15: Inclusivity

Juror: accessibility lead. I audited against Apple's accessibility guidance (VoiceOver, Dynamic Type, Increase Contrast, Reduce Motion and Transparency, Differentiate Without Colour, Bold Text, Smart Invert, Voice Control, Switch and keyboard access) and WCAG 2.2 AA. I worked from the code in `/home/claude/tuner/ios` and the review15 frames.

Contrast ratios were computed from `Design/Theme.swift`. Pixel ratios were sampled from the PNGs, and colour-blind separation was simulated with the Machado 2009 matrices (CIELAB ΔE). The scripts are in `scratchpad/inclusivity/`.

---

## 1. Score: **8.3 / 10**

**Verdict.** Timbre has the most deliberate accessibility work I have seen in a music-learning app.
- **Tuner.** It is genuinely usable with VoiceOver. It speaks the note and cents about every 1.5 s, announces the lock and plays a distinct haptic for it. Each pitch state carries words, a sign and a symbol, and the three-zone colour rule survives every colour-vision deficiency.
- **Tokens.** Every text token passes 4.5:1, and the tokens answer Increase Contrast by themselves.
- **Motion and layout.** A single Reduce Motion policy runs through 65 files, and the shared kit restructures for the accessibility text sizes.
- **Chords.** Chord boxes are spoken as finger placements in finger order.

No competitor comes close on any of that. But Inclusivity is judged on the whole promise ("tune *and learn*"), and here the app still fails people:
- **Blind learners.**
  - VoiceOver users cannot do the play-along at all. It is one opaque element saying "Play-along, 6 notes".
  - VoiceOver focus is never moved when a step changes.
  - The results screen hides the star count.
  - Neither the first-run tune nor the in-lesson tune check gives any spoken guidance until "In tune".
- **Left-handed players.** "Handedness" reorders only the tuner's chips and the strum meters. Every chord box, neck, runway, strum stage and 3D model stays right-handed, which Yousician, JustinGuitar and GuitarTuna already handle.
- **Other languages.** 26 % of the interface (474 of 1,819 strings) is English in all 48 non-English locales. That includes the paywall's renewal terms and the VoiceOver chord descriptions. 20 % of the lessons are English in the nine lesson languages.
- **Evidence.** Nothing is verified by an audit, an AX5 frame, an RTL frame or a German frame.

These are visible seams, so this is not yet an ADA Inclusivity finalist. It is clearly #1 among its competitors on this angle.

---

## 2. Head-to-head on Inclusivity

| Competitor | Who wins | Why, with evidence |
|---|---|---|
| **GuitarTuna** (Yousician Ltd) | **Timbre**, but it loses on left-handed use | GuitarTuna has declared no accessibility features: its App Store Accessibility section reads "The developer has not yet indicated…". AppleVis's 2025–26 tuner threads, where blind guitarists look for a usable tuner, don't recommend it. GuitarTuna does ship a "Left-hand mode" that switches the whole app. Timbre's announcer (`Tune/TunerVoiceOver.swift:10-49`), its Differentiate Without Colour marks (`Tune/Readout.swift:13-38, 344-349`) and its contrast tokens (`Design/Theme.swift:9-33`) beat it outright. On left-handed use, Timbre's setting is skin-deep (§3 item 2). |
| **Fender Tune** | **Timbre**, decisively | AppleVis rates Fender Tune as usable only with workarounds: few buttons are clearly labelled, and voice feedback while tuning is unreliable. It has declared no accessibility features and mentions no left-handed mode. Timbre's tuner reads each string chip as "String 4, D3" with a "Tuned" value (`Tune/StringRail.swift:236-246`). It speaks the cents on a settle-and-interval schedule and has its own lock haptic pattern (`TunerVoiceOver.swift:63-73`). |
| **Fender Play** | **Timbre** | Fender's own support says there are no left-handed lessons and suggests lefties "watch the videos as a mirror image". Its lessons are video, with no flipped tab. Timbre's chord boxes are spoken (`Learn/Diagrams.swift:706-744`), and its lessons are short, plain sentences ("The thickest string is the lowest. It sits nearest your face…", curriculum unit 1). |
| **Yousician** | **Timbre** overall; **Yousician** on left-handed use | Yousician has a real Left-handed mode in the Game tab that flips the hand graphic and mirrors the chord charts. Timbre has nothing equivalent outside the tuner. Yousician's AppleVis entry (2018) says it is not usable with VoiceOver: unlabelled buttons, and setup needs sighted help. It has declared no accessibility features. Its game-runway core has the same blind-player problem as Timbre's highway (`Learn/Highway.swift:145-146`), but Timbre's surrounding flows are far more accessible. |
| **Simply Guitar** | **Timbre** | Simply Guitar has no left-handed mode. Its help article tells lefties to play right-handed, restring, or flip the diagrams themselves via leftyfretz.com. It has declared no accessibility features. Timbre's plain language, Differentiate Without Colour, Reduce Motion and VoiceOver depth exceed it on every axis except left-handed use, where both are weak and Timbre at least mirrors the tuner. |
| **JustinGuitar** | **Timbre**; JustinGuitar is ahead only on left-handed song display | A May 2024 community thread reports the iOS app is "completely inaccessible with VoiceOver", even at login, with no staff reply. JustinGuitar does have "Left Handed Mode" under a song's Display Options (Nov 2025 thread). |

All six competitors leave the App Store "Accessibility" (nutrition label) section empty. A truthful, complete label is a free, visible differentiator that Timbre also hasn't claimed (§3 item 11).

---

## 3. Everything that costs points, ranked

### 1. Blind musicians can tune but cannot learn. Severity: **blocker** · Size: **L**

**Where:** 59/60 along-ready and along-playing, 52 lesson-tunecheck, 05a onboarding-first-tune, 62 lesson-results.

**What's wrong:**
- **Play-along.** The runway is collapsed to one element: `.accessibilityElement(children: .ignore).accessibilityLabel("Play-along, \(take.count) notes")` (`Learn/Highway.swift:145-146`).
  - Nothing speaks the next note or chord during a take. The "Next D3 · String 4, open" row (`Highway.swift:339-363`) is reachable only by swiping, which is impossible with both hands on the instrument.
  - The only per-note feedback is a haptic on a Perfect (`Highway.swift:713`). A miss is silent.
- **Step changes.** There is no focus management anywhere: zero `AccessibilityFocusState` / `.accessibilityFocused` / `.screenChanged` in the app.
  - Steps advance by themselves after a heard success (`Learn/LessonSteps.swift:819-828`, `316-330`).
  - VoiceOver focus is left on a removed element, and the new `StepTitle` (`Learn/LessonPlayer.swift:476-492`) is never read.
- **Tuning outside the Tune tab.**
  - The first-run tune posts only "In tune" (`Onboarding/FirstTuneStep.swift:378`).
  - The lesson tune check posts nothing (`LessonSteps.swift:1734-1760`: the hint is a plain `Text`).
  - So a blind user's very first task gives no tighten/loosen guidance, although `TunerAnnouncer` exists.
- **Results.** The stars are `accessibilityHidden(true)` with no replacement (`Learn/LessonResults.swift:601`). Every other screen says "\(n) of 3 stars" (`LearnView.swift:517`, `SongsView.swift:1022`).

**Fix:**
- **Play-along.** Add a "Spoken cues" mode, on by default when `accessibilityVoiceOverEnabled`:
  - In `Highway.tick`, one beat before each note, post `AccessibilityNotification.Announcement` with priority `.high` (iOS 17 `AttributedString` `accessibilitySpeechAnnouncementPriority`). Content: chord name or "D, string 4 open".
  - Duck the band, or offer a "half-speed with speech" rung.
  - Play earcons on each judgement: a soft tick for good, a low thud for a miss.
  - Haptic count-in on every count-in beat.
  - Announce the result line ("5 of 6, 2 perfect") on finish.
- **Step changes.** Add `@AccessibilityFocusState var titleFocused` to the lesson player. Set it on `run.index` change and post `.screenChanged` with the step title.
- **Tuning outside the Tune tab.** Instantiate `TunerAnnouncer` in `FirstTuneStep` and `TuneCheckStep` and feed it each frame, as `TuneView.announce()` does (`TuneView.swift:157-163`).
- **Results.** Replace line 601 with `.accessibilityElement(children: .ignore).accessibilityLabel(Text("\(result.stars) of 3 stars"))` on the stars' `HStack` (lines 122-124).

### 2. The left-handed setting is cosmetic. Severity: **major** · Size: **M–L**

**Where:** 13 settings ("Handedness"), 52b lesson-chord, 55 lesson-strum, 59/60 along, 10 tune-3d.

**What's wrong:**
- **What it changes.** `handedness` is read in exactly two places: tuner chip order (`Tune/StringRail.swift:16`) and strum meters (`Tune/StrumModel.swift:325`).
- **What stays right-handed.** Everything a learner looks at:
  - `StringOrder.upright` is a constant ("Not a choice: the same always", `Learn/Diagrams.swift:79-82`), so chord boxes, `PlayerNeck` and the play-along lanes are right-handed for everyone (`PlayerNeck.swift:19-21`).
  - The strum stage puts the soundhole and neck on the right-hander's side.
  - The Scales and Intonation necks put the nut on the left.
  - The Show Me 3D hand is a right hand.
  - The tuner's 3D headstock and its peg cues (`Stage/PegCue.swift:9-19`, the turn sign comes from the right-handed rig) show the wrong peg side for a left-handed instrument.
- **Discovery.** The setting is not offered in onboarding (01–05b).
- **Competitors.** Yousician mirrors charts and the hand, JustinGuitar mirrors the song fretboard, and GuitarTuna has an app-wide left-hand mode.

**Fix:**
- **Onboarding.** Ask once, after the instrument choice: "Which hand strums?" (Right / Left / Left, strung upside-down).
- **One mirror flag.** Add `isMirrored` to the environment, and apply `.scaleEffect(x: -1)` with un-mirrored text layers (or mirrored x-coordinates in the Canvas draw code) in:
  - `ChordDiagram`, `PlayerNeck` and `HighwayRunway.Lanes`;
  - `FretboardDiagram`, the Scales and Intonation necks, and the strum stage;
  - the studio and photo stage cards.
- **3D stage.** Flip the camera's x axis (or the model's root `scale.x = -1`, with the winding of culled faces fixed). Negate the rig's `tighten` sign.
- **Show Me.** Mirror the hand rig.
- **Upside-down lefties.** Keep the string *labels* (1 = thinnest). Their string order is reversed relative to the mirror, so it needs its own `StringOrder` case. No competitor serves this group (Hendrix and Albert King players).

### 3. Localisation is a quarter English in every locale, and the tooling loses translations. Severity: **major** · Size: **M** (code), **L** (owner)

**Where:** `docs/l10n/HANDOFF.md:9-16` and `tools/l10n/todo/index.json`.

**What's wrong:**
- **Interface.** 474 of 1,819 interface strings are missing in all 48 locales (26 %). They include:
  - the onboarding welcome line (`Onboarding/OnboardingView.swift:136`);
  - the paywall's renewal fine print (`Paywall/PaywallView.swift:1414`), a compliance exposure in non-English storefronts;
  - the placement check;
  - every VoiceOver chord sentence ("Finger %lld on string…", "Strings %@ open/muted", `Learn/Diagrams.swift:714-741`), so a Spanish VoiceOver user hears "Finger 2 on string 5, fret 2" in English;
  - "Thickest", "Thinnest" and "%lld of %lld stars".
- **Lessons.** 1,126 of 5,747 lesson strings are missing in the 9 lesson languages (20 %). Guitar units 17–22 are almost all missing. The other 39 locales get no lessons at all.
- **Tooling.**
  - The scanner mis-infers specifiers. The TODO key for `Diagrams.swift:721` is "Finger %@ on string %lld, fret %lld", but `finger` is an `Int` (%lld at runtime). The key for `Journey/JourneyView.swift:311` is "…drifts %lf about…", but the argument is a `String` (%@). A translator's work on these will never match at runtime.
- **Plurals.** Only 7 plural rules exist (`Resources/en.lproj/Localizable.stringsdict`). At least 23 counted strings ("Play-along, %lld notes", "%lld BPM · %lld notes", "Lock %lld strings in tune", "Finish %lld lessons") are flat, which is wrong in ru, pl, uk, ar, he and cs.
- **No gate.** CI only warns ("It never fails the build", HANDOFF.md).

**Fix:**
- Make `report.py --check` fail for any shipped locale with missing *legal* (paywall), permission or VoiceOver strings. Keep warnings for the rest.
- Run the `l10n.yml` xliff export and pass `--xliff`, so keys come from Xcode, not inference. Re-key the two broken strings.
- Move every counted string to the String Catalog with plural variants (`.xcstrings` handles this natively).
- Either fund the translations (owner, §5) or drop locales below ~95 % from `CFBundleLocalizations`, so the App Store stops promising 49 languages.

### 4. VoiceOver reads note names as ASCII and omits the turn instruction. Severity: **major** · Size: **S**

**Where:** Tuner (10, 11, 15) with any tuning that contains accidentals (E♭ standard, Open D, Drop C♯, mandolin and violin alternates, chromatic mode).

**What's wrong:**
- **Raw note names.** `AppStore.targetName` is the raw data spelling, "F#3" or "Eb3" (`Services/AppStore.swift:235`; `PitchMath.noteName` is documented as "ASCII… Show it through `displayName`"). It feeds VoiceOver verbatim:
  - the announcer: `note + ", " + cents` (`Tune/TunerVoiceOver.swift:47`);
  - the readout label `Text("Target \(note)")` (`Tune/Readout.swift:310`);
  - the string chips `Text("String \(n), \(note)")` (`Tune/StringRail.swift:236-238`).
- **What VoiceOver says.** It reads "#" as "number" and "Eb" as letters. There is no spoken-name helper anywhere (glyphs only via `NoteNames.glyphs`), and even "♯"/"♭" pronunciation varies by voice and language.
- **Turn instruction.** Sighted users see "Tighten" / "Loosen" (`TuneView.swift:419-427`). VoiceOver hears only "12 cents flat" (`TunerVoiceOver.swift:42`). A beginner doesn't know flat means tighten.

**Fix:**
- Add `NoteNames.spoken(_:)` in TimbreCore, localized: "F sharp 3" / "Fis 3" / "Fa dièse 3" / "E flat 3". Use it in the three labels above and in `EarTrainingView.spokenNotes` (`Practice/EarTrainingView.swift:697`).
- Announce "\(note), 12 cents flat, tighten". Use "tighten" or "loosen" only outside the lock band.

### 5. Zero automated accessibility verification. Severity: **major** · Size: **S–M**

**Where:** `TimbreUITests/` and `Tests/`.

**What's wrong:**
- No `performAccessibilityAudit()`.
- No launch with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`.
- No Increase Contrast, Bold Text, RTL (`-AppleLanguages (ar)`) or German runs. Every UI test pins `-AppleLanguages (en)` (`TimbreUITests.swift:12`, `AppPreviewUITests.swift:32`, `TabletScreenshotsUITests.swift:20`).
- No SwiftUI previews (0 `#Preview`).
- The 77-frame review set has no AX-size, RTL or German frame. I can award nothing for AX5 behaviour I cannot see. Only 15 of 87 view files branch on `isAccessibilitySize`; Highway, ShowMe, Settings, Metronome, Ear training, Chords and Scales do not.

**Fix:**
- Add an `AccessibilityAuditTests` target. For every tab and every lesson step type, run `try app.performAccessibilityAudit(for: [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .dynamicType, .textClipped])`.
- Add a CI matrix at AX5 + Bold Text + Increase Contrast, plus `ar` and `de`, each producing the same named frames as review15.

### 6. No hands-free or pedal control. Severity: **major** (motor) · Size: **M**

**Where:** 59 along-ready ("Start"), 61 along-done ("Again" / "Next"), 51 lesson-explain ("Continue").

**What's wrong:**
- There are 0 `keyboardShortcut` / `onKeyPress` / `UIKeyCommand` in the app. A Bluetooth page-turner pedal (AirTurn, PageFlip), the standard aid for players whose hands are on the instrument, does nothing. Full Keyboard Access users on iPad have no shortcuts.
- The play-along needs a tap to start and a tap to retry.
- The Watch app cannot drive a lesson.
- The Siri App Shortcuts (`Intents/TimbreShortcuts.swift:9-31`) launch things, but nothing works inside a step.

**Fix:**
- Add `.keyboardShortcut(.space)` (start/stop), `.rightArrow` (Continue / Next) and `.leftArrow` (Again) on `StepButton`, the Highway controls and the tuner Listen orb. Add `.onKeyPress` on the lesson root.
- Add "Start on first strum": arm the mic and begin the count-in on the first onset.
- Expose Start, Again and Next as App Intents, so Voice Control and Siri ("Again") work mid-lesson.

### 7. Bold Text, Smart Invert and Button Shapes are not handled. Severity: **minor→major** (low vision) · Size: **S–M**

**Where:** All screens. 398 `Typeface.*` uses.

**What's wrong:**
- **Bold Text.** Sora headings, numbers, buttons and the note name ignore it. There is no `legibilityWeight` read anywhere (`Design/Theme.swift:143-185`), so with Bold Text on, the system body bolds but every Sora label stays Light, Medium or SemiBold. The octave digit is Sora-Light (`Readout.swift:291`).
- **Smart Invert.** There are 0 `accessibilityIgnoresInvertColors`, so instrument photos, 3D stages and song covers invert into negatives.
- **Button Shapes.** It is not honoured on plain-style text buttons (paywall footer `PaywallView.swift:1376-1393`; "I already have Timbre Pro", `OnboardingView.swift:153`).

**Fix:**
- In `Typeface`, take a `legibilityWeight` parameter: Light→Regular, Medium→SemiBold, SemiBold→Bold (bundle Sora-Bold). Apply it via a `.timbreFont(_:)` view modifier that reads `@Environment(\.legibilityWeight)`.
- Add `.accessibilityIgnoresInvertColors()` on `InstrumentStage`, `StudioStage`, the ShowMe scene, `SongCover` and `CourseArt`.
- Read `@Environment(\.accessibilityShowButtonShapes)` in `linkLabel` and underline or outline when it is on.

### 8. Primary tuner controls stop growing at xLarge, with no Large Content Viewer. Severity: **minor→major** · Size: **S**

**Where:** 10 tune-3d (AUTO / MANUAL / REFERENCE, the "Strum" and "Pause" captions).

**What's wrong:**
- `TunerStageBar` is capped at `...xLarge` (`Tune/TunerControls.swift:19`) and so is `StageCaption` (`Tune/TuneView.swift:529`).
- The Highway HUD, lyrics, notation and finger tags are capped at xxLarge (`HighwayHUD.swift:24`, `HighwayLyrics.swift:48`, `NotationView.swift:256`, `Highway.swift:373`).
- The drone dial labels are capped at `.large` (`DroneTanpura.swift:317`).
- Only two views offer `accessibilityShowsLargeContentViewer` (`Design/GameUI.swift:49, 165`).
- A low-vision user at AX3 gets 10–11 pt captions on the most important controls, with no long-press magnifier.

**Fix:** Add `.accessibilityShowsLargeContentViewer { Label(...) }` to `DetectionPill`'s segments, `ReferenceToneButton`, `StrumToggle`, `ListenOrb`, the Highway tempo rungs and the band and metronome toggles. Raise the stage bar cap to `.accessibility1` and use its `ViewThatFits` compact face, which already exists.

### 9. Control boundaries and dimmed tallies fall below WCAG 1.4.11 / 1.4.3 by default. Severity: **minor** · Size: **S**

**Where:** 13 settings, 20 practice-hub, 59/60 along, 10 tune (resting string chips).

**What's wrong:**
- `controlLine` is 1.66:1 on `surface` and 1.91:1 on `stage` by default (`Design/Theme.swift:22`). The comment admits "1.8:1". This is the edge of every unselected chip, segmented track and search field. It reaches 3:1 only with Increase Contrast.
- Resting string chips ring at white 12 %, about 1.3:1 (`Tune/StringRail.swift:214`).
- The play-along tally dims zero counts to `.opacity(0.45)` (`Learn/Highway.swift:2032`). I measured "✓ 0" at 3.4:1, "◷ 0" at 3.0:1 and "✕ 0" at 2.2:1 on `stage` (60-along-playing). That is text below 4.5:1, and it ignores Increase Contrast.

**Fix:**
- Set the base `controlLine` to `0x5A606A`, which is about 3:1 on `surface`. It reads as quiet as today on near-black.
- Set the resting chip ring to `controlLine`.
- Drop the 0.45 dim and use `inkFaint` for zero counts (5.5:1+).

### 10. Cognitive load for beginners and kids. Severity: **minor→major** · Size: **M**

**Where:** 10 tune-3d, 20 practice-hub, 50 learn, 52 tunecheck vs 52b chord vs 10 tune.

**What's wrong:**
- **Tuner density.** The first tuner screen carries a streak chip, level ring, settings, Strum, Listen, AUTO/MANUAL, REFERENCE, 3D stage, note, cents, Hz, meter, status, "Quest · tune every string 1/6 +20 XP" and six chips.
- **Play hub.** It stacks +XP pills on every row and uses unexplained names ("Sweet Spot", "Bullseye", "P4", `PlayHubGames`).
- **No simpler mode.** There is no way to hide gamification and no "simple" or "kids" profile.
- **String order.** A beginner meets three orders across screens:
  - the tuner rail runs thickest→thinnest left to right (10);
  - the tune-check chips run 1→6, thinnest first (52);
  - the chord box has 6 on the left (52b).

  This is deliberate (`Learn/Diagrams.swift:50-66`) but not explained on screen. The "Thickest" / "Thinnest" captions exist only on some of these screens.
- **Credit.** The curriculum prose itself is excellent plain language, short sentences with no jargon (unit 1).

**Fix:**
- Add Settings › Display › "Simple tuner": it hides the quest line, XP and the header chips on Tune.
- Add a "Calm mode" that drops XP pills and streak pressure (kids, anxious learners and older adults all ask for this).
- Write intervals out ("4th" with the spoken label "perfect fourth").
- Put "Thickest ↔ Thinnest" captions on every string row, including the tuner rail.

### 11. The store listing claims no accessibility and declares no Accessibility Nutrition Labels. Severity: **minor** (business) · Size: **S**

**Where:** `docs/ios/APP-STORE-LISTING.md` has no "accessibility" or "VoiceOver" anywhere.

**What's wrong:** On iOS 26 the product page shows an Accessibility section to every shopper. Apple's criteria require that *all* common tasks work, including onboarding, purchase and the primary function. Today Timbre can honestly declare:
- Larger Text;
- Dark Interface;
- Differentiate Without Colour Alone;
- Sufficient Contrast (with Increase Contrast);
- Reduced Motion.

It cannot yet declare VoiceOver, because the play-along fails (item 1).

**Fix:** Ship item 1, then declare VoiceOver too. Add an accessibility URL (a docs page) and a description line ("Tune by ear with VoiceOver: Timbre speaks the note and cents and taps your wrist when you lock").

### 12. Hearing access on the phone stops short of the Watch's. Severity: **minor** · Size: **S**

**Where:** 21/22 metronome, 59 along count-in.

**What's wrong:**
- The Watch has a real haptic metronome (`TimbreWatch/WristMetronome.swift:4-11, 124`), which is excellent.
- The phone metronome has no haptic pulse option. `MetronomeView` never calls `Haptics.beat`; it uses visual flashes only (`Practice/MetronomeView.swift:137-170`).
- The play-along count-in is visual only. `Highway.swift:720` fires haptics only on combo tiers.
- Ear-training "Listen" steps (58) have no visual alternative or skip for deaf learners.

**Fix:**
- Add Settings › Feedback › "Feel the beat": `Haptics.beat(accent:)` on every metronome click and count-in beat.
- Offer "Skip ear steps" or show notation with the audio on Listen steps.

### 13. RTL is untested and music surfaces are not pinned left-to-right. Severity: **minor** · Size: **S**

**Where:** `Root/RootView.swift:37` sets RTL for ar, he, fa and ur.

**What's wrong:**
- The `HStack` rows that model strings or time will mirror in Arabic and Hebrew: `StringRail`, `UpNextRail`, tune-check chips and the `LessonBeatRow` legend.
- The `Canvas`-drawn necks, chord boxes and runway will not mirror.
- So the chip row and the instrument disagree.
- No RTL frame exists.

**Fix:** Pin `.environment(\.layoutDirection, .leftToRight)` on every music-spatial view (strings, beats, staff, runway, chips). Keep prose and chrome RTL, and add an `ar` CI frame set.

### 14. String palette collapses under deuteranopia (mitigated). Severity: **minor** · Size: **S**

**Where:** 59/60 along.

**What's wrong:** In `HighwayRunway.palette` (`Learn/Highway.swift:1149`), yellow `FFE066` vs amber `FFB547` is ΔE 10.1 under deuteranopia and 12.6 under protanopia. Sky vs mint is 15.4 under tritanopia.

This is mitigated: lanes are positional, the targets are numbered 6…1 and the gems carry fret and note. Credit where due: the pitch triad mint / amber / coral keeps ΔE ≥ 28 under all three deficiencies, and the tally pairs icons with colour.

**Fix:** Shift string 4 to a cooler lime (`0xC8F25A`), or add a dash pattern to alternate lanes when `differentiateWithoutColor` is on.

### 15. Voice Control names are long, and Reduce Motion still spins the stars. Severity: **minor** · Size: **S**

**What's wrong:**
- **Voice Control.** String chips are named "String 4, D3" and there are no `accessibilityInputLabels`, so the user must say "Tap String 4 comma D3".
- **Reduce Motion.** The results stars still scale from 0.3 and rotate −40° (`LessonResults.swift:595-596`). The animation curve is reduced, but the transform is not, which breaks the app's own policy (`Theme.swift:211-214`).

**Fix:**
- Add `.accessibilityInputLabels([Text("D"), Text("String 4"), Text("D3")])`.
- Under Reduce Motion, set `scaleEffect` to 1, rotation to 0 and fade only.

---

## 4. How to take #1 (ranked by impact)

1. **Make "a blind guitarist finishes Unit 1 with VoiceOver" a shipped, tested claim.**
   - Add spoken cues, earcons and a haptic count-in in the play-along.
   - Move focus to the new step title on every step change.
   - Reuse `TunerAnnouncer` in onboarding and the tune check, and speak the star count.
   - Encode the run as an XCUITest with `performAccessibilityAudit()`.

   AppleVis threads from 2025–26 show blind players still hunting for a usable tuner and settling on old apps or Roadie hardware. Nobody serves them a full learn path. This is exactly the profile of the ADA 2025 Inclusivity entries (Land of Livia, Art of Fauna: full VoiceOver, designed for blind players).
2. **Ship a real left-handed experience, and be the first to serve upside-down lefties.**
   - Ask in onboarding.
   - Mirror every neck, chord box, runway, strum stage, 3D headstock, peg arrow and the Show Me hand.
   - Add a third mode, "Left, strung right-handed".

   This takes the one inclusivity axis where Yousician, JustinGuitar and GuitarTuna beat Timbre today. It is also a marketing line ("the guitar app lefties don't have to flip in their heads").
3. **Close the language gap or stop claiming it.**
   - Block releases on missing legal, permission and VoiceOver strings.
   - Rebuild keys from the xliff, add plural variants and fund the 474 interface and 1,126 lesson strings.
   - Add `ar` and `de` CI frames.
   - Trim `CFBundleLocalizations` to the locales that are really complete.
4. **Hands-free practice kit.**
   - Pedal and keyboard shortcuts (space, arrows).
   - "Start on first strum".
   - Watch as a lesson remote with a wrist count-in.
   - A phone haptic metronome toggle.
   - App Intents for Again / Next / Slower, so Voice Control and Siri work mid-lesson.

   This serves players with motor disabilities, one-handed players and everyone holding an instrument.
5. **Prove and publish it.**
   - Run audit tests plus AX5, Bold Text, Increase Contrast and RTL frames in CI.
   - Fix Bold Text (Sora `legibilityWeight`), Smart Invert, Button Shapes, the default `controlLine` contrast and Large Content Viewer on capped controls.
   - Declare complete Accessibility Nutrition Labels with an accessibility page URL. Every competitor's label is empty, so Timbre would be the only one with a filled section.
6. **Calm and Simple modes.** Hide XP, streaks and quests on demand. Use one string-order story with "Thickest ↔ Thinnest" everywhere. Write interval names in words. Kids, older beginners and anxious learners are the biggest under-served groups in this category.
7. **Spoken music vocabulary.** Add a localized `NoteNames.spoken` ("F sharp 3", "Fis 3", "Fa dièse 3"). Make the announcer say "tighten" or "loosen". Read chord diagrams finger by finger with `accessibilityCustomContent` or child elements, so a user can step through instead of hearing one long sentence.

---

## 5. What only the owner can do

- **Translation budget.** The gap is 474 interface strings × 48 locales (22,800 pairs) plus 1,126 lesson strings × 9 languages. At roughly 5–12 words per string and typical professional rates, that is in the low tens of thousands of dollars. Alternatively, decide which locales to drop. The paywall's renewal terms in English in 48 storefronts is a legal and review risk that needs a decision either way.
- **People.**
  - Recruit and pay blind and low-vision testers (AppleVis community, NFB/RNIB networks, or a service such as Fable) for the VoiceOver learn path.
  - Recruit left-handed testers, including upside-down players, before claiming the feature.
  - Include a deaf or hard-of-hearing musician for the haptic flows.
- **Art.** A mirrored right-hand rig may not read as a convincing left hand in the Show Me demonstrations. A dedicated left-hand animation pass may need the 3D artist.
- **App Store Connect.** Fill in the Accessibility Nutrition Labels, add the accessibility URL, and only claim VoiceOver once item 1 ships, because App Review can ask for misleading labels to be corrected (Guideline 2.3).
- **Outreach.** Submit the app to AppleVis for an accessibility review and pitch App Store editorial's accessibility collections. Both need an account holder.

---

## 6. Sources

- Apple, Overview of Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- Apple Design Awards 2025 (Inclusivity winners and finalists): https://developer.apple.com/design/awards/2025/
- GuitarTuna App Store page (rating 4.9, "Left-hand mode", no declared accessibility features): https://apps.apple.com/ua/app/id527588389
- Yousician App Store page (4.6 from 134K ratings, no declared accessibility features): https://apps.apple.com/us/app/959883039
- Yousician Help, Left handed option: https://support.yousician.com/hc/en-us/articles/202773522-Left-handed-option
- AppleVis, Yousician (not usable with VoiceOver, 2018): https://applevis.com/apps/ios/education/yousician-guitar-lessons
- Fender Tune App Store page (4.8 from 152K ratings, no declared accessibility features): https://apps.apple.com/app/id1107017950
- AppleVis, Fender Guitar Tuner (unlabelled buttons, unreliable voice feedback): https://www.applevis.com/apps/ios/music/fender-guitar-tuner
- Fender Play support, lessons for left-handed players: https://play-support.fender.com/hc/en-us/articles/44538504876059-Do-you-offer-lessons-for-left-handed-players
- Simply Guitar App Store page (4.7 from about 400K ratings, no declared accessibility features, no left-handed mode): https://apps.apple.com/us/app/id1476695335
- Simply Guitar help, "I'm left handed, how do I follow the lessons": https://guitar-help.hellosimply.com/en/articles/4043609-i-m-left-handed-how-do-i-follow-the-lessons
- JustinGuitar community, "Inaccessibility to the iOS app for blind users" (May 2024): https://community.justinguitar.com/t/inaccessibility-to-the-ios-app-for-blind-users/322052
- JustinGuitar community, "Fret board is upside down" (Left Handed Mode, Nov 2025): https://community.justinguitar.com/t/fret-board-is-upside-down/405580
- AppleVis, "Apps for tuning the guitar" (2025–26 thread): https://applevis.com/comment/203421
- AppleVis, "guitar tuner app" (2018 thread): https://applevis.com/forum/guitar-tuner-app
