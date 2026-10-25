import SwiftUI

/// The plan's hero, for onboarding's paywall and Pro from Settings: it shows the goods. A rail of the sleeves of the
/// songs the plan plays (three Originals for the plan's instrument, then its next song, then the folk and standards it
/// reaches: `PaywallPlan.rail`) drifts slowly right to left across the full width, under a light in the course's
/// colour, with the Pro pill at its foot.
///
/// The sleeves are their art alone (`SongCover` untitled: no course eyebrow, catalogue number or title), so no sleeve
/// type can meet the headline, the pill or the close button. They stand inside the hero and dissolve into the stage
/// before the headline's first line, round the Pro pill and under the close button, so each of those sits on the plain
/// stage. The rail is laid out more than once, so it loops without a seam.
///
/// How large the sleeves are follows the room the fold gives the hero (`PaywallView.fold`): from 64 points on a
/// 6.1-inch iPhone up to `PaywallHero.maxHeight`. Only the rail's offset changes from frame to frame; the sleeves are
/// drawn once (`SleeveStrip` is equatable) and the masks never change while it drifts. With Reduce Motion the rail
/// stands still, its first Original at the left.
struct PaywallPlanHero: View {
    let scene: PaywallPlanScene
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the rail started drifting.
    @State private var start = Date()
    /// The Pro pill as measured: the rail keeps the stage plain round it.
    @State private var pill = CGSize(width: 150, height: 26)

    /// Points a second: a sleeve takes about forty seconds to cross a phone.
    private static let speed: Double = 9
    private static let gap: CGFloat = 12
    private static let smallestSide: CGFloat = 56
    private static let largestSide: CGFloat = 132
    /// Where the sleeves are gone, below the hero's foot: the headline's frame starts 12 points under the hero
    /// (`PaywallView.headerTop`) and its first line's letters a few points below that, on the plain stage.
    private static let clearLine: CGFloat = 6
    /// How far above that line the sleeves start to dissolve, as a share of their side.
    private static let fadeShare: CGFloat = 0.4
    /// The rail runs past the content's side margins to the screen's edges.
    private static let bleed: CGFloat = 20
    /// Where the rail's first sleeve starts, from the screen's left edge: just inside the edge's fade, the rail's last
    /// sleeve fading out to the left of it.
    private static let lead: CGFloat = 40
    /// Room above the sleeves for their tilt, and below them for their shadow.
    private static let topRoom: CGFloat = 4
    private static let bottomRoom: CGFloat = 8
    /// The widest the rail has to cover (the content's widest column and its bleed), so a short rail is laid out
    /// often enough never to leave a gap.
    private static let widest: CGFloat = 600
    /// The plain stage kept round the Pro pill, and how softly the sleeves dissolve into a pocket of plain stage.
    private static let pillMargin: CGFloat = 14
    private static let softness: CGFloat = 9
    /// The close button's disc from the rail's top-trailing corner (`PaywallView.closeButton`: a 34 pt disc in a
    /// 44 pt target, 15 pt in from the trailing edge and 8 pt under the safe area, which is 6 pt above the hero), and
    /// the plain stage kept round it.
    private static let closeInset: CGFloat = 37
    private static let closeDrop: CGFloat = 24
    private static let closeClear: CGFloat = 30
    /// A rail narrower than the content's widest column (480 pt) and its bleed runs to the window's trailing edge,
    /// under the close button; a wider window centres the column away from it.
    private static let columnCap: CGFloat = 519

    /// The sleeves fill the hero from its top to just past its foot.
    private var side: CGFloat {
        min(Self.largestSide, max(Self.smallestSide, height + Self.clearLine - Self.topRoom))
    }

