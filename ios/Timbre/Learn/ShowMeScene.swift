import RealityKit
import SwiftUI
import TimbreCore
import UIKit
import simd

// MARK: - The neck, from the rig

/// The model's strings as a lesson numbers them, lowest first (as `ChordSpec.frets`): each lane is one string, or one
/// course of a paired instrument (both its strings). Every position on the neck comes from the rig's nut and saddle by
/// the equal-temperament rule: fret n lies 1 − 2^(−n/12) of the scale length from the nut (the 12th halves the string),
/// so a fingertip lands on the model's own frets whatever its scale (a 25.6″ guitar, a 13.8″ mandolin, a cello).
struct ShowMeNeck {
    struct Lane {
        /// The course's strings in the rig (two on a mandolin), each vibrating along its own line.
        let strings: [InstrumentRig.StringRig]
        /// The course's middle where it leaves the nut and where it meets the saddle.
        let nut: SIMD3<Float>
        let saddle: SIMD3<Float>
    }

    let lanes: [Lane]
    /// Violin and cello: a fingertip stops the string right on the note, with no wire to sit behind.
    let fretless: Bool
    /// Unit directions in model space: across the strings (lowest to highest), along them toward the head, and out of
    /// the board toward the player.
    let across: SIMD3<Float>
    let along: SIMD3<Float>
    let normal: SIMD3<Float>

    /// Nil when the rig's courses don't match the lesson's strings (a rig with no length to its strings, or another count).
    init?(rig: InstrumentRig, strings count: Int, fretless: Bool) {
        var anchors: [String] = []
        var groups: [String: [InstrumentRig.StringRig]] = [:]
        for string in rig.strings where string.radius > 0 {
            if groups[string.anchor] == nil { anchors.append(string.anchor) }
            groups[string.anchor, default: []].append(string)
        }
        guard count >= 1, anchors.count == count else { return nil }
        var lanes: [Lane] = []
        for anchor in anchors {
            let members = groups[anchor] ?? []
            guard !members.isEmpty else { return nil }
            let share = 1 / Float(members.count)
            let nut = members.reduce(SIMD3<Float>.zero) { $0 + $1.nutPoint } * share
            let saddle = members.reduce(SIMD3<Float>.zero) { $0 + $1.saddlePoint } * share
            guard simd_distance(nut, saddle) > 0.05 else { return nil }
            lanes.append(Lane(strings: members, nut: nut, saddle: saddle))
        }
        self.lanes = lanes
        self.fretless = fretless
        let nutMiddle = lanes.reduce(SIMD3<Float>.zero) { $0 + $1.nut } / Float(lanes.count)
        let saddleMiddle = lanes.reduce(SIMD3<Float>.zero) { $0 + $1.saddle } / Float(lanes.count)
        let along = simd_normalize(nutMiddle - saddleMiddle)
        var across = SIMD3<Float>(1, 0, 0)
        if let first = lanes.first, let last = lanes.last, lanes.count > 1 {
            across = simd_normalize((last.nut + last.saddle) - (first.nut + first.saddle))
        }
        let normal = simd_normalize(simd_cross(across, along))
        self.along = along
        self.normal = normal
        // Square to the neck's axis.
        self.across = simd_normalize(simd_cross(along, normal))
    }

    /// How far fret `n` lies from the nut, as a share of the scale length (negative: past the nut toward the head).
    static func share(fret: Double) -> Float { Float(1 - pow(2, -fret / 12)) }

    /// Where a fingertip presses for `fret`: just behind its wire on a fretted board (62 % of the way from the fret
    /// before, as a player does), on the note on a fretless one.
    func pressShare(fret: Int) -> Float {
        guard fret > 0 else { return 0 }
        let wire = Self.share(fret: Double(fret))
        guard !fretless else { return wire }
        let before = Self.share(fret: Double(fret - 1))
        return before + (wire - before) * 0.62
    }

    /// Where a string held at `fret` starts to speak: the wire it is pressed behind (the fingertip, fretless); the nut open.
    func stopShare(fret: Int) -> Float { fret > 0 ? Self.share(fret: Double(fret)) : 0 }

    /// Lane `index` at `share` of the way from the nut to the saddle (on the string, over the board).
    func point(lane index: Int, share: Float) -> SIMD3<Float> {
        let lane = lanes[max(0, min(lanes.count - 1, index))]
        return lane.nut + (lane.saddle - lane.nut) * share
    }

    /// The spacing between neighbouring lanes at `share`.
    func gap(at share: Float) -> Float {
        guard lanes.count > 1 else { return 0.009 }
        return simd_distance(point(lane: 0, share: share), point(lane: lanes.count - 1, share: share)) / Float(lanes.count - 1)
    }

    /// The rotation that lays the neck square to the camera: across → +X, along → +Y, out of the board → +Z.
    var square: simd_quatf {
        simd_quatf(simd_float3x3(columns: (across, along, normal))).inverse
    }
}

// MARK: - What the hands do

/// The fretting hand's shape for a demonstration: each fingertip (or a finger laid across several strings), the open and
/// muted strings, and the frets to frame. Strings are counted lowest first, as `ChordSpec.frets`.
struct ShowMeShape: Equatable {
    struct Press: Equatable {
        /// The strings it holds (one, or a barre's span), lowest first.
        let first: Int
        let last: Int
        let fret: Int
        /// 1 index … 4 little; nil when the lesson doesn't say.
        let finger: Int?
        /// Its place in the landing order (0 lands first).
        let rank: Int
    }

    struct Open: Equatable {
        let string: Int
        /// Its place among the notes when it is one of them (a run of notes); nil for a chord's open string, there from the start.
        let rank: Int?
    }

    let strings: Int
    let presses: [Press]
    let opens: [Open]
    let muted: Set<Int>
    /// The first fret framed and how many.
    let base: Int
    let rows: Int
    /// Each note sounds as its fingertip lands (a run of notes); a chord's strings ring when the host says (`ringing`).
    let soundsOnLanding: Bool

