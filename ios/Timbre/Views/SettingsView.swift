import SwiftUI
import TimbreCore

@MainActor
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @EnvironmentObject private var ads: AdvertisingService
    @State private var referenceInput = ""
    @State private var confirmClear = false
    @State private var showAbout = false

    private func text(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, value: fallback, comment: "")
    }
    private func setting<Value>(_ keyPath: WritableKeyPath<UserSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { value in
            store.updateSettings { $0[keyPath: keyPath] = value }
        })
    }
    private var parsedReference: Double? {
        guard let value = Double(referenceInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, (415...466).contains(value) else { return nil }
        return value
    }
    var body: some View {
        Form {
            accessSection
            referenceSection
            notationSection
            listeningSection
            appearanceSection
            languageSection
            privacySection
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(TimbreTheme.canvas)
        .tint(TimbreTheme.action)
        .navigationTitle(text("timbre_settings_title", "Settings"))
        .onAppear { store.stopActivity(); referenceInput = String(store.settings.referencePitchHz) }
        .onChange(of: store.settings.referencePitchHz) { _, value in referenceInput = String(value) }
        .confirmationDialog("Clear practice history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { store.clearHistory() }
            Button("timbre_about_cancel", role: .cancel) {}
        } message: { Text("This removes saved practice sessions and demonstrated voice progress from this device.") }
        .sheet(isPresented: $showAbout) { NavigationStack { aboutView } }
    }
    private var accessSection: some View {
        Section(text("timbre_settings_your_access", "Your access")) {
            Text(commerce.isPlus ? text("timbre_settings_full_access_active", "Full access is active.") : text("timbre_settings_free_access_detail", "Three instruments are available without a purchase. One purchase opens the full collection, singing practice and Studio."))
                .foregroundStyle(TimbreTheme.secondary)
            Button(commerce.isPlus ? text("timbre_settings_purchase_restore", "Purchase and restore") : text("timbre_settings_explore_unlock", "Explore the full unlock")) { store.showPlus = true }
            if let error = store.error { Text(error).foregroundStyle(.red).accessibilityLabel("Not saved: \(error)") }
        }
    }
    private var referenceSection: some View {
        Section(text("timbre_settings_reference_pitch", "Reference pitch")) {
            Text("A4 = \(store.settings.referencePitchHz, specifier: "%.1f") Hz").font(.headline)
            Text(text("timbre_settings_reference_pitch_detail", "Choose a concert pitch or enter a value from 415 to 466 Hz."))
                .font(.footnote).foregroundStyle(TimbreTheme.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 8) {
                ForEach([415.0, 432, 435, 440, 442], id: \.self) { hz in
                    Button(String(Int(hz))) { store.updateSettings { $0.referencePitchHz = hz } }
                        .buttonStyle(.bordered)
                        .tint(store.settings.referencePitchHz == hz ? TimbreTheme.brass : .secondary)
                        .accessibilityLabel("A4 \(Int(hz)) hertz")
                }
            }
            TextField(text("timbre_settings_custom_a4", "Custom A4 (Hz)"), text: $referenceInput)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("settings.referenceInput")
            if parsedReference == nil {
                Text(text("timbre_settings_a4_input_hint", "Enter a number from 415 to 466 Hz.")).font(.caption).foregroundStyle(.red)
            }
            Button(text("timbre_settings_apply_reference", "Apply reference pitch")) {
                if let value = parsedReference { store.updateSettings { $0.referencePitchHz = value } }
            }.disabled(parsedReference == nil || parsedReference == store.settings.referencePitchHz)
                .accessibilityIdentifier("settings.applyReference")
            Picker("Temperament", selection: setting(\.temperamentId)) {
                ForEach(Temperament.all) { temperament in Text(temperament.name).tag(temperament.id) }
            }
            if store.settings.temperamentId != "equal" {
                Text("Historical presets use the same approximate offset tables as Timbre for Android.").font(.caption).foregroundStyle(TimbreTheme.secondary)
            }
        }
    }
    private var notationSection: some View {
        Section(text("timbre_settings_note_names", "Note names")) {
            Picker(text("timbre_settings_note_names", "Note names"), selection: setting(\.notation)) {
                Text(text("timbre_settings_letters", "Letters")).tag("english")
                Text(text("timbre_settings_solfege", "Solfège")).tag("solfege")
                Text(text("timbre_settings_sargam", "Sargam")).tag("sargam")
                Text(text("timbre_settings_numbers", "Numbers")).tag("numbered")
            }
            Text(text("timbre_settings_written_pitch_detail", "Change displayed names for transposing instruments or capo shapes. Measured pitch and tuning frequency stay unchanged."))
                .font(.footnote).foregroundStyle(TimbreTheme.secondary)
            if commerce.isPlus {
                Stepper(value: setting(\.transposition), in: -12...12) {
                    Text("\(text("timbre_settings_transposition_semitones", "Transposition (semitones)")): \(store.settings.transposition)")
                }
                Stepper(value: setting(\.capo), in: 0...12) {
                    Text("\(text("timbre_settings_capo_fret", "Capo fret")): \(store.settings.capo)")
                }
            } else {
                Button(text("timbre_settings_unlock_written_pitch", "Unlock written pitch")) { store.showPlus = true }
                if store.settings.transposition != 0 || store.settings.capo != 0 {
                    Button(text("timbre_settings_reset_written_pitch", "Reset written pitch")) { store.updateSettings { $0.transposition = 0; $0.capo = 0 } }
                }
            }
        }
    }
    private var listeningSection: some View {
        Section(text("timbre_settings_listening", "Listening")) {
            VStack(alignment: .leading) {
                Text("Microphone sensitivity: \(store.settings.micSensitivity)%")
                Slider(value: Binding(get: { Double(store.settings.micSensitivity) }, set: { value in store.updateSettings { $0.micSensitivity = Int(value.rounded()) } }), in: 0...100, step: 1)
                    .accessibilityLabel("Microphone sensitivity")
            }
            Picker(text("timbre_settings_confidence_threshold", "Confidence threshold"), selection: setting(\.confidenceThreshold)) {
                Text(text("timbre_settings_responsive", "Responsive")).tag(0.60)
                Text(text("timbre_settings_balanced", "Balanced")).tag(0.75)
                Text(text("timbre_settings_strict", "Strict")).tag(0.90)
            }
            Text(text("timbre_settings_confidence_detail", "A higher threshold asks for a clearer note before showing a reading."))
                .font(.footnote).foregroundStyle(TimbreTheme.secondary)
            Picker("Analysis window", selection: setting(\.analysisWindowOverride)) {
                Text("Automatic").tag(Int?.none)
                ForEach([2048, 4096, 8192], id: \.self) { size in Text("\(size) samples").tag(Optional(size)) }
            }
            Text("Larger windows can detect lower notes with more delay.").font(.caption).foregroundStyle(TimbreTheme.secondary)
        }
    }
    private var appearanceSection: some View {
        Section(text("timbre_settings_appearance_feedback", "Appearance and feedback")) {
            Picker("Theme", selection: setting(\.theme)) {
                Text(text("timbre_settings_theme_dark", "Dark")).tag("dark")
                Text(text("timbre_settings_theme_light", "Light")).tag("light")
                Text(text("timbre_settings_theme_system", "System")).tag("system")
            }
            .accessibilityIdentifier("settings.theme")
            .accessibilityValue(store.settings.theme)
            Picker("Handedness", selection: setting(\.handedness)) {
                Text("Right-handed").tag("right"); Text("Left-handed").tag("left")
            }
            Toggle(text("timbre_settings_in_tune_vibration", "In-tune vibration"), isOn: setting(\.hapticsEnabled))
            Toggle(text("timbre_settings_reduce_motion", "Reduce motion"), isOn: setting(\.reducedMotion))
        }
    }
    private var languageSection: some View {
        Section(text("timbre_settings_app_language", "App language")) {
            Picker(text("timbre_settings_language_choose", "Choose language"), selection: setting(\.language)) {
                Text(text("timbre_settings_language_system", "System default")).tag("system")
                ForEach(Self.languages, id: \.self) { code in
                    Text(Locale(identifier: code).localizedString(forIdentifier: code)?.localizedCapitalized ?? code).tag(code)
                }
            }
            .accessibilityIdentifier("settings.language")
        }
    }
    private var privacySection: some View {
        Section(text("timbre_settings_privacy", "Privacy")) {
            Text(text("timbre_settings_on_device_privacy_detail", "Microphone audio is analysed on this device. Recordings are not saved or uploaded."))
            Text("Practice summaries and preferences stay on this device. Apple handles purchases through the App Store.").font(.footnote).foregroundStyle(TimbreTheme.secondary)
            Button(text("timbre_settings_about_app_privacy", "About the app and privacy")) { showAbout = true }
            if ads.privacyOptionsRequired { Button("timbre_settings_ad_privacy") { Task { await ads.presentPrivacyOptions() } } }
            Button("Clear practice history", role: .destructive) { confirmClear = true }
        }
    }
    private var aboutView: some View {
        List {
            Section("timbre_app_name") {
                Text("An instrument tuner, vocal practice companion and metronome.")
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
            }
            Section("timbre_settings_privacy") {
                Text("Audio is processed on your device. Timbre does not save microphone recordings or send audio to a server. Local practice records contain dates, instrument selections and measured summaries. Clear history in Settings to remove those records.")
                Text("Purchases and restoration use Apple StoreKit. When advertising is configured, eligible free sessions may show ads after consent requirements are resolved. Ad privacy choices are available in Settings.")
                Link("Privacy policy", destination: URL(string: "https://github.com/azerish25-ux/tuner/blob/main/docs/ios/PRIVACY.md")!)
            }
            Section("Open-source fonts") {
                fontLicense("Inter", file: "Inter-OFL")
                fontLicense("Space Grotesk", file: "SpaceGrotesk-OFL")
                fontLicense("IBM Plex Mono", file: "IBMPlexMono-OFL")
            }
            Section("Music") { Text("The short song exercise uses a transposed phrase from Beethoven’s public-domain Ode to Joy.") }
        }
        .navigationTitle("About Timbre")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAbout = false } } }
    }
    private func fontLicense(_ name: String, file: String) -> some View {
        NavigationLink(name) {
            ScrollView { Text(license(file)).font(.footnote.monospaced()).textSelection(.enabled).padding() }
                .navigationTitle(name)
        }
    }
    private func license(_ file: String) -> String {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt", subdirectory: "Fonts") ?? Bundle.main.url(forResource: file, withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return "SIL Open Font License 1.1. License text is unavailable in this installation." }
        return content
    }
    private static let languages = ["ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "fa", "fi", "fr", "gu", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "kn", "ko", "lt", "lv", "ml", "mr", "nl", "no", "pa", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "sw", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-CN", "zu"]
}
