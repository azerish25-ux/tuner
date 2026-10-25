#if DEBUG
import SwiftUI
import TimbreCore

// Xcode previews of the design system's parts, on the stage they are drawn for. Each part is shown with no app state
// (no `AppStore`), so a preview never loads the catalogue or the curriculum; parts that read the store (the streak
// chip, the level ring, the reward toast) are seen in the app itself. Debug builds only.

/// The stage every preview sits on, in the app's one colour scheme.
private struct PreviewStage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .padding(Metrics.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.stage)
        .preferredColorScheme(.dark)
    }
}

/// A named swatch of one colour role.
private struct Swatch: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(color)
                .frame(width: 64, height: 40)
                .overlay(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            Text(verbatim: name).font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }
}

#Preview("Colour roles") {
    PreviewStage {
        SectionHeader(Text(verbatim: "Status"))
        HStack(spacing: 12) {
            Swatch(name: "mint", color: Palette.mint)
            Swatch(name: "adjust", color: Palette.adjust)
            Swatch(name: "danger", color: Palette.danger)
        }
        SectionHeader(Text(verbatim: "Categories and courses"))
        HStack(spacing: 12) {
            Swatch(name: "neutral", color: Palette.accentNeutral)
            Swatch(name: "violet", color: Palette.violet)
            Swatch(name: "sky", color: Palette.sky)
            Swatch(name: "orchid", color: Palette.orchid)
        }
        SectionHeader(Text(verbatim: "Rewards"))
        HStack(spacing: 12) {
            Swatch(name: "starGold", color: Palette.starGold)
            Swatch(name: "flame", color: Palette.flame)
            Swatch(name: "frost", color: Palette.frost)
        }
        SectionHeader(Text(verbatim: "Ink and lines"))
        HStack(spacing: 12) {
            Swatch(name: "ink", color: Palette.ink)
            Swatch(name: "inkSoft", color: Palette.inkSoft)
            Swatch(name: "inkFaint", color: Palette.inkFaint)
            Swatch(name: "control", color: Palette.controlLine)
        }
    }
}

#Preview("Type scale") {
    PreviewStage {
        ForEach(TypeStep.allCases, id: \.self) { step in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: "\(Int(step.points))").font(Typeface.number(.caption)).foregroundStyle(Palette.inkFaint)
                    .frame(width: 24, alignment: .trailing)
                Text(verbatim: "Still point").font(Typeface.display(step)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
        }
    }
}

#Preview("Glyphs") {
    PreviewStage {
        SectionHeader(Text(verbatim: "Drawn for Timbre"))
        HStack(spacing: 18) {
            ForEach(TimbreGlyph.allCases, id: \.self) { glyph in
                Glyph(glyph, size: Glyph.lead, tint: glyph == .lamp ? Palette.flame : Palette.inkSoft)
            }
        }
        SectionHeader(Text(verbatim: "The streak's lamp"))
        HStack(alignment: .bottom, spacing: 18) {
            ForEach([12, 14, 16, 18, 22, 28, 40] as [CGFloat], id: \.self) { size in
                Glyph(.lamp, size: size, tint: Palette.flame)
            }
            StageLamp(level: 1, size: 56)
        }
        SectionHeader(Text(verbatim: "Row glyphs"))
        HStack(spacing: 18) {
            Glyph("tuningfork")
            Glyph("ear", tint: Palette.accentNeutral)
            Glyph("checkmark", tint: Palette.mint)
            Glyph("bell", tint: Palette.violet)
            ProLock()
        }
    }
}

