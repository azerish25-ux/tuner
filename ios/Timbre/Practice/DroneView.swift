import SwiftUI
import TimbreCore

/// The drone as a tanpura: its four strings plucked in turn on the drone's own clock around a dial of tonics, and
/// with the microphone on, your sung or played pitch traced against the nearest swara inside a ±5¢ band.
struct DroneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The tanpura gives up height so the controls end above the dock where they can.
    @State private var heroHeight: CGFloat = 290
    /// The selected tonic's highlight moves between keys.
    @Namespace private var tonics
    /// The first string: Pa (a fifth below Sa, most ragas) or Ma (a fourth, for ragas without Pa).
    @AppStorage("drone.firstString") private var firstString = "pa"
    @StateObject private var singAlong = DroneSingAlong()
    /// The microphone is on for this screen (the store's lesson microphone, owned by `owner`).
    @State private var listening = false
    @State private var owner = UUID()

    private var fifth: Bool { firstString != "ma" }
    private var saHz: Double { PitchMath.frequency(midi: Double(store.droneMidi), reference: store.settings.referencePitchHz) }
    private var notation: String { store.settings.notation }
    /// The app's one spelling (D♭ E♭ A♭ B♭ flat, F♯ sharp) in the player's note names.
    private var tonicName: String { VoiceNoteName.name(store.droneMidi, notation: notation) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                DroneSingAlongCard(model: singAlong, listening: listening && audio.running, tonicPc: store.droneMidi % 12, notation: notation,
                                   headphones: audio.headphones, permissionDenied: audio.permissionDenied, toggle: toggleListening)
                settings
                Label("Sing or play long notes against the drone. Headphones keep it out of the microphone.", systemImage: "headphones")
                    .font(.footnote).foregroundStyle(listening && !audio.headphones ? Palette.amber : Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 4).padding(.bottom, 28)
        }
        .fitsHero($heroHeight, in: 260...290)
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Drone")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock {
            Button { toggleDrone() } label: {
                Label(audio.droneRunning ? "Stop drone" : "Start drone", systemImage: audio.droneRunning ? "stop.fill" : "play.fill")
            }
            .buttonStyle(BrassButtonStyle())
            .accessibilityIdentifier("drone.start")
        }
        .onAppear(perform: conform)
        .onChange(of: audio.droneRunning) { _, _ in conform() }
        .onChange(of: store.droneMidi) { _, _ in
            singAlong.reset()
            if listening { store.gameTargetHz = saHz }
        }
        .onChange(of: audio.running) { _, running in
            // The microphone stopped on its own (the app went to the background, an interruption).
            if !running && listening { stopListening() }
        }
        .onDisappear(perform: stopListening)
    }

    // MARK: Hero

    private var hero: some View {
        TanpuraHero(tonicPc: store.droneMidi % 12, tonicName: tonicName, notation: notation, saHz: saHz, fifth: fifth,
                    pure: store.droneVoice == .pure, running: audio.droneRunning, clock: { audio.droneOrigin() })
            .frame(height: heroHeight)
            // VoiceOver: swipe up or down to move the tonic a semitone, across both octaves of the picker.
            .adjustableValue(Text("Tonic"), value: Text(verbatim: tonicName + ", " + String(format: "Sa = %.1f Hz", saHz)),
                             increment: { setTonic(min(71, store.droneMidi + 1)) },
                             decrement: { setTonic(max(48, store.droneMidi - 1)) })
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Tonic")
            tonicGrid
            Picker("Octave", selection: Binding(get: { store.droneMidi >= 60 ? 1 : 0 }, set: { setTonic(store.droneMidi % 12 + ($0 == 1 ? 60 : 48)) })) {
                Text("Low").tag(0); Text("High").tag(1)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 10) {
                Picker("Voice", selection: Binding(get: { store.droneVoice }, set: { setVoice($0) })) {
                    Text("Tanpura").tag(DroneRenderer.Voice.tanpura)
                    Text("Pure").tag(DroneRenderer.Voice.pure)
                }
                .pickerStyle(.segmented)
                Picker("First string", selection: Binding(get: { fifth }, set: { setFirstString(fifth: $0) })) {
                    Text(verbatim: "Pa").tag(true)
                    Text(verbatim: "Ma").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 132)
            }
        }
        .stillCard()
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
        let name = VoiceNoteName.pitchClass(pc, notation: notation)
        return Button { setTonic(48 + pc + (store.droneMidi >= 60 ? 12 : 0)) } label: {
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

    // MARK: Actions

    private func toggleDrone() {
        store.toggleDrone()
        conform()
    }

    private func setTonic(_ midi: Int) {
        store.setDrone(midi: midi)
        conform()
    }

    private func setVoice(_ voice: DroneRenderer.Voice) {
        store.setDrone(voice: voice)
        conform()
    }

    private func setFirstString(fifth: Bool) {
        firstString = fifth ? "pa" : "ma"
        Haptics.shared.selection()
        conform()
    }

    /// The store starts and retunes the drone with Pa on its first string: with Ma chosen, the running drone is
    /// retuned at once (in the same turn, before it is heard).
    private func conform() {
        guard audio.droneRunning, audio.droneFifth != fifth else { return }
        audio.setDrone(tonic: saHz, voice: store.droneVoice, fifth: fifth)
    }

    // MARK: Microphone

    private func toggleListening() {
        if listening && audio.running { stopListening() } else { startListening() }
    }

    /// The tuner's own pitch pipeline (the store's lesson microphone): readings arrive here instead of the tuner.
    private func startListening() {
        singAlong.reset()
        listening = true
        let model = singAlong
        // The demo pitch (UI tests, screenshots) sings Sa.
        store.gameTargetHz = saHz
        store.startLessonListening(owner: owner, lowHz: 55, highHz: 1600) { [weak store] hz, _ in
            guard let store else { return }
            let sa = PitchMath.frequency(midi: Double(store.droneMidi), reference: store.settings.referencePitchHz)
            model.accept(hz, sa: sa)
        }
        Haptics.shared.selection()
    }

    private func stopListening() {
        guard listening else { return }
        listening = false
        store.stopLessonListening(owner: owner)
        singAlong.reset()
    }
}
