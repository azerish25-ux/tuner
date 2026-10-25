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
    /// Spelled as the tuner, drone and chords spell notes (E♭ not D♯), in the player's note names.
    private func note(_ midi: Int) -> String { NoteNames.glyphs(VoiceNoteName.name(midi, notation: store.settings.notation)) }
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
                            Image(systemName: level == 7 ? "arrow.up.and.down" : "music.note").foregroundStyle(Palette.mint)
                            Spacer()
                            if store.demonstratedLevels.contains(level) { Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success) }
                            else if locked(level) { ProLock(size: 22) }
                        }
                        Text(level == 7 ? String(localized: "Range test") : exerciseName(level)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading).lineLimit(2)
                    }
                    .frame(width: 150, height: 86, alignment: .topLeading)
                    .padding(12)
                    .overlay(alignment: .bottomTrailing) {
                        NoteContour(notes: VoiceExercise(level: level, rootMidi: store.voiceRoot).notes, lit: store.voiceLevel == level)
                            .frame(width: 66, height: 16)
                            .padding(12)
                    }
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(store.voiceLevel == level ? Palette.mint.opacity(0.16) : Palette.stageRaised))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(store.voiceLevel == level ? Palette.mint : Palette.controlLine, lineWidth: 1))
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
                    NoteGlyphs.text(note(targetMidi), size: 64).font(Typeface.display(64)).foregroundStyle(Palette.ink).contentTransition(.numericText())
                        .heroNumeral()
                }
                Spacer()
                if store.voiceRunning && store.countdown > 0 {
                    Text("\(store.countdown)").font(Typeface.display(64)).foregroundStyle(Palette.mint).contentTransition(.numericText())
                        .heroNumeral()
                } else if store.voiceRunning {
                    LiveVoiceReading(tolerance: exercise.toleranceCents)
                }
            }
            VoiceTrace(tolerance: exercise.toleranceCents, hidden: hidePreviousResult, plan: exercise.notes,
                       hold: exercise.notes.count == 1 ? Double(exercise.holdMs) / Double(max(1, exercise.durationMs)) : nil,
                       notation: store.settings.notation)
                .frame(height: 190)
            if store.voiceRunning && store.countdown == 0 { VoiceProgress(duration: exercise.durationMs, hold: exercise.notes.count == 1 ? exercise.holdMs : nil) }
            if store.voiceRunning {
                Button(role: .destructive) { store.cancelVoice() } label: { Label("Stop", systemImage: "stop.fill") }
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Button { hidePreviousResult = false; store.startVoice() } label: {
                    Label(store.voiceResult == nil ? text("timbre_voice_start_practice", "Start practice") : text("timbre_voice_try_again", "Try again"), systemImage: "mic.fill")
                }
                // Waits while the target tone sounds; the style shows it disabled (graphite, faint type, no glow).
                .buttonStyle(PrimaryButtonStyle()).disabled(audio.tonePlaying)
                .accessibilityIdentifier("voice.start")
            }
        }
        .stillCard()
    }

    private var target: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ¢ in visible copy, as everywhere else (the English value of this key is the l10n owner's to match).
            Text(String(format: text("timbre_voice_hold_requirement", "%1$@ s hold · ±%2$d¢"), String(format: "%.1f", Double(exercise.holdMs) / 1000), Int(exercise.toleranceCents)))
                .font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
            VoiceKeyboard(targetMidi: targetMidi, notation: store.settings.notation, editable: !store.voiceRunning) { store.voiceRoot = $0 }
            if exercise.notes.count > 1 {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 8) {
                    ForEach(Array(exercise.notes.enumerated()), id: \.offset) { index, midi in
                        NoteGlyphs.text(note(midi), size: 13, weight: .medium).font(Typeface.number(13)).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .foregroundStyle(Palette.ink)
                            .background(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(Palette.stageRaised))
                            .accessibilityLabel(Text("Note \(index + 1), \(note(midi))"))
                    }
                }
            }
            HStack {
                Button {
                    if audio.tonePlaying { audio.stopTone() }
                    else { audio.playTone(PitchMath.frequency(midi: Double(store.voiceRoot), reference: store.settings.referencePitchHz), durationMs: 1500) }
                } label: { Label(text("timbre_voice_hear_target", "Hear target"), systemImage: "speaker.wave.2.fill") }
                // Off during a take; the chip dims to show it.
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
                    NoteGlyphs.text(String(localized: "\(note(low)) – \(note(high))"), size: 48).font(Typeface.display(48)).foregroundStyle(Palette.locked)
                    RangeLadder(low: low, high: high, notation: store.settings.notation)
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
                Button(LocalizedStringKey("timbre_voice_retry_save")) { store.retryVoiceSave() }.buttonStyle(SecondaryButtonStyle())
            }
        }
        .stillCard()
    }

    private func metric(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Palette.inkSoft)
            Text(value.map { "\($0)" } ?? "—").font(Typeface.display(44)).foregroundStyle(Palette.ink)
                .heroNumeral()
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
                Text(verbatim: NoteReadout.signed(cents.isFinite ? Int(cents.rounded()) : nil)).font(Typeface.number(28))
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
            ProgressView(value: Double(store.live.voiceElapsed), total: Double(duration)).tint(Palette.mint)
            if let hold {
                ProgressView(value: Double(min(store.live.voiceLiveHoldMs, hold)), total: Double(hold)).tint(Palette.locked)
                    .accessibilityIdentifier("voice.holdProgress")
            }
        }
    }
}