    /// A chord: fingertips in finger order (finger 1 first, a barre with its finger), as the chart lands them.
    @MainActor init(chord: ChordSpec) {
        let diagram = ChordDiagram(chord: chord, landingOrder: .fingers)
        let ranks = diagram.landingRanks
        let barres = diagram.barres
        let frets = chord.frets
        var presses: [Press] = barres.map { barre in
            Press(first: barre.first, last: barre.last, fret: barre.fret, finger: barre.finger, rank: ranks[safe: barre.first] ?? 0)
        }
        for i in frets.indices where frets[i] > 0 {
            if barres.contains(where: { $0.fret == frets[i] && $0.first <= i && i <= $0.last }) { continue }
            let finger = chord.fingers?[safe: i].flatMap { $0 > 0 ? $0 : nil }
            presses.append(Press(first: i, last: i, fret: frets[i], finger: finger, rank: ranks[safe: i] ?? 0))
        }
        self.strings = frets.count
        self.presses = presses
        self.opens = frets.indices.filter { frets[$0] == 0 }.map { Open(string: $0, rank: nil) }
        self.muted = Set(frets.indices.filter { frets[$0] < 0 })
        // The frets the player's view shows (`PlayerNeck`): four, more when the shape needs them.
        let base = max(1, chord.baseFret ?? 1)
        self.base = base
        self.rows = min(6, max(4, (frets.max() ?? 0) - base + 1))
        self.soundsOnLanding = false
    }

    /// Notes on the neck (`Fretting`: string 1 the highest): each lands, and sounds, in `order` (indices into `dots`).
    init(dots: [Fretting], strings: Int, order: [Int], start: Int) {
        var presses: [Press] = []
        var opens: [Open] = []
        for (rank, index) in order.enumerated() where dots.indices.contains(index) {
            let dot = dots[index]
            let lane = strings - dot.string
            guard lane >= 0, lane < strings else { continue }
            if dot.fret > 0 {
                presses.append(Press(first: lane, last: lane, fret: dot.fret, finger: dot.finger, rank: rank))
            } else {
                opens.append(Open(string: lane, rank: rank))
            }
        }
        self.strings = strings
        self.presses = presses
        self.opens = opens
        self.muted = []
        let held = presses.map(\.fret)
        let low = min(held.min() ?? max(1, start), max(1, start))
        self.base = max(1, low)
        self.rows = min(12, max(4, (held.max() ?? 0) - self.base + 1))
        self.soundsOnLanding = true
    }

    /// How many landings there are (the last one's rank + 1).
    var landingCount: Int {
        let ranks = presses.map(\.rank) + opens.compactMap(\.rank)
        return (ranks.max() ?? -1) + 1
    }
}

/// A strum demonstration: the pattern's strokes on the loop's clock (`RhythmLoop`), at its tempo.
struct ShowMeStrum: Equatable {
    let pattern: [Double]
    let beatsPerBar: Int
    let bpm: Double
    /// When a bar's beat 1 falls: the loop turns before and after it.
    let origin: Date
}

/// What a stage demonstrates.
enum ShowMeShot: Equatable {
    case fretting(ShowMeShape)
    case strum(ShowMeStrum)
}

/// The strokes of a strum and the pick riding them: the same clock and the same sweep as the 2D strum stage
/// (`StrumSweep`), so the 3D pick crosses the strings exactly when the demonstration sounds them.
struct ShowMeStrokes {
    struct Stroke {
        let time: Double
        let down: Bool
    }

    struct Pick {
        /// 0 on the thickest string's side, 1 past the thinnest.
        var position: Double
        var touching: Bool
        var down: Bool
        /// 0…1: how far it is lifted off the strings on its way back.
        var lift: Double
    }

    let pattern: [Double]
    let beatsPerBar: Int
    let secondsPerBeat: Double

    private var barSeconds: Double { Double(max(1, beatsPerBar)) * secondsPerBeat }
    /// How long a stroke takes to cross the strings; the pick passes the middle string on the beat.
    var sweepSeconds: Double { min(0.22, max(0.08, secondsPerBeat * 0.42)) }

    /// Strokes from the bar before to the bar after `t`, in time order.
    func near(_ t: Double) -> [Stroke] {
        guard barSeconds > 0, !pattern.isEmpty else { return [] }
        let current = Int((t / barSeconds).rounded(.down))
        var out: [Stroke] = []
        for bar in (current - 1)...(current + 1) {
            let start = Double(bar) * barSeconds
            for hit in pattern {
                out.append(Stroke(time: start + hit * secondsPerBeat, down: hit.truncatingRemainder(dividingBy: 1) == 0))
            }
        }
        return out.sorted { $0.time < $1.time }
    }

    func pick(at t: Double, _ strokes: [Stroke]) -> Pick {
        let half = sweepSeconds / 2
        if let stroke = strokes.first(where: { abs(t - $0.time) <= half }) {
            let f = (t - (stroke.time - half)) / sweepSeconds
            return Pick(position: stroke.down ? f : 1 - f, touching: true, down: stroke.down, lift: 0)
        }
        let previous = strokes.last { $0.time + half < t }
        let next = strokes.first { $0.time - half > t }
        if let previous, let next {
            let from = previous.time + half, to = next.time - half
            let u = to > from ? min(1, max(0, (t - from) / (to - from))) : 1
            let eased = u * u * (3 - 2 * u)
            let a: Double = previous.down ? 1 : 0
            let b: Double = next.down ? 0 : 1
            return Pick(position: a + (b - a) * eased, touching: false, down: next.down, lift: a == b ? 0 : sin(.pi * u))
        }
        if let previous { return Pick(position: previous.down ? 1 : 0, touching: false, down: previous.down, lift: 0) }
        if let next { return Pick(position: next.down ? 0 : 1, touching: false, down: next.down, lift: 0) }
        return Pick(position: 0, touching: false, down: true, lift: 0)
    }

