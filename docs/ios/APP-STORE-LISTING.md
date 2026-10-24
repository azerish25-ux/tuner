# App Store listing (English, U.S.)

Paste into App Store Connect → the app → the version's page and App Information. The lengths have been checked against Apple's limits. The numbers come from the build: 60 instruments, 102 tunings, 13 courses, 499 lessons and 49 languages (lessons in 10 of them).

## App Information

| Field | Value | Limit |
|---|---|---|
| Name | Timbre: Guitar Tuner & Lessons | 30/30 |
| Subtitle | Learn Violin, Ukulele & Bass | 28/30 |
| Primary category | Music | |
| Secondary category | Education | |
| Age rating | 4+ (no user content, no web access) | |

## Keywords (100/100)

```
chromatic,cello,mandolin,banjo,metronome,chord,ear training,strobe,fiddle,music,songs,pitch,uke,sing
```

Apple already indexes words from the name and subtitle (guitar, tuner, lessons, learn, violin, ukulele, bass), so the keywords don't repeat them. The name carries "guitar tuner", the category's highest-volume search. Use singular forms; Apple matches plurals.

## Promotional text (170 max; can change without a review)

```
Tune up, then learn to play: 499 lessons that listen as you play guitar, ukulele, bass, violin, cello, mandolin, banjo or sing. New songs arrive with every update.
```

## Description

```
Timbre is a precise tuner and a music teacher in one app. Tune any of 60 instruments in seconds, then play real lessons that listen to you and tell you exactly how you did.

TUNE ANYTHING, FAST
• A chromatic and strobe tuner with cent-level precision
• 60 instruments and 102 tunings, from guitar and violin to oud, sitar and erhu
• Auto string detection, with a check-off as each string locks in
• Studio-lit 3D guitars, basses, violin, cello and mandolin
• Custom tunings, capo, adjustable A4 reference, solfège and sargam note names

LEARN BY PLAYING
• 499 lessons in 13 courses: guitar, ukulele, bass, violin, cello, mandolin, banjo, voice, ear training, music theory, rhythm, songs and Originals
• Timbre listens as you play: single notes, whole chords and strumming rhythm, with pitch feedback and timing feedback in milliseconds
• A play-along note highway that slows down for you, then speeds back up as you improve
• A Songs tab: 20 original songs in today's styles plus public-domain classics from Ode to Joy to Amazing Grace
• Stars, XP, daily quests, streaks and badges keep you coming back

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone for intonation work, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course
• Home Screen and Lock Screen widgets, plus Siri shortcuts

FREE TO START
The tuner for guitar, bass and ukulele is free, with a chromatic tuner for anything else, and so is the first unit of every course. Timbre Pro unlocks every lesson, every instrument and the full practice set. The trial timeline is on the paywall, and, with notifications on, Timbre reminds you two days before the trial ends.

Private by design: audio is analysed on your iPhone and never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: <privacy policy URL>
```

## What's New (first release)

```
Welcome to Timbre: a precise tuner for 60 instruments and 499 lessons that listen as you play.
```

## Screenshots (6.9" iPhone and 13" iPad)

The two tables below are the only place the screenshot captions live: `tools/marketing/screenshots.py` reads them and renders each capture under its caption. To change a caption, edit it here and render again:

```
python3 tools/marketing/screenshots.py <ci-out/screenshots> <out folder>          # iPhone, 1320x2868
python3 tools/marketing/screenshots.py <ci-out/ipad-screenshots> <out folder> --ipad   # iPad, 2064x2752
python3 tools/marketing/screenshots.py --check                                    # the tables only
```

The script stops if a caption runs past 30 characters, if a row names a capture the UI tests never take, or if a count no longer matches the build (lessons and courses from `curriculum.json`, instruments and tunings from `catalog.json`). Each caption names what the player gets, not the feature; the supporting line under it backs it up.

### iPhone 6.9"

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | **In tune in seconds** | 60 instruments, to the cent | a string locked on the 3D headstock, its peg ringed and ticked (`10b-tune-locked`) |
| 2 | **Hear exactly how you played** | Pitch and timing on every note | the play-along highway mid-take (`60-along-playing`) |
| 3 | **Play your first chord today** | Timbre hears every string | the chord step with every string lit (`52b-lesson-chord`) |
| 4 | **Play songs, start to finish** | Originals and timeless classics | the Songs tab (`63-songs`) |
| 5 | **Learn at your own pace** | 499 lessons in 13 courses | Learn, with the next lesson up (`50-learn`) |
| 6 | **Five minutes a day adds up** | Stars, streaks and daily quests | lesson results with their stars (`62-lesson-results`) |
| 7 | **Tune whatever you play** | Guitar to violin, oud to erhu | the instrument browser's Guitar shelf (`31-instruments-scrolled`) |
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
The paywall opens from any locked lesson (Learn tab → a lesson in unit 2 or later) and from Practice → Drone. It shows the price, the trial timeline, auto-renewal terms, Restore, Terms and Privacy.
No account or login is needed.
```

## Pricing: the owner decides

The current suggestion in APPLE-DELIVERY.md is $34.99 a year, $6.99 a month and $89.99 lifetime. With 499 lessons, Timbre now sits between tuner apps and lesson apps. In the competitive brief, yearly plans had a median of $44.99. The lesson apps charge well above that, and the most common complaint across all of them was billing surprises. Two options:

- **Conservative:** keep $34.99 / $6.99 / $89.99 with a 2-week trial. This maximises conversion while there are no reviews yet.
- **Recommended once ratings are ≥ 4.6:** $44.99 / $7.99 / $99.99 with a 7-day trial.

Both keep the trial timeline and the reminder two days before it ends. Those are what set Timbre apart from the billing complaints that competitors get.
