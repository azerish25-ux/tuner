# JURY 15: Technical achievement and acquirer due diligence

Juror role: Apple Design Awards juror for technical achievement, and the principal iOS engineer an acquirer would send to read the code before signing.

**What I checked.**
- **The code.** I read `ios/Timbre`, `ios/Sources/TimbreCore`, all test targets, `project.yml`, `Package.swift` and all six workflows. I also counted things directly in the tree (method below).
- **CI.** I pulled the latest published CI evidence (`ci-results/core`, `/app` and `/ipad`, 2026-10-25 09:56–10:16 UTC):
  - core: 358 tests, green;
  - app: 16 unit tests and 15 UI flows, green, archive built;
  - iPad: **red**. `TabletScreenshotsUITests.swift:110` reports "ipad-landscape-instruments: sitar, oud and erhu aren't whole on screen".
- **Screens.** I opened 90-stage-diagnostics and ipad-landscape-instruments-wrong.

**What I could not do.** There is no Swift toolchain on this machine, so nothing was compiled or run locally. Every runtime claim below comes from code reading or from the CI logs, and the items marked "verify on device" need a phone.

---

## 1. Score: **8.1 / 10**

**Verdict.**
- **Real technical achievement.** Parts of Timbre would win a technical ADA conversation:
  - **`PolyTuner`.** It is a polyphonic strum-to-tune solver. It fits a Hann-windowed damped-partial model with inharmonicity, fₙ = n·f₁·√((1+Bn²)/(1+B)), and uses ridge least squares and golden-section search (PolyTuner.swift:66-96). No competitor ships anything like it.
  - **Pitch detection.** It is an FFT-accelerated YIN on vDSP (DSP.swift:84-155, PitchDetectors.swift:5-79).
  - **Output path.** The render callback only ever *tries* its lock (AudioService.swift:794-800) and frees players outside the lock (AudioService.swift:737-744, 778-783).
  - **Sync.** It has host-time clocks for audio-visual sync (AudioService.swift:801-814) and tap-along latency calibration per route (AudioService.swift:427-461).
  - **Platform breadth.** Liquid Glass with pre-26 fallbacks (Glass.swift:22-37), a Watch app and complications, a Live Activity, configurable widgets plus a Control Center control, App Intents, Spotlight, TipKit, Game Center, and a weak-linked FoundationModels coach.
  - **Privacy.** Collection is zero by default, against "Data used to track you" on every competitor's listing.
  - **Defensive discipline.** There are 17 force unwraps in about 74k lines, no `print`, no TODO, LRU-capped caches, and purges on memory warning.
- **Why it is not a 9.**
  - Due diligence finds two latent blockers:
    - Fresh installs ignore the device language (LocalStore.swift:10).
    - Any state-file decode or validation failure leaves the app unable to open, with no recovery (LocalStore.swift:195-201, TimbreApp.swift:15-22).
  - Subscription access is wrong during Billing Grace Period (Access.swift:28-29).
  - The audio session is not resilient to engine configuration changes or interruptions.
  - Both targets are still in Swift 5 mode.
  - A 1,142-line `AppStore` god object is observed by 85 views.
  - The 59k-line app target has 16 unit tests, and there is no field telemetry at all.
- **It reads like one prolific author.** The code is careful, but it reads as one author iterating against screenshot reviews rather than a senior team. Comments cite "review 14" and "bug 64", test hooks sit in 23 production files, the repo root holds agent scratch files, and commits read "WIP wave 17: in-progress team edits".
- **Bottom line.** It is a good app with visible seams. It is excellent where it is ambitious and weakest where acquirers look first: data safety, entitlement correctness, observability and maintainability.

---

## 2. Head-to-head on the technical angle

Store facts (size, minimum OS, devices, privacy labels) are from each app's current App Store page (Sources).

### GuitarTuna (Yousician Ltd): split; Timbre wins the ADA column, GuitarTuna wins due diligence
- **Store facts.** 4.7★ (≈20K, CA). 295.6 MB, iOS 15+, Mac and visionOS, 11 languages, weekly releases. Tracks Location, Identifiers, Usage and Diagnostics. 15 instruments.
- **Timbre wins on:**
  - polyphonic strum-to-tune;
  - 60 instruments and 102 tunings;
  - 3D RealityKit peg cues;
  - Watch, Live Activity and widgets, none of which are listed for GuitarTuna;
  - no tracking SDKs.
- **GuitarTuna wins on:**
  - a tuner proven on hundreds of millions of real devices and rooms;
  - crash and diagnostics telemetry (its privacy label lists Diagnostics; Timbre has none);
  - accounts and sync;
  - Mac and visionOS reach;
  - release cadence.

  Timbre's DSP is validated only on synthetic signals. Tests/Fixtures holds no audio, and StrumSynth in PolyTunerTests.swift:7-60 is a simulator.

