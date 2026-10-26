# Persian localization glossary

AI translation decisions, 2026-10-25. Not human native-speaker sign-off. Legal facts take priority over length. RTL: start with Persian words; isolate dynamic values adjoining punctuation with U+2068/U+2069 and record this in batch notes.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | fa — فارسی | As in `ios/Timbre/Resources/<locale>.lproj`. `zh-CN` is Simplified Chinese, `no` is Norwegian Bokmål, `pt` serves Brazil and Portugal, `es` serves every Spanish market. |
| Variant | Persian as used in Iran; no Arabic letter substitutions. | `es`: the current table uses Spain's iOS wording ("Ajustes"); the store listing targets es-MX ("Configuración"). `pt`: the current table is Brazilian ("você"). Pick one variant and write it here; GPT follows it. |
| Register ("you") | Polite شما; plural imperatives ending ـید. | Formal or informal, and the exact form: German du, French vous, Spanish tú, Russian вы, Japanese です/ます, Korean 해요체, Chinese 你 (not 您), Hindi आप … One register for the whole app, lessons included. The current tables of he, hr, ro, sl and tr mix both registers: decide, and add the clean-up to the review. |
| Imperatives and buttons | Short noun/infinitive labels; polite imperative instructions. | How a button reads (infinitive "Stimmen", imperative "Stimme", noun "Stimmung"); how an instruction reads ("Pluck your thickest string"). Follow Apple's own iOS wording in the language. |
| Readers of unknown gender | Gender-neutral Persian constructions. | Languages that mark the reader's gender in verbs or adjectives (ar, he, hi, ur, pl, ru, uk, cs, sk, sl, hr, ro, pt, es, it, fr, ca …): plural address, neutral constructions, or a fixed default. Write the rule here. |
| Quotation marks | «…» | For quoting another control's name or a song title ("Tap Listen to start"). Current tables: de „…“, fr « … » (with no-break spaces), ru and uk «…», pl and ro „…”, cs, sk, bg „…“, sl »…«, el, ar, fa «…», ja 「…」, zh-CN “…”, ko ‘…’, most others “…”, some none. |
| Apostrophe and ellipsis | Persian normally needs no apostrophe; retain … | Apostrophe ' or ’ (match the current table). Ellipsis: the single character … wherever the English has it ("Listening…"), never three dots. |
| Spaces | Standard Persian spacing and ZWNJ in می‌ and plural suffixes; keep brands separated. | French: no-break space (U+00A0, or narrow U+202F) before : ; ? ! and inside « ». Chinese: a space between Han characters and Latin letters, digits or placeholders, as the current tables do ("保持你的 %lld 天连续记录"). Japanese: no spaces between kana/kanji and Latin, digits or placeholders. Thai: no spaces between words (a space ends a phrase). |
| Digits in literal numbers | ASCII 0–9 in new translations; runtime numbers follow device. | Lessons always use ASCII 0–9 (the import requires it). Interface text: Western digits unless the current table uses native ones (fa Persian, bn Bengali, mr Devanagari do in places); numbers the app formats (%lld) follow the device anyway. |
| Units | سنت؛ دقیقه / دقیقه؛ ثانیه؛ میلی‌ثانیه. Hz, BPM, ¢, XP unchanged. | Hz, BPM, ¢ and XP stay as they are in every locale. Write here the word for "cents" (Cent, セント, 音分, центы …), "minutes"/"min", "seconds", "ms". |
| Capitalization | No upper/lowercase distinction; preserve Latin identifiers. | English uses sentence case for titles and buttons ("Start free trial"). Keep sentence case unless the language's iOS convention differs. |
| Note names in the interface | App-inserted notes unchanged. | The app writes note names itself (`NoteNames`, Settings › Note names): German letters with H by default in `de`, letters in every other language, or the player's choice of solfège, sargam or numbers. Never write a note name into an interface string of your own; placeholders bring them. |
| Note names in lessons (lesson languages only) | Lessons remain English in fa; quoted note/chord labels unchanged. | Letters exactly as in the English (C, F♯, B♭, Em, G7). German only: B natural is H and B♭ is B. A spelled-out "sharp"/"flat" becomes the word below. |
| Sharp / flat / double sharp / double flat as words | دیز / بمل / دوبل دیز / دوبل بمل | The words VoiceOver uses (`NoteNames.SpokenWords` in `ios/Sources/TimbreCore/Catalog/NoteNames.swift`): fr dièse/bémol, it diesis/bemolle, es sostenido/bemol, pt sustenido/bemol, ru диез/бемоль (D-диез), ja シャープ/フラット (Dシャープ), zh-CN 升/降 before the letter (升 D), ko 샵/플랫 (D 샵); German-family languages name the note (Dis, Es, As, B; Dutch Bes; Swedish Fiss). Lessons in de: decide "Dis" or "D♯" for a spelled-out "D sharp", but never add a ♯ sign the English doesn't have (the import counts them). |
| Tuning direction | پایین‌تر / بالاتر for tuning deviation, not accidentals. | "flat" / "sharp" as a tuner reading (too low / too high) is not the accidental: de zu tief / zu hoch, fr trop bas / trop haut (current tables). Write both senses here. |
| iOS Settings path (legal text) | تنظیمات › حساب Apple › اشتراک‌ها; terminology consistent with existing translation, not verified on a Persian iPhone. | Apple's own words in this language for Settings › Apple Account › Subscriptions, with the › separator kept. Listing doc: de Einstellungen › Apple-Account › Abonnements (the app's de strings say "Apple Account"), fr Réglages › Compte Apple › Abonnements, es-MX Configuración › Cuenta de Apple › Suscripciones, pt-BR Ajustes › Conta Apple › Assinaturas, it Impostazioni › Account Apple › Abbonamenti, ja 設定 › Appleアカウント › サブスクリプション, ko 설정 › Apple 계정 › 구독, zh-CN 设置 › Apple 账户 › 订阅, ru Настройки › Аккаунт Apple › Подписки. Other languages: copy it from an iPhone set to the language. |
| Apple feature names | صفحهٔ اصلی، صفحهٔ قفل، ویجت، فعالیت زنده، میان‌برها، Siri، مرکز کنترل، Apple Watch، اشتراک‌گذاری خانوادگی، Game Center | Apple's localized names for Home Screen, Lock Screen, widget, Live Activity, Shortcuts, Siri, Control Center, Apple Watch, Family Sharing, Game Center: as iOS shows them in the language, never a new coinage. |
| Siri phrases | Polite imperative; preserve ${applicationName} and command tokens. | How a spoken command reads (imperative or first person, "Stimme mein …"); keep ${applicationName} in every phrase. |

