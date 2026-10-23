import SwiftUI
import TimbreCore

/// One token per course, in physical order. Tuned strings keep a lit ring.
struct StringRail: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let courses = store.settings.handedness == "left" ? Array(store.courses.reversed()) : store.courses
        // Centred when every course fits (iPad, most instruments); scrolls for long courses.
        ViewThatFits(in: .horizontal) {
            row(courses)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { row(courses) }
                    .onChange(of: store.selectedCourse) { _, index in withAnimation(Motion.settle) { proxy.scrollTo(index, anchor: .center) } }
            }
        }
    }

    private func row(_ courses: [Course]) -> some View {
        HStack(spacing: 10) {
            ForEach(courses) { course in
                let label = TargetLabelFormatter.splitCue(store.courseLabel(course))
                let selected = store.activeCourse.index == course.index
                let tuned = store.lockedCourses.contains(course.index)
                let parts = NoteReadout.split(label.main)
                // Amber ring: the string you are tuning. Mint: tuned (solid once the selected one locks).
                let solid = selected && tuned
                let ring: Color = solid ? Palette.mint : tuned ? Palette.mint.opacity(0.45) : selected ? Palette.amber : .white.opacity(0.12)
                let fill: Color = solid ? Palette.mint : tuned ? Palette.mint.opacity(0.08) : selected ? Palette.amber.opacity(0.12) : .white.opacity(0.03)
                Button { store.chooseCourse(course.index) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(parts.name).font(Typeface.label(17))
                        Text(label.cue ?? parts.octave).font(Typeface.label(10))
                            .foregroundStyle(solid ? Palette.onAccent.opacity(0.75) : tuned ? Palette.mint : selected ? Palette.amber : Palette.inkFaint)
                    }
                    .foregroundStyle(solid ? Palette.onAccent : tuned ? Color(hex: 0xCFFBEA) : selected ? Color(hex: 0xFFE2B3) : Palette.ink)
                    .frame(minWidth: 50, minHeight: 50)
                    .padding(.horizontal, label.cue == nil ? 0 : 6)
                    .background(Capsule().fill(fill))
                    .overlay(Capsule().strokeBorder(ring, lineWidth: selected || solid ? 1.5 : 1))
                    .shadow(color: solid ? Palette.mint.opacity(0.55) : .clear, radius: 12)
                    .scaleEffect(selected ? 1.05 : 1)
                    .animation(Motion.pluck, value: selected)
                    .animation(Motion.pluck, value: tuned)
                }
                .buttonStyle(.plain)
                .id(course.index)
                .accessibilityLabel(Text("String \(course.index), \(label.main)"))
                .accessibilityValue(tuned ? Text("Tuned") : Text(""))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("string.\(course.index)")
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 6)
    }
}
