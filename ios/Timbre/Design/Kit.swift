import SwiftUI

// Studio Noir's shared parts (DESIGN11, batch A): headers, buttons, segmented pills, tiles, badges, empty and loading
// states, and the Dynamic Type, hit-target and Reduce Motion helpers every screen uses. Tokens live in Theme.swift;
// button styles and `Eyebrow` in Components.swift; streak, level and quest parts in GameUI.swift.

// MARK: - Headers

/// A tab's header: its title (and a line under it), read as one heading, with the shared controls on the trailing
/// side (`HeaderControls`: the streak chip and the level ring, both leading to Progress) or your own.
/// At the accessibility sizes the controls move above the title so it keeps the full width.
struct TabHeader<Trailing: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: Text, subtitle: Text? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: Text(title), subtitle: subtitle.map { Text($0) }, trailing: trailing)
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    trailing
                }
                ScreenTitle(title: title, subtitle: subtitle)
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                ScreenTitle(title: title, subtitle: subtitle)
                trailing
            }
        }
    }
}

extension TabHeader where Trailing == HeaderControls {
    /// With the standard controls. `showsToday` as `StreakChip`'s (false where a Today card sits right below).
    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, showsToday: Bool? = nil) {
        self.init(title: title, subtitle: subtitle) { HeaderControls(showsToday: showsToday) }
    }

    init(title: Text, subtitle: Text? = nil, showsToday: Bool? = nil) {
        self.init(title: title, subtitle: subtitle) { HeaderControls(showsToday: showsToday) }
    }
}

/// The trailing cluster every tab header shares: the streak chip and the level ring (44 pt targets), both opening
/// Progress. Tune puts its settings button after it.
struct HeaderControls: View {
    var showsToday: Bool?
    @EnvironmentObject private var store: AppStore

    init(showsToday: Bool? = nil) {
        self.showsToday = showsToday
    }

    var body: some View {
        HStack(spacing: 2) {
            StreakChip(showsToday: showsToday) { store.selectedTab = .journey }
            LevelRing(size: 36) { store.selectedTab = .journey }
        }
    }
}

/// A section between cards ("Achievements", "Tunings"): Sora 20 on the title3 curve, a heading for VoiceOver's
/// rotor, with an optional trailing control or count on its baseline (under it at the accessibility sizes).
struct SectionHeader<Trailing: View>: View {
    private let title: Text
    private let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: Text, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.init(Text(title), trailing: trailing)
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            title.font(Typeface.sectionTitle).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }

    init(_ title: Text) {
        self.init(title) { EmptyView() }
    }
}

/// A title inside a card ("Today", "Coach", a game's name): Sora 17 on the headline curve, a heading for VoiceOver.
struct CardTitle: View {
    private let title: Text

    init(_ title: LocalizedStringKey) { self.title = Text(title) }
    init(_ title: Text) { self.title = title }

