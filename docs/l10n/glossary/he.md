# Hebrew glossary

Status: AI-drafted and AI-reviewed, 2026-10-25. Native-human sign-off and device verification pending. Shipped labels inspected; explicit decisions below override conflicting anchors.

## 1. Locale decisions

| Decision | Value |
|---|---|
| Locale code and language | he — Hebrew |
| Variant | Standard national language; shared regional table |
| Register (you) | Plural address אתם with plural imperatives; gender-neutral labels; overrides mixed shipped singular/plural register |
| Imperatives and buttons | Short action labels; instructions in the chosen register; spoken hints state the action |
| Readers of unknown gender | Gender-neutral wording; no agreement with unknown argument values |
| Quotation marks | “…” |
| Apostrophe and ellipsis | Single …; conventional apostrophe |
| Spaces | Ordinary single spaces |
| Digits in literal numbers | ASCII 0–9 |
| Units | Hz, BPM, ¢, XP unchanged; סנטים; דקות/דק׳; שניות/שנ׳; מ״ש |
| Capitalization | Sentence case |
| Note names in interface | Runtime placeholders only |
| Note names in lessons | Keep C, F♯, B♭, Em, G7 unchanged |
| Accidentals as words | דיאז / במול / דיאז כפול / במול כפול |
| Tuning direction | נמוך / גבוה |
| iOS Settings path | הגדרות › חשבון Apple › מינויים |
| Apple feature names | מסך הבית; מסך הנעילה; וידג׳ט; פעילויות בזמן אמת; קיצורים; מרכז הבקרה; שיתוף משפחתי. Apple Watch, Siri, Game Center unchanged. |
| Siri phrases | Natural spoken command; retain every ${…} token. הבא / שוב / לאט יותר |

## 2. Terms

