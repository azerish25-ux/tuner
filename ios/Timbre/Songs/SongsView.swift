import SwiftUI
import TimbreCore

/// The Songs tab: every song in the curriculum, wherever it lives (Originals, the public-domain Songs
/// course, and the songs inside each instrument course), as record shelves under a daily featured song.
/// Sleeves are generated from each song (`CoverArt`), so there are no image assets. Songs open the
/// same full-screen lesson flow as Learn and follow Learn's rules (`LessonAccess`) for Pro and order locks.
/// The featured song (`SongOfTheDay`) suits the learner's level, and its sleeve plays the opening bars.
struct SongsView: View {
    @EnvironmentObject private var store: AppStore
    /// Instrument filter: a catalogue instrument id, or "all".
    @AppStorage("songs.instrument") private var filter = "all"
    @State private var playing: LearnView.PlayingLesson?
    /// Shake counters for order-locked tiles, by lesson id.
    @State private var shakes: [String: Int] = [:]
    /// After a tap on an order-locked song: the open lesson on the way to it.
    @State private var hint: Hint?
    /// The song whose opening is playing from the featured sleeve, when it started and how long it runs.
    @State private var previewing: String?
    @State private var previewStart = Date()
    @State private var previewLength = 0.0
    @State private var previewTask: Task<Void, Never>?
    /// Songs zoom open out of the tile or hero that was tapped (and back into it on close).
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// A song, its course and unit, and its place among the course's songs (1-based).
    struct Song: Identifiable {
        let course: LearnCourse
        let unit: LearnUnit
        let unitIndex: Int
        let lesson: Lesson
        let number: Int
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

    /// A shelf picked from the learner's progress or the songs themselves ("Because you learned E minor",
    /// "3 chords or fewer"), above the course shelves.
    struct Pick: Identifiable {
        let id: String
        let symbol: String
        let title: Text
        let songs: [Song]
    }

    private static let all = "all"
    private static let heroSource = "songs.hero"
    /// A tile's zoom source; a song on a picked shelf has its own, so the lesson zooms back into the tile it came from.
    private static func tileSource(_ lesson: Lesson, shelf: String? = nil) -> String {
        shelf.map { "songs.tile.\($0).\(lesson.id)" } ?? "songs.tile.\(lesson.id)"
    }
    private var tileWidth: CGFloat { sizeClass == .regular ? 176 : 148 }
    private var sleeveSide: CGFloat { sizeClass == .regular ? 168 : 128 }
    private var heroHeight: CGFloat { sizeClass == .regular ? 380 : 330 }

    /// The tab's title: the Songs course's own, translated with the curriculum.
    static func title(in curriculum: Curriculum) -> String {
        curriculum.course(id: "songs")?.title.localized ?? "Songs"
    }

