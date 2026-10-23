import AVFoundation
import Metal
import StoreKit
import SwiftUI
import TimbreCore

struct TuneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var motion = ReadoutMotion()
    private static let supports3D = MTLCreateSystemDefaultDevice() != nil

    var body: some View {
        ZStack {
            StageBackground()
            PitchAura().allowsHitTesting(false)
            GeometryReader { proxy in
                // Landscape and large iPad windows: the stage takes the left, tuning controls the right.
                let wide = proxy.size.width > proxy.size.height * 1.15
                VStack(spacing: 0) {
                    header
                    if wide {
                        HStack(spacing: 20) {
                            stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                tuningPanel
                                Spacer(minLength: 0)
                            }
                            .frame(width: min(560, proxy.size.width * 0.44))
                        }
                    } else {
                        stage.frame(maxHeight: .infinity)
                        tuningPanel.frame(maxWidth: 680)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            CelebrationOverlay()
        }
        .onAppear { autoListen() }
        .onChange(of: scenePhase) { _, phase in if phase == .active && store.selectedTab == .tune { autoListen() } }
        .onChange(of: store.requestReviewNow) { _, now in
            if now { requestReview(); store.requestReviewNow = false }
        }
        .sheet(isPresented: $store.showInstrumentPicker) { InstrumentPicker().presentationDetents([.large]).presentationBackground(Palette.stage) }
    }

    private func autoListen() {
        guard store.settings.onboardingCompleted == true, !audio.running, store.canListen,
              AVAudioApplication.shared.recordPermission == .granted else { return }
        store.startListening()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { store.showInstrumentPicker = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.instrumentDisplayName).font(Typeface.display(28, relativeTo: .title)).foregroundStyle(Palette.ink).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Palette.brass)
                    }
                    if !store.referenceMode {
                        Text(store.tuning.name.localized).font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    } else {
                        Text("Any note, any instrument").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tune.instrument")
            Spacer(minLength: 4)
            Menu {
                ForEach([415.0, 432, 435, 440, 442, 443], id: \.self) { hz in
                    Button { store.updateSettings { $0.referencePitchHz = hz } } label: {
                        if store.settings.referencePitchHz == hz { Label("A4 = \(Int(hz)) Hz", systemImage: "checkmark") } else { Text("A4 = \(Int(hz)) Hz") }
                    }
                }
                Button("More in Settings…") { store.showSettings = true }
            } label: {
                Text("A\(Text("4").font(.caption2)) \(Int(store.settings.referencePitchHz))").font(Typeface.number(14))
                    .foregroundStyle(Palette.ink).padding(.horizontal, 12).padding(.vertical, 8).glassCapsule()
            }
            .accessibilityLabel(Text("Reference pitch A4 \(Int(store.settings.referencePitchHz)) hertz"))
            Button { store.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40).glassCapsule()
            }
            .accessibilityLabel(Text("Settings")).accessibilityIdentifier("settings.open")
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 6)
    }

    private func stageInput() -> StageInput {
        StageInput(cents: store.live.reading.cents, level: store.live.level, locked: store.live.reading.inTune,
                   listening: audio.running, activeAnchor: store.activeAnchor, focus: audio.running && !store.referenceMode)
    }

    @ViewBuilder private var stage: some View {
        ZStack(alignment: .top) {
            if store.referenceMode {
                ChromaticStage(input: stageInput, note: store.targetName).padding(24)
            } else if let modelID = store.modelID {
                let rig = ModelLibrary.rig(modelID)
                if Self.supports3D && store.settings.stageMode != "studio" {
                    InstrumentStage(modelID: modelID, input: stageInput) { store.chooseAnchor($0) }
                } else {
                    StudioStage(imageName: ModelLibrary.cardImageName(modelID), rig: rig, input: stageInput) { store.chooseAnchor($0) }
                        .padding(.horizontal, 16)
                }
            } else if let photo = store.photo {
                StudioStage(imageName: photo.asset, rig: nil, input: stageInput).padding(28)
            }
            TurnHint().padding(.top, 8)
        }
        .accessibilityIdentifier("tune.stage")
    }

    private var readout: some View {
        TimelineView(.animation) { timeline in
            let reading = store.live.reading
            let _ = motion.step(audio.running ? reading.cents : (store.live.preserved ? reading.cents : nil), locked: reading.inTune, now: timeline.date.timeIntervalSinceReferenceDate)
            VStack(spacing: 10) {
                NoteReadout(note: store.targetName, cents: motion.cents, hertz: reading.frequency, target: store.targetHz, locked: reading.inTune)
                StrobeBand(cents: motion.cents, phase: motion.phase, locked: reading.inTune, active: motion.cents != nil)
                    .frame(height: 22).padding(.horizontal, 36)
                CentsScale(cents: motion.cents, locked: reading.inTune).frame(height: 34).padding(.horizontal, 28)
                Text(store.statusText).font(.subheadline.weight(.semibold))
                    .foregroundStyle(reading.inTune ? Palette.locked : Palette.inkSoft)
                    .contentTransition(.opacity)
                    .animation(Motion.quick, value: store.statusText)
                    .accessibilityIdentifier("tune.status")
            }
        }
        .padding(.bottom, 6)
    }

    private var tuningPanel: some View {
        VStack(spacing: 0) {
            readout
            StringRail().opacity(store.referenceMode ? 0 : 1).frame(height: store.referenceMode ? 8 : nil)
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            Button { store.automatic.toggle(); Haptics.shared.selection() } label: {
                VStack(spacing: 3) {
                    Image(systemName: store.automatic ? "wand.and.stars" : "hand.tap").font(.title3)
                    Text(store.automatic ? "Auto" : "Manual").font(.caption2.weight(.semibold))
                }
                .foregroundStyle(store.automatic ? Palette.brass : Palette.inkSoft)
                .frame(width: 64, height: 56)
                .glassCapsule()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(store.automatic ? "Automatic string detection on" : "Manual string selection"))
            .accessibilityIdentifier("tune.auto")
            ListenOrb()
            Button { store.toggleTone() } label: {
                VStack(spacing: 3) {
                    Image(systemName: audio.tonePlaying ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.title3)
                    Text(audio.tonePlaying ? "Stop" : "Hear").font(.caption2.weight(.semibold))
                }
                .foregroundStyle(audio.tonePlaying ? Palette.brass : Palette.inkSoft)
                .frame(width: 64, height: 56)
                .glassCapsule()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(audio.tonePlaying ? "Stop reference tone" : "Play reference tone"))
            .accessibilityIdentifier("tune.tone")
        }
        .padding(.top, 6).padding(.bottom, 10)
    }
}

