import SwiftUI

/// The plan's hero, for onboarding's paywall and Pro from Settings: it sells the plan rather than a game. The person's
/// instrument stands under a light in their course's colour with the sleeve of the first song their plan reaches
/// leaning beside it (drawn as the Songs shelf draws it), its record sliding out; under them, the road there from the
/// plan itself ("Today · Day 2 Greensleeves · Day 7 Strumming"), then the Pro pill.
///
/// The picture is fitted to the room the road and the pill leave, so the instrument always stands whole: nothing is
/// cut by the top edge. Nothing in it redraws every frame but the record turning (off with Reduce Motion), which stands
/// clear of the close button's corner.
struct PaywallPlanHero: View {
    let scene: PaywallPlanScene
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The picture has come together: the sleeve out from behind the instrument, its record slid out.
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                picture(proxy.size)
            }
            road
                .padding(.top, 8)
            PaywallProPill()
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.top, 10)
                .padding(.bottom, 2)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .onAppear(perform: reveal)
    }

    private func reveal() {
        guard !shown else { return }
        if reduceMotion {
            shown = true
        } else {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82).delay(0.2)) { shown = true }
        }
    }

    // MARK: The picture

    /// The instrument in a square `side` points tall, standing on the floor of the room; the sleeve leaning on its
    /// right, the record half out of it. Without an instrument the sleeve stands alone, larger.
    private func picture(_ size: CGSize) -> some View {
        let side = max(1, min(size.height, size.width * 0.56))
        let alone = scene.instrument == nil
        let sleeve = side * (alone ? 0.8 : 0.6)
        let sleeveX = alone ? -sleeve * 0.2 : side * 0.1
        let sleeveY = alone ? side * 0.1 - sleeve * 0.1 : side * 0.17
        return ZStack {
            light(side, width: size.width)
            if let instrument = scene.instrument {
                figure(instrument, side: side)
                    .offset(x: -side * 0.34)
            }
            record(sleeve)
                .offset(x: sleeveX + (shown ? sleeve * 0.36 : 0), y: sleeveY - sleeve * 0.02)
            cover(sleeve)
                .offset(x: sleeveX - (shown ? 0 : side * 0.14), y: sleeveY)
                .opacity(shown ? 1 : 0)
        }
        .frame(width: size.width, height: side)
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .accessibilityHidden(true)
    }

    /// A pool of the course's colour behind the picture, and the shadow it stands on.
    private func light(_ side: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(EllipticalGradient(colors: [scene.accent.opacity(0.3), scene.accent.opacity(0)], center: .center,
                                         startRadiusFraction: 0, endRadiusFraction: 0.5))
                .frame(width: min(width * 1.05, side * 2.3), height: side * 1.4)
                .offset(y: -side * 0.04)
            Ellipse().fill(Color.black.opacity(0.55))
                .frame(width: side * 1.35, height: side * 0.08)
                .blur(radius: 6)
                .offset(y: side * 0.47)
        }
    }

    /// The instrument, whole: a studio render (upright in its square) leans toward the sleeve; a photograph already leans.
    private func figure(_ instrument: (name: String, render: Bool), side: CGFloat) -> some View {
        Image(instrument.name).resizable().interpolation(.high).scaledToFit()
            .frame(width: side * 0.94, height: side * 0.94)
            .rotationEffect(.degrees(instrument.render ? 14 : 0))
            .shadow(color: .black.opacity(0.55), radius: side * 0.05, y: side * 0.04)
            .frame(width: side, height: side)
    }

    private func cover(_ side: CGFloat) -> some View {
        SongCover(art: scene.sleeve, corner: max(6, side * 0.05))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(-4))
            .shadow(color: .black.opacity(0.5), radius: side * 0.08, y: side * 0.05)
    }

    /// The song's record, its label in the sleeve's colour, turning once it is out.
    private func record(_ sleeve: CGFloat) -> some View {
        VinylRecord(color: scene.sleeve.primary, spinning: shown && !reduceMotion)
            .frame(width: sleeve * 0.9, height: sleeve * 0.9)
            .rotationEffect(.degrees(shown ? 0 : -60))
    }

    // MARK: The road

    /// Today, the first song and the next unit on one line; when that is too wide, the first two; at the last, the song.
    private var road: some View {
        ViewThatFits(in: .horizontal) {
            roadRow(scene.stops)
            if scene.stops.count > 2 { roadRow(Array(scene.stops.prefix(2))) }
            roadRow(scene.stops.filter { $0.kind == .song })
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func roadRow(_ stops: [PaywallPlanScene.Stop]) -> some View {
        HStack(spacing: 7) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 7) {
                    if index > 0 { link }
                    stopLabel(stop)
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 5)
                .animation(reduceMotion ? nil : Motion.pluck.delay(0.45 + Double(index) * 0.14), value: shown)
            }
        }
        .lineLimit(1)
    }

    private var link: some View {
        Capsule().fill(Color.white.opacity(0.2)).frame(width: 12, height: 1.5)
    }

    private func stopLabel(_ stop: PaywallPlanScene.Stop) -> some View {
        HStack(spacing: 5) {
            marker(stop.kind)
            day(stop).font(Typeface.label(11, relativeTo: .caption)).foregroundStyle(tint(stop.kind))
            if let title = stop.title {
                Text(verbatim: title).font(.caption.weight(.medium))
                    .foregroundStyle(stop.kind == .unit ? Palette.inkSoft : Palette.ink)
            }
        }
    }

    private func day(_ stop: PaywallPlanScene.Stop) -> Text {
        stop.day <= 1 ? Text("Today") : Text("Day \(stop.day)")
    }

    /// As on the plan track: mint for today, amber for the song, the unit quieter.
    private func tint(_ kind: PaywallPlanScene.Stop.Kind) -> Color {
        switch kind {
        case .today: return Palette.mint
        case .song: return Palette.amber
        case .unit: return Palette.inkSoft
        }
    }

    @ViewBuilder private func marker(_ kind: PaywallPlanScene.Stop.Kind) -> some View {
        switch kind {
        case .today:
            Circle().fill(Palette.mint).frame(width: 7, height: 7)
                .shadow(color: Palette.mint.opacity(0.6), radius: 4)
        case .song:
            Image(systemName: "music.note").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.amber)
        case .unit:
            Image(systemName: "flag.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.inkSoft)
        }
    }

    /// "Your plan: Today, Day 2 Greensleeves, Day 7 Strumming".
    private var spoken: Text {
        var label = Text("Your plan") + Text(verbatim: ": ")
        for (index, stop) in scene.stops.enumerated() {
            if index > 0 { label = label + Text(verbatim: ", ") }
            label = label + day(stop)
            if let title = stop.title { label = label + Text(verbatim: " ") + Text(verbatim: title) }
        }
        return label
    }
}
