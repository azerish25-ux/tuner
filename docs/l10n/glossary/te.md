# Telugu (te) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | te — Telugu |  |
| Variant | Standard modern Telugu |  |
| Register ("you") | Polite మీరు; warm and direct. Existing informal Learn label retained only as exact control reference |  |
| Imperatives and buttons | Polite చేయండి, వాయించండి; short noun labels |  |
| Readers of unknown gender | Neutral constructions; avoid reader gender assumptions |  |
| Quotation marks | “…”; full stop . |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Normal word spaces; preserve needed ZWJ/ZWNJ |  |
| Digits in literal numbers | ASCII 0–9 in literal text; runtime follows device |  |
| Units | సెంట్లు; నిమిషాలు; సెకన్లు; మిల్లీసెకన్లు. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies notes; do not invent names |  |
| Note names in lessons (lesson languages only) | Not a lesson locale; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | షార్ప్ / ఫ్లాట్ / డబుల్ షార్ప్ / డబుల్ ఫ్లాట్ |  |
| Tuning direction | తక్కువ / ఎక్కువ for tuner direction; existing loan labels remain exact refs |  |
| iOS Settings path (legal text) | సెట్టింగ్‌లు › Apple ఖాతా › సబ్‌స్క్రిప్షన్‌లు. AI-reviewed; device verification pending |  |
| Apple feature names | హోమ్ స్క్రీన్ / లాక్ స్క్రీన్ / విడ్జెట్ / లైవ్ యాక్టివిటీ / షార్ట్‌కట్ / కంట్రోల్ సెంటర్ / ఫ్యామిలీ షేరింగ్; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: గిటార్, బాస్, యుకులేలే, వయొలిన్, చెల్లో, సితార్, తంబురా | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | స్టాండర్డ్ | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ట్యూన్ | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | నేర్చుకో | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | పాటలు | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | ప్రాక్టీస్ | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | పురోగతి | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | సెట్టింగ్‌లు | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | ఈరోజు | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | లక్ష్యం | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | మీ పాటలు |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | పాట షీట్ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | కార్డ్ చార్ట్ / వాయించేవారి వీక్షణ | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | కార్డ్ వీక్షణ / నెక్ వీక్షణ |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | చూపించండి | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ట్యూన్ చేయడానికి స్ట్రమ్ చేయండి |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | కంపనంతో ట్యూన్ చేయండి / కంపనాన్ని అనుభవించండి | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | బుల్స్‌ఐ | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | చెవి శిక్షణ |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | డ్రోన్ | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | తంబురా |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ఇంటొనేషన్ — డ్రోన్‌తో శ్రుతిలో వాయించడం; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | మెట్రోనోమ్ / స్పీడ్ ట్రైనర్ |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | కార్డ్‌లు / స్కేల్స్ |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | స్థాయి తనిఖీ |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | కలిసి వాయించండి | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | చివరి టేక్; టేక్ = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | లూప్ A–B / A సెట్ చేయండి / B సెట్ చేయండి | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | ప్రారంభ స్థాయి / స్టాండర్డ్ / నిపుణులు | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | స్టూడియో (తేలికైనది) / రియల్-టైమ్ 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | హాప్టిక్స్ | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ట్యూనర్ |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ట్యూన్ అప్ |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ట్యూనింగ్ | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ట్యూన్‌లో ఉంది | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | ఫ్లాట్ / షార్ప్ | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | సెంట్లు | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | శ్రుతి కుదిరిన నిర్ధారణ; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | తీగ |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | పెగ్ / హెడ్‌స్టాక్ |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | ఆధార స్వరం / ఆధార శ్రుతి / కాన్సర్ట్ పిచ్ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | లిఖిత స్వరం / టెంపరమెంట్ |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | క్రోమాటిక్ / స్ట్రోబ్ |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | క్యాపో |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | శ్రుతి మార్చండి / శ్రుతి మార్పు |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | నోట్ పేర్లు / సోల్ఫెజ్ / సర్గం |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ఫ్రెట్ / ఓపెన్ తీగ | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | వేలు 1–4; 1 చూపుడు, 2 మధ్య, 3 ఉంగరం, 4 చిటికెన; 0 ఓపెన్ | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | కార్డ్ / కార్డ్ ఆకారం / బారే కార్డ్ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | మేజర్ / మైనర్ / సెవెంత్ / పవర్ కార్డ్ | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | కీ (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | స్కేల్ / మేజర్ స్కేల్ / పెంటాటోనిక్ నమూనా | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | అర్ధ స్వరం / పూర్తి స్వరం / స్వరాంతరం / తృతీయ / పంచమ / ఆక్టేవ్ |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | బార్ |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | బీట్ / టెంపో / మొదటి బీట్ / లెక్కింపు |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | స్ట్రమ్ / కింది స్ట్రోక్ / పై స్ట్రోక్ / మ్యూట్ స్ట్రోక్ / మ్యూట్ స్ట్రోక్ / మ్యూట్ | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | పిక్ (plectrum); ఎంచుకోండి (choose); తీగ మీటండి (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ఫింగర్‌పికింగ్ / హ్యామర్-ఆన్ / పుల్-ఆఫ్ / స్లైడ్ / బెండ్ / వైబ్రాటో | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | బోతో వాయించడం / ఓపెన్ తీగపై బోతో వాయించడం |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | బాణీ | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | కేడెన్స్ / V కార్డ్ / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | మొదటి పూర్తి బార్‌కు ముందు స్వరాలు |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | ప్రారంభం / చరణం 1 / పల్లవి / బ్రిడ్జ్ / సోలో / ముగింపు / ట్యాగ్ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | భాగం |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | వరుస | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | వరుస రక్షణ |  |
| best run | The longest streak so far | Progress | `best run` | ఉత్తమ వరుస | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | బ్యాడ్జ్ / సాధన |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | స్థాయి / నక్షత్రాలు / XP / కాంబో / స్కోర్ / రౌండ్ |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | స్నేహితునికి సవాలు విసరండి |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | సవాలు | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | కోర్సు / యూనిట్ / పాఠం / దశ |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | క్విజ్ / సూచన |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | సబ్‌స్క్రిప్షన్ / పునరుద్ధరణ / రద్దు చేయండి | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | ఉచిత ట్రయల్ / ట్రయల్ ముగుస్తుంది |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | వార్షికం / నెలవారీ / జీవితకాలం |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | కొనుగోళ్లను పునరుద్ధరించు |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | చెల్లింపు పద్ధతి / బిల్లింగ్ సమస్య |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | నిబంధనలు / గోప్యతా విధానం | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | గిటార్ / యుకులేలే / బాస్ / వయొలిన్ / చెల్లో / మాండొలిన్ / బాంజో | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | చెవి శిక్షణ / సంగీత సిద్ధాంతం / లయ / గానం |  |
| Songs | Course title, also the Songs tab | పాటలు |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | సొంత పాటలు | Keep or translate: decide once. |
| Standards & Classics | Course title | ప్రసిద్ధ మరియు క్లాసిక్ పాటలు |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | యుకులేలే / మాండొలిన్ / వయొలిన్ / చెల్లో / బాస్ పాటల పుస్తకం | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ట్యూన్ (verb/tab); బాణీ (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | షార్ప్ / ఫ్లాట్ (accidentals); ఎక్కువ / తక్కువ (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | బార్ | a UI bar, a pub |
| key | tonality | a piano key, a password key | కీ (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | పిక్ (plectrum); ఎంచుకోండి (choose); తీగ మీటండి (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | శ్రుతి కుదిరిన నిర్ధారణ | a padlock |
| take | one recorded attempt | "take a lesson" | టేక్ (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | వరుస (streak); పూర్తి ప్రయత్నం (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | కార్డ్ చార్ట్ (music); చార్ట్ (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ఇంటొనేషన్ — డ్రోన్‌తో శ్రుతిలో వాయించడం; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | తర్వాత / మళ్లీ / నెమ్మదిగా | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | ప్రాక్టీస్ | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | కంపనాన్ని అనుభవించండి (haptics; not emotion) | emotions |
