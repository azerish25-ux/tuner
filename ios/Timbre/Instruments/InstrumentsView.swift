import SwiftUI
import TimbreCore

/// Every instrument, grouped by family, as studio cards.
struct InstrumentsView: View {
    var picker = false
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var family: String?
    @State private var creating = false
    @State private var editing: CustomTuning?
    @State private var searching = false
    @FocusState private var searchFocused: Bool

    private var photos: [InstrumentPhoto] {
        store.catalog.photos.filter { photo in
            guard let instrument = store.catalog.instrument(id: photo.instrumentId) else { return false }
            let text = [photo.label, name(photo), instrument.name.localized, instrument.familyId].joined(separator: " ")
            return (family == nil || family == instrument.familyId) && (query.isEmpty || text.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                if picker { currentTunings } else { header }
                if searching || picker { search }
                filters
                if query.isEmpty && family == nil {
                    chromaticCard
                    if !recents.isEmpty {
                        section("Your instruments", count: nil)
                        EdgeRail(spacing: 12, selection: store.referenceMode ? nil : store.photo?.asset) {
                            ForEach(recents, id: \.asset) { photo in card(photo).frame(width: 180).id(photo.asset) }
                        }
                    }
                }
                ForEach(store.catalog.families) { group in
                    let items = photos.filter { store.catalog.instrument(id: $0.instrumentId)?.familyId == group.id }
                        .sorted { rank($0) < rank($1) }
                    if !items.isEmpty {
                        section(group.name.localized, count: items.count)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                            ForEach(items, id: \.asset) { card($0) }
                        }
                    }
                }
                if photos.isEmpty { Text("No instrument matches “\(query)”.").foregroundStyle(Palette.inkSoft).padding(.vertical, 30) }
            }
            .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
        }
        .stageTopShade()
        .scrollDismissesKeyboard(.interactively)
        .background(StageBackground(motes: false))
        .toolbar { if picker { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } } }
        .sheet(isPresented: $creating) {
            if let base = store.catalog.tuning(id: store.instrument.defaultTuningId) {
                CustomTuningEditor(base: base).presentationBackground(Palette.stage)
            }
        }
        .sheet(item: $editing) { custom in
            if let base = store.catalog.tuning(id: store.instrument.defaultTuningId) {
                CustomTuningEditor(base: base, editing: custom).presentationBackground(Palette.stage)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Instruments").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                Text("\(store.catalog.instruments.count) instruments, each on its own live stage").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                withAnimation(Motion.quick) { searching.toggle(); if !searching { query = "" } }
            } label: {
                Image(systemName: searching ? "xmark" : "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.stageRaised)).overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(searching ? "Close search" : "Search instruments")
            .accessibilityIdentifier("instruments.searchToggle")
        }
    }

    private func section(_ title: String, count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Typeface.display(20)).foregroundStyle(Palette.ink)
            Spacer()
            if let count { Text("\(count)").font(Typeface.number(13)).foregroundStyle(Palette.inkFaint) }
        }
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }

    private var recents: [InstrumentPhoto] {
        store.recentInstrumentIds.compactMap { id in store.catalog.photo(instrumentId: id) }
    }

    @ViewBuilder private var currentTunings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Eyebrow("\(store.instrumentDisplayName) tunings")
                Spacer(minLength: 8)
                customTuningButton
            }
            EdgeRail(selection: store.referenceMode ? nil : store.tuning.id) {
                ForEach(store.tunings) { tuning in
                    let available = AccessPolicy.canUse(tuning: tuning, of: store.instrument, pro: commerce.isPro)
                    Button {
                        store.selectTuning(tuning)
                        if available { dismiss() }
                    } label: {
                        HStack(spacing: 6) {
                            if tuning.isCustom { Image(systemName: "slider.vertical.3").font(.caption2) }
                            Text(tuning.name.localized)
                            if !available { Image(systemName: "lock.fill").font(.caption2) }
                        }
                    }
                    .buttonStyle(ChipButtonStyle(selected: tuning.id == store.tuning.id && !store.referenceMode))
                    .id(tuning.id)
                    .contextMenu {
                        if tuning.isCustom, let custom = store.customTuning(id: tuning.id) {
                            Button { editing = custom } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { store.deleteCustomTuning(id: custom.id) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }

    /// New custom tuning: in the section header so it's always in reach, not at the far end of the rail.
    @ViewBuilder private var customTuningButton: some View {
        if !store.referenceMode, !store.courses.isEmpty {
            Button {
                if commerce.isPro { creating = true } else { store.presentPaywall("custom_tuning") }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Custom")
                    if !commerce.isPro { ProBadge() }
                }
            }
            .buttonStyle(ChipButtonStyle(selected: false))
            .accessibilityIdentifier("tunings.custom")
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
            TextField("Search instruments", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searchFocused)
                .onAppear { if searching { searchFocused = true } }
                .accessibilityIdentifier("instruments.search")
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint) }.accessibilityLabel("Clear search") }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }

    private var filters: some View {
        EdgeRail(selection: family ?? Self.allFamilies) {
            Button("All") { family = nil }.buttonStyle(ChipButtonStyle(selected: family == nil))
                .id(Self.allFamilies)
            ForEach(store.catalog.families) { group in
                Button(group.name.localized) { withAnimation(Motion.quick) { family = group.id } }.buttonStyle(ChipButtonStyle(selected: family == group.id))
                    .id(group.id)
            }
        }
    }

    /// Rail id of the "All" filter chip.
    private static let allFamilies = "filter.all"

    /// The chromatic tuner: the pitch line wraps to as many lines as it needs instead of truncating.
    private var chromaticCard: some View {
        Button {
            store.selectReference()
            if picker { dismiss() }
        } label: {
            HStack(spacing: 14) {
                IconOrb(symbol: "dot.radiowaves.left.and.right", tint: Palette.brass)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Chromatic").font(.headline).foregroundStyle(Palette.ink)
                    Text("A strobe tuner for any note: voice, piano, winds or anything else.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.brass)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .stillCard(tint: store.referenceMode ? Palette.mint : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.referenceMode ? .isSelected : [])
        .accessibilityIdentifier("instruments.chromatic")
    }

    private func card(_ photo: InstrumentPhoto) -> some View {
        let instrument = store.catalog.instrument(id: photo.instrumentId)
        let model = ModelLibrary.modelID(forPhoto: photo.asset)
        let open = instrument.map { store.canTune($0) } ?? false
        let selected = !store.referenceMode && store.photo?.asset == photo.asset
        let tunings = instrument?.supportedTuningIds.count ?? 0
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            guard let instrument else { return }
            if open {
                store.selectInstrument(instrument, photo: photo.asset, tuning: tuningFor(photo, instrument))
                if picker { dismiss() }
            } else { store.presentPaywall("instrument", instrument: instrument) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Image(model.flatMap { ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : nil } ?? photo.thumbnail).resizable().interpolation(.high).scaledToFit()
                    .padding(.vertical, 6)
                    .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
                    .frame(height: 148)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                cardCaption(name: name(photo), tunings: tunings, selected: selected)
            }
            .padding(14)
            .background {
                shape.fill(Palette.stageRaised)
                    .overlay(RadialGradient(colors: [(selected ? Palette.mint : Color(hex: 0xFFC48C)).opacity(selected ? 0.10 : 0.06), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 4, endRadius: 140).clipShape(shape))
            }
            .overlay(shape.strokeBorder(selected ? Palette.mint : Palette.line, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) { if !open { ProBadge().padding(12) } }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("instrument." + photo.asset)
    }

    /// Name (up to two lines, so "7-string electric guitar" reads in full) over the tuning count. Two
    /// lines are always reserved and the text sits at the bottom, so cards in a row keep one height
    /// and one-line names still sit right above their count.
    private func cardCaption(name: String, tunings: Int, selected: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "A\nA").font(Typeface.display(16)).lineLimit(2)
                Text(verbatim: "A").font(.footnote)
            }
            .hidden()
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(Typeface.display(16)).foregroundStyle(Palette.ink)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Group {
                    if selected { Text("Tuning now · \(tunings) tunings") } else if tunings == 1 { Text("1 tuning") } else { Text("\(tunings) tunings") }
                }
                .font(.footnote).foregroundStyle(selected ? Palette.mint : Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .paywallSheet()
    }
}
