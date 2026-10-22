import SwiftUI
import TimbreCore

@main
struct TimbreApp: App {
    @StateObject private var bootstrap = Bootstrap()
    var body: some Scene {
        WindowGroup {
            Group {
                if let store = bootstrap.store { RootView().environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce).environmentObject(store.ads) }
                else {
                    ContentUnavailableView {
                        Label("Unable to open Timbre", systemImage: "exclamationmark.triangle")
                    } description: { Text(bootstrap.error ?? "Loading…") } actions: {
                        Button("Retry") { bootstrap.load() }
                    }
                }
            }
        }
    }
}

@MainActor
final class Bootstrap: ObservableObject {
    @Published var store: AppStore?
    @Published var error: String?
    init() { load() }
    func load() {
        do {
            var directory: URL?
            #if DEBUG
            // Separate real application state per UI test; release builds never read this value.
            if let identifier = ProcessInfo.processInfo.environment["TIMBRE_TEST_STORAGE_ID"], UUID(uuidString: identifier) != nil {
                directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
            }
            #endif
            store = try AppStore(directory: directory); error = nil
        }
        catch { self.error = error.localizedDescription }
    }
}
