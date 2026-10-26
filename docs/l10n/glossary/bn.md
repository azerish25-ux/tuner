# Bengali (bn) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Status: AI-reviewed translation decisions, not human-reviewed or native-speaker approved. Device QA pending.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | bn — Bengali |  |
| Variant | Standard Bengali, shared India/Bangladesh wording |  |
| Register ("you") | Polite আপনি; warm and direct |  |
| Imperatives and buttons | Polite করুন, বাজান; short noun labels |  |
| Readers of unknown gender | Neutral constructions, no reader-gender assumptions |  |
| Quotation marks | “…”; sentence-final । |  |
| Apostrophe and ellipsis | Typographic apostrophe ’; single ellipsis … |  |
| Spaces | Ordinary word spaces; preserve necessary script joiners |  |
| Digits in literal numbers | ASCII 0–9 in new literals; runtime numbers follow device |  |
| Units | সেন্ট; মিনিট; সেকেন্ড; মিলিসেকেন্ড. Hz, BPM, ¢, XP unchanged |  |
| Capitalization | No letter case; brands retain spelling |  |
| Note names in the interface | Notes supplied by runtime; never invent note names |  |
| Note names in lessons (lesson languages only) | Lessons are required; retain C, F♯, B♭, Em, G7 when referenced |  |
| Sharp / flat / double sharp / double flat as words | শার্প / ফ্ল্যাট / ডাবল শার্প / ডাবল ফ্ল্যাট |  |
| Tuning direction | নিচু / উঁচু; not accidentals |  |
| iOS Settings path (legal text) | সেটিংস › Apple অ্যাকাউন্ট › সাবস্ক্রিপশন. AI-reviewed; device verification pending |  |
| Apple feature names | হোম স্ক্রিন / লক স্ক্রিন / উইজেট / লাইভ অ্যাক্টিভিটি / শর্টকাট / কন্ট্রোল সেন্টার / ফ্যামিলি শেয়ারিং; Siri, Apple Watch, Game Center unchanged; device verification pending |  |
| Siri phrases | Polite imperatives; preserve ${applicationName} and all other tokens |  |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Use existing timbre_catalog_* entries: গিটার, বেস, ইউকুলেলে, বেহালা, চেলো, সেতার, তানপুরা | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | স্ট্যান্ডার্ড | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | টিউন করুন | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | শিখুন | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | গান | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | অনুশীলন | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | অগ্রগতি | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | সেটিংস | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | আজ | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | লক্ষ্য | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | আপনার গান |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | গানের শিট |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | কর্ড চার্ট / বাদকের দৃশ্য | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | কর্ড দৃশ্য / নেক দৃশ্য |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | দেখান | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | টিউন করতে স্ট্রাম করুন |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | কম্পন অনুভব করে টিউন করুন / কম্পন | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | নিখুঁত নিশানা | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | কানের তালিম |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | টানা সুর | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | তানপুরা |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | ইন্টোনেশন — টানা সুরের সঙ্গে সুরে বাজানো; not saddle adjustment | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | মেট্রোনোম / স্পিড ট্রেনার |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | কর্ড / স্কেল |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | দক্ষতা যাচাই |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | সাথে বাজান | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | শেষ টেক; টেক = recorded attempt | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | লুপ A–B / A সেট করুন / B সেট করুন | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | শিক্ষানবিশ / স্ট্যান্ডার্ড / বিশেষজ্ঞ | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | স্টুডিও (হালকা) / রিয়েল-টাইম 3D |  |
| Haptics | Vibration feedback | Settings | `Haptics` | হ্যাপটিক্স | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | টিউনার |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | টিউন-আপ |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | টিউনিং | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | সুরে আছে | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | নিচু / উঁচু | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | সেন্ট | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | সুর মেলার নিশ্চিত সংকেত; not a padlock | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | তার |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | পেগ / হেডস্টক |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | রেফারেন্স স্বর / রেফারেন্স পিচ / কনসার্ট পিচ |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | লিখিত স্বর / টেম্পারামেন্ট |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | ক্রোমাটিক / স্ট্রোব |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | ক্যাপো |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | সুর বদলান / সুর পরিবর্তন |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | নোটের নাম / সোলফেজ / সরগম |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | ফ্রেট / খোলা তার | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | আঙুল 1–4; 1 তর্জনী, 2 মধ্যমা, 3 অনামিকা, 4 কনিষ্ঠা; 0 খোলা | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | কর্ড / কর্ডের আকৃতি / বারে কর্ড |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | মেজর / মাইনর / সেভেন্থ / পাওয়ার কর্ড | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | কী (tonality) |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | স্কেল / মেজর স্কেল / পেন্টাটোনিক প্যাটার্ন | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | অর্ধস্বর / পূর্ণস্বর / স্বরান্তর / তৃতীয় / পঞ্চম / অক্টেভ |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | বার |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | বিট / টেম্পো / প্রথম বিট / গণনা |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | স্ট্রাম / নিচের স্ট্রোক / ওপরের স্ট্রোক / চাপা স্ট্রোক / চাপা স্ট্রোক / মিউট | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | পিক (plectrum); বেছে নিন (choose); তার বাজান (picking) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | ফিঙ্গারপিকিং / হ্যামার-অন / পুল-অফ / স্লাইড / বেন্ড / ভাইব্রাটো | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | ছড় দিয়ে বাজানো / খোলা তারে ছড় চালানো |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | সুর | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | ক্যাডেন্স / V কর্ড / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | পিকআপ; প্রথম পূর্ণ বারের আগের স্বর | Teach পিকআপ with its Bengali definition at first use. Keep the term, not its answer-giving definition, in a definition quiz. |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | শুরু / স্তবক 1 / কোরাস / ব্রিজ / সোলো / শেষ / ট্যাগ | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | অংশ |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | ধারা | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | ধারা রক্ষা |  |
| best run | The longest streak so far | Progress | `best run` | সেরা ধারা | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | ব্যাজ / কৃতিত্ব |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | স্তর / তারা / XP / কম্বো / স্কোর / রাউন্ড |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | বন্ধুকে চ্যালেঞ্জ করুন |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | চ্যালেঞ্জ | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | কোর্স / ইউনিট / পাঠ / ধাপ |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | কুইজ / ইঙ্গিত |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | সাবস্ক্রিপশন / নবায়ন / বাতিল করুন | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | ফ্রি ট্রায়াল / ট্রায়াল শেষ হয় |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | বার্ষিক / মাসিক / আজীবন |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | কেনাকাটা পুনরুদ্ধার করুন |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | পেমেন্ট পদ্ধতি / বিলিং সমস্যা |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | শর্তাবলি / গোপনীয়তা নীতি | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | গিটার / ইউকুলেলে / বেস / বেহালা / চেলো / ম্যান্ডোলিন / ব্যাঞ্জো | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | কানের তালিম / সংগীততত্ত্ব / ছন্দ / গান গাওয়া |  |
| Songs | Course title, also the Songs tab | গান |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | মৌলিক গান | Keep or translate: decide once. |
| Standards & Classics | Course title | প্রচলিত ও ক্লাসিক গান |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | ইউকুলেলে / ম্যান্ডোলিন / বেহালা / চেলো / বেস গানের খাতা | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

