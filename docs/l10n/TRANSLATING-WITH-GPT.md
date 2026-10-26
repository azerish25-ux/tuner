# Translating Timbre with GPT

The operating manual for producing Timbre's translations with GPT (a large language model) and independent reviewers, so that what comes back passes the repository's checks on the first import, clears the App Store gate, and reads like an app written in the language. It covers what is translated where, the exact input and output of a translation, the rules the import enforces and the ones it can't, ready-to-use prompts, a small helper that batches the TODO files for GPT and checks its answers, the apply-and-verify loop, QA, and the store listing.

Three files go with it:

- [HANDOFF.md](HANDOFF.md): the generated brief, with today's counts (`tools/l10n/report.py` writes it). Its field definitions and import rules hold here unchanged. Its opening line, "Translations are done by people, never by a machine", predates this plan; under this manual GPT drafts, the checks below gate every string mechanically, and independent semantic review checks every launch-critical string and a sample of the rest ([§8.5](#85-human-review)).
- [GLOSSARY-TEMPLATE.md](GLOSSARY-TEMPLATE.md): the term list fixed once per locale and given to GPT with every batch.
- [tools/curriculum/STYLE.md](../../tools/curriculum/STYLE.md): the English voice the translations carry over.

Historical implementation details below were checked against the code at commit `0bbf273` (branch `v2/foundations`). Counts are that commit's; HANDOFF.md always has the current ones. **Store requirements were expanded on 2026-10-26 to all 50 Apple-supported listing locales; requirements are not completion claims.**

## Contents

