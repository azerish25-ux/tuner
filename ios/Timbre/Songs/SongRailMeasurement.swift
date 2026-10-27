import SwiftUI
import UIKit

/// Caption-only sizing. Hosts are never attached to a window or retained; cache entries contain
/// value-type input signatures and heights only. No cover, playback control or menu is evaluated here.
@MainActor
final class SongRailMeasurement {
    struct Key: Equatable {
        var content: [String]
        var width: CGFloat
        var locale: String
        var language: String
        var typeSize: DynamicTypeSize
        var direction: LayoutDirection
        var legibility: LegibilityWeight?
        var bold: Bool
        var scale: CGFloat
    }

    private struct Entry {
        let key: Key
        let height: CGFloat
    }
    private var entries: [Entry] = []
    static let capacity = 24
    private(set) var hostCount = 0
    private(set) var lastDuration: TimeInterval = 0
    var entryCount: Int { entries.count }

    func maximum<Caption: View>(key: Key, count: Int, @ViewBuilder caption: (Int) -> Caption) -> CGFloat {
        if let entry = entries.first(where: { $0.key == key }) { return entry.height }
        let started = Date()
        var height: CGFloat = 0
        for index in 0..<count {
            // Keep the host's lifetime to this iteration. Sizing never invokes appearance by installing a window.
            let size = autoreleasepool { Self.measure(caption(index), key: key) }
            hostCount += 1
            height = max(height, size.height)
        }
        let scale = max(1, key.scale)
        height = ceil(height * scale) / scale
        if entries.count >= Self.capacity { entries.removeFirst() }
        entries.append(Entry(key: key, height: height))
        lastDuration = Date().timeIntervalSince(started)
        #if DEBUG
        print("SONG-RAIL sizing: captions=\(count) hosts=\(hostCount) seconds=\(lastDuration) height=\(height) width=\(key.width) type=\(key.typeSize)")
        #endif
        return height
    }

    static func measure<Caption: View>(_ caption: Caption, key: Key) -> CGSize {
        let host = UIHostingController(rootView: caption
            .environment(\.locale, Locale(identifier: key.locale))
            .environment(\.layoutDirection, key.direction)
            .environment(\.dynamicTypeSize, key.typeSize)
            .environment(\.legibilityWeight, key.legibility)
            .environment(\.displayScale, key.scale))
        return host.sizeThatFits(in: CGSize(width: key.width, height: .greatestFiniteMagnitude))
    }
}
