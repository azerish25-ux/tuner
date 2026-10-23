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
    private func text(_ key: String, _ fallback: String) -> String { NSLocalizedString(key, value: fallback, comment: "") }
    private func note(_ midi: Int) -> String { PitchMath.noteName(midi: midi, notation: store.settings.notation) }
    private func exerciseName(_ level: Int) -> String {
        let suffix = ["1", "2", "3", "4", "interval", "melody", "range", "song"][level - 1]
        return text("timbre_voice_exercise_" + suffix, VoiceExercise(level: level).name)
    }
    private func locked(_ level: Int) -> Bool { !commerce.isPro && level != 7 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(text("timbre_voice_message_initial", "Choose a comfortable note, listen to it, then sing it.")).font(.subheadline).foregroundStyle(Palette.inkSoft)
                exercises
                practice
                target
                if let result = store.voiceResult, !hidePreviousResult { resultPanel(result) }
                Label(text("timbre_voice_privacy", "Audio is analysed on this device. Only a practice summary is saved."), systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !commerce.isPro && store.voiceLevel != 7 { store.voiceLevel = 7 } }
        .onDisappear { store.cancelVoice() }
        .onChange(of: store.voiceLevel) { _, _ in hidePreviousResult = true; audio.stopTone() }
        .onChange(of: store.voiceRoot) { _, _ in hidePreviousResult = true; audio.stopTone() }
        .onChange(of: store.voiceResult) { _, result in if result != nil { hidePreviousResult = false } }
    }

    private var exercises: some View {
        EdgeRail(spacing: 10, selection: store.voiceLevel) {
            ForEach([7, 1, 2, 3, 4, 5, 6, 8], id: \.self) { level in
                Button {
                    guard !store.voiceRunning else { return }
                    if locked(level) { store.presentPaywall("voice") } else { store.voiceLevel = level }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: level == 7 ? "arrow.up.and.down" : "music.note").foregroundStyle(Palette.brass)
                            Spacer()
                            if store.demonstratedLevels.contains(level) { Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success) }
                            else if locked(level) { ProBadge() }
                        }
                        Text(level == 7 ? String(localized: "Range test") : exerciseName(level)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading).lineLimit(2)
                    }
                    .frame(width: 150, height: 86, alignment: .topLeading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(store.voiceLevel == level ? Palette.brass.opacity(0.16) : Palette.stageRaised))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(store.voiceLevel == level ? Palette.brass : Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(store.voiceRunning)
                .accessibilityIdentifier("voice.exercise.\(level)")
                .id(level)
            }
        }
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Target")
                    Text(note(targetMidi)).font(Typeface.display(64)).foregroundStyle(Palette.ink).contentTransition(.numericText())
                }
                Spacer()
                if store.voiceRunning && store.countdown > 0 {
                    Text("\(store.countdown)").font(Typeface.display(64)).foregroundStyle(Palette.brass).contentTransition(.numericText())
                } else if store.voiceRunning {
                    LiveVoiceReading(tolerance: exercise.toleranceCents)
                }
            }
            VoiceTrace(tolerance: exercise.toleranceCents, hidden: hidePreviousResult).frame(height: 190)
            if store.voiceRunning && store.countdown == 0 { VoiceProgress(duration: exercise.durationMs, hold: exercise.notes.count == 1 ? exercise.holdMs : nil) }
            if store.voiceRunning {
                Button(role: .destructive) { store.cancelVoice() } label: { Label("Stop", systemImage: "stop.fill") }
                    .buttonStyle(BrassButtonStyle(prominent: false))
            } else {
                Button { hidePreviousResult = false; store.startVoice() } label: {
                    Label(store.voiceResult == nil ? text("timbre_voice_start_practice", "Start practice") : text("timbre_voice_try_again", "Try again"), systemImage: "mic.fill")
                }
                .buttonStyle(BrassButtonStyle()).disabled(audio.tonePlaying)
                .accessibilityIdentifier("voice.start")
            }
        }
        .stillCard()
    }

    private var target: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: text("timbre_voice_hold_requirement", "%1$@ s hold · ±%2$d cents"), String(format: "%.1f", Double(exercise.holdMs) / 1000), Int(exercise.toleranceCents)))
                .font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
            VoiceKeyboard(targetMidi: targetMidi, notation: store.settings.notation, editable: !store.voiceRunning) { store.voiceRoot = $0 }
            if exercise.notes.count > 1 {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 8) {
                    ForEach(Array(exercise.notes.enumerated()), id: \.offset) { index, midi in
                        Text(note(midi)).font(Typeface.number(13)).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .foregroundStyle(Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.stageRaised))
                            .accessibilityLabel(Text("Note \(index + 1), \(note(midi))"))
                    }
                }
            }
            HStack {
                Button {
                    if audio.tonePlaying { audio.stopTone() }
                    else { audio.playTone(PitchMath.frequency(midi: Double(store.voiceRoot), reference: store.settings.referencePitchHz), durationMs: 1500) }
                } label: { Label(text("timbre_voice_hear_target", "Hear target"), systemImage: "speaker.wave.2.fill") }
                .buttonStyle(ChipButtonStyle(selected: audio.tonePlaying)).disabled(store.voiceRunning)
                Spacer()
            }
            Text(text("timbre_voice_comfort", "Keep the note comfortable. Stop if your voice feels strained.")).font(.footnote).foregroundStyle(Palette.inkFaint)
        }
        .stillCard()
    }

    private func resultPanel(_ result: VoiceResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(LocalizedStringKey(text("timbre_voice_last_attempt", "Your last attempt")))
            if exercise.level == 7 {
                if let low = result.lowestMidi, let high = result.highestMidi {
                    Text("\(note(low)) – \(note(high))").font(Typeface.display(48)).foregroundStyle(Palette.locked)
                    Text("Your comfortable range today. A description, not a classification.").font(.footnote).foregroundStyle(Palette.inkSoft)
                } else { Text(text("timbre_voice_range_no_result", "No reliable range yet. Try two comfortable notes.")).foregroundStyle(Palette.inkSoft) }
            } else {
                HStack(spacing: 28) {
                    metric(text("timbre_voice_accuracy", "Accuracy"), result.accuracy)
                    metric(text("timbre_voice_steadiness", "Steadiness"), result.stability)
                }
                Text(localizedVoiceExplanation(result, level: exercise.level)).font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            if result.demonstrated { Label("Skill demonstrated", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.success) }
            if store.voiceSaveFailed {
                Button(LocalizedStringKey("timbre_voice_retry_save")) { store.retryVoiceSave() }.buttonStyle(BrassButtonStyle(prominent: false))
            }
        }
        .stillCard()
    }

    private func metric(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Palette.inkSoft)
            Text(value.map { "\($0)" } ?? "—").font(Typeface.display(44)).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LiveVoiceReading: View {
    let tolerance: Double
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let reading = store.live.reading
        VStack(alignment: .trailing, spacing: 2) {
            if let cents = reading.cents {
                Text(String(format: "%+.0f¢", cents)).font(Typeface.number(28))
                    .foregroundStyle(abs(cents) <= tolerance ? Palette.locked : Palette.pitch(cents, locked: false))
                Text(reading.stable ? "Clear pitch" : "Settling").font(.caption).foregroundStyle(Palette.inkSoft)
            } else {
                Text("Sing…").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityIdentifier("voice.guidance")
    }
}

private struct VoiceProgress: View {
    let duration: Int
    let hold: Int?
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(store.live.voiceElapsed), total: Double(duration)).tint(Palette.brass)
            if let hold {
                ProgressView(value: Double(min(store.live.voiceLiveHoldMs, hold)), total: Double(hold)).tint(Palette.locked)
                    .accessibilityIdentifier("voice.holdProgress")
            }
        }
    }
}

