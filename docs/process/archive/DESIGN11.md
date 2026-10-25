# DESIGN11: design-system and accessibility audit (reading only)

Scope: `ios/Timbre` (iOS 18+, SwiftUI) with the tokens in `ios/Timbre/Design/`. I compared all 70 w11 screenshots (iPhone 17 Pro and iPad) side by side, and grepped the code for literals that bypass `Typeface`, `Palette`, `Metrics` and `Motion`. Paths are relative to `ios/Timbre/`. No files were edited.

**Severity**
- **P1:** An accessibility defect, or something a juror notices in the first minute.
- **P2:** A visible inconsistency between screens.
- **P3:** Polish.

**Batch** (A to F) says who fixes it. Batches own files that don't overlap; see the end of this document. Batch A creates the shared tokens and components, and the other batches call them by the names given in the API contract.

## Drift at a glance (counts from grep)

| Token | Bypassed by | Notes |
|---|---|---|
| `Typeface` | 158 `.font(.system(size:))` | About 40 of them are on text, not icons. |
| | 91 `Typeface.display()` calls | Only 11 pass `relativeTo:`. |
| | 21 distinct display sizes | 15, 16, 17, 18, 19, 20, 22, 24, 26, 28, 30, 32, 34, 36, 40, 44, 48, 52, 56, 64, 80. |
| `Palette` | 120 `Color(hex:)` outside Design/ | 60 or so are UI colours, not illustration. |
| `Metrics` | `Metrics.corner` and `cornerSmall` referenced twice in total | Card radii in use: 14, 16, 18 (32×), 19, 20, 22, 24, 26, 28, 30. |
| | `stillCard` padding | 0, 6, 12, 14, 16, 18 and 22. |
| | Screen gutters | 20, 22, 24, 26, 28 and 30. |
| `Motion` | 30 ad-hoc `.spring(response:dampingFraction:)` and about 70 ad-hoc `.easeX(duration:)` | |
| Components | `ScreenTitle` is never used. | |
| | `Eyebrow` is used 19 times; about 20 eyebrows are built by hand. | |
| | `HubQuestRow` duplicates `QuestRow`. | |
| | There are 7 close-button builds and 3 primary-button builds. | |

## WCAG contrast of the Studio Noir tokens (computed from Theme.swift hex values)

| Foreground on → | stage #060708 | stageRaised #111317 | surface #16191E | line #24272D | lesson green wash #0F201C (from screenshot) |
|---|---|---|---|---|---|
| ink #F5F3EF | 18.2 | 16.8 | 15.9 | 13.5 | n/a |
| inkSoft #A3A8B1 | 8.4 | 7.8 | 7.4 | 6.3 | 7.1 |
| inkFaint #80868F | 5.5 | 5.1 | 4.8 | **4.1 ✗** | **4.6** (marginal) |
| inkFaint on a mint-tinted `stillCard(tint:)` corner #1A3731 | n/a | **3.5 ✗** | n/a | n/a | n/a |
| `Palette.line` as a control or card boundary (WCAG 1.4.11 needs 3:1) | 1.35 ✗ | **1.24 ✗** | n/a | n/a | n/a |
| white at 72% (Songs hero meta) on cover mid-tones #8A4E44 and #9B6B64 | n/a | n/a | n/a | n/a | **4.2 / 3.2 ✗** |
| `onAccent` on mint, amber, violet, coral, sky | 13.3, 10.8, 7.4, 7.7, 10.3 | n/a | n/a | n/a | n/a |

The base text tokens pass AA. The failures come from faint text on tinted or `line` surfaces, from boundaries drawn only with `line`, and from white-alpha text over artwork. No screen outside `Tune/` responds to Increase Contrast (finding 4).

---

## Ranked findings

### 1. P1 · The Typeface tokens scale against the wrong text style, so headings end up smaller than body text at AX sizes · A
- **Where:**
  - `Design/Theme.swift:77-95`: `display()` defaults to `.largeTitle`, `label()` to `.caption` and `number()` to `.body`, whatever size is asked for.
  - 80 of 91 `display()` calls take the default. That includes the 16–20 pt section titles: `Journey/JourneyView.swift:234,290,404,572,617`, `Practice/PracticeView.swift:144,196` and `Journey/CoachCard.swift:99`.
- **What the user sees** (the AX5 multipliers are ≈ largeTitle ×1.76, body ×3.1, caption ×3.6):
  - "Coach" (16 pt) grows to ≈28 pt while the subheadline under it reaches ≈49 pt. Headings shrink below their own content.
  - 18 pt Sora button labels (`label(18)`) grow ×3.6.
  - Hero numerals in `number(40…96)` grow ×3.1 and overflow (finding 2).
- **Fix:**
  - Add `Font.TextStyle.matching(_ size:)` to `Typeface`:

    | Size (pt) | Text style |
    |---|---|
    | ≤11.5 | caption2 |
    | ≤12.5 | caption |
    | ≤13.5 | footnote |
    | ≤15.5 | subheadline |
    | ≤17.5 | headline |
    | ≤21 | title3 |
    | ≤25 | title2 |
    | ≤31 | title |
    | above 31 | largeTitle |

  - Make it the default `relativeTo` for `display`, `note`, `displayLight`, `number` and `label`.
  - The default text size is unchanged. Only the scaling curve changes, and explicit `relativeTo:` call sites keep their own value.

### 2. P1 · Hubs and results keep phone layouts at accessibility sizes and clip · C, D, E
There is no `isAccessibilitySize` branch in JourneyView, PracticeView, DailySetCard, LearnView, LessonResults or SongsView.

| Screen | Where | What breaks | Fix |
|---|---|---|---|
| Progress stats | `Journey/JourneyView.swift:193-198, 212-221` | Three tiles across with `lineLimit(1) minimumScaleFactor(0.7)`. "day streak" and the level name truncate. | Stack the tiles vertically at AX sizes and use `StatTile` (finding 23). |
| Results tiles | `Learn/LessonResults.swift:109-113` | Three tiles across. | Same fix as Progress stats. |
| Play tools | `Practice/PracticeView.swift:274-288` | A three-column grid with `.caption`, `lineLimit(1)` and `minimumScaleFactor(0.8)` reads "Metron…" and "Intonat…". | At AX sizes, one column of `FeatureRow`. |
| Today ring | `Practice/DailySetCard.swift:241-252, 278` | The ring is a fixed 112 pt. `number(22)` (body-relative) is ≈69 pt at AX5, wider than the 90 pt hole. | Use `ViewThatFits` to put the ring above the rows, and cap the ring's text with `.dynamicTypeSize(...xxxLarge)`. VoiceOver already reads the value. |
| Ear training session ring | `Practice/EarTrainingView.swift:373-375` | `number(40)` in a fixed 156 pt circle. "7/10" at ≈125 pt overflows. | Add `relativeTo: .largeTitle` and `lineLimit(1).minimumScaleFactor(0.4)`, or size the ring with `@ScaledMetric`. |
| Pitch Sniper result | `Practice/PitchSniperView.swift:146` | `number(56)` grows to ≈175 pt and "1,650" truncates. | Same fix as the ear-training ring. |
| Metronome BPM | `Practice/MetronomeView.swift:187` | `display(80)` beside two 44 pt steppers clips at AX4+. | Add `.lineLimit(1).minimumScaleFactor(0.5)`. |
| Learn course cards | `Learn/LearnView.swift:251` | A fixed 136×170 frame. | Use `minHeight` and drop the art at AX sizes. |
| Learn hero "Continue" pill | `Learn/LearnView.swift:283` | `frame(height: 42)` holds a caption-relative 15 pt label. | Use `frame(minHeight: 44)`. |
| Songs hero Play | `Songs/SongsView.swift:421` | `frame(height: 42)`. | Use `frame(minHeight: 44)`. |
| Lock plate | `Songs/SongsView.swift:1007` | `frame(height: 24)`. | Use `frame(minHeight:)` and allow 2 lines. |

