import SwiftUI
import TimbreCore
import UIKit

/// Generative single-sleeve art for a song, so a shelf of songs reads like a rack of records with no image assets.
/// Everything comes from the song: its id seeds the colours and the type (a song always wears the same sleeve), its
/// unit gives it a genre (a palette, a family of motifs, a typeface), its course stands in for the artist, and its
/// title is set in Sora. A sleeve is either dark (a deep gradient, the motif in the song's colours, light type) or,
/// now and then, a bright colour field with the motif and the type in ink.
///
/// Motifs are dealt along each course in turn (`assignedMotif`) from one of two sets of twelve: the Originals' own
/// (waveforms, grids, spirals, a synthwave horizon…) and the traditional tunes' (suns, ridges, moons, rosettes…). So
/// the Song of the Day, an Original for anyone past the first steps, never wears the motif of the paywall's sleeve (a
/// song from an instrument's course). A sleeve skips any motif of the last eight its course dealt and the family
/// (`Motif.family`: suns, skies, rings…) of the two before it, so a course's shelf never shows a motif twice within
/// nine sleeves and neighbours never look alike; the picked shelves keep each motif once (`SongsCatalog`). The type
/// is set in one of four weights.
///
/// Every sleeve keeps one grid, so the controls on it never move or collide: the bottom-right corner (`playCorner`)
/// is clear for "Hear it" (or a badge). The title sits at the top (left, centred or right), or, when short, at the foot
/// on the left, stopping short of the play corner (now and then on a band of colour). How a sleeve credits itself
/// varies (`Imprint`): a catalogue rule and number over the course in spaced capitals, a number in the top corner over
/// the course as written, the course alone, or the title alone, so a shelf never reads as one template run many times.
struct CoverArt {
    enum Genre: CaseIterable { case nursery, folk, classical, americana, holiday, swing, rock, anthem }
    enum Motif: CaseIterable {
        case sunset, waveform, orbits, grid, ridges, stripes, sparkle, contour
        case dial, halftone, rays, blocks, rosette, keys, horizon, strings
        case arches, moon, checker, spiral, equalizer, petals, constellation, waves
    }
    /// Motifs that read alike at a glance (a sun low on the sleeve, rings round a centre, a field of bars): two
    /// sleeves side by side never share one.
    enum Family { case sun, land, sky, radial, sound, geometry, lines, dots }
    /// How the title lines up across the sleeve.
    enum Align { case leading, center, trailing }
    /// How the sleeve credits itself.
    enum Imprint {
        /// A rule and the catalogue number top-left, the course over the title in spaced capitals.
        case catalogue
        /// The number alone in the top-right corner, the course over the title as it is written.
        case corner
        /// No number: the course over the title as it is written.
        case credit
        /// The title alone.
        case plain

        /// The catalogue number is drawn.
        var numbered: Bool { self == .catalogue || self == .corner }
        /// The course's line over the title is drawn.
        var credited: Bool { self != .plain }
    }

    let seed: UInt64
    let genre: Genre
    let motif: Motif
    /// The motif's colour and the one it plays against.
    let primary: Color
    let secondary: Color
    /// A bright colour field with ink type and motif, rather than a dark sleeve.
    let field: Bool
    /// The title sits at the top (the motif below it), else at the foot (the motif above).
    let titleOnTop: Bool
    let align: Align
    /// The title sits on a band of the song's colour across the foot of the sleeve.
    let banner: Bool
    /// The title's Sora face.
    let face: String
    /// How the sleeve credits itself.
    let imprint: Imprint
    /// The title as set on the sleeve: the main title (no subtitle), in capitals for some genres.
    let title: String
    /// The small line over the title: the course, as the artist, as written (a `catalogue` imprint sets it in capitals).
    let label: String
    /// The song's place in its course, as a catalogue number.
    let number: Int
    /// Gradient direction in degrees.
    let angle: Double
    /// Where the glow sits, as a fraction of the sleeve.
    let glow: UnitPoint

    /// `title` is the title as shown, so the sleeve matches it in every language. `motif` is the one its course dealt
    /// it (`assignedMotif`); without it the sleeve takes its turn in its genre's motifs by `number`.
    init(id: String, title: String, accent: String, genre: Genre, label: String, number: Int, motif: Motif? = nil) {
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
        _ = random.next()
        let chosen = motif ?? Self.turn(id: id, number: number, genre: genre)
        self.motif = chosen
        let fieldRoll = random.next()
        field = genre.allowsField && chosen.allowsField && fieldRoll < 0.28
        let coin = random.next() < 0.5
        let main = Self.mainTitle(title)
        // A sun, a horizon or ridges sit low, so their title goes on top; so does a long title, which needs the
        // sleeve's whole width (a title at the foot stops short of the play corner).
        titleOnTop = chosen.sitsLow || main.count > Self.footTitleLimit || coin
        let capitalRoll = random.next()
        let capitals = genre.capitals ?? (capitalRoll < 0.25)
        self.title = capitals ? main.uppercased() : main
        self.label = label
        self.number = number
        angle = 200 + 140 * random.next()
        glow = UnitPoint(x: CGFloat(0.2 + 0.6 * random.next()), y: CGFloat(0.12 + 0.5 * random.next()))
        let alignRoll = random.next()
        let rolled: Align = alignRoll < 0.56 ? .leading : alignRoll < 0.8 ? .trailing : .center
        // A title at the foot keeps to the left of the play corner.
        align = titleOnTop ? rolled : .leading
        let bannerRoll = random.next()
        banner = !field && !titleOnTop && bannerRoll < 0.3
        let faces = genre.faces(short: main.count <= 16)
        face = faces[Self.index(random.next(), faces.count)]
        // Its own roll, after every other, so the rest of the sleeve is drawn as it always was.
        imprint = genre.imprint(Double(Self.hash(id, salt: Self.imprintSalt) % 1000) / 1000)
    }

    /// Seeds the imprint's roll apart from the sleeve's other choices.
    private static let imprintSalt: UInt64 = 53

    private static func index(_ value: Double, _ count: Int) -> Int { min(max(0, count - 1), Int(value * Double(count))) }

    /// A sleeve's turn in its genre's motifs without its course's deal: the course (the id's prefix) sets where the
    /// count starts, so songs of different courses with the same number don't match.
    private static func turn(id: String, number: Int, genre: Genre) -> Motif {
        let list = genre.motifs
        let prefix = id.split(separator: "-").first.map(String.init) ?? id
        let start = Int(hash(prefix, salt: dealSalt) % UInt64(list.count))
        return list[(max(0, number - 1) + start) % list.count]
    }

    /// Tunes where each course's deal starts, so the mixed "3 chords or fewer" shelf repeats as little as it can.
    private static let dealSalt: UInt64 = 181

    /// The Originals' motifs: a modern catalogue's (sound, print and geometry, one synthwave sun).
    static let originalsMotifs: [Motif] = [.horizon, .waveform, .dial, .equalizer, .halftone, .contour,
                                           .spiral, .grid, .checker, .blocks, .constellation, .arches]
    /// Every other song's: the traditional tunes' (suns and skies, land and sea, rosettes, strings and keys). No
    /// motif is in both sets.
    static let heritageMotifs: [Motif] = [.sunset, .rays, .ridges, .waves, .sparkle, .moon,
                                          .rosette, .petals, .orbits, .stripes, .strings, .keys]
    /// A sleeve passes over the motifs of this many sleeves before it in its course.
    private static let dealWindow = 8

