import SwiftUI
import TimbreCore
import UIKit

/// What the first chord needs: the chosen instrument's course and the shape it starts with. Guitar and ukulele play
/// their course's first chord (E minor, C); the banjo's open strings already ring a G chord; mandolin, bass, violin and
/// cello ring their open strings, lowest first.
struct FirstChordSetup {
    let course: LearnCourse
    let chord: ChordSpec
    /// A chord, rather than the open strings one after another.
    let isChord: Bool

    /// Nil for "Voice or other" and for an instrument without a course of its own.
    @MainActor static func make(store: AppStore, instrumentID: String?) -> FirstChordSetup? {
        guard let id = instrumentID, let course = store.curriculum.courses.first(where: { $0.instrument == id }) else { return nil }
        let open = ChordStep.openStrings(course)
        guard !open.isEmpty else { return nil }
        switch course.fretKind {
        case "guitar", "ukulele":
            guard let chord = firstChord(in: course), chord.frets.count == open.count else { return nil }
            return FirstChordSetup(course: course, chord: chord, isChord: true)
        case "banjo":
            let chord = ChordSpec(name: "G", root: 7, quality: "maj", frets: Array(repeating: 0, count: open.count))
            return FirstChordSetup(course: course, chord: chord, isChord: true)
        default:
            // Named by its strings ("G D A E"); not a chord, so it is heard string by string.
            let name = open.map { NoteName.pitchClass($0) }.joined(separator: " ")
            let strings = ChordSpec(name: name, root: open[0] % 12, quality: "open", frets: Array(repeating: 0, count: open.count))
            return FirstChordSetup(course: course, chord: strings, isChord: false)
        }
    }

    /// The first chord a lesson of the course asks for.
    private static func firstChord(in course: LearnCourse) -> ChordSpec? {
        for lesson in course.lessons {
            for step in lesson.steps {
                if case .playChord(let chord) = step { return chord }
            }
        }
        return nil
    }
}

/// Onboarding's second win, for beginners, after the first tune: the lesson's own chord step (the shape, "Show me",
/// every string lighting as it rings). Heard, it says so ("You just played your first chord") over a burst and moves
/// on to the plan, so the paywall sells lessons the player has already felt. Skip is always there.
struct FirstChordStep: View {
    let setup: FirstChordSetup
    /// Called once: true when the chord was played, false when skipped.
    let onDone: (Bool) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var played = false
    @State private var finished = false
    @State private var burstStart: Date?

    private var accent: Color { Palette.accent(setup.course.accent) }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                ChordStep(chord: setup.chord, course: setup.course, accent: accent, done: { _ in chordPlayed() })
                    .opacity(played ? 0 : 1)
                    .allowsHitTesting(!played)
                    .accessibilityHidden(played)
            }
            if played {
                celebration
                    .transition(.adaptive(.scale(scale: 0.92).combined(with: .opacity), reduceMotion: reduceMotion))
            }
            if let burstStart, !reduceMotion { FirstTuneBurst(started: burstStart).allowsHitTesting(false) }
        }
        .adaptiveAnimation(Motion.settle, value: played)
        // "Hear it" and "Show me" sound like the course's instrument, as in a lesson.
        .onAppear {
            store.audio.courseVoice = InstrumentVoice(instrumentId: setup.course.instrument)
            Analytics.log("onboarding_first_chord", ["result": "started", "instrument": setup.course.instrument ?? ""])
        }
        .onDisappear { store.audio.courseVoice = nil }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                (setup.isChord ? Text("Your first chord") : Text("Ring every open string"))
                    .font(Typeface.display(28)).tracking(-0.5).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("onboarding.firstchord")
                (setup.isChord ? Text("Thirty seconds, then your plan.") : Text("Lowest first, then your plan."))
                    .font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { finish(played: false) } label: {
                Text("Skip").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 8).tapTarget()
            }
            .buttonStyle(.plain)
            .opacity(played ? 0 : 1)
            .disabled(played)
            .accessibilityIdentifier("onboarding.firstchord.skip")
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 18)
    }

    /// The fact where the step was, the chord large under it: then the plan.
    private var celebration: some View {
        VStack(spacing: 10) {
            (setup.isChord ? Text("You just played your first chord") : Text("Every string rings"))
                .font(Typeface.display(28)).tracking(-0.5).foregroundStyle(Palette.mint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: setup.chord.name)
                .font(Typeface.display(64)).tracking(-1.2).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .shadow(color: Palette.mint.opacity(0.35), radius: 20)
            Text("Your plan is next.").font(.subheadline).foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish(played: true) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("onboarding.firstchord.done")
    }

    // MARK: Flow

    private func chordPlayed() {
        guard !played, !finished else { return }
        store.updateSettings { $0.firstChordDone = true }
        Haptics.shared.done()
        SoundFX.shared.play(.star)
        burstStart = Date()
        withMotion(Motion.settle, reduceMotion: reduceMotion) { played = true }
        let line = setup.isChord ? String(localized: "You just played your first chord") : String(localized: "Every string rings")
        UIAccessibility.post(notification: .announcement, argument: line)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            finish(played: true)
        }
    }

    private func finish(played heard: Bool) {
        guard !finished else { return }
        finished = true
        Analytics.log("onboarding_first_chord", ["result": heard ? "played" : "skipped", "instrument": setup.course.instrument ?? "",
                                                 "chord": setup.isChord ? setup.chord.symbol : "open"])
        onDone(heard)
    }
}
