import SwiftUI
import TimbreCore

/// On the tuner in Chromatic, for a free player who chose a Pro instrument in onboarding
/// (`AppStore.chromaticStandIn`): one line naming the instrument and where its own stage is (a tap opens
/// the paywall for it), and its open strings as targets. A tap on a string aims the chromatic readout at
/// that note; while listening on automatic, the string being played lights up. Once Pro arrives (from this
/// paywall or any other), the instrument takes the stage.
struct ChromaticStandInHint: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService

    private struct Target: Identifiable {
        let midi: Int
        let name: String
        var id: Int { midi }
    }

    var body: some View {
        if let instrument = store.chromaticStandIn {
            card(instrument)
                .opacity(commerce.isPro ? 0 : 1)
                .onAppear { adopt(instrument) }
                .onChange(of: commerce.isPro) { _, _ in adopt(instrument) }
                .onChange(of: store.selectedTab) { _, _ in adopt(instrument) }
        }
    }

    /// With Pro, the instrument goes on its own stage, but only while the tuner is on screen
    /// (selecting an instrument opens the Tune tab).
    private func adopt(_ instrument: Instrument) {
        guard commerce.isPro, store.referenceMode, store.selectedTab == .tune else { return }
        store.selectInstrument(instrument, photo: store.catalog.photo(instrumentId: instrument.id)?.asset)
    }

    private func card(_ instrument: Instrument) -> some View {
        VStack(spacing: 10) {
            Button { store.presentPaywall("instrument", instrument: instrument) } label: { pitch(instrument) }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("tune.standin")
            strings(targets(instrument))
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 4)
    }

    /// "Tuning your violin in Chromatic · violin stage in Pro", beside the instrument.
    private func pitch(_ instrument: Instrument) -> some View {
        let name = displayName(instrument)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return HStack(spacing: 10) {
            if let image = CourseArtwork.instrumentImage(instrument.id, catalog: store.catalog) {
                InstrumentTile(image: image.name, render: image.render, accent: Palette.amber, size: 32)
            }
            Text("Tuning your \(name) in Chromatic · \(name) stage in Pro")
                .font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            ProBadge()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.inkSoft)
                .accessibilityHidden(true)
        }
        .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 8)
        .background(shape.fill(Palette.stageRaised))
        .overlay(shape.strokeBorder(Color(hex: 0xE39A3B).opacity(0.4), lineWidth: 1))
        .contentShape(shape)
    }

    /// The instrument's open strings as chips; the one the readout is on is lit.
    private func strings(_ targets: [Target]) -> some View {
        HStack(spacing: 8) {
            ForEach(targets) { target in
                let current = store.referenceMidi == target.midi
                Button {
                    store.chooseReferenceNote(target.midi)
                    Haptics.shared.selection()
                } label: {
                    Text(verbatim: target.name).font(Typeface.label(14)).monospacedDigit()
                        .foregroundStyle(current ? Palette.mint : Palette.ink)
                        .frame(minWidth: 44, minHeight: 34)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(current ? Palette.mint.opacity(0.14) : Palette.stageRaised))
                        .overlay(Capsule().strokeBorder(current ? Palette.mint : Palette.line, lineWidth: current ? 1.5 : 1))
                        .animation(Motion.quick, value: current)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(current ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The instrument's default tuning, string by string (doubled courses once), named as the chromatic readout names notes.
    private func targets(_ instrument: Instrument) -> [Target] {
        guard let tuning = store.catalog.tuning(id: instrument.defaultTuningId) else { return [] }
        let settings = store.settings
        var seen = Set<Int>()
        return tuning.courses.sorted { $0.index < $1.index }.compactMap { course in
            guard seen.insert(course.targetMidi).inserted else { return nil }
            let name = PitchMath.noteName(midi: course.targetMidi + settings.transposition - settings.capo, notation: settings.notation)
            return Target(midi: course.targetMidi, name: name)
        }
    }

    /// The name the tuner and the first tune use: the photograph's label, else the catalogue name.
    private func displayName(_ instrument: Instrument) -> String {
        if let photo = store.catalog.photo(instrumentId: instrument.id) {
            return NSLocalizedString("timbre_photo_" + photo.asset, bundle: .main, value: photo.label, comment: "")
        }
        return instrument.name.localized
    }
}
