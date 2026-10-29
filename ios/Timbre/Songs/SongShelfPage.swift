import SwiftUI

/// The collection identity and the scroll binding must agree, including the two non-shelf rows.
/// Song IDs belong to the nested horizontal rails, not this vertical page.
enum SongShelfPageTarget<ID: Hashable & Sendable>: Hashable, Sendable {
    case introduction
    case shelf(ID)
    case request
}

/// A size-change command is separate from the binding's constant-center tracking policy.
/// Geometry is a current sample, not a promise that lazy content has finished remeasuring.
struct SongShelfPageResize<ID: Hashable & Sendable> {
    struct Measurement: Equatable, Sendable {
        let rowSize: CGSize
        let viewport: CGSize
        let generation: Int
    }

    private(set) var viewport: CGSize = .zero
    private(set) var generation = 0
    private(set) var target: SongShelfPageTarget<ID>?
    private var userScrolling = false

    mutating func resized(to size: CGSize, position: SongShelfPageTarget<ID>?) {
        guard size != viewport else { return }
        let previous = viewport
        viewport = size
        generation += 1
        // Initial appearance and missing geometry are not navigation commands.
        guard !userScrolling, Self.valid(previous), Self.valid(size), case .some(.shelf(_)) = position else {
            target = nil
            return
        }
        // Only full-width shelf rows participate. Intrinsic introduction/footer layout is unchanged.
        target = position
    }

    mutating func cancel() { target = nil }

    mutating func disappeared() {
        cancel()
        userScrolling = false
    }

    mutating func userScrollChanged(_ active: Bool) {
        userScrolling = active
        if active { cancel() }
    }

    mutating func consume(for id: SongShelfPageTarget<ID>, measurement: Measurement) -> UnitPoint? {
        guard !userScrolling, target == id, measurement.generation == generation, measurement.viewport == viewport,
              Self.valid(measurement.rowSize), Self.valid(viewport),
              abs(measurement.rowSize.width - (viewport.width - 2 * Metrics.gutter)) <= 1 else { return nil }
        // Consume before invoking SwiftUI: command-generated geometry cannot replay the command.
        target = nil
        return measurement.rowSize.height > viewport.height ? .top : .center
    }

    private static func valid(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }
}

/// A stable vertical browsing position, independent of each shelf's horizontal song selection.
struct SongShelfPage<Item: Identifiable, Introduction: View, Content: View, Footer: View>: View where Item.ID: Sendable {
    let items: [Item]
    @Binding var position: SongShelfPageTarget<Item.ID>?
    @State private var resize = SongShelfPageResize<Item.ID>()
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
        let measuredViewport = resize.viewport
        let measuredGeneration = resize.generation
        ScrollViewReader { proxy in
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
                        .onGeometryChange(for: SongShelfPageResize<Item.ID>.Measurement.self) { geometry in
                            .init(rowSize: geometry.size, viewport: measuredViewport, generation: measuredGeneration)
                        } action: { measurement in
                            guard let anchor = resize.consume(for: row.id, measurement: measurement) else { return }
                            var transaction = Transaction(animation: nil)
                            transaction.disablesAnimations = true
                            withTransaction(transaction) { proxy.scrollTo(row.id, anchor: anchor) }
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .scrollPosition(id: $position, anchor: .center)
            .onScrollGeometryChange(for: CGSize.self) { $0.containerSize } action: { _, size in
                resize.resized(to: size, position: position)
            }
            .onScrollPhaseChange { _, phase in
                resize.userScrollChanged(phase == .tracking || phase == .interacting || phase == .decelerating)
            }
            .onChange(of: position) { _, value in
                if let target = resize.target, value != target { resize.cancel() }
            }
            .onChange(of: items.map(\.id)) { _, _ in resize.cancel() }
            .onDisappear { resize.disappeared() }
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
}
