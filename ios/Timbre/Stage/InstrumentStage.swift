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
    /// The note of the string being tuned ("D3"), for the peg label.
    var note = ""
    /// Which string of the active anchor is being tuned, in course order (0 for the first): on a paired
    /// course, the one peg to turn. Nil cues every peg of the anchor.
    var pegIndex: Int?
}

/// Drives the live 3D instrument: camera framing, peg rotation following measured cents,
/// a vibrating string whose standing wave drifts with the pitch error and freezes in tune.
@MainActor
final class StageController {
    let root = Entity()
    let camera = PerspectiveCamera()
    /// The model on stage (nil while the wanted one loads).
    private(set) var loadedModel: String?
    /// The model the host asked for last. A load that finishes for any other model is dropped, never shown.
    private(set) var wanted: String?
    /// Bumped by every new request; a load compares it after its await, so a superseded load can't land.
    private var generation = 0
    /// The wanted model's load: one per model, joined by every later request for the same model.
    private var loadTask: Task<Void, Never>?
    /// When the wanted model was asked for (system uptime): a model revealed mid-dolly picks up from there.
    private var requestedAt: TimeInterval = 0
    /// Plain-text load state for diagnostics (shown only when TIMBRE_STAGE_DEBUG is set in debug builds).
    private(set) var status = "idle"
    /// The wanted model could not be loaded.
    private(set) var failed = false
    /// The host's placeholder dollies to the peg as well: a new model's dolly runs from the moment it is asked
    /// for, so the model appears at the placeholder's framing instead of holding the whole instrument first.
    var revealClose = false
    private var model: Entity?
    private var rig: InstrumentRig?
    private var pegs: [String: (entity: Entity, base: simd_quatf, position: SIMD3<Float>)] = [:]
    private var posts: [String: (entity: Entity, base: simd_quatf)] = [:]
    /// Each post's centre in model space (by peg name), measured once as the model goes on stage: where the string
    /// leaves the head, for the lock shimmer (`lockPath`).
    private var postCenters: [String: SIMD3<Float>] = [:]
    private var staticStrings: [String: Entity] = [:]
    private var segments: [ModelEntity] = []
    private var halo: [ModelEntity] = []
    private var subscription: EventSubscription?
    private let light = Entity()
    private var filter = ReadoutMotion.makeFilter()
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.07)
    private var time: Double = 0
    private var energy: Float = 0
    private var glow: Float = 0
    private var angles: [String: Float] = [:]
    private(set) var framing: Float = 0     // 0 = whole instrument, 1 = headstock close-up
    /// The dolly's speed along `framing` (a critically damped spring: it eases out and settles without overshoot).
    private var framingVelocity: Float = 0
    /// A freshly loaded model holds the whole-instrument framing until this time, so it cross-fades with a
    /// placeholder that shows the whole instrument before the camera dollies in: never a double image.
    /// (With `revealClose` there is no hold: the placeholder dollies in too.)
    private var holdWholeUntil: Double = 0
    private var yaw: Float = -0.32
    private var aimPoint: SIMD3<Float>?
    private var aimDistance: Float?
    /// The stage view's size in points: the close-up keeps every peg clear of its edges.
    var viewSize: CGSize = .zero
    /// Reduce Motion: the camera cuts instead of gliding and the instrument holds still.
    var reduceMotion = false
    /// The pitch error the stage shows, smoothed like the readout (nil with no pitch).
    private(set) var smoothedCents: Double?
    private var previousLevel: Double = -120
    private var currentAnchor: String?
    /// The string of `currentAnchor` being tuned (nil: all of them).
    private var currentPeg: Int?
    var input: () -> StageInput = { StageInput() }
    /// Paywall and onboarding: the instrument sways slowly under the lights.
    var showcase = false
    private static let segmentCount = 36
    /// Close-up clearances in points: peg centres stay this far below the stage top (24 pt plus the peg ring),
    /// the nut this far above its bottom; the headstock centres in the room left of the side controls.
    private static let pegClearance: Float = 48
    private static let nutClearance: Float = 30
    private static let controlsInset: Float = 26
    private static let closeYaw: Float = -0.54
    /// Dolly stiffness (rad/s): about a second from the whole instrument to the headstock.
    private static let dolly: Float = 4.2
    /// Long enough for the host's placeholder cross-fade to finish.
    private static let revealHold = 0.9

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

    /// Asks for `modelID` on stage. A model other than the last one asked for clears the stage at once (the old
    /// instrument never lingers while the new one loads), cancels the superseded load and starts this one. Asking
    /// again for the same model joins its load, so each model loads once.
    func request(_ modelID: String) {
        guard wanted != modelID else { return }
        wanted = modelID
        generation += 1
        loadTask?.cancel()
        loadTask = nil
        failed = false
        clearModel()
        // The new instrument starts whole, as its placeholder does, and the dolly runs from here.
        framing = 0
        framingVelocity = 0
        requestedAt = ProcessInfo.processInfo.systemUptime
        status = "loading \(modelID)"
        let ticket = generation
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.load(modelID, ticket: ticket)
        }
    }

    /// Requests `modelID` and returns once its load has finished: at once when it is already on stage (or failed).
    func show(_ modelID: String) async {
        request(modelID)
        if let loadTask { await loadTask.value }
    }

    private func load(_ modelID: String, ticket: Int) async {
        guard let url = ModelLibrary.url(modelID) else { fail("no usdz for \(modelID)", ticket: ticket); return }
        guard let rig = ModelLibrary.rig(modelID) else { fail("no rig for \(modelID)", ticket: ticket); return }
        let entity: Entity
        do { entity = try await Entity(contentsOf: url) } catch {
            fail("load failed: \(error.localizedDescription)", ticket: ticket)
            return
        }
        // Another instrument was asked for while this one loaded (its task was cancelled then): drop this model.
        guard ticket == generation, wanted == modelID, !Task.isCancelled else { return }
        install(entity, rig: rig, modelID: modelID)
    }

    /// A load that failed while still wanted; a superseded (cancelled) one fails silently.
    private func fail(_ reason: String, ticket: Int) {
        guard ticket == generation else { return }
        status = reason
        failed = true
    }

    /// Takes the model off the stage, with everything that animates it.
    private func clearModel() {
        model?.removeFromParent()
        model = nil
        rig = nil
        loadedModel = nil
        pegs = [:]; posts = [:]; postCenters = [:]; staticStrings = [:]; angles = [:]
        segments = []; halo = []
        currentAnchor = nil
        currentPeg = nil
        aimPoint = nil
        aimDistance = nil
        smoothedCents = nil
        filter.reset()
    }

    private func install(_ entity: Entity, rig: InstrumentRig, modelID: String) {
        clearModel()
        let holder = Entity()
        holder.addChild(entity)
        root.addChild(holder)
        model = holder
        self.rig = rig
        loadedModel = modelID
        for string in rig.strings {
            if let peg = entity.findEntity(named: string.peg) {
                pegs[string.peg] = (peg, peg.orientation, peg.position)
                peg.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.024)]))
                peg.components.set(InputTargetComponent())
            }
            if let post = entity.findEntity(named: string.post) {
                posts[string.peg] = (post, post.orientation)
                let center = post.visualBounds(relativeTo: holder).center
                if center.x.isFinite && center.y.isFinite && center.z.isFinite { postCenters[string.peg] = center }
            }
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
        // Aim at the string being tuned from the first frame, not at the first string and then glide across.
        let state = input()
        currentAnchor = state.activeAnchor ?? rig.strings.first?.anchor
        currentPeg = state.activeAnchor == nil ? nil : state.pegIndex
        if revealClose {
            holdWholeUntil = 0
            if state.focus { pickUpPlaceholderDolly(rig) }
            applyFraming(snapCamera: true)
        } else {
            holdWholeUntil = time + Self.revealHold
            applyFraming(snapFraming: true)
        }
        let box = holder.visualBounds(relativeTo: nil)
        func fmt(_ v: SIMD3<Float>) -> String { String(format: "%.2f,%.2f,%.2f", v.x, v.y, v.z) }
        status = "loaded \(modelID) pegs=\(pegs.count) strings=\(staticStrings.count) c=\(fmt(box.center)) e=\(fmt(box.extents)) ibl=\(light.components.has(ImageBasedLightComponent.self))"
    }

    /// The placeholder (`StudioStage`) has been dollying in since the request, toward a zoom of at most
    /// `StageFrame.maxZoom`. The model carries on from the 3D framing with the same apparent zoom, so the cross-fade
    /// meets the picture at its own scale and the dolly continues to the full close-up. Where it has got to is
    /// worked out from the clock (the same spring), since a hidden stage may not have ticked while it loaded.
    private func pickUpPlaceholderDolly(_ rig: InstrumentRig) {
        let t = Float(max(0, ProcessInfo.processInfo.systemUptime - requestedAt))
        let w = Self.dolly
        let progress = min(1, 1 - (1 + w * t) * exp(-w * t))
        let speed = w * w * t * exp(-w * t)
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let close = closeUp(rig: rig, anchor: currentAnchor, fov: fov)
        let span = log(max(1.05, wholeShotDistance(rig, fov: fov) / max(close.distance, 0.001)))
        let ratio = log(Float(StageFrame.maxZoom)) / span
        framing = min(1, progress * ratio)
        framingVelocity = framing < 1 ? speed * ratio : 0
    }

    /// The camera distance that frames the whole instrument.
    private func wholeShotDistance(_ rig: InstrumentRig, fov: Float) -> Float {
        ((rig.upper.y - rig.lower.y) * 0.56) / tan(fov / 2)
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
    /// `snapFraming` cuts the dolly to its target; `snapCamera` places the aim, distance and turn at once (a model
    /// just put on stage). The dolly advances even with no model on stage, so a model that arrives mid-move
    /// appears where its placeholder's dolly has got to.
    private func applyFraming(dt: Float = 0, snapFraming: Bool = false, snapCamera: Bool = false) {
        let target: Float = input().focus && time >= holdWholeUntil ? 1 : 0
        if snapFraming || reduceMotion { framing = target; framingVelocity = 0 } else { dollyFraming(toward: target, dt: dt) }
        guard let rig, let model else { return }
        let snap = snapFraming || snapCamera || reduceMotion
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let center = (rig.lower + rig.upper) / 2
        let wholeDistance = wholeShotDistance(rig, fov: fov)
        // Close-up: the whole headstock, gliding toward the peg being tuned when the string changes.
        let close = closeUp(rig: rig, anchor: currentAnchor ?? rig.strings.first?.anchor, fov: fov)
        let previousAim = aimPoint ?? close.aim
        let focusPoint = snap ? close.aim : previousAim + (close.aim - previousAim) * min(1, dt * 3)
        aimPoint = focusPoint
        let previousDistance = aimDistance ?? close.distance
        let focusDistance = snap ? close.distance : previousDistance + (close.distance - previousDistance) * min(1, dt * 3)
        aimDistance = focusDistance
        // A dolly rather than a cross-fade: the distance moves geometrically (even apparent zoom) and the aim
        // slides so the headstock travels to its close-up spot in step with the zoom.
        let distance = wholeDistance * pow(focusDistance / max(wholeDistance, 0.001), framing)
        let slide = 1 - (1 - framing) * distance / max(wholeDistance, 0.001)
        let point = simd_mix(center, focusPoint, SIMD3(repeating: max(0, min(1, slide))))
        let sway: Float = showcase && !reduceMotion ? 0.5 * Float(sin(time * 0.32)) : 0
        let targetYaw: Float = showcase ? -0.18 + sway : -0.32 + (Self.closeYaw + 0.32) * framing
        yaw = snap ? targetYaw : yaw + (targetYaw - yaw) * min(1, dt * 2.6)
        let breathing = reduceMotion ? 0 : Float(sin(time * 0.35)) * 0.025 * (1 - framing)
        let rotation = simd_quatf(angle: yaw + breathing, axis: [0, 1, 0]) * simd_quatf(angle: 0.04 * (1 - framing), axis: [1, 0, 0])
        model.orientation = rotation
        // In close-up the headstock centres in the room left of the side controls.
        let shift = Self.controlsInset * metresPerPoint(distance: distance, fov: fov) * framing
        model.position = -rotation.act(point) + SIMD3<Float>(-shift, 0, -distance)
    }

    /// Advances the dolly: a critically damped spring on `framing`, in small steps so a long frame can't overshoot.
    private func dollyFraming(toward target: Float, dt: Float) {
        let omega = Self.dolly
        var remaining = max(0, min(dt, 0.25))
        while remaining > 0 {
            let h = min(remaining, 1 / 120)
            let acceleration = omega * omega * (target - framing) - 2 * omega * framingVelocity
            framingVelocity += acceleration * h
            framing += framingVelocity * h
            remaining -= h
        }
        if framing < 0 || framing > 1 { framing = max(0, min(1, framing)); framingVelocity = 0 }
    }

    /// World metres one point spans at `distance` in front of the camera (0 before the view has a size).
    private func metresPerPoint(distance: Float, fov: Float) -> Float {
        let half = Float(viewSize.height) / 2
        return half > 0 ? distance * tan(fov / 2) / half : 0
    }

    /// The close-up target: aimed between the head and the peg being tuned, then raised (and the camera
    /// backed off if needed) so every tuning peg sits at least `pegClearance` below the top edge while the
    /// nut stays `nutClearance` above the bottom. A point's height on screen is (y - aim.y) / ((distance - z) * t)
    /// of the half-height, z being how far the turned instrument brings it toward the camera; the yaw leaves y alone.
    private func closeUp(rig: InstrumentRig, anchor: String?, fov: Float) -> (aim: SIMD3<Float>, distance: Float) {
        let head = rig.head
        var aim = head + SIMD3<Float>(0, -0.045, 0)
        if let string = rig.string(anchor) {
            aim = head + (string.pegPoint - head) * 0.45 + SIMD3<Float>(0, -0.03, 0)
        }
        var distance: Float = max(0.34, (rig.upper.y - rig.lower.y) * 0.33)
        let height = Float(viewSize.height)
        guard height > Self.pegClearance + Self.nutClearance + 40, !rig.strings.isEmpty else { return (aim, distance) }
        let t = tan(fov / 2)
        let top = 1 - 2 * Self.pegClearance / height
        let bottom = 1 - 2 * Self.nutClearance / height
        let turn = simd_quatf(angle: Self.closeYaw, axis: [0, 1, 0])
        var highest = -Float.greatestFiniteMagnitude
        var lowest = Float.greatestFiniteMagnitude
        for string in rig.strings {
            let peg = string.pegPoint, nut = string.nutPoint
            highest = max(highest, peg.y + top * turn.act(peg - aim).z * t)
            lowest = min(lowest, nut.y - bottom * turn.act(nut - aim).z * t)
        }
        distance = max(distance, (highest - lowest) / ((top + bottom) * t))
        let minAim = highest - top * distance * t
        let maxAim = max(minAim, lowest + bottom * distance * t)
        aim.y = min(max(aim.y, minAim), maxAim)
        return (aim, distance)
    }

    /// Where a rig point (model space) lands in a stage view of `size`, in points; the same projection
    /// the camera uses (at the origin, looking down -Z, vertical field of view).
    func screenPoint(_ p: SIMD3<Float>, in size: CGSize) -> CGPoint? {
        guard let model, size.width > 0, size.height > 0 else { return nil }
        let world = model.orientation.act(p) + model.position
        let depth = -world.z
        guard depth > 0.01 else { return nil }
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let scale = Float(size.height) / 2 / (depth * tan(fov / 2))
        return CGPoint(x: size.width / 2 + CGFloat(world.x * scale), y: size.height / 2 - CGFloat(world.y * scale))
    }

    struct PegMarker {
        /// The pegs of the string being tuned on screen: one, or both of a pair when the input names neither.
        var points: [CGPoint]
        /// The label's side: -1 left of the peg (pegs left of the head's centre), +1 right.
        var side: CGFloat
        /// The rig's turn sign: +1 when clockwise tightens.
        var tighten: Int
        var slides: Bool
        /// 0 = whole instrument, 1 = headstock close-up.
        var closeUp: Float
    }

    /// The pegs of the string being tuned, projected for the stage overlay; nil before the model is on stage.
    func pegMarker(in size: CGSize) -> PegMarker? {
        guard let rig, !showcase, let anchor = currentAnchor else { return nil }
        let strings = Self.tuned(rig, anchor: anchor, peg: currentPeg)
        let points = strings.compactMap { screenPoint($0.pegPoint, in: size) }
        guard let first = strings.first, let lead = points.first else { return nil }
        let head = screenPoint(rig.head, in: size)
        let left = head.map { lead.x < $0.x } ?? true
        return PegMarker(points: points, side: left ? -1 : 1, tighten: first.tighten, slides: first.slides, closeUp: framing)
    }

    /// The string being tuned on screen, for the lock shimmer (`LockShimmer`).
    struct LockPath {
        var peg: CGPoint
        /// Where the string leaves the head: its post (its peg when the model has no post for it).
        var post: CGPoint
        var nut: CGPoint
        var saddle: CGPoint
        /// The headstock: the box around every peg and nut on screen.
        var head: CGRect?
    }

    /// The lead string of the anchor being tuned, projected like `pegMarker`; nil before the model is on stage. Read
    /// only while the shimmer runs. A string with no length of its own (a wind joint) shimmers at its peg alone.
    func lockPath(in size: CGSize) -> LockPath? {
        guard let rig, !showcase, let anchor = currentAnchor,
              let string = Self.tuned(rig, anchor: anchor, peg: currentPeg).first,
              let peg = screenPoint(string.pegPoint, in: size) else { return nil }
        guard string.radius > 0, let nut = screenPoint(string.nutPoint, in: size) else {
            return LockPath(peg: peg, post: peg, nut: peg, saddle: peg, head: nil)
        }
        let post = postCenters[string.peg].flatMap { screenPoint($0, in: size) } ?? peg
        // Past the nut the string runs on to its saddle (straight on from the head, should the saddle be off camera).
        let saddle = screenPoint(string.saddlePoint, in: size)
            ?? CGPoint(x: nut.x + (nut.x - post.x) * 6, y: nut.y + (nut.y - post.y) * 6)
        var low = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var high = CGPoint(x: -CGFloat.greatestFiniteMagnitude, y: -CGFloat.greatestFiniteMagnitude)
        for each in rig.strings {
            for point in [each.pegPoint, each.nutPoint] {
                guard let p = screenPoint(point, in: size) else { continue }
                low = CGPoint(x: min(low.x, p.x), y: min(low.y, p.y))
                high = CGPoint(x: max(high.x, p.x), y: max(high.y, p.y))
            }
        }
        let head = high.x >= low.x ? CGRect(x: low.x, y: low.y, width: high.x - low.x, height: high.y - low.y) : nil
        return LockPath(peg: peg, post: post, nut: nut, saddle: saddle, head: head)
    }

    func tick(_ dt: Float) {
        guard dt > 0 else { return }
        time += Double(dt)
        let state = input()
        applyFraming(dt: dt)
        guard let rig else { return }
        let anchor = state.activeAnchor ?? rig.strings.first?.anchor
        let peg = state.activeAnchor == nil ? nil : state.pegIndex
        if anchor != currentAnchor || peg != currentPeg {
            for string in rig.strings where string.anchor == currentAnchor { staticStrings[string.nodeName]?.isEnabled = true }
            currentAnchor = anchor
            currentPeg = peg
            filter.reset()
        }
        let tuned = Self.tuned(rig, anchor: anchor, peg: peg)
        let turning = Set(tuned.map(\.peg))
        // Pluck energy: rises with the input level, decays like a string.
        let rising = state.level > previousLevel + 6 && state.level > -42
        previousLevel = state.level
        let target = state.listening ? Float(max(0, min(1, (state.level + 58) / 34))) : 0
        energy = rising ? max(energy, target) : max(target * 0.6, energy * exp(-dt * 1.4))
        let smoothed = state.cents.map { filter.filter(max(-60, min(60, $0)), at: time) }
        if smoothed == nil { filter.reset() }
        smoothedCents = state.listening ? smoothed : nil
        let phase = strobe.advance(cents: state.locked ? 0 : smoothed, dt: Double(dt))
        glow += ((state.locked ? 1 : 0) - glow) * min(1, dt * (state.locked ? 7 : 2.5))

        // Pegs: the peg of the string being tuned follows the pitch error; the rest ease home.
        for string in rig.strings {
            guard let peg = pegs[string.peg] else { continue }
            var goal: Float = 0
            if turning.contains(string.peg), let smoothed {
                goal = string.slides ? Float(-smoothed) * (string.perCent ?? 0.0003)
                                     : Float(-smoothed) * rig.degPerCent * Float(string.tighten) * .pi / 180
            }
            let current = angles[string.peg] ?? 0
            let next = current + (goal - current) * min(1, dt * 9)
            angles[string.peg] = next
            if string.slides {
                // Out when flat (the tube or tine is too long), in when sharp; home when in tune.
                peg.entity.position = peg.position + peg.base.act(SIMD3<Float>(1, 0, 0)) * next
                continue
            }
            peg.entity.orientation = peg.base * simd_quatf(angle: next, axis: [1, 0, 0])
            if let post = posts[string.peg] { post.entity.orientation = post.base * simd_quatf(angle: next / 6, axis: [0, 0, 1]) }
        }
        updateString(tuned.first, phase: Float(phase), locked: state.locked, active: state.listening)
    }

    /// The rig strings being tuned: on a paired course the one `peg` names (in course order), else every
    /// string on the anchor (a rig with one string per anchor ignores `peg`).
    private static func tuned(_ rig: InstrumentRig, anchor: String?, peg: Int?) -> [InstrumentRig.StringRig] {
        let strings = rig.strings.filter { $0.anchor == anchor }
        guard let peg, strings.count > 1, strings.indices.contains(peg) else { return strings }
        return [strings[peg]]
    }

    private func updateString(_ string: InstrumentRig.StringRig?, phase: Float, locked: Bool, active: Bool) {
        guard let string, string.radius > 0 else { return }
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

/// SwiftUI host. Taps on a peg select its string; the peg being tuned is ringed and labelled with its turn.
struct InstrumentStage: View {
    let modelID: String
    let input: () -> StageInput
    var onSelect: (String) -> Void = { _ in }
    /// Called when the model cannot be shown, so the host can fall back to the studio stage.
    var onFailure: () -> Void = {}
    /// Called once the model is on stage (the host can retire its placeholder).
    var onReady: () -> Void = {}
    var showcase = false
    /// The host's placeholder (a `StudioStage` with card points) dollies to the peg as well: the model then
    /// appears at the placeholder's framing instead of holding the whole instrument first.
    var revealClose = false
    /// The host isn't listening and holds no reading: the peg cue settles and stops redrawing (`StagePegCue.resting`).
    var resting = false
    @State private var box = StageBox()
    @State private var ready = false
    @State private var status = "make"
    @State private var attached = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let debug = ProcessInfo.processInfo.environment["TIMBRE_STAGE_DEBUG"] == "1"

    private var controller: StageController { box.controller }

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            if let image = StageLighting.environmentImage(),
               let resource = try? await EnvironmentResource(equirectangular: image, withName: "timbre.stage") {
                controller.setEnvironment(resource)
            }
            configure()
            controller.reduceMotion = reduceMotion
            controller.attach(&content)
            // The model task loads and reports; attaching reports through `attached` (this closure's copy of the
            // view keeps the model id it was made with, so it never reports a model itself).
            attached = true
            status = "attached"
        } update: { _ in
            controller.input = input
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            var entity: Entity? = value.entity
            while let current = entity, !current.name.hasPrefix("peg_") { entity = current.parent }
            if let name = entity?.name { onSelect(String(name.dropFirst(4))) }
        })
        // One load per model, owned by the controller: a newer instrument cancels it, and only the model the host
        // still wants is ever put on stage or reported ready.
        .task(id: modelID) {
            configure()
            await controller.show(modelID)
            guard !Task.isCancelled else { return }
            reportLoad()
        }
        .onChange(of: modelID) { _, id in
            // The old instrument leaves the scene at once and the stage turns clear until the new one is in, so the
            // host's placeholder shows through instead of the last model.
            ready = false
            configure()
            controller.request(id)
        }
        .onChange(of: attached) { _, _ in reportLoad() }
        .onChange(of: reduceMotion, initial: true) { _, value in controller.reduceMotion = value }
        .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { size in controller.viewSize = size }
        // Feather the edges so the stage melts into the screen whatever the renderer clears to.
        .mask { StageFeather(close: 1) }
        .overlay {
            if !showcase { StagePegCue(controller: controller, input: input, reduceMotion: reduceMotion, resting: resting, loaded: ready) }
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

    private func configure() {
        controller.input = input
        controller.showcase = showcase
        controller.revealClose = revealClose
    }

    /// Ready (the host retires its placeholder) only once the model this view shows is on stage and the scene is
    /// attached; failed only when the model it shows could not load. A superseded model never reports.
    private func reportLoad() {
        status = controller.status
        guard controller.wanted == modelID else { return }
        if controller.failed { onFailure() }
        else if attached && controller.loadedModel == modelID { ready = true; onReady() }
    }
}

/// Holds the stage's controller, made on first use: `@State` evaluates its initial value each time the view is
/// initialised, and a controller makes RealityKit entities, so the box keeps that to once per stage.
@MainActor
final class StageBox {
    private(set) lazy var controller = StageController()
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
