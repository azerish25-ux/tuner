# Jury 16: Inclusivity

Juror: accessibility lead, judging for the Apple Design Awards Inclusivity category.

**Scope.** I audited against Apple's accessibility guidance and WCAG 2.2 AA: VoiceOver, Voice Control, Switch and Full Keyboard Access, Dynamic Type, Bold Text, the Large Content Viewer, Increase Contrast, Reduce Motion and Transparency, Smart Invert, Differentiate Without Colour, hearing and haptics, motor access, cognitive load and localisation.

**What I read.**
- The code in `/home/claude/tuner/ios`.
- Every review16 frame that bears on this angle: the new `ax-audit-*`, `l10n-de-*` and `l10n-ar-*` captures, 04b, 05a, 13, 20, 22, 44, 52, 52b, 55, 58, 59, 60, 61 and 62, plus the preview contact sheet.

**How I measured.**
- Contrast: computed from `Design/Theme.swift` and sampled from the PNGs.
- Colour-blind separation: the Machado 2009 simulation, scored in CIEDE2000.
- Localisation: I ran `tools/l10n/report.py --check` and `tools/l10n/critical.py`, both read-only; the working tree was still clean afterwards.
- Scripts are in `scratchpad/inclusivity16/`.

---

## 1. Score: **8.7 / 10** (round 15: 8.3)

**Verdict.**

The team shipped against nearly every round-15 accessibility item, and several of the fixes are first in the category.

- **The blind learner's path now exists.** It comes in three parts:
  - **Play-along.** It speaks each note a beat ahead ("D, string 4, open"), plays an earcon for each hit and each miss, taps out the count-in, ducks the band, and lands VoiceOver focus on a one-sentence result. Sources: `Learn/PlayAlongCues.swift:14-76`, `Learn/Highway.swift:106, 737, 788-802, 837-842`.
  - **Step changes.** Every step change moves focus to the new title (`Learn/LessonPlayer.swift:501-521`).
  - **Tuning.** The tuner, the first-run tune and the tune check all speak "12 cents flat, tighten" (`Tune/TunerVoiceOver.swift:26-57`, `Learn/LessonSteps.swift:2283-2295`).
- **Left-handed players are served app-wide.** There is a real `HandStyle` (`Learn/Diagrams.swift:105-191`) that mirrors:
  - chord boxes, necks, the runway, the strum stage and the Scales and Intonation necks;
  - the 3D and studio stages, including peg turns (`Stage/InstrumentStage.swift:559, 862-900`);
  - the Show Me hand.

  It also has an "upside-down" mode that no competitor offers, and onboarding asks the question (04b).
- **Hands-free practice.** Space and → act as the primary button, ← as Again and ↓ as Slower, with debouncing against pedal bounce (`LessonPlayer.swift:551-591`). There are Siri and Shortcuts lesson commands (`Intents/PracticeIntents.swift:80-125`) and "Start on first strum" (`PlayAlongCues.swift:177-219`).
- **Hearing.** "Tune by feel" turns the beating between a string and its target into a haptic throb (`Design/Haptics.swift:6-10, 125-151`), and the metronome has a haptic beat (`Practice/MetronomeView.swift:337-366`). Nobody else has either.
- **Settings and contrast.** Bold Text, Smart Invert, Button Shapes, the Large Content Viewer on capped controls, Simple tuner and Calm mode all landed. The tally contrast is fixed.

It does not reach 9 because the same release made the app *less* inclusive for everyone who doesn't read English, and because none of the new work is proven:

- **The interface is now 30 % English in all 48 non-English locales**, up from 26 %: 584 of 1,923 strings are missing.
  - The German welcome headline is English (`l10n-de-welcome`).
  - Every new accessibility string (spoken cues, "Start on first strum", the hand question, Simple tuner, Calm mode, Feel the beat) is untranslated.
  - The translator handoff is stale.
- **Arabic shows the tuner's hero note as "2E"** (`l10n-ar-tabs`), despite a code comment saying it can't.
- **Proof.**
  - The new audit enforces nothing.
  - There is no AX5, Bold Text, Increase Contrast, left-handed or RTL-lesson frame.
  - The Accessibility Nutrition Label is still unclaimed.
- **Open gaps in the blind path.** The notes step goes silent between notes, and VoiceOver's own speech plays into the microphone on the speaker.

On this angle Timbre is clearly #1 against the six competitors. It is not yet an ADA Inclusivity finalist.

---

## 2. Head-to-head on Inclusivity

