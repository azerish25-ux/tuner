import SwiftUI
import TimbreCore

// MARK: - Chart or player's view

/// How every neck and every chord in the app is drawn: one choice, remembered, flipped from the switch on a chord
/// card (a lesson's chord explanations and chord steps, the Chords tool, the Scales neck) or in Settings › String
/// order. It is the only stored value, so no two pictures can ever disagree.
///
/// - Chart (the default), as songbooks, tab and Yousician print it: a chord is the chord box (nut on top, the lowest
///   string on the left, string 1 on the right, `ChordDiagram`), and a neck lying across the screen (the fretboard
///   strips, the tune check, the Scales neck, the strum stage) has string 1, the thinnest, on top, nut on the left, as
///   tablature writes it. The box is that strip turned upright, so the two always agree.
/// - Player view: the instrument as you see it while you play. Every neck lying across the screen has the thickest
///   string on top (so a down strum falls down the screen), and a chord is the neck in perspective in the play-along
///   runway's look (`PlayerNeck`), its lanes laid as the runway lays them, the lowest string on the left.
///
/// Strings standing upright side by side (the chord pictures, the play-along and paywall runways' lanes) run from the
/// lowest string on the left in both views (`StringOrder.upright`), so flipping never mirrors a chord or a lane.
///
/// `StringOrder` is this same stored value read as the order of the strings on a neck lying down (`.tab` for Chart,
/// `.mirror` for Player view), for the code that only asks which string is on top.
enum ChordPicture: String, CaseIterable, Identifiable {
    case chart
    case player

    /// The UserDefaults key the one choice is stored under (`StringOrder.storageKey` is the same key). Its first read
    /// folds in, once, the separate string order older builds kept (`display.stringOrder`): someone who had put the
    /// thickest string on top, and never picked a chord picture, keeps that as Player view.
    static let storageKey: String = {
        let key = "display.chordPicture"
        let legacy = "display.stringOrder"
        let defaults = UserDefaults.standard
        if let old = defaults.string(forKey: legacy) {
            if old == "mirror", defaults.string(forKey: key) == nil {
                defaults.set(ChordPicture.player.rawValue, forKey: key)
            }
            defaults.removeObject(forKey: legacy)
        }
        return key
    }()

    /// The stored choice, for code outside a view (views read it through `@AppStorage` so they redraw).
    static var current: ChordPicture {
        UserDefaults.standard.string(forKey: storageKey).flatMap(ChordPicture.init(rawValue:)) ?? .chart
    }

    /// The order of the strings on a neck lying across the screen: string 1 on top for the chart, the thickest for
    /// the player's view.
    var stringOrder: StringOrder { self == .chart ? .tab : .mirror }

    var id: String { rawValue }

    /// Its name on the switch.
    var title: LocalizedStringKey {
        switch self {
        case .chart: return "Chart"
        case .player: return "Player view"
        }
    }

    /// Its name for VoiceOver.
    var spoken: LocalizedStringKey {
        switch self {
        case .chart: return "Chord chart"
        case .player: return "Player view"
        }
    }

    /// What it means for the necks lying down, under its name in Settings › String order (the chord boxes go with
    /// the name: a chart, or the player's view).
    var detail: LocalizedStringKey {
        switch self {
        case .chart: return "Like tab: string 1, the thinnest, on top"
        case .player: return "As you look down at it: the thickest on top"
        }
    }
}

/// The switch between the chart and the player's view: a small capsule with both, the chosen one filled in the
/// accent (the fill slides across as it changes). It is Settings › String order itself, so every neck and chord in
/// the app flips with it.
struct ChordPictureToggle: View {
    var accent: Color = Palette.mint
    /// What VoiceOver calls the switch: "Chord view" on a chord card, "Neck view" over the Scales neck.
    var label: LocalizedStringKey = "Chord view"
    @AppStorage(ChordPicture.storageKey) private var picture: ChordPicture = .chart
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChordPicture.allCases) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }

    private func segment(_ option: ChordPicture) -> some View {
        let selected = picture == option
        return Button {
            guard picture != option else { return }
            Haptics.shared.selection()
            withMotion(Motion.settle, reduceMotion: reduceMotion) { picture = option }
        } label: {
            Text(option.title)
                .font(Typeface.label(.caption))
                .lineLimit(1)
                .foregroundStyle(selected ? Palette.onAccent : Palette.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule().fill(accent).matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(option.spoken))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("chord.picture.\(option.rawValue)")
    }
}

/// A chord card's top line: the chord's name on the left, the chart / player's-view switch on the right (under the
/// name at the largest text sizes). VoiceOver hears the name from the picture below, with its shape, so it isn't
/// said twice.
struct ChordCardHeader: View {
    let name: String
    var accent: Color = Palette.mint

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                title
                Spacer(minLength: 8)
                ChordPictureToggle(accent: accent)
            }
            VStack(spacing: 8) {
                title
                ChordPictureToggle(accent: accent)
            }
        }
    }

    private var title: some View {
        Text(name).font(Typeface.display(.title)).foregroundStyle(Palette.ink)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

/// The flip between the two pictures: the chart tips back into the neck's perspective as it leaves, the neck rises
/// out of it; a plain cross-fade with Reduce Motion.
@MainActor
enum ChordFlip {
    static func transition(toPlayer: Bool, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let away = ChordTilt(angle: toPlayer ? -30 : 36, opacity: 0)
        return .modifier(active: away, identity: ChordTilt(angle: 0, opacity: 1))
    }
}

private struct ChordTilt: ViewModifier {
    let angle: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.55)
            .opacity(opacity)
    }
}

