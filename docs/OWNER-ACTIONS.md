# Timbre: what only the owner can do

**Historical owner inventory.** [Current App Store readiness](ios/readiness/STATUS.md) supersedes resolved translation,
publication, provenance and developer-task items below. Paid growth recommendations remain optional.

Every action no developer or tool can take for you: accounts and money, licences, recordings, people, decisions, and the App Store programme. As of **25 October 2026** (`v2/foundations` at `0bbf273`).

This list merges the October 2026 review panel's findings with the repository's owner notes, with duplicates removed. The panel was six jurors (visual, delight, inclusivity, technical, growth and category) and a foreman, plus the integration notes from the last work wave. The repository notes are in:

- [ios/APPLE-DELIVERY.md](ios/APPLE-DELIVERY.md) and [ios/APP-STORE-LISTING.md](ios/APP-STORE-LISTING.md);
- [ios/APP-STORE-LISTING-LOCALIZED.md](ios/APP-STORE-LISTING-LOCALIZED.md) and [ios/PRIVACY.md](ios/PRIVACY.md);
- [ios/AUDIO-DEVICE-TESTS.md](ios/AUDIO-DEVICE-TESTS.md) and [l10n/HANDOFF.md](l10n/HANDOFF.md);
- the content docs in [content/](content/).

The step-by-step release path is [ios/RELEASE-CHECKLIST.md](ios/RELEASE-CHECKLIST.md). This page is the owner's to-do list around it.

**How to read it**
- **Release**: blocks the 2.0.0 submission or launch.
- **Release (claim)**: blocks one claim or feature on the store page, but not the submission.
- **Growth**: after launch, toward $10k a month and the panel's "#1 on every angle".
- **Money** figures are the panel's planning estimates, not quotes. "Not estimated" means the panel gave no figure.
- **Impact** is the panel's expected effect on revenue, or on its 0–10 score (8.3 overall today).

---

## 1. Priority order

