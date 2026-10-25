import SwiftUI
import TimbreCore

/// Writing and fixing a chart. "Chords": the song's details (title, artist, key, tempo, capo) and its words, where a
/// tap on a word puts a chord on it (or changes or takes off the one there). "Text": the ChordPro itself, for typing or
/// pasting the words and for everything else ChordPro can say. Every change is made to the ChordPro text, so whatever
/// the author wrote around it stays as it was.
struct ChartEditorView: View {
    enum Mode: Hashable { case chords, text }

    let isNew: Bool
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var source: String
    @State private var mode: Mode
    @State private var picking: PickedWord?

    struct PickedWord: Identifiable {
        let word: ChordProEdit.Word
        var id: String { "\(word.line):\(word.offset)" }
    }

    init(source: String, isNew: Bool, onSave: @escaping (String) -> Void) {
        self.isNew = isNew
        self.onSave = onSave
        _source = State(initialValue: source)
        // A new song starts with its words; chords go on them after.
        _mode = State(initialValue: isNew ? .text : .chords)
    }

    private var chart: ChordChart { ChordProParser.parse(source) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                SegmentedPill(options: [Mode.chords, Mode.text], selection: $mode,
                              identifier: { $0 == .chords ? "yoursongs.editor.chords" : "yoursongs.editor.text" }) { option in
                    Text(option == .chords ? LocalizedStringKey("Chords") : LocalizedStringKey("Text"))
                }
                .padding(.horizontal, Metrics.gutter)
                if mode == .chords { chordsMode } else { textMode }
            }
            .padding(.top, 8)
            .background(Palette.stage.ignoresSafeArea())
            .navigationTitle(isNew ? Text("New song") : Text("Edit chart"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(source)
                        dismiss()
                    }
                    .disabled(source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("yoursongs.editor.save")
                }
            }
        }
        .presentationBackground(Palette.stage)
        .preferredColorScheme(.dark)
        .sheet(item: $picking) { picked in
            ChordPickerSheet(word: picked.word.text, current: picked.word.chord, suggestions: chart.uniqueChords.map(\.text)) { chord in
                source = ChordProEdit.setChord(chord, on: picked.word, in: source)
            }
        }
    }

    // MARK: Chords

    private var chordsMode: some View {
        let rows = ChordProEdit.words(in: source)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                details
                if rows.isEmpty {
                    EmptyState(symbol: "text.word.spacing", title: "No words yet",
                               message: "Type or paste the words under Text, then come back to put chords on them.")
                } else {
                    Text("Tap a word to put a chord on it.").font(.footnote).foregroundStyle(Palette.inkSoft)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { item in
                            wordRow(item.element)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func wordRow(_ words: [ChordProEdit.Word]) -> some View {
        ChordFlowLayout(spacing: 4, lineSpacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { item in
                wordButton(item.element)
            }
        }
    }

    private func wordButton(_ word: ChordProEdit.Word) -> some View {
        let chord = word.chord.map { NoteNames.glyphs(NoteNames.chordSymbol($0)) }
        return Button { picking = PickedWord(word: word) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: chord ?? "+")
                    .font(Typeface.label(13, relativeTo: .footnote))
                    .foregroundStyle(chord == nil ? Palette.inkFaint.opacity(0.6) : Palette.mint)
                Text(verbatim: word.text.isEmpty ? "·" : word.text)
                    .font(.body).foregroundStyle(word.text.isEmpty ? Palette.inkFaint : Palette.ink)
            }
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(chord == nil ? Color.white.opacity(0.03) : Palette.mint.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(verbatim: word.text.isEmpty ? (chord ?? "") : word.text))
        .accessibilityValue(chord.map { Text(verbatim: $0) } ?? Text("No chord"))
        .accessibilityHint(Text("Puts a chord on this word"))
    }

    // MARK: Details

    private var details: some View {
        let current = chart
        return VStack(alignment: .leading, spacing: 10) {
            field("Title", text: directive("title", current.title))
                .accessibilityIdentifier("yoursongs.editor.title")
            field("Artist", text: directive("artist", current.artist ?? ""))
            HStack(spacing: 10) {
                field("Key", text: directive("key", current.key ?? ""))
                field("Tempo", text: directive("tempo", current.tempo.map { String(Int($0.rounded())) } ?? ""))
                    .keyboardType(.numberPad)
            }
            Stepper(value: Binding(get: { current.capo }, set: { source = ChordProEdit.setDirective("capo", $0 > 0 ? String($0) : nil, in: source) }),
                    in: 0...12) {
                Text(current.capo == 0 ? LocalizedStringKey("No capo") : LocalizedStringKey("Capo \(current.capo)"))
                    .font(.subheadline).foregroundStyle(Palette.ink)
            }
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }

    private func directive(_ name: String, _ value: String) -> Binding<String> {
        Binding(get: { value }, set: { source = ChordProEdit.setDirective(name, $0, in: source) })
    }

    private func field(_ title: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Palette.inkSoft)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(.body).foregroundStyle(Palette.ink)
                .padding(.horizontal, 10).frame(minHeight: Metrics.minTarget)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).strokeBorder(Palette.controlLine, lineWidth: 1))
        }
    }

    // MARK: Text

    private var textMode: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $source)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                .accessibilityIdentifier("yoursongs.editor.source")
            Text("Chords go in brackets just before their word: [G]Amazing [C]grace. {start_of_chorus} and {end_of_chorus} mark a chorus.")
                .font(.caption).foregroundStyle(Palette.inkFaint).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Metrics.gutter).padding(.bottom, 12)
    }
}

