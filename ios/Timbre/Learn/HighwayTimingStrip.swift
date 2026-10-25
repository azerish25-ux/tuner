import SwiftUI
import TimbreCore

/// The take's timing, note by note, for the results card: a dot per note in play order, above the line when it
/// came early and below when late, in its grade's colour (white-gold perfect, the course colour good, amber late
/// or early); a missed note is a coral cross on the line. A gold band marks perfect timing and a fainter one good;
/// a dashed amber line marks the average lean when it is off the beat. The dots land one by one (all at once with
/// Reduce Motion). Its words are in the timing note under it, so VoiceOver skips the drawing.
///
/// Given `onLoop`, the misses are ringed and tapping one (anywhere in its column) hands its index over, so the
/// play-along can loop that note's bar at a slower tempo; a line under the strip says so, and VoiceOver then reads
/// the strip as the count of misses with an action per bar that has one.
///
/// Under a whole song's take (the finale, which sets `takeSections`), the song's sections follow as a ribbon, each
/// as long as its bars and named with its score where there is room ("Chorus 96 %").
struct HighwayTimingStrip: View {
    let count: Int
    let judgments: [PlayAlongJudge.Judgment]
    let accent: Color
    var calm = false
    /// Takes a missed note's index when it is tapped; nil leaves the strip still.
    var onLoop: ((Int) -> Void)?
    /// The bar (0 first) each note falls in, for the VoiceOver actions.
    var bar: (Int) -> Int = { $0 }
    @State private var landed = false
    @Environment(\.takeSections) private var sections

    /// Offsets this far either way reach the edge (the judge takes a note up to 0.2 s early and 0.32 s late).
    static let range = 0.3
    /// The average lean worth a line, as in "About 160 ms early on average".
    private static let lean = 0.035

    private var misses: [PlayAlongJudge.Judgment] { judgments.filter { $0.grade == .miss } }
    private var loops: Bool { onLoop != nil && !misses.isEmpty }

    var body: some View {
        VStack(spacing: 12) {
            timing
            if !sections.isEmpty {
                SectionRibbon(sections: sections, calm: calm)
            }
        }
    }

