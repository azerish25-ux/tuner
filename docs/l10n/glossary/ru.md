# Russian glossary

Status: AI-drafted and AI-reviewed, 2026-10-25. No native-human sign-off or device verification claimed. Existing tables inspected; terminology below is binding.

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | ru — Russian | As in `ios/Timbre/Resources/<locale>.lproj`. `zh-CN` is Simplified Chinese, `no` is Norwegian Bokmål, `pt` serves Brazil and Portugal, `es` serves every Spanish market. |
| Variant | Standard Russian, shared regional table | `es`: the current table uses Spain's iOS wording ("Ajustes"); the store listing targets es-MX ("Configuración"). `pt`: the current table is Brazilian ("você"). Pick one variant and write it here; GPT follows it. |
| Register ("you") | Formal/plural вы, lower case | Formal or informal, and the exact form: German du, French vous, Spanish tú, Russian вы, Japanese です/ます, Korean 해요체, Chinese 你 (not 您), Hindi आप … One register for the whole app, lessons included. The current tables of he, hr, ro, sl and tr mix both registers: decide, and add the clean-up to the review. |
| Imperatives and buttons | Infinitives on action buttons; plural imperatives in instructions | How a button reads (infinitive "Stimmen", imperative "Stimme", noun "Stimmung"); how an instruction reads ("Pluck your thickest string"). Follow Apple's own iOS wording in the language. |
| Readers of unknown gender | Gender-neutral present tense or plural address | Languages that mark the reader's gender in verbs or adjectives (ar, he, hi, ur, pl, ru, uk, cs, sk, sl, hr, ro, pt, es, it, fr, ca …): plural address, neutral constructions, or a fixed default. Write the rule here. |
| Quotation marks | «…» | For quoting another control's name or a song title ("Tap Listen to start"). Current tables: de „…“, fr « … » (with no-break spaces), ru and uk «…», pl and ro „…”, cs, sk, bg „…“, sl »…«, el, ar, fa «…», ja 「…」, zh-CN “…”, ko ‘…’, most others “…”, some none. |
| Apostrophe and ellipsis | Typographic apostrophe where needed; single … | Apostrophe ' or ’ (match the current table). Ellipsis: the single character … wherever the English has it ("Listening…"), never three dots. |
| Spaces | Ordinary single spaces; no extra punctuation spacing | French: no-break space (U+00A0, or narrow U+202F) before : ; ? ! and inside « ». Chinese: a space between Han characters and Latin letters, digits or placeholders, as the current tables do ("保持你的 %lld 天连续记录"). Japanese: no spaces between kana/kanji and Latin, digits or placeholders. Thai: no spaces between words (a space ends a phrase). |
| Digits in literal numbers | ASCII 0–9 | Lessons always use ASCII 0–9 (the import requires it). Interface text: Western digits unless the current table uses native ones (fa Persian, bn Bengali, mr Devanagari do in places); numbers the app formats (%lld) follow the device anyway. |
| Units | Hz, BPM, ¢, XP unchanged; центы, минуты/мин, секунды/с, мс | Hz, BPM, ¢ and XP stay as they are in every locale. Write here the word for "cents" (Cent, セント, 音分, центы …), "minutes"/"min", "seconds", "ms". |
| Capitalization | Sentence case | English uses sentence case for titles and buttons ("Start free trial"). Keep sentence case unless the language's iOS convention differs. |
| Note names in the interface | Runtime placeholders only; do not respell notes | The app writes note names itself (`NoteNames`, Settings › Note names): German letters with H by default in `de`, letters in every other language, or the player's choice of solfège, sargam or numbers. Never write a note name into an interface string of your own; placeholders bring them. |
| Note names in lessons (lesson languages only) | Keep C, F♯, B♭, Em, G7 unchanged | Letters exactly as in the English (C, F♯, B♭, Em, G7). German only: B natural is H and B♭ is B. A spelled-out "sharp"/"flat" becomes the word below. |
| Sharp / flat / double sharp / double flat as words | диез / бемоль / дубль-диез / дубль-бемоль | The words VoiceOver uses (`NoteNames.SpokenWords` in `ios/Sources/TimbreCore/Catalog/NoteNames.swift`): fr dièse/bémol, it diesis/bemolle, es sostenido/bemol, pt sustenido/bemol, ru диез/бемоль (D-диез), ja シャープ/フラット (Dシャープ), zh-CN 升/降 before the letter (升 D), ko 샵/플랫 (D 샵); German-family languages name the note (Dis, Es, As, B; Dutch Bes; Swedish Fiss). Lessons in de: decide "Dis" or "D♯" for a spelled-out "D sharp", but never add a ♯ sign the English doesn't have (the import counts them). |
| Tuning direction | ниже / выше (not accidentals) | "flat" / "sharp" as a tuner reading (too low / too high) is not the accidental: de zu tief / zu hoch, fr trop bas / trop haut (current tables). Write both senses here. |
| iOS Settings path (legal text) | Настройки › Аккаунт Apple › Подписки | Apple's own words in this language for Settings › Apple Account › Subscriptions, with the › separator kept. Listing doc: de Einstellungen › Apple-Account › Abonnements (the app's de strings say "Apple Account"), fr Réglages › Compte Apple › Abonnements, es-MX Configuración › Cuenta de Apple › Suscripciones, pt-BR Ajustes › Conta Apple › Assinaturas, it Impostazioni › Account Apple › Abbonamenti, ja 設定 › Appleアカウント › サブスクリプション, ko 설정 › Apple 계정 › 구독, zh-CN 设置 › Apple 账户 › 订阅, ru Настройки › Аккаунт Apple › Подписки. Other languages: copy it from an iPhone set to the language. |
| Apple feature names | Экран «Домой»; экран блокировки; виджет; Live Activity; Команды; Пункт управления; Семейный доступ. Apple Watch, Siri, Game Center unchanged. | Apple's localized names for Home Screen, Lock Screen, widget, Live Activity, Shortcuts, Siri, Control Center, Apple Watch, Family Sharing, Game Center: as iOS shows them in the language, never a new coinage. |
| Siri phrases | Natural spoken commands; Далее, Ещё раз, Медленнее; keep ${applicationName} | How a spoken command reads (imperative or first person, "Stimme mein …"); keep ${applicationName} in every phrase. |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Каталожные названия инструментов (timbre_catalog_*); гитара, уд, эрху, ситар, танпура | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | Стандартный строй; Drop D; открытый G; DADGAD | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | Настройка | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | Обучение | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | Песни | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | Занятия | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | Прогресс | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | Настройки | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | Сегодня | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | Задание | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | Ваши песни |  |
| Song sheet | A song lesson's chord-and-words page | lessons |  | Лист с аккордами и текстом |  |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | Схема / Вид со стороны музыканта | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | Вид аккорда / Вид грифа |  |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | Покажите | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | Проведите по струнам для настройки |  |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | Настройка по вибрации / Вибрация | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | В яблочко | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | Тренировка слуха |  |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | Бурдон | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | Танпура |  |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | Интонация | Not the guitar-setup adjustment of the saddle (octave intonation). The current ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准) tables use that wrong sense: fix them. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | Метроном / Тренажёр темпа |  |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | Аккорды / Гаммы |  |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | Проверка уровня |  |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | Играйте в ритм | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | Дубль | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | Петля A–B / Установить A / Установить B | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | Начальный / Стандарт / Эксперт | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | Студия (легче) / 3D в реальном времени |  |
| Haptics | Vibration feedback | Settings | `Haptics` | Тактильный отклик | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | тюнер |  |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | настроить |  |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | строй | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | Настроено | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | ниже / выше | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | центы | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | точное попадание в ноту; подтверждение настройки | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | струна |  |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | колок / головка грифа |  |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | опорный тон / эталонная высота / Камертон |  |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | записанная высота / Темперация |  |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | Хроматический / стробоскопический |  |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | Каподастр |  |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | Транспонировать / транспозиция |  |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | Названия нот / Сольфеджио / Саргам |  |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | лад / открытая струна | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | палец 1–4; указательный, средний, безымянный, мизинец | Digits stay digits. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | аккорд / аппликатура аккорда / баррэ |  |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | мажорный / минорный / септаккорд / квинтаккорд | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | Тональность |  |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | гамма / мажорная гамма / бокс пентатоники | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | полутон / тон / интервал / терция / квинта / октава |  |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | такт |  |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | доля / темп / сильная доля / счёт |  |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | бой / удар вниз / удар вверх / приглушённый удар / глушение | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | медиатор; щипок; выбрать (UI) | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | пальцевая игра / хаммер-он / пулл-офф / слайд / бенд / вибрато | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons |  | игра смычком / игра смычком по открытым струнам |  |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | мелодия | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | каденция / аккорд V ступени / I–IV–V | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | затакт |  |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | Вступление / Куплет 1 / Припев / Бридж / Соло / Кода / Завершение | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 |  | раздел |  |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 |  | серия | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI |  | заморозка серии |  |
| best run | The longest streak so far | Progress | `best run` | лучшая серия | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | значок / достижение |  |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | уровень / звёзды / XP / Комбо / счёт / раунд |  |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | вызвать друга на состязание |  |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | испытание | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | курс / раздел / урок / шаг |  |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | тест / подсказка |  |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | подписка / продлить / отменить | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | бесплатный пробный период / пробный период заканчивается |  |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | Ежегодно / Ежемесячно / Навсегда |  |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | Восстановить покупки |  |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | способ оплаты / проблема с оплатой |  |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | Условия / Политика конфиденциальности | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | Гитара, Укулеле, Бас-гитара, Скрипка, Виолончель, Мандолина, Банджо | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | Тренировка слуха, Теория музыки, Ритм, Пение |  |
| Songs | Course title, also the Songs tab | Песни |  |
| Originals | Course of songs written for Timbre ("Timbre Originals") | Авторские песни | Keep or translate: decide once. |
| Standards & Classics | Course title | Стандарты и классика |  |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | Песенник для укулеле / мандолины / скрипки / виолончели / бас-гитары | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

