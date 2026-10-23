import SwiftUI
import TimbreCore

/// The Songs tab: every song in the curriculum, wherever it lives (Originals, the public-domain Songs
/// course, and the songs inside each instrument course), as album shelves under a daily featured song.
/// Covers are generated from each song's id (`CoverArt`), so there are no image assets. Songs open the
/// same full-screen lesson flow as Learn and follow Learn's rules (`LessonAccess`) for Pro and order locks.
struct SongsView: View {
    @EnvironmentObject private var store: AppStore
    /// Instrument filter: a catalogue instrument id, or "all".
    @AppStorage("songs.instrument") private var filter = "all"
    @State private var playing: LearnView.PlayingLesson?
    /// Shake counters for order-locked tiles, by lesson id.
    @State private var shakes: [String: Int] = [:]
    /// After a tap on an order-locked song: the open lesson on the way to it.
    @State private var hint: Hint?
    /// Songs zoom open out of the tile or hero that was tapped (and back into it on close).
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// A song and the course it belongs to.
    struct Song: Identifiable {
        let course: LearnCourse
        let lesson: Lesson
        var id: String { lesson.id }
    }

    /// One shelf: a course's songs.
    struct Shelf: Identifiable {
        let course: LearnCourse
        let songs: [Song]
        var id: String { course.id }
    }

    /// One instrument filter chip, wearing its course's art.
    struct Chip: Identifiable {
        let id: String
        let title: String
        let course: LearnCourse
    }

    struct Hint: Equatable {
        let lessonId: String
        let token: Int
    }

    private static let all = "all"
    private static let heroSource = "songs.hero"
    private static func tileSource(_ lesson: Lesson) -> String { "songs.tile.\(lesson.id)" }
    private var tileWidth: CGFloat { sizeClass == .regular ? 176 : 148 }

    /// The tab's title: the Songs course's own, translated with the curriculum.
    static func title(in curriculum: Curriculum) -> String {
        curriculum.course(id: "songs")?.title.localized ?? "Songs"
    }

    var body: some View {
        let chips = instrumentChips
        let active = chips.contains { $0.id == filter } ? filter : Self.all
        let songs = allSongs.filter { Self.matches($0, filter: active) }
        let hero = featured(songs)
        let glow: Color = hero.map { Palette.accent($0.course.accent) } ?? Color(hex: 0xFFC48C)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header
                    if chips.count > 1 { filterRail(chips, active: active) }
                    if let hero {
                        heroCard(hero)
                            .id(hero.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                    ForEach(shelves(songs)) { shelf in shelfView(shelf) }
                    Text("More lessons arrive with every update.").font(.footnote).foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .stageTopShade()
            .background(StageBackground(glow: glow, motes: false))
            .overlay(alignment: .bottom) { hintPill }
        }
        .fullScreenCover(item: $playing) { item in
            LessonPlayer(course: item.course, lesson: item.lesson) { next in
                let source = next.kind == .song ? Self.tileSource(next) : Self.heroSource
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open(item.course, next, from: source) }
            }
            .environmentObject(store)
            .navigationTransition(.zoom(sourceID: item.source, in: zoom))
        }
    }

    // MARK: Data

    /// Every song in the curriculum, in course order.
    private var allSongs: [Song] {
        store.curriculum.courses.flatMap { course in
            course.lessons.filter { $0.kind == .song }.map { Song(course: course, lesson: $0) }
        }
    }

    /// Songs for any instrument (a course without one) show under every filter.
    private static func matches(_ song: Song, filter: String) -> Bool {
        filter == all || song.course.instrument == nil || song.course.instrument == filter
    }

    /// A course that is mostly songs (Songs, Originals) rather than an instrument's path.
    private static func isCollection(_ course: LearnCourse) -> Bool {
        course.lessons.filter { $0.kind == .song }.count * 2 >= course.lessons.count
    }

    /// Originals first, then the song collections, then each instrument's songs in curriculum order.
    private static func rank(_ course: LearnCourse) -> Int {
        if course.id.hasPrefix("original") || course.title.defaultValue.lowercased().hasPrefix("original") { return 0 }
        return isCollection(course) ? 1 : 2
    }

