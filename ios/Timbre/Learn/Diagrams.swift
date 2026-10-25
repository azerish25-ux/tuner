import SwiftUI
import TimbreCore

/// The picture on a lesson card. Given `room` (a quiz's card), it grows to fill it: the neck's rows, the chord
/// box's frets, the staff and the keys get as big as the card allows; without it, each is drawn at its plain size.
struct LessonVisualView: View {
    let visual: LessonVisual
    var accent: Color = Palette.mint
    var instrumentId: String?
    /// The room the picture may fill; nil draws it at its plain size.
    var room: CGSize?

    var body: some View {
        switch visual {
        case .none: EmptyView()
        case let .fretboard(strings, dots, frets, start):
            FretboardDiagram(strings: strings, dots: dots, frets: frets, accent: accent, start: start, fretless: fretless,
                             rowHeight: neckRowHeight(strings: strings, frets: frets, start: start),
                             edges: StringEdges.of(instrumentId: instrumentId, strings: strings), fretNumbers: !fretless)
        case let .chord(spec):
            chord(spec)
        case let .staff(midi, clef): StaffView(notes: midi, clef: clef, accent: accent, lineGap: staffGap)
        case let .rhythm(pattern, beatsPerBar): RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, arrows: strums)
        case let .keyboard(midi): KeyboardView(highlighted: Set(midi), accent: accent, height: keysHeight)
        case let .instrument(part): InstrumentPartView(part: part, instrumentId: instrumentId, accent: accent, height: room.map { max(200, $0.height) } ?? 260)
        case let .clip(name): LessonClipView(name: name, height: room.map { max(200, $0.height) } ?? 240)
        }
    }

    /// Strummed instruments read rhythm patterns as down and up strokes.
    private var strums: Bool { LearnCourse.strummed(instrumentId) }
    private var fretless: Bool { ["violin", "cello"].contains { instrumentId?.hasPrefix($0) == true } }

    private func neckRowHeight(strings: Int, frets: Int, start: Int) -> CGFloat {
        guard let room else { return 26 }
        return FretboardDiagram.rowHeight(filling: room, strings: strings, frets: frets, start: start, named: strings >= 2, numbered: !fretless)
    }

    /// The chord in the picture the learner chose (the chart or the player's view), as big as the room allows.
    private func chord(_ spec: ChordSpec) -> some View {
        let fit = room.map { ChordDiagram.fit(spec, room: $0) } ?? (width: CGFloat(220), stretch: CGFloat(1))
        return ChordPictureView(chord: spec, accent: accent, landing: true, edges: StringEdges.of(instrumentId: instrumentId, strings: spec.frets.count),
                                fretNumbers: room != nil, stretch: fit.stretch)
            .frame(maxWidth: fit.width)
    }

    private var staffGap: CGFloat { room.map { StaffView.lineGap(filling: $0.height) } ?? 11 }
    private var keysHeight: CGFloat { room.map { min(170, max(110, $0.height)) } ?? 110 }
}

/// Which string sits on top wherever a neck is drawn lying down (the fretboard strips, the Scales and intonation
/// necks, the tune check; the strum stage is `.mirror`, so a down strum falls down the screen): the app's one picture
/// choice (`ChordPicture`, Settings › String order, the Chart / Player view switch on a chord card) read as a string
/// order. It is the same stored value, under the same key, so the necks and the chords can never disagree:
/// - `.tab` is Chart (the default): string 1, the thinnest, on top as tablature writes it, the chord chart's box
///   being that strip turned upright (the lowest string on the left);
/// - `.mirror` is Player view: the thickest string on top, as you see the neck looking down at it while playing,
///   so a down strum falls down the screen.
/// Where strings stand upright side by side instead (the play-along runway's lanes, the paywall's runway, the
/// player's-view chord neck `PlayerNeck`), they run from the lowest string on the left (`upright`), as the chord chart
/// and a photograph of the instrument show them: in the Chart view that is the tab strip turned upright, in Player
/// view the string on top taking the left, so flipping between the two never mirrors a chord.
///
/// The player's hold (Settings › Handedness, `HandStyle`) turns these for a left-handed player: a neck lying down
/// takes its order and nut side from `HandStyle.lying(_:)`, upright lanes from `lanes(for:)`, the strum stage from
/// `HandStyle.strumOrder`.
///
/// In a view: `@AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab`, then
/// `stringOrder.row(ofString:count:)` for where string n goes; elsewhere `StringOrder.current`. Change it through
/// `ChordPicture` (the switch, Settings), never on its own.
enum StringOrder: String, CaseIterable, Identifiable {
    /// String 1, the thinnest, on top: the Chart view (the default). Stored as `ChordPicture.chart`.
    case tab = "chart"
    /// The thickest string on top: the Player view. Stored as `ChordPicture.player`.
    case mirror = "player"

    /// The picture choice's key: one stored value, two ways to read it.
    static let storageKey = ChordPicture.storageKey

    /// The stored choice, for code outside a view (views read it through `@AppStorage` so they redraw).
    static var current: StringOrder { ChordPicture.current.stringOrder }

    /// Strings standing upright side by side, read as lanes counted from the left (`row(ofString:count:)` 0 is the
    /// left lane): the lowest string on the left in either view, as on a right-handed chord chart (a left-handed
    /// player's lanes: `lanes(for:)`).
    static let upright: StringOrder = .mirror

    var id: String { rawValue }

    var thinnestOnTop: Bool { self == .tab }

    /// The row, counted from the top (0), of string `number` (1 is string 1) on an instrument with `count` strings.
    func row(ofString number: Int, count: Int) -> Int { self == .tab ? number - 1 : count - number }

    /// The string number drawn in row `row` (0 at the top): the inverse of `row(ofString:count:)`.
    func string(atRow row: Int, count: Int) -> Int { self == .tab ? row + 1 : count - row }

    /// The other order: the other string on top, or the other string in the left lane.
    var reversed: StringOrder { self == .tab ? .mirror : .tab }

    /// Strings standing upright side by side for a player holding the instrument as `hand` says: the lowest string on
    /// the left (`upright`), or on the right on a left-handed instrument. Read as lanes counted from the left.
    static func lanes(for hand: HandStyle) -> StringOrder { hand.mirrorsUpright ? .tab : .mirror }
}

// MARK: - The player's hand

/// How the player holds the instrument (Settings › Handedness, `UserSettings.handedness`), as every picture of it
/// reads it:
/// - `.right`: the pictures as drawn.
/// - `.left`: a left-handed instrument, the mirror image of a right-handed one. Every neck and chord picture is its mirror
///   image (a neck lying across the screen has its nut on the right, a chord box its lowest string on the right), and so
///   is the 3D instrument, its pegs turning the other way.
/// - `.leftUpsideDown`: a right-handed instrument turned over and played left-handed, string 1 nearest the face. A neck
///   lying across the screen has its nut on the right and string 1 on top, as the player sees it, and a strum falls from
///   string 1. Standing up (a chord box, the player's-view neck, the 3D headstock), it is the right-handed instrument it is.
/// Words are never mirrored, and every string keeps its number (1 is the thinnest) whichever way it is held.
extension Handedness {
    /// The fretting hand is the right one: a neck lying across the screen has its nut on the right.
    var nutOnRight: Bool { self != .right }
    /// The instrument is the mirror image of a right-handed one (strung left-handed).
    var mirrorsInstrument: Bool { self == .left }
    /// String 1, the thinnest, lies nearest the face: on top of a neck lying across the screen, and first under a strum.
    var thinnestOnTop: Bool { self == .leftUpsideDown }
}

/// The player's hold with Settings › Charts as printed, and what each kind of picture makes of them. Views read it with
/// `@CurrentHand`; a screen can hand it down with `.handStyle(_:)`.
struct HandStyle: Equatable, Sendable {
    var hand: Handedness = .right
    /// Chord charts (the chord box, and the Chart view's necks lying across the screen) stay as songbooks print them.
    var chartsAsPrinted = false

    static let standard = HandStyle()

    init(hand: Handedness = .right, chartsAsPrinted: Bool = false) {
        self.hand = hand
        self.chartsAsPrinted = chartsAsPrinted
    }

    /// From the player's settings.
    init(_ settings: UserSettings) {
        self.init(hand: settings.handedness, chartsAsPrinted: settings.chartsAsPrinted)
    }

    /// The chord box (`ChordDiagram`) is drawn as its mirror image.
    var mirrorsChordChart: Bool { hand.mirrorsInstrument && !chartsAsPrinted }
    /// The instrument standing up (the player's-view neck in perspective, a runway's lanes, the 3D and studio stages) is
    /// drawn as its mirror image.
    var mirrorsUpright: Bool { hand.mirrorsInstrument }

    /// A neck lying across the screen in the picture choice `picture` (`.tab`, the Chart view; `.mirror`, Player view):
    /// which string lies on top, and whether the nut is on the right.
    func lying(_ picture: StringOrder) -> (order: StringOrder, nutOnRight: Bool) {
        if picture == .tab && chartsAsPrinted { return (picture, false) }
        return (hand.thinnestOnTop ? .tab : picture, hand.nutOnRight)
    }

