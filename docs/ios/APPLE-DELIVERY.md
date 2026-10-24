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

The paywall shows the yearly plan's weekly cost ("$0.67 a week"), worked out from the yearly price Apple returns, so it always matches the storefront. The paywall's offer codes and its one-time exit offer are set up in [section 6](#6-growth-features-owner-steps).

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

4. Run **Actions → Apple delivery → Run workflow** on `main` with a version (2.0.0), a new build number, and the confirmation box ticked. It runs the core tests, archives the Release build, signs it and uploads it to App Store Connect, where it appears under TestFlight after processing. The version and build number go into every bundle (app, widgets, watch app, complications); App Store Connect refuses a build number it has already seen for that version.

## 4. Listing

- Category: Music. Secondary: Education.
- Age rating: 4+.
- App Privacy: **Data Not Collected** matches this version (pitch analysis and history stay on the device, no analytics SDK, no ads). Revisit if analytics or a paywall service is added. Game Center (section 6) does not change this: scores and achievements go to Apple's Game Center under the player's own Game Center account, and the app keeps no player ID, name or friend list.
- Encryption: the app uses only Apple's standard encryption (`ITSAppUsesNonExemptEncryption = false`).
- Screenshots: the CI tour produces 6.9" iPhone and 13" iPad captures (`ci-results/app`, `ci-results/ipad`) as a starting point.
- Subscription disclosures are on the paywall (price, period, auto-renewal, cancel in Settings, Terms and Privacy links), as App Review Guideline 3.1.2 requires.

## 5. Analytics (optional, off until you switch it on)

Timbre can send anonymous product events (onboarding finished, paywall shown, trial started, lesson done, streaks) to [TelemetryDeck](https://telemetrydeck.com), which is privacy-first: no IDFA, no personal data, and a random install ID hashed on the device. With no app ID, nothing leaves the device.

1. Create a TelemetryDeck app and copy its App ID.
2. GitHub → repository Settings → Secrets and variables → Actions → **Variables** → add `TELEMETRYDECK_APP_ID`. Delivery builds pick it up and debug builds stay in test mode.
3. Before submitting, update the App Privacy label in App Store Connect to "Product Interaction → Analytics, not linked to the user, not used for tracking" (the app's privacy manifest already declares this), and update the "Analytics and advertising" section of PRIVACY.md.


## 6. Growth features: owner steps

The app ships with all of these switched on in code, and each works as soon as its App Store Connect setup exists. Until then it stays out of sight: no Leaderboard chips, no exit offer, and an offer-code sheet with nothing to redeem. Nothing crashes or prompts. The identifiers below are also in `ios/Timbre/Services/GameCenterIDs.swift`, and they must match exactly.

### 6.1 Game Center

1. **Capability.** Under Certificates, Identifiers & Profiles → Identifiers → `com.shahradazerisharghi.timbre`, check that **Game Center** is ticked. It is on by default for explicit App IDs.
2. **Entitlement.** This is a one-line change to `ios/project.yml`. Under `targets → Timbre → entitlements → properties`, add `com.apple.developer.game-center: true` beside the App Group. The delivery workflow signs automatically, and its Admin API key can update the provisioning profile. The entitlement was left out of the repo on purpose, so CI never signs with a capability the App ID might not have yet. Without it, Game Center may refuse to sign in on TestFlight and App Store builds; the app then carries on without it. Do not add `gamekit` to `UIRequiredDeviceCapabilities`.
3. **Turn on Game Center for the app version.** Go to App Store Connect → the app → Features → **Game Center** → enable it. Then, on the version page, add the leaderboards and achievements below under Game Center.
4. **Leaderboards.** Create all three. Each uses score format **Integer**, submission type **Best score**, and is sorted **High to low**.

| Leaderboard ID | Type | Name (English) | Score range | Notes |
|---|---|---|---|---|
| `timbre.sniper.best` | Classic | Pitch Sniper | 0 – 25,000 | All-time best game |
| `timbre.sniper.weekly` | Recurring | Pitch Sniper this week | 0 – 25,000 | Starts on a Monday at 00:00, lasts 1 week, repeats every week. This is the weekly league; the Leaderboard chip opens it first. |
| `timbre.ear.level` | Classic | Ear trainer level | 1 – 100 | The level the Play tab shows |

5. **Achievements.** Create these 31 achievements, worth 895 points in all (the cap is 1,000). For every one, set Hidden to No and Achievable more than once to No. Add a 1024 × 1024 image. Use the badge's title as the title. Use its detail for both descriptions, before and after it is earned. The per-instrument course badges and the Pro-only badges (custom tuning, Pro-precision locks) are left out on purpose.

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
| `timbre.badge.bullseye` | Bullseye | Hit a bullseye in Pitch Sniper | 5 |
| `timbre.badge.sniper_win` | Marksman | Win a round of Pitch Sniper | 10 |
| `timbre.badge.bullseyes_50` | Dead center | Hit 50 bullseyes | 25 |
| `timbre.badge.sharpshooter` | Sharpshooter | Score 2,000 in Pitch Sniper | 50 |
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

6. **Test** with a sandbox Apple Account signed in to Game Center on a TestFlight build. Open the Play tab. The welcome banner appears once, and a trophy chip appears on each game card when its board exists. Badges earned before sign-in are reported then.

How the app behaves: it signs in quietly the first time the Play tab's game cards show, or when a challenge link opens, and never during onboarding. It never shows GameKit's sign-in sheet. When a player isn't signed in, the app isn't recognised yet, or Game Center is restricted, everything stays hidden. Game Center's own achievement banner is off, because the app announces badges itself.

### 6.2 "Beat my score" challenge links

The paper-plane chip on the Pitch Sniper card shares a "Beat my score" card. It comes with the link `timbre://challenge?game=sniper&score=N`, which opens Pitch Sniper with that score to beat. A player who beats it gets "Send it back" on the results screen.

- A `timbre://` link only works where Timbre is installed, and some apps don't make custom-scheme links tappable. Once the app has an App Store page, set `SniperChallenge.appStoreLink` in `ios/Timbre/Services/GameCenter.swift` to `https://apps.apple.com/app/id<Apple ID>`, so the shared message also says where to get Timbre.
- Optional, later: host a small https page that forwards to the `timbre://` link and falls back to the App Store, and share that page instead. Universal Links would need an Associated Domains entitlement and an `apple-app-site-association` file on a domain you control.

### 6.3 Offer codes ("Redeem code" on the paywall)

App Store Connect → the app → Subscriptions → Timbre Pro → the plan → **Offer Codes** → create a campaign: one-time-use codes or a custom code, the offer (free or discounted months), eligibility and dates. The paywall's "Have an offer code? Redeem code" link opens Apple's own redemption sheet, and the code unlocks Pro through the usual transaction. The App Store also accepts codes outside the app (App Store → account → Redeem Gift Card or Code). Nothing in the app needs to change per campaign.

### 6.4 The paywall's one-time exit offer

The second time anyone turns a paywall down (onboarding's paywall counts as the first), the paywall makes one offer, once per install. It only uses offers that exist in App Store Connect, at Apple's prices; the app never invents a discount. If nothing below is set up, the paywall simply closes.

1. **Lapsed subscribers.** Under App Store Connect → Subscriptions → Timbre Pro → each plan → **Win-Back Offers**, create one or more offers (for example 1 month free, for people whose subscription ended 1–6 months ago). The app offers the best one the App Store lists for the person (`eligibleWinBackOfferIDs`) and buys it with that offer applied. StoreKit may also show Apple's own win-back sheet at launch to eligible people. That needs no code.
2. **Never subscribed.** Give `timbre_pro_monthly` an **Introductory Offer** (for example a 1-week free trial for new subscribers). Introductory-offer eligibility covers the whole group, so someone who already used the yearly trial isn't offered it. The card shows the offer as Apple holds it ("Try Pro free for 7 days"), then the monthly price and how it renews. Leave the monthly plan without an introductory offer to switch this off.
3. To test locally, add an introductory offer to the monthly plan in `ios/Tests/Fixtures/Timbre.storekit` (in a scratch copy, not the committed fixture the UI tests use). Turn down the paywall twice. The exit offer never shows under the UI tests or the demo modes.


## 7. Apple Watch companion: owner steps

The iPhone build carries a watch app (`ios/TimbreWatch`, watchOS 11 or later) and its complications (`ios/TimbreWatchWidgets`). They install with the iPhone app and are submitted with it. There is no separate App Store Connect record and nothing extra to buy.

- **Wrist metronome.** Haptic taps, strong on the downbeat and light on the other beats. 30–240 BPM on the Digital Crown or by Tap, in 2/4 to 7/4. It starts at the iPhone metronome's tempo until the player sets their own.
- **Today.** The streak flame inside today's set ring, then the set, the open quest and the next lesson, as the iPhone last sent them. After midnight the flame goes out and the ring clears.
- **Start today's practice.** If Timbre is on the iPhone's screen, Today opens on the Play tab. If it isn't, the watch offers Handoff: Timbre appears in the iPhone's App Switcher and opens on Today. Opening Timbre within ten minutes also lands on Today. watchOS can't bring an iPhone app to the front by itself.
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
- **App Privacy** is unchanged (Data Not Collected). The watch gets the streak and today's set from the player's own iPhone over WatchConnectivity, and nothing leaves their devices.
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
