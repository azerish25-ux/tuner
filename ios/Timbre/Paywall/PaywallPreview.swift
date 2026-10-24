import SwiftUI
import TimbreCore

/// The paywall's hero, one scene across the full width: the person's own instrument under a spotlight, its strings
/// running on toward you as the lanes of a play-along runway, in the lesson highway's string colours and order
/// (Settings › String order). A light runs down a string, a gem leaves the bridge on that string's lane and glides
/// to the hit line, where its target flashes. Under the line, inside the runway, the combo builds from the moment
/// the paywall opens, counted as the play-along counts it (×2 from 4 notes, ×3 from 8, ×4 from 16), and holds at ×4.
/// The Timbre Pro pill stands on the stage floor below. Everything stays inside the runway's width, clear of the
/// close button. One Canvas on the display clock; with Reduce Motion it holds a single frame mid-song.
struct PaywallPreview: View {
    let figure: PaywallFigure
    let accent: Color
    /// The instrument's strings (pairs count once): one lane each.
    let lanes: Int
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The lanes follow the diagrams' and the lesson highway's string order.
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    /// The pill's measured size: the combo and the hit line stand above it.
    @State private var pill = CGSize(width: 128, height: 26)
    /// When the scene appeared: the combo counts from here.
    @State private var start = Date()

    var body: some View {
        ZStack(alignment: .bottom) {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
                let elapsed = reduceMotion ? PaywallScene.still : max(0, timeline.date.timeIntervalSince(start))
                Canvas { context, size in
                    PaywallScene(figure: figure, lanes: max(1, lanes), order: stringOrder, accent: accent, elapsed: elapsed,
                                 calm: reduceMotion, pill: pill).draw(&context, size: size)
                } symbols: {
                    if let glyph = figure.glyph {
                        CourseEmblemTile(glyph: glyph, accent: accent, size: PaywallScene.emblemSide)
                            .tag(PaywallScene.emblemTag)
                    }
                }
            }
            .accessibilityHidden(true)
            PaywallProPill()
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { size in pill = size }
                .padding(.bottom, 2)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

/// "TIMBRE PRO" in gold: on the hero's stage floor, or on its own row above the headline.
struct PaywallProPill: View {
    var body: some View {
        Text("TIMBRE PRO").font(Typeface.label(12)).tracking(2.2).foregroundStyle(Color(hex: 0x1B1206))
            .lineLimit(1)
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Capsule().fill(Palette.proGold))
            .shadow(color: Color(hex: 0xE39A3B).opacity(0.35), radius: 10, y: 3)
    }
}

// MARK: - The instrument

/// The hero's instrument as the app pictures it (its studio render, else its photograph), with where its strings
/// run on the picture. With two or more strings standing roughly upright it is shown close up: turned so the
/// strings stand straight, its body filling the stage and the lanes leaving from its bridge. Anything else (winds,
/// keys, zithers lying flat, a course emblem) stands whole over the far end of the lanes.
struct PaywallFigure {
    enum Art {
        case picture(String)
        case emblem(CourseGlyph)
    }

    /// A string on the picture, nut to saddle, in the square the picture is fitted into (0…1); `number` 1 is the thinnest.
    struct Wire {
        let number: Int
        let nut: CGPoint
        let saddle: CGPoint
    }

    let art: Art
    let closeUp: Bool
    /// Where the lanes leave the picture, in its square: the saddles' middle, or the foot of a whole picture.
    let bridge: CGPoint
    /// Degrees to turn the picture about `bridge` so its strings stand upright.
    let turn: Double
    /// Nut to saddle, in squares.
    let reach: CGFloat
    let wires: [Wire]

    var glyph: CourseGlyph? {
        if case .emblem(let glyph) = art { return glyph }
        return nil
    }

    /// The highest string number on the picture.
    var topString: Int { wires.map(\.number).max() ?? 0 }

