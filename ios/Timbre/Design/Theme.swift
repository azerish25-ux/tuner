import SwiftUI
import UIKit

// Also compiled into the widget extension (project.yml): tokens only, SwiftUI and UIKit, nothing app-only.

/// "Studio Noir" design tokens: a near-black stage, and colour that only ever means one thing.
/// The app is dark by design; names are kept from the earlier palette so every screen restyles at once.
///
/// The colour rule:
/// - Status is exclusive. Mint means in tune, correct or go (and so every primary button is mint), amber means
///   adjust, coral means wrong. Nothing else is drawn in those three: a course, a lane or a sleeve never is.
/// - Course hues (`accent(_:)`: mint, sky, violet, orchid, lime) only tint what a course owns: its art, its eyebrow,
///   its progress. Never a primary button, never a status.
/// - Rewards keep their own: `flame` for the streak, gold (`proGold`, `starFill`) for Timbre Pro and stars.
/// - Glow means live: listening, locked, playing (`liveGlow`, Kit.swift). A button at rest is flat.
///
/// Contrast: `inkSoft`, `inkFaint`, `line`, `controlLine` and `hairline` follow Increase Contrast (Settings ›
/// Accessibility › Display & Text Size), so every screen answers it without reading the setting itself. With it on,
/// `inkFaint` is at least 4.5:1 on every card surface and `line`/`controlLine` at least 3:1 on the stage and cards.
enum Palette {
    // Stage
    static let stage = Color(hex: 0x060708)
    static let stageRaised = Color(hex: 0x111317)
    static let stageDeep = Color(hex: 0x020303)
    static let surface = Color(hex: 0x16191E)
    /// Dividers between rows and sections (decoration). Increase Contrast: 3:1 on the stage, cards and `surface`.
    static let line = adaptive(0x24272D, high: 0x60666F)
    /// The boundary of a control that sits on the stage or a card: an unselected chip, a search field, a secondary
    /// button, a segmented track, a resting string chip. About 3:1 on `surface` and the stage without Increase
    /// Contrast (WCAG 1.4.11), brighter still with it.
    static let controlLine = adaptive(0x5A606A, high: 0x7A808A)
    /// A card's border: white at 6% (14% with Increase Contrast). `stillCard` draws it.
    static let hairline = Color(uiColor: UIColor { traits in
        UIColor(white: 1, alpha: traits.accessibilityContrast == .high ? 0.14 : 0.06)
    })
    // Ink
    static let ink = Color(hex: 0xF5F3EF)
    /// Secondary text: 7.8:1 on a card (11.2:1 with Increase Contrast).
    static let inkSoft = adaptive(0xA3A8B1, high: 0xC4C9D1)
    /// Tertiary text (captions, footers, disabled labels): 4.6:1 even on `line`, 5.8:1 on a card
    /// (7.8:1 with Increase Contrast).
    static let inkFaint = adaptive(0x8A9099, high: 0xA3A8B1)
    // Status: mint is in tune, correct and go (every primary action), amber is adjust, coral is wrong.
    static let mint = Color(hex: 0x4CF2B8)
    static let mintDeep = Color(hex: 0x1A8F69)
    static let amber = Color(hex: 0xFFB547)
    static let coral = Color(hex: 0xFF7E6B)
    /// The streak's own colour (a habit, not a status).
    static let flame = Color(hex: 0xFF9F43)
    /// A category's tint where no course owns it (a Today activity, a tool, a difficulty): a cool steel that reads as
    /// a colour beside `inkSoft` without meaning in tune, adjust or wrong. 9:1 on `surface`.
    static let accentNeutral = Color(hex: 0xB4BECB)
    /// Course hues: they tint what a course owns, never a status or a primary button.
    static let violet = Color(hex: 0xA592FF)
    static let sky = Color(hex: 0x62C9FF)
    static let orchid = Color(hex: 0xE38ADB)
    static let lime = Color(hex: 0xC4E86B)
    /// A course's hue by its name in the curriculum. The curriculum's older names for warm courses ("amber",
    /// "coral") would draw a course in a status colour, so they map onto the course hues instead.
    static func accent(_ name: String) -> Color {
        switch name {
        case "violet": return violet
        case "sky": return sky
        case "orchid", "amber": return orchid
        case "lime", "coral": return lime
        default: return mint
        }
    }
    /// Dark text on mint (and the other course accents).
    static let onAccent = Color(hex: 0x04130D)
    /// Dark text and glyphs on gold (`proGold`, `starFill`): the one "dark on gold" ink.
    static let onGold = Color(hex: 0x1B1206)
    // Light and rewards
    /// The warm stage light: `StageBackground`'s glow and hero washes.
    static let spotlight = Color(hex: 0xFFC48C)
    /// Streak numbers and words on the flame's warm wash.
    static let flameInk = Color(hex: 0xFFD3A8)
    /// Streak freezes: the snowflakes and the "streak saved" pill.
    static let frost = Color(hex: 0x9FD8FF)
    /// Rewards and roots as one colour: a star's glow and outline, a reward's burst or tile, a chord's or scale's root
    /// note. Gold, so a reward never borrows the status amber.
    static let starGold = Color(hex: 0xF0A93B)
    /// A star's fill, lit from the top.
    static let starFill = LinearGradient(colors: [Color(hex: 0xFFE29A), starGold], startPoint: .top, endPoint: .bottom)
    /// The deep end of Timbre Pro gold, as one colour.
    static let proGoldDeep = Color(hex: 0xE39A3B)
    // Earlier names, mapped onto the new system. They hide which colour you get (brass is mint, ember is amber):
    // rename them as you touch a file.
    @available(*, deprecated, renamed: "mint")
    static let brass = mint
    @available(*, deprecated, renamed: "mintDeep")
    static let brassDeep = mintDeep
    @available(*, deprecated, renamed: "amber")
    static let ember = amber
    // Pitch meaning: mint inside the tolerance, amber when close, coral when far (always with words too).
    static let flat = amber
    static let sharp = amber
    static let locked = mint
    static let success = mint
    /// Wrong, missed, destructive: the one red, so an error never comes in two shades.
    static let danger = coral
    /// Timbre Pro gold.
    static let proGold = LinearGradient(colors: [Color(hex: 0xFFD08A), proGoldDeep], startPoint: .top, endPoint: .bottom)

