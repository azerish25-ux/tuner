# Czech glossary

Status: The prior app/UI glossary was AI-drafted and AI-reviewed on 2026-10-25. The current 6,083-key lesson addendum below was directly authored and self-checked on 2026-10-26 by `/root/translate_czech_lessons`; it has NOT received independent semantic review, native-human sign-off, or device verification. Prior UI review is not review of these new lesson drafts. Explicit decisions below override conflicting anchors.

## 1. Locale decisions

| Decision | Value |
|---|---|
| Locale code and language | cs — Czech |
| Variant | Standard national language; shared regional table |
| Register (you) | Formal/plural vy; plural imperatives |
| Imperatives and buttons | Short action labels; instructions in the chosen register; spoken hints state the action |
| Readers of unknown gender | Gender-neutral wording; no agreement with unknown argument values |
| Quotation marks | „…“ |
| Apostrophe and ellipsis | Single …; conventional apostrophe |
| Spaces | Ordinary single spaces |
| Digits in literal numbers | ASCII 0–9 |
| Units | Hz, BPM, ¢, XP unchanged; centy; minuty/min; sekundy/s; ms |
| Capitalization | Sentence case |
| Note names in interface | Runtime placeholders only |
| Note names in lessons | Keep C, F♯, B♭, Em, G7 unchanged |
| Accidentals as words | křížek / béčko / dvojitý křížek / dvojité béčko |
| Tuning direction | níže / výše |
| iOS Settings path | Nastavení › Účet Apple › Předplatná |
| Apple feature names | Plocha; zamknutá obrazovka; widget; Živé aktivity; Zkratky; Ovládací centrum; Rodinné sdílení. Apple Watch, Siri, Game Center unchanged. |
| Siri phrases | Natural spoken command; retain every ${…} token. Další / Znovu / Pomaleji |