/// A chord in the picture the learner chose, for the places that show one without the switch beside it (a quiz's
/// card, the Learn preview, a strum's chord, a progression's strip): the chord chart, or the player's-view neck in
/// the room the chart's box would take at that width, its name over it as over the chart. It flips with the choice.
struct ChordPictureView: View {
    let chord: ChordSpec
    var accent: Color = Palette.mint
    var showName = true
    /// Strings ringing now (lowest string first), lit on either picture.
    var ringing: Set<Int> = []
    /// The fingers land as the picture appears.
    var landing = false
    var edges: StringEdges?
    /// The chart numbers its frets beside the box (the neck always numbers them down its left).
    var fretNumbers = false
    /// How much taller than plain the chart's frets are drawn (1 to 1.5); the neck takes the same height.
    var stretch: CGFloat = 1
    /// A small picture (a strip's chords, the preview's row): the neck draws narrower margins and smaller marks, and
    /// numbers its lanes rather than naming its edges.
    var compact = false
    @AppStorage(ChordPicture.storageKey) private var picture: ChordPicture = .chart
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let player = picture == .player
        ZStack {
            if player {
                neck
                    .transition(ChordFlip.transition(toPlayer: true, reduceMotion: reduceMotion))
            } else {
                ChordDiagram(chord: chord, accent: accent, showName: showName, ringing: ringing, landing: landing, edges: edges,
                             fretNumbers: fretNumbers, stretch: stretch)
                    .transition(ChordFlip.transition(toPlayer: false, reduceMotion: reduceMotion))
            }
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: player)
    }

    /// The chart's box is `count / (5.4 × stretch)` wide for its height: the neck keeps that shape, so a card holds
    /// still whichever picture it shows.
    private var aspect: CGFloat { CGFloat(max(1, chord.frets.count)) / (5.4 * min(1.5, max(1, stretch))) }

    private var neck: some View {
        VStack(spacing: 8) {
            if showName {
                // VoiceOver hears the name from the neck, with its shape.
                Text(chord.name).font(Typeface.display(.title)).foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
            PlayerNeck(chord: chord, accent: accent, ringing: ringing, landsOnAppear: landing, edges: edges, compact: compact)
                .aspectRatio(aspect, contentMode: .fit)
        }
    }
}

// MARK: - Perspective

/// The play-along runway's materials (`HighwayRunway`): rosewood darkening toward the far end, rolled darker at its
/// edges, nickel fret wires and bone for the nut and the binding. In a lesson the strings are plain steel and bronze,
/// lit in the lesson's accent as they ring, as every lesson picture marks them (the runway keeps a colour per string).
enum NeckFinish {
    static let wood = Gradient(colors: [Color(hex: 0x16100D), Color(hex: 0x3B2A1F)])
    static let woodFar = Color(hex: 0x16100D)
    static let roll = Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.4)])
    static let wire = Color(hex: 0xC9CED6)
    static let bone = Color(hex: 0xEDE3CF)
    /// Plain strings, and the wound bass strings.
    static let steel = Color(hex: 0xE2DDD3)
    static let bronze = Color(hex: 0xCDB892)
    /// A capo's padded bar.
    static let capo = Color(hex: 0x2B2E34)
}

/// A neck in perspective, as the runway lays its board: a plane tilted away from you, its strings side by side in
/// lanes converging on a vanishing point far above, the near end biggest. `u` runs along the neck from the nut (0)
/// to the near edge (1), and negative past the nut toward the head. Lane 0 is the left one; which string takes it
/// is the caller's (`PlayerNeck.order`, the runway's `StringOrder`).
struct NeckPerspective {
    let centerX: CGFloat
    /// Screen heights of the nut (u = 0) and the near edge (u = 1).
    let farY: CGFloat
    let nearY: CGFloat
    /// Between neighbouring lanes at the near edge.
    let gap: CGFloat
    let strings: Int
    /// How big the nut end is drawn beside the near end.
    var farScale: CGFloat = 0.68

    /// Where the lanes would meet.
    private var horizonY: CGFloat { (farY - farScale * nearY) / (1 - farScale) }

    /// How big things at `u` are drawn: `farScale` at the nut, 1 at the near edge.
    func scale(_ u: CGFloat) -> CGFloat { 1 / (1 / farScale + (1 - 1 / farScale) * u) }

    func y(_ u: CGFloat) -> CGFloat { horizonY + (nearY - horizonY) * scale(u) }

    /// The `u` drawn at height `y`: the inverse of `y(_:)`.
    func u(atY y: CGFloat) -> CGFloat {
        let s = max(0.05, (y - horizonY) / max(1, nearY - horizonY))
        return (1 / s - 1 / farScale) / (1 - 1 / farScale)
    }

    /// The centre of lane `row` (0 the left) at `u`.
    func x(row: Int, _ u: CGFloat) -> CGFloat {
        centerX + (CGFloat(row) - CGFloat(strings - 1) / 2) * gap * scale(u)
    }

    /// The board's edges, a little over half a lane outside the outer strings.
    func left(_ u: CGFloat) -> CGFloat { x(row: 0, u) - gap * 0.6 * scale(u) }
    func right(_ u: CGFloat) -> CGFloat { x(row: strings - 1, u) + gap * 0.6 * scale(u) }

    /// A point `a` of the way across the board (0 its left edge, 1 its right) at `u`.
    func point(across a: CGFloat, _ u: CGFloat) -> CGPoint {
        CGPoint(x: left(u) + (right(u) - left(u)) * a, y: y(u))
    }
}

// MARK: - The player's view