    var body: some View {
        let chips = instrumentChips
        let active = chips.contains { $0.id == filter } ? filter : Self.all
        let songs = allSongs.filter { Self.matches($0, filter: active) }
        let hero = featured(songs)
        let curated = picks(songs, hero: hero)
        let glow: Color = hero.map { CoverArt($0).primary } ?? Color(hex: 0xFFC48C)
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
                    ForEach(curated) { pick in pickShelf(pick) }
                    // The featured song isn't repeated on its shelf: that rail starts with the song after it.
                    ForEach(shelves(songs)) { shelf in
                        let rail = shelf.songs.filter { $0.id != hero?.id }
                        if !rail.isEmpty { shelfView(shelf, rail: rail) }
                    }
                    Text("More lessons arrive with every update.").font(.footnote).foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .stageTopShade()
            .background(StageBackground(glow: glow, motes: false))
            .overlay(alignment: .bottom) { hintPill }
        }
        .onChange(of: filter) { _, _ in stopPreview() }
        .onDisappear { stopPreview() }
        .fullScreenCover(item: $playing) { item in
            LessonPlayer(course: item.course, lesson: item.lesson) { next in
                // The featured song has no tile: it zooms from the hero.
                let source = next.kind == .song && next.id != hero?.id ? Self.tileSource(next) : Self.heroSource
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open(item.course, next, from: source) }
            }
            .environmentObject(store)
            .navigationTransition(.zoom(sourceID: item.source, in: zoom))
        }
    }

    // MARK: Data

    /// Every song in the curriculum, in course order.
    private var allSongs: [Song] {
        store.curriculum.courses.flatMap { course -> [Song] in
            var found: [Song] = []
            for (index, unit) in course.units.enumerated() {
                for lesson in unit.lessons where lesson.kind == .song {
                    found.append(Song(course: course, unit: unit, unitIndex: index, lesson: lesson, number: found.count + 1))
                }
            }
            return found
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

    private static func isOriginals(_ course: LearnCourse) -> Bool {
        course.id.hasPrefix("original") || course.title.defaultValue.lowercased().hasPrefix("original")
    }

    /// Originals first, then the song collections, then each instrument's songs in curriculum order.
    private static func rank(_ course: LearnCourse) -> Int {
        if isOriginals(course) { return 0 }
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

    /// The song of the day (`SongOfTheDay`): an unfinished song at the learner's level, an Original ahead of the
    /// traditional tunes once past the beginner units, the same all day.
    private func featured(_ songs: [Song]) -> Song? {
        let progress = store.learn
        let candidates = songs.map { song in
            SongOfTheDay.Candidate(id: song.id, original: Self.isOriginals(song.course), unit: song.unitIndex,
                                   finished: progress.isFinished(song.lesson.id), access: dayAccess(song))
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let placed = progress.placedThrough.values.contains { $0 >= 0 }
        guard let id = SongOfTheDay.pick(candidates, level: store.level.number, finishedLessons: progress.stars.count,
                                         placed: placed, day: day) else { return nil }
        return songs.first { $0.id == id }
    }

    /// Learn's access, with Pro songs split into the next one in order (worth featuring) and later ones.
    private func dayAccess(_ song: Song) -> SongOfTheDay.Access {
        switch LessonAccess.of(song.lesson, in: song.course, store: store) {
        case .play: return .open
        case .pro: return store.learn.isUnlocked(song.lesson, in: song.course) ? .pro : .locked
        case .locked: return .locked
        }
    }

    // MARK: Picked shelves

    /// From the songs under the filter (the featured one aside): songs not played yet that use the chord the learner
    /// learned last ("Because you learned E minor"), then every song of one to three chords. Songs that play now
    /// come first, the easiest of them first.
    private func picks(_ songs: [Song], hero: Song?) -> [Pick] {
        let pool = songs.filter { $0.id != hero?.id }
        var out: [Pick] = []
        if let chord = lastLearnedChord {
            let using = pool.filter { song in
                !store.learn.isFinished(song.lesson.id) && SongSheet.of(song.lesson).chords.contains { $0.symbol == chord.symbol }
            }
            if !using.isEmpty {
                out.append(Pick(id: "because", symbol: "sparkles", title: Text("Because you learned \(SongSheet.spoken(chord))"),
                                songs: Array(easiestFirst(using).prefix(10))))
            }
        }
        let few = pool.filter { (1...3).contains(SongSheet.of($0.lesson).chords.count) }
        if few.count >= 2 {
            out.append(Pick(id: "few", symbol: "3.circle.fill", title: Text("3 chords or fewer"), songs: Array(easiestFirst(few).prefix(12))))
        }
        return out
    }

    /// The chord of the lesson finished most recently that taught one (a chord to play, or one on an explanation's card).
    private var lastLearnedChord: ChordSpec? {
        let recent = store.learn.finishedDates.sorted { $0.value > $1.value }
        for entry in recent.prefix(40) {
            guard let found = store.curriculum.lesson(id: entry.key), let chord = Self.taughtChord(found.lesson) else { continue }
            return chord
        }
        return nil
    }

    private static func taughtChord(_ lesson: Lesson) -> ChordSpec? {
        var taught: ChordSpec?
        for step in lesson.steps {
            switch step {
            case let .playChord(chord): taught = chord
            case let .explain(_, _, .chord(chord)): taught = chord
            default: break
            }
        }
        return taught
    }

    private struct Ranked {
        let order: Int
        let song: Song
        let open: Bool
        let level: Int
    }

    private func easiestFirst(_ songs: [Song]) -> [Song] {
        let ranked = songs.enumerated().map { item -> Ranked in
            let song = item.element
            let level = SongSheet.of(song.lesson).difficulty(unit: song.unitIndex, of: song.course.units.count)
            return Ranked(order: item.offset, song: song, open: LessonAccess.of(song.lesson, in: song.course, store: store) == .play, level: level)
        }
        let sorted = ranked.sorted { a, b in
            if a.open != b.open { return a.open }
            if a.level != b.level { return a.level < b.level }
            return a.order < b.order
        }
        return sorted.map(\.song)
    }

    // MARK: Actions

    /// Learn's path: play, the paywall for Pro, or a shake (and the way there) for a song not yet reached.
    private func open(_ course: LearnCourse, _ lesson: Lesson, from source: String) {
        stopPreview()
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

    // MARK: Preview

    /// Plays (or stops) the song's opening bars in its course's instrument voice, one note at a time on one
    /// clock, the way a lesson's "Hear it" lands its notes.
    private func togglePreview(_ song: Song) {
        if previewing == song.id { stopPreview(); return }
        stopPreview()
        guard let phrase = SongPreview.opening(of: song.lesson) else { return }
        let audio = store.audio
        let voice = InstrumentVoice(instrumentId: song.course.instrument)
        let reference = store.settings.referencePitchHz
        Haptics.shared.selection()
        Analytics.log("song_preview", ["lesson": song.id])
        previewStart = Date()
        previewLength = phrase.duration
        withAnimation(Motion.pluck) { previewing = song.id }
        previewTask = Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            for (index, note) in phrase.notes.enumerated() {
                try? await clock.sleep(until: start + .seconds(phrase.time(of: index)))
                guard !Task.isCancelled else { return }
                let ms = Int(min(1600, max(160, note.beats * phrase.secondsPerBeat * 950)))
                audio.playTones([PitchMath.frequency(midi: Double(note.midi), reference: reference)],
                                together: false, noteMs: ms, gapMs: 0, voice: voice)
            }
            try? await clock.sleep(until: start + .seconds(phrase.duration + 0.3))
            guard !Task.isCancelled else { return }
            previewTask = nil
            withAnimation(Motion.settle) { previewing = nil }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        guard previewing != nil else { return }
        store.audio.stopTone()
        withAnimation(Motion.settle) { previewing = nil }
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

    /// The song of the day: its sleeve (with the record peeking out) over a backdrop made from the same art,
    /// the title and Play below. The preview button sits on the sleeve's free corner, outside the card's button.
    private func heroCard(_ song: Song) -> some View {
        let art = CoverArt(song)
        let accent = art.primary
        let access = LessonAccess.of(song.lesson, in: song.course, store: store)
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let canPreview = SongPreview.opening(of: song.lesson) != nil
        return Button { open(song.course, song.lesson, from: Self.heroSource) } label: {
            // The ideal height is proposed to the face, so its spacer puts the title at the bottom.
            heroFace(song, art: art, access: access, stars: stars)
                .frame(maxWidth: .infinity, minHeight: heroHeight, idealHeight: heroHeight, alignment: .topLeading)
                .background { heroBackdrop(art) }
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
        .overlay(alignment: .topTrailing) {
            if canPreview {
                previewButton(song, art: art)
                    .padding(.trailing, 18 + 4)
                    .padding(.top, art.titleOnTop ? 18 + sleeveSide - 4 - 44 : 18 + 4)
            }
        }
    }

    private func heroFace(_ song: Song, art: CoverArt, access: LessonAccess, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // Above the record as it slides out.
                heroEyebrow(accent: art.primary).zIndex(1)
                Spacer(minLength: 0)
                sleeve(art, playing: previewing == song.id)
            }
            Spacer(minLength: 0)
            heroText(song, accent: art.primary, access: access, stars: stars)
        }
        .padding(18)
    }

    /// The sleeve, square and crisp, with its record peeking from the left; the record slides out and turns
    /// while the opening plays (it stays put with Reduce Motion).
    private func sleeve(_ art: CoverArt, playing: Bool) -> some View {
        let side = sleeveSide
        let out = playing && !reduceMotion ? side * 0.3 : side * 0.14
        return SongCover(art: art, corner: 8)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
            .background(alignment: .leading) {
                VinylRecord(color: art.primary, spinning: playing && !reduceMotion)
                    .frame(width: side * 0.94, height: side * 0.94)
                    .offset(x: -out)
            }
    }

    /// The same art, blurred into light behind the card, darkening toward the title.
    private func heroBackdrop(_ art: CoverArt) -> some View {
        ZStack {
            art.far
            SongCover(art: art, corner: 0, titled: false, drift: true, outlined: false)
                .blur(radius: 22)
                .opacity(0.85)
            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.35), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Play (or stop) on the sleeve: white disc, a ring that fills as the opening plays.
    private func previewButton(_ song: Song, art: CoverArt) -> some View {
        let active = previewing == song.id
        let ring = art.field ? Palette.stage : art.primary.mix(with: .black, by: 0.25)
        return Button { togglePreview(song) } label: {
            ZStack {
                Circle().fill(.white.opacity(0.94))
                if active {
                    previewRing(color: ring)
                }
                Image(systemName: active ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.stage)
                    .offset(x: active ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 38, height: 38)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(active ? Text("Stop") : Text("Hear it"))
        .accessibilityIdentifier("songs.hero.preview")
    }

    private func previewRing(color: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(previewStart)
            let fraction = previewLength > 0 ? min(1, max(0, elapsed / previewLength)) : 0
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2.5)
        }
    }

    private func heroEyebrow(accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform").foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            Text("Song of the day").tracking(1.2).textCase(.uppercase)
                .lineLimit(1).minimumScaleFactor(0.7)
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
            // What the song asks for, at a glance: its chords (its key, for a melody) and how hard it is.
            HStack(spacing: 8) {
                let sheet = SongSheet.of(song.lesson)
                DifficultyDots(level: sheet.difficulty(unit: song.unitIndex, of: song.course.units.count), tint: .white)
                ChordChips(chords: sheet.chords, key: sheet.keyName, tint: accent, limit: 5)
            }
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

    /// A course's songs: the stars count every one of them, the rail shows `rail` (all but the featured song).
    private func shelfView(_ shelf: Shelf, rail: [Song]) -> some View {
        let progress = store.learn
        let earned = shelf.songs.reduce(0) { $0 + (progress.stars[$1.lesson.id] ?? 0) }
        // The rail opens on the next song to play in it.
        let next = rail.first { !progress.isFinished($0.lesson.id) && LessonAccess.of($0.lesson, in: $0.course, store: store) == .play }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                CourseArt(course: shelf.course, size: 32)
                Text(shelf.course.title.localized).font(Typeface.display(20)).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Label("\(earned)/\(shelf.songs.count * 3)", systemImage: "star.fill").font(Typeface.number(12)).foregroundStyle(Palette.amber)
            }
            EdgeRail(spacing: 14, selection: next?.id) {
                ForEach(rail) { song in tile(song).id(song.id) }
            }
        }
    }

    /// A picked shelf: its reason as the header, then its songs' tiles (each zooming from this shelf's own tile).
    private func pickShelf(_ pick: Pick) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: pick.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.amber)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.amber.opacity(0.14)))
                    .accessibilityHidden(true)
                pick.title.font(Typeface.display(20)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            EdgeRail(spacing: 14, selection: nil as String?) {
                ForEach(pick.songs) { song in tile(song, shelf: pick.id).id(song.id) }
            }
        }
    }

    /// `shelf` names a picked shelf; nil is the song's own course shelf.
    private func tile(_ song: Song, shelf: String? = nil) -> some View {
        let access = LessonAccess.of(song.lesson, in: song.course, store: store)
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let accent = Palette.accent(song.course.accent)
        let sheet = SongSheet.of(song.lesson)
        let source = Self.tileSource(song.lesson, shelf: shelf)
        let shrink: CGFloat = reduceMotion ? 0 : 0.08
        return Button { open(song.course, song.lesson, from: source) } label: {
            VStack(alignment: .leading, spacing: 10) {
                tileCover(song, access: access, stars: stars)
                tileCaption(song, sheet: sheet, accent: accent)
            }
            .frame(width: tileWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: source, in: zoom)
        .modifier(Shake(amount: shakes[song.id] ?? 0))
        // Sleeves ease back and dim as they slide off the rail's edge.
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content.scaleEffect(1 - shrink * CGFloat(abs(phase.value))).opacity(1 - 0.35 * abs(phase.value))
        }
        .accessibilityLabel(Text(verbatim: "\(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(tileValue(song, sheet: sheet, access: access, stars: stars))
        .accessibilityIdentifier(shelf.map { "songs.\($0).\(song.id)" } ?? "songs.song.\(song.id)")
    }

    /// Under the sleeve, which already carries the title: the part of the title it leaves off ("The chords"), else the
    /// song's chords ("G D Em C"; its key for a melody), then how hard it is, how long it runs and its XP.
    private func tileCaption(_ song: Song, sheet: SongSheet, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if let subtitle = Self.subtitle(song.lesson.title.localized) {
                    Text(verbatim: subtitle).font(Typeface.label(13, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    ChordChips(chords: sheet.chords, key: sheet.keyName, tint: accent)
                }
            }
            .frame(height: 24, alignment: .leading)
            HStack(spacing: 7) {
                DifficultyDots(level: sheet.difficulty(unit: song.unitIndex, of: song.course.units.count), tint: accent)
                Text(verbatim: sheet.length).font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                Text("+\(song.lesson.xp) XP").font(.footnote).foregroundStyle(accent.mix(with: Palette.inkSoft, by: 0.45))
            }
            .lineLimit(1)
        }
    }

    /// The part of a title after its main title, which the sleeve leaves off: "Greensleeves: the chords" is "The chords".
    private static func subtitle(_ title: String) -> String? {
        let main = CoverArt.mainTitle(title)
        guard main != title, let range = title.range(of: main) else { return nil }
        let rest = title[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " :()（）：").union(.whitespaces))
        guard let first = rest.first else { return nil }
        return first.uppercased() + rest.dropFirst()
    }

    /// Open, Pro or locked (or the stars), how hard, and the chords, for VoiceOver.
    private func tileValue(_ song: Song, sheet: SongSheet, access: LessonAccess, stars: Int) -> Text {
        let level = sheet.difficulty(unit: song.unitIndex, of: song.course.units.count)
        var value = accessValue(access, stars: stars) + Text(verbatim: ", ") + Text(DifficultyDots.name(level))
        if !sheet.chords.isEmpty { value = value + Text(verbatim: ", " + sheet.chords.map(\.name).joined(separator: " ")) }
        return value
    }

    /// The sleeve with its state, in the corner its title leaves free: Pro songs keep their colour under a PRO
    /// badge, songs not yet reached dim under a lock, and every open song shows its progress: its stars (empty
    /// ones still to win) and, once played, a bar along its foot filled to its best accuracy.
    private func tileCover(_ song: Song, access: LessonAccess, stars: Int) -> some View {
        let art = CoverArt(song)
        let best = access == .locked ? nil : store.learn.bestAccuracy[song.lesson.id]
        return SongCover(art: art, locked: access == .locked)
            .frame(width: tileWidth, height: tileWidth)
            .overlay(alignment: .bottom) { if let best { progressBar(best) } }
            .overlay(alignment: art.freeCorner) {
                if access == .pro {
                    ProBadge().padding(10)
                } else if access == .play {
                    starPlate(stars)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
    }

    /// The stars a song has earned on a dark plate; unplayed, three faint ones show what there is to win.
    private func starPlate(_ stars: Int) -> some View {
        StarRow(stars: stars, size: 10)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(stars > 0 ? 0.55 : 0.4)))
            .overlay(Capsule().strokeBorder(.white.opacity(stars > 0 ? 0 : 0.1), lineWidth: 1))
            .padding(10)
    }

    /// How much of the song has landed (its best accuracy), as a bar along the sleeve's foot.
    private func progressBar(_ best: Double) -> some View {
        let share = CGFloat(min(1, max(0, best)))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.45))
                Capsule().fill(Palette.amber)
                    .frame(width: max(4, proxy.size.width * share))
                    .shadow(color: Palette.amber.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 10).padding(.bottom, 5)
        .accessibilityHidden(true)
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
    /// The title as shown sets the sleeve's type; colour, motif and layout follow the lesson id and its unit's genre.
    init(_ song: SongsView.Song) {
        self.init(id: song.lesson.id, title: song.lesson.title.localized, accent: song.course.accent,
                  genre: CoverArt.genre(unit: song.unit.title.defaultValue, instrument: song.course.instrument),
                  label: song.course.title.localized, number: song.number)
    }

    /// A song lesson's sleeve wherever it shows (its song sheet, its poster): the same art as its tile on the shelf,
    /// numbered by its place among its course's songs.
    static func of(_ lesson: Lesson, in course: LearnCourse) -> CoverArt {
        var number = 0
        for (index, unit) in course.units.enumerated() {
            for item in unit.lessons where item.kind == .song {
                number += 1
                if item.id == lesson.id {
                    return CoverArt(SongsView.Song(course: course, unit: unit, unitIndex: index, lesson: item, number: number))
                }
            }
        }
        let unit = course.units.first { $0.lessons.contains { $0.id == lesson.id } }
        return CoverArt(id: lesson.id, title: lesson.title.localized, accent: course.accent,
                        genre: CoverArt.genre(unit: unit?.title.defaultValue ?? "", instrument: course.instrument),
                        label: course.title.localized, number: 1)
    }
}