    /// The motif a course deals its song `lessonId`: song by song in course order, from its set (`originalsMotifs`
    /// or `heritageMotifs`) in its unit's genre's order of preference, each takes its turn (`deal`). Nil for a lesson
    /// that isn't one of the course's songs.
    static func assignedMotif(_ lessonId: String, in course: LearnCourse) -> Motif? {
        let pool = SongOfTheDay.isOriginals(course) ? originalsMotifs : heritageMotifs
        var recent: [Motif] = []
        var number = 0
        let start = Int(hash(course.id, salt: dealSalt) % UInt64(pool.count))
        for unit in course.units {
            let preferred = genre(unit: unit.title.defaultValue, instrument: course.instrument).motifs
            // The genre's favourites from the set first, then the rest of the set: all twelve, in order.
            let list = preferred.filter { pool.contains($0) } + pool.filter { !preferred.contains($0) }
            for lesson in unit.lessons where lesson.kind == .song {
                number += 1
                let pick = deal(list, from: (number - 1 + start) % list.count, after: recent)
                if lesson.id == lessonId { return pick }
                recent.append(pick)
                if recent.count > dealWindow { recent.removeFirst() }
            }
        }
        return nil
    }

    /// From `list[first]` on, the first motif none of the `recent` sleeves wore whose family differs from the last
    /// two's; failing that, the first none of them wore; failing that, `list[first]`.
    private static func deal(_ list: [Motif], from first: Int, after recent: [Motif]) -> Motif {
        let near = recent.suffix(2).map { $0.family }
        var fallback: Motif?
        for step in 0..<list.count {
            let candidate = list[(first + step) % list.count]
            guard !recent.contains(candidate) else { continue }
            if !near.contains(candidate.family) { return candidate }
            if fallback == nil { fallback = candidate }
        }
        return fallback ?? list[first]
    }

    // MARK: Colour

    /// The sleeve's gradient ends.
    var deep: Color { field ? primary.mix(with: .white, by: 0.08) : primary.mix(with: .black, by: 0.62) }
    var far: Color { field ? primary.mix(with: secondary, by: 0.35).mix(with: .black, by: 0.16) : secondary.mix(with: .black, by: 0.8) }
    /// Type: light on a dark sleeve, ink on a colour field or a band.
    var ink: Color { field || banner ? Palette.stage : Palette.ink }
    var start: UnitPoint {
        let radians = angle * Double.pi / 180
        return UnitPoint(x: CGFloat(0.5 - 0.5 * cos(radians)), y: CGFloat(0.5 - 0.5 * sin(radians)))
    }
    var end: UnitPoint { UnitPoint(x: 1 - start.x, y: 1 - start.y) }
    /// The play corner, clear of the title on every sleeve: where "Hear it", a badge or a lock goes.
    var freeCorner: Alignment { .bottomTrailing }
    /// The share of the side kept clear of type at the bottom-right: room for a 32 to 38 pt "Hear it" disc in its
    /// 44 pt tap area on a 124 to 176 pt sleeve.
    static let playCorner: CGFloat = 0.34
    /// The longest title (in characters) set at the foot, where it has the sleeve's width less the play corner.
    static let footTitleLimit = 16

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
        let ground = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [deep, far]),
            startPoint: CGPoint(x: start.x * size.width, y: start.y * size.height),
            endPoint: CGPoint(x: end.x * size.width, y: end.y * size.height))
        let ink = MotifInk(main: field ? Palette.stage : primary,
                           second: field ? Color.white : secondary,
                           line: field ? Color.black : Color.white,
                           ground: ground)
        switch motif {
        case .sunset: Motifs.sunset(&context, size: size, region: region, ink: ink, random: &random)
        case .waveform: Motifs.waveform(&context, size: size, region: region, ink: ink, random: &random)
        case .orbits: Motifs.orbits(&context, region: region, ink: ink, random: &random)
        case .grid: Motifs.grid(&context, region: region, ink: ink, random: &random)
        case .ridges: Motifs.ridges(&context, size: size, region: region, ink: ink, random: &random)
        case .stripes: Motifs.stripes(&context, size: size, region: region, ink: ink, random: &random)
        case .sparkle: Motifs.sparkle(&context, region: region, ink: ink, random: &random)
        case .contour: Motifs.contour(&context, region: region, ink: ink, random: &random)
        case .dial: Motifs.dial(&context, region: region, ink: ink, random: &random)
        case .halftone: Motifs.halftone(&context, region: region, ink: ink, random: &random)
        case .rays: Motifs.rays(&context, size: size, region: region, ink: ink, random: &random)
        case .blocks: Motifs.blocks(&context, region: region, ink: ink, random: &random)
        case .rosette: Motifs.rosette(&context, region: region, ink: ink, random: &random)
        case .keys: Motifs.keys(&context, region: region, ink: ink, random: &random)
        case .horizon: Motifs.horizon(&context, size: size, region: region, ink: ink, random: &random)
        case .strings: Motifs.strings(&context, size: size, region: region, ink: ink, random: &random)
        case .arches: Motifs.arches(&context, region: region, ink: ink, random: &random)
        case .moon: Motifs.moon(&context, region: region, ink: ink, random: &random)
        case .checker: Motifs.checker(&context, region: region, ink: ink, random: &random)
        case .spiral: Motifs.spiral(&context, region: region, ink: ink, random: &random)
        case .equalizer: Motifs.equalizer(&context, region: region, ink: ink, random: &random)
        case .petals: Motifs.petals(&context, region: region, ink: ink, random: &random)
        case .constellation: Motifs.constellation(&context, region: region, ink: ink, random: &random)
        case .waves: Motifs.waves(&context, size: size, region: region, ink: ink, random: &random)
        }
        Motifs.grain(&context, size: size, random: &random)
    }
}

extension CoverArt.Motif {
    /// Drawn low in its room (a sun or a grid on the horizon, ridges, a rainbow, waves, a dial's arc), so the title goes
    /// above it.
    var sitsLow: Bool { self == .sunset || self == .ridges || self == .horizon || self == .arches || self == .waves || self == .dial }
    /// Piano keys need a dark sleeve to read as keys.
    var allowsField: Bool { self != .keys }

    /// What it reads as at a glance: neighbouring sleeves never share a family (`CoverArt.assignedMotif`).
    var family: CoverArt.Family {
        switch self {
        case .sunset, .rays, .horizon, .arches: return .sun
        case .ridges, .waves: return .land
        case .sparkle, .moon, .constellation: return .sky
        case .orbits, .contour, .rosette, .spiral, .petals: return .radial
        case .waveform, .dial, .equalizer: return .sound
        case .grid, .blocks, .checker: return .geometry
        case .stripes, .strings, .keys: return .lines
        case .halftone: return .dots
        }
    }
}

