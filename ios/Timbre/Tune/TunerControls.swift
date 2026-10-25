import SwiftUI

/// Under the tuner's stage: how it picks its target (AUTO | MANUAL) and the reference tone, side by side on glass.
/// When a language's words don't fit, the reference button keeps only its tuning fork (VoiceOver still names it).
/// The words grow with Dynamic Type up to the first accessibility size (the compact face takes over when they no
/// longer fit); beyond it, a long press on any control shows it large (Large Content Viewer).
struct TunerStageBar: View {
    let automatic: Bool
    /// Chromatic: the modes follow or hold a note rather than a string.
    let chromatic: Bool
    let listening: Bool
    let tonePlaying: Bool
    let setAutomatic: (Bool) -> Void
    let toggleTone: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(compact: false)
            bar(compact: true)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// iOS 26: both pieces of Liquid Glass in one container (Design/Glass.swift), sampling one backdrop in one pass;
    /// earlier systems draw each on its own material (`glassCapsule`).
    private func bar(compact: Bool) -> some View {
        TimbreGlassGroup(spacing: 10) {
            HStack(spacing: 10) {
                DetectionPill(automatic: automatic, chromatic: chromatic, listening: listening, choose: setAutomatic)
                ReferenceToneButton(playing: tonePlaying, compact: compact, action: toggleTone)
            }
        }
        .fixedSize()
    }
}

/// AUTO | MANUAL: whether the tuner follows the string (or note) it hears, or stays on the one chosen. One capsule of
/// glass with a mint thumb that slides to the mode in use; in Auto, while listening, a light beside the word pulses.
struct DetectionPill: View {
    let automatic: Bool
    var chromatic = false
    var listening = false
    let choose: (Bool) -> Void
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 2) {
            segment(auto: true)
            segment(auto: false)
        }
        .padding(3)
        .glassCapsule(interactive: false)
        .animation(reduceMotion ? nil : Motion.pluck, value: automatic)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tune.detection")
    }

    private func segment(auto: Bool) -> some View {
        let selected = auto == automatic
        let idle: Color = contrast == .increased ? Palette.ink : Palette.inkSoft
        return Button {
            guard !selected else { return }
            Haptics.shared.selection()
            choose(auto)
        } label: {
            HStack(spacing: 6) {
                if auto { light(on: selected) }
                (auto ? Text("Auto") : Text("Manual"))
                    .font(Typeface.label(12, relativeTo: .caption))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(selected ? Palette.mint : idle)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background { if selected { thumbShape } }
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(auto ? Text("Automatic") : Text("Manual"))
        .cappedControl(auto ? Text("Automatic") : Text("Manual"), symbol: auto ? "dot.radiowaves.left.and.right" : "hand.point.up.left")
        .accessibilityHint(hint(auto: auto))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(auto ? "tune.auto" : "tune.manual")
    }

    private var thumbShape: some View {
        Capsule()
            .fill(Palette.mint.opacity(0.16))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(contrast == .increased ? 0.9 : 0.5), lineWidth: 1))
            .matchedGeometryEffect(id: "thumb", in: thumb)
    }

    /// Auto's light: lit and pulsing while it follows what it hears, dim while it waits, hidden in Manual.
    private func light(on selected: Bool) -> some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 6, weight: .bold))
            .symbolEffect(.pulse, options: .repeating, isActive: selected && listening && !reduceMotion)
            .opacity(selected ? (listening ? 1 : 0.45) : 0)
            .accessibilityHidden(true)
    }

    private func hint(auto: Bool) -> Text {
        if auto { return chromatic ? Text("Follows the note you play") : Text("Follows the string you play") }
        return chromatic ? Text("Holds the note. Tap the wheel for another") : Text("Tap a string to tune it")
    }
}

/// The reference tone: the target note, played until tapped again. Labelled "Reference" (just the tuning fork when
/// space is short); mint, its speaker sounding, while it plays.
struct ReferenceToneButton: View {
    let playing: Bool
    var compact = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                icon
                if !compact {
                    Text("Reference")
                        .font(Typeface.label(12, relativeTo: .caption))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(playing ? Palette.mint : Palette.ink)
            .padding(.horizontal, compact ? 0 : 16)
            .frame(minWidth: 44, minHeight: 44)
            .background { if playing { Capsule().fill(Palette.mint.opacity(0.14)) } }
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(playing ? (contrast == .increased ? 0.9 : 0.5) : 0), lineWidth: 1))
            .glassCapsule()
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .animation(Motion.quick, value: playing)
        .accessibilityLabel(playing ? Text("Stop reference tone") : Text("Play reference tone"))
        .cappedControl(playing ? Text("Stop reference tone") : Text("Play reference tone"),
                       symbol: playing ? "speaker.wave.2.fill" : "tuningfork")
        .accessibilityIdentifier("tune.tone")
    }

    private var icon: some View {
        Image(systemName: playing ? "speaker.wave.2.fill" : "tuningfork")
            .font(.system(size: 14, weight: .semibold))
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: playing && !reduceMotion)
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }
}
