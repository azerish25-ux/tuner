# Native iOS verification and review

> Historical: this audit describes the v1 Android port (lifetime purchase and optional ads). Version 2 replaced ads with Timbre Pro subscriptions; see README.md and APPLE-DELIVERY.md.


Reviewed native app and domain code for correctness, security, performance, architecture and readability. No actionable P1/P2 findings remain in the reviewed production source. The Android comparison uses the local, ignored reference snapshot; it is not a second application shipped in this repository.

## Runtime evidence

Verified executable revision: `df44acb` ([Actions run 39862780625](https://github.com/azerish25-ux/tuner/actions/runs/39862780625)), completed successfully on October 22, 2026. Subsequent integration changes only update documentation; app, core, tests, project definitions and workflows remain identical to this verified revision.

| Check | Result |
|---|---|
| Foundation-only core regressions | 64 tests passed |
| App integration and verified StoreKit tests | 18 tests passed |
| iPhone UI flows | 7 tests passed |
| 13-inch iPad portrait/landscape flow | 1 test passed |
| Catalogue, assets, fonts and localization resource checks | Passed |
| Unsigned generic-iOS Release archive | Passed |
| Optional Google advertising overlay compile | Passed |

**90 automated tests passed.** Test ownership comes from actual verified local StoreKit transactions. The cold-launch fixture establishes the verified store precondition before creating a fresh service; microphone UI testing confirms the actual permission dialog is dismissed. These checks grant no production entitlement and fabricate no microphone data.

## Findings closed

| Issue | Implementation and verification |
|---|---|
| Instrument/photo/preset partially committed | Collection uses one validated settings commit; failure keeps the previous selection and navigation. Integration regression covers unavailable storage. |
| Physical image did not follow bass/mallet preset | Tuning-aware photo resolver preserves compatible aliases and follows physical variants; domain and app tests cover the mappings. |
| Invalid remembered preset could select foreign courses | Unknown/foreign preset IDs fall back to the instrument's own default. |
| Paused pitch appeared live or survived a new target | Explicit LAST state; resume, manual course/reference note and calibration changes clear it. Automatic chromatic tracking remains automatic. |
| Recently used order differed from Android | Completed instrument sessions take precedence, deduplicated newest first; remembered selections are the fallback when none exist. |
| Failed voice save could return after deletion | Atomic persistence, explicit retry with retained record identity, and successful clear-history removal of pending retry/progress state. |
| Overlapping StoreKit snapshots could publish stale ownership | Revisioned, serialized verified entitlement reconciliation. No local ownership flag; purchase, pending, refund, restoration and cold service paths are exercised. |
| Linked Google SDK crashed without an app ID | Baseline does not link Google. Explicit overlay validates IDs before building and rejects Google demo IDs for Release. |
| Audio errors were hard to reach | Global error presentation, microphone Settings link, generation cancellation, and audio stop on navigation/background. |
| Required timer declaration missing | App PrivacyInfo.xcprivacy declares SystemBootTime reason `35F9.1` for elapsed timers; resource verification checks it. |

## Evidence inspected

- Actual iPhone screenshots: twelve-string paired courses, purchase gate and verified unlock, timed voice with no fabricated accuracy, Studio metronome playing and stopped after backgrounding, history, custom calibration, and German/Persian accessibility-size and RTL layouts.
- Actual 13-inch iPad screenshots: complete portrait/landscape tuner, Browse, all eight Singing previews with selected piano note, Studio and Settings. Tests require real rotation, reachable in-bounds controls, selected native tabs and visible destinations. Captures use the unmodified physical-display screenshot.
- Unsigned `df44acb` device archive: bundle `com.shahradazerisharghi.timbre`, iOS17 minimum, iPhone/iPad families, Xcode26.3/iOS26.2 SDK, app icon/fonts, and timer privacy declaration. No StoreKit fixture or default Google SDK bundle is present. The final artifact was downloaded and inspected directly.
- The test environment uses actual local StoreKit transactions and real microphone permission controls. DEBUG UUID storage isolation changes the data directory only; it grants no entitlement, supplies no pitch and fabricates no history.

## Advertising and Apple boundary

`project.yml` builds without advertising SDKs. `project-ads.yml` adds Google Mobile Ads/UMP only with validated configuration; CI separately compiles it with Google's documented demo application ID. Compile success does not establish live advertising or consent-region behavior. Production iOS AdMob IDs/messages and release privacy answers remain an owner release choice.

Forty-nine localization tables are bundled; every phrase has not been independently reviewed linguistically. Simulator checks do not measure physical iPhone acoustic accuracy, latency or hardware route/interruption behavior. No Apple signing or upload has been executed. The manual delivery workflow uses the `apple-delivery` environment, restricted to `main` with owner review, and the exact secrets listed in APPLE-DELIVERY.md.