### Fender Tune: **Timbre wins clearly**
- **Store facts.** 4.8★ (2.6K). 70.2 MB, iOS 17.6+. Auto, manual and chromatic modes, 26 tunings, custom tunings behind a Fender account. The latest release note "restored the ability to strum" in manual view. Tracks identifiers for third-party advertising.
- **Why Timbre wins.** It is more sophisticated on every technical axis: polyphonic detection, intonation, strobe, drone, 3D, platform integration and privacy.
- **Where Fender is ahead.** Its custom tunings sync through an account. Timbre's live only on one device.

### Fender Play: **Timbre wins on technology, Fender wins on infrastructure**
- **Store facts.** 121 MB. 3,000+ video lessons with MatchMySound feedback (a licensed recognition engine), account sync, and integration with Fender amps.
- **Where Timbre is ahead.** Its in-house recognition, judging and band engine are more technically ambitious and run entirely on the device.
- **Where Fender is ahead.** It has a back end (accounts, progress synced across devices, live office hours). Timbre has no sync at all: an iPhone and an iPad keep separate streaks.

### Yousician: **Yousician wins, narrowly**
- **Store facts.** 4.6★. 329 MB, iOS 15+ and visionOS. Real-time feedback across guitar, bass and voice, weekly challenges against other users (server-side), and "unlimited practice across platforms".
- **Why Yousician wins.** Its recognition stack is proven across instruments and voices at scale, and it runs live operations and cross-device sync.
- **Where Timbre is ahead.** Strum tuning, privacy and Apple-platform depth (Watch, Live Activity, App Intents, Liquid Glass).
- **What would change the call.** Timbre would take this column with a real-audio accuracy corpus and iCloud sync.

### Simply Guitar: **even overall; Simply wins on recognition, Timbre on platform**
- **Store facts.** 4.7★ (≈400K). 260 MB, iOS 15+. Real-time recognition shipped to millions of learners. Tracks identifiers. Collects contact info and user content.
- **Where Simply is ahead.** Its note and chord recognition is far more battle-tested than Timbre's `ChordRecognizer`, whose tests use synthesized signals only.
- **Where Timbre is ahead.** The tuner, platform integration, offline privacy and 3D.

### JustinGuitar (Musopia): **Timbre wins**
- **Store facts.** 4.9★ (22K). 333 MB. English only. iOS 15+; on Mac it says itself it is "not optimized". Tracks identifiers.
- **Why Timbre wins.** It is technically far more ambitious: 49 locale tables (once the default bug is fixed), real-time judging, a 3D "Show me", a Watch app and intents. JustinGuitar's strength is content and teacher brand, not engineering.

**Net.** On innovation and Apple-platform craft, Timbre beats every competitor. On operational maturity, three competitors win today: field telemetry, data safety, accounts and sync, and recognition proven on real audio.

---

## 3. Everything that costs points, ranked

### 1. Blocker (S): fresh installs ignore the device language, and two localization paths disagree
- **Where.** LocalStore.swift:10 (`public var language = "en"`); AppStore.swift:99 and :333; RootView.swift:36-37; Catalog.swift:21-26; AppStore.swift:301-311.
- **What's wrong.**
  - Nothing ever sets `"system"` for a new user. A German, Japanese or Arabic device starts the app in English:
    - SwiftUI `Text` resolves against `.environment(\.locale, "en")`;
    - catalogue and lesson strings go through `TimbreLocalization.bundle`, which is en.lproj;
    - note names default to English letters, despite the comment at AppStore.swift:100;
    - right-to-left layout never engages for ar, he, fa or ur.
  - Meanwhile 271 `String(localized:)` calls carry no bundle or locale and follow the *system* language. Among them is the tuner status line at AppStore.swift:302-311.
  - The result is a mixed-language UI. The "49 languages" claim in the listing is invisible to new users. The CI UI tests force `-AppleLanguages (en)` (TimbreUITests.swift:12), so no CI run can see this.
  - Verify on a device: delete the app, set the device to German, launch.
- **Fix.**
  1. Default `language` to `"system"`, and on load treat a stored `"en"` that the user never chose as `"system"`. Add a `languageChosen` flag like `notationChosen`.
  2. Route every lookup through one resolver: pass `bundle: TimbreLocalization.bundle` to `String(localized:)`, or drop the in-app picker and adopt iOS per-app language (Settings › Timbre › Language), which Apple prefers.
  3. Add one UI test that launches in `(de)` and one in `(ar)`, and assert a known translated label and right-to-left direction.

