# Bulgarian glossary

Status: AI-drafted and AI-reviewed, 2026-10-25. Native-human sign-off and device verification pending. Shipped labels inspected; explicit decisions below override conflicting anchors.

## 1. Locale decisions

| Decision | Value |
|---|---|
| Locale code and language | bg — Bulgarian |
| Variant | Standard national language; shared regional table |
| Register (you) | Formal/plural вие; plural imperatives |
| Imperatives and buttons | Short action labels; instructions in the chosen register; spoken hints state the action |
| Readers of unknown gender | Gender-neutral wording; no agreement with unknown argument values |
| Quotation marks | „…“ |
| Apostrophe and ellipsis | Single …; conventional apostrophe |
| Spaces | Ordinary single spaces |
| Digits in literal numbers | ASCII 0–9 |
| Units | Hz, BPM, ¢, XP unchanged; центове; минути/мин; секунди/сек; мс |
| Capitalization | Sentence case |
| Note names in interface | Runtime placeholders only |
| Note names in lessons | Keep C, F♯, B♭, Em, G7 unchanged |
| Accidentals as words | диез / бемол / двоен диез / двоен бемол |
| Tuning direction | по-ниско / по-високо |
| iOS Settings path | Настройки › Apple регистрация › Абонаменти |
| Apple feature names | Начален екран; заключен екран; уиджет; Команди; Контролен център; Семейно споделяне. Apple Watch, Siri, Game Center unchanged. |
| Siri phrases | Natural spoken command; retain every ${…} token. Напред / Отново / По-бавно |

