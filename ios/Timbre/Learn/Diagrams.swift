import SwiftUI
import TimbreCore

/// The picture on a lesson card.
struct LessonVisualView: View {
    let visual: LessonVisual
    var accent: Color = Palette.mint
    var instrumentId: String?

    var body: some View {
        switch visual {
        case .none: EmptyView()
        case let .fretboard(strings, dots, frets, start):
            FretboardDiagram(strings: strings, dots: dots, frets: frets, accent: accent, start: start,
                             fretless: ["violin", "cello"].contains { instrumentId?.hasPrefix($0) == true })
        case let .chord(spec): ChordDiagram(chord: spec, accent: accent).frame(maxWidth: 220)
        case let .staff(midi, clef): StaffView(notes: midi, clef: clef, accent: accent)
        case let .rhythm(pattern, beatsPerBar): RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent)
        case let .keyboard(midi): KeyboardView(highlighted: Set(midi), accent: accent)
        case let .instrument(part): InstrumentPartView(part: part, instrumentId: instrumentId, accent: accent)
        }
    }
}

/// A stretch of neck seen from the player: string 1 on top, nut on the left, dots where to press.
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

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 26, right = size.width - 10, top: CGFloat = 14, bottom = size.height - 14
            let fretWidth = (right - left) / CGFloat(frets)
            let gap = strings > 1 ? (bottom - top) / CGFloat(strings - 1) : 0
            let board = Path(roundedRect: CGRect(x: left, y: top - 10, width: right - left, height: bottom - top + 20), cornerRadius: 8)
            context.fill(board, with: .linearGradient(Gradient(colors: fretless ? [Color(hex: 0x1C1C1E), Color(hex: 0x0E0E10)] : [Color(hex: 0x2A1E17), Color(hex: 0x1A120E)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
            for marker in [3, 5, 7, 9, 12, 15] where marker >= start && marker < start + frets && !fretless {
                let x = left + (CGFloat(marker - start + 1) - 0.5) * fretWidth
                context.fill(Path(ellipseIn: CGRect(x: x - 4, y: (top + bottom) / 2 - 4, width: 8, height: 8)), with: .color(.white.opacity(0.18)))
            }
            if start <= 1 {
                context.fill(Path(CGRect(x: left - 3, y: top - 10, width: 6, height: bottom - top + 20)), with: .color(Color(hex: 0xEDE4D3)))
            } else {
                context.draw(Text("\(start)fr").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: left + fretWidth / 2, y: bottom + 16))
            }
            for fret in 1...frets {
                let x = left + CGFloat(fret) * fretWidth
                if fretless {
                    // Tapes where first-position fingers land (whole tone, major third, fourth, fifth).
                    guard [2, 4, 5, 7].contains(fret) else { continue }
                    let tape = left + (CGFloat(fret) - 0.5) * fretWidth
                    context.fill(Path(CGRect(x: tape - 1.5, y: top - 10, width: 3, height: bottom - top + 20)), with: .color(Color(hex: 0xEDE4D3).opacity(0.35)))
                } else {
                    context.fill(Path(CGRect(x: x - 1, y: top - 10, width: 2, height: bottom - top + 20)), with: .color(Color(hex: 0xB9B2A6).opacity(0.8)))
                }
            }
            for string in 1...max(1, strings) {
                let y = top + CGFloat(string - 1) * gap
                let thickness = 0.8 + CGFloat(string - 1) * 0.35
                let lit = activeString == string
                context.fill(Path(CGRect(x: left, y: y - thickness / 2, width: right - left, height: thickness)),
                             with: .color(lit ? accent : Color(hex: 0xD8D2C6).opacity(0.85)))
                if lit { context.fill(Path(CGRect(x: left, y: y - 4, width: right - left, height: 8)), with: .color(accent.opacity(0.22))) }
            }
            for dot in dots where dot.string >= 1 && dot.string <= strings {
                let y = top + CGFloat(dot.string - 1) * gap
                if dot.fret == 0 {
                    let ring = Path(ellipseIn: CGRect(x: left - 22, y: y - 8, width: 16, height: 16))
                    context.stroke(ring, with: .color(accent), lineWidth: 2.5)
                } else {
                    let x = left + (CGFloat(min(max(1, dot.fret - start + 1), frets)) - 0.5) * fretWidth
                    let r: CGFloat = min(15, gap * 0.48 + 4)
                    context.fill(Path(ellipseIn: CGRect(x: x - r - 4, y: y - r - 4, width: (r + 4) * 2, height: (r + 4) * 2)), with: .color(accent.opacity(0.25)))
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                    if let finger = dot.finger, finger > 0 {
                        context.draw(Text("\(finger)").font(.system(size: r, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent), at: CGPoint(x: x, y: y))
                    }
                }
            }
        }
        .frame(height: CGFloat(max(4, strings)) * 26 + 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibility))
    }

    private var accessibility: String {
        dots.map { $0.fret == 0 ? String(localized: "string \($0.string) open") : String(localized: "string \($0.string), fret \($0.fret)") }.joined(separator: "; ")
    }
}