| English | Meaning in Timbre | Where | App key | Translation | Notes |
|---|---|---|---|---|---|
| Timbre | The app; also its home-screen name (InfoPlist `CFBundleDisplayName`) | everywhere | `Timbre` | Timbre | Never translate brands or attach endings. |
| Timbre Pro | The subscription (yearly, monthly, lifetime) | paywall, settings, locks | `Timbre Pro` | Timbre Pro | Never translate brands or attach endings. |
| Pro | Short for Timbre Pro, never "professional" | badges, "Try Pro free for %@" |  | Pro | Never translate brands or attach endings. |
| Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri | Apple's products | permission prompts, paywall, Your songs |  | Unchanged | Never translate brands or attach endings. |
| ChordPro | A chord-chart file format | Your songs import help |  | ChordPro | Never translate brands or attach endings. |
| XP, BPM, Hz, ¢, A4 | Experience points; beats per minute; hertz; cents sign; the reference A | tuner, metronome, progress | `XP`, `Hz`, `A4` | Unchanged | Never translate brands or attach endings. |
| Instrument names (60, from guitar to oud, erhu, sitar, tanpura) | The catalogue | tuner, instrument browser, lessons |  | שמות הקטלוג timbre_catalog_*: גיטרה, עוד, ארהו, סיטאר, טנפורה | Use this sense; inflect words naturally, never placeholders. |
| Tuning names (Standard, Drop D, Open G, DADGAD) | Preset tunings | tuner, lessons | `Standard` | כיוון רגיל / Drop D / G פתוח / DADGAD | Use this sense; inflect words naturally, never placeholders. |
| Tune (tab) | The tuner tab; also the verb "to tune" | tab bar; UI 63, lessons 218 (mostly the verb) | `Tune` | כיוון | Use this sense; inflect words naturally, never placeholders. |
| Learn (tab) | Courses and lessons | tab bar | `Learn` | לימוד | Use this sense; inflect words naturally, never placeholders. |
| Songs (tab) | The song shelf; the tab shows the Songs course's own title from `Learn.strings` | tab bar, Songs screen | `Songs` | שירים | Use this sense; inflect words naturally, never placeholders. |
| Practice (tab) | Metronome, drone, chords, scales, ear games | tab bar | `Practice` | תרגול | Use this sense; inflect words naturally, never placeholders. |
| Progress (tab) | Stats, string health, badges (the Journey screen) | tab bar | `Progress` | התקדמות | Use this sense; inflect words naturally, never placeholders. |
| Settings | The in-app settings, and the iOS Settings app in legal text | Settings, paywall footer | `Settings` | הגדרות | Use this sense; inflect words naturally, never placeholders. |
| Today | The daily set of three activities ("Your Today plan") | Tune, Practice, widgets | `Today` | היום | Use this sense; inflect words naturally, never placeholders. |
| Quest | A side goal next to Today ("Quest · tune every string") | Tune, Practice |  | משימה | Use this sense; inflect words naturally, never placeholders. |
| Your songs | The player's own chord charts (imported or pasted) | Your songs screen | `Your songs` | השירים שלכם | Use this sense; inflect words naturally, never placeholders. |
| Song sheet | A song lesson's chord-and-words page | lessons |  | דף אקורדים ומילים | Use this sense; inflect words naturally, never placeholders. |
| Chart / Player view | The two ways a chord card shows: a chord chart, or the 3D player's hand | chord cards, Settings | `Chart`, `Player view` | תרשים / מבט הנגן | Use this sense; inflect words naturally, never placeholders. |
| Chord view / Neck view | What VoiceOver calls the Show me switch | VoiceOver | `Chord view`, `Neck view` | תצוגת אקורד / תצוגת צוואר | Use this sense; inflect words naturally, never placeholders. |
| Show me | The 3D demonstration of a chord or notes on the neck | lessons | `Show me` | הדגמה | Use this sense; inflect words naturally, never placeholders. |
| Strum to tune | One strum reads every string at once | tuner, listing | `Strum to tune` | פרטו לכיוון | Use this sense; inflect words naturally, never placeholders. |
| Tune by feel / Feel | The phone pulses with the beat between the string and its note, slower as they meet, still at the lock | tuner, settings | `Tune by feel`, `Feel` | כיוון לפי רטט / רטט | Use this sense; inflect words naturally, never placeholders. |
| Bullseye | The pitch game (hit the centre ring); also leaderboard names | Practice, Game Center | `Bullseye` | בול | Use this sense; inflect words naturally, never placeholders. |
| Ear trainer / Ear training | The ear games and the ear course | Practice, Learn | `Ear training` | פיתוח שמיעה | Use this sense; inflect words naturally, never placeholders. |
| Drone | A sustained reference tone to play or sing against | Practice, lessons | `Drone` | בורדון | Use this sense; inflect words naturally, never placeholders. |
| Tanpura drone | The drone voiced as an Indian tanpura | Practice, paywall | `Tanpura` | טנפורה | Use this sense; inflect words naturally, never placeholders. |
| Intonation | The Practice tool for playing or singing in tune over a drone ("Intonation over a drone") | Practice, paywall | `Intonation` | אינטונציה | Use this sense; inflect words naturally, never placeholders. |
| Metronome, Speed trainer | The metronome, and its mode that raises the tempo every few bars | Practice, Watch | `Metronome`, `Speed trainer` | מטרונום / מאמן מהירות | Use this sense; inflect words naturally, never placeholders. |
| Chords, Scales | The chord library and the scales across the neck | Practice | `Chords`, `Scales` | אקורדים / סולמות | Use this sense; inflect words naturally, never placeholders. |
| Placement check | A 45-second check in onboarding that picks the first lesson | onboarding | `Placement check` | בדיקת רמה | Use this sense; inflect words naturally, never placeholders. |
| Play along | Playing with the note highway or the band | lessons, songs | `Play along` | נגינה יחד | Use this sense; inflect words naturally, never placeholders. |
| Take | One recorded attempt at a song ("Final take", "Best take 92%") | songs, results | `Final take` | ביצוע | Use this sense; inflect words naturally, never placeholders. |
| Loop A–B, Set A, Set B | Loop points of a passage | songs |  | לולאה A–B / הגדרת A / הגדרת B | Use this sense; inflect words naturally, never placeholders. |
| Precision: Beginner, Standard, Expert | How wide the tuner's in-tune band is | Settings | `Expert` | מתחילים / רגיל / מומחה | Use this sense; inflect words naturally, never placeholders. |
| Studio (lighter) / Real-time 3D | The two ways the instrument stage renders | Settings |  | אולפן (קל יותר) / תלת-ממד בזמן אמת | Use this sense; inflect words naturally, never placeholders. |
| Haptics | Vibration feedback | Settings | `Haptics` | רטט | Use this sense; inflect words naturally, never placeholders. |
| tuner | The tuning screen and the device it imitates | UI 13, listing |  | מכוון | Use this sense; inflect words naturally, never placeholders. |
| tune (verb), tune up | Bring a string to its pitch | UI, lessons | `Tune up` | לכוון | Use this sense; inflect words naturally, never placeholders. |
| tuning | A preset set of string pitches ("132 tunings") | tuner, listing | `Tuning` | כיוון | Use this sense; inflect words naturally, never placeholders. |
| In tune | The string is at its pitch (the lock) | tuner, VoiceOver, lessons 26 | `In tune` | מכוון | Use this sense; inflect words naturally, never placeholders. |
| flat / sharp (direction) | The reading is too low / too high | tuner, Progress ("drifts flat") | `flat`, `sharp` | נמוך מדי / גבוה מדי | Use this sense; inflect words naturally, never placeholders. |
| cents (¢) | Hundredths of a semitone | tuner, VoiceOver, lessons | `Cents` | סנטים | Use this sense; inflect words naturally, never placeholders. |
| lock, locks | The moment a string is held in tune and the tuner confirms it | tuner, listing |  | אישור כיוון מדויק | Use this sense; inflect words naturally, never placeholders. |
| string | A string of the instrument; numbered 1 (thinnest, highest) to N | UI 69, lessons 807 |  | מיתר | Use this sense; inflect words naturally, never placeholders. |
| peg, headstock | The tuning peg the 3D stage highlights; the head of the neck | tuner |  | מפתח כיוון / ראש הצוואר | Use this sense; inflect words naturally, never placeholders. |
| reference tone / reference pitch / Concert Pitch | The tone the app plays; A4's frequency (440 Hz); sounding pitch of a transposing instrument | tuner, Settings | `Concert Pitch` | צליל ייחוס / גובה ייחוס / כיוון קונצרט | Use this sense; inflect words naturally, never placeholders. |
| written pitch, temperament | Transposing instruments' notation; equal or other temperaments | Settings | `Temperament` | גובה כתוב / טמפרמנט | Use this sense; inflect words naturally, never placeholders. |
| chromatic / strobe | The free-note tuner mode; the strobe display | tuner, listing | `Chromatic` | כרומטי / סטרובוסקופי | Use this sense; inflect words naturally, never placeholders. |
| capo | The clamp across the frets ("Capo on fret %lld") | tuner, lessons 20 | `Capo` | קאפו | Use this sense; inflect words naturally, never placeholders. |
| transpose / transposition | Shift a chart to another key | Your songs | `Transpose` | טרנספוזיציה | Use this sense; inflect words naturally, never placeholders. |
| Note names | Settings › Note names (letters, German, solfège, sargam, numbers) | Settings | `Note names`, `Solfège`, `Sargam` | שמות תווים / סולפז׳ / סרגאם | Use this sense; inflect words naturally, never placeholders. |
| fret, open string | A fret of the neck; a string played without fretting | lessons 562, 79 |  | סריג / מיתר פתוח | Use this sense; inflect words naturally, never placeholders. |
| finger 1–4 | 1 index, 2 middle, 3 ring, 4 little; 0 open | lessons |  | אצבע 1–4; מורה, אמה, קמיצה, זרת | Use this sense; inflect words naturally, never placeholders. |
| chord, chord shape, barre (chord) |  | UI 31, lessons 324, 56 | `Chords` | אקורד / צורת אקורד / בארה | Use this sense; inflect words naturally, never placeholders. |
| major, minor, seventh, power chord | Chord qualities ("E minor", "G7") | lessons |  | מז׳ור / מינור / אקורד ספטימה / פאוור אקורד | Use this sense; inflect words naturally, never placeholders. |
| key | Tonality ("in the key of G"); not a piano key | UI 7, lessons 127 | `Key` | סולם | Use this sense; inflect words naturally, never placeholders. |
| scale, major scale, pentatonic box |  | lessons 126 | `Scales` | סולם / סולם מז׳ורי / תבנית פנטטונית | Use this sense; inflect words naturally, never placeholders. |
| half step, whole step, interval, third, fifth, octave |  | lessons | `Octave` | חצי טון / טון שלם / מרווח / טרצה / קווינטה / אוקטבה | Use this sense; inflect words naturally, never placeholders. |
| bar | A measure (bar 2 of the song); not a UI bar | UI 7, lessons 167 | `Bar %lld` | תיבה | Use this sense; inflect words naturally, never placeholders. |
| beat, tempo, downbeat, count |  | UI 29, lessons 251 | `Tempo` | פעמה / טמפו / פעמה חזקה / ספירה | Use this sense; inflect words naturally, never placeholders. |
| strum, downstroke, upstroke, chop, chunk, mute | Strumming and muted strokes | UI 21, lessons 120 | `Strum` | פריטה / פריטה למטה / פריטה למעלה / פריטה עמומה / השתקה | Use this sense; inflect words naturally, never placeholders. |
| pick | A plectrum, or picking strings; in UI often "choose" | UI 8, lessons 77 |  | מפרט; פריטה; בחירה (UI) | Use this sense; inflect words naturally, never placeholders. |
| fingerpicking, hammer-on, pull-off, slide, bend, vibrato | Techniques | lessons |  | נגינה באצבעות / האמר-און / פול-אוף / סלייד / בנד / ויברטו | Use this sense; inflect words naturally, never placeholders. |
| bowing, open-string bowing | Violin and cello | lessons |  | נגינה בקשת / נגינה בקשת על מיתרים פתוחים | Use this sense; inflect words naturally, never placeholders. |
| tune (noun) | A melody ("an old fiddle tune") | lessons |  | מנגינה | Use this sense; inflect words naturally, never placeholders. |
| cadence, V chord, I–IV–V | Harmony | lessons |  | קדנצה / אקורד V / I–IV–V | Use this sense; inflect words naturally, never placeholders. |
| pickup | Notes before the first full bar (anacrusis) | lessons |  | קדמה | Use this sense; inflect words naturally, never placeholders. |
| Intro, Verse 1, Chorus, Bridge, Solo, Outro, Tag | Section labels on small chips | lessons 14, 60, 57, 32, 16, 1 | `Verse`, `Chorus`, `Bridge` | פתיחה / בית 1 / פזמון / גשר / סולו / סיום / תוספת | Use this sense; inflect words naturally, never placeholders. |
| section | A part of a song | lessons 9 |  | קטע | Use this sense; inflect words naturally, never placeholders. |
| streak | Consecutive days with practice | UI 21 |  | רצף | Use this sense; inflect words naturally, never placeholders. |
| streak freeze | Saves the streak on a missed day | UI |  | הקפאת רצף | Use this sense; inflect words naturally, never placeholders. |
| best run | The longest streak so far | Progress | `best run` | הרצף הטוב ביותר | Use this sense; inflect words naturally, never placeholders. |
| badge / achievement | Rewards in the app; Game Center calls them achievements | Progress, Game Center | `Next badge` | תג / הישג | Use this sense; inflect words naturally, never placeholders. |
| level, stars, XP, combo, score, round | Game and lesson rewards | UI | `Combo` | רמה / כוכבים / XP / קומבו / ניקוד / סיבוב | Use this sense; inflect words naturally, never placeholders. |
| challenge (a friend) | A Game Center challenge | Practice | `Challenge a friend` | אתגר לחבר | Use this sense; inflect words naturally, never placeholders. |
| challenge (lesson) | The last lesson of each unit, mixing what it taught | Learn, lessons 68 | `Challenge` | אתגר | Use this sense; inflect words naturally, never placeholders. |
| course, unit, lesson, step | The curriculum's levels (course › unit › lesson › step) | Learn | `Lesson`, `Unit` | קורס / יחידה / שיעור / שלב | Use this sense; inflect words naturally, never placeholders. |
| quiz, hint | Question steps and the line under an exercise | lessons | `Quiz` | חידון / רמז | Use this sense; inflect words naturally, never placeholders. |
| subscription, renew, cancel | The auto-renewing plan | paywall (legal) |  | מינוי / חידוש / ביטול | Use this sense; inflect words naturally, never placeholders. |
| free trial, trial ends | The introductory offer | paywall (legal) | `Free trial` | תקופת ניסיון בחינם / תקופת הניסיון מסתיימת | Use this sense; inflect words naturally, never placeholders. |
| yearly, monthly, lifetime | Plans | paywall | `Yearly`, `Monthly`, `Lifetime` | שנתי / חודשי / לכל החיים | Use this sense; inflect words naturally, never placeholders. |
| Restore purchases | Restore on this Apple Account | paywall, settings | `Restore purchases` | שחזור רכישות | Use this sense; inflect words naturally, never placeholders. |
| payment method, billing issue | Failed renewal banner | all tabs (legal) |  | אמצעי תשלום / בעיית תשלום | Use this sense; inflect words naturally, never placeholders. |
| Terms, Privacy Policy | Links in the paywall footer | paywall (legal) | `Terms` | תנאים / מדיניות פרטיות | Use this sense; inflect words naturally, never placeholders. |