    /// Past this many cents a pitch is "far" (coral) rather than "close" (amber).
    static let nearCents = 20.0

    /// The pitch colour rule: mint inside `band` (or once locked), amber out to `nearCents`, coral beyond.
    /// Cents are judged to the whole cent, as every readout shows them, so a digit and its colour never disagree.
    /// The tuner passes the tracker's own lock band (`Palette.tuningBand`, set by Precision in Settings), so the colour turns mint exactly where it can lock.
    static func pitch(_ cents: Double?, locked: Bool, band: Double) -> Color {
        guard let cents, cents.isFinite else { return inkSoft }
        let shown = abs(cents.rounded())
        if locked || shown <= band { return mint }
        return shown <= nearCents ? amber : coral
    }

    /// Off-target colour for screens that judge their own tolerance first (intonation, voice):
    /// mint once locked, amber otherwise. The tuner uses the three-zone rule above.
    static func pitch(_ cents: Double?, locked: Bool) -> Color {
        guard cents != nil else { return inkSoft }
        return locked ? mint : amber
    }

    /// `base`, or `high` while Increase Contrast is on. Resolved by SwiftUI from the environment, so a view never
    /// has to read `colorSchemeContrast` for these tokens.
    static func adaptive(_ base: UInt, high: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.accessibilityContrast == .high ? high : base)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt) { self.init(uiColor: UIColor(hex: hex)) }
}

extension Font.TextStyle {
    /// The text style whose size is nearest `size` from below, so a custom size scales on that style's curve.
    /// A 16 pt heading then grows like the headline it sits over, never slower than the body text under it
    /// (scaled against `.largeTitle` it reached ≈28 pt at AX5 while a subheadline reached ≈49 pt).
    static func matching(_ size: CGFloat) -> Font.TextStyle {
        switch size {
        case ...11.5: return .caption2
        case ...12.5: return .caption
        case ...13.5: return .footnote
        case ...15.5: return .subheadline
        case ...17.5: return .headline
        case ...21: return .title3
        case ...25: return .title2
        case ...31: return .title
        default: return .largeTitle
        }
    }
}

/// The type scale: eight steps, plus the hero numeral above them. Every size of type in the app is one of these;
/// CI rejects a `Typeface` size off the scale (`isOnScale`). Each step grows with Dynamic Type on its own text style's
/// curve.
///
/// | Step       | pt | Curve         | For                                                      |
/// |------------|----|---------------|----------------------------------------------------------|
/// | `caption`  | 12 | `.caption`    | badges, eyebrows, counters under a figure                |
/// | `footnote` | 13 | `.footnote`   | captions, chips, small labels                            |
/// | `body`     | 15 | `.subheadline`| a row's text, chord names in a strip                     |
/// | `headline` | 17 | `.headline`   | card titles, buttons, values in a row                    |
/// | `title3`   | 20 | `.title3`     | section titles, a tile's figure                          |
/// | `title`    | 28 | `.title`      | screen and step titles, a card's lead line               |
/// | `display`  | 40 | `.largeTitle` | a celebration's headline, a big note in a card           |
/// | `hero`     | 64 | `.largeTitle` | the big figures (a score, a note to sing)                |
///
/// Above 64 is the hero numeral (`Typeface.hero`, the tuner's note, a count-in), sized to its stage and clamped
/// with `heroNumeral()`. Art drawn to the size of its picture (a sleeve's title, a dial's ticks) sets its own size
/// with `Font.custom(_:fixedSize:)`, outside the scale.
enum TypeStep: CaseIterable, Sendable {
    case caption, footnote, body, headline, title3, title, display, hero