    /// One chip per instrument that has songs, named after its own course (Guitar, Ukulele, Singing…).
    private var instrumentChips: [Chip] {
        var seen = Set<String>()
        var chips: [Chip] = []
        for course in store.curriculum.courses {
            guard let instrument = course.instrument, !seen.contains(instrument),
                  course.lessons.contains(where: { $0.kind == .song }) else { continue }
            seen.insert(instrument)
            let candidates = store.curriculum.courses.filter { $0.instrument == instrument }
            let own = candidates.first { !Self.isCollection($0) } ?? course
            chips.append(Chip(id: instrument, title: own.title.localized, course: own))
        }
        return chips
    }

    private func shelves(_ songs: [Song]) -> [Shelf] {
        var found: [Shelf] = []
        for course in store.curriculum.courses {
            let items = songs.filter { $0.course.id == course.id }
            if !items.isEmpty { found.append(Shelf(course: course, songs: items)) }
        }
        let ranked = found.enumerated().sorted { a, b in
            let left = Self.rank(a.element.course), right = Self.rank(b.element.course)
            return left != right ? left < right : a.offset < b.offset
        }
        return ranked.map { $0.element }
    }

    /// The song of the day: one the learner can play and hasn't yet (else any open one), picked by a
    /// hash of the day so it changes daily and stays put within the day.
    private func featured(_ songs: [Song]) -> Song? {
        let progress = store.learn
        let open = songs.filter { LessonAccess.of($0.lesson, in: $0.course, store: store) == .play }
        let fresh = open.filter { !progress.isFinished($0.lesson.id) }
        let pool = !fresh.isEmpty ? fresh : (!open.isEmpty ? open : songs)
        let day = UInt64(Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0)
        return pool.min { CoverArt.hash($0.id, salt: day) < CoverArt.hash($1.id, salt: day) }
    }

    // MARK: Actions

    /// Learn's path: play, the paywall for Pro, or a shake (and the way there) for a song not yet reached.
    private func open(_ course: LearnCourse, _ lesson: Lesson, from source: String) {
        switch LessonAccess.of(lesson, in: course, store: store) {
        case .play:
            Haptics.shared.selection()
            Analytics.log("song_open", ["lesson": lesson.id])
            withAnimation(Motion.quick) { hint = nil }
            playing = LearnView.PlayingLesson(course: course, lesson: lesson, source: source)
        case .pro:
            store.presentPaywall("lesson", lesson: lesson)
        case .locked:
            if !reduceMotion { withAnimation(.default) { shakes[lesson.id, default: 0] += 1 } }
            Haptics.shared.selection()
            showHint(toward: lesson, in: course)
        }
    }

    /// Points at the nearest open lesson before a locked song in its course: finishing it moves toward the song.
    private func showHint(toward lesson: Lesson, in course: LearnCourse) {
        let progress = store.learn
        let all = course.lessons
        guard let position = all.firstIndex(where: { $0.id == lesson.id }),
              let step = all[..<position].last(where: { progress.isUnlocked($0, in: course) && !progress.isFinished($0.id) }) else { return }
        withAnimation(Motion.pluck) { hint = Hint(lessonId: step.id, token: (hint?.token ?? 0) + 1) }
        AccessibilityNotification.Announcement(String(localized: "Next up: \(step.title.localized)", bundle: TimbreLocalization.bundle)).post()
    }

    private func choose(_ id: String) {
        guard id != filter else { return }
        Haptics.shared.selection()
        withAnimation(Motion.settle) { filter = id; hint = nil }
    }

