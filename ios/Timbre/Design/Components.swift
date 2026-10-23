import SwiftUI

/// Warm, dark stage lit from above. Optional floating motes catch the light.
struct StageBackground: View {
    var glow: Color = Palette.ember
    var intensity: Double = 1
    var motes = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Palette.stage
            RadialGradient(colors: [glow.opacity(0.22 * intensity), .clear], center: UnitPoint(x: 0.5, y: 0.18), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.9)], center: .center, startRadius: 240, endRadius: 760)
            if motes && !reduceMotion { MoteField().opacity(0.55 * intensity).allowsHitTesting(false) }
        }
        .ignoresSafeArea()
    }
}

private struct MoteField: View {
    private struct Mote { let x, y, r, speed, phase: Double }
    private static let motes: [Mote] = {
        var g = SystemRandom(seed: 11)
        return (0..<46).map { _ in Mote(x: g.next(), y: g.next(), r: 0.6 + 1.8 * g.next(), speed: 0.004 + 0.012 * g.next(), phase: g.next() * 6.28) }
    }()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for m in Self.motes {
                    let y = (m.y - t * m.speed).truncatingRemainder(dividingBy: 1)
                    let yy = (y < 0 ? y + 1 : y) * size.height
                    let xx = m.x * size.width + sin(t * 0.3 + m.phase) * 14
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.8 + m.phase * 3))
                    let rect = CGRect(x: xx - m.r, y: yy - m.r, width: m.r * 2, height: m.r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.brass.opacity(0.35 * twinkle)))
                }
            }
        }
    }
}

/// Tiny deterministic generator for decorative layouts.
struct SystemRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

extension View {
    /// Raised glass panel. Liquid Glass on iOS 26, material on iOS 18.
    @ViewBuilder func stillCard(cornerRadius: CGFloat = Metrics.corner, padding: CGFloat = 18, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let padded = self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
        if #available(iOS 26.0, *) {
            padded.glassEffect(tint.map { Glass.regular.tint($0.opacity(0.18)) } ?? Glass.regular, in: shape)
        } else {
            padded
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Palette.line.opacity(0.9), lineWidth: 0.5))
        }
    }

    /// Floating control capsule over the stage.
    @ViewBuilder func glassCapsule(interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().strokeBorder(Palette.line, lineWidth: 0.5))
        }
    }
}

struct Eyebrow: View {
    let text: LocalizedStringKey
    var color: Color = Palette.brass
    init(_ text: LocalizedStringKey, color: Color = Palette.brass) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(Typeface.eyebrow).tracking(2.2).textCase(.uppercase).foregroundStyle(color)
    }
}

struct ScreenTitle: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(40)).foregroundStyle(Palette.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(Palette.inkSoft) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Gold primary action with a soft inner light and a pluck on press.
struct BrassButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(prominent ? Color(hex: 0x1A1206) : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .background {
                if prominent {
                    Capsule().fill(LinearGradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xD3A65C), Color(hex: 0xB0823F)], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
                        .shadow(color: Palette.ember.opacity(configuration.isPressed ? 0.15 : 0.35), radius: configuration.isPressed ? 6 : 18, y: 6)
                } else {
                    Capsule().fill(Palette.stageRaised).overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct ChipButtonStyle: ButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundStyle(selected ? Color(hex: 0x1A1206) : Palette.ink)
            .background(Capsule().fill(selected ? AnyShapeStyle(Palette.brass) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(Capsule().strokeBorder(selected ? .clear : Palette.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO").font(.system(size: 10, weight: .heavy)).tracking(1.4)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(Color(hex: 0x1A1206))
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xC8954A)], startPoint: .top, endPoint: .bottom)))
            .accessibilityLabel("Pro")
    }
}

struct IconOrb: View {
    let symbol: String
    var tint: Color = Palette.brass
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.14)))
            .overlay(Circle().strokeBorder(tint.opacity(0.28), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Large tappable row used across hubs and settings-like lists.
struct FeatureRow<Trailing: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var tint: Color = Palette.brass
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 14) {
            IconOrb(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
    }
}

extension FeatureRow where Trailing == EmptyView {
    init(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, tint: Color = Palette.brass) {
        self.init(symbol: symbol, title: title, detail: detail, tint: tint) { EmptyView() }
    }
}
