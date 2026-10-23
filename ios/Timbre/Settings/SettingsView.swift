import StoreKit
import SwiftUI
import TimbreCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @State private var referenceInput = ""
    @State private var confirmClear = false
    @State private var manageSubscriptions = false
    @FocusState private var referenceFocused: Bool

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
            Form {
                membership
                tuningSection
                displaySection
                Section("Feedback") {
                    Toggle("Haptics", isOn: setting(\.hapticsEnabled))
                    Picker("Stage", selection: Binding(get: { store.settings.stageMode ?? "3d" }, set: { v in store.updateSettings { $0.stageMode = v } })) {
                        Text("Real-time 3D").tag("3d"); Text("Studio (lighter)").tag("studio")
                    }
                }
                NavigationLink("Advanced listening") { AdvancedListening() }
                languageSection
                privacySection
            }
            .scrollContentBackground(.hidden)
            .background(StageBackground(motes: false))
            .tint(Palette.brass)
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
    }

    private var membership: some View {
        Section {
            if commerce.isPro {
                Label { VStack(alignment: .leading, spacing: 2) {
                    Text("Timbre Pro is active").font(.headline)
                    if let date = commerce.renewalDate { Text("Renews \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(Palette.inkSoft) }
                    else if commerce.activeProductID == TimbreProduct.lifetime { Text("Lifetime").font(.caption).foregroundStyle(Palette.inkSoft) }
                } } icon: { Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.brass) }
                if commerce.activeProductID != TimbreProduct.lifetime { Button("Manage subscription") { manageSubscriptions = true } }
            } else {
                Button { dismiss(); store.presentPaywall("settings") } label: {
                    FeatureRow(symbol: "sparkles", title: "Try Timbre Pro", detail: "Every instrument in 3D, strobe precision and daily practice.") { ProBadge() }
                }
                .buttonStyle(.plain)
            }
            Button("Restore purchases") { Task { await commerce.restore() } }
        }
    }

    private var tuningSection: some View {
        Section {
            HStack {
                Text("A4")
                Spacer()
                TextField("440", text: $referenceInput).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($referenceFocused).frame(width: 90)
                    .accessibilityIdentifier("settings.referenceInput")
                Text("Hz").foregroundStyle(Palette.inkSoft)
            }
            if parsedReference == nil { Text("Enter a value from 415 to 466 Hz.").font(.caption).foregroundStyle(Palette.danger) }
            else if parsedReference != store.settings.referencePitchHz {
                Button("Apply \(referenceInput) Hz") { referenceFocused = false; if let v = parsedReference { store.updateSettings { $0.referencePitchHz = v } } }
                    .accessibilityIdentifier("settings.applyReference")
            }
            Picker("Temperament", selection: Binding(get: { store.settings.temperamentId }, set: { value in
                if value != "equal" && !commerce.isPro { store.presentPaywall("temperament"); return }
                store.updateSettings { $0.temperamentId = value }
            })) { ForEach(Temperament.all) { Text($0.name).tag($0.id) } }
            Picker("Note names", selection: setting(\.notation)) {
                Text("Letters").tag("english"); Text("Solfège").tag("solfege"); Text("Sargam").tag("sargam"); Text("Numbers").tag("numbered")
            }
            Stepper("Capo: \(store.settings.capo)", value: Binding(get: { store.settings.capo }, set: { v in
                guard commerce.isPro || v == 0 else { store.presentPaywall("capo"); return }
                store.updateSettings { $0.capo = v }
            }), in: 0...12)
            Stepper("Transpose: \(store.settings.transposition)", value: Binding(get: { store.settings.transposition }, set: { v in
                guard commerce.isPro || v == 0 else { store.presentPaywall("transpose"); return }
                store.updateSettings { $0.transposition = v }
            }), in: -12...12)
        } header: { Text("Tuning") } footer: { Text("Capo and transposition change the names you see, never the pitch Timbre measures.") }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Appearance", selection: setting(\.theme)) {
                Text("Dark").tag("dark"); Text("Light").tag("light"); Text("System").tag("system")
            }
            .accessibilityIdentifier("settings.theme")
            Picker("Handedness", selection: setting(\.handedness)) { Text("Right-handed").tag("right"); Text("Left-handed").tag("left") }
        }
    }

    private var languageSection: some View {
        Section("Language") {
            Picker("App language", selection: setting(\.language)) {
                Text("System default").tag("system")
                ForEach(Self.languages, id: \.self) { code in
                    Text(Locale(identifier: code).localizedString(forIdentifier: code)?.localizedCapitalized ?? code).tag(code)
                }
            }
            .accessibilityIdentifier("settings.language")
        }
    }

    private var privacySection: some View {
        Section {
            Label("Microphone audio is analysed on this device. Recordings are never saved or uploaded.", systemImage: "lock.shield.fill")
                .font(.subheadline).foregroundStyle(Palette.inkSoft)
            Link("Privacy policy", destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!)
            NavigationLink("Acknowledgements") { Acknowledgements() }
            Button("Clear practice history", role: .destructive) { confirmClear = true }
        } header: { Text("Privacy") } footer: {
            Text("Timbre \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
        }
    }

    static let languages = ["ar", "bg", "bn", "ca", "cs", "da", "de", "el", "en", "es", "et", "fa", "fi", "fr", "gu", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "kn", "ko", "lt", "lv", "ml", "mr", "nl", "no", "pa", "pl", "pt", "ro", "ru", "sk", "sl", "sv", "sw", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-CN", "zu"]
}

private struct AdvancedListening: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("Microphone sensitivity: \(store.settings.micSensitivity)%")
                    Slider(value: Binding(get: { Double(store.settings.micSensitivity) }, set: { v in store.updateSettings { $0.micSensitivity = Int(v.rounded()) } }), in: 0...100, step: 1)
                }
                Picker("Confidence", selection: Binding(get: { store.settings.confidenceThreshold }, set: { v in store.updateSettings { $0.confidenceThreshold = v } })) {
                    Text("Responsive").tag(0.60); Text("Balanced").tag(0.75); Text("Strict").tag(0.90)
                }
                Picker("Analysis window", selection: Binding(get: { store.settings.analysisWindowOverride }, set: { v in store.updateSettings { $0.analysisWindowOverride = v } })) {
                    Text("Automatic").tag(Int?.none)
                    ForEach([2048, 4096, 8192], id: \.self) { Text("\($0) samples").tag(Optional($0)) }
                }
            } footer: { Text("Strict confidence asks for a clearer note before showing a reading. Larger windows read lower notes with a little more delay.") }
        }
        .scrollContentBackground(.hidden)
        .background(StageBackground(motes: false))
        .navigationTitle("Advanced listening")
    }
}

private struct Acknowledgements: View {
    var body: some View {
        List {
            Section("Fonts") {
                license("Instrument Serif", file: "InstrumentSerif-OFL")
                license("IBM Plex Mono", file: "IBMPlexMono-OFL")
            }
            Section("Music") { Text("The song exercise uses a phrase from Beethoven's public-domain Ode to Joy.") }
            Section("Instruments") { Text("3D instruments, materials and renders are generated from code for Timbre.") }
        }
        .scrollContentBackground(.hidden)
        .background(StageBackground(motes: false))
        .navigationTitle("Acknowledgements")
    }
    private func license(_ name: String, file: String) -> some View {
        NavigationLink(name) {
            ScrollView {
                Text((Bundle.main.url(forResource: file, withExtension: "txt")).flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "SIL Open Font License 1.1")
                    .font(.footnote.monospaced()).textSelection(.enabled).padding()
            }
            .navigationTitle(name)
        }
    }
}