    /// The strum stage's strings (thickest on top as a right-hander holds it, so a down strum falls down the screen):
    /// string 1 on top for a player holding the instrument upside down, whose down strum falls from string 1.
    var strumOrder: StringOrder { hand.thinnestOnTop ? .tab : .mirror }
}

private struct HandStyleKey: EnvironmentKey {
    static let defaultValue: HandStyle? = nil
}

extension EnvironmentValues {
    /// The hold the pictures below are drawn for; nil reads it from the player's settings (`CurrentHand`).
    var handStyle: HandStyle? {
        get { self[HandStyleKey.self] }
        set { self[HandStyleKey.self] = newValue }
    }
}

extension View {
    /// Draws every neck and chord picture inside for `settings`' hold.
    func handStyle(_ settings: UserSettings) -> some View {
        environment(\.handStyle, HandStyle(settings))
    }
}

/// The hold to draw for: the one handed down (`View.handStyle`), else the player's settings. Redraws when they change.
@MainActor @propertyWrapper
struct CurrentHand: DynamicProperty {
    @Environment(\.handStyle) private var given
    @EnvironmentObject private var store: AppStore

    init() {}

    var wrappedValue: HandStyle { given ?? HandStyle(store.settings) }
}

/// Drawing a picture mirrored: its shapes go through a context turned over left to right, its words are set at the
/// mirrored points (never mirrored themselves).
struct CanvasMirror {
    let on: Bool
    let width: CGFloat

    func x(_ value: CGFloat) -> CGFloat { on ? width - value : value }
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: x(p.x), y: p.y) }
    func anchor(_ anchor: UnitPoint) -> UnitPoint { on ? UnitPoint(x: 1 - anchor.x, y: anchor.y) : anchor }

    /// A copy of `context` that draws mirrored.
    func shapes(_ context: GraphicsContext) -> GraphicsContext {
        guard on else { return context }
        var mirrored = context
        mirrored.translateBy(x: width, y: 0)
        mirrored.scaleBy(x: -1, y: 1)
        return mirrored
    }
}

/// Which strings are the thinnest and the thickest, so every diagram can name its edges in words
/// ("Thinnest (1)" on one side, "Thickest (6)" on the other) whichever way it is drawn. On reentrant
/// tunings (ukulele, banjo) the thickest string sits inside the set, and an edge that is neither stays unnamed.
struct StringEdges: Equatable {
    let thinnest: Int
    let thickest: Int

    init(thinnest: Int, thickest: Int) { self.thinnest = thinnest; self.thickest = thickest }

    /// From the open strings, lowest string first (as `ChordStep.openStrings`): string 1 is the thinnest,
    /// the lowest-pitched string the thickest.
    init?(openStrings: [Int]) {
        guard openStrings.count >= 2, let low = openStrings.indices.min(by: { openStrings[$0] < openStrings[$1] }) else { return nil }
        self.init(thinnest: 1, thickest: openStrings.count - low)
    }

    /// The course instrument's edges; a plain run from 1 to `strings` when the tuning isn't known.
    static func of(instrumentId: String?, strings: Int) -> StringEdges? {
        let open = ChordStep.openStrings(kind: LearnCourse.fretKind(of: instrumentId))
        if open.count == strings, let edges = StringEdges(openStrings: open) { return edges }
        return strings >= 2 ? StringEdges(thinnest: 1, thickest: strings) : nil
    }

    static func of(_ course: LearnCourse) -> StringEdges? { of(instrumentId: course.instrument, strings: course.stringCount) }

    /// The words for the string on an edge; nil when it is neither the thinnest nor the thickest.
    func label(_ string: Int) -> Text? {
        if string == thinnest { return Text("Thinnest (\(string))") }
        if string == thickest { return Text("Thickest (\(string))") }
        return nil
    }

    /// Just the word, for a place that already shows the string's number beside it (the highway's targets).
    func word(_ string: Int) -> Text? {
        if string == thinnest { return Text("Thinnest") }
        if string == thickest { return Text("Thickest") }
        return nil
    }

    /// The same, styled for drawing into a Canvas: never under the diagrams' 11 pt floor (`DiagramType`).
    func canvasLabel(_ string: Int, size: CGFloat = DiagramType.floor) -> Text? {
        label(string)?.font(DiagramType.font(size, weight: .semibold)).foregroundStyle(Palette.inkSoft)
    }
}

/// The smallest type a diagram draws (string names and numbers, fret numbers, edge and lane names): never under
/// 11 pt, the size of `.caption2`, and growing with Dynamic Type as `.caption2` does, up to `cap` times, so a
/// drawing keeps its layout at the largest sizes. A view reads its scale with
/// `@ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1` and passes it in.
enum DiagramType {
    static let floor: CGFloat = 11
    static let cap: CGFloat = 1.3

    /// `points` (raised to the floor) grown by the Dynamic Type `scale`, within the cap.
    static func size(_ points: CGFloat, scale: CGFloat = 1) -> CGFloat {
        max(Self.floor, points) * min(Self.cap, max(1, scale))
    }

    static func font(_ points: CGFloat = DiagramType.floor, weight: Font.Weight = .bold, scale: CGFloat = 1) -> Font {
        .system(size: size(points, scale: scale), weight: weight, design: .rounded)
    }
}