    var body: some View {
        title.font(Typeface.cardTitle).foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Icon buttons

/// A round glyph button. The disc is 34 pt (`.compact`: bars, sheet corners) or 44 pt (`.regular`: stage controls,
/// a header's search); the hit area is always at least 44 × 44 pt, with no negative padding, so neighbours never
/// overlap. Give it a `label` (or an `.accessibilityLabel`): VoiceOver has no words otherwise. `glass` draws the
/// disc in Liquid Glass on iOS 26 (only where nothing under it redraws every frame).
struct IconButton: View {
    enum Size {
        case compact
        case regular

        var face: CGFloat { self == .compact ? 34 : 44 }
        var glyph: CGFloat { self == .compact ? 14 : 17 }
        var weight: Font.Weight { self == .compact ? .bold : .semibold }
    }

    private let symbol: String
    private let size: Size
    private let tint: Color
    private let label: Text?
    private let glass: Bool
    private let action: () -> Void

    init(symbol: String, size: Size = .regular, tint: Color = Palette.ink, label: LocalizedStringKey? = nil,
         glass: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.size = size
        self.tint = tint
        self.label = label.map { Text($0) }
        self.glass = glass
        self.action = action
    }

    var body: some View {
        Button(action: action) { face }
            .buttonStyle(PressScaleStyle())
            .modifier(SpokenLabel(label: label))
    }

    private var face: some View {
        Image(systemName: symbol)
            .font(.system(size: size.glyph, weight: size.weight))
            .foregroundStyle(tint)
            .frame(width: size.face, height: size.face)
            .background { if !glass { Circle().fill(Palette.surface) } }
            .overlay { if !glass { Circle().strokeBorder(Palette.hairline, lineWidth: 1) } }
            .timbreGlass(interactive: true, isOn: glass, in: Circle()) { Circle().fill(Palette.surface) }
            .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
    }
}

/// The one close button: a 34 pt graphite disc with a hairline and a bold ink ✕, in a 44 pt target.
/// Add the screen's `.accessibilityIdentifier` to it as before.
struct CloseButton: View {
    private let label: LocalizedStringKey
    private let glass: Bool
    private let action: () -> Void

    init(label: LocalizedStringKey = "Close", glass: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.glass = glass
        self.action = action
    }

    var body: some View {
        IconButton(symbol: "xmark", size: .compact, label: label, glass: glass, action: action)
    }
}

/// `CloseButton`'s twin with a back chevron (it mirrors in right-to-left languages), for going up a level inside
/// a flow (a lesson's part back to its song sheet). Pass a label that says where it goes when you can.
struct BackButton: View {
    private let label: LocalizedStringKey
    private let glass: Bool
    private let action: () -> Void

    init(label: LocalizedStringKey = "Back", glass: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.glass = glass
        self.action = action
    }

    var body: some View {
        IconButton(symbol: "chevron.backward", size: .compact, label: label, glass: glass, action: action)
    }
}

// MARK: - Segmented pill

/// Two to four choices in one capsule track; the chosen one is the chips' pill of light (ink, dark type), and it
/// slides to the next choice (Liquid Glass flowing on iOS 26; a matched pill before; a short fade under Reduce
/// Motion). Each segment is 40 pt tall in a 44 pt track. Labels default to the chips' type; set a font inside
/// `label` to change it (Sora digits for minutes, say). `identifier` names each segment for UI tests.
///
///     SegmentedPill(options: [5, 10, 15], selection: $minutes, identifier: { "onboarding.minutes.\($0)" }) { value in
///         Text(Duration.seconds(value * 60), format: .units(allowed: [.minutes], width: .abbreviated))
///     }
struct SegmentedPill<Value: Hashable, Label: View>: View {
    private let options: [Value]
    @Binding private var selection: Value
    private let tint: Color
    private let identifier: ((Value) -> String)?
    private let content: (Value) -> Label
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(options: [Value], selection: Binding<Value>, tint: Color = Palette.ink,
         identifier: ((Value) -> String)? = nil, @ViewBuilder label: @escaping (Value) -> Label) {
        self.options = options
        self._selection = selection
        self.tint = tint
        self.identifier = identifier
        self.content = label
    }

    var body: some View {
        TimbreGlassGroup(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { value in
                    segment(value)
                }
            }
            .padding(2)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
        }
        .accessibilityElement(children: .contain)
    }

    private func segment(_ value: Value) -> some View {
        let selected = value == selection
        let glassID: String? = selected ? "segment.selected" : nil
        return Button {
            guard value != selection else { return }
            withMotion(Motion.morph, reduceMotion: reduceMotion) { selection = value }
            Haptics.shared.selection()
        } label: {
            content(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(selected ? selectedInk : Palette.inkSoft)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40)
                .timbreGlass(tint, isOn: selected, in: Capsule()) {
                    Capsule().fill(tint).matchedGeometryEffect(id: "segment.pill", in: pill)
                }
                .timbreGlassID(glassID, in: pill)
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .modifier(OptionalIdentifier(id: identifier?(value)))
    }

    /// Dark type on the pill: the stage on ink (as chips), the accent ink on any other colour.
    private var selectedInk: Color { tint == Palette.ink ? Palette.stage : Palette.onAccent }
}

// MARK: - Stat tiles

private struct StatTileFillsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by `StatTileRow`: its tiles stretch to the tallest one.
    fileprivate var statTileFills: Bool {
        get { self[StatTileFillsKey.self] }
        set { self[StatTileFillsKey.self] = newValue }
    }
}

/// One figure in a tile: a tinted symbol, the value in Sora digits and what it counts ("12 · day streak").
/// At the accessibility sizes it turns into a full-width row (symbol, then value over label), so nothing truncates.
/// Put tiles side by side in a `StatTileRow`, which stacks them at those sizes and evens their heights.
struct StatTile: View {
    private let symbol: String
    private let tint: Color
    private let value: Text
    private let label: Text
    private let alignment: HorizontalAlignment
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.statTileFills) private var fills