### 3. P1 · Header controls are 36 pt targets that clip, and the "LV" caption is 6.8 pt · A, B
- **StreakChip** (`Design/GameUI.swift:35`) is `.frame(height: 36)` around `Typeface.label(14)` (caption-relative). The count clips vertically from about AX3. The snowflakes are fixed at 10 pt (`:28`).
- **LevelRing(size: 36)** is used at `Tune/TuneView.swift:184`, `Learn/LearnView.swift:212` and `Songs/SongsView.swift:267`. It is a 36 pt target, and its caption is `max(6.5, size*0.19)` = 6.8 pt (`Design/GameUI.swift:158`).
- **The Tune settings button** is 36×36 (`Tune/TuneView.swift:185-190`).
- **Fix:**
  - Keep the visuals and give each control `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`.
  - StreakChip: change to `.frame(minHeight: 36)`, scale its padding with `@ScaledMetric`, and render the flakes with `Typeface.label(10, relativeTo: .caption2)`.
  - Drop the "LV" micro-caption for rings under 44 pt. The VoiceOver label already says "Level 5".

### 4. P1 · Increase Contrast is ignored outside the tuner, and control boundaries are 1.24:1 · A
- **Where:** `colorSchemeContrast` is read only in `Tune/*`, which is 6 files. `Palette.inkSoft`, `inkFaint` and `line` are static (`Design/Theme.swift:12-16`).
- **What the user sees:**
  - inkFaint falls to 4.1:1 on `line` and 3.5:1 on tinted cards.
  - Chip, search-field and card outlines use `Palette.line` at 1.24:1 and do not respond to the setting.
- **Fix** (Theme.swift only, one change for every screen):
  - Make the tokens dynamic: `Color(uiColor: UIColor { $0.accessibilityContrast == .high ? hi : base })`.

    | Token | Base | High | Contrast on stageRaised (base → high) |
    |---|---|---|---|
    | inkSoft | #A3A8B1 | #C4C9D1 | 7.8 → 11.2:1 |
    | inkFaint | #80868F | #A3A8B1 | 5.1 → 7.8:1 |
    | line | #24272D | #5C626C | 1.24 → 3.0:1 |
    | `hairline` (new, finding 32) | white 6% | white 14% | n/a |

  - The per-view `strong ?` branches in Tune can stay, or be deleted later.

### 5. P1 · Disabled buttons look tappable · A, B, D, F
- **Where:** `BrassButtonStyle` and `ChipButtonStyle` (`Design/Components.swift:101-135`) never read `isEnabled`. The disabled controls that look live:
  - The mint "Start practice" button while the target tone plays (`Practice/VoiceView.swift:108`).
  - The "Hear target" chip while a take runs (`Practice/VoiceView.swift:135`).
  - The paywall purchase button while no plan is selected or a purchase is pending (`Paywall/PaywallView.swift:1203`) and the win-back purchase button (`Paywall/PaywallWinBack.swift:149`).
  - The ± buttons at ±12 semitones (`Instruments/CustomTuningEditor.swift:133-137`).
- **Fix:**
  - Inside both styles, use a small wrapper view that reads `@Environment(\.isEnabled)`.
  - Disabled prominent buttons: `Palette.surface` fill, `Palette.inkFaint` label, no glow.
  - Disabled chips: 45% opacity.
  - Then delete `ContinueButtonStyle` (`Onboarding/OnboardingView.swift:767-782`), which already hand-rolls exactly this.

### 6. P1 · Two primary-button systems with different shape, font and height · A, C, E, F
- **The two systems:**
  - `BrassButtonStyle` is a capsule with SF `.headline` at 54 pt. It is used in onboarding, tools, the paywall and Strum.
  - `StepButton` (`Learn/LessonPlayer.swift:426-447`) is a rounded rectangle (r18) with Sora 18 at 56 pt, plus a 3D lip.
- **Hand-built variants:**
  - The paywall CTA overrides the brass font with Sora 18 (`Paywall/PaywallView.swift:1194`, `Paywall/PaywallWinBack.swift:146`).
  - The Learn hero pill (`Learn/LearnView.swift:278-284`) and the Songs hero Play button (`Songs/SongsView.swift:415-425`) are custom capsules at 42 pt.
  - The results "Done" button is a custom Text (`Learn/LessonResults.swift:139-141`).
- **What the user sees:** "Continue" is a capsule on onboarding (05b) and a rounded block one tap later in the first lesson (06b).
- **Fix:**
  - Add `PrimaryButtonStyle(accent: Color = Palette.mint, shape: .capsule)` with one label font, `Typeface.label(17, relativeTo: .headline)`, and min height 54. Add `SecondaryButtonStyle` for "Done", "Hear it" and "Try again".
  - `StepButton` becomes a thin wrapper around them.
  - Remove the font overrides at the call sites.

### 7. P2 · The tab headers disagree · A, B, C, D, E, F
- **Where:**

  | Tab | Header | Trailing controls |
  |---|---|---|
  | Tune | `Tune/TuneView.swift:165-195` | Streak, level and settings |
  | Learn | `Learn/LearnView.swift:207-214` | Streak and level |
  | Songs | `Songs/SongsView.swift:255-270` | Streak and level |
  | Play | `Practice/PracticeView.swift:64-72` | Streak only |
  | Progress | `Journey/JourneyView.swift:69-71` | None |
  | Instruments | `Instruments/InstrumentsView.swift:68-89` | A 44 pt search circle |

  `ScreenTitle` (`Design/Components.swift:86-98`) is dead code, and each tab re-types `display(30).tracking(-0.6)`.
- **Fix:**
  - Add `TabHeader(title:subtitle:trailing:)` to Design, built on `ScreenTitle`. It carries the `.isHeader` trait and a standard trailing cluster of `StreakChip()` and `LevelRing(size: 36)`.
  - Use it on Learn, Songs, Play and Instruments. Play gains the LevelRing.
  - Progress keeps no cluster, because it is where those controls lead. Tune keeps its picker title but uses the same cluster.

### 8. P2 · Section headers come in 4 sizes and 2 styles, and Progress sections aren't headings · A, C, D, E, F
- **The sizes in use:**

  | Size | Where |
  |---|---|
  | `display(16)` | Progress: `Journey/JourneyView.swift:234,290,404,572,617`, `Journey/CoachCard.swift:99`, `Journey/WeekRecap.swift:87` |
  | `display(17)` | Play: `Practice/PracticeView.swift:144,196`, `Practice/DailySetCard.swift:217` |
  | `display(19)` | Game cards: `Practice/PlayHubGames.swift:141` |
  | `display(20)` | `Instruments/InstrumentsView.swift:93`, `Songs/SongsView.swift:437`, `Learn/LearnView.swift:347` |

