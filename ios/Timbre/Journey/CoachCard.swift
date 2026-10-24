import SwiftUI
import TimbreCore

// MARK: - One note

/// One coach note: an icon for what it is about, the words (the template, then a rewording on device where that
/// is on) and its one action as a pill.
struct CoachNoteView: View {
    let note: CoachNote
    let voice: CoachVoice
    let tint: Color
    /// "Coach" over the words, where the card has no title of its own (the lesson's results).
    var eyebrow = false
    var actionId = "coach.action"
    let onAction: (CoachAction) -> Void
    @State private var reworded: String?

    var body: some View {
        let template = voice.text(note)
        HStack(alignment: .top, spacing: 12) {
            IconOrb(symbol: CoachVoice.symbol(note), tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 8) {
                if eyebrow { Eyebrow("Coach", color: tint) }
                Text(verbatim: reworded ?? template)
                    .font(.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if let action = note.action {
                    pill(action).padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .task(id: template) {
            reworded = nil
            guard let text = await CoachPolish.polish(template, names: voice.names(note)) else { return }
            withAnimation(Motion.fade) { reworded = text }
        }
    }

    /// The action in the note's colour, with where it goes ("Metronome · 45 BPM"). A pill on one line; a long
    /// title at large text sizes wraps to a second rather than being cut. The pill is 36 pt tall; its target is 44.
    private func pill(_ action: CoachAction) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { onAction(action) } label: {
            HStack(spacing: 6) {
                Image(systemName: CoachVoice.symbol(action)).font(.system(size: 12, weight: .bold)).accessibilityHidden(true)
                Text(verbatim: voice.actionTitle(action, for: note))
                    .lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.forward").font(.system(size: 10, weight: .heavy)).opacity(0.7).accessibilityHidden(true)
            }
            .font(Typeface.label(13))
            .foregroundStyle(tint)
            .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 36)
            .background(shape.fill(tint.opacity(0.14)))
            .overlay(shape.strokeBorder(tint.opacity(0.4), lineWidth: 1))
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier(actionId)
    }
}

// MARK: - Progress's card

/// Progress's "Coach": the notes that matter most now, one at a time (swipe, or the arrow), each with its one thing
/// to do; the card takes the colour of what it says. Before there is anything to say, it says what it listens for.
struct CoachPanel: View {
    let notes: [CoachNote]
    let voice: CoachVoice
    let onAction: (CoachAction) -> Void
    /// The note on show (nil: the first).
    @State private var current: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: CoachNote? { notes.first { $0.id == current } ?? notes.first }
    private var shownIndex: Int { notes.firstIndex { $0.id == shown?.id } ?? 0 }
    private var tint: Color { shown.map { CoachVoice.tint($0) } ?? Palette.mint }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if notes.isEmpty { waiting } else { pages }
        }
        .stillCard(tint: tint)
        .adaptiveAnimation(Motion.settle, value: shown?.id)
        .onChange(of: notes.map(\.id)) { _, ids in
            if let current, !ids.contains(current) { self.current = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journey.coach")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            CardTitle("Coach")
            Spacer(minLength: 8)
            if notes.count > 1 {
                dots
                nextButton
            }
        }
    }

    /// One mark per note, the one on show long and in its colour.
    private var dots: some View {
        HStack(spacing: 5) {
            ForEach(notes) { note in
                let on = note.id == shown?.id
                Capsule().fill(on ? tint : Palette.inkFaint.opacity(0.35))
                    .frame(width: on ? 16 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    /// The arrow to the next note: the app's compact icon button (a 34 pt disc in a 44 pt target).
    private var nextButton: some View {
        IconButton(symbol: "arrow.forward", size: .compact, tint: Palette.inkSoft, label: "Next tip") { advance() }
            .accessibilityValue(Text("\(shownIndex + 1) of \(notes.count)"))
            .accessibilityIdentifier("journey.coach.next")
    }

    /// The notes side by side, a page each: swiping moves the dots and the card's colour with it. The pages run
    /// out to the card's edges (its padding is theirs), so a page slides under the edge, not mid-card.
    private var pages: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(notes) { note in
                    CoachNoteView(note: note, voice: voice, tint: CoachVoice.tint(note), actionId: "journey.coach.action", onAction: onAction)
                        .padding(.horizontal, Self.inset)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Self.inset)
    }

    /// The card's own padding (`stillCard`'s default).
    private static let inset: CGFloat = Metrics.cardPadding

    private var waiting: some View {
        HStack(alignment: .top, spacing: 12) {
            IconOrb(symbol: "waveform", tint: Palette.mint, size: 38)
            Text("Play a lesson or tune up on a few days: notes on your timing, chords and strings show up here.")
                .font(.callout).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The next note, round to the first after the last.
    private func advance() {
        guard !notes.isEmpty else { return }
        Haptics.shared.selection()
        let next = notes[(shownIndex + 1) % notes.count].id
        withMotion(Motion.settle, reduceMotion: reduceMotion) { current = next }
    }
}

// MARK: - Where actions lead

/// Coach actions that leave the screen: the metronome at the note's tempo, the tuner, Today on Play. (Lessons and
/// the weak-spot drill open where the card is.)
@MainActor enum CoachRoute {
    static func open(_ action: CoachAction, store: AppStore) {
        switch action {
        case let .metronome(bpm):
            store.setMetronome(bpm: bpm)
            store.selectedTab = .practice
            store.pendingPracticeRoute = .metronome
        case .tune:
            store.selectedTab = .tune
        case .today:
            store.selectedTab = .practice
        case .review, .lesson:
            break
        }
    }

    static func log(_ action: CoachAction, screen: String) {
        Analytics.log("coach_action", ["screen": screen, "action": CoachVoice.kind(action)])
    }
}
