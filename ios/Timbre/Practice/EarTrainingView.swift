import SwiftUI
import TimbreCore

/// Ear training: ten questions a round. Each question is drawn as the Practice hub's interval staircase: as the tones
/// sound, the first note rises onto its step and the rest rise behind a frosted veil marked with the places they may
/// land (the answers to choose from), a "?" pulsing with them; on the answer the veil lifts and the notes land on
/// their steps, named, with the interval. Round dots, a combo that heats up on a run of right answers, Recent answers
/// to hear again, and a results card at the end.
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
    /// Answers so far in this drill, newest first, kept across rounds (each can be heard again).
    @State private var history: [EarAnswerRecord] = []
    @State private var answered = 0
    /// Bumped with every new question, so its staircase starts unanswered rather than hopping back down.
    @State private var serial = 0
    /// Once you have answered a question of your own, Recent no longer opens with an example.
    @AppStorage("ear.recent.exampleSeen") private var exampleSeen = false
    private let length = 10

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                drillPicker
                if finished, let session {
                    results(session)
                        .transition(.adaptive(.scale(scale: 0.94).combined(with: .opacity), reduceMotion: reduceMotion))
                } else if let question {
                    hud
                    card(question)
                        .transition(.opacity)
                    recentStrip
                }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 14)
        }
        .stageTopShade()
        .background {
            StageBackground(glow: hot ? Palette.flame : Palette.spotlight, intensity: hot ? 1.35 : 1, motes: false)
                .animation(Motion.reveal, value: hot)
        }
        .navigationTitle("Ear training")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefillExample()
            if session == nil { start() }
        }
    }

    /// Three or more right in a row warms the stage.
    private var hot: Bool { combo >= 3 && !finished }

    /// The drill, as the app's segmented pill (the chips' pill of light sliding to the choice). Intervals and Chords
    /// are Pro: without it they carry a lock, and a tap opens the paywall while the pill stays put.
    private var drillPicker: some View {
        SegmentedPill(options: [EarDrill.pitchDirection, EarDrill.interval, EarDrill.chordQuality],
                      selection: Binding(get: { drill }, set: { pick($0) }),
                      identifier: { "ear.drill.\($0.rawValue)" }) { value in
            drillLabel(value)
        }
    }

    private func drillLabel(_ value: EarDrill) -> some View {
        let locked = value != .pitchDirection && !commerce.isPro
        return HStack(spacing: 5) {
            drillTitle(value)
            if locked {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
                    .accessibilityLabel(Text("Pro"))
            }
        }
    }

    private func drillTitle(_ value: EarDrill) -> Text {
        switch value {
        case .pitchDirection: return Text("Pitch")
        case .interval: return Text("Intervals")
        case .chordQuality: return Text("Chords")
        }
    }

    private func pick(_ value: EarDrill) {
        guard value != drill else { return }
        if value != .pitchDirection && !commerce.isPro { store.presentPaywall("ear.\(value.rawValue)"); return }
        drill = value; history = []; prefillExample(); start()
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
                } animation: { _ in Motion.pop }
                .transition(.adaptive(.scale(scale: 0.6).combined(with: .opacity), reduceMotion: reduceMotion))
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
            answerStage(question)
            answers(question)
        }
        .stillCard()
        .animation(Motion.pluck, value: picked)
    }

    /// The question as a staircase of semitones from its first note (`EarAnswerStage`), with Hear again under it.
    private func answerStage(_ question: EarQuestion) -> some View {
        let playing = audio.tonePlaying
        let picture = EarPicture(question: question, reference: store.settings.referencePitchHz, notation: store.settings.notation)
        return VStack(spacing: 10) {
            EarAnswerStage(picture: picture, revealed: picked != nil, playing: playing, startedAt: playedAt,
                           together: question.simultaneous)
                .frame(height: 204)
                .id(serial)
                .overlay { SparkBurst(trigger: burst, color: Palette.mint).frame(width: 300, height: 300) }
                .overlay(alignment: .topTrailing) { xpFloat }
            hearButton(question, picture: picture, playing: playing)
        }
    }

    /// Plays the question again. The app is sounding the tones, so it reads "Hear it" with a speaker while they play,
    /// as lessons do ("Listen" is kept for the microphone). Once answered it names what you heard,
    /// "A3 → E4 · Perfect 5th", and still plays it again.
    private func hearButton(_ question: EarQuestion, picture: EarPicture, playing: Bool) -> some View {
        let revealed = picked != nil
        return Button { play(question) } label: {
            HStack(spacing: 8) {
                Image(systemName: playing ? "speaker.wave.2.fill" : (revealed ? "speaker.wave.2" : "play.fill"))
                    .symbolEffect(.variableColor.iterative, isActive: playing && !reduceMotion)
                if revealed {
                    picture.revealText(answer: question.answer)
                } else if playing {
                    Text("Hear it")
                } else {
                    Text("Hear again")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(revealed ? Palette.ink : Palette.mint)
            .lineLimit(1).minimumScaleFactor(0.75)
            .padding(.horizontal, 16).frame(minHeight: 40)
            .background(Capsule().fill(Palette.mint.opacity(playing ? 0.16 : 0.07)))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(playing ? 0.55 : 0.25), lineWidth: 1))
            .tapTarget()
        }
        .buttonStyle(PressScaleStyle())
        .animation(Motion.quick, value: playing)
        .accessibilityLabel(revealed ? picture.spoken(answer: question.answer) : Text("Hear again"))
        .accessibilityHint(revealed ? Text("Hear again") : Text(verbatim: ""))
        .accessibilityIdentifier("ear.play")
    }

    /// "+2 XP" rising over the staircase's corner on a right answer.
    @ViewBuilder private var xpFloat: some View {
        if showXP {
            Text("+\(XPReward.earCorrect) XP").font(Typeface.label(13)).foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Palette.mint))
                .shadow(color: Palette.mint.opacity(0.5), radius: 10)
                .padding(.top, 8)
                .transition(.adaptive(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                  removal: .opacity.combined(with: .offset(y: -18))), reduceMotion: reduceMotion))
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

    // MARK: Recent answers

    /// Under the card: the latest answers, newest first, each a chip that plays its question again
    /// (a miss shows what you picked struck through, then the answer). A first visit opens with one example
    /// chip to hear (`prefillExample`); until the first answer, one line says what will land there, in a slot the
    /// chips' height so nothing jumps when they arrive.
    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Recent")
            if history.isEmpty {
                recentHint
                    .transition(.opacity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(history) { record in
                            recentChip(record)
                                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .railBleed(leading: Metrics.gutter, trailing: Metrics.gutter)
                .transition(.opacity)
                if history.allSatisfy(\.example) {
                    Text("Answers appear here. Tap one to hear it again.")
                        .font(.footnote).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        }
        .padding(.top, 2)
    }

    /// First visit: Recent opens with one example of this drill to hear (the same one every time), until you have
    /// answered a question of your own.
    private func prefillExample() {
        guard !exampleSeen, history.isEmpty else { return }
        history = [example(for: drill)]
    }

    private func example(for drill: EarDrill) -> EarAnswerRecord {
        let reference = store.settings.referencePitchHz
        func question(_ seed: UInt64) -> EarQuestion {
            var session = EarSession(drill: drill, seed: seed, level: 0, referenceHz: reference)
            return session.next()
        }
        // The first seed whose interval moves (a unison would make a dull example).
        let chosen = (UInt64(3)...UInt64(40)).lazy.map(question).first { $0.answer != Intervals.names[0] } ?? question(3)
        return EarAnswerRecord(id: -1, question: chosen, picked: chosen.answer, example: true)
    }

    private var recentHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.counterclockwise").font(.caption.weight(.semibold)).accessibilityHidden(true)
            Text("Answers appear here. Tap one to hear it again.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(Palette.inkFaint)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4])))
    }

    /// An answer to hear again: right or wrong (an example is marked so), the answer, and the notes it was
    /// ("A3 → E4"; a chord's root; higher-or-lower's cents).
    private func recentChip(_ record: EarAnswerRecord) -> some View {
        let tint = record.example ? Palette.amber : (record.right ? Palette.mint : Palette.coral)
        let notes = EarPicture(question: record.question, reference: store.settings.referencePitchHz, notation: store.settings.notation).chipNotes
        return Button { play(record.question) } label: {
            HStack(spacing: 6) {
                if record.example {
                    Text("Example").font(.caption.weight(.semibold)).foregroundStyle(Palette.amber)
                } else {
                    Image(systemName: record.right ? "checkmark" : "xmark").font(.caption.weight(.heavy)).foregroundStyle(tint)
                }
                if !record.right {
                    Text(LocalizedStringKey(record.picked)).strikethrough().foregroundStyle(Palette.inkFaint)
                    Image(systemName: "arrow.right").font(.caption2.weight(.bold)).foregroundStyle(Palette.inkFaint)
                }
                Text(LocalizedStringKey(record.question.answer)).foregroundStyle(Palette.ink)
                if let notes {
                    NoteGlyphs.text(notes, size: 12).font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                }
                if let cents = record.question.cents {
                    Text(verbatim: "\(Int(abs(cents).rounded()))¢").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                }
                Image(systemName: "speaker.wave.2.fill").font(.caption2).foregroundStyle(Palette.inkFaint)
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12).padding(.vertical, 4).frame(minHeight: 38)
            .background(Capsule().fill(Palette.stageRaised))
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
            // The chip stays 38 pt; the finger gets 44.
            .tapTarget()
        }
        .buttonStyle(PressScaleStyle())
        .disabled(picked != nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(record.question.answer)) + Text(verbatim: notes.map { ", " + EarPicture.spokenNotes($0) } ?? ""))
        .accessibilityValue(record.example ? Text("Example") : (record.right ? Text(verbatim: "") : Text("Not quite.")))
        .accessibilityHint(Text("Hear again"))
        .accessibilityAddTraits(.isButton)
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
            StatTileRow {
                StatTile(symbol: "sparkles", tint: Palette.mint, value: Text("+\(shownXP)"), label: "XP", alignment: .center)
                StatTile(symbol: "scope", tint: Palette.amber, value: Text("\(accuracy)%"), label: "accuracy", alignment: .center)
                StatTile(symbol: "flame.fill", tint: Palette.flame, value: Text(verbatim: "×" + bestCombo.formatted()), label: "best run",
                         alignment: .center)
            }
            roundDots.allowsHitTesting(false)
            VStack(spacing: 10) {
                Button("Go again") { start() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("ear.again")
                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("ear.done")
            }
            .padding(.top, 4)
        }
        .stillCard(tint: Palette.mint)
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
            // A fixed ring: the score shrinks to fit its hole rather than growing past it.
            Text.fraction(session.correct, session.asked).font(Typeface.hero(40)).foregroundStyle(Palette.ink)
                .heroNumeral()
                .frame(maxWidth: 120)
        }
        .frame(width: 156, height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(session.correct) of \(session.asked)"))
    }

    // MARK: Flow

    private func start() {
        let level = store.settings.earLevels?[drill.rawValue] ?? 0
        var next = EarSession(drill: drill, level: level, referenceHz: store.settings.referencePitchHz)
        let first = next.next()
        round += 1
        serial += 1
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
        withMotion(Motion.pluck, reduceMotion: reduceMotion) {
            history.removeAll { $0.example }
            history.insert(EarAnswerRecord(id: answered, question: question, picked: choice), at: 0)
            if history.count > 12 { history.removeLast() }
        }
        answered += 1
        exampleSeen = true
        // The staircase names the notes as they land; VoiceOver hears them too.
        let picture = EarPicture(question: question, reference: store.settings.referencePitchHz, notation: store.settings.notation)
        AccessibilityNotification.Announcement(picture.spokenString(answer: NSLocalizedString(question.answer, comment: ""))).post()
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
        // Long enough to see the notes land and read their names (a miss a little longer).
        Task { @MainActor in
            if right {
                try? await Task.sleep(for: .milliseconds(520))
                withAnimation(Motion.fade) { showXP = false }
                try? await Task.sleep(for: .milliseconds(580))
            } else {
                try? await Task.sleep(for: .milliseconds(1800))
            }
            guard token == round, var s = session else { return }
            if s.asked >= length {
                finish(s)
            } else {
                let next = s.next(); session = s; serial += 1; self.question = next; picked = nil
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
            withAnimation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.9)) { ringShown = true }
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

/// One answered question, kept so it can be heard again from the Recent strip.
private struct EarAnswerRecord: Identifiable {
    let id: Int
    let question: EarQuestion
    let picked: String
    /// A first visit's example (`prefillExample`), not an answer of yours: dropped at your first answer.
    var example = false
    var right: Bool { picked == question.answer }
}

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
        case .idle, .faded: return Palette.controlLine
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
            .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(tint, lineWidth: revealed ? 2 : 1))
            .shadow(color: glow, radius: 14)
            .opacity(state == .faded ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .phaseAnimator([false, true], trigger: state) { content, flashing in
            content
                .brightness(flashing && revealed ? 0.2 : 0)
                .scaleEffect(flashing && state == .right ? 1.05 : 1)
        } animation: { flashing in
            flashing ? Animation.easeOut(duration: 0.12) : Motion.reward
        }
        .animation(Motion.pluck, value: state)
    }
}

