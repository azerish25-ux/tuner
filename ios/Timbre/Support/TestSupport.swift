import Foundation

/// The one place the app asks whether it is running under automation: unit and UI tests, the demo pitch, demo data
/// and the capture scenes (the App Store screenshots and App Preview). Features that must stay quiet there (remote
/// settings, Game Center, the win-back offer, analytics) read `isAutomated` instead of the environment; a feature
/// that a run switches on reads its own `Key`.
///
/// Debug builds only: a release build is never automated and reads no launch environment, so none of this reaches the
/// shipped app.
enum TestSupport {
    /// The launch environment an automated run (a UI test, `tools/marketing`) can set.
    enum Key: String, CaseIterable, Sendable {
        /// A UI test's own storage folder, a UUID (`storageRoot`).
        case storageID = "TIMBRE_TEST_STORAGE_ID"
        /// "1": a demo pitch stands in for the microphone.
        case demoPitch = "TIMBRE_DEMO_PITCH"
        /// "1": realistic practice history is seeded on an empty store (`DemoData`).
        case demoData = "TIMBRE_DEMO_DATA"
        /// "1": onboarding counts as done.
        case skipOnboarding = "TIMBRE_SKIP_ONBOARDING"
        /// "studio": the tuner opens on the studio stage.
        case stageMode = "TIMBRE_STAGE_MODE"
        /// "1": probes XCUITest reads (presentation flags, the stage's state) are drawn.
        case debugState = "TIMBRE_DEBUG_STATE"
        /// "1": the 3D stage draws its load state.
        case stageDebug = "TIMBRE_STAGE_DEBUG"
        /// "1": everything that moves on its own rests as in Low Power Mode (`stageResting`).
        case stageRest = "TIMBRE_STAGE_REST"
        #if DEBUG
        /// "1": report the resting live stage disappearing to its own priming session; not GPU completion.
        case simulatorPriming = "TIMBRE_SIMULATOR_PRIMING"
        #endif
        /// "1": bounded local Songs page geometry/position observations; never a scrolling instruction.
        case songPageTrace = "TIMBRE_SONG_PAGE_TRACE"
        /// A capture scene's name (`DemoScene`).
        case scene = "TIMBRE_SCENE"
        /// A capture scene's instrument, song, bar, lock comet and cue file.
        case sceneInstrument = "TIMBRE_SCENE_INSTRUMENT"
        case sceneSong = "TIMBRE_SCENE_SONG"
        case sceneBar = "TIMBRE_SCENE_BAR"
        /// "1": hold an actual song-scene state for a still image; never set by video capture.
        case sceneStill = "TIMBRE_SCENE_STILL"
        case sceneComet = "TIMBRE_SCENE_COMET"
        case sceneCue = "TIMBRE_SCENE_CUE"
        /// A folder the App Preview's soundtrack is written to (`PreviewRecorder`).
        case previewAudio = "TIMBRE_PREVIEW_AUDIO"
        /// A file whose appearance plays the motif under the App Preview's end card (`DemoScene.playMotifWhenAsked`).
        case previewMotif = "TIMBRE_PREVIEW_MOTIF"
        /// A recording played into the listening frames while the demo pitch runs (`AudioService.demoClip`).
        case demoClip = "TIMBRE_DEMO_CLIP"
    }

    /// The keys that make a run automated, with XCTest's own.
    private static let automationKeys = ["XCTestConfigurationFilePath", Key.storageID.rawValue, Key.demoPitch.rawValue,
                                         Key.demoData.rawValue, Key.scene.rawValue]

    /// A test, a demo mode or a capture scene is driving the app. Always false in a release build.
    static let isAutomated: Bool = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return automationKeys.contains { environment[$0] != nil }
        #else
        return false
        #endif
    }()

    /// What the run set `key` to; nil when it didn't, and always in a release build.
    static func value(_ key: Key) -> String? {
        #if DEBUG
        return ProcessInfo.processInfo.environment[key.rawValue]
        #else
        return nil
        #endif
    }

    /// The run set `key` to "1".
    static func isOn(_ key: Key) -> Bool { value(key) == "1" }

    /// The run asked for a resting stage (`Key.stageRest`): the 3D stages stay on their pictures, the shader effects
    /// and the animations that run while seen hold still, as they do in Low Power Mode, so a screen that never stops
    /// moving can still be read whole (an accessibility audit times out on one). Read once; false in a release build.
    static let stageResting: Bool = isOn(.stageRest)

    /// A UI test's own Application Support folder (`TimbreUITests/<storage id>`), so each test starts from its own
    /// saved state; nil outside one (and in a release build), where the app's own folders are used.
    static let storageRoot: URL? = {
        guard let identifier = value(.storageID), UUID(uuidString: identifier) != nil else { return nil }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
    }()
}

#if DEBUG
extension TestSupport {
    @MainActor private static var primingRestReported = false

    /// A diagnostic lifecycle observation, not a rendering, permission or app-readiness certificate.
    /// Called only by the live child's disappearance after its existing resting detach/unmount path.
    @MainActor static func recordPrimingStageRest(modelID: String) {
        guard isOn(.simulatorPriming), stageResting, !primingRestReported,
              let session = value(.storageID), UUID(uuidString: session) != nil,
              let directory = storageRoot else { return }
        primingRestReported = true  // One bounded attempt; an I/O failure remains a missing host signal.
        let observation: [String: Any] = [
            "schema": 1, "diagnosticOnly": true, "event": "stage-rest-live-disappeared",
            "sessionID": session, "pid": ProcessInfo.processInfo.processIdentifier,
            "bundleID": Bundle.main.bundleIdentifier ?? "", "modelID": modelID,
            "utcEpoch": Date().timeIntervalSince1970, "uptime": ProcessInfo.processInfo.systemUptime,
            "semantics": "resting-live-child-disappeared-after-detach-not-gpu-completion"
        ]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var data = try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys])
            data.append(0x0A)
            try data.write(to: directory.appendingPathComponent("simulator-priming-stage.json"), options: .atomic)
        } catch {
            let message = "Simulator priming rest observation could not be written; host must retain failure.\n"
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}
#endif
