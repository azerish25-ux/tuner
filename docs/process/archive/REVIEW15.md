# REVIEW 15: Timbre (iOS), foreman's verdict for the six-juror panel

Panel:
- visual (8.6);
- delight and innovation (8.3);
- inclusivity (8.3);
- technical and acquirer due diligence (8.1);
- growth and App Store editorial (7.4);
- category expert (7.8).

I read all six verdicts and the brief. I then re-checked the claims that carry the most weight against the code in `/home/claude/tuner/ios` (branch `v2/foundations`, HEAD `7c8d46c`) and against the review15 frames, the store sheet and the App Preview frames. My verification log is in §6. Where a juror is wrong or overstates, I say so there.

---

## 1. Overall score: **7.7 / 10**

### How I combined the six angles

The owner's bar is "#1 on **all** angles" and $10k a month. A plain mean (8.08) would hide the weakest angles, and those are the ones that decide whether an ordinary person installs and pays. So I combine the scores in two steps.

**Step 1: a weighted mean, 8.00.**
- Growth and Category carry ×1.5, because they decide user choice and revenue.
- Visual, Delight and Technical carry ×1.0.
- Inclusivity carries ×0.75, because it is where Timbre already leads.
- The sum is (8.6 + 8.3 + 0.75·8.3 + 8.1 + 1.5·7.4 + 1.5·7.8) / 6.75 = 54.03 / 6.75 = **8.00**.

**Step 2: a weakest-link gate, 7.7.** I average the weighted mean with the lowest angle: (8.00 + 7.4) / 2 = **7.70**. You are only #1 everywhere when your worst angle is #1.

### Why this is far below REVIEW14's 8.9

REVIEW14 scored craft dimensions such as tuner, motion and platform. It never audited the things that happen off the screenshot. This panel did, and the panel and I verified six latent blockers:
1. **Every fresh install runs in English** on every device language.
2. **One bad state file locks the user out** forever.
3. **Strumming steps grade timing only**, never the chord.
4. **The tuner's haptics are very likely muted** while the microphone listens.
5. **There is zero funnel measurement.**
6. **The App Preview is silent** and never shows a lock.

Those are not polish. They decide whether the app is trustworthy and whether it can sell.

### The craft is real

These were checked on screen and in code:
- **The tuner stage** (10, 10b).
- **The highway** (60, 65).
- **The `PolyTuner` strum solver** (`PolyTuner.swift:66-96`).
- **A tuner that works with VoiceOver**, with deeper accessibility than any competitor.
- **An honest trial timeline**, the best in the category.

This is an excellent engine wearing a component-library suit and sold by a silent ad.

### Scoreboard: who is #1 today, angle × competitor

| Angle (score) | vs GuitarTuna | vs Fender Tune | vs Fender Play | vs Yousician | vs Simply Guitar | vs JustinGuitar | **#1 on the angle today** |
|---|---|---|---|---|---|---|---|
| **Visual & interaction (8.6)** | **Split.** Timbre in-app: a lit 3D headstock, peg ring and stage wash (10, 10b) against a flat needle. GuitarTuna wins the store creative and its recognisable brand. | **Timbre.** 7 instruments in 3D and 37 photo rigs, against one headstock and a meter. | **Split.** Fender's filmed hands beat Timbre's dot-only "Show me" (51b). Timbre's UI and highway beat Fender's. | **Timbre, narrowly.** The highway (60, 65) is at least Yousician's play screen. | **Simply.** One bespoke illustrated language; Timbre has 20 `IconOrb`s, 236 `Capsule()`s and 53 eyebrows. | **Timbre.** Every screen is more polished. | **Split.** Timbre on in-app craft; Simply on art direction; GuitarTuna on the store page. |
| **Delight & innovation (8.3)** | **Timbre, narrowly.** A pitched lock bell, the comet and strum-to-tune. GuitarTuna has more games and known songs. | **Timbre.** Fender Tune has no "moments". | **Split.** Timbre on novelty (highway, 3D). Fender on warmth (a real band, real teachers). | **Yousician on Fun, Timbre on Innovation.** Yousician plays a recorded backing out loud; Timbre plays a click on the speaker (`AudioService.swift:544`). | **Simply on Fun.** Queen against *Porchlight*. Timbre on craft. | **Justin on personality.** Timbre on game feel. | **Timbre on Innovation; Yousician on Fun.** |
| **Inclusivity (8.3)** | **Timbre.** A VoiceOver tuner and Differentiate Without Colour. GuitarTuna wins left-handed use with an app-wide mode. | **Timbre, decisively.** AppleVis calls Fender Tune "usable with workarounds". | **Timbre.** Fender has no left-handed lessons. | **Timbre.** Yousician wins left-handed use (mirrored charts and hand). | **Timbre.** | **Timbre.** JustinGuitar's iOS app is reported inaccessible to VoiceOver. | **Timbre: the only clean #1.** It is not ADA level, because blind players cannot play along (`Highway.swift:145-146`). |
| **Technical (8.1)** | **Split.** Timbre on technology (`PolyTuner`, Watch, Live Activity). GuitarTuna on maturity: telemetry, scale, sync, Mac and visionOS. | **Timbre.** | **Split.** Timbre on technology. Fender on infrastructure (accounts, sync). | **Yousician, narrowly.** Recognition proven at scale, live operations and sync. | **Even.** Simply's recognition is battle-tested; Timbre leads on platform. | **Timbre.** | **Yousician, narrowly.** Timbre takes it with the blockers fixed, a real-audio corpus and iCloud sync. |
| **Growth (7.4)** | **GuitarTuna.** 4.8★ from 149K ratings, "Chords, Tabs & Lyrics", three price tiers. | **Fender Tune.** Free, 152K ratings. | **Fender.** Brand, licensed songs, a gear tie-in. | **Yousician.** A licensed catalogue and revenue. | **Simply.** About 400K ratings and a song-led funnel. | **Justin.** Teacher trust and YouTube. | **GuitarTuna / Simply. Timbre is last:** 0 ratings, no analytics and a silent preview. Its only beachhead is the violin, cello and ukulele long tail. |
| **Category: what a player picks (7.8)** | **Split.** Timbre for a tuner-first player. GuitarTuna for songs (20,000+); it wins the mass market. | **Split.** Timbre's auto tuner is better. Fender Tune gives more away free (26 tunings, 5,000 chords). | **Fender.** 3,000 video lessons and 1,000+ songs. Timbre leads on feedback, price and breadth. | **Yousician** for a guitarist who wants hits, with chord judging. **Timbre** for string players. | **Simply** wins week one (video and a famous song). | **Justin** for guitar pedagogy. | **Split.** Timbre is #1 on the tuner, breadth and price; behind on songs, teaching media and chord feedback. |

**Count:**
- **A clean #1 on 1 of 6 angles:** Inclusivity.
- **Split on 3:** Visual (in-app craft only), Delight (Innovation only) and Category (tuner, breadth and price only).
- **Lost on 2:** Technical, to Yousician narrowly, and Growth, where Timbre is last.

**What an ordinary person does today:**
- A **"guitar tuner"** searcher sees a 0-rating, dark listing next to a 4.8★ GuitarTuna with 149K ratings, and installs GuitarTuna.
- A **"learn guitar"** searcher installs Simply or Yousician for the songs they know.
- A **"violin tuner"** or **"learn ukulele"** searcher would pick Timbre, but the listing never speaks to them.

---

## 2. Consensus findings and blockers (deduplicated)

### 2a. Blockers (each verified by me; must ship before launch)

