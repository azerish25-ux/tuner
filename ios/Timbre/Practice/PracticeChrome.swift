import SwiftUI

// Scroll chrome shared by the practice tools, the instrument screens and the Play and Progress tabs:
// edge-to-edge chip rails, a soft shade where content slides under the status bar, a dock for pinned
// controls, and a hero that sizes itself so a screen's controls end above that dock.

/// A horizontal rail of chips or cards that runs past its container's padding to the edge, so items
/// scroll under the edge instead of being cut at the padding. `bleed` is that padding (the screen gutter,
/// or a card's inset); the first item still lines up with the content around the rail. An edge fades
/// while more is hidden past it (measured from the chips themselves, so a rail resting at either end is
/// solid there), and the selected item glides to the middle when the rail appears and whenever the
/// selection changes, clear of both fades (at either end it simply rests against the margin).
/// Give each item `.id(value)` with the same type as `selection`.
struct EdgeRail<ID: Hashable, Content: View>: View {
    var bleed: CGFloat = Metrics.gutter
    var spacing: CGFloat = 8
    var selection: ID?
    @ViewBuilder var content: Content

    @State private var position: ID?
    @State private var revealed = false
    @State private var overflow = EdgeOverflow()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) { content }
                .scrollTargetLayout()
                .onGeometryChange(for: EdgeOverflow.self) { proxy in
                    EdgeOverflow(content: proxy)
                } action: { value in
                    overflow = value
                }
        }
        .scrollPosition(id: $position, anchor: .center)
        .modifier(RailBleed(leading: bleed, trailing: bleed, measured: overflow))
        .onAppear(perform: reveal)
        .onChange(of: selection) { _, value in
            guard let value else { return }
            withAnimation(Motion.settle) { position = value }
        }
    }

    private func reveal() {
        guard !revealed else { return }
        revealed = true
        position = selection
    }
}

extension View {
    /// For a horizontal ScrollView: extends it `leading`/`trailing` points past its container with matching
    /// content margins, so content rests aligned but scrolls on to the edge, and fades an edge while
    /// content is hidden past it.
    func railBleed(leading: CGFloat, trailing: CGFloat) -> some View {
        modifier(RailBleed(leading: leading, trailing: trailing))
    }

    /// Shades the status bar (and bar) area once a vertical ScrollView's content scrolls beneath it.
    /// Apply directly to the ScrollView.
    func stageTopShade() -> some View { modifier(StageTopShade()) }

    /// Pins controls to the bottom on a stage-coloured dock with a short fade above it. The scroll
    /// content is inset by the dock, so nothing ends up hidden beneath it.
    func stageDock<Dock: View>(@ViewBuilder _ dock: () -> Dock) -> some View {
        let bar = dock()
        return safeAreaInset(edge: .bottom, spacing: 0) {
            bar
                .padding(.horizontal, Metrics.gutter).padding(.top, 8).padding(.bottom, 6)
                .background { StageDockBackdrop() }
        }
    }

    /// VoiceOver: one adjustable element for a value that buttons (or a stepper) change a step at a time, so a
    /// swipe up or down moves it and VoiceOver reads back `value`. The view's own children are replaced by it.
    func adjustableValue(_ label: Text, value: Text, increment: @escaping () -> Void, decrement: @escaping () -> Void) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: increment()
                case .decrement: decrement()
                @unknown default: break
                }
            }
    }

    /// For a vertical ScrollView whose content opens with a hero graphic `height` points tall: shrinks or
    /// grows the hero within `range` so the rest of the content ends above the dock (or tab bar) on the
    /// screen it is on, instead of the last controls resting half under it. Content that can't fit even
    /// with the smallest hero (large text sizes) simply scrolls.
    func fitsHero(_ height: Binding<CGFloat>, in range: ClosedRange<CGFloat>) -> some View {
        modifier(HeroFit(height: height, range: range))
    }
}

/// Visible height of a scroll view and the height of its content.
private struct HeroRoom: Equatable {
    var visible: CGFloat
    var content: CGFloat
}

private struct HeroFit: ViewModifier {
    @Binding var height: CGFloat
    let range: ClosedRange<CGFloat>
    /// The first fit lands before anything is seen; later ones (a section opening) ease.
    @State private var measured = false

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: HeroRoom.self) { geometry in
            HeroRoom(visible: geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom,
                     content: geometry.contentSize.height)
        } action: { _, room in
            // Everything but the hero keeps its height, so one step lands on the fit.
            let rest = room.content - height
            let fit = min(range.upperBound, max(range.lowerBound, (room.visible - rest).rounded(.down)))
            guard abs(fit - height) > 1 else { measured = true; return }
            if measured { withAnimation(Motion.settle) { height = fit } } else { height = fit }
            measured = true
        }
    }
}

/// Bleeds a horizontal ScrollView past its container and fades each end (the shared `EdgeFadeMask`) over a
/// little more than its bleed while content hides past it, so a chip running past the edge dissolves
/// instead of reading as cut mid-word. `measured` is the overflow read from the row's own content when the
/// caller has it (`EdgeRail`); otherwise it is read from the scroll geometry.
private struct RailBleed: ViewModifier {
    let leading: CGFloat
    let trailing: CGFloat
    var measured: EdgeOverflow?
    @State private var scrolled = EdgeOverflow()

    func body(content: Content) -> some View {
        let overflow = measured ?? scrolled
        return content
            .contentMargins(.leading, leading, for: .scrollContent)
            .contentMargins(.trailing, trailing, for: .scrollContent)
            .onScrollGeometryChange(for: EdgeOverflow.self) { geometry in
                EdgeOverflow(geometry)
            } action: { _, value in
                scrolled = value
            }
            .mask {
                EdgeFadeMask(overflow: overflow, leading: EdgeFadeMask.width(bleed: leading), trailing: EdgeFadeMask.width(bleed: trailing))
                    .animation(Motion.quick, value: overflow)
            }
            .padding(.leading, -leading)
            .padding(.trailing, -trailing)
    }
}

private struct StageTopShade: ViewModifier {
    @State private var scrolled = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 2
            } action: { _, value in
                scrolled = value
            }
            .overlay(alignment: .top) {
                // A strip just below the top safe-area edge; its shade reaches up through the status bar (and a
                // navigation or tab bar) by ignoring the safe area, the way bar backgrounds do: solid behind the clock,
                // so no heading ghosts through it, then fading out over the strip.
                Color.clear
                    .frame(height: 18)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        VStack(spacing: 0) {
                            Palette.stage
                            LinearGradient(colors: [Palette.stage, Palette.stage.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 18)
                        }
                        .ignoresSafeArea(edges: .top)
                    }
                    .opacity(scrolled ? 1 : 0)
                    .animation(Motion.quick, value: scrolled)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

private struct StageDockBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
            Palette.stage.opacity(0.96)
        }
        .padding(.top, -24)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
