import AppIntents
import SwiftUI

/// The streak as the widget snapshot last saw it, carried forward to today without opening the app: a run stays
/// alive through the day after its last practice and is over after that. (Banked streak freezes are spent when the
/// app next opens, which may bring a run back; this answer never claims one that might not survive.)
struct StreakStatus: Equatable {
    let days: Int
    let best: Int
    let practicedToday: Bool
    /// The last seven days ending today, oldest first.
    let week: [Bool]

    init(_ snapshot: WidgetSnapshot, now: Date = Date(), calendar: Calendar = .current) {
        let age = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: snapshot.updated), to: calendar.startOfDay(for: now)).day ?? 0)
        switch age {
        case 0:
            days = snapshot.streak; practicedToday = snapshot.practicedToday
        case 1:
            days = snapshot.practicedToday ? snapshot.streak : 0; practicedToday = false
        default:
            days = 0; practicedToday = false
        }
        best = max(snapshot.best, days)
        let recent = snapshot.week.count == 7 ? snapshot.week : Array(repeating: false, count: 7)
        week = age >= 7 ? Array(repeating: false, count: 7) : Array(recent.dropFirst(age)) + Array(repeating: false, count: age)
    }

    var dialog: IntentDialog {
        if days > 0 && practicedToday { return IntentDialog("You're on a \(days)-day streak, and you've practised today.") }
        if days > 0 { return IntentDialog("You're on a \(days)-day streak. Ten minutes today keeps it alive.") }
        return IntentDialog("No streak running. Ten minutes today starts one.")
    }
}

/// Siri's and Shortcuts' card for the streak: the widget's flame, count and week, on its own dark stage so it
/// reads on a light platter too.
struct StreakSnippet: View {
    let status: StreakStatus

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            count
            Spacer(minLength: 0)
            week
        }
        .padding(18)
        .background(background)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private var count: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(status.practicedToday ? Palette.flame : Palette.inkFaint)
            Text(status.days, format: .number)
                .font(Typeface.display(.display))
                .foregroundStyle(Palette.ink)
            Text("day streak").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
            if status.practicedToday {
                Text("Practised today").font(.caption2).foregroundStyle(Palette.success).lineLimit(2)
            } else if status.days > 0 {
                Text("Keep it alive today").font(.caption2).foregroundStyle(Palette.flame).lineLimit(2)
            }
        }
    }

    private var week: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("Last 7 days").font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkFaint)
            HStack(spacing: 6) {
                ForEach(Array(status.week.enumerated()), id: \.offset) { index, done in
                    Capsule()
                        .fill(done ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.line))
                        .frame(width: 12, height: index == status.week.count - 1 ? 44 : 34)
                }
            }
            Text("Best \(status.best)").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
        }
        .accessibilityHidden(true)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x1B1611), Palette.stage], startPoint: .top, endPoint: .bottom))
    }
}
