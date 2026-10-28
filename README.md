# Timbre — development and Apple submission readiness

## Active continuation — 28 October 2026

Development has resumed at the owner's request on `codex/app-store-readiness-gates` (draft PR #3). The preserved handoff below remains the baseline record; its stop instruction no longer describes this continuation. The app is **not submission-ready**. Current layout repairs and their native regressions remain under verification; no signing, upload or submission is authorized by this status.

The required Nightly XCTest shards now run with **no preceding diagnostic priming launch** by default. This does not establish a cold OS/GPU state, and later launches within a class are conditioned by earlier tests. All existing XCTest selections, assertions, timeouts, source/build checks, original captures and native release/accessibility/localization/sanitizer gates remain required. The separate demo/stage-rest priming experiment does not establish app readiness or GPU completion: recent prelaunch setup failures were followed by passing actual first-session/capture XCTest classes.

Priming remains available through the Nightly manual `priming=true` input, or the `simulator-priming` PR label alongside `captures`. Its request, outcome and original receipt are recorded in shard evidence. If requested, failure, missing evidence, unexpected skipping or a foreign receipt still fails aggregation. A default run records “not requested/skipped,” never a successful priming receipt. Historical failed runs remain failed. This changes the diagnostic setup contract, not any production acceptance assertion.

## Preserved development handoff

**Owner-requested stop: 28 October 2026. The app is NOT submission-ready. Apple Developer configuration is NOT the only remaining work.**

The owner has taken over development on their own laptop with their own Codex. Development and automatic retry plans were stopped. This README is the current handoff, superseding older completion estimates and older active/historical README sections.

Approved App Store identity:

- **Name:** Timbre: Tuner & Music Lessons
- **Subtitle:** Guitar, Violin, Cello & More
- **App Store Connect app:** `6827721551`; SKU `timbre-ios-001`; primary locale `en-US`.
- **Scope:** instrument tuner and music lessons, not a guitar-only app. Preserve the Timbre name.

## 1. Where ALL current work is saved — read this first

**This README and its handoff package are published on `main`. The current application work is on `codex/app-store-readiness-gates`, in [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). Unverified application changes have NOT been merged into main.** Main's application baseline is older; do not begin continuation against its old app files accidentally.