    /// The picture the app shows for this photograph (its studio render when it has one) and its string points.
    @MainActor static func instrument(asset: String) -> PaywallFigure {
        if let model = ModelLibrary.modelID(forPhoto: asset), ModelLibrary.hasCard(model) {
            return make(image: ModelLibrary.cardImageName(model), card: ModelLibrary.rig(model).flatMap(StageCard.init(rig:)))
        }
        return make(image: asset, card: ModelLibrary.photoCard(asset))
    }

    /// A course emblem (singing, theory and the like), standing whole.
    static func emblem(_ glyph: CourseGlyph) -> PaywallFigure {
        // The tile takes two thirds of its square, so its foot is at 0.83.
        PaywallFigure(art: .emblem(glyph), closeUp: false, bridge: CGPoint(x: 0.5, y: 0.83), turn: 0, reach: 0, wires: [])
    }

    private static func make(image: String, card: StageCard?) -> PaywallFigure {
        let whole = PaywallFigure(art: .picture(image), closeUp: false, bridge: CGPoint(x: 0.5, y: 0.86), turn: 0, reach: 0, wires: [])
        guard let card else { return whole }
        var wires: [Wire] = []
        for anchor in card.anchors {
            guard let number = stringNumber(anchor), let nut = card.point(anchor + ".nut"), let saddle = card.point(anchor + ".saddle") else { continue }
            wires.append(Wire(number: number, nut: nut, saddle: saddle))
        }
        guard wires.count >= 2 else { return whole }
        let count = CGFloat(wires.count)
        let saddle = CGPoint(x: wires.map(\.saddle.x).reduce(0, +) / count, y: wires.map(\.saddle.y).reduce(0, +) / count)
        let nut = CGPoint(x: wires.map(\.nut.x).reduce(0, +) / count, y: wires.map(\.nut.y).reduce(0, +) / count)
        let dx = nut.x - saddle.x, up = saddle.y - nut.y
        let reach = (dx * dx + up * up).squareRoot()
        guard reach > 0.3 else { return whole }
        // How far the neck leans clockwise from upright, and how wide the saddles spread across the strings.
        let lean = Double(atan2(dx, up)) * 180 / .pi
        let across = CGPoint(x: -up / reach, y: -dx / reach)
        let offsets = wires.map { ($0.saddle.x - saddle.x) * across.x + ($0.saddle.y - saddle.y) * across.y }
        let spread = (offsets.max() ?? 0) - (offsets.min() ?? 0)
        // Zithers lying flat, harps and kalimbas spread their strings too wide or too low to stand on a runway.
        guard abs(lean) <= 45, spread <= reach * 0.35 else { return whole }
        return PaywallFigure(art: .picture(image), closeUp: true, bridge: saddle, turn: -lean, reach: reach, wires: wires)
    }

    /// "s3" → 3, "c4a" (one string of a pair) → 4, "bridge_12" → 12; nil for points that are not numbered strings.
    private static func stringNumber(_ anchor: String) -> Int? {
        var name = Substring(anchor)
        if let last = name.last, last.isLetter, name.dropLast().last?.isNumber == true { name = name.dropLast() }
        return Int(String(name.reversed().prefix(while: \.isNumber).reversed()))
    }
}

// MARK: - The scene

/// The scene at one moment. `d` is how far a note still has to travel, in lookaheads: 1 at the bridge, 0 on the
/// hit line. Every note is hit: a demo plays clean.
private struct PaywallScene {
    let figure: PaywallFigure
    let lanes: Int
    let order: StringOrder
    let accent: Color
    /// Seconds since the scene appeared.
    let elapsed: Double
    let calm: Bool
    /// The pill at the bottom centre: the combo and the hit line stand above it.
    let pill: CGSize

    struct Note {
        let beat: Double
        /// Across the strings: 0 the lowest, 1 the highest (string 1).
        let place: Double
        let length: Double
    }