### 2. Blocker (M): any decode or validation failure bricks the app, and there is no migration safety
- **Where.**
  - LocalStore.swift:195-201: the whole state file is decoded and validated on load and throws on failure.
  - LocalStore.swift:314-342: validation is strict. `version == 1`, `progress.isValid` and `learn.isValid` are checked on load, and the loop runs over every record.
  - TimbreApp.swift:15-22 and :66: the only response is "Timbre couldn't open" and a Retry that fails forever.
  - Tests/TimbreCoreTests/PersistenceTests.swift:46 asserts this fail-closed behaviour.
- **What's wrong.**
  - All progress (streak, XP, lessons, spaced review, custom tunings) lives in one JSON file.
  - Each of these, shipped in an update, locks every existing user out with no way back short of deleting the app and losing the streak, the product's core retention asset:
    - adding a non-optional `Codable` field (synthesized decoding ignores default values);
    - tightening a validator;
    - a TestFlight-to-App-Store downgrade (the version check).
  - There is no backup copy, no quarantine, and no test that decodes a state file written by an earlier version (a golden-file test).
- **Fix.**
  1. On a decode failure, move the file to `timbre-state.corrupt-<date>.json`, then try `timbre-state.bak.json` (written before every successful persist), else start fresh, and tell the user.
  2. Decode `UserSettings` with a hand-written lenient `init(from:)` (`decodeIfPresent ?? default`) so new fields can never break old files.
  3. Validate on *write* only, and *repair* on load (clamp, drop bad records) rather than throw.
  4. Accept `version <= current` and add explicit migration steps.
  5. Add golden fixtures (`state-v1-2026-10.json`, …) to TimbreCoreTests and decode them on every CI run.

### 3. Major (S): entitlements are wrong in Billing Grace Period, and billing retry is invisible
- **Where.** Access.swift:26-31; CommerceService.swift:161-167.
- **What's wrong.**
  - `Transaction.currentEntitlements` already includes subscriptions in grace period. `AccessPolicy.isPro` then *also* requires `expiresAt > now`, and during grace the transaction's `expirationDate` is in the past. So when the owner enables Billing Grace Period in App Store Connect, which is the standard recovery tool for involuntary churn, payers lose Pro exactly when Apple says they should keep it.
  - Nothing reads `Product.SubscriptionInfo.status` or `renewalInfo`, so the app never shows "update your payment method" during billing retry. At $10k a month, involuntary churn is often 20–40 % of all churn.
  - The StoreKit tests cover purchase, expiry, refund and lifetime only (CommerceIntegrationTests.swift:39-86). They do not cover grace, retry, Ask to Buy (the `pending` path), win-back (`PaywallWinBack.swift:27`; the fixture has no win-back offers) or offer codes.
  - Family Sharing is off on all three products (Timbre.storekit).
- **Fix.**
  1. Trust `currentEntitlements` for access, keeping only the `revocationDate` check.
  2. Read `subscription.status` for `.inGracePeriod` and `.inBillingRetryPeriod` and show a banner deep-linking to `manageSubscriptionsSheet`.
  3. Add SKTestSession tests with `_billingGracePeriodEnabled`, `askToBuyEnabled` and a win-back offer in the fixture.
  4. Decide Family Sharing deliberately.

### 4. Major (M): the audio engine is not resilient to configuration changes or interruptions
- **Where.** AudioService.swift:71-116, :152-178, :252-263; RecordingPlayer.swift:45 and :248-253.
- **What's wrong.**
  - **No configuration-change observer.** `AudioService` never observes `AVAudioEngineConfigurationChange`; only `RecordingPlayer` does.
    - When the hardware format changes (AirPods connecting mid-lesson, which is precisely the "band joins when headphones connect" flow), the engine stops. In output-only mode (the Metronome tool, the drone) the route-change handler does nothing but `refreshRoute()`, so the click dies while `metronomeRunning` stays true.
    - When capturing, the restart path reads `wasOutputting = engine.isRunning` (false once the engine has stopped), then `setSampleRate(…, keepState: false)` wipes the metronome, band and drone (AudioService.swift:256 and :728). The lesson's click goes silent with no state change.
  - **Interruptions.** `.ended` and `.shouldResume` are ignored, so a phone call or Siri permanently stops a background metronome or drone.
  - **Two session owners.** `AudioService` and `RecordingPlayer` both set category and activation.
  - **Main-thread deactivation.** `setActive(false)` is called on the main thread (AudioService.swift:240), and it blocks.
