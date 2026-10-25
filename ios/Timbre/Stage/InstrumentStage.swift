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
    /// The close-up frames the whole headstock, every button and its tip, centred across the stage (the iPad, in any
    /// window), rather than the phone's tighter shot leaning toward the peg being tuned.
    var wholeHeadstock = false
    /// Points along the stage's trailing edge that the side controls stand over: a whole-headstock close-up keeps
    /// clear of them.
    var controlsReserve: CGFloat = 0
    /// How many times wider the live string swings than in use: 1, except in an App Store capture of a moment the
    /// still frame would otherwise miss (`captureScale`). The amplitude only; nothing else on the stage changes.
    var marketingScale: Float = StageInput.defaultMarketingScale
    /// The host reads right to left: its side controls stand on the stage's left edge, so the close-up leans right
    /// of them and the peg's label keeps clear of them there, its words set right to left. The instrument itself
    /// never mirrors for a language.
    var rightToLeft = false

    static var defaultMarketingScale: Float {
        #if DEBUG
        return captureScale
        #else
        return 1
        #endif
    }

    #if DEBUG
    /// Set by an App Store scene (`DemoScene`) before the stage appears: 3 shows the string's swing in a still frame.
    nonisolated(unsafe) static var captureScale: Float = 1
    #endif
}