// MARK: - Answer stage

/// The notes of a question, for the answer stage and the Recent chips: the first note, the others as semitones
/// above it (an interval's second note, a chord's upper notes), or for higher-or-lower the second note's detune.
private struct EarPicture {
    let drill: EarDrill
    /// MIDI note of the first tone.
    let root: Int
    /// Semitones above the root of the other notes, 0…12 (empty for higher-or-lower).
    let steps: [Int]
    /// Higher-or-lower: the second note's detune in cents.
    let cents: Double?
    let notation: String
    /// Intervals: the steps the answers to choose from would land on (semitones above the root), marked under the
    /// veil before the answer. They say no more than the buttons do.
    let candidates: [Int]

    init(question: EarQuestion, reference: Double, notation: String) {
        let midis = question.tones.map { Int(PitchMath.midi(frequency: $0, reference: reference).rounded()) }
        let first = midis.first ?? 57
        drill = question.drill
        root = first
        cents = question.cents
        steps = question.cents == nil ? midis.dropFirst().map { max(0, min(12, $0 - first)) } : []
        self.notation = notation
        candidates = question.drill == .interval ? question.choices.compactMap { Intervals.names.firstIndex(of: $0) } : []
    }

    /// "E♭4"-style names as the voice tools write them (signs set by `NoteGlyphs`).
    func name(_ midi: Int) -> String { VoiceNoteName.name(midi, notation: notation) }

