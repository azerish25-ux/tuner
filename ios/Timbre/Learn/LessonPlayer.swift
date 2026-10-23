import SwiftUI
import TimbreCore

/// A lesson, full screen: progress bar on top, one step at a time, results at the end.
struct LessonPlayer: View {
    let course: LearnCourse
    let lesson: Lesson
    var onNext: ((Lesson) -> Void)?
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var run: LessonRun
    @State private var result: LessonResult?
    @State private var improved = false
    @State private var confirmQuit = false

    init(course: LearnCourse, lesson: Lesson, onNext: ((Lesson) -> Void)? = nil) {
        self.course = course
        self.lesson = lesson
        self.onNext = onNext
        _run = State(initialValue: LessonRun(lesson: lesson))
    }

    private var accent: Color { Palette.accent(course.accent) }

    var body: some View {
        ZStack {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0), startRadius: 10, endRadius: 520).ignoresSafeArea()
            if let result {
                LessonResults(course: course, lesson: lesson, result: result, improved: improved, accent: accent,
                              next: nextLesson, onContinue: { dismiss() }, onNext: { next in dismiss(); onNext?(next) })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 0) {
                    topBar
                    if let step = run.step {
                        StepView(step: step, course: course, accent: accent) { score in advance(score) }
                            .id(run.index)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: run.index)
        .animation(.easeInOut(duration: 0.4), value: result != nil)
        .preferredColorScheme(.dark)
        .confirmationDialog("Leave this lesson?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: { Text("Your progress in this lesson won’t be saved.") }
        .onDisappear { store.stopLessonListening(); store.audio.stopMetronome() }
        .statusBarHidden(result == nil)
    }

    private var nextLesson: Lesson? {
        let all = course.lessons
        guard let i = all.firstIndex(where: { $0.id == lesson.id }), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { if run.index == 0 { dismiss() } else { confirmQuit = true } } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.inkSoft)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Close lesson").accessibilityIdentifier("lesson.close")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule().fill(LinearGradient(colors: [accent.opacity(0.85), accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(14, proxy.size.width * run.progress))
                        .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.35)).frame(height: 3).padding(.horizontal, 6).padding(.top, 2) }
                        .shadow(color: accent.opacity(0.5), radius: 8)
                }
            }
            .frame(height: 14)
            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: run.progress)
            .accessibilityElement().accessibilityLabel(Text("Step \(run.index + 1) of \(lesson.steps.count)"))
        }
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
    }

    private func advance(_ score: Double?) {
        run.complete(score: score)
        guard run.isFinished else { return }
        let outcome = run.result()
        improved = outcome.stars > (store.learn.stars[lesson.id] ?? 0)
        store.stopLessonListening()
        store.finishLesson(outcome, courseId: course.id)
        SoundFX.shared.play(.complete)
        Haptics.shared.done()
        result = outcome
    }
}

/// Routes a step to its view. Each view calls `done` with a 0…1 score (nil when not scored).
struct StepView: View {
    let step: LessonStep
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void

    var body: some View {
        switch step {
        case let .explain(title, body, visual):
            ExplainStep(title: title, text: body, visual: visual, course: course, accent: accent, done: done)
        case let .playNotes(notes, hint):
            NotesStep(notes: notes, hint: hint, course: course, accent: accent, done: done)
        case let .playAlong(notes, bpm, beatsPerBar, title):
            AlongStep(notes: notes, bpm: bpm, beatsPerBar: beatsPerBar, title: title, course: course, accent: accent, done: done)
        case let .playChord(chord):
            ChordStep(chord: chord, course: course, accent: accent, done: done)
        case let .strum(chord, pattern, bpm, bars):
            RhythmStep(mode: .strum(chord), pattern: pattern, bpm: bpm, bars: bars, accent: accent, done: done)
        case let .tapRhythm(pattern, bpm, bars):
            RhythmStep(mode: .tap, pattern: pattern, bpm: bpm, bars: bars, accent: accent, done: done)
        case let .listen(prompt, sound, options, answer):
            ChoiceStep(prompt: prompt, options: options, answer: answer, why: nil, visual: .none, sound: sound, course: course, accent: accent, done: done)
        case let .quiz(prompt, options, answer, why, visual):
            ChoiceStep(prompt: prompt, options: options, answer: answer, why: why, visual: visual, sound: nil, course: course, accent: accent, done: done)
        }
    }
}

// MARK: - Shared pieces

/// The big bottom button every step ends with.
struct StepButton: View {
    let title: LocalizedStringKey
    var accent: Color = Palette.mint
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Typeface.label(18)).foregroundStyle(enabled ? Palette.onAccent : Palette.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(enabled ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.stageRaised)))
                .overlay(alignment: .bottom) {
                    if enabled { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.18)).frame(height: 5).offset(y: 5).mask(RoundedRectangle(cornerRadius: 18, style: .continuous).offset(y: 5)) }
                }
                .shadow(color: enabled ? accent.opacity(0.35) : .clear, radius: 16, y: 6)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
        .padding(.horizontal, 20).padding(.bottom, 12)
        .accessibilityIdentifier("lesson.continue")
    }
}

/// A burst of sparks for right answers and hit notes.
struct SparkBurst: View {
    let trigger: Int
    var color: Color = Palette.mint
    @State private var started = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(started)
                guard t < 0.9 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<22 {
                    let angle = Double(i) / 22 * 2 * .pi + Double(trigger) * 0.37
                    let speed = 90 + Double((i * 37) % 60)
                    let d = speed * t * (1 - t / 1.8)
                    let p = CGPoint(x: center.x + cos(angle) * d, y: center.y + sin(angle) * d)
                    let r = 3.2 * (1 - t / 0.9)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color((i % 3 == 0 ? Palette.amber : color).opacity(1 - t / 0.9)))
                }
                let ring = 20 + 160 * t
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)), with: .color(color.opacity(max(0, 0.5 - t * 0.6))), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in started = Date() }
        .accessibilityHidden(true)
    }
}

