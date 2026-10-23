import SwiftUI
import TimbreCore

/// The Learn tab: pick a course, continue where you left off, and follow the path lesson by lesson.
struct LearnView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("learn.course") private var courseId = "guitar"
    @State private var playing: PlayingLesson?

    struct PlayingLesson: Identifiable {
        let course: LearnCourse
        let lesson: Lesson
        var id: String { lesson.id }
    }

    private var course: LearnCourse? { store.curriculum.course(id: courseId) ?? store.curriculum.courses.first }

    var body: some View {
        NavigationStack {
            Group {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        courses
                        if let course {
                            continueCard(course)
                            ForEach(Array(course.units.enumerated()), id: \.element.id) { index, unit in
                                UnitSection(course: course, unit: unit, number: index + 1, onPlay: open)
                            }
                            Text("More lessons arrive with every update.").font(.footnote).foregroundStyle(Palette.inkFaint)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
                }
                .background(StageBackground(motes: false))
            }
        }
        .fullScreenCover(item: $playing) { item in
            LessonPlayer(course: item.course, lesson: item.lesson) { next in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open(item.course, next) }
            }
            .environmentObject(store)
        }
    }

    private func open(_ course: LearnCourse, _ lesson: Lesson) {
        guard store.canPlay(lesson) else { store.presentPaywall("lesson"); return }
        Haptics.shared.selection()
        playing = PlayingLesson(course: course, lesson: lesson)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Learn").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            StreakChip { store.selectedTab = .journey }
            LevelRing(size: 36) { store.selectedTab = .journey }
        }
    }

    private var courses: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.curriculum.courses) { item in
                    let selected = item.id == course?.id
                    let accent = Palette.accent(item.accent)
                    let done = store.learn.finishedCount(in: item)
                    let total = item.lessons.count
                    Button { withAnimation(Motion.settle) { courseId = item.id }; Haptics.shared.selection() } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(selected ? Palette.onAccent : accent)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(selected ? AnyShapeStyle(accent) : AnyShapeStyle(accent.opacity(0.14))))
                            Spacer(minLength: 0)
                            Text(item.title.localized).font(Typeface.display(16)).foregroundStyle(Palette.ink).lineLimit(1)
                            Text("\(done)/\(total)").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                            ProgressLine(value: total == 0 ? 0 : Double(done) / Double(total), color: accent, height: 4)
                        }
                        .padding(14)
                        .frame(width: 128, height: 150)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised)
                                .overlay(RadialGradient(colors: [accent.opacity(selected ? 0.28 : 0.10), .clear], center: .topLeading, startRadius: 4, endRadius: 150).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)))
                        )
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(selected ? accent : Palette.line, lineWidth: selected ? 1.5 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("learn.course.\(item.id)")
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.horizontal, -Metrics.gutter)
    }

    @ViewBuilder private func continueCard(_ course: LearnCourse) -> some View {
        let accent = Palette.accent(course.accent)
        let next = store.learn.nextLesson(in: course)
        let unit = next.flatMap { lesson in course.units.first { $0.lessons.contains { $0.id == lesson.id } } }
        let unitNumber = unit.flatMap { u in course.units.firstIndex { $0.id == u.id } }.map { $0 + 1 }
        let photo = course.instrument.flatMap { store.catalog.photo(instrumentId: $0)?.asset }
        let image = photo.map { asset in ModelLibrary.modelID(forPhoto: asset).map { ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : asset } ?? asset }
        Button { if let next { open(course, next) } } label: {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    if let next, let unit, let unitNumber {
                        Text("UNIT \(unitNumber) · \(unit.title.localized.uppercased())").font(Typeface.label(11)).tracking(1.2).foregroundStyle(accent).lineLimit(1)
                        Text(next.title.localized).font(Typeface.display(24)).tracking(-0.4).foregroundStyle(Palette.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text("\(next.minutes) min · +\(next.xp) XP").font(.subheadline).foregroundStyle(Palette.inkSoft)
                        HStack(spacing: 6) {
                            Image(systemName: store.canPlay(next) ? "play.fill" : "lock.fill")
                            Text(store.learn.finishedCount(in: course) == 0 ? LocalizedStringKey("Start") : LocalizedStringKey("Continue"))
                        }
                        .font(Typeface.label(15)).foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 18).frame(height: 42)
                        .background(Capsule().fill(accent))
                        .shadow(color: accent.opacity(0.45), radius: 12, y: 4)
                        .padding(.top, 4)
                    } else {
                        Text("Course complete").font(Typeface.display(24)).foregroundStyle(Palette.ink)
                        Text("Replay any lesson for three stars.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                if let image {
                    Image(image).resizable().interpolation(.high).scaledToFit().frame(width: 110, height: 170)
                        .rotationEffect(.degrees(-12)).shadow(color: .black.opacity(0.6), radius: 16, y: 10)
                        .padding(.trailing, -10)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.26), Palette.stageRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("learn.continue")
    }
}

/// A unit banner and its lessons as a winding path of nodes.
struct UnitSection: View {
    let course: LearnCourse
    let unit: LearnUnit
    let number: Int
    let onPlay: (LearnCourse, Lesson) -> Void
    @EnvironmentObject private var store: AppStore

    private let rowHeight: CGFloat = 104

    var body: some View {
        let accent = Palette.accent(course.accent)
        let progress = store.learn
        let finished = unit.lessons.filter { progress.isFinished($0.id) }.count
        let next = progress.nextLesson(in: course)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("UNIT \(number)").font(Typeface.label(11)).tracking(1.4).foregroundStyle(accent)
                    Text(unit.title.localized).font(Typeface.display(20)).foregroundStyle(Palette.ink)
                    Text(unit.summary.localized).font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    if unit.lessons.contains(where: { !$0.free }) && !store.isPro { ProBadge() }
                    Label("\(progress.stars(in: unit))/\(unit.lessons.count * 3)", systemImage: "star.fill").font(Typeface.number(12)).foregroundStyle(Palette.amber)
                    Text("\(finished)/\(unit.lessons.count)").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
            .overlay(alignment: .leading) { Capsule().fill(accent).frame(width: 4).padding(.vertical, 18) }
            GeometryReader { geometry in
                let neck = course.fretKind != nil
                let swing = neck ? 22.0 : min(90, geometry.size.width * 0.24)
                let points = unit.lessons.indices.map { i in
                    CGPoint(x: geometry.size.width / 2 + sin(Double(i) * 1.15 + Double(number)) * swing, y: rowHeight * (CGFloat(i) + 0.5))
                }
                ZStack {
                    if neck {
                        // The path is a stretch of fingerboard: frets between lessons, strings running through.
                        NeckStrip(rows: unit.lessons.count, rowHeight: rowHeight, strings: course.stringCount, fretless: course.fretless, accent: accent)
                            .frame(width: 150)
                            .position(x: geometry.size.width / 2, y: rowHeight * CGFloat(unit.lessons.count) / 2)
                    } else {
                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for (a, b) in zip(points, points.dropFirst()) {
                                path.addCurve(to: b, control1: CGPoint(x: a.x, y: (a.y + b.y) / 2), control2: CGPoint(x: b.x, y: (a.y + b.y) / 2))
                            }
                        }
                        .stroke(Palette.line, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [0.1, 13]))
                    }
                    ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { i, lesson in
                        LessonNode(course: course, lesson: lesson, accent: accent, current: lesson.id == next?.id) { onPlay(course, lesson) }
                            .position(points[i])
                            .id(lesson.id)
                    }
                }
            }
            .frame(height: rowHeight * CGFloat(unit.lessons.count))
        }
    }
}

