import SwiftUI
import TimbreCore

/// Build or edit a tuning: one target per string, stepped in semitones from the
/// instrument's standard tuning, with a reference tone for each string.
struct CustomTuningEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let editing: CustomTuning?
    @State private var name: String
    @State private var midis: [Int]
    private let base: [Course]

    init(base: Tuning, editing: CustomTuning? = nil) {
        self.editing = editing
        self.base = base.courses.sorted { $0.index < $1.index }
        _name = State(initialValue: editing?.name ?? String(localized: "My tuning"))
        _midis = State(initialValue: editing?.midis ?? self.base.map(\.targetMidi))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Tuning name", text: $name)
                        .font(Typeface.display(.title)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16).padding(.vertical, 12).glassCapsule(interactive: false)
                        .accessibilityIdentifier("custom.name")
                    HeadstockPreview(pegs: pegs, card: CardHeadstock.resolve(modelID: store.modelID, anchors: pegs.map(\.anchor)), animate: !reduceMotion)
                        .frame(height: 210)
                        .stillCard(padding: 0)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                    Text("Move each string in semitones, up to an octave either way. Tap a string to hear it.")
                        .font(.footnote).foregroundStyle(Palette.inkSoft)
                    VStack(spacing: 0) {
                        let groups = self.groups
                        ForEach(Array(groups.enumerated()), id: \.offset) { number, group in
                            row(number: groups.count - number, group: group)
                            if number < groups.count - 1 { Hairline() }
                        }
                    }
                    .stillCard(padding: 6)
                    if editing != nil {
                        Button(role: .destructive) {
                            if let editing { store.deleteCustomTuning(id: editing.id) }
                            dismiss()
                        } label: { Label("Delete tuning", systemImage: "trash") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.danger)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Metrics.gutter)
            }
            .stageTopShade()
            .background(StageBackground(motes: false))
            .navigationTitle(editing == nil ? "New tuning" : "Edit tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.saveCustomTuning(CustomTuning(id: editing?.id ?? "custom." + UUID().uuidString.lowercased(),
                                                            instrumentId: store.instrument.id,
                                                            name: trimmed.isEmpty ? String(localized: "My tuning") : String(trimmed.prefix(60)),
                                                            midis: midis))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("custom.save")
                }
            }
        }
    }

    /// Strings tuned together, as offsets into `base`: a mandolin's or 12-string's pairs share one row
    /// (one anchor), so a paired instrument shows four rows, not eight.
    private var groups: [[Int]] {
        var order: [String] = []
        var members: [String: [Int]] = [:]
        for (offset, course) in base.enumerated() {
            let key = course.anchorId ?? "course.\(course.index)"
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(offset)
        }
        return order.compactMap { members[$0] }
    }

    /// Each row as the headstock shows it: its peg, the note it is tuned to and its move from standard.
    private var pegs: [PegState] {
        groups.enumerated().map { number, group in
            let first = group.first ?? 0
            let midi = midis[first]
            return PegState(id: number, anchor: base[first].anchorId,
                            note: PitchMath.noteName(midi: midi, notation: store.settings.notation),
                            shift: midi - base[first].targetMidi)
        }
    }

    /// One string (or pair), numbered from the highest like the instrument: its note, how far it moved,
    /// and steppers that move the whole pair together.
    private func row(number: Int, group: [Int]) -> some View {
        let first = group.first ?? 0
        let midi = midis[first]
        let shift = midi - base[first].targetMidi
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("String \(number)")
                    if group.count > 1 { Text(verbatim: "×\(group.count)") }
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.inkFaint)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(PitchMath.noteName(midi: midi, notation: store.settings.notation)).font(Typeface.display(.title)).foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    if shift != 0 {
                        Text(shift > 0 ? "+\(shift)" : "\(shift)").font(Typeface.number(.caption))
                            .foregroundStyle(shift > 0 ? Palette.sharp : Palette.flat)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { play(group) }
            // VoiceOver: one element per string; swipe up or down to move it a semitone, double-tap to hear it.
            .adjustableValue(stringLabel(number: number, group: group), value: Text(verbatim: noteValue(midi: midi, shift: shift)),
                             increment: { nudge(group, 1) }, decrement: { nudge(group, -1) })
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Plays this string's note"))
            .accessibilityAction { play(group) }
            Spacer()
            Button { step(group, -1) } label: { Image(systemName: "minus") }
                .buttonStyle(ChipButtonStyle(selected: false)).disabled(shift <= -12)
                .accessibilityLabel(Text("Lower string \(number)"))
            Button { step(group, 1) } label: { Image(systemName: "plus") }
                .buttonStyle(ChipButtonStyle(selected: false)).disabled(shift >= 12)
                .accessibilityLabel(Text("Raise string \(number)"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    private func step(_ group: [Int], _ delta: Int) {
        withAnimation(Motion.quick) { for offset in group { midis[offset] += delta } }
        Haptics.shared.selection()
        play(group)
    }

    /// A step that stays within an octave of standard (the buttons disable themselves at the ends).
    private func nudge(_ group: [Int], _ delta: Int) {
        guard let first = group.first, (-12...12).contains(midis[first] - base[first].targetMidi + delta) else { return }
        step(group, delta)
    }

    /// "String 6" (with "×2" for a pair), as the row's caption reads.
    private func stringLabel(number: Int, group: [Int]) -> Text {
        group.count > 1 ? Text("String \(number)") + Text(verbatim: " ×\(group.count)") : Text("String \(number)")
    }

    /// The note, and its move from standard once moved ("F2, +1").
    private func noteValue(midi: Int, shift: Int) -> String {
        let note = PitchMath.noteName(midi: midi, notation: store.settings.notation)
        return shift == 0 ? note : note + ", " + (shift > 0 ? "+\(shift)" : "\(shift)")
    }

    /// The string's note; an octave pair sounds both notes together.
    private func play(_ group: [Int]) {
        let pitches = Array(Set(group.map { midis[$0] })).sorted()
        let tones = pitches.map { PitchMath.frequency(midi: Double($0), reference: store.settings.referencePitchHz) }
        audio.playTones(tones, together: tones.count > 1)
    }
}

// MARK: - Headstock preview

/// One row of the editor as the headstock shows it.
private struct PegState: Identifiable, Equatable {
    /// The row, lowest string first.
    let id: Int
    let anchor: String?
    let note: String
    /// Semitones from the instrument's standard tuning.
    let shift: Int
}

/// The headstock with a badge beside every peg: the note that string is tuned to and, once moved, how
/// far from standard (+2, −1), changing as the rows below do. The instrument's studio render when it has
/// one, otherwise a drawn headstock; an instrument with many strings shows them side by side instead.
private struct HeadstockPreview: View {
    let pegs: [PegState]
    let card: CardHeadstock?
    let animate: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                RadialGradient(colors: [Palette.spotlight.opacity(0.1), .clear], center: UnitPoint(x: 0.5, y: 0.34), startRadius: 4, endRadius: 190)
                if pegs.count > 8 {
                    StringFan(pegs: pegs)
                } else if let card {
                    let layout = card.layout(in: size)
                    Image(card.image).resizable().interpolation(.high)
                        .frame(width: layout.imageSide, height: layout.imageSide)
                        .position(layout.imageCenter)
                        .mask { neckFade }
                    PegBadges(pegs: pegs, posts: layout.posts, left: layout.left, size: size, animate: animate)
                } else {
                    let drawn = DrawnHeadstock(size: size, count: pegs.count)
                    Canvas { context, _ in drawn.draw(&context, pegs: pegs) }
                        .mask { neckFade }
                    PegBadges(pegs: pegs, posts: drawn.posts, left: drawn.left, size: size, animate: animate)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    /// The neck dissolves into the card below the nut.
    private var neckFade: some View {
        LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.74), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The studio render's headstock: one peg post per row and the nut, normalised (0…1) on the square render.
private struct CardHeadstock {
    let image: String
    let posts: [CGPoint]
    let nut: [CGPoint]

    /// The render's side, in points, at most: the headstock shows large without the 1024-pixel render going soft.
    static let maxScale: CGFloat = 760

    /// Only when the render marks a peg for every row of this tuning.
    @MainActor static func resolve(modelID: String?, anchors: [String?]) -> CardHeadstock? {
        guard let modelID, !anchors.isEmpty, ModelLibrary.hasCard(modelID), let rig = ModelLibrary.rig(modelID) else { return nil }
        var posts: [CGPoint] = []
        var nut: [CGPoint] = []
        for anchor in anchors {
            guard let anchor, let post = rig.card(anchor + ".peg") else { return nil }
            posts.append(post)
            if let point = rig.card(anchor + ".nut") { nut.append(point) }
        }
        return CardHeadstock(image: ModelLibrary.cardImageName(modelID), posts: posts, nut: nut)
    }

    struct Layout {
        let imageSide: CGFloat
        let imageCenter: CGPoint
        let posts: [CGPoint]
        let left: [Bool]
    }

    /// The render scaled and placed so the pegs and the nut (and a little neck) fill the view.
    func layout(in size: CGSize) -> Layout {
        let all = posts + nut
        let minX = all.map(\.x).min() ?? 0, maxX = all.map(\.x).max() ?? 1
        let minY = all.map(\.y).min() ?? 0, maxY = all.map(\.y).max() ?? 1
        let region = CGRect(x: minX - 0.06, y: minY - 0.045, width: maxX - minX + 0.12, height: maxY - minY + 0.115)
        let scale = min(Self.maxScale, size.height / max(0.05, region.height))
        let origin = CGPoint(x: size.width / 2 - region.midX * scale, y: size.height / 2 - region.midY * scale)
        return Layout(imageSide: scale,
                      imageCenter: CGPoint(x: origin.x + scale / 2, y: origin.y + scale / 2),
                      posts: posts.map { CGPoint(x: origin.x + $0.x * scale, y: origin.y + $0.y * scale) },
                      left: sides())
    }

    /// Which pegs face left: split at the widest gap across the headstock; an in-line headstock (no real
    /// gap) puts every badge on the side its pegs sit, away from the nut.
    private func sides() -> [Bool] {
        let xs = posts.map(\.x).sorted()
        var gap: CGFloat = 0
        var split: CGFloat = 0
        if xs.count > 1 {
            for i in 1..<xs.count where xs[i] - xs[i - 1] > gap {
                gap = xs[i] - xs[i - 1]
                split = (xs[i] + xs[i - 1]) / 2
            }
        }
        if gap >= 0.018 { return posts.map { $0.x < split } }
        let mean = xs.reduce(0, +) / CGFloat(max(1, xs.count))
        let nutX = nut.isEmpty ? mean : nut.map(\.x).reduce(0, +) / CGFloat(nut.count)
        let left = mean <= nutX
        return posts.map { _ in left }
    }
}

/// A drawn headstock for instruments without a render: pegs in two rows (the lowest string nearest the nut
/// on the left, the highest nearest it on the right, as on a guitar), strings running to the nut.
private struct DrawnHeadstock {
    let size: CGSize
    let count: Int

    private var center: CGFloat { size.width / 2 }
    private var nutY: CGFloat { size.height - 46 }
    private var leftCount: Int { (count + 1) / 2 }
    private var lowest: CGFloat { nutY - 30 }
    private var step: CGFloat {
        let rows = max(1, leftCount)
        return rows > 1 ? min(34, (lowest - 40) / CGFloat(rows - 1)) : 0
    }
    private var topRow: CGFloat { lowest - CGFloat(max(0, leftCount - 1)) * step }

    var posts: [CGPoint] {
        (0..<count).map { i in
            if i < leftCount { return CGPoint(x: center - 22, y: lowest - CGFloat(i) * step) }
            return CGPoint(x: center + 22, y: topRow + CGFloat(i - leftCount) * step)
        }
    }
    var left: [Bool] { (0..<count).map { $0 < leftCount } }

    private func slot(_ i: Int) -> CGFloat { count > 1 ? center - 18 + 36 * CGFloat(i) / CGFloat(count - 1) : center }

    func draw(_ context: inout GraphicsContext, pegs: [PegState]) {
        // Neck below the nut, two frets.
        context.fill(Path(CGRect(x: center - 26, y: nutY, width: 52, height: size.height - nutY + 4)),
                     with: .linearGradient(Gradient(colors: [Palette.surface, Palette.line]), startPoint: CGPoint(x: center - 26, y: 0), endPoint: CGPoint(x: center + 26, y: 0)))
        for y in [nutY + 24, nutY + 46] {
            var fret = Path()
            fret.move(to: CGPoint(x: center - 26, y: y))
            fret.addLine(to: CGPoint(x: center + 26, y: y))
            context.stroke(fret, with: .color(Palette.inkFaint.opacity(0.45)), lineWidth: 1.5)
        }
        // The head: tapering up from the nut to a soft crown.
        let crown = topRow - 22
        var head = Path()
        head.move(to: CGPoint(x: center - 28, y: nutY))
        head.addLine(to: CGPoint(x: center - 40, y: crown + 8))
        head.addQuadCurve(to: CGPoint(x: center + 40, y: crown + 8), control: CGPoint(x: center, y: crown - 14))
        head.addLine(to: CGPoint(x: center + 28, y: nutY))
        head.closeSubpath()
        context.fill(head, with: .linearGradient(Gradient(colors: [Palette.line, Palette.surface]), startPoint: CGPoint(x: center, y: crown), endPoint: CGPoint(x: center, y: nutY)))
        context.stroke(head, with: .color(.white.opacity(0.08)), lineWidth: 1)
        // Tuners: a shaft out to a button, lit in the adjust amber when that string has moved (it will need turning).
        let points = posts
        for (i, post) in points.enumerated() {
            let moved = pegs.indices.contains(i) && pegs[i].shift != 0
            let out: CGFloat = i < leftCount ? -1 : 1
            var shaft = Path()
            shaft.move(to: CGPoint(x: post.x + out * 5, y: post.y))
            shaft.addLine(to: CGPoint(x: post.x + out * 20, y: post.y))
            context.stroke(shaft, with: .color(Palette.inkSoft.opacity(0.6)), lineWidth: 2.5)
            let button = CGRect(x: post.x + out * 27 - 7, y: post.y - 5.5, width: 14, height: 11)
            let metal = Gradient(colors: [Palette.ink.opacity(0.8), Palette.inkFaint])
            let shading: GraphicsContext.Shading = moved
                ? .color(Palette.adjust)
                : .linearGradient(metal, startPoint: CGPoint(x: button.midX, y: button.minY), endPoint: CGPoint(x: button.midX, y: button.maxY))
            context.fill(Path(roundedRect: button, cornerRadius: 4), with: shading)
        }
        // Strings from each post to its slot in the nut, then down the neck.
        for (i, post) in points.enumerated() {
            let moved = pegs.indices.contains(i) && pegs[i].shift != 0
            let width = count > 1 ? 2 - CGFloat(i) / CGFloat(count - 1) : 1.5
            var string = Path()
            string.move(to: post)
            string.addLine(to: CGPoint(x: slot(i), y: nutY))
            string.addLine(to: CGPoint(x: slot(i) + (slot(i) - center) * 0.15, y: size.height))
            context.stroke(string, with: .color(moved ? Palette.adjust.opacity(0.9) : Palette.ink.opacity(0.45)), lineWidth: width)
        }
        for post in points {
            context.fill(Path(ellipseIn: CGRect(x: post.x - 4.5, y: post.y - 4.5, width: 9, height: 9)), with: .color(Palette.ink.opacity(0.78)))
        }
        // Nut.
        context.fill(Path(roundedRect: CGRect(x: center - 28, y: nutY - 3, width: 56, height: 5), cornerRadius: 1.5), with: .color(Palette.ink.opacity(0.85)))
    }
}

/// Note badges in a column either side of the headstock, each joined to its peg by a hairline; a moved
/// string's badge and line turn the amber of a string to adjust (`Palette.adjust`) and carry its offset.
private struct PegBadges: View {
    let pegs: [PegState]
    let posts: [CGPoint]
    let left: [Bool]
    let size: CGSize
    let animate: Bool

    private static let width: CGFloat = 92
    private static let reach: CGFloat = 42
    private static let pitch: CGFloat = 30

    private struct Spot {
        let center: CGPoint
        /// Where the hairline leaves the badge.
        let edge: CGPoint
    }

    var body: some View {
        let spots = place()
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for (i, spot) in spots.enumerated() {
                    guard let spot, posts.indices.contains(i), pegs.indices.contains(i) else { continue }
                    let moved = pegs[i].shift != 0
                    var line = Path()
                    line.move(to: spot.edge)
                    line.addLine(to: posts[i])
                    context.stroke(line, with: .color(moved ? Palette.adjust.opacity(0.75) : .white.opacity(0.2)), lineWidth: 1)
                    let post = posts[i]
                    if moved {
                        context.fill(Path(ellipseIn: CGRect(x: post.x - 10, y: post.y - 10, width: 20, height: 20)),
                                     with: .radialGradient(Gradient(colors: [Palette.adjust.opacity(0.55), .clear]), center: post, startRadius: 0, endRadius: 10))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: post.x - 2.5, y: post.y - 2.5, width: 5, height: 5)), with: .color(moved ? Palette.adjust : Palette.ink.opacity(0.8)))
                }
            }
            ForEach(pegs) { peg in
                if spots.indices.contains(peg.id), let spot = spots[peg.id] {
                    let onLeft = left.indices.contains(peg.id) && left[peg.id]
                    PegBadge(note: peg.note, shift: peg.shift, animate: animate)
                        .frame(width: Self.width, alignment: onLeft ? .trailing : .leading)
                        .position(spot.center)
                }
            }
        }
    }

    /// A column per side: badges level with their pegs, nudged apart to stay legible, kept in the frame.
    private func place() -> [Spot?] {
        var spots = [Spot?](repeating: nil, count: posts.count)
        for side in [true, false] {
            let members = posts.indices.filter { left.indices.contains($0) && left[$0] == side }.sorted { posts[$0].y < posts[$1].y }
            guard !members.isEmpty else { continue }
            let xs = members.map { posts[$0].x }
            let inner = side ? (xs.min() ?? 0) - Self.reach : (xs.max() ?? 0) + Self.reach
            let wanted = members.map { posts[$0].y }
            var ys = wanted
            for k in ys.indices.dropFirst() { ys[k] = max(ys[k], ys[k - 1] + Self.pitch) }
            // Centred on its pegs again, then inside the frame.
            var delta = (wanted.reduce(0, +) - ys.reduce(0, +)) / CGFloat(ys.count)
            if let first = ys.first, first + delta < 16 { delta = 16 - first }
            if let last = ys.last, last + delta > size.height - 16 { delta = size.height - 16 - last }
            let half = Self.width / 2
            let x = side ? max(half + 2, inner - half) : min(size.width - half - 2, inner + half)
            let edgeX = side ? x + half + 3 : x - half - 3
            for (k, index) in members.enumerated() {
                let y = ys[k] + delta
                spots[index] = Spot(center: CGPoint(x: x, y: y), edge: CGPoint(x: edgeX, y: y))
            }
        }
        return spots
    }
}

