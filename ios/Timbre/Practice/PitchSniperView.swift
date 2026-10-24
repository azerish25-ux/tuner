import Combine
import SwiftUI
import TimbreCore

/// Pitch Sniper: play or sing the target note; your pitch is a dot homing in on the bullseye.
struct PitchSniperView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game: PitchSniper?
    @State private var hold = 0.0
    @State private var cents: Double?
    @State private var flash: PitchSniper.Outcome?
    @State private var flashToken = 0
    @State private var finished = false
    @State private var restoreAutomatic = true
    private let ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            StageBackground(glow: flashColor, intensity: flash == nil ? 0.6 : 1.4, motes: false)
            if let game {
                if finished { results(game) } else { playing(game) }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: start)
        .onDisappear {
            store.pauseListening()
            store.gameTargetHz = nil
            store.automatic = restoreAutomatic
        }
        .onReceive(ticker) { _ in tick() }
    }

    private var flashColor: Color {
        switch flash {
        case .bullseye: return Palette.mint
        case .near: return Palette.amber
        default: return Color(hex: 0xFFC48C)
        }
    }

    // MARK: Playing

    private func playing(_ game: PitchSniper) -> some View {
        let now = ProcessInfo.processInfo.systemUptime
        return VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain).accessibilityLabel(Text("Leave game"))
                Spacer()
                VStack(spacing: 3) {
                    Text("Round \(min(game.index + 1, game.rounds.count)) of \(game.rounds.count)").font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    SniperChallengeTarget(score: game.score)  // a friend's score to beat, from a challenge link (PlayHubGames.swift)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(game.score.formatted()).font(Typeface.number(20)).foregroundStyle(Palette.ink).contentTransition(.numericText())
                    Text("Combo ×\(game.multiplier)").font(Typeface.label(12)).foregroundStyle(game.combo > 0 ? Palette.amber : Palette.inkFaint)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 8)
            ProgressLine(value: game.remaining(at: now) / PitchSniper.roundSeconds, color: Palette.mint, height: 4)
                .padding(.horizontal, Metrics.gutter).padding(.top, 14)
                .animation(.linear(duration: 1.0 / 30), value: game.index)

            if let round = game.current {
                let parts = NoteReadout.split(PitchMath.noteName(midi: round.midi, notation: store.settings.notation))
                VStack(spacing: 2) {
                    Text("Play or sing").font(.caption.weight(.semibold)).tracking(1.4).textCase(.uppercase).foregroundStyle(Palette.inkSoft)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(parts.name).font(Typeface.note(64)).foregroundStyle(Palette.ink)
                        Text(parts.octave).font(Typeface.displayLight(26)).foregroundStyle(Palette.inkFaint)
                    }
                }
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
            }

            Reticle(cents: cents, hold: hold, flash: flash, animate: !reduceMotion)
                .frame(width: 300, height: 300).padding(.top, 18)

            Group {
                if let cents {
                    Text(abs(cents) <= PitchSniper.bullseyeCents ? String(localized: "Hold it…") : cents < 0 ? String(localized: "\(Int(abs(cents).rounded())) cents flat") : String(localized: "\(Int(abs(cents).rounded())) cents sharp"))
                        .foregroundStyle(abs(cents) <= PitchSniper.bullseyeCents ? Palette.mint : Palette.amber)
                } else {
                    Text(audio.running ? "Listening…" : "Tap Listen to start").foregroundStyle(Palette.inkSoft)
                }
            }
            .font(Typeface.label(18)).padding(.top, 14)
            Text("Hold inside the green ring for a bullseye").font(.footnote).foregroundStyle(Palette.inkSoft).padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(0..<game.rounds.count, id: \.self) { i in
                    Circle().fill(dotColor(game, i)).frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(i == game.index ? Palette.amber : .clear, lineWidth: 2))
                }
            }
            .padding(.top, 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(game.bullseyes) bullseyes so far"))

            Spacer(minLength: 12)
            HStack(spacing: 12) {
                Button { store.toggleTone() } label: {
                    Label(audio.tonePlaying ? "Stop" : "Hear it", systemImage: audio.tonePlaying ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(BrassButtonStyle(prominent: false))
                Button { if !audio.running { store.startListening() } else { advance(self.game?.skip()) } } label: {
                    Text(audio.running ? "Skip" : "Listen")
                }
                .buttonStyle(BrassButtonStyle(prominent: !audio.running))
                .accessibilityIdentifier("sniper.action")
            }
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
        }
    }

    private func dotColor(_ game: PitchSniper, _ i: Int) -> Color {
        guard i < game.outcomes.count else { return .white.opacity(0.08) }
        switch game.outcomes[i] {
        case .bullseye: return Palette.mint
        case .near: return Palette.amber.opacity(0.7)
        case .miss: return Palette.danger.opacity(0.55)
        }
    }

    // MARK: Results

    private func results(_ game: PitchSniper) -> some View {
        let best = store.progress.stats["sniperBest"] ?? game.score
        return VStack(spacing: 18) {
            Spacer()
            Image(systemName: game.won ? "trophy.fill" : "scope").font(.system(size: 54, weight: .bold))
                .foregroundStyle(game.won ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint))
                .symbolEffect(.bounce, value: finished)
            Text(game.won ? "Round won" : "Good shooting").font(Typeface.display(30)).foregroundStyle(Palette.ink)
            Text(game.score.formatted()).font(Typeface.number(56)).foregroundStyle(Palette.ink)
            HStack(spacing: 24) {
                stat("\(game.bullseyes)", "bullseyes")
                stat(best.formatted(), "best")
            }
            if !game.won { Text("Hit \(PitchSniper.winBullseyes) bullseyes to win the round.").font(.footnote).foregroundStyle(Palette.inkSoft) }
            SniperChallengeResult(score: game.score)
            Spacer()
            Button("Play again") { start() }.buttonStyle(BrassButtonStyle()).accessibilityIdentifier("sniper.again")
            Button("Done") { dismiss() }.buttonStyle(BrassButtonStyle(prominent: false))
        }
        .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Typeface.number(22)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    // MARK: Game loop

    private var fretted: Bool { store.instrument.anchorType == "MACHINE_HEAD" || ["guitar", "ukulele", "mandolin"].contains(store.instrument.familyId) }

    private func start() {
        restoreAutomatic = store.automatic
        store.automatic = false
        let notes = store.courses.map(\.targetMidi)
        var seed = UInt64(Date().timeIntervalSince1970)
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" { seed = 7 }
        let next = PitchSniper(notes: notes.isEmpty ? [57, 60, 64, 67] : notes, fretted: fretted, referenceHz: store.settings.referencePitchHz, seed: seed)
        game = next
        finished = false; hold = 0; flash = nil
        store.gameTargetHz = next.current?.frequency
        if !audio.running { store.startListening() }
    }

    private func tick() {
        guard var game, !finished else { return }
        let reading = store.live.reading
        cents = audio.running && reading.frequency != nil ? reading.cents : nil
        let event = game.update(cents: audio.running ? cents : nil, at: ProcessInfo.processInfo.systemUptime)
        self.game = game
        switch event {
        case .holding(let fraction): hold = fraction
        case .finished: advance(event)
        case nil: hold = 0
        }
    }

    private func advance(_ event: PitchSniper.Event?) {
        guard let game, case .finished(let outcome) = event else { return }
        hold = 0
        audio.stopTone()
        switch outcome {
        case .bullseye: Haptics.shared.lock()
        case .near: Haptics.shared.selection()
        case .miss: break
        }
        store.recordProgress(.sniperRound(bullseye: { if case .bullseye = outcome { return true } else { return false } }()), announce: false)
        flashToken += 1
        let token = flashToken
        withAnimation(.easeOut(duration: 0.2)) { flash = outcome }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            if token == flashToken { withAnimation(.easeOut(duration: 0.4)) { flash = nil } }
        }
        if game.isOver {
            finished = true
            store.gameTargetHz = nil
            store.pauseListening()
            store.recordProgress(.sniperGame(score: game.score, won: game.won))
            Analytics.log("sniper_finished", ["score": String(game.score), "won": game.won ? "1" : "0"])
        } else {
            store.gameTargetHz = game.current?.frequency
        }
    }
}