1. [The work in one page](#1-the-work-in-one-page)
2. [What is translated, where, and in which order](#2-what-is-translated-where-and-in-which-order)
3. [The TODO file](#3-the-todo-file)
4. [Hard rules](#4-hard-rules)
5. [Prompts](#5-prompts)
6. [The batch helper](#6-the-batch-helper)
7. [Apply and verify](#7-apply-and-verify)
8. [QA](#8-qa)
9. [The App Store listing](#9-the-app-store-listing)
10. [Traps the tooling doesn't catch](#10-traps-the-tooling-doesnt-catch)

## 1. The work in one page

Per locale, in this order:

1. **Glossary.** Copy [GLOSSARY-TEMPLATE.md](GLOSSARY-TEMPLATE.md) to `docs/l10n/glossary/<locale>.md`, pre-fill it from the current tables, decide the rest, have an independent reviewer check it.
2. **Batches.** `python3 gpt_l10n.py split <repo> <locale>` cuts `tools/l10n/todo/<locale>.json` into batches of one kind each (legal, permission, VoiceOver, funnel, the rest of the interface, whole lessons) ([§6](#6-the-batch-helper)).
3. **Translate.** For each batch: the system prompt ([§5.1](#51-system-prompt)) plus the batch message the helper writes ([§5.2](#52-batch-message)); GPT answers in JSON ([§5.3](#53-output-format)).
4. **Merge.** `python3 gpt_l10n.py merge <repo> <locale> <answers>` runs the import's own checks plus stricter ones and writes the answers that pass into the TODO file's `translation` fields. Errors go back to GPT; warnings go to the reviewer.
5. **Review.** A GPT review pass over the merged text ([§5.5](#55-review-pass)), then the independent review sample ([§8.5](#85-human-review)). Corrections go into the same `translation` fields.
6. **Import and gates.** `python3 tools/l10n/report.py --import tools/l10n/todo`, then the gates ([§7](#7-apply-and-verify)). Commit.
7. **See it.** Screenshots and a pass on a phone in the language ([§8](#8-qa)).
8. **Listing** (every Apple-supported listing locale; currently 50 including primary English): [§9](#9-the-app-store-listing).

## 2. What is translated, where, and in which order

### 2.1 Surfaces

| Surface | English comes from | Translation ships in | TODO `table` | Locales |
|---|---|---|---|---|
| App interface: every screen, alert, share card and App Intents dialog, the Home and Lock Screen widgets and Live Activity (`ios/TimbreWidgets`), the Watch app and its complications (`ios/TimbreWatch`, `ios/TimbreWatchWidgets`) | Swift string literals, found by `tools/l10n/swiftstrings.py` (the key is the English itself); legacy `timbre_*` keys from `en.lproj/Localizable.strings` | `ios/Timbre/Resources/<locale>.lproj/Localizable.strings`. The widget and Watch targets copy the same table (`ios/project.yml`: `includes: ["*.lproj/Localizable.strings", "*.lproj/Localizable.stringsdict"]`) | `Localizable.strings` | all 48 |
| What VoiceOver says: labels, hints, values, announcements, Voice Control's input labels | the same literals, inside an accessibility modifier or announcement (`tools/l10n/critical.py` finds them) | `Localizable.strings` | `Localizable.strings`, `launch: voiceover` | all 48 |
| Plurals | `en.lproj/Localizable.stringsdict` (7 entries today) | `<locale>.lproj/Localizable.stringsdict` | `Localizable.stringsdict` | all 48 |
| Siri and Shortcuts phrases | `AppShortcut` phrases in `ios/Timbre/Intents/` | `AppShortcuts.strings` | `AppShortcuts.strings` | all 48 |
| System permission prompts, home-screen name | the Timbre target's Info.plist keys in `ios/project.yml` (`NSMicrophoneUsageDescription`, `NSAppleMusicUsageDescription`, `CFBundleDisplayName`) | `InfoPlist.strings` | `InfoPlist.strings`, `launch: permission` | all 48 |
| Lessons: course, unit and lesson titles, lesson cards, prompts, quiz answers and explanations, hints, unit summaries, course subtitles, song section chips, lyric credits | `tools/curriculum/courses/*.py` → `tools/curriculum/build.py` → `en.lproj/Learn.strings` (keys are a hash of the English, so an edited sentence gets a new key) | `tools/l10n/learn/<locale>.json` → `apply_learn.py` → `<locale>.lproj/Learn.strings` | `Learn.strings` | all 48 non-English app locales |
| App Store listing: name, subtitle, keywords, promotional text, description, What's New, screenshot captions, App Preview captions | `docs/ios/APP-STORE-LISTING.md`, and its "Source for translators" (counts as variables) in `docs/ios/APP-STORE-LISTING-LOCALIZED.md` | `tools/l10n/store/<Apple-locale>.json`; release evidence is separate; captions rendered by `tools/marketing/screenshots.py` | none (no TODO file) | all 50 Apple-supported listing locales |
| Other App Store Connect text: in-app purchase display names and descriptions, Game Center leaderboard and achievement names | the tables in `APP-STORE-LISTING.md`; `ios/Timbre/Services/GameCenterIDs.swift` (achievement titles and details are the app's own badge texts) | App Store Connect only | none | as the listing |

Not translated: sung lyrics (the public-domain originals, or Timbre's own for the Originals), App Review notes (English), product and file names. "What's New" exists only as the App Store version text; the app has no What's New screen of its own.

### 2.2 Locales

- **49 string tables**: English, the source, and 48 translations: ar, bg, bn, ca, cs, da, de, el, es, et, fa, fi, fr, gu, he, hi, hr, hu, id, is, it, ja, kn, ko, lt, lv, ml, mr, nl, no, pa, pl, pt, ro, ru, sk, sl, sv, sw, ta, te, th, tr, uk, ur, vi, zh-CN, zu. `tools/verify-ios-resources.py` asserts there are 49 `.lproj` folders. All 48 ship today (`CFBundleLocalizations` in `ios/project.yml`).
- **All 49 app languages include lessons**: English source plus all 48 translation targets. The original nine delivered lesson maps (de, es, fr, it, ja, ko, pt, ru, zh-CN) remain partial; they do not limit the requirement.
- **The 39 newly required lesson targets** originally added **237,120 locale-string pairs** at the historical 6,080-key expansion baseline. The current English source has 6,083 keys after reviewed context splits and retirement; use the generated handoff and exact current key/text set, never a historical count alone. Verify a newly assigned TODO against publisher English before freezing it. Do not overwrite active frozen batches after a source change: preserve explicit source-bound addenda and retirement records. Missing maps/tables still produce lesson TODOs. Do not manufacture English copies: fallback is temporary missing content, not completed translation.
- **Automatic language**: fresh settings use `TimbreLocalization.system`, so iOS selects the phone/app preferred localization and regional fallback through `Bundle.main`. An explicit in-app language choice remains respected; selecting System restores automatic behavior. Missing lesson text is a content gap, not evidence the language resolver failed.
- **Right to left**: ar, fa, he, ur ([§4.11](#411-right-to-left-ar-fa-he-ur)).
- **Variants**: one table per language serves every region. `es` serves Spain and Latin America (the current table uses Spain's iOS wording, "Ajustes"; the existing store block is es-MX, "Configuración"; es-ES is also required), `pt` serves Brazil and Portugal (the current table is Brazilian, "você"), `zh-CN` is Simplified Chinese, `no` is Norwegian Bokmål. The glossary records the variant.

**Store scope:** all 50 Apple locales in [store-locales.json](../../tools/l10n/store-locales.json), with exact API shortcodes, app mappings, primary English fallback policy and source URLs. Eight app languages (`fa`, `bg`, `et`, `is`, `lt`, `lv`, `sw`, `zu`) have no Apple listing locale: do not invent one. Malay (`ms`), Odia (`or-IN`) and Traditional Chinese (`zh-Hant`) listings are required but do not add app UI languages or justify claiming UI support. English regional listings and French, Portuguese and Spanish regional variants are distinct metadata deliverables. The app remains 49 languages (English + 48 translations), with lessons required in all 49.

### 2.3 Historical baseline (at 0bbf273; superseded by generated handoff)

Current requirements include the additional 237,120 lesson pairs above. Run `python3 tools/l10n/lessons.py --strict` for applied coverage and consult the generated [HANDOFF.md](HANDOFF.md) for current queues. Copied-English entries, including shared titles needing independent review, are conservatively unresolved. No native review is implied by a mechanical pass. Legitimate English-identical proper names, original titles, notation or credits can be approved per locale/key in `tools/l10n/lesson-invariants.json`: exact current `source`, a reason covering the entire string, and the actual `reviewed_by` identity. No wildcard approvals or fabricated review records.

639 interface strings in every one of the 48 locales (30,672 locale-string pairs), of which 151 are launch-critical, and 1,467 lesson strings in each lesson language (13,203 pairs). Every locale has 67.7 % of the interface (`python3 tools/l10n/shipping.py`). 1,410 of the pairs are `changed`: the English was edited and the old translation comes along to update.

### 2.4 Priority, and the gate each step opens

The TODO files are already in this order: `report.py` puts the launch-critical entries first (legal, permission, VoiceOver, funnel), then the interface in the order a new user meets it (permission prompts, onboarding, the paywall, the tabs, the tuner, Learn, Songs, Practice, Progress, instruments, Your songs, Settings, then everything else), then the lessons in course order. Translate from the top.

| # | What | Marker in the TODO entry | Strings (each locale) | What it unlocks |
|---|---|---|---:|---|
| 1 | Purchase terms (the paywall's renewal, trial, cancel, billing, restore, Terms and Privacy texts) | `launch: legal` | 11 | `critical.py --strict`, which the App Store upload runs (`apple-delivery.yml`): a shipped locale may lack none of 1–3. `critical.py --baseline` fails any pull request that adds a new gap. |
| 2 | Permission prompts | `launch: permission` | 1 | as 1 |
| 3 | VoiceOver | `launch: voiceover` | 93 | as 1 |
| 4 | Onboarding, welcome to paywall | `launch: funnel` | 46 | No gate, but it is the first thing every new user reads, and `LocalizationLaunchUITests` checks the German welcome ([§8.2](#82-the-localization-launch-tests)). |
| 5 | The rest of the interface | none | 488 | The shipping bar: `shipping.py --min 95` ships a locale only when 95 % of its interface is translated ([§7.6](#76-shipping-fewer-locales)). |
| 6 | Lessons (all 48 target locales) | `table: Learn.strings` | up to 6,080 | `lessons.py --strict`: every target must have complete applied lesson text before external delivery; English fallback is incomplete. |
| 7 | Store listing (all 50 Apple locales) | none | 13 caption rows plus the text blocks | `screenshots.py --check` ([§9](#9-the-app-store-listing)). |

Across locales, the order that gets an upload through soonest:

1. Steps 1–4 for all 48 locales. Then `critical.py --strict` passes with every locale shipped.
2. Step 5 for the 9 major locales: they are complete.
3. Step 6 for all 48 target lesson locales. Step 7 for **all 50 listing locales**, starting with the nine existing partial blocks and primary English, then the 40 additional listings.
4. Step 5 for the other 39, shipping each one as it reaches the bar.

Until a locale has steps 1–3, either it doesn't ship (`shipping.py --min … --critical --apply`) or the upload fails.

## 3. The TODO file

`tools/l10n/todo/<locale>.json`, generated by `python3 tools/l10n/report.py`. One file per locale, one string per line, so a delivered translation is a one-line diff. `tools/l10n/todo/index.json` holds the counts; it isn't a TODO file.

### 3.1 Header

| Field | Meaning |
|---|---|
| `locale` | The locale code (the `.lproj` name). The import uses it (falling back to the file name). |
| `language` | Its English name. |
| `about` | "fill in the translation fields and change nothing else". |
| `counts` | Entries per table. |
| `strings` | The entries, below. |

### 3.2 Entry fields

| Field | When present | Meaning | GPT |
|---|---|---|---|
| `table` | always | Where the string ships: `Localizable.strings`, `Localizable.stringsdict`, `AppShortcuts.strings`, `InfoPlist.strings`, `Learn.strings` ([§2.1](#21-surfaces)). | reads; never changes |
| `key` | always | The lookup key. Interface: the English itself (for `timbre_*` and InfoPlist keys, an identifier). Lessons: `L` + a hash of the English. | never sees it (the helper maps ids to keys) |
| `source` | always | The English to translate. For a plural, the English `other` form. | translates |
| `context` | when the code has a comment above the string, for every lesson string, InfoPlist and plurals | Interface: the developer's comment (layout, what the text does). Lessons: course · unit · lesson kind, id and title · step number and type · role (title, lesson card text, question or instruction, quiz answer, explanation after a quiz answer, hint under an exercise, song section label, lyric credit). Plurals: an instruction to give every form. | reads |
| `where` | interface strings | Up to two `file:line` locations in the Swift sources (line numbers drift). The helper adds the code line as `code`, which shows what fills each `%@`. | reads |
| `layout` | when the code shows a tight spot | `one line`, `shrinks to fit` (the text scales down to fit), `small label`, `control label` (a button, tab, toggle or badge), `system UI label` (a Shortcuts title, a widget's name), comma-separated. | reads |
| `max_length` | tight interface strings; every lesson string except lyric credits | Aim at most this many characters. Interface: `max(len + 6, 1.5 × len)` of the English with each argument counted as two characters (only for English of up to 60 characters), a soft limit. Lessons: the limit the English is written to (title 42, lesson card 300, question 140, quiz answer 48, hint 120, explanation 220, unit summary 120, course subtitle 80; a section chip `max(12, 1.5 × len)`). Nothing enforces it; the screen truncates or shrinks. | stays within |
| `launch` | launch-critical strings | `legal`, `permission`, `voiceover` or `funnel` ([§2.4](#24-priority-and-the-gate-each-step-opens)). A string that is both legal and VoiceOver shows `legal`. | applies the rules of [§4.15](#415-legal-permission-voiceover-siri-watch) |
| `key_check` | 5 new interface strings today | The scanner guessed an argument's type in the key (`%lld` or `%@`). Translate normally; a developer confirms the key before importing ([§7.4](#74-confirm-guessed-keys-key_check)). | translates normally |
| `status` | always | `new`; `changed`: the English was edited, `previous` has the old English and its translation; `rejected`: a delivered translation failed a check, `problem` says why. | follows |
| `previous` | `changed`, some `rejected` | `{"source": old English, "translation": old translation}` for `changed`; `{"translation": …}` for a rejected delivery that was stored but failed. | starts from it |
| `problem` | `rejected` | Why the import refused the text: "format arguments or ${…} tokens differ from the English", "the numbers differ from the English", "the line breaks differ from the English", "the count of ♯ differs from the English", "a plural needs a JSON object with at least an "other" form", "empty". | fixes exactly that |
| `translation` | always | **The only field that is filled.** A string; for `Localizable.stringsdict`, a JSON object of plural forms. Empty means "not translated" (the entry is skipped). For a rejected entry it may hold the refused text. | writes (through the helper) |

Never change any other field, never reorder, add or delete lines, never rename the file. `report.py` regenerates the file from the code after every import, keeps every `translation` typed into it (`carried_translations`), and drops entries whose English no longer exists.

### 3.3 Examples (from `de.json`)

A changed legal string: start from `previous.translation`, change what the English change requires (here "cancel anytime" became "Cancel anytime in Settings"):

```json
{"table": "Localizable.strings", "key": "Cancel anytime in Settings", "source": "Cancel anytime in Settings", "where": ["ios/Timbre/Paywall/PaywallView.swift:1033", "ios/Timbre/Paywall/PaywallView.swift:1041"], "status": "changed", "previous": {"source": "cancel anytime", "translation": "jederzeit kündbar"}, "launch": "legal", "translation": ""}
```

A VoiceOver string with a layout limit:

```json
{"table": "Localizable.strings", "key": "Not heard", "source": "Not heard", "where": ["ios/Timbre/Tune/StrumMeters.swift:180", "ios/Timbre/Tune/StrumMeters.swift:534"], "layout": "one line", "max_length": 15, "status": "new", "launch": "voiceover", "translation": ""}
```

A string whose key was guessed (`key_check`):

```json
{"table": "Localizable.strings", "key": "Then %@. It renews automatically until you cancel in Settings.", "source": "Then %@. It renews automatically until you cancel in Settings.", "where": ["ios/Timbre/Paywall/PaywallWinBack.swift:208"], "key_check": "the interpolation types in this key are inferred: confirm it with an Xcode export (l10n.yml) before applying", "status": "new", "launch": "legal", "translation": ""}
```

A lesson string:

```json
{"table": "Learn.strings", "key": "La0e88a1c69", "source": "B A G A B B B: open string 2, then string 3.", "context": "Guitar · Unit 1 · song gtr-1-6 “Mary Had a Little Lamb: three notes” · step 3 (notes) · hint under an exercise", "max_length": 120, "status": "new", "translation": ""}
```

Its German translation must write H for B and keep both digits: `"H A G A H H H: leere Saite 2, dann Saite 3."` ("zwei" for 2 is refused: "the numbers differ from the English").

A Siri phrase:

```json
{"table": "AppShortcuts.strings", "key": "${command} in ${applicationName}", "source": "${command} in ${applicationName}", "context": "Mid-lesson, hands on the instrument: \"Again in Timbre\", \"Next in Timbre\", \"Slower in Timbre\".", "where": ["ios/Timbre/Intents/TimbreShortcuts.swift:34"], "status": "new", "translation": ""}
```

A plural (none is open today; this is the shape one takes), and its Russian translation:

```json
{"table": "Localizable.stringsdict", "key": "%lld sessions", "source": "%lld sessions", "context": "Plural. Give every plural form your language uses (zero, one, two, few, many, other) as a JSON object, e.g. {\"one\": \"…\", \"other\": \"…\"}.", "status": "new",
 "translation": {"one": "%lld занятие", "few": "%lld занятия", "many": "%lld занятий", "other": "%lld занятия"}}
```

### 3.4 What happens to an entry after the import

| Entry | After `report.py --import tools/l10n/todo` |
|---|---|
| A translation that passes the checks | Merged into `tools/l10n/translations/<locale>.json` (interface) or `tools/l10n/learn/<locale>.json` (lessons), written into the `.lproj` tables, gone from the regenerated TODO file. |
| A translation that fails a check | Printed as "not imported"; stays in the TODO file with `status: rejected`, `problem` and the refused text in `translation`. |
| A plural that passes | Printed as "add it to `<locale>.lproj/Localizable.stringsdict` by hand"; nothing is written ([§7.5](#75-plurals-by-hand)). The entry stays until the plural is in the table. |
| A `key_check` translation under a wrong guessed key | Imported under a key the app never looks up: the entry disappears from the TODO file while the app still shows English. Confirm keys first ([§7.4](#74-confirm-guessed-keys-key_check)). |
| An empty `translation` | Skipped; stays. |

## 4. Hard rules

The rules GPT follows. The prompts ([§5](#5-prompts)) carry them; this section gives the reasons and the per-language detail. "The import checks" means `report.py --import` refuses the text; "the helper checks" means `gpt_l10n.py merge` refuses it or warns.

### 4.1 Format arguments

Arguments are where the app inserts a value at run time: `%@` text (a note or chord name, an instrument, a song title, a price, a date, a translated word such as "flat"), `%lld` and `%d` whole numbers, `%lf`, `%f` and `%.1f` decimals, `%llu` and `%u` unsigned numbers. `%%` is a literal percent sign in a string that has arguments ("Save %lld%%").

- Keep every argument: the same number of each type. The app formats the number itself, in the reader's locale.
- To change their order, number all of them with their position in the English: "Combo %lld, ×%lld" → `×%2$lld · Combo %1$lld`. Never mix numbered and plain arguments in one string (`Takt %1$lld von %lld` is refused).
- Legacy `timbre_*` strings already number theirs (`%1$d`); keep the numbers.
- Never add an argument, never drop one, never put a space or letter inside one (`% @`, `%l ld`), never use a full-width ％.
- `%%` stays `%%`.

The import checks the types and their order (`tools/l10n/apply.py`, `specs`), every type included (`%lf`, `%llu`, `%u` and precisions such as `%.1lf` since 2026-10-25; before that a dropped `%lf` slipped through). The helper checks them too.

Example of what the arguments hold, from `code`: `Text("Your \(labels[worst.anchor] ?? worst.anchor) string drifts \(worst.centsPerDay < 0 ? String(localized: "flat") : String(localized: "sharp")) about \(Int(abs(worst.centsPerDay).rounded()))¢ a day.")` is "Your %@ string drifts %@ about %lld¢ a day.": a string's name, the translated word for flat or sharp, a number. The German that shipped for the earlier wording reorders all three: `Deine %1$@-Saite verstimmt sich: etwa %3$lld Cent pro Tag %2$@.`

### 4.2 Named tokens and literal syntax

- `${applicationName}`, `${instrument}`, `${key}`, `${bpm}`, `${command}` (Siri phrases and Shortcuts summaries): keep each one exactly as spelled, in any order. Every Siri phrase keeps `${applicationName}`; Siri needs the app's name in the phrase. The import checks them.
- Literal syntax stays verbatim: ChordPro in examples (`[G]Amazing [C]grace`, `{start_of_chorus}`, `{end_of_chorus}`), URLs, file names, the `›` between Settings levels (it mirrors itself in right-to-left text), `·` separators, `×` multipliers, `≈`, `→`, en-dash ranges (`1–16`), `/`, `+`.
- Symbols the English uses for meaning stay: ♯ ♭ ✓ ▲ ▼ ¢.

### 4.3 Plurals

New plural keys arrive as `table: Localizable.stringsdict`; today all 7 are translated in every locale. The translation is a JSON object with the forms the language uses. The categories are CLDR's; the repository's own `.stringsdict` files record which each locale uses:

| Forms | Locales |
|---|---|
| `other` | id, ja, ko, th, vi, zh-CN |
| `one`, `other` | bg, bn, ca, da, de, el, es, et, fa, fi, fr, gu, hi, hu, is, it, kn, ml, mr, nl, no, pa, pt, sv, sw, ta, te, tr, ur, zu (and en) |
| `zero`, `one`, `other` | lv |
| `one`, `two`, `other` | he |
| `one`, `few`, `other` | cs, hr, lt, ro, sk |
| `one`, `two`, `few`, `other` | sl |
| `one`, `few`, `many`, `other` | pl, ru, uk |
| `zero`, `one`, `two`, `few`, `many`, `other` | ar |

- `one` is not "exactly 1" in every language: it is 0 and 1 in fr, pt, hi, bn, gu, kn, fa and zu, 1, 21, 31 … in ru, uk, hr, lt, lv and is, and 1, 101 … in sl. So **every form keeps the number**: each form must carry the same arguments as the English (`%lld`), or the import refuses it, even though the English `one` of "Every %lld bars" reads "Every bar".
- `other` is always required.
- The import doesn't write plurals ([§7.5](#75-plurals-by-hand)).

Counted strings that are **not** plurals: many interface strings carry a count in a flat `Localizable.strings` entry ("%lld bars", "Finish %lld lessons", "Hit %lld bullseyes"). One text must then read right for every number. In languages with several plural forms, write a count-neutral form: a label and a colon (Russian "тактов: %lld"), or the form that fits the common counts. A unit abbreviation that doesn't inflect ("%lld дн.") works on screen, but not in a VoiceOver string. `tools/l10n/plurals-en.json` lists 22 such strings that become real plurals when the app moves to String Catalogs (`tools/l10n/xcstrings.py`); translators add their forms then.

### 4.4 Line breaks, spaces and characters

- **Line breaks** (`\n` in the TODO file's JSON, a real line break in the text): lessons must keep the same number as the English (the import checks). Interface strings should keep the English line structure ("Tune in seconds.\nThen learn to play." is a two-line headline); the import doesn't check, the helper warns.
- No leading or trailing spaces, no double spaces.
- The ellipsis is one character, …, wherever the English has it ("Listening…"). The current tables mix in three dots in places; don't follow them.
- Write ordinary hyphens: the code itself turns "45-second" into non-breaking hyphens.
- Invisible characters: none, except the right-to-left marks of [§4.11](#411-right-to-left-ar-fa-he-ur), the joiners a script needs (ZWNJ in Persian "می‌شوید", ZWJ and ZWNJ in Indic scripts), and the no-break spaces of French typography.

### 4.5 Length and layout

- `max_length` is a target, not a check: nothing refuses a longer text, but a `one line` label truncates and a `shrinks to fit` label gets smaller. The helper warns.
- Count CJK characters twice (each is about two Latin characters wide); the helper does.
- `control label`: a button, tab, toggle or badge; use the shortest natural wording the iOS convention of the language allows (infinitive or noun).
- `small label`: caption-sized text on a chip or capsule.
- Watch and widget strings (`where` in `ios/TimbreWatch`, `ios/TimbreWatchWidgets`, `ios/TimbreWidgets`) sit on very small screens even without a `layout`.
- Long compounds (German, Finnish, Dutch, Hungarian, Russian) don't hyphenate in a one-line label: choose a shorter word.
- Lessons: German, Russian and French run 20–35 % longer than English; the limits leave little room. Shorten wording, never the content of a lesson card, a question or a legal sentence; say in `note` when a limit can't be met.
- VoiceOver strings have no visual limit; keep them as short as the English.

### 4.6 Names that never change

Timbre, Timbre Pro, Pro (the plan), Apple, iPhone, iPad, Apple Watch, App Store, Apple Music, Game Center, Siri, ChordPro, XP, BPM, Hz, A4. Never translate, transliterate or inflect "Timbre": rebuild the sentence so it needs no ending ("in Timbre", "die App Timbre"). Apple's own products keep Apple's spelling in each language; Apple's localized names of iOS places and features (Settings, Apple Account, Subscriptions, Home Screen, Lock Screen, Live Activity, Shortcuts, Control Center) are used as iOS shows them in the language ([glossary §1](GLOSSARY-TEMPLATE.md#1-locale-decisions)).

Decided per locale, in the glossary: song titles (local title where one is established, else the English; Originals translated or kept), the course names, and the game "Bullseye". HANDOFF.md asks to keep game names, but every shipped table translates "Bullseye" (de Volltreffer, fr Tir parfait, ja ど真ん中, ru В яблочко); the glossary decides, and every string naming the game follows it. Instrument names are translated, as the catalogue's `timbre_catalog_*` keys already are.

### 4.7 Units and numbers

- Hz, BPM, XP and the cents sign ¢ stay as they are. The word "cents" is translated (Cent, セント, 音分, центы). "min", "ms" follow the language's abbreviations.
- Interface strings: a literal number in the English stays the same number. Thousands separators follow the language ("Score 2,000 in Bullseye": de 2.000, fr 2 000 with a no-break space). Digits: Western 0–9, unless the current table uses the script's own digits (fa, bn and mr do in places); numbers the app formats follow the device's settings anyway.
- **Lessons** (the import checks): every group of digits in the English appears in the translation, the same groups the same number of times, in ASCII digits 0–9. So: "string 2" stays "2", never "zwei", "二" or a full-width "２"; "2,000" may become "2.000" or "2 000" (the digit groups 2 and 000 survive) but not "2000"; a number the English spells as a word ("three notes", "ten half steps") stays a word, because a digit the English doesn't have is also refused. The count of `%` signs must match too.

### 4.8 Note names

- **Interface**: the app writes note and chord names itself, through `NoteNames` and the player's Settings › Note names: German letters (B natural H, B♭ B) by default in `de`, letters in every other language, or the player's choice of solfège, sargam or numbers; VoiceOver speaks them with the language's own words (`NoteNames.spoken`). Interface strings therefore never spell a note of their own: the `%@` brings it. The few letters in interface English are not notes: "Loop A–B", "Set B" are loop markers, and `[G]` in the ChordPro help is syntax. Keep them as they are (German too).
- **Lessons**: note letters and chord symbols exactly as in the English (C, F♯, B♭, Em, G7, D/F♯, DADGAD), with one exception the import knows: German writes H for B natural and B for B♭ (a German `B♭` drops its sign). Lesson text is not respelled at run time; only diagrams, chord names and the tools follow the setting. Don't convert lessons to Do Ré Mi, even in languages that read solfège.
- **♯ and ♭**: a sign in the English stays a sign (the import counts them). A spelled-out "sharp" or "flat" becomes the language's word, as `NoteNames.SpokenWords` has them (fr dièse/bémol, it diesis/bemolle, es sostenido/bemol, pt sustenido/bemol, ru диез/бемоль as "D-диез", ja シャープ/フラット as "Dシャープ", zh-CN 升/降 before the letter, "升 D", ko 샵/플랫), never a sign: a sign the English doesn't have is refused. German may write a spelled-out "D sharp" as the German name "Dis" ("E flat" as "Es"); where the English writes the sign (D♯, E♭), German keeps the sign. Never ASCII `#` or `b`.
- **Tuner direction**: "flat" and "sharp" on the tuner mean too low and too high (de zu tief / zu hoch); the glossary has both senses.

### 4.9 Musical terminology

Use the glossary's term for every listed word, every time, inflected as the grammar needs. For words not in it, use what instrument teachers in the language say; loanwords are fine where usual (Bend, Hammer-on). Several English words have more than one sense in Timbre (Tune, sharp/flat, bar, key, pick, lock, take, run, chart, Intonation): the glossary's last section lists them. Where the batch gives `refs` (the current translation of a control or screen the string names) or `lesson_title`, use them verbatim. Known wrong terms in the shipped tables are listed in [§10](#10-traps-the-tooling-doesnt-catch); don't copy them.

### 4.10 Punctuation and quotation marks

The quotation marks are the ones the current tables use where they quote a control's name ("Tap Listen to start"); where a table doesn't quote, the language's standard form follows the slash.

| Language | Quotation marks | Other |
|---|---|---|
| de | „…“ | |
| fr | « … » with no-break spaces | no-break space (U+00A0 or narrow U+202F) before : ; ? ! |
| es, ca, it, pt | none around control names; «…» (es, ca, it) or “…” (pt) for titles | Spanish opens questions with ¿ |
| ru, uk, el | «…» | Greek question mark is ; (U+037E) |
| pl, ro | „…” | |
| hu | none / „…” | |
| cs, sk, bg, lt | „…“ | |
| et, hr, lv | „…” | |
| sl | »…« | |
| da, no, sv, fi, is, nl, tr, id, vi, sw | none / “…” (sv, fi ”…”) | |
| ar, fa | «…» | Arabic comma ، and question mark ؟ |
| he | “…” | |
| ur | “…” | full stop ۔ |
| hi, bn, pa | “…” | full stop । (danda) |
| mr, gu, kn, ml, ta, te, zu | “…” | full stop . |
| th | “…” | no full stop |
| ja | 「…」 | 、。！？（）：full width, digits ASCII |
| zh-CN | “…”, 《…》 for titles | ，。：；？！（）full width |
| ko | ‘…’ | Western punctuation |

The glossary fixes the final choice; keep it consistent with the current table. When a string names another control ("Tap Listen to start"), use that control's exact translation (the batch's `refs`), quoted as the language quotes control names.

### 4.11 Right to left (ar, fa, he, ur)

The layout flips by itself (`TimbreLocalization.isRightToLeft`); the tuner readout, the note highway, the timing strip and other pictures of an instrument stay left to right in code. The text needs three things:

- **Begin with a word of the language.** A paragraph can take its direction from its first strong character, so a string that starts with `%@` (which may be a Latin note, chord or song title) or a Latin word may lay out left to right. Numbers don't count (`%lld دقيقة` is fine). When the sentence must begin with the value, start the string with U+200F (RIGHT-TO-LEFT MARK) and say so in `note`. The helper warns on every such string; many in the current tables start with `%@`, and the Arabic captures show whether they read right.
- **Isolate a Latin value that touches digits or punctuation.** A note with an octave ("E♭3"), a chord change ("Em → G") or a tuning name inside a sentence stays whole when the argument is wrapped in U+2068 (FIRST STRONG ISOLATE) … U+2069 (POP DIRECTIONAL ISOLATE). Use it only where a value sits beside a number, a dash, a slash, a colon or parentheses, and list every mark you add in `note`: they are invisible to a reviewer. The import keeps them; the helper lists them.
- **Digits**: Western digits in literal numbers unless the glossary says otherwise (the current fa table uses Persian digits in places); formatted numbers follow the device. Brackets and parentheses mirror by themselves; write them in reading order.

The Arabic octave test ([§8.2](#82-the-localization-launch-tests)) guards the tuner readout; the Arabic captures are where a reviewer sees the rest.

### 4.12 CJK, Thai and Indic scripts

- **ja**: no spaces between kana or kanji and Latin letters, digits or arguments (Gメジャー, %lld日, レベル%lld); full-width 、。「」（）！？ and full-width ： in prose; ASCII digits always (lessons require them); です/ます.
- **zh-CN**: a half-width space between Han characters and Latin letters, digits or arguments (保持你的 %lld 天连续记录, G 大调); full-width ，。：；？！“”（）and 《》 for titles; 你, not 您.
- **ko**: normal Korean word spacing. A particle after an argument depends on the value's last sound (이/가, 을/를, 은/는, 와/과, 으로/로), which the translator can't see: rephrase so the argument needs no particle (a noun after it, or a colon), or use the paired form "을(를)".
- **th**: no spaces between words (a space ends a phrase), no full stop; don't insert zero-width spaces, iOS breaks lines by dictionary.
- **hi, bn, gu, kn, ml, mr, pa, ta, te**: keep the ZWJ and ZWNJ the script needs; the danda । ends a sentence in hi, bn and pa (the mr table uses a full stop); English loanwords for app terms are common (ट्यून), the glossary decides.

### 4.13 Register and voice

The English voice (`tools/curriculum/STYLE.md`): "Second person, present tense, warm and direct, like a good teacher sitting next to you. No exclamation marks except in a rare celebration. No emoji. No filler." Carry that over:

- One register for the whole app, lessons included, fixed in the glossary.
- No exclamation mark or emoji the English doesn't have; no marketing words the English doesn't use; nothing added, nothing left out.
- Settings, buttons and system texts follow Apple's own conventions in the language.
- Write a sentence a native teacher would say, not a mirror of the English.

The register the shipped tables use (read from a sample of their strings; the glossary confirms or overrules it):

| Register | Locales |
|---|---|
| Informal "you" | ca (tu), da, de (du), es (tú), et, fi, hu, is, it (tu), nl (je), no, pl, sv, sw, zu |
| Formal or plural "you" | bg, cs, el, fa, fr (vous), id (Anda), lt, lv, pt (você, polite), ru (вы), sk, tr (mostly), uk (ви) |
| Polite verb forms | bn, gu, hi, kn, mr, pa, ta, te, ur (आप-style); ja (です/ます); ko (해요체) |
| Neutral | ar (masculine singular imperatives), ml, th, vi (bạn), zh-CN (你) |
| **Mixed: decide and clean up** | he (plural and masculine singular), hr, ro, sl (formal and informal imperatives side by side), tr ("Her teli akort et" beside formal ones) |

### 4.14 Grammar around arguments

- Never inflect an argument or attach an ending to it. Build the sentence so the inserted value stands where its dictionary form fits: before or after a noun in apposition ("die %@-Saite"), or after a colon ("Nächstes Lied: %@").
- Gender and case agreement with an unknown value (an instrument, a song): avoid it with a neutral construction.
- Suffixing languages (tr, fi, hu, et, ko): the suffix depends on the value's sound; rephrase, or use the apostrophe form the language allows for foreign words (tr `%@'e` is still wrong half the time: prefer a label).
- One key can serve several places (`where` lists up to two, and `code` the first): "Next", "Again" and "Slower" are on-screen labels and also Siri's command words (`ios/Timbre/Intents/PracticeIntents.swift`). Choose a wording that works in every place; say in `note` when none does.

### 4.15 Legal, permission, VoiceOver, Siri, Watch

- **Legal** (`launch: legal`): translate every fact exactly: automatic renewal, cancelling at least a day (24 hours) before renewal, where to cancel (Apple's own names for Settings › Apple Account › Subscriptions in the language), what stays free, the trial and its end, the billing problem and the grace period. Add nothing, soften nothing, drop nothing; don't shorten a legal sentence to meet `max_length` (say so in `note`). Apple reviews these texts in every language the app ships.
- **Permission prompts** (`launch: permission`): the purpose and the privacy promise exactly ("Timbre plays the Apple Music songs you choose, so you can listen to them beside your own chord charts."); Apple rejects vague purpose strings. Timbre stays the subject.
- **VoiceOver** (`launch: voiceover`): the text is spoken. Labels are short noun phrases without the control's type ("button"); hints are third-person verb phrases saying what happens ("Opens…", "Plays…", "Shows…"), as iOS phrases them in the language. Prefer words to symbols VoiceOver reads oddly; no abbreviations where the English has none.
- **Siri phrases** (`AppShortcuts.strings`): natural spoken commands a person says aloud, keeping `${applicationName}` and every other token.
- **Watch, widgets, Live Activity**: the shortest natural wording.

## 5. Prompts

The system prompt is the same for every batch and every locale. The batch message carries the locale's glossary, a few of its current translations as style anchors, and the batch; the helper writes it ([§6](#6-the-batch-helper)).

### 5.1 System prompt

Save as `system.txt` and send it as the system (or developer) message of every request:

```text
You are the senior localizer for Timbre, an iPhone app that is a precise tuner and a music teacher in one: it tunes 60
instruments, teaches guitar, ukulele, bass, violin, cello, mandolin, banjo, singing, ear training, music theory and
rhythm with lessons that listen to the player through the microphone, and has songs to play along to, a metronome, a
drone, ear games, streaks and a subscription called Timbre Pro. You translate its strings from American English into
the language the user message names. Your text ships in the app as it is: a program checks it, then a native speaker
reads a sample.

VOICE
- Timbre speaks like a good teacher sitting next to the player: warm, direct, second person, present tense, plain
  words, short sentences. Use the register (formal or informal "you") the glossary fixes, everywhere.
- Write what a native speaker would write in an iPhone app (Apple's own wording and conventions for the language),
  not a word-for-word copy. Keep the meaning, every fact, and roughly the length.
- No exclamation mark, emoji, filler or marketing word the English doesn't have. Add nothing, leave nothing out.

INPUT
A JSON array of items. Each item has:
- id: echo it back.
- table: Localizable.strings (app interface, widgets, Watch, VoiceOver), Localizable.stringsdict (a plural),
  AppShortcuts.strings (a Siri phrase), InfoPlist.strings (a system permission prompt), Learn.strings (lesson text).
- source: the English to translate.
- context: where the text appears and what it does; for lessons the course, unit, lesson, step and the role of the text.
- where, code: the Swift source line; it shows what each %@ or %lld will hold.
- layout, max_length: the text sits somewhere tight; stay within max_length characters (count each Chinese, Japanese or
  Korean character as two).
- launch: legal, permission, voiceover or funnel. Special rules below.
- status: new; changed (the English was edited: start from previous.translation and change only what the edit from
  previous.source to source requires); rejected (a checker refused rejected_text or previous.translation for the reason
  in problem: fix exactly that).
- refs: the app's current translations of other controls or screens this text names. Use them verbatim.
- lesson_title: the current translation of the title of the lesson this text belongs to. Name the song the same way.
- plural_forms: for a plural, the plural categories of this language that you must fill.
- translation: only in a review pass: the current translation to check.

HARD RULES (a program refuses a translation that breaks rules 1 to 6)
1. Format arguments (%@ %lld %d %lf %f %.1f %llu %u): keep every one, the same number of each type. To change their
   order, number ALL of them with their position in the English (%1$@ … %2$lld); never mix numbered and plain ones.
   Keep %% as %%. Never translate, space out or add an argument.
2. Tokens ${applicationName} ${instrument} ${key} ${bpm} ${command}: keep each exactly, any order. Every Siri phrase
   keeps ${applicationName}.
3. Line breaks: keep the English number of line breaks (required in lessons; in the interface keep the line structure).
   No leading or trailing spaces.
4. Lessons (table Learn.strings): every group of digits in the English appears in your text, the same groups the same
   number of times, in ASCII digits 0-9 (never words, never full-width or native digits); add no digit the English
   lacks, so numbers the English spells out stay words. Keep the count of ♯, ♭ and % signs. A ♯ or ♭ sign stays a
   sign; a spelled-out "sharp" or "flat" becomes your language's word from the glossary, never a sign. German only:
   B natural is H, and B♭ is B (drop the sign).
5. Plurals (table Localizable.stringsdict): answer in "plural" with every category of plural_forms; every form keeps
   the same arguments as the English, the number included, even in "one".
6. Note and chord names in lessons stay exactly as in the English (C, F♯, B♭, Em, G7, D/F♯, DADGAD), except the German
   rule above. Interface strings never spell a note themselves: the app inserts notes through %@. "Loop A–B" and
   "Set B" are loop markers, not notes.
7. Never translate: Timbre, Timbre Pro, Pro (the plan), Apple, iPhone, iPad, Apple Watch, App Store, Apple Music,
   Game Center, Siri, ChordPro, XP, BPM, Hz, A4, ¢. Never inflect "Timbre": rebuild the sentence instead. Literal
   syntax stays: [G], {start_of_chorus}, URLs, › between Settings levels, ·, ×, →, ranges like 1–16.
8. Use the glossary's translation for every term it lists, every time. Use refs and lesson_title verbatim.
9. Never inflect an argument or attach an ending, particle, article or case suffix to it; build the sentence so the
   inserted value needs none (a noun beside it, or a colon).
10. Right-to-left languages (ar, fa, he, ur): begin with a word of the language, not with %@ or a Latin word; if the
    sentence must begin with the value, start the string with U+200F. Where a Latin value (%@: a note, chord, tuning or
    title) touches digits or punctuation, wrap that argument in U+2068 … U+2069. Name every invisible character you
    add in note.
11. Legal strings (launch: legal): every fact exactly (automatic renewal, cancel at least a day before renewal, where
    to cancel with Apple's own names for Settings, Apple Account and Subscriptions in this language, what stays free,
    the trial). Never shorten them to fit. Permission prompts (launch: permission): the purpose and the privacy promise
    exactly, Timbre as the subject.
12. VoiceOver strings (launch: voiceover) are spoken: labels are short noun phrases without the control's type; hints
    are third-person verb phrases saying what happens ("Opens…"), as iOS phrases them in this language. No
    abbreviation the English doesn't have.
13. Use the language's punctuation, quotation marks and spacing as the glossary fixes them. One ellipsis character …
    where the English has it.

OUTPUT
Only JSON, no prose, no code fence:
{"items": [{"id": "s001", "translation": "…", "plural": null, "note": ""}, …]}
- Exactly one item per input id, the same ids.
- translation: your text. For a plural, "" (the forms go in plural).
- plural: null, or for table Localizable.stringsdict an object with the keys zero, one, two, few, many, other; null
  for each category not in plural_forms.
- note: "" normally. One short English sentence when a human should look: an ambiguity you resolved, a rule you could
  not meet (a length, a word order), a term the glossary lacks, an invisible character you added, a place where one
  translation cannot serve every use of the key.

BEFORE ANSWERING, CHECK EVERY ITEM
- Same arguments and tokens as the English, numbered if reordered; %% kept.
- Same line breaks; no leading or trailing space.
- Lessons: same digit groups in ASCII digits, same ♯ ♭ % counts, letters as in the English (German H and B).
- Plural: every category of plural_forms, each with the number.
- Glossary terms, refs and lesson_title used exactly; register consistent; brand names intact.
- Within max_length; legal and permission facts complete.
- Right-to-left: starts with a word of the language or U+200F.
- Valid JSON, one item per id.
```

### 5.2 Batch message

`python3 gpt_l10n.py prompt <repo> <locale> batches/<batch>.json <repo>/docs/l10n/glossary/<locale>.md` writes `batches/<batch>.prompt.txt`: the user message for that batch. Its shape:

```text
Translate this batch of Timbre strings from American English into German (de).

Locale decisions and glossary for German (binding):
<<<
(the whole glossary file)
>>>

How Timbre already reads in German (current translations; match their register, terms and punctuation):
- "Pluck your thickest string" → "Zupf deine dickste Saite"
- "Tap Listen to start" → "Tippe auf „Zuhören“, um zu starten"
- … (ten interface pairs from the current table, plus six lesson pairs for a lesson batch)

The batch: 40 strings, kind "voiceover". Return exactly one item per id, in the JSON format the system prompt gives.
[ {"id": "s001", "table": "Localizable.strings", "source": "…", "where": "…", "code": "…", "launch": "voiceover", …}, … ]
```

The style anchors come from the locale's own shipped strings, so a locale whose current table is wrong in register (the mixed ones of [§4.13](#413-register-and-voice)) needs its glossary decision stated plainly; the glossary is binding, the anchors are examples.

### 5.3 Output format

GPT answers with this JSON. Through an API that supports structured output, pass the schema so the model can't answer anything else (it is written for strict mode: every property required, nulls explicit):

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["items"],
  "properties": {
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id", "translation", "plural", "note"],
        "properties": {
          "id": {"type": "string"},
          "translation": {"type": "string"},
          "plural": {
            "anyOf": [
              {"type": "null"},
              {
                "type": "object",
                "additionalProperties": false,
                "required": ["zero", "one", "two", "few", "many", "other"],
                "properties": {
                  "zero": {"type": ["string", "null"]},
                  "one": {"type": ["string", "null"]},
                  "two": {"type": ["string", "null"]},
                  "few": {"type": ["string", "null"]},
                  "many": {"type": ["string", "null"]},
                  "other": {"type": "string"}
                }
              }
            ]
          },
          "note": {"type": "string"}
        }
      }
    }
  }
}
```

Save each answer beside its batch as `<batch>.out.json` (`de-003.json` → `de-003.out.json`).

Driving it through the OpenAI API (Python SDK; adjust the model name, and drop `temperature` if the model refuses it):

```python
import json, sys
from pathlib import Path
from openai import OpenAI

client = OpenAI()
system = Path("system.txt").read_text(encoding="utf-8")
schema = json.loads(Path("schema.json").read_text(encoding="utf-8"))     # the schema above
for prompt in sys.argv[1:]:                                               # batches/de-0*.prompt.txt
    out = Path(prompt.replace(".prompt.txt", ".out.json"))
    if out.exists():
        continue
    response = client.chat.completions.create(
        model="<your GPT model>",
        temperature=0.2,
        messages=[{"role": "system", "content": system},
                  {"role": "user", "content": Path(prompt).read_text(encoding="utf-8")}],
        response_format={"type": "json_schema",
                         "json_schema": {"name": "timbre_batch", "strict": True, "schema": schema}},
    )
    out.write_text(response.choices[0].message.content, encoding="utf-8")
    print(out)
```

In a chat window instead: put `system.txt` in the custom instructions (or paste it first), paste one `.prompt.txt` per message, and save each reply as the batch's `.out.json`. Start a new conversation every few batches so the glossary stays in view.

### 5.4 Batch size, model and settings

- **Size**: `--size 40` (the default). The helper never mixes kinds: the 11 legal strings form one batch, the permission prompt another, then VoiceOver, the funnel, the rest of the interface, and lessons, which it only cuts between lessons (a lesson is always translated whole, in order, about 40–50 strings a batch). Use `--size 25` for the languages GPT handles less well (zu, sw, pa, gu, kn, ml, mr, te, ta, bn), where smaller batches get more care.
- **Model**: the strongest GPT model available. A reasoning model for lessons and for the legal batch.
- **Temperature**: low (0.2) where the model accepts one: terminology must not wander between batches.
- **Volume**: at 40 strings a batch, about 20 interface batches per locale (48 locales) and about 34 lesson batches per lesson language (9): some 1,270 requests for everything, plus a review pass. Run them through the API, not a chat window.
- **Order**: steps 1–4 of [§2.4](#24-priority-and-the-gate-each-step-opens) first in every locale; within a locale, the helper's batch numbers follow the TODO order.

### 5.5 Review pass

After the merge, a second GPT pass checks the merged text before a human sees it:

```sh
cd ~/timbre-l10n
python3 gpt_l10n.py split  ~/src/tuner de --review --out batches     # entries with a translation, not yet imported
python3 gpt_l10n.py prompt ~/src/tuner de batches/de-review-001.json ~/src/tuner/docs/l10n/glossary/de.md
#   GPT: system.txt + batches/de-review-001.prompt.txt  →  batches/de-review-001.out.json
python3 gpt_l10n.py merge  ~/src/tuner de batches/de-review-0*.out.json
```

The review message asks GPT to return every item, unchanged when right, corrected with a `note` otherwise; `merge` writes the corrections back (they pass the same checks). Run it with a different model or a fresh conversation than the translation, so it doesn't approve its own reasoning. Every `note` from either pass goes to the independent reviewer.

### 5.6 Context beyond the batch

The batch already carries `context`, the code line, `refs`, `lesson_title`, `previous` and the layout hints. Where the model accepts images, add the English screenshots of the screens a batch covers: the nightly tour publishes them on the `ci-results/app` branch (`git fetch origin ci-results/app`, the `screenshots` folder); the onboarding captures for the funnel, the paywall for the legal batch, the tuner for VoiceOver. For lessons, the batch is a whole lesson in order, which is the context a lesson needs. When `code` and `context` still leave an argument unclear, ask the developer before translating; a guessed `%@` is the most common cause of a wrong sentence.

## 6. The batch helper

`tools/l10n/gpt_l10n.py` is a standalone script (Python 3.9 or later, standard library only; it was tested against this commit's TODO files: split, prompt, merge, then a clean `report.py --import`). Copy it into a working folder outside the repository, for example `~/timbre-l10n/` beside `system.txt`, `schema.json` and the `batches` folder; it reads the repository through the path you give it and changes only the `translation` fields of `tools/l10n/todo/<locale>.json`. It imports `tools/l10n/report.py` for the import's own checks, so its verdict and the import's never disagree, and adds the checks the import lacks (`%lf`, `%llu` and `%u` arguments; line breaks, length, brand names, exclamation marks, emoji, three dots, text left in English, right-to-left starts and invisible marks, as warnings).

```sh
cd ~/timbre-l10n
python3 gpt_l10n.py split  ~/src/tuner de --out batches              # batches/de-001.json …, with a .map.json each
python3 gpt_l10n.py prompt ~/src/tuner de batches/de-001.json ~/src/tuner/docs/l10n/glossary/de.md
#   GPT: system.txt + batches/de-001.prompt.txt  →  batches/de-001.out.json
python3 gpt_l10n.py merge  ~/src/tuner de batches/de-0*.out.json
```

`merge` prints, per answer: `ERROR` (the answer is refused and not written), `WARN` (written, but a reviewer must look), `NOTE` (GPT's own remark, for the reviewer), and "no answer" for ids GPT skipped. Answers for entries that left the TODO file meanwhile (translated elsewhere, or the English changed) are skipped. The refused and unanswered entries are still empty, so the next `split` picks them up: run it into a **new** folder each round (`--out batches-2`), because a new split numbers its ids afresh and an old answer must never meet a new map. Give GPT the `ERROR` lines of the previous round with the new batch. Entries the import refused (`status: rejected`) come back with their `problem` and the refused text.

The script's full source is `tools/l10n/gpt_l10n.py` in the repository (read it before a first run; it changes only the `translation` fields of the TODO files).

## 7. Apply and verify

### 7.1 The loop

From the repository root, on a branch (`git switch -c l10n/de-gpt`; pushing a branch named `l10n/…` also runs the Localization export, [§7.3](#73-what-ci-runs)):

```sh
# 0. Start from a current TODO file. If the English changed since it was generated, CI fails anyway until this runs.
python3 tools/l10n/report.py

# 1. Batches, GPT, merge (§6). Then the review pass and the independent review (§5.5, §8.5) on the TODO file.

# 2. Import: checks every filled entry again, merges the good ones into tools/l10n/translations and tools/l10n/learn,
#    applies all tables, regenerates the TODO files, pending.json and HANDOFF.md.
python3 tools/l10n/report.py --import tools/l10n/todo
#    Its two apply steps, run by hand after editing tools/l10n/translations or tools/l10n/learn directly:
#    python3 tools/l10n/apply.py tools/l10n/translations    # interface tables, every locale
#    python3 tools/l10n/apply_learn.py                      # lesson tables, the lesson languages

# 3. Gates
python3 tools/l10n/report.py --check --strict          # the handoff matches the code (CI's core job)
python3 tools/l10n/critical.py --baseline              # no legal, permission or VoiceOver gap beyond the baseline (CI)
python3 tools/l10n/critical.py --write-baseline        # when the previous line says gaps are translated now: shrink it
python3 tools/l10n/critical.py --strict --locales de   # the App Store gate, for the locales you finished
python3 tools/l10n/shipping.py                         # coverage per locale
python3 tools/verify-ios-resources.py                  # 49 tables, every timbre_* key the code uses exists
python3 tools/l10n/xcstrings.py --check                # every table still converts to a String Catalog
python3 tools/l10n/tests/test_store_locales.py          # requirements/mapping only; NOT translation completion
python3 tools/marketing/screenshots.py --check         # current supported listing subset only (§9)
plutil -lint ios/Timbre/Resources/*.lproj/*.strings ios/Timbre/Resources/*.lproj/*.stringsdict   # on a Mac
```

The import prints one line per refused translation ("de Localizable.strings 'Beat %lf': format arguments or ${…} tokens differ from the English: not imported"), then `apply.py` and `apply_learn.py` print what they wrote ("de/Localizable.strings: 784 entries (5 new)", "de: 4614/6080 lesson strings"), then the regenerated counts. Shrink the baseline after every import that translated critical strings: a baseline that still lists a translated gap would let that gap come back unnoticed.

### 7.2 Reading failures

| Message | Cause | Fix |
|---|---|---|
| `format arguments or ${…} tokens differ from the English` (import), `format arguments differ (%lf, %llu and %u included)` (helper) | An argument or token missing, added, of another type, or numbered and plain ones mixed | Correct the text in the TODO entry (`status: rejected`), or send it back to GPT with the message. |
| `the numbers differ from the English` | Lesson: a digit group changed, missing, added, spelled out, or written in full-width or native digits | Keep every digit group as ASCII digits; keep number words as words. |
| `the line breaks differ from the English` | Lesson: a `\n` added or dropped | Same line breaks as the English. |
| `the count of ♯ differs from the English` (or ♭, %) | A sign added, dropped, or written as a word or as `#`/`b` | Signs stay signs; words stay words (German B♭ → B is allowed). |
| `a plural needs a JSON object with at least an "other" form`, `one: format arguments differ from the English` | A plural given as a string, without `other`, or a form without the number | Give the JSON object; keep `%lld` in every form. |
| `plural '…': add it to <locale>.lproj/Localizable.stringsdict by hand` | Normal for a plural that passed | [§7.5](#75-plurals-by-hand). |
| `<locale>/<table>: format mismatch, kept English` (apply.py), `… kept English` (apply_learn.py) | A hand edit to `tools/l10n/translations` or `tools/l10n/learn` that breaks the rules | Fix that JSON file and run the apply script again. |
| `FAILED: the committed handoff is out of date` (`report.py --check --strict`) | The TODO files, `pending.json` or HANDOFF.md weren't regenerated or committed | `python3 tools/l10n/report.py`, commit what it writes. |
| `NEW legal […] '…': de, fr` and `FAILED: … new legal, permission or VoiceOver gaps` (`critical.py --baseline`) | A critical English string without its translations | Translate it, or record the gap deliberately with `--write-baseline`. |
| `FAILED: N legal, permission or VoiceOver gaps in the shipped locales` (`critical.py --strict`) | A shipped locale lacks one of them | Translate, or ship fewer locales ([§7.6](#76-shipping-fewer-locales)). |
| `No string tables for: …` (exit 2) | A wrong code in `--locales` | Use the `.lproj` codes. |
| `AssertionError` at `len(locales) == 49` (verify-ios-resources.py) | A `.lproj` folder was added or removed | Translations never add folders; restore it. |
| The accessibility job fails `testAGermanDeviceWelcomesInGerman` with an expected failure that didn't happen | The German funnel arrived | [§8.2](#82-the-localization-launch-tests). |

### 7.3 What CI runs

- **Every pull request and push to main** (`.github/workflows/ios.yml`, the core job): `report.py --check --strict` (fails when the committed handoff is out of date; publishes fresh TODO files to the `ci-results/core` branch, folder `l10n`), `critical.py --baseline --github` (fails on a new critical gap), and `tools/verify-ios-resources.py`. The accessibility job runs `LocalizationLaunchUITests` with the accessibility audit.
- **Localization export** (`.github/workflows/l10n.yml`, Actions → Localization export → Run workflow, or any push to a branch named `l10n/…`): exports the English from source with Xcode (`xcodebuild -exportLocalizations`), runs `report.py --check --xliff` and `critical.py --xliff` with Xcode's own keys, and publishes `en.xliff`, the handoff files, `report.log`, `critical.log` and `critical-missing.json` to `ci-results/l10n` (a side branch publishes to `ci-results/l10n--<branch name with dashes>`): `git fetch origin ci-results/l10n` and read them from `FETCH_HEAD`.
- **App Store delivery** (`.github/workflows/apple-delivery.yml`): `critical.py --strict` over the shipped locales, after the optional `ship_min_coverage` bar. Only an internal TestFlight build (`internal_testflight_untranslated`) skips it, and that build can't be submitted.

**Expanded completion gate:** keep GitHub Actions translation work scoped to all 49 app languages (English source + 48 targets), all 48 target lesson languages, and a separate all-50 listing queue. The app TODO importer does not import store metadata. A green app translation job, manifest test or existing screenshot check does not prove all listings complete. Track per-locale/per-field drafts, placeholder removal, mechanical validation, independent AI review, native review and device/render review separately; retain failed/pending work for the next run. No App Store account changes or submission are implied by generating or checking translations.

### 7.4 Confirm guessed keys (key_check)

`swiftstrings.py` reads Swift without a compiler and infers each interpolation's type. When it can't be sure, the TODO entry carries `key_check`: the key's `%lld` or `%@` is a guess. Imported under a wrong guess, the translation lands under a key the app never looks up, the entry disappears from the TODO file, `critical.py` counts it as translated, and the app shows English. Before importing such entries:

1. Run the Localization export ([§7.3](#73-what-ci-runs)) and fetch its `en.xliff`.
2. `python3 tools/l10n/report.py --check --xliff en.xliff --out /tmp/handoff`: the entries Xcode keys differently show up with their real keys in `/tmp/handoff/tools/l10n/todo/<locale>.json`.
3. If a key differs, copy the translation to the real key's entry (fix the argument type if it changed), and leave the guessed entry empty.
4. Import, then commit what plain `python3 tools/l10n/report.py` writes (CI runs without the export; once a table holds the real key, the scanner settles on it by itself).

For a release with key_check entries among the critical strings (today: "Then %@. It renews automatically until you cancel in Settings." and "Loop bar %lld"), read the export's `critical.log` before uploading: it is the only gate that uses Xcode's keys.

### 7.5 Plurals by hand

The import checks a plural and prints it, but doesn't write `.stringsdict` files. Add it to `ios/Timbre/Resources/<locale>.lproj/Localizable.stringsdict` in the shape the file already uses (one `dict` per key, a `%#@n@` format and the forms):

```xml
	<key>%lld sessions</key>
	<dict>
		<key>NSStringLocalizedFormatKey</key>
		<string>%#@n@</string>
		<key>n</key>
		<dict>
			<key>NSStringFormatSpecTypeKey</key>
			<string>NSStringPluralRuleType</string>
			<key>NSStringFormatValueTypeKey</key>
			<string>lld</string>
			<key>one</key>
			<string>%lld занятие</string>
			<key>few</key>
			<string>%lld занятия</string>
			<key>many</key>
			<string>%lld занятий</string>
			<key>other</key>
			<string>%lld занятия</string>
		</dict>
	</dict>
```

Escape `&` and `<` as `&amp;` and `&lt;`. Run `plutil -lint` on the file (on a Mac) and `python3 tools/l10n/report.py`; the entry leaves the TODO file.

### 7.6 Shipping fewer locales

Which languages ship is the owner's decision; `tools/l10n/shipping.py` applies it:

```sh
python3 tools/l10n/shipping.py                              # interface and lesson coverage, critical gaps, what ships now
python3 tools/l10n/shipping.py --min 95                     # which locales a 95 % bar keeps (dry run)
python3 tools/l10n/shipping.py --min 95 --critical          # … and only those with every critical string
python3 tools/l10n/shipping.py --min 95 --critical --apply  # write it: then cd ios && xcodegen generate
python3 tools/l10n/shipping.py --all --apply                # ship every locale again
```

`--apply` rewrites `CFBundleLocalizations` of the Timbre target and the `excludes` lines marked `# shipping.py` in each target that copies string tables, so a left-out locale is neither in the build nor listed on the App Store. Its `.lproj` folder and its translation files stay in the repository, and it comes back with the next `--apply` once it clears the bar. Coverage counts the interface (Localizable, plurals, AppShortcuts, InfoPlist), not the lessons.

The delivery workflow's `ship_min_coverage` input applies `--min` to its own checkout for one upload, without `--critical`: a locale above the bar that lacks a critical string still fails that upload. Use `--critical` locally and commit, or translate the critical strings first.

### 7.7 What to commit

One commit per import, with:

- `tools/l10n/todo/*.json`, `tools/l10n/todo/index.json`, `tools/l10n/pending.json`, `docs/l10n/HANDOFF.md`, and `tools/l10n/source/learn-history.json` when it changed (`report.py` writes them);
- `tools/l10n/translations/<locale>.json` and `tools/l10n/learn/<locale>.json` (the delivered translations);
- `ios/Timbre/Resources/<locale>.lproj/*.strings` (and a hand-edited `.stringsdict`);
- `tools/l10n/critical-baseline.json` after `--write-baseline`;
- `docs/l10n/glossary/<locale>.md`;
- `ios/TimbreUITests/LocalizationLaunchUITests.swift` when the German funnel arrived ([§8.2](#82-the-localization-launch-tests));
- `docs/ios/APP-STORE-LISTING-LOCALIZED.md` for listing work.

Not the helper's batches, prompts or answers.

## 8. QA

### 8.1 Pseudo-localization

Before and while translating, pseudo-languages find layout problems that no translation should have to work around:

- **Bounded strings** (automatic): `LocalizationLaunchUITests.testNoTextOnTheWelcomeOrTheTunerBypassesTheStringTables` launches with `-NSSurroundLocalizedStrings YES`, so every looked-up string reads `[# … #]`, and fails on any text of three or more Latin letters outside the brackets on the welcome screen and the tuner (only "Timbre" and "BPM" may be). A text that bypasses the tables stays English in every language whatever the translators do.
- **By hand, in Xcode** (Product › Scheme › Edit Scheme › Run › Options › App Language): *Double-Length Pseudolanguage* shows where German or Finnish will truncate (look at every `one line` label: the tab bar, chips, the paywall's plan cards, the Watch); *Right-to-Left Pseudolanguage* shows layout that doesn't flip; *Accented Pseudolanguage* shows clipped diacritics and line height. Fix layout in code, not by shortening translations below what the language needs.

### 8.2 The localization launch tests

`ios/TimbreUITests/LocalizationLaunchUITests.swift` runs in the accessibility job on every pull request:

- `testAGermanDeviceWelcomesInGerman`: the welcome's button isn't "Get started". The headline ("Tune in seconds.\nThen learn to play.") and its subline ("Timbre listens and tells you exactly how you did.") are funnel strings still waiting; the test wraps their two assertions in `XCTExpectFailure`, which fails the test as soon as the expected failure stops happening. **When the German funnel is imported, unwrap them in the same pull request** (lines 56–63 today: delete the comment, the `waiting` line and the `XCTExpectFailure` around the two `XCTAssertFalse` lines, and keep those two lines, which guard the German welcome from then on), or the accessibility job fails.
- `testAGermanDeviceNamesTheTabsInGerman` pins the German tab names "Stimmen", "Lernen", "Fortschritt"; `testAnArabicDeviceRunsRightToLeft` pins the Arabic "ضبط" (Tune) and "التقدّم" (Progress) and checks the tab bar flips; `LocalizationTests` (unit tests) pins the German "Get started" as "Los geht's". Changing any of those translations means changing the test with it.
- `testAnArabicTunerKeepsTheOctaveRightOfTheNote`: the tuner's note reads "E₂", not "₂E", in Arabic.

### 8.3 Screenshots in the language

The UI tour takes its pictures in any language:

```sh
TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE xcodebuild test -project ios/Timbre.xcodeproj -scheme Timbre \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" -only-testing:TimbreUITests/TimbreUITests -resultBundlePath /tmp/de.xcresult
xcrun xcresulttool export attachments --path /tmp/de.xcresult --output-path /tmp/de-captures
```

(`TimbreUITests` launches the app with `-AppleLanguages (de) -AppleLocale de_DE` from those variables; use any installed simulator.) Review the captures for truncation, overlaps, wrong direction (ar, he, fa, ur) and English left over, screen by screen against the English captures on `ci-results/app`. Chord completion and results-frame checks now use locale-independent state identifiers while preserving localized spoken labels; the chord check requires all six individual strings and cannot pass on an empty set. The focused `localized-capture-check.yml` workflow requests English, German and Arabic checks for `52b-lesson-chord` and `62b-lesson-results-violin`. These are limited capture checks, not all-locales/all-assets certification. Other tour selectors and iPad setup still need localized verification, and any `-wrong` frame remains unusable by `screenshots.py` ([§10](#10-traps-the-tooling-doesnt-catch)).

### 8.4 Reading it in the app

Reviewers read on a phone: an internal TestFlight build carries every translation imported so far (the delivery workflow's `internal_testflight_untranslated` input skips the critical gate for internal testers only). In the app, Settings › Language › App language switches the language without changing the phone's. A reviewer goes through the onboarding, the paywall (both plans, the trial terms), the tuner with VoiceOver on, one lesson per course, a song with the band, Practice, Progress, Settings, a widget and the Watch.

### 8.5 Human review

The owner selected independent AI semantic review for this translation effort in place of human review. Use a separate review context from the drafting pass, compare against English and the glossary, and record corrections and actual evidence. This is not native-speaker certification, a market-search study, legal advice, blinded back-translation, or device QA. Those checks remain separate and must never be marked completed without evidence. Human review by a musician remains recommended before broad release. The review sample below applies to the selected reviewer; app/device checks still require actual rendering. Corrections go into the TODO file's `translation` before the import (preferred), or afterwards into `tools/l10n/translations/<locale>.json` (a key that isn't there yet can be added: `apply.py` replaces the table's line) or `tools/l10n/learn/<locale>.json`, followed by `python3 tools/l10n/apply.py tools/l10n/translations` or `python3 tools/l10n/apply_learn.py`, then `python3 tools/l10n/report.py`.

| What | Review |
|---|---|
| Glossary | 100 %, before the first batch |
| Legal and permission strings | 100 %, plus the back-translation check (§8.7) |
| Funnel (onboarding to paywall), the paywall, Siri phrases | 100 % |
| VoiceOver | 100 % in the 9 major locales, read with VoiceOver on; 30 % elsewhere |
| Every `WARN` of the helper and every GPT `note` | 100 % |
| Rest of the interface | 20 % in the 9 major locales, 10 % elsewhere, picked at random, plus every string with a `layout` |
| Lessons | One whole lesson per unit read in the app, plus 10 % at random; every song title against the glossary |
| Store listing | 100 % under the explicit store text-review policy (§9.1); human/market review is optional under owner-selected AI mode |

When a sample finds more than 2 % substantive errors (meaning, a glossary term, register, a fact), review all strings of that kind for the locale, and fix the cause in the glossary or the prompt before the next batch.

### 8.6 Terminology consistency pass

After each import, list the strings whose English uses a glossary term but whose translation doesn't use the glossary's translation (the shipped tables, the filled TODO entries and the lesson translations). It reads the glossary's **App key** and **Translation** columns and compares a stem, so it is a list for a reviewer, not a gate; a word with several senses (Tune) lists many false hits. Run from the repository root:

```sh
python3 - de docs/l10n/glossary/de.md <<'EOF'
import re, sys, json
sys.path.insert(0, "tools/l10n")
import report
loc, glossary = sys.argv[1], sys.argv[2]
table = report.read_strings(report.RES / f"{loc}.lproj/Localizable.strings")
pairs = dict(table)                                   # shipped: English key -> translation
for line in open(f"tools/l10n/todo/{loc}.json", encoding="utf-8"):
    if line.startswith("  {"):
        item = json.loads(line.strip().rstrip(","))
        if isinstance(item.get("translation"), str) and item["translation"]:
            pairs[item["source"]] = item["translation"]   # filled, not imported yet
learn = report.read_strings(report.RES / "en.lproj/Learn.strings")
from pathlib import Path
learn_path = Path(f"tools/l10n/learn/{loc}.json")
done = json.loads(learn_path.read_text(encoding="utf-8")) if learn_path.exists() else {}
pairs.update({learn[k]: v for k, v in done.items() if k in learn})
for line in open(glossary, encoding="utf-8"):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 5 or not cells[3].startswith("`") or cells[4] in ("", "—"):
        continue
    want = cells[4].split(" / ")[0].split(";")[0].strip()
    stem = want.casefold()[:max(4, len(want) - 2)]
    for key in re.findall(r"`([^`]+)`", cells[3]):
        if "%" in key:
            continue
        hits = [(e, t) for e, t in pairs.items() if not e.startswith("timbre_")
                and re.search(rf"(?<!\w){re.escape(key)}(?!\w)", e, re.I)]
        off = [(e, t) for e, t in hits if stem not in t.casefold()]
        if off:
            print(f"\n{key!r} -> {want!r}: {len(off)} of {len(hits)} strings don't use it")
            for e, t in off[:8]:
                print(f"    {e[:70]!r} -> {t[:70]!r}")
EOF
```

### 8.7 Legal back-translation

For the 11 legal strings and the permission prompts of each locale, a separate GPT conversation translates the translation back into English, without seeing the original; compare the facts (renewal, the cancellation window, where to cancel, what stays free, the trial, what is recorded). Any difference is fixed before the import.

## 9. The App Store listing

**Required scope: every Apple-supported listing locale, currently 50 including `en-US`.** The authoritative inventory is [store-locales.json](../../tools/l10n/store-locales.json), verified on 2026-10-26 against [Apple’s supported languages](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations) and [Apple’s API shortcodes](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes). Listing scope does not change the 49 app languages or all-49 lesson requirement (§2.2).

The English source remains `docs/ios/APP-STORE-LISTING.md`. All 50 machine-readable listing payloads are in `tools/l10n/store/<Apple-locale>.json`, including its `en-US` snapshot. [APP-STORE-LISTING-LOCALIZED.md](../ios/APP-STORE-LISTING-LOCALIZED.md) documents their evidence and release gates; old nine-locale Markdown blocks are no longer the translation deliverable. Each payload includes name, subtitle, keywords, promotional text, description, What's New, 13 iPhone/iPad caption pairs, both App Preview cuts, three IAP names/descriptions, 12 Game Center boards and 31 achievement name/description pairs.

### 9.1 Review policy and evidence

The owner explicitly elected source-aware AI review instead of mandatory human text sign-off. `store-review.json` records `review_policy.mode: ai_source_aware`; absent an explicit selection, the validator defaults to the conservative `human` policy. All 50 full payloads have independent source-aware AI review, and the original 94 corrections, 2 Slovenian morphology corrections and 157 later independently reviewed Game Center title-alignment corrections (253 total) were applied with exact-old guards and matched the reviewers’ proposed hashes. The title-only addendum preserves the earlier full-payload review with per-locale parent-hash lineage; see `docs/l10n/reviews/store-title-alignment/`. Named reviewer/method, current-payload hashes, exact source hash/version/counts, correction resolution, the 50-locale inventory and hash-bound original evidence artifacts are checked mechanically.

AI review is **not** native-speaker certification, blinded legal back-translation, legal compliance certification, measured keyword popularity or device/account/visual verification. The native, market and legal-review states stay unverified or unperformed. Those additional text reviews are optional under the owner-selected AI policy, not silently marked passed. The historical human-only store requirements elsewhere in this manual are superseded for store text by this explicit policy.

A new import, source change or `--sync-game-center` operation that changes payloads invalidates their AI review hashes. Independently review the changed text and resolve findings before updating evidence; never simply regenerate hashes to claim a review occurred.

```sh
python3 tools/l10n/store.py                    # all 50 payloads + current AI evidence
python3 tools/l10n/store.py --sync-manifest    # record factual validation, never release approval
python3 tools/l10n/store.py --release          # still fails for missing real release evidence
python3 tools/l10n/store.py --release --review-policy human # audit conservative policy
python3 tools/marketing/screenshots.py --check
```

### 9.2 Fields, counts and limits

`store.py` validates all 50 locales, and `screenshots.py --check` invokes that validator. NFC code-point limits are name/subtitle 30, keywords 100, promotional text 170, description/What's New 4,000, screenshot headlines 30 (design constraint), IAP names 2–30 and descriptions 45, Game Center titles 100 and descriptions 500 (actual account verification still required). Capture order, preview clip IDs, all product/achievement IDs, missing text, unresolved translation/count markers, required source counts and unsupported numeric claims are checked.

Use the source’s count variables (`{instruments}`, `{tunings}`, `{courses}`, `{lessons}`, `{songs_floor}`, `{originals}`) and current build values while authoring. Store JSON contains resolved values, never stale counts or unresolved variables. Empty strings, `TRANSLATE:` or copied-English fallback do not satisfy translation coverage. English regional variants deliberately share reviewed source wording, not missing-language fallback. The standard EULA URL is unchanged in every locale.

`<privacy policy URL>` remains explicit during drafting. It is a **release blocker**, not a translation omission to disguise. Replace it only with the verified production URL, update the English source and snapshot consistently, and renew review evidence for changed payloads.

### 9.3 Keywords and regional wording

Keywords are comma-separated, at most 100 characters, without spaces beside commas or duplicate terms. The validator rejects name/subtitle repetitions except explicitly mapped Custom Product Page terms, and verifies that assigned page terms belong to the field and to one page only. It cannot prove search popularity, idiom, competitor/trademark suitability or regional search behavior. The current AI-reviewed candidates are not measured market findings; market ASO research is optional and unperformed under the selected policy.

Keep descriptions equivalent to the source: distinguish 60-instrument tuning from the limited teaching-course scope, include 50 Originals within 140+ songs, preserve every free-tier condition, the notification-conditioned two-day trial reminder, on-device audio that is never recorded/uploaded, automatic renewal, the 24-hour cancellation window and anytime subscription management. Use glossary and app terms without implying app UI support for listing-only Malay, Odia or Traditional Chinese. Never claim a language count as completed merely because locale files exist.

### 9.4 Screenshots and App Preview

The renderers read locale JSON, retaining original capture/clip inventory and visual looks. Render localized screenshots with `python3 tools/marketing/screenshots.py <captures> <out> --locale de-DE` (plus `--ipad` for iPad); use `preview.py render --out <recording-folder> --locale de-DE` for recorded previews. Matching localized captures/recordings and glyph-capable fonts are required. Metadata does not translate pixels, prove RTL shaping or create a finished video. Inspect truncation, overlap, search-size legibility, audio and synchronization. Custom Product Page asset sets are separate from the 13 default caption pairs.

### 9.5 IAP, Game Center and mandatory release gates

Reuse matching app badge and song-title translations where available. Run `store.py --sync-game-center` only after app imports, then review every changed payload; do not independently rename localized song titles away from `Learn.strings`. Listing-only languages use reviewed store text without claiming app UI support. Review notes stay English.

Regardless of text-review policy, release requires a verified HTTPS production privacy URL present in each description, real localized device/glyph/RTL/layout checks, screenshot capture/render review, localized preview recording/audio/render evidence, actual App Store Connect IAP localization/product limits and Game Center configuration/images. Verified statuses must have evidence references bound to the current payload. Structural/numeric gates and English-source integrity remain mandatory. All current listings remain `release_ready: false`; text completion and a green draft gate do not authorize upload, account changes or submission.

## 10. Traps the tooling doesn't catch

What can still go wrong after every check above passes, and what to do about it:

1. *(Fixed 2026-10-25: the import now checks `%lf`, `%llu` and `%u` arguments too.)*
2. **Guessed keys** (`key_check`): a wrong guess imports silently and `critical.py` counts the string as translated ([§7.4](#74-confirm-guessed-keys-key_check)).
3. **Plurals aren't applied by the import** ([§7.5](#75-plurals-by-hand)), and the import refuses a `one` form without the number although the English has one.
4. **Interface line breaks, length, register, terminology and meaning** are not checked by the import; the helper warns on the first two, the review catches the rest.
5. **The German funnel** turns `testAGermanDeviceWelcomesInGerman` red until its `XCTExpectFailure` wrapper is removed ([§8.2](#82-the-localization-launch-tests)).
6. **Localized store frames #3 and #7** come out `-wrong` in a localized capture run, because their checks read English text (`ios/TimbreUITests/TimbreUITests.swift`, the comment on `language`): a full localized set can't be rendered until those checks read identifiers.
7. **Wrong terms in the shipped tables**, which the anchors and `refs` may show GPT: "Intonation" (the drone trainer) is translated as the guitar-setup adjustment in ca (Octavació), es (Octavación), ja (オクターブ調整), pt (Oitavado) and zh-CN (八度音准); the register is mixed in he, hr, ro, sl and tr; "Bullseye" is translated everywhere although HANDOFF.md says to keep game names. The glossary overrules the tables; a clean-up batch for those keys means editing `tools/l10n/translations/<locale>.json` and running `apply.py`, since they aren't in the TODO files.
8. **Shared keys**: "Next", "Again" and "Slower" are on-screen labels and Siri's command words; one translation has to serve both ([§4.14](#414-grammar-around-arguments)).
9. **Store semantic and visual quality** cannot be proven by the all-50 text validator. Current-payload/source hashes protect independent AI review evidence from silently going stale; actual localized assets, device checks, production privacy and account configuration remain separate release gates (§9).
10. **`ship_min_coverage`** in the delivery workflow doesn't require the critical strings: a locale above the bar without them fails the upload instead of being left out ([§7.6](#76-shipping-fewer-locales)).


### Shared answer contexts (26 October 2026)

New `gpt_l10n.py split` batches include `answer_contexts` for lesson answer keys: every distinct current prompt/explanation, total occurrences and example lesson IDs. Translate a shared answer for **all** listed uses, not only the first TODO context. Bare Up/Down have 41 uses each, including mandolin picking strokes as well as pitch movement; neutral direction wording avoids a past-tense pitch-only error. One beat has eight uses across duration/count/missing-beat questions. When no target can serve every context, hold the key and request a bounded source-reference repair instead of silently changing quiz semantics.

Frozen batches created earlier remain valid historical artifacts; do not overwrite them mid-review. Reviewers can call `gpt_l10n.option_contexts(repo)` against the current integration source to inspect all current answer contexts. This context enrichment does not approve translations, rewrite TODO metadata, or waive independent review.

### Verified source clarifications

New batches also include `source_clarification` for a small set of ambiguous English
instructions. These distinguish under-bent pitch from short duration, horizontal
violin posture from floor height, fretting from plucking, and a whole1700s century
from its first decade. `tools/l10n/source-clarifications.json` binds each note to its
exact English hash and complete current curriculum context hashes. A changed sound,
answer, instruction or context fails closed until the note is rechecked. The note is
reference metadata, not text to copy into the translation and not review approval.
Preserve source numeric tokens; do not copy explanatory MIDI/example numbers from
metadata into a target that did not contain them.

### Repeated text outside quiz choices

`shared_lesson_contexts` includes distinct non-option title/body roles as well as
quiz roles. It deduplicates identical semantic text contexts, preserves counts and
example locations, and excludes large music arrays. Do not assume a shared title
has the same meaning everywhere: song-form bridge versus physical instrument bridge
and chord qualities versus interval sizes now have explicit source keys. Known
historical draft versions remain verifiable through exact source migrations; no
arbitrary missing-key waiver or copied-English completion is introduced.
