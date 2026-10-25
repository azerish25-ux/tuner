# App Store listing (English, U.S.)

Paste into App Store Connect → the app → the version's page and App Information. The lengths have been checked against Apple's limits. The numbers come from the build: 60 instruments, 102 tunings, 14 courses, 557 lessons and 49 languages (lessons in 10 of them).

## App Information

| Field | Value | Limit |
|---|---|---|
| Name | Timbre: Guitar Tuner & Lessons | 30/30 |
| Subtitle | Learn Violin, Ukulele & Bass | 28/30 |
| Primary category | Music | |
| Secondary category | Education | |
| Age rating | 13+ as the song catalogue stands, 4+ without two songs: see [Age rating](#age-rating) (owner decision) | |
| Privacy Policy URL | `<privacy policy URL>` (**owner TODO**: the hosted policy, on a custom domain) | required |

## Age rating

App Store Connect → the app → App Information → Age Ratings. Apple replaced the questionnaire in 2025. The ratings are now 4+, 9+, 13+, 16+ and 18+ (12+ and 17+ are gone), and new questions cover in-app controls, capabilities (user-generated content, messaging, advertising, web access, social media), medical and wellness topics, and violent themes. App Store Connect has required the new answers for every submission since January 31, 2026. Apple computes the rating from the answers. Timbre's answers, checked against this build:

| Section | Question | Answer | Why |
|---|---|---|---|
| In-app controls | Parental Controls | No | |
| | Age Assurance | No | |
| Capabilities | Unrestricted Web Access | No | Terms and Privacy open in Safari. The app has no browser or web view. |
| | User-Generated Content | No | Apple means content broadly distributed to other users. Charts and audio files a player imports into Your songs (from Files, the clipboard, the share sheet or the chart editor) stay on that device, and nobody else sees them. |
| | Social Media | No | |
| | Messaging and Chat | No | A Pitch Sniper challenge leaves as a link through the system share sheet. |
| | Advertising | No | No ads. The paywall sells Timbre's own subscription. |
| Mature themes | Profanity or Crude Humor | None | |
| | Horror/Fear Themes | None | |
| | Alcohol, Tobacco, or Drug Use or References | **Infrequent** | Two traditional songs: "Drunken Sailor" (title and chorus) and "Good King Wenceslas" ("bring me wine"). |
| Medical or wellness | Medical or Treatment Information | No | |
| | Health or Wellness Topics | No | The voice course's breathing is singing technique, not self-care advice. |
| Sexuality or nudity | All three | None | The Originals' lyrics were checked. |
| Violence | All four, guns and weapons included | None | Pitch Sniper's "scope" is a pitch reticle; no weapon is shown. |
| Chance-based activities | Gambling, Simulated Gambling, Loot Boxes | None | Rewards are earned, never bought or drawn at random. |
| | Contests | Infrequent | Pitch Sniper's Game Center leaderboard and friend challenges. |

**Result: 13+** (confirm it on the summary App Store Connect shows after the last answer). The alcohol answer sets it: Apple's 4+ and 9+ definitions allow no alcohol references. Everything else here sits at 4+, infrequent contests included. **Owner decision:** remove those two songs from the bundled catalogue (`curriculum.json`) and answer None, and the app is 4+. At 13+ it is hidden from any child whose Screen Time limits apps to 9+, and many beginners on ukulele and guitar are children. Answer the questionnaire again whenever songs are added.

## Keywords (100/100)

```
chromatic,cello,mandolin,banjo,metronome,chord,ear training,strobe,fiddle,pitch,uke,sing,song,tuning
```

Apple already indexes words from the name and subtitle (guitar, tuner, lessons, learn, violin, ukulele, bass), so the keywords don't repeat them. The name carries "guitar tuner", the category's highest-volume search. Use singular forms; Apple matches plurals. Leave out category names too ("music"): the app is already found under its category.

The 12 characters that "music" and "songs" used now hold "song" (singular, so it still matches "guitar songs" and "ukulele songs") and "tuning". "Tuning" catches the searches that name a tuning ("drop D tuning", "open G tuning", "cello tuning"), which "tuner" in the name does not match, and Timbre ships 102 tunings plus custom ones.

## Promotional text (170 max; can change without a review)

```
Tune up, then learn to play: 557 lessons that listen as you play guitar, ukulele, bass, violin, cello, mandolin, banjo or sing. New songs arrive with every update.
```

## Description

> **Owner TODO before pasting:** replace `<privacy policy URL>` on the last line with the hosted privacy policy, the same URL as App Information → Privacy Policy URL. Everything else is ready to paste.

```
Timbre is a precise tuner and a music teacher in one app. Tune any of 60 instruments in seconds, then play real lessons that listen to you and tell you exactly how you did.

TUNE ANYTHING, FAST
• A chromatic and strobe tuner with cent-level precision
• 60 instruments and 102 tunings, from guitar and violin to oud, sitar and erhu
• Auto string detection, with a check-off as each string locks in
• Strum to tune: one strum reads every string at once and shows which one to tune first
• Studio-lit 3D guitars, basses, violin, cello and mandolin
• Custom tunings, capo, adjustable A4 reference, solfège and sargam note names

LEARN BY PLAYING
• 557 lessons in 14 courses: guitar, ukulele, bass, violin, cello, mandolin, banjo, voice, ear training, music theory, rhythm, songs, Originals and Standards & Classics
• Timbre listens as you play: single notes, whole chords and strumming rhythm, with pitch feedback and timing feedback in milliseconds
• A play-along note highway that slows down for you, then speeds back up as you improve
• A Songs tab: 50 original songs in today’s styles plus public-domain classics and standards, from The Entertainer to Amazing Grace — every song a full arrangement, most with lyrics
• Stars, XP, daily quests, streaks and badges keep you coming back

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone for intonation work, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course
• Home Screen and Lock Screen widgets, plus Siri shortcuts

FREE TO START
The tuner for guitar, bass, ukulele, violin and cello is free, with a chromatic tuner for anything else, and so is the first unit of every course. Timbre Pro unlocks every lesson, every instrument and the full practice set. With notifications on, Timbre reminds you two days before a free trial ends.

Private by design: audio is analysed on your iPhone and never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: <privacy policy URL>
```

## What's New (first release)

```
Welcome to Timbre: a precise tuner for 60 instruments and 557 lessons that listen as you play.
```

## Screenshots (6.9" iPhone and 13" iPad)

The two tables below are the only place the screenshot captions live: `tools/marketing/screenshots.py` reads them and renders each capture under its caption. To change a caption, edit it here and render again:

```
python3 tools/marketing/screenshots.py <ci-out/screenshots> <out folder>          # iPhone, 1320x2868
python3 tools/marketing/screenshots.py <ci-out/ipad-screenshots> <out folder> --ipad   # iPad, 2064x2752 portrait / 2752x2064 landscape (follows each capture)
python3 tools/marketing/screenshots.py --check                                    # the tables only
```

The script stops if a caption runs past 30 characters, if a row names a capture the UI tests never take, or if a count no longer matches the build (lessons and courses from `curriculum.json`, instruments and tunings from `catalog.json`). Each caption names what the player gets, not the feature; the supporting line under it backs it up.

Every capture shows the same player: the UI tests' seeded history (`DemoData` in `ios/Timbre/TimbreApp.swift`) is a 7-day streak that already counts today (the flame lit), level 5 and today's tune-up done, whatever the hour the run starts. Each capture waits for its screen to settle before the picture (`stillScreenshot` in `ios/TimbreUITests/StillScreen.swift`), after the cue that its slowest animation has finished: the fingertips landing, the XP counter, a stagger.

### iPhone 6.9"

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | **In tune in seconds** | 60 instruments, to the cent | a string locked on the 3D headstock, its peg ringed and ticked (`10b-tune-locked`) |
| 2 | **Hear exactly how you played** | Pitch and timing on every note | the play-along highway mid-take (`60-along-playing`) |
| 3 | **Play your first chord today** | Timbre hears every string | the chord step with every string lit (`52b-lesson-chord`) |
| 4 | **Play songs, start to finish** | Originals and timeless classics | the Songs tab (`63-songs`) |
| 5 | **Learn at your own pace** | 557 lessons in 14 courses | Learn, with the next lesson up (`50-learn`) |
| 6 | **Five minutes a day adds up** | Stars, streaks and daily quests | lesson results with their stars (`62-lesson-results`) |
| 7 | **One strum checks every string** | See which string to tune first | Strum to tune with all six strings read from one strum, A2 the one to tune first (`11b-tune-strum`) |
| 8 | **See yourself get better** | Accuracy, string health, badges | the Progress screen (`32-journey`) |

### iPad 13"

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | **In tune in seconds** | 60 instruments, to the cent | the tuner in landscape (`ipad-landscape-tune`) |
| 2 | **Tune whatever you play** | Guitar to violin, oud to erhu | the instrument browser (`ipad-landscape-instruments`) |
| 3 | **Play songs, start to finish** | Originals and timeless classics | the Songs tab (`ipad-landscape-songs`) |
| 4 | **Five minutes a day adds up** | A daily set, quests and ear games | the Play tab (`ipad-landscape-practice`) |

### App Preview (6.9")

Run the **App Preview** workflow by hand (Actions → App Preview → Run workflow). It records the `AppPreviewUITests` tour on a Pro Max simulator with the status bar at 9:41, and publishes `preview.mp4` (886×1920, 30 fps, H.264, a silent audio track, 15–30 s) and `poster.png` to the `ci-results/preview` branch. The tour: a string locking on the 3D stage, the all-strings celebration, a chord lesson hearing the chord, the play-along highway, the lesson's stars, the Songs tab. `PREVIEW.txt` on that branch gives the poster frame's time; set it as the preview's poster frame in App Store Connect.

## In-app purchase display names

| Product | Display name | Description (55 max) |
|---|---|---|
| `timbre_pro_annual` | Timbre Pro, yearly | Every lesson, instrument and practice tool |
| `timbre_pro_monthly` | Timbre Pro, monthly | Every lesson, instrument and practice tool |
| `timbre_plus_lifetime` | Timbre Pro, lifetime | Everything in Pro, paid once |

## Review notes

```
Timbre needs the microphone to tune and to hear lessons. With no instrument to hand, a 440 Hz tone from another device works for the tuner.
Guitar, bass, ukulele, violin and cello tune free in every preset tuning; the other instruments are part of Timbre Pro.
The paywall opens from any locked lesson (Learn tab → a lesson in unit 2 or later), from the Play tab → Tools → Drone, and from a Pro instrument (Tune tab → tap the instrument name → Mandolin). It shows the price, the trial timeline, auto-renewal terms, Restore, Terms and Privacy.
No account or login is needed.
```

## Pricing: the owner decides

The current suggestion in APPLE-DELIVERY.md is $34.99 a year, $6.99 a month and $89.99 lifetime. With 557 lessons, Timbre now sits between tuner apps and lesson apps. In the competitive brief, yearly plans had a median of $44.99. The lesson apps charge well above that, and the most common complaint across all of them was billing surprises. Two options:

- **Conservative:** keep $34.99 / $6.99 / $89.99 with a 2-week trial. This maximises conversion while there are no reviews yet.
- **Recommended once ratings are ≥ 4.6:** $44.99 / $7.99 / $99.99 with a 7-day trial.

Both keep the trial timeline and the reminder two days before it ends. Those are what set Timbre apart from the billing complaints that competitors get.
