import SwiftUI

/// The plan's hero, for onboarding's paywall and Pro from Settings: it shows the goods. A rail of the sleeves of the
/// songs the plan plays (its first song first, each drawn as the Songs shelf draws it) drifts slowly right to left
/// across the full width, under a light in the course's colour, with the Pro pill on it. The sleeves reach on past
/// the hero, behind the headline, and fade into the stage before its words, so the headline always reads on the
/// plain stage. The rail is laid out more than once, so it loops without a seam.
///
/// How large the sleeves are follows the room the fold gives the hero (`PaywallView.fold`): the hero holds their
/// tops and the pill, from 64 points on a 6.1-inch iPhone up to `PaywallHero.maxHeight`. Only the rail's offset
/// changes from frame to frame; the sleeves are drawn once (`SleeveStrip` is equatable). With Reduce Motion the rail
/// stands still, the plan's first song at the left.
struct PaywallPlanHero: View {
    let scene: PaywallPlanScene
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the rail started drifting.
    @State private var start = Date()

    /// Points a second: a sleeve takes about forty seconds to cross a phone.
    private static let speed: Double = 9
    private static let gap: CGFloat = 12
    private static let smallestSide: CGFloat = 56
    private static let largestSide: CGFloat = 132
    /// The sleeves' side against the hero's height: the share past 1 reaches on behind the headline.
    private static let reach: CGFloat = 1.35
    /// The rail runs past the content's side margins to the screen's edges.
    private static let bleed: CGFloat = 20
    /// Where the plan's first song starts, from the screen's left edge.
    private static let lead: CGFloat = 24
    /// Room above the sleeves for their tilt, and below them for their shadow.
    private static let topRoom: CGFloat = 4
    private static let bottomRoom: CGFloat = 8
    /// The widest the rail has to cover (the content's widest column and its bleed), so a short rail is laid out
    /// often enough never to leave a gap.
    private static let widest: CGFloat = 600

    private var side: CGFloat {
        min(Self.largestSide, max(Self.smallestSide, (height - 2) * Self.reach))
    }

    var body: some View {
        let side = self.side
        ZStack(alignment: .top) {
            light(side)
            rail(side)
        }
        // The sleeves overflow the hero's frame at the bottom, behind the headline: drawn, not clipped.
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            PaywallProPill().padding(.bottom, 2)
        }
    }

    /// A pool of the course's colour behind the rail.
    private func light(_ side: CGFloat) -> some View {
        Rectangle()
            .fill(EllipticalGradient(colors: [scene.accent.opacity(0.26), scene.accent.opacity(0)], center: .center,
                                     startRadiusFraction: 0, endRadiusFraction: 0.5))
            .frame(height: side * 1.5)
            .frame(maxWidth: .infinity)
            .offset(y: -side * 0.12)
            .padding(.horizontal, -Self.bleed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: The rail

    private func rail(_ side: CGFloat) -> some View {
        let songs = scene.songs
        let pitch = side + Self.gap
        let loop = CGFloat(songs.count) * pitch
        let copies = loop > 0 ? max(2, Int((Self.widest / loop).rounded(.up)) + 1) : 1
        let strip = SleeveStrip(songs: songs, side: side, gap: Self.gap, top: Self.topRoom)
        let still = reduceMotion || loop <= 0
        // The strip rides in an overlay, so its width (several loops) never widens the hero: the clear base holds the
        // width of the screen and the mask cuts the strip to it.
        return Color.clear
            .frame(height: Self.topRoom + side + Self.bottomRoom)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: still)) { timeline in
                    HStack(spacing: Self.gap) {
                        ForEach(0..<copies, id: \.self) { _ in
                            strip.equatable()
                        }
                    }
                    .fixedSize()
                    .offset(x: Self.lead - (still ? 0 : drift(at: timeline.date, loop: loop)))
                }
            }
            .mask { fade(side) }
            .padding(.horizontal, -Self.bleed)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken)
    }

    /// How far the rail has drifted, within one loop of its songs.
    private func drift(at date: Date, loop: CGFloat) -> CGFloat {
        let travelled = max(0, date.timeIntervalSince(start)) * Self.speed
        return CGFloat(travelled.truncatingRemainder(dividingBy: Double(loop)))
    }

    /// Solid over the sleeves' upper half, gone before their foot (where the headline's words sit), and soft at the
    /// screen's edges.
    private func fade(_ side: CGFloat) -> some View {
        let total = Self.topRoom + side + Self.bottomRoom
        let solid = (Self.topRoom + side * 0.55) / total
        let gone = (Self.topRoom + side * 0.94) / total
        let down = LinearGradient(stops: [Gradient.Stop(color: .black, location: 0), Gradient.Stop(color: .black, location: solid),
                                          Gradient.Stop(color: .clear, location: gone)],
                                  startPoint: .top, endPoint: .bottom)
        let across = LinearGradient(stops: [Gradient.Stop(color: .clear, location: 0), Gradient.Stop(color: .black, location: 0.06),
                                            Gradient.Stop(color: .black, location: 0.94), Gradient.Stop(color: .clear, location: 1)],
                                    startPoint: .leading, endPoint: .trailing)
        return down.mask { across }
    }

    /// "Songs: Greensleeves, Clementine and Kite Weather".
    private var spoken: Text {
        Text("Songs") + Text(verbatim: ": ") + Text(verbatim: scene.songs.map(\.title).formatted(.list(type: .and)))
    }
}

/// One pass of the rail's sleeves, each hung with a slight tilt. Equal on the songs and their size, so the rail's
/// drift moves the strip without drawing its sleeves again.
private struct SleeveStrip: View, Equatable {
    let songs: [PaywallPlan.RailSong]
    let side: CGFloat
    let gap: CGFloat
    /// Room above the sleeves for their tilt.
    let top: CGFloat

    /// Tilts in turn, never two alike side by side.
    private static let tilts: [Double] = [-2.4, 1.8, -1.2, 2.2, -1.8, 1.2, -2.0, 2.4]

    static func == (lhs: SleeveStrip, rhs: SleeveStrip) -> Bool {
        lhs.side == rhs.side && lhs.gap == rhs.gap && lhs.top == rhs.top && lhs.songs.map(\.id) == rhs.songs.map(\.id)
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongCover(art: song.art, corner: max(6, side * 0.05))
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(Self.tilts[index % Self.tilts.count]))
                    .shadow(color: .black.opacity(0.5), radius: side * 0.06, y: side * 0.04)
            }
        }
        .padding(.top, top)
    }
}