## 2. Terms

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translate brands or attach endings. |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | Never translate brands or attach endings. |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | Never translate brands or attach endings. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | Unchanged | Never translate brands or attach endings. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Never translate brands or attach endings. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | Unchanged | Never translate brands or attach endings. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Каталожни имена timbre_catalog_*: китара, уд, ерху, ситар, танпура | Use this sense; inflect words naturally, never placeholders. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | Стандартна настройка / Drop D / отворен G / DADGAD | Use this sense; inflect words naturally, never placeholders. |
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | Настройване | Use this sense; inflect words naturally, never placeholders. |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | Обучение | Use this sense; inflect words naturally, never placeholders. |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | Песни | Use this sense; inflect words naturally, never placeholders. |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | Упражнения | Use this sense; inflect words naturally, never placeholders. |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | Напредък | Use this sense; inflect words naturally, never placeholders. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | Настройки | Use this sense; inflect words naturally, never placeholders. |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | Днес | Use this sense; inflect words naturally, never placeholders. |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | Задача | Use this sense; inflect words naturally, never placeholders. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | Вашите песни | Use this sense; inflect words naturally, never placeholders. |
| Song sheet | A song lesson's chord-and-words page | lessons |  | Лист с акорди и текст | Use this sense; inflect words naturally, never placeholders. |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | Диаграма / Изглед на музиканта | Use this sense; inflect words naturally, never placeholders. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | Изглед на акорда / Изглед на грифа | Use this sense; inflect words naturally, never placeholders. |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | Покажете ми | Use this sense; inflect words naturally, never placeholders. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | Прокарайте по струните за настройване | Use this sense; inflect words naturally, never placeholders. |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | Настройване чрез вибрации / Вибрации | Use this sense; inflect words naturally, never placeholders. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | В десетката | Use this sense; inflect words naturally, never placeholders. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | Трениране на слуха | Use this sense; inflect words naturally, never placeholders. |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | Бурдон | Use this sense; inflect words naturally, never placeholders. |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | Танпура | Use this sense; inflect words naturally, never placeholders. |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | Интонация | Use this sense; inflect words naturally, never placeholders. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | Метроном / Тренажор за темпо | Use this sense; inflect words naturally, never placeholders. |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | Акорди / Гами | Use this sense; inflect words naturally, never placeholders. |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | Проверка на нивото | Use this sense; inflect words naturally, never placeholders. |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | Свирете в ритъм | Use this sense; inflect words naturally, never placeholders. |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | Дубъл | Use this sense; inflect words naturally, never placeholders. |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | Цикъл A–B / Задаване на A / Задаване на B | Use this sense; inflect words naturally, never placeholders. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | Начинаещ / Стандартно / Експерт | Use this sense; inflect words naturally, never placeholders. |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | Студио (по-леко) / 3D в реално време | Use this sense; inflect words naturally, never placeholders. |
| Haptics | Vibration feedback | Settings | `Haptics` | Хаптика | Use this sense; inflect words naturally, never placeholders. |
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | тунер | Use this sense; inflect words naturally, never placeholders. |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | настройване | Use this sense; inflect words naturally, never placeholders. |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | строй | Use this sense; inflect words naturally, never placeholders. |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | Настроено | Use this sense; inflect words naturally, never placeholders. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | по-ниско / по-високо | Use this sense; inflect words naturally, never placeholders. |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | центове | Use this sense; inflect words naturally, never placeholders. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | потвърждение за точно настройване | Use this sense; inflect words naturally, never placeholders. |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | струна | Use this sense; inflect words naturally, never placeholders. |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ключ / глава на грифа | Use this sense; inflect words naturally, never placeholders. |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | референтен тон / референтна височина / Камертон | Use this sense; inflect words naturally, never placeholders. |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | изписана височина / Темперация | Use this sense; inflect words naturally, never placeholders. |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | Хроматично / стробоскопично | Use this sense; inflect words naturally, never placeholders. |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | Каподастър | Use this sense; inflect words naturally, never placeholders. |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | Транспониране | Use this sense; inflect words naturally, never placeholders. |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | Имена на нотите / Солфеж / Саргам | Use this sense; inflect words naturally, never placeholders. |
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | прагче / отворена струна | Use this sense; inflect words naturally, never placeholders. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | пръст 1–4; показалец, среден, безименен, кутре | Use this sense; inflect words naturally, never placeholders. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | акорд / форма на акорда / баре | Use this sense; inflect words naturally, never placeholders. |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | мажорен / минорен / септакорд / пауър акорд | Use this sense; inflect words naturally, never placeholders. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | Тоналност | Use this sense; inflect words naturally, never placeholders. |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | гама / мажорна гама / пентатонична позиция | Use this sense; inflect words naturally, never placeholders. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | полутон / цял тон / интервал / терца / квинта / октава | Use this sense; inflect words naturally, never placeholders. |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | такт | Use this sense; inflect words naturally, never placeholders. |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | удар / темпо / силно време / броене | Use this sense; inflect words naturally, never placeholders. |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | удар по струните / удар надолу / удар нагоре / приглушен удар / приглушаване | Use this sense; inflect words naturally, never placeholders. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | перце; щипване; избор (UI) | Use this sense; inflect words naturally, never placeholders. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | свирене с пръсти / хамър-он / пул-оф / слайд / бенд / вибрато | Use this sense; inflect words naturally, never placeholders. |
| bowing, open-string bowing | Violin and cello | lessons |  | свирене с лък / свирене с лък по отворени струни | Use this sense; inflect words naturally, never placeholders. |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | мелодия | Use this sense; inflect words naturally, never placeholders. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | каденца / акорд V / I–IV–V | Use this sense; inflect words naturally, never placeholders. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | затакт | Use this sense; inflect words naturally, never placeholders. |
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | Интро / Куплет 1 / Припев / Бридж / Соло / Аутро / Завършек | Use this sense; inflect words naturally, never placeholders. |
| section | A part of a song | lessons 9 |  | част | Use this sense; inflect words naturally, never placeholders. |
| streak | Consecutive days with practice | UI 21 |  | поредица | Use this sense; inflect words naturally, never placeholders. |
| streak freeze | Saves the streak on a missed day | UI |  | замразяване на поредицата | Use this sense; inflect words naturally, never placeholders. |
| best run | The longest streak so far | Progress | `best run` | най-добра поредица | Use this sense; inflect words naturally, never placeholders. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | значка / постижение | Use this sense; inflect words naturally, never placeholders. |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | ниво / звезди / XP / Комбо / резултат / рунд | Use this sense; inflect words naturally, never placeholders. |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | предизвикателство към приятел | Use this sense; inflect words naturally, never placeholders. |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | предизвикателство | Use this sense; inflect words naturally, never placeholders. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | курс / раздел / урок / стъпка | Use this sense; inflect words naturally, never placeholders. |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | тест / подсказка | Use this sense; inflect words naturally, never placeholders. |
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | абонамент / подновяване / отказване | Use this sense; inflect words naturally, never placeholders. |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | безплатен пробен период / пробният период изтича | Use this sense; inflect words naturally, never placeholders. |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | Годишно / Месечно / Завинаги | Use this sense; inflect words naturally, never placeholders. |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | Възстановяване на покупките | Use this sense; inflect words naturally, never placeholders. |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | начин на плащане / проблем с плащането | Use this sense; inflect words naturally, never placeholders. |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | Условия / Политика за поверителност | Use this sense; inflect words naturally, never placeholders. |

