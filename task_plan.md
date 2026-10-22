# Timbre Swift iOS port

## Objective and approved direction
Port the complete existing Android app to native Swift/SwiftUI, retaining features, catalogue, assets, musical calculations and appearance. Build and verify with GitHub Actions macOS runners. Stop at Apple Developer signing/delivery and notify the owner. No mandatory recruited tester pool. Device audio remains explicitly unverified until measured.

## Architecture
- `ios` Swift package: Foundation-only TimbreCore models, pitch DSP, tuning/session rules, vocal sequences/scoring and tests.
- `ios/Timbre`: SwiftUI presentation, AVAudioEngine capture/playback/metronome, durable local state, StoreKit 2 commerce.
- XcodeGen defines the iPhone/iPad application and UI test target.
- JSON catalogue and source images/fonts imported reproducibly from the Android snapshot.
- GitHub Actions runs core tests, simulator build/UI tests and unsigned device archive. Signing and upload are a final owner handoff.

## Phases
- [x] Inspect repository/access and snapshot Android source without local signing credentials.
- [ ] Inventory actual shipped features and source contracts; map each to Swift implementation and verification.
- [ ] Foundation core, tests and macOS CI (DSP, catalogue, tuning maths, vocal progression/scoring).
- [ ] Native audio, lifecycle and route/interruption handling.
- [ ] Faithful Collection/Bench/Voice/Studio/History/Settings/Plus screens, assets and localization.
- [ ] Persistence, commerce, free/paid policy and ads parity decision/integration.
- [ ] Simulator UI flow verification and screenshots; unsigned device archive.
- [ ] Review code and parity evidence, fix gaps, prepare Apple delivery instructions and notify owner.

## Verification
Port existing regression vectors and edge cases. Run `swift test --package-path ios` on macOS. Generate project with XcodeGen; run simulator UI tests and capture screenshots, then archive for generic iOS with signing disabled. A green build alone is not feature parity. Retain a checklist with exact implementation and evidence.
