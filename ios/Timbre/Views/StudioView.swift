import SwiftUI
import TimbreCore

struct StudioView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("timbre_studio_title").font(TimbreTheme.title(32))
                Text("timbre_studio_subtitle").foregroundStyle(TimbreTheme.secondary)
                Panel {
                    Text("timbre_studio_tuning_desk").font(TimbreTheme.title(20))
                    HStack(spacing: 20) {
                        if let photo = store.photo { Image(photo.asset).resizable().scaledToFit().frame(width: 100, height: 120).accessibilityLabel(store.instrument.name.localized) }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.photo.map { NSLocalizedString("timbre_photo_" + $0.asset, value: $0.label, comment: "") } ?? store.instrument.name.localized).font(.headline)
                            Text(store.tuning.name.localized).foregroundStyle(TimbreTheme.secondary)
                            Button("timbre_tab_bench") { store.selectedTab = 1 }
                        }
                    }
                    Picker("timbre_studio_select_preset", selection: Binding(get: { store.tuning.id }, set: { id in
                        if let tuning = store.catalog.tuning(id: id) { store.selectTuning(tuning) }
                    })) {
                        ForEach(store.catalog.tunings.filter { $0.instrumentId == store.instrument.id }) { tuning in
                            Text(tuning.name.localized + (commerce.isPlus || tuning.isFree ? "" : " · Plus")).tag(tuning.id)
                        }
                    }.accessibilityIdentifier("studio.tuningPreset")
                    Text(store.courses.map { store.courseLabel($0) }.joined(separator: " · "))
                        .font(.subheadline.monospaced()).foregroundStyle(TimbreTheme.secondary)
                }
                Panel {
                    HStack { Text("timbre_studio_metronome").font(TimbreTheme.title(20)); Spacer(); if !commerce.isPlus { Label("Plus", systemImage: "lock") } }
                    Text("\(store.bpm)").font(TimbreTheme.number(60)).frame(maxWidth: .infinity).accessibilityLabel(String(format: NSLocalizedString("timbre_studio_tempo_value", comment: ""), store.bpm)).accessibilityIdentifier("studio.bpm")
                    Text("timbre_studio_beats_per_minute").font(.caption).foregroundStyle(TimbreTheme.secondary).frame(maxWidth: .infinity)
                    Stepper("timbre_studio_tempo", value: $store.bpm, in: 40...240).accessibilityIdentifier("studio.tempo")
                    Slider(value: Binding(get: { Double(store.bpm) }, set: { store.bpm = Int($0) }), in: 40...240, step: 1).accessibilityLabel("timbre_studio_tempo")
                    HStack {
                        Text("timbre_studio_beats_per_bar")
                        Spacer()
                        Picker("timbre_studio_beats_per_bar", selection: $store.beats) { ForEach([2, 3, 4, 6], id: \.self) { Text("\($0)").tag($0) } }.labelsHidden()
                    }
                    HStack {
                        Text("timbre_studio_subdivision")
                        Spacer()
                        Picker("timbre_studio_subdivision", selection: $store.subdivision) { ForEach(1...4, id: \.self) { Text("\($0)").tag($0) } }.labelsHidden()
                    }
                    Toggle("Accent first beat", isOn: $store.accents)
                    HStack {
                        Button("timbre_studio_tap_tempo") { if commerce.isPlus { store.tapTempo() } else { store.showPlus = true } }.buttonStyle(.bordered).accessibilityIdentifier("tapTempo")
                        Button { store.toggleMetronome() } label: { Label(audio.metronomeRunning ? NSLocalizedString("timbre_studio_stop_metronome", comment: "") : NSLocalizedString("timbre_studio_start_metronome", comment: ""), systemImage: audio.metronomeRunning ? "stop.fill" : "play.fill") }.buttonStyle(PrimaryButton()).accessibilityIdentifier("studio.startMetronome")
                    }
                    if store.accents { Text("timbre_studio_metronome_hint").font(.caption).foregroundStyle(TimbreTheme.secondary) }
                    if !commerce.isPlus { Text("timbre_studio_preview").font(.caption).foregroundStyle(TimbreTheme.secondary) }
                    if let error = audio.error { Text(error).foregroundStyle(TimbreTheme.warning).font(.caption) }
                }
                Panel {
                    Text("timbre_studio_recent_practice").font(TimbreTheme.title(20))
                    if !commerce.isPlus {
                        Text("timbre_studio_history_locked").foregroundStyle(TimbreTheme.secondary)
                        Button("timbre_studio_unlock_history") { store.showPlus = true }.buttonStyle(.bordered)
                    } else if store.records.isEmpty { Text("Your measured practice sessions will appear here.").foregroundStyle(TimbreTheme.secondary) }
                    else {
                        ForEach(store.records.filter { $0.instrumentId == store.instrument.id }.prefix(3)) { record in
                            HStack {
                                Text(record.date, style: .date)
                                Spacer()
                                if let cents = record.meanAbsoluteCents { Text(String(format: "%.1f ¢ average", cents)).monospacedDigit() }
                                else { Text("Accuracy unavailable") }
                            }.font(.subheadline)
                        }
                    }
                    NavigationLink("Practice history") { HistoryView() }
                    Text("timbre_studio_summary_privacy").font(.caption).foregroundStyle(TimbreTheme.secondary)
                }
            }.padding(22).frame(maxWidth: 850)
        }
        .frame(maxWidth: .infinity).background(TimbreTheme.canvas)
        .onChange(of: store.bpm) { _, _ in updateIfPlaying() }
        .onChange(of: store.beats) { _, _ in updateIfPlaying() }
        .onChange(of: store.subdivision) { _, _ in updateIfPlaying() }
        .onChange(of: store.accents) { _, _ in updateIfPlaying() }
    }
    private func updateIfPlaying() { if audio.metronomeRunning { store.updateMetronome() } }
}