/// Drives the live 3D instrument: camera framing, peg rotation following measured cents,
/// a vibrating string whose standing wave drifts with the pitch error and freezes in tune. A left-handed player's
/// stage is the same scene turned over by its host (`flipX`): projected points and the pegs' turn follow.
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
    /// The corners of every peg's box in model space (the button the player turns, with its shaft), measured once as
    /// the model goes on stage: a whole-headstock close-up keeps every button inside the frame (`wholeHeadCloseUp`).
    private var pegCorners: [SIMD3<Float>] = []
    /// The corners of the box around the head above its highest peg, in model space: a violin's or cello's scroll, a
    /// mandolin's curl, the end of a guitar's head. Measured from the mesh itself once per model (`measureCrown`),
    /// so every close-up keeps the whole of it in frame, however it curls toward the camera. Empty when the mesh
    /// can't be read; the instrument's top point stands in then.
    private var crown: [SIMD3<Float>] = []
    /// Crowns already measured, by model.
    private static var crowns: [String: [SIMD3<Float>]] = [:]
    private var staticStrings: [String: Entity] = [:]
    private var segments: [ModelEntity] = []
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
    /// The host shows the stage mirrored (a left-handed instrument): projected points mirror, and a peg that tightens
    /// clockwise on the model tightens anticlockwise on screen.
    var flipX = false
    /// The stage at rest holds this much of the close-up (the studio picture's own zoom) instead of all of it, so it
    /// can hand over to that picture (`InstrumentStage`); nil holds the whole close-up.
    var restFraming: Float?
    /// Frames drawn since the scene was attached: the stage has really drawn once this moves.
    private(set) var frames = 0
    private var glowTube: ModelEntity?
    /// The full-tune roll (`rollStrings`): when each rig string (lowest first) is struck in turn, when they are all
    /// struck together, and each string's glow.
    private var rollStrikes: [Date] = []
    private var rollBloom: Date?
    private var rollGlows: [ModelEntity] = []
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

    /// Puts the stage in a (new) scene: a stage brought back after resting attaches again, model and all.
    func attach(_ content: inout RealityViewCameraContent) {
        subscription?.cancel()
        frames = 0
        content.add(root)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.tick(Float(event.deltaTime)) }
        }
    }

    /// The 3D view is going away (the stage rests on its picture): its frames stop until it attaches again.
    func detach() {
        subscription?.cancel()
        subscription = nil
        frames = 0
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

    /// Loads through the shared cache (`ModelCache`), so the tuner and a lesson's "Show me" load an instrument once.
    private func load(_ modelID: String, ticket: Int) async {
        guard ModelLibrary.url(modelID) != nil else { fail("no usdz for \(modelID)", ticket: ticket); return }
        guard let rig = ModelLibrary.rig(modelID) else { fail("no rig for \(modelID)", ticket: ticket); return }
        guard let entity = await ModelCache.shared.instance(of: modelID) else {
            fail("load failed: \(ModelCache.shared.problem(modelID) ?? "no reason given")", ticket: ticket)
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
        pegs = [:]; posts = [:]; postCenters = [:]; pegCorners = []; crown = []; staticStrings = [:]; angles = [:]
        segments = []; glowTube = nil
        rollStrikes = []; rollBloom = nil; rollGlows = []
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
                pegCorners += Self.corners(peg.visualBounds(relativeTo: holder))
            }
            if let post = entity.findEntity(named: string.post) {
                posts[string.peg] = (post, post.orientation)
                let center = post.visualBounds(relativeTo: holder).center
                if center.x.isFinite && center.y.isFinite && center.z.isFinite { postCenters[string.peg] = center }
            }
            if let line = entity.findEntity(named: string.nodeName) { staticStrings[string.nodeName] = line }
        }
        if let known = Self.crowns[modelID] {
            crown = known
        } else {
            crown = Self.measureCrown(of: entity, in: holder, above: rig.strings.map(\.pegPoint.y).max() ?? rig.head.y)
            Self.crowns[modelID] = crown
        }
        let mesh = MeshResource.generateCylinder(height: 1, radius: 1)
        var metal = PhysicallyBasedMaterial()
        metal.baseColor = .init(tint: UIColor(white: 0.86, alpha: 1))
        metal.metallic = 1.0; metal.roughness = 0.28
        for _ in 0..<Self.segmentCount {
            let segment = ModelEntity(mesh: mesh, materials: [metal])
            segment.isEnabled = false
            holder.addChild(segment); segments.append(segment)
        }
        // The lit string's glow: one tube along it, never a glow per segment (their overlaps beaded the light).
        let glow = ModelEntity(mesh: StringGlow.mesh(), materials: [StringGlow.material(UIColor(red: 1, green: 0.86, blue: 0.62, alpha: 1), opacity: 0.3)])
        glow.isEnabled = false
        holder.addChild(glow)
        glowTube = glow
        addLights()
        holder.receiveImageBasedLight(from: light)
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
        let close = closeUp(rig: rig, anchor: currentAnchor, fov: fov, layout: input())
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
        model?.receiveImageBasedLight(from: light)
    }

    /// How far into the close-up (0 the whole instrument, 1 the close-up) the camera must be for the instrument to look
    /// `zoom` times as big as in the whole shot: where the studio picture's close-up stands, so the two meet.
    func framing(atZoom zoom: Float) -> Float? {
        guard let rig else { return nil }
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let close = closeUp(rig: rig, anchor: currentAnchor ?? rig.strings.first?.anchor, fov: fov, layout: input())
        let span = log(max(1.05, wholeShotDistance(rig, fov: fov) / max(close.distance, 0.001)))
        return min(1, max(0, log(max(1, zoom)) / span))
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
        let state = input()
        let target: Float = state.focus && time >= holdWholeUntil ? (restFraming ?? 1) : 0
        if snapFraming || reduceMotion { framing = target; framingVelocity = 0 } else { dollyFraming(toward: target, dt: dt) }
        guard let rig, let model else { return }
        let snap = snapFraming || snapCamera || reduceMotion
        let fov = Float(camera.camera.fieldOfViewInDegrees) * .pi / 180
        let center = (rig.lower + rig.upper) / 2
        let wholeDistance = wholeShotDistance(rig, fov: fov)
        // Close-up: the whole headstock, gliding toward the peg being tuned when the string changes.
        let close = closeUp(rig: rig, anchor: currentAnchor ?? rig.strings.first?.anchor, fov: fov, layout: state)
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
        // In close-up the headstock centres in the room beside the side controls, away from them on screen: left of
        // them, or right of them where they stand on the left (a right-to-left language). A mirrored stage (a
        // left-handed instrument) turns the scene over, so the shift turns over with it to land on the same side.
        // The whole-headstock close-up centres itself.
        let inset: Float = state.wholeHeadstock ? 0 : Self.controlsInset
        let away: Float = (state.rightToLeft ? 1 : -1) * (flipX ? -1 : 1)
        let shift = inset * metresPerPoint(distance: distance, fov: fov) * framing
        model.position = -rotation.act(point) + SIMD3<Float>(away * shift, 0, -distance)
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

    /// A point the close-up keeps on screen, `clearance` points inside the stage's top (or bottom) edge.
    private typealias Bound = (point: SIMD3<Float>, clearance: Float)

    /// The feathered edge (`StageFeather` fades the outer 6 % of each side) and a little air: the head's top stays
    /// under it, whole and lit.
    private static func featherClearance(_ length: Float) -> Float { 0.06 * length + 10 }

    /// The top of the head the close-up keeps in frame: the measured crown, or the instrument's top point over its head.
    private func headTops(_ rig: InstrumentRig) -> [SIMD3<Float>] {
        crown.isEmpty ? [SIMD3<Float>(rig.head.x, rig.upper.y, rig.head.z)] : crown
    }

    /// The close-up target: aimed between the head and the peg being tuned, then raised (and the camera backed off if
    /// needed) so every tuning peg sits at least `pegClearance` below the top edge, the whole head above them (a
    /// scroll, a curl) under the feathered edge, and the nut `nutClearance` above the bottom (`fitVertically`).
    private func closeUp(rig: InstrumentRig, anchor: String?, fov: Float, layout: StageInput) -> (aim: SIMD3<Float>, distance: Float) {
        if layout.wholeHeadstock { return wholeHeadCloseUp(rig: rig, anchor: anchor, fov: fov, reserve: Float(layout.controlsReserve)) }
        let head = rig.head
        var aim = head + SIMD3<Float>(0, -0.045, 0)
        if let string = rig.string(anchor) {
            aim = head + (string.pegPoint - head) * 0.45 + SIMD3<Float>(0, -0.03, 0)
        }
        let distance: Float = max(0.34, (rig.upper.y - rig.lower.y) * 0.33)
        let height = Float(viewSize.height)
        guard height > Self.pegClearance + Self.nutClearance + 40, !rig.strings.isEmpty else { return (aim, distance) }
        let edge = Self.featherClearance(height)
        let pegs: [Bound] = rig.strings.map { (point: $0.pegPoint, clearance: Self.pegClearance) }
        let tops: [Bound] = headTops(rig).map { (point: $0, clearance: edge) }
        let nuts: [Bound] = rig.strings.map { (point: $0.nutPoint, clearance: Self.nutClearance) }
        return fitVertically(aim: aim, distance: distance, above: pegs + tops, below: nuts, fov: fov, height: height)
    }

    /// Raises the aim, and backs the camera off as far as needed, so every point of `above` sits at least its clearance
    /// under the stage's top edge and every point of `below` its clearance over the bottom. A point's height on screen
    /// is (y - aim.y) / ((distance - z) * t) of the half-height, z being how far the close-up's turn brings it toward
    /// the camera (the turn leaves y alone), so each point bounds the aim's height: one above, aim.y >= a - k·distance·t;
    /// one below, aim.y <= b + k·distance·t.
    private func fitVertically(aim start: SIMD3<Float>, distance near: Float, above: [Bound], below: [Bound],
                               fov: Float, height: Float) -> (aim: SIMD3<Float>, distance: Float) {
        var aim = start
        var distance = near
        let t = tan(fov / 2)
        let turn = simd_quatf(angle: Self.closeYaw, axis: [0, 1, 0])
        let tops: [(a: Float, k: Float)] = above.map { item -> (a: Float, k: Float) in
            let k = 1 - 2 * item.clearance / height
            return (a: item.point.y + k * turn.act(item.point - aim).z * t, k: k)
        }
        let bottoms: [(b: Float, k: Float)] = below.map { item -> (b: Float, k: Float) in
            let k = 1 - 2 * item.clearance / height
            return (b: item.point.y - k * turn.act(item.point - aim).z * t, k: k)
        }
        for top in tops {
            for bottom in bottoms where top.k + bottom.k > 0 {
                distance = max(distance, (top.a - bottom.b) / ((top.k + bottom.k) * t))
            }
        }
        let minAim = tops.map { $0.a - $0.k * distance * t }.max() ?? aim.y
        let maxAim = max(minAim, bottoms.map { $0.b + $0.k * distance * t }.min() ?? aim.y)
        aim.y = min(max(aim.y, minAim), maxAim)
        return (aim, distance)
    }

    /// The iPad's close-up (`StageInput.wholeHeadstock`): the whole headstock in the frame, every button and the head
    /// above them clear of the feathered edges, centred across the stage (and clear of `reserve` points of side
    /// controls on its trailing edge), rather than the phone's tighter shot leaning toward the peg being tuned.
    /// Vertically as `closeUp`: aimed a little toward the peg's height, the camera backing off until the pegs sit
    /// `pegClearance` under the top, the head's crown and the buttons under the feather and the nut `nutClearance`
    /// above the bottom (`fitVertically`). Then far enough back that the head fits across, and slid sideways to centre
    /// it. A point's offset across is x / ((distance - z) * t) of the half-height, x and z after the close-up's turn.
    private func wholeHeadCloseUp(rig: InstrumentRig, anchor: String?, fov: Float, reserve: Float) -> (aim: SIMD3<Float>, distance: Float) {
        let head = rig.head
        var aim = head + SIMD3<Float>(0, -0.045, 0)
        if let string = rig.string(anchor) { aim.y = head.y + (string.pegPoint.y - head.y) * 0.45 - 0.03 }
        let width = Float(viewSize.width), height = Float(viewSize.height)
        let near: Float = max(0.34, (rig.upper.y - rig.lower.y) * 0.33)
        guard height > Self.pegClearance + Self.nutClearance + 40, width > 160, !rig.strings.isEmpty else { return (aim, near) }
        let t = tan(fov / 2)
        let turn = simd_quatf(angle: Self.closeYaw, axis: [0, 1, 0])
        let edge = Self.featherClearance(height)
        let crownPoints = headTops(rig)
        let buttons = pegCorners.isEmpty ? rig.strings.map { $0.pegPoint + $0.pegDirection * 0.03 } : pegCorners
        let pegs: [Bound] = rig.strings.map { (point: $0.pegPoint, clearance: Self.pegClearance) }
        let tops: [Bound] = (crownPoints + buttons).map { (point: $0, clearance: edge) }
        let nuts: [Bound] = rig.strings.map { (point: $0.nutPoint, clearance: Self.nutClearance) }
        let fitted = fitVertically(aim: aim, distance: near, above: pegs + tops, below: nuts, fov: fov, height: height)
        aim = fitted.aim
        var distance = fitted.distance

        // Across: every button, peg, nut and the head's crown inside the room between the feathered sides and the controls.
        let side = 0.06 * width + 8
        let room = width - 2 * side - reserve
        let across = buttons + rig.strings.flatMap { [$0.pegPoint, $0.nutPoint] } + crownPoints
        let turned = across.map { turn.act($0 - aim) }
        let pointsPerMetre = height / 2 / t
        func extent(_ d: Float) -> (low: Float, high: Float) {
            var low = Float.greatestFiniteMagnitude, high = -Float.greatestFiniteMagnitude
            for v in turned {
                let x = v.x / max(d - v.z, 0.01) * pointsPerMetre
                low = min(low, x); high = max(high, x)
            }
            return (low: low, high: high)
        }
        if room > 40 {
            for _ in 0..<6 {
                let span = extent(distance)
                guard span.high - span.low > room else { break }
                distance *= (span.high - span.low) / room * 1.02
            }
        }
        // Centred across the whole stage when that keeps clear of the sides and the controls, else as near it as fits.
        let span = extent(distance)
        let lowest = -width / 2 + side - span.low
        let highest = width / 2 - side - reserve - span.high
        let centred = -(span.low + span.high) / 2
        let offset = lowest <= highest ? min(max(centred, lowest), highest) : (lowest + highest) / 2
        // Slide the aim along the turned instrument's own x, so every point moves across by the offset and none in depth.
        let metres = offset * distance / pointsPerMetre
        aim -= turn.inverse.act(SIMD3<Float>(metres, 0, 0))
        return (aim, distance)
    }

    /// The eight corners of a peg's box: none when it is empty, not finite, or too big to be one peg.
    private static func corners(_ box: BoundingBox) -> [SIMD3<Float>] {
        let size = box.max - box.min
        guard max(size.x, max(size.y, size.z)) < 0.2 else { return [] }
        return boxCorners(low: box.min, high: box.max)
    }

    /// The eight corners of the box from `low` to `high`: none when it is empty or not finite.
    private static func boxCorners(low: SIMD3<Float>, high: SIMD3<Float>) -> [SIMD3<Float>] {
        let size = high - low
        guard size.x >= 0, size.y >= 0, size.z >= 0,
              low.x.isFinite, low.y.isFinite, low.z.isFinite, high.x.isFinite, high.y.isFinite, high.z.isFinite else { return [] }
        var points: [SIMD3<Float>] = []
        for x in [low.x, high.x] {
            for y in [low.y, high.y] {
                for z in [low.z, high.z] { points.append(SIMD3<Float>(x, y, z)) }
            }
        }
        return points
    }

    /// The corners of the box around every vertex of `entity`'s meshes above `floor` (model space, relative to
    /// `holder`): the part of the head above its pegs, as the model is built rather than as its overall bounds or a
    /// single point say. Read once per model as it goes on stage; empty when no mesh has a vertex there.
    private static func measureCrown(of entity: Entity, in holder: Entity, above floor: Float) -> [SIMD3<Float>] {
        var low = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var found = false
        var pending: [Entity] = [entity]
        while let current = pending.popLast() {
            pending.append(contentsOf: current.children)
            guard let mesh = current.components[ModelComponent.self]?.mesh else { continue }
            let toHolder = current.transformMatrix(relativeTo: holder)
            let contents = mesh.contents
            for instance in contents.instances {
                guard let model = contents.models[instance.model] else { continue }
                let transform = toHolder * instance.transform
                for part in model.parts {
                    for position in part.positions {
                        let placed = transform * SIMD4<Float>(position.x, position.y, position.z, 1)
                        guard placed.y >= floor, placed.x.isFinite, placed.y.isFinite, placed.z.isFinite else { continue }
                        let point = SIMD3<Float>(placed.x, placed.y, placed.z)
                        low = simd_min(low, point)
                        high = simd_max(high, point)
                        found = true
                    }
                }
            }
        }
        return found ? boxCorners(low: low, high: high) : []
    }

    /// How far below the stage's top edge (points) the highest point of the head's crown stands on screen in a stage
    /// of `size` (negative when the stage cuts it), and how far into the close-up the camera is; nil before a model
    /// is on stage.
    func headClearance(in size: CGSize) -> (top: CGFloat, framing: Float)? {
        guard let rig else { return nil }
        let tops = headTops(rig).compactMap { screenPoint($0, in: size) }
        guard let highest = tops.map(\.y).min() else { return nil }
        return (top: highest, framing: framing)
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
        let x = size.width / 2 + CGFloat(world.x * scale)
        return CGPoint(x: flipX ? size.width - x : x, y: size.height / 2 - CGFloat(world.y * scale))
    }

    struct PegMarker {
        /// The pegs of the string being tuned on screen: one, or both of a pair when the input names neither.
        var points: [CGPoint]
        /// The label's side: -1 left of the peg (pegs left of the head's centre), +1 right.
        var side: CGFloat
        /// The turn sign as the stage shows the peg: +1 when clockwise tightens (the rig's, turned over on a
        /// mirrored stage).
        var tighten: Int
        var slides: Bool
        /// 0 = whole instrument, 1 = headstock close-up.
        var closeUp: Float
    }

    /// The string a tapped peg node turns, as the host names pegs ("s4", or "c4a" on a pair); nil when the rig has no
    /// such peg. Node names don't always match: the violin and cello rigs wind G/E (C/A) onto pegs built as peg_s3/peg_s2.
    func pegName(forNode name: String) -> String? {
        guard let string = rig?.strings.first(where: { $0.peg == name }) else { return nil }
        return String(string.nodeName.dropFirst("string_".count))
    }

    /// The pegs of the string being tuned, projected for the stage overlay; nil before the model is on stage.
    func pegMarker(in size: CGSize) -> PegMarker? {
        guard let rig, !showcase, let anchor = currentAnchor else { return nil }
        let strings = Self.tuned(rig, anchor: anchor, peg: currentPeg)
        let points = strings.compactMap { screenPoint($0.pegPoint, in: size) }
        guard let first = strings.first, let lead = points.first else { return nil }
        let head = screenPoint(rig.head, in: size)
        let left = head.map { lead.x < $0.x } ?? true
        // A mirror image turns the other way: what tightens clockwise on the model tightens anticlockwise on screen.
        let tighten = flipX ? -first.tighten : first.tighten
        return PegMarker(points: points, side: left ? -1 : 1, tighten: tighten, slides: first.slides, closeUp: framing)
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
        frames += 1
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
        updateString(tuned.first, phase: Float(phase), locked: state.locked, active: state.listening, swing: state.marketingScale)
        updateRoll(Date())
    }

    // MARK: Every string in tune

    /// Every string in tune: the strings light one by one, lowest first, in step with the full-tune strum as it rolls
    /// across them (`SoundSynth.tunedRoll`, `count` strings), then all together as it is strummed again
    /// (`SoundSynth.tunedBloom`), each glowing in the in-tune colour and dying away as it rings.
    func rollStrings(count: Int) {
        guard let rig, let model else { return }
        if rollGlows.count != rig.strings.count {
            for glow in rollGlows { glow.removeFromParent() }
            let material = StringGlow.material(UIColor(Palette.mint), opacity: 0.3)
            rollGlows = rig.strings.map { _ -> ModelEntity in
                let glow = ModelEntity(mesh: StringGlow.mesh(), materials: [material])
                glow.isEnabled = false
                model.addChild(glow)
                return glow
            }
        }
        let now = Date()
        let step = SoundSynth.tunedRoll(count: max(1, count))
        rollStrikes = rig.strings.indices.map { now.addingTimeInterval(Double($0) * step) }
        rollBloom = now.addingTimeInterval(SoundSynth.tunedBloom(count: max(1, count)))
    }

    /// Each string's glow in the roll: struck, it flares and dies away, shimmering as it rings (still with Reduce Motion).
    private func updateRoll(_ now: Date) {
        guard let rig, let bloom = rollBloom else { return }
        guard now.timeIntervalSince(bloom) < Self.rollRing else {
            for glow in rollGlows { glow.isEnabled = false }
            rollStrikes = []
            rollBloom = nil
            return
        }
        for (index, string) in rig.strings.enumerated() where index < rollGlows.count {
            let glow = rollGlows[index]
            let struck = index < rollStrikes.count ? Self.ringLevel(now.timeIntervalSince(rollStrikes[index])) : 0
            let level = max(struck, Self.ringLevel(now.timeIntervalSince(bloom)))
            guard string.radius > 0, level > 0.02 else {
                glow.isEnabled = false
                continue
            }
            let shimmer = reduceMotion ? 1 : 0.85 + 0.15 * Float(sin(time * 2 * .pi * 7 + Double(index)))
            StringGlow.place(glow, from: string.saddlePoint, to: string.nutPoint, radius: string.radius * (2.4 + 5 * Float(level) * shimmer))
        }
    }

    /// Seconds a string glows after the last strike.
    private static let rollRing = 2.4

    /// 1 as a string is struck, dying away; 0 before it is struck and once it has rung out.
    private static func ringLevel(_ since: Double) -> Double {
        guard since >= 0, since < rollRing else { return 0 }
        return exp(-since * 2.2)
    }

    /// The rig strings being tuned: on a paired course the one `peg` names (in course order), else every
    /// string on the anchor (a rig with one string per anchor ignores `peg`).
    private static func tuned(_ rig: InstrumentRig, anchor: String?, peg: Int?) -> [InstrumentRig.StringRig] {
        let strings = rig.strings.filter { $0.anchor == anchor }
        guard let peg, strings.count > 1, strings.indices.contains(peg) else { return strings }
        return [strings[peg]]
    }

    private func updateString(_ string: InstrumentRig.StringRig?, phase: Float, locked: Bool, active: Bool, swing: Float) {
        guard let string, string.radius > 0 else { return }
        let visible = active && (energy > 0.02 || glow > 0.05)
        staticStrings[string.nodeName]?.isEnabled = !visible
        let a = string.saddlePoint, b = string.nutPoint
        let axis = simd_normalize(b - a)
        let lateral = simd_normalize(simd_cross(axis, [0, 0, 1]) + SIMD3<Float>(0, 0, 0.35))
        let amplitude = (0.0012 + 0.0042 * energy) * (1 - 0.85 * glow) * max(1, swing)
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
        }
        if let glowTube {
            if visible && glow > 0.05 {
                StringGlow.place(glowTube, from: a, to: b, radius: string.radius * (3 + 5 * glow))
            } else {
                glowTube.isEnabled = false
            }
        }
    }
}

