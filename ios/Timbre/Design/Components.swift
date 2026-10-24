import SwiftUI

/// Near-black stage under a warm spotlight. Optional floating motes catch the light.
struct StageBackground: View {
    var glow: Color = Color(hex: 0xFFC48C)
    var intensity: Double = 1
    var motes = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Palette.stage
            RadialGradient(colors: [glow.opacity(0.15 * intensity), .clear], center: UnitPoint(x: 0.5, y: 0.26), startRadius: 10, endRadius: 330)
            RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.9)], center: .center, startRadius: 260, endRadius: 760)
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
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.amber.opacity(0.22 * twinkle)))
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
    /// Raised surface: solid graphite with a hairline, optionally washed with a tint from its corner.
    func stillCard(cornerRadius: CGFloat = Metrics.corner, padding: CGFloat = 18, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        // contentShape keeps the whole card tappable when it styles a button (not just its text).
        return self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Palette.stageRaised)
                    .overlay { if let tint { shape.fill(LinearGradient(colors: [tint.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .center)) } }
            }
            .overlay(shape.strokeBorder(tint?.opacity(0.28) ?? .white.opacity(0.06), lineWidth: 1))
            .contentShape(shape)
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
            Text(title).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
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
            .foregroundStyle(prominent ? Palette.onAccent : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 18)
            .background {
                if prominent {
                    Capsule().fill(Palette.mint)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
                        .shadow(color: Palette.mint.opacity(configuration.isPressed ? 0.15 : 0.4), radius: configuration.isPressed ? 6 : 22, y: 6)
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
            .foregroundStyle(selected ? Palette.stage : Palette.ink)
            .background(Capsule().fill(selected ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(Capsule().strokeBorder(selected ? .clear : Palette.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

/// Plain button that gives a little under the finger.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO").font(.system(size: 10, weight: .heavy)).tracking(1.4)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(Palette.onAccent)
            .background(Capsule().fill(Palette.proGold))
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
