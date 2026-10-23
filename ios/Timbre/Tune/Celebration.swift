import SwiftUI
import TimbreCore

/// All strings in tune: a burst of light, a chord of haptics and a card to share.
struct CelebrationOverlay: View {
    @EnvironmentObject private var store: AppStore
    @State private var visible = false
    @State private var started = Date()
    @State private var card: Image?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { dismiss() }
                if !reduceMotion { Burst(started: started).allowsHitTesting(false) }
                VStack(spacing: 14) {
                    Eyebrow("Still point")
                    Text("All strings in tune").font(Typeface.display(38)).foregroundStyle(Palette.locked).multilineTextAlignment(.center)
                    Text("\(store.instrumentDisplayName) · \(store.tuning.name.localized)").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    HStack(spacing: 12) {
                        if let card {
                            ShareLink(item: card, preview: SharePreview("In tune with Timbre", image: card)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(BrassButtonStyle())
                        }
                        Button("Done") { dismiss() }.buttonStyle(BrassButtonStyle(prominent: false))
                    }
                    .padding(.top, 6)
                }
                .padding(26)
                .stillCard(cornerRadius: 30, padding: 22)
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(Motion.pluck, value: visible)
        .onChange(of: store.celebrate) { _, _ in
            started = Date()
            visible = true
            renderCard()
            Task { try? await Task.sleep(for: .seconds(6)); if visible { dismiss() } }
        }
    }

    private func dismiss() { visible = false }

    private func renderCard() {
        let renderer = ImageRenderer(content: ShareCard(instrument: store.instrumentDisplayName, tuning: store.tuning.name.localized,
                                                         notes: store.courses.map { TargetLabelFormatter.splitCue(store.courseLabel($0)).main },
                                                         modelID: store.modelID, photo: store.photo?.asset, streak: store.streak.current))
        renderer.scale = displayScale
        if let image = renderer.uiImage { card = Image(uiImage: image) }
    }
}

private struct Burst: View {
    let started: Date
    private struct Spark { let angle, speed, size, hue: Double }
    private static let sparks: [Spark] = {
        var g = SystemRandom(seed: 5)
        return (0..<90).map { _ in Spark(angle: g.next() * 2 * .pi, speed: 120 + 320 * g.next(), size: 1.5 + 3.5 * g.next(), hue: g.next()) }
    }()
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(started)
                guard t < 2.4 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let ring = 40 + t * 380
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                               with: .color(Palette.locked.opacity(max(0, 0.5 - t * 0.3))), lineWidth: 2)
                for spark in Self.sparks {
                    let d = spark.speed * t * (1 - t / 4)
                    let p = CGPoint(x: center.x + cos(spark.angle) * d, y: center.y + sin(spark.angle) * d + 60 * t * t)
                    let alpha = max(0, 1 - t / 2.2)
                    let color = spark.hue > 0.5 ? Palette.brass : Palette.locked
                    context.fill(Path(ellipseIn: CGRect(x: p.x - spark.size, y: p.y - spark.size, width: spark.size * 2, height: spark.size * 2)), with: .color(color.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// The shareable "in tune" card.
struct ShareCard: View {
    let instrument: String
    let tuning: String
    let notes: [String]
    let modelID: String?
    let photo: String?
    let streak: Int
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("TIMBRE").font(.system(size: 13, weight: .bold)).tracking(5).foregroundStyle(Palette.brass)
                Spacer()
                if streak > 1 { Label("\(streak)-day streak", systemImage: "flame.fill").font(.caption.weight(.semibold)).foregroundStyle(Palette.ember) }
            }
            if let name = modelID.map(ModelLibrary.cardImageName) ?? photo {
                Image(name).resizable().scaledToFit().frame(height: 300).shadow(color: .black.opacity(0.6), radius: 24, y: 14)
            }
            Text("In tune").font(Typeface.display(54)).foregroundStyle(Color(hex: 0xFFF3DA))
            Text("\(instrument) · \(tuning)").font(.headline).foregroundStyle(Color(hex: 0xB3A99E))
            Text(notes.joined(separator: "  ")).font(Typeface.number(15)).foregroundStyle(Color(hex: 0xD9B26F))
        }
        .padding(30)
        .frame(width: 400)
        .background(LinearGradient(colors: [Color(hex: 0x1B1512), Color(hex: 0x0B0908)], startPoint: .top, endPoint: .bottom))
        .environment(\.colorScheme, .dark)
    }
}