    var points: CGFloat {
        switch self {
        case .caption: return 12
        case .footnote: return 13
        case .body: return 15
        case .headline: return 17
        case .title3: return 20
        case .title: return 28
        case .display: return 40
        case .hero: return 64
        }
    }

    /// The text style whose Dynamic Type curve the step follows.
    var style: Font.TextStyle {
        switch self {
        case .caption: return .caption
        case .footnote: return .footnote
        case .body: return .subheadline
        case .headline: return .headline
        case .title3: return .title3
        case .title: return .title
        case .display, .hero: return .largeTitle
        }
    }

    /// Every step's size, smallest first.
    static let scale: [CGFloat] = allCases.map(\.points)

    /// Whether `size` is a step of the scale, or a hero numeral above it.
    static func isOnScale(_ size: CGFloat) -> Bool {
        size > TypeStep.hero.points || scale.contains(size)
    }

    /// The step nearest `size` (the smaller one on a tie, so nothing grows past the room it was given).
    static func nearest(_ size: CGFloat) -> TypeStep {
        var best = TypeStep.caption
        for step in allCases where abs(step.points - size) < abs(best.points - size) { best = step }
        return best
    }
}

/// Sora for headings, note names, numbers and button labels; body text stays in the system font.
///
/// Sizes come from the type scale (`TypeStep`): pass a step (`Typeface.display(.title)`) or use a role below. The
/// functions taking points remain for the hero numeral and for sizes moving onto the scale; CI rejects a literal off
/// it. Each scales with Dynamic Type on its step's curve (or the curve of the text style nearest the size, or the one
/// `relativeTo:` names).
///
/// Bold Text: with Settings › Accessibility › Display & Text Size › Bold Text on, every face is drawn one weight
/// heavier (Light as Medium, Medium as SemiBold, SemiBold as Bold), as the system font bolds. `boldTextAware()`
/// (Kit.swift) at the root of each window keeps `boldText` in step with the environment's `legibilityWeight`.
enum Typeface {
    /// The Sora faces the app bundles, lightest first.
    enum Face: Sendable {
        case light, medium, semiBold, bold

        var fontName: String {
            switch self {
            case .light: return "Sora-Light"
            case .medium: return "Sora-Medium"
            case .semiBold: return "Sora-SemiBold"
            case .bold: return "Sora-Bold"
            }
        }

        /// One weight heavier, for Bold Text (Bold stays Bold: it is the heaviest bundled).
        var heavier: Face {
            switch self {
            case .light: return .medium
            case .medium: return .semiBold
            case .semiBold, .bold: return .bold
            }
        }
    }

    /// Bold Text is on. Set on the main thread from the environment (`boldTextAware()`); read while views draw.
    nonisolated(unsafe) static var boldText = false

