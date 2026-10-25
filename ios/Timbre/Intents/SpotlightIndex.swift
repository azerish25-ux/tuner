import AppIntents
import CoreSpotlight
import Foundation
import TimbreCore

// Timbre in Spotlight: every catalog instrument ("cello"), lesson and song ("Kite Weather") is an indexed App
// Entity. Tapping a result runs its open intent, which hands a `timbre://` link to RootView, so it lands exactly
// where the same link from a widget would (DeepLink.swift): the tuner on that instrument, the lesson or its paywall.
// MARK: - Instruments

extension InstrumentEntity: IndexedEntity {
    /// Searchable beyond its name: its family and the shorter names people say.
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = name
        attributes.contentDescription = family
        attributes.keywords = [family, String(localized: "Tune")] + spokenNames
        return attributes
    }
}

/// Spotlight's way in to an instrument: the tuner on it (a Pro instrument on the free plan opens its paywall).
/// Siri and Shortcuts already have "Tune an instrument" (`TuneInstrumentIntent`), so this one stays out of their lists.
struct OpenInstrumentIntent: OpenIntent {
    static let title: LocalizedStringResource = "Tune an instrument"
    static let description = IntentDescription("Opens the tuner on the instrument you name.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Instrument")
    var target: InstrumentEntity

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.tune(instrument: target.id)
        return .result()
    }
}

// MARK: - Lessons and songs

/// A lesson or a song of the curriculum, named in the device language (as Siri and Spotlight speak it).
struct LessonEntity: IndexedEntity {
    let id: String
    let title: String
    /// Its course and unit: "Originals · First songs".
    let place: String
    let song: Bool
    /// Its course's symbol (a song wears a note).
    let symbol: String
    /// More words to find it by: its course, its unit and the chords it asks for.
    let keywords: [String]

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Lesson"
    static let defaultQuery = LessonQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: Self.resource(title), subtitle: Self.resource(place),
                              image: DisplayRepresentation.Image(systemName: song ? "music.note" : symbol, isTemplate: true))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        attributes.contentDescription = place
        attributes.keywords = keywords
        return attributes
    }

    private static func resource(_ text: String) -> LocalizedStringResource { "\(text)" }

    /// Every lesson and song in curriculum order (reviews are made for each learner, so they stay out). Read from the
    /// app's one decoded curriculum (`CurriculumStore`), never decoded again here.
    static let all: [LessonEntity] = {
        let curriculum = CurriculumStore.shared.curriculum
        let songsTitle = curriculum.course(id: "songs").map { LessonEntity.localized($0.title) }
        var found: [LessonEntity] = []
        for course in curriculum.courses {
            let courseTitle = LessonEntity.localized(course.title)
            for unit in course.units {
                let unitTitle = LessonEntity.localized(unit.title)
                for lesson in unit.lessons where lesson.kind != .review {
                    let song = lesson.kind == .song
                    var words = [courseTitle, unitTitle] + LessonEntity.chordNames(lesson)
                    if song, let songsTitle { words.append(songsTitle) }
                    found.append(LessonEntity(id: lesson.id, title: LessonEntity.localized(lesson.title), place: "\(courseTitle) · \(unitTitle)",
                                              song: song, symbol: course.symbol, keywords: words))
                }
            }
        }
        return found
    }()

    static let byId: [String: LessonEntity] = Dictionary(LessonEntity.all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// Lesson text in the device language (Learn.strings), not Timbre's own language setting.
    private static func localized(_ text: LearnText) -> String {
        text.key.isEmpty ? text.defaultValue : Bundle.main.localizedString(forKey: text.key, value: text.defaultValue, table: "Learn")
    }

    private static func chordNames(_ lesson: Lesson) -> [String] {
        var names: [String] = []
        for step in lesson.steps {
            switch step {
            case let .progression(chords, _, _, _, _): names += chords.map(\.symbol)
            case let .playChord(chord): names.append(chord.symbol)
            case let .strum(chord, _, _, _, _): if let chord { names.append(chord.symbol) }
            default: break
            }
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    /// Lessons named by `text`: titles containing it first, then those whose course or unit does.
    static func search(_ text: String) -> [LessonEntity] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let titled = all.filter { $0.title.localizedStandardContains(query) }
        if !titled.isEmpty { return titled }
        return all.filter { $0.place.localizedStandardContains(query) }
    }
}

struct LessonQuery: EntityStringQuery {
    func entities(for identifiers: [LessonEntity.ID]) async throws -> [LessonEntity] {
        identifiers.compactMap { LessonEntity.byId[$0] }
    }

    func entities(matching string: String) async throws -> [LessonEntity] {
        LessonEntity.search(string)
    }

    /// The songs: what people most often open by name.
    func suggestedEntities() async throws -> [LessonEntity] {
        LessonEntity.all.filter(\.song)
    }
}

/// Opens a lesson or a song from Spotlight, Siri or Shortcuts: it plays when it's open, a Pro one shows its paywall,
/// and one further on in its course shows where it sits (`DeepLink.openLesson`).
struct OpenLessonIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open a lesson"
    static let description = IntentDescription("Opens the lesson or song you choose.")
    static let openAppWhenRun = true

    @Parameter(title: "Lesson")
    var target: LessonEntity

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.link = DeepLink.lesson(id: target.id)
        return .result()
    }
}