Song titles, the rule for this locale (fill one line each):

- All lesson prose and descriptive title text is Bengali; no English fallback counts as translated. Polite আপনি, warm direct teacher voice. Keep ASCII digits, literal notation, note/chord letters, brands and original sung lyrics exactly. Translate credit connectors, retaining names and years.
- Established Bengali song names may be used when known; otherwise use a clear stable Bengali translation or Bengali transliteration, without claiming an established local title. Proper names may remain original. Originals receive Bengali titles, reused verbatim in prose. Qualifiers (three notes, melody, chords, arrangement) are translated.
- Initial binding title map (extend before translating each new title):

| English | Bengali |
|---|---|
| Boil Them Cabbage Down | বাঁধাকপি সেদ্ধ করুন |
| Minuet in G | G-তে মিনুয়েট |
| Old Joe Clark | বুড়ো জো ক্লার্ক |
| Soldier's Joy | সৈনিকের আনন্দ |
| Arkansas Traveler | আরকানসাসের পথিক |
| The Swan | রাজহাঁস |
| Brahms' Lullaby | ব্রাহমসের ঘুমপাড়ানি গান |
| Au clair de la lune | চাঁদের আলোয় |
| The Carnival of the Animals | প্রাণীদের উৎসব |
| Angeline the Baker | রুটির কারিগর অ্যাঞ্জেলিন |
| Cripple Creek | ক্রিপল ক্রিক |
| Cumberland Gap | কাম্বারল্যান্ড গিরিপথ |
| Shady Grove | ছায়াঘেরা বন |
| Skip to My Lou | লাফিয়ে লুর কাছে |
| Jingle Bells | ঝনঝন ঘণ্টা |
| Take Me Out to the Ball Game | আমাকে বলখেলায় নিয়ে চলো |
| My Bonnie Lies Over the Ocean | আমার বনি সাগরের ওপারে |
| The Entertainer | বিনোদনদাতা |
| Frère Jacques | ভাই জাক |
| Für Elise | এলিজের জন্য |
| Auld Lang Syne | অল্ড ল্যাং সাইন |
| Shenandoah | শেনানডোয়া |
| Yankee Doodle | ইয়াঙ্কি ডুডল |
| The alphabet song | বর্ণমালার গান |
| Baa, Baa, Black Sheep | বা, বা, কালো ভেড়া |
| One Horse Open Sleigh | এক ঘোড়ার খোলা স্লেজ |
| Old MacDonald Had a Farm | বুড়ো ম্যাকডোনাল্ডের খামার |
| Love Me Tender | লাভ মি টেন্ডার |
| Bobby Shafto | ববি শ্যাফটো |
| Canon in D | D-তে ক্যানন |
| Largo, New World Symphony | লার্গো, নতুন জগতের সিম্ফনি |
| From the New World | নতুন জগৎ থেকে |
| In the Hall of the Mountain King | পাহাড়ের রাজার সভায় |
| Peer Gynt | পিয়ার গিন্ট |
| My Country, 'Tis of Thee | আমার দেশ, তোমারই গান |
| God Save the King | ঈশ্বর রাজাকে রক্ষা করুন |
| Simple Gifts | সহজ উপহার |
| Appalachian Spring | অ্যাপালাচিয়ার বসন্ত |
| Good King Wenceslas | সৎ রাজা ওয়েনসেসলাস |
| Deck the Halls | হলঘর সাজাও |
| Nos Galan | নস গালান |
| We Wish You a Merry Christmas | আনন্দময় বড়দিনের শুভেচ্ছা |
| Silent Night | নীরব রাত |
| Messiah | মেসায়া |
| Eine kleine Nachtmusik | রাতের ছোট্ট সংগীত |
| The Merry Wives of Windsor | উইন্ডসরের হাসিখুশি গৃহিণীরা |
| Danny Boy (Londonderry Air) | ড্যানি বয় (লন্ডনডেরির সুর) |
| Danny Boy | ড্যানি বয় |
| Mozart's Symphony No. 40 | মোৎসার্টের 40 নম্বর সিম্ফনি |
| Moth and Ember | মথ ও অঙ্গার |
| First Frost | প্রথম তুষারপাত |
| Hammock Season | দোলনায় শোওয়ার মরসুম |
| Glow-in-the-Dark Stars | অন্ধকারে জ্বলা তারা |
| Echo Canyon | প্রতিধ্বনির গিরিখাত |
| Open Windows | খোলা জানালা |
| Scoreboard Lights | স্কোরবোর্ডের আলো |
| Carousel at Closing Time | বন্ধের সময় নাগরদোলা |
| Cedar Smoke | সিডার কাঠের ধোঁয়া |
| Rain on the Skylight | ছাদ-জানালায় বৃষ্টি |
| Pocket Change | পকেটের খুচরো |
| Kitchen Slow Dance | রান্নাঘরে ধীর নাচ |
| Houseplants | ঘরের গাছ |
| Static on Channel Nine | নয় নম্বর চ্যানেলে ঝিরঝির |
| Boardwalk Comet | কাঠের পথের ধূমকেতু |
| Mile Marker Zero | শূন্য মাইলফলক |
| Last Bell | শেষ ঘণ্টা |
| Copper Wire | তামার তার |
| Cold Lake | ঠান্ডা হ্রদ |
| Parking Lot Cathedral | পার্কিং মাঠের গির্জা |
| Keeper's Daughter | রক্ষকের মেয়ে |
| Snow Globe Town | স্নো গ্লোবের শহর |
| Thistle and Thread | কাঁটাফুল ও সুতো |
| Late Bus Home | বাড়ি ফেরার রাতের বাস |
| Velvet Hour | মখমলি প্রহর |
| Rooftop Choir | ছাদের গানের দল |
| Bright Side of the Block | পাড়ার উজ্জ্বল দিক |
| Over You Soon | শিগগিরই তোমায় ভুলব |
| Constellation Prize | নক্ষত্রমণ্ডলের পুরস্কার |
| She'll Be Coming 'Round the Mountain | পাহাড় ঘুরে সে আসবে |
| Loch Lomond | লখ লোমন্ড |
| All Through the Night / Ar Hyd y Nos | সারারাত |
| O Christmas Tree | ও বড়দিনের গাছ |
| O Come, All Ye Faithful / Adeste Fideles | এসো, সব বিশ্বাসী |
| The First Noel | প্রথম বড়দিন |
| Scotland the Brave | বীর স্কটল্যান্ড |
| Korobeiniki | কোরোবেইনিকি |
| The Blue Danube | নীল দানিয়ুব |
| Can-can | ক্যান-ক্যান |
| Orpheus in the Underworld | পাতালে অর্ফিয়ুস |
| The Liberty Bell | স্বাধীনতার ঘণ্টা |
| Carmen: Prelude | কারমেন: প্রিলিউড |
| Carmen | কারমেন |
| Toreador Song | ষাঁড়যোদ্ধার গান |
| Morning Mood | সকালের আবেশ |
| Hark! The Herald Angels Sing | শোনো! দূতেরা গাইছে |
| Away in a Manger | দূরে এক জাবনার পাত্রে |
| O Little Town of Bethlehem | ও বেথলেহেমের ছোট্ট শহর |
| It Came Upon the Midnight Clear | নির্মল মধ্যরাতে তা এসেছিল |
| Once in Royal David's City | একদা রাজা দাউদের নগরে |
| In the Bleak Midwinter | বিষণ্ণ শীতের মাঝে |
| The Holly and the Ivy | হলি ও আইভি |
| Angels from the Realms of Glory | মহিমার রাজ্যের স্বর্গদূত |
| O God, Our Help in Ages Past | হে ঈশ্বর, অতীত যুগের সহায় |
| St Anne | সেন্ট অ্যান |
| Holy, Holy, Holy | পবিত্র, পবিত্র, পবিত্র |
| Abide with Me | আমার সঙ্গে থাকো |
| Eventide | সাঁঝবেলা |
| Nearer, My God, to Thee | হে ঈশ্বর, তোমার আরও কাছে |
| For the Beauty of the Earth | পৃথিবীর সৌন্দর্যের জন্য |
| Dix | ডিক্স |
| Bethany | বেথানি |
| Nicaea | নাইসিয়া |
| Home! Sweet Home! | ঘর! মধুর ঘর! |
| Hard Times Come Again No More | দুঃসময় আর এসো না |
| The Last Rose of Summer | গ্রীষ্মের শেষ গোলাপ |
| Martha | মার্থা |
| Jupiter | বৃহস্পতি |
| The Planets | গ্রহমালা |
| Thaxted | থ্যাক্সটেড |
| Spring | বসন্ত |
| The Four Seasons | চার ঋতু |
| Rondo alla Turca | রোন্দো আল্লা তুর্কা |
| The Stars and Stripes Forever | তারা ও ডোরা চিরকাল |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | ইউকুলেলে / ম্যান্ডোলিন / বেহালা / চেলো / বেস গানের খাতা |
| Molly Malone | মলি ম্যালোন |
| The Skye Boat Song | স্কাইয়ের নৌকার গান |
| The Water Is Wide | বিস্তৃত জলরাশি |
| New Britain | নিউ ব্রিটেন |
| Red River Valley | রেড রিভার উপত্যকা |
| Aura Lee | অরা লি |
| Camptown Races | ক্যাম্পটাউনের দৌড় |
| Jukebox Moon | জুকবক্সের চাঁদ |
| Slow Motion Strobe | ধীরগতির স্ট্রোব |
| Market Day | হাটবার |
| Late Checkout | দেরিতে বিদায় |
| Joy to the World | বিশ্বজুড়ে আনন্দ |
| Lantern Hill | লণ্ঠন পাহাড় |
| Roller Rink | রোলার স্কেটিংয়ের মাঠ |
| Gravel Road Two-Step | নুড়িপথের টু-স্টেপ |
| Sparkler Season | ফুলঝুরির মরসুম |
| Saltwater Sunday | নোনাজলের রবিবার |
| Spray Paint Sunrise | স্প্রে রঙে সূর্যোদয় |
| Neon Laundromat | নিয়ন লন্ড্রি |
| Porchlight | বারান্দার আলো |
| Glass Satellites | কাচের উপগ্রহ |
| Rust Belt Shuffle | রাস্ট বেল্ট শাফল |
| Basement Weather | বেসমেন্টের আবহাওয়া |
| Clementine | ক্লেমেন্টাইন |
| Ghost Light | ভূতুড়ে আলো |
| Kite Weather | ঘুড়ি ওড়ার দিন |
| Halogen | হ্যালোজেন |
| Low Tide Radio | ভাটার রেডিও |
| Letters in a Shoebox | জুতোর বাক্সে চিঠি |
| Dust on the Dashboard | ড্যাশবোর্ডে ধুলো |
| Mary Had a Little Lamb | মেরির ছোট্ট ভেড়া |
| Ode to Joy | আনন্দগান |
| When the Saints Go Marching In | সাধুদের শোভাযাত্রা |
| Amazing Grace | অপার করুণা |
| Greensleeves | গ্রিনস্লিভস |
| Oh! Susanna | ওহ! সুজানা |
| Down by the Riverside | নদীর তীরে |
| Row, Row, Row Your Boat | বেয়ে চলুন নৌকা |
| Twinkle, Twinkle, Little Star / Twinkle Twinkle Little Star | ঝিকিমিকি ছোট্ট তারা |
| Lightly Row | আলতো করে বেয়ে চলুন |
| Songs | গান |
| Guitar / Ukulele / Bass / Violin / Cello / Mandolin / Banjo | গিটার / ইউকুলেলে / বেস / বেহালা / চেলো / ম্যান্ডোলিন / ব্যাঞ্জো |
| Voice / Ear Training / Music Theory / Rhythm | কণ্ঠ / কানের তালিম / সংগীততত্ত্ব / ছন্দ |
| Originals | মৌলিক গান |
| Standards & Classics | প্রচলিত ও ক্লাসিক গান |
| Songbook | গানের খাতা |

