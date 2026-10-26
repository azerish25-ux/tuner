# Gujarati (gu) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | gu — Gujarati |  |
| Variant | Standard Gujarati, India |  |
| Register ("you") | Polite તમે; warm direct voice |  |
| Imperatives and buttons | Polite કરો, વગાડો; concise nouns for labels |  |
| Readers of unknown gender | Use gender-neutral imperatives and neutral reader descriptions |  |
| Quotation marks | “…”; full stop . |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Normal word spaces; preserve necessary script joiners |  |
| Digits in literal numbers | ASCII 0–9 in literal text; runtime follows device |  |
| Units | સેન્ટ્સ; મિનિટ; સેકન્ડ; મિલિસેકન્ડ. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No letter case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies note names; never invent them |  |
| Note names in lessons (lesson languages only) | Lessons are required; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | શાર્પ / ફ્લૅટ / ડબલ શાર્પ / ડબલ ફ્લૅટ |  |
| Tuning direction | નીચો / ઊંચો; not accidentals |  |
| iOS Settings path (legal text) | સેટિંગ્સ › Apple એકાઉન્ટ › સબ્સ્ક્રિપ્શન. AI-reviewed; device verification pending |  |
| Apple feature names | હોમ સ્ક્રીન / લૉક સ્ક્રીન / વિજેટ / લાઇવ ઍક્ટિવિટી / શૉર્ટકટ / કંટ્રોલ સેન્ટર / ફૅમિલી શેરિંગ; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Polite imperative; preserve ${applicationName} and all other tokens |  |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: ગિટાર, બાસ, યુકુલેલે, વાયોલિન, ચેલો, સિતાર, તાનપુરો | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | સ્ટાન્ડર્ડ | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ટ્યુન કરો | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | શીખો | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | ગીતો | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | પ્રેક્ટિસ | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | પ્રગતિ | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | સેટિંગ્સ | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | આજે | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | લક્ષ્ય | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | તમારાં ગીતો |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | ગીતની શીટ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | કોર્ડ ચાર્ટ / વાદક દૃશ્ય | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | કોર્ડ દૃશ્ય / નેક દૃશ્ય |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | બતાવો | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ટ્યુન કરવા સ્ટ્રમ કરો |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | કંપનથી ટ્યુન કરો / કંપન અનુભવો | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | સચોટ નિશાન | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | કાનની તાલીમ |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | આધાર સ્વર | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | તાનપુરો |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ઇન્ટોનેશન — આધાર સ્વર સાથે સૂરમાં વગાડવું; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | મેટ્રોનોમ / સ્પીડ ટ્રેનર |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | કોર્ડ્સ / સ્કેલ્સ |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | સ્તરની ચકાસણી |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | સાથે વગાડો | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | અંતિમ ટેક; ટેક = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | લૂપ A–B / A સેટ કરો / B સેટ કરો | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | શિખાઉ / સ્ટાન્ડર્ડ / નિષ્ણાત | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | સ્ટુડિયો (હળવું) / રિયલ-ટાઇમ 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | હેપ્ટિક્સ | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ટ્યુનર |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ટ્યુન-અપ |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ટ્યુનિંગ | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ટ્યુનમાં | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | નીચો / ઊંચો | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | સેન્ટ્સ | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | સૂર મળ્યાની પુષ્ટિ; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | તાર |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ખૂંટી / હેડસ્ટોક |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | સંદર્ભ સ્વર / સંદર્ભ પિચ / કોન્સર્ટ પિચ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | લિખિત સ્વર / ટેમ્પરામેન્ટ |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | ક્રોમેટિક / સ્ટ્રોબ |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | કેપો |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | સૂર બદલો / સૂર પરિવર્તન |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | નોટના નામ / સોલ્ફેજ / સરગમ |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ફ્રેટ / ખુલ્લો તાર | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | આંગળી 1–4; 1 તર્જની, 2 મધ્યમા, 3 અનામિકા, 4 ટચલી; 0 ખુલ્લો | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | કોર્ડ / કોર્ડનો આકાર / બારે કોર્ડ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | મેજર / માઇનર / સેવન્થ / પાવર કોર્ડ | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | સૂર (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | સ્કેલ / મેજર સ્કેલ / પેન્ટાટોનિક પેટર્ન | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | અર્ધ સ્વર / પૂર્ણ સ્વર / સ્વરાંતર / તૃતીય / પંચમ / સપ્તક |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | બાર |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | તાલ / ટેમ્પો / પ્રથમ તાલ / ગણતરી |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | સ્ટ્રમ / નીચેનો સ્ટ્રોક / ઉપરનો સ્ટ્રોક / ચૉપ / દબાવેલો સ્ટ્રોક / મ્યૂટ | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | પિક (plectrum); પસંદ કરો (choose); તાર વગાડો (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ફિંગરપિકિંગ / હેમર-ઓન / પુલ-ઓફ / સ્લાઇડ / બેન્ડ / વાઇબ્રેટો | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | બો વડે વગાડવું / ખુલ્લા તાર પર બો ચલાવવો |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | ધૂન | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | કેડન્સ / V કોર્ડ / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | પિકઅપ — પ્રથમ આખા બાર પહેલાંના સ્વર |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | શરૂઆત / અંતરો 1 / મુખડું / બ્રિજ / સોલો / અંત / ટૅગ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | ભાગ |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | સિલસિલો | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | સિલસિલાની સુરક્ષા |  |
| best run | The longest streak so far | Progress | `best run` | સૌથી લાંબો સિલસિલો | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | બૅજ / સિદ્ધિ |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | સ્તર / તારા / XP / કોમ્બો / સ્કોર / રાઉન્ડ |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | મિત્રને પડકાર આપો |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | પડકાર | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | અભ્યાસક્રમ / એકમ / પાઠ / પગલું |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | ક્વિઝ / સંકેત |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | સબ્સ્ક્રિપ્શન / નવીકરણ / રદ કરો | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | મફત ટ્રાયલ / ટ્રાયલ પૂરી થાય છે |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | વાર્ષિક / માસિક / આજીવન |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | ખરીદીઓ પુનઃસ્થાપિત કરો |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | ચુકવણી પદ્ધતિ / બિલિંગની સમસ્યા |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | શરતો / ગોપનીયતા નીતિ | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | ગિટાર / યુકુલેલે / બાસ / વાયોલિન / ચેલો / મેન્ડોલિન / બેન્જો | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | કાનની તાલીમ / સંગીત સિદ્ધાંત / લય / ગાયન |  |
| Songs | Course title, also the Songs tab | ગીતો |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | મૌલિક ગીતો | Keep or translate: decide once. |
| Standards & Classics | Course title | પ્રચલિત અને ક્લાસિક ગીતો |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | યુકુલેલેની / મેન્ડોલિનની / વાયોલિનની / ચેલોની / બાસની ગીતોની ચોપડી | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ટ્યુન કરો (verb/tab); ધૂન (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | શાર્પ / ફ્લૅટ (accidentals); ઊંચો / નીચો (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | બાર | a UI bar, a pub |
| key | tonality | a piano key, a password key | સૂર (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | પિક (plectrum); પસંદ કરો (choose); તાર વગાડો (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | સૂર મળ્યાની પુષ્ટિ | a padlock |
| take | one recorded attempt | "take a lesson" | ટેક (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | સિલસિલો (streak); આખો પ્રયાસ (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | કોર્ડ ચાર્ટ (music); ચાર્ટ (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ઇન્ટોનેશન — આધાર સ્વર સાથે સૂરમાં વગાડવું; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | આગળ / ફરી / ધીમું | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | પ્રેક્ટિસ | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | કંપન અનુભવો (haptics; not emotion) | emotions |

## 5. Lesson drafting decisions (2026-10-26)

AI translation draft; not native-speaker certification. Preserve Latin note/chord notation and ASCII digit groups exactly. Ordinary instructional prose is Gujarati; quoted original sung-word locators and English mnemonic initials may remain when needed to explain the exercise. Translate the explanation, not the original lyrics. Retain original song names consistently in lesson titles and prose unless a well-established Gujarati title is documented; no invented local title. Exact notation-only strings and retained proper-title/author strings are held for independent invariant review, not altered with punctuation merely to defeat identity checks.

Additional consistent lesson terms: note = સ્વર (a musical sound); pitch = સ્વરની ઊંચાઈ or પિચ where technical; rhythm = લય; beat = તાલ; rest = વિરામ; root = મૂળ સ્વર; major/minor = મેજર/માઇનર; palm mute = હથેળીથી મ્યૂટ કરવું; riff = રિફ; melody = ધૂન; bass line = બાસ લાઇન; groove = ગ્રૂવ; triplet = ત્રિપુટ; shuffle = શફલ; swing = સ્વિંગ; syncopation = સિન્કોપેશન; eighth note = એઇથ નોટ; quarter note = ક્વાર્ટર નોટ; half note = હાફ નોટ; whole note = હોલ નોટ. These are rhythmic durations, not ordinal pitch degrees; નોટ is feminine (plural નોટો). Duration rests use the same qualifier plus વિરામ, e.g. ક્વાર્ટર વિરામ. Keep અર્ધ/પૂર્ણ સ્વર for half/whole steps and preserve genuine scale-degree ordinals. Whole meaning the entire sustained sound, rather than the duration value, remains આખો સ્વર. Spelled-out quantities stay words; never introduce numeric fractions absent from the source.

Further lesson distinctions: chop = ચૉપ (a clipped reggae/bluegrass chord), chunk = દબાવેલો સ્ટ્રોક (percussive ukulele strum); these related but distinct actions must not share an indistinguishable exercise label. triad = ત્રિસ્વરી કોર્ડ; inversion = ઉલટાવ; arpeggio = આર્પેજિયો; slur = સ્લર; tremolo = ટ્રેમોલો; trill = ટ્રિલ; down-bow/up-bow = ડાઉન-બો/અપ-બો; bow frog = ફ્રૉગ; fingerboard = ફિંગરબોર્ડ; natural = નૅચરલ; high/low second finger = ઊંચી/નીચી 2 when the source uses the digit. Interlude chip = મધ્ય વાદ્યભાગ.

Source solfège syllable names (not source Latin pitch letters) are transliterated consistently: do/re/mi/fa/sol/la/ti = ડો/રે/મી/ફા/સોલ/લા/ટી; source si, if present, = સી. This localizes syllable names without converting C, D, E, etc. to solfège. Banjo alternating thumb = વારાફરતી અંગૂઠો; alternating thumb roll = વારાફરતી અંગૂઠાનો રોલ. Tonal “home” = મૂળ સ્વર / મૂળ સૂર / આધાર as context requires, not a literal house.

Spelling: dominant = ડૉમિનન્ટ; perfect interval = પરફેક્ટ; unison = યુનિસન. Source solfège syllables remain Gujarati even before Gujarati postpositions (ડો થી may be written ડોથી; never Latin doથી). Original song titles such as Do Lord, if encountered, remain protected titles.

Final lesson refinements: dotted = બિંદુવાળો (બિંદુવાળી with feminine નોટ); sixteenth note = સિક્સટીન્થ નોટ; seventh interval = સપ્તમ (chord quality remains સેવન્થ); note highway = સ્વરપથ; Pre-chorus chip = પૂર્વમુખડું; Last theme chip = અંતિમ ધૂન. Vocal warm-up syllables ah/da/loo = આ/દા/લૂ. Counting syllables e/and/a = ઈ/એન્ડ/અ and trip-let = ટ્રિપ-લેટ, distinct from preserved original sung-word locators. Rhythmic એન્ડ is one timed syllable; the ordinary prose/list conjunction remains અને. A sung syllable is ઉચ્ચારખંડ, not a written alphabetic letter. Breathe low = પેટ તરફ ઊંડો શ્વાસ લો. These are translation decisions, not native certification.

Genre spelling: ballad = બૅલડ; Latin = લૅટિન. English staff mnemonics explain the relevant word initial in Gujarati without adding extra note tokens absent from the source.

## Independent review integration — 2026-10-26

Three exact, guarded terminology fragments from the independent review are applied once above. Rhythmic એન્ડ is distinct from the ordinary conjunction અને; duration names are distinct from pitch-step ordinals.

## Separated source contexts — 6,082-key source

The two source edits separate string enumeration from spoken rhythm, and a middle finger from a musical section. Use only the exact context below:

| English source | Context | Translation |
|---|---|---|
| Strings: 1, 2, 3 and 4 | Ukulele string-number distractor | તાર: 1, 2, 3 અને 4 |
| Middle section | Musical section, six arrangements | વચ્ચેનો ભાગ |
| 1, 2, 3 and 4 | Spoken rhythm distractor | 1, 2, 3 એન્ડ 4 |
| Middle | Middle finger, three banjo options | મધ્યમા |

The 6,080-pair baseline review and the four-key context delta are distinct independent AI reviews, not a new blanket review or human/native certification of 6,082 pairs. The exact source-bound invariant decisions are now registered; author drafting notes above describe their historical hold. Runtime layout, RTL where relevant, audio and VoiceOver QA remain pending. Previously reviewed UI haptic wording is preserved.

The historical `મધ્યમા` → `મધ્ય` neutralization is superseded by the split; retain the precise finger name `મધ્યમા`. Do not replay that old correction.
