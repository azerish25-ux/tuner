# Timbre for iOS — release checklist

Reconciled **27 October 2026** for cloud + GitHub Actions delivery. Unchecked means pending or unverified, not failed or completed. Record a source SHA, build/run ID, scope and durable evidence for each actual pass. **No signed upload, Apple portal configuration, submission or approval is verified by this checklist.**

## Release decisions and boundaries

| Item | Current disposition |
|---|---|
| Working branch | `codex/app-store-readiness-gates`, [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3), `50e2ce8` handoff lineage; resolve full current SHA before execution |
| Main | Protected; required up-to-date `gate`; no bypass or skipped CI |
| Initial listing | Screenshots only, selected under the owner's delegated choice; no preview upload and no app feature removal |
| Game Center | Existing release default disabled; account evidence not applicable only while source/archive remain disabled |
| Physical-device QA | **Owner-waived / unverified** because hardware testing is unavailable; not a pass |
| Native/cloud QA | Still required, including accessibility, localization, final media and commerce/privacy checks |
| Signing/upload/submission | Separate owner/action-time authorization, not implied by preparation |

The source-hashed [release applicability policy](readiness/RELEASE-APPLICABILITY.md) implements the limited exclusions/waiver. Do not forge evidence, auto-promote `release_ready` flags or refresh policy hashes without review. The waiver does not relax Apple requirements, justify accessibility claims or establish hardware safety/quality.

Historical schedules, PR #2 / `v2/foundations` directions and price/revenue forecasts are superseded. Historical tests/reviews remain scoped to their recorded revisions; Git history and [review receipts](readiness/reviews/) preserve them. There is **no committed launch date**. Proceed by evidence, not an elapsed deadline.

## 0. Establish the exact source and evidence ledger

- [ ] Record full current branch SHA, working-tree changes and PR checks. Do not overwrite other cloud work.
- [ ] Read current [README](../../README.md), [Apple handoff](APPLE-DELIVERY.md), applicability policy and actual workflows. README's historical physical-device requirement is superseded only by the recorded waiver above.
- [ ] Preserve important Actions artifacts before retention expiry, with source/run IDs and hashes. A missing/expired artifact is not a pass: recover an archived original or reproduce its scope.
- [ ] Keep app, metadata, screenshots, policy and signed-build evidence separate. A source review or parser pass does not establish runtime behavior.

Known baseline, not final acceptance: `5167d34` had 127 app tests and three smoke flows passing, but accessibility had 57 contrast reports and two unfinished Songs audits, so aggregate gate failed. Later layout tests initially failed compilation on the historical QA branch. Corrections and subsequent cloud work need their **own** run receipts; neither these old failures nor old passes determine current results. The accepted Watch bundle is only a portion of required listing media. Earlier failed previews remain failed but are excluded from this initial upload scope.

## A. Apple account and required owner decisions

