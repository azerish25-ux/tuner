# App Store readiness — active continuation

Resumed 27 October 2026 at the owner's request, using the assistant's cloud computer and GitHub Actions.

## Current checkpoint — 27 October 2026, 08:39 UTC

- Existing application branch: `codex/app-store-readiness-gates`, [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3). Published head: `59380e3f2e892bcfb43578dbc0b769b8bfef78f8` (privacy evidence/source binding; 217 local tests passed). That published app-source baseline is `fa5a28a`; this checkpoint also includes the later source fixes below, pending native execution. The branch name is not a separate coding agent. Main's required gate remains mandatory; no application merge, signing/upload or submission has occurred.
- The `fa5a28a` cover-credit wrapping/layout source built natively, and [German capture-check 40472603446](https://github.com/azerish25-ux/tuner/actions/runs/40472603446) passed. [iOS 40472609940](https://github.com/azerish25-ux/tuner/actions/runs/40472609940), [nightly 40472609789](https://github.com/azerish25-ux/tuner/actions/runs/40472609789) and [three-locale pilot 40472603655](https://github.com/azerish25-ux/tuner/actions/runs/40472603655) still have pending scopes. Build success is not a pass of all nine new tests, accessibility or final listing media.
- `a16b80e` native/nightly runs were superseded and cancelled; its successful export/typography runs remain valid for their recorded scopes only.

| Exact source / run | Evidence at this checkpoint |
|---|---|
| `50e2ce8` — [iOS 40463664971](https://github.com/azerish25-ux/tuner/actions/runs/40463664971) | **Terminal, aggregate failed.** Core and Release passed; 135 app tests and three smoke flows passed. Accessibility: 50 contrast findings + two incomplete audits = 52 failures. This run is no longer running. |
| `48704b3` — [iOS 40467762004](https://github.com/azerish25-ux/tuner/actions/runs/40467762004) | Core/Release and 135 app tests + three smoke flows passed. Required accessibility audit terminal/cancelled at the 55-minute outer budget; aggregate gate failed. Only about 20 KB of logs survived, not a complete result bundle. |
| `48704b3` — [captures 40467931446](https://github.com/azerish25-ux/tuner/actions/runs/40467931446) | iPad job successful; bounded review of 12 normal-size English images found no concrete defects. Tour terminal: 28 tests, two failures; diagnosis active. Matrix green is diagnostic capture only, not accessibility acceptance. TSan skipped, not passed; workflow corrected but fresh execution required. |
| `a16b80e` — [export 40470652212](https://github.com/azerish25-ux/tuner/actions/runs/40470652212) | Successful: all 49 app languages, 48 × 6,083 translated lesson keys, zero gaps. |
| `a16b80e` — [typography 40470652270](https://github.com/azerish25-ux/tuner/actions/runs/40470652270) | Successful: 56 tests and 2,050 glyph + 2,050 layout checks across 50 locales; zero failures. Does not certify final captured/composed store frames. |

**Diagnostic matrix is not accessibility acceptance:** 294 callbacks (202 Dynamic Type, 57 contrast, 35 clipped text) plus three unfinished tuner audits. Actual AX5 NotesStep clipping was found. This checkpoint includes a reviewed source/test fix (including a corrected scroll viewport) and planned 75-minute partitioned audits with evidence preservation; native execution/acceptance is still pending.

## Remaining gates

1. Diagnose the two tour failures, natively verify the reviewed AX5 NotesStep fix and planned partitioned audit/evidence-preservation changes, and establish results for pending native/capture scopes and exact-head execution for the cover-credit layout fix/new tests. Review real accessibility callback identities and paint evidence; finish incomplete audits without weakening enforcement. Earlier-source passes do not cover later changes.
2. Execute the corrected sanitizer scope, finish tour/layout/localization QA and inspect native normal/AX5/RTL frames. A successful iPad job is not acceptance of every frame or all supported device scopes.
3. Review the three-locale pilot and capture-check, then complete and review the final 50-locale phone/tablet inventory with original frames, manifests and source/build hashes. Watch's historical accepted bundle is only one portion.
4. Keep all listing `release_ready` flags false until real requirements pass. Release preflight requires exact current-main source, a successful native gate and applicable release evidence before signing; archive identity/feature-scope checks still need an actual signed archive.
5. Owner account, agreements, tax/banking, products/prices, signing permissions/secrets and explicit delivery/submission authorization remain separate gates. No portal state or Apple approval is verified here. Follow the current [Apple handoff](../APPLE-DELIVERY.md) and [release checklist](../RELEASE-CHECKLIST.md).

Submission remains polished localized screenshots **without preview videos**, with Game Center disabled. No app feature is removed. Historical failed movies and the unapplied audio draft remain historical, not passes. Physical-device QA is **owner-waived / unverified**, bounded by [the applicability policy](RELEASE-APPLICABILITY.md); it does not waive simulator/accessibility, privacy, media, product/account or Apple requirements.

Portable/local checks are useful but separate from native results: earlier baseline 193 localization tests, 50 marketing tests, 25 hygiene tests and four cover-contrast tests passed; the subsequent applicability suite reached 204 localization tests, and the `59380e3` privacy-evidence/source-binding update passed 217 local tests. Those counts describe their recorded checkpoints, not a new full-suite run on the current head.

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
