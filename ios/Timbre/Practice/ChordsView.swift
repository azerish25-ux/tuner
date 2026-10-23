import SwiftUI
import TimbreCore

struct ChordsView: View {
    enum Mode { case chords, scales }
    let mode: Mode
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @State private var root = 0
    @State private var formula = ChordFormula.all[0]
    @State private var scale = ScaleFormula.all[3]

    /// Open-string pitches for the current tuning, one per physical string group.
    private var openMidi: [Int] {
        var seen = Set<String>()
        return store.courses.compactMap { course in
            let key = course.anchorId ?? "\(course.index)"
            return seen.insert(key).inserted ? course.targetMidi : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.tuning.name.localized + " · " + store.instrumentDisplayName).font(.subheadline).foregroundStyle(Palette.inkSoft)
                rootPicker
                if mode == .chords { chordContent } else { scaleContent }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
        }
        .background(StageBackground(motes: false))
        .navigationTitle(mode == .chords ? "Chords" : "Scales")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.beginPractice(mode == .chords ? DailyActivity.Kind.chord.rawValue : DailyActivity.Kind.scale.rawValue) }
        .onDisappear { store.finishPractice(mode == .chords ? .chord : .scale) }
    }

    private var rootPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<12, id: \.self) { pc in
                    Button(NoteNames.name(pc, preferFlats: [1, 3, 8, 10].contains(pc))) { root = pc; Haptics.shared.selection() }
                        .buttonStyle(ChipButtonStyle(selected: root == pc))
                }
            }
        }
    }

    @ViewBuilder private var chordContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ChordFormula.all) { f in
                    Button(f.suffix.isEmpty ? String(localized: "Major") : f.suffix) { formula = f }.buttonStyle(ChipButtonStyle(selected: formula == f))
                }
            }
        }
        let name = NoteNames.name(root, preferFlats: [1, 3, 8, 10].contains(root)) + formula.suffix
        HStack(alignment: .firstTextBaseline) {
            Text(name).font(Typeface.display(56)).foregroundStyle(Palette.ink)
            Text(formula.name).font(.subheadline).foregroundStyle(Palette.inkSoft)
            Spacer()
        }
        let shapes = ChordFinder.shapes(root: root, formula: formula, openMidi: openMidi, limit: 6)
        if shapes.isEmpty {
            Text("No comfortable shape for this chord in this tuning.").foregroundStyle(Palette.inkSoft).stillCard()
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(shapes, id: \.self) { shape in
                Button { strum(shape) } label: {
                    VStack(spacing: 8) {
                        ChordDiagram(shape: shape).frame(height: 170)
                        Text(shape.notation).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                    }
                    .stillCard(cornerRadius: 22, padding: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(name), \(shape.notation). Double tap to hear."))
            }
        }
    }

    private func strum(_ shape: ChordShape) {
        let frequencies = shape.frets.enumerated().compactMap { index, fret in
            fret.map { PitchMath.frequency(midi: Double(openMidi[index] + $0), reference: store.settings.referencePitchHz) }
        }
        audio.playTones(frequencies, together: true, noteMs: 1500)
    }

    @ViewBuilder private var scaleContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ScaleFormula.all) { s in Button(s.name) { scale = s }.buttonStyle(ChipButtonStyle(selected: scale == s)) }
            }
        }
        Text(NoteNames.name(root, preferFlats: [1, 3, 8, 10].contains(root)) + " " + scale.name).font(Typeface.display(40)).foregroundStyle(Palette.ink)
        ScrollView(.horizontal, showsIndicators: true) {
            Fretboard(openMidi: openMidi, positions: ScaleMap.positions(root: root, scale: scale, openMidi: openMidi, frets: 0...15), frets: 15)
                .frame(width: 900, height: CGFloat(openMidi.count) * 30 + 40)
        }
        .stillCard(padding: 12)
        Button {
            let base = (openMidi.min() ?? 48) + ((root - (openMidi.min() ?? 48)) % 12 + 12) % 12
            let notes = (scale.intervals + [12]).map { PitchMath.frequency(midi: Double(base + $0), reference: store.settings.referencePitchHz) }
            audio.playTones(notes, together: false, noteMs: 380, gapMs: 40)
        } label: { Label("Hear the scale", systemImage: "speaker.wave.2.fill") }
        .buttonStyle(BrassButtonStyle())
    }
}

