import SwiftUI

/// Near-black stage under a warm spotlight. Optional floating motes catch the light.
struct StageBackground: View {
    var glow: Color = Palette.spotlight
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
    /// Drifting only while on screen, the app in front and Low Power Mode off (`animatesWhileSeen`).
    @State private var live = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !live)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for m in Self.motes {
                    let y = (m.y - t * m.speed).truncatingRemainder(dividingBy: 1)
                    let yy = (y < 0 ? y + 1 : y) * size.height
                    let xx = m.x * size.width + sin(t * 0.3 + m.phase) * 14
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 0.8 + m.phase * 3))
                    let rect = CGRect(x: xx - m.r, y: yy - m.r, width: m.r * 2, height: m.r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.spotlight.opacity(0.22 * twinkle)))
                }
            }
        }
        .animatesWhileSeen($live)
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
    /// Pass `Metrics.cardPadding` (the default) for a card or `Metrics.tilePadding` for a tile, and a radius from
    /// the scale (`Metrics.corner` for a card, `cornerTile` for a tile, `cornerHero` for a hero).
    /// Increase Contrast: a brighter rim and a fainter wash, so faint text on the tinted corner stays legible.
    func stillCard(cornerRadius: CGFloat = Metrics.corner, padding: CGFloat = Metrics.cardPadding, tint: Color? = nil) -> some View {
        modifier(StillCard(cornerRadius: cornerRadius, padding: padding, tint: tint))
    }

    /// Floating control capsule over the stage (Liquid Glass on iOS 26, a material with a hairline before).
    func glassCapsule(interactive: Bool = true) -> some View {
        timbreGlass(interactive: interactive, in: Capsule()) {
            Capsule().fill(.ultraThinMaterial).overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 0.5))
        }
    }
}

private struct StillCard: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let tint: Color?
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let high = contrast == .increased
        let rim: Color = tint?.opacity(high ? 0.55 : 0.28) ?? Palette.hairline
        // contentShape keeps the whole card tappable when it styles a button (not just its text).
        return content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Palette.stageRaised)
                    .overlay {
                        if let tint {
                            shape.fill(LinearGradient(colors: [tint.opacity(high ? 0.08 : 0.16), .clear], startPoint: .topLeading, endPoint: .center))
                        }
                    }
            }
            .overlay(shape.strokeBorder(rim, lineWidth: 1))
            .contentShape(shape)
    }
}

/// A small label over a title or a group ("Unit 1 · Hello, guitar", "Tuning"). Capitals are for section level only:
/// an eyebrow over a group of cards or a list's section (`.section`) is set in small tracked capitals; one inside a
/// card or over a figure (`.label`, the default) is the same small type in sentence case. Budget: at most one per
/// card, and none in a card that already has a title. Write the text in sentence case: a section eyebrow capitalises
/// it for the reader's locale (never `uppercased()`).
struct Eyebrow: View {
    enum Style {
        /// SF semibold: the default.
        case system
        /// Sora: on the display-type screens (Learn, song sheets, onboarding, celebrations).
        case display
    }

    /// Where the eyebrow stands, which decides whether it is in capitals.
    enum Level {
        /// Over a group of cards or a list's section: small tracked capitals.
        case section
        /// Inside a card or over a figure: sentence case, no tracking.
        case label
    }

    let text: Text
    var color: Color = Palette.mint
    var style: Style = .system
    var level: Level = .label
    @Environment(\.legibilityWeight) private var legibility

    init(_ text: LocalizedStringKey, color: Color = Palette.mint, style: Style = .system, level: Level = .label) {
        self.init(Text(text), color: color, style: style, level: level)
    }

    init(_ text: Text, color: Color = Palette.mint, style: Style = .system, level: Level = .label) {
        self.text = text
        self.color = color
        self.style = style
        self.level = level
    }