private extension CoverArt.Genre {
    /// Course hues (`Palette.accent`) the genre's sleeves are coloured from: never a status colour.
    var hues: [String] {
        switch self {
        case .nursery: return ["orchid", "lime", "sky"]
        case .folk: return ["orchid", "mint", "lime"]
        case .classical: return ["violet", "sky"]
        case .americana: return ["lime", "sky", "orchid"]
        case .holiday: return ["lime", "mint", "orchid"]
        case .swing: return ["violet", "orchid", "lime"]
        case .rock: return ["lime", "orchid", "violet"]
        case .anthem: return ["sky", "violet", "mint"]
        }
    }

    /// How a sleeve of the genre credits itself, from a roll in 0..<1: classical sleeves mostly by the course as
    /// written, rock and anthem by the catalogue rule or the title alone, the rest a mix.
    func imprint(_ roll: Double) -> CoverArt.Imprint {
        switch self {
        case .classical: return roll < 0.6 ? .credit : roll < 0.85 ? .corner : .plain
        case .rock, .anthem: return roll < 0.45 ? .catalogue : roll < 0.75 ? .plain : .corner
        default: return roll < 0.3 ? .catalogue : roll < 0.55 ? .corner : roll < 0.8 ? .credit : .plain
        }
    }

    /// Twelve motifs per genre, its favourites first, from both sets (`CoverArt.originalsMotifs`, `heritageMotifs`):
    /// a course deals those of its set in this order, then the rest of the set; a sleeve without a deal takes its turn
    /// in the whole list.
    var motifs: [CoverArt.Motif] {
        switch self {
        case .nursery: return [.sparkle, .moon, .petals, .arches, .constellation, .checker, .halftone, .grid, .waves, .orbits, .keys, .rays]
        case .folk: return [.ridges, .strings, .waves, .waveform, .petals, .halftone, .contour, .moon, .arches, .spiral, .sunset, .blocks]
        case .classical: return [.rosette, .keys, .orbits, .moon, .contour, .spiral, .petals, .halftone, .constellation, .grid, .strings, .sparkle]
        case .americana: return [.rays, .strings, .ridges, .stripes, .waves, .halftone, .arches, .checker, .blocks, .sunset, .moon, .waveform]
        case .holiday: return [.sparkle, .constellation, .rosette, .petals, .moon, .orbits, .checker, .grid, .halftone, .keys, .rays, .blocks]
        case .swing: return [.keys, .equalizer, .checker, .stripes, .grid, .blocks, .spiral, .orbits, .dial, .halftone, .moon, .rays]
        case .rock: return [.horizon, .equalizer, .checker, .stripes, .dial, .waveform, .blocks, .spiral, .strings, .rays, .halftone, .sunset]
        case .anthem: return [.horizon, .arches, .contour, .dial, .constellation, .equalizer, .waveform, .spiral, .sparkle, .orbits, .halftone, .rays]
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

    /// The faces its titles are set in: classical in Sora Light when the title is short enough to be set large,
    /// swing in Medium, rock and anthem always Bold.
    func faces(short: Bool) -> [String] {
        switch self {
        case .classical: return short ? ["Sora-Light", "Sora-Light", "Sora-SemiBold"] : ["Sora-SemiBold"]
        case .swing: return ["Sora-Medium", "Sora-Bold"]
        case .rock, .anthem: return ["Sora-Bold"]
        case .americana: return ["Sora-Bold", "Sora-SemiBold"]
        case .nursery, .folk, .holiday: return ["Sora-Bold", "Sora-SemiBold", "Sora-Medium"]
        }
    }
}

private struct MotifInk {
    let main: Color
    let second: Color
    let line: Color
    /// The sleeve's own gradient, to hide what lies behind a shape.
    let ground: GraphicsContext.Shading
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

    /// A radio's tuning dial: a fan of ticks along a wide arc, every fifth one long, a few stations marked in the
    /// second colour, and the needle, in the song's colour, resting on one of them.
    static func dial(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let pivot = CGPoint(x: region.midX, y: region.maxY - unit * 0.04)
        let radius = min(region.width * 0.47, region.height * 0.9)
        let weight = max(1, unit * 0.012)
        let ticks = 41
        // Degrees from the right, counterclockwise: the arc spans 25 to 155, left to right as i grows.
        func angle(_ i: Int) -> Double { (155 - 130 * Double(i) / Double(ticks - 1)) * Double.pi / 180 }
        func point(_ i: Int, _ length: CGFloat) -> CGPoint {
            CGPoint(x: pivot.x + CGFloat(cos(angle(i))) * length, y: pivot.y - CGFloat(sin(angle(i))) * length)
        }
        var stations: [Int] = []
        for _ in 0..<3 { stations.append(3 + Int(random.next() * Double(ticks - 6))) }
        var band = Path()
        for i in 0..<ticks {
            if i == 0 { band.move(to: point(i, radius * 0.72)) } else { band.addLine(to: point(i, radius * 0.72)) }
        }
        context.stroke(band, with: .color(ink.line.opacity(0.25)), lineWidth: weight)
        for i in 0..<ticks {
            let long = i % 5 == 0
            let station = stations.contains(i)
            let color = station ? ink.second : ink.line.opacity(long ? 0.7 : 0.35)
            context.stroke(segment(point(i, radius * (long ? 0.78 : 0.86)), point(i, radius)), with: .color(color),
                           style: StrokeStyle(lineWidth: station ? weight * 2 : weight, lineCap: .round))
        }
        let tuned = stations[Int(random.next() * Double(stations.count)) % stations.count]
        context.stroke(segment(pivot, point(tuned, radius * 1.04)), with: .color(ink.main),
                       style: StrokeStyle(lineWidth: weight * 2.4, lineCap: .round))
        context.fill(circle(pivot, unit * 0.07), with: .color(ink.main))
        context.fill(circle(pivot, unit * 0.025), with: ink.ground)
    }

    /// A sphere in halftone, its dots swelling toward the light, ringed by one orbit in the second colour.
    static func halftone(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let radius = unit * 0.44
        let room = max(0, region.width - radius * 2)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * room * 0.8, y: region.midY)
        // Light from the upper left (a unit vector).
        let light = (x: -0.52, y: -0.58, z: 0.63)
        let step = max(2.5, radius * 2 / 15)
        var y = center.y - radius + step / 2
        var row = 0
        while y < center.y + radius {
            var x = center.x - radius + step / 2 + (row % 2 == 0 ? 0 : step / 2)
            while x < center.x + radius {
                let dx = Double((x - center.x) / radius)
                let dy = Double((y - center.y) / radius)
                let squared = dx * dx + dy * dy
                if squared < 1 {
                    let dz = (1 - squared).squareRoot()
                    let shade = max(0, dx * light.x + dy * light.y + dz * light.z)
                    let dot = step * 0.5 * CGFloat(0.12 + 0.88 * shade)
                    context.fill(circle(CGPoint(x: x, y: y), dot), with: .color(ink.main))
                }
                x += step
            }
            y += step
            row += 1
        }
        var ring = context
        ring.translateBy(x: center.x, y: center.y)
        ring.rotate(by: .degrees(-14 - 12 * random.next()))
        ring.stroke(Path(ellipseIn: CGRect(x: -radius * 1.32, y: -radius * 0.3, width: radius * 2.64, height: radius * 0.6)),
                    with: .color(ink.second.opacity(0.9)), lineWidth: max(1.2, unit * 0.016))
    }

    /// A sunburst from the foot of the motif: alternating rays, fading as they go, a half sun at their source.
    static func rays(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let origin = CGPoint(x: region.minX + region.width * (0.3 + 0.4 * value(&random)), y: region.maxY)
        let reach = hypot(region.width, region.height) * 1.2
        let count = 18
        let turn = random.next() * Double.pi / Double(count)
        var burst = context
        burst.clip(to: Path(CGRect(x: 0, y: region.minY, width: size.width, height: region.height)))
        let fade = GraphicsContext.Shading.radialGradient(Gradient(colors: [ink.main.opacity(0.9), ink.main.opacity(0.08)]),
                                                         center: origin, startRadius: unit * 0.1, endRadius: reach * 0.8)
        for i in stride(from: 0, to: count, by: 2) {
            let from = Double.pi + turn + Double(i) / Double(count) * Double.pi
            let to = from + Double.pi / Double(count)
            var wedge = Path()
            wedge.move(to: origin)
            wedge.addLine(to: CGPoint(x: origin.x + CGFloat(cos(from)) * reach, y: origin.y + CGFloat(sin(from)) * reach))
            wedge.addLine(to: CGPoint(x: origin.x + CGFloat(cos(to)) * reach, y: origin.y + CGFloat(sin(to)) * reach))
            wedge.closeSubpath()
            burst.fill(wedge, with: fade)
        }
        let sun = unit * 0.24
        burst.fill(circle(origin, sun * 1.25), with: ink.ground)
        burst.fill(circle(origin, sun), with: .color(ink.second))
        burst.stroke(circle(origin, sun * 1.25), with: .color(ink.line.opacity(0.35)), lineWidth: 1)
    }

    /// A Swiss composition: a grid of colour blocks, some left open, a disc across one of its joints and a rule.
    static func blocks(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let columns = 3
        let rows = 2
        let gutter = max(1.5, unit * 0.025)
        let width = region.width / CGFloat(columns)
        let height = region.height / CGFloat(rows)
        let fills: [Color?] = [ink.main, ink.second, ink.line.opacity(0.85), ink.main.opacity(0.45), nil, nil]
        var painted = 0
        for row in 0..<rows {
            for column in 0..<columns {
                let box = CGRect(x: region.minX + CGFloat(column) * width, y: region.minY + CGFloat(row) * height, width: width, height: height)
                    .insetBy(dx: gutter / 2, dy: gutter / 2)
                let pick = Int(random.next() * Double(fills.count)) % fills.count
                // At least two blocks take colour, the last ones if the dice didn't.
                let forced = painted < 2 && row * columns + column >= columns * rows - (2 - painted)
                var fill = fills[pick]
                if fill == nil && forced { fill = ink.main }
                if let fill {
                    context.fill(Path(box), with: .color(fill))
                    painted += 1
                } else {
                    context.stroke(Path(box), with: .color(ink.line.opacity(0.18)), lineWidth: 1)
                }
            }
        }
        let joint = CGPoint(x: region.minX + width * CGFloat(1 + Int(random.next() * 2) % 2), y: region.minY + height)
        let disc = min(width, height) * 0.62
        context.fill(circle(joint, disc), with: .color(ink.second))
        context.fill(circle(joint, disc * 0.34), with: ink.ground)
        let ruleY = region.minY + region.height * CGFloat(0.15 + 0.7 * random.next())
        context.stroke(segment(CGPoint(x: region.minX, y: ruleY), CGPoint(x: region.maxX, y: ruleY)),
                       with: .color(ink.line.opacity(0.55)), lineWidth: max(1, unit * 0.01))
    }

    /// A guilloché rosette: three rolling-circle curves laid over one another, one in the song's colour.
    static func rosette(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.25, y: region.midY)
        let outer = Double(unit) * 0.48
        let lobes = 5 + Int(random.next() * 5) % 5
        let roll = Double(lobes - 1)
        let reaches = [2.4, 1.5, 3.2]
        let lit = Int(random.next() * 3) % 3
        for layer in 0..<3 {
            let d = reaches[layer]
            let scale = outer / (roll + d)
            let phase = Double(layer) * Double.pi / Double(lobes)
            var curve = Path()
            let steps = 320
            for s in 0...steps {
                let t = Double(s) / Double(steps) * 2 * Double.pi
                let x = roll * cos(t) + d * cos(roll * t)
                let y = roll * sin(t) - d * sin(roll * t)
                let rx = x * cos(phase) - y * sin(phase)
                let ry = x * sin(phase) + y * cos(phase)
                let point = CGPoint(x: center.x + CGFloat(rx * scale), y: center.y + CGFloat(ry * scale))
                if s == 0 { curve.move(to: point) } else { curve.addLine(to: point) }
            }
            curve.closeSubpath()
            let featured = layer == lit
            context.stroke(curve, with: .color(featured ? ink.main : ink.line.opacity(0.32)),
                           lineWidth: featured ? max(1.3, unit * 0.013) : max(0.7, unit * 0.005))
        }
        context.fill(circle(center, unit * 0.06), with: .color(ink.second))
    }

