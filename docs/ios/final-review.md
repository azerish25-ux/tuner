# Final independent native integration review

Reviewed current 0876588-era source and visible working-tree changes using `code-review-and-quality` across correctness, security, performance, architecture and readability. Earlier findings were rechecked against authoritative files. The parent reports the latest core job passed64 tests; application/StoreKit/UI tests are still running. This is source closure evidence, not overall runtime approval.

## Earlier findings rechecked

| Finding | Current evidence | Status |
|---|---|---|
| P2 physical picture/header did not follow bass/mallet preset | `AppStore.photo` calls `Catalog.photo(instrumentId:tuningId:preferredAsset:)`. Resolver follows four/five-string and all four mallet presets while preserving compatible other aliases. `PhotoSelectionTests` has four regression cases. | Source closed; app screenshot/preset execution still requires latest test result. |
| P2 failed voice save could resurrect after history deletion | `AppStore.clearHistory` first successfully clears disk, then clears `pendingVoiceRecord`, `voiceSaveFailed`, `voiceResult`, stops activity and resets tuning counters. Failure retains state and reports error. | Source closed; runtime/regression evidence still required. |
| P2 multi-step instrument/preset/photo selection could partially commit | Each `updateSettings` commits confirmed settings before publishing them and returns a Bool. However Collection still invokes `selectInstrument` then `selectTuning` as separate persistent operations; callers cannot observe the first method's success. | Per-write failure handling improved; multi-step action remains source-open as described below. |

## Remaining actionable finding

### [P2] Commit a Collection instrument+preset choice atomically

Current locations: `ios/Timbre/Views/LibraryView.swift:110` (preset Menu), `:139` (photo open), `ios/Timbre/Services/AppStore.swift:103` (`selectInstrument`) and `:114` (`selectTuning`).

Both Collection paths still select instrument/photo and then select its preset in two disk writes. `updateSettings` correctly retains the old published settings when an individual save fails, but that does not make the whole user action atomic. If the first write succeeds and the second fails, active instrument/photo already changes while its requested preset does not. If the first fails, the caller still attempts a tuning operation against the previous instrument, potentially replacing the useful save failure with an ownership error; it also unconditionally navigates to Bench.

Use a validated instrument+preset+photo selection method that produces one settings candidate and one persistent commit. Stop/reset the session and navigate only after that commit succeeds. A tuning-only action can remain separate for the current instrument. Add a regression for write failure that proves all selection fields and navigation remain unchanged. This finding is based on currently inspected files, not the earlier absence of per-write Bool handling; recheck if the parent subsequently completes this change.

## Newly rechecked integration paths

- RootView now displays `audio.error` as well as store errors, provides Open Settings when microphone permission is denied, and cancels active voice on an audio error. SettingsView/HistoryView stop audio when entering those screens.
- The action/text accent is adaptive for light and dark backgrounds while filled primary-button colors remain intentionally paired. Dynamic text/RTL and screenshot inspection still need runtime evidence.
- DEBUG-only test storage accepts a UUID environment value and places state below a dedicated application-support test directory. Release code does not read this environment override. It changes storage isolation only; it does not fabricate entitlement, pitch or history.
- Verified StoreKit current entitlements remain the paid authority; revocation/upgrades are rejected, and initial unresolved commerce suppresses ads. No persisted `isPlus` bypass was found. Cold restoration/Ask to Buy/refund behavior still require actual StoreKit suite results.
- Original course action cues/flat spellings and every paired pitch remain available through TargetLabelFormatter and the per-course strip. History duration/optional accuracy analytics and persisted voice level/evidence are present; destructive500-record trim is removed.
- Capture queue bounding, generation/cancellation checks and tone capture invalidation remain present. Source inspection cannot establish actual acoustic latency, routing or interruption behavior on iPhone.

## Advertising startup crash fix: source boundary reviewed

The baseline `ios/project.yml` now references only the local TimbreCore package and does not include Google SDK packages/dependencies or a `GADApplicationIdentifier`. `AdvertisingService.swift` imports/implements Google APIs only under `TIMBRE_ADS_ENABLED`; otherwise the application receives a compatible no-SDK service that does no advertising/consent work. This addresses the previous design where merely linking the Google SDK with no valid application ID could fail at application startup before the app-level configured guard helped.

The explicit `ios/project-ads.yml` overlay adds Google Mobile Ads/UMP dependencies and the compilation condition, resolves `GADApplicationIdentifier` from `TIMBRE_ADMOB_APP_ID`, and runs a prebuild validation script. The script rejects absent/invalid application IDs; Release additionally requires a valid production interstitial ID and rejects Google's test publisher. AdvertisingService separately rejects unconfigured Release IDs and requires DEBUG test-ad opt-in before requesting Google's test interstitial.

CI generates the baseline project for tests and unsigned archive first, then separately generates the ads overlay and compiles it with Google's documented test application ID. These are distinct verification scopes: the optional integration **compile** does not prove its launch, consent-region UI, network requests or a production ad unit. No source path was identified that links/loads Google in the unconfigured baseline. Inspect final app linked frameworks and launch artifacts to close runtime evidence rather than inferring it from this source structure.

## Approval/evidence gate

No overall approval claim is made while the remaining Collection transaction finding is open and the latest application/StoreKit/UI jobs are in progress. After the fix, inspect actual successful results for the same commit, simulator screenshots, unsigned generic-device archive and optional ads compile. An earlier core/job pass cannot establish the current app/UI revision. Signing/AppStoreConnect delivery and live AdMob configuration remain the owner handoff described in APPLE-DELIVERY.md.
