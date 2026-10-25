import SwiftUI
import WidgetKit

/// Timbre's watch complications, drawn from the snapshot the watch app keeps (`SnapshotStore`).
@main
struct TimbreWatchWidgets: WidgetBundle {
    var body: some Widget {
        StreakComplication()
    }
}

// MARK: - Timeline

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot?
    /// The snapshot as of this entry's moment: after midnight the flame goes out and the ring empties.
    var day: WatchDay? { snapshot.map { WatchDay($0, now: date) } }
}

extension WatchSnapshot {
    /// The face gallery's example.
    static var sample: WatchSnapshot {
        WatchSnapshot(day: Calendar.current.startOfDay(for: Date()), streak: 7, best: 12, practicedToday: true,
                      steps: [.init(kind: "lesson", symbol: "graduationcap", tint: "violet", title: "Next lesson", minutes: 4, done: true),
                              .init(kind: "tune", symbol: "tuningfork", tint: "neutral", title: "Tune up", minutes: 1, done: true),
                              .init(kind: "ear", symbol: "ear", tint: "neutral", title: "Ear training", minutes: 5, done: false)])
    }
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : StreakEntry(date: Date(), snapshot: SnapshotStore.read()))
    }

    /// Now, and just after the next two midnights, so the flame and ring reset without the watch app running
    /// (a new snapshot reloads the timeline sooner).
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let now = Date()
        let snapshot = SnapshotStore.read()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let tomorrow = midnight.addingTimeInterval(60)
        let dayAfter = tomorrow.addingTimeInterval(86_400)
        let entries = [StreakEntry(date: now, snapshot: snapshot), StreakEntry(date: tomorrow, snapshot: snapshot),
                       StreakEntry(date: dayAfter, snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .after(dayAfter)))
    }
}

// MARK: - Streak

struct StreakComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "timbre.watch.streak", provider: StreakProvider()) { entry in
            StreakComplicationView(entry: entry)
        }
        .configurationDisplayName("Practice streak")
        .description("Your streak and today's set.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

/// The streak flame and count, with today's set as a ring (circular, rectangular) or a count (inline).
struct StreakComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    private var streak: Int { entry.day?.streak ?? 0 }
    private var lit: Bool { entry.day?.practicedToday ?? false }
    private var done: Int { entry.day?.done ?? 0 }
    private var total: Int { entry.day?.total ?? 0 }
    private var flameStyle: AnyShapeStyle { lit ? AnyShapeStyle(Palette.flame) : AnyShapeStyle(.secondary) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryInline: inline
        default: rectangular
        }
    }

    /// The set ring with the flame and the streak inside.
    private var setGauge: some View {
        Gauge(value: Double(done), in: 0...Double(max(1, total))) {
            Text("Today")
        } currentValueLabel: {
            VStack(spacing: -1) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(flameStyle)
                    .widgetAccentable()
                Text(streak, format: .number)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Palette.mint)
    }

    private var circular: some View {
        setGauge
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(streak)-day streak"))
            .accessibilityValue(Text("Today") + Text(verbatim: ": ") + Text("\(done) of \(total)"))
            .containerBackground(for: .widget) { Color.clear }
    }

    private var corner: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(flameStyle)
            .widgetAccentable()
            .widgetLabel {
                Text("\(streak)-day streak")
            }
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Label {
            if total > 0 {
                Text("\(streak)-day streak") + Text(verbatim: " · \(done)/\(total)")
            } else {
                Text("\(streak)-day streak")
            }
        } icon: {
            Image(systemName: "flame.fill")
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            setGauge
            VStack(alignment: .leading, spacing: 1) {
                Text("\(streak)-day streak")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                detail
                    .font(.caption)
                    .lineLimit(1)
                if let quest = entry.day?.quest, !quest.claimed {
                    Text(verbatim: quest.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Palette.flame.opacity(0.3), Palette.stage], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// "Today: 2 of 4", "Daily set complete", or whether today has counted yet.
    private var detail: Text {
        if entry.day?.complete == true { return Text("Daily set complete") }
        if total > 0 { return Text("Today") + Text(verbatim: ": ") + Text("\(done) of \(total)") }
        return lit ? Text("Practised today") : Text("Keep it alive today")
    }
}
