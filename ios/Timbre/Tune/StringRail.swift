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
                Button { store.chooseCourse(course.index) } label: {
                    VStack(spacing: 2) {
                        Text(NoteReadout.split(label.main).name).font(Typeface.display(24, relativeTo: .title2))
                        Text(label.cue ?? NoteReadout.split(label.main).octave).font(.caption2.weight(.semibold)).foregroundStyle(selected ? Color(hex: 0x1A1206).opacity(0.7) : Palette.inkFaint)
                    }
                    .frame(minWidth: 50, minHeight: 58)
                    .padding(.horizontal, 4)
                    .foregroundStyle(selected ? Color(hex: 0x1A1206) : Palette.ink)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selected ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xC8954A)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.stageRaised.opacity(0.9)))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(tuned ? Palette.locked.opacity(0.9) : Palette.line, lineWidth: tuned ? 1.5 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if tuned {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Palette.locked, Palette.stage)
                                .offset(x: 4, y: -4).transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(selected ? 1.06 : 1)
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
