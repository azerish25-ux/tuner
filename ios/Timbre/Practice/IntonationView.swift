import SwiftUI
import TimbreCore

/// Guided intonation check: for each string, the 12th-fret harmonic and the fretted
/// 12th-fret note should match. The difference tells which way to move the saddle.
struct IntonationView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @State private var course = 0
    @State private var step = Step.harmonic
    @State private var samples: [Double] = []
    @State private var harmonic: [Int: Double] = [:]
    @State private var offsets: [Int: Double] = [:]
    @State private var restoreAutomatic = true

    enum Step { case harmonic, fretted }
    private static let needed = 24

    /// One entry per physical course (pairs share a check).
    private var strings: [Course] {
        var seen = Set<String>()
        return store.courses.filter { seen.insert($0.anchorId ?? "\($0.index)").inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                picker
                instruction
                meter
                if !offsets.isEmpty { results }
                Label("Use fresh strings tuned to pitch. Measure with the instrument in playing position.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
        }
        .background(StageBackground(motes: false))
        .navigationTitle("Intonation")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { audio.running ? store.pauseListening() : store.startListening() } label: {
                Label(audio.running ? "Pause" : "Listen", systemImage: audio.running ? "pause.fill" : "mic.fill")
            }
            .buttonStyle(BrassButtonStyle()).padding(.horizontal, Metrics.gutter).padding(.bottom, 8)
            .accessibilityIdentifier("intonation.listen")
        }
        .onAppear {
            restoreAutomatic = store.automatic
            store.automatic = false
            store.intonationMode = true
            select(strings.first?.index ?? 0)
        }
        .onDisappear {
            store.pauseListening()
            store.intonationMode = false
            store.automatic = restoreAutomatic
        }
        .onChange(of: store.live.reading) { _, reading in capture(reading) }
    }

    private var picker: some View {
        HStack(spacing: 8) {
            ForEach(strings) { string in
                let done = offsets[string.index] != nil
                Button { select(string.index) } label: {
                    VStack(spacing: 1) {
                        Text(NoteReadout.split(store.courseLabel(string)).name).font(Typeface.display(20))
                        Image(systemName: done ? "checkmark" : "circle.dotted").font(.caption2.weight(.bold))
                    }
                    .frame(minWidth: 40)
                }
                .buttonStyle(ChipButtonStyle(selected: string.index == course))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var instruction: some View {
        let label = store.courseLabel(store.activeCourse)
        return HStack(alignment: .top, spacing: 14) {
            IconOrb(symbol: step == .harmonic ? "hand.point.up.left" : "hand.raised.fingers.spread", tint: step == .harmonic ? Palette.flat : Palette.ember)
            VStack(alignment: .leading, spacing: 4) {
                if step == .harmonic {
                    Eyebrow("Step 1 of 2")
                    Text("Play the 12th-fret harmonic on \(label)").font(Typeface.display(26)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Touch the string lightly right above the 12th fret, pluck, and let it ring.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                } else {
                    Eyebrow("Step 2 of 2")
                    Text("Now fret \(label) at the 12th fret").font(Typeface.display(26)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Press just behind the fret with normal pressure and let it ring.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .stillCard()
    }

    private var meter: some View {
        let reading = store.live.reading
        let progress = Double(samples.count) / Double(Self.needed)
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 6)
                Circle().trim(from: 0, to: progress).stroke(Palette.brass, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: audio.running ? "waveform" : "mic.slash").font(.title2).foregroundStyle(audio.running ? Palette.brass : Palette.inkFaint)
                    .symbolEffect(.variableColor.iterative, isActive: audio.running && reading.frequency != nil)
            }
            .frame(width: 74, height: 74)
            .animation(Motion.quick, value: samples.count)
            VStack(alignment: .leading, spacing: 4) {
                Text(reading.frequency.map { String(format: "%.2f Hz", $0) } ?? "—").font(Typeface.number(20)).foregroundStyle(Palette.ink)
                Text(audio.running ? (reading.stable ? String(localized: "Hold it…") : String(localized: "Listening")) : String(localized: "Tap Listen to start"))
                    .font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .stillCard()
        .accessibilityElement(children: .combine)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Results")
            ForEach(strings.filter { offsets[$0.index] != nil }) { string in
                let cents = offsets[string.index] ?? 0
                HStack(spacing: 12) {
                    Text(NoteReadout.split(store.courseLabel(string)).name).font(Typeface.display(24)).foregroundStyle(Palette.ink).frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verdict(cents)).font(.subheadline.weight(.semibold)).foregroundStyle(abs(cents) <= 3 ? Palette.success : Palette.pitch(cents, locked: false))
                        Text(advice(cents)).font(.caption).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Text(String(format: "%+.1f¢", cents)).font(Typeface.number(15)).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .stillCard()
    }

    private func verdict(_ cents: Double) -> String {
        if abs(cents) <= 3 { return String(localized: "Intonation is good") }
        return cents > 0 ? String(localized: "Sharp at the 12th fret") : String(localized: "Flat at the 12th fret")
    }

    private func advice(_ cents: Double) -> String {
        if abs(cents) <= 3 { return String(localized: "Within 3 cents: nothing to change.") }
        return cents > 0 ? String(localized: "Lengthen the string: move its saddle away from the neck.")
                         : String(localized: "Shorten the string: move its saddle toward the neck.")
    }

    private func select(_ index: Int) {
        course = index
        step = .harmonic
        samples = []
        store.chooseCourse(index)
    }

    private func capture(_ reading: TuningReading) {
        guard audio.running, let hz = reading.frequency, reading.stable, let cents = reading.cents, abs(cents) < 60 else {
            if reading.frequency == nil { samples.removeAll() }
            return
        }
        samples.append(hz)
        guard samples.count >= Self.needed else { return }
        let median = samples.sorted()[samples.count / 2]
        samples = []
        Haptics.shared.lock()
        switch step {
        case .harmonic:
            harmonic[course] = median
            withAnimation(Motion.settle) { step = .fretted }
        case .fretted:
            guard let reference = harmonic[course] else { step = .harmonic; return }
            withAnimation(Motion.settle) { offsets[course] = 1200 * log2(median / reference) }
            if let next = strings.first(where: { offsets[$0.index] == nil }) {
                select(next.index)
            } else {
                store.pauseListening()
            }
        }
    }
}
