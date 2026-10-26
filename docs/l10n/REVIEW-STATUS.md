# Translation review status

The owner requested GPT translation and independent AI review in place of the
manual's human-review step. No human native-speaker, legal, accessibility-listening,
or market review is claimed. Automated checks cannot establish perfect fluency
or release readiness. This work does not authorize App Store submission.

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

- Complete all 48 interface locales, nine lesson locales and all 50 Apple-supported listing locales.
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
