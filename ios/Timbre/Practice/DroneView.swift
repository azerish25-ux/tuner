import SwiftUI
import TimbreCore

/// The drone as a tanpura: its four strings plucked in turn on the drone's own clock around a dial of tonics you
/// turn by hand, and with the microphone on, your sung or played pitch traced against the nearest swara inside a
/// ±5¢ band.
struct DroneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    /// The tanpura gives up height so the controls end above the dock where they can.
    @State private var heroHeight: CGFloat = 290
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
                // The tonic is the dial itself, at the top; its octave, voice and first string sit right under it,
                // above the sing-along card, so none of them rests under the Start button.
                hero
                settings
                DroneSingAlongCard(model: singAlong, listening: listening && audio.running, tonicPc: store.droneMidi % 12, notation: notation,
                                   headphones: audio.headphones, permissionDenied: audio.permissionDenied, toggle: toggleListening)
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

    /// The tanpura, whose gourd is the tonic dial: drag round it to turn (a tick at every note), or tap a note.
    /// The octave stays as picked below; the dial chooses the note within it.
    private var hero: some View {
        TanpuraHero(tonicPc: store.droneMidi % 12, tonicName: tonicName, notation: notation, saHz: saHz, fifth: fifth,
                    pure: store.droneVoice == .pure, running: audio.droneRunning, clock: { audio.droneOrigin() },
                    onSelect: { pc in setTonic(48 + pc + (store.droneMidi >= 60 ? 12 : 0)) })
            .frame(height: heroHeight)
            // VoiceOver: swipe up or down to move the tonic a semitone, across both octaves.
            .adjustableValue(Text("Tonic"), value: Text(verbatim: tonicName + ", " + String(format: "Sa = %.1f Hz", saHz)),
                             increment: { setTonic(min(71, store.droneMidi + 1)) },
                             decrement: { setTonic(max(48, store.droneMidi - 1)) })
            .accessibilityIdentifier("drone.dial")
    }

    // MARK: Settings

    /// The rest of the drone, one labelled row each, the controls lined up in one column.
    private var settings: some View {
        VStack(spacing: 12) {
            settingRow("Octave") {
                Picker("Octave", selection: Binding(get: { store.droneMidi >= 60 ? 1 : 0 }, set: { setTonic(store.droneMidi % 12 + ($0 == 1 ? 60 : 48)) })) {
                    Text("Low").tag(0); Text("High").tag(1)
                }
            }
            settingRow("Voice") {
                Picker("Voice", selection: Binding(get: { store.droneVoice }, set: { setVoice($0) })) {
                    Text("Tanpura").tag(DroneRenderer.Voice.tanpura)
                    Text("Pure").tag(DroneRenderer.Voice.pure)
                }
            }
            settingRow("First string") {
                Picker("First string", selection: Binding(get: { fifth }, set: { setFirstString(fifth: $0) })) {
                    Text(verbatim: "Pa").tag(true)
                    Text(verbatim: "Ma").tag(false)
                }
            }
        }
        .stillCard()
    }

    /// A name on the left (the picker carries it for VoiceOver) and its segmented control on the right; large
    /// text stacks the two.
    private func settingRow<Control: View>(_ title: LocalizedStringKey, @ViewBuilder control: () -> Control) -> some View {
        let name = Text(title).font(.subheadline).foregroundStyle(Palette.inkSoft).accessibilityHidden(true)
        let picker = control().pickerStyle(.segmented)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                name.lineLimit(1)
                Spacer(minLength: 8)
                picker.frame(width: 184)
            }
            VStack(alignment: .leading, spacing: 8) {
                name.fixedSize(horizontal: false, vertical: true)
                picker
            }
        }
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
