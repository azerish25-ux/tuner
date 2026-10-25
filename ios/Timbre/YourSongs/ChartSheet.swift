import SwiftUI
import TimbreCore

/// A chart as a Studio Noir song sheet: each section under its name (a chorus marked by a bar of the accent down its
/// side), chords in Sora over the syllables they fall on, lines wrapping word by word to the width, rows of chords on
/// their own as chips between bar lines, comments in a quiet plate, tabs in a fixed-width face. The chord sounding (or, while
/// syncing, the next one to tap) is lit. Chords are shown as the player plays them: transposed and written for their
/// capo (`ChartTransform`). Every line carries an id (`lineID`) to scroll to.
struct ChartSheetView: View {
    let chart: ChordChart
    let transform: ChartTransform
    /// The chord lit: an index into `chart.chordSequence`.
    var current: Int?
    /// Lit for a tap (ink) rather than as sounding (the accent).
    var syncing = false
    /// The player's text size on top of Dynamic Type.
    var textScale: CGFloat = 1
    var accent: Color = Palette.mint

    @ScaledMetric(relativeTo: .body) private var lyricSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var chordSize: CGFloat = 15
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func lineID(section: Int, line: Int) -> Int { section * 10_000 + line }

    /// The line a chord of `chordSequence` sits on.
    static func lineID(of ref: ChartChordRef) -> Int { lineID(section: ref.section, line: ref.line) }