- **The second style:** Ear training, Metronome and Settings use `Eyebrow` instead. "Recent" is an eyebrow in Ear training (`Practice/EarTrainingView.swift:254`) but a 16 pt title on Progress (`:617`).
- **The heading trait is missing** on the Progress section titles (Last five weeks, String health, Achievements, Tuning accuracy, Recent), so VoiceOver's rotor can't jump between them.
- **Fix:**
  - Add `SectionHeader(_ title:, trailing:)` for sections between cards: `display(20, relativeTo: .title3)` plus `.isHeader`.
  - Add `CardTitle(_:)` for titles inside a card: `display(17, relativeTo: .headline)` plus `.isHeader`.
  - Eyebrows are only for labels inside cards.

### 9. P2 · Lesson step titles change size and alignment from step to step · C
- **Where:**

  | Step | Location | Style |
  |---|---|---|
  | Explain | `Learn/LessonExplain.swift:140` | 30 pt, leading |
  | Tune check | `Learn/LessonSteps.swift:1155` | 28 pt, centred |
  | Strum | `Learn/LessonSteps.swift:786` | 26 pt, centred |
  | Quiz | `Learn/LessonPlayer.swift:630` | 26 pt, leading |
  | Play-along | `Learn/Highway.swift:198` | 24 pt, leading, `lineLimit(1) minScale 0.7` |

  Screenshots 51→52→54→56→59 show the title jumping at every step.
- **Heading trait:** LessonSteps, Highway and the results headline (`Learn/LessonResults.swift:99`) have no `.isHeader`.
- **Fix:** Add a `StepTitle(_:)` view in LessonPlayer.swift: `display(28, relativeTo: .title)`, leading, 2 lines then wrap, plus `.isHeader`. Use it for every step type.

### 10. P1 (copy) · "Listen" means opposite things · D
- **Where:**
  - Ear training's "Listen" with a speaker icon plays tones to the user (`Practice/EarTrainingView.swift:192`).
  - Drone, Intonation and Strum's "Listen" with a mic icon starts the microphone (`Practice/DroneSingAlong.swift:166`, `Practice/IntonationView.swift:56`, `Tune/StrumTuneView.swift:318`).
  - Lessons already call app-plays "Hear it" (`Learn/LessonPlayer.swift:476`).
  - "Listening" has no ellipsis at `Practice/IntonationView.swift:192`, while the rest of the app writes "Listening…".
- **Fix:**
  - Ear training uses "Hear it" / "Hear again".
  - "Listen" is reserved for the microphone.
  - Write "Listening…" everywhere.

### 11. P2 · Seven different close buttons · A, B, C, D, F

| Screen | Location | Build |
|---|---|---|
| Strum | `Tune/StrumTuneView.swift:97-103` | 44 pt circle on surface with a hairline; ink glyph at body size |
| Paywall | `Paywall/PaywallView.swift:258-262` | 44 pt circle on surface, no hairline |
| Pitch Sniper | `Practice/PitchSniperView.swift:52-55` | 44 pt circle at white 6%; 15 pt ink glyph |
| Lesson | `Learn/LessonPlayer.swift:267-273` | 34 pt circle at white 7%; 14 pt inkSoft glyph |
| Placement | `Onboarding/PlacementCheckView.swift:64-66` | Bare 17 pt inkSoft glyph |
| Calibration | `Learn/LatencyCalibration.swift:54-56` | Bare 15 pt inkSoft glyph |
| Results reminder | `Learn/LessonResults.swift:373-374` | 28×36 pt target with an inkFaint glyph (too small) |

- **Fix:**
  - Add `CloseButton(label: "Close", action:)`: a 44 pt target, a 34 pt `Palette.surface` circle with a `hairline`, and a 14 pt bold `Palette.ink` xmark.
  - Add a `BackButton` twin using `chevron.backward`, for the lesson part view.

### 12. P2 · Chips are 38 pt targets with three "selected" looks · A, B, C
- **Target size:** `ChipButtonStyle` (`Design/Components.swift:128`) is subheadline plus 9 pt padding, about 38 pt. It is used by every filter rail and by the custom-tuning ± buttons.
- **Onboarding chips** (`Onboarding/OnboardingView.swift:137-151`) are 44 pt with a mint-outline selected state and text in `0xC9FFEC`. The first screen's chip style never appears again; everywhere else the selected chip is an ink fill.
- **Segmented controls** come in four builds:
  - Notes/Tab: a custom 28 pt control (`Learn/SongOpener.swift:344-368`).
  - The minutes picker: a mint fill (`Onboarding/OnboardingView.swift:643-668`).
  - System grey segmented controls in Ear training, Metronome, Scales and Drone (`Practice/EarTrainingView.swift:76`, `Practice/MetronomeView.swift:327`, `Practice/ScalesView.swift:54`, `Practice/DroneView.swift:112`).
- **Fix:**
  - `ChipButtonStyle` gets `.frame(minHeight: 44)` with an inset capsule, so the visual stays at 36 pt.
  - Onboarding uses `ChipButtonStyle`.
  - Add `SegmentedPill(options, selection)` in Design, with the ink fill and dark text that chips use, for Notes/Tab and the minutes picker.
  - Leave the system segmented controls but tint them with `.tint(Palette.ink)`. Don't mix them on one screen.

### 13. P2 · The card radius scale is ignored · A, then all batches
- **Where:** `Metrics.corner` is 22 and `Metrics.cornerSmall` is 16 (`Design/Theme.swift:99-103`), but almost every call site uses a literal. Side-by-side tabs disagree:
  - **Play:** Today and level cards r24 (`Practice/DailySetCard.swift:209`, `Practice/PracticeView.swift:136`); game cards r24 (`Practice/PlayHubGames.swift:109`); quest rows r18 (`Design/GameUI.swift:235`, `Practice/PracticeView.swift:350`); tool tiles r16 (`Practice/PracticeView.swift:281`).
  - **Progress:** stat tiles r18 (`Journey/JourneyView.swift:219`); other cards r22.
  - **Results:** tiles r20 (`Learn/LessonResults.swift:463`).
  - **Onboarding:** option rows r20 (`Onboarding/OnboardingView.swift:239`).
  - **Heroes:** r28 (`Learn/LearnView.swift:301`, `Songs/SongsView.swift:302`).
  - **Other:** r26 (`Learn/LessonExplain.swift:194`, `Learn/Highway.swift:161`) and r30 (`Tune/Celebration.swift:80`).
- **Fix:**
  - Define `Metrics.cornerHero` = 28, `corner` = 22 (cards), `cornerTile` = 16 (tiles, rows, buttons, answers) and `cornerChip` = 12 (icon tiles).
  - Map the literals:

    | Literal | Becomes |
    |---|---|
    | 24 | 22 |
    | 18, 19, 20 | 16 for rows and tiles, 22 for cards |
    | 26, 30 | 28 |

### 14. P2 · Screen gutters jump between onboarding pages and lesson steps · B, C
- **What the user sees:** The primary button's width changes from page to page (screenshots 01, 05 and 05b).
- **Where:**
  - **Onboarding:** text at 28 pt with the button at 22 pt (`Onboarding/OnboardingView.swift:132,156,162`); 28 and 30 pt (`:290,298`); 24 pt (`:328,402,407`, `Onboarding/PlacementCheckView.swift:136,141,199`, `Onboarding/FirstTuneStep.swift:184`).
  - **Lessons:** 22 pt (`Learn/LessonExplain.swift:87`, `Learn/LessonPlayer.swift:480,637`, `Learn/Highway.swift:214`, `Learn/SongPerform.swift:154,261`, `Learn/LatencyCalibration.swift:61`); 24 pt (`Learn/LessonSteps.swift:775,1173`, `Learn/Highway.swift:358`); 26 pt (`Learn/LessonSteps.swift:913`); 30 pt (`Learn/LessonSteps.swift:146,1159`).