/// Live pitch line against the ±tolerance band, glowing where it sits in tune. Before there is a line,
/// the exercise's path: its notes as steps in time (the range walk's ladder down and up), each named,
/// the first lit; a single held note shows how long to hold it.
private struct VoiceTrace: View {
    let tolerance: Double
    let hidden: Bool
    let plan: [Int]
    /// Share of the exercise to hold a single note for.
    let hold: Double?
    let notation: String
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let values = hidden ? [] : store.live.trace
        let traced = values.contains { $0 != nil }
        Canvas { context, size in
            let extent = max(100.0, tolerance * 2)
            let center = size.height / 2
            let half = CGFloat(tolerance / extent) * center
            context.fill(Path(roundedRect: CGRect(x: 0, y: center - half, width: size.width, height: half * 2), cornerRadius: 10), with: .color(Palette.locked.opacity(0.1)))
            var mid = Path(); mid.move(to: CGPoint(x: 0, y: center)); mid.addLine(to: CGPoint(x: size.width, y: center))
            context.stroke(mid, with: .color(Palette.inkFaint.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            if !traced {
                drawPlan(&context, size: size)
                return
            }
            var path = Path(); var connected = false
            for (index, value) in values.enumerated() {
                guard let value, value.isFinite else { connected = false; continue }
                let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * size.width
                let y = center - CGFloat(min(extent, max(-extent, value)) / extent) * center
                if connected { path.addLine(to: CGPoint(x: x, y: y)) } else { path.move(to: CGPoint(x: x, y: y)) }
                connected = true
            }
            context.stroke(path, with: .color(Palette.mint.opacity(0.35)), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageDeep.opacity(0.6)))
        .accessibilityLabel(Text("Your pitch relative to the target"))
    }

    private func drawPlan(_ context: inout GraphicsContext, size: CGSize) {
        guard let low = plan.min(), let high = plan.max() else { return }
        let inset: CGFloat = 16
        let center = size.height / 2
        let usable = max(0, size.height - 64)
        let middle = Double(low + high) / 2
        let span = Double(max(1, high - low))
        func y(_ midi: Int) -> CGFloat { high == low ? center : center - CGFloat((Double(midi) - middle) / span) * usable }
        if plan.count == 1, let midi = plan.first {
            // One note: the whole take at the target, the stretch to hold lit in the middle.
            let bar = CGRect(x: inset, y: center - 4, width: size.width - inset * 2, height: 8)
            context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .color(Palette.mint.opacity(0.18)))
            let held = (size.width - inset * 2) * CGFloat(min(1, max(0.08, hold ?? 0.3)))
            context.fill(Path(roundedRect: CGRect(x: size.width / 2 - held / 2, y: center - 4, width: held, height: 8), cornerRadius: 4),
                         with: .color(Palette.mint.opacity(0.6)))
            context.draw(NoteGlyphs.text(VoiceNoteName.name(midi, notation: notation), size: 11).font(Typeface.label(11)).foregroundStyle(Palette.inkSoft),
                         at: CGPoint(x: inset, y: center - 16), anchor: .leading)
            return
        }
        let slot = (size.width - inset * 2) / CGFloat(plan.count)
        var previous: CGPoint?
        for (i, midi) in plan.enumerated() {
            let x0 = inset + slot * CGFloat(i) + 2
            let width = max(4, slot - 4)
            let level = y(midi)
            if let previous {
                var step = Path()
                step.move(to: previous)
                step.addLine(to: CGPoint(x: x0, y: level))
                context.stroke(step, with: .color(Palette.mint.opacity(0.2)), lineWidth: 1.5)
            }
            context.fill(Path(roundedRect: CGRect(x: x0, y: level - 4, width: width, height: 8), cornerRadius: 4),
                         with: .color(Palette.mint.opacity(i == 0 ? 0.75 : 0.32)))
            context.draw(NoteGlyphs.text(VoiceNoteName.name(midi, notation: notation), size: 10).font(Typeface.label(10)).foregroundStyle(i == 0 ? Palette.ink : Palette.inkFaint),
                         at: CGPoint(x: x0 + width / 2, y: level - 13))
            previous = CGPoint(x: x0 + width, y: level)
        }
    }
}