/// Rings at 50, 20 and 5 cents; the live pitch is a glowing dot that homes in on the centre.
private struct Reticle: View {
    let cents: Double?
    let hold: Double
    let flash: PitchSniper.Outcome?
    let animate: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animate)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 - 4
                func ring(_ radius: CGFloat, _ color: Color, _ width: CGFloat = 1) {
                    context.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)), with: .color(color), lineWidth: width)
                }
                ring(r, .white.opacity(0.08)); ring(r * 0.71, .white.opacity(0.10))
                ring(r * 0.4, Palette.amber.opacity(0.45))
                let bull = r * 0.15
                context.fill(Path(ellipseIn: CGRect(x: c.x - bull, y: c.y - bull, width: bull * 2, height: bull * 2)), with: .color(Palette.mint.opacity(flash.map { if case .bullseye = $0 { return 0.5 } else { return 0.16 } } ?? 0.16)))
                ring(bull, Palette.mint, 1.5)
                for (dx, dy) in [(0.0, -1.0), (0.0, 1.0), (-1.0, 0.0), (1.0, 0.0)] {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + dx * r, y: c.y + dy * r))
                    p.addLine(to: CGPoint(x: c.x + dx * r * 0.77, y: c.y + dy * r * 0.77))
                    context.stroke(p, with: .color(.white.opacity(0.18)), lineWidth: 1)
                }
                // Sweep: a slow radar arc, plus the hold progress around the bullseye.
                var sweep = Path()
                sweep.addArc(center: c, radius: r, startAngle: .radians(t * 2), endAngle: .radians(t * 2 + 0.7), clockwise: false)
                context.stroke(sweep, with: .color(Palette.mint.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                if hold > 0 {
                    var arc = Path()
                    arc.addArc(center: c, radius: bull + 7, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * hold), clockwise: false)
                    context.stroke(arc, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                guard let cents else { return }
                // Distance is the error (log-ish, so the last few cents still read); flat sits left, sharp right.
                let error = min(60, abs(cents))
                let distance = r * CGFloat(min(1, sqrt(error / 60)))
                let angle = (cents < 0 ? Double.pi : 0) + sin(t * 1.3) * 0.35
                let p = CGPoint(x: c.x + cos(angle) * distance, y: c.y - sin(angle) * distance)
                let color = error <= PitchSniper.bullseyeCents ? Palette.mint : Palette.amber
                context.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)), with: .radialGradient(Gradient(colors: [color.opacity(0.7), .clear]), center: p, startRadius: 0, endRadius: 22))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(color))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Target"))
        .accessibilityValue(Text(NoteReadout.spoken(cents)))
    }
}
