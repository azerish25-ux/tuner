# Slovak glossary

Status: AI-drafted and AI-reviewed, 2026-10-25. Native-human sign-off and device verification pending. Shipped labels inspected; explicit decisions below override conflicting anchors.

## 1. Locale decisions

| Decision | Value |
|---|---|
| Locale code and language | sk — Slovak |
| Variant | Standard national language; shared regional table |
| Register (you) | Formal/plural vy; plural imperatives |
| Imperatives and buttons | Short action labels; instructions in the chosen register; spoken hints state the action |
| Readers of unknown gender | Gender-neutral wording; no agreement with unknown argument values |
| Quotation marks | „…“ |
| Apostrophe and ellipsis | Single …; conventional apostrophe |
| Spaces | Ordinary single spaces |
| Digits in literal numbers | ASCII 0–9 |
| Units | Hz, BPM, ¢, XP unchanged; centy; minúty/min; sekundy/s; ms |
| Capitalization | Sentence case |
| Note names in interface | Runtime placeholders only |
| Note names in lessons | Keep C, F♯, B♭, Em, G7 unchanged |
| Accidentals as words | krížik / béčko / dvojitý krížik / dvojité béčko |
| Tuning direction | nižšie / vyššie |
| iOS Settings path | Nastavenia › Apple účet › Predplatné |
| Apple feature names | Plocha; zamknutá obrazovka; widget; Aktivity naživo; Skratky; Ovládacie centrum; Rodinné zdieľanie. Apple Watch, Siri, Game Center unchanged. |
| Siri phrases | Natural spoken command; retain every ${…} token. Ďalej / Znova / Pomalšie |

