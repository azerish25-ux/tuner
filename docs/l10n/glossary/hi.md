# Hindi (hi) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | hi — Hindi |  |
| Variant | Standard modern Hindi (India), Devanagari |  |
| Register ("you") | Polite आप; warm, direct teacher voice |  |
| Imperatives and buttons | Polite imperatives करें, बजाएँ; short nouns for labels |  |
| Readers of unknown gender | Use gender-neutral imperatives; avoid gendered reader predicates |  |
| Quotation marks | “…”; sentence-final । |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Normal word spaces; spaces around Latin names and arguments; preserve required script joiners |  |
| Digits in literal numbers | ASCII 0–9 in new literal text; runtime numbers follow device |  |
| Units | सेंट्स; मिनट; सेकंड; मिलीसेकंड. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case in Devanagari; preserve brand capitalization |  |
| Note names in the interface | Runtime arguments supply notes; do not invent names |  |
| Note names in lessons (lesson languages only) | Lessons are required; if referenced, preserve C, F♯, B♭, Em, G7 |  |
| Sharp / flat / double sharp / double flat as words | शार्प / फ़्लैट / डबल शार्प / डबल फ़्लैट |  |
| Tuning direction | नीचा / ऊँचा for tuner direction, not accidentals |  |
| iOS Settings path (legal text) | सेटिंग्स › Apple खाता › सदस्यताएँ. AI-reviewed wording; device verification pending |  |
| Apple feature names | होम स्क्रीन; लॉक स्क्रीन; विजेट; लाइव ऐक्टिविटी; शॉर्टकट; कंट्रोल सेंटर; फ़ैमिली शेयरिंग. Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Polite imperative; preserve every ${…} token, especially ${applicationName} |  |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries verbatim; e.g. गिटार, बास, युकुलेले, वायलिन, चेलो, सितार, तानपुरा | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | स्टैंडर्ड | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ट्यून करें | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | सीखें | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | गाने | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | अभ्यास | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | प्रगति | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | सेटिंग्स | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | आज | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | लक्ष्य | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | आपके गाने |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | गाने की शीट |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | कॉर्ड चार्ट / वादक दृश्य | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | कॉर्ड दृश्य / नेक दृश्य |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | दिखाएँ | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ट्यून करने के लिए स्ट्रम करें |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | कंपन से ट्यून करें / कंपन | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | सटीक निशाना | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | कान की ट्रेनिंग |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | आधार स्वर | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | तानपुरा |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | इंटोनेशन — आधार स्वर के साथ सुर में बजाना; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | मेट्रोनोम / स्पीड ट्रेनर |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | कॉर्ड्स / स्केल |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | स्तर जाँच |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | साथ में बजाएँ | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | अंतिम टेक; टेक = one recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | लूप A–B / A सेट करें / B सेट करें | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | शुरुआती / स्टैंडर्ड / विशेषज्ञ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | स्टूडियो (हल्का) / रियल-टाइम 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | हैप्टिक्स | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ट्यूनर |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ट्यून-अप |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ट्यूनिंग | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | सुर में | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | नीचा / ऊँचा | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | सेंट्स | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | सुर मिलने की पुष्टि; never a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | तार |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | खूँटी / हेडस्टॉक |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | संदर्भ स्वर / संदर्भ पिच / कॉन्सर्ट पिच |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | लिखित स्वर / टेम्परामेंट |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | क्रोमैटिक / स्ट्रोब |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | कैपो |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | सुर बदलें / सुर परिवर्तन |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | नोट के नाम / सॉल्फेज / सरगम |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | फ़्रेट / खुला तार | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | उँगली 1–4; 1 तर्जनी, 2 मध्यमा, 3 अनामिका, 4 छोटी उँगली; 0 खुला तार | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | कॉर्ड / कॉर्ड का आकार / बारे कॉर्ड |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | मेजर / माइनर / सेवन्थ / पावर कॉर्ड | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | सुर (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | स्केल / मेजर स्केल / पेंटाटोनिक पैटर्न | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | आधा स्वर / पूरा स्वर / स्वरांतर / तृतीय / पंचम / सप्तक |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | बार |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ताल / टेम्पो / पहला ताल / गिनती |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | स्ट्रम / नीचे का स्ट्रोक / ऊपर का स्ट्रोक / दबा स्ट्रोक / दबा स्ट्रोक / म्यूट | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | पिक (plectrum); चुनें (choose); तार बजाएँ (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | फ़िंगरपिकिंग / हैमर-ऑन / पुल-ऑफ़ / स्लाइड / बेंड / वाइब्रेटो | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | बो से बजाना / खुले तार पर बो चलाना |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | धुन | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | कैडेंस / V कॉर्ड / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | पहले पूरे बार से पहले के स्वर |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | शुरुआत / अंतरा 1 / मुखड़ा / ब्रिज / सोलो / अंत / टैग | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | खंड |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | सिलसिला | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | सिलसिला सुरक्षा |  |
| best run | The longest streak so far | Progress | `best run` | सबसे लंबा सिलसिला | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | बैज / उपलब्धि |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | स्तर / सितारे / XP / कॉम्बो / स्कोर / दौर |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | दोस्त को चुनौती दें |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | चुनौती | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | पाठ्यक्रम / इकाई / पाठ / चरण |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | प्रश्नोत्तरी / संकेत |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | सदस्यता / नवीनीकरण / रद्द करें | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | मुफ़्त ट्रायल / ट्रायल समाप्त होता है |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | वार्षिक / मासिक / आजीवन |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | खरीदारी पुनर्स्थापित करें |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | भुगतान विधि / बिलिंग की समस्या |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | शर्तें / गोपनीयता नीति | Apple's EULA is linked as "Terms". |

## 3. Course and song names

Lesson policy (2026-10-26): Hindi requires all 6,080 lesson strings, with automatic phone-language selection. English fallback is incomplete, not English-by-design. These are AI translation decisions, not native certification. Preserve sung originals, notation and proper-name titles only; translate all teaching prose and connecting words in credits.


| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | गिटार / युकुलेले / बास / वायलिन / चेलो / मैंडोलिन / बैंजो | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | कान की ट्रेनिंग / संगीत सिद्धांत / लय / गायन |  |
| Songs | Course title, also the Songs tab | गाने |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | मौलिक गाने | Keep or translate: decide once. |
| Standards & Classics | Course title | प्रचलित और क्लासिक गाने |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | युकुलेले / मैंडोलिन / वायलिन / चेलो / बास गानों की किताब | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

Song titles, the rule for this locale (fill one line each):

- Public-domain songs with an established title in the language (Ode to Joy, Silent Night, Twinkle Twinkle Little Star …): use the established Hindi title; otherwise keep English. (Current tables use local titles where they exist: ru «Зелёные рукава», zh-CN 《绿袖子》.)
- Other traditional songs (Clementine, Shenandoah, Molly Malone …): keep the English title (ja グリーンスリーブス, ko 그린슬리브스).
- Timbre Originals (Kite Weather, Ghost Light, Neon Laundromat …): keep the original English title. (Current lesson tables translate them: de Drachenwetter, ja 「凧日和」.)
- A title in prose must equal the title of its song lesson in this locale (the helper adds it to lesson batches as `lesson_title`), and Game Center's leaderboard for a featured song uses the same title.
- Lyric credits ("Traditional (printed 1876; James Yorkston, 1884)", "Words from 1779, tune from 1829"): names and years as they are; the connecting words translated.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | ट्यून करें (verb/tab); धुन (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | शार्प / फ़्लैट (accidentals); ऊँचा / नीचा (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | बार | a UI bar, a pub |
| key | tonality | a piano key, a password key | सुर (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | पिक (plectrum); चुनें (choose); तार बजाएँ (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | सुर मिलने की पुष्टि | a padlock |
| take | one recorded attempt | "take a lesson" | टेक (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | सिलसिला (streak); पूरा प्रयास (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | कॉर्ड चार्ट (music); चार्ट (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | इंटोनेशन — आधार स्वर के साथ सुर में बजाना; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | अगला / फिर से / धीरे | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | अभ्यास | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | कंपन महसूस करें (haptics; not emotion) | emotions |

## 5. Exact song-title reference map

No reliable single established Hindi form is asserted for these source titles; retain their identifying title, translating descriptive suffixes where present. This explicit map controls all prose references; original sung words stay unchanged.

| English title | Hindi reference |
|---|---|
| Abide with Me | Abide with Me |
| All Through the Night | All Through the Night |
| Amazing Grace | Amazing Grace |
| Amazing Grace, fingerpicked | Amazing Grace, fingerpicked |
| Angeline the Baker | Angeline the Baker |
| Angels from the Realms of Glory | Angels from the Realms of Glory |
| Arkansas Traveler | Arkansas Traveler |
| Au clair de la lune | Au clair de la lune |
| Auld Lang Syne | Auld Lang Syne |
| Aura Lee | Aura Lee |
| Away in a Manger | Away in a Manger |
| Basement Weather | Basement Weather |
| Boardwalk Comet | Boardwalk Comet |
| Bobby Shafto | Bobby Shafto |
| Boil Them Cabbage Down | Boil Them Cabbage Down |
| Brahms' Lullaby | Brahms' Lullaby |
| Bright Side of the Block | Bright Side of the Block |
| Camptown Races | Camptown Races |
| Can-can | Can-can |
| Canon in D | Canon in D |
| Carmen: Prelude | Carmen: प्रस्तावना |
| Carousel at Closing Time | Carousel at Closing Time |
| Cedar Smoke | Cedar Smoke |
| Clementine | Clementine |
| Cold Lake | Cold Lake |
| Constellation Prize | Constellation Prize |
| Copper Wire | Copper Wire |
| Cripple Creek | Cripple Creek |
| Cumberland Gap | Cumberland Gap |
| Danny Boy (Londonderry Air) | Danny Boy (Londonderry Air) |
| Deck the Halls | Deck the Halls |
| Down by the Riverside | Down by the Riverside |
| Down by the Riverside: your arrangement | Down by the Riverside: आपकी अरेंजमेंट |
| Dust on the Dashboard | Dust on the Dashboard |
| Echo Canyon | Echo Canyon |
| Eine kleine Nachtmusik | Eine kleine Nachtmusik |
| First Frost | First Frost |
| For the Beauty of the Earth | For the Beauty of the Earth |
| Frère Jacques | Frère Jacques |
| Für Elise | Für Elise |
| Ghost Light | Ghost Light |
| Glass Satellites | Glass Satellites |
| Glow-in-the-Dark Stars | Glow-in-the-Dark Stars |
| Good King Wenceslas | Good King Wenceslas |
| Gravel Road Two-Step | Gravel Road Two-Step |
| Greensleeves | Greensleeves |
| Greensleeves: the chords | Greensleeves: कॉर्ड |
| Greensleeves: the melody | Greensleeves: धुन |
| Halogen | Halogen |
| Hammock Season | Hammock Season |
| Hard Times Come Again No More | Hard Times Come Again No More |
| Hark! The Herald Angels Sing | Hark! The Herald Angels Sing |
| Holy, Holy, Holy | Holy, Holy, Holy |
| Home! Sweet Home! | Home! Sweet Home! |
| Houseplants | Houseplants |
| In the Bleak Midwinter | In the Bleak Midwinter |
| In the Hall of the Mountain King | In the Hall of the Mountain King |
| It Came Upon the Midnight Clear | It Came Upon the Midnight Clear |
| Jingle Bells | Jingle Bells |
| Joy to the World | Joy to the World |
| Jukebox Moon | Jukebox Moon |
| Jupiter | Jupiter |
| Keeper's Daughter | Keeper's Daughter |
| Kitchen Slow Dance | Kitchen Slow Dance |
| Kite Weather | Kite Weather |
| Korobeiniki | Korobeiniki |
| Lantern Hill | Lantern Hill |
| Largo, New World Symphony | Largo, New World Symphony |
| Last Bell | Last Bell |
| Late Bus Home | Late Bus Home |
| Late Checkout | Late Checkout |
| Letters in a Shoebox | Letters in a Shoebox |
| Lightly Row | Lightly Row |
| Loch Lomond | Loch Lomond |
| Low Tide Radio | Low Tide Radio |
| Market Day | Market Day |
| Mary Had a Little Lamb | Mary Had a Little Lamb |
| Mary Had a Little Lamb: three notes | Mary Had a Little Lamb: तीन स्वर |
| Mile Marker Zero | Mile Marker Zero |
| Minuet in G | Minuet in G |
| Molly Malone | Molly Malone |
| Morning Mood | Morning Mood |
| Moth and Ember | Moth and Ember |
| Mozart's Symphony No. 40 | Mozart's Symphony No. 40 |
| My Country, 'Tis of Thee | My Country, 'Tis of Thee |
| Nearer, My God, to Thee | Nearer, My God, to Thee |
| Neon Laundromat | Neon Laundromat |
| O Christmas Tree | O Christmas Tree |
| O Come, All Ye Faithful | O Come, All Ye Faithful |
| O God, Our Help in Ages Past | O God, Our Help in Ages Past |
| O Little Town of Bethlehem | O Little Town of Bethlehem |
| Ode to Joy | Ode to Joy |
| Ode to Joy on bass | Ode to Joy on bass |
| Oh! Susanna | Oh! Susanna |
| Oh! Susanna: the chorus | Oh! Susanna: मुखड़ा |
| Oh! Susanna: the verse | Oh! Susanna: अंतरा |
| Old Joe Clark | Old Joe Clark |
| Old MacDonald Had a Farm | Old MacDonald Had a Farm |
| Once in Royal David's City | Once in Royal David's City |
| Open Windows | Open Windows |
| Over You Soon | Over You Soon |
| Parking Lot Cathedral | Parking Lot Cathedral |
| Pocket Change | Pocket Change |
| Porchlight | Porchlight |
| Rain on the Skylight | Rain on the Skylight |
| Red River Valley | Red River Valley |
| Roller Rink | Roller Rink |
| Rondo alla Turca | Rondo alla Turca |
| Rooftop Choir | Rooftop Choir |
| Row, Row, Row Your Boat | Row, Row, Row Your Boat |
| Rust Belt Shuffle | Rust Belt Shuffle |
| Saltwater Sunday | Saltwater Sunday |
| Scoreboard Lights | Scoreboard Lights |
| Scotland the Brave | Scotland the Brave |
| Shady Grove | Shady Grove |
| She'll Be Coming 'Round the Mountain | She'll Be Coming 'Round the Mountain |
| Shenandoah | Shenandoah |
| Silent Night | Silent Night |
| Simple Gifts | Simple Gifts |
| Skip to My Lou | Skip to My Lou |
| Slow Motion Strobe | Slow Motion Strobe |
| Snow Globe Town | Snow Globe Town |
| Soldier's Joy | Soldier's Joy |
| Sparkler Season | Sparkler Season |
| Spray Paint Sunrise | Spray Paint Sunrise |
| Spring | Spring |
| Static on Channel Nine | Static on Channel Nine |
| The Blue Danube | The Blue Danube |
| The Entertainer | The Entertainer |
| The First Noel | The First Noel |
| The Holly and the Ivy | The Holly and the Ivy |
| The Last Rose of Summer | The Last Rose of Summer |
| The Liberty Bell | The Liberty Bell |
| The Skye Boat Song | The Skye Boat Song |
| The Stars and Stripes Forever | The Stars and Stripes Forever |
| The Swan | The Swan |
| The Water Is Wide | The Water Is Wide |
| Thistle and Thread | Thistle and Thread |
| Twinkle Twinkle Little Star | Twinkle Twinkle Little Star |
| Twinkle, Twinkle, Little Star | Twinkle, Twinkle, Little Star |
| Velvet Hour | Velvet Hour |
| Walking the blues in A | Walking the blues in A |
| We Wish You a Merry Christmas | We Wish You a Merry Christmas |
| When the Saints Go Marching In | When the Saints Go Marching In |
| Yankee Doodle | Yankee Doodle |
| Your arrangement | Your arrangement |

## Independent review additions (2026-10-26)

Preserve the exact current reviewed title from Learn.strings when mentioning a song. Explain English note-initial mnemonics in Hindi; retained mnemonic headings depend on their paired Hindi explanation. Distinguish evenly timed notes from identical pitches, continuous picking from an immobile hand, and musical meter from chronological time. Original sung words remain only when identifying exact lyric targets. Review is AI semantic, not human/native or device certification.
