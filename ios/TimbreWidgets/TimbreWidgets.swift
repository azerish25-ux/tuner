import AppIntents
import SwiftUI
import WidgetKit

@main
struct TimbreWidgets: WidgetBundle {
    var body: some Widget {
        QuickTuneWidget()
        StreakWidget()
        TunerControl()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: WidgetSnapshot(streak: 7, best: 12, practicedToday: true, week: [true, true, false, true, true, true, true], instrument: "Acoustic guitar"))
    }
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: Date(), snapshot: WidgetSnapshot.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // Redraw just after midnight so "practised today" resets without opening the app.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400)).addingTimeInterval(60)
        completion(Timeline(entries: [SnapshotEntry(date: Date(), snapshot: WidgetSnapshot.read())], policy: .after(tomorrow)))
    }
}

// MARK: - Quick tune

/// The app icon's frozen strobe ring: one tap opens Timbre listening.
struct StrobeRing: View {
    var segments = 36
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for ring in 0..<2 {
                let radius = side * (ring == 0 ? 0.46 : 0.37)
                let count = ring == 0 ? segments : segments * 2 / 3
                for i in 0..<count {
                    let start = Double(i) / Double(count) * 2 * .pi
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + .pi / Double(count)), clockwise: false)
                    let lift = 0.45 + 0.55 * (0.5 + 0.5 * cos(start + .pi / 2))
                    context.stroke(arc, with: .color(Palette.brass.opacity(lift)), lineWidth: side * 0.05)
                }
            }
            var wave = Path()
            for i in 0...40 {
                let u = Double(i) / 40
                let point = CGPoint(x: center.x - side * 0.26 + side * 0.52 * u, y: center.y + side * 0.07 * sin(.pi * 2 * u))
                if i == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            context.stroke(wave, with: .color(Palette.locked), style: StrokeStyle(lineWidth: side * 0.035, lineCap: .round))
        }
    }
}

struct QuickTuneWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "timbre.quicktune", provider: SnapshotProvider()) { entry in
            QuickTuneView(entry: entry).widgetURL(URL(string: "timbre://tune"))
        }
        .configurationDisplayName("Quick tune")
        .description("Open Timbre already listening.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct QuickTuneView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack { AccessoryWidgetBackground(); Image(systemName: "tuningfork").font(.title3.weight(.semibold)) }
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "tuningfork").font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tune").font(.headline)
                    Text(entry.snapshot.instrument.isEmpty ? String(localized: "Timbre") : entry.snapshot.instrument).font(.caption).lineLimit(1)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(spacing: 8) {
                StrobeRing().frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Tune").font(Typeface.display(22)).foregroundStyle(Palette.ink)
            }
            .containerBackground(for: .widget) {
                RadialGradient(colors: [Color(hex: 0x2A2016), Palette.stage], center: .center, startRadius: 4, endRadius: 120)
            }
        }
    }
}

// MARK: - Streak

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "timbre.streak", provider: SnapshotProvider()) { entry in
            StreakView(entry: entry).widgetURL(URL(string: "timbre://practice"))
        }
        .configurationDisplayName("Practice streak")
        .description("Your streak and the last seven days.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct StreakView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("\(snapshot.streak)-day streak", systemImage: "flame.fill").font(.headline)
                Text(snapshot.practicedToday ? "Practised today" : "Keep it alive today").font(.caption)
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "flame.fill").font(.title2).foregroundStyle(snapshot.practicedToday ? Palette.ember : Palette.inkFaint)
                    Text("\(snapshot.streak)").font(Typeface.display(44)).foregroundStyle(Palette.ink).contentTransition(.numericText())
                    Text("day streak").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    Spacer(minLength: 0)
                    Text(snapshot.practicedToday ? "Practised today" : "Ten minutes keeps it alive")
                        .font(.caption2).foregroundStyle(snapshot.practicedToday ? Palette.success : Palette.brass).lineLimit(2)
                }
                if family == .systemMedium {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 10) {
                        Text("Last 7 days").font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkFaint)
                        HStack(spacing: 6) {
                            ForEach(Array(snapshot.week.enumerated()), id: \.offset) { index, done in
                                Capsule().fill(done ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.line))
                                    .frame(width: 12, height: index == snapshot.week.count - 1 ? 44 : 34)
                            }
                        }
                        Text("Best \(snapshot.best)").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [Color(hex: 0x1B1611), Palette.stage], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

// MARK: - Control Center

struct TunerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "timbre.control.tune") {
            ControlWidgetButton(action: OpenTunerIntent()) {
                Label("Tune", systemImage: "tuningfork")
            }
        }
        .displayName("Timbre tuner")
        .description("Open Timbre listening.")
    }
}