## 3. Course and song names

| English | Translation |
|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Китара, Укулеле, Бас, Цигулка, Виолончело, Мандолина, Банджо |
| Ear Training, Music Theory, Rhythm, Singing | Трениране на слуха, Теория на музиката, Ритъм, Пеене |
| Songs | Песни |
| Originals | Авторски песни |
| Standards & Classics | Стандарти и класика |
| Instrument Songbook | Песнопойка за съответния инструмент |

- Established public-domain titles: use established local titles.
- Other traditional songs: retain English unless a shipped localized lesson title already exists.
- Timbre Originals: translate consistently with existing localized lesson titles; never translate sung lyrics.
- A title in prose must exactly match its lesson title and leaderboard. Credits retain names and digit groups; translate connecting words.

## 4. Words that mislead

| English | Translation and distinction |
|---|---|
| Tune | настройване; мелодия as noun |
| sharp / flat | диез / бемол; по-високо / по-ниско for tuning |
| bar | такт, not a pub |
| key | тоналност, not an object |
| pick | перце / щипване; избор in UI |
| lock | потвърждение за настройване, not padlock |
| take | дубъл |
| run | поредица / изпълнение на откъс |
| chart | диаграма на акорди |
| Intonation | Интонация; pitch accuracy, not saddle adjustment |
| Next, Again, Slower | Напред / Отново / По-бавно |
| Practice | Упражнения |
| Feel | Вибрации, not emotions |

## 5. Current lesson-author decisions (2026-10-26)

Historical author-stage status: the frozen lesson draft was unreviewed when authored. Complete independent AI semantic review is now integrated; the review supplement below takes precedence. Native-human and device review remain pending.

- Formal/plural imperatives throughout; no assumed handedness. “Picking hand” is the hand with the pick, not automatically the right hand.
- Note/chord letters remain Latin, including B natural. Named accidentals remain words: диез, бемол. Never introduce a ♯/♭ or numeric chord label where the source spells it out.
- Interval qualities: major = голям, minor = малък; chord/key qualities: мажорен/минорен. Major seventh chord = голям мажорен септакорд / мажорен акорд с голяма септима; minor seventh chord = малък минорен септакорд / минорен акорд с малка септима; dominant seventh = доминантсептакорд.
- Beat in duration/count answers = удар; numbered metrical positions = време (първото време). Bare shared “One/Two” are standalone counting labels, not gender-dependent noun phrases. Up/Down = Нагоре/Надолу, covering pitch and picking directions. Same/Different = Еднакви/Различни, comparing the heard pair of notes or chords.
- Triad = тризвучие; inversion = обръщение; root = основен тон; degree = степен; Dorian = дорийски; Mixolydian = миксолидийски.
- Physical guitar bridge = магаренце; song bridge = бридж. Shared physical/song roles must be inspected before choosing a shared target.
- Pentatonic box = пентатонична позиция (shortened позиция when already clear). Hammer-on = хамър-он; pull-off = пул-оф; slide = слайд; bend = бенд; trill = трилер; shuffle = шафъл; Travis picking = техника „Травис“; comping = съпровод.
- Source “short bend” means under-bent pitch, rendered недотеглен бенд, not short duration. Source fretting-finger/picking ambiguity is resolved explicitly without changing notes or digit groups.
- The E A D G B E English mnemonic remains an identified English mnemonic within translated Bulgarian explanation so its initials still work; rhythmic Humpty Dumpty syllables become там-та, там-та. Sixteenth counting uses едно-е-и-а, keeping four subdivisions.
- Traditional original titles are retained consistently unless a clear established Bulgarian title is chosen: Ode to Joy = Ода на радостта. Exact-source whole titles/credits/notation remain **candidates, never author approvals**.

