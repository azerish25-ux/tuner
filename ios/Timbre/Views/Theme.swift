import SwiftUI

enum TimbreTheme {
    static let brass = Color(hex: 0xDCC28B)
    static let ink = Color(hex: 0x1A1206)
    static let canvas = adaptive(0x101419, 0xF4F6F8)
    static let surface = adaptive(0x1B2227, 0xFFFFFF)
    static let raised = adaptive(0x252E33, 0xE9EDF1)
    static let primary = adaptive(0xF4F1EA, 0x131820)
    static let secondary = adaptive(0xA8B2B8, 0x59626E)
    static let success = adaptive(0xA9C5B5, 0x1E7A56)
    static let warning = adaptive(0xEE7B45, 0x8F4A00)
    static func adaptive(_ dark: UInt, _ light: UInt) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
    static func title(_ size: CGFloat = 28) -> Font { .custom("SpaceGrotesk-Light", size: size, relativeTo: .title).weight(.medium) }
    static func number(_ size: CGFloat = 44) -> Font { .custom("IBMPlexMono-Medium", size: size, relativeTo: .largeTitle) }
}
extension Color {
    init(hex: UInt) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 14) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 20)) }
}
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15).foregroundStyle(TimbreTheme.ink).background(TimbreTheme.brass.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
