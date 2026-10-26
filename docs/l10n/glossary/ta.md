# Tamil (ta) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | ta — Tamil |  |
| Variant | Standard modern Tamil |  |
| Register ("you") | Polite நீங்கள்; warm direct voice |  |
| Imperatives and buttons | Polite செய்யுங்கள், வாசியுங்கள் in instructions; செய்யவும் / வாசிக்கவும் for compact buttons; short nouns where appropriate |  |
| Readers of unknown gender | Neutral constructions; no gender assumptions |  |
| Quotation marks | “…”; full stop . |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Ordinary word spaces; preserve necessary script joiners |  |
| Digits in literal numbers | ASCII 0–9 in literals; runtime numbers follow device |  |
| Units | சென்ட்கள்; நிமிடம்; வினாடி; மில்லிவினாடி. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies notes; do not invent note names |  |
| Note names in lessons (lesson languages only) | Lessons are required; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | ஷார்ப் / ஃபிளாட் / டபுள் ஷார்ப் / டபுள் ஃபிளாட் |  |
| Tuning direction | கீழே / மேலே for tuner direction; not accidentals |  |
| iOS Settings path (legal text) | அமைப்புகள் › Apple கணக்கு › சந்தாக்கள். AI-reviewed; device verification pending |  |
| Apple feature names | முகப்புத் திரை / பூட்டுத் திரை / விட்ஜெட் / நேரலைச் செயல்பாடு / குறுக்குவழிகள் / கட்டுப்பாட்டு மையம் / குடும்பப் பகிர்வு; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: கிட்டார், பேஸ், யூகுலேலே, வயலின், செல்லோ, சித்தார், தம்புரா | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | நிலையான | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | டியூன் | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | கற்றல் | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | பாடல்கள் | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | பயிற்சி | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | முன்னேற்றம் | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | அமைப்புகள் | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | இன்று | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | இலக்கு | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | உங்கள் பாடல்கள் |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | பாடல் தாள் |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | கார்டு அட்டவணை / வாசிப்பவர் காட்சி | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | கார்டு காட்சி / நெக் காட்சி |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | காட்டுங்கள் | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | டியூன் செய்ய ஸ்ட்ரம் செய்யுங்கள் |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | அதிர்வால் டியூன் செய்யுங்கள் / அதிர்வை உணருங்கள் | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | துல்லியக் குறி | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | செவிப் பயிற்சி |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | ஆதார சுருதி | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | தம்புரா |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | இன்டோனேஷன் — ஆதார சுருதியுடன் சுருதி சேர்த்து வாசித்தல்; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | மெட்ரோனோம் / வேகப் பயிற்சியாளர் |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | கார்டுகள் / ஸ்கேல்கள் |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | நிலைச் சோதனை |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | சேர்ந்து வாசியுங்கள் | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | இறுதிப் பதிவு; பதிவு = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | லூப் A–B / A அமைக்கவும் / B அமைக்கவும் | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | தொடக்கநிலை / நிலையான / நிபுணர் | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | ஸ்டுடியோ (இலகுவானது) / நிகழ்நேர 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | ஹாப்டிக்ஸ் | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | டியூனர் |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | டியூன்-அப் |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | டியூனிங் | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | டியூனில் உள்ளது | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | கீழே / மேலே | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | சென்ட்கள் | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | சுருதி சேர்ந்ததற்கான உறுதி; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | தந்தி |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | முறுக்காணி / ஹெட்ஸ்டாக் |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | ஆதார சுரம் / ஆதார சுருதி / கான்சர்ட் பிட்ச் |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | எழுதப்பட்ட சுரம் / டெம்பரமென்ட் |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | குரோமேட்டிக் / ஸ்ட்ரோப் |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | கேப்போ |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | சுருதி மாற்றுங்கள் / சுருதி மாற்றம் |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | குறிப்பு பெயர்கள் / சோல்ஃபெஜ் / சர்கம் |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ஃப்ரெட் / திறந்த தந்தி | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | விரல் 1–4; 1 ஆள்காட்டி, 2 நடுவிரல், 3 மோதிரவிரல், 4 சுண்டுவிரல்; 0 திறந்த | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | கார்டு / கார்டு வடிவம் / பாரே கார்டு |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | மேஜர் / மைனர் / செவன்த் / பவர் கார்டு | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | சுருதி (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | ஸ்கேல் / மேஜர் ஸ்கேல் / பென்டாடோனிக் வடிவம் | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | அரை சுரம் / முழு சுரம் / சுர இடைவெளி / மூன்றாம் / ஐந்தாம் / ஸ்தாயி |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | பார் |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | துடிப்பு / டெம்போ / முதல் துடிப்பு / எண்ணிக்கை |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | ஸ்ட்ரம் / கீழ்நோக்கிய ஸ்ட்ரோக் / மேல்நோக்கிய ஸ்ட்ரோக் / சாப் (அடக்கிய ஸ்ட்ரோக்) / அடக்கிய ஸ்ட்ரோக் / மியூட் | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | பிக் (plectrum); தேர்ந்தெடுங்கள் (choose); தந்தியை மீட்டுங்கள் (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ஃபிங்கர்பிக்கிங் / ஹேமர்-ஆன் / புல்-ஆஃப் / ஸ்லைட் / பெண்ட் / வைப்ராட்டோ | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | வில்லால் வாசித்தல் / திறந்த தந்தியில் வில்லால் வாசித்தல் |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | மெட்டு | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | கேடன்ஸ் / V கார்டு / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | முதல் முழு பாருக்கு முந்தைய சுரங்கள் |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | தொடக்கம் / சரணம் 1 / பல்லவி / பிரிட்ஜ் / சோலோ / முடிவு / டேக் | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | பகுதி |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | தொடர்ச்சி | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | தொடர்ச்சிப் பாதுகாப்பு |  |
| best run | The longest streak so far | Progress | `best run` | சிறந்த தொடர்ச்சி | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | பதக்கம் / சாதனை |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | நிலை / நட்சத்திரங்கள் / XP / காம்போ / மதிப்பெண் / சுற்று |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | நண்பருக்குச் சவால் விடுங்கள் |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | சவால் | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | பாடத்திட்டம் / அலகு / பாடம் / படி |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | வினாடிவினா / குறிப்பு |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | சந்தா / புதுப்பித்தல் / ரத்துசெய்யுங்கள் | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | இலவசச் சோதனை / சோதனை முடிகிறது |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | ஆண்டுதோறும் / மாதாந்திரம் / வாழ்நாள் |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | வாங்கியவற்றை மீட்டமைக்கவும் |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | பணம் செலுத்தும் முறை / கட்டணச் சிக்கல் |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | விதிமுறைகள் / தனியுரிமைக் கொள்கை | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | கிட்டார் / யூகுலேலே / பேஸ் / வயலின் / செல்லோ / மாண்டலின் / பாஞ்சோ | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | செவிப் பயிற்சி / இசைக் கோட்பாடு / தாளம் / பாடுதல் |  |
| Songs | Course title, also the Songs tab | பாடல்கள் |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | சொந்தப் பாடல்கள் | Keep or translate: decide once. |
| Standards & Classics | Course title | பிரபலமான மற்றும் செவ்வியல் பாடல்கள் |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | யூகுலேலே / மாண்டலின் / வயலின் / செல்லோ / பேஸ் பாடல் புத்தகம் | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | டியூன் (verb/tab); மெட்டு (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | ஷார்ப் / ஃபிளாட் (accidentals); மேலே / கீழே (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | பார் | a UI bar, a pub |
| key | tonality | a piano key, a password key | சுருதி (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | பிக் (plectrum); தேர்ந்தெடுங்கள் (choose); தந்தியை மீட்டுங்கள் (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | சுருதி சேர்ந்ததற்கான உறுதி | a padlock |
| take | one recorded attempt | "take a lesson" | பதிவு (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | தொடர்ச்சி (streak); முழு முயற்சி (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | கார்டு அட்டவணை (music); வரைபடம் (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | இன்டோனேஷன் — ஆதார சுருதியுடன் சுருதி சேர்த்து வாசித்தல்; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | அடுத்து / மீண்டும் / மெதுவாக | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | பயிற்சி | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | அதிர்வை உணருங்கள் (haptics; not emotion) | emotions |

## 5. Lesson drafting decisions (2026-10-26)

- Lesson drafts use polite வாசியுங்கள் / மீட்டுங்கள் / கேளுங்கள் and standard modern Tamil. `note` in music is சுரம், not குறிப்பு (the latter is a hint); sustain is நீடிக்கவிடுங்கள், rest is இடைநிறுத்தம், pulse is துடிப்பு.
- Staff: சுரக் கோடுகள்; clef: கிளெஃப்; treble/bass clef: ட்ரெபிள்/பேஸ் கிளெஃப்; ledger line: கூடுதல் கோடு; key signature: சுருதிக் குறியீடு; time signature: தாளக் குறியீடு; accidentals: சுர மாற்றக் குறிகள். Preserve actual note letters, chord symbols and Roman numerals.
- Triad: மூன்று சுரக் கார்டு; root: மூலச் சுரம்; inversion: தலைகீழ் அமைப்பு; perfect/augmented/diminished intervals: பெர்ஃபெக்ட்/ஆக்மென்டட்/டிமினிஷ்ட் சுர இடைவெளி. Major/minor remain மேஜர்/மைனர்.
- Bow: வில்; bow hair: வில் முடி; frog: வில்லின் பிடிப்பகுதி; rosin: ரோசின்; bridge (instrument): பிரிட்ஜ்; neck: நெக்; fingerboard: விரற்பலகை; fretboard: ஃப்ரெட் பலகை. Do not confuse song bridge with instrument bridge.
- Solfège syllables in explanations: டோ ரே மி ஃபா சோல் லா டி. Actual source C/D/etc. stay Latin. English mnemonic sentences remain quoted with Tamil explanation so their note-letter initials survive. Original sung-word locators also remain quoted inside Tamil instruction; ordinary prose is Tamil.
- Song titles remain the exact original where no established Tamil title is known; instructional subtitles and prose are translated. Standalone unchanged title, credit or notation rows are held for independent invariant review, never disguised with punctuation or filler. Proper composer/author names remain exact; connecting credit words are Tamil.
- This is AI drafting and mechanical QA, not native/human certification; phone layout QA remains pending.
- Rhythmic durations use முழு நோட்டு / அரை நோட்டு / கால் நோட்டு / எட்டாம் நோட்டு / பதினாறாம் நோட்டு, distinct from pitch interval அரை சுரம். Spoken subdivision `and` is அண்ட் (one counting syllable), not the conjunction மற்றும். Beat accent is அழுத்தம்; syncopation is எதிர்த்தாளம்; harmonic rhythm/progression is கார்டு வரிசை.
- Violin finger positions: உயர்ந்த 2 / தாழ்ந்த 2; natural accidental as word: நேச்சுரல். Cello endpin: தாங்குக் கம்பி. Mandolin courses in explanations: ஜோடிகள், with கோர்ஸ் explained once. Bow slur: ஸ்லர். Fingerboard tapes: நாடாக்கள்.
- Additional lesson terms: blues ப்ளூஸ்; bluegrass ப்ளூகிராஸ்; tonal home ஆதாரம் / ஆதாரச் சுரம்; pickup முன்எடுப்பு (notes before a full bar); chop சாப் as the named short muted mandolin/reggae technique, explained as அடக்கிய ஸ்ட்ரோக் or குறுகிய அடக்கிய கார்டு. A rest is இடைநிறுத்தம்; slur ஸ்லர்; tie இணைப்பு.

## Independent Tamil terminology decisions

Independent AI recommendations integrated with the reviewed lesson baseline. Not native-speaker or human certification.

| Topic | Recommended clarification | Evidence |
|---|---|---|
| Long/short durations | Use நீண்டது / குறுகியது in spoken duration patterns; நீண்ட / குறுகிய adjectivally. Do not use குறுக்கம் for “short.” Preserve the order/grouping of durations. | 002s019; 005s068/s071/s073; 008s026; 011s006; 021s092; 023s012/s030/s031; 024s035/s057/s060 |
| Duration versus pitch | Keep the existing distinction: முழு/அரை/கால்/எட்டாம் நோட்டு are rhythmic values; அரை சுரம் / முழு சுரம் describe pitch steps. “Long” does not mean a higher pitch, and “short” does not mean lower. | Bowing, dotted-note and bass-groove lessons |
| Spoken `and` versus conjunction | Keep existing அண்ட் for a spoken offbeat, மற்றும் for an ordinary list. Review all contexts of source-hashed labels. Do not force one target if the same key serves both. | 019s015 Lf6586312d9; resolved by the separately guarded source-context split |
| Transitive instructions | Use அமைக்கவும்/அமையுங்கள் according to subject/object; fingers are வளைத்துப் பிடியுங்கள், a hand/string is அசைக்கவும், a body/finger is சாய்த்துவையுங்கள். Move the finger with நகர்த்துங்கள், not a player-directed வழுக்குங்கள். Preserve polite instruction register. | 002s061/s087; 005s064; 014s039; 025s095; 027s050/s053/s077 |
| Shift destinations | “Up to D” means மேலே D வரை, not D-க்கு மேலே (“above D”). Preserve endpoint and direction separately. | 027s053/s077 |
| Bow length and weight | Bow instrument is வில்; a longer/quick bow action is a வில் இழுப்பு. “Heavy bow” in tone production means using arm weight, not choosing a heavier bow. | 023s006; 027s009/s029/s040/s089 |
| Sympathetic resonance | In the stopped-note/open-string comparisons, “ring” is ஒத்ததிர்வு, not எதிரொலி (echo). The nearby explanation that the open string vibrates along supplies the meaning. Do not globally replace every English “ring.” | 023s070/s072; 024s005/s018; 026s082 |
| Outline chords | For a bass/melody line expressing harmony through chord tones, use கார்டுகளை உணர்த்துங்கள் rather than an instruction to draw an outline. | 020s084; 021s025/s026; 030s022 |
| Same | A shared ear-test answer spanning both individual notes and chords needs a generic form such as ஒன்றே. Avoid numeral ஒன்று or a note-only wording. | 009s013 and its 24 exact curriculum uses |
| Original spans | Retain the existing Latin-initial mnemonic rule and original sung-word locator rule, but only the relevant spans. Translate surrounding teaching prose. | preserved-fragments.json, 10 exact guarded rows |
| Titles and credits | Keep exact source-bound decisions, not a whole-English-prose exception. Song titles, author names/dates and literal notation are reviewed individually. Translate instructional subtitles and connective credit wording. | invariants.json: 94 exact rows |

These are contextual decisions, not automatic source-wide replacements. “Bridge” is context-sensitive, but the existing loan பிரிட்ஜ் can serve both the instrument part and song section; the shared first-half key does not require a forced split. “Rest” may be a compact label or prose instruction; avoid mechanical substitutions based only on a glossary headword.


## Separated source contexts — 6,082-key source

The two source edits separate string enumeration from spoken rhythm, and a middle finger from a musical section. Use only the exact context below:

| English source | Context | Translation |
|---|---|---|
| Strings: 1, 2, 3 and 4 | Ukulele string-number distractor | தந்திகள்: 1, 2, 3 மற்றும் 4 |
| Middle section | Musical section, six arrangements | நடுப்பகுதி |
| 1, 2, 3 and 4 | Spoken rhythm distractor | 1, 2, 3 அண்ட் 4 |
| Middle | Middle finger, three banjo options | நடுவிரல் |

The 6,080-pair baseline review and the four-key context delta are distinct independent AI reviews, not a new blanket review or human/native certification of 6,082 pairs. The exact source-bound invariant decisions are now registered; author drafting notes above describe their historical hold. Runtime layout, RTL where relevant, audio and VoiceOver QA remain pending. Previously reviewed UI haptic wording is preserved.
