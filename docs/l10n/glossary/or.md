# Timbre — Odia glossary (draft)

Author: /root/complete_three_ui_localizations/author_odia. Independent review and native typography verification pending.

## 1. Locale decisions
- Resource locale `or`; standard written Odia used in Odisha, India. Store locale `or-IN` maps to this resource.
- Address the reader politely as ଆପଣ; instructions use କରନ୍ତୁ, ଶୁଣନ୍ତୁ, ବଜାନ୍ତୁ. Short buttons may use action nouns. Do not introduce gendered language.
- Use “…” for quotations, the single ellipsis …, and । for full sentence endings. Preserve source line breaks, separators, tokens and meaningful punctuation.
- Normal word spacing, with spaces around Latin placeholders/brand names. No invisible joiners unless linguistically necessary.
- Literal digits remain ASCII 0–9, especially all lesson numeric groups. Number placeholders remain unchanged. Odia has `one` and `other` cardinal forms; keep the numeric argument in both.
- Hz, BPM, XP, A4 and ¢ remain unchanged. cents=ସେଣ୍ଟ, minutes=ମିନିଟ୍, seconds=ସେକେଣ୍ଡ, milliseconds=ମିଲିସେକେଣ୍ଡ.
- Odia has no letter case. Latin brand spelling stays exact: Timbre, Timbre Pro, Pro, Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri, ChordPro. Do not attach inflection to brand/placeholder tokens.
- UI notes are supplied by placeholders. Lesson note names and chord symbols stay exactly C, F♯, B♭, Em, G7, D/F♯; never substitute Indian sargam into the source's Western notation.
- Accidentals use ଶାର୍ପ, ଫ୍ଲାଟ୍, ଡବଲ୍ ଶାର୍ପ, ଡବଲ୍ ଫ୍ଲାଟ୍; tuner directional readings use ସ୍ୱର ଉଚ୍ଚ / ସ୍ୱର ନିମ୍ନ, not the accidental names. This avoids confusing chromatic Western accidentals with Indian scale-specific ତୀବ୍ର/କୋମଳ.
- Legal navigation uses ସେଟିଂସ୍ › Apple ଆକାଉଣ୍ଟ › ସଦସ୍ୟତା. Actual iOS system-language support/wording must be verified; no device certification is implied. Apple's product names remain English; generic feature descriptions may be Odia.
- Siri phrases are polite natural commands and retain `${applicationName}` and all other tokens.

