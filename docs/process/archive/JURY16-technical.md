# JURY 16: Technical achievement and acquirer due diligence

Juror role: ADA technical-achievement juror, and the principal iOS engineer an acquirer sends to read the code before signing.

**What I checked.**
- **Code.** `ios/Timbre` (66,524 lines, 144 files), `ios/Sources/TimbreCore` (14,032 lines, 53 files), all test targets, `Package.swift`, `project.yml`, the six workflows and `tools/ci`. Repo HEAD is `eb6ee5c` on `v2/foundations`.
- **CI evidence**, fetched from the `ci-results/*` branches and the GitHub REST API on 2026-10-25 at 15:24 UTC:
  - core, run 40204220703 (e74c390): **417 tests green**, 0 compiler warnings. The hygiene lint, SwiftLint (report-only) and the l10n reports ran.
  - app, run 40199381317 (543192c): **27 unit tests and 24 UI flows green**, 3 warnings (all from Apple's StoreKitTest SDK). The **archive step was cancelled** by the 60-minute timeout; `archive.log` is 0 bytes.
  - iPad: green.
  - The current run's app job (e74c390, 90-minute budget) was still in its UI flows at 15:24 UTC.
  - The four completed runs before it were `cancelled`, `failure`, `cancelled` and `failure`.
- **Screens.** I opened 90-stage-diagnostics and 11b-tune-strum, the App Preview notes, and the CI accessibility-audit attachments.

**What I could not do.** There is no Swift toolchain on this machine, and I had no device. Runtime claims come from code and CI logs. Items marked "verify on device" need a phone.

---

## 1. Score: **8.5 / 10** (round 15: 8.1)

**Verdict.**

**What the team fixed, verified in code.** This wave fixed most of what an acquirer would have walked away over:
- **Persistence is crash-proof.**
  - Lenient decoders sit on every persisted type (LocalStore.swift:108-168; Progression.swift:59-82; LessonEngine.swift:367).
  - A failed open quarantines the file and falls back to the backup, then to a fresh start, and repairs into bounds rather than throwing (LocalStore.swift:361-388, 495-578).
  - The launch screen recovers (TimbreApp.swift:108-200).
  - A golden v1 fixture and a Mirror round-trip test guard it (PersistenceTests.swift:137, :173-202).
- **The device language is the default** (LocalStore.swift:12, :528-532), with one cached bundle and green German and Arabic launch tests.
- **Billing Grace Period is honoured** (Access.swift:30), with a billing-issue banner (BillingIssueBanner.swift, mounted at RootView.swift:36). StoreKit tests now cover grace, retry and Ask to Buy.
- **One audio-session owner** with off-main deactivation (AudioService.swift:791-851). Engine configuration changes, interruptions with "should resume" and media-services resets all recover (:82-144, :320-375). Haptics are allowed while recording (:821).
- **Idle rendering stops.** The motes pause, and the 3D stage hands over to its studio picture after 12 s or in Low Power Mode (InstrumentStage.swift:760-948).
- **One curriculum, decoded off the main thread** (CurriculumStore.swift).
- **Telemetry.** TelemetryDeck, MetricKit and AdServices with a real opt-out and a background-task flush (Analytics.swift). The privacy policy and manifest now agree.

**DSP.** The DSP is still the best in the category on paper:
- `PolyTuner`'s damped-partial fit;
- per-stroke chord checks (`StrokeChords`);
- the "which string didn't ring" check (`ChordRing`), which refuses to accuse a string that sits on another string's harmonic.

**Why it is not a 9.**
- **The wave can't ship through its own pipeline.** The renewal terms, "Start free trial", the new billing banner and a permission string are untranslated in all 48 non-English locales. `apple-delivery.yml:88` gates on exactly that. App-string debt grew from 475 to 584.
- **No end-to-end green run exists for this wave.** The last published app run lost its archive to the timeout, and HEAD is `[skip ci]`.
- **Architecture and concurrency are where round 15 left them, and slightly worse.**
  - Swift 5 mode in both targets.
  - `AppStore` has grown to 1,205 lines and is observed through 89 `@EnvironmentObject` declarations.
  - `ObservableObject` types have grown from 11 to 16, against 3 `@Observable`.
  - `@unchecked Sendable` has grown from 13 to 17.
  - There are still two modules and zero `#Preview`.
- **Two of the new gates don't gate.**
  - The accessibility audit enforces nothing, and on 6 of 8 screens it reported "Audit failed to complete in time" and passed anyway.
  - The real-recording harness has `"clips": []`, so all four of its tests skip.
- **Every one of the wave's 26 commits is authored "Claude".** Twelve are "WIP wave 18: in-progress team edits" and 22 skip CI. PR #2 carries +340,605 lines over 258 commits with 0 reviews.

**Bottom line.**
- **Runtime.** It is now a solid, careful app.
- **ADA conversation.** It still wins on the DSP.
- **Due diligence.** It still reads as one generator with no reviewer, and the release machinery isn't green.

---

## 2. Head-to-head on the technical angle

Store facts are from current App Store pages and version trackers (Sources).

### GuitarTuna (Yousician): **split. Timbre wins the ADA column; GuitarTuna wins operational maturity.**
- **Store facts.** v7.103.0 (released 4 days before capture). 295.6 MB, iOS 15+, Mac and visionOS, 11 languages, 4.7★ (20K CA). It tracks Location, Identifiers, Usage Data and Diagnostics.
- **Timbre wins on:**
  - one-strum polyphonic tuning;
  - per-stroke chord grading;
  - 60 instruments, with a 3D peg stage that now rests itself;
  - Watch, Live Activity, widgets and Control Center;
  - zero tracking SDKs, with an opt-out that also stops the Ads attribution request (Analytics.swift:230-231).
- **GuitarTuna wins on:**
  - a tuner proven on hundreds of millions of devices;
  - weekly releases from a team with a green pipeline;
  - Mac and visionOS reach;
  - accounts and sync.
- **Where Timbre stands on evidence.** Its accuracy evidence is still synthetic only (Tests/Fixtures/RealWorld/expected.json:12 `"clips": []`).

### Fender Tune: **Timbre wins clearly**
- **Store facts.** v4.16.2 (2026-04-30), iOS 17.6+. That release's only note is that it "restored the ability to strum" in manual view.
- **Why Timbre wins.** It is ahead on every technical axis: polyphonic reading, strobe, intonation, drone, 3D, platform surface, privacy and persistence safety.
- **Where Fender is ahead.** Its custom tunings sync through a Fender account. Timbre's stay on one device.

### Fender Play: **Timbre wins on in-house technology; Fender wins on infrastructure**
- **Store facts.** v7.4.9, 121.3 MB, iOS 15+ and Mac. It uses MatchMySound, a licensed listening engine. Its labels list contact info and identifiers linked to you.
- **Where Timbre is ahead.** Its recognition, judging and band engine are its own and run fully on-device.
- **Where Fender is ahead.** Fender has accounts, cross-device progress, amp integration and a far smaller binary.

### Yousician: **Yousician wins, narrowly**
- **Store facts.** v5.41.0 (2026-10-13), 313.9 MB, iOS 15+, 4.6★ (139K). Its 2026 major updates were "Lyrics in Play Mode" and "Song Courses for Guitar". It also ships a separate *AI Guitar Teacher* ("June") app: a chat teacher that "listens while you play", on iOS 16.4+, Mac and visionOS.
- **Why Yousician wins.** It has recognition proven at scale across instruments and voice, cross-platform sync, live ops, and now a conversational AI teacher.
- **Where Timbre is ahead.**
  - Strum tuning and per-stroke chord grading on-device.
  - Privacy: Yousician's AI app tracks Identifiers.
  - Apple-platform depth.
  - Its own on-device FoundationModels coach (weak-linked, project.yml:111-115).
- **What would change the call.** A published real-audio accuracy corpus plus iCloud sync.

### Simply Guitar (Simply/JoyTunes): **even. Simply wins on battle-tested recognition and scale; Timbre wins on platform and privacy.**
- **Store facts.** v10.31, 260.4 MB, iOS 15+, 4.7★ (400K). It tracks Identifiers. Linked to you: Contact Info, User Content, Search History, Identifiers, Usage Data, Diagnostics and Other Data.
- **Where Simply is ahead.** Its note and chord recognition has years of real-world tuning that Timbre's `ChordRecognizer` hasn't. Timbre's recognizer knows 8 qualities (ChordRecognizer.swift); the funk unit's E9 and D9 fall back to string-by-string checking.
- **Where Timbre is ahead.** The tuner, 3D, widgets and Watch, privacy, and offline.

### JustinGuitar (Musopia): **Timbre wins**
- **Store facts.** 333.4 MB, English only, iOS 15+. On Mac it says itself it is "Not optimized". It tracks Identifiers.
- **Its own recognition is struggling.** Users reported chord detection broken from April to November 2025. Staff confirmed the "One Minute Chord audio detection issue" on 2025-10-29, and users said it persisted after the update.
- **Why Timbre wins.** It is technically far more ambitious and, by the code, more careful.

**Net.**
- **Innovation and on-device DSP.** Timbre beats all six.
- **Operational maturity.** GuitarTuna, Yousician and Simply still win: proven recognition on real audio, a green release pipeline, sync and review culture.

---

## 3. Everything that costs points, ranked

### 1. Blocker (S–M): the current build cannot pass its own App Store delivery gate, and localization debt grew
- **Where.**
  - `.github/workflows/apple-delivery.yml:88` (`critical.py --strict`).
  - CI `ci-results/core:l10n-critical.log` and `l10n/critical-missing.json`.
  - BillingIssueBanner.swift:66-81 and the paywall's renewal copy.
- **What's wrong.**
  - **Legal (11 strings) in all 48 non-English locales**, including:
    - "Subscriptions renew automatically until cancelled…";
    - "Then %@. It renews automatically until you cancel in Settings.";
    - "Start free trial";
    - "Cancel in 2 taps";
    - every billing-banner string.
  - **Permission (1 string):** `NSAppleMusicUsageDescription`.
  - **VoiceOver (84 strings)**, each missing in all 48 non-English locales.
  - **General debt grew.** App strings rose from 475 to **584**, missing in all 48 locales. Lesson strings rose from 1,126 to **1,408**, missing in 9.
  - **Consequences.** The only App Store path is to translate first or drop locales; `allow_untranslated` is documented as TestFlight-only. Meanwhile a German subscriber in grace period sees the payment banner in English.
  - **Why the PR job didn't catch it.** It reports critical gaps but never fails (ios.yml "report here; apple-delivery.yml enforces"), so new paywall copy landed untranslated.
- **Fix.**
  1. Run `critical.py --strict` in the PR core job, so no legal, permission or VoiceOver string merges without its 48 translations.
  2. Translate the 96 critical strings now (machine translation plus a native-speaker pass for the legal ones).
  3. Either translate the 584 or ship only `en` plus the 9 lesson locales in v2.0, and add the other 39 as they are done.

### 2. Major (M): no green end-to-end CI run for this wave; the gating job is a 60–90 minute screenshot pipeline
- **Where.** ios.yml:91 (`timeout-minutes: 90`), :124-128 (the UI flows), :129-133 (the archive); RUN history via the REST API; HEAD `eb6ee5c` `[skip ci]`.
- **What's wrong.**
  - **Recent run history.**
    - Run 40199381317: app `cancelled` in "Archive unsigned iOS app" (archive.log is 0 bytes).
    - Run 40194852452: core tests `failure` and UI flows `failure`.
    - The two before were `cancelled` and `failure`.
    - The fix was to raise the budget to 90 minutes (e74c390), not to split the job.
  - **Slow serial UI flows.** They take 2,001 s; test06PurchaseUnlocksPro alone takes 513 s. Twelve of the 18 TimbreUITests flows are store or capture scenes.
  - **Unverified HEAD.** 22 of the wave's 26 commits carry `[skip ci]`, and HEAD changes PitchSniperView.swift and Readout.swift unverified.
  - **CI hardening gaps.**
    - `permissions: contents: write` is set workflow-wide (ios.yml:8-9).
    - There is no DerivedData or SPM caching.
    - There is no TSan or ASan, no `xcodebuild analyze`, and no coverage.
- **Fix.**
  1. Make a required "gate" job (<15 min): core tests, app unit tests, 3 smoke UI flows (launch, tune, purchase) and a Release `build` (not archive) with warnings as errors.
  2. Move captures, App Preview, the iPad shelf and the archive to a nightly or `workflow_dispatch` job.
  3. Ban `[skip ci]` on commits that touch `ios/`, with a pre-receive check or branch protection requiring the gate.
  4. Set `contents: write` only on the publish steps' jobs.
  5. Add a nightly TSan job on TimbreAppTests.

### 3. Major (L): the architecture is unchanged and growing — a god object, mixed observation, two modules
- **Where.**
  - Timbre/Services/AppStore.swift: 1,205 lines and 32 `@Published` properties. It still owns:
    - the tuning session (:571-706);
    - voice practice (:992-1049);
    - lesson-microphone arbitration (:764-795);
    - XP, quests, freezes, streak milestones and Today;
    - widget, watch and reminder publishing (:216-236);
    - paywall routing;
    - the metronome and drone;
    - strum mode (:1140-1205).
  - 89 `@EnvironmentObject … AppStore` declarations in 52 files.
  - LessonSteps.swift: 2,323 lines and 73 `@State`. Highway.swift: 2,180 lines.
- **What's wrong.**
  - **Global invalidation from the tuner path.** Every auto-detected string change (`selectedCourse`, AppStore.swift:645) and every chromatic note change (`referenceMidi`, :650) invalidates all 89 observers while the tuner runs.
  - **Half-done migration.** 16 `ObservableObject` types sit beside 3 `@Observable` ones (round 15: 11 to 3).
  - **Partial extraction.** `PlayAlongSession` was extracted to TimbreCore (good), but Highway.swift and SongPerform.swift still share **58 identical 5-line windows** (normalized, comments stripped).
  - **No previews.** There are zero `#Preview` in 144 view files.
- **Fix.**
  - Split into `@Observable` `TunerSession`, `VoiceSession`, `ProgressStore`, `TodayPlan`, `Router` and `SettingsStore`, injected per feature. `LiveReading` already shows the pattern (LiveReading.swift:7-23).
  - Move the shared take UI into one `PlayAlongStage` view.
  - Split SPM targets (`AudioEngine`, `DesignSystem`, `Tuner`, `Learn`, `Paywall`, `Platform`).
  - Add previews for the design-system components.

### 4. Major (M): Swift 6 work hasn't started, and new escape hatches were added
- **Where.**
  - Package.swift:12 `swiftLanguageModes: [.v5]`; project.yml:12 `SWIFT_VERSION: "5.10"`. There is no `SWIFT_STRICT_CONCURRENCY`.
  - 17 `@unchecked Sendable` (13 in round 15) and 5 `nonisolated(unsafe)`. The `nonisolated(unsafe)` is new at Theme.swift:257 (`boldText`).
  - Global mutable statics: Readout.swift:7 `Palette.tuningBand` and ShowMe.swift:38 `ShowMe.lastProblem`.
  - Isolated-state `deinit`s: CommerceService.swift:73 and RecordingPlayer.swift:76.
- **What's wrong.**
  - Round 15's quick wins landed: the DroneSingAlong statics are now computed, and the deprecated aliases are gone. **The build log is now warning-free** (only the 3 SDK deprecations).
  - That means warnings-as-errors and complete concurrency checking on TimbreCore are almost free today, and they still aren't on.
- **Fix.**
  1. `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` this week.
  2. TimbreCore to `.v6`; it is value types plus 5 lock-protected classes.
  3. App target: `SWIFT_STRICT_CONCURRENCY=complete`, then Swift 6 with `defaultIsolation(MainActor)`.
  4. Inject `tuningBand` through the environment; delete `lastProblem` from release.

### 5. Major (M): two of the new quality gates pass without testing
- **The accessibility audit enforces nothing.**
  - AccessibilityAuditUITests.swift:11 sets `enforced = []`, and the `catch` at :122 turns a failed audit into a report line.
  - CI attachments for run 40199381317 show **"The audit did not run: Audit failed to complete in time"** for tab-1-tune, tab-3-songs, tab-4-practice, tab-5-progress, settings and paywall. Only welcome (10 issues) and Learn (9 issues) were audited, and the test is green.
- **The real-recording harness has no recordings.** RealWorldAccuracyTests.swift:92 and :104 skip because Tests/Fixtures/RealWorld/expected.json:12 is `"clips": []`. The harness design is good: per-clip budgets for notes, strums, chords and ring checks.
- **No end-to-end audio path is tested.** The strum UI test injects a hand-written `StrumDemo` reading (StrumModel.swift:198-221). No test pushes audio through `AudioService` → `PitchWorker`/`PolyTuner` → `AppStore.accept` → lock.
- **Smaller gaps.**
  - SwiftLint is report-only, with 1,003 violations and no committed baseline (ios.yml SwiftLint step; `ci-results/core:swiftlint.txt`).
  - The app target has 27 unit tests in 437 lines for 66.5k lines.
  - There is no coverage collection.
- **Fix.**
  1. Make the audit a failure when it cannot run.
  2. Audit with the stage resting: pass a launch flag that pauses `TimelineView`s and RealityKit, then audit.
  3. Enforce `.contrast`, `.hitRegion` and `.sufficientElementDescription` now, and the rest as screens clear.
  4. Add an audio-injection test: an `AudioService` initializer taking an `AVAudioFile` source (manual-rendering engine) that drives synthesized and recorded WAVs through the real capture path to a lock.
  5. Commit the SwiftLint baseline so the step gates.
  6. Add `-enableCodeCoverage YES` with a TimbreCore floor.

### 6. Major (S, verify on device): the remaining audio-session edges
- **UI sounds bypass the session owner** (SoundFX.swift:149-153; PlayAlongCues.swift:134).
  - On first launch, nothing has configured the session, so the welcome motif (OnboardingView.swift:285-293) plays through AVAudioPlayer under the default `.soloAmbient` category. **That category is not mixable: opening Timbre stops the user's music or podcast.**
  - After the tuner has run, the session category stays `.playAndRecord`, so every chime, star and lock bell ignores the Ring/Silent switch.
- **Two observers restart the same capture.** AirPods connecting posts both a route change (AudioService.swift:123-135) and an engine configuration change (:95-103, :320-330). Each stops the capture and starts it again, so the click and drone glitch twice. Whether `setPreferredSampleRate` in `start` triggers a second `.routeConfigurationChange` restart needs a device.
- **Interruption reasons are not filtered.** `.began` is handled without reading `AVAudioSessionInterruptionReasonKey` (`.appWasSuspended`, `.builtInMicMuted`) (:82-94).
- **Lock contention can block the main thread.** `AudioSessionOwner.activate` holds its lock on the main thread while the background deactivation holds the same lock across `setActive(false)` (:811-833, :844-849). A quick stop and restart can block the main thread for the whole hardware wind-down.
- **Battery costs while listening.**
  - The tuner requests 5 ms I/O buffers even when it only listens (:823); 20 ms is enough outside tap-along.
  - One main-actor `Task` is created per reading, about 60 a second (:199).
- **Tune by feel.** It drives a continuous haptic while the microphone listens (Haptics.swift `throb`). Bleed into the pitch detector is only argued in a comment (`beatFloor`); it hasn't been measured.
- **Fix.**
  1. Add a `.interface` user to `AudioSessionOwner` that sets `.ambient` (mixable, honours the silent switch) whenever no engine holds the session, and route SoundFX and PlayAlongCues through it.
  2. Coalesce the route and configuration restarts into one debounced `rebuild()`.
  3. Ignore `.appWasSuspended`.
  4. Never take the owner's lock on the main thread for longer than a flag flip: make activation and deactivation serial on the owner's queue and await them.
  5. Commit a device test sheet (AirPods in and out mid-lesson, a call during the drone, Siri during the tuner, CarPlay) with dated results.

### 7. Minor (M): commit and process hygiene got no better, and the hygiene lint reads as concealment
- **Where.** `git log 7c8d46c..HEAD`; PR #2 (REST: `reviews: 0, comments: 0`); tools/ci/lint_tells.py:2, :101-103.
- **What's wrong.**
  - **The wave since round 15.** 26 commits. All 26 are authored `Claude <noreply@anthropic.com>`, 12 read "WIP wave 18: in-progress team edits", and 22 carry `[skip ci]`. Together they add 21,102 lines across 203 files in one day.
  - **PR #2 (`v2/foundations` → `main`).** 258 commits, +340,605 lines, 1,062 files, zero reviews.
  - **The lint's framing.** It describes itself as blocking "the tells of an unreviewed, generated codebase" and bans the word "Claude" in comments, while git names Claude as the only author. To a buyer that is cosmetics over review. Its comment rules (review and bug numbers) are still worth having.
- **Fix.**
  1. A human reviewer approves every PR, with branch protection on `main`.
  2. Squash the WIP commits on merge.
  3. Rename the lint (`comment_hygiene.py`) and drop the agent-name rule.
  4. Write a short ADR folder for the big decisions (session owner, persistence recovery, curriculum store).

### 8. Minor (S): test hooks still sit in release code
- **Where.**
  - Release-build reads outside `#if DEBUG`: PaywallWinBack.swift:76-80, GameCenter.swift:136-140, LiveActivityController.swift:22-25, PitchSniperView.swift:218 (`seed = 7` under `TIMBRE_DEMO_PITCH`) and InstrumentStage.swift:793.
  - The same five-key "quiet" list is copied in PaywallWinBack, GameCenter, RemoteConfig.swift:97-104 and Analytics.swift:141-145.
- **What's wrong.**
  - 21 product files read the test environment, 8 of those reads outside `#if DEBUG`.
  - 57 product comments explain behaviour by screenshots, UI tests or the simulator; the lint counts 46 as `test-coupling`. Examples: Highway.swift:2172-2173, LessonSteps.swift:1829, AudioService.swift:214.
- **Fix.**
  1. One `TestSupport.isAutomated` behind `#if DEBUG` (a `false` constant in release), read everywhere.
  2. Rewrite the coupled comments in product terms; the lint's note level can become `error` once the count reaches 0.

### 9. Minor (S): dead and speculative state, and a stringly typed domain
- **Dead or speculative settings.**
  - `bandOnSpeaker` (LocalStore.swift:80-82) is new this wave. Its comment describes a voice-processing band-on-speaker feature "after its self-test", but **nothing reads it**; a search finds only a test.
  - `theme`, `skin`, `reducedMotion` and `telemetryEnabled` (LocalStore.swift:6-8, :24-25) are still persisted and never read. The lenient decoder now makes deleting them safe.
- **Strings where enums belong.**
  - `TuningReading.status: String` (TuningTracker.swift:28), switched on in AppStore.swift:363-369 and built at :655;
  - `PracticeRecord.kind`, `notation`, `stageMode` and `goal`;
  - the instrument families in `canStrumTune` (AppStore.swift:1145);
  - `"learn.course"` written 16 times as a raw UserDefaults key.
- **Fix.**
  - Delete the dead fields, or ship the feature.
  - Use `Codable` enums with raw values; the JSON is unchanged.
  - One `Preferences` type for the UserDefaults keys.

### 10. Minor (M): the persistence write path and sync
- **Where.** LocalStore.swift:425-435 (`append`), :456-466 (`persist`), :680-706 (`validate`); AppStore.swift:745 (one `recordProgress` per correct ear answer).
- **What's wrong.**
  - **Write cost.** Each save re-validates up to 2,000 records, copies a backup and rewrites the whole JSON on the main actor. Each staged settings change re-validates them too.
  - **Split storage.** Daily minutes, latency calibration, the band switch and `learn.course` live in UserDefaults, and "Clear practice history" leaves them.
  - **No sync.** There is still no iCloud sync, so the iPhone, the marketed iPad and the Watch keep separate streaks.
- **Fix.**
  1. Validate the delta.
  2. Persist on a serial background actor with a coalesced write.
  3. Add `NSUbiquitousKeyValueStore` for streak and XP, then CloudKit for history.

### 11. Minor (S): launch and failure visibility for the curriculum
- **Where.** TimbreApp.swift:76-85 (`Bootstrap.load` awaits `CurriculumStore.load` before any store exists); CurriculumStore.swift:95-111; AppStore.swift:105 and :110-112.
- **What's wrong.**
  - The curriculum doubled to **8.9 MB** of JSON, and the first real screen waits for its full decode. That is now off the main thread, but there is no launch metric to see what it costs on an iPhone SE.
  - A decode failure leaves an empty Learn in release, with only a DEBUG `assertionFailure` and no analytics event.
  - `Catalog()` (300 KB) still decodes on the main actor.
- **Fix.**
  1. Shard the curriculum per course, or ship a binary plist, decoding the selected course first.
  2. Log `curriculum_failed`.
  3. Add `XCTApplicationLaunchMetric` to the nightly job.

### 12. Minor (S): analytics, remote config and privacy posture
- **Where.** Analytics.swift:273-282 (diagnostics are counts only); LocalStore.swift:26-27 and :247 (sharing on until the player chooses); RemoteConfig.swift:11-13 and :117-122 (rating line); project.yml:101-105.
- **What's wrong.**
  - **MetricKit diagnostics are counts only.** "crashes: 2" can't be fixed; there are no call stacks.
  - **Opt-out default.** An opt-out default with a per-install identifier is a consent question in the EU.
  - **Hand-typed rating.** The paywall's "★ 4.8 · 312 ratings" line is typed into a remote JSON file rather than read from the App Store, so it can drift from the truth.
  - **Every build-time address is empty**: telemetry ID, App Store ID, share URL and remote-config URL. The privacy URL is still `azerish25-ux.github.io`.
- **Fix.**
  1. Upload `MXDiagnosticPayload.jsonRepresentation()` call-stack trees, or adopt a crash SDK.
  2. Show the sharing choice once in onboarding in EU storefronts.
  3. Read the rating from the iTunes Lookup API, or drop the line.
  4. The owner sets the addresses.

### 13. Minor (S): commerce leftovers
- **Family Sharing** is still `false` on all three products (Tests/Fixtures/Timbre.storekit), with no documented decision.
- **Win-back is untested.** The fixture has 0 win-back offers, so the win-back branch of `exitOffer()` (PaywallWinBack.swift:44-62) has never run under test.
- **Fix.** Add a win-back offer to the fixture and a test that a lapsed subscriber gets it. Record the Family Sharing decision in APPLE-DELIVERY.md.

### 14. Minor (S): DSP coverage limits
- **Chord qualities.** `ChordRecognizer` knows 8 qualities. The funk unit's E9 and D9 (14 steps) silently fall back to string-by-string checking (LessonSteps.swift:800, :1157). There is no dim, aug, 6 or add9.
- **Fast strokes blend.** `StrokeChords` reads 60–230 ms after each onset (StrokeChords.swift:19-23), so strokes closer than about 230 ms (sixteenths above about 65 BPM) blend into the next stroke.
- **Fix.**
  - Add 9, 6, add9, dim and aug templates with tests.
  - Shorten the frame when the next onset is near (a 4096-sample frame at 48 kHz is already supported by the recognizer).
  - Grade only on-beat strokes on fast patterns.

### 15. Minor (S): API shadowing in the localization layer
- **Where.** Timbre/Localization.swift:10-20.
- **What's wrong.** A module-level `NSLocalizedString` and a `String.init(localized:comment:)` overload silently replace Foundation's. A new engineer's `String(localized:)` behaves differently in this module. The tables are still legacy `.strings`.
- **Fix.** Migrate to `.xcstrings` and call `String(localized:bundle: .app)` explicitly, with a `Bundle.app` accessor, instead of shadowing.

---

## 4. How to take #1 on the technical angle (ranked by impact)

1. **Make it shippable and provably green.**
   - Run the critical-strings check strict on every PR, and translate the 96 critical strings, or trim the locales.
   - Split CI into a required gate under 15 minutes plus a nightly capture job.
   - Ban `[skip ci]` on `ios/`, and require a green gate run with the archive before any merge to `main`.

   A buyer's first question is "show me the last green release build". Today there isn't one for this wave.
2. **Prove the DSP on real audio, end to end, and publish the numbers.**
   - Fill `Tests/Fixtures/RealWorld` with 100–300 labelled clips across phones, microphones, rooms and instruments, and gate the budgets already written in `expected.json`.
   - Add an audio-injection path so UI and unit tests drive real WAVs through `AudioService` to a lock and a strum verdict.
   - Put "measured on N real recordings: median 0.4 ¢, all six strings in 0.85 s" on the listing.

   None of the six competitors can say that, and JustinGuitar's users have spent half a year reporting broken chord detection.
3. **Re-architect for a team.**
   - `AppStore` becomes `@Observable` feature models.
   - SPM modules.
   - TimbreCore on Swift 6 now; the app on strict concurrency next.
   - Warnings as errors; the build is already clean, so it is free.
   - Previews for the design system.
4. **Make every gate real.**
   - The accessibility audit fails when it can't run, and enforces kinds as they clear.
   - The SwiftLint baseline is committed so the step gates.
   - A coverage floor on TimbreCore.
   - Launch and energy metrics nightly.
5. **Finish audio on hardware.**
   - UI sounds through the owner as `.ambient`, so Timbre never stops the user's music and respects the silent switch.
   - Debounce the route and configuration restarts.
   - A committed device test sheet.
   - Measure Tune by feel's bleed into the microphone.
6. **Account-free iCloud sync** of streak, XP and lessons across iPhone, iPad and Watch. It closes the gap with Yousician and Fender Play on privacy terms Apple editorial likes.
7. **Process a buyer can trust.**
   - A human senior reviewer approving PRs.
   - Squash-merged waves.
   - ADRs.
   - A test-hook layer that compiles to nothing in release.

---

## 5. What only the owner can do
- **Languages.** Commission translations of the 96 critical strings and the 584 app strings, or decide which locales v2.0 ships.
- **Recordings.** Players and devices to record the real-audio corpus: guitar, bass, ukulele and violin; iPhone SE to 17 Pro; built-in microphone and AirPods; quiet room and café. Ground truth comes from a reference tuner.
- **App Store Connect.**
  - Turn on Billing Grace Period; the code is ready.
  - Configure win-back offers and offer codes.
  - Make the Family Sharing decision.
  - Set `TIMBRE_APP_STORE_ID`.
- **Accounts and hosting.**
  - A TelemetryDeck account (`TELEMETRYDECK_APP_ID`).
  - A domain for the privacy policy, share page and remote-config file (`TIMBRE_*_URL`).
  - A crash-reporting decision.
- **Devices and CI money.** A device lab (SE, a mid-range iPhone, a Pro, an iPad, AirPods, a wired headset, a Watch) and macOS CI minutes. The gating job costs 60–90 runner-minutes per push today.
- **People.** An independent senior iOS engineer to own PR review and sign off on the Swift 6 and architecture migration. PR #2 has 0 reviews across 340k lines.
- **Repository settings.** Branch protection on `main` that requires the gate job.

---

## 6. Sources
- [GuitarTuna on the App Store (CA)](https://apps.apple.com/ca/app/guitartuna-tune-play-guitar/id527588389): v7.103.0, 295.6 MB, iOS 15+, Mac and visionOS, 11 languages, tracking labels, IAP prices.
- [Yousician version tracker (AppsHunter)](https://appshunter.io/ios/app/yousician/id959883039): v5.41.0 (Oct 13, 2026), 313.9 MB, iOS 15+, 4.6★ (139K), 2026 major updates.
- [AI Guitar Teacher by Yousician on the App Store](https://apps.apple.com/us/app/-/id1640426327): the "June" AI teacher, real-time feedback, iOS 16.4+, Mac and visionOS, tracks Identifiers.
- [Fender Tune version history (Appaloosa Scout)](https://scout.appaloosa.io/en/apps/ios/com.fenderDigital.TuneAndTone/history): v4.16.2 (2026-04-30), iOS 17.6, "restored the ability to strum".
- [Fender Play on the App Store](https://apps.apple.com/app/id1226057939): v7.4.9, 121.3 MB, iOS 15+, Mac, MatchMySound, privacy labels.
- [Simply Guitar on the App Store](https://apps.apple.com/app/id1476695335): v10.31, 260.4 MB, iOS 15+, 4.7★ (400K), tracking and linked-data labels.
- [Justin Guitar Lessons & Songs on the App Store](https://apps.apple.com/US/app/id1176125504): 333.4 MB, English only, Mac "Not optimized", tracking labels.
- [JustinGuitar Community: "Chord detection issues"](https://community.justinguitar.com/t/chord-detection-issues/397102): reports from April to November 2025; staff confirmed the "One Minute Chord audio detection issue" on 2025-10-29.
- GitHub REST API for azerish25-ux/tuner (`/pulls`, `/pulls/2/reviews`, `/actions/runs`, `/actions/runs/{id}/jobs`), queried 2026-10-25 at 15:20–15:24 UTC: PR #2 statistics, CI run outcomes and step results.

## Method notes
- **Sizes.** `find … | xargs wc -l` gives the app 66,524 lines in 144 files, the core 14,032 in 53, and tests 7,746 (core) + 437 (app unit) + 2,131 (UI).
- **Counts.**
  - 89 `@EnvironmentObject.*AppStore` declarations in 52 files.
  - 16 `ObservableObject` types and 3 `@Observable`.
  - 17 `@unchecked Sendable` and 5 `nonisolated(unsafe)`.
  - 0 `#Preview`.
  - 301 `String(localized:)` calls without a bundle (all routed through the module shadow).
  - Environment-hook reads outside `#if DEBUG` were found with a preprocessor-aware Python scan.
  - Duplication is identical 5-line windows after stripping blank lines and comments.
- **CI evidence.** `git fetch --force` of `ci-results/{core,app,ipad}`: core at 51e7651 (run 40204220703), app and iPad at 348d82f (run 40199381317). The accessibility-audit outcomes come from that run's `.txt` attachments. The current run's app job (e74c390) had not finished at 15:24 UTC.
- **Needs a device.**
  - Item 6: the welcome motif stopping background music, the double restart on AirPods, the silent-switch behaviour after tuning, and haptic bleed.
  - Item 11: the decode cost on older phones.
