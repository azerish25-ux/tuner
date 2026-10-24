import SwiftUI
import TimbreCore

/// The first screen of a song lesson, a song sheet. The zoom out of the song's sleeve (on the Songs shelf, Learn's
/// path) lands on that sleeve full size; once the screen has arrived, the sleeve settles into the sheet's head and
/// the sheet unfolds under it: key, tempo, meter and level; the chords the song asks for as small boxes that strum
/// when tapped (a melody's notes, for a song without chords); the song map; and the lead sheet, bar by bar, with the
/// chord symbols over the melody (or its tab) and the hook marked. Tapping a section, on the map or the lead sheet,
/// loops it, at 50, 75 or 100 % of the song's tempo, with a playhead through its bars; `practice`, when the host
/// gives one, takes that loop on to be played. "Preview with band" plays the opening of the take the lesson ends on:
/// over the band in headphones, the melody alone on the speaker (the band only ever plays in headphones, where it
/// can't reach the microphone). Start goes on to the lesson.
struct SongOpener: View {
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    /// The presentation carrying the lesson in has landed: the sleeve settles and the sheet unfolds only then.
    let arrived: Bool
    let start: () -> Void
    /// A section picked on the sheet, to practise on its own at its loop's speed; nil hides "Practice this part".
    var practice: ((SongSheet.Loop) -> Void)?
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    /// The lead sheet shows tab rather than the melody's shape (fretted courses).
    @AppStorage("songsheet.tab") private var showTab = false
    @State private var unfolded = false
    @State private var width: CGFloat = 390
    /// "Preview with band" is playing.
    @State private var previewing = false
    /// The picked section is looping.
    @State private var looping = false
    @State private var playTask: Task<Void, Never>?
    @State private var playStart = Date()
    @State private var previewSeconds = 0.0
    /// The section picked on the map or the lead sheet, its loop's speed and how long one pass lasts.
    @State private var selected: Int?
    @State private var loopSpeed = 0.75
    @State private var loopPass = 0.0
    /// The chord (symbol) or note just tapped, lit while it sounds.
    @State private var sounding: String?