All five App Store listings I checked (GuitarTuna, Fender Tune, Yousician, Simply Guitar, plus Fender Play's support pages) still read "The developer has not yet indicated which accessibility features this app supports."

| Competitor | Who wins | Why, with evidence |
|---|---|---|
| **GuitarTuna** (4.8★, 149K ratings; 11 languages) | **Timbre** on accessibility; **GuitarTuna** on finished localisation | GuitarTuna declares no accessibility features. The 2025–26 AppleVis threads where blind guitarists pick a tuner never recommend it: they use Roadie, Guitar Tuner+, Acoustic Tuner and TonalEnergy. Its "left-hand mode" is a practice-tool switch. Timbre now has a spoken tuner with turn words (`TunerVoiceOver.swift:54-57`), a haptic lock pattern, Tune by feel, and a left-handed mode that also mirrors the 3D peg turns. Where GuitarTuna wins: it ships 11 languages, and nothing in its listing suggests they are partial. Timbre ships 49 languages, each about 30 % English. |
| **Fender Tune** (4.8★, 152K; 11 languages) | **Timbre**, decisively | Fender Tune declares no accessibility features, has no left-handed mode, and AppleVis rates it usable only with workarounds. Timbre's string chips carry Voice Control input labels ("D", "String 4", the spoken name; `Tune/StringRail.swift:167, 298-301`), the meter has Differentiate Without Colour marks, and the tuner is spoken. |
| **Fender Play** | **Timbre** | Fender's support says "We don't offer specific lessons for left handed players" and suggests watching the videos as a mirror image. Its video lessons have no spoken step structure. Timbre mirrors every chart and neck, and adds a "Charts as printed" escape hatch (`Diagrams.swift:124-160`). |
| **Yousician** (4.6★, 139K; 10 languages) | **Timbre** | Yousician's Left-handed mode flips the song screen and chord charts. It doesn't mention upside-down players or 3D, and the 2018 AppleVis verdict (not usable) has not been revisited. Timbre now beats it on its strongest inclusivity axis: an upside-down mode (`Diagrams.swift:111-121, 153-160`) and a mirrored 3D hand. A blind user cannot play Yousician's game runway; Timbre's speaks. |
| **Simply Guitar** (4.7★, 400K; 11 languages) | **Timbre** on accessibility; **Simply Guitar** on localisation | Simply Guitar has no left-handed mode (its help tells lefties to flip diagrams themselves) and declares no accessibility features. It is localised into 11 languages. A German Simply Guitar user meets German on the first screen; a German Timbre user meets "Tune in seconds. Then learn to play." (`Onboarding/OnboardingView.swift:262-265`). |
| **JustinGuitar** | **Timbre** | Users report JustinGuitar's iOS app is "completely inaccessible with VoiceOver", even at login (2024, unanswered). It has a left-handed song display (Nov 2025 thread). Timbre is ahead on every axis. |

**Watch item.** Niche apps are moving: Guitar Wiz added spoken VoiceOver tuning guidance in December 2025. A small app could claim "accessible tuner" before Timbre claims anything in its listing.

---

## 3. Everything that costs points, ranked

### 1. Localisation regressed while the app grew. Severity: **major** · Size: **M** (code), **L** (owner)

**Where:** `l10n-de-welcome`, `l10n-de-tabs`, `l10n-ar-tabs`; `docs/l10n/HANDOFF.md`; `tools/l10n/report.py --check`.

**What's wrong:**
- **The numbers.** I ran `report.py --check` today. It shows 584 of 1,923 interface strings missing in all 48 non-English locales (30.4 %; round 15 was 474 of 1,819, 26 %). It shows 1,408 of 6,029 lesson strings missing in each of the 9 lesson languages (23 %; round 15 was 1,126, 20 %).
- **The handoff is stale.** CI prints "Translation handoff out of date". `HANDOFF.md` still says 475 and 1,126, and `todo/de.json` lacks every string added this wave.
- **On screen in German:**
  - the welcome headline and subline (`OnboardingView.swift:262, 265`);
  - "Strum" (`Tune/StrumTuneView.swift:546`), "REFERENCE" (`Tune/TunerControls.swift:127`), "Quest · tune every string" (`Tune/TuneView.swift:468`), "Thickest" and "Thinnest".
- **Hertz isn't localised.** It is formatted with `String(format: "%.2f Hz")` (`Tune/Readout.swift:380`), so German reads "Ziel 82.41 Hz", not "82,41 Hz".
- **Every new inclusivity string is English in all 48 locales:**
  - "Which hand do you play with?" and "Left-handed, strung upside down" (`OnboardingView.swift:462, 483`);
  - "Turn spoken cues off/on" and "Next: %@" (`Learn/Highway.swift:268, 888`);
  - "%@ sharp" and "%@ flat" (`PlayAlongCues.swift:63, 67`);
  - "Start on first strum" (`LessonSteps.swift:1496`);
  - Simple tuner and Calm mode (`Settings/SettingsView.swift:276-292`);
  - "Feel the beat" (`MetronomeView.swift:343`).
- **What a Spanish VoiceOver player hears mid-take:** "Next: E, Cuerda 6, al aire". The VoiceOver chord sentences ("Finger %lld on string %lld, fret %lld", `Learn/Diagrams.swift:924-953`) and "%lld of %lld stars" are still English.
- **Plurals.** Still only 7 plural rules in every `Localizable.stringsdict`. `tools/l10n/xcstrings.py` exists but has not been adopted.

**Fix:**
- Run `report.py` and commit its output on every string change. Make the core CI job *fail* when the handoff is out of date, not warn.
- Ship only the locales you can finish: trim to the 9 lesson languages (plus ar and he if RTL is a goal) through `CFBundleLocalizations` or by removing `.lproj` folders.
- Adopt the String Catalog (`xcstrings.py --out`) so counted strings get real plural variants.
- Use `.formatted(.number.precision(.fractionLength(2)))` for hertz and cents.

### 2. The blind path still has holes in its most frequent steps. Severity: **major** · Size: **M**

**Where:** 56 lesson-notes, 59/60 along, `Audio/AudioService.swift:818`.

**What's wrong:**
- **The notes step goes silent.** On each `.hit` it plays a sound and a haptic, then nothing is spoken (`LessonSteps.swift:283-303`). The next note, its string and fret, and "A little flat/sharp" (`LessonSteps.swift:263-264`) are never announced. A blind learner must take a hand off the instrument and swipe to find the next note.
- **Cue timing is unrealistic at lesson tempos.**
  - A cue is said one beat ahead (`Highway.swift:792`, `lead: spb`) and is shortened only when notes are under 0.9 s apart (`Highway.swift:800-801`).
  - At the roll-call tempo of 60 BPM, "E, string 6, open" takes about 1.2–1.4 s at VoiceOver's default rate. The cue therefore runs into the note it announces.
  - Each cue is posted at `.high` priority (`PlayAlongCues.swift:46`), so cues collide with each other and with VoiceOver's audio ducking of the click.
- **VoiceOver's voice reaches the microphone.**
  - The lesson session is `.playAndRecord` / `.measurement` / `.defaultToSpeaker` with no echo cancellation (`AudioService.swift:818`). Voice processing is used only for the band-on-speaker option (`LocalStore.swift:80-82`).
  - A spoken cue's fundamental (100–250 Hz) sits inside the guitar's E2–E4 range, so it can produce false onsets or wrong-note readings during a take.
  - Nothing in the code gates detection while speech plays, and no device test is evident.
- **Spoken names are inconsistent.**
  - The play-along builds them from an English template ("%@ sharp", `PlayAlongCues.swift:59-70`); the tuner uses the localised core `NoteNames.spoken` ("Fis 3", "Fa dièse 3", `Tune/TunerVoiceOver.swift:74-82`).
  - The first-run tune passes no spoken name (`Onboarding/FirstTuneStep.swift:195`).
  - Glyph names still feed VoiceOver in `Diagrams.swift:989, 1074`, `NotationView.swift:213` and `SongOpener.swift:295`.
- **Chord shapes are one long sentence.** There is no `accessibilityCustomContent`, so the user cannot step through the fingers (`Diagrams.swift:618-620`).

**Fix:**
- **Notes step.** In `NotesStep.listen()`, on `.hit`, post the next note's `SpokenCues.phrase(…)`. While a wrong or out-of-tolerance pitch is held, post "A little flat, tighten" on the `TunerAnnouncer` cadence.
- **Cue timing.**
  - Speak cues 2 beats ahead whenever the beat is under 1.5 s.
  - Use the brief form ("6 open") whenever the gap is under 1.6 s.
  - Better: speak through your own `AVSpeechSynthesizer`, routed into the app's output, at a known rate and with known utterance timing. Then ignore detector frames while an utterance plays, and turn on voice processing (`setVoiceProcessingEnabled`) when spoken cues are on, so the echo canceller removes the voice.
- **Names.** Replace `SpokenCues.spokenName` with `NoteNames.spokenInApp`. Add `accessibilityCustomContent` (one entry per finger) to `ChordPictureView`.

### 3. RTL: the hero note reads "2E" in Arabic, and the music rails flip. Severity: **major** · Size: **S**

**Where:** `l10n-ar-tabs`; `Tune/Readout.swift:292-300`; `Learn/Highway.swift:2044` (`UpNextRail`), `:2102` (`TakeRibbon`), `HighwayTimingStrip.swift:247`.

**What's wrong:**
- **The note readout.** The comment at `Readout.swift:299` promises "E₂, never ₂E in Arabic or Hebrew", but the frame shows the octave digit to the *left* of the E. The `.environment(\.layoutDirection, .leftToRight)` on the HStack doesn't hold on device. This is the biggest glyph on the app's main screen.
- **The pins.** The string rail, the tune-check chips and the strum stage are pinned left-to-right (credit: `StringRail.swift:42`, `LessonSteps.swift:2130`). The play-along's up-next rail, take ribbon and timing strip are not pinned, so in Arabic time runs right to left under a runway that runs left to right.
- **The same frame also shows:**
  - "Strum", "REFERENCE", "Quest · tune every string", "Thickest", "Thinnest" and the "Songs" tab in English;
  - "A4 ٤٤٠ Hz" (Arabic-Indic digits) beside "82.41 Hz" (Latin).
- **The test.** The Arabic test asserts only the tab order (`TimbreUITests/LocalizationLaunchUITests.swift:54-66`).

**Fix:**
- Draw the readout as one `Text` run: `Text(name) + Text(octave).font(...).baselineOffset(...)`, wrapped in U+2066…U+2069 (LTR isolate). Or apply `.flipsForRightToLeftLayoutDirection(false)` to a fixed-direction container.
- Pin `UpNextRail`, `TakeRibbon` and the timing strip left-to-right.
- Format hertz with the locale's numbering system.
- Add an `ar` frame of 59/60 along and 52 tune-check, and assert the readout's octave sits to the right of its note in a pixel test.

### 4. The new verification proves nothing yet. Severity: **major** · Size: **S–M**

**Where:** `TimbreUITests/AccessibilityAuditUITests.swift:11, 35, 111`; `LocalizationLaunchUITests.swift:39`; the `ax-audit-*` frames.

**What's wrong:**
- **The audit can't fail.** `enforced` is `[]`, so `performAccessibilityAudit(for: .all)` logs and never fails.
- **The audit's coverage is narrow.** It runs in English at the default text size, on the welcome screen, five tabs, Settings and the paywall. No lesson step, play-along, Show Me, tuner sheet or metronome is audited. The audit text reports weren't in the review set, so I can't credit their findings.
- **Missing frames.**
  - There is no AX5, Bold Text or Increase Contrast frame, and no left-handed or upside-down frame. The hand claim on 04b ("Necks, chord charts and the stage follow your hand") is never shown.
  - There is no RTL lesson frame.
  - There is still no `#Preview`.
  - Only 16 app files branch on `isAccessibilitySize`. `SettingsView`, `EarTrainingView`, `ChordsView` and `ScalesView` have no `isAccessibilitySize` or `ViewThatFits` at all.
- **The German test is weak.** It checks only that the button isn't "Get started" (`LocalizationLaunchUITests.swift:39`), and it passed while the headline above that button is English.

**Fix:**
- **Enforce.** Turn on `.contrast`, `.hitRegion`, `.sufficientElementDescription` and `.trait` now (the frames suggest they are clean). Add `.dynamicType` and `.textClipped` once AX runs exist.
- **Add a CI matrix.** Use `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` (AX5) plus Bold Text and Increase Contrast, and add left-handed and upside-down launch overrides. Run it over 05a, 13, 52, 52b, 55, 56, 59, 60, 62.
- **Pseudo-localise.** Launch with `-NSDoubleLocalizedStrings YES` (or a custom pseudo-locale) and fail on any untranslated string visible on the welcome screen and the tuner.

### 5. The legal, permission and VoiceOver release gate is bypassable, and would fail today. Severity: **major** (compliance) · Size: **S** (code), **L** (owner)

**Where:** `tools/l10n/critical.py`; `.github/workflows/apple-delivery.yml:23-27, 84-88`.

**What's wrong:**
- **The gate is good engineering.** It checks paywall terms, `NS…UsageDescription` strings and every string reaching VoiceOver.
- **It would fail today.** Run now, it finds 11 legal strings, 1 permission string (`NSAppleMusicUsageDescription`) and 84 VoiceOver strings missing in *every* shipped locale. The legal strings include "Subscriptions renew automatically…", "Then %@. It renews automatically…", "Start free trial", "Cancel in 2 taps" and the billing-retry banner.
- **It can be switched off.** The `allow_untranslated` checkbox skips it. Its description says "internal TestFlight only, never an App Store release", but nothing enforces that.

**Fix:**
- When `allow_untranslated` is set, refuse to submit for review. For example, set the build's `TIMBRE_INTERNAL` flag so App Store Connect submission fails, or block the `submit` step on the input.
- Better: deliver those 96 strings first (about 4,600 locale-string pairs; most are short) or ship fewer locales via `--locales`.

### 6. The accessibility differentiator is still unclaimed in the store. Severity: **minor→major** (business) · Size: **S**

**Where:** `docs/ios/APP-STORE-LISTING.md:9` ("No VoiceOver claim … until the play-along works with it").

**What's wrong:**
- The play-along now speaks, so that note is stale.
- The listing has no Accessibility Nutrition Label section, no accessibility URL and no accessibility line.
- Every competitor's label is empty. Timbre could hold the only filled label in the category today.

**Fix:**
- **Declare now:** Larger Text (after the AX5 matrix in item 4), Dark Interface, Differentiate Without Colour Alone, Sufficient Contrast, Reduced Motion.
- **Declare after one round of on-device testing:** Voice Control.
- **Declare after item 2 and a blind tester's pass through Unit 1:** VoiceOver.
- **Add to the listing:** an accessibility page URL and the line "Tune by ear or by feel: Timbre speaks the note and tells you which way to turn, or pulses in your hand until the string locks."

### 7. Hands-free gaps: pedal keys, Siri languages, Full Keyboard Access, Watch. Severity: **minor** · Size: **S**

**Where:** `Learn/LessonPlayer.swift:568-583`; `Intents/TimbreShortcuts.swift:34-35`; `Resources/*/AppShortcuts.strings`.

**What's wrong:**
- **Page-turner pedals.** Pedals commonly send Page Up/Down, ↑/↓ or Return; forScore answers all of them by default. Timbre maps only Space, →, ← and ↓, and ↓ means *Slower*. A pedal in its Up/Down mode would select the slow tempo on the results screen instead of moving on.
- **Full Keyboard Access.** Space is its Activate key. Binding Space to the primary action risks firing Continue while Try again has keyboard focus. Not tested.
- **Siri.** The phrases "${command} in ${applicationName}" are untranslated in all 48 locales, so Siri lesson control is English-only.
- **No Stop during a take.** The lesson play-along has no Esc/Stop key; `StopKey` is used only in songs (`SongPerform.swift:324`, `SongChords.swift:94`).
- **Watch.** It still cannot drive a lesson or tap the count-in on the wrist.

**Fix:**
- Map primary to → / Page Down / Return (keep Space only when no other control has focus), Again to ← / Page Up, and Slower to ⌥↓.
- Add `StopKey` to `AlongStep`.
- Translate the AppShortcuts phrases.
- Add a `LessonCommand` relay through `WatchBridge` with a haptic count-in on the wrist.

### 8. Calm mode is shallow, and its footer overpromises. Severity: **minor** · Size: **S**

**Where:** `SettingsView.swift:276` ("Calm mode keeps XP and streak counters out of the way").

**What's wrong:**
- **What it hides.** Only the XP pills in three places: the daily set, ear training and a hub challenge (`Practice/DailySetCard.swift:356, 374`; `EarTrainingView.swift:255`; `PlayHubGames.swift:441`).
- **What stays:**
  - the streak chip and level ring on every tab header (`Design/Kit.swift:64-78`);
  - the "+XP" reward banners and "Quest complete" toasts (`Design/GameUI.swift:449, 554, 570`);
  - the results screen's +24 XP and "7 day streak" tiles and level bar (62);
  - "5 min · +25 XP" on Learn, "+35 XP" on Songs;
  - the "Sweet Spot" level card;
  - the streak celebration.
- **Simple tuner** is thorough on Tune (`TuneView.swift:204, 455`).
- **Jargon.** "M6" and "P4" are still unexplained interval tags (20 practice hub).

**Fix:** Gate `HeaderControls`, `RewardBanner` XP and streak entries, the XP and streak tiles in `LessonResults`, and the Learn/Songs XP suffixes on `calmMode`. Offer Calm mode in onboarding for "Just for fun" goals. Give interval tags spoken labels ("major sixth") and a one-line legend.

### 9. Control boundaries are still just under 3:1. Severity: **minor** · Size: **S**

**Where:** `Design/Theme.swift:31`.

**What's wrong:**
- `controlLine` is now `0x5A606A`, a big improvement over 1.66:1. It measures 2.78:1 on `surface` and 2.94:1 on `stageRaised`, so it still fails WCAG 1.4.11 on cards. Only `stage` reaches 3.18:1.
- The token's comment claims "about 3:1 on `surface`".
- The tally zeros are now `inkFaint` at 6.27:1 (60), so that item is fixed.

**Fix:** Use `0x646A74`: 3.23:1 on `surface`, 3.41:1 on `stageRaised` and 3.70:1 on `stage`, and it still reads quiet on near-black.

### 10. Lane colours: neighbours are safe, but two non-neighbour pairs collide. Severity: **minor** · Size: **S**

**Where:** `Learn/Highway.swift:1265-1266`; frames 59 and 60.

**What's wrong:**
- **Neighbours.** Adjacent strings stay ≥ 8.5 ΔE2000 apart under every deficiency (credit).
- **String 3 vs string 6** (`FF7AD0` vs `FFA3E0`): 8.3 ΔE2000 with *normal* vision, 5.5 under deuteranopia. On frame 59 both read as "pink".
- **String 2 vs string 5** (`6E8BFF` vs `A592FF`): 3.5 under protanopia, effectively identical.
- **The "Next · String n" chip** is tinted in the lane colour, so string 3 and string 6 cues look alike.
- **Status colours.** The palette comment says no lane uses a verdict colour (`Highway.swift:1263-1264`). But lime string 4 (`C4E86B`) is 4.9 ΔE2000 from amber "early/late" under deuteranopia.
- **Mitigations.** Lanes are positional and numbered, verdict pops carry words, and Differentiate Without Colour dashes alternate lanes (`Highway.swift:1205, 1285`). The ribbon's perfect gold vs mint "good" is 5.7 under protanopia, mitigated by the icons on the tally.

**Fix:**
- Move string 6 to ice (`0xB8F0FF`). It sits 39.4 from string 3 with normal vision, at least 11.0 from every other lane under every deficiency, and at least 10.3 from mint, amber, coral and gold. I tested lighter lavenders for string 5, and they make it worse (string 1 vs string 5 drops to 1.6 under protanopia), so keep string 5.
- Six lanes cannot all be separated by colour under protanopia, so make lane identity non-chromatic by default: put the string number on every gem (not only under Differentiate Without Colour), and keep the dashes.

### 11. Dynamic Type leftovers and no AX evidence. Severity: **minor** · Size: **S**

**Where:**
- `Practice/DroneTanpura.swift:317`: the drone dial's note names are still capped at `.large` at 11 pt.
- `Tune/StrumMeters.swift:297-306`: "≈ estimate" is 10 pt, below the app's own 11 pt floor, and capped at xLarge.
- `Learn/Highway.swift:421`: the finger tag is capped at xxLarge.

**Credit:** the main controls now cap at AX1 with the Large Content Viewer (`Design/Kit.swift:713-716`, `TunerControls.swift:21, 85, 146`, `TuneView.swift:548, 595`).

**Fix:** Give the dial labels `.cappedControl` with the Large Content Viewer, and raise "≈ estimate" to `Typeface.badge` (12 pt).

### 12. Deaf and hard-of-hearing: ear steps have no alternative. Severity: **minor** · Size: **S**

**Where:** 58 lesson-listen ("Which is higher?").

**What's wrong:** There is no "show me instead" path, and no skip that keeps the lesson's stars. Tune by feel, Feel the beat and the haptic count-in are excellent and first-in-class.

**Fix:** After two wrong answers, or when the player has opted in, show both notes on a mini staff and a pitch ladder, with an "I can't hear this" skip that doesn't cap the stars.

---

### Round-15 checklist (JURY15-inclusivity.md)

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Blind musicians can tune but not learn | **Partly fixed (mostly)** | Play-along cues, earcons, haptic count-in, ducking and result focus: `PlayAlongCues.swift`, `Highway.swift:106, 737, 788-842`. Step focus: `LessonPlayer.swift:501-521`. Announcers in the first tune and the tune check. Stars read aloud: `LessonResults.swift:129-131`. Still open: the notes step is silent (item 2), cue timing and the mic hearing speech, and English cues abroad. |
| 2 | Left-handed setting cosmetic | **Fixed** (code); unverified on screen | `HandStyle` across charts, necks, runway, strum stage, Scales and Intonation, 3D, studio, Show Me and peg turns; upside-down mode; onboarding 04b; "Charts as printed". No left-handed frame. |
| 3 | Localisation a quarter English | **Worse** | 26 % → 30 % of the interface; lessons 20 % → 23 %; handoff stale; new a11y strings untranslated. The critical gate exists but is bypassable and failing. Plurals unchanged. |
| 4 | ASCII note names; no turn word | **Mostly fixed** | `NoteNames.spoken` in the readout, rail and announcer; "tighten" and "loosen" spoken (`Readout.swift:397-401`, `TunerVoiceOver.swift:54-57`). The play-along uses an English template; other labels use glyphs; the first tune passes no spoken name. |
| 5 | Zero automated verification | **Partly fixed** | The audit test exists but enforces nothing and runs in English at default size. de/ar launch tests exist but are weak. No AX5, Bold or Increase Contrast frames. |
| 6 | No hands-free or pedal control | **Mostly fixed** | Keys, Siri lesson commands, Start on first strum. Incomplete pedal mapping, Siri English-only, no Watch, no Stop key in lessons. |
| 7 | Bold Text, Smart Invert, Button Shapes | **Fixed** | `Theme.swift:229-263`; 16 `accessibilityIgnoresInvertColors`; `Kit.swift:752-757`; the onboarding secondary button is now bordered. |
| 8 | Controls capped at xLarge, no Large Content Viewer | **Mostly fixed** | `cappedControl` gives AX1 plus the Large Content Viewer on the pill, reference, orb and strum. Leftovers in item 11. |
| 9 | Control boundaries and dimmed tallies | **Mostly fixed** | Tally at 6.27:1; resting chip ring = `controlLine`; `controlLine` 2.78:1 on `surface` (item 9). |
| 10 | Cognitive load | **Partly fixed** | Simple tuner is good. Calm mode is shallow. Thickest/Thinnest now on every string row (52, 52b, 55, 59, tuner rail). "M6" and "P4" remain. |
| 11 | No Accessibility Nutrition Labels | **Not fixed** | `APP-STORE-LISTING.md:9` is stale. |
| 12 | Phone haptics behind the Watch | **Fixed, and better** | Feel the beat, the haptic count-in (`PlayAlongCues.swift:29-30`) and Tune by feel. Ear steps still have no alternative. |
| 13 | RTL untested, music not pinned | **Partly fixed, plus a new visible bug** | Rails pinned. The hero readout reads "2E" in Arabic. The play-along rails aren't pinned. |
| 14 | String palette under deuteranopia | **Partly fixed** | Neighbours safe; s3/s6 and s2/s5 collide; Differentiate Without Colour dashes. |
| 15 | Voice Control names; Reduce Motion stars | **Fixed** | `StringRail.swift:167, 298-301`; `LessonResults.swift:607-608`. About 28 non-adaptive scale and move transitions remain, many under nil animations; a minor sweep is due (e.g. `LessonSteps.swift:2311`, `LessonPlayer.swift:903`). |

---

## 4. How to take #1 (ranked by impact)

1. **Finish the languages you ship, or ship fewer.** This is now the single biggest inclusivity deficit, and it grows with every feature.
   - Fund the 584 interface strings and the 1,408 lesson strings in the 9 lesson languages, and drop the other 39 until they are complete.
   - Make `critical.py --strict` impossible to skip for App Store submissions.
   - Make an out-of-date handoff fail CI.
   - Pseudo-localise in CI, so an English string on the welcome or tuner screen fails the build.
2. **Make "a blind guitarist finishes Unit 1 with VoiceOver" a tested, shipped claim.**
   - Fix the notes step's announcements.
   - Move spoken cues to your own `AVSpeechSynthesizer`: speak two beats ahead, mute detection while speaking, and turn on voice processing.
   - Localise the cues through `NoteNames.spokenInApp`.
   - Have 3–5 AppleVis-recruited blind guitarists run Unit 1 on device.
   - Then claim VoiceOver in the Nutrition Label. No competitor can.
3. **Claim the store real estate now.** Fill the Accessibility Nutrition Labels: Larger Text, Dark Interface, Differentiate Without Colour, Sufficient Contrast and Reduced Motion today; Voice Control after testing; VoiceOver after tip 2. Add an accessibility page, and put "Tune by feel" and "left-handed, even upside-down" in the screenshots' captions. Every competitor's label is empty.
4. **Prove it in CI with the frames a juror asks for.**
   - AX5 + Bold Text + Increase Contrast frames for the tuner, a lesson, the play-along and results.
   - Left-handed and upside-down frames for 52b, 55, 59 and the 3D tuner.
   - Arabic frames for 52, 59 and 60.
   - Enforce the clean audit kinds.
5. **Fix RTL at the glyph level.** Render the note as one isolated `Text` run, pin the play-along rails left-to-right, and localise digits and decimals.
6. **Complete the hands-free kit.** Pedal-standard keys (Page Up/Down, Return), Esc in lessons, localised Siri phrases, a Watch lesson remote with a wrist count-in, and "Again / Next" through Voice Control's custom commands, documented on the accessibility page.
7. **Make Calm mode real and offer it in onboarding.** Hide streak and level chrome, XP banners and results XP. Kids, anxious adults and older beginners are the under-served group here.
8. **Polish the last colour and contrast items.** Raise `controlLine` to 3:1 on cards and re-pick lane colours for strings 5 and 6.

---

## 5. What only the owner can do

- **Translation money, or a decision.** The gap is 584 interface strings × 48 locales plus 1,408 lesson strings × 9 languages. Either fund professional translation of the kept locales (low tens of thousands of dollars at agency rates), or decide to ship 9–11 languages and remove the rest. The paywall renewal terms are English in every storefront; that needs a decision before the next App Store submission, not a checkbox.
- **People.**
  - Paid blind and low-vision testers (AppleVis, NFB/RNIB networks, or Fable) for Unit 1 and one song.
  - Left-handed and upside-down guitarists to validate the mirrored 3D hand and the charts.
  - A deaf or hard-of-hearing player to validate Tune by feel.
  - Native reviewers for Arabic and Hebrew RTL.
- **App Store Connect.** Fill the Accessibility Nutrition Labels, add the accessibility URL, and claim VoiceOver only after tested sign-off (Guideline 2.3).
- **Release policy.** Remove or lock down `allow_untranslated` for App Store builds. It is a governance decision, not a code one.
- **Outreach.** Submit to AppleVis and pitch Apple's accessibility editorial ("Tune by feel" is a story).

---

## 6. Sources

- Apple, About the accessibility information shown for apps in the App Store: https://support.apple.com/123073
- Apple, Overview of Accessibility Nutrition Labels: https://developer-rno.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- GuitarTuna App Store page (4.8★, 149K ratings; no declared accessibility features; left/right-hand modes; 11 languages): https://apps.apple.com/us/app/id527588389
- Fender Tune App Store page (4.8★, 152K; no declared accessibility features; 11 languages): https://apps.apple.com/app/id1107017950
- Yousician App Store page (4.6★, 139K; no declared accessibility features; 10 languages): https://apps.apple.com/us/app/id959883039
- Yousician Help, Left handed option: https://support.yousician.com/hc/en-us/articles/202773522-Left-handed-option
- Simply Guitar App Store page (4.7★, 400K; no declared accessibility features; 11 languages; no left-handed mention): https://apps.apple.com/app/id1476695335
- Fender Play support, lessons for left-handed players: https://play-support.fender.com/hc/en-us/articles/44538504876059-Do-you-offer-lessons-for-left-handed-players
- JustinGuitar community, "Inaccessibility to the iOS app for blind users": https://community.justinguitar.com/t/inaccessibility-to-the-ios-app-for-blind-users/322052
- JustinGuitar community, "Fret board is upside down" (Left Handed Mode): https://community.justinguitar.com/t/fret-board-is-upside-down/405580
- AppleVis, "Apps for tuning the guitar" (2025–Feb 2026: Roadie, Guitar Tuner+, Acoustic Tuner, TonalEnergy): https://applevis.com/comment/203442
- KVR Audio, Guitar Wiz adds VoiceOver tuning guidance (28 Dec 2025): https://www.kvraudio.com/news/jsplash-apps-updates-guitar-wiz---major-accessibility-improvements-with-enhanced-voiceover-support-65792
- forScore, Page Turners & Shortcuts (default keys: arrows, space, return, Page Up/Down): https://forscore.co/?p=1641
