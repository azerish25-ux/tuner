# App Store listing, localized (9 locales)

Store text for Timbre in de-DE, fr-FR, es-MX, pt-BR, it, ja, ko, zh-Hans and ru, adapted from [APP-STORE-LISTING.md](APP-STORE-LISTING.md) (English, U.S., the primary locale). Paste each locale's blocks into App Store Connect → the app → the version's page (description, promotional text, keywords, What's New) and App Information (name, subtitle) for that localization.

## State: what is current, and what is waiting for translators

> **Don't paste any locale's promotional text, description, What's New or screenshot captions yet.** They were written for an earlier build (499 lessons, 13 courses, 20 Originals, a six-frame screenshot set) and are kept under each locale only as reference, folded away. Each locale's **name, subtitle and keywords are current** and within the limits.

The English listing was rewritten for this build (a free-tuner lead, honest song counts, a new nine-frame screenshot set and App Preview captions). Translators work from [Source for translators](#source-for-translators) below: the English text with every count the build can change written as a variable, so a translation never carries a stale number again. Then, per locale:

1. Translate the promotional text, description and What's New from the source, filling the variables from the values table, and paste them in place of the locale's stale reference.
2. Replace every `TRANSLATE:` cell of the locale's two screenshot caption tables with its translation (a caption is at most 30 characters). `tools/marketing/screenshots.py` reads those tables to render the locale's frames, and refuses rows still marked.
3. Run `python3 tools/marketing/screenshots.py --check`: it checks every locale's name, subtitle and keywords against Apple's limits, that its caption tables name the English set's captures in the English order, and that a translated caption quotes no number its English row doesn't. Rows still marked `TRANSLATE:` are listed, not failed.
4. Capture the locale's screens and render its frames: run the UI tests with `TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE`, then `python3 tools/marketing/screenshots.py <captures> <out> --locale de-DE` (and `--ipad`). Japanese, Korean, Chinese and Russian captions are set in a system font with those glyphs (or the one `--font` names), since Sora has none.

## How the earlier text was made (still the rules)

- **Same facts as the English, no stronger.** The free tier, the trial reminder ("with notifications on, Timbre reminds you two days before the trial ends"), no account, no ads and audio never recorded carry the English claims exactly.
- **Adapted, not word-for-word.** Each description keeps the English structure but is written for its market, using the terms the app itself uses in `Resources/<lang>.lproj` (for example Bordun / bourdon / nota pedal / bordone / ドローン / 드론 / 持续音 / бурдон for drone, and the app's own names for streak, quest, achievement, unit and course).
- **Keywords.** At most 100 characters, comma-separated with no spaces after commas (a space appears only inside a two-word term), singular forms, and none of the words already in that locale's name or subtitle, except an instrument word a Custom Product Page needs ([below](#custom-product-page-keywords-by-locale)): a page takes its keywords only from this field. Search terms come from what people in each market type, not from the English list. For ja, ko and zh-Hans no keyword may be a substring of the name or subtitle, with the same exception.
- **Character counts** are Python `len()` on the NFC string.
- **Placeholders.** `<privacy policy URL>` stays as in the English file, in every locale. The Terms link is Apple's standard EULA in every locale.
- **Legal line.** The wording for Settings / Apple Account / Subscriptions follows Apple's own wording for that language (see the notes under each locale and the open points at the end).

## Summary

| Locale | Name | Subtitle |
|---|---|---|
| de-DE | Timbre: Stimmgerät & Lektionen | Gitarre, Geige, Ukulele lernen |
| fr-FR | Timbre : Accordeur Guitare | Leçons violon, ukulélé, basse |
| es-MX | Timbre: Afinador de Guitarra | Aprende violín, ukelele y bajo |
| pt-BR | Timbre: Afinador de Violão | Aulas: ukulele, violino, baixo |
| it | Timbre: Accordatore Chitarra | Impara violino, ukulele, basso |
| ja | Timbre: ギター チューナー＆レッスン | ウクレレ・バイオリン・ベースが学べる |
| ko | Timbre: 기타 튜너 & 레슨 | 바이올린, 우쿨렐레, 베이스 배우기 |
| zh-Hans | Timbre：吉他调音器与课程 | 边弹边学小提琴、尤克里里、贝斯 |
| ru | Timbre: Тюнер для гитары | Уроки скрипки, укулеле и баса |

## Custom Product Page keywords by locale

A Custom Product Page's localization can be assigned keywords only from that localization's keyword field ([the English rule](APP-STORE-LISTING.md#custom-product-pages)): a word that sits only in the subtitle can't be assigned. The three pages to start with, and the word each locale's page takes from its own field today. "—" marks a page that can't be found in that language until the word is added to the field (shorten another keyword to make room; it may repeat a subtitle word, since the page needs it). `screenshots.py --check` fails when a word named here isn't in that locale's field.

| Locale | Violin | Cello | Ukulele |
|---|---|---|---|
| de-DE | Violine | Cello | — add “Ukulele” (subtitle only) |
| fr-FR | — add “violon” (subtitle only) | violoncelle | — add “ukulélé” (subtitle only) |
| es-MX | — add “violín” (subtitle only) | violonchelo | ukulele |
| pt-BR | — add “violino” (subtitle only) | violoncelo | — add “ukulele” (subtitle only) |
| it | — add “violino” (subtitle only) | violoncello | — add “ukulele” (subtitle only) |
| ja | ヴァイオリン | チェロ | — add “ウクレレ” (subtitle only) |
| ko | — add “바이올린” (subtitle only) | 첼로 | — add “우쿨렐레” (subtitle only) |
| zh-Hans | — add “小提琴” (subtitle only) | 大提琴 | 乌克丽丽 |
| ru | скрипка | виолончель | — add “укулеле” (subtitle only) |

## Source for translators

The English text, every count the build can change written as a variable. `screenshots.py --check` computes the values from the build and fails when this table disagrees, when a variable isn't one of these, or when the source with its values filled in no longer reads exactly as the English listing (so a change to the English is made here too).

| Variable | Value in this build | What it is |
|---|---:|---|
| `{instruments}` | 60 | instruments in the catalogue |
| `{tunings}` | 132 | preset tunings |
| `{courses}` | 11 | courses in Learn (the songbooks are counted as songs) |
| `{lessons}` | 526 | lessons in those courses |
| `{songs_floor}` | 140 | distinct song titles, rounded down to ten (144 now): written "{songs_floor}+" |
| `{originals}` | 50 | Timbre Originals |

### Promotional text (170 max)

```
Free tuner, no ads, no account. Feel each string come into tune, then play lessons that listen on guitar, ukulele, violin, cello, bass, mandolin or banjo, and {songs_floor}+ songs.
```

### Description (4000 max)

```
Free tuner, no ads, no account. Then lessons that listen as you play.

Timbre is a precise tuner and a music teacher in one app. Tune any of {instruments} instruments in seconds, then play real lessons that listen to you and tell you exactly how you did.

TUNE ANYTHING, FREE
• Every instrument's standard tuning is free, from guitar, ukulele and violin to mandolin, banjo, oud and erhu
• A chromatic and strobe tuner with cent-level precision
• {tunings} tunings, from drop D and open G to DADGAD, plus your own
• Auto string detection, with a check-off as each string locks in
• Strum to tune: one strum reads every string at once and shows which one to tune first
• Tune by feel: the phone pulses with the beat between your string and its note, slower as they meet and still at the lock, so you can tune without looking
• Studio-lit 3D guitars, basses, violin, cello and mandolin, with the peg to turn shown on the headstock
• Capo, adjustable A4 reference, solfège and sargam note names

LEARN BY PLAYING
• {lessons} lessons in {courses} courses: guitar, ukulele, bass, violin, cello, mandolin, banjo, voice, ear training, music theory and rhythm, plus songbooks for ukulele, mandolin, violin, cello and bass
• Timbre hears every strum: the right chord, on time, and which string didn't ring
• Every note judged as you play it, its pitch to the cent and its timing to the millisecond
• "Show me" plays each new chord on a 3D guitar, the fingers landing in order
• A play-along note highway that slows down for you, then speeds back up as you improve

PLAY SONGS
• {songs_floor}+ songs, each a full arrangement: classics from Jingle Bells to Amazing Grace, and {originals} Originals written for Timbre in today's styles
• Play along with the band in your headphones while the words light up
• Your songs: paste or import any chord chart, transpose it, scroll it in time, and listen to the original on Apple Music beside it

KEEP IT GOING
• Stars, XP, daily quests, streaks and badges
• Game Center: a weekly Bullseye league, song leaderboards and friend challenges
• Apple Watch: a metronome you feel on your wrist, and today's practice at a glance
• Home Screen and Lock Screen widgets, a Live Activity and Siri shortcuts

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course

FREE TO START
Every instrument's standard tuning is free, and guitar, bass, ukulele, violin and cello tune free in every tuning. The first unit of every course and a shelf of songs are free too. Timbre Pro unlocks every lesson and song, every tuning and the full practice set. With notifications on, Timbre reminds you two days before a free trial ends.

Private by design: audio is analysed on your iPhone and never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: <privacy policy URL>
```

### What's New

```
Welcome to Timbre: a free tuner for {instruments} instruments, and {lessons} lessons that listen as you play.
```

### Screenshot captions: iPhone (caption at most 30 characters)

| # | Caption | Supporting line |
|---|---|---|
| 1 | Free tuner. No ads. | {instruments} instruments, to the cent |
| 2 | Hear exactly how you played | Pitch and timing on every note |
| 3 | Play your first chord today | Timbre hears every string |
| 4 | Tune whatever you play | {instruments} instruments, {tunings} tunings |
| 5 | Play songs you know | {songs_floor}+ songs, classics to Originals |
| 6 | Learn at your own pace | {lessons} lessons in {courses} courses |
| 7 | Five minutes a day adds up | Stars, streaks and daily quests |
| 8 | One strum checks every string | See which string to tune first |
| 9 | See yourself get better | Accuracy, string health, badges |

### Screenshot captions: iPad

| # | Caption | Supporting line |
|---|---|---|
| 1 | Free tuner. No ads. | {instruments} instruments, to the cent |
| 2 | Tune whatever you play | Violin to oud, sitar to erhu |
| 3 | Play songs you know | {songs_floor}+ songs, classics to Originals |
| 4 | Five minutes a day adds up | A daily set, quests and ear games |

### App Preview captions

For a localized App Preview (the main cut, then the violin page's), translate these into the locale's own `### App Preview` tables when the preview is localized; until then every storefront shows the English preview.

| Clip | Main preview |
|---|---|
| `lock` | Free tuner. No ads. |
| `tuned` | Every string, checked |
| `showme` | See it played in 3D |
| `highway` | Play songs with the band |
| `results` | Hear how you did |
| `songs` | {songs_floor}+ songs to learn |
| `end` | Tune. Learn. Play songs. |
| `end-note` | Free tuner · No ads · No account |

| Clip | Violin page |
|---|---|
| `lock` | Tune your violin, free |
| `tuned` | G, D, A, E: all in tune |
| `highway` | Play songs on your violin |
| `results` | Hear how you did |
| `songs` | {songs_floor}+ songs to learn |
| `end` | Violin tuner and lessons |
| `end-note` | Free tuner · No ads · No account |

---

## de-DE: German (Germany)

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 30 | 30 | current |
| Subtitle | 30 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 100 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: Stimmgerät & Lektionen
```

### Subtitle

```
Gitarre, Geige, Ukulele lernen
```

### Keywords

```
Tuner,Violine,Bass,Cello,Metronom,Akkord,Gehörbildung,Mandoline,Banjo,chromatisch,Gesang,Lied,Strobe
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Stimmen, dann spielen lernen: 499 Lektionen, die dir zuhören – ob Gitarre, Ukulele, Bass, Violine, Cello, Mandoline, Banjo oder Gesang. Mit jedem Update neue Songs.
```

Description:

```
Timbre ist Stimmgerät und Musiklehrer in einer App. Stimme jedes von 60 Instrumenten in Sekunden und spiele dann echte Lektionen, die dir zuhören und dir genau sagen, wie es gelaufen ist.

ALLES STIMMEN, SCHNELL
• Chromatisches und Stroboskop-Stimmgerät mit centgenauer Anzeige
• 60 Instrumente und 102 Stimmungen, von Gitarre und Violine bis Oud, Sitar und Erhu
• Automatische Saitenerkennung: Jede Saite wird abgehakt, sobald sie sitzt
• 3D-Gitarren, -Bässe, Violine, Cello und Mandoline im Studiolicht
• Eigene Stimmungen, Kapodaster, einstellbare A4-Referenz sowie Solfège- und Sargam-Notennamen

LERNEN DURCH SPIELEN
• 499 Lektionen in 13 Kursen: Gitarre, Ukulele, Bass, Violine, Cello, Mandoline, Banjo, Singen, Gehörbildung, Musiktheorie, Rhythmus, Songs und Originals
• Timbre hört zu, während du spielst: einzelne Töne, ganze Akkorde und Schlagrhythmus, mit Feedback zur Tonhöhe und Timing-Feedback in Millisekunden
• Eine Notenbahn zum Mitspielen, die für dich langsamer wird und mit deinem Fortschritt wieder anzieht
• Ein Songs-Tab: 20 Originalsongs in den Stilen von heute plus gemeinfreie Klassiker, von „Ode an die Freude“ bis „Amazing Grace“
• Sterne, XP, Tagesquests, Serien und Erfolge halten dich bei der Stange

ÜBUNGSTOOLS
• Metronom mit Akzenten, Unterteilungen und Tempotrainer
• Bordun für die Intonation, ein Intonationstrainer sowie eine Akkord- und Tonleiterbibliothek
• Gehörbildung: Tonhöhenrichtung, Intervalle und Akkordtyp, dazu ein Gehörbildungskurs mit 40 Lektionen
• Widgets für Home- und Sperrbildschirm sowie Siri-Kurzbefehle

KOSTENLOS STARTEN
Das Stimmgerät für Gitarre, Bass und Ukulele ist kostenlos, mit einem chromatischen Stimmgerät für alles andere, und das gilt auch für die erste Einheit jedes Kurses. Mit Timbre Pro schaltest du jede Lektion, jedes Instrument und alle Übungstools frei. Den Ablauf der Testphase siehst du auf dem Abo-Bildschirm, und bei eingeschalteten Mitteilungen erinnert dich Timbre zwei Tage vor dem Ende der Testphase.

Privat von Grund auf: Audio wird auf deinem iPhone analysiert und nie aufgezeichnet oder hochgeladen. Kein Konto, keine Werbung.

Abos verlängern sich automatisch, wenn sie nicht mindestens 24 Stunden vor Ablauf des Zeitraums gekündigt werden. Du kannst sie jederzeit unter Einstellungen › Apple-Account › Abonnements verwalten oder kündigen.
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Datenschutz: <privacy policy URL>
```

What's New:

```
Willkommen bei Timbre: ein präzises Stimmgerät für 60 Instrumente und 499 Lektionen, die dir beim Spielen zuhören.
```

Captions (the old six frames):

```
1. Alles in Sekunden stimmen
2. Lektionen, die dir zuhören
3. Mitspielen, Note für Note
4. 499 Lektionen. 13 Kurse.
5. 60 Instrumente, jedes mit eigener Bühne
6. Eine Serie, die du halten willst
```

</details>

**Notes.** Searches targeted: Stimmgerät, Gitarre stimmen, Gitarre lernen, Tuner (very common loan word in German queries), Geige/Violine. "Gitarre" sits in the subtitle so Apple can combine it with "Stimmgerät" from the name. Legal line uses Apple's German "Apple-Account" (hyphenated); the app's own de strings say "Apple Account".

---

## fr-FR: French (France)

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 26 | 30 | current |
| Subtitle | 29 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 98 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre : Accordeur Guitare
```

### Subtitle

```
Leçons violon, ukulélé, basse
```

### Keywords

```
tuner,violoncelle,chromatique,métronome,accord,mandoline,banjo,chant,diapason,solfège,chanson,note
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Accordez, puis apprenez : 499 leçons qui vous écoutent (guitare, ukulélé, basse, violon, violoncelle, mandoline, banjo, chant). Nouvelles chansons à chaque mise à jour.
```

Description:

```
Timbre réunit un accordeur précis et un professeur de musique dans une seule app. Accordez n'importe lequel des 60 instruments en quelques secondes, puis jouez de vraies leçons qui vous écoutent et vous indiquent précisément comment ça s'est passé.

ACCORDEZ TOUT, VITE
• Accordeur chromatique et stroboscopique, précis au cent près
• 60 instruments et 102 accordages, de la guitare et du violon à l'oud, au sitar et à l'erhu
• Détection automatique de la corde, avec une coche à chaque corde accordée
• Guitares, basses, violon, violoncelle et mandoline en 3D, éclairés comme en studio
• Accordages personnalisés, capodastre, référence A4 réglable, noms de notes en solfège et en sargam

APPRENEZ EN JOUANT
• 499 leçons réparties en 13 cours : guitare, ukulélé, basse, violon, violoncelle, mandoline, banjo, chant, entraînement auditif, théorie musicale, rythme, chansons et Originals
• Timbre vous écoute jouer : notes isolées, accords entiers et rythme de grattage, avec un retour sur la hauteur des notes et un retour sur le tempo en millisecondes
• Une piste de notes à suivre, qui ralentit pour vous puis réaccélère à mesure que vous progressez
• Un onglet Chansons : 20 chansons originales dans les styles d'aujourd'hui, plus des classiques du domaine public, de « Ode à la joie » à « Amazing Grace »
• Étoiles, XP, quêtes quotidiennes, séries et succès : de quoi vous donner envie de revenir

OUTILS DE PRATIQUE
• Métronome avec accents, subdivisions et progression de tempo
• Bourdon pour travailler la justesse, entraîneur de justesse, bibliothèque d'accords et de gammes
• Entraînement auditif : sens de la hauteur, intervalles et qualité d'accord, plus un cours d'oreille de 40 leçons
• Widgets pour l'écran d'accueil et l'écran verrouillé, plus raccourcis Siri

GRATUIT POUR COMMENCER
L'accordeur pour guitare, basse et ukulélé est gratuit, avec un accordeur chromatique pour tout autre instrument, tout comme la première unité de chaque cours. Timbre Pro débloque toutes les leçons, tous les instruments et tous les outils de pratique. Le calendrier de l'essai figure sur l'écran d'abonnement et, si les notifications sont activées, Timbre vous prévient deux jours avant la fin de l'essai.

Confidentialité dès la conception : l'audio est analysé sur votre iPhone, jamais enregistré ni envoyé. Aucun compte, aucune publicité.

Les abonnements se renouvellent automatiquement, sauf résiliation au moins 24 heures avant la fin de la période en cours. Gérez-les ou résiliez-les à tout moment dans Réglages › Compte Apple › Abonnements.
Conditions d'utilisation : https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Confidentialité : <privacy policy URL>
```

What's New:

```
Bienvenue dans Timbre : un accordeur précis pour 60 instruments et 499 leçons qui vous écoutent jouer.
```

Captions (the old six frames):

```
1. Accordez tout en quelques secondes
2. Des leçons qui vous écoutent
3. Jouez avec la piste, note à note
4. 499 leçons. 13 cours.
5. 60 instruments, chacun sur sa scène
6. Une série à ne pas casser
```

</details>

**Notes.** Searches targeted: accordeur guitare, accordeur, leçons de guitare / apprendre la guitare, tuner (loan word used in French queries), diapason. Name keeps the French space before the colon. Legal line uses Apple's French "Réglages › Compte Apple › Abonnements".

---

## es-MX: Spanish (Mexico)

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 28 | 30 | current |
| Subtitle | 30 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 98 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: Afinador de Guitarra
```

### Subtitle

```
Aprende violín, ukelele y bajo
```

### Keywords

```
afinar,lecciones,cromático,violonchelo,metrónomo,acorde,mandolina,banjo,ukulele,clases,oído,cantar
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Afina y aprende: 499 lecciones que te escuchan, para guitarra, ukelele, bajo, violín, violonchelo, mandolina, banjo o canto. Canciones nuevas con cada actualización.
```

Description:

```
Timbre es un afinador preciso y un maestro de música en una sola app. Afina cualquiera de sus 60 instrumentos en segundos y luego toca lecciones de verdad que te escuchan y te dicen exactamente cómo lo hiciste.

AFINA LO QUE SEA, RÁPIDO
• Afinador cromático y estroboscópico con precisión de cents
• 60 instrumentos y 102 afinaciones, desde guitarra y violín hasta oud, sitar y erhu
• Detección automática de cuerda, con una palomita cada vez que una cuerda queda afinada
• Guitarras, bajos, violín, violonchelo y mandolina en 3D con luz de estudio
• Afinaciones personalizadas, cejilla, referencia A4 ajustable y nombres de notas en solfeo y sargam

APRENDE TOCANDO
• 499 lecciones en 13 cursos: guitarra, ukelele, bajo, violín, violonchelo, mandolina, banjo, canto, entrenamiento auditivo, teoría musical, ritmo, canciones y Originals
• Timbre te escucha mientras tocas: notas sueltas, acordes completos y ritmo de rasgueo, con retroalimentación de afinación y de tiempo en milisegundos
• Una autopista de notas para tocar al ritmo, que baja la velocidad por ti y la sube de nuevo conforme mejoras
• Una pestaña de Canciones: 20 canciones originales en estilos de hoy, además de clásicos de dominio público, desde «Himno de la alegría» hasta «Sublime gracia»
• Estrellas, XP, misiones diarias, rachas y logros para que sigas volviendo

HERRAMIENTAS DE PRÁCTICA
• Metrónomo con acentos, subdivisiones y entrenador de velocidad
• Nota pedal para trabajar la entonación, un entrenador de entonación y una biblioteca de acordes y escalas
• Entrenamiento auditivo: dirección del tono, intervalos y calidad de los acordes, además de un curso de oído de 40 lecciones
• Widgets para la pantalla de inicio y la pantalla bloqueada, además de atajos de Siri

GRATIS PARA EMPEZAR
El afinador para guitarra, bajo y ukelele es gratis, con un afinador cromático para cualquier otro instrumento, igual que la primera unidad de cada curso. Timbre Pro desbloquea todas las lecciones, todos los instrumentos y todas las herramientas de práctica. La cronología de la prueba aparece en la pantalla de suscripción y, con las notificaciones activadas, Timbre te avisa dos días antes de que termine la prueba.

Privado por diseño: el audio se analiza en tu iPhone y nunca se graba ni se sube. Sin cuenta y sin anuncios.

Las suscripciones se renuevan automáticamente a menos que se cancelen al menos 24 horas antes de que termine el periodo. Administra o cancela cuando quieras en Configuración › Cuenta de Apple › Suscripciones.
Términos: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacidad: <privacy policy URL>
```

What's New:

```
Te damos la bienvenida a Timbre: un afinador preciso para 60 instrumentos y 499 lecciones que te escuchan mientras tocas.
```

Captions (the old six frames):

```
1. Afina lo que sea en segundos
2. Lecciones que te escuchan
3. Toca al ritmo, nota por nota
4. 499 lecciones. 13 cursos.
5. 60 instrumentos, cada uno en su escenario
6. Una racha que quieres mantener
```

</details>

**Notes.** Searches targeted: afinador de guitarra, afinador, afinar guitarra, clases/lecciones de guitarra, ukulele (alternate spelling of the app's "ukelele"). Legal line uses Apple's es-MX "Configuración" and "Cuenta de Apple"; the app's es.lproj says "Ajustes" (Spain wording).

---

## pt-BR: Portuguese (Brazil)

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 26 | 30 | current |
| Subtitle | 30 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 96 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: Afinador de Violão
```

### Subtitle

```
Aulas: ukulele, violino, baixo
```

### Keywords

```
guitarra,afinar,cromático,violoncelo,bandolim,banjo,metrônomo,acorde,cifra,treino auditivo,canto
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Afine e aprenda: 499 lições que ouvem você, para violão, guitarra, ukulele, baixo, violino, violoncelo, bandolim, banjo ou canto. Músicas novas a cada atualização.
```

Description:

```
O Timbre é um afinador preciso e um professor de música em um só app. Afine qualquer um dos 60 instrumentos em segundos e depois toque lições de verdade que ouvem você e mostram exatamente como você se saiu.

AFINE QUALQUER COISA, RÁPIDO
• Afinador cromático e estroboscópico com precisão em cents
• 60 instrumentos e 102 afinações, do violão e do violino ao oud, ao sitar e ao erhu
• Detecção automática de corda, com um visto a cada corda afinada
• Violões, guitarras, baixos, violino, violoncelo e bandolim em 3D com iluminação de estúdio
• Afinações personalizadas, capotraste, referência A4 ajustável e nomes de notas em solfejo e sargam

APRENDA TOCANDO
• 499 lições em 13 cursos: violão e guitarra, ukulele, baixo, violino, violoncelo, bandolim, banjo, canto, treino auditivo, teoria musical, ritmo, músicas e Originais
• O Timbre ouve você tocar: notas isoladas, acordes inteiros e ritmo de batida, com feedback de altura e de tempo em milissegundos
• Uma pista de notas para tocar junto, que desacelera para você e volta a acelerar conforme você evolui
• Uma aba Músicas: 20 músicas originais nos estilos de hoje, além de clássicos em domínio público, de “Ode à Alegria” a “Amazing Grace”
• Estrelas, XP, missões diárias, sequências e conquistas para você voltar sempre

FERRAMENTAS DE PRÁTICA
• Metrônomo com acentos, subdivisões e treino de velocidade
• Nota pedal para exercitar a afinação, um treinador de afinação e uma biblioteca de acordes e escalas
• Treino auditivo: direção da altura, intervalos e qualidade dos acordes, além de um curso de ouvido com 40 lições
• Widgets para a Tela de Início e a Tela Bloqueada, além de atalhos da Siri

COMECE DE GRAÇA
O afinador para violão, guitarra, baixo e ukulele é grátis, com um afinador cromático para qualquer outro instrumento, assim como a primeira unidade de cada curso. O Timbre Pro libera todas as lições, todos os instrumentos e todas as ferramentas de prática. A linha do tempo do teste fica na tela de assinatura e, com as notificações ativadas, o Timbre avisa você dois dias antes de o teste terminar.

Privado desde a concepção: o áudio é analisado no seu iPhone e nunca é gravado nem enviado. Sem conta e sem anúncios.

As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período. Gerencie ou cancele a qualquer momento em Ajustes › Conta Apple › Assinaturas.
Termos: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacidade: <privacy policy URL>
```

What's New:

```
Boas-vindas ao Timbre: um afinador preciso para 60 instrumentos e 499 lições que ouvem você tocar.
```

Captions (the old six frames):

```
1. Afine tudo em segundos
2. Lições que ouvem você
3. Toque junto, nota por nota
4. 499 lições. 13 cursos.
5. 60 instrumentos, cada um no seu palco
6. Uma sequência que vale manter
```

</details>

**Notes.** Searches targeted: afinador de violão (the Brazilian #1 phrase; "violão" = acoustic guitar), afinador de guitarra (guitarra in keywords), aulas de violão / de ukulele, cifra. Subtitle says "Aulas" (market term) while the description follows the app's "lições". Legal line uses Apple's pt-BR "Ajustes › Conta Apple › Assinaturas".

---

## it: Italian

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 28 | 30 | current |
| Subtitle | 30 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 99 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: Accordatore Chitarra
```

### Subtitle

```
Impara violino, ukulele, basso
```

### Keywords

```
tuner,lezioni,cromatico,violoncello,mandolino,banjo,metronomo,accordo,orecchio,canto,canzone,musica
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Accorda, poi impara: 499 lezioni che ti ascoltano, per chitarra, ukulele, basso, violino, violoncello, mandolino, banjo o canto. Canzoni nuove a ogni aggiornamento.
```

Description:

```
Timbre è un accordatore preciso e un insegnante di musica in un'unica app. Accorda uno qualsiasi dei 60 strumenti in pochi secondi, poi suona vere lezioni che ti ascoltano e ti dicono esattamente come te la sei cavata.

ACCORDA TUTTO, IN FRETTA
• Accordatore cromatico e stroboscopico con precisione al cent
• 60 strumenti e 102 accordature, dalla chitarra e dal violino all'oud, al sitar e all'erhu
• Rilevamento automatico della corda, con una spunta a ogni corda che va a posto
• Chitarre, bassi, violino, violoncello e mandolino in 3D, illuminati come in studio
• Accordature personalizzate, capotasto, riferimento A4 regolabile e nomi delle note in solfeggio e sargam

IMPARA SUONANDO
• 499 lezioni in 13 corsi: chitarra, ukulele, basso, violino, violoncello, mandolino, banjo, canto, allenamento dell'orecchio, teoria musicale, ritmo, canzoni e Originali
• Timbre ti ascolta mentre suoni: note singole, accordi interi e ritmo delle pennate, con riscontro sull'altezza delle note e sul tempo in millisecondi
• Un'autostrada delle note da suonare insieme, che rallenta per te e riprende velocità man mano che migliori
• Una scheda Canzoni: 20 canzoni originali negli stili di oggi, più classici di pubblico dominio, da «Inno alla gioia» ad «Amazing Grace»
• Stelle, XP, missioni quotidiane, serie e obiettivi ti fanno tornare ogni giorno

PER ESERCITARTI
• Metronomo con accenti, suddivisioni e allenamento della velocità
• Bordone per lavorare sull'intonazione, un allenatore di intonazione e una libreria di accordi e scale
• Allenamento dell'orecchio: direzione dell'altezza, intervalli e qualità degli accordi, più un corso di 40 lezioni
• Widget per la schermata Home e la schermata di blocco, più scorciatoie Siri

SI COMINCIA GRATIS
L'accordatore per chitarra, basso e ukulele è gratuito, con un accordatore cromatico per qualsiasi altro strumento, come la prima unità di ogni corso. Timbre Pro sblocca ogni lezione, ogni strumento musicale e tutte le funzioni di pratica. La cronologia della prova è sulla schermata dell'abbonamento e, con le notifiche attive, Timbre ti avvisa due giorni prima della fine della prova.

Privato per progettazione: l'audio viene analizzato sul tuo iPhone e non viene mai registrato né caricato. Nessun account, nessuna pubblicità.

Gli abbonamenti si rinnovano automaticamente, a meno che non vengano annullati almeno 24 ore prima della fine del periodo. Gestiscili o annullali in qualsiasi momento in Impostazioni › Account Apple › Abbonamenti.
Termini: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: <privacy policy URL>
```

What's New:

```
Benvenuto in Timbre: un accordatore preciso per 60 strumenti e 499 lezioni che ti ascoltano mentre suoni.
```

Captions (the old six frames):

```
1. Accorda tutto in pochi secondi
2. Lezioni che ti ascoltano
3. Suona insieme, nota dopo nota
4. 499 lezioni. 13 corsi.
5. 60 strumenti, ognuno sul suo palco
6. Una serie da non spezzare
```

</details>

**Notes.** Searches targeted: accordatore chitarra, accordatore, lezioni di chitarra / imparare a suonare, tuner (loan word), accordatore cromatico. Legal line uses Apple's Italian "Impostazioni › Account Apple › Abbonamenti".

---

## ja: Japanese

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 22 | 30 | current |
| Subtitle | 18 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 98 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: ギター チューナー＆レッスン
```

### Subtitle

```
ウクレレ・バイオリン・ベースが学べる
```

### Keywords

```
チューニング,クロマチック,ストロボ,メトロノーム,コード,耳トレ,聴音,チェロ,マンドリン,バンジョー,歌,ボイトレ,音程,ピッチ,ヴァイオリン,カポ,楽器,ギターチューナー,初心者,音感,練習
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
チューニングしたら、そのままレッスンへ。ギター、ウクレレ、ベース、バイオリン、チェロ、マンドリン、バンジョー、歌。演奏を聴き取る499レッスンを収録。アップデートのたびに新しい曲が登場します。
```

Description:

```
Timbreは、精密なチューナーと音楽の先生がひとつになったアプリです。60種類の楽器を数秒でチューニングしたら、そのまま演奏を聴き取り、どう弾けたかをはっきり教えてくれる本格レッスンへ進めます。

【なんでもすばやくチューニング】
・セント単位の精度を誇るクロマチックチューナー＆ストロボチューナー
・ギターやバイオリンから、ウード、シタール、二胡まで、60種類の楽器と102種類のチューニングに対応
・弦の自動検出つき。音が合った弦から順にチェックが入ります
・スタジオライトに照らされた3Dのギター、ベース、バイオリン、チェロ、マンドリン
・カスタムチューニング、カポ、調整できるA4基準音、ソルフェージュとサルガムの音名表示

【弾きながら学ぶ】
・13コース・全499レッスン：ギター、ウクレレ、ベース、バイオリン、チェロ、マンドリン、バンジョー、歌唱、耳トレーニング、音楽理論、リズム、曲、オリジナル曲
・演奏中はTimbreが聴き取ります。単音、コードの全体、ストロークのリズムを判定し、ピッチとタイミングをミリ秒単位でフィードバック
・一緒に演奏するノートハイウェイは、最初はゆっくり、上達に合わせて元のテンポへ戻っていきます
・「曲」タブ：いまどきのスタイルのオリジナル曲20曲と、「歓喜の歌」から「アメイジング・グレイス」までのパブリックドメインの名曲
・星、XP、デイリークエスト、連続記録、実績で、毎日続けたくなります

【練習ツール】
・アクセント、拍の細分化、スピードトレーナーを備えたメトロノーム
・ドローンに合わせた音程練習（イントネーショントレーナー）、コードとスケールのライブラリ
・耳トレーニング：音の高低、音程、コードの響きを聴き分ける練習と、40レッスンの耳トレーニングコース
・ホーム画面とロック画面のウィジェット、Siriショートカット

【無料で始められます】
ギター、ベース、ウクレレ用のチューナーは無料で、そのほかの楽器向けにクロマチックチューナーも付いています。各コースの最初のユニットも無料です。Timbre Proなら、すべてのレッスン、すべての楽器、すべての練習ツールが使えるようになります。無料トライアルの流れはプラン選択画面に表示され、通知をオンにしていれば、トライアル終了の2日前にTimbreがお知らせします。

プライバシーに配慮した設計：音声はiPhone上で分析され、録音やアップロードは一切されません。アカウント登録も広告もありません。

サブスクリプションは、現在の期間が終了する24時間以上前に解約しない限り、自動的に更新されます。「設定」›「Appleアカウント」›「サブスクリプション」でいつでも管理・解約できます。
利用規約：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
プライバシー：<privacy policy URL>
```

What's New:

```
Timbreへようこそ。60種類の楽器に対応する精密チューナーと、演奏を聴き取る499レッスンをお届けします。
```

Captions (the old six frames):

```
1. どんな楽器も数秒でチューニング
2. あなたの演奏を聴くレッスン
3. 音符に合わせて、一音ずつ
4. 499レッスン。13コース。
5. 60種類の楽器、それぞれ専用のステージで
6. 続けたくなる連続記録
```

</details>

**Notes.** Searches targeted: ギター チューナー, チューナー, チューニング, ギター レッスン, ボイトレ, 耳トレ. The name is spaced (ギター チューナー) so each term is its own token. ヴァイオリン is kept in keywords as the alternate spelling of the subtitle's バイオリン, and ギターチューナー (no space) covers the compound spelling of the spaced name. Legal line uses Apple's Japanese "設定 › Appleアカウント › サブスクリプション".

---

## ko: Korean

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 18 | 30 | current |
| Subtitle | 19 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 84 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: 기타 튜너 & 레슨
```

### Subtitle

```
바이올린, 우쿨렐레, 베이스 배우기
```

### Keywords

```
튜닝,크로매틱,스트로브,메트로놈,코드,청음,첼로,만돌린,밴조,노래,보컬,음정,피치,악기,연습,음악,조율,카포,기타튜너,기타튜닝,독학,초보,리듬,음악이론
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
튜닝을 마치면 바로 레슨으로. 기타, 우쿨렐레, 베이스, 바이올린, 첼로, 만돌린, 밴조, 노래까지 연주를 듣고 알려 주는 499개 레슨. 업데이트마다 새로운 곡이 추가됩니다.
```

Description:

```
Timbre는 정밀한 튜너와 음악 선생님을 하나의 앱에 담았습니다. 60가지 악기를 몇 초 만에 튜닝한 뒤, 연주를 들어 주고 얼마나 잘했는지 정확히 알려 주는 진짜 레슨을 시작해 보세요.

■ 무엇이든 빠르게 튜닝
• 센트 단위로 정밀한 크로매틱 튜너와 스트로브 튜너
• 기타와 바이올린부터 우드, 시타르, 얼후까지 악기 60가지, 튜닝 102가지
• 줄 자동 감지, 줄이 맞을 때마다 하나씩 체크
• 스튜디오 조명 아래 3D 기타, 베이스, 바이올린, 첼로, 만돌린
• 사용자 지정 튜닝, 카포, 조절 가능한 A4 기준음, 계명창과 사르감 음 이름

■ 연주하며 배우기
• 13개 코스, 499개 레슨: 기타, 우쿨렐레, 베이스, 바이올린, 첼로, 만돌린, 밴조, 노래하기, 청음 훈련, 음악 이론, 리듬, 노래, 오리지널 곡
• 연주하는 동안 Timbre가 귀 기울입니다. 단음, 코드 전체, 스트럼 리듬을 듣고 음높이 피드백과 밀리초 단위 타이밍 피드백을 알려 드립니다
• 따라 연주하는 음표 하이웨이는 실력에 맞춰 느려졌다가, 실력이 늘면 다시 빨라집니다
• 노래 탭: 요즘 스타일의 오리지널 곡 20곡과 〈환희의 송가〉부터 〈어메이징 그레이스〉까지 저작권이 만료된 명곡
• 별, XP, 일일 퀘스트, 연속 기록, 업적이 매일 다시 찾게 만듭니다

■ 연습 도구
• 강세, 박 나누기, 스피드 트레이너를 갖춘 메트로놈
• 인토네이션 연습용 드론, 인토네이션 트레이너, 코드·스케일 라이브러리
• 청음 훈련: 음의 높낮이 방향, 음정, 코드 종류, 그리고 40개 레슨의 청음 코스
• 홈 화면 및 잠금 화면 위젯, Siri 단축어

■ 무료로 시작
기타, 베이스, 우쿨렐레용 튜너는 무료이고 그 밖의 악기를 위한 크로매틱 튜너도 함께 제공되며, 모든 코스의 첫 번째 단원도 무료입니다. Timbre Pro를 사용하면 모든 레슨, 모든 악기, 모든 연습 도구의 잠금이 해제됩니다. 체험 일정은 구독 화면에 표시되며, 알림을 켜 두면 체험이 끝나기 2일 전에 Timbre가 알려 드립니다.

설계부터 프라이버시 우선: 오디오는 iPhone에서 분석되며 녹음되거나 업로드되지 않습니다. 계정도 광고도 없습니다.

구독은 현재 기간이 끝나기 최소 24시간 전에 취소하지 않으면 자동으로 갱신됩니다. 설정 › Apple 계정 › 구독에서 언제든지 관리하거나 취소할 수 있습니다.
이용약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
개인정보 처리방침: <privacy policy URL>
```

What's New:

```
Timbre에 오신 것을 환영합니다. 60가지 악기를 위한 정밀 튜너와 연주를 들어 주는 499개 레슨을 만나 보세요.
```

Captions (the old six frames):

```
1. 어떤 악기든 몇 초 만에 튜닝
2. 내 연주를 듣는 레슨
3. 한 음 한 음 따라 연주
4. 레슨 499개. 코스 13개.
5. 악기 60가지, 저마다 전용 무대
6. 지키고 싶은 연속 기록
```

</details>

**Notes.** Searches targeted: 기타 튜너, 튜너, 기타 튜닝, 기타 레슨, 청음. "튜닝" sits in keywords (different word from 튜너), 기타튜너 / 기타튜닝 cover the unspaced spellings Korean users type, and the rest follow the app's terms (청음 훈련, 메트로놈, 계명창, 단원). Legal line uses Apple's Korean "설정 › Apple 계정 › 구독".

---

## zh-Hans: Chinese (Simplified)

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 15 | 30 | current |
| Subtitle | 15 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 81 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre：吉他调音器与课程
```

### Subtitle

```
边弹边学小提琴、尤克里里、贝斯
```

### Keywords

```
校音器,调弦,音准,半音阶,频闪,节拍器,和弦,练耳,乐理,大提琴,曼陀林,班卓琴,乌克丽丽,歌曲,唱歌,音乐,教学,零基础,入门,自学,节奏,指板,变调夹,声乐
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
先调音，再学琴：499 节会聆听你演奏的课程，涵盖吉他、尤克里里、贝斯、小提琴、大提琴、曼陀林、班卓琴和唱歌。每次更新都会加入新歌曲。
```

Description:

```
Timbre 集精准调音器与音乐老师于一体。几秒钟就能为 60 种乐器中的任意一种调好音，然后开始真正会“聆听”你演奏的课程，并准确告诉你弹得怎么样。

【快速调准，任何乐器】
• 精度达到音分（cent）级别的半音阶调音器与频闪调音器
• 60 种乐器、102 种调弦，从吉他、小提琴到乌德琴、西塔琴和二胡
• 自动识别琴弦，每调准一根就打一个勾
• 影棚灯光下的 3D 吉他、贝斯、小提琴、大提琴和曼陀林
• 自定义调弦、变调夹、可调 A4 基准音，以及唱名法和萨尔甘（Sargam）音名

【边弹边学】
• 13 门课程、499 节课：吉他、尤克里里、贝斯、小提琴、大提琴、曼陀林、班卓琴、唱歌、练耳、乐理、节奏、歌曲和原创曲目
• 你演奏时 Timbre 在聆听：单音、完整和弦、扫弦节奏，都会给出音高反馈和以毫秒计的节奏反馈
• 可跟弹的音符轨道会为你放慢速度，随着你进步再逐步提速
• 歌曲标签页：20 首当代风格的原创歌曲，另有公版经典，从《欢乐颂》到《奇异恩典》
• 星级、XP、每日任务、连续记录和成就，让你天天想打开它

【练习工具】
• 带重音、节拍细分和速度训练的节拍器
• 用于音准练习的持续音、音准训练器，以及和弦与音阶库
• 练耳：辨别音高方向、音程和和弦性质，另有 40 节课的练耳课程
• 主屏幕和锁定屏幕小组件，以及 Siri 快捷指令

【免费开始】
吉他、贝斯和尤克里里的调音器免费，其他乐器则配有半音阶调音器，每门课程的第一个单元也免费。Timbre Pro 解锁全部课程、全部乐器和完整的练习工具。试用时间线显示在订阅页面上，开启通知后，Timbre 会在试用结束前两天提醒你。

从设计上保护隐私：音频在你的 iPhone 上分析，绝不会被录制或上传。无需账号，没有广告。

订阅会自动续订，除非在当前订阅期结束前至少 24 小时取消。你可随时在“设置”›“Apple 账户”›“订阅”中管理或取消。
条款：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
隐私：<privacy policy URL>
```

What's New:

```
欢迎使用 Timbre：适用于 60 种乐器的精准调音器，以及 499 节会聆听你演奏的课程。
```

Captions (the old six frames):

```
1. 几秒钟调准任何乐器
2. 会聆听你的课程
3. 跟着音符，一音一音弹
4. 499 节课。13 门课程。
5. 60 种乐器，各有各的舞台
6. 值得坚持的连续记录
```

</details>

**Notes.** Searches targeted: 吉他调音器, 调音器, 校音器 (common alternate word for tuner), 吉他教学, 尤克里里 / 乌克丽丽 (both spellings), 练耳. Note: 吉他, 调音器, 课程, 小提琴, 尤克里里 and 贝斯 are already indexed from the name and subtitle. Legal line uses Apple's Simplified Chinese "设置 › Apple 账户 › 订阅".

---

## ru: Russian

| Field | Characters | Limit | State |
|---|---:|---:|---|
| Name | 24 | 30 | current |
| Subtitle | 29 | 30 | current (the English subtitle now leads with songs; worth following) |
| Keywords | 97 | 100 | current |
| Promotional text, Description, What's New | | | **stale: translate from the source above** |
| Screenshot captions | | | **to translate: the tables below** |

### Name

```
Timbre: Тюнер для гитары
```

### Subtitle

```
Уроки скрипки, укулеле и баса
```

### Keywords

```
настройка,хроматический,гитара,скрипка,бас,виолончель,мандолина,банджо,метроном,аккорд,слух,песня
```

### Screenshot captions: iPhone

The English set's frames, in its order. Replace each `TRANSLATE:` cell with the translation (at most 30 characters for a caption).

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `10b-tune-locked` |
| 2 | TRANSLATE: Hear exactly how you played | TRANSLATE: Pitch and timing on every note | `65-song-perform` |
| 3 | TRANSLATE: Play your first chord today | TRANSLATE: Timbre hears every string | `52b-lesson-chord` |
| 4 | TRANSLATE: Tune whatever you play | TRANSLATE: 60 instruments, 132 tunings | `31b-instruments-folk` |
| 5 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `63-songs` |
| 6 | TRANSLATE: Learn at your own pace | TRANSLATE: 526 lessons in 11 courses | `50-learn` |
| 7 | TRANSLATE: Five minutes a day adds up | TRANSLATE: Stars, streaks and daily quests | `62-lesson-results` |
| 8 | TRANSLATE: One strum checks every string | TRANSLATE: See which string to tune first | `11b-tune-strum` |
| 9 | TRANSLATE: See yourself get better | TRANSLATE: Accuracy, string health, badges | `32-journey` |

### Screenshot captions: iPad

| # | Caption | Supporting line | Capture |
|---|---|---|---|
| 1 | TRANSLATE: Free tuner. No ads. | TRANSLATE: 60 instruments, to the cent | `ipad-landscape-tune` |
| 2 | TRANSLATE: Tune whatever you play | TRANSLATE: Violin to oud, sitar to erhu | `ipad-landscape-instruments` |
| 3 | TRANSLATE: Play songs you know | TRANSLATE: 140+ songs, classics to Originals | `ipad-landscape-songs` |
| 4 | TRANSLATE: Five minutes a day adds up | TRANSLATE: A daily set, quests and ear games | `ipad-landscape-practice` |

### Earlier text (stale, for reference only)

<details><summary>The promotional text, description, What's New and captions written for the earlier build (499 lessons, 13 courses, 20 Originals, six frames). Don't paste: reuse its wording where it still fits.</summary>

Promotional text:

```
Настройте и учитесь: 499 уроков, которые слушают вас на гитаре, укулеле, басе, скрипке, виолончели, мандолине, банджо и в пении. С каждым обновлением — новые песни.
```

Description:

```
Timbre — это точный тюнер и учитель музыки в одном приложении. Настройте любой из 60 инструментов за секунды, а затем занимайтесь по настоящим урокам, которые слушают вашу игру и точно говорят, как у вас получилось.

НАСТРАИВАЙТЕ ВСЁ И БЫСТРО
• Хроматический и стробоскопический тюнер с точностью до центов
• 60 инструментов и 102 строя: от гитары и скрипки до уда, ситара и эрху
• Автоопределение струны: каждая струна отмечается галочкой, как только встаёт на место
• 3D-гитары, бас-гитары, скрипка, виолончель и мандолина в студийном свете
• Свои строи, каподастр, настраиваемая опорная частота A4, названия нот в системе сольфеджио и саргам

УЧИТЕСЬ, ИГРАЯ
• 499 уроков в 13 курсах: гитара, укулеле, бас, скрипка, виолончель, мандолина, банджо, пение, тренировка слуха, теория музыки, ритм, песни и «Оригиналы»
• Timbre слушает, как вы играете: отдельные ноты, целые аккорды и ритм боя, с оценкой высоты тона и тайминга в миллисекундах
• Дорожка нот для игры вместе с приложением: она замедляется для вас и снова ускоряется по мере того, как вы растёте
• Вкладка «Песни»: 20 оригинальных песен в современных стилях и классика из общественного достояния, от «Оды к радости» до Amazing Grace
• Звёзды, XP, ежедневные задания, серии и достижения помогают заниматься каждый день

ВСЁ ДЛЯ ЗАНЯТИЙ
• Метроном с акцентами, делением долей и тренажёром темпа
• Бурдон для работы над интонацией, тренажёр интонации, библиотека аккордов и гамм
• Тренировка слуха: направление высоты, интервалы и тип аккорда, а также курс из 40 уроков
• Виджеты для экрана «Домой» и экрана блокировки, быстрые команды Siri

НАЧНИТЕ БЕСПЛАТНО
Тюнер для гитары, баса и укулеле бесплатен, а для любых других инструментов есть хроматический тюнер. Бесплатен и первый раздел каждого курса. Timbre Pro открывает все уроки, все инструменты и все возможности для занятий. График пробного периода показан на экране подписки, а если уведомления включены, Timbre напомнит вам за два дня до окончания пробного периода.

Приватность заложена в основу: звук анализируется на вашем iPhone и никогда не записывается и не отправляется. Без аккаунта и без рекламы.

Подписка продлевается автоматически, если не отменить её не позднее чем за 24 часа до конца текущего периода. Управлять подпиской и отменять её можно в любой момент в разделе Настройки › Аккаунт Apple › Подписки.
Условия использования: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Конфиденциальность: <privacy policy URL>
```

What's New:

```
Добро пожаловать в Timbre: точный тюнер для 60 инструментов и 499 уроков, которые слушают, как вы играете.
```

Captions (the old six frames):

```
1. Настройка за секунды
2. Уроки, которые вас слушают
3. Играйте в ритм, нота за нотой
4. 499 уроков. 13 курсов.
5. 60 инструментов, у каждого своя сцена
6. Серия, которую хочется сохранить
```

</details>

**Notes.** Searches targeted: тюнер для гитары, тюнер, настройка гитары, уроки гитары / игры на гитаре, хроматический тюнер. Nominative forms (гитара, скрипка) are in keywords because people type them that way; the name and subtitle carry the genitive forms. Legal line uses the app's "Настройки › Аккаунт Apple › Подписки".

---
## Open points before submitting

- **The free tier changed.** Every instrument's standard tuning is now free, and guitar, bass, ukulele, violin and cello tune free in every tuning. The stale descriptions name only guitar, bass and ukulele; the source above has the current paragraph.
- **Apple Account spelling (de).** The legal line uses Apple's German "Apple-Account" (hyphenated). The app's `de.lproj` subscription footers say "Apple Account" without the hyphen; worth aligning in the app so the store text and the in-app text match.
- **Settings name (es-MX).** The store text uses Mexican Apple wording: "Configuración › Cuenta de Apple › Suscripciones". The app's `es.lproj` uses "Ajustes" (Spain wording) in its subscription footer. If the app only ships one Spanish file, decide which market it serves; the store text can switch to "Ajustes" if es-ES is added later.
- **Native-speaker pass.** The search terms come from market knowledge, not from keyword-tool volumes. Have a native reader check tone and the keyword choices, and compare with App Store Connect's keyword and search-popularity tools once the locales are live.
- **Not covered here.** In-app purchase display names and descriptions (they need a localization per locale in App Store Connect too), review notes (stay in English), and Custom Product Pages (English first; localize the violin, cello and ukulele pages next, since those are the queries with the weakest competition abroad too).
