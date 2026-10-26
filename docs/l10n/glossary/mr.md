# Marathi (mr) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | mr — Marathi |  |
| Variant | Standard Marathi, Maharashtra |  |
| Register ("you") | Polite तुम्ही; warm direct voice |  |
| Imperatives and buttons | Polite करा, वाजवा; concise noun labels |  |
| Readers of unknown gender | Neutral imperatives; avoid gendered reader assumptions |  |
| Quotation marks | “…”; full stop . as existing table |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Ordinary word spaces; retain script joiners where needed |  |
| Digits in literal numbers | ASCII 0–9 in new literals; runtime numbers follow device |  |
| Units | सेंट्स; मिनिटे; सेकंद; मिलिसेकंद. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies notes; do not invent them |  |
| Note names in lessons (lesson languages only) | Lessons are required; retain C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | शार्प / फ्लॅट / डबल शार्प / डबल फ्लॅट |  |
| Tuning direction | कमी / जास्त for tuner direction; not accidentals |  |
| iOS Settings path (legal text) | सेटिंग्ज › Apple खाते › सदस्यता. AI-reviewed; device verification pending |  |
| Apple feature names | होम स्क्रीन / लॉक स्क्रीन / विजेट / लाइव्ह ॲक्टिव्हिटी / शॉर्टकट / कंट्रोल सेंटर / फॅमिली शेअरिंग; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: गिटार, बास, युकुलेले, व्हायोलिन, चेलो, सतार, तानपुरा | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | स्टँडर्ड | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ट्यून करा | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | शिका | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | गाणी | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | सराव | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | प्रगती | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | सेटिंग्ज | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | आज | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | ध्येय | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | तुमची गाणी |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | गाण्याची शीट |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | कॉर्ड चार्ट / वादक दृश्य | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | कॉर्ड दृश्य / नेक दृश्य |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | दाखवा | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ट्यून करण्यासाठी स्ट्रम करा |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | कंपनांनी ट्यून करा / कंपन | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | अचूक नेम | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | कानाचा सराव |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | आधार स्वर | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | तानपुरा |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | इंटोनेशन — आधार स्वरासोबत सुरात वाजवणे; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | मेट्रोनोम / स्पीड ट्रेनर |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | कॉर्ड्स / स्केल्स |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | पातळी तपासणी |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | सोबत वाजवा | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | अंतिम टेक; टेक = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | लूप A–B / A सेट करा / B सेट करा | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | नवशिके / स्टँडर्ड / तज्ज्ञ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | स्टुडिओ (हलके) / रिअल-टाइम 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | हॅप्टिक्स | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ट्यूनर |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ट्यून-अप |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ट्यूनिंग | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | सुरात | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | कमी / जास्त | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | सेंट्स | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | सूर जुळल्याची पुष्टी; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | तार |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | खुंटी / हेडस्टॉक |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | संदर्भ स्वर / संदर्भ पिच / कॉन्सर्ट पिच |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | लिखित स्वर / टेम्परामेंट |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | क्रोमॅटिक / स्ट्रोब |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | कॅपो |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | सूर बदला / सूरबदल |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | स्वरांची नावे / सॉल्फेज / सरगम |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | फ्रेट / मोकळी तार | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | बोट 1–4; 1 तर्जनी, 2 मधले बोट, 3 अनामिका, 4 करंगळी; 0 मोकळी तार | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | कॉर्ड / कॉर्डचा आकार / बारे कॉर्ड |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | मेजर / मायनर / सेव्हन्थ / पॉवर कॉर्ड | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | की (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | स्केल / मेजर स्केल / पेंटाटोनिक पॅटर्न | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | अर्धा स्वर / पूर्ण स्वर / स्वरांतर / तृतीय / पंचम / सप्तक |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | बार |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ठेका / टेम्पो / पहिला ठेका / मोजणी |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | स्ट्रम / खालचा स्ट्रोक / वरचा स्ट्रोक / तुटक स्ट्रोक / चंक (नाद लगेच थांबवणारा स्ट्रम) / म्यूट | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | पिक (plectrum); निवडा (choose); तार वाजवा (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | फिंगरपिकिंग / हॅमर-ऑन / पुल-ऑफ / स्लाइड / बेंड / व्हायब्रेटो | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | बोने वाजवणे / मोकळ्या तारेवर बो फिरवणे |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | चाल | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | कॅडन्स / V कॉर्ड / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | पहिल्या पूर्ण बारच्या आधीचे स्वर |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | सुरुवात / अंतरा 1 / मुखडा / ब्रिज / सोलो / शेवट / टॅग | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | भाग |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | सलग सराव | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | सलग सरावाचे संरक्षण |  |
| best run | The longest streak so far | Progress | `best run` | सर्वाधिक सलग | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | बॅज / कामगिरी |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | पातळी / तारे / XP / कॉम्बो / स्कोअर / फेरी |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | मित्राला आव्हान द्या |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | आव्हान | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | अभ्यासक्रम / घटक / धडा / पायरी |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | प्रश्नमंजूषा / संकेत |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | सदस्यता / नूतनीकरण / रद्द करा | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | मोफत ट्रायल / ट्रायल संपते |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | वार्षिक / मासिक / आजीवन |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | खरेदी रिस्टोअर करा |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | पेमेंट पद्धत / बिलिंगची अडचण |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | अटी / गोपनीयता धोरण | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | गिटार / युकुलेले / बास / व्हायोलिन / चेलो / मँडोलिन / बँजो | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | कानाचा सराव / संगीत सिद्धांत / लय / गायन |  |
| Songs | Course title, also the Songs tab | गाणी |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | मौलिक गाणी | Keep or translate: decide once. |
| Standards & Classics | Course title | प्रचलित आणि अभिजात गाणी |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | युकुलेले / मँडोलिन / व्हायोलिन / चेलो / बास गाण्यांचे पुस्तक | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ट्यून करा (verb/tab); चाल (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | शार्प / फ्लॅट (accidentals); जास्त / कमी (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | बार | a UI bar, a pub |
| key | tonality | a piano key, a password key | की (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | पिक (plectrum); निवडा (choose); तार वाजवा (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | सूर जुळल्याची पुष्टी | a padlock |
| take | one recorded attempt | "take a lesson" | टेक (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | सलग सराव (streak); पूर्ण प्रयत्न (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | कॉर्ड चार्ट (music); चार्ट (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | इंटोनेशन — आधार स्वरासोबत सुरात वाजवणे; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | पुढे / पुन्हा / हळू | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | सराव | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | कंपन अनुभवा (haptics; not emotion) | emotions |

## 5. Lesson-drafting clarifications (AI draft, 2026-10-26)

- Rhythmic durations: whole/half/quarter/eighth/sixteenth note = होल/हाफ/क्वार्टर/एट्थ/सिक्स्टीन्थ नोट. These are durations, not pitch intervals. Interval degrees use तृतीय, चतुर्थ, पंचम, षष्ठ, सप्तम, नवम; major/minor qualities remain मेजर/मायनर.
- Steady beat/tempo means एकसारखी लय/गती, not a motionless hand. A physically still hand can be स्थिर; keep a strumming hand moving when the instruction says so.
- High/low pitch is उंच/खालचा स्वर. Thick/thin strings are जाड/पातळ तारा; never infer their physical location from pitch words. “Top strings” in these guitar voicings means the thin, higher-pitched strings.
- Timed counting uses pronounceable short अन् for the English subdivision syllable “and”: एक-अन्-दोन-अन्; sixteenths एक-इ-अन्-अ. Explanatory prose may name the “आणि” subdivision. Preserve ASCII numbers where the source uses digits.
- English initial-letter mnemonics stay as examples introduced by Marathi prose; do not invent Marathi initials that fail to match the note letters. Original sung words stay unchanged only as quoted lyric examples, with surrounding instruction translated.
- Standard song names without a verified established Marathi title are kept in their original spelling consistently; all descriptive title additions and prose are Marathi. Bare original names, credits and notation are identity candidates for separate independent semantic review, not automatic coverage claims.
- Keyboard key = पट्टी; tonal key = की. Triad = त्रिस्वरी कॉर्ड; inversion = इन्व्हर्जन; root = मूळ स्वर; pentatonic box = पेंटाटोनिक पॅटर्न. Roman chord numerals and literal fingering letters p, i, m, a stay unchanged.
- Shared counts/list labels and ambiguous Middle finger/section keys require the parent context-split migration; do not make one context-specific wording silently serve incompatible uses.
- Unison = युनिसन (two sounds at exactly the same pitch), not a label for monophonic texture. When explaining the English word “octave” via eight letters, name the English word explicitly: Marathi सप्तक must not be given that false etymology.
- Rhythmic dot/dotted = बिंदू / बिंदूयुक्त; a dot lengthens a note by half its value. Six-eight = सहा-आठ तालमाप; its six subdivision counts are not six large beats. Whole/half steps are पूर्ण स्वर / अर्धा स्वर distances, not rhythmic note values.
- Spoken rhythm examples can use ता, ति-ति for long/short-short; triplets use 1-ता-कि, with swing on 1 and कि. Keep the beat count and subdivision timing intact.
- Reggae chop = तुटक स्ट्रोक, describing a short, clipped articulation, not increased fretting pressure. Cello “heavy bow” means adding weight to the stroke, not choosing a heavier bow.
- Interlude (song section) = मध्यवादन; carol = कॅरोल; medley = गीतगुंफण. Dynamics piano/forte are सौम्य आवाज / मोठा आवाज (पियानो / फोर्ते), not the piano instrument.