    /// "+35¢", "−35¢".
    var centsLabel: String? {
        guard let cents else { return nil }
        return (cents < 0 ? "−" : "+") + "\(Int(abs(cents).rounded()))¢"
    }

    /// The notes heard: "A3 → E4", a chord's "A3 C♯4 E4", higher-or-lower's "A3 → +35¢".
    var notes: String {
        if let centsLabel { return name(root) + " → " + centsLabel }
        let names = [name(root)] + steps.map { name(root + $0) }
        return drill == .chordQuality ? names.joined(separator: " ") : names.joined(separator: " → ")
    }

    /// A Recent chip's notes: an interval's two, a chord's root; none for higher-or-lower (its chip shows the cents).
    var chipNotes: String? {
        switch drill {
        case .pitchDirection: return nil
        case .interval: return notes
        case .chordQuality: return name(root)
        }
    }

    /// "A3 → E4 · Perfect 5th".
    func revealText(answer: String) -> Text {
        NoteGlyphs.text(notes, size: 15) + Text(verbatim: "  ·  ") + Text(LocalizedStringKey(answer))
    }

    /// For VoiceOver: "A3, E4, Perfect 5th" (no arrows read aloud).
    func spoken(answer: String) -> Text {
        Text(verbatim: Self.spokenNotes(notes) + ", ") + Text(LocalizedStringKey(answer))
    }

