# App Store listing, localized (all 50 Apple-supported locales)

## Authoritative content and scope

The current store text is in [`tools/l10n/store/<Apple-locale>.json`](../../tools/l10n/store/). These per-locale files replace the old nine stale Markdown blocks and their `TRANSLATE:` caption cells. The English source remains [APP-STORE-LISTING.md](APP-STORE-LISTING.md); `en-US.json` is its machine-readable text snapshot, not an alternative source.

All **50 Apple-supported listing locales**, including `en-US`, are required. [store-locales.json](../../tools/l10n/store-locales.json) is the exact locale inventory and readiness manifest, verified against [Apple’s supported languages](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations) and [API shortcodes](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes) on 2026-10-26. Listing locales are independent of the **49 app UI/lesson languages**. Malay, Odia and Traditional Chinese listings do not add app UI support; their project app fallback is English, subject to device language preferences and verification. `fa`, `bg`, `et`, `is`, `lt`, `lv`, `sw`, `zu` remain app-only languages; no invented Apple locale codes are used.

Each JSON contains name, subtitle, keywords, promotional text, description, What's New; nine iPhone and four iPad caption/support pairs in the source capture order; both App Preview cuts; three IAP display names/descriptions; twelve Game Center leaderboard names; and the names/descriptions of all 31 Game Center achievements. Product, achievement and capture IDs are not translated. Matching app badge and song-title translations are reused when available. Otherwise draft text and retained musical-work titles are identified in provenance, and must be reconciled with subsequent app lesson imports.

Independent source-aware AI review covers all 50 complete listing payloads. The original 94 corrections, 2 later Slovenian morphology fixes and **157 independently reviewed song-title alignment corrections** (253 total) were applied only after exact-old checks. The title addendum across 38 locales matches the current in-app lesson names; exact source/old/new guards, reviewer decisions and per-locale parent-hash lineage preserve the prior full-payload review. See [title-alignment evidence](../l10n/reviews/store-title-alignment/). Every resulting consumer payload matches the reviewed proposal. [store-review.json](../../tools/l10n/store-review.json) records current content/source hashes, the owner-selected policy and resolved corrections. The original [review evidence](../../tools/l10n/store-review-independent.json) and [correction ledger](../../tools/l10n/store-corrections.json) are retained with artifact hashes. This is not blinded back-translation, native approval, legal certification or measured market research.


The subsequent56 independently reviewed Game Center achievement-description deltas brought the retained correction history to309. The current source update adds100 guarded description/production-URL field records across all50 locales (409 total), reviewed by Codex /root/store_release_copy_review, with accepted Greek/Indonesian register refinements. This bounded review covers live microphone/on-device privacy wording, removal of the disabled Game Center availability promise and production URL resolution. Prior complete-payload review is inherited only for unchanged material; parent/new source hashes and exact review artifacts are retained in [update evidence](../l10n/reviews/store-release-privacy-update/). GC draft metadata and all captions/IAP names remain intact; current candidate integration is off. Published-policy/source alignment is still pending.

## Multi-instrument positioning update

Bounded source-aware independent AI review of owner-approved multi-instrument title/subtitle positioning and keyword continuity across all 50 locales. Unchanged consumer fields inherit prior full-payload review. Exact-old/new deltas and source/payload hash lineage retained. Native-speaker, legal, market, rendered-device and Apple acceptance are not certified. All release flags remain false. The approved English name is **Timbre: Tuner & Music Lessons** and subtitle **Guitar, Violin, Cello & More**. All 50 locales retain the Timbre brand and use compact, reviewed local equivalents. This adds 194 guarded field deltas (49 names, 50 subtitles, 45 keyword fields and 50 whole-array phone-caption permutations) to the retained 759 records, for 953 total. The phone story now introduces instrument breadth before guitar-specific examples; all caption text and capture associations remain unchanged. See [proposal and independent review](../l10n/reviews/multi-instrument-positioning/).

## App Information header persistence — 2026-10-27

All 50 locale name/subtitle pairs were observed persisted in App Store Connect: 49 newly saved locale headers with full-page reload/readback, plus unchanged `en-US` with fresh-page readback. See the [headers-only receipt and source binding](readiness/APP-INFORMATION-HEADERS.md). This does not establish completion of descriptions, keywords, promotional text, localized assets, pricing, signing or submission, and it does not change the release flags below.

## Evidence, not release certification

