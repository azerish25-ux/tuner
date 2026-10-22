import SwiftUI
import TimbreCore
import Charts

@MainActor
struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var selectedInstrument = ""
    @State private var selectedInitialInstrument = false
    private var analytics: PracticeHistorySummary {
        PracticeAnalytics.summary(records: store.records, instrumentId: selectedInstrument.isEmpty ? nil : selectedInstrument)
    }
    private func localized(_ key: String, _ fallback: String = "") -> String { NSLocalizedString(key, value: fallback, comment: "") }
    private func format(_ key: String, _ arguments: CVarArg...) -> String { String(format: localized(key), arguments: arguments) }
    private func duration(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        return seconds < 60 ? format("timbre_progress_seconds", seconds) : format("timbre_progress_minutes", seconds / 60, seconds % 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("timbre_progress_recent", value: "Recent practice", comment: "")).font(TimbreTheme.title())
                if !commerce.isPlus { lockedHistory }
                else if store.records.isEmpty { emptyHistory }
                else {
                    instrumentFilter
                    summary
                    activity
                    challengeProgress
                    if analytics.records.isEmpty { Text("timbre_progress_no_recent").foregroundStyle(TimbreTheme.secondary) }
                    ForEach(analytics.records) { record in recordView(record) }
                }
            }.padding(20).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
        }
        .background(TimbreTheme.canvas)
        .foregroundStyle(TimbreTheme.primary)
        .navigationTitle("Practice history")
        .onAppear { if !selectedInitialInstrument { selectedInstrument = store.instrument.id; selectedInitialInstrument = true } }
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
            Text("timbre_progress_recent").font(.headline)
            Text(format("timbre_progress_session_count", analytics.comparison.recent.sessionCount))
            if let mean = analytics.comparison.recent.meanAbsCentsError {
                Text(format("timbre_progress_mean_offset", String(format: "%.1f", mean)))
            }
            if let change = analytics.comparison.changeCents {
                Text(abs(change) < 0.05 ? localized("timbre_progress_change_same") : format(change < 0 ? "timbre_progress_change_closer" : "timbre_progress_change_farther", String(format: "%.1f", abs(change))))
                    .foregroundStyle(change < 0 ? TimbreTheme.success : TimbreTheme.secondary)
            } else { Text("timbre_progress_change_unknown").foregroundStyle(TimbreTheme.secondary) }
            Text("timbre_progress_comparison").font(.footnote).foregroundStyle(TimbreTheme.secondary)
        }
    }
    private var instrumentFilter: some View {
        Picker("Instrument", selection: $selectedInstrument) {
            Text("timbre_library_all").tag("")
            ForEach(store.catalog.instruments) { instrument in
                Text(instrument.name.localized).tag(instrument.id)
            }
            Text("timbre_voice_title").tag("voice")
        }.pickerStyle(.menu).accessibilityIdentifier("history.instrumentFilter")
    }
    private var activity: some View {
        Panel {
            if let total = analytics.weekDurationMs { Text(format("timbre_progress_week_duration", duration(total))).font(.headline) }
            else {
                Text("Known practice time this week: \(duration(analytics.measuredWeekDurationMs))").font(.headline)
                Text("Some older sessions have no recorded duration. Their time is unavailable.").font(.footnote).foregroundStyle(TimbreTheme.secondary)
            }
            Chart(analytics.activity) { day in
                if let milliseconds = day.durationMs {
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", Double(milliseconds) / 60000))
                        .foregroundStyle(TimbreTheme.brass)
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(day.sessionCount) sessions, \(duration(milliseconds))")
                }
            }
            .frame(height: 140)
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
            .chartYAxisLabel("Minutes")
            .accessibilityIdentifier("history.activityChart")
            if analytics.activity.allSatisfy({ $0.sessionCount == 0 }) { Text("timbre_progress_no_week").foregroundStyle(TimbreTheme.secondary) }
        }
    }
    @ViewBuilder private var challengeProgress: some View {
        let challenges = PracticeAnalytics.challenges(records: store.records)
        if !challenges.isEmpty {
            Panel {
                Text("timbre_progress_voice_exercises").font(.headline)
                ForEach(challenges) { progress in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName(progress.challengeId)).font(.subheadline.weight(.medium))
                        Text(progress.attempts == 1 ? format("timbre_progress_best_one", progress.bestScore) : format("timbre_progress_best_many", progress.bestScore, progress.attempts))
                            .font(.footnote).foregroundStyle(TimbreTheme.secondary)
                    }
                }
            }
        }
    }
    private func exerciseName(_ id: String) -> String {
        guard let level = Int(id.split(separator: ".").last ?? ""), (1...8).contains(level) else { return localized("timbre_progress_exercise_default", "Voice exercise") }
        let suffix = ["1", "2", "3", "4", "interval", "melody", "range", "song"][level - 1]
        return localized("timbre_voice_exercise_" + suffix, VoiceExercise(level: level).name)
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
            if let milliseconds = record.durationMs { Text(duration(milliseconds)).font(.caption.monospacedDigit()).foregroundStyle(TimbreTheme.secondary) }
            else { Text("Duration unavailable").font(.caption).foregroundStyle(TimbreTheme.secondary) }
            if record.count > 0 {
                Text(format("timbre_progress_steady_fraction", Int((100 * Double(record.stableCount) / Double(record.count)).rounded())))
                    .font(.caption).foregroundStyle(TimbreTheme.secondary)
            }
            if let voice = record.voiceResult {
                if let tuning = record.tuningId, let level = Int(tuning.split(separator: ".").last ?? ""), (1...8).contains(level) {
                    Text(exerciseName(tuning)).font(.subheadline)
                }
                HStack(alignment: .top, spacing: 24) {
                    metric(localized("timbre_voice_accuracy"), value: voice.accuracy)
                    metric(localized("timbre_voice_steadiness"), value: voice.stability)
                }
                if voice.longestHoldMs > 0 { Text("Measured hold: \(Double(voice.longestHoldMs) / 1000, specifier: "%.1f") s").font(.footnote) }
                if record.tuningId?.hasPrefix("voice.range.") == true, let low = voice.lowestMidi, let high = voice.highestMidi {
                    Text("Reliable range: \(PitchMath.noteName(midi: low, notation: store.settings.notation))–\(PitchMath.noteName(midi: high, notation: store.settings.notation))")
                }
                Text(localizedVoiceExplanation(voice, level: record.tuningId.flatMap { Int($0.split(separator: ".").last ?? "") } ?? 1)).font(.footnote).foregroundStyle(TimbreTheme.secondary)
                if voice.demonstrated { Label("Skill demonstrated", systemImage: "checkmark.circle").font(.caption).foregroundStyle(TimbreTheme.success) }
            } else {
                if let id = record.tuningId, let tuning = store.catalog.tunings.first(where: { $0.id == id }) { Text(tuning.name.localized).font(.subheadline) }
                if let mean = record.meanAbsoluteCents {
                    Text(format("timbre_progress_mean_offset", String(format: "%.1f", mean))).font(.subheadline)
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
            else { Text("timbre_voice_not_measured").font(.subheadline) }
        }.accessibilityElement(children: .combine)
    }
    private func instrumentName(_ record: PracticeRecord) -> String {
        if record.kind == "voice" { return "Voice practice" }
        return store.catalog.instruments.first { $0.id == record.instrumentId }?.name.localized ?? record.instrumentId
    }
}
