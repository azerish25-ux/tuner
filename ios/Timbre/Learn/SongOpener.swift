import SwiftUI
import TimbreCore

/// The first screen of a song lesson, a song sheet. The zoom out of the song's sleeve (on the Songs shelf, Learn's
/// path) lands on that sleeve full size; once the screen has arrived, the sleeve settles into the sheet's head and
/// the sheet unfolds under it: key, tempo, meter and length; the chords the song asks for as small boxes that strum
/// when tapped (a melody's notes, for a song without chords); and the song map. "Preview with band" plays the opening
/// of the take the lesson ends on: over the band in headphones, the melody alone on the speaker (the band only ever
/// plays in headphones, where it can't reach the microphone). Start goes on to the lesson.
struct SongOpener: View {
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    /// The presentation carrying the lesson in has landed: the sleeve settles and the sheet unfolds only then.
    let arrived: Bool
    let start: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @State private var unfolded = false
    @State private var width: CGFloat = 390
    @State private var previewing = false
    @State private var previewTask: Task<Void, Never>?
    @State private var previewStart = Date()
    @State private var previewSeconds = 0.0
    /// The chord (symbol) or note just tapped, lit while it sounds.
    @State private var sounding: String?

    /// The sleeve's side once settled in the sheet's head.
    private static let side: CGFloat = 112
    private static let margin: CGFloat = 22

    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        facts.modifier(Unfold(shown: unfolded, order: 1, calm: reduceMotion))
                        harmony.modifier(Unfold(shown: unfolded, order: 2, calm: reduceMotion))
                        songMap.modifier(Unfold(shown: unfolded, order: 3, calm: reduceMotion))
                    }
                    .padding(.horizontal, Self.margin).padding(.top, 8).padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                actionBar
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear {
            store.audio.prepareBand(band)
            if arrived || reduceMotion { unfolded = true }
        }
        .onChange(of: arrived) { _, landed in
            guard landed, !unfolded else { return }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) { unfolded = true }
        }
        .onDisappear { stopPreview() }
    }

    // MARK: Head

    /// The sleeve's own light behind the head of the sheet.
    private var backdrop: some View {
        SongCover(art: art, corner: 0, titled: false, outlined: false)
            .frame(height: 360)
            .blur(radius: 48)
            .opacity(0.4)
            .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Full size and centred as the zoom lands, then beside the title.
    private var bigScale: CGFloat { min(2.3, max(1.3, (width - 110) / Self.side)) }

    private var header: some View {
        let scale = unfolded ? 1 : bigScale
        let shift = unfolded ? 0 : width / 2 - Self.margin - Self.side / 2
        return HStack(alignment: .center, spacing: 30) {
            sleeve
                .scaleEffect(scale, anchor: .top)
                .offset(x: shift)
                .zIndex(1)
            titleBlock
                .opacity(unfolded ? 1 : 0)
                .offset(x: unfolded ? 0 : 40)
        }
        .frame(height: unfolded ? Self.side : Self.side * bigScale, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The sleeve with its record peeking out, turning while the preview plays.
    private var sleeve: some View {
        let side = Self.side
        let out = unfolded ? side * (previewing && !reduceMotion ? 0.3 : 0.18) : 0
        return SongCover(art: art, corner: 10)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            .background(alignment: .trailing) {
                VinylRecord(color: art.primary, spinning: previewing && !reduceMotion)
                    .frame(width: side * 0.92, height: side * 0.92)
                    .offset(x: out)
            }
            .animation(reduceMotion ? nil : Motion.settle, value: previewing)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                CourseArt(course: course, size: 16)
                Text(course.title.localized.uppercased()).font(Typeface.label(11)).tracking(1.2).foregroundStyle(accent).lineLimit(1)
            }
            Text(lesson.title.localized).font(Typeface.display(26)).tracking(-0.5).foregroundStyle(Palette.ink)
                .lineLimit(3).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
            Text("\(lesson.minutes) min · +\(lesson.xp) XP").font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Facts

    private var facts: some View {
        let sheet = self.sheet
        return HStack(spacing: 8) {
            if let key = sheet.keyName { fact("Key", Text(verbatim: key)) }
            fact("Tempo", Text("\(Int(sheet.bpm.rounded())) BPM"))
            fact("Meter", Text(verbatim: sheet.meterName))
            fact("Length", Text(verbatim: sheet.length))
        }
    }

    private func fact(_ label: LocalizedStringKey, _ value: Text) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Typeface.label(11)).tracking(1).textCase(.uppercase).foregroundStyle(Palette.inkFaint)
                .lineLimit(1).minimumScaleFactor(0.7)
            value.font(Typeface.display(16, relativeTo: .headline)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(shape.fill(Palette.stageRaised.opacity(0.9)))
        .overlay(shape.strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Chords, or the melody's notes

    @ViewBuilder private var harmony: some View {
        let sheet = self.sheet
        if !sheet.chords.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                heading("Chords", detail: Text(verbatim: "\(sheet.chords.count)"))
                EdgeRail(bleed: Self.margin, spacing: 10, selection: nil as String?) {
                    ForEach(sheet.chords, id: \.symbol) { chord in chordCard(chord) }
                }
            }
        } else if !sheet.melody.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                heading("Notes", detail: range(sheet.noteSet))
                EdgeRail(bleed: Self.margin, spacing: 8, selection: nil as String?) {
                    ForEach(sheet.noteSet, id: \.self) { midi in noteChip(midi) }
                }
            }
        }
    }

    private func chordCard(_ chord: ChordSpec) -> some View {
        let lit = sounding == chord.symbol
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { strum(chord) } label: {
            VStack(spacing: 8) {
                MiniChordGlyph(chord: chord, accent: accent, lit: lit)
                    .frame(width: 54, height: 64)
                Text(verbatim: chord.name).font(Typeface.display(17, relativeTo: .headline))
                    .foregroundStyle(lit ? accent : Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(minWidth: 62)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
            .background(shape.fill(lit ? accent.opacity(0.16) : Palette.stageRaised))
            .overlay(shape.strokeBorder(lit ? accent.opacity(0.6) : .white.opacity(0.06), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .animation(reduceMotion ? nil : Motion.quick, value: lit)
        .accessibilityLabel(Text("\(chord.name) chord"))
        .accessibilityHint(Text("Hear it"))
    }

    private func noteChip(_ midi: Int) -> some View {
        let lit = sounding == "\(midi)"
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button { pluck(midi) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: NoteName.pitchClass(midi)).font(Typeface.display(18, relativeTo: .headline))
                Text(verbatim: "\(midi / 12 - 1)").font(Typeface.label(11)).foregroundStyle(Palette.inkSoft)
            }
            .foregroundStyle(lit ? accent : Palette.ink)
            .frame(minWidth: 46, minHeight: 46)
            .padding(.horizontal, 6)
            .background(shape.fill(lit ? accent.opacity(0.16) : Palette.stageRaised))
            .overlay(shape.strokeBorder(lit ? accent.opacity(0.6) : .white.opacity(0.06), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(verbatim: NoteName.name(midi)))
        .accessibilityHint(Text("Hear it"))
    }

    /// The melody's lowest and highest notes, "D3–G4".
    private func range(_ notes: [Int]) -> Text? {
        guard let low = notes.first, let high = notes.last, high > low else { return nil }
        return Text(verbatim: "\(NoteName.name(low))–\(NoteName.name(high))")
    }

    // MARK: Song map

    private var songMap: some View {
        let sheet = self.sheet
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                heading("Song map", detail: Text("\(sheet.bars) bars"))
                Spacer(minLength: 8)
                BandControls(audio: store.audio, accent: accent)
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !previewing)) { timeline in
                SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent, progress: mapProgress(at: timeline.date))
            }
        }
    }

    /// Where the preview has got to in the song, while it plays.
    private func mapProgress(at date: Date) -> Double? {
        guard previewing, sheet.seconds > 0 else { return nil }
        let into = date.timeIntervalSince(previewStart) - previewLead
        return min(1, max(0, into / sheet.seconds))
    }

    private func heading(_ title: LocalizedStringKey, detail: Text?) -> some View {
        HStack(spacing: 8) {
            Text(title).font(Typeface.label(12)).tracking(1.4).textCase(.uppercase).foregroundStyle(accent)
            if let detail { detail.font(Typeface.label(12)).foregroundStyle(Palette.inkFaint) }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: The bar

    private var actionBar: some View {
        LessonActionBar {
            previewButton
            StepButton(title: "Start", accent: accent, inset: false) {
                stopPreview()
                Haptics.shared.selection()
                start()
            }
        }
    }

    private var previewButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button(action: togglePreview) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    if previewing { previewRing }
                    Image(systemName: previewing ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .offset(x: previewing ? 0 : 1)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 30, height: 30)
                Text(previewing ? LocalizedStringKey("Stop") : LocalizedStringKey("Preview with band"))
                    .lineLimit(2).minimumScaleFactor(0.75).multilineTextAlignment(.leading)
            }
            .font(Typeface.label(15)).foregroundStyle(accent)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(shape.fill(accent.opacity(0.12)))
            .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(previewPhrase == nil)
        .accessibilityIdentifier("song.preview")
    }

    private var previewRing: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(previewStart)
            let fraction = previewSeconds > 0 ? min(1, max(0, elapsed / previewSeconds)) : 0
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: Sound

    /// The band the final take plays over (the same arrangement, so it is rendered once for both).
    private var band: BandArrangement {
        let sheet = self.sheet
        return .melody(sheet.melody, bpm: sheet.melodyBpm, beatsPerBar: sheet.melodyMeter,
                       reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }

    /// The preview: the take's first four bars (eight when they hold few notes), at its tempo.
    private var previewPhrase: SongPreview.Phrase? {
        let sheet = self.sheet
        let meter = Double(max(1, sheet.melodyMeter))
        guard !sheet.melody.isEmpty else { return nil }
        let four = sheet.melody.filter { $0.beat < 4 * meter }
        let notes = four.count >= 5 ? four : sheet.melody.filter { $0.beat < 8 * meter }
        guard !notes.isEmpty else { return nil }
        return SongPreview.Phrase(notes: notes, bpm: sheet.melodyBpm)
    }

    /// Seconds before the melody starts within the preview (none: the band starts with it).
    private var previewLead: Double { 0 }

    private func togglePreview() {
        if previewing { stopPreview(); return }
        guard let phrase = previewPhrase else { return }
        let audio = store.audio
        let reference = store.settings.referencePitchHz
        let voice = InstrumentVoice(instrumentId: course.instrument)
        let meter = Double(max(1, sheet.melodyMeter))
        let spb = phrase.secondsPerBeat
        let withBand = bandOn && audio.headphones
        // With the band, through the end of the last bar it plays, so it lands on its final chord.
        let bars = ((phrase.notes.map { $0.beat + $0.beats }.max() ?? meter) / meter).rounded(.up)
        let length = withBand ? max(phrase.duration, bars * meter * spb) : phrase.duration
        Haptics.shared.selection()
        Analytics.log("song_sheet_preview", ["lesson": lesson.id, "band": withBand ? "1" : "0"])
        if withBand {
            // The band rides the click from its first bar: no count-in for a preview.
            audio.setMetronome(bpm: Int(phrase.bpm.rounded()), beats: Int(meter), subdivision: 1, accents: true)
            audio.playBand(band, firstBar: 0)
        }
        previewStart = Date()
        previewSeconds = length
        withAnimation(Motion.pluck) { previewing = true; sounding = nil }
        previewTask = Task { @MainActor in
            let clock = ContinuousClock()
            let begin = clock.now
            for (index, note) in phrase.notes.enumerated() {
                try? await clock.sleep(until: begin + .seconds(phrase.time(of: index)))
                guard !Task.isCancelled else { return }
                let ms = Int(min(1600, max(160, note.beats * spb * 950)))
                audio.playTones([PitchMath.frequency(midi: Double(note.midi), reference: reference)],
                                together: false, noteMs: ms, gapMs: 0, voice: voice)
            }
            try? await clock.sleep(until: begin + .seconds(length))
            guard !Task.isCancelled else { return }
            if withBand { audio.finishBand(celebrate: true) }
            try? await clock.sleep(until: begin + .seconds(length + 0.5))
            guard !Task.isCancelled else { return }
            previewTask = nil
            withAnimation(Motion.settle) { previewing = false }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        guard previewing else { return }
        store.audio.stopTone()
        if store.audio.metronomeRunning { store.audio.stopMetronome() }
        withAnimation(Motion.settle) { previewing = false }
    }

    /// The chord as shaped on the course instrument (as the lessons sound it); a plain triad without a shape.
    private func strum(_ chord: ChordSpec) {
        stopPreview()
        let open = ChordStep.openStrings(course)
        var midis = chord.frets.enumerated().compactMap { i, fret -> Int? in fret >= 0 && i < open.count ? open[i] + fret : nil }
        if midis.isEmpty, let target = ChordTarget(root: chord.root, formulaId: chord.quality) {
            midis = target.quality.intervals.map { 48 + target.root + $0 }
        }
        guard !midis.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        store.audio.playTones(midis.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1300,
                              voice: InstrumentVoice(instrumentId: course.instrument))
        Haptics.shared.selection()
        light(chord.symbol, for: 1.4)
    }

    private func pluck(_ midi: Int) {
        stopPreview()
        store.audio.playTones([PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz)], together: false,
                              noteMs: 700, gapMs: 0, voice: InstrumentVoice(instrumentId: course.instrument))
        Haptics.shared.selection()
        light("\(midi)", for: 0.8)
    }

    private func light(_ id: String, for seconds: Double) {
        sounding = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            if sounding == id { sounding = nil }
        }
    }
}

/// A row of the song sheet coming in under the settling sleeve, one after another.
private struct Unfold: ViewModifier {
    let shown: Bool
    let order: Int
    let calm: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || calm ? 0 : 26)
            .animation(calm ? nil : .spring(response: 0.6, dampingFraction: 0.86).delay(0.08 * Double(order)), value: shown)
    }
}
