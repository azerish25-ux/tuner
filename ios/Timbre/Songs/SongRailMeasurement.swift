import SwiftUI
import UIKit

/// Caption-only sizing. Each sizing batch reuses one off-window host, then releases it; cache entries contain
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
    private(set) var measurementCount = 0
    private(set) var lastDuration: TimeInterval = 0
    var entryCount: Int { entries.count }

    func maximum<Caption: View>(key: Key, count: Int, @ViewBuilder caption: (Int) -> Caption) -> CGFloat {
        if let entry = entries.first(where: { $0.key == key }) { return entry.height }
        #if DEBUG
        Self.trace("sizing-batch-begin", position: "count=\(count) width=\(key.width) type=\(key.typeSize)")
        #endif
        let started = Date()
        var height: CGFloat = 0
        if count > 0 {
            // Keep one hosting controller only for this batch. A fresh identity for every root resets
            // SwiftUI state exactly as constructing separate hosts did; no root ever enters a window.
            height = autoreleasepool {
                #if DEBUG
                Self.trace("sizing-host-begin", position: "type=\(key.typeSize)")
                #endif
                let host = UIHostingController(rootView: Self.root(caption(0), key: key, identity: 0))
                #if DEBUG
                Self.trace("sizing-host-end", position: "type=\(key.typeSize)")
                #endif
                hostCount += 1
                var maximum: CGFloat = 0
                for index in 0..<count {
                    if index > 0 {
                        #if DEBUG
                        Self.trace("sizing-root-begin", position: "index=\(index) type=\(key.typeSize)")
                        #endif
                        host.rootView = Self.root(caption(index), key: key, identity: index)
                        #if DEBUG
                        Self.trace("sizing-root-end", position: "index=\(index) type=\(key.typeSize)")
                        #endif
                    }
                    #if DEBUG
                    Self.trace("sizing-fit-begin", position: "index=\(index) type=\(key.typeSize)")
                    let fitStarted = Self.probeEnabled ? ProcessInfo.processInfo.systemUptime : 0
                    #endif
                    let size = host.sizeThatFits(in: CGSize(width: key.width, height: .greatestFiniteMagnitude))
                    #if DEBUG
                    let fitDuration = Self.probeEnabled ? ProcessInfo.processInfo.systemUptime - fitStarted : 0
                    Self.trace("sizing-fit-end", position: "index=\(index) type=\(key.typeSize) measuredSeconds=\(fitDuration)")
                    #endif
                    measurementCount += 1
                    maximum = max(maximum, size.height)
                }
                return maximum
            }
        }
        let scale = max(1, key.scale)
        height = ceil(height * scale) / scale
        if entries.count >= Self.capacity { entries.removeFirst() }
        entries.append(Entry(key: key, height: height))
        lastDuration = Date().timeIntervalSince(started)
        #if DEBUG
        Self.trace("sizing-batch-end", position: "count=\(count) width=\(key.width) type=\(key.typeSize) seconds=\(lastDuration)")
        print("SONG-RAIL sizing: captions=\(count) hosts=\(hostCount) measurements=\(measurementCount) seconds=\(lastDuration) height=\(height) width=\(key.width) type=\(key.typeSize)")
        #endif
        return height
    }

    #if DEBUG
    private static let probeEnabled = TestSupport.isOn(.songSizingProbe)
    // Direct fit durations exclude trace encoding/writes. Total probe runtime remains instrumented.
    private static func trace(_ kind: String, position: @autoclosure () -> String) {
        guard probeEnabled else { return }
        SongPageTrace.record(kind, position: position())
    }
    #endif

    private static func root<Caption: View>(_ caption: Caption, key: Key, identity: Int) -> some View {
        caption
            .id(identity)
            .environment(\.locale, Locale(identifier: key.locale))
            .environment(\.layoutDirection, key.direction)
            .environment(\.dynamicTypeSize, key.typeSize)
            .environment(\.legibilityWeight, key.legibility)
            .environment(\.displayScale, key.scale)
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
