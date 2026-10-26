# Kannada (kn) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | kn — Kannada |  |
| Variant | Standard Kannada, Karnataka |  |
| Register ("you") | Polite ನೀವು; warm and direct |  |
| Imperatives and buttons | Polite ಮಾಡಿ, ನುಡಿಸಿ; short noun labels |  |
| Readers of unknown gender | Neutral constructions; no assumptions about gender |  |
| Quotation marks | “…”; full stop . |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Normal word spaces; preserve needed ZWJ/ZWNJ |  |
| Digits in literal numbers | ASCII 0–9 in literals; runtime numbers follow device |  |
| Units | ಸೆಂಟ್ಸ್; ನಿಮಿಷ; ಸೆಕೆಂಡ್; ಮಿಲಿಸೆಕೆಂಡ್. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Notes supplied by runtime; do not invent them |  |
| Note names in lessons (lesson languages only) | Not a lesson locale; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | ಶಾರ್ಪ್ / ಫ್ಲಾಟ್ / ಡಬಲ್ ಶಾರ್ಪ್ / ಡಬಲ್ ಫ್ಲಾಟ್ |  |
| Tuning direction | ಕಡಿಮೆ / ಹೆಚ್ಚು for tuner direction; existing flat/sharp loan labels may remain as refs |  |
| iOS Settings path (legal text) | ಸೆಟ್ಟಿಂಗ್‌ಗಳು › Apple ಖಾತೆ › ಚಂದಾದಾರಿಕೆಗಳು. AI-reviewed; device verification pending |  |
| Apple feature names | ಹೋಮ್ ಸ್ಕ್ರೀನ್ / ಲಾಕ್ ಸ್ಕ್ರೀನ್ / ವಿಜೆಟ್ / ಲೈವ್ ಆ್ಯಕ್ಟಿವಿಟಿ / ಶಾರ್ಟ್‌ಕಟ್ / ಕಂಟ್ರೋಲ್ ಸೆಂಟರ್ / ಫ್ಯಾಮಿಲಿ ಶೇರಿಂಗ್; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Polite imperative; preserve ${applicationName} and all tokens |  |

## 2. Terms

