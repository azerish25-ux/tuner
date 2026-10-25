import RealityKit
import UIKit

/// Loaded 3D instrument models kept for reuse: every usdz the app shows loads through here, so the tuner's stage
/// (`InstrumentStage`) and a lesson's "Show me" demonstrations (`ShowMeStage`) load an instrument once however many
/// of them show it. Each stage gets its own copy (`instance(of:)`), which shares the cached model's meshes and
/// textures; the copies are free to move, hide and re-parent their parts.
///
/// It keeps the most recent model only (a player plays one instrument at a time), loads each model at most once at a
/// time (a second request joins the first), and lets go of everything on a memory warning or when the app goes to the
/// background. The stage environment (`StageLighting`) is made once and shared too.
@MainActor
final class ModelCache {
    static let shared = ModelCache()

    /// Models kept after their stages close.
    private static let capacity = 1
    private var prototypes: [String: Entity] = [:]
    /// Most recently used last.
    private var recent: [String] = []
    private var loads: [String: Task<Entity?, Never>] = [:]
    /// Why a model failed to load, by id (the error's words), until it loads.
    private var problems: [String: String] = [:]
    private var environmentResource: EnvironmentResource?
    private var environmentLoad: Task<EnvironmentResource?, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        for name in [UIApplication.didReceiveMemoryWarningNotification, UIApplication.didEnterBackgroundNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.purge() }
            })
        }
    }

    /// A fresh copy of model `id` (sharing the cached model's resources); nil when it can't be loaded.
    func instance(of id: String) async -> Entity? {
        guard let prototype = await prototype(id) else { return nil }
        return prototype.clone(recursive: true)
    }

    /// Starts loading model `id` after `delay` seconds, so a later `instance(of:)` is immediate. Nothing happens when
    /// it is already cached or loading.
    func prefetch(_ id: String, after delay: Double = 0) {
        guard prototypes[id] == nil, loads[id] == nil, ModelLibrary.url(id) != nil else { return }
        Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self else { return }
            _ = await self.prototype(id)
        }
    }

    /// Lets go of every cached model (stages on screen keep their own copies).
    func purge() {
        prototypes = [:]
        recent = []
    }

    /// Why model `id` last failed to load; nil when it hasn't.
    func problem(_ id: String) -> String? { problems[id] }

    /// Where model `id` stands, in a word, for diagnostics: cached, loading, failed (and why) or idle.
    func describe(_ id: String) -> String {
        if prototypes[id] != nil { return "cached" }
        if loads[id] != nil { return "loading" }
        if let problem = problems[id] { return "failed (\(problem))" }
        return "idle"
    }

    /// The dark stage's image-based light, made once.
    func environment() async -> EnvironmentResource? {
        if let environmentResource { return environmentResource }
        if let environmentLoad { return await environmentLoad.value }
        let load = Task<EnvironmentResource?, Never> { @MainActor in
            guard let image = StageLighting.environmentImage() else { return nil }
            return try? await EnvironmentResource(equirectangular: image, withName: "timbre.stage")
        }
        environmentLoad = load
        let resource = await load.value
        environmentResource = resource
        environmentLoad = nil
        return resource
    }

    private func prototype(_ id: String) async -> Entity? {
        if let cached = prototypes[id] {
            touch(id)
            return cached
        }
        if let load = loads[id] { return await load.value }
        guard let url = ModelLibrary.url(id) else {
            problems[id] = "no usdz for \(id) in the bundle"
            return nil
        }
        // The error is kept (not swallowed) so a stage that gives up can say why.
        let load = Task<Entity?, Never> { @MainActor in
            do {
                return try await Entity(contentsOf: url)
            } catch {
                self.problems[id] = error.localizedDescription
                return nil
            }
        }
        loads[id] = load
        let entity = await load.value
        loads[id] = nil
        if let entity {
            problems[id] = nil
            prototypes[id] = entity
            touch(id)
        }
        return entity
    }

    /// Marks `id` as just used and drops the oldest models past the capacity.
    private func touch(_ id: String) {
        recent.removeAll { $0 == id }
        recent.append(id)
        while recent.count > Self.capacity {
            let oldest = recent.removeFirst()
            prototypes[oldest] = nil
        }
    }
}
