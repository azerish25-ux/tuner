import SwiftUI

/// A Pro-only card's mark: a small gold lock on a dark disc in the card's corner, read "Timbre Pro". On a wall of cards
/// a PRO pill on every locked one reads as a price tag; the lock says the same in one glyph and leaves the photo
/// and the name alone.
struct ProLock: View {
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(Palette.proGold)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.stage.opacity(0.78)))
            .overlay(Circle().strokeBorder(Palette.proGoldDeep.opacity(0.45), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Timbre Pro"))
    }
}