- [ ] Verify intended legal entity/team and active Apple Developer Program membership. Any paid enrollment/renewal needs authorization; none is assumed.
- [ ] Account Holder reviews applicable agreements; verify current Paid Apps Agreement, required tax/banking and their portal status. Never put personal financial details or credentials in this repository. Apple's [agreement requirements](https://developer.apple.com/support/terms) and [payment prerequisites](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments) govern these steps.
- [ ] Confirm territories, content rights, trader status and territory-specific requirements against the current portal. Do not guess eligibility, legal status or approvals.
- [ ] Verify the iOS app record, main bundle ID, available name, primary language, SKU and real numeric Apple ID. Choose actual version/build numbers from the record: project default `1.0.0` and workflow example `2.0.0` are not portal evidence.
- [ ] Verify all four explicit bundle IDs and App Group associations from [handoff identity](APPLE-DELIVERY.md#identity). Verify MusicKit App Service for the retained Apple Music feature. Leave Game Center disabled in this release.
- [ ] Confirm review contact and private phone/email directly in Apple, without publishing them in receipts.
- [ ] Decide live product prices, territories and introductory offers. Test fixture prices do not establish live values. Optional experiments are in section K, not prerequisites.

## B. Public pages and configured services

- [ ] Recheck public [privacy](https://timbre-support.timbre.workers.dev/privacy) and [support](https://timbre-support.timbre.workers.dev/support) pages, HTTPS responses, visible content and working contact route; preserve a dated receipt. Earlier publication evidence does not prove future uptime.
- [ ] Match the archive's privacy links to those pages and [PRIVACY.md](PRIVACY.md). Apple standard EULA remains the source-configured Terms link unless an authorized legal change is made.
- [ ] Record final values/presence (no secrets) for `TELEMETRYDECK_APP_ID`, `TIMBRE_APP_STORE_ID`, `TIMBRE_SHARE_URL`, `TIMBRE_REMOTE_CONFIG_URL` and effective privacy URL. Optional unset services need accurate fallback behavior, not invented configuration.
- [ ] If analytics is enabled, verify consent/revocation, queued and in-flight cancellation, song-request acknowledgments and allowlisted attribution/diagnostics against tests and policy. No telemetry ID does **not** imply no network: StoreKit, remote settings, rating lookup, optional Apple Music and support are separate flows.
- [ ] If optional remote settings/shares are configured, test schema, failure/cache behavior, real destinations and any product/offer IDs. Do not publish historical dates, fake ratings or unapproved offers. Universal Links require additional configuration beyond a custom scheme.

## C. Cloud source and native validation

- [ ] Run portable localization/content/resource/hygiene tests from README; keep exact-source results.
- [ ] Run native `ios.yml`: `core`, `app`, Release and **accessibility** all required. Investigate warnings and failures rather than weakening assertions.
- [ ] Verify new layout/startup/cue tests as applicable to the committed source, then full smoke/first-session/tour, iPad, sanitizer and accessibility matrix. Do not apply the separate prepared-audio patch merely to satisfy optional preview work.
- [ ] Finish both Songs accessibility audits and reconcile current callbacks by identity, visibility and paint evidence. Old inventories are not the latest result. No blanket contrast exemptions or “incomplete = pass” treatment.
- [ ] Inspect normal/AX5 ready, playing and results views; Start reachability, scrolling, peg labels and results overlays. Source fixes alone are insufficient.
- [ ] Run authoritative Xcode localization export and all eight matrix groups covering 48 translated app languages. Review glyphs, clipping, wrapping and RTL; recapture RTL counters after source fixes. Preserve all 49 app languages and the 50-listing mapping/fallback disclosures.
- [ ] Complete required native media and caption review (section H), then `python3 tools/l10n/store.py --release`. A non-release text check is not a release pass.
- [ ] Review and merge PR #3 only after required checks pass; inspect the exact resulting `main` push run. Branch protection is already a requirement, not a task to bypass or loosen.

## D. Products and commerce

- [ ] Configure/verify **Timbre Pro** group and `timbre_pro_annual` (yearly), `timbre_pro_monthly` (monthly), plus non-consumable `timbre_plus_lifetime`. Preserve identifiers for entitlement continuity; source has no authority to invent portal products.
- [ ] Confirm subscription levels, localized names/descriptions, live prices/availability, eligible offers, paywall screenshots and review notes. Cross-check paywall disclosure against actual StoreKit values.
- [ ] Cover purchase/cancel/pending/error, restore, renewal/expiration, refund/revocation and billing states in cloud StoreKit tests. Obtain real sandbox/product evidence when account access and a supported test environment permit; local fixtures cannot certify Apple-side state.
- [ ] If unavailable, label real sandbox commerce evidence **unverified/blocked**, with the exact missing account/environment requirement. Do not extend the physical-device waiver to IAP/account evidence.
- [ ] Decide Family Sharing separately before any change. It [cannot be turned off once enabled for a product](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases); require specific owner approval. Claims must match verified setup.
- [ ] Submit first products with the appropriate app version following [Apple's IAP submission guidance](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase). Record actual review status later; setup is not approval.

## E. Signing and TestFlight upload — gated, not authorized here

- [ ] Verify protected `apple-delivery` environment, branch restrictions and owner review controls. Account/key privileges must actually support the operation; do not assume Admin access or generate persistent keys automatically.
- [ ] Only after authorization, obtain/configure `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` through provider secret fields. Follow Apple's [key guidance](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api); never paste key material into chat or files tracked by Git.
- [ ] Confirm exact current `main` SHA and latest push-triggered `ios.yml` success, including each `core`, `app`, `release`, `accessibility`, `gate` job, plus release evidence validation. `apple_delivery_preflight.py` must pass before signing; an earlier successful run does not override a newer pending/failed one.
- [ ] Obtain explicit signing/upload authorization naming SHA, version/build and destination. Then dispatch `apple-delivery.yml` on `main` with confirmation. Leave `internal_testflight_untranslated=false` and language scope unchanged for a submission build.
- [ ] Verify the signed archive, effective feature settings, all embedded targets, entitlements, versions, capabilities, privacy manifest/report and upload validation. `apple_archive_scope.py` is a scoped check, not a complete certification.
- [ ] Preserve non-secret build/run receipts and inspect Apple processing, warnings, export-compliance questions and TestFlight availability. Upload accepted ≠ processed ≠ approved.

The internal-only translation mode exports `testFlightInternalTestingOnly` and stamps `TimbreBuildChannel=internal`; it cannot be submitted to App Review or external testers. It does not waive exact-source preflight. `ship_min_coverage` does not waive all-language completeness; no silent language reduction is authorized.

## F. Physical-device disposition — owner-waived, unverified

**This section is an explicit recorded exception, not a box to mark passed.** The owner said real-device testing is impossible and authorized proceeding through cloud/Actions. Keep [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md) as the future test specification; do not delete or rewrite historical failures as success.

| Unverified hardware scope | What cloud evidence cannot establish |
|---|---|
| Microphone start/stop, interruptions | Actual device lifecycle/recovery and route behavior |
| Speaker leakage and grading, latency | Real acoustic feedback, grading correctness and perceived timing |
| Wired/Bluetooth routes | Hardware routing, disconnection and latency |
| Haptics | Actual intensity/timing and accessibility usefulness |
| Watch installation, synchronization, Handoff, complications | Actual paired-device behavior and screen-off haptics |
| Physical VoiceOver / Dynamic Type | End-to-end assistive-technology behavior on hardware |

The waiver does not waive simulator accessibility, privacy, store media, Apple Music account configuration, IAP/account validation or Apple rules. If a later failure demonstrates a real defect, fix it; do not use this waiver to hide known bugs. If hardware becomes available, record new evidence separately and re-review the policy rather than silently claiming prior coverage.

## G. TestFlight review and feedback, if used

- [ ] Verify processed build identity and provide accurate beta test/review information. Invite only explicitly authorized/resolved recipients; no tester invitation is implied by this document.
- [ ] Follow Apple's [TestFlight process](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview) for internal/external distribution and any Beta App Review requirement. External testing is not assumed to have occurred.
- [ ] Triage actual crashes, feedback and commerce findings to the build tested. No invented tester count, feedback period or fixed launch schedule.

## H. Store metadata and media

### H1. iPhone and iPad screenshots

- [ ] After verified merge, run `listing-assets.yml` screenshot pilot on `main` for `en-US,de-DE,ar-SA`, `scope=screenshots`, `violin=false`; inspect the workflow's current dispatch restrictions first.
- [ ] Review native **1206×2622** medium Dynamic Island phone and **2752×2064** 13-inch iPad captures plus final macOS captions, then produce all 50 locales. Planned nine phone/four tablet frames per locale, complete manifests, source/build hashes and real-language proof remain required.
- [ ] Review every composed frame for legibility, truthful UI, clipping, glyphs and RTL. Upload to matching current Apple display slots; follow [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications). Preserve originals and upload inventory.

### H2. App Preview — not applicable to this initial submission

No video upload. Apple's [preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) make previews optional. Retain failed video evidence and future draft work as history; no pass or feature removal is implied. Reopening videos requires a reviewed scope/policy change and real video/audio acceptance.

### H3. Apple Watch screenshots

- [ ] Revalidate the archived `watch-store-assets-d292f88.zip`, its manifest/checksums and compatibility with final Watch source. It supplies two 416×496 frames per 50 listing folders, not phone/tablet screenshots or hardware tests.
- [ ] Include Watch assets in the portal; Apple requires the same Watch screenshot size across localizations. Do not infer upload/approval from the local archive.

### H4. App information

- [ ] Confirm final title, categories, localization mapping, age-rating answers, content rights, territories/trader details and support/privacy URLs against final features and the current portal. No source proposal is a completed questionnaire.

### H5. Version text

- [ ] Match all 50 listing payloads to source and current-content reviews; verify names, subtitles, descriptions, keywords, promotional text and IAP copy. No Game Center claims for disabled release, no unapproved prices/offers or revenue promises.
- [ ] Keep per-listing release flags false until real validation criteria pass. Listing-only fallback languages remain disclosed, not represented as additional in-app languages.

### H6. App Privacy

- [ ] Review final archive, active services, consent behavior and policy against Apple's [App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/). The source manifest is evidence to inspect, not an instruction to blindly copy portal answers.

With analytics enabled, review these declared types and actual purposes/linkage/tracking:

| Type | Relevant source flow |
|---|---|
| Device ID | Hashed random installation identifier; session grouping |
| Product Interaction | Funnel and feature events |
| Advertising Data | Allowlisted Apple Ads attribution |
| Crash Data / Performance Data | MetricKit diagnostics/metrics |
| Purchase History | Plan/price/currency and subscription events |
| Other User Content | Optional user-entered song request title |

Source declares Analytics, not linked and not tracking; verify those answers remain accurate for final service configuration. Hashing is not a blanket anonymity guarantee. Without `TELEMETRYDECK_APP_ID`, telemetry/attribution HTTP/song requests are disabled, but other network services remain. Do not automatically answer “Data Not Collected.” Imported audio and full chart text stay local; optional MusicKit searches may send selected title/artist metadata. Confirm the public policy and portal label agree before publishing.

### H7. Accessibility labels

- [ ] Evaluate each proposed label per device and across all common tasks, including onboarding, purchase and Settings, using Apple's [criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/). Recheck current submission requirements at action time.
- [ ] No automatic Yes for Dark Interface, Reduced Motion, color differentiation, contrast, Larger Text or VoiceOver. Require appropriate evidence; the physical-device waiver supplies none. Do not extrapolate iPhone audits to iPad/Watch.
- [ ] Required repository accessibility tests remain mandatory regardless of whether optional portal labels are provided. Record unsupported/unevaluated claims accurately; do not market a test failure as accessibility support.

### H8. Pricing and availability

- [ ] Confirm owner-approved app price, IAP prices/offers, countries and release method in the portal. Check actual localized StoreKit displays. No fixture value or former recommendation is a current price.

### H9. Product metadata

- [ ] Verify correct products attached, localized copy, review screenshots and review notes; compare claims with live configuration and source behavior.

### H10. In-App Events — optional, deferred

No Holiday Carols or other event is required for the initial submission. Historical dates and creative proposals are not active campaigns. Any event needs a separate truthful content/access plan, approved dates/media and current Apple configuration review.

### H11. App Review information

- [ ] Provide accurate contact, demo/access instructions where needed, purchase entry points and feature limitations. Explain the Watch companion and Your songs import/optional Apple Music routes without claiming hardware or account verification that has not happened.
- [ ] State no account requirement only if verified for the relevant app flow; distinguish optional Apple services and subscriptions. Never include API keys, financial records or unrelated personal information in notes.
- [ ] Review encryption answers for final dependencies/settings; source `ITSAppUsesNonExemptEncryption=false` is not independent legal clearance.

### H12. Version release

- [ ] Obtain owner decision for manual/automatic release and intended availability. No schedule is committed here; do not select automatic public release without authorization.

## I. Submission authorization

- [ ] Verify final exact-source gate, release validator, complete media, current policy dispositions, privacy/commerce/account checks and processed signed-build identity. No later source/config changes may silently inherit earlier evidence.
- [ ] Present remaining unverified hardware risks and any other blockers honestly. The bounded waiver is not Apple approval and does not erase missing non-waived evidence.
- [ ] Obtain explicit authorization for final build/products/metadata submission; submit only then. Record actual status and respond to Apple requests with evidence, not promises.

## J. Release and immediate verification

- [ ] Once actually approved, obtain the agreed public-release authorization/action and verify the public listing, languages, images, URLs, prices, product availability and version.
- [ ] Check available crash/support/commerce signals within an agreed scope; do not claim monitoring has started or fabricate a schedule. Diagnose real regressions and obtain authorization for changes outside existing scope.

## K. Optional growth and later work

These are not blockers for the base submission: Small Business Program, Family Sharing, Billing Grace Period, price-test products `timbre_pro_annual_b` / `timbre_pro_annual_c`, trials/offer codes/win-back offers, remote experiments, custom product pages, In-App Events, featuring, App Previews and Apple Ads. Game Center enablement is a future source/account/policy project, not part of the current disabled release.

For each later item, define goal, truthful claims, evidence, budget/owner approval and stopping condition before acting. Paid ads, irreversible Family Sharing, persistent credentials and new services are not authorized by a checklist. No projected revenue, conversion rate or launch-date guarantee is retained.
