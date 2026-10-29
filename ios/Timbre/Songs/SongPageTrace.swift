#if DEBUG
import Foundation
import SwiftUI

/// Passive, opt-in observations only. No observable state, scroll command, accessibility override or release code.
enum SongPageTrace {
    static let enabled = TestSupport.isOn(.songPageTrace) && TestSupport.storageRoot != nil
    private static let recorder: Recorder? = enabled ? Recorder() : nil

    struct Geometry: Equatable, Encodable {
        let container: [Double]
        let content: [Double]
        let offset: [Double]
        let insets: [Double]
        let visible: [Double]
        init(_ value: ScrollGeometry) {
            container = [Double(value.containerSize.width), Double(value.containerSize.height)]
            content = [Double(value.contentSize.width), Double(value.contentSize.height)]
            offset = [Double(value.contentOffset.x), Double(value.contentOffset.y)]
            insets = [value.contentInsets.top, value.contentInsets.leading,
                      value.contentInsets.bottom, value.contentInsets.trailing].map(Double.init)
            let rect = value.visibleRect
            visible = [rect.minX, rect.minY, rect.width, rect.height].map(Double.init)
        }
    }

    static func record(_ kind: String, position: String, oldPosition: String? = nil,
                       geometry: Geometry? = nil, oldPhase: String? = nil, phase: String? = nil) {
        recorder?.record(kind, position: position, oldPosition: oldPosition,
                         geometry: geometry, oldPhase: oldPhase, phase: phase)
    }

    private struct Event: Encodable {
        let schema = 1
        let diagnosticOnly = true
        let sessionID: String
        let sequence: Int
        let segment: Int
        let wallTimeUTC: Double
        let uptimeSeconds: Double
        let kind: String
        let position: String
        let oldPosition: String?
        let geometry: Geometry?
        let oldPhase: String?
        let phase: String?
        let observation = "Passive SwiftUI callbacks; onChange can coalesce; not exhaustive binding setters"
    }

    /// Lock protects file and counters without publishing state back into the view hierarchy.
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private let sessionID: String
        private let current: URL
        private let previous: URL
        private var handle: FileHandle?
        private var bytes = 0
        private var sequence = 0
        private var segment = 0
        private static let maximumBytes = 4 * 1024 * 1024

        init?() {
            guard let root = TestSupport.storageRoot, let sessionID = TestSupport.value(.storageID),
                  UUID(uuidString: sessionID) != nil else { return nil }
            self.sessionID = sessionID
            current = root.appendingPathComponent("song-page-trace.ndjson")
            previous = root.appendingPathComponent("song-page-trace.previous.ndjson")
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                try Data().write(to: current, options: .atomic)
                handle = try FileHandle(forWritingTo: current)
            } catch {
                NSLog("Song page diagnostic file could not be opened; trace is incomplete: %@", String(describing: error))
                return nil
            }
        }

        func record(_ kind: String, position: String, oldPosition: String?,
                    geometry: Geometry?, oldPhase: String?, phase: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard handle != nil else { return }
            sequence += 1
            do {
                func encoded() throws -> Data {
                    let event = Event(sessionID: sessionID, sequence: sequence, segment: segment,
                        wallTimeUTC: Date().timeIntervalSince1970, uptimeSeconds: ProcessInfo.processInfo.systemUptime,
                        kind: kind, position: position, oldPosition: oldPosition, geometry: geometry,
                        oldPhase: oldPhase, phase: phase)
                    var data = try JSONEncoder().encode(event)
                    data.append(10)
                    return data
                }
                var data = try encoded()
                if bytes + data.count > Self.maximumBytes {
                    try handle?.close()
                    if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
                    try FileManager.default.moveItem(at: current, to: previous)
                    try Data().write(to: current, options: .atomic)
                    handle = try FileHandle(forWritingTo: current)
                    bytes = 0
                    segment += 1
                    data = try encoded()
                }
                guard data.count <= Self.maximumBytes else { throw CocoaError(.fileWriteOutOfSpace) }
                try handle?.write(contentsOf: data)
                bytes += data.count
            } catch {
                try? handle?.close()
                handle = nil
                NSLog("Song page diagnostic recording stopped; trace is incomplete: %@", String(describing: error))
            }
        }
    }
}
#endif
