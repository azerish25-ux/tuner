# App Store listing (English, U.S.)

Paste into App Store Connect → the app → the version's page and App Information. Every length below is within Apple's limits, and every count is the build's own: 60 instruments, 132 tunings, 17 courses, 819 lessons, 120+ songs (124 distinct titles; the Songs tab's arrangements per instrument are more) and 50 Originals. `python3 tools/marketing/screenshots.py --check` re-checks the counts in this file's paste blocks and tables against `curriculum.json` and `catalog.json`, and the lengths against Apple's limits, so a stale number fails before it reaches the store.

What the listing claims, and what it leaves out until the app makes it true:

- **Free tuner, no ads, no account** leads, because those decide a tuner install and no funded competitor can say all three.
- **"120+ songs"**, not the arrangement count: the same song on two instruments is one song to a buyer.
- **No VoiceOver claim** (here or in the Accessibility Nutrition Labels) until the play-along works with it. **No "whole chords"** for strumming until the strum steps judge the chord as well as the timing: chord steps hear every string, strum steps judge timing.
- **No language count.** The app follows the phone's language, but until every shipped locale is complete the listing doesn't count them.
- **No ratings, quotes or laurels** until they are real and consented (≥ 4.6★ from ≥ 200 ratings for a rating line).

## App Information

