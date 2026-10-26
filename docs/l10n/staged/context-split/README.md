# Pending two-key context split

**Checkpoint only — not applied.** Publishing these artifacts does not apply a
source patch, import translations, approve a release, or certify native-language
or device quality. All existing 6,080 source keys remain the live baseline.

## Proposed change

- `Strings: 1, 2, 3 and 4` (`Lf94a998e29`) separates one ukulele string-list
  distractor from the retained rhythm-count key `Lf6586312d9`.
- `Middle section` (`L4f162aedb4`) separates six musical-section labels from
  the retained banjo-finger key `Lced02810fc` (three finger contexts).

The byte-exact `source-authoring.patch` changes two source lines. The byte-exact
`generated-english.patch` records the expected two English additions. The
isolated-build evidence found only seven changed localized objects, with all
other curriculum fields and marketing counts unchanged. This is historical
build evidence, not a current CI or release pass.

## Canonical evidence

- `source-guards.json`, `retained-source-guards.json`, `input-manifest.json`:
  exact baseline file, source and old-value guards.
- `affected-contexts.json`, `context-signatures.json`,
  `generated-context-diff.json`: before/after context binding.
- `locale-guarded-operations.json`: 31 main proposed mutations, preserving
  exact source/key/old/new values and their original hashes.
- `locale-baselines-and-retentions.json`: original locale baseline metadata and
  unchanged-key decisions; repeated mutation payloads are replaced by references
  to the canonical guarded operations.
- `locale-evidence.json`, `retained-count-display-evidence.json`,
  `rtl-evidence.json`: glossary, neighbor and RTL diagnostics.
- Tamil and Kannada supplements: Independent AI review proposals, including
  exact guards; neither native-human nor whole-migrated-baseline approval.
- `migration-plan.json`: ordered integration gates. Its historical authorization
  section describes the preparation phase; current checkpoint publication is
  distinct from applying the proposal.
- `verification.json`: original isolated-build/mechanical evidence.
- `checkpoint-summary.json`: current combined checkpoint status and new counts.

Including the later Tamil and Kannada supplements, **32 of the 96 required new
locale/key pairs have proposals**, across 16 locales. The other **64 pairs across
32 locales are unsupplied**; Gujarati has no new-key values in this bundle.
The older preparation evidence predates the Kannada supplements, so its original
28-main/30-with-Tamil counts are historical, not the combined checkpoint total.

## Still required

Reconcile every proposal with the final composed locale baseline; recheck exact
source/target/context guards; complete independent migration review and missing
translations; then run the separately approved source/build/import workflow and
full 6,082-key gates. Check actual iOS layout, RTL and VoiceOver behavior. Never
apply a retained-key correction before its contexts have been narrowed, and
never treat a frozen 6,080-key review as full review of the 6,082-key baseline.

Checkpoint validation passed: patch applicability **without applying it**; exact
source-file and unique-old-line guards; computed proposed-file hashes; all 38
main/supplemental operation records' supplied source/old/new hashes; and absence
of both new keys from live English. No denied operation was bypassed.

The file manifest hashes every staged artifact except itself. It also records
original artifact hashes where applicable. Private machine locations and reviewer
identifiers were replaced by public relative paths or descriptive artifact labels;
translation values and guards were not rewritten. No raw build logs, prompts,
source mirrors or duplicated proposal dumps are included.
