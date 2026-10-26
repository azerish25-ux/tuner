/// Capture-only geometry checks, independent of language and localized number formatting.
enum CaptureFrameBounds {
    static func safeBottom(viewportBottom: Double, buttonsTop: Double, fadeHeight: Double) -> Double? {
        guard viewportBottom.isFinite, buttonsTop.isFinite, fadeHeight.isFinite,
              viewportBottom > 0, buttonsTop > 0, fadeHeight >= 0,
              fadeHeight < min(viewportBottom, buttonsTop) else { return nil }
        return min(viewportBottom, buttonsTop) - fadeHeight
    }

    static func fits(contentBottom: Double, safeBottom: Double) -> Bool {
        guard contentBottom.isFinite, safeBottom.isFinite, contentBottom >= 0, safeBottom > 0 else { return false }
        // Allow at most one point of outward accessibility-rectangle rounding, never multi-point clipping.
        return contentBottom <= safeBottom + 1
    }
}
