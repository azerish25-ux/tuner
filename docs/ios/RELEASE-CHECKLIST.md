# Timbre for iOS: release checklist, from today to Ready for Distribution

This is the step-by-step path from the repository as it stands on **25 October 2026** (`v2/foundations` at `0bbf273`) to Timbre 2.0.0 live on the App Store. Work through it in order and tick each box. Each step says:

- **Who** does it: the **owner** (the Apple Developer Program Account Holder), or the **developer** (whoever maintains the repository);
- **Where** it happens: an App Store Connect screen, a GitHub setting, or a repository command;
- **Enter**: the exact values to type;
- **Verify**: how you know it worked.

App Store Connect now calls the final state **Ready for Distribution**; older guides call it "Ready for Sale".

The long reference tables stay where they already are, and this checklist links to them:

- [APPLE-DELIVERY.md](APPLE-DELIVERY.md): identifiers, signing, Game Center, Apple Watch, MusicKit and the growth programme.
- [APP-STORE-LISTING.md](APP-STORE-LISTING.md): the English store text, age rating answers, screenshots, Custom Product Pages and review notes.
- [APP-STORE-LISTING-LOCALIZED.md](APP-STORE-LISTING-LOCALIZED.md): the localized store text.
- [PRIVACY.md](PRIVACY.md): the privacy policy.
- [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md): the audio device test sheet.
- [../l10n/HANDOFF.md](../l10n/HANDOFF.md): the translation handoff.
- [../OWNER-ACTIONS.md](../OWNER-ACTIONS.md): everything only the owner can do, beyond this release.

## Rules that hold for every step

1. **Nobody dispatches the Apple delivery workflow without the owner.** It signs and uploads to App Store Connect. Only the owner starts it, or explicitly approves a run someone else started (step C3 makes GitHub enforce this). Automated agents never dispatch it.
2. **Never submit a build made with `internal_testflight_untranslated`.** That build is stamped `TimbreBuildChannel = internal` and exported for internal TestFlight only. App Store Connect refuses it for review and external testing. Use it only to try a build on devices.
3. **Never paste the `.p8` key, the Key ID, the Issuer ID or the Team ID** into chat, issues, commits or logs. Revoke the key at once if it leaks.
4. **Never put on the store page, or set up in App Store Connect, a monthly introductory offer, a VoiceOver accessibility claim, a hand-typed rating, or a feature the build doesn't have** (Game Center when it's off, Apple Music without MusicKit). App Review checks claims (Guideline 2.3).
5. **Build numbers only go up.** App Store Connect refuses a build number it has already seen for a version.

## Where things stand today (verified 25 October 2026)

| Area | State | What it means for release |
|---|---|---|
| Apple portals | Nothing exists yet: no App Store Connect record, no products, no API key ([APPLE-DELIVERY.md](APPLE-DELIVERY.md) intro) | Phases A and D are the critical path |
| `main` | 302 commits behind `v2/foundations`. PR #2 (`v2/foundations` → `main`) is open with 0 reviews. `main` is not protected | Phase C. Delivery runs from `main`. |
| CI on the release candidate | On `0bbf273` the required **`gate` is green** (core, app, release). The **`accessibility` job is red**: the enforced contrast audit fails on elements of the tuner (string chips, "Reference"), the metronome, the paywall, a lesson and the welcome screen | Step E1 needs a green `gate` on the commit you ship; fix or sign off the contrast failures before declaring Sufficient Contrast (H7) |
| Store captures | The nightly tour on `62a7508` failed 4 tests, including the captures for store frame #2 (`65-song-perform`) and the violin page's #2 (`65b-song-perform-violin`). On `0bbf273` the iPad job passed and the tour was still running at the time of writing | Step H1 needs a green nightly tour on the release commit |
| App Preview | No cut passes the current gates: the runs on `d031914` and `0bbf273` failed, and the last published cut (`e74c390`) predates the gates | Optional for 2.0.0 (step H2) |
| Translations | Every one of the 48 non-English locales is at 67.7 % of the interface, with 106 legal, permission and VoiceOver strings missing (`tools/l10n/shipping.py`) | The delivery gate refuses a review build with any of them. Ship English only for now (step E2), or wait for translators. |
| Hosted privacy policy | `https://azerish25-ux.github.io/tuner/privacy.html` (the `gh-pages` branch) is dated 23 October 2026 and says analytics stay on the device | It must be republished from [PRIVACY.md](PRIVACY.md) before a build with analytics goes to review (step B2) |
| Support page | None exists | The Support URL is a required field (step B3) |
| Device tests | [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md): "Not yet run on a device" | Phase F |
| Code readiness for the store | Done: the products `_b` and `_c` load and grant Pro; the paywall discloses a monthly trial if one ever exists; Pro survives the Billing Grace Period (`AccessPolicy.isPro` trusts `Transaction.currentEntitlements`) and the billing-issue banner shows; the Family Sharing line shows by itself; `freeSongs` and `flags.unit2Free` work | No code is needed before the products go on sale |

## Target dates

The carol In-App Event (December 1–31) can only be submitted with the first app version, and must be approved before it can be published 14 days ahead. That sets the calendar.

| By | Milestone |
|---|---|
| Wed 28 Oct | Phase 0 decisions made. Phases A–C done: accounts, app record, API key, GitHub settings, `main` merged and protected. |
| Tue 3 Nov | First internal TestFlight build (Phase E) |
| Fri 6 Nov | Device sheet signed off (Phase F). External TestFlight cohort started (Phase G). Store page filled (Phase H). |
| **Tue 10 Nov** | **2.0.0 submitted** with its three products and the Holiday Carols event (Phase I) |
| Tue 17 Nov | The event's earliest publish date (14 days before 1 December) |
| 17–24 Nov | Manual release (Phase J), before the carol shelf opens in the app on 25 November and before US Thanksgiving (26 November) |
| 1–7 Dec | Carols free through the remote settings (step K4) |

---

## Phase 0: decisions (owner, today)

Make these first; later steps depend on them. The recommendations come from the October 2026 review panel and the existing docs.

| # | Decision | Recommendation | Lands in |
|---|---|---|---|
| 0.1 | Version string | **2.0.0**, build numbers from **1** up. This is the delivery workflow's default, and the panel's "v2.0". `ios/project.yml`'s `1.0.0` is overridden by the workflow. | E2, H5 |
| 0.2 | Languages in 2.0.0 | **English only** (`ship_min_coverage: 95`, which today keeps English alone). Add each locale in a 2.0.x update once its translations pass the gate. The panel's target set is `en` plus de, es, fr, it, ja, ko, pt, ru and zh-CN. Arabic and Hebrew wait for native RTL review. | E2, K5 |
| 0.3 | Prices | Yearly **$49.99** with a **14-day** free trial. Monthly **$9.99** with **no** introductory offer. Lifetime **$149.99**, kept off the onboarding paywall. `timbre_pro_annual_b` at **$59.99** for a later price test. | D2, K3 |
| 0.4 | Family Sharing | **On** for the yearly plans and lifetime; off for monthly. It can't be turned off again. | D3 |
| 0.5 | Analytics at launch | **On** (TelemetryDeck). Without it there is no funnel, no price test and no revenue per install. The App Privacy label changes with it (H6). | B4, C4, H6 |
| 0.6 | Game Center in 2.0.0 | **Off for 2.0.0**, unless the 31 achievement images (1024 × 1024) and the challenge and activity art (3840 × 2160) are ready by 3 November. Turn it on in 2.1. Off means: delete the Game Center bullet from the description, and answer Contests "None" in the age rating. | C5, H4, H5 |
| 0.7 | Where it's sold | Every storefront **except China mainland**, which needs an ICP filing number. **Not** on Apple silicon Macs or Apple Vision Pro: untested there. | H8 |
| 0.8 | Release method | **Manually release this version** for 2.0.0. Use phased release from 2.0.1 on. | H12, J1 |
| 0.9 | A domain | One domain for the privacy policy, support page and remote settings file. GitHub Pages with a custom domain is enough. | B1 |
| 0.10 | Repository visibility | The repository is **public** today: anyone can read the source and the store strategy. Making it private protects the work. It also ends free macOS Actions minutes (the gate uses 60–90 runner-minutes per push) and needs a paid plan for Pages. Decide before launch. | [OWNER-ACTIONS.md](../OWNER-ACTIONS.md) |

---