## 3. Course and song names

| English | Translation |
|---|---|
| Guitar, Ukulele, Bass, Violin, Cello, Mandolin, Banjo | גיטרה, יוקולילי, בס, כינור, צ׳לו, מנדולינה, בנג׳ו |
| Ear Training, Music Theory, Rhythm, Singing | פיתוח שמיעה, תאוריה מוזיקלית, קצב, שירה |
| Songs | שירים |
| Originals | שירים מקוריים |
| Standards & Classics | סטנדרטים וקלאסיקות |
| Instrument Songbook | ספר שירים לכלי המתאים |

- Established public-domain titles: use established local titles.
- Other traditional songs: retain English unless a shipped localized lesson title already exists.
- Timbre Originals: translate consistently with existing localized lesson titles; never translate sung lyrics.
- A title in prose must exactly match its lesson title and leaderboard. Credits retain names and digit groups; translate connecting words.

## 4. Words that mislead

| English | Translation and distinction |
|---|---|
| Tune | לכוון; מנגינה as noun |
| sharp / flat | דיאז / במול; גבוה מדי / נמוך מדי for tuning |
| bar | תיבה, not pub |
| key | סולם, not a physical key |
| pick | מפרט / פריטה; בחירה in UI |
| lock | אישור כיוון מדויק, not padlock |
| take | ביצוע |
| run | רצף / נגינת קטע |
| chart | תרשים אקורדים |
| Intonation | אינטונציה, pitch accuracy not saddle adjustment |
| Next, Again, Slower | הבא / שוב / לאט יותר |
| Practice | תרגול |
| Feel | רטט, not emotion |

