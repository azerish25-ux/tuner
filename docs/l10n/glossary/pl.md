# Polish glossary

Status: AI-drafted and AI-reviewed, 2026-10-25. Native-human sign-off and device verification pending. Shipped labels inspected; explicit decisions below override conflicting anchors.

## 1. Locale decisions

| Decision | Value |
|---|---|
| Locale code and language | pl — Polish |
| Variant | Standard national language; shared regional table |
| Register (you) | Informal ty; singular imperatives; avoid gendered past forms |
| Imperatives and buttons | Short action labels; instructions in the chosen register; spoken hints state the action |
| Readers of unknown gender | Gender-neutral wording; no agreement with unknown argument values |
| Quotation marks | „…” |
| Apostrophe and ellipsis | Single …; conventional apostrophe |
| Spaces | Ordinary single spaces |
| Digits in literal numbers | ASCII 0–9 |
| Units | Hz, BPM, ¢, XP unchanged; centy; minuty/min; sekundy/s; ms |
| Capitalization | Sentence case |
| Note names in interface | Runtime placeholders only |
| Note names in lessons | Keep C, F♯, B♭, Em, G7 unchanged |
| Accidentals as words | krzyżyk / bemol / podwójny krzyżyk / podwójny bemol |
| Tuning direction | za nisko / za wysoko |
| iOS Settings path | Ustawienia › Konto Apple › Subskrypcje |
| Apple feature names | Ekran początkowy; ekran blokady; widżet; Aktywności na żywo; Skróty; Centrum sterowania; Chmura rodzinna. Apple Watch, Siri, Game Center unchanged. |
| Siri phrases | Natural spoken command; retain every ${…} token. Dalej / Jeszcze raz / Wolniej |

