# Catalogue 28: isolated grain is not a proven text-contrast failure

Verified original `CAA03408-26BE-48CF-B2B0-80C80A8D8646.png`, SHA256 `754ff4444ee8009a0450788ec68d9b0a862698c5aa49d0d7f9a74ecdcfebfeab`; upright 1206×2622, explicit sRGB intent 0, PNG CRCs valid.

Both digits and their surrounding backing are complete in the generous [477,1258,521,1300] pixel support crop and larger context. The suspicious **(515,1285) RGB [113,118,97]** belongs to a distinct light rectangular grain mark at approximately x514–516, y1284–1286. It is **not AA fringe**. Against observed solid foreground [245,243,239], its ratio is **4.2428536**.

But this grain is outside the visible digit edge. At y1285:

- x511: [153,157,141], AA edge—not a core/background sample.
- x512: [101,107,85], ordinary backing, ratio **5.0029471**.
- x513: [102,108,85], ordinary backing, ratio **4.9331840**.
- x514: grain begins.

At y1284, ordinary backing at x513 also separates the AA edge at x512 from the grain at x514. The annotated exact-pixel grid records this topology. Source grain rectangles drawn behind text are consistent with this isolated patch.

**Conclusion:** 4.24 is a conservative support-rectangle bound, not a demonstrated text-adjacent contrast defect. Do not change production paint on this point alone. The support crop has not been narrowed to discard it, and the original conservative bound remains below 4.5.

This is neither a full-glyph contrast pass nor a failure authorization. Opaque glyph pixels hide their exact backing; a matched no-text native render or independently validated glyph/backing coverage would be needed to close that gap. [W3C G18](https://www.w3.org/WAI/WCAG21/Techniques/general/G18) distinguishes immediately adjacent/behind-letter background from the entire surrounding artwork and excludes edge AA from foreground sampling.

## Complete-digit adjacency follow-up

No genuine immediately adjacent <4.5 sample was found across either complete glyph. An explicitly diagnostic 8-connected component/rim sweep (all cutoffs 1–6 retained, not selected for a pass) yielded candidate-rim minima 4.93318, 4.93318, 4.92908, 4.92908, 4.78526, and 4.64261. The grain remained outside both glyph components and their immediate rims. Higher cutoffs can leave weak AA in the rim. This fitted-background sensitivity check is **not an independently certified glyph mask or no-text render**, so the conclusion remains **unsubstantiated failure, not blanket pass**. Full method/results: `adjacency-sensitivity.json`.
