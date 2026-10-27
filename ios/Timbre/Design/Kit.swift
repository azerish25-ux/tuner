import Combine
import SwiftUI

// Studio Noir's shared parts: headers, icon buttons, segmented pills, stat tiles and the stat bar, badges, empty and
// loading states, and the helpers every screen uses for Dynamic Type, Bold Text, Button Shapes, the Large Content
// Viewer, hit targets, Reduce Motion, live glow and decoration that rests off screen. Tokens live in Theme.swift;
// button styles and `Eyebrow` in Components.swift; glyphs in Glyphs.swift; streak, level and quest parts in GameUI.swift.
//
// Selector budget: at most two rows of chips or segmented controls above a screen's content. A third choice goes in a
// menu ("View", a toolbar menu) or under the content.

// MARK: - Headers

/// A tab's header: its title (and a line under it), read as one heading, with the shared controls on the trailing
/// side (`HeaderControls`: the streak chip and the level ring, both leading to Progress, none in Calm mode) or your own.
/// At the accessibility sizes the controls move above the title so it keeps the full width.
struct TabHeader<Trailing: View>: View {
    private let title: Text
    private let subtitle: Text?
    private let identity: String
    private let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: Text, subtitle: Text? = nil, identity: String = "screen.header", @ViewBuilder trailing: () -> Trailing) {
        self.identity = identity
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, identity: String = "screen.header", @ViewBuilder trailing: () -> Trailing) {
        self.init(title: Text(title), subtitle: subtitle.map { Text($0) }, identity: identity, trailing: trailing)
    }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    trailing
                }
                ScreenTitle(title: title, subtitle: subtitle, identity: identity)
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                ScreenTitle(title: title, subtitle: subtitle, identity: identity)
                trailing
            }
        }
    }
}

extension TabHeader where Trailing == HeaderControls {
    /// With the standard controls. `showsToday` as `StreakChip`'s (false where a Today card sits right below).
    init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, showsToday: Bool? = nil, identity: String = "screen.header") {
        self.init(title: title, subtitle: subtitle, identity: identity) { HeaderControls(showsToday: showsToday, identity: identity) }
    }

    init(title: Text, subtitle: Text? = nil, showsToday: Bool? = nil, identity: String = "screen.header") {
        self.init(title: title, subtitle: subtitle, identity: identity) { HeaderControls(showsToday: showsToday, identity: identity) }
    }
}

/// The trailing cluster every tab header shares: the streak chip and the level ring (44 pt targets), both opening
/// Progress. Tune puts its settings button after it. Calm mode (`UserSettings.calmMode`) shows neither: the header is
/// its title alone.
struct HeaderControls: View {
    var showsToday: Bool?
    var identity: String
    @EnvironmentObject private var store: AppStore

    init(showsToday: Bool? = nil, identity: String = "screen.header") {
        self.showsToday = showsToday
        self.identity = identity
    }

