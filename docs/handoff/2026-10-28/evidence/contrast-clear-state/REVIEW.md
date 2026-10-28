# Revealed Songs contrast: current native evidence, not audit authorization

## Result

No production paint correction is justified by this review. All 15 requested strings are visibly complete in their respective revealed original screenshots, with surrounding backing and without dock or rail-edge fading. Fourteen measured candidate-core/backing bounds are at least 4.5. Catalogue **28** has a conservative whole-support bound below 4.5, but the low sample is an isolated grain patch outside the digit; an actual text-adjacent failure is unsubstantiated. This is not a blanket contrast or accessibility pass.

| Requested target | Observed conservative core/backing ratio |
|---|---:|
| Violin | 16.6307968 |
| Joy, with both title lines retained in support | 7.9180881 |
| Ode to Joy C / G | 14.0357070 / 13.9088385 |
| Ode to Joy 2:07 / +35 XP | 8.2161214 / 7.9580892 |
| Amazing Grace G / C / D | 12.5294596 / 12.6692846 / 12.6810791 |
| Silent / Night | 4.8827183 / 7.7998748 |
| 28 | 4.2054498 whole-support bound; see qualification below |
| Silent Night A7 | 14.5167833 |
| Both +5 versions labels | 15.2027358 / 15.4973757 |

Threshold remains 4.5, without rounding for comparison. Ratios are measurements of the retained masks and visible backing, not assertions about unknown pixels hidden beneath opaque glyphs.

## Catalogue 28 qualification

The broad support was not narrowed to discard its worst point. Pixel (515,1285), RGB (113,118,97), is a genuine light grain mark, not antialiasing. Against the observed solid foreground (245,243,239), it gives 4.2428536; the more conservative retained core minimum gives 4.2054498. However, this grain is outside the 8 silhouette. At that row, x511 is an antialiased edge, x512 and x513 are intervening ordinary backing, and the grain begins at x514. Those ordinary backing points give 5.0029471 and 4.9331840.

An independent complete-digit adjacency sensitivity sweep found no substantiated immediately adjacent sample below 4.5. Its candidate-rim minima range from 4.92908–4.93318 for the tighter background-residual cutoffs. Looser cutoffs admit possible AA and remain diagnostic only. Neither that fitted-background sweep nor the masks here are a certified glyph oracle or a hidden-backing reconstruction. See `independent-catalogue/` for the exact-pixel grid, full support, all sensitivity results and limitations. No paint change or finding clearance follows.

## Provenance and method

- Verified original artifact 12814747299, SHA256 `4e2ad730783e6464b5c10b424ee9b9b55cb6d2498f089125e3867da4a1021ef2`, 404,947,485 bytes. Native reports record checkout `9d7c91cc68269205260089b41139170ca87c6698`; this is provenance, not a source-closure or eligibility assertion.
- Twelve original PNG/hierarchy hashes match the verified attachment map. Every target has a unique StaticText ID/label and the exact Button parent before/after. Target and parent frames match across the pair.
- PNGs are upright, opaque 1206×2622 with an original sRGB declaration (intent 0), checked CRCs and no alternate/HDR/animated declaration. They already encode sRGB; no guessed device profile or redundant color transform is applied. Geometry establishes 3 pixels per point against 402×874, not UIImage.scale metadata.
- Every pixel from row 118 downward matches before/after. Differences above are only status-clock pixels. The measured support rectangles themselves match exactly.
- Full visible glyph support was visually reviewed, not cropped solely to AX frames. Joy retains the entire two-line title block. Chord supports include every glyph edge plus backing, rather than treating the separate bright capsule outline as the background behind a letter. The initial wider support measurements are retained in `exploratory-wide-support/` to make this distinction inspectable.
- Magenta is candidate core consistent with source paint; amber is strong ink/uncertain AA boundary; cyan is candidate backing. Two-pixel-eroded interiors retain actual top-wash variation. Radius 2–5 sensitivity is retained. No edge AA pixel is intentionally treated as the nominal foreground. RGB proximity and erosion do not establish exact native alpha coverage; the excluded 2px band also leaves immediate fringe/hidden backing unmeasured. These are analysis masks, not an audit exemption mechanism.

The [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) distinguishes nominal foreground from antialiasing. [G18](https://www.w3.org/WAI/WCAG22/Techniques/general/G18) addresses backing immediately adjacent to or behind letters, rather than every distant color in an illustration.

## Native callbacks and remaining limits

The current clear-state audit reports returned, but first-pair and third-card diagnostic groups then exceeded their 90-second cooperative budgets. Their failures remain failures. Ten requested IDs are absent from those clear-state callback lists; five still produce contrast callbacks: Joy, Silent, Night, and the two +5 labels. `clear-state-callback-comparison.json` records the exact lines and report hashes. Callback absence is observed evidence, not a pass for a failed group.

Requested locale en_US and content size large are recorded configuration only; other effective traits remain unknown. These sequential screenshots are not atomic callback proof. This review covers neither Learn Start nor Practice Ear, unrelated new callback targets, other variants, nor the original occluded/faded layouts. All original strict failures remain, `auditAuthorization=false`, and no helper or filter is activated.

## Reproduce

Use an environment with NumPy, SciPy and Pillow:

```sh
python measure_revealed_songs.py --originals <verified-attachments-directory> --output <new-analysis-output>
```

`review-receipt.json` binds the script, measurements, support/mask sheet and independent review. Original image bytes are not transformed or replaced; only derived analysis crops/masks are written separately.

## Independent support review

All 15 support/mask pairs were independently inspected: no target glyph was found clipped, the foreground roles match the native originals, Joy retains both title lines while measuring only Joy, and chord supports retain glyph edges plus capsule fill without substituting the separate capsule outline as backing. Mask hashes/counts were checked. This clears the package only for diagnostic observed-extrema reporting, not as a certified full-glyph minimum or audit filter.
