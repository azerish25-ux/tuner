import RealityKit
import SwiftUI
import TimbreCore
import UIKit

/// What the stage needs each frame. Read from the live reading, never published.
struct StageInput {
    var cents: Double?
    var level: Double = -120
    var locked = false
    var listening = false
    var activeAnchor: String?
    var focus = false
}

/// Drives the live 3D instrument: camera framing, peg rotation following measured cents,
/// a vibrating string whose standing wave drifts with the pitch error and freezes in tune.
@MainActor
final class StageController {
    let root = Entity()
    let camera = PerspectiveCamera()
    private(set) var loadedModel: String?
    private var loading: String?
    /// Plain-text load state for diagnostics (shown only when TIMBRE_STAGE_DEBUG is set in debug builds).
    private(set) var status = "idle"
    private(set) var failed = false
    private var model: Entity?
    private var rig: InstrumentRig?
    private var pegs: [String: (entity: Entity, base: simd_quatf)] = [:]
    private var posts: [String: (entity: Entity, base: simd_quatf)] = [:]
    private var staticStrings: [String: Entity] = [:]
    private var segments: [ModelEntity] = []
    private var halo: [ModelEntity] = []
    private var subscription: EventSubscription?
    private let light = Entity()
    private var filter = OneEuroFilter(minCutoff: 1.1, beta: 0.02)
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.07)
    private var time: Double = 0
    private var energy: Float = 0
    private var glow: Float = 0
    private var angles: [String: Float] = [:]
    private var framing: Float = 0          // 0 = whole instrument, 1 = headstock close-up
    private var yaw: Float = -0.32
    private var aimPoint: SIMD3<Float>?
    private var previousLevel: Double = -120
    private var currentAnchor: String?
    var input: () -> StageInput = { StageInput() }
    private static let segmentCount = 36

    init() {
        camera.camera.fieldOfViewInDegrees = 30
        camera.position = .zero
        root.addChild(camera)
    }

    func attach(_ content: inout RealityViewCameraContent) {
        content.add(root)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.tick(Float(event.deltaTime)) }
        }
    }

    func load(modelID: String) async {
        guard loadedModel != modelID, loading != modelID else { return }
        guard let url = ModelLibrary.url(modelID) else { status = "no usdz for \(modelID)"; failed = true; return }
        guard let rig = ModelLibrary.rig(modelID) else { status = "no rig for \(modelID)"; failed = true; return }
        loading = modelID
        defer { loading = nil }
        status = "loading \(modelID)"
        let entity: Entity
        do { entity = try await Entity(contentsOf: url) } catch { status = "load failed: \(error.localizedDescription)"; failed = true; return }
        failed = false
        model?.removeFromParent()
        pegs = [:]; posts = [:]; staticStrings = [:]; angles = [:]
        segments.forEach { $0.removeFromParent() }; halo.forEach { $0.removeFromParent() }
        segments = []; halo = []
        let holder = Entity()
        holder.addChild(entity)
        root.addChild(holder)
        model = holder
        self.rig = rig
        loadedModel = modelID
        for string in rig.strings {
            if let peg = entity.findEntity(named: string.peg) {
                pegs[string.peg] = (peg, peg.orientation)
                peg.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.024)]))
                peg.components.set(InputTargetComponent())
            }
            if let post = entity.findEntity(named: string.post) { posts[string.peg] = (post, post.orientation) }
            if let line = entity.findEntity(named: string.nodeName) { staticStrings[string.nodeName] = line }
        }
        let mesh = MeshResource.generateCylinder(height: 1, radius: 1)
        var metal = PhysicallyBasedMaterial()
        metal.baseColor = .init(tint: UIColor(white: 0.86, alpha: 1))
        metal.metallic = 1.0; metal.roughness = 0.28
        var glowMaterial = UnlitMaterial(color: UIColor(red: 1, green: 0.86, blue: 0.62, alpha: 0.32))
        glowMaterial.blending = .transparent(opacity: 0.32)
        for _ in 0..<Self.segmentCount {
            let segment = ModelEntity(mesh: mesh, materials: [metal])
            segment.isEnabled = false
            holder.addChild(segment); segments.append(segment)
            let glowSegment = ModelEntity(mesh: mesh, materials: [glowMaterial])
            glowSegment.isEnabled = false
            holder.addChild(glowSegment); halo.append(glowSegment)
        }
        addLights()
        receiveImageBasedLight(holder)
        applyFraming(immediately: true)
        let box = holder.visualBounds(relativeTo: nil)
        func fmt(_ v: SIMD3<Float>) -> String { String(format: "%.2f,%.2f,%.2f", v.x, v.y, v.z) }
        status = "loaded \(modelID) pegs=\(pegs.count) strings=\(staticStrings.count) c=\(fmt(box.center)) e=\(fmt(box.extents)) ibl=\(light.components.has(ImageBasedLightComponent.self))"
    }

    /// Image-based light from the procedural stage environment, applied to every model part.
    func setEnvironment(_ resource: EnvironmentResource) {
        light.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.4))
        if light.parent == nil { root.addChild(light) }
        if let model { receiveImageBasedLight(model) }
    }

    private func receiveImageBasedLight(_ entity: Entity) {
        guard light.components.has(ImageBasedLightComponent.self) else { return }
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        for child in entity.children { receiveImageBasedLight(child) }
    }

    private func addLights() {
        guard root.findEntity(named: "stage.key") == nil else { return }
        let key = DirectionalLight()
        key.name = "stage.key"
        key.light.color = UIColor(red: 1, green: 0.88, blue: 0.74, alpha: 1)
        key.light.intensity = 2600
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
        key.look(at: [0, 0, -2], from: [-1.4, 1.8, 1.2], relativeTo: nil)
        root.addChild(key)
        let rim = DirectionalLight()
        rim.name = "stage.rim"
        rim.light.color = UIColor(red: 0.7, green: 0.82, blue: 1, alpha: 1)
        rim.light.intensity = 1500
        rim.look(at: [0, 0, -2], from: [1.6, 0.8, -4.2], relativeTo: nil)
        root.addChild(rim)
    }

    /// The camera stays at the origin looking down -Z; the instrument moves to be framed.
    /// This keeps framing correct whichever camera the view ends up using.
    private func applyFraming(immediately: Bool = false, dt: Float = 0) {
        guard let rig, let model else { return }
        let target: Float = input().focus ? 1 : 0
        framing = immediately ? target : framing + (target - framing) * min(1, dt * 2.6)
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let height = rig.upper.y - rig.lower.y
        let center = (rig.lower + rig.upper) / 2
        let wholeDistance = (height * 0.56) / tan(fov / 2)
        // Close-up aims between the head and the peg being tuned, gliding when the string changes.
        let head = rig.head
        var aim = head + SIMD3<Float>(0, -0.045, 0)
        if let anchor = currentAnchor ?? rig.strings.first?.anchor, let string = rig.string(anchor) {
            aim = head + (string.pegPoint - head) * 0.45 + SIMD3<Float>(0, -0.03, 0)
        }
        let previousAim = aimPoint ?? aim
        let focusPoint = immediately ? aim : previousAim + (aim - previousAim) * min(1, dt * 3)
        aimPoint = focusPoint
        let focusDistance: Float = max(0.34, height * 0.33)
        let point = simd_mix(center, focusPoint, SIMD3(repeating: framing))
        let distance = wholeDistance + (focusDistance - wholeDistance) * framing
        let targetYaw: Float = -0.32 - 0.22 * framing
        yaw = immediately ? targetYaw : yaw + (targetYaw - yaw) * min(1, dt * 2.6)
        let breathing = Float(sin(time * 0.35)) * 0.025 * (1 - framing)
        let rotation = simd_quatf(angle: yaw + breathing, axis: [0, 1, 0]) * simd_quatf(angle: 0.04 * (1 - framing), axis: [1, 0, 0])
        model.orientation = rotation
        model.position = -rotation.act(point) + SIMD3<Float>(0, 0, -distance)
    }

    func tick(_ dt: Float) {
        guard dt > 0 else { return }
        time += Double(dt)
        let state = input()
        applyFraming(dt: dt)
        guard let rig else { return }
        let anchor = state.activeAnchor ?? rig.strings.first?.anchor
        if anchor != currentAnchor {
            for string in rig.strings where string.anchor == currentAnchor { staticStrings[string.nodeName]?.isEnabled = true }
            currentAnchor = anchor
            filter.reset()
        }
        // Pluck energy: rises with the input level, decays like a string.
        let rising = state.level > previousLevel + 6 && state.level > -42
        previousLevel = state.level
        let target = state.listening ? Float(max(0, min(1, (state.level + 58) / 34))) : 0
        energy = rising ? max(energy, target) : max(target * 0.6, energy * exp(-dt * 1.4))
        let smoothed = state.cents.map { filter.filter(max(-60, min(60, $0)), at: time) }
        let phase = strobe.advance(cents: state.locked ? 0 : smoothed, dt: Double(dt))
        glow += ((state.locked ? 1 : 0) - glow) * min(1, dt * (state.locked ? 7 : 2.5))

        // Pegs: the active course's pegs (both of a pair) follow the pitch error; the rest ease home.
        for string in rig.strings {
            guard let peg = pegs[string.peg] else { continue }
            var goal: Float = 0
            if string.anchor == anchor, let smoothed {
                goal = Float(-smoothed) * rig.degPerCent * Float(string.tighten) * .pi / 180
            }
            let current = angles[string.peg] ?? 0
            let next = current + (goal - current) * min(1, dt * 9)
            angles[string.peg] = next
            peg.entity.orientation = peg.base * simd_quatf(angle: next, axis: [1, 0, 0])
            if let post = posts[string.peg] { post.entity.orientation = post.base * simd_quatf(angle: next / 6, axis: [0, 0, 1]) }
        }
        updateString(rig.string(anchor), phase: Float(phase), locked: state.locked, active: state.listening)
    }

    private func updateString(_ string: InstrumentRig.StringRig?, phase: Float, locked: Bool, active: Bool) {
        guard let string else { return }
        let visible = active && (energy > 0.02 || glow > 0.05)
        staticStrings[string.nodeName]?.isEnabled = !visible
        let a = string.saddlePoint, b = string.nutPoint
        let axis = simd_normalize(b - a)
        let lateral = simd_normalize(simd_cross(axis, [0, 0, 1]) + SIMD3<Float>(0, 0, 0.35))
        let amplitude = (0.0012 + 0.0042 * energy) * (1 - 0.85 * glow)
        let t = Float(time)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(Self.segmentCount + 1)
        for i in 0...Self.segmentCount {
            let u = Float(i) / Float(Self.segmentCount)
            let envelope = sin(.pi * u)
            // Slow-motion standing wave (fundamental + 2nd, 3rd partials) plus a strobe ripple.
            let standing = sin(2 * .pi * 1.7 * t) * envelope + 0.32 * sin(2 * .pi * u) * sin(2 * .pi * 3.4 * t + 0.6) + 0.18 * sin(3 * .pi * u) * sin(2 * .pi * 5.1 * t + 1.1)
            let ripple = 0.55 * sin(2 * .pi * (u * 7 - phase)) * envelope
            let offset = amplitude * (standing * (1 - glow) + ripple)
            points.append(a + (b - a) * u + lateral * offset)
        }
        let radius = string.radius * (1.25 + 0.6 * glow)
        for i in 0..<Self.segmentCount {
            let p = points[i], q = points[i + 1]
            let length = simd_length(q - p)
            let rotation = simd_quatf(from: [0, 1, 0], to: (q - p) / max(length, 1e-6))
            let segment = segments[i]
            segment.isEnabled = visible
            segment.position = (p + q) / 2
            segment.orientation = rotation
            segment.scale = [radius, length * 1.02, radius]
            let haloSegment = halo[i]
            haloSegment.isEnabled = visible && glow > 0.05
            haloSegment.position = segment.position
            haloSegment.orientation = rotation
            haloSegment.scale = [radius * (3 + 5 * glow), length * 1.02, radius * (3 + 5 * glow)]
        }
    }
}

