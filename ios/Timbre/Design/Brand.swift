import SwiftUI
import UIKit

// The brand in code until the identity designer's files land: the mark (a plucked string settling into stillness, then
// the point where it locks) and the logotype (the mark beside "Timbre" in Sora SemiBold, sentence case, in ink). It
// replaces the tracked capitals in a status colour that stood in for a brand on the posters and the welcome screen.
//
// Integration point: a template image named "Brand/Logotype" in the asset catalog (the Brand folder provides its
// namespace) is drawn instead, tinted with the logotype's ink, the moment it ships. Nothing else changes for callers.

/// The mark: a string's swing dying away into a straight line, ending in the lock's bead. Drawn in `tint` (mint, the
/// colour of in tune) at any size; `height` sets it, the width follows (1.7 : 1).
struct TimbreMark: View {
    var height: CGFloat = 16
    var tint: Color = Palette.mint

    static let aspect: CGFloat = 1.7

    var body: some View {
        let width = height * Self.aspect
        ZStack(alignment: .topLeading) {
            TimbreMarkString()
                .stroke(tint, style: StrokeStyle(lineWidth: max(1, height * 0.12), lineCap: .round, lineJoin: .round))
            Circle().fill(tint)
                .frame(width: height * 0.26, height: height * 0.26)
                .position(x: width - height * 0.13, y: height / 2)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

/// The mark's string, in a rect 1.7 times as wide as it is tall: two and a half swings, each smaller than the last,
/// from the left edge to 62 % of the width, then still to the bead.
struct TimbreMarkString: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        let amplitude = rect.height * 0.36
        let swingEnd = rect.minX + rect.width * 0.62
        let restEnd = rect.maxX - rect.height * 0.3
        let steps = 64
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = rect.minX + (swingEnd - rect.minX) * CGFloat(t)
            let y = mid - amplitude * CGFloat(exp(-2.6 * t) * sin(2 * .pi * 2.5 * t))
            if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: restEnd, y: mid))
        return path
    }
}

/// The logotype: the mark beside "Timbre". `size` is the word's point size; the logotype is art drawn to its picture
/// (a poster, a header), so it keeps that size at every text size. VoiceOver reads "Timbre".
struct TimbreLogotype: View {
    var size: CGFloat = 15
    /// The word's colour; the mark stays mint unless `monochrome`.
    var ink: Color = Palette.ink
    /// One colour throughout (a template on a coloured ground).
    var monochrome = false

    /// The designer's logotype, once it ships as a template image in the catalog (UIKit caches the lookup).
    private var artwork: UIImage? { UIImage(named: "Brand/Logotype") }

    var body: some View {
        Group {
            if let art = artwork {
                Image(uiImage: art).renderingMode(.template).resizable().scaledToFit()
                    .frame(height: size * 1.1)
                    .foregroundStyle(ink)
            } else {
                HStack(spacing: size * 0.36) {
                    TimbreMark(height: size * 0.8, tint: monochrome ? ink : Palette.mint)
                    Text(verbatim: "Timbre")
                        .font(.custom(Typeface.Face.semiBold.fontName, fixedSize: size))
                        .tracking(-size * 0.02)
                        .foregroundStyle(ink)
                }
                .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Timbre"))
    }
}
