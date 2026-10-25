import SwiftUI
import TimbreCore

/// A course's own picture, wherever a course is shown (Learn's carousel and continue card, the Songs tab,
/// the onboarding plan, the paywall). Instrument courses wear the instrument's studio render (or its
/// photograph); the rest (theory, ear training, rhythm, singing, songs, originals) a drawn emblem on their
/// course hue. No SF Symbols: the art is the app's own. Smart Invert leaves all of it as it is (it is a picture).
enum CourseArtwork {
    case instrument(name: String, render: Bool)
    case emblem(CourseGlyph)

    @MainActor static func of(_ course: LearnCourse, catalog: Catalog) -> CourseArtwork {
        if let glyph = CourseGlyph(courseId: course.id) { return .emblem(glyph) }
        if let image = instrumentImage(course.instrument, catalog: catalog) { return .instrument(name: image.name, render: image.render) }
        return .emblem(.note)
    }

    /// The instrument's studio render when it has an artist model, otherwise its photograph.
    /// `render` is true for the renders, which stand upright in a square canvas.
    @MainActor static func instrumentImage(_ instrumentId: String?, catalog: Catalog) -> (name: String, render: Bool)? {
        guard let instrumentId, let asset = catalog.photo(instrumentId: instrumentId)?.asset else { return nil }
        if let model = ModelLibrary.modelID(forPhoto: asset), ModelLibrary.hasCard(model) { return (ModelLibrary.cardImageName(model), true) }
        return (asset, false)
    }
}

/// The drawn emblems of the courses that aren't one instrument.
enum CourseGlyph: CaseIterable {
    /// Theory: a treble clef.
    case clef
    /// Ear training: an ear.
    case ear
    /// Rhythm: a metronome.
    case metronome
    /// Singing: a voice waveform.
    case voice
    /// Songs: two beamed quavers.
    case notes
    /// Originals: a record with a glint.
    case record
    /// Any other course: one quaver.
    case note

    init?(courseId: String) {
        switch courseId {
        case "theory": self = .clef
        case "ear": self = .ear
        case "rhythm": self = .metronome
        case "voice": self = .voice
        case "songs": self = .notes
        case "originals": self = .record
        default: return nil
        }
    }
}

/// A course's art as a rounded tile of `size` points: the emblem tile, or the instrument leaning across a dark
/// accent tile. Used small (filter chips, shelf headers, paywall bullets) and medium (the plan's eyebrow).
struct CourseArt: View {
    @EnvironmentObject private var store: AppStore
    let course: LearnCourse
    var size: CGFloat = 32

    var body: some View {
        let accent = Palette.accent(course.accent)
        switch CourseArtwork.of(course, catalog: store.catalog) {
        case .instrument(let name, let render):
            InstrumentTile(image: name, render: render, accent: accent, size: size)
        case .emblem(let glyph):
            CourseEmblemTile(glyph: glyph, accent: accent, size: size)
        }
    }
}

/// Large course art for cards: the instrument itself leaning in the light, or the emblem tile tilted like a
/// sticker. `size` is the square the instrument stands in; the emblem tile takes two thirds of it.
struct CourseHeroArt: View {
    let artwork: CourseArtwork
    let accent: Color
    var size: CGFloat = 110
    /// Degrees; negative leans left.
    var lean: Double = -12

    var body: some View {
        switch artwork {
        case .instrument(let name, _):
            Image(name).resizable().interpolation(.high).scaledToFit()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(lean))
                .shadow(color: .black.opacity(0.6), radius: size * 0.1, y: size * 0.07)
                .accessibilityIgnoresInvertColors()
                .accessibilityHidden(true)
        case .emblem(let glyph):
            CourseEmblemTile(glyph: glyph, accent: accent, size: size * 0.66)
                .rotationEffect(.degrees(lean * 0.6))
                .shadow(color: accent.opacity(0.35), radius: size * 0.12, y: size * 0.05)
                .shadow(color: .black.opacity(0.45), radius: size * 0.05, y: size * 0.04)
                .frame(width: size, height: size)
        }
    }
}

