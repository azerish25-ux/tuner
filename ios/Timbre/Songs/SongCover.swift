import SwiftUI
import TimbreCore
import UIKit

/// Generative single-sleeve art for a song, so a shelf of songs reads like a rack of records with no image assets.
/// Everything comes from the song: its id seeds the layout (a song always wears the same sleeve), its unit gives it
/// a genre (a palette and a family of motifs), its course stands in for the artist, and its title is set in Sora.
/// A sleeve is either dark (a deep gradient, the motif in the song's colours, light type) or, now and then, a bright
/// colour field with the motif and the type in ink.
struct CoverArt {
    enum Genre: CaseIterable { case nursery, folk, classical, americana, holiday, swing, rock, anthem }
    enum Motif: CaseIterable { case sunset, waveform, orbits, grid, ridges, stripes, sparkle, contour }

    let seed: UInt64
    let genre: Genre
    let motif: Motif
    /// The motif's colour and the one it plays against.
    let primary: Color
    let secondary: Color
    /// A bright colour field with ink type and motif, rather than a dark sleeve.
    let field: Bool
    /// The title sits at the top-left (the motif below it), else at the bottom-left (the motif above).
    let titleOnTop: Bool
    /// The title as set on the sleeve: the main title (no subtitle), in capitals for some genres.
    let title: String
    /// The small line over the title: the course, as the artist.
    let label: String
    /// The song's place in its course, as a catalogue number.
    let number: Int
    /// Gradient direction in degrees.
    let angle: Double
    /// Where the glow sits, as a fraction of the sleeve.
    let glow: UnitPoint

    /// `title` is the title as shown, so the sleeve matches it in every language.
    init(id: String, title: String, accent: String, genre: Genre, label: String, number: Int) {
        let seed = Self.hash(id)
        var random = SystemRandom(seed: seed)
        self.seed = seed
        self.genre = genre
        // The course's colour leads now and then; otherwise the genre's own.
        let hues = genre.hues
        let pool = [accent] + hues
        let first = pool[Self.index(random.next(), pool.count)]
        let others = hues.filter { $0 != first }
        let second = others.isEmpty ? (first == "mint" ? "violet" : "mint") : others[Self.index(random.next(), others.count)]
        primary = Palette.accent(first)
        secondary = Palette.accent(second)
        let motifs = genre.motifs
        let chosen = motifs[Self.index(random.next(), motifs.count)]
        motif = chosen
        let fieldRoll = random.next()
        field = genre.allowsField && fieldRoll < 0.28
        let coin = random.next() < 0.5
        // A sun or ridges sit low, so their title goes on top.
        titleOnTop = (chosen == .ridges || chosen == .sunset) ? true : coin
        let capitalRoll = random.next()
        let capitals = genre.capitals ?? (capitalRoll < 0.25)
        let main = Self.mainTitle(title)
        self.title = capitals ? main.uppercased() : main
        self.label = label.uppercased()
        self.number = number
        angle = 200 + 140 * random.next()
        glow = UnitPoint(x: CGFloat(0.2 + 0.6 * random.next()), y: CGFloat(0.12 + 0.5 * random.next()))
    }

    private static func index(_ value: Double, _ count: Int) -> Int { min(max(0, count - 1), Int(value * Double(count))) }

    // MARK: Colour

    /// The sleeve's gradient ends.
    var deep: Color { field ? primary.mix(with: .white, by: 0.08) : primary.mix(with: .black, by: 0.62) }
    var far: Color { field ? primary.mix(with: secondary, by: 0.35).mix(with: .black, by: 0.16) : secondary.mix(with: .black, by: 0.8) }
    /// Type: light on a dark sleeve, ink on a colour field.
    var ink: Color { field ? Palette.stage : Palette.ink }
    var start: UnitPoint {
        let radians = angle * Double.pi / 180
        return UnitPoint(x: CGFloat(0.5 - 0.5 * cos(radians)), y: CGFloat(0.5 - 0.5 * sin(radians)))
    }
    var end: UnitPoint { UnitPoint(x: 1 - start.x, y: 1 - start.y) }
    /// The corner clear of the title, where a badge, a lock or a button goes.
    var freeCorner: Alignment { titleOnTop ? .bottomTrailing : .topTrailing }

