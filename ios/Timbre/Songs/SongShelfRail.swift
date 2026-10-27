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

    // A stable item identity, not a pixel offset or a delayed scrollTo, survives lazy layout
    // changes on rotation. SwiftUI updates this binding as the user browses.
    @State private var position = ScrollPosition(idType: Item.ID.self)
    @State private var initialized = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Track the logical trailing item in either language direction. At the catalogue end
        // this is the terminal record, rather than its neighbour nearest the viewport centre.
        .scrollPosition($position, anchor: .trailing)
        .railBleed(leading: Metrics.gutter, trailing: Metrics.gutter)
        .frame(height: height)
        .accessibilityIdentifier(identity)
        .onAppear {
            guard !initialized else { return }
            initialized = true
            if let selection { position.scrollTo(id: selection, anchor: .center) }
        }
        .onChange(of: selection) { _, value in
            guard let value else { return }
            withAnimation(reduceMotion ? nil : Motion.settle) {
                position.scrollTo(id: value, anchor: .center)
            }
        }
    }
}
