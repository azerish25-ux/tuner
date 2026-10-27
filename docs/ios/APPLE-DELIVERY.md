# Timbre for iOS — Apple delivery handoff

Reconciled 27 October 2026 against the cloud checkout. This is an operational plan, **not evidence of an Apple account configuration, signed build, upload, approval or submission**. Portal state, live prices, agreements, tax/banking, membership and signing permissions remain unverified.

## Release scope and authority

- Continue on `codex/app-store-readiness-gates`, [draft PR #3](https://github.com/azerish25-ux/tuner/pull/3), from the `50e2ce8` handoff lineage. Record the full current SHA before running anything. `main` is protected; merge only through its required up-to-date `gate`, never a bypass.
- **Initial submission: polished screenshots only; no App Preview uploads.** The owner delegated this choice. This does not remove any app feature. Earlier failed movies remain failed; the prepared-audio draft remains unapplied. Apple confirms [app previews are optional](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications).
- **Game Center stays disabled**, as already configured by `TIMBRE_GAME_CENTER_ENABLED=NO`; no Game Center entitlement is present. This is existing release scope, not a new feature deletion.
- **Physical-device QA is owner-waived and unverified**, because hardware testing is unavailable. The waiver covers only the repository's physical-device QA gate. It does not certify audio, routes, haptics, Watch or physical accessibility behavior; it does not waive native simulator tests, privacy, commerce/account evidence or Apple requirements.
- The machine-readable [release applicability policy](readiness/RELEASE-APPLICABILITY.md) binds these dispositions to source hashes. Never replace missing evidence with invented `verified` flags or refresh hashes solely to silence validation.
- Free cloud preparation does not authorize paid enrollment, contractual/financial decisions, persistent credentials, signing/upload or submission. Those remain owner/action-time gates. Keep credentials out of chat, source, issues and logs.

Earlier schedules, pricing/conversion projections and historical review instructions are superseded, not recorded as completed. Git history and [review receipts](readiness/reviews/) retain that history. Use the [release checklist](RELEASE-CHECKLIST.md) for execution and exact-source receipts rather than extrapolating old passes.

## Identity

| Field | Release configuration |
|---|---|
| App | Timbre |
| Main bundle | `com.shahradazerisharghi.timbre` |
| iOS widgets | `com.shahradazerisharghi.timbre.widgets` |
| Watch app | `com.shahradazerisharghi.timbre.watchkitapp` |
| Watch complications | `com.shahradazerisharghi.timbre.watchkitapp.widgets` |
| App Group | `group.com.shahradazerisharghi.timbre` |
| Minimum OS | iOS 18.0; watchOS 11.0 |
| Privacy | https://timbre-support.timbre.workers.dev/privacy |
| Support | https://timbre-support.timbre.workers.dev/support |
| Terms | [Apple standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) |

`ios/project.yml` is authoritative; generated projects are not. Its default marketing version is `1.0.0`, while the delivery workflow suggests `2.0.0`: **choose the actual version from the app record**, do not assume either is the next portal version. Choose a unique positive build number; the workflow stamps all four bundles consistently.

## 1. App Store Connect app

Owner/account administrator, at action time:

1. Verify active Apple Developer Program membership and the intended legal entity/team. Do not enroll or renew a paid membership without authorization.
2. Have the Account Holder review applicable agreements. Apple requires the current Paid Apps Agreement for paid apps and IAP; complete the applicable tax and banking steps and verify their portal status, without placing private financial records in this repository. See [agreements](https://developer.apple.com/support/terms), [payment prerequisites](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments) and [role permissions](https://developer.apple.com/help/app-store-connect/reference/account-management/role-permissions/).
3. Verify/register the four explicit bundle IDs and their App Group associations. Verify MusicKit for the main App ID (§8); do not enable Game Center for this release. Source configuration does not establish portal capabilities or provisioned entitlements.
4. Create or inspect the iOS app record for the main bundle. Confirm name, primary language, private SKU, Apple ID, content rights, territories, trader status and any territory-specific requirements. Do not invent an Apple ID or assert a name is available.
5. Supply owner-approved contact/review information. Enter private contact details directly into Apple, not public notes.

Small Business Program enrollment is an **optional separate eligibility decision**, not an assumed commission rate or release prerequisite. Review Apple's [current program terms](https://developer.apple.com/app-store/small-business-program/) before applying.

## 2. In-app purchases (exact identifiers — the app looks these up)

| Product ID | Type | Duration / group |
|---|---|---|
| `timbre_pro_annual` | Auto-renewable subscription | 1 year; Timbre Pro |
| `timbre_pro_monthly` | Auto-renewable subscription | 1 month; Timbre Pro |
| `timbre_plus_lifetime` | Non-consumable | Lifetime entitlement |

Create/verify the **Timbre Pro** group and equivalent subscription levels for the two plans. Preserve existing product identities and entitlement compatibility. The owner decides actual prices, storefront availability and introductory offers; `ios/Tests/Fixtures/Timbre.storekit` contains **test data, not live prices or a launch recommendation**. The UI must show StoreKit's actual localized price, renewal period and eligible offer.

Prepare localized names/descriptions, product review screenshots and review notes explaining where the paywall is reached. Verify product loading, purchase, cancellation, pending purchase, restore, revocation/refund and subscription state with the configured sandbox/StoreKit evidence; local fixtures alone do not verify portal products. Attach first IAP/subscription submissions to the appropriate app version under Apple's [submission instructions](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase).

**Family Sharing is an owner decision, not an instruction to enable it.** Apple says it [cannot be turned off for a product once enabled](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases). Do not make that irreversible change without specific approval; show claims only after configuration and behavior are verified.

Optional price-test IDs `timbre_pro_annual_b` and `timbre_pro_annual_c`, offer codes, win-back offers and grace-period experiments are not initial-release requirements. Do not create them or change live prices merely because code supports them. No revenue or conversion outcome is promised.

## 3. Signing and upload from GitHub Actions

The [Apple delivery workflow](../../.github/workflows/apple-delivery.yml) is manual and guarded. It uses macOS 15 / Xcode 26.3 and automatic signing with `-allowProvisioningUpdates`; success depends on actual account permissions and capabilities. Automatic signing is **not proof that identifiers/profiles already exist or can be created**.

Before obtaining a key, verify the least privileges sufficient for the intended provisioning/upload operations using Apple's [API key guidance](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api) and role matrix. Key generation is persistent access and requires explicit authorization. Do not automatically create or escalate an Admin key to fix a failure.

Configure the protected `apple-delivery` GitHub environment, restricted to the approved delivery branch with owner approval before jobs receive secrets. Verify the repository's available environment protections; do not assume reviewer rules exist. Enter these through provider secret fields only:

| Environment secret | Expected value |
|---|---|
| `APPLE_TEAM_ID` | 10-character team ID |
| `APP_STORE_CONNECT_KEY_ID` | 10-character key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID |
| `APP_STORE_CONNECT_API_KEY_P8` | Raw PEM private key, not Base64 |

The job writes the private key to a restricted temporary directory and removes it at job end. Revoke an exposed key through Apple; never paste it into a diagnosis.

### Preconditions and dispatch

1. Merge reviewed work through a green PR gate. On **the exact current `main` SHA**, require the latest push-triggered `ios.yml` run and all `core`, `app`, `release`, `accessibility`, `gate` jobs to succeed. A historical or branch-only success is insufficient.
2. Run `python3 tools/l10n/store.py --release` and resolve real missing content/media/applicability evidence. Keep draft `release_ready` flags false until their criteria genuinely hold. Delivery's `apple_delivery_preflight.py` enforces exact-main/native/release evidence before signing.
3. Obtain explicit owner authorization for the revision, version, build number and signing/upload destination. Only then dispatch **Apple delivery** on `main` with `confirm_delivery=true`.
4. Leave `internal_testflight_untranslated=false` for a submission build. The internal-only mode stamps `TimbreBuildChannel=internal` and exports with `testFlightInternalTestingOnly`; it cannot become an App Store/external-test build. This mode does not bypass the workflow's exact-source preflight.
5. Keep `ship_min_coverage` empty for the committed language scope unless a separate scope change is approved. Selecting fewer languages does **not** waive the complete-interface/all-language lesson checks.
6. The workflow tests core/resources, exports authoritative English localization keys, checks translations, archives all targets and calls `apple_archive_scope.py` before export/upload. Inspect signed entitlements, Info.plists, embedded bundles, version/build consistency and privacy report. Do not interpret this scoped archive check as full Apple validation.
7. Preserve non-secret run/source/build receipts. An accepted upload is not processed/available/approved: inspect App Store Connect processing, warnings and TestFlight availability separately. Submission and public release require their own authorization.

## 4. Listing

- Candidate categories: Music / Education, subject to owner confirmation. Answer the current age-rating, content-rights and export-compliance questions for the final build. `ITSAppUsesNonExemptEncryption=false` is source configuration, not a substitute for reviewing actual dependencies and Apple's questionnaire.
- Use reviewed [English](APP-STORE-LISTING.md) and [localized](APP-STORE-LISTING-LOCALIZED.md) text only when it matches the shipping build. Keep all 50 listing payloads and the 49-app-language mapping, including documented listing-only fallbacks.
- Produce separate native medium Dynamic Island iPhone **1206×2622**, large Dynamic Island iPhone **1320×2868**, and 13-inch iPad landscape **2752×2064** captures, with matching source/build hashes, manifests and actual-language evidence. Do not substitute or stretch one role into another. The phone roles share captions but require separate images: **9 + 9 + 4 = 22 frames per locale**. Full scope: **150 sets / 75 two-locale shards / 1,100 JPEGs**; three-locale pilot: **9 sets / 6 shards / 66 images**. These are plans; large-role native captures and every final frame/macOS composition still need acceptance. Upload to matching portal slots after checking [current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications): large Face ID screenshots are conditionally required when large Dynamic Island screenshots are absent; this release selects the latter alongside its medium and iPad sets.
- Include the Watch screenshots (§7). **Do not upload previews** in this initial scope; old failed previews must not be relabeled approved.
- Review final App Privacy answers against all active services (§5; [checklist H6](RELEASE-CHECKLIST.md#h6-app-privacy)). Privacy and support URLs must work publicly and match the signed build.
- Accessibility labels are separate from mandatory repository accessibility QA. Declare only features supported by evidence for all common tasks on each device, not blanket Yes values based on design intent. Apple's [label guidance](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/) currently describes voluntary introduction; recheck requirements at submission. The hardware waiver provides no positive label evidence.

## 5. Analytics, links and remote settings

| Repository variable | Build setting | Effect / decision |
|---|---|---|
| `TELEMETRYDECK_APP_ID` | `TIMBRE_TELEMETRY_APP_ID` | Optional TelemetryDeck transport when usage sharing is enabled; absent disables this transport, attribution HTTP and song-request submission |
| `TIMBRE_APP_STORE_ID` | Same | Real numeric Apple ID for store/share/offer links; verify after app record creation |
| `TIMBRE_SHARE_URL` | Same | Optional HTTPS share landing page; absent falls back to App Store link when its ID is configured |
| `TIMBRE_REMOTE_CONFIG_URL` | Same | Optional HTTPS remote settings; absent uses built-in defaults |
| Not a workflow variable | `TIMBRE_PRIVACY_POLICY_URL` | Committed published privacy URL in `ios/project.yml`; changing it needs source review |

The workflow passes its four listed repository variables into the archive. Do not assume a new variable or Game Center override is supported. Review both final build settings and the archive.

**No TelemetryDeck ID does not mean no networking.** Remote settings, Apple's rating lookup, StoreKit, user-chosen Apple Music and support email have separate flows. With analytics enabled, inspect product interactions, hashed install/session identifiers, purchase information, MetricKit diagnostics, allowlisted attribution and user-entered song requests. The [policy](PRIVACY.md) describes consent revocation, cancellation limits and the separate services; compare it with `Analytics.swift`, `AnalyticsTransport.swift`, `RemoteConfig.swift`, `StoreRating.swift`, `ShareDestination.swift` and the archive manifest. Never infer “Data Not Collected” from a single empty setting.

Remote configuration is optional operational infrastructure, not a prerequisite or authorization to deploy another service. If chosen, verify `RemoteConfig.swift`'s schema, HTTPS, cache/failure handling and payload bounds. Review paywall `annualProductId` against live approved products, and `referralCode` against a real offer before publishing. Time-limited `freeSongsWindow` uses local Gregorian dates with inclusive start/exclusive end; do not reuse historical event dates. Preserve the fallback behavior and test changes before enabling experiments.

## 6. Growth features: optional, not initial-release blockers

### 6.1 Game Center

No account setup is required under the current source-bound disabled policy. For a separately authorized future enablement: restore required account evidence, configure capabilities/records/assets, add the reviewed entitlement and feature switch, review permission translations/privacy/metadata, and verify signed configuration and behavior. Portal records alone do not enable source. Friend access additionally requires the appropriate `NSGKFriendListUsageDescription`; do not claim it exists in this release.

Canonical IDs are in `ios/Timbre/Services/GameCenterIDs.swift`. The retained inventory below is for future reconciliation, **not evidence that any record exists or is approved**. Recheck Apple's current Game Center configuration requirements before executing that work.

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

| Activity ID | Associate these leaderboards | Opens |
|---|---|---|
| `timbre.activity.sniper` | `timbre.sniper.weekly`, `timbre.sniper.best` | Bullseye |
| `timbre.activity.song.<slug>`, one per song above with the same slug (for example `timbre.activity.song.lochlomond`) | `timbre.song.<slug>` | That song |

### 6.2 Share links and offers

`ShareDestination` uses `TIMBRE_SHARE_URL`, then the App Store URL if configured. Custom routes such as `timbre://challenge?game=sniper&score=N` and `timbre://lesson?id=<lesson>` are not a verified Universal Links deployment; that would additionally need Associated Domains and a hosted association file.

Offer codes, referrals, win-back and introductory offers require real products, eligibility and owner-approved commercial terms. The app's support for them does not establish portal configuration. Keep optional annual test products in the same group if later chosen; verify fallback to the standard annual plan. Billing Grace Period is likewise a separate decision to test in sandbox before enabling in production.

## 7. Apple Watch companion: owner steps

The iPhone app embeds `TimbreWatch` and `TimbreWatchWidgets`, using the IDs above and the same version/build. Verify all four bundles' signing and App Group configuration; do not assume an API key can provision every target. The Watch uses its own on-device App Group container and WatchConnectivity snapshots, not a shared cross-device filesystem.

Apple requires Watch screenshots for a Watch app and the same size across localizations. The archived [Watch bundle](readiness/handoff-assets/watch-store-assets-d292f88.zip) contains two **416×496** native frames per 50 listing folders, from 98 original captures across 49 app languages. Its bounded visual/integrity acceptance does not prove Watch hardware behavior or a complete phone/tablet media set. Check the [manifest](readiness/handoff-assets/manifest.json) and source compatibility before reuse.

Review notes should explain the companion relationship and opening the iPhone app to populate Today. Haptics, screen-off behavior, real installation, synchronization, Handoff and complications on hardware remain **owner-waived / unverified**. Do not describe a simulator pass as those tests. Keep [AUDIO-DEVICE-TESTS.md](AUDIO-DEVICE-TESTS.md) for future hardware work.

## 8. Your songs and Apple Music (MusicKit): owner steps

The shipped Your songs feature remains in scope. Imported audio and full chart text are local; selected title/artist metadata, searches and playback requests can go to Apple through MusicKit. The app includes `NSAppleMusicUsageDescription`; final localized permission coverage still needs exact-build checks.

For the existing optional Apple Music player, verify **MusicKit App Service** on the explicit main App ID in the developer portal. Apple's [automatic token documentation](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api) describes automatic token generation for that service; do not create a separate persistent music key by default. Portal enablement is unverified here.

Review `ios/Timbre/YourSongs/AppleMusicListen.swift`: user-initiated playback, subscription/authorization and unavailable-service handling, no paid gating of Apple Music controls, and no assumption that imported files or full chart text are uploaded. Keep licensing/provenance evidence in [the song licensing playbook](../content/SONG-LICENSING-PLAYBOOK.md). Do not claim all bundled material is copyright-free or that source review establishes legal clearance. Test import, playback and UI using cloud-capable scopes; real Apple Music playback/audio-session behavior remains unverified under the hardware waiver.

## 9. Optional post-readiness work

Small Business Program, Family Sharing, Billing Grace Period, alternative prices/trials, referral codes, custom product pages, In-App Events, product-page experiments, featuring and Apple Ads are **separate decisions**, not tasks that must be completed to ship the chosen base release. Revisit current Apple requirements when one is approved. No historical holiday schedule, campaign budget, conversion estimate or revenue target is a delivery commitment. Paid advertising requires explicit budget authorization. No account, key, remote service or campaign is created by this document.
