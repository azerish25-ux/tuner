# Source-aware purchase/permission comparison

**1,104 / 1,104 rows compared: 23 keys × 48 locales.** Two timing corrections are recommended; 1,102 targets retained. All 1,104 snapshot targets match the checkout (96 `.strings` tables), and source/target/back-translation format arguments match. No repository files were edited.

## Guarded corrections

| ID | Table / key | Old | Proposed new |
|---|---|---|---|
| de-Q011 | `Localizable.strings` / `Cancel anytime in Settings before day %lld.` | Bis Tag %lld jederzeit in den Einstellungen kündbar. | Vor Tag %lld jederzeit in den Einstellungen kündbar. |
| lt-Q011 | `Localizable.strings` / `Cancel anytime in Settings before day %lld.` | Atšaukite bet kada nustatymuose prieš %lld d. | Atšaukite bet kada nustatymuose prieš prasidedant %lld dienai. |

- **German:** `Bis Tag` leaves an until/up-to endpoint; `Vor Tag` restores the source’s exclusive before-day boundary.
- **Lithuanian:** `prieš %lld d.` can mean a number of days ago. The proposal explicitly means before the numbered day begins. It retains `%lld` and avoids a hard-coded ordinal suffix that would not suit every number.

## Contextual warnings resolved without edits

- Swahili `kodi` is attested for chords in [music teaching](https://mtayarishaji.blogspot.com/2012/08/nadharia-ya-muziki.html); tax/rent is not the intended sense here. Google uses `husasishwa` for [subscription renewal](https://support.google.com/youtube/answer/16475192?hl=sw).
- Thai `ระดับเสียง` is pitch in [official music teaching](https://dltv.ac.th/utils/files/download/38495), not necessarily volume.
- Tamil and Telugu chord loanwords have primary musical usage; Korean `내` is a user-perspective own/my adaptation. The permission context retains the user’s charts.
- Bulgarian `Apple регистрация` is [Apple’s own Account term](https://support.apple.com/bg-bg/guide/iphone/iph76e54c61e/27/ios/27). Latvian [klausīties permits locative constructions](https://llvv.tezaurs.lv/klaus%C4%ABties%3A1); the case warning alone is not a defect.
- Date-level last-active-day wording is consistent with the caller’s month/day formatting; there is no explicit through-end-of-day extension. Bare numbered days are anchored by the trial timeline. Short restore/terms/privacy labels are resolved by their actual controls and destinations.
- Annual/monthly periods, automatic renewal, one-day cancellation minimum, respective free-tier scopes, one-payment/no-subscription terms, and no-save/no-upload/on-device privacy statements are retained outside the two identified timing ambiguities.

## Evidence and limits

`row-dispositions.json` and `.jsonl` contain every source, target, blinded back-translation, uncertainty note, fact disposition and current-value guard. `corrections.json` is the guarded integration input. `source-evidence.json` records references and whether evidence came from an opened page or indexed excerpt. `guard-validation.json` includes input and target-table hashes.

This is source-aware AI linguistic QA, not native/human certification, legal sufficiency/compliance review, platform-policy verification, UI validation or audio-implementation certification. No blocked action remains within this assigned comparison; integration and runtime checks belong to the parent task.