/// A stretch of neck, nut on the left, dots where to press, its strings in the player's string order
/// (string 1 on top in the Chart view, the default, as in tab; the thickest on top in Player view). For a left-handed
/// player the nut is on the right, and held upside down string 1 is on top (`HandStyle.lying`).
/// Every string is numbered beside the nut, and the top and bottom edges are named ("Thinnest (1)",
/// "Thickest (6)"), so the orientation never has to be guessed. Lessons number the frets under their
/// columns too, as the Scales neck does, the frets holding a dot lit.
struct FretboardDiagram: View {
    let strings: Int
    var dots: [Fretting] = []
    var frets: Int = 5
    var accent: Color = Palette.mint
    /// Fret number at the left edge; 1 draws the nut, higher shows a position label instead.
    var start: Int = 1
    /// Live highlight: the string being played right now.
    var activeString: Int?
    /// Violin and cello: an ebony fingerboard with finger-position tapes instead of frets.
    var fretless = false
    /// Height per string; lessons draw a compact strip under the note ring.
    var rowHeight: CGFloat = 26
    /// The dots (and the lit string) breathe: the target to play right now.
    var pulsing = false
    /// Names the top and bottom edges in words; nil leaves just the numbers.
    var edges: StringEdges?
    /// A demonstration: per dot (in `dots` order), 0 before it lands, then dropping onto its string as it grows
    /// to 1 (a spring may overshoot). Nil draws every dot in place.
    var landing: [Double]?
    /// Numbers every fret under its column (the ones holding a dot lit), standing in for the "5fr" label.
    /// Fretless boards have no frets to number.
    var fretNumbers = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    @CurrentHand private var hand
    /// String numbers, fret numbers and edge names grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    var body: some View {
        let lie = hand.lying(stringOrder)
        let scale = typeScale
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !pulsing || reduceMotion)) { timeline in
            let beat = pulsing && !reduceMotion ? 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2) : 0
            Canvas { context, size in
                draw(&context, size: size, beat: beat, order: lie.order, mirror: CanvasMirror(on: lie.nutOnRight, width: size.width), scale: scale)
            }
        }
        .frame(height: height)
        .accessibilityIgnoresInvertColors()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibility))
    }

    /// The row under the board for the "5fr" position label.
    private static let positionRow: CGFloat = 16
    /// The row under the board for the fret numbers.
    private static let numberRow: CGFloat = 16
    /// Centre of the string-number column, left of the open-string rings.
    private static let numberX: CGFloat = 8
    /// The nut's x: the number column and the open-string rings sit left of it.
    private static let nutX: CGFloat = 44
    /// A row above and below the board for the edge names.
    private static let edgeRow: CGFloat = 14
    /// Rows from this tall are a big neck (an explanation's or a quiz's card): bigger dots, more room around them.
    private static let tallRow: CGFloat = 36

    /// Room above the first string and below the last: the board's edge plus a whole finger dot and its
    /// halo, so a dot on an outer string is never cut off.
    private var pad: CGFloat { rowHeight >= Self.tallRow ? 28 : 22 }
    /// The finger dots' largest radius: 15 on the compact strips, growing with the rows on a big neck.
    private var dotCap: CGFloat { rowHeight >= Self.tallRow ? min(22, rowHeight * 0.4) : 15 }
    private var tall: Bool { rowHeight >= Self.tallRow }
    private var numbered: Bool { fretNumbers && !fretless }
    private var edgeLift: CGFloat { edges != nil && strings >= 2 ? Self.edgeRow : 0 }
    /// The row under the board: the fret numbers, else the "5fr" label when the neck starts up the board.
    private var footRow: CGFloat { numbered ? Self.numberRow : (start > 1 ? Self.positionRow : 0) }

    private var height: CGFloat {
        CGFloat(max(4, strings)) * rowHeight + 10 + 2 * (pad - 14) + footRow + 2 * edgeLift
    }

    /// The row height that fills `room` with a neck: the rows grow (up to 54 pt) until the drawing is as tall as
    /// the room, but a fret's cell never gets much taller than it is wide. `named`: the edges are named;
    /// `numbered`: the frets are numbered.
    static func rowHeight(filling room: CGSize, strings: Int, frets: Int, start: Int, named: Bool, numbered: Bool) -> CGFloat {
        let rows = CGFloat(max(4, strings))
        let extras = (named ? 2 * edgeRow : 0) + (numbered ? numberRow : (start > 1 ? positionRow : 0))
        // The drawing is rows × row + 10 + 2 × (pad − 14) + extras tall, its pad 28 on tall rows and 22 below them.
        let roomy = (room.height - 10 - 28 - extras) / rows
        let fill = roomy >= tallRow ? roomy : min(tallRow - 0.5, (room.height - 10 - 16 - extras) / rows)
        let fretWidth = (room.width - nutX - 10) / CGFloat(max(1, frets))
        return min(54, max(22, min(fill, max(26, fretWidth * 1.1))))
    }

    /// Strings get thicker toward the bass (string 1, the highest, is the thinnest); the lower ones are wound.
    private func gauge(_ string: Int) -> CGFloat {
        strings > 1 ? CGFloat(string - 1) / CGFloat(strings - 1) : 0.5
    }

    /// Draws the neck nut-left; `mirror` turns the shapes over for a nut on the right and sets the words at the mirrored
    /// points, so they read as usual.
    private func draw(_ context: inout GraphicsContext, size: CGSize, beat: Double, order: StringOrder, mirror: CanvasMirror, scale: CGFloat) {
        let shapes = mirror.shapes(context)
        let lift = edgeLift
        let left = Self.nutX, right = size.width - 10, top = pad + lift
        let bottom = size.height - pad - footRow - lift
        let count = max(1, strings)
        if let edges, lift > 0 {
            // The top string's name over its number ("Thinnest (1)" in tab order), the bottom string's under its own.
            let topString = order.string(atRow: 0, count: count), bottomString = order.string(atRow: count - 1, count: count)
            let points = DiagramType.size(DiagramType.floor, scale: scale)
            if let name = edges.canvasLabel(topString, size: points) {
                context.draw(name, at: mirror.point(CGPoint(x: 2, y: lift / 2 + 1)), anchor: mirror.anchor(.leading))
            }
            if let name = edges.canvasLabel(bottomString, size: points) {
                context.draw(name, at: mirror.point(CGPoint(x: 2, y: size.height - lift / 2 - 1)), anchor: mirror.anchor(.leading))
            }
        }
        let fretWidth = (right - left) / CGFloat(frets)
        let gap = strings > 1 ? (bottom - top) / CGFloat(strings - 1) : 0
        // String n's y, in the player's string order.
        func rowY(_ string: Int) -> CGFloat { top + CGFloat(order.row(ofString: string, count: count)) * gap }
        let board = Path(roundedRect: CGRect(x: left, y: top - 10, width: right - left, height: bottom - top + 20), cornerRadius: 8)
        shapes.fill(board, with: .linearGradient(Gradient(colors: fretless ? [Color(hex: 0x1C1C1E), Color(hex: 0x0E0E10)] : [Color(hex: 0x2A1E17), Color(hex: 0x1A120E)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        for marker in [3, 5, 7, 9, 12, 15] where marker >= start && marker < start + frets && !fretless {
            let x = left + (CGFloat(marker - start + 1) - 0.5) * fretWidth
            shapes.fill(Path(ellipseIn: CGRect(x: x - 4, y: (top + bottom) / 2 - 4, width: 8, height: 8)), with: .color(.white.opacity(0.18)))
        }
        if start <= 1 {
            shapes.fill(Path(CGRect(x: left - 3, y: top - 10, width: 6, height: bottom - top + 20)), with: .color(Color(hex: 0xEDE4D3)))
        } else if !numbered {
            context.draw(Text("\(start)fr").font(DiagramType.font(11, weight: .semibold, scale: scale)).foregroundStyle(Palette.inkSoft),
                         at: mirror.point(CGPoint(x: left + fretWidth / 2, y: size.height - lift - 13)))
        }
        if numbered {
            drawFretNumbers(&context, left: left, fretWidth: fretWidth, y: bottom + pad + Self.numberRow / 2 - 2, mirror: mirror, scale: scale)
        }
        for fret in 1...frets {
            let x = left + CGFloat(fret) * fretWidth
            if fretless {
                // Tapes where first-position fingers land (whole tone, major third, fourth, fifth).
                guard [2, 4, 5, 7].contains(fret) else { continue }
                let tape = left + (CGFloat(fret) - 0.5) * fretWidth
                shapes.fill(Path(CGRect(x: tape - 1.5, y: top - 10, width: 3, height: bottom - top + 20)), with: .color(Color(hex: 0xEDE4D3).opacity(0.35)))
            } else {
                shapes.fill(Path(CGRect(x: x - 1, y: top - 10, width: 2, height: bottom - top + 20)), with: .color(Color(hex: 0xB9B2A6).opacity(0.8)))
            }
        }
        for string in 1...count {
            let y = rowY(string)
            let g = gauge(string)
            let thickness = 1 + g * 2.4
            let wound = strings >= 4 && g > 0.45
            let lit = activeString == string
            if lit {
                let glow = 0.14 + 0.16 * beat
                let band = tall ? max(10, gap * 0.24) : 10
                shapes.fill(Path(CGRect(x: left, y: y - band / 2, width: right - left, height: band)), with: .color(accent.opacity(pulsing ? glow : 0.22)))
            }
            let tone = wound ? Color(hex: 0xCDB892) : Color(hex: 0xE2DDD3)
            shapes.fill(Path(CGRect(x: left, y: y - thickness / 2, width: right - left, height: thickness)),
                        with: .color(lit ? accent : tone.opacity(0.88)))
            if wound && !lit {
                // A thin highlight along the top of a wound string.
                shapes.fill(Path(CGRect(x: left, y: y - thickness / 2, width: right - left, height: 0.6)), with: .color(.white.opacity(0.28)))
            }
            drawNumber(&context, string: string, y: y, lit: lit, mirror: mirror, scale: scale)
        }
        for (k, dot) in dots.enumerated() where dot.string >= 1 && dot.string <= strings {
            // Landing: hidden until its turn, then it falls the last few points onto the string as it grows.
            let land = CGFloat(landing?[safe: k] ?? 1)
            guard land > 0.01 else { continue }
            // A landing dot falls the last 14 points onto its string, never from above the drawing's top edge.
            let drop = (1 - min(1, land)) * 14
            let swell = CGFloat(beat) * 5
            if dot.fret == 0 {
                let side = (tall ? 10 : 8) * land
                let glow = pulsing ? 8 + 3 + swell : side
                let center = CGPoint(x: left - 14, y: max(rowY(dot.string) - drop, glow + 1))
                if pulsing {
                    shapes.fill(Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)), with: .color(accent.opacity(0.18 + 0.14 * beat)))
                }
                let ring = Path(ellipseIn: CGRect(x: center.x - side, y: center.y - side, width: side * 2, height: side * 2))
                shapes.stroke(ring, with: .color(accent), lineWidth: tall ? 3 : 2.5)
            } else {
                let x = left + (CGFloat(min(max(1, dot.fret - start + 1), frets)) - 0.5) * fretWidth
                // Never wider than its fret's cell, so a dot doesn't sit on the fret wires.
                let r: CGFloat = min(dotCap, gap * 0.48 + 4, fretWidth * 0.42) * land
                // Capped by the padding, so the halo of a dot on string 1 stays inside the drawing.
                let halo = min(pad - 1, r + 4 + (pulsing ? swell : 0))
                let y = max(rowY(dot.string) - drop, halo + 1)
                shapes.fill(Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)), with: .color(accent.opacity(pulsing ? 0.2 + 0.15 * beat : 0.25)))
                shapes.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                if land > 0.6, let finger = dot.finger, finger > 0 {
                    context.draw(Text("\(finger)").font(.system(size: r, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent),
                                 at: mirror.point(CGPoint(x: x, y: y)))
                }
            }
        }
    }

    /// The string's number in the column beside the nut; the string being played lights with it. Never under the
    /// 11 pt floor, even on the tune check's compact strip (its rows are 15 pt apart, room for an 11 pt numeral).
    private func drawNumber(_ context: inout GraphicsContext, string: Int, y: CGFloat, lit: Bool, mirror: CanvasMirror, scale: CGFloat) {
        let label = Text("\(string)").font(DiagramType.font(tall ? 13 : 11, scale: scale))
            .foregroundStyle(lit ? accent : Palette.inkSoft.opacity(0.85))
        context.draw(label, at: mirror.point(CGPoint(x: Self.numberX, y: y)))
    }

    /// Each fret's number under its column, as on the Scales neck; the frets holding a landed dot light up.
    private func drawFretNumbers(_ context: inout GraphicsContext, left: CGFloat, fretWidth: CGFloat, y: CGFloat, mirror: CanvasMirror, scale: CGFloat) {
        var held = Set<Int>()
        for (k, dot) in dots.enumerated() where dot.fret > 0 && (landing?[safe: k] ?? 1) > 0.6 { held.insert(dot.fret) }
        let size: CGFloat = tall ? 12 : 11
        for column in 0..<max(1, frets) {
            let fret = start + column
            let lit = held.contains(fret)
            let label = Text("\(fret)").font(DiagramType.font(size, weight: lit ? .heavy : .semibold, scale: scale))
                .foregroundStyle(lit ? accent : Palette.inkFaint)
            context.draw(label, at: mirror.point(CGPoint(x: left + (CGFloat(column) + 0.5) * fretWidth, y: y)))
        }
    }

    private var accessibility: String {
        dots.map { $0.fret == 0 ? String(localized: "string \($0.string) open") : String(localized: "string \($0.string), fret \($0.fret)") }.joined(separator: "; ")
    }
}

