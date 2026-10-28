import SwiftUI

/// The collection identity and the scroll binding must agree, including the two non-shelf rows.
/// Song IDs belong to the nested horizontal rails, not this vertical page.
enum SongShelfPageTarget<ID: Hashable & Sendable>: Hashable, Sendable {
    case introduction
    case shelf(ID)
    case request
}

/// A stable vertical browsing position, independent of each shelf's horizontal song selection.
struct SongShelfPage<Item: Identifiable, Introduction: View, Content: View, Footer: View>: View where Item.ID: Sendable {
    let items: [Item]
    @Binding var position: SongShelfPageTarget<Item.ID>?
    @ViewBuilder let introduction: () -> Introduction
    @ViewBuilder let shelf: (Item) -> Content
    @ViewBuilder let footer: () -> Footer

    private enum Row: Identifiable {
        case introduction
        case shelf(Item)
        case request

        var id: SongShelfPageTarget<Item.ID> {
            switch self {
            case .introduction: return .introduction
            case .shelf(let item): return .shelf(item.id)
            case .request: return .request
            }
        }
    }

    private var rows: [Row] { [.introduction] + items.map { Row.shelf($0) } + [.request] }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // One concrete scroll target per lazy row. The explicit target uses exactly
                // the same typed key as ForEach, not a nested song ID or a second key type.
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 0) {
                        switch row {
                        case .introduction: introduction()
                        case .shelf(let item): shelf(item)
                        case .request: footer()
                        }
                    }
                    .id(row.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
        }
        .scrollPosition(id: $position, anchor: .center)
        #if DEBUG
        .onAppear { SongPageTrace.record("appear", position: String(describing: position)) }
        .onDisappear { SongPageTrace.record("disappear", position: String(describing: position)) }
        .onChange(of: position) { old, new in
            SongPageTrace.record("position-observed", position: String(describing: new), oldPosition: String(describing: old))
        }
        .onScrollGeometryChange(for: SongPageTrace.Geometry?.self) { geometry in
            SongPageTrace.enabled ? SongPageTrace.Geometry(geometry) : nil
        } action: { _, geometry in
            guard let geometry else { return }
            SongPageTrace.record("geometry", position: String(describing: position), geometry: geometry)
        }
        .onScrollPhaseChange { old, new, context in
            guard SongPageTrace.enabled else { return }
            SongPageTrace.record("phase", position: String(describing: position), geometry: SongPageTrace.Geometry(context.geometry),
                                 oldPhase: String(describing: old), phase: String(describing: new))
        }
        #endif
    }
}
