# Danish (da) glossary

Review: AI-reviewed working glossary, 2026-10-25. Not human-approved. Native musician and device review remain outstanding. Applies to interface and the lesson draft. Lesson draft by /root/translate_danish_lessons, 2026-10-26; independent semantic review pending.

## 1. Locale decisions
- Locale/variant: da, standard Danish; Norwegian is Bokmål.
- Register: Informal singular, warm direct second person; avoid gender assumptions. Short imperative actions; noun labels; third-person VoiceOver hints. Avoid reader-gender marking.
- Typography: sentence case, normal word spaces, no double or edge spaces. Curly apostrophe where needed; single ellipsis …. Quotes follow shipped table (Nordic ”…”/“…”; Baltic „…“/„…”; sw/zu “…”). Digits ASCII 0–9. Preserve line structure.
- Units: Hz, BPM, XP, ¢, A4 unchanged; cents = Cent. Minutes use existing minutes entry; seconds s, milliseconds ms on screen, full words in spoken hints.
- Notes: preserve inserted note names and all placeholders without inflecting them. No lesson note respelling. Accidentals follow existing note-name entries, never confuse with tuner direction: flat = for lavt; sharp = for højt. Double accidentals repeat the musical alteration, not the direction word.
- Legal Settings path: Indstillinger › Apple-konto › Abonnementer. For languages without localized iOS system UI, retain the actual English path, not invented translated system menu labels. Apple’s iOS 26 language-support list excludes is/et/lt/lv/sw/zu; English system-path labels retained (https://images.apple.com/ie/iphone-16/specs/). In-app Settings retains Indstillinger.
- Apple features: preserve product names Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri; use shipped system labels, never invent product names. Home/Lock Screen and accessibility feature names require device verification when first encountered.
- Siri: natural imperative, retain ${applicationName} and every named token.
- Brands: Timbre, Timbre Pro, Pro, ChordPro unchanged and uninflected. Keep [G], ChordPro directives, URLs, ›, ·, ×, arrows and all format tokens verbatim.
- Musical tuning terminology overrides: the drone-training Intonation is pitch accuracy, not saddle adjustment. da/no/sv Temperament means musical temperament (not physical temperature); use Temperering / Temperering / Temperering respectively when this source occurs.

### Explicit locale conventions
- Exact address: du.
- Quotation marks: “…”; no spaces inside quotation marks. Other punctuation uses normal Western spacing.
- Units, spoken and compact: cent; minutter/min.; sekunder/s; millisekunder/ms. Spoken VoiceOver labels use full words, not the screen abbreviation.
- Musical accidentals (sharp / flat / double sharp / double flat): kryds; b; dobbeltkryds; dobbelt-b. These are notation terms; the tuner direction terms above instead describe whether the pitch is too low or high.
- Apple feature labels (Home Screen / Lock Screen / widget / Live Activity / Shortcuts / Control Center / Family Sharing): Hjemmeskærm; låseskærm; widget; Liveaktivitet; Genveje; Kontrolcenter; Familiedeling. Product names remain unchanged. Verify supported-system labels on device before release; English names deliberately retained for unsupported system UI languages.
- Instrument names: use the already localized `timbre_catalog_*` names; do not substitute English when a localized catalogue name exists. Tuning presets use the existing `timbre_catalog_tuning_*` names, preserving Drop/Open note letters and DADGAD.
- Counted flat strings: prefer a count-neutral label for unknown counts where inflection differs; never attach a case suffix to a placeholder. Numeric chord 7 and 3D stay numeric; musical symbols and cents sign stay unchanged.

## 2. Terms
Existing shipped terminology below is binding by sense and may be grammatically inflected, except inserted values and brand names. Supplemented terms precede anchors and override them only for the same sense.

| English | Meaning | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Songs | Music/app sense | UI | `Songs` | Sange | AI-reviewed |
| Your songs | Music/app sense | UI | `Your songs` | Dine sange | AI-reviewed |
| Chart | Music/app sense | UI | `Chart` | Akkorddiagram | AI-reviewed |
| Player view | Music/app sense | UI | `Player view` | Spillervisning | AI-reviewed |
| Chord view | Music/app sense | UI | `Chord view` | Akkordvisning | AI-reviewed |
| Neck view | Music/app sense | UI | `Neck view` | Gribebrætvisning | AI-reviewed |
| Show me | Music/app sense | UI | `Show me` | Vis mig | AI-reviewed |
| Strum to tune | Music/app sense | UI | `Strum to tune` | Slå an for at stemme | AI-reviewed |
| Tune by feel | Music/app sense | UI | `Tune by feel` | Stem med følesansen | AI-reviewed |
| Feel | Music/app sense | UI | `Feel` | Mærk | AI-reviewed |
| Placement check | Music/app sense | UI | `Placement check` | Niveautjek | AI-reviewed |
| Final take | Music/app sense | UI | `Final take` | Sidste optagelse | AI-reviewed |
| Expert | Music/app sense | UI | `Expert` | Ekspert | AI-reviewed |
| Capo | Music/app sense | UI | `Capo` | Capo | AI-reviewed |
| Transpose | Music/app sense | UI | `Transpose` | Transponer | AI-reviewed |
| Verse | Music/app sense | UI | `Verse` | Vers | AI-reviewed |
| Chorus | Music/app sense | UI | `Chorus` | Omkvæd | AI-reviewed |
| Bridge | Music/app sense | UI | `Bridge` | Kontraststykke | AI-reviewed |
| Quest | Music/app sense | UI | `Quest` | Mission | AI-reviewed |
| Song sheet | Music/app sense | UI | `Song sheet` | Sangark | AI-reviewed |
| string | Music/app sense | UI | `string` | streng | AI-reviewed |
| peg | Music/app sense | UI | `peg` | stemmeskrue | AI-reviewed |
| headstock | Music/app sense | UI | `headstock` | hoved | AI-reviewed |
| fret | Music/app sense | UI | `fret` | bånd | AI-reviewed |
| open string | Music/app sense | UI | `open string` | løs streng | AI-reviewed |
| chord shape | Music/app sense | UI | `chord shape` | akkordgreb | AI-reviewed |
| barre | Music/app sense | UI | `barre` | barré | AI-reviewed |
| minor | Music/app sense | UI | `minor` | mol | AI-reviewed |
| seventh | Music/app sense | UI | `seventh` | septim | AI-reviewed |
| power chord | Music/app sense | UI | `power chord` | powerakkord | AI-reviewed |
| half step | Music/app sense | UI | `half step` | halvtonetrin | AI-reviewed |
| whole step | Music/app sense | UI | `whole step` | heltonetrin | AI-reviewed |
| third | Music/app sense | UI | `third` | terts | AI-reviewed |
| fifth | Music/app sense | UI | `fifth` | kvint | AI-reviewed |
| bar | Music/app sense | UI | `bar` | takt | AI-reviewed |
| beat | Music/app sense | UI | `beat` | slag | AI-reviewed |
| downbeat | Music/app sense | UI | `downbeat` | første slag | AI-reviewed |
| strum | Music/app sense | UI | `strum` | anslag | AI-reviewed |
| downstroke | Music/app sense | UI | `downstroke` | nedslag | AI-reviewed |
| upstroke | Music/app sense | UI | `upstroke` | opslag | AI-reviewed |
| mute | Music/app sense | UI | `mute` | dæmp | AI-reviewed |
| pick | Music/app sense | UI | `pick` | plekter | AI-reviewed |
| fingerpicking | Music/app sense | UI | `fingerpicking` | fingerspil | AI-reviewed |
| bowing | Music/app sense | UI | `bowing` | buestrøg | AI-reviewed |
| tune (melody) | Music/app sense | UI | `tune (melody)` | melodi | AI-reviewed |
| cadence | Music/app sense | UI | `cadence` | kadence | AI-reviewed |
| pickup | Music/app sense | UI | `pickup` | optakt | AI-reviewed |
| section | Music/app sense | UI | `section` | afsnit | AI-reviewed |
| streak | Music/app sense | UI | `streak` | dage i træk | AI-reviewed |
| streak freeze | Music/app sense | UI | `streak freeze` | rækkebeskyttelse | AI-reviewed |
| badge | Music/app sense | UI | `badge` | mærke | AI-reviewed |
| achievement | Music/app sense | UI | `achievement` | præstation | AI-reviewed |
| round | Music/app sense | UI | `round` | runde | AI-reviewed |
| course | Music/app sense | UI | `course` | kursus | AI-reviewed |
| unit | Music/app sense | UI | `unit` | del | AI-reviewed |
| step | Music/app sense | UI | `step` | trin | AI-reviewed |
| quiz | Music/app sense | UI | `quiz` | quiz | AI-reviewed |
| hint | Music/app sense | UI | `hint` | tip | AI-reviewed |
| subscription | Music/app sense | UI | `subscription` | abonnement | AI-reviewed |
| renew | Music/app sense | UI | `renew` | forny | AI-reviewed |
| cancel subscription | Music/app sense | UI | `cancel subscription` | opsig | AI-reviewed |
| payment method | Music/app sense | UI | `payment method` | betalingsmetode | AI-reviewed |
| billing issue | Music/app sense | UI | `billing issue` | betalingsproblem | AI-reviewed |
| trial ends | Music/app sense | UI | `trial ends` | prøveperioden slutter | AI-reviewed |
| Intro | Music/app sense | UI | `Intro` | Intro | AI-reviewed |
| Solo | Music/app sense | UI | `Solo` | Solo | AI-reviewed |
| Outro | Music/app sense | UI | `Outro` | Outro | AI-reviewed |
| Tag | Music/app sense | UI | `Tag` | Afslutning | AI-reviewed |
| Originals | Music/app sense | UI | `Originals` | Originaler | AI-reviewed |
| Standards & Classics | Music/app sense | UI | `Standards & Classics` | Standards og klassikere | AI-reviewed |
| Music Theory | Music/app sense | UI | `Music Theory` | Musikteori | AI-reviewed |
| Singing | Music/app sense | UI | `Singing` | Sang | AI-reviewed |
| A4 | Existing app sense | UI | `A4` | A4 | Existing table anchor |
| Banjo | Existing app sense | UI | `Banjo` | Banjo | Existing table anchor |
| Bass | Existing app sense | UI | `Bass` | Bas | Existing table anchor |
| Cello | Existing app sense | UI | `Cello` | Cello | Existing table anchor |
| Cents | Existing app sense | UI | `Cents` | Cent | Existing table anchor |
| Chords | Existing app sense | UI | `Chords` | Akkorder | Existing table anchor |
| Chromatic | Existing app sense | UI | `Chromatic` | Kromatisk | Existing table anchor |
| Drone | Existing app sense | UI | `Drone` | Bordun | Existing table anchor |
| Ear training | Existing app sense | UI | `Ear training` | Gehørtræning | Existing table anchor |
| Free trial | Existing app sense | UI | `Free trial` | Gratis prøveperiode | Existing table anchor |
| Guitar | Existing app sense | UI | `Guitar` | Guitar | Existing table anchor |
| Haptics | Existing app sense | UI | `Haptics` | Haptik | Existing table anchor |
| Hz | Existing app sense | UI | `Hz` | Hz | Existing table anchor |
| In tune | Existing app sense | UI | `In tune` | Stemt | Existing table anchor |
| Intervals | Existing app sense | UI | `Intervals` | Intervaller | Existing table anchor |
| Lifetime | Existing app sense | UI | `Lifetime` | Livstid | Existing table anchor |
| Major | Existing app sense | UI | `Major` | Dur | Existing table anchor |
| Mandolin | Existing app sense | UI | `Mandolin` | Mandolin | Existing table anchor |
| Metronome | Existing app sense | UI | `Metronome` | Metronom | Existing table anchor |
| Monthly | Existing app sense | UI | `Monthly` | Månedlig | Existing table anchor |
| Note names | Existing app sense | UI | `Note names` | Tonenavne | Existing table anchor |
| Octave | Existing app sense | UI | `Octave` | Oktav | Existing table anchor |
| Practice | Existing app sense | UI | `Practice` | Øv | Existing table anchor |
| Privacy policy | Existing app sense | UI | `Privacy policy` | Privatlivspolitik | Existing table anchor |
| Pro | Existing app sense | UI | `Pro` | Pro | Existing table anchor |
| Real-time 3D | Existing app sense | UI | `Real-time 3D` | 3D i realtid | Existing table anchor |
| Restore purchases | Existing app sense | UI | `Restore purchases` | Gendan køb | Existing table anchor |
| Rhythm | Existing app sense | UI | `Rhythm` | Rytme | Existing table anchor |
| Sargam | Existing app sense | UI | `Sargam` | Sargam | Existing table anchor |
| Scales | Existing app sense | UI | `Scales` | Skalaer | Existing table anchor |
| Settings | Existing app sense | UI | `Settings` | Indstillinger | Existing table anchor |
| Slower | Existing app sense | UI | `Slower` | Langsommere | Existing table anchor |
| Solfège | Existing app sense | UI | `Solfège` | Solmisation | Existing table anchor |
| Speed trainer | Existing app sense | UI | `Speed trainer` | Tempotræner | Existing table anchor |
| Studio (lighter) | Existing app sense | UI | `Studio (lighter)` | Studio (lettere) | Existing table anchor |
| Tanpura | Existing app sense | UI | `Tanpura` | Tanpura | Existing table anchor |
| Temperament | Existing app sense | UI | `Temperament` | Temperatur | Existing table anchor |
| Tempo | Existing app sense | UI | `Tempo` | Tempo | Existing table anchor |
| Terms | Existing app sense | UI | `Terms` | Vilkår | Existing table anchor |
| Timbre | Existing app sense | UI | `Timbre` | Timbre | Existing table anchor |
| Timbre Pro | Existing app sense | UI | `Timbre Pro` | Timbre Pro | Existing table anchor |
| Today | Existing app sense | UI | `Today` | I dag | Existing table anchor |
| Tonic | Existing app sense | UI | `Tonic` | Grundtone | Existing table anchor |
| Tune | Existing app sense | UI | `Tune` | Stem | Existing table anchor |
| Tune up | Existing app sense | UI | `Tune up` | Stem instrumentet | Existing table anchor |
| Tuning | Existing app sense | UI | `Tuning` | Stemning | Existing table anchor |
| Ukulele | Existing app sense | UI | `Ukulele` | Ukulele | Existing table anchor |
| Violin | Existing app sense | UI | `Violin` | Violin | Existing table anchor |
| Yearly | Existing app sense | UI | `Yearly` | Årlig | Existing table anchor |
| best run | Existing app sense | UI | `best run` | rekord | Existing table anchor |
| minutes | Existing app sense | UI | `minutes` | minutter | Existing table anchor |
| Practice streak | Existing app sense | UI | `Practice streak` | Øvedage i træk | Existing table anchor |
| Achievements | Existing app sense | UI | `Achievements` | Præstationer | Existing table anchor |
| Ear trainer | Existing app sense | UI | `Ear trainer` | Gehørtræner | Existing table anchor |
| Intonation | Existing app sense | UI | `Intonation` | Intonation | Existing table anchor |
| Progress | Existing app sense | UI | `Progress` | Fremskridt | Existing table anchor |
| flat | Existing app sense | UI | `flat` | for lavt | Existing table anchor |
| sharp | Existing app sense | UI | `sharp` | for højt | Existing table anchor |
| Learn | Existing app sense | UI | `Learn` | Lær | Existing table anchor |
| Lesson | Existing app sense | UI | `Lesson` | Lektion | Existing table anchor |
| Next | Existing app sense | UI | `Next` | Næste | Existing table anchor |
| Play along | Existing app sense | UI | `Play along` | Spil med | Existing table anchor |
| XP | Existing app sense | UI | `XP` | XP | Existing table anchor |
| Streak freeze earned | Existing app sense | UI | `Streak freeze earned` | Rækkebeskyttelse optjent | Existing table anchor |
| Streak saved | Existing app sense | UI | `Streak saved` | Rækken er reddet | Existing table anchor |
| Precision | Existing app sense | UI | `Precision` | Præcision | Existing table anchor |
| Beginner | Existing app sense | UI | `Beginner` | Begynder | Existing table anchor |
| Standard | Existing app sense | UI | `Standard` | Standard | Existing table anchor |
| Fretted | Existing app sense | UI | `Fretted` | Nedtrykket | Existing table anchor |
| Saddle | Existing app sense | UI | `Saddle` | Sadel | Existing table anchor |
| Bullseye | Existing app sense | UI | `Bullseye` | Pletskud | Existing table anchor |
| Songbook | Existing app sense | UI | `Songbook` | Sangbog | Existing table anchor |
| Concert Pitch | Existing app sense | UI | `Concert Pitch` | Kammertone | Existing table anchor |
| A flat | Existing app sense | UI | `A flat` | As | Existing table anchor |
| A sharp | Existing app sense | UI | `A sharp` | Ais | Existing table anchor |
| Combo | Existing app sense | UI | `Combo` | Combo | Existing table anchor |
| D sharp | Existing app sense | UI | `D sharp` | Dis | Existing table anchor |
| E flat | Existing app sense | UI | `E flat` | Es | Existing table anchor |
| Key | Existing app sense | UI | `Key` | Toneart | Existing table anchor |

## 3. Course and song names
Use the instrument-name anchors for Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo. Songs equals the Songs tab. Ear Training/Rhythm reuse existing feature terminology; Music Theory/Singing and Originals/Standards & Classics are specified above. Songbook reuses the existing anchor. The localized lesson draft follows these same terms. Keep English song titles unless a firmly established local title exists; preserve traditional proper names and Timbre Originals titles. A title in prose must exactly match its lesson title. Lyric credits retain names and years, translating only connecting words; lyrics are not translated.

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

## Lesson draft decisions (2026-10-26; independent review pending)
- Source context delta: the frozen TODO still associates bare `Second`, `Third`, `Fourth` with finger questions. Publisher source has remapped finger uses to explicit finger keys. The bare keys are musical intervals and translate as `Sekund`, `Terts`, `Kvart`; TODO metadata is deliberately unchanged.
- Note letters remain English international B, not Danish H, as required by the lesson notation contract. Spelled sharp/flat use `med kryds` / `med b`; never introduce accidental symbols absent from the source.
- `Ode to Joy` is `Ode til glæden`. Other traditional and Original song titles are preserved unless a specific established Danish title is recorded here. Title modifiers and surrounding prose are translated.
- Guitar open-string mnemonic `Every Amateur Does Get Better Eventually` becomes `En And Danser Glad Bag Elefanten`, preserving E A D G B E.
- Lesson terminology: fretted note = grebet tone; finger = finger (ordinal spelled when English spells it); tab = tabulatur; quarter note = fjerdedelsnode; eighth note = ottendedelsnode; half note = halvnode; strumming = rytmisk akkordspil; folk strum = folk-rytmen; root = grundtone; progression = akkordfølge; hook = hook; down/up strums = nedslag/opslag.
- Standard Danish instrument/loanword labels and proper-name/title/notation strings can genuinely equal English; exact-source candidates are recorded separately for independent approval, never changed merely to defeat copied-English checks.

### Additional lesson terms and learning conventions
- In lesson prose, unit remains `del`; course `kursus`; lesson `lektion`. An entire strumming pattern is a `rytme` or `anslagsmønster`, not an individual anslag.
- Clefs: treble clef `G-nøgle`, bass clef `F-nøgle`; staff `nodesystem`, bar line `taktstreg`; slur `legatobue`, tie `bindebue`; dotted note `punkteret node`; triplet `triol`; sixteenth note `sekstendedelsnode`.
- Intervals: second `sekund`, third `terts`, fourth `kvart`, fifth `kvint`, sixth `sekst`, seventh `septim`, octave `oktav`; minor/major interval `lille/stor`, perfect `ren`, diminished `formindsket`, augmented `forstørret`. In chord quality, minor/major remains `mol/dur` instead. Tonic uses `grundtone` in beginner explanations and `tonika` in functional theory.
- Bow/instrument parts: bow `bue`, frog `frosch`, bow stick `stang`, tip `spids`, rosin `harpiks`, scroll `snekke`, fingerboard `gribebræt`, bridge `stol`, tailpiece `strengeholder`, fine tuner `finstemmer`, nut `oversadel`, saddle `sadel`. Cello endpin is drafted as `endepind`; native musician review should weigh the conventional alternative `stachel`.
- Bow directions `nedstrøg/opstrøg`, distinct from pick/strum `nedslag/opslag`. High/low numbered finger positions remain explicit finger placements, not high/low string pitch.
- Palm muting `håndkantsdæmpning`; walking bass `walkingbas`; chromatic approach `kromatisk ledetone`; pre-chorus `før-omkvæd`. Instrument bridge `stol` is distinct from song-form bridge `kontraststykke`.
- Established guitar/banjo technique loans are retained: hammer-on(s), pull-off(s), slides, crosspicking, clawhammer, rolls, pinch. Named banjo rhythmic vocables `Bum-ditty` / `Bum, dit, ty` remain phonetic teaching cues. These are proposed exact-source exceptions, not independent approvals.
- `maj-septimakkord` is used when major seventh is written out, avoiding introduction of a digit 7 not in the source. Chord symbols such as Cmaj7, Dm7 and B♭ are never respelled.
- Folk/country guitar uses `folk-rytmen`; the ukulele island strum is `ø-rytmen`. Loan genre words remain recognizable; e.g. blues, surf, punk, doo-wop, highlife and neosoul.
- W/H scale patterns stay literal W/H. Their legend explains W as `hel` and H as `halv`; the pattern is not converted into Danish initial letters.
- Triplet counting `1-trip-let, 2-trip-let` becomes `1-tri-ol, 2-tri-ol`, with any referred-to syllable `let` correspondingly `ol`. Rhythmic `and` becomes `og`; an offbeat location is explicitly `og efter to`, not the ordinary conjunction joining two beats.
- Bar/measure synonym question is adapted to avoid a circular Danish question: `What's another word for a bar?` → `Hvad betyder det engelske “bar”?`; choices Beat / Rest / Measure → `Slag` / `Pause` / `Takt`; explanation → `Bar og measure betyder begge takt.` Shared Slag and Pause retain their normal meanings everywhere else. Source keys/text and option ordering are unchanged.

### Mnemonic adaptations
Each mnemonic preserves the source's initial-letter sequence; these are localized teaching examples, not literal translations.
- Guitar E A D G B E: `En And Danser Glad Bag Elefanten`.
- Ukulele G C E A: `Glade Citroner Elsker Appelsiner`.
- Bass E A D G: `En And Danser Glad`.
- Violin/mandolin G D A E: `Glade Dyr Arbejder Energisk`.
- Cello C G D A: `Citroner Giver Dej Appetit`.
- Treble lines E G B D F: `En Glad Bjørn Danser Flot`.
- Bass lines G B D F A: `Glade Bjørne Danser For Altid`.
- Bass spaces A C E G: `Alle Cykler Er Grønne`.
- Treble-space FACE remains FACE as the literal F A C E letter sequence. Individual quiz references to mnemonic words follow the adapted sentence.

### Localized established song/work titles
The named title in prose follows the title mapping; original sung words remain in their original language even when the work title is Danish. Short lyric fragments tested in a quiz are not translated as ordinary English nouns.

| English source title/work | Danish draft title |
|---|---|
| Ode to Joy | Ode til glæden |
| Twinkle, Twinkle, Little Star / Twinkle Twinkle Little Star | Blinke, blinke stjernelille |
| Frère Jacques | Mester Jakob |
| Jingle Bells | Bjældeklang |
| Old MacDonald Had a Farm | Jens Hansens bondegård |
| Brahms' Lullaby | Brahms' vuggevise |
| Minuet in G | Menuet i G |
| The Swan | Svanen |
| The Carnival of the Animals | Dyrenes karneval |
| Canon in D | Kanon i D |
| Largo, New World Symphony | Largo, Fra den nye verden |
| In the Hall of the Mountain King | I Dovregubbens hal |
| Silent Night | Glade jul |
| Mozart's Symphony No.40 | Mozarts symfoni nr.40 |
| The Merry Wives of Windsor | De lystige koner i Windsor |
| Messiah | Messias |
| O Christmas Tree | O juletræ |
| The Blue Danube | Den blå Donau |
| Can-can | Cancan |
| Orpheus in the Underworld | Orfeus i underverdenen |
| Carmen: Prelude | Carmen: forspil |
| The Toreador Song / Toreador Song | Toreadorsangen / Toreadorsang |
| Morning Mood | Morgenstemning |
| Holy, Holy, Holy | Hellig, hellig, hellig |
| Abide with Me | Bliv hos mig |
| Nearer, My God, to Thee | Nærmere Gud til dig |
| The Last Rose of Summer | Sommerens sidste rose |
| The Planets | Planeterne |
| Spring | Foråret |
| The Four Seasons | De fire årstider |

- Other traditional, hymn and classical titles retain the identifying source title in this draft, including Mary Had a Little Lamb, Row, Row, Row Your Boat, Amazing Grace, Auld Lang Syne, Greensleeves, Lightly Row, Aura Lee, Für Elise, Eine kleine Nachtmusik, Rondo alla Turca and Jupiter. Timbre Originals retain their proper titles. Each exact-source title is individually listed as an invariant candidate for independent review.
- The nursery-song references `the alphabet song` and `Baa, Baa, Black Sheep` become `alfabetsangen` and `Mæ, mæ, lam` in prose. Composer Handel is Danish `Händel` in prose; attribution credits preserve source names and dates.
- `Fly`, `Wide`, `Boat`, `Town` and `Bethlehem` in lyric-recognition questions stay the sung English words. They are not untranslated navigation or ordinary vocabulary. Likewise the all-lyric-and-note exercise `Ma-ry had a lit-tle lamb: E D C D E E E.` retains its complete literal content.