    private var timing: some View {
        VStack(spacing: 6) {
            strip
            if loops {
                Label("Tap a miss to loop its bar", systemImage: "repeat")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!loops)
        .accessibilityLabel(Text("Missed"))
        .accessibilityValue(Text(misses.count, format: .number))
        .accessibilityActions {
            ForEach(missedBars, id: \.self) { which in
                Button { loopBar(which) } label: { Text("Loop bar \(which + 1)") }
            }
        }
    }

    private var strip: some View {
        HStack(spacing: 8) {
            axis
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in drawBands(&context, size: size) }
                    Canvas { context, size in drawTrend(&context, size: size) }
                        .opacity(landed || calm ? 1 : 0)
                        .animation(calm ? nil : Motion.fade.delay(landingDelay(count)), value: landed)
                    ForEach(judgments, id: \.index) { judgment in
                        mark(judgment)
                            .scaleEffect(landed || calm ? 1 : 0.2)
                            .opacity(landed || calm ? 1 : 0)
                            .animation(calm ? nil : Motion.pluck.delay(landingDelay(judgment.index)), value: landed)
                            .position(point(judgment, in: proxy.size))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in tap(at: location, in: proxy.size) }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        // The take runs left to right in every language, as the runway it came from does.
        .environment(\.layoutDirection, .leftToRight)
        .onAppear { landed = true }
    }

    /// Early over late, beside the strip.
    private var axis: some View {
        VStack(alignment: .leading) {
            Text("Early")
            Spacer(minLength: 0)
            Text("Late")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Palette.inkFaint)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Each dot lands a beat after the one before, the whole strip inside about 0.8 s.
    private func landingDelay(_ index: Int) -> Double { 0.15 + Double(index) * min(0.06, 0.8 / Double(max(1, count))) }

    private var dot: CGFloat { count > 40 ? 5 : count > 20 ? 7 : 9 }

    private func point(_ judgment: PlayAlongJudge.Judgment, in size: CGSize) -> CGPoint {
        let x = size.width * (CGFloat(judgment.index) + 0.5) / CGFloat(max(1, count))
        let mid = size.height / 2
        guard let offset = judgment.offset else { return CGPoint(x: x, y: mid) }
        let lean = max(-1, min(1, offset / Self.range))
        return CGPoint(x: x, y: mid + CGFloat(lean) * (mid - dot / 2))
    }

    @ViewBuilder private func mark(_ judgment: PlayAlongJudge.Judgment) -> some View {
        if judgment.grade == .miss {
            Image(systemName: "xmark")
                .font(.system(size: dot, weight: .heavy))
                .foregroundStyle(Palette.danger)
                // Ringed when it can be tapped to loop its bar.
                .background {
                    if onLoop != nil {
                        Circle().fill(Palette.danger.opacity(0.12))
                            .overlay(Circle().strokeBorder(Palette.danger.opacity(0.5), lineWidth: 1.2))
                            .frame(width: dot + 12, height: dot + 12)
                    }
                }
        } else {
            let tint = TakeRibbon.color(judgment.grade, accent: accent)
            Circle()
                .fill(tint)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
                .frame(width: dot, height: dot)
                .shadow(color: tint.opacity(judgment.grade == .perfect ? 0.7 : 0), radius: 4)
        }
    }

    // MARK: Looping a missed bar

    /// The bars with a missed note, in order.
    private var missedBars: [Int] {
        guard onLoop != nil else { return [] }
        return Array(Set(misses.map { bar($0.index) })).sorted()
    }

    /// A tap picks the missed note nearest across, within its column (at least a finger's width).
    private func tap(at location: CGPoint, in size: CGSize) {
        guard let onLoop else { return }
        let reach = max(22, size.width / CGFloat(max(1, count)))
        let nearest = misses.min { abs(point($0, in: size).x - location.x) < abs(point($1, in: size).x - location.x) }
        guard let nearest, abs(point(nearest, in: size).x - location.x) <= reach else { return }
        onLoop(nearest.index)
    }

    private func loopBar(_ which: Int) {
        guard let onLoop, let first = misses.sorted(by: { $0.index < $1.index }).first(where: { bar($0.index) == which }) else { return }
        onLoop(first.index)
    }

    // MARK: Drawing

    /// The good and perfect windows round the beat, and the beat itself.
    private func drawBands(_ context: inout GraphicsContext, size: CGSize) {
        let mid = size.height / 2
        let span = mid - dot / 2
        func band(_ seconds: Double) -> CGRect {
            let h = span * CGFloat(seconds / Self.range)
            return CGRect(x: 0, y: mid - h, width: size.width, height: h * 2)
        }
        context.fill(Path(roundedRect: band(PlayAlongJudge.goodSeconds), cornerRadius: 4), with: .color(.white.opacity(0.04)))
        context.fill(Path(roundedRect: band(PlayAlongJudge.perfectSeconds), cornerRadius: 3), with: .color(HighwayRunway.perfectGold.opacity(0.12)))
        context.fill(Path(CGRect(x: 0, y: mid - 0.5, width: size.width, height: 1)), with: .color(.white.opacity(0.28)))
    }

    /// A faint line through the notes as they came, and the average lean when it is off the beat.
    private func drawTrend(_ context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        var started = false
        var sum = 0.0, timed = 0
        for judgment in judgments.sorted(by: { $0.index < $1.index }) {
            guard let offset = judgment.offset else { continue }
            sum += offset; timed += 1
            let p = point(judgment, in: size)
            if started { path.addLine(to: p) } else { path.move(to: p); started = true }
        }
        if timed >= 2 {
            context.stroke(path, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        }
        guard timed > 0 else { return }
        let mean = sum / Double(timed)
        guard abs(mean) >= Self.lean else { return }
        let mid = size.height / 2
        let y = mid + CGFloat(max(-1, min(1, mean / Self.range))) * (mid - dot / 2)
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(line, with: .color(Palette.amber.opacity(0.7)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
    }
}

// MARK: - The song's sections

/// One section of a song as a take went: its name, where it sits (first bar, how many) and the share of its notes
/// played as the play-along scores them; no score for a section without notes (an intro the band plays alone).
struct TakeSection: Identifiable, Equatable {
    let id: Int
    let name: String
    let start: Int
    let bars: Int
    /// 0…1 over the notes sung or played in it.
    let score: Double?
    /// How many notes (chords, on a strummed take) it holds: a section of a handful is never called the strongest.
    var notes = 0
    /// The name in brief for a tile too narrow for it ("In", "Out"); nil to show the score alone there.
    var short: String?

    var percent: Int? { score.map { Int(($0 * 100).rounded()) } }

    /// "In" for an intro, "Out" for an outro: the bookends are short, and their tiles narrow.
    static func short(of section: SongSheet.Section) -> String? {
        switch section.part?.kind {
        case .intro?: return String(localized: "In", bundle: TimbreLocalization.bundle, comment: "Short for Intro, on a narrow tile")
        case .outro?: return String(localized: "Out", bundle: TimbreLocalization.bundle, comment: "Short for Outro, on a narrow tile")
        default: return nil
        }
    }
}

private struct TakeSectionsKey: EnvironmentKey {
    static let defaultValue: [TakeSection] = []
}

extension EnvironmentValues {
    /// The sections of the song whose take a timing strip shows (the song finale sets them); empty elsewhere.
    var takeSections: [TakeSection] {
        get { self[TakeSectionsKey.self] }
        set { self[TakeSectionsKey.self] = newValue }
    }
}

/// A song's sections side by side, each as long as its bars (never too narrow for its score) and lit by how its notes
/// went (mint from 90 %, amber below, faint without notes), named with its score where there is room ("Chorus 96 %",
/// an intro "In" on a narrow tile); under them, the strongest section and the one with most to gain, in words. The
/// tiles fill in from the left after the timing strip's dots, left to right in every language.
struct SectionRibbon: View {
    let sections: [TakeSection]
    var calm = false
    @State private var shown = false

    private static let gap: CGFloat = 3
    /// Room for a score ("100%") on a tile however short its section.
    private static let minimumWidth: CGFloat = 38
    /// Sections with fewer notes than this are too short to be called the strongest or the weakest.
    private static let telling = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let sizes = widths(in: proxy.size.width)
                HStack(spacing: Self.gap) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        tile(section)
                            .frame(width: index < sizes.count ? sizes[index] : 0)
                            .opacity(shown || calm ? 1 : 0)
                            .animation(calm ? nil : Motion.fade.delay(0.9 + Double(index) * 0.06), value: shown)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .frame(height: 44)
            if let summary {
                Text(summary)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Sections"))
        .accessibilityValue(Text(verbatim: spoken))
    }

    /// Each tile's width: its bars' share of the room, every tile given at least `minimumWidth` (or an equal share,
    /// on a song with more sections than fit at that width) and the rest shared out by bars.
    private func widths(in total: CGFloat) -> [CGFloat] {
        let count = sections.count
        guard count > 0 else { return [] }
        let room = max(0, total - Self.gap * CGFloat(count - 1))
        let floor = min(Self.minimumWidth, room / CGFloat(count))
        let spare = max(0, room - floor * CGFloat(count))
        let bars = sections.map { CGFloat(max(1, $0.bars)) }
        let totalBars = max(1, bars.reduce(0, +))
        return bars.map { floor + spare * $0 / totalBars }
    }

    private func tint(_ section: TakeSection) -> Color {
        guard let score = section.score else { return Palette.inkFaint }
        return score >= 0.9 ? Palette.mint : Palette.amber
    }

    private func tile(_ section: TakeSection) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let tint = tint(section)
        return shape
            .fill(tint.opacity(section.score == nil ? 0.08 : 0.08 + 0.22 * (section.score ?? 0)))
            .overlay(shape.strokeBorder(tint.opacity(section.score == nil ? 0.25 : 0.6), lineWidth: 1))
            .overlay {
                // The name, in brief when the tile is narrow, over the score; the score alone; or the score shrunk to
                // fit: never an empty tile.
                ViewThatFits(in: .horizontal) {
                    labelled(section.name, section, tint: tint)
                    labelled(section.short ?? section.name, section, tint: tint)
                    percentLabel(section, tint: tint)
                    percentLabel(section, tint: tint).minimumScaleFactor(0.5)
                }
                .lineLimit(1)
                .padding(.horizontal, 3)
            }
    }

    private func labelled(_ name: String, _ section: TakeSection, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(verbatim: name).font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
            percentLabel(section, tint: tint)
        }
    }

    @ViewBuilder private func percentLabel(_ section: TakeSection, tint: Color) -> some View {
        if let percent = section.percent {
            Text(verbatim: "\(percent)%").font(Typeface.number(.footnote)).foregroundStyle(tint == Palette.inkFaint ? Palette.inkSoft : tint)
        } else {
            Text(verbatim: "–").font(Typeface.number(.footnote)).foregroundStyle(Palette.inkFaint)
        }
    }

    /// The strongest and the weakest of the sections with enough notes to tell (eight; every scored section on a song
    /// with fewer than two such): "Strongest: Chorus, 96 % · Most to gain: Bridge, 71 %". A tie goes to the section
    /// with more notes, the harder part to keep clean. "Every section 90 %+" when none fell below; nothing with fewer
    /// than two sections scored.
    private var summary: LocalizedStringKey? {
        let scored = sections.filter { $0.score != nil }
        let telling = scored.filter { $0.notes >= Self.telling }
        let pool = telling.count >= 2 ? telling : scored
        guard pool.count >= 2 else { return nil }
        let best = pool.max { Self.ranks($0, below: $1) }
        let worst = pool.min { Self.ranks($0, aboveForGain: $1) }
        guard let best, let worst, let high = best.percent, let low = worst.percent else { return nil }
        if low >= 90 { return "Every section 90%+" }
        if best.id == worst.id { return "Strongest: \(best.name), \(high)%" }
        return "Strongest: \(best.name), \(high)% · Most to gain: \(worst.name), \(low)%"
    }

    /// `a` ranks below `b` for strongest: a lower score, or the same score over fewer notes.
    private static func ranks(_ a: TakeSection, below b: TakeSection) -> Bool {
        let x = a.score ?? 0, y = b.score ?? 0
        return x != y ? x < y : a.notes < b.notes
    }

    /// `a` has more to gain than `b`: a lower score, or the same score over more notes.
    private static func ranks(_ a: TakeSection, aboveForGain b: TakeSection) -> Bool {
        let x = a.score ?? 0, y = b.score ?? 0
        return x != y ? x < y : a.notes > b.notes
    }

    /// Every section with its score, for VoiceOver ("Verse 1, 92 %; Chorus, 96 %").
    private var spoken: String {
        sections.compactMap { section in
            section.percent.map { "\(section.name), \($0) %" }
        }.joined(separator: "; ")
    }
}
