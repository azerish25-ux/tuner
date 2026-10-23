import SwiftUI
import TimbreCore

struct DroneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                rings.frame(height: 250)
                VStack(spacing: 4) {
                    Text(PitchMath.noteName(midi: store.droneMidi, notation: store.settings.notation)).font(Typeface.display(72)).foregroundStyle(Palette.ink)
                    Text(String(format: "Sa = %.1f Hz", PitchMath.frequency(midi: Double(store.droneMidi), reference: store.settings.referencePitchHz)))
                        .font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Tonic")
                    // Runs to the card's edge (its 18 pt inset) so tonics scroll under it instead of being cut.
                    EdgeRail(bleed: 18, spacing: 6, selection: store.droneMidi % 12) {
                        ForEach(0..<12, id: \.self) { pc in
                            let midi = 48 + pc
                            Button(NoteNames.name(pc, preferFlats: [1, 3, 8, 10].contains(pc))) { store.setDrone(midi: midi + (store.droneMidi >= 60 ? 12 : 0)) }
                                .buttonStyle(ChipButtonStyle(selected: store.droneMidi % 12 == pc))
                                .id(pc)
                        }
                    }
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
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
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

    private var rings: some View {
        TimelineView(.animation(paused: !audio.droneRunning || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<7 {
                    let phase = (t * 0.22 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                    let r = 30 + phase * min(size.width, size.height) * 0.5
                    let alpha = audio.droneRunning ? (1 - phase) * 0.55 : (i == 0 ? 0.25 : 0)
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Palette.locked.opacity(alpha)), lineWidth: 1.5)
                }
                let core = 46 + (audio.droneRunning ? 6 * sin(t * 2.1) : 0)
                context.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2)),
                             with: .radialGradient(Gradient(colors: [Palette.brass.opacity(0.9), Palette.ember.opacity(0.2), .clear]), center: center, startRadius: 0, endRadius: core))
            }
        }
        .accessibilityHidden(true)
    }
}