## RTL handling
Start with Hebrew words, including brand-led sentences (האפליקציה Timbre). Dynamic Latin note/chord values beside punctuation use U+2068 and U+2069; annotate these in answer notes. Never attach Hebrew prefixes/suffixes directly to placeholders. Literal numbers remain ASCII. Instrument diagrams remain left-to-right in code; do not reverse their text or markers.

## 2026-10-26 lesson-author decisions (unreviewed author draft)

Author: `/root/translate_hebrew_lessons` (GPT language author; not native-human or independent review).
The lesson drafting baseline is 6,083 current English keys. Existing glossary/UI review claims above do not constitute review of these new lessons.

- Maintain plural imperatives. Bare numeric answers use Hebrew standalone numeral forms (אחת, שתיים, שלוש, ארבע, etc.) so they do not commit to the varying counted noun in shared quiz contexts.
- Independently reviewed shared musical-item ordinals: “The first” / “The second” / “The third” / “The last” use הראשון / השני / השלישי / האחרון. Actual note, chord, string, pair and phrase antecedents were checked as masculine. Do not add “option”: in the phrase quiz, The first is displayed as the second answer button. Explicit finger ordinals remain feminine.
- Up / Down: למעלה / למטה, neutral direction for both pitch and picking, not past-tense verbs.
- Bare Second / Third / Fourth: סקונדה / טרצה / קוורטה (intervals only); explicit finger keys use האצבע השנייה / השלישית / הרביעית. “First” is הראשונה because its verified contexts are fingers.
- Instrument bridge: גשר הכלי; song “The bridge”: קטע הגשר; short song-section Bridge: גשר.
- Root: צליל יסוד; third: טרצה; fifth: קווינטה; triad: אקורד משולש; inversion: היפוך; root position: מצב יסודי; common tone: צליל משותף.
- Major seventh chord: אקורד מז׳ור ספטימה; minor seventh chord: אקורד מינור ספטימה; dominant seventh: אקורד ספטימה דומיננטית. Interval major/minor seventh: ספטימה גדולה / קטנה.
- Position: פוזיציה; shape: צורה; pentatonic box: תבנית פנטטונית (תבנית when established); mode: מודוס; Dorian: דורי; Mixolydian: מיקסולידי.
- Rhythm: פעמה; quarter/half note: תו רבע / תו חצי; sixteenth note: תו חלקי שש־עשרה; anacrusis/pickup: קדמה; strumming: פריטה; fingerpicking: נגינה באצבעות; arpeggio: ארפג׳ו; syncopation: סינקופה.
- Techniques: האמר־און / פול־אוף / סלייד / בנד / ויברטו / טריל; riff: ריף; lick: ליק; hook: הקטע הקליט; palm muting: השתקה בכף היד. Hebrew maqaf U+05BE joins natural Hebrew prefix constructions and transliterated compounds; this is a visible orthographic hyphen, not an invisible bidi control.
- Turnaround: הסיום שמחזיר להתחלה (or ליק שמחזיר להתחלה); tag: תוספת סיום; fill: קישוט; texture: מרקם; comping: ליווי; Travis picking: פריטת טראוויס.
- In a rhythmic spoken count, English “and” becomes ו. Sixteenth counting keeps phonetic syllables: אחת־אִי־ו־אָה. These are pedagogical counting syllables, not translated solfège note names.
- The mnemonic “Every Amateur Does Get Better Eventually” remains in English with Hebrew explanation that its initials give the note order; changing initials would break the mnemonic. Pure note names/notation remain original and are held for independent invariant review, never padded to bypass identity checks.

