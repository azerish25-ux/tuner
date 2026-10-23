# Timbre for iOS — Apple delivery handoff

What the owner sets up in Apple's portals and GitHub before the first App Store build. Nothing here has been executed yet: no signing, upload or App Store product exists until the owner does these steps.

## Identity

| | |
|---|---|
| App | **Timbre** |
| Bundle ID (app) | `com.shahradazerisharghi.timbre` |
| Bundle ID (widgets) | `com.shahradazerisharghi.timbre.widgets` |
| App Group | `group.com.shahradazerisharghi.timbre` (widgets read the practice streak from it) |
| Minimum iOS | 18.0, iPhone and iPad |
| Privacy policy URL | https://azerish25-ux.github.io/tuner/privacy.html |
| Terms | Apple standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ |

## 1. App Store Connect app

1. Accept the Paid Apps agreement and complete banking and tax (Business → Agreements). Subscriptions cannot go live without it.
2. Enrol in the **App Store Small Business Program** (15% commission instead of 30%).
3. Create the app: **Apps → + → New App**, platform iOS, name Timbre, bundle ID `com.shahradazerisharghi.timbre` (register it under Certificates, Identifiers & Profiles if it is not offered; automatic signing in step 3 can also register it).

## 2. In-app purchases (exact identifiers — the app looks these up)

Create a subscription group named **Timbre Pro** with two auto-renewable subscriptions at the same level:

| Product ID | Type | Duration | Suggested US price | Introductory offer |
|---|---|---|---|---|
| `timbre_pro_annual` | Auto-renewable | 1 year | $34.99 | Free trial, 2 weeks, new subscribers |
| `timbre_pro_monthly` | Auto-renewable | 1 month | $6.99 | none |

And one non-consumable:

| Product ID | Type | Suggested US price |
|---|---|---|
| `timbre_plus_lifetime` | Non-consumable | $89.99 |

`timbre_plus_lifetime` keeps the identifier of the earlier lifetime purchase, so anyone who bought it keeps Pro. Prices are suggestions: the app shows whatever Apple returns (`displayPrice`), including the trial length. Give each product a display name and description, a review screenshot of the paywall, and review notes saying the trial and plans are on the paywall reached from any locked lesson or Practice → Drone. Ready-to-paste names, descriptions, listing text, keywords, review notes and a pricing note are in [APP-STORE-LISTING.md](APP-STORE-LISTING.md). Submit the products with the first app version.

## 3. Signing and upload from GitHub Actions

The delivery workflow signs automatically with an App Store Connect API key, which provisions the app, the widget extension and the App Group without certificates or profiles to export.

1. App Store Connect → Users and Access → Integrations → **App Store Connect API** → Team Keys → generate a key with the **Admin** role (automatic signing needs to create a distribution certificate). Download the `.p8` once; note the Key ID and Issuer ID.
2. Find the Team ID under Membership details at developer.apple.com.
3. GitHub → repository Settings → Environments → **apple-delivery** → add these environment secrets:

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | 10-character Team ID |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | Entire `.p8` file contents including the BEGIN/END lines (not Base64) |

Never paste these into chat, issues, commits or logs. Revoke the key in App Store Connect if it is ever exposed.

4. Run **Actions → Apple delivery → Run workflow** on `main` with a version (2.0.0), a new build number, and the confirmation box ticked. It runs the core tests, archives the Release build, signs it and uploads it to App Store Connect, where it appears under TestFlight after processing.

## 4. Listing

- Category: Music. Secondary: Education.
- Age rating: 4+.
- App Privacy: **Data Not Collected** matches this version (pitch analysis and history stay on the device, no analytics SDK, no ads). Revisit if analytics or a paywall service is added.
- Encryption: the app uses only Apple's standard encryption (`ITSAppUsesNonExemptEncryption = false`).
- Screenshots: the CI tour produces 6.9" iPhone and 13" iPad captures (`ci-results/app`, `ci-results/ipad`) as a starting point.
- Subscription disclosures are on the paywall (price, period, auto-renewal, cancel in Settings, Terms and Privacy links), as App Review Guideline 3.1.2 requires.
