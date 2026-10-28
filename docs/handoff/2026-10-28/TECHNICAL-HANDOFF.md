# Technical continuation handoff — 28 October 2026

## Stop boundary and source of truth

Development stopped at the owner's request so they can continue on their own laptop with Codex. This is a documentation/package handoff, not evidence of release readiness or approval to merge application code, sign, upload, submit, or activate audit exceptions. The app is **not submission-ready**. Preserve original failures and distinguish source review, portable tests, simulator execution, visual review, physical-device testing, and Apple-account approval.

Source snapshot updated: **2026-10-28, approximately 16:56 UTC**. The preservation commit was pushed and fetched; native evidence remains the separate 16:44 snapshot below. Pre-documentation locally verified refs:

| Ref | Commit | Meaning |
|---|---|---|
| `main` / `origin/main` | `7a0c7a45cb4c5efe3ada881b049634efc20b0343` | Earlier published developer handoff; not the current application candidate. |
| `codex/app-store-readiness-gates` / its origin ref | `f937c5d412956fd4d7b5468659f049103aee402f` | Published preservation commit containing all nine reviewed changes; native-unverified. |
| Last native-tested branch source | `a161bec505f827a32feaeb74c6e955d4d6db146d` | Parent of the preservation commit; native results below bind here, not to f937. |
| Tested PR merge checkout for a16 evidence | `52f6c14ffc807db7be184e16416e508c69f2c870` | Do not confuse with branch HEAD or inherit results across revisions. |

Main is an ancestor of readiness; readiness is **57 commits ahead**, zero behind, in this snapshot. The readiness working tree is clean. All nine formerly pending files are now committed in f937 (tree `469926c5835eb3f057fa64d1b8f2a46de50e5ca1`); the separate Along proposal remains unapplied. Neither belongs to the older a16 native results. The root README supersedes its older active/historical sections. Use exact source commits rather than treating historical results as current.

## Published preservation commit — exactly nine reviewed files

The portable [combined provenance patch](patches/pending-readiness-working-tree.patch) captures exactly the nine-file difference from a16 to the already published f937 commit. **Do not apply it to f937 or the current readiness branch again.** Its SHA-256 is **`9eddd4d64960c04dbaf4b6454da709c4581175f4b3601b6091e927ea4738f3a7`**. [The preservation manifest](manifests/preserved-readiness-changes.json) records every a16/f937 file hash. These are reviewed candidates, **not native-verified fixes**. They do not alter production app source or the privacy source inventory.

1. **Steady still-image capture, three files:** `ios/TimbreUITests/TimbreUITests.swift`, `tools/ci/test_capture_check.py`, `tools/marketing/tests/test_listing_assets.py`. Violin/cello/ukulele still leads stop requesting periodic comet replucks. They retain real `lockedTunerFrame`, continuous hold proof, fresh screenshot, and final semantic-state rejection. Explicit animation capability remains. Native capture correction is unverified; do not replace a failed capture with later passing state.
2. **Prelaunch priming-container resolution, four files:** `tools/ci/simulator_priming_signal.py`, `simulator_warmup.py`, and their two `test_*.py` files. Resolve the installed app's validated data container **after install, before launch**, avoiding that service request during startup. Preserve the same 5-second lookup, 300-second total budget, 30-second cleanup reserve, exact session/PID/time/schema validation, fresh namespace, no-follow reads, owner/scope checks, and pinned container identity revalidation immediately before accepting bytes. Missing/replaced/foreign/error signals fail; no success fallback. Independent 75 focused tests passed. Real simulator improvement is unverified.
3. **Initial Nightly scheduling, two files:** `.github/workflows/nightly.yml` and existing selected `tools/ci/test_tour_shards.py`. Archive/iPad/accessibility-matrix/TSan wait for terminal `tour-build` through `needs`, but `always() && !cancelled() && (original predicate)` preserves independent evidence after failure/skip and blocks explicit workflow cancellation. Accessibility-only PRs still run their matrix after the unneeded producer skips. Actual shared-product tour consumers still require producer success. Only four job headers change; all steps, tests, timeouts, artifacts, permissions and existing concurrency policy are unchanged. Nineteen focused contracts, 480 modelled truth-table cases, DAG checks, and actionlint passed. Initial eligible macOS roots for concurrent iOS + captures-labelled PR workflows fall **9 → 5**; this is not a concurrency cap, priority guarantee, account-limit determination, or proof of the queue's cause.

