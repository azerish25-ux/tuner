import SwiftUI
import TimbreCore

/// Gallery of every instrument, grouped by family, rendered in the studio.
struct InstrumentsView: View {
    var picker = false
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var family: String?

    private var photos: [InstrumentPhoto] {
        store.catalog.photos.filter { photo in
            guard let instrument = store.catalog.instrument(id: photo.instrumentId) else { return false }
            let text = [photo.label, name(photo), instrument.name.localized, instrument.familyId].joined(separator: " ")
            return (family == nil || family == instrument.familyId) && (query.isEmpty || text.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: []) {
                if picker { currentTunings } else { ScreenTitle(title: "Instruments", subtitle: "Sixty instruments, each with its own tuning mechanism.") }
                search
                filters
                if query.isEmpty && family == nil {
                    chromaticCard
                    if !recents.isEmpty {
                        Eyebrow("Your instruments")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) { ForEach(recents, id: \.asset) { photo in card(photo).frame(width: 150) } }
                        }
                    }
                }
                ForEach(store.catalog.families) { group in
                    let items = photos.filter { store.catalog.instrument(id: $0.instrumentId)?.familyId == group.id }
                        .sorted { rank($0) < rank($1) }
                    if !items.isEmpty {
                        HStack {
                            Text(group.name.localized).font(Typeface.display(26, relativeTo: .title2)).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("\(items.count)").font(Typeface.number(13)).foregroundStyle(Palette.inkFaint)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(items, id: \.asset) { card($0) }
                        }
                    }
                }
                if photos.isEmpty { Text("No instrument matches “\(query)”.").foregroundStyle(Palette.inkSoft).padding(.vertical, 30) }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(StageBackground(motes: false))
        .toolbar { if picker { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } } }
    }

    private var recents: [InstrumentPhoto] {
        store.recentInstrumentIds.compactMap { id in store.catalog.photo(instrumentId: id) }
    }

    @ViewBuilder private var currentTunings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("\(store.instrumentDisplayName) tunings")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.tunings) { tuning in
                        let available = AccessPolicy.canUse(tuning: tuning, of: store.instrument, pro: commerce.isPro)
                        Button {
                            store.selectTuning(tuning)
                            if available { dismiss() }
                        } label: {
                            HStack(spacing: 6) {
                                Text(tuning.name.localized)
                                if !available { Image(systemName: "lock.fill").font(.caption2) }
                            }
                        }
                        .buttonStyle(ChipButtonStyle(selected: tuning.id == store.tuning.id && !store.referenceMode))
                    }
                }
            }
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
            TextField("Search instruments", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("instruments.search")
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint) }.accessibilityLabel("Clear search") }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .glassCapsule(interactive: false)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("All") { family = nil }.buttonStyle(ChipButtonStyle(selected: family == nil))
                ForEach(store.catalog.families) { group in
                    Button(group.name.localized) { withAnimation(Motion.quick) { family = group.id } }.buttonStyle(ChipButtonStyle(selected: family == group.id))
                }
            }
        }
    }

    private var chromaticCard: some View {
        Button {
            store.selectReference()
            if picker { dismiss() }
        } label: {
            FeatureRow(symbol: "dot.radiowaves.left.and.right", title: "Chromatic", detail: "A strobe tuner for any note: voice, piano, winds or anything else.") {
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.brass)
            }
            .stillCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("instruments.chromatic")
    }

    private func card(_ photo: InstrumentPhoto) -> some View {
        let instrument = store.catalog.instrument(id: photo.instrumentId)
        let model = ModelLibrary.modelID(forPhoto: photo.asset)
        let open = instrument.map { store.canTune($0) } ?? false
        let selected = !store.referenceMode && store.photo?.asset == photo.asset
        return Button {
            guard let instrument else { return }
            if open {
                store.selectInstrument(instrument, photo: photo.asset, tuning: tuningFor(photo, instrument))
                if picker { dismiss() }
            } else { store.presentPaywall("instrument") }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RadialGradient(colors: [Palette.ember.opacity(0.18), .clear], center: .center, startRadius: 4, endRadius: 110)
                    Image(model.map(ModelLibrary.cardImageName) ?? photo.thumbnail).resizable().interpolation(.high).scaledToFit()
                        .padding(model == nil ? 14 : 4)
                        .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                HStack(alignment: .top) {
                    Text(name(photo)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    if !open { ProBadge() } else if model != nil { Image(systemName: "cube.transparent").font(.caption).foregroundStyle(Palette.brass).accessibilityLabel("3D") }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(selected ? Palette.brass : Palette.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("instrument." + photo.asset)
    }

    private func tuningFor(_ photo: InstrumentPhoto, _ instrument: Instrument) -> Tuning? {
        if photo.label == "5-string bass" || photo.label == "5-string double bass" { return store.catalog.tuning(id: instrument.id + ".five") }
        if instrument.id == "mallet.marimba.0", ["Xylophone", "Glockenspiel", "Vibraphone"].contains(photo.label) { return store.catalog.tuning(id: instrument.id + "." + photo.label.lowercased()) }
        if photo.label.hasPrefix("4-string") || photo.label == "Marimba" { return store.catalog.tuning(id: instrument.defaultTuningId) }
        return nil
    }

    private func rank(_ photo: InstrumentPhoto) -> Int {
        guard let instrument = store.catalog.instrument(id: photo.instrumentId) else { return 3 }
        return (instrument.isFree ? 0 : 2) + (ModelLibrary.modelID(forPhoto: photo.asset) == nil ? 1 : 0)
    }

    private func name(_ photo: InstrumentPhoto) -> String {
        NSLocalizedString("timbre_photo_" + photo.asset, bundle: .main, value: photo.label, comment: "")
    }
}

struct InstrumentPicker: View {
    var body: some View {
        NavigationStack {
            InstrumentsView(picker: true)
                .navigationTitle("Choose instrument")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
