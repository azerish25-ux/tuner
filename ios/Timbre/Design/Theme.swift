import SwiftUI
import UIKit

/// "Studio Noir" design tokens: a near-black stage, one amber cue for "act", mint for "in tune".
/// The app is dark by design; names are kept from the earlier palette so every screen restyles at once.
enum Palette {
    // Stage
    static let stage = Color(hex: 0x060708)
    static let stageRaised = Color(hex: 0x111317)
    static let stageDeep = Color(hex: 0x020303)
    static let surface = Color(hex: 0x16191E)
    static let line = Color(hex: 0x24272D)
    // Ink
    static let ink = Color(hex: 0xF5F3EF)
    static let inkSoft = Color(hex: 0xA3A8B1)
    static let inkFaint = Color(hex: 0x80868F)
    // Accents: mint marks success and primary actions, amber asks you to act, flame is the streak.
    static let mint = Color(hex: 0x4CF2B8)
    static let mintDeep = Color(hex: 0x1A8F69)
    static let amber = Color(hex: 0xFFB547)
    static let flame = Color(hex: 0xFF9F43)
    /// Course accents for Learn.
    static let violet = Color(hex: 0xA592FF)
    static let coral = Color(hex: 0xFF7E6B)
    static let sky = Color(hex: 0x62C9FF)
    static func accent(_ name: String) -> Color {
        switch name { case "amber": return amber; case "violet": return violet; case "coral": return coral; case "sky": return sky; default: return mint }
    }
    /// Dark text on mint or gold fills.
    static let onAccent = Color(hex: 0x04130D)
    // Earlier names, mapped onto the new system.
    static let brass = mint
    static let brassDeep = mintDeep
    static let ember = amber
    // Pitch meaning: mint inside the tolerance, amber when close, coral when far (always with words too).
    static let flat = amber
    static let sharp = amber
    static let locked = mint
    static let success = mint
    static let danger = Color(hex: 0xFF6B6B)
    /// Timbre Pro gold.
    static let proGold = LinearGradient(colors: [Color(hex: 0xFFD08A), Color(hex: 0xE39A3B)], startPoint: .top, endPoint: .bottom)

    /// Past this many cents a pitch is "far" (coral) rather than "close" (amber).
    static let nearCents = 20.0

    /// The pitch colour rule: mint inside `band` (or once locked), amber out to `nearCents`, coral beyond.
    /// Cents are judged to the whole cent, as every readout shows them, so a digit and its colour never disagree.
    /// The tuner passes the tracker's own lock band (see `Palette.tuning`), so the colour turns mint exactly where it can lock.
    static func pitch(_ cents: Double?, locked: Bool, band: Double) -> Color {
        guard let cents, cents.isFinite else { return inkSoft }
        let shown = abs(cents.rounded())
        if locked || shown <= band { return mint }
        return shown <= nearCents ? amber : coral
    }

    /// Off-target colour for screens that judge their own tolerance first (intonation, voice):
    /// mint once locked, amber otherwise. The tuner uses the three-zone rule above.
    static func pitch(_ cents: Double?, locked: Bool) -> Color {
        guard cents != nil else { return inkSoft }
        return locked ? mint : amber
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt) { self.init(uiColor: UIColor(hex: hex)) }
}

enum Typeface {
    /// Sora: headings, note names, numbers. Body text stays in the system font.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Sora-SemiBold", size: size, relativeTo: style)
    }
    /// The big note name.
    static func note(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Sora-Medium", size: size, relativeTo: style)
    }
    static func displayLight(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Sora-Light", size: size, relativeTo: style)
    }
    /// Earlier name for the light display face.
    static func displayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font { displayLight(size, relativeTo: style) }
    /// Cents, hertz, tempo, scores.
    static func number(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Sora-Medium", size: size, relativeTo: style).monospacedDigit()
    }
    static func label(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("Sora-SemiBold", size: size, relativeTo: style)
    }
    static let eyebrow = Font.system(.caption2, design: .default).weight(.semibold)
}

enum Metrics {
    static let gutter: CGFloat = 20
    static let corner: CGFloat = 22
    static let cornerSmall: CGFloat = 16
}

enum Motion {
    /// The "pluck": a fast attack and a damped settle, used across the app.
    static let pluck = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let settle = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let quick = Animation.snappy(duration: 0.22)
}
