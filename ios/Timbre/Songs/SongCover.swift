import SwiftUI

/// Generative cover art for a song. Everything is derived from the lesson id (and its course accent), so a
/// song always wears the same cover in every language and no image assets are needed: a dark gradient from
/// the course accent into a second hue, a soft glow, one of five line patterns, and an SF Symbol chosen from
/// the song's title ("Twinkle" gets the moon and stars) or, failing that, from the id.
struct CoverArt {
    enum Pattern: Int, CaseIterable { case rings, stripes, halftone, waves, rays }

    let seed: UInt64
    let primary: Color
    let secondary: Color
    let pattern: Pattern
    let symbol: String
    /// Gradient direction in degrees.
    let angle: Double
    /// Where the glow sits, as a fraction of the cover.
    let glow: UnitPoint
    /// The symbol's lean in degrees.
    let tilt: Double

    init(id: String, title: String, accent: String) {
        let seed = Self.hash(id)
        self.seed = seed
        primary = Palette.accent(accent)
        let others = ["mint", "amber", "violet", "coral", "sky"].filter { $0 != accent }
        secondary = Palette.accent(others[Int((seed >> 8) % UInt64(others.count))])
        pattern = Pattern(rawValue: Int((seed >> 16) % UInt64(Pattern.allCases.count))) ?? .rings
        symbol = Self.motif(id: id, title: title) ?? Self.symbols[Int((seed >> 24) % UInt64(Self.symbols.count))]
        angle = Double((seed >> 32) % 360)
        var random = SystemRandom(seed: seed)
        let glowX = 0.15 + 0.7 * random.next()
        let glowY = 0.1 + 0.5 * random.next()
        glow = UnitPoint(x: CGFloat(glowX), y: CGFloat(glowY))
        tilt = -14 + 28 * random.next()
    }

    /// The gradient's two ends: deep accent into a darker second hue.
    var deep: Color { primary.mix(with: .black, by: 0.5) }
    var far: Color { secondary.mix(with: .black, by: 0.66) }
    var start: UnitPoint {
        let radians = angle * Double.pi / 180
        return UnitPoint(x: CGFloat(0.5 - 0.5 * cos(radians)), y: CGFloat(0.5 - 0.5 * sin(radians)))
    }
    var end: UnitPoint { UnitPoint(x: 1 - start.x, y: 1 - start.y) }