**Do not paste or upload these drafts as a finished release.** AI-authored text and automated structural checks are not native-speaker, market-search, legal, device, render or App Store Connect approval. Each JSON has independent review states; the manifest tracks actual draft validation separately from `release_ready`. English regional variants intentionally share source wording after regional drafting; they are not missing-language fallback. Nothing here claims keyword popularity has been measured.

Remaining release gates include:
- The production privacy URL is resolved in all50 payloads. Actual public publication evidence is recorded, but published-policy alignment with the current live-microphone/imported-audio source must be refreshed and verified before release.
- Text review under the explicitly recorded policy (see below). The owner selected source-aware AI review instead of mandatory human sign-off; native/instrument-player review, market-ASO research and independent blinded legal back-translation remain **unperformed**, optional additional review under this policy, not claimed certifications.
- Actual localized iPhone/iPad UI captures, glyph coverage, RTL shaping, truncation/overlap and search-size render review. Text metadata does not create native screenshots.
- Localized App Preview recordings and render/audio/sync review. Localized captions alone are not a finished video.
- App Store Connect IAP localization availability and current account limits, configured products, Game Center boards/achievements and images. The local limits are guards, not evidence from the account.
- Custom Product Page asset sets and promotional copy are not newly authored here. The JSON page-keyword mapping only reserves terms from the keyword field; it does not assert page approval or localized asset readiness.

### Explicit text-review policy

`store-review.json.review_policy.mode` selects `ai_source_aware` for this owner-authorized work. With no recorded selection, the validator conservatively defaults to `human`, which retains the native, market and independent legal-review requirements. The AI mode requires explicit owner selection, a named AI reviewer and source-aware method, complete current-payload and English-source SHA-256 hashes, matching source version/counts, and resolution of every identified correction across the exact 50-locale inventory. It never changes native, legal or market fields to `verified`.

Changes to any listing payload, source text/counts or Game Center synchronization invalidate the corresponding review hash. Review changed content independently and update the evidence; **do not mechanically restamp a stale review hash**. Review/provenance metadata is excluded from payload hashes so factual status updates do not alter reviewed text. The historical critical-fact review is retained explicitly as superseded evidence, not the current policy.

Regardless of text-review mode, `--release` still requires a verified HTTPS production privacy URL present in the description, localized device/glyph/RTL/layout evidence, screenshots, preview recordings/render/audio, IAP locale/account checks and Game Center account/assets checks. Each verified release status also needs an actual evidence reference bound to the current listing payload. The tool checks references and hashes; it does not itself authenticate external account/device evidence. Structural and numeric gates and English-source integrity remain mandatory. All listings currently remain `release_ready: false`.

No account changes or submission are authorized by this documentation or its tools.

## Validation and rendering

```sh
python3 tools/l10n/store.py                    # all 50 draft text/structure checks
python3 tools/l10n/store.py --sync-game-center --sync-manifest # after imports; changed payloads need renewed review
python3 tools/l10n/store.py --release          # intentionally fails until release evidence is complete
python3 tools/l10n/store.py --release --review-policy human # inspect the conservative alternative
python3 tools/marketing/screenshots.py --check # original English/source counts + all 50 JSON drafts
python3 tools/marketing/screenshots.py <localized-captures> <out> --locale de-DE
python3 tools/marketing/screenshots.py <localized-ipad-captures> <out> --locale de-DE --ipad
python3 tools/marketing/preview.py render --out <recording-folder> --locale de-DE
```

The screenshot renderer reads JSON captions, inheriting the source's captures and looks. The preview renderer reads JSON captions for the recorded main/violin cut. Both require captures/recordings in the matching language; they do not translate the app pixels. Supply a font with all required glyphs through the screenshot renderer's existing `--font` option, and inspect shaping/layout. Custom Product Page localized screenshots are not implied by the default 13 captions.

Checks use NFC code-point lengths: name/subtitle 30, keywords 100, promo 170, description/What's New 4000, screenshot headline 30 (design constraint), IAP name 2–30/description 45, Game Center title 100/description 500 (provisional account verification required). They validate all required IDs, capture/clip inventory, source counts, literal caption numbers, EULA URL, unresolved translation/count markers, missing text, keyword commas/duplicates and title/subtitle reuse with explicit page exceptions. They cannot mechanically prove meaning, regional idiom, legal equivalence, singular keyword suitability, search popularity, visual quality or Apple eligibility.

