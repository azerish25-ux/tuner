import SwiftUI
import TimbreCore
import UniformTypeIdentifiers

/// "Your songs" on the Songs tab: the player's own charts as sleeves on a rail, and "Add a song" (import a chart file,
/// paste one, write one, or, with Pro, draft one from a recording of theirs). Empty, the shelf is one row (a small
/// crate of sleeves, what it's for, and "Add a song"), so it doesn't hold the catalogue below the fold; the add sheet
/// says what each way in takes. Either way "Add a song" shows once. Three charts are free (`YourSongsPolicy`); a song
/// opens full screen (`ChartSongView`).
struct YourSongsShelf: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var library = YourSongsStore.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The empty row's crate fans its sleeves out once it is on screen.
    @State private var fanned = false
    @State private var adding = false
    @State private var next: AddSongChoice?
    @State private var importing: ImportKind?
    @State private var writing = false
    @State private var open: OpenSong?
    @State private var drafting: DraftSource?
    @State private var deleting: UserSong?

    enum ImportKind { case chart, recording }

    struct OpenSong: Identifiable {
        let id: String
    }

    struct DraftSource: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
    }

    private var tileWidth: CGFloat { sizeClass == .regular ? 176 : 148 }

    // The modifier chain is split into stages so the type checker handles each in reasonable time.
    var body: some View {
        dialogs(sheets(importer(shelf)))
            .onAppear {
                library.collectInbox(store: store)
                openPending()
            }
            .onChange(of: library.pendingOpen) { _, _ in openPending() }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            if library.songs.isEmpty {
                invitation
            } else {
                header
                rail
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("yoursongs.shelf")
    }

    private var importingBinding: Binding<Bool> {
        Binding(get: { importing != nil }, set: { if !$0 { importing = nil } })
    }

    private var importTypes: [UTType] { importing == .recording ? [.audio] : YourSongsStore.chartTypes }

    private func importer<Content: View>(_ content: Content) -> some View {
        content.fileImporter(isPresented: importingBinding, allowedContentTypes: importTypes) { result in
            let kind = importing
            importing = nil
            guard case let .success(url) = result else { return }
            imported(url, as: kind ?? .chart)
        }
    }

    private func sheets<Content: View>(_ content: Content) -> some View {
        content
            .background { addSheet }
            .background { editorSheet }
            .background { draftSheet }
            .fullScreenCover(item: $open) { item in
                ChartSongView(songId: item.id)
                    .environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce)
            }
    }

    private var addSheet: some View {
        Color.clear.sheet(isPresented: $adding, onDismiss: runNext) {
            AddSongSheet(canAdd: library.canAdd(pro: store.isPro), pro: store.isPro) { choice in
                next = choice
                adding = false
            }
            .environmentObject(store).environmentObject(store.commerce)
        }
    }

    private var editorSheet: some View {
        Color.clear.sheet(isPresented: $writing) {
            ChartEditorView(source: ChordProEdit.newChart(title: String(localized: "New song", bundle: TimbreLocalization.bundle), artist: nil, lyrics: ""),
                            isNew: true) { source in
                if let song = library.add(source: source) { show(song.id) }
            }
        }
    }

    private var draftSheet: some View {
        Color.clear.sheet(item: $drafting) { draft in
            RecordingDraftSheet(url: draft.url, name: draft.name) { song in show(song.id) }
                .environmentObject(store)
        }
    }

    private var deletingBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private var problemBinding: Binding<Bool> {
        Binding(get: { library.problem != nil && open == nil }, set: { if !$0 { library.problem = nil } })
    }

    private func dialogs<Content: View>(_ content: Content) -> some View {
        content
            .confirmationDialog("Delete this song?", isPresented: deletingBinding, titleVisibility: .visible, presenting: deleting) { song in
                Button("Delete", role: .destructive) { library.delete(song) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The chart and the recording you added go from this iPhone.")
            }
            .alert("Timbre", isPresented: problemBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: library.problem ?? "")
            }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            // The shelf's own glyph, a chart of chords over words: the player's charts, not another record.
            Glyph(.chart, size: Glyph.lead)
            SectionHeader(Text("Your songs")) {
                HStack(spacing: 8) {
                    if !store.isPro && !library.songs.isEmpty {
                        Text.fraction(library.songs.count, YourSongsPolicy.freeChartLimit)
                            .font(Typeface.number(.caption)).foregroundStyle(Palette.inkSoft)
                    }
                    Button { startAdding() } label: { addCapsule.tapTarget() }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityIdentifier("yoursongs.add")
                }
            }
        }
    }

    /// "Add a song" as a small mint capsule: the shelf's one way in, in its header or on the empty row.
    private var addCapsule: some View {
        Label("Add a song", systemImage: "plus")
            .font(Typeface.label(.footnote)).foregroundStyle(Palette.onAccent)
            .lineLimit(1)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(Capsule().fill(Palette.mint))
            .fixedSize()
    }

    // MARK: Empty

    /// One row, the whole of it a button to the add sheet: a crate of sleeves, "Your songs" and what it's for, and
    /// "Add a song". VoiceOver hears what the shelf takes (a chart, a recording, Apple Music) as the hint. At the
    /// accessibility sizes the capsule goes under the words.
    private var invitation: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                             : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        // In a row the words take the room between the crate and the capsule.
        let wordsWidth: CGFloat? = stacked ? nil : CGFloat.infinity
        return Button { startAdding() } label: {
            layout {
                HStack(spacing: 14) {
                    crate
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your songs").font(Typeface.cardTitle).foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("songs.library.empty.title")
                        Text("Play the songs you love").font(.footnote).foregroundStyle(Palette.inkSoft)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: wordsWidth, alignment: .leading)
                addCapsule
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding, tint: Palette.mint)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Add a song"))
        .accessibilityHint(Text("Bring a chord chart (ChordPro or chords over the words), paste one or write your own. Play it along with your own recording, or listen on Apple Music."))
        .accessibilityIdentifier("yoursongs.add")
    }

    /// Three sleeves, as if pulled from a crate, drawn like the songs' own (`SongCover`) without their type; they fan
    /// out with a pluck when the row comes on screen (at once with Reduce Motion).
    private var crate: some View {
        let turns: [Double] = [-15, 10, -2]
        let shifts: [CGFloat] = [-10, 10, 0]
        return ZStack {
            ForEach(Self.crateArt.indices, id: \.self) { index in
                SongCover(art: Self.crateArt[index], corner: 6, titled: false)
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .rotationEffect(.degrees(fanned ? turns[index] : 0))
                    .offset(x: fanned ? shifts[index] : 0, y: fanned && index < 2 ? 2 : 0)
            }
        }
        .frame(width: 58, height: 44)
        .accessibilityHidden(true)
        .onAppear {
            guard !fanned else { return }
            if reduceMotion {
                fanned = true
            } else {
                withAnimation(Motion.pluck.delay(0.15)) { fanned = true }
            }
        }
    }

    /// The crate's sleeves: fixed, so they look the same on every visit.
    private static let crateArt: [CoverArt] = [
        CoverArt(id: "yoursongs.crate.1", title: "", accent: "violet", genre: .swing, label: "", number: 1, motif: .stripes),
        CoverArt(id: "yoursongs.crate.2", title: "", accent: "orchid", genre: .folk, label: "", number: 2, motif: .sunset),
        CoverArt(id: "yoursongs.crate.3", title: "", accent: "mint", genre: .anthem, label: "", number: 3, motif: .halftone),
    ]

    // MARK: Rail

    /// The player's songs; "Add a song" is the header's.
    private var rail: some View {
        EdgeRail(spacing: 14, selection: nil as String?) {
            ForEach(Array(library.songs.enumerated()), id: \.element.id) { item in
                tile(item.element, number: item.offset + 1).id(item.element.id)
            }
        }
    }

    private func tile(_ song: UserSong, number: Int) -> some View {
        let chart = library.chart(for: song)
        let title = library.title(of: song)
        let art = Self.art(for: song, title: title, artist: chart.artist, number: number)
        let keyName = chart.resolvedKey.map { ChartSongView.keyName((tonic: (($0.tonic + song.transform.soundingShift) % 12 + 12) % 12, minor: $0.minor)) }
        return Button { show(song.id) } label: {
            VStack(alignment: .leading, spacing: 8) {
                SongCover(art: art)
                    .frame(width: tileWidth, height: tileWidth)
                    .overlay(alignment: art.freeCorner) { badges(song).padding(8) }
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title).font(Typeface.label(.footnote)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(verbatim: [chart.artist, keyName.map { String(localized: "Key \($0)", bundle: TimbreLocalization.bundle) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
            .frame(width: tileWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .contextMenu {
            Button { show(song.id) } label: { Label("Open", systemImage: "music.note") }
            Button(role: .destructive) { deleting = song } label: { Label("Delete song", systemImage: "trash") }
        }
        .accessibilityLabel(Text(verbatim: [title, chart.artist].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityValue(song.recording(.file) != nil ? Text("With your recording") : Text(verbatim: ""))
        .accessibilityIdentifier("yoursongs.song.\(number)")
        .alignmentGuide(VerticalAlignment.center) { dimensions in dimensions[.top] }
    }

    /// Small marks on the sleeve: the song has the player's recording, or an Apple Music pick.
    private func badges(_ song: UserSong) -> some View {
        HStack(spacing: 4) {
            if song.recording(.file) != nil { badge("waveform") }
            if song.recording(.appleMusic) != nil { badge("music.note") }
        }
        .accessibilityHidden(true)
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.ink)
            .frame(width: 24, height: 24)
            .background(Circle().fill(.black.opacity(0.55)))
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
    }

    /// A user song's sleeve: the same generated art as the curriculum's songs, its genre dealt from its id.
    static func art(for song: UserSong, title: String, artist: String?, number: Int) -> CoverArt {
        let genres = CoverArt.Genre.allCases
        let genre = genres[Int(CoverArt.hash(song.id) % UInt64(genres.count))]
        return CoverArt(id: song.id, title: title, accent: "mint", genre: genre,
                        label: artist ?? String(localized: "Your songs", bundle: TimbreLocalization.bundle), number: number)
    }

    // MARK: Adding

    private func startAdding() {
        Haptics.shared.selection()
        adding = true
        Analytics.log("yoursongs_add_open", ["count": "\(library.songs.count)"])
    }

    /// What was chosen in the sheet, once it has gone (an importer or the paywall can't show over it).
    private func runNext() {
        guard let choice = next else { return }
        next = nil
        switch choice {
        case .file: importing = .chart
        case .recording: importing = .recording
        case .write: writing = true
        case .pasted(let id): show(id)
        case .paywall: store.presentPaywall("your_songs")
        }
    }

    private func imported(_ url: URL, as kind: ImportKind) {
        switch kind {
        case .chart:
            if let song = library.importChart(from: url) { show(song.id) }
        case .recording:
            // A copy to work on while Timbre listens; the library keeps its own if a chart is made.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension.isEmpty ? "m4a" : url.pathExtension)
            do {
                try FileManager.default.copyItem(at: url, to: copy)
                drafting = DraftSource(url: copy, name: url.deletingPathExtension().lastPathComponent)
            } catch {
                library.problem = String(localized: "That recording couldn't be added.", bundle: TimbreLocalization.bundle)
            }
        }
    }

    private func show(_ id: String) {
        withMotion(Motion.settle, reduceMotion: reduceMotion) { open = OpenSong(id: id) }
    }

    private func openPending() {
        guard let id = library.pendingOpen else { return }
        library.pendingOpen = nil
        show(id)
    }
}

/// What the add sheet asked for.
enum AddSongChoice: Equatable {
    case file
    case write
    case recording
    /// A pasted chart, already saved.
    case pasted(String)
    case paywall
}

/// "Add a song": the ways a chart comes in, each saying what it takes; past the free limit each asks for Pro instead.
/// Paste uses the system Paste button, so iOS never asks to allow it.
struct AddSongSheet: View {
    let canAdd: Bool
    let pro: Bool
    let choose: (AddSongChoice) -> Void
    @ObservedObject private var library = YourSongsStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !canAdd { limitBanner }
                    option(symbol: "doc.badge.plus", title: "Import a chart", detail: "A ChordPro file, or a text file with the chords over the words.",
                           identifier: "yoursongs.add.file") { choose(canAdd ? .file : .paywall) }
                    pasteOption
                    option(symbol: "square.and.pencil", title: "Write one", detail: "Type the words, then tap a word to put a chord on it.",
                           identifier: "yoursongs.add.write") { choose(canAdd ? .write : .paywall) }
                    option(symbol: "waveform.badge.magnifyingglass", title: "Chords from your recording",
                           detail: "Timbre listens to an audio file of yours, finds the beat and drafts the chords bar by bar.",
                           pro: !pro, identifier: "yoursongs.add.recording") {
                        choose(canAdd && YourSongsPolicy.canDetectChords(pro: pro) ? .recording : .paywall)
                    }
                    Text("Add only charts and recordings you have the right to use. They stay on this iPhone; Timbre never uploads or shares them.")
                        .font(.caption).foregroundStyle(Palette.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.stage)
            .navigationTitle(Text("Add a song"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.stage)
        .preferredColorScheme(.dark)
    }

    private var limitBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            ProBadge()
            Text("The free plan keeps \(YourSongsPolicy.freeChartLimit) songs. Timbre Pro keeps as many as you like.")
                .font(.footnote).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }

    private func option(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, pro: Bool = false, identifier: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Glyph(symbol, size: Glyph.lead)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline).foregroundStyle(Palette.ink)
                        if pro { ProBadge() }
                    }
                    Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var pasteOption: some View {
        if canAdd {
            HStack(alignment: .center, spacing: 14) {
                Glyph("doc.on.clipboard", size: Glyph.lead)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste a chart").font(.headline).foregroundStyle(Palette.ink)
                    Text("Copied from a chord sheet you own, in ChordPro or with chords over the words.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    PasteButton(payloadType: String.self) { strings in
                        let text = strings.joined(separator: "\n")
                        Task { @MainActor in
                            if let song = library.importPasted(text) { choose(.pasted(song.id)) }
                        }
                    }
                    .buttonBorderShape(.capsule)
                    .tint(Palette.mint)
                    .labelStyle(.titleAndIcon)
                    .accessibilityIdentifier("yoursongs.add.paste")
                }
                Spacer(minLength: 0)
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
        } else {
            option(symbol: "doc.on.clipboard", title: "Paste a chart", detail: "Copied from a chord sheet you own.",
                   identifier: "yoursongs.add.paste") { choose(.paywall) }
        }
    }
}

/// Chords from a recording (Pro): Timbre listens through the player's audio file (`RecordingReader`, on the device),
/// then shows what it found (tempo, key, the first bars) to make into a chart, the recording attached and already
/// synced to it. A draft to check by ear, never a transcription.
struct RecordingDraftSheet: View {
    let url: URL
    let name: String
    let made: (UserSong) -> Void
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var library = YourSongsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var progress = 0.0
    @State private var analysis: RecordingAnalysis?
    @State private var finished = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let analysis {
                    result(analysis)
                } else if finished {
                    EmptyState(symbol: "waveform.slash", title: "No steady beat found",
                               message: "Timbre couldn't find a beat and chords in this recording. Try one with the band or a strummed instrument playing in time.")
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    StageSpinner("Listening to your recording…")
                    ProgressView(value: progress).tint(Palette.mint).padding(.horizontal, 40)
                        .accessibilityLabel(Text("Listening"))
                    Text("It stays on this iPhone.").font(.caption).foregroundStyle(Palette.inkFaint)
                    Spacer(minLength: 0)
                }
            }
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.stage)
            .navigationTitle(Text(verbatim: name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationBackground(Palette.stage)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(analysis == nil && !finished)
        .task {
            let found = await RecordingReader.analyze(url, beatsPerBar: 4) { value in
                Task { @MainActor in progress = value }
            }
            analysis = found
            finished = true
            Analytics.log("yoursongs_detect", ["found": found == nil ? "0" : "1"])
        }
        .onDisappear {
            // The working copy goes; a chart made from it has its own copy in the library.
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func result(_ analysis: RecordingAnalysis) -> some View {
        let chords = analysis.bars.prefix(8).map { bar in bar.chords.map { $0.map { NoteNames.glyphs(NoteNames.chordSymbol($0)) } ?? "–" }.joined(separator: " ") }
        return VStack(alignment: .leading, spacing: 18) {
            StatTileRow {
                StatTile(symbol: "metronome", value: Text("\(Int(analysis.bpm.rounded()))"), label: "BPM")
                StatTile(symbol: "music.note", value: Text(verbatim: analysis.key.map { NoteNames.glyphs(NoteNames.chordSymbol($0)) } ?? "–"), label: "Key")
                StatTile(symbol: "square.grid.3x3", value: Text("\(analysis.bars.count)"), label: "Bars")
            }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("The first bars", style: .display)
                ChordFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Array(chords.enumerated()), id: \.offset) { item in
                        Text(verbatim: item.element).font(Typeface.label(15)).foregroundStyle(Palette.mint)
                            .padding(.horizontal, 10).frame(minHeight: 32)
                            .background(Capsule().fill(Palette.mint.opacity(0.12)))
                    }
                }
            }
            Text("A draft from what Timbre heard. Play along and fix any chord that sounds wrong in the editor.")
                .font(.footnote).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { make(analysis) } label: { Text("Make the chart") }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("yoursongs.draft.make")
        }
    }

    private func make(_ analysis: RecordingAnalysis) {
        let source = DraftChart.chordPro(analysis, title: name)
        guard let song = library.add(source: source) else { return }
        let attached = library.attachAudio(from: url, to: song, title: name, timings: DraftChart.timings(analysis), bpm: analysis.bpm)
        dismiss()
        made(attached ?? song)
    }
}
