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
    /// Read from a horizontal scroll view (content margins included): an end counts once more than a point hides past it.
    init(_ geometry: ScrollGeometry) {
        let offset = geometry.contentOffset.x + geometry.contentInsets.leading
        let range = geometry.contentSize.width + geometry.contentInsets.leading + geometry.contentInsets.trailing - geometry.containerSize.width
        self.init(leading: offset > 1, trailing: offset < range - 1)
    }

    /// Read from the row's own content, inside the scroll view: an end counts once more than a point of the
    /// content lies past the scroll view's visible edge. Content margins are not content, so a row resting
    /// against either end (its last chip at the margin) is solid there.
    init(content proxy: GeometryProxy) {
        guard let viewport = proxy.bounds(of: .scrollView) else {
            self.init()
            return
        }
        self.init(leading: viewport.minX > 1, trailing: viewport.maxX < proxy.size.width - 1)
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

    /// How wide an end's fade is for a row drawn `bleed` points past its container: over the bleed (the
    /// gutter, or a card's inset) and a little way into the content, so a chip passing under the edge
    /// dissolves over about its own width.
    static func width(bleed: CGFloat) -> CGFloat { max(36, bleed + 32) }

    var body: some View {
        HStack(spacing: 0) {
            ramp(fromLeading: true, faded: overflow.leading).frame(width: leading)
            Rectangle().fill(.black)
            ramp(fromLeading: false, faded: overflow.trailing).frame(width: trailing)
        }
    }

    private func ramp(fromLeading: Bool, faded: Bool) -> some View {
        ZStack {
            LinearGradient(stops: Self.stops,
                           startPoint: fromLeading ? .leading : .trailing,
                           endPoint: fromLeading ? .trailing : .leading)
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

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: EdgeOverflow.self) { geometry in
                EdgeOverflow(geometry)
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
