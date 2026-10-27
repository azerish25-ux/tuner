# Timbre for iOS

A Swift/SwiftUI tuner and music-learning app for iPhone, iPad and Apple Watch: 60 instruments, 132 tunings, 526 lessons in 11 courses and 135 distinct songs. Pitch analysis runs on the device. Requires iOS 18 or later; native CI uses macOS 15 and Xcode 26.3.

## Active continuation — 27 October 2026

Development resumed at the owner's request from the application handoff in draft PR #3. Work uses the assistant's cloud computer and GitHub Actions only. The existing branch name `codex/app-store-readiness-gates` is a Git reference, not a separate coding session. Main's required gate is preserved; no signing, upload or submission has been authorized or performed.

The first-submission scope is **localized screenshots without optional preview videos**, with Game Center still disabled. No application feature is removed by omitting marketing videos. Physical-device testing is unavailable: the owner waived that repository QA requirement, but microphone/audio routes, latency, interruptions, haptics, Watch hardware and physical accessibility remain **unverified**, not passed. The explicit [release applicability policy](docs/ios/readiness/RELEASE-APPLICABILITY.md) keeps that distinction and does not waive privacy, screenshot, product/account or Apple approval requirements.

**Corrective source: `89705bd3144ac3b7ceefe84d6fcf65d83eb9045e` (27 October 2026).** The Songs compiler/lint and flat-gold offer corrections are published; **native execution is pending, not a pass**. The explicit large-phone role integration and inventory documentation are the next reviewed checkpoint, not proof of captured assets. All listing `release_ready` flags remain false. The owner Apple-account question is unanswered; no application merge, signing or upload.