- **Fix.**
  1. One `AudioSessionCoordinator` actor owns category, mode and activation.
  2. Observe `.AVAudioEngineConfigurationChange` and rebuild the graph keeping renderer state; snapshot `metronomeRunning`, `droneRunning` and the band request *before* stopping.
  3. Resume on interruption end when `.shouldResume` is set.
  4. Deactivate off the main thread.
  5. Add a real-device test script: AirPods on and off mid play-along, a phone call during the drone, Siri during the tuner, CarPlay.

### 5. Major (S, verify on device): tuner haptics are probably muted while the microphone is open
- **Where.** AudioService.swift:243-250 (session setup); Haptics.swift:39-45 (`detent`, fired at up to 60 Hz from AppStore.swift:609); `lock()` at AppStore.swift:618.
- **What's wrong.** Under `.playAndRecord` with input active, iOS suppresses haptics and system sounds unless `allowHapticsAndSystemSoundsDuringRecording` is true. The app never sets it. The tuner's signature tactile design (the detent ladder and the lock pattern) is therefore likely silent on real devices during the only moments it is designed for. Simulators have no haptics, so CI cannot catch it.
- **Fix.**
  1. Call `try session.setAllowHapticsAndSystemSoundsDuringRecording(true)` in `configureSession()`.
  2. Measure on a device whether the vibration bleeds into the microphone (it might: gate `detent` while `abs(cents) > 3`).

### 6. Major (L): a god object and mixed observation paradigms
- **Where.**
  - AppStore.swift has 1,142 lines and 32 `@Published` properties. It holds the tuning session, the voice exercise runner (:929-986), lesson-microphone arbitration (:716-747), XP, quests, badges, freezes, the daily plan, widget, watch and reminder publishing (:164-184), paywall routing, settings persistence, the metronome and the drone.
  - It is an `ObservableObject` read through `@EnvironmentObject` by 85 declarations in 50 files, so every publish (`selectedCourse` on auto-detect, `rewardPulse`, `countdown`, `referenceMidi`…) invalidates all of them.
  - 11 `ObservableObject` types sit beside 3 `@Observable` ones (a half-done migration).
  - Side effects run from getters: `dailySet` (:857-866) schedules a settings write while views draw.
  - Derived state is recomputed per access with no cache. `streak` (:251) rebuilds a Set of `startOfDay` over every record each time, and is read 21 times in views. `recordProgress` → `achievementMetrics` walks the 638-lesson curriculum for every event, ×N per ear round (:698).
- **Fix.**
  - Split into `@Observable` feature models: `TunerSession`, `VoiceSession`, `ProgressStore` (XP, quests, streak, with a cached `StreakSummary` invalidated on save), `DailyPlan`, `Router` (tab, sheets, paywall), and `SettingsStore`.
  - Inject them per feature. Keep `LiveReading` as is; its closure-passing isolation (TuneView.swift:233) is good.

### 7. Major (M): not Swift 6 ready, and warnings are tolerated
- **Language mode.** `swiftLanguageModes: [.v5]` (Package.swift:12) and `SWIFT_VERSION: "5.10"` (project.yml), with no `SWIFT_STRICT_CONCURRENCY`, so checking is minimal.
- **Warnings that ship.**
  - 9 isolation warnings, all marked "error in Swift 6": DroneSingAlong.swift:275, :292, :299, :303, :327 and :346. They come from `static let band/window/goal` on a `@MainActor` class (:33-44) read from the nonisolated `DroneTraceArt`.
  - 4 deprecated-alias warnings in the team's own code: TimbreApp.swift:21 `BrassButtonStyle`; TimbreWidgets.swift:71, :204 and :209 `brass` and `ember`.
- **Swift 6 blockers.**
  - Global mutable statics:
    - `NoteNames.active` (NoteNames.swift:17);
    - `TimbreLocalization.language` (Catalog.swift:22);
    - `Palette.tuningBand` (Readout.swift:7);
    - static caches in CoachVoice.swift:291-293, PlayHubTools.swift:435 and InstrumentRig.swift:70;
    - `ShowMe.lastProblem` (ShowMe.swift:33).
  - 13 `@unchecked Sendable` classes.
  - A `deinit` that touches state in a `@MainActor` class (CommerceService.swift:49-52).