| Field | Value | Limit |
|---|---|---|
| Name | Timbre: Guitar Tuner & Lessons | 30/30 |
| Subtitle | Learn Songs: Ukulele & Violin | 29/30 |
| Primary category | Music | |
| Secondary category | Education | |
| Age rating | 4+: see [Age rating](#age-rating) | |
| Privacy Policy URL | `<privacy policy URL>` (**owner TODO**: the hosted policy, on a custom domain; the build reads the same address from `TIMBRE_PRIVACY_POLICY_URL`) | required |

The name carries "guitar tuner", the category's highest-volume search; the subtitle carries the intent that pays ("learn songs") and the two instruments where Timbre can rank first (ukulele, violin). Bass moves to the keywords.

## Age rating

App Store Connect → the app → App Information → Age Ratings. Apple replaced the questionnaire in 2025. The ratings are now 4+, 9+, 13+, 16+ and 18+ (12+ and 17+ are gone), and new questions cover in-app controls, capabilities (user-generated content, messaging, advertising, web access, social media), medical and wellness topics, and violent themes. App Store Connect has required the new answers for every submission since January 31, 2026, and the social media question since September 2026. Apple computes the rating from the answers, and the strictest answer sets it. Apple's [definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) allow at 4+ only the in-app controls, the capabilities other than web access and social media, and infrequent contests. Any profanity, horror, suggestive theme, cartoon violence or weapon makes an app at least 9+, and any alcohol, tobacco or drug reference makes it at least 13+. Two of Apple's definitions count mere *references*: alcohol, tobacco and drugs, and guns or other weapons (swords and knives included). A title or a single lyric line is enough.

Timbre's answers, checked against this build: every title, lyric and lesson text in `curriculum.json`, swept in October 2026.

| Section | Question | Answer | Why |
|---|---|---|---|
| In-app controls | Parental Controls | No | |
| | Age Assurance | No | The app asks no age and uses no age-range API. |
| Capabilities | Unrestricted Web Access | No | Terms and Privacy open in Safari. The app has no browser or web view. |
| | User-Generated Content | No | Charts and audio files a player imports into Your songs (from Files, the clipboard, the share sheet or the chart editor) are user content. Apple's question, though, is about "the broad distribution of content created by users", and these stay on that device where nobody else sees them. A Yes would still allow 4+, but it would bring Guideline 1.2's filtering, reporting and blocking duties, which apply only to content that others see. Answer Yes if imported charts ever become shareable inside the app. |
| | Social Media | No | No feed and no discovery of other players' content. The friend streak shows Game Center friends' streak lengths, nothing they made. |
| | Messaging and Chat | No | "Challenge a friend" opens Game Center's own challenge, or sends a link through the system share sheet. Players can't write to each other in the app. |
| | Advertising | No | No ads. The paywall sells Timbre's own subscription. |
| Mature themes | Profanity or Crude Humor | None | |
| | Horror/Fear Themes | None | A few old songs mention a death (Clementine, Molly Malone, Danny Boy), but none tells a frightening story. Ghost Light is about a theatre's stage lamp. |
| | Alcohol, Tobacco, or Drug Use or References | None | "Drunken Sailor" was replaced by "Bobby Shafto". Good King Wenceslas sings Neale's verses 1, 2, 4 and 5, leaving out verse 3 ("bring me wine"). The Originals were cleaned of "last call" and "smoke in the air". "A cup o' kindness" (Auld Lang Syne) and "a cup of good cheer" (We Wish You a Merry Christmas) name no drink. "Feuertrunken" in the German Ode to Joy means "drunk with fire", a figure of speech. Soldier's Joy is a fiddle tune with no words. Its title names no drug, though one theory links it to morphine. |
| Medical or wellness | Medical or Treatment Information | No | |
| | Health or Wellness Topics | No | The voice course's breathing and warm-ups are singing technique, not self-care advice. |
| Sexuality or nudity | Mature or Suggestive Themes | None | The love songs go no further than holding hands and a slow dance. The Originals were cleaned of a hotel "Do not disturb" sign, "cherry pop" and "somebody new in your bedroom". Spray Paint Sunrise now paints a sun rather than the singers' names, so it no longer tags a wall. |
| | Sexual Content or Nudity; Graphic Sexual Content and Nudity | None | |
| Violence | Cartoon or Fantasy Violence; Realistic Violence; Prolonged Graphic or Sadistic Realistic Violence | None | The catalogue has no murder ballads and no battle songs. |
| | Guns or Other Weapons | None | Down by the Riverside sings its traditional "walk with the Prince of Peace" verse, not "lay down my sword and shield". The pitch game is called Bullseye (a target, no weapon words). |
| Chance-based activities | Gambling; Simulated Gambling | None | Nothing in the app can be bet. Camptown Races' "I'll bet my money on the bobtail nag" is a lyric, not betting. |
| | Loot Boxes | None | Rewards are earned, never bought or drawn at random. |
| | Contests | Infrequent | Game Center leaderboards on Bullseye, the ear trainer, the streak and eight featured songs, and friend challenges on them. Competing is optional and covers a small part of the app. |
| Age categories | Made for Kids | Not Applicable | The Kids category would need a parental gate before every purchase and every link out (Guideline 1.3). 4+ doesn't. |

**Result: 4+.** Confirm it on the summary App Store Connect shows after the last answer. Every answer sits inside Apple's 4+ list. At 4+, Timbre stays visible to a child whose Screen Time allows only 4+ or 9+ apps, and many beginners on ukulele and guitar are children.

**Bullseye (the pitch game).** It was called Pitch Sniper; it and its badges were renamed (Bullseye, High Scorer, Round Winner) so nothing borrows shooting words, and "None" stands for weapons.

**Keeping 4+.** Answer the questionnaire again whenever songs or games are added, and hold new content, the Originals included, to these rules:

- No drink, smoke or drug, in a title or a lyric. Leave out the verse rather than the song when only one verse has it.
- No weapons, not even laid down.
- No innuendo, horror, gambling or swearing.
- Give leaderboards to a featured set of songs, not to every song: Contests answered Frequent makes the app 13+.

`docs/content/PUBLIC-DOMAIN-CLEARANCE.md` lists the songs taken out or changed for the rating and the tunes turned down for it.

## Keywords (98/100)

```
bass,chromatic,cello,mandolin,banjo,metronome,chord,ear training,practice,tuning,fiddle,pitch,sing
```

Apple already indexes the words in the name and subtitle (guitar, tuner, lessons, learn, songs, ukulele, violin), so the keywords don't repeat them. Singular forms only (Apple matches plurals), no category names ("music"), no spaces after commas. "Bass" moved here from the subtitle; "practice" catches "guitar practice" and "practice app"; "tuning" catches searches that name a tuning ("drop D tuning", "cello tuning"), which "tuner" in the name doesn't match. "Strobe" and "uke" gave way: "strobe tuner" searches are few, and "uke" is matched by "ukulele" in the subtitle for most queries. Each Custom Product Page adds its own keywords ([Custom Product Pages](#custom-product-pages)).

## Promotional text (158/170; can change without a review)

```
Free tuner, no ads, no account. Then lessons that listen as you play guitar, ukulele, violin, cello, bass, mandolin or banjo, and 120+ songs to play along to.
```

## Description

> **Owner TODO before pasting:** replace `<privacy policy URL>` on the last line with the hosted privacy policy, the same URL as App Information → Privacy Policy URL. If Game Center isn't set up for this version ([APPLE-DELIVERY.md §6.1](APPLE-DELIVERY.md#61-game-center)), delete the Game Center bullet. Everything else is ready to paste.

```
Free tuner, no ads, no account. Then lessons that listen as you play.

Timbre is a precise tuner and a music teacher in one app. Tune any of 60 instruments in seconds, then play real lessons that listen to you and tell you exactly how you did.

TUNE ANYTHING, FREE
• Every instrument's standard tuning is free, from guitar, ukulele and violin to mandolin, banjo, oud and erhu
• A chromatic and strobe tuner with cent-level precision
• 132 tunings, from drop D and open G to DADGAD, plus your own
• Auto string detection, with a check-off as each string locks in
• Strum to tune: one strum reads every string at once and shows which one to tune first
• Studio-lit 3D guitars, basses, violin, cello and mandolin, with the peg to turn shown on the headstock
• Capo, adjustable A4 reference, solfège and sargam note names

LEARN BY PLAYING
• 819 lessons in 17 courses: guitar, ukulele, bass, violin, cello, mandolin, banjo, voice, ear training, music theory and rhythm, plus songbooks for ukulele, mandolin and violin
• Timbre listens as you play: single notes, every string of a chord, and the timing of your strumming, with pitch feedback and timing in milliseconds
• "Show me" plays each new chord on a 3D guitar, the fingers landing in order
• A play-along note highway that slows down for you, then speeds back up as you improve

PLAY SONGS
• 120+ songs, each a full arrangement: classics from Jingle Bells to Amazing Grace, and 50 Originals written for Timbre in today's styles
• Play along with the band in your headphones while the words light up
• Your songs: paste or import any chord chart, transpose it, scroll it in time, and listen to the original on Apple Music beside it

KEEP IT GOING
• Stars, XP, daily quests, streaks and badges
• Game Center: a weekly Bullseye league, song leaderboards and friend challenges
• Apple Watch: a metronome you feel on your wrist, and today's practice at a glance
• Home Screen and Lock Screen widgets, a Live Activity and Siri shortcuts

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course

FREE TO START
Every instrument's standard tuning is free, and guitar, bass, ukulele, violin and cello tune free in every tuning. The first unit of every course and a shelf of songs are free too. Timbre Pro unlocks every lesson and song, every tuning and the full practice set. With notifications on, Timbre reminds you two days before a free trial ends.

Private by design: audio is analysed on your iPhone and never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: <privacy policy URL>
```

## What's New (first release)

```
Welcome to Timbre: a free tuner for 60 instruments, and 819 lessons that listen as you play.
```

## Screenshots (6.9" iPhone and 13" iPad)

The tables below are the only place the store frames are described: `tools/marketing/screenshots.py` reads them and composes each capture under its caption, in the look the last column names. To change a caption or a look, edit it here and render again:

```
python3 tools/marketing/screenshots.py <ci-out/screenshots> <out folder>                  # iPhone, 1320x2868
python3 tools/marketing/screenshots.py <ci-out/ipad-screenshots> <out folder> --ipad      # iPad, 2752x2064 landscape / 2064x2752 portrait
python3 tools/marketing/screenshots.py <ci-out/screenshots> <out folder> --page violin    # a Custom Product Page's set
python3 tools/marketing/screenshots.py <de captures> <out folder> --locale de-DE          # a localized set (APP-STORE-LISTING-LOCALIZED.md)
python3 tools/marketing/screenshots.py --check                                            # every table, every locale, every count
```

`<ci-out/screenshots>` is the iOS workflow's exported attachments (a `manifest.json` beside the PNGs) or any folder of PNGs named after their captures. Each run also writes `sheet.png`, the set side by side at search-result size, and warns when two frames look alike at that size.

**The looks.** The set is art-directed, not one template nine times: each frame takes the accent of the feature it shows (the tuner's mint, the Originals' sky, the course hues lime, violet and orchid, the stars' gold, the streak's flame, the stage light's warm spotlight), and one frame is light, so the row reads as a colour progression at thumbnail size. Amber and coral never wash a frame: in the app they mean "adjust" and "wrong". The captions are set in Sora at 120 px or more, the supporting line at 56 px in ink at 60 %; there is no eyebrow (the app's name already sits above the gallery). The layouts:

| Look | What it does |
|---|---|
| `breakout` | The 3D headstock rises out of the top of the screen and over the frame's stage, the readout and the string chips below it in the screen, enlarged, bleeding off the bottom |
| `zoom` | The hero region cropped and enlarged (about 120 %), full width, bleeding off the bottom |
| `callout` | The whole screen, with its key detail enlarged in a card that breaks out over the screen's edge |
| `wall` | The instrument browser in front of a wall of the app's own instrument photographs |
| `light` | The screen on warm paper: the one light frame in the dark run |
| `offset`, `offset-left` | Caption set left (right), the screen shifted right (left), bleeding off two edges |
| `flip` | The screen from the top, bleeding off it, the caption at the foot |
| `side`, `side-right` | iPad landscape: the caption in a column on the left (right), the screen bleeding off the other edge |

**The captures.** Every frame comes from exactly one capture in the UI tests, and that capture is deterministic: TimbreUITests keeps a frame under its own name only when it checked that the screen shows what the caption says (`storeFrame`); otherwise the test fails and keeps the picture as `<name>-wrong`, which this tool refuses. Store scenes (`TIMBRE_SCENE`, `ios/Timbre/Root/DemoScenes.swift`) put the app into each hero moment through its own code paths: the tuner's lock (#1, caught mid-comet: the scene plucks the string again every 4 s and the test keeps the picture taken 0.35 s after a lock), *Kite Weather* from bar 16 with every earlier note played clean (#2, kept only when two pictures 120 ms apart show the same HUD, so no counter is caught mid-change), the chord with every string lit (#3), the instrument browser (#4) and the violin's lock and song (the violin page). The results (#7) follow a play-along the demo pitch plays clean, kept only with three stars. Every capture shows the same player: the UI tests' seeded history (`DemoData` in `ios/Timbre/TimbreApp.swift`), a 7-day streak that already counts today, level 5. Each waits for its screen to settle (`stillScreenshot` in `ios/TimbreUITests/StillScreen.swift`).

No two frames show the same lesson, and the first three answer the three questions a searcher has: is it free (#1), does it really listen (#2), can I play something today (#3).

### iPhone 6.9"

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Free tuner. No ads.** | 60 instruments, to the cent | a string locked on the 3D headstock, its peg ringed and ticked, the lock's comet running down the string (`10b-tune-locked`) | `breakout mint` |
| 2 | **Hear exactly how you played** | Pitch and timing on every note | *Kite Weather* on the highway mid-chorus at ×4, the words lighting up under the runway (`65-song-perform`) | `zoom sky` |
| 3 | **Play your first chord today** | Timbre hears every string | E minor's chord step with every string lit (`52b-lesson-chord`) | `callout lime` |
| 4 | **Tune whatever you play** | 60 instruments, 132 tunings | the instrument browser on the Folk & world strings, the wall of instruments around it (`31b-instruments-folk`) | `wall spotlight` |
| 5 | **Play songs, start to finish** | 120+ songs, classics to Originals | the Songs tab (`63-songs`) | `light orchid` |
| 6 | **Learn at your own pace** | 819 lessons in 17 courses | Learn, with the next lesson up (`50-learn`) | `offset violet` |
| 7 | **Five minutes a day adds up** | Stars, streaks and daily quests | lesson results with three stars after a clean play-along (`62-lesson-results`) | `zoom gold` |
| 8 | **One strum checks every string** | See which string to tune first | Strum to tune: six strings read from one strum, A2 the one to tune first (`11b-tune-strum`) | `flip mint` |
| 9 | **See yourself get better** | Accuracy, string health, badges | the Progress screen (`32-journey`) | `offset-left flame` |

### iPad 13"

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Free tuner. No ads.** | 60 instruments, to the cent | the tuner in landscape, a string locked (`ipad-landscape-tune`) | `side mint` |
| 2 | **Tune whatever you play** | Violin to oud, sitar to erhu | the instrument browser, a full page of its own, on the bowed strings and the Folk & world strings (`ipad-landscape-instruments`) | `side-right spotlight` |
| 3 | **Play songs, start to finish** | 120+ songs, classics to Originals | the Songs tab (`ipad-landscape-songs`) | `light orchid` |
| 4 | **Five minutes a day adds up** | A daily set, quests and ear games | the Practice tab (`ipad-landscape-practice`) | `side violet` |

### iPhone 6.9": violin page

The violin Custom Product Page's set ([below](#custom-product-pages)). Its first two frames are the violin's own; the rest are the main set's.

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Tune your violin, free** | G, D, A and E, to the cent | the 3D violin, G, D and A locked, the lock's comet on the A string (`49d-tune-violin-locked`) | `breakout orchid` |
| 2 | **Play songs on your violin** | From Jingle Bells to Ode to Joy | *Jingle Bells* from the violin songbook on the runway, its last chorus lighting up (`65b-song-perform-violin`) | `zoom sky` |
| 3 | **Hear exactly how you played** | Pitch and timing on every note | lesson results with three stars (`62-lesson-results`) | `zoom gold` |
| 4 | **Play songs, start to finish** | 120+ songs, classics to Originals | the Songs tab (`63-songs`) | `light orchid` |
| 5 | **Learn at your own pace** | 819 lessons in 17 courses | Learn (`50-learn`) | `offset violet` |

### App Preview (6.9")

Run the **App Preview** workflow by hand (Actions → App Preview → Run workflow; the `preview` input picks `guitar` or `violin`). It records the `AppPreviewUITests` tour on a Pro Max simulator with the status bar at 9:41, and publishes `preview.mp4` (886×1920, 30 fps, H.264 High, stereo AAC, 20–25 s), `poster.png`, `contact.png` and `PREVIEW.txt` to the `ci-results/preview` branch. `PREVIEW.txt` gives the poster frame's time; set it as the preview's poster frame in App Store Connect.

The cut, in order, with hard cuts on the band's beat: a string drifting into tune on the 3D headstock and locking, held 1.5 s (the poster: ✓ In tune, the peg's tick); the other strings locking, chosen as automatic detection chooses them, and the full-tune celebration; "Show me" fingering E minor on the 3D guitar; *Kite Weather*'s last chorus on the highway at ×4 with the band; the song's stars; the Songs tab, under 3 s; the end card. The soundtrack is the app's own sound at the moment each clip was filmed (the lock bells, the full-tune strum, Show me's chord, the band in headphones, the stars), loudness-normalised; nothing is added. `tools/marketing/preview.py` draws the captions and the end card from the tables below (Clip, Caption, Accent); the `end` row is the end card's line and `end-note` the line under it.

| Clip | Caption | Accent |
|---|---|---|
| `lock` | Free tuner. No ads. | mint |
| `tuned` | Every string, checked | mint |
| `showme` | See it played in 3D | mint |
| `highway` | Play songs with the band | sky |
| `results` | Hear how you did | gold |
| `songs` | 120+ songs to learn | spotlight |
| `end` | Tune. Learn. Play songs. | mint |
| `end-note` | Free tuner · No ads · No account | |

### App Preview: violin page

The same tour on the 3D violin, then *Jingle Bells* from the violin songbook (free), for the violin Custom Product Page.

| Clip | Caption | Accent |
|---|---|---|
| `lock` | Tune your violin, free | orchid |
| `tuned` | G, D, A, E: all in tune | orchid |
| `highway` | Play songs on your violin | sky |
| `results` | Hear how you did | gold |
| `songs` | 120+ songs to learn | spotlight |
| `end` | Violin tuner and lessons | orchid |
| `end-note` | Free tuner · No ads · No account | |

## Custom Product Pages

Timbre's moat for search is breadth: 60 instruments, and lessons that listen on violin, cello, ukulele, mandolin and banjo, where the big apps have nothing. Since July 2025 a Custom Product Page can be assigned keywords and appear in organic search, so each instrument family gets a page of its own: its own first frames, promotional text and keywords, and a deep link that opens onboarding with that instrument chosen (`timbre://tune?instrument=<catalog id>`, read by `DeepLink.swift` before onboarding is done). The App Store Connect steps are in [APPLE-DELIVERY.md §9](APPLE-DELIVERY.md#9-app-store-connect-growth-programme). Keywords may repeat across pages; each page's are matched to that page.

| Page | Keywords to assign | First frames | Promotional text | Deep link | Preview |
|---|---|---|---|---|---|
| Violin | violin tuner, violin lessons, learn violin, fiddle, fiddle tuner, violin app | the violin page's set | Tune your violin free, then learn with lessons that listen: bowing, first fingers and songs from Jingle Bells to Ode to Joy. No ads. | `timbre://tune?instrument=violin.standard.4` | violin |
| Cello | cello tuner, cello lessons, learn cello, cello app | `49c-tune-cello-3d`, then the main set | Tune your cello free, then learn to play with lessons that hear every note. No ads, no account. | `timbre://tune?instrument=cello.standard.4` | main |
| Ukulele | ukulele tuner, uke tuner, learn ukulele, ukulele songs, ukulele chords | `17-tune-photo-stage`, then the main set | Tune your ukulele free, then play songs from a whole ukulele songbook, with lessons that listen. | `timbre://tune?instrument=ukulele.soprano.4` | main |
| Bass | bass tuner, bass guitar tuner, learn bass, bass lessons | `19-tune-bass-3d`, then the main set | Tune your bass free and learn grooves that lock with the band. | `timbre://tune?instrument=bass.electric.4` | main |
| Mandolin | mandolin tuner, mandolin lessons, learn mandolin, bluegrass | `49-tune-mandolin-3d`, then the main set | Tune your mandolin free, then a mandolin course and songbook that listen as you play. | `timbre://tune?instrument=mandolin.standard.8` | main |
| Banjo | banjo tuner, 5 string banjo, learn banjo, banjo lessons | the main set (a banjo capture is owed) | Tune your 5-string banjo free, then rolls, chords and songs with lessons that listen. | `timbre://tune?instrument=banjo.five.5` | main |
| Chromatic and strobe | chromatic tuner, strobe tuner, tuner app, pitch | `15-tune-chromatic`, then the main set | A precise chromatic and strobe tuner for anything you play or sing. Free, no ads. | `timbre://tune?instrument=guitar.acoustic.6` (then the chromatic chip) | main |
| Ear training | ear training, interval trainer, relative pitch, music theory | `23-ear-training`, then the main set | Train your ear: intervals, chord qualities and a 40-lesson ear course. | `timbre://ear` | main |
| Voice | singing, vocal range, sing in tune, pitch trainer | `24-voice-range`, then the main set | Find your range and sing in tune, with a voice course that listens. | `timbre://tune?instrument=guitar.acoustic.6` | main |
| Songs | learn songs, play along, chord charts, songbook | `65-song-perform`, `63-songs`, then the main set | 120+ songs to play along to, and any chord chart you paste. | `timbre://songs` | main |

A page whose first frame is a plain capture (`49c-tune-cello-3d`, `17-tune-photo-stage`, …) needs it promoted to a store frame first: a `storeFrame` check in its UI test and a table here, as the violin page has. Start with violin, cello and ukulele: those queries have the weakest competition and the highest prices paid elsewhere (Trala charges $119.99 a year for violin alone).

## In-app purchase display names

| Product | Display name | Description (55 max) |
|---|---|---|
| `timbre_pro_annual` | Timbre Pro, yearly | Every lesson, song, tuning and practice tool |
| `timbre_pro_monthly` | Timbre Pro, monthly | Every lesson, song, tuning and practice tool |
| `timbre_plus_lifetime` | Timbre Pro, lifetime | Everything in Pro, paid once |

## Review notes

```
Timbre needs the microphone to tune and to hear lessons. With no instrument to hand, a 440 Hz tone from another device works for the tuner.
Every instrument's standard tuning is free; guitar, bass, ukulele, violin and cello tune free in every preset tuning. Other instruments' alternate tunings, and lessons after each course's first unit, are part of Timbre Pro.
The paywall opens from any locked lesson (Learn tab → a lesson in unit 2 or later), from the Practice tab → Tools → Drone, and from a Pro tuning (Tune tab → tap the instrument name → Mandolin → an alternate tuning). It shows the price, the trial timeline, auto-renewal terms, Restore, Terms and Privacy.
No account or login is needed.
```

## Pricing: the owner decides

The prices live in App Store Connect; the app shows whatever Apple returns. The panel's recommendation (REVIEW 15, growth): yearly **$49.99** with the **14-day** trial, monthly **$9.99** with a 7-day introductory offer (which also powers the paywall's exit offer), lifetime **$149.99**, kept off the onboarding paywall, and Family Sharing on for the yearly plan and lifetime. Then test $49.99 against $59.99 with a second yearly product chosen by the remote settings file ([APPLE-DELIVERY.md §5](APPLE-DELIVERY.md#5-analytics-links-and-remote-settings)).

- **Keep the 14-day trial.** Yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 days (RevenueCat, 2026). An earlier version of this file suggested 7 days; don't.
- **Keep the trial timeline and the reminder two days before the trial ends.** They answer the billing complaints competitors get, and editors notice.
- **Turn on the Billing Grace Period only with a build that keeps Pro during it** (the entitlement fix shipped in WP1; check it on a TestFlight build first).
