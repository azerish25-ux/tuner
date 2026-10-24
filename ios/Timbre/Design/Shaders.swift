import SwiftUI

// Timbre's signature Metal effects (Design/Shaders.metal): the lock shimmer over the tuner's stage, the lamp and the
// lock's ring of light on the chromatic strobe and the heat glow on reward stars. Each one decorates a view that already says everything on its
// own, runs only for its moment (no idle frames) and steps aside under Reduce Motion and in Low Power Mode.

enum ShaderFX {
    /// Whether the decorative shaders may run now: not with Reduce Motion, not in Low Power Mode.
    static func allowed(reduceMotion: Bool) -> Bool {
        !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

/// The moment a string locks, for an effect drawn by a stage's own timeline. A class, stepped every frame, so the
/// steps never invalidate a view.
final class LockFlash {
    private var key: String?
    private var wasLocked = false
    private var lockedAt: Double?

    /// Seconds since `key` (the string being tuned) locked, while that moment lasts (`duration`); nil otherwise.
    /// The first frame (a stage that opens already locked) and a change of string never flash, and a lock that
    /// flickers off and on mid-flash doesn't start it again.
    func step(locked: Bool, key: String, now: Double, duration: Double) -> Double? {
        guard key == self.key else {
            self.key = key
            wasLocked = locked
            lockedAt = nil
            return nil
        }
        if locked && !wasLocked && lockedAt == nil { lockedAt = now }
        wasLocked = locked
        guard let start = lockedAt else { return nil }
        let elapsed = now - start
        guard elapsed >= 0, elapsed < duration else {
            lockedAt = nil
            return nil
        }
        return elapsed
    }
}

/// The lock shimmer (`timbreLockShimmer`): the moment a string locks, a flash and a ring leave its peg, a band of
/// light sweeps down the headstock and a comet runs down the string from its post past the nut. Drawn over the stage
/// (3D or 2D) in the stage's own points and added to the light already there; the stage itself is untouched.
struct LockShimmer: View {
    /// The peg's ring, where the string leaves the head (its post, else the peg), its nut and its saddle.
    let peg: CGPoint
    let post: CGPoint
    let nut: CGPoint
    let saddle: CGPoint
    /// The headstock (the box around every peg and nut), which the band sweeps; nil sweeps nothing.
    let head: CGRect?
    /// Seconds since the lock.
    let elapsed: Double
    var tint: Color = Palette.mint

    /// How long it runs: over before the tuner moves on to the other string of a pair (1.2 s).
    static let duration = 1.15

    var body: some View {
        let box = head ?? .zero
        Rectangle()
            .fill(Color.white)
            .colorEffect(ShaderLibrary.timbreLockShimmer(
                .float2(peg), .float2(post), .float2(nut), .float2(saddle),
                .float4(box.minX, box.minY, box.width, box.height),
                .float(elapsed), .color(tint)))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

enum StrobeRipple {
    /// The lock's ring of light rolls across the disc in this many seconds.
    static let shock = 0.9
}

extension View {
    /// The chromatic strobe disc as a liquid surface (`timbreStrobeRipple`): ripples run out through its rings when
    /// the pitch is sharp and in when it is flat, at the strobe's `phase` (0..<1) and `depth` (0…1, how far off),
    /// and the disc stands still in tune. `shock` (seconds since the lock) rolls one ring of light out across it.
    /// Off when `enabled` is false, and whenever there is nothing to show.
    func strobeRipple(phase: Double, depth: Double, shock: Double?, enabled: Bool, tint: Color = Palette.mint) -> some View {
        layerEffect(ShaderLibrary.timbreStrobeRipple(.boundingRect, .float(phase), .float(depth),
                                                     .float(shock ?? StrobeRipple.shock), .color(tint)),
                    maxSampleOffset: CGSize(width: 12, height: 12),
                    isEnabled: enabled && (depth > 0.02 || shock != nil))
    }
}

enum StrobeLamp {
    /// The widest smear, in radians: a disc racing 50 cents off blurs its finest band through, as a real one does.
    static let maxSpin = 0.12
}

extension View {
    /// The chromatic strobe disc's lamp (`timbreStrobeLamp`): light blooming through the lit slots (`glow`, 0…1) and,
    /// while the disc turns, its slots smeared along their circles by `spin` radians (the disc's turn in a glance).
    /// Off when `enabled` is false and whenever there is nothing to show (unlit and still), so the disc reads the
    /// same without it (Reduce Motion, Low Power Mode), only flatter.
    func strobeLamp(spin: Double, glow: Double, enabled: Bool) -> some View {
        let smear = min(StrobeLamp.maxSpin, abs(spin))
        return layerEffect(ShaderLibrary.timbreStrobeLamp(.boundingRect, .float(smear), .float(glow)),
                           maxSampleOffset: CGSize(width: 14, height: 14),
                           isEnabled: enabled && (glow > 0.01 || smear > 0.002))
    }
}

/// Heat glow on a reward star (`timbreHeatStar`): it lands white-hot, its points glowing orange and its edge
/// wavering in the heat haze, cools to its own gold and a glint crosses it, then the effect (and its timeline)
/// stops. Nothing before it lands, and nothing under Reduce Motion or in Low Power Mode: the star stays plain gold.
struct StarHeat: ViewModifier {
    /// When the star landed; nil before it has (or for a star not earned).
    let landed: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hot = false

    static let duration = 2.0

    func body(content: Content) -> some View {
        let on = hot && landed != nil && ShaderFX.allowed(reduceMotion: reduceMotion)
        TimelineView(.animation(paused: !on)) { timeline in
            let elapsed = landed.map { timeline.date.timeIntervalSince($0) } ?? Self.duration
            content.layerEffect(ShaderLibrary.timbreHeatStar(.boundingRect, .float(elapsed)),
                                maxSampleOffset: CGSize(width: 3, height: 3),
                                isEnabled: on && elapsed < Self.duration)
        }
        .task(id: landed) {
            guard landed != nil else {
                hot = false
                return
            }
            hot = true
            try? await Task.sleep(for: .seconds(Self.duration))
            guard !Task.isCancelled else { return }
            hot = false
        }
    }
}