    var body: some View {
        let side = self.side
        ZStack(alignment: .top) {
            light(side)
            rail(side)
        }
        // The rail's shadows run a few points past the hero's frame: drawn, not clipped (they are clear by then).
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            PaywallProPill()
                .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { size in pill = size }
                .padding(.bottom, 2)
        }
    }

    /// A pool of the course's colour behind the rail.
    private func light(_ side: CGFloat) -> some View {
        Rectangle()
            .fill(EllipticalGradient(colors: [scene.accent.opacity(0.26), scene.accent.opacity(0)], center: .center,
                                     startRadiusFraction: 0, endRadiusFraction: 0.5))
            .frame(height: side * 1.4)
            .frame(maxWidth: .infinity)
            .offset(y: -side * 0.14)
            .padding(.horizontal, -Self.bleed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: The rail

    private func rail(_ side: CGFloat) -> some View {
        let songs = scene.songs
        let pitch = side + Self.gap
        let loop = CGFloat(songs.count) * pitch
        // One loop to the left of the first sleeve and enough to its right to reach past the widest screen at the end
        // of a loop, so when the drift wraps to the start the picture is the same.
        let copies = loop > 0 ? 2 + Int((Self.widest / loop).rounded(.up)) : 1
        let strip = SleeveStrip(songs: songs, side: side, gap: Self.gap, top: Self.topRoom)
        let still = reduceMotion || loop <= 0
        // The strip rides in an overlay, so its width (several loops) never widens the hero: the clear base holds the
        // width of the screen and the masks cut the strip to it.
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
                    .offset(x: Self.lead - loop - (still ? 0 : drift(at: timeline.date, loop: loop)))
                }
            }
            .mask { fade(side) }
            .mask { pockets }
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

    /// Solid over the sleeves' upper part, easing out to clear just below the hero's foot (above the headline's
    /// first line), and dissolving at the screen's edges as the app's other rails do (`EdgeFadeMask`): there is
    /// always more rail past both.
    private func fade(_ side: CGFloat) -> some View {
        let total = Self.topRoom + side + Self.bottomRoom
        let clear = min(1, (height + Self.clearLine) / total)
        let solid = max(0, clear - side * Self.fadeShare / total)
        let down = LinearGradient(stops: [Gradient.Stop(color: .black, location: 0)] + Self.easedOut(from: solid, to: clear),
                                  startPoint: .top, endPoint: .bottom)
        let edge = EdgeFadeMask.width(bleed: Self.bleed)
        return down.mask {
            EdgeFadeMask(overflow: EdgeOverflow(leading: true, trailing: true), leading: edge, trailing: edge)
        }
    }

    /// Solid at `from` to clear at `to`, eased (1 − (3t² − 2t³)), so no line shows where the sleeves end.
    private static func easedOut(from: CGFloat, to: CGFloat) -> [Gradient.Stop] {
        (0...6).map { (step: Int) -> Gradient.Stop in
            let t = CGFloat(step) / 6
            let eased = t * t * (3 - 2 * t)
            return Gradient.Stop(color: Color.black.opacity(Double(1 - eased)), location: from + (to - from) * t)
        }
    }

    /// Pockets of plain stage in the rail: round the Pro pill at the hero's foot, and under the close button when the
    /// rail runs to the window's trailing edge. The sleeves dissolve into them softly as they drift past.
    private var pockets: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black
                pillPocket
                if proxy.size.width < Self.columnCap { closePocket }
            }
            .compositingGroup()
        }
    }

    private var pillPocket: some View {
        Capsule().fill(Color.black)
            .frame(width: pill.width + 2 * Self.pillMargin, height: pill.height + 2 * Self.pillMargin)
            .offset(y: height - 2 - pill.height - Self.pillMargin)
            .blur(radius: Self.softness)
            .blendMode(.destinationOut)
    }

    private var closePocket: some View {
        Circle().fill(Color.black)
            .frame(width: 2 * Self.closeClear, height: 2 * Self.closeClear)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: Self.closeClear - Self.closeInset, y: Self.closeDrop - Self.closeClear)
            .blur(radius: Self.softness)
            .blendMode(.destinationOut)
    }

    /// "Songs: Kite Weather, Porchlight and Low Tide Radio".
    private var spoken: Text {
        Text("Songs") + Text(verbatim: ": ") + Text(verbatim: scene.songs.map(\.title).formatted(.list(type: .and)))
    }
}

/// One pass of the rail's sleeves, each hung with a slight tilt: the art alone, no type. Equal on the songs and their
/// size, so the rail's drift moves the strip without drawing its sleeves again.
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
                // Untitled: the motif over the whole sleeve, with no eyebrow, number or title to collide with the
                // headline, and none cut short on a small sleeve.
                SongCover(art: song.art, corner: max(6, side * 0.05), titled: false)
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(Self.tilts[index % Self.tilts.count]))
                    .shadow(color: .black.opacity(0.5), radius: side * 0.06, y: side * 0.04)
            }
        }
        .padding(.top, top)
    }
}