### Song naming decisions already used in guitar lessons

| English | Hebrew |
|---|---|
| Mary Had a Little Lamb | למרי הייתה כבשה קטנה |
| Ode to Joy | אודה לשמחה |
| Letters in a Shoebox | מכתבים בקופסת נעליים |
| Dust on the Dashboard | אבק על לוח המחוונים |
| Low Tide Radio | רדיו בשפל |
| Kite Weather | מזג אוויר לעפיפונים |
| Halogen | הלוגן |
| Ghost Light | אור רפאים |
| Rust Belt Shuffle | שאפל חגורת החלודה |
| Basement Weather | מזג אוויר במרתף |
| Glass Satellites | לווייני זכוכית |
| Porchlight | אור במרפסת |
| Neon Laundromat | מכבסת ניאון |
| Saltwater Sunday | יום ראשון במים מלוחים |
| Spray Paint Sunrise | זריחה בספריי צבע |
| Sparkler Season | עונת זיקוקי היד |
| Gravel Road Two-Step | טו־סטפ בדרך חצץ |
| Lantern Hill | גבעת הפנסים |
| Roller Rink | זירת הגלגיליות |
| Late Checkout | עזיבה מאוחרת |
| Market Day | יום השוק |
| Slow Motion Strobe | סטרוב בהילוך איטי |
| Jukebox Moon | ירח הג׳וקבוקס |

Other traditional works are retained under their original title unless a clear established Hebrew title is selected and recorded. Credits retain original Latin names and original digit groups; connecting words translate. Lyrics are not translated.

### Direction controls and verification status

- Mixed Hebrew/Latin strings use balanced U+2068 FIRST STRONG ISOLATE and U+2069 POP DIRECTIONAL ISOLATE for Latin note/chord/name runs beside punctuation or digits. Each authored output row explicitly records added controls in its note.
- U+200F RIGHT-TO-LEFT MARK establishes Hebrew paragraph direction only where a musical label must begin with a Latin name, e.g. A מינור. Each such row is annotated.
- Pure Latin notation/title candidates remain byte-identical; no controls are added to manufacture a translation. These are held empty in canonical TODO until genuinely independent review.
- No device, native-speaker, or VoiceOver layout verification has occurred. Latin-heavy labels, mnemonic passages, credits, isolating punctuation and mixed Hebrew/Latin prefixes need RTL/device review.

## Lesson continuation decisions — Ukulele, Bass, Violin, Cello