    /// The same, already in words (`answer` localized), for an announcement.
    func spokenString(answer: String) -> String {
        Self.spokenNotes(notes) + ", " + answer
    }

    static func spokenNotes(_ notes: String) -> String {
        NoteNames.glyphs(notes).replacingOccurrences(of: " → ", with: ", ")
    }
}

/// A question drawn as the Practice hub's interval staircase (`IntervalStairsArt`): a step a semitone up from the first
/// note. On the question's first hearing each note rises as its tone begins: the first onto its step, the rest into a
/// frosted veil over the steps they might land on. They rise to the veil's "?", the same height whatever the answer,
/// so nothing is given away; the veil marks the places the answers to choose from would land (higher-or-lower's two,
/// the intervals on the buttons). On the answer the veil lifts and the notes hop up to their steps, each with its
/// interval and name. A replay only glows (timed like `AudioService.playTones`). Reduce Motion: the notes stand in
/// place, the tones glow without pulsing and the answer fades in on its steps.
private struct EarAnswerStage: View {
    let picture: EarPicture
    let revealed: Bool
    let playing: Bool
    let startedAt: Date?
    let together: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal = 0.0
    /// When this question was first played: its notes rise with that hearing only.
    @State private var firstHearing: Date?

    init(picture: EarPicture, revealed: Bool, playing: Bool, startedAt: Date?, together: Bool) {
        self.picture = picture
        self.revealed = revealed
        self.playing = playing
        self.startedAt = startedAt
        self.together = together
        _firstHearing = State(initialValue: startedAt)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !(playing && !reduceMotion))) { timeline in
            EarStairsCanvas(picture: picture, reveal: reveal, still: reduceMotion,
                            first: energy(tone: 0, at: timeline.date), second: energy(tone: 1, at: timeline.date),
                            firstRise: rise(tone: 0, at: timeline.date), secondRise: rise(tone: 1, at: timeline.date))
        }
        .accessibilityHidden(true)
        .onAppear { if revealed { reveal = 1 } }
        .onChange(of: startedAt) { _, now in
            if firstHearing == nil { firstHearing = now }
        }
        .onChange(of: revealed) { _, now in
            guard now else { return }
            withAnimation(reduceMotion ? Motion.reduced : .easeInOut(duration: 0.8)) { reveal = 1 }
        }
    }

    /// 0…1 loudness of tone `tone` (a chord's notes sound as one): a fast attack and a decay per note.
    private func energy(tone: Int, at now: Date) -> Double {
        guard playing, let startedAt else { return 0 }
        if reduceMotion { return 0.5 }
        let elapsed = now.timeIntervalSince(startedAt)
        let length = together ? 1.3 : 0.9
        let step = together ? 1.3 : 1.05
        let within = elapsed - Double(together ? 0 : tone) * step
        guard within >= 0, within < length else { return 0 }
        return 0.25 + 0.75 * min(1, within / 0.03) * exp(-within * 2.4)
    }

    /// 0…1: how far tone `tone`'s note has risen. On the question's first hearing it rises over 0.42 s from the moment
    /// its tone begins (a chord's notes together); on a replay, once heard, or under Reduce Motion it stands risen.
    private func rise(tone: Int, at now: Date) -> Double {
        guard let startedAt else { return 0 }
        guard playing, !reduceMotion, startedAt == firstHearing else { return 1 }
        let begin = together ? 0 : Double(tone) * 1.05
        return min(1, max(0, (now.timeIntervalSince(startedAt) - begin) / 0.42))
    }
}

