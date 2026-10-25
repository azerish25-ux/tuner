# JURY 16: Visuals & Graphics and Interaction (role: "visual")

Juror: principal product designer, ex design lead of a top-10 grossing App Store app, ADA jury experience.

What I judged:
- **Phone frames:** all 87 phone frames in `review16/`.
- **iPad frames:** all 12 iPad frames, landscape turned upright from EXIF 8.
- **App Preview:** `preview.mp4` and its notes. I re-extracted frames at the cut points and measured the soundtrack's RMS level every half second with ffmpeg.
- **Store frames:** the 9 iPhone and 4 iPad store frames, re-rendered with the repo's own composer: `python3 tools/marketing/screenshots.py review16 …`.
- **Source:** the SwiftUI code under `ios/Timbre`, plus `tools/marketing` and `tools/ci`.

JURY15-visual and REVIEW15 were read for context only. Every claim below was re-checked against pixels or code. My scratch evidence is in `/tmp/claude-0/-home-claude/8e09460e-cfac-5eb2-9c8f-db780efe8fda/scratchpad/j16v/`:
- `store/`, `store-ipad/`: the store frames.
- `pv/pvsheet.png`, `pv/rms.txt`: the preview frames and soundtrack levels.
- `icons*.png`: the app icon at full and small sizes.
- `c*.png`, `s*.png`: crops of the defects below.

---

## 1. Score: **8.8 / 10** (round 15: 8.6)

### What the team fixed
Round 16 is the first round where the team attacked the design language rather than individual screens, and most of the round-15 "template" tells are gone:
- **No more `IconOrb`.** Zero calls remain, replaced by a bare `Glyph` component with seven glyphs drawn for the app: capo, temperament, chart, and ♩ ♫ ³ ♬.
- **Mint primary buttons only.** Every primary button is mint and flat at rest.
- **Sentence-case eyebrows.** Tracked capitals survive only at section level.
- **Proper tab bar.** "Play" is now "Practice", on a native `TabView` with a matched solid symbol family.
- **Show me cleaned up.** The string glow is one continuous tube, and the per-string rainbow is gone from lessons.
- **Smaller fixes:**
  - the barre ends at the outer string;
  - string order is low→high everywhere;
  - the chromatic tuner no longer shows two meters;
  - results stars are bespoke (`RewardStar`), not `star.fill`;
  - iPad Progress has a stats bar.
- **The store creative is now art-directed.** It is nine distinct compositions with a colour story: breakout, zoom, callout, a wall of 60 instruments, one light frame and a flip. The App Preview now carries the app's own sound, captions on accent backgrounds, hard cuts and an end card. The combo digit is crisp.

### What it broke or left
The pass also introduced new defects, and left the deepest gap, art direction, where it was:
- **A fake Dynamic Island.** It draws XP and badge banners right under the status bar's clock and signal icons, on the very first tuner screen and inside the App Preview.
- **The paywall timeline.** Its "proportional" fix pulled the labels off their nodes.
- **A paywall state with no plan cards** (16).
- **The app icon** is a near-black amber dial. It goes muddy at home-screen size and has nothing to do with the mint brand.
- **Instrument photography** has an AI-generated house style: the same fleur-de-lis inlay on a banjo, a bouzouki and a Martin-style guitar.
- **Violin, cello and mandolin scrolls are cropped** by the top of the stage.
- **The colour rule is written down but not enforced.** Amber and coral still mark activity categories, ear training, accuracy and paywall milestones.
- **Ghosting under the docks.** Text still shows through below the bottom buttons.

### Where that leaves it
- **Excellent with visible seams.** The tuner stage, the strum-to-tune lanes, the highway and the iPad Practice tiles with live previews are best in category.
- **Not yet 9.0.** A juror can still name concrete losses:
  - to **Simply Guitar** on bespoke brand and illustration;
  - to **Fender Play** on human teaching imagery (Show me still has no hand);
  - to **GuitarTuna** on icon and brand recognition at thumbnail size.

---

## 2. What changed since round 15 (my verification)

