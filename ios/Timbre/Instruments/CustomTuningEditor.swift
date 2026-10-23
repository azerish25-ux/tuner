import SwiftUI
import TimbreCore

/// Build or edit a tuning: one target per string, stepped in semitones from the
/// instrument's standard tuning, with a reference tone for each string.
struct CustomTuningEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.dismiss) private var dismiss
    let editing: CustomTuning?
    @State private var name: String
    @State private var midis: [Int]
    private let base: [Course]

    init(base: Tuning, editing: CustomTuning? = nil) {
        self.editing = editing
        self.base = base.courses.sorted { $0.index < $1.index }
        _name = State(initialValue: editing?.name ?? String(localized: "My tuning"))
        _midis = State(initialValue: editing?.midis ?? self.base.map(\.targetMidi))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Tuning name", text: $name)
                        .font(Typeface.display(30)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16).padding(.vertical, 12).glassCapsule(interactive: false)
                        .accessibilityIdentifier("custom.name")
                    Text("Move each string in semitones, up to an octave either way. Tap a string to hear it.")
                        .font(.footnote).foregroundStyle(Palette.inkSoft)
                    VStack(spacing: 0) {
                        let groups = self.groups
                        ForEach(Array(groups.enumerated()), id: \.offset) { number, group in
                            row(number: groups.count - number, group: group)
                            if number < groups.count - 1 { Divider().overlay(Palette.line) }
                        }
                    }
                    .stillCard(padding: 6)
                    if editing != nil {
                        Button(role: .destructive) {
                            if let editing { store.deleteCustomTuning(id: editing.id) }
                            dismiss()
                        } label: { Label("Delete tuning", systemImage: "trash") }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.danger)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(Metrics.gutter)
            }
            .stageTopShade()
            .background(StageBackground(motes: false))
            .navigationTitle(editing == nil ? "New tuning" : "Edit tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.saveCustomTuning(CustomTuning(id: editing?.id ?? "custom." + UUID().uuidString.lowercased(),
                                                            instrumentId: store.instrument.id,
                                                            name: trimmed.isEmpty ? String(localized: "My tuning") : String(trimmed.prefix(60)),
                                                            midis: midis))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("custom.save")
                }
            }
        }
    }

    /// Strings tuned together, as offsets into `base`: a mandolin's or 12-string's pairs share one row
    /// (one anchor), so a paired instrument shows four rows, not eight.
    private var groups: [[Int]] {
        var order: [String] = []
        var members: [String: [Int]] = [:]
        for (offset, course) in base.enumerated() {
            let key = course.anchorId ?? "course.\(course.index)"
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(offset)
        }
        return order.compactMap { members[$0] }
    }

    /// One string (or pair), numbered from the highest like the instrument: its note, how far it moved,
    /// and steppers that move the whole pair together.
    private func row(number: Int, group: [Int]) -> some View {
        let first = group.first ?? 0
        let midi = midis[first]
        let shift = midi - base[first].targetMidi
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("String \(number)")
                    if group.count > 1 { Text(verbatim: "×\(group.count)") }
                }
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.inkFaint)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(PitchMath.noteName(midi: midi, notation: store.settings.notation)).font(Typeface.display(28)).foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    if shift != 0 {
                        Text(shift > 0 ? "+\(shift)" : "\(shift)").font(Typeface.number(12))
                            .foregroundStyle(shift > 0 ? Palette.sharp : Palette.flat)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { play(group) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Plays this string's note"))
            Spacer()
            Button { step(group, -1) } label: { Image(systemName: "minus") }
                .buttonStyle(ChipButtonStyle(selected: false)).disabled(shift <= -12)
                .accessibilityLabel(Text("Lower string \(number)"))
            Button { step(group, 1) } label: { Image(systemName: "plus") }
                .buttonStyle(ChipButtonStyle(selected: false)).disabled(shift >= 12)
                .accessibilityLabel(Text("Raise string \(number)"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    private func step(_ group: [Int], _ delta: Int) {
        withAnimation(Motion.quick) { for offset in group { midis[offset] += delta } }
        Haptics.shared.selection()
        play(group)
    }

    /// The string's note; an octave pair sounds both notes together.
    private func play(_ group: [Int]) {
        let pitches = Array(Set(group.map { midis[$0] })).sorted()
        let tones = pitches.map { PitchMath.frequency(midi: Double($0), reference: store.settings.referencePitchHz) }
        audio.playTones(tones, together: tones.count > 1)
    }
}

/// Presents the paywall from whichever surface is on top (root, a sheet, a sheet's sheet).
struct PaywallHost: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    let active: Bool
    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { active && store.showPaywall }, set: { if !$0 { store.showPaywall = false } })) {
            PaywallView().environmentObject(store).environmentObject(commerce)
        }
    }
}

extension View {
    func paywallSheet(active: Bool = true) -> some View { modifier(PaywallHost(active: active)) }
}
