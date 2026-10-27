import SwiftUI
import TimbreCore
import UIKit

/// The Songs tab: every song in the curriculum, wherever it lives (Originals, the public-domain Songs
/// course, and the songs inside each instrument course), as record shelves under a daily featured song.
/// Sleeves are generated from each song (`CoverArt`), so there are no image assets. Songs open the
/// same full-screen lesson flow as Learn and follow Learn's rules (`LessonAccess`) for Pro and order locks.
/// The featured song (`SongOfTheDay`) suits the learner's level, and its sleeve plays the opening bars. The shelves
/// open on the songs people know ("Songs you know": Ode to Joy, Amazing Grace, Silent Night…), with the carols in their
/// season; the rest is adult-first: the Originals and the Standards lead the hero, the picked shelves and the course
/// shelves, and nursery rhymes and campfire rounds have a shelf of their own lower down ("Campfire & kids"). The foot
/// of the page asks for the songs that aren't here yet ("Request a song").
/// A song further on in its course says under its sleeve what to finish first ("Finish Kite Weather"), and a Pro song
/// wears a gold lock in its play corner, the same way on every shelf. Every sleeve offers twenty seconds of its song
/// ("Hear it", over the band) and, for a tune
/// several courses teach (Ode to Joy on guitar, violin, cello…), badges of its other versions to choose from; the
/// picked shelves show each tune once, in the learner's instrument's version.
/// What every song's standing is, and so each shelf, is worked out by `SongsCatalog` once per change of progress,
/// Pro, level, day or effective free access, not on every store change.
struct SongsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    /// Instrument filter: a catalogue instrument id, or "all".
    @AppStorage("songs.instrument") private var filter = "all"
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    /// The learner's Learn course: its instrument's version of a tune leads on the picked shelves.
    @AppStorage(Preferences.Key.learnCourse) private var learnCourseId = Preferences.defaultLearnCourse
    @State private var catalog = SongsCatalog()
    @State private var railMeasurement = SongRailMeasurement()
    @State private var playing: LearnView.PlayingLesson?
    /// Shake counters for order-locked tiles, by lesson id.
    @State private var shakes: [String: Int] = [:]
    /// After a tap on an order-locked song: the open lesson on the way to it.
    @State private var hint: Hint?
    /// The song playing from its sleeve (the featured opening, or a locked song's twenty seconds), when it started
    /// and how long it runs.
    @State private var previewing: String?
    @State private var previewStart = Date()
    @State private var previewLength = 0.0
    @State private var previewTask: Task<Void, Never>?
    /// Songs zoom open out of the tile or hero that was tapped (and back into it on close).
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var direction
    @Environment(\.legibilityWeight) private var legibility
    @Environment(\.displayScale) private var displayScale
    /// The page's width, for the iPad's card columns (`CardColumns`) under the featured song.
    @State private var pageWidth: CGFloat = 0
    /// "Request a song": the field is up, what it holds, and a thank-you once one is sent.
    @State private var requesting = false
    @State private var request = ""
    @State private var requested = false
    @State private var sendingRequest = false
    @State private var requestFailed = false

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

    /// A shelf on the page: a picked one or a course's.
    private enum ShelfItem: Identifiable {
        case pick(Pick)
        case rail(SongsCatalog.Rail)

        var id: String {
            switch self {
            case .pick(let pick): return "pick." + pick.id
            case .rail(let rail): return "rail." + rail.id
            }
        }
    }

    /// A shelf picked from the learner's progress or the songs themselves ("Because you learned E minor",
    /// "3 chords or fewer"), above the course shelves.
    struct Pick: Identifiable {
        let id: String
        let symbol: String
        let title: Text
        let songs: [Song]
    }

    static let all = "all"
    private static let heroSource = "songs.hero"
    /// A locked song's "Hear it": at most this many seconds of it.
    private static let sampleSeconds = 20.0
    /// A tile's zoom source; a song on a picked shelf has its own, so the lesson zooms back into the tile it came from.
    private static func tileSource(_ lesson: Lesson, shelf: String? = nil) -> String {
        shelf.map { "songs.tile.\($0).\(lesson.id)" } ?? "songs.tile.\(lesson.id)"
    }
    private var tileWidth: CGFloat { sizeClass == .regular ? 176 : 148 }
    private var sleeveSide: CGFloat { sizeClass == .regular ? 168 : 124 }
    /// iPad: the featured row's height (the song of the day and the songs up next). On iPhone the card is as tall as
    /// what it holds.
    private var heroHeight: CGFloat { 380 }
    /// Under a tile's sleeve, before its caption.
    private static let captionGap: CGFloat = 10
    /// The tune's other versions shown as badges under a tile's sleeve; "+2" for the rest.
    private var versionLimit: Int { sizeClass == .regular ? 3 : 2 }

    /// Prefer the translated course name; unfinished lesson content must not make an otherwise localized tab English.
    static func title(in curriculum: Curriculum) -> String {
        if let title = curriculum.course(id: "songs")?.title {
            let localized = title.localized
            if localized != title.defaultValue { return localized }
        }
        return String(localized: "Songs")
    }

    var body: some View {
        let chips = catalog.chips(store)
        let active = chips.contains { $0.id == filter } ? filter : Self.all
        let layout = catalog.layout(filter: active, course: learnCourseId, store: store)
        let hero = layout.hero
        let shelves = Self.items(layout)
        let glow: Color = hero.map { catalog.art($0).primary } ?? Palette.spotlight
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    // The top of the page as one piece, so "Your songs" is built with it on any screen height: it opens
                    // a chart another app hands to Timbre ("Open in Timbre").
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if chips.count > 1 { filterRail(chips, active: active) }
                        if let hero {
                            featured(hero, layout: layout)
                                .id(hero.id)
                                .transition(.adaptive(.opacity.combined(with: .scale(scale: 0.97)), reduceMotion: reduceMotion))
                        }
                        // The player's own charts and "Add a song" (YourSongs/YourSongsShelf.swift), above the fold under
                        // the song of the day: one row while there are none. It keeps this place whatever the filter, so
                        // its sheets and the song it opens stay up.
                        YourSongsShelf()
                    }
                    ForEach(shelves) { item in shelfItem(item) }
                    requestFooter
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { width in pageWidth = width }
            .stageTopShade()
            .background(StageBackground(glow: glow, motes: false))
            .overlay(alignment: .bottom) { hintPill }
        }
        .onChange(of: filter) { _, _ in stopPreview() }
        .onDisappear { stopPreview() }
        .alert("Request a song", isPresented: $requesting) {
            if requestAvailable && !requestFailed {
                TextField("Song and artist", text: $request)
                Button("Send") { sendRequest() }
            }
            Button("Contact support") { openURL(AppLinks.support) }
            Button("Cancel", role: .cancel) { }
        } message: {
            if requestFailed {
                Text("Your request could not be sent. Try again later.")
            } else if !store.settings.sharesUsage {
                Text("Song requests are unavailable while usage sharing is off.")
            } else if !Analytics.isSending {
                Text("Song requests are unavailable in this build.")
            } else {
                Text("Your song title and instrument filter are sent to TelemetryDeck. Do not include personal information.")
            }
        }
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

    /// The picked shelves, then the course shelves, with "Campfire & kids" (`SongsCatalog.Layout.lower`) after the
    /// song collections and before the instruments' own. The featured song keeps its place on its course's shelf, so
    /// the shelf's numbers run on without a gap.
    private static func items(_ layout: SongsCatalog.Layout) -> [ShelfItem] {
        var items = layout.picks.map { ShelfItem.pick($0) }
        let rails = layout.rails.map { ShelfItem.rail($0) }
        let split = min(max(0, layout.lowerAfter), rails.count)
        items += rails[..<split]
        if let lower = layout.lower { items.append(.pick(lower)) }
        items += rails[split...]
        return items
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
        guard let step = SongsCatalog.gate(lesson, in: course, progress: store.learn) else { return }
        withAnimation(Motion.pluck) { hint = Hint(lessonId: step.id, token: (hint?.token ?? 0) + 1) }
        AccessibilityNotification.Announcement(String(localized: "Next up: \(step.title.localized)", bundle: TimbreLocalization.bundle)).post()
    }

    private func choose(_ id: String) {
        guard id != filter else { return }
        Haptics.shared.selection()
        withAnimation(Motion.settle) { filter = id; hint = nil }
    }

    // MARK: Preview

    /// What a sleeve plays: notes from beat 0 at a tempo, in a meter, for so long.
    private struct Clip {
        let notes: [TimedNote]
        let bpm: Double
        let meter: Int
        let seconds: Double
        /// Bars it runs (the band under a sample is exactly as long).
        let bars: Int
        /// The song's bar it starts at (the band takes the chart's chords from there).
        var firstBar = 0
    }

    /// The featured sleeve's opening bars (`SongPreview`: a whole arrangement's first verse, not its intro).
    private static func opening(of lesson: Lesson) -> Clip? {
        guard let phrase = SongPreview.opening(of: lesson) else { return nil }
        return Clip(notes: phrase.notes, bpm: phrase.bpm, meter: 4, seconds: phrase.duration, bars: 0)
    }

    /// A locked song's "Hear it": a whole arrangement from its first verse or chorus (`SongPreview.excerpt`, the
    /// intro passed over); else the song itself (its final take, else its melody) from the top. Up to twenty seconds,
    /// cut at a bar line, at a whole tempo so the band's click and the notes keep together.
    @MainActor private static func sample(of lesson: Lesson) -> Clip? {
        if let excerpt = SongPreview.excerpt(of: lesson, maxSeconds: sampleSeconds) {
            let bpm = max(30, excerpt.bpm.rounded())
            let meter = max(1, excerpt.beatsPerBar)
            return Clip(notes: excerpt.notes, bpm: bpm, meter: meter, seconds: Double(excerpt.bars * meter) * 60 / bpm,
                        bars: excerpt.bars, firstBar: excerpt.firstBar)
        }
        let sheet = SongSheet.of(lesson)
        guard !sheet.melody.isEmpty else { return opening(of: lesson) }
        let meter = max(1, sheet.melodyMeter)
        let bpm = max(30, sheet.melodyBpm.rounded())
        let barSeconds = Double(meter) * 60 / bpm
        let end = sheet.melody.map { $0.beat + $0.beats }.max() ?? Double(meter)
        let whole = max(1, Int((end / Double(meter) - 1e-6).rounded(.up)))
        let bars = max(1, min(whole, Int((sampleSeconds / barSeconds).rounded(.down))))
        let notes = sheet.melody.filter { $0.beat < Double(bars * meter) - 1e-6 }
        guard !notes.isEmpty else { return opening(of: lesson) }
        return Clip(notes: notes, bpm: bpm, meter: meter, seconds: Double(bars) * barSeconds, bars: bars)
    }

    /// Plays (or stops) a sleeve's clip in its course's instrument voice, one note at a time on one clock, the way a
    /// lesson's "Hear it" lands its notes; a locked song's sample (`full`) plays over the band, on the song's own chords
    /// change by change where its chart has them.
    private func togglePreview(_ song: Song, full: Bool) {
        if previewing == song.id { stopPreview(); return }
        stopPreview()
        guard let found = full ? Self.sample(of: song.lesson) : Self.opening(of: song.lesson) else { return }
        let audio = store.audio
        let reference = store.settings.referencePitchHz
        var band: BandArrangement?
        if full, bandOn, found.bars > 0 {
            let chart = LeadChart.of(song.lesson)
            let harmony = chart.notes.isEmpty ? [] : chart.filledBars(from: found.firstBar, count: found.bars)
            band = SongPlayback.band(notes: found.notes, harmony: harmony, bars: found.bars, bpm: found.bpm, meter: found.meter,
                                     reference: reference, bass: song.course.fretKind != "bass")
        }
        // Without the band, a sample starts on its first note rather than a lead-in bar's rest.
        let clip = band == nil ? Self.trimmed(found) : found
        Haptics.shared.selection()
        Analytics.log(full ? "song_sample" : "song_preview", ["lesson": song.id, "band": band == nil ? "0" : "1"])
        previewStart = Date()
        previewLength = clip.seconds
        withAnimation(Motion.pluck) { previewing = song.id }
        previewTask = SongPlayback.start(SongPlayback.hits(clip.notes), bpm: clip.bpm, meter: clip.meter, length: clip.seconds,
                                         band: band, loop: false, audio: audio,
                                         voice: InstrumentVoice(instrumentId: song.course.instrument), reference: reference) {
            previewTask = nil
            withAnimation(Motion.settle) { previewing = nil }
        }
    }

    /// `clip` from its first note: the rest before it cut, and the length shortened to match.
    private static func trimmed(_ clip: Clip) -> Clip {
        guard let lead = clip.notes.first?.beat, lead > 0.01 else { return clip }
        let notes = clip.notes.map { TimedNote(midi: $0.midi, beat: $0.beat - lead, beats: $0.beats, at: $0.at) }
        return Clip(notes: notes, bpm: clip.bpm, meter: clip.meter, seconds: max(0.5, clip.seconds - lead * 60 / max(1, clip.bpm)),
                    bars: clip.bars, firstBar: clip.firstBar)
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        guard previewing != nil else { return }
        SongPlayback.stop(store.audio)
        withAnimation(Motion.settle) { previewing = nil }
    }

    // MARK: Requests

    /// The foot of the page: a song that isn't here yet can be asked for.
    private var requestFooter: some View {
        VStack(spacing: 10) {
            (sendingRequest ? Text("Sending your request…") :
                (requested ? Text("Thanks. Your request is in.") : Text("Missing a song you love?")))
                .font(.footnote).foregroundStyle(Palette.inkSoft)
                .contentTransition(.opacity)
            Button { requestFailed = false; requesting = true } label: {
                Label("Request a song", systemImage: "text.bubble")
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("songs.request")
            .disabled(sendingRequest)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    private var requestAvailable: Bool { store.settings.sharesUsage && Analytics.isSending }

    /// Send independently of the normal event batch; success means the ingest service acknowledged the request.
    private func sendRequest() {
        let title = String(request.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !title.isEmpty, !sendingRequest else { return }
        guard requestAvailable else { requestFailed = true; requesting = true; return }
        sendingRequest = true
        requested = false
        Analytics.requestSong(title: title, filter: filter) { accepted in
            Task { @MainActor in
                sendingRequest = false
                guard accepted else {
                    requestFailed = true
                    requesting = true
                    return
                }
                request = ""
                Haptics.shared.done()
                withAnimation(Motion.settle) { requested = true }
                AccessibilityNotification.Announcement(String(localized: "Thanks. Your request is in.", bundle: TimbreLocalization.bundle)).post()
            }
        }
    }

    // MARK: Header and filters

    /// The tab's header, as on every tab: the Songs course's title and line, with the streak and level beside them.
    private var header: some View {
        let subtitle: Text? = store.curriculum.course(id: "songs").map { Text($0.subtitle.localized) }
        return TabHeader(title: Text(Self.title(in: store.curriculum)), subtitle: subtitle, identity: "songs.header")
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
                            .accessibilityIdentifier("songs.filter.\(chip.id).title")
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

    /// The song of the day. On iPad (two card columns or more, `CardColumns`) it shares its row with the songs up next,
    /// the hero across all but the last column, so it isn't a band of colour stretched across the screen.
    @ViewBuilder private func featured(_ hero: Song, layout: SongsCatalog.Layout) -> some View {
        let columns = CardColumns(width: pageWidth - 2 * Metrics.gutter)
        let next = sizeClass == .regular && columns.count > 1 ? upNext(layout, hero: hero) : []
        if next.count >= 2 {
            HStack(alignment: .top, spacing: CardColumns.spacing) {
                heroCard(hero)
                    .frame(width: columns.span(columns.count - 1))
                upNextPanel(next)
                    .frame(width: columns.unit, height: heroHeight)
            }
        } else {
            heroCard(hero)
        }
    }

    /// iPad, beside the song of the day: the next song on each shelf under the filter (open and not played yet), each
    /// tune once and the featured tune aside; then songs still to unlock, and with fewer shelves than that (an
    /// instrument's filter) the songs further along them, up to four, so the panel is full beside the hero rather than
    /// a third empty. Adult-first and varied: no nursery rhyme and no sleeve repeating a motif already beside it (the
    /// featured one's included), unless that leaves fewer than two.
    private func upNext(_ layout: SongsCatalog.Layout, hero: Song) -> [Song] {
        let progress = store.learn
        var picked: [Song] = []
        var tunes: Set<String> = [SongsCatalog.tuneKey(hero.lesson)]
        var motifs: Set<CoverArt.Motif> = [catalog.art(hero).motif]
        func fits(_ song: Song, strict: Bool) -> Bool {
            guard !progress.isFinished(song.lesson.id), !tunes.contains(SongsCatalog.tuneKey(song.lesson)) else { return false }
            return !strict || (!SongsCatalog.isKids(song) && !motifs.contains(catalog.art(song).motif))
        }
        func add(_ song: Song?) {
            guard let song, picked.count < 4 else { return }
            tunes.insert(SongsCatalog.tuneKey(song.lesson))
            motifs.insert(catalog.art(song).motif)
            picked.append(song)
        }
        for rail in layout.rails {
            add(rail.songs.first { catalog.standing($0).access == .play && fits($0, strict: true) })
        }
        if picked.count < 4 {
            for rail in layout.rails { add(rail.songs.first { fits($0, strict: true) }) }
        }
        if picked.count < 4 {
            for rail in layout.rails {
                for song in rail.songs where picked.count < 4 && fits(song, strict: true) { add(song) }
            }
        }
        if picked.count < 2 {
            for rail in layout.rails { add(rail.songs.first { fits($0, strict: false) }) }
        }
        return picked
    }

    /// "Up next": as many of the songs as the hero's height holds, each a row of sleeve, title, course and length.
    /// A card at the hero's height and radius beside it.
    private func upNextPanel(_ songs: [Song]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CardTitle("Up next")
            ViewThatFits(in: .vertical) {
                upNextList(songs, limit: 4)
                upNextList(songs, limit: 3)
                upNextList(songs, limit: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .stillCard(cornerRadius: Metrics.cornerHero)
    }

    private func upNextList(_ songs: [Song], limit: Int) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(songs.prefix(limit))) { song in upNextRow(song) }
        }
    }

    /// One song up next: its sleeve, title, course and length, and Play (or a lock); a tap opens it as its tile would.
    private func upNextRow(_ song: Song) -> some View {
        let art = catalog.art(song)
        let access = catalog.standing(song).access
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let source = Self.tileSource(song.lesson, shelf: "next")
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        let playable = access == .play
        return Button { open(song.course, song.lesson, from: source) } label: {
            HStack(spacing: 12) {
                SongCover(art: art, corner: 6, locked: !playable)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: song.lesson.title.localized).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        CourseArt(course: song.course, size: 16)
                        Text(verbatim: song.course.title.localized + " · " + SongSheet.of(song.lesson).length)
                    }
                    .font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: playable ? "play.fill" : "lock.fill").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(playable ? Palette.onAccent : Palette.inkSoft)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(playable ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Color.white.opacity(0.08))))
            }
            .padding(7)
            .background(shape.fill(.white.opacity(0.04)))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: source, in: zoom)
        .modifier(Shake(amount: shakes[song.id] ?? 0))
        .accessibilityLabel(Text(verbatim: "\(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(accessValue(access, stars: stars))
        .accessibilityIdentifier("songs.next.\(song.id)")
    }

    /// The song of the day: its sleeve (with the record peeking out) over a mesh of the sleeve's own colours, Play
    /// below. On iPhone the title sits beside the sleeve, so the card is short and the shelves start on the first
    /// screen; on iPad the title goes below and the song's map and chords (`heroSheet`) fill the room beside the sleeve.
    /// The preview button sits on the sleeve's play corner (bottom-right, as on every sleeve), outside the card's button.
    private func heroCard(_ song: Song) -> some View {
        let art = catalog.art(song)
        let accent = art.primary
        let access = catalog.standing(song).access
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
        let canPreview = SongPreview.opening(of: song.lesson) != nil
        let regular = sizeClass == .regular
        let height: CGFloat? = regular ? heroHeight : nil
        // The disc's 44-point tap area sits in the sleeve's corner (on iPhone's smaller sleeve, flush with its edges),
        // so the disc stays inside the play corner the sleeve's type keeps clear (`CoverArt.playCorner`).
        let inset: CGFloat = regular ? 4 : 0
        return Button { open(song.course, song.lesson, from: Self.heroSource) } label: {
            // On iPad the ideal height is proposed to the face, so its spacer puts the title at the bottom.
            heroFace(song, art: art, access: access, stars: stars)
                .frame(maxWidth: .infinity, minHeight: height, idealHeight: height, alignment: .topLeading)
                .background { heroBackdrop(art) }
                .clipShape(shape)
                .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .matchedTransitionSource(id: Self.heroSource, in: zoom)
        .accessibilityLabel(Text("Song of the day") + Text(verbatim: ", \(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(accessValue(access, stars: stars))
        .accessibilityIdentifier("songs.hero")
        .overlay(alignment: .topTrailing) {
            if canPreview {
                PreviewDisc(active: previewing == song.id, ring: art.field ? Palette.stage : art.primary.mix(with: .black, by: 0.25),
                            start: previewStart, length: previewLength, side: regular ? 38 : 32) {
                    togglePreview(song, full: false)
                }
                .accessibilityIdentifier("songs.hero.preview")
                .padding(.trailing, Metrics.cardPadding + inset)
                .padding(.top, Metrics.cardPadding + sleeveSide - inset - Metrics.minTarget)
            }
        }
    }

    /// The sleeve top-right; beside it the eyebrow, then the title (iPhone) or the song's map and chords (iPad); the
    /// details and Play at the foot.
    private func heroFace(_ song: Song, art: CoverArt, access: LessonAccess, stars: Int) -> some View {
        let regular = sizeClass == .regular
        // At the accessibility sizes the title needs the card's width: it goes below the sleeve on iPhone too.
        let titleBeside = !regular && !typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: titleBeside ? 14 : 16) {
            HStack(alignment: .top, spacing: regular ? 16 : 12) {
                heroLead(song, art: art, titled: titleBeside)
                    // Above the record as it slides out.
                    .zIndex(1)
                sleeve(art, playing: previewing == song.id)
            }
            // As tall as the sleeve (or the title, if taller): the lead's spacer then sets its foot level with the sleeve's.
            .fixedSize(horizontal: false, vertical: true)
            // On iPad the card has the up-next panel's height; the details go to its foot.
            if regular { Spacer(minLength: 0) }
            heroText(song, accent: art.primary, access: access, stars: stars, compact: titleBeside)
                .background(alignment: .bottom) { heroScrim(fade: titleBeside ? 14 : 40) }
        }
        .padding(Metrics.cardPadding)
    }

    /// Beside the sleeve: the eyebrow at the top and, level with the sleeve's foot, the title (iPhone, `titled`) or,
    /// on iPad, the song's map and chords.
    private func heroLead(_ song: Song, art: CoverArt, titled: Bool) -> some View {
        let regular = sizeClass == .regular
        return VStack(alignment: .leading, spacing: regular ? 12 : 10) {
            heroEyebrow(accent: art.primary, playing: previewing == song.id, identity: "songs.hero.\(song.id).eyebrow")
            Spacer(minLength: 0)
            if titled {
                // The record slides out behind it while the opening plays.
                heroTitle(song, lines: 3)
                    .padding(.trailing, 8)
            } else if regular && !typeSize.isAccessibilitySize {
                heroSheet(song, accent: art.primary)
                    // Clear of the record at its furthest out (`sleeve`).
                    .padding(.trailing, max(0, sleeveSide * 0.3 - 16) + 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The song's title in the app's ink, large, over the sleeve's light.
    private func heroTitle(_ song: Song, lines: Int) -> some View {
        Text(song.lesson.title.localized).font(Typeface.display(.title)).tracking(-0.6).foregroundStyle(Palette.ink)
            .accessibilityIdentifier("songs.hero.\(song.id).title")
            .lineLimit(lines).minimumScaleFactor(lines > 2 ? 0.75 : 0.8).fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    // MARK: The song beside its sleeve (iPad)

    /// iPad, in the room beside the sleeve: the song as its song sheet draws it, read-only, its sections
    /// (`SongSectionMap`) over its chords (`MiniChordGlyph`; its melody's notes for a song without chords), on a dark
    /// glass so both read over any sleeve's light. While the opening plays, a playhead runs through the map from where
    /// the opening starts in the song. Part of the hero's button: a tap on it opens the song.
    private func heroSheet(_ song: Song, accent: Color) -> some View {
        let sheet = SongSheet.of(song.lesson)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            heroMap(song, sheet: sheet, accent: accent)
            heroHarmony(sheet, accent: accent)
        }
        .padding(10)
        .frame(maxWidth: 560, alignment: .leading)
        .background(shape.fill(.black.opacity(reduceTransparency ? 0.62 : 0.34)))
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .allowsHitTesting(false)
    }

    /// The song map; while the featured opening plays, filled up to where it has reached.
    @ViewBuilder private func heroMap(_ song: Song, sheet: SongSheet, accent: Color) -> some View {
        let named = Self.mapWidth(sheet.sections)
        if previewing == song.id, let from = Self.openingBeat(of: song.lesson), let arrangement = sheet.arrangement,
           let tempo = Self.opening(of: song.lesson)?.bpm {
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 30)) { timeline in
                heroMapBody(sheet, accent: accent, named: named,
                            progress: Self.mapProgress(from: from, tempo: tempo, beats: arrangement.beats,
                                                       elapsed: min(previewLength, timeline.date.timeIntervalSince(previewStart))))
            }
        } else {
            heroMapBody(sheet, accent: accent, named: named, progress: nil)
        }
    }

    /// The song map (`SongSectionMap`) where the panel has room for every section's name (`named` points: landscape);
    /// else, rather than a map cut off at the panel's edge, the song's shape (`songShape`).
    private func heroMapBody(_ sheet: SongSheet, accent: Color, named: CGFloat, progress: Double?) -> some View {
        ViewThatFits(in: .horizontal) {
            SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent, progress: progress, height: 30)
                .frame(minWidth: named, maxWidth: .infinity)
            songShape(sheet, accent: accent, progress: progress)
        }
    }

    /// About how wide the song map is with every section's name in full: `SongSectionMap`'s tiles are the name (Sora,
    /// at the reader's text size) and 12 points a side, 44 at least, 4 apart.
    private static func mapWidth(_ sections: [SongSheet.Section]) -> CGFloat {
        let label = UIFont(name: "Sora-SemiBold", size: UIFontMetrics(forTextStyle: .caption1).scaledValue(for: 12))
            ?? UIFont.systemFont(ofSize: 12, weight: .semibold)
        let symbol = UIFont(name: "Sora-SemiBold", size: UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 15))
            ?? UIFont.systemFont(ofSize: 15, weight: .semibold)
        var total: CGFloat = 0
        for section in sections {
            var name = section.bars == 1 ? "\(section.start + 1)" : "\(section.start + 1)–\(section.start + section.bars)"
            var font = label
            if section.isBookend {
                name = ""
            } else if let title = section.title {
                name = title.localized
            } else if let chord = section.chord {
                name = chord.name
                font = symbol
            }
            let width = (name as NSString).size(withAttributes: [.font: font]).width
            total += max(44, ceil(width) + 24)
        }
        return total + 4 * CGFloat(max(0, sections.count - 1))
    }

    /// The song's shape, for a panel too narrow for the map's names: "Song map" and its length over its sections as
    /// plain bars, each its share of the song wide and in the map's colours (`SongSectionMap.tint`), lit up to the
    /// playhead while the opening plays. As tall as the map.
    private func songShape(_ sheet: SongSheet, accent: Color, progress: Double?) -> some View {
        let sections = sheet.sections
        let total = max(1, sections.reduce(0) { $0 + max(1, $1.bars) })
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Eyebrow("Song map", color: Palette.ink, style: .display)
                Text("\(sheet.bars) bars").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            GeometryReader { proxy in
                let room = max(0, proxy.size.width - 3 * CGFloat(max(0, sections.count - 1)))
                HStack(spacing: 3) {
                    ForEach(sections) { section in
                        shapeBar(section, in: sections, bars: sheet.bars, accent: accent, progress: progress)
                            .frame(width: room * CGFloat(max(1, section.bars)) / CGFloat(total))
                    }
                }
            }
            .frame(height: 8)
        }
        .frame(height: 30, alignment: .bottomLeading)
        .accessibilityHidden(true)
    }

    /// A section of the song's shape: its colour, brighter behind the playhead.
    private func shapeBar(_ section: SongSheet.Section, in sections: [SongSheet.Section], bars: Int, accent: Color,
                          progress: Double?) -> some View {
        let tint = SongSectionMap.tint(of: section, in: sections, accent: accent)
        let quiet = section.isBookend || (section.title == nil && section.chord == nil)
        let played = Self.played(section, bars: bars, progress: progress)
        return Capsule().fill(tint.opacity(quiet ? 0.3 : 0.6))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(tint).frame(width: proxy.size.width * CGFloat(played))
                }
            }
            .clipShape(Capsule())
    }

    /// How much of `section` the playhead has passed, 0…1 (`progress` is 0…1 of the song's `bars`).
    private static func played(_ section: SongSheet.Section, bars: Int, progress: Double?) -> Double {
        guard let progress else { return 0 }
        let bar = progress * Double(max(1, bars))
        return min(1, max(0, (bar - Double(section.start)) / Double(max(1, section.bars))))
    }

    /// How far through the song the opening has reached, 0…1: `elapsed` seconds at `tempo` from beat `from`.
    private static func mapProgress(from: Double, tempo: Double, beats: Double, elapsed: Double) -> Double {
        let beat = from + max(0, elapsed) * max(1, tempo) / 60
        return min(1, max(0, beat / max(1, beats)))
    }

    /// Where the featured opening (`SongPreview.opening`) starts in a whole arrangement, in beats: the first note of
    /// its opening section. Nil for a song without one, whose opening isn't a stretch of the map.
    private static func openingBeat(of lesson: Lesson) -> Double? {
        guard let arrangement = lesson.arrangement, let take = lesson.songTake,
              let section = SongPreview.openingSection(of: arrangement, notes: take.notes) else { return nil }
        let from = arrangement.startBeat(of: section)
        return take.notes.first { $0.beat >= from - 1e-6 }?.beat
    }

    /// The song's chords as small boxes with their names, as many as fit ("+2" for the rest); for a melody, its notes.
    @ViewBuilder private func heroHarmony(_ sheet: SongSheet, accent: Color) -> some View {
        if !sheet.chords.isEmpty {
            ViewThatFits(in: .horizontal) {
                chordStrip(sheet.chords, shown: sheet.chords.count, accent: accent)
                chordStrip(sheet.chords, shown: min(6, sheet.chords.count), accent: accent)
                chordStrip(sheet.chords, shown: min(5, sheet.chords.count), accent: accent)
                chordStrip(sheet.chords, shown: min(4, sheet.chords.count), accent: accent)
                chordStrip(sheet.chords, shown: min(3, sheet.chords.count), accent: accent)
            }
        } else if !sheet.melody.isEmpty {
            let names = Self.noteNames(sheet.noteSet)
            ViewThatFits(in: .horizontal) {
                noteStrip(names, shown: 8, accent: accent)
                noteStrip(names, shown: 6, accent: accent)
                noteStrip(names, shown: 4, accent: accent)
            }
        }
    }

    private func chordStrip(_ chords: [ChordSpec], shown: Int, accent: Color) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(chords.prefix(shown), id: \.symbol) { chord in
                VStack(spacing: 3) {
                    MiniChordGlyph(chord: chord, accent: accent)
                        .frame(width: 28, height: 40)
                    Text(verbatim: chord.name).font(Typeface.label(.caption)).foregroundStyle(Palette.ink)
                        .lineLimit(1).fixedSize()
                }
                .frame(minWidth: 30)
            }
            if chords.count > shown {
                Text(verbatim: "+\(chords.count - shown)").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft).fixedSize()
            }
        }
    }

    /// The melody's notes once each, low to high, by name ("D", "E", "F♯").
    private static func noteNames(_ notes: [Int]) -> [String] {
        var names: [String] = []
        for midi in notes {
            let name = NoteName.pitchClass(midi)
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    private func noteStrip(_ names: [String], shown: Int, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note").font(.system(size: 12, weight: .bold)).foregroundStyle(accent)
            ForEach(Array(names.prefix(shown)), id: \.self) { name in
                Text(verbatim: name).font(Typeface.display(.body)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 8).frame(minHeight: 26)
                    .background(Capsule().fill(accent.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(accent.opacity(0.4), lineWidth: 1))
                    .fixedSize()
            }
            if names.count > shown {
                Text(verbatim: "+\(names.count - shown)").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft).fixedSize()
            }
        }
    }

    // MARK: The featured card's light

    /// The stage behind the title and its details, solid under the words (and denser with Reduce Transparency) and
    /// fading in over `fade` points above them, so the text keeps its contrast over any sleeve's colours. It runs out
    /// to the card's edges.
    private func heroScrim(fade: CGFloat) -> some View {
        let tone = Palette.stage.opacity(reduceTransparency ? 0.8 : 0.55)
        return VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), tone], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
            Rectangle().fill(tone)
        }
        .padding(.top, -fade)
        .padding(.horizontal, -Metrics.cardPadding)
        .padding(.bottom, -Metrics.cardPadding)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

    /// The sleeve's colours as a slow mesh of light (smooth at any width, where a blur of the sleeve smudged on
    /// iPad), darkening toward the title: toward the foot, and on iPhone, where the title sits beside the sleeve, also
    /// toward the leading edge.
    private func heroBackdrop(_ art: CoverArt) -> some View {
        ZStack {
            art.far
            CoverMesh(art: art)
            RadialGradient(colors: [art.primary.opacity(0.22), .clear], center: UnitPoint(x: 0.82, y: 0.18), startRadius: 4, endRadius: 320)
                .blendMode(.screen)
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.32), .black.opacity(0.84)], startPoint: .top, endPoint: .bottom)
            if sizeClass != .regular {
                LinearGradient(colors: [.black.opacity(reduceTransparency ? 0.6 : 0.42), .black.opacity(0)],
                               startPoint: .leading, endPoint: UnitPoint(x: 0.66, y: 0.5))
            }
        }
    }

    /// "Song of the day": the app's display eyebrow in ink, on a dark plate over the art. Its waveform moves only while
    /// the opening plays (motion means live).
    private func heroEyebrow(accent: Color, playing: Bool, identity: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform").font(Typeface.eyebrowDisplay).foregroundStyle(accent)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: playing && !reduceMotion)
            Eyebrow("Song of the day", color: Palette.ink, style: .display)
                .accessibilityIdentifier(identity)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.4)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    /// The details in the app's inks (on `heroScrim`), not white at partial opacity over the art: the title (unless
    /// it sits beside the sleeve, `compact`), the course and length, how hard the song is and its chords, and Play.
    /// `compact` (iPhone) puts the chords on Play's row, at its end, to keep the card short.
    private func heroText(_ song: Song, accent: Color, access: LessonAccess, stars: Int, compact: Bool) -> some View {
        let sheet = SongSheet.of(song.lesson)
        return VStack(alignment: .leading, spacing: compact ? 10 : 8) {
            if !compact { heroTitle(song, lines: 2) }
            HStack(spacing: 6) {
                CourseArt(course: song.course, size: 18)
                Text(song.course.title.localized).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("songs.hero.\(song.id).course")
                // How long the song runs (not the lesson's minutes, which the song sheet gives beside it), as the rows
                // up next say it: "Originals · 2:40 · +30 XP"; Calm mode leaves the XP out.
                if store.settings.calmMode {
                    Text(verbatim: "· \(sheet.length)").foregroundStyle(Palette.inkSoft)
                        .accessibilityIdentifier("songs.hero.\(song.id).metadata")
                } else {
                    (Text(verbatim: "· \(sheet.length) · ") + Text("+\(song.lesson.xp) XP")).foregroundStyle(Palette.inkSoft)
                        .accessibilityIdentifier("songs.hero.\(song.id).metadata")
                }
            }
            .font(.subheadline).lineLimit(1)
            if compact {
                HStack(spacing: 10) {
                    heroButton(access, finished: stars > 0, identity: "songs.hero.\(song.id).play.title").fixedSize()
                    if stars > 0 { StarRow(stars: stars, size: 13) }
                    if access == .pro { ProBadge() }
                    Spacer(minLength: 4)
                    // Offered the rest of the row first, so it shows as many chords as fit there.
                    heroNeeds(song, sheet: sheet, accent: accent).layoutPriority(1)
                }
            } else {
                heroNeeds(song, sheet: sheet, accent: accent)
                HStack(spacing: 12) {
                    heroButton(access, finished: stars > 0, identity: "songs.hero.\(song.id).play.title")
                    if stars > 0 { StarRow(stars: stars, size: 13) }
                    Spacer(minLength: 0)
                    if access == .pro { ProBadge() }
                }
                .padding(.top, 6)
            }
        }
    }

    /// What the song asks for, at a glance: how hard it is and its chords (its key, for a melody).
    private func heroNeeds(_ song: Song, sheet: SongSheet, accent: Color) -> some View {
        HStack(spacing: 8) {
            DifficultyDots(level: sheet.difficulty(unit: song.unitIndex, of: song.course.units.count), tint: Palette.ink)
            ChordChips(chords: sheet.chords, key: sheet.keyName, tint: accent, identity: "songs.hero.\(song.id).chords", limit: 5)
        }
    }

    /// Play, drawn as the app's primary button: mint whatever the sleeve's colours (its label font, a capsule at least
    /// 44 pt tall, flat at rest). It is part of the hero's own button, so it is a look, not a second button.
    private func heroButton(_ access: LessonAccess, finished: Bool, identity: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: access == .play ? "play.fill" : "lock.fill")
            Text(finished ? LocalizedStringKey("Play again") : LocalizedStringKey("Play"))
                .accessibilityIdentifier(identity)
        }
        .font(Typeface.button).foregroundStyle(Palette.onAccent)
        .padding(.horizontal, 18).padding(.vertical, 8)
        .frame(minHeight: Metrics.minTarget)
        .background(Capsule().fill(Palette.mint))
    }

    // MARK: Shelves

    @ViewBuilder private func shelfItem(_ item: ShelfItem) -> some View {
        switch item {
        case .pick(let pick): pickShelf(pick)
        case .rail(let rail): shelfView(rail.shelf, rail: rail.songs)
        }
    }

    /// A course's songs: the stars count every one of them, the rail shows `rail` (all of them, numbered in order).
    private func shelfView(_ shelf: Shelf, rail: [Song]) -> some View {
        let progress = store.learn
        let earned = shelf.songs.reduce(0) { $0 + (progress.stars[$1.lesson.id] ?? 0) }
        // The rail opens on the next song to play in it.
        let next = rail.first { !progress.isFinished($0.lesson.id) && catalog.standing($0).access == .play }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                CourseArt(course: shelf.course, size: 32)
                SectionHeader(Text(shelf.course.title.localized)) {
                    Label { Text.fraction(earned, shelf.songs.count * 3) } icon: { Image(systemName: "star.fill") }
                        .font(Typeface.number(.caption)).foregroundStyle(Palette.starGold)
                }
            }
            SongShelfRail(items: rail, selection: next?.id, itemWidth: tileWidth,
                          height: railHeight(rail), identity: "songs.rail." + shelf.id) { song in
                tile(song)
            }
        }
    }

    /// A picked shelf: its reason as the header, then its songs' tiles (each zooming from this shelf's own tile).
    private func pickShelf(_ pick: Pick) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Glyph(pick.symbol, size: Glyph.lead)
                // Wraps rather than shrinking a long reason ("Because you learned E minor").
                SectionHeader(pick.title)
            }
            SongShelfRail(items: pick.songs, selection: nil, itemWidth: tileWidth,
                          height: railHeight(pick.songs), identity: "songs.rail." + pick.id) { song in
                tile(song, shelf: pick.id)
            }
        }
    }

    /// Preserve the eager row's maximum natural caption height without keeping offscreen card trees alive.
    /// Every geometry-affecting caption input is in the signature, including localized fallback text and versions.
    private func railHeight(_ songs: [Song]) -> CGFloat {
        let content = songs.flatMap { song -> [String] in
            let sheet = SongSheet.of(song.lesson)
            let standing = catalog.standing(song)
            let versions = Self.otherCourses(catalog.versions(of: song))
            return [song.id, song.lesson.title.localized, String(describing: standing.access),
                    standing.gate?.id ?? "", standing.gate?.title.localized ?? "",
                    String(store.learn.stars[song.id] ?? 0), String(song.lesson.xp), sheet.length,
                    sheet.keyName ?? "", String(versionLimit), String(store.settings.calmMode),
                    String(sheet.chords.count), String(versions.count)]
                + sheet.chords.map(\.name) + versions.map(\.id)
        }
        let key = SongRailMeasurement.Key(content: content, width: tileWidth, locale: locale.identifier,
                                         language: TimbreLocalization.language, typeSize: typeSize, direction: direction,
                                         legibility: legibility, bold: Typeface.boldText, scale: displayScale)
        let captionHeight = railMeasurement.maximum(key: key, count: songs.count) { index in
            let song = songs[index]
            Self.tileCaption(song, sheet: SongSheet.of(song.lesson), accent: Palette.accent(song.course.accent),
                        standing: catalog.standing(song), stars: store.learn.stars[song.id] ?? 0,
                        calm: store.settings.calmMode, versionLimit: versionLimit,
                        others: Self.otherCourses(catalog.versions(of: song)), identity: Self.tileSource(song.lesson))
                .environmentObject(store)
        }
        return tileWidth + Self.captionGap + captionHeight
    }

    /// `shelf` names a picked shelf; nil is the song's own course shelf. Every tile has the same grid, its controls
    /// outside the tile's own button: "Hear it" in the sleeve's play corner (bottom-right, which every sleeve's type
    /// keeps clear, its number top-left), and the tune's other versions under the sleeve, beside its chords.
    private func tile(_ song: Song, shelf: String? = nil) -> some View {
        let standing = catalog.standing(song)
        let access = standing.access
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let accent = Palette.accent(song.course.accent)
        let sheet = SongSheet.of(song.lesson)
        let art = catalog.art(song)
        let source = Self.tileSource(song.lesson, shelf: shelf)
        let versions = catalog.versions(of: song)
        let others = Self.otherCourses(versions)
        let shrink: CGFloat = reduceMotion ? 0 : 0.08
        return Button { open(song.course, song.lesson, from: source) } label: {
            VStack(alignment: .leading, spacing: Self.captionGap) {
                tileCover(song, art: art, access: access)
                Self.tileCaption(song, sheet: sheet, accent: accent, standing: standing, stars: stars,
                                 calm: store.settings.calmMode, versionLimit: versionLimit, others: others, identity: source)
            }
            .frame(width: tileWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(verbatim: "\(song.lesson.title.localized), \(song.course.title.localized)"))
        .accessibilityValue(tileValue(song, sheet: sheet, standing: standing))
        .accessibilityIdentifier(shelf.map { "songs.\($0).\(song.id)" } ?? "songs.song.\(song.id)")
        .overlay(alignment: .top) {
            Color.clear
                .frame(width: tileWidth, height: tileWidth)
                .allowsHitTesting(false)
                .overlay(alignment: .bottomTrailing) {
                    // A Pro song wears the gold lock the tool tiles wear, above "Hear it" in the play corner that the
                    // sleeve's type keeps clear.
                    VStack(alignment: .trailing, spacing: 0) {
                        if access == .pro { ProLock(size: 22).padding(.trailing, 15).allowsHitTesting(false).accessibilityHidden(true) }
                        sampleButton(song, art: art)
                    }
                }
        }
        .overlay(alignment: .topTrailing) {
            if !others.isEmpty {
                // Over the room the caption keeps for it (`tileCaption`): its 44-point tap area centred on that row.
                versionsMenu(song, versions: versions, courses: others, source: source)
                    .padding(.top, tileWidth + Self.captionGap - (Metrics.minTarget - VersionBadges.height) / 2)
            }
        }
        .matchedTransitionSource(id: source, in: zoom)
        .modifier(Shake(amount: shakes[song.id] ?? 0))
        // Sleeves ease back and dim as they slide off the rail's edge.
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content.scaleEffect(1 - shrink * CGFloat(abs(phase.value))).opacity(1 - 0.35 * abs(phase.value))
        }
        // The rail centres its items: lined up by their tops instead, the sleeves stay level when one caption runs
        // to two lines (a lock plate's "Finish …").
        .alignmentGuide(VerticalAlignment.center) { dimensions in dimensions[.top] }
    }

    /// The courses of a tune's other versions (`versions` without the song itself), once each; empty for a tune only
    /// one course teaches.
    private static func otherCourses(_ versions: [Song]) -> [LearnCourse] {
        var courses: [LearnCourse] = []
        for version in versions.dropFirst() where !courses.contains(where: { $0.id == version.course.id }) {
            courses.append(version.course)
        }
        return courses
    }

    /// The tune's other versions as small badges of their `courses`' art; a tap lists every version, this one first and
    /// then the learner's instrument's, to choose which to play.
    private func versionsMenu(_ song: Song, versions: [Song], courses: [LearnCourse], source: String) -> some View {
        let names = courses.map { $0.title.localized }.joined(separator: ", ")
        return Menu {
            Section {
                ForEach(versions) { version in
                    Button { open(version.course, version.lesson, from: source) } label: { versionLabel(version) }
                        .accessibilityIdentifier(source + ".version." + version.id)
                }
            } header: {
                Text(verbatim: CoverArt.mainTitle(song.lesson.title.localized))
            }
        } label: {
            VersionBadges(courses: courses, limit: versionLimit, identity: source + ".versions")
                // The pill as the caption keeps room for it, in a 44-point tap area.
                .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(PressScaleStyle())
        .menuOrder(.fixed)
        // The badges stop growing at xxLarge: a long press shows the control magnified instead.
        .accessibilityShowsLargeContentViewer { Label("Versions", systemImage: "square.stack") }
        .accessibilityLabel(Text("Versions"))
        .accessibilityValue(Text(verbatim: names))
        .accessibilityIdentifier("songs.versions.\(song.id)")
    }

    /// A version in the list: its course (and its part, "Guitar · The chords"), then where it stands.
    private func versionLabel(_ version: Song) -> some View {
        let course = version.course.title.localized
        let name = Self.subtitle(version.lesson.title.localized).map { "\(course) · \($0)" } ?? course
        return Label {
            Text(verbatim: name)
            versionDetail(version)
        } icon: {
            Image(systemName: version.course.symbol)
        }
    }

    /// Pro, or the lesson to finish first, for a version that doesn't play yet; else its stars, or how long it runs.
    private func versionDetail(_ version: Song) -> Text {
        let standing = catalog.standing(version)
        let stars = store.learn.stars[version.lesson.id] ?? 0
        switch standing.access {
        case .pro: return Text("Timbre Pro")
        case .locked:
            guard let gate = standing.gate else { return Text("Locked") }
            return Text("Finish \(gate.title.localized)")
        case .play:
            return stars > 0 ? Text("\(stars) of 3 stars") : Text(verbatim: SongSheet.of(version.lesson).length)
        }
    }

    /// Twenty seconds of the song (over the band), from any sleeve.
    private func sampleButton(_ song: Song, art: CoverArt) -> some View {
        PreviewDisc(active: previewing == song.id, ring: art.primary.mix(with: .black, by: 0.25),
                    start: previewStart, length: previewLength, side: 32) {
            togglePreview(song, full: true)
        }
        .padding(4)
        .accessibilityLabel(previewing == song.id ? Text("Stop") : Text("Hear it"))
        .accessibilityValue(Text(verbatim: song.lesson.title.localized))
        .accessibilityIdentifier("songs.sample.\(song.id)")
    }

    /// Under the sleeve, which already carries the title: the lesson to finish first for a song further on in its
    /// course ("Finish Kite Weather"; a Pro song says so with the lock on its sleeve instead); else the part of the
    /// title it leaves off ("The chords"), else the song's chords ("G D Em C"; its key for a melody), with room at the
    /// end for the tune's other versions (`others`, drawn over it by `tile`); then how hard it is, how long it runs and
    /// its XP (its stars, once it has some).
    static func tileCaption(_ song: Song, sheet: SongSheet, accent: Color, standing: SongsCatalog.Standing, stars: Int,
                            calm: Bool, versionLimit: Int, others: [LearnCourse], identity: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 6) {
                Group {
                    if standing.access == .locked {
                        LockReason(access: standing.access, gate: standing.gate)
                    } else if let subtitle = Self.subtitle(song.lesson.title.localized) {
                        Text(verbatim: subtitle).font(Typeface.label(.footnote)).foregroundStyle(Palette.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        ChordChips(chords: sheet.chords, key: sheet.keyName, tint: accent, identity: identity + ".chords")
                    }
                }
                // At least a plate's height, so captions line up; a two-line plate or larger text grows it.
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                if !others.isEmpty {
                    // The versions menu's own pill, held in place here so the chords make room for it.
                    VersionBadges(courses: others, limit: versionLimit, identity: identity + ".versions.placeholder").hidden()
                }
            }
            HStack(spacing: 7) {
                DifficultyDots(level: sheet.difficulty(unit: song.unitIndex, of: song.course.units.count), tint: accent)
                Text(verbatim: sheet.length).font(Typeface.number(.caption)).foregroundStyle(Palette.inkSoft)
                    .accessibilityIdentifier(identity + ".duration")
                if stars > 0 {
                    StarRow(stars: stars, size: 10)
                } else if !calm {
                    Text("+\(song.lesson.xp) XP").font(.footnote).foregroundStyle(Palette.inkSoft)
                        .accessibilityIdentifier(identity + ".xp")
                }
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

    /// Open, Pro or locked (and why), or the stars, how hard, and the chords, for VoiceOver.
    private func tileValue(_ song: Song, sheet: SongSheet, standing: SongsCatalog.Standing) -> Text {
        let stars = store.learn.stars[song.lesson.id] ?? 0
        let level = sheet.difficulty(unit: song.unitIndex, of: song.course.units.count)
        var value = accessValue(standing.access, stars: stars)
        if standing.access == .locked, let gate = standing.gate {
            value = value + Text(verbatim: ", ") + Text("Finish \(gate.title.localized)")
        }
        value = value + Text(verbatim: ", ") + Text(DifficultyDots.name(level))
        if !sheet.chords.isEmpty { value = value + Text(verbatim: ", " + sheet.chords.map(\.name).joined(separator: " ")) }
        return value
    }

    /// The sleeve with its state: songs that play show, once played, a bar along the foot filled to the best accuracy
    /// (their stars are in the caption); songs that don't play yet, Pro or further on alike, calm under the same muted
    /// colour (the type stays crisp) and say why underneath. Every sleeve wears "Hear it" in its play corner (`tile`).
    private func tileCover(_ song: Song, art: CoverArt, access: LessonAccess) -> some View {
        let best = access == .play ? store.learn.bestAccuracy[song.lesson.id] : nil
        return SongCover(art: art, locked: access != .play)
            .frame(width: tileWidth, height: tileWidth)
            .overlay(alignment: .bottom) { if let best { progressBar(best) } }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
    }

    /// How much of the song has landed (its best accuracy), as a bar along the sleeve's foot, stopping short of the
    /// play corner.
    private func progressBar(_ best: Double) -> some View {
        let share = CGFloat(min(1, max(0, best)))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.45))
                Capsule().fill(Palette.mint)
                    .frame(width: max(4, proxy.size.width * share))
            }
        }
        .frame(height: 4)
        .padding(.leading, 10).padding(.trailing, tileWidth * CoverArt.playCorner).padding(.bottom, 5)
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
                        .background(Circle().fill(Palette.mint))
                        .accessibilityHidden(true)
                }
                .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
                .frame(minHeight: Metrics.minTarget)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
            .transition(.adaptive(.move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
            .accessibilityIdentifier("songs.hint")
            .task(id: hint) {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.settle) { self.hint = nil }
            }
        }
    }
}

