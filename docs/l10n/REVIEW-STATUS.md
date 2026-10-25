# Translation review status

This change set follows `TRANSLATING-WITH-GPT.md`. GPT-generated translations
and glossary decisions remain drafts until the native-speaker reviews in
sections 1 and 8.5 are recorded. Automated validation and simulator results do
not constitute native-speaker, legal, accessibility-listening, or market review.

No native reviewer sign-off has been supplied for this change set. Do not treat
it as approval to upload or release a translated build to the App Store.

## Required before release

- A native musician approves every locale glossary.
- A separate GPT pass reviews translations and back-translates legal and
  permission strings; discrepancies are resolved.
- Native reviewers complete the sampling and full-review requirements in
  section 8.5, including every warning and translator note.
- The five inferred interpolation keys are confirmed against a fresh Xcode
  localization export, with translations under the compiler's actual keys.
- Localization validation, iOS Simulator checks, and visual review pass.
- Store text and search terms are reviewed in each of the nine store markets.

Progress, checks, and outstanding issues will be recorded here as work proceeds.
