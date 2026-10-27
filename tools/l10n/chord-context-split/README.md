# Chord versus key/scale source repair

Status: prepared source correction, **not a translation approval or release-ready migration**.

The original English deduplication merged eight labels used for different musical concepts. In particular, the Traditional Chinese words for a major chord (大和弦) and a major key (大調) cannot safely share one target. Adjacent-context review found the same issue for B♭ major beyond the original seven flagged labels.

## Bounded source change

- Exact base: `0b89f9ba4913bf5910302c059b30ce1aa1a59cc4`.
- Both base and proposal contain 19 courses and 1,100 lessons. A pristine rebuild of the base authoring modules reproduced both committed generated files byte for byte.
- Exactly 26 localized `{k,t}` objects change. Lesson IDs, order, quiz answers, MIDI/audio, patterns, diagrams, arrangements, timings and every other nonlocalized value remain unchanged.
- All 6,083 old English key/text pairs remain unchanged. Seven new keys make 6,090 total.
- Six new explicit major-chord labels: A, C, G, D, F and B♭. Their old bare major labels remain solely in key/scale contexts.
- A minor remains a chord label; the violin `vln-5-3` lesson title reuses the existing **A minor scale** key.
- E minor remains a chord label; one incorrect mode distractor uses the new **E minor scale** key. The correct answer remains A Dorian.
- The English title/option limits still pass the curriculum validator.

## Evidence and review contract

- `changes.json`: exact before/after localized objects and pointers.
- `contexts.json`: complete linked lesson/quiz contexts before and after, including quiz options and answers.
- `manifest.json`: exact source hashes and unchanged-content reconstruction guards.
- `pending-addendum.json`: **816 pending source-context rows** across 51 target languages. Each target has seven new translations and nine retained/reused-context reviews. Null translations/reviewer names are intentionally unresolved. The three new app languages have no shipping baseline map yet; bind their accepted outside draft before reviewing an addendum.
- `zh-Hant-draft-addendum.json`: a proposed 16-row Traditional Chinese addendum. It is explicitly **not independently reviewed**.

Do not relabel the 816 pending rows as reviewed automatically, copy existing bare-label targets into new keys without checking their musical meaning, or create English fallback copies. Do not overwrite immutable prior reviews. Preserve all unaffected accepted targets and attach the reviewed, source-bound addendum separately. For Traditional Chinese, 6,074 unchanged lesson rows retain their prior review; the 16 addendum rows require a fresh independent review (including the newly identified B♭ collision and the reused A minor scale context).

Before release integration:

1. Independently review the English source/context correction and the Traditional Chinese draft against the exact contexts.
2. Author and independently review all 51 target-language addenda. Check the old bare major/minor translations against their now-unambiguous contexts; unchanged English text does not automatically preserve a prior mixed-context approval.
3. Apply exact-old/absent-key guarded target changes to lesson maps and generated bundles, retain legitimate per-key identity approvals only where their context remains valid, and regenerate TODO/handoff data without rewriting frozen review inputs.
4. Run `python tools/l10n/chord_context_split.py`, full localization tests, curriculum validation, strict lesson coverage and the normal release checks. A source-only verification intentionally returns `release_ready: false`.
5. Capture and review affected Learn lesson titles and quiz options natively, including maximum Dynamic Type, RTL, Traditional Chinese, Odia and Malay. No native pass is supplied by this package.

No production translation maps or non-English bundles are changed by the source preparation package. Applying it alone would create seven missing targets in every existing non-English app language and must not be treated as submission-ready.