- **Fix:**
  - Use `Metrics.gutter` (20) for every screen edge and bottom button.
  - Add `Metrics.proseInset` = 8 for centred paragraphs that need extra side room, applied on top of the gutter.

### 15. P2 · About 20 eyebrows are hand-built in another face and tracking · A, B, C, D, E, F
- **The canonical `Eyebrow`** (`Design/Components.swift:77-84`) is SF caption2 semibold with tracking 2.2.
- **The hand-built ones** use Sora `label(11–13)` with tracking 1.0–1.8:
  - Learn: `Learn/LearnView.swift:275,346`, `Learn/SongOpener.swift:170,209,449`, `Learn/SongPerform.swift:148,257`, `Learn/SongStoryCard.swift:309,347` and `Learn/HighwayHUD.swift:42`.
  - Onboarding: `Onboarding/OnboardingView.swift:483,493,556`, `Onboarding/PlacementCheckView.swift:227,314`.
  - Elsewhere: `Practice/PlayHubGames.swift:373`, `Practice/PitchSniperView.swift:77`, `Songs/SongsView.swift:377`, `Journey/StreakCelebration.swift:83`, `Tune/Celebration.swift:395,483` and `Paywall/PaywallWinBack.swift:131`.
- **What the user sees:** "UNIT 1 · HELLO, GUITAR" (Learn) and "TUNINGS" (picker) are visibly different type.
- **Uppercasing:** About 8 of them use `.uppercased()` on localized strings, which is not locale-aware (Turkish "i").
- **Fix:**
  - Give `Eyebrow` a `Text` initializer and a `style: .system | .display` option. `.display` = `Typeface.label(11, relativeTo: .caption2)` with tracking 1.6.
  - Always use `.textCase(.uppercase)` instead of `uppercased()`.
  - Write `"Unit \(n) · \(title)"` in sentence case and let the eyebrow uppercase it.

### 16. P2 · One-off colours that should be tokens · A, then all batches

| New token | Value | Where it is used today |
|---|---|---|
| `Palette.spotlight` | 0xFFC48C | 11 sites: `Design/Components.swift:5`, `Tune/StrumTuneView.swift:50`, `Tune/Celebration.swift:299,358`, `Onboarding/OnboardingView.swift:107,112`, `Practice/EarTrainingView.swift:56`, `Practice/PitchSniperView.swift:42`, `Paywall/PaywallView.swift:94`, `Instruments/InstrumentsView.swift:369`, `Songs/SongsView.swift:95` |
| `Palette.flameInk` | 0xFFD3A8 | Streak text, 7 sites: `Design/GameUI.swift:23`, `Tune/Celebration.swift:44,354,409,483`, `Journey/StreakCelebration.swift:84`, `Learn/SongStoryCard.swift:442` |
| `Palette.frost` | 0x9FD8FF | `Design/GameUI.swift:28,632` |
| `Palette.starGold`, `Palette.starFill` | 0xF0A93B and a 0xFFE29A→0xF0A93B gradient | Copied three times: `Tune/Celebration.swift:390-391`, `Learn/SongStoryCard.swift:117,121,300-301`, `Learn/LessonResults.swift:54,446,449` |
| `Palette.onGold` | 0x1B1206 | `Design/GameUI.swift:622`, `Learn/LessonResults.swift:153,198`, `Paywall/PaywallView.swift:461`, `Paywall/PaywallPreview.swift:76`. `ProBadge` puts `Palette.onAccent` on the same gold, so there are two "dark on gold" inks. |

Colours to replace with existing tokens:
- "Restring soon" uses 0xFFC977 (`Journey/JourneyView.swift:292,348,367`). It is not `Palette.amber`; use amber.
- 0xC9FFEC (`Onboarding/OnboardingView.swift:143`) becomes `Palette.ink`.
- 0xEFFFF8 (`Tune/Readout.swift:244`) becomes `Palette.ink`.
- 0xE39A3B (`Onboarding/ChromaticStandIn.swift:67`, `Paywall/PaywallPreview.swift:80`) becomes `Palette.proGoldDeep`.

### 17. P2 · Learn path: Pro-gated and progress-locked lessons look and sound the same · C
- **Where:** `Learn/LearnView.swift:448-450, 475-476`. Both states draw `lock.fill`, and VoiceOver says "Locked" for both. Songs does distinguish them ("Timbre Pro" in gold vs "Finish …"). The current node's "START" pill (`:461-468`) is not announced.
- **Fix:**
  - Pro nodes get a `ProBadge` under the disc and the VoiceOver value "Timbre Pro".
  - The current node's value is "Next lesson".

### 18. P2 · The first-tune title overlaps its subtitle · B
- **Where:** Screenshot 05a, `Onboarding/FirstTuneStep.swift:172-181`. "E2 · Acoustic guitar" is drawn over the second line of "Pluck your thickest string". The title switches between a 1-line and a 2-line string through `.contentTransition(.opacity)`, and the subtitle keeps the old layout.
- **Fix:**
  - `.lineLimit(2, reservesSpace: true)` on the title.
  - Or swap with `.id(title).transition(.opacity)` inside a fixed-height container.

### 19. P2 (copy) · Fractions are written three ways · A, B, C, D, E
- **The three forms:**

  | Form | Where |
  |---|---|
  | "1 / 6" | `Tune/TuneView.swift:368`, `Practice/PracticeView.swift:133,342`, `Design/GameUI.swift:227`, `Practice/ScalesView.swift:220`, `Journey/JourneyView.swift:534,554` |
  | "1/3" | `Practice/DailySetCard.swift:278,454`, `Learn/LearnView.swift:246,353,354`, `Practice/EarTrainingView.swift:373`, `Journey/JourneyView.swift:637`, `Songs/SongsView.swift:440` |
  | "9 of 42" | `Journey/JourneyView.swift:406` |

- **Mixed on one screen:** Progress says "9 of 42" above badges reading "3 / 10".
- **No labels:** The Learn unit header stacks "★ 8/15" over a bare "3/5" (`Learn/LearnView.swift:353-354`), and course cards show a bare "3/96" (`:246`).
- **Fix:**
  - Add `Text.fraction(a, b)` in Design: "a / b" with thin spaces (U+2009) and the accessibility label "a of b". Use it for every compact counter.
  - Prose keeps "of".
  - Label the bare counters: "3 of 5 lessons", "3/96 lessons".

### 20. P2 (copy) · "Ear trainer" vs "Ear training" · D
- **Where:** The Play card says "Ear trainer" (`Practice/PracticeView.swift:213`, visible on iPad Play). The screen title, the Today row, the Shortcut and Progress all say "Ear training" (`Practice/EarTrainingView.swift:59`, `Practice/DailySetCard.swift:9`, `Intents/TimbreShortcuts.swift:32`, `Journey/JourneyView.swift:664`).
- **Fix:** Use "Ear training" on the card. If it's meant as a game name like Pitch Sniper, it needs Title Case everywhere instead.

### 21. P2 (copy) · Pro naming and restore wording drift · B, F
- **Pro naming:**
  - "What's in Pro" (`Paywall/PaywallView.swift:548`) sits beside a "TIMBRE PRO" pill.
  - The Settings precision level is called "Pro ±1¢" (`Settings/SettingsView.swift:240`). It is itself gated by Timbre Pro, so picking "Pro" opens the Pro paywall.
