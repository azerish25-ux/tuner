# Swedish (sv) glossary

> **Intonation: current source context.** App key `Intonation` labels the guided 12th-fret instrument-setup check (`IntonationView`: harmonic/fretted comparison and saddle advice). `Intonation over a drone` is separate pitch-accuracy practice; lesson uses follow their own context. This rule supersedes copied drone-only definitions and “never saddle/octave adjustment” claims below.

Review: AI-reviewed working glossary, 2026-10-25. Not human-approved. Native musician and device review remain outstanding. Applies to interface and the full lesson curriculum. Swedish lesson author draft complete (6,082 strings), 2026-10-26; independent semantic review, human/native-musician review and device review are not claimed.

## 1. Locale decisions
- Locale/variant: sv, standard Swedish; Norwegian is Bokmål.
- Register: Informal singular, warm direct second person; avoid gender assumptions. Short imperative actions; noun labels; third-person VoiceOver hints. Avoid reader-gender marking.
- Typography: sentence case, normal word spaces, no double or edge spaces. Curly apostrophe where needed; single ellipsis …. Quotes follow shipped table (Nordic ”…”/“…”; Baltic „…“/„…”; sw/zu “…”). Digits ASCII 0–9. Preserve line structure.
- Units: Hz, BPM, XP, ¢, A4 unchanged; cents = Cent. Minutes use existing minutes entry; seconds s, milliseconds ms on screen, full words in spoken hints.
- Notes: preserve inserted note names and all placeholders without inflecting them. No lesson note respelling. Accidentals follow existing note-name entries, never confuse with tuner direction: flat = för lågt; sharp = för högt. Double accidentals repeat the musical alteration, not the direction word.
- Legal Settings path: Inställningar › Apple-konto › Prenumerationer. For languages without localized iOS system UI, retain the actual English path, not invented translated system menu labels. Apple’s iOS 26 language-support list excludes is/et/lt/lv/sw/zu; English system-path labels retained (https://images.apple.com/ie/iphone-16/specs/). In-app Settings retains Inställningar.
- Apple features: preserve product names Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri; use shipped system labels, never invent product names. Home/Lock Screen and accessibility feature names require device verification when first encountered.
- Siri: natural imperative, retain ${applicationName} and every named token.
- Brands: Timbre, Timbre Pro, Pro, ChordPro unchanged and uninflected. Keep [G], ChordPro directives, URLs, ›, ·, ×, arrows and all format tokens verbatim.
- Musical tuning terminology overrides: the drone-training Intonation is pitch accuracy, not saddle adjustment. da/no/sv Temperament means musical temperament (not physical temperature); use Temperering / Temperering / Temperering respectively when this source occurs.

### Explicit locale conventions
- Exact address: du.
- Quotation marks: ”…”; no spaces inside quotation marks. Other punctuation uses normal Western spacing.
- Units, spoken and compact: cent; minuter/min; sekunder/s; millisekunder/ms. Spoken VoiceOver labels use full words, not the screen abbreviation.
- Musical accidentals (sharp / flat / double sharp / double flat): kors; b; dubbelkors; dubbel-b. These are notation terms; the tuner direction terms above instead describe whether the pitch is too low or high.
- Apple feature labels (Home Screen / Lock Screen / widget / Live Activity / Shortcuts / Control Center / Family Sharing): Hemskärm; låsskärm; widget; Liveaktivitet; Genvägar; Kontrollcenter; Familjedelning. Product names remain unchanged. Verify supported-system labels on device before release; English names deliberately retained for unsupported system UI languages.
- Instrument names: use the already localized `timbre_catalog_*` names; do not substitute English when a localized catalogue name exists. Tuning presets use the existing `timbre_catalog_tuning_*` names, preserving Drop/Open note letters and DADGAD.
- Counted flat strings: prefer a count-neutral label for unknown counts where inflection differs; never attach a case suffix to a placeholder. Numeric chord 7 and 3D stay numeric; musical symbols and cents sign stay unchanged.

## 2. Terms
Existing shipped terminology below is binding by sense and may be grammatically inflected, except inserted values and brand names. Supplemented terms precede anchors and override them only for the same sense.

| English | Meaning | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Songs | Music/app sense | UI | `Songs` | Låtar | AI-reviewed |
| Your songs | Music/app sense | UI | `Your songs` | Dina låtar | AI-reviewed |
| Chart | Music/app sense | UI | `Chart` | Ackorddiagram | AI-reviewed |
| Player view | Music/app sense | UI | `Player view` | Spelarvy | AI-reviewed |
| Chord view | Music/app sense | UI | `Chord view` | Ackordvy | AI-reviewed |
| Neck view | Music/app sense | UI | `Neck view` | Greppbrädesvy | AI-reviewed |
| Show me | Music/app sense | UI | `Show me` | Visa mig | AI-reviewed |
| Strum to tune | Music/app sense | UI | `Strum to tune` | Slå an för att stämma | AI-reviewed |
| Tune by feel | Music/app sense | UI | `Tune by feel` | Stäm med känseln | AI-reviewed |
| Feel | Music/app sense | UI | `Feel` | Känn | AI-reviewed |
| Placement check | Music/app sense | UI | `Placement check` | Nivåtest | AI-reviewed |
| Final take | Music/app sense | UI | `Final take` | Sista tagning | AI-reviewed |
| Expert | Music/app sense | UI | `Expert` | Expert | AI-reviewed |
| Capo | Music/app sense | UI | `Capo` | Capo | AI-reviewed |
| Transpose | Music/app sense | UI | `Transpose` | Transponera | AI-reviewed |
| Verse | Music/app sense | UI | `Verse` | Vers | AI-reviewed |
| Chorus | Music/app sense | UI | `Chorus` | Refräng | AI-reviewed |
| Bridge | Music/app sense | UI | `Bridge` | Brygga | AI-reviewed |
| Quest | Music/app sense | UI | `Quest` | Uppdrag | AI-reviewed |
| Song sheet | Music/app sense | UI | `Song sheet` | Låtblad | AI-reviewed |
| string | Music/app sense | UI | `string` | sträng | AI-reviewed |
| peg | Music/app sense | UI | `peg` | stämskruv | AI-reviewed |
| headstock | Music/app sense | UI | `headstock` | huvud | AI-reviewed |
| fret | Music/app sense | UI | `fret` | band | AI-reviewed |
| open string | Music/app sense | UI | `open string` | öppen sträng | AI-reviewed |
| chord shape | Music/app sense | UI | `chord shape` | ackordgrepp | AI-reviewed |
| barre | Music/app sense | UI | `barre` | barré | AI-reviewed |
| minor | Music/app sense | UI | `minor` | moll | AI-reviewed |
| seventh | Music/app sense | UI | `seventh` | septima | AI-reviewed |
| power chord | Music/app sense | UI | `power chord` | powerackord | AI-reviewed |
| half step | Music/app sense | UI | `half step` | halvtonssteg | AI-reviewed |
| whole step | Music/app sense | UI | `whole step` | heltonssteg | AI-reviewed |
| third | Music/app sense | UI | `third` | ters | AI-reviewed |
| fifth | Music/app sense | UI | `fifth` | kvint | AI-reviewed |
| bar | Music/app sense | UI | `bar` | takt | AI-reviewed |
| beat | Music/app sense | UI | `beat` | slag | AI-reviewed |
| downbeat | Music/app sense | UI | `downbeat` | första slaget | AI-reviewed |
| strum | Music/app sense | UI | `strum` | anslag | AI-reviewed |
| downstroke | Music/app sense | UI | `downstroke` | nedslag | AI-reviewed |
| upstroke | Music/app sense | UI | `upstroke` | uppslag | AI-reviewed |
| mute | Music/app sense | UI | `mute` | dämpa | AI-reviewed |
| pick | Music/app sense | UI | `pick` | plektrum | AI-reviewed |
| fingerpicking | Music/app sense | UI | `fingerpicking` | fingerspel | AI-reviewed |
| bowing | Music/app sense | UI | `bowing` | stråkföring | AI-reviewed |
| tune (melody) | Music/app sense | UI | `tune (melody)` | melodi | AI-reviewed |
| cadence | Music/app sense | UI | `cadence` | kadens | AI-reviewed |
| pickup | Music/app sense | UI | `pickup` | upptakt | AI-reviewed |
| section | Music/app sense | UI | `section` | avsnitt | AI-reviewed |
| streak | Music/app sense | UI | `streak` | dagar i rad | AI-reviewed |
| streak freeze | Music/app sense | UI | `streak freeze` | svitskydd | AI-reviewed |
| badge | Music/app sense | UI | `badge` | märke | AI-reviewed |
| achievement | Music/app sense | UI | `achievement` | prestation | AI-reviewed |
| round | Music/app sense | UI | `round` | runda | AI-reviewed |
| course | Music/app sense | UI | `course` | kurs | AI-reviewed |
| unit | Music/app sense | UI | `unit` | enhet | AI-reviewed |
| step | Music/app sense | UI | `step` | steg | AI-reviewed |
| quiz | Music/app sense | UI | `quiz` | frågesport | AI-reviewed |
| hint | Music/app sense | UI | `hint` | tips | AI-reviewed |
| subscription | Music/app sense | UI | `subscription` | prenumeration | AI-reviewed |
| renew | Music/app sense | UI | `renew` | förnya | AI-reviewed |
| cancel subscription | Music/app sense | UI | `cancel subscription` | säga upp | AI-reviewed |
| payment method | Music/app sense | UI | `payment method` | betalningsmetod | AI-reviewed |
| billing issue | Music/app sense | UI | `billing issue` | betalningsproblem | AI-reviewed |
| trial ends | Music/app sense | UI | `trial ends` | provperioden slutar | AI-reviewed |
| Intro | Music/app sense | UI | `Intro` | Intro | AI-reviewed |
| Solo | Music/app sense | UI | `Solo` | Solo | AI-reviewed |
| Outro | Music/app sense | UI | `Outro` | Outro | AI-reviewed |
| Tag | Music/app sense | UI | `Tag` | Avslutning | AI-reviewed |
| Originals | Music/app sense | UI | `Originals` | Original | AI-reviewed |
| Standards & Classics | Music/app sense | UI | `Standards & Classics` | Standards och klassiker | AI-reviewed |
| Music Theory | Music/app sense | UI | `Music Theory` | Musikteori | AI-reviewed |
| Singing | Music/app sense | UI | `Singing` | Sång | AI-reviewed |
| A4 | Existing app sense | UI | `A4` | A4 | Existing table anchor |
| Banjo | Existing app sense | UI | `Banjo` | Banjo | Existing table anchor |
| Bass | Existing app sense | UI | `Bass` | Bas | Existing table anchor |
| Cello | Existing app sense | UI | `Cello` | Cello | Existing table anchor |
| Cents | Existing app sense | UI | `Cents` | Cent | Existing table anchor |
| Chords | Existing app sense | UI | `Chords` | Ackord | Existing table anchor |
| Chromatic | Existing app sense | UI | `Chromatic` | Kromatisk | Existing table anchor |
| Drone | Existing app sense | UI | `Drone` | Bordun | Existing table anchor |
| Ear training | Existing app sense | UI | `Ear training` | Gehörsträning | Existing table anchor |
| Free trial | Existing app sense | UI | `Free trial` | Gratis provperiod | Existing table anchor |
| Guitar | Existing app sense | UI | `Guitar` | Gitarr | Existing table anchor |
| Haptics | Existing app sense | UI | `Haptics` | Haptik | Existing table anchor |
| Hz | Existing app sense | UI | `Hz` | Hz | Existing table anchor |
| In tune | Existing app sense | UI | `In tune` | Stämd | Existing table anchor |
| Intervals | Existing app sense | UI | `Intervals` | Intervall | Existing table anchor |
| Lifetime | Existing app sense | UI | `Lifetime` | Livstid | Existing table anchor |
| Major | Existing app sense | UI | `Major` | Dur | Existing table anchor |
| Mandolin | Existing app sense | UI | `Mandolin` | Mandolin | Existing table anchor |
| Metronome | Existing app sense | UI | `Metronome` | Metronom | Existing table anchor |
| Monthly | Existing app sense | UI | `Monthly` | Månadsvis | Existing table anchor |
| Note names | Existing app sense | UI | `Note names` | Tonnamn | Existing table anchor |
| Octave | Existing app sense | UI | `Octave` | Oktav | Existing table anchor |
| Practice | Existing app sense | UI | `Practice` | Öva | Existing table anchor |
| Privacy policy | Existing app sense | UI | `Privacy policy` | Integritetspolicy | Existing table anchor |
| Pro | Existing app sense | UI | `Pro` | Pro | Existing table anchor |
| Real-time 3D | Existing app sense | UI | `Real-time 3D` | 3D i realtid | Existing table anchor |
| Restore purchases | Existing app sense | UI | `Restore purchases` | Återställ köp | Existing table anchor |
| Rhythm | Existing app sense | UI | `Rhythm` | Rytm | Existing table anchor |
| Sargam | Existing app sense | UI | `Sargam` | Sargam | Existing table anchor |
| Scales | Existing app sense | UI | `Scales` | Skalor | Existing table anchor |
| Settings | Existing app sense | UI | `Settings` | Inställningar | Existing table anchor |
| Slower | Existing app sense | UI | `Slower` | Långsammare | Existing table anchor |
| Solfège | Existing app sense | UI | `Solfège` | Solmisation | Existing table anchor |
| Speed trainer | Existing app sense | UI | `Speed trainer` | Tempotränare | Existing table anchor |
| Studio (lighter) | Existing app sense | UI | `Studio (lighter)` | Studio (lättare) | Existing table anchor |
| Tanpura | Existing app sense | UI | `Tanpura` | Tanpura | Existing table anchor |
| Temperament | Existing app sense | UI | `Temperament` | Temperatur | Existing table anchor |
| Tempo | Existing app sense | UI | `Tempo` | Tempo | Existing table anchor |
| Terms | Existing app sense | UI | `Terms` | Villkor | Existing table anchor |
| Timbre | Existing app sense | UI | `Timbre` | Timbre | Existing table anchor |
| Timbre Pro | Existing app sense | UI | `Timbre Pro` | Timbre Pro | Existing table anchor |
| Today | Existing app sense | UI | `Today` | I dag | Existing table anchor |
| Tonic | Existing app sense | UI | `Tonic` | Grundton | Existing table anchor |
| Tune | Existing app sense | UI | `Tune` | Stäm | Existing table anchor |
| Tune up | Existing app sense | UI | `Tune up` | Stäm instrumentet | Existing table anchor |
| Tuning | Existing app sense | UI | `Tuning` | Stämning | Existing table anchor |
| Ukulele | Existing app sense | UI | `Ukulele` | Ukulele | Existing table anchor |
| Violin | Existing app sense | UI | `Violin` | Violin | Existing table anchor |
| Yearly | Existing app sense | UI | `Yearly` | Årsvis | Existing table anchor |
| best run | Existing app sense | UI | `best run` | bästa svit | Existing table anchor |
| minutes | Existing app sense | UI | `minutes` | minuter | Existing table anchor |
| Practice streak | Existing app sense | UI | `Practice streak` | Övningssvit | Existing table anchor |
| Achievements | Existing app sense | UI | `Achievements` | Prestationer | Existing table anchor |
| Ear trainer | Existing app sense | UI | `Ear trainer` | Gehörstränare | Existing table anchor |
| Intonation | Existing app sense | UI | `Intonation` | Intonation | Existing table anchor |
| Progress | Existing app sense | UI | `Progress` | Framsteg | Existing table anchor |
| flat | Existing app sense | UI | `flat` | för lågt | Existing table anchor |
| sharp | Existing app sense | UI | `sharp` | för högt | Existing table anchor |
| Learn | Existing app sense | UI | `Learn` | Lär dig | Existing table anchor |
| Lesson | Existing app sense | UI | `Lesson` | Lektion | Existing table anchor |
| Next | Existing app sense | UI | `Next` | Nästa | Existing table anchor |
| Play along | Existing app sense | UI | `Play along` | Spela med | Existing table anchor |
| XP | Existing app sense | UI | `XP` | XP | Existing table anchor |
| Streak freeze earned | Existing app sense | UI | `Streak freeze earned` | Svitskydd intjänat | Existing table anchor |
| Streak saved | Existing app sense | UI | `Streak saved` | Sviten är räddad | Existing table anchor |
| Precision | Existing app sense | UI | `Precision` | Precision | Existing table anchor |
| Beginner | Existing app sense | UI | `Beginner` | Nybörjare | Existing table anchor |
| Standard | Existing app sense | UI | `Standard` | Standard | Existing table anchor |
| Fretted | Existing app sense | UI | `Fretted` | Nedtryckt | Existing table anchor |
| Saddle | Existing app sense | UI | `Saddle` | Sadel | Existing table anchor |
| Bullseye | Existing app sense | UI | `Bullseye` | Fullträff | Existing table anchor |
| Songbook | Existing app sense | UI | `Songbook` | Sångbok | Existing table anchor |
| Concert Pitch | Existing app sense | UI | `Concert Pitch` | Kammartonen | Existing table anchor |
| A flat | Existing app sense | UI | `A flat` | As | Existing table anchor |
| A sharp | Existing app sense | UI | `A sharp` | Ais | Existing table anchor |
| Combo | Existing app sense | UI | `Combo` | Kombo | Existing table anchor |
| D sharp | Existing app sense | UI | `D sharp` | Dis | Existing table anchor |
| E flat | Existing app sense | UI | `E flat` | Ess | Existing table anchor |
| Key | Existing app sense | UI | `Key` | Tonart | Existing table anchor |

## 3. Course and song names
Use the instrument-name anchors for Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo. Songs equals the Songs tab. Ear Training/Rhythm reuse existing feature terminology; Music Theory/Singing and Originals/Standards & Classics are specified above. Songbook reuses the existing anchor. The full lesson corpus is being localized in Swedish. Keep English song titles unless a firmly established local title exists; preserve traditional proper names and Timbre Originals titles. A title in prose must exactly match its lesson title. Lyric credits retain names and years, translating only connecting words; lyrics are not translated.

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

### Lesson drafting conventions (2026-10-26, awaiting independent review)
- Standard Swedish teaching voice, du. Notes keep source letters, including B; symbolic ♯/♭ and all chord notation remain exact. Spelled accidentals use Swedish names (C sharp = Ciss, F sharp = Fiss, B flat = Bess), never insert new accidental symbols.
- Established localized titles used consistently: Ode to Joy = Ode till glädjen; Twinkle, Twinkle, Little Star = Blinka lilla stjärna; Row, Row, Row Your Boat = Ro, ro, ro din båt. Other song titles and Timbre Originals titles retain their proper names.
- Intervals: Second = Sekund, Third = Ters, Fourth = Kvart. Frozen TODO/batch contexts still show historical finger uses. The publisher source repair has now been applied: all current generic uses are intervals, and explicit finger keys carry ordinal finger answers. Current shared-context evidence was verified on 2026-10-26; historical batch metadata is intentionally unchanged.
- Finger numbers remain exact. Explicit First finger / Third finger / Little finger = Första fingret / Tredje fingret / Lillfingret.
- Picking = plock or slå an by context; fingerpicking = fingerspel; Travis picking = Travisplock; palm muting = handflatedämpning. Hammer-on, pull-off, slide, bend, vibrato retain established loanwords.
- Seventh chord = septimackord; major seventh = stor septima; minor seventh = liten septima; minor seventh chord = mollseptimackord. Keep numeric symbols only where source uses digits.
- Major/minor pentatonic = dur-/mollpentatonik. Dorian/Mixolydian = dorisk/mixolydisk. CAGED and p-i-m-a remain notation.
- D/U strumming shorthand remains exact notation pending independent contextual review; surrounding prose uses ned/upp. Island strum = ö-kompet.
- Mnemonics are adapted while preserving note initials: EADGBE = En Apa Dansar Gärna Bakom Eken; GCEA = Goda Citroner Eller Apelsiner.
- Exact-source proper names, credits, notation and genuine Swedish loanword invariants are drafted in batch outputs but held out by the importer for independent semantic review. No fake differences or self-approved invariant registry entries.

### Additional lesson decisions through batch 018
- Timbre Original in descriptive prose = originallåt från Timbre; the navigation category Originals stays Original. This avoids an English noun phrase in otherwise Swedish prose.
- Additional established titles: The Swan = Svanen; The Carnival of the Animals = Djurens karneval; Brahms’ Lullaby = Brahms vaggvisa; Minuet in G = Menuett i G.
- String teaching: bow = stråke, down-/up-bow = nedstråk/uppstråk, frog = frosch, scroll = snäcka, tailpiece = stränghållare, rosin = harts, endpin = stackel. Shift = lägesväxling; fourth position = fjärde läget.
- GDAE mnemonic = Glada Djur Arbetar Enigt; CGDA = Cirkusens Glada Djur Arbetar; EADG = En Apa Dansar Gärna. Every initial matches the unchanged source note sequence.
- Mandolin pairs = strängpar/par (courses introduced as körer); beating = svävning; chop = hugg. Banjo pinch = dubbelknäpp, roll = rullning, forward roll = framåtrullning. Crosspicking and clawhammer retain their established technique names. Mountain minor is retained as the named Appalachian sound, not asserted to be an established Swedish term.
- One draft soft-layout exception through batch 018: “Pekfinger, långfinger, pekfinger, långfinger” is 44 characters vs target 42. Retain complete, intelligible finger names pending visual review.

### Completion decisions through batch 033 (author draft, not independent approval)
- All 6,082 strings are directly authored. 390 exact-source candidates remain held for independent semantic acceptance; they are not omissions. The combined review artifact includes them. Original input/map/output batches are retained; a keyed, hash-bound `author-corrections.json` overlay records 119 author corrections without replacing original output bytes.
- Open notes use the earlier curriculum convention **öppet E**, **öppet G**; open string = **öppen sträng**. Late-batch wording was harmonized for grammatical agreement. **Power chord = powerackord** throughout; **home note = hemmatonen**. Avoid the ambiguous compound *femtonsmönster*: five-note patterns = **mönster med fem toner**.
- Pre-chorus = **Refrängbrygga**, distinct from Bridge = Brygga. Major/minor interval quality = stor/liten; perfect = ren; augmented = överstigande; diminished = förminskad. Seventh chords retain the prior septimackord terminology, not added digits.
- Staff = notsystem; treble clef = G-klav; bass clef = F-klav/basklav; ledger lines = hjälplinjer; key signature = fasta förtecken. Middle C = ettstrukna C; scientific pitch labels such as C4 stay exact. Slur = legatobåge; tie = bindebåge.
- Rhythm tapping = knacka (not a button-tap instruction). Triplet = triol; count 1-trip-let is adapted to **1-tri-ol**, with the last syllable **ol** and all digits retained. Offbeat = mellanslag/och-slag, backbeat = baktakt. Lip trills = läppdallring; solfege = solmisation.
- Bare shared Up/Down = **Upp/Ned**, neutral for both pitch direction and mandolin picking direction (41 uses each, 11 distinct quiz contexts each). One beat = **Ett slag**, neutral for duration and missing-beat questions (8 uses, 7 distinct contexts). These are not past-tense or pitch-only answers.
- Bare Half = Halvkadens; Authentic = Autentisk; Plagal = Plagal; Deceptive = Bedräglig. Current shared contexts are exclusively cadence choices; Plagal remains an exact-source candidate rather than a registered exemption.
- Bass clef line mnemonic GBDFA = **Glada Björnar Dansar Framför Alla**; bass spaces ACEG = **Alla Clowner Efterliknar Grisar**; treble lines EGBDF = **En Glad Björn Dansar Fint**. FACE is explicitly introduced as an English word, preserving its note letters. The W/H scale-recipe notation stays exact and is explicitly defined as W = hel, H = halv.
- Additional localized titles: Jingle Bells = Bjällerklang; Frère Jacques = Broder Jakob; Canon in D = Kanon i D; Largo, New World Symphony = Largo, symfonin Från nya världen; In the Hall of the Mountain King = I bergakungens sal; Silent Night = Stilla natt; Morning Mood = Morgonstämning; Spring = Våren; The Four Seasons = De fyra årstiderna; The Planets = Planeterna; The Blue Danube = An der schönen blauen Donau; Can-can = Cancan; O Christmas Tree = O Tannenbaum (the lesson sings the German text); Holy, Holy, Holy = Helig, helig, helig; Abide with Me = Bliv kvar hos mig; Nearer, My God, to Thee = Närmare, Gud, till dig. Für Elise retains its familiar title.
- **Baa, Baa, Black Sheep remains the English title**: Swedish Bä, bä, vita lamm uses a different melody and would falsify the shared-melody quiz explanation. Old MacDonald Had a Farm likewise remains the title taught, not replaced with a different local song. English sung lyric words and lyric cues remain English, while their instructional framing is translated.

### Approved bounded bar/measure adaptation
Source “What's another word for a bar?” becomes **Vilket ord betyder samma sak som engelskans bar?**. Explanation “Bar and measure mean the same thing.” becomes **Engelskans bar och measure betyder båda takt.** Shared choices remain normal Swedish: Beat = **Slag**, Rest = **Paus**, Measure = **Takt**. The preceding explanation introduces the English synonyms alongside Swedish takt. This preserves the intended correct answer and musical concept without a circular Swedish synonym quiz or globally retaining English answer choices. The parent explicitly approved this refined wording and superseded an earlier definition-question suggestion. No source/key migration was made. The current publisher has one use of each affected question/choice/explanation; evidence and exact parent receipt are in the frozen review handoff.

### Remaining review boundary
One soft length warning remains: “Pekfinger, långfinger, pekfinger, långfinger” is 44 characters against 42. Full finger names are intentionally retained for comprehension pending visual review. Mechanical QA does not establish linguistic, native-musician, accessibility or device approval. Shared-key context evidence, all exact-source candidates and adapted mnemonics/titles must be independently checked.

## Reviewed shared musical-item ordinals

These exact shared-key decisions supersede conflicting earlier draft labels. The first = Det första exemplet; The second = Det andra exemplet. Refer to musical-example order, never displayed answer-button position. Complete current contexts and source-bound correction evidence are in ../reviews/shared-ordinal-labels/. Independent AI review only, not native-human/device certification.
