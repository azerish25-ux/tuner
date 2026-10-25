# Timbre for iOS

A precision tuner and a music-lessons app that listens as you play, for iPhone, iPad and Apple Watch, built in Swift and SwiftUI. Requires iOS 18 or later. App Store archives use Xcode 26 or later and the iOS 26 SDK or later.

**New here? Start with [docs/HANDOVER.md](docs/HANDOVER.md)** — the state of the project, what's unfinished, how to release, how development was run, and links to every other document.

The app includes a 60-instrument catalogue with 132 tunings and 73 photographic instrument variants, 7 3D instruments, 300 recorded instrument samples, 526 teaching lessons in 11 courses plus songbooks (146 songs), a play-along with a band, chord and strum checking, ear training, metronome, drone, voice exercises, measured practice history, streaks, quests and badges, widgets, a Live Activity, App Intents, Game Center, a watch companion and 49 language tables. Pitch analysis runs on the device; microphone recordings are neither retained nor uploaded.

## Build and verification

GitHub Actions supplies the macOS/Xcode environment; local development can also use a Mac:

```sh
swift test --package-path ios --parallel
python3 tools/verify-ios-resources.py
brew install xcodegen
cd ios
xcodegen generate
open Timbre.xcodeproj
```

The [iOS workflow](https://github.com/azerish25-ux/tuner/actions/workflows/ios.yml) is the pull-request gate: its required `gate` check passes only when the core job (engine tests with a coverage floor, resources, the translation handoff and the legal/permission/VoiceOver string gate, comment hygiene, SwiftLint), the app job (unit tests and three smoke UI flows) and a Release device build are green, each in under 15 minutes, with compiler warnings treated as errors (concurrency warnings are counted per file while they are cleared). Its `accessibility` job runs the accessibility audit and the localization launches beside it. The [nightly workflow](.github/workflows/nightly.yml) runs the full UI tour with the App Store captures, the 13-inch iPad flow, the accessibility matrix, the thread sanitizer and the unsigned archive, every night and on pull requests labelled `captures`. Results, logs and screenshots are published to the `ci-results/*` branches (the tour's captures to `ci-results/app`, the iPad's to `ci-results/ipad`). Inspect the actual run results before treating a revision as verified.

`ios/Sources/TimbreCore` contains the Foundation-only musical and persistence logic. `ios/Timbre` contains the interface, the RealityKit tuning stage, AVAudioEngine integration and StoreKit commerce; `ios/TimbreWidgets` holds the widgets and Control Center control. `ios/project.yml` is the Xcode project source. Generated Xcode projects and build products are ignored.

## Purchases and Apple delivery

Timbre Pro is sold as `timbre_pro_annual` (two-week free trial) and `timbre_pro_monthly` in the **Timbre Pro** subscription group, plus `timbre_plus_lifetime` (non-consumable). Every instrument's standard tuning is free, and guitar, bass, ukulele, violin and cello are free in every tuning (one custom tuning is free); the other instruments' alternate and custom tunings, most lessons beyond each course's first unit, and the full practice set are Pro (`AccessPolicy`, `FreeTier`). Prices come from StoreKit; the bundled `.storekit` fixture is test data. There are no ads.

The [manual Apple delivery workflow](.github/workflows/apple-delivery.yml) signs automatically with an App Store Connect API key and uploads to TestFlight. It needs explicit owner confirmation and the `apple-delivery` environment secrets, and must not be dispatched until the owner authorizes delivery. See [Apple delivery instructions](docs/ios/APPLE-DELIVERY.md) and the [privacy policy](docs/ios/PRIVACY.md).

## 3D instruments

The seven shipped 3D instruments are Sketchfab models under CC BY (credits in each rig file), converted for RealityKit. `tools/models` also contains a pipeline that builds instruments from code in Blender 4.5 (the `3D assets` workflow), renders studio cards with Cycles and writes rig files that tell the app which nodes are pegs and strings; `python3 tools/models/install_assets.py <built folder>` copies them into the app. See [docs/TOOLS.md](docs/TOOLS.md).

The bundled resources are sufficient to build. `tools/import-ios-resources.py` was the one-time import from the Android app; it now refuses to run, because it would overwrite everything added since. The original icon vector is retained at `tools/timbre-icon.svg`.