/// The main listen control: gold when listening, its halo breathing with the input level.
struct ListenOrb: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    var body: some View {
        let level = audio.running ? max(0, min(1, (store.live.level + 60) / 45)) : 0
        Button { store.toggleListening(); Haptics.shared.selection() } label: {
            ZStack {
                Circle().fill(Palette.brass.opacity(0.18)).frame(width: 96, height: 96).scaleEffect(1 + level * 0.28).opacity(audio.running ? 1 : 0)
                Circle().fill(audio.running ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF1D69E), Color(hex: 0xC8954A)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.stageRaised))
                    .frame(width: 78, height: 78)
                    .overlay(Circle().strokeBorder(audio.running ? .white.opacity(0.35) : Palette.line, lineWidth: 1))
                    .shadow(color: Palette.ember.opacity(audio.running ? 0.45 : 0), radius: 20, y: 6)
                Image(systemName: audio.running ? "pause.fill" : "mic.fill").font(.title2.weight(.bold))
                    .foregroundStyle(audio.running ? Color(hex: 0x1A1206) : Palette.brass)
            }
            .animation(.easeOut(duration: 0.12), value: level)
            .animation(Motion.pluck, value: audio.running)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(audio.running ? "Pause listening" : "Listen"))
        .accessibilityIdentifier("listenButton")
    }
}

/// Warm or cool light behind the stage that follows the pitch.
struct PitchAura: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let reading = store.live.reading
        let color = Palette.pitch(reading.cents, locked: reading.inTune)
        RadialGradient(colors: [color.opacity(reading.cents == nil ? 0 : (reading.inTune ? 0.28 : 0.14)), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 360)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.35), value: reading.inTune)
    }
}

/// "Tighten" / "Loosen" with the turn direction of the selected peg.
struct TurnHint: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    var body: some View {
        let reading = store.live.reading
        if audio.running, !store.referenceMode, let cents = reading.cents, !reading.inTune, abs(cents) >= 3 {
            let tighten = cents < 0
            let sign = store.modelID.flatMap { ModelLibrary.rig($0)?.string(store.activeAnchor)?.tighten } ?? 1
            let clockwise = (tighten ? 1 : -1) * sign > 0
            Label(tighten ? "Tighten" : "Loosen", systemImage: clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tighten ? Palette.flat : Palette.sharp)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCapsule(interactive: false)
                .symbolEffect(.rotate, options: .repeating, isActive: true)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityHidden(true)
        }
    }
}
