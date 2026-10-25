import SwiftUI
import TimbreCore
import UniformTypeIdentifiers

/// A song the player brought, full screen: its sleeve and details, the key and capo to play it in (with the easiest
/// capo suggested on guitar), its chords as boxes for the player's instrument (a tap sounds one), "Listen on Apple
/// Music", and the chart as a song sheet that lights and scrolls to the chord sounding: at a tempo (auto-scroll) or
/// along the player's own recording once synced (the dock). "Practice" drills its chords with the lessons' steps.
struct ChartSongView: View {
    let songId: String
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var library = YourSongsStore.shared
    @StateObject private var follower = ChartFollower()
    @StateObject private var player = RecordingPlayer()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("yoursongs.textScale") private var textScale = 1.0
    @State private var dockMode = ChartDockMode.scroll
    @State private var editing = false
    @State private var practicing = false
    @State private var confirmDelete = false
    @State private var importingRecording = false
    @State private var userScrolling = false
    @State private var shownLine: Int?
    /// The chord in the strip sounding now.
    @State private var sounding: String?
    @State private var soundingTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let song = library.song(id: songId) {
                page(song)
            } else {
                // Deleted (here or from the shelf): nothing left to show.
                Palette.stage.ignoresSafeArea().onAppear { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func page(_ song: UserSong) -> some View {
        let chart = library.chart(for: song)
        let transform = song.transform
        let instrument = ChartInstrument(store)
        return ZStack {
            StageBackground(glow: Palette.mint, intensity: 0.45, motes: false)
            VStack(spacing: 0) {
                topBar(song, chart: chart, transform: transform, instrument: instrument)
                songSheet(song, chart: chart, transform: transform, instrument: instrument)
            }
        }
        .fullScreenCover(isPresented: $practicing) {
            ChartPracticeView(title: library.title(of: song), steps: instrument.steps(for: chart, transform: transform), course: instrument.course)
                .environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce)
        }
        .sheet(isPresented: $editing) {
            ChartEditorView(source: song.source, isNew: false) { source in
                var changed = song
                changed.source = source
                library.update(changed)
            }
        }
        .fileImporter(isPresented: $importingRecording, allowedContentTypes: [.audio]) { result in
            guard case let .success(url) = result else { return }
            if library.attachAudio(from: url, to: song) != nil {
                withMotion(Motion.settle, reduceMotion: reduceMotion) { dockMode = .recording }
            }
        }
        .confirmationDialog("Delete this song?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                follower.stop()
                player.stop()
                library.delete(song)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The chart and the recording you added go from this iPhone.")
        }
        .alert("Timbre", isPresented: Binding(get: { library.problem != nil }, set: { if !$0 { library.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: library.problem ?? "")
        }
        .paywallSheet()
        .onAppear {
            var opened = song
            opened.lastOpened = Date()
            library.remember(opened)
            if song.recording(.file) != nil { dockMode = .recording }
            Analytics.log("yoursongs_open", ["synced": song.recording(.file)?.timings.isEmpty == false ? "1" : "0"])
        }
        .onDisappear {
            // Covered by Practice, or closed: the recording keeps its place (Close stops it for good).
            soundingTask?.cancel()
            follower.stop()
            player.pause()
        }
        .onChange(of: song.transpose) { _, value in player.setSemitones(value) }
    }

    // MARK: Top bar

    private func topBar(_ song: UserSong, chart: ChordChart, transform: ChartTransform, instrument: ChartInstrument) -> some View {
        let canPractice = !ChartPractice.drill(chart, transform: transform).isEmpty
        return HStack(spacing: 8) {
            CloseButton(label: "Close") { close() }
                .accessibilityIdentifier("yoursongs.song.close")
            Spacer(minLength: 4)
            Button {
                follower.stop()
                player.pause()
                AppleMusicListener.shared.pause()
                practicing = true
            } label: {
                Label("Practice", systemImage: "guitars")
                    .font(Typeface.label(.body)).foregroundStyle(canPractice ? Palette.onAccent : Palette.inkFaint)
                    .padding(.horizontal, 14).frame(minHeight: 36)
                    .background(Capsule().fill(canPractice ? Palette.mint : Palette.surface))
                    .tapTarget()
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!canPractice)
            .accessibilityIdentifier("yoursongs.practice")
            Menu {
                Button { editing = true } label: { Label("Edit chart", systemImage: "square.and.pencil") }
                Picker(selection: $textScale) {
                    Text("Small").tag(0.85)
                    Text("Default").tag(1.0)
                    Text("Large").tag(1.2)
                    Text("Largest").tag(1.45)
                } label: {
                    Label("Text size", systemImage: "textformat.size")
                }
                Divider()
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete song", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                    .tapTarget()
            }
            .accessibilityLabel(Text("More"))
            .accessibilityIdentifier("yoursongs.song.more")
        }
        .padding(.leading, 8).padding(.trailing, Metrics.gutter).padding(.top, 4).padding(.bottom, 4)
    }

    // MARK: The page

    private func songSheet(_ song: UserSong, chart: ChordChart, transform: ChartTransform, instrument: ChartInstrument) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(song, chart: chart, transform: transform)
                    keyCard(song, chart: chart, transform: transform, instrument: instrument)
                    if !chart.uniqueChords.isEmpty {
                        chordStrip(chart, transform: transform, instrument: instrument)
                    }
                    AppleMusicCard(song: song, chartTitle: chart.title, chartArtist: chart.artist)
                    ChartSheetView(chart: chart, transform: transform, current: follower.current, syncing: follower.mode == .syncing,
                                   textScale: CGFloat(textScale))
                        .padding(.top, 4)
                    if chart.sections.isEmpty {
                        EmptyState(symbol: "music.note.list", title: "This chart is empty", message: "Edit it to add the words and chords.")
                    }
                    Text("Your charts and recordings stay on this iPhone.")
                        .font(.caption2).foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity).padding(.top, 12)
                }
                .padding(.horizontal, Metrics.gutter).padding(.top, 8).padding(.bottom, 24)
            }
            .onScrollPhaseChange { _, phase in
                userScrolling = phase == .interacting || phase == .decelerating
            }
            .stageDock {
                ChartDock(song: song, chart: chart, transform: transform, follower: follower, player: player, mode: $dockMode,
                          pro: store.isPro, addRecording: { importingRecording = true },
                          paywall: { store.presentPaywall("your_songs_practice") },
                          saveTimings: { times in saveTimings(times, for: song) },
                          removeRecording: {
                              player.stop()
                              follower.stop()
                              library.removeRecording(.file, from: song)
                          })
            }
            .onChange(of: follower.current) { _, index in
                reveal(index, in: chart, proxy: proxy)
            }
        }
    }

    /// Leaves the song: the recording and Apple Music stop, and the audio session goes back to other apps.
    private func close() {
        follower.stop()
        player.stop()
        AppleMusicListener.shared.pause()
        dismiss()
    }

    /// Scrolls the line with chord `index` to the upper part of the screen, unless the player is scrolling themselves.
    private func reveal(_ index: Int?, in chart: ChordChart, proxy: ScrollViewProxy) {
        guard let index, !userScrolling else { return }
        let refs = chart.chordSequence
        guard refs.indices.contains(index) else { return }
        let line = ChartSheetView.lineID(of: refs[index])
        guard line != shownLine else { return }
        shownLine = line
        withAnimation(reduceMotion ? Motion.reduced : .easeInOut(duration: 0.55)) {
            proxy.scrollTo(line, anchor: UnitPoint(x: 0.5, y: 0.28))
        }
    }

    private func saveTimings(_ times: [Double], for song: UserSong) {
        guard var recording = song.recording(.file) else { return }
        var changed = song
        recording.timings = times
        changed.attach(recording)
        library.remember(changed)
    }

    // MARK: Header

    private func header(_ song: UserSong, chart: ChordChart, transform: ChartTransform) -> some View {
        let title = library.title(of: song)
        let number = (library.songs.firstIndex { $0.id == song.id } ?? 0) + 1
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                SongCover(art: YourSongsShelf.art(for: song, title: title, artist: chart.artist, number: number), corner: 10)
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Your song", style: .display)
                    Text(verbatim: title).font(Typeface.display(28)).tracking(-0.5).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let artist = chart.artist {
                        Text(verbatim: artist).font(.subheadline).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            facts(chart, transform: transform)
        }
    }

    /// The key, tempo, meter and chord count as one line of words ("Key G · 96 BPM · 4/4 · 5 chords"), not a row of
    /// pills.
    private func facts(_ chart: ChordChart, transform: ChartTransform) -> some View {
        var parts: [Text] = []
        if let key = transform.soundingKey(of: chart) { parts.append(Text("Key \(Self.keyName(key))")) }
        if let tempo = chart.tempo { parts.append(Text("\(Int(tempo.rounded())) BPM")) }
        if let meter = chart.meter { parts.append(Text(verbatim: meter.text)) }
        parts.append(Text("\(chart.uniqueChords.count) chords"))
        let line = parts.dropFirst().reduce(parts[0]) { (line: Text, part: Text) -> Text in line + Text(verbatim: " · ") + part }
        return line.font(.subheadline).foregroundStyle(Palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    static func keyName(_ key: (tonic: Int, minor: Bool)) -> String {
        NoteNames.glyphs(NoteNames.chordSymbol(ChordSpelling.keyName(tonic: key.tonic, minor: key.minor)))
    }

    // MARK: Key and capo

    private func keyCard(_ song: UserSong, chart: ChordChart, transform: ChartTransform, instrument: ChartInstrument) -> some View {
        let sounding = transform.soundingKey(of: chart).map(Self.keyName)
        let shapes = transform.shapeKey(of: chart).map(Self.keyName)
        let tip = instrument.isGuitar ? capoTip(chart, transform: transform) : nil
        return VStack(alignment: .leading, spacing: 10) {
            stepperRow(title: Text("Key"),
                       value: Text(verbatim: sounding ?? "–"),
                       detail: song.transpose == 0 ? Text("As written") : Text(verbatim: (song.transpose > 0 ? "+" : "−") + "\(abs(song.transpose))"),
                       minus: { change(song) { $0.transpose = max(-11, $0.transpose - 1) } },
                       plus: { change(song) { $0.transpose = min(11, $0.transpose + 1) } },
                       identifier: "yoursongs.key")
            Hairline()
            stepperRow(title: Text("Capo"),
                       value: transform.capo == 0 ? Text("None") : Text(verbatim: "\(transform.capo)"),
                       detail: transform.capo > 0 ? shapes.map { Text("\($0) shapes") } : nil,
                       minus: { change(song) { $0.capo = max(0, transform.capo - 1) } },
                       plus: { change(song) { $0.capo = min(9, transform.capo + 1) } },
                       identifier: "yoursongs.capo")
            if let tip {
                Button { change(song) { $0.capo = tip } } label: {
                    Label("Easiest with capo \(tip)", systemImage: "lightbulb")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(TextLinkStyle())
                .accessibilityIdentifier("yoursongs.capoTip")
            }
            if song.transpose != 0 && song.recording(.file) != nil {
                Text("Your recording plays in the new key too.").font(.caption).foregroundStyle(Palette.inkFaint)
            }
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }

    private func stepperRow(title: Text, value: Text, detail: Text?, minus: @escaping () -> Void, plus: @escaping () -> Void,
                            identifier: String) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                title.font(.subheadline).foregroundStyle(Palette.inkSoft)
                if let detail { detail.font(.caption).foregroundStyle(Palette.inkFaint) }
            }
            Spacer(minLength: 8)
            IconButton(symbol: "minus", size: .compact, label: "Down") { minus() }
            value.font(Typeface.number(20)).foregroundStyle(Palette.ink)
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            IconButton(symbol: "plus", size: .compact, label: "Up") { plus() }
        }
        .adjustableValue(title, value: value, increment: plus, decrement: minus)
        .accessibilityIdentifier(identifier)
    }

    /// A capo that makes the chart easier on guitar (fewer barre chords), when there is one.
    private func capoTip(_ chart: ChordChart, transform: ChartTransform) -> Int? {
        let sounding = chart.chordSequence.compactMap { ChordSymbol($0.chord)?.transposed(by: transform.soundingShift, names: ChordSpelling.sharpNames) }
        return CapoAdvisor.easiest(sounding: sounding, current: transform.capo)
    }

    private func change(_ song: UserSong, _ edit: (inout UserSong) -> Void) {
        var changed = song
        edit(&changed)
        guard changed != song else { return }
        Haptics.shared.selection()
        withMotion(Motion.quick, reduceMotion: reduceMotion) { library.remember(changed) }
    }

    // MARK: Chords

    private func chordStrip(_ chart: ChordChart, transform: ChartTransform, instrument: ChartInstrument) -> some View {
        let shapes = ChartPractice.drill(chart, transform: transform, limit: 24)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Chords", style: .display)
                Spacer(minLength: 8)
                Text("Tap one to hear it").font(.caption).foregroundStyle(Palette.inkFaint)
            }
            EdgeRail(spacing: 10, selection: nil as String?) {
                ForEach(shapes, id: \.text) { shape in
                    chordCard(shape, instrument: instrument)
                }
            }
        }
    }

    @ViewBuilder private func chordCard(_ shape: ChordSymbol, instrument: ChartInstrument) -> some View {
        let name = NoteNames.glyphs(NoteNames.chordSymbol(shape.text))
        let lit = sounding == shape.text
        if let spec = instrument.spec(shape) {
            Button { audition(spec, name: shape.text, instrument: instrument) } label: {
                VStack(spacing: 6) {
                    MiniChordGlyph(chord: spec, accent: Palette.mint, lit: lit)
                        .frame(width: 48, height: 58)
                    Text(verbatim: name).font(Typeface.label(.body)).foregroundStyle(lit ? Palette.mint : Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: 64)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
                    .strokeBorder(lit ? Palette.mint.opacity(0.6) : Palette.hairline, lineWidth: 1))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(Text("\(name) chord"))
            .accessibilityValue(Text(verbatim: ChordWords.shape(spec)))
            .accessibilityHint(Text("Plays the chord"))
        } else {
            Text(verbatim: name).font(Typeface.label(.body)).foregroundStyle(Palette.inkSoft)
                .frame(width: 64, height: 92)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
        }
    }

    /// Strums the shape (low string to high) in the instrument's voice; the recording pauses so the two don't clash.
    private func audition(_ spec: ChordSpec, name: String, instrument: ChartInstrument) {
        player.pause()
        let reference = store.settings.referencePitchHz
        let notes = instrument.notes(spec).map { PitchMath.frequency(midi: Double($0), reference: reference) }
        guard !notes.isEmpty else { return }
        store.audio.playTones(notes, together: false, noteMs: 1100, gapMs: 30, voice: InstrumentVoice(instrumentId: instrument.id))
        Haptics.shared.selection()
        withAnimation(Motion.quick) { sounding = name }
        soundingTask?.cancel()
        soundingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.settle) { sounding = nil }
        }
    }
}
