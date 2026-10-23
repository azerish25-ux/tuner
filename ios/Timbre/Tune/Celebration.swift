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
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundStyle(Palette.onAccent)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.6), radius: 24)
                        .symbolEffect(.bounce, value: visible)
                    Text("All strings in tune").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                    Text("\(store.instrumentDisplayName) · \(store.tuning.name.localized)").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    HStack(spacing: 6) {
                        ForEach(Array(store.courses.enumerated()), id: \.offset) { _, course in
                            let note = NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(course)).main)
                            (Text(note.name).font(Typeface.label(13)) + Text(note.octave).font(Typeface.label(9)))
                                .foregroundStyle(Palette.mint)
                                .frame(minWidth: 30, minHeight: 30)
                                .background(Circle().fill(Palette.mint.opacity(0.12)))
                        }
                    }
                    .accessibilityHidden(true)
                    HStack(spacing: 10) {
                        if let seconds = store.lastTuneSeconds, seconds > 0 {
                            Label("\(seconds) s", systemImage: "stopwatch.fill").foregroundStyle(Palette.ink)
                        }
                        Label("+\(XPReward.fullTune) XP", systemImage: "sparkles").foregroundStyle(Palette.mint)
                        if store.streak.current > 0 {
                            Label("\(store.streak.current)-day streak", systemImage: "flame.fill").foregroundStyle(Color(hex: 0xFFD3A8))
                        }
                    }
                    .font(Typeface.label(13))
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
                    // Tuned up: the natural moment to play something.
                    if let course = store.curriculum.courses.first(where: { $0.instrument == store.instrument.id }), let next = store.learn.nextLesson(in: course) {
                        Button {
                            dismiss()
                            UserDefaults.standard.set(course.id, forKey: "learn.course")
                            store.selectedTab = .learn
                        } label: {
                            Label("Ready to play: \(next.title.localized)", systemImage: "graduationcap.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint).lineLimit(1)
                        }
                        .padding(.top, 2)
                        .accessibilityIdentifier("celebration.lesson")
                    }
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
                                                         modelID: store.modelID, photo: store.photo?.asset, streak: store.streak.current, seconds: store.lastTuneSeconds))
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
                    let color = spark.hue > 0.6 ? Palette.amber : Palette.mint
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
    var seconds: Int?
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("TIMBRE").font(Typeface.label(13)).tracking(6).foregroundStyle(Palette.amber)
                Spacer()
                if streak > 1 { Label("\(streak)-day streak", systemImage: "flame.fill").font(Typeface.label(12)).foregroundStyle(Color(hex: 0xFFD3A8)) }
            }
            if let name = modelID.flatMap({ ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : nil }) ?? photo {
                Image(name).resizable().scaledToFit().frame(height: 300).shadow(color: .black.opacity(0.65), radius: 24, y: 14)
                    .background(Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.25), .clear], center: .center, startRadius: 2, endRadius: 160)).frame(width: 300, height: 40).offset(y: 150))
            }
            Text("In tune").font(Typeface.display(52)).tracking(-1.2).foregroundStyle(Palette.ink)
            if let seconds, seconds > 0 {
                Text("Every string in \(seconds) seconds").font(Typeface.label(16)).foregroundStyle(Palette.mint)
            }
            Text("\(instrument) · \(tuning)").font(.headline).foregroundStyle(Palette.inkSoft)
            HStack(spacing: 8) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note).font(Typeface.label(14)).foregroundStyle(Palette.mint)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(Capsule().fill(Palette.mint.opacity(0.12)))
                }
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(
            ZStack {
                Palette.stage
                RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 4, endRadius: 320)
            }
        )
        .environment(\.colorScheme, .dark)
    }
}