    // MARK: Header and filters

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.title(in: store.curriculum)).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                if let subtitle = store.curriculum.course(id: "songs")?.subtitle.localized {
                    Text(subtitle).font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            StreakChip { store.selectedTab = .journey }
            LevelRing(size: 36) { store.selectedTab = .journey }
        }
    }

    private func filterRail(_ chips: [Chip], active: String) -> some View {
        EdgeRail(selection: active) {
            Button("All") { choose(Self.all) }
                .buttonStyle(ChipButtonStyle(selected: active == Self.all))
                .accessibilityAddTraits(active == Self.all ? .isSelected : [])
                .accessibilityIdentifier("songs.filter.all")
                .id(Self.all)
            ForEach(chips) { chip in
                Button { choose(chip.id) } label: {
                    HStack(spacing: 7) {
                        CourseArt(course: chip.course, size: 20).padding(.leading, -5)
                        Text(chip.title)
                    }
                }
                .buttonStyle(ChipButtonStyle(selected: active == chip.id))
                .accessibilityAddTraits(active == chip.id ? .isSelected : [])
                .accessibilityIdentifier("songs.filter.\(chip.id)")
                .id(chip.id)
            }
        }
    }

    // MARK: Featured song

    private func heroCard(_ song: Song) -> some View {
        let accent = Palette.accent(song.course.accent)
        let access = LessonAccess.of(song.lesson, in: song.course, store: store)
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return Button { open(song.course, song.lesson, from: Self.heroSource) } label: {
            heroText(song, accent: accent, access: access, stars: stars)
                .padding(20)
                .padding(.top, 120)
                .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 340 : 300, alignment: .bottomLeading)
                .background {
                    ZStack {
                        // The monogram crops off the top-right corner, clear of the eyebrow and the title.
                        SongCover(art: CoverArt(song), corner: 28, monogramAnchor: UnitPoint(x: 0.84, y: 0.27), monogramSize: 0.44, drift: true, outlined: false)
                        LinearGradient(colors: [.clear, .black.opacity(0.3), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                    }
                }
                .overlay(alignment: .topLeading) { heroEyebrow(accent: accent).padding(16) }
                .clipShape(shape)
                .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
                .shadow(color: accent.opacity(0.28), radius: 26, y: 12)
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: Self.heroSource, in: zoom)
        .accessibilityLabel(Text("Song of the day") + Text(verbatim: ", \(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(accessValue(access, stars: stars))
        .accessibilityIdentifier("songs.hero")
    }

    private func heroEyebrow(accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform").foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            Text("Song of the day").tracking(1.2).textCase(.uppercase)
        }
        .font(Typeface.label(11))
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.4)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    private func heroText(_ song: Song, accent: Color, access: LessonAccess, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(song.lesson.title.localized).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            HStack(spacing: 6) {
                CourseArt(course: song.course, size: 18)
                Text(song.course.title.localized).foregroundStyle(.white)
                Text("\(song.lesson.minutes) min · +\(song.lesson.xp) XP").foregroundStyle(.white.opacity(0.72))
            }
            .font(.subheadline).lineLimit(1)
            HStack(spacing: 12) {
                heroButton(access, finished: stars > 0, accent: accent)
                if stars > 0 { StarRow(stars: stars, size: 13) }
                Spacer(minLength: 0)
                if access == .pro { ProBadge() }
            }
            .padding(.top, 6)
        }
    }

    private func heroButton(_ access: LessonAccess, finished: Bool, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: access == .play ? "play.fill" : "lock.fill")
            Text(finished ? LocalizedStringKey("Play again") : LocalizedStringKey("Play"))
        }
        .font(Typeface.label(15)).foregroundStyle(Palette.onAccent)
        .padding(.horizontal, 18).frame(height: 42)
        .background(Capsule().fill(accent))
        .shadow(color: accent.opacity(0.45), radius: 12, y: 4)
    }

    // MARK: Shelves

    private func shelfView(_ shelf: Shelf) -> some View {
        let progress = store.learn
        let earned = shelf.songs.reduce(0) { $0 + (progress.stars[$1.lesson.id] ?? 0) }
        // The rail opens on the next song to play in it.
        let next = shelf.songs.first { !progress.isFinished($0.lesson.id) && LessonAccess.of($0.lesson, in: $0.course, store: store) == .play }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                CourseArt(course: shelf.course, size: 32)
                Text(shelf.course.title.localized).font(Typeface.display(20)).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Label("\(earned)/\(shelf.songs.count * 3)", systemImage: "star.fill").font(Typeface.number(12)).foregroundStyle(Palette.amber)
            }
            EdgeRail(spacing: 14, selection: next?.id) {
                ForEach(shelf.songs) { song in tile(song).id(song.id) }
            }
        }
    }

    private func tile(_ song: Song) -> some View {
        let access = LessonAccess.of(song.lesson, in: song.course, store: store)
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let accent = Palette.accent(song.course.accent)
        let shrink: CGFloat = reduceMotion ? 0 : 0.08
        return Button { open(song.course, song.lesson, from: Self.tileSource(song.lesson)) } label: {
            VStack(alignment: .leading, spacing: 10) {
                tileCover(song, access: access, stars: stars)
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.lesson.title.localized).font(Typeface.display(15, relativeTo: .headline)).foregroundStyle(Palette.ink)
                        .lineLimit(2, reservesSpace: true)
                    Text("\(song.lesson.minutes) min · \(song.course.title.localized)").font(.footnote)
                        .foregroundStyle(accent.mix(with: Palette.inkSoft, by: 0.45)).lineLimit(1)
                }
            }
            .frame(width: tileWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: Self.tileSource(song.lesson), in: zoom)
        .modifier(Shake(amount: shakes[song.id] ?? 0))
        // Covers ease back and dim as they slide off the rail's edge.
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content.scaleEffect(1 - shrink * CGFloat(abs(phase.value))).opacity(1 - 0.35 * abs(phase.value))
        }
        .accessibilityLabel(Text(verbatim: "\(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(accessValue(access, stars: stars))
        .accessibilityIdentifier("songs.song.\(song.id)")
    }

    /// The cover with its state: Pro songs keep their colour under a PRO badge, songs not yet reached
    /// dim under a lock, finished songs wear their stars.
    private func tileCover(_ song: Song, access: LessonAccess, stars: Int) -> some View {
        SongCover(art: CoverArt(song))
            .frame(width: tileWidth, height: tileWidth)
            .overlay {
                if access == .locked {
                    ZStack {
                        Color.black.opacity(0.5)
                        Image(systemName: "lock.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.9))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(.black.opacity(0.45)))
                            .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .overlay(alignment: .topTrailing) { if access == .pro { ProBadge().padding(10) } }
            .overlay(alignment: .bottomLeading) {
                if stars > 0 {
                    StarRow(stars: stars, size: 10)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(10)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
    }

    private func accessValue(_ access: LessonAccess, stars: Int) -> Text {
        if stars > 0 { return Text("\(stars) of 3 stars") }
        switch access {
        case .play: return Text("Open")
        case .pro: return Text("Pro")
        case .locked: return Text("Locked")
        }
    }

    // MARK: Order-lock hint

    /// "Next up: …" above the tab bar after a tap on a song not yet reached; tapping it plays that lesson.
    @ViewBuilder private var hintPill: some View {
        if let hint, let found = store.curriculum.lesson(id: hint.lessonId) {
            let accent = Palette.accent(found.course.accent)
            Button { open(found.course, found.lesson, from: Self.heroSource) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.open.fill").foregroundStyle(accent).accessibilityHidden(true)
                    Text("Next up: \(found.lesson.title.localized)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Image(systemName: "play.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(accent))
                        .accessibilityHidden(true)
                }
                .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("songs.hint")
            .task(id: hint) {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.settle) { self.hint = nil }
            }
        }
    }
}

extension CoverArt {
    /// The monogram follows the title as shown; colour and pattern follow the lesson id.
    init(_ song: SongsView.Song) {
        self.init(id: song.lesson.id, title: song.lesson.title.localized, accent: song.course.accent)
    }
}

/// Three small stars, earned ones in amber.
private struct StarRow: View {
    let stars: Int
    var size: CGFloat = 10
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill").font(.system(size: size, weight: .bold)).foregroundStyle(i < stars ? Palette.amber : .white.opacity(0.18))
            }
        }
        .accessibilityHidden(true)
    }
}
