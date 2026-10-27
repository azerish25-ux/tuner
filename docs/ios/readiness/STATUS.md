# App Store readiness — active continuation

Resumed 27 October 2026 at the owner's request, using the assistant's cloud computer and GitHub Actions.

## Current checkpoint — 27 October 2026, 09:18 UTC

Branch: `codex/app-store-readiness-gates`, [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). This checkpoint follows base `bf1698a586ae54acc7c43344dc5d61f1e071cd03`. **Not submission-ready.** All listing `release_ready` flags remain false. Main's required gate is preserved; no application merge, signing/upload or submission. The owner account question remains unanswered; no account/agreements/products/permissions are assumed.

| Exact source / evidence | Observed result; limits |
|---|---|
| `59380e3` — native | 144 unit tests ran with 82 assertion failures, all in one compact synthetic `SleeveCreditLayoutTests` case. Other eight cover tests, including ImageRenderer, and all three smoke flows passed. Core force-cast lint failed; Release passed. Required accessibility audit still running; no aggregate pass. |
| `48704b3` — [captures 40467931446](https://github.com/azerish25-ux/tuner/actions/runs/40467931446) | Tour terminal: 28 tests, two failures (visible cue ID / Just Tune durability). Diagnostic matrix: 294 callbacks (202 Dynamic Type, 57 contrast, 35 clipped text) plus three unfinished tuner audits. Green diagnostic job is **not accessibility acceptance**. Twelve normal-size English iPad frames received bounded visual review with no concrete defects; AX5 and other scopes remain separate. TSan skipped, not passed. |
| `fa5a28a` — [capture-check 40472603446](https://github.com/azerish25-ux/tuner/actions/runs/40472603446) | German and Arabic each passed eight tests. English launch failed. Reviewed bounded retry/warmup changes are later source, not executed evidence yet. |
| `fa5a28a` — [listing pilot 40472603655](https://github.com/azerish25-ux/tuner/actions/runs/40472603655) | All iPhone shards failed: English/German lacked the visible cue ID; Arabic XCTest reported PID 0 despite actual Arabic app launch. iPad English/German running; Arabic queued. No complete pilot accepted. |
| `a16b80e` — [export 40470652212](https://github.com/azerish25-ux/tuner/actions/runs/40470652212) | Passed all 49 app languages / 48 × 6,083 translated lesson keys without gaps. |
| `a16b80e` — [typography 40470652270](https://github.com/azerish25-ux/tuner/actions/runs/40470652270) | 56 tests, 2,050 glyph and 2,050 layout checks across 50 locales passed. Not acceptance of final captured/composed frames. Its separate native/nightly runs were superseded/cancelled. |
| `bf1698a` — new runs | [Capture-check 40478297057](https://github.com/azerish25-ux/tuner/actions/runs/40478297057) queued; [iOS 40478303793](https://github.com/azerish25-ux/tuner/actions/runs/40478303793) and [nightly 40478303657](https://github.com/azerish25-ux/tuner/actions/runs/40478303657) pending. |

### Corrections awaiting native evidence

- `9774746`: core force-cast lint, visible cue accessibility ID and Just Tune durability corrections. They do not change the failed older run's result.
- `bf1698a`: compact synthetic cover-credit test geometry correction; passing eight other cover tests does not waive the failing case or prove the correction.
- `476a3f0`: reviewed AX5 NotesStep layout/scroll viewport fix; native acceptance pending. Partitioned audit/evidence-preservation work must establish complete required audit results, not just diagnostic captures.
- Capture retry/warmup changes are bounded and reviewed, but not yet executed evidence; real-language/native-launch checks remain enforced.
- **Actual Arabic quest fractions are confirmed reversed.** The earlier unit oracle did not catch this rendered ordering defect. This checkpoint includes separate localized operands and independent wide/compact rendering oracles; native verification and actual Arabic recapture remain pending. Do not cite the old unit pass as current RTL acceptance.

### Earlier continuation evidence, not current passes

`50e2ce8` [run 40463664971](https://github.com/azerish25-ux/tuner/actions/runs/40463664971): core/Release, 135 app tests and three smokes passed; accessibility had 50 contrast findings + two incomplete audits = 52 failures, aggregate failed. `48704b3` [run 40467762004](https://github.com/azerish25-ux/tuner/actions/runs/40467762004): core/Release, 135 app tests and three smokes passed; required accessibility cancelled at the 55-minute outer budget and aggregate gate failed. Only about 20 KB of logs survived, not a complete result bundle.

Local baseline counts (193 localization / 50 marketing / 25 hygiene / four cover-contrast tests), later 204 applicability-suite tests and `59380e3` privacy source-binding's 217 local tests describe their own checkpoints. They are neither a new current-head full-suite pass nor Apple/privacy release approval.

## Remaining gates

1. Complete the Arabic rendered-order correction, then verify exact-source RTL frames and regressions. Establish terminal native outcomes for compact geometry, lint, cue/Just Tune and AX5 fixes; finish required audits without blanket exemptions.
2. Execute sanitizer and complete tour/layout/localization scopes. Pending, cancelled, diagnostic-only and incomplete results are not passes; preserve full artifacts where possible.
3. Review/reproduce a complete three-locale pilot, then all 50 final phone/tablet sets with native originals, manifests and source/build hashes. Watch's historical accepted bundle is only one portion.
4. Keep release flags false until genuine validation passes. Delivery requires exact current-main source, green required native gate, applicable release evidence and signed-archive checks; no later source inherits an earlier pass automatically.
5. Obtain the missing owner account information and verify agreements, tax/banking, products/prices and signing permissions at action time. Credentials, upload, submission and release remain separately authorized actions; see [Apple handoff](../APPLE-DELIVERY.md) and [release checklist](../RELEASE-CHECKLIST.md).

Scope remains localized screenshots **without optional previews**, Game Center disabled, no app feature removal. Failed movies/unapplied audio draft remain historical. Physical-device QA is **owner-waived / unverified**, bounded by [the applicability policy](RELEASE-APPLICABILITY.md); privacy, simulator/accessibility, media, product/account and Apple requirements are not waived.

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
