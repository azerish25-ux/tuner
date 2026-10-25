# Jury 15: Growth (App Store editorial and subscription growth)

Juror: App Store editor and subscription-growth lead (music and education apps taken past $1M ARR).
Angle: the listing, ASO against competitors' live pages, the first-session funnel, the paywall and pricing, free versus Pro, retention, virality, analytics, and whether Timbre can reach $10k a month.

---

## 1. Score: 7.4 / 10

Timbre has the most honest and best-built paywall in the category, and one of the fastest first sessions. In about 45 seconds a new player picks an instrument, answers two questions, grants the microphone with a privacy promise, tunes a real string and gets a reward (05a2). The plan is personal, with a unit placement and an optional 45-second check (05b). The paywall's trial timeline names the day of the reminder and the day of the charge (06, 16, 40), and the code behind it is careful: exit offers come only from real App Store offers, plus offer codes, win-back and review prompts at the right moments.

Growth is decided by other things, though, and there Timbre is behind every funded competitor:
- **No songs people know.** The Songs tab leads with *First Frost* and *Dust on the Dashboard* (63). GuitarTuna's subtitle sells "Chords, Tabs & Lyrics to Songs", and Simply, Yousician and Fender sell licensed hits.
- **Priced like a tuner.** $34.99 a year is below the Education median of $44.99, against $64.99–$179.99 for the lesson apps.
- **Nothing to measure with.** No analytics ID is set and the onboarding paywall's impression isn't logged. There is no session event, no renewal data, no attribution and no way to run an experiment.
- **A silent App Preview.** The preview has no sound and spends 9 of its 29 seconds on a still Songs tab.
- **Stale non-English listings.** The nine localized listings still say 499 lessons, 13 courses and 20 Originals.
- **No instrument-led ASO.** The one structural advantage, 60 instruments, isn't used for ASO through keyword-linked Custom Product Pages.

It is a good app with visible growth seams, and as shipped I would not bet on $10k a month in year 1.

---

## 2. Head-to-head on growth

Live store facts were fetched on 2026-10-25 (US storefront unless noted). A rating count means the number of ratings.

| Competitor | Live listing | Who wins on growth | Why |
|---|---|---|---|
| **GuitarTuna** (Yousician Ltd) | Name "GuitarTuna: Tune & Play Guitar". Subtitle "Chords, Tabs & Lyrics to Songs". 4.8★ from 149K ratings, #21 in Music. Three tiers: Tools $29.99/yr, Play $39.99/yr, Learn $139.99/yr. "100 million downloads". | **GuitarTuna** | It owns the "guitar tuner" query and its social proof. Its tiers capture both tuner buyers ($29.99) and learners ($139.99), where Timbre's single $34.99 plan captures neither well. Timbre wins on craft and honesty: a 3D stage, no ads, no account, and a trial timeline with a reminder. On the search results page, though, a 0-rating Timbre next to a 4.8★/149K GuitarTuna loses almost every tap. |
| **Fender Tune / Fender Play** | Fender Play's App Store page: "Start for free", "14 days free", 10% off Fender gear with a plan. Third-party trackers list $9.99/mo and $89.99/yr (sources conflict). I could not read the Fender Tune page this session. | **Fender** for acquisition; Timbre for the in-lesson product | Fender has the brand, licensed songs, video teachers and a gear tie-in. Timbre listens as the player plays (52b, 65), and Fender Play mostly doesn't, so Timbre is the better product per dollar. But that is invisible on the store page, where only "Fender" and the song names show. |
| **Yousician** | Subtitle "Guitar, Bass & Singing Lessons". 4.6★ from 139K ratings, #76 in Education. One Instrument $119.99/yr or $19.99/mo; Premium+ $159.99–$179.99/yr. A December 2024 review complains most lessons are locked, and the developer replied that the library can't be free. | **Yousician** on revenue; **Timbre** on trust and value | Yousician's licensed catalogue and paid-acquisition budget win. Timbre is a third the price and its timeline is transparent, an answer to the billing complaints in Yousician's reviews. It also covers violin, cello, mandolin and banjo, which Yousician does not. |
| **Simply Guitar** (Simply) | Subtitle "Guitar Songs & Lessons". 4.7★ from about 400K ratings, #58 in Education. In-app purchases from $19.99 to $199.99 (yearly tiers $119.99 / $149.99 / $179.99 / $199.99). | **Simply Guitar** | It has the most social proof in the set, a song-led subtitle and a funnel built for paid acquisition. Timbre's first session is faster and has no account, but by the paywall a Simply user has played a song excerpt, while Timbre's has tuned one string. |
| **JustinGuitar** (Musopia) | Subtitle "Learn Guitar Chords, Simply". 4.9★ from 22K ratings. Full Access $64.99/yr or $8.99/mo; Unlimited $99.99–$129.99/yr. | **JustinGuitar** for guitar learners | Justin's face and his free YouTube course carry the trust. Timbre beats it on the tuner, on instrument breadth and on live feedback. |
| *(Category reference)* **Trala: Learn Violin** | 4.7★ from 4.9K ratings. $19.99/mo or $119.99/yr. | Violin is where **Timbre can win** | Violin learners already pay $120 a year for one instrument. Timbre offers violin and cello lessons that listen, plus a violin and cello tuner, for $34.99. This is the beachhead, and the listing doesn't aim at it. |