## 2. Terms

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translate brands or attach endings. |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | Never translate brands or attach endings. |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | Never translate brands or attach endings. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | Unchanged | Never translate brands or attach endings. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Never translate brands or attach endings. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | Unchanged | Never translate brands or attach endings. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | Nazwy katalogowe timbre_catalog_*: gitara, oud, erhu, sitar, tanpura | Use this sense; inflect words naturally, never placeholders. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | Strój standardowy / Drop D / otwarty G / DADGAD | Use this sense; inflect words naturally, never placeholders. |
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | Strój | Use this sense; inflect words naturally, never placeholders. |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | Nauka | Use this sense; inflect words naturally, never placeholders. |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | Piosenki | Use this sense; inflect words naturally, never placeholders. |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | Ćwiczenia | Use this sense; inflect words naturally, never placeholders. |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | Postępy | Use this sense; inflect words naturally, never placeholders. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | Ustawienia | Use this sense; inflect words naturally, never placeholders. |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | Dziś | Use this sense; inflect words naturally, never placeholders. |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | Zadanie | Use this sense; inflect words naturally, never placeholders. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | Twoje piosenki | Use this sense; inflect words naturally, never placeholders. |
| Song sheet | A song lesson's chord-and-words page | lessons |  | Karta z akordami i tekstem | Use this sense; inflect words naturally, never placeholders. |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | Diagram / Widok muzyka | Use this sense; inflect words naturally, never placeholders. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | Widok akordu / Widok gryfu | Use this sense; inflect words naturally, never placeholders. |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | Pokaż mi | Use this sense; inflect words naturally, never placeholders. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | Przeciągnij po strunach, aby nastroić | Use this sense; inflect words naturally, never placeholders. |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | Strojenie wibracjami / Wibracje | Use this sense; inflect words naturally, never placeholders. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | Dziesiątka | Use this sense; inflect words naturally, never placeholders. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | Trening słuchu | Use this sense; inflect words naturally, never placeholders. |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | Burdon | Use this sense; inflect words naturally, never placeholders. |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | Tanpura | Use this sense; inflect words naturally, never placeholders. |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | Intonacja | Use this sense; inflect words naturally, never placeholders. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | Metronom / Trener tempa | Use this sense; inflect words naturally, never placeholders. |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | Akordy / Skale | Use this sense; inflect words naturally, never placeholders. |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | Sprawdzenie poziomu | Use this sense; inflect words naturally, never placeholders. |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | Graj do rytmu | Use this sense; inflect words naturally, never placeholders. |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | Podejście | Use this sense; inflect words naturally, never placeholders. |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | Pętla A–B / Ustaw A / Ustaw B | Use this sense; inflect words naturally, never placeholders. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | Początkujący / Standardowy / Ekspert | Use this sense; inflect words naturally, never placeholders. |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | Studio (lżejsze) / 3D w czasie rzeczywistym | Use this sense; inflect words naturally, never placeholders. |
| Haptics | Vibration feedback | Settings | `Haptics` | Haptyka | Use this sense; inflect words naturally, never placeholders. |
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | stroik | Use this sense; inflect words naturally, never placeholders. |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | nastroić | Use this sense; inflect words naturally, never placeholders. |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | strój | Use this sense; inflect words naturally, never placeholders. |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | W stroju | Use this sense; inflect words naturally, never placeholders. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | za nisko / za wysoko | Use this sense; inflect words naturally, never placeholders. |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | centy | Use this sense; inflect words naturally, never placeholders. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | potwierdzenie dokładnego stroju | Use this sense; inflect words naturally, never placeholders. |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | struna | Use this sense; inflect words naturally, never placeholders. |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | klucz / główka | Use this sense; inflect words naturally, never placeholders. |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | dźwięk wzorcowy / wysokość odniesienia / Strój koncertowy | Use this sense; inflect words naturally, never placeholders. |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | wysokość zapisana / Temperacja | Use this sense; inflect words naturally, never placeholders. |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | Chromatyczny / stroboskopowy | Use this sense; inflect words naturally, never placeholders. |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | Kapodaster | Use this sense; inflect words naturally, never placeholders. |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | Transponuj / transpozycja | Use this sense; inflect words naturally, never placeholders. |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | Nazwy nut / Solfeż / Sargam | Use this sense; inflect words naturally, never placeholders. |
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | próg / pusta struna | Use this sense; inflect words naturally, never placeholders. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | palec 1–4; wskazujący, środkowy, serdeczny, mały | Use this sense; inflect words naturally, never placeholders. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | akord / chwyt akordowy / barré | Use this sense; inflect words naturally, never placeholders. |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | durowy / molowy / septymowy / power chord | Use this sense; inflect words naturally, never placeholders. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | Tonacja | Use this sense; inflect words naturally, never placeholders. |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | skala / skala durowa / pozycja pentatoniki | Use this sense; inflect words naturally, never placeholders. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | półton / cały ton / interwał / tercja / kwinta / oktawa | Use this sense; inflect words naturally, never placeholders. |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | takt | Use this sense; inflect words naturally, never placeholders. |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | uderzenie / tempo / mocna część taktu / liczenie | Use this sense; inflect words naturally, never placeholders. |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | bicie / uderzenie w dół / uderzenie w górę / tłumione uderzenie / tłumienie | Use this sense; inflect words naturally, never placeholders. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | kostka; szarpnięcie; wybierz (UI) | Use this sense; inflect words naturally, never placeholders. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | gra palcami / hammer-on / pull-off / slide / bend / vibrato | Use this sense; inflect words naturally, never placeholders. |
| bowing, open-string bowing | Violin and cello | lessons |  | gra smyczkiem / gra smyczkiem na pustych strunach | Use this sense; inflect words naturally, never placeholders. |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | melodia | Use this sense; inflect words naturally, never placeholders. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | kadencja / akord V / I–IV–V | Use this sense; inflect words naturally, never placeholders. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | przedtakt | Use this sense; inflect words naturally, never placeholders. |
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | Intro / Zwrotka 1 / Refren / Mostek / Solo / Outro / Zakończenie | Use this sense; inflect words naturally, never placeholders. |
| section | A part of a song | lessons 9 |  | część | Use this sense; inflect words naturally, never placeholders. |
| streak | Consecutive days with practice | UI 21 |  | seria | Use this sense; inflect words naturally, never placeholders. |
| streak freeze | Saves the streak on a missed day | UI |  | zamrożenie serii | Use this sense; inflect words naturally, never placeholders. |
| best run | The longest streak so far | Progress | `best run` | najlepsza seria | Use this sense; inflect words naturally, never placeholders. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | odznaka / osiągnięcie | Use this sense; inflect words naturally, never placeholders. |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | poziom / gwiazdki / XP / Combo / wynik / runda | Use this sense; inflect words naturally, never placeholders. |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | wyzwij znajomego | Use this sense; inflect words naturally, never placeholders. |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | wyzwanie | Use this sense; inflect words naturally, never placeholders. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | kurs / dział / lekcja / krok | Use this sense; inflect words naturally, never placeholders. |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | quiz / wskazówka | Use this sense; inflect words naturally, never placeholders. |
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | subskrypcja / odnowić / anulować | Use this sense; inflect words naturally, never placeholders. |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | bezpłatny okres próbny / koniec okresu próbnego | Use this sense; inflect words naturally, never placeholders. |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | Rocznie / Miesięcznie / Na zawsze | Use this sense; inflect words naturally, never placeholders. |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | Przywróć zakupy | Use this sense; inflect words naturally, never placeholders. |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | metoda płatności / problem z płatnością | Use this sense; inflect words naturally, never placeholders. |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | Warunki / Polityka prywatności | Use this sense; inflect words naturally, never placeholders. |

