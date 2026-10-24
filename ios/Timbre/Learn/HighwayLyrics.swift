import SwiftUI
import TimbreCore

/// The song's words under the play-along stage, karaoke style: the line being sung bright, its sung syllables in ink,
/// the syllable on the note sounding now in the accent, the ones still to come soft, and the next line dim beneath.
/// Between lines (an intro, a solo) only the next line shows, dim, until a beat before it is sung. `beat` is the take's
/// clock in beats from its first bar (nil before a take: the first line waits). Lines slide up as they change (a
/// crossfade with Reduce Motion). Takes the same height whatever it shows, so the stage above never moves.
struct HighwayLyrics: View {
    let sheet: LyricSheet
    let beat: Double?
    let accent: Color
    /// The section playing ("Chorus"), over the words; nil leaves the row out.
    var section: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cue: LyricSheet.Cue {
        guard let beat else { return LyricSheet.Cue(line: nil, syllable: nil, next: sheet.isEmpty ? nil : 0) }
        return sheet.cue(atBeat: beat)
    }

    var body: some View {
        let cue = self.cue
        VStack(spacing: 3) {
            if let section {
                Text(verbatim: section)
                    .font(Typeface.label(11))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : Motion.quick, value: section)
            }
            ZStack {
                topRow(cue)
                    .id(topKey(cue))
                    .transition(lineTransition)
            }
            .frame(maxWidth: .infinity, minHeight: 26)
            .clipped()
            ZStack {
                bottomRow(cue)
                    .id(bottomKey(cue))
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, minHeight: 18)
        }
        .animation(reduceMotion ? Animation.easeOut(duration: 0.15) : Motion.settle, value: topKey(cue))
        .multilineTextAlignment(.center)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Lyrics"))
        .accessibilityValue(Text(verbatim: spoken(cue)))
    }

    // MARK: Rows

    /// The line in the light, syllable by syllable; between lines, the next one waiting, dim.
    @ViewBuilder private func topRow(_ cue: LyricSheet.Cue) -> some View {
        if let index = cue.line, sheet.lines.indices.contains(index) {
            Text(sung(sheet.lines[index], upTo: cue.syllable))
                .font(Typeface.display(19, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else if let next = cue.next, sheet.lines.indices.contains(next) {
            Text(verbatim: sheet.lines[next].text)
                .font(Typeface.display(19, relativeTo: .title3))
                .foregroundStyle(Palette.inkSoft.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    /// Under the line being sung: the one after it, dim.
    @ViewBuilder private func bottomRow(_ cue: LyricSheet.Cue) -> some View {
        if cue.line != nil, let next = cue.next, sheet.lines.indices.contains(next) {
            Text(verbatim: sheet.lines[next].text)
                .font(.subheadline)
                .foregroundStyle(Palette.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private func topKey(_ cue: LyricSheet.Cue) -> Int {
        if let line = cue.line { return line * 2 }
        return (cue.next ?? sheet.lines.count) * 2 + 1
    }

    private func bottomKey(_ cue: LyricSheet.Cue) -> Int { cue.line == nil ? -1 : (cue.next ?? -2) }

    private var lineTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                              removal: .move(edge: .top).combined(with: .opacity))
    }

    /// The line's syllables coloured by where the song is: sung in ink, the one sounding in the accent, the rest soft.
    private func sung(_ line: LyricSheet.Line, upTo current: Int?) -> AttributedString {
        var out = AttributedString()
        for (index, syllable) in line.syllables.enumerated() {
            let gap = syllable.joinsNext || index == line.syllables.count - 1 ? "" : " "
            var piece = AttributedString(syllable.text + gap)
            if let current, index < current {
                piece.foregroundColor = Palette.ink
            } else if let current, index == current {
                piece.foregroundColor = accent
            } else {
                piece.foregroundColor = Palette.inkSoft
            }
            out += piece
        }
        return out
    }

    private func spoken(_ cue: LyricSheet.Cue) -> String {
        if let index = cue.line ?? cue.next, sheet.lines.indices.contains(index) { return sheet.lines[index].text }
        return ""
    }
}
