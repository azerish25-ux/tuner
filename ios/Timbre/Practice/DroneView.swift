import SwiftUI
import TimbreCore

struct DroneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The rings give up height so the tonic card and the headphones hint end above the dock.
    @State private var ringsHeight: CGFloat = 250
    /// The selected tonic's highlight moves between keys.
    @Namespace private var tonics

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                rings.frame(height: ringsHeight)
                VStack(spacing: 4) {
                    Text(PitchMath.noteName(midi: store.droneMidi, notation: store.settings.notation)).font(Typeface.display(72)).foregroundStyle(Palette.ink)
                    Text(String(format: "Sa = %.1f Hz", PitchMath.frequency(midi: Double(store.droneMidi), reference: store.settings.referencePitchHz)))
                        .font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                }
                // VoiceOver: swipe up or down to move the tonic a semitone, across both octaves of the picker.
                .adjustableValue(Text("Tonic"), value: Text(verbatim: PitchMath.noteName(midi: store.droneMidi, notation: store.settings.notation) + ", "
                                     + String(format: "Sa = %.1f Hz", PitchMath.frequency(midi: Double(store.droneMidi), reference: store.settings.referencePitchHz))),
                                 increment: { store.setDrone(midi: min(71, store.droneMidi + 1)) },
                                 decrement: { store.setDrone(midi: max(48, store.droneMidi - 1)) })
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Tonic")
                    tonicGrid
                    Picker("Octave", selection: Binding(get: { store.droneMidi >= 60 ? 1 : 0 }, set: { store.setDrone(midi: store.droneMidi % 12 + ($0 == 1 ? 60 : 48)) })) {
                        Text("Low").tag(0); Text("High").tag(1)
                    }
                    .pickerStyle(.segmented)
                    Picker("Voice", selection: Binding(get: { store.droneVoice }, set: { store.setDrone(voice: $0) })) {
                        Text("Tanpura").tag(DroneRenderer.Voice.tanpura)
                        Text("Pure").tag(DroneRenderer.Voice.pure)
                    }
                    .pickerStyle(.segmented)
                }
                .stillCard()
                Label("Sing or play long notes against the drone. Headphones keep it out of the microphone.", systemImage: "headphones")
                    .font(.footnote).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .fitsHero($ringsHeight, in: 160...250)
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Drone")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock {
            Button { store.toggleDrone() } label: {
                Label(audio.droneRunning ? "Stop drone" : "Start drone", systemImage: audio.droneRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(BrassButtonStyle())
            .accessibilityIdentifier("drone.start")
        }
    }

    /// All twelve tonics at once, two rows of six in chromatic order (nothing hides past an edge); the
    /// selection slides from key to key (it simply moves with Reduce Motion).
    private var tonicGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<12, id: \.self) { pc in tonicKey(pc) }
        }
        .animation(reduceMotion ? Animation.easeInOut(duration: 0.15) : Motion.pluck, value: store.droneMidi % 12)
    }

    private func tonicKey(_ pc: Int) -> some View {
        let selected = store.droneMidi % 12 == pc
        let name = NoteNames.name(pc, preferFlats: [1, 3, 8, 10].contains(pc))
        return Button { store.setDrone(midi: 48 + pc + (store.droneMidi >= 60 ? 12 : 0)) } label: {
            Text(verbatim: name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(selected ? Palette.stage : Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if selected {
                        Capsule().fill(Palette.ink)
                            .matchedGeometryEffect(id: reduceMotion ? "tonic.\(pc)" : "tonic", in: tonics)
                    } else {
                        Capsule().fill(Palette.stageRaised).overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var rings: some View {
        TimelineView(.animation(paused: !audio.droneRunning || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // Rings travel from the core to just inside the canvas (half its short side, less the
                // line), so none is ever cut flat by the frame, however short the hero gets.
                let inner: CGFloat = 30
                let outer = max(inner, min(size.width, size.height) / 2 - 2)
                if audio.droneRunning {
                    for i in 0..<7 {
                        let phase = (t * 0.22 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                        let r = inner + CGFloat(phase) * (outer - inner)
                        // Eases in as it leaves the core and out as it reaches the edge.
                        let alpha = min(1, phase * 6) * (1 - phase) * 0.55
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Palette.locked.opacity(alpha)), lineWidth: 1.5)
                    }
                } else {
                    // At rest: one quiet ring, well inside the frame.
                    let r = inner + 0.78 * (outer - inner)
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Palette.locked.opacity(0.25)), lineWidth: 1.5)
                }
                let core = 46 + (audio.droneRunning ? 6 * sin(t * 2.1) : 0)
                context.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)),
                             with: .radialGradient(Gradient(colors: [Palette.brass.opacity(0.9), Palette.ember.opacity(0.2), .clear]), center: center, startRadius: 0, endRadius: core))
            }
        }
        .accessibilityHidden(true)
    }
}
