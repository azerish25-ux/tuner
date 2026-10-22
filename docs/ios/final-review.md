# Final independent native integration review

Review scope: current native Swift source at the parent-requested ec48b6a baseline plus immediately visible working-tree changes; reviewed using `code-review-and-quality` across correctness, security, performance, architecture and readability. Earlier audit findings were rechecked against the current files rather than copied as unresolved. This document is not merge approval. The parent reports 60 core tests passing, while latest Xcode26.3 application/StoreKit/UI execution is still pending; those results were not independently established by this source review.

## Actionable findings

### [P2] Resolve physical photo variants from the active tuning

Locations at review: `ios/Timbre/Services/AppStore.swift:77` and `:113`.

`photo` prioritizes the persisted `selectedPhotoAsset`, while `selectTuning` changes only the preset ID. Starting from the four-string bass picture and choosing `.five` in Bench or Studio therefore retains the four-string image/header while displaying B0 and five-string targets. Marimba→Glockenspiel likewise retains a Marimba image/header with the glockenspiel range. Android's `InstrumentPhotos.primary` explicitly selects the pictured variant from these tuning IDs.

Remedy prepared in this review: new `TimbreCore/Catalog/PhotoSelection.swift` adds `Catalog.photo(instrumentId:tuningId:preferredAsset:)`. Bass/mallet physical variants follow the verified owner preset; compatible preferred aliases for concert/tenor ukulele, recorder, clarinet, saxophone and concertina remain selectable. Four regression tests cover every physical variant, incompatible preferred assets, compatible aliases, foreign preset ownership and missing inputs. Parent must wire AppStore's computed photo to this resolver and verify app behavior/CI. Core helper alone does not resolve the integration finding.

### [P2] Clear pending voice-save state when deleting history

Locations at review: `ios/Timbre/Services/AppStore.swift:198`, `:239`, `:246`.

After a failed voice save, `pendingVoiceRecord` intentionally retains the record for retry. `clearHistory()` clears only persisted history and publishes records. It leaves that pending record and `voiceSaveFailed` intact. A subsequent Start or retry action runs `retryVoiceSave()` and inserts the pre-deletion attempt again, potentially restoring demonstrated progress the user explicitly deleted.

Remedy: after a successful clear, cancel the current attempt and clear pending record/result/retry state as appropriate; do not discard pending data if the disk clear itself fails. Add a regression with a failed save, successful history clear and retry/start, proving the old record/progress cannot reappear. Parent is addressing this path.

### [P2] Make instrument/preset/photo selection one persistent operation

Locations at review: `ios/Timbre/Views/LibraryView.swift:110` and `:139` (both selection paths), `AppStore.selectInstrument`/`selectTuning`.

Collection currently selects instrument/photo and preset in two separate disk writes. If instrument write succeeds and preset write fails, UI has already switched instrument/photo and may show its previous/default preset rather than the requested variant. If the first save fails, the second operation can still run against the previous current instrument, replacing the original useful error with an ownership error. The existing single-method guards do not make the two-step user action atomic.

Remedy: centralize a validated instrument+preset+photo selection operation with one settings commit; only change active session/navigation after persistence succeeds. Parent is addressing this integration path. Keep separate tuning-only selection for the existing instrument, using the same validation boundary.

## Rechecked areas without an additional blocking finding

- StoreKit access is derived from verified current entitlements, rejects revocation/upgrades, and handles pending/cancellation separately. No persisted `isPlus` bypass exists. Cold launch's initial unknown state suppresses ads until entitlement resolution. StoreKit local tests and paid UI flows still need actual successful execution.
- Tuning listening/tone and metronome actions enforce the current free/paid boundary. All paired course targets are preserved rather than collapsed by anchor. Recent target-label updates retain authored physical/action cues and flat spellings.
- Voice progression now persists selected level and demonstrated evidence; all exercise previews remain selectable. Voice saves retain the same pending record for retry rather than fabricating scores or creating new IDs on each retry.
- History no longer destructively trims at500 entries. Analytics keeps absent accuracy/duration as optional, restricts longitudinal comparison to supported same-instrument evidence, and preserves all-time scored voice attempts from retained records.
- Audio capture bounds queue work and validates permission/generation/cancellation around asynchronous capture start. Tone playback invalidates capture and clears published microphone readings. Core DSP remains on a serial worker queue; actual route/interrupt/latency behavior remains runtime evidence, not source-review proof.
- No credential material or external authorization bypass was identified in the inspected Swift app. AppStoreConnect signing inputs are documented as future GitHub secrets, not source files. Local `.storekit` data must remain excluded from release app resources.
- Bundled catalogue references are validated at load. This review did not treat hypothetical external mutation of immutable bundled resources as a new practical security finding. Current generated resources and tests, rather than public Codable conformance alone, are the relevant shipped input boundary.

## Approval/evidence gate

No approval claim is made until the findings above are wired and regression-tested on the latest commit, the application and StoreKit/UI suites actually succeed, simulator screenshots are inspected, and the unsigned generic-device archive completes. Passing an earlier core revision cannot establish current app/UI parity. Apple delivery and any production AdMob setup remain the separately documented owner handoff.