## 3. Course and song names

| English | Translation |
|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | Gitara, Ukulele, Bas, Skrzypce, Wiolonczela, Mandolina, Banjo |
| Ear Training, Music Theory, Rhythm, Singing | Trening słuchu, Teoria muzyki, Rytm, Śpiew |
| Songs | Piosenki |
| Originals | Autorskie piosenki |
| Standards & Classics | Standardy i klasyka |
| Instrument Songbook | Śpiewnik na odpowiedni instrument |

- Established public-domain titles: use established local titles.
- Other traditional songs: retain English unless a shipped localized lesson title already exists.
- Timbre Originals: translate consistently with existing localized lesson titles; never translate sung lyrics.
- A title in prose must exactly match its lesson title and leaderboard. Credits retain names and digit groups; translate connecting words.

## 4. Words that mislead

| English | Translation and distinction |
|---|---|
| Tune | nastroić / melodia |
| sharp / flat | krzyżyk / bemol; za wysoko / za nisko for tuning |
| bar | takt, not pub |
| key | tonacja, not object |
| pick | kostka / szarpnięcie; wybierz in UI |
| lock | potwierdzenie stroju, not padlock |
| take | podejście |
| run | seria / zagranie fragmentu |
| chart | diagram akordów |
| Intonation | Intonacja, pitch accuracy not bridge adjustment |
| Next, Again, Slower | Dalej / Jeszcze raz / Wolniej |
| Practice | Ćwiczenia |
| Feel | Wibracje, not emotion |

## Lesson authoring decisions (independent review pending)
- Informal singular imperatives, without gendered past forms.
- Preserve source B notation; do not silently substitute Polish traditional H. Context/notation convention must be checked during independent review.
- Chord qualities: E-moll/E-dur; root of chord: pryma; tonic: tonika; bar: takt; beat: uderzenie, with pulsu when contrasted with strumming.
- Shared ordinals: Pierwszy przykład / Drugi przykład, referring to musical items, never displayed answer index. In the phrase quiz The first is the second displayed option. Bare First is finger-only Pierwszy. Direction W górę / W dół works for both pitch and picking direction.
- Fret-wire placement: przy progu, od strony główki; avoids ambiguous front/behind viewpoints.
- Use existing navigation names Piosenki and Autorskie piosenki.
- Direct author corrections and source-bound old/new receipts are retained; no native-human or independent approval is claimed for this section.

### Additional lesson author decisions (unreviewed, /root/translate_polish_lessons)
- Polish string mnemonics preserve literal note initials: E A D G B E = „Ewa akompaniuje dobrym gitarzystom bardzo elegancko”; G C E A = „Gosia codziennie energicznie akompaniuje”. Parent-root mnemonic drafts are preserved with source-bound corrections in author-corrections-003.json.
- Spelled accidentals remain spelled in prose: G sharp = G z krzyżykiem; B flat = B z bemolem. For spelled sharp minor keys, use e.g. F z krzyżykiem w moll. Existing literal accidental symbols are preserved exactly; do not add new symbols. This verbose convention needs independent language/layout review; source B is never silently replaced by H.
- Musical form bridge = mostek. Guitar/mandolin bridge = mostek; violin/cello bridge = podstawek. The explicit current source split The instrument bridge must be translated from its actual bowed-instrument context, not from the musical form label.
- Travis picking = technika Travisa; alternating bass = bas naprzemienny; power chord = power chord (plural power chordy); lick = zagrywka; turnaround = zwrot na koniec / zwrot bluesowy; comping = akompaniament; triad = trójdźwięk; inversion = przewrót; common tone = dźwięk wspólny; re-entrant tuning = strój powracający (terminology review pending).
- D/U strum-pattern notation is retained as notation, with a Polish D = dół, U = góra explanation added in the first island-strum card. Country boom-chick = bum-cyk; sixteenths counted raz-e-i-a. These are source-context adaptations, not semantic-review approvals.
- Twinkle, Twinkle, Little Star = Migaj, migaj, gwiazdko mała. Established Polish title draft; sung words remain unchanged. Other encountered traditional titles retained as proper titles, each with individual candidate reasons.

