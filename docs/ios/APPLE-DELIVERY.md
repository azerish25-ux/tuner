# Timbre iOS — Apple delivery handoff

This document describes the remaining Apple-account and release work. It is not evidence that the current revision's tests, archive, App Store product, live advertising or submission have succeeded. Inspect the latest GitHub Actions results and release artifact before delivery.

## Application identity

- Repository: https://github.com/azerish25-ux/tuner
- Application: **Timbre**
- Current XcodeGen bundle identifier: **com.shahradazerisharghi.timbre** (`ios/project.yml`)
- Deployment target: **iOS 17.0**, iPhone and iPad
- Owner/support: **Shahrad Azeri Sharghi**, **azerish25@gmail.com**
- Non-consumable purchase identifier: **timbre_plus_lifetime**
- Intended privacy URL after these files are merged to publicly accessible `main`: **https://github.com/azerish25-ux/tuner/blob/main/docs/ios/PRIVACY.md**
- Standard Apple EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Verify that the privacy URL opens without authentication after merge. A file on an unmerged branch or a private repository is not a public metadata URL. The previous linked Worker privacy site must not be assumed available. If this repository is private, publish this same approved policy at a publicly reachable location before submission.

## Owner's Apple setup

1. Register the exact bundle ID in Certificates, Identifiers & Profiles and create the matching iOS app in App Store Connect. Confirm the owner has accepted applicable agreements and configured required paid-app banking/tax information.
2. Create **timbre_plus_lifetime** as a **non-consumable** in-app purchase. Add its localized display name/description, chosen real price and availability, and review screenshot/information. This is a permanent unlock with no renewal. The StoreKit fixture's 7.99 is strictly local test data and is not a production price decision. The app uses Apple's `displayPrice`.
3. Add App Store metadata, support contact, privacy URL, category, age-rating questionnaire, export-compliance answers, and required iPhone/iPad screenshots. Complete App Privacy against the actual release SDK/configuration, including third-party partners; the on-device microphone design does not justify declaring all third-party data collection absent. Apple requires disclosure of integrated partners' practices. [Apple's privacy guidance][apple-privacy] and [Google's iOS SDK disclosure][google-disclosure] are the starting evidence.
4. Establish signing for this bundle ID: Apple distribution certificate/private key and App Store provisioning profile, or an authorized automatic-signing workflow with appropriately scoped credentials. The current unsigned archive cannot be installed or uploaded as a signed App Store build.
5. Create a scoped App Store Connect API key for the approved CI upload process and retain its issuer ID/key ID. The owner must authorize the signed delivery/upload step. Do not place credentials in chat, repository files, issues, logs or build artifacts.

## GitHub Actions signing secrets

Use repository/environment **GitHub Actions secrets**, ideally a protected release environment with required owner approval. The manual `.github/workflows/apple-delivery.yml` workflow uses the following exact names in the `apple-delivery` environment:

| Secret | Contents/use |
|---|---|
| `APPLE_TEAM_ID` | Apple Developer team identifier used for signing |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64 transport of distribution certificate and private key; remains a secret, not encryption |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that certificate export |
| `APPLE_PROVISIONING_PROFILE_BASE64` | App Store provisioning profile matching bundle ID and certificate |
| `APP_STORE_CONNECT_KEY_ID` | Upload API key identifier |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer identifier |
| `APP_STORE_CONNECT_API_KEY_P8` | Complete raw PEM contents of the downloaded `.p8` private key, including BEGIN/END lines; do not Base64-encode this secret |

Alternative signing methods can avoid a manually supplied profile, but must be concretely configured and verified before replacing these inputs. Use an ephemeral CI keychain, temporary files with restrictive permissions, and cleanup that runs even on failure. Do not echo secret values, enable shell tracing around secrets, or upload keychains, `.p12`, `.p8`, profiles or temporary credential directories. Rotate/revoke exposed credentials. Follow [Apple's API-key guidance][apple-keys] and [GitHub's secrets guidance][github-secrets].

## Optional iOS advertising configuration

To retain free-edition monetization, the owner must create/confirm an **iOS** AdMob app and interstitial ad unit. Android identifiers do not identify the iOS app. Supply production GitHub repository or `apple-delivery` environment variables `TIMBRE_ADMOB_APP_ID` and `TIMBRE_ADMOB_INTERSTITIAL_ID`; the delivery workflow forwards them as build settings and selects `ios/project-ads.yml` only when both are valid. `GADApplicationIdentifier` resolves from the former. The baseline `ios/project.yml` does not link the advertising SDKs, avoiding SDK startup without an application identifier. Configure privacy messages in AdMob, verify required privacy-options access, and review the actual SDK privacy manifests and App Store privacy answers. If any proposed advertising behavior constitutes tracking, implement and validate Apple's applicable permission requirements before enabling it. [Google's UMP documentation][google-ump] and [Apple's tracking guidance][apple-tracking] describe separate responsibilities.

When identifiers are absent, the delivery workflow selects the baseline build without advertising SDKs. Malformed, incomplete or Google demo identifier pairs fail delivery validation instead of producing a release with invalid advertising configuration. Test identifiers/debug opt-in are not production monetization. Do not claim live iOS ads or consent-region behavior were verified until the configured release has been tested. If shipping without advertising, make that release decision explicit and ensure policy/metadata match the delivered build.

## Signed delivery workflow outline

The existing `.github/workflows/ios.yml` builds/tests on hosted macOS and creates an **unsigned** archive. Signing and uploading use the separate manual `.github/workflows/apple-delivery.yml` workflow. It runs only through `workflow_dispatch`, requires `confirm_delivery=true`, the approved `marketing_version` and a unique positive `build_number`, and targets the `apple-delivery` environment. Do not dispatch it before the owner authorizes Apple delivery. Its steps are:

1. Select an exact reviewed commit; require successful latest core, application integration/StoreKit and UI flow jobs. Inspect simulator screenshots and test artifacts, rather than inferring feature parity from a compile alone.
2. Resolve dependencies and generate `ios/Timbre.xcodeproj` with XcodeGen. Set the approved Apple team, bundle/version/build values and optional advertising configuration.
3. Import signing inputs into the ephemeral keychain and install the correct profile. Archive for `generic/platform=iOS` with distribution signing enabled; do not use `CODE_SIGNING_ALLOWED=NO` for this archive.
4. Export with an App Store Connect distribution ExportOptions file for the same team/bundle. Check the signed app's identity, entitlements, version and resources. Local `.storekit` fixtures belong to test resources and must not be included in the release app.
5. Upload the approved exported build using an Apple-supported upload tool authenticated with the scoped App Store Connect key. Preserve upload/processing results and report failures accurately.
6. After Apple processes the build, select it in App Store Connect, attach the in-app purchase as required, finish review notes/metadata, and obtain owner authorization for the intended TestFlight or App Store submission action.
7. Remove temporary credentials/keychain/profile copies from the runner. Retain useful test/archive/export evidence without secrets.

TestFlight distribution and App Store submission are distinct choices. This handoff imposes no recruited tester count; it also does not claim Apple's review is waived. Simulator checks cannot establish actual iPhone microphone latency, routing or acoustic accuracy. Those hardware measurements remain explicitly unverified until performed.

[apple-privacy]: https://developer.apple.com/app-store/app-privacy-details/
[apple-keys]: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
[github-secrets]: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
[google-disclosure]: https://developers.google.com/admob/ios/privacy/data-disclosure
[google-ump]: https://developers.google.com/admob/ios/privacy
[apple-tracking]: https://developer.apple.com/app-store/user-privacy-and-data-use/
