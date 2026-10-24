import SwiftUI
import TimbreCore
import UIKit

/// Strum to tune: strum every open string once and see them all. Each string has its own meter in its string
/// colour (the bead where the strum heard it, ↑/↓ for the turn it needs, ✓ inside the tuner's lock band); the line
/// above names the string furthest out ("Tune A2 up 12¢ first") and one tap takes the tuner to it. When every
/// string reads in tune the tuner takes over for its celebration (the whole instrument, the resolving chord, the
/// share card), and the strings count as tuned.
///
/// Opened from the tuner (`StrumToggle`). While it is up the polyphonic tuner has the microphone's raw frames and
/// the single-string tuner stands aside (`AppStore.beginStrum`).
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

    var body: some View {
        let band = Palette.tuningBand
        let board = StrumBoard.make(store: store, reading: model.reading, band: band)
        let allInTune = board.verdict == .allInTune
        ZStack {
            StageBackground(glow: allInTune ? Palette.mint : Color(hex: 0xFFC48C), intensity: allInTune ? 1.3 : 1)
                .animation(.easeInOut(duration: 0.6), value: allInTune)
            VStack(spacing: 0) {
                header
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 16) {
                            prompt(board)
                            rows(board, band: band)
                            footer(board)
                        }
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.vertical, 12)
                    }
                } else {
                    VStack(spacing: 0) {
                        prompt(board).padding(.horizontal, Metrics.gutter).padding(.top, 10)
                        meters(board, band: band).frame(maxHeight: .infinity).padding(.vertical, 14)
                        footer(board).padding(.horizontal, Metrics.gutter).padding(.bottom, 10)
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
            model.stop(store: store)
        }
        .onChange(of: model.readings) { _, _ in landed() }
        .onChange(of: store.strumTargets) { _, _ in model.retune(store: store) }
        .onChange(of: interrupted) { _, now in if now { close() } }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { close() } label: {
                Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(Text("Close"))
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
    private func prompt(_ board: StrumBoard) -> some View {
        let title = self.headline(board)
        let line = self.detail(board)
        let allInTune = board.verdict == .allInTune
        return VStack(spacing: 6) {
            HStack(spacing: 10) {
                if allInTune {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Palette.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.6), radius: 14)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
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
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.pluck, value: title)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("strum.summary")
    }

    /// Listening, or about to (the microphone takes a moment to start when the screen opens).
    private var listening: Bool {
        audio.running || (!audio.permissionDenied && audio.error == nil && Date().timeIntervalSince(openedAt) < 1.5)
    }

    private func headline(_ board: StrumBoard) -> String {
        guard listening else {
            return audio.permissionDenied ? String(localized: "Microphone is off") : String(localized: "Tap to listen")
        }
        if model.thin { return String(localized: "Strum them all together") }
        switch board.verdict {
        case .waiting: return model.pending ? String(localized: "Listening…") : String(localized: "Strum all open strings")
        case .allInTune: return String(localized: "All in tune")
        case .tune(let meter): return StrumWords.tuneFirst(meter)
        case .missing: return String(localized: "Strum again")
        }
    }

    private func detail(_ board: StrumBoard) -> String {
        guard listening else {
            return audio.permissionDenied ? String(localized: "Microphone access is off. Turn it on in Settings to tune.")
                                          : String(localized: "Every string reads from one strum")
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

    // MARK: Meters

    private var ring: StrumRing {
        let hint = model.reading == nil && audio.running && !reduceMotion
        return StrumRing(hint: hint, hintStart: model.hintStart, attackAt: model.attackAt, active: hint || model.ringing)
    }

    private func meters(_ board: StrumBoard, band: Double) -> some View {
        let ring = self.ring
        let count = board.meters.count
        return HStack(spacing: 0) {
            ForEach(Array(board.meters.enumerated()), id: \.element.id) { position, meter in
                StrumMeterColumn(meter: meter, position: position, count: count, band: band,
                                 focus: board.focus == meter.id, waiting: board.waiting, ring: ring, pulse: model.readings)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 26)
                    .animation(entrance(position), value: appeared)
            }
        }
        .overlay { if ring.hint { StrumPickSweep(ring: ring) } }
        .padding(.horizontal, 12)
    }

    private func entrance(_ position: Int) -> Animation {
        reduceMotion ? .easeOut(duration: 0.25) : Motion.settle.delay(0.04 * Double(position))
    }

    private func rows(_ board: StrumBoard, band: Double) -> some View {
        VStack(spacing: 10) {
            ForEach(board.meters) { meter in
                StrumMeterRow(meter: meter, band: band, focus: board.focus == meter.id, waiting: board.waiting, pulse: model.readings)
            }
        }
    }

    // MARK: Footer

    @ViewBuilder private func footer(_ board: StrumBoard) -> some View {
        VStack(spacing: 12) {
            if board.hasApproximate { approximateNote }
            action(board)
        }
        .frame(minHeight: typeSize.isAccessibilitySize ? nil : 100, alignment: .bottom)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.settle, value: board.focus)
    }

    @ViewBuilder private func action(_ board: StrumBoard) -> some View {
        if !listening {
            if audio.permissionDenied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: { Label("Open Settings", systemImage: "gear") }
                .buttonStyle(BrassButtonStyle())
            } else {
                Button { store.startListening(); Haptics.shared.selection() } label: { Label("Listen", systemImage: "mic.fill") }
                    .buttonStyle(BrassButtonStyle())
            }
        } else {
            switch board.verdict {
            case .tune(let meter):
                Button { fineTune(meter) } label: {
                    Label { Text("Fine-tune \(meter.note)") } icon: { Image(systemName: "tuningfork") }
                }
                .buttonStyle(BrassButtonStyle())
                .accessibilityHint(Text("Tunes this string on its own"))
                .accessibilityIdentifier("strum.finetune")
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .allInTune:
                Button { close() } label: { Text("Done") }
                    .buttonStyle(BrassButtonStyle(prominent: false))
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

    /// Hollow beads: their strings share a peak with another string's overtone (B3 under the low E's third harmonic).
    private var approximateNote: some View {
        HStack(spacing: 8) {
            Circle().strokeBorder(Palette.inkSoft, lineWidth: 2).frame(width: 12, height: 12).accessibilityHidden(true)
            Text("Hollow: approximate. Fine-tune it alone to be sure.")
                .font(.caption)
                .foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    /// Leaving for the tuner (the tab, the paywall, settings or the picker took over; the instrument changed to one a strum can't read).
    private var interrupted: Bool {
        store.selectedTab != .tune || store.showPaywall || store.showSettings || store.showInstrumentPicker || !store.canStrumTune
    }

    /// A strum was read: one VoiceOver announcement for all of it, a tap of haptics, and on every string in tune
    /// the tuner's celebration a moment later.
    private func landed() {
        let board = StrumBoard.make(store: store, reading: model.reading, band: Palette.tuningBand)
        celebration?.cancel(); celebration = nil; pendingMean = nil
        UIAccessibility.post(notification: .announcement, argument: StrumWords.spoken(board))
        guard board.verdict == .allInTune else { Haptics.shared.selection(); return }
        guard !store.allCoursesLocked else {
            // Already tuned string by string this session: the chord again, nothing new to credit.
            Haptics.shared.done()
            SoundFX.shared.play(.tuned)
            return
        }
        Haptics.shared.lock()
        let mean = board.meanCents
        pendingMean = mean
        let app = self.store
        let screen = self.model
        let leave = self.dismiss
        let delay = voiceOver ? 2.4 : 1.3
        celebration = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            // The strings lock and the tuner celebrates (its chord, the whole instrument, the share card). Crediting
            // twice is harmless: a second call finds every string already locked.
            app.completeStrumTune(meanCents: mean)
            screen.stop(store: app)
            leave()
        }
    }

    /// Back to the tuner on the string to tune first, chosen by hand so automatic detection doesn't move it.
    private func fineTune(_ meter: StrumBoard.Meter) {
        celebration?.cancel(); celebration = nil; pendingMean = nil
        let locked = store.lockedCourses
        let index = meter.courses.first { !locked.contains($0) } ?? meter.id
        model.stop(store: store)
        store.chooseCourse(index)
        dismiss()
    }

    private func close() {
        celebration?.cancel(); celebration = nil
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
                        .background(Circle().fill(.white.opacity(0.05)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    Text("Strum")
                        .font(Typeface.label(10, relativeTo: .caption2))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                        .fixedSize()
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
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
