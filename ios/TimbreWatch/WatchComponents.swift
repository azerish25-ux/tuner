import SwiftUI

/// The bar as a ring: one arc per beat, the downbeat in flame and the others in mint. Beats already played this bar
/// stay softly lit and the one just played is full, with a glow that flashes on the beat and fades before the next.
/// Under Reduce Motion the glow only fades (no swell); dimmed (Always On) the ring is a quiet outline.
struct BeatRing: View {
    let beats: Int
    /// The beat just played; nil while stopped.
    let current: Int?
    /// Changes on every beat.
    let pulse: Int
    /// Seconds the glow takes to fade.
    var fade: Double = 0.3
    var dimmed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let line = max(6, side * 0.075)
            ZStack {
                ForEach(0..<beats, id: \.self) { index in
                    arc(index, line: line)
                }
                if let current, !dimmed {
                    glow(current, line: line)
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }

    private func span(_ index: Int) -> (from: Double, to: Double) {
        let gap = beats > 1 ? 0.045 : 0
        let from = Double(index) / Double(beats) + gap / 2
        return (from, max(from + 0.01, Double(index + 1) / Double(beats) - gap / 2))
    }

    private func tint(_ index: Int) -> Color { index == 0 ? Palette.flame : Palette.mint }

    /// Full for the beat just played, half for the rest of the bar so far, a faint track ahead.
    private func level(_ index: Int) -> Double {
        guard let current else { return 0.18 }
        if index == current { return 1 }
        return index < current ? 0.45 : 0.18
    }

    private func arc(_ index: Int, line: CGFloat) -> some View {
        let range = span(index)
        let width = dimmed ? line * 0.45 : line
        return Circle().inset(by: line / 2)
            .trim(from: range.from, to: range.to)
            .stroke(tint(index).opacity(dimmed ? 0.35 : level(index)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.12), value: current)
    }

    private func glow(_ index: Int, line: CGFloat) -> some View {
        let range = span(index)
        return Circle().inset(by: line / 2)
            .trim(from: range.from, to: range.to)
            .stroke(tint(index), style: StrokeStyle(lineWidth: line * 1.3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .blur(radius: line * 0.7)
            .phaseAnimator([false, true], trigger: pulse) { content, lit in
                content
                    .opacity(lit ? 0.95 : 0)
                    .scaleEffect(lit && !reduceMotion ? 1.03 : 1)
            } animation: { lit in
                lit ? Animation.linear(duration: 0.03) : Animation.easeOut(duration: fade)
            }
    }
}

/// Today as a ring, as on the iPhone (`DailySetRing`): one arc per activity, as long as its minutes, in its colour,
/// lit once done. With no set (nothing synced yet, or a new day) it is a plain track.
struct SetRing: View {
    let steps: [WatchSnapshot.Step]
    var lineWidth: CGFloat = 7
    var gap = 0.06

    var body: some View {
        ZStack {
            if steps.isEmpty {
                Circle().inset(by: lineWidth / 2).stroke(Palette.line, lineWidth: lineWidth)
            } else {
                let spans = self.spans
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    arc(step, from: spans[index].from, to: spans[index].to)
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.9), value: steps)
        .accessibilityHidden(true)
    }

    private var spans: [(from: Double, to: Double)] {
        let total = Double(max(1, steps.reduce(0) { $0 + max(1, $1.minutes) }))
        let space = steps.count > 1 ? gap : 0
        var start = 0.0
        return steps.map { step in
            let length = Double(max(1, step.minutes)) / total
            defer { start += length }
            let from = start + space / 2
            return (from: from, to: max(from + 0.004, start + length - space / 2))
        }
    }

    private func arc(_ step: WatchSnapshot.Step, from: Double, to: Double) -> some View {
        let tint = Palette.accent(step.tint)
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        return ZStack {
            Circle().inset(by: lineWidth / 2).trim(from: from, to: to)
                .stroke(tint.opacity(0.2), style: style)
            Circle().inset(by: lineWidth / 2).trim(from: from, to: step.done ? to : from)
                .stroke(tint, style: style)
                .opacity(step.done ? 1 : 0)
                .shadow(color: tint.opacity(step.done ? 0.5 : 0), radius: lineWidth * 0.6)
        }
        .rotationEffect(.degrees(-90))
    }
}

/// The streak flame, lit once today counts: it sways gently while lit (still under Reduce Motion and Always On).
struct WristFlame: View {
    var lit: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        if lit && !reduceMotion && !dimmed {
            flame.phaseAnimator([false, true]) { content, up in
                content
                    .scaleEffect(x: 1, y: up ? 1.06 : 0.97, anchor: .bottom)
                    .rotationEffect(.degrees(up ? 2.5 : -2.5), anchor: .bottom)
            } animation: { _ in
                Animation.easeInOut(duration: 0.9)
            }
        } else {
            flame
        }
    }

    private var flame: some View {
        Image(systemName: "flame.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(lit ? AnyShapeStyle(Palette.flameFill) : AnyShapeStyle(Palette.inkFaint))
            .shadow(color: Palette.flame.opacity(lit ? 0.55 : 0), radius: 6)
            .accessibilityHidden(true)
    }
}

/// A thin bar for a quest's count.
struct ProgressBar: View {
    let value: Double
    var tint: Color = Palette.mint

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(tint).frame(width: max(4, proxy.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// A press that gives a little: buttons drawn as Studio Noir shapes rather than watchOS platters.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension View {
    /// A raised Studio Noir card.
    func wristCard() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}