| Round-15 item | Status in round 16 | Evidence |
|---|---|---|
| #1 Store set is one template ×9 | **Fixed, with new crop defects** | 9 distinct looks, colour progression, instrument wall (store sheet). #7 slices the status bar; #8 slices its title; #1 shows the pre-lock state (see item 3 below). |
| #2 Ghosted combo digit in store #2 | **Fixed** | `HighwayHUD.swift:20-22` returns `.identity` under `DemoScene.stillScore`; store #2 shows a crisp "70" and "×4". |
| #3 Silent, cross-faded preview | **Mostly fixed** | Captions, hard cuts and an end card are in. But the RMS log is −120 dB for 0–1.5 s, 7.0–8.5 s and **17.0–23.2 s (27 % of the cut)**: results, Songs and the end card are silent. The poster shows "Hold it…", not the lock. |
| #4 `IconOrb` everywhere | **Fixed by name; the pattern survives inline** | 0 `IconOrb(` calls; `Glyph` lives in `Design/Glyphs.swift`. But `DailySetCard.swift:381-386` draws the same 14 % tinted disc behind a symbol (violet, amber and mint on 20 and the iPad Learn/Practice "Today" cards). |
| #5 Wrong glyphs | **Mostly fixed** | Custom capo and temperament glyphs (13), note-value subdivisions (`Glyphs.swift:24-25`), and the crown is gone. Still wrong: the Bullseye paper-plane (`PlayHubGames.swift:309-316`) and the amber ▶ bullet on the paywall (`PaywallView.swift:1191`). |
| #6 Mixed tab weights and "Play" | **Fixed** | `RootView.swift:24-34`: gauge, cap, list, metronome, bars, all solid. |
| #7 Beaded Show me glow | **Fixed (glow); not fixed (hand)** | 51b shows continuous tubes and mint-only marks. There is still no hand (`ShowMe.swift:15-16` "hook for more"). |
| #8 Pill overload | **Partly fixed** | Scales now has two selector rows plus a View menu (44). The picker still has tunings chips + search + category chips + "Custom" + "Try next" (12). Song cards still carry "🔒 Timbre Pro" pills (ipad-portrait-songs). `Capsule(` count is 240 against 236. |
| #9 Colour semantics | **Rule written, not enforced** | `Theme.swift:9-15` says status colours are exclusive. Yet `DailySetCard.swift:53` (tune = amber), `:56` (rhythm = coral), `PaywallView.swift:1229-1236` (milestones amber), `LessonResults.swift:155` (accuracy amber), `:181` (amber burst); 246 `Palette.amber` uses in total. |
| #10 Type system | **Scale defined, adoption half done** | `TypeStep` has 8 steps (`Theme.swift:159-220`), but `lint_tells.py` reports **112 off-scale literals** (9, 10, 11, 14, 16, 18, 19, 22–56 pt), and the rule is warn-only. 177 `.system(size:)` literals. |
| #11 Glow soup | **Fixed for buttons** | Primary buttons are flat at rest (01, 04, 21, 59). 102 `.shadow(` and 106 gradients remain. |
| #12 Docks cover content | **Half fixed** | Docks now reserve space (`safeAreaInset`), but their backdrops are translucent (`OnboardingView.swift:738-745` at 0.9; `PracticeChrome.swift:248-250` at 0.96). "One strum per beat" (05b), "−20" (41) and the next chord cards (43) ghost through below the button. |
| #13 Placeholder art | **Partly fixed** | Results now use custom faceted stars (62). Still placeholder: mic + 3 rings (05, `OnboardingView.swift:578-581`); play + 5 rings (58, `LessonPlayer.swift:~820-844`); SF bell hero (05a3, `ReminderAskStep.swift:59`); SF-symbol medals, now in 5 hues (ipad-landscape-progress). |
| #14 Dead space / small heads | **Not fixed** | 04b has a ~200 pt void above its answers; 05a3 ~330 pt void; 61 ~130 pt void. The studio head is still ~25 % of the stage (14). |
| #15 Double captions / sliced E1 | **Fixed** | 51 and 19 are clean. |
| #16 Copy drift | **Fixed** | "High scorer" is sentence case, the placeholder is one "Not yet", restore is a bordered button. |
| #17 Level drawn four ways | **Mostly fixed** | The header, Practice and Progress share the ring (`GameUI.swift:124-176`). Results still draw a plain "5" disc (`LessonResults.swift:229`). |
| #18 Halo past the gutter | **Fixed** | 10, 11, 17 |
| #19 String order flips | **Fixed** | 46, 52 |
| #20 iPad finish | **Partly fixed** | The Progress stats bar is in. The Learn unit path is still a ~250 pt strip. The bowed row still sets a tiny dark cello beside large bright violas and basses (ipad-landscape-instruments). |
| #21 Paywall micro-layout | **Close and strike price fixed; timeline regressed** | See item 4 below. |
| #22 Barre | **Fixed** | Crop `c43-barre.png`. |
| #23 Sleeves show their generator | **Improved** | Faces vary (condensed caps, Sora) and so do eyebrows. Still the same: the "Your songs" planet icon, and the *Kite Weather* cover is an *Unknown Pleasures* ridge-line pastiche. |
| #24 Redundant chromatic meter | **Fixed** | 15 |

**New in round 16 (not in round 15):**
- the fake-island collision;
- the empty paywall plan state;
- labels detached on the timeline;
- the Show me segmented control that relabels itself;
- cropped scrolls;
- the app icon (not audited in round 15);
- the photography house style;
- `numericText` used on letters.

