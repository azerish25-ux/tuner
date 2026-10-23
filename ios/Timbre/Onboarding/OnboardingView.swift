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
    private let steps = 5

    var body: some View {
        ZStack {
            StageBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { index in
                        Capsule().fill(index <= step ? Palette.brass : Palette.line).frame(height: 4)
                    }
                }
                .padding(.horizontal, 28).padding(.top, 12)
                .opacity(step == 0 ? 0 : 1)
                Group {
                    switch step {
                    case 0: welcome
                    case 1: instrument
                    case 2: experience
                    case 3: goals
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

    private func finish() {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0) }
        store.completeOnboarding(instrument: instrument, level: level, goal: goal)
        if instrumentID == nil { store.selectReference() }
        Analytics.log("onboarding_complete", ["instrument": instrumentID ?? "chromatic", "goal": goal, "level": level])
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                ChromaticStage(input: { StageInput(cents: 0, level: -30, locked: true, listening: true) }, note: "")
                    .frame(width: 300, height: 300).opacity(0.75)
                Image(ModelLibrary.cardImageName("guitar_acoustic")).resizable().scaledToFit().frame(height: 300)
                    .shadow(color: Palette.ember.opacity(0.35), radius: 40, y: 10)
            }
            VStack(spacing: 10) {
                Text("TIMBRE").font(.system(size: 14, weight: .bold)).tracking(8).foregroundStyle(Palette.brass)
                Text("Tune until it\nstands still.").font(Typeface.display(46)).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                Text("A precision tuner for sixty instruments, with the practice that keeps you in tune.").font(.body).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            Spacer()
            Button("Get started") { next() }.buttonStyle(BrassButtonStyle()).padding(.horizontal, 28).accessibilityIdentifier("onboarding.start")
            Spacer().frame(height: 14)
        }
    }

    private struct Choice: Identifiable { let id: String?; let title: LocalizedStringKey; let photo: String?; let symbol: String? }
    private var choices: [Choice] {
        [Choice(id: "guitar.acoustic.6", title: "Guitar", photo: "guitar_acoustic", symbol: nil),
         Choice(id: "bass.electric.4", title: "Bass", photo: "bass_p4", symbol: nil),
         Choice(id: "ukulele.soprano.4", title: "Ukulele", photo: "ukulele_soprano", symbol: nil),
         Choice(id: "violin.standard.4", title: "Violin", photo: "17_bowed_strings_violin", symbol: nil),
         Choice(id: "cello.standard.4", title: "Cello", photo: "19_bowed_strings_cello", symbol: nil),
         Choice(id: "mandolin.standard.8", title: "Mandolin", photo: "13_mandolin_mandolin", symbol: nil),
         Choice(id: "banjo.five.5", title: "Banjo", photo: "22_folk_world_strings_banjo_5_string", symbol: nil),
         Choice(id: nil, title: "Voice or other", photo: nil, symbol: "dot.radiowaves.left.and.right")]
    }

    private var instrument: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("What do you play?", "We'll set up your tuner and practice around it.")
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(choices) { choice in
                        let selected = instrumentID == choice.id
                        Button { instrumentID = choice.id; Haptics.shared.selection() } label: {
                            VStack(spacing: 8) {
                                Group {
                                    if let photo = choice.photo {
                                        let name = UIImage(named: ModelLibrary.cardImageName(photo)) != nil ? ModelLibrary.cardImageName(photo) : (UIImage(named: "thumb_" + photo) != nil ? "thumb_" + photo : photo)
                                        Image(name).resizable().scaledToFit()
                                    } else if let symbol = choice.symbol { Image(systemName: symbol).font(.system(size: 44)).foregroundStyle(Palette.brass) }
                                }
                                .frame(height: 96)
                                Text(choice.title).font(.headline).foregroundStyle(Palette.ink)
                            }
                            .frame(maxWidth: .infinity).padding(12)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(selected ? Palette.brass.opacity(0.16) : Palette.stageRaised.opacity(0.8)))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(selected ? Palette.brass : Palette.line, lineWidth: selected ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            Button("Continue") { next() }.buttonStyle(BrassButtonStyle()).accessibilityIdentifier("onboarding.continue")
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
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
            options([("tune", "Tune fast and precisely", "tuningfork"), ("practice", "Practise every day", "calendar"), ("ear", "Train my ear", "ear.fill"), ("voice", "Sing in tune", "music.mic"), ("rhythm", "Keep better time", "metronome.fill")], selection: $goal)
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
            Text("Timbre listens\nto your instrument").font(Typeface.display(40)).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text("Pitch is measured on your iPhone. Recordings are never saved or uploaded.").multilineTextAlignment(.center).foregroundStyle(Palette.inkSoft).padding(.horizontal, 30)
            Spacer()
            Button("Allow microphone") {
                Task {
                    _ = await AVAudioApplication.requestRecordPermission()
                    showPaywall = true
                }
            }
            .buttonStyle(BrassButtonStyle()).padding(.horizontal, 28)
            .accessibilityIdentifier("onboarding.microphone")
            Button("Not now") { showPaywall = true }.font(.subheadline).foregroundStyle(Palette.inkSoft).padding(.bottom, 14)
        }
    }

    private func question(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(38)).foregroundStyle(Palette.ink)
            Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 8)
    }
}