- **Restore wording:** It appears as "I already have Timbre Pro" (`Onboarding/OnboardingView.swift:173`), "Restore purchases" (`Settings/SettingsView.swift:87`) and "Restore" (`Paywall/PaywallView.swift:1224`).
- **Fix:**
  - "What's in Timbre Pro".
  - Rename the precision level to "Expert ±1¢".
  - The paywall link reads "Restore purchases". Onboarding can keep its sentence, but it should call the same action.

### 22. P2 · Tuner side controls: only one of four has a caption · B
- **Where:** "Strum" is captioned (`Tune/StrumTuneView.swift:543-548`). The reference tone, the automatic/manual toggle (wand ↔ hand icon, no words) and Listen are glyph-only (`Tune/TuneView.swift:381-392`).
- **Fix:** Caption all four the same way: Strum, Tone, Auto/Manual, Listen. Use `Typeface.label(10, relativeTo: .caption2)`, capped at xLarge, with a shared `StageControl(caption:)` parameter.

### 23. P2 · Stat tiles have 3 layouts, and the quest row is duplicated · A, C, D, E
- **Stat tiles:**
  - Progress: leading-aligned, r18, `number(22)` (`Journey/JourneyView.swift:212-221`).
  - Results: centred, r20, `number(24)`, no border (`Learn/LessonResults.swift:456-465`).
  - Week recap: an inline row (`Journey/WeekRecap.swift`).
- **Quest row:** `HubQuestRow` (`Practice/PracticeView.swift:322-366`) is a copy of `QuestRow` (`Design/GameUI.swift:209-253`).
- **Fix:**
  - Add `StatTile(symbol:tint:value:label:alignment:)` to Design. It handles the AX-size switch itself (finding 2).
  - Give `QuestRow` an optional `count: (done: Int, total: Int)` and delete `HubQuestRow`.

### 24. P2 · Icon buttons in six sizes, several of them under 44 pt · A, C, E, F
- **Visual sizes in use:**

  | Size | Where |
  |---|---|
  | 28 pt | Calibrate and band buttons (`Learn/Highway.swift:787-801, 855-880`) |
  | 30 pt | `Practice/ChordsView.swift:393-402`, `Learn/SongOpener.swift:485` |
  | 32 pt | Coach "next" (`Journey/CoachCard.swift:122-133`), a 32 pt target |
  | 34 pt | Lesson bar |
  | 36 pt | Tune settings |
  | 44 pt | `StageControl` |
  | 52 pt | `ListenOrb` |

- **Other targets under 44 pt:**
  - Coach action pill: `minHeight 36` (`Journey/CoachCard.swift:57`).
  - Notes/Tab: 28 pt (`Learn/SongOpener.swift:363`).
  - Paywall "Restore · Terms · Privacy": about 30 pt (`Paywall/PaywallView.swift:1237`).
  - "Continue with the free tuner": about 32 pt (`Paywall/PaywallView.swift:1179`).
  - Instruments clear-search: about 17 pt (`Instruments/InstrumentsView.swift:294`).
  - The Highway buttons use `.padding(-8)` around a 44 pt shape, so neighbouring hit areas overlap by 8 pt.
- **Fix:**
  - Add `IconButton(symbol:size: .compact (34) | .regular (44))` with a 44 pt hit area and no negative padding.
  - Text links get `.frame(minHeight: 44)`.

### 25. P2 · Pro badges are fixed-size and get scaled down · A, D, F
- **ProBadge** is fixed 10 pt heavy SF (`Design/Components.swift:146-154`). The tool tiles shrink it to an effective 8 pt with `scaleEffect(0.8)` (`Practice/PracticeView.swift:283`).
- **Plan tags** "SAVE 58%" and "14 DAYS FREE" are fixed 10 pt (`Paywall/PaywallView.swift:799, 806-807`).
- **The "TIMBRE PRO" pill** is another build: Sora 12 with tracking 2.2 and onGold (`Paywall/PaywallPreview.swift:76`).
- **The reward toast** detail is a fixed 11 pt and the toast is clamped to `.large` (`Design/GameUI.swift:579, 614`). It is announced to VoiceOver, so this is acceptable, but the detail should still use `.caption2`.
- **Fix:**
  - Add `Badge(text, style: .pro | .accent(Color))`: `Typeface.label(10, relativeTo: .caption2)`, `.dynamicTypeSize(...xxxLarge)`, never `scaleEffect`.
  - `ProBadge` becomes `Badge(.pro)`.

### 26. P3 (copy) · ¢ vs "cents" in visible copy · D, E
- **Where:**
  - String health says "drifts flat about 7 cents a day" (`Journey/JourneyView.swift:296`) directly under the Coach's "drifts 7¢ flat a day".
  - Voice says "0.5 s hold · ±75 cents" (`Practice/VoiceView.swift:117`; the en value is `timbre_voice_hold_requirement`). Everything else says ±5¢.
- **Fix:**
  - Use ¢ in all visible copy, and "cents" only in VoiceOver strings, as `Tune/Readout.swift:324,332` already does.
  - The en.lproj value change needs the l10n owner.

### 27. P3 (copy) · One feature, four names: Today / daily set / daily quest / Today's quests · A, B, C
- **Where:**
  - The card is "Today" (`Practice/DailySetCard.swift:217`).
  - Banners and results say "Daily set complete" (`Design/GameUI.swift:524`, `Learn/LessonResults.swift:190`).
  - Onboarding says "Your daily set is built around it." (`Onboarding/OnboardingView.swift:271`) and "a daily quest to keep you going" (`:129`).
  - The tuner says "Daily quest · every string" (`Tune/TuneView.swift:365`).
  - Play has "Today's quests".
- **Fix:**
  - "Today" is the three-activity set: "Today complete" and "Your Today plan is built around it".
  - "Quest" is the side goals: the tuner reads "Quest · tune every string".

### 28. P3 (copy) · "Accuracy" uses two units · E
- **Where:** Progress shows "±1.0¢ avg accuracy" (`Journey/JourneyView.swift:197`). Results show "96% accuracy".
- **Fix:** Label the Progress tile "avg tuning offset" (or "tuning ±1.0¢"), and keep "accuracy" as a percentage.

### 29. P3 (copy) · Case and wording drift inside single lines · C, D, F
- **Where:**
  - "Song 0:22 · lesson 6 min" (`Learn/SongOpener.swift:175`).
  - The paywall plan details are lowercase, "cancel anytime" and "pay once" (`Paywall/PaywallView.swift:696,699`), above a trust row reading "Cancel anytime" (`:814`).
  - "Late/early" (`Learn/Highway.swift:1996`), while the pops and the timing strip read "Early … Late".
  - "Check it" (`Practice/ChordsView.swift:253`) vs "Check" in lessons.
  - "+4 BPM every 4 bars up to 140" has no unit on 140 (`Practice/MetronomeView.swift:344`).
  - Level names are Title Case ("Sweet Spot", "Tuned Ear"; `Sources/TimbreCore/Practice/Progression.swift:88`) next to sentence-case badge names ("Golden ear") on the same screen.
- **Fix:**
  - Write "Song 0:22 · Lesson 6 min".
  - Capitalise the plan details: "Cancel anytime", "Pay once".
  - Write "Early/late" and "up to 140 BPM".
  - Pick one verb, "Check".
  - Change the level names to sentence case. This is a key change, so it needs l10n tooling.

### 30. P3 · Truncated plates and titles · C, E
- **Where:**
  - Locked song plates read "Finish Mary Had a Littl…" (`Songs/SongsView.swift:996-1008`). They are `lineLimit(1)` at a fixed 24 pt height.
  - The play-along title is `lineLimit(1) minimumScaleFactor(0.7)` (`Learn/Highway.swift:198`).
