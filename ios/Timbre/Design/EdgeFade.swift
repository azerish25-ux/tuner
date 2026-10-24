import SwiftUI

// The welcome screen's chip-row fade, shared: a row of chips that scrolls sideways fades out over the last
// stretch of an edge while more chips wait past it, so a chip running off the edge dissolves instead of being
// cut through mid-word ("7/4", "sus…", "Bowe…"). At rest against an end the row is solid there.

/// Which ends of a horizontal scroll row have content past them.
struct EdgeOverflow: Equatable {
    var leading = false
    var trailing = false
}

extension EdgeOverflow {
    /// Read from a horizontal scroll view (content margins included): an end counts once more than a point hides past it.
    init(_ geometry: ScrollGeometry) {
        let offset = geometry.contentOffset.x + geometry.contentInsets.leading
        let range = geometry.contentSize.width + geometry.contentInsets.leading + geometry.contentInsets.trailing - geometry.containerSize.width
        self.init(leading: offset > 1, trailing: offset < range - 1)
    }
}

/// The mask: solid, fading to clear across the last `leading` or `trailing` points of an end with more past it.
struct EdgeFadeMask: View {
    var overflow: EdgeOverflow
    var leading: CGFloat = 36
    var trailing: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflow.leading ? leading : 0)
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: overflow.trailing ? trailing : 0)
        }
    }
}

extension View {
    /// Fades the ends of a horizontally scrolling row while chips hide past them. Apply it to the row's ScrollView
    /// or `EdgeRail`. `bleed` is how far the row draws past its own frame (an `EdgeRail`'s bleed: the screen gutter,
    /// or a card's inset), so the fade lands on the edge where the chips actually disappear.
    func edgeFade(bleed: CGFloat = 0, leading: CGFloat = 36, trailing: CGFloat = 64) -> some View {
        modifier(EdgeFade(bleed: bleed, leading: leading, trailing: trailing))
    }
}

private struct EdgeFade: ViewModifier {
    let bleed: CGFloat
    let leading: CGFloat
    let trailing: CGFloat
    @State private var overflow = EdgeOverflow()

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: EdgeOverflow.self) { geometry in
                EdgeOverflow(geometry)
            } action: { _, value in
                overflow = value
            }
            .mask {
                EdgeFadeMask(overflow: overflow, leading: leading, trailing: trailing)
                    .animation(Motion.quick, value: overflow)
                    // Reaches over the bleed, and a little above and below so a pressed chip's scale isn't clipped.
                    .padding(.horizontal, -bleed)
                    .padding(.vertical, -12)
            }
    }
}
