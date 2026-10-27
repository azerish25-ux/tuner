# App Store listing (English, U.S.)

Paste into App Store Connect → the app → the version's page and App Information. Every length below is within Apple's limits, and every count is the build's own: 60 instruments, 132 tunings, 11 courses, 526 lessons, 140+ songs (146 distinct titles; the songbooks' arrangements per instrument are more and count once) and 50 Originals. `python3 tools/marketing/screenshots.py --check` re-checks the counts in this file's paste blocks and tables against `curriculum.json` and `catalog.json`, and the lengths against Apple's limits, so a stale number fails before it reaches the store.

What the listing claims, and what it leaves out until the app makes it true:

- **Free tuner, no ads, no account** leads, because those decide a tuner install and no funded competitor can say all three.
- **"140+ songs"**, not the arrangement count: the same song on two instruments is one song to a buyer.
- **"Timbre hears every strum: the right chord, on time, and which string didn't ring."** Strum steps judge each stroke's chord as well as its timing, a muted stroke (a ukulele chunk, a mandolin or reggae chop) passes as muted, and a chord step names the string that didn't ring with the finger that stopped it. No competitor does the last. The line goes if a release grades a correct muted stroke as a miss.
- **Tune by feel** is a feature, not a default: the phone pulses with the beat between the string and its note and goes still at the lock. It is on under VoiceOver and a tap away on the tuner for everyone else.
- **No VoiceOver claim** (here or in the [Accessibility Nutrition Labels](#accessibility-nutrition-labels)) until the lessons' notes step speaks the next note, the play-along's cues land on time, and blind testers have finished Unit 1.
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
| Privacy Policy URL | `https://timbre-support.timbre.workers.dev/privacy` (the build reads the same address from `TIMBRE_PRIVACY_POLICY_URL`; current candidate policy/source alignment verification remains pending) | required |

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

## Keywords (97/100)

```
violin,ukulele,uke,cello,bass,mandolin,banjo,fiddle,chromatic,strobe,ear training,metronome,chord
```

The field is the inventory of the [Custom Product Pages](#custom-product-pages). Apple lets a page be assigned keywords only "from your latest approved app version", that is, from this field, and recommends "a unique set of keywords for each page". So every word a page needs is here, one page each: violin and fiddle (violin page), ukulele and uke (ukulele), cello, bass, mandolin, banjo, chromatic and strobe (chromatic tuner), ear training. "Violin" and "ukulele" are also in the subtitle; they are repeated here only because their pages need them. "Metronome" and "chord" stay with the default page.

The rest of each query comes from the name and subtitle (guitar, tuner, lessons, learn, songs), so "violin tuner", "learn ukulele" and "cello tuner" still match. Singular forms only (Apple matches plurals), no category names ("music"), no spaces after commas. "Uke" is its own query ("uke tuner", "uke chords"); App Store search doesn't match it inside "ukulele". "Practice", "tuning", "pitch" and "sing" gave way to the instrument words. `screenshots.py --check` fails when a page names a keyword that isn't in this field, when two pages share one, or when a word repeats the name or subtitle without a page that needs it.

## Promotional text (170/170; can change without a review)

```
Free tuner, no ads, no account. Feel each string come into tune, then play lessons that listen on guitar, ukulele, violin, cello, bass, mandolin or banjo, and 140+ songs.
```

## Description

> **Current candidate:** the production privacy URL is resolved and the unconditional Game Center description bullet is removed because integration defaults off. The live-microphone privacy wording is source-bound; published-policy alignment, device/assets and account release checks remain pending. Do not upload on text validation alone.

```
Free tuner, no ads, no account. Then lessons that listen as you play.

Timbre is a precise tuner and a music teacher in one app. Tune any of 60 instruments in seconds, then play real lessons that listen to you and tell you exactly how you did.

TUNE ANYTHING, FREE
• Every instrument's standard tuning is free, from guitar, ukulele and violin to mandolin, banjo, oud and erhu
• A chromatic and strobe tuner with cent-level precision
• 132 tunings, from drop D and open G to DADGAD, plus your own
• Auto string detection, with a check-off as each string locks in
• Strum to tune: one strum reads every string at once and shows which one to tune first
• Tune by feel: the phone pulses with the beat between your string and its note, slower as they meet and still at the lock, so you can tune without looking
• Studio-lit 3D guitars, basses, violin, cello and mandolin, with the peg to turn shown on the headstock
• Capo, adjustable A4 reference, solfège and sargam note names

LEARN BY PLAYING
• 526 lessons in 11 courses: guitar, ukulele, bass, violin, cello, mandolin, banjo, voice, ear training, music theory and rhythm, plus songbooks for ukulele, mandolin, violin, cello and bass
• Timbre hears every strum: the right chord, on time, and which string didn't ring
• Every note judged as you play it, its pitch to the cent and its timing to the millisecond
• "Show me" plays each new chord on a 3D guitar, the fingers landing in order
• A play-along note highway that slows down for you, then speeds back up as you improve

PLAY SONGS
• 140+ songs, each a full arrangement: classics from Jingle Bells to Amazing Grace, and 50 Originals written for Timbre in today's styles
• Play along with the band in your headphones while the words light up
• Your songs: paste or import any chord chart, transpose it, scroll it in time, and listen to the original on Apple Music beside it

KEEP IT GOING
• Stars, XP, daily quests, streaks and badges
• Apple Watch: a metronome you feel on your wrist, and today's practice at a glance
• Home Screen and Lock Screen widgets, a Live Activity and Siri shortcuts

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course

FREE TO START
Every instrument's standard tuning is free, and guitar, bass, ukulele, violin and cello tune free in every tuning. The first unit of every course and a shelf of songs are free too. Timbre Pro unlocks every lesson and song, every tuning and the full practice set. With notifications on, Timbre reminds you two days before a free trial ends.

Private by design: live microphone audio is analyzed on your device, never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: https://timbre-support.timbre.workers.dev/privacy
```

## What's New (first release)

```
Welcome to Timbre: a free tuner for 60 instruments, and 526 lessons that listen as you play.
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

`<ci-out/screenshots>` is the iOS workflow's exported attachments (a `manifest.json` beside the PNGs) or any folder of PNGs named after their captures. Each run also writes `<set>-sheet.png`, the set side by side at search-result size, and warns when two frames look alike at that size. Where each capture's hero region sits (the crop a look uses) is the `FOCUS` table at the top of the script: adjust it there when a screen's layout moves.

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

**The captures.** Every frame comes from exactly one capture in the UI tests, and that capture is deterministic: TimbreUITests keeps a frame under its own name only when it checked that the screen shows what the caption says (`storeFrame`); otherwise the test fails and keeps the picture as `<name>-wrong`, which this tool refuses. Store scenes (`TIMBRE_SCENE`, `ios/Timbre/Root/DemoScenes.swift`) put the app into each hero moment through its own code paths: the tuner's lock (#1 and the iPad's #1, caught mid-comet: the scene plucks the string again every 4 s and the test keeps the picture taken 0.35 s after a lock, and only when the selected string's chip shows its tick and the readout its In tune badge), *Kite Weather* from bar 16 with every earlier note played clean (#2, kept only when two pictures 120 ms apart show the same HUD, so no counter is caught mid-change), the chord with every string lit (#3), the instrument browser (#4), and the violin's, cello's and ukulele's locks, the violin's song and the violin's results (the instrument pages). The results (#7) follow a play-along the demo pitch plays clean, kept only with three stars. Every capture shows the same player: the UI tests' seeded history (`DemoData` in `ios/Timbre/TimbreApp.swift`), a 7-day streak that already counts today, level 5. Each waits for its screen to settle (`stillScreenshot` in `ios/TimbreUITests/StillScreen.swift`). A frame whose top edge would cut through text (the status bar, a screen's title) is refused at render: each crop starts in a gap (`FOCUS` in the script).

No two frames show the same lesson, and the first three answer the three questions a searcher has: is it free (#1), does it really listen (#2), can I play something today (#3).

### iPhone 6.9"

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Free tuner. No ads.** | 60 instruments, to the cent | a string locked on the 3D headstock, its peg ringed and ticked, the lock's comet running down the string (`10b-tune-locked`) | `breakout mint` |
| 2 | **Hear exactly how you played** | Pitch and timing on every note | *Kite Weather* on the highway mid-chorus at ×4, the words lighting up under the runway (`65-song-perform`) | `zoom sky` |
| 3 | **Play your first chord today** | Timbre hears every string | E minor's chord step with every string lit, the six ticked strings enlarged (`52b-lesson-chord`) | `callout lime` |
| 4 | **Tune whatever you play** | 60 instruments, 132 tunings | the instrument browser on the Folk & world strings, the wall of instruments around it (`31b-instruments-folk`) | `wall spotlight` |
| 5 | **Play songs you know** | 140+ songs, classics to Originals | the Songs tab, the songs people know on its first shelf (`63-songs`) | `light orchid` |
| 6 | **Learn at your own pace** | 526 lessons in 11 courses | Learn, with the next lesson up (`50-learn`) | `offset violet` |
| 7 | **Five minutes a day adds up** | Stars, streaks and daily quests | lesson results with three stars after a clean play-along (`62-lesson-results`) | `zoom gold` |
| 8 | **One strum checks every string** | See which string to tune first | Strum to tune: six strings read from one strum, A2 the one to tune first (`11b-tune-strum`) | `flip mint` |
| 9 | **See yourself get better** | Accuracy, string health, badges | the Progress screen (`32-journey`) | `offset-left flame` |

### iPad 13"

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Free tuner. No ads.** | 60 instruments, to the cent | the tuner in landscape, a string locked (`ipad-landscape-tune`) | `side mint` |
| 2 | **Tune whatever you play** | Violin to oud, sitar to erhu | the instrument browser, a full page of its own, on the bowed strings and the Folk & world strings (`ipad-landscape-instruments`) | `side-right spotlight` |
| 3 | **Play songs you know** | 140+ songs, classics to Originals | the Songs tab (`ipad-landscape-songs`) | `light orchid` |
| 4 | **Five minutes a day adds up** | A daily set, quests and ear games | the Practice tab (`ipad-landscape-practice`) | `side violet` |

### iPhone 6.9": violin page

The violin Custom Product Page's set ([below](#custom-product-pages)). Its first three frames are the violin's own (its lock, its song with finger numbers on the gems, its results); the rest are the main set's that show no other instrument.

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Tune your violin, free** | G, D, A and E, to the cent | the 3D violin, G, D and A locked, the lock's comet on the A string (`49d-tune-violin-locked`) | `breakout orchid` |
| 2 | **Play songs on your violin** | From Jingle Bells to Ode to Joy | *Jingle Bells* from the violin songbook on the runway, finger numbers on the gems, its last chorus lighting up (`65b-song-perform-violin`) | `zoom sky` |
| 3 | **Hear exactly how you played** | Pitch and timing on every note | the violin's "Open-string checkup" results with three stars (`62b-lesson-results-violin`) | `zoom gold` |
| 4 | **Play songs you know** | 140+ songs, classics to Originals | the Songs tab (`63-songs`) | `light orchid` |
| 5 | **Learn at your own pace** | 526 lessons in 11 courses | Learn (`50-learn`) | `offset violet` |

### iPhone 6.9": cello page

The cello Custom Product Page's set. Its first frame is the cello's own; the rest show no other instrument.

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Tune your cello, free** | C, G, D and A, to the cent | the 3D cello, C, G and D locked, the lock's comet on the D string (`49e-tune-cello-locked`) | `breakout orchid` |
| 2 | **Tune whatever you play** | 60 instruments, 132 tunings | the instrument browser on the Folk & world strings (`31b-instruments-folk`) | `wall spotlight` |
| 3 | **Play songs you know** | 140+ songs, classics to Originals | the Songs tab (`63-songs`) | `light orchid` |
| 4 | **See yourself get better** | Accuracy, string health, badges | the Progress screen (`32-journey`) | `offset-left flame` |

### iPhone 6.9": ukulele page

The ukulele Custom Product Page's set. Its first frame is the ukulele's own; the rest show no other instrument.

| # | Caption | Supporting line | Capture | Look |
|---|---|---|---|---|
| 1 | **Tune your ukulele, free** | G, C, E and A, to the cent | the soprano ukulele, G, C and E locked (`17b-tune-ukulele-locked`) | `breakout mint` |
| 2 | **Play songs you know** | 140+ songs, classics to Originals | the Songs tab (`63-songs`) | `light orchid` |
| 3 | **Tune whatever you play** | 60 instruments, 132 tunings | the instrument browser on the Folk & world strings (`31b-instruments-folk`) | `wall spotlight` |
| 4 | **See yourself get better** | Accuracy, string health, badges | the Progress screen (`32-journey`) | `offset-left flame` |

### App Preview (6.9")

Run the **App Preview** workflow by hand (Actions → App Preview → Run workflow; the `preview` input picks `both`, `guitar` or `violin`). It records the `AppPreviewUITests` tour on a Pro Max simulator with the status bar at 9:41, and publishes `preview.mp4` (886×1920, 30 fps, H.264 High, stereo AAC, 20–25 s), `poster.png`, `contact.png` and `PREVIEW.txt` to `ci-results/preview` (the violin cut to `ci-results/preview-violin`). `PREVIEW.txt` gives the poster frame's time; set it as the preview's poster frame in App Store Connect. Upload only a cut whose `PREVIEW.txt` ends "Meets the App Preview spec and its gates."

The cut, in order, with hard cuts on the band's beat: a string drifting into tune on the 3D headstock, heard as it comes in, and locking with its bell, held 1.2 s (the poster, 0.3 s after the lock: ✓ In tune, the peg's tick, the comet); the other strings locking, chosen as automatic detection chooses them, and the full-tune celebration; "Show me" fingering E minor on the 3D guitar; *Kite Weather*'s chorus on the highway at ×4 with the band, from the take store frame #2 comes from; the song's stars ringing as they land; the Songs tab with the song of the day's preview playing, under 3 s; the end card over the app's three-note motif. The soundtrack is the app's own sound at the moment each clip was filmed (the string, the lock bells, the full-tune strum, Show me's chord, the band in headphones, the stars, the song's preview), loudness-normalised; nothing is added. `tools/marketing/preview.py` draws the captions and the end card from the tables below (Clip, Caption, Accent); the `end` row is the end card's line and `end-note` the line under it.

**What the render checks before a cut can ship** (`PREVIEW.txt` lists each measurement; any failure prints NOT FOR UPLOAD and fails the run, which records the tour again when a new take can fix it):

- **Sound:** no silence longer than 0.5 s anywhere, end card included; every clip sounding; under "Play songs with the band", the band's low end (drums and bass) between the clicks, and the app's own note that the band was playing while that clip was filmed.
- **Sync:** the lock's bell and the In tune badge's first frame at most 80 ms apart. The lock's sync screenshot is taken the moment the app notes its lock, and the lock clip is placed by it alone.
- **Poster:** the poster frame shows the In tune badge (the readout measured in the recording); if the marked moment doesn't, the first frame after it that does, else no cut.
- **The highway at ×4:** the take's run is 16 or more at the clip's end.

`python3 tools/marketing/preview.py check --out <folder>` measures a rendered preview's sound again.

| Clip | Caption | Accent |
|---|---|---|
| `lock` | Free tuner. No ads. | mint |
| `tuned` | Every string, checked | mint |
| `showme` | See it played in 3D | mint |
| `highway` | Play songs with the band | sky |
| `results` | Hear how you did | gold |
| `songs` | 140+ songs to learn | spotlight |
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
| `songs` | 140+ songs to learn | spotlight |
| `end` | Violin tuner and lessons | orchid |
| `end-note` | Free tuner · No ads · No account | |

## Custom Product Pages

Timbre's moat for search is breadth: 60 instruments, and lessons that listen on violin, cello, ukulele, mandolin and banjo, where the big apps have nothing. A Custom Product Page can appear in organic search for the keywords assigned to it, so each instrument family gets a page of its own: its own first frames, promotional text and keywords. The App Store Connect steps are in [APPLE-DELIVERY.md §9.2](APPLE-DELIVERY.md#92-custom-product-pages).

Apple's rules, from [App Store Connect Help](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions), which this table follows:

- **Keywords come from the keyword field.** "You can assign keywords from your latest approved app version to a custom product page." A page can't add words of its own, so every page word is in the [field](#keywords-97100), and the field ships with the version before the pages are assigned. Searches for an assigned keyword are directed to the page "rather than your default product page".
- **Each page its own words.** "To ensure the most relevant custom product page appears, select a unique set of keywords for each page." No word is assigned to two pages.
- **Searchable only once approved and visible**, per localization: assign each localization's keywords from that localization's field ([by locale](APP-STORE-LISTING-LOCALIZED.md#custom-product-page-keywords-by-locale)).
- **The deep link works only on "Open".** It "directs" people on iOS 18 or later who tap **Open** on the page, and only after the link itself is approved. Someone who installs from the page and opens the app from the Home Screen gets the default welcome. So the link is a help, not the instrument choice: onboarding still asks.

| Page | Keywords from the field | First frames | Promotional text | Deep link (Open only) | Preview |
|---|---|---|---|---|---|
| Violin | violin, fiddle | the violin page's set | Tune your violin free, then learn with lessons that listen: bowing, first fingers and songs from Jingle Bells to Ode to Joy. No ads. | `timbre://tune?instrument=violin.standard.4` | violin |
| Cello | cello | the cello page's set | Tune your cello free, then learn to play with lessons that hear every note. No ads, no account. | `timbre://tune?instrument=cello.standard.4` | main |
| Ukulele | ukulele, uke | the ukulele page's set | Tune your ukulele free, then play songs from a whole ukulele songbook, with lessons that listen. | `timbre://tune?instrument=ukulele.soprano.4` | main |
| Bass | bass | `19-tune-bass-3d`, then the main set (a store frame is owed) | Tune your bass free and learn grooves that lock with the band. | `timbre://tune?instrument=bass.electric.4` | main |
| Mandolin | mandolin | `49-tune-mandolin-3d`, then the main set (a store frame is owed) | Tune your mandolin free, then a mandolin course and songbook that listen as you play. | `timbre://tune?instrument=mandolin.standard.8` | main |
| Banjo | banjo | the main set (a banjo capture is owed) | Tune your 5-string banjo free, then rolls, chords and songs with lessons that listen. | `timbre://tune?instrument=banjo.five.5` | main |
| Chromatic and strobe | chromatic, strobe | `15-tune-chromatic`, then the main set | A precise chromatic and strobe tuner for anything you play or sing. Free, no ads. | `timbre://tune?instrument=guitar.acoustic.6` (then the chromatic chip) | main |
| Ear training | ear training | `23-ear-training`, then the main set | Train your ear: intervals, chord qualities and a 40-lesson ear course. | `timbre://ear` | main |
| Voice | — (link and Apple Ads only) | `24-voice-range`, then the main set | Find your range and sing in tune, with a voice course that listens. | `timbre://tune?instrument=guitar.acoustic.6` | main |
| Songs | — (link and Apple Ads only; "chord" and "metronome" stay with the default page) | `65-song-perform`, `63-songs`, then the main set | 140+ songs to play along to, and any chord chart you paste. | `timbre://songs` | main |

Start with violin, cello and ukulele: those queries have the weakest competition and the highest prices paid elsewhere (Trala charges $119.99 a year for violin alone), and their first frames are store frames already. A page whose first frame is still a plain capture (`19-tune-bass-3d`, `49-tune-mandolin-3d`, …) needs it promoted first: a `storeFrame` check in its UI test and a table here.

**When the deep link didn't run.** For installs from Apple Ads, the `attribution` event (Analytics.swift) arrives within seconds of the first launch with the ad group: map each instrument's ad group to its catalog id in the remote settings file and let onboarding preselect that instrument when no link has (this needs a small change in onboarding; until then onboarding asks).

## Accessibility Nutrition Labels

App Store Connect → the app → **Accessibility**, per device (iPhone and iPad). Declare a feature only when a person can do the app's common tasks (tune, take a lesson, play a song) with it; App Review can ask for corrections. None of the six competitors fills these in, so an honest label is a difference on the product page itself.

| Feature | Declare | When, and why |
|---|---|---|
| Dark Interface | Yes | The app is dark by design, every screen. |
| Differentiate Without Color Alone | Yes | Every status has words or a shape as well as a colour (with the setting on, the readout marks ▲ sharp, ▼ flat and ✓ in the lock band). |
| Sufficient Contrast | Yes | Text at 4.5:1, controls at 3:1, raised further under Increase Contrast. |
| Reduced Motion | Yes | Every animation has a still or a fade under Reduce Motion. |
| Larger Text | Once the accessibility-size captures pass | Dynamic Type throughout; declare after the AX5 capture of the tuner, a lesson and the play-along shows nothing clipped. |
| VoiceOver | **Not yet** | The tuner works with VoiceOver today. Declare it only when the lessons' notes step speaks the next note, the play-along's spoken cues land before their notes, and blind testers have finished Unit 1. |
| Voice Control | Not yet | After a pass that every control has a speakable name. |
| Captions, Audio Descriptions | Not applicable | The app has no video with speech. |

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

The prices live in App Store Connect; the app shows whatever Apple returns. The recommendation for $10k a month: yearly **$49.99** with the **14-day** trial, monthly **$9.99** with no introductory offer, lifetime **$149.99**, kept off the onboarding paywall, and Family Sharing on for the yearly plan and lifetime. Then test $49.99 against $59.99 with a second yearly product chosen by the remote settings file ([APPLE-DELIVERY.md §5](APPLE-DELIVERY.md#5-analytics-links-and-remote-settings)), once a build grants Pro for that product.

- **Keep the 14-day trial.** Yearly trials of 10–16 days convert at about 43 %, against 33 % for 5–9 days (RevenueCat, 2026). An earlier version of this file suggested 7 days; don't.
- **No monthly introductory offer** until a build's paywall discloses it on the Monthly card (its own "7 days free", button, terms line and reminder). Before that build, a monthly trial would show "$9.99" while the App Store starts a free week. Win-back offers and offer codes cover the exit offer meanwhile ([APPLE-DELIVERY.md §6.4](APPLE-DELIVERY.md#64-the-paywalls-one-time-exit-offer)).
- **Keep the trial timeline and the reminder two days before the trial ends.** They answer the billing complaints competitors get, and editors notice.
- **Turn on the Billing Grace Period only with a build that keeps Pro during it** (the entitlement check that trusts `Transaction.currentEntitlements`; check it on a TestFlight build first).