    var body: some View {
        let _ = legibility
        switch level {
        case .section:
            text.font(style == .display ? Typeface.eyebrowDisplay : Typeface.eyebrow)
                .tracking(style == .display ? 1.4 : 1.8)
                .textCase(.uppercase)
                .foregroundStyle(color)
        case .label:
            text.font(style == .display ? Typeface.label(.caption) : Typeface.eyebrow)
                .foregroundStyle(color)
        }
    }
}

/// A screen's title with an optional line under it, read as one heading. `TabHeader` puts the shared controls
/// beside it.
struct ScreenTitle: View {
    let title: Text
    var subtitle: Text?

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
    }

    init(title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    @Environment(\.legibilityWeight) private var legibility

    var body: some View {
        let _ = legibility
        VStack(alignment: .leading, spacing: 4) {
            title.font(Typeface.screenTitle).tracking(-0.6).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                subtitle.font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

/// The outline of a primary or secondary button.
enum ActionShape {
    /// A capsule: every primary action ("Continue", "Start practice", the paywall's purchase).
    case capsule
    /// A rounded rectangle at `Metrics.cornerTile`, for buttons laid out as tiles in a grid.
    case rounded
}

/// The app's one main action: a mint capsule with dark Sora type and a pluck on press. Every primary action is mint,
/// whatever the screen's or the course's colour (a course hue never fills a primary button), and at rest it is flat:
/// a 1 pt highlight along its top edge, no glow (glow means live, `liveGlow`). Disabled, it is a graphite capsule with
/// faint type, so it never looks tappable. One label font for every button (`Typeface.button`): don't override it at
/// the call site.
struct PrimaryButtonStyle: ButtonStyle {
    var shape: ActionShape = .capsule
    /// False draws the secondary look (the earlier `BrassButtonStyle(prominent: false)`); prefer `SecondaryButtonStyle`.
    var prominent = true

    init(shape: ActionShape = .capsule) {
        self.shape = shape
    }

    /// Every primary action is mint: the accent is not drawn.
    @available(*, deprecated, message: "Every primary action is mint: drop `accent:`")
    init(accent: Color, shape: ActionShape = .capsule) {
        self.shape = shape
    }

    /// The earlier `BrassButtonStyle(prominent:)`.
    init(prominent: Bool) {
        self.prominent = prominent
    }

    @available(*, deprecated, message: "Every primary action is mint: drop `accent:`")
    init(prominent: Bool, accent: Color) {
        self.prominent = prominent
    }

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, prominent: prominent, tint: nil, shape: shape)
    }
}

/// The quieter action beside or after a primary one ("Done", "Hear it", "Try again"): graphite with a control
/// outline and ink type, or washed in `tint` with type in it. Same height, shape and font as the primary.
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var shape: ActionShape = .capsule

    init(tint: Color? = nil, shape: ActionShape = .capsule) {
        self.tint = tint
        self.shape = shape
    }

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, prominent: false, tint: tint, shape: shape)
    }
}

/// Earlier name. `BrassButtonStyle()` is `PrimaryButtonStyle()`; `BrassButtonStyle(prominent: false)` is
/// `SecondaryButtonStyle()`.
@available(*, deprecated, message: "Use PrimaryButtonStyle, or SecondaryButtonStyle for prominent: false")
typealias BrassButtonStyle = PrimaryButtonStyle

/// Reads `isEnabled` (a ButtonStyle can't reliably), so a disabled button looks disabled.
private struct ActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    let tint: Color?
    let shape: ActionShape
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.legibilityWeight) private var legibility

    var body: some View {
        let _ = legibility
        let pressed = configuration.isPressed && isEnabled
        return configuration.label
            .font(Typeface.button)
            .foregroundStyle(labelColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .padding(.horizontal, 18)
            .background { face(pressed: pressed) }
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(Motion.quick, value: pressed)
    }

    private var labelColor: Color {
        guard isEnabled else { return Palette.inkFaint }
        if prominent { return Palette.onAccent }
        return tint ?? Palette.ink
    }

    @ViewBuilder private func face(pressed: Bool) -> some View {
        switch shape {
        case .capsule:
            ActionFace(shape: Capsule(), prominent: prominent, enabled: isEnabled, tint: tint, pressed: pressed)
        case .rounded:
            ActionFace(shape: RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous),
                       prominent: prominent, enabled: isEnabled, tint: tint, pressed: pressed)
        }
    }
}

