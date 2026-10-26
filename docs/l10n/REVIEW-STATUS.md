# Translation review status

The owner requested GPT translation and independent AI review in place of the
manual's human-review step. No human native-speaker, legal, accessibility-listening,
or market review is claimed. Automated checks cannot establish perfect fluency
or release readiness. This work does not authorize App Store submission.

## Current checkpoint — 26 October 2026, 11:25 UTC

- Interface resources: all 49 app languages have literal-key coverage; this is not a universal device/semantic certification.
- Lessons: 28 translated targets plus English now cover all 6,083 current source keys. Finnish, Danish, Swedish, Dutch and Norwegian were imported after full independent AI review, 842 guarded corrections and 1,940 exact-source retention approvals. Bridge and interval source splits and the sustained-tremolo repair reconcile their frozen drafts with current content.
- Romanian is now imported after full independent AI review: 164 guarded corrections, 370 exact source-bound retention approvals, and all 6,083 current targets independently hash-verified.
- Hebrew and Thai are now independently reviewed and imported: 14 and 13 guarded corrections, 231 and 261 exact retention approvals respectively; all 6,083 current targets verified in each.
- Telugu, Swahili and Greek complete drafts are undergoing independent review. Zulu authoring is complete with final author QA in progress. Polish, Czech and Indonesian drafting continue. 13 further targets have not yet entered lesson drafting.
- 18 additional first/second musical-item label corrections across nine earlier locales passed independent review of all 369 locale/context rows. Some changes fix demonstrated referent/gender defects; others improve precision.
- Context tooling now exposes nested arrangement section names in semantic bundles. Source curriculum is unchanged; frozen review inputs remain preserved.
- Store text: all 50 Apple-supported locale payloads have independent AI text review. Localized screenshot/preview renders, production privacy URL and account-side checks are not complete; release_ready remains false.
- GitHub run 40288874201 on 31305f6 passed 58 app tests and 3 smoke tests, including all configured regional language cases and the corrected tuner string identifier. Its accessibility audit still failed contrast checks.
- Matrix run 40286089721 now passed seven groups after the Indic retry; its RTL group remains failed with simulator lifecycle timeout. Current integration requests a fresh full matrix with the bounded recovery fix; queued/running is not passing.
- Historical sections below describe their own earlier checkpoints, not current coverage.

## Imported checkpoint: German launch strings

- 151 launch strings imported: 11 purchase/legal, one permission, 93 VoiceOver,
  and 46 onboarding/funnel strings.
- The German glossary defines register, music terminology and interface terms.
- A separate AI pass read all 151 English/German pairs. It corrected a literal
  haptic-feedback phrase, muted-note feedback, unknown-note grammar and the
  description of a higher starting level.
- Independent AI back-translation preserved purchase, cancellation and free-tier
  facts. The reviewer had previously seen the shared English source in another
  locale, so this was not a strictly source-blind experiment.
- The German welcome test now asserts the translated headline and subline without
  the old expected-failure wrapper. Its new simulator result is pending.
- 488 German interface strings and 1,467 German lesson strings remain at this
  checkpoint. Other languages and all store-listing work are still in progress.

## Compiler-key evidence