/// Microphone permission is off: say so, offer Settings, let the step be skipped.
struct MicrophoneHint: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        if store.audio.permissionDenied {
            VStack(spacing: 8) {
                Label("Timbre needs the microphone to hear you play.", systemImage: "mic.slash.fill").font(.subheadline).foregroundStyle(Palette.inkSoft)
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
            }
            .padding(14).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.stageRaised))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Explain

struct ExplainStep: View {
    let title: LearnText
    let text: LearnText
    let visual: LessonVisual
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if visual != .none {
                        LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument)
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.stageRaised))
                            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
                            .scaleEffect(shown ? 1 : 0.94).opacity(shown ? 1 : 0)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title.localized).font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text(text.localized).font(.title3).foregroundStyle(Palette.inkSoft).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .offset(y: shown ? 0 : 18).opacity(shown ? 1 : 0)
                }
                .padding(.horizontal, 22).padding(.top, 18)
            }
            StepButton(title: "Continue", accent: accent) { Haptics.shared.selection(); done(nil) }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { shown = true } }
    }
}

// MARK: - Choices (listen and quiz)

struct ChoiceStep: View {
    let prompt: LearnText
    let options: [LearnText]
    let answer: Int
    let why: LearnText?
    let visual: LessonVisual
    let sound: [[Int]]?
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var picked: Int?
    @State private var shake = 0
    @State private var burst = 0
    @State private var playing = false

    private var correct: Bool { picked == answer }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(prompt.localized).font(Typeface.display(26)).tracking(-0.4).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    if let sound { listenButton(sound) }
                    if visual != .none {
                        LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument)
                            .padding(16).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
                    }
                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in optionRow(index, option) }
                    }
                    .modifier(Shake(amount: shake))
                }
                .padding(.horizontal, 22).padding(.top, 18)
            }
            if let picked { feedback(picked) }
            StepButton(title: picked == nil ? "Check" : "Continue", accent: picked == nil || correct ? accent : Palette.danger, enabled: picked != nil) {
                done(correct ? 1 : 0)
            }
        }
        .overlay { SparkBurst(trigger: burst, color: accent) }
        .onAppear { if let sound { play(sound) } }
    }

    private func listenButton(_ sound: [[Int]]) -> some View {
        Button { play(sound) } label: {
            HStack(spacing: 14) {
                Image(systemName: playing ? "speaker.wave.3.fill" : "play.fill").font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.onAccent).frame(width: 64, height: 64)
                    .background(Circle().fill(accent)).shadow(color: accent.opacity(0.5), radius: 14)
                    .symbolEffect(.variableColor.iterative, isActive: playing)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hear it").font(Typeface.label(17)).foregroundStyle(Palette.ink)
                    Text("Tap to play again").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("lesson.hear")
    }

    private func optionRow(_ index: Int, _ option: LearnText) -> some View {
        let isPicked = picked == index
        let reveal = picked != nil
        let tint: Color = reveal && index == answer ? accent : reveal && isPicked ? Palette.danger : Palette.line
        return Button {
            guard picked == nil else { return }
            picked = index
            if index == answer { SoundFX.shared.play(.correct); Haptics.shared.lock(); burst += 1 }
            else { SoundFX.shared.play(.wrong); Haptics.shared.selection(); withAnimation(.default) { shake += 1 } }
        } label: {
            HStack(spacing: 12) {
                Text(option.localized).font(.body.weight(.semibold)).foregroundStyle(Palette.ink).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if reveal && index == answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                else if reveal && isPicked { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.danger) }
            }
            .padding(.horizontal, 18).frame(minHeight: 58)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(reveal && (index == answer || isPicked) ? tint.opacity(0.12) : Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(tint, lineWidth: reveal && (index == answer || isPicked) ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(picked != nil && !isPicked && index != answer)
        .accessibilityIdentifier("lesson.option.\(index)")
    }

    private func feedback(_ picked: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: correct ? "checkmark.seal.fill" : "lightbulb.fill").font(.title2).foregroundStyle(correct ? accent : Palette.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text(correct ? LocalizedStringKey("Nice — that’s right.") : LocalizedStringKey("Not quite.")).font(Typeface.label(17)).foregroundStyle(Palette.ink)
                if let why { Text(why.localized).font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true) }
                else if !correct { Text("The answer is \(options[answer].localized).").font(.subheadline).foregroundStyle(Palette.inkSoft) }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill((correct ? accent : Palette.amber).opacity(0.10)))
        .padding(.horizontal, 20).padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func play(_ sound: [[Int]]) {
        playing = true
        Task { @MainActor in
            for group in sound {
                let hz = group.map { PitchMath.frequency(midi: Double($0), reference: store.settings.referencePitchHz) }
                store.audio.playTones(hz, together: group.count > 1, noteMs: group.count > 1 ? 900 : 650, gapMs: 120)
                try? await Task.sleep(for: .milliseconds(group.count > 1 ? 1350 : 800))
            }
            playing = false
        }
    }
}

struct Shake: GeometryEffect {
    var animatableData: CGFloat
    init(amount: Int) { animatableData = CGFloat(amount) }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 6), y: 0))
    }
}