**IAP limit verification (2026-10-26).** [Apple’s current IAP reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/) specifies display names of 2–30 characters and descriptions of at most 45. The draft validator uses 45 conservatively for all three products; the older English source table’s 55 label is not the validation authority. Its English text itself fits 45 and is preserved unchanged. Product configuration, subscription-specific acceptance and locale availability still require account verification. [Game Center achievement properties](https://developer.apple.com/help/app-store-connect/reference/game-center/achievements) and [leaderboard properties](https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards) also require account/asset setup beyond translated text.

## Custom Product Page keywords by locale

See each JSON’s `custom_product_page_keywords`: every assigned term must be in that locale’s keyword field and assigned to only one page. Only explicitly listed page assignments are proposed; unlisted pages have no localized keyword assignment. Market validation remains optional and unperformed under the selected AI text-review policy; localized page assets remain pending. No search-popularity measurement is claimed.

## Locale files

| Listing locale | Language | App UI | Draft text |
|---|---|---|---|
| `ar-SA` | Arabic | `ar` | [ar-SA.json](../../tools/l10n/store/ar-SA.json) |
| `bn-BD` | Bangla | `bn` | [bn-BD.json](../../tools/l10n/store/bn-BD.json) |
| `ca` | Catalan | `ca` | [ca.json](../../tools/l10n/store/ca.json) |
| `zh-Hans` | Chinese (Simplified) | `zh-CN` | [zh-Hans.json](../../tools/l10n/store/zh-Hans.json) |
| `zh-Hant` | Chinese (Traditional) | No matching UI language | [zh-Hant.json](../../tools/l10n/store/zh-Hant.json) |
| `hr` | Croatian | `hr` | [hr.json](../../tools/l10n/store/hr.json) |
| `cs` | Czech | `cs` | [cs.json](../../tools/l10n/store/cs.json) |
| `da` | Danish | `da` | [da.json](../../tools/l10n/store/da.json) |
| `nl-NL` | Dutch | `nl` | [nl-NL.json](../../tools/l10n/store/nl-NL.json) |
| `en-AU` | English (Australia) | `en` | [en-AU.json](../../tools/l10n/store/en-AU.json) |
| `en-CA` | English (Canada) | `en` | [en-CA.json](../../tools/l10n/store/en-CA.json) |
| `en-GB` | English (U.K.) | `en` | [en-GB.json](../../tools/l10n/store/en-GB.json) |
| `en-US` | English (U.S.) | `en` | [en-US.json](../../tools/l10n/store/en-US.json) |
| `fi` | Finnish | `fi` | [fi.json](../../tools/l10n/store/fi.json) |
| `fr-FR` | French | `fr` | [fr-FR.json](../../tools/l10n/store/fr-FR.json) |
| `fr-CA` | French (Canada) | `fr` | [fr-CA.json](../../tools/l10n/store/fr-CA.json) |
| `de-DE` | German | `de` | [de-DE.json](../../tools/l10n/store/de-DE.json) |
| `el` | Greek | `el` | [el.json](../../tools/l10n/store/el.json) |
| `gu-IN` | Gujarati | `gu` | [gu-IN.json](../../tools/l10n/store/gu-IN.json) |
| `he` | Hebrew | `he` | [he.json](../../tools/l10n/store/he.json) |
| `hi` | Hindi | `hi` | [hi.json](../../tools/l10n/store/hi.json) |
| `hu` | Hungarian | `hu` | [hu.json](../../tools/l10n/store/hu.json) |
| `id` | Indonesian | `id` | [id.json](../../tools/l10n/store/id.json) |
| `it` | Italian | `it` | [it.json](../../tools/l10n/store/it.json) |
| `ja` | Japanese | `ja` | [ja.json](../../tools/l10n/store/ja.json) |
| `kn-IN` | Kannada | `kn` | [kn-IN.json](../../tools/l10n/store/kn-IN.json) |
| `ko` | Korean | `ko` | [ko.json](../../tools/l10n/store/ko.json) |
| `ms` | Malay | No matching UI language | [ms.json](../../tools/l10n/store/ms.json) |
| `ml-IN` | Malayalam | `ml` | [ml-IN.json](../../tools/l10n/store/ml-IN.json) |
| `mr-IN` | Marathi | `mr` | [mr-IN.json](../../tools/l10n/store/mr-IN.json) |
| `no` | Norwegian | `no` | [no.json](../../tools/l10n/store/no.json) |
| `or-IN` | Odia | No matching UI language | [or-IN.json](../../tools/l10n/store/or-IN.json) |
| `pl` | Polish | `pl` | [pl.json](../../tools/l10n/store/pl.json) |
| `pt-BR` | Portuguese (Brazil) | `pt` | [pt-BR.json](../../tools/l10n/store/pt-BR.json) |
| `pt-PT` | Portuguese (Portugal) | `pt` | [pt-PT.json](../../tools/l10n/store/pt-PT.json) |
| `pa-IN` | Punjabi | `pa` | [pa-IN.json](../../tools/l10n/store/pa-IN.json) |
| `ro` | Romanian | `ro` | [ro.json](../../tools/l10n/store/ro.json) |
| `ru` | Russian | `ru` | [ru.json](../../tools/l10n/store/ru.json) |
| `sk` | Slovak | `sk` | [sk.json](../../tools/l10n/store/sk.json) |
| `sl-SI` | Slovenian | `sl` | [sl-SI.json](../../tools/l10n/store/sl-SI.json) |
| `es-MX` | Spanish (Mexico) | `es` | [es-MX.json](../../tools/l10n/store/es-MX.json) |
| `es-ES` | Spanish (Spain) | `es` | [es-ES.json](../../tools/l10n/store/es-ES.json) |
| `sv` | Swedish | `sv` | [sv.json](../../tools/l10n/store/sv.json) |
| `ta-IN` | Tamil | `ta` | [ta-IN.json](../../tools/l10n/store/ta-IN.json) |
| `te-IN` | Telugu | `te` | [te-IN.json](../../tools/l10n/store/te-IN.json) |
| `th` | Thai | `th` | [th.json](../../tools/l10n/store/th.json) |
| `tr` | Turkish | `tr` | [tr.json](../../tools/l10n/store/tr.json) |
| `uk` | Ukrainian | `uk` | [uk.json](../../tools/l10n/store/uk.json) |
| `ur-PK` | Urdu | `ur` | [ur-PK.json](../../tools/l10n/store/ur-PK.json) |
| `vi` | Vietnamese | `vi` | [vi.json](../../tools/l10n/store/vi.json) |

## Source for translators

The English text, every count the build can change written as a variable. `screenshots.py --check` computes the values from the build and fails when this table disagrees, when a variable isn't one of these, or when the source with its values filled in no longer reads exactly as the English listing (so a change to the English is made here too).

| Variable | Value in this build | What it is |
|---|---:|---|
| `{instruments}` | 60 | instruments in the catalogue |
| `{tunings}` | 132 | preset tunings |
| `{courses}` | 11 | courses in Learn (the songbooks are counted as songs) |
| `{lessons}` | 526 | lessons in those courses |
| `{songs_floor}` | 130 | distinct tunes after treatment/punctuation normalization and exercise exclusion, rounded down to ten (135 now): written "{songs_floor}+" |
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
• Apple Watch: a metronome you feel on your wrist, and today's practice at a glance
• Home Screen and Lock Screen widgets, a Live Activity and Siri shortcuts

PRACTICE TOOLS
• Metronome with accents, subdivisions and a speed trainer
• Drone, an intonation trainer, and a chord and scale library
• Ear training: pitch direction, intervals and chord quality, plus a 40-lesson ear course

FREE TO START
Every instrument's standard tuning is free, and guitar, bass, ukulele, violin and cello tune free in every tuning. The first unit of every course and a shelf of songs are free too. Timbre Pro unlocks every lesson and song, every tuning and the full practice set. With notifications on, Timbre reminds you two days before a free trial ends.

Private by design: live microphone audio is analyzed on your device, never recorded or uploaded. No account and no ads.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel any time in Settings → Apple Account → Subscriptions.
Terms: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy: https://timbre-support.timbre.workers.dev/privacy
```

### What's New

```
Welcome to Timbre: a free tuner for {instruments} instruments, and {lessons} lessons that listen as you play.
```

### Screenshot captions: iPhone (caption at most 30 characters)

| # | Caption | Supporting line |
|---|---|---|
| 1 | Free tuner. No ads. | {instruments} instruments, to the cent |
| 2 | Tune whatever you play | {instruments} instruments, {tunings} tunings |
| 3 | See feedback as you play | Pitch and timing on every note |
| 4 | Play songs you know | {songs_floor}+ songs, classics to Originals |
| 5 | Learn at your own pace | {lessons} lessons in {courses} courses |
| 6 | Play your first chord today | Timbre hears every string |
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