    /// When the pick last crossed a string lying `share` of the way from the thickest side, at or before `t`.
    func lastCrossing(share: Double, at t: Double, _ strokes: [Stroke]) -> Double? {
        var latest: Double?
        for stroke in strokes {
            let time = stroke.time - sweepSeconds / 2 + (stroke.down ? share : 1 - share) * sweepSeconds
            if time <= t { latest = time }
        }
        return latest
    }
}

// MARK: - Marks drawn over the stage

/// The fingertips, the open and muted strings and the numbers, projected from the model each frame for the overlay
/// (`ShowMeMarksView`): flat values, so the drawing never touches the scene.
struct ShowMeMarks {
    struct Finger {
        /// The pad's centre (lifted while it comes down) and, for a barre, its other end.
        var tip: CGPoint
        var end: CGPoint?
        /// Under the contact on the board, for the shadow and the press ring.
        var shadow: CGPoint
        var shadowEnd: CGPoint?
        var radius: CGFloat
        /// How flat a circle lying on the board looks (1 seen square on).
        var squash: CGFloat
        var finger: Int?
        /// 0 in the air (not drawn) … 1 pressing.
        var down: CGFloat
        /// Seconds since it pressed, while the press ring and squash run.
        var since: Double?
    }

    struct Ring {
        var point: CGPoint
        var radius: CGFloat
        /// The string's colour on the runway (`HighwayRunway.color`).
        var tint: Color
        var lit: Bool
        var alpha: CGFloat
    }

    struct Label {
        var point: CGPoint
        var value: Int
        var tint: Color
        var lit: Bool
        var faint: Bool
    }

    var fingers: [Finger] = []
    var opens: [Ring] = []
    var mutes: [Ring] = []
    var frets: [Label] = []
    var strings: [Label] = []
}

// MARK: - The stage

/// Drives a "Show me" demonstration on the course instrument's 3D model: the camera glides in to the neck where the
/// chord or the notes are played (or to where the strings are strummed), seen as the player's view shows a neck (nut
/// far, lowest string on the left) or, for a strum, as a teacher's video does (strings across, the thickest on top, so a
/// down stroke falls down the screen). Strings shimmer as they sound, each between where it is stopped and the
/// saddle; a pick sweeps the strings on every stroke. The fingertips and marks are drawn over it (`marks(in:now:)`).
@MainActor
final class ShowMeController {
    let root = Entity()
    let camera = PerspectiveCamera()
    /// The model is on stage.
    private(set) var loaded = false
    /// The model can't be shown (no rig that fits, or it failed to load).
    private(set) var failed = false
    private var loadedID: String?
    /// The model's parent: turned and moved to frame the shot (the camera stays at the origin looking down −Z).
    private let holder = Entity()
    private(set) var neck: ShowMeNeck?
    private var wires: [Wire] = []
    private var staticStrings: [String: Entity] = [:]
    private var pick: ModelEntity?
    private var pickHalo: ModelEntity?
    private let light = Entity()
    private var subscription: EventSubscription?

    // Inputs, set by the view.
    var shot: ShowMeShot? { didSet { if shot != oldValue { plan = nil } } }
    var ringing: Set<Int> = []
    var landStart: Date?
    var landingStep: Double = 0.45
    var viewSize: CGSize = .zero { didSet { if viewSize != oldValue { plan = nil } } }

    /// When each lane (lowest first) was struck: by the host lighting it (`strike`), or on its fingertip's landing.
    private var strikes: [Int: [Date]] = [:]
    /// The glide in from a wider shot: 0 as the model appears, 1 framed.
    private var glide: Float = 1
    private var glideVelocity: Float = 0
    private var plan: Plan?
    /// The pick's tip: +1 toward the thinnest string (a down stroke), −1 toward the thickest; it turns between strokes.
    private var pickTip: Float = 1
    private var pickFlash: Float = 0

    private struct Plan {
        let rotation: simd_quatf
        let aim: SIMD3<Float>
        let distance: Float
        let startRotation: simd_quatf
        let startAim: SIMD3<Float>
        let startDistance: Float
    }

    /// One string of the model, redrawn while it rings or glows (its static mesh hides meanwhile).
    private final class Wire {
        let lane: Int
        let rig: InstrumentRig.StringRig
        /// The held part (nut to the stop) first, then the speaking length.
        let segments: [ModelEntity]
        let halo: [ModelEntity]
        var shown = false
        /// Drawn still (not ringing) at this stop and glow: nothing to redraw until one changes or it rings.
        var resting: (stop: Float, glow: Float)?
        init(lane: Int, rig: InstrumentRig.StringRig, segments: [ModelEntity], halo: [ModelEntity]) {
            self.lane = lane; self.rig = rig; self.segments = segments; self.halo = halo
        }
    }

    /// Segments along a speaking length.
    private static let speaking = 22
    private static let fieldOfView: Float = 30
    /// The player's-view shot: tilted back so the head goes away from the camera, as the player's-view neck lies
    /// (`PlayerNeck`). The glide swings in to it from the bass side.
    private static let tilt: Float = 1.05
    private static let swing: Float = 0.38
    /// Where the pick crosses the strings, as a share of the scale from the nut (about a sixth of it from the saddle).
    private static let pickShare: Float = 0.83
    /// Glide stiffness (rad/s): about 0.9 s from the wide shot to the frame.
    private static let glideRate: Float = 5.2
    /// How long a struck string rings.
    private static let ringSeconds = 1.8

    init() {
        camera.camera.fieldOfViewInDegrees = Self.fieldOfView
        camera.position = .zero
        root.addChild(camera)
        root.addChild(holder)
    }