### A. Names that stay as they are

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translated, transliterated or inflected. Where grammar wants a case ending, rebuild the sentence ("in Timbre", "the Timbre app"). |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro |  |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | The precision level is "Expert", precisely so that "Pro" always means the plan. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | (unchanged) | Apple's spelling; "Apple Music" never in capitals. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Its syntax in examples stays verbatim: `[G]`, `{start_of_chorus}`, `{end_of_chorus}`. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | XP / Hz / A4 | The pseudo-localization test lets only "Timbre", "BPM" and words under three letters bypass the tables on the welcome screen and the tuner. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: ಗಿಟಾರ್, ಬಾಸ್, ಯುಕುಲೇಲೆ, ವಯಲಿನ್, ಚೆಲ್ಲೊ, ಸಿತಾರ್, ತಂಬೂರಿ | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | ಸ್ಟ್ಯಾಂಡರ್ಡ್ | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ಟ್ಯೂನ್ | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | ಕಲಿಯಿರಿ | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | ಹಾಡುಗಳು | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | ಅಭ್ಯಾಸ | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | ಪ್ರಗತಿ | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | ಸೆಟ್ಟಿಂಗ್‌ಗಳು | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | ಇಂದು | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | ಗುರಿ | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | ನಿಮ್ಮ ಹಾಡುಗಳು |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | ಹಾಡಿನ ಹಾಳೆ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | ಸ್ವರಮೇಳದ ಚಾರ್ಟ್ / ವಾದಕರ ನೋಟ | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | ಸ್ವರಮೇಳದ ನೋಟ / ನೆಕ್ ನೋಟ |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | ತೋರಿಸಿ | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ಟ್ಯೂನ್ ಮಾಡಲು ಸ್ಟ್ರಮ್ ಮಾಡಿ |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | ಕಂಪನದಿಂದ ಟ್ಯೂನ್ ಮಾಡಿ / ಕಂಪನ ಅನುಭವಿಸಿ | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | ನಿಖರ ಗುರಿ | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | ಕಿವಿ ತರಬೇತಿ |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | ಡ್ರೋನ್ | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | ತಂಬೂರಿ |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ಇಂಟೋನೇಶನ್ — ಡ್ರೋನ್ ಜೊತೆ ಶ್ರುತಿಯಲ್ಲಿ ನುಡಿಸುವುದು; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | ಮೆಟ್ರೋನೋಮ್ / ವೇಗ ತರಬೇತುದಾರ |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | ಸ್ವರಮೇಳಗಳು / ಸ್ಕೇಲ್‌ಗಳು |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | ಮಟ್ಟದ ಪರಿಶೀಲನೆ |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | ಜೊತೆಗೆ ನುಡಿಸಿ | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | ಅಂತಿಮ ಟೇಕ್; ಟೇಕ್ = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | ಲೂಪ್ A–B / A ಹೊಂದಿಸಿ / B ಹೊಂದಿಸಿ | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | ಆರಂಭಿಕ / ಸ್ಟ್ಯಾಂಡರ್ಡ್ / ಪರಿಣತ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | ಸ್ಟುಡಿಯೋ (ಹಗುರ) / ರಿಯಲ್-ಟೈಮ್ 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | ಹ್ಯಾಪ್ಟಿಕ್ಸ್ | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ಟ್ಯೂನರ್ |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ಟ್ಯೂನ್-ಅಪ್ |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ಟ್ಯೂನಿಂಗ್ | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ಟ್ಯೂನ್‌ನಲ್ಲಿದೆ | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | ಫ್ಲಾಟ್ / ಶಾರ್ಪ್ | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | ಸೆಂಟ್ಸ್ | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | ಶ್ರುತಿ ಹೊಂದಿದ ದೃಢೀಕರಣ; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | ತಂತಿ |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ಪೆಗ್ / ಹೆಡ್‌ಸ್ಟಾಕ್ |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | ಆಧಾರ ಸ್ವರ / ಆಧಾರ ಶ್ರುತಿ / ಕನ್ಸರ್ಟ್ ಪಿಚ್ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | ಲಿಖಿತ ಸ್ವರ / ಟೆಂಪರಮೆಂಟ್ |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | ಕ್ರೊಮ್ಯಾಟಿಕ್ / ಸ್ಟ್ರೋಬ್ |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | ಕ್ಯಾಪೋ |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | ಶ್ರುತಿ ಬದಲಿಸಿ / ಶ್ರುತಿ ಬದಲಾವಣೆ |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | ಸ್ವರದ ಹೆಸರುಗಳು / ಸೊಲ್ಫೆಜ್ / ಸರಗಮ್ |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ಫ್ರೆಟ್ / ತೆರೆದ ತಂತಿ | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | ಬೆರಳು 1–4; 1 ತೋರುಬೆರಳು, 2 ಮಧ್ಯದ ಬೆರಳು, 3 ಉಂಗುರದ ಬೆರಳು, 4 ಕಿರುಬೆರಳು; 0 ತೆರೆದ | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | ಸ್ವರಮೇಳ / ಸ್ವರಮೇಳದ ಆಕಾರ / ಬಾರೆ ಸ್ವರಮೇಳ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | ಮೇಜರ್ / ಮೈನರ್ / ಸೆವೆಂತ್ / ಪವರ್ ಸ್ವರಮೇಳ | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | ಕೀ (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | ಸ್ಕೇಲ್ / ಮೇಜರ್ ಸ್ಕೇಲ್ / ಪೆಂಟಾಟಾನಿಕ್ ಮಾದರಿ | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | ಅರ್ಧ ಸ್ವರ / ಪೂರ್ಣ ಸ್ವರ / ಸ್ವರಾಂತರ / ತೃತೀಯ / ಪಂಚಮ / ಆಕ್ಟೇವ್ |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | ಬಾರ್ |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ಬೀಟ್ / ಟೆಂಪೋ / ಮೊದಲ ಬೀಟ್ / ಎಣಿಕೆ |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | ಸ್ಟ್ರಮ್ / ಕೆಳಗಿನ ಸ್ಟ್ರೋಕ್ / ಮೇಲಿನ ಸ್ಟ್ರೋಕ್ / ಮ್ಯೂಟ್ ಸ್ಟ್ರೋಕ್ / ಮ್ಯೂಟ್ ಸ್ಟ್ರೋಕ್ / ಮ್ಯೂಟ್ | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | ಪಿಕ್ (plectrum); ಆಯ್ಕೆಮಾಡಿ (choose); ತಂತಿ ನುಡಿಸಿ (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ಫಿಂಗರ್‌ಪಿಕಿಂಗ್ / ಹ್ಯಾಮರ್-ಆನ್ / ಪುಲ್-ಆಫ್ / ಸ್ಲೈಡ್ / ಬೆಂಡ್ / ವೈಬ್ರಾಟೋ | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | ಬೋ ಬಳಸಿ ನುಡಿಸುವುದು / ತೆರೆದ ತಂತಿಯಲ್ಲಿ ಬೋ ನುಡಿಸುವುದು |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | ಧಾಟಿ | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | ಕ್ಯಾಡೆನ್ಸ್ / V ಸ್ವರಮೇಳ / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | ಮೊದಲ ಪೂರ್ಣ ಬಾರ್‌ಗಿಂತ ಮುಂಚಿನ ಸ್ವರಗಳು |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | ಆರಂಭ / ಚರಣ 1 / ಪಲ್ಲವಿ / ಬ್ರಿಡ್ಜ್ / ಸೋಲೋ / ಅಂತ್ಯ / ಟ್ಯಾಗ್ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | ಭಾಗ |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | ಸರಣಿ | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | ಸರಣಿ ರಕ್ಷಣೆ |  |
| best run | The longest streak so far | Progress | `best run` | ಅತ್ಯುತ್ತಮ ಸರಣಿ | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | ಬ್ಯಾಡ್ಜ್ / ಸಾಧನೆ |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | ಮಟ್ಟ / ನಕ್ಷತ್ರಗಳು / XP / ಕಾಂಬೋ / ಸ್ಕೋರ್ / ಸುತ್ತು |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | ಸ್ನೇಹಿತರಿಗೆ ಸವಾಲು ಹಾಕಿ |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | ಸವಾಲು | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | ಕೋರ್ಸ್ / ಘಟಕ / ಪಾಠ / ಹಂತ |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | ರಸಪ್ರಶ್ನೆ / ಸುಳಿವು |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | ಚಂದಾದಾರಿಕೆ / ನವೀಕರಣ / ರದ್ದುಮಾಡಿ | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | ಉಚಿತ ಪ್ರಯೋಗ / ಪ್ರಯೋಗ ಮುಗಿಯುತ್ತದೆ |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | ವಾರ್ಷಿಕ / ಮಾಸಿಕ / ಜೀವಮಾನ |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | ಖರೀದಿಗಳನ್ನು ಮರುಸ್ಥಾಪಿಸಿ |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | ಪಾವತಿ ವಿಧಾನ / ಬಿಲ್ಲಿಂಗ್ ಸಮಸ್ಯೆ |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | ನಿಯಮಗಳು / ಗೌಪ್ಯತಾ ನೀತಿ | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | ಗಿಟಾರ್ / ಯುಕುಲೇಲೆ / ಬಾಸ್ / ವಯಲಿನ್ / ಚೆಲ್ಲೊ / ಮ್ಯಾಂಡೊಲಿನ್ / ಬ್ಯಾಂಜೊ | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | ಕಿವಿ ತರಬೇತಿ / ಸಂಗೀತ ಸಿದ್ಧಾಂತ / ಲಯ / ಗಾಯನ |  |
| Songs | Course title, also the Songs tab | ಹಾಡುಗಳು |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | ಮೂಲ ಹಾಡುಗಳು | Keep or translate: decide once. |
| Standards & Classics | Course title | ಜನಪ್ರಿಯ ಮತ್ತು ಶಾಸ್ತ್ರೀಯ ಹಾಡುಗಳು |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | ಯುಕುಲೇಲೆ / ಮ್ಯಾಂಡೊಲಿನ್ / ವಯಲಿನ್ / ಚೆಲ್ಲೊ / ಬಾಸ್ ಹಾಡುಗಳ ಪುಸ್ತಕ | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