    /// A stable 64-bit hash: `String.hashValue` changes between launches.
    static func hash(_ text: String, salt: UInt64 = 0) -> UInt64 { SongOfTheDay.hash(text, salt: salt) }

    /// The title without a subtitle after a colon or in brackets ("Greensleeves: the melody" is "Greensleeves",
    /// "Danny Boy (Londonderry Air)" is "Danny Boy").
    static func mainTitle(_ title: String) -> String {
        let main = title.split(whereSeparator: { $0 == ":" || $0 == "(" || $0 == "（" || $0 == "：" }).first.map(String.init) ?? title
        let trimmed = main.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? title : trimmed
    }

    /// A unit's genre from its English title ("Classical themes I", "Riffs, power chords and throwbacks"), else from
    /// the course's instrument.
    static func genre(unit: String, instrument: String?) -> Genre {
        let text = unit.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if has(["classical", "concert", "minuet", "expression", "shifting"]) { return .classical }
        if has(["holiday", "celebration", "christmas"]) { return .holiday }
        if has(["hymn", "americana", "fiddle", "clawhammer", "hammer-on"]) { return .americana }
        if has(["swing", "seventh", "blues", "walking", "jazz"]) { return .swing }
        if has(["riff", "power", "throwback", "rock"]) { return .rock }
        if has(["barre", "finish", "together", "anthem"]) { return .anthem }
        if has(["first"]) { return .nursery }
        if has(["folk", "open", "melodies", "songs"]) { return .folk }
        let family = instrument?.split(separator: ".").first.map(String.init) ?? ""
        switch family {
        case "violin", "cello": return .classical
        case "banjo", "mandolin": return .americana
        case "bass": return .swing
        case "voice": return .anthem
        default: return .folk
        }
    }

    // MARK: Motif

    /// Draws the motif inside `region` (the sleeve less its type), then a fine print grain over the whole sleeve.
    func draw(in context: inout GraphicsContext, size: CGSize, region: CGRect) {
        guard size.width > 1, size.height > 1, region.width > 1, region.height > 1 else { return }
        var random = SystemRandom(seed: seed &+ 7)
        let ink = MotifInk(main: field ? Palette.stage : primary,
                           second: field ? Color.white : secondary,
                           line: field ? Color.black : Color.white)
        switch motif {
        case .sunset: Motifs.sunset(&context, size: size, region: region, ink: ink, random: &random)
        case .waveform: Motifs.waveform(&context, size: size, region: region, ink: ink, random: &random)
        case .orbits: Motifs.orbits(&context, region: region, ink: ink, random: &random)
        case .grid: Motifs.grid(&context, region: region, ink: ink, random: &random)
        case .ridges: Motifs.ridges(&context, size: size, region: region, ink: ink, random: &random)
        case .stripes: Motifs.stripes(&context, size: size, region: region, ink: ink, random: &random)
        case .sparkle: Motifs.sparkle(&context, region: region, ink: ink, random: &random)
        case .contour: Motifs.contour(&context, region: region, ink: ink, random: &random)
        }
        Motifs.grain(&context, size: size, random: &random)
    }
}

private extension CoverArt.Genre {
    /// Accent names (`Palette.accent`) the genre's sleeves are coloured from.
    var hues: [String] {
        switch self {
        case .nursery: return ["amber", "coral", "sky"]
        case .folk: return ["amber", "mint", "coral"]
        case .classical: return ["violet", "sky"]
        case .americana: return ["coral", "sky", "amber"]
        case .holiday: return ["coral", "mint", "amber"]
        case .swing: return ["violet", "amber", "coral"]
        case .rock: return ["coral", "amber", "violet"]
        case .anthem: return ["sky", "violet", "mint"]
        }
    }

