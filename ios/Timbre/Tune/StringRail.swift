import SwiftUI
import TimbreCore

/// One chip per course, in physical order, thickest to thinnest from the left (mirrored for a left-handed player),
/// in every language: the row is music, not text, so it never flips right to left. Under it, "Thickest" and "Thinnest"
/// name its ends wherever the strings run low to high. Unison partners (a mandolin's pair) share one chip marked ×2,
/// with a pip per string that lights as that string locks; the chip turns solid once both have.
/// The course being tuned is the one raised, filled chip, showing the live pitch in the tuner's colour rule
/// (mint in the lock band, amber close, coral far) and turning solid mint as it locks. Tuned courses stay
/// quiet with a small ✓ on the shoulder. When every string is in tune the chips light low to high in step with the
/// strum (`SoundFX.playTuned`). Increase Contrast strengthens rings and labels; Differentiate Without Colour adds a
/// symbol (▲ sharp, ▼ flat, ✓ in tune).
struct StringRail: View {
    /// The readout's smoothing, so the selected chip shows the same value as the digits.
    let motion: ReadoutMotion
    /// The lock as the readout shows it, so the chip stays solid exactly while the badge does.
    let latch: LockLatch
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorSchemeContrast) private var contrast
    /// The chips lit by the full-tune roll right now.
    @State private var ringing: Set<Int> = []

    var body: some View {
        let groups = CourseGrouping.groups(store.courses)
        let mirrored = store.settings.handedness.isLeftHanded
        let ordered = mirrored ? Array(groups.reversed()) : groups
        VStack(spacing: 2) {
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
            if Self.lowToHigh(groups) { ends(mirrored: mirrored) }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onChange(of: store.celebrate) { _, _ in roll(groups) }
    }

    private func row(_ groups: [CourseGroup]) -> some View {
        HStack(spacing: 10) {
            ForEach(groups) { group in
                CourseChip(group: group, motion: motion, latch: latch, ringing: ringing.contains(group.id)).id(group.id)
            }
        }
        .padding(.vertical, 6)
    }

    /// "Thickest" under the low end, "Thinnest" under the high one.
    private func ends(mirrored: Bool) -> some View {
        let color = contrast == .increased ? Palette.inkSoft : Palette.inkFaint
        return HStack {
            Text(mirrored ? "Thinnest" : "Thickest")
            Spacer(minLength: 12)
            Text(mirrored ? "Thickest" : "Thinnest")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(color)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Metrics.gutter + 4)
        .accessibilityHidden(true)
    }

    /// The strings rise in pitch along the row (a guitar, a bass, the violin family), so its ends are the thickest
    /// and thinnest strings. Re-entrant tunings (a GCEA ukulele, a banjo's short fifth) don't, and get no captions.
    static func lowToHigh(_ groups: [CourseGroup]) -> Bool {
        guard groups.count > 1 else { return false }
        let pitches = groups.map(\.lead.targetMidi)
        return zip(pitches, pitches.dropFirst()).allSatisfy { $0 < $1 }
    }

    /// Every string in tune: each chip lights in turn, in string order, as the strum rolls across its string.
    private func roll(_ groups: [CourseGroup]) {
        let courses = store.courses
        let step = SoundSynth.tunedRoll(count: courses.count)
        for group in groups {
            let position = courses.firstIndex { $0.index == group.lead.index } ?? 0
            let id = group.id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Double(position) * step))
                withAnimation(Motion.pop) { _ = ringing.insert(id) }
                try? await Task.sleep(for: .milliseconds(360))
                withAnimation(Motion.settle) { _ = ringing.remove(id) }
            }
        }
    }
}