Song titles, the rule for this locale (fill one line each):

- Public-domain songs with an established title in the language (Ode to Joy, Silent Night, Twinkle Twinkle Little Star …): use the established local title; otherwise keep English. (Current tables use local titles where they exist: ru «Зелёные рукава», zh-CN 《绿袖子》.)
- Other traditional songs (Clementine, Shenandoah, Molly Malone …): keep the English title (ja グリーンスリーブス, ko 그린슬리브스).
- Timbre Originals (Kite Weather, Ghost Light, Neon Laundromat …): keep the original English title. (Current lesson tables translate them: de Drachenwetter, ja 「凧日和」.)
- A title in prose must equal the title of its song lesson in this locale (the helper adds it to lesson batches as `lesson_title`), and Game Center's leaderboard for a featured song uses the same title.
- Lyric credits ("Traditional (printed 1876; James Yorkston, 1884)", "Words from 1779, tune from 1829"): names and years as they are; the connecting words translated.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | ಟ್ಯೂನ್ (verb/tab); ಧಾಟಿ (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | ಶಾರ್ಪ್ / ಫ್ಲಾಟ್ (accidentals); ಹೆಚ್ಚು / ಕಡಿಮೆ (tuner direction, clearer than ambiguous loans) | pointed / level |
| bar | a measure | a UI bar, a pub | ಬಾರ್ | a UI bar, a pub |
| key | tonality | a piano key, a password key | ಕೀ (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | ಪಿಕ್ (plectrum); ಆಯ್ಕೆಮಾಡಿ (choose); ತಂತಿ ನುಡಿಸಿ (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | ಶ್ರುತಿ ಹೊಂದಿದ ದೃಢೀಕರಣ | a padlock |
| take | one recorded attempt | "take a lesson" | ಟೇಕ್ (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | ಸರಣಿ (streak); ಪೂರ್ಣ ಪ್ರಯತ್ನ (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | ಸ್ವರಮೇಳದ ಚಾರ್ಟ್ (music); ಚಾರ್ಟ್ (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ಇಂಟೋನೇಶನ್ — ಡ್ರೋನ್ ಜೊತೆ ಶ್ರುತಿಯಲ್ಲಿ ನುಡಿಸುವುದು; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | ಮುಂದೆ / ಮತ್ತೆ / ನಿಧಾನವಾಗಿ | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | ಅಭ್ಯಾಸ | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | ಕಂಪನ ಅನುಭವಿಸಿ (haptics; not emotion) | emotions |