/// The staircase at one point of the reveal; `reveal` animates (0: unanswered, 1: every note landed).
private struct EarStairsCanvas: View, Animatable {
    let picture: EarPicture
    var reveal: Double
    let still: Bool
    let first: Double
    let second: Double
    let firstRise: Double
    let secondRise: Double

    var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let frame = EarStairsArt.Frame(picture: picture, reveal: reveal, still: still, first: first, second: second,
                                           firstRise: firstRise, secondRise: secondRise)
            if picture.cents != nil {
                EarStairsArt.drawPitch(&context, size: size, frame: frame)
            } else {
                EarStairsArt.drawSteps(&context, size: size, frame: frame)
            }
        }
    }
}

private enum EarStairsArt {
    fileprivate struct Frame {
        let picture: EarPicture
        let reveal: Double
        let still: Bool
        /// Loudness of the first tone and of the rest (the chord's: both), 0…1.
        let first: Double
        let second: Double
        /// How far the first note and the rest have risen, 0…1.
        let firstRise: Double
        let secondRise: Double
    }

    static let noteR: CGFloat = 5.5
    /// Room under the floor for two rows of note names.
    static let nameRoom: CGFloat = 34

    /// Intervals and chords: thirteen steps, unison to octave.
    fileprivate static func drawSteps(_ context: inout GraphicsContext, size: CGSize, frame: Frame) {
        let picture = frame.picture
        let count = 13
        let inset: CGFloat = 8
        let floorY = size.height - nameRoom
        let rise = max(30, floorY - 44)
        let stepWidth = (size.width - inset * 2) / CGFloat(count)
        func centerX(_ i: Int) -> CGFloat { inset + stepWidth * (CGFloat(i) + 0.5) }
        func top(_ i: Int) -> CGFloat { floorY - 6 - CGFloat(i) / 12 * rise }
        let targets = picture.steps
        let highest = targets.max() ?? 0
        let stagger = 0.15
        let span = max(0.1, 1 - stagger * Double(max(0, targets.count - 1)))
        func progress(_ k: Int) -> Double { min(1, max(0, (frame.reveal - stagger * Double(k)) / span)) }
        let unknown = max(0, 1 - frame.reveal * 3)

        // The ladder: the root's step lit as its note lands, the answer's steps as theirs do, the span between warming.
        for i in 0..<count {
            var lit = 0.0
            if i == 0 {
                lit = (0.55 + 0.45 * frame.first) * min(1, frame.firstRise * 2)
            } else if let k = targets.firstIndex(of: i) {
                lit = progress(k)
            } else if i < highest {
                lit = 0.16 * frame.reveal
            }
            let rect = CGRect(x: centerX(i) - stepWidth / 2 + 1.5, y: top(i), width: max(2, stepWidth - 3), height: max(4, floorY - top(i)))
            step(&context, rect: rect, lit: lit)
        }
        floorLine(&context, from: inset, to: size.width - inset, y: floorY)

        // Note names under the floor; one too close to another drops to a second row.
        var firstRow: [CGFloat] = []
        func nameY(_ x: CGFloat) -> CGFloat {
            if firstRow.contains(where: { abs($0 - x) < 36 }) { return floorY + 26 }
            firstRow.append(x)
            return floorY + 12
        }
        func nameX(_ x: CGFloat) -> CGFloat { min(size.width - 18, max(18, x)) }

        // The first note hops up from the floor onto its step as it sounds.
        let rest = CGPoint(x: centerX(0), y: top(0) - noteR - 1)
        let root = frame.still || frame.firstRise >= 1 ? rest : hop(from: CGPoint(x: rest.x, y: floorY + 2), to: rest, progress: frame.firstRise)
        let rootAlpha = min(1, frame.firstRise * 5)
        let rootX = nameX(centerX(0))
        context.draw(noteText(picture.name(picture.root), color: Palette.inkSoft), at: CGPoint(x: rootX, y: nameY(rootX)))

        // Unanswered: a veil over the steps above the root, the places the answers on the buttons would land marked on
        // it, the rest of the notes rising behind it to its "?".
        if unknown > 0 {
            let veilTop = top(12) - 24
            let veil = CGRect(x: centerX(1) - stepWidth / 2, y: veilTop, width: stepWidth * 12, height: floorY - veilTop)
            let spot = CGPoint(x: centerX(3), y: top(10))
            if frame.secondRise > 0 {
                let hidden = CGPoint(x: spot.x, y: floorY - (floorY - spot.y) * CGFloat(overshoot(frame.secondRise)))
                hiddenNote(&context, at: hidden, energy: frame.second, alpha: unknown * min(1, frame.secondRise * 4))
            }
            veilPanel(&context, rect: veil, alpha: unknown)
            for semitones in picture.candidates where (1...12).contains(semitones) {
                let x = centerX(semitones)
                slot(&context, from: x - stepWidth / 2 + 3, to: x + stepWidth / 2 - 3, y: top(semitones), label: Intervals.short[semitones],
                     at: CGPoint(x: x, y: top(semitones) - 9), alpha: unknown)
            }
            var arc = Path()
            arc.move(to: root)
            arc.addQuadCurve(to: CGPoint(x: spot.x - 16, y: spot.y + 6), control: CGPoint(x: (root.x + spot.x) / 2, y: spot.y - 10))
            context.stroke(arc, with: .color(Palette.amber.opacity(0.28 * unknown * rootAlpha)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
            mystery(&context, at: spot, energy: frame.second, alpha: unknown)
        }
        dot(&context, at: root, energy: frame.first, alpha: rootAlpha)

        // Answered: each note hops from the root to its step, its interval over it and its name under the floor.
        for (k, semitones) in targets.enumerated() {
            let p = progress(k)
            guard p > 0 else { continue }
            let landing = CGPoint(x: centerX(semitones), y: top(semitones) - noteR - 1)
            let point = frame.still ? landing : hop(from: root, to: landing, progress: p)
            let alpha = frame.still ? p : min(1, p * 4)
            if targets.count == 1 && semitones > 0 {
                var arc = Path()
                arc.move(to: root)
                arc.addQuadCurve(to: point, control: CGPoint(x: (root.x + point.x) / 2, y: min(root.y, point.y) - 24))
                context.stroke(arc, with: .color(Palette.amber.opacity(0.5 * alpha)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
            }
            dot(&context, at: point, energy: 0.6 * p, alpha: alpha)
            let short = Text(verbatim: Intervals.short[semitones]).font(Typeface.label(12)).foregroundStyle(Palette.amber.opacity(alpha))
            context.draw(short, at: CGPoint(x: min(size.width - 14, max(14, point.x)), y: max(10, point.y - 18)))
            if semitones > 0 {
                let x = nameX(centerX(semitones))
                context.draw(noteText(picture.name(picture.root + semitones), color: Palette.ink.opacity(alpha)), at: CGPoint(x: x, y: nameY(x)))
            }
        }
    }

    /// Higher or lower: two columns side by side, the second rising or falling by the detune (drawn larger than
    /// life: a semitone would be a whole step), at least a clear nudge however fine the ear has become. Unanswered, the
    /// second stands behind a veil marked with its two possible places, the first one's level running between them.
    fileprivate static func drawPitch(_ context: inout GraphicsContext, size: CGSize, frame: Frame) {
        let picture = frame.picture
        let floorY = size.height - nameRoom
        let rise = max(40, floorY - 26)
        let width = min(120, size.width * 0.3)
        let gap: CGFloat = 24
        let leftX = size.width / 2 - gap / 2 - width / 2
        let rightX = size.width / 2 + gap / 2 + width / 2
        let base = floorY - rise * 0.5
        let cents = picture.cents ?? 0
        let magnitude = CGFloat(max(0.32, min(1, abs(cents) / 50))) * rise * 0.4
        let shift = magnitude * (cents < 0 ? -1 : 1)
        let p = frame.reveal
        let eased = p * p * (3 - 2 * p)
        let moved = frame.still ? (p > 0 ? 1 : 0) : eased
        let secondTop = base - shift * CGFloat(moved)
        let alpha = frame.still ? p : min(1, p * 4)
        let unknown = max(0, 1 - p * 3)

        // The first note's column, rising from the floor to its pitch as it sounds.
        let firstTop = floorY - (floorY - base) * CGFloat(overshoot(frame.firstRise))
        if frame.firstRise > 0 {
            let firstRect = CGRect(x: leftX - width / 2, y: firstTop, width: width, height: max(2, floorY - firstTop))
            step(&context, rect: firstRect, lit: 0.55 + 0.45 * frame.first)
        }
        floorLine(&context, from: leftX - width / 2 - 8, to: rightX + width / 2 + 8, y: floorY)

        // Unanswered: the second note rising behind the veil to the first one's level, whichever way it really went;
        // the two places it may land marked on the veil, a higher and a lower, with the difference.
        if unknown > 0 {
            let veilTop = base - magnitude - 24
            let veil = CGRect(x: rightX - width / 2, y: veilTop, width: width, height: floorY - veilTop)
            if frame.secondRise > 0 {
                let hidden = CGPoint(x: rightX, y: floorY - (floorY - base) * CGFloat(overshoot(frame.secondRise)))
                hiddenNote(&context, at: hidden, energy: frame.second, alpha: unknown * min(1, frame.secondRise * 4))
            }
            veilPanel(&context, rect: veil, alpha: unknown)
            let amount = "\(Int(abs(cents).rounded()))¢"
            slot(&context, from: veil.minX + 8, to: veil.maxX - 8, y: base - magnitude, label: "+" + amount,
                 at: CGPoint(x: veil.maxX + 6, y: base - magnitude), anchor: .leading, alpha: unknown)
            slot(&context, from: veil.minX + 8, to: veil.maxX - 8, y: base + magnitude, label: "−" + amount,
                 at: CGPoint(x: veil.maxX + 6, y: base + magnitude), anchor: .leading, alpha: unknown)
        }

        // The first note's level, carried across: where the second would be if it were the same.
        var level = Path()
        level.move(to: CGPoint(x: leftX, y: base))
        level.addLine(to: CGPoint(x: rightX + width / 2, y: base))
        context.stroke(level, with: .color(Palette.amber.opacity(0.22 * min(1, frame.firstRise * 2))), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        if unknown > 0 {
            mystery(&context, at: CGPoint(x: rightX, y: base), energy: frame.second, alpha: unknown)
        }
        let firstDot = CGPoint(x: leftX, y: firstTop - noteR - 1)
        dot(&context, at: firstDot, energy: frame.first, alpha: min(1, frame.firstRise * 5))
        context.draw(noteText(picture.name(picture.root), color: Palette.inkSoft), at: CGPoint(x: leftX, y: floorY + 12))

        // Answered: the second column steps out from the first one's level onto its place, the cents over it.
        guard p > 0 else { return }
        let secondRect = CGRect(x: rightX - width / 2, y: secondTop, width: width, height: max(4, floorY - secondTop))
        var faded = context
        faded.opacity = alpha
        step(&faded, rect: secondRect, lit: 1)
        let secondDot = CGPoint(x: rightX, y: secondTop - noteR - 1)
        var link = Path()
        link.move(to: firstDot)
        link.addQuadCurve(to: secondDot, control: CGPoint(x: (firstDot.x + secondDot.x) / 2, y: min(firstDot.y, secondDot.y) - 20))
        context.stroke(link, with: .color(Palette.amber.opacity(0.5 * alpha)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
        dot(&context, at: secondDot, energy: 0.6 * p, alpha: alpha)
        if let label = picture.centsLabel {
            let text = Text(verbatim: label).font(Typeface.label(12)).foregroundStyle(Palette.amber.opacity(alpha))
            context.draw(text, at: CGPoint(x: rightX, y: max(10, secondDot.y - 18)))
        }
    }

    // MARK: Pieces

    /// A step of the staircase: an amber column, its top edge brighter the more it is lit.
    private static func step(_ context: inout GraphicsContext, rect: CGRect, lit: Double) {
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Palette.amber.opacity(0.07 + 0.3 * lit), Palette.amber.opacity(0.02)]),
            startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        var edge = Path()
        edge.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        edge.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        context.stroke(edge, with: .color(Palette.amber.opacity(0.16 + 0.64 * lit)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func floorLine(_ context: inout GraphicsContext, from start: CGFloat, to end: CGFloat, y: CGFloat) {
        var line = Path()
        line.move(to: CGPoint(x: start, y: y))
        line.addLine(to: CGPoint(x: end, y: y))
        context.stroke(line, with: .color(.white.opacity(0.07)), lineWidth: 1)
    }

    /// A note: amber with a soft halo that swells with its tone.
    private static func dot(_ context: inout GraphicsContext, at point: CGPoint, energy: Double, alpha: Double) {
        let halo = 14 + 6 * CGFloat(energy)
        context.fill(SniperScopeArt.circle(point, halo), with: .radialGradient(
            Gradient(colors: [Palette.amber.opacity((0.3 + 0.45 * energy) * alpha), .clear]), center: point, startRadius: 0, endRadius: halo))
        context.fill(SniperScopeArt.circle(point, noteR), with: .color(Palette.amber.opacity(alpha)))
        context.fill(SniperScopeArt.circle(CGPoint(x: point.x - 1.5, y: point.y - 1.5), 2), with: .color(.white.opacity(0.8 * alpha)))
    }

    /// A note out of sight: its glow, drawn before the veil so the veil frosts it over.
    private static func hiddenNote(_ context: inout GraphicsContext, at point: CGPoint, energy: Double, alpha: Double) {
        let halo = 20 + 10 * CGFloat(energy)
        context.fill(SniperScopeArt.circle(point, halo), with: .radialGradient(
            Gradient(colors: [Palette.amber.opacity((0.4 + 0.4 * energy) * alpha), .clear]), center: point, startRadius: 0, endRadius: halo))
        context.fill(SniperScopeArt.circle(point, noteR), with: .color(Palette.amber.opacity(0.85 * alpha)))
    }

    /// The veil over what is still to name: frosted, finely hatched and edged in a dashed line; it lifts as it goes.
    private static func veilPanel(_ context: inout GraphicsContext, rect: CGRect, alpha: Double) {
        let lifted = rect.offsetBy(dx: 0, dy: -10 * CGFloat(1 - alpha))
        let shape = Path(roundedRect: lifted, cornerRadius: 8)
        context.fill(shape, with: .color(Palette.stageRaised.opacity(0.62 * alpha)))
        context.fill(shape, with: .linearGradient(Gradient(colors: [Palette.amber.opacity(0.08 * alpha), Palette.amber.opacity(0.02 * alpha)]),
                                                  startPoint: CGPoint(x: lifted.midX, y: lifted.minY), endPoint: CGPoint(x: lifted.midX, y: lifted.maxY)))
        var hatch = context
        hatch.clip(to: shape)
        var lines = Path()
        var x = lifted.minX - lifted.height
        while x < lifted.maxX {
            lines.move(to: CGPoint(x: x, y: lifted.maxY))
            lines.addLine(to: CGPoint(x: x + lifted.height, y: lifted.minY))
            x += 9
        }
        hatch.stroke(lines, with: .color(.white.opacity(0.035 * alpha)), lineWidth: 1)
        context.stroke(shape, with: .color(Palette.amber.opacity(0.3 * alpha)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
    }

    /// A place the hidden note may land: a dashed mark at its height and the answer it would be, named.
    private static func slot(_ context: inout GraphicsContext, from start: CGFloat, to end: CGFloat, y: CGFloat, label: String,
                             at labelPoint: CGPoint, anchor: UnitPoint = .center, alpha: Double) {
        var line = Path()
        line.move(to: CGPoint(x: start, y: y))
        line.addLine(to: CGPoint(x: end, y: y))
        context.stroke(line, with: .color(Palette.amber.opacity(0.45 * alpha)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 3]))
        let text = Text(verbatim: label).font(Typeface.label(10)).foregroundStyle(Palette.amber.opacity(0.75 * alpha))
        context.draw(text, at: labelPoint, anchor: anchor)
    }

    /// The notes still to name: a "?" in a glow that swells with their tone.
    private static func mystery(_ context: inout GraphicsContext, at point: CGPoint, energy: Double, alpha: Double) {
        let halo = 18 + 10 * CGFloat(energy)
        context.fill(SniperScopeArt.circle(point, halo), with: .radialGradient(
            Gradient(colors: [Palette.amber.opacity((0.12 + 0.35 * energy) * alpha), .clear]), center: point, startRadius: 0, endRadius: halo))
        let mark = Text(verbatim: "?").font(Typeface.display(28)).foregroundStyle(Palette.amber.opacity((0.45 + 0.55 * energy) * alpha))
        context.draw(mark, at: point)
    }

    /// Partway along a hop from `from` to `to`: up in an arc and down onto the step.
    private static func hop(from: CGPoint, to: CGPoint, progress p: Double) -> CGPoint {
        let eased = p * p * (3 - 2 * p)
        let lift = CGFloat(sin(Double.pi * p)) * 22
        return CGPoint(x: from.x + (to.x - from.x) * CGFloat(eased), y: from.y + (to.y - from.y) * CGFloat(p) - lift)
    }

    /// A rise that overshoots a touch and settles (back-out easing), 0…1.
    private static func overshoot(_ x: Double) -> Double {
        let t = min(1, max(0, x)) - 1
        let c = 1.4
        return 1 + (c + 1) * t * t * t + c * t * t
    }

    private static func noteText(_ name: String, color: Color) -> Text {
        NoteGlyphs.text(name, size: 12).font(Typeface.label(12)).foregroundStyle(color)
    }
}