    static let secondsPerBeat = 0.5
    static let beatsPerLoop = 16.0
    /// Seconds a gem takes from the bridge to the hit line.
    static let lookahead = 2.6
    /// Seconds the light takes down the string before its gem leaves the bridge.
    static let pluck = 0.5
    static let burst = 0.55
    /// The song's clock when the scene appears: a few gems are already on their way, none counted yet.
    static let lead = 1.4
    /// Reduce Motion's frame, in seconds after appearing: ×3, a burst on the line, a gem about to land and a light
    /// halfway down two strings.
    static let still = 5.8
    /// The emblem symbol, drawn at this size and scaled to the stage.
    static let emblemTag = 1
    static let emblemSide: CGFloat = 160

    /// A little riff: single notes, two chords (beats 4 and 12) and a held note.
    static let tune: [Note] = [
        Note(beat: 0, place: 0, length: 1), Note(beat: 1, place: 0.4, length: 0.5), Note(beat: 1.5, place: 0.6, length: 0.5),
        Note(beat: 2, place: 1, length: 1), Note(beat: 3, place: 0.6, length: 1),
        Note(beat: 4, place: 0.2, length: 1.5), Note(beat: 4, place: 0.8, length: 1.5),
        Note(beat: 6, place: 0.4, length: 0.5), Note(beat: 6.5, place: 0.6, length: 0.5), Note(beat: 7, place: 1, length: 0.5),
        Note(beat: 7.5, place: 0.8, length: 0.5), Note(beat: 8, place: 0, length: 2),
        Note(beat: 10, place: 0.4, length: 1), Note(beat: 11, place: 0.8, length: 1),
        Note(beat: 12, place: 0.2, length: 1.5), Note(beat: 12, place: 0.6, length: 1.5),
        Note(beat: 14, place: 1, length: 0.5), Note(beat: 14.5, place: 0.6, length: 0.5), Note(beat: 15, place: 0.4, length: 1),
    ]

    static var loop: Double { beatsPerLoop * secondsPerBeat }
    static let floorShade = Color(hex: 0x1C1F26)
    static let hitLine = Color(hex: 0xFFF4DE)

    private var songTime: Double { elapsed + Self.lead }

    /// The string a note plays.
    private func string(_ note: Note) -> Int { lanes - Int((note.place * Double(lanes - 1)).rounded()) }
    /// A string's lane, counted from the left, in the player's string order.
    private func lane(_ string: Int) -> Int { order.row(ofString: string, count: lanes) }
    private func color(_ string: Int) -> Color { HighwayRunway.color(string: string, of: lanes) }

    /// The lane string a string on the picture belongs to (a 21-string kora shares out seven lanes).
    private func laneString(ofWire number: Int) -> Int {
        let top = figure.topString
        guard top > 1, top != lanes else { return min(lanes, max(1, number)) }
        return Int((Double(number - 1) / Double(top - 1) * Double(lanes - 1)).rounded()) + 1
    }

    // MARK: Layout

    /// The runway in perspective, its far end at the instrument's bridge. Depth runs 1 at the bridge to 0 on the
    /// hit line (negative past it); lanes are straight lines from the bridge.
    struct Stage {
        let size: CGSize
        let hitY: CGFloat
        let comboY: CGFloat
        let bridge: CGPoint
        /// Width on the hit line, and where the lanes meet at the bridge.
        let width: CGFloat
        let far: CGFloat
        let lanes: Int
        /// A target ring's radius.
        let target: CGFloat
        /// The side of the square the picture is fitted into.
        let art: CGFloat

