# Mixed-locale warning review

Independent source-aware AI review by Codex reviewer `review_is`, against the
current source, shipped targets, locale glossaries and the full lesson warning
audit. **All 71 non-BIDI warning rows** in da, fi, sv, el, it, ru, ja, ko, kn, lv,
ml, pl and sw were read. This is not native-human or device certification.

- **52 flagged rows corrected**, plus one coupled Russian mnemonic-card change:
  **53 guarded lesson proposals** in `corrections.json`.
- **19 warnings accepted with individual reasons** in `decisions.json`; these are
  explicit soft-layout or proper-title-punctuation exceptions, not silent waivers.
- **Four new exact-source mnemonic heading retentions**, in Russian and Korean,
  have independent whole-string reasons in `invariant-proposals.json`. The English
  word initials encode staff notes. Their localized cards retain the explanations;
  the Russian bass mnemonic's meaning gloss moves from its heading into its card.
- The proposed corrected strings have **zero contract errors and zero unexpected
  helper warnings**. Raw English-identity gates still require the proposed exact
  registry integration by the parent; no live gate was bypassed.

Changes preserve the complete finger patterns, source note letters, spelled
accidentals, note order, fret/string associations, numeric tokens and register.
Greek long hints use concise position groups; Polish groups sharp qualifiers
without changing the intervening open notes. Swedish/Russian finger headings use
compact separators with every finger name retained. The Korean attention-call
exclamation and three-dot ellipsis are corrected. Proper repertoire names are not
renamed solely to clear a scanner warning.

`context-inventory.json` inventories and hashes all actual source occurrences and
their current localized text boundaries. Every flagged row's source/target and
reported context was directly read; selected full answer/card boundaries were
reread for the coupled mnemonic and potentially ambiguous finger/interval/timing
cases. The inventory is mechanical evidence, **not** a claim that all 792 repeated
Latvian chorus arrangements or every neighboring paragraph were redisplayed.

The three Latvian exclamation warnings are published proper hymn titles, verified
against primary publisher sources: [Ak, ticīgie, nāciet!](https://www.churchofjesuschrist.org/study/broadcasts/article/christmas-devotional/2015/12/oh-come-let-us-adore-him-and-the-plan?lang=lav),
[Ak, mazā, klusā Bētleme!](https://www.churchofjesuschrist.org/study/manual/hymns/o-little-town-of-bethlehem?id=html&lang=lav),
and [Paliec ar mani!](https://www.churchofjesuschrist.org/bc/content/shared/content/latvian/pdf/language-materials/34832_lav.pdf).
Their punctuation is retained with the identifying titles.

## Supplemental catalogue label review

`ui-catalogue-proposals.json` contains three guarded proposals for
`timbre_catalog_instrument_handpan_standard_0`: retain conventional **Handpan**,
but localize the descriptive steel-tongue-drum alternative:

| Locale | Proposed catalogue name |
|---|---|
| da | Handpan / tungetromme i stål |
| id | Handpan / drum lidah baja |
| it | Handpan / tamburo a lingua d’acciaio |

Indonesian terminology is directly paired in the
[official instrument-class terminology](https://skm.dgip.go.id/index.php/skm/detailkelas/15).
Italian manufacturer material uses
[tamburo a lingua d'acciaio](https://www.raysenmusic.com/it/tongue-drum/).
The Danish phrase is an explicit natural-language composition from the localized
[instrument-catalogue terminology](https://www.gear4music.dk/da/Perkussion-/Tunet/Tunge-trommer),
not a claim of a uniquely standardized name. No invented phonetic instrument name
is introduced. The slash delimiter used for Siri aliases remains intact.

Integration should add these keys to the persistent UI translation maps and apply
the normal generators, and record terminology updates in the glossaries. This
review changed only proposal/evidence files. Native language preferences, exact
device fit, glyph/RTL shaping, audio/VoiceOver and Siri recognition remain separate
unperformed checks; the parent is tracking actual native CI jobs.