Song titles, the rule for this locale (fill one line each):

- Established public-domain titles: use the established Russian title.
- Other traditional titles: retain English unless the current Russian lesson has an established localized title.
- Timbre Originals: translate titles consistently with existing Russian lesson titles.
- A title in prose must equal the title of its song lesson in this locale (the helper adds it to lesson batches as `lesson_title`), and Game Center's leaderboard for a featured song uses the same title.
- Lyric credits ("Traditional (printed 1876; James Yorkston, 1884)", "Words from 1779, tune from 1829"): names and years as they are; the connecting words translated.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | настроить / мелодия | Avoid the unrelated sense in the Not column. |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | диез / бемоль; выше / ниже | Avoid the unrelated sense in the Not column. |
| bar | a measure | a UI bar, a pub | такт | Avoid the unrelated sense in the Not column. |
| key | tonality | a piano key, a password key | тональность | Avoid the unrelated sense in the Not column. |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | медиатор / щипок; выбрать | Avoid the unrelated sense in the Not column. |
| lock | the string is held in tune | a padlock | подтверждение точной настройки | Avoid the unrelated sense in the Not column. |
| take | one recorded attempt | "take a lesson" | дубль | Avoid the unrelated sense in the Not column. |
| run | a streak ("best run"), a clean run through a passage | running | серия / исполнение отрывка | Avoid the unrelated sense in the Not column. |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | схема аккордов | Avoid the unrelated sense in the Not column. |
| Intonation | playing in tune over a drone | guitar setup octave adjustment | Интонация (чистота высоты) | Avoid the unrelated sense in the Not column. |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | Далее / Ещё раз / Медленнее | Avoid the unrelated sense in the Not column. |
| Practice | the tab and the activity | a medical or legal practice | Занятия | Avoid the unrelated sense in the Not column. |
| Feel | the haptic tuning feature, feeling the beat | emotions | Вибрация | Avoid the unrelated sense in the Not column. |