| # | Blocker | Jurors | Evidence (verified) | Package |
|---|---|---|---|---|
| B1 | **Fresh installs ignore the device language.** All 49 locales are invisible until the user finds Settings › Language. | technical (+ inclusivity, growth on l10n) | `LocalStore.swift:10` sets `language = "en"`. The only writer is `SettingsView.swift:374`. `RootView.swift:36-37` and `Catalog.swift:21-26` follow it. The UI tests pin `-AppleLanguages (en)`, so CI is blind to it. | WP1 |
| B2 | **One decode or validation failure bricks the app**, and the streak is lost. | technical | `LocalStore.swift:195-201` (throws), `:314-342` (strict validation, `version == 1`); `TimbreApp.swift:15-22` is a Retry that fails forever. | WP1 |
| B3 | **The tuner's haptics are very likely silent while the microphone is open.** That covers the detent, the lock, the highway and Bullseye. | delight, technical | Zero `setAllowHapticsAndSystemSoundsDuringRecording` in the repo; `.playAndRecord` at `AudioService.swift:245`. Apple documents the default as `false`. **Needs a device to confirm. The fix is one line plus a check for vibration bleeding into the microphone.** | WP1 |
| B4 | **Strum and progression steps grade timing only.** Open strings or a wrong chord earn "Flawless". This breaks the listing's "whole chords and strumming rhythm" claim. | category | `LessonSteps.swift:1509` (`chords: false`); `register` `:1520-1530` grades onset distance only. *(Melody song takes are pitch-judged; see §6.)* | WP4 |
| B5 | **Nothing is measured**, so nothing can be tuned toward $10k. | growth, technical | `Analytics.swift:32-35` (empty ID ⇒ nil). `paywall_shown` is logged only in `AppStore.swift:472`, so the onboarding paywall's impression is never logged. There is no `app_open`, no trial or price on `purchase`, and no server notifications. | WP2 |
| B6 | **The App Preview is silent.** The lock is never on camera, the poster is a double exposure, AUTO flips to MANUAL, and the last 9.6 s are a still Songs tab. | visual, delight, growth | `preview.py:509` (`anullsrc`), `:49`/`:502` (⅓ s crossfades). In PREVIEW.txt the lock clip ends at 91.43 s, before the lock sync at 91.47 s, and the poster at 3.45 s falls inside the 3.40–3.73 s overlap. The preview sheet shows the double exposure and MANUAL. | WP3 |
| B7 | **Store #2 shows a ghosted combo digit ("74").** | visual | Frame 65. `HighwayHUD.swift:37` and `:67` still use `.numericText`; only the score was frozen. | WP6 (day 1) → WP3 |
| B8 | **A blind learner can tune but cannot learn.** The play-along is one opaque element, VoiceOver focus never moves, and the results hide the stars. | inclusivity | `Highway.swift:145-146`. There are 0 `AccessibilityFocusState`/`.screenChanged` in the app. `LessonResults.swift:601` hides the stars with no replacement. | WP6, WP4, WP7 |
| B9 | **Pro is revoked during Billing Grace Period.** This is a blocker the moment the owner turns grace on. | technical, growth | `Access.swift:28-29` requires `expiresAt > now`; `CommerceService.swift:161-164` passes `transaction.expirationDate`. `Timbre.storekit` has `familyShareable: false` on all three products. | WP1 |
| B10 | **The paywall's renewal terms are English in 48 storefronts**, which is a legal and review exposure. | inclusivity, technical | `PaywallView.swift:1414`; 474–475 UI keys are missing in all locales, and the CI gate only warns. | WP10 (pipeline), owner (translators) |
| B11 | **The iPad CI is red, and iPad store frame #2 has no valid capture.** | visual, growth, technical | `TabletScreenshotsUITests.swift:110`; `ipad-landscape-instruments-wrong.png`. | WP3 |

### 2b. Consensus majors (raised by two or more jurors)

| Finding | Jurors | Verified evidence | Package |
|---|---|---|---|
| **No songs the buyer knows, and the count is inflated.** The paywall says "159 songs"; there are 159 song *lessons* but 124 distinct titles. | growth, category, delight | `PaywallView.swift:483-486` counts `kind == .song`. 50 Originals with no recognition value. | owner (licensing) + WP2/WP3 (copy) + WP5 (PD and uke songbooks) |
| **The store screenshot set is one template applied nine times.** No colour story, an eyebrow taking headline room, Show me caught at rest, and no "Free · No ads" frame. | visual, growth, delight | `screenshots.py:121-130`, `:165-209`, `:182`. The store sheet confirms it. | WP3 |
| **"Show me" is dots with no hand.** Physical technique is text only (87 steps). Ukulele and banjo get no model. The string glow is beaded. | visual, delight, category | `ShowMeScene.swift:505-513` (stacked-alpha segments; visible in 51b); `ShowMe.swift:11-12`. | WP9 + owner (hand rig, clips, usdz) |
| **The left-handed setting is cosmetic.** | inclusivity, category | `handedness` is read only at `StringRail.swift:16` and `StrumModel.swift:325`. | WP9 (+ WP2 ask, WP6 lanes, WP4 strum stage) |
| **Localisation is broken end to end.** B1, plus 26 % of the UI and 20 % of the lessons are untranslated, specifiers are mis-inferred, plurals are missing, and the 9 localized listings are stale (38 stale counts). | inclusivity, technical, growth | `HANDOFF.md`; `APP-STORE-LISTING-LOCALIZED.md`. | WP1, WP10, WP3, owner |
| **Rewards are category templates.** `star.fill` stars, a Duolingo-style flame screen, one 22-dot burst everywhere, and "Great work" at 6 peaks. | visual, delight | `LessonResults.swift:588-602`; `StreakCelebration.swift:54-164`; `SparkBurst` in `LessonPlayer.swift:587-608`; 62. | WP7 |
| **"Template / AI" visual tells.** | visual (and delight on rewards) | Counts verified: 20 `IconOrb(`, 236 `Capsule()`, 53 `Eyebrow(`, 31 Sora sizes, and a mint glow on every primary button. Paywall orbs in three hues per screen (06). | WP8 |
| **Vibe-coded engineering tells.** 14 "review N / bug N" comments in 10 files. Scratch files at the repo root; `findings.md` leaks a personal Windows path and auth notes. 232 of 233 commits by one author, 50 WIP / `[skip ci]` commits, 0 `#Preview`, no lint, Swift 5 mode, 16 app unit tests. | technical, visual | Verified (§6). | WP10 |
| **Free tier cut in the wrong places.** Mandolin and banjo can't be tuned free. Capo, open chords, scales, subdivisions and custom tunings are Pro. Guitar has 5 free lessons. | growth, category | `catalog.json` `isFree` (5 instruments); `PracticeView.swift:571-577`; `SettingsView.swift:150,162`; `MetronomeView.swift:286`; curriculum (guitar 5/153 free). | WP5 + WP1 (`Access`) + owner |
| **Real-audio evidence is missing.** Every DSP test uses synthesized signals. | technical, category | `Tests/Fixtures` holds only `Timbre.storekit`. | WP4 + owner (recordings) |
| **The band is thin.** Performances hold a tonic bass under every bar, and on the speaker the band is a click. | delight (category: "no real recording") | `SongPerform.swift:83-86` → `Band.swift:46-55`; `AudioService.swift:544`. | WP6 + owner (stems) |
| **No accessibility verification.** | inclusivity, technical | 0 `performAccessibilityAudit`; no AX5, RTL or German frames. | WP10 |
| **String order flips between screens.** | visual, inclusivity | Tuner rail low→high (07, 10) against tune check and intonation (52, 46). | WP4, WP9, WP7 |
| **Pricing and packaging.** | growth (category cautions price is a strength) | $34.99 / $6.99 / $89.99 in `Timbre.storekit`. Lifetime appears on the onboarding paywall (06). | owner + WP2 |
| **Idle battery cost.** | technical | `MoteField` and `StreakFlame` never pause; RealityKit renders every frame while the stage is at rest. | WP8, WP9 |

### 2c. Single-juror items I still rank as major (verified)
- **The audio engine doesn't survive AirPods or a call.**
  - There is no `AVAudioEngineConfigurationChange` observer in `AudioService`.
  - `.ended` is ignored (`AudioService.swift:71-77`).
  - Owner: WP1.
- **"Every string rings" ticks strings it never heard** (`LessonSteps.swift:772`). Owner: WP4.
- **Guitar has 6 preset tunings, against 26 in Fender Tune** (`catalog.json`). Owner: WP5.
- **Ukulele shows 12 songs.** Every song collection is `guitar.acoustic.6`. Owner: WP5.
- **The paywall is reached before any lesson moment.** There is no "learn songs" goal (`OnboardingView.swift:275-293`). Owner: WP2.
- **Shares carry dead `timbre://` links**, and `appStoreLink = nil` (`GameCenter.swift:18`). Owner: WP2.
- **Layout collisions with the dock.** On 05b the goal card runs under "Start my plan"; 21 and 41 show the same. Owners: WP2 and WP5.

---

## 3. Roadmap to #1: ten file-disjoint work packages

### Rules for all teams
1. **One owner per file.** Each package owns the files listed for it. A file not listed anywhere defaults to **WP10**.
2. **Shared resources:**
   - **New user settings.** `UserSettings` fields are added only by WP1, in one day-1 commit. The fields are `languageChosen`, `handedness` (an enum `right`/`left`/`leftUpsideDown`), `simpleTuner`, `calmMode`, `tuneByFeel`, `feelTheBeat`, `bandOnSpeaker`, `chartsAsPrinted`, `firstChordDone`, and a lenient decoder. Other packages read them.
   - **Strings.** New strings go in code with English defaults. No package hand-edits `.lproj` files; WP10's pipeline extracts them. The one exception is the generated English `Learn.strings`, which travels with `curriculum.json` (WP5).
   - **Info.plist keys** (`TimbreTelemetryAppID`, the privacy URL, fonts) go through `project.yml`, which WP10 owns. Packages request them.
3. **Day-1 handoffs:**
   - WP4 moves `SparkBurst` verbatim from `LessonPlayer.swift:587-608` into `Timbre/Design/SparkBurst.swift`, which WP7 then owns.
   - WP4 adds `ChordSpec.capo: Int?` and `LessonVisual.clip(name:)` to `Curriculum.swift`.
   - WP6 freezes the HUD digits under `DemoScene.stillScore`.
   - WP1 exposes `CurriculumStore.shared` and a per-frame reading hook in `AppStore`.
4. **The only cross-ownership edit allowed** is WP10's mechanical final sweep (comments and test hooks), run after WP1–WP9 merge, with the file owners pre-approving.
5. **Every package strips "review N / bug N / store frame" comments from the files it touches**, and WP10's lint blocks new ones from day 1.

Packages are ordered by impact on:
- (a) an ordinary user choosing Timbre;
- (b) revenue toward $10k a month;
- (c) ADA-level craft.

