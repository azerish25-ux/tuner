# Timbre for iOS

Native Swift and SwiftUI port of Timbre's Android instrument tuner and singing practice app. Requires iOS 17 or later. App Store archives use Xcode 26 or later and the iOS 26 SDK or later.

The app includes the original 60-instrument catalogue, 102 tunings, 71 photographic instrument variants, reference tones, eight vocal exercises, metronome, measured practice history, 49 language tables, and the original fonts and colour palette. Pitch analysis runs on the device; microphone recordings are neither retained nor uploaded.

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

The [iOS workflow](https://github.com/azerish25-ux/tuner/actions/workflows/ios.yml) runs core regressions, validates resources, executes simulator application/StoreKit/UI tests on iPhone plus a separate 13-inch iPad portrait/landscape flow, creates an unsigned device archive, and separately compiles the optional advertising overlay. Its `ios-evidence` artifact contains the Xcode result bundle and archive when those steps succeed. Screenshots are attached to the UI test results and exported; `ipad-evidence` contains the tablet result and captures. Inspect the actual run results before treating a revision as verified.

`ios/Sources/TimbreCore` contains the Foundation-only musical and persistence logic. `ios/Timbre` contains the native interface, AVAudioEngine integration, StoreKit commerce and consent-gated advertising. `ios/project.yml` is the Xcode project source. Generated Xcode projects and build products are ignored.

## Purchases, ads and Apple delivery

The production product identifier is `timbre_plus_lifetime`, an Apple non-consumable. Prices come from StoreKit. The test fixture is bundled only with test targets; its price is local test data. Google Play purchases do not automatically establish an Apple purchase entitlement.

The default project does not link an advertising SDK and runs without advertising credentials. To include advertising, generate with `xcodegen generate --spec project-ads.yml` and supply the owner's iOS AdMob application and interstitial identifiers. Release builds reject missing or Google demo identifiers. The overlay uses UMP for consent and privacy choices. CI compiles the optional integration separately with Google's demo application ID. Never put Apple signing keys, certificates or passwords in repository files.

The [manual Apple delivery workflow](.github/workflows/apple-delivery.yml) requires explicit owner confirmation and protected environment secrets. It is separate from normal verification and must not be dispatched until the owner authorizes Apple delivery. See [Apple delivery instructions](docs/ios/APPLE-DELIVERY.md), [privacy policy](docs/ios/PRIVACY.md), and the [source parity audit](docs/ios/parity-audit.md).

The bundled resources are sufficient to build. Regenerating them with `tools/import-ios-resources.py` additionally requires the original Android source copied to the ignored `reference/android` directory and Python Pillow. The original icon vector is retained at `tools/timbre-icon.svg`.
