import SwiftUI
import TimbreCore
import UIKit

/// Every instrument, grouped by family, as studio cards.
struct InstrumentsView: View {
    var picker = false
    /// A full page of its own (the picker on iPad): the last row fades into the stage at the bottom edge rather than
    /// being cut there, with room under it to scroll clear of the fade.
    var fullPage = false
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
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                    if picker { currentTunings.id(Self.top) } else { header.id(Self.top) }
                    if searching || picker { search }
                    filters
                    if query.isEmpty && family == nil {
                        chromaticCard
                        section(Text("Your instruments"), count: nil)
                        shelf { browse(scroller) }
                    }
                    ForEach(store.catalog.families) { group in
                        let items = photos.filter { store.catalog.instrument(id: $0.instrumentId)?.familyId == group.id }
                            .sorted { rank($0) < rank($1) }
                        if !items.isEmpty {
                            section(Text(verbatim: group.name.localized), count: items.count)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                                ForEach(items, id: \.asset) { card($0) }
                            }
                        }
                    }
                    if photos.isEmpty { noMatches }
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
                .padding(.bottom, fullPage ? Self.bottomFade : 0)
            }
            .stageTopShade()
            .overlay(alignment: .bottom) { if fullPage { bottomShade } }
            .scrollDismissesKeyboard(.interactively)
        }
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

    /// How far the full page's bottom fade reaches up from the safe area's edge.
    private static let bottomFade: CGFloat = 64

    /// The full page's bottom edge: the cards passing under it dim into the stage, so a row running off the screen
    /// reads as more below rather than as cut. On through the home indicator's strip; never in the way of a tap.
    private var bottomShade: some View {
        LinearGradient(colors: [Palette.stageDeep.opacity(0), Palette.stageDeep.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            .frame(height: Self.bottomFade)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The tab's header, its trailing control the search (a 44 pt disc, as a header's search is everywhere).
    private var header: some View {
        TabHeader(title: Text("Instruments"),
                  subtitle: Text("\(store.catalog.instruments.count) instruments, each on its own live stage")) {
            searchToggle
        }
    }

    private var searchToggle: some View {
        IconButton(symbol: searching ? "xmark" : "magnifyingglass", size: .regular,
                   label: searching ? LocalizedStringKey("Close search") : LocalizedStringKey("Search instruments")) {
            withAnimation(Motion.quick) { searching.toggle(); if !searching { query = "" } }
        }
        .accessibilityIdentifier("instruments.searchToggle")
    }

    /// A family's section between the grids: its name, and how many instruments it holds on the baseline.
    private func section(_ title: Text, count: Int?) -> some View {
        SectionHeader(title) {
            if let count { Text("\(count)").font(Typeface.number(13)).foregroundStyle(Palette.inkFaint) }
        }
        .padding(.top, 6)
    }

    /// Nothing matches the search: the reason, in the stage's empty-state style.
    private var noMatches: some View {
        EmptyState(symbol: "magnifyingglass", title: Text("No instrument matches “\(query)”."))
    }

    private var recents: [InstrumentPhoto] {
        store.recentInstrumentIds.compactMap { id in store.catalog.photo(instrumentId: id) }
    }

    // MARK: Your instruments

    /// Scroll id of the screen's first row (the Add card scrolls back up to the search).
    private static let top = "instruments.top"
    /// Rail id of the Add card.
    private static let addID = "instruments.add"
    private static let shelfCardWidth: CGFloat = 180

    /// The shelf: the person's instruments, then two to try next, then a ghost card that opens search. It always
    /// reads as a collection with room to grow, never one lonely card.
    private func shelf(browse: @escaping () -> Void) -> some View {
        EdgeRail(spacing: 12, selection: store.referenceMode ? nil : store.photo?.asset) {
            ForEach(mine, id: \.asset) { photo in
                card(photo).frame(width: Self.shelfCardWidth).id(photo.asset)
            }
            ForEach(suggestions, id: \.asset) { photo in
                card(photo, suggested: true).frame(width: Self.shelfCardWidth).id(photo.asset)
            }
            addCard(action: browse).frame(width: Self.shelfCardWidth).id(Self.addID)
        }
    }

    /// The instruments this person plays, most recent first; the one on the tuner wears the photo it is tuned as
    /// and leads when it has no practice yet.
    private var mine: [InstrumentPhoto] {
        var list = recents
        guard !store.referenceMode, let current = store.photo else { return list }
        if let index = list.firstIndex(where: { $0.instrumentId == current.instrumentId }) {
            list[index] = current
        } else {
            list.insert(current, at: 0)
        }
        return list
    }

    /// Two instruments to try next, picked from what this person plays: a guitarist's ukulele and bass, a
    /// violinist's viola and cello. Ones that need Pro wear its badge.
    private var suggestions: [InstrumentPhoto] {
        let owned = mine.map(\.instrumentId)
        let base = store.referenceMode ? (owned.first ?? store.instrument.id) : store.instrument.id
        let family = store.catalog.instrument(id: base)?.familyId ?? ""
        let ideas = (Self.nextUp[base] ?? []) + (Self.nextUp[family] ?? []) + (Self.nextUp["guitar"] ?? [])
        var seen = Set(owned + [base])
        var picks: [InstrumentPhoto] = []
        for id in ideas {
            if picks.count == 2 { break }
            guard seen.insert(id).inserted, let photo = store.catalog.photo(instrumentId: id) else { continue }
            picks.append(photo)
        }
        return picks
    }

    /// Natural next instruments, by instrument and then by family, nearest first.
    private static let nextUp: [String: [String]] = [
        "guitar.acoustic.6": ["ukulele.soprano.4", "bass.electric.4", "mandolin.standard.8"],
        "bass.electric.4": ["guitar.acoustic.6", "bass.double.4", "ukulele.bass.4"],
        "ukulele.soprano.4": ["guitar.acoustic.6", "ukulele.baritone.4", "mandolin.standard.8"],
        "violin.standard.4": ["viola.standard.4", "cello.standard.4", "mandolin.standard.8"],
        "viola.standard.4": ["violin.standard.4", "cello.standard.4"],
        "cello.standard.4": ["bass.double.4", "violin.standard.4", "viola.standard.4"],
        "bass.double.4": ["cello.standard.4", "bass.electric.4"],
        "guitar": ["ukulele.soprano.4", "bass.electric.4", "guitar.acoustic.12", "mandolin.standard.8"],
        "ukulele": ["guitar.acoustic.6", "ukulele.soprano.4", "charango.standard.10"],
        "mandolin": ["banjo.five.5", "guitar.acoustic.6", "violin.standard.4", "mandola.standard.8"],
        "bowed_strings": ["violin.standard.4", "cello.standard.4", "mandolin.standard.8"],
        "folk_world_strings": ["mandolin.standard.8", "guitar.acoustic.6", "bouzouki.irish.8"],
        "keys": ["ukulele.soprano.4", "guitar.acoustic.6", "keys.accordion.0"],
        "winds": ["recorder.standard.0", "flute.concert.0", "tin_whistle.d.0"],
        "mallet_percussion_hand": ["kalimba.standard.17", "handpan.standard.0", "ukulele.soprano.4"],
    ]

    /// The Add card: back up to the search, opened and focused, with every instrument listed below it.
    private func browse(_ scroller: ScrollViewProxy) {
        Haptics.shared.selection()
        withAnimation(Motion.settle) {
            searching = true
            scroller.scrollTo(Self.top, anchor: .top)
        }
        searchFocused = true
    }

    /// The shelf's last card: the outline of a card with a plus, the same size as the others.
    private func addCard(action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    Circle().fill(Palette.mint.opacity(0.12))
                    Circle().strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1)
                    Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(Palette.mint)
                }
                .frame(width: 64, height: 64)
                .frame(height: 148)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .accessibilityHidden(true)
                captionBlock(Text("Add instrument"), detail: Text("Browse all \(store.catalog.instruments.count)"), tint: Palette.inkSoft)
            }
            .padding(14)
            .background(shape.fill(Palette.stageRaised.opacity(0.35)))
            .overlay(shape.strokeBorder(Palette.inkFaint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(Self.addID)
    }

    /// "Try next" over a suggested card's photo.
    private var tryNextTag: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
            Text("Try next").lineLimit(1)
        }
        .font(Typeface.label(11))
        .foregroundStyle(Palette.mint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(Palette.stage.opacity(0.6)))
        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder private var currentTunings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                tuningsHeading
                Spacer(minLength: 8)
                customTuningButton.fixedSize().layoutPriority(1)
            }
            EdgeRail(selection: store.referenceMode ? nil : store.tuning.id) {
                ForEach(store.tunings) { tuning in
                    let available = AccessPolicy.canUse(tuning: tuning, of: store.instrument, pro: commerce.isPro)
                    Button {
                        store.selectTuning(tuning)
                        if available { dismiss() }
                    } label: {
                        // At its own width: a rail never has to squeeze a chip, so a name is never cut ("My tuni…").
                        HStack(spacing: 6) {
                            if tuning.isCustom { Image(systemName: "slider.vertical.3").font(.caption2) }
                            Text(tuning.name.localized).lineLimit(1)
                            if !available { Image(systemName: "lock.fill").font(.caption2) }
                        }
                        .fixedSize(horizontal: true, vertical: false)
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

    /// "Tunings", one line beside the Custom button, the same for every instrument and plan (it used to grow into
    /// "Acoustic guitar tunings" only when the name fitted, so it changed with the instrument and with the Pro badge on
    /// Custom). The instrument is named right below, under Your instruments; VoiceOver hears the full heading.
    private var tuningsHeading: some View {
        Eyebrow("Tunings").lineLimit(1).minimumScaleFactor(0.8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(store.instrumentDisplayName) tunings"))
            .accessibilityAddTraits(.isHeader)
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

    /// The search field: a capsule with a control's edge. Its clear button is a full 44 pt target inside the
    /// capsule's height, so the field never grows when it appears.
    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkSoft)
                .accessibilityHidden(true)
            TextField("Search instruments", text: $query).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($searchFocused)
                .onAppear { if searching { searchFocused = true } }
                .accessibilityIdentifier("instruments.search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkFaint).tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16).padding(.trailing, query.isEmpty ? 16 : 2)
        .frame(minHeight: 48)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
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
                IconOrb(symbol: "dot.radiowaves.left.and.right", tint: Palette.mint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Chromatic").font(.headline).foregroundStyle(Palette.ink)
                    Text("A strobe tuner for any note: voice, piano, winds or anything else.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.mint)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .stillCard(tint: store.referenceMode ? Palette.mint : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(store.referenceMode ? .isSelected : [])
        .accessibilityIdentifier("instruments.chromatic")
    }

    /// An instrument card. A suggested one (the shelf's "Try next") wears the tag over its photo and its own id,
    /// so `instrument.<asset>` always finds the card in the family grid.
    private func card(_ photo: InstrumentPhoto, suggested: Bool = false) -> some View {
        let instrument = store.catalog.instrument(id: photo.instrumentId)
        let model = ModelLibrary.modelID(forPhoto: photo.asset)
        let open = instrument.map { store.canTune($0) } ?? false
        let selected = !store.referenceMode && store.photo?.asset == photo.asset
        let tunings = instrument?.supportedTuningIds.count ?? 0
        let shape = RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
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
                    .overlay(RadialGradient(colors: [(selected ? Palette.mint : Palette.spotlight).opacity(selected ? 0.10 : 0.06), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 4, endRadius: 140).clipShape(shape))
            }
            .overlay(shape.strokeBorder(selected ? Palette.mint : Palette.hairline, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) { if !open { ProBadge().padding(12) } }
            .overlay(alignment: .topLeading) { if suggested { tryNextTag.padding(12) } }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier((suggested ? "instruments.next." : "instrument.") + photo.asset)
    }

    /// Name (up to two lines, so "7-string electric guitar" reads in full) over the tuning count.
    private func cardCaption(name: String, tunings: Int, selected: Bool) -> some View {
        captionBlock(Text(name), detail: tuningLine(tunings, selected: selected), tint: selected ? Palette.mint : Palette.inkSoft)
    }

    private func tuningLine(_ tunings: Int, selected: Bool) -> Text {
        if selected { return Text("Tuning now · \(tunings) tunings") }
        return tunings == 1 ? Text("1 tuning") : Text("\(tunings) tunings")
    }

    /// A card's two lines. Two title lines are always reserved and the text sits at the bottom, so cards in a
    /// row keep one height and one-line names still sit right above their detail.
    private func captionBlock(_ title: Text, detail: Text, tint: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "A\nA").font(Typeface.display(16)).lineLimit(2)
                Text(verbatim: "A").font(.footnote)
            }
            .hidden()
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                title.font(Typeface.display(16)).foregroundStyle(Palette.ink)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                detail.font(.footnote).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.75)
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
    /// A full page of its own (iPad) rather than a sheet.
    var fullPage = false

    var body: some View {
        NavigationStack {
            InstrumentsView(picker: true, fullPage: fullPage)
                .navigationTitle("Choose instrument")
                .navigationBarTitleDisplayMode(.inline)
        }
        .paywallSheet()
    }
}

extension View {
    /// The instrument browser over the tuner: a sheet on a phone; on iPad a full page of its own, so all 60 instruments
    /// get the whole screen and none of the tuner's controls (Auto, Manual, Strum, the readout) show around a sheet's
    /// edges. Done closes it either way.
    func instrumentPicker(isPresented: Binding<Bool>) -> some View {
        modifier(InstrumentPickerPresentation(isPresented: isPresented))
    }
}

private struct InstrumentPickerPresentation: ViewModifier {
    @Binding var isPresented: Bool
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService

    /// The device decides, not the window's width: a picker never switches presentation while it is up (iPad
    /// multitasking resizes), and a large iPhone in landscape keeps its sheet.
    private var fullPage: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @ViewBuilder func body(content: Content) -> some View {
        if fullPage {
            // No presentation background: an opaque page (its stage background fills the screen) lets the tuner leave
            // the screen under it, rather than keep rendering out of sight.
            content.fullScreenCover(isPresented: $isPresented) {
                InstrumentPicker(fullPage: true)
                    .environmentObject(store)
                    .environmentObject(commerce)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                InstrumentPicker().presentationDetents([.large]).presentationBackground(Palette.stage)
            }
        }
    }
}
