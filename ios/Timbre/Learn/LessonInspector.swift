import SwiftUI
import TimbreCore

/// iPad: the lesson picked on Learn's path (the next one until another is picked), shown beside the path. Its card says
/// what it is (unit, kind, minutes, XP, stars; a song's sleeve) with Start, Continue or Play again (Timbre Pro for a Pro
/// lesson, the open lesson on the way for one not reached yet); then what's in it step by step, and a still preview of
/// what you'll play: its chords, its first picture, its notes on the neck or a staff, or its rhythm. `wide` sets the
/// card, its steps and `companion` (Learn's Today) in one column with the preview beside them, centred on that column;
/// otherwise everything stacks in one column.
struct LessonInspector<Companion: View>: View {
    let course: LearnCourse
    let lesson: Lesson
    /// The course's next lesson: its button says Continue, as the phone's Continue card does.
    let isNext: Bool
    let wide: Bool
    /// The Learn tab's zoom namespace and the source the lesson zooms out of.
    let zoom: Namespace.ID
    let source: String
    let onStart: () -> Void
    /// Picks another lesson on the path (the open one on the way to a lesson not reached yet).
    let onSelect: (Lesson) -> Void
    @ViewBuilder let companion: () -> Companion
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { Palette.accent(course.accent) }

    var body: some View {
        columns
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("learn.inspector")
    }

    @ViewBuilder private var columns: some View {
        if wide {
            // The card, its steps and the companion in one column; the preview beside them, centred on that column
            // and as tall as its drawing wants (a stage stretched to the column's height left a band of empty stage).
            HStack(alignment: .top, spacing: CardColumns.spacing) {
                VStack(alignment: .leading, spacing: CardColumns.spacing) {
                    handing(hero)
                    handing(steps)
                    companion()
                }
                .frame(maxWidth: .infinity, alignment: .top)
                handing(preview)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: CardColumns.spacing) {
                handing(hero)
                handing(preview)
                handing(steps)
                companion()
            }
        }
    }