/// A chord box as chord charts print it (the Chart view's chord, `ChordPicture.chart`): strings upright, nut on
/// top, the lowest string on the left and string 1 on the right, finger numbers in the dots, open and muted marks
/// above, a rounded bar where one finger holds several strings, and the string numbers along the bottom. It is the
/// tab-order strip (`FretboardDiagram`) turned upright. For a left-handed player it is its mirror image, the lowest
/// string on the right, unless Settings › Charts as printed keeps it as songbooks print it (`HandStyle`). A shape
/// played behind a capo has the capo across the top in place of the nut, its fingers counted from it, and says so
/// under the box ("G shape · capo 2"). Places that show a chord without the switch use `ChordPictureView`, which
/// draws this or the player's view as chosen.
struct ChordDiagram: View {
    let chord: ChordSpec
    var accent: Color = Palette.mint
    var showName = true
    /// Strings that rang in the last reading (lowest string first), lit while the learner plays.
    var ringing: Set<Int> = []
    /// Keep the fret-label column even for open shapes, so a set of diagrams shares one grid size (Chords tool).
    var reservesFretLabel = false
    /// Lessons: fingers land one by one when the diagram first appears. Off by default (the Chords tool stays still).
    var landing = false
    /// The order the fingers land in: string by string, or finger 1 first (a demonstration).
    var landingOrder: LandingOrder = .strings
    /// Seconds between one finger landing and the next.
    var landingStep: Double = 0.08
    /// Changing it lands the fingers again (the demonstration replays).
    var replay = 0
    /// Names the outer strings under the box ("Thickest (6)" … "Thinnest (1)"); nil leaves just the numbers.
    var edges: StringEdges?
    /// Numbers each fret beside its row, left of the box (lit where a finger sits), standing in for the "5fr" label.
    var fretNumbers = false
    /// How much taller than plain the frets are drawn (1 to 1.5), so a lesson's box can fill its card.
    var stretch: CGFloat = 1
    /// Drawn as its mirror image (a left-handed player's chart); nil follows the player's hold (`CurrentHand`). Code
    /// that measures the box outside a view (`stringPositions`) passes the hold's `mirrorsChordChart`.
    var mirrored: Bool?
    @State private var landStart: Date?
    @State private var landed = false
    @State private var landGeneration = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @CurrentHand private var hand
    /// String and fret numbers grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    enum LandingOrder { case strings, fingers }

    /// Its name over the box and the edge names under it, with the gaps between them.
    static let chrome: CGFloat = 62
    /// The capo's line under the box ("G shape · capo 2") with the gap above it.
    static let capoLine: CGFloat = 24

    /// The width and stretch that fill `room` with a chord's box: its name and edge names (`chrome`, and the capo's
    /// line) around a box 5.4 rows tall for every string gap across at plain proportions, the frets drawn up to half as
    /// tall again when there's height to spare, and narrower than `maxWidth` only when the room is short.
    static func fit(_ chord: ChordSpec, room: CGSize, maxWidth: CGFloat = 340, minWidth: CGFloat = 170) -> (width: CGFloat, stretch: CGFloat) {
        let count = CGFloat(max(2, chord.frets.count))
        let boxRoom = max(0, room.height - chrome - (chord.drawnCapo > 0 ? capoLine : 0))
        let width = max(minWidth, min(maxWidth, room.width))
        let plain = width * 5.4 / count
        if boxRoom >= plain { return (width, min(1.45, boxRoom / plain)) }
        return (max(minWidth, min(width, boxRoom * count / 5.4)), 1)
    }

    /// The column beside the box for the fret numbers or the "5fr" label (a capo's shape needs neither).
    private var labelColumn: CGFloat {
        let upTheNeck = chord.drawnCapo == 0 && (chord.baseFret ?? 1) > 1
        return (reservesFretLabel || fretNumbers || upTheNeck) ? 20 : 0
    }

    /// A finger dot's radius is at most 0.38 of the string gap, and a landing dot overshoots it by up to 9 %.
    private static let dotReach: CGFloat = 0.38 * 1.09
    /// Past the dot: its halo (3) and two points of air.
    private static let dotAir: CGFloat = 5
    /// The least margin beside an outer string: room for its open ring or muted cross over the nut.
    private static let sideFloor: CGFloat = 10

    /// The lowest string's x and the gap between strings across a canvas `width` wide (drawn as a right-hander's
    /// chart; a mirrored one is turned over afterwards). Each side keeps exactly the room a whole finger dot needs on
    /// an outer string (its radius at the largest, its halo and its landing overshoot; a barre's rounded end the same),
    /// so a dot on string 1 or the lowest string is never cut off at any size; the fret-number column sits beside
    /// that. The margins grow with the box, so a big box keeps its dots inside and a small one doesn't waste its width
    /// on empty margins.
    private func stringSpan(width: CGFloat) -> (first: CGFloat, gap: CGFloat) {
        let count = chord.frets.count
        let room = max(0, width - labelColumn)
        guard count > 1 else { return (labelColumn + room / 2, 0) }
        let spans = CGFloat(count - 1)
        // Both margins are `dotReach × gap + dotAir`: solve for the gap that fills the rest.
        var gap = (room - 2 * Self.dotAir) / (spans + 2 * Self.dotReach)
        if Self.dotReach * gap + Self.dotAir < Self.sideFloor { gap = (room - 2 * Self.sideFloor) / spans }
        gap = max(0, gap)
        let side = max(Self.sideFloor, Self.dotReach * gap + Self.dotAir)
        return (labelColumn + side, gap)
    }

    /// Where each string's line runs across a box `width` wide (lowest string first), so a row drawn over the
    /// box (the lesson's string checks) lines up with it; mirrored when `mirrored` is set.
    func stringPositions(width: CGFloat) -> [CGFloat] {
        let span = stringSpan(width: width)
        let mirror = CanvasMirror(on: mirrored ?? false, width: width)
        return (0..<chord.frets.count).map { mirror.x(span.first + CGFloat($0) * span.gap) }
    }

    var body: some View {
        let flip = mirrored ?? hand.mirrorsChordChart
        VStack(spacing: 8) {
            if showName { Text(chord.name).font(Typeface.display(.title)).foregroundStyle(Palette.ink) }
            TimelineView(.animation(paused: !landing || landed || reduceMotion)) { timeline in
                let landScale = landScales(at: timeline.date)
                let scale = typeScale
                Canvas { context, size in
                    draw(&context, size: size, land: landScale, mirror: CanvasMirror(on: flip, width: size.width), scale: scale)
                }
                .aspectRatio(CGFloat(chord.frets.count) / (5.4 * min(1.5, max(1, stretch))), contentMode: .fit)
            }
            if let capo = capoCaption {
                capo.lineLimit(1).minimumScaleFactor(0.8)
            }
            if let edges, chord.frets.count >= 2 { edgeNames(edges, mirrored: flip) }
        }
        .accessibilityIgnoresInvertColors()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(chord.name) chord"))
        .accessibilityValue(Text(ChordWords.shape(chord)))
        .onAppear { if landStart == nil { startLanding() } }
        .onChange(of: replay) { _, _ in startLanding(delay: 0.05) }
    }

