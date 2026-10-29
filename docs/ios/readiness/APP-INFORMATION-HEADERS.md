# App Information header persistence — 2026-10-27

**Headers only: 50 locale name/subtitle pairs were observed persisted in App Store Connect.** This is not full-listing, asset, signing or submission readiness, and it is not evidence of publication on the public App Store.

## What was observed

- **49 new locale headers:** Save was observed, followed by a full-page reload and exact visual readback of each name and subtitle.
- **Existing `en-US` header:** exact fresh-page readback, with no fields edited. Save appeared gray, but Playwright `isEnabled` returned `true`; no semantic-disabled assertion is made.
- Observations span **2026-10-27 22:09:30–23:44:49 UTC**. Per-locale timestamps and exact text are retained in the [machine-readable receipt](reviews/app-information-headers-2026-10-27.json).

The receipt covers exactly the 50 locale codes in [`store-locales.json`](../../../tools/l10n/store-locales.json), including `en-US`. There are no missing, additional or duplicate locales. Every observed name and subtitle exactly matches its [`tools/l10n/store/<locale>.json`](../../../tools/l10n/store/) source.

## Source binding and evidence limits

The reviewed text snapshot is revision `4f8b69e3efad4e405714d031462a25167cc06799`. All 50 frozen per-locale files were byte-for-byte reconciled with repository revision `2013834d947756154688f34979bf7802c6f79946`. The receipt records each repository-relative source path and its full-file SHA-256 hash, plus the inventory hash.

A full-file source hash binds the exact source version; **it does not assert that every field in that file was uploaded or read back**. The observed fields are only `name` and `subtitle`. This is a transcription of recorded browser observations, not an App Store Connect API export. Offline source reconciliation does not repeat the authenticated portal session or certify its future state.

Public [support](https://timbre-support.timbre.workers.dev/support) and [privacy](https://timbre-support.timbre.workers.dev/privacy) pages were visible in the browser at **2026-10-27 23:41:28 UTC**, with the expected titles. This observation did **not** measure HTTP status; no fresh HTTP 200, body-hash/source-alignment, response-header or uptime claim is made. Nor does page visibility verify any URL field in App Store Connect.

## What remains separate

Descriptions, keywords, promotional text, What's New, localized screenshots and App Previews, pricing/product configuration, signing/build upload and submission remain ongoing release work. This receipt does not establish their completion. It does not certify native-speaker review, legal compliance, market performance or device-render quality.

The existing [localized listing review/readiness policy](../APP-STORE-LISTING-LOCALIZED.md) remains in force. No consumer text, readiness flag or release-evidence disposition is changed. The local draft text/review check (`python tools/l10n/store.py`) passed with **50 locales and zero problems** at the reconciled revision; that is not the release gate.

Only intended app metadata and nonsecret provenance are included here. Authenticated browser/account captures and private account material are not part of the published receipt.