- New source `Major and minor intervals` (L418aadaeed): מרווחים גדולים וקטנים. Hebrew interval quality uses גדול/קטן, not chord-quality מז׳ור/מינור. The separate source-bound addendum is authoritative for this new title; the original `Major and minor everywhere` now refers only to chords.
- Current publisher retirement: `Tremolo until the next beat` (L4d1c8b1ea7) is obsolete; its former occurrence uses existing `Tremolo through long notes` (Le56240b1d1). Keep historical batch inputs; exclude the obsolete key from the final current map.
- Twinkle, Twinkle, Little Star: נצנץ כוכב קטן; Minuet in G: מינואט בסולם G; Brahms' Lullaby: שיר הערש של ברהמס; The Swan: הברבור; The Carnival of the Animals: קרנבל החיות.
- Re-entrant tuning: כיוון חוזר, explained by the high G. Course (paired mandolin strings) is קבוצת מיתרים, not the curriculum קורס; exercises generally say זוג, matching source pair.
- Bass: בס; walking bass: בס מהלך; approach note: צליל גישה; chromatic approach notes: צלילי גישה כרומטיים; root/fifth/octave: צליל יסוד / קווינטה / אוקטבה; sixth: סקסטה. Pickup on an electric instrument is פיקאפ, distinct from musical anacrusis קדמה.
- Bow: קשת; frog: עקב הקשת; tip: חוד הקשת; stick: מוט; hair: שיער; rosin: שרף; tailpiece: מחזיק המיתרים (descriptive beginner wording); fine tuner: בורג כיוון עדין; scroll: שבלול; chin rest: משענת סנטר; endpin: רגלית. These local instrument terms still need independent/native review.
- Down-bow / up-bow: קשת למטה / קשת למעלה, with explicit source directions retained. Slur: קשת חיבור; slurred pairs: זוגות מחוברים / זוגות בקשת אחת. A tie is distinct: קשת הארכה when encountered later.
- High 2 / Low 2: אצבע 2 גבוהה / אצבע 2 נמוכה, or במיקום גבוה / במיקום נמוך in isolated headings. Preserve every occurrence of the digit 2. Natural notes: C טבעי etc.; do not change letter notation to solfège.
- Shift: החלפת פוזיציה; first/fourth position: פוזיציה ראשונה / רביעית. Forte/piano: פורטה / פיאנו; crescendo/diminuendo: קרשנדו / דימינואנדו. Keep source f/p notation where present.
- Explicit century clarification: source `1700s` becomes `המאה שהחלה בשנת 1700`, retaining 1700 once and clearly expressing the century rather than a decade. Source `18th century` remains `המאה ה־18`.
- Instrument posture clarification: violin `about level with the floor` means בערך במקביל לרצפה, never at floor height.
- Source D/DU/UDU strumming patterns, Roman-numeral harmony patterns, and p-i-m-a finger symbols remain original notation. Whole-string cases are proposed invariant candidates, not translations or automatic approvals. Whole-string notation reason must describe the actual notation type, not confuse strumming D/U with pitch letters.
- Lyrics quoted as short cues inside lesson instructions remain in their original language, with Hebrew framing; sung lyrics themselves are never translated.

## Lesson continuation decisions — Mandolin, Banjo, Ear Training, Theory, Rhythm, Singing

- Mandolin crosspicking: פריטה מוצלבת; chop: פריטה קצוצה; bluegrass: בלוגראס; old-time: אולד־טיים. Tremolo: טרמולו. Pair: זוג. The retired historical next-beat tremolo remains marked historical only, and its current replacement means tremolo for the full duration of long notes.
- Banjo: בנג׳ו; drone: בורדון, introduced as a fixed recurring open note; roll: רול; alternating thumb roll: רול אגודל מתחלף; forward roll: רול קדימה; pinch: פינץ׳, explained as thumb and middle playing together; clawhammer: קלאוהאמר; bum-ditty: באם־דיטי, counted באם, די, טי; banjo head: עור התוף של הבנג׳ו. These transliterations and beginner instrument terms need native/domain review.
- Ear Training: פיתוח שמיעה; unison: אוניסון; audiation: אודיאציה / שמיעה פנימית; half/whole step: חצי טון / טון שלם; step/skip: צעד / דילוג; second/third/sixth/seventh/ninth: סקונדה / טרצה / סקסטה / ספטימה / נונה; perfect: זך (agree in gender); interval major/minor: גדול/קטן, never מז׳ור/מינור.
- Scale degrees use conventional Hebrew solfège syllables דו, רה, מי, פה, סול, לה, סי. English movable-do `ti` is localized to conventional Hebrew סי; the relative function is unchanged, and explicit A–G note letters remain untouched. This is different from translating literal note-letter notation, which is not done.
- Frère Jacques: אחינו יעקב; Für Elise: לאליזה. Other new full traditional-title cases remain original-title candidates unless a recorded Hebrew title exists.
- Staff: חמשה; treble/G clef: מפתח סול / מפתח G; bass/F clef: מפתח פה / מפתח F; ledger line: קו עזר; enharmonic: אנהרמוני; tonic: טוניקה; key signature: סימני סולם; time signature: סימן משקל; rhythm: מקצב; tempo: מפעם; bpm: פעימות בדקה, retaining bpm where teaching the acronym.
- English mnemonic sentences retain their original initials, with Hebrew explanation in surrounding prose. Whole-string Every Good Boy Does Fine and Good Boys Do Fine Always are held candidates because translation would break the E-G-B-D-F / G-B-D-F-A mnemonic, not because they are titles. FACE is explained as the letters F-A-C-E, not translated as פנים.
- The bar/measure synonym quiz is explicitly adapted: both English words naturally translate to תיבה, so the question asks the meaning of English bar and the explanation identifies bar and measure as synonyms. This preserves the correct answer and musical concept instead of asking a tautological Hebrew synonym question. See `manual-context-adaptations.json` for exact hashes.
- Progression: מהלך אקורדים; authentic/plagal/deceptive cadence: קדנצה אותנטית / פלגלית / מדומה; half cadence: חצי קדנצה. Roman numeral case, separators and ° stay intact.
- Tie: קשת הארכה, distinct from slur קשת חיבור. Triplet: טריולה; the three-place spoken count is 1־טרי־לה, keeping source digits and three positions. Source `let` is correspondingly לה when naming the last position; this is localized counting, not lyric translation.
- Swing: סווינג; ride pattern: תבנית הרייד; ride cymbal: מצילת הרייד; offbeat: אוף־ביט; backbeat: בקביט, explicitly taught on beats 2 and 4. Count strings use Hebrew ו for English and; RTL chronological display of numeric counting strings needs device review.
- Singing flat/sharp (off-target pitch): נמוך מדי / גבוה מדי, not the accidental names במול / דיאז. Pitch matching: התאמת גובה הצליל; lip trill: רטט שפתיים; ah/da: אָה / דָּה. Phrase open vowel uses תנועה פתוחה. Lyrics remain in the original language; Hebrew framing explains a lyric cue.
- U+200F may also establish RTL direction for digit-led translated labels/counting strings, not only Latin-led musical names. It never changes a pure invariant string. Output row notes generated earlier call this a musical-name case generically; exact controls are counted in author QA and need layout/VoiceOver review.

