# Urdu (ur) glossary

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | ur — Urdu |  |
| Variant | Standard Urdu, Perso-Arabic script, Pakistan |  |
| Register ("you") | Polite آپ; warm direct teacher voice |  |
| Imperatives and buttons | Polite کریں، بجائیں; compact noun labels |  |
| Readers of unknown gender | Neutral constructions and respectful plural; no gender assumptions |  |
| Quotation marks | “…”; Urdu full stop ۔, comma ،, question mark ؟ |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Normal Urdu spacing; preserve necessary ZWNJ. Begin strings in Urdu; if brand/argument must lead use U+200F. Isolate Latin placeholders touching punctuation with U+2068/U+2069; document marks in batch notes |  |
| Digits in literal numbers | ASCII 0–9 in literals; runtime numbers follow device |  |
| Units | سینٹس؛ منٹ؛ سیکنڈ؛ ملی سیکنڈ. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No case; preserve brand spelling |  |
| Note names in the interface | Runtime supplies notes; never invent names |  |
| Note names in lessons (lesson languages only) | Lessons are required; preserve C, F♯, B♭, Em, G7 if referenced |  |
| Sharp / flat / double sharp / double flat as words | شارپ / فلیٹ / ڈبل شارپ / ڈبل فلیٹ |  |
| Tuning direction | نیچے / اوپر for tuner direction; not accidentals |  |
| iOS Settings path (legal text) | سیٹنگز › Apple اکاؤنٹ › سبسکرپشنز. AI-reviewed; device verification pending |  |
| Apple feature names | ہوم اسکرین / لاک اسکرین / ویجٹ / لائیو ایکٹیویٹی / شارٹ کٹس / کنٹرول سینٹر / فیملی شیئرنگ; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: گٹار، باس، یوکولیلے، وائلن، چیلو، ستار، تانپورہ | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | معیاری | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | ٹیون | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | سیکھیں | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | گانے | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | پریکٹس | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | پیش رفت | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | سیٹنگز | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | آج | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | ہدف | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | آپ کے گانے |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | گانے کی شیٹ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | کورڈ چارٹ / بجانے والے کا منظر | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | کورڈ کا منظر / نیک کا منظر |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | دکھائیں | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | ٹیون کرنے کے لیے اسٹرم کریں |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | ارتعاش سے ٹیون کریں / ارتعاش | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | عین نشانہ | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | کان کی تربیت |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | مسلسل سُر | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | تانپورہ |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | سُر کی درستگی — مسلسل سُر کے ساتھ سُر میں بجانا؛ not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | میٹرونوم / اسپیڈ ٹرینر |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | کورڈز / اسکیلز |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | سطح کی جانچ |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | ساتھ بجائیں | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | آخری ٹیک؛ ٹیک = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | لوپ A–B / A مقرر کریں / B مقرر کریں | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | ابتدائی / معیاری / ماہر | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | اسٹوڈیو (ہلکا) / ریئل ٹائم 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | ہیپٹکس | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ٹیونر |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | ساز ٹیون کریں |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ٹیوننگ | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | ٹیون میں | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | نیچے / اوپر | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | سینٹس | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | سُر ملنے کی تصدیق؛ not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | تار |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | کھونٹی / ہیڈ اسٹاک |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | حوالہ سُر / حوالہ پچ / کنسرٹ پچ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | لکھا ہوا سُر / ٹیمپرامنٹ |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | کرومیٹک / اسٹروب |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | کیپو |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | سُر بدلیں / سُر کی تبدیلی |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | نوٹ کے نام / سولفیج / سرگم |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | فریٹ / کھلا تار | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | انگلی 1–4؛ 1 شہادت، 2 درمیانی، 3 انگوٹھی، 4 چھوٹی؛ 0 کھلا | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | کورڈ / کورڈ کی شکل / بارے کورڈ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | میجر / مائنر / سیونتھ / پاور کورڈ | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | کی (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | اسکیل / میجر اسکیل / پینٹاٹونک پیٹرن | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | آدھا سُر / پورا سُر / سُروں کا وقفہ / تیسرا / پانچواں / آکٹیو |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | بار |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | تال / ٹیمپو / پہلا تال / گنتی |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | اسٹرم / نیچے کا اسٹروک / اوپر کا اسٹروک / دبا اسٹروک / دبا اسٹروک / میوٹ | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | پک (plectrum)؛ چنیں (choose)؛ تار چھیڑیں (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | فنگر پکنگ / ہیمر آن / پل آف / سلائیڈ / بینڈ / وائبراٹو | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | گز سے بجانا / کھلے تار پر گز چلانا |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | دھن | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | کیڈنس / V کورڈ / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | پہلے پورے بار سے پہلے کے سُر |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | آغاز / انترا 1 / مکھڑا / برج / سولو / اختتام / ٹیگ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | حصہ |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | سلسلہ | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | سلسلے کا تحفظ |  |
| best run | The longest streak so far | Progress | `best run` | بہترین سلسلہ | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | بیج / کامیابی |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | سطح / ستارے / XP / کومبو / اسکور / راؤنڈ |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | دوست کو چیلنج دیں |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | چیلنج | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | کورس / یونٹ / سبق / مرحلہ |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | کوئز / اشارہ |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | سبسکرپشن / تجدید / منسوخ کریں | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | مفت ٹرائل / ٹرائل ختم ہوتا ہے |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | سالانہ / ماہانہ / تاحیات |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | خریداری بحال کریں |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | ادائیگی کا طریقہ / بلنگ کا مسئلہ |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | شرائط / رازداری کی پالیسی | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | گٹار / یوکولیلے / باس / وائلن / چیلو / مینڈولن / بینجو | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | کان کی تربیت / موسیقی کا نظریہ / لے / گائیکی |  |
| Songs | Course title, also the Songs tab | گانے |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | اصل گانے | Keep or translate: decide once. |
| Standards & Classics | Course title | معروف اور کلاسیکی گانے |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | یوکولیلے / مینڈولن / وائلن / چیلو / باس گانوں کی کتاب | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

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
| Tune | to tune (verb, tab); in lessons also a melody | — | ٹیون (verb/tab)؛ دھن (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | شارپ / فلیٹ (accidentals)؛ اوپر / نیچے (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | بار | a UI bar, a pub |
| key | tonality | a piano key, a password key | کی (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | پک (plectrum)؛ چنیں (choose)؛ تار چھیڑیں (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | سُر ملنے کی تصدیق | a padlock |
| take | one recorded attempt | "take a lesson" | ٹیک (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | سلسلہ (streak)؛ مکمل کوشش (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | کورڈ چارٹ (music)؛ چارٹ (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | سُر کی درستگی — مسلسل سُر کے ساتھ سُر میں بجانا؛ not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | اگلا / دوبارہ / آہستہ | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | پریکٹس | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | ارتعاش محسوس کریں (haptics; not emotion) | emotions |

## 5. Lesson-draft decisions (direct GPT pass, 2026-10-26)

These decisions are AI-reviewed only; no native-speaker certification or device QA is claimed.

- Keep exact note/chord notation, fingering letters (`p`, `i`, `m`, `a`), roman-numeral progressions, strumming-letter notation and original song/author names when the whole source is such an invariant. They remain unmerged until an independent per-key semantic review approves them; do not add bidi marks or filler merely to evade identity checks.
- In prose, lead with natural Urdu words (`نوٹ`, `کورڈ`, `کی`, `اسکیل`, `گانا`, `دھن`) when that fits, to establish RTL direction. No extra meaning is implied by those classifiers. Exact standalone invariants retain source spelling.
- English acrostics used to remember literal Latin note letters are quoted **teaching examples**, not untranslated instruction or placeholders: `Every Amateur Does Get Better Eventually`, `Good Cooks Eat Apples`, `Every Amp Drives Grooves`, `Good Dogs Always Eat`, `Cats Go Dancing Around`. Keep the acrostic in quotes within Urdu instruction, with Urdu meaning where room allows; a literal Urdu replacement alone would lose the mnemonic's initial letters. Original lyric fragments identifying a passage are likewise retained within Urdu instruction.
- Solfège instructional syllables: do = دو, re = رے, mi = می, fa = فا, sol = سول, la = لا, ti = ٹی. Actual Latin note names (`C`, `D`, etc.) remain Latin, never converted to solfège.
- Interval terms: minor/major second = مائنر/میجر دوسرا وقفہ; third = تیسرا وقفہ; sixth = چھٹا وقفہ; perfect fourth/fifth = پرفیکٹ چوتھا/پانچواں; unison = ہم آواز. Root = بنیادی نوٹ; home note = بنیادی/مرکزی نوٹ; tonic = ٹونک.
- Triad = ترائیڈ; inversion = الٹ ترتیب; arpeggio = آرپیجیو; common tone = مشترک سُر; diminished = ڈِمنشڈ; augmented = آگمنٹڈ; dominant seventh = ڈومیننٹ سیونتھ; mode = موڈ; Dorian = ڈورین; Mixolydian = مکسولیڈین; pentatonic box = پینٹاٹونک پیٹرن.
- Hook = مرکزی دھن; riff = رِف; lick = فقرہ; fill = فِل; arrangement = ترتیب; texture = صوتی بناوٹ; comping = کورڈ سنگت; walking bass = واکنگ باس / چلتی باس دھن; shuffle = شفل; swing = سوئنگ / جھول by context; syncopation = سنکوپیشن; tremolo = ٹریملو; trill = ٹرل.
- Bow = گز; frog = دستہ; tip = سرا; fingerboard = فنگر بورڈ; scroll = بل دار سرا; rosin = روزن; pizzicato = پزیکاٹو; slur = سلر; endpin = اینڈ پن; position/shift = پوزیشن / پوزیشن بدلنا; high/low second finger = اونچی/نیچی 2 when the source uses the digit. Cello first-position spacing is one finger per half step, not violin fingering.
- Mandolin string pair/course = جوڑا (technical introductory term کورس); pick = پک; chop = چاپ; chunk = چنک. Banjo roll = رول; forward roll = فارورڈ رول; pinch = پنچ; clawhammer = کلا ہیمر; bum-ditty = بم ڈِٹی (بم، ڈِٹ، ٹی). These are instrument-technique terms, not untranslated prose.
- Rhythm-duration terms follow the earlier lesson drafts: whole note = پورا نوٹ, half note = نصف نوٹ, quarter note = چوتھائی نوٹ, eighth note = آٹھواں نوٹ (plural/oblique آٹھویں نوٹ), sixteenth note = سولہواں نوٹ (plural/oblique سولہویں نوٹ). Rest = وقفہ / وقفۂ خاموشی; tie = ٹائی; dot/dotted = نقطہ / نقطے والا; triplet = ٹرپلٹ. A half cadence is the separate harmony term ہاف کیڈنس, not a half-note duration.
- Staff = اسٹاف; treble/bass clef = ٹریبل/باس کلیف; ledger lines = اضافی لکیریں; key signature = کی سگنیچر; time signature = ٹائم سگنیچر; meter = میٹر. Keyboard keys are چابیاں/کنجیاں, never the tonality term کی.
- Additional letter-name mnemonics remain quoted inside Urdu instruction: `Every Good Boy Does Fine`, `Good Boys Do Fine Always`, `All Cows Eat Grass`, and `FACE`. Their initials are the teaching content; an Urdu-only replacement would break the note mapping.
- Cadence types: authentic = آتھنٹک, plagal = پلیگل, half = ہاف, deceptive = ڈیسیپٹو. Dynamics = ڈائنامکس / آواز کی بلندی; sustain = سُر قائم رکھنا; pitch matching = سُر ملانا; lip trill = ہونٹوں کا ٹرل. Breath-energy instructions do not mean squeezing or forcing the throat.
- Descriptive numbered classical work titles may translate their descriptor while preserving the identifying number: `Mozart's Symphony No. 40` = موزارٹ کی سمفنی نمبر 40; `Symphony No. 40` = سمفنی نمبر 40. Keep the same localized descriptor in explanatory prose. This is distinct from lexical original song titles, which retain their original spelling under the rule above.

## Independent review checkpoint (2026-10-26)

The 6,080-key baseline received independent AI source/context review, including 186 guarded corrections and 305 source-bound identity decisions. Targeted Unicode isolates are limited to sequences whose display ordering was reviewed; ordinary prose is not blanket-wrapped. Shared count/list and finger/section source context repairs remain tracked separately. This is not native-reader or device-rendering certification.
