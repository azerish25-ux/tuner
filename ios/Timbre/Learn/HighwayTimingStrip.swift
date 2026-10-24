import SwiftUI
import TimbreCore

/// The take's timing, note by note, for the results card: a dot per note in play order, above the line when it
/// came early and below when late, in its grade's colour (white-gold perfect, the course colour good, amber late
/// or early); a missed note is a coral cross on the line. A gold band marks perfect timing and a fainter one good;
/// a dashed amber line marks the average lean when it is off the beat. The dots land one by one (all at once with
/// Reduce Motion). Its words are in the timing note under it, so VoiceOver skips the drawing.
struct HighwayTimingStrip: View {
    let count: Int
    let judgments: [PlayAlongJudge.Judgment]
    let accent: Color
    var calm = false
    @State private var landed = false

    /// Offsets this far either way reach the edge (the judge takes a note up to 0.2 s early and 0.32 s late).
    static let range = 0.3
    /// The average lean worth a line, as in "About 160 ms early on average".
    private static let lean = 0.035

    var body: some View {
        HStack(spacing: 8) {
            axis
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in drawBands(&context, size: size) }
                    Canvas { context, size in drawTrend(&context, size: size) }
                        .opacity(landed || calm ? 1 : 0)
                        .animation(calm ? nil : Animation.easeIn(duration: 0.3).delay(landingDelay(count)), value: landed)
                    ForEach(judgments, id: \.index) { judgment in
                        mark(judgment)
                            .scaleEffect(landed || calm ? 1 : 0.2)
                            .opacity(landed || calm ? 1 : 0)
                            .animation(calm ? nil : Motion.pluck.delay(landingDelay(judgment.index)), value: landed)
                            .position(point(judgment, in: proxy.size))
                    }
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.stageRaised.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
        .onAppear { landed = true }
        .accessibilityHidden(true)
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
        } else {
            let tint = TakeRibbon.color(judgment.grade, accent: accent)
            Circle()
                .fill(tint)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
                .frame(width: dot, height: dot)
                .shadow(color: tint.opacity(judgment.grade == .perfect ? 0.7 : 0), radius: 4)
        }
    }

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
