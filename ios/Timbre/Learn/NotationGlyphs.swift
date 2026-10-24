import SwiftUI

/// The engraved shapes of standard notation, drawn as paths rather than taken from a music font (the app bundles
/// none): clefs, noteheads, flags, rests and accidentals. Each is built once in staff spaces with y pointing up, from
/// the origin its drawing code expects; `placed(_:at:space:)` scales one to a staff and flips it into view space.
/// The curved ones are a centre line with a width at each point (thick downstrokes, thin hairlines), outlined.
enum NotationGlyph: Hashable {
    case trebleClef, bassClef
    case blackHead, halfHead, wholeHead
    case slashHead, slashHollow
    case sharp, flat, natural, doubleSharp, doubleFlat
    case wholeRest, halfRest, quarterRest, eighthRest, sixteenthRest
    case flagUp, flagDown
    case dot

    /// Its outline, in parts filled one by one (so a ball touching a stroke can't cancel it out); `evenOdd` parts
    /// have holes (open noteheads).
    var parts: [(path: Path, evenOdd: Bool)] { NotationGlyphs.parts(of: self) }

    /// Width in staff spaces, from its origin.
    var width: CGFloat {
        switch self {
        case .trebleClef: return 2.7
        case .bassClef: return 2.85
        case .blackHead, .halfHead: return 1.24
        case .wholeHead: return 1.6
        case .slashHead, .slashHollow: return 1.5
        case .sharp: return 1.05
        case .flat: return 0.92
        case .natural: return 0.84
        case .doubleSharp: return 0.95
        case .doubleFlat: return 1.7
        case .wholeRest, .halfRest: return 1.2
        case .quarterRest: return 1.0
        case .eighthRest: return 1.0
        case .sixteenthRest: return 1.2
        case .flagUp, .flagDown: return 1.0
        case .dot: return 0.4
        }
    }
}

enum NotationGlyphs {
    /// The shape scaled to a staff whose spaces are `space` points and moved to `point` (its origin), in view space.
    static func placed(_ glyph: NotationGlyph, at point: CGPoint, space: CGFloat) -> [(path: Path, evenOdd: Bool)] {
        let transform = CGAffineTransform(a: space, b: 0, c: 0, d: -space, tx: point.x, ty: point.y)
        return glyph.parts.map { (path: $0.path.applying(transform), evenOdd: $0.evenOdd) }
    }

    fileprivate static func parts(of glyph: NotationGlyph) -> [(path: Path, evenOdd: Bool)] {
        if let known = cache[glyph] { return known }
        return build(glyph)
    }

    private static let cache: [NotationGlyph: [(path: Path, evenOdd: Bool)]] = {
        let all: [NotationGlyph] = [.trebleClef, .bassClef, .blackHead, .halfHead, .wholeHead, .slashHead, .slashHollow,
                                    .sharp, .flat, .natural, .doubleSharp, .doubleFlat, .wholeRest, .halfRest, .quarterRest,
                                    .eighthRest, .sixteenthRest, .flagUp, .flagDown, .dot]
        var table: [NotationGlyph: [(path: Path, evenOdd: Bool)]] = [:]
        for glyph in all { table[glyph] = build(glyph) }
        return table
    }()

    private static func build(_ glyph: NotationGlyph) -> [(path: Path, evenOdd: Bool)] {
        switch glyph {
        case .trebleClef: return treble
        case .bassClef: return bass
        case .blackHead: return [(path: head(width: 1.3, height: 0.86, tilt: 22), evenOdd: false)]
        case .halfHead:
            var path = head(width: 1.3, height: 0.86, tilt: 22)
            path.addPath(head(width: 1.0, height: 0.4, tilt: 22))
            return [(path: path, evenOdd: true)]
        case .wholeHead:
            var path = head(width: 1.6, height: 1.0, tilt: 0)
            path.addPath(head(width: 0.62, height: 0.84, tilt: -35))
            return [(path: path, evenOdd: true)]
        case .slashHead: return [(path: slash(hollow: false), evenOdd: false)]
        case .slashHollow: return [(path: slash(hollow: true), evenOdd: true)]
        case .sharp: return sharp
        case .flat: return flat(at: 0)
        case .natural: return natural
        case .doubleSharp: return doubleSharp
        case .doubleFlat: return flat(at: 0) + flat(at: 0.8)
        case .wholeRest: return [(path: Path(CGRect(x: 0, y: -0.5, width: 1.2, height: 0.5)), evenOdd: false)]
        case .halfRest: return [(path: Path(CGRect(x: 0, y: 0, width: 1.2, height: 0.5)), evenOdd: false)]
        case .quarterRest: return quarterRest
        case .eighthRest: return restWithBalls(1)
        case .sixteenthRest: return restWithBalls(2)
        case .flagUp: return [(path: flag(down: false), evenOdd: false)]
        case .flagDown: return [(path: flag(down: true), evenOdd: false)]
        case .dot: return [(path: Path(ellipseIn: CGRect(x: -0.2, y: -0.2, width: 0.4, height: 0.4)), evenOdd: false)]
        }
    }