    /// "G shape · capo 2", under a shape played behind a capo.
    private var capoCaption: Text? {
        guard let shape = chord.drawnCapoShape else { return nil }
        return Text("\(shape) shape · capo \(chord.drawnCapo)")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Palette.inkSoft)
    }

    /// The lowest string's name under its side of the box, string 1's under the other (`EdgeNamesRow`).
    private func edgeNames(_ edges: StringEdges, mirrored: Bool) -> some View {
        let lowest = edges.label(chord.frets.count), first = edges.label(1)
        return EdgeNamesRow(leading: mirrored ? first : lowest, trailing: mirrored ? lowest : first)
            .padding(.top, -4)
    }

    /// The box's height without its name (the frets and string numbers at a `width` and `stretch`, the capo's line
    /// and the edge names under it when `named`): the room a picture that swaps with it (`PlayerNeck`) is given, so
    /// the card holds still as the learner flips between them.
    static func boxHeight(_ chord: ChordSpec, width: CGFloat, stretch: CGFloat, named: Bool) -> CGFloat {
        let grid = width * 5.4 * min(1.5, max(1, stretch)) / CGFloat(max(1, chord.frets.count))
        return grid + (named ? 22 : 0) + (chord.drawnCapo > 0 ? capoLine : 0)
    }

    /// One finger laid flat across several strings at one fret (an index-finger barre, or finger 3
    /// across strings 4, 3 and 2): drawn as one rounded bar instead of a row of separate dots. The player's view
    /// (`PlayerNeck`) and the spoken shape (`ChordWords`) read them too.
    struct Barre {
        let fret: Int
        /// Lowest and highest string index it spans (lowest string first, as `frets`).
        let first: Int
        let last: Int
        let finger: Int
    }

    /// Barres in the suggested fingering: the same finger on two or more strings at the same fret, with
    /// every string between them fretted at or above it (an open, muted or lower string can't sit under a barre).
    var barres: [Barre] {
        guard let fingers = chord.fingers else { return [] }
        let frets = chord.frets
        var found: [Barre] = []
        for finger in Set(fingers.filter { $0 > 0 }).sorted() {
            let held = frets.indices.filter { fingers[safe: $0] == finger && chord.drawnFingered($0) }
            guard held.count >= 2, let first = held.first, let last = held.last else { continue }
            let fret = frets[first]
            guard held.allSatisfy({ frets[$0] == fret }), (first...last).allSatisfy({ frets[$0] >= fret }) else { continue }
            found.append(Barre(fret: fret, first: first, last: last, finger: finger))
        }
        return found
    }

    /// Draws the box as a right-hander's chart; `mirror` turns the shapes over and sets the words at the mirrored points.
    private func draw(_ context: inout GraphicsContext, size: CGSize, land: (Int) -> CGFloat, mirror: CanvasMirror, scale: CGFloat) {
        let shapes = mirror.shapes(context)
        let count = chord.frets.count
        let rows = 4
        let capo = chord.drawnCapo
        // Behind a capo the box starts at the first fret above it, as the open shape it is.
        let base = capo > 0 ? capo + 1 : (chord.baseFret ?? 1)
        // The "5fr" label (or the fret numbers) get their own column beside the grid instead of sitting on its edge,
        // and each outer string keeps room for a whole dot beside it (`stringSpan`).
        let span = stringSpan(width: size.width)
        let left = span.first, gap = span.gap
        let right = left + gap * CGFloat(max(0, count - 1))
        // String numbers under the box when there's room (not on the small "next chord" preview).
        let numbered = gap >= 13
        let top: CGFloat = 24, bottom = size.height - (numbered ? 20 : 6)
        let rowHeight = (bottom - top) / CGFloat(rows)
        let radius = min(gap, rowHeight) * 0.38
        if capo > 0 {
            drawCapo(shapes, left: left, right: right, top: top, radius: radius)
        } else if base == 1 {
            shapes.fill(Path(roundedRect: CGRect(x: left - 2, y: top - 5, width: right - left + 4, height: 6), cornerRadius: 2), with: .color(Palette.ink))
        } else if !fretNumbers {
            context.draw(Text("\(base)fr").font(DiagramType.font(11, weight: .semibold, scale: scale)).foregroundStyle(Palette.inkSoft),
                         at: mirror.point(CGPoint(x: left - radius - 4, y: top + rowHeight / 2)), anchor: mirror.anchor(.trailing))
        }
        if fretNumbers {
            drawFretNumbers(&context, base: base, rows: rows, top: top, rowHeight: rowHeight, x: left - radius - 6, land: land, mirror: mirror, scale: scale)
        }
        for row in 0...rows {
            let y = top + CGFloat(row) * rowHeight
            shapes.fill(Path(CGRect(x: left, y: y - 0.75, width: right - left, height: 1.5)), with: .color(Palette.inkSoft.opacity(0.5)))
        }
        let barres = self.barres
        for i in 0..<count {
            let x = left + CGFloat(i) * gap
            let lit = ringing.contains(i)
            // Lowest string thickest, like the real set.
            let thickness = count > 1 ? 1.1 + 2.1 * CGFloat(count - 1 - i) / CGFloat(count - 1) : 1.8
            shapes.fill(Path(CGRect(x: x - thickness / 2, y: top, width: thickness, height: bottom - top)), with: .color(lit ? accent : Palette.inkSoft.opacity(0.75)))
            if numbered {
                // String numbers run from the lowest string down to 1.
                context.draw(Text("\(count - i)").font(DiagramType.font(11, scale: scale)).foregroundStyle(lit ? accent : Palette.inkFaint),
                             at: mirror.point(CGPoint(x: x, y: size.height - 8)))
            }
            let fret = chord.frets[i]
            if fret < 0 {
                context.draw(Text("×").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.inkFaint), at: mirror.point(CGPoint(x: x, y: 10)))
            } else if !chord.drawnFingered(i) {
                // Open, or ringing from the capo.
                shapes.stroke(Path(ellipseIn: CGRect(x: x - 6, y: 4, width: 12, height: 12)), with: .color(lit ? accent : Palette.ink), lineWidth: 1.8)
            } else if !barres.contains(where: { $0.fret == fret && $0.first <= i && i <= $0.last }) {
                let grow = land(i)
                guard grow > 0.01 else { continue }
                let y = top + (CGFloat(fret - base) + 0.5) * rowHeight - (1 - min(1, grow)) * 12
                let r = radius * grow
                let halo = 3 * grow
                shapes.fill(Path(ellipseIn: CGRect(x: x - r - halo, y: y - r - halo, width: (r + halo) * 2, height: (r + halo) * 2)), with: .color(accent.opacity(lit ? 0.45 : 0.18)))
                shapes.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                if grow > 0.6, let finger = chord.fingers?[safe: i], finger > 0 {
                    context.draw(Text("\(finger)").font(.system(size: r * 1.05, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent),
                                 at: mirror.point(CGPoint(x: x, y: y)))
                }
            }
        }
        for barre in barres {
            drawBarre(&context, shapes: shapes, barre, left: left, gap: gap, top: top, rowHeight: rowHeight, radius: radius, base: base,
                      grow: land(barre.first), mirror: mirror)
        }
    }

    /// The capo across every string where the nut would be: a clamp's padded bar a little past the outer strings, its
    /// rubber edge along the bottom and its screw toward one end.
    private func drawCapo(_ shapes: GraphicsContext, left: CGFloat, right: CGFloat, top: CGFloat, radius: CGFloat) {
        let reach = max(4, radius * 0.6)
        let bar = CGRect(x: left - reach, y: top - 7, width: right - left + reach * 2, height: 9)
        shapes.fill(Path(roundedRect: bar, cornerRadius: 4.5), with: .color(Palette.inkSoft))
        let pad = CGRect(x: bar.minX + 3, y: bar.maxY - 2.5, width: max(0, bar.width - 6), height: 1.5)
        shapes.fill(Path(roundedRect: pad, cornerRadius: 0.75), with: .color(Palette.stage.opacity(0.45)))
        let screw = CGRect(x: bar.maxX - 8, y: bar.midY - 2.5, width: 5, height: 5)
        shapes.fill(Path(ellipseIn: screw), with: .color(Palette.stage.opacity(0.5)))
    }

    /// Each row's fret beside it, right-aligned beside the box; a fret with a landed finger on it in the accent. Behind
    /// a capo, the capo's own fret is numbered beside it.
    private func drawFretNumbers(_ context: inout GraphicsContext, base: Int, rows: Int, top: CGFloat, rowHeight: CGFloat, x: CGFloat,
                                 land: (Int) -> CGFloat, mirror: CanvasMirror, scale: CGFloat) {
        let frets = chord.frets
        let anchor = mirror.anchor(.trailing)
        for row in 0..<rows {
            let fret = base + row
            let held = frets.indices.contains { frets[$0] == fret && chord.drawnFingered($0) && land($0) > 0.6 }
            let label = Text("\(fret)").font(DiagramType.font(11, weight: held ? .heavy : .semibold, scale: scale))
                .foregroundStyle(held ? accent : Palette.inkFaint)
            context.draw(label, at: mirror.point(CGPoint(x: x, y: top + (CGFloat(row) + 0.5) * rowHeight)), anchor: anchor)
        }
        let capo = chord.drawnCapo
        if capo > 0 {
            let label = Text("\(capo)").font(DiagramType.font(11, weight: .semibold, scale: scale)).foregroundStyle(Palette.inkSoft)
            context.draw(label, at: mirror.point(CGPoint(x: x, y: top - 2.5)), anchor: anchor)
        }
    }

    /// A rounded bar across the strings the finger holds, landing with the barre's lowest string. Its ends sit one dot
    /// radius past the outer strings it holds, whatever the landing's overshoot, and its glow hugs it.
    private func drawBarre(_ context: inout GraphicsContext, shapes: GraphicsContext, _ barre: Barre, left: CGFloat, gap: CGFloat, top: CGFloat,
                           rowHeight: CGFloat, radius: CGFloat, base: Int, grow: CGFloat, mirror: CanvasMirror) {
        guard grow > 0.01 else { return }
        let y = top + (CGFloat(barre.fret - base) + 0.5) * rowHeight - (1 - min(1, grow)) * 12
        let thick = radius * grow
        let halo = 3 * min(1, grow)
        let x0 = left + CGFloat(barre.first) * gap, x1 = left + CGFloat(barre.last) * gap
        let lit = (barre.first...barre.last).contains { ringing.contains($0) }
        let glow = CGRect(x: x0 - radius, y: y - thick - halo, width: x1 - x0 + radius * 2, height: (thick + halo) * 2)
        shapes.fill(Path(roundedRect: glow, cornerRadius: min(radius, thick + halo)), with: .color(accent.opacity(lit ? 0.45 : 0.18)))
        let bar = CGRect(x: x0 - radius, y: y - thick, width: x1 - x0 + radius * 2, height: thick * 2)
        shapes.fill(Path(roundedRect: bar, cornerRadius: min(radius, thick)), with: .color(accent))
        if grow > 0.6 {
            context.draw(Text("\(barre.finger)").font(.system(size: thick * 1.05, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent),
                         at: mirror.point(CGPoint(x: (x0 + x1) / 2, y: y)))
        }
    }

    /// Scale of each string's finger dot: 0 before it lands, then a damped spring to 1; always 1 when still.
    private func landScales(at date: Date) -> (Int) -> CGFloat {
        guard landing, !landed, !reduceMotion else { return { _ in 1 } }
        guard let landStart else { return { _ in 0 } }
        let elapsed = date.timeIntervalSince(landStart)
        let ranks = landingRanks
        let step = landingStep
        return { i in CGFloat(ChordDiagram.spring(elapsed - Double(ranks[safe: i] ?? 0) * step)) }
    }

    /// When each string's finger lands (0, 1, 2 …): fingered strings left to right, or by finger number
    /// (finger 1 first, a barre with its finger); strings without a finger after the rest.
    var landingRanks: [Int] {
        let frets = chord.frets
        let stringOrder = frets.indices.map { i in (0..<i).filter { chord.drawnFingered($0) }.count }
        guard landingOrder == .fingers, let fingers = chord.fingers else { return stringOrder }
        let used = Set(frets.indices.compactMap { i -> Int? in
            guard chord.drawnFingered(i), let finger = fingers[safe: i], finger > 0 else { return nil }
            return finger
        }).sorted()
        return frets.indices.map { i in
            guard let finger = fingers[safe: i], finger > 0, let rank = used.firstIndex(of: finger) else { return used.count + stringOrder[i] }
            return rank
        }
    }

    /// How many landings there are (the last one's rank + 1).
    var landingCount: Int {
        let ranks = landingRanks
        let fingered = chord.frets.indices.filter { chord.drawnFingered($0) }
        return (fingered.compactMap { ranks[safe: $0] }.max() ?? -1) + 1
    }

    /// A damped spring from 0 to 1: response 0.35 s with a slight overshoot.
    private static func spring(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / 0.35, zeta = 0.62
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    /// A beat after the card arrives (or the replay), the fingers land one every `landingStep`.
    private func startLanding(delay: Double = 0.25) {
        guard landing, !reduceMotion else { return }
        landGeneration += 1
        let generation = landGeneration
        landed = false
        landStart = Date().addingTimeInterval(delay)
        let duration = delay + Double(max(0, landingCount - 1)) * landingStep + 0.6
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            // A replay started meanwhile keeps the clock running.
            if generation == landGeneration { landed = true }
        }
    }
}

