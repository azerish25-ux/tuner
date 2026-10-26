# Punjabi (pa) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | pa — Punjabi |  |
| Variant | Eastern Punjabi, Gurmukhi script |  |
| Register ("you") | Polite ਤੁਸੀਂ; warm direct voice |  |
| Imperatives and buttons | Polite ਕਰੋ, ਵਜਾਓ; concise noun labels |  |
| Readers of unknown gender | Neutral imperatives; avoid gendered reader predicates |  |
| Quotation marks | “…”; sentence-final । |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Ordinary word spaces; retain necessary script joiners |  |
| Digits in literal numbers | ASCII 0–9 in literals; runtime numbers follow device |  |
| Units | ਸੈਂਟ; ਮਿੰਟ; ਸਕਿੰਟ; ਮਿਲੀਸਕਿੰਟ. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies note names; do not invent them |  |
| Note names in lessons (lesson languages only) | Lessons are required; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | ਸ਼ਾਰਪ / ਫਲੈਟ / ਡਬਲ ਸ਼ਾਰਪ / ਡਬਲ ਫਲੈਟ |  |
| Tuning direction | ਨੀਵਾਂ / ਉੱਚਾ for tuner direction; not accidentals |  |
| iOS Settings path (legal text) | ਸੈਟਿੰਗਾਂ › Apple ਖਾਤਾ › ਸਬਸਕ੍ਰਿਪਸ਼ਨਾਂ. AI-reviewed; device verification pending |  |
| Apple feature names | ਹੋਮ ਸਕ੍ਰੀਨ / ਲੌਕ ਸਕ੍ਰੀਨ / ਵਿਜੈੱਟ / ਲਾਈਵ ਐਕਟੀਵਿਟੀ / ਸ਼ਾਰਟਕੱਟ / ਕੰਟਰੋਲ ਸੈਂਟਰ / ਫੈਮਿਲੀ ਸ਼ੇਅਰਿੰਗ; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Polite imperative; preserve ${applicationName} and every token |  |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: ਗਿਟਾਰ, ਬਾਸ, ਯੂਕੁਲੇਲੇ, ਵਾਇਲਿਨ, ਚੈਲੋ, ਸਿਤਾਰ, ਤਾਨਪੁਰਾ | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | ਸਟੈਂਡਰਡ | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ਟਿਊਨ ਕਰੋ | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | ਸਿੱਖੋ | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | ਗੀਤ | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | ਅਭਿਆਸ | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | ਤਰੱਕੀ | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | ਸੈਟਿੰਗਾਂ | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | ਅੱਜ | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | ਟੀਚਾ | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | ਤੁਹਾਡੇ ਗੀਤ |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | ਗੀਤ ਦੀ ਸ਼ੀਟ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | ਕੋਰਡ ਚਾਰਟ / ਵਾਦਕ ਦ੍ਰਿਸ਼ | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | ਕੋਰਡ ਦ੍ਰਿਸ਼ / ਨੈੱਕ ਦ੍ਰਿਸ਼ |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | ਦਿਖਾਓ | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ਟਿਊਨ ਕਰਨ ਲਈ ਸਟ੍ਰਮ ਕਰੋ |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | ਕੰਪਨ ਨਾਲ ਟਿਊਨ ਕਰੋ / ਕੰਪਨ | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | ਸਟੀਕ ਨਿਸ਼ਾਨਾ | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | ਕੰਨ ਦੀ ਸਿਖਲਾਈ |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | ਆਧਾਰ ਸੁਰ | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | ਤਾਨਪੁਰਾ |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ਇੰਟੋਨੇਸ਼ਨ — ਆਧਾਰ ਸੁਰ ਨਾਲ ਸੁਰ ਵਿੱਚ ਵਜਾਉਣਾ; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | ਮੈਟਰੋਨੋਮ / ਸਪੀਡ ਟ੍ਰੇਨਰ |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | ਕੋਰਡ / ਸਕੇਲ |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | ਪੱਧਰ ਦੀ ਜਾਂਚ |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | ਨਾਲ ਵਜਾਓ | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | ਅੰਤਿਮ ਟੇਕ; ਟੇਕ = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | ਲੂਪ A–B / A ਸੈੱਟ ਕਰੋ / B ਸੈੱਟ ਕਰੋ | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | ਸ਼ੁਰੂਆਤੀ / ਸਟੈਂਡਰਡ / ਮਾਹਰ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | ਸਟੂਡੀਓ (ਹਲਕਾ) / ਰੀਅਲ-ਟਾਈਮ 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | ਹੈਪਟਿਕਸ | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ਟਿਊਨਰ |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ਟਿਊਨ-ਅੱਪ |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ਟਿਊਨਿੰਗ | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ਸੁਰ ਵਿੱਚ | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | ਨੀਵਾਂ / ਉੱਚਾ | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | ਸੈਂਟ | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | ਸੁਰ ਮਿਲਣ ਦੀ ਪੁਸ਼ਟੀ; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | ਤਾਰ |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ਖੂੰਟੀ / ਹੈੱਡਸਟੌਕ |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | ਹਵਾਲਾ ਸੁਰ / ਹਵਾਲਾ ਪਿੱਚ / ਕੰਸਰਟ ਪਿੱਚ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | ਲਿਖਿਆ ਸੁਰ / ਟੈਂਪਰਾਮੈਂਟ |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | ਕ੍ਰੋਮੈਟਿਕ / ਸਟ੍ਰੋਬ |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | ਕੈਪੋ |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | ਸੁਰ ਬਦਲੋ / ਸੁਰ ਤਬਦੀਲੀ |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | ਨੋਟ ਦੇ ਨਾਮ / ਸੋਲਫੇਜ / ਸਰਗਮ |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ਫ੍ਰੈੱਟ / ਖੁੱਲ੍ਹੀ ਤਾਰ | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | ਉਂਗਲ 1–4; 1 ਤਰਜਨੀ, 2 ਵਿਚਕਾਰਲੀ, 3 ਅਨਾਮਿਕਾ, 4 ਚੀਚੀ; 0 ਖੁੱਲ੍ਹੀ | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | ਕੋਰਡ / ਕੋਰਡ ਦਾ ਆਕਾਰ / ਬਾਰੇ ਕੋਰਡ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | ਮੇਜਰ / ਮਾਈਨਰ / ਸੈਵੰਥ / ਪਾਵਰ ਕੋਰਡ | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | ਸੁਰ (tonality); prefer over ambiguous ਕੁੰਜੀ |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | ਸਕੇਲ / ਮੇਜਰ ਸਕੇਲ / ਪੈਂਟਾਟੋਨਿਕ ਪੈਟਰਨ | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | ਅੱਧਾ ਸੁਰ / ਪੂਰਾ ਸੁਰ / ਸੁਰ ਅੰਤਰ / ਤੀਜਾ / ਪੰਜਵਾਂ / ਸਪਤਕ |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | ਬਾਰ |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ਤਾਲ / ਟੈਂਪੋ / ਪਹਿਲਾ ਤਾਲ / ਗਿਣਤੀ |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | ਸਟ੍ਰਮ / ਹੇਠਲਾ ਸਟ੍ਰੋਕ / ਉੱਪਰਲਾ ਸਟ੍ਰੋਕ / ਚੌਪ / ਦਬਿਆ ਸਟ੍ਰੋਕ / ਮਿਊਟ | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | ਪਿਕ (plectrum); ਚੁਣੋ (choose); ਤਾਰ ਵਜਾਓ (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ਫਿੰਗਰਪਿਕਿੰਗ / ਹੈਮਰ-ਆਨ / ਪੁੱਲ-ਆਫ਼ / ਸਲਾਈਡ / ਬੈਂਡ / ਵਾਈਬ੍ਰਾਟੋ | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | ਗਜ਼ ਨਾਲ ਵਜਾਉਣਾ / ਖੁੱਲ੍ਹੀ ਤਾਰ ਉੱਤੇ ਗਜ਼ ਫੇਰਨਾ |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | ਧੁਨ | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | ਕੈਡੈਂਸ / V ਕੋਰਡ / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | ਪਹਿਲੇ ਪੂਰੇ ਬਾਰ ਤੋਂ ਪਹਿਲਾਂ ਦੇ ਸੁਰ |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | ਸ਼ੁਰੂਆਤ / ਅੰਤਰਾ 1 / ਮੁਖੜਾ / ਬ੍ਰਿਜ / ਸੋਲੋ / ਅੰਤ / ਟੈਗ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | ਹਿੱਸਾ |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | ਸਿਲਸਿਲਾ | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | ਸਿਲਸਿਲੇ ਦੀ ਸੁਰੱਖਿਆ |  |
| best run | The longest streak so far | Progress | `best run` | ਸਭ ਤੋਂ ਲੰਮਾ ਸਿਲਸਿਲਾ | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | ਬੈਜ / ਪ੍ਰਾਪਤੀ |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | ਪੱਧਰ / ਤਾਰੇ / XP / ਕੰਬੋ / ਸਕੋਰ / ਗੇੜ |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | ਦੋਸਤ ਨੂੰ ਚੁਣੌਤੀ ਦਿਓ |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | ਚੁਣੌਤੀ | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | ਕੋਰਸ / ਇਕਾਈ / ਪਾਠ / ਕਦਮ |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | ਕੁਇਜ਼ / ਸੰਕੇਤ |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | ਸਬਸਕ੍ਰਿਪਸ਼ਨ / ਨਵੀਨੀਕਰਨ / ਰੱਦ ਕਰੋ | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | ਮੁਫ਼ਤ ਟ੍ਰਾਇਲ / ਟ੍ਰਾਇਲ ਮੁੱਕਦੀ ਹੈ |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | ਸਾਲਾਨਾ / ਮਾਸਿਕ / ਜੀਵਨ ਭਰ |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | ਖਰੀਦਦਾਰੀ ਬਹਾਲ ਕਰੋ |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | ਭੁਗਤਾਨ ਵਿਧੀ / ਬਿਲਿੰਗ ਦੀ ਸਮੱਸਿਆ |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | ਸ਼ਰਤਾਂ / ਪਰਦੇਦਾਰੀ ਨੀਤੀ | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | ਗਿਟਾਰ / ਯੂਕੁਲੇਲੇ / ਬਾਸ / ਵਾਇਲਿਨ / ਚੈਲੋ / ਮੈਂਡੋਲਿਨ / ਬੈਂਜੋ | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | ਕੰਨ ਦੀ ਸਿਖਲਾਈ / ਸੰਗੀਤ ਸਿਧਾਂਤ / ਲੈਅ / ਗਾਇਕੀ |  |
| Songs | Course title, also the Songs tab | ਗੀਤ |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | ਮੌਲਿਕ ਗੀਤ | Keep or translate: decide once. |
| Standards & Classics | Course title | ਪ੍ਰਚਲਿਤ ਅਤੇ ਕਲਾਸਿਕ ਗੀਤ |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | ਯੂਕੁਲੇਲੇ / ਮੈਂਡੋਲਿਨ / ਵਾਇਲਿਨ / ਚੈਲੋ / ਬਾਸ ਗੀਤਾਂ ਦੀ ਕਿਤਾਬ | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ਟਿਊਨ ਕਰੋ (verb/tab); ਧੁਨ (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | ਸ਼ਾਰਪ / ਫਲੈਟ (accidentals); ਉੱਚਾ / ਨੀਵਾਂ (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | ਬਾਰ | a UI bar, a pub |
| key | tonality | a piano key, a password key | ਸੁਰ (tonality); prefer over ambiguous ਕੁੰਜੀ | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | ਪਿਕ (plectrum); ਚੁਣੋ (choose); ਤਾਰ ਵਜਾਓ (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | ਸੁਰ ਮਿਲਣ ਦੀ ਪੁਸ਼ਟੀ | a padlock |
| take | one recorded attempt | "take a lesson" | ਟੇਕ (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | ਸਿਲਸਿਲਾ (streak); ਪੂਰਾ ਯਤਨ (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | ਕੋਰਡ ਚਾਰਟ (music); ਚਾਰਟ (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ਇੰਟੋਨੇਸ਼ਨ — ਆਧਾਰ ਸੁਰ ਨਾਲ ਸੁਰ ਵਿੱਚ ਵਜਾਉਣਾ; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | ਅੱਗੇ / ਫਿਰ / ਹੌਲੀ | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | ਅਭਿਆਸ | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | ਕੰਪਨ ਮਹਿਸੂਸ ਕਰੋ (haptics; not emotion) | emotions |

## 5. Lesson-draft refinements (AI decisions; independent review pending)

- Duration uses **ਨੋਟ**: whole note **ਪੂਰਾ ਨੋਟ**, half note **ਅੱਧਾ ਨੋਟ**, quarter note **ਚੌਥਾਈ ਨੋਟ**, eighth note **ਅੱਠਵਾਂ ਨੋਟ**, sixteenth note **ਸੋਲ੍ਹਵਾਂ ਨੋਟ**. These name time values, never scale degrees. Pitch or scale membership uses **ਸੁਰ**; scale degree is **ਸਕੇਲ ਦਾ ਦਰਜਾ**. A third/fifth as an interval is **ਤੀਜਾ/ਪੰਜਵਾਂ ਸੁਰ ਅੰਤਰ**, and as a chord tone **ਤੀਜਾ/ਪੰਜਵਾਂ ਸੁਰ**.
- Timing is **ਤਾਲ ਨਾਲ ਮਿਲਾਪ / ਸਮੇਂ ਦੀ ਪਕੜ**, not bodily stillness. Keep a steady beat = **ਤਾਲ ਇਕਸਾਰ ਰੱਖੋ**. Keep the hand still = **ਹੱਥ ਟਿਕਿਆ ਰੱਖੋ**.
- High/low strings by pitch: **ਉੱਚੇ/ਨੀਵੇਂ ਸੁਰਾਂ ਵਾਲੀਆਂ ਤਾਰਾਂ**. Physical top/bottom must explicitly follow the actual instrument orientation; ukulele string 4 is physically upper but high G, and string 3 is lowest in standard re-entrant tuning (**ਰੀ-ਐਂਟਰੈਂਟ ਟਿਊਨਿੰਗ**).
- Spoken eighth subdivisions: **ਇੱਕ-ਤੇ-ਦੋ-ਤੇ**. Spoken sixteenth subdivisions: **ਇੱਕ-ਇ-ਤੇ-ਅ, ਦੋ-ਇ-ਤੇ-ਅ** (four short syllables per beat). Preserve every ASCII digit when the source uses digits. Swing/shuffle mnemonic **ਹਮ-ਟੀ, ਡਮ-ਟੀ**, with the first syllable long and second short, is explained rather than treated as straight subdivisions.
- Strum abbreviations D/U are English directions, not pitches: retain when shown as notation and explain **D=ਹੇਠਾਂ, U=ਉੱਪਰ**. English-initial open-string mnemonics retain their original words plus an explanation that initial letters encode the note names; do not pretend Punjabi initials encode them.
- Original sung words used to locate a passage stay quoted in English, followed by **ਬੋਲਾਂ ਦੇ ਸੁਰ / ਦੇ ਸੁਰ** or another Punjabi locator; the lyric itself is not replaced by a singable translation.
- Additional terms: root **ਮੂਲ ਸੁਰ**; tonic/home **ਆਧਾਰ ਸੁਰ**; arpeggio **ਆਰਪੈਜੀਓ**; triad **ਤਿੰਨ-ਸੁਰੀ ਕੋਰਡ**; inversion **ਉਲਟਾਅ**; lick **ਲਿੱਕ**; riff **ਰਿਫ਼**; arrangement **ਸੰਗੀਤਕ ਤਰਤੀਬ**; texture **ਆਵਾਜ਼ੀ ਬਣਤਰ**; fill **ਫਿੱਲ**; comping **ਸੰਗਤ**; common tone **ਸਾਂਝਾ ਸੁਰ**; Dorian **ਡੋਰੀਅਨ**; Mixolydian **ਮਿਕਸੋਲਿਡੀਅਨ**; Travis picking **ਟ੍ਰੈਵਿਸ ਪਿਕਿੰਗ**; trill **ਟ੍ਰਿਲ**; shuffle **ਸ਼ਫ਼ਲ**; syncopation **ਸਿੰਕੋਪੇਸ਼ਨ**; palm muting **ਹਥੇਲੀ ਨਾਲ ਮਿਊਟ ਕਰਨਾ**; rest stroke (bass plucking) **ਟਿਕਦਾ ਸਟ੍ਰੋਕ**.
- Titles of unestablished traditional songs and Timbre Originals remain in English throughout titles and prose; translate appended teaching descriptions. Exact notation, pure proper titles and bare name/year credits remain candidates for independent key-specific invariant review, not author-approved exceptions.

- Bowed-string terms: bow **ਗਜ਼**; down-bow/up-bow **ਡਾਊਨ-ਬੋ / ਅੱਪ-ਬੋ**, with frog-to-tip / tip-to-frog direction explained; frog **ਫ੍ਰੌਗ**; rosin **ਰੋਜ਼ਿਨ**; fingerboard **ਫਿੰਗਰਬੋਰਡ**; pizzicato **ਪਿਜ਼ੀਕਾਟੋ**; slur **ਸਲਰ** (multiple notes within one bow stroke); shift **ਸਥਿਤੀ ਬਦਲਣਾ**; extension **ਐਕਸਟੈਂਸ਼ਨ** (widening the left hand). Violin high/low second finger **ਉੱਚੀ/ਨੀਵੀਂ 2** describes finger position and pitch, never note duration.
- Chop is the named short chord technique **ਚੌਪ** (reggae/mandolin), while chunk is described **ਦਬਿਆ ਸਟ੍ਰੋਕ**; the explanations retain the distinct muting action. Tremolo **ਟ੍ਰੈਮੋਲੋ** is rapid repeated picking, not vibrato. Crosspicking **ਕਰਾਸਪਿਕਿੰਗ**.
- Banjo: roll **ਰੋਲ**, forward roll **ਫਾਰਵਰਡ ਰੋਲ**, pinch **ਪਿੰਚ**, clawhammer **ਕਲੌਹੈਮਰ**, bum-ditty **ਬਮ-ਡਿ-ਟੀ** (long-short-short).
- Theory/ear terms: unison **ਇਕਸੁਰ**; audiation **ਆਡੀਏਸ਼ਨ**; perfect interval **ਪੂਰਨ ਸੁਰ ਅੰਤਰ**; diminished **ਡਿਮਿਨਿਸ਼ਡ**; augmented **ਆਗਮੈਂਟਡ**; dominant seventh **ਡੌਮੀਨੈਂਟ ਸੈਵੰਥ**; solfège syllables **ਦੋ / ਰੇ / ਮੀ / ਫਾ / ਸੋਲ / ਲਾ / ਟੀ**. Physical piano key **ਚਾਬੀ** (plural **ਚਾਬੀਆਂ**), distinct from tonality **ਸੁਰ**. Staff **ਸਟਾਫ਼**, treble clef **ਟ੍ਰੈਬਲ ਕਲੈਫ਼**, ledger line **ਲੈਜਰ ਲਾਈਨ**.
- Notation/rhythm: time signature **ਤਾਲ-ਮਾਪ ਚਿੰਨ੍ਹ**; key signature **ਸੁਰ-ਚਿੰਨ੍ਹ**; measure **ਮੇਜ਼ਰ** when teaching the synonym, otherwise **ਬਾਰ**; enharmonic **ਐਨਹਾਰਮੋਨਿਕ**; chord progression **ਕੋਰਡ-ਕ੍ਰਮ**; offbeat **ਔਫ਼ਬੀਟ**. Cadences: authentic **ਔਥੈਂਟਿਕ**, plagal **ਪਲੇਗਲ**, half **ਅੱਧੀ**, deceptive **ਭਰਮਾਉਂਦੀ**. Triplet counting uses **1-ਟਿ-ਟਾ**, three short subdivisions, with **ਟਾ** the last part.
- Pickup in rhythm is a **ਸ਼ੁਰੂਆਤੀ ਪਿਕਅੱਪ ਸੁਰ**, explained as **ਪਹਿਲੇ ਪੂਰੇ ਬਾਰ ਤੋਂ ਪਹਿਲਾਂ ਦਾ ਸੁਰ**; never literal **ਚੁੱਕ**. An instrument's electronic pickup remains **ਪਿਕਅੱਪ** in its physical context. Canonical fret spelling is **ਫ੍ਰੈੱਟ**.