**What the ordinary user sees.** A search for "guitar tuner" shows Timbre with no rating, a dark 3D headstock and "In tune in seconds", beside a 4.8★, 149K-rating GuitarTuna, so they install GuitarTuna. A search for "learn guitar" shows Simply, Yousician and Fender with hundreds of thousands of ratings and songs they know, so they install those. A search for "violin tuner", "cello tuner" or "learn violin" shows weaker competitors, and Timbre's 3D violin and cello stages and lessons that listen are clearly better. Today, though, they would still land on a listing whose first three frames are all guitar.

Once installed, Timbre's first session beats every competitor: it is fast, beautiful, asks for no account and has an honest paywall. Then the player opens Songs and finds no song they recognise.

---

## 3. Everything that costs points, ranked

### 1. Blocker, size M: nothing can be measured, so nothing can be tuned to $10k
- **Screens and code:** `Analytics.swift:32-35`; `project.yml:89`; `OnboardingView.swift:60-63`; `AppStore.swift:469-473`; `PaywallView.swift:1360`; `RootView.swift:86`; `APPLE-DELIVERY.md:67`.
- **What's wrong:**
  - With no `TIMBRE_TELEMETRY_APP_ID`, nothing leaves the device.
  - The highest-volume paywall, onboarding's, is shown by `fullScreenCover` and never logs `paywall_shown`. Only `presentPaywall` logs it.
  - There is no `app_open` or session event. A player who opens the app and tunes a few strings sends nothing (`full_tune` needs every string, `AppStore.swift:647`), so D1, D7 and D30 retention can't be computed.
  - Onboarding logs only `onboarding_first_tune` and `onboarding_complete`. Nothing records the welcome, experience, goal or plan views, or the microphone answer.
  - `purchase` has no trial flag, price or currency. Paywall declines, cancelled purchases and failed purchases aren't logged.
  - Nothing reports trial-to-paid, renewals, cancellations or refunds: no App Store Server Notifications and no server.
  - There is no AdServices attribution token for Apple Ads.
  - There is no remote flag to A/B test a paywall or a price.
  - `pro_active` fires on every launch for a subscriber, which inflates it.
  - The App Privacy label still says "Data Not Collected".
- **Fix:**
  - Set the TelemetryDeck ID.
  - Log `app_open` on `scenePhase == .active`.
  - Log `onboarding_step{step}` in `next()` and on each `step` change, and `mic_permission{granted}` after `requestRecordPermission`.
  - Log `paywall_view{reason, variant}` in `PaywallView.onAppear` and remove the call in `presentPaywall`.
  - Log `paywall_close{reason}` in `decline()`, and `purchase_cancelled` and `purchase_failed` in `CommerceService.purchase`.
  - Add `trial`, `price` and `currency` to `purchase`.
  - Log `pro_active` only when the value changes against a stored value.
  - Send the AdServices token once.
  - Stand up an App Store Server Notifications v2 endpoint (`DID_RENEW`, `EXPIRED`, `DID_CHANGE_RENEWAL_STATUS`, `REFUND`) and forward those events.
  - Read the paywall variant and annual product ID from a small remote JSON on the custom domain.
  - Update the privacy label to "Analytics, not linked".

