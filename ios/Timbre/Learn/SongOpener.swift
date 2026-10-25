import SwiftUI
import TimbreCore

/// The first screen of a song lesson, a song sheet. The zoom out of the song's sleeve (on the Songs shelf, Learn's
/// path) lands on that sleeve full size; once the screen has arrived, the sleeve settles into the sheet's head and
/// the sheet unfolds under it: key, tempo, meter and level; the chords the song asks for as small boxes that strum
/// when tapped (a melody's notes, for a song without chords); the song map (a whole arrangement's sections: intro,
/// verses, choruses, bridge, outro); and the lead sheet, bar by bar, with the chord symbols over the melody (or its
/// tab), the words under it and the hook marked. Tapping a section, on the map or the lead sheet, loops it, at 50, 75
/// or 100 % of the song's tempo, with a playhead through its bars; `practice`, when the host gives one, takes that
/// loop on to be played. "Preview with band" plays the song from its first verse (a whole arrangement's intro is
/// passed over, `SongPreview.excerpt`), else the opening of the take the lesson ends on, over the band (on the speaker
/// too: nothing is listening here). Start goes on to the lesson.
struct SongOpener: View {
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    /// The presentation carrying the lesson in has landed: the sleeve settles and the sheet unfolds only then.
    let arrived: Bool
    let start: () -> Void
    /// A section picked on the sheet, to practise on its own at its loop's speed; nil hides "Practice this part".
    var practice: ((SongSheet.Loop) -> Void)?
    /// Back from practising a part: it is picked again (at the same speed) and in view.
    var returning: SongSheet.Loop?
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(BandArrangement.preferenceKey) private var bandOn = true
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    /// What the lead sheet writes the melody as on a fretted course: staff, tab or both.
    @AppStorage(NotationMode.storageKey) private var notationMode: NotationMode = .both
    @State private var unfolded = false
    @State private var width: CGFloat = 390
    /// "Preview with band" is playing.
    @State private var previewing = false
    /// The picked section is looping.
    @State private var looping = false
    @State private var playTask: Task<Void, Never>?
    @State private var playStart = Date()
    @State private var previewSeconds = 0.0
    /// Where the preview starts, in bars from the top of the song, and how long a bar of it lasts.
    @State private var previewFrom = 0.0
    @State private var previewBarSeconds = 2.0
    /// The section picked on the map or the lead sheet, its loop's speed and how long one pass lasts.
    @State private var selected: Int?
    @State private var loopSpeed = 0.75
    @State private var loopPass = 0.0
    /// The chord (symbol) or note just tapped, lit while it sounds.
    @State private var sounding: String?

    /// The sleeve's side once settled in the sheet's head.
    private static let side: CGFloat = 112
    private static let margin: CGFloat = Metrics.gutter
    /// The sheet keeps to a readable measure on a wide screen.
    private static let measure: CGFloat = 860
    private static let speeds: [Double] = [0.5, 0.75, 1]
    /// Where a section's card comes to rest when the map (or a return from practice) brings it into view: its top
    /// near the top of the screen, as an engraved section runs several lines.
    private static let cardAnchor = UnitPoint(x: 0.5, y: 0.1)

    private var sheet: SongSheet { SongSheet.of(lesson) }
    private var chart: LeadChart { LeadChart.of(lesson) }
    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private var playing: Bool { previewing || looping }

