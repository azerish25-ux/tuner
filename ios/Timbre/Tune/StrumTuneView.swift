import SwiftUI
import TimbreCore
import UIKit

/// Strum to tune: strum every open string once and see them all. Each string has its own lane, neutral steel
/// with a chip naming it (its number and note); colour only says status: the bead where the strum heard it, ↑/↓
/// for the turn it needs and the cents in amber while it is off, ✓ and mint inside the tuner's lock band. The line
/// above names the string furthest out ("Tune A2 up 12¢ first") and one tap takes the tuner to it. When the strum
/// reads every string but one in tune, that last lane zooms into a single-string fine-tune right here, the other
/// lanes shrinking into a row of ✓ (`StrumFinaleLane`). When every string is in tune the tuner takes over for its
/// celebration (the whole instrument, the resolving chord, the share card), and the strings count as tuned.
///
/// Opened from the tuner (`StrumToggle`). While the lanes are up the polyphonic tuner has the microphone's raw
/// frames and the single-string tuner stands aside (`AppStore.beginStrum`); the zoom hands it back.
struct StrumTuneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var model = StrumModel()
    /// The meters have risen into place.
    @State private var appeared = false
    @State private var openedAt = Date()
    /// Every string read in tune: the tuner takes over shortly (`celebration`), crediting the tune with this mean.
    @State private var pendingMean: Double?
    @State private var celebration: Task<Void, Never>?
    /// The last string's lane, zoomed into the single-string fine-tune (its meter id); nil while every lane shows.
    @State private var finale: Int?
    /// The zoomed lane's strings the tuner has locked since it zoomed in.
    @State private var finaleLocked: Set<Int> = []
    /// The zoom waits a beat after the strum lands, so the other strings' ✓ are seen first.
    @State private var zoomTask: Task<Void, Never>?
    /// Off once the player backs out of the zoom: the last string then waits for its "Fine-tune" button.
    @State private var autoZoom = true
    /// Automatic string detection as it was before the zoom chose the string by hand; restored on the way out.
    @State private var wasAutomatic = true
    /// A lane and its zoomed or tuned self share geometry.
    @Namespace private var laneSpace

    var body: some View {
        let band = Palette.tuningBand
        let board = StrumBoard.make(store: store, reading: model.reading, band: band)
        let zoomed = zoomedMeter(board)
        let done = zoomed.map { isDone($0) } ?? false
        let allInTune = board.verdict == .allInTune || done
        ZStack {
            StageBackground(glow: allInTune ? Palette.mint : Palette.spotlight, intensity: allInTune ? 1.3 : 1)
                .animation(Motion.reveal, value: allInTune)
            VStack(spacing: 0) {
                header
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 16) {
                            prompt(board, zoomed: zoomed, done: done)
                            accessibleLanes(board, zoomed: zoomed, done: done, band: band)
                            footer(board, zoomed: zoomed, done: done)
                        }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.vertical, 12)
                    }
                } else {
                    VStack(spacing: 0) {
                        prompt(board, zoomed: zoomed, done: done).padding(.horizontal, Metrics.gutter).padding(.top, 10)
                        stage(board, zoomed: zoomed, done: done, band: band).frame(maxHeight: .infinity).padding(.vertical, 14)
                        footer(board, zoomed: zoomed, done: done).padding(.horizontal, Metrics.gutter).padding(.bottom, 10)
                    }
                    .frame(maxWidth: 680)
                }
            }
        }
        .onAppear {
            openedAt = Date()
            model.start(store: store)
            Analytics.log("strum_open", ["instrument": store.instrument.id, "strings": String(store.courses.count)])
        }
        .task {
            try? await Task.sleep(for: .milliseconds(120))
            appeared = true
        }
        .onDisappear {
            celebration?.cancel()
            zoomTask?.cancel()
            model.stop(store: store)
        }
        .onChange(of: model.readings) { _, _ in landed() }
        .onChange(of: store.strumTargets) { _, _ in retuned() }
        .onChange(of: interrupted) { _, now in if now { close() } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            // The app's one close button, in a column as wide as the listen orb opposite so the title stays centred.
            CloseButton { close() }
                .frame(width: 52, alignment: .leading)
                .accessibilityIdentifier("strum.close")
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Text("Strum to tune").font(Typeface.display(18, relativeTo: .headline)).foregroundStyle(Palette.ink)
                Text("\(store.instrumentDisplayName) · \(store.tuning.name.localized)")
                    .font(.footnote).foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            ListenOrb()
        }
        .padding(.horizontal, Metrics.gutter - 4).padding(.top, 6)
    }

    // MARK: Prompt and summary

    /// The headline names what to do next; the line under it, why.
    private func prompt(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool) -> some View {
        let title = self.headline(board, zoomed: zoomed, done: done)
        let line = self.detail(board, zoomed: zoomed, done: done)
        let allInTune = board.verdict == .allInTune || done
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                if allInTune {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.6), radius: 14)
                        .transition(.adaptive(.scale(scale: 0.3).combined(with: .opacity), reduceMotion: reduceMotion))
                        .accessibilityHidden(true)
                }
                Text(verbatim: title)
                    .font(Typeface.display(26, relativeTo: .title2)).tracking(-0.4)
                    .foregroundStyle(allInTune ? Palette.mint : Palette.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }
            Text(verbatim: line)
                .font(.subheadline)
                .foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .animation(Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion), value: title)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("strum.summary")
    }

    /// Listening, or about to (the microphone takes a moment to start when the screen opens).
    private var listening: Bool {
        audio.running || (!audio.permissionDenied && audio.error == nil && Date().timeIntervalSince(openedAt) < 1.5)
    }

    private func headline(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool) -> String {
        guard listening else {
            return audio.permissionDenied ? String(localized: "Microphone is off") : String(localized: "Tap to listen")
        }
        if let zoomed { return done ? String(localized: "All in tune") : String(localized: "Fine-tune \(zoomed.note)") }
        if model.thin { return String(localized: "Strum them all together") }
        switch board.verdict {
        case .waiting: return model.pending ? String(localized: "Listening…") : String(localized: "Strum all open strings")
        case .allInTune: return String(localized: "All in tune")
        case .tune(let meter): return StrumWords.tuneFirst(meter)
        case .missing: return String(localized: "Strum again")
        }
    }

    private func detail(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool) -> String {
        guard listening else {
            return audio.permissionDenied ? String(localized: "Microphone access is off. Turn it on in Settings to tune.")
                                          : String(localized: "Every string reads from one strum")
        }
        if zoomed != nil {
            return done ? String(localized: "Every string within ±\(Int(Palette.tuningBand))¢")
                        : String(localized: "\(board.inTune) of \(board.meters.count) in tune")
        }
        if model.thin { return String(localized: "Only one string rang. Let every string ring.") }
        switch board.verdict {
        case .waiting:
            return String(localized: "Let them ring. Every string reads at once.")
        case .allInTune:
            return String(localized: "Every string within ±\(Int(Palette.tuningBand))¢")
        case .tune(let meter):
            return StrumWords.turn(meter) + "  ·  " + String(localized: "\(board.inTune) of \(board.meters.count) in tune")
        case .missing(let count):
            return String(localized: "\(count) not heard · the rest are in tune")
        }
    }

    // MARK: Lanes

    private var ring: StrumRing {
        let hint = model.reading == nil && audio.running && !reduceMotion
        return StrumRing(hint: hint, hintStart: model.hintStart, attackAt: model.attackAt, active: hint || model.ringing)
    }

    /// The meter zoomed into the fine-tune, while it is.
    private func zoomedMeter(_ board: StrumBoard) -> StrumBoard.Meter? {
        guard let finale else { return nil }
        return board.meters.first { $0.id == finale }
    }

    /// Every string of the zoomed lane has locked since it zoomed in.
    private func isDone(_ meter: StrumBoard.Meter) -> Bool {
        meter.courses.allSatisfy { finaleLocked.contains($0) }
    }

    /// A lane's key in the zoom: the lane and its zoomed or tuned self share it, so one grows out of the other.
    /// With Reduce Motion none share, and the change is a cross-fade.
    private func laneKey(_ id: Int, zoomed: Bool) -> String {
        reduceMotion ? "lane.\(id).\(zoomed ? "zoomed" : "lane")" : "lane.\(id)"
    }

    private var zoom: Animation {
        Motion.adaptive(Motion.page, reduceMotion: reduceMotion)
    }

    @ViewBuilder private func stage(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool, band: Double) -> some View {
        if let zoomed {
            finaleStage(board, meter: zoomed, done: done, band: band)
        } else {
            meters(board, band: band)
        }
    }

    private func meters(_ board: StrumBoard, band: Double) -> some View {
        let ring = self.ring
        let count = board.meters.count
        return HStack(spacing: 0) {
            ForEach(Array(board.meters.enumerated()), id: \.element.id) { position, meter in
                StrumMeterColumn(meter: meter, position: position, count: count, band: band,
                                 focus: board.focus == meter.id, waiting: board.waiting, ring: ring, pulse: model.readings)
                    .matchedGeometryEffect(id: laneKey(meter.id, zoomed: false), in: laneSpace)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 26)
                    .animation(entrance(position), value: appeared)
            }
        }
        .overlay { if ring.hint { StrumPickSweep(ring: ring) } }
        .padding(.horizontal, 12)
    }

    /// The zoom: the strings already in tune shrink into a row of ✓ chips and the last lane fills the stage.
    private func finaleStage(_ board: StrumBoard, meter: StrumBoard.Meter, done: Bool, band: Double) -> some View {
        let compact = board.meters.count > 7
        return VStack(spacing: 18) {
            HStack(spacing: 4) {
                ForEach(board.meters.filter { $0.id != meter.id }) { other in
                    StrumTunedChip(meter: other, compact: compact)
                        .matchedGeometryEffect(id: laneKey(other.id, zoomed: true), in: laneSpace)
                }
            }
            StrumFinaleLane(meter: meter, band: band, done: done) { course in finaleLock(course) }
                .frame(maxHeight: .infinity)
                .matchedGeometryEffect(id: laneKey(meter.id, zoomed: true), in: laneSpace)
                .accessibilityIdentifier("strum.lastString")
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func entrance(_ position: Int) -> Animation {
        // Under Reduce Motion the lanes only fade in (they don't rise).
        reduceMotion ? Motion.fade : Motion.settle.delay(0.04 * Double(position))
    }

    /// The largest text sizes: rows instead of lanes, the zoomed lane on top of the rest while it is up.
    @ViewBuilder private func accessibleLanes(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool, band: Double) -> some View {
        if let zoomed {
            StrumFinaleLane(meter: zoomed, band: band, done: done) { course in finaleLock(course) }
                .frame(height: 460)
                .accessibilityIdentifier("strum.lastString")
            rows(board.meters.filter { $0.id != zoomed.id }, board: board, band: band)
        } else {
            rows(board.meters, board: board, band: band)
        }
    }

    private func rows(_ meters: [StrumBoard.Meter], board: StrumBoard, band: Double) -> some View {
        VStack(spacing: 10) {
            ForEach(meters) { meter in
                StrumMeterRow(meter: meter, band: band, focus: board.focus == meter.id && finale == nil,
                              waiting: board.waiting, pulse: model.readings)
            }
        }
    }

    // MARK: Footer

    @ViewBuilder private func footer(_ board: StrumBoard, zoomed: StrumBoard.Meter?, done: Bool) -> some View {
        VStack(spacing: 12) {
            if let zoomed, listening {
                zoomedAction(zoomed, done: done)
            } else {
                action(board)
            }
        }
        .frame(minHeight: typeSize.isAccessibilitySize ? nil : 100, alignment: .bottom)
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: board.focus)
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: finale)
    }

    @ViewBuilder private func action(_ board: StrumBoard) -> some View {
        if !listening {
            if audio.permissionDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: { Label("Open Settings", systemImage: "gear") }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button { store.startListening(); Haptics.shared.selection() } label: { Label("Listen", systemImage: "mic.fill") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else {
            switch board.verdict {
            case .tune(let meter):
                // The last string fine-tunes here, zoomed; any other takes the tuner to it.
                Button { if board.lastString?.id == meter.id { zoomIn(meter.id) } else { fineTune(meter) } } label: {
                    Label { Text("Fine-tune \(meter.note)") } icon: { Image(systemName: "tuningfork") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint(Text("Tunes this string on its own"))
                .accessibilityIdentifier("strum.finetune")
                .transition(.adaptive(.opacity.combined(with: .move(edge: .bottom)), reduceMotion: reduceMotion))
            case .allInTune:
                Button { close() } label: { Text("Done") }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("strum.done")
            case .missing:
                Text("Turn a peg, then strum again")
                    .font(.footnote)
                    .foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            case .waiting:
                EmptyView()
            }
        }
    }

    /// While zoomed: hear the string's target, or go back to every lane; once it locks, Done.
    @ViewBuilder private func zoomedAction(_ meter: StrumBoard.Meter, done: Bool) -> some View {
        if done {
            Button { close() } label: { Text("Done") }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("strum.done")
        } else {
            HStack(spacing: 12) {
                StageControl(symbol: audio.tonePlaying ? "speaker.slash.fill" : "speaker.wave.2.fill", active: audio.tonePlaying) {
                    store.toggleTone()
                }
                .accessibilityLabel(Text(audio.tonePlaying ? "Stop reference tone" : "Play reference tone"))
                .accessibilityIdentifier("strum.tone")
                Button { zoomOut() } label: {
                    Label("Strum again", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityHint(Text("Shows every string again"))
                .accessibilityIdentifier("strum.again")
            }
            .transition(.adaptive(.opacity.combined(with: .move(edge: .bottom)), reduceMotion: reduceMotion))
        }
    }

    // MARK: Actions

    /// Leaving for the tuner (the tab, the paywall, settings or the picker took over; the instrument changed to one a strum can't read).
    private var interrupted: Bool {
        store.selectedTab != .tune || store.showPaywall || store.showSettings || store.showInstrumentPicker || !store.canStrumTune
    }

    /// A strum was read: one VoiceOver announcement for all of it, a tap of haptics, the last string's zoom a beat
    /// later when only one is off, and on every string in tune the tuner's celebration a moment later.
    private func landed() {
        let board = StrumBoard.make(store: store, reading: model.reading, band: Palette.tuningBand)
        celebration?.cancel(); celebration = nil; pendingMean = nil
        zoomTask?.cancel(); zoomTask = nil
        UIAccessibility.post(notification: .announcement, argument: StrumWords.spoken(board))
        guard board.verdict == .allInTune else {
            Haptics.shared.selection()
            if autoZoom, let last = board.lastString { scheduleZoom(last.id) }
            return
        }
        guard !store.allCoursesLocked else {
            // Already tuned string by string this session: the chord again, nothing new to credit.
            Haptics.shared.done()
            SoundFX.shared.play(.tuned)
            return
        }
        Haptics.shared.lock()
        celebrate(mean: board.meanCents, delay: voiceOver ? 2.4 : 1.3)
    }

    /// The strings lock and the tuner celebrates (its chord, the whole instrument, the share card) after `delay`,
    /// crediting the tune with `mean`. Crediting twice is harmless: a second call finds every string already locked.
    private func celebrate(mean: Double, delay: Double) {
        pendingMean = mean
        let app = self.store
        let screen = self.model
        let leave = self.dismiss
        let restore: Bool? = finale != nil ? wasAutomatic : nil
        celebration = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            if let restore { app.automatic = restore }
            app.completeStrumTune(meanCents: mean)
            screen.stop(store: app)
            leave()
        }
    }

    private func scheduleZoom(_ id: Int) {
        let delay = voiceOver ? 2.2 : 1.1
        zoomTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            zoomIn(id)
        }
    }

    /// The last string's lane zooms into the fine-tune: the strum hands the microphone back to the single-string
    /// tuner, set by hand on that string so automatic detection can't move it.
    private func zoomIn(_ id: Int) {
        zoomTask?.cancel(); zoomTask = nil
        guard finale == nil, listening else { return }
        let board = StrumBoard.make(store: store, reading: model.reading, band: Palette.tuningBand)
        guard let meter = board.meters.first(where: { $0.id == id }) else { return }
        celebration?.cancel(); celebration = nil; pendingMean = nil
        wasAutomatic = store.automatic
        model.stop(store: store)
        store.chooseCourse(meter.id)
        finaleLocked = []
        withAnimation(zoom) { finale = id }
        UIAccessibility.post(notification: .announcement, argument: StrumWords.zoomed(board, meter: meter))
        Analytics.log("strum_last_string", ["instrument": store.instrument.id, "strings": String(store.courses.count)])
    }

    /// Back to every lane: the strum listens again and the last string waits for its "Fine-tune" button.
    private func zoomOut() {
        guard finale != nil else { return }
        autoZoom = false
        if audio.tonePlaying { audio.stopTone() }
        store.automatic = wasAutomatic
        finaleLocked = []
        withAnimation(zoom) { finale = nil }
        model.start(store: store)
        Haptics.shared.selection()
    }

    /// The tuner locked a string of the zoomed lane. A pair moves on to its other string once the bell has rung
    /// (the tuner's own pair step may get there first); the lane's last string completes the instrument.
    private func finaleLock(_ course: Int) {
        guard let id = finale, pendingMean == nil else { return }
        let board = StrumBoard.make(store: store, reading: model.reading, band: Palette.tuningBand)
        guard let meter = board.meters.first(where: { $0.id == id }), meter.courses.contains(course) else { return }
        var locked = finaleLocked
        locked.insert(course)
        finaleLocked = locked
        if let next = meter.courses.first(where: { !locked.contains($0) }) {
            let app = self.store
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                guard app.selectedCourse == course else { return }
                app.chooseCourse(next)
            }
            return
        }
        if audio.tonePlaying { audio.stopTone() }
        UIAccessibility.post(notification: .announcement, argument: String(localized: "All strings in tune"))
        // The mean over every string: the others as the strum read them, this one as it locked.
        let others = board.meters.filter { $0.id != id }.compactMap(\.cents).map { abs($0) }
        let mean = (others.reduce(0, +) + abs(store.live.reading.cents ?? 0)) / Double(others.count + 1)
        celebrate(mean: mean, delay: voiceOver ? 2.4 : 1.0)
    }

    /// The strings changed under the screen (a tuning, reference pitch or temperament): every lane again.
    private func retuned() {
        model.retune(store: store)
        guard finale != nil else { return }
        celebration?.cancel(); celebration = nil; pendingMean = nil
        store.automatic = wasAutomatic
        finaleLocked = []
        finale = nil
        model.start(store: store)
    }

    /// Back to the tuner on the string to tune first, chosen by hand so automatic detection doesn't move it.
    private func fineTune(_ meter: StrumBoard.Meter) {
        celebration?.cancel(); celebration = nil; pendingMean = nil
        zoomTask?.cancel(); zoomTask = nil
        let locked = store.lockedCourses
        let index = meter.courses.first { !locked.contains($0) } ?? meter.id
        model.stop(store: store)
        store.chooseCourse(index)
        dismiss()
    }

    private func close() {
        celebration?.cancel(); celebration = nil
        zoomTask?.cancel(); zoomTask = nil
        if finale != nil {
            // The tuner stays on the string being fine-tuned, its detection as it was.
            if audio.tonePlaying { audio.stopTone() }
            store.automatic = wasAutomatic
        }
        if let mean = pendingMean {
            pendingMean = nil
            store.completeStrumTune(meanCents: mean)
        }
        model.stop(store: store)
        dismiss()
    }
}

// MARK: - The tuner's toggle

/// The tuner's way into Strum to tune, at the top of the stage's controls: a round control with strings and a
/// strum across them, "Strum" beneath. Only for instruments a strum can read (`AppStore.canStrumTune`): stringed,
/// 3 to 12 strings, one the player may tune, never in Chromatic.
struct StrumToggle: View {
    let action: () -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if store.canStrumTune {
            Button {
                Haptics.shared.selection()
                action()
            } label: {
                VStack(spacing: 3) {
                    StrumGlyph()
                        .frame(width: 22, height: 22)
                        .frame(width: 44, height: 44)
                        .stageControlDisc()
                    StageCaption(text: Text("Strum"))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(Text("Strum to tune"))
            .accessibilityHint(Text("Strum every open string once to read them all"))
            .accessibilityIdentifier("tune.strum")
        }
    }
}

/// Four strings and a strum sweeping across them.
private struct StrumGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            for i in 0..<4 {
                let x = w * (0.17 + 0.22 * CGFloat(i))
                var string = Path()
                string.move(to: CGPoint(x: x, y: h * 0.06))
                string.addLine(to: CGPoint(x: x, y: h * 0.94))
                context.stroke(string, with: .color(Palette.ink.opacity(0.9)), lineWidth: 1.7 - 0.25 * CGFloat(i))
            }
            var sweep = Path()
            sweep.move(to: CGPoint(x: w * 0.02, y: h * 0.74))
            sweep.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.36), control: CGPoint(x: w * 0.5, y: h * 0.78))
            context.stroke(sweep, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            var head = Path()
            head.move(to: CGPoint(x: w * 0.7, y: h * 0.34))
            head.addLine(to: CGPoint(x: w * 0.92, y: h * 0.34))
            head.addLine(to: CGPoint(x: w * 0.86, y: h * 0.55))
            context.stroke(head, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