### Original song names already chosen in the guitar course

| English | Bulgarian |
|---|---|
| Letters in a Shoebox | Писма в кутия за обувки |
| Dust on the Dashboard | Прах по таблото |
| Low Tide Radio | Радио при отлив |
| Kite Weather | Време за хвърчила |
| Halogen | Халоген |
| Ghost Light | Призрачна светлина |
| Rust Belt Shuffle | Шафъл от Ръждивия пояс |
| Basement Weather | Времето в мазето |
| Glass Satellites | Стъклени спътници |
| Porchlight | Светлина на верандата |
| Neon Laundromat | Неонова пералня |
| Saltwater Sunday | Солена неделя |
| Spray Paint Sunrise | Изгрев със спрей |
| Sparkler Season | Сезон на бенгалския огън |
| Gravel Road Two-Step | Две стъпки по чакъла |
| Lantern Hill | Хълмът на фенерите |
| Roller Rink | Ролер пързалка |
| Late Checkout | Късно напускане |
| Market Day | Пазарен ден |
| Slow Motion Strobe | Бавен стробоскоп |
| Jukebox Moon | Джубокс луна |

Frozen prompts contain the original glossary snapshot. This dated author addendum records later decisions without rewriting those historical inputs.

### Remaining original titles and final lesson terminology

| English | Bulgarian |
|---|---|
| Moth and Ember | Нощна пеперуда и жарава |
| First Frost | Първа слана |
| Hammock Season | Сезон на хамаците |
| Glow-in-the-Dark Stars | Светещи в тъмното звезди |
| Echo Canyon | Каньонът на ехото |
| Open Windows | Отворени прозорци |
| Scoreboard Lights | Светлините на таблото |
| Carousel at Closing Time | Въртележка преди затваряне |
| Cedar Smoke | Кедров дим |
| Rain on the Skylight | Дъжд по капандурата |
| Pocket Change | Дребни в джоба |
| Kitchen Slow Dance | Бавен танц в кухнята |
| Houseplants | Стайни растения |
| Static on Channel Nine | Шум по девети канал |
| Boardwalk Comet | Комета по крайбрежната алея |
| Mile Marker Zero | Нулева миля |
| Last Bell | Последният звънец |
| Copper Wire | Медна жица |
| Cold Lake | Студено езеро |
| Parking Lot Cathedral | Катедрала на паркинга |
| Keeper's Daughter | Дъщерята на пазача |
| Snow Globe Town | Град в снежно кълбо |
| Thistle and Thread | Бодил и конец |
| Late Bus Home | Късен автобус към дома |
| Velvet Hour | Кадифен час |
| Rooftop Choir | Хор на покрива |
| Bright Side of the Block | Слънчевата страна на квартала |
| Over You Soon | Скоро ще те забравя |
| Constellation Prize | Награда от съзвездия |

