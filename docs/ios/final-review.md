# Native iOS final code review

Reviewed the current Swift integration using `code-review-and-quality` across correctness, security, architecture, readability and performance. The authoritative sources are the working files, with runtime evidence limited to the exact revision executed by CI.

## Verification state

[GitHub Actions run39851758978](https://github.com/azerish25-ux/tuner/actions/runs/39851758978) has passed core regression tests, iPhone application/StoreKit/UI tests and the unsigned generic-device archive, as reported by the coordinating agent. Its optional advertising integration compile also passed.

The next revision includes additional pause/reference/calibration resets, restoration regression coverage, metronome background checks and iPad tests. These later edits are **not covered by the earlier run**. Final approval requires successful results for the exact final commit and inspection of its screenshots/artifacts.

## Findings closed in current source

| Reviewed issue | Current implementation/evidence |
|---|---|
| Physical bass/mallet image mismatched selected preset | `AppStore.photo` delegates to tuning-aware `Catalog.photo(instrumentId:tuningId:preferredAsset:)`. Four core regression cases cover variant mapping, incompatible preferences and foreign preset IDs. |
| Collection instrument/photo/preset selection partially committed | `selectInstrument(_:photo:tuning:)` validates access and ownership, saves one candidate, and changes session/navigation only after confirmed persistence. Both Collection selection paths use it. |
| Failed voice save resurrected after history deletion | Successful `clearHistory` clears pending record/result/retry state and stops activity; failed disk deletion retains retry evidence and reports an error. |
| Overlapping StoreKit snapshots published stale ownership | CommerceService serializes revisioned verified-entitlement refreshes; superseded enumerations are discarded and waiting callers resume after the latest snapshot. Test setup polls actual cleared StoreKit state. |
| Unconfigured linked Google SDK failed at launch | Baseline project excludes Google dependencies and GAD application ID; compile-guarded no-SDK AdvertisingService is used. Ads overlay adds dependencies only with validated build configuration. |
| Audio errors were inaccessible outside Studio | Root presents global audio errors and an Open Settings action for denied microphone access. Voice cancels on audio errors; entering Settings/History stops audio. |
| Paused measurements appeared live | Explicit pause preserves an identified LAST measurement; resume/target changes reset it appropriately in the pending revision. New regression coverage still requires final CI. |
| Foreign remembered preset could select another instrument's courses | Restored preset ownership is checked; unknown/foreign IDs fall back to the instrument default. New regression coverage still requires final CI. |

## Reference-note reset follow-up

The pending reference observer regression is corrected in the current source: `referenceMidi` is `private(set)`, and the manual Stepper calls `chooseReferenceNote`, which clears the retained reading, resets the tracker/tone and disables automatic mode. Automatic detection assigns the note internally without switching automatic mode off. Successful settings changes also clear a retained reading. New regressions cover multiple distinct automatic reference pitches and manual-note/calibration changes after pause; their execution awaits the final revision's CI.

## Advertising boundary

Default `project.yml` has no Google package/dependency and does not define `TIMBRE_ADS_ENABLED`. `project-ads.yml` explicitly adds Mobile Ads/UMP, compilation conditions and the GAD application ID. Its prebuild script rejects absent/invalid app IDs and rejects missing/test production identifiers for Release. DEBUG ad requests require explicit test-ad opt-in. The optional CI job compiles the overlay with Google's test application ID.

Compilation proves API/build compatibility only. It does not establish consent-region behavior, successful live ad delivery or production account configuration. Inspect linked frameworks in the final baseline artifact and treat configured advertising as a separate release choice.

## Remaining limits and release gate

No production entitlement override, hard-coded purchase price, raw-audio persistence or credential material was identified in the reviewed native app. DEBUG storage isolation accepts a UUID and changes only the test data directory. Summary history is retained until explicit deletion; unmeasured accuracy/duration remains optional.

Collection's recents follow selection rather than Android's completed-session-derived order, an intentional UI difference. Forty-nine localization tables exist, but every translated phrase has not been linguistically validated. Simulator results do not measure physical iPhone acoustic accuracy, microphone latency, routing or interruptions. Live Apple product/signing/upload and optional production AdMob setup remain the documented owner handoff.

There is no unconditional final approval while the latest edits remain unverified. Require the final commit's successful core/app/StoreKit/iPhone/iPad tests, archive and relevant screenshots before claiming the port's automated verification is complete.
