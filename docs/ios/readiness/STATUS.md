# App Store readiness — active continuation

Resumed 27 October 2026 at the owner's request, using the assistant's cloud computer and GitHub Actions.

## Corrective checkpoint — 27 October 2026

Branch: `codex/app-store-readiness-gates`, [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). Published corrective source `89705bd3144ac3b7ceefe84d6fcf65d83eb9045e` includes Songs compiler/lint and flat-gold offer corrections. The large-phone role integration and inventory documentation are the next reviewed checkpoint. **Native execution and final media acceptance remain pending, not passed.** All listing `release_ready` flags remain false. Main's required gate is preserved; no application merge, signing/upload or submission. The owner Apple-account question remains unanswered.

### Evidence and corrections

| Source / scope | Observed result; limits |
|---|---|
| `f97713eb` — [export 40539498484](https://github.com/azerish25-ux/tuner/actions/runs/40539498484), [iOS 40539504787](https://github.com/azerish25-ux/tuner/actions/runs/40539504787), [pilot 40539498544](https://github.com/azerish25-ux/tuner/actions/runs/40539498544) | Failed on compiler complexity at `SongsView.swift:1006`. Core also failed the nine-parameter `tileCaption` lint at line 1171. Typed ordered appends and a `TileCaptionView` replace those problem expressions/signature in the reviewed correction; native execution pending. |
| `f97713eb` — [caption audit 40539498843](https://github.com/azerish25-ux/tuner/actions/runs/40539498843) | Passed 65 tests and 2,050 glyph + 2,050 layout checks for 50 locales. Does not certify app compilation, final screenshots or submission coverage. |
| Earlier `6a9329aa` native baseline | 148 unit tests, three smoke flows, core, Release and TSan passed. Accessibility recorded 38 assertions; tour had two failures; iPad screenshots failed. No aggregate readiness pass; these passes do not cover the later source. |

Source changes needing verification include accessibility TuneCheck/Quest-trait handling, quiet demo, RTL cropping and warmup-rest behavior. Source review is not native execution evidence. The flat-gold offer-badge experiment has a measured minimum contrast of **12.89:1**, replacing an already accessible gradient. It adds no audit exemptions; an improved or passing SDK audit outcome has **not** been established.

`b89893fa` corrects the distinct-tune claims across all 50 listing payloads: **135 distinct tunes**, marketed as **“130+ songs”**, not the larger instrument-arrangement count. Prior privacy/source-binding and local test passes are limited to their own source and scope; they do not establish App Privacy or release approval.

### Media inventory correction

Apple's [official locale inventory](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations) confirms the 50 listing locales; this remains distinct from 49 in-app languages and their documented fallbacks. The [current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) identify the missing large-phone submission coverage. The explicit large-phone capture/validation role is implemented and locally tested, not natively accepted. Selected roles are medium `iphone` 1206×2622, `iphone-large` 1320×2868 and landscape `ipad` 2752×2064, without substitution or stretching. Shared phone captions produce separate native images: 9+9+4 per locale. Planned full inventory is 150 sets / 75 two-locale shards / 1,100 JPEGs; pilot is 9 sets / 6 shards / 66 images. Large Dynamic Island captures address Apple’s conditional large-phone requirement; this is not a claim that every phone size is universally mandatory. **Do not label medium-only captures a complete submission set.** iPad and Watch remain separate required inventory portions. Typography passes and historical Watch acceptance cannot fill missing phone/iPad evidence.

## Remaining gates

1. Execute this corrective source natively: compile/export, core lint, app/smoke/Release, sanitizer and complete required accessibility audits. Preserve full artifacts; do not convert cancelled, diagnostic-only or incomplete results into passes.
2. Recheck actual TuneCheck/Quest/RTL/demo behavior, tour failures and iPad layouts using the current source. Keep narrow identity/paint evidence for audit diagnoses; no blanket exemptions.
3. Execute the locally tested explicit medium/large-phone roles, then reproduce/review the pilot and all 50 localized phone/iPad sets with originals, manifests and matching source/build hashes. No final complete inventory exists yet.
4. Require a green exact-current-main gate and applicable release evidence before any signing. Keep every release flag false until real criteria pass. Later source must not inherit older test or privacy evidence automatically.
5. Resolve the owner account question, then verify actual agreements, tax/banking, products/prices and permissions. Credential generation, signing/upload, submission and release require the separate authorizations in [Apple handoff](../APPLE-DELIVERY.md) / [release checklist](../RELEASE-CHECKLIST.md). No account state or Apple approval is assumed.

Scope remains localized screenshots **without optional previews**, Game Center disabled, no app feature removal. Physical-device QA remains **owner-waived / unverified**, bounded by [the applicability policy](RELEASE-APPLICABILITY.md), not a waiver of simulator/accessibility, privacy, media, commerce/account or Apple requirements. Earlier continuation details remain in Git/run history; the handoff below is a separately frozen historical record, not current instructions or current medium-only coverage guidance.

## Historical handoff snapshot

Updated 27 October 2026 when the owner requested development wind-down. The frozen handoff is preserved under [Historical developer handoff](../../../README.md#historical-developer-handoff--earlier-27-october-2026). Everything in this section describes that earlier stop checkpoint, not the resumed execution or current instructions above.

**Not submission-ready.** No Apple signing/upload/submission has occurred. Main remains at `b6efd36`; resume `codex/app-store-readiness-gates` in [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). Do not bypass its required gate.

| Evidence | Current state |
|---|---|
| `5167d34`, iOS run `40456038504` | Core/Release passed; 127 app tests and three smoke flows passed with zero failures. Accessibility failed, so aggregate gate failed. |
| Accessibility on that revision | 57 contrast reports and two unfinished Songs audits: 59 failures. Six localization launches passed. The older 008 review's 54-report inventory is separate. |
| Xcode export `40456066835` | Passed: all 48×6,083 lesson keys, zero legal/permission/VoiceOver gaps. |
| Caption audit `40456063547` | Linux/new medium-size glyph and layout preflight passed: 2,050 + 2,050 checks for 50 locales. |
| Watch `40440109281` | 98 original captures accepted within bounded visual/integrity scope; portable 100-image/50-listing bundle archived. |
| Layout QA `40458830411`, `c089246` | Sanitizer passed; tour/iPad/matrix stopped at new-test numeric type ambiguity. Explicit CGFloat corrections are included in the handoff source but not natively rerun. |
| Guitar preview `40447132590`, `c8874d9` | Actual video/audio gates failed. Cue source fix is committed but unrun; band-preparation draft is archived, unapplied and unverified. |

Later source changes need new native execution; the green app result above is revision-specific. Large-text ready/playing/results layouts, full tour, accessibility resolution, full 48-language matrix, all 50 final phone/tablet sets, applicable previews, physical-device QA and Apple configuration remain unfinished. All listing `release_ready` flags remain false. Game Center is disabled by default.

Recoverable work:

- [Unapplied preparation patch and instructions](drafts/README.md).
- [Portable Watch/text/caption material](handoff-assets/README.md).
- [Frozen source reviews and failure triage](reviews/).
- [All 44 historical Claude issue rows reconciled](reviews/claude-handoff-reconciliation.json).

The old wind-down statement and execution order are retained only as history. Active continuation and its source-specific evidence are above; do not use this snapshot to override the current screenshot-only scope, physical-device waiver or release policy.