    var motifs: [CoverArt.Motif] {
        switch self {
        case .nursery: return [.sparkle, .grid, .sunset]
        case .folk: return [.ridges, .waveform, .sunset]
        case .classical: return [.orbits, .contour, .grid]
        case .americana: return [.sunset, .stripes, .ridges]
        case .holiday: return [.sparkle, .orbits, .grid]
        case .swing: return [.grid, .orbits, .stripes]
        case .rock: return [.stripes, .sunset, .waveform]
        case .anthem: return [.contour, .waveform, .sparkle]
        }
    }

    /// Classical and anthem sleeves stay dark.
    var allowsField: Bool { self != .classical && self != .anthem }

    /// Rock, anthem and americana titles are always in capitals, classical never; the rest now and then.
    var capitals: Bool? {
        switch self {
        case .rock, .anthem, .americana: return true
        case .classical: return false
        default: return nil
        }
    }
}

private struct MotifInk {
    let main: Color
    let second: Color
    let line: Color
}

/// The sleeve motifs, each drawn to fit the region the type leaves (some run to the sleeve's edges).
private enum Motifs {
    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    static func value(_ random: inout SystemRandom) -> CGFloat { CGFloat(random.next()) }

    static func segment(_ from: CGPoint, _ to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }

    /// A sun going down behind the horizon, its lower half cut into bands, its reflection under the line.
    static func sunset(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let horizon = region.maxY - unit * 0.14
        let radius = max(4, min(region.width * 0.36, (horizon - region.minY) / 1.12))
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.3, y: horizon - radius * 0.12)
        context.fill(circle(center, radius * 1.7),
                     with: .radialGradient(Gradient(colors: [ink.main.opacity(0.3), ink.main.opacity(0)]),
                                           center: center, startRadius: radius * 0.6, endRadius: radius * 1.7))
        var sun = context
        sun.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)))
        sun.clip(to: circle(center, radius))
        let top = center.y - radius
        sun.fill(Path(CGRect(x: center.x - radius, y: top, width: radius * 2, height: radius)),
                 with: .linearGradient(Gradient(colors: [ink.second, ink.main]),
                                       startPoint: CGPoint(x: center.x, y: top), endPoint: center))
        var y = center.y
        var band = radius * 0.2
        var gap = radius * 0.05
        while y < horizon {
            sun.fill(Path(CGRect(x: center.x - radius, y: y, width: radius * 2, height: band)), with: .color(ink.main))
            y += band + gap
            band = max(radius * 0.05, band * 0.78)
            gap *= 1.3
        }
        let weight = max(1, unit * 0.012)
        context.stroke(segment(CGPoint(x: 0, y: horizon), CGPoint(x: size.width, y: horizon)),
                       with: .color(ink.line.opacity(0.4)), lineWidth: weight)
        for ripple in 1...4 {
            let level = horizon + CGFloat(ripple) * unit * 0.032
            let half = radius * (1 - 0.2 * CGFloat(ripple))
            context.stroke(segment(CGPoint(x: center.x - half, y: level), CGPoint(x: center.x + half, y: level)),
                           with: .color(ink.main.opacity(0.55 - 0.1 * Double(ripple))),
                           style: StrokeStyle(lineWidth: weight * 1.4, lineCap: .round))
        }
    }

    /// A sound wave across the sleeve: rounded bars under a swelling envelope, a few in the second colour.
    static func waveform(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let count = 22 + Int(random.next() * 10)
        let left = size.width * 0.08
        let step = size.width * 0.84 / CGFloat(count)
        let bar = step * 0.56
        let middle = region.midY
        let tallest = region.height * 0.92
        let accent = Int(random.next() * Double(count))
        context.stroke(segment(CGPoint(x: 0, y: middle), CGPoint(x: size.width, y: middle)), with: .color(ink.line.opacity(0.14)), lineWidth: 1)
        for i in 0..<count {
            let t = Double(i) / Double(max(1, count - 1))
            let envelope = pow(max(0, sin(Double.pi * t)), 0.6)
            let height = max(bar, tallest * CGFloat(envelope * (0.25 + 0.75 * random.next())))
            let rect = CGRect(x: left + step * (CGFloat(i) + 0.5) - bar / 2, y: middle - height / 2, width: bar, height: height)
            let lit = abs(i - accent) <= 1
            context.fill(Path(roundedRect: rect, cornerRadius: bar / 2), with: .color(lit ? ink.second : ink.main))
        }
    }

    /// Orbits round a bright core, one lit arc and two planets.
    static func orbits(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.25, y: region.midY)
        let rings = 5
        let reach = unit * 0.5
        for k in 1...(rings + 2) {
            let radius = reach * CGFloat(k) / CGFloat(rings)
            let opacity = k > rings ? 0.06 : (k % 2 == 0 ? 0.26 : 0.12)
            context.stroke(circle(center, radius), with: .color(ink.line.opacity(opacity)), lineWidth: k == rings ? 1.4 : 0.9)
        }
        let from = random.next() * 2 * Double.pi
        var arc = Path()
        arc.addArc(center: center, radius: reach * 0.6, startAngle: .radians(from), endAngle: .radians(from + 1.9), clockwise: false)
        context.stroke(arc, with: .color(ink.main), style: StrokeStyle(lineWidth: max(2, unit * 0.035), lineCap: .round))
        context.fill(circle(center, reach * 0.22), with: .color(ink.main))
        for planet in 0..<2 {
            let orbit = reach * (planet == 0 ? 0.8 : 0.4)
            let angle = random.next() * 2 * Double.pi
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * orbit, y: center.y + CGFloat(sin(angle)) * orbit)
            context.fill(circle(point, unit * (planet == 0 ? 0.06 : 0.035)), with: .color(planet == 0 ? ink.second : ink.line.opacity(0.85)))
        }
    }

    /// A Bauhaus grid: discs, rings, half discs and quarter circles.
    static func grid(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let columns = 4
        let cell = max(4, min(region.width * 0.92 / CGFloat(columns), region.height / 2))
        let rows = max(2, min(4, Int(region.height / cell)))
        let origin = CGPoint(x: region.midX - cell * CGFloat(columns) / 2, y: region.midY - cell * CGFloat(rows) / 2)
        for row in 0..<rows {
            for column in 0..<columns {
                let box = CGRect(x: origin.x + CGFloat(column) * cell, y: origin.y + CGFloat(row) * cell, width: cell, height: cell)
                    .insetBy(dx: cell * 0.08, dy: cell * 0.08)
                tile(&context, box: box, kind: Int(random.next() * 6), turn: Int(random.next() * 4) % 4, ink: ink)
            }
        }
    }

    private static func tile(_ context: inout GraphicsContext, box: CGRect, kind: Int, turn: Int, ink: MotifInk) {
        let center = CGPoint(x: box.midX, y: box.midY)
        let radius = box.width / 2
        switch kind {
        case 0, 1:
            context.fill(circle(center, radius), with: .color(ink.main))
        case 2:
            context.stroke(circle(center, radius * 0.94), with: .color(ink.line.opacity(0.4)), lineWidth: max(1, radius * 0.08))
        case 3:
            var half = Path()
            let from = Double(turn) * Double.pi / 2
            half.addArc(center: center, radius: radius, startAngle: .radians(from), endAngle: .radians(from + Double.pi), clockwise: false)
            half.closeSubpath()
            context.fill(half, with: .color(ink.second))
        case 4:
            let corners = [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                           CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)]
            let corner = corners[turn]
            var pie = Path()
            pie.move(to: corner)
            pie.addArc(center: corner, radius: box.width, startAngle: .radians(Double(turn) * Double.pi / 2),
                       endAngle: .radians(Double(turn + 1) * Double.pi / 2), clockwise: false)
            pie.closeSubpath()
            context.fill(pie, with: .color(ink.main.opacity(0.85)))
        default:
            context.fill(circle(center, radius * 0.18), with: .color(ink.line.opacity(0.5)))
        }
    }

    /// Mountain ridges, far to near, under a moon.
    static func ridges(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let moonRadius = unit * 0.13
        let moon = CGPoint(x: region.minX + region.width * (0.2 + 0.6 * value(&random)), y: region.minY + moonRadius * 1.4)
        context.fill(circle(moon, moonRadius), with: .color(ink.second))
        let peaks = 9
        for layer in 0..<3 {
            let base = region.minY + region.height * (0.45 + 0.2 * CGFloat(layer))
            let amplitude = region.height * (0.3 - 0.06 * CGFloat(layer))
            var crest: [CGPoint] = []
            for i in 0...peaks {
                let lift = (i % 2 == 0 ? 0.35 : 1) * value(&random)
                crest.append(CGPoint(x: size.width * CGFloat(i) / CGFloat(peaks), y: base - amplitude * lift))
            }
            var ridge = Path()
            ridge.move(to: CGPoint(x: 0, y: size.height))
            for point in crest { ridge.addLine(to: point) }
            ridge.addLine(to: CGPoint(x: size.width, y: size.height))
            ridge.closeSubpath()
            context.fill(ridge, with: .color(ink.main.opacity(0.4 + 0.25 * Double(layer))))
            var line = Path()
            line.addLines(crest)
            context.stroke(line, with: .color(ink.line.opacity(0.28)), lineWidth: 1)
        }
    }

    /// Bold diagonal bands seen through a round window.
    static func stripes(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.3, y: region.midY)
        let radius = unit * 0.48
        context.stroke(circle(center, radius + unit * 0.05), with: .color(ink.line.opacity(0.2)), lineWidth: 1)
        var window = context
        window.clip(to: circle(center, radius))
        window.fill(circle(center, radius), with: .color(ink.line.opacity(0.06)))
        window.translateBy(x: center.x, y: center.y)
        window.rotate(by: .degrees(-(28 + 30 * random.next())))
        let band = radius * 0.32
        let colors = [ink.main, ink.second, ink.line.opacity(0.85), ink.main.opacity(0.55)]
        let reach = hypot(size.width, size.height)
        for i in 0..<colors.count {
            let y = (CGFloat(i) - CGFloat(colors.count) / 2) * band * 1.2
            window.fill(Path(CGRect(x: -reach, y: y, width: reach * 2, height: band)), with: .color(colors[i]))
        }
    }

    /// A four-point star with smaller ones scattered round it.
    static func sparkle(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.3, y: region.midY)
        context.fill(circle(center, unit * 0.36),
                     with: .radialGradient(Gradient(colors: [ink.main.opacity(0.35), ink.main.opacity(0)]),
                                           center: center, startRadius: 0, endRadius: unit * 0.36))
        context.fill(star(center, unit * 0.46), with: .color(ink.main))
        for _ in 0..<8 {
            let point = CGPoint(x: region.minX + value(&random) * region.width, y: region.minY + value(&random) * region.height)
            let radius = unit * (0.04 + 0.07 * value(&random))
            let light = random.next() < 0.5
            guard hypot(point.x - center.x, point.y - center.y) > unit * 0.32 else { continue }
            context.fill(star(point, radius), with: .color(light ? ink.second : ink.line.opacity(0.8)))
        }
    }

    /// A four-point star with curved sides.
    static func star(_ center: CGPoint, _ radius: CGFloat) -> Path {
        let inner = radius * 0.16
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + inner, y: center.y - inner))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + inner, y: center.y + inner))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - inner, y: center.y + inner))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - inner, y: center.y - inner))
        path.closeSubpath()
        return path
    }

    /// Contour lines round a filled core, every third one in the second colour.
    static func contour(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.3, y: region.midY)
        let p1 = random.next() * 6.28
        let p2 = random.next() * 6.28
        let p3 = random.next() * 6.28
        for k in stride(from: 8, through: 1, by: -1) {
            let base = unit * 0.07 * CGFloat(k)
            var loop = Path()
            let steps = 72
            for s in 0...steps {
                let theta = Double(s) / Double(steps) * 2 * Double.pi
                let wobble = 1 + 0.09 * sin(3 * theta + p1) + 0.05 * sin(5 * theta + p2 + Double(k) * 0.3) + 0.04 * sin(2 * theta + p3)
                let point = CGPoint(x: center.x + CGFloat(cos(theta) * wobble) * base, y: center.y + CGFloat(sin(theta) * wobble) * base)
                if s == 0 { loop.move(to: point) } else { loop.addLine(to: point) }
            }
            loop.closeSubpath()
            if k == 1 { context.fill(loop, with: .color(ink.main)) }
            let featured = k % 3 == 0
            context.stroke(loop, with: .color(featured ? ink.second.opacity(0.9) : ink.line.opacity(0.3 - 0.02 * Double(k))),
                           lineWidth: featured ? max(1.4, unit * 0.014) : 1)
        }
    }

    /// A fine print grain over the whole sleeve.
    static func grain(_ context: inout GraphicsContext, size: CGSize, random: inout SystemRandom) {
        let dot = max(0.6, min(size.width, size.height) * 0.006)
        for i in 0..<140 {
            let rect = CGRect(x: value(&random) * size.width, y: value(&random) * size.height, width: dot, height: dot)
            context.fill(Path(rect), with: .color(i % 2 == 0 ? Color.white.opacity(0.07) : Color.black.opacity(0.1)))
        }
    }
}