## 2. Terminology
| English | Odia | Context |
|---|---|---|
| Tune / tuner / tuning | ସୁର ମିଳାନ୍ତୁ / ଟ୍ୟୁନର୍ / ଟ୍ୟୁନିଂ | Action versus device versus preset |
| Learn / Songs / Practice / Progress / Settings | ଶିଖନ୍ତୁ / ଗୀତ / ଅଭ୍ୟାସ / ପ୍ରଗତି / ସେଟିଂସ୍ | Fixed tabs |
| Today / Quest / Your songs | ଆଜି / ଲକ୍ଷ୍ୟ / ଆପଣଙ୍କ ଗୀତ | Daily plan and side objective |
| Song sheet / Chart / Player view | ଗୀତର ସ୍ୱରଲିପି / କର୍ଡ ଚିତ୍ର / ବାଦକ ଦୃଶ୍ୟ | Imported chart=କର୍ଡ ପତ୍ର |
| Chord view / Neck view / Show me | କର୍ଡ ଦୃଶ୍ୟ / ନେକ୍ ଦୃଶ୍ୟ / ଦେଖାନ୍ତୁ | |
| Strum to tune / Tune by feel / Feel | ଝଙ୍କାର କରି ସୁର ମିଳାନ୍ତୁ / କମ୍ପନ ଅନୁଭବ କରି ସୁର ମିଳାନ୍ତୁ / କମ୍ପନ | Haptic feedback, not emotion |
| Bullseye | ଲକ୍ଷ୍ୟଭେଦ | Game name consistent throughout |
| Ear training / Drone / Tanpura | ଶ୍ରବଣ ଅଭ୍ୟାସ / ନିରନ୍ତର ସ୍ୱର / ତାନପୁରା | Drone is sustained reference tone |
| Intonation | ଅକ୍ଟେଭ୍ ସୁର ସମନ୍ୱୟ | Instrument setup comparing harmonic/fretted pitch |
| Intonation over a drone | ନିରନ୍ତର ସ୍ୱର ସହ ସୁର ଅଭ୍ୟାସ | Pitch accuracy, distinct from setup |
| Metronome / Speed trainer / Chords / Scales | ମେଟ୍ରୋନୋମ୍ / ବେଗ ଅଭ୍ୟାସ / କର୍ଡ / ସ୍କେଲ୍ | |
| Placement check / Play along / Take | ଦକ୍ଷତା ଯାଞ୍ଚ / ସାଥିରେ ବଜାନ୍ତୁ / ପ୍ରୟାସ | Take is performance attempt, not saved audio |
| Loop A–B / Set A / Set B | A–B ପୁନରାବୃତ୍ତି / A ସ୍ଥିର କରନ୍ତୁ / B ସ୍ଥିର କରନ୍ତୁ | Markers unchanged |
| Beginner / Standard / Expert | ନବଶିକ୍ଷାର୍ଥୀ / ମାନକ / ଦକ୍ଷ | Expert not Pro plan |
| Studio (lighter) / Real-time 3D / Haptics | ଷ୍ଟୁଡିଓ (କମ୍ ସଂସାଧନ) / ତତ୍କ୍ଷଣାତ୍ 3D / ସ୍ପର୍ଶ ପ୍ରତିକ୍ରିୟା | |
| In tune / flat / sharp / cents | ସୁର ମିଳିଛି / ସ୍ୱର ନିମ୍ନ / ସ୍ୱର ଉଚ୍ଚ / ସେଣ୍ଟ | Tuner directions |
| lock / string / peg / headstock | ସୁର ସ୍ଥିର / ତାର / ଖୁଣ୍ଟି / ହେଡ୍‌ଷ୍ଟକ୍ | Paid lock=ଲକ୍; not tuning lock |
| reference tone / reference pitch / concert pitch | ଆଧାର ସ୍ୱର / ଆଧାର ସ୍ୱରୋଚ୍ଚତା / ପ୍ରକୃତ ଶ୍ରବ୍ୟ ସ୍ୱର | Context-dependent concert A calibration distinct |
| written pitch / temperament / chromatic / strobe | ଲିଖିତ ସ୍ୱର / ସ୍ୱର ବିଭାଜନ ପଦ୍ଧତି / କ୍ରୋମାଟିକ୍ / ଷ୍ଟ୍ରୋବ୍ | |
| capo / transpose / note names / solfège / sargam | କାପୋ / ସ୍ୱରାନ୍ତର କରନ୍ତୁ / ସ୍ୱରର ନାମ / ସୋଲଫେଜ୍ / ସରଗମ | |
| fret / open string / finger | ଫ୍ରେଟ୍ / ଖୋଲା ତାର / ଆଙ୍ଗୁଠି | Preserve string/fret/finger numbers |
| chord shape / barre chord | କର୍ଡର ଆଙ୍ଗୁଠି ବିନ୍ୟାସ / ବାରେ କର୍ଡ | Barre press spans strings |
| major / minor / seventh / power chord | ମେଜର୍ / ମାଇନର୍ / ସେଭେନ୍ଥ / ପାୱାର୍ କର୍ଡ | Western musical qualities |
| key / major scale / pentatonic box | ମୂଳ ସ୍ୱର / ମେଜର୍ ସ୍କେଲ୍ / ପେଣ୍ଟାଟୋନିକ୍ ବିନ୍ୟାସ | Key not password or piano key |
| half step / whole step / interval / third / fifth / octave | ଅର୍ଦ୍ଧ ସ୍ୱରାନ୍ତର / ପୂର୍ଣ୍ଣ ସ୍ୱରାନ୍ତର / ସ୍ୱରାନ୍ତର / ତୃତୀୟ ସ୍ୱରାନ୍ତର / ପଞ୍ଚମ ସ୍ୱରାନ୍ତର / ଅକ୍ଟେଭ୍ | |
| bar / beat / tempo / downbeat / count | ଆବର୍ତ୍ତ / ମାତ୍ରା / ଲୟର ବେଗ / ପ୍ରଥମ ମାତ୍ରା / ଗଣନା | Measure versus beat |
| strum / downstroke / upstroke / chop / chunk / mute | ଝଙ୍କାର / ତଳମୁଖୀ ଆଘାତ / ଉପରମୁଖୀ ଆଘାତ / ଚପ୍ / ମ୍ୟୁଟ୍ ଝଙ୍କାର / ଶବ୍ଦ ରୋକନ୍ତୁ | Muting not missed note |
| pick / fingerpicking | ପିକ୍ ବା ତାର ଟାଣି ବଜାଇବା / ଆଙ୍ଗୁଠିରେ ତାର ବଜାଇବା | Pick in UI=ବାଛନ୍ତୁ |
| hammer-on / pull-off / slide / bend / vibrato | ହାମର୍-ଅନ୍ / ପୁଲ୍-ଅଫ୍ / ସ୍ଲାଇଡ୍ / ବେଣ୍ଡ୍ / ଭିବ୍ରାଟୋ | Established technique loans, explain in prose |
| bowing / open-string bowing / tune (noun) | ବୋ ଚଳାଇବା / ଖୋଲା ତାରରେ ବୋ ଚଳାଇବା / ସୁର | |
| cadence / V chord / pickup | ସମାପନ ସ୍ୱରକ୍ରମ / V କର୍ଡ / ଆରମ୍ଭର ଅପୂର୍ଣ୍ଣ ଆବର୍ତ୍ତ | Pickup device=ପିକ୍‌ଅପ୍ |
| Intro / Verse / Chorus / Bridge / Solo / Outro / Tag / section | ପ୍ରାରମ୍ଭ / ପଦ / ମୁଖଡ଼ା / ସଂଯୋଗ ଅଂଶ / ଏକକ ବାଦନ / ସମାପ୍ତି / ଶେଷ ପୁନରାବୃତ୍ତି / ଅଂଶ | Physical bridge=ବ୍ରିଜ୍ |
| streak / streak freeze / best run | କ୍ରମାଗତ ଅଭ୍ୟାସ / ଅଭ୍ୟାସ ଧାରା ସୁରକ୍ଷା / ଦୀର୍ଘତମ ଅଭ୍ୟାସ ଧାରା | |
| badge / achievement / level / stars / combo / score / round | ବ୍ୟାଜ୍ / ସଫଳତା / ସ୍ତର / ତାରା / କମ୍ବୋ / ସ୍କୋର୍ / ପର୍ଯ୍ୟାୟ | XP unchanged |
| challenge / course / unit / lesson / step / quiz / hint | ଆହ୍ୱାନ / ପାଠ୍ୟକ୍ରମ / ଏକକ / ପାଠ / ପଦକ୍ଷେପ / ପ୍ରଶ୍ନୋତ୍ତର / ସୂଚନା | Hierarchy distinct |
| subscription / renew / cancel / free trial | ସଦସ୍ୟତା / ନବୀକରଣ / ବାତିଲ / ମାଗଣା ପରୀକ୍ଷଣ | Exact renewal/cancellation facts |
| yearly / monthly / lifetime / restore purchases | ବାର୍ଷିକ / ମାସିକ / ଆଜୀବନ / କ୍ରୟ ପୁନଃସ୍ଥାପନ କରନ୍ତୁ | Lifetime is one payment |
| payment method / billing issue / terms / privacy policy | ଦେୟ ପଦ୍ଧତି / ଦେୟ ସମସ୍ୟା / ସର୍ତ୍ତାବଳୀ / ଗୋପନୀୟତା ନୀତି | |