/// Live pitch line against the ±tolerance band, glowing where it sits in tune.
private struct VoiceTrace: View {
    let tolerance: Double
    let hidden: Bool
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let values = hidden ? [] : store.live.trace
        Canvas { context, size in
            let extent = max(100.0, tolerance * 2)
            let center = size.height / 2
            let half = CGFloat(tolerance / extent) * center
            context.fill(Path(roundedRect: CGRect(x: 0, y: center - half, width: size.width, height: half * 2), cornerRadius: 10), with: .color(Palette.locked.opacity(0.1)))
            var mid = Path(); mid.move(to: CGPoint(x: 0, y: center)); mid.addLine(to: CGPoint(x: size.width, y: center))
            context.stroke(mid, with: .color(Palette.inkFaint.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            var path = Path(); var connected = false
            for (index, value) in values.enumerated() {
                guard let value, value.isFinite else { connected = false; continue }
                let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * size.width
                let y = center - CGFloat(min(extent, max(-extent, value)) / extent) * center
                if connected { path.addLine(to: CGPoint(x: x, y: y)) } else { path.move(to: CGPoint(x: x, y: y)) }
                connected = true
            }
            context.stroke(path, with: .color(Palette.brass.opacity(0.35)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Palette.brass), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.stageDeep.opacity(0.6)))
        .accessibilityLabel(Text("Your pitch relative to the target"))
    }
}
