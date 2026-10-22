import Foundation

extension Catalog {
    /// Tuning determines pictured physical variants; valid aliases remain user-selectable
    /// for shared groups where the source has no distinct physical tuning preset.
    public func photo(instrumentId: String, tuningId: String?, preferredAsset: String? = nil) -> InstrumentPhoto? {
        let candidates = photos.filter { $0.instrumentId == instrumentId }
        guard !candidates.isEmpty else { return nil }
        let tuningBelongs = tuningId.flatMap { tuning(id: $0) }?.instrumentId == instrumentId
        let id = tuningBelongs ? tuningId : nil
        let variantLabel: String?
        switch instrumentId {
        case "bass.electric.4": variantLabel = id == "bass.electric.4.five" ? "5-string bass" : "4-string bass"
        case "bass.double.4": variantLabel = id == "bass.double.4.five" ? "5-string double bass" : "4-string double bass"
        case "mallet.marimba.0":
            switch id {
            case "mallet.marimba.0.xylophone": variantLabel = "Xylophone"
            case "mallet.marimba.0.glockenspiel": variantLabel = "Glockenspiel"
            case "mallet.marimba.0.vibraphone": variantLabel = "Vibraphone"
            default: variantLabel = "Marimba"
            }
        default: variantLabel = nil
        }
        if let variantLabel { return candidates.first { $0.label == variantLabel } ?? candidates.first }
        return candidates.first { $0.asset == preferredAsset } ?? candidates.first
    }
}