## Final author decisions — Songs, Originals and Songbooks

- Sus chord: אקורד מושהה, matching the early guitar lessons. Power chord: פאוור אקורד (plural פאוור אקורדים). Funk stays פאנק; punk uses פאנק־רוק to distinguish it; punk-pop is פופ־פאנק. Vamp: ואמפ; skank: סקאנק; highlife: היילייף; neo-soul: ניאו־סול; doo-wop: דו־וופ; surf: סרף; lo-fi: לו־פיי; synth-pop: סינת׳־פופ. Native genre-label review remains pending.
- A dynamic swell is expressed as הגברה והחלשה / התגברות ודעיכה, not literal bodily inflation. Half-time is described as a feeling of half speed, not an actual tempo instruction. A slow burner is שיר שנבנה לאט.
- Song form: verse בית; chorus פזמון; refrain פזמון חוזר; pre-chorus קדם־פזמון; bridge גשר / קטע הגשר, distinct from גשר הכלי. Round/canon קאנון; melodic sequence סקוונצה; melisma מליסמה; ground bass גראונד introduced as a repeating bass.
- Traditional/classical title choices added: Old MacDonald Had a Farm → לדוד משה הייתה חווה; Canon in D → קאנון בסולם D (the source letter D is preserved); Largo, New World Symphony → לרגו, סימפוניית העולם החדש; In the Hall of the Mountain King → בהיכל מלך ההר; Silent Night → לילה שקט; Eine kleine Nachtmusik → מוזיקת לילה זעירה; The Blue Danube → הדנובה הכחולה; Can-can → קאן־קאן; The Liberty Bell → פעמון החירות; Carmen: Prelude → כרמן: פרלוד; Morning Mood → אווירת בוקר; Jupiter → יופיטר; The Planets → כוכבי הלכת; Spring → האביב; The Four Seasons → ארבע העונות; Rondo alla Turca → הרונדו הטורקי; The Stars and Stripes Forever → כוכבים ופסים לנצח. These are author naming decisions, not a claim of verified native acceptance.
- Existing source `1800s` is also rendered explicitly as the century beginning in 1800; `early 1800s` as the beginning of that century. Actual decades such as 1580s, 1840s, 1890s and 1950s remain decades with the original digit groups.
- Whole-string lyric-identification answers Fly, Wide, Boat, Town and Bethlehem are retained as sung English words, NOT translated lexical vocabulary or song titles. Full-string candidate reasons identify this function. Song/tune title-plus-year answer choices retain names, punctuation and year; no independent approval is implied.
- The song title Over You Soon is authored as בקרוב אתגבר עליך. The English addressee is ungendered; the Hebrew conventional unpointed singular wording merits native review for preferred title treatment. It is not an instruction addressing the learner.
- Source-bound title inventories and all final current shared contexts are included in the independent-review packet. Do not regenerate corrected output batches from their original raw typing artifacts; corrections retain their earlier bytes and receipts.

### Completed Originals title inventory