/// A tiny picture of an exercise's notes for its card: steps for a melody, the range walk's V, a line
/// for one held note.
private struct NoteContour: View {
    let notes: [Int]
    let lit: Bool

    var body: some View {
        Canvas { context, size in
            guard let low = notes.min(), let high = notes.max(), !notes.isEmpty else { return }
            let span = CGFloat(max(1, high - low))
            let slot = size.width / CGFloat(notes.count)
            func y(_ midi: Int) -> CGFloat { high == low ? size.height / 2 : size.height - 1.5 - CGFloat(midi - low) / span * (size.height - 3) }
            var path = Path()
            for (i, midi) in notes.enumerated() {
                let a = CGPoint(x: slot * CGFloat(i), y: y(midi))
                let b = CGPoint(x: slot * CGFloat(i + 1), y: y(midi))
                if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
                path.addLine(to: b)
            }
            context.stroke(path, with: .color(Palette.mint.opacity(lit ? 0.9 : 0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The range found, on a ladder from C2 to C6 with each C marked: where your comfortable notes sit.
private struct RangeLadder: View {
    let low: Int
    let high: Int
    let notation: String
    private let first = 36
    private let last = 84

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 10
            func x(_ midi: Int) -> CGFloat {
                inset + (size.width - inset * 2) * CGFloat(min(last, max(first, midi)) - first) / CGFloat(last - first)
            }
            let rail = size.height / 2 - 7
            context.fill(Path(roundedRect: CGRect(x: inset, y: rail - 3, width: size.width - inset * 2, height: 6), cornerRadius: 3), with: .color(Palette.line))
            for midi in stride(from: first, through: last, by: 12) {
                var tick = Path()
                tick.move(to: CGPoint(x: x(midi), y: rail - 8))
                tick.addLine(to: CGPoint(x: x(midi), y: rail + 8))
                context.stroke(tick, with: .color(Palette.inkFaint.opacity(0.6)), lineWidth: 1)
                context.draw(NoteGlyphs.text(VoiceNoteName.name(midi, notation: notation), size: 10).font(Typeface.label(10)).foregroundStyle(Palette.inkFaint),
                             at: CGPoint(x: x(midi), y: size.height - 7))
            }
            let from = x(min(low, high)), to = x(max(low, high))
            let band = CGRect(x: from - 5, y: rail - 6, width: to - from + 10, height: 12)
            context.fill(Path(roundedRect: band.insetBy(dx: -4, dy: -4), cornerRadius: 10), with: .color(Palette.locked.opacity(0.14)))
            context.fill(Path(roundedRect: band, cornerRadius: 6),
                         with: .linearGradient(Gradient(colors: [Palette.mintDeep, Palette.locked]), startPoint: CGPoint(x: from, y: 0), endPoint: CGPoint(x: to, y: 0)))
        }
        .frame(height: 46)
        .accessibilityHidden(true)
    }
}
