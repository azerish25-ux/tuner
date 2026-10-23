import CoreText
import SwiftUI
import UIKit

/// Generative typographic cover art for a song. Colour, pattern and composition come from the lesson id (and its
/// course accent), so a song always wears the same cover and no image assets are needed: a dark gradient from the
/// course accent into a second hue, a soft glow, one of five line patterns, and the title's monogram set large in
/// Sora ("Mary Had a Little Lamb" is ML, "Porchlight" is Po), whole inside the cover so it always reads.
struct CoverArt {
    enum Pattern: Int, CaseIterable { case rings, stripes, halftone, waves, rays }

    let seed: UInt64
    let primary: Color
    let secondary: Color
    let pattern: Pattern
    /// One or two letters from the title (`monogram(_:)`).
    let monogram: String
    /// Gradient direction in degrees.
    let angle: Double
    /// Where the glow sits, as a fraction of the cover.
    let glow: UnitPoint
    /// The monogram's lean in degrees.
    let tilt: Double

    /// `title` is the title as shown, so the letters match it in every language.
    init(id: String, title: String, accent: String) {
        let seed = Self.hash(id)
        self.seed = seed
        primary = Palette.accent(accent)
        let others = ["mint", "amber", "violet", "coral", "sky"].filter { $0 != accent }
        secondary = Palette.accent(others[Int((seed >> 8) % UInt64(others.count))])
        pattern = Pattern(rawValue: Int((seed >> 16) % UInt64(Pattern.allCases.count))) ?? .rings
        monogram = Self.monogram(title)
        angle = Double((seed >> 32) % 360)
        var random = SystemRandom(seed: seed)
        let glowX = 0.15 + 0.7 * random.next()
        let glowY = 0.1 + 0.5 * random.next()
        glow = UnitPoint(x: CGFloat(glowX), y: CGFloat(glowY))
        tilt = -6 + 12 * random.next()
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

    /// Little words a monogram skips ("Ode to Joy" is OJ, "Ode an die Freude" OF).
    private static let minorWords: Set<String> = [
        "a", "an", "the", "to", "of", "in", "on", "at", "and", "or", "for", "my", "your", "our", "no",
        "de", "del", "la", "le", "les", "du", "des", "el", "los", "las", "il", "lo", "et", "y", "e",
        "der", "die", "das", "dem", "den", "ein", "eine", "und", "im", "am", "het", "een", "en",
    ]

    /// The title's monogram: the initials of its first and last words that carry meaning ("Mary Had a Little
    /// Lamb" → "ML"), or a one-word title's first two letters ("Porchlight" → "Po"). A subtitle after a colon or
    /// in brackets is left out ("Greensleeves: the melody" → "Gr"). Scripts without capitals take one character.
    static func monogram(_ title: String) -> String {
        let main = title.split(whereSeparator: { $0 == ":" || $0 == "(" || $0 == "（" || $0 == "：" }).first.map(String.init) ?? title
        let words = main.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "’" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'’")) }
            .filter { !$0.isEmpty }
        let meaningful = words.filter { $0.count > 1 && !minorWords.contains($0.lowercased()) }
        let pool = meaningful.isEmpty ? words : meaningful
        guard let first = pool.first, let lead = first.first else { return "♪" }
        guard lead.isCased else { return String(lead) }
        if pool.count > 1, let last = pool.last?.first { return (String(lead) + String(last)).uppercased() }
        let letters = Array(first)
        guard letters.count > 1 else { return String(lead).uppercased() }
        return String(lead).uppercased() + String(letters[1]).lowercased()
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

/// A song's cover, drawn from its `CoverArt`: gradient, glow, pattern, the monogram and a top-left sheen; a song
/// not reached yet dims under a lock.
struct SongCover: View {
    let art: CoverArt
    var corner: CGFloat = 20
    /// Where the monogram's centre would like to sit, as a fraction of the cover; it moves in from there only as
    /// far as it must to stay inside `monogramBounds`.
    var monogramAnchor = UnitPoint(x: 0.66, y: 0.62)
    /// The monogram's type size as a fraction of the cover's shorter side (two letters; one letter sets larger),
    /// smaller when the letters wouldn't fit `monogramBounds` whole.
    var monogramSize: CGFloat = 0.5
    /// The part of the cover (as fractions of it) that holds all of the monogram: letters, offset print and lean.
    var monogramBounds = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84)
    /// Not reached yet: the cover dims and a lock sits in the corner farthest from the letters.
    var locked = false
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
        let placement = MonogramPlacement(text: art.monogram, points: side * monogramSize * (art.monogram.count > 1 ? 1 : 1.24),
                                          tilt: art.tilt, cover: size, anchor: monogramAnchor, bounds: monogramBounds)
        return ZStack {
            LinearGradient(colors: [art.deep, art.far], startPoint: art.start, endPoint: art.end)
            glow(side: side)
                .position(x: size.width * art.glow.x, y: size.height * art.glow.y)
            Canvas { context, canvasSize in art.drawPattern(in: &context, size: canvasSize) }
            monogram(points: placement.points, side: side)
                .position(placement.center)
            LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .center)
            if locked { lock(size: size, letters: placement.center) }
        }
        .frame(width: size.width, height: size.height)
    }

