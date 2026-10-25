# Jury 16: Growth (App Store editorial and subscription growth)

Juror: App Store editor and subscription-growth lead (music and education apps taken past $1M ARR).
Angle: the listing and Custom Product Pages, the App Preview, the screenshot set, the first-session funnel, the paywall, the free tier, retention, sharing and referral, analytics readiness, and the $10k-a-month model.

Everything below was checked against the round-16 captures (`scratchpad/review16/`), the rendered App Preview (`review16/preview/`), store frames I rendered myself from those captures with `tools/marketing/screenshots.py` (the iPhone set, the violin page and the iPad set, in `scratchpad/growth16/`), the code in `/home/claude/tuner/ios`, and the live App Store pages fetched today (2026-10-25).

---

## 1. Score: 8.1 / 10 (round 15: 7.4)

The team shipped almost every growth item I asked for, and most of it is real.
- **Measurement.** The whole funnel is now in code: `app_open` (cold and warm), every onboarding step, the mic answer, `paywall_view`/`paywall_close` with the test arm (onboarding's paywall included), and `purchase` carrying trial, price and currency. Cancel and fail are logged, `pro_active` is de-duplicated, and AdServices attribution, MetricKit and a remote-config file are wired.
- **Onboarding.** It now sells learning: "Tune in seconds. Then learn to play.", "Play my first songs" as the default goal for beginners, a full-card streak reminder, and a heard E-minor chord before the plan and the paywall.
- **Paywall.** Two plans on onboarding, an honest "140+ songs" proof line, a "paste the chords" outcome, a Family Sharing line driven by StoreKit, and a rating line held to a ≥ 4.6★ / ≥ 200 rule.
- **Free tier.** Every instrument's standard tuning is free.
- **Store.** The screenshots are art-directed, and the App Preview finally has captions and a soundtrack.

It doesn't reach 8.5 because several of these levers are built but don't work, and two money paths are broken:
- **The "first song" promise is missing for every true beginner.** The onboarding paywall can say "Play your first song this week" only when the plan reaches a song by day 7. The plan counts one lesson a day, and every instrument course puts its first song at lesson 9–20, behind the paywall. So beginners on guitar, ukulele, violin, bass, cello, mandolin and banjo all get the generic "Unlock your full plan" (06). (Players placed past unit 1, the "A few months" answer, can still get it.)
- **The App Preview is half silence.** About 13 of its 23 s are silent or near-silent. "Play songs with the band" plays over a bare click track, and the lock is never on camera, although the pipeline's own notes say the poster is "in lock".
- **The price test can't run.** `timbre_pro_annual_b` is never loaded and would never grant Pro. The `unit2Free` flag isn't read anywhere.
- **The Custom Product Page keywords can't be assigned as written.** Apple only lets a page take keywords from the app's keyword field, and the plan's keywords aren't there.
- **The monthly free week isn't disclosed.** The owner is told to give the monthly plan a 7-day intro trial, but the paywall never says so on the Monthly row.
- **Non-English users meet English.** The new onboarding and paywall copy is untranslated, and the translators' table of counts is stale.

Above all, there are still no songs a buyer recognises, and 0 ratings against 22K–400K. As shipped, Timbre has the best-built funnel in the category and the weakest storefront position.

---

## 2. Head-to-head on growth

Live App Store facts were fetched on 2026-10-25 (US storefront). A rating count means the number of ratings.

| Competitor | Live listing today | Who wins on growth | Why, with evidence |
|---|---|---|---|
| **GuitarTuna** (Yousician) | "GuitarTuna: Tune & Play Guitar", subtitle "Chords, Tabs & Lyrics to Songs". 4.8★ from 149K ratings, #21 Music. Tools $29.99/yr, Play $39.99/yr, Learn $139.99/yr. "100 million downloads", "20,000+ songs". Updated 3 days ago. | **GuitarTuna** | It owns "guitar tuner" with social proof that Timbre can't touch for a year, and three tiers capture both tuner buyers and learners. Timbre wins inside the app: the first chord is heard before the paywall (05c), the trial timeline names the reminder and charge days (06), and there's no account. But a 0-rating row next to 4.8★/149K loses the search-results tap. |
| **Fender Tune** | "Fender Tune: Guitar Tuner App", subtitle "Chords, Scales and Metronome". 4.8★ from 152K ratings, #84 Music. Entirely free; 26 tunings; 5,000+ chords; custom tunings saved to a Fender account. Updated 16 hours ago for iOS 27. | **Fender Tune** on tuner installs | "Free tuner. No ads." is a parity claim against Fender Tune, which is free too. Timbre's differences are 60 instruments, the 3D stage and lessons that listen. Only the second screenshot shows the listening; the first is a parity message. |
| **Fender Play** | "Fender Play: Learn Guitar", subtitle "Songs, Scales, Chords & Tabs". 4.8★ from 61K ratings. "1000+ song library", "get 14 days free". Annual $74.99–$149.99 (also $44.99/$89.99 entries); guitar, bass and ukulele. | **Fender Play** | Licensed hits and the brand. Timbre listens as you play and Fender mostly doesn't, but on the store page that is one caption against 1,000 song names. |
| **Yousician** | Subtitle "Guitar, Bass & Singing Lessons". 4.6★ from 139K ratings, #76 Education, Editors' Choice. One Instrument $119.99/yr; Premium+ $159.99–$179.99/yr. Its reviews complain most of level one is locked. | **Yousician** on revenue; **Timbre** on trust | Yousician has the catalogue, Editors' Choice and paid acquisition. Timbre's honest trial timeline, its free standard tuning for 60 instruments and its violin, cello, mandolin and banjo courses answer Yousician's complaints, at a third to a quarter of the price. |
| **Simply Guitar** | Subtitle "Guitar Songs & Lessons". 4.7★ from about 400K ratings, #58 Education. Prices up to $199.99. | **Simply Guitar** | The most social proof in the set and a song-led funnel. Timbre has closed the "play before pay" gap (a heard chord before the paywall), but Simply's first song is one people know, and Timbre's onboarding paywall can't even promise a first song for a beginner (item 1). |
| **JustinGuitar** (Musopia) | Subtitle "Learn Guitar Chords, Simply". 4.9★ from 22K ratings. "Over 1,500 hit songs". Full Access $64.99/yr; Unlimited $99.99–$129.99/yr. | **JustinGuitar** for guitar learners | Justin's face, his free YouTube course and licensed hits. Timbre beats it on the tuner, on instrument breadth and on live feedback. |
| *(Category reference)* **Trala: Learn Violin** | Subtitle "Learn and Play Violin". 4.7★ from 4.9K ratings. $19.99/mo, $119.99/yr. | **Timbre can win this one** | Violin learners already pay $120 a year for one instrument. Timbre now has a violin page set (two violin frames lead it) and a free violin tuner. But the page's keywords can't be assigned as planned (item 2), and the violin App Preview wasn't rendered. The beachhead is ready on paper, not in App Store Connect. |

**What the ordinary user sees today.**
- **Searching "guitar tuner".** The preview autoplays muted with "Free tuner. No ads." over a 3D headstock, which is a good first impression. It sits next to two free 4.8★ apps with about 150K ratings each, so they install those.
- **Searching "learn guitar".** It is Simply, Yousician, Fender Play and Justin, with hundreds of thousands of ratings and songs they know.
- **Searching "violin tuner" or "learn violin".** The competition is weak and Timbre's 3D violin and lessons are better. But Timbre would show its guitar-first default page, because the violin page can't claim "violin" as a keyword (item 2).

Once installed, Timbre's first two minutes beat everyone's. They are measured, in tune, a chord heard and an honest paywall.

---

## 3. Everything that costs points, ranked

### 1. Major, size M: the "first song" promise is never made to a true beginner, and no instrument course has a free song
- **Screens:** 06 (onboarding paywall: "Unlock your full plan", Day 9 "Play 'Ode to Joy'"), 05b, 16.
- **Code and data:**
  - `PaywallView.swift:356`: `guard … let day = plan.songDay, day <= 7 else { return generic }`.
  - `PaywallPlan.swift:105-108`: "One lesson a day from the first one".
  - `curriculum.json`: the first song is lesson 9 on guitar and mandolin (*Ode to Joy*), 15 on bass, 16 on violin, cello and banjo, 19 on voice and 20 on ukulele. Every one of them is Pro.
- **What's wrong:**
  - The headline variant built for the onboarding paywall ("Play your first song this week") never fires for any instrument's true beginner, who is the person the "Play my first songs" goal is the default for (`OnboardingView.swift:176-177`).
  - The plan ignores the minutes the player just chose. At 10 min a day, guitar reaches *Ode to Joy* on day 4 (40 minutes of lessons), not day 9.
  - Every course's free unit 1 ends without a song. The subtitle sells "Learn Songs: Ukulele", but the ukulele course's first chord (C, `uke-2-1`) is in locked unit 2, although onboarding has just had the player strum that same C chord.
  - The free songs exist (Songs, the three songbooks, Originals), but the plan never routes a "songs" goal to them (`AppStore.swift:488-492` maps only the ear, voice and rhythm goals).
- **Fix:**
  - Compute `songDay` from cumulative lesson minutes ÷ daily minutes. Only for goal `songs`, if the course's first song is still past day 7, make the plan's day-1 or day-2 milestone a free songbook song for that instrument (*Mary Had a Little Lamb* / *Jingle Bells* exist free in Songs and every songbook), so the promise is true.
  - Content: give every instrument course a free song as the last lesson of unit 1 (a three-note *Mary Had a Little Lamb* on guitar, mandolin and violin; on ukulele, move "Your first chord: C" plus a one-chord song into unit 1).
  - Then the onboarding headline reads "Play your first song this week" for nearly everyone who chose it. That is the single biggest conversion lever this team can pull without the owner.

### 2. Major, size S: the Custom Product Page keyword plan can't be done in App Store Connect as written
- **Docs:**
  - `APP-STORE-LISTING.md:68-74`: the keyword field is `bass,chromatic,cello,mandolin,banjo,metronome,chord,ear training,practice,tuning,fiddle,pitch,sing`.
  - `APP-STORE-LISTING.md:237`, `:239-250`: the per-page keywords "violin tuner, violin lessons, learn violin, fiddle tuner, violin app", "uke tuner, ukulele songs", "5 string banjo", "bluegrass", "interval trainer", "relative pitch", "vocal range", "chord charts", "songbook", "play along"…
  - `APPLE-DELIVERY.md:358`: "A page's keywords count against no other field".
- **What's wrong:**
  - Apple: "You can assign keywords from your latest approved app version to a custom product page." Pages are assigned keywords from the 100-character keyword field. They don't get new ones.
  - About 40 of the planned page keywords aren't in the field.
  - "violin" and "ukulele" sit only in the subtitle. Apple's help page doesn't say subtitle words can be picked, so as far as Apple documents it, the violin page, the flagship, has no keyword it can claim.
  - The doc also says "Keywords may repeat across pages"; Apple's tip is to give each page a unique set.
  - The page's deep link (`timbre://tune?instrument=…`) only runs when someone taps **Open** on the page (iOS 18 or later), as Apple's help and Apple's forum answer say. A newcomer who opens the app from the Home Screen gets the default welcome. The doc presents it as a guaranteed onboarding preselect (`APPLE-DELIVERY.md:357`).
- **Fix:**
  - Rebuild the keyword field as the pages' inventory, for example `violin,ukulele,uke,cello,bass,mandolin,banjo,fiddle,chromatic,strobe,ear training,metronome,chord` (≈ 95). Apple combines those with "guitar", "tuner", "lessons", "learn" and "songs" from the name and subtitle, so "violin tuner" and "learn ukulele" still match.
  - Assign single tokens per page: violin and fiddle → violin; cello → cello; ukulele and uke → ukulele…
  - Correct the two docs, and do the same per locale.
  - Keep the deep link, but also map Apple Ads ad groups to an instrument through the `attribution` event (the ad group ID arrives within seconds of launch) and preselect from that when no link has arrived.

### 3. Major, size S–M: the App Preview with sound is mostly silence, the band is missing and the lock is never on camera
- **Material:** `review16/preview/preview.mp4`, `PREVIEW.txt`, `poster.png`; `APP-STORE-LISTING.md:208`; `preview.py:80`, `:884`; `DemoScenes.swift:376-386`.
- **What I measured** (ffmpeg astats, 0.5 s and 0.1 s windows; integrated loudness −15.2 LUFS):
  - **0.0–1.9 s: digital silence** (mean −91 dB). Anyone who taps to unmute on the first frame hears nothing.
  - **10.9–16.4 s, "Play songs with the band": no band.** A 100 ms blip every ~0.68 s (88 BPM) with digital silence between, which is the click. No melody, no guitar, no backing. The pipeline swaps the speaker route to read as headphones so the band plays (`DemoScenes.swift:592-599`). In this run it didn't, and nothing failed.
  - **17.0–23.17 s: 6.2 s of digital silence** under "Hear how you did" (the stars' triad rang before the clip's kept tail), the Songs tab and the end card.
  - In all, about 26 of 46 half-second windows are silent or near-silent. The gate in `preview.py:884` only checks the *mean* volume against −30 dB, which a click track normalised to −16 LUFS clears, so it printed "Meets the App Preview spec."
  - **The lock is never on camera.** In `PREVIEW.txt` the `lock` clip ends at 124.83 s but the lock sync is at 125.33 s. The 0–3.4 s frames show "Tighten" → "Hold it…" at −3¢ with the E2 chip unticked and "Quest 0/6". `PREVIEW.txt` calls the 2.70 s poster "(in lock)" and the listing promises "the poster: ✓ In tune, the peg's tick". The poster shows "Hold it…". This is round 15's B6 defect again.
  - The highway clip runs at ×1–×2 with a combo of 1–7 and "× 2" misses in red (t13), not the ×4, combo-70 chorus of screenshot #2.
  - No violin preview was rendered, although the violin page's table names one (`APP-STORE-LISTING.md:221-233`).
- **What's good:** 23.2 s, captions on every clip (the preview autoplays muted in search), the highway by 11 s, Songs under 3 s, and an end card that says "Free tuner · No ads · No account".
- **Fix:**
  - Make the band audible in the recording: assert `store.audio.headphones` in `startIfAsked` and *fail* the workflow when the "no band" note appears.
  - Add per-clip gates in `preview.py`: no digital silence over 0.5 s anywhere, and the highway clip ≥ 80 % non-silent windows.
  - Anchor the `lock` clip's end to the pinned lock sync + 1.2 s, and pick the poster from a frame where "✓ In tune" is detected.
  - Keep the *head* of `results` so the three star notes land under "Hear how you did".
  - Lay the app's own welcome motif (an existing cue, so still "nothing added") under the end card.
  - Pick the highway window by the HUD's ×4.
  - Render the violin cut.

### 4. Major, size S: two of the remote levers are dead, and subscription outcomes aren't measured
- **Code:**
  - `CommerceService.swift:108-111`: `annualProductID(remote:)` returns the remote product only if `TimbreProduct.subscriptions.contains(remote)`.
  - `Access.swift:11`: `subscriptions = [annual, monthly]`.
  - `CommerceService.swift:137`: loads only `TimbreProduct.all`.
  - `Access.swift:32`: `isPro` counts only those IDs.
  - `RemoteConfig.swift:13`, `:16`, `:122-124`; `APPLE-DELIVERY.md:40`, `:91`, `:94`; `APP-STORE-LISTING.md:273`.
- **What's wrong:**
  - **The price test can't run.** The documented arm `{"annualProductId": "timbre_pro_annual_b"}` falls back to the standard yearly plan on every device. Even if it didn't, a purchase of `_b` would never grant Pro. The $49.99 against $59.99 test the docs promise "without a build" needs a build.
  - `flags.unit2Free` is documented in both files, but `RemoteConfig.flag(_:)` is called nowhere in the app. The free-tier test the foreman asked to keep can't run either.
  - There's still no signal for trial→paid, renewals, auto-renew turned off, refunds or expiry: no App Store Server Notifications, and no client-side proxy either.
- **Fix:**
  - Add `annualB = "timbre_pro_annual_b"` (and `_c`) to `TimbreProduct.all` and `.subscriptions` now, plus a unit test that the remote arm is honoured and grants Pro. Ship it in 1.0 so the owner can create the products later.
  - Read `flag("unit2Free")` in `AccessPolicy.canPlay`, passed in from `AppStore.canPlay` as `extraFreeUnits`.
  - Until the owner hosts an ASSN v2 endpoint, log from the device:
    - `subscription_state{state, will_renew, offer, product}` when `Product.SubscriptionInfo.Status` or `renewalInfo.willAutoRenew` changes (a trial cancelled on day 0 shows up here);
    - `renewal{product, offer_type}` for each new transaction in `Transaction.updates` whose `originalID` differs from its `id`;
    - `refund` when `revocationDate` appears.

### 5. Major, size S: the monthly intro trial the owner is told to create is never shown, logged or reminded
- **Code:**
  - `CommerceService.swift:115-117`: `trialLabel` reads only `annual`'s intro offer.
  - `PaywallView.swift:1413` (`wasTrial = isAnnual(selected) && …`), `:1335-1340` (CTA "Subscribe for $6.99"), `:1343-1349` ("$6.99 a month, renews automatically"), `:880` (Monthly row "Cancel anytime").
  - `PaywallWinBack.swift:62-66`; `APPLE-DELIVERY.md:31-32` (monthly "Free trial, 1 week").
- **What's wrong:**
  - StoreKit applies an introductory offer to any eligible purchase. Once the owner adds the recommended 7-day monthly trial, everyone who picks **Monthly** on the main paywall starts a free week, while the row, the button and the terms line all say they're paying $6.99 now.
  - The system sheet will then contradict the paywall.
  - `purchase` logs `trial=0` for a trial, so trial-start counts and the trial→paid rate are wrong from day one.
  - `TrialReminder.schedule` isn't called, so the "we remind you" promise silently doesn't apply to that trial.
  - The one-time "exit offer" is that same automatic intro, so it isn't exclusive.
- **Fix:**
  - Generalise `trialLabel` and `trialDays` to any `Product`: show "7 days free" on the Monthly row, use "Start 7-day free trial" and its own terms line, and set `trial` and the reminder for whichever plan is chosen.
  - Either drop the monthly intro and keep the exit offer for win-back and offer codes only, or keep the intro and stop calling it an exit offer.

### 6. Major, size M: non-English storefronts and onboarding are still English where it counts
- **Screens:** `l10n-de-welcome.png`: German buttons under the English "Tune in seconds. Then learn to play." and "Timbre listens and tells you exactly how you did." The Violin chip is also gone from the German row (Gitarre, Bass, Ukulele, …).
- **Code and docs:**
  - `de/fr/ja.lproj/Localizable.strings` have no entry for "Tune in seconds.\nThen learn to play.", "Play my first songs", "You just played your first chord", "Any song you love: paste the chords, play along", "Cancel in 2 taps", "Share with up to 5 family members", "Give a friend a month" or "Get Timbre: …".
  - `HANDOFF.md`: 475 app strings missing in every locale.
  - `APP-STORE-LISTING-LOCALIZED.md:7`: no locale's description, promotional text, What's New or captions can be pasted.
  - `APP-STORE-LISTING-LOCALIZED.md:47-49`: the translators' table still says **`{courses}` 17, `{lessons}` 819, `{songs_floor}` 120 ("124 now")**, while the English listing and the paywall say 11 courses, 518 lessons and 140+ songs (`screenshots.py --check`: "518 lessons, 11 courses … 144 songs").
  - `screenshots.py --check`: 117 caption rows still `TRANSLATE:`.
- **What's wrong:**
  - Every German, French or Japanese newcomer reads the new funnel's key promises in English.
  - A translator working from the variables table would write numbers that contradict the English listing and the app's own paywall. The check validates variable *names*, not their values.
- **Fix:**
  - Have `screenshots.py --check` compute the variables table from the build and fail on a mismatch.
  - Put the ~40 funnel strings (welcome to paywall) at the top of each TODO file as "launch-critical".
  - Until they're translated, ship only the locales that are ≥ 95 % complete in `CFBundleLocalizations` (owner decision).

### 7. Major, size S: the songs people do know are buried, and December is seven weeks away
- **Screens:** 63-songs and store frame #5: "Song of the day: *First Frost*" (Original), then "3 chords or fewer: *Dust on the Dashboard*, *Lantern Hill*" (Originals). The preview's Songs clip shows *Dust on the Dashboard*. The paywall rail on 06 shows three abstract sleeves with no readable title.
- **Data:** the catalogue holds about 15 carols (*Silent Night*, *Joy to the World*, *Deck the Halls*, *O Come, All Ye Faithful*, *Hark! The Herald*…), *Ode to Joy*, *Amazing Grace*, *Twinkle*, *When the Saints*. Of the carols, only *Jingle Bells* is free. `APPLE-DELIVERY.md` plans a "Holiday carols" In-App Event for December 1–31.
- **What's wrong:**
  - Until licensed songs arrive, these public-domain titles are the only names a buyer recognises, and the shelves, the store frame and the preview lead with 50 Originals no one has heard of.
  - An In-App Event must be published up to 14 days ahead, and a holiday Featuring Nomination 6 weeks ahead, which means about Oct 20 for Dec 1. That date has passed, and the event card currently promises carols that are 93 % Pro.
- **Fix:**
  - Rank recognisable public-domain titles first on Songs and in the rail. In December, make "Song of the day" a carol, and add a seasonal shelf, unlocked for free players for the event's first week via a `freeSongs` list in RemoteConfig.
  - Recapture store frame #5 and the preview's Songs clip on a shelf whose first cards say *Ode to Joy*, *Amazing Grace* and *Silent Night*.
  - Add the "Request a song" button the licensing playbook asks for (`SONG-LICENSING-PLAYBOOK.md`, "Next 30 days"). It costs a sheet and an event, and its data is what publishers will ask for.

### 8. Minor, size S: a tuner-intent install still answers four screens before it can tune
- **Screens:** 01 → 03 → 04 → 04b → 05 → 05a; `OnboardingView.swift:173-203`.
- **What's wrong:**
  - Someone who searched "guitar tuner" (most of the volume, and the source of the 5★ ratings) taps Get started, experience, goal, hand and the microphone before hearing the tuner: about 7 taps and 25–40 s. Fender Tune opens on the tuner.
  - "I already have Timbre Pro" is a full-width secondary button on the welcome screen for a 1.0 app where nobody has Pro yet (`OnboardingView.swift:297-310`).
  - The progress bar grows from 6 to 7 segments after the experience answer (03 against 04), so the funnel visibly gets longer.
- **Fix:**
  - Add a text link "Just tune" on the welcome screen. It asks for the microphone in context, opens the tuner, and defers experience, goal and hand until Learn is first opened.
  - Turn the restore button into a footnote link.
  - Size the bar for the longest path from the start.

### 9. Minor, size S–M: the referral rewards nobody and is hard to find
- **Code:** `ShareDestination.swift:93-123` (one public custom code from RemoteConfig); `SettingsView.swift:72-87` and `WeekRecap.swift:90` (Pro-only, Settings and the week poster only); `project.yml:39-42` (no Associated Domains); `APPLE-DELIVERY.md:211`.
- **What's wrong:**
  - "Give a friend a month" shares one public custom code (`FRIENDMONTH`), redeemable once per Apple Account up to its cap. It is a coupon, not a referral: the sharer gets nothing, nothing ties a redemption to them, and a public code leaks to coupon sites.
  - It appears only in Settings and on the week poster, never at the peaks (a 3-star song, a streak milestone).
  - Without Associated Domains, the https share page can't open the app directly. It can only forward to `timbre://` through Safari's "Open in Timbre?" prompt.
- **Fix:**
  - Show the pill on lesson results after a 3-star song and on streak milestones.
  - Phrase it as a gift ("A month of Pro for a friend") and log `referral_share` with the screen.
  - When the owner can, switch to one-time codes handed out by a tiny endpoint so each referrer can be credited (for example a free month for them after a friend's first renewal).
  - Add `com.apple.developer.associated-domains` with `applinks:<share host>` and the AASA file.

### 10. Minor, size S: paywall seams
- **Screens and code:**
  - **16-paywall-from-settings:** the plan cards are invisible while the "14 DAYS FREE" tag floats over empty space, about 400 pt of blank between "What's in Timbre Pro" and the trust row. The tag layer is drawn outside the glass group, which hadn't faded in (`PaywallView.swift:856-866`, overlay at `:863`). If App Review's paywall screenshot catches this, it reads as a broken purchase screen.
  - **Strike-through anchor:** "$83.88" struck through next to "$34.99" with "SAVE 58%" (06, 40). It is twelve monthly payments, not a former price. In the EU and UK, a struck-through "was" price is a reference-price claim (EU Price Indication Directive Art. 6a; UK DMCC Act enforcement from April 2025).
  - **"Cancel in 2 taps"** (`PaywallView.swift:1006`): from Timbre that's Settings → Manage subscription → Cancel Free Trial → Confirm. That is three taps after reaching Settings, and Apple's sheet always confirms. It's an unverifiable claim on the money screen.
  - **Rating line** (`PaywallView.swift:558-566`; `RemoteConfig.swift:111-116`): the numbers are typed by hand into a JSON file, it is one global rating shown in every storefront although App Store ratings are per storefront, and it is set in amber, the colour that means "adjust".
  - **Settings row** "Try Timbre Pro: Every instrument, every ear game and practice tool." (`SettingsView.swift:90`): every instrument is free to tune now, and it doesn't mention lessons or songs, which are what Pro sells.
- **Fix:**
  - Draw the tag inside the plans' opacity transition, or hold the tag until `commerce.products` has loaded.
  - Label the anchor "12 × $6.99", or drop the strike-through outside the US.
  - Change the trust line to "Cancel anytime in Settings · We remind you on day 12".
  - Fetch the rating from `itunes.apple.com/lookup?id=<id>&country=<storefront>` instead of hand-typed JSON, set it in ink or gold, and keep the ≥ 4.6 / ≥ 200 rule.
  - Change the Settings copy to "Every lesson and song, every tuning and tool".

### 11. Minor, size S: store-frame seams
- **Material:** rendered sets in `scratchpad/growth16/` (contact9.jpg, violin3.jpg, ipad4.jpg).
- **What's wrong:**
  - **Violin page #3** "Hear exactly how you played" shows the *guitar* results "6 of 6, clean · The open strings" on a page for a four-string instrument.
  - The status bar "9:41" is sliced by the frame edge on #7 and violin #3.
  - #8's screen title "Strum to tune" is cut through the middle of the letters at the top edge.
  - #1's headstock is small and dark, and its "Hold it…" (not "✓ In tune") repeats the preview's missing lock.
  - #5 leads with an Original (item 7).
  - Only the violin page has store frames; cello, ukulele, bass and mandolin still need `storeFrame` captures (`APP-STORE-LISTING.md:252`).
- **Fix:**
  - Capture violin results (`62-lesson-results` on `vln-1-6`) for the violin page.
  - Have the `zoom` and `flip` looks crop below the status bar or include it whole.
  - Keep #1's capture only when the chip shows its tick.
  - Promote `49c`, `17` and `19` to store frames with their own tables.

### 12. Minor, size S: small funnel losses
- **The first chord doesn't count.** After "You just played your first chord", the plan says "First lesson: Meet your guitar" (05b), and the course's own "Your first chord: E minor" lesson stays unplayed. `FirstChordStep.swift:137` sets only `firstChordDone`. Credit `gtr-1-4`'s chord step, or show "Em ✓" on the plan.
- **The reminder ask splits two wins.** It comes between the first tune and the first chord (`OnboardingView.swift:196-203`). Ask after the chord, at the bigger peak.
- **No review prompt after a song.** There's no prompt after the first song played at three stars; `LessonResults.swift:634-637` prompts only at lessons 2 and 10, and only if that lesson got 3 stars.
- **No widget promotion.** No TipKit tip or Today card promotes the widgets on day 2 (`Timbre/Tips/TimbreTips.swift` has two tips, both on the tuner).

### 13. Minor, size S: owner-dependent trust hygiene still visible in the build
- **Privacy link.** `ShareDestination.swift:11` falls back to `https://azerish25-ux.github.io/tuner/privacy.html` until `TIMBRE_PRIVACY_POLICY_URL` is set. A personal github.io handle on the paywall's Privacy link is the first thing an editor or a careful parent clicks.
- **Keywords.** "uke" was dropped on the claim that "ukulele" matches it. Apple doesn't document prefix matching, and "uke tuner" is a real query; check it in Apple Ads' search popularity before 1.0.

### What earns the 8.1 (verified)

- **The funnel, end to end** (beginner, guitar):

  | Step | Screen | Taps |
  |---|---|---|
  | Welcome | 01 | 1 |
  | Experience | 03 | 2 |
  | Goal, preselected "Play my first songs" | 04 | 1 |
  | Hand, preselected | 04b | 1 |
  | Microphone, with a privacy line | 05 | 1 + iOS |
  | **First tune locks**, "Low E, dead on.", +5 XP, 1-day streak | 05a2 | |
  | Full-card reminder, "Keep your 1-day streak" | 05a3 | 1 (+ iOS) |
  | **First chord heard**, every string lit, celebration | 05c | |
  | Plan | 05b | 1 |
  | Paywall | 06 | |

  First value comes at about 25–40 s and the paywall at about 90–130 s, after two felt wins. The first-chord step is real (`FirstChordStep.swift:131-147`): heard, it announces, celebrates and moves on, and Skip is always there.
- **Paywall** (06, 16, 40):
  - Two plans on onboarding, lifetime only on standard paywalls (`PaywallView.swift:63-70`), with a remote arm to bring it back.
  - The proof line is counted from the build, with songs by distinct title rounded down to "140+" (`:537-555`).
  - Outcomes follow the reason the paywall opened, including "Any song you love: paste the chords, play along".
  - The timeline names Today, the song day, the reminder day and the charge day, and the promise is dropped when notifications are blocked (`:993-997`).
  - The Family Sharing line shows only when StoreKit says the plan is shareable (`:829-840`). The rating line has a rule (`RemoteConfig.swift:59-66`).
  - "Continue with the free tuner" is a clear way out. There is one exit offer per install, built only from real App Store offers. There are offer codes and a billing-issue banner (`RootView.swift:35`).
- **Free tier:** every instrument's standard tuning (`Access.swift:39-55`), every preset for guitar, bass, ukulele, violin and cello, open chords with Check, capo and transpose (`SettingsView.swift:158-178`), one custom tuning, ten Your-songs charts, eighths and triplets (`FreeTier.swift`). "Best free tuner" reviews on mandolin, banjo and oud queries are now possible.
- **Measurement**, all in code (`Analytics.swift:8-21`), with an opt-out in Settings, a privacy manifest declaring analytics as not linked (`PrivacyInfo.xcprivacy`), and a privacy policy section (`PRIVACY.md:15-23`).
- **Listing:** the opening line "Free tuner, no ads, no account. Then lessons that listen as you play.", an honest "140+ songs", no VoiceOver claim until it's true, and a 4+ age-rating sweep down to single lyric lines. `screenshots.py --check` gates every count and length (it passed today).
- **Screenshots:**
  - An art-directed colour progression: mint, sky, lime, spotlight, one light orchid frame, violet, gold, mint, flame.
  - The first three answer free (#1), listens (#2, *Kite Weather* at ×4 with lyrics) and "today" (#3, Em with every string ticked).
  - iPad #2 now has a valid capture.
- **Retention:** the trial-end notification recaps minutes and days played (`PracticeReminder.swift:194-202`); practice reminders name the next lesson and the streak; streak freezes, quests, widgets, Live Activity and the Watch.
- **Shares:** every `ShareLink` now carries "Get Timbre: <https link>" once the owner sets the IDs (`ShareDestination.swift:52-71`; `Celebration.swift:95`, `:271`, `:356`; `LessonResults.swift:720`; `SongStoryCard.swift:202`; `WeekRecap.swift:148`), and the Game Center challenge text includes the App Store link (`GameCenter.swift:44-52`).

### Round-15 items, checked one by one

| # (R15) | Item | Status | Evidence |
|---|---|---|---|
| 1 | Nothing measured | **Fixed in code; the ID waits on the owner. Two levers dead, no subscription outcomes** | `Analytics.swift`; `OnboardingView.swift:154`, `:593`; `PaywallView.swift:91`, `:123-135`; `CommerceService.swift:157-177`; `AppStore.swift:178-185`. Dead: item 4 above. |
| 2 | No songs the buyer knows | **Partly.** Your songs is above the fold on Songs (63), a paywall outcome (06) and a listing bullet. Licensing is the owner's, not started. | Item 7 |
| 3 | Price and packaging | **Code ready; prices are the owner's** ($34.99 / $6.99 / $89.99 still in `Timbre.storekit`). A new monthly-intro defect. | Item 5 |
| 4 | Paywall before the lesson moment | **Fixed** (welcome, goal, first chord), **but the song headline never fires for beginners** | Item 1 |
| 5 | App Preview doesn't sell | **Partly.** Captions, length, highway and end card are fixed; the sound, the lock and the band are not. | Item 3 |
| 6 | Stale non-English pages | **Not fixed** (translators); a stale variables table is new | Item 6 |
| 7 | Instrument-led ASO | **Partly.** Plan, deep link and violin set are done; keywords can't be assigned; the deep link works only on Open | Item 2 |
| 8 | Free tier cut wrong | **Fixed for the tuner and tools; not for lessons** (unit 1 only, no free song in any course) | Items 1 and 4 |
| 9 | Generic screenshots | **Fixed**, minor seams | Item 11 |
| 10 | Social proof and plan clutter | **Fixed** (rule coded, two plans); the quote and ratings are the owner's | Item 10 |
| 11 | Quiet reminders | **Fixed** | 05a3; `PracticeReminder.swift:194-202` |
| 12 | Shares bring no one | **Fixed in code**; IDs, share page and offer code are the owner's; no Associated Domains | Item 9 |
| 13 | Listing copy | **Fixed** ("uke" is a risk) | Item 13 |
| 14 | iPad #2 capture | **Fixed** | `ipad-landscape-instruments.png`, rendered |
| 15 | Billing and trust hygiene | **Mostly fixed** (grace entitlement, banner, delivery doc §9); the privacy URL is the owner's | Item 13 |

---

## 4. The $10k-a-month model

**Net per list dollar:** about $0.80 (the Small Business Program's 15 %, plus VAT and tax on a 65 % US / 35 % international blend). $10k net is about **$12.5k gross a month**.

**Benchmarks** (RevenueCat, *State of Subscription Apps 2026*):
- Education's median yearly price is **$44.99**, the highest of any category, and its monthly median is $9.99.
- Download-to-trial is **6.5 %**.
- **78.5 % of trial starts happen on day 0**, which makes the onboarding paywall the business.
- Median revenue per install at day 14 is **$0.30**, and yearly realised LTV per payer is $22.82.
- Yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 days.

| | A: today's prices ($34.99 / $6.99 / $89.99) | B: recommended ($49.99 / $9.99 / $149.99, lifetime off onboarding) |
|---|---|---|
| Net in a buyer's first year | $31.55 | **$43.67** |
| New buyers a month for $10k net (year 1) | 317 | **229** |
| Installs a month at 1.8 / 2.6 / 3.4 % install-to-paid | 17,600 / 12,200 / 9,300 | 12,700 / **8,800** / 6,700 (about **295 a day** at 2.6 %) |
| Year-1 net per install, the most one install can cost | $0.57 / $0.82 / $1.07 | $0.79 / **$1.14** / $1.48 |
| Steady state with yearly renewals (year 3) | about 200 buyers, 7,700 installs a month | **about 140 buyers, 5,400 installs a month** |

**What round 16 changed in the model.**
- Two felt wins before the paywall and a two-plan paywall should lift onboarding install→trial from my 5.2 % base toward the 6.5 % Education median.
- Item 1 alone (the "first song this week" promise for the default goal) is worth testing as the first experiment, once the ID is live.
- Captions on the preview and a "Free tuner. No ads." first frame help search-result conversion. The half-silent soundtrack and the missing band cost the unmuted viewers, who are the most interested ones.
- The violin, cello and ukulele long tail is still the only organic channel that can bring about 150–350 installs a day in the first six months. Item 2 decides whether the Custom Product Pages can take it at all.

**My call.**
- **As shipped, with the owner's levers unpulled** (today's prices, no analytics ID, no Custom Product Pages): about **10–15 %** chance of $10k net a month within 12 months.
- **With the owner's levers pulled** (scenario B, analytics on, the violin, cello and ukulele pages live with working keywords, a Featuring Nomination, then Apple Ads only after measured revenue per install ≥ $1.10) and items 1–5 fixed: about **35–45 % within 12–18 months**.
- **With a licensed starter pack of 20–30 songs on top:** above 50 %, and the first real shot at #1 in a sub-niche (violin, then ukulele).

---

## 5. How to take #1 on growth, ranked by impact

1. **Make the first-song promise true for every beginner (team, 2–3 days).**
   - Compute `songDay` from minutes.
   - Put a free song at the end of every course's unit 1, and route the "songs" goal to a free songbook song on day 1–2.
   - The onboarding paywall then reads "Play your first song this week" for the default goal. That headline, after a heard chord, is a paywall Simply and Yousician can't match on honesty.
2. **Turn the instrument pages on, for real (team half a day, owner 1 day).**
   - Rebuild the keyword field as the pages' inventory (violin, ukulele, uke, cello, mandolin, banjo, fiddle…), assign single tokens per page, and fix both docs.
   - Render the violin preview and promote the cello and ukulele captures to store frames.
   - Map Apple Ads ad groups to an instrument through `attribution` as the fallback preselect.
   - Launch violin, cello and ukulele first: Trala charges $119.99 for violin alone.
3. **Fix the money paths before the first dollar (team, 1 day).**
   - Add `timbre_pro_annual_b` / `_c` to `TimbreProduct` and wire `unit2Free`.
   - Disclose and log the monthly intro trial.
   - Log subscription state, renewal and refund events from the device until the server notifications exist.
   - Then the owner's prices go live as an experiment, not a guess: $49.99 against $59.99 on the yearly plan, with the 14-day trial kept.
4. **A preview you'd unmute (team, 1–2 days).**
   - Capture the band (fail the run without it), anchor the lock, and put sound in the first and last 2 s.
   - Pick the ×4 chorus and recut to about 20 s.
   - Then run Product Page Optimization: poster on the lock against poster on the highway.
5. **Lead with the songs people know until licensing lands (team 1 day, owner a decision).**
   - Public-domain titles first on Songs, on store frame #5, in the preview's Songs clip and in the paywall rail.
   - A December carol shelf, free for the event's first week through a remote `freeSongs` list.
   - A "Request a song" button to collect publisher-grade demand data.
   - Submit the carol In-App Event by mid-November.
6. **Translate the funnel first (owner, translators).** The ~40 strings from welcome to paywall, plus a generated, verified variables table. Ship only the locales that are complete.
7. **Social proof, fast and honest (owner).**
   - A TestFlight cohort of 300–500 and two consented teacher quotes before launch.
   - The rating line fetched per storefront from the lookup API once ≥ 4.6★ / ≥ 200.
   - A review prompt after the first song played at three stars.
8. **A "Just tune" door for tuner-intent installs (team, half a day).** It turns "guitar tuner" installs into 5★ ratings, which compound every other lever.
9. **A referral that rewards the referrer (owner plus a small endpoint).** One-time codes, and the pill shown after a 3-star song and on streak milestones. Add Associated Domains so the share page opens the app.

---

## 6. What only the owner can do (everything in code now waits on these)

- **Prices and packaging in App Store Connect:**
  - Yearly $49.99 with the 14-day trial, monthly $9.99, lifetime $149.99 (off onboarding by default).
  - Family Sharing on the yearly plan and lifetime. The paywall line appears by itself (`PaywallView.swift:829`).
  - Billing Grace Period on, now that the entitlement fix and the banner are in (test it on TestFlight first).
  - A win-back offer, and the Small Business Program.
  - Decide on the monthly intro trial only after item 5 ships.
- **Accounts and addresses:**
  - The **TelemetryDeck app ID** (`TELEMETRYDECK_APP_ID`). Every event in this report is dark until it is set.
  - `TIMBRE_APP_STORE_ID` as soon as the app record exists; `TIMBRE_SHARE_URL` and the share page.
  - `TIMBRE_REMOTE_CONFIG_URL` and its JSON; `TIMBRE_PRIVACY_POLICY_URL` on a custom domain, off github.io.
  - The App Privacy label changed to "Analytics, not linked" before submitting with analytics on.
  - An App Store Server Notifications v2 endpoint.
- **App Store Connect programme:**
  - Violin, cello and ukulele Custom Product Pages, once the keyword field is fixed.
  - The "Holiday carols" In-App Event, submitted by mid-November.
  - A launch Featuring Nomination: already late for a December 1 launch, so nominate for the January "learn something new" window.
  - Product Page Optimization tests.
  - The "Give a friend a month" offer code.
  - Accessibility Nutrition Labels (no VoiceOver until the play-along works with it).
- **Licences and people:**
  - A licensed starter pack of 20–30 recognisable songs (the playbook's 30-day list: an attorney, outreach to independent artists, quotes from Hal Leonard, Musicnotes, LyricFind and Musixmatch).
  - Translators for the launch-critical funnel strings and the 9 store listings.
  - A TestFlight cohort and 2–3 music teachers.
- **Money:**
  - An Apple Ads test at about $1.5–3k a month on exact-match instrument keywords, only once revenue per install is measured.

**Levers that are NOT the owner's** (the team must fix them, or the owner's actions don't land):
- The price-arm product IDs and the `unit2Free` wiring (item 4).
- The monthly intro disclosure (item 5).
- The song-day promise (item 1).
- The preview audio and lock (item 3).
- The keyword-field rebuild for the pages (item 2).
- The stale translators' table (item 6).

---

## 7. Sources

- [GuitarTuna: Tune & Play Guitar, App Store (US)](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): subtitle, 4.8★ from 149K ratings, #21 Music, Tools / Play / Learn prices, "100 million downloads", 20,000+ songs, updated 3 days ago.
- [Fender Tune: Guitar Tuner App, App Store (US)](https://apps.apple.com/us/app/fender-tune-guitar-tuner-app/id1107017950): subtitle, 4.8★ from 152K ratings, #84 Music, free, 26 tunings, 5,000+ chords, iOS 27 update 16 hours ago.
- [Fender Play: Learn Guitar, App Store (US)](https://apps.apple.com/us/app/fender-play-learn-guitar/id1226057939): subtitle, 4.8★ from 61K ratings, 1000+ songs, 14 days free, plan prices.
- [Yousician: Learn & Play Guitar, App Store (US)](https://apps.apple.com/us/app/yousician-learn-guitar-bass/id959883039): subtitle, 4.6★ from 139K ratings, #76 Education, Editors' Choice, $119.99–$179.99 yearly.
- [Simply Guitar - Learn Guitar, App Store (US)](https://apps.apple.com/us/app/simply-guitar-learn-guitar/id1476695335): subtitle, 4.7★ from about 400K ratings, #58 Education, prices up to $199.99.
- [Justin Guitar Lessons & Songs, App Store (US)](https://apps.apple.com/US/app/id1176125504): subtitle, 4.9★ from 22K ratings, 1,500+ hit songs, $64.99–$129.99 yearly.
- [Trala: Learn Violin, App Store (US)](https://apps.apple.com/us/app/-/id1143205265): 4.7★ from 4.9K ratings, $19.99/mo, $119.99/yr.
- [RevenueCat, State of Subscription Apps 2026: Education](https://www.revenuecat.com/state-of-subscription-apps-2026-education): $44.99 yearly and $9.99 monthly medians, 6.5 % download-to-trial, 78.5 % of trials started on day 0, $0.30 D14 revenue per install, $22.82 yearly realised LTV per payer.
- [RevenueCat, State of Subscription Apps 2026](https://revenuecat.com/report): the all-category trial-length conversion figures (10–16-day yearly trials about 43 %, 5–9 days about 33 %), as cited in round 15.
- [Apple, Custom product pages](https://developer.apple.com/app-store/custom-product-pages): keywords per page, 70 pages, deep links on iOS 18 or later.
- [App Store Connect Help, Configure multiple product page versions](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions): "You can assign keywords from your latest approved app version to a custom product page"; the deep link applies when users "click Open on your custom product page".
- [Apple Developer Forums, "Are Deep Links on Custom Product Pages working?"](https://developer.apple.com/forums/thread/757367): Apple engineer, "The Deep Link only changes the URL of the 'Open' button on the App Store client."
- [Adapty, "App Store custom product pages: how to use them in 2026"](https://adapty.io/blog/custom-product-pages-app-store/): keywords are assigned "from your keyword field"; each combination unique to one page.
