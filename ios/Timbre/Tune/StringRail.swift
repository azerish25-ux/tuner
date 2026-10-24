import SwiftUI
import TimbreCore

/// One chip per course, in physical order. Unison partners (a mandolin's pair) share one chip marked ×2,
/// with a pip per string that lights as that string locks; the chip turns solid once both have.
/// The course being tuned is the one raised, filled chip, showing the live pitch in the tuner's colour rule
/// (mint in the lock band, amber close, coral far) and blooming solid mint as it locks. Tuned courses stay
/// quiet with a small ✓ on the shoulder. Increase Contrast strengthens rings and labels; Differentiate
/// Without Colour adds a symbol (▲ sharp, ▼ flat, ✓ in tune).
struct StringRail: View {
    /// The readout's smoothing, so the selected chip shows the same value as the digits.
    let motion: ReadoutMotion
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let groups = CourseGrouping.groups(store.courses)
        let ordered = store.settings.handedness == "left" ? Array(groups.reversed()) : groups
        // Centred when every course fits (iPad, most instruments); scrolls full-bleed for long courses.
        ViewThatFits(in: .horizontal) {
            row(ordered).padding(.horizontal, Metrics.gutter)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { row(ordered) }
                    .contentMargins(.horizontal, Metrics.gutter, for: .scrollContent)
                    // The raised chip's shadow and the ✓ badges reach past the row: let them show.
                    .scrollClipDisabled()
                    .onChange(of: store.selectedCourse) { _, index in
                        let chip = groups.first { $0.contains(index) }?.id ?? index
                        withAnimation(Motion.settle) { proxy.scrollTo(chip, anchor: .center) }
                    }
            }
        }
    }

    private func row(_ groups: [CourseGroup]) -> some View {
        HStack(spacing: 10) {
            ForEach(groups) { group in
                CourseChip(group: group, motion: motion).id(group.id)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CourseChip: View {
    let group: CourseGroup
    let motion: ReadoutMotion
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor

    private struct Style {
        var ring: Color
        var fill: Color
        var text: Color
        var cue: Color
        /// Solid mint with dark text (locked, or tuned and quiet).
        var solid = false
        /// Sharp, flat or in tune, shown as a symbol with Differentiate Without Colour.
        var mark: PitchMark?
    }

    /// What the chip shows: the note, its octave or cue, and a pip per string of a pair.
    private struct Face {
        var name: String
        var cue: String
        var padded: Bool
        /// One colour per string of a pair (empty for a single string).
        var pips: [Color]
        var mark: PitchMark?
    }

    private var strong: Bool { contrast == .increased }

    var body: some View {
        let label = TargetLabelFormatter.splitCue(store.courseLabel(group.lead))
        let locked = store.lockedCourses
        let active = store.activeCourse.index
        let selected = group.contains(active)
        let tuned = group.isTuned(locked)
        let parts = NoteReadout.split(label.main)
        let style = selected ? selectedStyle(tuned: tuned) : restingStyle(tuned: tuned)
        let face = Face(name: parts.name, cue: label.cue ?? parts.octave, padded: label.cue != nil,
                        pips: pipColors(locked: locked, active: selected ? active : nil, live: style.ring),
                        mark: withoutColor ? style.mark : nil)
        // The string being tuned stands up off the rail (until it blooms solid on the lock); a tuned string you
        // are not tuning carries the ✓ instead.
        let raised = selected && !style.solid
        let lift: Color = raised ? Color.black.opacity(0.6) : Color.clear
        let halo: Color = style.solid ? Palette.mint.opacity(0.55) : (raised ? style.ring.opacity(0.3) : Color.clear)
        let change = Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion)
        Button { store.chooseCourse(group.nextToTune(store.lockedCourses).index) } label: {
            content(face, text: style.text, cueColor: style.cue)
                .background { chipFill(style.fill, raised: raised) }
                .overlay { solidLayer(face, solid: style.solid) }
                .overlay(Capsule().strokeBorder(style.ring, lineWidth: ringWidth(selected: selected, solid: style.solid)))
                .overlay(alignment: .topTrailing) { shoulderBadge(tuned: tuned, done: tuned && !selected, ring: style.ring) }
                .shadow(color: lift, radius: 10, y: 6)
                .shadow(color: halo, radius: 12)
                .scaleEffect(selected ? 1.1 : 1)
                .animation(change, value: selected)
                .animation(change, value: tuned)
                .animation(change, value: style.solid)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName(label.main))
        .accessibilityValue(accessibilityState(locked: locked, tuned: tuned))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("string.\(group.id)")
    }

    private func content(_ face: Face, text: Color, cueColor: Color, solid: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(face.name).font(Typeface.label(17))
            Text(face.cue).font(Typeface.label(10)).foregroundStyle(cueColor)
        }
        // The symbol sits just above the note, the pair's pips just below it; neither moves the note.
        .overlay(alignment: .top) {
            if let mark = face.mark {
                PitchMark.image(mark, size: 8).alignmentGuide(.top) { d in d[.bottom] + 1 }
            }
        }
        .overlay(alignment: .bottom) {
            if !face.pips.isEmpty {
                pips(face.pips, solid: solid).alignmentGuide(.bottom) { d in d[.top] - 4 }
            }
        }
        .foregroundStyle(text)
        .frame(minWidth: 50, minHeight: 50)
        .padding(.horizontal, face.padded ? 6 : 0)
    }

    private func pips(_ colors: [Color], solid: Bool) -> some View {
        HStack(spacing: 3) {
            ForEach(colors.indices, id: \.self) { i in
                Circle().fill(solid ? Palette.onAccent.opacity(0.7) : colors[i]).frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    /// A pair's pips: mint for a string that has locked, the live colour for the one being tuned, faint otherwise.
    private func pipColors(locked: Set<Int>, active: Int?, live: Color) -> [Color] {
        guard group.count > 1 else { return [] }
        return group.courses.map { course in
            if locked.contains(course.index) { return Palette.mint }
            if course.index == active { return live }
            return strong ? Palette.inkSoft : Palette.inkFaint.opacity(0.6)
        }
    }

    /// The chip's body: the raised chip lifts onto a lighter surface with a soft top light; the rest sit in the rail.
    private func chipFill(_ fill: Color, raised: Bool) -> some View {
        ZStack {
            if raised {
                Capsule().fill(Palette.surface)
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
            }
            Capsule().fill(fill)
        }
    }

    private func ringWidth(selected: Bool, solid: Bool) -> CGFloat {
        (selected && !solid ? 2 : (solid ? 1.5 : 1)) + (strong ? 0.5 : 0)
    }

    /// The chip's shoulder: "×2" for a pair (mint, with a ✓, once both strings are tuned); for a single string
    /// you are not tuning, a small mint ✓ once it is tuned.
    @ViewBuilder private func shoulderBadge(tuned: Bool, done: Bool, ring: Color) -> some View {
        if group.count > 1 {
            HStack(spacing: 2) {
                if tuned { Image(systemName: "checkmark").font(.system(size: 7, weight: .heavy)) }
                Text(verbatim: "×\(group.count)").font(Typeface.label(9))
            }
            .foregroundStyle(tuned ? Palette.onAccent : (strong ? Palette.ink : Palette.inkSoft))
            .padding(.horizontal, 4).padding(.vertical, 1.5)
            .background(Capsule().fill(tuned ? Palette.mint : Palette.stageRaised))
            .overlay(Capsule().strokeBorder(tuned ? Color.clear : ring, lineWidth: 1))
            .fixedSize()
            .offset(x: 4, y: -3)
            .accessibilityHidden(true)
        } else if done {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Palette.mint))
                .overlay(Circle().strokeBorder(Palette.stage, lineWidth: 1.5))
                .offset(x: 2, y: -2)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.scale(scale: 0.3).combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }

    /// The solid state is a second copy of the chip (mint fill, dark label) revealed by a capsule that blooms
    /// from the centre. Fill and label change together, so every glyph is either light on dark or dark on
    /// mint at each moment of the lock: the label never disappears. Reduce Motion fades it instead.
    private func solidLayer(_ face: Face, solid: Bool) -> some View {
        content(face, text: Palette.onAccent, cueColor: Palette.onAccent.opacity(0.75), solid: true)
            .background(Capsule().fill(Palette.mint))
            .mask {
                Capsule()
                    .scaleEffect(solid || reduceMotion ? 1 : 0.001)
                    .opacity(solid || !reduceMotion ? 1 : 0)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Strings you are not tuning stay quiet in the rail; a tuned one keeps a faint mint edge and its octave in
    /// mint, and its ✓ badge says it is done (so it never outshines the string being tuned).
    private func restingStyle(tuned: Bool) -> Style {
        tuned ? Style(ring: Palette.mint.opacity(strong ? 0.7 : 0.22), fill: Palette.mint.opacity(0.04), text: Palette.ink, cue: Palette.mint)
              : Style(ring: .white.opacity(strong ? 0.45 : 0.12), fill: .white.opacity(0.03), text: Palette.ink, cue: strong ? Palette.inkSoft : Palette.inkFaint)
    }

    /// The string being tuned is the raised, filled chip: it follows the live pitch with the readout's colour rule
    /// (the same steady whole cents as the digits) and turns solid mint while locked. With no pitch it is solid
    /// mint if already tuned, otherwise a bright ring on the raised fill.
    private func selectedStyle(tuned: Bool) -> Style {
        // Only this chip reads the live reading, so only it redraws with the pitch.
        let reading = store.live.reading
        let live = audio.running && reading.cents != nil ? motion.shown : nil
        let solid = Style(ring: Palette.mint, fill: Palette.mint.opacity(0.12), text: Palette.ink, cue: Palette.mint, solid: true, mark: .inTune)
        guard let live else {
            return tuned ? solid : Style(ring: strong ? Palette.ink : Palette.ink.opacity(0.85), fill: .white.opacity(0.06), text: Palette.ink, cue: strong ? Palette.ink : Palette.inkSoft)
        }
        if reading.inTune { return solid }
        let tint = Palette.tuning(Double(live), locked: false)
        return Style(ring: tint, fill: tint.opacity(0.2), text: Palette.ink, cue: tint, mark: PitchMark(shown: live, locked: false))
    }

    /// "String 4, D3": the number players call the string by, 1 the thinnest (the digits its peg-head anchor ends in,
    /// "s4"), as lessons and Strum to tune count. A pair shares its anchor, so it reads as one string; its state says
    /// "1 of 2". Only a course without an anchor falls back to its index.
    private func accessibilityName(_ note: String) -> Text {
        let digits = String((group.lead.anchorId ?? "").reversed().prefix { $0.isNumber }.reversed())
        return Text("String \(Int(digits) ?? group.lead.index), \(note)")
    }

    /// "Tuned"; a pair part way: "1 of 2".
    private func accessibilityState(locked: Set<Int>, tuned: Bool) -> Text {
        if tuned { return Text("Tuned") }
        let count = group.lockedCount(locked)
        guard group.count > 1, count > 0 else { return Text(verbatim: "") }
        return Text("\(count) of \(group.count)")
    }
}
