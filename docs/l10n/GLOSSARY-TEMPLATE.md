# Glossary template: fix the terms before translating

One glossary per locale, filled once before the first GPT batch and given to GPT with every batch (the user message the helper in [TRANSLATING-WITH-GPT.md](TRANSLATING-WITH-GPT.md#6-the-batch-helper) builds puts the whole file in). GPT treats it as binding, the consistency pass checks against it, and the native reviewer signs it off. Most translation errors in a terminology-dense app like this one are not grammar: they are the same English word rendered three ways, or a musical word taken in its everyday sense. The glossary prevents both.

How to use this file:

1. Copy it to `docs/l10n/glossary/<locale>.md` (for example `docs/l10n/glossary/de.md`, with the locale code of `ios/Timbre/Resources/<locale>.lproj`). Delete this introduction and the "Pre-filling" section; keep sections 1 to 4, so GPT reads only decisions.
2. Pre-fill the **Translation** column from the app's current tables (snippet below). A term the shipped app already translates keeps that translation, unless it is wrong (several are, see the notes), in which case the glossary records the fix and the consistency pass lists the strings to change.
3. Fill every empty **Translation** cell and every row of section 1. GPT can draft them (give it this template and the locale's `Localizable.strings`), but a native speaker who plays an instrument decides. Leave a cell as "—" only where the English term really does not occur in your language's text (a "Notes" entry says why).
4. Keep it short. A filled glossary runs to a few pages; GPT reads all of it with every batch, so every row must earn its place. Don't add terms that have one obvious translation.
5. When a reviewer corrects a term later, change it here first, then rerun the consistency pass ([TRANSLATING-WITH-GPT.md §8.6](TRANSLATING-WITH-GPT.md#86-terminology-consistency-pass)).

The **App key** column names the key in `Localizable.strings` whose translation is the term itself (empty when the term has no key of its own). The **Where** column says where the English term occurs, so the reader knows which sense is meant: "UI n" is the number of interface strings that contain it, "lessons n" the number of lesson strings (counts from the build at 0bbf273; they drift, the senses don't).

## Pre-filling from the current tables

Run from the repository root with the locale code; it prints the current translation of every **App key** in this template, ready to paste into the Translation column:

```sh
python3 - de <<'EOF'
import re, sys
sys.path.insert(0, "tools/l10n")
import report
loc = sys.argv[1]
table = report.read_strings(report.RES / f"{loc}.lproj/Localizable.strings")
for line in open("docs/l10n/GLOSSARY-TEMPLATE.md", encoding="utf-8"):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) >= 4 and cells[3].startswith("`"):
        for key in re.findall(r"`([^`]+)`", cells[3]):
            print(f"{cells[0]:28} {key!r:24} {table.get(key, '(not translated yet)')}")
EOF
```

## 1. Locale decisions

Every row is mandatory. The "Current table" hints come from reading the shipped `<locale>.lproj/Localizable.strings`; confirm or overrule them.

| Decision | Value for this locale | Guidance |
|---|---|---|
| Locale code and language | | As in `ios/Timbre/Resources/<locale>.lproj`. `zh-CN` is Simplified Chinese, `no` is Norwegian Bokmål, `pt` serves Brazil and Portugal, `es` serves every Spanish market. |
| Variant | | `es`: the current table uses Spain's iOS wording ("Ajustes"); the store listing targets es-MX ("Configuración"). `pt`: the current table is Brazilian ("você"). Pick one variant and write it here; GPT follows it. |
| Register ("you") | | Formal or informal, and the exact form: German du, French vous, Spanish tú, Russian вы, Japanese です/ます, Korean 해요체, Chinese 你 (not 您), Hindi आप … One register for the whole app, lessons included. The current tables of he, hr, ro, sl and tr mix both registers: decide, and add the clean-up to the review. |
| Imperatives and buttons | | How a button reads (infinitive "Stimmen", imperative "Stimme", noun "Stimmung"); how an instruction reads ("Pluck your thickest string"). Follow Apple's own iOS wording in the language. |
| Readers of unknown gender | | Languages that mark the reader's gender in verbs or adjectives (ar, he, hi, ur, pl, ru, uk, cs, sk, sl, hr, ro, pt, es, it, fr, ca …): plural address, neutral constructions, or a fixed default. Write the rule here. |
| Quotation marks | | For quoting another control's name or a song title ("Tap Listen to start"). Current tables: de „…“, fr « … » (with no-break spaces), ru and uk «…», pl and ro „…”, cs, sk, bg „…“, sl »…«, el, ar, fa «…», ja 「…」, zh-CN “…”, ko ‘…’, most others “…”, some none. |
| Apostrophe and ellipsis | | Apostrophe ' or ’ (match the current table). Ellipsis: the single character … wherever the English has it ("Listening…"), never three dots. |
| Spaces | | French: no-break space (U+00A0, or narrow U+202F) before : ; ? ! and inside « ». Chinese: a space between Han characters and Latin letters, digits or placeholders, as the current tables do ("保持你的 %lld 天连续记录"). Japanese: no spaces between kana/kanji and Latin, digits or placeholders. Thai: no spaces between words (a space ends a phrase). |
| Digits in literal numbers | | Lessons always use ASCII 0–9 (the import requires it). Interface text: Western digits unless the current table uses native ones (fa Persian, bn Bengali, mr Devanagari do in places); numbers the app formats (%lld) follow the device anyway. |
| Units | | Hz, BPM, ¢ and XP stay as they are in every locale. Write here the word for "cents" (Cent, セント, 音分, центы …), "minutes"/"min", "seconds", "ms". |
| Capitalization | | English uses sentence case for titles and buttons ("Start free trial"). Keep sentence case unless the language's iOS convention differs. |
| Note names in the interface | | The app writes note names itself (`NoteNames`, Settings › Note names): German letters with H by default in `de`, letters in every other language, or the player's choice of solfège, sargam or numbers. Never write a note name into an interface string of your own; placeholders bring them. |
| Note names in lessons (lesson languages only) | | Letters exactly as in the English (C, F♯, B♭, Em, G7). German only: B natural is H and B♭ is B. A spelled-out "sharp"/"flat" becomes the word below. |
| Sharp / flat / double sharp / double flat as words | | The words VoiceOver uses (`NoteNames.SpokenWords` in `ios/Sources/TimbreCore/Catalog/NoteNames.swift`): fr dièse/bémol, it diesis/bemolle, es sostenido/bemol, pt sustenido/bemol, ru диез/бемоль (D-диез), ja シャープ/フラット (Dシャープ), zh-CN 升/降 before the letter (升 D), ko 샵/플랫 (D 샵); German-family languages name the note (Dis, Es, As, B; Dutch Bes; Swedish Fiss). Lessons in de: decide "Dis" or "D♯" for a spelled-out "D sharp", but never add a ♯ sign the English doesn't have (the import counts them). |
| Tuning direction | | "flat" / "sharp" as a tuner reading (too low / too high) is not the accidental: de zu tief / zu hoch, fr trop bas / trop haut (current tables). Write both senses here. |
| iOS Settings path (legal text) | | Apple's own words in this language for Settings › Apple Account › Subscriptions, with the › separator kept. Listing doc: de Einstellungen › Apple-Account › Abonnements (the app's de strings say "Apple Account"), fr Réglages › Compte Apple › Abonnements, es-MX Configuración › Cuenta de Apple › Suscripciones, pt-BR Ajustes › Conta Apple › Assinaturas, it Impostazioni › Account Apple › Abbonamenti, ja 設定 › Appleアカウント › サブスクリプション, ko 설정 › Apple 계정 › 구독, zh-CN 设置 › Apple 账户 › 订阅, ru Настройки › Аккаунт Apple › Подписки. Other languages: copy it from an iPhone set to the language. |
| Apple feature names | | Apple's localized names for Home Screen, Lock Screen, widget, Live Activity, Shortcuts, Siri, Control Center, Apple Watch, Family Sharing, Game Center: as iOS shows them in the language, never a new coinage. |
| Siri phrases | | How a spoken command reads (imperative or first person, "Stimme mein …"); keep ${applicationName} in every phrase. |

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
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons | | | Use the catalogue's translations (`timbre_catalog_*` keys in the table) and the language's established names; transliterate only an instrument the language has no name for. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | | Letters stay. "Standard", "Drop", "Open" follow the catalogue's `timbre_catalog_tuning_*` translations. The key `Standard` is also the middle precision level. |

### B. App areas and features (names the interface shows)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | | The tab name is pinned by `LocalizationLaunchUITests` in de ("Stimmen") and ar. In lessons "tune" can also mean a melody (see section D). |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | | Pinned in de ("Lernen"). |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | | Must equal the Songs course title (section 3). |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | | Practice, not a game controller's "Play". |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | | Pinned in de ("Fortschritt") and ar. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | | The legal text uses Apple's name for the iOS app (section 1). |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | | A name, not the adverb; "Today’s quests". |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice | | | Context of the key says "Quest" is a side goal; "Today" is the three-activity set. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | | |
| Song sheet | A song lesson's chord-and-words page | lessons | | | |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | | "Chart" is also a chord chart in Your songs. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | | |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | | Sits on a small capsule: short. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | | |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | | "Feel it", "Feel the beat" use the same sense. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | | Every current table translates it (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко …) although HANDOFF.md says to keep game names. Decide once; every string naming the game ("Win a round of Bullseye", "Score 2,000 in Bullseye") uses this. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | | |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | | de Bordun, fr Bourdon, es Nota pedal, ja ドローン (current tables). |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | | |
| Intonation | Guided instrument setup: harmonic/stopped-note comparison and saddle advice | Practice tool, setup-specific paywall references | `Intonation` | | Check `IntonationView.swift` and the routed screen. Do not apply the separate drone-practice sense to this literal key. |
| Intonation over a drone | Playing or singing accurately against a reference drone | Today activity, drone paywall outcome | `Intonation over a drone` | | Distinct literal key and source sense; generic lesson intonation also means pitch accuracy when its context says so. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | | |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | | |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | | |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | | The listing calls it the "play-along note highway". |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | | Not "take" as in "take a lesson". |
| Loop A–B, Set A, Set B | Loop points of a passage | songs | | | A and B are markers, not notes: German keeps B, never H. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | | "Expert", not "Pro" (see Pro). |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings | | | |
| Haptics | Vibration feedback | Settings | `Haptics` | | Apple's own word in the language. |

### C. Tuner

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| tuner | The tuning screen and the device it imitates | UI 13, listing | | | |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | | |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | | Not the act of tuning, where the language distinguishes (de Stimmung vs Stimmen). |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | | VoiceOver speaks it on every lock: short and natural. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | | Not the accidentals ♭ ♯ (section 1). |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | | ¢ stays a sign; the word is translated. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing | | | Not a padlock (which is "locked" content behind Pro). |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 | | | |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner | | | |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | | |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | | |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | | |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | | |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | | |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | | |

### D. Music in the lessons (lesson languages; also the interface where it names them)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 | | | "fret 2 on string 3": keep the digits. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons | | | Digits stay digits. |
| chord, chord shape, barre (chord) | | UI 31, lessons 324, 56 | `Chords` | | |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons | | | Symbols (Em, G7) stay as written. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | | |
| scale, major scale, pentatonic box | | lessons 126 | `Scales` | | "box" is a fretboard pattern. |
| half step, whole step, interval, third, fifth, octave | | lessons | `Octave` | | |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | | |
| beat, tempo, downbeat, count | | UI 29, lessons 251 | `Tempo` | | |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | | A muted stroke is judged as muted, not as a miss. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 | | | Translate by sense; check `context`. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons | | | Use the terms guitar teachers in the language use; loanwords are fine where usual. |
| bowing, open-string bowing | Violin and cello | lessons | | | |
| tune (noun) | A melody ("an old fiddle tune") | lessons | | | Not the verb, not the tab. |
| cadence, V chord, I–IV–V | Harmony | lessons | | | Roman numerals stay. |
| pickup | Notes before the first full bar (anacrusis) | lessons | | | |

### E. Song structure (section chips: `max_length` 12, or 1.5 × a longer English label)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | | Short forms are fine; keep the number ("Verse 2"). |
| section | A part of a song | lessons 9 | | | |

### F. Progress and motivation

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| streak | Consecutive days with practice | UI 21 | | | One word everywhere, including Game Center's "Practice streak". |
| streak freeze | Saves the streak on a missed day | UI | | | |
| best run | The longest streak so far | Progress | `best run` | | Same word family as streak in most languages. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | | |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | | |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | | |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | | Different sense from the row above; say which the glossary uses for each. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | | |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | | |

### G. Purchase and legal (exact, never creative)

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) | | | Apple's own words in the language (they appear in the iOS Settings screen the text points to). |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | | |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | | |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | | |
| payment method, billing issue | Failed renewal banner | all tabs (legal) | | | |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | | Apple's EULA is linked as "Terms". |

## 3. Course and song names

| English | Where | Translation | Notes |
|---|---|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Course titles (`Learn.strings`) | | Same words as the instrument names. |
| Ear Training, Music Theory, Rhythm, Singing | Course titles | | |
| Songs | Course title, also the Songs tab | | |
| Originals | Course of songs written for Timbre ("Timbre Originals") | | Keep or translate: decide once. |
| Standards & Classics | Course title | | |
| Ukulele / Mandolin / Violin / Cello / Bass Songbook | Course titles | | `Songbook` key: de Liederbuch, fr Carnet de chansons (current). |

Song titles, the rule for this locale (fill one line each):

- Public-domain songs with an established title in the language (Ode to Joy, Silent Night, Twinkle Twinkle Little Star …): use it / keep the English. (Current tables use local titles where they exist: ru «Зелёные рукава», zh-CN 《绿袖子》.)
- Other traditional songs (Clementine, Shenandoah, Molly Malone …): keep the English title / transliterate (ja グリーンスリーブス, ko 그린슬리브스).
- Timbre Originals (Kite Weather, Ghost Light, Neon Laundromat …): translate / keep. (Current lesson tables translate them: de Drachenwetter, ja 「凧日和」.)
- A title in prose must equal the title of its song lesson in this locale (the helper adds it to lesson batches as `lesson_title`), and Game Center's leaderboard for a featured song uses the same title.
- Lyric credits ("Traditional (printed 1876; James Yorkston, 1884)", "Words from 1779, tune from 1829"): names and years as they are; the connecting words translated.

## 4. Words that mislead

Write the translation that applies in Timbre, and the one GPT must avoid.

| English | In Timbre it means | Not | Translation | Avoid |
|---|---|---|---|---|
| Tune | to tune (verb, tab); in lessons also a melody | — | | |
| sharp / flat | ♯ ♭ in music; too high / too low on the tuner | pointed / level | | |
| bar | a measure | a UI bar, a pub | | |
| key | tonality | a piano key, a password key | | |
| pick | plectrum, or picking strings; "pick" = choose in UI | — | | |
| lock | the string is held in tune | a padlock | | |
| take | one recorded attempt | "take a lesson" | | |
| run | a streak ("best run"), a clean run through a passage | running | | |
| chart | a chord chart; the Chart view | a statistics chart (the Progress screen's charts are "charts" in that sense: check `context`) | | |
| Intonation | instrument setup for the current `Intonation` tool; pitch accuracy in drone/generic lesson contexts | assuming all occurrences mean drone practice, or all mean saddle adjustment | | |
| Next, Again, Slower | on-screen labels and also Siri command words (`ios/Timbre/Intents/PracticeIntents.swift`): one translation serves both | — | | |
| Practice | the tab and the activity | a medical or legal practice | | |
| Feel | the haptic tuning feature, feeling the beat | emotions | | |
