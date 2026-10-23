import CoreGraphics
import Foundation
import simd
import TimbreCore

/// Animation anchors exported with each 3D model (tools/models/build_assets.py).
/// Coordinates are metres in the model's USD stage space (Y up, +Z toward the player).
struct InstrumentRig: Decodable, Sendable {
    struct StringRig: Decodable, Sendable {
        let anchor: String
        let saddle: [Float]
        let nut: [Float]
        let radius: Float
        let wound: Bool
        let peg: String
        let post: String
        let pegCenter: [Float]
        let pegAxis: [Float]
        let tighten: Int
        var saddlePoint: SIMD3<Float> { SIMD3(rig: saddle) }
        var nutPoint: SIMD3<Float> { SIMD3(rig: nut) }
        var pegPoint: SIMD3<Float> { SIMD3(rig: pegCenter) }
    }
    let model: String
    let rig: String
    let degPerCent: Float
    let strings: [StringRig]
    let headCenter: [Float]
    let bodyCenter: [Float]
    let length: Float
    let boundsMin: [Float]
    let boundsMax: [Float]
    /// Normalised (0...1, top-left origin) positions on the studio card render.
    let card2D: [String: [Double]]?

    var head: SIMD3<Float> { SIMD3(rig: headCenter) }
    var lower: SIMD3<Float> { SIMD3(rig: boundsMin) }
    var upper: SIMD3<Float> { SIMD3(rig: boundsMax) }
    func string(_ anchor: String?) -> StringRig? { strings.first { $0.anchor == anchor } }
    func card(_ key: String) -> CGPoint? {
        guard let p = card2D?[key], p.count == 2 else { return nil }
        return CGPoint(x: p[0], y: p[1])
    }
}

private extension SIMD3 where Scalar == Float {
    init(rig array: [Float]) { self.init(array.count > 0 ? array[0] : 0, array.count > 1 ? array[1] : 0, array.count > 2 ? array[2] : 0) }
}

/// Bundled models, rigs and studio renders. A photo variant maps to a model id.
enum ModelLibrary {
    private struct Manifest: Decodable { let photos: [String: String] }
    private static let manifest: Manifest? = {
        guard let url = Bundle.main.url(forResource: "models-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }()
    private static var rigs: [String: InstrumentRig] = [:]

    static func modelID(forPhoto asset: String?) -> String? {
        guard let asset, let id = manifest?.photos[asset], url(id) != nil else { return nil }
        return id
    }
    static func url(_ id: String) -> URL? { Bundle.main.url(forResource: id, withExtension: "usdz") }
    @MainActor static func rig(_ id: String) -> InstrumentRig? {
        if let cached = rigs[id] { return cached }
        guard let url = Bundle.main.url(forResource: id, withExtension: "rig.json"),
              let data = try? Data(contentsOf: url), let rig = try? JSONDecoder().decode(InstrumentRig.self, from: data) else { return nil }
        rigs[id] = rig
        return rig
    }
    /// Studio render used for cards and the 2D stage.
    static func cardImageName(_ id: String) -> String { "render_\(id)" }
}