## 2. Terms

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translate brands or attach endings. |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | Never translate brands or attach endings. |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | Never translate brands or attach endings. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | Unchanged | Never translate brands or attach endings. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Never translate brands or attach endings. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | Unchanged | Never translate brands or attach endings. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Katalógové názvy timbre_catalog_*: gitara, úd, erhu, sitár, tanpura | Use this sense; inflect words naturally, never placeholders. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | Štandardné ladenie / Drop D / otvorené G / DADGAD | Use this sense; inflect words naturally, never placeholders. |
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | Ladiť | Use this sense; inflect words naturally, never placeholders. |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | Výučba | Use this sense; inflect words naturally, never placeholders. |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | Piesne | Use this sense; inflect words naturally, never placeholders. |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | Cvičenie | Use this sense; inflect words naturally, never placeholders. |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | Pokrok | Use this sense; inflect words naturally, never placeholders. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | Nastavenia | Use this sense; inflect words naturally, never placeholders. |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | Dnes | Use this sense; inflect words naturally, never placeholders. |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | Úloha | Use this sense; inflect words naturally, never placeholders. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | Vaše piesne | Use this sense; inflect words naturally, never placeholders. |
| Song sheet | A song lesson's chord-and-words page | lessons |  | List s akordmi a textom | Use this sense; inflect words naturally, never placeholders. |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | Diagram / Pohľad hráča | Use this sense; inflect words naturally, never placeholders. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | Zobrazenie akordu / Zobrazenie hmatníka | Use this sense; inflect words naturally, never placeholders. |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | Ukážte mi | Use this sense; inflect words naturally, never placeholders. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | Prejdite struny a nalaďte | Use this sense; inflect words naturally, never placeholders. |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | Ladenie podľa vibrácií / Vibrácie | Use this sense; inflect words naturally, never placeholders. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | Do čierneho | Use this sense; inflect words naturally, never placeholders. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | Tréning sluchu | Use this sense; inflect words naturally, never placeholders. |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | Bordún | Use this sense; inflect words naturally, never placeholders. |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | Tanpura | Use this sense; inflect words naturally, never placeholders. |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | Intonácia | Use this sense; inflect words naturally, never placeholders. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | Metronóm / Trenažér tempa | Use this sense; inflect words naturally, never placeholders. |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | Akordy / Stupnice | Use this sense; inflect words naturally, never placeholders. |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | Overenie úrovne | Use this sense; inflect words naturally, never placeholders. |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | Hrajte do rytmu | Use this sense; inflect words naturally, never placeholders. |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | Pokus | Use this sense; inflect words naturally, never placeholders. |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | Slučka A–B / Nastaviť A / Nastaviť B | Use this sense; inflect words naturally, never placeholders. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | Začiatočník / Štandardné / Expert | Use this sense; inflect words naturally, never placeholders. |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | Štúdio (menej náročné) / 3D v reálnom čase | Use this sense; inflect words naturally, never placeholders. |
| Haptics | Vibration feedback | Settings | `Haptics` | Haptika | Use this sense; inflect words naturally, never placeholders. |
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | ladička | Use this sense; inflect words naturally, never placeholders. |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | naladiť | Use this sense; inflect words naturally, never placeholders. |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | ladenie | Use this sense; inflect words naturally, never placeholders. |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | Naladené | Use this sense; inflect words naturally, never placeholders. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | nižšie / vyššie | Use this sense; inflect words naturally, never placeholders. |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | centy | Use this sense; inflect words naturally, never placeholders. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | potvrdenie presného naladenia | Use this sense; inflect words naturally, never placeholders. |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | struna | Use this sense; inflect words naturally, never placeholders. |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | ladiaci kolík / hlava nástroja | Use this sense; inflect words naturally, never placeholders. |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | referenčný tón / referenčná výška / Komorné ladenie | Use this sense; inflect words naturally, never placeholders. |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperácia` | zapísaná výška / Temperácia | Use this sense; inflect words naturally, never placeholders. |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | Chromatická / stroboskopická | Use this sense; inflect words naturally, never placeholders. |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | Kapodaster | Use this sense; inflect words naturally, never placeholders. |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | Transponovať / transpozícia | Use this sense; inflect words naturally, never placeholders. |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | Názvy tónov / Solmizácia / Sargam | Use this sense; inflect words naturally, never placeholders. |
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | pražec / prázdna struna | Use this sense; inflect words naturally, never placeholders. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | prst 1–4; ukazovák, prostredník, prstenník, malíček | Use this sense; inflect words naturally, never placeholders. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | akord / hmat akordu / barré | Use this sense; inflect words naturally, never placeholders. |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | durový / molový / septakord / power akord | Use this sense; inflect words naturally, never placeholders. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | Tónina | Use this sense; inflect words naturally, never placeholders. |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | stupnica / durová stupnica / pentatonický box | Use this sense; inflect words naturally, never placeholders. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | poltón / celý tón / interval / tercia / kvinta / oktáva | Use this sense; inflect words naturally, never placeholders. |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | takt | Use this sense; inflect words naturally, never placeholders. |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | doba / tempo / ťažká doba / počítanie | Use this sense; inflect words naturally, never placeholders. |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | úder / úder nadol / úder nahor / tlmený úder / tlmenie | Use this sense; inflect words naturally, never placeholders. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | brnkadlo; brnknutie; vybrať (UI) | Use this sense; inflect words naturally, never placeholders. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | prstová hra / hammer-on / pull-off / slide / bend / vibrato | Use this sense; inflect words naturally, never placeholders. |
| bowing, open-string bowing | Violin and cello | lessons |  | hra sláčikom / hra sláčikom na prázdnych strunách | Use this sense; inflect words naturally, never placeholders. |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | melódia | Use this sense; inflect words naturally, never placeholders. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | kadencia / akord V / I–IV–V | Use this sense; inflect words naturally, never placeholders. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | predtaktie | Use this sense; inflect words naturally, never placeholders. |
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | Úvod / Sloha 1 / Refrén / Medzihra / Sólo / Záver / Dodatok | Use this sense; inflect words naturally, never placeholders. |
| section | A part of a song | lessons 9 |  | časť | Use this sense; inflect words naturally, never placeholders. |
| streak | Consecutive days with practice | UI 21 |  | séria | Use this sense; inflect words naturally, never placeholders. |
| streak freeze | Saves the streak on a missed day | UI |  | zmrazenie série | Use this sense; inflect words naturally, never placeholders. |
| best run | The longest streak so far | Progress | `best run` | najlepšia séria | Use this sense; inflect words naturally, never placeholders. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | odznak / úspech | Use this sense; inflect words naturally, never placeholders. |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | úroveň / hviezdy / XP / Kombo / skóre / kolo | Use this sense; inflect words naturally, never placeholders. |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | vyzvať priateľa | Use this sense; inflect words naturally, never placeholders. |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | výzva | Use this sense; inflect words naturally, never placeholders. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | kurz / časť / lekcia / krok | Use this sense; inflect words naturally, never placeholders. |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | kvíz / pomôcka | Use this sense; inflect words naturally, never placeholders. |
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | predplatné / obnoviť / zrušiť | Use this sense; inflect words naturally, never placeholders. |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | bezplatné skúšobné obdobie / koniec skúšobného obdobia | Use this sense; inflect words naturally, never placeholders. |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | Ročne / Mesačne / Navždy | Use this sense; inflect words naturally, never placeholders. |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | Obnoviť nákupy | Use this sense; inflect words naturally, never placeholders. |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | spôsob platby / problém s platbou | Use this sense; inflect words naturally, never placeholders. |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | Podmienky / Zásady ochrany osobných údajov | Use this sense; inflect words naturally, never placeholders. |

## 3. Course and song names

| English | Translation |
|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Gitara, Ukulele, Basgitara, Husle, Violončelo, Mandolína, Banjo |
| Ear Training, Music Theory, Rhythm, Singing | Tréning sluchu, Hudobná teória, Rytmus, Spev |
| Songs | Piesne |
| Originals | Autorské piesne |
| Standards & Classics | Štandardy a klasika |
| Instrument Songbook | Spevník pre daný nástroj |

- Established public-domain titles: use established local titles.
- Other traditional songs: retain English unless a shipped localized lesson title already exists.
- Timbre Originals: translate consistently with existing localized lesson titles; never translate sung lyrics.
- A title in prose must exactly match its lesson title and leaderboard. Credits retain names and digit groups; translate connecting words.

## 4. Words that mislead

| English | Translation and distinction |
|---|---|
| Tune | naladiť / melódia |
| sharp / flat | krížik / béčko / dvojitý krížik / dvojité béčko; tuning direction: vyššie / nižšie |
| bar | takt; not pub |
| key | tónina; not a physical key |
| pick | brnkadlo; brnknutie; vybrať (UI) |
| lock | potvrdenie presného naladenia; not padlock |
| take | pokus; recorded performance |
| run | séria / prehratie úseku |
| chart | diagram akordov |
| Intonation | Intonácia; pitch accuracy, not saddle adjustment |
| Next, Again, Slower | Ďalej / Znova / Pomalšie |
| Practice | Cvičenie |
| Feel | Vibrácie; not emotion |

## Lesson author decisions, current draft (independent review pending)

Use formal/plural instructions (vy) consistently. Preserve the curriculum's Latin A–G note naming, including B; do not substitute the regional H convention because displays and quiz notation remain source-bound.

Original song titles must be translated consistently across labels and lesson references:
- Letters in a Shoebox → Listy v krabici od topánok
- Dust on the Dashboard → Prach na palubnej doske
- Low Tide Radio → Rádio pri odlive
- Kite Weather → Počasie na šarkany (inflect naturally in sentences)

Songs → Piesne; Originals → Autorské piesne. Navigation prose: v časti Piesne, v kategórii Autorské piesne. Major/minor musical quality → dur/mol. Down/up physical or pitch direction → nadol/nahor; rhythmic spoken pattern may use shorter dolu/hore. Beat → doba; bar → takt; eighth notes → osminové noty; chord progression → akordový sled.

E–A–D–G–B–E mnemonic adaptation: Eva a Dávid grilujú bez elektriny. Each initial is bound to the original string order. This is an author proposal, not independent approval.
- Halogen → Halogén
- Ghost Light → Svetlo duchov
- Sharp in prose → krížik, sharpened note names G sharp/F sharp → Gis/Fis. This does not replace literal displayed G♯/F♯ notation symbols.
- Traditional song names When the Saints Go Marching In, Amazing Grace, Greensleeves and Clementine are proposed retained work identifiers. Every exact-source row is held for individual independent review; retention is not a blanket exemption for instructions, generic titles or credits such as Traditional spiritual.
- Rust Belt Shuffle → Shuffle hrdzavého pásu
- Basement Weather → Počasie v pivnici
- Power chord → kvintový akord; palm muting → tlmenie dlaňou; seventh chord → septakord; sus chord → akord sus (explained as akord so zadržaným tónom).
- Shuffle rhythm mnemonic hum-pty, dum-pty → dáá-da, dáá-da, explicitly illustrating long-short duration without leaving English verse.
- Glass Satellites → Sklenené satelity
- Barre → barré; pentatonic box → pentatonický box; Travis picking → Travisovo vybrnkávanie; p/i/m/a preserve the standard Spanish-derived guitar notation. Finger names: palec, ukazovák, prostredník, prstenník, malíček.
- Porchlight → Svetlo na verande
- Neon Laundromat → Neónová práčovňa
- Hammer-on → príklep; pull-off → odtrh; slide → sklz; turnaround → návratový motív or descriptive Návrat na začiatok; quick change → skorá zmena akordu, explained by the actual fourth-degree chord in bar 2.
- Saltwater Sunday → Slaná nedeľa
- Same/Different listening alternatives → Rovnaké/Odlišné, neutral plural for compared sounds; shared context requires independent review.
- Spray Paint Sunrise → Úsvit nasprejovaný farbou
- Sparkler Season → Sezóna prskaviek
- Sixteenth count one-e-and-a → raz-e-a-da; preserve four syllables/subdivisions, matching dva-e-a-da. Country boom-chick → bum-čik. Reggae offbeat here explicitly means weak beats two and four, rendered ľahké doby, not medzi dobami.
- Gravel Road Two-Step → Two-step na štrkovej ceste
- Lantern Hill → Lampášový vrch
- Triad → trojzvuk; inversion → obrat; root-position → základný tvar/poloha; CAGED stays the acronym formed by exact source chord letters C A G E D.
- Roller Rink → Korčuliarsky parket
- Late Checkout → Neskorý odchod z hotela
- Major seventh chord → veľký durový septakord; minor seventh chord → malý molový septakord; major/minor seventh interval → veľká/malá septima. B flat in this app’s A–G notation → znížené B, avoiding local B/H ambiguity and preserving accidental-glyph guard.
- Joy to the World → Radosť svetu
- Market Day → Trhový deň
- A Dorian → dórsky modus od A; D Mixolydian → mixolýdický modus od D. Descriptive phrasing distinguishes the mode name from a key quality while preserving the same tonic.
- Slow Motion Strobe → Spomalený stroboskop
- Jukebox Moon → Jukeboxový mesiac
- Song-form bridge → mostík (not instrument kobylka); tag → opakovaný záver; fill → výplň; texture in arranging → spôsob sprievodu.
- Ukulele G C E A mnemonic proposal: Gorila cíti egrešovú arómu. Exact initials G C E A preserved; independent review pending.
- Bass E A D G mnemonic: Eva a Dávid grilujú. Exact initials preserved; independent review pending.
- Re-entrant tuning → reentrantné ladenie, with explicit high-G/lower-C explanation. Rest stroke → opretý úder, explicitly resting on the adjacent thicker string.
- Violin → husle; bow → sláčik; frog → žabka; bow stick → prút; bow hair → vlásie; rosin → kolofónia; chin rest → podbradník; tailpiece → strunník.
- Down-bow → ťah od žabky; up-bow → ťah k žabke. Directions are explicitly tied to frog/tip rather than implying a vertical arm motion.
- Violin G D A E mnemonic: Gorila dnes asi experimentuje. Inclusive fifth/octave counting is explicitly clarified when the source describes letter-name distances.
- High 2 / low 2 → vysoký prst 2 / nízky prst 2, not second hand position. Preserve each repeated source digit even where Slovak could naturally coalesce it.
- Cello → violončelo; endpin → bodec; shift → výmena polohy; fourth position → štvrtá poloha. Distinguish a hand position from a low/high placement of finger 2.
- Slur → legatový oblúčik / legato jedným ťahom; do not confuse with a duration tie. The Swan → Labuť; Brahms’ Lullaby → Brahmsova uspávanka.
- Cello C G D A mnemonic: Cirkusová gorila dáva autogramy. Exact initials retained, review pending.