## Phase A: Apple accounts and identifiers (owner)

### A1. Apple Developer Program
- [ ] **Who:** owner. **Where:** developer.apple.com → Account → Membership details.
- **Enter:** an active membership ($99 a year) with you as Account Holder. Note the 10-character **Team ID**.
- **Verify:** Membership details shows the status Active and the Team ID.

### A2. Agreements, tax and banking
- [ ] **Who:** owner. **Where:** App Store Connect → Business.
- **Enter:** accept the **Paid Apps Agreement** (it is Schedule 2 of the Program License Agreement). Complete the tax forms (U.S. W-9, or W-8BEN outside the U.S.) and add the bank account.
- **Verify:** the Paid Apps Agreement shows **Active**. Subscriptions can't go on sale until it does, and banking checks can take days, so do this first.

### A3. EU trader status (Digital Services Act)
- [ ] **Who:** owner. **Where:** App Store Connect → Business → the Digital Services Act section.
- **Enter:** whether you are a trader. Selling subscriptions usually makes you one. A trader's address, phone number and email appear on the EU product page, so use a business address and phone if you don't want home details public.
- **Verify:** the status reads verified. Without a trader status, the app is withheld from the EU storefronts, and a trader can't submit until the details are entered.

### A4. App Store Small Business Program
- [ ] **Who:** owner (it needs the Account Holder). **Where:** developer.apple.com/app-store/small-business-program → Enroll.
- **Enter:** list any associated developer accounts (none, presumably).
- **Verify:** you receive the approval email. The commission falls from 30 % to 15 % starting 15 days after the end of the fiscal month in which enrollment is approved, so enroll now.

### A5. Identifiers and capabilities
- [ ] **Who:** owner (the developer can do it with an Admin role). **Where:** developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.

The delivery workflow's automatic signing registers the bundle IDs and the App Group on its first run, but only with an **Admin** API key (A7). MusicKit is never automatic. Check each row:

