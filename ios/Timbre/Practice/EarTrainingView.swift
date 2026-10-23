import SwiftUI
import TimbreCore

/// Ear training: ten questions a round. A listening orb that pulses with the tones, round dots,
/// a combo that heats up on a run of right answers, and a results card at the end.
struct EarTrainingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drill: EarDrill = .pitchDirection
    @State private var session: EarSession?
    @State private var question: EarQuestion?
    @State private var picked: String?
    @State private var finished = false
    /// Right or wrong for each answered question this round, for the dots.
    @State private var outcomes: [Bool] = []
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var burst = 0
    @State private var shake = 0
    @State private var showXP = false
    /// When the current question started sounding, so the orb can pluck in time with each tone.
    @State private var playedAt: Date?
    /// Bumped on every new round so a pending advance from the previous one is dropped.
    @State private var round = 0
    /// XP the finished round earned (counted up on the results card) and the score ring's fill.
    @State private var gained = 0
    @State private var shownXP = 0
    @State private var ringShown = false
    @State private var resultBurst = 0
    private let length = 10

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                drillPicker
                if finished, let session {
                    results(session)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                } else if let question {
                    hud
                    card(question)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 14)
        }
        .stageTopShade()
        .background {
            StageBackground(glow: hot ? Palette.flame : Color(hex: 0xFFC48C), intensity: hot ? 1.35 : 1, motes: false)
                .animation(.easeInOut(duration: 0.5), value: hot)
        }
        .navigationTitle("Ear training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if session == nil { start() } }
    }

    /// Three or more right in a row warms the stage.
    private var hot: Bool { combo >= 3 && !finished }

    private var drillPicker: some View {
        Picker("Drill", selection: Binding(get: { drill }, set: { value in
            if value != .pitchDirection && !commerce.isPro { store.presentPaywall("ear.\(value.rawValue)"); return }
            drill = value; start()
        })) {
            Text("Pitch").tag(EarDrill.pitchDirection)
            Text("Intervals").tag(EarDrill.interval)
            Text("Chords").tag(EarDrill.chordQuality)
        }
        .pickerStyle(.segmented)
    }

    private var prompt: LocalizedStringKey {
        switch drill {
        case .pitchDirection: return "Is the second note higher or lower?"
        case .interval: return "Name the interval"
        case .chordQuality: return "Name the chord"
        }
    }

    /// The question on screen, 1…10; it stays put while an answer is being revealed.
    private var questionNumber: Int { min(length, outcomes.count + (picked == nil ? 1 : 0)) }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 14) {
            HStack {
                if let session {
                    Label("Level \(session.level + 1)", systemImage: "chart.line.uptrend.xyaxis")
                        .font(Typeface.label(13)).foregroundStyle(Palette.mint)
                        .contentTransition(.numericText())
                        .animation(Motion.pluck, value: session.level)
                }
                Spacer()
                comboBadge
            }
            .frame(minHeight: 32)
            .animation(Motion.pluck, value: combo >= 2)
            roundDots
        }
    }

    @ViewBuilder private var comboBadge: some View {
        if combo >= 2 {
            Label("Combo ×\(combo)", systemImage: "flame.fill")
                .font(Typeface.label(14)).foregroundStyle(Palette.flame)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Palette.flame.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.4), lineWidth: 1))
                .shadow(color: Palette.flame.opacity(hot ? 0.45 : 0), radius: 12)
                .contentTransition(.numericText())
                .symbolEffect(.bounce, value: combo)
                .phaseAnimator([1.0, 1.16], trigger: combo) { content, scale in
                    content.scaleEffect(CGFloat(reduceMotion ? 1 : scale))
                } animation: { _ in Animation.spring(response: 0.22, dampingFraction: 0.55) }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if let session {
            Text("\(session.correct) correct").font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    /// Ten dots: mint for right, coral for wrong, an amber ring on the current question.
    private var roundDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<length, id: \.self) { i in dot(i) }
        }
        .frame(maxWidth: .infinity)
        .animation(Motion.pluck, value: outcomes.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Question \(questionNumber) of \(length)"))
    }

    private func dot(_ i: Int) -> some View {
        let answered = i < outcomes.count
        let current = i == outcomes.count && picked == nil
        let fill: Color = answered ? (outcomes[i] ? Palette.mint : Palette.coral) : .white.opacity(0.09)
        return Circle().fill(fill)
            .frame(width: 13, height: 13)
            .overlay(Circle().strokeBorder(current ? Palette.amber : .clear, lineWidth: 2).padding(-4))
            .shadow(color: answered ? fill.opacity(0.55) : .clear, radius: 5)
            .scaleEffect(answered || current ? 1 : 0.82)
    }

    // MARK: Question

    private func card(_ question: EarQuestion) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Eyebrow("Question \(questionNumber) of \(length)")
                    .contentTransition(.numericText())
                Text(prompt).font(Typeface.display(26)).tracking(-0.4).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let cents = question.cents {
                    Text("Difference: \(Int(abs(cents)))¢").font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                        .contentTransition(.numericText())
                }
            }
            listenOrb(question)
            answers(question)
        }
        .stillCard(padding: 22)
        .animation(Motion.pluck, value: picked)
    }

    private func listenOrb(_ question: EarQuestion) -> some View {
        let playing = audio.tonePlaying
        return VStack(spacing: 6) {
            ZStack {
                ListeningRings(active: playing, startedAt: playedAt, tones: question.simultaneous ? 1 : question.tones.count,
                               together: question.simultaneous, animate: !reduceMotion)
                    .frame(width: 232, height: 232)
                Button { play(question) } label: { orbFace(playing) }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("Play again")
                    .accessibilityIdentifier("ear.play")
            }
            .frame(height: 232)
            .overlay { SparkBurst(trigger: burst, color: Palette.mint).frame(width: 300, height: 300) }
            .overlay(alignment: .topTrailing) { xpFloat }
            // The app is sounding the tones here, so this reads "Listen" with a speaker, never the
            // microphone's "Listening…" used by the tuner.
            Group {
                if playing {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                        .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                } else {
                    Text("Tap to play again")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(playing ? Palette.mint : Palette.inkFaint)
            .animation(.easeInOut(duration: 0.2), value: playing)
            .accessibilityHidden(true)
        }
    }

    private func orbFace(_ playing: Bool) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Palette.mint.opacity(playing ? 0.42 : 0.26), Palette.mintDeep.opacity(0.18)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 80))
            Circle().strokeBorder(Palette.mint.opacity(playing ? 0.7 : 0.35), lineWidth: 1)
            Image(systemName: playing ? "waveform" : "play.fill")
                .font(.system(size: 38, weight: .semibold)).foregroundStyle(Palette.mint)
                .symbolEffect(.variableColor.iterative, isActive: playing)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 118, height: 118)
        .scaleEffect(playing && !reduceMotion ? 1.06 : 1)
        .shadow(color: Palette.mint.opacity(playing ? 0.45 : 0.15), radius: playing ? 26 : 12)
        .animation(Motion.pluck, value: playing)
        .contentShape(Circle())
    }

    /// "+2 XP" rising beside the orb on a right answer.
    @ViewBuilder private var xpFloat: some View {
        if showXP {
            Text("+\(XPReward.earCorrect) XP").font(Typeface.label(13)).foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Palette.mint))
                .shadow(color: Palette.mint.opacity(0.5), radius: 10)
                .padding(.top, 8)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity.combined(with: .offset(y: -18))))
                .accessibilityHidden(true)
        }
    }

    private func answers(_ question: EarQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(question.choices, id: \.self) { choice in
                EarChoiceButton(title: choice, state: choiceState(choice, question)) { answer(choice, question) }
                    .disabled(picked != nil)
                    .accessibilityIdentifier("ear.choice.\(choice)")
            }
        }
        .modifier(Shake(amount: shake))
    }

    private func choiceState(_ choice: String, _ question: EarQuestion) -> EarChoiceState {
        guard let picked else { return .idle }
        if choice == question.answer { return .right }
        if choice == picked { return .wrong }
        return .faded
    }

    // MARK: Results

    private func results(_ session: EarSession) -> some View {
        let accuracy = session.accuracy ?? 0
        return VStack(spacing: 20) {
            scoreRing(session)
                .overlay { SparkBurst(trigger: resultBurst, color: Palette.amber).frame(width: 320, height: 320) }
                .padding(.top, 6)
            VStack(spacing: 6) {
                Eyebrow("Session complete")
                Text(headline(accuracy)).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                Text("\(session.correct) of \(session.asked) right · now level \(session.level + 1)")
                    .font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                tile(symbol: "sparkles", tint: Palette.mint, value: Text("+\(shownXP)"), label: Text("XP"))
                tile(symbol: "scope", tint: Palette.amber, value: Text("\(accuracy)%"), label: Text("accuracy"))
                tile(symbol: "flame.fill", tint: Palette.flame, value: Text(verbatim: "×" + bestCombo.formatted()), label: Text("best run"))
            }
            roundDots.allowsHitTesting(false)
            VStack(spacing: 10) {
                Button("Go again") { start() }
                    .buttonStyle(BrassButtonStyle())
                    .accessibilityIdentifier("ear.again")
                Button("Done") { dismiss() }
                    .buttonStyle(BrassButtonStyle(prominent: false))
                    .accessibilityIdentifier("ear.done")
            }
            .padding(.top, 4)
        }
        .stillCard(padding: 22, tint: Palette.mint)
    }

    private func headline(_ accuracy: Int) -> LocalizedStringKey {
        if accuracy >= 100 { return "Flawless" }
        if accuracy >= 70 { return "Great work" }
        return "Keep going"
    }

    /// Right answers out of the round, as a ring that fills when the card lands.
    private func scoreRing(_ session: EarSession) -> some View {
        let fraction = Double(session.correct) / Double(max(1, session.asked))
        return ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 12)
            Circle().trim(from: 0, to: CGFloat(ringShown ? max(0.001, fraction) : 0))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.mint.opacity(0.5), radius: 10)
            Text("\(session.correct)/\(session.asked)").font(Typeface.number(40)).foregroundStyle(Palette.ink)
        }
        .frame(width: 156, height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(session.correct) of \(session.asked)"))
    }

    private func tile(symbol: String, tint: Color, value: Text, label: Text) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            value.font(Typeface.number(22)).foregroundStyle(Palette.ink).contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.7)
            label.font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
        .accessibilityElement(children: .combine)
    }

    // MARK: Flow

    private func start() {
        let level = store.settings.earLevels?[drill.rawValue] ?? 0
        var next = EarSession(drill: drill, level: level, referenceHz: store.settings.referencePitchHz)
        let first = next.next()
        round += 1
        session = next; question = first; picked = nil
        outcomes = []; combo = 0; bestCombo = 0; showXP = false
        gained = 0; shownXP = 0; ringShown = false
        withAnimation(Motion.settle) { finished = false }
        store.beginPractice(DailyActivity.Kind.ear.rawValue)
        play(first)
    }

    private func play(_ question: EarQuestion) {
        playedAt = Date()
        audio.playTones(question.tones, together: question.simultaneous)
    }

    private func answer(_ choice: String, _ question: EarQuestion) {
        guard picked == nil, var current = session else { return }
        let levelBefore = current.level
        picked = choice
        let right = current.answer(choice, for: question)
        session = current
        outcomes.append(right)
        if right {
            combo += 1
            bestCombo = max(bestCombo, combo)
            SoundFX.shared.play(current.level > levelBefore ? .star : .correct)
            Haptics.shared.lock()
            burst += 1
            withAnimation(Motion.pluck) { showXP = true }
        } else {
            combo = 0
            SoundFX.shared.play(.wrong)
            Haptics.shared.selection()
            withAnimation(.default) { shake += 1 }
        }
        let token = round
        Task { @MainActor in
            if right {
                try? await Task.sleep(for: .milliseconds(520))
                withAnimation(.easeOut(duration: 0.25)) { showXP = false }
                try? await Task.sleep(for: .milliseconds(130))
            } else {
                try? await Task.sleep(for: .milliseconds(1300))
            }
            guard token == round, var s = session else { return }
            if s.asked >= length {
                finish(s)
            } else {
                let next = s.next(); session = s; self.question = next; picked = nil
                play(next)
            }
        }
    }

    /// Saves the round exactly as before (ear level, then the practice record that awards XP and quests),
    /// then reveals the results: ring, burst and XP counting up.
    private func finish(_ s: EarSession) {
        store.updateSettings { settings in var levels = settings.earLevels ?? [:]; levels[drill.rawValue] = s.level; settings.earLevels = levels }
        let before = store.progress.xp
        store.finishPractice(.ear, questions: s.asked, correct: s.correct)
        gained = max(0, store.progress.xp - before)
        shownXP = 0
        withAnimation(Motion.settle) { finished = true }
        SoundFX.shared.play(.complete)
        Haptics.shared.done()
        let token = round
        let total = gained
        let great = (s.accuracy ?? 0) >= 80
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard token == round else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.9)) { ringShown = true }
            if great { resultBurst += 1 }
            guard total > 0 else { return }
            let steps = 20
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(30))
                guard token == round else { return }
                withAnimation(.linear(duration: 0.03)) { shownXP = total * step / steps }
            }
        }
    }
}

