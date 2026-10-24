import AppIntents
import WidgetKit

// What the configurable widgets let the player choose, read from the list the app keeps in the App Group
// (`WidgetLibrary`, written whenever the app publishes its widget snapshot). Nothing chosen keeps the old
// behaviour: Quick tune opens the instrument last tuned, Next song looks across every song.

private func resource(_ text: String) -> LocalizedStringResource { "\(text)" }

// MARK: - Quick tune: an instrument

struct WidgetInstrumentEntity: AppEntity {
    let id: String
    let name: String
    let family: String
    let symbol: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Instrument"
    static let defaultQuery = WidgetInstrumentQuery()

    init(_ instrument: WidgetLibrary.Instrument) {
        id = instrument.id
        name = instrument.name
        family = instrument.family
        symbol = instrument.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: resource(name), subtitle: resource(family),
                              image: DisplayRepresentation.Image(systemName: symbol, isTemplate: true))
    }

    var instrument: WidgetLibrary.Instrument { WidgetLibrary.Instrument(id: id, name: name, family: family, symbol: symbol) }
}

struct WidgetInstrumentQuery: EntityStringQuery {
    func entities(for identifiers: [WidgetInstrumentEntity.ID]) async throws -> [WidgetInstrumentEntity] {
        let library = WidgetLibrary.read()
        return identifiers.compactMap { id in library.instrument(id: id).map(WidgetInstrumentEntity.init) }
    }

    func entities(matching string: String) async throws -> [WidgetInstrumentEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = WidgetLibrary.read().instruments
        guard !query.isEmpty else { return all.map(WidgetInstrumentEntity.init) }
        return all.filter { $0.name.localizedStandardContains(query) || $0.family.localizedStandardContains(query) }
            .map(WidgetInstrumentEntity.init)
    }

    /// The whole catalog, families together.
    func suggestedEntities() async throws -> [WidgetInstrumentEntity] {
        WidgetLibrary.read().instruments.map(WidgetInstrumentEntity.init)
    }
}

struct QuickTuneConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick tune"
    static let description = IntentDescription("Open Timbre already listening.")

    /// Nil: the instrument last tuned.
    @Parameter(title: "Instrument")
    var instrument: WidgetInstrumentEntity?
}

// MARK: - Next song: a shelf

/// Every song, or one instrument's (as the Songs tab's filter chips).
struct SongShelfEntity: AppEntity {
    let id: String
    let title: String
    let symbol: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Instrument"
    static let defaultQuery = SongShelfQuery()

    init(_ shelf: WidgetLibrary.Shelf) {
        id = shelf.id
        // The every-song shelf reads "All", as the Songs tab's first chip.
        title = shelf.id == WidgetLibrary.allShelf ? String(localized: "All") : shelf.title
        symbol = shelf.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: resource(title), subtitle: nil,
                              image: DisplayRepresentation.Image(systemName: symbol, isTemplate: true))
    }
}

struct SongShelfQuery: EntityQuery {
    func entities(for identifiers: [SongShelfEntity.ID]) async throws -> [SongShelfEntity] {
        let shelves = WidgetLibrary.read().shelves
        return identifiers.compactMap { id in shelves.first { $0.id == id }.map(SongShelfEntity.init) }
    }

    func suggestedEntities() async throws -> [SongShelfEntity] {
        WidgetLibrary.read().shelves.map(SongShelfEntity.init)
    }
}

struct NextSongConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Next song"
    static let description = IntentDescription("The song to play next, one tap away.")

    /// Nil: every song.
    @Parameter(title: "Instrument")
    var shelf: SongShelfEntity?
}