/// Vertical chord box: strings top to bottom, nut or base fret, finger dots.
struct ChordDiagram: View {
    let shape: ChordShape
    var body: some View {
        Canvas { context, size in
            let strings = shape.frets.count
            let base = shape.highestFret <= 4 ? 1 : shape.lowestFret
            let rows = 4
            let left: CGFloat = 22, right = size.width - 14, top: CGFloat = 26, bottom = size.height - 8
            let dx = (right - left) / CGFloat(max(1, strings - 1)), dy = (bottom - top) / CGFloat(rows)
            for i in 0..<strings {
                var line = Path(); line.move(to: CGPoint(x: left + CGFloat(i) * dx, y: top)); line.addLine(to: CGPoint(x: left + CGFloat(i) * dx, y: bottom))
                context.stroke(line, with: .color(Palette.inkSoft.opacity(0.6)), lineWidth: 1)
            }
            for j in 0...rows {
                var line = Path(); line.move(to: CGPoint(x: left, y: top + CGFloat(j) * dy)); line.addLine(to: CGPoint(x: right, y: top + CGFloat(j) * dy))
                context.stroke(line, with: .color(j == 0 && base == 1 ? Palette.ink : Palette.inkFaint.opacity(0.7)), lineWidth: j == 0 && base == 1 ? 4 : 1)
            }
            if base > 1 {
                context.draw(Text("\(base)fr").font(.caption2).foregroundStyle(Palette.inkSoft), at: CGPoint(x: 8, y: top + dy / 2))
            }
            for (i, fret) in shape.frets.enumerated() {
                let x = left + CGFloat(i) * dx
                guard let fret else {
                    context.draw(Text("×").font(.caption.weight(.bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: x, y: 12))
                    continue
                }
                if fret == 0 {
                    context.stroke(Path(ellipseIn: CGRect(x: x - 5, y: 7, width: 10, height: 10)), with: .color(Palette.ink), lineWidth: 1.5)
                } else {
                    let y = top + (CGFloat(fret - base) + 0.5) * dy
                    context.fill(Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)),
                                 with: .linearGradient(Gradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xB0823F)]), startPoint: CGPoint(x: x, y: y - 8), endPoint: CGPoint(x: x, y: y + 8)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Horizontal fretboard with scale tones; roots glow.
struct Fretboard: View {
    let openMidi: [Int]
    let positions: [FretPosition]
    let frets: Int
    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 36, top: CGFloat = 20
            let width = size.width - left - 10, height = size.height - top - 20
            let rows = openMidi.count
            let dy = height / CGFloat(max(1, rows - 1))
            func x(_ fret: Int) -> CGFloat { left + width * CGFloat(fret) / CGFloat(frets) }
            context.fill(Path(roundedRect: CGRect(x: left, y: top - 8, width: width, height: height + 16), cornerRadius: 6), with: .color(Color(hex: 0x2A1A12)))
            for fret in 0...frets {
                var line = Path(); line.move(to: CGPoint(x: x(fret), y: top - 8)); line.addLine(to: CGPoint(x: x(fret), y: top + height + 8))
                context.stroke(line, with: .color(fret == 0 ? Palette.ink : Color(hex: 0xC9C2B6).opacity(0.7)), lineWidth: fret == 0 ? 4 : 1.5)
                if [3, 5, 7, 9, 15].contains(fret) || fret == 12 {
                    context.draw(Text("\(fret)").font(.caption2).foregroundStyle(Palette.inkFaint), at: CGPoint(x: (x(fret) + x(fret - 1)) / 2, y: top + height + 16))
                }
            }
            for row in 0..<rows {
                let y = top + height - CGFloat(row) * dy
                var line = Path(); line.move(to: CGPoint(x: left, y: y)); line.addLine(to: CGPoint(x: left + width, y: y))
                context.stroke(line, with: .color(Color(hex: 0xD8CFC2).opacity(0.75)), lineWidth: 1 + CGFloat(rows - row) * 0.25)
                context.draw(Text(NoteNames.name(openMidi[row] % 12)).font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: 14, y: y))
            }
            for p in positions {
                let cx = p.fret == 0 ? x(0) - 12 : (x(p.fret) + x(p.fret - 1)) / 2
                let cy = top + height - CGFloat(p.string) * dy
                let r: CGFloat = p.isRoot ? 11 : 9
                context.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(p.isRoot ? Palette.ember : Palette.brass.opacity(0.85)))
                context.draw(Text("\(p.degree)").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0x1A1206)), at: CGPoint(x: cx, y: cy))
            }
        }
        .accessibilityHidden(true)
    }
}