// MARK: - The index

/// Keeps the instruments, lessons and songs in Spotlight. Indexing runs in the background and only when something
/// it shows could have changed (the app build, the catalog, the curriculum or the device language), so an ordinary
/// launch costs one comparison.
enum SpotlightIndex {
    private static let indexName = "timbre.library"
    private static let signatureKey = "spotlight.signature"
    /// Bump when what goes into the index changes shape.
    private static let schema = 1

    @MainActor static func refresh(_ store: AppStore) {
        #if DEBUG
        // UI tests and store screenshots never need it (and keep their launches quiet).
        let environment = ProcessInfo.processInfo.environment
        let testing = ["XCTestConfigurationFilePath", "TIMBRE_TEST_STORAGE_ID", "TIMBRE_DEMO_PITCH", "TIMBRE_SCENE"]
        if testing.contains(where: { environment[$0] != nil }) { return }
        #endif
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let info = Bundle.main.infoDictionary ?? [:]
        let parts = [String(schema),
                     info["CFBundleShortVersionString"] as? String ?? "",
                     info["CFBundleVersion"] as? String ?? "",
                     String(store.curriculum.version),
                     String(store.curriculum.lessonCount),
                     String(store.catalog.instruments.count),
                     Locale.preferredLanguages.first ?? ""]
        let signature = parts.joined(separator: "|")
        guard UserDefaults.standard.string(forKey: signatureKey) != signature else { return }
        Task.detached(priority: .utility) {
            do {
                let index = CSSearchableIndex(name: SpotlightIndex.indexName)
                // A fresh start, so lessons a new curriculum dropped don't linger.
                try await index.deleteAllSearchableItems()
                try await index.indexAppEntities(InstrumentEntity.all, priority: 2)
                try await index.indexAppEntities(LessonEntity.all.filter(\.song), priority: 2)
                try await index.indexAppEntities(LessonEntity.all.filter { !$0.song }, priority: 1)
                UserDefaults.standard.set(signature, forKey: SpotlightIndex.signatureKey)
            } catch {
                // Not saved: the next launch tries again.
            }
        }
    }

    /// A Spotlight result handed over as a user activity rather than through its open intent: its identifier is the
    /// entity's (an instrument or a lesson id). Anything else is left alone.
    @MainActor static func open(_ activity: NSUserActivity, store: AppStore) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        if store.catalog.instrument(id: identifier) != nil {
            IntentRouter.shared.link = DeepLink.tune(instrument: identifier)
        } else if store.curriculum.lesson(id: identifier) != nil {
            IntentRouter.shared.link = DeepLink.lesson(id: identifier)
        }
    }
}