---

## 3. Head-to-head on Visuals & Interaction

Competitor pixels on mzstatic remain unreachable from this sandbox (see Sources). The listing facts are current; the design comparison draws on the shipping apps as I know them, and is labelled as such.

| vs | Winner on my angle | Why, with evidence |
|---|---|---|
| **GuitarTuna** (4.8★; v7.104.0 Oct 2026, "small improvements and bug fixes"; Play / Learn / Tools tiers) | **Timbre in-app; GuitarTuna on brand and icon** | The tuner is not close. Timbre has a lit 3D headstock with peg ring and turn sign (10, 10b), a six-lane strum-to-tune (11b) and a strobe dial (15). GuitarTuna has a flat headstock and needle surrounded by upsells. GuitarTuna keeps a recognisable bright icon and brand system, while Timbre's icon is a 31/255-luminance brown dial that becomes a smudge at 40–60 px (`icons-small.png`). In search results GuitarTuna is still the one you see. |
| **Fender Tune** (4.8★; Auto, Manual on an interactive Fender headstock, Chromatic) | **Timbre** | Fender Tune is one headstock and a meter. Timbre gives 7 instruments in 3D plus 37 photographed rigs, strum-to-tune, string health, custom tunings and Arabic right-to-left (l10n-ar-tabs). Fender's only visual advantage is real Fender headstocks; Timbre's photo library now has an AI-generated house style that a Fender-literate player will spot. |
| **Fender Play** (4.5★ DK, v8.0.2; 3,000+ video lessons, 1,000+ songs; v8.0 reworked search, courses, lessons) | **Split: Fender on teaching imagery, Timbre on interface** | Fender teaches with filmed hands. Timbre's Show me is now clean (51b) but is still two numbered dots landing on a neck with no hand. Timbre's interaction design is far ahead of Fender's light, conventional UI: listening feedback (52, 52b, 55), the highway (65), results (62), the strum stage (53). |
| **Yousician** (4.6★, 139K ratings; v5.41.0 Oct 13 2026; 2026 Song Courses, lyrics in play mode, a Bowie artist event) | **Timbre, narrowly** | Timbre's highway (65), with perspective lanes, karaoke lyrics, a section-coloured map and "Perfect" pops, is at least Yousician's play screen. Its play-along now has a colour-blind-safe lane palette (60). Yousician still wins on licensed artist art and real album covers; Timbre's sleeves are generative and one is a Joy Division pastiche. |
| **Simply Guitar** (4.8★ MX, ~26K ratings; v10.31 Oct 2026; Guitar World: "a very bold, graphic aesthetic that's bravely contemporary") | **Simply Guitar on art direction; Timbre on craft** | Simply has one bespoke graphic language and filmed tutorials, with no stock symbols on its emotional screens. Timbre's onboarding still leans on stock pictures: the SF mic in rings (05), an SF bell (05a3), signal bars for experience (03), and the same SF play-in-rings on the listen step (58). Timbre's tuner, 3D, highway and practice tools are richer. Coherence still goes to Simply. |
| **JustinGuitar** (4.8★, ~27K ratings; v3.27.3 Oct 19 2026: card-flip Daily Jam, a green ring filling per chord) | **Timbre** | JustinGuitar is utilitarian: video plus colour-chord cards. Timbre's chord step, with each string's chip lighting and the card glowing while it listens (05c, 52b), is the same idea done better. Justin keeps the human teacher. |
| *Reference: Guitar Wiz* (ADA 2026 **Inclusivity** winner; a tuner, metronome and chord toolkit with spoken pitch guidance) | Not a revenue competitor, but proof the jury rewards guitar tools | It shows a guitar utility can win an ADA. The 2026 Visuals and Interaction winners (Tide Guide; Moonlitt, cited for "best-in-class Liquid Glass") won on one cohesive theme and native platform craft. Timbre uses Liquid Glass sparingly and well (paywall plans, the action button, chips: `Glass.swift`), but its icon is a flat PNG with an identical "dark" variant. |

**Net on my angle:** Timbre is #1 among these apps on in-app visual and interaction craft for tuning, play-along and practice tools. It is not #1 on brand (icon, mark, photography coherence), human teaching imagery, or polish of the ad.

---

## 4. Everything that costs points, ranked

### 1. A fake Dynamic Island draws reward banners under the status bar's clock and icons. **Blocker · S**
- **Screens:** 07 (the first tuner screen after onboarding), 14, 17, 18, and App Preview frames 5–7 (crop `c07-island.png`).
- **Code:**
  - `Design/GameUI.swift:454-458`: "a black pill that grows out of the island and stays inside the status-bar band".
  - `:614-626` puts the icon "left of the camera cutout, words right of it".
  - `:671-703` (`PillLayout`) sizes it to 126 + 2×64 pt.
  - It is mounted globally at `Root/RootView.swift:59`.
  - There is no `statusBarHidden` anywhere for it.
