# All-language lesson integration — 26 October 2026

## Requirement and changes

English source + all 48 app targets require interface **and lesson** localization. Fresh settings follow the phone/app language through `Bundle.main`; explicit in-app overrides remain available. English fallback is temporary missing content, not a completed translation.

`report.py` derives lesson requirements from app resource locales, even without a lesson map/table. Generated TODOs include all 39 new targets × 6,080 keys = **237,120 additional pairs**. Existing maps/resources are preserved. `gpt_l10n.py prompt` now tolerates absent lesson maps. Shipping coverage no longer counts accepted-but-unapplied deliveries as shipped.

`lessons.py --strict` audits actual `Learn.strings` resources for every target, including missing, empty, English-identical and mechanically invalid strings. External Apple delivery now requires this gate; the existing explicit internal-TestFlight-only untranslated bypass is retained. Development CI reports coverage without pretending it is complete, and runs the Python regression tests.

## Legitimate unchanged text

Do not translate proper names/notation artificially merely to pass an identity check. Record the actual independent AI review (or human review only when supplied) in `tools/l10n/lesson-invariants.json`:

```json
{"locales":{"de":{"LKEY":{"source":"Exact current English", "reason":"Why this entire string must stay unchanged", "reviewed_by":"Actual reviewer identity"}}}}
```

Merge records into the existing document; no wildcards, blanket title/prose exemptions, copied-English placeholders, or fabricated reviewer evidence. A changed English source invalidates the exception. The initial registry is empty, pending real review. These records do not certify unrelated translations or device rendering.

## Verification on the integration checkout (before new translations)

- `python3 -m unittest discover -s tools/l10n/tests -p 'test_*.py'`: **23 passed**.
- `python3 tools/verify-ios-resources.py`: **passed**, including all 49 resource locales.
- `python3 tools/l10n/report.py --check --strict`: **passed** (handoff current; this is not translation completion).
- `python3 tools/l10n/lessons.py --strict`: **expected failure, exit 1** — 250,323 absent + 1,740 rejected/English-identical = **252,063 unresolved lesson pairs**. This includes existing titles/notation requiring invariant review, not necessarily mistranslations.
- `python3 tools/l10n/critical.py --baseline --github`: passed, zero critical gaps.
- `python3 tools/ci/comment_hygiene.py`: passed, no new error-level occurrences.
- Python syntax checks and `git diff --check`: passed.
- New Swift app tests cover fresh automatic settings, Foundation regional language negotiation, automatic/manual lesson lookups, restoring System and a deliberately nonexistent lesson key. A regional German UI launch test exercises actual phone-language selection. **Not executed locally**: neither Swift nor Xcode is installed. Existing iOS CI jobs execute these suites after publication; earlier runs cannot verify these uncommitted additions.

## Integration checklist

1. Review the code, generated requirements and validation results before publication.
2. Import completed, reviewed translations and merge reviewed invariant records. Do not generate fake English-filled new-locale maps.
3. Regenerate with `python3 tools/l10n/report.py`, then run the tests, resource verifier, strict handoff check and `lessons.py --strict` again. The gate must remain red until real applied coverage is complete.
4. Inspect subsequent iOS app/UI results for the exact published commit. The welcome/tab matrix alone is not lesson-content coverage or native review.

Generated TODOs are intentionally large (about 74 MB total), because every missing key carries source/context for translators. No new translation, App Store mutation, running-workflow cancellation or locale removal was performed.