## 3. Course and song names
ଗିଟାର୍, ୟୁକୁଲେଲେ, ବେସ୍, ଭାୟୋଲିନ୍, ଚେଲୋ, ମାଣ୍ଡୋଲିନ୍, ବାଞ୍ଜୋ; Ear Training=ଶ୍ରବଣ ଅଭ୍ୟାସ; Music Theory=ସଙ୍ଗୀତ ତତ୍ତ୍ୱ; Rhythm=ଛନ୍ଦ; Singing=ଗାୟନ; Originals=ମୌଳିକ ଗୀତ; Standards & Classics=ପ୍ରଚଳିତ ଓ କ୍ଲାସିକ୍ ଗୀତ; Songbook=ଗୀତ ସଂକଳନ.
Public-domain songs use reliably established local titles when known; otherwise transliterate titles consistently. Original song titles are translated, retaining exact cross-reference consistency. Proper personal names and dates in credits remain, but connecting words translate. Sung lyrics are intentionally exempt under the repository licensing policy; canonical musical notation, filenames/product identifiers and English App Review notes also remain unchanged by design.

## 4. Ambiguities
A tuner sharp/flat reading is too high/low, not a named accidental. `Intonation` setup is not drone practice. Physical bridge differs from a song bridge. `Open` depends on context (open string vs button action). `Take` means attempt, not recorded audio. `Key` is musical tonality unless explicitly a keyboard key. `best run` in EarTraining is bestCombo=ସର୍ବଶ୍ରେଷ୍ଠ କମ୍ବୋ, not day streak. `Run` elsewhere may mean practice attempt or streak; inspect the source. No blanket source-identical approvals.
