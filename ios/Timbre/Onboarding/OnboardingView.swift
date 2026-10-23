import AVFoundation
import SwiftUI
import TimbreCore
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var instrumentID: String? = "guitar.acoustic.6"
    @State private var level = "beginner"
    @State private var goal = "tune"
    @State private var showPaywall = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var floating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let steps = 4

    var body: some View {
        ZStack {
            StageBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { index in
                        Capsule().fill(index <= step ? Palette.mint : Palette.line).frame(height: 4)
                    }
                }
                .padding(.horizontal, 28).padding(.top, 12)
                .opacity(step == 0 ? 0 : 1)
                Group {
                    switch step {
                    case 0: welcome
                    case 1: experience
                    case 2: goals
                    default: microphone
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
                .frame(maxHeight: .infinity)
            }
        }
        .animation(Motion.settle, value: step)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: finish) {
            PaywallView(context: .onboarding).environmentObject(store).environmentObject(store.commerce)
        }
    }

    private func next() { Haptics.shared.selection(); step += 1 }

    /// Pro members skip the offer.
    private func afterMicrophone() {
        if store.commerce.isPro { finish() } else { showPaywall = true }
    }

    private func finish() {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0) }
        store.completeOnboarding(instrument: instrument, level: level, goal: goal)
        if instrumentID == nil { store.selectReference() }
        Analytics.log("onboarding_complete", ["instrument": instrumentID ?? "chromatic", "goal": goal, "level": level])
    }

    /// Spotlit instrument, the promise, and the instrument picker in one screen.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                Spotlight().fill(LinearGradient(colors: [Color(hex: 0xFFC48C).opacity(0.16), Color(hex: 0xFFC48C).opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    .blur(radius: 6)
                    .ignoresSafeArea(edges: .top)
                Text("TIMBRE").font(Typeface.label(15)).tracking(9).foregroundStyle(Palette.amber).padding(.top, 34)
                    .frame(maxWidth: .infinity)
                Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.22), .clear], center: .center, startRadius: 2, endRadius: 170))
                    .frame(width: 320, height: 46).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                Image(heroImage(selectedChoice)).resizable().interpolation(.high).scaledToFit()
                    .id(instrumentID ?? "voice")
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                    .shadow(color: .black.opacity(0.65), radius: 26, y: 18)
                    .rotationEffect(.degrees(floating ? -9 : -13))
                    .offset(y: floating ? -6 : 6)
                    .padding(.top, 70).padding(.bottom, 26)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                Text("Tune until it\nstands still.").font(Typeface.display(40)).tracking(-1).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("A precision tuner, hundreds of lessons that listen as you play, and a daily quest to keep you going.")
                    .font(.body).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(choices) { choice in
                        let selected = instrumentID == choice.id
                        Button {
                            withAnimation(Motion.pluck) { instrumentID = choice.id }
                            Haptics.shared.selection()
                        } label: {
                            Text(choice.title).font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? Color(hex: 0xC9FFEC) : Palette.ink)
                                .padding(.horizontal, 18).frame(height: 44)
                                .background(Capsule().fill(selected ? Palette.mint.opacity(0.10) : Palette.stageRaised))
                                .overlay(Capsule().strokeBorder(selected ? Palette.mint : Palette.line, lineWidth: selected ? 1.5 : 1))
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.instrument.\(choice.id ?? "voice")")
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 18)
            Button("Start tuning") { next() }.buttonStyle(BrassButtonStyle()).padding(.horizontal, 22).padding(.top, 22)
                .accessibilityIdentifier("onboarding.start")
            Button {
                restoring = true
                restoreMessage = nil
                Task {
                    await store.commerce.restore()
                    restoring = false
                    if store.commerce.isPro { next() } else { restoreMessage = store.commerce.error }
                }
            } label: {
                if restoring { ProgressView().tint(Palette.inkSoft) } else { Text("I already have Timbre Pro").underline() }
            }
            .font(.footnote).foregroundStyle(Palette.inkSoft).frame(maxWidth: .infinity).frame(height: 44).padding(.bottom, 4)
            .disabled(restoring)
            .accessibilityIdentifier("onboarding.restore")
            if let restoreMessage {
                Text(restoreMessage).font(.caption).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.bottom, 6)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    private var selectedChoice: Choice { choices.first { $0.id == instrumentID } ?? choices[0] }

    /// The studio render when the instrument has an artist model, otherwise its photograph.
    private func heroImage(_ choice: Choice) -> String {
        let photo = choice.photo ?? "01_guitar_acoustic_guitar"
        if let model = ModelLibrary.modelID(forPhoto: photo), ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return photo
    }

    private struct Choice: Identifiable { let id: String?; let title: LocalizedStringKey; let photo: String?; let symbol: String? }
    private var choices: [Choice] {
        [Choice(id: "guitar.acoustic.6", title: "Guitar", photo: "01_guitar_acoustic_guitar", symbol: nil),
         Choice(id: "bass.electric.4", title: "Bass", photo: "06_bass_4_string_p_bass", symbol: nil),
         Choice(id: "ukulele.soprano.4", title: "Ukulele", photo: "10_ukulele_soprano_ukulele", symbol: nil),
         Choice(id: "violin.standard.4", title: "Violin", photo: "17_bowed_strings_violin", symbol: nil),
         Choice(id: "cello.standard.4", title: "Cello", photo: "19_bowed_strings_cello", symbol: nil),
         Choice(id: "mandolin.standard.8", title: "Mandolin", photo: "13_mandolin_mandolin", symbol: nil),
         Choice(id: "banjo.five.5", title: "Banjo", photo: "22_folk_world_strings_banjo_5_string", symbol: nil),
         Choice(id: nil, title: "Voice or other", photo: nil, symbol: "dot.radiowaves.left.and.right")]
    }

    private func options(_ items: [(String, LocalizedStringKey, String)], selection: Binding<String>) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.0) { item in
                Button { selection.wrappedValue = item.0; Haptics.shared.selection() } label: {
                    HStack(spacing: 14) {
                        IconOrb(symbol: item.2, size: 40)
                        Text(item.1).font(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: selection.wrappedValue == item.0 ? "checkmark.circle.fill" : "circle").foregroundStyle(selection.wrappedValue == item.0 ? Palette.brass : Palette.inkFaint)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(selection.wrappedValue == item.0 ? Palette.brass.opacity(0.14) : Palette.stageRaised.opacity(0.8)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selection.wrappedValue == item.0 ? Palette.brass : Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var experience: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("How long have you been playing?", "Exercises start where you are.")
            options([("beginner", "Just starting", "leaf.fill"), ("intermediate", "A few years", "music.note"), ("advanced", "Many years", "star.fill"), ("pro", "I play professionally", "crown.fill")], selection: $level)
            Spacer()
            Button("Continue") { next() }.buttonStyle(BrassButtonStyle()).accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("What matters most?", "Your daily set is built around it.")
            options([("tune", "Tune fast and precisely", "tuningfork"), ("practice", "Practice every day", "calendar"), ("ear", "Train my ear", "ear.fill"), ("voice", "Sing in tune", "music.mic"), ("rhythm", "Keep better time", "metronome.fill")], selection: $goal)
            Spacer()
            Button("Continue") { next() }.buttonStyle(BrassButtonStyle()).accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var microphone: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle().strokeBorder(Palette.brass.opacity(0.3 - Double(ring) * 0.08), lineWidth: 1.5).frame(width: 130 + CGFloat(ring) * 60, height: 130 + CGFloat(ring) * 60)
                }
                Image(systemName: "mic.fill").font(.system(size: 54)).foregroundStyle(Palette.brass)
            }
            .frame(height: 260)
            Text("Timbre listens\nto your instrument").font(Typeface.display(34)).tracking(-0.6).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text("Pitch is measured on your iPhone. Recordings are never saved or uploaded.").multilineTextAlignment(.center).foregroundStyle(Palette.inkSoft).padding(.horizontal, 30)
            Spacer()
            Button("Allow microphone") {
                Task {
                    _ = await AVAudioApplication.requestRecordPermission()
                    afterMicrophone()
                }
            }
            .buttonStyle(BrassButtonStyle()).padding(.horizontal, 28)
            .accessibilityIdentifier("onboarding.microphone")
            Button("Not now") { afterMicrophone() }.font(.subheadline).foregroundStyle(Palette.inkSoft).padding(.bottom, 14)
        }
    }

    private func question(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 8)
    }
}

/// A soft cone of light falling from the top edge.
private struct Spotlight: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.09, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.09, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.32, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.32, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
