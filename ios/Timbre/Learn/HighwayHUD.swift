import SwiftUI

/// The play-along's heads-up display, over the stage's top corners while a take plays: the run of perfect and
/// good notes in a row on the left, the multiplier on the right in a ring that fills toward its next step (×2 from
/// 4 in a row, ×3 from 8, ×4 from 16, as `ComboBadge` counts it). The count pops on every note of the run and
/// dims when the run breaks; the dial pulses, warms and catches fire as the multiplier climbs.
struct HighwayHUD: View {
    let combo: Int
    /// Reduce Motion: no pops or pulses.
    var calm = false

    private var level: Int { ComboBadge.multiplier(combo) }
    private var tint: Color { ComboBadge.tint(level) }

    /// The digits roll to each new count. A store capture changes them in place instead: a roll lasts
    /// `Motion.quick` and a run grows several times a second, so a still picture would catch a ghosted digit.
    /// The take's other running counts (the ribbon's tallies) change the same way.
    static func digitTransition(_ value: Int) -> ContentTransition {
        #if DEBUG
        if DemoScene.stillScore { return .identity }
        #endif
        return .numericText(value: Double(value))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            counter
            Spacer(minLength: 0)
            dial
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        // It sits over the board: large type grows it only so far, and a long press shows it magnified.
        .cappedControl(Text("Combo \(combo), ×\(level)"), symbol: "flame.fill", cap: .xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combo"))
        .accessibilityValue(Text(verbatim: "\(combo), ×\(level)"))
    }

    /// The run so far, big, over its name.
    private var counter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(combo, format: .number)
                .font(Typeface.number(.title))
                .foregroundStyle(combo > 0 ? Palette.ink : Palette.inkFaint)
                .contentTransition(Self.digitTransition(combo))
                .shadow(color: tint.opacity(level >= 2 ? 0.6 : 0), radius: 10)
            Eyebrow("Combo", color: level >= 2 ? tint : Palette.inkSoft, style: .display)
        }
        .phaseAnimator([1.0, 1.16], trigger: combo) { content, scale in
            content.scaleEffect(calm || combo == 0 ? 1 : CGFloat(scale), anchor: .leading)
        } animation: { _ in Motion.pop }
        .animation(calm ? nil : Motion.quick, value: combo)
    }

    /// The multiplier in a ring filling toward the next step, a flame beside it from ×2.
    private var dial: some View {
        HStack(spacing: 6) {
            if level >= 2 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: calm ? 0 : level)
                    .transition(.scale.combined(with: .opacity))
            }
            ZStack {
                Circle().fill(Palette.stageDeep.opacity(0.7))
                Circle().stroke(tint.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.001, ComboBadge.progress(combo)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "×\(level)")
                    .font(Typeface.number(17))
                    .foregroundStyle(level >= 2 ? tint : Palette.inkSoft)
                    .contentTransition(Self.digitTransition(level))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 48, height: 48)
            .shadow(color: tint.opacity(level >= 3 ? 0.55 : 0), radius: 12)
        }
        .phaseAnimator([1.0, 1.22], trigger: level) { content, scale in
            content.scaleEffect(calm ? 1 : CGFloat(scale), anchor: .trailing)
        } animation: { _ in Motion.pop }
        .animation(calm ? nil : Motion.quick, value: combo)
        .animation(calm ? nil : Motion.pluck, value: level)
    }
}
