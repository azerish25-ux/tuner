# REVIEW 16: Timbre (iOS), foreman's verdict for the six-juror panel

Panel (round 15 in brackets):
- visual: 8.8 (8.6);
- delight and innovation: 8.7 (8.3);
- inclusivity: 8.7 (8.3);
- technical and acquirer due diligence: 8.5 (8.1);
- growth and App Store editorial: 8.1 (7.4);
- category expert: 8.3 (7.8).

I read the brief, all six round-16 verdicts and REVIEW15. I then re-checked the claims that carry the most weight against:
- the code in `/home/claude/tuner/ios` (branch `v2/foundations`, HEAD `eb6ee5c`, working tree clean before and after my checks);
- the review16 frames and the App Preview (I measured the soundtrack myself);
- `curriculum.json` (scripted checks);
- the live CI state (`gh run list`, `gh api …/pulls/2/reviews`);
- one Apple documentation page.

My verification log is in §6. Where a juror is wrong or overstates, I say so there.

**The Arabic "₂E" readout is fixed in code** (commit `eb6ee5c`):
- `Readout.swift:299-300` and `PitchSniperView.swift:84` now pin the note's HStack left-to-right.
- The `l10n-ar-tabs` capture predates that commit, so I do not count ₂E as open.
- Because the commit is `[skip ci]`, no capture proves it yet. WP1's Arabic frame is the acceptance check.

---

## 1. Overall score: **8.3 / 10** (round 15: 7.7)

### How I combined the six angles (method kept)

I keep REVIEW15's method unchanged, for two reasons:
- **Consistency.** Movement is only meaningful if it is measured the same way.
- **It still points at the right thing.** The owner's bar is "#1 on all angles" and $10k a month, and the weakest angle (Growth) is still the one where Timbre is last against every competitor.

**Step 1: a weighted mean, 8.46.**
- Growth and Category carry ×1.5, because they decide user choice and revenue.
- Visual, Delight and Technical carry ×1.0.
- Inclusivity carries ×0.75, because it is where Timbre already leads.
- The sum is (8.8 + 8.7 + 0.75·8.7 + 8.5 + 1.5·8.1 + 1.5·8.3) / 6.75 = 57.125 / 6.75 = **8.46**.

**Step 2: a weakest-link gate, 8.3.** I average the weighted mean with the lowest angle: (8.46 + 8.1) / 2 = 8.28, which rounds to **8.3**.

**Reference points:**
- **Plain mean: 8.52.**
- **Sensitivity to ₂E:** crediting the fix to inclusivity (about 8.8) gives 8.29, which still rounds to 8.3.
- **The gate matters less than it did.** The spread between angles shrank from 1.2 to 0.7 points, so the gate now costs 0.18 points (round 15: 0.30). The method no longer dominates the result. It still says what the owner needs to hear: the store page loses.

I did not re-score any juror. My verification found no error that moves a score by more than about 0.1 (see §6).

### Movement since round 15

| | R15 | R16 | Δ |
|---|---|---|---|
| Visual | 8.6 | 8.8 | +0.2 |
| Delight | 8.3 | 8.7 | +0.4 |
| Inclusivity | 8.3 | 8.7 | +0.4 |
| Technical | 8.1 | 8.5 | +0.4 |
| Growth | 7.4 | 8.1 | **+0.7** |
| Category | 7.8 | 8.3 | +0.5 |
| Weighted mean | 8.00 | 8.46 | +0.46 |
| Weakest angle | 7.4 | 8.1 | +0.7 |
| **Overall** | **7.7** | **8.3** | **+0.6** |
| Plain mean (reference) | 8.08 | 8.52 | +0.44 |

### What the wave fixed (REVIEW15 blockers, verified)

| R15 | Blocker | Status | Evidence |
|---|---|---|---|
| B1 | Fresh installs in English | **Fixed** | `LocalStore.swift:12` is `TimbreLocalization.system`; de and ar launch tests exist. *(But 30 % of strings are untranslated; see B1 below.)* |
| B2 | One bad state file bricks the app | **Fixed** | Quarantine plus `.bak` fallback (`LocalStore.swift:289-308`); recovery screen. |
| B3 | Haptics muted while listening | **Fixed in code** | `AudioService.swift:821`. Needs a device check, including microphone bleed from Tune by feel. |
| B4 | Strums graded on timing only | **Fixed, with a new defect** | Per-stroke chord judge (`LessonSteps.swift:1747-1748`, `:1783-1800`). Muted strokes now fail (new B5). |
| B5 | Nothing measured | **Fixed in code** | The whole funnel is in `Analytics.swift`. It is dark until the owner sets the ID, and two remote levers are dead (§2b). |
| B6 | Silent preview, no lock | **Not fixed in substance** | A soundtrack exists, but 77 % of it is near-silent. The lock clip still ends before the lock, and the poster is still pre-lock (new B4). |
| B7 | Ghosted combo digit | **Fixed** | `HighwayHUD.swift:46`, `:76`; store #2 is crisp. |
| B8 | Blind learner can tune but not learn | **Mostly fixed** | Play-along cues, earcons and focus on each step. Still open: the notes step is silent and cues are badly timed (§2b). |
| B9 | Pro revoked in grace | **Fixed** | `Access.swift:26-34` trusts `currentEntitlements`; billing banner. |
| B10 | Renewal terms in English in 48 storefronts | **Worse** | 11 legal strings × 48 locales; the delivery gate fails (new B1). |
| B11 | iPad CI red | **Fixed** | iPad job green; iPad #2 valid. |

**8 of 11 are fixed (or fixed in code), 1 is mostly fixed, 1 is not fixed and 1 is worse.** The repo hygiene items are also done: no scratch files at the root, 0 "review N / bug N" comments, 0 `IconOrb(`.

### Why it is not higher

The wave raised every score, but **moved no angle to a clean #1** (see the count below). It also opened new seams that a juror or a reviewer finds in minutes:
- **Visual and system intrusion.** A fake Dynamic Island draws "+5 XP" under the system clock on the first tuner screen (07) and on the ukulele page's lead frame (17).
- **The hero claim misfires.** The lock flickers off after about 130 ms, so store #1, the iPad #1 frame and the preview poster all read "Hold it…".
- **New grading and content errors:**
  - correct chunks and chops grade as misses;
  - songs drop half-bar chord changes in 216 of 419 arrangements;
  - the ukulele songbook plays Mozart in C minor;
  - violin play-along teaches guitar fret numbers.
- **Untrue money screen:**
  - the paywall's Free/Pro table contradicts the free tier;
  - the price test can't run, and the free-tier test can't either;
  - the monthly trial the delivery doc asks for would go undisclosed;
  - the beginner's paywall can never promise the first song.
- **It can't ship.**
  - The legal, permission and VoiceOver gate fails in all 48 non-English locales.
  - There is no green end-to-end app run for the wave.
  - 22 of 26 commits skipped CI; all 26 are authored "Claude", and PR #2 has 0 reviews.

### Scoreboard: who is #1 today, angle × competitor

| Angle (score) | vs GuitarTuna | vs Fender Tune | vs Fender Play | vs Yousician | vs Simply Guitar | vs JustinGuitar | **#1 on the angle today** |
|---|---|---|---|---|---|---|---|
| **Visual & interaction (8.8)** | **Split.** In-app goes to Timbre: lit 3D headstock, peg ring, strum lanes, strobe (10, 11b, 15). Brand goes to GuitarTuna: Timbre's icon has a mean luminance of 31.8/255 and its dark variant is byte-identical. | **Timbre.** 7 instruments in 3D and 37 photo rigs, against one headstock. | **Split.** Fender's filmed hands beat Show me's pads (51b); Timbre's UI and highway are far ahead. | **Timbre, narrowly.** Highway with colour-blind-safe lanes (60, 65), against licensed album art. | **Simply on art direction; Timbre on craft.** Stock SF heroes remain on 05, 05a3 and 58. | **Timbre.** | **Split.** Timbre on in-app craft; Simply on art direction; GuitarTuna on brand at thumbnail size. |
| **Delight & innovation (8.7)** | **Timbre on the tuning moment.** Lock bell, self-strumming finale, Tune by feel. **GuitarTuna on games and known songs.** | **Timbre, by a mile.** | **Split.** Timbre on innovation; Fender has a band you hear out loud, and hands. | **Yousician on Fun** (band out of the speaker, weekly songs). **Timbre on Innovation:** a band that reacts to you, but only in headphones (`AudioService.swift:655`). | **Simply on Fun** (Queen, seasonal events). | **Justin on personality.** | **Timbre on Innovation (clean); Yousician and Simply on Fun.** |
| **Inclusivity (8.7)** | **Timbre**, but GuitarTuna ships 11 finished languages. | **Timbre, decisively.** | **Timbre.** Fender offers no left-handed lessons. | **Timbre.** Upside-down mode and a spoken runway. | **Timbre**, but Simply's 11 languages are finished. | **Timbre.** Justin's app is reported inaccessible to VoiceOver. | **Timbre: the only clean #1.** Not an ADA finalist yet: 49 languages at 30 % English, the notes step silent for VoiceOver, an audit that enforces nothing. |
| **Technical (8.5)** | **Split.** Timbre on technology (`PolyTuner`, per-stroke chords, `ChordRing`). GuitarTuna on maturity: green weekly releases, Mac, visionOS, sync. | **Timbre.** | **Split.** Timbre's in-house engine against Fender's accounts and sync. | **Yousician, narrowly.** Recognition proven at scale, sync, live ops, an AI teacher. | **Even.** | **Timbre.** Justin's chord detection was broken from April to November 2025. | **Yousician, narrowly.** Timbre has no real-audio evidence (`expected.json` `"clips": []`), no green release run and no sync. |
| **Growth (8.1)** | **GuitarTuna.** 4.8★ from 149K ratings, 20,000+ songs, three tiers. | **Fender Tune.** Free, 4.8★ from 152K. | **Fender Play.** Brand, 1,000+ songs. | **Yousician.** Editors' Choice, catalogue. | **Simply.** About 400K ratings, a song-led funnel. | **Justin.** Teacher trust, 1,500+ songs. | **GuitarTuna (tuner search) and Simply (learn search). Timbre is last on the storefront and first on the in-app funnel.** |
| **Category: what a player picks (8.3)** | **Split.** Timbre on the tuner, 24 free guitar tunings, no ads. GuitarTuna on songs. | **Split.** Timbre on the auto and polyphonic tuner. Fender on its free library (5,000 chords, 2,000 scales, 65 rhythms). | **Fender** on videos and songs. Timbre on feedback, breadth and price. | **Yousician** for hits. **Timbre** for string players and feedback depth. | **Simply** wins week one. | **Justin** on pedagogy. | **Split.** Timbre is #1 on tuner, instruments, feedback, price and free tier; behind on songs and a visible teacher. |

**Count (unchanged from round 15; every margin narrowed):**
- **Clean #1 on 1 of 6:** Inclusivity.
- **Split on 3:** Visual, Delight, Category.
- **Lost on 2:** Technical (narrowly, to Yousician) and Growth.

**What an ordinary person does today:**
- **"guitar tuner".** The muted autoplay preview says "Free tuner. No ads." over a 3D headstock, a good first frame. It sits beside two free 4.8★ apps with about 150K ratings each, so they install those.
- **"learn guitar".** They install Simply, Yousician, Fender Play or Justin, for songs they know.
- **"violin tuner" / "learn ukulele".** Timbre is the best product for them, but:
  - the violin page cannot claim "violin" as a keyword the way the docs plan it;
  - its frame #2 teaches fret numbers to a violinist;
  - the ukulele page's lead frame (17) has the "+5 XP" pill over the clock.
