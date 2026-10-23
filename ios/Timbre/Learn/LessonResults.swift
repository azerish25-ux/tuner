import SwiftUI
import TimbreCore

/// The end of a lesson: stars land one by one, XP counts up, then the next lesson is one tap away.
struct LessonResults: View {
    let course: LearnCourse
    let lesson: Lesson
    let result: LessonResult
    let improved: Bool
    let accent: Color
    let next: Lesson?
    let onContinue: () -> Void
    let onNext: (Lesson) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var shownStars = 0
    @State private var xp = 0
    @State private var burst = 0
    @State private var appeared = false
    @State private var offerReminder = !UserDefaults.standard.bool(forKey: PracticeReminder.askedKey) && !UserDefaults.standard.bool(forKey: PracticeReminder.enabledKey)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    private var headline: LocalizedStringKey {
        switch result.stars { case 3: return "Flawless"; case 2: return "Great work"; default: return "Lesson complete" }
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 10)
            ZStack {
                SparkBurst(trigger: burst, color: Palette.amber).frame(width: 320, height: 320)
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in star(i) }
                }
            }
            .frame(height: 150)
            VStack(spacing: 8) {
                Text(headline).font(Typeface.display(36)).tracking(-0.8).foregroundStyle(Palette.ink)
                Text(lesson.title.localized).font(.headline).foregroundStyle(Palette.inkSoft)
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
            HStack(spacing: 12) {
                tile(symbol: "sparkles", tint: accent, value: Text("+\(xp)"), label: Text("XP"))
                tile(symbol: "scope", tint: Palette.amber, value: Text("\(Int((result.accuracy * 100).rounded()))%"), label: Text("accuracy"))
                tile(symbol: "flame.fill", tint: Palette.flame, value: Text("\(store.streak.current)"), label: Text("day streak"))
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            if improved && result.stars == 3 {
                Label("New best on this lesson", systemImage: "arrow.up.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            if offerReminder && appeared { reminderCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
            Spacer()
            VStack(spacing: 10) {
                if let next, store.canPlay(next) {
                    StepButton(title: "Next lesson", accent: accent) { onNext(next) }.padding(.bottom, -12)
                        .accessibilityIdentifier("lesson.next")
                }
                Button { onContinue() } label: {
                    Text("Done").font(Typeface.label(17)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, minHeight: 52)
                }
                .accessibilityIdentifier("lesson.done")
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)
        }
        .task { await reveal() }
    }

    /// After the first lesson: one tap to make practice a daily habit.
    private var reminderCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(accent)
                .frame(width: 44, height: 44).background(Circle().fill(accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Make it a habit").font(Typeface.label(15)).foregroundStyle(Palette.ink)
                Text("A reminder each evening at 7 pm.").font(.footnote).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 4)
            Button("Remind me") {
                UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
                Task { await PracticeReminder.enable(at: PracticeReminder.minutes); withAnimation { offerReminder = false } }
            }
            .font(Typeface.label(14)).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(accent))
            .accessibilityIdentifier("lesson.reminder")
            Button { UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey); withAnimation { offerReminder = false } } label: {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint).frame(width: 28, height: 36)
            }
            .accessibilityLabel("Not now")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .padding(.horizontal, 20)
    }

    private func star(_ i: Int) -> some View {
        let earned = i < result.stars
        let shown = i < shownStars
        let size: CGFloat = i == 1 ? 96 : 72
        return Image(systemName: "star.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(earned && shown ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.08)))
            .shadow(color: earned && shown ? Color(hex: 0xF0A93B).opacity(0.6) : .clear, radius: 18)
            .scaleEffect(shown ? 1 : 0.3)
            .rotationEffect(.degrees(shown ? 0 : -40))
            .offset(y: i == 1 ? -14 : 0)
            .accessibilityHidden(true)
    }

    private func tile(symbol: String, tint: Color, value: Text, label: Text) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            value.font(Typeface.number(24)).foregroundStyle(Palette.ink).contentTransition(.numericText())
            label.font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .accessibilityElement(children: .combine)
    }

    private func reveal() async {
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        for i in 0..<3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 380))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shownStars = i + 1 }
            if i < result.stars { SoundFX.shared.play(.star); Haptics.shared.lock(); burst += 1 }
        }
        // Ask for a rating right after a flawless lesson, a couple of times in the app's life.
        if result.stars == 3, [2, 10].contains(store.progress.stats["lessons"] ?? 0) {
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
        let steps = 20
        for s in 1...steps {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.linear(duration: 0.03)) { xp = result.xp * s / steps }
        }
    }
}