### 2. Major, size L: no songs the buyer knows
- **Screens:** 63-songs, 64, 65, the paywall rails on 06 and 16, preview 19–29 s.
- **What's wrong:**
  - The catalogue is public-domain songs plus 50 Originals with abstract covers. The paywall's "159 songs" counts per-instrument arrangements: there are 124 unique titles (`curriculum.json`).
  - In this category, recognisable songs are what makes people subscribe. GuitarTuna's subtitle is about songs, and Simply's is "Guitar Songs & Lessons".
  - Timbre already has a partial answer, Your songs: import, paste or write a chart, and play along with Apple Music (`YourSongsShelf.swift:5-9`). But it doesn't appear in the listing, onboarding or the paywall outcomes.
- **Fix:**
  - Owner: license 20–30 recognisable songs, or partner with a chord or tab licensor.
  - Now: add a listing bullet, "Play any song: paste the chords, play along with Apple Music, Timbre follows". Add a paywall outcome for Your songs, and put the Your songs shelf above the fold on Songs.
  - Change the proof line to "120+ songs" (`PaywallView.swift:483-487` counts arrangements).

### 3. Major, size S (App Store Connect) or M (to test): price and packaging leave money behind
- **Code and docs:** `Timbre.storekit:9,50,79` (`familyShareable: false`); `APPLE-DELIVERY.md:31-38`; `PaywallView.swift:789-792` (lifetime on every paywall, onboarding's included); `APP-STORE-LISTING.md:178-185`.
- **What's wrong:**
  - $34.99/yr, $6.99/mo and $89.99 lifetime sit at a tuner app's price.
  - RevenueCat's 2026 report puts the Education yearly median at $44.99, the highest of any category. Lesson competitors charge $64.99–$179.99, and Trala charges $119.99 for violin alone.
  - Lifetime at 2.6× the yearly price sits on the onboarding paywall and pulls buyers away from the trial.
  - Family Sharing is off, although parents buy music lessons for their children.
  - The listing doc's "recommended" move to a 7-day trial goes against the data. In RevenueCat's 2026 numbers, yearly trials of 10–16 days convert at 43% and trials of 5–9 days at 33%.
- **Fix:**
  - Yearly $49.99 with the 14-day trial, monthly $9.99, lifetime $149.99.
  - Hide lifetime on the onboarding paywall (show it on standard paywalls and in Settings).
  - Turn on Family Sharing for the yearly plan and lifetime, and say so on the paywall ("Share with up to 5 family members").
  - Give the monthly plan a 7-day introductory offer, so the existing exit offer works (`PaywallWinBack.swift:62-66`).
  - Create a win-back offer, and turn on the Billing Grace Period.
  - Test $49.99 against $59.99 with a second yearly product ID chosen by the remote flag from item 1.

### 4. Major, size M: the paywall comes before the "lessons that listen" moment
- **Screens and code:** 01, 04, 05a, 05b and 06; `OnboardingView.swift:133`, `:279-281`.
- **What's wrong:**
  - The only value moment before the paywall is tuning one string. The paywall then sells lessons the player hasn't tried.
  - The welcome headline, "Tune until it stands still.", is poetic but says nothing to someone who wants to learn.
  - The goal question has no "learn to play songs" answer, the intent that pays. Its five answers are tuner and practice goals ("Tune fast and precisely" is first), so the player who came to learn has no answer that says so.
  - In my last look at their funnels, Simply Guitar and Yousician get a player to play notes with feedback before asking for money. I could not record their current onboarding this session.
- **Fix:**
  - Add the goal "Play my first songs" at the top of the list, and make it the default for "Just starting" and "A few months".
  - For those players, insert a 30-second "Your first chord" step after the first tune, reusing the chord step from 52b (E minor on guitar, C on ukulele, open strings on violin). Every string lights up, then show "You just played your first chord" and go on to the plan.
  - Retitle the welcome screen to "Tune in seconds. Then learn to play." with "Timbre listens and tells you exactly how you did." under it.

### 5. Major, size M: the App Preview doesn't sell
- **Material:** `review15/preview/PREVIEW.txt`, the contact sheet at `scratchpad/growth15/contact.png`.
- **What's wrong:**
  - The audio track is silent. A music app with no sound loses everyone who taps to unmute.
  - The first 8 seconds are the commodity tuner.
  - The highway segment (11–16 s) is the 60 BPM "Open-string roll call" with combos of 0–2, not the *Kite Weather* chorus with lyrics and the ×4 multiplier that screenshot #2 shows.
  - From 19.4 to 29.0 s it is an almost still Songs tab.
  - There are no captions, although the preview autoplays muted in search.
  - The preview replaces screenshot #1 in search results, so this is the first thing every searcher sees.
- **Fix:** Recut it to 20–25 s with captions and recorded instrument audio:
  - 0–3 s: *Kite Weather* chorus, "Perfect", ×4, the words lighting up.
  - 3–8 s: a real strum heard as E minor, every string lighting.
  - 8–12 s: Strum to tune.
  - 12–16 s: the violin and cello stages.
  - 16–20 s: stars and the streak.
  - End card: "Free tuner · Lessons that listen".
  - Set the poster frame on the highway.
  - Add second and third previews: tuner-first, and violin-first for that page.

### 6. Major, size M: non-English store pages are wrong and their screenshots are English
- **Docs and code:** `APP-STORE-LISTING-LOCALIZED.md:7, 62, 78, 103, 106-121`; `TimbreUITests.swift:12`; `screenshots.py` (no locale support).
- **What's wrong:**
  - All nine locales say 499 lessons, 13 courses and 20 Originals (the build has 638, 14 and 50).
  - The German free-tier line leaves out violin and cello.
  - Their caption lists describe an old set of 6 frames in another order.
  - Captures are forced to English, and the caption renderer has no locales, so de, fr, es, pt-BR, it, ja, ko, zh-Hans and ru would show English frames.
- **Fix:**
  - Regenerate the localized blocks from the English tables, keeping the counts as variables the way `screenshots.py --check` does.
  - Add `--locale` to `screenshots.py`, and run the UI-test tour per locale (`-AppleLanguages (de)`).
  - Translate the 9 captions and their supporting lines.

### 7. Major, size M: no instrument-led ASO
- **Doc:** `APP-STORE-LISTING.md` has no Custom Product Pages, In-App Events or Product Page Optimization plan.
- **What's wrong:**
  - Since July 30, 2025, Custom Product Pages can be assigned to keywords and appear in organic search, and since October 29, 2025, an app can have 70 of them.
  - Timbre's moat, 60 instruments and lessons on violin, cello, mandolin and banjo, is exactly what keyword-linked pages reward. Yet every searcher sees the same guitar-first set.
- **Fix:**
  - Build one page per instrument family: violin, cello, ukulele, bass, mandolin, banjo, voice, chromatic and strobe, and ear training. Each gets its own 3 lead frames and promotional text, and its keywords from the field ("violin", "cello", "mandolin"…).
  - Give each page a deep link, `timbre://tune?instrument=violin.standard.4`. Today `DeepLink.swift:65-71` holds a link until onboarding closes. Instead, let onboarding read a waiting `tune` link and preselect that instrument's chip and course.
  - Run In-App Events for "Holiday carols" in December (the carols are already in Standards) and a "30-day ukulele challenge".

### 8. Major, size S: the free tier is cut in the wrong place
- **Code and data:** `Access.swift:37`; `OnboardingView.swift:223`; `curriculum.json` (guitar: 5 free lessons, 20 minutes in all; `gtr-2-4` *Ode to Joy* is locked while `song-ode-to-joy` is free in Songs).
- **What's wrong:**
  - A guitar beginner hits the wall on day 1 or 2 at a 10-minute plan, before a habit forms, and the first song in their own course shows a lock.
  - Mandolin and banjo wear PRO on the welcome chips. Those players must pay to tune their own instrument, a classic 1-star review ("not a free tuner") on exactly the long-tail queries Timbre could win.
- **Fix:**
  - Make the standard tuning of every instrument free. Keep alternate and custom tunings, strobe, temperaments and the studio stage as Pro.
  - Make units 1–2 of the player's instrument course free, through its first song.
  - Turn "Tune all 60 instruments" on the paywall into "Every tuning, strobe and temperament".

### 9. Minor, size S: the screenshots are well made but generic
- **Screens:** the rendered first three are at `scratchpad/growth15/store/first3.png`; `screenshots.py:182-190`; `APP-STORE-LISTING.md:138-146`.
- **What's wrong:**
  - Frames #1–#3 are all guitar and all near-black, and they share one layout. None says "Free" or "No ads", the two facts that decide a tuner install.
  - The "TIMBRE" eyebrow uses headline room.
  - Caption #3 promises "Fingers land on a 3D guitar", but 51b shows two numbered dots with Show me at rest.
- **Fix:**
  - Change caption #1 to "Free tuner. No ads." with "60 instruments, to the cent" under it.
  - Make #2 the highway as now.
  - Make #3 "Play your first chord today" (52b), and drop the Show me frame or recapture it mid-animation.
  - Remove the eyebrow and let the device screenshot run 6% larger.
  - Add one light frame, the Songs tab, to break the dark run.
  - Run Product Page Optimization tests on the first three.

### 10. Minor, size S: no social proof on the paywall, and the plan choice is cluttered
- **Screens and code:** 06, 16 and 40; `PaywallView.swift:309`, `:789-792`.
- **What's wrong:**
  - There is no rating, review or player count on the paywall.
  - The headline "Unlock your full plan" is generic.
  - Three plans on the first paywall.
  - The hero rail is abstract sleeve art for songs no one knows.
- **Fix:**
  - Once the app has ≥ 4.6★ from ≥ 200 ratings, show a line under the proof line: "4.8★ · loved by N players". Before launch, show one teacher's quote from the TestFlight beta.
  - Change the onboarding headline to "Play your first song this week".
  - Show two plans on onboarding (yearly with the trial, and monthly).

### 11. Minor, size S: reminders are opt-in and quiet
- **Screens and code:** 05b, 62; `OnboardingView.swift:23`; `PaywallView.swift:1656-1657`.
- **What's wrong:**
  - The practice reminder is off unless the player finds the small "Remind me" pill.
  - The trial-ending notification reads "Keep tuning, or cancel anytime", which doesn't name what they used.
- **Fix:**
  - After the first-tune reward, ask on a full card: "Keep your 1-day streak. Remind me at 7 PM?", with Allow and Not now.
  - Rewrite the trial reminder with the value used: "You've played 6 lessons and 2 songs. Pro renews in 2 days; cancel anytime in Settings."

### 12. Minor, size S: shares don't bring anyone in
- **Code:** `GameCenter.swift:18` (`appStoreLink = nil`); `LessonResults.swift:700`, `WeekRecap.swift:145`, `Celebration.swift:52`.
- **What's wrong:** "Beat my score" messages carry only a `timbre://` link, which is dead for anyone without the app. The results, week and celebration cards share an image with no link at all. There is no referral offer.
- **Fix:**
  - Set the App Store link on day one.
  - Add `message:` with an https page (on the custom domain) that falls back to the App Store to every `ShareLink`.
  - Add "Give a friend a month" using one-time offer codes.

### 13. Minor, size S: listing copy leaves out the best facts
- **Doc:** `APP-STORE-LISTING.md:9-110`.
- **What's wrong:**
  - The description never mentions Your songs, Apple Music play-along, the Apple Watch metronome or Game Center challenges.
  - "No ads, no account" comes only at the end.
  - The keywords spend 6 characters on "strobe" and leave out "practice" and "bass" (bass sits in the subtitle now).
- **Fix:**
  - Open with "Free tuner, no ads, no account. Then lessons that listen as you play."
  - Subtitle: `Learn Songs: Ukulele & Violin` (29).
  - Keywords: `bass,chromatic,cello,mandolin,banjo,metronome,chord,ear training,practice,tuning,fiddle,pitch,sing` (98).

### 14. Minor, size S: iPad slot #2 has no valid capture
- **Screen:** `ipad-landscape-instruments-wrong.png`.
- **What's wrong:** The listing's iPad #2 ("Tune whatever you play", `APP-STORE-LISTING.md:153`) depends on a capture its own test rejected.
- **Fix:** Fix the scroll position or the crop and recapture.

### 15. Minor, size S: billing and trust hygiene
- **Code and docs:** `PaywallView.swift:1386`; `APP-STORE-LISTING.md:14`; `APPLE-DELIVERY.md`.
- **What's wrong:**
  - The privacy link is a github.io page under a personal handle.
  - The docs don't mention the Billing Grace Period, Family Sharing or Featuring Nominations.
- **Fix:** Move the privacy page to the custom domain, add those three App Store Connect steps to the delivery doc, and submit a Featuring Nomination for launch.

### What earns the 7.4 (verified)
- **Fast first session.** Six steps, a value moment in about 30 s, the paywall in about 50 s. No account. The microphone pre-prompt carries a privacy line (05). There is a Skip and a "Not now" path (`OnboardingView.swift:70-77`).
- **Personalised.** Placement by experience, a 45-second check, a named first lesson and a placement pass that opens it for free (`Access.swift:48-64`). The paywall headline, hero and timeline follow why it opened (`PaywallView.swift:307-336`, `:990-1011`).
- **The best trial timeline in the category.** It shows the reminder day and the charge day, and drops the promise when notifications are off (`:897-902`, `:1109-1114`). Notification permission is asked only after a trial starts (`:1361-1362`).
- **Exit, win-back, offer codes.** One exit offer per install, made only from real App Store offers (`PaywallWinBack.swift:45-68`). Offer codes are redeemable in the app (`:1397-1411`).
- **Review prompts at peaks.** After the 3rd and 12th full tune (`AppStore.swift:646`), and after the 2nd and 10th 3-star lesson (`LessonResults.swift:620-624`).
- **Rich retention loop.**
  - Today set, streak with freezes, quests, XP and levels, a coach.
  - Reminders that name the next lesson and the streak at stake, and stop after two idle weeks; a Sunday "Your week" notification (`PracticeReminder.swift:79-112`).
  - Four widgets, two Control Center controls, a Live Activity, and a Watch app with complications.
  - Game Center challenges and a friends' streak rank.

---

## 4. The $10k a month model

**What $10k net requires.** On the Small Business Program, Apple keeps 15%. Storefront VAT and tax (about 18–20% in Europe, included in the price) take more. Assume a blend of 65% US and 35% international: about **$0.80 of each list dollar reaches the developer**. $10k net is about **$12.5k a month in gross sales**.

**Assumptions** (RevenueCat *State of Subscription Apps 2026*, calendar 2025, unless marked):
- **Install to trial start:** 5.2% base. Education's median download-to-trial is 6.5%; North America's is 7.1%.
- **Trial to paid (yearly, 14 days):** 38% base. The all-category median for 10–16-day yearly trials is 43%. I discount it because practice habits fade in music apps (my estimate).
- **Direct purchases** (monthly or lifetime, no trial): 25% of buyers in scenario A, 20% in scenario B.
- **Install to paid:** about 2.6% base, 1.8% low, 3.4% high. The overall median at day 35 is 2.0%, and North America's is 2.8%.
- **Monthly subscribers:** pay about 4 months on average (my estimate).
- **Yearly renewal:** 35% at year 1 and 60% after that (my estimate; the 2026 report gives no renewal figure).

| | A: current ($34.99 / $6.99 / $89.99, lifetime on every paywall) | B: recommended ($49.99 / $9.99 / $149.99, no lifetime on onboarding) |
|---|---|---|
| Buyer mix (yearly / monthly / lifetime) | 75 / 15 / 10 | 80 / 14 / 6 |
| Net in a buyer's first year | **$31.55** | **$43.67** |
| New buyers a month for $10k net (year 1, no renewals yet) | **317** (about 240 yearly, so about **630 trial starts** a month, 21 a day) | **229** (about 183 yearly, about **460 trial starts** a month, 15 a day) |
| Installs a month needed at 1.8% / 2.6% / 3.4% install-to-paid | 17,600 / **12,200** / 9,300 (≈ 590 / **405** / 310 a day) | 12,700 / **8,800** / 6,700 (≈ 425 / **295** / 225 a day) |
| Year-1 net per install (the most you can spend to acquire one) | $0.57 / **$0.82** / $1.07 | $0.79 / **$1.14** / $1.48 |
| Steady state once yearly renewals stack (year 3) | 200 buyers a month, about 7,700 installs a month at 2.6% | **140 buyers** a month, about **5,400 installs a month** at 2.6% |

**Is it plausible against GuitarTuna, Yousician, Simply and Fender?**
- **Organic search.** "Guitar tuner" and "learn guitar" belong to apps with 139K–400K ratings, so Timbre's first 6 months will run on the instrument long tail: violin, cello, ukulele, mandolin and banjo tuners, and learn violin. Ranking top-10 on 8–12 such queries across 10 storefronts can plausibly bring **150–350 installs a day** (my estimate, from comparable music-utility launches; check it in Apple Ads' search popularity).
- **Paid acquisition.** Apple Ads for "learn guitar"-type terms usually costs more per install than the $0.82 a year-1 install earns in scenario A, so paid acquisition loses money until prices and conversion improve. In scenario B with the onboarding fixes ($1.14–$1.48 a year, about $1.90 over three years), paid acquisition breaks even on long-tail instrument keywords.
- **My call:**
  - As it ships, with scenario A, no analytics, no Custom Product Pages and a silent preview: **under 10%** chance of $10k net a month within 12 months.
  - With items 1–8 done and scenario B: **about 30–40% within 12–18 months**, mostly from violin, cello and ukulele.
  - With licensed songs on top: the first real shot at a #1 position in a sub-niche.

