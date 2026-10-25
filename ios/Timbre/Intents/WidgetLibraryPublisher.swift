import SwiftUI
import TimbreCore
import UIKit

// App only: builds the configurable widgets' library (WidgetLibrary.swift) from the app's state.

extension WidgetLibrary {
    /// Rebuilds the library and saves it when something changed. `AppStore.publishWidgets()` calls it, so it follows
    /// practice, finished songs and the Learn course the same way the snapshot does.
    @MainActor static func publish(_ store: AppStore) {
        write(WidgetLibrary(instruments: instruments(store.catalog), shelves: shelves(store)))
    }

    // MARK: Instruments

    /// Built once per app language (names follow Timbre's own language, as the widgets' other words do).
    @MainActor private static var cachedInstruments: (language: String, list: [WidgetLibrary.Instrument])?

    @MainActor private static func instruments(_ catalog: Catalog) -> [WidgetLibrary.Instrument] {
        let language = TimbreLocalization.language
        if let cached = cachedInstruments, cached.language == language { return cached.list }
        let families = Dictionary(catalog.families.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let order = Dictionary(catalog.families.map { ($0.id, $0.ordering) }, uniquingKeysWith: { first, _ in first })
        // Families together, in the picker's order; the catalog's own order within a family.
        let sorted = catalog.instruments.enumerated().sorted { a, b in
            let left = order[a.element.familyId] ?? .max, right = order[b.element.familyId] ?? .max
            return left != right ? left < right : a.offset < b.offset
        }
        let list = sorted.map { _, instrument in
            WidgetLibrary.Instrument(id: instrument.id, name: instrument.name.localized,
                       family: families[instrument.familyId]?.name.localized ?? "", symbol: symbol(family: instrument.familyId))
        }
        cachedInstruments = (language, list)
        return list
    }

    static func symbol(family: String) -> String {
        switch family {
        case "guitar", "ukulele", "mandolin": return "guitars"
        case "keys": return "pianokeys"
        case "folk_world_strings": return "music.note.list"
        case "mallet_percussion_hand": return "music.quarternote.3"
        default: return "music.note"
        }
    }

    // MARK: Song shelves

    private struct Entry {
        let course: LearnCourse
        let unit: LearnUnit
        let unitIndex: Int
        let lesson: Lesson
        /// Its place among its course's songs, 1-based (the sleeve's catalogue number).
        let number: Int
    }

    /// Every song, then one shelf per instrument with songs (named after its own course, as the Songs tab's chips).
    @MainActor private static func shelves(_ store: AppStore) -> [Shelf] {
        let curriculum = store.curriculum
        var songs: [Entry] = []
        for course in curriculum.courses {
            var number = 0
            for (index, unit) in course.units.enumerated() {
                for lesson in unit.lessons where lesson.kind == .song {
                    number += 1
                    songs.append(Entry(course: course, unit: unit, unitIndex: index, lesson: lesson, number: number))
                }
            }
        }
        guard !songs.isEmpty else { return [] }
        var access: [String: SongOfTheDay.Access] = [:]
        for song in songs { access[song.lesson.id] = Self.access(song.lesson, in: song.course, store: store) }

        let collection = curriculum.course(id: "songs")
        var result = [shelf(id: allShelf, title: SongsView.title(in: curriculum), symbol: collection?.symbol ?? "music.note.list",
                            accent: collection?.accent ?? "amber", songs: songs, access: access, store: store)]
        var seen = Set<String>()
        for course in curriculum.courses {
            guard let instrument = course.instrument, !seen.contains(instrument) else { continue }
            let members = songs.filter { $0.course.instrument == instrument || $0.course.instrument == nil }
            guard !members.isEmpty else { continue }
            seen.insert(instrument)
            let own = curriculum.courses.first { $0.instrument == instrument && !isCollection($0) } ?? course
            result.append(shelf(id: instrument, title: own.title.localized, symbol: own.symbol, accent: own.accent,
                                songs: members, access: access, store: store))
        }
        return result
    }

    /// The Songs tab's pick for these songs (`SongOfTheDay`, as its featured song under the same filter).
    @MainActor private static func shelf(id: String, title: String, symbol: String, accent: String, songs: [Entry],
                                         access: [String: SongOfTheDay.Access], store: AppStore) -> Shelf {
        let progress = store.learn
        let candidates = songs.map { song in
            SongOfTheDay.Candidate(song: song.lesson, in: song.course, unit: song.unitIndex,
                                   finished: progress.isFinished(song.lesson.id), access: access[song.lesson.id] ?? .locked)
        }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let placed = progress.placedThrough.values.contains { $0 >= 0 }
        let pick = SongOfTheDay.pick(candidates, level: store.level.number, finishedLessons: progress.stars.count, placed: placed, day: day)
        let chosen = songs.first { $0.lesson.id == pick }
        let finished = songs.filter { progress.isFinished($0.lesson.id) }.count
        return Shelf(id: id, title: title, symbol: symbol, accent: accent,
                     song: chosen.map { song($0, access: access[$0.lesson.id] ?? .locked, store: store) },
                     finished: finished, total: songs.count)
    }

    @MainActor private static func song(_ entry: Entry, access: SongOfTheDay.Access, store: AppStore) -> Song {
        let title = entry.lesson.title.localized
        let art = CoverArt(id: entry.lesson.id, title: title, accent: entry.course.accent,
                           genre: CoverArt.genre(unit: entry.unit.title.defaultValue, instrument: entry.course.instrument),
                           label: entry.course.title.localized, number: entry.number)
        let state: String
        switch access {
        case .open: state = "open"
        case .pro: state = "pro"
        case .locked: state = "locked"
        }
        return Song(id: entry.lesson.id, title: title, course: entry.course.title.localized, minutes: entry.lesson.minutes,
                    xp: entry.lesson.xp, stars: store.learn.stars[entry.lesson.id] ?? 0, access: state,
                    colors: [hex(art.primary), hex(art.deep), hex(art.far)], chords: chords(entry.lesson), bpm: bpm(entry.lesson))
    }

    /// Learn's access (`LessonAccess`), with Pro songs split into the next one in order and later ones.
    @MainActor private static func access(_ lesson: Lesson, in course: LearnCourse, store: AppStore) -> SongOfTheDay.Access {
        switch LessonAccess.of(lesson, in: course, store: store) {
        case .play: return .open
        case .pro: return store.learn.isUnlocked(lesson, in: course) ? .pro : .locked
        case .locked: return .locked
        }
    }

    private static func isCollection(_ course: LearnCourse) -> Bool {
        course.lessons.filter { $0.kind == .song }.count * 2 >= course.lessons.count
    }

    private static func isOriginals(_ course: LearnCourse) -> Bool {
        course.id.hasPrefix("original") || course.title.defaultValue.lowercased().hasPrefix("original")
    }

    /// The chords a song asks for, in the order they come, in the player's note names.
    private static func chords(_ lesson: Lesson) -> [String] {
        var names: [String] = []
        func add(_ chord: ChordSpec) { if !names.contains(chord.name) { names.append(chord.name) } }
        // A full arrangement charts the whole song; its shapes come in the order the song first asks for them.
        if let shapes = lesson.arrangement?.shapes, !shapes.isEmpty {
            shapes.forEach(add)
            return Array(names.prefix(4))
        }
        for step in lesson.steps {
            switch step {
            case let .progression(chords, _, _, _, _): chords.forEach(add)
            case let .playChord(chord): add(chord)
            case let .strum(chord, _, _, _, _): if let chord { add(chord) }
            default: break
            }
        }
        return Array(names.prefix(4))
    }

    /// The tempo it is played at: the full arrangement's, else its play-along's, else its strumming's.
    private static func bpm(_ lesson: Lesson) -> Int? {
        if let arrangement = lesson.arrangement { return Int(arrangement.bpm.rounded()) }
        for step in lesson.steps {
            switch step {
            case let .playAlong(_, bpm, _, _): return Int(bpm.rounded())
            case let .progression(_, _, _, bpm, _): return Int(bpm.rounded())
            case let .strum(_, _, bpm, _, _): return Int(bpm.rounded())
            default: continue
            }
        }
        return nil
    }

    private static func hex(_ color: Color) -> UInt {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> UInt { UInt((min(1, max(0, value)) * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}
