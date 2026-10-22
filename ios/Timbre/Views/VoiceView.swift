import SwiftUI
import TimbreCore

@MainActor
struct VoiceView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @EnvironmentObject private var audio: AudioService
    @State private var hidePreviousResult = false

    private var exercise: VoiceExercise { store.voiceExercise }
    private var targetMidi: Int { store.voiceRunning && store.countdown == 0 ? store.voiceTargetMidi : store.voiceRoot }
    private var suggestedLevel: Int {
        let best = store.demonstratedLevels.max() ?? 0
        return best == 6 ? 8 : min(best + 1, 8)
    }
    private func text(_ key: String, _ fallback: String) -> String { NSLocalizedString(key, value: fallback, comment: "") }
    private func note(_ midi: Int) -> String { PitchMath.noteName(midi: midi, notation: store.settings.notation) }
    private func exerciseName(_ level: Int) -> String {
        let suffix = ["1", "2", "3", "4", "interval", "melody", "range", "song"][level - 1]
        return text("timbre_voice_exercise_" + suffix, VoiceExercise(level: level).name)
    }
    private var exerciseInstructions: String {
        switch exercise.level {
        case 1: return text("timbre_voice_easy_note", "An easy note, without a score")
        case 7: return text("timbre_voice_range_plan_hint", "Start on an easy note. Follow the notes down and up. Skip any note that strains.")
        case 5, 6, 8: return text("timbre_voice_message_pattern_ready", "Hear the pattern, then sing each note in turn.")
        default: return text("timbre_voice_message_hear_then_sing", "Hear the target, then sing a comfortable, steady note.")
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading
                if !commerce.isPlus { plusPreview }
                plan
                target
                practice
                if let result = store.voiceResult, !hidePreviousResult { resultPanel(result) }
                Text(text("timbre_voice_privacy", "Audio is analysed on this device. Only a practice summary is saved."))
                    .font(.footnote).foregroundStyle(TimbreTheme.secondary)
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TimbreTheme.canvas)
        .foregroundStyle(TimbreTheme.primary)
        .navigationTitle("timbre_voice_title")
        .onChange(of: store.voiceLevel) { _, _ in hidePreviousResult = true; audio.stopTone() }
        .onChange(of: store.voiceRoot) { _, _ in hidePreviousResult = true; audio.stopTone() }
        .onChange(of: store.voiceResult) { _, result in if result != nil { hidePreviousResult = false } }
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("timbre_voice_subtitle").font(TimbreTheme.title(32))
            Text(text("timbre_voice_message_initial", "Choose a comfortable note, listen to it, then sing it."))
                .foregroundStyle(TimbreTheme.secondary)
        }
    }
    private var plusPreview: some View {
        Panel {
            Label("Singing practice", systemImage: "waveform").font(.headline)
            Text(text("timbre_voice_practice_preview", "Preview any exercise. Singing practice is included in the one-time full unlock."))
            Button("Explore Timbre Plus") { store.showPlus = true }.buttonStyle(PrimaryButton())
        }
    }
    private var plan: some View {
        Panel {
            Text(text("timbre_voice_practice_plan", "Practice plan")).font(TimbreTheme.title(22))
            Text("Suggested next: \(exerciseName(suggestedLevel)). Choose any exercise at any time.")
                .font(.footnote).foregroundStyle(TimbreTheme.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], spacing: 10) {
                ForEach(1...8, id: \.self) { level in
                    Button {
                        guard !store.voiceRunning else { return }
                        store.voiceLevel = level
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(level)).font(.caption.monospaced()).foregroundStyle(TimbreTheme.secondary)
                                Spacer()
                                if store.demonstratedLevels.contains(level) { Image(systemName: "checkmark.circle.fill").foregroundStyle(TimbreTheme.success) }
                            }
                            Text(exerciseName(level)).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading).padding(12)
                        .background(store.voiceLevel == level ? TimbreTheme.brass.opacity(0.14) : TimbreTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.voiceLevel == level ? TimbreTheme.brass : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.voiceRunning)
                    .accessibilityLabel("Exercise \(level), \(exerciseName(level))\(store.demonstratedLevels.contains(level) ? ", demonstrated" : "")")
                    .accessibilityAddTraits(store.voiceLevel == level ? [.isSelected] : [])
                    .accessibilityIdentifier("voice.exercise.\(level)")
                }
            }
        }
    }
    private var target: some View {
        Panel {
            Text(exerciseName(exercise.level)).font(TimbreTheme.title(24))
            Text(exerciseInstructions).foregroundStyle(TimbreTheme.secondary)
            Text(String(format: text("timbre_voice_hold_requirement", "%1$@ s hold · ±%2$d cents"), String(format: "%.1f", Double(exercise.holdMs) / 1000), Int(exercise.toleranceCents)))
                .font(.footnote.monospaced())
            Picker("Starting note", selection: $store.voiceRoot) {
                ForEach(45...81, id: \.self) { midi in Text(note(midi)).tag(midi) }
            }.disabled(store.voiceRunning).accessibilityIdentifier("voice.root")
            if exercise.notes.count > 1 {
                Text(text("timbre_voice_sequence_target", "Sing these notes")).font(.caption).foregroundStyle(TimbreTheme.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 8) {
                    ForEach(Array(exercise.notes.enumerated()), id: \.offset) { index, midi in
                        let current = store.voiceRunning && store.countdown == 0 && exercise.noteIndex(at: store.voiceElapsed) == index
                        Text(note(midi)).font(.subheadline.monospaced()).padding(.vertical, 12).frame(maxWidth: .infinity)
                            .foregroundStyle(current ? TimbreTheme.ink : TimbreTheme.primary)
                            .background(current ? TimbreTheme.brass : TimbreTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Note \(index + 1), \(note(midi))\(current ? ", current target" : "")")
                    }
                }
            }
            Button {
                guard commerce.isPlus else { store.showPlus = true; return }
                if audio.tonePlaying { audio.stopTone() }
                else { audio.playTone(PitchMath.frequency(midi: Double(store.voiceRoot), reference: store.settings.referencePitchHz)) }
            } label: {
                Label(audio.tonePlaying ? text("timbre_voice_playing_target", "Playing target…") : text("timbre_voice_hear_target", "Hear target"), systemImage: audio.tonePlaying ? "stop.fill" : "speaker.wave.2")
            }.buttonStyle(.bordered).disabled(store.voiceRunning).accessibilityIdentifier("voice.hearTarget")
            Text(text("timbre_voice_comfort", "Keep the note comfortable. Stop if your voice feels strained."))
                .font(.footnote).foregroundStyle(TimbreTheme.secondary)
        }
    }
    private var practice: some View {
        Panel {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target").font(.caption).foregroundStyle(TimbreTheme.secondary)
                    Text(note(targetMidi)).font(TimbreTheme.number(40))
                }
                Spacer()
                if store.voiceRunning && store.countdown > 0 {
                    Text(String(format: text("timbre_voice_ready_in", "Ready in %1$d"), store.countdown)).font(TimbreTheme.title(24)).accessibilityAddTraits(.updatesFrequently)
                } else if store.voiceRunning {
                    liveReading
                } else { Text("Ready").foregroundStyle(TimbreTheme.secondary) }
            }
            VoicePitchTrace(values: hidePreviousResult ? [] : store.trace, tolerance: exercise.toleranceCents)
                .frame(height: 170)
                .accessibilityLabel(store.trace.contains(where: { $0 != nil }) ? "Measured pitch relative to each target. Shaded band is plus or minus \(Int(exercise.toleranceCents)) cents. Gaps indicate no measured pitch." : text("timbre_voice_graph_placeholder", "Your pitch appears here"))
            if store.voiceRunning && store.countdown == 0 {
                ProgressView(value: Double(store.voiceElapsed), total: Double(exercise.durationMs))
                    .tint(TimbreTheme.brass).accessibilityLabel("Exercise time")
                Text("\(Double(store.voiceElapsed) / 1000, specifier: "%.1f") / \(Double(exercise.durationMs) / 1000, specifier: "%.1f") s")
                    .font(.caption.monospaced()).foregroundStyle(TimbreTheme.secondary)
                Text("\(text("timbre_voice_continuous_hold", "Continuous in-tune hold")): \(Double(store.voiceLiveHoldMs) / 1000, specifier: "%.1f") s")
                    .font(.footnote).foregroundStyle(TimbreTheme.success)
            }
            if store.voiceRunning {
                Button("timbre_voice_stop_practice", role: .destructive) { store.cancelVoice() }.buttonStyle(.bordered).frame(maxWidth: .infinity)
            } else {
                Button(store.voiceResult == nil ? text("timbre_voice_start_practice", "Start practice") : text("timbre_voice_try_again", "Try again")) { hidePreviousResult = false; store.startVoice() }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("voice.start")
            }
        }
    }
    private var liveReading: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let hz = store.reading.frequency, let cents = store.reading.cents {
                Text("\(cents > 0 ? "+" : "")\(cents, specifier: "%.0f") ¢").font(TimbreTheme.number(28))
                    .foregroundStyle(store.reading.stable && abs(cents) <= exercise.toleranceCents ? TimbreTheme.success : TimbreTheme.primary)
                Text("\(hz, specifier: "%.1f") Hz").font(.caption.monospaced()).foregroundStyle(TimbreTheme.secondary)
                Text(store.reading.stable ? "Clear pitch" : "Settling").font(.caption).foregroundStyle(TimbreTheme.secondary)
            } else { Text(text("timbre_voice_no_clear_pitch", "No clear pitch")).font(.subheadline).foregroundStyle(TimbreTheme.secondary) }
        }.accessibilityElement(children: .combine)
    }
    private func resultPanel(_ result: VoiceResult) -> some View {
        Panel {
            Text(text("timbre_voice_last_attempt", "Your last attempt")).font(TimbreTheme.title(24))
            HStack(alignment: .top, spacing: 24) {
                resultMetric(text("timbre_voice_accuracy", "Accuracy"), value: result.accuracy)
                resultMetric(text("timbre_voice_steadiness", "Steadiness"), value: result.stability)
            }
            if exercise.level == 7 {
                if let low = result.lowestMidi, let high = result.highestMidi {
                    Text("Reliable notes: \(note(low))–\(note(high))").font(.headline)
                    Text("A description of notes reached in this walk, not a clinical voice classification.").font(.footnote).foregroundStyle(TimbreTheme.secondary)
                } else { Text(text("timbre_voice_range_no_result", "No reliable range yet. Try two comfortable notes.")) }
            }
            Text(result.explanation).foregroundStyle(TimbreTheme.secondary)
            if result.longestHoldMs > 0 {
                Text("Measured hold: \(Double(result.longestHoldMs) / 1000, specifier: "%.1f") s").font(.footnote.monospaced())
            }
            if let percent = result.inBandPercent { Text("\(percent)% of readings inside the target band").font(.footnote) }
            if let percent = result.contourPercent { Text("Melody direction matched \(percent)% of the time").font(.footnote) }
            if result.demonstrated { Label("Skill demonstrated", systemImage: "checkmark.circle.fill").foregroundStyle(TimbreTheme.success) }
            if exercise.level < 8 {
                Button(text("timbre_voice_next_exercise", "Next exercise →")) { store.voiceLevel = exercise.level + 1 }
                    .buttonStyle(.bordered)
            }
        }
    }
    private func resultMetric(_ title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(TimbreTheme.secondary)
            if let value { Text("\(value)/100").font(TimbreTheme.number(24)) }
            else { Text(text("timbre_voice_not_measured", "Not measured")).font(.subheadline) }
        }.accessibilityElement(children: .combine)
    }
}

private struct VoicePitchTrace: View {
    let values: [Double?]
    let tolerance: Double
    var body: some View {
        Canvas { context, size in
            let extent = max(100.0, tolerance * 2)
            let center = size.height / 2
            let halfBand = CGFloat(tolerance / extent) * center
            let band = CGRect(x: 0, y: center - halfBand, width: size.width, height: halfBand * 2)
            context.fill(Path(roundedRect: band, cornerRadius: 8), with: .color(TimbreTheme.success.opacity(0.12)))
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: center)); centerLine.addLine(to: CGPoint(x: size.width, y: center))
            context.stroke(centerLine, with: .color(TimbreTheme.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            var path = Path(), connected = false
            for (index, value) in values.enumerated() {
                guard let value, value.isFinite else { connected = false; continue }
                let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * size.width
                let y = center - CGFloat(min(extent, max(-extent, value)) / extent) * center
                let point = CGPoint(x: x, y: y)
                if connected { path.addLine(to: point) } else {
                    path.move(to: point)
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(TimbreTheme.brass))
                }
                connected = true
            }
            context.stroke(path, with: .color(TimbreTheme.brass), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .background(TimbreTheme.canvas, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
    }
}