- **What's wrong:**
  - The system status bar is drawn above the app window, so the clock sits on the sparkle disc and the cellular bars sit on "+5 XP" ("9:4● … +5 X▮▮▮").
  - In 14 a two-line "3 achievements unlocked / Rising …" sits behind the signal, Wi-Fi and battery icons.
  - It fires on every XP gain, so it is the most frequent motion in the app.
  - Imitating the Dynamic Island is also the kind of gimmick an Apple juror marks down: the area belongs to the system and to Live Activities, which the app already has.
- **Fix:**
  - Delete the island mode. Show rewards as an in-app capsule docked under the screen header, leading-aligned, at `safeAreaInsets.top + 8` (the existing `docked` branch, `GameUI.swift:698-701`), using the app's own Liquid Glass (`timbreGlass`).
  - Or, if the island look is kept, hide the status bar while it is open: `.statusBarHidden(open)` on the root, animated with `Motion.island`.
  - Re-record the preview and re-capture 07, 14, 17 and 18.

### 2. The app icon and brand mark are the weakest visual asset, and the one seen most. **Major · M (needs owner and designer)**
- **Asset:** `Timbre/Resources/Assets.xcassets/AppIcon.appiconset/`.
- **What's wrong:**
  - **Too dark.** `icon.png` has a mean luminance of 31/255: a brown-black square with a thin amber tick ring and a hairline string arc. At 40–60 px it reads as a dim dotted circle (`icons-small.png`), so it disappears on a dark home screen and next to GuitarTuna's bright icon in search.
  - **No real dark variant.** `icon-dark.png` is byte-identical to `icon.png` (max pixel difference 0).
  - **No iOS 26 layered icon.** There is no `.icon` file from Icon Composer; the competitors' newest builds ship layered glass icons.
  - **No logotype.** The "brand" is Sora in tracked capitals, in amber, a status colour (`Onboarding/OnboardingView.swift:242`, `.tracking(9)`), repeated as "TIMBRE PRO".
  - **Off-brand colour.** The icon is amber/brass while the product, store backgrounds and buttons are mint.
- **Fix:**
  - Commission one mark: a single vibrating string that settles into a lock, readable at 29 pt, in the mint/teal family against a lit stage.
  - Build it in Icon Composer with foreground (string), mid (glow) and background (stage) layers, and real Default, Dark, Clear and Tinted variants.
  - Use the same string-to-lock gesture as the wordmark's animation on welcome and as the end card of the preview.

### 3. The store frames and the preview, as the ad: crops, a missed lock and a silent final quarter. **Major · S–M**
- **Store #1, `breakout mint`, `10b-tune-locked`:**
  - The listing promises "its peg ringed and ticked, the lock's comet running down the string" (`docs/ios/APP-STORE-LISTING.md:173`). The capture shows **D3 at "Hold it…" 0¢ with no tick** (10b, crop `s01-rise.png`).
  - The breakout carries a dark rectangular halo from the capture's stage onto the teal background.
- **Store #7, `zoom gold`:** `FOCUS["62-lesson-results"]` has `y0: 0.035` (`tools/marketing/screenshots.py:76`), which **slices the status bar in half** ("9:41", Wi-Fi and battery cut; crop `s07-top.png`). The amber burst rings also cross "6 of 6, clean" and "The open strings".
- **Store #8, `flip mint`:** `FOCUS["11b-tune-strum"]` has `y0: 0.075` (`screenshots.py:81`), which **slices the "Strum to tune" title** and the close and pause buttons (crop `s08-top.png`).
- **Store #3, `callout lime`:** the enlarged callout's headline "Every string rings" is grey (`inkSoft`) on dark green, the lowest-contrast text in the set. It covers the "Em" title and the chart toggle.
- **Store #2:** the *Kite Weather* sleeve is the ridge-line plot from Joy Division's *Unknown Pleasures* (also on the paywall rail, 06). A design juror reads it as a pastiche on the ad's second image.
- **Preview:**
  - **A missed lock.** The poster (`preview/poster.png`, "2.70 s, in lock" per PREVIEW.txt) shows "Hold it…" −3¢ with no ✓. The 0–3.4 s clip never shows the "✓ In tune" pill.
  - **Silence.** The soundtrack is **digital silence for 0–1.5 s, 7.0–8.5 s and 17.0–23.2 s**, so "Hear how you did", the Songs clip and the end card have no sound. `soundtrack.py:1-15` lays only what the app played during each clip, and "Silence is left out".
  - **Notes disagree with the file.** PREVIEW.txt says "shortened … to 25.0 s"; the file is 23.17 s.