    /// Piano keys on a slant across the motif's room, three of them lit as a chord.
    static func keys(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        var board = context
        board.clip(to: Path(roundedRect: region, cornerRadius: unit * 0.04))
        board.translateBy(x: region.midX, y: region.midY)
        board.rotate(by: .degrees(-10 - 12 * random.next()))
        let white = max(4, unit * 0.15)
        let length = hypot(region.width, region.height) * 0.62
        let count = Int((hypot(region.width, region.height) / white).rounded(.up)) + 2
        let left = -CGFloat(count) * white / 2
        let octave = Int(random.next() * 7) % 7
        let root = count / 2 - 2 + Int(random.next() * 3) % 3
        let lit: Set<Int> = [root, root + 2, root + 4]
        for i in 0..<count {
            let rect = CGRect(x: left + CGFloat(i) * white + white * 0.04, y: -length / 2, width: white * 0.92, height: length)
            board.fill(Path(roundedRect: rect, cornerRadius: white * 0.14),
                       with: .color(lit.contains(i) ? ink.main : Color.white.opacity(0.86)))
        }
        // Black keys after C, D, F, G and A.
        for i in 0..<(count - 1) where [0, 1, 3, 4, 5].contains((i + octave) % 7) {
            let rect = CGRect(x: left + CGFloat(i + 1) * white - white * 0.31, y: -length / 2, width: white * 0.62, height: length * 0.6)
            board.fill(Path(roundedRect: rect, cornerRadius: white * 0.1), with: .color(Palette.stage))
        }
        board.fill(Path(CGRect(x: left, y: -length / 2, width: CGFloat(count) * white, height: white * 0.18)), with: .color(ink.second.opacity(0.9)))
    }

