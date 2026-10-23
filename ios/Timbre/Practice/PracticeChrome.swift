import SwiftUI

// Scroll chrome shared by the practice tools and the instrument screens: edge-to-edge chip rails,
// a soft shade where content slides under the status bar, and a dock for pinned controls.

/// A horizontal rail of chips or cards that runs past its container's padding to the edge, so items
/// scroll under the edge instead of being cut at the padding. `bleed` is that padding (the screen gutter,
/// or a card's inset); the first item still lines up with the content around the rail. An edge fades
/// while more is hidden past it, and the selected item is brought into view when the rail appears and
/// whenever the selection changes. Give each item `.id(value)` with the same type as `selection`.
struct EdgeRail<ID: Hashable, Content: View>: View {
    var bleed: CGFloat = Metrics.gutter
    var spacing: CGFloat = 8
    var selection: ID?
    @ViewBuilder var content: Content

    @State private var position: ID?
    @State private var revealed = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) { content }
                .scrollTargetLayout()
        }
        // The first reveal centres the selection; later ones scroll only as far as needed.
        .scrollPosition(id: $position, anchor: revealed ? nil : .center)
        .railBleed(leading: bleed, trailing: bleed)
        .onAppear(perform: reveal)
        .onChange(of: selection) { _, value in
            guard let value else { return }
            withAnimation(Motion.settle) { position = value }
        }
    }

    private func reveal() {
        guard !revealed else { return }
        position = selection
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            revealed = true
        }
    }
}

extension View {
    /// For a horizontal ScrollView: extends it `leading`/`trailing` points past its container with matching
    /// content margins, so content rests aligned but scrolls on to the edge, and fades an edge while
    /// content is hidden past it.
    func railBleed(leading: CGFloat, trailing: CGFloat) -> some View {
        modifier(RailBleed(leading: leading, trailing: trailing))
    }

    /// Shades the status bar (and bar) area once a vertical ScrollView's content scrolls beneath it.
    /// Apply directly to the ScrollView.
    func stageTopShade() -> some View { modifier(StageTopShade()) }

    /// Pins controls to the bottom on a stage-coloured dock with a short fade above it. The scroll
    /// content is inset by the dock, so nothing ends up hidden beneath it.
    func stageDock<Dock: View>(@ViewBuilder _ dock: () -> Dock) -> some View {
        let bar = dock()
        return safeAreaInset(edge: .bottom, spacing: 0) {
            bar
                .padding(.horizontal, Metrics.gutter).padding(.top, 8).padding(.bottom, 6)
                .background { StageDockBackdrop() }
        }
    }
}

/// Which ends of a horizontal rail have content hidden past them.
private struct HiddenEdges: Equatable {
    var leading = false
    var trailing = false

    init() {}

    init(_ geometry: ScrollGeometry) {
        let offset = geometry.contentOffset.x + geometry.contentInsets.leading
        let range = geometry.contentSize.width + geometry.contentInsets.leading + geometry.contentInsets.trailing - geometry.containerSize.width
        leading = offset > 1
        trailing = offset < range - 1
    }
}

private struct RailBleed: ViewModifier {
    let leading: CGFloat
    let trailing: CGFloat
    @State private var hidden = HiddenEdges()

    func body(content: Content) -> some View {
        content
            .contentMargins(.leading, leading, for: .scrollContent)
            .contentMargins(.trailing, trailing, for: .scrollContent)
            .onScrollGeometryChange(for: HiddenEdges.self) { geometry in
                HiddenEdges(geometry)
            } action: { _, edges in
                hidden = edges
            }
            .mask { fadeMask }
            .padding(.leading, -leading)
            .padding(.trailing, -trailing)
    }

    private var fadeMask: some View {
        HStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                Color.black.opacity(hidden.leading ? 0 : 1)
            }
            .frame(width: max(24, leading + 12))
            Color.black
            ZStack {
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                Color.black.opacity(hidden.trailing ? 0 : 1)
            }
            .frame(width: max(24, trailing + 12))
        }
        .animation(Motion.quick, value: hidden)
    }
}

private struct StageTopShade: ViewModifier {
    @State private var scrolled = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 2
            } action: { _, value in
                scrolled = value
            }
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    LinearGradient(stops: [
                        .init(color: Palette.stage, location: 0),
                        .init(color: Palette.stage.opacity(0.88), location: 0.55),
                        .init(color: Palette.stage.opacity(0), location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                    .frame(width: proxy.size.width, height: proxy.safeAreaInsets.top + 14)
                }
                .ignoresSafeArea(edges: .top)
                .opacity(scrolled ? 1 : 0)
                .animation(Motion.quick, value: scrolled)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

private struct StageDockBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
            Palette.stage.opacity(0.96)
        }
        .padding(.top, -24)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
