import Foundation

/// The one place the app asks whether it is running under automation: unit and UI tests, the demo pitch, demo data
/// and the capture scenes (the App Store screenshots and App Preview). Features that must stay quiet there (remote
/// settings, Game Center, the win-back offer, analytics) read `isAutomated` instead of the environment.
///
/// Debug builds only: a release build is never automated, so none of this reaches the shipped app.
enum TestSupport {
    /// The launch environment keys an automated run sets.
    private static let automationKeys = ["XCTestConfigurationFilePath", "TIMBRE_TEST_STORAGE_ID", "TIMBRE_DEMO_PITCH",
                                         "TIMBRE_DEMO_DATA", "TIMBRE_SCENE"]

    /// A test, a demo mode or a capture scene is driving the app. Always false in a release build.
    static let isAutomated: Bool = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return automationKeys.contains { environment[$0] != nil }
        #else
        return false
        #endif
    }()
}
