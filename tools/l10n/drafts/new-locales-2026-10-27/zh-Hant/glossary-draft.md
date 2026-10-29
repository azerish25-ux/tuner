# Timbre — Traditional Chinese glossary (draft)

Author: translation author. Independent review pending; not native-speaker certification.

## Locale decisions
- Canonical resource: `zh-Hant`; Traditional Chinese, Taiwan-oriented terminology, script-wide fallback for Traditional Chinese regions. Do not reuse Simplified Chinese wording mechanically.
- Register: warm, direct `你`; omit pronouns naturally in commands. Buttons use short action labels; no honorific 您.
- Unknown gender: neutral 你; do not add gendered pronouns.
- Punctuation: ，。；：？！「」, 《》 for named works when prose needs a title. Preserve source line breaks and structural separators.
- Use a half-width space around Latin musical notation, ASCII numerals and interpolated values in prose. Digits stay ASCII; lesson digit groups must match exactly.
- Cardinal plurals: `other` only. Do not import English plural grammar.
- Apple UI: 設定 › Apple 帳號 › 訂閱項目. Brand tokens Apple, App Store, Apple Music, Siri, Timbre, Timbre Pro, Pro remain unchanged.
- Note letters/chord symbols remain canonical C, F♯, B♭, Em, G7, D/F♯; do not replace with solfège. Accidentals: 升／降／重升／重降, before note letter. Tuner directions are 偏高／偏低, not 升／降.
- Units: Hz, BPM, XP, A4, ¢ unchanged; cents=音分. No native digits, added emoji or excitement.

## Interface and music terms
| English | Traditional Chinese | Context |
|---|---|---|
| Tune / tuner / tuning | 調音／調音器／調弦 | Tab/action versus device versus preset arrangement |
| Learn / Songs / Practice / Progress / Settings | 學習／歌曲／練習／進度／設定 | Fixed tabs |
| Today / Quest / Your songs | 今日／任務／你的歌曲 | Named plan, side goal, owned charts |
| Song sheet / Chart / Player view | 歌曲譜／和弦圖／演奏視角 | Chart in imported songs may be 和弦譜 |
| Chord view / Neck view / Show me | 和弦視圖／琴頸視圖／示範 | Short display labels |
| Strum to tune / Tune by feel / Feel | 掃弦調音／觸覺調音／觸感 | Haptic sensing, not emotion |
| Bullseye | 正中靶心 | Consistent localized game name |
| Ear training / Drone / Tanpura | 聽力訓練／持續音／坦布拉琴 | Drone is reference sustained tone, never aircraft |
| Intonation | 八度音準校正 | Guided harmonic/fretted comparison and saddle setup |
| Intonation over a drone | 持續音音準練習 | Distinct pitch-accuracy practice |
| Metronome / Speed trainer / Chords / Scales | 節拍器／速度訓練／和弦／音階 | |
| Placement check / Play along / Take | 程度測試／跟著演奏／演奏紀錄 | Take is an attempt, never imply saved audio |
| Loop A–B / Set A / Set B | A–B 循環／設定 A／設定 B | Markers unchanged |
| Beginner / Standard / Expert | 初學／標準／專家 | Precision, Expert is not subscription Pro |
| Studio (lighter) / Real-time 3D / Haptics | 棚拍（較省資源）／即時 3D／觸覺回饋 | |
| In tune / flat / sharp / cents | 音準正確／偏低／偏高／音分 | Tuner direction |
| lock / string / peg / headstock | 鎖定音準／琴弦／弦鈕／琴頭 | Paid locked content is 未解鎖 |
| reference tone / reference pitch / Concert Pitch | 參考音／基準音高／實際音高 | Concert pitch is sounding pitch; inspect source context |
| written pitch / temperament / chromatic / strobe | 記譜音高／律制／半音階／頻閃 | |
| capo / transpose / Note names / Solfège / Sargam | 移調夾／移調／音名／唱名／印度唱名 | |
| fret / open string / finger | 品格／空弦／手指 | Fret wire=品絲; preserve numbers |
| chord shape / barre chord | 和弦指型／封閉和弦 | Barre action=橫按 |
| major / minor / seventh / power chord | 大調或大和弦／小調或小和弦／七和弦／強力和弦 | Qualities versus keys; inspect context |
| key / major scale / pentatonic box | 調性／大音階／五聲音階指型 | Key not keyboard key |
| half step / whole step / interval / third / fifth / octave | 半音／全音／音程／三度／五度／八度 | |
| bar / beat / tempo / downbeat / count | 小節／拍／速度／強拍／數拍 | Downbeat=first beat if specified; count can be numeric count |
| strum / downstroke / upstroke / chop / chunk / mute | 掃弦／下撥／上撥／切音／悶掃／消音 | Preserve source technique distinctions |
| pick / fingerpicking | 撥片或撥弦／指彈 | UI pick=選擇 |
| hammer-on / pull-off / slide / bend / vibrato | 搥弦／勾弦／滑音／推弦／揉弦 | Instrument context can change vibrato to 顫音 |
| bowing / open-string bowing / tune (noun) | 運弓／空弦運弓／旋律 | |
| cadence / V chord / pickup | 終止式／V 級和弦／弱起拍 | Pickup can mean instrument 拾音器 |
| Intro / Verse / Chorus / Bridge / Solo / Outro / Tag / section | 前奏／主歌／副歌／橋段／獨奏／尾奏／尾句／段落 | Physical bridge=琴橋 |
| streak / streak freeze / best run | 連續練習／連續紀錄保護／最長連續紀錄 | |
| badge / achievement / level / stars / combo / score / round | 徽章／成就／等級／星星／連擊／分數／回合 | XP unchanged |
| challenge a friend / challenge (lesson) | 挑戰朋友／挑戰 | |
| course / unit / lesson / step / quiz / hint | 課程／單元／課堂／步驟／測驗／提示 | Hierarchy consistent |
| subscription / renew / cancel / free trial / trial ends | 訂閱／續訂／取消／免費試用／試用結束 | Never soften automatic-renewal conditions |
| yearly / monthly / lifetime / Restore purchases | 年繳／月繳／永久使用／回復購買項目 | Lifetime is one-time purchase, not subscription |
| payment method / billing issue / Terms / Privacy Policy | 付款方式／付款問題／條款／隱私權政策 | |

## Course and song names
Guitar=吉他; Ukulele=烏克麗麗; Bass=貝斯; Violin=小提琴; Cello=大提琴; Mandolin=曼陀林; Banjo=斑鳩琴; Ear Training=聽力訓練; Music Theory=樂理; Rhythm=節奏; Singing=歌唱; Songs=歌曲; Originals=原創歌曲; Standards & Classics=標準曲與經典曲; Songbook=曲集. Instrument names follow established Traditional Chinese usage, transliterating only when no established term exists.

Public-domain songs use established Traditional Chinese titles where available (歡樂頌、平安夜、小星星、綠袖子); preserve other traditional titles as proper names when no reliable localized title exists. Timbre Originals are translated consistently between lesson titles, references and store achievements; record exact title map before curriculum authoring. Credits retain personal names and years, translating connecting prose. Sung lyric content itself is exempt under project guide and licensing; not a missing-UI fallback. ChordPro/file/product identifiers, canonical note sequences and App Review notes remain unchanged intentionally.