/// One stop on the path: raised disc, kind icon, stars when finished, lock when not yet open.
struct LessonNode: View {
    let course: LearnCourse
    let lesson: Lesson
    let accent: Color
    let current: Bool
    let action: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var pulse = false
    @State private var shake = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = store.learn
        let stars = progress.stars[lesson.id] ?? 0
        let unlocked = progress.isUnlocked(lesson, in: course)
        let pro = !store.canPlay(lesson)
        let size: CGFloat = current ? 78 : lesson.kind == .challenge ? 72 : 64
        let symbol = lesson.kind == .song ? "music.quarternote.3" : lesson.kind == .challenge ? "crown.fill" : lesson.kind == .review ? "arrow.clockwise" : stars > 0 ? "checkmark" : "music.note"
        let lit = unlocked && !pro
        Button {
            if lit || stars > 0 { action() }
            else if pro { store.presentPaywall("lesson") }
            else { withAnimation(.default) { shake += 1 }; Haptics.shared.selection() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if current {
                        Circle().stroke(accent.opacity(0.35), lineWidth: 6).frame(width: size + 22, height: size + 22)
                            .scaleEffect(pulse ? 1.12 : 0.96).opacity(pulse ? 0.2 : 0.9)
                    }
                    Circle().fill(lit ? accent.opacity(0.55) : Color.black.opacity(0.5)).frame(width: size, height: size).offset(y: 6)
                    Circle().fill(lit ? AnyShapeStyle(LinearGradient(colors: [accent.mix(with: .white, by: 0.25), accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.surface))
                        .frame(width: size, height: size)
                        .overlay(Circle().strokeBorder(.white.opacity(lit ? 0.35 : 0.06), lineWidth: 1.5).padding(1))
                    Image(systemName: pro ? "lock.fill" : (lit ? symbol : "lock.fill"))
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(lit ? Palette.onAccent : Palette.inkFaint)
                }
                .shadow(color: current ? accent.opacity(0.5) : .clear, radius: 18)
                if stars > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(i < stars ? Palette.amber : .white.opacity(0.15))
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if current {
                    Text("START").font(Typeface.label(12)).tracking(1.2).foregroundStyle(accent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.stageRaised))
                        .overlay(Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 1))
                        .offset(y: pulse ? -44 : -38)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .modifier(Shake(amount: shake))
        .onAppear { guard current, !reduceMotion else { return }; withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityLabel(Text(lesson.title.localized))
        .accessibilityValue(Text(stars > 0 ? LocalizedStringKey("\(stars) of 3 stars") : lit ? LocalizedStringKey("Open") : LocalizedStringKey("Locked")))
        .accessibilityIdentifier("learn.lesson.\(lesson.id)")
    }
}

/// A vertical stretch of fingerboard behind a unit's lessons.
struct NeckStrip: View {
    let rows: Int
    let rowHeight: CGFloat
    let strings: Int
    var fretless = false
    var accent: Color = Palette.mint

    var body: some View {
        Canvas { context, size in
            let board = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14)
            let wood = Gradient(colors: fretless ? [Color(hex: 0x1D1D20), Color(hex: 0x111113)] : [Color(hex: 0x3B2519), Color(hex: 0x24160F)])
            context.fill(board, with: .linearGradient(wood, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            context.stroke(board, with: .color(.white.opacity(0.06)), lineWidth: 1)
            if !fretless {
                for row in 0...rows {
                    let y = CGFloat(row) * rowHeight
                    context.fill(Path(CGRect(x: 2, y: y - 1.5, width: size.width - 4, height: 3)), with: .color(Color(hex: 0xC8C2B8).opacity(row == 0 ? 0 : 0.55)))
                }
            }
            for s in 0..<max(1, strings) {
                let x = 16 + (size.width - 32) * CGFloat(s) / CGFloat(max(1, strings - 1))
                let width = 0.8 + CGFloat(strings - 1 - s) * 0.35
                context.fill(Path(CGRect(x: x - width / 2, y: 0, width: width, height: size.height)), with: .color(Color(hex: 0xE2DCD0).opacity(0.5)))
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .accessibilityHidden(true)
    }
}
