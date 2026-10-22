import Foundation

public struct LocalizedText: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let key: String
    public let defaultValue: String
    public var description: String { defaultValue }
    public var localized: String { key.isEmpty ? defaultValue : NSLocalizedString(key, bundle: TimbreLocalization.bundle, value: defaultValue, comment: "") }
    enum CodingKeys: String, CodingKey { case key; case defaultValue = "default" }
    public init(key: String = "", defaultValue: String) { self.key = key; self.defaultValue = defaultValue }
    public init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) { key = ""; defaultValue = value }
        else { let c = try decoder.container(keyedBy: CodingKeys.self); key = try c.decode(String.self, forKey: .key); defaultValue = try c.decode(String.self, forKey: .defaultValue) }
    }
}
public enum TimbreLocalization {
    public static var language = "en"
    public static var bundle: Bundle {
        guard language != "system", let path = Bundle.main.path(forResource: language, ofType: "lproj"), let selected = Bundle(path: path) else { return .main }
        return selected
    }
}
public struct InstrumentFamily: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: LocalizedText
    public let ordering: Int
    public let accentRole: String
}
public struct Instrument: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: LocalizedText
    public let familyId: String
    public let accentRole: String
    public let defaultTuningId: String
    public let supportedTuningIds: [String]
    public let minFrequencyHz: Double
    public let maxFrequencyHz: Double
    public let isFree: Bool
    public let provenance: String
    public let anchorType: String
    public let source: String
    public let license: String
    public let illustrationRef: String
    public let anchorMapRef: String
    public var isAdjustable: Bool { provenance == "ADJUSTABLE" }
}
public struct Course: Codable, Identifiable, Equatable, Sendable {
    public let index: Int
    public let targetMidi: Int
    public let label: String
    public let anchorId: String?
    public var id: Int { index }
    public init(index: Int, targetMidi: Int, label: String, anchorId: String? = nil) { self.index = index; self.targetMidi = targetMidi; self.label = label; self.anchorId = anchorId }
}
public struct Tuning: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let instrumentId: String
    public let name: LocalizedText
    public let isDefault: Bool
    public let isFree: Bool
    public let a4Hz: Double
    public let temperamentId: String
    public let provenance: String
    public let courses: [Course]
    // Paired strings are separate courses sharing the physical anchor, preserving octave partners.
    public var coursesByAnchor: [String: [Course]] { Dictionary(grouping: courses, by: { $0.anchorId ?? "course-\($0.index)" }) }
}
public struct ReferenceMode: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: LocalizedText
    public let isFree: Bool
    public let provenance: String
    public let courses: [Course]
    public let source: String
    public let license: String
}
public struct ReferencePitchSpec: Codable, Sendable {
    public let `default`: Double
    public let min: Double
    public let max: Double
    public let freePresets: [Double]
}
public struct InstrumentPhoto: Codable, Identifiable, Sendable {
    public let instrumentId: String
    public let label: String
    public let asset: String
    public let thumbnail: String
    public let source: String
    public let sha256: String
    public let origin: String
    public var id: String { instrumentId }
}
public struct Catalog: Sendable {
    public let families: [InstrumentFamily]
    public let instruments: [Instrument]
    public let tunings: [Tuning]
    public let referenceMode: ReferenceMode?
    public let referencePitch: ReferencePitchSpec
    public let photos: [InstrumentPhoto]
    private struct Document: Decodable {
        let families: [InstrumentFamily]; let instruments: [Instrument]; let tunings: [Tuning]
        let referenceMode: ReferenceMode?; let referencePitch: ReferencePitchSpec
    }
    public init() throws {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json"), let photosURL = Bundle.module.url(forResource: "photos", withExtension: "json") else { throw CatalogError.missingResources }
        let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        families = document.families.sorted { $0.ordering < $1.ordering }; instruments = document.instruments; tunings = document.tunings; referenceMode = document.referenceMode; referencePitch = document.referencePitch
        photos = try JSONDecoder().decode([InstrumentPhoto].self, from: Data(contentsOf: photosURL))
        let ids = Set(instruments.map(\.id)); let tuningIDs = Set(tunings.map(\.id)); let familyIDs = Set(families.map(\.id))
        guard ids.count == instruments.count, tuningIDs.count == tunings.count, familyIDs.count == families.count else { throw CatalogError.invalid("Duplicate identifier") }
        for instrument in instruments {
            guard familyIDs.contains(instrument.familyId), instrument.supportedTuningIds.contains(instrument.defaultTuningId), instrument.supportedTuningIds.allSatisfy(tuningIDs.contains), instrument.minFrequencyHz > 0, instrument.maxFrequencyHz >= instrument.minFrequencyHz, !instrument.source.isEmpty, !instrument.license.isEmpty else { throw CatalogError.invalid(instrument.id) }
            for tuning in tunings.filter({ $0.instrumentId == instrument.id }) {
                guard instrument.supportedTuningIds.contains(tuning.id), !tuning.courses.isEmpty else { throw CatalogError.invalid(tuning.id) }
                let anchorless = ["REFERENCE_ONLY", "DRONE", "MALLET_BAR"].contains(instrument.anchorType)
                guard tuning.courses.allSatisfy({ anchorless ? $0.anchorId == nil : !($0.anchorId ?? "").isEmpty }) else { throw CatalogError.invalid(tuning.id + " anchor") }
            }
        }
        guard tunings.allSatisfy({ ids.contains($0.instrumentId) }) else { throw CatalogError.invalid("Unknown tuning owner") }
    }
    public func tuning(id: String) -> Tuning? { tunings.first { $0.id == id } }
    public func instrument(id: String) -> Instrument? { instruments.first { $0.id == id } }
    public func photo(instrumentId: String) -> InstrumentPhoto? { photos.first { $0.instrumentId == instrumentId } }
    public enum CatalogError: Error { case missingResources; case invalid(String) }
}
