import SwiftUI

// "Studio Noir" on the wrist: the tokens of Timbre/Design/Theme.swift (same names and values) for the watch app and its
// complications. Theme.swift itself isn't shared because it builds on UIKit colours; keep the two in step.

enum Palette {
    static let stage = Color(hex: 0x060708)
    static let stageRaised = Color(hex: 0x111317)
    static let line = Color(hex: 0x24272D)
    static let ink = Color(hex: 0xF5F3EF)
    static let inkSoft = Color(hex: 0xA3A8B1)
    static let inkFaint = Color(hex: 0x80868F)
    static let mint = Color(hex: 0x4CF2B8)
    static let amber = Color(hex: 0xFFB547)
    static let flame = Color(hex: 0xFF9F43)
    static let violet = Color(hex: 0xA592FF)
    static let coral = Color(hex: 0xFF7E6B)
    static let sky = Color(hex: 0x62C9FF)
    /// Dark text on mint or gold fills.
    static let onAccent = Color(hex: 0x04130D)

    static func accent(_ name: String) -> Color {
        switch name { case "amber": return amber; case "violet": return violet; case "coral": return coral; case "sky": return sky; default: return mint }
    }

    /// The streak flame's body, as on the iPhone (`StreakFlame`).
    static let flameFill = LinearGradient(colors: [Color(hex: 0xFFE29A), flame, Color(hex: 0xE2542C)], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// Sora for numbers and headings (bundled with the watch app, not the complications, which use the system face).
enum Typeface {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Sora-SemiBold", size: size, relativeTo: style)
    }
    static func number(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Sora-Medium", size: size, relativeTo: style).monospacedDigit()
    }
    static func label(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("Sora-SemiBold", size: size, relativeTo: style)
    }
}
