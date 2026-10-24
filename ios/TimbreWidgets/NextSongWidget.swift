import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct NextSongEntry: TimelineEntry {
    let date: Date
    /// The chosen shelf as the app last saw it; nil before the app has written its library.
    let shelf: WidgetLibrary.Shelf?
}

struct NextSongProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextSongEntry {
        NextSongEntry(date: Date(), shelf: .sample)
    }

    func snapshot(for configuration: NextSongConfiguration, in context: Context) async -> NextSongEntry {
        let current = entry(for: configuration)
        // The gallery shows a song even before the app has picked one.
        return context.isPreview && current.shelf?.song == nil ? placeholder(in: context) : current
    }

    /// The app redraws it whenever the pick changes (`WidgetLibrary.write`); the day's song holds until then.
    func timeline(for configuration: NextSongConfiguration, in context: Context) async -> Timeline<NextSongEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: NextSongConfiguration) -> NextSongEntry {
        NextSongEntry(date: Date(), shelf: WidgetLibrary.read().shelf(id: configuration.shelf?.id))
    }
}

extension WidgetLibrary.Shelf {
    /// The widget gallery's example: the first Original.
    static let sample = WidgetLibrary.Shelf(
        id: WidgetLibrary.allShelf, title: "Songs", symbol: "music.note.list", accent: "amber",
        song: WidgetLibrary.Song(id: "sample", title: "Kite Weather", course: "Originals", minutes: 5, xp: 30, stars: 0, access: "open",
                                 colors: [0x62C9FF, 0x1F3A4D, 0x1A1430], chords: ["G", "D", "Em", "C"], bpm: 92),
        finished: 3, total: 20)
}

// MARK: - Widget

/// The song to play next: the Songs tab's song of the day, across every song or one instrument's. One tap opens it
/// (or its paywall, or Songs when it comes later in its course).
struct NextSongWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetLibrary.nextSongKind, intent: NextSongConfiguration.self, provider: NextSongProvider()) { entry in
            NextSongView(entry: entry).widgetURL(WidgetLibrary.songURL(entry.shelf?.song?.id))
        }
        .configurationDisplayName("Next song")
        .description("The song to play next, one tap away.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct NextSongView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextSongEntry

    var body: some View {
        if let song = entry.shelf?.song {
            content(song)
        } else {
            empty
        }
    }

    @ViewBuilder private func content(_ song: WidgetLibrary.Song) -> some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("Next song", systemImage: "music.note").font(.caption.weight(.semibold))
                Text(verbatim: song.title).font(.headline).lineLimit(2).widgetAccentable()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            medium(song)
                .containerBackground(for: .widget) { SongBackdrop(song: song) }
        default:
            small(song)
                .containerBackground(for: .widget) { SongBackdrop(song: song) }
        }
    }

    // MARK: Small

    private func small(_ song: WidgetLibrary.Song) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 0) {
                SongSleeve(song: song, record: true)
                    .frame(width: 44, height: 44)
                    .padding(.leading, 12)
                Spacer(minLength: 4)
                AccessMark(song: song)
            }
            Spacer(minLength: 2)
            SongEyebrow(song: song)
            Text(verbatim: song.title)
                .font(Typeface.display(17, relativeTo: .headline)).foregroundStyle(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.75)
                .widgetAccentable()
            Footer(song: song)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Medium

    private func medium(_ song: WidgetLibrary.Song) -> some View {
        HStack(alignment: .center, spacing: 16) {
            SongSleeve(song: song, record: true)
                .frame(width: 104, height: 104)
                .padding(.leading, 26)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    SongEyebrow(song: song)
                    Spacer(minLength: 4)
                    AccessMark(song: song)
                }
                Text(verbatim: song.title)
                    .font(Typeface.display(20, relativeTo: .title3)).foregroundStyle(Palette.ink)
                    .lineLimit(2).minimumScaleFactor(0.75)
                    .widgetAccentable()
                Text(verbatim: song.course).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                if !song.chords.isEmpty { ChordChips(chords: song.chords, tint: SongColors(song).primary) }
                Spacer(minLength: 0)
                Footer(song: song, shelf: entry.shelf)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Before the app has picked a song

    private var empty: some View {
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 1) {
                    Label("Next song", systemImage: "music.note").font(.caption.weight(.semibold))
                    Text("Open Timbre to pick your next song.").font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { Color.clear }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "music.note.list").font(.title3).foregroundStyle(Palette.amber)
                    Spacer(minLength: 0)
                    Text("Next song").font(Typeface.display(18)).foregroundStyle(Palette.ink)
                    Text("Open Timbre to pick your next song.").font(.caption2).foregroundStyle(Palette.inkSoft).lineLimit(3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { Palette.stage }
            }
        }
    }
}

// MARK: - Pieces

/// The sleeve's colours as the Songs tab draws them (`CoverArt`): the motif's colour and the gradient's two ends.
private struct SongColors {
    let primary: Color
    let deep: Color
    let far: Color

