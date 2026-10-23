import StoreKit
import SwiftUI
import TimbreCore

/// Settings in the Studio Noir card style: each group is a raised card under an eyebrow header, every row
/// carries an icon orb, separators are inset to the titles, and footers sit small and grey below their card.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @State private var referenceInput = ""
    @State private var confirmClear = false
    @State private var manageSubscriptions = false
    @FocusState private var referenceFocused: Bool
    @AppStorage(TuneView.strobeKey) private var strobeView = false

    private func setting<Value>(_ keyPath: WritableKeyPath<UserSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { value in store.updateSettings { $0[keyPath: keyPath] = value } })
    }
    private var parsedReference: Double? {
        guard let value = Double(referenceInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, (415...466).contains(value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    membership
                    tuningSection
                    displaySection
                    feedbackSection
                    reminderSection
                    listeningSection
                    languageSection
                    privacySection
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
            .stageTopShade()
            .background(StageBackground(motes: false))
            .tint(Palette.mint)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { referenceFocused = false } }
            }
            .onAppear { referenceInput = String(store.settings.referencePitchHz) }
            .onChange(of: store.settings.referencePitchHz) { _, value in referenceInput = String(value) }
            .confirmationDialog("Clear practice history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { store.clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes saved sessions, streaks and voice progress from this device.") }
            .manageSubscriptionsSheet(isPresented: $manageSubscriptions)
        }
        .paywallSheet()
    }

    // MARK: Membership

    private var membership: some View {
        SettingsGroup(tint: commerce.isPro ? Palette.mint : Palette.amber) {
            if commerce.isPro {
                proStatus
                if commerce.activeProductID != TimbreProduct.lifetime {
                    RowDivider()
                    Button { manageSubscriptions = true } label: {
                        SettingRow(symbol: "creditcard", title: Text("Manage subscription")) { RowGlyph(symbol: "chevron.right") }
                    }
                    .buttonStyle(RowButtonStyle())
                }
            } else {
                Button { store.presentPaywall("settings") } label: {
                    FeatureRow(symbol: "sparkles", title: "Try Timbre Pro", detail: "Every instrument, every ear game and practice tool.") { ProBadge() }
                        .padding(16)
                }
                .buttonStyle(RowButtonStyle())
                .accessibilityIdentifier("settings.pro")
            }
            RowDivider()
            Button { Task { await commerce.restore() } } label: {
                SettingRow(symbol: "arrow.clockwise", title: Text("Restore purchases"))
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    private var proStatus: some View {
        HStack(spacing: 14) {
            IconOrb(symbol: "checkmark.seal.fill", tint: Palette.mint)
            VStack(alignment: .leading, spacing: 3) {
                Text("Timbre Pro is active").font(.headline).foregroundStyle(Palette.ink)
                if let date = commerce.renewalDate {
                    Text("Renews \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(Palette.inkSoft)
                } else if commerce.activeProductID == TimbreProduct.lifetime {
                    Text("Lifetime").font(.caption).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 8)
            ProBadge()
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: Tuning

    private var tuningSection: some View {
        SettingsGroup(title: "Tuning", footer: Text("Capo and transposition change the names you see, never the pitch Timbre measures.")) {
            referenceRow
            RowDivider()
            temperamentPicker
            RowDivider()
            precisionPicker
            RowDivider()
            strobeToggle
            RowDivider()
            notationPicker
            RowDivider()
            capoStepper
            RowDivider()
            transposeStepper
        }
    }

    private var temperamentPicker: some View {
        MenuRow(title: "Temperament", symbol: "slider.horizontal.3", id: "settings.temperament", selection: Binding(get: { store.settings.temperamentId }, set: { value in
            if value != "equal" && !commerce.isPro { store.presentPaywall("temperament"); return }
            store.updateSettings { $0.temperamentId = value }
        })) { ForEach(Temperament.all) { Text($0.name).tag($0.id) } }
    }

    private var strobeToggle: some View {
        Toggle(isOn: Binding(get: { strobeView }, set: { on in
            if on && !commerce.isPro { store.presentPaywall("precision"); return }
            strobeView = on
        })) { RowLabel(symbol: "circle.dotted", title: Text("Strobe precision")) }
        .settingsRow()
        .accessibilityIdentifier("settings.strobe")
    }

    private var capoStepper: some View {
        Stepper(value: Binding(get: { store.settings.capo }, set: { v in
            guard commerce.isPro || v == 0 else { store.presentPaywall("capo"); return }
            store.updateSettings { $0.capo = v }
        }), in: 0...12) { RowLabel(symbol: "line.3.horizontal", title: Text("Capo: \(store.settings.capo)")) }
        .settingsRow()
    }

    private var transposeStepper: some View {
        Stepper(value: Binding(get: { store.settings.transposition }, set: { v in
            guard commerce.isPro || v == 0 else { store.presentPaywall("transpose"); return }
            store.updateSettings { $0.transposition = v }
        }), in: -12...12) { RowLabel(symbol: "arrow.up.arrow.down", title: Text("Transpose: \(store.settings.transposition)")) }
        .settingsRow()
    }

    /// A4 in hertz: typed, checked against 415–466 Hz, and applied on demand.
    private var referenceRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RowLabel(symbol: "tuningfork", title: Text("A4"))
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    TextField("440", text: $referenceInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($referenceFocused)
                        .font(Typeface.number(17))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 72)
                        .accessibilityIdentifier("settings.referenceInput")
                    Text("Hz").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(referenceFocused ? Palette.mint.opacity(0.6) : Palette.line, lineWidth: 1))
            }
            .settingsRow()
            referenceStatus
        }
        .animation(Motion.quick, value: parsedReference)
    }

    @ViewBuilder private var referenceStatus: some View {
        if parsedReference == nil {
            Text("Enter a value from 415 to 466 Hz.")
                .font(.footnote).foregroundStyle(Palette.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, RowDivider.inset).padding(.trailing, 16).padding(.bottom, 12)
        } else if parsedReference != store.settings.referencePitchHz {
            Button("Apply \(referenceInput) Hz") { referenceFocused = false; if let v = parsedReference { store.updateSettings { $0.referencePitchHz = v } } }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, RowDivider.inset).padding(.trailing, 16).padding(.bottom, 12)
                .accessibilityIdentifier("settings.applyReference")
        }
    }

    /// How close a string must hold to lock: Beginner ±5¢ (the original), Standard ±3¢, Pro ±1¢ (Timbre Pro).
    /// The tracker, the colours and the meter's green zone all follow it.
    private var precisionPicker: some View {
        MenuRow(title: "Precision", symbol: "scope", id: "settings.precision", selection: Binding(get: { store.settings.precision }, set: { value in
            if value == .pro && !commerce.isPro { store.presentPaywall("precision"); return }
            store.updateSettings { $0.precision = value }
        })) {
            ForEach(TuningPrecision.allCases, id: \.self) { precision in
                (Self.precisionName(precision) + Text(verbatim: " ±\(Int(precision.bandCents))¢")).tag(precision)
            }
        }
    }

    private static func precisionName(_ precision: TuningPrecision) -> Text {
        switch precision {
        case .beginner: return Text("Beginner")
        case .standard: return Text("Standard")
        case .pro: return Text("Pro")
        }
    }

    /// Letters, German letters (B natural is H, B flat is B), solfège, sargam or numbers. Picking one here
    /// fixes it; until then it follows the app language.
    private var notationPicker: some View {
        MenuRow(title: "Note names", symbol: "textformat.abc", id: "settings.notation", selection: Binding(get: { store.settings.notation }, set: { value in
            store.updateSettings { $0.notation = value; $0.notationChosen = true }
        })) {
            Text("Letters").tag("english")
            Text("German (H)").tag("german")
            Text("Solfège").tag("solfege")
            Text("Sargam").tag("sargam")
            Text("Numbers").tag("numbered")
        }
    }

    // MARK: Display and feedback

    /// Which string is drawn on top wherever a neck lies across the screen (`StringOrder`).
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab

    private var displaySection: some View {
        SettingsGroup(title: "Display") {
            MenuRow(title: "Handedness", symbol: "hand.raised", id: "settings.handedness", selection: setting(\.handedness)) {
                Text("Right-handed").tag("right"); Text("Left-handed").tag("left")
            }
            RowDivider()
            stringOrderChoice
        }
    }

    /// "String order" and its two options, each with a small picture of the strings in that order and a check
    /// on the chosen one (the options are too long to sit in a menu at the end of a row).
    private var stringOrderChoice: some View {
        VStack(spacing: 0) {
            RowLabel(symbol: "list.number", title: Text("String order"))
                .settingsRow()
                .accessibilityAddTraits(.isHeader)
            ForEach(StringOrder.allCases) { order in
                RowDivider()
                stringOrderOption(order)
            }
        }
    }

    private func stringOrderOption(_ order: StringOrder) -> some View {
        let selected = stringOrder == order
        return Button {
            stringOrder = order
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 12) {
                StringOrderGlyph(thinnestOnTop: order.thinnestOnTop, lit: selected)
                Text(order.title).font(.body).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Palette.mint)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .settingsRow()
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .animation(Motion.quick, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings.stringOrder.\(order.rawValue)")
    }

    private var feedbackSection: some View {
        SettingsGroup(title: "Feedback") {
            Toggle(isOn: setting(\.hapticsEnabled)) { RowLabel(symbol: "iphone.radiowaves.left.and.right", title: Text("Haptics")) }
                .settingsRow()
            RowDivider()
            MenuRow(title: "Stage", symbol: "cube.transparent", id: "settings.stage",
                    selection: Binding(get: { store.settings.stageMode ?? "3d" }, set: { v in store.updateSettings { $0.stageMode = v } })) {
                Text("Real-time 3D").tag("3d"); Text("Studio (lighter)").tag("studio")
            }
        }
    }

    // MARK: Reminders

    @AppStorage(PracticeReminder.enabledKey) private var reminderOn = false
    @AppStorage(PracticeReminder.minutesKey) private var reminderMinutes = 19 * 60

    private var reminderSection: some View {
        SettingsGroup(title: "Reminders", footer: Text("One gentle nudge a day, at a time you choose.")) {
            Toggle(isOn: Binding(get: { reminderOn }, set: { on in
                if on { Task { reminderOn = await PracticeReminder.enable(at: reminderMinutes) } } else { PracticeReminder.disable(); reminderOn = false }
            })) { RowLabel(symbol: "bell", title: Text("Daily practice reminder")) }
            .settingsRow()
            .accessibilityIdentifier("settings.reminder")
            if reminderOn {
                RowDivider()
                DatePicker(selection: Binding(get: {
                    Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
                }, set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    reminderMinutes = (parts.hour ?? 19) * 60 + (parts.minute ?? 0)
                    Task { await PracticeReminder.enable(at: reminderMinutes) }
                }), displayedComponents: .hourAndMinute) { RowLabel(symbol: "clock", title: Text("Time")) }
                .settingsRow()
                .transition(.opacity)
            }
        }
        .animation(Motion.settle, value: reminderOn)
    }

    // MARK: Listening, language, privacy

    private var listeningSection: some View {
        SettingsGroup {
            NavigationLink { AdvancedListening() } label: {
                SettingRow(symbol: "ear", title: Text("Advanced listening")) { RowGlyph(symbol: "chevron.right") }
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    private var languageSection: some View {
        SettingsGroup(title: "Language") {
            // Note names follow the language until the player picks a system (German reads B natural as H).
            MenuRow(title: "App language", symbol: "globe", id: "settings.language", selection: Binding(get: { store.settings.language }, set: { value in
                store.updateSettings { $0.language = value; $0.applyNotationDefault(systemLanguage: Locale.preferredLanguages.first) }
            })) {
                Text("System default").tag("system")
                ForEach(Self.languages, id: \.self) { code in
                    Text(Locale(identifier: code).localizedString(forIdentifier: code)?.localizedCapitalized ?? code).tag(code)
                }
            }
        }
    }

    private var privacySection: some View {
        SettingsGroup(title: "Privacy", footer: Text("Timbre \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")) {
            HStack(alignment: .top, spacing: 12) {
                IconOrb(symbol: "lock.shield.fill", tint: Palette.mint, size: 30)
                Text("Microphone audio is analysed on this device. Recordings are never saved or uploaded.")
                    .font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
            }
            .settingsRow()
            RowDivider()
            Link(destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!) {
                SettingRow(symbol: "doc.text", title: Text("Privacy policy")) { RowGlyph(symbol: "arrow.up.right") }
            }
            .buttonStyle(RowButtonStyle())
            RowDivider()
            NavigationLink { Acknowledgements() } label: {
                SettingRow(symbol: "heart", title: Text("Acknowledgements")) { RowGlyph(symbol: "chevron.right") }
            }
            .buttonStyle(RowButtonStyle())
            RowDivider()
            Button(role: .destructive) { confirmClear = true } label: {
                SettingRow(symbol: "trash", title: Text("Clear practice history"), tint: Palette.danger, titleColor: Palette.danger)
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    static let languages = ["ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "fa", "fi", "fr", "gu", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "kn", "ko", "lt", "lv", "ml", "mr", "nl", "no", "pa", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "sw", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-CN", "zu"]
}

// MARK: - Card parts

/// One settings card: an eyebrow header, the rows on a raised surface, and a small grey footer.
private struct SettingsGroup<Content: View>: View {
    var title: LocalizedStringKey?
    var footer: Text?
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Eyebrow(title).padding(.horizontal, 6).accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                .stillCard(padding: 0, tint: tint)
            if let footer {
                footer
                    .font(.footnote).foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// An icon orb and a title: the leading half of every row (and the label of toggles, steppers and pickers).
private struct RowLabel: View {
    let symbol: String
    let title: Text
    var tint: Color = Palette.mint
    var titleColor: Color = Palette.ink

    var body: some View {
        HStack(spacing: 12) {
            IconOrb(symbol: symbol, tint: tint, size: 30)
            title.font(.body).foregroundStyle(titleColor).multilineTextAlignment(.leading)
        }
    }
}

/// A full row: label, then an optional trailing glyph or control.
private struct SettingRow<Trailing: View>: View {
    let symbol: String
    let title: Text
    var tint: Color = Palette.mint
    var titleColor: Color = Palette.ink
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            RowLabel(symbol: symbol, title: title, tint: tint, titleColor: titleColor)
            Spacer(minLength: 8)
            trailing
        }
        .settingsRow()
        .contentShape(Rectangle())
    }
}

extension SettingRow where Trailing == EmptyView {
    init(symbol: String, title: Text, tint: Color = Palette.mint, titleColor: Color = Palette.ink) {
        self.init(symbol: symbol, title: title, tint: tint, titleColor: titleColor) { EmptyView() }
    }
}

/// A row whose value is picked from a menu, shown in mint at the trailing edge.
private struct MenuRow<Selection: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    let id: String
    @Binding var selection: Selection
    @ViewBuilder var options: Options

    var body: some View {
        HStack(spacing: 12) {
            RowLabel(symbol: symbol, title: Text(title))
            Spacer(minLength: 8)
            Picker(title, selection: $selection) { options }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier(id)
        }
        .settingsRow()
    }
}

/// Four strings, thin to thick from the top (tab order) or the other way round (mirror), in the orb column.
private struct StringOrderGlyph: View {
    let thinnestOnTop: Bool
    let lit: Bool

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                Capsule().fill(lit ? Palette.mint : Palette.inkSoft)
                    .frame(width: 22, height: 1 + 0.9 * CGFloat(thinnestOnTop ? row : 3 - row))
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// Chevron or arrow at the end of a navigating row.
private struct RowGlyph: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.inkFaint)
            .accessibilityHidden(true)
    }
}

/// Hairline between rows, inset to line up with the titles (never full width).
private struct RowDivider: View {
    /// Row padding + icon orb + spacing.
    static let inset: CGFloat = 16 + 30 + 12
    var body: some View {
        Divider().overlay(Palette.line).padding(.leading, Self.inset)
    }
}

/// Rows that act as buttons light up softly under the finger.
private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.05 : 0))
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

private extension View {
    /// Padding and height shared by every settings row.
    func settingsRow() -> some View {
        padding(.horizontal, 16).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }
}

// MARK: - Sub-pages

private struct AdvancedListening: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            SettingsGroup(footer: Text("Strict confidence asks for a clearer note before showing a reading. Larger windows read lower notes with a little more delay.")) {
                VStack(alignment: .leading, spacing: 8) {
                    RowLabel(symbol: "mic", title: Text("Microphone sensitivity: \(store.settings.micSensitivity)%"))
                    Slider(value: Binding(get: { Double(store.settings.micSensitivity) }, set: { v in store.updateSettings { $0.micSensitivity = Int(v.rounded()) } }), in: 0...100, step: 1)
                        .padding(.leading, RowDivider.inset - 16)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                RowDivider()
                MenuRow(title: "Confidence", symbol: "checkmark.circle", id: "settings.confidence",
                        selection: Binding(get: { store.settings.confidenceThreshold }, set: { v in store.updateSettings { $0.confidenceThreshold = v } })) {
                    Text("Responsive").tag(0.60); Text("Balanced").tag(0.75); Text("Strict").tag(0.90)
                }
                RowDivider()
                MenuRow(title: "Analysis window", symbol: "waveform", id: "settings.window",
                        selection: Binding(get: { store.settings.analysisWindowOverride }, set: { v in store.updateSettings { $0.analysisWindowOverride = v } })) {
                    Text("Automatic").tag(Int?.none)
                    ForEach([2048, 4096, 8192], id: \.self) { Text("\($0) samples").tag(Optional($0)) }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Advanced listening")
    }
}

private struct Acknowledgements: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SettingsGroup(title: "Fonts") { license("Sora", file: "Sora-OFL") }
                SettingsGroup(title: "Music") {
                    Text("The song exercise uses a phrase from Beethoven's public-domain Ode to Joy.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                SettingsGroup(title: "Instruments", footer: Text("Instruments without a credit are modelled and rendered from code for Timbre.")) {
                    ForEach(Array(ModelLibrary.credits().enumerated()), id: \.element.id) { index, credit in
                        if index > 0 { Divider().overlay(Palette.line).padding(.leading, 16) }
                        VStack(alignment: .leading, spacing: 4) {
                            Link(destination: credit.link) { Text("“\(credit.title)” by \(credit.author)").font(.subheadline.weight(.semibold)) }
                            Text("\(credit.licenseName) · rigged, relit and rendered for Timbre").font(.caption).foregroundStyle(Palette.inkSoft)
                            if let licence = credit.licenseLink { Link("Licence", destination: licence).font(.caption) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Acknowledgements")
    }

    private func license(_ name: String, file: String) -> some View {
        NavigationLink {
            ScrollView {
                Text((Bundle.main.url(forResource: file, withExtension: "txt")).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "SIL Open Font License 1.1")
                    .font(.footnote.monospaced()).foregroundStyle(Palette.inkSoft).textSelection(.enabled).padding()
            }
            .background(StageBackground(motes: false))
            .navigationTitle(name)
        } label: {
            SettingRow(symbol: "textformat", title: Text(verbatim: name)) { RowGlyph(symbol: "chevron.right") }
        }
        .buttonStyle(RowButtonStyle())
    }
}
