# Smallest defensible visibility/reachability distinction

**Proposal only. No audit handler or gate changes are authorized or implemented.**

## Official guidance and its boundary

Apple describes an accessibility audit as an inspection of the current screen, recommends covering the app’s different views, and explicitly permits filtering an individually investigated false positive. Its example defaults to reporting issues and narrows filtering by issue type plus element properties. It does **not** define every offscreen, covered or fading element as safe to ignore. Audits also do not replace assistive-technology testing. [Apple audit guide](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app), [WWDC23 audit session, filtering and considerations](https://developer.apple.com/videos/play/wwdc2023/10035/).

`exists` means presence in the UI hierarchy, not visibility. `isHittable` means the system can compute a current hit point; it is useful for control reachability, not a guarantee that every glyph is unobscured. A partially readable label or an AX rectangle overlapping a dock must not become a paint pass on those properties alone. [Apple exists](https://developer.apple.com/documentation/xcuiautomation/xcuielement/exists), [Apple isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable).

## Recommended now: disposition metadata, not exemptions

Keep the raw initial audit and all issue records. Add no new raster-reference catalog. For each exact issue identity, record two independent axes:

1. **Visibility in the audited state:** fully clear / wholly outside actual clip and viewport / partially covered or faded / unknown. Require the same current screen, unique ID + type + label + parent, finite actual frames, real viewport and occluder bounds, and matching original pixels. Unknown bounds, anonymous/duplicate identity, unreadable full glyph support, state motion or an incomplete capture remains **unknown/fail**. Do not infer an occluder is absent just because its AX query returns zero.
2. **Reachability and clear-state result:** not attempted / failed / reached and native audit returned / reached with persistent target callback. Use bounded real scrolling, the same exact target and semantic state, complete full-glyph and control containment, and actual control hittability. A missing target is never a pass. Retain separate reachability assertions; do not make an offscreen contrast classification erase an inaccessible control.

These axes distinguish a finding’s observation conditions without claiming the text’s paint is defective or safe. Dock/rail fading is a **partial-visibility condition**, not automatically “offscreen.” If the text remains intended to be read in that position, actual low contrast there can still be a product defect. If scrolling cannot expose it fully, that is a reachability/layout failure regardless of its clear-state colors.

### Current evidence makes this useful immediately

The three verified revealed Songs states contain all 15 requested strings completely. Ten IDs are absent from the returned clear-state contrast callbacks; five persist: Joy, Silent, Night and both +5 labels. Fourteen observed core/backing measurements are at least 4.5; catalogue 28 is qualified, not cleared. The first-pair and third groups still failed their cooperative budgets. Therefore the correct present dispositions are **evidence collected, original failures retained**, not ten native passes or fifteen contrast waivers.

## If a future gate policy is explicitly requested

Two small, distinct options exist:

**A. Current-run reveal/re-audit coverage, preferred for occluded targets.** A known original observation may be marked “contrast not evaluable in that state; covered in clear state” only after the same run completes the required reveal checkpoint and audit within the existing bounds, proves full support/control reachability, and records no contrast callback for that exact target in the clear state. It is not a historical suppression. Any new/unrecognized issue, identity mismatch, failed reachability, missing overlay evidence, budget failure, incomplete audit or persistent target callback remains a failure. Original raw issues are still retained. This is an explicit policy change, not something the present evidence or collector silently enables.

**B. Individually reviewed native false positive for a persistent clear target.** This follows Apple’s documented filtering facility but needs a separate, explicit review decision for the exact contrast issue, screen and component—not a prefix, label-only, offscreen or `.isHittable == false` rule. Acceptance requires current actual full-glyph/backing evidence and adequate paint contrast, supported variants/states, independent review, and regression coverage which fails on changed foreground/backing, clipped/deleted glyphs, foreign identity and missing evidence. A current audit call must complete. A reviewer may approve only the known false-positive case; all unknown issues continue failing. The five persistent targets are candidates for investigation, **not authorized exceptions**. Catalogue 28 is not a candidate based on its ambiguous rectangular-support bound alone.

Neither option requires whole-app/source-closure attestation or endlessly refreshing exact old PNGs. The property is about current visible pixels, identity and state. Build/runtime settings belong in provenance. Conversely, source palette ratios alone, a representative favorable pixel, absence from an incomplete audit, or exact geometry alone cannot establish the complete current visual property.

## Stopping rule

Use the already integrated bounded checkpoint/callback-capture improvements on the next authorized native run. First establish whether the three Songs groups and Learn/Practice lifecycle/overlay prerequisites complete. Review the resulting current originals and exact target callback lists. Do not expand the framework or change product artwork simply to obtain a green audit. If a persistent clear-state issue cannot be independently justified as a false positive, it stays failed.