private struct CourseChip: View {
    let group: CourseGroup
    let motion: ReadoutMotion
    let latch: LockLatch
    /// Lit by the full-tune roll.
    var ringing = false
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor
    @Environment(\.locale) private var locale

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
        let halo: Color = ringing ? Palette.mint.opacity(0.85) : (style.solid ? Palette.mint.opacity(0.55) : (raised ? style.ring.opacity(0.3) : Color.clear))
        let scale: CGFloat = ringing && !reduceMotion ? 1.16 : (selected ? 1.1 : 1)
        let change = Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion)
        let spoken = NoteNames.spoken(label.main, locale: locale, system: NoteNames.active)
        Button { store.chooseCourse(group.nextToTune(store.lockedCourses).index) } label: {
            content(face, text: style.text, cueColor: style.cue)
                .background { chipFill(style.fill, raised: raised) }
                .overlay { solidLayer(face, solid: style.solid) }
                .overlay(Capsule().strokeBorder(style.ring, lineWidth: ringWidth(selected: selected, solid: style.solid)))
                .overlay(alignment: .topTrailing) { shoulderBadge(tuned: tuned, done: tuned && !selected, ring: style.ring) }
                .shadow(color: lift, radius: 10, y: 6)
                .shadow(color: halo, radius: ringing ? 16 : 12)
                .scaleEffect(scale)
                .animation(change, value: selected)
                .animation(change, value: tuned)
                .animation(change, value: style.solid)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("String \(stringNumber), \(spoken)"))
        .accessibilityValue(accessibilityState(locked: locked, tuned: tuned))
        .accessibilityAddTraits(selected ? .isSelected : [])
        // Voice Control: "Tap D", "Tap String 4" or "Tap D 3", without the comma.
        .accessibilityInputLabels(inputLabels(name: parts.name, spoken: spoken))
        .accessibilityIdentifier("string.\(group.id)")
    }

    private func content(_ face: Face, text: Color, cueColor: Color, solid: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(face.name).font(Typeface.label(17))
            Text(face.cue).font(Typeface.label(.caption)).foregroundStyle(cueColor)
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
                Text(verbatim: "×\(group.count)").font(Typeface.badge)
            }
            .foregroundStyle(tuned ? Palette.onAccent : (strong ? Palette.ink : Palette.inkSoft))
            .padding(.horizontal, 4).padding(.vertical, 1.5)
            .background(Capsule().fill(tuned ? Palette.mint : Palette.stageRaised))
            .overlay(Capsule().strokeBorder(tuned ? Color.clear : ring, lineWidth: 1))
            .fixedSize()
            // A badge on the chip's shoulder: it grows a little with the text size, never over the note.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
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

    /// The solid state is a second copy of the chip (mint fill, dark label) that crossfades in over the first as the
    /// string locks, growing the last few points to its size. Both copies carry the label, so it never disappears
    /// and is never cut; under Reduce Motion it only fades.
    private func solidLayer(_ face: Face, solid: Bool) -> some View {
        content(face, text: Palette.onAccent, cueColor: Palette.onAccent.opacity(0.75), solid: true)
            .background(Capsule().fill(Palette.mint))
            .opacity(solid ? 1 : 0)
            .scaleEffect(solid || reduceMotion ? 1 : 0.92)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Strings you are not tuning stay quiet in the rail; a tuned one keeps a faint mint edge and its octave in
    /// mint, and its ✓ badge says it is done (so it never outshines the string being tuned).
    private func restingStyle(tuned: Bool) -> Style {
        tuned ? Style(ring: Palette.mint.opacity(strong ? 0.7 : 0.22), fill: Palette.mint.opacity(0.04), text: Palette.ink, cue: Palette.mint)
              : Style(ring: Palette.controlLine, fill: .white.opacity(0.03), text: Palette.ink, cue: strong ? Palette.inkSoft : Palette.inkFaint)
    }

    /// The string being tuned is the raised, filled chip: it follows the live pitch with the readout's colour rule
    /// (the same steady whole cents as the digits) and turns solid mint while the lock is on screen (`LockLatch`).
    /// With no pitch it is solid mint if already tuned, otherwise a bright ring on the raised fill.
    private func selectedStyle(tuned: Bool) -> Style {
        // Only this chip reads the live reading, so only it redraws with the pitch.
        let reading = store.live.reading
        let live = audio.running && reading.cents != nil ? motion.shown : nil
        let solid = Style(ring: Palette.mint, fill: Palette.mint.opacity(0.12), text: Palette.ink, cue: Palette.mint, solid: true, mark: .inTune)
        if latch.shows(reading, listening: audio.running, shown: live) { return solid }
        guard let live else {
            return tuned ? solid : Style(ring: strong ? Palette.ink : Palette.ink.opacity(0.85), fill: .white.opacity(0.06), text: Palette.ink, cue: strong ? Palette.ink : Palette.inkSoft)
        }
        let tint = Palette.tuning(Double(live), locked: false)
        return Style(ring: tint, fill: tint.opacity(0.2), text: Palette.ink, cue: tint, mark: PitchMark(shown: live, locked: false))
    }

    /// The number players call the string by, 1 the thinnest (the digits its peg-head anchor ends in, "s4"), as
    /// lessons and Strum to tune count: VoiceOver reads "String 4, D 3". A pair shares its anchor, so it reads as one
    /// string; its state says "1 of 2". Only a course without an anchor falls back to its index.
    private var stringNumber: Int {
        let digits = String((group.lead.anchorId ?? "").reversed().prefix { $0.isNumber }.reversed())
        return Int(digits) ?? group.lead.index
    }

    /// What Voice Control answers to: the note ("D", "F sharp"), the string's number, and the note with its octave.
    private func inputLabels(name: String, spoken: String) -> [Text] {
        let letter = NoteNames.spoken(name, locale: locale, system: NoteNames.active)
        return [Text(verbatim: letter), Text("String \(stringNumber)"), Text(verbatim: spoken)]
    }

    /// "Tuned"; a pair part way: "1 of 2".
    private func accessibilityState(locked: Set<Int>, tuned: Bool) -> Text {
        if tuned { return Text("Tuned") }
        let count = group.lockedCount(locked)
        guard group.count > 1, count > 0 else { return Text(verbatim: "") }
        return Text("\(count) of \(group.count)")
    }
}
