# Watch simulator capture plan

**Goal:** Produce source-bound genuine Today and running-metronome captures for all 49 app languages and map the 50 store locales without claiming a fallback is translated.

**Architecture:** A new opt-in workflow builds the existing TimbreWatch Debug scheme. A standard-library Python harness creates a fresh paired iPhone/46 mm Series 10–12 simulator, installs the unsigned Watch app and launches each actual TabView page with language arguments. DEBUG-only hooks seed a real localized WatchSnapshot and start the real metronome; page/state/label probes are written atomically to the app's Documents directory with a unique launch token. Fresh live probes bracket each screenshot. Installed public simctl help is saved and hash-bound: prefer untouched native PNG with black mask; use honestly labeled native JPEG only when that public capability is absent. Validate 416×496 dimensions, PNG CRC/decoded pixel opacity, native ImageIO decode, source revision, hashes, page/state/locale/labels and full coverage before writing the final manifest. Native PNG alpha-channel presence is recorded separately from opaque pixels and flagged for upload review; no channel stripping or recomposition is performed.

**Scope:** New `watch-captures.yml`, `tools/ci/watch_captures.py`, Python tests, DEBUG hook source and guarded calls in `ios/TimbreWatch`. Existing project.yml and CI remain untouched. No account, signing, network setup, commits, pushes or Apple delivery dispatch.

- [x] Write failing tests for native dimensions, missing/corrupt media/probes, source/token/locale/page mismatches, full 49-language/50-store-locale coverage and explicit fallback provenance.
- [x] Implement fail-closed validator and public xcrun/simctl/xcodebuild capture harness.
- [x] Add DEBUG-only deterministic snapshot/page hooks using existing applied localization keys; release/normal behavior remains unchanged.
- [x] Add isolated opt-in workflow and artifact upload, including partial failure diagnostics.
- [x] Run Python tests and source/configuration checks; bind local receipt to source hashes. Root obtains independent review and native run.

The third handoff frame (a real system face with complications) remains separate: Simulator supports genuine screen capture, and Apple documents creating/sharing configured faces, but no public documented simctl operation found selects/configures a face. Do not fabricate one or count an app preview as a system face. Manually configure a real installed Timbre circular/rectangular complication on a compatible face, capture the actual face at the same dimensions and record provenance. Apple's published minimum is 1–10 screenshots per device size, Watch screenshots required, one consistent Watch screenshot size across localizations; a face image is not a stated minimum-media requirement.

Sources: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications ; https://developer.apple.com/help/app-store-connect/create-an-app-record/add-watchos-app-information/ ; https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/iOS_Simulator_Guide/InteractingwiththeiOSSimulator/InteractingwiththeiOSSimulator.html ; https://developer.apple.com/documentation/clockkit/sharing-an-apple-watch-face .