- **Fix.**
  1. Today: mark the three DroneSingAlong constants `nonisolated static let` and replace the deprecated aliases.
  2. Set `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in CI.
  3. Move TimbreCore to `.v6` first; it is mostly value types already.
  4. Then move the app to `SWIFT_STRICT_CONCURRENCY=complete` and Swift 6, with `defaultIsolation(MainActor)` for UI modules.
  5. Replace the global statics with environment or injected values.

### 8. Major (M): the test pyramid is inverted for the app, and the DSP is never checked against real audio
- **Where.**
  - TimbreAppTests: 16 tests, 265 lines, covering a 59k-line target.
  - TimbreUITests: 15 flows that take 20 minutes (test06 alone takes 350 s). They are mainly the screenshot pipeline (test11–test15 are "Store…" scenes).
  - `Tests/Fixtures` holds only `Timbre.storekit`.
- **What's missing.**
  - No `performAccessibilityAudit()`.
  - No `XCTApplicationLaunchMetric`, memory or energy metrics.
  - No code-coverage collection.
  - No snapshot tests.
  - No unit tests for `AudioService`, `CommerceService`'s routing, the daily plan, `DeepLink`, `PaywallPlan` or the play-along take state.
  - No recorded-audio regression corpus. The YIN, PolyTuner and ChordRecognizer tests all use synthesized signals.
  - The iPad job is red on the latest run.
- **Fix.**
  1. Commit 100–300 short recordings (iPhone SE to 17 Pro, built-in microphone and AirPods; guitar, bass, ukulele and violin; quiet room and café) with ground-truth labels. Run accuracy and lock-latency budgets in the core job.
  2. Add accessibility audits to three UI flows, and a launch-time metric.
  3. Turn on `-enableCodeCoverage YES` with a floor on TimbreCore.
  4. Move scene and screenshot capture into its own non-gating workflow.

### 9. Major (S): idle rendering costs battery
- **Where.**
  - Components.swift:20-38: `MoteField` is a 46-particle `Canvas` in `TimelineView(.animation(minimumInterval: 1/30))` with no pause, and Low Power Mode is ignored. It sits behind the Tune tab (TuneView.swift:40), StrumTuneView.swift:50, onboarding and the launch error screen.
  - The RealityKit stage renders every frame while the tuner is on screen, with no rest or Low Power fallback. Only Show me (ShowMe.swift:85) and the shaders (Shaders.swift:9-11) honour Low Power.
  - `StreakFlame` runs at 60 fps unpaused (GameUI.swift:92).
  - The microphone path spawns a main-actor `Task` per reading at 60 Hz (AudioService.swift:169-173).
  - There are no signposts and no MetricKit, so none of this has been measured.
- **Fix.**
  1. `paused: !visible || lowPower` on `MoteField` and `StreakFlame`.
  2. When `resting` (already computed at TuneView.swift:227), swap the RealityView for the studio still, or cap it at 30 fps.
  3. In Low Power Mode, use the 2D studio stage.
  4. Instrument with `OSSignposter` and gate an energy regression in CI with `XCTOSSignpostMetric`.

### 10. Major (S): the launch path and memory duplication
- **Where.** AppStore.swift:706; BandGroove.swift:113; SpotlightIndex.swift:74; the `Catalog()` decode at AppStore.swift:92.
- **What's wrong.**
  - The 4.3 MB `curriculum.json` is decoded synchronously on the main thread in `AppStore.init`, during launch.
  - A failure is swallowed into an empty curriculum by `try?`, so Learn would silently show nothing.
  - It is decoded twice more: by `BandStyleIndex.shared` and by `LessonEntity.all`. That is three resident copies of the largest model in the app.
- **Fix.**
  1. Load the curriculum once, through one `CurriculumStore.shared` behind an actor, and hand the instance to all three users.
  2. Decode off the main thread before the first frame (the launch screen holds), or switch to a binary plist or lazily sharded per-course JSON.
  3. Fail loudly in DEBUG.
  4. Add a launch-time XCTest metric.

### 11. Minor (M): modularity and duplication
- **Where.** Highway.swift (2,053 lines), LessonSteps.swift (1,951), SongsView.swift (1,788), PaywallView.swift (1,662), SongCover.swift (1,481).
- **What's wrong.**
  - There are only two modules, and 30 app files exceed 700 lines.
  - The play-along take orchestration is duplicated between Highway.swift and SongPerform.swift: 28 duplicated five-line windows and 19–21 `@State` each. LessonSteps holds 62 `@State` across 12 types.
  - The tuner stage loads its usdz itself (InstrumentStage.swift:152) and builds its own IBL environment (:673-678), outside `ModelCache` (ModelCache.swift:71-82). The same guitar can be resident twice.
  - `receiveImageBasedLight` is duplicated (InstrumentStage.swift:268 and ShowMeScene.swift:448).
- **Fix.**
  - Extract a `PlayAlongSession` model into TimbreCore beside `PlayAlongJudge`, which is already there and tested.
  - Split into SPM targets: `DesignSystem`, `AudioEngine` (AudioService, Band, SoundFX, testable without UI), `Tuner`, `Learn`, `Paywall`, `Platform` (intents, widgets bridge).
  - Route every model load through `ModelCache`.

### 12. Minor (M): the code reads AI-iterated rather than senior-team
- **Comments that cite review rounds and bug numbers with no tracker:**
  - ShowMe.swift:149 ("store frame 51b, review 15");
  - LessonResults.swift:82 and :93 ("review 14, bug 2", "review 13, bug 1");
  - SongCover.swift:1123 and SongSheet.swift:658 ("review 14");
  - LessonSteps.swift:335, :1601 and :1764 ("bug 52", "bug 5");
  - LessonPlayer.swift:12 ("bug 64").
- **Test and marketing concerns in production code:**
  - 51 comments about screenshots, CI or the simulator;
  - environment-variable test hooks in 23 production files;
  - the root paywall is an overlay because "UI tests never saw a sheet" (RootView.swift:43-44).
- **Style:**
  - doc comments split around an attribute (AppStore.swift:749-754);
  - 634 semicolon-chained lines and lines up to 364 characters, with no SwiftLint or SwiftFormat;
  - zero `#Preview` in 132 view files.