private enum EarChoiceState: Equatable { case idle, right, wrong, faded }

/// An answer tile: flashes mint with a check when right, coral with a cross when wrong.
private struct EarChoiceButton: View {
    let title: String
    let state: EarChoiceState
    let action: () -> Void

    private var revealed: Bool { state == .right || state == .wrong }

    private var tint: Color {
        switch state {
        case .right: return Palette.mint
        case .wrong: return Palette.coral
        case .idle, .faded: return Palette.line
        }
    }

    private var fill: Color {
        switch state {
        case .right: return Palette.mint.opacity(0.18)
        case .wrong: return Palette.coral.opacity(0.18)
        case .idle, .faded: return Palette.surface
        }
    }

    private var glow: Color {
        switch state {
        case .right: return Palette.mint.opacity(0.35)
        case .wrong: return Palette.coral.opacity(0.3)
        case .idle, .faded: return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if state == .right {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                        .transition(.scale.combined(with: .opacity))
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.coral)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint, lineWidth: revealed ? 2 : 1))
            .shadow(color: glow, radius: 14)
            .opacity(state == .faded ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .phaseAnimator([false, true], trigger: state) { content, flashing in
            content
                .brightness(flashing && revealed ? 0.2 : 0)
                .scaleEffect(flashing && state == .right ? 1.05 : 1)
        } animation: { flashing in
            flashing ? Animation.easeOut(duration: 0.12) : Animation.spring(response: 0.4, dampingFraction: 0.6)
        }
        .animation(Motion.pluck, value: state)
    }
}