    init(symbol: String, tint: Color = Palette.mint, value: Text, label: Text, alignment: HorizontalAlignment = .leading) {
        self.symbol = symbol
        self.tint = tint
        self.value = value
        self.label = label
        self.alignment = alignment
    }

    init(symbol: String, tint: Color = Palette.mint, value: Text, label: LocalizedStringKey, alignment: HorizontalAlignment = .leading) {
        self.init(symbol: symbol, tint: tint, value: value, label: Text(label), alignment: alignment)
    }

    var body: some View {
        content
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var content: some View {
        if typeSize.isAccessibilitySize {
            HStack(alignment: .center, spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    figure
                    caption.fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: alignment, spacing: 4) {
                icon
                figure
                caption
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: fills ? CGFloat.infinity : nil, alignment: Alignment(horizontal: alignment, vertical: .top))
        }
    }

    private var icon: some View {
        Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var figure: some View {
        value.font(Typeface.number(22, relativeTo: .title2)).foregroundStyle(Palette.ink)
            .lineLimit(1).minimumScaleFactor(0.7)
            .contentTransition(.numericText())
    }

    private var caption: some View {
        label.font(.caption).foregroundStyle(Palette.inkSoft)
    }
}

/// Stat tiles side by side with equal heights; stacked one per row at the accessibility sizes.
struct StatTileRow<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: spacing) { content }
        } else {
            HStack(alignment: .top, spacing: spacing) { content }
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.statTileFills, true)
        }
    }
}

// MARK: - Badges

/// Small capitals in a capsule: "PRO", "NEW", a plan's "SAVE 58%". Sora 10 on the caption2 curve, grows with
/// Dynamic Type up to xxxLarge and is never scaled down with `scaleEffect`. Write the text in sentence case; the
/// badge capitalises it.
struct Badge: View {
    enum Style {
        /// Dark type on Timbre Pro gold.
        case pro
        /// Washed in the colour, the type in it.
        case accent(Color)
        /// Solid colour, dark type.
        case solid(Color)
    }

    /// Ready-made badges.
    enum Preset {
        /// "PRO" on gold, read "Timbre Pro".
        case pro
    }

    private let text: Text
    private let style: Style
    private let spoken: Text?

    init(_ text: LocalizedStringKey, style: Style = .accent(Palette.mint)) {
        self.text = Text(text)
        self.style = style
        self.spoken = nil
    }

    init(_ text: Text, style: Style = .accent(Palette.mint)) {
        self.text = text
        self.style = style
        self.spoken = nil
    }

    init(_ preset: Preset) {
        switch preset {
        case .pro:
            text = Text("PRO")
            style = .pro
            spoken = Text("Timbre Pro")
        }
    }

    var body: some View {
        text.font(Typeface.badge).tracking(1.2)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(ink)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(wash))
            .overlay(Capsule().strokeBorder(rim, lineWidth: 1))
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .modifier(SpokenLabel(label: spoken))
    }

    private var ink: Color {
        switch style {
        case .pro: return Palette.onGold
        case .accent(let color): return color
        case .solid: return Palette.onAccent
        }
    }

    private var wash: AnyShapeStyle {
        switch style {
        case .pro: return AnyShapeStyle(Palette.proGold)
        case .accent(let color): return AnyShapeStyle(color.opacity(0.16))
        case .solid(let color): return AnyShapeStyle(color)
        }
    }

    private var rim: Color {
        switch style {
        case .accent(let color): return color.opacity(0.35)
        case .pro, .solid: return .clear
        }
    }
}

// MARK: - Empty and loading

/// Nothing to show yet, or nothing matches: a quiet orb, a title and a line of help, centred, with optional actions
/// under them. For a search with no results prefer `ContentUnavailableView.search(text:)`.
struct EmptyState<Actions: View>: View {
    private let symbol: String
    private let title: Text
    private let message: Text?
    private let actions: Actions

