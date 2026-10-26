# Localization work checkpoint — 2026-10-26

This is a **preserved review checkpoint, not a release-completion claim**. It keeps
full frozen author translations, safely composed reviewed candidates, exact
correction guards, source-bound invariant decisions, and unresolved work in Git.
No live resource or registry is changed by reading or verifying this package.

## Four complete reviewed baselines

| Locale | Frozen keys | Guarded corrections | Exact invariant decisions | Integration at checkpoint |
|---|---:|---:|---:|---|
| Urdu (`ur`) | 6,080 | 186 | 305 | Reviewed 6,080-key baseline imported locally; publication and context delta pending |
| Gujarati (`gu`) | 6,080 | 312 | 310 | Not imported |
| Tamil (`ta`) | 6,080 | 109 | 309 | Not imported |
| Kannada (`kn`) | 6,080 | 198 | 304 | Not imported |

Every locale's 59 batches received **Independent AI semantic review of all
6,080 pairs**, not just a sample. This is not native-human certification, device
rendering, audio performance testing, or release approval. Per-key review
provenance is public and accurately labeled; private reviewer identifiers are
not needed to reproduce the checks.

## Bounded partial drafts captured at 04:50:18 UTC

Already-finished Malayalam (`ml`), Marathi (`mr`) and Punjabi (`pa`) draft
outputs and nonempty author TODO values are also preserved under
`tools/l10n/staged/partial/`. These are **unreviewed partial drafts**, not reviewed
candidates or completed locales. Work after this timestamp is outside this
bounded checkpoint.

| Locale | Nonempty TODO values captured | Unique draft keys preserved | Unapproved identity candidates |
|---|---:|---:|---:|
| Malayalam | 298 | 313 | 15 |
| Marathi | 546 | 577 | 31 |
| Punjabi | 399 | 418 | 19 |

Each capture includes exact source/translation hashes, finished input hashes,
origin labels and author notes. Conflicting versions are retained, not silently
chosen: Marathi `Le060c1abc6` has multiple captured draft variants. No partial
translation is imported or independently approved. Explicit author identity
holds and other source-identical outputs remain candidates for semantic review,
never new registry approvals. No unfinished batch, prompt or log is included.

## Canonical data and exact author reconstruction

The data lives in [`tools/l10n/staged`](../../../tools/l10n/staged/):

- `source-catalog.json` stores each exact source/key, source SHA-256, batch/id,
  original context/layout metadata, and exact keyed curriculum pointers once.
- `<locale>/candidate.json` is the complete 6,080-key reviewed translation table.
  It overlays only the original guarded correction ledger. It **does not apply
  the separate source-context migration** and is not a blind-import instruction.
- `<locale>/corrections.json` preserves exact locale/table/key/source/old/new,
  reasons, source/old/new hashes, and any original additional file guards.
- To reconstruct the frozen author translation table, copy `candidate.json`,
  then replace each corrected key with that ledger row's exact `old` value.
  Every uncorrected author value equals the candidate value. This avoids storing
  duplicate full tables without discarding original text.
- `<locale>/coverage.json` covers every key with author/candidate hashes,
  original review disposition, and checkpoint integration/hold status.
- `<locale>/invariants.json` preserves narrowly source-bound decisions and
  reasons. These records do not themselves install or broaden an allowlist.
- `<locale>/baseline.json` pins original author batch source/map/output byte
  hashes, author/review manifest hashes, and independently reproducible complete
  author/candidate content digests. Original raw files are consolidated, not
  copied; an original byte hash is provenance, not a claim that identical raw
  formatting is stored here.
- `author-notes.json` and `source-refs.json` preserve nonempty author notes and
  locale-specific source reference text. Combine the shared catalog with these
  per-key reference values to recover the original translation input content.
- `status.json` records scoped status, explicitly separating archive creation
  from separately performed live integration work.

Correction `old` guards bind the **frozen author draft**, not a currently empty
TODO field or a later edited live translation. Verify every guard before a later
integration. Never fuzzy-match text or silently treat the current TODO as the
frozen author baseline.

## Open gates — do not bypass

1. **Two mixed-context keys**: `Lf6586312d9` (`1, 2, 3 and 4`) is both an
   instrument string list and a spoken rhythm distractor; `Lced02810fc`
   (`Middle`) is both a finger and a song-section label. Retain the original
   baseline in this archive; do not apply conditional retained-key changes
   before the exact context split. Neutral wording proposed for some locales
   does not establish all-locale migration approval.
2. **Kannada layout**: `L8a28d3c1df` preserves all four finger slots at 46/42
   code points; `Lb1a60a5698` is 44/42. Actual UI layout review remains pending;
   no finger was removed or shortened to conceal the warning.
3. **Invariant integration**: Gujarati, Tamil and Kannada recommendations are
   not installed. Genuine original titles, notation, credits and sung-word
   examples are individually justified, never generic English-prose waivers.
4. **Glossary changes**: author glossaries and independent recommendations are
   preserved under each locale. Gujarati's three coordinated old/new fragments
   are deduplicated in `gu/glossary-corrections.json`; apply one guarded set,
   not both historical partition copies. They are not applied to the preserved
   author glossary. Kannada and Tamil guidance is also still staged.
5. **Blind backtranslation comparison** is pending. The complete 1,104-row
   backtranslation result is evidence for a later source comparison, not a
   passed translation-quality gate.

## Review evidence

The `ur/`, `gu/`, `ta/`, and `kn/` directories retain focused semantic/context,
lyric/mnemonic, warning, layout and validation evidence. Urdu includes contextual
ICU Unicode-order before/after results; that does not prove iOS glyph shaping.
Tamil includes the isolated wrong-batch QA-assignment finding and neighbor audit.
Historical review evidence describes the time it was produced. Its statements
that no import had occurred must not override the newer integration table above.

- [Two-key source split](context-split/README.md): exact authoring/generated
  patches, source/context/old-value guards, migration plan and locale proposals;
  **not applied**. The full expanded baseline will contain 6,082 keys and needs
  separate migrated-baseline review.
- [Blind backtranslation](blind-backtranslation/README.md): complete outputs,
  evidence and source mapping; **comparison pending**.
- `checkpoint-validation.json`: new read-only mechanical checks against all
  24,320 candidate pairs, using proposed exact invariants **in memory only**.
  No hard/protected-token errors; expected identity/RTL notices remain visible,
  plus the two unresolved Kannada layout warnings.

Raw download/tool logs, duplicate source mirrors, internal prompts and private
machine paths are intentionally excluded. Full surrounding source remains in
repository curriculum files; the checkpoint pins its source baseline hashes and
exact pointers rather than duplicating multi-megabyte curriculum dumps.

## Verify without importing

```sh
python3 tools/l10n/staged/verify.py
```

This checks all JSON, 6,080 source bindings, all four full key sets, author
reconstruction, correction/invariant guards, content hashes, public-path hygiene,
and the complete file manifest. The archive can be verified after live source
changes; it is a frozen baseline, not an assertion of current app completeness.
Use the repository's full localization, source-build and device gates again
before a later release. `artifact-manifest.json` lists every checkpoint file,
byte size and SHA-256, excluding only itself.