// MARK: - The catalogue, worked out once per change

/// The Songs tab's songs and where each one stands. The catalogue, its filter chips and its sleeves are read once
/// from the curriculum; each song's access (and, for one further on in its course, the open lesson on the way to it)
/// once per change of the learner's progress, Pro, level or day; each filter's featured song, picked shelves and
/// course shelves once per such change too. Bodies then only look things up, so a settings save, the reward pulse or
/// a slider step elsewhere in the app no longer re-runs some hundred access checks, sorts and lesson scans.
@MainActor final class SongsCatalog {
    struct Standing {
        let access: LessonAccess
        /// For a song further on in its course: the open lesson to finish on the way to it.
        let gate: Lesson?
    }

    /// A course shelf and the songs its rail shows (every one, the featured song included).
    struct Rail: Identifiable {
        let shelf: SongsView.Shelf
        let songs: [SongsView.Song]
        var id: String { shelf.id }
    }

    struct Layout {
        let hero: SongsView.Song?
        /// The picked shelves at the top: the adult repertoire.
        let picks: [SongsView.Pick]
        let rails: [Rail]
        /// "Campfire & kids", lower down: after the first `lowerAfter` rails (the song collections').
        var lower: SongsView.Pick? = nil
        var lowerAfter = 0
    }

    private struct Key: Equatable {
        let learn: LearnProgress
        let pro: Bool
        let level: Int
        let day: Int
        /// Effective grants, rather than raw config: expiry and same-day config edits both change this snapshot.
        let freeLessons: Set<String>
        let unit2Free: Bool
        /// The instrument the learner plays (`home`): a tune shows its version for it first.
        let home: String?
    }