    /// The dim over a song not reached yet, and its lock in the corner farthest from the letters.
    private func lock(size: CGSize, letters: CGPoint) -> some View {
        let badge: CGFloat = 36
        let inset: CGFloat = 12
        let x = letters.x > size.width / 2 ? inset + badge / 2 : size.width - inset - badge / 2
        let y = letters.y > size.height / 2 ? inset + badge / 2 : size.height - inset - badge / 2
        return ZStack {
            Color.black.opacity(0.5)
            Image(systemName: "lock.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.9))
                .frame(width: badge, height: badge)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .position(x: x, y: y)
        }
    }

    /// The letters in Sora, white over an offset print in the cover's second hue.
    private func monogram(points: CGFloat, side: CGFloat) -> some View {
        let font = Font.custom("Sora-SemiBold", fixedSize: points)
        return ZStack {
            Text(verbatim: art.monogram).font(font).tracking(-points * 0.04)
                .foregroundStyle(art.secondary.mix(with: .white, by: 0.25).opacity(0.7))
                .offset(x: points * 0.05, y: points * 0.05)
                .blendMode(.screen)
            Text(verbatim: art.monogram).font(font).tracking(-points * 0.04)
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.76)], startPoint: .top, endPoint: .bottom))
        }
        .lineLimit(1)
        .fixedSize()
        .shadow(color: .black.opacity(0.3), radius: side * 0.04, y: side * 0.02)
        .rotationEffect(.degrees(art.tilt))
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

/// Where a cover's monogram goes and at what size, so all of it (the letters, their offset print, the lean)
/// stays inside the cover's monogram bounds: the ink is measured from the glyphs themselves with Core Text,
/// set at the asked size when it fits and smaller when it doesn't, and moved from the anchor only as far as
/// it must. Matches `SongCover.monogram`: Sora SemiBold, tracking −4 %, the print 5 % down and right.
private struct MonogramPlacement {
    /// The centre of the letters' text frame, in the cover.
    let center: CGPoint
    let points: CGFloat

    init(text: String, points: CGFloat, tilt: Double, cover: CGSize, anchor: UnitPoint, bounds: CGRect) {
        let box = CGRect(x: cover.width * bounds.minX, y: cover.height * bounds.minY,
                         width: cover.width * bounds.width, height: cover.height * bounds.height)
        let ink = Self.ink(text, points: max(1, points), tilt: tilt)
        // Everything in the ink scales with the type size, about the frame's centre.
        let scale = min(1, box.width / max(1, ink.width), box.height / max(1, ink.height))
        let fitted = CGRect(x: ink.minX * scale, y: ink.minY * scale, width: ink.width * scale, height: ink.height * scale)
        center = CGPoint(x: Self.clamp(cover.width * anchor.x, box.minX - fitted.minX, box.maxX - fitted.maxX),
                         y: Self.clamp(cover.height * anchor.y, box.minY - fitted.minY, box.maxY - fitted.maxY))
        self.points = points * scale
    }

    private static func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        low > high ? (low + high) / 2 : min(max(value, low), high)
    }

    /// The box around the monogram's ink at `points`, relative to the centre of its text frame (y down).
    private static func ink(_ text: String, points: CGFloat, tilt: Double) -> CGRect {
        let font = UIFont(name: "Sora-SemiBold", size: points) ?? UIFont.systemFont(ofSize: points, weight: .semibold)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: -points * 0.04])
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        var glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        if glyphs.isNull || glyphs.isEmpty { glyphs = CGRect(x: 0, y: -descent, width: width, height: ascent + descent) }
        // Core Text measures up from the baseline; the frame's centre sits half its height below its top, and
        // the baseline `ascent` below the top.
        let baseline = ascent - (ascent + descent) / 2
        let print = points * 0.05
        let letters = CGRect(x: glyphs.minX - width / 2, y: baseline - glyphs.maxY,
                             width: glyphs.width + print, height: glyphs.height + print)
        return turned(letters, degrees: tilt)
    }

    /// The box around `rect` turned by `degrees` about the origin, either way (the lean is a few degrees).
    private static func turned(_ rect: CGRect, degrees: Double) -> CGRect {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for sign in [1.0, -1.0] {
            let radians = degrees * sign * Double.pi / 180
            let c = CGFloat(cos(radians)), s = CGFloat(sin(radians))
            for corner in corners {
                let x = corner.x * c - corner.y * s
                let y = corner.x * s + corner.y * c
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