    var body: some View {
        if !store.settings.calmMode {
            HStack(spacing: 2) {
                StreakChip(showsToday: showsToday, identity: identity + ".streak") { store.selectedTab = .journey }
                LevelRing(size: 36, identity: identity + ".level") { store.selectedTab = .journey }
            }
            .transition(.opacity)
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

    @Environment(\.legibilityWeight) private var legibility

    var body: some View {
        let _ = legibility
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

    @Environment(\.legibilityWeight) private var legibility

    init(_ title: LocalizedStringKey) { self.title = Text(title) }
    init(_ title: Text) { self.title = title }

    var body: some View {
        let _ = legibility
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
/// `label` to change it (Sora digits for minutes, say). `identifier` names each segment for automation.
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
    private let icon: AnyView
    private let value: Text
    private let label: Text
    private let alignment: HorizontalAlignment
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.statTileFills) private var fills

    init(symbol: String, tint: Color = Palette.mint, value: Text, label: Text, alignment: HorizontalAlignment = .leading) {
        self.init(value: value, label: label, alignment: alignment) {
            Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
        }
    }

    /// With its own mark in place of a symbol (the level's ring).
    init<Icon: View>(value: Text, label: Text, alignment: HorizontalAlignment = .leading, @ViewBuilder icon: () -> Icon) {
        self.icon = AnyView(icon())
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
                mark
                VStack(alignment: .leading, spacing: 2) {
                    figure
                    caption.fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: alignment, spacing: 4) {
                mark
                figure
                caption
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: fills ? CGFloat.infinity : nil, alignment: Alignment(horizontal: alignment, vertical: .top))
        }
    }

    private var mark: some View {
        icon.accessibilityHidden(true)
    }

    private var figure: some View {
        value.font(Typeface.number(.title3)).foregroundStyle(Palette.ink)
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

// MARK: - Stat bar

/// Figures side by side in one card, for a wide screen: each figure's glyph, value and label in a row, centred in its
/// share and parted by hairlines. Where a phone stacks `StatTile`s, an iPad has one summary bar rather than tiles
/// stretched across its width with their content huddled in a corner. At the accessibility sizes the figures stack, one
/// per row.
struct StatBar: View {
    struct Figure: Identifiable {
        let id: String
        let icon: AnyView
        let value: Text
        let label: Text
        /// What VoiceOver reads for the figure, when its value and label alone don't say it ("Level 5, Strummer").
        let spoken: Text?

        init(id: String, symbol: String, tint: Color, value: Text, label: Text, spoken: Text? = nil) {
            self.init(id: id, value: value, label: label, spoken: spoken) { Glyph(symbol, size: Glyph.lead, tint: tint) }
        }

        init<Icon: View>(id: String, value: Text, label: Text, spoken: Text? = nil, @ViewBuilder icon: () -> Icon) {
            self.id = id
            self.icon = AnyView(icon())
            self.value = value
            self.label = label
            self.spoken = spoken
        }
    }

    private let figures: [Figure]
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ figures: [Figure]) {
        self.figures = figures
    }

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 0))
        layout {
            ForEach(Array(figures.enumerated()), id: \.element.id) { index, figure in
                if index > 0 && !stacked {
                    Hairline(vertical: true).frame(height: 40)
                }
                cell(figure, stacked: stacked)
            }
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }

    private func cell(_ figure: Figure, stacked: Bool) -> some View {
        HStack(spacing: 12) {
            figure.icon.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                figure.value.font(Typeface.number(.title3)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                figure.label.font(.caption).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: stacked ? .leading : .center)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .modifier(SpokenLabel(label: figure.spoken))
    }
}

// MARK: - Badges

/// Small capitals in a capsule: "PRO", "NEW", a plan's "SAVE 58%". Sora 12 (the scale's smallest step) on the
/// caption2 curve, grows with Dynamic Type up to xxxLarge and is never scaled down with `scaleEffect`. Write the text in
/// sentence case; the badge capitalises it. Use one where a word must stand out; a locked card says so with a lock
/// glyph in its corner rather than a badge.
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
    @Environment(\.legibilityWeight) private var legibility

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
        let _ = legibility
        return text.font(Typeface.badge).tracking(1)
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

/// Nothing to show yet, or nothing matches: a quiet glyph, a title and a line of help, centred, with optional actions
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
                Glyph(symbol, size: Glyph.feature, tint: Palette.inkFaint)
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
    static func fraction(_ done: Int, _ total: Int) -> some View {
        // The counter owns its numeric direction; the surrounding row and the digits keep the reader's locale.
        Text("\(done)\u{2009}/\u{2009}\(total)")
            .environment(\.layoutDirection, .leftToRight)
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

// MARK: - Bold Text, Button Shapes, the Large Content Viewer, live glow, resting decoration

extension View {
    /// At the root of each window (RootView, a cover outside it): keeps `Typeface.boldText` in step with Bold Text, so
    /// every Sora face is drawn a weight heavier while it is on.
    func boldTextAware() -> some View { modifier(BoldTextBridge()) }

    /// A control that stops growing at `cap` to keep its place on a busy stage (the tuner's side controls, a HUD, a
    /// dock) offers the Large Content Viewer instead: a long press shows `label` and `symbol` magnified, as the tab bar
    /// does. Give every capped control one.
    func cappedControl(_ label: Text, symbol: String? = nil, cap: DynamicTypeSize = .accessibility1) -> some View {
        dynamicTypeSize(...cap)
            .accessibilityShowsLargeContentViewer {
                Label {
                    label
                } icon: {
                    if let symbol { Image(systemName: symbol) }
                }
            }
    }

    /// Glow means live: `color` shines under the view while `on` (listening, locked, playing) and nothing at rest. A
    /// button, a card or a disc at rest never glows.
    func liveGlow(_ on: Bool, color: Color = Palette.mint, radius: CGFloat = 16) -> some View {
        shadow(color: color.opacity(on ? 0.5 : 0), radius: on ? radius : 0)
    }

    /// For decoration that moves on its own (motes, a flame, an idle picture): `live` is true only while the view is on
    /// screen (appeared, and inside its scroll view's visible bounds), the app is in front and Low Power Mode is off.
    /// Drive a `TimelineView(.animation(paused: !live))` with it, so nothing redraws at rest.
    func animatesWhileSeen(_ live: Binding<Bool>) -> some View {
        modifier(WhileSeen(live: live))
    }
}

/// A text button in its colour ("Show all", "I just restrung", a link): with Button Shapes on (Settings ›
/// Accessibility › Display & Text Size) it is underlined, as the system's text buttons are, so it reads as a button
/// by more than its colour. It dims under the finger, and its target is at least 44 pt tall.
struct TextLinkStyle: ButtonStyle {
    var tint: Color = Palette.mint

    func makeBody(configuration: Configuration) -> some View {
        TextLinkBody(configuration: configuration, tint: tint)
    }
}

private struct TextLinkBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    @Environment(\.accessibilityShowButtonShapes) private var buttonShapes

    var body: some View {
        configuration.label
            .foregroundStyle(tint)
            .underline(buttonShapes, color: tint)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
    }
}

/// Sets `Typeface.boldText` from the environment before the views under it draw.
private struct BoldTextBridge: ViewModifier {
    @Environment(\.legibilityWeight) private var legibility

    func body(content: Content) -> some View {
        let bold = legibility == .bold
        if Typeface.boldText != bold { Typeface.boldText = bold }
        return content
    }
}

private struct WhileSeen: ViewModifier {
    @Binding var live: Bool
    @State private var shown = false
    @State private var inView = true
    @State private var lowPower = WhileSeen.lowPowerNow
    @Environment(\.scenePhase) private var scenePhase

    /// Low Power Mode is on (or the run asked for a resting stage, `TestSupport.stageResting`).
    nonisolated private static var lowPowerNow: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled || TestSupport.stageResting }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                guard let viewport = proxy.bounds(of: .scrollView) else { return true }
                return viewport.intersects(CGRect(origin: .zero, size: proxy.size))
            } action: { value in
                inView = value
                update()
            }
            .onAppear {
                shown = true
                update()
            }
            .onDisappear {
                shown = false
                update()
            }
            .onChange(of: scenePhase) { _, _ in update() }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: DispatchQueue.main)) { _ in
                lowPower = WhileSeen.lowPowerNow
                update()
            }
    }

    private func update() {
        let next = shown && inView && scenePhase == .active && !lowPower
        if live != next { live = next }
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
struct OptionalIdentifier: ViewModifier {
    let id: String?

    @ViewBuilder func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