| Rank | Package | Size | Why it ranks here |
|---|---|---|---|
| 1 | WP1 Trust foundation and core hardening | L | (a) Every non-English user gets their language, and every user gets the haptics. (b) Payers keep Pro in grace, and no update locks anyone out. Due-diligence blockers B1, B2, B3 and B9. |
| 2 | WP2 Funnel: first session, paywall and measurement | L | (b) Measurement is the prerequisite for every price and paywall test (B5). (a) The lesson magic comes before the paywall. |
| 3 | WP3 Store creative and listing | M | (a) The App Preview replaces screenshot #1 in search, so it is the moment people choose. B6, B7 and B11. |
| 4 | WP4 Listening that tells the truth | M–L | (a) A reviewer finds timing-only grading in five minutes (B4). Naming the dead string is a category first. |
| 5 | WP5 Catalogue, content and free tier | M–L | (a)(b) "Best free tuner" and about 100 ukulele songs bring the installs and the ratings. |
| 6 | WP6 Play-along, band and an accessible highway | L | (a)(c) The band as the reward; VoiceOver can play along (B8). |
| 7 | WP7 Tuner feel, rewards and sound identity | L | (c) The ADA signature ("feel it stand still"). (a) Rewards that aren't templates. |
| 8 | WP8 Design system and app shell | L | (c) Removes the "template / AI" tells on 12+ screens. |
| 9 | WP9 Necks, hands and the 3D stage | L | (a) For about 10 % of players (left-handed), plus "Show me" craft. |
| 10 | WP10 Vibe-coded cleanup and engineering hygiene | M | The acquirer's and the owner's "nothing vibe-coded" bar. The lint gate lands on day 1 and the sweep runs last. |

---

### WP1: Trust foundation and core hardening (**L**; run as two sub-teams, data/l10n/entitlements and audio/core)
**Goal.** Fix these so an acquirer finds nothing:
- No update can lock anyone out.
- Every user sees their own language.
- Payers never lose Pro wrongly.
- The tuner's feel reaches the hand.
- Audio survives AirPods and phone calls.

**Items**
1. **Language (B1).**
   - Default `language = "system"` (`LocalStore.swift:10`).
   - Migrate a stored `"en"` the user never chose to `"system"`, using the `languageChosen` flag (WP8 sets it at `SettingsView.swift:374`).
   - Use one resolver with a cached bundle (`Catalog.swift:21-26`, `Localization.swift:5-7`), so the 271 bare `String(localized:)` calls and `TimbreLocalization` agree.
   - Optionally adopt iOS per-app language.
   - Add a new `TimbreUITests/LocalizationLaunchUITests.swift` with `(de)` and `(ar)` launches.
2. **Crash-proof persistence (B2).**
   - On a decode failure, move the file to `timbre-state.corrupt-<date>.json`, then load `timbre-state.bak.json` (written before each persist), else start fresh and tell the user (`LocalStore.swift:195-201`).
   - Give `UserSettings` a lenient `init(from:)`.
   - Validate on write and repair on load (`:314-342`); accept `version <= current`.
   - Add golden fixtures (`Tests/Fixtures/state-v1-2026-10.json`).
   - Replace the dead-end Retry with recovery (`TimbreApp.swift:15-22`).
   - Invert the fail-closed assertion (`PersistenceTests.swift:46`).
3. **Entitlements (B9).**
   - Trust `currentEntitlements`, keeping only the revocation check (`Access.swift:26-31`).
   - Read `Product.SubscriptionInfo.status` for `.inGracePeriod` and `.inBillingRetryPeriod` (`CommerceService.swift:161-167`) and show a new `Timbre/Paywall/BillingIssueBanner.swift` that opens `manageSubscriptionsSheet`. WP8 mounts it.
   - Add SKTestSession tests for grace, retry, Ask to Buy (pending), win-back and offer codes (`CommerceIntegrationTests.swift`).
   - Log `purchase_cancelled` and `purchase_failed` to WP2's schema.
4. **Free-tuning policy** (owner sign-off): `canUse(tuning:)` makes every instrument's standard tuning free; alternates and custom tunings stay Pro (`Access.swift:35-41`).
5. **Haptics (B3).**
   - Add `try session.setAllowHapticsAndSystemSoundsDuringRecording(true)` after `setCategory` (`AudioService.swift:245`).
   - Gate `detent` while |cents| > 3 if a device test shows vibration bleeding into the microphone.
6. **Audio resilience.**
   - Observe `.AVAudioEngineConfigurationChange` in `AudioService`, snapshotting metronome, drone and band *before* stopping (`:256`, `:728`).
   - Resume on `.ended` with `.shouldResume` (`:71-77`).
   - Call `setActive(false)` off the main thread (`:240`).
   - Make one session owner shared with `RecordingPlayer.swift:45-53`.
7. **AppStore hooks for other teams.**
   - One `CurriculumStore`, decoded off the main thread before the first frame (`AppStore.swift:92`; `SpotlightIndex.swift:74`). WP6 adopts it at `BandGroove.swift:113`.
   - A cached `StreakSummary` (`:251`).
   - Move the side effect out of the `dailySet` getter (`:857-866`).
   - Remove `paywall_shown` (`:472`).
   - Log `pro_active` only on change.
   - A per-frame reading hook for WP7's haptic beating, replacing the detent and lock calls at `:609` and `:618`.

**Acceptance (what a juror checks)**
- A fresh install on a German device shows German onboarding, tabs and lessons; Arabic is right-to-left. The de and ar CI launches are green.
- A corrupted state file means the app opens with the streak restored from `.bak` and a quarantine file present. The golden v1 fixture decodes, and a new non-optional field doesn't break it.
- With billing grace enabled in the test, `isPro` stays true; during billing retry the banner shows.
- On an iPhone 15–17 with the tuner listening, the detent and lock are felt and there are no false readings. This is the owner's device check.
- Plugging AirPods in mid play-along keeps the click and band going; the drone resumes after a phone call.
- The curriculum is decoded once (one resident copy).

**Files owned**
- `Sources/TimbreCore/Persistence/LocalStore.swift`
- `Sources/TimbreCore/Commerce/Access.swift`
- `Sources/TimbreCore/Catalog/Catalog.swift`
- `Sources/TimbreCore/Practice/Streaks.swift`
- `Timbre/Services/{AppStore, CommerceService, Localization, LiveReading}.swift`
- `Timbre/Audio/AudioService.swift`
- `Timbre/YourSongs/RecordingPlayer.swift`
- `Timbre/Intents/SpotlightIndex.swift`
- `Timbre/TimbreApp.swift`
- `Timbre/Paywall/BillingIssueBanner.swift` (new)
- `Tests/TimbreCoreTests/{PersistenceTests, AccessPolicyTests}.swift`
- `Tests/Fixtures/Timbre.storekit` and the new state fixtures
- `TimbreAppTests/*`
- `TimbreUITests/LocalizationLaunchUITests.swift` (new)

**Dependencies**
- WP8 mounts the banner and sets `languageChosen`.
- WP6 adopts `CurriculumStore` in `BandGroove`.
- WP10 moves the `TimbreApp` DEBUG hooks after merge.

---

### WP2: Funnel: first session, paywall and measurement (**L**)
**Goal.** Sell lessons the player has already felt, measure every step, and package for $10k.

**Items**
1. **Measurement (B5).**
   - Read the ID from Info.plist (owner key).
   - Wrap `flush` in `beginBackgroundTask` (`Analytics.swift:85-95`), honour `telemetryEnabled`, and log `app_open` on `didBecomeActive`.
   - New events:
     - `onboarding_step{step}`, `mic_permission{granted}`;
     - `paywall_view{reason,variant}` in `PaywallView.onAppear`, which covers the onboarding `fullScreenCover` (`OnboardingView.swift:60-63`);
     - `paywall_close{reason}` in `decline()`;
     - `purchase{trial,price,currency}` (`PaywallView.swift:90`, `:1360`).
   - Send the AdServices token once.
   - Add `MXMetricManager`.
   - Add a new `Timbre/Services/RemoteConfig.swift`: the paywall variant, the annual product ID and a social-proof switch, from JSON on the owner's domain.
2. **Lessons before the paywall.**
   - Add the goal "Play my first songs" first, and make it the default for "Just starting" and "A few months" (`OnboardingView.swift:275-293`).
   - For beginners, add a 30 s "Your first chord" step after the first tune: Em on guitar, C on ukulele, open strings on violin. It reuses WP4's chord step: every string lights, then "You just played your first chord".
   - Retitle the welcome screen "Tune in seconds. Then learn to play." (`:133-136`).
   - Add a handedness question (Right / Left / Left, strung upside-down).
   - After the first-tune reward, ask for the reminder on a full card.
   - Replace "Great work" with the fact ("Low E, dead on.") (`FirstTuneStep.swift:182`, `:202`).
   - Feed `TunerAnnouncer` in `FirstTuneStep` (`:378`).