extension ChordSpec {
    /// The fret the capo clamps for this shape; 0 without one.
    var drawnCapo: Int { max(0, capo ?? 0) }

    /// Whether a finger stops string `i` (lowest first): fretted above the capo, or above the nut without one.
    func drawnFingered(_ i: Int) -> Bool { frets.indices.contains(i) && frets[i] > drawnCapo }

    /// The shape's own name under a capo, in the player's note names ("G" for an A played as a G shape on capo 2);
    /// nil without a capo.
    var drawnCapoShape: String? {
        let capo = drawnCapo
        guard capo > 0 else { return nil }
        let main = symbol.split(separator: "/", maxSplits: 1).first.map(String.init) ?? symbol
        let accidentals: Set<Character> = ["#", "b", "♯", "♭"]
        let suffix = String(main.dropFirst().drop { accidentals.contains($0) })
        let shapeRoot = ((root - capo) % 12 + 12) % 12
        return NoteNames.glyphs(NoteNames.chord(root: shapeRoot, suffix: suffix))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// A diagram's outer strings named under it, one at each side ("Thickest (6)" … "Thinnest (1)"), at `.caption2`
/// (11 pt and up). A narrow diagram (the progression strip's) puts them on two lines rather than shrinking them.
struct EdgeNamesRow: View {
    let leading: Text?
    let trailing: Text?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                leading
                Spacer(minLength: 0)
                trailing
            }
            VStack(spacing: 1) {
                HStack(spacing: 0) {
                    leading
                    Spacer(minLength: 0)
                }
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
        .font(.system(.caption2, design: .rounded).weight(.semibold))
        .foregroundStyle(Palette.inkSoft)
        .lineLimit(1)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 2)
    }
}

/// A chord's shape in words for VoiceOver, said once by whichever picture shows it (the chart or the player's
/// view): the capo first when there is one, the fingers in the order they go down, then the open (or capo) and the
/// muted strings ("Finger 2 on string 5, fret 2; Finger 3 on string 4, fret 2; Strings 6, 3, 2 and 1 open").
@MainActor
enum ChordWords {
    static func shape(_ chord: ChordSpec) -> String {
        let frets = chord.frets
        let count = frets.count
        let barres = ChordDiagram(chord: chord).barres
        var placed: [(order: Int, words: String)] = []
        for barre in barres {
            let strings = (barre.first...barre.last).map { count - $0 }
            placed.append((order: barre.finger, words: String(localized: "Finger \(barre.finger) across strings \(list(strings)) at fret \(barre.fret)")))
        }
        for i in frets.indices where chord.drawnFingered(i) {
            if barres.contains(where: { $0.fret == frets[i] && $0.first <= i && i <= $0.last }) { continue }
            let string = count - i
            let fret = frets[i]
            if let finger = chord.fingers?[safe: i], finger > 0 {
                placed.append((order: finger, words: String(localized: "Finger \(finger) on string \(string), fret \(fret)")))
            } else {
                placed.append((order: 9, words: String(localized: "String \(string), fret \(fret)")))
            }
        }
        // Finger order, ties as the strings run.
        let sorted = placed.enumerated().sorted { a, b in
            a.element.order != b.element.order ? a.element.order < b.element.order : a.offset < b.offset
        }
        var parts = sorted.map { $0.element.words }
        let capo = chord.drawnCapo
        if capo > 0 { parts.insert(String(localized: "Capo on fret \(capo)"), at: 0) }
        let open = frets.indices.filter { frets[$0] >= 0 && !chord.drawnFingered($0) }.map { count - $0 }
        let muted = frets.indices.filter { frets[$0] < 0 }.map { count - $0 }
        if open.count == 1, let only = open.first {
            parts.append(String(localized: "String \(only) open"))
        } else if open.count > 1 {
            parts.append(String(localized: "Strings \(list(open)) open"))
        }
        if muted.count == 1, let only = muted.first {
            parts.append(String(localized: "String \(only) muted"))
        } else if muted.count > 1 {
            parts.append(String(localized: "Strings \(list(muted)) muted"))
        }
        return parts.joined(separator: "; ")
    }

    private static func list(_ strings: [Int]) -> String {
        ListFormatter.localizedString(byJoining: strings.map { "\($0)" })
    }
}

/// Five lines with note heads; ledger lines and sharps as needed. Everything scales with `lineGap`.
struct StaffView: View {
    let notes: [Int]
    var clef: String = "treble"
    var accent: Color = Palette.mint
    var activeIndex: Int?
    /// Space between the lines: 11 pt on steps and small cards, up to 17 on a big card.
    var lineGap: CGFloat = 11

    /// The drawing's height for a line gap (120 pt at the plain 11).
    static func height(lineGap: CGFloat) -> CGFloat { 120 * lineGap / 11 }

    /// The line gap that fills `height`, between the plain 11 pt and 17 pt.
    static func lineGap(filling height: CGFloat) -> CGFloat { min(17, max(11, height * 11 / 120)) }