        var span: CGFloat { max(1, hitY - bridge.y) }
        var gap: CGFloat { width / CGFloat(max(1, lanes)) }
        var shrink: CGFloat { 1 - far / max(1, width) }
        /// Notes speed up as they come closer.
        func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + 0.55) * 1.55) }
        func y(_ depth: CGFloat) -> CGFloat { hitY - span * depth }
        func scale(_ depth: CGFloat) -> CGFloat { 1 - shrink * depth }
        func x(lane: Int, _ depth: CGFloat) -> CGFloat {
            bridge.x + (CGFloat(lane) - CGFloat(lanes - 1) / 2) * gap * scale(depth)
        }
        /// The runway's left (-1) or right (1) edge.
        func edge(_ side: CGFloat, _ depth: CGFloat) -> CGFloat { bridge.x + side * width / 2 * scale(depth) }
    }

    /// The pill at the bottom, the combo over it, the hit line over that; the bridge part way up, so the
    /// instrument above it and the runway below it share the height. The runway keeps 48 points from each side,
    /// so nothing reaches under the close button.
    private func stage(_ size: CGSize) -> Stage {
        let width = max(120, min(280, size.width - 96))
        let target = min(8, max(5, width / CGFloat(lanes) * 0.24))
        let comboHeight: CGFloat = 13
        let comboY = size.height - pill.height - 2 - 3 - comboHeight / 2
        let hitY = max(36, comboY - comboHeight / 2 - 3 - target)
        let bridgeY: CGFloat
        let art: CGFloat
        if figure.closeUp {
            // Taller stages give the instrument a little more of the height.
            let grow = max(0, min(1, (size.height - 110) / 100))
            bridgeY = hitY * (0.4 + 0.05 * grow)
            // About two fifths of the strings show above the bridge: the body and the foot of the neck.
            let wanted = (bridgeY + 6) / (0.4 * max(0.2, figure.reach))
            art = min(330, max(size.height * 0.9, min(wanted, size.height * 2.6)))
        } else {
            bridgeY = hitY * 0.55
            art = bridgeY / max(0.5, figure.bridge.y)
        }
        return Stage(size: size, hitY: hitY, comboY: comboY, bridge: CGPoint(x: size.width / 2, y: bridgeY),
                     width: width, far: 3, lanes: lanes, target: target, art: art)
    }

    // MARK: Notes

    private struct Gem { let string: Int; let d: Double }
    private struct Burst { let string: Int; let age: Double }
    private struct Tail { let string: Int; let from: Double; let to: Double }
    /// A light running down a string to the bridge: 0 → 1 on its way, past 1 while the string still glows.
    private struct Pluck { let string: Int; let progress: Double }
    private struct InView {
        var gems: [Gem] = []
        var bursts: [Burst] = []
        var tails: [Tail] = []
        var plucks: [Pluck] = []
    }

    /// Notes from the loop before to the loop after: lighting their string, on their way, bursting, or holding a tail.
    private func notesInView() -> InView {
        let t = songTime
        let loop = Self.loop
        let current = Int((t / loop).rounded(.down))
        var view = InView()
        for index in (current - 1)...(current + 1) {
            for note in Self.tune {
                let at = Double(index) * loop + note.beat * Self.secondsPerBeat
                let s = string(note)
                let d = (at - t) / Self.lookahead
                let lit = (t - (at - Self.lookahead - Self.pluck)) / Self.pluck
                if lit >= 0, lit <= 1.4 { view.plucks.append(Pluck(string: s, progress: lit)) }
                if d >= 0, d <= 1 {
                    view.gems.append(Gem(string: s, d: d))
                } else if d < 0, t - at < Self.burst {
                    view.bursts.append(Burst(string: s, age: t - at))
                }
                let end = (at + note.length * Self.secondsPerBeat - t) / Self.lookahead
                if note.length >= 1.5, end > 0, d < 1 { view.tails.append(Tail(string: s, from: max(0, d), to: min(1, end))) }
            }
        }
        return view
    }

    /// Notes landed by song time `t`, from the first loop.
    private static func landed(by t: Double) -> Int {
        guard t >= 0 else { return 0 }
        let loops = (t / loop).rounded(.down)
        let rest = t - loops * loop
        return Int(loops) * tune.count + tune.filter { $0.beat * secondsPerBeat <= rest }.count
    }

    /// The run since the scene appeared.
    private var combo: Int { Self.landed(by: songTime) - Self.landed(by: Self.lead) }

    // MARK: Drawing

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        let g = stage(size)
        let view = notesInView()
        let combo = self.combo
        drawSpotlight(context, g)
        if figure.closeUp {
            // The body dissolves below the bridge and the lanes run on over it.
            drawArt(context, g, plucks: view.plucks)
            drawRunway(context, g)
        } else {
            // A whole picture stands over the lanes' far end and hides where they meet.
            drawRunway(context, g)
            drawArt(context, g, plucks: [])
        }
        drawTargets(context, g, view: view, level: ComboBadge.multiplier(combo))
        for tail in view.tails { drawTail(context, g, tail) }
        for gem in view.gems.sorted(by: { $0.d > $1.d }) { drawGem(context, g, gem) }
        for burst in view.bursts { drawBurst(context, g, burst) }
        drawCombo(context, g, combo: combo, sinceHit: view.bursts.map(\.age).min())
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// A soft pool of the course colour behind the instrument, breathing slowly.
    private func drawSpotlight(_ context: GraphicsContext, _ g: Stage) {
        let breathe = calm ? 0 : 0.04 * sin(elapsed * 0.8)
        let radius = min(g.size.width * 0.42, 170)
        let squash = max(0.3, min(1, g.hitY * 0.8 / radius))
        var light = context
        light.translateBy(x: g.bridge.x, y: g.bridge.y * 0.75)
        light.scaleBy(x: 1, y: squash)
        light.fill(Self.circle(.zero, radius), with: .radialGradient(Gradient(colors: [accent.opacity(0.24 + breathe), accent.opacity(0)]),
                                                                      center: .zero, startRadius: 0, endRadius: radius))
    }

    /// The instrument, turned upright about its bridge and swaying a little there, so the lanes stay on it. It
    /// fades in from the top edge and, close up, dissolves below the bridge; a plucked string lights on it.
    private func drawArt(_ context: GraphicsContext, _ g: Stage, plucks: [Pluck]) {
        let h = max(1, g.size.height)
        var art = context
        if figure.closeUp {
            let solid = min(1, (g.bridge.y + 2) / h)
            let top = max(0.001, min(solid, min(18, g.bridge.y * 0.6) / h))
            let gone = min(1, max(solid + 0.001, (g.bridge.y + max(10, g.span * 0.7)) / h))
            let stops = [Gradient.Stop(color: .clear, location: 0), Gradient.Stop(color: .black, location: top),
                         Gradient.Stop(color: .black, location: solid), Gradient.Stop(color: .clear, location: gone)]
            art.clipToLayer { mask in
                mask.fill(Path(CGRect(origin: .zero, size: g.size)),
                          with: .linearGradient(Gradient(stops: stops), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            }
        }
        let sway = calm ? 0 : sin(elapsed * 0.6) * 0.8
        art.translateBy(x: g.bridge.x, y: g.bridge.y)
        art.rotate(by: .degrees(figure.turn + sway))
        let side = g.art
        let square = CGRect(x: -figure.bridge.x * side, y: -figure.bridge.y * side, width: side, height: side)
        switch figure.art {
        case .picture(let name):
            let picture = art.resolve(Image(name))
            art.draw(picture, in: Self.fitted(picture.size, in: square))
        case .emblem:
            if let tile = art.resolveSymbol(id: Self.emblemTag) {
                var scaled = art
                let k = side / Self.emblemSide
                scaled.scaleBy(x: k, y: k)
                scaled.draw(tile, at: CGPoint(x: square.midX / k, y: square.midY / k), anchor: .center)
            }
        }
        for pluck in plucks { drawPluck(art, pluck, side: side) }
    }

    /// `natural` fitted into `square`, centred, as the picture's points were measured.
    private static func fitted(_ natural: CGSize, in square: CGRect) -> CGRect {
        guard natural.width > 0, natural.height > 0 else { return square }
        let k = min(square.width / natural.width, square.height / natural.height)
        let size = CGSize(width: natural.width * k, height: natural.height * k)
        return CGRect(x: square.midX - size.width / 2, y: square.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// The light running down a plucked string to the bridge, the string glowing in its colour behind it.
    private func drawPluck(_ context: GraphicsContext, _ pluck: Pluck, side: CGFloat) {
        let tint = color(pluck.string)
        let fade = pluck.progress <= 1 ? 1 : max(0, 1 - (pluck.progress - 1) / 0.4)
        let head = 0.3 + 0.7 * min(1, pluck.progress)
        for wire in figure.wires where laneString(ofWire: wire.number) == pluck.string {
            let nut = local(wire.nut, side), saddle = local(wire.saddle, side)
            func point(_ u: Double) -> CGPoint {
                CGPoint(x: nut.x + (saddle.x - nut.x) * CGFloat(u), y: nut.y + (saddle.y - nut.y) * CGFloat(u))
            }
            var glowing = Path()
            glowing.move(to: point(0.3))
            glowing.addLine(to: saddle)
            context.stroke(glowing, with: .color(tint.opacity(0.3 * fade)), lineWidth: 1.4)
            guard pluck.progress <= 1 else { continue }
            let tailStart = point(max(0.3, head - 0.22)), tip = point(head)
            var trail = Path()
            trail.move(to: tailStart)
            trail.addLine(to: tip)
            context.stroke(trail, with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.mix(with: .white, by: 0.5)]), startPoint: tailStart, endPoint: tip),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.fill(Self.circle(tip, 4), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.9), tint.opacity(0)]), center: tip, startRadius: 0, endRadius: 4))
        }
    }

    /// A point on the picture, relative to the bridge, in the turned art's coordinates.
    private func local(_ point: CGPoint, _ side: CGFloat) -> CGPoint {
        CGPoint(x: (point.x - figure.bridge.x) * side, y: (point.y - figure.bridge.y) * side)
    }

    /// The floor, the beat lines rolling toward you and a lane per string from the bridge, brightening toward the
    /// line and fading just past it.
    private func drawRunway(_ context: GraphicsContext, _ g: Stage) {
        let nearDepth = -(g.target + 8) / g.span
        let nearY = g.y(nearDepth)
        let line = min(0.98, max(0.02, (g.hitY - g.bridge.y) / max(1, nearY - g.bridge.y)))
        let from = CGPoint(x: 0, y: g.bridge.y), to = CGPoint(x: 0, y: nearY)
        var floor = Path()
        floor.move(to: CGPoint(x: g.edge(-1, 1), y: g.bridge.y))
        floor.addLine(to: CGPoint(x: g.edge(1, 1), y: g.bridge.y))
        floor.addLine(to: CGPoint(x: g.edge(1, nearDepth), y: nearY))
        floor.addLine(to: CGPoint(x: g.edge(-1, nearDepth), y: nearY))
        floor.closeSubpath()
        let shade = [Gradient.Stop(color: Self.floorShade.opacity(0), location: 0), Gradient.Stop(color: Self.floorShade.opacity(0.6), location: line),
                     Gradient.Stop(color: Self.floorShade.opacity(0), location: 1)]
        context.fill(floor, with: .linearGradient(Gradient(stops: shade), startPoint: from, endPoint: to))
        // A line per beat rolling toward you, the bar lines brighter, out of the dark at the far end.
        let spb = Self.secondsPerBeat
        let firstBeat = Int((songTime / spb).rounded(.down))
        for beat in firstBeat...(firstBeat + Int(Self.lookahead / spb) + 1) {
            let d = (Double(beat) * spb - songTime) / Self.lookahead
            guard d > 0, d < 1 else { continue }
            let depth = g.depth(d)
            var rung = Path()
            rung.move(to: CGPoint(x: g.edge(-1, depth), y: g.y(depth)))
            rung.addLine(to: CGPoint(x: g.edge(1, depth), y: g.y(depth)))
            let bar = beat % 4 == 0
            context.stroke(rung, with: .color(.white.opacity((bar ? 0.12 : 0.045) * (1 - d * 0.7))), lineWidth: 1)
        }
        for s in 1...lanes {
            let tint = color(s)
            let column = lane(s)
            var strip = Path()
            strip.move(to: CGPoint(x: g.x(lane: column, 1), y: g.bridge.y))
            strip.addLine(to: CGPoint(x: g.x(lane: column, nearDepth), y: nearY))
            let glow = [Gradient.Stop(color: tint.opacity(0), location: 0), Gradient.Stop(color: tint.opacity(0.16), location: line),
                        Gradient.Stop(color: tint.opacity(0), location: 1)]
            let core = [Gradient.Stop(color: tint.opacity(0.1), location: 0), Gradient.Stop(color: tint.opacity(0.62), location: line),
                        Gradient.Stop(color: tint.opacity(0), location: 1)]
            context.stroke(strip, with: .linearGradient(Gradient(stops: glow), startPoint: from, endPoint: to), lineWidth: 4)
            context.stroke(strip, with: .linearGradient(Gradient(stops: core), startPoint: from, endPoint: to), lineWidth: 1.2)
        }
    }

    /// The hit line and a target per string: dark, filling as a note closes in, flashing as it lands. The line
    /// warms with the multiplier, as on the lesson highway.
    private func drawTargets(_ context: GraphicsContext, _ g: Stage, view: InView, level: Int) {
        let warm = level >= 3 ? ComboBadge.tint(level) : Self.hitLine
        let flash = view.bursts.map { max(0, 1 - $0.age / 0.3) }.max() ?? 0
        let left = g.edge(-1, 0) - 4, right = g.edge(1, 0) + 4
        let band = CGRect(x: left, y: g.hitY - 9, width: right - left, height: 18)
        context.fill(Path(roundedRect: band, cornerRadius: 9),
                     with: .linearGradient(Gradient(colors: [warm.opacity(0), warm.opacity(0.1 + 0.12 * flash), warm.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        context.fill(Path(roundedRect: CGRect(x: left, y: g.hitY - 1, width: right - left, height: 2), cornerRadius: 1),
                     with: .color(warm.opacity(0.55 + 0.3 * flash)))
        for s in 1...lanes {
            let tint = color(s)
            let center = CGPoint(x: g.x(lane: lane(s), 0), y: g.hitY)
            let lit = view.bursts.filter { $0.string == s }.map { max(0, 1 - $0.age / 0.3) }.max() ?? 0
            let near = view.gems.filter { $0.string == s && $0.d < 0.2 }.map { 1 - $0.d / 0.2 }.max() ?? 0
            let r = g.target * (1 + 0.15 * CGFloat(lit))
            context.fill(Self.circle(center, g.target + 2.5), with: .color(.black.opacity(0.55)))
            context.fill(Self.circle(center, r), with: .color(tint.opacity(0.08 + 0.3 * near + 0.45 * lit)))
            context.stroke(Self.circle(center, r), with: .color(tint.opacity(0.8 + 0.2 * max(near, lit))), lineWidth: 1.6)
        }
    }

    /// A held note's ribbon up its lane.
    private func drawTail(_ context: GraphicsContext, _ g: Stage, _ tail: Tail) {
        guard tail.to > tail.from else { return }
        let a = g.depth(tail.from), b = g.depth(tail.to)
        let column = lane(tail.string)
        let wa = g.gap * 0.07 * g.scale(a), wb = g.gap * 0.07 * g.scale(b)
        var path = Path()
        path.move(to: CGPoint(x: g.x(lane: column, a) - wa, y: g.y(a)))
        path.addLine(to: CGPoint(x: g.x(lane: column, b) - wb, y: g.y(b)))
        path.addLine(to: CGPoint(x: g.x(lane: column, b) + wb, y: g.y(b)))
        path.addLine(to: CGPoint(x: g.x(lane: column, a) + wa, y: g.y(a)))
        path.closeSubpath()
        context.fill(path, with: .color(color(tail.string).opacity(0.42)))
    }

    /// A glossy gem in the string's colour, born at the bridge and growing as it nears.
    private func drawGem(_ context: GraphicsContext, _ g: Stage, _ gem: Gem) {
        let depth = g.depth(gem.d), scale = g.scale(depth)
        let width = g.gap * 0.66 * scale
        let height = max(1, min(g.gap * 0.34, 11) * scale)
        let center = CGPoint(x: g.x(lane: lane(gem.string), depth), y: g.y(depth))
        let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        let alpha = gem.d > 0.8 ? max(0, (1 - gem.d) / 0.2) : 1
        let tint = color(gem.string)
        let shape = Path(roundedRect: rect, cornerRadius: height * 0.42)
        let shine = Gradient(colors: [tint.mix(with: .white, by: 0.4).opacity(alpha), tint.opacity(alpha)])
        context.fill(shape, with: .linearGradient(shine, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(shape, with: .color(.white.opacity(0.35 * alpha)), lineWidth: 0.8)
    }

    /// A soft flash, a ring and four sparks off the target, in the string's colour.
    private func drawBurst(_ context: GraphicsContext, _ g: Stage, _ burst: Burst) {
        let progress = min(1, burst.age / Self.burst)
        let fade = 1 - progress
        let tint = color(burst.string)
        let center = CGPoint(x: g.x(lane: lane(burst.string), 0), y: g.hitY)
        let glow = g.target * 1.6
        context.fill(Self.circle(center, glow), with: .radialGradient(Gradient(colors: [tint.opacity(0.5 * fade * fade), tint.opacity(0)]),
                                                                       center: center, startRadius: 0, endRadius: glow))
        let r = g.target * (1 + 1.2 * CGFloat(progress))
        context.stroke(Self.circle(center, r), with: .color(tint.opacity(0.8 * fade)), lineWidth: 0.6 + 1.4 * fade)
        for spark in 0..<4 {
            let angle = (Double(spark) * 90 + 45 + Double(burst.string) * 13) * .pi / 180
            let inner = r + 1, outer = r + 2 + CGFloat(fade) * 3
            var path = Path()
            path.move(to: CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle))))
            path.addLine(to: CGPoint(x: center.x + outer * CGFloat(cos(angle)), y: center.y + outer * CGFloat(sin(angle))))
            context.stroke(path, with: .color(tint.mix(with: .white, by: 0.4).opacity(fade)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }

    /// "Combo ×3" and four pips filling toward the next step, centred under the hit line. It pulses as a note
    /// lands, more when the multiplier steps up, and glows from ×3.
    private func drawCombo(_ context: GraphicsContext, _ g: Stage, combo: Int, sinceHit: Double?) {
        let level = ComboBadge.multiplier(combo)
        let tint = ComboBadge.tint(level)
        let label = context.resolve(Text("Combo ×\(level)").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(tint))
        let measured = label.measure(in: CGSize(width: g.width, height: 40))
        let pips: CGFloat = 4 * 9 + 3 * 3
        let left = g.bridge.x - (measured.width + 8 + pips) / 2
        let center = CGPoint(x: left + measured.width / 2, y: g.comboY)
        let age = sinceHit ?? 1
        let stepped = combo == 4 || combo == 8 || combo == 16
        let swell = calm ? 1 : 1 + (stepped ? 0.2 : 0.06) * CGFloat(max(0, 1 - age / 0.3))
        var text = context
        if level >= 3 { text.addFilter(.shadow(color: tint.opacity(0.6), radius: 6)) }
        text.translateBy(x: center.x, y: center.y)
        text.scaleBy(x: swell, y: swell)
        text.draw(label, at: .zero, anchor: .center)
        let filled = level >= 4 ? 4 : Int((ComboBadge.progress(combo) * 4).rounded(.down))
        for pip in 0..<4 {
            let rect = CGRect(x: left + measured.width + 8 + CGFloat(pip) * 12, y: g.comboY - 1.5, width: 9, height: 3)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(pip < filled ? tint : Color.white.opacity(0.14)))
        }
    }
}
