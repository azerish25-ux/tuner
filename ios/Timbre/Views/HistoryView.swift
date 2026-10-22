import SwiftUI
import TimbreCore

@MainActor
struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("timbre_progress_recent", value: "Recent practice", comment: "")).font(TimbreTheme.title())
                if !commerce.isPlus { lockedHistory }
                else if store.records.isEmpty { emptyHistory }
                else {
                    summary
                    ForEach(store.records.sorted { $0.date > $1.date }) { record in recordView(record) }
                }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TimbreTheme.canvas)
        .foregroundStyle(TimbreTheme.primary)
        .navigationTitle("Practice history")
    }
    private var lockedHistory: some View {
        Panel {
            Image(systemName: "clock.arrow.circlepath").font(.largeTitle).foregroundStyle(TimbreTheme.brass)
            Text(NSLocalizedString("timbre_studio_history_locked", value: "Review your sessions and measured progress with full access.", comment: ""))
            Button("Explore Timbre Plus") { store.showPlus = true }.buttonStyle(PrimaryButton()).accessibilityIdentifier("history.unlock")
        }
    }
    private var emptyHistory: some View {
        Panel {
            Image(systemName: "music.note.list").font(.largeTitle).foregroundStyle(TimbreTheme.secondary)
            Text("No practice sessions yet").font(.headline)
            Text("Your next saved instrument or voice practice will appear here.").foregroundStyle(TimbreTheme.secondary)
        }
    }
    private var summary: some View {
        Panel {
            Text("Your practice").font(.headline)
            Text("\(store.records.count) saved sessions")
            if !store.demonstratedLevels.isEmpty {
                Text("Demonstrated voice exercises: \(store.demonstratedLevels.sorted().map(String.init).joined(separator: ", "))")
                    .foregroundStyle(TimbreTheme.success)
            }
            let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
            let recent = store.records.filter { $0.date >= cutoff }
            Text("\(recent.count) sessions in the last two weeks").font(.footnote).foregroundStyle(TimbreTheme.secondary)
        }
    }
    private func recordView(_ record: PracticeRecord) -> some View {
        Panel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(instrumentName(record)).font(.headline)
                    Text(record.date, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                        .font(.caption).foregroundStyle(TimbreTheme.secondary)
                }
                Spacer()
                Image(systemName: record.kind == "voice" ? "waveform" : "tuningfork").foregroundStyle(TimbreTheme.brass).accessibilityHidden(true)
            }
            if let voice = record.voiceResult {
                if let tuning = record.tuningId, let level = Int(tuning.split(separator: ".").last ?? ""), (1...8).contains(level) {
                    Text(VoiceExercise(level: level).name).font(.subheadline)
                }
                HStack(alignment: .top, spacing: 24) {
                    metric("Accuracy", value: voice.accuracy)
                    metric("Stability", value: voice.stability)
                }
                if voice.longestHoldMs > 0 { Text("Measured hold: \(Double(voice.longestHoldMs) / 1000, specifier: "%.1f") s").font(.footnote) }
                if record.tuningId?.hasPrefix("voice.range.") == true, let low = voice.lowestMidi, let high = voice.highestMidi {
                    Text("Reliable range: \(PitchMath.noteName(midi: low, notation: store.settings.notation))–\(PitchMath.noteName(midi: high, notation: store.settings.notation))")
                }
                Text(voice.explanation).font(.footnote).foregroundStyle(TimbreTheme.secondary)
                if voice.demonstrated { Label("Skill demonstrated", systemImage: "checkmark.circle").font(.caption).foregroundStyle(TimbreTheme.success) }
            } else {
                if let id = record.tuningId, let tuning = store.catalog.tunings.first(where: { $0.id == id }) { Text(tuning.name.localized).font(.subheadline) }
                if let mean = record.meanAbsoluteCents {
                    Text("Mean pitch offset: \(mean, specifier: "%.1f") cents").font(.subheadline)
                } else {
                    Text(NSLocalizedString("timbre_progress_no_stable", value: "No stable pitch measurement in this session.", comment: ""))
                        .font(.subheadline).foregroundStyle(TimbreTheme.secondary)
                }
                Text("\(record.stableCount) stable readings · \(record.count) measured readings").font(.caption).foregroundStyle(TimbreTheme.secondary)
            }
        }
    }
    private func metric(_ label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(TimbreTheme.secondary)
            if let value { Text("\(value)%").font(TimbreTheme.number(24)) }
            else { Text("Not measured").font(.subheadline) }
        }.accessibilityElement(children: .combine)
    }
    private func instrumentName(_ record: PracticeRecord) -> String {
        if record.kind == "voice" { return "Voice practice" }
        return store.catalog.instruments.first { $0.id == record.instrumentId }?.name.localized ?? record.instrumentId
    }
}