/// Around the play button: radial bars that pluck with each tone while the question sounds
/// (timed like AudioService.playTones), and rings drifting outward. At rest, a quiet dial.
private struct ListeningRings: View {
    let active: Bool
    let startedAt: Date?
    let tones: Int
    let together: Bool
    let animate: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !(active && animate))) { timeline in
            Canvas { context, size in draw(&context, size: size, now: timeline.date) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0…1 loudness of the sounding tone: a fast attack and a decay per note.
    private func energy(at now: Date) -> Double {
        guard active, let startedAt else { return 0 }
        let elapsed = now.timeIntervalSince(startedAt)
        guard elapsed >= 0 else { return 0 }
        let length = together ? 1.3 : 0.9
        let step = together ? 1.3 : 1.05
        let index = Int(elapsed / step)
        let within = elapsed - Double(index) * step
        guard index < max(1, tones), within < length else { return 0.1 }
        return 0.25 + 0.75 * min(1, within / 0.03) * exp(-within * 2.4)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, now: Date) {
        let cx = Double(size.width) / 2
        let cy = Double(size.height) / 2
        let inner = 68.0
        let outer = Double(min(size.width, size.height)) / 2
        let t = animate ? now.timeIntervalSinceReferenceDate : 0
        let e = animate ? energy(at: now) : (active ? 0.5 : 0)
        let count = 56
        for i in 0..<count {
            let angle = Double(i) / Double(count) * 2 * .pi - .pi / 2
            let wobble = 0.5 + 0.5 * sin(t * 9 + Double(i) * 1.7) * cos(t * 4.3 + Double(i) * 0.61)
            let reach = 3 + (outer - inner - 12) * e * (0.3 + 0.7 * wobble)
            var bar = Path()
            bar.move(to: CGPoint(x: cx + cos(angle) * inner, y: cy + sin(angle) * inner))
            bar.addLine(to: CGPoint(x: cx + cos(angle) * (inner + reach), y: cy + sin(angle) * (inner + reach)))
            context.stroke(bar, with: .color(Palette.mint.opacity(0.16 + 0.6 * e)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        guard active && animate else { return }
        for k in 0..<3 {
            let phase = (t * 0.7 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
            let r = inner + (outer - inner) * phase
            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(Palette.mint.opacity(0.3 * (1 - phase))), lineWidth: 1.2)
        }
    }
}