    init(_ song: WidgetLibrary.Song) {
        func color(_ index: Int, _ fallback: UInt) -> Color { Color(hex: index < song.colors.count ? song.colors[index] : fallback) }
        primary = color(0, 0x4CF2B8)
        deep = color(1, 0x16191E)
        far = color(2, 0x060708)
    }
}

/// The stage, lit from the sleeve's corner in the song's colour.
private struct SongBackdrop: View {
    let song: WidgetLibrary.Song

    var body: some View {
        let colors = SongColors(song)
        ZStack {
            Palette.stage
            RadialGradient(colors: [colors.primary.opacity(0.30), colors.deep.opacity(0.18), .clear],
                           center: .topLeading, startRadius: 4, endRadius: 260)
        }
    }
}

/// "NEXT SONG" in the song's colour.
private struct SongEyebrow: View {
    let song: WidgetLibrary.Song

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
            Text("Next song").textCase(.uppercase).tracking(0.8)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(SongColors(song).primary)
        .lineLimit(1)
    }
}

/// Pro gold for a song Pro opens, a lock for one further on, else its stars (empty ones still to win).
private struct AccessMark: View {
    let song: WidgetLibrary.Song

    var body: some View {
        switch song.access {
        case "pro":
            Text("Pro")
                .font(Typeface.label(10)).textCase(.uppercase).tracking(0.6)
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Palette.proGold))
        case "locked":
            Image(systemName: "lock.fill").font(.caption2.weight(.bold)).foregroundStyle(Palette.inkSoft)
        default:
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(index < song.stars ? Palette.amber : Palette.ink.opacity(0.2))
                }
            }
            .accessibilityLabel(Text("\(song.stars) of 3 stars"))
        }
    }
}

/// The time and XP (or "Play again" once it has stars), and on the medium widget the tempo and the shelf's count.
private struct Footer: View {
    let song: WidgetLibrary.Song
    var shelf: WidgetLibrary.Shelf?

    var body: some View {
        // The tempo goes first when the row runs short.
        ViewThatFits(in: .horizontal) {
            row(tempo: true)
            row(tempo: false)
        }
        .font(.caption2)
        .foregroundStyle(Palette.inkSoft)
        .lineLimit(1)
    }

    private func row(tempo: Bool) -> some View {
        HStack(spacing: 8) {
            if song.stars > 0 {
                Text("Play again")
            } else {
                Text("\(song.minutes) min · +\(song.xp) XP")
            }
            if let shelf {
                if tempo, let bpm = song.bpm { Text(verbatim: "♩ \(bpm)") }
                Spacer(minLength: 0)
                Label {
                    Text(verbatim: "\(shelf.finished)/\(shelf.total)")
                } icon: {
                    Image(systemName: "music.note.list")
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }
}

/// Up to four chord names as small chips: the song at a glance.
private struct ChordChips: View {
    let chords: [String]
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(chords, id: \.self) { chord in
                Text(verbatim: chord)
                    .font(Typeface.label(11))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 0.5))
            }
        }
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}

/// The song's record sleeve in its own colours, sound rings on it, the record peeking from its left edge.
private struct SongSleeve: View {
    let song: WidgetLibrary.Song
    var record = false

    var body: some View {
        let colors = SongColors(song)
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack(alignment: .leading) {
                if record {
                    VinylDisc(label: colors.primary)
                        .frame(width: side * 0.92, height: side * 0.92)
                        .offset(x: -side * 0.26)
                }
                sleeve(colors)
                    .frame(width: side, height: side)
            }
        }
        .accessibilityHidden(true)
    }

    private func sleeve(_ colors: SongColors) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [colors.deep, colors.far], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Canvas { context, size in
                    let center = CGPoint(x: size.width * 0.72, y: size.height * 0.7)
                    let side = min(size.width, size.height)
                    for ring in 0..<5 {
                        let radius = side * (0.12 + 0.13 * CGFloat(ring))
                        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        context.stroke(Path(ellipseIn: rect), with: .color(colors.primary.opacity(0.75 - 0.13 * Double(ring))),
                                       lineWidth: max(1, side * 0.025))
                    }
                    let dot = side * 0.07
                    context.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                                 with: .color(colors.primary))
                }
                .clipShape(shape)
            }
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
    }
}

/// A black record with faint grooves and a label in the song's colour.
private struct VinylDisc: View {
    let label: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func circle(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            context.fill(circle(side / 2), with: .color(Color(hex: 0x0B0C0E)))
            for groove in 0..<4 {
                context.stroke(circle(side * (0.44 - 0.05 * CGFloat(groove))), with: .color(.white.opacity(0.07)), lineWidth: 0.6)
            }
            context.fill(circle(side * 0.17), with: .color(label))
            context.fill(circle(side * 0.03), with: .color(Palette.stage))
        }
    }
}