    /// A stable 64-bit hash (FNV-1a with a final mix): `String.hashValue` changes between launches.
    static func hash(_ text: String, salt: UInt64 = 0) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325 ^ salt
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
        value ^= value >> 33
        value = value &* 0xff51_afd7_ed55_8ccd
        value ^= value >> 33
        return value
    }

    private static let symbols = ["music.note", "music.mic", "guitars.fill", "pianokeys", "waveform", "sparkles",
                                  "star.fill", "music.quarternote.3", "flame.fill", "bolt.fill", "headphones", "metronome.fill"]

    /// Title words → symbol, first match wins (English title and id, so every language gets the same cover).
    private static let motifs: [(words: [String], symbol: String)] = [
        (["twinkle", "lullaby", "silent", "lune", "moon"], "moon.stars.fill"),
        (["jingle", "deck the", "wenceslas", "christmas", "joy to the world"], "snowflake"),
        (["jacques", "bell"], "bell.fill"),
        (["swan", "bird", "lark"], "bird.fill"),
        (["sailor", "river", "shenandoah", "clementine", "creek", "lightly row", "tide"], "water.waves"),
        (["rain"], "cloud.rain.fill"),
        (["radio", "static", "channel"], "antenna.radiowaves.left.and.right"),
        (["ember", "smoke", "cedar"], "flame.fill"),
        (["porchlight", "neon", "laundromat"], "lightbulb.fill"),
        (["kite", "weather"], "wind"),
        (["dashboard", "mile marker", "highway"], "car.fill"),
        (["comet", "carousel"], "sparkles"),
        (["shuffle"], "guitars.fill"),
        (["mountain", "gap"], "mountain.2.fill"),
        (["lamb", "macdonald", "cabbage", "grove", "greensleeves"], "leaf.fill"),
        (["races", "traveler", "yankee", "susanna", "skip to"], "hare.fill"),
        (["saints", "grace", "gifts", "joy"], "sun.max.fill"),
        (["blues", "walking", "groove"], "guitars.fill"),
        (["elise"], "pianokeys"),
        (["symphony", "canon", "mozart", "nachtmusik", "largo", "minuet"], "music.quarternote.3"),
        (["auld", "country"], "sparkles"),
        (["danny", "aura", "love", "heart"], "heart.fill"),
    ]

    private static func motif(id: String, title: String) -> String? {
        let text = (id + " " + title).lowercased()
        return motifs.first { motif in motif.words.contains { text.contains($0) } }?.symbol
    }

    // MARK: Pattern

    func drawPattern(in context: inout GraphicsContext, size: CGSize) {
        var random = SystemRandom(seed: seed &+ 7)
        let unit = max(8, min(size.width, size.height))
        let reach = hypot(size.width, size.height)
        switch pattern {
        case .rings: drawRings(in: &context, size: size, unit: unit, reach: reach, random: &random)
        case .stripes: drawStripes(in: &context, size: size, unit: unit, reach: reach, random: &random)
        case .halftone: drawHalftone(in: &context, size: size, unit: unit, random: &random)
        case .waves: drawWaves(in: &context, size: size, unit: unit, random: &random)
        case .rays: drawRays(in: &context, size: size, reach: reach, random: &random)
        }
    }

    /// Record grooves around a point near the top.
    private func drawRings(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, reach: CGFloat, random: inout SystemRandom) {
        let cx = CGFloat(0.5 + 0.45 * random.next())
        let cy = CGFloat(0.05 + 0.5 * random.next())
        let center = CGPoint(x: size.width * cx, y: size.height * cy)
        let step = unit * 0.065
        var ring = 1
        while CGFloat(ring) * step < reach * 1.2 {
            let radius = CGFloat(ring) * step
            let strong = ring % 4 == 0
            let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(circle, with: .color(.white.opacity(strong ? 0.2 : 0.08)), lineWidth: strong ? 1.6 : 0.8)
            ring += 1
        }
    }

    /// Bold diagonal bands.
    private func drawStripes(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, reach: CGFloat, random: inout SystemRandom) {
        var layer = context
        layer.translateBy(x: size.width / 2, y: size.height / 2)
        layer.rotate(by: .degrees(25 + 40 * random.next()))
        let step = unit * 0.09
        var x = -reach
        while x < reach {
            layer.fill(Path(CGRect(x: x, y: -reach, width: step * 0.4, height: reach * 2)), with: .color(.white.opacity(0.07)))
            x += step
        }
    }

    /// A halftone burst: dots that shrink away from a point.
    private func drawHalftone(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, random: inout SystemRandom) {
        let cx = CGFloat(random.next())
        let cy = CGFloat(random.next())
        let center = CGPoint(x: size.width * cx, y: size.height * cy)
        let step = unit * 0.085
        var y = step / 2
        while y < size.height {
            var x = step / 2
            while x < size.width {
                let falloff = max(0, 1 - hypot(x - center.x, y - center.y) / (unit * 1.1))
                let radius = step * 0.42 * falloff
                if radius > 0.5 {
                    context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(.white.opacity(0.16)))
                }
                x += step
            }
            y += step
        }
    }

    /// Stacked sound waves.
    private func drawWaves(in context: inout GraphicsContext, size: CGSize, unit: CGFloat, random: inout SystemRandom) {
        let lines = 10
        let amplitude = unit * CGFloat(0.025 + 0.035 * random.next())
        let cycles = CGFloat(1 + 2 * random.next())
        let phase = CGFloat(random.next() * 2 * Double.pi)
        for line in 0..<lines {
            let base = size.height * (CGFloat(line) + 0.5) / CGFloat(lines)
            let shift = phase + CGFloat(line) * 0.55
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width + 4 {
                let angle = shift + x / unit * cycles * 2 * .pi
                let point = CGPoint(x: x, y: base + amplitude * sin(angle))
                if x == 0 { path.move(to: point) } else { path.addLine(to: point) }
                x += 4
            }
            let strong = line % 2 == 0
            context.stroke(path, with: .color(.white.opacity(strong ? 0.16 : 0.07)), lineWidth: strong ? 1.4 : 0.8)
        }
    }

    /// A sunburst from one corner.
    private func drawRays(in context: inout GraphicsContext, size: CGSize, reach: CGFloat, random: inout SystemRandom) {
        let right = random.next() < 0.5
        let bottom = random.next() < 0.6
        let corner = CGPoint(x: right ? size.width : 0, y: bottom ? size.height : 0)
        let count = 28
        for ray in stride(from: 0, to: count, by: 2) {
            let from = CGFloat(ray) / CGFloat(count) * 2 * .pi
            let to = CGFloat(ray + 1) / CGFloat(count) * 2 * .pi
            var wedge = Path()
            wedge.move(to: corner)
            wedge.addLine(to: CGPoint(x: corner.x + cos(from) * reach * 1.5, y: corner.y + sin(from) * reach * 1.5))
            wedge.addLine(to: CGPoint(x: corner.x + cos(to) * reach * 1.5, y: corner.y + sin(to) * reach * 1.5))
            wedge.closeSubpath()
            context.fill(wedge, with: .color(.white.opacity(0.06)))
        }
    }
}

/// A song's cover, drawn from its `CoverArt`: gradient, glow, pattern, symbol and a top-left sheen.
struct SongCover: View {
    let art: CoverArt
    var corner: CGFloat = 20
    /// Where the symbol sits, as a fraction of the cover.
    var symbolAnchor = UnitPoint(x: 0.66, y: 0.62)
    /// The glow drifts slowly (the featured song), unless Reduce Motion is on.
    var drift = false
    var outlined = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        GeometryReader { proxy in
            artwork(size: proxy.size)
        }
        .clipShape(shape)
        .overlay { if outlined { shape.strokeBorder(.white.opacity(0.1), lineWidth: 1) } }
        .onAppear {
            guard drift, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drifting = true }
        }
        .accessibilityHidden(true)
    }

    private func artwork(size: CGSize) -> some View {
        let side = min(size.width, size.height)
        return ZStack {
            LinearGradient(colors: [art.deep, art.far], startPoint: art.start, endPoint: art.end)
            glow(side: side)
                .position(x: size.width * art.glow.x, y: size.height * art.glow.y)
            Canvas { context, canvasSize in art.drawPattern(in: &context, size: canvasSize) }
            Image(systemName: art.symbol)
                .font(.system(size: side * 0.46, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: side * 0.05, y: side * 0.03)
                .rotationEffect(.degrees(art.tilt))
                .position(x: size.width * symbolAnchor.x, y: size.height * symbolAnchor.y)
            LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .center)
        }
        .frame(width: size.width, height: size.height)
    }

    private func glow(side: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [art.primary.opacity(0.75), art.primary.opacity(0)], center: .center, startRadius: 0, endRadius: side * 0.6))
            .frame(width: side * 1.2, height: side * 1.2)
            .scaleEffect(drifting ? 1.12 : 0.94)
            .offset(x: drifting ? side * 0.1 : -side * 0.04, y: drifting ? -side * 0.06 : side * 0.03)
            .blendMode(.screen)
    }
}
