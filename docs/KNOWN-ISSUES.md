# Known issues and unfinished work

**Historical issue inventory.** [Current App Store readiness](ios/readiness/STATUS.md) and its
[44-entry reconciliation](ios/readiness/reviews/claude-handoff-reconciliation.json) record current dispositions and evidence.
Unrun native, media and hardware checks remain open; dated source findings below are not automatically current defects.

The honest list at hand-over (2026-10-25). Each item says where it lives and what would close it. Release blockers
that only the owner can clear (accounts, translations, licences) are in [OWNER-ACTIONS.md](OWNER-ACTIONS.md) and the
step-by-step path to the store is in [ios/RELEASE-CHECKLIST.md](ios/RELEASE-CHECKLIST.md).

Legend: **R** = check or fix before release · **G** = growth / quality · **T** = technical debt.

## 1. Needs a real device before release

| | Issue | Where | What closes it |
|---|---|---|---|
| R | The microphone start race (an older tuner start releasing the session a newer one holds) was fixed from code reading, about 60 % confidence; a quiet retry precedes the "Could not start audio" alert. Never run on a device. | `ios/Timbre/Audio/AudioService.swift` (`activationsPending`, `openMicrophone`) | Device sheet cases: cold launch onto the tuner several times; stop and restart within 1 s; drone + mic; AirPods in/out; a phone call; microphone denied. Console: subsystem `com.shahradazerisharghi.timbre`, category `audio`. |
| R | On the CI simulator the main thread stalled 9.4 s (2.2 s on another run) when a song take started its audio output (`ensureOutput` → `configureSession` → `AudioSessionOwner` `queue.sync`). The click now starts before the take's clock, so notes aren't lost, but a freeze on a phone would be a serious bug. | `AudioService.ensureOutput`, `AudioSessionOwner.activate` | Time Perform → first click on a device; any freeze > 300 ms is a bug: move the activation off the main thread like the microphone's (`activateInBackground`). |
| R | The audio device test sheet has never been run (latency, speaker band vs strum grading, haptics while recording, Bluetooth). | [ios/AUDIO-DEVICE-TESTS.md](ios/AUDIO-DEVICE-TESTS.md), checklist cases 13–20 in [ios/RELEASE-CHECKLIST.md](ios/RELEASE-CHECKLIST.md) | Run it on 2–3 iPhones and one iPad; record results in the sheet. |
| R | The band now renders at `.userInitiated` so it joins at the first downbeat; check on the phone speaker with the mic on (Kite Weather): drums at the first downbeat, joins within a bar after a tempo change, also in Low Power Mode and with AirPods (full band). A band prepared before any engine ran renders at 48 kHz and is redone after Start if the hardware rate differs. | `AudioService` (`refreshBand`, `bandRenderPending`) | Device test. |
| R | The speaker band plays drums only while the mic listens; attack-graded steps (strum/chords) pass `onSpeaker: false` so drum hits can't be graded as strokes. Whether the drums leak into play-along judging on a speaker is unmeasured. | `Band.swift`, `AudioService.playBand(_:firstBar:onSpeaker:)`, `Highway.swift` | Device test 4 of the sheet. |

## 2. CI and store creative

