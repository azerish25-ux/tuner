import SwiftUI
import TimbreCore
import TipKit

/// Timbre's coach marks (TipKit): a one-time hint at the moment a feature matters, never over a paywall or a sheet.
/// UI tests and the store-screenshot runs hide them all, so every picture stays clean.
enum TimbreTips {
    /// False under XCTest, the UI tests (they all set TIMBRE_TEST_STORAGE_ID), the demo pitch, demo data and the
    /// store scenes. Release builds never read these values.
    static let enabled: Bool = {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let quiet = ["XCTestConfigurationFilePath", "TIMBRE_TEST_STORAGE_ID", "TIMBRE_DEMO_PITCH", "TIMBRE_DEMO_DATA", "TIMBRE_SCENE"]
        return !quiet.contains { environment[$0] != nil }
        #else
        return true
        #endif
    }()

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
        TimbreTips.enabled && store.settings.onboardingCompleted == true && store.canStrumTune && store.selectedTab == .tune
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

    /// Steps whose strings lie across the screen in the chosen order: a fretboard picture, the notes' strip, the
    /// play-along's lanes and, since it lies as every neck does, the strum stage (a rhythm explanation's, a strum's or
    /// a progression's), where string 1 on top means a down strum climbs the screen.
    static func drawsNeck(_ step: LessonStep, course: LearnCourse) -> Bool {
        guard course.fretKind != nil else { return false }
        switch step {
        case let .explain(_, _, visual):
            switch visual {
            case .fretboard, .rhythm: return true
            default: return false
            }
        case let .quiz(_, _, _, _, visual):
            if case .fretboard = visual { return true }
            return false
        case .playNotes, .playAlong, .strum, .progression:
            return true
        default:
            return false
        }
    }
}
