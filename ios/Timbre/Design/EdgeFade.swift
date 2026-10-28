import SwiftUI

// One fade for every row that scrolls sideways (chips, pills, shelves): an end fades out over its last stretch
// while more waits past it, so a chip running off the edge dissolves instead of being cut through mid-word
// ("7/4", "Open G", "Bowe…"). At rest against an end the row is solid there. `EdgeRail` and `railBleed`
// (PracticeChrome) use it for their rails; `.edgeFade` adds it to any other horizontal ScrollView.

/// Which ends of a horizontal scroll row have content past them.
struct EdgeOverflow: Equatable {
    var leading = false
    var trailing = false
}

extension EdgeOverflow {
    /// Scroll/CGRect coordinates describe physical left/right. The mask API describes semantic
    /// leading/trailing, so convert exactly once rather than fading the resting RTL leading edge.
    init(physicalLeft: Bool, physicalRight: Bool, direction: LayoutDirection) {
        self.init(leading: direction == .rightToLeft ? physicalRight : physicalLeft,
                  trailing: direction == .rightToLeft ? physicalLeft : physicalRight)
    }

    /// ScrollGeometry's x offset is logical, unlike a content GeometryProxy's physical bounds.
    /// A live 300-point viewport with 20/32 margins reports a 248-point container, and starts
    /// at -20 in LTR or +32 in RTL. Use the visible width, without counting those margins twice.
    init(_ geometry: ScrollGeometry, direction: LayoutDirection) {
        self.init(offset: geometry.contentOffset.x, contentSize: geometry.contentSize,
                  viewportSize: geometry.visibleRect.size, insets: geometry.contentInsets, direction: direction)
    }

    /// Separate the logical scroll measurement from CGRect's physical left/right conversion below.
    init(offset: CGFloat, contentSize: CGSize, viewportSize: CGSize, insets: EdgeInsets, direction: LayoutDirection) {
        let progress = offset + (direction == .rightToLeft ? -insets.trailing : insets.leading)
        let range = contentSize.width + insets.leading + insets.trailing - viewportSize.width
        guard range > 1 else { self.init(); return }
        self.init(leading: progress > 1, trailing: progress < range - 1)
    }

    /// Read from the row's own content, inside the scroll view: an end counts once more than a point of the
    /// content lies past the scroll view's visible edge. Content margins are not content, so a row resting
    /// against either end (its last chip at the margin) is solid there.
    init(content proxy: GeometryProxy, direction: LayoutDirection) {
        guard let viewport = proxy.bounds(of: .scrollView) else {
            self.init()
            return
        }
        self.init(viewport: viewport, contentWidth: proxy.size.width, direction: direction)
    }

    /// Physical viewport bounds inside the content coordinate space (independent of its text direction).
    init(viewport: CGRect, contentWidth: CGFloat, direction: LayoutDirection) {
        self.init(physicalLeft: viewport.minX > 1, physicalRight: viewport.maxX < contentWidth - 1,
                  direction: direction)
    }
}

/// The mask: solid, easing to clear across the last `leading` or `trailing` points of an end with more past it.
/// The ramp follows a smoothstep, so the very edge is all but clear (no line where the row is cut) and the
/// chips inside it dim gradually rather than all at once. An end with nothing past it stays solid; the ramp
/// cross-fades in and out rather than changing width, so nothing in the row moves.
struct EdgeFadeMask: View {
    var overflow: EdgeOverflow
    var leading: CGFloat = 52
    var trailing: CGFloat = 52
    @Environment(\.layoutDirection) private var direction

    /// How wide an end's fade is for a row drawn `bleed` points past its container: over the bleed (the
    /// gutter, or a card's inset) and a little way into the content, so a chip passing under the edge
    /// dissolves over about its own width.
    static func width(bleed: CGFloat) -> CGFloat { max(36, bleed + 32) }

    var body: some View {
        // Gradient UnitPoint coordinates are physical. Fix only this internal mask layout to
        // LTR and explicitly map semantic widths/flags; never mirror a one-sided ramp twice.
        let rtl = direction == .rightToLeft
        HStack(spacing: 0) {
            ramp(fromLeft: true, faded: rtl ? overflow.trailing : overflow.leading)
                .frame(width: rtl ? trailing : leading)
            Rectangle().fill(.black)
            ramp(fromLeft: false, faded: rtl ? overflow.leading : overflow.trailing)
                .frame(width: rtl ? leading : trailing)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func ramp(fromLeft: Bool, faded: Bool) -> some View {
        ZStack {
            LinearGradient(stops: Self.stops,
                           startPoint: UnitPoint(x: fromLeft ? 0 : 1, y: 0.5),
                           endPoint: UnitPoint(x: fromLeft ? 1 : 0, y: 0.5))
            Rectangle().fill(.black).opacity(faded ? 0 : 1)
        }
    }

    /// Clear at the edge to solid inward, eased (3t² − 2t³).
    private static let stops: [Gradient.Stop] = (0...8).map { (step: Int) -> Gradient.Stop in
        let t = Double(step) / 8
        return Gradient.Stop(color: Color.black.opacity(t * t * (3 - 2 * t)), location: CGFloat(t))
    }
}

extension View {
    /// Fades the ends of a horizontally scrolling row while chips hide past them. Apply it to the row's
    /// ScrollView (an `EdgeRail` fades itself). `bleed` is how far the row draws past its own frame, so the
    /// fade lands on the edge where the chips actually disappear; `width` is how far each fade reaches in from
    /// that edge (by default over the bleed and a little way into the content).
    func edgeFade(bleed: CGFloat = 0, width: CGFloat? = nil) -> some View {
        modifier(EdgeFade(bleed: bleed, width: width ?? EdgeFadeMask.width(bleed: bleed)))
    }
}

private struct EdgeFade: ViewModifier {
    let bleed: CGFloat
    let width: CGFloat
    @State private var overflow = EdgeOverflow()
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: EdgeOverflow.self) { geometry in
                EdgeOverflow(geometry, direction: direction)
            } action: { _, value in
                overflow = value
            }
            .mask {
                EdgeFadeMask(overflow: overflow, leading: width, trailing: width)
                    .animation(Motion.quick, value: overflow)
                    // Reaches over the bleed, and well above and below so a pressed chip's scale, a raised
                    // chip's shadow or a badge on its shoulder isn't clipped.
                    .padding(.horizontal, -bleed)
                    .padding(.vertical, -24)
            }
    }
}
