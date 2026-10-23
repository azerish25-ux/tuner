import SwiftUI
import TimbreCore

struct EarTrainingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @State private var drill: EarDrill = .pitchDirection
    @State private var session: EarSession?
    @State private var question: EarQuestion?
    @State private var picked: String?
    @State private var finished = false
    private let length = 10

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Drill", selection: Binding(get: { drill }, set: { value in
                    if value != .pitchDirection && !commerce.isPro { store.presentPaywall("ear.\(value.rawValue)"); return }
                    drill = value; start()
                })) {
                    Text("Pitch").tag(EarDrill.pitchDirection)
                    Text("Intervals").tag(EarDrill.interval)
                    Text("Chords").tag(EarDrill.chordQuality)
                }
                .pickerStyle(.segmented)
                if finished, let session { summary(session) } else if let question { card(question) }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 14)
        }
        .background(StageBackground(motes: false))
        .navigationTitle("Ear training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if session == nil { start() } }
    }

    private var prompt: LocalizedStringKey {
        switch drill {
        case .pitchDirection: return "Is the second note higher or lower?"
        case .interval: return "Name the interval"
        case .chordQuality: return "Name the chord"
        }
    }

    private func card(_ question: EarQuestion) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Eyebrow("Question \(min(length, (session?.asked ?? 0) + 1)) of \(length)")
                Text(prompt).font(Typeface.display(30)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                if let cents = question.cents {
                    Text("Difference: \(Int(abs(cents)))¢").font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                }
            }
            Button { play(question) } label: {
                ZStack {
                    Circle().fill(Palette.brass.opacity(audio.tonePlaying ? 0.22 : 0.12)).frame(width: 128, height: 128)
                        .scaleEffect(audio.tonePlaying ? 1.08 : 1)
                    Image(systemName: audio.tonePlaying ? "waveform" : "play.fill").font(.system(size: 40, weight: .semibold)).foregroundStyle(Palette.brass)
                        .symbolEffect(.variableColor.iterative, isActive: audio.tonePlaying)
                }
                .animation(Motion.pluck, value: audio.tonePlaying)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play again")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(question.choices, id: \.self) { choice in
                    Button { answer(choice, question) } label: {
                        Text(LocalizedStringKey(choice)).font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(Palette.ink)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill(choice, question)))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(picked != nil)
                    .accessibilityIdentifier("ear.choice.\(choice)")
                }
            }
            if let session {
                HStack {
                    Label("Level \(session.level + 1)", systemImage: "chart.line.uptrend.xyaxis").font(.caption.weight(.semibold)).foregroundStyle(Palette.brass)
                    Spacer()
                    Text("\(session.correct) correct").font(.caption).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .stillCard(padding: 22)
        .animation(Motion.pluck, value: picked)
    }

    private func fill(_ choice: String, _ question: EarQuestion) -> Color {
        guard let picked else { return Palette.stageRaised }
        if choice == question.answer { return Palette.success.opacity(0.35) }
        if choice == picked { return Palette.danger.opacity(0.35) }
        return Palette.stageRaised
    }

    private func summary(_ session: EarSession) -> some View {
        VStack(spacing: 16) {
            Eyebrow("Session complete")
            Text("\(session.accuracy ?? 0)%").font(Typeface.display(88)).foregroundStyle(Palette.locked)
            Text("\(session.correct) of \(session.asked) right · now level \(session.level + 1)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            Button("Go again") { start() }.buttonStyle(BrassButtonStyle())
        }
        .stillCard(padding: 24)
    }

    private func start() {
        let level = store.settings.earLevels?[drill.rawValue] ?? 0
        var next = EarSession(drill: drill, level: level, referenceHz: store.settings.referencePitchHz)
        let first = next.next()
        session = next; question = first; picked = nil; finished = false
        store.beginPractice(DailyActivity.Kind.ear.rawValue)
        play(first)
    }

    private func play(_ question: EarQuestion) { audio.playTones(question.tones, together: question.simultaneous) }

    private func answer(_ choice: String, _ question: EarQuestion) {
        guard var current = session else { return }
        picked = choice
        let right = current.answer(choice, for: question)
        right ? Haptics.shared.lock() : Haptics.shared.selection()
        session = current
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(right ? 650 : 1300))
            guard var s = session else { return }
            if s.asked >= length {
                finished = true
                store.updateSettings { settings in var levels = settings.earLevels ?? [:]; levels[drill.rawValue] = s.level; settings.earLevels = levels }
                store.finishPractice(.ear, questions: s.asked, correct: s.correct)
            } else {
                let next = s.next(); session = s; self.question = next; picked = nil
                play(next)
            }
        }
    }
}
