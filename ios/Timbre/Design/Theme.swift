import SwiftUI
import UIKit

/// "Still Point" design tokens. Sound is light; in tune, motion stops.
enum Palette {
    // Stage
    static let stage = adaptive(0x0E0C0B, 0xF3EEE7)
    static let stageRaised = adaptive(0x171412, 0xFBF8F4)
    static let stageDeep = adaptive(0x070605, 0xE6DFD5)
    static let line = adaptive(0x2B2521, 0xDCD3C8)
    // Ink
    static let ink = adaptive(0xF5EFE6, 0x1A1510)
    static let inkSoft = adaptive(0xB3A99E, 0x5E554C)
    static let inkFaint = adaptive(0x6F675F, 0x9A9086)
    // Brand
    static let brass = adaptive(0xD9B26F, 0x9A6A24)
    static let brassDeep = adaptive(0xA67C3D, 0x7A5218)
    static let ember = adaptive(0xF0A04B, 0xB4661A)
    // Pitch meaning — always paired with motion and an arrow.
    static let flat = adaptive(0x62C9EA, 0x1F7FA6)
    static let sharp = adaptive(0xF4A64C, 0xB86514)
    static let locked = adaptive(0xFFF3DA, 0x2C8A5A)
    static let success = adaptive(0x9FE0B8, 0x22804F)
    static let danger = adaptive(0xF07A6A, 0xB23B2B)

    static func adaptive(_ dark: UInt, _ light: UInt) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .light ? UIColor(hex: light) : UIColor(hex: dark) })
    }
    static func pitch(_ cents: Double?, locked: Bool) -> Color {
        guard let cents else { return inkSoft }
        if locked || abs(cents) < 1.5 { return Palette.locked }
        return cents < 0 ? flat : sharp
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
    /// Instrument Serif: headings, note names and the wordmark.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }
    static func displayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("InstrumentSerif-Italic", size: size, relativeTo: style)
    }
    /// Plex Mono for cents, hertz, tempo.
    static func number(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("IBMPlexMono-Medium", size: size, relativeTo: style)
    }
    static let eyebrow = Font.system(.caption2, design: .default).weight(.semibold)
}

enum Metrics {
    static let gutter: CGFloat = 20
    static let corner: CGFloat = 26
    static let cornerSmall: CGFloat = 16
}

enum Motion {
    /// The "pluck": a fast attack and a damped settle, used across the app.
    static let pluck = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let settle = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let quick = Animation.snappy(duration: 0.22)
}
