# Timbre for iOS: testing and CI

Every test suite, every workflow and every gate, and how to read their results. Paths are from the repository root.
The code layout these tests exercise is in [ARCHITECTURE.md](ARCHITECTURE.md); the scripts are listed in
[TOOLS.md](TOOLS.md). Checked against the workflows and tests at the commit this file was added in.

## Contents

1. [Overview](#1-overview)
2. [Test suites](#2-test-suites)
3. [Workflows](#3-workflows)
4. [The required `gate`](#4-the-required-gate)
5. [Results branches (`ci-results/*`)](#5-results-branches-ci-results)
6. [Lint and hygiene tools (`tools/ci`)](#6-lint-and-hygiene-tools-toolsci)
7. [Localization gates](#7-localization-gates)
8. [Running things locally](#8-running-things-locally)
9. [Known CI flakiness and how it is handled](#9-known-ci-flakiness-and-how-it-is-handled)
10. [Changing a gate](#10-changing-a-gate)

---

## 1. Overview

| Suite | Where | Tests | Runs in CI |
|---|---|---:|---|
| `TimbreCoreTests` (SwiftPM) | `ios/Tests/TimbreCoreTests` | 463 | `ios.yml` core (with coverage); `nightly.yml` tsan (thread sanitizer); `apple-delivery.yml` before signing |
| `TimbreAppTests` (unit tests hosted in the app) | `ios/TimbreAppTests` | 47 | `ios.yml` app |
| `TimbreUITests` (XCUITest) | `ios/TimbreUITests` | 41 | Split across `ios.yml` app and accessibility, `nightly.yml` tour, ipad and a11y-matrix, and `preview.yml` (§2.3) |
| Python hygiene tests | `tools/ci/test_hygiene.py` | 25 | `ios.yml` core |
| Resource and string checks | `tools/verify-ios-resources.py`, `tools/l10n/report.py`, `critical.py` | n/a | `ios.yml` core, `apple-delivery.yml` |

`tools/curriculum/build.py --check` is **not** run by any workflow. The curriculum is guarded in CI only through the
Swift tests that read the built `curriculum.json` (`LearnTests`, `SongArrangementTests`, `SongbookEditionTests`,
`CurriculumIndexTests`, `PlacementTests`) and through the handoff check, which fails when `Learn.strings` changed
without `report.py` being re-run. Run `build.py --check` yourself before committing lesson changes.

Seven workflows live in `.github/workflows/`:

| Workflow | File | Triggers | Purpose |
|---|---|---|---|
| iOS | `ios.yml` | push to `main`, every pull request, manual | The pull-request gate |
| Nightly and captures | `nightly.yml` | 03:17 UTC daily, manual, pull requests labelled `captures` (and `accessibility` for the matrix) | Full UI tour and store captures, iPad, accessibility matrix, thread sanitizer, unsigned archive |
| Apple delivery | `apple-delivery.yml` | manual only, with confirmation | Sign and upload to App Store Connect |
| App Preview | `preview.yml` | manual, push to `preview/**` | Record and cut the App Store App Previews |
| Render instrument cards | `cards.yml` | manual, push to `cards/**` | Studio card renders with RealityKit |
| 3D assets | `assets.yml` | manual, push to `assets/**` touching `tools/models/**` | Blender model pipeline |
| Localization export | `l10n.yml` | manual, push to `l10n/**` | Xcode's string export and the handoff checks against it |

All macOS jobs run on `macos-15` with `DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer`. Results are
uploaded as artifacts and also published to `ci-results/*` branches (§5), which can be read with plain `git`.

## 2. Test suites

### 2.1 TimbreCoreTests

Package test target in `ios/Package.swift`; run with `swift test --package-path ios`. Pure logic, no simulator.
Synthesized audio comes from `SynthesizedSignals.swift` (a deterministic LCG, so signals are identical on every run).
Bundled resources (catalogue, curriculum, samples) are read for real, so the tests also guard the shipped content.

| File | Tests | Covers |
|---|---:|---|
| `AccessPolicyTests.swift` | 10 | Pro from entitlements (any expiry date, test arms, revoked/unknown), free tunings, the placement pass, remote openings, the Free/Pro table (`PlanComparison`) matching the policy |
| `BandGrooveTests.swift` | 15 | Originals' band styles, recognising a song from its cues, every style's bar stays inside its meter |
| `CatalogTests.swift` | 5 | Catalogue size and defaults, preset tunings, 12-string octave partners, reference mode, temperaments |
| `ChordLibraryTests.swift` | 9 | Curated guitar shapes spell their chords, ordering, shifted tunings, fingering, scale intervals, tuning-quest counter |
| `ChordRecognizerTests.swift` | 16 | Open chords at both sample rates, barre and power chords, every root and quality, robustness bench, lesson matching |
| `CoachNotesTests.swift` | 18 | Which coach note leads and what it says |
| `CoachTimingTests.swift` | 10 | Late chord changes in strummed and play-along takes |
| `CourseGroupTests.swift` | 4 | Unison pairs share a chip, octave partners don't, a pair locks once both strings have |
| `CurriculumIndexTests.swift` | 11 | Lesson indexes, songbook ordering, unlocking, lookups match a scan |
| `CurriculumStoreTests.swift` | 4 | Decode once, decode on demand, failure leaves an empty curriculum |
| `DSPTests.swift` | 11 | YIN accuracy across range and rates, rejecting silence and noise, octave errors, FFT/autocorrelation |
| `HistoryRollUpTests.swift` | 4 | History roll-up keeps streaks and minutes; staged settings wait for a flush |
| `LearnTests.swift` | 27 | Curriculum consistency and JSON round trip, play-along grading, combos, tempo ladder, star caps and XP, latency calibration, weak spots, note sequences, unlocking and placement, strum takes (chops, accents, chords), spoken-cue timing (`CuePlan`) |
| `NotationTests.swift` | 20 | Key signatures, spelling, clefs, quantizing, beaming, layout |
| `NoteNamesTests.swift` | 16 | German H/B, every naming system, chord symbols, spoken names |
| `OnsetDetectorTests.swift` | 14 | Onsets of clicks, plucks, strums, sixteenths, noise floors; `RhythmJudge` |
| `OutputAudioTests.swift` | 5 | Reference tone harmonics and envelope, metronome pulses on sample time |
| `PersistenceTests.swift` | 21 | `LocalStore`: reopen, failed writes, invalid updates, clearing history, lenient decoding, backup and quarantine, the `state-v1-2026-10.json` fixture |
| `PhotoSelectionTests.swift` | 4 | Photo choice per instrument and tuning |
| `PlacementTests.swift` | 14 | Placement per course and the 45-second check |
| `PlayAlongSessionTests.swift` | 13 | Take clock and count-in, multiplier, broken runs, sections, spoken-cue timing |
| `PolyTunerTests.swift` | 15 | Strum to tune on synthetic strums (guitar, bass, re-entrant ukulele, muted strings) |
| `PracticeAnalyticsTests.swift` | 6 | 7-day activity, 14-day comparisons, time zones |
| `PracticeTests.swift` | 20 | Chord finder, scale map, ear sessions, streaks and freezes, Today, custom tunings (`CustomTuningTests`) |
| `ProgressionTests.swift` | 20 | Levels, daily quests, XP and badges, `tunedToday`; Bullseye (`PitchSniperTests`) |
| `RealWorldAccuracyTests.swift` | 6 | Real recordings against budgets in `ios/Tests/Fixtures/RealWorld/expected.json`; skips while `clips` is empty (it is empty today) |
| `SampledTonesTests.swift` | 13 | The bundled sample library: coverage, lazy decoding, exact pitch, loops |
| `ShowMeMemoryTests.swift` | 5 | "Show me" plays by itself once per course |
| `SongArrangementTests.swift` | 11 | Every song is a whole arrangement of 90–180 s, sections, charts, lyrics |
| `SongOfTheDayTests.swift` | 17 | The featured song's choice |
| `SongbookEditionTests.swift` | 5 | Free first-unit songs, ukulele editions, cello and bass songbooks, muted strokes |
| `SpacedReviewTests.swift` | 12 | SM-2 schedule and sessions |
| `StreakCacheTests.swift` | 5 | Streak cache invalidation |
| `StrokeChordsTests.swift` | 7 | Stroke chord, attack and ring through the live path (`AudioClip` → `LessonListening` → `StrokeChords` → `StrumTake`) |
| `TargetLabelTests.swift` | 2 | String label formatting |
| `ToneSynthTests.swift` | 10 | Every voice renders finite, bounded audio at exact pitch |
| `TuningTests.swift` | 13 | 650 ms hold, gaps, confidence, cadence, analysis window |
| `VoiceTests.swift` | 12 | The eight exercises and their scoring |
| `YourSongs/ChartPlaybackTests.swift` | 6 | Transpose and capo, capo advice, timelines, tap-along, practice plan, free vs Pro |
| `YourSongs/ChordProTests.swift` | 12 | Lenient ChordPro parsing and import |
| `YourSongs/ChordSymbolTests.swift` | 6 | Chord symbol parsing, spelling, key guessing |
| `YourSongs/RecordingAnalysisTests.swift` | 5 | Tempo, beats, chords per bar, draft chart |
| `YourSongs/UserSongLibraryTests.swift` | 4 | Save, load, damaged files, audio import |

Fixtures (`ios/Tests/Fixtures/`): `Timbre.storekit` (the StoreKit test configuration, also the app scheme's run
configuration), `state-v1-2026-10.json` (a saved state from October 2026), `RealWorld/expected.json` (accuracy budgets
and the clip list for the owner's recordings).

### 2.2 TimbreAppTests

A unit-test bundle hosted in the app (`TEST_HOST` in `ios/project.yml`), so it can `@testable import Timbre` and
exercise `AppStore`, `CommerceService` and `AudioService` helpers on a simulator.

| File | Tests | Covers |
|---|---:|---|
| `AppStoreIntegrationTests.swift` | 15 | A real `AppStore` on a temporary directory: free and Pro tunings, an unreadable saved file opens fresh, the guitar's 3D rig anchors, which settings restart listening, metronome and drone settings persist, `updateSettingsSoon` batching and flushing, staged settings riding along with a record, lock rewards in the next batch, sessions saving and counting for the streak, automatic string following, Today |
| `CommerceIntegrationTests.swift` | 14 | `CommerceService` against `SKTestSession` (`Timbre.storekit`, run serially): product order and trials, trial eligibility, remote yearly arms, Pro from annual, arms and lifetime, expiry, refund, a fresh service finding a purchase, grace period, billing retry, Ask to Buy |
| `CommercePlanTests.swift` | 3 | The paywall plan's first song and pace |
| `LocalizationTests.swift` | 2 | Strings built in code follow a picked language; every setting resolves to a language the app has |
| `MicStartRetryTests.swift` | 5 | Which microphone start failures get one more try |
| `TunerFrameHookTests.swift` | 3 | Every tuner reading reaches `onTunerFrame`; lessons take readings themselves |
| `TunerSessionTests.swift` | 5 | Automatic detection, completing a tune once, when a session is worth a record, chromatic range, observation isolation |
| `StoreKitTestEnvironment.swift` | – | Helpers that wait for StoreKit test transactions to reach `currentEntitlements` |

### 2.3 TimbreUITests

Every UI test launches the app with its own storage (`TIMBRE_TEST_STORAGE_ID`, a UUID) so tests never share state.
Launch keys are listed in [ARCHITECTURE.md §14](ARCHITECTURE.md#14-test-hooks).

| Class (file) | Tests | What it does | Run by |
|---|---:|---|---|
| `SmokeUITests` (`SmokeUITests.swift`) | 3 | A fresh install opens on the welcome; the tuner hears the demo pitch and locks a string; buying Pro (StoreKit test) unlocks a Pro tool | `ios.yml` app |
| `LaunchPerformanceUITests` (`SmokeUITests.swift`) | 1 | `XCTApplicationLaunchMetric` on a cold launch | `nightly.yml` tour |
| `AccessibilityAuditUITests` | 5 | Xcode's accessibility audit on the welcome, every tab, Settings and the paywall, lesson steps, the metronome. Enforced kinds: contrast, hit region, element description, traits; pre-existing issues listed in `known`; an audit that can't run fails; up to 3 attempts per audit; launched with `TIMBRE_STAGE_REST=1` | `ios.yml` accessibility |
| `LocalizationLaunchUITests` | 5 | A German device reads German (welcome and tabs); an Arabic device runs right to left with note names left to right; no welcome or tuner text bypasses the string tables | `ios.yml` accessibility |
| `TimbreUITests` | 21 | The full tour (`test01Onboarding` … `test21StoreUkuleleStage`): every screen captured for review, plus the App Store frames (`test11`–`test21`, most launched into a capture scene); a purchase; lessons; stage diagnostics. Language from `TEST_RUNNER_TIMBRE_UI_LANGUAGE`/`_LOCALE` | `nightly.yml` tour |
| `TabletScreenshotsUITests` | 1 | 13-inch iPad captures in portrait and landscape | `nightly.yml` ipad |
| `AccessibilityMatrixUITests` | 1 | The screens that break first under one setting per run (`TEST_RUNNER_TIMBRE_MATRIX`: `baseline`, `ax5`, `bold`, `contrast`, `lefty`, `upside`, `ar`), captured and audited; an unreachable screen fails | `nightly.yml` a11y-matrix |
| `AppPreviewUITests` | 2 | `testAppPreview` (guitar) and `testAppPreviewViolin`: tours of capture scenes marked with `PREVIEW-*` log lines for `tools/marketing/preview.py` | `preview.yml` |
| `FirstSessionUITests` | 2 | The paywall from Settings shows its plan cards; "Just tune" reaches a listening tuner | **No workflow** (run it by hand) |
| `StillScreen.swift` | – | Waits for the screen to come to rest by comparing screenshot thumbnails, instead of fixed sleeps | helper |

UI tests that need products load `Timbre.storekit` themselves with `SKTestSession(configurationFileNamed: "Timbre")`:
`TimbreUITests` in `setUp` (reset to the default state, transactions cleared, dialogs off) and
`SmokeUITests.testBuyingProUnlocksAProTool` in the test.

### 2.4 Python tests

`python3 tools/ci/test_hygiene.py` runs 25 `unittest` tests of the Swift comment lexer (`swift_source.py`), the hygiene
lint and the comment sweep.

## 3. Workflows

### 3.1 `ios.yml` (iOS): the pull-request gate

- **Triggers:** `push` to `main`; every `pull_request` (no path filter, so a docs-only PR still reports the required
  check); `workflow_dispatch`.
- **Concurrency:** `ios-native-${{ github.ref }}`, cancel in progress.
- **Permissions:** `contents: read`; only `publish` has `contents: write`.

| Job | Runner | Timeout | Steps | Artifact |
|---|---|---:|---|---|
| `core` | macos-15 | 15 min | Full-history blobless checkout; on PRs `tools/ci/skip_ci_guard.py`; `swift test --package-path ios --parallel --enable-code-coverage`; `tools/ci/coverage.py`; then, each even if an earlier one failed: `build_warnings.py` on the core log, `verify-ios-resources.py`, `l10n/report.py --check --strict --out ci-out/l10n`, `l10n/critical.py --baseline --github --out ci-out/l10n`, `test_hygiene.py` and `comment_hygiene.py --github`, SwiftLint against the baseline (6-minute step timeout); `summarize-log.py` | `results-core` (7 days) |
| `app` | macos-15 | 25 min | Check the iOS SDK is 26+; `xcodegen generate`; pick the newest iPhone simulator and boot it; `ensure-metal.sh`; restore the module cache (key = hash of `project.yml` + `Package.swift`); `xcodebuild build-for-testing` (Debug, simulator, no signing, no index store); `build_warnings.py`; grant the microphone; `xcodebuild test-without-building -only-testing:TimbreAppTests -only-testing:TimbreUITests/SmokeUITests` into `Gate.xcresult`; export attachments, summarize and gzip logs | `results-app` (7 days); `gate-xcresult` on failure (7 days) |
| `release` | macos-15 | 25 min | `xcodegen generate`; `ensure-metal.sh`; `xcodebuild build -configuration Release -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO`; `build_warnings.py` | `results-release` (7 days) |
| `accessibility` | macos-15 | 55 min | Build for testing (tail of the log kept); grant the microphone; one warm-up launch (up to 3 tries of 2 minutes, with `TIMBRE_STAGE_REST`, `TIMBRE_SKIP_ONBOARDING`, `TIMBRE_DEMO_DATA`); run `AccessibilityAuditUITests` and `LocalizationLaunchUITests`; on failure, `launch_retry.py` picks tests that failed only at launch and runs them once more (any other failure stands) | `results-accessibility` (7 days) |
| `gate` | ubuntu-latest | 5 min | `if: always()`, `needs: [core, app, release]`; fails unless every one of them is `success` (skipped or cancelled fail it too) | – |
| `publish` | ubuntu-latest | 10 min | `if: always()` and not a fork PR; `needs: [core, app, release, accessibility]`; downloads `results-*` and runs `tools/ci/publish-results.sh` for `core`→`ci-results/core`, `app`→`ci-results/gate`, `release`→`ci-results/release`, `accessibility`→`ci-results/accessibility` | – |

Compiler warnings are treated as errors by the log gate (`build_warnings.py`), not by `SWIFT_TREAT_WARNINGS_AS_ERRORS`
(see §6.2). The `accessibility` job is outside `gate` but its failure makes the workflow run red.

### 3.2 `nightly.yml` (Nightly and captures)

- **Triggers:** `schedule` `17 3 * * *` (03:17 UTC, on the default branch), `workflow_dispatch`, and `pull_request`
  events `labeled`, `opened`, `reopened`, `synchronize`. On a pull request a job runs only when the PR carries the
  label `captures` (every push re-runs while the label is on); `a11y-matrix` also runs for the label `accessibility`;
  `tsan` never runs on pull requests.
- **Concurrency:** `nightly-${{ github.ref }}`, cancel in progress.

| Job | Timeout | What it runs | Artifacts (14 days) | Published to |
|---|---:|---|---|---|
| `tour` | 90 min | Build for testing; boot the iPhone; status bar 9:41, full battery and signal; `-only-testing:TimbreUITests/TimbreUITests -only-testing:TimbreUITests/LaunchPerformanceUITests` into `UITests.xcresult`; `xcodebuild archive` unsigned (`Timbre.xcarchive`); export attachments | `results-tour`, `ios-evidence` (xcresult and archive) | `ci-results/app` |
| `ipad` | 45 min | Newest 13-inch iPad simulator; switch it to Full Screen Apps (SpringBoard defaults `SBMedusaMultitaskingEnabled`, `SBChamoisWindowingEnabled` = 0, reboot; falls back to the default mode with a warning if apps don't launch); 9:41 status bar; `xcodebuild test -only-testing:TimbreUITests/TabletScreenshotsUITests`; one reboot-and-retry if the runner "failed to initialize for UI testing" | `results-ipad`, `ipad-evidence` | `ci-results/ipad` |
| `a11y-matrix` | 75 min | Build for testing; for each variant `baseline ax5 bold contrast lefty upside ar`: set the simulator setting where it is a system setting (Increase Contrast with `simctl ui`, Bold Text with a defaults write), run `AccessibilityMatrixUITests` with `TEST_RUNNER_TIMBRE_MATRIX=<variant>` into `Matrix-<variant>.xcresult`, reset the setting; fail if any variant failed | `results-a11y-matrix` | `ci-results/a11y-matrix` |
| `tsan` | 30 min | `swift test --package-path ios --sanitize=thread` | `results-tsan` | `ci-results/tsan` |
| `publish` | 10 min | Not on fork PRs and only when at least one job ran; maps `tour`→`app`, `ipad`→`ipad`, `a11y-matrix`→`a11y-matrix`, `tsan`→`tsan` | – | – |

To get captures for a pull request, add the `captures` label; remove it to stop the extra runs.

### 3.3 `apple-delivery.yml` (Apple delivery)

Manual only, never before the owner authorizes delivery. Inputs: `marketing_version` (default `2.0.0`),
`build_number`, `confirm_delivery` (must be ticked, else the job is skipped), `internal_testflight_untranslated`,
`ship_min_coverage`. Job `deliver` on macos-15, 60 minutes, environment `apple-delivery` (secrets `APPLE_TEAM_ID`,
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8`; variables
`TELEMETRYDECK_APP_ID`, `TIMBRE_APP_STORE_ID`, `TIMBRE_SHARE_URL`, `TIMBRE_REMOTE_CONFIG_URL`). Concurrency group
`apple-delivery`, never cancelled. Steps:

1. Validate inputs and secret formats without printing them; check the iOS SDK is 26+.
2. `swift test --package-path ios --parallel` and `python3 tools/verify-ios-resources.py`.
3. With `ship_min_coverage`: `tools/l10n/shipping.py --min <n> --apply` on this checkout only.
4. `tools/l10n/critical.py --strict --github` (no gap allowed), unless `internal_testflight_untranslated`, which only
   reports and stamps the build `TimbreBuildChannel=internal` and exports it with `testFlightInternalTestingOnly`.
5. `xcodegen generate`; write the API key and `ExportOptions.plist` (`app-store-connect`, `upload`, automatic signing,
   symbols uploaded) into `$RUNNER_TEMP`.
6. `ensure-metal.sh`; `xcodebuild archive` Release with automatic signing and the API key, passing the version, build
   number, channel and the Info.plist build settings.
7. `xcodebuild -exportArchive` uploads to App Store Connect. The key is removed in an `always()` step.

The owner's instructions are in [ios/APPLE-DELIVERY.md](ios/APPLE-DELIVERY.md) §3.

### 3.4 `preview.yml` (App Preview)

Manual (inputs `preview`: `both`/`guitar`/`violin`; `sync_offset` seconds; `reanchor`) or push to `preview/**`. A
matrix over the cuts (`fail-fast: false`), macos-15, 90 minutes. Installs XcodeGen, ffmpeg and a venv with Pillow and
fontTools; `preview.py device` picks a 6.9-inch iPhone; builds for testing; then up to three takes: start
`preview.py record` in the background (waits on a handshake folder passed as `TEST_RUNNER_PREVIEW_HANDSHAKE`), run
`AppPreviewUITests/testAppPreview` or `testAppPreviewViolin`, `preview.py stop`, export attachments, copy what the app
wrote it played (`handshake/app`, or the app container's `Caches/preview-audio`), then `preview.py render`. A take that
lost the app (exit 3) or missed a moment (exit 4) is recorded again; "failed to initialize for UI testing" reboots and
retries. Publishes `preview.mp4`, `poster.png`, `contact.png`, `PREVIEW.txt`, `cut.json`, `sync.png`, `raw-small.mp4`,
`record.log`, the clip marks and log summaries to `ci-results/preview` (guitar) or `ci-results/preview-violin`; the raw
recording and the app's sound are in the artifact `preview-recording-<cut>` (7 days).

### 3.5 `cards.yml` (Render instrument cards)

Manual or push to `cards/**`; macos-15, 40 minutes. Compiles `tools/models/render_cards.swift` with `swiftc` for
macOS 15, renders every model's card variants from `ios/Timbre/Resources/Models` into `build/cards`, fetches the latest
live-stage captures from `ci-results/app` (`git archive FETCH_HEAD screenshots`), builds review sheets with
`tools/models/cards.py sheet`, and publishes `build/cards` to `ci-results/cards`. Install a variant with
`tools/models/cards.py install` ([TOOLS.md](TOOLS.md)).

### 3.6 `assets.yml` (3D assets)

Manual (input `models`, comma-separated ids) or push to `assets/**` touching `tools/models/**` or the workflow;
ubuntu-24.04, 60 minutes; `contents: write`. Downloads the newest Blender 4.5 LTS tarball (cached), installs Pillow,
NumPy and SciPy, runs `tools/models/textures.py`, then
`blender -b --factory-startup --python-exit-code 1 --python tools/models/build_assets.py -- --out build/assets --models … --samples 64 --res 1024`,
then `tools/models/postprocess.py build/assets`, and publishes `build/assets` to `ci-results/assets`.

### 3.7 `l10n.yml` (Localization export)

Manual or push to `l10n/**`; macos-15, 20 minutes. `xcodebuild -exportLocalizations -exportLanguage en`
(`SWIFT_EMIT_LOC_STRINGS=YES`) into `ci-out/l10n`, copies the `.xliff` to `ci-out/`, then (allowed to fail)
`report.py --check --xliff <en.xliff> --out ci-out/handoff` and `critical.py --xliff <en.xliff> --out ci-out`.
Publishes `ci-out` to `ci-results/l10n`. Use its `en.xliff` to settle format specifiers the Swift scanner only guessed
([l10n/HANDOFF.md](l10n/HANDOFF.md)).

## 4. The required `gate`

`gate` in `ios.yml` is the one check branch protection requires (per the workflow's header comment; the protection rule
itself is a GitHub setting, not in the repository). It passes only when `core`, `app` and `release` all succeed. The
three run in parallel; the target is under 15 minutes each (the `core` timeout is 15 minutes, `app` and `release` 25).

Consequences:

- A cancelled or skipped gate job fails `gate`. A newer push cancels the running workflow for the same ref
  (`cancel-in-progress`), so only the newest commit's run counts.
- GitHub runs no workflow for a commit whose message contains `[skip ci]` (or the other skip forms), so a pull request
  whose newest commit skips CI never gets a `gate` result and cannot merge. `skip_ci_guard.py` additionally fails `core`
  when any earlier commit in the PR that touches `ios/` skips CI or starts with "WIP" (§6.5).
- `accessibility` can turn the run red without blocking `gate`.

## 5. Results branches (`ci-results/*`)

`tools/ci/publish-results.sh BRANCH DIR [JOB]` publishes a folder as a single orphan commit, force-pushed, so each
branch holds only the latest run and its history never grows. Only the `publish` jobs (and the single-job workflows
`assets`, `cards`, `l10n`, `preview`) have write access.

**Naming.** Runs on `main` or `v2/foundations` (for a pull request, its head branch) publish to the base name. Any other
ref adds a suffix: `ci-results/core--<ref with / replaced by ->`, e.g. a PR from `feature/x` publishes to
`ci-results/core--feature-x`. A push to `cards/foo` publishes to `ci-results/cards--cards-foo`.

**Every branch** has `RUN.txt` (`sha`, `ref`, `run`, `job`, `date`). Files over 45 MB are left out and listed in
`SKIPPED.txt`. If the push fails three times (with 5, 10 and 15 s back-off), a logs-only commit is pushed with
`PUSH-FAILED.txt`. Always compare `RUN.txt`'s `sha` with the commit you are checking.

| Branch | Producer | Main contents |
|---|---|---|
| `ci-results/core` | `ios.yml` core | `core.log`, `core.summary.txt`, `coverage.log`, `skip-ci.log`, `resources.log`, `l10n.log`, `l10n-critical.log`, `l10n/` (fresh TODO files, `HANDOFF.md`, `pending.json`, `critical-missing.json`), `hygiene-tests.log`, `hygiene.log`, `swiftlint.txt`, `swiftlint-baseline.json` (a fresh baseline candidate), `warnings-core/warnings.json`, `warnings-core/concurrency-by-file.json` |
| `ci-results/gate` | `ios.yml` app | `build.log.gz`, `test.log.gz`, their `.summary.txt`, `warnings-app/`, `screenshots/` (attachments with `manifest.json`) |
| `ci-results/release` | `ios.yml` release | `release.log.gz`, `release.summary.txt`, `warnings-release/` |
| `ci-results/accessibility` | `ios.yml` accessibility | `build-tail.log`, `test.log.gz`, `test-relaunch.log.gz`, `relaunch.txt`, summaries, `screenshots/`, `screenshots-relaunch/` (audit reports `ax-audit-<screen>` beside screenshots) |
| `ci-results/app` | `nightly.yml` tour | `build.log.gz`, `test.log.gz`, summaries, `archive.log`, `screenshots/` (the tour and store captures; names in `screenshots/manifest.json`) |
| `ci-results/ipad` | `nightly.yml` ipad | `ipad-test.log.gz`, summary, `ipad-screenshots/` |
| `ci-results/a11y-matrix` | `nightly.yml` a11y-matrix | `matrix-<variant>.log.gz`, `Matrix-<variant>/` attachments |
| `ci-results/tsan` | `nightly.yml` tsan | `tsan.log.gz`, `tsan.summary.txt` |
| `ci-results/preview`, `ci-results/preview-violin` | `preview.yml` | The cut and its evidence (§3.4) |
| `ci-results/cards` | `cards.yml` | `cards/<variant>/render_<model>.png`, `closeups/`, `RENDER.txt`, review sheets, logs |
| `ci-results/assets` | `assets.yml` | usdz, rigs, renders, `manifest.json`, `blender.log`, contact sheet |
| `ci-results/l10n` | `l10n.yml` | `en.xliff`, `export.log`, `handoff/`, `report.log`, `critical.log`, `critical-missing.json` |

The remote also holds older branches no current workflow writes (`ci-results/convert/*`, `ci-results/import/*`,
`ci-results/bench`, `ci-results/scout`); they come from removed workflows and can be ignored.

**Reading them with git** (works where artifact downloads don't):

```sh
git ls-remote origin 'refs/heads/ci-results/*'            # what exists
git fetch --depth 1 origin ci-results/core                 # the latest core results
git show FETCH_HEAD:RUN.txt                                # which commit and run they are for
git show FETCH_HEAD:coverage.log                           # coverage per folder
git show FETCH_HEAD:core.summary.txt                       # errors and failed tests first
git ls-tree -r --name-only FETCH_HEAD                      # every file
git show FETCH_HEAD:test.log.gz | gunzip | less            # a compressed log (on ci-results/gate, app, …)
mkdir -p /tmp/shots && git archive FETCH_HEAD screenshots | tar -x -C /tmp/shots   # screenshots
```

Screenshot files are named by attachment UUID; `screenshots/manifest.json` maps them to the names the tests gave
(`xcresulttool export attachments` output). For pull-request branches use the suffixed name, e.g.
`git fetch --depth 1 origin ci-results/gate--feature-x`.

## 6. Lint and hygiene tools (`tools/ci`)

### 6.1 Comment and design-rule hygiene: `comment_hygiene.py`

Scans every `.swift` file under `ios/` (skipping build folders), reading comments as comments and code with comments
and string literals blanked (`swift_source.py`).

| Rule | Level | Reads | Flags |
|---|---|---|---|
| `review-ref` | error | comments | "review 14", "REVIEW15" |
| `bug-ref` | error | comments | "bug 64", "bug #5" |
| `qa-ref` | error | comments | "QA M11" |
| `store-frame` | error | comments, production targets only (not `Support/`, not `Root/DemoScenes.swift`) | "store frame 51b", "frame #4" |
| `wip` | error | comments | "WIP" |
| `process-ref` | error | comments | "juror", "jury", "foreman" |
| `icon-orb` | warn | code | `IconOrb(` |
| `inline-orb` | warn | code | a glyph on a translucent tinted circle drawn by hand |
| `status-colour` | warn | code (not `Design/Theme.swift`) | `Palette.amber`, `Palette.coral` |
| `type-scale` | warn | code | a literal `Typeface.display/…(N)` size off 12/13/15/17/20/28/40/64 |
| `test-coupling` | note | comments, production targets | screenshots, UI tests, App Preview, simulator explained in product code |

Baseline: `tools/ci/hygiene-baseline.json` counts pre-existing occurrences per file and "rule: matched text" (today
81 `status-colour`, 8 `inline-orb`, 7 `test-coupling`; 96 in all). A file may hold at most its baseline count. Error
rules fail on anything over the baseline. A warn rule reports new occurrences without failing while the baseline still
holds some of it, and **arms itself** (fails like an error rule) once the baseline holds none: today `icon-orb` and
`type-scale` are armed. `--strict` arms all warn rules.

```sh
python3 tools/ci/comment_hygiene.py                    # check (CI adds --github)
python3 tools/ci/comment_hygiene.py --list status-colour
python3 tools/ci/comment_hygiene.py --update-baseline  # only ever lowers counts
python3 tools/ci/comment_hygiene.py --reset-baseline   # rewrite from scratch (a reviewed decision)
```

`sweep_comments.py` rewrites review/bug/QA/store-frame references out of comments mechanically (dry run by default,
`--write` to apply). `lint_tells.py` is the old name of `comment_hygiene.py`, kept as an alias. `test_hygiene.py` tests
all three. `.swiftlint.yml` repeats the review and WIP rules as SwiftLint custom rules so Xcode shows them while typing.

### 6.2 Compiler warnings: `build_warnings.py`

Reads `path:line:col: warning:` lines from an xcodebuild or `swift build` log (each warning counted once) and sorts
them into `sdk` (inside Xcode's SDKs; allowed), `allowed` (matched by `tools/ci/warnings-allowlist.json`, which today
allows only generated code under `ios/build/`), `concurrency` (complete concurrency checking; counted per file, allowed
until the move to Swift 6 mode) and `other` (fails). Writes `warnings.json` and `concurrency-by-file.json` with
`--out`. It runs on the core, app and release logs. This replaces `SWIFT_TREAT_WARNINGS_AS_ERRORS`, which can't spare
the concurrency warnings. To allow an unavoidable warning, add an entry with a `why`.

### 6.3 SwiftLint

Configuration: `.swiftlint.yml` (included folders, opt-in rules such as `force_unwrapping` and
`accessibility_label_for_image`, length limits, the two custom rules). Baseline: `tools/ci/swiftlint-baseline.json`
(1,003 entries: 939 warnings, 64 errors). The core step installs SwiftLint with Homebrew if missing, writes a fresh
baseline candidate and a summary (`ci-out/swiftlint-baseline.json`, `ci-out/swiftlint.txt`), then lints against the
committed baseline with the GitHub reporter: a new error-severity violation fails, a new warning is only reported. When
violations are fixed, replace the baseline with the candidate from `ci-results/core`.

### 6.4 Coverage floor: `coverage.py`

Reads SwiftPM's coverage export (`swift test --show-codecov-path`) and counts lines of `ios/Sources/TimbreCore` only,
with a per-folder breakdown. Fails when coverage is under `tools/ci/coverage-floor.json` (`lines`, today 50.0; measured
about 95 %). `--raise-floor` sets the floor to one point under the measured value and never lowers it. It prints a
hint when coverage is 3+ points above the floor.

### 6.5 Skip-CI guard: `skip_ci_guard.py`

On pull requests, every commit in `base..head` that changes a file under `ios/` must not ask CI to skip it (`[skip ci]`,
`[ci skip]`, `[no ci]`, `[skip actions]`, `[actions skip]`, `skip-checks: true`) and its subject must not start with
"WIP". Commits reachable from the SHA in `tools/ci/skip-ci-grandfathered.txt` predate the rule and are exempt; never
move that SHA past a commit that skipped CI. Needs full history (`fetch-depth: 0`).

### 6.6 Other CI helpers

| Script | What it does |
|---|---|
| `launch_retry.py LOG OUT` | From a failed xcodebuild log, writes `-only-testing:` lines for tests that failed only because the app never launched ("Timed out while launching application", "does not have a process ID"); exit 0 only if every failure was of that kind. Used by `ios.yml` accessibility |
| `summarize-log.py LOG OUT` | Writes errors, failed tests and the log's tail to a summary file and emits up to 10 `::error` annotations |
| `publish-results.sh BRANCH DIR [JOB]` | §5 |
| `ensure-metal.sh` | Installs Xcode 26's separately downloaded Metal toolchain (`xcodebuild -downloadComponent MetalToolchain`) when `xcrun metal` is missing; the app has `Shaders.metal` |
| `swift_source.py` | Swift lexer (comments, strings, interpolations) used by the hygiene lint, the sweep and `verify-ios-resources.py` |

## 7. Localization gates

Both run in the `core` job, every run. Details for translators and developers are in
[l10n/HANDOFF.md](l10n/HANDOFF.md).

- `python3 tools/l10n/report.py --check --strict --out ci-out/l10n`: prints a warning annotation with the untranslated
  counts per locale, writes fresh TODO files to the results, and **fails when the committed handoff
  (`docs/l10n/HANDOFF.md`, `tools/l10n/todo/`, `tools/l10n/pending.json`, `tools/l10n/source/`) is out of date**. Fix:
  run `python3 tools/l10n/report.py` and commit what it writes whenever you add or change English (a new `Text("…")`, a
  curriculum change).
- `python3 tools/l10n/critical.py --baseline --github`: fails on a legal (paywall terms), permission
  (`NS…UsageDescription`) or VoiceOver string that a shipped locale lacks and `tools/l10n/critical-baseline.json` does not
  list. Fix: deliver the translation, or record the gap with `critical.py --write-baseline` (a reviewed diff).
- The App Store upload runs `critical.py --strict`, which allows no gap in any shipped locale (§3.3).

## 8. Running things locally

### 8.1 On a Mac (Xcode 26.x)

```sh
# Core library
swift test --package-path ios --parallel
swift test --package-path ios --filter LearnTests             # one suite
swift test --package-path ios --parallel --enable-code-coverage && python3 tools/ci/coverage.py
swift test --package-path ios --sanitize=thread               # what the nightly tsan job runs

# App project
brew install xcodegen swiftlint
(cd ios && xcodegen generate)
bash tools/ci/ensure-metal.sh
open ios/Timbre.xcodeproj                                     # scheme Timbre; StoreKit test file is preconfigured

# App unit tests and smoke flows, as the app job runs them
DEVICE_ID=<simulator udid>                                    # xcrun simctl list devices available
xcodebuild build-for-testing -project ios/Timbre.xcodeproj -scheme Timbre \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath ios/build/dd CODE_SIGNING_ALLOWED=NO
xcrun simctl boot "$DEVICE_ID"; xcrun simctl privacy "$DEVICE_ID" grant microphone com.shahradazerisharghi.timbre
xcodebuild test-without-building -project ios/Timbre.xcodeproj -scheme Timbre -parallel-testing-enabled NO \
  -only-testing:TimbreAppTests -only-testing:TimbreUITests/SmokeUITests \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath ios/build/dd CODE_SIGNING_ALLOWED=NO

# Other UI suites: swap the -only-testing arguments, e.g.
#   -only-testing:TimbreUITests/AccessibilityAuditUITests
#   -only-testing:TimbreUITests/TimbreUITests/test11StoreTunerLock
# The tour in another language, or one matrix variant:
TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE xcodebuild test-without-building … -only-testing:TimbreUITests/TimbreUITests
TEST_RUNNER_TIMBRE_MATRIX=ax5 xcodebuild test-without-building … -only-testing:TimbreUITests/AccessibilityMatrixUITests

# Release build and the warnings gate
xcodebuild build -project ios/Timbre.xcodeproj -scheme Timbre -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath ios/build/release CODE_SIGNING_ALLOWED=NO 2>&1 | tee /tmp/release.log
python3 tools/ci/build_warnings.py /tmp/release.log

# SwiftLint as CI runs it
swiftlint lint --quiet --baseline tools/ci/swiftlint-baseline.json

# Export screenshots from a result bundle
xcrun xcresulttool export attachments --path ios/build/Gate.xcresult --output-path /tmp/shots
```

To try the app without an instrument, run it from Xcode with the environment variables in
[ARCHITECTURE.md §14.1](ARCHITECTURE.md#141-testsupport-launch-keys)
(e.g. `TIMBRE_DEMO_PITCH=1`, `TIMBRE_DEMO_DATA=1`, `TIMBRE_SCENE=tune-locked`). They have no effect in Release.

### 8.2 On Linux (Python 3.12+, no Swift toolchain)

`swift test` needs macOS: TimbreCore imports Apple-only modules (for example `os` for `OSAllocatedUnfairLock` in
`Commerce/Access.swift`) and the package declares only iOS and macOS. The Python tools don't need a Mac. Rows marked
"run" were run on Linux (Python 3.13) when this document was written, with the results CI gets; the others need only
what their row lists.

| Command | Needs | |
|---|---|---|
| `python3 tools/verify-ios-resources.py` | standard library | run |
| `python3 tools/ci/comment_hygiene.py`, `python3 tools/ci/test_hygiene.py` | standard library | run |
| `python3 tools/curriculum/build.py --check` (and the full build) | standard library (about 10 s) | run |
| `python3 tools/l10n/report.py --check --strict`, `critical.py --baseline`, `shipping.py`, `xcstrings.py --check` | standard library (`report.py` reads git history when present) | run |
| `python3 tools/marketing/screenshots.py --check` | standard library | run |
| `tools/l10n/apply.py`, `apply_learn.py`, `report.py --import` | standard library | |
| `python3 tools/ci/skip_ci_guard.py --base origin/main --head HEAD` | git with full history | |
| `python3 tools/ci/build_warnings.py <log>`, `launch_retry.py`, `summarize-log.py` | a log from a Mac build | |
| `tools/marketing/screenshots.py` rendering, `preview.py render` / `check` | Pillow, fontTools, ffmpeg (recording itself needs a Mac simulator) | |
| `tools/build-ios-samples.py` | git, ffmpeg, NumPy | |
| `tools/models/textures.py`, `build_assets.py`, `postprocess.py` | Blender 4.5, Pillow, NumPy, SciPy (`assets.yml` runs them on Ubuntu) | |

## 9. Known CI flakiness and how it is handled

| Symptom | Cause | Handling |
|---|---|---|
| "Timed out while launching application", "does not have a process ID" before any assertion | A simulator that has just booted loses launches for minutes | `ios.yml` accessibility: one warm-up launch (up to 3 tries × 2 min) before the tests; `launch_retry.py` re-runs only launch-only failures once. Other jobs boot the simulator while the app builds |
| "failed to initialize for UI testing" | The hosted simulator fails to bring up accessibility for the runner | `nightly.yml` ipad and `preview.yml`: reboot the simulator and retry once / take again |
| Window-resize arc on every iPad capture | iPadOS 26 starts in Windowed Apps | Full Screen Apps via SpringBoard defaults and a reboot; if apps then don't launch, back to the default with a warning |
| Status bar shows the runner's time | A reboot drops `simctl status_bar` overrides | The override is re-applied after every boot |
| Accessibility audit times out | Screens that never stop moving | `TIMBRE_STAGE_REST=1` stills the stage, shaders and timelines; each audit gets 3 attempts |
| A lock or a note is late in a UI test | Every XCUITest query stalls the app's main thread; a gap over 150 ms restarts the 0.65 s hold | Tests keep their hands off while a lock or note is due; `StillScreen` compares thumbnails instead of querying |
| StoreKit test purchases not visible yet | `SKTestSession` changes reach `currentEntitlements` asynchronously | `StoreKitTestEnvironment` waits (up to 12 s) for the verified store state; commerce tests run serially |
| Streak captures show 7 days with a grey flame | Demo records dated before midnight on a run just after midnight UTC | `DemoData` dates records at 5 PM local, never after now, today's first |
| `hashFiles()` times out | It walks samples, photos and models | The module cache key hashes only `ios/project.yml` and `ios/Package.swift` |
| Metal compiler missing | Xcode 26 ships it as a separate component | `tools/ci/ensure-metal.sh` downloads it when absent |
| Results not published | Push rejected or file over 100 MB | 3 attempts with back-off; files over 45 MB skipped (`SKIPPED.txt`); logs-only fallback (`PUSH-FAILED.txt`) |
| App Preview missed a moment | The recorder lost the app (exit 3) or a moment didn't come (exit 4) | Up to 3 takes; `PREVIEW.txt` says what was missed |
| `gate` red with no failing test | A gate job was cancelled by a newer push, or skipped | Push again or re-run; only the newest run for a ref counts |

The manual audio checks that CI can't do (real microphone, silent switch, calls, AirPods, CarPlay) are in
[ios/AUDIO-DEVICE-TESTS.md](ios/AUDIO-DEVICE-TESTS.md).

## 10. Changing a gate

- Adding Swift code to TimbreCore: add tests in `ios/Tests/TimbreCoreTests`; coverage is checked against the floor.
- Adding English strings: run `python3 tools/l10n/report.py` and commit its output; a new VoiceOver, permission or
  paywall-terms string needs translations or a baseline entry (`critical.py --write-baseline`).
- Adding resources: update `tools/verify-ios-resources.py` when a count it pins changes (instruments, tunings, locales,
  models).
- Fixing old lint: lower baselines with `comment_hygiene.py --update-baseline`, replace
  `tools/ci/swiftlint-baseline.json` with the candidate from `ci-results/core`, and raise the coverage floor with
  `coverage.py --raise-floor`. None of these files should grow without a reviewed reason.
- Adding a UI test class: name it in a workflow's `-only-testing` list, or it will not run in CI (as with
  `FirstSessionUITests` today).
