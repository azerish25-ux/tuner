import SwiftUI
import UserNotifications

/// Right after the first tune's reward, while the streak is one day old: the practice reminder asked for on a full
/// card ("Keep your 1-day streak"), with its time, rather than as a small pill on the plan. "Remind me" asks iOS for
/// notifications there and plans the reminders; "Not now" leaves them off (the plan still offers them).
struct ReminderAskStep: View {
    let streak: Int
    @Binding var time: Date
    /// Called once, with whether the reminder is now on.
    let onDone: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var asking = false
    @State private var shown = false
    @State private var finished = false

    /// Only asked while iOS has never asked for notifications, and nothing in the app has offered the reminder yet.
    static func canAsk() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: PracticeReminder.askedKey) else { return false }
        return await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                bell.padding(.top, 36)
                VStack(spacing: 10) {
                    Text("Keep your \(max(1, streak))-day streak")
                        .font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding.reminder.card")
                    Text("One reminder on days you haven't played yet, naming your next lesson. Never more than one a day.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Metrics.proseInset)
                timeRow
            }
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onboardingDock { buttons }
        .onAppear { withMotion(Motion.page, reduceMotion: reduceMotion) { shown = true } }
    }

    /// The bell, ringing once as the card arrives.
    private var bell: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(Palette.mint)
            .symbolEffect(.bounce, value: shown)
            .frame(width: 120, height: 120)
            .background(Circle().fill(RadialGradient(colors: [Palette.mint.opacity(0.18), .clear], center: .center, startRadius: 4, endRadius: 64)))
            .accessibilityHidden(true)
    }

    private var timeRow: some View {
        HStack(spacing: 12) {
            Text("Remind me at").font(.headline).foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            DatePicker("Daily practice reminder", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Palette.mint)
                .fixedSize()
                .accessibilityIdentifier("onboarding.reminder.time")
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }

    private var buttons: some View {
        VStack(spacing: 4) {
            Button(action: allow) {
                if asking { ProgressView().tint(Palette.onAccent) } else { Text("Remind me") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(asking)
            .accessibilityIdentifier("onboarding.reminder.allow")
            Button { finish(on: false, result: "later") } label: {
                Text("Not now").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTarget).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(asking)
            .accessibilityIdentifier("onboarding.reminder.later")
        }
    }

    /// Asks iOS (once: the plan and the first lesson's results won't offer it again) and plans the reminders.
    private func allow() {
        Haptics.shared.selection()
        UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
        asking = true
        Task { @MainActor in
            let on = await PracticeReminder.enable(at: PlanCommitment.minutesOfDay(time))
            asking = false
            if on { Haptics.shared.lock() }
            finish(on: on, result: on ? "allowed" : "denied")
        }
    }

    private func finish(on: Bool, result: String) {
        guard !finished else { return }
        finished = true
        Analytics.log("reminder_ask", ["result": result, "minutes": String(PlanCommitment.minutesOfDay(time))])
        onDone(on)
    }
}