/// SwiftUI host. Taps on a peg select its string.
struct InstrumentStage: View {
    let modelID: String
    let input: () -> StageInput
    var onSelect: (String) -> Void = { _ in }
    /// Called when the model cannot be shown, so the host can fall back to the studio stage.
    var onFailure: () -> Void = {}
    /// Called once the model is on stage (the host can retire its placeholder).
    var onReady: () -> Void = {}
    @State private var controller = StageController()
    @State private var ready = false
    @State private var status = "make"
    private let debug = ProcessInfo.processInfo.environment["TIMBRE_STAGE_DEBUG"] == "1"

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            if let image = StageLighting.environmentImage(),
               let resource = try? await EnvironmentResource(equirectangular: image, withName: "timbre.stage") {
                controller.setEnvironment(resource)
            }
            controller.input = input
            controller.attach(&content)
            status = "attached"
            await controller.load(modelID: modelID)
            status = controller.status
            if controller.failed { onFailure() } else { onReady() }
            ready = true
        } update: { _ in
            controller.input = input
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            var entity: Entity? = value.entity
            while let current = entity, !current.name.hasPrefix("peg_") { entity = current.parent }
            if let name = entity?.name { onSelect(String(name.dropFirst(4))) }
        })
        .task(id: modelID) {
            await controller.load(modelID: modelID)
            status = controller.status
            if controller.failed { onFailure() }
        }
        .mask {
            // Feather the edges so the stage melts into the screen whatever the renderer clears to.
            let edge: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .black, location: 0.06), .init(color: .black, location: 0.94), .init(color: .clear, location: 1)]
            LinearGradient(stops: edge, startPoint: .top, endPoint: .bottom)
                .mask(LinearGradient(stops: edge, startPoint: .leading, endPoint: .trailing))
        }
        .opacity(ready ? 1 : 0)
        .animation(Motion.settle, value: ready)
        .accessibilityHidden(true)
        .overlay(alignment: .bottomLeading) {
            #if DEBUG
            if debug {
                Text(status).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.8)).padding(6)
                    .accessibilityIdentifier("stage.debug")
            }
            #endif
        }
    }
}

/// Procedural equirectangular environment: dark warm stage with a key softbox and a cool rim.
enum StageLighting {
    static func environmentImage(width: Int = 512, height: Int = 256) -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 0.035, green: 0.03, blue: 0.028, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        func softbox(_ u: CGFloat, _ v: CGFloat, _ radius: CGFloat, _ color: (CGFloat, CGFloat, CGFloat)) {
            let colors = [CGColor(red: color.0, green: color.1, blue: color.2, alpha: 1), CGColor(red: color.0, green: color.1, blue: color.2, alpha: 0)] as CFArray
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: u * CGFloat(width), y: v * CGFloat(height))
            context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius * CGFloat(width), options: [])
        }
        softbox(0.38, 0.72, 0.13, (1.0, 0.86, 0.68))   // key: front-left, high
        softbox(0.86, 0.6, 0.09, (0.62, 0.76, 1.0))    // rim: behind-right
        softbox(0.6, 0.45, 0.16, (0.32, 0.26, 0.2))    // warm bounce
        return context.makeImage()
    }
}