    /// `face` at `size`, one weight heavier under Bold Text.
    static func sora(_ face: Face, _ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        let shown = boldText ? face.heavier : face
        return .custom(shown.fontName, size: size, relativeTo: style ?? .matching(size))
    }

    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        sora(.semiBold, size, relativeTo: style)
    }
    /// The big note name.
    static func note(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        sora(.medium, size, relativeTo: style)
    }
    static func displayLight(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        sora(.light, size, relativeTo: style)
    }
    /// Earlier name for the light display face.
    static func displayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font { displayLight(size, relativeTo: style) }
    /// Cents, hertz, tempo, scores.
    static func number(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        sora(.medium, size, relativeTo: style).monospacedDigit()
    }
    static func label(_ size: CGFloat, relativeTo style: Font.TextStyle? = nil) -> Font {
        sora(.semiBold, size, relativeTo: style)
    }
    /// Hero numerals (a score, the BPM, a big counter): Sora Medium on the gentlest curve, `.largeTitle`.
    /// Clamp policy: pair it with `.heroNumeral()` (Kit.swift), which keeps the numeral on one line, lets it
    /// shrink to fit its ring or row, and stops it growing past AX1.
    static func hero(_ size: CGFloat) -> Font { number(size, relativeTo: .largeTitle) }

    // MARK: On the scale

    static func display(_ step: TypeStep) -> Font { display(step.points, relativeTo: step.style) }
    static func note(_ step: TypeStep) -> Font { note(step.points, relativeTo: step.style) }
    static func displayLight(_ step: TypeStep) -> Font { displayLight(step.points, relativeTo: step.style) }
    static func number(_ step: TypeStep) -> Font { number(step.points, relativeTo: step.style) }
    static func label(_ step: TypeStep) -> Font { label(step.points, relativeTo: step.style) }

    // MARK: Roles: one size and one curve per job

    /// A tab's or screen's title ("Learn", "Practice"): `TabHeader`, `ScreenTitle`.
    static var screenTitle: Font { display(TypeStep.title.points, relativeTo: .largeTitle) }
    /// A lesson step's title, the same on every kind of step.
    static var stepTitle: Font { display(.title) }
    /// A section between cards ("Achievements", "Tunings"): `SectionHeader`.
    static var sectionTitle: Font { display(.title3) }
    /// A title inside a card ("Today", "Coach"): `CardTitle`.
    static var cardTitle: Font { display(.headline) }
    /// Every primary and secondary button's label.
    static var button: Font { label(.headline) }
    /// An eyebrow in the display face (`Eyebrow(style: .display)`).
    static var eyebrowDisplay: Font { label(.caption) }
    /// Small capitals on a badge ("PRO", "SAVE 58%") and the captions under the tuner's side controls.
    static var badge: Font { label(TypeStep.caption.points, relativeTo: .caption2) }
    static var eyebrow: Font { Font.system(.caption, design: .default).weight(.semibold) }
}

enum Metrics {
    /// Every screen edge and every bottom button.
    static let gutter: CGFloat = 20
    /// Extra side room for a centred paragraph, on top of the gutter.
    static let proseInset: CGFloat = 8

    // Corner radii: heroes, cards, tiles (rows, buttons, answers), small icon tiles.
    static let cornerHero: CGFloat = 28
    static let corner: CGFloat = 22
    static let cornerTile: CGFloat = 16
    static let cornerChip: CGFloat = 12
    @available(*, deprecated, renamed: "cornerTile")
    static let cornerSmall: CGFloat = 16

    // Insets: inside a card (`stillCard`'s default) and inside a tile.
    static let cardPadding: CGFloat = 18
    static let tilePadding: CGFloat = 12

    /// The smallest thing a finger should have to hit.
    static let minTarget: CGFloat = 44
    /// Primary and secondary buttons.
    static let buttonHeight: CGFloat = 54
}

/// Motion tokens. Reduce Motion policy (helpers in Kit.swift):
/// - Movement (springs that slide, scale, rotate or morph; page and step changes) becomes `Motion.reduced`, and
///   slide or scale transitions become `.opacity`: use `Motion.adaptive`, `withMotion`, `.adaptiveAnimation`
///   or `AnyTransition.adaptive`.
/// - Pure fades and colour changes (`fade`, `reveal`, `quick` on opacity) are kept as they are.
/// - Loops (motes, flickers, pulses, a `TimelineView` that only decorates) stop and hold a still frame.
enum Motion {
    /// The "pluck": a fast attack and a damped settle, used across the app.
    static let pluck = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let settle = Animation.spring(response: 0.6, dampingFraction: 0.9)
    static let quick = Animation.snappy(duration: 0.22)
    /// The reward pill growing out of the Dynamic Island: quick, with a little overshoot.
    static let island = Animation.spring(response: 0.46, dampingFraction: 0.7)
    /// The reward pill folding back into the island: no overshoot.
    static let islandClose = Animation.spring(response: 0.34, dampingFraction: 1)
    /// Steps and pages: a lesson step, an onboarding page, the song sheet's parts.
    static let page = Animation.spring(response: 0.5, dampingFraction: 0.86)
    /// Combo counts, answers, nudges: fast, with a bounce.
    static let pop = Animation.spring(response: 0.22, dampingFraction: 0.55)
    /// Stars, badges, a streak's number: a celebratory overshoot.
    static let reward = Animation.spring(response: 0.45, dampingFraction: 0.58)
    /// A hero's slow, soft entrance (the paywall's runway).
    static let hero = Animation.spring(response: 0.9, dampingFraction: 0.85)
    /// Fades and crossfades (opacity only).
    static let fade = Animation.easeOut(duration: 0.25)
    /// The slow crossfade of a big change of scene (the studio giving way to the 3D stage).
    static let reveal = Animation.easeInOut(duration: 0.6)
    /// What any movement becomes under Reduce Motion: short, no overshoot.
    static let reduced = Animation.easeOut(duration: 0.2)

    /// `animation`, or `reduced` under Reduce Motion.
    static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}