    /// A banded sun on the horizon over a grid running away to it.
    static func horizon(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let line = region.minY + region.height * 0.56
        let vanish = CGPoint(x: region.midX + (value(&random) - 0.5) * region.width * 0.24, y: line)
        let radius = max(4, min(unit * 0.36, (line - region.minY) * 0.92))
        let center = CGPoint(x: vanish.x, y: line - radius * 0.32)
        context.fill(circle(center, radius * 1.6),
                     with: .radialGradient(Gradient(colors: [ink.main.opacity(0.28), ink.main.opacity(0)]),
                                           center: center, startRadius: radius * 0.5, endRadius: radius * 1.6))
        var sun = context
        sun.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: line)))
        sun.clip(to: circle(center, radius))
        sun.fill(Path(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                 with: .linearGradient(Gradient(colors: [ink.second, ink.main]),
                                       startPoint: CGPoint(x: center.x, y: center.y - radius),
                                       endPoint: CGPoint(x: center.x, y: center.y + radius)))
        var slot = center.y - radius * 0.1
        var height = radius * 0.035
        while slot < line {
            sun.fill(Path(CGRect(x: center.x - radius, y: slot, width: radius * 2, height: height)), with: ink.ground)
            slot += radius * 0.17
            height *= 1.4
        }
        var floor = context
        floor.clip(to: Path(CGRect(x: 0, y: line, width: size.width, height: size.height - line)))
        let weight = max(0.8, unit * 0.008)
        for i in -9...9 {
            let foot = CGPoint(x: vanish.x + CGFloat(i) * size.width * 0.16, y: size.height)
            floor.stroke(segment(vanish, foot), with: .color(ink.main.opacity(0.5)), lineWidth: weight)
        }
        for k in 1...7 {
            let t = pow(Double(k) / 7, 2)
            let y = line + (size.height - line) * CGFloat(t)
            floor.stroke(segment(CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)),
                         with: .color(ink.main.opacity(0.25 + 0.45 * t)), lineWidth: weight)
        }
        context.stroke(segment(CGPoint(x: 0, y: line), CGPoint(x: size.width, y: line)),
                       with: .color(ink.line.opacity(0.55)), lineWidth: weight * 1.4)
    }

    /// Strings across the sleeve on a slant, one plucked and still ringing, with a bridge in the second colour.
    static func strings(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let count = random.next() < 0.5 ? 6 : 4
        let plucked = 1 + Int(random.next() * Double(count - 2))
        var board = context
        board.clip(to: Path(CGRect(x: 0, y: region.minY, width: size.width, height: region.height)))
        board.translateBy(x: region.midX, y: region.midY)
        board.rotate(by: .degrees(-(6 + 10 * random.next())))
        let spread = region.height * 0.7
        let reach = hypot(size.width, size.height)
        let bridge = -reach / 2 + reach * CGFloat(0.22 + 0.08 * random.next())
        board.fill(Path(roundedRect: CGRect(x: bridge - unit * 0.03, y: -spread * 0.62, width: unit * 0.06, height: spread * 1.24),
                        cornerRadius: unit * 0.02), with: .color(ink.second.opacity(0.9)))
        for i in 0..<count {
            let y = -spread / 2 + spread * CGFloat(i) / CGFloat(count - 1)
            let weight = max(0.8, unit * (0.005 + 0.0035 * CGFloat(i)))
            guard i == plucked else {
                board.stroke(segment(CGPoint(x: -reach / 2, y: y), CGPoint(x: reach / 2, y: y)),
                             with: .color(ink.line.opacity(0.6)), lineWidth: weight)
                continue
            }
            let swing = spread / CGFloat(count) * 0.42
            for side in [-1.0, 1.0] {
                var blur = Path()
                for s in 0...80 {
                    let t = Double(s) / 80
                    let x = bridge + (reach / 2 - bridge) * CGFloat(t)
                    let point = CGPoint(x: x, y: y + CGFloat(side) * swing * CGFloat(sin(Double.pi * t)))
                    if s == 0 { blur.move(to: point) } else { blur.addLine(to: point) }
                }
                board.stroke(blur, with: .color(ink.main.opacity(0.35)), lineWidth: weight)
            }
            var wave = Path()
            for s in 0...160 {
                let t = Double(s) / 160
                let x = bridge + (reach / 2 - bridge) * CGFloat(t)
                let point = CGPoint(x: x, y: y + swing * CGFloat(sin(Double.pi * t) * sin(t * Double.pi * 9)))
                if s == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            board.stroke(wave, with: .color(ink.main.opacity(0.3)), lineWidth: weight * 5)
            board.stroke(wave, with: .color(ink.main), lineWidth: weight * 1.5)
            board.stroke(segment(CGPoint(x: -reach / 2, y: y), CGPoint(x: bridge, y: y)), with: .color(ink.main), lineWidth: weight * 1.5)
        }
    }

    /// A rainbow of thick arches rising from the foot of the motif, on a ground line.
    static func arches(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let outer = max(4, min(region.width * 0.48, region.height * 0.96))
        let base = CGPoint(x: region.midX + (value(&random) - 0.5) * max(0, region.width - outer * 2), y: region.maxY)
        let bands = random.next() < 0.5 ? 4 : 5
        let band = outer / CGFloat(bands + 1)
        let colors: [Color] = [ink.main, ink.second, ink.line.opacity(0.85), ink.main.opacity(0.6), ink.second.opacity(0.7)]
        for k in 0..<bands {
            let radius = outer - band * (CGFloat(k) + 0.5)
            var arch = Path()
            for s in 0...48 {
                let theta = Double.pi + Double.pi * Double(s) / 48
                let point = CGPoint(x: base.x + CGFloat(cos(theta)) * radius, y: base.y + CGFloat(sin(theta)) * radius)
                if s == 0 { arch.move(to: point) } else { arch.addLine(to: point) }
            }
            context.stroke(arch, with: .color(colors[k % colors.count]), style: StrokeStyle(lineWidth: band * 0.78, lineCap: .butt))
        }
        context.stroke(segment(CGPoint(x: region.minX, y: base.y), CGPoint(x: region.maxX, y: base.y)),
                       with: .color(ink.line.opacity(0.45)), lineWidth: max(1, unit * 0.012))
    }

    /// The moon's phases in a gentle arc, waxing to full (in the second colour, glowing) and waning, over faint stars.
    static func moon(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let count = 5
        let radius = max(2, min(region.width / (CGFloat(count) * 2.5), region.height * 0.2))
        let gap = (region.width - radius * 2 * CGFloat(count)) / CGFloat(count + 1)
        let rise = (value(&random) - 0.5) * region.height * 0.2
        for _ in 0..<10 {
            let point = CGPoint(x: region.minX + value(&random) * region.width, y: region.minY + value(&random) * region.height)
            context.fill(circle(point, max(0.6, unit * 0.008)), with: .color(ink.line.opacity(0.45)))
        }
        // How far the dark disc slides off each moon: to the left while waxing (lit on the right), right while waning.
        let shifts: [CGFloat] = [0.7, 1.25, 2.2, -1.25, -0.7]
        let full = count / 2
        for k in 0..<count {
            // The full moon highest.
            let lift = CGFloat(abs(k - full)) * radius * 0.35
            let center = CGPoint(x: region.minX + gap + radius + CGFloat(k) * (radius * 2 + gap), y: region.midY + rise + lift)
            if k == full {
                context.fill(circle(center, radius * 1.9),
                             with: .radialGradient(Gradient(colors: [ink.second.opacity(0.35), ink.second.opacity(0)]),
                                                   center: center, startRadius: radius * 0.8, endRadius: radius * 1.9))
            }
            var disc = context
            disc.clip(to: circle(center, radius))
            disc.fill(circle(center, radius), with: .color(k == full ? ink.second : ink.main))
            disc.fill(circle(CGPoint(x: center.x - shifts[k] * radius, y: center.y), radius), with: ink.ground)
            context.stroke(circle(center, radius), with: .color(ink.line.opacity(0.35)), lineWidth: max(0.8, unit * 0.008))
        }
    }

    /// An op-art board: a checkerboard swelling toward its middle, one square lit in the second colour.
    static func checker(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let side = max(4, min(region.width, region.height))
        let left = region.minX + max(0, region.width - side) * value(&random)
        let top = region.minY + max(0, region.height - side) / 2
        let cells = 7
        // Squares widen toward the middle: an eased edge, (1 - cos πt) / 2.
        func edge(_ i: Int) -> CGFloat { CGFloat((1 - cos(Double.pi * Double(i) / Double(cells))) / 2) * side }
        let litRow = Int(random.next() * Double(cells)) % cells
        let litColumn = Int(random.next() * Double(cells)) % cells
        for row in 0..<cells {
            for column in 0..<cells {
                let lit = row == litRow && column == litColumn
                guard lit || (row + column) % 2 == 0 else { continue }
                let rect = CGRect(x: left + edge(column), y: top + edge(row),
                                  width: edge(column + 1) - edge(column), height: edge(row + 1) - edge(row))
                context.fill(Path(rect), with: .color(lit ? ink.second : ink.main))
            }
        }
        context.stroke(Path(CGRect(x: left, y: top, width: side, height: side)), with: .color(ink.line.opacity(0.3)), lineWidth: 1)
    }

    /// A groove wound out from a bright centre, its last turn in the second colour.
    static func spiral(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * max(0, region.width - unit) * 0.8, y: region.midY)
        let reach = unit * 0.47
        let turns = 4.5 + random.next() * 2
        let phase = random.next() * 2 * Double.pi
        let steps = 420
        // Where the last turn starts.
        let split = Int(Double(steps) * (1 - 1 / turns))
        var groove = Path()
        var outer = Path()
        for s in 0...steps {
            let t = Double(s) / Double(steps)
            let theta = phase + t * turns * 2 * Double.pi
            let radius = reach * CGFloat(0.12 + 0.88 * t)
            let point = CGPoint(x: center.x + CGFloat(cos(theta)) * radius, y: center.y + CGFloat(sin(theta)) * radius)
            if s == 0 { groove.move(to: point) } else if s <= split { groove.addLine(to: point) }
            if s == split { outer.move(to: point) } else if s > split { outer.addLine(to: point) }
        }
        let weight = max(1, unit * 0.014)
        context.stroke(groove, with: .color(ink.line.opacity(0.55)), style: StrokeStyle(lineWidth: weight, lineCap: .round))
        context.stroke(outer, with: .color(ink.second), style: StrokeStyle(lineWidth: weight * 2.2, lineCap: .round))
        context.fill(circle(center, reach * 0.1), with: .color(ink.main))
        context.fill(circle(center, reach * 0.025), with: ink.ground)
    }

    /// A level meter: columns of segments lit up to a swell, the top lit segment of each in the second colour.
    static func equalizer(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let columns = 9
        let rows = 9
        let pitch = region.width / CGFloat(columns)
        let step = region.height / CGFloat(rows)
        let gap = min(pitch, step) * 0.22
        let peak = 0.3 + 0.4 * random.next()
        for column in 0..<columns {
            let t = (Double(column) + 0.5) / Double(columns)
            let swell = exp(-pow((t - peak) / 0.32, 2))
            let height = Double(rows) * (0.2 + 0.8 * swell) * (0.7 + 0.3 * random.next())
            let level = max(1, min(rows, Int(height.rounded())))
            for row in 0..<rows {
                let rect = CGRect(x: region.minX + CGFloat(column) * pitch + gap / 2, y: region.maxY - CGFloat(row + 1) * step + gap / 2,
                                  width: pitch - gap, height: step - gap)
                let cell = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.2)
                let color = row >= level ? ink.line.opacity(0.08) : row == level - 1 ? ink.second : ink.main
                context.fill(cell, with: .color(color))
            }
        }
    }

    /// A flower of rounded petals in two rings, the inner ring between the outer's, round a bright heart.
    static func petals(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let center = CGPoint(x: region.midX + (value(&random) - 0.5) * max(0, region.width - unit) * 0.8, y: region.midY)
        let count = 6 + Int(random.next() * 3) % 3
        let turn = random.next() * Double.pi
        for ring in 0..<2 {
            let length = unit * (ring == 0 ? 0.47 : 0.3)
            let width = length * (ring == 0 ? 0.42 : 0.5)
            let color = ring == 0 ? ink.main.opacity(0.85) : ink.second.opacity(0.9)
            for k in 0..<count {
                let angle = turn + (Double(k) + (ring == 0 ? 0 : 0.5)) / Double(count) * 2 * Double.pi
                var petal = context
                petal.translateBy(x: center.x, y: center.y)
                petal.rotate(by: .radians(angle))
                let shape = Path(ellipseIn: CGRect(x: -width / 2, y: -length, width: width, height: length))
                petal.fill(shape, with: .color(color))
                petal.stroke(shape, with: .color(ink.line.opacity(0.35)), lineWidth: max(0.6, unit * 0.006))
            }
        }
        context.fill(circle(center, unit * 0.09), with: .color(ink.line.opacity(0.9)))
        context.fill(circle(center, unit * 0.045), with: .color(ink.main))
    }

    /// A constellation: seven stars joined by fine lines, one a bright four-point star, over a dust of faint ones.
    static func constellation(_ context: inout GraphicsContext, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        for _ in 0..<26 {
            let point = CGPoint(x: region.minX + value(&random) * region.width, y: region.minY + value(&random) * region.height)
            context.fill(circle(point, max(0.5, unit * (0.004 + 0.006 * value(&random)))), with: .color(ink.line.opacity(0.4)))
        }
        // Left to right across the room, each up or down from the one before.
        let count = 7
        let room = region.insetBy(dx: region.width * 0.06, dy: region.height * 0.12)
        var points: [CGPoint] = []
        for k in 0..<count {
            let x = room.minX + room.width * (CGFloat(k) + 0.2 + 0.6 * value(&random)) / CGFloat(count)
            points.append(CGPoint(x: x, y: room.minY + value(&random) * room.height))
        }
        var lines = Path()
        lines.addLines(points)
        // A branch from the last star back to the middle one closes a shape.
        lines.move(to: points[count - 1])
        lines.addLine(to: points[count / 2])
        context.stroke(lines, with: .color(ink.line.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.8, unit * 0.008), lineJoin: .round))
        let bright = 1 + Int(random.next() * Double(count - 2)) % (count - 2)
        for (k, point) in points.enumerated() {
            if k == bright {
                context.fill(circle(point, unit * 0.16),
                             with: .radialGradient(Gradient(colors: [ink.main.opacity(0.4), ink.main.opacity(0)]),
                                                   center: point, startRadius: 0, endRadius: unit * 0.16))
                context.fill(star(point, unit * 0.13), with: .color(ink.main))
            } else {
                context.fill(circle(point, unit * 0.026), with: .color(k % 3 == 0 ? ink.second : ink.line.opacity(0.9)))
            }
        }
    }

    /// Waves rolling in, far to near, each crest drawn in fine line, the nearest in the song's colour.
    static func waves(_ context: inout GraphicsContext, size: CGSize, region: CGRect, ink: MotifInk, random: inout SystemRandom) {
        let unit = min(region.width, region.height)
        let layers = 4
        let weight = max(0.8, unit * 0.01)
        for layer in 0..<layers {
            let depth = CGFloat(layer) / CGFloat(layers - 1)
            let base = region.minY + region.height * (0.3 + 0.55 * depth)
            let amplitude = region.height * (0.05 + 0.06 * depth)
            let length = max(1, size.width * (0.5 + 0.25 * value(&random)))
            let phase = random.next() * 2 * Double.pi
            var crest: [CGPoint] = []
            for s in 0...60 {
                let x = size.width * CGFloat(s) / 60
                let theta = Double(x / length) * 2 * Double.pi + phase
                // A rolling wave: a sharper crest and a broader trough than a sine's.
                let lift = pow((sin(theta) + 1) / 2, 2) * 2 - 1
                crest.append(CGPoint(x: x, y: base - amplitude * CGFloat(lift)))
            }
            var water = Path()
            water.move(to: CGPoint(x: 0, y: size.height))
            for point in crest { water.addLine(to: point) }
            water.addLine(to: CGPoint(x: size.width, y: size.height))
            water.closeSubpath()
            let near = layer == layers - 1
            context.fill(water, with: .color(near ? ink.main : ink.main.opacity(0.22 + 0.18 * Double(layer))))
            var line = Path()
            line.addLines(crest)
            context.stroke(line, with: .color(near ? ink.second : ink.line.opacity(0.5)), lineWidth: weight * (near ? 1.6 : 1))
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
/// number, and a sheen. A song that doesn't play yet calms: its art loses some colour, its type stays crisp.
struct SongCover: View {
    let art: CoverArt
    var corner: CGFloat = 14
    /// The type on the sleeve; off for a backdrop made from it (and never on a sleeve under `typeMinimum`).
    var titled = true
    /// Doesn't play yet (Pro, or further on in its course): the art quietens, the title stays readable.
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
        // A picture: Smart Invert leaves it as it is.
        .accessibilityIgnoresInvertColors()
        .accessibilityHidden(true)
    }

    /// Sleeves smaller than this (a 40 pt header thumbnail, a list row's) draw the motif alone: at that size the course
    /// line and the title can't be read (the line would be cut to "ORIGI…").
    static let typeMinimum: CGFloat = 72

    private func artwork(size: CGSize) -> some View {
        let typed = titled && min(size.width, size.height) >= Self.typeMinimum
        let layout = SleeveLayout(art: art, size: size, titled: typed)
        let region = layout.region
        let art = self.art
        return ZStack {
            ZStack {
                LinearGradient(colors: [art.deep, art.far], startPoint: art.start, endPoint: art.end)
                glow(side: layout.side)
                    .position(x: size.width * art.glow.x, y: size.height * art.glow.y)
                Canvas { context, canvasSize in art.draw(in: &context, size: canvasSize, region: region) }
            }
            .saturation(locked ? 0.42 : 1)
            .brightness(locked ? -0.07 : 0)
            if typed {
                if art.banner { band(layout) }
                typeBlock(layout)
                catalogue(layout)
            }
            LinearGradient(colors: [.white.opacity(art.field ? 0.18 : 0.12), .clear], startPoint: .topLeading, endPoint: .center)
        }
        .frame(width: size.width, height: size.height)
    }

    private var horizontal: HorizontalAlignment {
        switch art.align {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// The colour band a bannered title sits on, across the foot of the sleeve.
    private func band(_ layout: SleeveLayout) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Rectangle().fill(art.primary)
                .frame(height: layout.bandHeight)
                .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.18)).frame(height: max(1, layout.side * 0.006)) }
        }
    }

    /// The course over the title (as the imprint credits it), in the corner and alignment the sleeve gives them.
    private func typeBlock(_ layout: SleeveLayout) -> some View {
        let points = layout.fit.points
        let align = horizontal
        let capitals = art.imprint == .catalogue
        let block = VStack(alignment: align, spacing: 0) {
            if art.imprint.credited {
                Text(verbatim: capitals ? art.label.uppercased() : art.label)
                    .font(.custom(capitals ? "Sora-SemiBold" : "Sora-Medium", fixedSize: layout.labelSize * (capitals ? 1 : 1.1)))
                    .tracking(layout.labelSize * (capitals ? 0.16 : 0.01))
                    .foregroundStyle(art.ink.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, layout.labelSize * 0.35)
            }
            VStack(alignment: align, spacing: -points * 0.27) {
                ForEach(Array(layout.fit.lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(.custom(art.face, fixedSize: points))
                        .tracking(-points * 0.02)
                        .foregroundStyle(art.ink)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .shadow(color: .black.opacity(art.field || art.banner ? 0 : 0.35), radius: layout.side * 0.03, y: layout.side * 0.01)
        // On top, the title starts under the catalogue number; at the foot it stops short of the play corner.
        return ZStack(alignment: Alignment(horizontal: align, vertical: art.titleOnTop ? .top : .bottom)) {
            Color.clear
            block
        }
        .padding(.leading, layout.pad)
        .padding(.trailing, layout.typeTrailing)
        .padding(.top, art.titleOnTop ? layout.typeTop : layout.pad)
        .padding(.bottom, art.banner ? layout.bandInset : layout.pad)
    }

    /// The catalogue number, small: after a rule top-left (`catalogue`), alone top-right (`corner`), or not at all.
    @ViewBuilder private func catalogue(_ layout: SleeveLayout) -> some View {
        let size = layout.labelSize * 1.05
        let ink = (art.field ? Palette.stage : Palette.ink)
        let number = Text(verbatim: String(format: "%02d", art.number))
            .font(.custom("Sora-Medium", fixedSize: size)).monospacedDigit()
            // Small catalogue numbers need full ink beneath the sleeve's top-light wash.
            .foregroundStyle(ink)
        switch art.imprint {
        case .catalogue:
            ZStack(alignment: .topLeading) {
                Color.clear
                HStack(spacing: size * 0.4) {
                    Capsule().fill(ink.opacity(0.5)).frame(width: size * 1.2, height: max(1, size * 0.1))
                    number
                }
            }
            .padding(layout.pad)
        case .corner:
            ZStack(alignment: .topTrailing) {
                Color.clear
                number
            }
            .padding(layout.pad)
        case .credit, .plain:
            EmptyView()
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
    /// A bannered title's band, and the type's inset from its edges.
    let bandHeight: CGFloat
    let bandInset: CGFloat
    /// The type block's top inset when the title is on top (under the catalogue number's line), and its trailing
    /// inset (a title at the foot stops short of the play corner).
    let typeTop: CGFloat
    let typeTrailing: CGFloat
    /// The motif's room: the sleeve less its margins, the catalogue number over a title on top, and the type block.
    let region: CGRect

    init(art: CoverArt, size: CGSize, titled: Bool) {
        side = max(1, min(size.width, size.height))
        pad = side * 0.075
        labelSize = max(6, side * 0.052)
        let width = max(1, size.width - pad * 2)
        // The catalogue number's line (Sora's line box is 1.26 em) and the space under it.
        typeTop = pad + labelSize * 1.05 * 1.26 + side * 0.035
        guard titled else {
            fit = TitleFit(lines: [], points: 0)
            bandHeight = 0
            bandInset = 0
            typeTrailing = pad
            region = CGRect(x: pad, y: pad, width: width, height: max(1, size.height - pad * 2))
            return
        }
        typeTrailing = art.titleOnTop ? pad : max(pad, side * CoverArt.playCorner)
        let typeWidth = max(1, size.width - pad - typeTrailing)
        fit = TitleFit.make(art.title, width: typeWidth, maxHeight: side * (art.titleOnTop ? 0.36 : 0.4), largest: side * 0.17,
                            smallest: side * 0.075, font: art.face)
        let credit = art.imprint.credited ? labelSize * 1.26 + labelSize * 0.35 : 0
        let block = credit + fit.height
        let gap = side * 0.05
        bandInset = pad * 0.7
        bandHeight = art.banner ? block + bandInset * 2 : 0
        if art.titleOnTop {
            let top = typeTop + block + gap
            region = CGRect(x: pad, y: top, width: width, height: max(side * 0.2, size.height - top - pad))
        } else {
            let used = art.banner ? bandHeight + pad + gap : pad * 2 + block + gap
            region = CGRect(x: pad, y: pad, width: width, height: max(side * 0.2, size.height - used))
        }
    }
}

/// A sleeve title broken into lines at the largest size (in its Sora face) that fits `width` in at most three lines
/// and `maxHeight`, measured from the glyphs with UIKit. Titles in scripts without spaces (Chinese, Japanese) break
/// between characters; a word too long for the smallest size breaks too. Results are cached per title, face and width.
struct TitleFit {
    let lines: [String]
    let points: CGFloat

    static let font = "Sora-Bold"
    static let maxLines = 3

    /// The block's height: Sora's line box is 1.26 em, and lines stack 0.99 em apart.
    var height: CGFloat { lines.isEmpty ? 0 : points * (1.26 + 0.99 * CGFloat(lines.count - 1)) }

    @MainActor private static var cache: [String: TitleFit] = [:]

    @MainActor static func make(_ text: String, width: CGFloat, maxHeight: CGFloat, largest: CGFloat, smallest: CGFloat,
                                font: String = TitleFit.font) -> TitleFit {
        let key = "\(text)|\(font)|\(Int(width.rounded()))|\(Int(maxHeight.rounded()))|\(Int(largest.rounded()))"
        if let hit = cache[key] { return hit }
        let result = compute(text, width: width, maxHeight: maxHeight, largest: largest, smallest: min(smallest, largest), font: font)
        if cache.count > 500 { cache.removeAll() }
        cache[key] = result
        return result
    }

    private struct Token {
        let text: String
        /// Set straight after the one before (no space): characters of a CJK word.
        let joined: Bool
    }

    private static func compute(_ text: String, width: CGFloat, maxHeight: CGFloat, largest: CGFloat, smallest: CGFloat,
                                font: String) -> TitleFit {
        let words = tokens(text)
        guard !words.isEmpty, width > 4, largest > 1 else { return TitleFit(lines: [], points: 0) }
        var points = largest
        while points > smallest {
            let size = points
            let face = uiFont(font, size)
            let measure: (String) -> CGFloat = { Self.measure($0, face, size) }
            let lines = wrap(words, width: width, measure: measure)
            let height = size * (1.26 + 0.99 * CGFloat(lines.count - 1))
            if lines.count <= maxLines, height <= maxHeight, lines.allSatisfy({ measure($0) <= width }) {
                return TitleFit(lines: lines, points: size)
            }
            points *= 0.93
        }
        let face = uiFont(font, smallest)
        let measure: (String) -> CGFloat = { Self.measure($0, face, smallest) }
        let pieces = words.flatMap { split($0, width: width, measure: measure) }
        var lines = wrap(pieces, width: width, measure: measure)
        if lines.count > maxLines {
            lines = Array(lines.prefix(maxLines))
            lines[maxLines - 1] += "…"
        }
        return TitleFit(lines: lines, points: smallest)
    }

    private static func uiFont(_ name: String, _ points: CGFloat) -> UIFont {
        UIFont(name: name, size: points) ?? UIFont.systemFont(ofSize: points, weight: .bold)
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

// MARK: - The sleeve's light

/// A song's colours as a mesh of light (iOS 18 `MeshGradient`), for the backdrop behind its sleeve: the featured
/// card, the song sheet's head, the poster. Its middle drifts slowly unless Reduce Motion is on or `animated` is off
/// (the poster is drawn still). Unlike a blur of the sleeve it stays smooth at any width.
struct CoverMesh: View {
    let art: CoverArt
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drifting only while seen (`animatesWhileSeen`): never off screen, in the background or in Low Power Mode.
    @State private var live = false

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !live)) { timeline in
                    mesh(at: timeline.date.timeIntervalSinceReferenceDate)
                }
                .animatesWhileSeen($live)
            } else {
                mesh(at: 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityIgnoresInvertColors()
        .accessibilityHidden(true)
    }

    private func mesh(at time: Double) -> MeshGradient {
        MeshGradient(width: 3, height: 3, points: Self.points(at: time, glow: art.glow), colors: colors)
    }

    /// The sleeve's glow sets where the light gathers; the middle and the edges' midpoints sway around it.
    private static func points(at time: Double, glow: UnitPoint) -> [SIMD2<Float>] {
        let t = time.truncatingRemainder(dividingBy: 3600)
        let cx = Float(0.3 + 0.4 * glow.x) + Float(0.1 * sin(t * 0.21))
        let cy = Float(0.32 + 0.3 * glow.y) + Float(0.08 * cos(t * 0.17))
        let top = Float(0.5 + 0.18 * sin(t * 0.13 + 1))
        let left = Float(0.5 + 0.14 * cos(t * 0.16))
        let right = Float(0.45 + 0.14 * sin(t * 0.19 + 2))
        let bottom = Float(0.5 + 0.16 * cos(t * 0.11 + 3))
        return [
            SIMD2<Float>(0, 0), SIMD2<Float>(top, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(0, left), SIMD2<Float>(cx, cy), SIMD2<Float>(1, right),
            SIMD2<Float>(0, 1), SIMD2<Float>(bottom, 1), SIMD2<Float>(1, 1),
        ]
    }

    /// Dark at the edges and foot, the song's colour lit in the middle, its second colour along one side.
    private var colors: [Color] {
        let lit = art.primary.mix(with: .black, by: art.field ? 0.15 : 0.22)
        return [
            art.far, art.primary.mix(with: .black, by: 0.45), art.secondary.mix(with: .black, by: 0.55),
            art.secondary.mix(with: .black, by: 0.42), lit, art.deep,
            Palette.stageDeep, art.far.mix(with: .black, by: 0.4), Palette.stage,
        ]
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
        .accessibilityIgnoresInvertColors()
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