3. **Onboarding craft.**
   - Remove the orbs from the answers (WP8's spec).
   - Drop the ▶▶ bullet (`:506`) and the crown (`:276`).
   - Make the dock reserve its height with `safeAreaInset` (`:396`, `:474`; 05b).
   - Make "I already have Timbre Pro" a bordered button (`:153`).
   - Centre the answer stacks (03, 04).
4. **Paywall.**
   - On onboarding, show two plans and no lifetime (`PaywallView.swift:789-792`).
   - Headline "Play your first song this week" (`:309`).
   - Proof line from distinct titles, "120+ songs" (`:481-487`).
   - Add a "Your songs" outcome, and give all outcomes one tint (`PaywallPlan.swift:347-468`).
   - Space the timeline proportionally (`:1083`).
   - Put the strike price beside the price.
   - Put the close button on a solid 44 pt disc.
   - Add a remote-switched rating line, shown only at ≥ 4.6★ from ≥ 200 ratings.
   - The trial-end reminder names the value used (`:1656-1657`).
   - Read the privacy URL from Info.plist (`:1386`).
   - Add a Family Sharing line if the owner enables it.
5. **Acquisition and virality.**
   - `tune?instrument=` deep links that onboarding reads, to back Custom Product Pages (`DeepLink.swift:65-71`).
   - Set `appStoreLink` (`GameCenter.swift:18`).
   - A `ShareDestination` https helper used by every `ShareLink`. WP7 applies it in `LessonResults` and `Celebration`; WP2 applies it in `WeekRecap.swift:145`.
   - "Give a friend a month" with one-time offer codes.
6. **Privacy.** Align `docs/ios/PRIVACY.md` and `PrivacyInfo.xcprivacy`: analytics not linked to identity, Game Center, reminders.

**Acceptance**
- A test ID shows the funnel from `app_open` through the onboarding steps, `paywall_view(onboarding)`, trial start and conversion, with each paywall counted once.
- "Just starting" → first chord heard → plan → paywall takes under 90 s. No orbs and no dock overlap at 6.1" and at AX3.
- The onboarding paywall has 2 plans; the proof count equals the distinct titles; the timeline is linear.
- Every share opens the App Store for a non-user.
- A remote JSON flip changes the paywall variant without a build.

**Files owned**
- `Timbre/Onboarding/*`
- `Timbre/Paywall/*` except `BillingIssueBanner.swift`
- `Timbre/Services/{Analytics, GameCenter, GameCenterSocial, PracticeReminder, RemoteConfig(new)}.swift`
- `Timbre/Intents/DeepLink.swift`
- `Timbre/Journey/WeekRecap.swift`
- `Timbre/Resources/PrivacyInfo.xcprivacy`
- `docs/ios/PRIVACY.md`

**Dependencies**
- WP1: AppStore event removal, settings fields, commerce logs.
- WP4: public chord step.
- WP8: icon and button spec.
- WP10: Info.plist keys.

---

### WP3: Store creative and listing (**M**; start now, final captures after WP6, WP7 and WP9)
**Goal.** The ad is as good as the product.

**Items**
1. **App Preview** (B6; `preview.py:49`, `:502`, `:509`, `:520-526`, `:638`; `AppPreviewUITests.swift:84-255`):
   - **Sound.** A mix of the app's own audio: lock bells, the tuned strum, the *Kite Weather* band.
   - **Cuts.** Hard cuts on the beat, and a poster clamped away from any fade.
   - **The lock.** Held 1.5 s after the lock sync.
   - **Strings selected by the demo pitch,** so AUTO stays AUTO.
   - **Order:** Show me in 3D, *Kite Weather* at ×4, results, Songs for ≤ 3 s, then an end card.
   - **Captions** throughout.
   - **Length** 20–25 s, plus a second, violin-first preview for the violin page.
2. **Screenshots** (`screenshots.py:121-209`):
   - A background tint per feature; crop and enlarge the hero region; drop the "TIMBRE" eyebrow; supporting line at ≥ 52 px.
   - **#1:** "Free tuner. No ads.", with the headstock breaking the frame and captured mid-comet (WP9 `marketingScale`).
   - **#3:** the first chord lit (52b), or Show me mid-animation.
   - **#4:** the instrument wall.
   - One light frame.
   - A `--locale` option for de, fr, es, ja and more.
3. **Probes.**
   - Assert there is no mid-transition `numericText` (two captures 120 ms apart).
   - iPad #2 is a valid capture (`TabletScreenshotsUITests.swift:110`), in full-screen mode.
4. **Listing.**
   - Open with "Free tuner, no ads, no account. Then lessons that listen as you play."
   - "120+ songs", not 159.
   - Bullets for Your songs, Apple Music, Watch and Game Center.
   - Keywords per growth §13.
   - Regenerate the 9 localized blocks from variables (38 stale counts).
   - In the ASC playbook (`APPLE-DELIVERY.md`):
     - 9–12 Custom Product Pages by instrument, with keywords and WP2 deep links;
     - In-App Events (December carols, a 30-day ukulele challenge);
     - Product Page Optimization tests;
     - grace period, Family Sharing, a featuring nomination;
     - the accessibility-label plan.
5. **DemoScenes** for the new frames (Show me mid-run, the instrument wall, the first chord, the violin stage).

**Acceptance**
- The preview is audible (mean > −30 dB). The poster is clean, shows "✓ In tune" and the peg check, never shows MANUAL, and Songs runs ≤ 3 s.
- The 9 frames are distinguishable at thumbnail size, with no ghosted glyphs.
- iPad #1–#4 come from passing captures.
- `screenshots.py --check` passes for all 10 listing locales.

**Files owned**
- `tools/marketing/*`
- `TimbreUITests/{AppPreviewUITests, TabletScreenshotsUITests, StillScreen, TimbreUITests}.swift`
- `Timbre/Root/DemoScenes.swift`
- `docs/ios/{APP-STORE-LISTING, APP-STORE-LISTING-LOCALIZED, APPLE-DELIVERY}.md`
- `.github/workflows/preview.yml`

---

### WP4: Listening that tells the truth (**M–L**)
**Goal.** Every graded step hears what it claims to hear, and blind or hands-busy learners can follow a lesson.

**Items**
1. **Chord plus timing judge (B4).**
   - `RhythmStep.start()` (`LessonSteps.swift:1509`) uses `LessonAnalyzer(chords: true, target: chordAt(beat))`, retargeted each bar. Add `retarget(_:)` to `LessonAnalyzer.swift`.
   - In `register` (`:1520-1530`), confirm `matches(target)` within 60–250 ms after the onset.
   - Wrong chord: cap the stroke at `.ok` and paint an amber "Am?" chip (`LessonBeatRow.swift`).
   - No chord at all: `.miss`.
   - Feed `CoachTake.strummed` (`Sources/TimbreCore/Coach/CoachNotes.swift`).
2. **Name the dead string.**
   - Replace "3 chroma frames ⇒ all strings verified" (`LessonSteps.swift:768-776`) with a `PolyTuner` pass on the first strum.
   - Leave unheard strings unticked: "String 3 isn't ringing: arch finger 2". No competitor does this.
3. **Banjo D7.** Accept a superset target with the same bass root (`ChordRecognizer.swift:241-249`).
4. **Lesson accessibility and hands-free.**
   - `@AccessibilityFocusState` on the step title, plus `.screenChanged` on `run.index` change (`LessonPlayer.swift:476-492`).
   - `TunerAnnouncer` in `TuneCheckStep` (`LessonSteps.swift:1734-1760`).
   - `.keyboardShortcut` on `StepButton` (`LessonPlayer.swift:495`): space, → and ←, for page-turner pedals.
   - "Start on first strum".
   - "Again / Next / Slower" App Intents (`Intents/PracticeIntents.swift`, `TimbreShortcuts.swift`).
   - Mirror the strum stage from the handedness environment.
5. **Consistency.**
   - Sequence the captions, out then in (`LessonExplain.swift:594-600`).
   - The tune check runs low→high, left→right.
6. **Schema (day 1).** `ChordSpec.capo` and `LessonVisual.clip(name:)` in `Curriculum.swift`; hand `SparkBurst` to WP7.
7. **Real-audio harness.**
   - `Tests/Fixtures/RealWorld/` plus an expected JSON, and `RealWorldAccuracyTests`.
   - Budgets: ≤ 0.5 ¢ median, ≤ 250 ms to lock, all six strings within 2 ¢ in 0.85 s from one strum, and a chord-recognition precision floor.
   - It skips until the owner's recordings land.

**Acceptance**
- Through C–Am–F–G, open strings, a wrong chord or body taps score at most "OK" (one star). Synthesized wrong-chord tests are green.
- Em with string 4 muted says "String 4 isn't ringing"; a clean Em ticks all six.
- Banjo x0210 is accepted.
- With VoiceOver, focus lands on each new step title, and the tune check says "tighten" or "loosen".
- A hardware keyboard or pedal drives Start, Continue and Again.

**Files owned**
- `Timbre/Learn/{LessonSteps, LessonAnalyzer, LessonPlayer, LessonExplain, LessonBeatRow, LessonInspector, LessonMotion, LatencyCalibration, WeakSpotReview}.swift`
- `Sources/TimbreCore/DSP/*`
- `Sources/TimbreCore/Learn/{Curriculum, LessonEngine, Placement}.swift`
- `Sources/TimbreCore/Coach/*`
- `Timbre/Intents/{PracticeIntents, TimbreShortcuts}.swift`
- `Tests/TimbreCoreTests/{ChordRecognizer, PolyTuner, DSP, OnsetDetector, Learn, CoachNotes, CoachTiming}Tests.swift`, `SynthesizedSignals.swift`
- `Tests/Fixtures/RealWorld/` (new)

---

### WP5: Catalogue, content and free tier (**M–L**)
**Goal.** Win "best free tuner" outright and give every instrument a real songbook.

**Items**
1. **Free tier** (owner sign-off on the table):
   - free: the open-position chord library with Check (`ChordsView`; the gate at `PracticeView.swift:571-577`), eighth and triplet subdivisions (`MetronomeView.swift:286`), the Wood voice (`:324`), one custom tuning (`InstrumentsView.swift:300`), and 10 "Your songs" charts instead of 3 (`ChartPlayback.swift:258`);
   - capo and transpose: WP8 removes the gates at `SettingsView.swift:150` and `:162` per this table.
2. **Tunings.**
   - Guitar from 6 to 22+ presets: D, C and B standard; Drop C♯, C and B; double drop D; open C, E, A and Em; C6; CGCGCE; Nashville; lute G.
   - Bass: Drop C, BEAD and 6-string (`catalog.json:104-110`).
   - Extend `CatalogTests`.
3. **Content** (`tools/curriculum`, regenerate `curriculum.json`):
   - A ukulele songbook course: transpose to C, G, F or Am, use the uke shapes, and re-fret the melody for re-entrant tuning (`songbook.py`). About 100 songs, against 12 today.
   - A mandolin fiddle-tune book.
   - About 20 public-domain songs people actually request, per `PUBLIC-DOMAIN-CLEARANCE.md`.
   - Emit `ChordSpec.capo` for gtr-16-*.
   - An optional 4-finger banjo D7.
   - A free-runway flag for Unit 2 (A/B through remote config).
   - Placeholder hooks for technique clips.
4. **Practice-tool craft.**
   - Real ♩ ♫ ³ ♬ glyphs from `NotationGlyph` (`MetronomeView.swift:287`).
   - Meter and subdivision in one strip.
   - Docks reserve space (`MetronomeView.swift:29-56`, `DroneView.swift:51-53`).
   - Metronome voices from the shipped drum set.
   - A phone haptic "Feel the beat" (`:137-170`).
   - Fix the Swift 6 isolation warnings in `DroneSingAlong.swift:33-44`.
5. **Bullseye.**
   - Sound on bullseye, near and miss, and a target drone (`PitchSniperView.swift:200-216`).
   - Resonance rings instead of the scope (`:229-278`).
   - "Nice ear" (`:145`), and fix the doc comment (`:5`).
   - Hidden-melody rounds (`PitchSniper.swift`).
6. **Ear training and the Play hub.**
   - An unpitched reward call (`EarTrainingView.swift:492`).
   - Spoken notes (`:697`).
   - "Skip ear steps" or notation on Listen steps.
   - Intervals in words.
   - XP shown once per card; Calm mode hides XP pills; label the Bullseye affordance.
7. **Instrument picker.** Tunings move to the tuner's menu, and a corner lock glyph replaces the PRO pills (12, 30, iPad).

**Acceptance**
- A free user can use open chords with Check, capo, eighths and triplets, one custom tuning, and the standard tuning of all 60 instruments.
- Guitar has ≥ 22 presets.
- Songs › Ukulele shows ≥ 90 songs with uke shapes; Mandolin ≥ 20.
- Bullseye rings its note, and no "shooting" wording remains.

**Files owned**
- `Timbre/Practice/*` except `ScalesView` and `IntonationView`
- `Timbre/Instruments/*`
- `Sources/TimbreCore/Practice/{Chords, EarTraining, PitchSniper}.swift`
- `Sources/TimbreCore/YourSongs/ChartPlayback.swift`
- `Sources/TimbreCore/Resources/{catalog.json, curriculum.json}` and the generated English `Learn.strings`
- `tools/curriculum/*`
- `docs/content/*`
- `Tests/TimbreCoreTests/{Catalog, ChordLibrary, Practice, CurriculumIndex}Tests.swift`

---

### WP6: Play-along, band, and a highway everyone can play (**L**)
**Goal.** The reward for learning a song sounds like a band, and a blind player can do the play-along.

**Items**
1. **Day 1 (B7).** In `HighwayHUD.swift:37` and `:67`, use `DemoScene.stillScore ? .identity : .numericText(…)`.
2. **Chord-aware band.**
   - `SongPerform.swift:83-86` builds its band from the chart's chords through `SongPlayback.band` (`SongSheet.swift:1113-1128`). `AlongStep` (`Highway.swift`) does the same when a chart exists.
   - `.melody` (`Band.swift:46-55`) remains only as the fallback.
3. **VoiceOver play-along (B8).** Replace the single element (`Highway.swift:145-146`) with "Spoken cues", on by default under VoiceOver:
   - an announcement one beat ahead, at high priority;
   - earcons for hit and miss, and a haptic count-in;
   - the result spoken at the end;
   - the band ducked.
4. **Contrast and colour.**
   - The zero tally uses `inkFaint` instead of 0.45 opacity (`:2032`).
   - The lane palette moves off the status hues (`:1149`); string 4 becomes lime.
   - Under Differentiate Without Colour, alternate lanes are dashed.
   - Lanes are mirrored from the handedness environment.
5. **Game feel.**
   - A choke cue on a combo break (headphones only) and a crash at ×4.
   - A section ribbon ("Chorus 96 %") on the finale (`HighwayTimingStrip.swift`).
   - The share card says the fact, not "Great work" (`Highway.swift:402`, `:471-472`).
6. **Hands-free.** Keyboard shortcuts on Start, Again and Next; start on the first strum.
7. **Structure.**
   - Extract `PlayAlongSession` into TimbreCore (new file), removing the 28 duplicated windows between `Highway` and `SongPerform`.
   - Adopt WP1's `CurriculumStore` at `BandGroove.swift:113`.
8. **Phase 2.**
   - A "Chords & words" song mode with WP4's chord judge.
   - "Band on speaker", using voice processing for **lessons only**, behind a 10 s self-test and off by default.
   - A reactive band that thins on misses and adds a fill at ×4.
   - "This week's song" with a leaderboard.

**Acceptance**
- In a recaptured store #2, the combo and ×4 are crisp in two captures 120 ms apart.
- *Kite Weather* in headphones: the bass follows G–D–Em–C.
- With VoiceOver and eyes closed, a user finishes "Open-string roll call"; the accessibility audit on 59 and 60 passes.
- Zero counts are at least 4.5:1; ×4 crashes; the finale shows section percentages.

**Files owned**
- `Timbre/Learn/{Highway, HighwayHUD, HighwayLyrics, HighwayPop, HighwayTimingStrip, SongPerform, SongOpener, SongSheet, NotationEngraver, NotationGlyphs, NotationView}.swift`
- `Timbre/Audio/Band.swift`
- `Sources/TimbreCore/Audio/BandGroove.swift`
- `Sources/TimbreCore/Learn/PlayAlongSession.swift` (new)
- `Tests/TimbreCoreTests/BandGrooveTests.swift`

---

### WP7: Tuner feel, rewards and sound identity (**L**)
**Goal.** Make the signature thing, a string that stands still, something you hear, feel and are rewarded with. Retire every template reward.

**Items**
1. **"Tune by feel".**
   - In `Haptics.swift`, a continuous CHHaptic event pulsing at the beat frequency |f·(2^(c/1200)−1)|, mapped to 0.5–8 Hz. It goes still on lock, then one thump.
   - Driven from WP1's reading hook.
   - A Settings toggle and a "Feel test" diagnostics row; WP8 draws the rows.
2. **Tuner accessibility.**
   - Add a localized `NoteNames.spoken` ("E flat 3", "Es 3", "Fa dièse 3") and use it at `TunerVoiceOver.swift:47`, `Readout.swift:310` and `StringRail.swift:236-238`.
   - Add "tighten / loosen" to the announcer (`TunerVoiceOver.swift:42`).
   - `accessibilityInputLabels` on the string chips.
   - Raise the caps to `.accessibility1` and add the Large Content Viewer (`TunerControls.swift:19`, `TuneView.swift:529`).
   - Resting chip ring at `controlLine` (`StringRail.swift:214`).
   - Pin the string rail left-to-right.
   - `accessibilityIgnoresInvertColors` on the stage containers.
3. **Tuner visual.**
   - Keep the halo inside the gutter (`TuneView.swift:580-587`).
   - Hide the linear meter when the strobe is showing (`ChromaticStage.swift`; 15).
   - Crossfade instead of slicing the bloom (`StringRail.swift:198-205`; 19).
   - A "Simple tuner" mode that hides the quest line, XP and header chips.
   - "Thickest ↔ Thinnest" captions.
4. **Full-tune finale.**
   - The camera pulls back first (`showWhole`, `TuneView.swift:98`), the strings light low→high with their bells, and only then does the card rise (`Celebration.swift:18-26`, `:100`).
5. **Sound identity.**
   - `.tuned` becomes `tuned(frequencies:)`, strumming the targets just tuned (`SoundFX.swift:194-207`).
   - Stars ring 1-3-5 in the lesson's key (`LessonResults.swift:613`, `SongStoryCard.swift:261`).
   - An XP tick (`LessonResults.swift:625-629`).
   - Its own streak cue (`StreakCelebration.swift:150`).
   - A three-note motif, from the owner's sound designer, for welcome, Pro unlock and level-up.
   - An unpitched ear-training reward cue (`SoundFX.swift:142-148`).
6. **Rewards.**
   - A custom star shape instead of `star.fill`, labelled "n of 3 stars" for VoiceOver; under Reduce Motion, a fade with no scale or rotation (`LessonResults.swift:588-602`).
   - A "harmonic" burst in `SparkBurst.swift`.
   - The streak shown as a stage lamp or a setlist instead of the flame row (`StreakCelebration.swift:54-164`).
   - Headlines lead with the fact (`LessonResults.swift:66-73`, `SongStoryCard.swift:71-75`).
   - Sentence case for "High Scorer" and "Round Winner" (`Progression.swift:322`, `:345`).
   - A medal asset pipeline (`Progression.swift:317-358`), ready for art.
   - A `LockShimmer` duration parameter for marketing captures (`Shaders.swift:59`).

**Acceptance**
- On a device: the pulses slow toward pitch, go still at the lock, then one thump.
- VoiceOver on E♭ standard says "E flat 3, 12 cents flat, tighten".
- Tuning to E standard ends on an E-standard strum; GCEA ukulele ends on GCEA.
- `grep "Great work"` finds nothing, and there is no `star.fill` on results or the finale.
- Reduce Motion stars only fade.

**Files owned**
- `Timbre/Tune/*`
- `Timbre/Audio/SoundFX.swift`
- `Timbre/Design/{Haptics, Shaders, SparkBurst(new)}.swift`, `Shaders.metal`
- `Timbre/Learn/{LessonResults, SongStoryCard}.swift`
- `Timbre/Journey/StreakCelebration.swift`
- `Sources/TimbreCore/Catalog/NoteNames.swift`
- `Sources/TimbreCore/Practice/Progression.swift`
- `Tests/TimbreCoreTests/{NoteNames, Progression}Tests.swift`

---

### WP8: Design system and app shell, "nothing templated" (**L**)
**Goal.** Remove the component-library dialect: one token system, one icon language, one colour grammar.

**Items**
1. **Tokens** (`Theme.swift`):
   - An 8-step type scale (12/13/15/17/20/28/40/64, plus the hero numeral), enforced by a CI lint from WP10.
   - Bold Text through `legibilityWeight` in `Typeface` (`:143-185`), bundling Sora-Bold.
   - `controlLine = 0x5A606A` (`:22`; about 3:1).
   - Status colours exclusive: mint, amber, coral.
   - Course accents never on a primary CTA.
   - "Glow = live" for button styles.
   - An eyebrow budget: section level only, ≤ 1 per card.
2. **Kill `IconOrb`** (`Components.swift:337-349`).
   - Settings rows use plain glyphs (`SettingsView.swift:132-279`), with a custom capo glyph (`:153`) and temperament glyph (`:132`).
   - Remove it from Journey and Learn.
   - Publish the replacement spec for WP2 and WP5.
   - Use the owner's icon family when it lands.
3. **Tab bar.** Five custom SF Symbol templates with matched weight and fill variants; rename "Play" to "Practice" (`RootView.swift:24-30`); mount the billing banner.
4. **Songs.**
   - The hero Play is mint (`SongsView.swift:853-866`).
   - The "Your songs" shelf moves above the fold.
   - Vary the sleeve eyebrow and number placement (`SongCover.swift:7-9`, `:89-90`), add per-genre faces when licensed, and give "Your songs" its own icon.
5. **Chrome.**
   - One streak chip and one level glyph (`GameUI.swift:11-21`).
   - Pause `StreakFlame` (`:92`) and `MoteField` (`Components.swift:20-38`) when off screen or in Low Power Mode.
6. **iPad.**
   - A horizontal stats bar (Journey).
   - A horizontal unit path, a course rail with whole cards, and a centred Preview card (Learn).
7. **Settings rows** for the new flags: Simple tuner, Calm mode, Tune by feel, Feel the beat, the Feel test, Handedness (3 options), Language (`languageChosen`), Charts as printed. Capo and transpose ungated per WP5. Privacy URL from Info.plist (`:395`).
8. **Copy.** One placeholder ("Not yet") (`JourneyView.swift:393`); sentence case everywhere.

**Acceptance**
- 0 `IconOrb(` in the code. Lint passes on type sizes. ≤ 2 selector rows above content on every screen. Every primary CTA is mint.
- Bold Text bolds Sora. Chip edges are ≥ 3:1 without Increase Contrast.
- The tab icons are optically matched (designer sign-off).
- The iPad Progress and Learn frames have no dead zones.

**Files owned**
- `Timbre/Design/{Theme, Components, Kit, GameUI, Glass, EdgeFade}.swift`
- `Timbre/Root/RootView.swift`
- `Timbre/Settings/SettingsView.swift`
- `Timbre/Songs/*`
- `Timbre/Learn/{LearnView, CourseArt}.swift`
- `Timbre/Journey/{JourneyView, CoachCard, CoachVoice}.swift`
- `Timbre/YourSongs/*` except `RecordingPlayer.swift`
- `Timbre/Tips/TimbreTips.swift`
- `Timbre/Resources/{Assets.xcassets, Fonts}`

---

### WP9: Necks, hands and the 3D stage, left-handed everywhere (**L**)
**Goal.** Every neck is true to the player's hand and capo, "Show me" reads as a teacher, and the stage is cheap at rest.

**Items**
1. **Left-handed.**
   - An `isMirrored` environment value.
   - `StringOrder.left` and `.leftUpsideDown` (`Diagrams.swift:51-82`).
   - Mirror `ChordDiagram` (with a "Charts as printed" option), `PlayerNeck` (`PlayerNeck.swift:19-21`), the Scales and Intonation necks and the studio and photo cards.
   - In 3D, set the model root's `scale.x = -1` with culling fixed, flip the peg `tighten` sign (`PegCue.swift:9-19`), and mirror the Show me model.
   - Keep text unmirrored.
2. **Capo.** A capo bar, finger numbers relative to it, and the caption "G shape · capo 2" (`Diagrams.swift:565`; gtr-16-*).
3. **Barre.** End it at the outer string plus the dot radius, and drop the gloss (06b, 43).
4. **Show me.**
   - One continuous emissive tube per string (`ShowMeScene.swift:505-513`).
   - Soft fingertip pads without the gloss band (`ShowMe.swift:716-725`).
   - The lesson accent for every mark; the per-string rainbow stays on the highway only.
   - "Again" while it plays (`ShowMe.swift:473`).
   - Sequenced captions (`:57-59`).
   - Hooks for the hand rig, posed from `ShowMeShape.presses`, and for ukulele and banjo usdz (`:11-12`).
5. **Stage performance.**
   - A rest mode (studio still or 30 fps) and a 2D stage in Low Power Mode (InstrumentStage; TuneView passes `resting`).
   - Every usdz load goes through `ModelCache` (`InstrumentStage.swift:152`, `:673-678`).
   - Deduplicate the IBL code (`:268` and `ShowMeScene.swift:448`).
   - `accessibilityIgnoresInvertColors` on the stages.
6. **Framing.**
   - Normalise each rig's camera so the headstock spans 55–60 % of the stage (14 and 17 against 10 and 49).
   - A `marketingScale` input (3× amplitude) for DemoScenes.
   - Re-crop the lute with headroom, and normalise card scale per family (violin and cello against viola).
7. **Scales and Intonation.**
   - Position and labels move into a "View" menu, with ≤ 2 selector rows and edge fades (44).
   - Intonation runs low→high (`IntonationView.swift:32`).
   - One placeholder character (`:171`, `:191`).

**Acceptance**
- With Left chosen, the chord box, Player view, the scales and intonation necks, the 3D headstock, the peg arrows and Show me are all mirrored, with text readable. A left-handed tester signs off.
- The capo lessons draw a capo.
- A recaptured 51b has no beaded blobs.
- At rest, GPU frames drop (Instruments); in Low Power Mode, the 2D stage shows.
- Heads are the same size across 10, 14, 17, 49, 49b and 49c.

**Files owned**
- `Timbre/Learn/{Diagrams, PlayerNeck, ShowMe, ShowMeScene}.swift`
- `Timbre/Stage/*`
- `Timbre/Practice/{ScalesView, IntonationView}.swift`
- `Timbre/Resources/Models/*` (rigs, usdz, card renders)
- `tools/models/*`
- `.github/workflows/{cards, assets}.yml`
- `Tests/TimbreCoreTests/ShowMeMemoryTests.swift`

---

### WP10: Vibe-coded cleanup and engineering hygiene (**M**; gate on day 1, sweep last)
**Goal.** An acquirer's engineer reads it as a senior team's codebase.

**Items**
1. **Day-1 gate.**
   - `.swiftlint.yml` and `.swiftformat`.
   - A CI rule that fails on `review \d+ | bug \d+ | store frame | WIP` in comments, `IconOrb(` (once WP8 lands) and off-scale `Typeface` sizes.
   - `SWIFT_TREAT_WARNINGS_AS_ERRORS` once the 13 warnings are fixed.
2. **Repository.**
   - Delete `findings.md` (a personal Windows path and auth notes), `progress.md` and `task_plan.md`.
   - Rewrite the README.
   - Add `CONTRIBUTING.md`, a PR template and `docs/adr/`.
   - Squash-merge only; no `[skip ci]` on main (50 such commits today).
3. **Test hooks.**
   - One DEBUG-only `Timbre/Support/TestSupport.swift` replaces the environment reads in about 20 production files. `Analytics.swift:34` reads `TIMBRE_DEMO_PITCH` outside DEBUG.
   - This is the final sweep.
4. **Comment sweep.**
   - The 14 review and bug references: `Highway.swift:167`, `LessonExplain.swift:33`, `ShowMe.swift:149`, `LessonSteps.swift:335`, `:1601`, `:1764`, `LessonPlayer.swift:12`, `SongSheet.swift:658`, `:1135`, `Diagrams.swift:432`, `LessonResults.swift:82`, `:93`, `SongCover.swift:1123`, `DemoScenes.swift:117`.
   - About 33 screenshot, CI and simulator comments: rewrite them as the "why", or link real issues.
5. **Swift 6.**
   - TimbreCore in `.v6` (`Package.swift:12`).
   - The app on `SWIFT_STRICT_CONCURRENCY=complete` (`project.yml`).
   - Fix the deprecated aliases (`TimbreWidgets.swift:71`, `:204`, `:209`; `TimbreApp.swift:21` via WP1).
   - Track the 13 `@unchecked Sendable` with their owners.
6. **Localisation pipeline.**
   - Move to `.xcstrings` with plural variants for the 23 counted strings.
   - Take keys from the xliff, and fix the mis-inferred specifiers (`Diagrams.swift:721`, `JourneyView.swift:311`).
   - CI fails when a shipped locale is missing a legal, permission or VoiceOver key.
   - Trim `CFBundleLocalizations` to locales ≥ 95 % (owner decision).
7. **CI.**
   - Least-privilege permissions and caching.
   - A required gate under 10 minutes; screenshot jobs nightly and non-gating.
   - Nightly TSan, `analyze`, and a coverage floor on TimbreCore.
   - `AccessibilityAuditUITests.swift` (new; every tab and step type) and a matrix of AX5, Bold, Increase Contrast, `ar` and `de` frames.
   - A launch metric.
   - `#Preview` files for the design-system components (`Timbre/Previews/*`, new).

**Acceptance**
- No scratch files at the repo root.
- `grep -rnE "review [0-9]+|bug [0-9]+" ios` returns 0, and lint blocks reintroduction.
- Environment reads appear only in `TestSupport.swift`.
- 0 warnings; TimbreCore builds in Swift 6 mode.
- The gate runs under 10 minutes; the audit test runs on every tab.
- The l10n gate fails on a missing paywall key.

**Files owned**
- Repository root files
- `.github/workflows/{ios, l10n, apple-delivery}.yml`
- `ios/project.yml`, `ios/Package.swift`
- `Timbre/Resources/*.lproj`
- `tools/{l10n, ci}/*`, `docs/l10n/*`
- New `Timbre/Support/*`, `Timbre/Previews/*`, `TimbreUITests/AccessibilityAuditUITests.swift`
- `TimbreWidgets/*`, `TimbreWatch*/*`
- Every file not listed in WP1–WP9 (for example `Intents/{InstrumentEntity, SharedIntents, StreakSnippet, WidgetLibrary*}`, `Services/{LiveActivityController, Watch*, WidgetBridge, GameCenterIDs, PracticeActivityAttributes}`, and the core `Audio` files other than `BandGroove`, `History`, `Notation`, `Signal`, `Tuning`, `Voice`, `YourSongs` other than `ChartPlayback`, `SongArrangement`, `SongOfTheDay`, `WeakSpots` and `SpacedReview*`)

**Where the code-only roadmap lands.** WP1–WP10 should lift the panel to about **8.6–8.8**:
- Technical would reach about 9.0.
- Inclusivity about 9.2.
- Visual about 9.0 once the icon family lands.
- Delight about 9.0.

Growth and Category stay at about 8.0–8.3 until the owner's items in §4 land, above all songs people know and a visible teacher. "#1 on all angles" is not reachable with code alone.

---

## 4. Decisions only the owner can make

| Decision | Panel's recommendation | Expected impact |
|---|---|---|
| **Song licensing** | License a starter pack of 20–30 recognisable songs (Hal Leonard, Musicnotes or Songtradr-style; or indie or artist partnerships). Budget roughly $15–60k in advances plus revenue share. Until then, lead with "Play any song: paste the chords, play along with Apple Music". | The single biggest conversion lever in the category. It moves Category and Growth by about 0.5–0.8 each. |
| **Recordings** | Commission:<br>• real ukulele (soprano and low-G), mandolin, 5-string banjo and solo cello sample sets (about $1.5–3k);<br>• full-band stems for the 10 best Originals;<br>• rights-cleared App Preview audio, or approve the app's own render;<br>• a 100–1,000-clip real-world corpus (guitar, bass, ukulele, violin; SE to 17 Pro; built-in mic and AirPods; quiet room and café). | Honest "Hear it" audio (a uke teacher hears the guitar stand-in in one note). The band becomes the reward. The corpus unlocks a published accuracy claim: "measured on N real strums". |
| **Hand model and teaching video** | A stylised rigged fretting hand (about $0.5–2k; not realistic) plus ukulele and banjo usdz. Two shoot days with one guitar and ukulele teacher and one violin and cello teacher for about 40 technique clips (bow hold, pick grip, palm muting, F barre) and Unit 1–2 intros (about $8–15k). Signed likeness and usage releases. | Closes the gap with Fender Play and Simply Guitar. Makes Timbre the only credible app with violin lessons that listen. Store frame #3 becomes "a teacher's hands". |
| **Pricing in App Store Connect** | Yearly **$49.99** with the **14-day** trial (keep 14; 10–16-day yearly trials convert at 43 % against 33 % for 5–9 days). Monthly **$9.99** with a 7-day intro offer. Lifetime **$149.99**, kept off the onboarding paywall. **Family Sharing on** for yearly and lifetime. A win-back offer. **Billing Grace Period on, only after WP1 ships.** Small Business Program. Then test $49.99 against $59.99. | Net per buyer rises from about $31.55 to $43.67. Installs needed for $10k a month fall from about 12.2k to 8.8k (at 2.6 % install-to-paid). Still about ⅓ of the lesson apps' price, so the value story holds. |
| **Analytics ID and server** | A TelemetryDeck app ID. An App Store Server Notifications v2 endpoint and the remote-config JSON on the owner's custom domain. Move the privacy policy there too, off `github.io` under a personal handle, and update the privacy label to "Analytics, not linked". | Without it, no paywall or price test, no D7 and no RPI, so no rational ad spend. Prerequisite for $10k a month. |
| **Translators and locales** | Fund the 474 UI strings × 48 locales plus the 1,126 lesson strings × 9 (low tens of thousands of dollars), **or** trim `CFBundleLocalizations` to the locales that are really complete (≥ 95 %). Either way, renewal terms are human-translated in every storefront sold. Add human review of the lesson languages. | Removes a legal and review exposure. Makes "49 languages" true. Opens the 9 localized storefronts (localized screenshots and Custom Product Pages). |
| **Art director, icon designer, sound designer, typefaces** | An art director and illustrator for 2–3 weeks (about $8–15k): the store set and preview cut, 6 spot illustrations, badge art direction. An icon designer for a 24-glyph family plus 5 tab symbols (about $2–4k). A sound designer for a three-note motif and about 12 cues mastered for phone speakers (about $3–8k). 4–6 licensed display faces for the sleeve system. One real-hands lifestyle photograph (with a model release). | Removes the most visible "template" tells; Visual reaches 9.0 or more. Gives Timbre a recognisable brand on the shelf. |
| **Free-tier policy** | Approve WP5's table: the standard tuning of every instrument, open chords with Check, capo, eighths and triplets, one custom tuning and 10 Your-songs charts are free. Keep Unit 2 as an A/B test. | Wins "best free tuner" reviews and the long-tail tuner queries (mandolin, banjo), which bring the installs the paywall converts. |
| **Testers and people** | Paid blind and low-vision testers (AppleVis, Fable). Left-handed testers, including upside-down players. A deaf or hard-of-hearing musician. A TestFlight cohort of 300–500 and 2–3 teacher quotes, with consent. A violinist to confirm the peg mapping. A device lab (SE, a mid-range iPhone, a Pro, an iPad, AirPods, a Watch). **An independent senior iOS reviewer** to own PR review. | Turns the accessibility and left-handed claims into shippable statements. Social proof before launch. Proves B3 and the audio-resilience fixes on hardware. A review trail an acquirer will price in. |
| **App Store Connect programme** | 9–12 Custom Product Pages linked to instrument keywords. In-App Events (December carols, a 30-day ukulele challenge). Product Page Optimization tests. A Featuring Nomination built on the "feel it stand still" story. Accessibility Nutrition Labels: declare Larger Text, Dark Interface, Differentiate Without Colour, Sufficient Contrast and Reduced Motion now, and **VoiceOver only after B8 ships**. An Apple Ads test of about $1.5–3k a month on exact-match instrument keywords, **after** RPI is measured. | The long-tail beachhead (violin, cello, ukulele) is where Timbre can rank in months. All six competitors leave their accessibility labels empty, so a filled one is a free differentiator. |

---

## 5. What NOT to do

**Business**
1. **Don't enable Billing Grace Period before WP1's `Access` fix** (`Access.swift:28-29`). Payers would lose Pro in exactly the window grace is meant to protect.
2. **Don't claim VoiceOver** in the Accessibility Nutrition Labels or the listing **until the play-along works with it** (B8). App Review can force corrections (Guideline 2.3).
3. **Don't shorten the trial to 7 days**, as `APP-STORE-LISTING.md` suggests. The data favours 10–16 days.
4. **Don't keep advertising "159 songs", "49 languages" or "whole chords"** until the code makes them true. Say "120+ songs".
5. **Don't add ads or mandatory accounts.** "No ads, no account" is the cleanest trust advantage over every competitor. Use iCloud sync instead of accounts.
6. **Don't spend on paid acquisition before revenue per install is measured.** At today's prices a year-1 install is worth about $0.82, below typical "learn guitar" CPIs.
7. **Don't fake social proof.** Show no rating line until it is real (≥ 4.6★, ≥ 200 ratings), and no quotes or laurels without consent.
8. **Don't ship songs that are "almost" a hit** (sound-alikes, artist names in copy) without a licence. Add "Happy Birthday" or other borderline public-domain titles only after the clearance doc and a legal check agree.

**Product and engineering**
1. **Don't turn on voice processing or echo cancellation for the tuner.** It degrades pitch accuracy. Use it for lessons only, behind a self-test, and off by default (WP6 phase 2).
2. **Don't let the new haptics shake the microphone.** Measure on a device; gate the detents outside ±3 ¢ if they bleed into the input.
3. **Don't do a big-bang rewrite** (splitting the `AppStore` god object or modularising into SPM) before the blockers ship. Extract incrementally behind WP1's hooks, or the parallel teams will collide.
4. **Don't mirror text** when mirroring for left-handers. Keep string *labels* (1 = thinnest) for upside-down players.
5. **Don't make the "Show me" hand realistic.** A stylised hand avoids the uncanny valley.
6. **Don't let marketing captures diverge from the product.** App Preview footage must be captured from the app. `marketingScale` may exaggerate amplitude only in DemoScenes, never as a mock-up.
7. **Don't keep adding theory units or tools.** The next content wave is song-led (uke and mandolin songbooks, requested public-domain songs, band stems). Breadth is already #1; depth of recognisable music is not.
8. **Don't pile on more chips, pills, eyebrows or glows to "add polish".** Every visual juror deduction is for too much of them. Subtract.
9. **Don't commit `[skip ci]` "WIP wave N" commits to main, or leave scratch files and review-round comments.** Those are the tells an acquirer and an ADA juror read first.
10. **Don't remove the honest trial timeline, the real-offers-only exit offer or the notification-after-trial ask.** They are the best monetisation ethics in the category, and editors notice.

---

## 6. Foreman's verification log, and where jurors were wrong or overstated

### Verified true (code)
- **No haptics-during-recording call.** Zero `setAllowHapticsAndSystemSoundsDuringRecording` anywhere; session at `AudioService.swift:243-250`. Interruption handling acts on `.began` only (`:71-77`). `AVAudioEngineConfigurationChange` is observed only in `RecordingPlayer.swift:45`.
- **Language.** `LocalStore.swift:10` sets `language = "en"`; the only writer is `SettingsView.swift:374`; `RootView.swift:36-37` uses it.
- **Persistence.** `LocalStore.swift:198-199` decodes and validates and throws; `TimbreApp.swift:15-22` is a dead-end Retry.
- **Entitlements.** `Access.swift:28-29` requires `expiresAt > now`; `CommerceService.swift:164` passes the transaction's `expirationDate`. `familyShareable: false` ×3. Prices are $34.99, $6.99 and $89.99.
- **Strum judging.** `LessonSteps.swift:1509` uses `chords: false`, and `register` grades onset distance only. `LessonSteps.swift:772` sets every string verified after 3 matched chroma frames.
- **Band.** `SongPerform.swift:83-86` uses `.melody`, and `Band.swift:46-55` repeats `Bar(root: tonic)`.
- **Accessibility.**
  - `Highway.swift:145-146` is a single opaque element.
  - There are 0 `AccessibilityFocusState`, 0 `keyboardShortcut` and 0 `performAccessibilityAudit`.
  - `handedness` is read only at `StringRail.swift:16` and `StrumModel.swift:325`.
  - `LessonResults.swift:601` hides the stars; `:598-599` still scales and rotates them under Reduce Motion.
- **HUD digits.** `HighwayHUD.swift:37` and `:67` use `numericText`.
- **App Preview.** `preview.py:509` uses `anullsrc`. In PREVIEW.txt the lock clip ends at 91.43 s, the lock sync is at 91.47 s, and the poster at 3.45 s falls inside the 3.40–3.73 s overlap.
- **Analytics.** `Analytics.swift:32-35` sets no ID; `paywall_shown` is logged only at `AppStore.swift:472`.
- **Paywall count.** `PaywallView.swift:483-486` counts `kind == .song`.
- **Curriculum.** 638 lessons in 14 courses; guitar has 5 free lessons out of 153. There are **159 song lessons but 124 distinct titles**, and all three song collections are `guitar.acoustic.6`.
- **Catalog.** 60 instruments and 102 tunings; 5 instruments are free; guitar has 6 presets.
- **Pro gates.** `PracticeView.swift:571-577` puts drone, chords, scales and intonation behind Pro; capo and transpose are Pro (`SettingsView.swift:150`, `:162`); subdivisions and sounds are Pro (`MetronomeView.swift:286`, `:324`).
- **Design counts.** 20 `IconOrb(`, 236 `Capsule()` (the visual juror said 242; the difference is immaterial), 53 `Eyebrow(`, and 31 distinct Sora sizes. 0 `#Preview`; 16 app unit tests; Swift 5 language mode.
- **Repository.** `findings.md`, `progress.md` and `task_plan.md` are tracked. `findings.md` exposes a personal Windows path and GitHub auth notes. 232 of 233 commits are by one author; 50 are WIP or `[skip ci]`. There are 14 review or bug references in 10 files.

### Verified true (screens)
- **65:** the "74" combo is ghosted.
- **44:** five selector rows, and "ajor pentatonic" hard-clipped.
- **51b:** beaded string glow, a per-string rainbow, and Show me at rest.
- **06:** three orb hues; the Today column makes the timeline non-linear; the strike price sits under "14 DAYS FREE".
- **05b:** the goal card runs under the dock.
- **62:** `star.fill` stars and the void below the level card.
- **63:** an amber Play CTA, and sleeves with the "— 0N / ORIGINALS" generator eyebrow.
- **Store sheet:** nine frames on one template.
- **Preview sheet:** AUTO flips to MANUAL; a double exposure at "Listening/Continue"; four identical Songs frames; no frame with "In tune".

### Where jurors were wrong or overstated
1. **Category: "the whole-song take is timing only" (`SongPerform.swift:397`) is wrong.** `SongPerform` feeds `midi` and `cents` into `PlayAlongJudge.update` (`SongPerform.swift:411`). Melody performances are pitch-and-timing judged. The blocker is real but narrower: `RhythmStep` strum and progression steps, which are the steps that teach chords. The song gap is the missing "Chords & words" mode, not a broken judge.
2. **Category vs Growth on the song count.** 124 distinct titles (my count) against 117 tunes keyed by `tuneKey`; both are right in method. "159" is the overstatement either way. Use "120+".
3. **Visual: "on the paywall it comes in five hues".** Per screen it is three (06: mint, sky, violet); five across the reason variants. The point stands: it contradicts the system's own colour rule.
4. **Technical: "test hooks in 23 production files".** I count about 20 files reading `TIMBRE_` variables, and most sit inside `#if DEBUG`, so release builds don't read them (`TimbreApp.swift:51-63`). One unguarded read is `Analytics.swift:34`, which is harmless. This is a hygiene tell, not a release risk.
5. **Delight and Technical on haptics: "very likely muted".** The API default is documented as `false`, and the call is absent. That is strong, but no one has felt it on a device. I treat it as a blocker until disproven because the fix costs one line. It needs a microphone-bleed check before shipping the detent ladder unchanged.
6. **Category: "the free tier is stingier than the free tuners".** True against Fender Tune (26 free tunings, chords, scales). Against GuitarTuna it is the reverse: Timbre gives every preset tuning on its 5 free instruments with no ads, while GuitarTuna frees only standard tuning and shows ads.
7. **Inclusivity understated its own localisation finding.** Because of B1, a fresh-install German or Arabic user sees English everywhere, not just the 26 % of untranslated strings. Right-to-left never engages. Localisation is worse than any single juror scored it.
8. **REVIEW14 (8.9) overstated readiness.** It credited commit 544c576's "one icon language" for the paywall, but the pixels (06, 16, 40) still show three hues. Its "still score" fix froze the score but not the combo. And it never audited language, persistence, entitlements, judge correctness or analytics. Do not anchor on it.
9. **Growth vs Category on price.** These aren't contradictory. Category's "#1 on price" survives at $49.99, about ⅓ of Yousician, Simply and Fender Play. Growth's model shows $34.99 leaves about 28 % of net per buyer on the table. Panel position: $49.99, then test $59.99.
