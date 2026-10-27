import SwiftUI

/// Keep the existing translated sentence and spoken label; only its mathematical fraction is LTR.
struct PracticeXPProgress: View {
    let done: Int
    let total: Int
    let next: String
    @Environment(\.locale) private var locale

    static let key = "%lld / %lld XP · next: %@"
    // Exact accepted prefixes only: preserve the translator's slash and surrounding spacing.
    private static let fractionPrefixes = [(prefix: "%lld / %lld", separator: " / "),
                                           (prefix: "%lld／%lld", separator: "／")]

    // Internal so native tests can independently render the exact accessibility-label Text.
    var spoken: Text {
        Text("\(done) / \(total) XP · next: \(Text(LocalizedStringKey(next)))")
    }

    var body: some View {
        let template = NSLocalizedString(Self.key, comment: "")
        if let sentence = Self.sentence(template: template, counts: (done, total),
                                        next: NSLocalizedString(next, comment: ""), locale: locale) {
            Text(verbatim: sentence)
                .accessibilityLabel(spoken)
        } else {
            // A future translator may reorder placeholders. Never guess a different sentence or crash.
            spoken
        }
    }

    static func sentence(template: String, counts: (Int, Int), next: String, locale: Locale) -> String? {
        guard let fraction = fractionPrefixes.first(where: { template.hasPrefix($0.prefix) }) else { return nil }
        let suffix = String(template.dropFirst(fraction.prefix.count))
        // String(format:) must never receive unknown future conversion specifiers or missing arguments.
        guard suffix.components(separatedBy: "%@").count == 2,
              !suffix.replacingOccurrences(of: "%@", with: "").contains("%") else { return nil }
        // The outer isolate orders the two isolated operands physically left-to-right. An outer LRI alone
        // does not stop Arabic-number runs around a neutral slash from reversing inside that isolate.
        let isolated = "\u{2066}\u{2066}%lld\u{2069}\(fraction.separator)\u{2066}%lld\u{2069}\u{2069}"
        let format = isolated + suffix
        return String(format: format, locale: locale, arguments: [Int64(counts.0), Int64(counts.1), next])
    }
}
