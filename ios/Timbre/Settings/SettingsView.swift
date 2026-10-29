import StoreKit
import SwiftUI
import TimbreCore

/// Settings in the Studio Noir card style: each group is a raised card under a small-capitals section header, every row
/// starts with a bare glyph in a fixed column (no discs), separators are inset to the titles, and footers sit small
/// and grey below their card.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var referenceInput = ""
    @State private var confirmClear = false
    @State private var manageSubscriptions = false
    /// The feel test is playing.
    @State private var feeling = false
    @FocusState private var referenceFocused: Bool
    @AppStorage(TuneView.strobeKey) private var strobeView = false
    /// The player has chosen Tune by feel for themselves (`TuneByFeel.chosenKey`).
    @AppStorage(TuneByFeel.chosenKey) private var feelChosen = false

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
                    feelSection
                    reminderSection
                    listeningSection
                    languageSection
                    privacySection
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("settings.scroll")
            .scrollDismissesKeyboard(.interactively)
            .stageTopShade()
            .background(StageBackground(motes: false))
            .tint(Palette.mint)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("settings.done")
                }
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
        SettingsGroup {
            if commerce.isPro {
                proStatus
                if commerce.activeProductID != TimbreProduct.lifetime {
                    Hairline(leading: SettingsRowMetrics.inset)
                    Button { manageSubscriptions = true } label: {
                        SettingRow(icon: Glyph("creditcard"), title: Text("Manage subscription")) { RowGlyph(symbol: "chevron.right") }
                    }
                    .buttonStyle(RowButtonStyle())
                }
                // "Give a friend a month", once the owner has set up the offer (`ShareDestination.friendOffer`).
                if ShareDestination.friendOffer != nil {
                    Hairline(leading: SettingsRowMetrics.inset)
                    FriendOfferLink(screen: "settings")
                        .settingsRow()
                }
            } else {
                Button { store.presentPaywall("settings") } label: {
                    FeatureRow(symbol: "sparkles", title: "Try Timbre Pro", detail: "Every lesson and song, every tuning and tool.") { ProBadge() }
                        .padding(16)
                }
                .buttonStyle(RowButtonStyle())
                .accessibilityIdentifier("settings.pro")
            }
            Hairline(leading: SettingsRowMetrics.inset)
            Button { Task { await commerce.restore() } } label: {
                SettingRow(icon: Glyph("arrow.clockwise"), title: Text("Restore purchases"))
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    private var proStatus: some View {
        HStack(spacing: 12) {
            Glyph("checkmark.seal", tint: Palette.mint)
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

    /// How the tuner reads and tells: Tune by feel first (the tuner's own way to tune without looking), then the
    /// reference, the temperament, the lock's precision, the strobe and the names it shows.
    private var tuningSection: some View {
        SettingsGroup(title: "Tuning", footer: Text("Tune by feel pulses at the beat between the string and its note, slower as they meet, still at the lock.")
                        + Text(verbatim: " ")
                        + Text("Capo and transposition change the names you see, never the pitch Timbre measures.")) {
            tuneByFeelToggle
            Hairline(leading: SettingsRowMetrics.inset)
            referenceRow
            Hairline(leading: SettingsRowMetrics.inset)
            temperamentPicker
            Hairline(leading: SettingsRowMetrics.inset)
            precisionPicker
            Hairline(leading: SettingsRowMetrics.inset)
            strobeToggle
            Hairline(leading: SettingsRowMetrics.inset)
            notationPicker
            Hairline(leading: SettingsRowMetrics.inset)
            capoStepper
            Hairline(leading: SettingsRowMetrics.inset)
            transposeStepper
        }
    }

    private var temperamentPicker: some View {
        MenuRow(title: "Temperament", icon: Glyph(.temperament), id: "settings.temperament", selection: Binding(get: { store.settings.temperamentId }, set: { value in
            if value != "equal" && !commerce.isPro && !FreeTier.opens(.temperaments) { store.presentPaywall("temperament"); return }
            store.updateSettings { $0.temperamentId = value }
        })) { ForEach(Temperament.all) { Text(verbatim: SettingsOptionLabel.temperamentName($0)).tag($0.id) } }
    }

    /// The phone throbs at the beat between the string and its note (`Haptics`), so a string can be tuned by touch. It
    /// needs haptics on (Feedback, below). It shows Tune by feel as it is in effect (on while VoiceOver runs until the
    /// player chooses), and flipping it is the player's choice, as on the tuner.
    private var tuneByFeelToggle: some View {
        Toggle(isOn: TuneByFeel.binding(store, voiceOver: voiceOver)) { RowLabel(icon: Glyph("hand.tap"), title: Text("Tune by feel")) }
            .settingsRow()
            .disabled(!store.settings.hapticsEnabled)
            .accessibilityIdentifier("settings.tuneByFeel")
    }

    private var strobeToggle: some View {
        Toggle(isOn: Binding(get: { strobeView }, set: { on in
            if on && !commerce.isPro && !FreeTier.opens(.strobe) { store.presentPaywall("precision"); return }
            strobeView = on
        })) { RowLabel(icon: Glyph("circle.dotted"), title: Text("Strobe precision")) }
        .settingsRow()
        .accessibilityIdentifier("settings.strobe")
    }

    /// Free on every plan: a capo only renames what you see.
    private var capoStepper: some View {
        let capo = store.settings.capo
        return Stepper(value: setting(\.capo), in: 0...12) {
            StepperRowLabel(icon: Glyph(.capo), title: Text("Capo"), value: Self.capoValue(capo), amount: capo)
        }
        .settingsRow()
        .accessibilityValue(Self.capoValue(capo))
        .accessibilityIdentifier("settings.capo")
    }

    /// Free on every plan, as the capo is.
    private var transposeStepper: some View {
        let semitones = store.settings.transposition
        return Stepper(value: setting(\.transposition), in: -12...12) {
            StepperRowLabel(icon: Glyph("arrow.up.arrow.down"), title: Text("Transpose"), value: Self.transposeValue(semitones), amount: semitones)
        }
        .settingsRow()
        .accessibilityValue(Self.transposeValue(semitones))
        .accessibilityIdentifier("settings.transpose")
    }

    /// The capo's fret, or Off without one.
    private static func capoValue(_ fret: Int) -> Text {
        fret == 0 ? Text("Off") : Text(verbatim: "\(fret)")
    }

    /// Semitones with their sign (+2, 0, −3; a true minus sign).
    private static func transposeValue(_ semitones: Int) -> Text {
        Text(verbatim: semitones > 0 ? "+\(semitones)" : (semitones < 0 ? "\u{2212}\(-semitones)" : "0"))
    }

    /// A4 in hertz: typed, checked against 415–466 Hz, and applied on demand.
    private var referenceRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RowLabel(icon: Glyph("tuningfork"), title: Text("A4"))
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    TextField("440", text: $referenceInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($referenceFocused)
                        .font(Typeface.number(.headline))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 72)
                        .accessibilityIdentifier("settings.referenceInput")
                    Text("Hz").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(referenceFocused ? Palette.mint.opacity(0.6) : Palette.controlLine, lineWidth: 1))
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
                .padding(.leading, SettingsRowMetrics.inset).padding(.trailing, 16).padding(.bottom, 12)
        } else if parsedReference != store.settings.referencePitchHz {
            Button("Apply \(referenceInput) Hz") { referenceFocused = false; if let v = parsedReference { store.updateSettings { $0.referencePitchHz = v } } }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(TextLinkStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, SettingsRowMetrics.inset).padding(.trailing, 16).padding(.bottom, 4)
                .accessibilityIdentifier("settings.applyReference")
        }
    }

    /// How close a string must hold to lock: Beginner ±5¢ (the original), Standard ±3¢, Expert ±1¢ (Timbre Pro).
    /// The tracker, the colours and the meter's green zone all follow it.
    private var precisionPicker: some View {
        MenuRow(title: "Precision", icon: Glyph("scope"), id: "settings.precision", selection: Binding(get: { store.settings.precision }, set: { value in
            if value == .pro && !commerce.isPro { store.presentPaywall("precision"); return }
            store.updateSettings { $0.precision = value }
        })) {
            ForEach(TuningPrecision.allCases, id: \.self) { precision in
                (Self.precisionName(precision) + Text(verbatim: " " + SettingsOptionLabel.precisionTolerance(precision))).tag(precision)
            }
        }
    }

    private static func precisionName(_ precision: TuningPrecision) -> Text {
        switch precision {
        case .beginner: return Text("Beginner")
        case .standard: return Text("Standard")
        // "Expert", not "Pro": the level is a Timbre Pro feature, so "Pro" read as the plan, not the precision.
        case .pro: return Text("Expert")
        }
    }

    /// Letters, German letters (B natural is H, B flat is B), solfège, sargam or numbers. Picking one here
    /// fixes it; until then it follows the app language.
    private var notationPicker: some View {
        MenuRow(title: "Note names", icon: Glyph("textformat.abc"), id: "settings.notation", selection: Binding(get: { store.settings.notation }, set: { value in
            store.updateSettings { $0.notation = value; $0.notationChosen = true }
        })) {
            Text("Letters").tag("english")
            Text("German (H)").tag("german")
            Text("Solfège").tag("solfege")
            Text("Sargam").tag("sargam")
            Text("Numbers").tag("numbered")
        }
    }

    // MARK: Display

    /// How every neck and chord is drawn (`ChordPicture`): the very value the Chart / Player view switch on a chord
    /// card flips (`StringOrder` reads it too), so this row and that switch can never disagree.
    @AppStorage(ChordPicture.storageKey) private var chordPicture: ChordPicture = .chart

    private var displaySection: some View {
        SettingsGroup(title: "Display", footer: Text("Simple tuner shows the tuner on its own. Calm mode leaves out XP, levels, quests and streaks; your stars and badges stay.")) {
            handednessPicker
            if store.settings.handedness != .right {
                Hairline(leading: SettingsRowMetrics.inset)
                Toggle(isOn: setting(\.chartsAsPrinted)) { RowLabel(icon: Glyph("doc.plaintext"), title: Text("Charts as printed")) }
                    .settingsRow()
                    .accessibilityIdentifier("settings.chartsAsPrinted")
                    .transition(.opacity)
            }
            Hairline(leading: SettingsRowMetrics.inset)
            stringOrderChoice
            Hairline(leading: SettingsRowMetrics.inset)
            Toggle(isOn: setting(\.simpleTuner)) { RowLabel(icon: Glyph("eye.slash"), title: Text("Simple tuner")) }
                .settingsRow()
                .accessibilityIdentifier("settings.simpleTuner")
            Hairline(leading: SettingsRowMetrics.inset)
            Toggle(isOn: setting(\.calmMode)) { RowLabel(icon: Glyph("leaf"), title: Text("Calm mode")) }
                .settingsRow()
                .accessibilityIdentifier("settings.calmMode")
        }
        .animation(Motion.settle, value: store.settings.handedness)
    }

    /// Right-handed, left-handed, or left-handed on a right-handed instrument turned over (the thinnest string on top).
    private var handednessPicker: some View {
        MenuRow(title: "Handedness", icon: Glyph("hand.raised"), id: "settings.handedness", selection: setting(\.handedness)) {
            Text("Right-handed").tag(Handedness.right)
            Text("Left-handed").tag(Handedness.left)
            Text("Left-handed, strung upside down").tag(Handedness.leftUpsideDown)
        }
    }

    /// "String order" and its two options, Chart and Player view, each with a small picture of the strings in that
    /// order, what it means in a line under its name, and a check on the chosen one (too long for a menu).
    private var stringOrderChoice: some View {
        VStack(spacing: 0) {
            RowLabel(icon: Glyph("list.number"), title: Text("String order"))
                .settingsRow()
                .accessibilityAddTraits(.isHeader)
            ForEach(ChordPicture.allCases) { picture in
                Hairline(leading: SettingsRowMetrics.inset)
                stringOrderOption(picture)
            }
        }
    }

    private func stringOrderOption(_ picture: ChordPicture) -> some View {
        let selected = chordPicture == picture
        let order = picture.stringOrder
        return Button {
            chordPicture = picture
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 12) {
                StringOrderGlyph(thinnestOnTop: order.thinnestOnTop, lit: selected)
                VStack(alignment: .leading, spacing: 2) {
                    Text(picture.title).font(.body).foregroundStyle(Palette.ink)
                    Text(picture.detail).font(.footnote).foregroundStyle(Palette.inkSoft)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
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
        // The ids the option rows have always had: tab for Chart, mirror for Player view.
        .accessibilityIdentifier("settings.stringOrder.\(order == .tab ? "tab" : "mirror")")
    }

    // MARK: Feel

    private var feelSection: some View {
        SettingsGroup(title: "Feedback") {
            Toggle(isOn: setting(\.hapticsEnabled)) { RowLabel(icon: Glyph("iphone.radiowaves.left.and.right"), title: Text("Haptics")) }
                .settingsRow()
            Hairline(leading: SettingsRowMetrics.inset)
            Toggle(isOn: setting(\.feelTheBeat)) { RowLabel(icon: Glyph("metronome"), title: Text("Feel the beat")) }
                .settingsRow()
                .disabled(!store.settings.hapticsEnabled)
                .accessibilityIdentifier("settings.feelTheBeat")
            Hairline(leading: SettingsRowMetrics.inset)
            feelTest
            Hairline(leading: SettingsRowMetrics.inset)
            MenuRow(title: "Stage", icon: Glyph("cube.transparent"), id: "settings.stage",
                    selection: Binding(get: { store.settings.stageMode ?? "3d" }, set: { v in store.updateSettings { $0.stageMode = v } })) {
                Text("Real-time 3D").tag("3d"); Text("Studio (lighter)").tag("studio")
            }
        }
    }

    /// Plays the tuner's feel on the phone as the tuner would: with Tune by feel, the beat slowing to the lock
    /// (`Haptics.feelTest`); without it, a detent a cent at a time toward the note, then the lock. If nothing is felt,
    /// the phone's haptics are off (Settings › Sounds & Haptics) or this phone has none.
    private var feelTest: some View {
        Button { runFeelTest() } label: {
            SettingRow(icon: Glyph("waveform.path"), title: Text("Feel test")) {
                Text("Play").font(.subheadline.weight(.semibold)).foregroundStyle(feeling ? Palette.inkFaint : Palette.mint)
            }
        }
        .buttonStyle(RowButtonStyle())
        .disabled(feeling || !store.settings.hapticsEnabled)
        .accessibilityHint(feelOn ? Text("Plays the beat slowing to the lock") : Text("Plays the tuner's detents, then the lock"))
        .accessibilityIdentifier("settings.feelTest")
    }

    /// Tune by feel as the tuner plays it now (`TuneByFeel.isOn`): the player's choice, else on while VoiceOver runs.
    private var feelOn: Bool { TuneByFeel.isOn(store.settings, voiceOver: voiceOver, chosen: feelChosen) }

    private func runFeelTest() {
        guard !feeling else { return }
        feeling = true
        let byFeel = feelOn
        Task { @MainActor in
            if byFeel {
                // About three seconds of beat, then the lock's thump.
                Haptics.shared.feelTest()
                try? await Task.sleep(for: .milliseconds(3_600))
            } else {
                await playDetents()
            }
            feeling = false
        }
    }

    /// The standard feel: detents from 5¢ to the note, then the lock.
    @MainActor private func playDetents() async {
        for cents in [5.0, 4, 3, 2, 1, 0] {
            Haptics.shared.detent(cents: cents)
            try? await Task.sleep(for: .milliseconds(240))
        }
        Haptics.shared.lock()
        try? await Task.sleep(for: .milliseconds(500))
        // Forget the last detent, so the tuner's first one fires.
        Haptics.shared.detent(cents: nil)
    }

    // MARK: Reminders

    @AppStorage(PracticeReminder.enabledKey) private var reminderOn = false
    @AppStorage(PracticeReminder.minutesKey) private var reminderMinutes = 19 * 60

    private var reminderSection: some View {
        SettingsGroup(title: "Reminders", footer: Text("One gentle nudge a day, at a time you choose.")) {
            Toggle(isOn: Binding(get: { reminderOn }, set: { on in
                if on { Task { reminderOn = await PracticeReminder.enable(at: reminderMinutes) } } else { PracticeReminder.disable(); reminderOn = false }
            })) { RowLabel(icon: Glyph("bell"), title: Text("Daily practice reminder")) }
            .settingsRow()
            .accessibilityIdentifier("settings.reminder")
            if reminderOn {
                Hairline(leading: SettingsRowMetrics.inset)
                DatePicker(selection: Binding(get: {
                    Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
                }, set: { date in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                    reminderMinutes = (parts.hour ?? 19) * 60 + (parts.minute ?? 0)
                    Task { await PracticeReminder.enable(at: reminderMinutes) }
                }), displayedComponents: .hourAndMinute) { RowLabel(icon: Glyph("clock"), title: Text("Time")) }
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
                SettingRow(icon: Glyph("ear"), title: Text("Advanced listening")) { RowGlyph(symbol: "chevron.right") }
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    /// The app's language. Picking one, "System default" included, marks the language as chosen, so it is never moved
    /// to follow the device again.
    private var languageSection: some View {
        SettingsGroup(title: "Language") {
            // Note names follow the language until the player picks a system (German reads B natural as H).
            MenuRow(title: "App language", icon: Glyph("globe"), id: "settings.language", selection: Binding(get: { store.settings.language }, set: { value in
                store.updateSettings {
                    $0.language = value
                    $0.languageChosen = true
                    $0.applyNotationDefault(systemLanguage: Locale.preferredLanguages.first)
                }
            })) {
                Text("System default").tag(TimbreLocalization.system)
                ForEach(Self.shippedLanguages, id: \.self) { code in
                    Text(Locale(identifier: code).localizedString(forIdentifier: code)?.localizedCapitalized ?? code).tag(code)
                }
            }
        }
    }

    private var privacySection: some View {
        SettingsGroup(title: "Privacy", footer: Text("Timbre \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")) {
            HStack(alignment: .top, spacing: 12) {
                Glyph("lock.shield", tint: Palette.mint)
                Text("Microphone audio is analysed on this device. Recordings are never saved or uploaded.")
                    .font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .settingsRow()
            Hairline(leading: SettingsRowMetrics.inset)
            usageToggle
            Hairline(leading: SettingsRowMetrics.inset)
            // The one address every link to the policy uses (the build's Info.plist, else the published one).
            Link(destination: AppLinks.privacy) {
                SettingRow(icon: Glyph("doc.text"), title: Text("Privacy policy")) { RowGlyph(symbol: "arrow.up.right") }
            }
            .buttonStyle(RowButtonStyle())
            Hairline(leading: SettingsRowMetrics.inset)
            NavigationLink { Acknowledgements() } label: {
                SettingRow(icon: Glyph("heart"), title: Text("Acknowledgements")) { RowGlyph(symbol: "chevron.right") }
            }
            .buttonStyle(RowButtonStyle())
            Hairline(leading: SettingsRowMetrics.inset)
            Button(role: .destructive) { confirmClear = true } label: {
                SettingRow(icon: Glyph("trash", tint: Palette.danger), title: Text("Clear practice history"), titleColor: Palette.danger)
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    /// Anonymous product events (the privacy policy's "Anonymous usage analytics"): on until the player chooses, and
    /// off, nothing more leaves the device (`Analytics.setSharing`, applied by `AppStore.updateSettings`).
    private var usageToggle: some View {
        Toggle(isOn: Binding(get: { store.settings.sharesUsage }, set: { on in store.updateSettings { $0.shareUsageData = on } })) {
            HStack(spacing: 12) {
                Glyph("chart.bar")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share anonymous usage data").font(.body).foregroundStyle(Palette.ink)
                    Text("Which features get used, never audio or anything linked to you.")
                        .font(.footnote).foregroundStyle(Palette.inkSoft)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .settingsRow()
        .accessibilityIdentifier("settings.shareUsage")
    }

    /// The languages of `languages` this build has strings for (a `.lproj` in the app bundle), so the list never offers
    /// one the app can't show.
    static let shippedLanguages = languages.filter { Bundle.main.path(forResource: $0, ofType: "lproj") != nil }

    static let languages = [
        "ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "fa", "fi",
        "fr", "gu", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "kn", "ko", "lt",
        "lv", "ml", "mr", "ms", "nl", "no", "or", "pa", "pl", "pt", "ro", "ru", "sk",
        "sl", "sv", "sw", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-CN", "zh-Hant", "zu"
    ]
}

// MARK: - Card parts

/// One settings card: a small-capitals section header (the one place capitals belong), the rows on a raised surface,
/// and a small grey footer.
private struct SettingsGroup<Content: View>: View {
    var title: LocalizedStringKey?
    var footer: Text?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Eyebrow(title, color: Palette.inkSoft, level: .section).padding(.horizontal, 6).accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                .stillCard(padding: 0)
            if let footer {
                footer
                    .font(.footnote).foregroundStyle(Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }
}

/// A glyph and a title: the leading half of every row (and the label of toggles, steppers and pickers).
private struct RowLabel: View {
    let icon: Glyph
    let title: Text
    var titleColor: Color = Palette.ink
    var titleIdentifier: String? = nil

    @ViewBuilder private var identifiedTitle: some View {
        if let titleIdentifier { title.accessibilityIdentifier(titleIdentifier) } else { title }
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
            identifiedTitle.font(.body).foregroundStyle(titleColor).multilineTextAlignment(.leading)
        }
    }
}

/// A stepper's label: the glyph and title on the leading side, the current value at the trailing end beside the − +
/// control, the way every other row shows its value. VoiceOver reads the value from the stepper itself.
private struct StepperRowLabel: View {
    let icon: Glyph
    let title: Text
    let value: Text
    /// The number behind `value`, so a step rolls its digits.
    let amount: Int

    var body: some View {
        HStack(spacing: 12) {
            RowLabel(icon: icon, title: title)
            Spacer(minLength: 8)
            value
                .font(Typeface.number(.headline))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .fixedSize()
                .contentTransition(.numericText(value: Double(amount)))
                .animation(Motion.quick, value: amount)
                .accessibilityHidden(true)
        }
    }
}

/// A full row: label, then an optional trailing glyph or control.
private struct SettingRow<Trailing: View>: View {
    let icon: Glyph
    let title: Text
    var titleColor: Color = Palette.ink
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            RowLabel(icon: icon, title: title, titleColor: titleColor)
            Spacer(minLength: 8)
            trailing
        }
        .settingsRow()
        .contentShape(Rectangle())
    }
}

extension SettingRow where Trailing == EmptyView {
    init(icon: Glyph, title: Text, titleColor: Color = Palette.ink) {
        self.init(icon: icon, title: title, titleColor: titleColor) { EmptyView() }
    }
}

/// A row whose value is picked from a menu, shown in mint at the trailing edge.
private struct MenuRow<Selection: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    let icon: Glyph
    let id: String
    @Binding var selection: Selection
    @ViewBuilder var options: Options

    var body: some View {
        HStack(spacing: 12) {
            RowLabel(icon: icon, title: Text(title), titleIdentifier: id + ".title")
            Spacer(minLength: 8)
            Picker(title, selection: $selection) { options }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier(id)
        }
        .settingsRow()
    }
}

/// Four strings, thin to thick from the top (Chart, tab order) or the other way round (Player view), in the glyph
/// column.
private struct StringOrderGlyph: View {
    let thinnestOnTop: Bool
    let lit: Bool

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                Capsule().fill(lit ? Palette.mint : Palette.inkSoft)
                    .frame(width: 20, height: 1 + 0.9 * CGFloat(thinnestOnTop ? row : 3 - row))
            }
        }
        .frame(width: Glyph.row, height: 30)
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

/// Where a row's title starts: the dividers between rows (`Hairline`) are inset to it, never full width.
private enum SettingsRowMetrics {
    /// Row padding + the glyph column + spacing.
    static let inset: CGFloat = 16 + Glyph.row + 12
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
                    HStack(spacing: 12) {
                        RowLabel(icon: Glyph("mic"), title: Text("Microphone sensitivity"))
                        Spacer(minLength: 8)
                        Text(Double(store.settings.micSensitivity) / 100, format: .percent.precision(.fractionLength(0)))
                            .font(Typeface.number(.headline)).foregroundStyle(Palette.ink)
                            .fixedSize()
                    }
                    Slider(value: Binding(get: { Double(store.settings.micSensitivity) }, set: { v in store.updateSettings { $0.micSensitivity = Int(v.rounded()) } }), in: 0...100, step: 1)
                        .padding(.leading, SettingsRowMetrics.inset - 16)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Hairline(leading: SettingsRowMetrics.inset)
                MenuRow(title: "Confidence", icon: Glyph("checkmark.circle"), id: "settings.confidence",
                        selection: Binding(get: { store.settings.confidenceThreshold }, set: { v in store.updateSettings { $0.confidenceThreshold = v } })) {
                    Text("Responsive").tag(0.60); Text("Balanced").tag(0.75); Text("Strict").tag(0.90)
                }
                Hairline(leading: SettingsRowMetrics.inset)
                MenuRow(title: "Analysis window", icon: Glyph("waveform"), id: "settings.window",
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
                        if index > 0 { Hairline(leading: 16) }
                        VStack(alignment: .leading, spacing: 4) {
                            Link(destination: credit.link) { Text("“\(credit.title)” by \(credit.author)").font(.subheadline.weight(.semibold)) }
                            Text("\(credit.licenseName) · rigged, relit and rendered for Timbre").font(.caption).foregroundStyle(Palette.inkSoft)
                            if let licence = credit.licenseLink { Link("Licence", destination: licence).font(.caption) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                if !soundCredits.isEmpty { sounds }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Acknowledgements")
    }

    /// The sample libraries the recorded instruments and the band come from (Samples/manifest.json).
    private var soundCredits: [SampleCredit] { SampleLibrary.shared?.credits ?? [] }

    private var sounds: some View {
        SettingsGroup(title: "Sounds", footer: Text("Recorded instruments, shared under CC0 by their makers.")) {
            ForEach(Array(soundCredits.enumerated()), id: \.element.id) { index, credit in
                if index > 0 { Hairline(leading: 16) }
                soundCredit(credit)
            }
        }
    }

    private func soundCredit(_ credit: SampleCredit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let link = credit.link {
                Link(destination: link) { Text(verbatim: credit.title).font(.subheadline.weight(.semibold)) }
            } else {
                Text(verbatim: credit.title).font(.subheadline.weight(.semibold))
            }
            Text(verbatim: "\(credit.author) · \(credit.licence)").font(.caption).foregroundStyle(Palette.inkSoft)
            // What Timbre plays from it ("Ukulele (nylon-string guitar recordings)"), so a stand-in says what it is.
            if !credit.instruments.isEmpty {
                Text(verbatim: credit.instruments.joined(separator: " · ")).font(.caption).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let licence = credit.licenceLink { Link("Licence", destination: licence).font(.caption) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
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
            SettingRow(icon: Glyph("textformat"), title: Text(verbatim: name)) { RowGlyph(symbol: "chevron.right") }
        }
        .buttonStyle(RowButtonStyle())
    }
}