| | Issue | Where | What closes it |
|---|---|---|---|
| R | The App Preview's own gates refused the 0bbf273 cut: no band under "Play songs with the band", silence in the Show me / results / songs clips, the lock clip placed ~1.5 s early. Findings: the simulator recording drops frames (151.7–154.5 s had none, so the lock screenshot matched a frozen frame — a recording artefact, the app shows the badge and the bell in the same update and holds it ≥ 1.5 s); the band's render landed too late on a saturated runner (it now renders at `.userInitiated`, and the preview's `band` events record `rendering`). The preview is optional for submission. | `tools/marketing/preview.py`, `gates.py`, `ios/TimbreUITests/AppPreviewUITests.swift`, `Root/DemoScenes.swift`; results on `ci-results/preview--preview-run1` (`PREVIEW.txt`, `events.jsonl`) | Re-record (`git push -f origin <sha>:refs/heads/preview/run1`); if the band is still missing read the `band` events' `rendering`; retake or `--reanchor` the lock clip; the other silences are creative (Show me rings ~1 s, the Songs scene plays its opening without a band). Never loosen the gates to pass. |
| R | Nightly tour on 0bbf273 (the last one run): onboarding, purchase, iPad and the AX5 matrix pass; three store-capture checks still fail. **test14** (frame #2, Kite Weather): the take now holds a combo (90), but the words shown are a verse ("your little brother runs with the spaniel"), not the chorus — the new wait for a still Stop button moves the picture later; shift `TIMBRE_SCENE_BAR` or the wait. **test11** (frame #1, tuner lock): the probe saw the lock held 0.0 s over 7 s — check the `stage.state lock=` probe key the test reads against `RootView`/`TuneView` before suspecting the app (the app latches the badge ≥ 1.5 s, `LockLatch.swift`). **test01**: "Failed to terminate" at teardown (simulator flake). Failing frames are saved as `-wrong`. | `ios/TimbreUITests/TimbreUITests.swift`, `Root/DemoScenes.swift`; results on `ci-results/app` | Fix the three checks, re-run the nightly (label `captures`), then download the frames for App Store Connect. |
| R | Apple Watch screenshots are required (the build contains a watch app) and no workflow makes them. | `ios/TimbreWatch` | Add a watch simulator capture job, or capture by hand. |
| G | The accessibility audit job is not part of the required gate. On 0bbf273 it found ~30 contrast hits, 2 small hit areas and one icon read by its symbol name; the real ones were fixed (play-along rail letters, the next arrow's label, 44 pt stars and tempo buttons) and the rest exempted with measured ratios — a few flagged elements measure far above the threshold for reasons not proven. | `ios/TimbreUITests/AccessibilityAuditUITests.swift`, `ios.yml` job `accessibility` | Keep it green, then make it a required check. |
| G | `FirstSessionUITests` runs in no workflow; no UI test launches the `lesson-dead-string` scene; `tools/curriculum/build.py --check` runs in no workflow. | `ios/TimbreUITests`, `.github/workflows` | Add them to the nightly / core job. |
| G | Localized store sets can't be rendered yet: frames #3 and #7 read English text and stay `-wrong` in other languages. | `ios/TimbreUITests/TimbreUITests.swift` (top) | Read identifiers instead of English text. |
| R | StoreKit purchase tests are flaky on CI (e.g. `testYearlyArmGrantsPro`: "transactions did not clear before timeout"); a re-run of failed jobs passes. The accessibility audit often times out on hosted runners ("Audit failed to complete in time"). | `ios/TimbreAppTests/StoreKitTestEnvironment.swift`, `AccessibilityAuditUITests.swift` | Longer clean-up wait / serial StoreKit tests; a bigger runner or fewer audits per launch. |
| T | `actions/checkout@v4` and `upload-artifact@v4` run on deprecated Node 20. | all workflows | Move to the v5 actions. |
| T | Old results branches (`ci-results/convert/*`, `import/*`, `bench`, `scout`) come from workflows that no longer exist. | remote | Delete when convenient. |
| T | Coverage floor is 50 % against ~95 % measured; TimbreCore has zero concurrency warnings (the condition `Package.swift` sets to move it to Swift 6). | `tools/ci/coverage-floor.json`, `ios/Package.swift` | Raise the floor; switch TimbreCore to Swift 6. |

## 3. Product gaps the jury named (code side)

| | Issue | Where |
|---|---|---|
| G | The hand rig for Show me needs the owner's rigged hand; the hook is ready. | `ShowMeController.handRig` |
| G | Ukulele and banjo 3D models are missing (drop in via `models-manifest.json`). | `ios/Timbre/Resources/Models` |
| G | Metronome voices/grooves: new sounds need a joint change to `MetronomeRenderer.Sound` (TimbreCore `OutputAudio.swift`), `MetronomeView`'s exhaustive switch, FreeTier/PlanComparison and new strings. | `OutputAudio.swift`, `Practice/MetronomeView.swift` |
| G | The speaker band "step 2" (echo cancellation / voice processing behind a self-test, so the full band can play on the speaker while listening) needs a device. | `AudioService`, `CueVoice.swift` |
| G | A wrong-chord ("Am?") capture hook doesn't exist; only the dead-string one does. | `Root/DemoScenes.swift`, `Learn/LessonSteps.swift` |
| G | At the largest text size (AX5) the tuner header is still cramped (clipped text, overlaps). | `Tune/TuneView.swift` |
| G | The tuning menu sits on the tuning line only; the whole header would break tests that tap `tune.instrument`. | `Tune/TuneView.swift`, UI tests |
| G | Carol week has no remote-config key; `freeSongs` stays open until the owner removes the songs from the settings file. | `Services/RemoteConfig.swift` |
| G | "Next", "Again" and "Slower" are both on-screen labels and Siri command titles, so one translation serves both. | `Intents/PracticeIntents.swift` |
| G | Game Center still names the Pitch Sniper activity by its old name. | `Services/GameCenterIDs.swift` |

## 4. Technical debt

| | Issue | Where |
|---|---|---|
| T | iCloud sync of progress isn't built (needs the iCloud entitlement and the owner enabling iCloud on the App ID). | `Persistence/LocalStore.swift` |
| T | Curriculum is one 11 MB JSON decoded at launch (off the main thread); sharding would cut memory and launch work. | `CurriculumStore` |
| T | `AppStore` is still large; the Router/ProgressStore split was not done. `PracticeRecord.kind` is a string, not an enum. | `Services/AppStore.swift` |
| T | String Catalog (`.xcstrings`) migration not done; `Bundle.app` is prepared for it. | `ios/Timbre/Resources/*.lproj` |
| T | Hygiene baseline (96 allowed occurrences), SwiftLint baseline and the concurrency-warning allowlist still hold older violations. | `tools/ci/hygiene-baseline.json`, `swiftlint-baseline.json`, `warnings-allowlist.json` |
| T | `tools/brand/icon.py` renders the icon design in amber; the shipped interim icon is mint. | `tools/brand/icon.py` |
| T | The Blender model pipeline's rigs lack the `credit` block `verify-ios-resources.py` requires; the shipped models are Sketchfab CC BY models whose converter isn't in the repo. | `tools/models` |
| T | `tools/localize-ios-copy.py` targets a folder that no longer exists; `tools/import-ios-resources.py` now refuses to run (it would overwrite the catalogue, photos, fonts and translations). | `tools/` |

## 5. Translation tooling

| | Issue | Where |
|---|---|---|
| R | The App Store delivery gate runs `critical.py --strict` without `--xliff`, so a string imported under a wrongly guessed key (`key_check`) counts as translated while the app shows English. Two of today's five guessed keys are critical. | `.github/workflows/apple-delivery.yml` |
| R | Delivery trims locales with `shipping.py --min` but without `--critical`, so a locale above the bar that lacks a critical string fails the upload instead of being left out. | `.github/workflows/apple-delivery.yml` |
| G | The import refuses a plural `one` form without the number although the English (and 27 locales) have one; `--import` never writes plurals (they're added by hand). | `tools/l10n/report.py` |
| G | `max_length` is enforced nowhere; line breaks aren't compared for interface strings. | `tools/l10n/report.py` |
| G | Shipped tables have known errors: "Intonation" translated as guitar-setup octave adjustment in ca, es, ja, pt, zh-CN; mixed formal/informal register in he, hr, ro, sl, tr; mixed "..." and "…". They aren't in the TODO files, so they need a separate clean-up batch. | `ios/Timbre/Resources/*.lproj` |
| G | The listing checker skips several keyword rules for localized listings and never checks localized description / promotional text / What's New. | `tools/marketing/screenshots.py` |
| R | `LocalizationLaunchUITests` expects the German welcome to be English (`XCTExpectFailure`); remove the wrapper in the same PR that imports the German funnel strings. | `ios/TimbreUITests/LocalizationLaunchUITests.swift` |

Fixed during hand-over: the translation import now checks `%lf`, `%llu` and `%u` arguments (`tools/l10n/apply.py`).

## 6. Legal and store content

| | Issue | Where |
|---|---|---|
| R | 68 of the 73 instrument photos are marked "provided" with no licence on record. | `ios/Sources/TimbreCore/Resources/photos.json` |
| R | The hosted privacy policy (gh-pages, 23 Oct) says analytics stay on the device; the app sends anonymous analytics (with an opt-out). Updated pages are in `docs/site/` for the owner to publish; a Support URL page is there too. | `docs/site/` |
| R | MusicKit must be enabled on the App ID or "Listen on Apple Music" shows "isn't available"; the Game Center bullet must leave the description unless Game Center is set up. | `docs/ios/APPLE-DELIVERY.md` §6.1, §8 |
| G | The repository is public. | GitHub settings (owner decision) |
