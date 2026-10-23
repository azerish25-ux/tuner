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
        case let .chord(spec): ChordDiagram(chord: spec, accent: accent, landing: true).frame(maxWidth: 220)
        case let .staff(midi, clef): StaffView(notes: midi, clef: clef, accent: accent)
        case let .rhythm(pattern, beatsPerBar): RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, arrows: strums)
        case let .keyboard(midi): KeyboardView(highlighted: Set(midi), accent: accent)
        case let .instrument(part): InstrumentPartView(part: part, instrumentId: instrumentId, accent: accent)
        }
    }

    /// Strummed instruments read rhythm patterns as down and up strokes.
    private var strums: Bool { LearnCourse.strummed(instrumentId) }
}

/// A stretch of neck seen from the player: string 1 on top, nut on the left, dots where to press.
/// Every string is numbered beside the nut, so the orientation never has to be guessed.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !pulsing || reduceMotion)) { timeline in
            let beat = pulsing && !reduceMotion ? 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2) : 0
            Canvas { context, size in draw(&context, size: size, beat: beat) }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibility))
    }

    /// Room above the first string and below the last: the board's edge plus a whole finger dot and its
    /// halo, so a dot on an outer string is never cut off.
    private static let pad: CGFloat = 22
    /// The row under the board for the "5fr" position label.
    private static let positionRow: CGFloat = 16
    /// Centre of the string-number column, left of the open-string rings.
    private static let numberX: CGFloat = 8
    /// The nut's x: the number column and the open-string rings sit left of it.
    private static let nutX: CGFloat = 44

    private var height: CGFloat {
        CGFloat(max(4, strings)) * rowHeight + 10 + 2 * (Self.pad - 14) + (start > 1 ? Self.positionRow : 0)
    }

    /// Strings get thicker toward the bass (string 1, the highest, is the thinnest); the lower ones are wound.
    private func gauge(_ string: Int) -> CGFloat {
        strings > 1 ? CGFloat(string - 1) / CGFloat(strings - 1) : 0.5
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, beat: Double) {
        let left = Self.nutX, right = size.width - 10, top = Self.pad
        let bottom = size.height - Self.pad - (start > 1 ? Self.positionRow : 0)
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
            context.draw(Text("\(start)fr").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: left + fretWidth / 2, y: size.height - 13))
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
            let g = gauge(string)
            let thickness = 1 + g * 2.4
            let wound = strings >= 4 && g > 0.45
            let lit = activeString == string
            if lit {
                let glow = 0.14 + 0.16 * beat
                context.fill(Path(CGRect(x: left, y: y - 5, width: right - left, height: 10)), with: .color(accent.opacity(pulsing ? glow : 0.22)))
            }
            let tone = wound ? Color(hex: 0xCDB892) : Color(hex: 0xE2DDD3)
            context.fill(Path(CGRect(x: left, y: y - thickness / 2, width: right - left, height: thickness)),
                         with: .color(lit ? accent : tone.opacity(0.88)))
            if wound && !lit {
                // A thin highlight along the top of a wound string.
                context.fill(Path(CGRect(x: left, y: y - thickness / 2, width: right - left, height: 0.6)), with: .color(.white.opacity(0.28)))
            }
            drawNumber(&context, string: string, y: y, gap: gap, lit: lit)
        }
        for dot in dots where dot.string >= 1 && dot.string <= strings {
            let y = top + CGFloat(dot.string - 1) * gap
            let swell = CGFloat(beat) * 5
            if dot.fret == 0 {
                let center = CGPoint(x: left - 14, y: y)
                if pulsing {
                    let halo = 8 + 3 + swell
                    context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .color(accent.opacity(0.18 + 0.14 * beat)))
                }
                let ring = Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
                context.stroke(ring, with: .color(accent), lineWidth: 2.5)
            } else {
                let x = left + (CGFloat(min(max(1, dot.fret - start + 1), frets)) - 0.5) * fretWidth
                let r: CGFloat = min(15, gap * 0.48 + 4)
                // Capped by the padding, so the halo of a dot on string 1 stays inside the drawing.
                let halo = min(Self.pad - 1, r + 4 + (pulsing ? swell : 0))
                context.fill(Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)), with: .color(accent.opacity(pulsing ? 0.2 + 0.15 * beat : 0.25)))
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                if let finger = dot.finger, finger > 0 {
                    context.draw(Text("\(finger)").font(.system(size: r, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent), at: CGPoint(x: x, y: y))
                }
            }
        }
    }

    /// The string's number in the column left of the nut; the string being played lights with it.
    private func drawNumber(_ context: inout GraphicsContext, string: Int, y: CGFloat, gap: CGFloat, lit: Bool) {
        let size = min(11, max(8, gap * 0.62))
        let label = Text("\(string)").font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(lit ? accent : Palette.inkSoft.opacity(0.85))
        context.draw(label, at: CGPoint(x: Self.numberX, y: y))
    }

    private var accessibility: String {
        dots.map { $0.fret == 0 ? String(localized: "string \($0.string) open") : String(localized: "string \($0.string), fret \($0.fret)") }.joined(separator: "; ")
    }
}

