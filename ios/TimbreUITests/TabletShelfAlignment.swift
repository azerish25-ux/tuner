import Foundation

/// Capture-only geometry. A shaded title is not evidence of a professionally composed native frame.
enum TabletShelfAlignment {
    static func accepts(cardsTop: CGFloat, cardsBottom: CGFloat, headingTop: CGFloat, headingBottom: CGFloat,
                        clearTop: CGFloat, hiddenBottom: CGFloat, foot: CGFloat) -> Bool {
        guard valid(cardsTop, cardsBottom, headingTop, headingBottom, clearTop, hiddenBottom, foot) else { return false }
        return cardsTop >= clearTop && cardsBottom <= foot
            && (headingTop >= clearTop || headingBottom <= hiddenBottom)
    }

    /// Positive scroll moves content upward. Intersect title placement with unchanged whole-card bounds.
    /// Prefer the smallest move that leaves a four-point margin, remeasuring actual frames after every drag.
    static func correction(cardsTop: CGFloat, cardsBottom: CGFloat, headingTop: CGFloat, headingBottom: CGFloat,
                           clearTop: CGFloat, hiddenBottom: CGFloat, foot: CGFloat) -> CGFloat? {
        guard valid(cardsTop, cardsBottom, headingTop, headingBottom, clearTop, hiddenBottom, foot) else { return nil }
        let margin: CGFloat = 4
        let lower = cardsBottom - foot + margin
        let upper = cardsTop - clearTop - margin
        guard lower <= upper else { return nil }
        func nearest(_ low: CGFloat, _ high: CGFloat) -> CGFloat? {
            guard low <= high else { return nil }
            return min(max(0, low), high)
        }
        let visible = nearest(lower, min(upper, headingTop - clearTop - margin))
        let hidden = nearest(max(lower, headingBottom - hiddenBottom + margin), upper)
        return [visible, hidden].compactMap { $0 }.min { abs($0) < abs($1) }
    }

    private static func valid(_ cardsTop: CGFloat, _ cardsBottom: CGFloat, _ headingTop: CGFloat,
                              _ headingBottom: CGFloat, _ clearTop: CGFloat, _ hiddenBottom: CGFloat,
                              _ foot: CGFloat) -> Bool {
        [cardsTop, cardsBottom, headingTop, headingBottom, clearTop, hiddenBottom, foot].allSatisfy(\.isFinite)
            && cardsTop < cardsBottom && headingTop < headingBottom && hiddenBottom < clearTop && clearTop < foot
    }
}