- **Repository hygiene:**
  - agent scratch files at the repo root (`findings.md`, `progress.md`, `task_plan.md`);
  - 231 of 232 visible commits by one author, many "WIP wave N: in-progress team edits [skip ci]";
  - no PR review trail.

  An acquirer reads this as "single generator, no review".
- **What earns it credit.** The comments do explain *why*, the naming is consistent, and functions stay small: the longest body is 126 lines (Highway.swift:908).
- **Fix.**
  1. Strip the review and bug references, or link real issues.
  2. Move all hooks behind one `TestSupport` launch configuration compiled only in DEBUG.
  3. Add SwiftFormat and SwiftLint to CI.
  4. Add `#Preview`s for the design-system components.
  5. Delete the scratch files.
  6. Squash the WIP commits on merge and adopt a PR template with review.

### 13. Minor (S): a stringly typed domain and dead state
- **Strings where enums belong:**
  - `TuningReading.status: String` (TuningTracker.swift:28), compared against `"noSignal"` and `"inTune"`;
  - `PracticeRecord.kind`, `familyId` lists (AppStore.swift:1082) and paywall reasons;
  - settings `notation`, `stageMode` and `handedness` are all `String`.
- **Dead state:**
  - persisted fields `theme`, `skin = "brass"`, `reducedMotion` and `telemetryEnabled` (LocalStore.swift:6-22) are never read;
  - `MpmPitchDetector` (PitchDetectors.swift:81-116) is used only by tests;
  - the empty `reset() {}` methods (PitchDetectors.swift:23 and :89).
- **Fix.** Use `Codable` enums with raw values; the JSON stays compatible. Delete the dead fields through the lenient decoder from item 2.

### 14. Minor (M): persistence is split and nothing syncs
- **Split storage.**
  - State lives in the LocalStore JSON *and* in UserDefaults.
  - The key `"learn.course"` is a raw literal in 17 places.
  - Also in UserDefaults: `plan.dailyMinutes` (AppStore.swift:371), the latency calibration (AudioService.swift:441-457), the band switch and the tune-check keys.
  - "Clear practice history" does not touch them.
- **Write cost.** Every settings stage re-validates up to 2,000 records (LocalStore.swift:210-216 → 330-341). Every record append rewrites the whole file on the main thread (:222-249).
- **No sync.** There is no iCloud: the iPhone, the iPad (a marketed device) and the Watch each keep their own streak.
- **Fix.**
  1. Put typed keys in one `Preferences` type.
  2. Validate the delta, not the history.
  3. Persist off the main actor.
  4. Add `NSUbiquitousKeyValueStore` for streak and XP and a CloudKit private database for history. That gives account-free sync, a privacy-friendly answer to competitors' accounts.

### 15. Minor (M): the localization machinery
- **Where.** Localization.swift:5-7; Catalog.swift:23-26; dynamic keys such as AppStore.swift:245; CI log `ci-results/core:l10n.log`; ios.yml:28-35.
- **What's wrong.**
  - Strings are in legacy `.strings` tables, not String Catalogs.
  - A module-level `NSLocalizedString` *shadows* Foundation's.
  - `TimbreLocalization.bundle` builds a `Bundle` lookup on every string.
  - Dynamic keys defeat extraction.
  - The latest CI run reports 475 app strings untranslated in all 48 locales and 1,126 lesson strings missing in 9. The gate is warning-only.
- **Fix.**
  1. Migrate to `.xcstrings`.
  2. Cache the bundle.
  3. Make the CI check fail on any key missing in a locale the listing advertises.