/// A chord as the player sees it: the neck in perspective, nut at the far end, its strings in the runway's lanes,
/// four frets (more when the shape needs them) spaced as real frets are. Fingertips press in finger order
/// (1, then 2, then 3), each coming down out of the air with its shadow tightening under it, pressing just behind
/// its fret wire with a little squash and a ring across the board. Muted strings fade and take a ×, open strings glow
/// with a ring at the head, and each string shimmers between where it's held (or the nut) and the near end as it
/// starts to ring (`ringing`), so it moves with "Hear it". Every mark is in the lesson's accent. The frets are numbered
/// down the bass side, a held one lit, and every lane is numbered at the near end, the outer two named under it. A
/// shape behind a capo has the capo across the far end in place of the nut.
///
/// It is the Player view's chord (`ChordPicture.player`), its lanes the play-along runway's (`order`,
/// `StringOrder.upright`): the lowest string on the left, as on the chord chart, so flipping between the two never
/// mirrors the chord, and a shape learned here is the shape that comes down the runway. A left-handed player's neck is
/// its mirror image (`HandStyle.mirrorsUpright`), its words still reading as usual.
///
/// With Reduce Motion it is one still frame, every finger in place. VoiceOver reads it as one element: the chord's
/// name, then its shape in words (`ChordWords`).
struct PlayerNeck: View {
    let chord: ChordSpec
    var accent: Color = Palette.mint
    /// Strings ringing now (lowest string first, as `chord.frets`): each lights, and shimmers as it starts to ring.
    var ringing: Set<Int> = []
    /// A demonstration's clock: when the first fingertip presses its string, the next ones `landingStep` apart in
    /// finger order (a lesson's explanation, so each lands as its note sounds); nil leaves it to `landsOnAppear`.
    var landStart: Date?
    var landingStep: Double = 0.45
    /// The fingertips land quickly as the neck appears (unless a demonstration is landing them).
    var landsOnAppear = true
    /// Names the outer lanes under the neck ("Thinnest (1)", "Thickest (6)").
    var edges: StringEdges?
    /// A small card (the Chords tool's shapes): narrower margins, smaller marks, no edge names.
    var compact = false
    /// Drawn as its mirror image (a left-handed instrument); nil follows the player's hold (`CurrentHand`).
    var mirrored: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @CurrentHand private var hand
    /// Fret and string numbers grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1
    /// The quick landing as the neck appears.
    @State private var ownStart: Date?
    /// When each string (lowest first) last started to ring.
    @State private var struck: [Int: Date] = [:]
    /// Something is moving: the timeline runs only then.
    @State private var live = false
    @State private var liveUntil = Date.distantPast