- Final course labels follow section 3: Трениране на слуха, Стандарти и класика, Песнопойка за [instrument].
- Bare interval-only Second/Third/Fourth = Секунда/Терца/Кварта; explicit finger choices = Втори/Трети/Четвърти пръст. “Major and minor intervals” = Големи и малки интервали, separate from chord-only “Major and minor everywhere” = Мажор и минор навсякъде.
- Banjo: roll = рол (plural ролове), forward roll = преден рол, alternating thumb roll = рол с редуващ се палец, pinch = двойно щипване, clawhammer = клоухамър, drone = бурдон, bum-ditty = бум-дити. Mandolin chop = отсечен удар; crosspicking = кроспикинг.
- Bow slur = лига за легато; rhythmic tie = лига за удължаване. Violin/cello bridge = столче, distinct from guitar магаренце and song бридж. Violin High 2/Low 2 describe finger placement: Висок 2/Нисък 2.
- Treble/bass clef = сол/фа ключ; staff = петолиние; space = междулиние; ledger line = допълнителна линия. English initial-letter staff mnemonics remain identifiable English phrases, explained in Bulgarian; their initials encode Latin pitch names.
- Solfège uses до, ре, ми, фа, сол, ла, си; source ti becomes си. The movable-do interpretation is stated at its introduction, because do denotes the tonic in every key here, not fixed C.
- The English bar/measure synonym quiz is language-dependent: localized question explicitly asks for the English synonym, and choices carry Bulgarian glosses (Beat (удар), Rest (пауза), Measure (такт)). This avoids a tautological Bulgarian question with indistinguishable translated terms.
- Three-part counting: 1-три-ла, 2-три-ла; final ла is the late swung subdivision, equivalent to source “let.” Sixteenths keep four syllabic slots: едно-е-и-а. Quoted original sung lyric cues remain in the song's language; surrounding explanation is Bulgarian. Single lyric-word answer choices carry Bulgarian glosses where appropriate.
- Century expressions such as 1700s mean the whole century beginning 1700, not its first decade. Use “столетието, започващо с 1700” and preserve the original numeric token. 1840s/1950s are decade references and use 1840-те/1950-те.
- Additional established titles: Minuet in G = Менует в G; Brahms' Lullaby = Приспивна песен на Брамс; The Swan = Лебедът; Canon in D = Канон в D; Für Elise = На Елиза; Silent Night = Тиха нощ; Eine kleine Nachtmusik = Малка нощна музика; In the Hall of the Mountain King = В пещерата на планинския цар; The Blue Danube = На хубавия син Дунав; Morning Mood = Утро; Spring = Пролет; The Four Seasons = Годишните времена; Jupiter = Юпитер; The Planets = Планетите; Rondo alla Turca = Рондо ала турка.
- The author approved no invariant. Subsequent independent AI review has individually adjudicated retained strings and reviewed specialist technique terms, movable-do pedagogy, mnemonics/lyrics and compact hints; see the review supplement. Native-human and device verification remain pending.

## Independent lesson review supplement (2026-10-26)

Complete independent AI review: 6,083 exact pairs, 1,545 helper-required complete contexts and 20 supplemental contexts; 17 corrections and 235 individual identity decisions. See [review evidence](../reviews/bg/README.md). These reviewed decisions supersede conflicting historical author notes; no native-human or device certification is claimed.

- Silent first beat means a rest, not a quiet beat. Chords four/six are scale-degree IV/vi, not temporal order. A pull-off keeps both fretting fingers on the same string. Change a chord when the thumb attacks, not with the thumb.
- Clawhammer describes the loosely curled whole hand, not a fingernail-shaped hand; title, physical instruction and answer are aligned. Crosspicking describes flowing musical motion, not tumbling.
- Up/Down remain Нагоре/Надолу for melodic and physical pick directions; One beat remains Един удар. Interval qualities голяма/малка remain distinct from chord qualities мажорен/минорен.
- Guitar hardware магаренце, bowed-instrument hardware столче and song-form бридж remain context-specific. Каденца is retained for cadence. Latin note names stay unchanged; solfege „до“ is quoted where needed to distinguish it from the preposition до.
- The bar/measure quiz explicitly asks for an English synonym and supplies Bulgarian glosses for Beat, Rest and Measure. It does not treat the localized equivalents as distinct Bulgarian synonyms.
- All 50 original titles match their 154 final-map references. Two English note-initial mnemonics and the seven-syllable lyric/note cue have individual whole-string educational rationales, not blanket English exemptions.
