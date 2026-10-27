# Timbre for iOS — Apple delivery handoff

What the owner sets up in Apple's portals and GitHub before the first App Store build. Nothing here has been executed yet: no signing, upload or App Store product exists until the owner does these steps.

## Identity

| | |
|---|---|
| App | **Timbre** |
| Bundle ID (app) | `com.shahradazerisharghi.timbre` |
| Bundle ID (widgets) | `com.shahradazerisharghi.timbre.widgets` |
| Bundle ID (Apple Watch app) | `com.shahradazerisharghi.timbre.watchkitapp` (ships inside the iPhone app, [section 7](#7-apple-watch-companion-owner-steps)) |
| Bundle ID (watch complications) | `com.shahradazerisharghi.timbre.watchkitapp.widgets` |
| App Group | `group.com.shahradazerisharghi.timbre` (widgets read the practice streak from it; on the watch, the complications read the watch app's copy) |
| Minimum iOS | 18.0, iPhone and iPad |
| Privacy policy URL | https://azerish25-ux.github.io/tuner/privacy.html (move it to the owner's domain before launch: §5) |
| Terms | Apple standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ |

## 1. App Store Connect app

1. Accept the Paid Apps agreement and complete banking and tax (Business → Agreements). Subscriptions cannot go live without it.
2. Enrol in the **App Store Small Business Program** (15% commission instead of 30%).
3. Create the app: **Apps → + → New App**, platform iOS, name Timbre, bundle ID `com.shahradazerisharghi.timbre` (register it under Certificates, Identifiers & Profiles if it is not offered; automatic signing in step 3 can also register it).

## 2. In-app purchases (exact identifiers — the app looks these up)

Create a subscription group named **Timbre Pro** with two auto-renewable subscriptions at the same level:

| Product ID | Type | Duration | US price (recommended; the owner decides) | Introductory offer |
|---|---|---|---|---|
| `timbre_pro_annual` | Auto-renewable | 1 year | $49.99 (the StoreKit test file still says $34.99) | Free trial, 2 weeks, new subscribers. Keep 14 days: yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 |
| `timbre_pro_monthly` | Auto-renewable | 1 month | $9.99 ($6.99 in the test file) | None recommended (use win-back offers and offer codes, §6.3–6.4). If you add one, this build's paywall already discloses any plan's trial on its card, button, terms line and reminder |

And one non-consumable:

| Product ID | Type | US price |
|---|---|---|
| `timbre_plus_lifetime` | Non-consumable | $149.99 ($89.99 in the test file); onboarding's paywall leaves it out unless the remote settings say otherwise (§5) |

Turn **Family Sharing** on for the yearly plan and lifetime (parents buy lessons for their children; say so on the paywall once it is on). The prices above are the recommendation for $10k a month, about a third of the lesson apps' prices; test $49.99 against $59.99 later with a second yearly product chosen by the remote settings file (§5).

For that price test, two more yearly subscriptions can now be created in the **Timbre Pro** group, at the same level as `timbre_pro_annual`: `timbre_pro_annual_b` and `timbre_pro_annual_c` (1 year, the arm's price, the same 14-day free trial, Family Sharing as the standard year). The app already loads them and grants Pro for them exactly as for the standard year. A paywall arm sells one only when the remote settings name it (`annualProductId`, §5); where one isn't created, or isn't on sale in a storefront, that arm keeps selling `timbre_pro_annual`.

The paywall shows the yearly plan's weekly cost, worked out from the yearly price Apple returns, so it always matches the storefront. The paywall's offer codes and its one-time exit offer are set up in [section 6](#6-growth-features-owner-steps).

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

4. Run **Actions → Apple delivery → Run workflow** on `main` with a version (2.0.0), a new build number, and the confirmation box ticked. It runs the core tests, archives the Release build, signs it and uploads it to App Store Connect, where it appears under TestFlight after processing. The version and build number go into every bundle (app, widgets, watch app, complications); App Store Connect refuses a build number it has already seen for that version. Two more inputs, both optional:
   - **ship_min_coverage**: ship only the languages with at least this percent of the interface translated (`tools/l10n/shipping.py`, applied to this run's checkout only). Empty ships the committed `CFBundleLocalizations`.
   - **internal_testflight_untranslated** (off by default): **internal TestFlight only.** Every build must pass the translation gate (`tools/l10n/critical.py --strict`: the paywall's renewal terms, the permission prompts and VoiceOver's words translated in every language it ships). Ticked, the gate only reports, and the build is exported with `testFlightInternalTestingOnly`: App Store Connect offers it to internal testers and it can never be submitted for App Store review or external testing. Its Info.plist says `TimbreBuildChannel = internal`, and the run's summary says so too. Use it to try a build on devices while translations are still coming; for a build meant for review, leave it off and ship fewer languages (`ship_min_coverage`) or deliver the translations first.

## 4. Listing

- Category: Music. Secondary: Education.
- Age rating: complete Apple's current questionnaire using the content and capabilities of the release build. [APP-STORE-LISTING.md](APP-STORE-LISTING.md#age-rating) contains the proposed answers; the portal determines the rating.
- App Privacy: with analytics configured (§5), review all seven declared types: Product Interaction, Performance Data, Crash Data, Advertising Data, Device ID, Purchase History and Other User Content. The source manifest marks these for Analytics, not linked to the user and not used for tracking; [release checklist H6](RELEASE-CHECKLIST.md#h6-app-privacy) explains their source. Compare the final archive and active services with [Apple's current questions](https://developer.apple.com/app-store/app-privacy-details/) before entering responses. An unset TelemetryDeck ID disables this app's analytics uploads; it does not by itself certify a Data Not Collected answer for every service or future configuration.
- Encryption: the app uses only Apple's standard encryption (`ITSAppUsesNonExemptEncryption = false`).
- Text, keywords and media: [APP-STORE-LISTING.md](APP-STORE-LISTING.md) (English) and [APP-STORE-LISTING-LOCALIZED.md](APP-STORE-LISTING-LOCALIZED.md). The screenshot pipeline captures and composes the required medium Dynamic Island iPhone set at 1206×2622 and the 13-inch iPad set at 2752×2064. Upload those to their matching display slots in App Store Connect; a large iPhone set does not close the medium-size inventory. The separate App Preview workflow retains its Pro Max capture and 886×1920 delivery format. Upload a preview only after its actual video/audio gates and visual review pass; use the poster time in `PREVIEW.txt`.
- Subscription disclosures are on the paywall (price, period, auto-renewal, cancel in Settings, Terms and Privacy links), as App Review Guideline 3.1.2 requires.

## 5. Analytics, links and remote settings

Four addresses and one ID are build settings in `ios/project.yml`, carried into Info.plist and read by `AppLinks` (`ios/Timbre/Services/ShareDestination.swift`). An empty value means "not set yet": the app falls back or hides what needs it. The delivery workflow passes each **repository variable** (GitHub → Settings → Secrets and variables → Actions → **Variables**) into the archive; unset keeps the project's value.

| Repository variable | Build setting | What it switches on |
|---|---|---|
| `TELEMETRYDECK_APP_ID` | `TIMBRE_TELEMETRY_APP_ID` | Anonymous product events to [TelemetryDeck](https://telemetrydeck.com) (privacy-first: no IDFA, no personal data, a random install ID hashed on the device): the funnel from `app_open` through onboarding, `paywall_view`, trial and purchase. Without it nothing leaves the device. |
| `TIMBRE_APP_STORE_ID` | `TIMBRE_APP_STORE_ID` | The app's Apple ID in App Store Connect (digits only, App Information → Apple ID). Shares, "Beat my score" messages and the offer-code links point at `https://apps.apple.com/app/id<ID>`. Set it as soon as the app record exists. |
| `TIMBRE_SHARE_URL` | `TIMBRE_SHARE_URL` | An https page on the owner's domain that opens a shared route in Timbre (`…/lesson?id=…`) or sends someone without the app to the App Store. Without it, shares link to the App Store page. |
| `TIMBRE_REMOTE_CONFIG_URL` | `TIMBRE_REMOTE_CONFIG_URL` | The remote settings file below. |
| (edit `ios/project.yml`) | `TIMBRE_PRIVACY_POLICY_URL` | The privacy policy the paywall and Settings link to; move it to the owner's domain here and in App Information. |

**The remote settings file** (`ios/Timbre/Services/RemoteConfig.swift`): a small JSON file on the owner's domain, fetched when the app comes forward (at most every 6 hours), with no identifier in the request. Offline, missing or unparseable, the last good copy (or the built-in defaults) holds; nothing waits for it.

```json
{
  "paywall": [{ "id": "control", "weight": 50 },
              { "id": "annual_b", "weight": 50, "annualProductId": "timbre_pro_annual_b" }],
  "rating": { "show": true },
  "referralCode": "FRIENDMONTH",
  "freeSongs": ["song-silent-night", "uke-sb-song-silent-night"],
  "freeSongsWindow": { "startDate": "2026-12-01", "endDate": "2026-12-08" },
  "flags": { "unit2Free": true }
}
```

- `paywall`: the arms of a paywall test, each with a `weight` (its share, 1 when left out). An arm may sell another yearly product (`annualProductId`, which must exist in the same subscription group), show lifetime on onboarding's paywall (`onboardingLifetime`), or change onboarding's headline (`headline`: `song`, the default, or `plan`). A person keeps the arm first drawn for as long as it is listed; dropping an arm moves its people to the others. The analytics events carry the arm.
- `rating`: only `show` is needed. The paywall's rating line is on unless `show` is false, and appears only where the app really has at least 4.6★ from 200 ratings in that storefront: its figures always come from the App Store itself, and any stars or count written in the file are ignored.
- `referralCode`: the offer code "Give a friend a month" hands out (§6.3).
- `freeSongs`: song lesson IDs opened to everyone, at most **256** valid IDs of 1–64 ASCII letters, digits, dashes, dots or underscores. This accommodates all 102 Carol editions. The fetched file remains limited to 64,000 bytes. Without `freeSongsWindow`, these are intentionally permanent grants until removed from the remote settings.
- `freeSongsWindow` (optional): `{ "startDate": "2026-12-01", "endDate": "2026-12-08" }`. Strict **Gregorian local dates**, `YYYY-MM-DD`, evaluated in each player's current time zone, regardless of their preferred calendar. Start is inclusive and end exclusive: this example opens the songs on December 1–7, ending at local midnight starting December 8. A supplied null, wrong-shaped, partial, impossible or reversed window opens **no listed songs**; it never falls back to permanent access. Cached/offline access rechecks the window at every access read. Foreground, day/clock/time-zone changes and scheduled boundaries refresh visible access; an already started take continues. The window does not restrict the independent `unit2Free` flag.
- `flags`: named switches for experiments. `unit2Free` opens the second unit of every teaching course to everyone (songbooks keep their own free songs).

Before submitting with analytics on, update the App Privacy label (§4) and the "Analytics" section of PRIVACY.md.

## 6. Growth features: owner steps

Game Center is disabled by default through `TIMBRE_GAME_CENTER_ENABLED=NO`. Keep it off for the base release unless its account records, entitlement, assets and device checks are complete; enabling portal records alone does not enable the app feature. Other purchase-related features depend on actual Apple offers and product eligibility. The Game Center identifiers below are also in `ios/Timbre/Services/GameCenterIDs.swift` and must match configured records exactly.

### 6.1 Game Center

1. **Capability.** Under Certificates, Identifiers & Profiles → Identifiers → `com.shahradazerisharghi.timbre`, check that **Game Center** is ticked. It is on by default for explicit App IDs.
2. **Entitlement and feature switch.** After the account records and assets are ready, add `com.apple.developer.game-center: true` under `targets → Timbre → entitlements → properties` in `ios/project.yml`, and set `TIMBRE_GAME_CENTER_ENABLED=YES` for the intended release configuration. Verify the signed profile, authentication and reporting on a device. The entitlement is omitted and the feature switch is off in the default release. Do not add `gamekit` to `UIRequiredDeviceCapabilities`.
3. **Friends list reason (for the friend streak).** This is a one-line change to `ios/project.yml`. Under `targets → Timbre → info → properties`, beside `NSMicrophoneUsageDescription`, add:
   `NSGKFriendListUsageDescription: Timbre shows where your practice streak stands among your Game Center friends who also play Timbre. It never shows their names.`
   GameKit shows this sentence in its one-time prompt. Without the key the app never asks, and the friend streak stays off.
4. **Turn on Game Center for the app version.** Go to App Store Connect → the app → Features → **Game Center** → enable it. Then, on the version page, add the leaderboards, achievements, challenges and activities below under Game Center.
5. **Leaderboards.** Create all twelve. Each uses score format **Integer** and is sorted **High to low**. The submission type is **Best score** for every board except `timbre.streak`, which is **Most recent score**, because a streak goes down when it ends.

| Leaderboard ID | Type | Name (English) | Score range | Notes |
|---|---|---|---|---|
| `timbre.sniper.best` | Classic | Bullseye | 0 – 25,000 | All-time best game |
| `timbre.sniper.weekly` | Recurring | Bullseye this week | 0 – 25,000 | Starts on a Monday at 00:00 UTC, lasts 1 week, restarts every week. This is the weekly league. The Leaderboard chip opens it first, and the Bullseye challenge is built on it. |
| `timbre.ear.level` | Classic | Ear trainer level | 1 – 100 | The level the Practice tab shows |
| `timbre.streak` | Classic | Practice streak | 0 – 10,000 | **Most recent score.** Days in a row, sent when the streak changes. The friend streak reads it back for friends only. |
| `timbre.song.twinkle` | Classic | Twinkle, Twinkle, Little Star | 0 – 200,000 | Perform score |
| `timbre.song.odetojoy` | Classic | Ode to Joy | 0 – 200,000 | Perform score |
| `timbre.song.jinglebells` | Classic | Jingle Bells | 0 – 200,000 | Perform score |
| `timbre.song.saints` | Classic | When the Saints Go Marching In | 0 – 200,000 | Perform score |
| `timbre.song.kiteweather` | Classic | Kite Weather | 0 – 200,000 | Perform score |
| `timbre.song.dashboard` | Classic | Dust on the Dashboard | 0 – 200,000 | Perform score |
| `timbre.song.lochlomond` | Classic | Loch Lomond | 0 – 200,000 | Perform score |
| `timbre.song.mountain` | Classic | She'll Be Coming 'Round the Mountain | 0 – 200,000 | Perform score |

The eight song boards are the "Perform" family: one per featured song (`GameCenterIDs.songs`, all free, so every player can answer a challenge). A board takes the score of a whole take at the song's own tempo: each note's credit (perfect 1, good 0.8, late or early 0.5) × 100 × the combo multiplier (up to ×4). Slower takes and practice loops never count. The longest featured song has 228 notes, so 200,000 leaves room for longer songs later. To feature another song, add a line to `GameCenterIDs.songs` and create its board, challenge and activity with the same slug.

6. **Achievements.** Create these 31 achievements, worth 895 points in all (the cap is 1,000). For every one, set Hidden to No and Achievable more than once to No. Add a 1024 × 1024 image. Use the badge's title as the title. Use its detail for both descriptions, before and after it is earned. The per-instrument course badges and the Pro-only badges (custom tuning, Pro-precision locks) are left out on purpose.

| Achievement ID | Title | Description | Points |
|---|---|---|---|
| `timbre.badge.first_tune` | First in tune | Tune your first string | 5 |
| `timbre.badge.full_tune` | All six | Tune every string of an instrument | 10 |
| `timbre.badge.strings_100` | Hundred strings | Tune 100 strings | 20 |
| `timbre.badge.full_25` | Tune-up habit | Tune every string 25 times | 25 |
| `timbre.badge.multi` | Multi-instrumentalist | Tune three different instruments | 20 |
| `timbre.badge.strings_1000` | Thousand strings | Tune 1,000 strings | 50 |
| `timbre.badge.streak_3` | Warming up | Play three days in a row | 10 |
| `timbre.badge.streak_7` | Perfect week | Play seven days in a row | 25 |
| `timbre.badge.streak_30` | Month of music | Play thirty days in a row | 50 |
| `timbre.badge.streak_100` | Hundred days | Play 100 days in a row | 100 |
| `timbre.badge.level_5` | Rising star | Reach level 5 | 25 |
| `timbre.badge.minutes_60` | First hour | Practice for an hour in all | 10 |
| `timbre.badge.minutes_600` | Ten hours | Practice for ten hours in all | 50 |
| `timbre.badge.daily_1` | Daily set | Finish a daily set | 5 |
| `timbre.badge.daily_30` | Creature of habit | Finish 30 daily sets | 50 |
| `timbre.badge.bullseye` | Bullseye | Hit your first bullseye | 5 |
| `timbre.badge.sniper_win` | Round Winner | Win a round of Bullseye | 10 |
| `timbre.badge.bullseyes_50` | Dead center | Hit 50 bullseyes | 25 |
| `timbre.badge.sharpshooter` | High Scorer | Score 2,000 in Bullseye | 50 |
| `timbre.badge.golden_ear` | Golden ear | Answer 50 ear questions right | 25 |
| `timbre.badge.ear_perfect` | Clean sweep | Get all ten right in an ear round | 25 |
| `timbre.badge.ear_500` | Master listener | Answer 500 ear questions right | 50 |
| `timbre.badge.first_lesson` | First lesson | Finish your first lesson | 5 |
| `timbre.badge.units_1` | Unit cleared | Finish every lesson in a unit | 10 |
| `timbre.badge.songs_1` | First song | Play your first song | 10 |
| `timbre.badge.lessons_25` | Regular | Finish 25 lessons | 25 |
| `timbre.badge.perfect_10` | Flawless | Earn three stars on 10 lessons | 25 |
| `timbre.badge.units_10` | Ten units | Finish ten units | 25 |
| `timbre.badge.lessons_100` | Scholar | Finish 100 lessons | 50 |
| `timbre.badge.course_done` | Graduate | Finish a whole course | 50 |
| `timbre.badge.songs_25` | Songbook | Play 25 songs | 50 |

7. **Challenges (iOS 26 and later).** Go to App Store Connect → the app → Game Center → **Challenges** → (+). Enter the reference name and the challenge ID. Under Associated Leaderboard, choose the board below. Add an English localization (display name and description) and a 3840 × 2160 image (PNG or JPEG, RGB, no transparency; the share card art on a wide dark canvas works). Submit the challenges for review with the app version. Apple allows 20 challenges per app, and these use 9.

| Challenge ID | Associated leaderboard | Repeatable | Display name | Description |
|---|---|---|---|---|
| `timbre.challenge.sniper` | `timbre.sniper.weekly` | Yes | Bullseye duel | Ten notes, one bullseye at a time. The best game wins. |
| `timbre.challenge.song.twinkle` | `timbre.song.twinkle` | No | Twinkle, Twinkle, Little Star | One take at full tempo. The best score wins. |
| `timbre.challenge.song.odetojoy` | `timbre.song.odetojoy` | No | Ode to Joy | One take at full tempo. The best score wins. |
| `timbre.challenge.song.jinglebells` | `timbre.song.jinglebells` | No | Jingle Bells | One take at full tempo. The best score wins. |
| `timbre.challenge.song.saints` | `timbre.song.saints` | No | When the Saints Go Marching In | One take at full tempo. The best score wins. |
| `timbre.challenge.song.kiteweather` | `timbre.song.kiteweather` | No | Kite Weather | One take at full tempo. The best score wins. |
| `timbre.challenge.song.dashboard` | `timbre.song.dashboard` | No | Dust on the Dashboard | One take at full tempo. The best score wins. |
| `timbre.challenge.song.lochlomond` | `timbre.song.lochlomond` | No | Loch Lomond | One take at full tempo. The best score wins. |
| `timbre.challenge.song.mountain` | `timbre.song.mountain` | No | She'll Be Coming 'Round the Mountain | One take at full tempo. The best score wins. |

   - The app finds each challenge by the leaderboard it is built on, so any subset works. Create Bullseye's first. Until a challenge exists, and always below iOS 26 or when signed out, "Challenge a friend" shares a "Beat my score" card with a link instead (§6.2).
   - Bullseye's challenge is repeatable (players pick 1, 3 or unlimited tries), and Apple only allows that on a recurring board. It lasts the rest of the board's week. The song challenges sit on classic boards, so they are one take each, and the player picks 1 day, 3 days or 1 week.
   - Once a Game Center version is live, open Challenges → … → **Set Challenges Minimum Version** and pick the first version with this feature, so nobody on an older build is invited.
   - Xcode 26 can hold all of this in a GameKit configuration file and sync it to App Store Connect instead. The IDs must stay the same.
8. **Activities (iOS 26, recommended).** An activity takes a player who taps a challenge in the Games app, or its notification, straight to the right screen. Go to Game Center → **Activities** → (+). Enter the reference name and the activity ID, then add an English localization and a 3840 × 2160 image. Under Activity Associations → **Add Association** → Leaderboards, choose the boards below. Leave Supports Party Code off and the participants range empty. Apple allows 20 activities per app, and these use 9.

| Activity ID | Associate these leaderboards | Opens |
|---|---|---|
| `timbre.activity.sniper` | `timbre.sniper.weekly`, `timbre.sniper.best` | Bullseye |
| `timbre.activity.song.<slug>`, one per song above with the same slug (for example `timbre.activity.song.lochlomond`) | `timbre.song.<slug>` | That song |

   Instead of one activity per song, any activity may carry the property `lesson` set to a lesson ID from `GameCenterIDs.songs` (for example `std-loch-lomond`), and the app opens that lesson. Without activities, a challenge still opens Timbre, just not on the right screen.
9. **Test** with a sandbox Apple Account signed in to Game Center on a TestFlight build. On iOS, Settings → Developer → **Notify About Score Submissions** shows each score as it is sent.
   - Open the Practice tab. The welcome banner appears once, and a trophy chip appears on each game card when its board exists. Badges earned before sign-in are reported then.
   - Finish a Bullseye game. "Challenge a friend" on the end screen opens Game Center's challenge screen on iOS 26, or a share sheet with the "Beat my score" card on iOS 18–25 or before the challenge exists. With a challenge going on, "Live challenge" appears under it and opens Game Center's challenges.
   - Play a featured song through at full tempo. The results show "Challenge a friend" beside Share.
   - On Progress, "Your week" offers "Compare streaks with friends" once. After a yes, and with a sandbox friend who also plays and allows it, "Streak #2 of 2 among friends" appears on the card and on its poster.

How the app behaves: it signs in quietly the first time the Practice tab's game cards or Progress's week card show, or when a challenge link opens, and never during onboarding. On iOS 26 it also signs in at launch when the Games app has handed it an activity or challenge. It never shows GameKit's sign-in sheet. When a player isn't signed in, the app isn't recognised yet, or Game Center is restricted, everything stays hidden, and "Challenge a friend" falls back to its link. Game Center's own achievement banner is off, because the app announces badges itself. Scores go to Game Center only when a game or take ends, because each submission counts as a try in a challenge. While a song challenge is going on, stopping a take part-way counts as a try, with the points so far. A best set while signed out is sent once at the next sign-in. Friends' streaks are read only after the player says yes, stay in memory, and are dropped if the player later says no. The card and poster show a rank and a count, never a friend's name.

### 6.2 "Beat my score" challenge links

The paper-plane chip on the Bullseye card, and "Challenge a friend" wherever Game Center's own challenge isn't available, share a "Beat my score" card. For Bullseye it comes with the link `timbre://challenge?game=sniper&score=N`, which opens Bullseye with that score to beat. A player who beats it gets "Send it back" on the results screen. For a song it comes with `timbre://lesson?id=<lesson>`, which opens the song (the score to beat is in the message), on any song played through at full tempo, featured or not.

- A `timbre://` link only works where Timbre is installed, and some apps don't make custom-scheme links tappable. Every share therefore carries an https link as well (`ShareDestination`): the share page (`TIMBRE_SHARE_URL`, §5) with the route as its path, else the App Store page (`TIMBRE_APP_STORE_ID`, §5). Set the Apple ID as soon as the app record exists.
- The share page is a small https page that forwards to the `timbre://` link and falls back to the App Store. Opening it as a Universal Link (straight into the app) would also need an Associated Domains entitlement and an `apple-app-site-association` file on that domain.

### 6.3 Offer codes ("Redeem code" on the paywall)

App Store Connect → the app → Subscriptions → Timbre Pro → the plan → **Offer Codes** → create a campaign: one-time-use codes or a custom code, the offer (free or discounted months), eligibility and dates. The paywall's "Have an offer code? Redeem code" link opens Apple's own redemption sheet, and the code unlocks Pro through the usual transaction. The App Store also accepts codes outside the app (App Store → account → Redeem Gift Card or Code). Nothing in the app needs to change per campaign.

### 6.4 The paywall's one-time exit offer

The second time anyone turns a paywall down (onboarding's paywall counts as the first), the paywall makes one offer, once per install. It only uses offers that exist in App Store Connect, at Apple's prices; the app never invents a discount. If nothing below is set up, the paywall simply closes.

1. **Lapsed subscribers.** Under App Store Connect → Subscriptions → Timbre Pro → each plan → **Win-Back Offers**, create one or more offers (for example 1 month free, for people whose subscription ended 1–6 months ago). The app offers the best one the App Store lists for the person (`eligibleWinBackOfferIDs`) and buys it with that offer applied. StoreKit may also show Apple's own win-back sheet at launch to eligible people. That needs no code.
2. **Never subscribed.** The current build's paywall discloses a monthly trial everywhere it shows the Monthly plan (its own "7 days free", button, terms line and trial reminder), so you may give `timbre_pro_monthly` an **Introductory Offer** (for example a 1-week free trial for new subscribers). Introductory-offer eligibility covers the whole group, so someone who already used the yearly trial isn't offered it. The card shows the offer as Apple holds it ("Try Pro free for 7 days"), then the monthly price and how it renews. The recommendation is still to leave the monthly plan without one and use win-back offers and offer codes (§6.3).
3. To test locally, add an introductory offer to the monthly plan in `ios/Tests/Fixtures/Timbre.storekit` (in a scratch copy, not the committed fixture the UI tests use). Turn down the paywall twice. The exit offer never shows under the UI tests or the demo modes.


## 7. Apple Watch companion: owner steps

The iPhone build carries a watch app (`ios/TimbreWatch`, watchOS 11 or later) and its complications (`ios/TimbreWatchWidgets`). They install with the iPhone app and are submitted with it. There is no separate App Store Connect record and nothing extra to buy. Every iOS build in CI also builds the watch app (for the watch simulator, or for watchOS when archiving); the macos-15 runner's Xcode 26.3 has the watchOS 26.2 SDK and simulator.

- **Wrist metronome.** Haptic taps, strong on the downbeat and light on the other beats. 30–240 BPM on the Digital Crown or by Tap, in 2/4 to 7/4. It starts at the iPhone metronome's tempo until the player sets their own.
- **Today.** The streak flame inside today's set ring, then the set, the open quest and the next lesson, as the iPhone last sent them. After midnight the flame goes out and the ring clears.
- **Start today's practice.** If Timbre is on the iPhone's screen, Today opens on the Practice tab. If it isn't, the watch offers Handoff: Timbre appears in the iPhone's App Switcher and opens on Today. Opening Timbre within ten minutes also lands on Today. watchOS can't bring an iPhone app to the front by itself.
- **Complications.** Circular (the set ring around the flame and count), rectangular (also in the Smart Stack), corner and inline.

### 7.1 Signing: the two new bundle IDs

On its first run, the delivery workflow's automatic signing (`-allowProvisioningUpdates`) does the following:

- Registers `com.shahradazerisharghi.timbre.watchkitapp` and `com.shahradazerisharghi.timbre.watchkitapp.widgets`.
- Turns on App Groups for them, with `group.com.shahradazerisharghi.timbre`.
- Makes their App Store profiles.

The API key must be allowed to create identifiers and profiles. The **Admin** key from section 3 can. A key with a narrower role fails with "No profiles for 'com.shahradazerisharghi.timbre.watchkitapp' were found". In that case, switch to an Admin key, or register the IDs by hand and run the workflow again:

1. Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → App. Enter the explicit bundle ID `com.shahradazerisharghi.timbre.watchkitapp` and tick the **App Groups** capability. Do the same for `com.shahradazerisharghi.timbre.watchkitapp.widgets`.
2. Open each one, then App Groups → Configure, and tick `group.com.shahradazerisharghi.timbre`.

Handoff and WatchConnectivity need no capability. The watch app's version and build always match the iPhone app's, because `project.yml` gives every bundle the workflow's version and build number. App Store Connect rejects a watch app whose numbers differ.

### 7.2 App Store Connect

- **Apple Watch screenshots are required.** Once a build with the watch app has processed, the version page gets an Apple Watch section, and it can't be submitted without them. Pick one size and use it for every localization:

  | Size (pixels) | Watches |
  |---|---|
  | 422 × 514 | Ultra 3/4 |
  | 410 × 502 | Ultra and Ultra 2 |
  | 416 × 496 | Series 10–12 |
  | 396 × 484 | Series 7–9 |
  | 368 × 448 | Series 4–6, SE |
  | 312 × 390 | Series 3 and earlier |

  To take them on a simulator, run the **TimbreWatch** scheme on an Apple Watch simulator paired with an iPhone one, then use File → Save Screen. To take them on a watch, turn on Watch app → General → Enable Screenshots, then press the side button and the Digital Crown together. Suggested frames:
  - the metronome mid-bar;
  - Today with a lit flame and a part-done ring;
  - a face with the circular and rectangular complications.
- **App Privacy:** the watch's streak/Today synchronization uses WatchConnectivity between the player's devices. It does not remove the iPhone app's configured analytics disclosures in §4; review the combined release's actual data flows.
- **Review notes.** Add: "The Apple Watch app is a companion. Its metronome works on its own. The streak and Today come from the iPhone app, so open it once after installing."
- **Icon.** The watch icon is a copy of the iPhone icon (`ios/TimbreWatch/Assets.xcassets/AppIcon.appiconset/icon.png`), which watchOS masks to a circle. Replace it along with the new layered icon. It must stay 1024 × 1024 with no transparency.

### 7.3 Check on a real watch (TestFlight)

The simulator plays no haptics and has no Handoff. Check these on hardware:

1. **Install.** The watch app arrives with the TestFlight build. If it doesn't, open the Watch app on the iPhone and go to Available Apps → Install.
2. **Feel.** Try 60, 120 and 200 BPM, and 240 for distinct taps. The downbeat must stand out in 3/4 and 7/4. Check the crown detents and Tap. With Silent Mode off, watchOS plays each haptic's sound as well, so turn Silent Mode on for taps alone.
3. **Wrist down.** Taps pause, because watchOS plays haptics only for the app on screen and awake. They resume in the bar when the wrist comes up. Leaving the app stops the beat.
4. **Sync.** Practise on the iPhone. Today updates while open, and the complication redraws shortly after.
5. **Start today's practice.** Check all three cases:
   - Timbre open on the iPhone: Today opens.
   - iPhone locked: the watch says "Open Timbre on your iPhone", and the App Switcher offers Timbre from the watch. Handoff must be on in iPhone Settings → General → AirPlay & Continuity, and in the Watch app → General.
   - Timbre opened within ten minutes: lands on Today.
6. **Midnight.** The flame goes out and the ring empties without opening anything.

### 7.4 Why the metronome stops tapping with the screen off

watchOS keeps an app running with the screen off only in a workout, an audio session or an extended runtime session. The extended runtime types are self care, mindfulness, physical therapy and smart alarm. Apple asks that the type match the app's purpose, and a practice metronome is none of these, so Timbre doesn't start one. The beat holds its place in the bar while the wrist is down. To keep Timbre as the app that comes back during practice, set the watch's Settings → General → Return to Clock to **After 1 hour**, or customize it for Timbre there.

## 8. Your songs and Apple Music (MusicKit): owner steps

"Your songs" on the Songs tab is the licensing-safe way to play real songs: **the player brings the chart and the recording, and Timbre ships neither.** Charts come from Files (ChordPro `.cho`, `.chordpro`, `.chopro`, `.crd`, or text with the chords over the words), the clipboard, another app's share sheet ("Open in Timbre") or the in-app editor. Recordings are the player's own audio files. Everything stays on the device, in the app's Application Support folder; nothing is uploaded or synced. See [SONG-LICENSING-PLAYBOOK.md](../content/SONG-LICENSING-PLAYBOOK.md), sections 2 and "Next 30 days".

| | Free | Timbre Pro |
|---|---|---|
| Charts kept (`YourSongsPolicy.freeChartLimit`) | 10 (charts already saved always open, play and edit) | Unlimited |
| Song sheet: transpose, capo (and the easiest capo on guitar), chord boxes, auto-scroll, Practice | Yes | Yes |
| Your own recording: play along, tap-along sync, the chart following it | Yes | Yes |
| Your own recording: slow down (pitch kept), A–B loop, detect the chords (draft chart) | — | Yes |
| Listen on Apple Music | Yes | Yes (never behind the paywall) |

### 8.1 What Apple Music does, and what it deliberately doesn't

Apple's MusicKit terms and App Review Guideline 4.5.2 allow a **user-started, unmodified, free** player and nothing timed to it. So, in code (`ios/Timbre/YourSongs/AppleMusicListen.swift`):

- The song view has a plain "Listen on Apple Music" card: the player searches the catalog, picks the song, and plays, pauses or restarts it in Apple's own `ApplicationMusicPlayer`. Playback starts only from their tap. The artwork appears only on that player and in the search results.
- It is free on every plan: `YourSongsPolicy.canListenOnAppleMusic` is always true and no Apple Music control shows a Pro badge.
- Nothing is synchronised with the track. The chart's auto-scroll and its following of a recording run on their own clocks (`ChartFollower`), which never read Apple Music's position. An Apple Music link (`SongRecording` of kind `.appleMusic`) can't hold chord timings (the model drops them).
- The track is never modified: no loop, no slow-down, no pitch change (`playbackRate` is never set).
- Its audio is DRM-protected and plays outside the app's audio graph, so it is never analysed. Chord detection works only on the player's own files.

Get Apple's written answer before adding anything beyond this (playbook section 2).

### 8.2 Turn on MusicKit for the App ID

1. Certificates, Identifiers & Profiles → Identifiers → `com.shahradazerisharghi.timbre` → **App Services** tab → tick **MusicKit** → Save. That's all: MusicKit on iOS mints its developer token automatically for an App ID with the service on. There is no key to download, no entitlement to add to `project.yml`, and the provisioning profile doesn't change.
2. The Apple Music permission prompt uses `NSAppleMusicUsageDescription` (already in `project.yml`): "Timbre plays the Apple Music songs you choose, so you can listen to them beside your own chord charts." Add its translation to each `InfoPlist.strings` with the next localisation pass.
3. Until the service is on (and in the simulator without an Apple Music account), the card says "Apple Music isn't available in this version of Timbre" (`MusicTokenRequestError.developerTokenRequestFailed`). Nothing else in Your songs depends on it, nothing crashes, and no prompt appears until the player taps "Find this song on Apple Music".

### 8.3 Charts from other apps ("Open in Timbre")

`project.yml` declares the ChordPro type as an imported type (`org.chordpro.chordpro`, extensions `cho`, `chordpro`, `chopro`, `crd`, conforming to plain text) and two document types, ChordPro and plain text, both as Viewer with handler rank Alternate, with `LSSupportsOpeningDocumentsInPlace` set to false. The system hands Timbre a copy of the file (in Documents/Inbox). Timbre imports it as a chart, deletes the copy, and opens it on the Songs tab. On the free plan with ten charts already saved (`FreeTier`), it opens the paywall instead. PDFs aren't accepted: a chart must be text.

### 8.4 App Store Connect

- **App Privacy:** imported audio and full chart text stay local. A user-initiated Apple Music search can send the selected title and artist, further queries, catalog lookups and playback requests to Apple through MusicKit. This feature does not remove the configured analytics disclosures in §4. The [privacy policy](PRIVACY.md) describes these separate flows.
- **Review notes.** Add: "Your songs (Songs tab → Add a song) plays charts and recordings the user supplies; the app includes no copyrighted songs. Listen on Apple Music is a plain player for subscribers, started by the user, free, and not synchronised with anything. To try it, add a song (paste any chord chart), then tap Find this song on Apple Music."
- **Terms.** Add a clause to the Terms that users import only charts and recordings they have the right to use (playbook, "Next 30 days"). The Add a song sheet says the same.

### 8.5 Check on a device (TestFlight)

1. **Import.** Import `.cho` and `.txt` files from Files, including a chord sheet with the chords over the words, and paste one. Check the section names, the chords over the right syllables, and the title. AirDrop or share a `.cho` file to Timbre from another app: the Songs tab opens it.
2. **Free limit.** Without Pro, an eleventh chart opens the paywall from the Songs tab, from the Add sheet and from "Open in Timbre". The first ten still open, edit and play.
3. **Song view.** Transpose up and down: the chord names and boxes follow, and flat keys use flats. Change the capo, and on guitar check the easiest-capo tip (try a chart in B♭). Tap the chord boxes to hear them. Change the text size from the menu.
4. **Auto-scroll.** Check that the tempo buttons scroll at about a bar a chord, the chord lights a beat early, and dragging the sheet pauses the following.
5. **Your recording.** Add an `.m4a` or `.mp3`. Check play, ±5 s and the scrubber. Tap Sync, tap through a verse and tap Done: replay it and the chart follows. With Pro, check Speed at 50% (the pitch stays the same), loop A–B (gapless), and transpose (the recording follows the key). A copy-protected file is refused with a message.
6. **Detect chords (Pro).** Use a recording with a steady beat. It shows the progress, then the tempo, key and first bars. Make the chart: it opens synced to the recording. Analysing a 4-minute song should take seconds, not minutes, on a recent iPhone.
7. **Practice.** Check that each chord step hears a strum, then the progression is strummed in time.
8. **Apple Music**, with a subscriber account: find, play, pause and restart. Without a subscription it says so and offers Try Apple Music. Check that nothing scrolls or lights with Apple Music and that the card has no Pro badge on a free account. Before MusicKit is enabled, check that the card shows the "isn't available" message.
9. **Audio session.** Play your recording, then open Practice. The recording pauses and the microphone works. Back on the song, Play carries on from where it paused. Take a phone call mid-song: playback pauses. Close the song while something plays in another app's background audio: that app can resume.

## 9. App Store Connect growth programme

What the owner sets up in App Store Connect to turn the listing into installs, in the order that pays. Each item says what has to be true in the app first.

### 9.1 Billing Grace Period and Family Sharing

1. **Billing Grace Period** (App Store Connect → the app → Subscriptions → Billing Grace Period: 16 days, all renewals). The current build keeps Pro during grace (its entitlement check trusts `Transaction.currentEntitlements`) and shows a billing-issue banner. Check it on TestFlight with a sandbox account set to fail renewals before turning it on. Without it, a payer whose card fails loses Pro in exactly the window grace is meant to protect.
2. **Family Sharing** on `timbre_pro_annual` and `timbre_plus_lifetime` (each product → Family Sharing). Apple doesn't let it be turned off again for a product, so decide once. Then turn on the paywall's Family Sharing line.

### 9.2 Custom Product Pages

[APP-STORE-LISTING.md](APP-STORE-LISTING.md#custom-product-pages) has each page's keywords, first frames, promotional text, deep link and preview. A page can only be assigned keywords that are in the keyword field of the latest *approved* version, so the order matters:

1. **Ship the keyword field first.** Paste the listing's [keyword field](APP-STORE-LISTING.md#keywords-97100) (and each localization's) into the version and get it approved. It is the pages' inventory: violin, fiddle, ukulele, uke, cello, bass, mandolin, banjo, chromatic, strobe, ear training.
2. Render the page's frames: `python3 tools/marketing/screenshots.py <ci-out/screenshots> <out> --page violin` (and `--page cello`, `--page ukulele`: each has its own table), or the main set with the page's first capture moved to the front for a page without one.
3. For the violin page, use the violin App Preview (the App Preview workflow with `preview: violin`, or `both`).
4. App Store Connect → the app → **Custom Product Pages** → (+). Name it after the instrument; add the promotional text, the frames and the preview.
5. **Keywords**: in the page's Keywords section, select its words from the field (the table's "Keywords from the field" column), per localization from that localization's field. Give each word to one page only. The page becomes searchable for them once it is approved and set to visible.
6. **Deep link** (optional): the page's `timbre://tune?instrument=<id>` link. It runs only when someone on iOS 18 or later taps **Open** on the page, and only after the link is approved; someone who installs and opens Timbre from the Home Screen gets the default welcome. Before onboarding is done, `DeepLink.swift` keeps a `tune` link and onboarding opens with that instrument chosen; after it, the link opens the tuner on that instrument.
7. Submit it for review with (or after) the version.

Measure each page in App Store Connect → Analytics (page views and conversion by product page), and the installs it brought in with TelemetryDeck (onboarding's first instrument). Up to 70 pages are allowed; add bass, mandolin, banjo, voice and ear training once their first frames are store frames (a `storeFrame` check in the UI tests and a table in the listing).

### 9.3 In-App Events

App Store Connect → the app → **In-App Events** → (+). An event card needs a name (30 characters), a short description (50), a long description (120), a badge, a deep link, the event's start and end, and two pictures: the card (1920×1080) and the details page (1080×1920), with no text over the safe areas. Publish an event up to 14 days before it starts so it can be promoted.

| Event | Badge | When | Deep link | Short description |
|---|---|---|---|---|
| Holiday carols | Special Event | December 1–31, every year | `timbre://songs` | Play the carols, with the band |
| 30-day ukulele challenge | Challenge | January (and any month the ukulele page is pushed) | `timbre://tune?instrument=ukulele.soprano.4` | A song a day on your ukulele |
| This week's song | New Season | weekly, once "This week's song" ships | `timbre://songs` | A new Original, a new leaderboard |

The carols are in Standards and the ukulele songbook already; check the free ones before promising "free".

### 9.4 Product Page Optimization

App Store Connect → the app → **Product Page Optimization** → (+). Up to three treatments against the original page, for up to 90 days; apply the winner only at 90 % confidence or better. Tests in order:

1. **The first frame**: "Free tuner. No ads." (the original) against the highway first ("Hear exactly how you played"). This decides whether the tuner or the lessons lead.
2. **The preview's poster**: the lock (the original) against the highway at ×4.
3. **The icon**, once the icon designer delivers alternates (they ship in the build as alternate icons first).

Run one test at a time, and not while a Custom Product Page for the same audience is being changed.

### 9.5 Featuring Nomination

App Store Connect → **Featuring** → Nominations → (+), "New app launch", at least three weeks before the launch date (six for a holiday window). The story: the tuner you can feel stand still (Tune by feel: the phone pulses with the beat between string and note and goes still at the lock), lessons that hear every strum and name the string that didn't ring, 60 instruments with violin and cello lessons nobody else teaches, and a tuner that works with VoiceOver. Attach the App Preview and a TestFlight link. Nominate again for each major update (the band on speaker, the songbooks).

### 9.6 Accessibility Nutrition Labels

App Store Connect → the app → **Accessibility** → per device. What to declare, and when, is in [APP-STORE-LISTING.md](APP-STORE-LISTING.md#accessibility-nutrition-labels): Dark Interface, Differentiate Without Color Alone, Sufficient Contrast and Reduced Motion now; Larger Text once the accessibility-size captures pass; **VoiceOver only after** the lessons' notes step speaks the next note, the play-along's cues land before their notes, and blind testers have finished Unit 1. App Review can ask for corrections (Guideline 2.3), so declare a feature only when a person can do the app's common tasks with it. None of the six competitors fills these in, so an honest, filled label is a free difference.

### 9.7 Apple Ads

Not before the funnel measures revenue per install (§5). Then exact-match instrument keywords ("violin tuner", "learn violin", "cello tuner", "ukulele songs"), each ad group pointing at its Custom Product Page, at about $1.5–3k a month, and stop any keyword whose cost per install exceeds the install's measured first-year revenue.

Name each instrument's ad groups so they map to one instrument, and keep that map (ad group ID → catalog id, e.g. `violin.standard.4`) in the remote settings file: the `attribution` event names the ad group within seconds of the first launch, which is how an install from an ad can open on its instrument when the page's deep link didn't run (it runs only on "Open"). Onboarding needs a small change to read that map; until then it asks.