    func attach(_ content: inout RealityViewCameraContent) {
        content.add(root)
        subscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated { self?.tick(Float(event.deltaTime)) }
        }
    }

    func setEnvironment(_ resource: EnvironmentResource) {
        light.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.4))
        if light.parent == nil { root.addChild(light) }
        receiveImageBasedLight(holder)
    }

    private func receiveImageBasedLight(_ entity: Entity) {
        guard light.components.has(ImageBasedLightComponent.self) else { return }
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: light))
        for child in entity.children { receiveImageBasedLight(child) }
    }

    // MARK: Loading

    /// Puts model `id` on stage (once): its strings matched to the lesson's, lowest first.
    func load(_ id: String, strings: Int, fretless: Bool, accent: Color) async {
        guard loadedID != id else { return }
        guard let rig = ModelLibrary.rig(id), let neck = ShowMeNeck(rig: rig, strings: strings, fretless: fretless) else {
            failed = true
            return
        }
        guard let model = await ModelCache.shared.instance(of: id) else {
            failed = true
            return
        }
        guard !Task.isCancelled else { return }
        install(model, rig: rig, neck: neck, accent: UIColor(accent))
        loadedID = id
    }

    private func install(_ model: Entity, rig: InstrumentRig, neck: ShowMeNeck, accent: UIColor) {
        for child in Array(holder.children) { child.removeFromParent() }
        holder.addChild(model)
        self.neck = neck
        staticStrings = [:]
        for string in rig.strings {
            if let node = model.findEntity(named: string.nodeName) { staticStrings[string.nodeName] = node }
        }
        let mesh = MeshResource.generateCylinder(height: 1, radius: 1)
        var plain = PhysicallyBasedMaterial()
        plain.baseColor = .init(tint: UIColor(white: 0.88, alpha: 1))
        plain.metallic = 1.0
        plain.roughness = 0.26
        var wound = PhysicallyBasedMaterial()
        wound.baseColor = .init(tint: UIColor(red: 0.86, green: 0.76, blue: 0.58, alpha: 1))
        wound.metallic = 1.0
        wound.roughness = 0.34
        var glow = UnlitMaterial(color: accent.withAlphaComponent(0.4))
        glow.blending = .transparent(opacity: 0.4)
        wires = []
        for (index, lane) in neck.lanes.enumerated() {
            for string in lane.strings {
                let metal = string.wound ? wound : plain
                let segments = (0...Self.speaking).map { _ in Self.part(mesh, metal, in: holder) }
                let halo = (0..<Self.speaking).map { _ in Self.part(mesh, glow, in: holder) }
                wires.append(Wire(lane: index, rig: string, segments: segments, halo: halo))
            }
        }
        makePick(accent: accent)
        addLights()
        receiveImageBasedLight(holder)
        plan = nil
        glide = 0
        glideVelocity = 0
        loaded = true
    }

    private static func part(_ mesh: MeshResource, _ material: any RealityKit.Material, in parent: Entity) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.isEnabled = false
        parent.addChild(entity)
        return entity
    }

    /// A glowing pick in the accent, and the soft light around it.
    private func makePick(accent: UIColor) {
        var face = PhysicallyBasedMaterial()
        face.baseColor = .init(tint: accent)
        face.metallic = 0.0
        face.roughness = 0.3
        face.emissiveColor = .init(color: accent)
        face.emissiveIntensity = 0.55
        face.faceCulling = .none
        let mesh = ShowMePickMesh.make() ?? MeshResource.generateSphere(radius: 0.5)
        let pick = ModelEntity(mesh: mesh, materials: [face])
        pick.isEnabled = false
        holder.addChild(pick)
        self.pick = pick
        var aura = UnlitMaterial(color: accent.withAlphaComponent(0.22))
        aura.blending = .transparent(opacity: 0.22)
        let halo = ModelEntity(mesh: MeshResource.generateSphere(radius: 1), materials: [aura])
        halo.isEnabled = false
        holder.addChild(halo)
        pickHalo = halo
    }

    private func addLights() {
        guard root.findEntity(named: "showme.key") == nil else { return }
        let key = DirectionalLight()
        key.name = "showme.key"
        key.light.color = UIColor(red: 1, green: 0.9, blue: 0.78, alpha: 1)
        key.light.intensity = 2400
        key.look(at: [0, 0, -0.4], from: [-0.8, 1.2, 0.6], relativeTo: nil)
        root.addChild(key)
        let rim = DirectionalLight()
        rim.name = "showme.rim"
        rim.light.color = UIColor(red: 0.7, green: 0.82, blue: 1, alpha: 1)
        rim.light.intensity = 1300
        rim.look(at: [0, 0, -0.4], from: [1.2, 0.5, -1.6], relativeTo: nil)
        root.addChild(rim)
    }

    /// The camera glides in from a wider shot (the model has just appeared), placed at once so nothing projects from
    /// an unframed stage.
    func beginGlide() {
        glide = 0
        glideVelocity = 0
        applyFraming(0)
    }

    /// Strings the host just lit start to ring now.
    func strike(_ lanes: Set<Int>) {
        let now = Date()
        for lane in lanes { strikes[lane, default: []].append(now) }
    }

    /// A run of notes sounds each one as its fingertip lands: their strikes are set out on the landing's clock, and
    /// ring on after it ends.
    func schedule(_ start: Date?) {
        guard let start, case let .fretting(shape)? = shot, shape.soundsOnLanding else { return }
        // A replay takes over from a run still to come.
        let now = Date()
        for (lane, times) in strikes { strikes[lane] = times.filter { $0 <= now } }
        for press in shape.presses {
            let at = start.addingTimeInterval(Double(press.rank) * landingStep)
            for lane in press.first...press.last { strikes[lane, default: []].append(at) }
        }
        for open in shape.opens {
            guard let rank = open.rank else { continue }
            strikes[open.string, default: []].append(start.addingTimeInterval(Double(rank) * landingStep))
        }
    }

    // MARK: Framing

    private func makePlan() -> Plan? {
        guard let neck, let shot, viewSize.width > 20, viewSize.height > 20 else { return nil }
        switch shot {
        case let .fretting(shape): return frettingPlan(neck, shape)
        case .strum: return strumPlan(neck)
        }
    }

    /// The shape's frets, from just past the nut (room for the open and muted marks) to past the last fret shown (room
    /// for the string numbers), with the fret numbers' column on the bass side.
    private func frettingPlan(_ neck: ShowMeNeck, _ shape: ShowMeShape) -> Plan {
        let far = Self.markShare(shape) - 0.012
        let near = Self.numbersShare(shape) + 0.012
        let last = neck.lanes.count - 1
        var points: [SIMD3<Float>] = []
        for share in [far, near] {
            let gap = neck.gap(at: share)
            points.append(neck.point(lane: 0, share: share) - neck.across * gap * 1.7)
            points.append(neck.point(lane: last, share: share) + neck.across * gap * 0.9)
        }
        let aim = points.reduce(SIMD3<Float>.zero, +) / Float(points.count)
        let rotation = simd_quatf(angle: -Self.tilt, axis: [1, 0, 0]) * neck.square
        let distance = fit(points, aim: aim, rotation: rotation, marginX: 0.9, marginY: 0.9)
        let wide = simd_quatf(angle: -(Self.tilt - 0.45), axis: [1, 0, 0]) * simd_quatf(angle: Self.swing, axis: [0, 1, 0]) * neck.square
        return Plan(rotation: rotation, aim: aim, distance: distance,
                    startRotation: wide, startAim: aim + neck.along * 0.05, startDistance: distance * 2.3)
    }

    /// Where the strings are strummed, from the saddle to toward the neck, strings across the frame with the thickest on
    /// top: turned a little so the neck runs away to the right and the top falls away from the camera.
    private func strumPlan(_ neck: ShowMeNeck) -> Plan {
        let last = neck.lanes.count - 1
        var points: [SIMD3<Float>] = []
        for share: Float in [0.72, 1.0] {
            let gap = max(neck.gap(at: share), 0.006)
            points.append(neck.point(lane: 0, share: share) - neck.across * gap * 1.8)
            points.append(neck.point(lane: last, share: share) + neck.across * gap * 1.8)
        }
        let aim = points.reduce(SIMD3<Float>.zero, +) / Float(points.count)
        let roll = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        let rotation = simd_quatf(angle: 0.72, axis: [0, 1, 0]) * simd_quatf(angle: -0.32, axis: [1, 0, 0]) * roll * neck.square
        let distance = fit(points, aim: aim, rotation: rotation, marginX: 0.94, marginY: 0.8)
        let wide = simd_quatf(angle: 1.05, axis: [0, 1, 0]) * simd_quatf(angle: -0.15, axis: [1, 0, 0]) * roll * neck.square
        return Plan(rotation: rotation, aim: aim, distance: distance,
                    startRotation: wide, startAim: aim + neck.along * 0.04, startDistance: distance * 1.9)
    }

    /// The camera distance at which every point (turned by `rotation` about `aim`) sits inside the frame's margins:
    /// a point's height on screen is y / ((distance − z) · tan(fov/2)) of the half-height, its width likewise.
    private func fit(_ points: [SIMD3<Float>], aim: SIMD3<Float>, rotation: simd_quatf, marginX: Float, marginY: Float) -> Float {
        let t = tan(Self.fieldOfView * .pi / 360)
        let aspect = Float(viewSize.width / max(1, viewSize.height))
        var distance: Float = 0.08
        for p in points {
            let q = rotation.act(p - aim)
            distance = max(distance, q.z + abs(q.y) / (t * marginY), q.z + abs(q.x) / (t * aspect * marginX))
        }
        return distance
    }

    /// Over the nut (or the first fret shown, up the neck): the open and muted marks.
    private static func markShare(_ shape: ShowMeShape) -> Float {
        shape.base <= 1 ? -0.018 : ShowMeNeck.share(fret: Double(shape.base - 1)) - 0.012
    }

    /// Past the last fret shown: the string numbers.
    private static func numbersShare(_ shape: ShowMeShape) -> Float {
        ShowMeNeck.share(fret: Double(shape.base - 1 + shape.rows)) + 0.02
    }

    private func applyFraming(_ dt: Float) {
        if plan == nil { plan = makePlan() }
        guard let plan else { return }
        var remaining = max(0, min(dt, 0.25))
        while remaining > 0 && glide < 1 {
            let h = min(remaining, 1 / 120)
            let omega = Self.glideRate
            glideVelocity += (omega * omega * (1 - glide) - 2 * omega * glideVelocity) * h
            glide += glideVelocity * h
            remaining -= h
        }
        if glide > 0.9995 { glide = 1; glideVelocity = 0 }
        let g = max(0, min(1, glide))
        let rotation = simd_slerp(plan.startRotation, plan.rotation, g)
        let aim = simd_mix(plan.startAim, plan.aim, SIMD3<Float>(repeating: g))
        let distance = plan.startDistance * pow(plan.distance / max(plan.startDistance, 0.001), g)
        holder.orientation = rotation
        holder.position = -rotation.act(aim) + SIMD3<Float>(0, 0, -distance)
    }

    /// Where a model-space point lands in the stage view, in points (the camera at the origin looking down −Z with a
    /// vertical field of view, as `StageController.screenPoint`); nil behind the camera.
    func project(_ p: SIMD3<Float>, in size: CGSize) -> CGPoint? {
        guard loaded, size.width > 0, size.height > 0 else { return nil }
        let world = holder.orientation.act(p) + holder.position
        let depth = -world.z
        guard depth > 0.01 else { return nil }
        let scale = Float(size.height) / 2 / (depth * tan(Self.fieldOfView * .pi / 360))
        return CGPoint(x: size.width / 2 + CGFloat(world.x * scale), y: size.height / 2 - CGFloat(world.y * scale))
    }

    /// The camera is still gliding in.
    var gliding: Bool { glide < 1 }

    // MARK: Every frame

    private func tick(_ dt: Float) {
        guard dt > 0, loaded else { return }
        applyFraming(dt)
        let now = Date()
        prune(now)
        switch shot {
        case let .fretting(shape)?:
            pick?.isEnabled = false
            pickHalo?.isEnabled = false
            updateFretting(shape, now: now)
        case let .strum(strum)?:
            updateStrum(strum, now: now, dt: dt)
        case nil:
            break
        }
    }

    private func prune(_ now: Date) {
        for (lane, times) in strikes {
            let kept = times.filter { now.timeIntervalSince($0) < Self.ringSeconds + 0.5 }
            strikes[lane] = kept.isEmpty ? nil : kept
        }
    }

    /// How strongly lane `lane` rings now (1 as it is struck, dying away), and the seconds since that strike.
    private func ring(_ lane: Int, now: Date) -> (level: Float, since: Float) {
        var best: (level: Float, since: Float) = (0, 0)
        for at in strikes[lane] ?? [] {
            let t = now.timeIntervalSince(at)
            guard t >= 0, t < Self.ringSeconds else { continue }
            let level = Float(exp(-t * 2.4))
            if level > best.level { best = (level, Float(t)) }
        }
        return best
    }

    /// Whether the fingertip of `rank` is down at `now` (all of them with no landing running).
    private func landed(_ rank: Int, now: Date) -> Bool {
        guard let landStart else { return true }
        return now.timeIntervalSince(landStart) >= Double(rank) * landingStep
    }

    private func updateFretting(_ shape: ShowMeShape, now: Date) {
        guard let neck else { return }
        for wire in wires {
            let lane = wire.lane
            let muted = shape.muted.contains(lane)
            // Stopped by the fingertip that landed last on it (a finger over a barre, the newest note of a run).
            let holding = shape.presses.filter { $0.first <= lane && lane <= $0.last && landed($0.rank, now: now) }
                .max { $0.rank < $1.rank }
            let stop = holding.map { neck.stopShare(fret: $0.fret) } ?? 0
            let open = shape.opens.contains { $0.string == lane && landed($0.rank ?? 0, now: now) }
            let rung = ring(lane, now: now)
            let lit = ringing.contains(lane)
            var glow: Float = muted ? 0 : max(rung.level * 0.9, lit ? 0.55 : 0)
            if open && !muted { glow = max(glow, 0.28) }
            draw(wire, stop: stop, level: muted ? 0 : rung.level, glow: glow, since: rung.since, curve: 1.7)
        }
    }

    private func updateStrum(_ strum: ShowMeStrum, now: Date, dt: Float) {
        guard let neck else { return }
        let strokes = ShowMeStrokes(pattern: strum.pattern, beatsPerBar: strum.beatsPerBar, secondsPerBeat: 60 / max(30, strum.bpm))
        let t = now.timeIntervalSince(strum.origin)
        let nearby = strokes.near(t)
        let count = max(1, neck.lanes.count)
        for wire in wires {
            let share = count > 1 ? Double(wire.lane) / Double(count - 1) : 0.5
            let crossed = strokes.lastCrossing(share: share, at: t, nearby)
            let since = crossed.map { t - $0 } ?? 10
            let level = since < 2 ? Float(exp(-since * 3.6)) : 0
            draw(wire, stop: 0, level: level, glow: level * 0.8, since: Float(since), curve: 1)
        }
        placePick(neck, state: strokes.pick(at: t, nearby), dt: dt)
    }

    /// The pick over where the strings are strummed: crossing them while it strokes, lifted off them on its way back,
    /// its tip leading the stroke (down the screen on a down stroke) and turning over between strokes.
    private func placePick(_ neck: ShowMeNeck, state: ShowMeStrokes.Pick, dt: Float) {
        guard let pick, let pickHalo else { return }
        let first = neck.point(lane: 0, share: Self.pickShare)
        let last = neck.point(lane: neck.lanes.count - 1, share: Self.pickShare)
        let spread = max(simd_distance(first, last), 0.02)
        let size = max(0.013, min(0.026, spread * 0.42))
        let reach: Float = 0.3
        let f = -reach + (1 + 2 * reach) * Float(state.position)
        let lift = Float(state.lift)
        var position = first + (last - first) * f
        position += neck.normal * (0.003 + lift * 0.016) + neck.along * (lift * 0.008)
        let target: Float = state.down ? 1 : -1
        pickTip += (target - pickTip) * min(1, dt * 14)
        let sideways = neck.across * pickTip + neck.along * ((1 - abs(pickTip)) * 0.9)
        let tip = simd_normalize(sideways - neck.normal * 0.3)
        let side = simd_normalize(simd_cross(tip, neck.normal))
        let face = simd_cross(side, tip)
        pick.orientation = simd_quatf(simd_float3x3(columns: (side, tip, face)))
        // The tip reaches a little past the strings it is crossing.
        pick.position = position - tip * size * 0.3
        pick.scale = SIMD3<Float>(repeating: size)
        pick.isEnabled = true
        pickFlash = state.touching ? 1 : max(0, pickFlash - dt * 3)
        pickHalo.position = position
        pickHalo.scale = SIMD3<Float>(repeating: size * (0.75 + 0.35 * pickFlash))
        pickHalo.isEnabled = true
    }

    /// Redraws one string: straight from the nut to where it is stopped, then along its speaking length bowing in a
    /// slow-motion standing wave with a ripple running along it, dying away; a glow along it while it rings or (open)
    /// rests lit. `curve` packs the segments toward the stop, where a player's-view shot looks. At rest the model's own
    /// string shows instead.
    private func draw(_ wire: Wire, stop: Float, level: Float, glow: Float, since: Float, curve: Float) {
        let visible = level > 0.01 || glow > 0.04
        if !visible {
            if wire.shown {
                for segment in wire.segments { segment.isEnabled = false }
                for segment in wire.halo { segment.isEnabled = false }
                staticStrings[wire.rig.nodeName]?.isEnabled = true
                wire.shown = false
            }
            wire.resting = nil
            return
        }
        let still = level <= 0.01
        if still, let resting = wire.resting, resting.stop == stop, abs(resting.glow - glow) < 0.005 { return }
        wire.resting = still ? (stop: stop, glow: glow) : nil
        wire.shown = true
        staticStrings[wire.rig.nodeName]?.isEnabled = false
        guard let neck else { return }
        let nut = wire.rig.nutPoint
        let saddle = wire.rig.saddlePoint
        let held = nut + (saddle - nut) * stop
        let lateral = simd_normalize(neck.across + neck.normal * 0.3)
        let radius = wire.rig.radius * 1.2
        // Bass strings swing wider; each lane at its own (slowed) speed.
        let gauge = Float(neck.lanes.count - wire.lane) / Float(max(1, neck.lanes.count))
        let amplitude = (0.0013 + 0.0011 * gauge) * level
        let f1 = 6.5 + 0.7 * Float(wire.lane)
        let phase = Float(wire.lane) * 1.3
        place(wire.segments[0], from: nut, to: held, radius: radius, enabled: stop > 0.0005)
        var previous = held
        for k in 1...Self.speaking {
            let v = pow(Float(k) / Float(Self.speaking), curve)
            let envelope = max(0, sin(.pi * v)).squareRoot()
            let standing = sin(2 * .pi * f1 * since + phase) + 0.35 * sin(2 * .pi * v) * sin(2 * .pi * f1 * 1.97 * since + 0.6)
            let ripple = 0.45 * sin(2 * .pi * (v * 6 - since * 2.6))
            let offset = amplitude * envelope * (standing + ripple)
            let point = held + (saddle - held) * v + lateral * offset
            place(wire.segments[k], from: previous, to: point, radius: radius, enabled: true)
            let halo = wire.halo[k - 1]
            if glow > 0.04 {
                place(halo, from: previous, to: point, radius: wire.rig.radius * (2.6 + 6 * glow), enabled: true)
            } else {
                halo.isEnabled = false
            }
            previous = point
        }
    }

    private func place(_ segment: ModelEntity, from p: SIMD3<Float>, to q: SIMD3<Float>, radius: Float, enabled: Bool) {
        let length = simd_length(q - p)
        guard enabled, length > 1e-5 else {
            segment.isEnabled = false
            return
        }
        segment.isEnabled = true
        segment.position = (p + q) / 2
        segment.orientation = simd_quatf(from: [0, 1, 0], to: (q - p) / length)
        segment.scale = [radius, length * 1.02, radius]
    }

    // MARK: Marks

    /// The fingertips (far ones first, so nearer ones lie over them), the open and muted marks and the numbers, as they
    /// stand at `now` in a view of `size`.
    func marks(in size: CGSize, now: Date, ringing lit: Set<Int>) -> ShowMeMarks? {
        guard let neck, case let .fretting(shape)? = shot, loaded else { return nil }
        var marks = ShowMeMarks()
        let count = neck.lanes.count
        marks.fingers = shape.presses.sorted { a, b in a.fret < b.fret }.compactMap { finger($0, neck, size: size, now: now) }
        let markShare = Self.markShare(shape)
        let gap = neck.gap(at: markShare)
        for open in shape.opens {
            guard let point = project(neck.point(lane: open.string, share: markShare), in: size) else { continue }
            let alpha: CGFloat = open.rank.map { touchDown($0, now: now) } ?? 1
            guard alpha > 0.01 else { continue }
            let radius = projectedLength(neck.point(lane: open.string, share: markShare), neck.across * gap * 0.32, size: size)
            marks.opens.append(ShowMeMarks.Ring(point: point, radius: radius, tint: HighwayRunway.color(string: count - open.string, of: count),
                                                lit: lit.contains(open.string), alpha: alpha))
        }
        for lane in shape.muted.sorted() {
            guard let point = project(neck.point(lane: lane, share: markShare), in: size) else { continue }
            let radius = projectedLength(neck.point(lane: lane, share: markShare), neck.across * gap * 0.32, size: size)
            marks.mutes.append(ShowMeMarks.Ring(point: point, radius: radius, tint: Palette.inkSoft, lit: false, alpha: 1))
        }
        if !neck.fretless {
            for k in 1...max(1, shape.rows) {
                let fret = shape.base + k - 1
                let middle = (ShowMeNeck.share(fret: Double(fret - 1)) + ShowMeNeck.share(fret: Double(fret))) / 2
                let side = neck.point(lane: 0, share: middle) - neck.across * neck.gap(at: middle) * 1.25
                guard let point = project(side, in: size) else { continue }
                let held = shape.presses.contains { $0.fret == fret && touchDown($0.rank, now: now) >= 1 }
                marks.frets.append(ShowMeMarks.Label(point: point, value: fret, tint: Palette.inkFaint, lit: held, faint: false))
            }
        }
        let numbers = Self.numbersShare(shape)
        for lane in 0..<count {
            guard let point = project(neck.point(lane: lane, share: numbers), in: size) else { continue }
            marks.strings.append(ShowMeMarks.Label(point: point, value: count - lane, tint: HighwayRunway.color(string: count - lane, of: count),
                                                   lit: lit.contains(lane), faint: shape.muted.contains(lane)))
        }
        return marks
    }

    /// The strum's outer strings, for their names: above the top string and below the bottom one, near the bridge.
    func strumEdges(in size: CGSize) -> (top: CGPoint, bottom: CGPoint)? {
        guard let neck, case .strum? = shot, loaded else { return nil }
        let share: Float = 0.93
        let gap = max(neck.gap(at: share), 0.006)
        let top = neck.point(lane: 0, share: share) - neck.across * gap * 1.1
        let bottom = neck.point(lane: neck.lanes.count - 1, share: share) + neck.across * gap * 1.1
        guard let a = project(top, in: size), let b = project(bottom, in: size) else { return nil }
        return (a, b)
    }

    /// How far a fingertip of `rank` has come down at `now`: 0 in the air, 1 pressing (always 1 with no landing).
    private func touchDown(_ rank: Int, now: Date) -> CGFloat {
        guard let landStart else { return 1 }
        let t = now.timeIntervalSince(landStart) - Double(rank) * landingStep
        if t >= 0 { return 1 }
        return t > -0.2 ? CGFloat(1 + t / 0.2) : 0
    }

    private func finger(_ press: ShowMeShape.Press, _ neck: ShowMeNeck, size: CGSize, now: Date) -> ShowMeMarks.Finger? {
        let down = touchDown(press.rank, now: now)
        guard down > 0.01 else { return nil }
        var since: Double?
        if let landStart {
            let t = now.timeIntervalSince(landStart) - Double(press.rank) * landingStep
            if t >= 0 && t < 0.6 { since = t }
        }
        let share = neck.pressShare(fret: press.fret)
        let gap = neck.gap(at: share)
        let radiusMetres = min(gap * 0.42, 0.0085)
        let air = 1 - Float(down * down)
        let lift = neck.normal * (0.0015 + 0.024 * air)
        let board = neck.normal * -0.003
        let start = neck.point(lane: press.first, share: share)
        let end = neck.point(lane: press.last, share: share)
        guard let tip = project(start + lift, in: size), let shadow = project(start + board, in: size) else { return nil }
        var tipEnd: CGPoint?
        var shadowEnd: CGPoint?
        if press.last != press.first {
            tipEnd = project(end + lift, in: size)
            shadowEnd = project(end + board, in: size)
        }
        let radius = projectedLength(start + lift, neck.across * radiusMetres, size: size)
        let along = projectedLength(start, neck.along * radiusMetres, size: size)
        let flat = projectedLength(start, neck.across * radiusMetres, size: size)
        let squash = flat > 0 ? max(0.25, min(1, along / flat)) : 1
        return ShowMeMarks.Finger(tip: tip, end: tipEnd, shadow: shadow, shadowEnd: shadowEnd, radius: radius, squash: squash,
                                  finger: press.finger, down: down, since: since)
    }

    /// The length on screen of `vector` laid at model point `p`.
    private func projectedLength(_ p: SIMD3<Float>, _ vector: SIMD3<Float>, size: CGSize) -> CGFloat {
        guard let a = project(p, in: size), let b = project(p + vector, in: size) else { return 0 }
        return hypot(b.x - a.x, b.y - a.y)
    }
}