/// A song's chords as small chips ("G" "D" "Em" "C"), as many as fit, "+2" for the rest; its key for a song
/// without chords. VoiceOver reads them with the tile.
private struct ChordChips: View {
    let chords: [ChordSpec]
    let key: String?
    let tint: Color
    var limit = 4

    var body: some View {
        Group {
            if chords.isEmpty {
                if let key { keyLabel(key) }
            } else {
                ViewThatFits(in: .horizontal) {
                    row(min(limit, chords.count))
                    row(min(3, chords.count))
                    row(min(2, chords.count))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func row(_ shown: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(chords.prefix(shown), id: \.symbol) { chord in chip(chord.name) }
            if chords.count > shown {
                Text(verbatim: "+\(chords.count - shown)").font(Typeface.label(11)).foregroundStyle(Palette.inkSoft).fixedSize()
            }
        }
    }

    private func chip(_ name: String) -> some View {
        Text(verbatim: name).font(Typeface.label(12)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 7).frame(height: 22)
            .background(Capsule().fill(tint.opacity(0.16)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
            .fixedSize()
    }

    private func keyLabel(_ key: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "music.note").font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            Text(verbatim: key).font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
        }
        .lineLimit(1)
    }
}

/// How hard a song is (`SongSheet.difficulty`): three dots, the earned ones lit.
private struct DifficultyDots: View {
    let level: Int
    let tint: Color

    static func name(_ level: Int) -> LocalizedStringKey { level <= 1 ? "Easy" : level == 2 ? "Medium" : "Hard" }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(index < level ? tint : Color.white.opacity(0.18)).frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.name(level)))
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
