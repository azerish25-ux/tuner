import Foundation

/// The curriculum (curriculum.json, a few MB), decoded once and shared by everything that reads it: the app's store,
/// Spotlight's lessons and the band's style index hold the same copy.
///
/// - At launch, `preload()` starts the decode on a background queue (it returns at once), or
///   `await CurriculumStore.shared.load()` waits for it without blocking the main thread.
/// - Anywhere after that, `CurriculumStore.shared.curriculum` returns it, waiting for a decode still running (or
///   decoding on the spot when nothing started one), e.g. `BandStyleIndex(curriculum: CurriculumStore.shared.curriculum)`.
///
/// A file that fails to decode leaves an empty curriculum, and `failure` says why.
public final class CurriculumStore: @unchecked Sendable {
    public static let shared = CurriculumStore { try Curriculum.bundled() }

    private let source: @Sendable () throws -> Curriculum
    private let condition = NSCondition()
    private var started = false
    private var decoded: Curriculum?
    private var decodeError: Error?
    private var waiting: [CheckedContinuation<Curriculum, Never>] = []

    /// A store over any source (tests); the app uses `shared`, over the bundled curriculum.json.
    public init(source: @escaping @Sendable () throws -> Curriculum) {
        self.source = source
    }

    /// Starts the decode on a background queue, once. Returns at once.
    public func preload() {
        guard claim() else { return }
        DispatchQueue.global(qos: .userInitiated).async { self.decode() }
    }

    /// The curriculum, once decoded; the caller is suspended, never blocked.
    public func load() async -> Curriculum {
        preload()
        return await withCheckedContinuation { continuation in
            condition.lock()
            if let decoded {
                condition.unlock()
                continuation.resume(returning: decoded)
            } else {
                waiting.append(continuation)
                condition.unlock()
            }
        }
    }

    /// The curriculum. Waits for a decode in progress, or decodes here when none has started.
    public var curriculum: Curriculum {
        if claim() { decode() }
        condition.lock()
        defer { condition.unlock() }
        while true {
            if let decoded { return decoded }
            condition.wait()
        }
    }

    /// The decode has finished (the curriculum can be read without waiting).
    public var isLoaded: Bool {
        condition.lock()
        defer { condition.unlock() }
        return decoded != nil
    }

    /// Why curriculum.json didn't decode, when it didn't (the curriculum is then empty).
    public var failure: Error? {
        condition.lock()
        defer { condition.unlock() }
        return decodeError
    }

    /// True for the one caller that gets to start the decode.
    private func claim() -> Bool {
        condition.lock()
        defer { condition.unlock() }
        guard !started else { return false }
        started = true
        return true
    }

    private func decode() {
        let result: Curriculum
        var problem: Error?
        do {
            result = try source()
        } catch {
            result = Curriculum(courses: [])
            problem = error
        }
        condition.lock()
        decoded = result
        decodeError = problem
        let resumed = waiting
        waiting = []
        condition.broadcast()
        condition.unlock()
        for continuation in resumed { continuation.resume(returning: result) }
    }
}