/// The emblem on its accent gradient: a light top edge, a faint stave behind the glyph at larger sizes, and a sheen.
struct CourseEmblemTile: View {
    let glyph: CourseGlyph
    let accent: Color
    var size: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [accent.mix(with: .white, by: 0.2), accent, accent.mix(with: .black, by: 0.2)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            if size >= 44 { Stave().stroke(.white.opacity(0.16), lineWidth: max(0.5, size / 110)) }
            CourseGlyphView(glyph: glyph, ink: Palette.onAccent.opacity(0.92), accent: accent)
                .padding(size * 0.12)
            shape.fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0)], startPoint: .top, endPoint: .center))
            shape.strokeBorder(.white.opacity(0.28), lineWidth: max(0.5, size / 90))
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityIgnoresInvertColors()
        .accessibilityHidden(true)
    }
}

/// An instrument across a dark accent tile, headstock to the top right, under a soft spotlight.
struct InstrumentTile: View {
    let image: String
    /// Studio renders stand upright in a square canvas and are leaned onto the diagonal; photographs already lean.
    let render: Bool
    let accent: Color
    var size: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [accent.mix(with: .black, by: 0.5), Palette.stageDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            RadialGradient(colors: [accent.opacity(0.5), accent.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.62)
            instrument
            shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0)], startPoint: .top, endPoint: .center))
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(accent.opacity(0.45), lineWidth: max(0.5, size / 90)))
        .accessibilityIgnoresInvertColors()
        .accessibilityHidden(true)
    }

    @ViewBuilder private var instrument: some View {
        if render {
            Image(image).resizable().interpolation(.high).scaledToFit()
                .frame(width: size * 1.42, height: size * 1.42)
                .rotationEffect(.degrees(42))
                .shadow(color: .black.opacity(0.55), radius: size * 0.05, y: size * 0.03)
        } else {
            Image(image).resizable().interpolation(.high).scaledToFit()
                .frame(width: size * 1.16, height: size * 1.16)
                .shadow(color: .black.opacity(0.55), radius: size * 0.05, y: size * 0.03)
        }
    }
}

/// Five faint stave lines across the middle of a tile.
private struct Stave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for line in 0..<5 {
            let y = rect.minY + rect.height * (0.3 + 0.1 * CGFloat(line))
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// A course glyph drawn on a 100-unit square in one ink (the record's grooves and label take the tile's accent).
struct CourseGlyphView: View {
    let glyph: CourseGlyph
    var ink: Color = Palette.onAccent
    var accent: Color = Palette.mint

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            var square = context
            square.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            let pen = GlyphPen(context: square, side: side, ink: ink, accent: accent)
            switch glyph {
            case .clef: pen.clef()
            case .ear: pen.ear()
            case .metronome: pen.metronome()
            case .voice: pen.voice()
            case .notes: pen.notes()
            case .record: pen.record()
            case .note: pen.note()
            }
        }
        .accessibilityHidden(true)
    }
}

