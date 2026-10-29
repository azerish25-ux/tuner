import SwiftUI

/// Long catalogue rows virtualize cards, unlike the short chip rails in `EdgeRail`.
/// The complete collection remains in ForEach: scrolling/VoiceOver can realize every item.
/// `height` is the maximum measured production caption plus its sleeve, not the first visible cell's height.
struct SongShelfRail<Item: Identifiable, Content: View>: View where Item.ID: Sendable {
    let items: [Item]
    let selection: Item.ID?
    let itemWidth: CGFloat
    let height: CGFloat
    let identity: String
    @ViewBuilder let content: (Item) -> Content

    // Interior positions follow item identity; catalogue ends follow a semantic edge through reflow.
    @State private var position = ScrollPosition(idType: Item.ID.self)
    @State private var initialized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var direction

    var body: some View {
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
        // Interior identity restoration must agree with the initial centered reveal.
        // Catalogue ends use explicit semantic edges, independent of this identity anchor.
        .scrollPosition($position, anchor: .center)
        .onScrollPhaseChange { _, phase, context in
            // Do not interrupt a gesture or replace an initial/programmatic interior selection.
            if phase == .idle && position.isPositionedByUser { retainUserEdge(context.geometry) }
        }
        .railBleed(leading: Metrics.gutter, trailing: Metrics.gutter)
        .frame(height: height)
        .accessibilityIdentifier(identity)
        .onAppear {
            guard !initialized else { return }
            initialized = true
            if let selection { reveal(selection) }
        }
        .onChange(of: selection) { _, value in
            guard let value else { return }
            withAnimation(reduceMotion ? nil : Motion.settle) {
                reveal(value)
            }
        }
    }

    private func reveal(_ value: Item.ID) {
        if value == items.first?.id { position.scrollTo(edge: .leading) }
        else if value == items.last?.id { position.scrollTo(edge: .trailing) }
        else { position.scrollTo(id: value, anchor: .center) }
    }

    private func retainUserEdge(_ geometry: ScrollGeometry) {
        let overflow = EdgeOverflow(geometry, direction: direction)
        // Both false means short content; both true means an interior browsing position.
        guard overflow.leading != overflow.trailing else { return }
        let edge: Edge = overflow.leading ? .trailing : .leading
        if position.edge != edge { position.scrollTo(edge: edge) }
    }
}
