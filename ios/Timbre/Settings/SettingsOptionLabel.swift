import Foundation
import TimbreCore

/// Picker values are display text, not the core model's English data names.
enum SettingsOptionLabel {
    static func temperamentName(_ temperament: Temperament) -> String {
        NSLocalizedString("timbre_bench_temperament_" + temperament.id, bundle: .app, value: temperament.name, comment: "")
    }

    /// Only the scientific token is left-to-right; the localized name and the row keep their own direction.
    /// LRI/PDI delimit the token without changing its sign, cents value, glyphs or Dynamic Type sizing.
    static func precisionTolerance(_ precision: TuningPrecision) -> String {
        "\u{2066}±\(Int(precision.bandCents))¢\u{2069}"
    }
}