/// A chord box: strings upright, nut on top, finger numbers in the dots, open and muted marks above.
struct ChordDiagram: View {
    let chord: ChordSpec
    var accent: Color = Palette.mint
    var showName = true
    /// Strings that rang in the last reading (lowest string first), lit while the learner plays.
    var ringing: Set<Int> = []

    var body: some View {
        VStack(spacing: 8) {
            if showName { Text(chord.name).font(Typeface.display(28)).foregroundStyle(Palette.ink) }
            Canvas { context, size in
                let count = chord.frets.count
                let rows = 4
                let top: CGFloat = 24, left: CGFloat = 22, right = size.width - 22, bottom = size.height - 6
                let gap = (right - left) / CGFloat(max(1, count - 1))
                let rowHeight = (bottom - top) / CGFloat(rows)
                let base = chord.baseFret ?? 1
                if base == 1 {
                    context.fill(Path(roundedRect: CGRect(x: left - 2, y: top - 5, width: right - left + 4, height: 6), cornerRadius: 2), with: .color(Palette.ink))
                } else {
                    context.draw(Text("\(base)fr").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: 8, y: top + rowHeight / 2), anchor: .leading)
                }
                for row in 0...rows {
                    let y = top + CGFloat(row) * rowHeight
                    context.fill(Path(CGRect(x: left, y: y - 0.75, width: right - left, height: 1.5)), with: .color(Palette.inkSoft.opacity(0.5)))
                }
                for i in 0..<count {
                    let x = left + CGFloat(i) * gap
                    let lit = ringing.contains(i)
                    context.fill(Path(CGRect(x: x - 0.9, y: top, width: 1.8, height: bottom - top)), with: .color(lit ? accent : Palette.inkSoft.opacity(0.75)))
                    let fret = chord.frets[i]
                    if fret < 0 {
                        context.draw(Text("×").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: x, y: 10))
                    } else if fret == 0 {
                        context.stroke(Path(ellipseIn: CGRect(x: x - 6, y: 4, width: 12, height: 12)), with: .color(lit ? accent : Palette.ink), lineWidth: 1.8)
                    } else {
                        let row = CGFloat(fret - base) + 0.5
                        let y = top + row * rowHeight
                        let r = min(gap, rowHeight) * 0.38
                        context.fill(Path(ellipseIn: CGRect(x: x - r - 3, y: y - r - 3, width: (r + 3) * 2, height: (r + 3) * 2)), with: .color(accent.opacity(lit ? 0.45 : 0.18)))
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                        if let finger = chord.fingers?[safe: i], finger > 0 {
                            context.draw(Text("\(finger)").font(.system(size: r * 1.05, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent), at: CGPoint(x: x, y: y))
                        }
                    }
                }
            }
            .aspectRatio(CGFloat(chord.frets.count) / 5.2, contentMode: .fit)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(chord.name) chord"))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Five lines with note heads; ledger lines and sharps as needed.
struct StaffView: View {
    let notes: [Int]
    var clef: String = "treble"
    var accent: Color = Palette.mint
    var activeIndex: Int?

    /// Diatonic step of a MIDI note counted from C0 and its accidental, spelled like NoteName (C♯ E♭ F♯ A♭ B♭).
    private static func step(_ midi: Int) -> (Int, String?) {
        let table: [(Int, String?)] = [(0, nil), (0, "♯"), (1, nil), (2, "♭"), (2, nil), (3, nil), (3, "♯"), (4, nil), (5, "♭"), (5, nil), (6, "♭"), (6, nil)]
        let (degree, accidental) = table[((midi % 12) + 12) % 12]
        return ((midi / 12) * 7 + degree, accidental)
    }

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 11
            let middle = size.height / 2
            let bottomLine = middle + 2 * gap
            // The bottom line is E4 in treble clef and G2 in bass clef.
            let reference = Self.step(clef == "bass" ? 43 : 64).0
            for line in 0..<5 {
                let y = bottomLine - CGFloat(line) * gap
                context.fill(Path(CGRect(x: 8, y: y - 0.6, width: size.width - 16, height: 1.2)), with: .color(Palette.inkSoft.opacity(0.7)))
            }
            context.draw(Text(clef == "bass" ? "𝄢" : "𝄞").font(.system(size: clef == "bass" ? 40 : 58)).foregroundStyle(Palette.ink),
                         at: CGPoint(x: 26, y: clef == "bass" ? middle - 4 : middle + 2))
            let start: CGFloat = 64
            let spacing = notes.count > 1 ? min(56, (size.width - start - 24) / CGFloat(notes.count - 1)) : 0
            for (i, midi) in notes.enumerated() {
                let (position, accidental) = Self.step(midi)
                let offset = position - reference
                let x = start + CGFloat(i) * spacing
                let y = bottomLine - CGFloat(offset) * gap / 2
                if offset < -1 { for ledger in stride(from: -2, through: offset, by: -2) { line(&context, x: x, y: bottomLine - CGFloat(ledger) * gap / 2) } }
                if offset > 9 { for ledger in stride(from: 10, through: offset, by: 2) { line(&context, x: x, y: bottomLine - CGFloat(ledger) * gap / 2) } }
                let color = activeIndex == nil || activeIndex == i ? accent : Palette.inkSoft
                var head = Path(ellipseIn: CGRect(x: -6.5, y: -4.8, width: 13, height: 9.6))
                head = head.applying(CGAffineTransform(rotationAngle: -0.35)).applying(CGAffineTransform(translationX: x, y: y))
                context.fill(head, with: .color(color))
                let up = offset < 4
                context.fill(Path(CGRect(x: up ? x + 5 : x - 6.3, y: up ? y - 32 : y, width: 1.4, height: 32)), with: .color(color))
                if let accidental { context.draw(Text(accidental).font(.system(size: 17, weight: .semibold)).foregroundStyle(color), at: CGPoint(x: x - 15, y: y)) }
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(notes.map(NoteName.name).joined(separator: ", ")))
    }

    private func line(_ context: inout GraphicsContext, x: CGFloat, y: CGFloat) {
        context.fill(Path(CGRect(x: x - 11, y: y - 0.6, width: 22, height: 1.2)), with: .color(Palette.inkSoft.opacity(0.7)))
    }
}

enum NoteName {
    static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static func name(_ midi: Int) -> String { "\(names[((midi % 12) + 12) % 12])\(midi / 12 - 1)" }
    static func pitchClass(_ midi: Int) -> String { names[((midi % 12) + 12) % 12] }
}

/// Two octaves of keys, highlighted where the lesson points.
struct KeyboardView: View {
    let highlighted: Set<Int>
    var accent: Color = Palette.mint

