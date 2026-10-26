# Malayalam (ml) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | ml — Malayalam |  |
| Variant | Standard modern Malayalam |  |
| Register ("you") | Neutral respectful voice; നിങ്ങൾ where needed |  |
| Imperatives and buttons | Neutral infinitive instructions ചെയ്യുക, വായിക്കുക; short nouns for labels |  |
| Readers of unknown gender | Neutral constructions, no gender assumptions |  |
| Quotation marks | “…”; full stop . |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Ordinary word spaces; retain necessary joiners and correct chillu letters |  |
| Digits in literal numbers | ASCII 0–9 in literals; runtime numbers follow device |  |
| Units | സെന്റുകൾ; മിനിറ്റ്; സെക്കൻഡ്; മില്ലിസെക്കൻഡ്. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies notes; do not invent note names |  |
| Note names in lessons (lesson languages only) | Lessons are required; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | ഷാർപ്പ് / ഫ്ലാറ്റ് / ഡബിൾ ഷാർപ്പ് / ഡബിൾ ഫ്ലാറ്റ് |  |
| Tuning direction | താഴ്ന്നത് / ഉയർന്നത് for tuner direction; loan labels remain exact refs |  |
| iOS Settings path (legal text) | ക്രമീകരണങ്ങൾ › Apple അക്കൗണ്ട് › സബ്സ്ക്രിപ്ഷനുകൾ. AI-reviewed; device verification pending |  |
| Apple feature names | ഹോം സ്ക്രീൻ / ലോക്ക് സ്ക്രീൻ / വിജറ്റ് / ലൈവ് ആക്ടിവിറ്റി / ഷോർട്ട്കട്ട് / കൺട്രോൾ സെന്റർ / ഫാമിലി ഷെയറിംഗ്; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Neutral imperative; preserve ${applicationName} and every token |  |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: ഗിറ്റാർ, ബാസ്, യുകുലേലെ, വയലിൻ, ചെല്ലോ, സിത്താർ, തംബുരു | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | സ്റ്റാൻഡേർഡ് | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ട്യൂൺ | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | പഠനം | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | പാട്ടുകൾ | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | പരിശീലനം | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | പുരോഗതി | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | ക്രമീകരണങ്ങൾ | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | ഇന്ന് | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | ലക്ഷ്യം | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | നിങ്ങളുടെ പാട്ടുകൾ |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | പാട്ടിന്റെ ഷീറ്റ് |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | കോർഡ് ചാർട്ട് / വായിക്കുന്നയാളുടെ കാഴ്ച | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | കോർഡ് കാഴ്ച / നെക്ക് കാഴ്ച |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | കാണിക്കുക | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ട്യൂൺ ചെയ്യാൻ സ്ട്രം ചെയ്യുക |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | കമ്പനത്തിലൂടെ ട്യൂൺ ചെയ്യുക / കമ്പനം | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | ബുൾസ്ഐ | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | ചെവി പരിശീലനം |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | ഡ്രോൺ | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | തംബുരു |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ഇന്റണേഷൻ — ഡ്രോണിനൊപ്പം ശ്രുതിയിൽ വായിക്കൽ; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | മെട്രോനോം / സ്പീഡ് ട്രെയിനർ |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | കോർഡുകൾ / സ്കെയിലുകൾ |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | നില പരിശോധിക്കൽ |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | ഒപ്പം വായിക്കുക | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | അവസാന ടേക്ക്; ടേക്ക് = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | ലൂപ്പ് A–B / A സജ്ജമാക്കുക / B സജ്ജമാക്കുക | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | തുടക്കക്കാരൻ / സ്റ്റാൻഡേർഡ് / വിദഗ്ധൻ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | സ്റ്റുഡിയോ (ഭാരം കുറവ്) / റിയൽ-ടൈം 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | ഹാപ്റ്റിക്സ് | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ട്യൂണർ |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ട്യൂൺ-അപ്പ് |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ട്യൂണിംഗ് | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ട്യൂണിലാണ് | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | ഫ്ലാറ്റ് / ഷാർപ്പ് | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | സെന്റുകൾ | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | ശ്രുതി ഒത്തതിന്റെ സ്ഥിരീകരണം; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | തന്തി |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | പെഗ് / ഹെഡ്‌സ്റ്റോക്ക് |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | ആധാര സ്വരം / ആധാര ശ്രുതി / കൺസേർട്ട് പിച്ച് |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | എഴുതിയ സ്വരം / ടെമ്പറമെന്റ് |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | ക്രോമാറ്റിക് / സ്ട്രോബ് |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | കാപ്പോ |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | ശ്രുതി മാറ്റുക / ശ്രുതി മാറ്റം |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | നോട്ട് പേരുകൾ / സോൾഫെജ് / സർഗം |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ഫ്രെറ്റ് / തുറന്ന തന്തി | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | വിരൽ 1–4; 1 ചൂണ്ടുവിരൽ, 2 നടുവിരൽ, 3 മോതിരവിരൽ, 4 ചെറുവിരൽ; 0 തുറന്നത് | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | കോർഡ് / കോർഡ് ആകൃതി / ബാരെ കോർഡ് |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | മേജർ / മൈനർ / സെവൻത് / പവർ കോർഡ് | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | കീ (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | സ്കെയിൽ / മേജർ സ്കെയിൽ / പെന്ററ്റോണിക് പാറ്റേൺ | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | അര സ്വരം / മുഴു സ്വരം / സ്വരാന്തരം / മൂന്നാം / അഞ്ചാം / ഒക്ടേവ് |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | ബാർ |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ബീറ്റ് / ടെമ്പോ / ആദ്യ ബീറ്റ് / എണ്ണൽ |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | സ്ട്രം / താഴേക്കുള്ള സ്ട്രോക്ക് / മുകളിലേക്കുള്ള സ്ട്രോക്ക് / മ്യൂട്ട് സ്ട്രോക്ക് / മ്യൂട്ട് സ്ട്രോക്ക് / മ്യൂട്ട് | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | പിക്ക് (plectrum); തിരഞ്ഞെടുക്കുക (choose); തന്തി മീട്ടുക (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ഫിംഗർപിക്കിംഗ് / ഹാമർ-ഓൺ / പുൾ-ഓഫ് / സ്ലൈഡ് / ബെൻഡ് / വൈബ്രാറ്റോ | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | ബോ ഉപയോഗിച്ച് വായിക്കൽ / തുറന്ന തന്തിയിൽ ബോ ഉപയോഗിച്ച് വായിക്കൽ |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | ഈണം | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | കേഡൻസ് / V കോർഡ് / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | ആദ്യ പൂർണ്ണ ബാറിനു മുമ്പുള്ള സ്വരങ്ങൾ |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | തുടക്കം / ചരണം 1 / പല്ലവി / ബ്രിഡ്ജ് / സോളോ / അവസാനം / ടാഗ് | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | ഭാഗം |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | തുടർച്ച | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | തുടർച്ച സംരക്ഷണം |  |
| best run | The longest streak so far | Progress | `best run` | മികച്ച തുടർച്ച | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | ബാഡ്ജ് / നേട്ടം |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | നില / നക്ഷത്രങ്ങൾ / XP / കോംബോ / സ്കോർ / റൗണ്ട് |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | സുഹൃത്തിനെ വെല്ലുവിളിക്കുക |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | വെല്ലുവിളി | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | കോഴ്സ് / യൂണിറ്റ് / പാഠം / ഘട്ടം |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | ക്വിസ് / സൂചന |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | സബ്സ്ക്രിപ്ഷൻ / പുതുക്കൽ / റദ്ദാക്കുക | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | സൗജന്യ ട്രയൽ / ട്രയൽ അവസാനിക്കുന്നു |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | വാർഷികം / പ്രതിമാസം / ആജീവനാന്തം |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | വാങ്ങിയവ പുനഃസ്ഥാപിക്കുക |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | പണമടയ്ക്കൽ രീതി / ബില്ലിംഗ് പ്രശ്നം |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | നിബന്ധനകൾ / സ്വകാര്യതാ നയം | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | ഗിറ്റാർ / യുകുലേലെ / ബാസ് / വയലിൻ / ചെല്ലോ / മാൻഡലിൻ / ബാഞ്ചോ | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | ചെവി പരിശീലനം / സംഗീത സിദ്ധാന്തം / താളം / ആലാപനം |  |
| Songs | Course title, also the Songs tab | പാട്ടുകൾ |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | സ്വന്തം പാട്ടുകൾ | Keep or translate: decide once. |
| Standards & Classics | Course title | പ്രചാരത്തിലുള്ളതും ക്ലാസിക്കുമായ പാട്ടുകൾ |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | യുകുലേലെ / മാൻഡലിൻ / വയലിൻ / ചെല്ലോ / ബാസ് പാട്ടുപുസ്തകം | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ട്യൂൺ (verb/tab); ഈണം (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | ഷാർപ്പ് / ഫ്ലാറ്റ് (accidentals); ഉയർന്നത് / താഴ്ന്നത് (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | ബാർ | a UI bar, a pub |
| key | tonality | a piano key, a password key | കീ (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | പിക്ക് (plectrum); തിരഞ്ഞെടുക്കുക (choose); തന്തി മീട്ടുക (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | ശ്രുതി ഒത്തതിന്റെ സ്ഥിരീകരണം | a padlock |
| take | one recorded attempt | "take a lesson" | ടേക്ക് (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | തുടർച്ച (streak); പൂർണ്ണ ശ്രമം (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | കോർഡ് ചാർട്ട് (music); ചാർട്ട് (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ഇന്റണേഷൻ — ഡ്രോണിനൊപ്പം ശ്രുതിയിൽ വായിക്കൽ; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | അടുത്തത് / വീണ്ടും / പതുക്കെ | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | പരിശീലനം | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | കമ്പനം അനുഭവിക്കുക (haptics; not emotion) | emotions |

## 5. Lesson draft decisions (2026-10-26; AI draft, independent review pending)

- A played musical note is **സ്വരം**; a written note symbol may be **നോട്ട്**. Pitch is **ശ്രുതി**. Preserve all literal Latin note letters and chord symbols.
- Count spoken beat words in Malayalam script: **ഒന്ന്, രണ്ട്, മൂന്ന്, നാല്**. Subdivision syllables use Malayalam script (for example **ഒന്ന്-ആൻഡ്**); do not add numeric digits where English spells a number.
- An English initial-letter mnemonic may remain verbatim only when explicitly taught, with a Malayalam explanation of its initial letters. Sung-word locators remain the actual sung words, introduced or explained in Malayalam. These are not permissions for untranslated explanatory prose.
- Song titles without a well-established Malayalam title and all Timbre Originals keep the exact English title consistently in headings and prose. Standalone title/name/notation identities are invariant candidates, not approved translations; keep them in batch evidence for independent review, never change punctuation to evade the identity check.
- **count** (beat counting) and **list** are distinct senses. The parent-owned source split has separately reviewed Malayalam targets: timed **1, 2, 3 and 4** → **1, 2, 3 ആൻഡ് 4**; string list **Strings: 1, 2, 3 and 4** → **തന്തികൾ: 1, 2, 3, 4**. **Middle** as a finger label → **നടുവിരൽ**; **Middle section** → **മധ്യഭാഗം**. These are staged in the source-context addendum, not inserted into the frozen baseline.

- Lesson terms fixed across the instrument and ear-training batches: root **മൂലസ്വരം**; scale degree **സ്വരപടി**; triad **ത്രിസ്വര കോർഡ്**; inversion **വിപര്യയം**; phrase **സംഗീതവാക്യം**; fill **നിറവ്**; note highway **സ്വരപാത**.
- Named intervals use ordinal + **സ്വരാന്തരം**, e.g. **മൈനർ രണ്ടാം സ്വരാന്തരം**, **മേജർ രണ്ടാം സ്വരാന്തരം**, **മൂന്നാം സ്വരാന്തരം**, **അഞ്ചാം സ്വരാന്തരം**; perfect is **പെർഫെക്റ്റ്**. Chord members are **മൂന്നാം സ്വരം**, **അഞ്ചാം സ്വരം**. Time duration remains **സെക്കൻഡ്**, not the interval label.
- Duration names: **ക്വാർട്ടർ നോട്ട്**, **ഹാഫ് നോട്ട്**, **ഹോൾ നോട്ട്**, **എയ്ത്ത് നോട്ട്**, **സിക്സ്റ്റീന്ത് നോട്ട്**. Spoken subdivision **ഒന്ന്-ഇ-ആൻഡ്-അ**; banjo bum-ditty **ബം-ഡിറ്റ്-ടി**.

- Sung solfège syllables: **ഡോ, റെ, മി, ഫാ, സോൾ, ലാ, ടി**. These are distinct from unchanged Latin note letters in notation.

- “X is a Timbre Original”: **X എന്നത് Timbre ആപ്പിലെ സ്വന്തം പാട്ടാണ്**. The app noun carries the ending; do not inflect the brand or omit the linking noun.

- Syncopation is **സിങ്കോപ്പേഷൻ**, with adjectival **സിങ്കോപ്പേറ്റഡ്**. Use this spelling consistently, not the short-ഒ variant.
- Musical “home” is **ആധാരം / ആധാര സ്വരം / ആധാര കോർഡ്** as context requires, not a literal house. Distinguish pitch height (**ഉയർന്ന / താഴ്ന്ന ശ്രുതി**) from physical string, fret or keyboard position.
- In the singing lessons, “breathe low” cues belly/lower-rib expansion: **വയറ് വികസിപ്പിച്ച് ശ്വസിക്കുക**, with the fuller explanation **വയറും താഴത്തെ വാരിയെല്ലുകളും വികസിക്കുക**. Avoid a literal instruction to breathe downward.