### Further lesson context decisions (unreviewed author draft)
Author: /root/translate_polish_lessons.
- Bowed strings: bridge = podstawek, frog = żabka, tip = szpic, stick = drzewce, hair = włosie, rosin = kalafonia, fingerboard = podstrunnica, scroll = ślimak, tailpiece = strunociąg, fine tuner = mikrostroik, cello endpin = nóżka. Down-bow = od żabki; up-bow = do żabki, not vertical directions.
- Violin/mandolin G D A E mnemonic: Gosia dobrze akompaniuje Ewie. Cello C G D A: Celina gra dla Ani.
- Staff lines E G B D F: Ewa gra ballady dla Filipa; bass lines G B D F A: Gosia bardzo dobrze frazuje arię; bass spaces A C E G: Ania codziennie energicznie gra. FACE remains the source acrostic with explicit Polish explanation of English face = twarz. All subsequent mnemonic references adapted consistently.
- Banjo: finger picks = pazurki, head = membrana, drone = burdon, roll = roll (plural rolle), forward roll = roll do przodu, alternating thumb roll = roll z naprzemiennym kciukiem. Pinch and clawhammer retained as explained technique names. Bum-ditty adapted phonetically to bum-di-ti consistently.
- Intervals: major/minor = wielki/mały (NOT durowy/molowy, which describe chords and scales). Perfect = czysty; diminished = zmniejszony; augmented = zwiększony. Shared Unison = Unisono, czyli pryma to support both same-pitch voices and interval quizzes.
- Solfège uses source movable-do syllables do re mi fa sol la ti; retain ti rather than mixing systems with si. Individual exact-string candidates record every melody sequence. W/H major-scale pattern retained with Polish legend W = cały ton, H = półton.
- English bar/measure synonym lesson explicitly names both as English words and asks what measure, synonym of bar, means: takt. This avoids inventing a nonexistent distinct everyday Polish synonym while preserving the source teaching point.
- Further titles: The Swan = Łabędź; Brahms’ Lullaby = Kołysanka Brahmsa; Jingle Bells = Dzwoneczki; Frère Jacques = Panie Janie; Für Elise = Dla Elizy. The Entertainer and named traditional American fiddle/banjo tunes remain individual title-retention candidates.

### Final lesson author decisions (unreviewed; 2026-10-26)
- Triplet counting is adapted consistently to `1-ta-ka, 2-ta-ka`; the final English counting syllable `let` is `ka` in its corresponding Polish explanation. This is a counting aid, not a lyric translation.
- Musical-form bridge remains **mostek** throughout, including the shared arrangement chip; the explicit bowed-instrument title is **Podstawek instrumentu**. Guitar/mandolin hardware remains mostek.
- Keep the existing **power chord / power chordy** spelling, including Polish inflections with a space. Country boom-chick remains **bum-cyk**; later country cards have been aligned with the earlier lesson.
- The first/second/third/last shared example choices use **Pierwszy przykład / Drugi przykład / Trzeci przykład / Ostatni przykład**. These identify musical referents, not choice positions. Explicit interval-only Second/Third/Fourth remain Sekunda/Tercja/Kwarta.
- Further localized title drafts: Old MacDonald Had a Farm = Stary MacDonald farmę miał; Canon in D = Kanon w D; In the Hall of the Mountain King = W grocie Króla Gór; Good King Wenceslas = Dobry król Wacław; We Wish You a Merry Christmas = Życzymy wam wesołych świąt; Joy to the World = Radość światu; Silent Night = Cicha noc; O Christmas Tree = O choinko; O Come, All Ye Faithful = Przybądźcie, wierni; The Blue Danube = Nad pięknym modrym Dunajem; Can-can = Kankan; The Liberty Bell = Dzwon wolności; Morning Mood = Poranek; Holy, Holy, Holy = Święty, Święty, Święty; Abide with Me = Zostań ze mną; Nearer, My God, to Thee = Być bliżej Ciebie chcę; The Last Rose of Summer = Ostatnia róża lata; Jupiter = Jowisz; Spring = Wiosna; The Stars and Stripes Forever = Gwiazdy i pasy na zawsze. All remain subject to independent terminology/title review.
- Keeper's Daughter = Córka latarnika, after inspecting the actual sea/lamp/keeper lyric context in originals_part2.py. Constellation Prize = Gwiazdozbiór na pocieszenie preserves the source's constellation/consolation-prize wordplay as a title adaptation. Sung lyrics are not changed.
- Original-song titles and remaining traditional title candidates are indexed in the frozen author handoff's title-decisions.json. Original titles embedded in prose are localized consistently, allowing normal Polish inflection.
- Whole sung-word quiz choices such as Fly, Wide, Boat, Town and Bethlehem remain the exact sung English word. Mixed lyric/instruction strings translate the instruction, not the quoted lyric; exact-source whole strings have individual candidate reasons and are not self-approved.
- The initial glossary header's prior UI AI-review status does not confer independent approval on these new lesson drafts. Native-human and device review remain pending.