/// Draws the glyphs. Coordinates are in a 100-unit square, y down; line widths in the same units.
private struct GlyphPen {
    let context: GraphicsContext
    let side: CGFloat
    let ink: Color
    let accent: Color

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x / 100 * side, y: y / 100 * side) }
    func u(_ value: CGFloat) -> CGFloat { value / 100 * side }

    func stroke(_ path: Path, _ width: CGFloat, color: Color? = nil) {
        context.stroke(path, with: .color(color ?? ink), style: StrokeStyle(lineWidth: u(width), lineCap: .round, lineJoin: .round))
    }

    func fill(_ path: Path, color: Color? = nil) {
        context.fill(path, with: .color(color ?? ink))
    }

    func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: u(x - r), y: u(y - r), width: u(2 * r), height: u(2 * r)))
    }

    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
        var path = Path()
        path.move(to: p(x1, y1))
        path.addLine(to: p(x2, y2))
        return path
    }

    func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points.map { p($0.x, $0.y) })
        path.closeSubpath()
        return path
    }

    /// A notehead tilted up to the right.
    func notehead(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        let center = p(x, y)
        let rect = CGRect(x: center.x - u(rx), y: center.y - u(ry), width: u(2 * rx), height: u(2 * ry))
        let tilt = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: -24 * CGFloat.pi / 180).translatedBy(x: -center.x, y: -center.y)
        return Path(ellipseIn: rect).applying(tilt)
    }

    // MARK: Glyphs

    func clef() {
        var path = Path()
        path.move(to: p(54, 62))
        path.curve(self, 44, 64, 40, 54, 48, 49)
        path.curve(self, 58, 43, 70, 50, 69, 61)
        path.curve(self, 68, 73, 56, 79, 47, 78)
        path.curve(self, 33, 77, 27, 64, 33, 53)
        path.curve(self, 39, 43, 52, 36, 58, 27)
        path.curve(self, 64, 17, 60, 6, 54, 7)
        path.curve(self, 47, 8, 44, 18, 47, 30)
        path.addLine(to: p(52, 88))
        path.curve(self, 53, 96, 46, 99, 41, 95)
        stroke(path, 6)
        fill(circle(42, 91, 5))
    }

    func ear() {
        var outer = Path()
        outer.move(to: p(28, 40))
        outer.curve(self, 28, 22, 42, 12, 54, 14)
        outer.curve(self, 68, 16, 74, 30, 70, 42)
        outer.curve(self, 66, 54, 56, 58, 54, 68)
        outer.curve(self, 52, 80, 44, 88, 34, 84)
        stroke(outer, 6.5)
        var inner = Path()
        inner.move(to: p(40, 42))
        inner.curve(self, 40, 32, 50, 28, 56, 34)
        inner.curve(self, 60, 40, 56, 46, 50, 50)
        inner.curve(self, 46, 53, 48, 60, 44, 62)
        stroke(inner, 6)
    }

    func metronome() {
        let body = polygon([CGPoint(x: 30, y: 86), CGPoint(x: 70, y: 86), CGPoint(x: 58.5, y: 15), CGPoint(x: 41.5, y: 15)])
        fill(body, color: ink.opacity(0.22))
        stroke(body, 6)
        stroke(line(22, 86, 78, 86), 7)
        stroke(line(50, 74, 67, 28), 5)
        fill(circle(61.5, 43, 6.5))
        fill(circle(50, 74, 4.5))
    }

    func voice() {
        let heights: [CGFloat] = [18, 40, 62, 78, 56, 34, 16]
        for (index, height) in heights.enumerated() {
            let x = 20 + CGFloat(index) * 10
            stroke(line(x, 50 - height / 2, x, 50 + height / 2), 6.5)
        }
    }

    func notes() {
        fill(notehead(31, 75, 12.5, 9))
        fill(notehead(71, 67, 12.5, 9))
        stroke(line(42, 72, 42, 26), 6)
        stroke(line(82, 64, 82, 18), 6)
        fill(polygon([CGPoint(x: 39, y: 22), CGPoint(x: 85, y: 12), CGPoint(x: 85, y: 25), CGPoint(x: 39, y: 35)]))
    }

    func note() {
        fill(notehead(40, 76, 14, 10))
        stroke(line(52, 73, 52, 16), 6.5)
        var flag = Path()
        flag.move(to: p(49, 13))
        flag.curve(self, 52, 28, 72, 32, 72, 50)
        flag.curve(self, 72, 56, 70, 61, 67, 65)
        flag.curve(self, 68, 53, 62, 44, 49, 40)
        flag.closeSubpath()
        fill(flag)
    }

    func record() {
        fill(circle(46, 54, 34))
        context.stroke(circle(46, 54, 27), with: .color(accent.opacity(0.45)), lineWidth: u(1.6))
        context.stroke(circle(46, 54, 20), with: .color(accent.opacity(0.45)), lineWidth: u(1.6))
        fill(circle(46, 54, 11), color: accent)
        fill(circle(46, 54, 2.6))
        var glint = Path()
        glint.move(to: p(80, 4))
        glint.curve(self, 81, 14, 84, 17, 94, 18)
        glint.curve(self, 84, 19, 81, 22, 80, 32)
        glint.curve(self, 79, 22, 76, 19, 66, 18)
        glint.curve(self, 76, 17, 79, 14, 80, 4)
        glint.closeSubpath()
        fill(glint)
    }
}

private extension Path {
    /// A cubic curve in the pen's 100-unit space, in SVG order: both control points, then the end point.
    mutating func curve(_ pen: GlyphPen, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        addCurve(to: pen.p(x, y), control1: pen.p(x1, y1), control2: pen.p(x2, y2))
    }
}
