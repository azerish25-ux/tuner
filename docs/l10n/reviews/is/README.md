# Icelandic independent lesson text review

All **6,083** frozen source/target pairs were displayed and independently read in
order. Truncated output sections were explicitly reread. The complete author draft
is preserved unchanged at `tools/l10n/drafts/final/is.json`; its exact Git-byte
SHA-256 is bound in `summary.json`. No live language table was imported by this
reviewer.

The working final map is `candidate-map.json`: **84** exact source/old/new guarded
corrections and **317** individual source-bound unchanged-string decisions. The
extra identity compared with the author's 316 candidates is the corrected genre
label `Neo-soul`. All current helper checks pass for the effective map after those
individual decisions: zero structural errors and zero non-identity warnings.

`coverage.json` records every primary pair and its source, old-target and final
target hashes. `targeted-contexts.json` and `context-coverage.json` record **160**
deduplicated shared-answer prompt/explanation associations actually read, covering
ordinal/finger versus interval labels, shared direction/stroke words, beat counts,
duration answers, first/second examples, cadences, chord qualities and other
ambiguous choices. All **10** guarded source clarifications were separately checked.
This does **not** claim that every one of the helper's 1,545 complete semantic
bundles was separately redisplayed. The complete primary reading and targeted
context reading together are the review scope; the all-helper-context flag remains
false rather than disguising that distinction.

## Corrections

- Sixty physical piano-key references use musical **nóta**, with gender/case
  changes, instead of the literal `lykill` calque. Legitimate clef names
  **G-lykill / F-lykill** remain unchanged. Usage was checked against the
  [University of Iceland Science Web](https://www.visindavefur.is/svar.php?id=2874)
  and [Icelandic music teaching material](https://kokomo.is/tonfraedi).
- Shared fifth-string quiz choices use standalone nominative labels; one label
  serves both a where-from question and a what-does-the-thumb-play question.
- Artificial finger picks stay distinct from natural fingernails in the
  clawhammer distractor. Choking a reggae chord releases fretting pressure rather
  than directing the learner to lift fingers clear of the strings.
- Idiomatic perception wording replaces passive English-feels calques. Two
  counted-onset instructions quote the precise spoken count cue. Other changes
  correct a mass-noun construction and an ungrammatical question metaphor.
- Grieg's work uses **Í höll Dofrakonungs**, the established
  [Iceland Symphony Orchestra title](https://www.sinfonia.is/tonleikar-og-midasala/tonleikar-i-reykjanesbae).
  **Neo-soul** retains its established genre label, also found in
  [RÚV music programming](https://spilari.nyr.ruv.is/utvarp/spila/sudupottur/39086/bko37s).

`glossary-supplement.md` lists the coordinated translated Timbre Original titles
and the new terminology decisions. Integration should append it to the locale
glossary, superseding the old no-lesson/keep-all-English-Originals scope wording.

The 317 whole-string retentions are notation (including intentional distractors),
solfège, original work/creator names and dates, internationally named music
techniques/genres, or actual performed lyric tokens. Ordinary teaching prose is
not exempted. No note B-to-H respelling or invisible-mark identity disguise is used.

Source-aware AI text review does not certify native-human fluency, actual
VoiceOver speech, device rendering, or release readiness. No account-side action,
live resource import, commit, or push was performed by this reviewer.
