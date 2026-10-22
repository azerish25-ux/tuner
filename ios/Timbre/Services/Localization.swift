import Foundation
import TimbreCore

/// Resolve imperative copy through the same selected language as SwiftUI's Locale.
func NSLocalizedString(_ key: String, tableName: String? = nil, bundle: Bundle = .main, value: String = "", comment: String) -> String {
    Foundation.NSLocalizedString(key, tableName: tableName, bundle: bundle == .main ? TimbreLocalization.bundle : bundle, value: value, comment: comment)
}

func localizedVoiceExplanation(_ result: VoiceResult, level: Int) -> String {
    guard result.accuracy != nil else {
        let key: String
        if level == 7 { key = "timbre_voice_score_range" }
        else if result.readingCount == 0 { key = "timbre_voice_no_pitch_captured" }
        else if level == 1 { key = "timbre_voice_warmup_no_score" }
        else if [5, 6, 8].contains(level) { key = "timbre_voice_pattern_incomplete" }
        else { key = "timbre_voice_hold_longer" }
        return NSLocalizedString(key, comment: "")
    }
    guard let average = result.scoreAverageOffCents, let count = result.scoreReadingCount else {
        return NSLocalizedString("timbre_voice_score_saved", comment: "")
    }
    let tolerance = Int(result.toleranceCents)
    let primary: String
    switch level {
    case 4: primary = String(format: NSLocalizedString("timbre_voice_score_sustain", comment: ""), average, tolerance)
    case 5: primary = String(format: NSLocalizedString("timbre_voice_score_interval", comment: ""), average, count)
    case 6, 8: primary = String(format: NSLocalizedString("timbre_voice_score_melody", comment: ""), average, count, tolerance)
    default: primary = String(format: NSLocalizedString("timbre_voice_score_pitch", comment: ""), average, count, tolerance)
    }
    guard (2...4).contains(level) else { return primary }
    let steadiness = result.scorePitchVariationCents.map {
        String(format: NSLocalizedString("timbre_voice_score_steadiness_proxy", comment: ""), $0)
    } ?? NSLocalizedString("timbre_voice_score_steadiness_unknown", comment: "")
    return primary + " " + steadiness
}