    /// A card of the lesson's own: when another lesson is picked, the new card fades in a little from the side over the
    /// old one fading out (the two overlap rather than stack for the moment); just a cross-fade with Reduce Motion.
    /// The companion stays put.
    private func handing<Card: View>(_ card: Card) -> some View {
        let transition: AnyTransition = reduceMotion
            ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(x: 14)), removal: .opacity)
        return ZStack(alignment: .top) {
            card
                .id(lesson.id)
                .transition(transition)
        }
    }

    // MARK: State

    private var access: LessonAccess { LessonAccess.of(lesson, in: course, store: store) }

    private var unitPlace: (unit: LearnUnit, number: Int)? {
        guard let index = course.units.firstIndex(where: { $0.lessons.contains { $0.id == lesson.id } }) else { return nil }
        return (course.units[index], index + 1)
    }

    /// The open, unfinished lesson before this one: finishing it moves toward a lesson not reached yet.
    private var gate: Lesson? {
        guard let position = course.position(of: lesson.id) else { return nil }
        let progress = store.learn
        return course.lessons[..<position].last { progress.isUnlocked($0, in: course) && !progress.isFinished($0.id) }
    }

    // MARK: Card

    /// The lesson's card: its unit, title, kind, minutes and XP, stars once played, and the button; a song's sleeve
    /// (its record peeking out) or the course's instrument on the right. The lesson zooms out of it.
    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
        let stars = store.learn.stars[lesson.id] ?? 0
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if let place = unitPlace {
                    Eyebrow(Text("Unit \(place.number) · \(place.unit.title.localized)"), color: accent, style: .display)
                        .lineLimit(1)
                }
                Text(lesson.title.localized).font(Typeface.display(.title3)).tracking(-0.4).foregroundStyle(Palette.ink)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                meta(stars: stars)
                startButton(finished: stars > 0)
                    .padding(.top, 6)
            }
            Spacer(minLength: 4)
            heroArt
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
        .background(shape.fill(LinearGradient(colors: [accent.opacity(0.26), Palette.stageRaised], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(shape.strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .contentShape(shape)
        .matchedTransitionSource(id: source, in: zoom)
    }

    /// Kind, then "5 min · +25 XP", then the stars once the lesson has been played.
    private func meta(stars: Int) -> some View {
        HStack(spacing: 8) {
            kindChip
            Text("\(lesson.minutes) min · +\(lesson.xp) XP").font(.subheadline).foregroundStyle(Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
            if stars > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(index < stars ? Palette.amber : .white.opacity(0.18))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(stars) of 3 stars"))
            }
        }
    }

    private var kindChip: some View {
        let symbol: String
        let name: LocalizedStringKey
        switch lesson.kind {
        case .lesson: symbol = "graduationcap.fill"; name = "Lesson"
        case .song: symbol = "music.quarternote.3"; name = "Song"
        case .review: symbol = "arrow.clockwise"; name = "Review"
        case .challenge: symbol = "crown.fill"; name = "Challenge"
        }
        return HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold)).accessibilityHidden(true)
            Text(name)
        }
        .font(Typeface.label(.caption)).foregroundStyle(accent)
        .padding(.horizontal, 8).frame(minHeight: 22)
        .background(Capsule().fill(accent.opacity(0.14)))
        .overlay(Capsule().strokeBorder(accent.opacity(0.3), lineWidth: 1))
        .fixedSize()
    }

    /// Start (Continue on the next lesson once the course is under way, Play again once played); Timbre Pro in gold for
    /// a Pro lesson (the paywall); for a lesson not reached yet, the open lesson on the way to it, which it picks.
    @ViewBuilder private func startButton(finished: Bool) -> some View {
        switch access {
        case .play:
            let title: LocalizedStringKey = finished ? "Play again"
                : (isNext && store.learn.finishedCount(in: course) > 0 ? "Continue" : "Start")
            Button(action: onStart) {
                capsule(symbol: "play.fill", title: Text(title), ink: Palette.onAccent, fill: AnyShapeStyle(accent), glow: accent)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("learn.continue")
        case .pro:
            Button(action: onStart) {
                capsule(symbol: "lock.fill", title: Text("Timbre Pro"), ink: Palette.onAccent, fill: AnyShapeStyle(Palette.proGold), glow: Palette.amber)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("learn.continue")
        case .locked:
            if let gate {
                Button { onSelect(gate) } label: {
                    capsule(symbol: "lock.open.fill", title: Text("Next up: \(gate.title.localized)"), ink: Palette.ink,
                            fill: AnyShapeStyle(Palette.surface), glow: nil)
                        .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("learn.continue")
            } else {
                capsule(symbol: "lock.fill", title: Text("Locked"), ink: Palette.inkSoft, fill: AnyShapeStyle(Palette.surface), glow: nil)
                    .accessibilityIdentifier("learn.continue")
            }
        }
    }

    /// The primary button's type on a capsule at least 44 pt tall (it grows with the text), as Learn's Continue card.
    private func capsule(symbol: String, title: Text, ink: Color, fill: AnyShapeStyle, glow: Color?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).accessibilityHidden(true)
            title.lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(Typeface.button).foregroundStyle(ink)
        .padding(.horizontal, 18).frame(minHeight: Metrics.minTarget)
        .background(Capsule().fill(fill))
        .shadow(color: (glow ?? .clear).opacity(0.45), radius: 12, y: 4)
        .contentShape(Capsule())
    }

    @ViewBuilder private var heroArt: some View {
        if lesson.kind == .song {
            sleeve(side: wide ? 128 : 112)
        } else {
            CourseHeroArt(artwork: CourseArtwork.of(course, catalog: store.catalog), accent: accent, size: 120, lean: -12)
                .frame(width: 110, height: 170)
                .padding(.trailing, -10)
        }
    }

    /// A song's sleeve with its record half out, as on the Songs shelves.
    private func sleeve(side: CGFloat) -> some View {
        let art = CoverArt.of(lesson, in: course)
        return SongCover(art: art, corner: 8, locked: access != .play)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
            .background(alignment: .leading) {
                VinylRecord(color: art.primary, spinning: false)
                    .frame(width: side * 0.94, height: side * 0.94)
                    .offset(x: -side * 0.2)
            }
            .padding(.leading, side * 0.2)
    }

    // MARK: Steps

    /// "In this lesson": every step as a stop on a line, its kind's symbol, what it asks and (for playing steps) the
    /// notes, chord or tempo; lit once the lesson has been played.
    private var steps: some View {
        let played = store.learn.isFinished(lesson.id)
        let all = lesson.steps
        // Rhythm steps are titled as the player will title them (the screen standing in without a microphone).
        let micOff = LessonMicrophone.unavailable(store.audio)
        return VStack(alignment: .leading, spacing: 14) {
            CardTitle("In this lesson")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(all.enumerated()), id: \.offset) { index, step in
                    stepRow(StepSummary(step, course: course, micOff: micOff), played: played, last: index == all.count - 1)
                }
            }
        }
        .stillCard()
    }

    private func stepRow(_ summary: StepSummary, played: Bool, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Palette.stageRaised)
                Circle().fill(accent.opacity(played ? 0.9 : 0.14))
                Image(systemName: summary.symbol).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(played ? Palette.onAccent : accent)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                summary.title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let detail = summary.detail {
                    detail.font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
            .padding(.top, 5)
            Spacer(minLength: 0)
        }
        .padding(.bottom, last ? 0 : 14)
        // The line from this stop down to the next.
        .background(alignment: .topLeading) {
            if !last {
                Rectangle().fill(Palette.line).frame(width: 2)
                    .padding(.top, 32).padding(.bottom, 2)
                    .padding(.leading, 14)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Preview

    /// What you'll play, drawn still: the lesson's chords (fingers landing), its first picture, its notes on the course's
    /// neck (or a staff for the voice), its rhythm; the course's instrument when it has none of these. Chords and necks
    /// are drawn as the lesson draws them (the chart or the player's view, `ChordPicture`), so the preview never shows
    /// a chord the other way round from the lesson it opens. Stacked, it is 250 points tall; beside the card (`wide`)
    /// it grows up to 440 points, the drawing centred in it.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Preview", color: Palette.inkSoft)
                .accessibilityAddTraits(.isHeader)
            previewBody
                .frame(maxWidth: .infinity)
                .frame(minHeight: wide ? 300 : 250, maxHeight: wide ? 440 : 250)
                .background {
                    // A soft light on the stage, in the course's colour.
                    RadialGradient(colors: [accent.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 260)
                        .allowsHitTesting(false)
                }
        }
        .stillCard()
    }

    @ViewBuilder private var previewBody: some View {
        switch LessonPreview.of(lesson, in: course) {
        case let .chords(chords):
            HStack(alignment: .center, spacing: 14) {
                ForEach(chords, id: \.symbol) { chord in
                    ChordPictureView(chord: chord, accent: accent, landing: true, compact: true)
                        .frame(maxWidth: 150)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .visual(visual):
            GeometryReader { proxy in
                LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument, room: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
        case .art:
            CourseHeroArt(artwork: CourseArtwork.of(course, catalog: store.catalog), accent: accent, size: 200, lean: -10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// What the inspector previews for a lesson, picked from its steps in order of what says most about it.
enum LessonPreview {
    /// Two or three chords side by side (one chord is a `visual`).
    case chords([ChordSpec])
    case visual(LessonVisual)
    /// Nothing to draw: the course's instrument stands in.
    case art

    @MainActor static func of(_ lesson: Lesson, in course: LearnCourse) -> LessonPreview {
        var chords: [ChordSpec] = []
        func keep(_ chord: ChordSpec?) {
            guard let chord, !chords.contains(where: { $0.symbol == chord.symbol }) else { return }
            chords.append(chord)
        }
        if lesson.kind == .song { SongSheet.of(lesson).chords.forEach { keep($0) } }
        var picture: LessonVisual?
        var notes: [TimedNote] = []
        var rhythm: (pattern: [Double], meter: Int?)?
        for step in lesson.steps {
            switch step {
            case let .explain(_, _, visual), let .quiz(_, _, _, _, visual):
                if case let .chord(spec) = visual { keep(spec) } else if picture == nil, !isBlank(visual) { picture = visual }
            case let .playChord(chord):
                keep(chord)
            case let .strum(chord, pattern, _, _, meter, _, _):
                keep(chord)
                if rhythm == nil { rhythm = (pattern, meter) }
            case let .progression(list, _, pattern, _, meter, _, _):
                list.forEach { keep($0) }
                if rhythm == nil { rhythm = (pattern, meter) }
            case let .tapRhythm(pattern, _, _, meter):
                if rhythm == nil { rhythm = (pattern, meter) }
            case let .playNotes(list, _):
                if notes.isEmpty { notes = list }
            case let .playAlong(list, _, _, _):
                if notes.isEmpty { notes = list }
            case .listen:
                break
            }
        }
        if chords.count == 1, let only = chords.first { return .visual(.chord(only)) }
        if chords.count > 1 { return .chords(Array(chords.prefix(3))) }
        if lesson.kind == .song, let melody = noteVisual(SongSheet.of(lesson).melody, in: course) { return .visual(melody) }
        if let picture { return .visual(picture) }
        if let played = noteVisual(notes, in: course) { return .visual(played) }
        if let rhythm {
            let meter = rhythm.meter ?? max(4, Int((rhythm.pattern.max() ?? 3) + 1))
            return .visual(.rhythm(pattern: rhythm.pattern, beatsPerBar: meter))
        }
        return .art
    }

    /// No picture to draw still: none, or a clip (a moving demonstration, and not bundled for every lesson).
    private static func isBlank(_ visual: LessonVisual) -> Bool {
        switch visual {
        case .none, .clip: return true
        default: return false
        }
    }

    /// The first notes (up to eight different ones) where they're played: dots on the course's neck, or a staff for a
    /// course without one (the voice, any instrument), in bass clef when they sit low.
    @MainActor private static func noteVisual(_ notes: [TimedNote], in course: LearnCourse) -> LessonVisual? {
        guard !notes.isEmpty else { return nil }
        if course.fretKind != nil {
            var dots: [Fretting] = []
            for note in notes {
                guard let at = note.at ?? course.fretting(for: note.midi), !dots.contains(at) else { continue }
                dots.append(at)
                if dots.count == 8 { break }
            }
            guard !dots.isEmpty else { return nil }
            let highest = dots.map(\.fret).max() ?? 0
            return .fretboard(strings: course.stringCount, dots: dots, frets: min(12, max(5, highest + 1)), start: 1)
        }
        var midi: [Int] = []
        for note in notes where !midi.contains(note.midi) {
            midi.append(note.midi)
            if midi.count == 8 { break }
        }
        let mean = Double(midi.reduce(0, +)) / Double(max(1, midi.count))
        return .staff(midi: midi, clef: mean < 57 ? "bass" : "treble")
    }
}

/// One step as the inspector lists it: its kind's symbol, what it asks, and the notes, chord or tempo it plays at. A
/// rhythm step's title is the player's own (`RhythmStepTitle`), so the outline and the lesson always agree.
private struct StepSummary {
    let symbol: String
    let title: Text
    let detail: Text?

    init(_ step: LessonStep, course: LearnCourse, micOff: Bool) {
        let rhythmTitle = RhythmStepTitle.of(step, course: course, micOff: micOff).map { Text($0) }
        switch step {
        case let .explain(title, _, _):
            symbol = "text.book.closed"
            self.title = Text(verbatim: title.localized)
            detail = nil
        case let .quiz(prompt, _, _, _, _):
            symbol = "questionmark.bubble"
            title = Text(verbatim: prompt.localized)
            detail = nil
        case let .listen(prompt, _, _, _):
            symbol = "ear"
            title = Text(verbatim: prompt.localized)
            detail = nil
        case let .playNotes(notes, _):
            symbol = "music.note"
            title = Text("Play the notes")
            detail = Text(verbatim: Self.names(notes))
        case let .playAlong(notes, bpm, _, name):
            symbol = "music.note.list"
            title = name.map { Text(verbatim: $0.localized) } ?? Text("Play along")
            detail = Text("\(Int(bpm.rounded())) BPM · \(notes.count) notes")
        case let .playChord(chord):
            symbol = "hand.raised.fingers.spread"
            title = Text("Play the chord")
            detail = Text(verbatim: chord.name)
        case let .strum(chord, _, bpm, bars, _, _, _):
            symbol = "arrow.up.arrow.down"
            title = rhythmTitle ?? Text("Strum on the arrows")
            let tempo = Text("\(Int(bpm.rounded())) BPM · \(bars) bars")
            detail = chord.map { Text(verbatim: $0.name + " · ") + tempo } ?? tempo
        case let .tapRhythm(_, bpm, bars, _):
            // Played on the instrument in time (not tapped on the screen): its own symbol, as its own title.
            symbol = course.fretKind != nil && !micOff ? "metronome" : "hand.tap"
            title = rhythmTitle ?? Text("Tap on the dots")
            detail = Text("\(Int(bpm.rounded())) BPM · \(bars) bars")
        case let .progression(chords, bars, _, bpm, _, _, _):
            symbol = "arrow.triangle.swap"
            title = rhythmTitle ?? Text("Strum on the arrows")
            // The chords in order, then the tempo, as a strum's chord precedes its tempo.
            let tempo = Text("\(Int(bpm.rounded())) BPM · \(bars.reduce(0, +)) bars")
            detail = Text(verbatim: chords.map(\.name).joined(separator: " → ") + " · ") + tempo
        }
    }

    /// "E · A · D · G", the first six different notes, "…" after them when there are more.
    private static func names(_ notes: [TimedNote]) -> String {
        var seen: [String] = []
        for note in notes {
            let name = NoteName.pitchClass(note.midi)
            if !seen.contains(name) { seen.append(name) }
        }
        let shown = seen.prefix(6).joined(separator: " · ")
        return seen.count > 6 ? shown + " …" : shown
    }
}