## 2. Terms

### A. Names that stay as they are

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translated, transliterated or inflected. Where grammar wants a case ending, rebuild the sentence ("in Timbre", "the Timbre app"). |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" | | Pro | The precision level is "Expert", precisely so that "Pro" always means the plan. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs | | (unchanged) | Apple's spelling; "Apple Music" never in capitals. |
| ChordPro | A chord-chart file format | Your songs import help | | ChordPro | Its syntax in examples stays verbatim: `[G]`, `{start_of_chorus}`, `{end_of_chorus}`. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | (unchanged) | The pseudo-localization test lets only "Timbre", "BPM" and words under three letters bypass the tables on the welcome screen and the tuner. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | نام‌های تثبیت‌شدهٔ سازها در timbre_catalog_*؛ گیتار، بیس، یوکللی، ویولن، ویولنسل، عود | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | استاندارد؛ دراپ D؛ باز G؛ DADGAD | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | کوک | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | یادگیری | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | آهنگ‌ها | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | تمرین | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | پیشرفت | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | تنظیمات | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | امروز | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | مأموریت | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | آهنگ‌های شما |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | برگهٔ آهنگ |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | نمودار آکورد / نمای نوازنده | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | نمای آکورد / نمای دسته |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | نشانم بده | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | با ضربه به سیم‌ها کوک کنید |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | کوک با لمس / لمس | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | خال | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | تربیت شنوایی |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | صدای ممتد | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | صدای ممتد تانپورا |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | اینتوناسیون | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | مترونوم / مربی سرعت |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | آکوردها / گام‌ها |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | تعیین سطح |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | همراه بنوازید | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | اجرا / اجرای نهایی | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | حلقهٔ A–B؛ تنظیم A؛ تنظیم B | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | مبتدی / استاندارد / حرفه‌ای | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | استودیو (سبک‌تر) / سه‌بعدی هم‌زمان |  |
| Haptics | Vibration feedback | Settings | `Haptics` | لرزش | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | تیونر |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | کوک کردن / کوک ساز |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | کوک | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | کوک | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | پایین‌تر / بالاتر | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | سنت | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | تثبیت کوک | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | سیم |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | گوشی کوک / سردسته |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | صدای مرجع / فرکانس مرجع / کوک کنسرت |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | زیرایی نوشته‌شده / تعدیل |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | کروماتیک / استروب |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | کاپو |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | انتقال گام |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | نام نت‌ها / سلفژ / سارگام |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | فرت / سیم آزاد | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | انگشت 1–4 | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | آکورد / شکل آکورد / باره |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | ماژور / مینور / هفتم / پاور آکورد | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | گام |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | گام / گام ماژور / الگوی پنتاتونیک | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | نیم‌پرده / پرده / فاصله / سوم / پنجم / اکتاو |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | میزان |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | ضرب / تمپو / ضرب اول / شمارش |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | ضربه به سیم‌ها / ضربهٔ رو به پایین / ضربهٔ رو به بالا / ضربهٔ خفه / ضربهٔ خفه / خفه کردن | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | پیک؛ زخمه زدن؛ انتخاب کردن در رابط | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | انگشت‌نوازی / همر آن / پول آف / اسلاید / بند / ویبراتو | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | آرشه‌کشی / آرشه‌کشی روی سیم آزاد |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | ملودی | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | کادانس / آکورد V / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | پیش‌ضرب |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | مقدمه / بند 1 / ترجیع‌بند / پل / تک‌نوازی / پایان / دنباله | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | بخش |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | زنجیرهٔ تمرین | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | حفظ زنجیره |  |
| best run | The longest streak so far | Progress | `best run` | بهترین رکورد | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | نشان / دستاورد |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | سطح / ستاره‌ها / XP / کمبو / امتیاز / دور |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | به چالش کشیدن دوست |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | چالش | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | دوره / بخش / درس / گام |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | آزمون / راهنمایی |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | اشتراک / تمدید / لغو | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | آزمایش رایگان / پایان آزمایش |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | سالانه / ماهانه / مادام‌العمر |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | بازیابی خریدها |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | روش پرداخت / مشکل پرداخت |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | شرایط / سیاست حریم خصوصی | Apple's EULA is linked as "Terms". |