- **Once installed:** the first two minutes are the best in the category (tune, chord heard, honest paywall). But a beginner's paywall can never say "Play your first song this week".

---

## 2. Consensus findings and blockers (deduplicated and verified)

### 2a. Blockers (each verified by me; must ship before submission)

| # | Blocker | Jurors | Evidence (verified) | Package |
|---|---|---|---|---|
| B1 | **The wave can't pass its own App Store delivery gate.** Renewal terms, "Start free trial", the billing banner and `NSAppleMusicUsageDescription` are English in all 48 non-English locales. | technical, inclusivity, growth | I ran `critical.py`: legal 11, permission 1, VoiceOver 84 strings, each missing in every locale. `report.py --check`: 584 of 1,923 UI strings (R15: 474) and 1,408 lesson strings (R15: 1,126), and "handoff out of date". `apple-delivery.yml:87-88` gates on `--strict`, but `allow_untranslated` (`:23-27`) skips it with nothing preventing a review submission. The PR job only reports. | WP1 + owner (translators or a locale cut) |
| B2 | **A fake Dynamic Island draws reward banners inside the system status bar**, on the first tuner screen, in store frames and in the preview. | visual, delight (category misattributed it, §6) | Frames 07 and 17: the sparkle sits on "9:41" and "+5 XP" under the signal bars. Frame 14: "3 achievements unlock…" behind the battery. `GameUI.swift:454-458` ("grows out of the island"), `:614-626`, `:671-703` (`PillLayout`, 126 + 2×64 pt); mounted globally at `RootView.swift:59`; no `statusBarHidden` for it. Frame 17 is the ukulele page's lead frame. | WP9 (day 1) → WP2 recapture |
| B3 | **The lock doesn't hold.** "In tune" drops within about 130 ms, so store #1 (iPhone and iPad) and the preview poster read "Hold it…". | delight, visual, growth | Frame 10b: D3 at 0¢, "Hold it…", D3 unticked, yet "Quest 3/6". The badge is `reading.inTune` frame by frame (`TuneView.swift:357-363`). Any gap over 150 ms resets the hold (`TuningTracker.swift:76`), which then needs `holdMs = 650` again (`:6`). The lock path also persists settings on the main actor (`AppStore.swift:665-674`). | WP3 (day 1) + WP10 hook → WP2 recapture |
| B4 | **The App Preview is mostly silence, the band is missing, and the lock is never on camera.** | delight, growth, visual | My `silencedetect` (−60 dB, ≥ 0.4 s): **17.7 s of 23.17 s** are silent. That is 0–1.97 s; 6.62–8.92 s; the whole "Play songs with the band" clip (10.9–16.4 s), which is a 22 ms click every 0.68 s with silence between; and 16.40–23.17 s (results, Songs, end card). PREVIEW.txt: the lock clip ends at 124.83 s, the lock sync is at 125.33 s; the poster (2.70 s, "in lock") shows −3¢ "Hold it…" (`poster.png`). The only gate is mean volume (`preview.py:80`, `:924`), so it printed "Meets the App Preview spec." The notes say "shortened to 25.0 s"; the file is 23.17 s. | WP2 (after WP3, WP9, WP8) |
| B5 | **Correct muted strokes (uke chunk, mandolin chop, reggae chop) are scored as misses.** A perfect take fails. | category | `judgeChord` (`LessonSteps.swift:1793-1796`): a whole-beat stroke with no chord heard is `.miss`. `StrokeChords` reads 60–230 ms after the onset (`StrokeChords.swift:19-22`), where a chunk has no chord by design. `curriculum.json` has no `muted` field. uke-8-1 has pattern `[0,1,2,2.5,3]` on C and F; man-4-4 and gtr-15-3 have pattern `[1,3]` (every stroke a chop). A correct man-4-4 scores 0 % and is capped at 1 star (`:1179-1182`). | WP6 (schema, judge) + WP5 (data) |
| B6 | **The violin and cello play-along shows guitar fret numbers.** It teaches the wrong finger, and on the violin page's store frame #2. | category | Frame 65b: F♯ on the E string is drawn as a large "2" with a small finger "1". `Highway.swift:1149` labels `"\($0.fret)"`; the Next row says "String n, fret n" (`:395`). | WP7 (day 1) → WP2 recapture |
| B7 | **The paywall's Free/Pro table contradicts the free tier.** It undersells exactly what beats GuitarTuna. | category, growth | `PaywallView.swift:706-724` marks Free ✗ on "Alternate tunings for every instrument", "Chords, scales, intonation and drone" and "Strobe, temperaments and custom tunings". But `FreeTier.swift:3-38` makes open chords with Check and one custom tuning free, and `Access.swift` frees every preset of 5 instruments. The comment at `:721` still says "three charts free" (the limit is 10). | WP4 |
| B8 | **The monthly intro trial would go undisclosed.** It is latent: it becomes live the moment the owner follows `APPLE-DELIVERY.md:32` ("Free trial, 1 week"). | growth | `trialLabel` reads only the annual offer (`CommerceService.swift:115-117`). The CTA, terms and `wasTrial` are annual-only (`PaywallView.swift:928`, `:1062`, `:1336-1349`, `:1413-1421`). A monthly trial would show "$6.99, renews automatically", log `trial=0` and schedule no reminder. The StoreKit fixture has no monthly intro today. | WP4 (before the owner adds the offer) |
| B9 | **The paywall from Settings can render with no plan cards.** "14 DAYS FREE" floats over a void. | visual, growth | Frame 16. The tag is drawn outside the cards' glass group (`PaywallView.swift:856-866`, `:892-908`; `Glass.swift:31-37`). Whether it was a slow load or a capture moment, the tag must never show without its card; App Review screenshots this screen. | WP4 |
| B10 | **The *Kite Weather* cover imitates Joy Division's *Unknown Pleasures*.** It appears on store #2 and on the paywall rail (06, 16). | visual, delight | `SongCover.swift:624` `pulse`: "Stacked pulse lines, each hiding the ones behind it, rising into a signal… one line lit". It is not a one-off. `.pulse` is in the Originals rotation (`:143`) and the swing, rock and anthem pools (`:343-345`), so other sleeves can draw it too. The owner asked for it to be replaced. | WP5 (retire the motif) + owner (new cover) → WP2 recapture |
| B11 | **No green end-to-end app run exists for this wave**, and HEAD is `[skip ci]`. | technical | `gh run list`: the last finished iOS runs are cancelled (543192c), failure (7b80620), cancelled (9c749fe), failure (7c8d46c), failure (5111d1f). On e74c390, core and iPad are green and the app job was still in its UI flows at my check. 22 of 26 wave commits are `[skip ci]`. | WP1 |

### 2b. Consensus majors (two or more jurors, or one juror and my verification on a money or truth path)

