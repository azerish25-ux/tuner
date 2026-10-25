# Working on Timbre (read first)

Repo: $REPO (git; branch v2/foundations). iOS 18+, SwiftUI, Swift 5 language mode, Xcode 26. App code in ios/Timbre, engine package in ios/Sources/TimbreCore (+ tests in ios/Tests/TimbreCoreTests), UI tests in ios/TimbreUITests/TimbreUITests.swift.

**There is no Swift compiler here.** CI compiles later. So:
- Read every type, token and helper you use before using it (Palette, Typeface, Motion, Metrics, Haptics, SoundFX, components in ios/Timbre/Design/*.swift). Never invent an API.
- Keep SwiftUI expressions simple. Split long view bodies into small `private var`/`func` views. Avoid long chained ternaries mixing types (Color vs LinearGradient → wrap with AnyShapeStyle). Mark helpers @MainActor when they touch main-actor state.
- iOS 18 APIs only (contentMargins, scrollClipDisabled, onScrollGeometryChange, sensoryFeedback, numericText etc. are fine).
- Keep accessibility: identifiers used by UI tests must stay (grep TimbreUITests.swift for `element("…")` ids in your files before renaming anything), VoiceOver labels, Dynamic Type (`relativeTo:`), Reduce Motion.
- Design language "Studio Noir": dark stage, mint accent (Palette.mint), amber/gold for rewards, Sora display type via Typeface. Match existing components; reuse rather than duplicate.

**Strings.** Text("…") literals are localization keys (English source). Translators handle other languages separately: don't edit any .lproj or tools/l10n files. Reuse existing English wording where the meaning fits; keep new strings short.

**Scope.** Only edit the files your task names (plus new files you create in the same folder). If you truly need another file, keep the change minimal and say so in the report. Don't commit or push; don't touch CI or other agents' areas. Other agents are editing other files at the same time.

**Report** (final message, under 300 words): what you changed per file, anything you couldn't do or are unsure compiles.