## 3. Course and song names

Persian lessons do not ship. Keep song titles supplied by English lessons unchanged; do not translate sung lyrics. Course names appearing in the interface use the catalogue's Persian names. Originals = آثار اختصاصی; Standards & Classics = قطعات استاندارد و کلاسیک; Songbook = مجموعهٔ آهنگ‌ها. Names and years in credits stay unchanged.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | کوک کردن / ملودی | تنظیم دستگاه |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | دیز / بمل؛ بالاتر / پایین‌تر | تیز / مسطح |
| bar | a measure | a UI bar, a pub | میزان | نوار / میخانه |
| key | tonality | a piano key, a password key | گام | کلید رمز |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | پیک / زخمه زدن / انتخاب کردن | یک ترجمه برای همهٔ کاربردها |
| lock | the string is held in tune | a padlock | تثبیت کوک | قفل فیزیکی |
| take | one recorded attempt | "take a lesson" | اجرا | برداشتن |
| run | a streak ("best run"), a clean run through a passage | running | زنجیره / اجرای کامل | دویدن |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | نمودار آکورد | نمودار آماری مگر در آمار |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | اینتوناسیون | تنظیم خرک برای اکتاو |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | بعدی / دوباره / آهسته‌تر | فرمان ناسازگار با دکمه |
| Practice | the tab and the activity | a medical or legal practice | تمرین | مطب |
| Feel | the haptic tuning feature, feeling the beat | emotions | لمس | احساس عاطفی |
