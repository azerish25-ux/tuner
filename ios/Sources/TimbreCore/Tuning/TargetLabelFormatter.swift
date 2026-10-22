import Foundation

/// Keep physical holes, relative strings and authored flat spellings, matching Android.
public enum TargetLabelFormatter {
    private static let pitchPattern = try! NSRegularExpression(pattern: #"^([A-G](?:#|b)?-?\d+)(?:\s+(.*))?$"#)
    private static let cuePattern = try! NSRegularExpression(pattern: #"^(.+?) \(([^()]+)\)$"#)
    public static func display(label: String, midi: Int, notation: String = "english", transposition: Int = 0, capo: Int = 0) -> String {
        let ns = label as NSString
        guard let match = pitchPattern.firstMatch(in: label, range: NSRange(location: 0, length: ns.length)) else { return label }
        let pitch = (notation == "english" || notation == "scientific") && transposition == 0 && capo == 0
            ? ns.substring(with: match.range(at: 1))
            : PitchMath.noteName(midi: midi + min(12, max(-12, transposition)) - min(12, max(0, capo)), notation: notation)
        guard match.range(at: 2).location != NSNotFound else { return pitch }
        let suffix = ns.substring(with: match.range(at: 2))
        return suffix.range(of: #"^\([+-]\d+\)$"#, options: .regularExpression) != nil ? pitch + " " + suffix : pitch
    }
    public static func splitCue(_ label: String) -> (main: String, cue: String?) {
        let ns = label as NSString
        guard let match = cuePattern.firstMatch(in: label, range: NSRange(location: 0, length: ns.length)) else { return (label, nil) }
        return (ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)))
    }
}
