import SwiftUI
import TimbreCore

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var query = ""
    @State private var familyID: String?
    @FocusState private var searchFocused: Bool

    private var visiblePhotos: [InstrumentPhoto] {
        store.catalog.photos.filter { photo in
            guard let instrument = store.catalog.instrument(id: photo.instrumentId) else { return false }
            let familyMatches = familyID == nil || familyID == instrument.familyId
            let text = [photo.label, photoName(photo), instrument.name.localized, instrument.familyId].joined(separator: " ")
            return familyMatches && (query.isEmpty || text.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("timbre_library_title").font(TimbreTheme.title(32))
                    Text("timbre_library_subtitle").foregroundStyle(TimbreTheme.secondary)
                }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(TimbreTheme.secondary)
                    TextField("timbre_library_search", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }
                        .accessibilityIdentifier("collection.search")
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel(Text("timbre_library_clear_search")) }
                }.padding(14).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        filterButton(NSLocalizedString("timbre_library_all", comment: ""), id: nil)
                        ForEach(store.catalog.families) { family in filterButton(family.name.localized, id: family.id) }
                    }
                }
                if query.isEmpty && familyID == nil {
                    Button { store.selectReference() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "waveform").font(.title2).foregroundStyle(TimbreTheme.action)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.catalog.referenceMode?.name.localized ?? "Chromatic reference").font(.headline)
                                Text("timbre_library_adjust_reference").font(.caption).foregroundStyle(TimbreTheme.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.padding(18).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    if !store.settings.recentInstrumentIds.isEmpty {
                        Text("timbre_library_recent").font(TimbreTheme.title(20))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.settings.recentInstrumentIds, id: \.self) { id in
                                    if let instrument = store.catalog.instrument(id: id), let photo = store.catalog.photo(instrumentId: id) {
                                        Button { open(instrument, photo: photo) } label: {
                                            VStack(alignment: .leading) {
                                                Image(photo.thumbnail).resizable().scaledToFit().frame(width: 136, height: 98)
                                                Text(instrument.name.localized).font(.caption).lineLimit(2).frame(width: 136, alignment: .leading)
                                            }.padding(12).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                if visiblePhotos.isEmpty {
                    Text(String(format: NSLocalizedString("timbre_library_no_results", comment: ""), query)).foregroundStyle(TimbreTheme.secondary).padding(.vertical, 30)
                }
                ForEach(store.catalog.families) { family in
                    let candidates = visiblePhotos.filter { store.catalog.instrument(id: $0.instrumentId)?.familyId == family.id }
                    let photos = candidates.enumerated().sorted { left, right in
                        let leftRank = photoRank(left.element), rightRank = photoRank(right.element)
                        return leftRank == rightRank ? left.offset < right.offset : leftRank < rightRank
                    }.map(\.element)
                    if !photos.isEmpty {
                        HStack {
                            Text(family.name.localized).font(TimbreTheme.title(21))
                            Spacer()
                            Text("\(photos.count)").font(.caption.monospacedDigit()).foregroundStyle(TimbreTheme.secondary)
                        }
                        LazyVStack(spacing: 12) {
                            ForEach(photos, id: \.asset) { photo in
                                if let instrument = store.catalog.instrument(id: photo.instrumentId) { instrumentRow(instrument, photo: photo) }
                            }
                        }
                    }
                }
            }.padding(20)
        }.background(TimbreTheme.canvas).foregroundStyle(TimbreTheme.primary).scrollDismissesKeyboard(.interactively)
    }
    private func filterButton(_ name: String, id: String?) -> some View {
        Button { familyID = id } label: {
            Text(name).font(.subheadline.weight(.medium)).padding(.horizontal, 15).padding(.vertical, 10)
                .foregroundStyle(familyID == id ? TimbreTheme.ink : TimbreTheme.primary)
                .background(familyID == id ? TimbreTheme.brass : TimbreTheme.surface, in: Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(familyID == id ? .isSelected : [])
    }
    private func instrumentRow(_ instrument: Instrument, photo: InstrumentPhoto) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button { open(instrument, photo: photo) } label: {
                HStack(spacing: 12) {
                    Image(photo.thumbnail).resizable().scaledToFit().frame(width: 95, height: 105).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(photoName(photo)).font(.headline).multilineTextAlignment(.leading)
                        let free = instrument.isFree && (store.catalog.tuning(id: photoTuningID(instrument, photo: photo))?.isFree ?? false)
                        Text(free ? "timbre_library_free_to_tune" : "timbre_library_full_unlock").font(.caption).foregroundStyle(free ? TimbreTheme.success : TimbreTheme.action)
                        if instrument.isAdjustable { Text("Adjustable reference").font(.caption2).foregroundStyle(TimbreTheme.warning) }
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("collection.photo." + photo.asset)
            Menu {
                ForEach(store.catalog.tunings.filter { $0.instrumentId == instrument.id }) { tuning in
                    Button {
                        searchFocused = false
                        guard commerce.isPlus || (instrument.isFree && tuning.isFree) else { store.showPlus = true; return }
                        store.selectInstrument(instrument, photo: photo.asset, tuning: tuning)
                    } label: {
                        Label(tuning.name.localized, systemImage: tuning.isFree || commerce.isPlus ? "music.note" : "lock")
                    }
                }
            } label: { Image(systemName: "ellipsis.circle").font(.title3).frame(width: 44, height: 44) }
                .accessibilityLabel("Tunings for \(photoName(photo))")
        }.padding(12).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func photoName(_ photo: InstrumentPhoto) -> String {
        NSLocalizedString("timbre_photo_" + photo.asset, bundle: .main, value: photo.label, comment: "")
    }
    private func photoRank(_ photo: InstrumentPhoto) -> Int {
        guard let instrument = store.catalog.instrument(id: photo.instrumentId) else { return 2 }
        let id = photoTuningID(instrument, photo: photo)
        if instrument.isFree && (store.catalog.tuning(id: id)?.isFree ?? false) { return 0 }
        return id.hasSuffix(".five") ? 1 : 2
    }
    private func photoTuningID(_ instrument: Instrument, photo: InstrumentPhoto) -> String {
        let tuningID: String
        if photo.label == "5-string bass" || photo.label == "5-string double bass" { tuningID = instrument.id + ".five" }
        else if instrument.id == "mallet.marimba.0", ["Xylophone", "Glockenspiel", "Vibraphone"].contains(photo.label) { tuningID = instrument.id + "." + photo.label.lowercased() }
        else if photo.label == "4-string bass" || photo.label == "4-string double bass" || photo.label == "Marimba" { tuningID = instrument.defaultTuningId }
        else { tuningID = instrument.defaultTuningId }
        return tuningID
    }
    private func open(_ instrument: Instrument, photo: InstrumentPhoto) {
        searchFocused = false
        let tuningID = photoTuningID(instrument, photo: photo)
        guard commerce.isPlus || instrument.isFree else { store.showPlus = true; return }
        if let tuning = store.catalog.tuning(id: tuningID), !tuning.isFree && !commerce.isPlus { store.showPlus = true; return }
        store.selectInstrument(instrument, photo: photo.asset, tuning: store.catalog.tuning(id: tuningID))
    }
}
