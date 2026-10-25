import SwiftUI

// The app's icon language: a bare glyph in its ink, never an SF Symbol sitting in a tinted disc. A row's glyph stands
// in a fixed optical box, so titles line up down a list whatever the glyph's width; it is quiet (`inkSoft`) unless the
// row is about a status (mint, amber, coral), a course (its hue) or a category (`accentNeutral`). Where SF Symbols has
// no honest picture (a capo, a temperament, a note value, the player's own charts, the streak's stage lamp) the glyph
// is drawn here on a 24-point grid at the symbols' regular stroke, so drawn and system glyphs sit together in one list.
//
//     Glyph("bell")                                   // a settings row
//     Glyph(.capo)                                    // a drawn glyph
//     Glyph("waveform", size: Glyph.lead, tint: Palette.mint)
//
// Sizes: `row` (22) for list rows, `lead` (28) for a card's leading glyph, `feature` (40) for an empty state. When the
// owner's icon family lands, its glyphs join `TimbreGlyph` and every call site picks them up.

/// A glyph drawn for Timbre where SF Symbols has none that says the thing.
enum TimbreGlyph: CaseIterable, Sendable {
    /// A capo clamped across four strings.
    case capo
    /// Three keys of a keyboard: how the notes between are tuned.
    case temperament
    /// A chord chart: chords over the words (the player's own songs).
    case chart
    /// ♩, ♫, three beamed eighths under a 3, ♬: the metronome's subdivisions.
    case quarterNotes, eighthNotes, tripletNotes, sixteenthNotes
    /// The streak: a stage lamp hanging from its rig, its beam falling below it. The one picture of a streak (the chip,
    /// tiles, the coach, the milestone's `StageLamp`); the flame is kept for a play-along's combo, where "on fire" is meant.
    case lamp

    /// The stroke of a line, in grid units (SF Symbols' regular weight at a row's size).
    static let stroke: CGFloat = 1.6
    /// How strongly a glyph's wash (the lamp's beam) is filled, against its solids.
    static let washOpacity: Double = 0.38

    /// Lines, stroked at `stroke`, in a 24-unit square (y down) scaled by `u` points per unit.
    func lines(_ u: CGFloat) -> Path {
        var path = Path()
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: CGPoint(x: x1 * u, y: y1 * u))
            path.addLine(to: CGPoint(x: x2 * u, y: y2 * u))
        }
        switch self {
        case .capo:
            for x in [6.0, 10.0, 14.0, 18.0] as [CGFloat] { line(x, 3, x, 21) }
            // The clamp's lever behind the neck.
            line(21, 13.5, 21, 17.5)
            line(19.5, 17.5, 22, 17.5)
        case .temperament:
            path.addRoundedRect(in: CGRect(x: 3 * u, y: 5 * u, width: 18 * u, height: 14 * u), cornerSize: CGSize(width: 2 * u, height: 2 * u))
            line(9, 12.5, 9, 19)
            line(15, 12.5, 15, 19)
        case .chart:
            path.addRoundedRect(in: CGRect(x: 4.5 * u, y: 3 * u, width: 15 * u, height: 18 * u), cornerSize: CGSize(width: 2.5 * u, height: 2.5 * u))
            line(8, 11.5, 16, 11.5)
            line(8, 16.5, 13.5, 16.5)
        case .quarterNotes:
            line(12.3, 17, 12.3, 3.5)
        case .eighthNotes:
            line(9.4, 17.8, 9.4, 5)
            line(19.4, 15.8, 19.4, 3.5)
        case .tripletNotes:
            line(6.6, 19, 6.6, 9.5)
            line(13.6, 17.5, 13.6, 8.3)
            line(20.6, 16, 20.6, 7.1)
        case .sixteenthNotes:
            line(9.4, 18.8, 9.4, 5)
            line(19.4, 16.8, 19.4, 3.5)
        case .lamp:
            // The drop from the rig, and the stage floor the beam lands on.
            line(12, 0.6, 12, 2.8)
            line(3.5, 21.8, 20.5, 21.8)
        }
        return path
    }

    /// Light rather than ink (the lamp's beam), filled at `washOpacity` in the same square.
    func wash(_ u: CGFloat) -> Path {
        var path = Path()
        if self == .lamp {
            // The beam, parted from the shade by a hairline of air so the two never read as one bell.
            path.move(to: CGPoint(x: 7.6 * u, y: 10.2 * u))
            path.addLine(to: CGPoint(x: 16.4 * u, y: 10.2 * u))
            path.addLine(to: CGPoint(x: 20.4 * u, y: 20.6 * u))
            path.addLine(to: CGPoint(x: 3.6 * u, y: 20.6 * u))
            path.closeSubpath()
        }
        return path
    }

    /// Solid parts (noteheads, beams, the capo's bar), filled, in the same square.
    func solids(_ u: CGFloat) -> Path {
        var path = Path()
        func head(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) {
            let center = CGPoint(x: x * u, y: y * u)
            let oval = Path(ellipseIn: CGRect(x: center.x - rx * u, y: center.y - ry * u, width: 2 * rx * u, height: 2 * ry * u))
            let tilt = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: -22 * CGFloat.pi / 180)
                .translatedBy(x: -center.x, y: -center.y)
            path.addPath(oval.applying(tilt))
        }
        func beam(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, thickness: CGFloat) {
            path.move(to: CGPoint(x: x1 * u, y: y1 * u))
            path.addLine(to: CGPoint(x: x2 * u, y: y2 * u))
            path.addLine(to: CGPoint(x: x2 * u, y: (y2 + thickness) * u))
            path.addLine(to: CGPoint(x: x1 * u, y: (y1 + thickness) * u))
            path.closeSubpath()
        }
        switch self {
        case .capo:
            path.addRoundedRect(in: CGRect(x: 3 * u, y: 9.5 * u, width: 19 * u, height: 4 * u), cornerSize: CGSize(width: 2 * u, height: 2 * u))
        case .temperament:
            path.addRect(CGRect(x: 7.25 * u, y: 5 * u, width: 3.5 * u, height: 7.5 * u))
            path.addRect(CGRect(x: 13.25 * u, y: 5 * u, width: 3.5 * u, height: 7.5 * u))
        case .chart:
            // The chords over the first line of words.
            path.addEllipse(in: CGRect(x: 7.6 * u, y: 6.1 * u, width: 2.8 * u, height: 2.8 * u))
            path.addEllipse(in: CGRect(x: 13.1 * u, y: 6.1 * u, width: 2.8 * u, height: 2.8 * u))
        case .quarterNotes:
            head(9, 18, 3.6, 2.6)
        case .eighthNotes:
            head(6.5, 18.5, 3.2, 2.3)
            head(16.5, 16.5, 3.2, 2.3)
            beam(8.6, 4.2, 20.2, 2.6, thickness: 2.6)
        case .tripletNotes:
            head(4.6, 19.7, 2.5, 1.85)
            head(11.6, 18.2, 2.5, 1.85)
            head(18.6, 16.7, 2.5, 1.85)
            beam(5.8, 9.2, 21.4, 6.4, thickness: 2.3)
        case .sixteenthNotes:
            head(6.5, 19.5, 3.2, 2.3)
            head(16.5, 17.5, 3.2, 2.3)
            beam(8.6, 4.2, 20.2, 2.6, thickness: 2.3)
            beam(8.6, 8.2, 20.2, 6.6, thickness: 2.3)
        case .lamp:
            // The shade, narrow at the drop and open toward the stage.
            path.move(to: CGPoint(x: 9.6 * u, y: 2.6 * u))
            path.addLine(to: CGPoint(x: 14.4 * u, y: 2.6 * u))
            path.addLine(to: CGPoint(x: 17.6 * u, y: 8.6 * u))
            path.addLine(to: CGPoint(x: 6.4 * u, y: 8.6 * u))
            path.closeSubpath()
        }
        return path
    }
}

