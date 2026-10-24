import AppIntents
import SwiftUI
import WidgetKit

@main
struct TimbreWidgets: WidgetBundle {
    var body: some Widget {
        QuickTuneWidget()
        NextLessonWidget()
        StreakWidget()
        TunerControl()
        MetronomeControl()
        PracticeLiveActivity()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: WidgetSnapshot(streak: 7, best: 12, practicedToday: true, week: [true, true, false, true, true, true, true], instrument: "Acoustic guitar",
                                                             lesson: .init(course: "Guitar", symbol: "guitars.fill", accent: "mint", title: "Your first chord: E minor", minutes: 4, xp: 20, done: 3, total: 60)))
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

// MARK: - Next lesson

struct NextLessonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "timbre.nextlesson", provider: SnapshotProvider()) { entry in
            NextLessonView(entry: entry).widgetURL(URL(string: "timbre://learn"))
        }
        .configurationDisplayName("Next lesson")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct NextLessonView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let lesson = entry.snapshot.lesson {
            content(lesson)
        } else {
            empty
        }
    }

    @ViewBuilder private func content(_ lesson: WidgetSnapshot.NextLesson) -> some View {
        let accent = Palette.accent(lesson.accent)
        let progress = lesson.total == 0 ? 0 : Double(lesson.done) / Double(lesson.total)
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(lesson.course, systemImage: lesson.symbol).font(.caption.weight(.semibold))
                Text(lesson.title).font(.headline).lineLimit(2)
            }
            .containerBackground(for: .widget) { Color.clear }
        default:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: lesson.symbol).font(.caption.weight(.bold)).foregroundStyle(accent)
                        Text("Next lesson").font(.caption2.weight(.bold)).textCase(.uppercase).tracking(0.8).foregroundStyle(accent).lineLimit(1)
                    }
                    Text(lesson.title).font(Typeface.display(family == .systemSmall ? 17 : 20)).foregroundStyle(Palette.ink)
                        .lineLimit(3).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\(lesson.minutes) min · +\(lesson.xp) XP").font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    if family == .systemSmall {
                        Capsule().fill(Palette.line).frame(height: 4)
                            .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(accent).frame(width: max(4, g.size.width * progress)) } }
                    }
                }
                if family == .systemMedium {
                    Spacer(minLength: 0)
                    ZStack {
                        Circle().stroke(Palette.line, lineWidth: 8)
                        Circle().trim(from: 0, to: max(0.02, progress)).stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(lesson.done)/\(lesson.total)").font(Typeface.number(15)).foregroundStyle(Palette.ink)
                            Text(lesson.course).font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 10)
                    }
                    .frame(width: 96, height: 96)
                }
            }
            .containerBackground(for: .widget) {
                ZStack {
                    Palette.stage
                    RadialGradient(colors: [accent.opacity(0.28), .clear], center: .topLeading, startRadius: 2, endRadius: 220)
                }
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "graduationcap.fill").font(.title3).foregroundStyle(Palette.mint)
            Text("Course complete").font(Typeface.display(18)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
            Text("Replay any lesson for three stars.").font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Palette.stage }
    }
}

// MARK: - Control Center, Lock Screen and Action button

// Each control runs an intent from Timbre/Intents/SharedIntents.swift, which is built into both the app and this
// extension: the intent opens Timbre, so the system performs it in the app and RootView routes it.

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

struct MetronomeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "timbre.control.metronome") {
            ControlWidgetButton(action: OpenMetronomeIntent()) {
                Label("Metronome", systemImage: "metronome.fill")
            }
        }
        .displayName("Metronome")
        .description("Open the metronome")
    }
}
