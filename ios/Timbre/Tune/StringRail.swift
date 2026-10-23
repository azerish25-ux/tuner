import SwiftUI
import TimbreCore

/// One token per course, in physical order. Tuned strings keep a lit ring; the string being tuned
/// shows the live pitch in the tuner's colour rule (mint in the lock band, amber close, coral far).
struct StringRail: View {
    /// The readout's smoothing, so the selected chip shows the same value as the digits.
    let motion: ReadoutMotion
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let courses = store.settings.handedness == "left" ? Array(store.courses.reversed()) : store.courses
        // Centred when every course fits (iPad, most instruments); scrolls full-bleed for long courses.
        ViewThatFits(in: .horizontal) {
            row(courses).padding(.horizontal, Metrics.gutter)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { row(courses) }
                    .contentMargins(.horizontal, Metrics.gutter, for: .scrollContent)
                    .onChange(of: store.selectedCourse) { _, index in withAnimation(Motion.settle) { proxy.scrollTo(index, anchor: .center) } }
            }
        }
    }

    private func row(_ courses: [Course]) -> some View {
        HStack(spacing: 10) {
            ForEach(courses) { course in
                CourseChip(course: course, motion: motion).id(course.index)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CourseChip: View {
    let course: Course
    let motion: ReadoutMotion
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService

    private struct Style {
        var ring: Color
        var fill: Color
        var text: Color
        var cue: Color
        var solid = false
    }

    var body: some View {
        let label = TargetLabelFormatter.splitCue(store.courseLabel(course))
        let selected = store.activeCourse.index == course.index
        let tuned = store.lockedCourses.contains(course.index)
        let parts = NoteReadout.split(label.main)
        let style = selected ? selectedStyle(tuned: tuned) : restingStyle(tuned: tuned)
        Button { store.chooseCourse(course.index) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(parts.name).font(Typeface.label(17))
                Text(label.cue ?? parts.octave).font(Typeface.label(10)).foregroundStyle(style.cue)
            }
            .foregroundStyle(style.text)
            .frame(minWidth: 50, minHeight: 50)
            .padding(.horizontal, label.cue == nil ? 0 : 6)
            .background(Capsule().fill(style.fill))
            .overlay(Capsule().strokeBorder(style.ring, lineWidth: selected || style.solid ? 1.5 : 1))
            .shadow(color: style.solid ? Palette.mint.opacity(0.55) : .clear, radius: 12)
            .scaleEffect(selected ? 1.05 : 1)
            .animation(Motion.pluck, value: selected)
            .animation(Motion.pluck, value: tuned)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("String \(course.index), \(label.main)"))
        .accessibilityValue(tuned ? Text("Tuned") : Text(""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("string.\(course.index)")
    }

    /// Strings you are not tuning: mint once tuned, quiet otherwise.
    private func restingStyle(tuned: Bool) -> Style {
        tuned ? Style(ring: Palette.mint.opacity(0.45), fill: Palette.mint.opacity(0.08), text: Color(hex: 0xCFFBEA), cue: Palette.mint)
              : Style(ring: .white.opacity(0.12), fill: .white.opacity(0.03), text: Palette.ink, cue: Palette.inkFaint)
    }

    /// The string being tuned follows the live pitch with the readout's colour rule; solid mint while locked.
    /// With no pitch it is solid mint if already tuned, otherwise a plain bright ring.
    private func selectedStyle(tuned: Bool) -> Style {
        // Only this chip reads the live reading, so only it redraws with the pitch.
        let reading = store.live.reading
        let live = audio.running && reading.cents != nil ? motion.cents : nil
        let solid = Style(ring: Palette.mint, fill: Palette.mint, text: Palette.onAccent, cue: Palette.onAccent.opacity(0.75), solid: true)
        guard let live else {
            return tuned ? solid : Style(ring: Palette.ink.opacity(0.75), fill: .white.opacity(0.08), text: Palette.ink, cue: Palette.inkSoft)
        }
        if reading.inTune { return solid }
        let tint = Palette.tuning(live, locked: false)
        return Style(ring: tint, fill: tint.opacity(0.12), text: Palette.ink, cue: tint)
    }
}