/// SwiftUI host. Taps on a peg select its string; the peg being tuned is ringed and labelled with its turn.
///
/// For a left-handed player the stage is the mirror image of the model (a left-handed instrument), its pegs' turn
/// arrows reversed to match; the words beside the peg read as usual.
///
/// At rest it spares the device: once the host has been at rest (`resting`) for `StageRest.idle`, the camera eases back
/// to the studio picture's framing and the stage hands over to that picture (`StudioStage`, the same one the host shows
/// while the model loads), taking the 3D view away so nothing renders. Listening again brings the model straight back,
/// drawn behind the picture before it shows, and the camera glides in. In Low Power Mode or on a hot device it holds
/// the picture, live, until that passes. When every string is in tune, the strings light one by one with the full-tune
/// strum (`StageController.rollStrings`).
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
    /// The host isn't listening and holds no reading: the peg cue settles and stops redrawing (`StagePegCue.resting`),
    /// and after a while the stage rests on its studio picture.
    var resting = false
    @State private var box = StageBox()
    @State private var ready = false
    @State private var status = "make"
    @State private var attached = false
    /// The 3D view is in place (taken away while the stage rests on its picture).
    @State private var mounted = true
    /// The studio picture shows over the stage.
    @State private var still = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: AppStore
    @CurrentHand private var hand
    @ObservedObject private var power = StagePower.shared
    #if DEBUG
    /// Debug builds launched with TIMBRE_STAGE_DEBUG=1 print the load state over the stage.
    private let debug = ProcessInfo.processInfo.environment["TIMBRE_STAGE_DEBUG"] == "1"
    /// Debug builds launched with TIMBRE_DEBUG_STATE=1 say how the close-up frames the head (`headProbe`).
    private static let probe = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"
    #endif

    private var controller: StageController { box.controller }

    /// What decides whether the stage rests on its picture.
    private struct RestPlan: Equatable {
        var ready: Bool
        var resting: Bool
        var reduced: Bool
    }

    var body: some View {
        let plan = RestPlan(ready: ready, resting: resting && !showcase, reduced: power.reduced && !showcase)
        layers
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
        .onChange(of: hand) { _, _ in configure() }
        // Every string in tune: the strings light in step with the full-tune strum.
        .onChange(of: store.celebrate) { _, _ in controller.rollStrings(count: store.courses.count) }
        .onChange(of: reduceMotion, initial: true) { _, value in controller.reduceMotion = value }
        .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { size in controller.viewSize = size }
        .task(id: plan) { await follow(plan) }
        .opacity(ready ? 1 : 0)
        .animation(Motion.settle, value: ready)
        // An instrument is a picture, not text: it never mirrors for a right-to-left language, and its peg cue is
        // placed in the same left-to-right space the camera projects into (`StageInput.rightToLeft` sets the words).
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
        .accessibilityIgnoresInvertColors()
        .overlay(alignment: .bottomLeading) {
            #if DEBUG
            if debug {
                Text(status).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.8)).padding(6)
                    .accessibilityIdentifier("stage.debug")
            }
            if Self.probe { headProbe }
            #endif
        }
    }

    #if DEBUG
    /// Debug builds only: "framing=<0…1> head=<points>", how far into the close-up the camera is and how far under the
    /// stage's top edge the head's highest point stands (negative: the stage cuts the head). Clear ink, never touched.
    private var headProbe: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let frame = controller.headClearance(in: proxy.size)
                let head = frame.map { String(format: "%.1f", Double($0.top)) } ?? "none"
                Text(verbatim: "framing=\(String(format: "%.2f", Double(frame?.framing ?? 0))) head=\(head)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.clear)
                    .accessibilityIdentifier("stage.head")
            }
        }
        .allowsHitTesting(false)
    }
    #endif

    /// The model, and its studio picture over it while the stage rests.
    private var layers: some View {
        ZStack {
            if mounted {
                // Under the picture it draws at a trace rather than not at all, so coming back it has drawn before it shows.
                live
                    .opacity(still ? 0.02 : 1)
            }
            if still, let card = restCard {
                StudioStage(imageName: ModelLibrary.cardImageName(modelID), card: card, input: input, onSelect: onSelect,
                            resting: resting, startsClose: true)
                    .padding(.horizontal, StageRest.picturePadding)
                    .transition(.opacity)
            }
        }
    }

    /// The model in its scene, feathered into the screen, turned over for a left-handed player, the peg cue over it.
    private var live: some View {
        let mirrored = hand.mirrorsUpright
        return RealityView { content in
            content.camera = .virtual
            if let resource = await ModelCache.shared.environment() { controller.setEnvironment(resource) }
            configure()
            controller.reduceMotion = reduceMotion
            controller.attach(&content)
            // The model task loads and reports; attaching reports through `attached` (this closure's copy of the
            // view keeps the model id it was made with, so it never reports a model itself).
            attached = true
            if !ready { status = "attached" }
        } update: { _ in
            controller.input = input
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { value in
            var entity: Entity? = value.entity
            while let current = entity, !current.name.hasPrefix("peg_") { entity = current.parent }
            if let name = entity?.name { onSelect(controller.pegName(forNode: name) ?? String(name.dropFirst(4))) }
        })
        // Feather the edges so the stage melts into the screen whatever the renderer clears to.
        .mask { StageFeather(close: 1) }
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .overlay {
            if !showcase { StagePegCue(controller: controller, input: input, reduceMotion: reduceMotion, resting: resting, loaded: ready) }
        }
    }

    /// The studio picture the stage rests on: the model's own render with its points; nil for a model without one,
    /// which stays in 3D.
    private var restCard: StageCard? {
        guard ModelLibrary.hasCard(modelID), let rig = ModelLibrary.rig(modelID) else { return nil }
        return StageCard(rig: rig)
    }

    private func configure() {
        controller.input = input
        controller.showcase = showcase
        controller.revealClose = revealClose
        controller.flipX = hand.mirrorsUpright
    }

    /// Ready (the host retires its placeholder) only once the model this view shows is on stage and the scene is
    /// attached; failed only when the model it shows could not load. A superseded model never reports.
    private func reportLoad() {
        status = controller.status
        guard controller.wanted == modelID else { return }
        if controller.failed { onFailure() }
        else if attached && controller.loadedModel == modelID { ready = true; onReady() }
    }

    // MARK: Resting on the picture

    /// Rests on the picture at once in Low Power Mode, after `StageRest.idle` at rest; otherwise stays (or comes back)
    /// in 3D.
    private func follow(_ plan: RestPlan) async {
        guard plan.ready, restCard != nil else {
            await wake()
            return
        }
        if plan.reduced {
            await doze(after: 0)
        } else if plan.resting {
            await doze(after: StageRest.idle)
        } else {
            await wake()
        }
    }

    /// After `idle` seconds the camera eases back to the picture's framing (cut in Low Power Mode and with Reduce
    /// Motion), the picture fades in over the model, and the 3D view goes.
    private func doze(after idle: Double) async {
        if idle > 0 {
            try? await Task.sleep(for: .seconds(idle))
            guard !Task.isCancelled else { return }
        }
        if !still {
            if idle > 0 && !reduceMotion, let framing = restFraming() {
                controller.restFraming = framing
                try? await Task.sleep(for: .seconds(StageRest.pullBack))
                guard !Task.isCancelled else { return }
            }
            withMotion(Motion.reveal, reduceMotion: reduceMotion) { still = true }
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
        }
        controller.detach()
        mounted = false
    }

    /// The 3D view comes back behind the picture; once it has drawn a few frames the picture fades away and the camera
    /// glides in to the close-up.
    private func wake() async {
        if !mounted {
            mounted = true
            var waited = 0.0
            while controller.frames < 3 && waited < 1.5 {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                waited += 0.05
            }
        }
        controller.restFraming = nil
        if still { withMotion(Motion.settle, reduceMotion: reduceMotion) { still = false } }
    }

    /// The close-up framing at which the model looks as big as the studio picture's close-up does.
    private func restFraming() -> Float? {
        guard let card = restCard, let head = card.head else { return nil }
        let size = controller.viewSize
        let picture = CGSize(width: max(0, size.width - 2 * StageRest.picturePadding), height: size.height)
        let zoom = StageFrame.closeUpZoom(in: picture, head: head, tip: card.tip ?? StageFrame.tipShare)
        return controller.framing(atZoom: Float(zoom))
    }
}

/// The 3D stage resting on its studio picture (`InstrumentStage`).
enum StageRest {
    /// Seconds at rest before the stage hands over to its picture.
    static let idle = 12.0
    /// Seconds the camera takes to ease back to the picture's framing.
    static let pullBack = 1.1
    /// The picture's inset on each side, as the tuner gives its placeholder.
    static let picturePadding: CGFloat = 16
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