    /// Seconds between fingertips in the quick landing, how long one takes to come down, and how long a string shimmers.
    private static let quickStep = 0.12
    private static let fall = 0.2
    private static let ringSeconds = 1.8
    /// Frets with a pearl dot (12 and 24 have two).
    private static let inlays: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]

    /// Which string takes which lane: upright strings' order (`StringOrder.upright`, the lowest string on the left, as
    /// on the runway and the chart). Fixed rather than read from the setting, so a neck flipping away to the chart
    /// never re-lays its lanes on the way out.
    static let order: StringOrder = StringOrder.upright

    var body: some View {
        let order = Self.order
        let scale = typeScale
        let still = reduceMotion
        let flip = mirrored ?? hand.mirrorsUpright
        VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !live || still)) { timeline in
                let now = live ? timeline.date : Date()
                Canvas { context, size in
                    draw(&context, size: size, now: now, order: order, mirror: CanvasMirror(on: flip, width: size.width), scale: scale, still: still)
                }
            }
            if !compact, let edges, chord.frets.count >= 2 {
                let count = chord.frets.count
                let leftLane = edges.label(order.string(atRow: 0, count: count))
                let rightLane = edges.label(order.string(atRow: count - 1, count: count))
                EdgeNamesRow(leading: flip ? rightLane : leftLane, trailing: flip ? leftLane : rightLane)
            }
        }
        .accessibilityIgnoresInvertColors()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(chord.name) chord"))
        .accessibilityValue(Text(ChordWords.shape(chord)))
        .onAppear { appeared() }
        .onChange(of: landStart) { _, start in landingChanged(start) }
        .onChange(of: ringing) { old, new in rang(old: old, new: new) }
    }

    // MARK: Layout

    /// The lanes' centre and their spacing at the near edge across a canvas `width` wide: the board fills it but for
    /// a margin each side (the fret numbers' column on the left).
    static func laneSpacing(width: CGFloat, strings: Int, compact: Bool) -> (centerX: CGFloat, gap: CGFloat) {
        let side: CGFloat = compact ? 20 : 30
        let room = max(12, width - 2 * side)
        let gap = strings > 1 ? room / (CGFloat(strings - 1) + 1.2) : min(60, room)
        return (width / 2, gap)
    }

    /// Where each string's lane meets the near edge across a neck `width` wide (lowest string first, as `chord.frets`),
    /// so a row drawn under the neck (the chord step's string checks) lines up with it; `mirrored` for a left-handed
    /// player's neck (`HandStyle.mirrorsUpright`).
    static func stringPositions(_ chord: ChordSpec, width: CGFloat, compact: Bool = false, mirrored: Bool = false) -> [CGFloat] {
        let count = chord.frets.count
        let lane = laneSpacing(width: width, strings: count, compact: compact)
        let mirror = CanvasMirror(on: mirrored, width: width)
        return (0..<count).map { i in
            let row = Self.order.row(ofString: count - i, count: count)
            return mirror.x(lane.centerX + (CGFloat(row) - CGFloat(count - 1) / 2) * lane.gap)
        }
    }

    private struct Layout {
        let neck: NeckPerspective
        /// The first fret shown, and how many.
        let base: Int
        let rows: Int
        /// Each fret wire's `u`, the nut's (or the wire before `base`) first.
        let wires: [CGFloat]
        /// The `u` at the top of the canvas (past the nut, toward the head).
        let topU: CGFloat
        /// The height of the open and muted marks over the nut.
        let markY: CGFloat
        /// The height of the lanes' numbers under the near edge; nil when the lanes are too close for them.
        let numbersY: CGFloat?
        /// A fingertip's radius at the near edge.
        let radius: CGFloat

        /// Where a finger presses fret `fret`: just behind its wire, as a player does.
        func fingerU(_ fret: Int) -> CGFloat {
            let k = min(rows, max(1, fret - base + 1))
            return wires[k - 1] + (wires[k] - wires[k - 1]) * 0.62
        }

        /// The middle of row `k` (1 the first fret shown).
        func cellU(_ k: Int) -> CGFloat { (wires[k - 1] + wires[k]) / 2 }
    }

    private func layout(_ size: CGSize) -> Layout {
        let count = max(1, chord.frets.count)
        let lane = Self.laneSpacing(width: size.width, strings: count, compact: compact)
        let numbersRow: CGFloat = lane.gap >= 13 ? (compact ? 15 : 20) : 0
        let farY: CGFloat = compact ? 22 : 34
        let nearY = max(farY + 40, size.height - numbersRow - 2)
        let neck = NeckPerspective(centerX: lane.centerX, farY: farY, nearY: nearY, gap: lane.gap, strings: count)
        // Behind a capo the neck starts at the capo, the first fret shown the first above it.
        let base = chord.drawnCapo > 0 ? chord.drawnCapo + 1 : max(1, chord.baseFret ?? 1)
        let rows = min(6, max(4, (chord.frets.max() ?? 0) - base + 1))
        // Real fret spacing: each fret a twelfth root of two closer than the one before; the board runs a little
        // past the last wire shown.
        func position(_ fret: Int) -> Double { 1 - pow(2, -Double(fret) / 12) }
        let first = position(base - 1)
        let span = max(0.0001, (position(base - 1 + rows) - first) * 1.08)
        let wires = (0...rows).map { CGFloat((position(base - 1 + $0) - first) / span) }
        // Never taller than the first fret's cell allows (its top is the smallest).
        let cell = (neck.y(wires[1]) - neck.y(wires[0])) / neck.scale(wires[0])
        let radius = min(lane.gap * (compact ? 0.46 : 0.42), cell * 0.42)
        return Layout(neck: neck, base: base, rows: rows, wires: wires, topU: neck.u(atY: 0), markY: compact ? 10 : 15,
                      numbersY: numbersRow > 0 ? nearY + numbersRow / 2 + 1 : nil, radius: radius)
    }

    // MARK: Clock

    private struct Clock {
        let start: Date
        let step: Double
    }

    /// How far a fingertip has come down (0 in the air, not drawn; 1 pressing its string) and the seconds since it
    /// pressed (nil when the neck is still), for its squash and the ring it sends out.
    private struct Touch {
        var down: CGFloat = 1
        var since: Double?
    }

    /// One fingertip, or a finger laid across several strings (`from` and `to` its ends' lanes).
    private struct Press {
        let u: CGFloat
        let from: CGFloat
        let to: CGFloat
        let finger: Int?
        let touch: Touch
    }

    private var landingCount: Int { ChordDiagram(chord: chord, landingOrder: .fingers).landingCount }

    /// From the first fingertip's start to the last one's ring fading.
    private func landingLength(_ step: Double) -> Double { Double(max(0, landingCount - 1)) * step + 0.65 }

    /// The landing running at `now`: the demonstration's, else the quick one as the neck appeared; nil once done.
    private func landingClock(at now: Date) -> Clock? {
        if let landStart, now.timeIntervalSince(landStart) < landingLength(landingStep) {
            return Clock(start: landStart, step: landingStep)
        }
        if let ownStart, now.timeIntervalSince(ownStart) < landingLength(Self.quickStep) {
            return Clock(start: ownStart, step: Self.quickStep)
        }
        return nil
    }

    private static func touch(rank: Int, clock: Clock, now: Date) -> Touch {
        let t = now.timeIntervalSince(clock.start) - Double(rank) * clock.step
        if t >= 0 { return Touch(down: 1, since: t) }
        guard t > -fall else { return Touch(down: 0, since: nil) }
        return Touch(down: CGFloat(1 + t / fall), since: nil)
    }

    private func appeared() {
        guard !reduceMotion else { return }
        let now = Date()
        if let landStart, now.timeIntervalSince(landStart) < landingLength(landingStep) {
            keepAlive(until: landStart.addingTimeInterval(landingLength(landingStep)))
        } else if landsOnAppear {
            let start = now.addingTimeInterval(0.12)
            ownStart = start
            keepAlive(until: start.addingTimeInterval(landingLength(Self.quickStep)))
        }
    }

    private func landingChanged(_ start: Date?) {
        guard let start else { return }
        keepAlive(until: start.addingTimeInterval(landingLength(landingStep)))
    }

    /// Strings that just started to ring shimmer.
    private func rang(old: Set<Int>, new: Set<Int>) {
        let added = new.subtracting(old)
        guard !added.isEmpty else { return }
        let now = Date()
        for index in added { struck[index] = now }
        keepAlive(until: now.addingTimeInterval(Self.ringSeconds))
    }

    /// Runs the timeline until `end` (or a later end already asked for), then lets it rest.
    private func keepAlive(until end: Date) {
        guard !reduceMotion else { return }
        let target = max(end, liveUntil)
        liveUntil = target
        live = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0.05, target.timeIntervalSinceNow + 0.05)))
            if liveUntil == target { live = false }
        }
    }

    /// 1 as string `index` starts to ring, dying away over `ringSeconds`; 0 when it isn't ringing.
    private func ringLevel(_ index: Int, now: Date) -> Double {
        guard let at = struck[index] else { return 0 }
        let t = now.timeIntervalSince(at)
        guard t >= 0, t < Self.ringSeconds else { return 0 }
        return exp(-t * 2.4)
    }

    /// The string's sideways swing now (−1…1 of its widest), shimmering as it dies away.
    private func sway(_ index: Int, now: Date) -> CGFloat {
        guard let at = struck[index] else { return 0 }
        let level = ringLevel(index, now: now)
        guard level > 0 else { return 0 }
        let t = now.timeIntervalSince(at)
        return CGFloat(level * sin(t * 2 * .pi * 13 + Double(index) * 1.3))
    }

    // MARK: Drawing

    /// Draws the neck as a right-hander's; `mirror` turns the shapes over and sets the words at the mirrored points.
    private func draw(_ context: inout GraphicsContext, size: CGSize, now: Date, order: StringOrder, mirror: CanvasMirror, scale: CGFloat, still: Bool) {
        // A compact neck still draws in a progression's small "next" box.
        guard !chord.frets.isEmpty, size.width > 40, size.height > (compact ? 56 : 90) else { return }
        let shapes = mirror.shapes(context)
        let l = layout(size)
        let clock = still ? nil : landingClock(at: now)
        // Before the quick landing starts (the first frame), the fingertips are still to come.
        let pending = !still && landsOnAppear && ownStart == nil && landStart == nil
        let elapsed: Double? = pending ? -1 : clock.map { now.timeIntervalSince($0.start) }
        let reveal: CGFloat = elapsed.map { CGFloat(min(1, max(0, $0 / 0.45))) } ?? 1
        let ranks = ChordDiagram(chord: chord, landingOrder: .fingers).landingRanks
        let touches: [Touch] = chord.frets.indices.map { i in
            if pending { return Touch(down: 0, since: nil) }
            guard let clock else { return Touch() }
            return Self.touch(rank: ranks[safe: i] ?? 0, clock: clock, now: now)
        }
        drawBoard(shapes, l)
        drawFrets(shapes, l)
        drawFretNumbers(&context, l, touches: touches, mirror: mirror, scale: scale)
        drawStrings(shapes, l, order: order, now: now, still: still, reveal: reveal)
        drawMarks(&context, shapes: shapes, l, order: order, elapsed: elapsed, reveal: reveal, mirror: mirror)
        drawFingers(&context, shapes: shapes, l, order: order, touches: touches, mirror: mirror)
        drawNumbers(&context, l, order: order, mirror: mirror, scale: scale)
    }

    /// The head past the nut fading into the card, then the board: rosewood with its grain running along the neck,
    /// rolled darker at the edges and shaded at the near end, between bone binding.
    private func drawBoard(_ context: GraphicsContext, _ l: Layout) {
        let neck = l.neck
        let topY = neck.y(l.topU)
        var head = Path()
        head.move(to: CGPoint(x: neck.left(l.topU), y: topY))
        head.addLine(to: CGPoint(x: neck.right(l.topU), y: topY))
        head.addLine(to: CGPoint(x: neck.right(0), y: neck.farY))
        head.addLine(to: CGPoint(x: neck.left(0), y: neck.farY))
        head.closeSubpath()
        context.fill(head, with: .linearGradient(Gradient(colors: [NeckFinish.woodFar.opacity(0), NeckFinish.woodFar]),
                                                 startPoint: CGPoint(x: 0, y: topY), endPoint: CGPoint(x: 0, y: neck.farY)))
        var board = Path()
        board.move(to: CGPoint(x: neck.left(0), y: neck.farY))
        board.addLine(to: CGPoint(x: neck.right(0), y: neck.farY))
        board.addLine(to: CGPoint(x: neck.right(1), y: neck.nearY))
        board.addLine(to: CGPoint(x: neck.left(1), y: neck.nearY))
        board.closeSubpath()
        context.fill(board, with: .linearGradient(NeckFinish.wood, startPoint: CGPoint(x: 0, y: neck.farY), endPoint: CGPoint(x: 0, y: neck.nearY)))
        var grain = context
        grain.clip(to: board)
        for i in 0..<18 {
            let a = CGFloat((Double(i) + 0.15 + 0.7 * CanvasNoise.value(i + 300)) / 18)
            let mid = neck.point(across: a, 0.45)
            var line = Path()
            line.move(to: neck.point(across: a, 0))
            line.addQuadCurve(to: neck.point(across: a, 1), control: CGPoint(x: mid.x + CGFloat(CanvasNoise.value(i + 340) - 0.5) * 8, y: mid.y))
            let tone: Color = i % 3 == 0 ? Color.white.opacity(0.03) : Color.black.opacity(0.18 + 0.15 * CanvasNoise.value(i + 380))
            grain.stroke(line, with: .color(tone), lineWidth: 0.7 + 1.4 * CGFloat(CanvasNoise.value(i + 420)))
        }
        grain.fill(board, with: .linearGradient(NeckFinish.roll, startPoint: CGPoint(x: neck.left(1), y: 0), endPoint: CGPoint(x: neck.right(1), y: 0)))
        grain.fill(board, with: .linearGradient(Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.32)]),
                                                startPoint: CGPoint(x: 0, y: neck.y(0.88)), endPoint: CGPoint(x: 0, y: neck.nearY)))
        var binding = Path()
        binding.move(to: CGPoint(x: neck.left(0), y: neck.farY))
        binding.addLine(to: CGPoint(x: neck.left(1), y: neck.nearY))
        binding.move(to: CGPoint(x: neck.right(0), y: neck.farY))
        binding.addLine(to: CGPoint(x: neck.right(1), y: neck.nearY))
        context.stroke(binding, with: .linearGradient(Gradient(colors: [NeckFinish.bone.opacity(0.12), NeckFinish.bone.opacity(0.4)]),
                                                      startPoint: CGPoint(x: 0, y: neck.farY), endPoint: CGPoint(x: 0, y: neck.nearY)),
                       lineWidth: compact ? 1 : 1.6)
    }

    /// Pearl dots on their frets, the bone nut (a capo's bar behind a capo, or a wire up the neck) and the fret wires,
    /// each on its shadow with a glint along its top.
    private func drawFrets(_ context: GraphicsContext, _ l: Layout) {
        let neck = l.neck
        for k in 1...l.rows {
            let fret = l.base + k - 1
            let double = fret == 12 || fret == 24
            guard double || Self.inlays.contains(fret) else { continue }
            let u = l.cellU(k)
            let s = neck.scale(u)
            let rx = (compact ? 4 : 6.5) * s
            let ry = rx * 0.72
            let offsets: [CGFloat] = double ? [-neck.gap * s, neck.gap * s] : [0]
            for dx in offsets {
                let c = CGPoint(x: neck.centerX + dx, y: neck.y(u))
                let pearl = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
                let shine = Gradient(colors: [Color.white.opacity(0.42), Color(hex: 0xB9D3DC).opacity(0.16)])
                context.fill(pearl, with: .radialGradient(shine, center: CGPoint(x: c.x - rx * 0.3, y: c.y - ry * 0.3), startRadius: 0, endRadius: rx))
            }
        }
        for k in 0...l.rows {
            let u = l.wires[k]
            let s = neck.scale(u)
            let y = neck.y(u)
            if k == 0 && chord.drawnCapo > 0 {
                drawCapo(context, l, y: y, scale: s)
                continue
            }
            if k == 0 && l.base == 1 {
                let h = (compact ? 4 : 6) * s
                let nut = CGRect(x: neck.left(0) - 1, y: y - h, width: neck.right(0) - neck.left(0) + 2, height: h + 1)
                let bone = Gradient(colors: [NeckFinish.bone, NeckFinish.bone.mix(with: .black, by: 0.28)])
                context.fill(Path(roundedRect: nut, cornerRadius: h * 0.3),
                             with: .linearGradient(bone, startPoint: CGPoint(x: 0, y: nut.minY), endPoint: CGPoint(x: 0, y: nut.maxY)))
                continue
            }
            var wire = Path()
            wire.move(to: CGPoint(x: neck.left(u), y: y))
            wire.addLine(to: CGPoint(x: neck.right(u), y: y))
            let w = (compact ? 1.6 : 2.6) * s
            context.stroke(wire.offsetBy(dx: 0, dy: w * 0.9), with: .color(.black.opacity(0.45)), lineWidth: w)
            context.stroke(wire, with: .color(NeckFinish.wire.opacity(0.7)), lineWidth: w)
            context.stroke(wire.offsetBy(dx: 0, dy: -w * 0.3), with: .color(.white.opacity(0.35)), lineWidth: max(0.5, w * 0.35))
        }
    }

    /// The capo where the nut would be: a padded bar clamped across every string a little past the board's edges, on
    /// its shadow, its screw toward the treble side.
    private func drawCapo(_ context: GraphicsContext, _ l: Layout, y: CGFloat, scale s: CGFloat) {
        let neck = l.neck
        let h = (compact ? 6 : 9) * s
        let reach = neck.gap * 0.25 * s
        let bar = CGRect(x: neck.left(0) - reach, y: y - h, width: neck.right(0) - neck.left(0) + reach * 2, height: h + 1)
        context.fill(Path(roundedRect: bar.offsetBy(dx: 0, dy: h * 0.35), cornerRadius: h * 0.45), with: .color(.black.opacity(0.4)))
        let body = Gradient(colors: [NeckFinish.capo.mix(with: .white, by: 0.18), NeckFinish.capo])
        context.fill(Path(roundedRect: bar, cornerRadius: h * 0.45),
                     with: .linearGradient(body, startPoint: CGPoint(x: 0, y: bar.minY), endPoint: CGPoint(x: 0, y: bar.maxY)))
        let screw = h * 0.5
        context.fill(Path(ellipseIn: CGRect(x: bar.maxX - screw * 2.2, y: bar.midY - screw / 2, width: screw, height: screw)),
                     with: .color(NeckFinish.wire.opacity(0.55)))
    }

    /// Each row's fret down the bass side of the board, beside its middle; a fret with a pressed fingertip on it lit.
    private func drawFretNumbers(_ context: inout GraphicsContext, _ l: Layout, touches: [Touch], mirror: CanvasMirror, scale: CGFloat) {
        let neck = l.neck
        let frets = chord.frets
        for k in 1...l.rows {
            let fret = l.base + k - 1
            let held = frets.indices.contains { frets[$0] == fret && chord.drawnFingered($0) && (touches[safe: $0]?.down ?? 1) >= 1 }
            let u = l.cellU(k)
            let label = Text(verbatim: "\(fret)")
                .font(DiagramType.font(compact ? 11 : 12, weight: held ? .heavy : .semibold, scale: scale))
                .foregroundStyle(held ? accent : Palette.inkFaint)
            context.draw(label, at: mirror.point(CGPoint(x: neck.left(u) - 6, y: neck.y(u))), anchor: mirror.anchor(.trailing))
        }
    }

    /// The strings in their lanes, from the head to the near edge: steel, or bronze on the wound bass strings, thicker
    /// toward the bass, with a glow in the lesson's accent under it while it rings. A muted string fades; an open one
    /// glows its whole length; a ringing one brightens and shimmers between where it's held (the fingertip, or the nut
    /// or capo) and the near end.
    private func drawStrings(_ context: GraphicsContext, _ l: Layout, order: StringOrder, now: Date, still: Bool, reveal: CGFloat) {
        let count = chord.frets.count
        let neck = l.neck
        let topY = neck.y(l.topU)
        // The strings fade in over the head, reaching full strength at the nut.
        let fade = Double((neck.farY - topY) / max(1, neck.nearY - topY))
        var light = context
        light.blendMode = .plusLighter
        for i in 0..<count {
            let number = count - i
            let row = order.row(ofString: number, count: count)
            let fret = chord.frets[i]
            let muted = fret < 0
            let open = fret >= 0 && !chord.drawnFingered(i)
            let lit = ringing.contains(i)
            let level = still ? 0 : ringLevel(i, now: now)
            let presence = muted ? 1 - 0.78 * Double(reveal) : 1
            var glow = 0.3 * level
            if open { glow += 0.12 * Double(reveal) }
            if lit { glow += 0.26 }
            var half: CGFloat = compact ? 3 : 5
            if open { half += 2 }
            if lit { half += 4 }
            half += CGFloat(level) * 4
            if glow > 0.01 {
                let lane = lanePath(neck, row: row, from: l.topU, half: half)
                light.fill(lane, with: .linearGradient(Gradient(colors: [accent.opacity(0), accent.opacity(glow * presence)]),
                                                       startPoint: CGPoint(x: 0, y: neck.farY), endPoint: CGPoint(x: 0, y: neck.nearY)))
            }
            let gauge: CGFloat = count > 1 ? CGFloat(number - 1) / CGFloat(count - 1) : 0.5
            let wound = count >= 4 && gauge > 0.45
            let thinnest: CGFloat = compact ? 0.8 : 1.1
            let extra: CGFloat = compact ? 1.3 : 2.1
            let width = (thinnest + gauge * extra) * neck.scale(0.6)
            let start: CGFloat = chord.drawnFingered(i) ? l.fingerU(fret) : 0
            let reach: CGFloat = compact ? 2.2 : 3.6
            let swing: CGFloat = (still || muted) ? 0 : sway(i, now: now) * reach
            let path = stringPath(neck, row: row, top: l.topU, start: start, swing: swing)
            let from = CGPoint(x: 0, y: topY), to = CGPoint(x: 0, y: neck.nearY)
            let bare = wound ? NeckFinish.bronze : NeckFinish.steel
            let metal = (lit || level > 0.3) ? bare.mix(with: accent, by: 0.45) : bare
            let line = StrokeStyle(lineWidth: width, lineCap: .round)
            context.stroke(path.offsetBy(dx: 1.2, dy: 1.4), with: .linearGradient(Self.fading(.black, 0.4 * presence, at: fade), startPoint: from, endPoint: to),
                           style: line)
            if level > 0.02 {
                light.stroke(path, with: .linearGradient(Self.fading(accent, 0.5 * level, at: fade), startPoint: from, endPoint: to),
                             style: StrokeStyle(lineWidth: width + 5, lineCap: .round))
            }
            context.stroke(path, with: .linearGradient(Self.fading(metal, 0.9 * presence, at: fade), startPoint: from, endPoint: to), style: line)
            if wound {
                // The winding on the wound strings.
                context.stroke(path, with: .linearGradient(Self.fading(.black, 0.22 * presence, at: fade), startPoint: from, endPoint: to),
                               style: StrokeStyle(lineWidth: width, dash: [1, 1.5]))
            }
            context.stroke(path.offsetBy(dx: -width * 0.25, dy: 0), with: .linearGradient(Self.fading(.white, 0.25 * presence, at: fade), startPoint: from, endPoint: to),
                           style: StrokeStyle(lineWidth: max(0.5, width * 0.3), lineCap: .round))
        }
    }

    /// Clear at the top of the canvas, `alpha` from `at` (the nut, as a share of the way to the near edge) on.
    private static func fading(_ color: Color, _ alpha: Double, at location: Double) -> Gradient {
        let nut = min(0.99, max(0.01, location))
        return Gradient(stops: [
            Gradient.Stop(color: color.opacity(0), location: 0),
            Gradient.Stop(color: color.opacity(alpha), location: nut),
            Gradient.Stop(color: color.opacity(alpha), location: 1)
        ])
    }

    /// A lane's strip from `top` to the near edge, `half` either side of its centre there.
    private func lanePath(_ neck: NeckPerspective, row: Int, from top: CGFloat, half: CGFloat) -> Path {
        let far = half * neck.scale(top)
        var path = Path()
        path.move(to: CGPoint(x: neck.x(row: row, top) - far, y: neck.y(top)))
        path.addLine(to: CGPoint(x: neck.x(row: row, top) + far, y: neck.y(top)))
        path.addLine(to: CGPoint(x: neck.x(row: row, 1) + half, y: neck.nearY))
        path.addLine(to: CGPoint(x: neck.x(row: row, 1) - half, y: neck.nearY))
        path.closeSubpath()
        return path
    }

    /// A string from `top` to the near edge, straight to `start` (where it's held) and from there bowing sideways by
    /// `swing` at its middle, a standing wave, as it rings.
    private func stringPath(_ neck: NeckPerspective, row: Int, top: CGFloat, start: CGFloat, swing: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: neck.x(row: row, top), y: neck.y(top)))
        path.addLine(to: CGPoint(x: neck.x(row: row, start), y: neck.y(start)))
        let segments = abs(swing) > 0.05 ? 24 : 1
        for k in 1...segments {
            let v = CGFloat(k) / CGFloat(segments)
            let u = start + (1 - start) * v
            let bow = swing * sin(.pi * v) * neck.scale(u)
            path.addLine(to: CGPoint(x: neck.x(row: row, u) + bow, y: neck.y(u)))
        }
        return path
    }

    /// Over the nut (or the capo): a × popping in on each muted string, a ring on each open one with its glow
    /// (brighter while it rings).
    private func drawMarks(_ context: inout GraphicsContext, shapes: GraphicsContext, _ l: Layout, order: StringOrder, elapsed: Double?,
                           reveal: CGFloat, mirror: CanvasMirror) {
        let count = chord.frets.count
        let neck = l.neck
        let u = neck.u(atY: l.markY)
        let pop: CGFloat = elapsed.map { CGFloat(LessonSpring.value($0 - 0.05)) } ?? 1
        let r: CGFloat = compact ? 4 : 7
        var light = shapes
        light.blendMode = .plusLighter
        for i in 0..<count where !chord.drawnFingered(i) {
            let number = count - i
            let center = CGPoint(x: neck.x(row: order.row(ofString: number, count: count), u), y: l.markY)
            if chord.frets[i] < 0 {
                guard pop > 0.02 else { continue }
                // On a dark disc, so the string running up to the head doesn't cut through it.
                shapes.fill(circle(center, (r + 2.5) * min(1, pop)), with: .color(Palette.stageRaised.opacity(0.9)))
                var mark = context
                mark.opacity = Double(min(1, pop))
                let at = mirror.point(center)
                mark.translateBy(x: at.x, y: at.y)
                mark.scaleBy(x: pop, y: pop)
                mark.draw(Text(verbatim: "×").font(.system(size: compact ? 11 : 16, weight: .bold)).foregroundStyle(Palette.inkSoft), at: .zero)
            } else {
                let lit = ringing.contains(i)
                let halo = r * (lit ? 3.4 : 2.6)
                let strength = (lit ? 0.55 : 0.32) * Double(reveal)
                shapes.fill(circle(center, r + 2), with: .color(Palette.stageRaised.opacity(0.9)))
                light.fill(circle(center, halo), with: .radialGradient(Gradient(colors: [accent.opacity(strength), accent.opacity(0)]),
                                                                     center: center, startRadius: 0, endRadius: halo))
                shapes.stroke(circle(center, r), with: .color(lit ? accent.mix(with: .white, by: 0.35) : accent), lineWidth: compact ? 1.6 : 2.2)
            }
        }
    }

    /// The fingertips (a finger laid across several strings as one pad), far ones first so nearer ones lie over them.
    private func drawFingers(_ context: inout GraphicsContext, shapes: GraphicsContext, _ l: Layout, order: StringOrder, touches: [Touch],
                             mirror: CanvasMirror) {
        let count = chord.frets.count
        let neck = l.neck
        let frets = chord.frets
        let barres = ChordDiagram(chord: chord).barres
        var presses: [Press] = []
        for barre in barres {
            let u = l.fingerU(barre.fret)
            let a = neck.x(row: order.row(ofString: count - barre.first, count: count), u)
            let b = neck.x(row: order.row(ofString: count - barre.last, count: count), u)
            presses.append(Press(u: u, from: min(a, b), to: max(a, b), finger: barre.finger, touch: touches[safe: barre.first] ?? Touch()))
        }
        for i in frets.indices where chord.drawnFingered(i) {
            let covered = barres.contains { $0.fret == frets[i] && $0.first <= i && i <= $0.last }
            guard !covered else { continue }
            let u = l.fingerU(frets[i])
            let x = neck.x(row: order.row(ofString: count - i, count: count), u)
            presses.append(Press(u: u, from: x, to: x, finger: chord.fingers?[safe: i], touch: touches[safe: i] ?? Touch()))
        }
        for press in presses.sorted(by: { $0.u < $1.u }) {
            drawPress(&context, shapes: shapes, press, l, mirror: mirror)
        }
    }

    /// One fingertip: coming down it is bigger and higher, its shadow wide and soft on the wood; pressing, the shadow
    /// tightens under it, it squashes a touch and a ring runs out across the board. A soft pad in the accent, shaded
    /// from its top to where it meets the string, with its finger number. A finger laid across several strings ends one
    /// fingertip's radius past the outer strings it holds.
    private func drawPress(_ context: inout GraphicsContext, shapes: GraphicsContext, _ press: Press, _ l: Layout, mirror: CanvasMirror) {
        let down = min(1, max(0, press.touch.down))
        guard down > 0.01 else { return }
        let neck = l.neck
        let s = neck.scale(press.u)
        let r = l.radius * s
        let air = 1 - down * down
        let alpha = Double(min(1, down * 2.5))
        var grow: CGFloat = 1 + 0.45 * air
        if let since = press.touch.since, since < 0.5 {
            grow *= 1 - CGFloat(0.09 * exp(-since * 9) * cos(since * 32))
        }
        let contact = CGPoint(x: (press.from + press.to) / 2, y: neck.y(press.u))
        let reach = (press.to - press.from) / 2
        drawPressShadow(shapes, at: contact, reach: reach, radius: r, air: air, scale: s, alpha: alpha)
        if let since = press.touch.since, since < 0.45 {
            drawPressRing(shapes, at: contact, reach: reach, radius: r, since: since)
        }
        let center = CGPoint(x: contact.x, y: contact.y - 18 * s * air)
        // A single fingertip swells and squashes; a barre keeps its ends where the strings are.
        let rx = reach > 0.5 ? r : r * grow
        let ry = r * grow * 0.9
        let tip = CGRect(x: center.x - reach - rx, y: center.y - ry, width: (reach + rx) * 2, height: ry * 2)
        let pad = Path(roundedRect: tip, cornerRadius: min(rx, ry))
        let face = Gradient(colors: [accent.mix(with: .white, by: 0.14).opacity(alpha), accent.opacity(alpha), accent.mix(with: .black, by: 0.2).opacity(alpha)])
        shapes.fill(pad, with: .linearGradient(face, startPoint: CGPoint(x: tip.midX, y: tip.minY), endPoint: CGPoint(x: tip.midX, y: tip.maxY)))
        if down > 0.6, let finger = press.finger, finger > 0 {
            let label = Text(verbatim: "\(finger)").font(.system(size: max(8, r * 1.1), weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.onAccent.opacity(alpha))
            context.draw(label, at: mirror.point(CGPoint(x: center.x, y: center.y + ry * 0.05)))
        }
    }

    /// The fingertip's shadow on the wood, lit from the far end: wide, faint and offset while the finger is in the
    /// air (`air` 1), small and dark right under it as it presses (`air` 0).
    private func drawPressShadow(_ context: GraphicsContext, at contact: CGPoint, reach: CGFloat, radius r: CGFloat, air: CGFloat,
                                 scale s: CGFloat, alpha: Double) {
        let spread = 1 + 0.6 * air
        let w = (reach + r * spread) * 2
        let h = r * 1.5 * spread
        let rect = CGRect(x: contact.x - w / 2 + (1.5 + 7 * air) * s, y: contact.y - h / 2 + (3.5 + 12 * air) * s, width: w, height: h)
        let shade = Double(0.55 - 0.35 * air) * alpha
        let blur = 2 + 8 * air
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: blur))
            layer.fill(Path(roundedRect: rect, cornerRadius: h / 2), with: .color(.black.opacity(shade)))
        }
    }

    /// The ring a press sends out, lying flat on the tilted board.
    private func drawPressRing(_ context: GraphicsContext, at contact: CGPoint, reach: CGFloat, radius r: CGFloat, since: Double) {
        let q = CGFloat(min(1, since / 0.45))
        let eased = 1 - (1 - q) * (1 - q)
        let spread = r * (1.1 + 1.8 * eased)
        let rect = CGRect(x: contact.x - reach - spread, y: contact.y - spread * 0.5, width: (reach + spread) * 2, height: spread)
        context.stroke(Path(roundedRect: rect, cornerRadius: spread * 0.5), with: .color(accent.opacity(0.6 * Double(1 - q))), lineWidth: 0.6 + 2 * (1 - q))
    }

    /// Each lane's string number under the near edge, the accent while it rings, faint when muted.
    private func drawNumbers(_ context: inout GraphicsContext, _ l: Layout, order: StringOrder, mirror: CanvasMirror, scale: CGFloat) {
        guard let y = l.numbersY else { return }
        let count = chord.frets.count
        for i in 0..<count {
            let number = count - i
            let x = l.neck.x(row: order.row(ofString: number, count: count), 1)
            var tone = Palette.inkSoft
            if chord.frets[i] < 0 { tone = Palette.inkFaint.opacity(0.6) }
            if ringing.contains(i) { tone = accent }
            let label = Text(verbatim: "\(number)").font(DiagramType.font(11, scale: scale)).foregroundStyle(tone)
            context.draw(label, at: mirror.point(CGPoint(x: x, y: y)))
        }
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