/// Choosing a chord for a word: the chart's own chords first, then any root with any of the common qualities, the
/// chord built shown large; "Remove chord" takes off the one there.
struct ChordPickerSheet: View {
    let word: String
    let current: String?
    let suggestions: [String]
    let choose: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var root: Int
    @State private var suffix: String

    static let suffixes = ["", "m", "7", "maj7", "m7", "sus2", "sus4", "add9", "6", "9", "dim", "aug", "5"]

    init(word: String, current: String?, suggestions: [String], choose: @escaping (String?) -> Void) {
        self.word = word
        self.current = current
        self.suggestions = suggestions
        self.choose = choose
        let parsed = current.flatMap { ChordSymbol($0) }
        _root = State(initialValue: parsed?.root ?? 7)
        _suffix = State(initialValue: parsed.map { Self.suffixes.contains($0.suffix) ? $0.suffix : "" } ?? "")
    }

    private var built: String { ChordSpelling.commonNames[root] + suffix }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(verbatim: NoteNames.glyphs(NoteNames.chordSymbol(built)))
                        .font(Typeface.display(.display)).foregroundStyle(Palette.mint)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                        .accessibilityLabel(Text("Chord \(NoteNames.glyphs(NoteNames.chordSymbol(built)))"))
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("In this song", color: Palette.inkSoft)
                            ChordFlowLayout(spacing: 8, lineSpacing: 8) {
                                ForEach(suggestions, id: \.self) { chord in
                                    Button(NoteNames.glyphs(NoteNames.chordSymbol(chord))) { pick(chord) }
                                        .buttonStyle(ChipButtonStyle(selected: chord == current))
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Root", color: Palette.inkSoft)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                            ForEach(0..<12, id: \.self) { pitch in
                                Button(NoteNames.glyphs(NoteNames.chordSymbol(ChordSpelling.commonNames[pitch]))) {
                                    root = pitch
                                    Haptics.shared.selection()
                                }
                                .buttonStyle(ChipButtonStyle(selected: root == pitch))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Kind", color: Palette.inkSoft)
                        ChordFlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(Self.suffixes, id: \.self) { option in
                                Button { suffix = option; Haptics.shared.selection() } label: {
                                    option.isEmpty ? Text("Major") : Text(verbatim: option)
                                }
                                .buttonStyle(ChipButtonStyle(selected: suffix == option))
                            }
                        }
                    }
                    VStack(spacing: 10) {
                        Button { pick(built) } label: { Text("Put \(NoteNames.glyphs(NoteNames.chordSymbol(built))) here") }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("yoursongs.picker.place")
                        if current != nil {
                            Button(role: .destructive) { pick(nil) } label: { Text("Remove chord") }
                                .buttonStyle(SecondaryButtonStyle(tint: Palette.danger))
                        }
                    }
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.stage)
            .navigationTitle(Text(verbatim: word.isEmpty ? "" : "“\(word)”"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.stage)
        .preferredColorScheme(.dark)
    }

    private func pick(_ chord: String?) {
        Haptics.shared.selection()
        choose(chord)
        dismiss()
    }
}