AI translation decisions only; independent AI review and native/device review remain distinct and pending.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | টিউন করুন (verb/tab); সুর (melody) | Use the sense above |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | শার্প / ফ্ল্যাট (accidentals); উঁচু / নিচু (direction) | pointed / level |
| bar | a measure | a UI bar, a pub | বার | a UI bar, a pub |
| key | tonality | a piano key, a password key | কী (tonality) | a piano key, a password key |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | পিক (plectrum); বেছে নিন (choose); তার বাজান (picking) | Use the sense above |
| lock | the string is held in tune | a padlock | সুর মেলার নিশ্চিত সংকেত | a padlock |
| take | one recorded attempt | "take a lesson" | টেক (recorded attempt) | "take a lesson" |
| run | a streak ("best run"), a clean run through a passage | running | ধারা (streak); পুরো প্রচেষ্টা (passage) | running |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | কর্ড চার্ট (music); চার্ট (statistics) | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | ইন্টোনেশন — টানা সুরের সঙ্গে সুরে বাজানো; not saddle adjustment | guitar setup octave adjustment |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | পরের / আবার / ধীরে | Use the sense above |
| Practice | the tab and the activity | a medical or legal practice | অনুশীলন | a medical or legal practice |
| Feel | the haptic tuning feature, feeling the beat | emotions | কম্পন অনুভব করুন (haptics; not emotion) | emotions |