#Preview("Buttons") {
    PreviewStage {
        Button {} label: { Text(verbatim: "Start practice") }.buttonStyle(PrimaryButtonStyle())
        Button {} label: { Text(verbatim: "Start practice") }.buttonStyle(PrimaryButtonStyle()).disabled(true)
        Button {} label: { Text(verbatim: "Hear it") }.buttonStyle(SecondaryButtonStyle())
        Button {} label: { Text(verbatim: "Try again") }.buttonStyle(SecondaryButtonStyle(tint: Palette.violet))
        Button {} label: { Text(verbatim: "Continue") }.buttonStyle(GlassActionButtonStyle())
        HStack(spacing: 8) {
            Button {} label: { Text(verbatim: "Standard") }.buttonStyle(ChipButtonStyle(selected: true))
            Button {} label: { Text(verbatim: "Drop D") }.buttonStyle(ChipButtonStyle(selected: false))
            Button {} label: { Text(verbatim: "DADGAD") }.buttonStyle(ChipButtonStyle(selected: false)).disabled(true)
        }
        HStack(spacing: 8) {
            IconButton(symbol: "magnifyingglass") {}
            CloseButton {}
            BackButton {}
        }
    }
}

#Preview("Segmented pill") {
    @Previewable @State var minutes = 10
    PreviewStage {
        SegmentedPill(options: [5, 10, 15], selection: $minutes) { value in
            Text(verbatim: "\(value) min")
        }
    }
}

#Preview("Badges, tiles and the stat bar") {
    PreviewStage {
        HStack(spacing: 8) {
            Badge(.pro)
            Badge(Text(verbatim: "New"))
            Badge(Text(verbatim: "Save 58%"), style: .solid(Palette.mint))
        }
        StatTileRow {
            StatTile(symbol: "sparkles", tint: Palette.starGold, value: Text(verbatim: "+24"), label: Text(verbatim: "XP"), alignment: .center)
            StatTile(symbol: "target", tint: Palette.accentNeutral, value: Text(verbatim: "92%"), label: Text(verbatim: "accuracy"), alignment: .center)
            StatTile(value: Text(verbatim: "7"), label: Text(verbatim: "day streak"), alignment: .center) {
                Glyph(.lamp, size: 18, tint: Palette.flame)
            }
        }
        StatBar([
            StatBar.Figure(id: "streak", value: Text(verbatim: "7"), label: Text(verbatim: "day streak")) {
                Glyph(.lamp, size: Glyph.lead, tint: Palette.flame)
            },
            StatBar.Figure(id: "level", value: Text(verbatim: "LV 5"), label: Text(verbatim: "Sweet Spot")) {
                LevelArc(progress: 0.6, size: Glyph.lead)
            },
            StatBar.Figure(id: "cents", symbol: "scope", tint: Palette.inkSoft, value: Text(verbatim: "±0.8¢"), label: Text(verbatim: "Avg. cents off")),
        ])
    }
}

#Preview("Brand") {
    PreviewStage {
        TimbreLogotype(size: 28)
        TimbreLogotype(size: 15)
        TimbreLogotype(size: 15, ink: Palette.onAccent, monochrome: true)
            .padding(10)
            .background(Capsule().fill(Palette.mint))
        HStack(spacing: 18) {
            TimbreMark(height: 12)
            TimbreMark(height: 24)
            TimbreMark(height: 48)
        }
    }
}

#Preview("Medals and stars") {
    PreviewStage {
        HStack(spacing: 14) {
            ForEach(Array(Achievements.all.prefix(5))) { achievement in
                AchievementMedal(achievement: achievement, earned: true, size: 56)
            }
        }
        HStack(spacing: 14) {
            ForEach(Array(Achievements.all.prefix(5))) { achievement in
                AchievementMedal(achievement: achievement, earned: false, size: 56, progress: 0.4)
            }
        }
        HStack(alignment: .bottom, spacing: 14) {
            RewardStar(earned: true).frame(width: 71, height: 68)
            RewardStar(earned: true).frame(width: 94, height: 90)
            RewardStar(earned: false).frame(width: 71, height: 68)
        }
    }
}

#Preview("Empty and loading") {
    PreviewStage {
        EmptyState(symbol: "magnifyingglass", title: Text(verbatim: "No instrument matches “oud”."))
        StageSpinner()
        QuestPreviewRow()
    }
}

/// A quest row's look without the store: the glyph, the title, its bar and the reward words.
private struct QuestPreviewRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Glyph("tuningfork", size: Glyph.lead, tint: Palette.inkSoft)
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: "Tune every string").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                ProgressLine(value: 0.5, color: Palette.mint, height: 5)
            }
            Text(verbatim: "+20 XP").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
    }
}
#endif