| Identifier | Capabilities to tick | Notes |
|---|---|---|
| `com.shahradazerisharghi.timbre` (app) | **App Groups** → `group.com.shahradazerisharghi.timbre`; **In-App Purchase** (on by default); **Game Center** (on by default for explicit IDs); App Services tab → **MusicKit** | MusicKit powers "Listen on Apple Music", which the description advertises. Without it the card says "Apple Music isn't available". |
| `com.shahradazerisharghi.timbre.widgets` | **App Groups** → the same group | |
| `com.shahradazerisharghi.timbre.watchkitapp` | **App Groups** → the same group | Embedded in the iPhone app ([APPLE-DELIVERY.md §7.1](APPLE-DELIVERY.md#71-signing-the-two-new-bundle-ids)) |
| `com.shahradazerisharghi.timbre.watchkitapp.widgets` | **App Groups** → the same group | |
| App Group `group.com.shahradazerisharghi.timbre` | — | Widgets and complications read the streak from it |

**Not needed, so don't add them:**
- **iCloud**: nothing syncs; that needs a code change first.
- **Push Notifications**: reminders are local, and the Live Activity updates locally.
- **Associated Domains**: needed only if the share page becomes a universal link later.
- **Siri**: App Shortcuts need no entitlement.
- **Sign in with Apple**: the app has no accounts.

- **Verify:** each identifier shows the ticks above. After E2's first run, the four IDs exist and their profiles are "Active".

### A6. The App Store Connect app record
- [ ] **Who:** owner. **Where:** App Store Connect → Apps → **+** → New App.
- **Enter:**

| Field | Value |
|---|---|
| Platform | iOS |
| Name | `Timbre: Guitar Tuner & Lessons` (30/30; the name must be unique on the store, so if it's taken, try a variant and keep the subtitle) |
| Primary language | English (U.S.) |
| Bundle ID | `com.shahradazerisharghi.timbre` |
| SKU | `timbre-ios` (anything unique; never shown) |
| User access | Full access |

  If App Store Connect already has an app for this bundle ID (an earlier Timbre), don't create a second one: add version 2.0.0 to it.
- **Verify:** the app opens on "iOS App 1.0 Prepare for Submission" (change the version to 2.0.0 in H5). Under App Information → General, note the **Apple ID** (digits only). It becomes `TIMBRE_APP_STORE_ID` in C4.

### A7. App Store Connect API key for signing and upload
- [ ] **Who:** owner. **Where:** App Store Connect → Users and Access → Integrations → App Store Connect API → **Team Keys** → **+**.
- **Enter:** name `GitHub delivery`, role **Admin**. Automatic signing must be able to create the distribution certificate, identifiers and profiles, which narrower roles can't. Download the `.p8` (you can download it only once) and note the **Key ID** and the **Issuer ID**.
- **Verify:** the key is listed as Active. Store the `.p8` in a password manager; it goes into GitHub in C3 and nowhere else.

### A8. People in App Store Connect
- [ ] **Who:** owner. **Where:** Users and Access → **+**.
- **Enter:**
  - the developer (role App Manager, or Developer plus Marketing);
  - every internal tester (internal TestFlight testers must be App Store Connect users, up to 100).
- **Verify:** each person accepts the invitation.

### A9. Sandbox test accounts
- [ ] **Who:** owner or developer. **Where:** Users and Access → Sandbox → Test Accounts → **+**.
- **Enter:** two U.S. accounts and one in an EU storefront (Germany, say), each with an email address nobody uses for a real Apple Account.
- **Verify:** sign one in on a device (Settings → Developer → Sandbox Apple Account, with Developer Mode on) and see the account listed. These accounts test billing retry and the grace period in F3.

---

## Phase B: web pages and services (owner; the developer can help)

### B1. Domain and hosting
- [ ] **Who:** owner. **Where:** your registrar, plus GitHub → repository Settings → Pages (custom domain) or any static host with https.
- **Enter:** the domain (written `<domain>` below). With GitHub Pages: the custom domain, then **Enforce HTTPS**.
- **Verify:** `curl -sI https://<domain>/` returns `200` over https.

### B2. Privacy policy
- [ ] **Who:** owner publishes; the developer converts [PRIVACY.md](PRIVACY.md) to HTML (the existing `gh-pages` `privacy.html` is the template).
- **Where:** `https://<domain>/privacy` (or `/timbre/privacy.html`).
- **Enter:** the full text of [PRIVACY.md](PRIVACY.md) as it stands at release, with its date. It must describe what the build does:
  - anonymous TelemetryDeck events, the Settings switch and "Request a song";
  - MetricKit summaries and Apple Ads attribution;
  - the remote settings file and the App Store rating lookup;
  - Game Center, if it's on.
- Also update `https://azerish25-ux.github.io/tuner/privacy.html`, or make it redirect, because earlier builds and TestFlight builds link there.
- **Verify:** both addresses show the 25 October 2026 text (or later), including the "Anonymous usage analytics" section.

### B3. Support page (required)
- [ ] **Who:** owner. **Where:** `https://<domain>/support`.
- **Enter:**
  - a contact email (the one in PRIVACY.md works);
  - how to restore purchases (Tune tab → Settings → Restore purchases);
  - how to manage or cancel (iPhone Settings → Apple Account → Subscriptions);
  - how to allow the microphone (iPhone Settings → Timbre → Microphone);
  - a link to the privacy policy;
  - optionally, a short accessibility section, which can serve as the Accessibility URL (H7).
- **Verify:** the page loads over https. App Store Connect won't submit a version without a Support URL.

### B4. TelemetryDeck (analytics)
- [ ] **Who:** owner. **Where:** telemetrydeck.com → create an organization → **Create App** "Timbre iOS".
- **Enter:** nothing in the app. Copy the app's **App ID** (a UUID) for C4.
- **Verify:** after the first TestFlight build (E3), the app's recent signals show `app_open`, `onboarding_step` and `paywall_view`. Turning off Settings → "Share anonymous usage data" stops them.
- **Note:** TestFlight builds send production signals: the build marks only Debug builds as test mode. Compare launch numbers by app version, or ask the developer to mark TestFlight signals as test mode.

### B5. Remote settings file
- [ ] **Who:** owner hosts it; the developer reviews each change.
- **Where:** `https://<domain>/timbre/config.json`, served over https with `Content-Type: application/json`.
- **Enter (launch content):**

```json
{
  "paywall": [{ "id": "control" }],
  "rating": { "show": true },
  "freeSongs": [],
  "flags": {}
}
```

  Add `"referralCode"` only once the offer code exists (K3), and the carols only for their week (K4). Every key is explained in [APPLE-DELIVERY.md §5](APPLE-DELIVERY.md#5-analytics-links-and-remote-settings).
- **Verify:** `curl -s https://<domain>/timbre/config.json | python3 -m json.tool` prints the file. In a TestFlight build, a test arm you add shows up in the `paywall_view` event's `variant`.

### B6. Share page (optional for 2.0.0)
- [ ] **Who:** owner. **Where:** `https://<domain>/timbre/` (`TIMBRE_SHARE_URL`).
- **Enter:** a small https page that forwards `…/lesson?id=x` to `timbre://lesson?id=x` and falls back to the App Store page ([APPLE-DELIVERY.md §6.2](APPLE-DELIVERY.md#62-beat-my-score-challenge-links)).
- **Verify:** without it, shares link to the App Store page, which is fine for launch.

### B7. App Store Server Notifications (optional; skip for 2.0.0)
- [ ] **Who:** owner, once a server exists. **Where:** App Store Connect → the app → App Information → App Store Server Notifications.
- **Enter:** Version 2 URLs for Production and Sandbox. The repository has no server. Until one exists, the app itself logs renewals, refunds and the auto-renew state (`subscription_state`, `renewal`, `refund`) to TelemetryDeck.
- **Verify:** n/a for 2.0.0.

---

## Phase C: GitHub (owner; the developer prepares the pull requests)

### C1. A green gate, a human review, then merge `v2/foundations` into `main`
- [ ] **Who:**
  - the developer gets the iOS workflow green on PR #2's head;
  - an independent reviewer and the owner review;
  - the owner merges.
- **Where:** github.com/azerish25-ux/tuner/pull/2.
- **Enter:** merge only when the PR's **`gate`** check is green. Also make sure the `accessibility` job and the nightly (label the PR `captures`) are green, or that each failure is understood and written down. A merge commit keeps the 302 commits that the docs and notes refer to by hash; squash-merge later pull requests.
- **Verify:** `main` contains `.github/workflows/preview.yml` and `ios/TimbreWatch/`. A push to `main` starts the iOS workflow, which reports `gate`.

### C2. Make `gate` required on `main`
- [ ] **Who:** owner (repository admin). **Where:** GitHub → repository Settings → Rules → Rulesets → **New branch ruleset** (or Settings → Branches → Add branch protection rule).
- **Enter:**
  - Target: `main` only. Don't target `ci-results/*`: the workflows push results there.
  - **Require a pull request before merging**, with 1 approval.
  - **Require status checks to pass**, adding `gate` (it appears once it has reported in the last week). Optionally add `accessibility`.
  - **Block force pushes**; restrict deletions.
- **Verify:** on a new pull request, `gate` shows as **Required**, and the merge button stays disabled until it passes.

### C3. The `apple-delivery` environment, its secrets and its approval rule
- [ ] **Who:** owner. **Where:** GitHub → Settings → Environments → **apple-delivery** (create it if it's missing).
- **Enter:**

| Setting | Value |
|---|---|
| Required reviewers | **the owner's GitHub account**. Every delivery run then waits for the owner's approval, whoever dispatched it. |
| Deployment branches and tags | Selected branches: `main` |
| Secret `APPLE_TEAM_ID` | the Team ID from A1 (10 characters) |
| Secret `APP_STORE_CONNECT_KEY_ID` | the Key ID from A7 |
| Secret `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID from A7 (a UUID) |
| Secret `APP_STORE_CONNECT_API_KEY_P8` | the whole `.p8` file, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines, as text (not Base64) |

- **Verify:** the environment lists four secrets and one required reviewer. The workflow's first step checks each value's format without printing it, and fails with "Missing apple-delivery environment secrets" or "Invalid format for …" when one is wrong.

### C4. Repository variables (the addresses the build carries)
- [ ] **Who:** owner. **Where:** GitHub → Settings → Secrets and variables → Actions → **Variables** → New repository variable.
- **Enter:**

| Variable | Value | Info.plist key the app reads |
|---|---|---|
| `TELEMETRYDECK_APP_ID` | the App ID from B4 | `TimbreTelemetryAppID` |
| `TIMBRE_APP_STORE_ID` | the Apple ID from A6 (digits only) | `TimbreAppStoreID` |
| `TIMBRE_REMOTE_CONFIG_URL` | `https://<domain>/timbre/config.json` | `TimbreRemoteConfigURL` |
| `TIMBRE_SHARE_URL` | `https://<domain>/timbre` (optional) | `TimbreShareURL` |

  The delivery workflow passes each one into the archive. When a variable is unset, the build keeps the project's empty value and the app falls back (`AppLinks` in `ios/Timbre/Services/ShareDestination.swift`). Only https addresses count.
- **Verify:** in a TestFlight build, a share's message ends with `https://apps.apple.com/app/id<digits>`, and B4's signals arrive.

### C5. Code changes that need the owner's values (developer)
- [ ] **Who:** developer, as a pull request through `gate`.
- **Where:** `ios/project.yml`, and `ios/Timbre/Services/ShareDestination.swift`.
- **Enter:**
  - `TIMBRE_PRIVACY_POLICY_URL: "https://<domain>/privacy"` under `targets → Timbre → settings → base`. It feeds `TimbrePrivacyURL` and `TimbrePrivacyPolicyURL`, which the paywall and Settings link to. Also change the `publishedPrivacy` fallback in `ShareDestination.swift` to the same address.
  - **Only if Game Center ships in 2.0.0** (decision 0.6): `com.apple.developer.game-center: true` under the Timbre target's entitlements, and the `NSGKFriendListUsageDescription` line from [APPLE-DELIVERY.md §6.1](APPLE-DELIVERY.md#61-game-center).
  - Verify the final archive's privacy report against H6. The source manifest now declares all seven listed types, including Device ID, Purchase History and Other User Content; source presence does not replace archive or portal verification.
- **Verify:** `gate` is green on the PR. In the TestFlight build, the paywall's Privacy link opens the new address.

---

## Phase D: products in App Store Connect (owner)

### D1. The subscription group
- [ ] **Who:** owner. **Where:** the app → Monetization → **Subscriptions** → Subscription Groups → **+**.
- **Enter:** reference name `Timbre Pro`. Under App Store Localization → English (U.S.), set the subscription group display name to `Timbre Pro`.
- **Verify:** the group shows the localization as "Prepare for Submission" or ready.

### D2. The products (exact identifiers; the app looks these up)

- [ ] **Who:** owner. **Where:** the subscriptions inside the **Timbre Pro** group (**+** under it), and the lifetime product under Monetization → **In-App Purchases** → **+** (Non-Consumable).

Every product needs a reference name, its product ID, its price, an English (U.S.) display name and description, a **review screenshot** and review notes:
- **Review screenshot:** the paywall, taken on the TestFlight build so it shows App Store Connect's prices, not the test file's.
- **Review notes:** "Reached from Tune → Settings → Try Timbre Pro, any locked lesson, or Practice → Tools → Drone."

| Product ID | Type | Level / duration | U.S. price | Introductory offer | Family Sharing | Display name | Description (55 max) |
|---|---|---|---|---|---|---|---|
| `timbre_pro_annual` | Auto-renewable | Level 1, **1 year** | **$49.99** | **Free trial, 2 weeks**, new subscribers, all storefronts, no end date | **On** | Timbre Pro, yearly | Every lesson, song, tuning and practice tool |
| `timbre_pro_monthly` | Auto-renewable | Level 1, **1 month** | **$9.99** | **None** | Off | Timbre Pro, monthly | Every lesson, song, tuning and practice tool |
| `timbre_plus_lifetime` | Non-consumable | — | **$149.99** | — | **On** | Timbre Pro, lifetime | Everything in Pro, paid once |

- The two subscriptions sit **at the same level** in the group, as [APPLE-DELIVERY.md §2](APPLE-DELIVERY.md#2-in-app-purchases-exact-identifiers--the-app-looks-these-up) specifies. (The test file `ios/Tests/Fixtures/Timbre.storekit` gives them different levels and older prices; it is test data only.)
- **Keep the 14-day trial.** Yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 days (RevenueCat 2026, as cited by the panel).
- **No monthly introductory offer.** The build would disclose one correctly now ("Free for 7 days, then $9.99 a month."). The recommendation is still none, with win-back offers and offer codes (K3) doing that job.
- **Lifetime stays off onboarding's paywall** by default. The remote settings can show it on one test arm (`onboardingLifetime`).
- Leave the price as the U.S. base price, and let App Store Connect set the other storefronts' equivalents.

- **Verify:** each product shows **Ready to Submit**. The first subscriptions and in-app purchases can only be submitted with an app version, which happens in I2.

### D3. Family Sharing
- [ ] **Who:** owner. **Where:** each product (`timbre_pro_annual`, `timbre_plus_lifetime`) → **Family Sharing** → Turn On → confirm.
- **Enter:** nothing else. It **can't be turned off again** for a product.
- **Verify:** on the TestFlight paywall, the yearly and lifetime cards show the Family Sharing line (StoreKit's `isFamilyShareable`). The monthly card doesn't.

### D4. Billing Grace Period, sandbox first
- [ ] **Who:** owner. **Where:** the app → Subscriptions → **Billing Grace Period** → Set Up Billing Grace Period.
- **Enter:** **16 days**, **All Renewals**, server environments **Only Sandbox** for now. Switch to **Production and Sandbox** in I3, after F3 passes.
- **Verify:** the section shows 16 days and Sandbox. Changes take up to 24 hours to apply.

### D5. Price-test products (create now, submit after launch)
- [ ] **Who:** owner. **Where:** the **Timbre Pro** group → **+**.
- **Enter:**
  - `timbre_pro_annual_b`: 1 year, the same level as `timbre_pro_annual`, **$59.99**, the same 2-week free trial, Family Sharing on, the same display name and description.
  - `timbre_pro_annual_c`: create it only when a third arm is planned. The panel recommends only the $49.99 against $59.99 test.
- **Don't add them to the 2.0.0 submission.** A product App Review can't find in the build risks a rejection, and the test needs baseline data first. Submit `_b` after launch (K3) with a note that the remote settings show it to half of new paywall viewers.
- **Verify:** the app already loads both IDs, and grants Pro for them. Until one is approved and on sale in a storefront, an arm naming it keeps selling `timbre_pro_annual`.

---

## Phase E: the first build to TestFlight (developer prepares, owner authorizes)

### E1. Pre-flight on `main`
- [ ] **Who:** developer. **Where:** GitHub Actions and a local checkout of `main`.
- **Check:**
  - the latest **iOS** run on `main`'s HEAD is green on `gate` (core, app, release), and `accessibility` is green or its failures are explained;
  - the **Nightly and captures** run on that commit is green on `tour` and `ipad`. If it hasn't run, start it: Actions → Nightly and captures → Run workflow → `main`;
  - locally:

```sh
python3 tools/l10n/shipping.py --min 95             # "Would ship en + 0 locales" today
python3 tools/l10n/shipping.py --min 95 --critical  # the same set, also requiring every legal/permission/VoiceOver string
python3 tools/marketing/screenshots.py --check      # listing counts and limits: "10 listing locales checked: all pass"
python3 tools/verify-ios-resources.py
```

- **Verify:** the developer posts the run links and the commit hash to the owner. That commit is the one to deliver.

### E2. Dispatch the Apple delivery workflow (the owner's call)
- [ ] **Who:** owner (or the developer, with the owner approving the environment deployment). **Where:** GitHub → Actions → **Apple delivery** → Run workflow.
- **Enter:**

| Input | Value |
|---|---|
| Use workflow from | `main` |
| marketing_version | `2.0.0` |
| build_number | `1` (then 2, 3, … for each later upload) |
| confirm_delivery | ticked |
| internal_testflight_untranslated | **not ticked** (step E2 builds what will be reviewed) |
| ship_min_coverage | `95` (English only today; a locale joins automatically once it reaches 95 % and has no critical gap) |

  Then approve the pending deployment to `apple-delivery` (C3).
- **Verify:** the run's summary shows "Languages in this build" with only `en`, the critical-strings step prints `OK`, and the summary ends "Upload accepted". If the gate step fails, a shipped locale lacks a critical string. Raise `ship_min_coverage`, or deliver the translations, and run again with a new build number.

**About `internal_testflight_untranslated`:** tick it only for a quick device build that keeps every language, while translations are still coming. That build reaches internal testers only, and can never be submitted. Use the same settings as the release (`ship_min_coverage: 95`) when you want to test what you'll ship.

### E3. Process the build and give it to internal testers
- [ ] **Who:** owner. **Where:** App Store Connect → the app → **TestFlight**.
- **Enter:**
  - wait for the build to finish processing (usually 15–60 minutes; Apple emails when it's done);
  - make an internal group ("Team"), add the A8 testers, add build 1;
  - export compliance is answered by the build (`ITSAppUsesNonExemptEncryption = false`), so no "Missing Compliance" prompt should appear.
- **Verify:**
  - the build shows "Ready to Test";
  - testers receive it in the TestFlight app, and the watch app arrives with it;
  - TelemetryDeck receives `app_open` (B4).

---

## Phase F: the device test sheet (owner and developer, on the TestFlight build)

The simulator has no microphone bleed, no silent switch, no calls, no haptics and no AirPods. Run this sheet on real hardware before every release that touches audio, and record every run (date, device and iOS version, build, pass or fail, what was heard) in the Results table of [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md). **A fail blocks the release until it is fixed or the owner signs it off in writing.**

**Devices:** at least one older iPhone (an SE or 12/13), one current Pro, one iPad, AirPods (or other Bluetooth headphones), a wired headset, an Apple Watch and a CarPlay car or car Bluetooth if you have one.

### F1. Audio cases 1–12
- [ ] Every case in [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md):
  1. a podcast at first launch;
  2. the silent switch after tuning;
  3. the speaker band;
  4. the speaker band on strummed steps;
  5. chords that change mid-bar;
  6. AirPods in and out mid-lesson;
  7. a call during the drone;
  8. Siri during the tuner;
  9. CarPlay;
  10. spoken cues at 60 BPM;
  11. the tuner's battery use;
  12. background and back.

  Run each on the built-in speaker, and run the route cases with AirPods and with a wired headset.

### F2. Microphone start, stall and feel checks (added by the latest audio and QA work)

These aren't in AUDIO-DEVICE-TESTS.md yet; record them in its Results table as cases 13–20.

| # | Case | Steps | Expected |
|---|---|---|---|
| 13 | Cold launch onto the tuner | Force-quit Timbre, open it on the Tune tab. Repeat 10 times, on the oldest phone too. | The tuner listens every time, without the microphone error alert. A start that needs it gets one quiet retry, which the user doesn't see. |
| 14 | Restart within a second | Leave the tuner (another tab) and come back within 1 s; repeat quickly 5 times. | It listens again each time; a start that was called off never stops the newer one. |
| 15 | Drone and microphone | Start the drone (Practice → Tools → Drone, Pro) and then the tuner, and the other way round. | Both sound and listen as designed; no stall, no silence. |
| 16 | AirPods in and out while the tuner listens | Connect and disconnect AirPods with the tuner open. | One short gap each time; it keeps listening. |
| 17 | A call's alert | Have someone call while the tuner listens and while a lesson plays. Decline, then accept and hang up. | The tuner and the lesson come back by themselves after the call. |
| 18 | Microphone denied | Delete and reinstall. At the onboarding prompt, choose Don't Allow; later allow it in iPhone Settings → Timbre → Microphone. | The app explains how to allow it and doesn't crash or hang. Once allowed, the tuner listens without a reinstall. |
| 19 | Perform to first click | Songs → a song → Perform. Time from the tap to the first click, five times, including on the oldest phone. | The click starts promptly, and the take's clock starts after it. **Any freeze over 300 ms is a bug** (the screen or the HUD stops moving). |
| 20 | Haptic bleed with Tune by feel | Turn Tune by feel on (the tuner's control, or Settings). Tune a string with the microphone open, on iPhone 15, 16 and 17 if you can. | The pulse is felt, slows as the string nears the note, and is still at the lock. The haptics don't move the reading or stop the lock. |

### F3. Purchases, restore and grace (TestFlight purchases are free)
- [ ] **Paywall:**
  - Tune → Settings → **Try Timbre Pro**: the yearly card shows "$49.99" (App Store Connect's price, not the test file's) and "14-day free trial", the trial timeline, renewal terms, Restore, Terms and Privacy;
  - the monthly card shows $9.99 with no trial;
  - the yearly and lifetime cards show the Family Sharing line.
- [ ] **Buy yearly:**
  - Pro unlocks at once (lessons past unit 1, every tuning, the drone);
  - with notifications allowed, a trial reminder is scheduled for two days before the trial ends;
  - TelemetryDeck shows `purchase` with `trial=1`.
- [ ] **On a second device with the same account:** Restore purchases unlocks Pro. Test lifetime the same way.
- [ ] **Turn down a paywall twice:** the second time, the exit offer stays hidden. No win-back offers or codes exist yet.
- [ ] **Billing retry and grace** (a Sandbox Apple Account from A9 on a development build, or the developer's StoreKit test setup):
  - make a renewal fail: the **billing-issue banner** appears;
  - with grace on (D4, Sandbox), Pro stays until the grace period ends; without grace, it pauses.
  - See [APPLE-DELIVERY.md §9.1](APPLE-DELIVERY.md#91-billing-grace-period-and-family-sharing).
- [ ] **Cancel the subscription** in Settings → Apple Account → Subscriptions, and let it lapse: Pro goes away once the (accelerated) period ends.

### F4. The rest of the app on hardware
- [ ] **Apple Watch:** every step of [APPLE-DELIVERY.md §7.3](APPLE-DELIVERY.md#73-check-on-a-real-watch-testflight): install, feel at 60/120/200/240 BPM, wrist down, sync, Start today's practice, midnight.
- [ ] **Your songs and Apple Music:** every step of [APPLE-DELIVERY.md §8.5](APPLE-DELIVERY.md#85-check-on-a-device-testflight). The free chart limit is **10** (`YourSongsPolicy.freeChartLimit`). Test the 11th.
- [ ] **Game Center**, only if decision 0.6 turned it on: [APPLE-DELIVERY.md §6.1 step 9](APPLE-DELIVERY.md#61-game-center).
- [ ] **Widgets, Live Activity, Siri:**
  - add the Home Screen and Lock Screen widgets: the streak shows;
  - start the metronome and lock the phone: the Live Activity shows;
  - "Hey Siri, tune my guitar in Timbre" (or any listed shortcut) opens the tuner.
- [ ] **iPad:** onboarding, the tuner in both orientations, a lesson and the paywall, in Split View too.
- [ ] **VoiceOver smoke test:** the tuner and the paywall work with VoiceOver. Don't claim VoiceOver anywhere yet (H7).

### F5. Analytics and remote settings
- [ ] Within a minute or so of use, TelemetryDeck shows the funnel events. Settings → "Share anonymous usage data" off stops them.
- [ ] Add a test arm to B5's file: `"paywall": [{ "id": "control" }, { "id": "plan", "headline": "plan" }]`. About half of fresh installs then see "Unlock your full plan" on onboarding's paywall, and `paywall_view` carries `variant=plan`. Remove the arm afterwards.

**Verify the phase:** the Results table in AUDIO-DEVICE-TESTS.md has a row for each device and case, committed by the developer, with no unresolved fail.

---

## Phase G: external TestFlight (owner)

### G1. Test information
- [ ] **Where:** TestFlight → Test Information (English (U.S.)).
- **Enter:**
  - **Beta App Description:** "Timbre is a free tuner for 60 instruments, with lessons and songs that listen as you play."
  - **Feedback email:** the support address.
  - **What to Test:** "Tune your instrument, finish the first unit of a course, play a song, and try Timbre Pro (purchases are free in TestFlight). Tell us about anything that sounded wrong, stalled or confused you."
  - **Privacy Policy URL:** B2.
  - The review contact details.

### G2. Groups and testers
- [ ] **Where:** TestFlight → External Testing → **+** → group "Cohort 1".
- **Enter:**
  - the panel's cohort, 200–500 players, through a **public link** with a tester limit;
  - 2–3 music teachers (ukulele, violin);
  - paid blind and low-vision testers (AppleVis or Fable);
  - left-handed players.
- **Verify:** the first build in the group goes to **Beta App Review**, usually within a day or two. Testers can install once it's approved. Builds expire after 90 days.

### G3. Feedback window
- [ ] Give the cohort at least 3–5 days before submitting (or overlap with Phase H).
- Triage TestFlight feedback and crash reports (TestFlight → Feedback, Xcode → Organizer → Crashes).
- Every fix is a new build: E2 with the next build number, and the device cases it touches run again.

---

## Phase H: the store page (owner, with the developer for assets)

### H1. Screenshots: medium Dynamic Island iPhone and iPad 13" (from CI)
- [ ] **Who:** developer renders; owner approves and uploads.
- **Where:** run **Localized listing assets** (`listing-assets.yml`) on the verified release revision of `main`, with `locales=all` and `scope=screenshots`. It captures the exact required devices from one unsigned simulator build and retains per-locale captures, composed frames, source/build hashes and manifests. Nightly tour images remain QA evidence; its first available iPhone is not a guarantee of the required display size.
- **Check before upload:** the workflow must finish successfully, its aggregate inventory must cover all 50 listing locales and both screenshot kinds, and its source SHA must match the release candidate. Review every actual frame; mechanical verification leaves `visual_review` pending and `release_ready=false`. Use the `rendered/` assets and manifests from that run, preserving locale and frame order. The standalone renderer also rejects source images whose native dimensions do not match its output device.

  The renderer reads the frame tables in [APP-STORE-LISTING.md](APP-STORE-LISTING.md#screenshots-medium-dynamic-island-iphone-and-13-ipad): 9 iPhone frames at 1206 × 2622, and 4 iPad frames at 2752 × 2064. It refuses a capture its test marked `-wrong`, and exits non-zero when a frame is missing. The listing pipeline also verifies native capture dimensions before composing; old large-phone captures cannot replace the required medium set.
- **Upload:** App Store Connect → the version → Previews and Screenshots → **iPhone with Dynamic Island (medium display)** (the 9 frames, in order) and **iPad 13"** (the 4 frames). Check these slots against [Apple's current requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) before submission.
- **Verify:**
  - look at each locale's `iphone-<locale>-sheet.png` and `ipad-<locale>-sheet.png` at search-result size, then inspect the original frames;
  - frame #1 shows "✓ In tune", and no frame shows a sliced status bar or a reward pill over the clock;
  - a missing or `-wrong` frame requires a fix and a new verified run; never upload an unchecked capture.

### H2. App Preview (optional for 2.0.0)
- [ ] **Who:** developer runs; owner approves the sound.
- **Where:** GitHub → Actions → **App Preview** → Run workflow on `main` (it can be dispatched once PR #2 has put it on `main`), with `preview: both`. The results land on `ci-results/preview` (main listing) and `ci-results/preview-violin` (the violin Custom Product Page): `preview.mp4`, `poster.png`, `contact.png`, `PREVIEW.txt`.
- **Upload only** a cut whose `PREVIEW.txt` ends with **"Meets the App Preview spec and its gates."**. Set the poster frame to the time `PREVIEW.txt` gives. Apple's limits: 15–30 s, 886 × 1920 for the 6.9" iPhone, at most 3 per size and language.
- **Verify:** watch it with sound on a phone. No preview is better than a silent one or one without the lock: the panel measured 77 % silence in the last shipped cut.

### H3. Apple Watch screenshots (required: the build carries a watch app)
- [ ] **Who:** developer, or the owner with a watch. **Where:** a Mac with Xcode 26 (the **TimbreWatch** scheme on an Apple Watch simulator paired with an iPhone one, then File → Save Screen), or a real watch (Watch app → General → Enable Screenshots; side button + Digital Crown). No CI job makes these.
- **Enter:**
  - **one size for every localization**: 416 × 496 (Series 10–12) is a good choice;
  - **3 frames**: the metronome mid-bar; Today with a lit flame and a part-done ring; a face with the circular and rectangular complications.
- **Upload:** the version page → Apple Watch section (it appears once a build with the watch app has processed).
- **Verify:** the version page no longer flags the Apple Watch section. The version can't be submitted without these.

### H4. App Information
- [ ] **Who:** owner. **Where:** the app → **App Information**.
- **Enter:**

| Field | Value |
|---|---|
| Name / Subtitle | `Timbre: Guitar Tuner & Lessons` / `Learn Songs: Ukulele & Violin` |
| Category | Primary **Music**, secondary **Education** |
| Content Rights | **Yes**, it contains third-party content, and you have the rights: public-domain songs (`docs/content/PUBLIC-DOMAIN-CLEARANCE.md`), CC0 recordings and credited CC BY 3D models (`docs/content/AUDIO-SOURCES.md`, Settings → Acknowledgements), Apple Music through MusicKit |
| Age Rating | Use [APP-STORE-LISTING.md → Age rating](APP-STORE-LISTING.md#age-rating) as proposed answers, then verify each against the final content and enabled features in Apple's current questionnaire. Game Center is off by default; this app is not submitted in the Made for Kids category. |
| Privacy Policy URL | B2's address |
| License Agreement | Apple's standard EULA (the default) |

- **Verify:** every current question is answered and the portal's resulting age rating accurately reflects the final app, content and capabilities. Do not force a target rating by changing factual answers. See [Apple's current age-rating procedure](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).

### H5. The version page (English (U.S.))
- [ ] **Who:** owner. **Where:** iOS App → **2.0.0** (rename "1.0" here).
- **Enter:**
  - **Promotional text**, **Description** and **Keywords** (97/100) from [APP-STORE-LISTING.md](APP-STORE-LISTING.md#keywords-97100), pasted exactly. In the description:
    - use the already resolved canonical privacy URL and reviewed per-locale payloads;
    - retain the current Game Center claim removal while the feature switch is off;
    - keep the band's line as "in your headphones" unless the listing has been updated since.
  - **Support URL:** B3's address. **Marketing URL:** optional.
  - **Version:** `2.0.0`. **Copyright:** `2026 Shahrad Azeri Sharghi`.
  - **What's New:** App Store Connect asks for it only on updates. If the field appears, paste the listing's "What's New (first release)" line.
- **Verify:** `python3 tools/marketing/screenshots.py --check` passes (it checks these texts against the build's counts and Apple's limits), and App Store Connect shows no field in red.

### H6. App Privacy
- [ ] **Who:** owner. **Where:** the app → **App Privacy** → Data Types → Edit, then **Publish**.
- **Enter, with analytics on (decision 0.5):** "Yes, we collect data". Each type below is **not linked** to the user and **not used for tracking**, with the purpose **Analytics**.

| Category | Data type | What the build sends |
|---|---|---|
| Identifiers | **Device ID** | A random per-install identifier, hashed on the device (`Telemetry.clientUser` in `Analytics.swift`). TelemetryDeck's own guidance is to declare it. |
| Usage Data | **Product Interaction** | The funnel and feature events (`app_open`, `paywall_view`, `lesson_done`, …) |
| Usage Data | **Advertising Data** | Apple Ads attribution: campaign, ad group and keyword numbers (`attribution`) |
| Diagnostics | **Crash Data** | MetricKit diagnostics (`diagnostics`) |
| Diagnostics | **Performance Data** | MetricKit daily metrics (`metrics_daily`) |
| Purchases | **Purchase History** | `purchase` (plan, price, currency), `renewal`, `refund`, `subscription_state`. Declaring it is the cautious reading of Apple's definition. |
| User Content | **Other User Content** | The song title typed into "Request a song" (`song_request`). Also the cautious reading. |

  No ATT prompt, no tracking domains (the privacy manifest says `NSPrivacyTracking = false`).

  **For a build without `TELEMETRYDECK_APP_ID`:** the telemetry transport is disabled, including analytics uploads, Apple Ads attribution HTTP and song-request submission. Remaining services such as remote settings, Apple's rating lookup, optional MusicKit searches and support email have their own request metadata and network information. Determine the portal answer from the final archive, enabled services and [Apple's current collection questions](https://developer.apple.com/app-store/app-privacy-details/), rather than inferring Data Not Collected from one missing ID. Keep the published policy aligned with these conditional behaviors.
- **Verify:** the product page preview shows "Data Not Linked to You" with those categories, and **no** "Data Used to Track You". PRIVACY.md describes each one.

### H7. Accessibility Nutrition Labels (voluntary, and a free difference)
- [ ] **Who:** owner. **Where:** the app → **App Accessibility** (Accessibility), for **iPhone** and **iPad**.
- **Enter:**

| Feature | Declare | Before declaring, check on a device |
|---|---|---|
| Dark Interface | Yes | Every screen is dark by design |
| Differentiate Without Color Alone | Yes | With the setting on, the tuner marks ▲ sharp, ▼ flat and ✓ in tune |
| Sufficient Contrast | **Once the accessibility job passes** | Text at 4.5:1 and controls at 3:1 are the design rule (`controlLine` is now `0x646A74`, 3.23:1 on cards), but the enforced contrast audit still fails on the tuner, the metronome, the paywall, a lesson and the welcome screen on `0bbf273` |
| Reduced Motion | Yes | With Reduce Motion on: onboarding, the tuner's lock, a lesson, the play-along |
| Larger Text | **Not yet** | Not until the AX5 captures of the tuner, a lesson and the play-along show nothing clipped. The tuner's header still clips at AX5. |
| VoiceOver | **Not yet** | Not until the lessons' notes step speaks the next note, the play-along's cues land on time, and blind testers have finished Unit 1 |
| Voice Control | Not yet | |
| Captions, Audio Descriptions | Leave unchecked | The app has no video with speech |

  Apple asks that a declared feature let someone finish every common task with it, the first launch, a purchase and Settings included. App Review can ask for corrections. Leave the Apple Watch unanswered until audited. Add B3's accessibility section as the **Accessibility URL** if you wrote one.
- **Verify:** the product page preview lists the declared features (three now, four once the contrast audit passes) for iPhone and iPad.

### H8. Pricing and Availability
- [ ] **Who:** owner. **Where:** the app → **Pricing and Availability**.
- **Enter:**
  - price **Free** (USD 0.00);
  - **all countries or regions except China mainland** (it needs an ICP filing number);
  - turn off availability on **Mac (Apple silicon)** and on **Apple Vision Pro** (untested there);
  - no pre-order;
  - the tax category is the default.
- **Verify:** the availability count is 174 storefronts (175 minus China mainland), give or take Apple's current list. Mac and Vision Pro show "Not available".

### H9. Product metadata check
- [ ] **Who:** owner. **Where:** each product from D2.
- **Enter:** the review screenshot from the TestFlight build (F3's paywall) and the review notes. Confirm the display names and descriptions above. App Store Connect ships them in English (U.S.); add localizations only with the locales the build ships.
- **Verify:** all three products are **Ready to Submit**.

### H10. The Holiday Carols In-App Event (submitted with 2.0.0)
- [ ] **Who:** owner; a designer makes the images. **Where:** the app → **In-App Events** → **+**.
- **Enter:**

| Field | Value |
|---|---|
| Reference name | `Holiday Carols 2026` |
| Event name (30) | `Holiday Carols` |
| Badge | Special Event |
| Short description (50) | `Play the carols, with the band` (30) |
| Long description (120) | `17 carols for guitar, ukulele, mandolin, violin, cello or bass, with the band. All free December 1–7.` (101) |
| Event card media | 16:9, 1920 × 1080 to 3840 × 2160, no text in the safe areas |
| Event details media | 9:16, 1080 × 1920 to 2160 × 3840 |
| Deep link | `timbre://songs` |
| Start / end | December 1, 2026 00:00 to December 31, 2026 23:59, local time |
| Publish start | November 17, 2026 (the earliest: 14 days before the start) |
| Purpose | The option that covers all users: new, active and lapsed |
| In-App Purchase required | No: the first week is free for everyone, and *Jingle Bells* always is. The long description promises only December 1–7. |

  The "All free December 1–7" promise needs step K4 on December 1, and the remote settings URL in the build (C4).
- **Verify:** the event shows "Ready for Review". It is added to the submission in I2. An app that hasn't been approved yet can submit its first event only with its first version.

### H11. App Review Information
- [ ] **Who:** owner. **Where:** the version page → **App Review Information**.
- **Enter:**
  - **Sign-in required:** No.
  - **Contact:** your name, phone and email.
  - **Notes:** paste the block below. Delete the Game Center paragraph if decision 0.6 left it off. When a later submission carries `timbre_pro_annual_b` (K3), add: "timbre_pro_annual_b is a yearly price-test plan. The remote settings show it to half of new paywall viewers in place of timbre_pro_annual; it unlocks the same Pro access."
  - **Attachment** (optional): a 30-second screen recording of the tuner hearing a tone, and of the paywall.

```
Thank you for reviewing Timbre. No account or sign-in is needed.

MICROPHONE
Timbre needs the microphone to tune and to hear lessons. Audio is analysed on the device and is never recorded or uploaded. With no instrument to hand, play a steady tone from another device (for example 440 Hz, or 82 Hz for the guitar's low E): the tuner shows the note and locks when it is in tune.

TIMBRE PRO (SUBSCRIPTIONS AND LIFETIME)
Quickest route to the paywall: Tune tab > Settings (the sliders button at the top) > Try Timbre Pro. It also opens from any locked lesson (Learn tab > a lesson in unit 2 or later), from Practice > Tools > Drone, and from a Pro tuning (Tune tab > tap the instrument name > Mandolin > an alternate tuning).
The paywall shows each plan's price and period, the free-trial timeline, the auto-renewal terms, Restore, Terms (Apple's standard EULA) and Privacy. Products: timbre_pro_annual (2-week free trial), timbre_pro_monthly, timbre_plus_lifetime. After a sandbox purchase every lock disappears: all lessons and songs, every tuning of every instrument, the drone, scales and the strobe's Pro precision.
Free without purchase: every instrument's standard tuning, every preset tuning of guitar, bass, ukulele, violin and cello, the first unit of every course and a shelf of songs.

BACKGROUND AUDIO
The audio background mode keeps the metronome, drone and play-along sounding when the screen locks.

APPLE WATCH
The Apple Watch app is a companion. Its metronome works on its own. The streak and Today come from the iPhone app, so open it once after installing.

YOUR SONGS AND APPLE MUSIC
Your songs (Songs tab > Add a song) plays chord charts and recordings the user supplies; they stay on the device and nobody else sees them. The songs the app ships are public domain or written for Timbre. Listen on Apple Music is a plain player for subscribers, started by the user, free, and not synchronised with anything. To try it, add a song (paste any chord chart), then tap Find this song on Apple Music.

GAME CENTER
Leaderboards, achievements and challenges appear on the Practice tab's game cards (Bullseye, ear training) and after a featured song once Game Center is signed in. Nothing about Game Center is required to use the app.

PRIVACY
Anonymous usage analytics (TelemetryDeck) are not linked to the user and not used for tracking. They can be switched off in Settings > Share anonymous usage data. There is no advertising.
```

- **Verify:** the notes fit the field (under 4,000 characters), and every route in them works on the TestFlight build.

### H12. Version release
- [ ] **Who:** owner. **Where:** the version page → **App Store Version Release**.
- **Enter:** **Manually release this version**. Phased release applies to updates, which reach existing users through automatic updates; use it from 2.0.1 on.

---

## Phase I: submit for review (the owner authorizes the final build)

### I1. The release build
- [ ] **Who:** owner dispatches or approves. **Where:** E2 again, from the `main` commit the device sheet passed on.
- **Enter:** `marketing_version 2.0.0`, the **next** `build_number`, `ship_min_coverage 95`, `internal_testflight_untranslated` unticked.
- **Verify:**
  - the summary shows `en` and "Upload accepted";
  - the build processes in TestFlight;
  - a final 10-minute smoke test on one phone: launch, tune, buy, restore.

### I2. Assemble and submit
- [ ] **Who:** owner. **Where:** the 2.0.0 version page.
- **Enter:**
  - under **Build**, select the build from I1;
  - under **In-App Purchases and Subscriptions**, add `timbre_pro_annual`, `timbre_pro_monthly` and `timbre_plus_lifetime`, not `_b` or `_c`;
  - then **Add for Review**;
  - in the draft submission, also add the **Holiday Carols** event;
  - **Submit for Review**.
- **Verify:** the status reads **Waiting for Review**. Apple emails each change. Review usually takes a day or two; a rejection arrives in the Resolution Center with the guideline number. Answer it there, fix the problem, deliver a new build number if code changed, and resubmit.

### I3. Billing Grace Period in production
- [ ] **Who:** owner, once F3's grace test passed. **Where:** Subscriptions → Billing Grace Period → Edit.
- **Enter:** server environments **Production and Sandbox** (16 days, All Renewals).
- **Verify:** the section shows Production. It applies to renewals within 24 hours.

---

## Phase J: release (owner)

### J1. Release
- [ ] **Who:** owner. **Where:** the version page, once it shows **Pending Developer Release**.
- **Enter:** **Release This Version** on the chosen day (between 17 and 24 November).
- **Verify:**
  - the status goes to Processing for Distribution, then **Ready for Distribution**;
  - within a few hours, the product page is live at `https://apps.apple.com/app/id<TIMBRE_APP_STORE_ID>`;
  - search for "Timbre guitar tuner"; search indexing can take a day.

### J2. Day-0 checks
- [ ] On a device that never had a TestFlight build, install from the App Store:
  - onboarding, the tuner, the paywall with live prices;
  - a real purchase if you want one: refund it through reportaproblem.apple.com afterwards, and watch `refund` arrive.
- [ ] The product page shows:
  - the three in-app purchases;
  - age consistent with the app's current portal rating and the event's content;
  - **English** as the language;
  - the privacy label from H6;
  - the accessibility features from H7;
  - Apple Watch screenshots;
  - the event once it is published.
- [ ] TelemetryDeck shows production `app_open` from build I1, and the remote settings file is being fetched (your host's log).

---

## Phase K: after launch

### K1. Monitoring (daily for two weeks, then weekly)
- **App Store Connect → Analytics:**
  - impressions, product page views, conversion rate and downloads, by source and later by Custom Product Page;
  - Sales and Trends → Subscriptions: trials started, trial-to-paid, renewals, cancellations.
- **TelemetryDeck funnel**, in this order: `app_open` → `onboarding_step` → `mic_permission` → `onboarding_first_tune` → `onboarding_first_chord` → `onboarding_complete` → `paywall_view` → `purchase_start` → `purchase` (with `trial`), then `subscription_state`, `renewal`, `refund`.
  - Also watch `paywall_close`, `exit_offer_shown`, `song_request` (what to license next) and `attribution`.
  - The panel's planning numbers: about **2.6 % install-to-paid**, and a 14-day yearly trial converting near **43 %**. At the recommended prices, that means about **8,800 installs a month for $10k a month**.
- **Crashes and hangs:** Xcode → Organizer → Crashes, Hangs, Energy for build I1 (symbols are uploaded by the delivery workflow); TelemetryDeck `diagnostics` and `metrics_daily`; TestFlight feedback.
  - A crash in launch, the tuner or purchase means a hotfix: fix it, deliver a new build number, submit 2.0.1, and request an expedited review if it blocks use.
- **Ratings and reviews:** App Store Connect → Ratings and Reviews.
  - Reply to every 1–3★ review within two days.
  - The app asks for a rating at the 3rd and 12th full tune, after the first song played with three stars, and after a flawless 2nd and 10th lesson. StoreKit decides whether the sheet actually shows, at most three times a year.
  - The paywall's rating line appears by itself, per storefront, once that storefront has at least 4.6★ from 200 ratings (`rating.show` in B5 can switch it off).

### K2. Updates
- Every update: run Phase E with the next build number, the device cases it touches, then I1–I2.
- Choose **Release update over 7-day period using phased release**: 1 %, 2 %, 5 %, 10 %, 20 %, 50 %, 100 %. You can pause it for up to 30 days in total.
- Anyone can still download the update manually during a phased release.

### K3. Growth set-up that needs an approved app (in this order)

| When | What | Where |
|---|---|---|
| After approval | **Win-back offers** on each plan, for example 1 month free for people whose subscription ended 1–6 months ago. A subscription must be approved first. | Subscriptions → the plan → Subscription Prices → **+** → Create Win-Back Offer ([APPLE-DELIVERY.md §6.4](APPLE-DELIVERY.md#64-the-paywalls-one-time-exit-offer)) |
| After Ready for Distribution | **Offer codes**: a custom code such as `FRIENDMONTH` (one free month, new subscribers). Then add `"referralCode": "FRIENDMONTH"` to B5's file, and "Give a friend a month" appears. One-time codes redeem only once the app is Ready for Distribution. | Subscriptions → the plan → Offer Codes ([§6.3](APPLE-DELIVERY.md#63-offer-codes-redeem-code-on-the-paywall)) |
| After about 2 weeks of baseline paywall data | **Price test**: submit `timbre_pro_annual_b` ($59.99). Once it is approved, set `"paywall": [{ "id": "control", "weight": 50 }, { "id": "annual_b", "weight": 50, "annualProductId": "timbre_pro_annual_b" }]`. Read the result by `variant` in TelemetryDeck. | D5, B5 |
| After 2.0.0's keyword field is approved | **Custom Product Pages**: violin, cello and ukulele first. A page's keywords can only come from the latest approved version's keyword field. | [APPLE-DELIVERY.md §9.2](APPLE-DELIVERY.md#92-custom-product-pages) |
| After launch | **Product Page Optimization**, one test at a time | [§9.4](APPLE-DELIVERY.md#94-product-page-optimization) |
| Early December | **Featuring nomination** for January's "learn something new" window, with the Tune by feel story. The December window has passed. | [§9.5](APPLE-DELIVERY.md#95-featuring-nomination) |
| Once revenue per install is measured | **Apple Ads**, about $1.5–3k a month on exact-match instrument keywords | [§9.7](APPLE-DELIVERY.md#97-apple-ads) |
| With 2.1 | **Game Center** (if left off), with its art | [§6.1](APPLE-DELIVERY.md#61-game-center) |

### K4. Carol week
- [ ] **Before December 1:** schedule `freeSongs` in B5's file with the carols' lesson IDs and `freeSongsWindow: {"startDate":"2026-12-01","endDate":"2026-12-08"}`. These are Gregorian local dates in each player's current time zone: start inclusive, end exclusive, so all of December 1–7 is covered. That is 17 carols, each in the guitar version and the ukulele, mandolin, violin, cello and bass songbooks: 102 IDs, below the bounded 256-ID limit. Generate the campaign fields and merge them into the existing settings without replacing unrelated keys:

```sh
python3 - <<'EOF'
import json
carols = ["song-silent-night", "song-jingle-bells", "song-joy-to-the-world", "song-deck-the-halls", "song-we-wish-you",
          "song-good-king-wenceslas", "std-o-christmas-tree", "std-o-come-all-ye-faithful", "std-the-first-noel",
          "std-hark-the-herald", "std-away-in-a-manger", "std-o-little-town", "std-it-came-upon", "std-royal-davids-city",
          "std-bleak-midwinter", "std-holly-and-ivy", "std-angels-from-the-realms"]
print(json.dumps({"freeSongs": [prefix + c for c in carols for prefix in ["", "uke-sb-", "man-sb-", "vln-sb-", "vc-sb-", "bass-sb-"]],
                  "freeSongsWindow": {"startDate": "2026-12-01", "endDate": "2026-12-08"}}, indent=2))
EOF
```

- [ ] **Verify before publishing:** all 102 IDs exist, late-list cello and bass songs unlock during the window, unrelated paid lessons stay locked, and cached/offline access expires at local midnight starting December 8. A missing window intentionally preserves permanent `freeSongs`; a supplied invalid/partial/reversed window grants none. This window does not affect `flags.unit2Free`. See [the schema](APPLE-DELIVERY.md#5-analytics-links-and-remote-settings).
- [ ] **December 8:** the app expires these grants automatically, including offline. Clean up both `freeSongs` and `freeSongsWindow` together when convenient; do not remove only the window while leaving song IDs, which would intentionally turn them into permanent grants. Already started takes are not interrupted.

### K5. More languages
- When a translator delivers a locale, the developer imports it (`python3 tools/l10n/report.py --import tools/l10n/todo`).
- Then check: `python3 tools/l10n/shipping.py --min 95 --critical` must list it.
- The next delivery with `ship_min_coverage: 95` then includes it.
- Add that locale's store listing from [APP-STORE-LISTING-LOCALIZED.md](APP-STORE-LISTING-LOCALIZED.md): its name, subtitle and keywords are current; its description, promotional text and captions need translating. Add the product localizations too.
- Don't add a store listing for a language the build doesn't ship.

---

## Quick reference

| Thing | Value |
|---|---|
| Bundle IDs | `com.shahradazerisharghi.timbre`, `.widgets`, `.watchkitapp`, `.watchkitapp.widgets` |
| App Group | `group.com.shahradazerisharghi.timbre` |
| Subscription group | `Timbre Pro` |
| Products | `timbre_pro_annual`, `timbre_pro_monthly`, `timbre_plus_lifetime`; price-test arms `timbre_pro_annual_b`, `timbre_pro_annual_c` |
| Environment secrets (`apple-delivery`) | `APPLE_TEAM_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_P8` |
| Repository variables | `TELEMETRYDECK_APP_ID`, `TIMBRE_APP_STORE_ID`, `TIMBRE_REMOTE_CONFIG_URL`, `TIMBRE_SHARE_URL` |
| Set in `ios/project.yml` | `TIMBRE_PRIVACY_POLICY_URL`; `CFBundleLocalizations` (via `tools/l10n/shipping.py --apply`) |
| Info.plist keys the app reads | `TimbreTelemetryAppID`, `TimbreAppStoreID`, `TimbreRemoteConfigURL`, `TimbreShareURL`, `TimbrePrivacyURL` / `TimbrePrivacyPolicyURL`, `TimbreBuildChannel`, `ITSAppUsesNonExemptEncryption = false` |
| CI evidence branches | `ci-results/gate`, `core`, `release`, `accessibility` (PR gate); `ci-results/app`, `ipad`, `a11y-matrix`, `tsan` (nightly); `ci-results/preview`, `preview-violin` (App Preview); a non-`main` branch adds `--<branch>` |
| Required check on `main` | `gate` (from the iOS workflow) |

## Sources (Apple's rules, checked 25 October 2026)

- [App privacy details on the App Store](https://developer.apple.com/support/app-privacy-on-the-app-store/): the data types, "collect", "linked", "tracking", and the optional-disclosure criteria
- [TelemetryDeck: Apple's app privacy details](https://telemetrydeck.com/docs/articles/apple-app-privacy/): declare Device ID and Product Interaction, Analytics, not linked, not tracking
- [Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels): the features, per device, voluntary for now, the "common tasks" rule, the Accessibility URL
- [In-App Events](https://developer.apple.com/app-store/in-app-events), [Offer In-App Events](https://developer.apple.com/help/app-store-connect/offer-in-app-events/offer-in-app-events) and [Submit an In-App Event](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-event): the limits, badges, media, 31 days long, published up to 14 days ahead, the first event goes with the first version
- [Custom product pages](https://developer.apple.com/app-store/custom-product-pages/): 70 pages, keywords, deep links on iOS 18 or later, reviewed independently
- [Set up introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions): trial lengths, one introductory offer per person per group
- [Set up win-back offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-win-back-offers/): the subscription must be approved first; the eligibility settings
- [Set up subscription offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes): code types, 1,000,000 a quarter, one-time codes need Ready for Distribution
- [Enable Billing Grace Period](https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions): 3, 16 or 28 days, all or paid-to-paid renewals, sandbox first, 24 hours to apply
- [Turn on Family Sharing for in-app purchases](https://developer-mdn.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases): it can't be turned off
- [Enter server URLs for App Store Server Notifications](https://www.developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications)
- [Complying with encryption export regulations](https://developer.apple.com/tutorials/data/documentation/security/complying-with-encryption-export-regulations.md): `ITSAppUsesNonExemptEncryption = NO` for the operating system's own encryption (HTTPS through URLSession). Apple notes that some exempt uses still call for a year-end self-classification report to the U.S. government; confirm once whether that applies.
- [Apple notifies developers of the new age rating system (9to5Mac)](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/) and [the social media question, required from September 2026 (PPC Land)](https://ppc.land/apple-forces-13-rating-on-apps-with-social-feeds-from-september/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview): 100 internal and 10,000 external testers, Beta App Review for the first external build, 90-day builds
- [Release a version update in phases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases): 7 days, 1 % to 100 %, up to 30 days paused
- [App and submission statuses](https://www.developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses): Pending Developer Release, Ready for Distribution
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications): sizes, 1–10 screenshots, 15–30 s previews, the Apple Watch sizes
- [Upcoming requirements for app distribution in the EU](https://developer.apple.com/news/?id=a0nevv65): trader status
- [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/): eligibility, enrollment and when the 15 % takes effect
- [App Store Connect app information reference](https://developer.apple.com/help/app-store-connect/reference/app-information/) and [Developer Forums: the ICP filing number](https://developer.apple.com/forums/thread/743661): China mainland availability