    /// Diatonic step of a MIDI note counted from C0 and its accidental, spelled like NoteName (C♯ E♭ F♯ A♭ B♭).
    private static func step(_ midi: Int) -> (Int, String?) {
        let table: [(Int, String?)] = [(0, nil), (0, "♯"), (1, nil), (2, "♭"), (2, nil), (3, nil), (3, "♯"), (4, nil), (5, "♭"), (5, nil), (6, "♭"), (6, nil)]
        let (degree, accidental) = table[((midi % 12) + 12) % 12]
        return ((midi / 12) * 7 + degree, accidental)
    }

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .frame(height: Self.height(lineGap: lineGap))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(notes.map(NoteName.name).joined(separator: ", ")))
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let gap = lineGap
        let s = gap / 11
        let middle = size.height / 2
        let bottomLine = middle + 2 * gap
        // The bottom line is E4 in treble clef and G2 in bass clef.
        let reference = Self.step(clef == "bass" ? 43 : 64).0
        let lineWeight = 1.2 * min(1.4, s)
        for line in 0..<5 {
            let y = bottomLine - CGFloat(line) * gap
            context.fill(Path(CGRect(x: 8, y: y - lineWeight / 2, width: size.width - 16, height: lineWeight)), with: .color(Palette.inkSoft.opacity(0.7)))
        }
        context.draw(Text(clef == "bass" ? "𝄢" : "𝄞").font(.system(size: (clef == "bass" ? 40 : 58) * s)).foregroundStyle(Palette.ink),
                     at: CGPoint(x: 26 * s, y: clef == "bass" ? middle - 4 * s : middle + 2 * s))
        let start = 64 * s
        let spacing = notes.count > 1 ? min(56 * s, (size.width - start - 24 * s) / CGFloat(notes.count - 1)) : 0
        for (i, midi) in notes.enumerated() {
            let (position, accidental) = Self.step(midi)
            let offset = position - reference
            let x = start + CGFloat(i) * spacing
            let y = bottomLine - CGFloat(offset) * gap / 2
            if offset < -1 { for ledger in stride(from: -2, through: offset, by: -2) { line(&context, x: x, y: bottomLine - CGFloat(ledger) * gap / 2, scale: s) } }
            if offset > 9 { for ledger in stride(from: 10, through: offset, by: 2) { line(&context, x: x, y: bottomLine - CGFloat(ledger) * gap / 2, scale: s) } }
            let color = activeIndex == nil || activeIndex == i ? accent : Palette.inkSoft
            var head = Path(ellipseIn: CGRect(x: -6.5 * s, y: -4.8 * s, width: 13 * s, height: 9.6 * s))
            head = head.applying(CGAffineTransform(rotationAngle: -0.35)).applying(CGAffineTransform(translationX: x, y: y))
            if activeIndex == i {
                // The note sounding now glows.
                let glow = 16 * s
                context.fill(Path(ellipseIn: CGRect(x: x - glow, y: y - glow, width: glow * 2, height: glow * 2)),
                             with: .radialGradient(Gradient(colors: [accent.opacity(0.4), .clear]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: glow))
            }
            context.fill(head, with: .color(color))
            let up = offset < 4
            let stem = 32 * s
            context.fill(Path(CGRect(x: up ? x + 5 * s : x - 6.3 * s, y: up ? y - stem : y, width: 1.4 * s, height: stem)), with: .color(color))
            if let accidental { context.draw(Text(accidental).font(.system(size: 17 * s, weight: .semibold)).foregroundStyle(color), at: CGPoint(x: x - 15 * s, y: y)) }
        }
    }

    private func line(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat, scale s: CGFloat) {
        let weight = 1.2 * min(1.4, s)
        context.fill(Path(CGRect(x: x - 11 * s, y: y - weight / 2, width: 22 * s, height: weight)), with: .color(Palette.inkSoft.opacity(0.7)))
    }
}

enum NoteName {
    static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static func name(_ midi: Int) -> String { "\(pitchClass(midi))\(midi / 12 - 1)" }
    /// In the player's note-naming system (Settings › Note names): B♭ is B and B is H in German.
    static func pitchClass(_ midi: Int) -> String { NoteNames.spell(names[((midi % 12) + 12) % 12], system: NoteNames.active) }
}

/// Two octaves of keys, highlighted where the lesson points.
struct KeyboardView: View {
    let highlighted: Set<Int>
    var accent: Color = Palette.mint
    /// The keys' length: 110 pt, longer on a big card.
    var height: CGFloat = 110

    var body: some View {
        let low = max(36, ((highlighted.min() ?? 60) / 12) * 12)
        let whites = (low..<(low + 24)).filter { ![1, 3, 6, 8, 10].contains($0 % 12) }
        Canvas { context, size in
            let w = size.width / CGFloat(whites.count)
            for (i, midi) in whites.enumerated() {
                let rect = CGRect(x: CGFloat(i) * w + 1, y: 0, width: w - 2, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(highlighted.contains(midi) ? accent : Color(hex: 0xEDEBE6)))
                if midi % 12 == 0 {
                    // The diagrams' 11 pt floor; a white key is wide enough for "C4" at that size, not more.
                    context.draw(Text("C\(midi / 12 - 1)").font(DiagramType.font(11, weight: .semibold)).foregroundStyle(Color.black.opacity(0.5)),
                                 at: CGPoint(x: rect.midX, y: size.height - 11))
                }
            }
            for (i, midi) in whites.enumerated() where [0, 2, 5, 7, 9].contains(midi % 12) && i < whites.count - 1 {
                let black = midi + 1
                let rect = CGRect(x: CGFloat(i + 1) * w - w * 0.3, y: 0, width: w * 0.6, height: size.height * 0.6)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(highlighted.contains(black) ? accent : Color(hex: 0x16181C)))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(highlighted.sorted().map(NoteName.name).joined(separator: ", ")))
    }
}

/// One bar of a pattern as the explanations and quizzes draw it: the rhythm step's own beat lane (`LessonBeatRow`)
/// without its calls, so a pattern looks the same wherever it's taught. On a strummed instrument that's every
/// down and up stroke with the pick riding the lane; otherwise dots with a playhead.
struct RhythmBar: View {
    let pattern: [Double]
    var beatsPerBar: Int = 4
    var accent: Color = Palette.mint
    /// 0…1 through the bar, nil when not playing.
    var playhead: Double?
    var judged: [Int: PlayAlongJudge.Grade] = [:]
    /// Strums: down arrows on the beat, up arrows between beats.
    var arrows = false

    var body: some View {
        LessonBeatRow(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: playhead,
                      calls: judged.mapValues { BeatCall(grade: $0, offset: nil) }, arrows: arrows, callRows: false)
    }
}

/// The course instrument's photograph with the named part glowing (strings, head, nut, bridge); a left-handed
/// instrument for a left-handed player (`HandStyle.mirrorsUpright`).
struct InstrumentPartView: View {
    let part: String
    let instrumentId: String?
    var accent: Color = Palette.mint
    /// Explanations give the photograph whatever room the card has.
    var height: CGFloat = 260
    @EnvironmentObject private var store: AppStore
    @CurrentHand private var hand
    @State private var pulse = false