/// A button's face in its shape: flat mint with a highlight on its top edge, disabled graphite, a tinted wash, or
/// quiet graphite.
private struct ActionFace<S: InsettableShape>: View {
    let shape: S
    let prominent: Bool
    let enabled: Bool
    let tint: Color?
    let pressed: Bool

    var body: some View {
        if prominent && enabled {
            shape.fill(pressed ? Palette.mint.mix(with: .black, by: 0.12) : Palette.mint)
                .overlay(shape.strokeBorder(Self.highlight, lineWidth: 1))
        } else if prominent {
            shape.fill(Palette.surface).overlay(shape.strokeBorder(Palette.controlLine, lineWidth: 1))
        } else if let tint {
            shape.fill(tint.opacity(enabled ? 0.12 : 0.05))
                .overlay(shape.strokeBorder(tint.opacity(enabled ? 0.4 : 0.15), lineWidth: 1))
        } else {
            shape.fill(Palette.stageRaised).overlay(shape.strokeBorder(Palette.controlLine, lineWidth: 1))
        }
    }

    /// Light along the top edge, gone by the middle: the one highlight a resting button has.
    private static let highlight = LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .center)
}

/// A chip: graphite with a control outline, or chosen, a pill of light. On iOS 26 the chosen pill is Liquid Glass
/// washed in ink, and inside an `EdgeRail` (which shares its glass namespace) it flows from chip to chip as the
/// choice moves. The pill is 36 pt tall; its hit area is 44 pt. Disabled, it dims to 45%.
struct ChipButtonStyle: ButtonStyle {
    var selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChipBody(configuration: configuration, selected: selected)
    }
}

private struct ChipBody: View {
    let configuration: ButtonStyleConfiguration
    let selected: Bool
    /// The rail's glass namespace, when the chip sits in one.
    @Environment(\.timbreGlassSpace) private var rail
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let id: String? = selected ? "chip.selected" : nil
        return configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(minHeight: 36)
            .foregroundStyle(selected ? Palette.stage : Palette.ink)
            .background {
                if !selected {
                    Capsule().fill(Palette.stageRaised).overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
                }
            }
            .timbreGlass(Palette.ink, isOn: selected, in: Capsule()) { Capsule().fill(Palette.ink) }
            .timbreGlassID(id, in: rail)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
            // The pill stays 36 pt; the finger gets 44.
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
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

// MARK: - Small pieces

/// "PRO" on gold: `Badge(.pro)`.
struct ProBadge: View {
    var body: some View { Badge(.pro) }
}

/// Retired: an SF Symbol in a tinted disc read as a template. It now draws the bare glyph in the box the disc took, so
/// a screen not yet moved to `Glyph` keeps its layout without the disc. Use `Glyph`.
@available(*, deprecated, message: "Use Glyph: a bare glyph in its ink, no disc")
struct IconOrb: View {
    let symbol: String
    var tint: Color = Palette.mint
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .regular))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Large tappable row used across hubs and settings-like lists: its glyph bare in `tint`, the title and a line of
/// detail. At the accessibility sizes the detail wraps freely.
struct FeatureRow<Trailing: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var tint: Color = Palette.mint
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(spacing: 14) {
            Glyph(symbol, size: Glyph.lead, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .contentShape(Rectangle())
    }
}

extension FeatureRow where Trailing == EmptyView {
    init(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, tint: Color = Palette.mint) {
        self.init(symbol: symbol, title: title, detail: detail, tint: tint) { EmptyView() }
    }
}