## 2. Terms

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translate brands or attach endings. |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | Never translate brands or attach endings. |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | Never translate brands or attach endings. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | Unchanged | Never translate brands or attach endings. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Never translate brands or attach endings. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | Unchanged | Never translate brands or attach endings. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Katalogové názvy timbre_catalog_*: kytara, úd, erhu, sitár, tanpura | Use this sense; inflect words naturally, never placeholders. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | Standardní ladění / Drop D / otevřené G / DADGAD | Use this sense; inflect words naturally, never placeholders. |
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | Ladit | Use this sense; inflect words naturally, never placeholders. |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | Výuka | Use this sense; inflect words naturally, never placeholders. |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | Písně | Use this sense; inflect words naturally, never placeholders. |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | Cvičení | Use this sense; inflect words naturally, never placeholders. |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | Pokrok | Use this sense; inflect words naturally, never placeholders. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | Nastavení | Use this sense; inflect words naturally, never placeholders. |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | Dnes | Use this sense; inflect words naturally, never placeholders. |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | Úkol | Use this sense; inflect words naturally, never placeholders. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | Vaše písně | Use this sense; inflect words naturally, never placeholders. |
| Song sheet | A song lesson's chord-and-words page | lessons |  | List s akordy a textem | Use this sense; inflect words naturally, never placeholders. |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | Diagram / Pohled hráče | Use this sense; inflect words naturally, never placeholders. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | Zobrazení akordu / Zobrazení hmatníku | Use this sense; inflect words naturally, never placeholders. |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | Ukažte mi | Use this sense; inflect words naturally, never placeholders. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | Přejeďte struny a nalaďte | Use this sense; inflect words naturally, never placeholders. |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | Ladění podle vibrací / Vibrace | Use this sense; inflect words naturally, never placeholders. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | Do černého | Use this sense; inflect words naturally, never placeholders. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | Trénink sluchu | Use this sense; inflect words naturally, never placeholders. |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | Bordun | Use this sense; inflect words naturally, never placeholders. |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | Tanpura | Use this sense; inflect words naturally, never placeholders. |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | Intonace | Use this sense; inflect words naturally, never placeholders. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | Metronom / Trenažér tempa | Use this sense; inflect words naturally, never placeholders. |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | Akordy / Stupnice | Use this sense; inflect words naturally, never placeholders. |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | Ověření úrovně | Use this sense; inflect words naturally, never placeholders. |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | Hrajte do rytmu | Use this sense; inflect words naturally, never placeholders. |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | Pokus | Use this sense; inflect words naturally, never placeholders. |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | Smyčka A–B / Nastavit A / Nastavit B | Use this sense; inflect words naturally, never placeholders. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | Začátečník / Standardní / Expert | Use this sense; inflect words naturally, never placeholders. |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | Studio (méně náročné) / 3D v reálném čase | Use this sense; inflect words naturally, never placeholders. |
| Haptics | Vibration feedback | Settings | `Haptics` | Haptika | Use this sense; inflect words naturally, never placeholders. |
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ladička | Use this sense; inflect words naturally, never placeholders. |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | naladit | Use this sense; inflect words naturally, never placeholders. |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ladění | Use this sense; inflect words naturally, never placeholders. |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | Naladěno | Use this sense; inflect words naturally, never placeholders. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | níže / výše | Use this sense; inflect words naturally, never placeholders. |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | centy | Use this sense; inflect words naturally, never placeholders. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | potvrzení přesného naladění | Use this sense; inflect words naturally, never placeholders. |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | struna | Use this sense; inflect words naturally, never placeholders. |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ladicí kolík / hlava nástroje | Use this sense; inflect words naturally, never placeholders. |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | referenční tón / referenční výška / Komorní ladění | Use this sense; inflect words naturally, never placeholders. |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperace` | zapsaná výška / Temperace | Use this sense; inflect words naturally, never placeholders. |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | Chromatická / stroboskopická | Use this sense; inflect words naturally, never placeholders. |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | Kapodastr | Use this sense; inflect words naturally, never placeholders. |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | Transponovat / transpozice | Use this sense; inflect words naturally, never placeholders. |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | Názvy tónů / Solmizace / Sargam | Use this sense; inflect words naturally, never placeholders. |
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | pražec / prázdná struna | Use this sense; inflect words naturally, never placeholders. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | prst 1–4; ukazovák, prostředník, prsteník, malík | Use this sense; inflect words naturally, never placeholders. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | akord / hmat akordu / barré | Use this sense; inflect words naturally, never placeholders. |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | durový / mollový / septakord / power akord | Use this sense; inflect words naturally, never placeholders. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | Tónina | Use this sense; inflect words naturally, never placeholders. |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | stupnice / durová stupnice / pentatonický box | Use this sense; inflect words naturally, never placeholders. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | půltón / celý tón / interval / tercie / kvinta / oktáva | Use this sense; inflect words naturally, never placeholders. |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | takt | Use this sense; inflect words naturally, never placeholders. |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | doba / tempo / těžká doba / počítání | Use this sense; inflect words naturally, never placeholders. |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | úhoz / úhoz dolů / úhoz nahoru / tlumený úhoz / tlumení | Use this sense; inflect words naturally, never placeholders. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | trsátko; brnknutí; vybrat (UI) | Use this sense; inflect words naturally, never placeholders. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | prstová hra / hammer-on / pull-off / skluz (slide) / bend / vibrato | Use this sense; inflect words naturally, never placeholders. |
| bowing, open-string bowing | Violin and cello | lessons |  | hra smyčcem / hra smyčcem na prázdných strunách | Use this sense; inflect words naturally, never placeholders. |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | melodie | Use this sense; inflect words naturally, never placeholders. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | kadence / akord V / I–IV–V | Use this sense; inflect words naturally, never placeholders. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | předtaktí | Use this sense; inflect words naturally, never placeholders. |
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | Úvod / Sloka 1 / Refrén / Mezihra / Sólo / Závěr / Dovětek | Use this sense; inflect words naturally, never placeholders. |
| section | A part of a song | lessons 9 |  | část | Use this sense; inflect words naturally, never placeholders. |
| streak | Consecutive days with practice | UI 21 |  | série | Use this sense; inflect words naturally, never placeholders. |
| streak freeze | Saves the streak on a missed day | UI |  | zmrazení série | Use this sense; inflect words naturally, never placeholders. |
| best run | The longest streak so far | Progress | `best run` | nejlepší série | Use this sense; inflect words naturally, never placeholders. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | odznak / úspěch | Use this sense; inflect words naturally, never placeholders. |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | úroveň / hvězdy / XP / Kombo / skóre / kolo | Use this sense; inflect words naturally, never placeholders. |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | vyzvat přítele | Use this sense; inflect words naturally, never placeholders. |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | výzva | Use this sense; inflect words naturally, never placeholders. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | kurz / oddíl / lekce / krok | Use this sense; inflect words naturally, never placeholders. |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | kvíz / nápověda | Use this sense; inflect words naturally, never placeholders. |
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | předplatné / obnovit / zrušit | Use this sense; inflect words naturally, never placeholders. |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | bezplatné zkušební období / konec zkušebního období | Use this sense; inflect words naturally, never placeholders. |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | Ročně / Měsíčně / Navždy | Use this sense; inflect words naturally, never placeholders. |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | Obnovit nákupy | Use this sense; inflect words naturally, never placeholders. |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | platební metoda / problém s platbou | Use this sense; inflect words naturally, never placeholders. |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | Podmínky / Zásady ochrany osobních údajů | Use this sense; inflect words naturally, never placeholders. |

## 3. Course and song names

| English | Translation |
|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Kytara, Ukulele, Baskytara, Housle, Violoncello, Mandolína, Banjo |
| Ear Training, Music Theory, Rhythm, Singing | Trénink sluchu, Hudební teorie, Rytmus, Zpěv |
| Songs | Písně |
| Originals | Autorské písně |
| Standards & Classics | Standardy a klasika |
| Instrument Songbook | Zpěvník pro daný nástroj |

- Established public-domain titles: use established local titles.
- Other traditional songs: retain English unless a shipped localized lesson title already exists.
- Timbre Originals: translate consistently with existing localized lesson titles; never translate sung lyrics.
- A title in prose must exactly match its lesson title and leaderboard. Credits retain names and digit groups; translate connecting words.

## 4. Words that mislead

| English | Translation and distinction |
|---|---|
| Tune | naladit / melodie |
| sharp / flat | křížek / béčko / dvojitý křížek / dvojité béčko; tuning direction: výše / níže |
| bar | takt; not pub |
| key | tónina; not a physical key |
| pick | trsátko; brnknutí; vybrat (UI) |
| lock | potvrzení přesného naladění; not padlock |
| take | pokus; recorded performance |
| run | série / přehrání úseku |
| chart | diagram akordů |
| Intonation | Intonace; pitch accuracy, not saddle adjustment |
| Next, Again, Slower | Další / Znovu / Pomaleji |
| Practice | Cvičení |
| Feel | Vibrace; not emotion |

## 5. Current whole-curriculum lesson addendum — author draft, 2026-10-26

Author: `/root/translate_czech_lessons`. Scope: all 6,083 current publisher English lesson keys, not just the former nine lesson locales. The 59 size-100 whole-lesson batches retain the publisher's complete shared answer contexts and nested arrangement-section contexts. This section records author choices, **not independent approval**.

### Register, notation, and reusable answers

- Formal plural instructions throughout: `Zahrajte`, `Držte`, `Poslouchejte`. Avoid gendered assumptions about the learner.
- Preserve source note/chord spelling, including **B natural as B**, never substitute Czech/German H. H remains H only when it is the source's intentional distractor. Preserve C♯, E♭, Em7, Cmaj7, A5, Roman numerals, digit groups, placeholders, and source line breaks. Written `sharp`/`flat` become `s křížkem`/`s béčkem`; do not introduce accidental symbols where the source spells them out.
- `The first` → `První`, `The second` → `Druhá ukázka`, `The third` → `Třetí`, `The last` → `Poslední`. They refer to the order of the **musical material**, never answer-button placement. `std-all-through-the-night` options are third, first, last, in that source order.
- Shared `One` → `Jeden / jedna`, `Two` → `Dva / dvě`: explicit grammatical variants cover masculine tones/bars and feminine notes/beats. Other quantity labels use ordinary number words. These remain stand-alone numeric labels, including count/repetition questions; native editorial review of the paired forms remains desirable.
- Shared `And this one?` → `A tady?`, avoiding gender agreement across chords and finger choices. `Same`/`Different` → `Stejný`/`Jiný` in their actual tone/chord contexts. `Up`/`Down` → `Nahoru`/`Dolů` for both pitch and picking direction.
- `Second`, `Third`, `Fourth` are current **interval-only** keys: `Sekunda`, `Tercie`, `Kvarta`. Explicit finger choices use `první/druhý/třetí/čtvrtý prst` and numbered fingers retain digits.
- `The major scale` → `Durová stupnice` in both title and answer roles. Its quiz prompt asks which scale has the given pattern, so all options use nominative labels rather than an accusative that would break the shared title.
- Shared long–short options are `Dlouze, pak krátce` and `Krátce, pak dlouze`; associated prompts ask how the notes/parts sound, avoiding an incompatible sentence completion.
- `bar` and `measure` both mean `takt`. The source question specifically testing their English synonymy names both English words, with `Measure (takt)` as its answer; it does not invent two different Czech musical concepts.

### Music and instrument terminology

| Source sense | Current Czech lesson choice |
|---|---|
| major/minor chord | durový/mollový; named chords C dur, A moll |
| major/minor interval | velký/malý; `Major and minor intervals` → `Velké a malé intervaly` |
| perfect fourth/fifth | čistá kvarta/kvinta |
| unison | unisono for matching voices; prima for the interval; shared answer `Unisono (prima)` |
| triad, root, third, fifth | kvintakord, základní tón, tercie, kvinta |
| power chord | power akord, consistently; root and fifth without a third |
| major/minor seventh chord | velký durový / malý mollový septakord |
| dominant seventh chord | dominantní septakord |
| diminished/augmented | zmenšený/zvětšený |
| instrument bridge | kobylka; split title `The instrument bridge` → `Kobylka nástroje` |
| song bridge / interlude | mezihra, including nested arrangement labels; never kobylka |
| down-bow / up-bow | smyk od žabky / smyk ke žabce |
| frog / bow stick / hair | žabka / hůlka / žíně |
| scroll / chinrest / tailpiece | šnek / podbradek / struník |
| fine tuner / endpin | dolaďovač / bodec |
| shift / hand frame | výměna polohy, přesun / tvar ruky |
| high 2 / low 2 | vysoký prst 2 / nízký prst 2 |
| natural note | tón bez posuvky |
| beating between pitches | rázy |
| Travis picking / chord melody | Travisova technika / melodie v akordech |
| short bend (undershot pitch) | nedotažený bend, not a short-duration bend |
| walking bass / groove | kráčející bas / rytmus, rytmická linka, by context |
| mandolin string pair / course | pár strun / sbor |
| banjo head / finger picks | blána / prstýnková trsátka |
| thumb pick / pinch | palcové trsátko / současné brnknutí |
| forward roll / alternating thumb roll | dopředný rozklad / rozklad se střídavým palcem |
| clawhammer / crosspicking | established technique names retained where the whole source is the name; explanation in Czech |
| tie / slur | ligatura for duration; legato / legatový oblouček for one bow |
| cadence | kadence; autentická, plagální, poloviční, klamná |
| downbeat / backbeat | první/těžká doba / důraz na druhou a čtvrtou dobu |
| lip trill | chvění rtů |
| unit / course / lesson | oddíl / kurz / lekce |

### Counting and memory aids

- `D`/`U` strum notation is retained, matching diagrams: down/dolů and up/nahoru. Full symbolic patterns are held candidates, not blanket-approved English exceptions.
- Relative solmization remains `do, re, mi, fa, sol, la, ti, do`. In particular `ti` follows the source relative-solmization system; do not silently switch to a fixed-note system. Whole solmization-only strings are held candidates with per-key reasons.
- Eighth counts: `1 a 2 a`; sixteenth counts: `1 e a e`, or `raz-e-a-e` when the source spells numbers. These are four evenly spaced syllables. A final subdivision is identified as `poslední e` where necessary.
- Triplet count: `1-ta-ka, 2-ta-ka`, three equal parts; swing leaves out `ta` and plays the number and `ka`. This is a consistent Czech counting adaptation, not a claim that this is the sole conventional Czech pedagogy.
- Shuffle mnemonic: `hou-py, hou-py`. Banjo `Bum-ditty` and `Bum, dit, ty` retain their exact rhythmic syllables.
- String mnemonics: EADGBE → `Eva a David geniálně brnkají evergreeny`; GCEA → `Gustav cvičí energicky akordy`; EADG → `Eva a David grilují`; GDAE → `Gustav doma asi experimentuje`; CGDA → `Cyril geniálně diriguje ansámbl`.
- Treble lines EGBDF → `Eva griluje, Bára dělá fazole`; bass lines GBDFA → `Gustav brnká, Dana fotí Annu`; bass spaces ACEG → `Alena cvičí etudy geniálně`. Treble spaces retain FACE, explained as the English word for obličej.
- An interval's letter count includes both endpoints. A fifth is not translated as five successive steps above the starting letter.

### Source clarifications and title/lyric handling

- Century-wide `1700s` (also `1800s`) is rendered as the century beginning in that source year, not a ten-year decade. True decade references such as `1580s`, `1880s`, `1890s`, `1950s` explicitly say the decade beginning in that year, preserving the source digit group.
- Violin “level with the floor” means horizontally aligned, not held at floor height. Bow contact halfway between bridge and fingerboard explicitly retains the midpoint.
- The hammer-on setup distinguishes the finger holding the first fret from the picking hand; an undershot bend means insufficient pitch rise. The retired tremolo key is absent; `Tremolo through long notes` keeps its current meaning.
- Song titles below are the author's consistent target forms; preservation of a whole original title is a **candidate** requiring independent approval. Localized traditional/hymn titles are editorial choices, not independently certified canonical editions.
- A title quoted in instructional prose retains its target title spelling, using a wrapper such as `v písni` rather than inflecting the title. A person's name within prose may inflect normally.
- Actual sung lyric cues remain in the source language, including English, German, and Latin. Performance instructions around them are Czech. `Fly`, `Wide`, `Boat`, `Town`, and sung `Bethlehem` are held whole-string lyric-identification candidates, not untranslated instructional words.
- Credits preserve author names and source digit groups; connecting words and `Traditional` are translated. Proper names, notation, technical loans, and lyric cues are assessed per complete string, never approved globally by token.

### Current song-title map (author draft)

This table is transcribed from the authored batch values; it is not an independent review result.

| English source title | Czech draft |
|---|---|
| Mary Had a Little Lamb: three notes | Mary Had a Little Lamb: tři tóny |
| Ode to Joy | Óda na radost |
| When the Saints Go Marching In | Až svatí půjdou |
| Amazing Grace | Úžasná milost |
| Greensleeves: the chords | Greensleeves: akordy |
| Greensleeves: the melody | Greensleeves: melodie |
| Oh! Susanna: the verse | Ó, Zuzano: sloka |
| Oh! Susanna: the chorus | Ó, Zuzano: refrén |
| Your arrangement | Vaše aranžmá |
| Down by the Riverside: your arrangement | Down by the Riverside: vaše aranžmá |
| Row, Row, Row Your Boat | Row, Row, Row Your Boat |
| Twinkle, Twinkle, Little Star | Sviť, hvězdičko, sviť |
| Aura Lee | Aura Lee |
| Camptown Races | Camptown Races |
| Red River Valley | Červená řeka |
| Amazing Grace, fingerpicked | Úžasná milost vybrnkávaně |
| The Water Is Wide | The Water Is Wide |
| Molly Malone | Molly Malone |
| The Skye Boat Song | The Skye Boat Song |
| Ode to Joy on bass | Óda na radost na baskytaře |
| Walking the blues in A | Kráčející blues v A |
| Lightly Row | Lightly Row |
| Boil Them Cabbage Down | Boil Them Cabbage Down |
| Minuet in G | Menuet v G |
| Old Joe Clark | Old Joe Clark |
| Soldier's Joy | Soldier's Joy |
| Arkansas Traveler | Arkansas Traveler |
| Brahms' Lullaby | Brahmsova ukolébavka |
| Au clair de la lune | Au clair de la lune |
| The Swan | Labuť |
| Angeline the Baker | Angeline the Baker |
| Cripple Creek | Cripple Creek |
| Cumberland Gap | Cumberland Gap |
| Shady Grove | Shady Grove |
| Skip to My Lou | Skip to My Lou |
| Twinkle Twinkle Little Star | Sviť, hvězdičko, sviť |
| Auld Lang Syne | Auld Lang Syne |
| Shenandoah | Shenandoah |
| Frère Jacques | Bratře Kubo |
| Old MacDonald Had a Farm | Strýček Donald farmu měl |
| Bobby Shafto | Bobby Shafto |
| Canon in D | Kánon v D |
| Largo, New World Symphony | Largo ze symfonie Z Nového světa |
| In the Hall of the Mountain King | V sluji Krále hor |
| Für Elise | Pro Elišku |
| My Country, 'Tis of Thee | My Country, 'Tis of Thee |
| Simple Gifts | Simple Gifts |
| Good King Wenceslas | Dobrý král Václav |
| Deck the Halls | Zdobte síně |
| We Wish You a Merry Christmas | Přejeme vám veselé Vánoce |
| Joy to the World | Raduj se, světe |
| Silent Night | Tichá noc |
| Eine kleine Nachtmusik | Malá noční hudba |
| Danny Boy (Londonderry Air) | Danny Boy (Londonderry Air) |
| Mozart's Symphony No. 40 | Mozartova symfonie č. 40 |
| Kite Weather | Počasí na draka |
| Porchlight | Světlo na verandě |
| Moth and Ember | Můra a žhavý uhlík |
| Low Tide Radio | Rádio za odlivu |
| Dust on the Dashboard | Prach na palubní desce |
| Lantern Hill | Lucernový vrch |
| Gravel Road Two-Step | Two-step po štěrkové cestě |
| First Frost | První mráz |
| Hammock Season | Sezona houpacích sítí |
| Glow-in-the-Dark Stars | Hvězdy svítící ve tmě |
| Sparkler Season | Sezona prskavek |
| Roller Rink | Bruslařská dráha |
| Echo Canyon | Kaňon ozvěn |
| Open Windows | Otevřená okna |
| Scoreboard Lights | Světla výsledkové tabule |
| Rust Belt Shuffle | Shuffle z rezavého pásu |
| Carousel at Closing Time | Kolotoč před zavíračkou |
| Cedar Smoke | Cedrový kouř |
| Rain on the Skylight | Déšť na světlíku |
| Neon Laundromat | Neonová prádelna |
| Late Checkout | Pozdní odhlášení |
| Saltwater Sunday | Slaná neděle |
| Pocket Change | Drobné v kapse |
| Kitchen Slow Dance | Ploužák v kuchyni |
| Houseplants | Pokojovky |
| Static on Channel Nine | Šum na devátém kanálu |
| Basement Weather | Počasí ve sklepě |
| Jukebox Moon | Měsíc z jukeboxu |
| Boardwalk Comet | Kometa na promenádě |
| Mile Marker Zero | Nultý milník |
| Last Bell | Poslední zvonění |
| Copper Wire | Měděný drát |
| Cold Lake | Studené jezero |
| Parking Lot Cathedral | Katedrála na parkovišti |
| Halogen | Halogen |
| Keeper's Daughter | Dcera strážce |
| Snow Globe Town | Město ve sněžítku |
| Thistle and Thread | Bodlák a nit |
| Ghost Light | Přízračné světlo |
| Late Bus Home | Pozdní autobus domů |
| Glass Satellites | Skleněné satelity |
| Market Day | Tržní den |
| Velvet Hour | Sametová hodina |
| Rooftop Choir | Sbor na střeše |
| Slow Motion Strobe | Zpomalený stroboskop |
| Bright Side of the Block | Slunná strana bloku |
| Over You Soon | Brzy na tebe zapomenu |
| Spray Paint Sunrise | Východ slunce ve spreji |
| Constellation Prize | Cena souhvězdí |
| She'll Be Coming 'Round the Mountain | She'll Be Coming 'Round the Mountain |
| Loch Lomond | Loch Lomond |
| All Through the Night | All Through the Night |
| O Christmas Tree | Ó, jedličko |
| O Come, All Ye Faithful | Ó, křesťané, pospěšte |
| The First Noel | The First Noel |
| Scotland the Brave | Scotland the Brave |
| Korobeiniki | Korobějniki |
| The Blue Danube | Na krásném modrém Dunaji |
| Can-can | Kankán |
| The Entertainer | The Entertainer |
| The Liberty Bell | Zvon svobody |
| Carmen: Prelude | Carmen: Předehra |
| Morning Mood | Jitřní nálada |
| Hark! The Herald Angels Sing | Slyš, jak andělský zpěv zní |
| Away in a Manger | V jesličkách |
| O Little Town of Bethlehem | Ó, městečko Betléme |
| It Came Upon the Midnight Clear | It Came Upon the Midnight Clear |
| Once in Royal David's City | Once in Royal David's City |
| In the Bleak Midwinter | In the Bleak Midwinter |
| The Holly and the Ivy | Cesmína a břečťan |
| Angels from the Realms of Glory | Andělé z říše slávy |
| O God, Our Help in Ages Past | Bože, naše dávná oporo |
| Holy, Holy, Holy | Svatý, svatý, svatý |
| Abide with Me | Zůstaň se mnou |
| Nearer, My God, to Thee | Blíž k tobě, Bože můj |
| For the Beauty of the Earth | Za krásu země |
| Home! Sweet Home! | Domove! Sladký domove! |
| Hard Times Come Again No More | Těžké časy, už se nevracejte |
| The Last Rose of Summer | Poslední růže léta |
| Jupiter | Jupiter |
| Spring | Jaro |
| Rondo alla Turca | Rondo alla Turca |
| The Stars and Stripes Forever | Hvězdy a pruhy navždy |

## Independently reviewed lesson overrides

The following source-bound decisions supersede conflicting older lesson anchors above.

# Czech glossary reconciliation

Read-state source: frozen author `final-glossary.md`; do not modify its bytes. The final map and the following review overrides supersede author-draft choices for parent integration.

## Required updates

- `One` → `Jedna`; `Two` → `Dva`. These are independent citation/counting labels across all quantity and numbered-beat roles, not slash variants or noun-specific gender agreement. Do not concatenate them with an inflected noun. Other numeric labels remain Tři/Čtyři/Pět etc.
- Bar/measure quiz: ask `Co v hudbě znamená anglické slovo „bar“?`; choices Doba/Pomlka/Takt; explain that English bar and measure both mean takt. Remove the glossary's prior `Measure (takt)` exception. These three bare keys each occur only in this quiz; no false shared-key defect is alleged.
- Ninth interval: `Nóna` (long ó), consistent with nónové terminology. Exact source and verification references are in correction L77fce1a6ed.
- `Half its value` in the dot quiz is nominal `Polovina její hodnoty` coordinated with `Jaká hodnota se tečkou přidává k notě?`.
- `The open fifth string` is the standalone shared label `Prázdná pátá struna` rather than case-specific `Z prázdné páté struny`.

## Clarified sense rules

- Picking/strumming hand must name the hand that plucks/strums, not the ambiguous generic hrající ruka when the other hand has a simultaneous task. Fretting hand/fingers stay explicit where the source names them.
- Open means a prázdná struna; a shorthand prázdné E is acceptable for an identified open-string pitch, but explanatory introductions must not call all open strings empty tones.
- Four/six chord means akord čtvrtého/šestého stupně, not the fourth/sixth chord performed.
- Lower/upper string register means hlubší/výše znějící, not necessarily physical below/above. Fret motion, bow direction and pitch direction stay distinct.
- Six quick counts in 6/8 are osminy/osminové pulzy; two big beats remain dvě velké doby. Intentionally wrong six-equal-beats distractors remain wrong, not silently corrected.
- An octave's eight letters/notes count both endpoints; do not imply eight whole-tone distances.
- A melodic approach may plynule vést/stoupat into a note without instructing a physical slide onto an open string.

## Retained reviewed decisions

Formal plural vy, international B natural as B, symbolic accidentals/chords and exact digits/newlines; intentional H distractors remain H. Named chords use dur/moll while interval qualities use velký/malý/čistý. Bare Second/Third/Fourth are interval-only. Up/Down remain Nahoru/Dolů in all pitch and picking roles. The bridge is song Mezihra; The instrument bridge is Kobylka nástroje. Tie uses ligatura; bow slur uses legato/legatový oblouček. Bow frog is žabka. Root is základní tón. Current tremolo-long-note source is retained; the retired key is absent.

All listed string/staff mnemonics were checked in actual contexts against their ordered letter sequences. Eighth `1 a`, sixteenth `1 e a e`, triplet `1-ta-ka`, shuffle `hou-py` and literal banjo bum-ditty are consistent adaptations, not a claim of the only native teaching tradition. Solfège retains source-relative ti.

Song identifiers were reviewed in primary and every shared title/body/recognition/arrangement context. Existing translated titles remain internally consistent; retained titles and credits have individual reasons in invariants.json. Literal sung English/German/Latin fragments are not substituted with translated title words. Native repertoire naming and pronunciation remain optional editorial/device follow-ups; no new blocking title mismatch was found.