- Last application/CI preservation commit: **[`f937c5d412956fd4d7b5468659f049103aee402f`](https://github.com/azerish25-ux/tuner/commit/f937c5d412956fd4d7b5468659f049103aee402f)**. All nine formerly uncommitted files were saved, pushed, fetched back and verified clean here.
- Its tree: `469926c5835eb3f057fa64d1b8f2a46de50e5ca1`.
- Last prior development candidate: [`a161bec505f827a32feaeb74c6e955d4d6db146d`](https://github.com/azerish25-ux/tuner/commit/a161bec505f827a32feaeb74c6e955d4d6db146d). The final observed native runs tested its PR merge `52f6c14ffc807db7be184e16416e508c69f2c870`, with the same tree `2723b64d3d1ce73f3ed229a1bdee026c13432c6b`.
- Before this documentation publication, main was `7a0c7a45cb4c5efe3ada881b049634efc20b0343`; f937 was 57 commits ahead. Later handoff-only documentation commits do not imply more app fixes or new test passes.
- [Complete committed development comparison](https://github.com/azerish25-ux/tuner/compare/7a0c7a45cb4c5efe3ada881b049634efc20b0343...f937c5d412956fd4d7b5468659f049103aee402f).
- [Detailed technical handoff](docs/handoff/2026-10-28/TECHNICAL-HANDOFF.md): source history, exact unfinished issues, patches, verification boundaries and commands.
- [Final native snapshot](docs/handoff/2026-10-28/manifests/native-snapshot.json): **16:44:14 UTC**, 16 jobs / 33 artifact records with direct GitHub links, hashes, sizes and evidence limitations.
- [Portable contrast evidence](docs/handoff/2026-10-28/evidence/contrast-clear-state/README.md) and [selected native originals](docs/handoff/2026-10-28/evidence/native-originals/README.md), preserved for independent review.
- [Apple owner checklist](docs/ios/APPLE-OWNER-CHECKLIST.md), also reproduced in section 8 below.
- [Preserved patch inventory](docs/handoff/2026-10-28/archive/PATCH-INVENTORY.md), [machine-readable inventory](docs/handoff/2026-10-28/archive/patch-inventory.json), and [portable package checksums](docs/handoff/2026-10-28/FILES-SHA256.json).

**There is no required dependency on the prior cloud computer.** Source is committed; current unapplied proposals and recovery instructions are packaged in this repository. Bulk native recordings/result bundles remain in the linked GitHub Actions artifacts, subject to their recorded retention/expiry. Download important originals before expiry. Generated duplicate caches are not application deliverables.

### Continue on your laptop

```sh
git clone https://github.com/azerish25-ux/tuner.git
cd tuner
git fetch origin
git switch codex/app-store-readiness-gates
git pull --ff-only
git status --short
# Read this README and docs/handoff/2026-10-28/TECHNICAL-HANDOFF.md.
# Verify f937c5d412956fd4d7b5468659f049103aee402f is in HEAD history.
git merge-base --is-ancestor f937c5d412956fd4d7b5468659f049103aee402f HEAD
```

Use the branch HEAD, including handoff docs. The combined archived nine-file patch is **already applied in f937**: do not apply it again. Do not reset to an old green revision and lose later work. Do not blindly apply every archived proposal.

The old restriction against separate Codex work applied to the previous assistant session. The owner now explicitly intends to continue with their own local Codex. On Windows/Linux, use GitHub Actions for native Apple builds; portable Python checks are not Swift/iOS execution. On a Mac, use the exact Xcode/SDK/toolchain selected by the workflows. Current source requires iOS 18+ and validates Apple SDK 26+, with Xcode 26.3 pinned where specified.

## 2. What has been completed, and what those results actually mean

| Area | Work preserved | Verification / limitation |
|---|---|---|
| Application breadth | Native Swift/SwiftUI iPhone/iPad/Watch app, instrument tuning, lessons, play-along, practice, progress, commerce and extensions. Existing features were not removed to bypass readiness. | Current source is a candidate, not a signed/submitted release. |
| Language expansion | 52 app languages; 51 translated lesson locales covering 6,090 keys; 50 separate App Store listing localizations. Legal/permission/VoiceOver and localization tooling/review lineage are preserved. | These three counts describe different inventories. Source coverage and AI review are not native-speaker certification or final native visual QA. |
| Public release counts | Public claims reconciled to 60 instruments, 132 tunings, 526 lessons in 11 courses, and **135 distinct tunes**, marketed as **130+ songs**. Resource/build tools also contain broader course and instrument-arrangement inventories. | Do not advertise the larger arrangement count as distinct songs, or assume every bundled experimental course is released. |
| Store drafts | 50/50 app-information names/subtitles and 50/50 version-text drafts were saved and read back in App Store Connect. Approved multi-instrument brand retained. | Draft text is saved; final screenshots are not uploaded. No submission or public release occurred. |
| Store/source review | All 50 payloads have structural/length/count/review-lineage checks. Arabic performance-feedback caption corrected to `تابع أداءك أثناء العزف`; musical-cent terminology retained. | Every release-ready flag remains false. Caption text/preflight is not final screenshot acceptance. |
| Country pricing | Country/storefront affordability proposal and validator prepared, with 175 public storefronts and unresolved exceptions documented. | No live product prices configured/read back. The authenticated complete-price verifier still needs implementation. |
| Apple identifiers | App record, four bundle identifiers and shared App Group registered/associated in the prior account work. Game Center disabled. | Registration is not provisioning, signing or successful extension execution. Exact identifiers are in the owner checklist. |
| Privacy/support | Public support/privacy pages published and previously verified against committed HTML with HTTP 200 and security headers. Source inventory/review history preserved. | Prior HTTP observations are dated; no fresh network verification is implied. App Privacy declarations and final release review remain unfinished. |
| Source/privacy binding | Current receipt binds 300 inputs; subsequent narrow source reviews are append-only. DEBUG local diagnostic persistence is explicitly disclosed. | Receipt hash on a16/f937: `e60e58061821f3197de1238896c2f6c81f631f49c7374287528b0548501ab4e9`. It is not legal or Apple approval. Refresh only after reviewing later source changes. |
| RTL metadata | Numeric direction/fraction work preserved; Arabic Songs hero duration and XP are isolated separately while spoken labels stay localized. The independent oracle uses a native text baseline. | The corrected Hero metadata suite passed all six cases in the preserved 226 log. Do not extend that to every later native gate. |
| Urdu typography | Actual fallback font selected using the explicit Urdu resource bundle and uncapped scaled metrics; measured ink allowance, strict pixel/bounds tests and renderer diagnostics added. | **Live right-edge clipping remains.** TextRenderer padding changed placement/wrapping; no accepted renderer repair exists yet. |
| Songs browsing | Horizontal identity/geometry work, explicit typed vertical row targets, bounded DEBUG page traces, and a once-per-size same-ID restoration candidate added. | Prior traces prove correct ID but wrong offset after rotation. a16's new restoration still needs completed native evidence. |
| Large-text lessons | Actual notes/quiz/PlayAlong reachability, selected-answer rediscovery after feedback, full place-label flow, intrinsic queued-note sizing and adaptive completed-take action layout added. | a16 English AX5 portrait originals visibly confirm the full badge, contained note glyphs and stacked readable buttons. Completed-summary overlay still has a separate defect. |
| Capture reliability | Real pitch lock, continuous-hold and fresh screenshot/final-semantic checks preserved; startup failures retained separately; independent XCTest proceeds. Onboarding now verifies selection before continuing and stops misleading cascades. | a16 has not natively verified the later f937 steady-capture/prelaunch changes. Do not accept an old frame using later passing state. |
| Still-frame fixture save | f937 stops periodic same-string comet replucks for violin/cello/ukulele still leads; all strict lock checks remain. | Source reviewed; native validation pending. Violin/cello passed earlier; do not relabel those historical passes as failures. |
| Simulator priming | Bounded exact-session stage-rest observation replaces a guessed delay, with unchanged 300-second budget and cleanup reserve. f937 resolves/pins the data container before launch. | The signal is a rest/disappearance milestone, **not GPU completion**. Launch/container/termination failures remain real recorded failures. Native recovery is unverified. |
| CI diagnostics | Required gate retains core/app/Release/accessibility. Coverage floor 94%; observed core coverage about 95.3%. Native watchdogs, exact source binding, compact logs, separate original-frame exports and bounded traces added. | Cancelled/unassigned jobs are not passes. Source-only Python tests do not establish native behavior. |
| Scheduling save | f937 delays archive/TSan/iPad/matrix until the shared producer is terminal, retaining failure/skip eligibility and explicit-cancellation behavior. | Initial eligible macOS jobs reduce 9→5; actual account limit/priority/queue cause is not established. |
| Screenshot renderer | Medium/large phone roles, full containment, Arabic layouts, chord callout/checkmark clearance, iPad composition and hash/provenance guards improved. | Selected historical native recompositions reviewed; **no final 150-set inventory** is approved. |
| Watch | Historical updated capture work produced 104 originals across 52 app locales, with bounded review and upload mapping work. | Recheck exact source/input compatibility and store bundle before upload. Watch hardware/complication behavior is not fully verified. |
| Optional preview/audio work | Earlier renderer/cue/audio investigations and drafts remain recoverable in repository history/readiness drafts. | Initial submission scope is screenshots-only. Optional preview failures are not a reason to silently invent a video pass, nor a requirement to finish previews for this selected launch scope. |

### Major recent preservation commits

| Commit | Main purpose |
|---|---|
| `06af3503`, `e6f4d863`, `210cc080` | Compiler/typed-layout corrections and bounded simulator diagnostics; exact historical outcomes remain in Git/Actions. |
| `c1ec4ebf6e08fa3c0177be6bb2f20c6c8a611885` | Native Urdu font metrics, strict oracles, listing composition/capture improvements, TSan budget and opt-in reveal diagnostics. |
| `774253f53aeee27b9deaf2a0d1f9c9c433c14a51` | Measured Urdu drawing allowance, explicit shelf identity, Arabic hero bidi, lesson/onboarding test repairs, caption review and evidence packaging. |
| `22621292bd722d1bc029d65bfbb9c834943f7972` | Checked font bridge, native-baseline oracle, bounded scroll traces, contained-host/renderer diagnostics, early reveal checkpoints and still-frame artifact separation. |
| `a161bec505f827a32feaeb74c6e955d4d6db146d` | Same-ID resize restoration candidate, adaptive Along typography, diagnostic watchdogs and guarded priming-rest signal. |
| `f937c5d412956fd4d7b5468659f049103aee402f` | All nine remaining reviewed working files saved for this handoff: steady still capture, prelaunch container validation and scheduling. Native-unverified. |

Use the complete Git comparison/history for earlier commits rather than treating this table as a replacement for source history.

## 3. Final observed native state — not a completion certificate

Frozen monitoring snapshot: **2026-10-28 16:44:14 UTC**. It describes a16, **not f937 or later documentation commits**. The last code-save push can trigger new CI automatically and may supersede prior branch runs; those newer results were not awaited or certified as part of the owner-requested stop. Existing runs were not manually cancelled. All retry plans were rescinded.

- [a16 iOS run 40718128459](https://github.com/azerish25-ux/tuner/actions/runs/40718128459)
- [a16 Nightly run 40718128275](https://github.com/azerish25-ux/tuner/actions/runs/40718128275)
- [Exact job/artifact/status snapshot](docs/handoff/2026-10-28/manifests/native-snapshot.json)

| Gate / evidence | Observed outcome and boundary |
|---|---|
| Shared app/test build | Passed; current Swift candidate compiled. This is not execution of all app tests. |
| Core / lint | Passed, including the corrected font bridge; coverage about 95.3% above the 94% floor. |
| TSan | 472 tests, six skipped, zero failures. |
| Localization launch | Six tests, zero failures. |
| Unsigned archive | Passed. Not a signed build and not a substitute for the missing Release-job status. |
| App | Cancelled without assigned runner/steps. No a16 app test results. Earlier 226 app was cancelled during a new contained-host diagnostic; Urdu matrix was not reached. |
| Release | Cancelled without assigned runner/steps. Cause not established. One scoped retry request was rejected because the workflow was still active; no retry accepted. |
| iPad | Passed within its current captured English/normal-size scope; not all locales/AX5/RTL. |
| Lesson layout | Independent XCTest four tests/zero failures, including AX5 notes/quiz and PlayAlong Start/completed take. Overall job still failed its priming lookup. |
| Strict screen audits | Four tests/two failures: anonymous enforced contrast on TuneCheck and paywall. Later named diagnostic is not proof of the original anonymous callback's identity. |
| Strict tab audits | 32 enforced contrast callbacks. No overall accessibility pass. |
| Reveal diagnostics | Five tests/70 failures: 68 contrast callbacks plus Learn geometry-not-settled and Practice missing-dimming-overlay diagnostics. This does not resolve original strict failures. |
| Real-touch Songs / captures | Still executing at the frozen snapshot. Do not assume either passed; obtain actual final results from Actions. |
| First session | Independent XCTest running at snapshot after priming failure/cleanup pass. Earlier 226 reachability passed five tests but live Urdu glyph crop remained. |
| Matrix / launch | Cancelled without observed assigned-runner evidence for these latest jobs; no latest matrix/launch pass. Older passes remain revision-specific. |
| Aggregate readiness | Not green. No signing, upload, TestFlight processing, submission or public release performed. |

The current preserved nine-file save had **515 CI Python tests and 148 marketing tests passing**. The last full localization suite was **266 passing on a16**, before those test/host/workflow-only changes. Re-run all suites on the resumed tree. Historical 493+266+148=907 counts describe a16 portable checks, not a later native pass.

## 4. Everything still required before submission

### A. Finish application and test correctness

1. **Urdu rendering — real blocker.** Normal and AX5 originals show heading strokes cropped at the physical right screen edge. Five passing onboarding-action tests do not establish glyph containment. Run the four `WelcomeRendererGeometryTests` cases with the now-enabled XCTest watchdog; inspect full ImageRenderer and bounded original UIKit viewport measurements. Do not compensate with screenshot-derived offsets, stitch/crop acceptance pictures, cap Dynamic Type, or silently relax equality. Select a demonstrably correct rendering/layout implementation, then re-run existing eight production/independent-reference/bounds/collision cases, non-Urdu preservation and actual normal/AX5 onboarding captures.
2. **Songs rotation — real blocker.** Before a16, all three real-touch cases failed at the first landscape orientation. Normal card tops were below the dock; AX5's primary activation area was clipped. 226 traces retained the correct `rail.bass-songbook` ID, so another ID rename is not the diagnosis. a16 adds a fresh-width/generation-scoped one-shot restore with center tracking unchanged and top command only for a measured oversized row. Verify both directions, normal/AX5, first/middle/last items, both rotation cycles, same horizontal item and actual hittability. Inspect current trace, not assumptions about a final SwiftUI lazy-layout callback.
3. **Do not manufacture unit passes.** Historical proxy→binding tests, explicit command controls and contained-host diagnostics test different contracts. Original failures remain. The external-reader/private nested-reader interaction is documented, not proved a false positive. Any later contract replacement needs an explicit rationale and equivalent automated user/geometry coverage; do not write expected bindings into a readback test.
4. **Completed AX results summary — unapplied reviewed proposal.** Fixed-height overlay still truncates tempo/grade/timing labels and clips Share. Review `patches/along-intrinsic-results.patch`, its base hashes and source review; it gives the existing compact AX summary intrinsic height and retains result/spoken-cue action semantics. Compile, inspect complete labels/Share/focus/Continue, and verify normal/RTL/short-height layouts. Refresh privacy source binding after applying production changes.
5. **TuneCheck reward overlap — unapplied reviewed proposal.** A transient chip burst can cross the tuning instruction. The archived six-file reward-band proposal deliberately contains that local effect in a 60-point faded band, adds 16 points of layout space and leaves the main listening orb unchanged. It is not a promise that all full rings remain. Its SE3/375×667 eight-case native runner/component coverage has not executed; wire/review the intended invocation and validate the entire short-screen lesson before acceptance.
6. **Finish capture fixes.** Verify f937's steady violin/cello/ukulele lead frames against real continuous lock plus fresh picture/final AX status. Earlier 226 ukulele failure was associated with periodic synthetic re-plucks; that is not a waived product lock. Verify onboarding choice acceptance/route progression, every required capture name and absence of wrong-screen substitutions.
7. **Resolve CI/setup issues without hiding them.** Test prelaunch container validation, the genuine rest signal, cleanup, native watchdog recovery and separated evidence exports. A launch timeout is distinct from a post-launch lookup timeout. Unknown PID, empty image, server errors, cancelled/unassigned jobs and partial results are not success. If the job never ran, retry the specific job after the workflow is terminal; preserve prior failures. A specific-job rerun also reruns dependent aggregate/publication jobs, not independent checks. Do not repeatedly retry an API-rejected active workflow.
8. **Complete current native suites.** Core, app, Release, sanitizer, all required accessibility partitions, complete matrix, first-session, full tour/captures, iPad and the relevant Watch checks must have source-bound evidence. Do not inherit earlier green results blindly. Distinguish job status from independent XCTest status when startup diagnostics fail.

### B. Accessibility and multilingual visual QA

9. **Resolve every applicable accessibility finding or individually justify a supported disposition.** Unknown/anonymous callbacks, incomplete audits and hidden/partly faded targets remain unresolved. Current-source identity, viewport, reachability and visible glyph/backing evidence are required. Fifteen clear-state Songs labels were reviewed: ten stopped triggering contrast callbacks after reveal and five persisted. Fourteen observed contrast bounds were at least4.5; catalogue28 remained qualified, not a proved paint defect. Those observations are neither runtime authorization nor a blanket exception. The inactive callback-raster draft is preserved only for research and has unrun native cases; do not activate it automatically or resurrect the superseded receipt architecture.
10. **Run final all-language checks and native localization matrix.** Keep 52 app languages, 51 translated lesson locales/6,090 keys and 50 listing payloads distinct. Use actual Xcode exports, strict interface/lesson/legal/permission/VoiceOver validation and current review hashes. AI structural/semantic review does not certify every natural-language rendering. Inspect RTL, fallback fonts, large text, numbers, truncation, VoiceOver labels and full instruction/control visibility. Do not reduce shipped languages or critical coverage to get a pass.
11. **Physical hardware remains waived/unverified by the owner.** Preserve that limitation for microphone start/stop, interruptions, latency, speaker leakage, wired/Bluetooth routes, haptics, Watch and physical accessibility. It is not a passed test or a waiver of simulator/account/App Store requirements.

### C. Finish the complete listing media package

12. **Recreate pilot then full native media on the final app source.** Planned phone/tablet inventory is 50 locales × three roles =150 sets /75 two-locale shards /1,100 JPEGs: nine medium-phone, nine large-phone and four iPad images per locale. Medium `iphone`:1206×2622; large `iphone-large`:1320×2868; iPad landscape:2752×2064. Keep actual dimensions/capture identity/source hashes; no stretching, substituted sizes, invented device screenshots or wrong-language fallback. Apple's live specifications still need a final recheck.
13. **Do not promote partial pilots.** Historical210 pilot mechanically passed only Arabic medium/large phone and German iPad sets; six other locale/device sets failed warmup before XCTest. Other historical raw images and reviewed recompositions exist but do not constitute final-source full coverage. Re-run source-bound native captures and current composition, then visually inspect every selected store image. Require manifests, raw/rendered hashes, exact locale/device slots, complete captions/glyphs and clean framing.
14. **Reconcile Watch separately.** Preserve historical104 native images/52 app-language work and the 50-listing mapping. Verify current Watch input hashes, selected100-image store mapping, complications and actual upload requirements. Old Watch acceptance cannot substitute for missing phone/tablet evidence.
15. **Upload only accepted media into the50 saved App Store locales.** Recheck names/descriptions/keywords/support URLs/captions against final shipping features and approved brand. Saved draft text is not complete listing readiness. All `release_ready` flags remain false until their genuine required evidence is present.
16. **Optional previews and Game Center.** Selected first-release scope is screenshots-only with no App Preview upload; Game Center is disabled in release source. Keep those explicit not-applicable states rather than fake passes. The older preview/audio preparation draft remains archived for optional later work, not a mandatory first-submission gate under this policy.

### D. Commerce, signing and submission

17. **Implement the still-missing authenticated pricing evidence verifier.** The175-country proposal has manual exceptions and unresolved authenticated identifiers. Structural country-policy checks are not live schedules. `validate_country_pricing_policy.py --require-complete` deliberately remains blocked until a reviewed active-territory/price-point importer and source-bound verifier exist. This is still developer work, not merely an owner checkbox.
18. **Configure and test the real products after owner setup.** Local StoreKit fixtures do not prove live App Store Connect product IDs, storefront prices, eligible offers, purchase/pending/cancel, restore, renewal/expiry, refund/revocation or entitlement behavior. Preserve country pricing independent of UI language. See exact IDs and owner steps below.
19. **Merge only the reviewed, validated source to main.** PR#3 is unmerged. Required branch/gate rules remain. The manual Apple delivery preflight requires exact current main plus real applicable evidence. Do not bypass it or assume a docs-only main commit is the shipping candidate.
20. **Signed build, Apple processing, final disclosures and submission remain.** Reconcile marketing version with the observed1.0 draft; the delivery workflow defaults to2.0.0 and must not be dispatched blindly. Use a unique build number. After explicit owner authorization, validate signing/profiles/entitlements for all targets, upload, wait for processing, verify TestFlight/sandbox and complete accurate privacy/age/content-rights/export-compliance/review-contact information. Submission and public release are separate owner decisions. Some of this verification can only occur **after** the owner finishes account configuration; configuration alone cannot guarantee immediate submission readiness.

## 5. Unapplied and historical proposals

| Material | Current use |
|---|---|
| [Intrinsic AX completed summary](docs/handoff/2026-10-28/patches/along-intrinsic-results.patch) | Reviewed, **unapplied**, native-unverified. Primary next visual fix. |
| [TuneCheck reward band + compact checks](docs/handoff/2026-10-28/archive/preserved-patches/tunecheck-reward-band-proposal.patch) | Reviewed, **unapplied**, native-unverified. Check full short-height layout and invocation prerequisites. |
| [Current-callback raster draft](docs/handoff/2026-10-28/patches/current-callback-raster-diagnostics.patch) | Inactive diagnostic research; no audit exemptions authorized, native wiring/tests unrun. |
| [Nine-file preservation diff](docs/handoff/2026-10-28/patches/pending-readiness-working-tree.patch) | **Already committed in f937. Provenance only—do not apply again.** |
| [Priming/scheduling provenance](docs/handoff/2026-10-28/TECHNICAL-HANDOFF.md) | Already committed in f937; overlap the nine-file diff. |
| [Twelve-patch historical archive](docs/handoff/2026-10-28/archive/PATCH-INVENTORY.md) | Exact frozen copies and statuses. Most are integrated/superseded; not a batch to apply. |
| [Older optional preview/audio draft](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/readiness/drafts/README.md) | Optional screenshots-only-launch backlog; do not silently claim native video acceptance. |

Every patch must be checked against its base/current source before application, and changed production source needs an honest evidence refresh. Do not use a proposal's portable tests as native proof.

## 6. Practical verification commands and evidence recovery

Use Python3 and the project dependencies. Shell examples below are POSIX; on Windows use equivalent PowerShell commands or the interpreter path in the virtual environment. No cloud-local executable path is required.

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r tools/marketing/requirements.txt
python -m unittest discover -s tools/ci -p 'test_*.py'
python -m unittest discover -s tools/l10n/tests -p 'test_*.py'
python -m unittest discover -s tools/marketing/tests -p 'test_*.py'
python tools/verify-ios-resources.py
python tools/curriculum/build.py --check
python tools/l10n/report.py --check --strict --out ci-out/l10n
python tools/l10n/lessons.py --strict
python tools/marketing/screenshots.py --check
python tools/ci/validate_country_pricing_policy.py
# Deliberately still blocked until authenticated completeness is implemented:
python tools/ci/validate_country_pricing_policy.py --require-complete
```

Install/run actionlint and the actual Swift/Xcode checks specified in the committed workflows. Caption rendering needs the documented pinned fonts and correct shaping support; a dependency installation alone does not produce approved media. Native translation proof uses the authoritative Xcode English export, not only regex/source scans.

With GitHub CLI authenticated locally (never paste tokens into source):

```sh
gh run list --repo azerish25-ux/tuner --branch codex/app-store-readiness-gates --limit 30
gh run view RUN_ID --repo azerish25-ux/tuner
gh run download RUN_ID --repo azerish25-ux/tuner --name ARTIFACT_NAME --dir evidence/RUN_ID
```

Use the snapshot's exact run/job/artifact IDs and SHA256 values; inspect the actual tested PR merge and tree. The old assistant connector's512MiB limit is **not a GitHub or app requirement**; your CLI may retrieve larger full archives. Prefer compact logs and original-frames subsets for fast triage; retain originals, not regenerated pictures. Artifacts expire. Missing/zero-byte images and incomplete `.xcresult` bundles do not become evidence because a filename exists.

Read `.github/workflows/ios.yml`, `nightly.yml`, `listing-assets.yml`, `localization-matrix.yml`, `watch-captures.yml`, `caption-typography.yml`, and `apple-delivery.yml` on the working branch. Do not dispatch Apple delivery during routine QA. A16 source-only review and older main README claims do not authorize signing/upload.

## 7. First instructions for the next local Codex session

> Read this entire README and the technical/Apple handoff pages. Work from `codex/app-store-readiness-gates`, preserving f937 and the packaged proposals. First inspect current GitHub results after the stop; do not assume the 16:44 snapshot is final. Prioritize a complete app native run with watchdogs/Urdu diagnostics, actual same-card rotation evidence, and the unapplied completed-summary visual repair. Fix demonstrated application defects before adding more generic proof frameworks. Preserve strict meaningful checks and raw failure history; explain any test-contract correction. Re-run final all-language/media/commerce/release gates. Keep Apple legal, identity, tax/banking, API-key creation, signing/upload, submission and release approvals distinct. Never commit credentials. Commit and push reviewed increments and record exact verification scope.

The owner wanted frequent updates and verified pushes. Do not confuse passing hundreds of portable checks with being almost submission-ready. Report the remaining release blockers plainly. No further autonomous work from the prior assistant is scheduled as part of this handoff.

## 8. Apple Developer and App Store Connect — complete owner checklist

The following checklist is also maintained as [a standalone page](docs/ios/APPLE-OWNER-CHECKLIST.md). It records prior observations and current documentation, not a fresh account audit. No passwords, verification codes, private keys, tax/banking details or identity documents belong in this repository.

### Apple Developer / App Store Connect — owner checklist

**Documentation checked: 28 October 2026. Account status below is a prior verified snapshot, not a new portal inspection.** This checklist neither changes an account nor authorizes agreements, credentials, signing, upload or release. It does not answer legal or tax questions for the owner.

At **00:09 on 28 October**, the owner said this setup was **not yet done** and that they would notify us after completing it. That remains the handoff boundary. No later completion is assumed; no login, verification-code or private-document request is outstanding from this checklist.

#### 1. What already exists, and what is still unknown

| Item | Last verified / recorded state | What it does not prove |
|---|---|---|
| App record | Timbre, Apple ID **6827721551**, SKU **timbre-ios-001** | No public release, processed build or approval implied |
| Developer team | **L8BZ8KG2WB** | Membership renewal, current permissions and signing still need action-time verification |
| Listing drafts | **50 names/subtitles and 50 version-text drafts saved** | These are drafts, not approved listings or complete screenshot uploads |
| Screenshots | **Not uploaded** at last verification | Local compositions/pilot captures are not portal uploads |
| Identifiers | Four explicit bundle IDs and one App Group registered; see below | Registration alone does not prove correct capability associations or signed profiles |
| Free agreement | **Active** at last verification | Does not replace the Paid Apps Agreement for IAP |
| Paid Apps Agreement | **New** at last verification | Not accepted/active; do not mark it complete |
| Legal entity / DSA | **Incomplete** at last verification | No identity/trader determination has been made on the owner's behalf |
| Bank and tax | **Unverified** | Not a claim that they are absent, submitted, approved or payable |
| Game Center | **Off** for this release | Do not enable it as an incidental setup step |
| CI signing / live commerce / TestFlight | **Not established by this checklist** | Unsigned simulator passes and local StoreKit fixtures are not proof |

Registered identifiers:

- Main app: `com.shahradazerisharghi.timbre`
- iOS widgets: `com.shahradazerisharghi.timbre.widgets`
- Watch app: `com.shahradazerisharghi.timbre.watchkitapp`
- Watch widgets: `com.shahradazerisharghi.timbre.watchkitapp.widgets`
- App Group: `group.com.shahradazerisharghi.timbre`

Use the [existing app record](https://appstoreconnect.apple.com/apps/6827721551), not a new app/SKU. Source configuration remains in `ios/project.yml`. Recheck the four targets' App Group associations and required capabilities without enabling Game Center. Optional MusicKit configuration and its remaining verification are documented in [Apple delivery](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/APPLE-DELIVERY.md#8-your-songs-and-apple-music-musickit-owner-steps).

#### 2. Owner completes the business/account blockers

These are owner-operated steps for the correct team, not permission for an assistant to accept terms or submit personal information.

##### A. Verify the legal entity

- [ ] In [App Store Connect](https://appstoreconnect.apple.com/), open **Business → Agreements** and review the legal entity already associated with this membership. The last observed screen showed **Edit Legal Entity**; that historical label does not guarantee that today's UI or state is unchanged. Use the existing business record, not a new registration.
- [ ] Supply only accurate information from the owner's own records in Apple's fields. Do not select an organization type, residency, address or identifier merely to get past validation.
- [ ] Distinguish completing missing fields from changing an existing membership entity. Apple says membership name/address changes require a verified request through membership details/Apple Support; do not treat an Edit button as authority to replace the contracting entity. Keep any requested identity/business documentation inside Apple's approved process. [Apple account-update guidance](https://developer.apple.com/help/account/membership/updating-your-account-information).

##### B. Review agreements personally

- [ ] The **Account Holder** reviews any pending Developer Program terms and the **Paid Apps Agreement** in **Business → Agreements**. For the Paid row, use **View and Agree to Terms** only after personally reading and deciding to accept. Apple notes that acceptance cannot be undone. Even a free-download app needs this agreement to offer IAP.
- [ ] Complete the required follow-on information and wait for the actual agreement status to become **Active**. Record the displayed status and date; a successful click is not activation evidence. [Apple agreement instructions](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).

##### C. Complete tax and bank information

- [ ] After accepting the paid agreement, use **Business → Agreements → Tax Forms → Add Tax Info** for the forms Apple presents. The required forms depend on the enrolled entity/jurisdiction; Apple requires a US tax form for all developers under the paid agreement. The owner or their qualified adviser determines the applicable form, tax residency, beneficial-owner information and any treaty claims. Do not copy guessed answers from a sample. Submit and retain the actual processing status. [Apple tax instructions](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information).
- [ ] In **Bank Accounts → Add Bank Account**, enter the owner's actual eligible account details, account currency, routing/IBAN where applicable, and bank-account-holder information. Verify against the bank's records; do not substitute an intermediary bank or invent missing fields. Account Holder, Admin or Finance can enter information, but changes initiated by Admin/Finance may require Account Holder approval. Tax requirements must also be completed for processing. Confirm the final bank status, not just that a row exists. [Apple banking instructions](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information).

**Keep tax IDs, banking details, identity scans and legal documents out of this repository, chat, issue comments and CI artifacts.** If uncertain, obtain advice from the relevant professional or Apple; this document is operational guidance, not legal/tax advice.

##### D. Complete DSA declarations accurately

- [ ] Account Holder/Admin: **Business → Agreements → Compliance → Digital Services Act → Complete Compliance Requirements**. The owner determines trader status; uncertainty belongs with their legal adviser. Do not select non-trader just to avoid contact verification.
- [ ] For a trader declaration, complete Apple's contact verification and any requested documentation/certification. Trader contact information is displayed publicly for EU distribution; inspect exactly what will be published. Organization and individual requirements differ. Do not paste those private inputs into the handoff.
- [ ] Reconcile this app's declaration under **Apps → Timbre → App Information → App Store Regulations and Permits → Digital Services Act**. Apple requires a trader-status declaration even if EU distribution is not selected. Verify account-level processing and app-specific status before claiming completion. [Apple DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).

#### 3. Configure commerce only after owner decisions

Preserve these existing product identities; verify rather than duplicate existing portal records:

| Product ID | Intended type |
|---|---|
| `timbre_pro_monthly` | Monthly auto-renewable subscription, group **Timbre Pro** |
| `timbre_pro_annual` | Annual auto-renewable subscription, same group/Pro entitlement |
| `timbre_plus_lifetime` | Non-consumable lifetime Pro access; the historical ID does not mean a weaker tier |

- [ ] Verify the group, durations, product availability, localized names/descriptions, review screenshots and review notes. Determine any trial/offer policy explicitly; no trial is assumed from test fixtures. Configure through the app's **Subscriptions** and **In-App Purchases** sections. Follow Apple's [IAP configuration overview](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/) and [first-IAP submission instructions](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/).
- [ ] Do not enable optional annual price-test products, Family Sharing, grace-period experiments or promotional offers merely because code supports them. They require separate decisions and verification; [Family Sharing cannot be turned off for a product once enabled](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases).

##### Country/storefront pricing is still a proposal

The [country-pricing policy](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/readiness/pricing/country-pricing-policy.md) and its JSON are the existing proposal, **not configured or verified live prices**. Recorded anchors are USD **3.99 / 19.99 / 59.99** and CAD **4.99 / 24.99 / 74.99** for monthly/annual/lifetime. These are not confirmed Apple price points, approval to apply them, or a revenue forecast.

- [ ] Owner reviews the proposed affordability approach and every intended storefront before configuration. The recorded public inventory has 175 countries, with Anguilla/Montserrat classification unresolved and Kosovo's authenticated territory mapping unresolved; that prior public research has **not** been rechecked here.
- [ ] Resolve authenticated app/product availability, Apple's actual territory identifiers, available currencies/price points, taxes/proceeds and dates. Use the same three product IDs across storefronts, not one product per language/country. The customer’s storefront—not UI language, IP or device region—selects the offer. [Apple subscription availability](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-availability-for-an-auto-renewable-subscription).
- [ ] In each subscription's **Subscription Prices**, review the starting-country price and every offered equivalent/override before confirming. Non-consumable pricing has its own schedule. Apple's equalization is not the proposed affordability policy; do not assume subscription prices are automatically maintained like other pricing. [Subscription pricing](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions), [IAP pricing](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase).
- [ ] After configuration, independently read back schedules and test actual localized StoreKit prices. Structural policy validation is not completion; the current `--require-complete` gate intentionally remains blocked until its authenticated evidence verifier exists. Never flip readiness flags to bypass it.

#### 4. Secure CI signing credentials — no secrets in the repository

The current [manual delivery workflow](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/.github/workflows/apple-delivery.yml) uses Xcode automatic provisioning/signing plus an App Store Connect API key. It does not currently require a manually uploaded `.p12` or provisioning-profile secret. Do not add a parallel signing mechanism without review.

- [ ] Account Holder requests API access if needed. An authorized Account Holder/Admin creates a dedicated **team** key under **Users and Access → Integrations → App Store Connect API → Team Keys**, with the least role privileges that actually permit this workflow's provisioning/upload tasks. Do not default to broad Admin access to resolve a failure. Team keys cover all apps; they cannot be limited to Timbre alone. [Apple API-access guidance](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
- [ ] A user-scoped individual key is **not interchangeable** here: Apple excludes individual keys from provisioning endpoints, while this workflow uses `-allowProvisioningUpdates` and an issuer ID. Download the private key once, store it securely, and revoke it promptly if compromised. Never put `.p8` contents in source, chat, screenshots or client code. [Apple key types and security](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api).
- [ ] An authorized repository administrator configures the protected **apple-delivery** GitHub environment, restricted to the approved delivery branch and owner approval before credentials are released. Confirm these protections actually exist. Use provider secret fields only:

| Environment secret | Required value |
|---|---|
| `APPLE_TEAM_ID` | `L8BZ8KG2WB` |
| `APP_STORE_CONNECT_KEY_ID` | The authorized team's key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Its issuer UUID |
| `APP_STORE_CONNECT_API_KEY_P8` | Raw PEM private-key contents, **not Base64** |

The workflow writes the key with restrictive temporary permissions and deletes its temporary signing directory in an always-run cleanup step. Do not print the values to troubleshoot. Environment-secret presence is not proof of successful authentication or signing. Creating persistent credentials and dispatching upload are separate owner-authorized actions, not actions performed by this checklist.

#### 5. What still must pass after the owner finishes setup

1. **Recheck account status.** Record non-sensitive statuses and verification time for legal entity, agreements, DSA, bank/tax, identifiers/capabilities and intended prices. Owner confirmation is welcome but does not itself certify signed binaries or live purchase behavior.
2. **Exact-source delivery gates.** Follow [Apple delivery](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/APPLE-DELIVERY.md) and the [release checklist](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/RELEASE-CHECKLIST.md). The current main revision, latest required native jobs, source-bound privacy/listing evidence and localization gates must genuinely pass. Historical green runs, cancelled jobs, draft metadata and source-only tests cannot replace them.
3. **Signed archive.** After explicit authorization for the revision/version/build/destination, verify Xcode signs all four targets for the intended team; inspect embedded profiles, App Group/capability entitlements, bundle/version/build consistency and the archive-scope report. Registered IDs alone do not prove this. No signing/upload is dispatched merely because the owner completed business forms.
4. **Apple processing/TestFlight.** An upload receipt is not processed-build availability. Check processing errors, compliance questions and the exact build in TestFlight. Invite only authorized testers; external beta testing has separate review requirements. An internal-only export cannot be reused for external testing or App Store submission. [Apple upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
5. **Real configured-product sandbox checks.** Verify product loading, storefront price/currency, eligible offers, purchase/cancel/pending flows, restore, entitlement changes, renewal/expiry and refund/revocation behavior. TestFlight uses the sandbox; accelerated renewals are not production billing. Local `.storekit` fixtures and a TestFlight install alone do not establish live product correctness. No real-money purchase is required merely to prove sandbox behavior. [Apple sandbox overview](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox/), [TestFlight IAP testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/).
6. **Listing and submission.** Reconcile the 50 saved text drafts with the exact shipping build. Upload only accepted native-backed screenshots into the correct locale/device slots after separate upload authorization; screenshots remain unuploaded in the last account snapshot. Complete accurate privacy, content-rights, age-rating, export-compliance and review-contact answers; the owner supplies legal determinations. Game Center stays off. Initial scope remains screenshots, not App Preview uploads. Submission and public release remain separate approvals.

##### Non-sensitive completion handoff

When the owner reports completion, record only status/date or a redacted receipt: legal-entity verification; Free/Paid agreement statuses; tax/bank processing statuses; DSA verification/app declaration; whether the protected CI environment is configured; which pricing decisions were approved/applied. Do **not** include account numbers, tax IDs, addresses, verification codes, private keys, identity scans or legal attestations in repository evidence. Leave every unverified item explicitly unverified.

## Historical developer handoff — earlier 27 October 2026

The previous README is preserved in Git at [7a0c7a45](https://github.com/azerish25-ux/tuner/blob/7a0c7a45cb4c5efe3ada881b049634efc20b0343/README.md). Its old counts, pending patches, revisions and continuation directions are historical, not current status. The dated handoff above supersedes them; repository history preserves the earlier work.