    private var built = false
    private var songs: [SongsView.Song] = []
    /// Every song by its tune (`tuneKey`), in curriculum order: Ode to Joy on guitar, ukulele, violin… and in Songs.
    private var tunes: [String: [SongsView.Song]] = [:]
    private var chipList: [SongsView.Chip] = []
    private var arts: [String: CoverArt] = [:]
    private var key: Key?
    private var standings: [String: Standing] = [:]
    private var layouts: [String: Layout] = [:]

    // MARK: Lookups

    func chips(_ store: AppStore) -> [SongsView.Chip] {
        build(store.curriculum)
        return chipList
    }

    /// `course` is the learner's Learn course (`learn.course`), which names the instrument they play.
    func layout(filter: String, course: String, store: AppStore, now: Date = Date()) -> Layout {
        refresh(store, home: Self.home(course: course, store: store), now: now)
        if let known = layouts[filter] { return known }
        let made = makeLayout(filter: filter, store: store, now: now)
        layouts[filter] = made
        return made
    }

    func standing(_ song: SongsView.Song) -> Standing {
        standings[song.id] ?? Standing(access: .locked, gate: nil)
    }

    /// The song's sleeve, its motif as its course deals it.
    func art(_ song: SongsView.Song) -> CoverArt {
        if let known = arts[song.id] { return known }
        let made = CoverArt(song)
        arts[song.id] = made
        return made
    }

