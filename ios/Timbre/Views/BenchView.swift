import SwiftUI
import TimbreCore

struct BenchView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var commerce: CommerceService
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if geometry.size.width > 740 {
                            HStack(alignment: .top, spacing: 20) {
                                stage.frame(maxWidth: .infinity)
                                dial.frame(maxWidth: .infinity)
                            }
                        } else { stage; dial }
                        if store.tuning.id == "oud.arabic.11.turkish" && !store.referenceMode {
                            Label("timbre_bench_oud_turkish_caution", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(TimbreTheme.warning)
                        }
                    }.padding(20).frame(maxWidth: 1150).frame(maxWidth: .infinity)
                }
                controls.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                    .background(TimbreTheme.canvas)
            }.background(TimbreTheme.canvas).foregroundStyle(TimbreTheme.primary)
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button { store.selectedTab = 0 } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("timbre_bench_your_instrument").font(.caption).foregroundStyle(TimbreTheme.secondary)
                        HStack(spacing: 6) {
                            Text(store.referenceMode ? (store.catalog.referenceMode?.name.localized ?? "Chromatic reference") : (store.photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? store.instrument.name.localized)).font(TimbreTheme.title(25))
                            Image(systemName: "chevron.down").font(.caption)
                        }.multilineTextAlignment(.leading)
                    }
                }.buttonStyle(.plain)
                Spacer(minLength: 10)
                Menu {
                    ForEach([415.0, 432, 435, 440, 442], id: \.self) { hz in
                        Button("A4 \(Int(hz)) Hz") { store.updateSettings { $0.referencePitchHz = hz } }
                    }
                    Button("Custom reference…") { store.showSettings = true }
                } label: {
                    Text("A4 \(store.settings.referencePitchHz, specifier: "%.0f")").font(.caption.monospacedDigit()).padding(10).background(TimbreTheme.raised, in: Capsule())
                }.accessibilityLabel("Reference pitch, A4 \(Int(store.settings.referencePitchHz)) hertz")
            }
            if !store.referenceMode {
                Menu {
                    ForEach(store.catalog.tunings.filter { $0.instrumentId == store.instrument.id }) { tuning in
                        Button { store.selectTuning(tuning) } label: {
                            Label(tuning.name.localized, systemImage: tuning.isFree || commerce.isPlus ? "music.note" : "lock")
                        }
                    }
                } label: {
                    HStack { Text(store.tuning.name.localized); Image(systemName: "chevron.down").font(.caption) }.font(.subheadline).foregroundStyle(TimbreTheme.secondary)
                }
            }
            if store.settings.capo != 0 || store.settings.transposition != 0 {
                Text("Display: transpose \(store.settings.transposition), capo \(store.settings.capo)").font(.caption).foregroundStyle(TimbreTheme.secondary)
            }
        }
    }
    private var stage: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22).fill(TimbreTheme.surface)
                if store.referenceMode {
                    Image(systemName: "waveform").resizable().scaledToFit().foregroundStyle(TimbreTheme.brass.opacity(0.35)).padding(65)
                } else if let photo = store.photo {
                    Image(photo.asset).resizable().scaledToFit().padding(15).accessibilityLabel(store.instrument.name.localized).accessibilityIdentifier("bench.photo")
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(store.targetName).font(TimbreTheme.number(44)).foregroundStyle(TimbreTheme.primary).accessibilityIdentifier("bench.targetNote")
                    Text("\(store.targetHz, specifier: "%.2f") Hz").font(.caption.monospacedDigit()).foregroundStyle(TimbreTheme.secondary)
                    Spacer()
                }.padding(15).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)).padding(12)
            }.frame(height: store.referenceMode ? 205 : 245)
            if store.referenceMode {
                Stepper(value: Binding(get: { store.referenceMidi }, set: { store.referenceMidi = $0; store.automatic = false }), in: 12...119) { Text("Choose a note · \(store.targetName)").font(.subheadline) }.padding(.horizontal, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(store.settings.handedness == "left" ? Array(store.courses.reversed()) : store.courses) { course in
                            let label = TargetLabelFormatter.splitCue(store.courseLabel(course))
                            Button { store.chooseCourse(course.index) } label: {
                                VStack(spacing: 4) {
                                    Text(label.main).font(.headline.monospaced())
                                    Text(label.cue ?? "\(course.index)").font(.caption2)
                                }.frame(minWidth: 46, minHeight: 52).padding(.horizontal, 7)
                                    .foregroundStyle(store.activeCourse.index == course.index ? TimbreTheme.ink : TimbreTheme.primary)
                                    .background(store.activeCourse.index == course.index ? TimbreTheme.brass : TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(course.label), note \(course.index)")
                                .accessibilityAddTraits(store.activeCourse.index == course.index ? .isSelected : [])
                        }
                    }
                }
                if store.instrument.isAdjustable {
                    HStack {
                        Label("Adjustable reference", systemImage: "slider.horizontal.3").font(.caption).foregroundStyle(TimbreTheme.warning)
                        Spacer()
                        Button("Adjust A4") { store.showSettings = true }.font(.caption)
                    }
                }
            }
        }
    }
    private var dial: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PRECISION TUNER").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(TimbreTheme.secondary)
                Spacer()
                Text(Temperament.byId(store.settings.temperamentId).name).font(.caption).foregroundStyle(TimbreTheme.secondary)
            }
            ZStack {
                CentsDial(cents: store.reading.cents, active: audio.running && !audio.tonePlaying, inTune: store.reading.inTune).frame(height: 132)
                VStack(spacing: 2) {
                    Text(store.reading.cents.map { String(format: "%+.1f", $0) } ?? "—").font(TimbreTheme.number(35))
                    Text("CENTS").font(.caption2).tracking(2).foregroundStyle(TimbreTheme.secondary)
                }.offset(y: 32)
            }.accessibilityElement(children: .ignore).accessibilityLabel("Pitch deviation").accessibilityValue(store.reading.cents.map { String(format: "%.1f cents", $0) } ?? "No measured pitch")
            Text(audio.tonePlaying ? "Listen to the reference, then play your note." : store.statusText)
                .font(.subheadline.weight(.medium)).foregroundStyle(store.reading.inTune ? TimbreTheme.success : TimbreTheme.secondary).multilineTextAlignment(.center)
            HStack {
                frequencyLabel("TARGET", frequency: store.targetHz)
                Spacer()
                frequencyLabel("LIVE", frequency: store.reading.frequency).accessibilityIdentifier("bench.liveFrequency")
            }.padding(.top, 8)
            HStack(spacing: 9) {
                Image(systemName: "mic").font(.caption)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TimbreTheme.raised)
                        Capsule().fill(audio.levelDbfs > -3 ? TimbreTheme.warning : TimbreTheme.success).frame(width: geometry.size.width * CGFloat(min(1, max(0, (audio.levelDbfs + 70) / 70))))
                    }
                }.frame(height: 5)
                Text(audio.running ? String(format: "%.0f dB", audio.levelDbfs) : "MIC OFF").font(.caption2.monospacedDigit()).frame(width: 52)
            }.foregroundStyle(TimbreTheme.secondary).padding(.top, 8).accessibilityLabel("Microphone input \(Int(audio.levelDbfs)) decibels")
        }.padding(20).background(TimbreTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private func frequencyLabel(_ title: String, frequency: Double?) -> some View {
        VStack(alignment: title == "TARGET" ? .leading : .trailing, spacing: 4) {
            Text(title).font(.caption2).tracking(1.5).foregroundStyle(TimbreTheme.secondary)
            Text(frequency.map { String(format: "%.2f Hz", $0) } ?? "— Hz").font(.subheadline.monospacedDigit())
        }.accessibilityElement(children: .ignore).accessibilityLabel(frequency.map { String(format: "%.2f Hz", $0) } ?? "— Hz")
    }
    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Target selection", selection: $store.automatic) {
                Text("Automatic").tag(true)
                Text("Manual").tag(false)
            }.pickerStyle(.segmented)
            HStack(spacing: 12) {
                Button { store.toggleTone() } label: {
                    Label(audio.tonePlaying ? "Stop tone" : "Hear note", systemImage: audio.tonePlaying ? "speaker.slash" : "speaker.wave.2")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 49).background(TimbreTheme.raised, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
                Button { store.toggleListening() } label: {
                    Label(audio.running ? "Pause" : "Listen", systemImage: audio.running ? "pause.fill" : "mic.fill")
                }.buttonStyle(PrimaryButton()).accessibilityIdentifier("listenButton")
            }
            Button("timbre_bench_finish_tuning") { store.finishTuning() }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

private struct CentsDial: View {
    let cents: Double?
    let active: Bool
    let inTune: Bool
    var body: some View {
        Canvas { (context: inout GraphicsContext, size: CGSize) in
            let center = CGPoint(x: size.width / 2.0, y: size.height - 8.0)
            let radius: CGFloat = min(size.width / 2.0 - 14.0, size.height - 15.0)
            for value in stride(from: -50, through: 50, by: 5) {
                let angle: Double = Double(value) / 50.0 * Double.pi / 2.0 - Double.pi / 2.0
                let long = value % 25 == 0
                let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                let tickLength: CGFloat = long ? 15.0 : 8.0
                let outer = CGPoint(x: center.x + dx * radius, y: center.y + dy * radius)
                let inner = CGPoint(x: center.x + dx * (radius - tickLength), y: center.y + dy * (radius - tickLength))
                var path = Path(); path.move(to: inner); path.addLine(to: outer)
                context.stroke(path, with: .color(value == 0 ? TimbreTheme.success : TimbreTheme.secondary.opacity(0.55)), lineWidth: value == 0 ? 3 : 1)
            }
            if active, let cents {
                let angle: Double = min(50.0, max(-50.0, cents)) / 50.0 * Double.pi / 2.0 - Double.pi / 2.0
                let dx = CGFloat(cos(angle)), dy = CGFloat(sin(angle))
                let tip = CGPoint(x: center.x + dx * (radius - 20.0), y: center.y + dy * (radius - 20.0))
                let base = CGPoint(x: center.x + dx * (radius - 37.0), y: center.y + dy * (radius - 37.0))
                var needle = Path(); needle.move(to: base); needle.addLine(to: tip)
                context.stroke(needle, with: .color(inTune ? TimbreTheme.success : TimbreTheme.action), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }.overlay(alignment: .bottom) {
            HStack { Text("−50"); Spacer(); Text("0").offset(y: -105); Spacer(); Text("+50") }.font(.caption2.monospacedDigit()).foregroundStyle(TimbreTheme.secondary).padding(.horizontal, 5)
        }
    }
}