---

## 5. How to take #1 on growth, ranked by impact

1. **Measure first: about one week of work, which every other move depends on.** Set TelemetryDeck, then log `app_open`, `onboarding_step`, `mic_permission`, `paywall_view{reason,variant}`, `paywall_close`, `purchase{trial,price,currency}`, `purchase_cancelled` and `purchase_failed`. Add an App Store Server Notifications v2 endpoint for trial-to-paid, renewals, refunds and cancellations, and the AdServices token. Add a remote JSON flag for the paywall variant and yearly product ID. Watch four numbers weekly: install→trial (target ≥ 7%), trial→paid (≥ 40%), D7 retention (≥ 25%), and net revenue per install (≥ $1.10).
2. **Win the instruments GuitarTuna ignores.**
   - Build 9–12 keyword-linked Custom Product Pages (violin, cello, ukulele, bass, mandolin, banjo, voice, chromatic and strobe, ear training). Each opens onboarding with that instrument chosen, via a `tune?instrument=` deep link read by `OnboardingView`.
   - Make every instrument's standard tuning free, so those pages turn into 5★ ratings.
   - Make violin the flagship: Trala charges $119.99 for less.
3. **Put the lessons' magic before the paywall.** Add "Play my first songs" as the first goal. For beginners, add a 30-second first chord, heard and lit string by string (reuse 52b), before the plan. Retitle the welcome screen to "Tune in seconds. Then learn to play." The paywall then sells what the player has just felt.
4. **Price and packaging.**
   - Yearly $49.99 with the 14-day trial (keep 14: yearly trials of 10–16 days convert at 43% against 33% for 5–9), monthly $9.99, lifetime $149.99 off onboarding.
   - Family Sharing on.
   - A 7-day monthly intro as the exit offer, a win-back offer, and the Billing Grace Period on.
   - Then test $49.99 against $59.99.