/// A glyph as the app draws its icons: bare, in its ink, centred in a square box of `size` points so rows line up.
/// Decorative: the row it sits in carries the words (it is hidden from VoiceOver).
struct Glyph: View {
    private enum Art {
        case symbol(String)
        case drawn(TimbreGlyph)
    }

    /// A list row's glyph (Settings, an add-a-song option).
    static let row: CGFloat = 22
    /// A card's leading glyph (the coach, a feature row).
    static let lead: CGFloat = 28
    /// An empty state's glyph, over its title.
    static let feature: CGFloat = 40

    private let art: Art
    private let size: CGFloat
    private let tint: Color

    /// An SF Symbol, in its outline form where it has one.
    init(_ symbol: String, size: CGFloat = Glyph.row, tint: Color = Palette.inkSoft) {
        art = .symbol(symbol)
        self.size = size
        self.tint = tint
    }

    /// A glyph drawn for Timbre.
    init(_ glyph: TimbreGlyph, size: CGFloat = Glyph.row, tint: Color = Palette.inkSoft) {
        art = .drawn(glyph)
        self.size = size
        self.tint = tint
    }

    var body: some View {
        face
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder private var face: some View {
        switch art {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.78, weight: .regular))
                .symbolRenderingMode(.monochrome)
        case .drawn(let glyph):
            DrawnGlyph(glyph: glyph)
        }
    }
}

/// A `TimbreGlyph` at the size it is given: its wash filled faintly, its solids filled and its lines stroked, all in the
/// foreground style.
struct DrawnGlyph: View {
    let glyph: TimbreGlyph

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let unit = side / 24
            ZStack {
                GlyphOutline(glyph: glyph, layer: .wash)
                    .opacity(TimbreGlyph.washOpacity)
                GlyphOutline(glyph: glyph, layer: .solids)
                GlyphOutline(glyph: glyph, layer: .lines)
                    .stroke(style: StrokeStyle(lineWidth: TimbreGlyph.stroke * unit, lineCap: .round, lineJoin: .round))
                if glyph == .tripletNotes {
                    Text(verbatim: "3")
                        .font(.custom(Typeface.Face.semiBold.fontName, fixedSize: max(6, side * 0.3)))
                        .position(x: proxy.size.width / 2 + 1.5 * unit, y: proxy.size.height / 2 - 9 * unit)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// One layer of a `TimbreGlyph` (its wash, solids or lines) centred in the rect.
private struct GlyphOutline: Shape {
    enum Layer { case wash, solids, lines }

    let glyph: TimbreGlyph
    let layer: Layer

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let unit = side / 24
        let drawn: Path
        switch layer {
        case .wash: drawn = glyph.wash(unit)
        case .solids: drawn = glyph.solids(unit)
        case .lines: drawn = glyph.lines(unit)
        }
        return drawn.offsetBy(dx: rect.midX - side / 2, dy: rect.midY - side / 2)
    }
}
