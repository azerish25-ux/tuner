# Applied lesson context split — 2026-10-26

**Applied and statically verified; not release approval.** The source now has
6,082 lesson keys. Seventeen target locales each bundle all 6,082 current keys:
`ar bn de es fa fr gu hi it ja kn ko pt ru ta ur zh-CN`.

## What changed

- Exactly two authoring lines: the ukulele distractor becomes
  `Strings: 1, 2, 3 and 4`; the musical section becomes `Middle section`.
- Exactly seven generated localized objects change: one quiz option and six
  arrangement section labels. Every other curriculum field, answer, pattern,
  note, array order and type is unchanged. The retained keys now mean only a
  spoken rhythm count and a middle finger respectively.
- The separate independent AI delta review supplies **34 additions, six exact
  rhythm-count replacements and 28 no-op retains** across 17 locales.
- Gujarati, Tamil and Kannada import their independently reviewed 6,080-pair
  baselines: 311/109/198 applied corrections respectively, plus 310/309/304
  individually source-bound invariant decisions. The Gujarati ledger's one
  additional correction (`મધ્યમા` → `મધ્ય`) is superseded, not applied: the
  precise finger name `મધ્યમા` remains; the section is `વચ્ચેનો ભાગ`.
- The three glossaries incorporate reviewed lesson terminology. Gujarati's
  three exact fragment changes are applied once. Previously reviewed UI haptic
  wording is preserved. No UI or store resource is changed by this integration.
- Historical stale map entries are preserved, but only current English keys
  enter bundled Learn tables. Structural counts remain **19 courses / 1,100
  lessons**; the actual marketing helper remains **11 courses / 526 lessons**.

## Evidence and reproduction

The applied evidence is in [`tools/l10n/context-split`](../../../tools/l10n/context-split/):

- `checked-manifest.json`, the two checked main-operation/retain files, and
  `addendum.json`: all exact source/old/new hashes, absence guards, before/after
  full-context signatures and semantic decisions. The original supplement name
  `unified-ta-gu-kn-addendum.json` is retained as provenance metadata; its public
  copy here is `addendum.json`.
- `checked-contexts.json` and `generated-context-diff.json`: full enclosing quiz
  and section evidence, not just pointers. Answer/pattern changes invalidate
  the signatures.
- `integration.json`: actual applied map-content digests, baseline correction
  and invariant counts, unchanged-data evidence and raw review artifact hashes.
- `glossary-integration.json`, `validation.json`, `icu-evidence.json`: exact
  glossary lineage, observed local checks and 26 reproduced ICU diagnostics.

```sh
python3 tools/l10n/context_split.py
python3 -m unittest discover -s tools/l10n/tests -p 'test_*.py'
python3 tools/curriculum/build.py --check
python3 tools/verify-ios-resources.py
python3 tools/l10n/report.py --check --strict
python3 tools/l10n/critical.py --strict
python3 tools/l10n/lessons.py
python3 tools/l10n/staged/verify.py
```

The read-only integration verifier reconstructs the prior curriculum and prior
locale maps, checks exact hashes, rejects unrelated changes, and verifies actual
bundled values and narrow invariant registrations. Seventeen migration tests
include wrong locale/table/source/old/target, preexisting addition, altered
answer/pattern/count/pointer/context, and mutually exclusive Gujarati branches.
No fuzzy substitutions, null old-value waivers or blanket identity approvals
were used. The original Urdu reviewed map was verified against the live map
before applying its three mutations.

Review artifacts retain their historical “not applied” status; **integration.json
and validation.json record the later actual application**. Machine-private paths
and reviewer identifiers are replaced with repository paths or public role/input
labels. Original raw hashes are provenance, not hashes of normalized formatting.
The [frozen staged checkpoint](../staged/README.md), including its manifest,
remains unchanged and still verifies: it is historical 6,080-key evidence, not a
new blanket certification of the 6,082-key source.

## Remaining gates

- The 31 other locales still lack **188,542 lesson pairs**, including the 62 new
  context-split pairs. `lessons.py --strict` correctly fails; report-only coverage
  and strict handoff consistency pass. No full-localization claim is made.
- Kannada `L8a28d3c1df` remains 46/42 code points and `Lb1a60a5698` 44/42. All four
  finger slots are retained; actual layout review remains required.
- Swift/Xcode tests could not run here: `swift` is not installed (exit 127).
  iOS builds, actual RTL rendering, font shaping, Dynamic Type, audio and
  VoiceOver checks remain pending. ICU output is codepoint-order diagnostics,
  not device or accessibility proof. No new directional controls were inserted;
  Persian ZWNJ is preserved.
- Baseline and delta reviews are independent **AI** reviews, not native-human
  certification or App Store delivery authorization.

## Source-observation clarification

The earlier question about `rhy-2-2` comparing its quiz answer to the preceding tap
is resolved by the quiz's own visual: `[0, 0.5, 1, 2, 3]` matches answer 2 and its
explanation. The preceding `[0, 1, 1.5, 2, 3]` exercise is intentionally different.
No answer index, visual rhythm or tap pattern was changed by this migration.
