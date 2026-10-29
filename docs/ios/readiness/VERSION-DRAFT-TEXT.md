# Version 1.0 draft text — 2026-10-28

**All 50 listing locales have recorded exact readbacks for Description, Promotional Text, original Keywords and Support URL: 200 fields.** At completion, version 1.0 remained **Prepare for Submission**. This is draft-text persistence evidence, not submission readiness or App Store publication.

The cumulative records span **2026-10-27 23:44:23–2026-10-28 00:39:36 UTC**; the completion audit was recorded at **00:39:47 UTC**. Offline reconciliation found no duplicate, missing or additional locales against [`store-locales.json`](../../../tools/l10n/store-locales.json), and all 200 values exactly match their reviewed sources and current source values. This reconciles earlier per-locale readbacks; it is not a new simultaneous check of all 50 locales or a guarantee of future state.

## Source binding

The [machine-readable receipt](reviews/version-draft-text-2026-10-28.json) preserves every original full-file SHA-256 from snapshot `4f8b69e3efad4e405714d031462a25167cc06799`. Those hashes identify the original files, not fields beyond the readback scope.

All 50 current [`tools/l10n/store/<locale>.json`](../../../tools/l10n/store/) files now differ from the snapshot only at `/iphone_screenshot_captions/2/caption`. **The earlier whole-file equality result must not be treated as current.** Description, promotional text, keywords, name and subtitle are unchanged. The common Support URL, `https://timbre-support.timbre.workers.dev/support`, is recorded separately and matches both the [delivery guide](../APPLE-DELIVERY.md) and [`AppLinks.support`](../../../ios/Timbre/Services/ShareDestination.swift); it is not a property of the per-locale JSON files.

Per-locale canonical hashes cover the four version fields and, separately, all six text fields including the previously recorded [name and subtitle](APP-INFORMATION-HEADERS.md). These hashes are produced only after exact value equality checks; the receipt defines the encoding and aggregate hashes. This does not claim a new six-field readback or verification of the changed screenshot captions. Original keywords, Unicode and description line breaks were preserved, including the 20 keyword strings exceeding 100 UTF-8 bytes; no keywords were truncated or rewritten.

## Limits

The receipt identifies retained external evidence by artifact name and SHA-256, not as public repository paths. It contains no captures or private operational material.

What's New was skipped for the initial version. Marketing URL is outside this four-field receipt. Assets, in-app purchases, privacy declarations, legal review, signing, builds, submission, release and public-storefront verification are **not established**. Native-speaker approval, device rendering, public endpoint health and market performance are also not certified. No consumer text, release-ready flag or release-evidence disposition changes. The [localized listing readiness policy](../APP-STORE-LISTING-LOCALIZED.md) remains in force.