- **Fix:**
  - #1: capture 10b after the lock event (`D3 ✓` and the comet), and mask the breakout to the model's alpha, not to a feathered rectangle.
  - #7: `y0 ≥ 0.06`, or composite a clean 9:41 bar.
  - #8: start the flip below the title (`y0 ≈ 0.12`) or keep the header whole.
  - #3: render the callout's headline in `ink`.
  - Commission a non-derivative *Kite Weather* cover.
  - Preview:
    - Run a music bed (the *Kite Weather* band stem, or the three-note motif) under 0–23 s, ducked under the app's cues.
    - Let the results stars ring in key over "Hear how you did".
    - End on the motif.
    - Clamp the poster to a frame after the lock event.

### 4. Paywall: timeline labels slide off their nodes, and one state shows no plans. **Major · S**
- **Screens:** 06, 16, 40, ax-audit-paywall (crop `c06-timeline.png`).
- **Code:** `Paywall/PaywallView.swift:1143-1168` (`planTrack`), `:1683-1707` (`TrackSpread.slots`).
- **What's wrong:**
  - **Detached labels.** The words are packed from the ends and pushed apart (`:1702-1704`), so on 06 "Play 'Ode to Joy'" sits midway between Today and Day 9, ~90 pt left of its node, and "We remind you" sits between Day 9 and Day 12.
  - **Crowded titles.** "Day 12" and "Day 14" touch.
  - **Status colour misuse.** Milestones are amber (`:1229-1236`), and the Today line has an amber ▶ bullet (`:1191`). Both contradict `Theme.swift:9-11`.
- **No plans in 16.** On 16 (the paywall from Settings) **the Yearly, Monthly and Lifetime cards are not drawn at all**. "14 DAYS FREE" floats over a ~200 pt void above "Cancel in 2 taps". The tag is an overlay outside the glass group (`:858-866`, `:894-908`), and the cards live inside `GlassEffectContainer` (`Design/Glass.swift:31-37`). Whether this is a rendering failure in a sheet or a capture taken mid-materialisation, the tag must never show without its card.
- **Fix:**
  - **Timeline:**
    - Keep words centred under their node and let the two right-hand events share one column ("Day 12 · reminder" over "Day 14 · $34.99"), or stagger labels above and below the line.
    - Colour milestones `ink` with a mint node.
    - Drop the ▶.
  - **Missing plans:**
    - Put the tag inside the yearly card's glass so it appears and fades with it.
    - Add a test that asserts `paywall.plan.yearly` is hittable on the Settings route.