## Independent contextual review decisions (2026-10-26)

AI review only, not human/native or device certification.

- **Latin-initial mnemonics**: Retain the precise English mnemonic inside Bengali teaching prose and explicitly tell the learner to take the first letter of each English word. Literal Bengali meaning alone loses the taught Latin note sequence. Standalone mnemonic headings can identify the sequence in Bengali. This is a contextual teaching exception, not permission to leave ordinary prose untranslated.
- **Sung lyric cues versus translated song titles**: Retain original sung words when the text maps lyric syllables to notes, even if those words also resemble a translated song title. Translate the accompanying musical instruction. This preserves original lyrics under the existing policy and is not a prose waiver.
- **Spoken subdivisions**: Use monosyllabic আর for the spoken offbeat counting syllable and, matching earlier Bengali lessons. Sixteenth counts use এক-ই-আর-আ. Do not use two-syllable এবং for a single rhythmic subdivision. Ordinary conjunctions remain contextually ও/এবং/আর.
- **String pitch versus physical orientation**: In guitar top strings/top four strings, use সরু তার/সরু চারটি তার or উঁচু স্বরের তার, since the physically upper strings nearest the player are bass strings. For violin, mandolin and cello, higher/lower string references denote pitch and are disambiguated as উঁচু/নিচু সুরের তার. Preserve actual tablature orientation and physical bow-arm directions.
- **Steady movement**: For a moving picking hand or thumb, steady means rhythmically even: সমান তালে / সমান তাল রাখা, not motionless স্থির হাত. স্থির remains appropriate for stable pitch, pressure or tempo when context is clear.
- **Bowing directions**: Use taught labels ডাউন-বো and আপ-বো for frog-to-tip and return strokes. Do not literalize them as vertically downward/upward bow movement.
- **Pickup as a taught term**: Use পিকআপ, defining it in Bengali at first teaching use. Do not replace the term by the answer in a definition question.
- **Swing subdivision**: When the source refers to the last or middle triplet within a beat, say ট্রিপলেটের শেষ অংশ or ট্রিপলেটের মাঝের অংশ: it denotes a subdivision within one triplet, not a whole triplet group.
- **Airflow**: Steady air is সমান বায়ুপ্রবাহ; do not describe breathing flow as motionless স্থির বাতাস.
- **Original lyric quiz options**: When a quiz identifies an original sung word or syllable, retain that precise word as a source-bound answer option, while translating prompt and explanation. This includes incorrect lyric-word options as well as the correct option. Do not extend to ordinary UI or lesson prose.