5. **Songs people know, or the next best thing.** License a starter pack of 20–30 recognisable songs and lead Songs, the paywall rail and screenshot #5 with them. Until then, make "Play any song: paste the chords, play along with Apple Music" a listing bullet, a paywall outcome and the first shelf on Songs.
6. **A store page that converts.**
   - Rebuild the App Preview with sound and captions, opening on the highway.
   - Change screenshot #1 to "Free tuner. No ads.", and use a first chord, not "Show me at rest", for #3.
   - Localize screenshots and captions for the 9 locales and refresh their stale text.
   - Run In-App Events (December carols, a 30-day ukulele challenge).
   - Run Product Page Optimization on the first three frames and the icon.
7. **Social proof and rating speed.**
   - Before launch: a TestFlight cohort of 300–500 players, two teacher quotes.
   - At launch: a Featuring Nomination.
   - After launch: prompt for a review after the first song completed at 3 stars, as well; add a rating line to the paywall at ≥ 4.6★ from ≥ 200 ratings; reply to every review under 4★.
8. **Retention.** Ask for reminders on a full card with the streak at stake right after the first-tune reward. Write a value-recap trial-end notification. Promote the widgets on day 2, through a Today card and a TipKit tip.
9. **Virality.** Put an https link that falls back to the App Store on every `ShareLink`, set `appStoreLink`, and add "Give a friend a month" with one-time offer codes.