| Source / evidence | Result and limit |
|---|---|
| `f97713eb` — [export 40539498484](https://github.com/azerish25-ux/tuner/actions/runs/40539498484), [iOS 40539504787](https://github.com/azerish25-ux/tuner/actions/runs/40539504787), [pilot 40539498544](https://github.com/azerish25-ux/tuner/actions/runs/40539498544) | Failed at compiler complexity in `SongsView.swift:1006`; core also failed nine-parameter `tileCaption` lint at line 1171. Reviewed corrections use typed ordered appends and `TileCaptionView`; no corrected native result yet. |
| `f97713eb` — [caption audit 40539498843](https://github.com/azerish25-ux/tuner/actions/runs/40539498843) | Passed 65 tests, 2,050 glyph and 2,050 layout checks across 50 locales. This is typography evidence, not a working build or complete native media set. |
| Earlier `6a9329aa` baseline | 148 unit tests, three smokes, core, Release and TSan passed. Accessibility had 38 assertions, tour had two failures and iPad screenshots failed; no aggregate readiness pass. Later source cannot inherit these passes. |

Current source includes accessibility TuneCheck/Quest-trait changes, quiet demo, RTL crop and warmup-rest work, all needing native verification. The flat-gold offer-badge experiment measures a **12.89:1 minimum** and replaces an already accessible gradient; no audit exemption was added and its SDK audit outcome is unproven.

All 50 listing payloads now distinguish **135 distinct tunes / “130+ songs”** from arrangement counts. Apple's [listing locales](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations) confirm the 50-locale scope. Media must preserve the selected medium-phone set **and add an explicit large-phone role** for submission coverage; that role is implemented and locally tested, but its native capture/visual acceptance remains pending. Medium-only media is not a complete submission inventory under the [current screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

Next: natively verify this corrective checkpoint, resolve actual accessibility/tour/layout failures, complete medium/large-phone and iPad capture roles, and review the pilot before all-locale production. [Readiness status](docs/ios/readiness/STATUS.md), [Apple delivery](docs/ios/APPLE-DELIVERY.md) and [release checklist](docs/ios/RELEASE-CHECKLIST.md) keep source evidence and owner/account gates separate. No readiness date is promised.

The historical handoff below is retained verbatim as revision-scoped evidence, **not current execution instructions**. Its old stop request, mandatory physical-device step, unconditional preview/Game Center evidence wording, old medium-only submission-coverage assumptions and old workflow restrictions are superseded by this active continuation and the current source-bound policy/workflows.

## Historical developer handoff — earlier 27 October 2026

**Development was wound down at the owner's request. The app is not ready for App Store submission. Apple account details are not the only remaining requirement.** No signed build, TestFlight upload or App Store submission has been performed.

**This handoff README is published on `main` for immediate visibility. Only the README has been published here; the application code on `main` remains at the `b6efd36` baseline.** Continue development from **`codex/app-store-readiness-gates`**, attached to [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). The last executed app/smoke baseline is `5167d34`. Later source changes are clearly marked below. PR #3 remains unmerged; application changes must pass the required gate before merging. Supporting document and download links below point to the frozen handoff snapshot `50e2ce8`, so they work from this README without merging unfinished code.

```sh
git clone https://github.com/azerish25-ux/tuner.git
cd tuner
git switch codex/app-store-readiness-gates
git pull --ff-only
git status --short
```

The unfinished prepared-audio implementation is an **unapplied patch**, separate from app source: [recovery instructions](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/drafts/README.md). Review receipts describe their exact revisions; source approval is not native execution evidence.

### What has been done

| Area | Completed work and limits |
|---|---|
| Translations | All 49 app languages are present. All 48 translated lesson languages cover 6,083 keys with zero unresolved pairs. Interface, lessons, legal, permission and VoiceOver text received source-aware review/corrections; French/Japanese/Tamil wrapping and RTL counters were addressed. Coverage and AI review do not establish universal native-speaker fluency. |
| Store text | All 50 listing payloads pass source, length, structure and recorded review-lineage checks under the owner's source-aware AI review policy. Names, descriptions, keywords, captions and IAP text are prepared. Every `release_ready` flag remains false. |
| Privacy fixtures | Session-specific URLProtocol handlers, invalidation/draining, callback ownership and attribution token queues were corrected. Production queue defaults and consent boundaries were preserved. All 21 privacy tests passed on `5167d34`. |
| RTL counters | Fractions own their numeric layout direction while inheriting localized digits and keeping a localized spoken label. Both strict render tests passed on `5167d34`: exact RGBA comparisons for Arabic/Persian/Hebrew/English and a swapped-value guard. Store-scene recapture remains required. |
| Test-install state | Deferred onboarding is scoped to the automated installation UUID; normal users retain the existing preference. Four unit regressions passed. A same-install/new-install UI regression and the missing first-session StoreKit fixture were added, but their full tour execution remains pending. |
| CI | Required `gate` depends on core, app, Release **and accessibility**. Official Node24 actions are pinned and named artifact publication is preserved. Main branch protection requires an up-to-date `gate`. The core coverage floor rose from 50% to 94% after a measured 95.3277% run. |
| CI budgets | App job: 40 minutes. Six-language matrix jobs: 90 minutes. These address measured cold-build/whole-suite cancellations; individual privacy assertions were not given longer deadlines. All eight groups/all 48 languages remain required. |
| Caption rendering | macOS FriBiDi/RAQM loading was fixed. Licensed, hash-pinned Noto fonts replace unstable private macOS fallback metrics. New medium-size Linux preflight passed 2,050 glyph and 2,050 layout checks across 50 locales. Final macOS compositions remain unverified. |
| Required screenshots | Separate native roles: medium `iphone` 1206×2622, `iphone-large` 1320×2868, and landscape `ipad` 2752×2064. No cross-role substitution or stretching. Shared phone captions, separate images: 9+9+4 per locale; planned full inventory 150 sets / 75 shards / 1,100 JPEGs, pilot 9 sets / 6 shards / 66 images. Large-role native acceptance remains pending. |
| Watch | Corrected lifecycle handling produced 98 original 416×496 RGB PNGs across 49 app languages, accepted by bounded visual/integrity review. A portable 50-listing/100-image upload bundle is archived below. Hardware behavior is untested. |
| Large text | Committed source measures peg cues before placement and adapts the play-along header, tempo grid and scrolling. Source review is complete. Initial QA stopped at test compilation; explicit `CGFloat` corrections are now included, but runtime tests and actual normal/AX5 screenshots remain pending. |
| Preview cue | Explicit camera cues no longer time out into an early start after 90 seconds. Standalone no-cue delay remains 12 seconds; cancellation guards and three native tests were added. These new tests have not run. |
| Public support | Privacy/support were published and verified against built HTML with HTTP 200, CSP and `nosniff`: [privacy](https://timbre-support.timbre.workers.dev/privacy), [support](https://timbre-support.timbre.workers.dev/support). See [publication receipt](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/reviews/privacy-publication-refresh.json). Resource/provenance inventories and owner image declarations are recorded. |
| Claude findings | All 44 issue-table rows and six handover claims were reconciled. The missing required-accessibility dependency and plural importer gaps were fixed with follow-up reviews/tests. Hardware, native-pending, optional growth and maintenance debt remain distinct in the [reconciliation ledger](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/reviews/claude-handoff-reconciliation.json). Do not label every historical row solved. |

Local verification last passed: **193 localization/tool tests, 50 marketing tests, 25 hygiene tests, four cover-contrast tests**, strict reporting, all 50 store-text checks and workflow YAML parsing. Windows cannot execute Swift/iOS tests; use the native evidence below.

### Exact native state

| Revision / run | Result |
|---|---|
| `5167d34` — [iOS 40456038504](https://github.com/azerish25-ux/tuner/actions/runs/40456038504) | Core, app and Release passed. **127 app tests: zero failures; all three smoke flows: zero failures.** Includes privacy, commerce, onboarding unit cases and both exact fraction tests. Accessibility failed, so the aggregate gate failed. |
| Same run — accessibility job `122030313414` | **57 contrast reports plus two unfinished Songs audits = 59 failures.** Contrast counts: Learn 2, Songs 37, Practice 7, Progress 10, paywall 1. Songs Dynamic Type and clipped-text audits did not finish after three isolated attempts. All six localization-launch tests passed. |
| `5167d34` — [Xcode export 40456066835](https://github.com/azerish25-ux/tuner/actions/runs/40456066835) | Passed with Xcode's actual keys: 48×6,083 lesson coverage, zero unresolved pairs, zero legal/permission/VoiceOver gaps. |
| `5167d34` — [caption audit 40456063547](https://github.com/azerish25-ux/tuner/actions/runs/40456063547) | Linux/new dimensions: 2,050 glyph and 2,050 layout checks, zero failures. Not final native screenshot/macOS composition acceptance. |
| `c089246` — [layout QA 40458830411](https://github.com/azerish25-ux/tuner/actions/runs/40458830411), `codex/ax5-layout-checks` | Sanitizer passed. Tour/iPad/accessibility matrix failed at test compilation: ambiguous `.greatestFiniteMagnitude` in two new test files. Explicit `CGFloat.greatestFiniteMagnitude` corrections are in this handoff branch, **not in that run**. No new layout/UI pass is claimed. Resume from the handoff branch, not the old QA branch. |
| `d292f88` — [Watch 40440109281](https://github.com/azerish25-ux/tuner/actions/runs/40440109281) | Passed: 98 native captures accepted within the stated visual/integrity scope. Subsequent iPhone layout changes did not alter Watch source inputs. |
| `c8874d9` — [guitar preview 40447132590](https://github.com/azerish25-ux/tuner/actions/runs/40447132590) | macOS font/shaping/layout passed at the previous large-phone size. **Video/audio failed:** 39% sounding, longest silence 4.6s, lock outside clip, late band and missing scene sounds. Not approved for upload. |
| `0081d2a` — [matrix 40445795060](https://github.com/azerish25-ux/tuner/actions/runs/40445795060) | Superseded/cancelled. RTL six-language group passed. Western de/es/fr/it completed before 60-minute cancellation/incomplete result bundle. Not a complete 48-language pass. An older matrix passed before later corrections; final-source QA remains required. |
| `b6efd36` — [nightly 40434262338](https://github.com/azerish25-ux/tuner/actions/runs/40434262338) | Earlier iPad/sanitizer/matrix job passed; tour failed. Old iPad frames received bounded review. Later fixes need fresh verification. |

All observed runs above are terminal. Pushing this handoff to PR #3 automatically starts another iOS run; inspect [the PR checks](https://github.com/azerish25-ux/tuner/pull/3/checks) for its eventual result. Do not extrapolate `5167d34`'s app pass to later code or to a green aggregate gate.

### What remains — recommended order

1. **Build the handoff branch and run the new tests.** Verify the numeric-type correction compiles. Run `PegLabelLayoutTests`, `TempoRungLayoutTests`, `PreviewCueTests`, all app tests and smoke flows. Then execute full first-session/tour, iPad, accessibility matrix and sanitizer. Inspect normal and AX5 ready/playing/results views, Start reachability, playback scrolling and the 420-point results overlay. Source approval does not establish these behaviors.
2. **Resolve accessibility without blanket exemptions.** Download the latest `5167d34` callback artifacts. The [older 008 callback review](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/reviews/accessibility-008-callback-review.json) accounts for 54 findings: 28 visible pixel contradictions, 25 obscured/edge-faded targets and six opaque callbacks historically collapsed to one. That is **not** the latest 57-report inventory. Scroll obscured targets fully into view and recheck the same target; identify opaque callbacks; finish both Songs audits. Any SDK false-positive filter must be narrow, identity/type/visibility-bound and backed by paint-role regressions. Do not remove contrast enforcement or call incomplete audits passes.
3. **Run all localization scopes and recapture RTL.** Execute eight groups/all 48 languages under the 90-minute outer budget; review real frames for glyphs, clipping, wrapping and RTL. Recapture Arabic compact progress after the fraction fix. Preserve 49-app/50-listing mapping and the explicitly disclosed English app fallback for listing-only Malay, Odia and Traditional Chinese.
4. **Finish preview timing if previews will ship.** The cue fix is committed; the actual movie remains failed. [Frozen timing triage](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/reviews/preview-c887-timing-triage.json) proves early cue bypass and band readiness after the selected hook. Show Me uses a pre-tap anchor; Songs emits a historical clip without sound acknowledgment; a late results query missed all four star cues. The untested preparation patch is below. Other anchors, tuned/end-card continuity and violin preview remain unfinished. Require actual acknowledgments and app sound. Do not invent missing audio, weaken silence/band/sync gates or assume `keep: .tail` caused the lock problem.
5. **Produce final localized listing media.** Review final macOS caption fitting, pilot English/German/Arabic, then run all 50 locales. `listing-assets.yml` currently plans only on `main`: merge through a green gate first, or deliberately review a branch-only artifact-validation change. Require native medium-iPhone/13-inch-iPad captures, actual-language evidence, matching source/build hashes, complete manifests and visual review of every frame. Nine phone and four tablet frames per listing are planned. A complete final 50-locale phone/tablet set does not exist yet; the Watch bundle is only its Watch portion.
6. **Align release validation with chosen scope.** `tools/l10n/store.py --release` unconditionally requires `app_preview` and `game_center_account` evidence. Game Center is disabled by default and previews are optional. If omitting either, implement an explicit reviewed applicability policy/tests/evidence; never fabricate `verified` flags. If enabling Game Center, finish its separate account/assets/device setup and restore only accurate claims. Keep all `release_ready` flags false until their real requirements are met.
7. **Complete physical-device QA.** Use [AUDIO-DEVICE-TESTS.md](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/AUDIO-DEVICE-TESTS.md): microphone start/stop, interruptions, leakage/grading, latency, wired/Bluetooth routes, haptics and Watch/device behavior. Test real VoiceOver/Dynamic Type and supported sizes. Simulator tests cannot certify this.
8. **Complete Apple-account setup and submission.** Configure app/bundle records, capabilities/MusicKit as applicable, agreements, tax/banking, products/prices/trials and real sandbox purchases. Verify signed entitlements, archive/privacy report, privacy/age-rating/export-compliance answers and portal metadata. Reconcile optional analytics/song-request configuration with the public policy. Only then authorize signing/upload and review the uploaded build. Follow [APPLE-DELIVERY.md](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/APPLE-DELIVERY.md) and [RELEASE-CHECKLIST.md](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/RELEASE-CHECKLIST.md).

### Portable files and unfinished source

| Material | Location |
|---|---|
| Watch upload portion | [watch-store-assets-d292f88.zip](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/handoff-assets/watch-store-assets-d292f88.zip): 50 locale folders × two unchanged native PNGs, with manifest/README. SHA-256 `5e28b00368c476db9ee6893dff20f10af2dcb9406a0f7897389c3373b60992b5`. |
| Reviewed store text | [listing-text-reviewed-0081d2a.zip](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/handoff-assets/listing-text-reviewed-0081d2a.zip): separate text/caption/IAP fields for all 50 locales. Every field hash was rechecked and payloads still match source JSON. Game Center metadata is omitted because release defaults disable it. |
| Caption summary | [caption-typography-5167d34.json](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/handoff-assets/caption-typography-5167d34.json), with native-run scope explained above. |
| Checksums | [handoff-assets/manifest.json](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/handoff-assets/manifest.json). These are prepared portions, not a complete submission package. |
| Unapplied audio draft | [preview-band-preparation.patch](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/drafts/preview-band-preparation.patch), [base/hash manifest](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/drafts/preview-band-preparation.json), [recovery guide](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/drafts/README.md). Four-file reviewed source draft, never compiled/executed natively. |
| Review history | [reviews/](https://github.com/azerish25-ux/tuner/tree/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/ios/readiness/reviews): original findings and resolutions retained. [docs/HANDOVER.md](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/HANDOVER.md) is historical context; use this dated README and reconciliation for current state. |

The patch adds exact arrangement/current-rate preparation, output-lease ownership through final startup, cancellation/replacement cleanup, a real take-clock acknowledgment and four controlled `AudioStartupTests`. Earlier source review findings were addressed. It changes shared `AudioStartGate` behavior, so focused **AudioStartup/RecordingStartup**, full app and actual preview verification are mandatory before integration. Its 45-second budget covers band polling after output activation, not the entire hardware lifecycle. It does not fix all preview anchors.

Original screenshots/logs remain in linked Actions artifacts and `ci-results/*` branches. Many artifacts retain files for only 7 or 14 days; preserve originals before expiry or reproduce the run. The original workstation also holds `C:\Users\shahr\Desktop\Translation\native-qa` and `release-candidate`; source and the portable bundles above do not depend on those local directories.

### Resume commands

From the repository root, use Python 3.12 and a virtual environment:

```sh
python3 -m venv ../timbre-marketing-venv
. ../timbre-marketing-venv/bin/activate
python3 -m pip install -r tools/marketing/requirements.txt
python3 -m unittest discover -s tools/l10n/tests -p 'test_*.py'
python3 -m unittest discover -s tools/marketing/tests -p 'test_*.py'
python3 tools/ci/test_hygiene.py
python3 tools/ci/test_song_cover_contrast.py
python3 tools/ci/comment_hygiene.py
python3 tools/l10n/report.py --check --strict
python3 tools/l10n/store.py
python3 tools/curriculum/build.py --check
python3 tools/verify-ios-resources.py
```

On a Mac, generate the project and select an available iPhone simulator UDID:

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
brew install xcodegen
(cd ios && xcodegen generate)
bash tools/ci/ensure-metal.sh
xcrun simctl list devices available
export DEVICE_ID='<available iPhone simulator UDID>'
swift test --package-path ios --parallel --enable-code-coverage
xcodebuild test -project ios/Timbre.xcodeproj -scheme Timbre \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -parallel-testing-enabled NO -only-testing:TimbreAppTests \
  -derivedDataPath ios/build/dd CODE_SIGNING_ALLOWED=NO
```

After GitHub CLI authentication, dispatch targeted fixes first, then complete scopes:

```sh
gh workflow run ios.yml --ref codex/app-store-readiness-gates
gh workflow run l10n.yml --ref codex/app-store-readiness-gates
gh workflow run caption-typography.yml --ref codex/app-store-readiness-gates
gh workflow run nightly.yml --ref codex/app-store-readiness-gates
gh workflow run localized-capture-check.yml --ref codex/app-store-readiness-gates
gh workflow run localization-matrix.yml --ref codex/app-store-readiness-gates
# After preview fixes; both actual cuts must pass:
gh workflow run preview.yml --ref codex/app-store-readiness-gates -f preview=both
# After a verified merge to main, run the screenshot pilot:
gh workflow run listing-assets.yml --ref main -f locales=en-US,de-DE,ar-SA -f scope=screenshots -f violin=false
# After pilot acceptance, all 50 locales:
gh workflow run listing-assets.yml --ref main -f locales=all -f scope=screenshots -f violin=false
```

Inspect exact source SHAs and artifacts. Recover known app evidence with `gh run download 40456038504 -n results-app -D ../timbre-evidence/app-5167d34`; use `-n results-accessibility` for that job's evidence. Do not use `[skip ci]`, bypass main's required gate, silently reduce locale scope or substitute mock/parser images for native captures. The handoff commit's checks must be evaluated separately from old passing jobs.

### Apple delivery and repository reference

Product IDs: `timbre_pro_annual`, `timbre_pro_monthly`, `timbre_plus_lifetime`; subscription group: **Timbre Pro**. Fixture prices are test data. Live prices/trial eligibility require the owner's App Store Connect configuration. Game Center code exists but `TIMBRE_GAME_CENTER_ENABLED=NO` is the default release scope.

The guarded [Apple delivery workflow](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/.github/workflows/apple-delivery.yml) expects `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` in the protected `apple-delivery` GitHub environment. Enter secrets through provider secret fields, never README/commits/chat. Do not dispatch signing/upload without the owner's explicit delivery authorization.

`ios/project.yml` is the project source; generated projects/build products are ignored. Foundation-only logic is under `ios/Sources/TimbreCore`, app UI/audio/commerce under `ios/Timbre`, with widget and Watch targets alongside it. Asset/model tooling and attribution are in [docs/TOOLS.md](https://github.com/azerish25-ux/tuner/blob/50e2ce8d895a25fd15bb6790a73b40a9b26c951a/docs/TOOLS.md). The Android resource importer intentionally refuses to overwrite the evolved iOS resources.