| Source | Authored Hebrew |
|---|---|
| Kite Weather | מזג אוויר לעפיפונים |
| Campfire pop | פופ למדורה |
| Porchlight | אור במרפסת |
| A slow ballad in D | בלדה איטית בסולם D |
| Moth and Ember | עש וגחלת |
| Stomp-clap folk | פולק עם רקיעות ומחיאות כפיים |
| Low Tide Radio | רדיו בשפל |
| Reggae: chop the offbeat | רגאיי: פריטה קצוצה באוף־ביט |
| Short and dry | קצר ויבש |
| Dust on the Dashboard | אבק על לוח המחוונים |
| Pick the root, then strum | פורטים את צליל היסוד, ואז את האקורד |
| Lantern Hill | גבעת הפנסים |
| Campfire sing-along | שירה משותפת ליד המדורה |
| Gravel Road Two-Step | טו־סטפ בדרך חצץ |
| Country two-step | טו־סטפ קאנטרי |
| First Frost | הכפור הראשון |
| An indie-folk waltz | ואלס אינדי־פולק |
| Hammock Season | עונת הערסלים |
| Reggae on two and four | רגאיי על שתיים וארבע |
| Up, then let go | למעלה, ואז משחררים |
| Glow-in-the-Dark Stars | כוכבים זוהרים בחושך |
| Bedroom pop | פופ חדר שינה |
| Sparkler Season | עונת זיקוקי היד |
| The four-chord anthem | המנון ארבעת האקורדים |
| F, the easy way | אקורד F, בדרך הקלה |
| Roller Rink | זירת הגלגיליות |
| Retro roller-rink pop | פופ רטרו לזירת הגלגיליות |
| Echo Canyon | קניון ההדים |
| Start on the six | מתחילים בשש |
| Open Windows | חלונות פתוחים |
| Pop in 6/8 | פופ ב־6/8 |
| Scoreboard Lights | אורות לוח התוצאות |
| A Friday-night anthem | המנון לערב שישי |
| B minor, the easy way | אקורד B מינור, בדרך הקלה |
| Rust Belt Shuffle | שאפל חגורת החלודה |
| The 12-bar shuffle | שאפל של 12 תיבות |
| Carousel at Closing Time | קרוסלה בשעת סגירה |
| A waltz in D minor | ואלס בסולם D מינור |
| Cedar Smoke | עשן ארז |
| Indie folk in 6/8 | אינדי־פולק ב־6/8 |
| Dsus4, then D | Dsus4, ואז D |
| Rain on the Skylight | גשם על חלון הגג |
| Lo-fi chill | לו־פיי רגוע |
| Sevenths the easy way | ספטימות בדרך הקלה |
| Neon Laundromat | מכבסת ניאון |
| A funk vamp | ואמפ פאנק |
| Land hard on the one | נוחתים חזק על האחת |
| Late Checkout | עזיבה מאוחרת |
| Lo-fi on a loop | לו־פיי בלולאה |
| Saltwater Sunday | יום ראשון במים מלוחים |
| One-drop reggae | רגאיי ואן־דרופ |
| D7 over A minor | אקורד D7 מעל A מינור |
| Pocket Change | כסף קטן |
| Funk scratch | פריטה מגרדת בפאנק |
| Scratch between the hits | מגרדים בין ההדגשות |
| Kitchen Slow Dance | סלואו במטבח |
| A slow dance in 6/8 | סלואו ב־6/8 |
| Fmaj7 and Em7 | Fmaj7 ו־Em7 |
| Houseplants | צמחי בית |
| Bedroom pop in sevenths | פופ חדר שינה בספטימות |
| Gmaj7 and Bm7 | Gmaj7 ו־Bm7 |
| Static on Channel Nine | רעש בערוץ תשע |
| Punk drive | תנופת פאנק־רוק |
| Basement Weather | מזג אוויר במרתף |
| Garage rock | גאראז׳ רוק |
| Punch back | עונים במכה |
| Jukebox Moon | ירח הג׳וקבוקס |
| Fifties doo-wop | דו־וופ של שנות החמישים |
| Boardwalk Comet | שביט בטיילת |
| Surf rock | סרף רוק |
| Mile Marker Zero | סמן מייל אפס |
| Heartland rock | רוק אמריקאי עממי |
| Asus4, then A | Asus4, ואז A |
| Last Bell | הצלצול האחרון |
| Punk-pop | פופ־פאנק |
| Copper Wire | חוט נחושת |
| Riff rock | רוק ריפים |
| Cold Lake | אגם קר |
| Dark rock in 6/8 | רוק כהה ב־6/8 |
| Parking Lot Cathedral | קתדרלת מגרש החניה |
| Indie-rock anthem | המנון אינדי־רוק |
| Halogen | הלוגן |
| Desert rock | רוק מדברי |
| A singer-songwriter ballad | בלדה של זמר־יוצר |
| Keeper's Daughter | בת השומר |
| A story in 6/8 | סיפור ב־6/8 |
| Snow Globe Town | עיירה בכדור שלג |
| A music-box waltz | ואלס של תיבת נגינה |
| Thistle and Thread | קוץ וחוט |
| A folk strummer | פולק בפריטה |
| Asus4 and Asus2 | Asus4 ו־Asus2 |
| Ghost Light | אור רפאים |
| A minor-key ballad | בלדה בסולם מינורי |
| Late Bus Home | האוטובוס המאוחר הביתה |
| B minor, full or easy | אקורד B מינור, מלא או קל |
| Glass Satellites | לווייני זכוכית |
| The power ballad | בלדת הרוק העוצמתית |
| F, the full barre | אקורד F, הבארה המלאה |
| Market Day | יום השוק |
| Highlife sunshine | שמש של היילייף |
| Velvet Hour | שעת קטיפה |
| Neo-soul | ניאו־סול |
| Two new shapes | שתי צורות חדשות |
| Rooftop Choir | מקהלת הגג |
| An anthem with a key change | המנון עם החלפת סולם |
| Chorus in C | הפזמון בסולם C |
| The lift to D | העלייה ל־D |
| Slow Motion Strobe | סטרוב בהילוך איטי |
| Synth-pop on guitar | סינת׳־פופ בגיטרה |
| F sharp minor, the barre | אקורד F דיאז מינור, הבארה |
| Bright Side of the Block | הצד המואר של הרחוב |
| Gospel-pop | גוספל־פופ |
| B minor, the full barre | אקורד B מינור, הבארה המלאה |
| Over You Soon | בקרוב אתגבר עליך |
| Dark pop | פופ כהה |
| Spray Paint Sunrise | זריחה בספריי צבע |
| Indie pop in E | אינדי־פופ בסולם E |
| B and C sharp minor | אקורד B ו־C דיאז מינור |
| Constellation Prize | פרס קבוצת הכוכבים |
| The big finish in 6/8 | הסיום הגדול ב־6/8 |
| B flat, the A-shape barre | אקורד B במול, בארה בצורת A |
