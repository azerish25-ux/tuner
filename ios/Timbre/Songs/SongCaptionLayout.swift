import SwiftUI

/// Keep a real 44-point versions target clear of the caption. The intrinsic row cannot
/// accept a fit obtained by truncating its text; narrow cards put the target above it.
struct SongCaptionHeader<Content: View, Versions: View>: View {
    let hasVersions: Bool
    private let content: () -> Content
    private let versions: () -> Versions

    init(hasVersions: Bool, @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder versions: @escaping () -> Versions) {
        self.hasVersions = hasVersions
        self.content = content
        self.versions = versions
    }

    var body: some View {
        if hasVersions {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 6) {
                    content()
                    slot
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 6) {
                    slot.frame(maxWidth: .infinity, alignment: .trailing)
                    content().fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            content().fixedSize(horizontal: false, vertical: true)
        }
    }

    private var slot: some View {
        versions().frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget, alignment: .trailing)
    }
}

/// Full-size chord chips wrap in reading order. Unlike a last-resort fixed HStack,
/// this layout cannot extend into the versions control or past the card boundary.
struct SongCaptionFlow: Layout {
    let direction: LayoutDirection
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.map { $0.sizeThatFits(.unspecified) }
        let intrinsicWidth = natural.reduce(CGFloat(0)) { $0 + $1.width }
            + CGFloat(max(0, natural.count - 1)) * spacing
        let width = min(proposal.width ?? intrinsicWidth, intrinsicWidth)
        let frames = frames(subviews, width: width)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: UnitPoint(x: 0, y: 0), proposal: ProposedViewSize(frame.size))
        }
    }

    private func frames(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
        let sizes = subviews.map { view in
            let natural = view.sizeThatFits(.unspecified)
            return view.sizeThatFits(ProposedViewSize(width: min(natural.width, width), height: nil))
        }
        return Self.pack(sizes, width: width, spacing: spacing, direction: direction)
    }

    static func pack(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat, direction: LayoutDirection) -> [CGRect] {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        return sizes.map { size in
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            let physicalX = direction == .rightToLeft ? width - x - size.width : x
            let frame = CGRect(x: physicalX, y: y, width: size.width, height: size.height)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            return frame
        }
    }
}
