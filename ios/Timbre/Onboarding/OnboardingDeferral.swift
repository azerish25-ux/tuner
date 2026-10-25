import Combine
import SwiftUI

/// Onboarding's questions that "Just tune" left for later. Someone who came for the tuner is tuning after one tap; the
/// first time they open Learn, the questions it needs (how long they have played, what they want, which hand) come
/// then, as `OnboardingView(entry: .questions)`, and lead to their plan. Saved, so a relaunch still asks once.
@MainActor
final class OnboardingDeferral: ObservableObject {
    static let shared = OnboardingDeferral()

    private static let key = "onboarding.questionsDeferred"

    /// The questions are still to be asked.
    @Published private(set) var pending: Bool

    private init() {
        pending = UserDefaults.standard.bool(forKey: Self.key)
    }

    /// "Just tune" skipped the questions: Learn asks them when it first opens.
    func deferQuestions() { set(true) }

    /// The questions were answered, or closed without answers: they are never asked again.
    func resolve() { set(false) }

    private func set(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.key)
        if pending != value { pending = value }
    }
}

extension View {
    /// On the Learn tab: the questions "Just tune" deferred, over the screen, the first time it shows. Their answers
    /// make the plan (and offer it, as onboarding does); closing them leaves Learn as it is.
    func deferredOnboardingQuestions() -> some View { modifier(DeferredOnboardingQuestions()) }
}

private struct DeferredOnboardingQuestions: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var deferral = OnboardingDeferral.shared

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: Binding(get: { deferral.pending && store.selectedTab == .learn },
                                                     set: { shown in if !shown { deferral.resolve() } })) {
            OnboardingView(entry: .questions)
                .environmentObject(store).environmentObject(store.audio).environmentObject(store.commerce)
        }
    }
}
