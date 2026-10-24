import AppIntents
import Foundation
import TimbreCore

/// A catalog instrument for Siri, Shortcuts and Spotlight ("Tune my cello with Timbre"). Every instrument is
/// offered; the app decides access when the tuner opens (a Pro instrument on the free plan shows its paywall).
struct InstrumentEntity: AppEntity {
    let id: String
    let name: String
    let family: String
    /// Shorter names people say: "Ukulele" for "Ukulele (soprano / concert / tenor)", "Piano" and "digital piano"
    /// for "Piano / digital piano", "Guitar" and "Bass" for the two most-tuned instruments.
    let spokenNames: [String]

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Instrument"
    static let defaultQuery = InstrumentQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: Self.resource(name), subtitle: Self.resource(family), image: nil, synonyms: spokenNames.map(Self.resource))
    }

    private static func resource(_ text: String) -> LocalizedStringResource { "\(text)" }

    /// The whole catalog in its own order (families together), named in the device language Siri speaks.
    static let all: [InstrumentEntity] = {
        guard let catalog = try? Catalog() else { return [] }
        let families = Dictionary(catalog.families.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return catalog.instruments.map { instrument in
            let name = InstrumentEntity.localized(instrument.name)
            let family = families[instrument.familyId].map { InstrumentEntity.localized($0.name) } ?? ""
            return InstrumentEntity(id: instrument.id, name: name, family: family,
                                    spokenNames: InstrumentEntity.aliases(for: instrument.id, name: name))
        }
    }()

    /// Siri speaks the device language, so names follow it rather than Timbre's own language setting.
    private static func localized(_ text: LocalizedText) -> String {
        text.key.isEmpty ? text.defaultValue : Bundle.main.localizedString(forKey: text.key, value: text.defaultValue, table: nil)
    }

    static func aliases(for id: String, name: String) -> [String] {
        var names: [String] = []
        switch id {
        case "guitar.acoustic.6": names.append(String(localized: "Guitar"))
        case "bass.electric.4": names.append(String(localized: "Bass"))
        default: break
        }
        // "Banjo (5-string)" → "Banjo"; "Handpan / steel tongue drum" → "Handpan", "steel tongue drum".
        let bare = (name.components(separatedBy: " (").first ?? name).trimmingCharacters(in: .whitespaces)
        names.append(bare)
        names += bare.components(separatedBy: " / ").map { $0.trimmingCharacters(in: .whitespaces) }
        var seen: Set<String> = [name.lowercased()]
        return names.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private var names: [String] { [name] + spokenNames }

    /// Instruments named by `text`: an exact name first ("Bass"), then names containing it ("cel" finds Cello),
    /// then names inside it ("my acoustic guitar").
    static func search(_ text: String) -> [InstrumentEntity] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let exact = all.filter { entity in
            entity.names.contains { $0.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        }
        if !exact.isEmpty { return exact }
        let containing = all.filter { entity in entity.names.contains { $0.localizedStandardContains(query) } }
        if !containing.isEmpty { return containing }
        return all.filter { entity in entity.names.contains { query.localizedStandardContains($0) } }
    }
}

struct InstrumentQuery: EntityStringQuery {
    func entities(for identifiers: [InstrumentEntity.ID]) async throws -> [InstrumentEntity] {
        InstrumentEntity.all.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [InstrumentEntity] {
        InstrumentEntity.search(string)
    }

    /// Every instrument: these are also the values Siri learns for "Tune my … with Timbre".
    func suggestedEntities() async throws -> [InstrumentEntity] {
        InstrumentEntity.all
    }
}
