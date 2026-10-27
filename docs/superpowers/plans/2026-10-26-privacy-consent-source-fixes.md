# Privacy consent source fixes implementation plan

**Goal:** Make opt-out stop queued and in-flight analytics work, make requests truthful, and keep unconfigured Game Center off.

**Architecture:** A Foundation-only `AnalyticsTransport` serializes consent generations, token creation, request creation and delayed retries. Revocation synchronously invalidates old leases and cancels tracked URLSession tasks. Telemetry retains batching; an explicit song request uses an immediate independently acknowledged upload. Stale responses cannot clear newer handles or report delivery after revocation.

**Tech stack:** Swift 5.10 app mode, Foundation URLSession, XCTest in TimbreAppTests, XcodeGen configuration.

## Constraints

- User/parent explicitly requests implementation in this shared checkout, no commits/pushes or Apple account changes.
- Root owns privacy/site/store/provenance and translations; preserve its Cloudflare URL and event-name-only logging.
- No Swift/Xcode executable is installed on this Windows host. Native tests must be authored before implementation and recorded as unexecuted, never claimed green.
- New UI keys are reported to root for all 48 non-English locales; do not force telemetry consent as the only support path.

## Task 1 — consent transport and attribution

Files: create `ios/Timbre/Services/AnalyticsTransport.swift`, modify `ios/Timbre/Services/Analytics.swift`, create `ios/TimbreAppTests/AnalyticsPrivacyTests.swift`.

- [x] Write URLProtocol-stub XCTest cases before implementation: off cancels a held request, stale completion after off/on cannot acknowledge success, pending old lease cannot create a token/request/retry, new generation still sends, HTTP failure does not acknowledge song delivery.
- [x] Attempt focused native test command and record environment limitation: `xcodebuild test -scheme Timbre -only-testing:TimbreAppTests/AnalyticsPrivacyTests`.
- [x] Implement lease-gated transport: `setEnabled(_:)`, `lease`, `perform(for:_:)`, `post(_:lease:completion:)`, delayed `perform(after:lease:_:)`; all mutations on one queue.
- [x] Route batching and explicit submission through that transport. `setSharing(false)` clears queued events, stops timer and cancels active requests synchronously.
- [x] Replace detached attribution task with lease-checked token/request/retry callbacks, at most 3 tries, 5-second retry delay; remove country from output whitelist. Only accepted analytics upload marks attribution done.
- [x] Inspect all entry points and run available source/config checks; record native execution pending.

## Task 2 — song-request truthfulness

Files: modify `ios/Timbre/Songs/SongsView.swift` and focused test file.

- [x] Test explicit submission result for disabled/unconfigured delivery and HTTP errors with the same transport stub.
- [x] Keep input until success, show pending state, never display old success for a failed next submission; present a localized error on rejection/failure and a localized disclosure before send.
- [x] Recheck consent on actual submission as well as UI; no consent-setting shortcut or forced opt-in.
- [x] Report exact new keys to root for translation integration and runtime matrix follow-up.

## Task 3 — release configuration and manifest

Files: modify `ios/Timbre/Services/GameCenter.swift`, `ios/project.yml`, `ios/Timbre/Resources/PrivacyInfo.xcprivacy`; extend focused tests.

- [x] Test configuration parsing defaults off and refuses unresolved/false values.
- [x] Gate GameKit activation and activity entry on explicit `TimbreGameCenterEnabled` build setting default NO; retain local ear/Pitch Sniper games and local score sharing.
- [x] Add DeviceID, PurchaseHistory and OtherUserContent manifest declarations, purpose Analytics, linked false/tracking false, matching existing source behavior and H6.
- [x] Parse XML/YAML/source artifacts and inspect diff, preserve root Cloudflare URL.

## Final verification and handoff

- [x] Save `docs/ios/readiness/reviews/privacy-source-fixes.json` with file inventory, exact new localization keys, validations actually run, native stub-network tests pending execution and remaining account requirements.
- [ ] Root obtains independent review and native CI results before claiming App Store readiness; no local commit/push.

Native execution note: focused xcodebuild invocation failed because Xcode is not installed. The 12 XCTest cases are authored and unexecuted; source/XML/YAML and whitespace checks passed locally. Translation integration and native runtime validation remain root-owned release gates.
