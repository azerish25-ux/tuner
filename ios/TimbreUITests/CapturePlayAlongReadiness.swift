import Foundation

/// Interprets one visible accessibility snapshot; absence of the optional check is not proof of readiness.
enum CapturePlayAlongReadiness: Equatable {
    case ready, tuneCheck, unexpected

    struct Control {
        let identifier: String
        var label = ""
        var enabled = true
    }

    static func observed(_ controls: [Control], startLabel: String?) -> Self {
        let identifiers = Set(controls.map(\.identifier))
        let tuning = identifiers.contains("lesson.tunecheck.title") || identifiers.contains("lesson.tunecheck.skip")
        let primary = controls.filter { $0.identifier == "lesson.continue" }
        let along = controls.filter { $0.identifier.hasPrefix("along.") }
        if tuning {
            let skip = controls.filter { $0.identifier == "lesson.tunecheck.skip" }
            guard identifiers.contains("lesson.tunecheck.title"), skip.count == 1, skip[0].enabled,
                  primary.isEmpty, along.isEmpty else { return .unexpected }
            return .tuneCheck
        }
        guard let startLabel, !startLabel.isEmpty,
              primary.count == 1, primary[0].label == startLabel, primary[0].enabled,
              along.contains(where: { $0.identifier == "along.tempo.0" && $0.enabled }),
              !identifiers.contains("along.again"),
              !identifiers.contains("lesson.notes.target"),
              !identifiers.contains(where: { $0.hasPrefix("lesson.option.") }) else { return .unexpected }
        return .ready
    }
}