The separate priming and scheduling patches are retained only for review provenance. **All their changes are already committed in f937; do not reapply any of these patches**:

| Patch | SHA-256 | State |
|---|---|---|
| [Priming preflight](patches/priming-container-preflight.patch) | `a43eebae4c403c37b617a32870bddcd51b6278d7803b3b6fc81f694103474ae1` | Committed in f937; provenance only. |
| [Nightly scheduling](patches/nightly-initial-load.patch) | `962cfd55cc1841e395c495c095dae1396deca74acb4f93b41bcf5cd5d24018e5` | Committed in f937; provenance only. |

Observed portable checks before preservation (identical nine-file bytes): **515 CI Python tests passed**; marketing **148 passed**. Localization **266 passed** earlier on a16, before these host/test/workflow-only changes; rerun in the final restored tree rather than inheriting the older result. Actionlint passed for scheduling. These numbers do not certify simulator UI or native compilation.

## Separate reviewed proposal — not applied

[Along intrinsic completed-results patch](patches/along-intrinsic-results.patch), SHA-256 **`9b37eb08214ac3ddba9b02568015536b60d12f8f5fa614c8d8cd132ee631c1d4`**; [four-file base/candidate manifest](manifests/along-summary-files.json).

This changes `Highway.swift` only for accessibility-size completed results: existing compact summary content gets intrinsic height within the existing outer scroll view instead of overflowing a fixed 420-point overlay. Stats/tempo labels flow without type caps. Normal runway/results-panel bodies and delayed result-focus logic are preserved. The old underlying runway's guarded, dynamically named spoken-cue action is transferred to the AX result heading only; no whole-results hiding/aggregation is added. Actual result action closures remain.

The content is **the existing compact summary at full intrinsic height**, not the noncompact timing-strip variant. Component tests are not fabricated completed-session evidence; the real-take UI test retains previous assertions and adds full-label/Share visibility inside the identified scroll viewport. Twelve focused contracts and a 520-test source overlay passed; independent source/API review and patch checks were clear. **Native compilation, rendering, VoiceOver action exposure, and live completion/Continue behavior remain unverified.** Production candidate SHA-256: `913d73adf6294640c580db47903c307be2daf9eb2f33d24bf5dd7d70888f6447`.

This proposal was prepared against a16; its four affected file hashes remain unchanged in f937. If it is later applied, it changes production source and therefore requires a narrowly reviewed privacy source-inventory refresh. The present receipt must not be silently rebound before that review.

## Inactive contrast diagnostic proposals — archival, not a recommended next fix

The current reviewed diagnostic draft and superseded architecture status are recorded in [their manifest](manifests/inactive-contrast-proposals.json). Neither is applied or authorized to dismiss an audit finding. Do not blindly apply these older drafts to f937 or prioritize more proof machinery over correcting an evidenced visual defect.

- [Current-callback raster diagnostics](patches/current-callback-raster-diagnostics.patch), SHA-256 `5fbc081b4594f7facb8182811b8b7ff46e6d428b41800c9d4674c68effaa5dc4`: recorded 13 portable tests, 268 raster negatives, 18 occluded rejections, and ten full reference PNG cases; twelve native tests prepared but none run. Ten reference-support candidates were visually reviewed; two later cross-launch raster mismatches remain rejected, while the other eight remain diagnostic candidates, not exemptions. Complete-reference support review is not current callback authorization. Actual pre/post context wiring, effective rendering traits, temporal coupling, and native PNG/zlib compilation remain open. Sampled stability is not atomic coupling to the audit's measurement.
- **Superseded, excluded from the portable integration bundle:** the old native receipt-collector/full installed-build-attestation architecture is not an active proposal. Its locally archived patch hashes to `38ea71291d057623ed14fdf798b0d66b314fdf1e6375ccfc429c3d4941abcb89`, but it was explicitly abandoned as unnecessary for the narrow actual-pixel property. Do not resurrect it as a prerequisite or recommended integration. Startup receipts never established individual reveal-screenshot/target coupling.

