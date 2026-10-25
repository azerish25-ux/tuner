import SwiftUI
import TimbreCore
import TipKit

/// Timbre's coach marks (TipKit): a one-time hint at the moment a feature matters, never over a paywall or a sheet.
/// Automated and demo runs hide them all, so nothing they record has a tip over it.
enum TimbreTips {
    /// Tips show whenever the app isn't being driven by automation (`TestSupport.isAutomated`, always false in a
    /// release build).
    static var enabled: Bool { !TestSupport.isAutomated }

    /// Once, at launch (TimbreApp), before any screen can show a tip.
    static func configure() {
        if !enabled { Tips.hideAllTipsForTesting() }
        do {
            try Tips.configure([.displayFrequency(.immediate)])
        } catch {
            // Already configured, or no datastore: the app simply shows no tips.
        }
    }
}

// MARK: - Strum to tune

/// On the tuner's Strum toggle: one strum reads every string. It waits for the second time the tuner shows, so a
/// first tune (and onboarding's) is never interrupted, and retires once the toggle is tapped.
struct StrumTuneTip: Tip {
    static let tunerShown = Tips.Event(id: "timbre.tuner.shown")

    var title: Text { Text("Strum to tune") }
    var message: Text? { Text("Strum every open string once to read them all") }
    var image: Image? { Image(systemName: "guitars") }

    var rules: [Rule] {
        #Rule(Self.tunerShown) { $0.donations.count >= 2 }
    }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

/// Anchors the Strum to tune tip on the toggle (TuneView's side controls) while the tuner is on screen with nothing
/// over it: not on the paywall overlay, Settings or the instrument picker, and only where a strum can read the
/// instrument (`AppStore.canStrumTune`, when the toggle shows at all).
private struct StrumTuneTipAnchor: ViewModifier {
    @EnvironmentObject private var store: AppStore
    private let tip = StrumTuneTip()

    private var clear: Bool {
        // Not on bowed strings: the coach mark speaks of strumming, and their toggle reads "Pluck all" (StrumToggle).
        TimbreTips.enabled && store.settings.onboardingCompleted == true && store.canStrumTune && !store.strumPlucks && store.selectedTab == .tune
            && !store.showPaywall && !store.showSettings && !store.showInstrumentPicker
    }

    func body(content: Content) -> some View {
        content
            .popoverTip(clear ? tip : nil)
            .simultaneousGesture(TapGesture().onEnded { tip.invalidate(reason: .actionPerformed) })
            .onAppear { Task { await StrumTuneTip.tunerShown.donate() } }
    }
}

extension View {
    /// The Strum to tune coach mark on the tuner's Strum toggle.
    func strumTuneTip() -> some View { modifier(StrumTuneTipAnchor()) }

    /// The Tune by feel coach mark on the tuner's Feel toggle.
    func tuneByFeelTip() -> some View { modifier(TuneByFeelTipAnchor()) }
}

// MARK: - Tune by feel

/// On the tuner's Feel toggle, once: after the player's third full tune, the tuner offers to let them feel the beat
/// instead of watching the needle. It waits for the tuner to appear after that tune (never over the celebration), and
/// retires once the toggle is tapped.
struct TuneByFeelTip: Tip {
    /// Full tunes so far (`UserSettings.fullTunes`), given by the tuner as it appears.
    @Parameter static var fullTunes: Int = 0

    var title: Text { Text("Tune by feel") }
    var message: Text? { Text("Tune by feel pulses at the beat between the string and its note, slower as they meet, still at the lock.") }
    var image: Image? { Image(systemName: "hand.tap") }

    var rules: [Rule] {
        #Rule(Self.$fullTunes) { $0 >= 3 }
    }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

/// Anchors the Tune by feel tip on the Feel toggle while the tuner is on screen with nothing over it, and only while
/// Tune by feel is off (VoiceOver turns it on by itself).
private struct TuneByFeelTipAnchor: ViewModifier {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AppStorage(TuneByFeel.chosenKey) private var chosen = false
    private let tip = TuneByFeelTip()

    private var clear: Bool {
        TimbreTips.enabled && TuneByFeel.available && store.settings.hapticsEnabled && store.selectedTab == .tune
            && !TuneByFeel.isOn(store.settings, voiceOver: voiceOver, chosen: chosen)
            && !store.showPaywall && !store.showSettings && !store.showInstrumentPicker
            // One coach mark at a time: where the Strum to tune tip can show, it has its turn first.
            && !(store.canStrumTune && !store.strumPlucks && StrumTuneTip().shouldDisplay)
    }

    func body(content: Content) -> some View {
        content
            .popoverTip(clear ? tip : nil)
            .simultaneousGesture(TapGesture().onEnded { tip.invalidate(reason: .actionPerformed) })
            .onAppear { TuneByFeelTip.fullTunes = store.settings.fullTunes ?? 0 }
    }
}

// MARK: - String order in lessons

/// Which way up the strings are drawn: string 1, the thinnest, on top as tab writes it (the Chart view, the
/// default), or at the bottom in Player view, so a beginner never has to guess as the lesson moves between pictures.
/// It says the one choice behind it (`ChordPicture`) can be flipped, and where: the switch on any chord card, or
/// Settings › String order.
struct StringOrderTip: Tip {
    var title: Text {
        StringOrder.current.thinnestOnTop ? Text("String 1 = thinnest, on top") : Text("String 1 = thinnest, at the bottom")
    }
    var message: Text? { Text("Chart or Player view: switch on any chord card, or in Settings › String order.") }
    var image: Image? { Image(systemName: "list.number") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(3)
    }
}

/// The string-order tip above a lesson's first step that draws a neck lying down (a fretboard picture, the notes'
/// neck strip or the play-along's lanes) on a fretted or bowed course. Leaving that step retires it. A chord card
/// carries the Chart / Player view switch itself, so it never shows it. LessonPlayer places it under its top bar.
struct StringOrderTipSlot: View {
    let step: LessonStep?
    let course: LearnCourse
    private let tip = StringOrderTip()

    var body: some View {
        if TimbreTips.enabled, let step, Self.drawsNeck(step, course: course) {
            TipView(tip)
                .tipBackground(Palette.stageRaised)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .transition(.opacity)
                .onDisappear { tip.invalidate(reason: .actionPerformed) }
        }
    }

    /// Steps whose strings lie across the screen in the chosen order: a fretboard picture, the notes' strip and the
    /// play-along's lanes. Not the strum stage (a rhythm explanation's, a strum's or a progression's): it always lies in
    /// Player view so a down strum falls down the screen (`StrumSweep.order`), and names its own edges.
    static func drawsNeck(_ step: LessonStep, course: LearnCourse) -> Bool {
        guard course.fretKind != nil else { return false }
        switch step {
        case let .explain(_, _, visual):
            if case .fretboard = visual { return true }
            return false
        case let .quiz(_, _, _, _, visual):
            if case .fretboard = visual { return true }
            return false
        case .playNotes, .playAlong:
            return true
        default:
            return false
        }
    }
}