Xcode localization export on source `63a672b4c6cb0cdb4b3c8113d9aa85047196884b`
passed in [run 40244541418](https://github.com/azerish25-ux/tuner/actions/runs/40244541418).
The generated `en.xliff` confirms the critical keys `Loop bar %lld` and
`Then %@. It renews automatically until you cancel in Settings.`.
Other scanner-only guesses need remapping before their later UI import:

- `%lf, estimate` → `%@, estimate`
- `Watch the pick: down on beats %lld` → `Watch the pick: down on beats %@`
- `%lf more to beat %lf` → `%lld more to beat %lld`
- `Position %lld · frets %f–%lld` → `Position %lld · frets %lld–%lld`
- `Position %lld · %@ shape · frets %f–%lld` → `Position %lld · %@ shape · frets %lld–%lld`

The scanner also duplicates `Beat %lld` and `%lld beaten` as `%lf` keys;
only the compiler's integer keys are used for those views.

## Baseline simulator result

Before this import, [iOS run 40244541404](https://github.com/azerish25-ux/tuner/actions/runs/40244541404)
passed core, app and release jobs. Localization launch tests passed with the old
expected German gaps. The accessibility audit failed on five audit timeouts and
a Settings “Note names” contrast failure. These pre-existing failures are not
translation validation success and are not waived.

## Outstanding quality checks

- Complete all 48 interface locales, all 48 target lesson locales and all 50 Apple-supported listing locales.
- Independently review remaining translations, terminology and length warnings.
- Verify compiled keys and preserve placeholder order, digits, plurals and syntax.
- Review localized simulator screenshots, RTL, VoiceOver and layout.
- Record actual pass/fail/not-run results for each published source revision.

Local checkpoint gates passed: strict handoff consistency, German strict critical
coverage, bundled-resource verification, and lossless string-catalog conversion.
The import also regenerated nine lesson tables, removing nine obsolete source
keys from each; none exists in the current English lesson table. No current
lesson translation was deleted. Other locales' handoffs dropped inferred-key
warnings now resolved by the German table. These are generator side effects.

## Checkpoint: launch-critical text in all 48 languages

All 7,248 launch-critical locale/string pairs (151 per language) have now been
translated and independently AI-reviewed against the English and relevant code.
Corrections distinguish pitch from loudness, sounding notes from written symbols,
stronger accents from earlier timing, and touch-to-sync from tapping the beat.
Legal renewal, cancellation, payment, free-tier and permission facts were reviewed.
This is source-aware AI review, not human sign-off or proof of perfect wording.

The strict critical gate now passes for all 48 shipping languages, with zero
legal, permission or VoiceOver gaps; its regression baseline is empty. The
handoff consistency, bundled-resource and lossless-catalog checks also pass.
The 46 funnel strings per locale are imported too. Full UI, lesson and store
translation completion is still pending: each locale has 488 UI TODO strings,
and each of the nine lesson languages has 1,467 lesson TODO strings at this
published checkpoint. Those numbers describe the imported tables, not unpublished
drafts. Simulator validation for this revision is pending.

Xcode additionally exposed `Back`, the default localized label in
`ios/Timbre/Design/Kit.swift:221`, which the quick scanner misses. The source table
now records it explicitly and each of the 48 translations reuses its existing
`timbre_about_back` value. This fixes lookup coverage without inventing new text.

## Expanded listing scope and simulator matrix

The owner expanded the listing requirement to every supported Apple locale.
`tools/l10n/store-locales.json` records the 50 verified metadata locales, primary
English source, app-language mapping and unsupported-language fallback policy.
This does not claim Malay, Odia or Traditional Chinese app UI support. The
additional listing texts are pending, not completed by adding the requirements.

The opt-in localization matrix covers all 48 translated app locales in eight
six-language shards. It compares actual welcome headlines, sublines, start
buttons and three tab labels with the shipped tables, and captures welcome/tuner
screenshots. Missing fixture resources, skipped tests and missing per-locale
completion markers fail the workflow. It does not prove every screen, spoken
VoiceOver behavior, or overall linguistic quality.

Independent source review completed for the matrix implementation. All 13 local
Python tests pass (fixture validation, real 48-language tables, workflow coverage
and store-locale requirements). Swift compilation and actual simulator execution
remain unverified until GitHub Actions finishes.

## Full UI and expanded lesson checkpoint (2026-10-26)

This section supersedes the earlier checkpoint counts above.

- All 48 target locales now have zero mechanically missing app UI entries.
  Independent AI review covered the new UI drafts and corrections; compiler-export
  evidence resolved the known interpolation-key mismatches before import.
- All 13,203 newly authored lesson entries in the original nine target languages
  received independent source-aware AI review. The 114 review corrections and
  subsequent 48 terminology/violin-source addenda were applied. Remaining shared
  titles are explicitly pending semantic review, not silently counted complete.
- Lessons are now required in every one of the 48 target languages. The additional
  39-language drafting effort is ongoing; unimported drafts are not shipped coverage.
  The strict external-delivery lesson gate intentionally fails until all are ready.
- Source-bound notation/name exceptions require actual independent review evidence.
  Directional formatting marks cannot disguise unchanged English as translated text.
- Legal, permission and VoiceOver string coverage passes the strict mechanical gate
  for all 48 targets. This does not establish legal advice or spoken accessibility QA.
- Simulator run 40250346596 at commit 3fc8ef1 has five successful six-language
  groups at this checkpoint; two groups remain running and one had an accessibility
  initialization failure before tests. The separate accessibility audit retry remains
  running. These results do not certify the newer full-UI candidate.
- Actual Arabic/Persian/Hebrew/Urdu/Bulgarian/Bengali launch captures were inspected.
  Persian ownership wording and Bulgarian headline/instrument truncation were fixed
  with source regression checks; fresh simulator captures remain required.
- No human native-speaker certification, full-app device signoff, completed store
  submission, or finished all-language lessons is claimed.

## Reviewed curriculum expansion (2026-10-26)

- Arabic, Persian and Hindi each add all 6,080 current lesson strings after
  exhaustive independent AI source/context review, not just a mechanical sample.
- Applied 190 Arabic, 86 Persian and 98 Hindi guarded review corrections. Exact
  source-bound invariant decisions cover 124 Arabic, 154 Persian and 370 Hindi
  notation/name/original-sung-token entries. Mnemonic text is contextualized in the
  target language; ordinary English teaching prose is not waived.
- Arabic complete LTR notation/name spans use Unicode isolates where review and
  ICU testing demonstrated split-token reordering. Actual iOS glyph, wrapping and
  spoken VoiceOver verification remain pending for these new lesson resources.
- The original nine target lesson languages now have zero mechanically unresolved
  entries after 357 coordinated title/reference/UI edits and 161 source-bound
  title/technical-term decisions. Established translated titles are documented in
  locale glossaries; source sung lyrics and creator credits remain intentionally intact.
- Mechanical completeness is not native-speaker certification or evidence that all
  48 target lesson languages are done. Remaining languages stay in the generated queue.

## Bengali curriculum (2026-10-26)

All 6,080 current lesson pairs received exhaustive independent AI contextual review.
Applied 172 exact-source/old-guarded corrections and 168 individually justified
notation/name/original-sung-token invariants. Every current source occurrence was
reconciled for shared labels. Latin-initial memory aids, rhythmic subdivision syllables,
string pitch versus physical position, bow directions and song titles are coordinated
with the glossary. Mechanical lesson coverage is complete; iOS rendering and human
native-speaker certification are not claimed.

## Preserved review and draft checkpoint (2026-10-26)

Urdu's full 6,080-key frozen baseline is imported locally with 186 guarded review
corrections and 305 source-bound invariants. This baseline still needs the separately
staged shared-context repairs; mechanical completeness is not release certification.

`tools/l10n/staged/` and `docs/l10n/staged/` preserve the complete Urdu, Gujarati,
Tamil and Kannada review candidates, original-value correction guards, invariants,
coverage and unresolved source/layout issues. They also preserve 1,104 source-blinded
purchase/permission back-translations and a bounded snapshot of ongoing Malayalam,
Marathi and Punjabi drafts. These artifacts do not auto-import or approve release.
The artifact manifest and verifier bind every preserved file; partial drafts are
explicitly unreviewed. Temporary tool logs, prompts and duplicate downloads are not
repository deliverables and were excluded.

Two English keys conflate different contexts (string list/rhythm count and finger/
song section). A minimal two-key source migration is staged and undergoing independent
review. The associated wording corrections must not be called resolved until applied
and checked against the regenerated source. Blinded wording comparison is also ongoing.

## Applied context migration and expanded runtime checks (2026-10-26)

The reviewed context migration is now applied: the two new source keys distinguish
string lists from spoken counts and song sections from finger choices. Exactly seven
localized curriculum objects changed; all other data and the marketing counts remain
unchanged. All 17 currently imported target locales contain 6,082 current lesson keys.
Gujarati, Tamil and Kannada review candidates and exact invariant decisions are now
in the live maps/resources; historical staged evidence remains frozen and verifiable.
The other 31 target locales still require their lessons, including the new two-key delta.

The language matrix now opens the first actual guitar lesson for every imported lesson
locale and checks its title, heading and body under the phone-language launch settings.
Missing lesson locales explicitly emit pending markers, never lesson passes. CI validates
executed markers against the generated fixture. Actual Swift/simulator execution remains
pending for this checkpoint; Python fixtures and source-based checks are not device QA.
Only a new explicit matrix request supersedes an older matrix run, using GitHub's
[conditional concurrency behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

Source-blinded purchase/permission QA now covers all 1,104 rows. Source-aware comparison
retained 1,102 and applied two exact-guarded cancellation-deadline corrections (German and
Lithuanian). Evidence and limitations are in `purchase-permission-review/`. No native
human certification, legal compliance opinion or complete release-readiness is claimed.

## Bounded simulator launch recovery

The older matrix's Japanese/Korean/Chinese/Thai/Vietnamese/Indonesian group failed
before launch with no app process ID. The matrix now waits for simulator boot and
uses the existing launch-only classifier for one retry. Build errors and actual
translation/layout assertions are never classified as recoverable launch failures.
Initial logs/result bundles remain preserved; completion markers must come entirely
from the successful attempt. Local validation: 102 localization tests plus workflow
YAML/shell syntax pass. This does not turn the earlier failed run into a pass; fresh
simulator execution remains required.

## Marathi and navigation fallback checkpoint

Marathi now includes all 6,082 current lesson strings, with source/final hashes,
opposite-author per-row review, 133 accepted corrections and 305 source-bound
invariant decisions checked before import. Review evidence is in `reviews/mr/`.

Direct inspection of actual a64f907 simulator captures confirms the earlier Bulgarian
headline/instrument wrapping and Persian ownership-link corrections at default text
size. It also exposed an English Songs tab where lesson content is absent: the tab
now uses the interface translation when the course name falls back to English, while
preserving an available translated course name. The matrix checks all five tabs, and
app tests cover fallback and retained course-title behavior. New simulator verification
is still required. The extreme AX5 tuner screenshot shows broader overlap/truncation
that remains unresolved; passing a scoped header check is not full-screen approval.
Evidence: `visual-review/launch-a64f907.json`.

## Malayalam, Punjabi and ordinal-context checkpoint

The live lesson maps now cover 20 target locales plus English, with 6,082 keys each.
Malayalam adds 246 independently reviewed corrections and 308 exact source-bound
invariants; Punjabi adds 94 corrections and 298 invariants. Their review bundles are
under `reviews/ml/` and `reviews/pa/`. Malayalam retains one semantically accepted
33-codepoint chip against a 24-codepoint hint; actual layout remains to be verified.
The other 28 target lesson languages are not yet complete.

The bare Second/Third/Fourth sources previously mixed finger and interval meanings.
Exactly 18 finger options now reuse existing explicit finger keys, leaving the bare
keys interval-only. Independent review approved 42 live replacements and 12 retains,
plus four French/Chinese Fifth/Sixth interval corrections. Punjabi's three conditional
ordinal targets were imported only after the exact reviewed source remap was verified.
No answers, note data, patterns, IDs or other curriculum data changed; English stays
byte-identical. Evidence and regression guards are in `ordinal-context/`.

On a291229, core, app and release jobs passed. Accessibility failed with contrast
findings and unfinished Songs Dynamic Type/clipped-text audits; failures remain open,
not waived. The actual paywall screenshot still shows a trial badge obscuring part of
the annual price. Evidence is in `visual-review/accessibility-a291229.json`; a later
layout repair requires fresh simulator verification. No global accessibility or native
linguistic certification is claimed. Store text remains independently AI reviewed;
locale-specific assets, live store/account requirements and final device QA remain
separate gates rather than presumed complete.

## Measured paywall offers and preserved ongoing drafts

The annual trial badge now occupies a measured row instead of an overlay over the
StoreKit price. Localized badges and stacked plan text wrap at full readable size;
accessibility sizes select the stacked arrangement. Four hosted-view regression tests
cover long offers, RTL, narrow widths and the actual phone-width arrangement selector.
These Swift tests still require Xcode execution; source/resource checks alone are not
rendered proof. No purchase wording or entitlement behavior changes were introduced.

Dutch instrument terminology is normalized to standard `ukelele`, with a separate
before/after receipt under `reviews/nl-ui-terminology.json`. Historical purchase review
hashes remain historical, not rewritten to pretend they cover later spelling changes.

`tools/l10n/drafts/ongoing/` preserves timestamped, partial, unreviewed Finnish, Dutch,
Swedish, Danish, Norwegian and Romanian authoring work. These drafts are not imported
or included in the completed-language count. Its verifier checks hashes and source
bindings, not translation quality. Work created after each snapshot remains ongoing.

## Accessibility-size tuner layout candidate

The observed AX5 screen overflow is addressed with a vertically scrollable layout
at accessibility text sizes instead of squeezing header, stage and readout into a
fixed screen-height stack. The normal-size arrangement is unchanged. Tuning captions,
status and quest text can wrap, and the string-end labels retain their full height.
The matrix now requires the AX5 status and string rail to be reachable above the tab
bar and captures both after scrolling. This is an implementation candidate: actual
Xcode/simulator execution and fresh visual inspection are still required. It does not
resolve or waive the separate contrast findings elsewhere in the app.


## Shared-answer context and uninterrupted CI

New helper batches include every distinct prompt/explanation for each quiz-answer
key. This prevents the first occurrence from hiding other meanings, such as Up/Down
being both melody directions and mandolin picking strokes. Earlier frozen batches
remain untouched; independent review must inspect current shared contexts. Three
new regression tests cover aggregation, all41 direction uses and8 One beat uses.

Ordinary main checkpoints now let a running iOS verification finish rather than
restarting its builds on every translation push. The newest pending checkpoint is
still tested afterward. PR updates, manual dispatch and an explicit `[ci-refresh]`
request retain cancellation behavior. Every result remains bound to its exact SHA;
a prior pass is not evidence for later code. The a291229 eight-group language matrix
finished successfully, covering48 launches and its17 available lesson locales. A
fresh explicit matrix request is needed for the20-locale and layout checkpoint.

## Phone-language negotiation coverage

Foundation negotiation tests now cover all49 app locales using regional phone
preferences, including Norwegian Bokmål `nb-NO`, Punjabi `pa-Guru-IN` and Simplified
Chinese `zh-Hans-CN`. The cases must exactly cover the bundled locale set. These are
new assertions pending Xcode execution, not a claim that every alias has passed or
that incomplete lesson locales are already translated. Production still uses the
system bundle for automatic selection; no silent language override was introduced.

## Shared semantics and string-control regression follow-up

17 additional guarded language corrections across Arabic, Marathi, Portuguese,
Spanish, German and Russian passed fresh independent semantic review and are now
applied. See `reviews/shared-context-corrections/`. This supersedes only those
specific earlier targets, not their historical review artifacts.

On 5e938a9 all 58 app unit tests passed, including the four new measured-paywall tests.
The string-lock smoke query failed even though its actual screenshot shows a green
E2 chip and quest1/6. The new rail identifier likely propagated to individual string
controls. The rail now explicitly contains its accessibility children; a separate
assertion checks individual string IDs before retaining the original tuned-string
assertion. A fresh simulator pass is required, not a waiver or assumed success.
Evidence: `visual-review/smoke-5e938a9.json`.

Complete unreviewed Finnish, Danish, Swedish, Dutch and Norwegian author drafts are preserved
under `tools/l10n/drafts/final/`, with exact source/target hashes. They remain excluded
from the 20 applied target-language count until separate full review and import.

## Pitch comparison and complete Romanian draft

Seven additional independently reviewed corrections make the gtr-13-4 bend prompt
explicitly mean a pitch below its target, not a short duration. Actual MIDI64-to63
comparison and Different answer are unchanged. Evidence and exact guards are in
`reviews/bend-context-corrections/`.

All six new author drafts, including Romanian, are now preserved in `drafts/final/`.
They are complete drafts but remain unapproved/unimported while full independent
semantic review proceeds. Applied lesson coverage is still20 target languages.

The actual5e938a9 paywall capture confirms that the trial badge no longer obscures
the annual price. All four hosted-layout tests passed. A remaining savings-badge
contrast finding and the wider47-finding audit are not waived; see
`visual-review/paywall-5e938a9.json`. An explicit iOS refresh requests verification
of the newer string-identifier fix rather than repeatedly testing the obsolete
known-failing revision.

## Guarded source clarification support

The batch helper now attaches10 verified source clarifications with exact English
and full-context hashes. Six new tests reject stale source/audio/context evidence
and unbound/duplicate notes. All117 Python localization tests pass. Existing frozen
translation/review packets are not rewritten; future batches gain these distinctions
without changing English keys, answers, music data or translator TODO metadata.

## Applied cross-role repairs and historical source versions

Two physical bridge titles now use an explicit instrument-part key; one interval
explanation now has an interval-specific title rather than a chord-quality title.
The incorrect next-beat tremolo answer reuses the existing sustained-long-note
instruction, preserving answer1 and the actual three-beat note. All notes, IDs,
patterns and counters remain unchanged. Exact independent reviews, parent rebuild
proofs and receipts are under `bridge-context/`, `interval-context/`, and
`tremolo-context/`.

The resulting current source contains6,083 keys: the frozen6,082 plus two additions
minus one explicitly retired obsolete key. All20 applied target resources cover
this exact current set. The six new reviews remain bound to their historical source
sets plus reviewed addenda; they are not falsely counted as imported. Draft integrity
checks accept only complete known source versions, not arbitrary subsets.

## Localized capture implementation checkpoint

Chord and result-frame checks now use semantic state identifiers without altering localized VoiceOver speech. The chord capture requires all six distinct heard strings. A focused English/German/Arabic workflow is requested; compilation and real captures are pending. Other tour selectors and iPad setup still need localized verification, so this does not certify complete listing assets.