## Independently reviewed lesson overrides

The following source-bound decisions supersede conflicting older lesson anchors above.

# Polish lesson glossary reconciliation

Independent AI reviewer: Independent Polish AI reviewer. Applies to this exact 6,083-key source revision; no native-human or device certification.

- **B stays B**, including B-moll/B♭ and note/chord sequences. H in the alphabet quiz remains an intentionally wrong distractor. No silent Polish H conversion. Accidentals written as words stay `z krzyżykiem` / `z bemolem`; existing ♯/♭ remain literal.
- Intervals: wielki/mały/czysty; chord/scale quality: durowy/molowy. Septymowe chord families are **akordy septymowe**, not bare interval **septymy**. Actual seventh tones/intervals retain septyma. Spelled accidental minor chord labels use **molowe F z krzyżykiem** / **molowe C z krzyżykiem**, with natural inflection; this supersedes the draft's `F z krzyżykiem w moll` phrasing.
- Arrangement **Intro → Wstęp**, **Outro → Zakończenie**, consistent with lesson prose and short answers. These replace the older generic glossary Intro/Outro anchors for these lesson keys. Verse → Zwrotka; Chorus → Refren; Bridge → Mostek; Interlude → Interludium; Coda → Koda. Native Polish loanwords Solo/Riff/Trio are retained in their individually reviewed roles.
- Guitar/mandolin bridge → mostek; violin/cello bridge → podstawek. Anatomical breastbone → mostek. The source split `The instrument bridge` is `Podstawek instrumentu`; `The bridge` is song form only.
- Bow **stroke** → pociągnięcie smyczka where one/two or separate strokes could otherwise imply physical bow objects. Down-bow/up-bow → od żabki/do żabki, not vertical directions. Heavy bowing refers to arm weight, not a heavy object or forcing tense movement.
- Chord shape → chwyt; shared guitar/violin finger pattern → układ palców. Steady hands describe **równa praca ręki/dłoni**, not physically even-shaped hands.
- Shared directions **W górę/W dół** cover melodic movement and pick direction. Shared count labels **Liczba jeden/dwa/trzy/cztery** explicitly name values across differently gendered count nouns and beat-number questions without adding prohibited digits. Shared None of them → **Żadne**, matching plural strings, notes and fingers.
- Shared musical ordinals **Pierwszy/Drugi/Trzeci/Ostatni przykład** identify the musical item, never the answer's displayed index. This includes the All Through the Night phrase quiz: its first phrase is the second displayed option. Finger-only `First` and explicit finger keys remain fingers; bare Second/Third/Fourth are intervals.
- Beat: uderzenie (pulsu where contrasted with strum), beat heading: puls; bar: takt. The explicit English bar/measure quiz asks the meaning of English measure, synonym of bar; answers Uderzenie/Pauza/Takt and explanation are coherent, not circular.
- Informal singular ty and gender-neutral learner references retained. Musical quotations and English sung-word quiz anchors are not translated lyrics. Established Polish repertoire titles and retained traditional original titles remain consistent across lesson, play-along, quiz and arrangement roles; all 146 song-title keys were covered. Normal Polish title inflection in prose is appropriate.
- Source movable-do system uses **ti**, not an inconsistent mixture with si. Literal D/U and W/H pattern notation has Polish explanation. Triplets: `1-ta-ka, 2-ta-ka`; last syllable `ka`. Sixteenths: `raz-e-i-a`; country boom-chick: `bum-cyk`; banjo bum-ditty: `bum-di-ti`.
- String/staff mnemonics independently checked: E-A-D-G-B-E **Ewa akompaniuje dobrym gitarzystom bardzo elegancko**; G-C-E-A **Gosia codziennie energicznie akompaniuje**; E-A-D-G **Ewa akompaniuje dobrym gitarzystom**; G-D-A-E **Gosia dobrze akompaniuje Ewie**; C-G-D-A **Celina gra dla Ani**; E-G-B-D-F **Ewa gra ballady dla Filipa**; G-B-D-F-A **Gosia bardzo dobrze frazuje arię**; A-C-E-G **Ania codziennie energicznie gra**. FACE remains the literal acrostic with the English-word explanation translated.
- Four earlier reviewer numeral-agreement edits were explicitly withdrawn in `judgment-amendments-001.json`; final output does not impose a blanket quantified-pronoun agreement rule.

All unchanged English-identical strings require their own exact reason in `invariants.json`; these glossary choices are not blanket invariant approval.