- **Fix:**
  - The plate allows 2 lines with `minHeight`, or reads "Unlocks after song 6".
  - The Highway title allows 2 lines; its header keeps `minHeight`.

### 31. P3 · Card padding drift · A, D, E
- **Where:** `stillCard` padding varies by screen: Play 16 (`Practice/DailySetCard.swift:209`, `Practice/PracticeView.swift:136`), Progress 18 (the default), Ear training 22 (`Practice/EarTrainingView.swift:169,355`) and Onboarding 14 (`Onboarding/OnboardingView.swift:458,612`).
- **Fix:**
  - `Metrics.cardPadding` = 18 and `Metrics.tilePadding` = 12.
  - The `stillCard(padding:)` default stays 18, and the parameter is limited to those two tokens.

### 32. P3 · Hairlines and dividers in five alphas · A, B, C, E, F
- **Card strokes:** `Palette.line` (17 sites), white 6% (7 sites), and white 8%, 12% or 14% elsewhere.
- **Dividers:**
  - `Palette.line` (`Paywall/PaywallView.swift:614`).
  - White 12% (`Tune/Celebration.swift:330,336`, `Learn/SongStoryCard.swift:445,451`).
  - White 16% (`Journey/JourneyView.swift:343`).
  - A private `RowDivider` in Settings.
- **Fix:**
  - `Palette.hairline` (white 6%) for card borders, `Palette.line` for dividers.
  - Move `RowDivider` into Design as `Hairline()`.

### 33. P3 · Empty and loading states are all ad hoc · A, D, F
- **Empty states:**
  - Instruments search shows plain text, "No instrument matches…" (`Instruments/InstrumentsView.swift:47`).
  - Chords shows text in a card (`Practice/ChordsView.swift:126`).
  - Ear training shows a dashed hint.
  - "Tap Listen to start" appears in three type styles: Sora 15 (`Practice/DroneSingAlong.swift:193`), system (`Practice/PitchSniperView.swift:95`) and `Practice/IntonationView.swift:192`.
- **Loading:** The paywall shows a 58 pt grey skeleton with a spinner (`Paywall/PaywallView.swift:710-713`).
- **Fix:**
  - Add `EmptyState(symbol:title:message:)` styled for Studio Noir. Use `ContentUnavailableView.search(text:)` for Instruments.
  - Add `StageSpinner()` (a tinted `ProgressView`) for loading.

### 34. P3 · Songs hero meta text over cover art can fall to 3.2:1 · E
- **Where:** `Songs/SongsView.swift:389-398`. White at 72% sits on art-derived gradients, and the title and eyebrow use raw `.white` rather than `Palette.ink`. With Reduce Transparency on, nothing changes.
- **Fix:**
  - Put a solid `Palette.stage` scrim at 0.55 behind the text block.
  - Use `Palette.ink` and `Palette.inkSoft` for the text.

### 35. P2 (motion) · 30 ad-hoc springs that should be four tokens · A, then all batches

| Proposed token | Value | Sites using it today |
|---|---|---|
| `Motion.page` | spring(0.5, 0.86): steps and pages | `Learn/LessonPlayer.swift:89,128,160,165,374`, `Onboarding/PlacementCheckView.swift:48`, `Tune/StrumTuneView.swift:224` (0.58), `Learn/SongOpener.swift:98,708` (0.6–0.62), `Onboarding/OnboardingView.swift:788` (0.62), `Learn/LessonExplain.swift:95` (0.6/0.85), `Paywall/PaywallView.swift:504` (0.6/0.85). Or reuse `Motion.settle`. |
| `Motion.pop` | spring(0.22, 0.55): combo, answers, nudges | `Learn/Highway.swift:1906`, `Learn/HighwayHUD.swift:47` (0.2/0.6) and `:80`, `Practice/EarTrainingView.swift:122`, `Instruments/CustomTuningEditor.swift:473`, `Learn/LatencyCalibration.swift:112` (0.18/0.5), `Journey/StreakCelebration.swift:160` (0.32) |
| `Motion.reward` | spring(0.45, 0.58): stars, badges, streak | `Learn/SongStoryCard.swift:271`, `Learn/LessonResults.swift:475,480,499,510,525`, `Practice/EarTrainingView.swift:555`, `Journey/StreakCelebration.swift:152,155` |

Keep, but name:
- `Root/RootView.swift:47` (0.45/0.9) becomes `Motion.settle`.
- `Paywall/PaywallView.swift:364` (0.9/0.85) becomes `Motion.hero`.
- `Design/GameUI.swift:510` (0.34/1) becomes `Motion.islandClose`.

### 36. P3 (motion) · About 70 ad-hoc eases in 12 durations · A, then all batches
- **Crossfades and fades:**
  - `easeInOut(0.2)` is used 9× in Strum and the string rail (`Tune/StrumTuneView.swift:153,306,307`, `Tune/StrumMeters.swift:117,349`, `Tune/StrumFinale.swift:79`, `Tune/StringRail.swift:91`, `Practice/EarTrainingView.swift:200,419`). Use `Motion.quick`.
  - `easeOut` at 0.15, 0.2, 0.22, 0.25, 0.3 and 0.35 for fades (Learn, Paywall, Celebration). Use a new `Motion.fade` = easeOut(0.25).
  - The studio→3D crossfade is `easeInOut(0.6)` (`Tune/TuneView.swift:237`, `Onboarding/FirstTuneStep.swift:199`, `Tune/StrumTuneView.swift:51`, `Learn/LessonResults.swift:522`). Use `Motion.reveal`.
- **Reduce Motion substitutes:** The `easeOut(0.2)` substitute is re-typed in several places (`Design/GameUI.swift:508,510`, `Learn/LessonResults.swift`). Add `Motion.reduced`.
- Reduce Motion itself is honoured well: only 10 animated files skip the check, and all of them are benign.

### 37. P3 · Legacy palette aliases hide what colour you get · A, plus each batch opportunistically
- **Where:** `Palette.brass` (39 uses) renders mint, and `Palette.ember` (10 uses) renders amber (`Design/Theme.swift:32-34`). That makes code review of colour choices unreliable.
- **Fix:**
  - Mark the aliases `@available(*, deprecated, renamed: "mint")`.
  - Each batch renames them in its own files.

---

## Verified OK (no action)
- **Tuner state is not colour-only.**
  - "Tighten · 13¢ flat" text and a signed number accompany every colour.
  - `PitchMark` ▲▼✓ appears with Differentiate Without Colour (`Tune/Readout.swift:13-40`).
  - The string chips get a ✓ badge, and the strum lanes use arrows and ✓.
- **Icon-only buttons:** A scan of every `Button` whose label is only an `Image` found none without `accessibilityLabel` (`StageControl` callers label it).
- **Reduce Transparency:** The only material is the system `ultraThinMaterial`/glass in `glassCapsule` (`Design/Components.swift:68-74`), which adapts on its own. The one risk is the art scrim (finding 34).
- **Paywall at AX sizes:** It already adapts (`typeSize` branches, and the bottom bar is clamped to AX1).
- **Lesson chrome:** It is clamped to AX1 on purpose (`Learn/LessonPlayer.swift:197,373`).

---

## Batches (parallel, disjoint files)

Batch A lands the API, and B–F code against the names below at the same time. With no compiler here, B–F should copy the signatures exactly. If A is late, a batch keeps its literal and leaves a `// DESIGN11` marker.