    // MARK: Building blocks

    /// An ellipse centred on the origin, turned `tilt` degrees anticlockwise.
    private static func head(width: CGFloat, height: CGFloat, tilt: CGFloat) -> Path {
        let ellipse = Path(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        return ellipse.applying(CGAffineTransform(rotationAngle: tilt * .pi / 180))
    }

    /// A slash notehead: a slanted bar a space tall across the middle line.
    private static func slash(hollow: Bool) -> Path {
        var path = Path()
        path.addLines([CGPoint(x: -0.75, y: -0.6), CGPoint(x: -0.25, y: -0.6), CGPoint(x: 0.75, y: 0.6), CGPoint(x: 0.25, y: 0.6)])
        path.closeSubpath()
        if hollow {
            path.addLines([CGPoint(x: -0.48, y: -0.42), CGPoint(x: -0.32, y: -0.42), CGPoint(x: 0.48, y: 0.42), CGPoint(x: 0.32, y: 0.42)])
            path.closeSubpath()
        }
        return path
    }

    /// A smooth stroke through `points` (Catmull–Rom), `widths` wide at each, outlined as one shape.
    private static func stroke(_ points: [CGPoint], widths: [CGFloat], samples: Int = 22) -> Path {
        let count = points.count
        guard count >= 2, widths.count == count else { return Path() }
        var padded: [CGPoint] = [mirror(points[1], about: points[0])]
        padded.append(contentsOf: points)
        padded.append(mirror(points[count - 2], about: points[count - 1]))
        var centre: [CGPoint] = []
        var wide: [CGFloat] = []
        for i in 1..<(padded.count - 2) {
            let p0 = padded[i - 1], p1 = padded[i], p2 = padded[i + 1], p3 = padded[i + 2]
            let w1 = widths[i - 1], w2 = widths[i]
            for k in 0..<samples {
                let t = CGFloat(k) / CGFloat(samples)
                centre.append(CGPoint(x: spline(p0.x, p1.x, p2.x, p3.x, t), y: spline(p0.y, p1.y, p2.y, p3.y, t)))
                let eased = t * t * (3 - 2 * t)
                wide.append(w1 + (w2 - w1) * eased)
            }
        }
        centre.append(points[count - 1])
        wide.append(widths[count - 1])
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in centre.indices {
            let before = centre[max(0, i - 1)]
            let after = centre[min(centre.count - 1, i + 1)]
            let dx = after.x - before.x
            let dy = after.y - before.y
            let length = max(0.000_001, (dx * dx + dy * dy).squareRoot())
            let nx = -dy / length * wide[i] / 2
            let ny = dx / length * wide[i] / 2
            left.append(CGPoint(x: centre[i].x + nx, y: centre[i].y + ny))
            right.append(CGPoint(x: centre[i].x - nx, y: centre[i].y - ny))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }

    private static func mirror(_ point: CGPoint, about centre: CGPoint) -> CGPoint {
        CGPoint(x: 2 * centre.x - point.x, y: 2 * centre.y - point.y)
    }

    private static func spline(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, _ t: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t
        let a = 2 * p1
        let b = (p2 - p0) * t
        let c = (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
        let d = (3 * p1 - p0 - 3 * p2 + p3) * t3
        return 0.5 * (a + b + c + d)
    }

    private static func ball(_ centre: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    // MARK: Clefs (origin: the bottom line, at the clef's left)

    /// The G clef: from its curl on the G line out round the belly, up through the S to the top loop, down the stem
    /// and into the tail's ball.
    private static let treble: [(path: Path, evenOdd: Bool)] = {
        let points: [(CGFloat, CGFloat)] = [(1.42, 1.08), (1.12, 1.40), (1.45, 1.98), (2.15, 1.75), (2.40, 0.85), (1.90, 0.05),
                                            (0.95, -0.05), (0.25, 0.75), (0.30, 1.85), (1.00, 2.75), (1.75, 3.55), (2.12, 4.45),
                                            (2.00, 5.25), (1.72, 5.60), (1.42, 5.30), (1.30, 4.55), (1.38, 3.50), (1.52, 2.00),
                                            (1.68, 0.50), (1.80, -0.70), (1.66, -1.38), (1.22, -1.62), (0.82, -1.42)]
        let widths: [CGFloat] = [0.30, 0.16, 0.10, 0.18, 0.34, 0.20, 0.12, 0.36, 0.40, 0.38, 0.32, 0.20,
                                 0.12, 0.10, 0.14, 0.17, 0.16, 0.15, 0.15, 0.16, 0.14, 0.10, 0.10]
        let body = stroke(points.map { CGPoint(x: $0.0, y: $0.1) }, widths: widths, samples: 26)
        return [(path: body, evenOdd: false),
                (path: ball(CGPoint(x: 0.90, y: -1.20), 0.36), evenOdd: false),
                (path: ball(CGPoint(x: 1.42, y: 1.08), 0.15), evenOdd: false)]
    }()

    /// The F clef: its ball on the F line, the curve over and down to a fine tail, the two dots either side of the line.
    private static let bass: [(path: Path, evenOdd: Bool)] = {
        let points: [(CGFloat, CGFloat)] = [(0.42, 3.05), (0.62, 3.72), (1.20, 4.02), (1.85, 3.72), (2.08, 2.95), (1.82, 2.00),
                                            (1.15, 1.18), (0.10, 0.45)]
        let widths: [CGFloat] = [0.18, 0.12, 0.12, 0.30, 0.46, 0.40, 0.22, 0.06]
        let body = stroke(points.map { CGPoint(x: $0.0, y: $0.1) }, widths: widths, samples: 26)
        return [(path: body, evenOdd: false),
                (path: ball(CGPoint(x: 0.45, y: 3.0), 0.34), evenOdd: false),
                (path: ball(CGPoint(x: 2.6, y: 3.5), 0.19), evenOdd: false),
                (path: ball(CGPoint(x: 2.6, y: 2.5), 0.19), evenOdd: false)]
    }()

    // MARK: Accidentals (origin: the left edge, on the note's line or space)

    private static let sharp: [(path: Path, evenOdd: Bool)] = {
        var path = Path(CGRect(x: 0.26, y: -1.35, width: 0.13, height: 2.55))
        path.addRect(CGRect(x: 0.66, y: -1.2, width: 0.13, height: 2.55))
        let bars = polygon([(0, -0.79), (1.05, -0.55), (1.05, -0.11), (0, -0.35)])
        let upper = polygon([(0, 0.11), (1.05, 0.35), (1.05, 0.79), (0, 0.55)])
        return [(path: path, evenOdd: false), (path: bars, evenOdd: false), (path: upper, evenOdd: false)]
    }()

    private static func flat(at x: CGFloat) -> [(path: Path, evenOdd: Bool)] {
        let stem = Path(CGRect(x: x + 0.02, y: -0.55, width: 0.13, height: 2.95))
        var bowl = Path()
        bowl.move(to: CGPoint(x: x + 0.1, y: 0.3))
        bowl.addCurve(to: CGPoint(x: x + 0.9, y: 0.45), control1: CGPoint(x: x + 0.35, y: 0.75), control2: CGPoint(x: x + 0.85, y: 0.85))
        bowl.addCurve(to: CGPoint(x: x + 0.1, y: -0.55), control1: CGPoint(x: x + 0.95, y: 0.05), control2: CGPoint(x: x + 0.45, y: -0.3))
        bowl.closeSubpath()
        bowl.move(to: CGPoint(x: x + 0.14, y: 0.1))
        bowl.addCurve(to: CGPoint(x: x + 0.62, y: 0.38), control1: CGPoint(x: x + 0.3, y: 0.4), control2: CGPoint(x: x + 0.55, y: 0.5))
        bowl.addCurve(to: CGPoint(x: x + 0.14, y: -0.36), control1: CGPoint(x: x + 0.7, y: 0.15), control2: CGPoint(x: x + 0.4, y: -0.15))
        bowl.closeSubpath()
        return [(path: stem, evenOdd: false), (path: bowl, evenOdd: true)]
    }

    private static let natural: [(path: Path, evenOdd: Bool)] = {
        var path = Path(CGRect(x: 0.06, y: -0.6, width: 0.13, height: 2.05))
        path.addRect(CGRect(x: 0.65, y: -1.45, width: 0.13, height: 2.05))
        let lower = polygon([(0.06, -0.62), (0.78, -0.42), (0.78, -0.02), (0.06, -0.22)])
        let upper = polygon([(0.06, 0.02), (0.78, 0.22), (0.78, 0.62), (0.06, 0.42)])
        return [(path: path, evenOdd: false), (path: lower, evenOdd: false), (path: upper, evenOdd: false)]
    }()

    private static let doubleSharp: [(path: Path, evenOdd: Bool)] = {
        var path = Path()
        path.addLines([CGPoint(x: 0, y: 0.47), CGPoint(x: 0.47, y: 0), CGPoint(x: 0, y: -0.47), CGPoint(x: 0.2, y: -0.47),
                       CGPoint(x: 0.47, y: -0.2), CGPoint(x: 0.74, y: -0.47), CGPoint(x: 0.94, y: -0.47), CGPoint(x: 0.47, y: 0),
                       CGPoint(x: 0.94, y: 0.47), CGPoint(x: 0.74, y: 0.47), CGPoint(x: 0.47, y: 0.2), CGPoint(x: 0.2, y: 0.47)])
        path.closeSubpath()
        return [(path: path, evenOdd: false)]
    }()

    // MARK: Rests (origin: the left edge, on the middle line; a whole rest on the fourth line)

    private static let quarterRest: [(path: Path, evenOdd: Bool)] = {
        let points: [(CGFloat, CGFloat)] = [(0.30, 1.55), (0.92, 0.72), (0.62, 0.32), (0.98, -0.45), (0.80, -0.58), (0.52, -0.70),
                                            (0.42, -0.95), (0.52, -1.25), (0.72, -1.52), (0.58, -1.55), (0.24, -1.30), (0.16, -0.95),
                                            (0.30, -0.60), (0.56, -0.38), (0.30, 0.15), (0.60, 0.62), (0.14, 1.30)]
        return [(path: polygon(points), evenOdd: false)]
    }()

    /// An eighth rest (one ball) or a sixteenth (two), on a slanted stem.
    private static func restWithBalls(_ count: Int) -> [(path: Path, evenOdd: Bool)] {
        var parts: [(path: Path, evenOdd: Bool)] = []
        let top = CGPoint(x: count == 1 ? 0.98 : 1.18, y: 0.75)
        let bottom = CGPoint(x: count == 1 ? 0.55 : 0.55, y: count == 1 ? -1.0 : -2.0)
        var stem = Path()
        stem.addLines([CGPoint(x: top.x - 0.07, y: top.y), CGPoint(x: top.x + 0.07, y: top.y),
                       CGPoint(x: bottom.x + 0.07, y: bottom.y), CGPoint(x: bottom.x - 0.07, y: bottom.y)])
        stem.closeSubpath()
        parts.append((path: stem, evenOdd: false))
        for k in 0..<count {
            let drop = CGFloat(k)
            let centre = CGPoint(x: 0.3 - 0.22 * drop, y: 0.55 - drop)
            let reach = CGPoint(x: top.x - 0.24 * drop, y: top.y - drop)
            parts.append((path: ball(centre, 0.24), evenOdd: false))
            let arm = stroke([CGPoint(x: centre.x, y: centre.y - 0.08), CGPoint(x: centre.x + 0.32, y: centre.y - 0.16), reach],
                             widths: [0.14, 0.11, 0.1], samples: 10)
            parts.append((path: arm, evenOdd: false))
        }
        return parts
    }

    // MARK: Flags (origin: the stem's tip)

    private static func flag(down: Bool) -> Path {
        let sign: CGFloat = down ? 1 : -1
        let points: [CGPoint] = [CGPoint(x: 0.02, y: 0.12 * sign), CGPoint(x: 0.22, y: 0.75 * sign), CGPoint(x: 0.78, y: 1.42 * sign),
                                 CGPoint(x: 0.98, y: 2.2 * sign), CGPoint(x: 0.66, y: 3.0 * sign)]
        return stroke(points.map { CGPoint(x: $0.x, y: -$0.y) }, widths: [0.34, 0.30, 0.22, 0.12, 0.04], samples: 14)
    }
}