All audit/proof authorization stays **false**. These are not fixes and do not clear any original strict contrast assertion.

The 774 revealed-Songs review was evidence, not a paint patch: fifteen requested strings had complete visual support in verified before/after originals. Fourteen observed core/backing bounds were at least 4.5; catalogue “28” remains qualified (whole-support bound 4.205 includes nonadjacent artwork grain; examined digit-adjacent candidates were at least 4.929). Antialias fringes and hidden backing were not proven, so this did not justify paint correction or audit clearance. Review receipt SHA-256 `5420ce8cc6b9d94249155d990e3c57ca9ea7a13223e4af696b7212a102a84b8b`; measurements SHA-256 `c914b9ed760e713d10c8fd6b64a4055e6e745c941314a1bdf881a84da30a9d76`. Original artifact ID `12814747299`, archive SHA-256 `4e2ad730783e6464b5c10b424ee9b9b55cb6d2498f089125e3867da4a1021ef2`. These are prior-revision findings, not current a16 acceptance. All originally obscured/anonymous/unknown targets, unsupported shapes, and unreviewed E7 remain unresolved; later callback absence or reveal reachability is not proof.

## Native status at the documentation stop

The [16:44:14 UTC snapshot](manifests/native-snapshot.json) binds all 16 jobs and 33 artifact records to a16 and its tested PR merge. Both [iOS run 40718128459](https://github.com/azerish25-ux/tuner/actions/runs/40718128459) and [Nightly run 40718128275](https://github.com/azerish25-ux/tuner/actions/runs/40718128275) remained in progress, attempt 1. Monitoring/retry plans stopped at the owner's instruction; existing jobs were not cancelled.

- Core/lint and shared simulator producer passed; unsigned archive and TSan passed (472 tests, six skipped, zero failures). iPad passed mechanically; its current originals were not visually accepted.
- Accessibility failed: screens four tests/two contrast assertions; tabs one test/32 strict contrast assertions; reveal five tests/70 assertions (68 contrast plus two incomplete diagnostics). Localization partition was six tests/zero failures. The required gate failed.
- App, Release, accessibility matrix, and launch jobs were cancelled with runner ID zero and zero steps. No app unit/renderer matrix, Release-job build, matrix variant or launch test ran. Shared producer compilation is separate evidence, not a replacement test pass.
- Independent lesson UI tests were four/zero, but the job failed its retained priming lookup failure. English portrait AX5 originals support the three earlier ready/cue/action typography corrections; the distinct completed-summary clipping remains.
- SongRails, captures, and first-session independent XCTest were still running. Their current outcomes and a16 rotation/Urdu results were unknown at the stop.
- One earlier authorized Release-only retry request was rejected; no retry was accepted and app was not retried. Do not retry or cancel as part of this documentation handoff.

## Unresolved native issues and interpretation

- **Song shelf rotation:** 226 actual-touch tests failed all three cases at the first landscape transition, not a later portrait return. Normal LTR/RTL terminal-card tops were approximately 461.7/463.7 points, below the tab-bar top at 338; AX5 had no valid terminal-card hit point. Three diagnostic traces showed the correct shelf ID remained bound while geometry moved; horizontal terminal selection remained. Typed row identity alone had not fixed it. A16 contains a reviewed one-shot resize restoration candidate: capture the current shelf for a real size generation, require fresh matching row geometry, consume before one explicit command, center fitting rows/top oversized rows, cancel on user interaction/external target/removal/disappearance. Tracking anchor stays `.center`. **No documented lazy-layout-completion barrier exists; later remeasurement can displace it. Treat a16 as an experiment until unchanged actual-touch gates pass.**
- **App fixture failures/timeouts:** old proxy-readback, explicit-binding and resize failures remain historical failures. A16 app job was cancelled with no assigned runner and zero steps: no new app compiler/XCTest result. Do not call it a code timeout. Earlier 226 app reached 181 started/180 finished and stalled at the contained-host RTL diagnostic; original command tests had 11 assertions. The reviewed 120-second per-test watchdog and enabled XCTest timeouts preserve failures and global budgets. Diagnostic snapshots using unsynchronized current-state rendering are not pixel acceptance.
- **Priming:** failures are distinct. A16 lesson launch succeeded (PID recorded), then its 5-second postlaunch container lookup timed out before reading a rest signal; later terminate succeeded and cleanup was confirmed. Captures instead hit launch timeout, unknown-PID probe timeout, then termination timeout. The prelaunch proposal addresses the first path only. Existing DEBUG rest milestone means the real stage was resting/detached, **not GPU compilation complete**. Independent XCTest still runs where permitted; retained priming failure still fails the job.
- **Urdu heading:** first-session reachability success is not unclipped glyph proof. Earlier actual AX5 screenshots showed physical-right-edge loss; strict native raster comparisons and the renderer matrix must be read together. The exploratory matrix records exact differences and bounded-host viewport originals; it does not declare all renderer variants valid. Do not replace the original eight strict production gates with exploratory comparisons.
- **Contrast/accessibility:** strict audit failures remain. Stable IDs, reveal frames, raster/profile support, or diagnostic collectors are not exemptions or sufficient authorization to suppress callbacks. All audit-exception authorization must remain false. Read the separate current native-evidence/contrast inventory before choosing a real visual fix.
- **Listing/release:** the final accepted 50-locale medium/large-phone/iPad set is incomplete. Historical screenshot/text portions are not final current-source media. All listing readiness flags remain false. No signing, TestFlight/upload, App Store submission, legal certification, physical hardware pass, or owner account/agreements confirmation is implied.

The latest verified current-source privacy receipt has SHA-256 `e60e58061821f3197de1238896c2f6c81f631f49c7374287528b0548501ab4e9`, with 300 production inputs. Preserve all previous review records, original HTTP bytes/timestamps/limitations, and all 50 listing bindings. Source-only refreshes are not fresh public HTTP verification.

## Remaining release gates and deliberately excluded work

The committed [release-applicability policy](../../ios/readiness/RELEASE-APPLICABILITY.md), [status document](../../ios/readiness/STATUS.md), and [release checklist](../../ios/RELEASE-CHECKLIST.md) define the scope. Their older revision-specific status paragraphs are historical; the exact source/native snapshot in this handoff supersedes those dates, not their evidence requirements.

- **Initial submission is screenshots-only, with Game Center off.** Optional App Previews are excluded by the recorded owner-delegated choice; no app feature is removed. Old failed video/audio evidence stays failed, and the archived preview/band-preparation patch remains optional, unapplied, and unverified—not a mandatory submission fix. Do not upload preview videos or enable Game Center without a separate reviewed scope/policy change.
- **Hardware QA is owner-waived / unverified, never passed.** This bounded repository waiver covers unavailable physical-device QA only. Microphone lifecycle, interruptions, speaker leakage/grading, latency, wired/Bluetooth routes, haptics, Watch hardware and physical assistive-technology behavior remain untested. It does not waive actual known defects, simulator/accessibility gates, privacy, screenshots, commerce/account evidence or Apple requirements.
- **Exact-source engineering gates remain blocking:** app/unit/renderer and smoke flows, Release, complete accessibility partitions/matrix, first-session/Urdu, real-touch Songs rotation, lesson completion, sanitizer and required localization/resource checks. Preserve original failures and unknown/cancelled states. No audit exemption is activated; no blanket contrast dismissal is permitted.
- **Finish and visually accept current-source media.** Selected roles are medium phone `iphone` 1206×2622, large phone `iphone-large` 1320×2868 and landscape `ipad` 2752×2064, with 9+9+4 planned frames per listing locale. Require originals, actual-language proof, manifests and source/build identity, then full pilot and all 50 listing locales; no stretching/substitution or medium-only completeness claim. Revalidate the separate historical Watch portion against final Watch source. Mechanical capture/typography success is not visual acceptance or upload.
- **Privacy/service/commerce correctness is separate:** reconcile policy and App Privacy answers with actual telemetry consent/revocation, optional service configuration, song requests, remote settings, StoreKit and MusicKit behavior. Do not infer “Data Not Collected” merely from a missing telemetry ID. Review current public support/privacy endpoints separately; historical HTTP observations are not ongoing availability. Verify real configured products, localized storefront prices, purchases/restore/entitlement/refund states and sandbox behavior; local StoreKit fixtures and the hardware waiver do not establish Apple-side commerce readiness.
- **Owner/business and distribution gates remain:** legal entity, Free/Paid agreements, tax/bank, DSA, identifiers/capabilities, intended pricing, protected CI credentials and permissions, then explicitly authorized signed archive, effective entitlements, upload processing/TestFlight, accurate listing/legal/compliance/review-contact answers, and separate submission/release approval. Optional trials, Family Sharing, grace-period/price experiments, promotional events/ads and Game Center enablement are not prerequisites for this base scope. Never invent portal completion or accept legal terms on the owner's behalf.
- **Keep all readiness flags false.** A green exact-current-main gate and all applicable source/content-bound evidence are required before delivery. Missing/stale applicability policy restores requirements rather than silently excluding them. Public accessibility claims need their own evidence; the hardware waiver supplies none.

Newer CI triggered by f937 is **unknown in this handoff**; no post-stop monitoring or retry result is claimed. Documentation publication and source preservation are not release validation.

## Resume safely on the owner's laptop

First preserve any local work and fetch only when ready; do not reset or overwrite an unrelated checkout. Start from the published preservation commit, not the older main branch or a16 parent:

```sh
git fetch origin
git log -1 --format='%H %s' origin/main
git log -1 --format='%H %s' origin/codex/app-store-readiness-gates
git worktree add ../timbre-handoff f937c5d412956fd4d7b5468659f049103aee402f
```

The exact [code preservation commit](https://github.com/azerish25-ux/tuner/commit/f937c5d412956fd4d7b5468659f049103aee402f) already contains the capture, priming-preflight and scheduling changes. Compare its files to `preserved_sha256` in [the preservation manifest](manifests/preserved-readiness-changes.json). The combined patch and its component patches are provenance only: **do not apply them again**. Inspect the published change directly if needed:

```sh
git diff --stat a161bec505f827a32feaeb74c6e955d4d6db146d f937c5d412956fd4d7b5468659f049103aee402f
git status --short
```

Copy this dated documentation directory into the worktree only if needed; documentation may be published on main independently of application code. Keep Along and any contrast proposal separate until explicitly selected and reviewed. Neither the f937 preservation commit nor a documentation publication is a native pass.

Use Python 3.12 and the repository's dependency declarations. From the repository root:

```sh
python3 -m venv .venv-handoff
. .venv-handoff/bin/activate
python3 -m pip install -r tools/marketing/requirements.txt
python3 -m unittest discover -s tools/ci -p 'test_*.py'
python3 -m unittest discover -s tools/l10n/tests -p 'test_*.py'
python3 -m unittest discover -s tools/marketing/tests -p 'test_*.py'
python3 tools/verify-ios-resources.py
python3 tools/l10n/report.py --check --strict
python3 tools/l10n/store.py
python3 tools/curriculum/build.py --check
actionlint -shellcheck= -pyflakes=
git diff --check
```

On macOS, use the exact supported Xcode/toolchain and project-generation instructions in the current workflows (a16 CI uses macOS 15/Xcode 26.3; app minimum iOS 18). Select a real available simulator UUID with `xcrun simctl list devices available`, run `xcodegen generate` inside `ios`, and use the current workflow's build/test commands and timeout settings—not stale copied command lists. Preserve original xcresult, logs, screenshots, hierarchy, trace provenance, branch/merge SHA, run/attempt, and artifact SHA-256. Inspect actual first-landscape Song frames, app watchdog boundary, Urdu strict rasters, and completed Along geometry before making another source change.

Prioritize finishing an exact-revision native result over adding generic instrumentation. Fix evidenced UI failures without weakening assertions. Review physical-device/Apple-account requirements separately with the owner; a previous hardware QA waiver records an unverified limitation, not a pass.

### Scheduling references

GitHub documents [dependency failure/skip behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idneeds) and [implicit success/cancellation functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions#status-check-functions). Its [published concurrency limits](https://docs.github.com/en/actions/reference/limits#job-concurrency-limits-for-github-hosted-runners) list five standard macOS jobs for common non-Enterprise plans, but the actual repository owner's plan/adjusted limit was not established. Do not present scheduling as a proven infrastructure diagnosis.