**API contract from Batch A**
- **Typeface:**
  - `Font.TextStyle.matching(_:)`
  - `display`, `label` and `number` take `relativeTo: Font.TextStyle? = nil`, which means `.matching(size)`.
- **Palette:**
  - `spotlight`, `flameInk`, `frost`, `starGold`, `starFill`, `onGold`, `proGoldDeep`, `hairline`
  - `inkSoft`, `inkFaint` and `line` become adaptive.
- **Metrics:** `cornerHero` = 28, `corner` = 22, `cornerTile` = 16, `cornerChip` = 12, `cardPadding` = 18, `tilePadding` = 12, `gutter` = 20, `proseInset` = 8.
- **Motion:** `page`, `pop`, `reward`, `fade`, `reveal`, `reduced`, `hero`, `islandClose`.
- **Button styles:**
  - `PrimaryButtonStyle(accent:)` and `SecondaryButtonStyle()`. `BrassButtonStyle` is kept as an alias of `PrimaryButtonStyle`.
  - `ChipButtonStyle` and `PrimaryButtonStyle` honour `isEnabled`, and `ChipButtonStyle` gets a 44 pt minimum.
- **Views:**
  - `TabHeader(title:subtitle:trailing:)`
  - `SectionHeader(_:trailing:)`
  - `CardTitle(_:)`
  - `Eyebrow(_ text: Text, color:, style:)`
  - `CloseButton(label:action:)` and `BackButton(action:)`
  - `IconButton(symbol:size:action:)`
  - `SegmentedPill(options:selection:)`
  - `StatTile(symbol:tint:value:label:alignment:)`
  - `Badge(_:style:)`, with `ProBadge` kept as `Badge(.pro)`
  - `EmptyState(symbol:title:message:)` and `StageSpinner()`
  - `Hairline()`
  - `Text.fraction(_:_:)`
  - `QuestRow(quest:count:)`
- **StreakChip and LevelRing:** 44 pt hit areas, a flexible chip height, and no "LV" caption under 44 pt.

| Batch | Files | Findings |
|---|---|---|
| **A: tokens and components** | `Design/Theme.swift`, `Design/Components.swift`, `Design/GameUI.swift`, and a new `Design/Kit.swift` for the new views | 1, 3 (chip and ring), 4, 5 (the styles), 6 (the styles), 7, 8, 11, 12 (chip style and `SegmentedPill`), 13, 15, 16 (definitions and `GameUI` sites), 19 (helper and `GameUI:227`), 23 (`StatTile`, `QuestRow`), 24, 25, 27 (`GameUI:524`), 31, 32, 33, 35/36 (tokens and `GameUI:508-510`), 37 |
| **B: Tune and onboarding** | `Tune/TuneView.swift`, `Tune/StrumTuneView.swift`, `Tune/StrumMeters.swift`, `Tune/StrumFinale.swift`, `Tune/StringRail.swift`, `Tune/Celebration.swift`, `Tune/Readout.swift`, `Onboarding/OnboardingView.swift`, `Onboarding/FirstTuneStep.swift`, `Onboarding/PlacementCheckView.swift`, `Onboarding/ChromaticStandIn.swift` | 3 (settings button `TuneView:185-190`), 5 (delete `ContinueButtonStyle`), 7 (Tune trailing cluster), 11 (Strum, Placement), 12 (onboarding chips and minutes → `ChipButtonStyle`/`SegmentedPill`), 13, 14 (onboarding gutters), 15, 16, 18, 19 (`TuneView:368`), 21 (onboarding restore line), 22, 27 (`TuneView:365`, `Onboarding:129,271`), 32 (Celebration dividers), 35/36 |
| **C: Learn, lessons and song sheet** | `Learn/LearnView.swift`, `Learn/LessonPlayer.swift`, `Learn/LessonSteps.swift`, `Learn/LessonExplain.swift`, `Learn/LessonResults.swift`, `Learn/Highway.swift`, `Learn/HighwayHUD.swift`, `Learn/HighwayTimingStrip.swift`, `Learn/LatencyCalibration.swift`, `Learn/SongOpener.swift`, `Learn/SongPerform.swift`, `Learn/SongStoryCard.swift`, `Learn/WeakSpotReview.swift`, `Learn/LessonBeatRow.swift`, `Learn/LessonMotion.swift` | 2 (results tiles, course cards, Continue pill), 6 (`StepButton` → `PrimaryButtonStyle`, results Done, Learn pill), 7 (Learn header), 8 (unit titles), 9, 11 (lesson bar, calibration, reminder), 12 (Notes/Tab → `SegmentedPill`), 13, 14 (lesson gutters), 15, 16 (star gold, onGold, flameInk), 17, 19, 23 (results → `StatTile`), 24 (Highway buttons, Notes/Tab), 27 (`LessonResults:190`), 29 (`SongOpener:175`, `Highway:1996`), 30 (Highway title), 32 (SongStoryCard), 35/36 |
| **D: Play hub and practice tools** | `Practice/PracticeView.swift`, `Practice/DailySetCard.swift`, `Practice/PlayHubGames.swift`, `Practice/PlayHubTools.swift`, `Practice/EarTrainingView.swift`, `Practice/PitchSniperView.swift`, `Practice/MetronomeView.swift`, `Practice/DroneView.swift`, `Practice/DroneSingAlong.swift`, `Practice/DroneTanpura.swift`, `Practice/IntonationView.swift`, `Practice/VoiceView.swift`, `Practice/VoiceKeyboard.swift`, `Practice/ChordsView.swift`, `Practice/ScalesView.swift` | 2 (tools, Today ring, ear ring, Sniper score, BPM), 5 (`VoiceView:108,135`), 7 (Play header), 8 (Play sections, game titles), 10, 11 (Sniper close), 13, 15, 16, 19, 20, 23 (delete `HubQuestRow`), 25 (tool-tile badge), 26 (`VoiceView:117`), 29 ("Check it", "up to 140"), 31, 33 ("Tap Listen to start", Chords empty), 35/36 |
| **E: Progress and Songs** | `Journey/JourneyView.swift`, `Journey/CoachCard.swift`, `Journey/WeekRecap.swift`, `Journey/StreakCelebration.swift`, `Songs/SongsView.swift`, and optionally `Sources/TimbreCore/Practice/Progression.swift` (level-name case, l10n keys) | 2 (Progress stats, Songs hero button, lock plate), 6 (Songs hero Play), 7 (Progress, Songs headers), 8 (Progress sections + `.isHeader`, shelf titles), 13, 15, 16 (Restring amber, flameInk, spotlight), 19, 23 (Progress → `StatTile`), 24 (Coach next and pill), 26 (`JourneyView:296`), 28, 29 (level names), 30 (lock plate), 31, 32 (`JourneyView:343`), 34, 35/36 |
| **F: Instruments, Settings, Paywall, Root** | `Instruments/InstrumentsView.swift`, `Instruments/CustomTuningEditor.swift`, `Settings/SettingsView.swift`, `Paywall/PaywallView.swift`, `Paywall/PaywallWinBack.swift`, `Paywall/PaywallPreview.swift`, `Root/RootView.swift` | 5 (paywall purchase, win-back, custom-tuning ±), 6 (paywall CTA font override), 7 (Instruments header), 8 (Instruments sections), 11 (paywall close), 13, 15 (`PaywallWinBack:131`, plan tags), 16 (spotlight, onGold, proGoldDeep), 21 ("What's in Timbre Pro", "Expert ±1¢", "Restore purchases"), 24 (paywall links, clear-search), 25 (plan tags, TIMBRE PRO pill), 29 (plan detail case), 32 (`RowDivider` → `Hairline`, table divider), 33 (Instruments search empty state, paywall loading), 35/36 (`PaywallView:364,504`, `RootView:47`) |