/// A song's sleeve, drawn from its `CoverArt`: gradient, glow, motif, the course and title in Sora with a catalogue
/// number, and a sheen. A song not reached yet dims under a lock in the sleeve's free corner.
struct SongCover: View {
    let art: CoverArt
    var corner: CGFloat = 14
    /// The type on the sleeve; off for a backdrop made from it.
    var titled = true
    /// Not reached yet: the sleeve dims and a lock sits in its free corner.
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
        let layout = SleeveLayout(art: art, size: size, titled: titled)
        let region = layout.region
        let art = self.art
        return ZStack {
            LinearGradient(colors: [art.deep, art.far], startPoint: art.start, endPoint: art.end)
            glow(side: layout.side)
                .position(x: size.width * art.glow.x, y: size.height * art.glow.y)
            Canvas { context, canvasSize in art.draw(in: &context, size: canvasSize, region: region) }
            if titled {
                typeBlock(layout)
                catalogue(layout)
            }
            LinearGradient(colors: [.white.opacity(art.field ? 0.18 : 0.12), .clear], startPoint: .topLeading, endPoint: .center)
            if locked { lock }
        }
        .frame(width: size.width, height: size.height)
    }

    /// The course over the title, in the corner the layout gives them.
    private func typeBlock(_ layout: SleeveLayout) -> some View {
        let points = layout.fit.points
        let block = VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: art.label)
                .font(.custom("Sora-SemiBold", fixedSize: layout.labelSize))
                .tracking(layout.labelSize * 0.16)
                .foregroundStyle(art.ink.opacity(0.72))
                .lineLimit(1)
                .padding(.bottom, layout.labelSize * 0.35)
            VStack(alignment: .leading, spacing: -points * 0.27) {
                ForEach(Array(layout.fit.lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(.custom(TitleFit.font, fixedSize: points))
                        .tracking(-points * 0.02)
                        .foregroundStyle(art.ink)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .shadow(color: .black.opacity(art.field ? 0 : 0.35), radius: layout.side * 0.03, y: layout.side * 0.01)
        return ZStack(alignment: art.titleOnTop ? .topLeading : .bottomLeading) {
            Color.clear
            block
        }
        .padding(layout.pad)
    }

    /// The catalogue number, small, in the left corner the title leaves free.
    private func catalogue(_ layout: SleeveLayout) -> some View {
        let size = layout.labelSize * 1.05
        return ZStack(alignment: art.titleOnTop ? .bottomLeading : .topLeading) {
            Color.clear
            HStack(spacing: size * 0.4) {
                Capsule().fill(art.ink.opacity(0.5)).frame(width: size * 1.2, height: max(1, size * 0.1))
                Text(verbatim: String(format: "%02d", art.number))
                    .font(.custom("Sora-Medium", fixedSize: size)).monospacedDigit()
                    .foregroundStyle(art.ink.opacity(0.62))
            }
        }
        .padding(layout.pad)
    }

    /// The dim over a song not reached yet, and its lock in the free corner.
    private var lock: some View {
        ZStack(alignment: art.freeCorner) {
            Color.black.opacity(0.5)
            Image(systemName: "lock.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .padding(10)
        }
    }

    private func glow(side: CGFloat) -> some View {
        let tint = art.field ? Color.white.opacity(0.4) : art.primary.opacity(0.6)
        return Circle()
            .fill(RadialGradient(colors: [tint, tint.opacity(0)], center: .center, startRadius: 0, endRadius: side * 0.6))
            .frame(width: side * 1.2, height: side * 1.2)
            .scaleEffect(drifting ? 1.12 : 0.94)
            .offset(x: drifting ? side * 0.1 : -side * 0.04, y: drifting ? -side * 0.06 : side * 0.03)
            .blendMode(.screen)
    }
}

/// Where a sleeve's type goes and at what size, and the room it leaves the motif.
@MainActor private struct SleeveLayout {
    let side: CGFloat
    let pad: CGFloat
    let labelSize: CGFloat
    let fit: TitleFit
    /// The motif's room: the sleeve less its margins and the type block.
    let region: CGRect

    init(art: CoverArt, size: CGSize, titled: Bool) {
        side = max(1, min(size.width, size.height))
        pad = side * 0.075
        labelSize = max(6, side * 0.052)
        let width = max(1, size.width - pad * 2)
        guard titled else {
            fit = TitleFit(lines: [], points: 0)
            region = CGRect(x: pad, y: pad, width: width, height: max(1, size.height - pad * 2))
            return
        }
        fit = TitleFit.make(art.title, width: width, maxHeight: side * 0.4, largest: side * 0.17, smallest: side * 0.075)
        let block = labelSize * 1.26 + labelSize * 0.35 + fit.height
        let gap = side * 0.05
        let room = max(side * 0.2, size.height - pad * 2 - block - gap)
        let top = art.titleOnTop ? pad + block + gap : pad
        region = CGRect(x: pad, y: top, width: width, height: room)
    }
}

/// A sleeve title broken into lines at the largest size (Sora Bold) that fits `width` in at most three lines and
/// `maxHeight`, measured from the glyphs with UIKit. Titles in scripts without spaces (Chinese, Japanese) break
/// between characters; a word too long for the smallest size breaks too. Results are cached per title and width.
struct TitleFit {
    let lines: [String]
    let points: CGFloat

    static let font = "Sora-Bold"
    static let maxLines = 3

    /// The block's height: Sora's line box is 1.26 em, and lines stack 0.99 em apart.
    var height: CGFloat { lines.isEmpty ? 0 : points * (1.26 + 0.99 * CGFloat(lines.count - 1)) }

    @MainActor private static var cache: [String: TitleFit] = [:]

    @MainActor static func make(_ text: String, width: CGFloat, maxHeight: CGFloat, largest: CGFloat, smallest: CGFloat) -> TitleFit {
        let key = "\(text)|\(Int(width.rounded()))|\(Int(maxHeight.rounded()))|\(Int(largest.rounded()))"
        if let hit = cache[key] { return hit }
        let result = compute(text, width: width, maxHeight: maxHeight, largest: largest, smallest: min(smallest, largest))
        if cache.count > 500 { cache.removeAll() }
        cache[key] = result
        return result
    }

    private struct Token {
        let text: String
        /// Set straight after the one before (no space): characters of a CJK word.
        let joined: Bool
    }

    private static func compute(_ text: String, width: CGFloat, maxHeight: CGFloat, largest: CGFloat, smallest: CGFloat) -> TitleFit {
        let words = tokens(text)
        guard !words.isEmpty, width > 4, largest > 1 else { return TitleFit(lines: [], points: 0) }
        var points = largest
        while points > smallest {
            let size = points
            let face = uiFont(size)
            let measure: (String) -> CGFloat = { Self.measure($0, face, size) }
            let lines = wrap(words, width: width, measure: measure)
            let height = size * (1.26 + 0.99 * CGFloat(lines.count - 1))
            if lines.count <= maxLines, height <= maxHeight, lines.allSatisfy({ measure($0) <= width }) {
                return TitleFit(lines: lines, points: size)
            }
            points *= 0.93
        }
        let face = uiFont(smallest)
        let measure: (String) -> CGFloat = { Self.measure($0, face, smallest) }
        let pieces = words.flatMap { split($0, width: width, measure: measure) }
        var lines = wrap(pieces, width: width, measure: measure)
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
            lines[maxLines - 1] += "…"
        }
        return TitleFit(lines: lines, points: smallest)
    }

    private static func uiFont(_ points: CGFloat) -> UIFont {
        UIFont(name: font, size: points) ?? UIFont.systemFont(ofSize: points, weight: .bold)
    }

    private static func measure(_ text: String, _ face: UIFont, _ points: CGFloat) -> CGFloat {
        NSAttributedString(string: text, attributes: [.font: face, .kern: -points * 0.02]).size().width
    }

    private static func tokens(_ text: String) -> [Token] {
        var out: [Token] = []
        for word in text.split(separator: " ") {
            if word.unicodeScalars.contains(where: { $0.properties.isIdeographic || (0x3040...0x30FF).contains($0.value) }) {
                for (i, character) in word.enumerated() { out.append(Token(text: String(character), joined: i > 0)) }
            } else {
                out.append(Token(text: String(word), joined: false))
            }
        }
        return out
    }

    /// Greedy lines: each token goes on the line while it fits.
    private static func wrap(_ tokens: [Token], width: CGFloat, measure: (String) -> CGFloat) -> [String] {
        var lines: [String] = []
        var line = ""
        for token in tokens {
            let candidate = line.isEmpty ? token.text : line + (token.joined ? "" : " ") + token.text
            if line.isEmpty || measure(candidate) <= width {
                line = candidate
            } else {
                lines.append(line)
                line = token.text
            }
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }

    /// A token too wide for a line, broken between characters.
    private static func split(_ token: Token, width: CGFloat, measure: (String) -> CGFloat) -> [Token] {
        guard measure(token.text) > width else { return [token] }
        var pieces: [Token] = []
        var piece = ""
        for character in token.text {
            let next = piece + String(character)
            if !piece.isEmpty && measure(next) > width {
                pieces.append(Token(text: piece, joined: pieces.isEmpty ? token.joined : true))
                piece = String(character)
            } else {
                piece = next
            }
        }
        if !piece.isEmpty { pieces.append(Token(text: piece, joined: pieces.isEmpty ? token.joined : true)) }
        return pieces
    }
}

/// The record behind the featured sleeve: grooves, a label in the song's colour, and two glints that turn while
/// its preview plays (33⅓ rpm).
struct VinylRecord: View {
    let color: Color
    let spinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !spinning)) { timeline in
            let turn = spinning ? timeline.date.timeIntervalSinceReferenceDate * 200 : 20
            Canvas { context, size in Self.draw(&context, size: size, degrees: turn, color: color) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func draw(_ context: inout GraphicsContext, size: CGSize, degrees: Double, color: Color) {
        let radius = min(size.width, size.height) / 2
        guard radius > 2 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func disc(_ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)) }
        context.fill(disc(radius), with: .color(Color(hex: 0x0B0C0E)))
        for k in 0..<9 {
            context.stroke(disc(radius * (0.42 + 0.06 * CGFloat(k))), with: .color(.white.opacity(0.05)), lineWidth: 0.7)
        }
        for k in 0..<2 {
            let from = (degrees + Double(k) * 180) * Double.pi / 180
            var glint = Path()
            glint.addArc(center: center, radius: radius * 0.72, startAngle: .radians(from), endAngle: .radians(from + 0.6), clockwise: false)
            context.stroke(glint, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: radius * 0.42, lineCap: .butt))
        }
        context.stroke(disc(radius - 0.5), with: .color(.white.opacity(0.14)), lineWidth: 1)
        context.fill(disc(radius * 0.34), with: .color(color))
        context.fill(disc(radius * 0.04), with: .color(.black))
    }
}