    var body: some View {
        let low = max(36, ((highlighted.min() ?? 60) / 12) * 12)
        let whites = (low..<(low + 24)).filter { ![1, 3, 6, 8, 10].contains($0 % 12) }
        Canvas { context, size in
            let w = size.width / CGFloat(whites.count)
            for (i, midi) in whites.enumerated() {
                let rect = CGRect(x: CGFloat(i) * w + 1, y: 0, width: w - 2, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(highlighted.contains(midi) ? accent : Color(hex: 0xEDEBE6)))
                if midi % 12 == 0 {
                    context.draw(Text("C\(midi / 12 - 1)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.black.opacity(0.45)), at: CGPoint(x: rect.midX, y: size.height - 10))
                }
            }
            for (i, midi) in whites.enumerated() where [0, 2, 5, 7, 9].contains(midi % 12) && i < whites.count - 1 {
                let black = midi + 1
                let rect = CGRect(x: CGFloat(i + 1) * w - w * 0.3, y: 0, width: w * 0.6, height: size.height * 0.6)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(highlighted.contains(black) ? accent : Color(hex: 0x16181C)))
            }
        }
        .frame(height: 110)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(highlighted.sorted().map(NoteName.name).joined(separator: ", ")))
    }
}

/// One bar: beat numbers and the hits of a pattern; the playhead sweeps while it plays.
struct RhythmBar: View {
    let pattern: [Double]
    var beatsPerBar: Int = 4
    var accent: Color = Palette.mint
    /// 0…1 through the bar, nil when not playing.
    var playhead: Double?
    var judged: [Int: PlayAlongJudge.Grade] = [:]

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 14, right = size.width - 14
            let width = right - left
            let mid = size.height / 2 - 8
            context.fill(Path(roundedRect: CGRect(x: left, y: mid - 1, width: width, height: 2), cornerRadius: 1), with: .color(Palette.line))
            for beat in 0..<beatsPerBar {
                let x = left + width * CGFloat(beat) / CGFloat(beatsPerBar)
                context.fill(Path(CGRect(x: x - 0.5, y: mid - 14, width: 1, height: 28)), with: .color(Palette.inkFaint.opacity(0.5)))
                context.draw(Text("\(beat + 1)").font(Typeface.label(13)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: x, y: size.height - 10))
            }
            for (i, hit) in pattern.enumerated() {
                let x = left + width * CGFloat(hit) / CGFloat(beatsPerBar)
                let grade = judged[i]
                let color: Color = grade == .miss ? Palette.danger : grade != nil ? accent : (hit.truncatingRemainder(dividingBy: 1) == 0 ? accent : Palette.amber)
                let r: CGFloat = hit.truncatingRemainder(dividingBy: 1) == 0 ? 11 : 8
                context.fill(Path(ellipseIn: CGRect(x: x - r - 4, y: mid - r - 4, width: (r + 4) * 2, height: (r + 4) * 2)), with: .color(color.opacity(0.18)))
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: mid - r, width: r * 2, height: r * 2)), with: .color(color))
            }
            if let playhead {
                let x = left + width * CGFloat(playhead)
                context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: mid - 22, width: 3, height: 44), cornerRadius: 1.5), with: .color(Palette.ink))
            }
        }
        .frame(height: 86)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rhythm pattern"))
    }
}

/// The course instrument's photograph with the named part glowing (strings, head, nut, bridge).
struct InstrumentPartView: View {
    let part: String
    let instrumentId: String?
    var accent: Color = Palette.mint
    @EnvironmentObject private var store: AppStore
    @State private var pulse = false

    var body: some View {
        let asset = instrumentId.flatMap { store.catalog.photo(instrumentId: $0)?.asset } ?? "01_guitar_acoustic_guitar"
        let card = ModelLibrary.photoCard(asset)
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let origin = CGPoint(x: (geometry.size.width - side) / 2, y: (geometry.size.height - side) / 2)
            ZStack {
                Image(asset).resizable().interpolation(.high).scaledToFit().frame(width: side, height: side)
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
        .frame(height: 260)
        .onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityHidden(true)
    }
}
