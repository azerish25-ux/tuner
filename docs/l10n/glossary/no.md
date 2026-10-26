# Norwegian (no) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Review: AI-reviewed working glossary, 2026-10-25. Not human-approved. Native musician and device review remain outstanding. Applies to interface and Norwegian Bokmål lesson drafts. Lesson translations drafted 2026-10-26; independent linguistic review is pending.

## 1. Locale decisions
- Locale/variant: no, standard Norwegian; Norwegian is Bokmål.
- Register: Informal singular, warm direct second person; avoid gender assumptions. Short imperative actions; noun labels; third-person VoiceOver hints. Avoid reader-gender marking.
- Typography: sentence case, normal word spaces, no double or edge spaces. Curly apostrophe where needed; single ellipsis …. Quotes follow shipped table (Nordic ”…”/“…”; Baltic „…“/„…”; sw/zu “…”). Digits ASCII 0–9. Preserve line structure.
- Units: Hz, BPM, XP, ¢, A4 unchanged; cents = Cent. Minutes use existing minutes entry; seconds s, milliseconds ms on screen, full words in spoken hints.
- Notes: preserve inserted note names and all placeholders without inflecting them. No lesson note respelling. Accidentals follow existing note-name entries, never confuse with tuner direction: flat = for lavt; sharp = for høyt. Double accidentals repeat the musical alteration, not the direction word.
- Legal Settings path: Innstillinger › Apple-konto › Abonnementer. For languages without localized iOS system UI, retain the actual English path, not invented translated system menu labels. Apple’s iOS 26 language-support list excludes is/et/lt/lv/sw/zu; English system-path labels retained (https://images.apple.com/ie/iphone-16/specs/). In-app Settings retains Innstillinger.
- Apple features: preserve product names Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri; use shipped system labels, never invent product names. Home/Lock Screen and accessibility feature names require device verification when first encountered.
- Siri: natural imperative, retain ${applicationName} and every named token.
- Brands: Timbre, Timbre Pro, Pro, ChordPro unchanged and uninflected. Keep [G], ChordPro directives, URLs, ›, ·, ×, arrows and all format tokens verbatim.
- Musical tuning terminology overrides: the drone-training Intonation is pitch accuracy, not saddle adjustment. da/no/sv Temperament means musical temperament (not physical temperature); use Temperering / Temperering / Temperering respectively when this source occurs.

### Explicit locale conventions
- Exact address: du.
- Quotation marks: “…”; no spaces inside quotation marks. Other punctuation uses normal Western spacing.
- Units, spoken and compact: cent; minutter/min; sekunder/s; millisekunder/ms. Spoken VoiceOver labels use full words, not the screen abbreviation.
- Musical accidentals (sharp / flat / double sharp / double flat): kryss; b; dobbeltkryss; dobbelt-b. These are notation terms; the tuner direction terms above instead describe whether the pitch is too low or high.
- Apple feature labels (Home Screen / Lock Screen / widget / Live Activity / Shortcuts / Control Center / Family Sharing): Hjem-skjerm; låst skjerm; widget; Direkteaktivitet; Snarveier; Kontrollsenter; Familiedeling. Product names remain unchanged. Verify supported-system labels on device before release; English names deliberately retained for unsupported system UI languages.
- Instrument names: use the already localized `timbre_catalog_*` names; do not substitute English when a localized catalogue name exists. Tuning presets use the existing `timbre_catalog_tuning_*` names, preserving Drop/Open note letters and DADGAD.
- Counted flat strings: prefer a count-neutral label for unknown counts where inflection differs; never attach a case suffix to a placeholder. Numeric chord 7 and 3D stay numeric; musical symbols and cents sign stay unchanged.

## 2. Terms
Existing shipped terminology below is binding by sense and may be grammatically inflected, except inserted values and brand names. Supplemented terms precede anchors and override them only for the same sense.

| English | Meaning | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Songs | Music/app sense | UI | `Songs` | Sanger | AI-reviewed |
| Your songs | Music/app sense | UI | `Your songs` | Dine sanger | AI-reviewed |
| Chart | Music/app sense | UI | `Chart` | Akkorddiagram | AI-reviewed |
| Player view | Music/app sense | UI | `Player view` | Spillervisning | AI-reviewed |
| Chord view | Music/app sense | UI | `Chord view` | Akkordvisning | AI-reviewed |
| Neck view | Music/app sense | UI | `Neck view` | Gripebrettvisning | AI-reviewed |
| Show me | Music/app sense | UI | `Show me` | Vis meg | AI-reviewed |
| Strum to tune | Music/app sense | UI | `Strum to tune` | Slå an for å stemme | AI-reviewed |
| Tune by feel | Music/app sense | UI | `Tune by feel` | Stem med følesansen | AI-reviewed |
| Feel | Music/app sense | UI | `Feel` | Kjenn | AI-reviewed |
| Placement check | Music/app sense | UI | `Placement check` | Nivåsjekk | AI-reviewed |
| Final take | Music/app sense | UI | `Final take` | Siste opptak | AI-reviewed |
| Expert | Music/app sense | UI | `Expert` | Ekspert | AI-reviewed |
| Capo | Music/app sense | UI | `Capo` | Capo | AI-reviewed |
| Transpose | Music/app sense | UI | `Transpose` | Transponer | AI-reviewed |
| Verse | Music/app sense | UI | `Verse` | Vers | AI-reviewed |
| Chorus | Music/app sense | UI | `Chorus` | Refreng | AI-reviewed |
| Bridge | Music/app sense | UI | `Bridge` | Bro | AI-reviewed |
| Quest | Music/app sense | UI | `Quest` | Oppdrag | AI-reviewed |
| Song sheet | Music/app sense | UI | `Song sheet` | Sangark | AI-reviewed |
| string | Music/app sense | UI | `string` | streng | AI-reviewed |
| peg | Music/app sense | UI | `peg` | stemmeskrue | AI-reviewed |
| headstock | Music/app sense | UI | `headstock` | hode | AI-reviewed |
| fret | Music/app sense | UI | `fret` | bånd | AI-reviewed |
| open string | Music/app sense | UI | `open string` | åpen streng | AI-reviewed |
| chord shape | Music/app sense | UI | `chord shape` | akkordgrep | AI-reviewed |
| barre | Music/app sense | UI | `barre` | barré | AI-reviewed |
| minor | Music/app sense | UI | `minor` | moll | AI-reviewed |
| seventh | Music/app sense | UI | `seventh` | septim | AI-reviewed |
| power chord | Music/app sense | UI | `power chord` | powerakkord | AI-reviewed |
| half step | Music/app sense | UI | `half step` | halvtonetrinn | AI-reviewed |
| whole step | Music/app sense | UI | `whole step` | heltonetrinn | AI-reviewed |
| third | Music/app sense | UI | `third` | ters | AI-reviewed |
| fifth | Music/app sense | UI | `fifth` | kvint | AI-reviewed |
| bar | Music/app sense | UI | `bar` | takt | AI-reviewed |
| beat | Music/app sense | UI | `beat` | slag | AI-reviewed |
| downbeat | Music/app sense | UI | `downbeat` | første slag | AI-reviewed |
| strum | Music/app sense | UI | `strum` | anslag | AI-reviewed |
| downstroke | Music/app sense | UI | `downstroke` | nedslag | AI-reviewed |
| upstroke | Music/app sense | UI | `upstroke` | oppslag | AI-reviewed |
| mute | Music/app sense | UI | `mute` | demp | AI-reviewed |
| pick | Music/app sense | UI | `pick` | plekter | AI-reviewed |
| fingerpicking | Music/app sense | UI | `fingerpicking` | fingerspill | AI-reviewed |
| bowing | Music/app sense | UI | `bowing` | buestrøk | AI-reviewed |
| tune (melody) | Music/app sense | UI | `tune (melody)` | melodi | AI-reviewed |
| cadence | Music/app sense | UI | `cadence` | kadens | AI-reviewed |
| pickup | Music/app sense | UI | `pickup` | opptakt | AI-reviewed |
| section | Music/app sense | UI | `section` | del | AI-reviewed |
| streak | Music/app sense | UI | `streak` | dager på rad | AI-reviewed |
| streak freeze | Music/app sense | UI | `streak freeze` | rekkebeskyttelse | AI-reviewed |
| badge | Music/app sense | UI | `badge` | merke | AI-reviewed |
| achievement | Music/app sense | UI | `achievement` | prestasjon | AI-reviewed |
| round | Music/app sense | UI | `round` | runde | AI-reviewed |
| course | Music/app sense | UI | `course` | kurs | AI-reviewed |
| unit | Music/app sense | UI | `unit` | enhet | AI-reviewed |
| step | Music/app sense | UI | `step` | trinn | AI-reviewed |
| quiz | Music/app sense | UI | `quiz` | quiz | AI-reviewed |
| hint | Music/app sense | UI | `hint` | hint | AI-reviewed |
| subscription | Music/app sense | UI | `subscription` | abonnement | AI-reviewed |
| renew | Music/app sense | UI | `renew` | forny | AI-reviewed |
| cancel subscription | Music/app sense | UI | `cancel subscription` | si opp | AI-reviewed |
| payment method | Music/app sense | UI | `payment method` | betalingsmåte | AI-reviewed |
| billing issue | Music/app sense | UI | `billing issue` | betalingsproblem | AI-reviewed |
| trial ends | Music/app sense | UI | `trial ends` | prøveperioden slutter | AI-reviewed |
| Intro | Music/app sense | UI | `Intro` | Intro | AI-reviewed |
| Solo | Music/app sense | UI | `Solo` | Solo | AI-reviewed |
| Outro | Music/app sense | UI | `Outro` | Outro | AI-reviewed |
| Tag | Music/app sense | UI | `Tag` | Avslutning | AI-reviewed |
| Originals | Music/app sense | UI | `Originals` | Originaler | AI-reviewed |
| Standards & Classics | Music/app sense | UI | `Standards & Classics` | Standards og klassikere | AI-reviewed |
| Music Theory | Music/app sense | UI | `Music Theory` | Musikkteori | AI-reviewed |
| Singing | Music/app sense | UI | `Singing` | Sang | AI-reviewed |
| A4 | Existing app sense | UI | `A4` | A4 | Existing table anchor |
| Banjo | Existing app sense | UI | `Banjo` | Banjo | Existing table anchor |
| Bass | Existing app sense | UI | `Bass` | Bass | Existing table anchor |
| Cello | Existing app sense | UI | `Cello` | Cello | Existing table anchor |
| Cents | Existing app sense | UI | `Cents` | Cent | Existing table anchor |
| Chords | Existing app sense | UI | `Chords` | Akkorder | Existing table anchor |
| Chromatic | Existing app sense | UI | `Chromatic` | Kromatisk | Existing table anchor |
| Drone | Existing app sense | UI | `Drone` | Bordun | Existing table anchor |
| Ear training | Existing app sense | UI | `Ear training` | Gehørtrening | Existing table anchor |
| Free trial | Existing app sense | UI | `Free trial` | Gratis prøveperiode | Existing table anchor |
| Guitar | Existing app sense | UI | `Guitar` | Gitar | Existing table anchor |
| Haptics | Existing app sense | UI | `Haptics` | Haptikk | Existing table anchor |
| Hz | Existing app sense | UI | `Hz` | Hz | Existing table anchor |
| In tune | Existing app sense | UI | `In tune` | Stemt | Existing table anchor |
| Intervals | Existing app sense | UI | `Intervals` | Intervaller | Existing table anchor |
| Lifetime | Existing app sense | UI | `Lifetime` | Livstid | Existing table anchor |
| Major | Existing app sense | UI | `Major` | Dur | Existing table anchor |
| Mandolin | Existing app sense | UI | `Mandolin` | Mandolin | Existing table anchor |
| Metronome | Existing app sense | UI | `Metronome` | Metronom | Existing table anchor |
| Monthly | Existing app sense | UI | `Monthly` | Månedlig | Existing table anchor |
| Note names | Existing app sense | UI | `Note names` | Tonenavn | Existing table anchor |
| Octave | Existing app sense | UI | `Octave` | Oktav | Existing table anchor |
| Practice | Existing app sense | UI | `Practice` | Øv | Existing table anchor |
| Privacy policy | Existing app sense | UI | `Privacy policy` | Personvernerklæring | Existing table anchor |
| Pro | Existing app sense | UI | `Pro` | Pro | Existing table anchor |
| Real-time 3D | Existing app sense | UI | `Real-time 3D` | 3D i sanntid | Existing table anchor |
| Restore purchases | Existing app sense | UI | `Restore purchases` | Gjenopprett kjøp | Existing table anchor |
| Rhythm | Existing app sense | UI | `Rhythm` | Rytme | Existing table anchor |
| Sargam | Existing app sense | UI | `Sargam` | Sargam | Existing table anchor |
| Scales | Existing app sense | UI | `Scales` | Skalaer | Existing table anchor |
| Settings | Existing app sense | UI | `Settings` | Innstillinger | Existing table anchor |
| Slower | Existing app sense | UI | `Slower` | Saktere | Existing table anchor |
| Solfège | Existing app sense | UI | `Solfège` | Solmisasjon | Existing table anchor |
| Speed trainer | Existing app sense | UI | `Speed trainer` | Tempotrener | Existing table anchor |
| Studio (lighter) | Existing app sense | UI | `Studio (lighter)` | Studio (lettere) | Existing table anchor |
| Tanpura | Existing app sense | UI | `Tanpura` | Tanpura | Existing table anchor |
| Temperament | Musical tuning system | UI/lessons | `Temperament` | Temperering | Corrected musical sense; not physical temperature |
| Tempo | Existing app sense | UI | `Tempo` | Tempo | Existing table anchor |
| Terms | Existing app sense | UI | `Terms` | Vilkår | Existing table anchor |
| Timbre | Existing app sense | UI | `Timbre` | Timbre | Existing table anchor |
| Timbre Pro | Existing app sense | UI | `Timbre Pro` | Timbre Pro | Existing table anchor |
| Today | Existing app sense | UI | `Today` | I dag | Existing table anchor |
| Tonic | Existing app sense | UI | `Tonic` | Grunntone | Existing table anchor |
| Tune | Existing app sense | UI | `Tune` | Stem | Existing table anchor |
| Tune up | Existing app sense | UI | `Tune up` | Stem instrumentet | Existing table anchor |
| Tuning | Existing app sense | UI | `Tuning` | Stemming | Existing table anchor |
| Ukulele | Existing app sense | UI | `Ukulele` | Ukulele | Existing table anchor |
| Violin | Existing app sense | UI | `Violin` | Fiolin | Existing table anchor |
| Yearly | Existing app sense | UI | `Yearly` | Årlig | Existing table anchor |
| best run | Existing app sense | UI | `best run` | rekord | Existing table anchor |
| minutes | Existing app sense | UI | `minutes` | minutter | Existing table anchor |
| Practice streak | Existing app sense | UI | `Practice streak` | Øvingsdager på rad | Existing table anchor |
| Achievements | Existing app sense | UI | `Achievements` | Prestasjoner | Existing table anchor |
| Ear trainer | Existing app sense | UI | `Ear trainer` | Gehørtrener | Existing table anchor |
| Intonation | Existing app sense | UI | `Intonation` | Intonasjon | Existing table anchor |
| Progress | Existing app sense | UI | `Progress` | Fremgang | Existing table anchor |
| flat | Existing app sense | UI | `flat` | for lavt | Existing table anchor |
| sharp | Existing app sense | UI | `sharp` | for høyt | Existing table anchor |
| Learn | Existing app sense | UI | `Learn` | Lær | Existing table anchor |
| Lesson | Existing app sense | UI | `Lesson` | Leksjon | Existing table anchor |
| Next | Existing app sense | UI | `Next` | Neste | Existing table anchor |
| Play along | Existing app sense | UI | `Play along` | Spill med | Existing table anchor |
| XP | Existing app sense | UI | `XP` | XP | Existing table anchor |
| Streak freeze earned | Existing app sense | UI | `Streak freeze earned` | Rekkebeskyttelse opptjent | Existing table anchor |
| Streak saved | Existing app sense | UI | `Streak saved` | Rekken er reddet | Existing table anchor |
| Precision | Existing app sense | UI | `Precision` | Presisjon | Existing table anchor |
| Beginner | Existing app sense | UI | `Beginner` | Nybegynner | Existing table anchor |
| Standard | Existing app sense | UI | `Standard` | Standard | Existing table anchor |
| Fretted | Existing app sense | UI | `Fretted` | Nedtrykket | Existing table anchor |
| Saddle | Existing app sense | UI | `Saddle` | Sal | Existing table anchor |
| Bullseye | Existing app sense | UI | `Bullseye` | Fulltreff | Existing table anchor |
| Songbook | Existing app sense | UI | `Songbook` | Sangbok | Existing table anchor |
| Concert Pitch | Existing app sense | UI | `Concert Pitch` | Kammertone | Existing table anchor |
| A flat | Existing app sense | UI | `A flat` | As | Existing table anchor |
| A sharp | Existing app sense | UI | `A sharp` | Ais | Existing table anchor |
| Combo | Existing app sense | UI | `Combo` | Kombo | Existing table anchor |
| D sharp | Existing app sense | UI | `D sharp` | Dis | Existing table anchor |
| E flat | Existing app sense | UI | `E flat` | Es | Existing table anchor |
| Key | Existing app sense | UI | `Key` | Toneart | Existing table anchor |

## 3. Course and song names
Use the instrument-name anchors for Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo. Songs equals the Songs tab. Ear Training/Rhythm reuse existing feature terminology; Music Theory/Singing and Originals/Standards & Classics are specified above. Songbook reuses the existing anchor. Keep English song titles unless a firmly established local title exists; preserve traditional proper names and Timbre Originals titles. A title in prose must exactly match its lesson title. Lyric credits retain names and years, translating only connecting words; lyrics are not translated.

## 4. Words that mislead
Tune: tuning verb/tab versus melody noun; use separate terms above. Sharp/flat: tuning too high/low versus musical accidental. Bar: musical measure, never pub or toolbar. Key: musical tonality, never password/keycap. Pick: plectrum or pluck, but choose in interface. Lock: confirmation of stable correct pitch, not a padlock; locked content is separate. Take: a recorded attempt. Run: streak or complete performance, not running. Chart: chord sheet/diagram except statistical plots in Progress. Intonation: pitch accuracy over a drone, not saddle setup. Next/Again/Slower: one term must work both on controls and as spoken commands, using shipped anchors. Practice: music practice, not professional business. Feel: haptic sensation, not emotion. Quest: optional side goal distinct from the Today activity set. Challenge: friend competition versus cumulative lesson test; translate by context. Finger numbers 1–4 and open 0 remain unchanged. Loop A–B labels are markers, not note names. For hammer-on/pull-off/slide/bend/vibrato use established guitar-teaching loanwords, not everyday translations; I–IV–V and V/I chord symbols remain intact.

### Context-review decisions
- `In` / `Out` in HighwayTimingStrip are short Intro / Outro section labels, not inside/outside, enabled/disabled, or loop boundaries.
- `Push beat` / `Push the and of` mean play the beat/offbeat more strongly (dynamic accent), never anticipate its timing.
- `String %lld, low %lld` / `high %lld`: the second argument is a finger number with low/high placement; make finger explicit, not pitch.
- `Tap Sync, then tap along once`: mark changes through one complete playback pass, not a single tap and not “immediately.”
- Watch `Taps resume` refers to haptic pulses resuming when the wrist is raised, not touch gestures by the user.
- Price/duration values can contain singular or plural units. Use period/duration label framing rather than an agreeing singular article around an unknown value.
- Haptic feature explanations should introduce the feature name as a named function before describing its operation, not use a bare imperative as the subject.
- Lesson control “moves on” means advances to the next step, not within the same step.

## 5. Lesson-specific draft decisions (2026-10-26)

Draft terminology, awaiting independent review; not a native-review sign-off.

- Notes and chord symbols retain source notation, including B (not H), ♯/♭, Em, G7 and slash chords. Plain spelled-out accidentals use kryss/b; in explanatory prose “hevet/senket en halvtone” where clearer. Never add or remove musical signs.
- Bare Second / Third / Fourth are interval names: sekund / ters / kvart. Explicit finger ordinals use andre finger / tredje finger / fjerde finger. Fifth, sixth and seventh intervals: kvint, sekst, septim. Perfect: ren; major: stor; minor: liten, when describing intervals. Major/minor key or chord: dur/moll.
- Beat = slag; bar/measure = takt; pulse = puls; downbeat = første slag; upbeat/offbeat = mellomslag, or oppslag when referring to strumming direction. Count-in = opptelling. Quarter note = firedelsnote; eighth note = åttedelsnote; half note = halvnote; whole note = helnote.
- Fret = bånd; fretboard = gripebrett; fretting hand = gripehånd; picking hand = anslagshånd; open string = åpen streng; fingerboard position = posisjon. Bow = bue; bow stroke = buestrøk; down-bow/up-bow = nedstrøk/oppstrøk; bow hair = buehår.
- Strum (noun) = anslag; strum (verb) = slå an; pick (object) = plekter; pick/pluck (verb) = knips/spill, according to technique. Fingerpicking = fingerspill; hammer-on and pull-off retain established teaching loanwords; slide = slide/glidning by context. Bend = bend; vibrato = vibrato.
- Root = grunntone; tonic = tonika (harmonic function), grunntone where identifying the tonal home. Key = toneart. Scale degree = skalatrinn. Chord progression = akkordrekke. Voicing = akkordlegging. Inversion = omvending. Drone = bordun.
- Quiz = quiz; challenge = utfordring; checkpoint = kontrollpunkt; whole song = hele sangen; full take = helt opptak; play along = spill med; listen = lytt.
- Preserve traditional English song titles and Timbre Originals names consistently; translate descriptive subtitles, section labels and connecting prose. Titles that are exact-source proper names or genuinely identical Norwegian music terms are held for independent invariant approval, never changed just to evade copied-English detection. Lyric credits translate connecting words only; sung lyrics remain unchanged.

### Additional course terminology from drafted batches 1–20
- Natural note (no accidental) = tone uten fortegn; e.g. C natural = C uten fortegn. “Ren” is reserved for pitch accuracy/perfect intervals, not the accidental itself.
- Bridge as an instrument part = stol; musical bridge section = bro. Nut = oversadel; tailpiece = strengeholder; endpin = pigg; scroll = snekke; bow frog = frosch; rosin = harpiks; fine tuner = finstemmer.
- Slur = legatobue; slurred notes = bundne toner. Shift (bowed strings) = posisjonsskift; first/fourth position = første/fjerde posisjon. High/low 2 finger placements = høy/lav 2.
- Mandolin course (paired strings) = kor/strengpar; subsequent numbered pair = par. Crosspicking = kryssplukking; chop = hugg; paired-string beats = svevninger.
- Banjo roll = rull; forward roll = foroverrull; alternating thumb roll = rull med vekslende tommel; pinch = dobbeltknips; drone string = bordunstreng; banjo head = skinn.
- Traditional song names generally remain original; established descriptive classical titles use Norwegian: Minuet in G = Menuett i G; Brahms' Lullaby = Brahms’ vuggesang. The Swan is consistently retained as the lesson's title in this draft.
- D/U strumming patterns, p-i-m-a fingering letters, note lists, Roman numeral progressions, and numeric rhythm groupings are notation and stay unchanged. Every exact-source candidate is awaiting independent semantic approval.

### Additional course terminology from drafted batches 21–38
- Unison as a named interval = prim. The shared answer also appears under a two-voices question, so that question explicitly asks which interval the voices form; its explanatory prose still naturally uses “synge unisont”. This is a target-only contextual adaptation, not a source-key change.
- Power chord = powerakkord throughout (including the late Originals and songbook units), matching the earlier lessons and interface anchor. Ordinary interval fifth remains kvint.
- Solfège = solmisasjon; sung do/re/mi/fa/sol/la/ti syllables stay literal. The curriculum uses movable do, with do as hjemmetonen. Ninth interval = none; an answer meaning “none” is ingen, never none.
- Triplet = triol; 1-trip-let becomes 1-tri-ol, preserving three equally spaced syllables and all digits. The swing exercise’s final syllable “let” correspondingly becomes “ol”. W/H scale-pattern codes remain literal, explicitly defined as W = heltone and H = halvtone in the question.
- Time signature = taktart; tie = bindebue, distinct from slur = legatobue. Sixteenth = sekstendel; dotted = punktert. Rhythm exercise tap = trykk (screen), not klapp; explicit physical clapping remains klapp.
- Bare Up/Down answers = Opp/Ned, usable for both pitch direction and physical picking direction. Shared One beat = Ett slag, usable for both duration and a missing beat.
- Because bar and measure both translate as takt, the synonym quiz asks what the English music word “bar” means; its explanation names both English terms and the answer Measure remains Takt. Distractors Beat/Rest remain Slag/Pause.
- Retained song-lyric options Fly/Wide/Boat/Town/Bethlehem identify actual words in the original sung verses; they are proposed exact-source candidates, not English UI leakage. Original lyric fragments in otherwise translated instructions remain unchanged to match the score.
- Additional established/descriptive classical titles: Canon in D = Kanon i D; In the Hall of the Mountain King = I Dovregubbens hall; Morning Mood = Morgenstemning; The Blue Danube = Den blå Donau; Spring = Våren; Mozart’s Symphony No. 40 = Mozarts symfoni nr. 40; Carmen: Prelude = Carmen: forspill. These are used consistently in related prose. Originals brand/song names remain unchanged.
- Chorus = refreng; refrain = omkvæd where the source distinguishes the labels; pre-chorus = førrefreng; medley = potpurri. Musical round = kanon, not the generic game round runde.

### Mnemonic adaptations (target only, exact note order retained)
- E A D G B E: Every Amateur Does Get Better Eventually → En Ape Danser Gjerne Bak Elefanten.
- E A D G: Every Amp Drives Grooves → En Ape Danser Gjerne.
- G D A E: Good Dogs Always Eat → Gode Dager Avler Energi (violin and mandolin).
- C G D A: Cats Go Dancing Around → Celloer Gir Deg Applaus.
- G C E A: Good Cooks Eat Apples → Gode Celloer Elsker Applaus.
- E G B D F: Every Good Boy Does Fine → En Glad Bjørn Danser Fint; all individual-word references are updated consistently.
- G B D F A: Good Boys Do Fine Always → Gode Bjørner Danser For Alle.
- A C E G: All Cows Eat Grass → Alle Celloer Elsker Gitarer.
- F A C E stays FACE, described explicitly as an English word. The introductory note-alphabet sentence says “Her bruker vi …” to make the curriculum’s B-not-H convention clear without claiming that all Norwegian notation follows it.

The completed lesson draft is not independently reviewed or device-tested. Exact-source candidate reasons and source-context adaptation receipts are supplied separately in the author handoff; they are not invariant approvals.