| # | Action | Blocks | Money (panel) | Expected impact (panel) | How |
|---|---|---|---|---|---|
| 1 | Developer Program, Paid Apps Agreement, tax and banking, EU trader status, Small Business Program | **Release** | $99 a year (Apple's fee) | Nothing sells without the agreement; the program cuts Apple's commission from 30 % to 15 % | [Checklist A1–A4](ios/RELEASE-CHECKLIST.md#phase-a-apple-accounts-and-identifiers-owner) |
| 2 | Decide the 2.0.0 languages: English only now, or pay for translations first | **Release** | Translation cost (§5) | "Unblocks the App Store submission and removes the legal exposure" of renewal terms in English in 48 storefronts | [Checklist 0.2, E2](ios/RELEASE-CHECKLIST.md#phase-0-decisions-owner-today), §5 |
| 3 | App record, identifiers (with MusicKit), Admin API key, GitHub `apple-delivery` secrets with you as required reviewer | **Release** | — | Signed builds can be delivered, and only with your approval | Checklist A5–A7, C3 |
| 4 | Prices and products: 3 products, Family Sharing, Billing Grace Period | **Release** | — | Net per buyer rises from about **$31.55 to $43.67**; installs needed for $10k a month fall from about **12.2k to 8.8k** (at 2.6 % install-to-paid) | Checklist D1–D5, §8 |
| 5 | A domain: republish the privacy policy; write a support page (a required field); host the remote settings file; create the TelemetryDeck app ID | **Release** (privacy policy, support page); prerequisite for $10k | A domain (a few dollars a year; not a panel figure) | "Every funnel event is dark until the ID is set, so there is no price test, no D7 and no revenue per install. It is the prerequisite for $10k a month and for any ad spend." | Checklist B1–B5, C4 |
| 6 | A human review of PR #2, the merge into `main`, `gate` required; an independent senior iOS reviewer from now on | **Release** | Not estimated | "Turns 'never vibe-coded' from a grep into a review trail an acquirer will price in" | Checklist C1–C2, §6 |
| 7 | Run and sign off the device test sheet; a small device lab | **Release** | Not estimated | Finds the microphone, audio-session and haptic problems a simulator can't | Checklist Phase F |
| 8 | Confirm the provenance and licence of the 68 "provided" instrument photos | **Release** (legal) | Replacement renders or photos, if needed | Avoids "a public 'AI-generated instruments' call-out and any licensing exposure" | §4 |
| 9 | Approve the store page: screenshots, **Apple Watch screenshots** (required), App Preview and its sound, text, App Privacy, age rating | **Release** | — | "The preview and store #1 are the moment people choose" | Checklist Phase H |
| 10 | The **Holiday Carols** In-App Event: art, then submit it with 2.0.0 by **about 10 November**; carols free 1–7 December | Growth (time-boxed) | Event art (§4) | Seasonal discovery in December | Checklist H10, K4 |
| 11 | Song licensing: a starter pack of 20–30 songs people know | Growth | **$15–60k** in advances plus revenue share; an attorney at $300–600 an hour for 1–2 hours | **The largest single lever**: about **+0.5 to +0.8** each on Category and Growth. "It is what a 'learn guitar' searcher picks on." | §3 |
| 12 | Teacher video, a rigged hand, ukulele and banjo 3D models | Growth | **$8–15k** (two shoot days); **$0.5–2k** (hand) | Closes the teaching-imagery gap with Fender Play and Justin, and gives store frame #3 "a teacher's hands" | §3 |
| 13 | Brand: an icon designer, then an art director and illustrator | Growth | **$4–10k** + **$8–15k** | Visual reaches 9.0 or more, and Timbre "looks like a brand next to GuitarTuna in search" | §4 |
| 14 | A sound designer and real instrument recordings | Growth | **$3–8k** + **$1.5–3k** | Honest "Hear it" audio, a band worth hearing on the speaker and in the preview, and a published accuracy claim no competitor can make | §3, §4 |
| 15 | The remaining translations | Growth | "Low tens of thousands of dollars at agency rates" | "A third of the market's first screen is in its own language" | §5 |
| 16 | Testers and outside voices: a TestFlight cohort, teachers, blind and low-vision, left-handed and deaf testers, RTL reviewers | Growth (start the cohort before launch) | Not estimated (paid testers) | Makes the VoiceOver and left-handed claims shippable; social proof before launch | §6 |
| 17 | The App Store programme: Custom Product Pages, Product Page Optimization, a January featuring nomination, Accessibility Nutrition Labels, then Apple Ads | Growth | Apple Ads **$1.5–3k a month**, only after revenue per install is measured | "The long tail (violin, cello, ukulele) is where Timbre can rank within months", and Timbre would hold the category's only filled accessibility label | §7 |

---

## 2. Release blockers, consolidated

Each one is a step in [RELEASE-CHECKLIST.md](ios/RELEASE-CHECKLIST.md). Tick them here as they're done.

- [ ] **Apple Developer Program** active, with you as Account Holder (A1).
- [ ] **Paid Apps Agreement, tax and banking** Active (A2).
- [ ] **EU trader status** entered and verified. A trader's address, phone and email are shown on the EU product page, so use business contact details (A3).
- [ ] **Small Business Program** enrollment (A4). It doesn't block release, but the 15 % rate starts only after the fiscal month of approval, so enroll now.
- [ ] **Identifiers:**
  - App Groups on the four bundle IDs;
  - **MusicKit** on the app ID: the description advertises "listen to the original on Apple Music", and without the service the card says "isn't available";
  - Game Center only if 2.0.0 uses it (A5).
- [ ] **App Store Connect app record** "Timbre: Guitar Tuner & Lessons"; note its Apple ID (A6).
- [ ] **Admin API key** (`.p8`, Key ID, Issuer ID) and the **Team ID** in the GitHub `apple-delivery` environment, with **you as its required reviewer** and `main` as its only branch (A7, C3).
  - Standing rule: **nobody dispatches Apple delivery without you**, and no automated agent ever does.
- [ ] **Language decision for 2.0.0.** Every non-English locale lacks 106 legal, permission or VoiceOver strings today. Either ship English only (`ship_min_coverage: 95`), or pay for those strings first (§5). Never submit an `internal_testflight_untranslated` build.
- [ ] **Prices and products** created in the **Timbre Pro** group, with Family Sharing on the yearly plans and lifetime, and the Billing Grace Period in sandbox first (D1–D5, §8).
- [ ] **Privacy policy** on your domain, republished from [PRIVACY.md](ios/PRIVACY.md). The live github.io page still says analytics stay on the device. Have the developer point `TIMBRE_PRIVACY_POLICY_URL` at it (B2, C5).
- [ ] **Support page**: App Store Connect requires a Support URL (B3).
- [ ] **TelemetryDeck app ID** and the remote settings URL as repository variables. Not a hard blocker, but launching without analytics means no measured funnel (B4–B5, C4).
- [ ] **PR #2 reviewed by a person and merged**; `gate` required on `main` (C1–C2). PR #2 has 302 commits, about 365k added lines and 0 reviews. On `0bbf273` the required `gate` is green; the `accessibility` job (an enforced contrast audit) is red.
- [ ] **Device sheet** run on real phones, a watch and headphones, and **signed off by you**. "A fail blocks the release until it is fixed or the owner signs it off." This includes the haptic-bleed test of Tune by feel with the microphone open, on iPhone 15, 16 and 17 if possible (Phase F).
- [ ] **Instrument photos:** confirm where the 68 "provided" photographs in `ios/Sources/TimbreCore/Resources/photos.json` came from, and that you may use them. The panel noticed identical inlays on a banjo, a bouzouki and a dreadnought. If you can't show the licence, replace them with renders under one light (`tools/models/cards.py`) or commissioned photos before launch. The panel's rule: "don't ship instrument photos whose provenance you can't show."
- [ ] **Store page approvals** (Phase H):
  - the 9 iPhone and 4 iPad frames from CI;
  - **Apple Watch screenshots**, which no CI job makes and which are required because the build includes a watch app;
  - the App Preview, which is optional: upload only a cut that passed its gates;
  - the App Privacy answers, the age rating (4+), the review contact and notes.
- [ ] **Game Center decision.** Off in 2.0.0, unless the art for 31 achievements and 9 challenges and activities is ready by 3 November. If it's off, delete the Game Center bullet from the description.

---

## 3. Content, licences, recordings and teaching media (Growth unless marked)

### Songs people know
- **Starter pack: 20–30 recognisable songs** (the category juror allows for up to 100).
  - **Cost:** $15–60k in advances plus revenue share.
  - **Begin with the songs every teacher uses in month one:** *Knockin' on Heaven's Door*, *Horse with No Name*, *Riptide*, *Wonderwall*, *Let It Be*, *Stand by Me*, *Hallelujah*, *Brown Eyed Girl*, *Three Little Birds*, and *Somewhere Over the Rainbow* for ukulele.
  - **Impact:** the biggest single move on Category and Growth (about +0.5 to +0.8 each).
- **The next 30 days**, from [SONG-LICENSING-PLAYBOOK.md](content/SONG-LICENSING-PLAYBOOK.md):
  - [ ] Book 1–2 hours with a music-licensing attorney ($300–600 an hour, an estimate) for a one-page term sheet.
  - [ ] Build an outreach list: 15 emerging artists who control 100 % of their songs, and 10 independent publishers or administrators.
  - [ ] Ask Hal Leonard (Muse Group), Musicnotes "Official Licensing", LyricFind and Musixmatch for quotes and minimums. This is fact-finding; sign later.
  - [ ] Before signing anything, the developer builds the licensing plumbing: per-storefront territory allow-lists, licence dates, a remote kill switch and a usage ledger.
- **Staged plan:**
  - emerging artists first (months 1–4: $0–1,000 a song, or 10–20 % of what the song earns);
  - independent publishers next (months 3–9: a revenue-share pool plus perhaps $50–200 a song a year);
  - majors and aggregators only at about $50k MRR or after funding.
- **Budget rule:** keep content costs at or below about 15 % of net revenue until licensed songs prove they lift conversion. The `song_request` event (Songs → Request a song) tells you which songs people ask for, by country, and gives you something to show publishers.
- **Paper the Originals.** Get a signed work-made-for-hire or assignment agreement from every person who contributed to the **50 Originals** (composition, lyrics, arrangement, any stems), with a no-copying warranty. Where AI drafted a song, keep dated records of the human edits. This is release hygiene; do it now.
- **Terms for "Your songs".** The playbook asks for a clause saying users import only charts and recordings they have the right to use. Apple's standard EULA can't be edited, so add your own licence agreement in App Store Connect (App Information → License Agreement), or link your own Terms page. *Release (claim): recommended before launch.*
- **Apple Music.** Get Apple's written answer before anything beyond the plain, user-started player ships.

### Recordings
- **Real instrument sample sets** (a session day plus editing, **$1.5–3k**): soprano and low-G ukulele, mandolin and 5-string banjo, about 30 notes each at two velocities.
  - Today the ukulele is a nylon guitar, the mandolin a steel guitar and the banjo synthesized ([AUDIO-SOURCES.md](content/AUDIO-SOURCES.md), Stand-ins).
- **Band stems** (real drums, bass and keys) for the 10 strongest Originals. You own the songs, so the stems can go in the app and the preview.
- **A real-world test corpus:** about 1,000 labelled notes, strums, chords and muted strums.
  - **What it covers:** 20 instruments; iPhone SE to 17 Pro; the built-in microphone and AirPods; a quiet room and a café; chunks, chops and mutes. A reference tuner provides the ground truth.
  - **Where it goes:** `Tests/Fixtures/RealWorld/`.
  - **What it enables:** "a published accuracy claim no competitor can make".

### Teaching media and 3D
- **Teacher video.** One guitar teacher, one ukulele teacher and one violin or cello teacher.
  - **What to shoot:** the 8 planned clips first, bow hold first ("no competitor has violin lessons that listen"), then about 30 more, plus short unit intros.
  - **Cost:** two shoot days, **$8–15k**. Get signed releases.
- **A stylised rigged hand** for "Show me" (**$0.5–2k**, work for hire). The app's hook, `ShowMeController.handRig`, is ready. Optionally, a half-day shoot of real fretting hands for store frame #3 and onboarding (model releases needed).
- **Ukulele and banjo `usdz` models** (in the same commission), added through `models-manifest.json`.
- **Larger studio renders**, so the studio head fills 55–60 % of the stage. The integration notes left this to the owner; the `3D assets` workflow (`tools/models`) can render them once you approve the run and review the result.

### Content decisions
- [ ] **Free tier:** keep unit 2 Pro, and A/B test opening it with the remote settings' `flags.unit2Free` once analytics run. The panel also recommends **free basic scales**; scales are Pro today, so that needs a code change if you approve it.
- [ ] **Lifetime at $99.99:** the category juror suggests testing it. The app's price tests cover only the yearly plan (`_b`, `_c`), so a lifetime test needs a second lifetime product and a small code change.
- [ ] **A low-G ukulele course**, and low-G songbook editions where folding is needed.
- [ ] **US carol tunes:** whether the US listing leads with Mueller's "Away in a Manger" (the US tune) rather than Kirkpatrick's (the UK one).

---

## 4. Design, brand and sound hires (Growth)

| Hire | Deliverables | Money and time (panel) | Why |
|---|---|---|---|
| **Icon and brand designer** | The mark. An Icon Composer icon with real Default, Dark, Clear and Tinted variants: today's dark icon is byte-identical to the light one, with a mean luminance of 31.8/255. A logotype. Motion and sonic signature guidelines. Alternate icons for the Product Page Optimization icon test. The watch icon. | **$4–10k**, 1–2 weeks | Brand at thumbnail size is where GuitarTuna wins today |
| **Art director and illustrator** | A pastiche review of all 50 Originals sleeves. A new, non-derivative *Kite Weather* cover: the derivative motif is retired in code, so this is optional now. 6 spot illustrations (microphone, reminder, listen, ear, empty states) and medal art. Direction for the store set and the preview re-cut. | **$8–15k**, 2–3 weeks | Visual 9.0+, and no derivative design in the ad's second frame |
| **Event and Game Center art** (the art director, or a freelancer) | The Holiday Carols event: a 16:9 card (1920 × 1080 or larger) and a 9:16 details image (1080 × 1920 or larger), **due early November**. When Game Center ships: 31 achievement images (1024 × 1024) and 9 challenge plus 9 activity images (3840 × 2160). A subscription image, if you promote offers on the App Store. | Not estimated | The event and Game Center can't be submitted without them |
| **Sound designer** | Master the three-note motif; a kit of about 12 UI cues tuned for phone speakers; a short "speaker-safe" drum kit for the speaker band | **$3–8k** | The app sounds as finished as it looks |
| **Instrument imagery** (decision) | Keep the 68 "provided" photos only with proven provenance; otherwise commission renders under one light, or photography | Not estimated | A legal and reputational risk (§2) |

**Approvals only you can give**
- [ ] The App Preview's soundtrack: a device capture with audio, or the rendered mix. Choose the Original under the highway, or license a 25-second cue. Confirm the rights to every sound in the cut.
- [ ] The store frames and their captions.

---

## 5. Translations (Release decision, then Growth)

**Owner decision, 26 October 2026:** all 49 app languages (English + 48 translations), including all lesson content, selected automatically from the phone language unless the user explicitly overrides it. The earlier English-only/nine-language rollout suggestions below are historical, superseded proposals, not current authorization. All 39 newly required lesson locales need 6,080 keys each (237,120 additional pairs). See [current handoff](l10n/HANDOFF.md); `python3 tools/l10n/lessons.py --strict` must pass before external delivery. Native-language and device review are still required.

**Where it stands** (from `tools/l10n/shipping.py` and `critical.py`, 25 October 2026):

| | Strings | Locale-string pairs |
|---|---:|---:|
| Launch-critical per locale: 11 legal (renewal terms), 1 permission prompt, 94 VoiceOver | 106 | 954 for the 9 lesson languages; 5,088 for all 48 |
| The rest of the interface (every locale is at 67.7 %) | 639 | 30,672 across 48 locales |
| Lessons (the 9 lesson languages are at 75.9 %) | 1,467 | 13,203 |

**Decisions and actions**
- [ ] **2.0.0:** English only (the delivery input `ship_min_coverage: 95`). Each locale then joins in a 2.0.x update once it reaches 95 % with no critical gap: `python3 tools/l10n/shipping.py --min 95 --critical` lists it.
- [ ] **The panel's target set:** English plus de, es, fr, it, ja, ko, pt, ru and zh-CN, with Arabic and Hebrew only after native RTL review. Add the other 39 locales as each reaches 95 %. Stop claiming "49 languages" until then; the listing already makes no language claim.
- [ ] **Pay for translations.**
  - The 106 critical strings first (954 pairs for the 9), with a native review of the 11 legal strings.
  - Then the 639 interface and 1,467 lesson strings for the 9.
  - The whole job is "low tens of thousands of dollars at agency rates".
  - The repository's rule is that "translations are done by people, never by a machine". The panel suggested machine drafts with native review for the critical strings. Choose one, and tell the translators.
- [ ] **Send the work:** `tools/l10n/todo/<locale>.json` and the brief [l10n/HANDOFF.md](l10n/HANDOFF.md). The developer imports what comes back (`report.py --import`).
- [ ] **Localized store pages** for each shipped locale ([APP-STORE-LISTING-LOCALIZED.md](ios/APP-STORE-LISTING-LOCALIZED.md)):
  - the name, subtitle and keywords are current;
  - the promotional text, description and What's New need translating, and so do 117 caption rows (13 a locale);
  - each locale needs its in-app purchase display names, a native-speaker check of its keywords, and its Custom Product Page keywords added to its field;
  - two open points: the German "Apple-Account" spelling, and Mexican "Configuración" against the app's "Ajustes".

---

## 6. People and testers

- [ ] **An independent senior iOS reviewer.** They review every PR and sign off the Swift 6 and architecture work, with branch protection on `main`, squash merges, no `[skip ci]` on `ios/`, and short architecture decision records.
  - 302 of the repository's 303 commits are authored by the tool, and PR #2 has 0 reviews. "The owner's 'never vibe-coded' bar is met by human review, branch protection and squash merges."
- [ ] **A TestFlight cohort of 200–500 players** before launch, through a public link. Two or three music teachers (ukulele, violin) for endorsements and early ratings. Real quotes only, with consent.
- [ ] **Paid blind and low-vision testers** (AppleVis, NFB or RNIB networks, or Fable) for Unit 1 and one song. **No VoiceOver claim**, in the listing or the Accessibility Nutrition Label, until they finish Unit 1, the notes step speaks the next note, and the play-along's cues land on time.
- [ ] **Left-handed and upside-down guitarists**, to check the mirrored 3D hand and charts.
- [ ] **A deaf or hard-of-hearing player**, to check Tune by feel.
- [ ] **Native reviewers for Arabic and Hebrew** before those ship.
- [ ] **A device lab:** an iPhone SE, a mid-range iPhone, a Pro, an iPad, AirPods, a wired headset and an Apple Watch. Haptics on iPhone 15, 16 and 17.
- [ ] **CI minutes:** the gate costs 60–90 macOS runner-minutes a push; that matters if the repository goes private (§9).
- [ ] **Outreach:** an AppleVis listing, and a pitch to Apple's accessibility editors. Tune by feel is the story.

---

## 7. The App Store programme (Growth; the order matters)

| When | Action | Notes |
|---|---|---|
| With 2.0.0 (submit by about 10 Nov) | **Holiday Carols In-App Event**: December 1–31, badge Special Event, deep link `timbre://songs`, published from 17 November. Carols free December 1–7 through the remote settings' `freeSongs`, cleared on December 8. | An app's first event goes in with its first version. Text and dates: [checklist H10](ios/RELEASE-CHECKLIST.md#h10-the-holiday-carols-in-app-event-submitted-with-200), [K4](ios/RELEASE-CHECKLIST.md#k4-carol-week) |
| With 2.0.0 | **The keyword field** (`violin,ukulele,uke,cello,bass,mandolin,banjo,fiddle,chromatic,strobe,ear training,metronome,chord`) | Custom Product Pages can take keywords only from the latest *approved* version's field |
| With 2.0.0 | **Accessibility Nutrition Labels**: Dark Interface, Differentiate Without Color Alone and Reduced Motion now; Sufficient Contrast once the CI contrast audit passes; Larger Text after the AX5 captures pass; VoiceOver only after §6's blind-tester pass | None of the six competitors fills these in |
| After approval | **Custom Product Pages**: violin, cello and ukulele first; then bass, mandolin, banjo, chromatic and ear training once their first frames are store frames | [APPLE-DELIVERY.md §9.2](ios/APPLE-DELIVERY.md#92-custom-product-pages). Deep links run only when someone taps "Open". |
| After approval | **Win-back offers** (a subscription must be approved first) and the **"Give a friend a month" offer code**. One-time codes need Ready for Distribution; then set `referralCode` in the remote settings. | [Checklist K3](ios/RELEASE-CHECKLIST.md#k3-growth-set-up-that-needs-an-approved-app-in-this-order) |
| About 2 weeks after launch | **Price test**: `timbre_pro_annual_b` at $59.99 against $49.99, 50/50 through the remote settings | Not before the analytics have a baseline |
| Early December | **Featuring nomination** for January's "learn something new" window, with the Tune by feel story and a device video of the pulse. The December window has passed. Nominate again for each major update. | At least 3 weeks ahead, 6 for a holiday window |
| January | **30-day ukulele challenge** In-App Event (badge Challenge), deep link `timbre://tune?instrument=ukulele.soprano.4` | |
| After launch, one at a time | **Product Page Optimization**: the first frame, then the preview's poster, then the icon | Apply a winner only at 90 % confidence or more |
| Once revenue per install is measured | **Apple Ads**, about **$1.5–3k a month**, exact-match instrument keywords, each ad group pointing at its Custom Product Page. Stop any keyword whose cost per install exceeds the install's first-year revenue. | Map each ad group to its instrument in the remote settings |
| Ongoing | **Ratings and reviews**: answer every 1–3★ review within two days | The paywall's rating line appears by itself at 4.6★ from 200 ratings per storefront. Never a hand-typed or global rating. |

---

## 8. Pricing and offers (Release decisions)

| Decision | Panel recommendation | Expected impact |
|---|---|---|
| Yearly `timbre_pro_annual` | **$49.99**, with a **14-day free trial** for new subscribers | Yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 days |
| Monthly `timbre_pro_monthly` | **$9.99**, **no introductory offer**. The build would disclose one correctly now; still none, with win-back offers and offer codes instead. | Keeps the money screen honest |
| Lifetime `timbre_plus_lifetime` | **$149.99**, kept **off** onboarding's paywall by default | Anchors the yearly plan |
| Family Sharing | **On** for the yearly plans and lifetime. It can't be turned off again. | Parents buy for their children; the paywall says so by itself |
| Billing Grace Period | **On**: 16 days, all renewals. Sandbox first, then production after the TestFlight test. | The code keeps Pro during grace and shows the billing banner |
| Small Business Program | **Enroll now** | 15 % commission instead of 30 % |
| Price test | `timbre_pro_annual_b` at **$59.99**, after launch | Measured by paywall variant in TelemetryDeck |
| Whole package | As above | Net per buyer **$31.55 → $43.67**; installs needed for $10k a month **12.2k → 8.8k** at 2.6 % install-to-paid. The RevenueCat 2026 Education medians are $44.99 a year and $9.99 a month. |

**Don't:**
- strike through a computed "was" price in EU or UK storefronts;
- announce a test before it can run;
- buy installs before analytics measure revenue per install.

---

## 9. Accounts, keys, addresses and policies (an inventory you own)

| Item | Where it lives | State on 25 Oct 2026 |
|---|---|---|
| Apple Developer Program (Account Holder) | developer.apple.com | Unknown here: confirm (A1) |
| App Store Connect app record and its Apple ID | App Store Connect | Not created |
| Admin API key (`.p8`), Key ID, Issuer ID, Team ID | Your password manager, plus GitHub `apple-delivery` secrets only | Not created |
| `apple-delivery` environment, with you as required reviewer | GitHub → Settings → Environments | Set it up (C3) |
| Repository variables `TELEMETRYDECK_APP_ID`, `TIMBRE_APP_STORE_ID`, `TIMBRE_REMOTE_CONFIG_URL`, `TIMBRE_SHARE_URL` | GitHub → Settings → Variables | Not set |
| A domain, privacy policy, support page, remote settings file, share page | Your host (GitHub Pages with a custom domain is enough) | Only the github.io privacy page exists, and it is out of date |
| TelemetryDeck account and app | telemetrydeck.com | Not created |
| App Store Server Notifications v2 endpoint | Needs a server; optional for 2.0.0 | None. The app logs renewals and refunds itself meanwhile. |
| Sandbox Apple Accounts | App Store Connect → Users and Access → Sandbox | Create 2–3 (A9) |
| **Repository visibility** | GitHub → Settings | **Public.** Anyone can read the source and the store strategy. Going private protects them, but costs macOS Actions minutes and needs a paid plan for Pages. Decide before launch. |
| **EU analytics consent** | Policy | Sharing is on by default, with a switch in Settings. Events are anonymous, not linked and not used for tracking. Get advice on whether EU storefronts need an opt-in. |
| **Crash reporting** | Policy | Xcode Organizer plus MetricKit through TelemetryDeck today. Decide whether that is enough. |
| `main` branch protection | GitHub → Settings → Rules | **Not protected.** Require `gate` (C2). |
| iCloud | App ID capability | Not needed: nothing syncs yet. When sync is built, enable iCloud on the App ID and add the entitlement. |
| Associated Domains | App ID capability, plus a file on your domain | Not needed for 2.0.0. It lets share links open the app directly (universal links): the entitlement plus an `apple-app-site-association` file on the share page's domain. |

---

## 10. Money at a glance (the panel's estimates)

| Item | One-off | Recurring | Blocks |
|---|---:|---:|---|
| Apple Developer Program | — | $99 a year (Apple's fee) | Release |
| Domain and hosting | — | A few dollars a year (not a panel figure) | Release |
| Music-licensing attorney (1–2 hours) | $300–1,200 | — | Before signing songs |
| Song licensing starter pack (20–30 songs) | $15–60k in advances | Revenue share; keep content at or below 15 % of net | Growth |
| Teacher video (two shoot days) | $8–15k | — | Growth |
| Rigged hand, ukulele and banjo models | $0.5–2k | — | Growth |
| Icon and brand designer | $4–10k | — | Growth |
| Art director and illustrator | $8–15k | — | Growth |
| Sound designer | $3–8k | — | Growth |
| Ukulele, mandolin and banjo recordings | $1.5–3k | — | Growth |
| Translations (everything, agency rates) | "Low tens of thousands" | — | The critical strings block each locale's release |
| Apple Ads (after revenue per install is measured) | — | $1.5–3k a month | Growth |
| Paid testers, device lab, reviewer, band stems, test corpus | Not estimated | — | Release (lab, reviewer); Growth |

**Priced one-offs, without songs or translations: about $25–54k.** With the song starter pack: about **$40–114k**.

---

## 11. What the panel expects

- **Today: 8.3 / 10 overall** (visual 8.8, delight 8.7, inclusivity 8.7, technical 8.5, growth 8.1, category 8.3).
  - Timbre is #1 outright only on inclusivity.
  - It splits visual, delight and category.
  - It loses technical narrowly to Yousician, and loses growth.
- **The code roadmap alone takes it to about 8.7.**
- **With the owner's levers, about 9.0–9.1 overall**, with Growth and Category at about 9.0–9.2. The levers are licensed songs, teacher clips and a hand, the icon and art direction, translations, the real-audio corpus and early ratings.
- "#1 on all angles is not reachable with code alone. Growth and Category are decided by songs people know, a visible teacher and social proof."
- **Revenue:** at the recommended prices, about **8,800 installs a month** reach **$10k a month** at 2.6 % install-to-paid. Measuring that needs the TelemetryDeck ID first.

## 12. What not to do (the owner's part of the panel's list)

1. Don't submit with `internal_testflight_untranslated` (formerly "allow untranslated"): the renewal terms would be English in 48 storefronts.
2. Don't add a monthly introductory offer. Use win-back offers and offer codes.
3. Don't plan Custom Product Page keywords that aren't in the approved keyword field. Don't count on the page's deep link for someone who opens the app from the Home Screen.
4. Don't claim VoiceOver, in the listing or the Accessibility Nutrition Label, before the blind-tester pass.
5. Don't caption "Play songs with the band" over a click track.
6. Don't show a hand-typed or global rating, and don't fake social proof.
7. Don't strike through a computed "was" price in the EU or UK.
8. Don't buy installs before the analytics ID is live and revenue per install is measured.
9. Don't ship sleeves that imitate famous covers, or instrument photos whose provenance you can't show.
10. Don't remove the honest trial timeline, the real-offers-only exit offer, or "Continue with the free tuner". They are the category's best monetisation ethics.