    var body: some View {
        let names = transform.names(for: chart)
        let indexes = Self.chordIndexes(chart)
        VStack(alignment: .leading, spacing: 22) {
            ForEach(Array(chart.sections.enumerated()), id: \.offset) { item in
                sectionView(item.element, at: item.offset, names: names, indexes: indexes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sections

    private func sectionView(_ section: ChartSection, at index: Int, names: [String], indexes: [Int: Int]) -> some View {
        let chorus = section.kind == .chorus
        return VStack(alignment: .leading, spacing: 8) {
            if let title = sectionTitle(section) {
                sectionHeader(title, repeated: section.isRepeat, chorus: chorus)
            }
            ForEach(Array(section.lines.enumerated()), id: \.offset) { item in
                lineView(item.element, section: index, line: item.offset, names: names, indexes: indexes)
                    .id(Self.lineID(section: index, line: item.offset))
            }
        }
        .padding(.leading, chorus ? 14 : 0)
        .overlay(alignment: .leading) {
            if chorus {
                Capsule().fill(accent.opacity(0.55)).frame(width: 3).padding(.vertical, 2)
                    .accessibilityHidden(true)
            }
        }
    }

    private func sectionTitle(_ section: ChartSection) -> Text? {
        if let label = section.label, !label.isEmpty { return Text(verbatim: label) }
        switch section.kind {
        case .chorus: return Text("Chorus")
        case .verse: return Text("Verse")
        case .bridge: return Text("Bridge")
        case .tab: return Text("Tab")
        case .grid: return Text("Chords")
        case .other, .untitled: return nil
        }
    }

    private func sectionHeader(_ title: Text, repeated: Bool, chorus: Bool) -> some View {
        HStack(spacing: 8) {
            // A section of the song is section level: its name in small capitals, as a chart prints it.
            Eyebrow(title, color: chorus ? accent : Palette.inkSoft, style: .display, level: .section)
            if repeated {
                Label("Again", systemImage: "repeat").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
                    .labelStyle(.titleAndIcon)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Lines

    @ViewBuilder private func lineView(_ line: ChartLine, section: Int, line number: Int, names: [String], indexes: [Int: Int]) -> some View {
        switch line {
        case .blank:
            Color.clear.frame(height: lyricSize * textScale * 0.4).accessibilityHidden(true)
        case .comment(let text):
            commentView(text)
        case .verbatim(let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: text).font(.system(size: 14 * textScale, design: .monospaced)).foregroundStyle(Palette.inkSoft)
                    .fixedSize()
            }
            .accessibilityLabel(Text(verbatim: text))
        case .lyrics(let segments):
            lyricLine(Self.tokens(segments, section: section, line: number, indexes: indexes), barRow: Self.isBarRow(segments), names: names)
        }
    }

    private func commentView(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "text.bubble.fill").font(.system(size: 12 * textScale, weight: .semibold)).accessibilityHidden(true)
            Text(verbatim: text).font(.system(size: lyricSize * textScale * 0.88).italic())
        }
        .foregroundStyle(Palette.inkSoft)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder private func lyricLine(_ tokens: [Token], barRow: Bool, names: [String]) -> some View {
        let spoken = Self.spoken(tokens, display: { display($0, names: names) })
        if !tokens.contains(where: { $0.chord != nil }) {
            Text(verbatim: tokens.map { $0.text + ($0.gap ? " " : "") }.joined())
                .font(.system(size: lyricSize * textScale)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else if barRow {
            ChordFlowLayout(spacing: 10, lineSpacing: 8) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { item in
                    HStack(spacing: 8) {
                        if let chord = item.element.chord { chordLabel(chord, index: item.element.index, names: names) }
                        if !item.element.text.isEmpty {
                            Text(verbatim: item.element.text).font(.system(size: lyricSize * textScale)).foregroundStyle(Palette.inkFaint)
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
        } else {
            ChordFlowLayout(spacing: 0, lineSpacing: 6) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { item in
                    tokenView(item.element, names: names)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
        }
    }

    /// A word with its chord over it (an empty, invisible chord keeps the row's height).
    private func tokenView(_ token: Token, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let chord = token.chord {
                chordLabel(chord, index: token.index, names: names).padding(.trailing, 6)
            } else {
                Text(verbatim: " ").font(.custom("Sora-SemiBold", fixedSize: chordSize * textScale)).padding(.vertical, 1).hidden()
            }
            Text(verbatim: token.text).font(.system(size: lyricSize * textScale)).foregroundStyle(Palette.ink)
        }
        .padding(.trailing, token.gap ? lyricSize * textScale * 0.28 : 0)
    }

    /// A chord as the player reads it; the one sounding sits in a pill of the accent (ink while syncing, waiting for
    /// the tap), glowing while it plays.
    private func chordLabel(_ chord: String, index: Int?, names: [String]) -> some View {
        let lit = index != nil && index == current
        let fill: Color = syncing ? Palette.ink : accent
        return Text(verbatim: display(chord, names: names))
            .font(.custom("Sora-SemiBold", fixedSize: chordSize * textScale))
            .foregroundStyle(lit ? (syncing ? Palette.stage : Palette.onAccent) : accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(Capsule().fill(fill).opacity(lit ? 1 : 0))
            .shadow(color: fill.opacity(lit ? 0.55 : 0), radius: 8)
            .scaleEffect(lit && !reduceMotion ? 1.08 : 1, anchor: .bottomLeading)
            .offset(x: -4)
            .animation(Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion), value: lit)
    }

    private func display(_ chord: String, names: [String]) -> String {
        let shape = transform.shape(chord, names: names)
        let written = shape.hasPrefix("*") ? String(shape.dropFirst()) : shape
        return NoteNames.glyphs(NoteNames.chordSymbol(written))
    }

    // MARK: Words

    /// One word of a lyric line: the chord placed on it (and that chord's place in `chordSequence`), the word without
    /// its spaces, and whether a space follows it.
    struct Token: Equatable {
        let chord: String?
        let index: Int?
        let text: String
        let gap: Bool
    }

    static func tokens(_ segments: [ChartSegment], section: Int, line: Int, indexes: [Int: Int]) -> [Token] {
        var out: [Token] = []
        for (number, segment) in segments.enumerated() {
            let index = segment.chord == nil ? nil : indexes[key(section: section, line: line, segment: number)]
            for (position, word) in words(segment.text).enumerated() {
                out.append(Token(chord: position == 0 ? segment.chord : nil, index: position == 0 ? index : nil, text: word.text, gap: word.gap))
            }
        }
        return out
    }

    /// The words of a segment's text, each with whether a space follows; one empty word for an empty text (a chord
    /// with nothing under it).
    static func words(_ text: String) -> [(text: String, gap: Bool)] {
        guard !text.isEmpty else { return [("", false)] }
        var out: [(text: String, gap: Bool)] = []
        var word = ""
        var spaced = false
        for character in text {
            if character == " " {
                spaced = true
                continue
            }
            if spaced {
                out.append((word, true))
                word = ""
                spaced = false
            }
            word.append(character)
        }
        out.append((word, spaced))
        return out
    }

    static func isBarRow(_ segments: [ChartSegment]) -> Bool {
        segments.contains { $0.chord != nil } && segments.allSatisfy(\.isBarText)
    }

    /// Where each chord of `chordSequence` sits, by section, line and segment.
    static func chordIndexes(_ chart: ChordChart) -> [Int: Int] {
        var out: [Int: Int] = [:]
        for (index, ref) in chart.chordSequence.enumerated() {
            out[key(section: ref.section, line: ref.line, segment: ref.segment)] = index
        }
        return out
    }

    private static func key(section: Int, line: Int, segment: Int) -> Int { section * 1_000_000 + line * 1_000 + segment }

    /// The line read aloud: each chord before the words it falls on.
    static func spoken(_ tokens: [Token], display: (String) -> String) -> String {
        var parts: [String] = []
        for token in tokens {
            if let chord = token.chord { parts.append(display(chord) + ":") }
            if !token.text.isEmpty && token.text != "|" { parts.append(token.text) }
        }
        return parts.joined(separator: " ")
    }
}

/// Lays its children out left to right, wrapping onto a new row when the next would pass the width: the words of a
/// lyric line under their chords, or a row of chord chips. A child wider than the width gets a row of its own.
struct ChordFlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 6

    private struct Placed {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }

    private struct Row {
        var items: [Placed] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map { $0.width }.max() ?? 0
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        if let proposed = proposal.width, proposed.isFinite { return CGSize(width: min(proposed, width), height: height) }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item.size))
            }
            y += row.height + lineSpacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if width.isFinite, size.width > width {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            }
            let x = row.items.isEmpty ? 0 : row.width + spacing
            if !row.items.isEmpty, width.isFinite, x + size.width > width {
                rows.append(row)
                row = Row()
                row.items.append(Placed(index: index, x: 0, size: size))
                row.width = size.width
                row.height = size.height
            } else {
                row.items.append(Placed(index: index, x: x, size: size))
                row.width = x + size.width
                row.height = max(row.height, size.height)
            }
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
