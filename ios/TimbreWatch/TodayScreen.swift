import SwiftUI
import WatchKit

/// Today at a glance: the streak flame inside today's set ring, the set's activities, the open quest and the next lesson,
/// as the iPhone last sent them (carried past midnight by `WatchDay`), and "Start today's practice" on the iPhone.
struct TodayScreen: View {
    @EnvironmentObject private var sync: WatchSync
    @State private var outcome: WatchSync.Outcome?
    @State private var sending = false
    /// Handoff to the iPhone stays offered for a few minutes after "Start today's practice".
    @State private var handoff = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(sync.snapshot.map { WatchDay($0, now: context.date) })
        }
        .containerBackground(Self.background, for: .tabView)
        .userActivity(WatchLink.todayActivity, isActive: handoff) { activity in
            activity.title = String(localized: "Today's set")
            activity.isEligibleForHandoff = true
        }
        .task(id: handoff) {
            guard handoff else { return }
            do { try await Task.sleep(for: .seconds(300)) } catch { return }
            handoff = false
        }
    }

    private static let background = LinearGradient(colors: [Palette.flame.opacity(0.22), Palette.stage], startPoint: .top, endPoint: .bottom)

    private func content(_ day: WatchDay?) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                hero(day)
                if day == nil {
                    Text("Open Timbre on your iPhone")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                if let day, !day.steps.isEmpty {
                    setCard(day)
                }
                if let quest = day?.quest {
                    questCard(quest)
                }
                if let lesson = day?.lesson {
                    lessonCard(lesson)
                }
                startButton
                if let outcome {
                    outcomeLine(outcome)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 6)
        }
    }

    // MARK: Streak

    private func hero(_ day: WatchDay?) -> some View {
        let streak = day?.streak ?? 0
        let lit = day?.practicedToday ?? false
        return VStack(spacing: 3) {
            ZStack {
                SetRing(steps: day?.steps ?? [], lineWidth: 7)
                VStack(spacing: 0) {
                    WristFlame(lit: lit).frame(width: 26, height: 26)
                    Text(streak, format: .number)
                        .font(Typeface.display(26, relativeTo: .title2))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText(value: Double(streak)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 64)
            }
            .frame(width: 96, height: 96)
            Text("day streak")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
            if day != nil {
                status(lit: lit, streak: streak)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(streak)-day streak"))
        .accessibilityValue(lit ? Text("Practised today") : Text("Keep it alive today"))
    }

    private func status(lit: Bool, streak: Int) -> some View {
        (lit ? Text("Practised today") : Text("Keep it alive today"))
            .font(.caption2)
            .foregroundStyle(lit ? Palette.mint : Palette.amber)
            .multilineTextAlignment(.center)
    }

    // MARK: Today's set

    private func setCard(_ day: WatchDay) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Today")
                    .font(Typeface.display(15, relativeTo: .headline))
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                if day.complete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Palette.amber)
                        .accessibilityHidden(true)
                } else {
                    Text("\(day.done) of \(day.total)")
                        .font(Typeface.number(12))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            if day.complete {
                Text("Daily set complete")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.amber)
            }
            ForEach(day.steps) { step in
                stepRow(step)
            }
        }
        .wristCard()
    }

    private func stepRow(_ step: WatchSnapshot.Step) -> some View {
        let tint = Palette.accent(step.tint)
        return HStack(spacing: 8) {
            Image(systemName: step.done ? "checkmark" : step.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(step.done ? Palette.onAccent : tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(step.done ? tint : tint.opacity(0.16)))
            Text(verbatim: step.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(step.done ? Palette.inkSoft : Palette.ink)
                .strikethrough(step.done, color: Palette.inkFaint)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.done ? Text("Done") : Text(verbatim: ""))
    }

    // MARK: Quest and lesson

    private func questCard(_ quest: WatchSnapshot.QuestLine) -> some View {
        let tint = quest.claimed ? Palette.mint : Palette.amber
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: quest.claimed ? "checkmark.circle.fill" : quest.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(verbatim: quest.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(quest.claimed ? Palette.inkSoft : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                ProgressBar(value: Double(quest.done) / Double(max(1, quest.total)), tint: tint)
                Text(verbatim: "\(quest.done) / \(quest.total)")
                    .font(Typeface.number(11))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize()
            }
            if !quest.claimed {
                Text("+\(quest.xp) XP")
                    .font(Typeface.label(11))
                    .foregroundStyle(Palette.mint)
            }
        }
        .wristCard()
        .accessibilityElement(children: .combine)
    }

    private func lessonCard(_ lesson: WatchSnapshot.LessonLine) -> some View {
        let tint = Palette.accent(lesson.accent)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: lesson.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.16)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Next lesson")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                Text(verbatim: lesson.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                Text(verbatim: lesson.course)
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
        }
        .wristCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Start on iPhone

    private var startButton: some View {
        Button { start() } label: {
            HStack(spacing: 6) {
                Image(systemName: sending ? "ellipsis" : "iphone")
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Start today's practice")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(Palette.mint))
        }
        .buttonStyle(PressStyle())
        .disabled(sending)
    }

    private func outcomeLine(_ outcome: WatchSync.Outcome) -> some View {
        let opened = outcome == .opened
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon(outcome))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(opened ? Palette.mint : Palette.amber)
                .accessibilityHidden(true)
            (opened ? Text("Opened on your iPhone") : Text("Open Timbre on your iPhone"))
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
    }

    private func icon(_ outcome: WatchSync.Outcome) -> String {
        switch outcome {
        case .opened: return "checkmark.circle.fill"
        case .waiting: return "iphone.radiowaves.left.and.right"
        case .unreachable: return "iphone.slash"
        }
    }

    /// Asks the iPhone to open Today, and offers Handoff to it meanwhile (the iPhone's App Switcher shows Timbre).
    private func start() {
        guard !sending else { return }
        sending = true
        handoff = true
        Task {
            let result = await sync.startToday()
            sending = false
            withAnimation(.snappy) { outcome = result }
            WKInterfaceDevice.current().play(result == .opened ? .success : .click)
        }
    }
}