### 16. Minor (S): no observability, and the privacy documents drift
- **Analytics.**
  - It is a hand-rolled TelemetryDeck client (Analytics.swift:21-96) whose app ID is empty, so production has zero funnel data.
  - `flush()` on background has no background task (:85-95), so batches are lost.
  - The persisted opt-out `telemetryEnabled` is never read.
- **No field diagnostics.** There is no MetricKit and no crash reporting.
- **Privacy documents disagree.**
  - docs/ios/PRIVACY.md:23-25 says "no third-party analytics" and omits Game Center (friends' streaks, leaderboards) and daily practice reminders.
  - PrivacyInfo.xcprivacy declares ProductInteraction collection.
  - The policy URL is hard-coded twice to github.io (PaywallView.swift:1386, SettingsView.swift:395). I could not load it from here, but it exists on the `gh-pages` branch.
- **Fix.**
  1. Use the official TelemetryDeck SDK, or keep the client and wrap flush in `beginBackgroundTask`.
  2. Add `MXMetricManager` (crashes, hangs, energy, launch).
  3. Align the policy, the privacy label and the manifest before the ID is set.
  4. Move the URL to `Info.plist` and the owner's domain.

### 17. Minor (S): CI robustness
- **Where.** ios.yml:1-254.
- **What's wrong.**
  - The workflow triggers on pushes to `main` only (`v2/foundations` is covered through its PR), and 19 commits carry `[skip ci]`.
  - The UI and iPad jobs run serially for 20–45 minutes with no DerivedData, SPM or brew caching.
  - The iPad job toggles private SpringBoard defaults (ios.yml:148-185).
  - Every job gets `contents: write`.
  - There is no Thread Sanitizer or Address Sanitizer job, no `xcodebuild analyze`, no lint and no coverage.
  - The iPad job is red now.
- **Fix.**
  1. Least-privilege permissions per job (publishing only).
  2. Cache dependencies.
  3. Add a nightly TSan job on TimbreAppTests and the core tests, an `analyze` step and a lint step.
  4. Make the screenshot jobs non-blocking and nightly; keep a fast (<10 min) required gate.

---

## 4. How to take #1 on the technical angle (ranked by impact)

1. **Remove the two latent blockers this week (S + M).**
   - Default the language to "system" and use one localization path.
   - Crash-proof persistence: a backup file, a quarantine for bad files, lenient decoding, and golden-file migration tests.

   Nothing else matters if one update can lock out every streak, or if the 49 languages never appear.
2. **Make revenue correct and measurable (S/M).**
   - Grace-period and billing-retry-aware entitlements, with an in-app "fix payment" banner.
   - StoreKit tests for grace, retry, Ask to Buy, win-back and offer codes.
   - Set the TelemetryDeck ID and track a funnel from onboarding through paywall shown, trial started, converted and churned.
   - App Store Server Notifications V2 to a tiny endpoint (or RevenueCat) for MRR and churn dashboards.

   You cannot reach $10k a month without seeing the funnel.
3. **Prove the DSP on real audio and publish the numbers (M).**
   - A recorded corpus across phones, microphones, rooms and instruments.
   - CI budgets such as "≤0.5 ¢ median error, ≤250 ms lock" and "strum: all six strings within 2 ¢ in 0.85 s".
   - Then put the numbers on the listing. "The only tuner that reads all six strings in one strum, measured on 300 real recordings" is an ADA-calibre technical story none of the six competitors can tell.
4. **Re-architect for a team, not an author (L).**
   - Split `AppStore` into `@Observable` feature models and the app into SPM modules (`AudioEngine`, `Tuner`, `Learn`, `Paywall`, `DesignSystem`).
   - Swift 6 language mode with warnings as errors, plus SwiftFormat and SwiftLint.
   - Previews for every design-system component.
   - Strip the review and bug-number comments and the test hooks into a `TestSupport` layer.
   - A PR workflow with review and ADRs.

   This is what turns "impressive" into "acquirable".
5. **Harden audio and battery on real hardware (M).**
   - One session coordinator, plus configuration-change and interruption recovery.
   - Haptics allowed while recording.
   - Low Power and idle fallbacks for RealityKit and the mote field.
   - MetricKit and signposts.
   - A device matrix in CI (Xcode Cloud or a device farm): AirPods mid-lesson, a phone call during the drone, Siri during the tuner.
6. **Account-free sync as the differentiator (M).** CloudKit or key-value-store sync of streak, XP and lessons across iPhone, iPad and Watch. Competitors need an email account; Timbre would sync privately through iCloud. It is a privacy story Apple editorial likes, and it closes the gap with Yousician and Fender Play.
7. **Ship where the competitors already are (S/M).**
   - "Designed for iPad" on Apple Silicon Macs and on visionOS (GuitarTuna, Yousician and JustinGuitar list both).
   - `AudioPlaybackIntent` so "Start the metronome" works without opening the app.
   - An `AppEntity`-backed lesson and song Spotlight index, decoded once.

---

## 5. What only the owner can do
- **App Store Connect.**
  - Turn on Billing Grace Period (only after fix #3, or payers will lose access).
  - Configure win-back offers and offer codes, and choose a Family Sharing policy.
  - Set up App Store Server Notifications V2 with a receiving endpoint.
  - Signing secrets for `apple-delivery.yml`.
- **Analytics and diagnostics accounts.** A TelemetryDeck account and app ID (set `TELEMETRYDECK_APP_ID`). A crash and diagnostics decision: MetricKit alone, or a vendor.
- **Legal.** Privacy-policy hosting on the owner's own domain, plus a legal pass that adds Game Center, reminders and analytics. Then update the nutrition label.
- **Real devices and people.**
  - A device lab or device-farm budget (SE, a mid-range iPhone, a Pro, an iPad, AirPods, a wired headset, a Watch).
  - Paid macOS CI minutes, or Xcode Cloud.
  - Players to record the real-audio test corpus: guitar, bass, ukulele and violin, across phones and rooms.
- **An independent senior iOS reviewer** (a human) to own PR review and sign off on the Swift 6 and architecture migration. Today 231 of 232 visible commits share one author, and no review trail exists. A buyer will price that in.

---

## Method notes (for reproducibility)
- **Sizes.** `find … | xargs wc -l` gives app 59,324 lines in 132 files, core 12,563 in 47, widgets 1,296, watch 966 + 173, tests 8,319 (core 6,450, app 265, UI 1,604).
- **Counts.**
  - 358 core tests, 16 app tests, 15 UI flows.
  - 17 force unwraps (Python scan excluding `!=`, string literals and `baseAddress!`).
  - 271 `String(localized:)` calls without bundle or locale.
  - 85 `@EnvironmentObject … AppStore` declarations in 50 files.
  - 67 `TimelineView`s, mostly paused correctly.
- **CI evidence.** `git fetch` of `ci-results/{core,app,ipad}` at sha 6ce8916 (core) and b33912a (app, iPad). Build warnings were taken from `build.log.gz`. The localization counts come from `ci-results/core:l10n.log`.
- **Not verified here, needs a device.** Haptic suppression (item 5), the engine stopping on AirPods connect (item 4), and the actual battery draw (item 9). The language default (item 1) is certain from the code; its on-screen mix should be confirmed with a fresh install on a German device.

## 6. Sources
- [GuitarTuna on the App Store (Canada)](https://apps.apple.com/ca/app/guitartuna-tune-play-guitar/id527588389): rating, 295.6 MB, iOS 15+, Mac and visionOS, tracking labels, IAP prices.
- [Fender Tune on the App Store](https://apps.apple.com/th/app/fender-tune-guitar-tuner-app/id1107017950?l=th): 4.8★ (2.6K), 70.2 MB, iOS 17.6+, v4.16.2 "restored strum", tracking labels, features. The [US listing](https://apps.apple.com/us/app/-/id1107017950) would not load.
- [Fender Play on the App Store](https://apps.apple.com/app/id1226057939): 121.3 MB, MatchMySound, 3,000+ lessons, account features.
- [Yousician on the App Store (RU)](https://apps.apple.com/ru/app/yousician-%D0%B2%D0%B0%D1%88-%D1%83%D1%87%D0%B8%D1%82%D0%B5%D0%BB%D1%8C-%D0%BC%D1%83%D0%B7%D1%8B%D0%BA%D0%B8/id959883039): 4.6★, 329 MB, visionOS, tracking labels, cross-platform practice.
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): 4.7★ (≈400K), 260.4 MB, iOS 15+, tracking labels, prices.
- [Justin Guitar Lessons & Songs on the App Store](https://apps.apple.com/US/app/id1176125504): 4.9★ (22K), 333.4 MB, English only, visionOS, tracking labels.
- [Haptic feedback and AVAudioSession conflicts (DEV Community)](https://dev.to/maxnxi/haptic-feedback-and-avaudiosession-conflicts-in-ios-troubleshooting-recording-issues-2ocl): `setAllowHapticsAndSystemSoundsDuringRecording` during `.playAndRecord`. Apple's `AVAudioSession.allowHapticsAndSystemSoundsDuringRecording` defaults to false.
- [CHHapticEngine documentation (Apple)](https://developer.apple.com/documentation/corehaptics/chhapticengine.md).
- Blocked: https://azerish25-ux.github.io/tuner/privacy.html (the fetch permission timed out). Its source is on the `gh-pages` branch and in docs/ios/PRIVACY.md.