### 5. Imagery is not one art direction: AI-style photography, two different "your guitar"s, and the bowed row's scale. **Major · M–L**
- **Data:** `Sources/TimbreCore/Resources/photos.json`: 68 of 73 entries are `"origin": "provided"`; only the classical and electric guitars are credited renders.
- **Screens and assets:**
  - **A repeated motif.** The 5-string banjo and the Greek bouzouki (`Assets.xcassets/22_…`, `23_…`; composite `folk2.png`) share an identical fleur-de-lis headstock inlay and brass tailpiece, as does the "Meet your guitar" dreadnought (06b). This is the signature of one image generator, not of three instrument traditions.
  - **Painterly textures.** The textures are smeared and painterly (06b's top).
- **Two guitars in the first minute.** Welcome (01), the plan (05b) and Learn (50) show the clean 3D Martin-style render. The first lesson (06b) shows a different, worn, tortoiseshell-guard guitar, because `Learn/Diagrams.swift:1110-1117` falls back to the `01_guitar_acoustic_guitar` photograph.
- **Bowed row (ipad-landscape-instruments):** the violin and cello are small and dark renders, while the viola and both double basses are large, saturated "provided" images, all in one row.
- **Fix:**
  - Use the 3D render card everywhere the user's own instrument appears (`photoCard` for the usdz-backed instruments first).
  - Re-render or commission the 68 photos under one studio light and camera (`tools/models/cards.py` already does this for renders).
  - Normalise card scale per family.
  - Remove the generic inlays.

### 6. The colour rule exists in a comment, not in the product. **Major · S–M**
- **Rule:** `Design/Theme.swift:9-15`: "Nothing else is drawn in those three [mint, amber, coral]".
- **Violations:**
  - **`Practice/DailySetCard.swift:51-58`:** `.tune` is amber, `.rhythm` is coral, `.lesson` is violet. They are drawn as tinted discs (`:381-386`), which recreates `IconOrb` by hand on the first card of the Practice tab (20) and on iPad Learn and Practice.
  - **Ear training (23):** the first note's bar, the ±50¢ box and the progress dot are amber (`Practice/EarTrainingView.swift`, 24 amber uses).
  - **Results:** the accuracy tile is amber (`Learn/LessonResults.swift:155`) and the star burst is amber (`:181`), though the rule assigns rewards to `starGold`.
  - **Other screens:** beat 1 of the metronome (21), the root notes in Chords and Scales (43, 44), "Today's challenge" (20), and the Day 9 paywall milestone.
  - **Coral** marks "Hard" difficulty (43).
- **Fix:**
  - Introduce `Palette.accentNeutral` for categories, and `starGold` for rewards and roots.
  - Restrict `amber` and `coral` to pitch and grade call sites with a lint rule in `tools/ci/lint_tells.py`: `Palette.(amber|coral)` outside a `// status` allow-list fails.
  - Replace the Today-card discs with bare `Glyph`s.

### 7. Hero objects cropped by the stage, and heads framed at different sizes. **Major · S**
- **Screens:**
  - **Cropped scrolls.** The violin's and cello's scrolls and the mandolin's head are cut flat at the stage's top edge (49b, 49c, 49; crop `c49b.png`).
  - **Small head.** The studio stage (14) frames the headstock at ~25 % of the stage, against ~60 % on 10.
- **Code:** `Stage/InstrumentStage.swift:448-450`. The close-up's top constraint uses one `tip` point at `(head.x, rig.upper.y, head.z)`, but a scroll curls toward the camera after the −0.54 rad yaw (`closeYaw`, `:130`), so its projected top lies above the constrained point.
- **Fix:**
  - Constrain the projected bounding box of the head mesh (its 8 corners) rather than one tip point.
  - Normalise the studio and photo rigs to the same 55–60 % head height.
  - Add a probe that fails when the head's top projects above the stage's top edge minus `edge`.

### 8. Docks ghost content below the button, and empty bands remain. **Minor→Major · S**
- **Ghosting:**
  - 05b: "One strum per beat" is visible under "Start my plan" (crop `c05b-dock.png`).
  - 41: "−20" is visible under "Start drone" (crop `c41-dock.png`).
  - 43: the next chord cards show under "Check".
  - **Code:** `Onboarding/OnboardingView.swift:745` (`Palette.stage.opacity(0.9)`), `Practice/PracticeChrome.swift:248-250` (0.96).
- **Empty bands:**
  - 04b: ~200 pt between the subtitle and the answers.
  - 05a3: ~330 pt between the time row and "Remind me".
  - 61: ~130 pt under the results card.
- **Fix:**
  - Make dock backdrops opaque (`Palette.stage`) below the 18–24 pt fade, or use the iOS 26 soft scroll-edge effect.
  - Give the reminder page a real hero (see item 11), and vertically centre the answer stacks within the space between the header and the dock.

### 9. The type scale is defined but not adopted. **Major · S**
- **Code:**
  - `TypeStep` (`Theme.swift:159-220`) defines 12/13/15/17/20/28/40/64.
  - `python3 tools/ci/lint_tells.py --list type-scale` reports **112 off-scale literals**: 9, 10, 11, 14, 16, 18, 19, 22, 24, 26, 30, 32, 34, 44, 46, 48, 52 and 56 pt. Most are in `Tune/Celebration.swift` (11), `Learn/SongStoryCard.swift` (7), `Onboarding/OnboardingView.swift` (6) and `Learn/SongOpener.swift` (6).
  - The rule is `warn`, so nothing stops more being added.
  - There are 177 `.system(size:)` literals.
- **On screen:**
  - The paywall timeline mixes 12 pt Sora titles with `.caption` SF (`PaywallView.swift:1154`, `:1197`).
  - The microphone title is 34 pt (`OnboardingView.swift:585`), off the scale.
  - Tracked capitals remain on the tuner's most-seen control ("AUTO · MANUAL · REFERENCE", 07–19).
- **Fix:**
  - Migrate the 112 call sites to `TypeStep` (most snap: 14→15, 16→17, 18→20, 22/24/26→28, 30/32/34→28 or 40, 44–56→40 or `hero`).
  - Then set `type-scale` to `error`.
  - Set the tuner mode control in sentence case at 15 pt.

### 10. Show me's segmented control relabels itself, and there is still no hand. **Major · M (hand: owner)**
- **Screens:** 51 shows "**Chart** | Player view". The same control on 51b, during Show me, shows "**3D** | Chart" (`Learn/ShowMe.swift:605-620`). The selected left segment changes meaning under the user's finger, and "Player view" disappears.
- **Missing hand.** The demonstration is two numbered discs landing on the 3D neck. There is no hand, while Fender Play and Simply Guitar teach with real hands. `ShowMe.swift:15-16` has the hook; there is no rig in `Resources/Models` (no `hand*.usdz`).
- **Glyph.** The button's "rotate.3d" glyph (`ShowMe.swift:520`) reads as a globe at 20 pt.
- **Fix:**
  - Make 3D a third, stable segment ("Chart · Player · 3D"), or put a separate "Show me" toggle beside the picture switch.
  - Commission the stylised hand (§6).
  - Use a play-in-3D glyph or the word alone.

### 11. Remaining placeholder illustration on the emotional screens. **Major · M**
- **Microphone permission (05):** an SF mic inside three concentric rings (`OnboardingView.swift:578-581`).
- **Listen step (58):** a play button inside five concentric rings.
- **Reminder (05a3):** the SF `bell.badge.fill` on a radial glow (`ReminderAskStep.swift:59`).
- **Medals (45, ipad-*-progress):** SF symbols on discs in five unrelated hues (orange, purple, teal, gold, silver), with "Earned" in orange on some and white on others.
- **Tune-check success (52):** a mint check disc with rings.
- **Fix:**
  - Commission 6 spot illustrations in the app's stage-light language: an instrument listening to a mic, a reminder card over the guitar, an ear and two notes, and so on.
  - Render the medals in the instrument studio light (metal disc, embossed custom glyph, one tier rim colour system).

### 12. Motion detail: `numericText` on letters, and mid-transition captures. **Minor · S**
- **Code:**
  - `Learn/Highway.swift:403` applies `.contentTransition(.numericText())` to the whole "Next" row, so note names roll like digits. On 60, "D3" shows a doubled, blurred "3" (crop `c60-next.png`).
  - `LessonPlayer.swift:421` rolls "Step 3 of 6" (56, crop `c56-step.png`).
- **Captures:** 56 and 05c2 were captured mid-transition (content slid off-screen).
- **Fix:**
  - Use `.contentTransition(.opacity)` for the Next row; keep `numericText` for numbers only.
  - Have the tour's still-capture helper wait for `Motion.page` to settle.

### 13. Discoverability and affordance slips. **Minor · S**
- **Metronome subdivisions** (♩ ♫ ³ ♬, now real notation glyphs) are hidden after 12/8 at the end of the meter rail (`Practice/MetronomeView.swift:281-300`). On 21 and 22 none are visible, and the rail's last visible chip is a faded "7/4".
  - **Fix:** a second row, or a leading segmented "♩ ♫ ³ ♬".
- **The Bullseye "Challenge a friend"** button is an unlabelled 32 pt paper plane in a corner (`PlayHubGames.swift:309-316`; 20, ipad practice).
  - **Fix:** "Challenge" text plus glyph.
- **The instrument picker** still opens with a tunings chip row above the search (12, 30).
  - **Fix:** move tunings into the tuner header's menu, as round 15 asked.
- **"Try next"** on a card and **"🔒 Timbre Pro"** pills on song cards (ipad-portrait-songs).
  - **Fix:** a corner lock glyph, as already used on the iPad tool tiles.
- **iPad Tune portrait:** "Thickest" and "Thinnest" are pinned to the column edges, ~300 pt from the centred chips.
  - **Fix:** align them under the first and last chips.

### 14. Tuner chrome in other languages. **Minor · S** (inclusivity owns the rest)
- **Screens:** l10n-de-tabs and l10n-ar-tabs. "Thickest", "Thinnest" and "Quest · tune every string" stay in English inside otherwise translated tuners; the Arabic stage also falls back to a small whole-guitar image instead of the 3D headstock.
- **Fix:** extract the strings, and keep the 3D close-up in right-to-left layouts with the camera mirrored.

---

## 5. How to take #1 on my angle (ranked by impact)

1. **Build a brand, not just a UI.** One mark (a string that settles into a lock) gives you:
   - an Icon Composer icon with real Dark, Tinted and Clear variants, readable at 29 pt and in mint;
   - a logotype;
   - a 1-second sonic and motion signature used on welcome, Pro unlock, the lock and the preview's end card.

   This is the single lever that changes how Timbre looks *next to* GuitarTuna in search, on the home screen and in the ad. Today the icon is the least crafted pixel the user will see most.
2. **Fix the three self-inflicted seams this week.**
   - Kill the fake island (item 1).
   - Re-centre the paywall timeline and make the plan tag appear with its card (item 4).
   - Make dock backdrops opaque and frame the bowed scrolls inside the stage (items 7 and 8).

   Each is S-sized, and each is visible on a first-session screen.
3. **Re-cut the ad around the lock.**
   - The first frame and the poster are a ✓-locked string with its comet.
   - A continuous music bed (the *Kite Weather* stem) under all 23 s, the stars ringing in key under "Hear how you did", and the motif on the end card.
   - Fix the slices on #7 and #8.
   - Replace the Joy Division pastiche.
   - Add a violin-first preview for the violin Custom Product Page (the listing already plans that set).
4. **Give "Show me" a hand, and give the emotional screens real art.**
   - A stylised rigged fretting hand posed from `ShowMeShape.presses`.
   - 6 spot illustrations: mic, reminder, listen, ear, empty states.
   - Medals rendered in the instrument studio light.

   This answers Fender Play and Simply Guitar where they still win, and is the material an ADA "Visuals and Graphics" entry needs.
5. **Make the design system enforce itself.**
   - Arm `type-scale` after migrating the 112 literals.
   - Add a `status-colour` lint and an `inline-orb` lint (`Circle().fill(x.opacity(0.1…))` behind an `Image(systemName:)`).
   - Budget `Capsule()` buttons outside `ChipButtonStyle`.

   The comment in `Theme.swift:9-15` is excellent; make CI hold the app to it.
6. **One art direction for every picture of an instrument.** Re-render or commission the 68 "provided" photos under the studio light, the same camera and the same scale per family. Show the user's own instrument from its 3D model everywhere (06b).
7. **iPad as its own composition.**
   - Learn: the unit path as a horizontal fretboard across the column.
   - Tune: controls grouped at the right edge instead of in four corners (ipad-landscape-tune has mode bottom-left, Strum and Pause at the right edge, the header top-left and chips top-right).
   - Pointer hover effects on the instrument wall and song sleeves.

---

## 6. What only the owner can do (my angle)

- **Brand and icon designer, 1–2 weeks, about $4–10k.** Deliverables: the mark, the Icon Composer icon (Default, Dark, Clear, Tinted), the logotype, and motion/sonic signature guidelines.
- **Art director and illustrator, 2–3 weeks, about $8–15k.**
  - 6 spot illustrations and the medal art direction.
  - The store set and preview re-cut.
  - A non-derivative *Kite Weather* cover, plus a review of the 50 Originals sleeves for pastiche.
- **Stylised hand rig for Show me, about $0.5–2k, work for hire.** Optionally, a half-day shoot of real fretting hands for the store frame and onboarding (model release needed).
- **Instrument imagery:** decide whether the 68 "provided" photographs stay. Confirm their provenance and licence. If they are generated, commission renders or photography under one light. A category expert or reviewer who notices identical inlays on a bouzouki and a banjo will say so in public.
- **Music bed for the App Preview:** approve using the *Kite Weather* band stem, or license a 25 s cue, and confirm rights for every sound in the cut.

---

## 7. Sources

Web, fetched October 2026:
- 2026 Apple Design Award winners (Tide Guide for Visuals & Graphics; Moonlitt for Interaction; Guitar Wiz for Inclusivity): https://9to5mac.com/2026/06/02/apple-reveals-apple-design-awards-app-and-game-winners-for-2026/
- Apple Newsroom, the 2026 ADA winners: https://apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/
- Guitar Wiz ADA Inclusivity win (VoiceOver pitch and chord guidance, Dynamic Type, Differentiate Without Colour): https://www.etvbharat.com/en/technology/2026-apple-design-awards-india-origin-app-guitar-wiz-wins-in-inclusivity-category-enn26060302573
- Guitar Wiz on Product Hunt: https://www.producthunt.com/p/guitar-wiz/guitar-wiz-won-an-apple-design-award
- GuitarTuna, App Store HK (4.8★, v7.104.0, tiers and prices): https://apps.apple.com/hk/app/id527588389
- Yousician on AppsHunter (4.6★, 139K ratings, v5.41.0 Oct 13 2026, 2026 Song Courses, lyrics in play mode, Bowie event): https://appshunter.io/ios/app/yousician/id959883039
- JustinGuitar on AppsHunter (4.8★, ~27K ratings, v3.27.3 Oct 19 2026, card-flip Daily Jam, chord ring): https://appshunter.io/ios/app/1176125504
- Fender Play, App Store DK (4.5★, v8.0.2, 3,000+ video lessons, 1,000+ songs, v8.0 rework): https://apps.apple.com/dk/app/id1226057939
- Fender Tune on Appaloosa Scout (4.8★, v4.16.2, Auto / Manual on an interactive Fender headstock / Chromatic): https://scout.appaloosa.io/en/apps/ios/com.fenderDigital.TuneAndTone/4.16.2?lang=en
- Simply Guitar, App Store MX (4.8★, ~26K ratings, v10.31, video tutorials): https://apps.apple.com/MX/app/id1476695335
- Guitar World, Simply Guitar review ("a very bold, graphic aesthetic that's bravely contemporary"): https://www.guitarworld.com/reviews/simply-guitar-review

Searched but not useful (outdated or no design detail):
- https://yousician.com/blog/whats-new-in-yousician-march-update (2020)
- https://guitar.com/news/fender-songs-launch/ (2019)

Not retrievable from this sandbox:
- `https://apps.apple.com/us/app/-/id1107017950` (client error).
- Competitor screenshot pixels on mzstatic, as in round 15. The design comparisons in §3 are therefore from working knowledge of the shipping apps.
