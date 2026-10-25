import SwiftUI

// Liquid Glass, Studio Noir's way: an accent on what floats or is chosen (a rail's selected chip, a step's bottom bar,
// the paywall's chosen plan and its button, a sheet's close button), never a change of theme. The stage stays dark.
//
// On iOS 26 these are the system's Liquid Glass. Shapes that sit together go in one `TimbreGlassGroup` (a
// `GlassEffectContainer`): they render in one pass, and a shape named with `timbreGlassID` flows from one place to the
// next as the selection moves (a chip to the next chip, Yearly to Monthly) instead of blinking out and in.
// Before iOS 26 every call draws its `fallback`, usually the solid look the control always had, so layouts, contrast
// and hit areas are the same on both.
//
// Glass resamples what lies behind it whenever that changes, so none goes over a Canvas that redraws every frame (the
// paywall's runway, a lesson's highway): there it would cost an extra pass each frame.

extension Motion {
    /// Glass moving from one control to the next: a liquid spring with a soft landing.
    static let morph = Animation.spring(response: 0.42, dampingFraction: 0.8)
}

/// One pass for the glass shapes inside, which blend and morph into one another within `spacing` points.
/// Before iOS 26 it is just its content.
struct TimbreGlassGroup<Content: View>: View {
    var spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private struct TimbreGlassSpaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// The namespace a group of glass shapes shares (an `EdgeRail`'s chips, a lesson's bottom bar), so one shape can
    /// morph into the next. Nil outside such a group.
    var timbreGlassSpace: Namespace.ID? {
        get { self[TimbreGlassSpaceKey.self] }
        set { self[TimbreGlassSpaceKey.self] = newValue }
    }
}

extension View {
    /// Liquid Glass behind the view, in `shape` (iOS 26): washed with `tint` when given, answering the finger when
    /// `interactive`. Off (`isOn` false) it leaves the view as it is, so a control can switch its glass on and off
    /// without changing identity. Before iOS 26, `fallback` is drawn behind the view instead (while on).
    /// Apply it after the view's own background and border: glass goes behind everything the view draws.
    func timbreGlass<S: Shape, Fallback: View>(_ tint: Color? = nil, interactive: Bool = false, isOn: Bool = true, in shape: S,
                                               @ViewBuilder fallback: () -> Fallback) -> some View {
        modifier(TimbreGlassModifier(tint: tint, interactive: interactive, isOn: isOn, shape: shape, fallback: fallback()))
    }

    /// Liquid Glass in `shape`, falling back to `TimbreGlassPlate` (a dark material with a rim of light).
    func timbreGlass<S: InsettableShape>(_ tint: Color? = nil, interactive: Bool = false, isOn: Bool = true, in shape: S) -> some View {
        timbreGlass(tint, interactive: interactive, isOn: isOn, in: shape) { TimbreGlassPlate(shape: shape, tint: tint) }
    }

    /// Names this view's glass within `namespace` (a `TimbreGlassGroup`'s), so when the name moves to another view
    /// the glass flows there. Nil `id` or `namespace` (or before iOS 26): nothing.
    func timbreGlassID<ID: Hashable & Sendable>(_ id: ID?, in namespace: Namespace.ID?) -> some View {
        modifier(TimbreGlassIDModifier(id: id, namespace: namespace))
    }
}

private struct TimbreGlassModifier<S: Shape, Fallback: View>: ViewModifier {
    let tint: Color?
    let interactive: Bool
    let isOn: Bool
    let shape: S
    let fallback: Fallback

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(isOn ? Glass.regular.tint(tint).interactive(interactive) : Glass.identity, in: shape)
        } else {
            content.background {
                if isOn { fallback }
            }
        }
    }
}

private struct TimbreGlassIDModifier<ID: Hashable & Sendable>: ViewModifier {
    let id: ID?
    let namespace: Namespace.ID?

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let namespace {
                content.glassEffectID(id, in: namespace)
            } else {
                content
            }
        } else {
            content
        }
    }
}

/// Glass before iOS 26: a dark material, the tint over it, and a hairline rim lit from above.
struct TimbreGlassPlate<S: InsettableShape>: View {
    let shape: S
    var tint: Color?

    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Palette.stageRaised.opacity(0.55))
            if let tint { shape.fill(tint) }
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                               lineWidth: 0.75)
        }
    }
}

/// The main action as a capsule of mint glass that answers the finger (iOS 26), with dark type; before iOS 26 the flat
/// mint capsule of `PrimaryButtonStyle`. At rest it doesn't glow (glow means live). `collapsed` folds it into a round
/// bead (a purchase in flight, its label a spinner) and back, the glass flowing with it.
/// Disabled, it is dark glass (graphite before iOS 26) with faint type and no glow, like a disabled
/// `PrimaryButtonStyle`; while `collapsed` or `busy` (a purchase in flight, the button disabled meanwhile) it keeps
/// its colour, so the spinner reads as work, not as a dead button.
struct GlassActionButtonStyle: ButtonStyle {
    var tint: Color = Palette.mint
    var collapsed = false
    var busy = false

    func makeBody(configuration: Configuration) -> some View {
        GlassActionBody(configuration: configuration, tint: tint, collapsed: collapsed, busy: busy)
    }
}

/// Reads `isEnabled` (a ButtonStyle can't reliably).
private struct GlassActionBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let collapsed: Bool
    let busy: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let live = isEnabled || collapsed || busy
        return configuration.label
            .font(Typeface.button)
            .foregroundStyle(live ? Palette.onAccent : Palette.inkFaint)
            .frame(minWidth: 54, maxWidth: collapsed ? CGFloat(54) : .infinity, minHeight: Metrics.buttonHeight)
            .padding(.horizontal, collapsed ? 0 : 18)
            .modifier(ActionGlass(tint: tint, live: live, pressed: configuration.isPressed && isEnabled))
            // The bead stays centred where the bar was.
            .frame(maxWidth: .infinity)
            .animation(Motion.morph, value: collapsed)
    }
}

private struct ActionGlass: ViewModifier {
    let tint: Color
    /// False: disabled, so dark and unlit.
    let live: Bool
    let pressed: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(Glass.regular.tint(live ? tint : Palette.surface).interactive(live), in: Capsule())
                .animation(Motion.quick, value: pressed)
        } else {
            content
                .background {
                    if live {
                        Capsule().fill(pressed ? tint.mix(with: .black, by: 0.12) : tint)
                            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                                                           startPoint: .top, endPoint: .center), lineWidth: 1))
                    } else {
                        Capsule().fill(Palette.surface).overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
                    }
                }
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(Motion.quick, value: pressed)
        }
    }
}
