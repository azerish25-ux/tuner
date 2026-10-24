import SwiftUI
import TimbreCore
import UIKit

/// The Learn tab: pick a course, continue where you left off, and follow the path lesson by lesson. On an iPad's
/// regular width the path takes one card column and a lesson inspector (`LessonInspector`) the rest: a tap on a node
/// shows that lesson there (its steps, a preview, Start), a second tap starts it. Narrower windows (Split View, Slide
/// Over) get the phone's single column.
struct LearnView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("learn.course") private var courseId = "guitar"
    @State private var playing: PlayingLesson?
    /// Content has scrolled under the status bar: a scrim fades in behind it.
    @State private var scrolled = false
    /// iPad: the lesson picked on the path for the inspector; nil follows the course's next lesson.
    @State private var selectedId: String?
    /// iPad: a lesson the path scrolls to (picked from the inspector, or the next one when the course opens).
    @State private var reveal: Reveal?
    /// iPad: the course whose next lesson the path has already scrolled to, so coming back to the tab keeps the place.
    @State private var revealedCourse: String?
    /// Lessons zoom open out of the card or node that was tapped (and back into it on close).
    @Namespace private var zoom

    struct PlayingLesson: Identifiable {
        let course: LearnCourse
        let lesson: Lesson
        /// The matched transition source the lesson zooms out of.
        let source: String
        var id: String { lesson.id }
    }

    struct Reveal: Equatable {
        let lessonId: String
        let token: Int
    }

    private static let continueSource = "learn.continue"

    private var course: LearnCourse? { store.curriculum.course(id: courseId) ?? store.curriculum.courses.first }

    /// The course's next lesson, which the inspector follows until another is picked.
    private var nextId: String? { course.flatMap { store.learn.nextLesson(in: $0)?.id } }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    GeometryReader { proxy in
                        let columns = CardColumns(width: proxy.size.width - 2 * Metrics.gutter)
                        if columns.count > 1 { wide(columns) } else { pathScroll { compactContent } }
                    }
                } else {
                    pathScroll { compactContent }
                }
            }
        }
        .onChange(of: courseId) { _, _ in
            store.publishWidgets()
            selectedId = nil
        }
        // A lesson finished moves the inspector on to the new next lesson.
        .onChange(of: nextId) { _, _ in selectedId = nil }
        .onAppear(perform: openPendingLesson)
        .onChange(of: store.pendingLessonId) { _, _ in openPendingLesson() }
        .fullScreenCover(item: $playing) { item in
            LessonPlayer(course: item.course, lesson: item.lesson) { next in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open(item.course, next, from: Self.continueSource) }
            }
            .environmentObject(store)
            .navigationTransition(.zoom(sourceID: item.source, in: zoom))
        }
    }

    private func open(_ course: LearnCourse, _ lesson: Lesson, from source: String) {
        guard store.canPlay(lesson) else { store.presentPaywall("lesson", lesson: lesson); return }
        Haptics.shared.selection()
        playing = PlayingLesson(course: course, lesson: lesson, source: source)
    }

    /// A lesson another screen asked for (`AppStore.pendingLessonId`: onboarding's first lesson, Today's lesson, a
    /// Siri, Spotlight or widget link): Learn shows its course and opens it out of the Continue card once any covering
    /// screen has gone. When one is still up after the wait (a lesson open here, from Songs or from Progress, a
    /// paywall), the link is dropped and the course left as it was: switching the course under that screen, or
    /// presenting a second cover over it (which UIKit refuses), would only leave Learn out of step.
    private func openPendingLesson() {
        guard let id = store.pendingLessonId else { return }
        store.pendingLessonId = nil
        guard let found = store.curriculum.lesson(id: id) else { return }
        Task { @MainActor in
            // A cover still going away (onboarding's, a lesson's) would refuse the presentation: wait for it (at most ~2 s).
            try? await Task.sleep(for: .milliseconds(300))
            for _ in 0..<12 where playing != nil || Self.coverShowing { try? await Task.sleep(for: .milliseconds(150)) }
            guard playing == nil, !Self.coverShowing else { return }
            if courseId != found.course.id {
                courseId = found.course.id
                // The Continue card shows the lesson's course before the lesson zooms out of it.
                try? await Task.sleep(for: .milliseconds(120))
                guard playing == nil, !Self.coverShowing else { return }
            }
            // iPad: the inspector, which the lesson zooms out of, shows it.
            selectedId = found.lesson.id
            open(found.course, found.lesson, from: Self.continueSource)
        }
    }

    /// Something is presented over the tabs (or still being dismissed).
    @MainActor private static var coverShowing: Bool {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController?.presentedViewController != nil
    }

    // MARK: Layout

    /// The path's scroll view: its own stage background on a phone (`backed`), the screen's in the iPad's columns,
    /// where it keeps half the column spacing on its `trailing` side.
    private func pathScroll<Content: View>(backed: Bool = true, trailing: CGFloat = Metrics.gutter,
                                           @ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.leading, Metrics.gutter).padding(.trailing, trailing).padding(.vertical, 12)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 4
        } action: { _, isScrolled in
            scrolled = isScrolled
        }
        .background { if backed { StageBackground(motes: false) } }
        .overlay(alignment: .top) { topScrim }
    }

    /// One column: Today in one line, the courses, the next lesson, then the path. Lazy, so a store change rebuilds
    /// only the units on screen rather than every lesson of the course.
    private var compactContent: some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            header
            // Today's practice set in one line; a tap opens it on the Play hub.
            DailySetCompactCard()
            courses
            if let course {
                continueCard(course)
                // Shows itself only when a weak-spot review is due.
                WeakSpotReviewCard(course: course) { open(course, $0, from: Self.continueSource) }
                unitPath(course)
            }
        }
    }

    /// iPad: the title across the top, then the courses and the path in one card column (`CardColumns`), and the
    /// lesson inspector across the rest with Today under it. In landscape (three columns) the inspector sets its card
    /// and steps beside its preview and Today; in portrait (two) it stacks. Each side scrolls on its own.
    private func wide(_ columns: CardColumns) -> some View {
        let half = CardColumns.spacing / 2
        let inspectorWidth = columns.span(columns.count - 1)
        return VStack(spacing: 0) {
            header
                .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 6)
            HStack(alignment: .top, spacing: 0) {
                ScrollViewReader { reader in
                    pathScroll(backed: false, trailing: half) {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            courses
                            if let course {
                                // Shows itself only when a weak-spot review is due.
                                WeakSpotReviewCard(course: course) { open(course, $0, from: Self.continueSource) }
                                unitPath(course, selecting: true)
                            }
                        }
                    }
                    .onChange(of: reveal) { _, request in
                        guard let request, let course else { return }
                        scroll(reader, to: request.lessonId, in: course)
                    }
                }
                .frame(width: columns.unit + Metrics.gutter + half)
                inspectorPane(roomy: inspectorWidth >= 640)
                    .frame(width: inspectorWidth + half + Metrics.gutter)
            }
        }
        .background(StageBackground(motes: false))
        .onAppear(perform: revealNextOnce)
        .onChange(of: courseId) { _, _ in revealNextOnce() }
    }

    /// The units of the course as a winding path, each lesson's access worked out once for the whole course. With
    /// `selecting` (iPad), a tap on a node shows it in the inspector and a second tap starts it.
    @ViewBuilder private func unitPath(_ course: LearnCourse, selecting: Bool = false) -> some View {
        let path = PathState(course: course, progress: store.learn)
        let shown = selecting ? inspected(in: course)?.id : nil
        let pick: ((Lesson) -> Void)? = selecting ? { lesson in select(lesson) } : nil
        ForEach(Array(course.units.enumerated()), id: \.element.id) { index, unit in
            UnitSection(course: course, unit: unit, number: index + 1, zoom: zoom, path: path, selectedId: shown,
                        onSelect: pick) { course, lesson in
                open(course, lesson, from: LessonNode.source(lesson))
            }
        }
        Text("More lessons arrive with every update.").font(.footnote).foregroundStyle(Palette.inkFaint)
            .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    // MARK: Inspector (iPad)

    /// The lesson the inspector shows: the one picked on the path, else the next one (the last once the course is done).
    private func inspected(in course: LearnCourse) -> Lesson? {
        if let selectedId, let position = course.position(of: selectedId) { return course.lessons[position] }
        return store.learn.nextLesson(in: course) ?? course.lessons.last
    }

    /// Beside the path on iPad: the picked lesson, then the day's set in full.
    private func inspectorPane(roomy: Bool) -> some View {
        ScrollView {
            if let course, let lesson = inspected(in: course) {
                LessonInspector(course: course, lesson: lesson, isNext: lesson.id == nextId, wide: roomy, zoom: zoom,
                                source: Self.continueSource,
                                onStart: { open(course, lesson, from: Self.continueSource) },
                                onSelect: { select($0, reveal: true) }) {
                    DailySetCard { openToday($0) }
                }
                .padding(.leading, CardColumns.spacing / 2).padding(.trailing, Metrics.gutter).padding(.vertical, 12)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .stageTopShade()
    }

    /// Shows `lesson` in the inspector (and, from the inspector, brings its node into view on the path).
    private func select(_ lesson: Lesson, reveal shows: Bool = false) {
        if lesson.id != (selectedId ?? nextId) {
            Haptics.shared.selection()
            withAnimation(Motion.settle) { selectedId = lesson.id }
        }
        if shows { reveal = Reveal(lessonId: lesson.id, token: (reveal?.token ?? 0) + 1) }
    }

    /// The first time a course shows on iPad, its path scrolls to the next lesson when that is past the first unit.
    private func revealNextOnce() {
        guard let course, revealedCourse != course.id else { return }
        revealedCourse = course.id
        guard let next = store.learn.nextLesson(in: course) else { return }
        let inFirstUnit = course.units.first?.lessons.contains(where: { $0.id == next.id }) ?? true
        guard !inFirstUnit else { return }
        reveal = Reveal(lessonId: next.id, token: (reveal?.token ?? 0) + 1)
    }

    /// Scrolls the path to a lesson's unit (it may not be built yet: the path is lazy), then centres its node.
    private func scroll(_ reader: ScrollViewProxy, to lessonId: String, in course: LearnCourse) {
        guard let unit = course.units.first(where: { $0.lessons.contains { $0.id == lessonId } }) else { return }
        Task { @MainActor in
            // The path may still be laying out (the tab just appeared, the course just changed).
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(Motion.settle) { reader.scrollTo(unit.id, anchor: .top) }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(Motion.settle) { reader.scrollTo(lessonId, anchor: .center) }
        }
    }

    /// An activity of Today opened from the panel: the lesson and a review here, the tuner on its tab, a tool on the
    /// Play hub (the paywall for a Pro tool on a free plan), as the Play hub's own card opens them.
    private func openToday(_ kind: DailyActivity.Kind) {
        if kind.needsPro && !store.isPro { store.presentPaywall("daily.\(kind.rawValue)"); return }
        switch kind {
        case .lesson: store.openDailyLesson()
        case .review:
            if let course, let review = store.weakSpotReview(in: course) { open(course, review, from: Self.continueSource) }
        case .tune: store.selectedTab = .tune
        case .ear: openTool(.ear)
        case .chord: openTool(.chords)
        case .scale: openTool(.scales)
        case .rhythm: openTool(.metronome)
        case .voice: openTool(.voice)
        case .drone: openTool(.drone)
        }
    }

    private func openTool(_ route: PracticeRoute) {
        store.pendingPracticeRoute = route
        store.selectedTab = .practice
    }

    /// Keeps the clock and status icons readable over cards scrolling beneath them.
    private var topScrim: some View {
        LinearGradient(colors: [Palette.stage, Palette.stage.opacity(0.85), Palette.stage.opacity(0)], startPoint: .top, endPoint: .bottom)
            .frame(height: 20)
            .ignoresSafeArea(edges: .top)
            .opacity(scrolled ? 1 : 0)
            .animation(Motion.quick, value: scrolled)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                    courseCard(item, selected: item.id == course?.id)
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.horizontal, -Metrics.gutter)
    }

    /// One course in the carousel: its own art in the top corner (the instrument leaning into the card,
    /// or the course emblem), the title and progress beneath. The chosen course glows in its accent.
    private func courseCard(_ item: LearnCourse, selected: Bool) -> some View {
        let accent = Palette.accent(item.accent)
        let done = store.learn.finishedCount(in: item)
        let total = item.lessons.count
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button { withAnimation(Motion.settle) { courseId = item.id }; Haptics.shared.selection() } label: {
            ZStack(alignment: .bottomLeading) {
                CourseHeroArt(artwork: CourseArtwork.of(item, catalog: store.catalog), accent: accent, size: 104, lean: -14)
                    .scaleEffect(selected ? 1.05 : 1, anchor: .center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 14, y: -6)
                // Keeps the title readable where the art reaches down.
                LinearGradient(colors: [Palette.stageRaised.opacity(0), Palette.stageRaised.opacity(0.94)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title.localized).font(Typeface.display(16)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text("\(done)/\(total)").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                    ProgressLine(value: total == 0 ? 0 : Double(done) / Double(total), color: accent, height: 4)
                }
                .padding(14)
            }
            .frame(width: 136, height: 170)
            .background {
                shape.fill(Palette.stageRaised)
                    .overlay(RadialGradient(colors: [accent.opacity(selected ? 0.32 : 0.12), .clear], center: .topTrailing, startRadius: 4, endRadius: 170))
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(selected ? accent : Palette.line, lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("learn.course.\(item.id)")
    }

    @ViewBuilder private func continueCard(_ course: LearnCourse) -> some View {
        let accent = Palette.accent(course.accent)
        let next = store.learn.nextLesson(in: course)
        let unit = next.flatMap { lesson in course.units.first { $0.lessons.contains { $0.id == lesson.id } } }
        let unitNumber = unit.flatMap { u in course.units.firstIndex { $0.id == u.id } }.map { $0 + 1 }
        let artwork = CourseArtwork.of(course, catalog: store.catalog)
        Button { if let next { open(course, next, from: Self.continueSource) } } label: {
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
                // The instrument (or the course emblem) in the card's light, as on the carousel.
                CourseHeroArt(artwork: artwork, accent: accent, size: 116, lean: -12)
                    .frame(width: 110, height: 170)
                    .padding(.trailing, -10)
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
        .matchedTransitionSource(id: Self.continueSource, in: zoom)
        .accessibilityIdentifier("learn.continue")
    }
}

/// Where the learner stands on a course's path, worked out once per render for the whole course rather than by
/// every node: the next lesson and which lessons are open.
struct PathState {
    let nextId: String?
    let unlocked: Set<String>

    init(course: LearnCourse, progress: LearnProgress) {
        nextId = progress.nextLesson(in: course)?.id
        unlocked = Set(course.lessons.lazy.filter { progress.isUnlocked($0, in: course) }.map(\.id))
    }
}

/// A unit banner and its lessons as a winding path of nodes.
struct UnitSection: View {
    let course: LearnCourse
    let unit: LearnUnit
    let number: Int
    /// The Learn tab's zoom namespace: each node is a source the lesson zooms out of.
    let zoom: Namespace.ID
    let path: PathState
    /// iPad: the lesson the inspector shows, ringed on the path.
    var selectedId: String? = nil
    /// iPad: a tap on a node not yet picked picks it for the inspector (nil on a phone: the tap plays).
    var onSelect: ((Lesson) -> Void)? = nil
    let onPlay: (LearnCourse, Lesson) -> Void
    @EnvironmentObject private var store: AppStore

    private let rowHeight: CGFloat = 104

    var body: some View {
        let accent = Palette.accent(course.accent)
        let progress = store.learn
        let finished = unit.lessons.filter { progress.isFinished($0.id) }.count
        let nextId = path.nextId
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
                // START sits beside its node, clear of the stars of the node above: off the neck on the side the node
                // leans to, or toward the middle on the open path, where a node can swing near the edge.
                let sides = points.map { point -> HorizontalEdge in
                    let right = point.x >= geometry.size.width / 2
                    return neck == right ? .trailing : .leading
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
                        LessonNode(course: course, lesson: lesson, accent: accent, current: lesson.id == nextId,
                                   unlocked: path.unlocked.contains(lesson.id), zoom: zoom,
                                   selected: lesson.id == selectedId, startSide: sides[i],
                                   onSelect: picker(lesson)) { onPlay(course, lesson) }
                            .position(points[i])
                            .id(lesson.id)
                    }
                }
            }
            .frame(height: rowHeight * CGFloat(unit.lessons.count))
        }
    }

    /// iPad: what a tap on a node not yet picked does (pick it); nil on a phone.
    private func picker(_ lesson: Lesson) -> (() -> Void)? {
        guard let onSelect else { return nil }
        return { onSelect(lesson) }
    }
}

/// What a tap on a lesson does, wherever it is shown (the Learn path, the Songs shelves): a Pro lesson
/// opens the paywall, a lesson past the learner's place refuses (the caller shakes it), the rest play.
enum LessonAccess {
    case play, pro, locked

    @MainActor static func of(_ lesson: Lesson, in course: LearnCourse, store: AppStore) -> LessonAccess {
        if !store.canPlay(lesson) { return .pro }
        return store.learn.isUnlocked(lesson, in: course) ? .play : .locked
    }
}

/// One stop on the path: raised disc, kind icon, stars when finished, lock when not yet open. The next lesson pulses
/// with START beside it; on iPad the lesson the inspector shows wears a ring.
struct LessonNode: View {
    let course: LearnCourse
    let lesson: Lesson
    let accent: Color
    let current: Bool
    /// Open on the path (`PathState`, worked out once for the course).
    let unlocked: Bool
    let zoom: Namespace.ID
    /// iPad: the inspector shows this lesson.
    var selected = false
    /// The side START sits on, beside the disc (never above it, where the node before keeps its stars).
    var startSide: HorizontalEdge = .trailing
    /// iPad: a tap picks the node for the inspector until it is picked; then a tap plays it.
    var onSelect: (() -> Void)? = nil
    let action: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var pulse = false

    /// The matched transition source id of a lesson's node.
    static func source(_ lesson: Lesson) -> String { "learn.node.\(lesson.id)" }
    /// Between the current node's halo and START.
    private static let startGap: CGFloat = 10
    @State private var shake = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = store.learn
        let stars = progress.stars[lesson.id] ?? 0
        let pro = !store.canPlay(lesson)
        let size: CGFloat = current ? 78 : lesson.kind == .challenge ? 72 : 64
        let symbol = lesson.kind == .song ? "music.quarternote.3" : lesson.kind == .challenge ? "crown.fill" : lesson.kind == .review ? "arrow.clockwise" : stars > 0 ? "checkmark" : "music.note"
        let lit = unlocked && !pro
        Button {
            if let onSelect, !selected { onSelect(); return }
            switch LessonAccess.of(lesson, in: course, store: store) {
            case .play: action()
            case .pro: store.presentPaywall("lesson", lesson: lesson)
            case .locked: withAnimation(.default) { shake += 1 }; Haptics.shared.selection()
            }
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
                .overlay {
                    if selected {
                        Circle().strokeBorder(Palette.ink.opacity(0.9), lineWidth: 2.5)
                            .frame(width: size + 14, height: size + 14)
                            .shadow(color: accent.opacity(0.6), radius: 8)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .overlay(alignment: startSide == .trailing ? .trailing : .leading) {
                    if current { startPill }
                }
                if stars > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(i < stars ? Palette.amber : .white.opacity(0.15))
                        }
                    }
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: Self.source(lesson), in: zoom)
        .modifier(Shake(amount: shake))
        .onAppear { guard current, !reduceMotion else { return }; withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } }
        .accessibilityLabel(Text(lesson.title.localized))
        .accessibilityValue(Text(stars > 0 ? LocalizedStringKey("\(stars) of 3 stars") : lit ? LocalizedStringKey("Open") : LocalizedStringKey("Locked")))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("learn.lesson.\(lesson.id)")
    }

    /// START beside the disc, just past its halo, a small chevron pointing at the node; it nudges toward it and back.
    private var startPill: some View {
        let trailing = startSide == .trailing
        let edge: HorizontalAlignment = trailing ? .trailing : .leading
        let gap = Self.startGap
        return HStack(spacing: 4) {
            if trailing { chevron("chevron.backward") }
            Text("START").font(Typeface.label(12)).tracking(1.2)
            if !trailing { chevron("chevron.forward") }
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 1))
        .fixedSize()
        .offset(x: pulse ? (trailing ? -3 : 3) : 0)
        // Its near edge sits `gap` outside the disc's halo: the trailing guide is its leading edge (or the other way).
        .alignmentGuide(edge) { d in trailing ? d[.leading] - gap : d[.trailing] + gap }
        .accessibilityHidden(true)
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 9, weight: .heavy))
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