    /// Every version of the song's tune, the song itself first, then the rest with the learner's instrument ahead of
    /// the others, in curriculum order. Just the song when no other course has its tune.
    func versions(of song: SongsView.Song) -> [SongsView.Song] {
        let all = tunes[Self.tuneKey(song.lesson)] ?? []
        guard all.count > 1 else { return [song] }
        let home = key?.home
        let others = all.filter { $0.id != song.id }
        let own = others.filter { home != nil && $0.course.instrument == home }
        let rest = others.filter { !(home != nil && $0.course.instrument == home) }
        return [song] + own + rest
    }

    /// A tune's key: its main title in English, letters and digits only ("Greensleeves: the chords" and
    /// "Greensleeves" are one tune; "Brahms' Lullaby" matches however its apostrophe is typed).
    static func tuneKey(_ lesson: Lesson) -> String {
        String(CoverArt.mainTitle(lesson.title.defaultValue).lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The instrument the learner plays: their Learn course's ("guitar.acoustic.6"; Songs and Originals are guitar);
    /// for a course without one (theory, ear, rhythm), the course of the tuner's instrument family.
    static func home(course id: String, store: AppStore) -> String? {
        if let own = store.curriculum.course(id: id)?.instrument { return own }
        let family = Self.family(store.instrument.id)
        return store.curriculum.courses.first { $0.instrument.map(Self.family) == family }?.instrument
    }

    private static func family(_ instrumentId: String) -> String {
        instrumentId.split(separator: ".").first.map(String.init) ?? instrumentId
    }

    // MARK: Building

    private func build(_ curriculum: Curriculum) {
        guard !built else { return }
        built = true
        var found: [SongsView.Song] = []
        for course in curriculum.courses {
            var number = 0
            for (index, unit) in course.units.enumerated() {
                for lesson in unit.lessons where lesson.kind == .song {
                    number += 1
                    found.append(SongsView.Song(course: course, unit: unit, unitIndex: index, lesson: lesson, number: number))
                }
            }
        }
        songs = found
        for song in found { tunes[Self.tuneKey(song.lesson), default: []].append(song) }
        // One chip per instrument that has songs, named after its own course (Guitar, Ukulele, Singing…).
        var seen = Set<String>()
        for course in curriculum.courses {
            guard let instrument = course.instrument, !seen.contains(instrument),
                  course.lessons.contains(where: { $0.kind == .song }) else { continue }
            seen.insert(instrument)
            let candidates = curriculum.courses.filter { $0.instrument == instrument }
            let own = candidates.first { !Self.isCollection($0) } ?? course
            chipList.append(SongsView.Chip(id: instrument, title: own.title.localized, course: own))
        }
    }

    private func refresh(_ store: AppStore, home: String?, now: Date) {
        build(store.curriculum)
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        let openings = RemoteConfig.shared.freeOpenings
        let next = Key(learn: store.learn, pro: store.isPro, level: store.level.number, day: day,
                       freeLessons: openings.lessons, unit2Free: openings.unit2, home: home)
        guard next != key else { return }
        key = next
        layouts = [:]
        var made: [String: Standing] = [:]
        for song in songs {
            let access = LessonAccess.of(song.lesson, in: song.course, store: store)
            let gate = access == .locked ? Self.gate(song.lesson, in: song.course, progress: next.learn) : nil
            made[song.id] = Standing(access: access, gate: gate)
        }
        standings = made
    }

    /// The nearest open, unfinished lesson before `lesson` in its course: finishing it moves toward the song.
    static func gate(_ lesson: Lesson, in course: LearnCourse, progress: LearnProgress) -> Lesson? {
        guard let position = course.position(of: lesson.id) else { return nil }
        return course.lessons[..<position].last { progress.isUnlocked($0, in: course) && !progress.isFinished($0.id) }
    }

    // MARK: Layout

    private func makeLayout(filter: String, store: AppStore, now: Date) -> Layout {
        let pool = songs.filter { Self.matches($0, filter: filter) }
        let hero = featured(pool, store: store)
        // A tune shows on a picked shelf as one sleeve: the filter's instrument's version, else the learner's.
        let prefer = filter == SongsView.all ? key?.home : filter
        let picks = self.picks(pool, hero: hero, prefer: prefer, store: store, now: now)
        var rails: [Rail] = []
        // Every course shelf keeps all its songs, the featured one included: its sleeves are numbered in course order
        // (01, 02, 03…), and a song lifted out for the hero left a hole in the count (01, 02, 03, 04, 06).
        for shelf in shelves(pool, curriculum: store.curriculum) where !shelf.songs.isEmpty {
            rails.append(Rail(shelf: shelf, songs: shelf.songs))
        }
        // The rails come in rank order: the song collections' (Originals, Standards, Songs) first.
        let collections = rails.filter { Self.rank($0.shelf.course) < 3 }.count
        return Layout(hero: hero, picks: picks, rails: rails, lower: campfire(pool, hero: hero, prefer: prefer), lowerAfter: collections)
    }

    /// Songs for any instrument (a course without one) show under every filter.
    private static func matches(_ song: SongsView.Song, filter: String) -> Bool {
        filter == SongsView.all || song.course.instrument == nil || song.course.instrument == filter
    }

    /// A course that is mostly songs (Songs, Originals) rather than an instrument's path.
    static func isCollection(_ course: LearnCourse) -> Bool {
        course.lessons.filter { $0.kind == .song }.count * 2 >= course.lessons.count
    }

    static func isOriginals(_ course: LearnCourse) -> Bool { SongOfTheDay.isOriginals(course) }

    static func isStandards(_ course: LearnCourse) -> Bool { SongOfTheDay.isStandards(course) }

    /// A nursery rhyme, children's song or campfire round (`SongOfTheDay.isCampfireOrKids`), by its English title.
    static func isKids(_ song: SongsView.Song) -> Bool { SongOfTheDay.isCampfireOrKids(song.lesson.title.defaultValue) }

    /// Adult-first: the Originals, then the Standards, then the other song collections (Songs, which opens on its
    /// first nursery rhymes), then each instrument's songs in curriculum order.
    private static func rank(_ course: LearnCourse) -> Int {
        if isOriginals(course) { return 0 }
        if isStandards(course) { return 1 }
        return isCollection(course) ? 2 : 3
    }

    private func shelves(_ songs: [SongsView.Song], curriculum: Curriculum) -> [SongsView.Shelf] {
        var found: [SongsView.Shelf] = []
        for course in curriculum.courses {
            let items = songs.filter { $0.course.id == course.id }
            if !items.isEmpty { found.append(SongsView.Shelf(course: course, songs: items)) }
        }
        let ranked = found.enumerated().sorted { a, b in
            let left = Self.rank(a.element.course), right = Self.rank(b.element.course)
            return left != right ? left < right : a.offset < b.offset
        }
        return ranked.map { $0.element }
    }

    /// The song of the day (`SongOfTheDay`): an unfinished song at the learner's level, adult-first (the Originals
    /// and the Standards ahead of the other tunes, nursery rhymes after them), an Original ahead of the traditional
    /// tunes once past the beginner units, the same all day.
    private func featured(_ songs: [SongsView.Song], store: AppStore) -> SongsView.Song? {
        let progress = key?.learn ?? store.learn
        let candidates = songs.map { song in
            SongOfTheDay.Candidate(song: song.lesson, in: song.course, unit: song.unitIndex,
                                   finished: progress.isFinished(song.lesson.id), access: dayAccess(song, progress: progress))
        }
        let placed = progress.placedThrough.values.contains { $0 >= 0 }
        guard let id = SongOfTheDay.pick(candidates, level: key?.level ?? store.level.number, finishedLessons: progress.stars.count,
                                         placed: placed, day: key?.day ?? 0) else { return nil }
        return songs.first { $0.id == id }
    }

    /// Learn's access, with Pro songs split into the next one in order (worth featuring) and later ones.
    private func dayAccess(_ song: SongsView.Song, progress: LearnProgress) -> SongOfTheDay.Access {
        switch standing(song).access {
        case .play: return .open
        case .pro: return progress.isUnlocked(song.lesson, in: song.course) ? .pro : .locked
        case .locked: return .locked
        }
    }

    /// First the songs people know (`SongOfTheDay.songsYouKnow`, in that order) and, from late November to Twelfth
    /// Night, the carols (named "free this week" while the remote config opens them, `RemoteConfig.freeSongs`). Then,
    /// from the songs under the filter (the featured song's tune and the nursery rhymes aside, which have their own
    /// shelf further down, `campfire`): songs not played yet that use the chord the learner learned last ("Because you
    /// learned E minor"), then every song of one to three chords. Each tune shows once, in its `prefer` instrument's
    /// version where it has one (its other versions are a tap away on the sleeve). Songs that play now come first,
    /// the Originals and the Standards ahead of the other tunes, the easiest of each first (`adultFirst`); each motif
    /// shows once on a shelf, never the featured sleeve's nor one the shelf above opens on (`distinct`).
    private func picks(_ songs: [SongsView.Song], hero: SongsView.Song?, prefer: String?, store: AppStore, now: Date) -> [SongsView.Pick] {
        let progress = key?.learn ?? store.learn
        let heroTune = hero.map { Self.tuneKey($0.lesson) }
        let pool = songs.filter { Self.tuneKey($0.lesson) != heroTune && !Self.isKids($0) }
        var above = Set<CoverArt.Motif>()
        if let hero { above.insert(art(hero).motif) }
        var out: [SongsView.Pick] = []
        // First, the tunes everyone knows, in their fixed order (Ode to Joy, Amazing Grace, Silent Night…), and in
        // carol season the carols: shelves of titles, not of motifs, so neither leaves a song out for its sleeve.
        if let known = ordered(songs, by: SongOfTheDay.songsYouKnow, prefer: prefer, limit: 12) {
            out.append(SongsView.Pick(id: "known", symbol: "heart.fill", title: Text("Songs you know"), songs: known))
            above.formUnion(known.prefix(3).map { art($0).motif })
        }
        if SongOfTheDay.isCarolSeason(now), let carols = ordered(songs, by: SongOfTheDay.carols, prefer: prefer, limit: 17) {
            let free = key?.freeLessons ?? []
            let title = carols.contains { free.contains($0.id) } ? Text("Carols, free this week") : Text("Carols")
            out.append(SongsView.Pick(id: "carols", symbol: "snowflake", title: title, songs: carols))
        }
        if let chord = lastLearnedChord(progress, curriculum: store.curriculum) {
            // Not played yet in any version.
            let played = Set(songs.filter { progress.isFinished($0.lesson.id) }.map { Self.tuneKey($0.lesson) })
            let using = pool.filter { song in
                !played.contains(Self.tuneKey(song.lesson)) && SongSheet.of(song.lesson).chords.contains { $0.symbol == chord.symbol }
            }
            let shelf = distinct(adultFirst(onePerTune(using, prefer: prefer)), avoiding: above, limit: 10)
            if !shelf.isEmpty {
                out.append(SongsView.Pick(id: "because", symbol: "sparkles", title: Text("Because you learned \(SongSheet.spoken(chord))"),
                                          songs: shelf))
                above.formUnion(shelf.prefix(3).map { art($0).motif })
            }
        }
        let few = onePerTune(pool.filter { (1...3).contains(SongSheet.of($0.lesson).chords.count) }, prefer: prefer)
        let shelf = distinct(adultFirst(few), avoiding: above, limit: 12)
        if shelf.count >= 2 {
            out.append(SongsView.Pick(id: "few", symbol: "3.circle.fill", title: Text("3 chords or fewer"), songs: shelf))
        }
        return out
    }

    /// "Campfire & kids", below the adult repertoire: the nursery rhymes, children's songs and campfire rounds under
    /// the filter (`isKids`), each tune once, songs that play now first and the easiest first, each motif once. Nil
    /// for fewer than two.
    private func campfire(_ songs: [SongsView.Song], hero: SongsView.Song?, prefer: String?) -> SongsView.Pick? {
        let heroTune = hero.map { Self.tuneKey($0.lesson) }
        let tunes = onePerTune(songs.filter { Self.isKids($0) && Self.tuneKey($0.lesson) != heroTune }, prefer: prefer)
        var avoiding = Set<CoverArt.Motif>()
        if let hero { avoiding.insert(art(hero).motif) }
        let shelf = distinct(easiestFirst(tunes), avoiding: avoiding, limit: 12)
        guard shelf.count >= 2 else { return nil }
        return SongsView.Pick(id: "campfire", symbol: "flame.fill", title: Text("Campfire & kids"), songs: shelf)
    }

    /// The songs of `tunes` (tune keys, in that order) under the filter, one version each (`onePerTune`), up to
    /// `limit`; nil for fewer than two.
    private func ordered(_ songs: [SongsView.Song], by tunes: [String], prefer: String?, limit: Int) -> [SongsView.Song]? {
        let wanted = Set(tunes)
        let found = onePerTune(songs.filter { wanted.contains(Self.tuneKey($0.lesson)) }, prefer: prefer)
        let place = Dictionary(uniqueKeysWithValues: tunes.enumerated().map { ($0.element, $0.offset) })
        let shelf = found.sorted { (place[Self.tuneKey($0.lesson)] ?? 0) < (place[Self.tuneKey($1.lesson)] ?? 0) }
        return shelf.count >= 2 ? Array(shelf.prefix(limit)) : nil
    }

    /// One song per tune, where its tune first comes: the version on `prefer` (the learner's instrument), then one
    /// that plays now, then the one with the most stars, then the first in curriculum order.
    private func onePerTune(_ songs: [SongsView.Song], prefer: String?) -> [SongsView.Song] {
        var chosen: [String: SongsView.Song] = [:]
        var order: [String] = []
        for song in songs {
            let tune = Self.tuneKey(song.lesson)
            guard let held = chosen[tune] else {
                chosen[tune] = song
                order.append(tune)
                continue
            }
            if rank(song, prefer: prefer).lexicographicallyPrecedes(rank(held, prefer: prefer)) { chosen[tune] = song }
        }
        return order.compactMap { chosen[$0] }
    }

    /// Lower ranks first: on the preferred instrument, then playable now, then more stars.
    private func rank(_ song: SongsView.Song, prefer: String?) -> [Int] {
        let own = prefer != nil && song.course.instrument == prefer ? 0 : 1
        let open = standing(song).access == .play ? 0 : 1
        let stars = key?.learn.stars[song.lesson.id] ?? 0
        return [own, open, 3 - stars]
    }

    /// The chord of the lesson finished most recently that taught one (a chord to play, or one on an explanation's card).
    private func lastLearnedChord(_ progress: LearnProgress, curriculum: Curriculum) -> ChordSpec? {
        let recent = progress.finishedDates.sorted { $0.value > $1.value }
        for entry in recent.prefix(40) {
            guard let found = curriculum.lesson(id: entry.key), let chord = Self.taughtChord(found.lesson) else { continue }
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
        let song: SongsView.Song
        let open: Bool
        let level: Int
        /// 0 for the Originals and the Standards, 1 for the other tunes.
        let repertoire: Int
    }

    private func ranked(_ songs: [SongsView.Song]) -> [Ranked] {
        songs.enumerated().map { item -> Ranked in
            let song = item.element
            let level = SongSheet.of(song.lesson).difficulty(unit: song.unitIndex, of: song.course.units.count)
            let adult = Self.isOriginals(song.course) || Self.isStandards(song.course)
            return Ranked(order: item.offset, song: song, open: standing(song).access == .play, level: level, repertoire: adult ? 0 : 1)
        }
    }

    /// Songs that play now first, the easiest of them first.
    private func easiestFirst(_ songs: [SongsView.Song]) -> [SongsView.Song] {
        let sorted = ranked(songs).sorted { a, b in
            if a.open != b.open { return a.open }
            if a.level != b.level { return a.level < b.level }
            return a.order < b.order
        }
        return sorted.map(\.song)
    }

    /// Songs that play now first; among them, and then among the rest, the Originals and the Standards ahead of the
    /// other tunes, the easiest of each first, so a shelf opens on the adult repertoire and stays beginner-friendly.
    private func adultFirst(_ songs: [SongsView.Song]) -> [SongsView.Song] {
        let sorted = ranked(songs).sorted { a, b in
            if a.open != b.open { return a.open }
            if a.repertoire != b.repertoire { return a.repertoire < b.repertoire }
            if a.level != b.level { return a.level < b.level }
            return a.order < b.order
        }
        return sorted.map(\.song)
    }

    /// `songs` in their order, up to `limit`, each sleeve's motif once and none of `avoiding` (the featured song's,
    /// those the shelf above opens on): a song that would repeat one is left to its course's shelf. When that leaves
    /// fewer than two (or than there are songs, for one), the order as it was with repeats moved last (`varied`).
    private func distinct(_ songs: [SongsView.Song], avoiding: Set<CoverArt.Motif>, limit: Int) -> [SongsView.Song] {
        var seen = avoiding
        var kept: [SongsView.Song] = []
        for song in songs where kept.count < limit {
            if seen.insert(art(song).motif).inserted { kept.append(song) }
        }
        if kept.count >= min(2, songs.count) { return kept }
        return Array(varied(songs).prefix(limit))
    }

    /// The same order, but a sleeve whose motif is already on the shelf waits until the end, so a shelf drawn from
    /// several courses doesn't show one motif twice where it can help it.
    private func varied(_ songs: [SongsView.Song]) -> [SongsView.Song] {
        var seen = Set<CoverArt.Motif>()
        var first: [SongsView.Song] = []
        var later: [SongsView.Song] = []
        for song in songs {
            if seen.insert(art(song).motif).inserted { first.append(song) } else { later.append(song) }
        }
        return first + later
    }
}

// MARK: - Sleeves

extension CoverArt {
    /// The title as shown sets the sleeve's type; colour and type follow the lesson id and its unit's genre, the
    /// motif its course's deal (`assignedMotif`).
    init(_ song: SongsView.Song) {
        self.init(id: song.lesson.id, title: song.lesson.title.localized, accent: song.course.accent,
                  genre: CoverArt.genre(unit: song.unit.title.defaultValue, instrument: song.course.instrument),
                  label: song.course.title.localized, number: song.number,
                  motif: CoverArt.assignedMotif(song.lesson.id, in: song.course))
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

// MARK: - Pieces

/// Play (or stop) on a sleeve: a white disc, and a ring that fills as the clip plays.
private struct PreviewDisc: View {
    let active: Bool
    let ring: Color
    let start: Date
    let length: Double
    var side: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.white.opacity(0.94))
                if active { progress }
                Image(systemName: active ? "stop.fill" : "play.fill")
                    .font(.system(size: side * 0.37, weight: .bold))
                    .foregroundStyle(Palette.stage)
                    .offset(x: active ? 0 : 1)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        // A fixed-size disc with no words: a long press shows what it does, magnified.
        .accessibilityShowsLargeContentViewer {
            Label { active ? Text("Stop") : Text("Hear it") } icon: { Image(systemName: active ? "stop.fill" : "play.fill") }
        }
        .accessibilityLabel(active ? Text("Stop") : Text("Hear it"))
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let fraction = length > 0 ? min(1, max(0, elapsed / length)) : 0
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(ring, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2.5)
        }
    }
}

/// Why a song doesn't play yet, the same plate on every shelf: a lock, then "Finish Kite Weather" (the open lesson
/// on the way to it) or "Timbre Pro" in gold. A long lesson name runs to a second line rather than being cut
/// ("Finish Mary Had a Littl…"); on one line the plate is a 24 pt capsule.
private struct LockReason: View {
    let access: LessonAccess
    let gate: Lesson?

    var body: some View {
        let pro = access == .pro
        // Half a one-line plate's height: a capsule on one line, a rounded plate on two.
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                .foregroundStyle(pro ? Palette.proGoldDeep : Palette.inkSoft)
            reason
                .font(Typeface.label(TypeStep.caption.points, relativeTo: .subheadline))
                .foregroundStyle(pro ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.ink.opacity(0.88)))
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(minHeight: 24)
        .background(shape.fill(pro ? Palette.proGoldDeep.opacity(0.1) : Color.white.opacity(0.06)))
        .overlay(shape.strokeBorder(pro ? Palette.proGoldDeep.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1))
    }

    private var reason: Text {
        if access == .pro { return Text("Timbre Pro") }
        if let gate { return Text("Finish \(gate.title.localized)") }
        return Text("Locked")
    }
}

/// A song's chords as small chips ("G" "D" "Em" "C"), as many as fit, "+2" for the rest; its key for a song
/// without chords. VoiceOver reads them with the tile.
private struct ChordChips: View {
    let chords: [ChordSpec]
    let key: String?
    let tint: Color
    let identity: String
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
            ForEach(chords.prefix(shown), id: \.symbol) { chord in chip(chord.name, symbol: chord.symbol) }
            if chords.count > shown {
                Text(verbatim: "+\(chords.count - shown)").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft).fixedSize()
                    .accessibilityIdentifier(identity + ".more")
            }
        }
    }

    private func chip(_ name: String, symbol: String) -> some View {
        Text(verbatim: name).font(Typeface.label(.caption)).foregroundStyle(Palette.ink)
            .accessibilityIdentifier(identity + ".chord." + symbol)
            .padding(.horizontal, 7).frame(minHeight: 22)
            .background(Capsule().fill(tint.opacity(0.16)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
            .fixedSize()
    }

    private func keyLabel(_ key: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "music.note").font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            Text(verbatim: key).font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
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

/// A tune's other versions under its sleeve, beside its chords: their courses' art overlapping on a pill as quiet as
/// a lock plate, "+2" past `limit`. The versions menu wraps it in a 44-point tap area; the caption holds its room
/// with a hidden copy, so both are exactly this size.
private struct VersionBadges: View {
    /// The pill's height: a chord chip's row.
    static let height: CGFloat = 24
    let courses: [LearnCourse]
    let limit: Int
    let identity: String

    var body: some View {
        let extra = courses.count - limit
        HStack(spacing: 2) {
            HStack(spacing: -6) {
                ForEach(Array(courses.prefix(limit))) { course in
                    CourseArt(course: course, size: 18)
                        .padding(1.5)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.stage))
                }
            }
            if extra > 0 {
                Text(verbatim: "+\(extra)").font(Typeface.label(.caption)).foregroundStyle(Palette.ink).fixedSize()
                    .accessibilityIdentifier(identity + ".more")
            }
        }
        .padding(.leading, 3).padding(.trailing, extra > 0 ? 6 : 3)
        .frame(height: Self.height)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .fixedSize()
    }
}

/// Three small stars, earned ones in the stars' gold.
private struct StarRow: View {
    let stars: Int
    var size: CGFloat = 10
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill").font(.system(size: size, weight: .bold)).foregroundStyle(i < stars ? Palette.starGold : .white.opacity(0.18))
            }
        }
        .accessibilityHidden(true)
    }
}