    init(symbol: String, title: Text, message: Text? = nil, @ViewBuilder actions: () -> Actions) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions()
    }

    init(symbol: String, title: LocalizedStringKey, message: LocalizedStringKey? = nil, @ViewBuilder actions: () -> Actions) {
        self.init(symbol: symbol, title: Text(title), message: message.map { Text($0) }, actions: actions)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                IconOrb(symbol: symbol, tint: Palette.inkSoft, size: 52)
                title.font(Typeface.cardTitle).foregroundStyle(Palette.ink)
                if let message {
                    message.font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, Metrics.proseInset)
    }
}

extension EmptyState where Actions == EmptyView {
    init(symbol: String, title: LocalizedStringKey, message: LocalizedStringKey? = nil) {
        self.init(symbol: symbol, title: title, message: message) { EmptyView() }
    }

    init(symbol: String, title: Text, message: Text? = nil) {
        self.init(symbol: symbol, title: title, message: message) { EmptyView() }
    }
}

/// Loading: the system spinner in mint, with an optional line under it. Use it instead of a grey skeleton.
struct StageSpinner: View {
    private let label: Text?
    private let tint: Color

    init(_ label: LocalizedStringKey? = nil, tint: Color = Palette.mint) {
        self.label = label.map { Text($0) }
        self.tint = tint
    }

    var body: some View {
        VStack(spacing: 10) {
            ProgressView().progressViewStyle(.circular).controlSize(.regular).tint(tint)
            if let label {
                label.font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Lines and counters

/// A divider between rows or sections in `Palette.line` (brighter with Increase Contrast). `leading` insets it to
/// line up with the rows' titles. Card borders are `Palette.hairline`, drawn by `stillCard`.
struct Hairline: View {
    var leading: CGFloat = 0
    var vertical = false

    var body: some View {
        Rectangle().fill(Palette.line)
            .frame(width: vertical ? CGFloat(1) : nil, height: vertical ? nil : CGFloat(1))
            .padding(.leading, leading)
            .accessibilityHidden(true)
    }
}

extension Text {
    /// A compact counter, "3 / 10" (thin spaces, the numbers in the reader's locale); VoiceOver reads "3 of 10".
    /// Every compact count uses it; running prose keeps "of".
    static func fraction(_ done: Int, _ total: Int) -> Text {
        (Text("\(done)") + Text(verbatim: "\u{2009}/\u{2009}") + Text("\(total)"))
            .accessibilityLabel(Text("\(done) of \(total)"))
    }
}

// MARK: - Dynamic Type, hit targets, Reduce Motion

extension View {
    /// Clamp policy for a hero numeral (`Typeface.hero` or a large `Typeface.number`): one line, shrinking to fit its
    /// ring or row rather than clipping, and no growth past `cap` (VoiceOver and the Large Content Viewer still
    /// have the value).
    func heroNumeral(cap: DynamicTypeSize = .accessibility1, minimumScale: CGFloat = 0.5) -> some View {
        lineLimit(1).minimumScaleFactor(minimumScale).dynamicTypeSize(...cap)
    }

    /// At least `size` (44 pt) to tap without changing how the view looks: text links, small glyph buttons.
    func tapTarget(_ size: CGFloat = Metrics.minTarget) -> some View {
        frame(minWidth: size, minHeight: size).contentShape(Rectangle())
    }

    /// `.animation(animation, value:)`, with `Motion.reduced` under Reduce Motion.
    func adaptiveAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AdaptiveAnimation(animation: animation, value: value))
    }
}

/// `withAnimation(animation)`, or `withAnimation(Motion.reduced)` under Reduce Motion.
@MainActor @discardableResult
func withMotion<Result>(_ animation: Animation, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.adaptive(animation, reduceMotion: reduceMotion), body)
}

extension AnyTransition {
    /// `transition`, or a plain fade under Reduce Motion.
    static func adaptive(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }
}

private struct AdaptiveAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Motion.adaptive(animation, reduceMotion: reduceMotion), value: value)
    }
}

/// An accessibility label when there is one.
private struct SpokenLabel: ViewModifier {
    let label: Text?

    @ViewBuilder func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

/// An accessibility identifier when there is one.
private struct OptionalIdentifier: ViewModifier {
    let id: String?

    @ViewBuilder func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