| Finding | Jurors | Verified evidence | Package |
|---|---|---|---|
| **The first-song promise is impossible for beginners.** The onboarding headline "Play your first song this week" never fires for the default "Play my first songs" goal. | growth (category: free runway) | `PaywallView.swift:356` needs `plan.songDay <= 7`. The plan assumes one lesson a day (`PaywallPlan.swift:105-108`). My curriculum check puts the first song at lesson 9 (guitar, mandolin), 15 (bass), 16 (violin, cello, banjo), 19 (voice) and 20 (ukulele), **all Pro** (free lessons: 5–6 per course). Frame 06 says "Unlock your full plan". The songs goal isn't routed to a free songbook (`AppStore.swift:489` maps only ear, voice and rhythm). | WP4 + WP5 (free unit-1 song) + WP10 (hook) |
| **One chord per bar drops half-bar changes**, in "Chords & words" and under the band in both modes. | category (delight credits the chord-following band) | `LeadChart.chords` is "the chord on each bar's downbeat" (`SongSheet.swift:744-745`), though `marks` holds every change (`:746-747`). `SongPerform.swift:104-116` builds the band and `chartChords` from `filledChords`. `BandArrangement.Bar` holds one `root` (`Band.swift:11-13`). `ChordAlongJudge.stroke` takes one stroke per bar (`PlayAlongSession.swift:278-285`). **216 of 419 song arrangements change chord mid-bar** (my count; category's 157 of 330 is the strummed subset). | WP8 (segments) + WP7 (judge, lane, band input) |
| **The band is silent on the speaker**, and so is everything it does: thin, fill, crash, choke, chord band. | delight, growth (preview), category | `AudioService.swift:655` `audible = bandAllowed && headphones && …`; `Band.swift:252-254` "only ever plays in headphones". `bandOnSpeaker` (`LocalStore.swift:82`) is read by nothing but a test. | WP8 |
| **The ukulele songbook's keys, spelling and octave folds break tunes.** | category | My check: uke *Rondo alla Turca* uses Bb, Bb7, Cm, Eb, Fm, Gm (source: Am, E7, …); its melody runs C4 Eb4 G4 … D4 C4 **B4** C4 (a major-seventh leap where the source steps). Uke *Carmen* spells **D#** beside Fm and Bb7. Cause: `editions.py:151-156` reads the tonic from the last chord; `:158-163` spells sharps in G; `:236-256` allows 3 % folds. | WP5 |
| **Dead remote levers.** The documented `timbre_pro_annual_b` price arm and `flags.unit2Free` do nothing. | growth | `TimbreProduct.subscriptions = [annual, monthly]` (`Access.swift:11`), so `annualProductID(remote:)` (`CommerceService.swift:108-111`) falls back on every device, and `isPro` would never grant `_b`. `unit2Free` appears only in a doc comment (`RemoteConfig.swift:16`); `flag(_:)` has no caller. There are also no subscription-outcome events (renewal, refund, auto-renew off). | WP4 |
| **Localisation regressed and the funnel is English abroad.** | inclusivity, technical, growth, visual | See B1. On `l10n-de-welcome` the headline and subline are English under German buttons. Tuner chrome ("Thickest", "Quest · tune every string", "REFERENCE", "Strum") is English in de and ar. Hertz uses `String(format: "%.2f Hz")` (`Readout.swift:380`). The localized listing's variables table is stale (`APP-STORE-LISTING-LOCALIZED.md:47-49`). Only 7 plural rules. | WP1 + owner |
| **The accessibility audit enforces nothing.** | inclusivity, technical | `AccessibilityAuditUITests.swift:11` `enforced = []`; the `catch` at `:122` turns "did not run" into a report line. The technical juror's CI attachments show 6 of 8 audits "failed to complete in time" and passed. There are no AX5, Bold Text, Increase Contrast, left-handed or RTL-lesson frames. The German test checks only the button (`LocalizationLaunchUITests.swift:39`). | WP1 |
| **Swift 6 and architecture are unchanged.** | technical | `Package.swift:12` `.v5`; `project.yml:12` `SWIFT_VERSION: "5.10"`; no strict concurrency. `AppStore.swift` is 1,205 lines, observed by 89 `@EnvironmentObject … AppStore` declarations. 14 `ObservableObject` against 3 `@Observable`; 17 `@unchecked Sendable`; 5 `nonisolated(unsafe)`; 0 `#Preview`; 27 app unit tests. `LessonSteps.swift` is 2,323 lines and `Highway.swift` 2,180. | WP10 + WP1 (flags) |
| **Commit and review hygiene.** | technical (R15 consensus) | Since `7c8d46c`: 26 commits, **all authored "Claude"**, 22 `[skip ci]`, 12 "WIP wave 18". Repository: 258 of 259 commits by "Claude". PR #2: 0 reviews (`gh api`). The hygiene lint bans the word "Claude" in comments (`lint_tells.py:88-90`) while git names it as the author; a buyer reads that as cosmetics over review. | owner (reviewer, branch protection) + WP1 |
| **No songs people know, and the PD songs people do know are buried.** | category, growth, delight | 134 distinct tunes (category), 0 licensed. Songs opens on Originals (63; `SongOfTheDay.swift:3-5`, `:105-108`). About 15 carols exist, but only *Jingle Bells* is free. | owner (licensing) + WP5 |
| **Physical technique is still words and dots**; Show me has no hand. | visual, delight, category | 8 planned clips, 0 bundled (`lib.py:170-197`); `ShowMeHandRig` is a protocol with no rig (`ShowMeScene.swift:206-209`); 51b shows pads. | owner + WP7 (hooks) |
| **Tune by feel, the category's most original interaction, is hidden.** | delight, inclusivity | Off by default (`LocalStore.swift:77`); Settings › Feedback only (`SettingsView.swift:359`); no tuner control, no onboarding offer, absent from the listing. | WP3 + WP4 (onboarding) + WP9 (Settings) + WP2 (listing) |
| **Custom Product Page keywords can't be assigned as written.** | growth | Apple's help page (fetched today): "You can assign keywords from your latest approved app version to a custom product page… select a unique set of keywords for each page." The deep link applies only when users "click Open". `APP-STORE-LISTING.md:68-74` lacks "violin" and "ukulele" (subtitle only). `:237` says keywords "may repeat across pages"; `APPLE-DELIVERY.md:357-358` says a page's keywords "count against no other field". | WP2 + owner |
| **The colour rule and type scale exist on paper only.** | visual (inclusivity on contrast) | `Theme.swift:9-15` reserves mint, amber and coral, yet `DailySetCard.swift:53` (tune amber), `:56` (rhythm coral), and 246 `Palette.amber` uses. The inline orb is back by hand (`DailySetCard.swift:381-386`). `lint_tells.py`: type-scale 112 (warn only). `controlLine` measures 2.78:1 on `surface` (my computation; `Theme.swift:31`). | WP9 + every WP in its own files + WP1 (arm) |
| **App icon and brand.** | visual | `icon-dark.png` is byte-identical to `icon.png` (same MD5); mean luminance 31.8/255; no Icon Composer `.icon`. | owner (designer) + WP9 |
| **Instrument photography has no provenance.** | visual | `photos.json`: 68 of 73 entries are `"origin": "provided"`, 2 "generated". The visual juror found identical inlays on a banjo, a bouzouki and the dreadnought. | owner |
| **The paywall timeline's labels sit off their nodes**, and milestones use a status colour. | visual, growth | Frame 06: "Play 'Ode to Joy'" sits about 140 pt left of its Day 9 node; "Day 12" and "Day 14" touch; amber milestone and ▶ bullet (`PaywallView.swift:1143-1168`, `TrackSpread` `:1666`, `:1191`, `:1229-1236`). | WP4 |
| **VoiceOver gaps in the most frequent steps.** | inclusivity | The notes step is silent on `.hit` (`LessonSteps.swift:283-303`: no announcement). Cues are said one beat ahead at `.high` (`Highway.swift:792`, `PlayAlongCues.swift:46`) and run into the note at 60 BPM. VoiceOver speech reaches a `.measurement` microphone with no echo cancellation. Cue names come from an English template (`PlayAlongCues.swift:59-70`). | WP6 (notes step) + WP8 (cues) + WP7 (scheduling) |
| **UI sounds bypass the session owner.** | technical | SoundFX uses bare `AVAudioPlayer` (`SoundFX.swift:149-153`). The owner only knows `.lessons` and `.recording` (`AudioService.swift:815-829`). So the welcome motif plays under the default `.soloAmbient` (likely stops the user's podcast), and after tuning, chimes ignore the silent switch. Needs a device check. | WP8 |
| **Store crops and wrong-instrument frames.** | visual, growth | `screenshots.py:76` (`y0: 0.035`) slices the status bar on #7; `:81` (`0.075`) slices "Strum to tune" on #8. Violin page #3 shows guitar results. | WP2 |
| **Hero objects cropped by the stage.** | visual | My crops of 49b and 49c: the violin and cello scrolls are cut flat at the stage's top. `InstrumentStage.swift:448-450` constrains a single tip point. | WP3 |

### 2c. Single-juror items I rank as major (verified or well-evidenced)
- **The strike-through "was" price.** "$83.88" (12 × monthly) is struck through beside $34.99 (06). That is a reference-price claim in the EU and UK. Owner: WP4.
- **"Cancel in 2 taps" can't be verified** (`PaywallView.swift:1006`, `:1014`). Owner: WP4.
- **A hand-typed rating line**, global rather than per storefront, set in amber (`RemoteConfig.swift:111-116`; `PaywallView.swift:558-566`). Owner: WP4.
- **Calm mode is shallow.** It hides XP pills in three places only; the streak and level chrome, the XP banners and the results tiles stay (`SettingsView.swift:276` overpromises). Owner: WP9.
- **The RTL play-along rails aren't pinned** (`Highway.swift:2044`, `:2102`; `HighwayTimingStrip.swift:247`). Owner: WP7.
- **Two lane-colour pairs collide.** String 3 vs string 6 is 5.5 ΔE under deuteranopia; string 2 vs string 5 is 3.5 under protanopia (`Highway.swift:1265-1266`). Owner: WP7.
- **The recogniser knows 8 qualities**, so E9 and D9 strokes go unchecked (`ChordRecognizer.swift:99`). Owner: WP6.
- **Test hooks in release code.**
  - 8 environment reads sit outside `#if DEBUG`, e.g. `PitchSniperView.swift:218` and `PaywallWinBack.swift:76-80`.
  - Dead persisted settings: `theme`, `skin`, `reducedMotion`, `telemetryEnabled`, `bandOnSpeaker`.
  - Owner: WP10.
- **A tuner-intent install answers four screens before it can tune.** There is no "Just tune" door (`OnboardingView.swift:173-203`). Owner: WP4.

### 2d. Minors (routed; no further argument needed)

**Motion and capture:**
- `numericText` rolls note letters (`Highway.swift:403`, `Readout.swift:295`).
- Show me's segmented control relabels itself (`ShowMe.swift:605-620`).
- Docks are translucent (`PracticeChrome.swift:248-250`; `OnboardingView.swift:745`).

**Results and rewards:**
- The results ribbon has blank Intro and Outro tiles, and "Strongest: Intro" (`HighwayTimingStrip.swift:289-318`).
- The flame is used for the streak everywhere except the milestone lamp.

**Practice games:**
- Bullseye hides a tune in only every other game (`PitchSniperView.swift:220`).
- Ear training's wrong cue is pitched.

**Small type:**
- The drone dial caps at `.large`.
- "≈ estimate" is set at 10 pt.

**Shares and prompts:**
- The referral is a public coupon, with no Associated Domains.
- There is no review prompt after the first 3-star song.
- The first chord isn't credited to its lesson (`FirstChordStep.swift:137`).

**German welcome:** the "Violine" chip sits in the "…" overflow (`OnboardingView.swift:316-344`), hiding the beachhead instrument.

**Smaller shelves:** cello has 7 songs, banjo 6 and bass 2.

---

## 3. Roadmap to #1: ten file-disjoint work packages

### Rules for all teams
1. **One owner per file.**
   - Each package owns the files listed for it.
   - An unlisted Swift file defaults to **WP10**; an unlisted non-Swift infrastructure file (workflows, tools, project files) defaults to **WP1**.
   - No team edits a file it doesn't own. It asks the owner for a hook.
2. **Day-1 contracts** (each lands as one small PR on day 1; consumers build against it):
   - **WP6:** adds `muted: [Double]` and `accents: [Double]` to strum and progression steps in `Curriculum.swift`. WP5 emits them.
   - **WP8:** publishes `BandArrangement.Bar.segments`, `BandFeel.kitOnly` and `SpokenCues.schedule(lead:brief:)`. WP7 consumes them.
   - **WP10:** publishes these hooks:
     - `AppStore.planCourse(forGoal:)`, used by WP4;
     - a debounced lock-path persist, used by WP3;
     - `TestSupport.isAutomated` (DEBUG-only, `false` in release); others adopt it in the final sweep.
   - **WP9:** publishes the `Palette.accentNeutral` and `Palette.starGold` roles and the docked reward toast.
   - **WP4:** publishes `ReferralPill`, `ReviewPrompt.afterSong`, and the RemoteConfig keys `freeSongs` and `unit2Free`. WP9 and WP5 consume them.
   - **WP5:** publishes `Curriculum.distinctTuneCount`. WP4 (proof line) and WP2 (listing) consume it.
3. **Strings.** New strings go in code with English defaults. WP1's pipeline extracts them; nobody hand-edits `.lproj`. The funnel strings (welcome to paywall) and the critical gate strings are tagged "launch-critical".
4. **Lints and concurrency.**
   - Each package migrates the off-scale `Typeface` literals and the status-colour misuse in its own files. WP1 arms both rules at `error` when the counts reach 0.
   - WP1 turns on complete concurrency checking as warnings on day 1. Each package clears its own files, and WP1 flips TimbreCore to `.v6` last.
5. **Process.** No `[skip ci]` on commits that touch `ios/`. Squash-merge. A human reviewer approves every PR (owner, §4), and the required gate job must be green.
6. **Captures.** WP2 recaptures last. Any package that changes a store-visible screen tells WP2.

### Day-1 blocker sweep (small fixes, in parallel, before the larger work)

| Blocker | Package | Size |
|---|---|---|
| B2 fake island: delete island mode | WP9 | S |
| B3 latch the lock | WP3 (+ WP10 debounce hook) | S |
| B6 violin and cello finger labels | WP7 | S |
| B7 table, B8 monthly disclosure, B9 plan tag | WP4 | S each |
| B5 muted strokes: schema, then judge and data | WP6 (day 1), WP5 (day 2–3) | S |
| B10 retire the `.pulse` sleeve motif | WP5 | S |
| B1 strict gate on PRs; submit blocked under `allow_untranslated` | WP1 (+ owner translations or a locale cut) | S + owner |
| B11 a required gate job, then green on HEAD | WP1 | M |
| B4 preview re-cut | WP2, after WP3, WP9 and WP8's speaker band | M |

### Ranking

Packages are ordered by impact on:
- (a) an ordinary user choosing Timbre;
- (b) revenue toward $10k a month;
- (c) ADA-level craft.

| Rank | Package | Size | Why it ranks here |
|---|---|---|---|
| 1 | WP1 Release gate, languages and CI | M–L | (b) Nothing earns until the build can be submitted (B1, B11). (a) A third of the market's first screen is in its own language. |
| 2 | WP2 Store creative, preview and listing | M | (a) The preview and store #1 are the moment people choose (B4). The instrument pages are the only organic beachhead. |
| 3 | WP3 The tuner's signature | S–M | (a)(c) Makes store #1's claim true (B3), puts Tune by feel one tap away, and frames every instrument whole. |
| 4 | WP4 Paywall, price levers and first session | M | (b) A true money screen (B7, B8, B9), working price and free-tier tests, and the first-song promise. |
| 5 | WP5 Content: songs people know, correct songbooks, a free first song | M–L | (a) Recognisable titles first and a free song in every unit 1. (c) A ukulele songbook a teacher can't fault. B10. |
| 6 | WP6 Listening that's right on every technique | M | (a)(c) No correct take is graded as a failure (B5); VoiceOver hears the next note. |
| 7 | WP7 Songs, play-along and Show me | M | (a) The violin beachhead (B6) and harmony that follows the chart. |
| 8 | WP8 Audio engine and the band | L | (a)(c) The band reaches speaker players, and Timbre stops interrupting the user's audio. |
| 9 | WP9 Design system, app shell and rewards | M–L | (c) Removes the status-bar intrusion (B2, day 1) and makes the design rules enforce themselves. |
| 10 | WP10 Platform and architecture | L | The acquirer's read: feature-scoped state, background persistence, sync, and no test plumbing in release. |

---

### WP1: Release gate, languages and CI (**M–L**)
**Goal.** HEAD can be submitted: every shipped locale passes the legal, permission and VoiceOver gate, a green release build exists, and every gate can fail.

**Items**
1. **Delivery gate (B1).**
   - Run `critical.py --strict` in the PR core job (`ios.yml`), so no legal, permission or VoiceOver string merges without its translations.
   - Make `allow_untranslated` (`apple-delivery.yml:23-27`, `:87`) produce an internal-only build that cannot be submitted for review: block the submit step and stamp `TIMBRE_INTERNAL`.
   - Make an out-of-date handoff fail CI. Regenerate `HANDOFF.md` and `todo/*.json`, with a "launch-critical" section first: the 96 critical strings plus about 40 funnel strings.
2. **Locales.** Apply the owner's locale decision in `project.yml` (`CFBundleLocalizations`) and the `.lproj` set. The recommendation is `en` plus the 9 lesson languages, with `ar` and `he` only after native RTL QA.
3. **String Catalog.**
   - Adopt `tools/l10n/xcstrings.py`, with plural variants for the counted strings.
   - Remove the module-level `NSLocalizedString` and `String(localized:)` shadow (`Localization.swift:10-20`) in favour of an explicit `Bundle.app`.
4. **Localisation tests.**
   - A pseudo-localisation launch that fails on any English string on the welcome screen and the tuner.
   - The German test asserts the headline, not just the button (`LocalizationLaunchUITests.swift:39`).
   - An Arabic frame asserts the readout's octave sits to the right of the note. This verifies `eb6ee5c`.
5. **Accessibility audit.**
   - Fail when the audit can't run (`AccessibilityAuditUITests.swift:122`).
   - Audit with the stage resting (a launch flag that pauses `TimelineView`s and RealityKit).
   - Enforce `.contrast`, `.hitRegion`, `.sufficientElementDescription` and `.trait` now.
   - Add lesson steps, the play-along, Show me and the metronome to the audited screens.
   - A nightly matrix covering AX5, Bold Text, Increase Contrast, left-handed, upside-down and `ar`, over 05a, 13, 52, 52b, 55, 56, 59, 60 and 62.
6. **CI (B11).**
   - A required gate job under 15 minutes: core tests, app unit tests, 3 smoke UI flows (launch, tune, purchase) and a Release build.
   - Captures, the App Preview, the iPad shelf and the archive move to nightly or dispatch.
   - `contents: write` only on publish jobs (`ios.yml:8-9`).
   - DerivedData and SPM caching; nightly TSan; a coverage floor on TimbreCore; `XCTApplicationLaunchMetric`.
   - The gate rejects `[skip ci]` commits that touch `ios/`.
7. **Swift.**
   - `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` now: the build is warning-free apart from 3 SDK deprecations, which go on an allow-list.
   - `SWIFT_STRICT_CONCURRENCY=complete` as warnings on day 1.
   - TimbreCore to `.v6` (`Package.swift:12`) once the file owners have cleared their warnings.
8. **Lint.**
   - Rename `lint_tells.py` to `comment_hygiene.py` and drop the agent-name rule (`:88-90`).
   - Add `status-colour` (`Palette.(amber|coral)` outside an allow-list) and `inline-orb` rules.
   - Arm `type-scale` (112 today) and the new rules at `error` when the counts reach 0.
   - Commit the SwiftLint baseline so the step gates.

**Acceptance (what a juror checks)**
- `critical.py --strict` passes for the shipped locale set.
- A green gate run, and a green nightly archive, on HEAD.
- The audit test goes red on an injected contrast failure and red when the audit times out.
- The pseudo-locale test fails on an English welcome headline.
- The `ar` frame shows E₂.
- A `[skip ci]` commit touching `ios/` cannot merge.
- 0 warnings with warnings as errors.

**Files owned**
- `.github/workflows/*` except `preview.yml`
- `tools/l10n/*`, `tools/ci/*`, `docs/l10n/*`
- `ios/Timbre/Resources/*.lproj`
- `ios/project.yml`, `ios/Package.swift`, `.swiftlint.yml`
- `Timbre/Services/Localization.swift`
- `TimbreUITests/{AccessibilityAuditUITests, LocalizationLaunchUITests}.swift`
- new `TimbreUITests/AccessibilityMatrixUITests.swift`

**Dependencies**
- The owner's locale decision and the translators.
- Every package for its own type-scale, colour and concurrency fixes, before the rules are armed.

---

### WP2: Store creative, preview and listing (**M**; start now, final captures after WP3, WP5, WP7, WP8 and WP9)
**Goal.** The ad shows a string standing still, sounds like the app, and the instrument pages can actually rank.

**Items**
1. **Preview audio gates (B4).** Replace the mean-only check (`preview.py:80`, `:924`) with per-clip gates:
   - no digital silence longer than 0.5 s anywhere;
   - the highway clip at least 80 % non-silent;
   - energy below 250 Hz between clicks whenever a caption says "band".

   The render fails when the band didn't record (assert the headphone route, `DemoScenes.swift:592-599`).
2. **Preview content.**
   - Log the demo string's pluck as engine audio at about −12 dB, so the first 2 s have the string.
   - The app's own `.motif` under the end card.
   - Results clip with `keep: .head`, so the star triad lands under "Hear how you did" (`AppPreviewUITests.swift:248`).
3. **Sync on events.**
   - Take the `lock` sync within 50 ms of the app's lock event, while the comet moves (`AppPreviewUITests.swift:171-178`).
   - Anchor the lock clip's end to the lock sync + 1.2 s (today the clip ends at 124.83 s, the sync is at 125.33 s).
   - Fail the render when the bell onset and the badge's first frame differ by more than 80 ms (`preview.py:847-853`).
4. **Poster.**
   - Template-match "✓ In tune" before writing PREVIEW.txt.
   - Correct the "shortened to 25.0 s" note (the file is 23.17 s).
   - Highway from the store scene's clean take at ×4, with the band audible.
   - Render the violin preview.
5. **Screenshots.**
   - **Recaptures:**
     - #1, iPhone and iPad, after WP3's latch (tick and comet);
     - 07, 14, 17 and 18 after WP9 removes the island;
     - #2 after WP5's new *Kite Weather* cover;
     - violin #2 after WP7's finger labels.
   - **Crops and contrast:** #7 at `y0 ≥ 0.06` (`screenshots.py:76`); #8 at `y0 ≈ 0.12` (`:81`); #3's callout headline in `ink`.
   - **Content:**
     - #5 leads with WP5's "Songs you know" shelf;
     - violin page #3 from a violin results capture (`vln-1-6`);
     - a new frame for the dead-string tip and the "Am?" call (after WP6 lands B5);
     - cello and ukulele page frames.
6. **Listing and Custom Product Pages.**
   - Rebuild the keyword field as the pages' inventory, e.g. `violin,ukulele,uke,cello,bass,mandolin,banjo,fiddle,chromatic,strobe,ear training,metronome,chord`, and assign single tokens per page.
   - Correct `APP-STORE-LISTING.md:68-74` and `:237`, and `APPLE-DELIVERY.md:357-358`, to Apple's rule: keywords come from the field, and the deep link works only on "Open".
   - Map Apple Ads ad groups to an instrument through the `attribution` event as the fallback preselect (request it from WP4).
7. **Listing copy.**
   - "Timbre hears every strum: the right chord, on time, and which string didn't ring" replaces `:9` and `:102`, once B5 ships.
   - A Tune by feel bullet and promotional line.
   - An Accessibility Nutrition Labels section (VoiceOver only after the blind-tester pass).
8. **Localized listing.** `screenshots.py --check` computes the variables table from the build and fails on a value mismatch (`APP-STORE-LISTING-LOCALIZED.md:47-49`).

**Acceptance**
- **Preview:** no silent window over 0.5 s; the poster shows "✓ In tune" and the tick; |bell − badge| ≤ 80 ms; ×4 and the band audible under the highway; the violin preview exists.
- **Store frames:** no frame shows a sliced status bar or the reward pill; #1 shows the tick; the violin pages show finger numbers and violin results.
- **Docs:** the keyword docs match Apple's help text.

**Files owned**
- `tools/marketing/*`
- `TimbreUITests/{AppPreviewUITests, TabletScreenshotsUITests, StillScreen, TimbreUITests}.swift`
- `Timbre/Root/DemoScenes.swift`
- `docs/ios/{APP-STORE-LISTING, APP-STORE-LISTING-LOCALIZED, APPLE-DELIVERY}.md`
- `.github/workflows/preview.yml`

**Dependencies**
- WP3 (latch), WP9 (island), WP8 (speaker band or recorded band), WP5 (cover, shelf), WP7 (violin labels), WP6 (before the "every strum" claim).
- Owner: approval of the soundtrack, and the keyword field in App Store Connect.

---

### WP3: The tuner's signature: a lock that holds, a feel you can find (**S–M**)
**Goal.** "Tune until it stands still" is true on screen, in the hand and in the ad.

**Items**
1. **Latch (B3).**
   - The badge and the quiet status line hold for max(1.5 s, while in band) after the lock (`lockedAt`; `TuneView.swift:357-363`, `:440`).
   - `TuningTracker.accept` keeps the hold across a gap over 150 ms when the frames on both sides are in band (`TuningTracker.swift:76`).
   - Adopt WP10's debounced lock-path persist (`AppStore.swift:665-674`).
   - A TimbreCore test: a 200 ms in-band gap keeps `inTune`.
2. **Tune by feel, one tap away.**
   - A `hand.tap` toggle beside Strum in the side controls.
   - A one-time tip after the 3rd full tune (`TimbreTips.swift`).
   - On by default while VoiceOver runs (`setting || voiceOverRunning`).
   - Schedule each pulse cycle as a `CHHapticParameterCurve` instead of per-frame parameters (`Haptics.swift:94-160`).
3. **Stage framing.**
   - Constrain the projected bounding box of the head mesh, not one tip point (`InstrumentStage.swift:448-450`, `closeYaw` `:130`).
   - Normalise the studio head to 55–60 % of the stage (14).
   - A probe fails when the head's top projects above the stage edge (49, 49b, 49c).
   - Keep the 3D close-up in RTL with the camera mirrored (`l10n-ar-tabs` falls back to a small image).
4. **Readout.**
   - Hertz through `.formatted(.number.precision(.fractionLength(2)))` (`Readout.swift:380`).
   - `.opacity` instead of `numericText` on the note letter (`:295`).
   - The mode control in sentence case at 15 pt (`TunerControls.swift`).
   - "≈ estimate" at 12 pt (`StrumMeters.swift:297-306`).
   - Migrate `Celebration.swift`'s 11 off-scale literals.
   - `TuningReading.status` becomes a `Codable` enum (to WP10's spec).

**Acceptance**
- In a UI test and on a device, the badge stays at least 1.5 s after the lock.
- The Tune by feel toggle is on the tuner, and on by default under VoiceOver.
- Violin, cello and mandolin scrolls are whole inside the stage at every size.
- German shows "82,41 Hz".

**Files owned**
- `Timbre/Tune/*`, `Timbre/Stage/*`
- `Sources/TimbreCore/Tuning/*`
- `Timbre/Design/Haptics.swift`, `Timbre/Tips/TimbreTips.swift`
- `Tests/TimbreCoreTests/Tuning*Tests.swift`

**Dependencies**
- WP10 (debounce hook); WP2 (recapture).
- Owner: a device haptic-bleed test with the microphone open.

---

### WP4: Paywall, price levers and first session (**M**)
**Goal.** Every fact on the money screen is true, every price lever works without a build, and the beginner's paywall promises a first song it can deliver.

**Items**
1. **First-song promise.**
   - `songDay` from cumulative lesson minutes ÷ daily minutes (`PaywallPlan.swift:105-108`).
   - For goal "songs", when the course's first song is past day 7, the day-1 or day-2 milestone becomes a free songbook song: WP10's `planCourse(forGoal:)` and WP5's unit-1 song.
   - The headline guard at `PaywallView.swift:356`.
2. **Free/Pro table (B7).**
   - Build the rows from `FreeTier` and `AccessPolicy` (`PaywallView.swift:706-724`):
     - "Open chords with Check": ✓ / ✓
     - "Barre chords, scales, intonation, drone": ✗ / ✓
     - "Custom tunings": 1 / unlimited
     - "Alternate tunings": "guitar, bass, ukulele, violin, cello" / "all 60"
     - "Strobe and temperaments": ✗ / ✓
   - Fix the "three charts" comment (`:721`).
   - A unit test that each row matches the policy.
3. **Remote levers.**
   - Add `annualB` and `annualC` to `TimbreProduct.all` and `.subscriptions` (`Access.swift:5-11`), so `annualProductID(remote:)` (`CommerceService.swift:108-111`) honours them and they grant Pro.
   - Load them (`:137`).
   - Wire `flag("unit2Free")` into `AccessPolicy.canPlay` as extra free units.
   - SKTestSession tests for both.
4. **Monthly intro (B8).**
   - Generalise `trialLabel` and `trialDays` to any product (`CommerceService.swift:115-117`). The Monthly row says "7 days free", with its own CTA, terms line, `purchase.trial` and `TrialReminder` (`PaywallView.swift:928`, `:1062`, `:1336-1349`, `:1413-1421`).
   - Rename the "exit offer" if the intro covers it (`PaywallWinBack.swift:62-66`).
5. **Paywall seams.**
   - **Timeline:**
     - labels centred on their nodes;
     - Day 12 and Day 14 staggered or merged (`:1143-1168`, `TrackSpread` `:1666`);
     - milestones in `ink` with mint nodes, and no amber ▶ (`:1191`, `:1229-1236`).
   - **Plan cards (B9):** the plan tag lives inside the yearly card's glass and waits for the products (`:856-866`, `:892-908`), plus a UI test that `paywall.plan.yearly` is hittable on the Settings route.
   - **Price and trust copy:**
     - the anchor reads "12 × $6.99", or no strike-through outside the US;
     - "Cancel anytime in Settings · We remind you on day 12" (`:1006`, `:1014`);
     - the rating from the iTunes Lookup API per storefront, in `ink` (`:558-566`; `RemoteConfig.swift:111-116`);
     - the proof line from `distinctTuneCount` ("130+").
6. **Subscription outcomes until ASSN v2.** Log `subscription_state{state, will_renew, offer, product}`, `renewal` and `refund` from `Transaction.updates` and the status API.
7. **Onboarding.**
   - A "Just tune" link on welcome: the microphone in context, the questions deferred to Learn (`OnboardingView.swift:173-203`).
   - Restore as a footnote link (`:297-310`), and a progress bar sized for the longest path.
   - The reminder ask after the first chord, not between tune and chord (`:196-203`).
   - A Tune by feel offer with a 3 s Feel test after the first lock (`FirstTuneStep.swift`).
   - Credit the first chord to `gtr-1-4` (`FirstChordStep.swift:137`).
   - An opaque dock (`:738-745`), and the welcome chip row never hides Violin in German (`:316-344`).
   - The welcome motif only through WP8's ambient session.
8. **Referral and shares.**
   - Publish the `ReferralPill` and `ReviewPrompt.afterSong` APIs; WP9 mounts them.
   - A `referral_share` event.
   - Request Associated Domains from WP1.

**Acceptance**
- A beginner on guitar, ukulele or violin who picks "Play my first songs" sees "Play your first song this week", and the named song is playable free.
- The table test passes.
- A remote `annual_b` arm shows and grants Pro in SKTestSession; `unit2Free` opens unit 2.
- Monthly with an intro shows "7 days free" and logs `trial=1`.
- 16 never shows the tag without its card.
- Timeline labels sit within 8 pt of their nodes.
- "Just tune" reaches a listening tuner in 2 taps or fewer.

**Files owned**
- `Timbre/Paywall/*`, `Timbre/Onboarding/*`
- `Timbre/Services/{CommerceService, RemoteConfig, Analytics, ShareDestination, PracticeReminder, GameCenterSocial}.swift`
- `Sources/TimbreCore/Commerce/*` (incl. `Access`, `FreeTier`)
- `Tests/Fixtures/Timbre.storekit`, `Tests/TimbreCoreTests/AccessPolicyTests.swift`, `TimbreAppTests/Commerce*`
- `docs/ios/PRIVACY.md`

**Dependencies**
- WP5 (free unit-1 songs, `distinctTuneCount`); WP10 (`planCourse(forGoal:)`); WP8 (ambient session); WP1 (Associated Domains, strings).
- Owner: prices and offers in App Store Connect (§4).

---

### WP5: Content: songs people know, correct songbooks, a free first song (**M–L**)
**Goal.** Every instrument's free unit ends with a song, the ukulele songbook is musically right, and the songs people recognise come first.

**Items**
1. **A free first song** at the end of unit 1 in every instrument course:
   - guitar, mandolin and violin: a three-note *Mary Had a Little Lamb*;
   - ukulele: move "Your first chord: C" plus a one-chord song into unit 1.
2. **Ukulele editions** (`tools/curriculum/editions.py`):
   - the tonic from the first section or the most bars, not the last chord (`:151-156`);
   - a per-instrument chord difficulty cost: Eb, Fm, Cm, Bb7, F♯m and Db cost about 2 (`:78-79`, `:236-256`);
   - spelling by function, so ♭VI in G is E♭, not D# (`:158-163`);
   - reject a plan that turns a step of 2 semitones or less into a leap of 10 or more;
   - low-G editions where folding is needed;
   - regenerate.
3. **Muted and accent data (B5).** Emit `muted` on uke-8-1, uke-8-2, uke-8-6, man-4-4, man-4-5, man-4-6, man-6-5, gtr-15-3, *Low Tide Radio* and *Saltwater Sunday*, and `accents` on uke-8-4, to WP6's schema.
4. **Songs you know.**
   - The shelf comes first on Songs (`SongsView.swift`).
   - Song of the Day picks from it until three have been played (`SongOfTheDay.swift:3-5`, `:105-108`).
   - A December carol shelf, free for its first week through WP4's `freeSongs` key.
   - A "Request a song" button with an event.
   - Course subtitle copy (`Learn.strings:4781`).
5. **Sleeves (B10).**
   - Retire `.pulse` (`SongCover.swift:143`, `:266`, `:300`, `:343-345`, `:624`).
   - Give *Kite Weather* the owner's new cover; flag any other sleeve the art director rejects.
   - A corner lock glyph instead of the "🔒 Timbre Pro" pills on song cards.
6. **Counts.** `Curriculum.distinctTuneCount` in TimbreCore:
   - strip ": the chords", ", fingerpicked" and " on bass";
   - exclude exercises.
7. **Shelves.**
   - A cello songbook (C-G-D-A, bass clef) from the violin songbook.
   - A bass root-and-fifth edition from every chord chart.
8. **Practice tools** (`Timbre/Practice/*` except `DailySetCard` and `PracticeChrome`):
   - Bullseye: every game a hidden tune, "Ten notes. One hidden song." (`PitchSniperView.swift:220`), and the miss wobble pitched to the target;
   - ear training: "9 of 10 by ear" and an unpitched wrong cue (call WP8's cue);
   - metronome subdivisions visible without scrolling (`MetronomeView.swift:281-300`);
   - "Challenge" text on the Bullseye button;
   - drone dial labels use `.cappedControl`;
   - chord qualities dim7, m7♭5, 7sus4, 6/9, 9, maj9, m9, 11, 13 and slash chords (`Chords.swift:11-26`).

**Acceptance**
- Every instrument course's unit 1 ends with a free song.
- Uke *Rondo* and *Carmen* contain no Cm, Fm, Eb, Bb7 or D#.
- A test over all 107 uke editions finds no folded step that becomes a leap of 10 semitones or more.
- Songs opens on *Ode to Joy*, *Amazing Grace* and *Silent Night*.
- No sleeve draws `.pulse`.
- Cello has at least 40 songs and bass at least 30.

**Files owned**
- `tools/curriculum/*`
- `Sources/TimbreCore/Resources/{curriculum.json, catalog.json}` and the generated English `Learn.strings`
- `docs/content/*`
- `Timbre/Songs/*`
- `Timbre/Practice/*` except `DailySetCard` and `PracticeChrome`
- `Sources/TimbreCore/Learn/SongOfTheDay.swift`
- `Sources/TimbreCore/Practice/{Chords, EarTraining, PitchSniper}.swift`
- `Sources/TimbreCore/YourSongs/*`
- `Tests/TimbreCoreTests/{Curriculum*, Catalog, ChordLibrary, Practice}Tests.swift`, new `SongbookEditionTests.swift`

**Dependencies**
- WP6 (schema, day 1); WP4 (`freeSongs` key).
- Owner: licensing and the new cover.

---

### WP6: Listening that's right on every technique (**M**)
**Goal.** No correct take is graded as a failure, every chord the curriculum names is checked, and a blind learner hears the next note.

**Items**
1. **Muted strokes (B5).**
   - Day 1: the schema `muted: [Double]` and `accents: [Double]` (`Curriculum.swift`).
   - In `judgeChord` (`LessonSteps.swift:1783-1800`), a muted beat passes when no chord is heard, or when the RMS 150 ms after the onset is below 30 % of the attack. A ringing chop is flagged "let it stop".
   - An "×" chip in `LessonBeatRow.swift`.
   - `chordsMostlyWrong` ignores muted beats (`:1179-1182`).
2. **Accents.** `StrokeChords` returns each stroke's peak RMS. Accented strokes must be at least 4 dB above the median, with the hint "Push the and of 2".
3. **Recogniser.**
   - Templates for 6, m6, 9, add9, dim, dim7 and aug (`ChordRecognizer.swift:99`).
   - Until they land, judge a 9 chord against its 7 and a 6 chord against its triad (`LessonSteps.swift:1148-1156`).
   - Shorten the frame when the next onset is under 230 ms away (`StrokeChords.swift:16-24`).
4. **VoiceOver in the notes step.**
   - On `.hit`, post the next note's spoken phrase.
   - While a wrong pitch is held, say "a little flat, tighten" on the `TunerAnnouncer` cadence (`LessonSteps.swift:283-303`, `:263-264`).
5. **Real audio.**
   - A WAV-injection seam in TimbreCore DSP (`PolyTuner`, `StrokeChords`, `LessonAnalyzer`), so tests drive recordings without `AudioService`.
   - Extend the `expected.json` schema to chunks, chops and mutes.
   - Gate the budgets once the owner's corpus lands.
6. **Ear steps.** After two wrong answers, show both notes on a mini staff, and offer "I can't hear this" without capping the stars.
7. **Pedals.**
   - Page Up and Page Down, and Return.
   - Slower moves to ⌥↓.
   - Space only when no other control has focus (`LessonPlayer.swift:551-591`).

**Acceptance**
- Synthesized tests: a perfect uke-8-1 take scores 100 %, and a perfect man-4-4 earns 3 stars.
- A chop left ringing is flagged.
- An E9 stroke is checked as E7.
- A VoiceOver user hears the next note after each hit.
- A pedal in Up/Down mode advances the lesson.

**Files owned**
- `Timbre/Learn/{LessonSteps, LessonAnalyzer, LessonPlayer, LessonBeatRow, LessonExplain, LessonInspector, LessonMotion, LatencyCalibration, WeakSpotReview}.swift`
- `Sources/TimbreCore/DSP/*`, `Sources/TimbreCore/Coach/*`
- `Sources/TimbreCore/Learn/{Curriculum, LessonEngine, Placement}.swift`
- `Timbre/Intents/{PracticeIntents, TimbreShortcuts}.swift`
- `Tests/TimbreCoreTests/{ChordRecognizer, StrokeChords, PolyTuner, DSP, OnsetDetector, Learn, Coach*, RealWorldAccuracy}Tests.swift`
- `Tests/Fixtures/RealWorld/*`

**Dependencies**
- WP5 (data).
- Owner: recordings, including real chunks, chops and mutes.

---

### WP7: Songs, play-along and Show me (**M**)
**Goal.** What a player sees during a song is right for their instrument and their song's harmony.

**Items**
1. **Fretless labels (B6, day 1).** For violin, viola, cello and double bass:
   - the gem shows the finger number ("0" for open), with low and high marks and the note name;
   - no semitone number (`Highway.swift:1149`);
   - the Next row says "String 1, finger 1" (`:395`).
2. **Chords per change.**
   - `LeadChart` exposes segments from `marks` (`SongSheet.swift:744-749`, `:964-974`).
   - `SongPerform` builds the band from those segments with WP8's API (`SongPerform.swift:104-116`).
   - `ChordAlongJudge` judges changes, not bars (`PlayAlongSession.swift:228-300`).
   - `ChordLane` draws split bars, "C · G" (`SongChords.swift:132`).
   - A test that every song's band segments equal its arrangement's changes.
3. **Lanes and RTL.**
   - String 6 becomes ice `0xB8F0FF`; the string number goes on every gem by default (`Highway.swift:1265-1266`).
   - Pin `UpNextRail` (`:2044`), `TakeRibbon` (`:2102`) and the timing strip (`HighwayTimingStrip.swift:247`) left-to-right.
   - `.opacity` instead of `numericText` on the Next row (`Highway.swift:403`).
   - `StopKey` in `AlongStep`.
   - Spoken cues through WP8's `SpokenCues.schedule`: two beats ahead when the beat is under 1.5 s, and the brief form when the gap is under 1.6 s (replacing `Highway.swift:792`, `:800-801`).
4. **Results ribbon.**
   - Minimum widths, with "In" and "Out".
   - "Strongest" tie-broken by note count, skipping sections under 8 notes (`HighwayTimingStrip.swift:289-318`).
5. **Show me.**
   - A stable "Chart · Player · 3D" picker (`ShowMe.swift:605-620`).
   - A clearer 3D glyph (`:520`).
   - Consume the owner's hand rig and the ukulele and banjo usdz (`ShowMe.swift:15-16`; `ShowMeScene.swift:206-209`).
   - A photo-stepper path for the 8 planned clips (`LessonClip.swift`).
   - Delete `ShowMe.lastProblem` from release.
6. **Your songs.** A full-song "Chords & words" take on a pasted chart (`ChartPracticeView.swift:35-50`).

**Acceptance**
- Twinkle in "Chords & words" shows and judges "C · G | D · G".
- The violin highway shows finger "1" for F♯ on the E string.
- The `ar` frames of 59 and 60 run left-to-right.
- No blank Intro or Outro tiles.
- Show me's picker never relabels.

**Files owned**
- `Timbre/Learn/{Highway, HighwayHUD, HighwayLyrics, HighwayPop, HighwayTimingStrip, SongPerform, SongOpener, SongSheet, SongChords, ShowMe, ShowMeScene, LessonClip, Diagrams, PlayerNeck, NotationView, NotationEngraver, NotationGlyphs}.swift`
- `Sources/TimbreCore/Learn/{PlayAlongSession, SongArrangement}.swift`
- `Timbre/YourSongs/ChartPracticeView.swift`
- `Tests/TimbreCoreTests/{PlayAlongSession, SongArrangement}Tests.swift`

**Dependencies**
- WP8 (segments, `SpokenCues`); WP2 (recapture).
- Owner: the hand rig, the usdz files and the clips.

---

### WP8: Audio engine and the band (**L**; the speaker kit layer first, S)
**Goal.** Every player hears the band, it follows every chord change, and Timbre is a good audio citizen.

**Items**
1. **Speaker band, step 1.**
   - On the speaker, play the kit layer only: drums are aperiodic and YIN rejects them. Harmony and bass stay gated on `headphones` (`AudioService.swift:655`; layers at `Band.swift:187-190`; a new `BandFeel.kitOnly`, `:245-256`).
   - Thin, fill, crash and choke then work on the speaker.
   - Speaker-safe noise earcons for tier-ups, ×4 and run breaks (the `Earcons` approach in `PlayAlongCues.swift:78-131`).
2. **Speaker band, step 2.**
   - An NLMS reference canceller on the analysis input, fed the band buffer at `heardLatency`, or voice processing for lessons only.
   - Behind a 10 s self-test.
   - Either wire `bandOnSpeaker`, or WP10 deletes it.
3. **Segments (day 1).** `BandArrangement.Bar.segments: [(beat, root, tones)]` (`Band.swift:5-20`), rendered per segment in `BandGroove`.
4. **Session citizenship.**
   - An `.interface` user sets `.ambient` whenever no engine holds the session. Route `SoundFX` and `PlayAlongCues` through it (`SoundFX.swift:149-153`; `PlayAlongCues.swift:134`).
   - Coalesce the route and configuration restarts into one debounced rebuild (`AudioService.swift:95-135`, `:320-330`).
   - Ignore `.appWasSuspended` interruptions (`:82-94`).
   - Never hold the owner's lock across `setActive(false)` on the main thread (`:811-849`).
   - A 20 ms I/O buffer when only listening (`:823`).
   - One coalesced main-actor hop per reading (`:199`).
5. **Spoken cues.**
   - Speak through the app's own `AVSpeechSynthesizer` at a known rate, and expose `SpokenCues.schedule(lead:brief:)`.
   - Mute detection while an utterance plays; voice processing on while cues are on.
   - Names from `NoteNames.spokenInApp`, localized (`PlayAlongCues.swift:59-70`).
6. **Metronome.** Rim, cowbell, shaker and kit voices, plus 12 drum grooves from `BandSynth` (`OutputAudio.swift:107`).
7. **Device test sheet**, committed with dated results:
   - AirPods in and out mid-lesson;
   - a call during the drone;
   - Siri during the tuner;
   - CarPlay;
   - a podcast playing at first launch;
   - the silent switch after tuning.

**Acceptance**
- On the speaker, a beginner hears drums under the highway, and thin, fill and crash audibly work.
- In headphones the band follows "C G | D G", changing on beat 3.
- Opening Timbre doesn't stop a podcast; chimes obey the silent switch after tuning.
- Connecting AirPods causes one restart, not two.
- At 60 BPM, a spoken cue never overlaps the note it announces.

**Files owned**
- `Timbre/Audio/*`, `Sources/TimbreCore/Audio/*`
- `Timbre/Learn/PlayAlongCues.swift`
- `Timbre/YourSongs/RecordingPlayer.swift`
- `Tests/TimbreCoreTests/BandGrooveTests.swift`

**Dependencies**
- WP7 consumes the segments and cues; WP2 records the band; WP10 cleans up the setting.
- Owner: sound designer, band stems, instrument samples.

---

### WP9: Design system, app shell and rewards (**M–L**)
**Goal.** Nothing on screen collides with the system or breaks the app's own rules.

**Items**
1. **Island (B2, day 1).**
   - Delete the island branch of `RewardToast`.
   - Use the docked branch under the header, at `safeAreaInsets.top + 8`, in `timbreGlass` (`GameUI.swift:454-458`, `:614-626`, `:671-703`; mount at `RootView.swift:59`).
2. **Colour.**
   - `Palette.accentNeutral` for categories, `starGold` for rewards and roots.
   - `DailySetCard` tints (`DailySetCard.swift:51-58`), and the inline orb discs become bare `Glyph`s (`:381-386`).
   - The results accuracy tile and burst (`LessonResults.swift:155`, `:181`); `ring: false` behind text (62).
   - Triage the remaining `Palette.amber` uses in owned files.
3. **Tokens.**
   - `controlLine = 0x646A74` (`Theme.swift:31`): 3.23:1 on `surface`, 3.41:1 on `stageRaised`.
   - Migrate the off-scale literals in owned files.
   - Opaque docks below an 18–24 pt fade (`PracticeChrome.swift:248-250`).
4. **Calm mode, for real.**
   - Gate `HeaderControls` (`Kit.swift:64-78`), the XP and streak banners (`GameUI.swift:449`, `:554`, `:570`), the results XP and streak tiles, and the Learn and Songs XP suffixes.
   - Make the footer true (`SettingsView.swift:276`).
5. **Rewards.**
   - A streak lamp glyph everywhere except the highway combo (25 `flame.fill` uses).
   - The results level ring instead of the "5" disc (`LessonResults.swift:229`).
   - The coach gives the next step instead of restating the headline.
   - Mount WP4's review prompt after the first 3-star song and the referral pill at peaks (`LessonResults.swift:634-637`).
6. **Settings.**
   - Tune by feel moves up into Tuning (`SettingsView.swift:355-360`).
   - "Try Timbre Pro: every lesson and song, every tuning and tool" (`:90`).
   - The privacy URL from Info.plist.
7. **Icon and brand.**
   - Integrate the owner's Icon Composer `.icon` with real Default, Dark, Tinted and Clear variants (today `icon-dark.png` is identical to `icon.png`).
   - A logotype in place of tracked amber Sora.
8. **Instrument picker.**
   - Tunings move into the tuner header's menu.
   - A corner lock glyph instead of PRO pills (`Timbre/Instruments/*`).
9. **Art and previews.**
   - Medals rendered in studio light when the art lands (`Progression.swift:317-358`).
   - `#Preview`s for the design components.

**Acceptance**
- No frame shows any app layer inside the status-bar band.
- The `status-colour` lint is green.
- `controlLine` is at least 3:1 on cards.
- In Calm mode, no XP or streak appears anywhere.
- A 40 px contact sheet shows a readable icon with distinct dark and tinted variants.

**Files owned**
- `Timbre/Design/*` except `Haptics.swift`
- `Timbre/Root/RootView.swift`, `Timbre/Settings/*`, `Timbre/Journey/*`, `Timbre/Instruments/*`
- `Timbre/Practice/{DailySetCard, PracticeChrome}.swift`
- `Timbre/Learn/{LessonResults, SongStoryCard, LearnView, CourseArt}.swift`
- `Timbre/Resources/{Assets.xcassets, Fonts}`
- `Sources/TimbreCore/Practice/Progression.swift`
- new `Timbre/Previews/*`

**Dependencies**
- WP4 (referral and review APIs); WP1 (lint arming).
- Owner: icon, illustrations, medal art.

---

### WP10: Platform and architecture (**L**; hooks on day 1, the sweep last)
**Goal.** An acquirer's engineer finds feature-scoped state, persistence off the main thread, sync, and no test plumbing in release.

**Items**
1. **Day-1 hooks.**
   - A debounced lock-path persist (`AppStore.swift:665-674`).
   - `planCourse(forGoal:)`, mapping "songs" to a course with a free first song (`:489`).
   - `TestSupport.isAutomated`: `#if DEBUG`, `false` in release.
2. **Incremental `AppStore` split.**
   - `@Observable TunerSession` first, the tuning path at `:571-706`. Stop `selectedCourse` and `referenceMidi` (`:645`, `:650`) invalidating the 89 observers.
   - Then `Router` (paywall routing) and `ProgressStore`, injected per feature.
3. **Persistence.**
   - Validate the delta.
   - A serial background actor with coalesced writes (`LocalStore.swift:425-466`, `:680-706`).
   - One `Preferences` type for the UserDefaults keys ("learn.course" is written 16 times), and "Clear practice history" clears them.
4. **Sync.** `NSUbiquitousKeyValueStore` for streak, XP and settings; CloudKit for history later.
5. **Dead and stringly-typed state.**
   - Remove `theme`, `skin`, `reducedMotion`, `telemetryEnabled` (`LocalStore.swift:6-8`, `:24-25`), and `bandOnSpeaker` unless WP8 ships it.
   - `Codable` enums for `PracticeRecord.kind`, `notation`, `stageMode` and `goal`.
6. **Launch and failure.**
   - Shard the curriculum (8.9 MB) per course, selected course first.
   - A `curriculum_failed` event.
   - `Catalog` decoded off the main thread (`CurriculumStore.swift:95-111`; `TimbreApp.swift:76-85`).
7. **Diagnostics.**
   - Upload MetricKit call-stack trees.
   - An EU consent choice for analytics (`LocalStore.swift:26-27`).
8. **Final sweep** (after WP1–WP9 merge, owners pre-approving):
   - Replace the 21 product files' environment reads with `TestSupport`, including the 8 outside DEBUG: `PaywallWinBack.swift:76-80`, `GameCenter.swift:136-140`, `LiveActivityController.swift:22-25`, `PitchSniperView.swift:218`, `InstrumentStage.swift:793`.
   - Rewrite the 46 test-coupled comments in product terms.

**Acceptance**
- Instruments shows a tuner reading invalidating only tuner views.
- Persistence runs off the main thread, and a write-interruption fuzz test passes.
- The streak syncs between iPhone and iPad.
- `grep TIMBRE_` finds only `TestSupport.swift`.
- A launch-metric baseline exists on an iPhone SE.

**Files owned**
- `Timbre/Services/{AppStore, LiveReading, GameCenter, GameCenterIDs, LiveActivityController, PracticeActivityAttributes, WatchBridge, WatchSnapshot, WidgetBridge}.swift`
- `Sources/TimbreCore/{Persistence, Catalog}/*`
- `Sources/TimbreCore/Learn/CurriculumStore.swift`
- `Sources/TimbreCore/Practice/Streaks.swift`
- `Timbre/TimbreApp.swift`, `Timbre/Intents/*` (except WP6's two files)
- `TimbreWidgets/*`, `TimbreWatch*/*`
- new `Timbre/Support/*`
- `TimbreAppTests/*` except commerce
- `Tests/TimbreCoreTests/PersistenceTests.swift`
- every Swift file not listed elsewhere

**Dependencies**
- WP3 and WP4 consume the day-1 hooks.
- The sweep runs last.
- Owner: an independent reviewer signs off the split.

### Where the roadmap lands
**Code alone (WP1–WP10)** gets the panel to about **8.7**:

| Angle | Expected |
|---|---|
| Visual | 9.0 |
| Delight | 9.1 |
| Inclusivity | 9.1 |
| Technical | 9.0 |
| Growth | 8.5 |
| Category | 8.7 |

That is a weighted mean of 8.85, gated with Growth: (8.85 + 8.5) / 2 = **8.67**.

**With the owner's levers in §4** (licensed songs, teacher clips and a hand, the icon and art direction, translations, the real-audio corpus, early ratings), Growth and Category reach about 9.0–9.2 and the overall about **9.0–9.1**.

As in round 15, **"#1 on all angles" is not reachable with code alone.** Growth and Category are decided by songs people know, a visible teacher and social proof.

---

## 4. Decisions only the owner can make

| Decision | Panel's recommendation | Expected impact |
|---|---|---|
| **Locales for v2.0** (blocks submission today) | Ship `en` plus the 9 lesson languages (de, es, fr, it, ja, ko, pt, ru, zh-CN). Fund the 96 critical strings now (about 4,600 locale-string pairs; machine translation plus native review of the 11 legal strings), then the 584 UI and 1,408 lesson strings for the 9. Add the other 39 locales as each reaches 95 %. Lock `allow_untranslated` to internal builds. | Unblocks the App Store submission and removes the legal exposure (renewal terms in English). "49 languages" stops being a claim nobody can keep. |
| **Pricing and offers** | Unchanged from REVIEW15: yearly **$49.99** with the **14-day** trial, monthly **$9.99**, lifetime **$149.99** kept off onboarding, Family Sharing on yearly and lifetime. **Billing Grace Period on now**: the entitlement fix has shipped; test on TestFlight. **Do not add a monthly intro** until WP4 item 4 ships; I recommend none, using win-back and offer codes instead. Create `timbre_pro_annual_b` at $59.99 only after WP4 item 3 ships, then test it. | Net per buyer rises from about $31.55 to $43.67. Installs needed for $10k a month fall from about 12.2k to 8.8k at 2.6 % install-to-paid (growth's model). |
| **Accounts and addresses** | A TelemetryDeck app ID. `TIMBRE_APP_STORE_ID`. The share page and remote-config URL. The privacy policy on a custom domain (today `ShareDestination.swift:11` points at `azerish25-ux.github.io`). An ASSN v2 endpoint. An EU consent posture for analytics. | Every funnel event is dark until the ID is set, so there is no price test, no D7 and no RPI. It is the prerequisite for $10k a month and for any ad spend. |
| **Song licensing** | A starter pack of 20–30 recognisable songs (Hal Leonard, Musicnotes or Songtradr-style; or independent artists). Roughly $15–60k in advances plus revenue share. Begin with the month-one teacher list (*Knockin' on Heaven's Door*, *Riptide*, *Let It Be*, *Stand by Me*, *Three Little Birds*, *Somewhere Over the Rainbow* for ukulele). | The largest single lever on Category and Growth (about +0.5 to +0.8 each). It is what a "learn guitar" searcher picks on. |
| **Teacher video and a hand** | Shoot the 8 planned clips first, bow hold first (no competitor has violin lessons that listen), then about 30 more. Commission a stylised rigged hand ($0.5–2k) and ukulele and banjo usdz models. Get signed releases. | Closes the gap with Fender Play and Justin on teaching imagery, and gives store frame #3 "a teacher's hands". |
| **Brand and art direction** | An icon designer (an Icon Composer icon with real variants, a mark and a logotype; $4–10k). An art director and illustrator ($8–15k) for: a new *Kite Weather* cover, a pastiche audit of the 50 Originals, 6 spot illustrations (mic, reminder, listen, ear, empty states) and medal art. | Visual reaches 9.0 or more, and Timbre looks like a brand next to GuitarTuna in search. It also removes a derivative-design risk from the ad's second frame. |
| **Instrument photography provenance** | Confirm the source and licence of the 68 "provided" images in `photos.json`. If they are generated or unlicensed, replace them with renders under one light (`tools/models/cards.py`) or commissioned photos. | Avoids a public "AI-generated instruments" call-out and any licensing exposure. Gives one art direction. |
| **Recordings** | Real ukulele (soprano and low-G), mandolin and banjo sample sets ($1.5–3k). Band stems for the 10 best Originals. A real-world corpus of about 1,000 clips across phones, microphones and rooms, including chunks, chops and mutes. | Honest "Hear it" audio. A band worth hearing on the speaker and in the preview. A published accuracy claim no competitor can make ("measured on N real strums"). |
| **People and process** | An independent senior iOS reviewer with branch protection on `main` (PR #2 has 0 reviews across +340k lines; all 26 wave commits are authored "Claude"). A rule of no `[skip ci]` on `ios/` and squash merges. Drop the lint rule that hides the tool's name and replace it with reviews and ADRs. Paid blind and left-handed testers; a device lab; a TestFlight cohort of 300–500; 2–3 teacher quotes. | Turns "never vibe-coded" from a grep into a review trail an acquirer will price in. Makes the VoiceOver and left-handed claims shippable. Provides social proof before launch. |
| **App Store Connect programme** | Set the keyword field to WP2's page inventory, then create the violin, cello and ukulele Custom Product Pages with single-token keywords. Submit the "Holiday carols" In-App Event by about **10 November**, with carols free in its first week. The December featuring window has passed; nominate for January's "learn something new" with the Tune by feel story. Accessibility Nutrition Labels: declare Larger Text (after WP1's AX5 matrix), Dark Interface, Differentiate Without Colour, Sufficient Contrast and Reduced Motion; **VoiceOver only after** WP6 and WP8 plus a blind-tester pass through Unit 1. Apple Ads at about $1.5–3k a month only after RPI is measured. | The long tail (violin, cello, ukulele) is where Timbre can rank within months. All six competitors leave their accessibility labels empty, so Timbre would hold the only filled one. |
| **Free tier** | Approve a free song at the end of every unit 1 (WP5) and free basic scales. Keep Unit 2 as an A/B test once `unit2Free` is wired. | Makes the onboarding promise true and wins "best free practice app", not just "best free tuner". |

---

## 5. What NOT to do

**Business**
1. **Don't submit with `allow_untranslated`.** The renewal terms would be English in 48 storefronts.
2. **Don't add a monthly intro offer in App Store Connect** before WP4's disclosure ships. Buyers would be told "$6.99 now" while starting a free week.
3. **Don't announce the `_b` price test or the `unit2Free` test** before WP4 item 3 ships. Today both silently fall back, and the "results" would be noise.
4. **Don't plan Custom Product Page keywords that aren't in the app's keyword field**, and don't count on the deep link for a newcomer who opens from the Home Screen.
5. **Don't claim VoiceOver** in the Nutrition Label or the listing until the notes step speaks and cues are timed, and blind testers have finished Unit 1.
6. **Don't caption "Play songs with the band"** over a click track. Fix the audio, or say "in headphones".
7. **Don't show a hand-typed or global rating**, and don't fake social proof.
8. **Don't strike through a computed "was" price** in EU or UK storefronts.
9. **Don't buy installs** before the analytics ID is live and revenue per install is measured.
10. **Don't ship sleeves that imitate famous covers, or instrument photos whose provenance you can't show.**

**Product and engineering**
1. **Don't "fix" the island by narrowing its wings.** The status bar belongs to the system, so remove the mode.
2. **Don't fix the flickering lock by loosening the band or the hold.** Latch the display; the tracker's honesty is the product.
3. **Don't turn on voice processing for the tuner.** Use it for lessons only, behind a self-test.
4. **Don't let Tune by feel ship as the default for sighted users** before the device bleed test. Default it on only under VoiceOver.
5. **Don't add courses, units or tools.** The next content wave is correctness (muted beats, chord changes, ukulele editions) and recognisable songs.
6. **Don't arm a lint before the file owners have migrated**, and don't edit a file you don't own: ask its owner for a hook.
7. **Don't big-bang the `AppStore` split.** Extract `TunerSession` first, behind WP10's hooks.
8. **Don't hide the tool's name in comments while git names it as the only author.** The remedy is human review, squash merges and ADRs.
9. **Don't commit `[skip ci]` "WIP wave N" to `ios/`, and don't merge without a green gate.**
10. **Don't add chips, pills, glows or amber "for polish".** Every visual deduction this round was for too many of them, or for the wrong colour.
11. **Don't remove the honest trial timeline, the real-offers-only exit offer, or "Continue with the free tuner".** They are the best monetisation ethics in the category.

---

## 6. Foreman's verification log, and where jurors were wrong or overstated

### Verified true (code and data)
- **Arabic ₂E fixed.** `eb6ee5c` adds `.environment(\.layoutDirection, .leftToRight)` on the note HStack (`Readout.swift:299-300`, `PitchSniperView.swift:84`). The `Celebration.swift:80` and `PegCue.swift:57` renderings are single concatenated `Text` runs. Not counted as open; the capture is pending (WP1).
- **Island.** `GameUI.swift:454-458`, `:614-626`, `:671-703`; mounted at `RootView.swift:59`. The only `statusBarHidden` calls are in `LessonPlayer.swift:124` and `ChartPracticeView.swift:86`.
- **Lock.**
  - `TuneView.swift:357-363` reads `reading.inTune` every frame;
  - `TuningTracker.swift:76` resets the hold after a 150 ms gap;
  - `:6` sets `holdMs = 650`;
  - the lock path writes settings and records progress (`AppStore.swift:665-674`).
- **Band.**
  - `AudioService.swift:655` gates the band on headphones;
  - `Band.swift:252-254` says headphones only;
  - `bandOnSpeaker` is read only by `PersistenceTests`;
  - one `root` per `Bar` (`Band.swift:11-13`);
  - one stroke per bar (`PlayAlongSession.swift:278-285`);
  - `LeadChart.chords` holds the downbeat only (`SongSheet.swift:744-745`).
- **Mid-bar changes:** 216 of 419 arrangements in `curriculum.json` have a change off beat 0.
- **Muted strokes.**
  - `judgeChord` (`LessonSteps.swift:1793-1796`) marks a silent whole-beat stroke `.miss`;
  - `StrokeChords` reads 60 ms + 170 ms;
  - uke-8-1, man-4-4 and gtr-15-3 have no `muted` field.
- **Ukulele editions:** uke *Rondo* chords include Bb, Bb7, Cm, Eb, Fm and Gm; uke *Carmen* uses "D#"; the *Rondo* melody contains D4 C4 B4 C4.
- **Violin labels:** `Highway.swift:1149` labels the fret; the Next row says "fret" (`:395`).
- **Paywall table vs free tier:** `PaywallView.swift:706-724` against `FreeTier.swift:3-38`.
- **First song:** every instrument course's first song is lesson 9–20 and not free; `PaywallView.swift:356`; `PaywallPlan.swift:105-108`; `AppStore.swift:489`.
- **Levers:** `TimbreProduct.subscriptions = [annual, monthly]` (`Access.swift:11`); `annualProductID(remote:)` (`CommerceService.swift:108-111`); `unit2Free` appears only in a comment (`RemoteConfig.swift:16`); no `.flag(` call anywhere.
- **Monthly trial.**
  - `trialLabel` is annual-only (`CommerceService.swift:115-117`);
  - `wasTrial` is annual-only (`PaywallView.swift:1413`);
  - the fixture's monthly plan has no intro;
  - `APPLE-DELIVERY.md:32` tells the owner to add a 1-week monthly trial.
- **Cover.** `SongCover.swift:624` `pulse` ("Stacked pulse lines … one line lit"), in the pools at `:143` and `:343-345`.
- **Audit.** `AccessibilityAuditUITests.swift:11` `enforced = []`; `:122` catches "did not run".
- **Localisation (my runs; working tree clean afterwards).**
  - `report.py --check`: 584 app strings in 48 locales and 1,408 lesson strings in 9; "handoff out of date".
  - `critical.py`: legal 11 (528 locale-string gaps), permission 1 (48), VoiceOver 84 (4,032).
  - `apple-delivery.yml:23-27`, `:87-88`.
- **Swift and architecture.** `Package.swift:12` `.v5`; `project.yml:12` 5.10. `AppStore.swift` is 1,205 lines; 89 `@EnvironmentObject … AppStore`; 14 `ObservableObject`, 3 `@Observable`; 17 `@unchecked Sendable`; 5 `nonisolated(unsafe)`; 0 `#Preview`; 27 app unit tests.
- **Hygiene.**
  - No scratch files at the root; 0 review or bug references.
  - `lint_tells.py`: type-scale 112, test-coupling 46.
  - `lint_tells.py:88-90` bans "Claude" in comments.
  - `git log 7c8d46c..HEAD`: 26 commits, all "Claude", 22 `[skip ci]`, 12 WIP.
  - Repository: 258 of 259 commits by "Claude".
  - PR #2: 0 reviews.
- **CI** (`gh run list`). Last finished iOS runs: cancelled, failure, cancelled, failure, failure. On e74c390, core and iPad are green and the app job was in progress.
- **Tokens.** `controlLine` 0x5A606A measures 2.78:1 on `surface`, 2.94:1 on `stageRaised` and 3.18:1 on `stage`; 0x646A74 measures 3.23:1, 3.41:1 and 3.70:1 (my computation, matching inclusivity's).
- **Brand and assets.** `icon-dark.png` has the same MD5 as `icon.png`, with mean luminance 31.8/255. `photos.json`: 68 of 73 are "provided".
- **Tune by feel.** `tuneByFeel = false` (`LocalStore.swift:77`); Settings only (`SettingsView.swift:359`); the word "feel" appears in the listing only for the Watch metronome (`APP-STORE-LISTING.md:114`).
- **Audio session.** `AudioService.swift:815-829` knows only `.lessons` and `.recording`; SoundFX uses bare `AVAudioPlayer`. The effect on background audio needs a device.
- **R15 fixes confirmed:**
  - language (`LocalStore.swift:12`);
  - quarantine and `.bak` (`:289-308`);
  - grace (`Access.swift:26-34`);
  - haptics during recording (`AudioService.swift:821`);
  - HUD digits (`HighwayHUD.swift:46`, `:76`).
- **Apple documentation** (fetched): Custom Product Page keywords come "from your latest approved app version"; "select a unique set of keywords for each page"; the deep link applies when users "click Open".

### Verified true (screens and media)
- **07, 17:** the sparkle on "9:41", and "+5 XP" under the signal bars. **14:** "3 achievements unlock…" behind the signal and battery icons.
- **10b:** D3 at 0¢, "Hold it…", D3 unticked, "Quest 3/6".
- **Poster:** E2 at −3¢, "Hold it…".
- **Preview audio:** my `silencedetect` at −60 dB and 0.4 s found 17.7 s of 23.17 s silent. The highway clip is a click every 0.68 s. PREVIEW.txt: lock clip 121.42–124.83 s, lock sync at 125.33 s.
- **65b:** violin F♯ drawn as "2" with finger "1".
- **06:** "Unlock your full plan"; labels detached from the Day 9 and Day 12 nodes; amber ▶; "$83.88" struck through; the ridge-line sleeve.
- **16:** no plan cards; the "14 DAYS FREE" tag floats.
- **49b, 49c:** the scrolls cut flat at the stage top.
- **l10n-de-welcome:** English headline and subline; the chip row ends "Gitarre, Bass, Ukulele, …".

### Where jurors were wrong or overstated
1. **Inclusivity on ₂E.** The juror concluded that `.environment(\.layoutDirection, .leftToRight)` "doesn't hold on device". The capture came from the run on `543192c`, before `eb6ee5c` added that line, so the code the juror read is the fix. It is not counted as open; WP1's `ar` frame proves it.
2. **Category item 14 misattributes the status-bar collision** to the Live Activity and proposes ending the activity before captures. Frames 07 and 17 show the in-app `RewardToast` island pill (sparkles, "+5 XP"). The fix is in `GameUI.swift` (B2), not `LiveActivityController`.
3. **Delight's fix for the pill** (cap the wings at 36 pt) is not enough. Any layer in that band sits beside the clock and the status icons. I rule for the visual juror's fix: remove island mode and dock the toast under the header.
4. **All three jurors understated the preview's silence.**
   - visual: about 27 % in the final stretch;
   - delight: about 7.5 s of digital zero;
   - growth: about 13 s silent or near-silent.

   At −60 dB I measure 17.7 of 23.2 s (77 %), and the "band" clip is a bare click. The direction is the same; the problem is larger.
5. **Growth: "the Violin chip is gone from the German row".** It is not removed. The row shows as many chips as fit, then "…" (`OnboardingView.swift:316-344`), and German's longer names push Violine into the overflow. The effect is the same, the beachhead instrument hidden, so I keep it as a minor fix in WP4.
6. **Category's "157 of 330" against my "216 of 419".** These are consistent: the juror counted strummed arrangements, I counted all of them. About half of the songs change chord mid-bar either way.
7. **Technical's "16 `ObservableObject`".** I count 14 declarations. Immaterial to the finding.
8. **Visual on frame 16** ("a rendering failure or a capture mid-materialisation"). I can't tell from a still. Because the tag is drawn outside the cards' glass group, it can show alone on any slow product load. I treat it as a blocker until a test proves the tag never shows without its card.
9. **Category scored the dead-string check "fixed (honestly limited by physics)".** I agree, and note that it is the feature no competitor has, and it is absent from the store. That makes it a growth item (WP2), not only a category credit.
10. **The technical juror framed the hygiene lint as "concealment".** I agree, and move it to the owner (§4). The owner's "never vibe-coded" bar is met by human review, branch protection and squash merges, not by banning a word from comments.
11. **Visual and Delight credit "Tune by feel" as a world first.** I can confirm only that none of the six competitors offers it. It is the strongest editorial story the app has, and it is off by default and unlisted.
12. **No juror's score is out of line with the evidence by more than about ±0.1**, so I did not re-score anyone. The one item I'd move, ₂E, leaves the overall at 8.3.