    var body: some View {
        let asset = instrumentId.flatMap { store.catalog.photo(instrumentId: $0)?.asset } ?? "01_guitar_acoustic_guitar"
        let mirrored = hand.mirrorsUpright
        let card = ModelLibrary.photoCard(asset).map { mirrored ? $0.mirrored() : $0 }
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let origin = CGPoint(x: (geometry.size.width - side) / 2, y: (geometry.size.height - side) / 2)
            ZStack {
                Image(asset).resizable().interpolation(.high).scaledToFit()
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 12)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                if let card {
                    Canvas { context, _ in
                        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * side, y: origin.y + p.y * side) }
                        let anchors = card.anchors
                        switch part {
                        case "strings":
                            for a in anchors { if let n = card.point("\(a).nut"), let s = card.point("\(a).saddle") {
                                var path = Path(); path.move(to: point(n)); path.addLine(to: point(s))
                                context.stroke(path, with: .color(accent.opacity(pulse ? 0.9 : 0.4)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            } }
                        default:
                            let key = part == "head" ? "peg" : part == "bridge" ? "saddle" : "nut"
                            for a in anchors { if let p = card.point("\(a).\(key)") {
                                let c = point(p), r: CGFloat = pulse ? 13 : 9
                                context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(accent), lineWidth: 2)
                            } }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: height)
        .accessibilityIgnoresInvertColors()
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - Filling an explanation that has no picture

/// The course instrument floating in a soft spotlight; for courses without one (theory, ear, rhythm,
/// singing) a quiet motif in the course colour. Still with Reduce Motion.
struct LessonBackdrop: View {
    let course: LearnCourse
    var accent: Color = Palette.mint
    @EnvironmentObject private var store: AppStore
    @CurrentHand private var hand
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    /// The instrument's lean as it floats (the other way for a left-handed instrument).
    private var tilt: Double {
        let lean: Double = floating ? -8 : -12
        return hand.mirrorsUpright ? -lean : lean
    }

    /// The instrument's studio render, or its photograph, resolved as on the Learn tab.
    private var image: String? {
        let photo = course.instrument.flatMap { store.catalog.photo(instrumentId: $0)?.asset }
        return photo.map { asset in ModelLibrary.modelID(forPhoto: asset).map { ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : asset } ?? asset }
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.18), .clear], center: .center, startRadius: 4, endRadius: 190)
            if let image {
                Ellipse().fill(RadialGradient(colors: [Color.black.opacity(0.6), .clear], center: .center, startRadius: 2, endRadius: 95))
                    .frame(width: 190, height: 28)
                    .scaleEffect(floating ? 0.84 : 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Image(image).resizable().interpolation(.high).scaledToFit()
                    .scaleEffect(x: hand.mirrorsUpright ? -1 : 1, y: 1)
                    .shadow(color: .black.opacity(0.6), radius: 22, y: 16)
                    .rotationEffect(.degrees(tilt))
                    .offset(y: floating ? -8 : 4)
                    .padding(.vertical, 24)
            } else if course.id == "theory" {
                StaffMotif(accent: accent)
            } else {
                RingMotif(accent: accent, symbol: course.symbol, beat: course.id == "rhythm")
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { floating = true }
        }
        .accessibilityHidden(true)
    }
}

/// Five staff lines with a treble clef and notes drifting through them.
struct StaffMotif: View {
    var accent: Color = Palette.mint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Staff positions of the notes (0 is the bottom line, each step a line or a space).
    private static let steps = [2, 4, 6, 3, 7, 5, 8, 4, 1, 5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in draw(&context, size: size, t: t) }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let gap = min(18, size.height / 9)
        let bottomLine = size.height / 2 + 2 * gap
        let clefX: CGFloat = 36
        let lineShade = Gradient(colors: [Palette.inkSoft.opacity(0), Palette.inkSoft.opacity(0.5), Palette.inkSoft.opacity(0.5), Palette.inkSoft.opacity(0)])
        for line in 0..<5 {
            let y = bottomLine - CGFloat(line) * gap
            context.fill(Path(CGRect(x: 0, y: y - 0.7, width: size.width, height: 1.4)),
                         with: .linearGradient(lineShade, startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: size.width, y: y)))
        }
        context.draw(Text("𝄞").font(.system(size: gap * 5.6)).foregroundStyle(Palette.ink.opacity(0.85)), at: CGPoint(x: clefX, y: bottomLine - gap * 1.85))
        let spacing = max(64, (size.width + 80) / CGFloat(Self.steps.count))
        let loop = spacing * CGFloat(Self.steps.count)
        let scale = gap / 11
        for (i, step) in Self.steps.enumerated() {
            var x = (CGFloat(i) * spacing - CGFloat(t) * 26).truncatingRemainder(dividingBy: loop)
            if x < 0 { x += loop }
            x -= 30
            // Fade in from the right edge, out before the clef.
            let fade = max(0, min(1, (x - clefX - 34) / 50)) * max(0, min(1, (size.width - 8 - x) / 50))
            guard fade > 0 else { continue }
            let y = bottomLine - CGFloat(step) * gap / 2 + CGFloat(sin(t * 1.3 + Double(i))) * 2
            let color = accent.opacity(fade)
            if i % 4 == 0 {
                let r = 13 * scale
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent.opacity(0.18 * fade)))
            }
            var head = Path(ellipseIn: CGRect(x: -6.5 * scale, y: -4.8 * scale, width: 13 * scale, height: 9.6 * scale))
            head = head.applying(CGAffineTransform(rotationAngle: -0.35)).applying(CGAffineTransform(translationX: x, y: y))
            context.fill(head, with: .color(color))
            let up = step < 4
            let stem = 3 * gap
            context.fill(Path(CGRect(x: up ? x + 5 * scale : x - 6.3 * scale, y: up ? y - stem : y, width: 1.4 * scale, height: stem)), with: .color(color))
        }
    }
}

/// Rings rippling out from the course symbol (ear, rhythm, singing) or from behind a play button.
struct RingMotif: View {
    var accent: Color = Palette.mint
    /// SF Symbol in the centre orb; nil leaves the centre to whatever sits on top.
    var symbol: String?
    /// Rhythm: a ring leaves on every beat and the orb pulses with it.
    var beat = false
    /// Off: the rings hold still and dim (a listen button between plays).
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var period: Double { beat ? 60.0 / 76 : 2.6 }
    private var moving: Bool { active && !reduceMotion }

    /// The rings ripple on the timeline; the orb sits outside it (unless it pulses with a beat), so a new symbol
    /// or colour lands the moment the caller changes it, never a frame of the old one late.
    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in draw(&context, size: size, t: t, moving: moving) }
            }
            if let symbol {
                if beat && moving {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        let beatPhase = (timeline.date.timeIntervalSinceReferenceDate / period).truncatingRemainder(dividingBy: 1)
                        orb(symbol).scaleEffect(CGFloat(1 + 0.07 * exp(-7 * beatPhase)))
                    }
                } else {
                    orb(symbol)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The centre orb: the symbol on the accent. The symbol swaps outright (no replace effect that could lag a
    /// reading behind), so the orb always says what the words beside it say.
    private func orb(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 30, weight: .semibold)).foregroundStyle(Palette.onAccent)
            .contentTransition(.identity)
            .frame(width: 76, height: 76)
            .background(Circle().fill(accent))
            .shadow(color: accent.opacity(0.55), radius: 20)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, moving: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = max(48, min(size.width, size.height) / 2 - 4)
        let inner: CGFloat = 40
        let glow = Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2))
        context.fill(glow, with: .radialGradient(Gradient(colors: [accent.opacity(moving ? 0.16 : 0.10), .clear]), center: center, startRadius: 0, endRadius: outer))
        let count = beat ? 3 : 4
        // A beat sends one ring per beat; otherwise the rings spread evenly through a slow cycle.
        let cycle = beat ? period * Double(count) : period * 1.6
        for k in 0..<count {
            let p = moving ? (t / cycle + Double(k) / Double(count)).truncatingRemainder(dividingBy: 1) : (Double(k) + 0.6) / Double(count)
            let r = inner + (outer - inner) * CGFloat(p)
            let alpha = pow(1 - p, 1.6) * (moving ? 0.6 : 0.3)
            context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(accent.opacity(alpha)), lineWidth: 1.5)
        }
    }
}

/// A stroke on a beat row lighting up as the playhead reaches it: the dot swells and a ring leaves it.
enum BeatStrike {
    /// 1 as the playhead reaches `position` (both 0…1 through the bar), fading to 0 a tenth of a bar later.
    static func amount(playhead: Double?, at position: Double) -> Double {
        guard let playhead else { return 0 }
        let since = playhead - position
        return since >= 0 && since < 0.1 ? 1 - since / 0.1 : 0
    }

    static func draw(_ context: inout GraphicsContext, at center: CGPoint, radius r: CGFloat, color: Color, strike: Double) {
        guard strike > 0 else { return }
        let ring = r + 4 + 16 * CGFloat(1 - strike)
        context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                       with: .color(color.opacity(0.6 * strike)), lineWidth: 2)
        let glow = r + 12
        context.fill(Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [color.opacity(0.4 * strike), .clear]), center: center, startRadius: r * 0.5, endRadius: glow))
    }
}

/// A rhythm pattern with the playhead sweeping it on a loop (explanations); still with Reduce Motion.
struct RhythmLoop: View {
    let pattern: [Double]
    var beatsPerBar = 4
    var accent: Color = Palette.mint
    var arrows = false
    var bpm: Double = 76
    /// The stroke itself above the bar (a pick sweeping the strings, a finger plucking, a tap pad),
    /// on the same clock as the playhead; give the loop a height to fill.
    var sweep: StrumSweep.Style?
    var strings = 6
    /// Names the top and bottom strings of the sweep.
    var edges: StringEdges?
    /// When a bar's beat 1 falls (the loop turns before and after it), so a demonstration's strokes can sound
    /// with the pick; nil starts the loop as it appears.
    var origin: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let secondsPerBeat = 60 / bpm
            let bar = Double(max(1, beatsPerBar)) * secondsPerBeat
            let elapsed = timeline.date.timeIntervalSince(origin ?? start)
            let into = (elapsed / bar).truncatingRemainder(dividingBy: 1)
            let through = into < 0 ? into + 1 : into
            VStack(spacing: 10) {
                if let sweep {
                    StrumSweep(pattern: pattern, beatsPerBar: beatsPerBar, strings: strings, style: sweep, accent: accent,
                               secondsPerBeat: secondsPerBeat, time: reduceMotion ? nil : elapsed, edges: edges)
                        .frame(maxHeight: .infinity)
                }
                RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: reduceMotion ? nil : through, arrows: arrows)
            }
        }
    }
}