    var body: some View {
        // The sleeve's light behind the head of the sheet is the lesson's to draw (`Backdrop`), from the top of the
        // screen: drawn here it began under the lesson's top bar, with an edge across the screen at its close button.
        ZStack(alignment: .top) {
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
                    .task {
                        // Back from practising a part: its card in view once the sheet has laid out.
                        guard let returning else { return }
                        try? await Task.sleep(for: .milliseconds(80))
                        proxy.scrollTo(returning.section.anchor, anchor: Self.cardAnchor)
                    }
                }
                actionBar
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear {
            if let clip = previewClip { store.audio.prepareBand(previewBand(clip)) }
            if arrived || reduceMotion { unfolded = true }
            if let returning, selected == nil {
                selected = returning.section.id
                loopSpeed = returning.speed
            }
        }
        .onChange(of: arrived) { _, landed in
            guard landed, !unfolded else { return }
            withAnimation(Motion.page) { unfolded = true }
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

    /// The sleeve's colours as a mesh of light behind the head of the sheet, fading out under it. The lesson draws it
    /// (`LessonPlayer`) behind its top bar and the sheet alike, from the top edge of the screen, so the light runs
    /// unbroken past the close button.
    struct Backdrop: View {
        let lesson: Lesson
        let course: LearnCourse

        var body: some View {
            CoverMesh(art: CoverArt.of(lesson, in: course))
                // The status bar, the lesson's top bar and the head of the sheet.
                .frame(height: 500)
                .opacity(0.5)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
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
    /// things: "Song 0:22 · Lesson 6 min"), and its XP (not in Calm mode).
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                CourseArt(course: course, size: 16)
                Eyebrow(Text(course.title.localized), color: accent, style: .display).lineLimit(1)
            }
            Text(lesson.title.localized).font(Typeface.display(.title)).tracking(-0.5).foregroundStyle(Palette.ink)
                .lineLimit(3).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text("Song \(sheet.length) · Lesson \(lesson.minutes) min")
                    .font(.subheadline).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
                // A reward, in the rewards' gold.
                if !store.settings.calmMode {
                    Text("+\(lesson.xp) XP").font(Typeface.label(.caption)).foregroundStyle(Palette.starGold)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.starGold.opacity(0.14)))
                        .fixedSize()
                }
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
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return VStack(alignment: .leading, spacing: 3) {
            Eyebrow(label, color: Palette.inkFaint, style: .display)
                .lineLimit(1).minimumScaleFactor(0.7)
            value.font(Typeface.display(.body)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.tilePadding)
        .background(shape.fill(Palette.stageRaised.opacity(0.9)))
        .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
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
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { strum(chord) } label: {
            VStack(spacing: 8) {
                MiniChordGlyph(chord: chord, accent: accent, lit: lit)
                    .frame(width: 54, height: 64)
                Text(verbatim: chord.name).font(Typeface.display(17))
                    .foregroundStyle(lit ? accent : Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(minWidth: 62)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
            .background(shape.fill(lit ? accent.opacity(0.16) : Palette.stageRaised))
            .overlay(shape.strokeBorder(lit ? accent.opacity(0.6) : Palette.hairline, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .animation(reduceMotion ? nil : Motion.quick, value: lit)
        .accessibilityLabel(Text("\(chord.name) chord"))
        .accessibilityHint(Text("Hear it"))
    }

    private func noteChip(_ midi: Int) -> some View {
        let lit = sounding == "\(midi)"
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { pluck(midi) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: NoteName.pitchClass(midi)).font(Typeface.display(.headline))
                Text(verbatim: "\(midi / 12 - 1)").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
            }
            // The octave after its letter in every language ("E3", never "3E" in Arabic).
            .environment(\.layoutDirection, .leftToRight)
            .foregroundStyle(lit ? accent : Palette.ink)
            .frame(minWidth: 46, minHeight: 46)
            .padding(.horizontal, 6)
            .background(shape.fill(lit ? accent.opacity(0.16) : Palette.stageRaised))
            .overlay(shape.strokeBorder(lit ? accent.opacity(0.6) : Palette.hairline, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text(verbatim: NoteNames.spokenInApp(NoteName.name(midi))))
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
                BandControls(audio: store.audio, accent: accent, speaker: .fullBand)
            }
            SongSectionMap(sections: sheet.sections, bars: sheet.bars, accent: accent,
                           progress: position.map { $0 / Double(max(1, sheet.bars)) }, bleed: Self.margin, selected: selected) { section in
                pick(section)
                withAnimation(reduceMotion ? nil : Motion.settle) { proxy.scrollTo(section.anchor, anchor: Self.cardAnchor) }
            }
            .accessibilityIdentifier("song.map")
        }
    }

    // MARK: Lead sheet

    @ViewBuilder private func leadSheet(_ position: Double?) -> some View {
        let tabbed = EngravedSheet.hasTab(lesson: lesson, course: course)
        let inner = max(120, min(width, Self.measure) - Self.margin * 2 - EngravedSheet.cardInset * 2)
        let engraved = EngravedSheet.of(lesson: lesson, course: course, mode: tabbed ? notationMode : .staff, width: inner,
                                        textScale: textScale, thinnestOnTop: stringOrder.thinnestOnTop)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                heading("Lead sheet", detail: engraved.swing ? Text("\(sheet.meterName) · Swing") : Text(verbatim: sheet.meterName))
                Spacer(minLength: 8)
                if tabbed { NotationModePicker(mode: $notationMode) }
            }
            if let words = sheet.arrangement?.words {
                // Who wrote the words the sheet sets under the melody: Timbre's own for an Original, words and music;
                // a public-domain song keeps its real credit.
                let original = SongOfTheDay.isOriginals(course) || words.defaultValue == "Timbre"
                Group {
                    if original {
                        Text("Words & music · Timbre Originals")
                    } else {
                        Text("Words: \(words.localized)")
                    }
                }
                .font(.footnote).foregroundStyle(Palette.inkFaint)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                .padding(.top, -6)
            }
            LeadSheetView(chart: chart, sections: sheet.sections, accent: accent, engraved: engraved, position: position,
                          selected: selected, onSelect: { section in pick(section) },
                          controls: { section in loopControls(section) })
                .animation(reduceMotion ? nil : Motion.settle, value: notationMode)
        }
        .accessibilityIdentifier("song.leadsheet")
    }

    /// The words and chord symbols grow a little with the reader's text size (the staff keeps its scale).
    private var textScale: CGFloat {
        switch typeSize {
        case .xSmall, .small, .medium, .large: return 1
        case .xLarge: return 1.08
        case .xxLarge: return 1.16
        case .xxxLarge: return 1.24
        default: return 1.32
        }
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
            if let practice, section.part != nil, !sheet.loopMelody(section).isEmpty {
                Button {
                    let loop = SongSheet.Loop(section: section, speed: loopSpeed, bpm: (baseBpm * loopSpeed).rounded())
                    stopPlayback()
                    Haptics.shared.selection()
                    practice(loop)
                } label: {
                    Label("Practice this part", systemImage: "music.mic")
                        .font(Typeface.label(.body)).foregroundStyle(Palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
                        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(tint))
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
                .font(Typeface.label(.body)).foregroundStyle(on ? Palette.onAccent : tint)
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, 14).frame(minHeight: Metrics.minTarget)
                .background(Capsule().fill(on ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14))))
                .overlay(Capsule().strokeBorder(tint.opacity(on ? 0 : 0.45), lineWidth: 1))
                .fixedSize()
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("song.section.loop")
    }

    /// 50 %, 75 % and 100 % of the song's tempo, as a segmented pill; changing it restarts a running loop at the new
    /// speed. Each segment reads as its tempo ("60 BPM").
    private func speedPicker(_ section: SongSheet.Section, tint: Color) -> some View {
        let speed = Binding<Double>(
            get: { loopSpeed },
            set: { value in
                loopSpeed = value
                if looping { startLoop(section) }
            })
        return SegmentedPill(options: Self.speeds, selection: speed) { value in
            Text(verbatim: "\(Int((value * 100).rounded()))%")
                .font(Typeface.number(12))
                .accessibilityLabel(Text("\(Int((baseBpm * value).rounded())) BPM"))
        }
        .fixedSize()
    }

    private func heading(_ title: LocalizedStringKey, detail: Text?) -> some View {
        HStack(spacing: 8) {
            Eyebrow(title, color: accent, style: .display)
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
            StepButton(title: "Start", inset: false) {
                stopPlayback()
                Haptics.shared.selection()
                start()
            }
        }
    }

    /// One line at its own width (Start takes the rest), as wide for "Stop" as for its label, so it never wraps or
    /// jumps; "Preview" alone at the largest text sizes. The secondary button's capsule, height and type, washed in
    /// the accent.
    private var previewButton: some View {
        let shape = Capsule()
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
            .font(Typeface.button).foregroundStyle(accent)
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.buttonHeight)
            .background(shape.fill(accent.opacity(0.12)))
            .overlay(shape.strokeBorder(accent.opacity(0.4), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .fixedSize(horizontal: true, vertical: false)
        .disabled(previewClip == nil)
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
    /// stretch the preview plays while it plays (a song mapped by its chords previews its melody instead, so it has
    /// none).
    private func position(at date: Date) -> Double? {
        let elapsed = max(0, date.timeIntervalSince(playStart))
        if looping, let id = selected, let section = sheet.sections.first(where: { $0.id == id }), loopPass > 0 {
            let within = elapsed.truncatingRemainder(dividingBy: loopPass) / loopPass
            return Double(section.start) + within * Double(section.bars)
        }
        guard previewing, !chart.notes.isEmpty else { return nil }
        let bar = previewFrom + elapsed / max(0.1, previewBarSeconds)
        return bar < Double(chart.bars) ? bar : nil
    }

    // MARK: Sound

    /// The course instrument's voice (nil: the app's selected instrument, as `playTones` falls back).
    private var voice: InstrumentVoice? { InstrumentVoice(instrumentId: course.instrument) }

    /// What "Preview with band" plays: notes from beat 0 of bar `firstBar`, `bars` whole bars, at `bpm`.
    private struct PreviewClip {
        let notes: [TimedNote]
        let firstBar: Int
        let bars: Int
        let bpm: Double
        let meter: Int
    }

    /// A whole arrangement from its first verse (`SongPreview.excerpt`): four bars, eight when they hold few notes,
    /// twenty seconds at most. Without one, the take's first four bars (eight when they hold few notes), at its tempo.
    private var previewClip: PreviewClip? {
        let sheet = self.sheet
        if sheet.arrangement != nil, let four = SongPreview.excerpt(of: lesson, bars: 4) {
            let clip = four.notes.count >= 5 ? four : (SongPreview.excerpt(of: lesson, bars: 8) ?? four)
            return PreviewClip(notes: clip.notes, firstBar: clip.firstBar, bars: clip.bars, bpm: clip.bpm, meter: clip.beatsPerBar)
        }
        let meter = max(1, sheet.melodyMeter)
        guard !sheet.melody.isEmpty else { return nil }
        let four = sheet.melody.filter { $0.beat < 4 * Double(meter) }
        let notes = four.count >= 5 ? four : sheet.melody.filter { $0.beat < 8 * Double(meter) }
        guard !notes.isEmpty else { return nil }
        let end = notes.map { $0.beat + $0.beats }.max() ?? Double(meter)
        let bars = max(1, Int((end / Double(meter) - 1e-6).rounded(.up)))
        return PreviewClip(notes: notes, firstBar: 0, bars: bars, bpm: sheet.melodyBpm, meter: meter)
    }

    /// The band under the preview, exactly its bars long: the chart's chords over them, change by change, where it has
    /// them.
    private func previewBand(_ clip: PreviewClip) -> BandArrangement {
        let harmony = chart.notes.isEmpty ? [] : chart.filledBars(from: clip.firstBar, count: clip.bars)
        return SongPlayback.band(notes: clip.notes, harmony: harmony, bars: clip.bars, bpm: clip.bpm, meter: clip.meter,
                                 reference: store.settings.referencePitchHz, bass: course.fretKind != "bass")
    }

    private func togglePreview() {
        if previewing { stopPlayback(); return }
        stopPlayback()
        guard let clip = previewClip else { return }
        let withBand = bandOn
        let spb = 60 / max(20, clip.bpm)
        // Over the band, whole bars from the clip's first, landing on its final chord; alone, from its first note
        // (no lead-in rest before an upbeat).
        let offset = withBand ? 0 : (clip.notes.first?.beat ?? 0)
        let notes = clip.notes.map { TimedNote(midi: $0.midi, beat: $0.beat - offset, beats: $0.beats, at: $0.at) }
        let end = notes.map { $0.beat + $0.beats }.max() ?? 0
        let length = (withBand ? max(end, Double(clip.bars * clip.meter)) : end) * spb
        Haptics.shared.selection()
        Analytics.log("song_sheet_preview", ["lesson": lesson.id, "band": withBand ? "1" : "0"])
        playStart = Date()
        previewSeconds = length
        previewBarSeconds = Double(clip.meter) * spb
        previewFrom = Double(clip.firstBar) + offset / Double(max(1, clip.meter))
        withAnimation(Motion.pluck) { previewing = true; sounding = nil }
        playTask = SongPlayback.start(SongPlayback.hits(notes), bpm: clip.bpm, meter: clip.meter, length: length,
                                      band: withBand ? previewBand(clip) : nil, loop: false, audio: store.audio, voice: voice,
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
    /// melody (an arrangement's section with the upbeat it starts on closing each pass), or its chords strummed on
    /// the song's pattern, over the band (on its own chords where the chart has them).
    private func startLoop(_ section: SongSheet.Section) {
        stopPlayback()
        let chart = self.chart
        let meter = chart.meter
        let bpm = max(30, (baseBpm * loopSpeed).rounded())
        let harmony = chart.filledBars(from: section.start, count: section.bars)
        let melody = section.part != nil ? sheet.loopMelody(section) : chart.melody(from: section.start, count: section.bars)
        let hits = chart.notes.isEmpty ? strums(harmony.map(\.downbeat), meter: meter, pattern: chart.strokes) : SongPlayback.hits(melody)
        guard !hits.isEmpty else { return }
        let pass = Double(section.bars * meter) * 60 / bpm
        let withBand = bandOn
        let loopBand = withBand ? SongPlayback.band(notes: melody, harmony: harmony, bars: section.bars, bpm: bpm, meter: meter,
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
            .animation(calm ? nil : Motion.page.delay(0.08 * Double(order)), value: shown)
    }
}