---

## 6. What only the owner can do

- **Accounts and settings:**
  - Create the TelemetryDeck app and set `TELEMETRYDECK_APP_ID`, then update the App Privacy label.
  - Host the App Store Server Notifications v2 endpoint and the remote-config JSON on the custom domain, and move the privacy policy there.
  - Enrol in the Small Business Program.
- **App Store Connect:**
  - Final prices, the 14-day yearly trial, the 7-day monthly intro offer, win-back offers and the Billing Grace Period.
  - Family Sharing on the yearly plan and lifetime.
  - Offer-code campaigns (referral, teachers, press).
  - 9–12 Custom Product Pages with keyword assignment, Product Page Optimization tests, In-App Events and a Featuring Nomination.
  - Set `appStoreLink` once the app ID exists.
- **Money:**
  - An Apple Ads test budget of about $1.5–3k a month on exact-match instrument keywords, once RPI is measured.
  - Song licensing for a recognisable starter pack.
- **People and recordings:**
  - A player with a real guitar and violin to record App Preview audio.
  - Translators for the captions and the refreshed localized listings.
  - A TestFlight community and 2–3 music teachers for quotes and endorsements.

---

## 7. Sources

- [GuitarTuna: Tune & Play Guitar, App Store (US)](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389): subtitle, 4.8★ from 149K ratings, #21 Music, Tools / Play / Learn tiers.
- [GuitarTuna, App Store (Canada)](https://apps.apple.com/ca/app/guitartuna-tune-play-guitar/id527588389) and [App Pricing Lab: GuitarTuna in-app purchases](https://apppricinglab.com/iap/apple/527588389): price cross-check.
- [Yousician: Learn & Play Guitar, App Store (US)](https://apps.apple.com/us/app/yousician-learn-guitar-bass/id959883039): subtitle, 4.6★ from 139K ratings, $119.99–$179.99 yearly.
- [Simply Guitar - Learn Guitar, App Store (US)](https://apps.apple.com/us/app/simply-guitar-learn-guitar/id1476695335): subtitle, 4.7★ from about 400K ratings, in-app purchases up to $199.99.
- [Justin Guitar Lessons & Songs, App Store (US)](https://apps.apple.com/US/app/id1176125504) and [App Pricing Lab: Justin Guitar](https://apppricinglab.com/app/apple/1176125504): subtitle, 4.9★ from 22K ratings, $64.99–$129.99 yearly.
- [Fender Play, App Store](https://apps.apple.com/app/id1226057939): "Start for free", "14 days free", gear discount.
- [Subger: Fender Play pricing](https://subger.com/en/service/fender-play) and [MusicRadar Fender Play review](https://musicradar.com/reviews/fender-play-review): price references (conflicting or dated, flagged as such above).
- [Trala: Learn Violin, App Store (US)](https://apps.apple.com/us/app/-/id1143205265): 4.7★ from 4.9K ratings, $19.99/mo, $119.99/yr.
- [RevenueCat, State of Subscription Apps 2026](https://revenuecat.com/report): download-to-trial, trial-to-paid, download-to-paid, revenue per install, the Education medians ($44.99 yearly), day-0 trial cancellations.
- [RevenueCat, "How long should your free trial be?" (Sep 2026)](https://www.revenuecat.com/blog/growth/free-trial-length): yearly trials of 10–16 days convert at 43%, 5–9 days at 33%.
- [Adapty, "App Store custom product pages: how to use them in 2026"](https://adapty.io/blog/custom-product-pages-app-store/): keyword-linked Custom Product Pages from July 30, 2025, and 70 pages from October 29, 2025.
- The Fender Tune App Store page ([id1107017950](https://apps.apple.com/us/app/-/id1107017950)) could not be read in this session, so it is not quoted.