    /// The sleeve's side once settled in the sheet's head.
    private static let side: CGFloat = 112
    private static let margin: CGFloat = 22
    /// The sheet keeps to a readable measure on a wide screen.
    private static let measure: CGFloat = 860
    private static let speeds: [Double] = [0.5, 0.75, 1]

    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var chart: LeadChart { LeadChart.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private var playing: Bool { previewing || looping }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        content(proxy)
                            .padding(.horizontal, Self.margin).padding(.top, 8).padding(.bottom, 16)
                            .frame(maxWidth: Self.measure)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }
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
        .onDisappear { stopPlayback() }
    }

    private func content(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            facts.modifier(Unfold(shown: unfolded, order: 1, calm: reduceMotion))
            harmony.modifier(Unfold(shown: unfolded, order: 2, calm: reduceMotion))
            // Only the map and the lead sheet follow the playhead.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { timeline in
                let position = self.position(at: timeline.date)
                VStack(alignment: .leading, spacing: 22) {
                    songMap(position, proxy: proxy).modifier(Unfold(shown: unfolded, order: 3, calm: reduceMotion))
                    leadSheet(position).modifier(Unfold(shown: unfolded, order: 4, calm: reduceMotion))
                }
            }
        }
    }

    // MARK: Head

    /// The sleeve's colours as a mesh of light behind the head of the sheet.
    private var backdrop: some View {
        CoverMesh(art: art)
            .frame(height: 380)
            .opacity(0.5)
            .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea(edges: .top)
    }

    /// Full size and centred as the zoom lands, then beside the title.
    private var bigScale: CGFloat { min(2.3, max(1.3, (min(width, Self.measure) - 110) / Self.side)) }

    private var header: some View {
        let scale = unfolded ? 1 : bigScale
        let shift = unfolded ? 0 : min(width, Self.measure) / 2 - Self.margin - Self.side / 2
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

    /// The sleeve with its record peeking out, turning while the song plays.
    private var sleeve: some View {
        let side = Self.side
        let out = unfolded ? side * (playing && !reduceMotion ? 0.26 : 0.18) : 0
        return SongCover(art: art, corner: 10)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
            .background(alignment: .trailing) {
                VinylRecord(color: art.primary, spinning: playing && !reduceMotion)
                    .frame(width: side * 0.92, height: side * 0.92)
                    .offset(x: out)
            }
            .animation(reduceMotion ? nil : Motion.settle, value: playing)
    }

    /// The course, the title, then how long the song runs beside how long the lesson takes (they are different
    /// things: "Song 0:22 · lesson 6 min"), and its XP.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                CourseArt(course: course, size: 16)
                Text(course.title.localized.uppercased()).font(Typeface.label(11)).tracking(1.2).foregroundStyle(accent).lineLimit(1)
            }
            Text(lesson.title.localized).font(Typeface.display(26)).tracking(-0.5).foregroundStyle(Palette.ink)
                .lineLimit(3).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Song \(sheet.length) · lesson \(lesson.minutes) min")
                    .font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                Text("+\(lesson.xp) XP").font(Typeface.label(12)).foregroundStyle(Palette.amber)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Palette.amber.opacity(0.14)))
                    .fixedSize()
            }
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
            fact("Level", Text(levelName))
        }
    }

    /// Easy, Medium or Hard, as the Songs shelves grade it.
    private var levelName: LocalizedStringKey {
        let unit = course.units.firstIndex { $0.lessons.contains { $0.id == lesson.id } } ?? 0
        let level = sheet.difficulty(unit: unit, of: course.units.count)
        return level <= 1 ? "Easy" : level == 2 ? "Medium" : "Hard"
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

    /// The sections across the screen; tapping one loops it and brings its bars into view on the lead sheet.
    private func songMap(_ position: Double?, proxy: ScrollViewProxy) -> some View {
        let sheet = self.sheet
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                heading("Song map", detail: Text("\(sheet.bars) bars"))
                Spacer(minLength: 8)
                BandControls(audio: store.audio, accent: accent)
            }
            SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent,
                           progress: position.map { $0 / Double(max(1, sheet.bars)) }, selected: selected) { section in
                pick(section)
                withAnimation(reduceMotion ? nil : Motion.settle) { proxy.scrollTo(section.anchor, anchor: .center) }
            }
            .accessibilityIdentifier("song.map")
        }
    }

    // MARK: Lead sheet

    @ViewBuilder private func leadSheet(_ position: Double?) -> some View {
        let chart = self.chart
        let tab = tabLayout
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                heading("Lead sheet", detail: Text(verbatim: sheet.meterName))
                Spacer(minLength: 8)
                if tab != nil { notationSwitch }
            }
            LeadSheetView(chart: chart, sections: sheet.sections, accent: accent, tab: showTab ? tab : nil,
                          width: min(width, Self.measure) - Self.margin * 2, position: position, selected: selected,
                          onSelect: { section in pick(section) },
                          controls: { section in loopControls(section) })
        }
        .accessibilityIdentifier("song.leadsheet")
    }

    /// Fret numbers for every note, where the lesson places it (else the lowest fret), on fretted courses only.
    private var tabLayout: LeadTab? {
        guard course.fretKind != nil, !course.fretless, course.stringCount > 0, !chart.notes.isEmpty else { return nil }
        let frets = chart.notes.map { $0.at ?? course.fretting(for: $0.midi) }
        guard frets.contains(where: { $0 != nil }) else { return nil }
        return LeadTab(frets: frets, strings: course.stringCount, thinnestOnTop: stringOrder.thinnestOnTop)
    }

    /// Notes (the melody's shape) or Tab.
    private var notationSwitch: some View {
        HStack(spacing: 2) {
            notationOption("Notes", on: !showTab) { showTab = false }
            notationOption("Tab", on: showTab) { showTab = true }
        }
        .padding(2)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .animation(reduceMotion ? nil : Motion.quick, value: showTab)
    }

    private func notationOption(_ title: LocalizedStringKey, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !on else { return }
            Haptics.shared.selection()
            action()
        } label: {
            Text(title).font(Typeface.label(12)).foregroundStyle(on ? Palette.stage : Palette.inkSoft)
                .padding(.horizontal, 12).frame(minHeight: 28)
                .background { if on { Capsule().fill(Palette.ink) } }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Under the picked section: loop or stop, the speed, and (when the host takes it on) practice this part.
    private func loopControls(_ section: SongSheet.Section) -> some View {
        let tint = SongSectionMap.tint(of: section, in: sheet.sections, accent: accent)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                loopButton(section, tint: tint)
                Spacer(minLength: 4)
                speedPicker(section, tint: tint)
            }
            if let practice {
                Button {
                    let loop = SongSheet.Loop(section: section, speed: loopSpeed, bpm: (baseBpm * loopSpeed).rounded())
                    stopPlayback()
                    Haptics.shared.selection()
                    practice(loop)
                } label: {
                    Label("Practice this part", systemImage: "music.mic")
                        .font(Typeface.label(14)).foregroundStyle(Palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("song.section.practice")
            }
        }
        // A tap between the controls stays here rather than reaching the card (which would stop the loop).
        .contentShape(Rectangle())
        .onTapGesture {}
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func loopButton(_ section: SongSheet.Section, tint: Color) -> some View {
        let on = looping && selected == section.id
        return Button {
            if on { stopPlayback() } else { startLoop(section) }
        } label: {
            Label(on ? LocalizedStringKey("Stop") : LocalizedStringKey("Loop"), systemImage: on ? "stop.fill" : "repeat")
                .font(Typeface.label(14)).foregroundStyle(on ? Palette.onAccent : tint)
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, 14).frame(minHeight: 40)
                .background(Capsule().fill(on ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14))))
                .overlay(Capsule().strokeBorder(tint.opacity(on ? 0 : 0.45), lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("song.section.loop")
    }

    /// 50 %, 75 % and 100 % of the song's tempo; changing it restarts a running loop at the new speed.
    private func speedPicker(_ section: SongSheet.Section, tint: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(Self.speeds, id: \.self) { speed in
                let on = abs(loopSpeed - speed) < 0.01
                Button {
                    guard !on else { return }
                    Haptics.shared.selection()
                    loopSpeed = speed
                    if looping { startLoop(section) }
                } label: {
                    Text(verbatim: "\(Int((speed * 100).rounded()))%")
                        .font(Typeface.number(12)).foregroundStyle(on ? Palette.stage : Palette.inkSoft)
                        .padding(.horizontal, 9).frame(minHeight: 32)
                        .background { if on { Capsule().fill(Palette.ink) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(Int((baseBpm * speed).rounded())) BPM"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Palette.stage.opacity(0.6)))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .fixedSize()
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
                stopPlayback()
                Haptics.shared.selection()
                start()
            }
        }
    }

    /// One line at its own width (Start takes the rest), as wide for "Stop" as for its label, so it never wraps or
    /// jumps; "Preview" alone at the largest text sizes.
    private var previewButton: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let label: LocalizedStringKey = typeSize >= .xxLarge ? "Preview" : "Preview with band"
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
                ZStack(alignment: .leading) {
                    Text(label).hidden()
                    Text(previewing ? LocalizedStringKey("Stop") : label)
                }
                .lineLimit(1)
                .fixedSize()
            }
            .font(Typeface.label(15)).foregroundStyle(accent)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(shape.fill(accent.opacity(0.12)))
            .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .fixedSize(horizontal: true, vertical: false)
        .disabled(previewPhrase == nil)
        .accessibilityLabel(previewing ? Text("Stop") : Text("Preview with band"))
        .accessibilityIdentifier("song.preview")
    }

    private var previewRing: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(playStart)
            let fraction = previewSeconds > 0 ? min(1, max(0, elapsed / previewSeconds)) : 0
            Circle()
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }

    // MARK: Where the song is

    /// The tempo the lead sheet is counted in: the final take's, or (a song without one) its melody's.
    private var baseBpm: Double { sheet.finale.isEmpty && !chart.notes.isEmpty ? sheet.melodyBpm : sheet.bpm }

    /// Bars from the top of the song: through the picked section, round and round, while it loops; through the
    /// opening while the preview plays (a song mapped by its chords previews its melody instead, so it has none).
    private func position(at date: Date) -> Double? {
        let elapsed = max(0, date.timeIntervalSince(playStart))
        if looping, let id = selected, let section = sheet.sections.first(where: { $0.id == id }), loopPass > 0 {
            let within = elapsed.truncatingRemainder(dividingBy: loopPass) / loopPass
            return Double(section.start) + within * Double(section.bars)
        }
        guard previewing, !chart.notes.isEmpty else { return nil }
        let barSeconds = Double(chart.meter) * 60 / max(20, sheet.melodyBpm)
        let bar = elapsed / barSeconds
        return bar < Double(chart.bars) ? bar : nil
    }

    // MARK: Sound

    /// The course instrument's voice (nil: the app's selected instrument, as `playTones` falls back).
    private var voice: InstrumentVoice? { InstrumentVoice(instrumentId: course.instrument) }

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

    private func togglePreview() {
        if previewing { stopPlayback(); return }
        stopPlayback()
        guard let phrase = previewPhrase else { return }
        let meter = max(1, sheet.melodyMeter)
        let withBand = bandOn && store.audio.headphones
        // With the band, through the end of the last bar it plays, so it lands on its final chord.
        let bars = ((phrase.notes.map { $0.beat + $0.beats }.max() ?? Double(meter)) / Double(meter)).rounded(.up)
        let length = withBand ? max(phrase.duration, bars * Double(meter) * phrase.secondsPerBeat) : phrase.duration
        Haptics.shared.selection()
        Analytics.log("song_sheet_preview", ["lesson": lesson.id, "band": withBand ? "1" : "0"])
        playStart = Date()
        previewSeconds = length
        withAnimation(Motion.pluck) { previewing = true; sounding = nil }
        playTask = SongPlayback.start(SongPlayback.hits(phrase.notes), bpm: phrase.bpm, meter: meter, length: length,
                                      band: withBand ? band : nil, loop: false, audio: store.audio, voice: voice,
                                      reference: store.settings.referencePitchHz) {
            playTask = nil
            withAnimation(Motion.settle) { previewing = false }
        }
    }

    /// A tap on a section: loops it, or, on the one already looping, stops and lets it go.
    private func pick(_ section: SongSheet.Section) {
        if selected == section.id && looping {
            stopPlayback()
            withAnimation(reduceMotion ? nil : Motion.settle) { selected = nil }
            return
        }
        Haptics.shared.selection()
        startLoop(section)
    }

    /// The section round and round at `loopSpeed` (a whole tempo, so the click and the notes keep together): its
    /// melody, or its chords strummed on the song's pattern, over the band (on its own chords where the chart has
    /// them) in headphones.
    private func startLoop(_ section: SongSheet.Section) {
        stopPlayback()
        let chart = self.chart
        let meter = chart.meter
        let bpm = max(30, (baseBpm * loopSpeed).rounded())
        let chords = chart.filledChords(from: section.start, count: section.bars)
        let melody = chart.melody(from: section.start, count: section.bars)
        let hits = chart.notes.isEmpty ? strums(chords, meter: meter, pattern: chart.strokes) : SongPlayback.hits(melody)
        guard !hits.isEmpty else { return }
        let pass = Double(section.bars * meter) * 60 / bpm
        let withBand = bandOn && store.audio.headphones
        let loopBand = withBand ? SongPlayback.band(notes: melody, chords: chords, bars: section.bars, bpm: bpm, meter: meter,
                                                    reference: store.settings.referencePitchHz, bass: course.fretKind != "bass") : nil
        Analytics.log("song_sheet_loop", ["lesson": lesson.id, "speed": "\(Int((loopSpeed * 100).rounded()))"])
        loopPass = pass
        playStart = Date()
        withAnimation(reduceMotion ? nil : Motion.pluck) { looping = true; selected = section.id; sounding = nil }
        playTask = SongPlayback.start(hits, bpm: bpm, meter: meter, length: pass, band: loopBand, loop: true, audio: store.audio,
                                      voice: voice, reference: store.settings.referencePitchHz) {}
    }

    /// A chord section's bars strummed: each bar's chord on every stroke of the song's pattern (once a bar without one).
    private func strums(_ chords: [ChordSpec], meter: Int, pattern: [Double]) -> [SongPlayback.Hit] {
        let strokes = pattern.isEmpty ? [0.0] : pattern.sorted()
        var hits: [SongPlayback.Hit] = []
        for (bar, chord) in chords.enumerated() {
            let midis = tones(of: chord)
            guard !midis.isEmpty else { continue }
            for (index, stroke) in strokes.enumerated() {
                let next = index + 1 < strokes.count ? strokes[index + 1] : Double(meter)
                hits.append(SongPlayback.Hit(beat: Double(bar * meter) + stroke, beats: max(0.25, next - stroke), midis: midis))
            }
        }
        return hits
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        guard previewing || looping else { return }
        SongPlayback.stop(store.audio)
        withAnimation(Motion.settle) { previewing = false; looping = false }
    }

    /// The chord as shaped on the course instrument (as the lessons sound it); a plain triad without a shape.
    private func tones(of chord: ChordSpec) -> [Int] {
        let open = ChordStep.openStrings(course)
        let midis = chord.frets.enumerated().compactMap { i, fret -> Int? in fret >= 0 && i < open.count ? open[i] + fret : nil }
        if !midis.isEmpty { return midis }
        guard let target = ChordTarget(root: chord.root, formulaId: chord.quality) else { return [] }
        return target.quality.intervals.map { 48 + target.root + $0 }
    }

    private func strum(_ chord: ChordSpec) {
        stopPlayback()
        let midis = tones(of: chord)
        guard !midis.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        store.audio.playTones(midis.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1300,
                              voice: voice)
        Haptics.shared.selection()
        light(chord.symbol, for: 1.4)
    }

    private func pluck(_ midi: Int) {
        stopPlayback()
        store.audio.playTones([PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz)], together: false,
                              noteMs: 700, gapMs: 0, voice: voice)
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