**Notes for every batch**
- Keep every `accessibilityIdentifier`, because the UI tests depend on them.
- English source strings are l10n keys. Copy changes (findings 10, 19–21, 26–29) need the localization owner to re-key the other languages, so leave the .lproj files untouched.
- Batch E's `Progression.swift` change is optional for the same reason.

---

## Batch A delivered: names → usage

Files: `Design/Theme.swift` (tokens; also built into the widget extension), `Design/Components.swift`, `Design/Glass.swift`, `Design/GameUI.swift`, new `Design/Kit.swift`. Every old name still compiles; `Palette.brass/brassDeep/ember`, `Metrics.cornerSmall` and `BrassButtonStyle` now warn (deprecated) so you can rename them in your files. The contract's signatures are as written above; extras are marked *(extra)*.

**Type** (finding 1)
- `display/note/displayLight/number/label(size, relativeTo: Font.TextStyle? = nil)`: nil now means `Font.TextStyle.matching(size)`. Drop `relativeTo:` unless you mean a different curve.
- Roles: `Typeface.screenTitle` (30/largeTitle), `stepTitle` (28/title: use it for `StepTitle`), `sectionTitle` (20/title3), `cardTitle` (17/headline), `button` (17/headline), `eyebrowDisplay` (11/caption2), `badge` (10/caption2, also the tuner's side-control captions).
- Hero numerals: `Text(…).font(Typeface.hero(56)).heroNumeral()`. `heroNumeral(cap: .accessibility1, minimumScale: 0.5)` gives one line, shrink to fit, and no growth past AX1. Use it for the ear ring, Sniper score, BPM and the Today ring.

**Colour** (findings 4, 16, 32)
- Adaptive with Increase Contrast, no code needed: `inkSoft`, `inkFaint` (base is now #8A9099, which gives 4.6:1 on `line`), `line` (#60666F high), `hairline`.
- New: `controlLine` *(extra)* is the edge of a control: unselected chip, search field, secondary button, segmented track. It is 1.8:1 at base and 3.9:1 in high contrast. Use it instead of `Palette.line` on control outlines.
- New: `spotlight`, `flameInk`, `frost`, `starGold`, `starFill` (gradient), `onGold`, `proGoldDeep`, `hairline`.
- Borders: card border `Palette.hairline` (stillCard already uses it), dividers `Hairline(leading:)`, control edges `controlLine`.

**Metrics** (13, 14, 31): `gutter` 20, `proseInset` 8, `cornerHero` 28, `corner` 22, `cornerTile` 16, `cornerChip` 12, `cardPadding` 18 (stillCard default), `tilePadding` 12. *(extra)* `minTarget` 44 and `buttonHeight` 54.

**Motion** (35, 36)
- Tokens: `page`, `pop`, `reward`, `hero`, `islandClose`, `fade` (easeOut 0.25), `reveal` (easeInOut 0.6), `reduced` (easeOut 0.2).
- Existing tokens: `pluck`, `settle`, `quick`, `island` and `morph`.
- Reduce Motion: `withMotion(Motion.page, reduceMotion: reduceMotion) { … }`, `.adaptiveAnimation(Motion.pop, value: x)`, `.transition(.adaptive(.move(edge: .bottom), reduceMotion: reduceMotion))` and `Motion.adaptive(_:reduceMotion:)`.
- Fades are kept under Reduce Motion. Decorative loops stop.

**Buttons** (5, 6, 12)
- `PrimaryButtonStyle(accent: = mint, shape: .capsule | .rounded)` and `SecondaryButtonStyle(tint: Color? = nil, shape:)`.
- Both use one font (`Typeface.button`) at a minimum height of 54. Disabled, they look disabled.
- Remove label `.font` overrides at call sites.
- `BrassButtonStyle()` maps to `PrimaryButtonStyle()`, and `BrassButtonStyle(prominent: false)` to `SecondaryButtonStyle()`.
- `GlassActionButtonStyle(tint:collapsed:busy:)` uses the same font and shows a disabled look. Batch F should pass `busy: purchasing` so the spinner stays mint when Reduce Motion is on.
- `ChipButtonStyle(selected:)` keeps a 36 pt pill inside a 44 pt target, dims to 45% when disabled, and keeps the glass selected look.
- `SegmentedPill(options:selection:tint: = ink, identifier:) { value in Text(…) }`.

**Views** (Kit.swift unless noted)
- `TabHeader(title:subtitle:)` uses the standard cluster. `TabHeader(title:subtitle:showsToday: false)` is for Play. `TabHeader(title:subtitle:) { custom trailing }` is for Instruments. Title and subtitle take `LocalizedStringKey` or `Text`. The cluster alone is `HeaderControls(showsToday:)` *(extra)*, for Tune.
- `ScreenTitle(title:subtitle:)` (Components) now also takes `Text`.
- `SectionHeader("…") { trailing }` and `CardTitle("…")` both carry `.isHeader`.
- `Eyebrow(_ LocalizedStringKey | Text, color: = mint, style: .system | .display)` (Components). Write sentence case, and don't call `uppercased()`.
- `CloseButton(label: = "Close", glass: = false) { }` and `BackButton(label: = "Back", glass:) { }`. Add your `.accessibilityIdentifier` to them.
- `IconButton(symbol:size: .compact | .regular, tint:, label:, glass:) { }` has a 44 pt target, so don't add negative padding.
- `StatTile(symbol:tint:value: Text, label: Text | "key", alignment:)`. Put tiles in `StatTileRow { … }` *(extra)*: equal heights, and stacked at AX sizes.
- `Badge("Save 58%", style: .pro | .accent(c) | .solid(c))` and `Badge(.pro)`. `ProBadge()` is `Badge(.pro)` and VoiceOver reads it as "Timbre Pro". Don't apply `scaleEffect`.
- `EmptyState(symbol:title:message:) { optional actions }` and `StageSpinner("optional line")`.
- `Hairline(leading:vertical:)` replaces Settings' `RowDivider`. Its inset is 58.
- `Text.fraction(a, b)` shows "a / b" and reads "a of b".
- `.tapTarget()` *(extra)* sets a 44 pt minimum on text links.
- `QuestRow(quest:count:)` (GameUI). Pass `count:` only if you already have it, because it reads `store.questCounter` itself. Delete `HubQuestRow` and use `QuestRow(quest: quest)` inside your Button.

**Done inside Design**
- `StreakChip` has a flexible height of at least 36, a 44 pt target, scaled insets and caption2 flakes. It is clamped at AX1 with the Large Content Viewer.
- `LevelRing` has a 44 pt target and no "LV" under 44 pt. Its type is clamped at xxxL.
- The toast uses `Motion.reduced`/`islandClose`, a caption2 detail, `onGold`/`frost`, and reads "Today complete".
- `stillCard` gets a brighter rim and a fainter tint wash in high contrast.
- `FeatureRow` detail wraps at AX sizes.
- The default `StageBackground` glow is now `spotlight`.

**New English keys (l10n owner):** "Today complete" (replaces "Daily set complete" in the toast) and "Back" (the `BackButton` default label). Everything else reuses existing keys: "Close", "PRO", "Timbre Pro", "%lld", "%lld of %lld".
