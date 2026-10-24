import SwiftUI
import TimbreCore

enum ChartDockMode: Hashable { case scroll, recording }

/// The song view's dock: "Auto-scroll" runs the chart at a tempo on its own clock (one bar a chord), and "Your
/// recording" plays the player's own audio file with the chart following it once synced. Syncing is a tap on each
/// chord change while the recording plays. Slowing the recording down (its pitch kept) and looping an A–B part are
/// Timbre Pro. Apple Music never plays here: it has its own card, and nothing is timed to it.
struct ChartDock: View {
    let song: UserSong
    let chart: ChordChart
    let transform: ChartTransform
    @ObservedObject var follower: ChartFollower
    @ObservedObject var player: RecordingPlayer
    @Binding var mode: ChartDockMode
    let pro: Bool
    let addRecording: () -> Void
    let paywall: () -> Void
    let saveTimings: ([Double]) -> Void
    let removeRecording: () -> Void
    @ObservedObject private var library = YourSongsStore.shared
    @State private var loopStart: Double?

    private var recording: SongRecording? { song.recording(.file) }
    private var count: Int { chart.chordSequence.count }
    private var recordingURL: URL? { recording.flatMap { library.audioURL(for: $0) } }

    var body: some View {
        VStack(spacing: 10) {
            SegmentedPill(options: [ChartDockMode.scroll, ChartDockMode.recording], selection: $mode,
                          identifier: { $0 == .scroll ? "yoursongs.dock.scroll" : "yoursongs.dock.recording" }) { option in
                if option == .scroll {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                } else {
                    Label("Your recording", systemImage: "waveform")
                }
            }
            if mode == .scroll { scrollControls } else { recordingControls }
        }
        .onAppear {
            follower.setTempo(chart.tempo ?? 90)
            loadRecording()
        }
        .onChange(of: recording?.reference) { _, _ in loadRecording() }
        .onChange(of: mode) { _, _ in modeChanged() }
        .onChange(of: follower.tap?.isFinished) { _, finished in if finished == true { finishSync() } }
    }

    // MARK: Auto-scroll

    private var scrollControls: some View {
        let running = follower.mode == .scrolling
        return HStack(spacing: 12) {
            Button { toggleScroll() } label: { RoundPlayFace(playing: running) }
                .buttonStyle(PressScaleStyle())
                .disabled(count == 0)
                .accessibilityLabel(running ? Text("Stop scrolling") : Text("Start scrolling"))
                .accessibilityIdentifier("yoursongs.scroll.play")
            HStack(spacing: 2) {
                IconButton(symbol: "minus", size: .compact, label: "Slower") { follower.setTempo(follower.bpm - 4) }
                VStack(spacing: 1) {
                    Text("\(Int(follower.bpm)) BPM").font(Typeface.number(17)).foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("A bar a chord").font(.caption2).foregroundStyle(Palette.inkFaint)
                }
                .frame(minWidth: 84)
                .adjustableValue(Text("Tempo"), value: Text("\(Int(follower.bpm)) BPM"),
                                 increment: { follower.setTempo(follower.bpm + 4) }, decrement: { follower.setTempo(follower.bpm - 4) })
                IconButton(symbol: "plus", size: .compact, label: "Faster") { follower.setTempo(follower.bpm + 4) }
            }
            Spacer(minLength: 0)
            IconButton(symbol: "backward.end.fill", size: .compact, label: "From the top") {
                follower.scroll(count: count, bpm: follower.bpm, beatsPerBar: chart.beatsPerBar, from: 0)
            }
            .disabled(count == 0)
        }
    }

    private func toggleScroll() {
        Haptics.shared.selection()
        if follower.mode == .scrolling {
            follower.stop()
        } else {
            player.pause()
            let from = follower.current ?? 0
            follower.scroll(count: count, bpm: follower.bpm, beatsPerBar: chart.beatsPerBar, from: from < count ? from : 0)
            Analytics.log("yoursongs_autoscroll")
        }
    }

    // MARK: Your recording

