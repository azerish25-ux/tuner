import Combine
import RealityKit
import SwiftUI
import UIKit
import simd

// What the tuner's stage (`StageController`) and the lessons' "Show me" stage (`ShowMeController`) share.

/// The glow along a ringing or locked string: one continuous tube, widest at the middle of the string and narrowing
/// toward its ends, as a vibrating string's blur does, drawn in one piece so its light never doubles up where pieces
/// would meet. Its mesh is built once and stretched along each string.
@MainActor
enum StringGlow {
    private static var cached: MeshResource?

    /// The tube along +Y, one unit long and one unit in radius at its widest.
    static func mesh() -> MeshResource {
        if let cached { return cached }
        let mesh = build() ?? MeshResource.generateCylinder(height: 1, radius: 1)
        cached = mesh
        return mesh
    }

    /// A glow of `color`, see-through at `opacity`.
    static func material(_ color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    /// Lays `entity` (made with `mesh()`) along a string from `p` to `q`, `radius` at its widest.
    static func place(_ entity: ModelEntity, from p: SIMD3<Float>, to q: SIMD3<Float>, radius: Float) {
        let length = simd_length(q - p)
        guard length > 1e-5, radius > 0 else {
            entity.isEnabled = false
            return
        }
        entity.isEnabled = true
        entity.position = (p + q) / 2
        entity.orientation = simd_quatf(from: [0, 1, 0], to: (q - p) / length)
        entity.scale = [radius, length, radius]
    }

    private static func build() -> MeshResource? {
        let rings = 24
        let sides = 14
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let radius = 0.42 + 0.58 * sin(Float.pi * v).squareRoot()
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * Float.pi
                let normal = SIMD3<Float>(cos(angle), 0, sin(angle))
                positions.append(SIMD3<Float>(normal.x * radius, v - 0.5, normal.z * radius))
                normals.append(normal)
            }
        }
        for ring in 0..<rings {
            for side in 0..<sides {
                let a = UInt32(ring * sides + side)
                let b = UInt32(ring * sides + (side + 1) % sides)
                let c = a + UInt32(sides)
                let d = b + UInt32(sides)
                indices += [a, c, b, b, c, d]
            }
        }
        var descriptor = MeshDescriptor(name: "stage.stringGlow")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }
}

extension Entity {
    /// Lights this entity and everything under it with `light`'s image-based light (when it has one).
    @MainActor func receiveImageBasedLight(from light: Entity) {
        guard light.components.has(ImageBasedLightComponent.self) else { return }
        components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        for child in children { child.receiveImageBasedLight(from: light) }
    }
}

/// Whether the device should be spared the 3D stages now: Low Power Mode, or a hot device. The stages fall back to
/// their pictures meanwhile, and come back when it passes.
@MainActor
final class StagePower: ObservableObject {
    static let shared = StagePower()

    @Published private(set) var reduced: Bool
    private var observers: [NSObjectProtocol] = []

    private init() {
        reduced = Self.currentlyReduced
        let center = NotificationCenter.default
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
    }

    /// Low Power Mode is on, or the device is hot.
    nonisolated static var currentlyReduced: Bool {
        let info = ProcessInfo.processInfo
        return info.isLowPowerModeEnabled || info.thermalState == .serious || info.thermalState == .critical
    }

    private func refresh() {
        let now = Self.currentlyReduced
        if now != reduced { reduced = now }
    }
}
