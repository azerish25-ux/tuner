import SwiftUI

/// Long catalogue rows virtualize cards, unlike the short chip rails in `EdgeRail`.
/// The complete collection remains in ForEach: scrolling/VoiceOver can realize every item.
/// `height` is the maximum measured production caption plus its sleeve, not the first visible cell's height.
struct SongShelfRail<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let selection: Item.ID?
    let itemWidth: CGFloat
    let height: CGFloat
    let identity: String
    @ViewBuilder let content: (Item) -> Content

    @State private var viewport: CGFloat = 0
    @State private var revealed = false
    @State private var browsed = false
    @State private var trackingBrowse = false
    @State private var visible: [Item.ID] = []
    @State private var browsedAnchor: Item.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: itemWidth, alignment: .topLeading)
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .frame(height: height, alignment: .top)
            }
            // ScrollGeometry measures the full lazy content extent without instantiating every card.
            .railBleed(leading: Metrics.gutter, trailing: Metrics.gutter)
            .frame(height: height)
            .accessibilityIdentifier(identity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width.rounded() } action: { width in
                let resized = abs(width - viewport) > 1
                viewport = width
                if resized && !browsed { revealed = false }
                if resized, browsed, let anchor = browsedAnchor {
                    // Preserve an actual browsed item, not its old pixel offset, when card widths change.
                    DispatchQueue.main.async { scroller.scrollTo(anchor, anchor: .center) }
                } else { reveal(scroller) }
            }
            .onScrollTargetVisibilityChange(idType: Item.ID.self, threshold: 0.9) { ids in
                visible = ids
                if trackingBrowse { rememberBrowse(ids) }
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { browsed = true }
                trackingBrowse = phase == .interacting || phase == .decelerating
                if phase == .idle && browsed { rememberBrowse(visible) }
            }
            .onAppear { reveal(scroller) }
            .onChange(of: selection) { _, value in
                guard let value else { return }
                browsed = false
                DispatchQueue.main.async {
                    withAnimation(reduceMotion ? nil : Motion.settle) {
                        scroller.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
    }

    private func rememberBrowse(_ ids: [Item.ID]) {
        // Data order works in both layout directions; a terminal card remains the anchor at that end.
        if let item = items.last(where: { ids.contains($0.id) }) { browsedAnchor = item.id }
    }

    private func reveal(_ scroller: ScrollViewProxy) {
        guard !revealed, viewport >= 88, let selection else { return }
        revealed = true
        DispatchQueue.main.async { scroller.scrollTo(selection, anchor: .center) }
    }
}