    @ViewBuilder private var recordingControls: some View {
        if recordingURL != nil, player.failed {
            VStack(spacing: 8) {
                Text("Timbre can't play this recording.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                Button { addRecording() } label: { Label("Replace recording", systemImage: "waveform.badge.plus") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else if recordingURL != nil, let recording {
            if follower.mode == .syncing { syncPad } else { transport(recording) }
        } else if recording != nil {
            VStack(spacing: 8) {
                Text("This recording's file is missing.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                Button { addRecording() } label: { Label("Choose it again", systemImage: "waveform.badge.plus") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else {
            VStack(spacing: 8) {
                Button { addRecording() } label: { Label("Add your recording", systemImage: "waveform.badge.plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("yoursongs.recording.add")
                Text("An audio file of your own. Timbre plays it, and once you sync it the chart follows along.")
                    .font(.caption).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func transport(_ recording: SongRecording) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                IconButton(symbol: "gobackward.5", size: .compact, label: "Back 5 seconds") { player.skip(by: -5) }
                Button { togglePlay() } label: { RoundPlayFace(playing: player.isPlaying) }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(player.isPlaying ? Text("Pause") : Text("Play"))
                    .accessibilityIdentifier("yoursongs.recording.play")
                IconButton(symbol: "goforward.5", size: .compact, label: "Ahead 5 seconds") { player.skip(by: 5) }
                RecordingScrubber(player: player).padding(.leading, 6)
            }
            EdgeRail(spacing: 8, selection: nil as String?) {
                speedChip
                loopChip
                Button { startSync() } label: {
                    Label(recording.timings.isEmpty ? LocalizedStringKey("Sync") : LocalizedStringKey("Sync again"), systemImage: "hand.tap")
                }
                .buttonStyle(ChipButtonStyle(selected: false))
                .disabled(count == 0)
                .accessibilityIdentifier("yoursongs.sync")
                Menu {
                    Button { addRecording() } label: { Label("Replace recording", systemImage: "arrow.triangle.2.circlepath") }
                    Button(role: .destructive) { removeRecording() } label: { Label("Remove recording", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.button)
                .buttonStyle(ChipButtonStyle(selected: false))
                .accessibilityLabel(Text("More"))
            }
            if recording.timings.isEmpty && count > 0 {
                Text("Tap Sync, then tap along once: from then on the chart follows this recording.")
                    .font(.caption).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Speed (Pro): the recording slowed with its pitch kept.
    @ViewBuilder private var speedChip: some View {
        let percent = Int((player.rate * 100).rounded())
        if pro {
            Menu {
                ForEach([50, 60, 75, 90, 100], id: \.self) { value in
                    Button { player.setRate(Float(value) / 100) } label: { Text(verbatim: "\(value)%") }
                }
            } label: {
                Label { Text("Speed") + Text(verbatim: " \(percent)%") } icon: { Image(systemName: "tortoise") }
            }
            .menuStyle(.button)
            .buttonStyle(ChipButtonStyle(selected: percent < 100))
            .accessibilityIdentifier("yoursongs.speed")
        } else {
            Button { paywall() } label: {
                HStack(spacing: 6) {
                    Label("Slow down", systemImage: "tortoise")
                    ProBadge()
                }
            }
            .buttonStyle(ChipButtonStyle(selected: false))
            .accessibilityIdentifier("yoursongs.speed")
        }
    }

    /// Loop A–B (Pro): a first tap marks A where it is, a second marks B and loops the part, a third lets it go.
    private var loopChip: some View {
        Button { loopTapped() } label: {
            HStack(spacing: 6) {
                Image(systemName: "repeat")
                if let loop = player.loop {
                    Text(verbatim: RecordingScrubber.clock(loop.lowerBound) + "–" + RecordingScrubber.clock(loop.upperBound))
                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                } else if loopStart != nil {
                    Text("Set B")
                } else {
                    Text("Loop A–B")
                }
                if !pro { ProBadge() }
            }
        }
        .buttonStyle(ChipButtonStyle(selected: player.loop != nil || loopStart != nil))
        .accessibilityLabel(player.loop != nil ? Text("Stop looping") : loopStart != nil ? Text("Set the end of the loop") : Text("Loop A–B"))
        .accessibilityIdentifier("yoursongs.loop")
    }

    private func loopTapped() {
        guard pro else { paywall(); return }
        Haptics.shared.selection()
        if player.loop != nil {
            player.setLoop(nil)
            loopStart = nil
            return
        }
        let now = player.currentTime()
        if let start = loopStart {
            if now - start >= 0.5 { player.setLoop(start...now) }
            loopStart = nil
        } else {
            loopStart = now
        }
    }

    private func togglePlay() {
        Haptics.shared.selection()
        if player.isPlaying {
            player.pause()
        } else {
            AppleMusicListener.shared.pause()
            player.play()
            if follower.mode != .recording { follow(recording?.timings ?? []) }
        }
    }

    // MARK: Syncing

    private var syncPad: some View {
        let next = follower.tap?.next ?? 0
        let refs = chart.chordSequence
        let name = refs.indices.contains(next) ? Self.display(refs[next].chord, transform: transform, chart: chart) : ""
        return VStack(spacing: 10) {
            HStack {
                Text("Tap as each chord comes in").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text.fraction(next, count).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 8) {
                IconButton(symbol: "arrow.uturn.backward", size: .compact, label: "Undo") { follower.undoTap() }
                Button {
                    if follower.tapNow() { Haptics.shared.beat(accent: true) }
                } label: {
                    VStack(spacing: 0) {
                        Text("Tap").font(Typeface.label(12))
                        Text(verbatim: name).font(Typeface.display(26)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(Palette.onGold)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.amber))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text("Tap on the change to \(name)"))
                .accessibilityIdentifier("yoursongs.sync.tap")
                Button { finishSync() } label: { Text("Done") }
                    .font(Typeface.button).foregroundStyle(Palette.mint)
                    .tapTarget()
                    .accessibilityIdentifier("yoursongs.sync.done")
            }
        }
    }

    private func startSync() {
        guard count > 0 else { return }
        Haptics.shared.selection()
        AppleMusicListener.shared.pause()
        player.setLoop(nil)
        loopStart = nil
        let player = self.player
        follower.sync(count: count, clock: { player.currentTime() })
        player.play(from: 0)
        Analytics.log("yoursongs_sync_start")
    }

    private func finishSync() {
        guard follower.mode == .syncing else { return }
        let times = follower.tap?.times ?? []
        if !times.isEmpty { saveTimings(times) }
        follower.stop()
        follow(times.isEmpty ? (recording?.timings ?? []) : times)
        Analytics.log("yoursongs_sync_done", ["chords": "\(times.count)", "of": "\(count)"])
    }

    // MARK: Following

    private func loadRecording() {
        guard let url = recordingURL else { return }
        player.load(url)
        player.setSemitones(transform.transpose)
        if mode == .recording, follower.mode != .syncing { follow(recording?.timings ?? []) }
    }

    private func follow(_ times: [Double]) {
        let player = self.player
        follower.follow(times: times, count: count, bpm: recording?.bpm ?? chart.tempo, beatsPerBar: chart.beatsPerBar,
                        clock: { player.currentTime() })
    }

    private func modeChanged() {
        loopStart = nil
        follower.stop()
        if mode == .scroll {
            player.pause()
        } else if recordingURL != nil {
            follow(recording?.timings ?? [])
        }
    }

    static func display(_ chord: String, transform: ChartTransform, chart: ChordChart) -> String {
        NoteNames.glyphs(NoteNames.chordSymbol(transform.shape(chord, in: chart)))
    }
}

/// A round play or pause button face in the accent.
struct RoundPlayFace: View {
    let playing: Bool

    var body: some View {
        Image(systemName: playing ? "pause.fill" : "play.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Palette.onAccent)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 52, height: 52)
            .background(Circle().fill(Palette.mint))
            .shadow(color: Palette.mint.opacity(playing ? 0.5 : 0.25), radius: playing ? 14 : 8)
    }
}

/// Where the recording is, as a bar to drag (with the A–B loop marked on it) and the time played of the whole.
struct RecordingScrubber: View {
    @ObservedObject var player: RecordingPlayer
    @State private var dragging: Double?

    static func clock(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds.rounded(.down))).formatted(.time(pattern: .minuteSecond))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !player.isPlaying || dragging != nil)) { _ in
            let time = dragging ?? player.currentTime()
            VStack(spacing: 2) {
                GeometryReader { proxy in
                    bar(width: proxy.size.width, time: time)
                }
                .frame(height: 24)
                HStack {
                    Text(verbatim: Self.clock(time))
                    Spacer(minLength: 4)
                    Text(verbatim: Self.clock(player.duration))
                }
                .font(Typeface.number(11)).foregroundStyle(Palette.inkFaint)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Position"))
        .accessibilityValue(Text(verbatim: Self.clock(player.currentTime())))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: player.skip(by: 5)
            case .decrement: player.skip(by: -5)
            @unknown default: break
            }
        }
    }

    private func bar(width: CGFloat, time: Double) -> some View {
        let duration = max(0.001, player.duration)
        let share = CGFloat(min(1, max(0, time / duration)))
        return ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
            if let loop = player.loop {
                let start = CGFloat(loop.lowerBound / duration) * width
                let end = CGFloat(loop.upperBound / duration) * width
                Capsule().fill(Palette.amber.opacity(0.45)).frame(width: max(4, end - start), height: 10).offset(x: start)
            }
            Capsule().fill(Palette.mint).frame(width: max(6, width * share), height: 6)
            Circle().fill(Palette.ink).frame(width: 14, height: 14).offset(x: max(0, width * share - 7))
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in dragging = Double(min(1, max(0, value.location.x / max(1, width)))) * duration }
            .onEnded { value in
                player.seek(to: Double(min(1, max(0, value.location.x / max(1, width)))) * duration)
                dragging = nil
            })
    }
}