/// A string's note with its move from standard: the adjust amber with the offset once moved, popping as it changes.
private struct PegBadge: View {
    let note: String
    let shift: Int
    let animate: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: note).font(Typeface.display(.body)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            if shift != 0 {
                Text(verbatim: shift > 0 ? "+\(shift)" : "\u{2212}\(-shift)")
                    .font(Typeface.number(.caption)).foregroundStyle(Palette.onAccent)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Palette.adjust))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(Palette.stage.opacity(0.88)))
        .overlay(Capsule().strokeBorder(shift != 0 ? Palette.adjust.opacity(0.7) : Palette.line, lineWidth: 1))
        .fixedSize()
        .animation(Motion.pluck, value: shift)
        .phaseAnimator([1.0, 1.12], trigger: shift) { content, scale in
            content.scaleEffect(CGFloat(animate ? scale : 1))
        } animation: { _ in Motion.pop }
    }
}

/// Many strings side by side (harps, zithers, koras): low strings long on the left, each peg lit in the amber of a
/// string to adjust, with its offset, once moved.
private struct StringFan: View {
    let pegs: [PegState]
    private static let fanLabel = Font.custom(Typeface.Face.medium.fontName, fixedSize: 10).monospacedDigit()

    var body: some View {
        Canvas { context, size in
            let count = pegs.count
            let inset: CGFloat = 22
            let spacing = (size.width - inset * 2) / CGFloat(max(1, count - 1))
            for (i, peg) in pegs.enumerated() {
                let along = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
                let x = inset + spacing * CGFloat(i)
                let top: CGFloat = 52 + along * 44
                let bottom = size.height - 26
                let moved = peg.shift != 0
                var string = Path()
                string.move(to: CGPoint(x: x, y: top))
                string.addLine(to: CGPoint(x: x, y: bottom))
                context.stroke(string, with: .color(moved ? Palette.adjust.opacity(0.9) : Palette.ink.opacity(0.4)), lineWidth: 1.8 - 0.9 * along)
                context.fill(Path(ellipseIn: CGRect(x: x - 3.5, y: top - 3.5, width: 7, height: 7)), with: .color(moved ? Palette.adjust : Palette.inkSoft))
                if moved {
                    let label = peg.shift > 0 ? "+\(peg.shift)" : "\u{2212}\(-peg.shift)"
                    // Drawn to the size of the fan (art, off the type scale), so dozens of strings keep their labels apart.
                    context.draw(Text(verbatim: label).font(Self.fanLabel).foregroundStyle(Palette.adjust),
                                 at: CGPoint(x: x, y: top - 12 - (i % 2 == 0 ? 0 : 12)))
                }
            }
        }
    }
}

/// Presents the paywall from whichever surface is on top (root, a sheet, a sheet's sheet).
struct PaywallHost: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    let active: Bool
    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { active && store.showPaywall }, set: { if !$0 { store.showPaywall = false } })) {
            PaywallView().environmentObject(store).environmentObject(commerce)
        }
    }
}

extension View {
    func paywallSheet(active: Bool = true) -> some View { modifier(PaywallHost(active: active)) }
}