/// A chord box: strings upright, nut on top, finger numbers in the dots, open and muted marks above,
/// a rounded bar where one finger holds several strings, and the string numbers along the bottom.
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
    @State private var landStart: Date?
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            if showName { Text(chord.name).font(Typeface.display(28)).foregroundStyle(Palette.ink) }
            TimelineView(.animation(paused: !landing || landed || reduceMotion)) { timeline in
                let landScale = landScales(at: timeline.date)
                Canvas { context, size in draw(&context, size: size, land: landScale) }
                    .aspectRatio(CGFloat(chord.frets.count) / 5.4, contentMode: .fit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(chord.name) chord"))
        .onAppear { startLanding() }
    }

    /// One finger laid flat across several strings at one fret (an index-finger barre, or finger 3
    /// across strings 4, 3 and 2): drawn as one rounded bar instead of a row of separate dots.
    private struct Barre {
        let fret: Int
        /// Lowest and highest string index it spans (lowest string first, as `frets`).
        let first: Int
        let last: Int
        let finger: Int
    }

    /// Barres in the suggested fingering: the same finger on two or more strings at the same fret, with
    /// every string between them fretted at or above it (an open, muted or lower string can't sit under a barre).
    private var barres: [Barre] {
        guard let fingers = chord.fingers else { return [] }
        let frets = chord.frets
        var found: [Barre] = []
        for finger in Set(fingers.filter { $0 > 0 }).sorted() {
            let held = frets.indices.filter { fingers[safe: $0] == finger && frets[$0] > 0 }
            guard held.count >= 2, let first = held.first, let last = held.last else { continue }
            let fret = frets[first]
            guard held.allSatisfy({ frets[$0] == fret }), (first...last).allSatisfy({ frets[$0] >= fret }) else { continue }
            found.append(Barre(fret: fret, first: first, last: last, finger: finger))
        }
        return found
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, land: (Int) -> CGFloat) {
        let count = chord.frets.count
        let rows = 4
        let base = chord.baseFret ?? 1
        // The "5fr" label gets its own column left of the grid instead of sitting on its edge.
        let labelColumn: CGFloat = (reservesFretLabel || base > 1) ? 20 : 0
        let left: CGFloat = 22 + labelColumn, right = size.width - 22 + labelColumn / 4
        let gap = (right - left) / CGFloat(max(1, count - 1))
        // String numbers under the box when there's room (not on the small "next chord" preview).
        let numbered = gap >= 13
        let top: CGFloat = 24, bottom = size.height - (numbered ? 20 : 6)
        let rowHeight = (bottom - top) / CGFloat(rows)
        let radius = min(gap, rowHeight) * 0.38
        if base == 1 {
            context.fill(Path(roundedRect: CGRect(x: left - 2, y: top - 5, width: right - left + 4, height: 6), cornerRadius: 2), with: .color(Palette.ink))
        } else {
            context.draw(Text("\(base)fr").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkSoft),
                         at: CGPoint(x: left - radius - 4, y: top + rowHeight / 2), anchor: .trailing)
        }
        for row in 0...rows {
            let y = top + CGFloat(row) * rowHeight
            context.fill(Path(CGRect(x: left, y: y - 0.75, width: right - left, height: 1.5)), with: .color(Palette.inkSoft.opacity(0.5)))
        }
        let barres = self.barres
        for i in 0..<count {
            let x = left + CGFloat(i) * gap
            let lit = ringing.contains(i)
            // Lowest string (left) thickest, like the real set.
            let thickness = count > 1 ? 1.1 + 2.1 * CGFloat(count - 1 - i) / CGFloat(count - 1) : 1.8
            context.fill(Path(CGRect(x: x - thickness / 2, y: top, width: thickness, height: bottom - top)), with: .color(lit ? accent : Palette.inkSoft.opacity(0.75)))
            if numbered {
                // String numbers run from the lowest string (left) down to 1.
                context.draw(Text("\(count - i)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(lit ? accent : Palette.inkFaint),
                             at: CGPoint(x: x, y: size.height - 8))
            }
            let fret = chord.frets[i]
            if fret < 0 {
                context.draw(Text("×").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: x, y: 10))
            } else if fret == 0 {
                context.stroke(Path(ellipseIn: CGRect(x: x - 6, y: 4, width: 12, height: 12)), with: .color(lit ? accent : Palette.ink), lineWidth: 1.8)
            } else if !barres.contains(where: { $0.fret == fret && $0.first <= i && i <= $0.last }) {
                let scale = land(i)
                guard scale > 0.01 else { continue }
                let y = top + (CGFloat(fret - base) + 0.5) * rowHeight - (1 - min(1, scale)) * 12
                let r = radius * scale
                let halo = 3 * scale
                context.fill(Path(ellipseIn: CGRect(x: x - r - halo, y: y - r - halo, width: (r + halo) * 2, height: (r + halo) * 2)), with: .color(accent.opacity(lit ? 0.45 : 0.18)))
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(accent))
                if scale > 0.6, let finger = chord.fingers?[safe: i], finger > 0 {
                    context.draw(Text("\(finger)").font(.system(size: r * 1.05, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent), at: CGPoint(x: x, y: y))
                }
            }
        }
        for barre in barres {
            drawBarre(&context, barre, left: left, gap: gap, top: top, rowHeight: rowHeight, radius: radius, base: base, scale: land(barre.first))
        }
    }

    /// A rounded bar across the strings the finger holds, landing with the barre's lowest string.
    private func drawBarre(_ context: inout GraphicsContext, _ barre: Barre, left: CGFloat, gap: CGFloat, top: CGFloat,
                           rowHeight: CGFloat, radius: CGFloat, base: Int, scale: CGFloat) {
        guard scale > 0.01 else { return }
        let y = top + (CGFloat(barre.fret - base) + 0.5) * rowHeight - (1 - min(1, scale)) * 12
        let r = radius * scale
        let halo = 3 * scale
        let x0 = left + CGFloat(barre.first) * gap, x1 = left + CGFloat(barre.last) * gap
        let lit = (barre.first...barre.last).contains { ringing.contains($0) }
        let glow = CGRect(x: x0 - r - halo, y: y - r - halo, width: x1 - x0 + (r + halo) * 2, height: (r + halo) * 2)
        context.fill(Path(roundedRect: glow, cornerRadius: r + halo), with: .color(accent.opacity(lit ? 0.45 : 0.18)))
        let bar = CGRect(x: x0 - r, y: y - r, width: x1 - x0 + r * 2, height: r * 2)
        context.fill(Path(roundedRect: bar, cornerRadius: r), with: .color(accent))
        // A soft sheen along the top, so it reads as one finger lying flat.
        context.fill(Path(roundedRect: CGRect(x: x0, y: y - r + 1.5, width: max(0, x1 - x0), height: max(1, r * 0.35)), cornerRadius: r * 0.2),
                     with: .color(.white.opacity(0.22)))
        if scale > 0.6 {
            context.draw(Text("\(barre.finger)").font(.system(size: r * 1.05, weight: .heavy, design: .rounded)).foregroundStyle(Palette.onAccent),
                         at: CGPoint(x: (x0 + x1) / 2, y: y))
        }
    }

    /// Scale of each string's finger dot: 0 before it lands, then a damped spring to 1; always 1 when still.
    private func landScales(at date: Date) -> (Int) -> CGFloat {
        guard landing, !landed, !reduceMotion else { return { _ in 1 } }
        guard let landStart else { return { _ in 0 } }
        let elapsed = date.timeIntervalSince(landStart)
        let frets = chord.frets
        return { i in
            let order = frets.prefix(i).filter { $0 > 0 }.count
            return CGFloat(ChordDiagram.spring(elapsed - Double(order) * 0.08))
        }
    }

    /// A damped spring from 0 to 1: response 0.35 s with a slight overshoot.
    private static func spring(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / 0.35, zeta = 0.62
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    /// A beat after the card arrives, the fingers land one every 80 ms.
    private func startLanding() {
        guard landing, !reduceMotion, landStart == nil else { return }
        landStart = Date().addingTimeInterval(0.25)
        let fingers = chord.frets.filter { $0 > 0 }.count
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25 + Double(max(0, fingers - 1)) * 0.08 + 0.6))
            landed = true
        }
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
    static func name(_ midi: Int) -> String { "\(pitchClass(midi))\(midi / 12 - 1)" }
    /// In the player's note-naming system (Settings › Note names): B♭ is B and B is H in German.
    static func pitchClass(_ midi: Int) -> String { NoteNames.spell(names[((midi % 12) + 12) % 12], system: NoteNames.active) }
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
    /// Strums: down arrows on the beat, up arrows between beats.
    var arrows = false

    var body: some View {
        Canvas { context, size in
            // Inset by the largest dot and its halo (15) plus air, so the first hit isn't clipped.
            let left: CGFloat = 22, right = size.width - 14
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
                if arrows {
                    let down = hit.truncatingRemainder(dividingBy: 1) == 0
                    let arrow = Text(Image(systemName: down ? "arrow.down" : "arrow.up")).font(.system(size: r * 1.15, weight: .black)).foregroundStyle(Palette.onAccent)
                    context.draw(arrow, at: CGPoint(x: x, y: mid))
                }
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
    /// Explanations give the photograph whatever room the card has.
    var height: CGFloat = 260
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
        .frame(height: height)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

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
                    .shadow(color: .black.opacity(0.6), radius: 22, y: 16)
                    .rotationEffect(.degrees(floating ? -8 : -12))
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let moving = active && !reduceMotion
            let beatPhase = (t / period).truncatingRemainder(dividingBy: 1)
            let pulse: CGFloat = moving && beat ? CGFloat(1 + 0.07 * exp(-7 * beatPhase)) : 1
            ZStack {
                Canvas { context, size in draw(&context, size: size, t: t, moving: moving) }
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 30, weight: .semibold)).foregroundStyle(Palette.onAccent)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(accent))
                        .shadow(color: accent.opacity(0.55), radius: 20)
                        .scaleEffect(pulse)
                }
            }
        }
        .accessibilityHidden(true)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let secondsPerBeat = 60 / bpm
            let bar = Double(max(1, beatsPerBar)) * secondsPerBeat
            let elapsed = max(0, timeline.date.timeIntervalSince(start))
            let through = (elapsed / bar).truncatingRemainder(dividingBy: 1)
            VStack(spacing: 10) {
                if let sweep {
                    StrumSweep(pattern: pattern, beatsPerBar: beatsPerBar, strings: strings, style: sweep, accent: accent,
                               secondsPerBeat: secondsPerBeat, time: reduceMotion ? nil : elapsed)
                        .frame(maxHeight: .infinity)
                }
                RhythmBar(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, playhead: reduceMotion ? nil : through, arrows: arrows)
            }
        }
    }
}
