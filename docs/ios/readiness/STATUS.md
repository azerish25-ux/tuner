# App Store readiness

Updated October 27, 2026 (America/Halifax). Baseline native verification candidate:
`b6efd36f5f72d7ec723229949f7c54c32972b72c`.
Reviewed follow-up changes and their native checks are in [PR #3](https://github.com/azerish25-ux/tuner/pull/3).

**Submission readiness is not yet established.** Native builds, current simulator runs and actual release media
are in progress. Apple account configuration and physical audio tests remain required before submission.

## Verified preparation

| Area | Evidence and current result |
|---|---|
| App languages | All 49 app languages present; all 48 translated lesson languages have zero missing keys. Strict critical-string checks report zero legal, permission or VoiceOver gaps. This establishes coverage, not universal linguistic perfection. |
| Store text | All 50 supported listing payloads pass source, length, structure and recorded independent AI review checks. The 100 privacy/Game Center field updates retain the previous review lineage. All `release_ready` flags remain false until release evidence is complete. |
| Local tests | 193 localization/tool tests, 46 marketing tests, 25 hygiene tests and four cover-contrast tests pass. Marketing tests use an isolated environment with the repository requirements. Swift/XCTest execution requires the hosted macOS jobs. |
| Bundled content | Curriculum validation and iOS resource verification pass. Image provenance includes the owner's declaration and hashes of all 68 bundled images and thumbnails. |
| Privacy and support | [Privacy](https://timbre-support.timbre.workers.dev/privacy) and [support](https://timbre-support.timbre.workers.dev/support) return HTTP 200 and exactly match built HTML. Policy wording matches current consent, attribution and song-request source behavior. |
| Independent review | Audio, privacy, CI, seasonal access, Watch tooling and listing deltas have source-review receipts. The integration review found no new blocking source defect; native execution remains separate. |
| Branch protection | `main` now requires the aggregate `gate` check with up-to-date branches. Normal administrator bypass is retained. [Verified settings](reviews/main-protection.json). The reviewed workflow update also requires accessibility to pass. |
| Action runtimes | The follow-up pins five official Node24 actions to exact commits. Explicit publisher destinations preserve single-artifact evidence; [migration review](reviews/node24-action-upgrade-resolution-independent-review.json). Hosted execution remains pending. |
| Historical findings | [Claude handoff reconciliation](reviews/claude-handoff-reconciliation.json) accounts for every one of the 44 historical issue-table rows and the handover claims. Follow-up fixes and native results must be read alongside that frozen snapshot. |

The public policy verification is recorded in [privacy-publication-refresh.json](reviews/privacy-publication-refresh.json).
The independent source integration review is [final-integration-independent-review.json](reviews/final-integration-independent-review.json).
The [plural import resolution](reviews/plural-import-resolution-independent-review.json) closes the historical importer gap,
including numeric singular/lexical dual compatibility and rejection of unsafe format arguments. The
[audit callback review](reviews/audit-callback-capture-independent-review.json) covers additional failure screenshots
and the four-job required gate; it does not approve any accessibility exception.
The original handover files remain dated historical evidence; their English-only, unpublished-support and unfixed-source
statements are superseded where current receipts establish a change.

## Native verification in progress

| Run | Required evidence |
|---|---|
| [Baseline iOS](https://github.com/azerish25-ux/tuner/actions/runs/40434233016) | Core tests/coverage/lint and unsigned Release build passed. The app job failed six privacy tests and suffered a fixture expectation exception; after restart, 102 remaining app tests and three smoke flows passed. This is not a full app-test pass. Accessibility failed contrast checks; the findings remain open. |
| [Follow-up iOS checks](https://github.com/azerish25-ux/tuner/pull/3/checks) | Corrected privacy fixtures, RTL fraction rendering and the four-job required gate still need hosted verification. |
| [Localization export](https://github.com/azerish25-ux/tuner/actions/runs/40434232913) | Passed: current English XLIFF and strict checks against Xcode's actual keys. |
| [48-language simulator matrix](https://github.com/azerish25-ux/tuner/actions/runs/40434232959) | Real localized launches, requested screens, request-state UI and retained screenshots for visual review. |
| [Caption typography](https://github.com/azerish25-ux/tuner/actions/runs/40434232930) | Passed for all 50 store locales. Caption layout/glyph checks do not establish finished native media. |
| [Localized capture checks](https://github.com/azerish25-ux/tuner/actions/runs/40434233041) | Actual selected English, German and Arabic store scenes. |
| [Listing asset pilot](https://github.com/azerish25-ux/tuner/actions/runs/40434233043) | Real iPhone/iPad screenshots and preview pipeline for English, German and Arabic before the complete 50-locale run. |
| [Watch captures](https://github.com/azerish25-ux/tuner/actions/runs/40434259810) | Watch build and one genuine English Today capture passed, then the metronome relaunch failed with a simulator scene-update error. One frame is not a completed 98-image set. Native retry effectiveness and full visual acceptance remain pending. |
| [Corrected Watch captures](https://github.com/azerish25-ux/tuner/actions/runs/40440109281) | Passed: 98 native PNGs, all 49 app languages and 50 listing mappings. Dimensions are 416×496; the manifest reports no alpha-channel upload flag. All-image visual review remains pending. |
| [Nightly tour](https://github.com/azerish25-ux/tuner/actions/runs/40434262338) | Full iPhone/iPad flows, first session, captures, accessibility matrix, thread sanitizer and unsigned archive. |

Earlier failed or cancelled runs are retained. Their failures are not replaced by a source-review approval.
The previously observed accessibility failures have not been waived. Capture/parser fixtures are not release screenshots.
The [privacy failure triage](reviews/privacy-native-failure-triage.json) identifies a defective trailing-slash test matcher
and shared fixture callbacks/session cleanup. The follow-up isolates sessions and adds lifecycle regressions without
changing production transport or raising the original test timeouts. A native rerun must establish the result.
The [fixture resolution review](reviews/privacy-fixture-resolution-independent-review.json) covers the corrected
session lifecycle, route assertion and 18 authored tests; source approval does not close the native failures.
The [Watch resolution review](reviews/watch-native-resolution-independent-review.json) records the actual first
frame and later relaunch failure, stderr-based native help correction, and narrowly bounded recovery with fresh
probe tokens and retained diagnostics. Unknown errors, timeouts and persistent failures still fail the job.
The listing pilot stopped at unavailable macOS caption shaping, before native media generation. The
[caption-shaping resolution](reviews/caption-shaping-resolution-independent-review.json) adds the runtime dependency,
safe per-step loading and clear failure reporting. It preserves the full glyph/shaping gates; actual macOS execution
and final composed media still need verification.

## Remaining release evidence

1. Resolve every genuine failure in the current native runs and confirm the corrected revision passes.
2. Review real localized app and Watch frames for clipping, glyphs, layout and RTL; produce and inspect the full
   localized iPhone/iPad listing sets. A text payload or caption audit cannot substitute for these assets.
3. Complete [the physical audio test sheet](../AUDIO-DEVICE-TESTS.md), including starts/stops, interruptions,
   speaker grading, first-click latency and wired/Bluetooth routes. A simulator cannot measure these behaviors.
4. Configure the Apple account, app record, identifiers/capabilities and products; verify sandbox purchases,
   signed entitlements, the archive privacy report and the final App Store Connect fields.

The optional preview pipeline retains its audio/sync gates. Paid commercial songs, external branding commissions,
teacher videos, additional 3D models and paid acquisition remain optional growth work. Game Center stays disabled
in the default release configuration until its separate account/assets/device setup is complete.

## Apple account handoff

The guarded delivery workflow expects `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID` and `APP_STORE_CONNECT_API_KEY_P8` in the protected GitHub `apple-delivery`
environment. Configure secrets through the provider's secret fields; never commit them or put them in a report.
The app's numeric App Store ID, product configuration, MusicKit capability, required agreements, tax/banking and
app privacy/age-rating/export-compliance responses must be completed using the owner's Apple account.

The [delivery guide](../APPLE-DELIVERY.md) and [release checklist](../RELEASE-CHECKLIST.md) describe those steps.
No signed build, Apple upload or submission is recorded by this status document. The current remaining work includes
native/media/hardware verification; it cannot honestly be reduced to account credentials yet.