// MARK: - The pick's shape

/// A guitar pick: a rounded triangle (a tight round at the tip, broad shoulders), a little thick, its tip at +Y, unit
/// height from the shoulders' back to the tip. Built once.
@MainActor
enum ShowMePickMesh {
    private static var cached: MeshResource?

    static func make() -> MeshResource? {
        if let cached { return cached }
        let outline = Self.outline()
        guard outline.count >= 3 else { return nil }
        let half: Float = 0.045
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        // Front and back faces: a fan from the middle (the outline is convex).
        for (z, facing) in [(half, Float(1)), (-half, Float(-1))] {
            let center = UInt32(positions.count)
            positions.append(SIMD3<Float>(0, 0.08, z))
            normals.append(SIMD3<Float>(0, 0, facing))
            for point in outline {
                positions.append(SIMD3<Float>(point.x, point.y, z))
                normals.append(SIMD3<Float>(0, 0, facing))
            }
            let n = UInt32(outline.count)
            for i in 0..<n {
                let a = center + 1 + i
                let b = center + 1 + (i + 1) % n
                if facing > 0 { indices += [center, a, b] } else { indices += [center, b, a] }
            }
        }
        // The rim.
        for i in 0..<outline.count {
            let p = outline[i], q = outline[(i + 1) % outline.count]
            let edge = q - p
            let out = simd_normalize(SIMD3<Float>(edge.y, -edge.x, 0))
            let base = UInt32(positions.count)
            positions += [SIMD3(p.x, p.y, half), SIMD3(q.x, q.y, half), SIMD3(q.x, q.y, -half), SIMD3(p.x, p.y, -half)]
            normals += [out, out, out, out]
            indices += [base, base + 2, base + 1, base, base + 3, base + 2]
        }
        var descriptor = MeshDescriptor(name: "showme.pick")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        let mesh = try? MeshResource.generate(from: [descriptor])
        cached = mesh
        return mesh
    }

    /// The convex outline, counter-clockwise: the hull of a small round at the tip and two broad ones at the shoulders.
    private static func outline() -> [SIMD2<Float>] {
        let rounds: [(center: SIMD2<Float>, radius: Float)] = [
            (SIMD2(0, 0.42), 0.08),
            (SIMD2(-0.24, -0.28), 0.22),
            (SIMD2(0.24, -0.28), 0.22)
        ]
        var points: [SIMD2<Float>] = []
        for round in rounds {
            for k in 0..<28 {
                let a = Float(k) / 28 * 2 * .pi
                points.append(round.center + SIMD2(cos(a), sin(a)) * round.radius)
            }
        }
        return hull(points)
    }

    /// Andrew's monotone chain: the convex hull, counter-clockwise.
    private static func hull(_ input: [SIMD2<Float>]) -> [SIMD2<Float>] {
        let points = input.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        guard points.count > 2 else { return points }
        func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [SIMD2<Float>] = []
        for p in points {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        var upper: [SIMD2<Float>] = []
        for p in points.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }
}
