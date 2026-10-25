# JURY 15: Visuals & Graphics and Interaction (role: "visual")

Juror: principal product designer, ex design lead of a top-10 grossing App Store app, ADA jury experience.
Material judged: all 77 CI frames in `review15/` (phone, iPad portrait, iPad landscape rotated upright), the 14 App Preview frames, the 9 + 4 store frames re-rendered with the project's own composer (`tools/marketing/screenshots.py`), and the SwiftUI source under `ios/Timbre`. REVIEW13/14 were read for context only; every claim below was re-checked against pixels or code.

---

## 1. Score: **8.6 / 10**

Timbre has two screens that would get onto an ADA longlist. The first is the tuner stage: studio-lit RealityKit headstocks, a peg ring with a turn sign, state colour washing the whole stage (10, 10b, 49b, 49c). The second is the play-along highway, with perspective lanes, karaoke lyrics, a combo HUD and "Perfect" pops (59, 60, 65). No competitor draws either of them better. Around those hero moments, though, the app still speaks the visual dialect of a component library:
- **An SF symbol in a tinted circle** is the default icon for anything. It appears on 11+ screens, and on the paywall it comes in five hues.
- **Stacks of capsule chips.** There are 242 `Capsule()` calls, and Scales has five selector rows before any content.
- **Letter-spaced capital eyebrows on nearly every card.** There are 53 `Eyebrow(` calls.
- **A mint glow behind every primary button.**
- **Semantically wrong glyphs.** A triangle stands for triplets, a 2×2 grid for sixteenths, and a hamburger for "Capo".
- **31 distinct type sizes.**

The store listing, which is the ad, is weaker than the product:
- **One template, nine times.** The nine iPhone frames are the same layout on near-black.
- **A ghosted digit in frame #2.** The combo counter is caught mid-roll.
- **The signature frame (#3) renders its string glow as beaded blotches.**
- **iPad frame #2 was rejected by its own test.**
- **The App Preview of a music app is silent.** Its last third is a static Songs page.

This is an excellent app with visible seams. A juror can name concrete reasons it loses specific comparisons:
- Simply Guitar on a bespoke, non-templated brand language.
- Fender Play on human teaching imagery.
- Any top-grossing music app on its store creative.

So it is below 9.0, and the gap is design-system discipline and art direction, not engineering.

---

## 2. Head-to-head (my angle only)

I could not retrieve competitor screenshot pixels: the proxy refused `itunes.apple.com` and `is1-ssl.mzstatic.com`, and WebFetch of the mzstatic image was not approved (blocked URLs are listed under Sources). The listing facts below are current, from the web. The design-language comparison draws on my working knowledge of each app's shipping UI and is labelled as such.

| vs | Winner on Visuals & Interaction | Why / evidence |
|---|---|---|
| **GuitarTuna** (4.8★, ≈149K US ratings, v7.104.0 Oct 2026, 20,000+ tab songs with weekly licensed drops) | **Timbre** (in-app); **GuitarTuna** (brand and ad) | Timbre's tuner is in another class. GuitarTuna has an illustrated flat headstock and a needle arc, inside chrome crowded with upsells; Timbre has a lit 3D headstock, a peg ring with ↻, a mint/amber stage wash and a strobe dial (10, 10b, 15, 11b). Against that, GuitarTuna's real song art and decade-old recognisable brand system read as "real" on the shelf. Timbre's nine near-identical dark frames (store sheet) would disappear in a search-results row. |
| **Fender Tune** (4.8★, ≈146K ratings, Auto/Manual with an interactive headstock; guitar, bass and ukulele) | **Timbre** | Fender Tune is clean and photo-real but thin: a headstock and a meter. Timbre renders 7 instruments in 3D and photographs 37+, and adds strum lanes, string health and custom tunings, all in one visual system. Fender keeps one advantage: genuine Fender headstocks carry brand cachet that house renders cannot. |
| **Fender Play** (4.5★ DK, v8.0.2, 3,000+ video lessons, 1,000+ songs, Samsung TV app announced Jan 2026) | **Split.** Fender Play wins teaching imagery; Timbre wins interface and interaction. | Fender teaches with filmed instructors and close-ups of real hands. Timbre's "Show me" is 2D glossy dots floating over a 3D neck with no hand (51b; `ShowMe.swift:691-731`), which is not a substitute. On interaction design (listening feedback, highway, results, strum lanes) Timbre is clearly ahead of Fender's conventional light UI with scrolling tab. |
| **Yousician** (≈4.6★, 137K+ App Store ratings, 9,000+ lessons, 2,000+ songs, artist courses) | **Timbre narrowly**, on per-screen craft | Timbre's highway (60, 65) is rendered as well as Yousician's signature play screen or better: perspective lanes, lyric sync, chip-fill section map, "Perfect" pops. Yousician still has more, and more varied, illustrated and video content, and real artist imagery. Timbre's tuner is far ahead of anything Yousician's apps ship outside GuitarTuna. |
| **Simply Guitar** (4.8★ MX, v10.31 Oct 2026; Guitar World calls its look "bold, graphic… bravely contemporary") | **Simply Guitar**, on the "nothing templated" bar | Simply has one bespoke graphic language (brand purple, custom illustration, an animated fretboard, video tutorials), and no tinted-circle SF symbols in onboarding. Timbre's onboarding questions (03, 04), mic ask (05) and results (62) use stock symbols and concentric rings. Timbre wins the tuner, the 3D and the highway. Simply wins coherence of art direction. |
| **JustinGuitar** (4.8★, 27K ratings, v3.27.3 Oct 19 2026: card-flip Daily Jam, a green ring per chord) | **Timbre** | JustinGuitar is utilitarian: video plus colour-coded chord cards. Timbre is more polished on every screen. Justin keeps the human teacher and the trust that comes with him. |

**Net on my angle:** Timbre is #1 among these apps on in-app visual craft for the tuner, play-along and practice tools. It is not #1 on bespoke art direction (Simply Guitar), on teaching imagery (Fender Play) or on store creative (top-grossing benchmark).

---

## 3. Everything that costs points (ranked by impact)

### 1. The store screenshot set is one template applied nine times. **Major · M**
- **Screens:** store frames #1–#9 (re-rendered with the repo's composer); iPad #1–#4.
- **Code:**
  - `tools/marketing/screenshots.py:121-130`: the same `stage()` warm-glow background on every frame.
  - `screenshots.py:165-209`: an identical layout of caption, grey line and 80 %-width shot with an outline.
  - `screenshots.py:182`: "T I M B R E" on every frame.
  - `docs/ios/APP-STORE-LISTING.md:136-146`.
- **What's wrong:**
  - **No colour story.** All nine frames are near-black with a small UI inside.
  - **Unreadable supporting line.** It is set in `SOFT` grey at ≈40 px, illegible at search-result size.
  - **A redundant eyebrow.** The app name already sits above the gallery.
  - **No breakouts.** There is no device chrome, no zoomed crop, no callout and no element breaking the frame.
  - **Wasted adjacent frames.** #3 and #4 are both the E minor chart.
  - **Breadth never shown.** No iPhone frame shows the 60-instrument breadth, which is the subtitle's promise.
  - **Hard to tell apart.** Every frame has the same luminance, so at thumbnail size they read as one image repeated.
- **Fix:** an art-directed set.
  - Frame 1: the 3D headstock breaking out of the frame, the D3 lock glowing, and "Tune. Learn. Play songs." set at ≥ 120 px.
  - Give each frame a background tint taken from the feature's own accent: mint for the tuner, sky for Originals, amber for rewards, violet for ear.
  - Crop the screenshot to the hero region at 110–130 % scale rather than shrinking the whole screen.
  - Make #4 the instrument wall (60 renders), not a second E minor.
  - Drop the eyebrow.
  - Raise the supporting line to INK at 60 % and ≥ 52 px.
  - Optionally make #1–#3 a panorama so the first three read as one image in search.

### 2. Store #2 has a ghosted combo digit ("7|4"). **Major (store-blocking) · S**
- **Screen:** 65-song-perform (store #2, crop `combo.png`).
- **Code:** `Learn/HighwayHUD.swift:34-37` keeps `.contentTransition(.numericText(value: Double(combo)))`, and the multiplier does the same at `HighwayHUD.swift:67`.
- **What's wrong:** Last round's fix froze only the score (`SongPerform.swift:273-281`, `DemoScene.stillScore`). The combo still rolls on every note, so the still catches the "4" mid-transition, blurred and doubled.
- **Fix:**
  - In `HighwayHUD.counter` and `dial`, use `DemoScene.stillScore ? .identity : .numericText(...)` (same `#if DEBUG` guard).
  - Make the store probe assert that no `numericText` view is mid-transition: compare two captures 120 ms apart for the HUD region.

### 3. The App Preview is silent, cross-faded and ends on 9.6 s of a static page. **Major · M**
- **Material:** `review15/preview/` (t21–t27 are identical Songs frames); PREVIEW.txt: songs clip 19.37–29.00 s.
- **Code:**
  - `tools/marketing/preview.py:509`: `anullsrc`, a silent track.
  - `preview.py:49` and `:502`: ⅓ s `xfade=fade` between clips.
- **What's wrong:**
  - **Silent.** A tuner and lessons app whose product is sound ships a preview with no sound. Previews autoplay muted, but anyone who unmutes hears nothing.
  - **Messy cuts.** The crossfades double-expose UI (t11 shows "Open-string roll call" over "Strum down", and "Listening" over "Continue").
  - **A static tail.** The last ~⅓ of the video does not move.
  - **No captions.** Without them the viewer cannot tell a tuner moment from a lesson moment.
- **Fix:**
  - Mix the app's own audio: the reference pluck, the lock "ding", the E minor strum, the *Kite Weather* band.
  - Use hard cuts on beat, or match-cuts (headstock lock → chord card).
  - Cut Songs to ≤ 3 s with a scroll and a tap into the sleeve opening.
  - Add 4 caption cards set in Sora on accent backgrounds.
  - Keep the 9:41 status bar.

### 4. The default icon language is "SF symbol in a tinted circle", and on the paywall it comes in five hues. **Major · M**
- **Screens:** 03, 04, 05b, 06, 12/30, 13, 16, 32, 33, 40, 46, 62.
- **Code:**
  - `Design/Components.swift:337-349`: `IconOrb`, a 14 % fill, a 28 % stroke and a symbol.
  - `Onboarding/OnboardingView.swift:275-293`: leaf, music.note, star, crown; tuningfork, calendar, ear, mic, metronome. Outline and fill glyphs are mixed in one list.
  - `Settings/SettingsView.swift:132-279`: every row has an orb.
  - `Paywall/PaywallPlan.swift:347-468`: outcomes tinted sky, violet, amber, coral and flame.
- **What's wrong:** This is the single most recognisable "AI or template" tell. It flattens every concept to the same visual weight, and the paywall's rainbow orbs contradict the system's own rule ("one amber cue for act, mint for in tune", `Theme.swift:6`). Commit 544c576 claims "one icon language" for the paywall, but the pixels (06, 16, 40) still show three hues per screen.
- **Fix:**
  - Commission a 24-glyph Timbre icon family on a 2 pt stroke and 24 pt grid, plus 5 tab symbols as SF Symbols custom templates with weights.
  - **Settings:** delete the orbs and use plain 22 pt glyphs in `inkSoft`, as iOS Settings does with its own colour tiles.
  - **Onboarding answers:** replace the orbs with small illustrated vignettes (one per level and goal), or remove icons entirely and let type carry it.
  - **Paywall:** one tint (mint) for all outcomes, or show screenshots of each outcome instead of icons.

### 5. Semantically wrong or generic glyphs. **Major · S**
- **Code and screens:**
  - **Metronome subdivisions:** "music.note" = quarter, "music.note.list" = eighths, "triangle" = triplets, "square.grid.2x2" = sixteenths (`Practice/MetronomeView.swift:287`; 21, 22). The app already ships engraved noteheads, flags and beams (`Learn/NotationGlyphs.swift:7-16`), so drawing real ♩ ♫ ³ and ♬ glyphs is a few lines.
  - **Capo** = hamburger "line.3.horizontal" (`SettingsView.swift:153`).
  - **Temperament** = "slider.horizontal.3", the same glyph as the tuner's Settings button (`SettingsView.swift:132`).
  - **A "▶▶" `forward.fill` used as a bullet** (`OnboardingView.swift:506`; 05b).
  - **A crown for "I play professionally"** (`OnboardingView.swift:276`).
  - **A paper-plane/location button on the Bullseye card** with no clear meaning (20, ipad-*-practice).
- **Fix:**
  - Draw the subdivision glyphs with `NotationGlyph`.
  - Capo: a custom clamp glyph.
  - Temperament: "tuningfork"+"±" or a custom piano-key glyph.
  - Drop the ▶▶ bullet.
  - Label the Bullseye affordance ("Play") or remove it.

### 6. The tab bar mixes outline and filled symbols, and "Play" is labelled with a game controller. **Major · S**
- **Code:** `Root/RootView.swift:24-30`.
- **Screens:** 07, 10, 20, 32, 50, 63.
- **What's wrong:**
  - **Mixed weights.** "tuningfork" and "chart.line.uptrend.xyaxis" have no fill variant and render as thin outlines, while "graduationcap", "music.note.list" and "gamecontroller" render filled. The five items carry visibly different weights in the most-seen control in the app.
  - **A misleading label.** "Play" with a game controller fronts metronome, drone, chords, scales and intonation as well as the games.
- **Fix:**
  - Ship 5 custom SF Symbol templates (headstock or fork, open book or cap, record, pick or metronome, rising bars) with matched optical weight and `.fill` variants.
  - Rename the tab "Practice" (the code already calls it `AppTab.practice`).

### 7. "Show me" (store #3) renders its string glow as beaded blotches over sticker fingertips. **Major · M**
- **Screens:** 51b (crop `showme.png`); the store #3 frame.
- **Code:**
  - `Learn/ShowMeScene.swift:505-513`: the ringing halo is a chain of separate `UnlitMaterial` segments at 40 % alpha. Their overlaps stack alpha, which produces the beaded blobs down strings 6–4.
  - `Learn/ShowMe.swift:716-725`: the 2D fingertip "pads" carry a white gloss band, the same sticker gloss as the chart's barre (06b, crop `barre.png`).
  - Open-string rings and string numbers switch to a per-string rainbow (salmon, amber, mint, blue, lavender). That palette appears only here and on the highway; the chart beside it is all mint.
- **What's wrong:** The frame meant to answer Fender Play's video is the noisiest image in the set.
- **Fix:**
  - One continuous emissive tube per string (a single mesh, additive blend, a sine-displaced vertex shader for the vibration).
  - Remove the gloss band and make the pads soft, shaded fingertip ellipses that cast onto the board (or the hand from item 4 of "How to take #1").
  - Use the lesson accent for every mark in lessons, and keep the per-string rainbow for the highway only.

### 8. Pill and chip overload; selectors stack before content. **Major · M**
- **Evidence:** 242 `Capsule(` calls in 132 files.
- **Screens:**
  - **Scales (44):** root chips, scale chips (with "ajor pentatonic" hard-clipped at the left), note tiles, position chips, and two segmented controls: five rows before the fretboard.
  - **Metronome (21):** three different selector vocabularies (meter capsules, icon capsules, a segmented control) plus two PRO pills.
  - **Instrument picker (12, 30):** a tunings chip row, a search pill, a category chip row, a "+ Custom PRO" pill and a "Try next" pill, which mixes two jobs (tuning versus instrument).
  - **iPad picker:** 15+ PRO pills on one screen (ipad-landscape-instruments).
  - **05a2:** a three-pill reward row in three colours.
  - **20 / ipad Play:** XP pills on every row.
- **Fix:**
  - **Budget:** at most 2 selector rows above content.
  - **Scales:** move position and labels into a single "View" menu over the fretboard.
  - **Metronome:** put meter and subdivision into one wheel or segmented strip.
  - **Picker:** move tunings to the tuner's header menu.
  - **PRO marking:** a small lock glyph on the card corner instead of a gold pill on every locked card.
  - **XP:** show it once per card, not per row.

### 9. Colour semantics are overloaded, and the primary CTA changes colour. **Major · M**
- **Code:**
  - `Design/Theme.swift:34-45` and `:71-76` define the roles.
  - `Songs/SongsView.swift:853-866`: the hero "Play" takes the song's colour.
- **What's wrong:**
  - **Amber** means "act", "flat", the streak, Pro gold, string 5, the Songs hero CTA (63), "Day 2" and the sleeves.
  - **Coral** means a far-off pitch, "Hard" (43), string 6, the iPad Songs hero CTA ("Dust on the Dashboard") and the metronome orb.
  - **Sky** is the Originals "Start" CTA (64), string 2 and paywall orbs.
  - **Violet** is ear training, the graduation cap (20, 32, 50) and string 1.
  - **Result:** the primary button is mint, amber, coral or sky depending on the day's sleeve. On the highway the amber lane (string 5) reads as "out of tune" to anyone who has just used the tuner.
- **Fix:**
  - **Status colours are exclusive:** mint = in tune or correct, amber = adjust, coral = error.
  - **Course accents only tint course-owned surfaces** (covers, eyebrows, progress), never a primary button. Every primary CTA is mint.
  - **Highway lanes:** desaturate them and use luminance steps, or shift the hues so none equals a status colour.

### 10. The type system is loose: 31 sizes, 53 tracked-caps eyebrows, and two eyebrows per card. **Major · S**
- **Code:**
  - `Theme.swift:168-185` defines roles, but the code uses 31 distinct Sora sizes (9…96, including one-offs at 19, 46 and 92) and 183 `.system(size:)` literals.
  - 53 `Eyebrow(` calls and 53 `.tracking/.kerning` calls.
- **Screens:**
  - 05b: "GUITAR" and "UNIT 7 · SONGS WITH CHORDS" in one card.
  - 23: "QUESTION 1 OF 10" under a dot row that already says 1 of 10.
  - 64: KEY, TEMPO, METER, LEVEL, CHORDS, SONG MAP and LEAD SHEET: seven eyebrows on one screen.
  - 21: METER and SOUND.
  - 46: STEP 1 OF 2.
- **What's wrong:** Spaced capitals on every container is a 2024 Dribbble or AI tell. It flattens hierarchy because everything is "labelled".
- **Fix:**
  - An 8-step scale: 12/13/15/17/20/28/40/64, plus the hero numeral.
  - Eyebrows only at section level, never inside a card that already has a title, and never two per card.
  - Add a lint that fails CI when `Typeface.*(N)` uses a size outside the scale.

### 11. Glow and gradient soup. **Minor→Major · S**
- **Evidence:** 111 `.shadow(` calls and 97 `Linear/RadialGradient` calls. Every primary CTA has a 20–30 pt mint outer glow (01, 05, 06, 21, 41, 59, 62). Cards are washed in mint (05a2, 52b, with a glowing outline), amber (Coach, String health, Accuracy on 32, 33) or coral (iPad Songs hero), with no rule for which.
- **Fix:**
  - Glow means "live": listening, locked, playing.
  - A resting CTA is flat with a 1 pt top highlight.
  - Card tint means "this card is about X", decided by one table.

### 12. Cramped and colliding layouts. **Major · S**
- **05b:** the goal card's foot runs under "Start my plan". Its bottom border is cut by the fade, leaving a ≈6 pt gap (crop `c05b.png`; `OnboardingView.swift:396`, `:474`).
- **21/22:** the meter card's foot is masked by the dock fade, so the "Click" segment fades to grey mid-control (crop `c21.png`; `MetronomeView.swift:29-56`).
- **41:** the drone's PITCH card graph sits under "Start drone", with "+20" visible above it and "−20" ghosted below (`Practice/DroneView.swift:51-53`).
- **06b:** body copy ends ≈8 pt above the buttons.
- **Fix:** each dock reserves its height (`safeAreaInset(edge: .bottom)` instead of an overlay fade), and scroll content ends with a 24 pt gap above the dock.

### 13. Placeholder-grade 2D illustration and reward art. **Major · M**
- **Screens:**
  - **05:** a mic with three concentric rings.
  - **58:** a play button with five concentric rings.
  - **62:** results use three SF `star.fill` with a gradient.
  - **45, ipad-*-progress:** 42 achievements are SF symbols on copper discs (`TimbreCore/Practice/Progression.swift:317-358`, each with `symbol:`).
- **What's wrong:** These are the emotional peaks of the app, and they are the most generic pixels in it. Duolingo, Apple Fitness and Simply all use bespoke art here.
- **Fix:**
  - Render the medals in the same RealityKit lighting as the instruments: a metal disc with an embossed custom glyph and a tier rim.
  - Give results a designed star-fill sequence plus a confetti burst in course colours.
  - Commission 6 spot illustrations for the mic permission, ear games, empty states and onboarding goals.

### 14. Dead space. **Minor · S**
- 03 and 04: ≈330 pt of empty stage between the answers and Continue.
- 61: ≈140 pt void under the results card.
- 52b: ≈70 pt.
- 14 (studio stage): a headstock filling ~25 % of the stage.
- 17 (ukulele): ~30 %, versus ~60 % on 10 and 49.
- **Fix:**
  - Centre the answer stacks vertically, or give each question a hero vignette.
  - Normalise each rig's camera so the headstock spans a fixed 55–60 % of stage height.

### 15. Double-exposed captions and sliced glyphs during transitions. **Minor · S**
- **06b:** "Your turn — play it back" appears over the fading "Watch the fingers land in order" (crop `c06b.png`). Both sit in one slot with opacity fades (`Learn/LessonExplain.swift:594-600` and `Learn/ShowMe.swift:57-59`).
- **19:** the bass "E1" chip shows a half-mint, sliced letter as the lock "bloom" mask collapses (crop `c19.png`; `Tune/StringRail.swift:198-205`).
- **Fix:**
  - Sequence the captions: out in 0.15 s, then in. Or use one `Text` with `.contentTransition(.opacity)`.
  - When the lock is lost, crossfade the solid layer instead of reversing the bloom mask.

### 16. Copy, capitalisation and punctuation drift. **Minor · S**
- **"High Scorer" and "Round Winner"** are in Title Case among 40 sentence-case badge names (`TimbreCore/Practice/Progression.swift:322`, `:345`; 45, ipad progress).
- **"I already have Timbre Pro"** is an underlined web-style link on a native screen (`OnboardingView.swift:153`; 01).
- **The empty-value placeholder uses three different characters:** an em dash "—" (`Practice/IntonationView.swift:171`, `:191`), an en dash "–" (`Journey/JourneyView.swift:393`; 33 string health), and a standalone "—" as a headline in 46's listening card.
- **Fix:** sentence case everywhere, a plain-text or bordered button for restore, and one placeholder: "Not yet", or a dimmed "0".

### 17. The header chrome changes between tabs, and level is drawn four ways. **Minor · S**
- **Code:** `Design/GameUI.swift:11-21`.
- **What's wrong:**
  - **The streak chip changes shape.** It carries the Today ring on Tune and Songs (07, 63) but not on Learn and Play (50, 20), so it resizes as you switch tabs.
  - **Level has four renderings:** an "LV 5" ring chip (header), a "LEVEL 5" ring (20), an "LV 5" star tile (32), and a "5" disc (62).
- **Fix:** one chip and one level glyph everywhere.

### 18. Side controls break the 20 pt gutter. **Minor · S**
- **Code:** `Tune/TuneView.swift:580` scales the listening halo to ×1.35 beyond its 52 pt frame (`:587`).
- **Screens:** it sits ≈7 pt from the screen edge on 10/11/17 and on ipad-portrait-tune, ≈10 pt on ipad-landscape-tune, and overlaps the strobe bezel on 15 (crop `chrom.png`).
- **Fix:** give the control column a trailing inset of gutter + 9 pt, or clip the halo to the frame.

### 19. String order flips between Tune and Learn. **Minor · S**
- **Screens:** the tuner rail reads E A D G B E left→right (07, 10, 11); the lesson tune check and intonation read E B G D A E (52, 46).
- **Code:** `Practice/IntonationView.swift:32`, and the `StringOrder.thinnestOnTop` reuse for a horizontal row.
- **Fix:** horizontal rails are always low→high, left→right. Tab order (thinnest on top) applies only to vertical diagrams.

### 20. iPad finish. **Minor · M**
- **ipad-*-progress:** the three stat tiles stretch to ≈630 pt with content huddled top-left; they are phone tiles scaled up.
- **ipad-*-learn:** the unit path is a ≈220 pt strip in a ≈700 pt column.
- **ipad-landscape-learn-picked:** the Preview card has a ≈270 pt empty band above the fretboard.
- **ipad-portrait-learn:** the course rail is still cut mid-word ("Violi") at the column edge, despite the fade.
- **ipad-landscape-instruments-wrong:**
  - Store iPad #2 was rejected by its own test.
  - The capture still shows the Renaissance lute on a black box. Commit 5f9b699 fixed the asset with [skip ci], so this needs a recapture.
  - The new lute thumbnail's pegbox touches the image's top edge (alpha bbox y = 0), so it reads as cropped.
  - Violin and cello render small and dark beside a large, saturated viola and double basses, in the same row.
- **Fix:**
  - On iPad, lay the three stats out as one horizontal summary bar.
  - Run the unit path as a horizontal fretboard across the column, or two columns of nodes.
  - Vertically centre the Preview diagram.
  - Recapture, and re-crop the lute with headroom.
  - Normalise card-render scale per family.

### 21. Paywall micro-layout. **Minor · S**
- **Timeline:** Today takes a fixed 40 % column (`Paywall/PaywallView.swift:1083`), so Day 2 sits farther from Today than Day 12 does from Day 2, and time reads non-linearly (06, 16, 40).
- **Crowding:** the strike-through "$83.88" sits under the "14 DAYS FREE" tab.
- **Close button:** it sits on sleeve art (16).
- **Fix:**
  - Use proportional node positions with labels allowed to overhang, or equal spacing with "Day" labels.
  - Move the strike price beside the price.
  - Put the close button on a solid 44 pt disc in the top-trailing safe area, above the art.

### 22. Barre rendering. **Minor · S**
- **06b:** an offset gloss band floats inside the "1" barre (crop `barre.png`).
- **43:** the 3fr barre overruns the 1st string (crop `barre2.png`).
- **Fix:** end the barre at the outer string's centre plus the dot radius, and drop the gloss.

### 23. The generative sleeve system shows its generator. **Minor · M**
- **Code:** `Songs/SongCover.swift:7-9`, `:89-90`.
- **What's wrong:** Every cover is set in Sora and carries the same "— 0N / ORIGINALS" eyebrow and number (63, ipad-*-songs). The planet motif repeats as the "Your songs" icon. The code comment promises "a typeface" per genre, but the title is always Sora.
- **Fix:** licence 4–6 display faces (one per genre), vary eyebrow placement, and give the "Your songs" shelf its own icon.

### 24. Redundant meters on the chromatic tuner. **Minor · S**
- **Screen:** 15 shows the same reading twice: strobe dial plus linear meter, plus "Hold it…".
- **Fix:** when the strobe dial is on screen, hide the linear meter and let the dial carry the state.

---

## 4. How to take #1 on my angle (ranked by impact)

1. **Art-direct the store listing like an ad, and give the preview sound.** Treat the 9 + 4 frames and the 30 s preview as a brand campaign.
   - A hero frame with the 3D headstock breaking the frame.
   - A colour progression taken from the course accents.
   - Cropped, enlarged UI.
   - One frame of real hands on a real guitar beside the phone.
   - The 60-instrument wall.
   - Captions ≥ 120 px.
   - A preview cut on the beat to the app's own audio (lock ding → E minor strum → *Kite Weather* chorus), with hard cuts and caption cards.

   In a search-results row this is the single biggest visual lever against GuitarTuna and Yousician.
2. **Kill the IconOrb and own a glyph family.**
   - One 24-glyph custom set (headstock, pick, capo, fret, strobe, drone, ear, metronome with real note values) plus 5 custom tab symbols with matched weights.
   - Set them bare: no tinted circles.
   - One afternoon of a good icon designer removes the most visible "template" tell from 12+ screens.
3. **Give "Show me" a hand.** A rigged low-poly hand, or captured hand footage composited over the neck, landing fingers in order on the existing clock. Fix the beaded string glow.

   This is the ADA "Visuals & Graphics" moment and the direct answer to Fender Play and Simply Guitar. It is already engineered (ShowMe.swift, ShowMeScene.swift); it lacks the art.
4. **A design-system pass with CI lint.**
   - An 8-step type scale and an eyebrow budget (section level only).
   - Role-exclusive status colours, with mint-only primary buttons.
   - One glow rule ("glow = live"), a chip budget of ≤ 2 selector rows per screen, and dock layouts that reserve space.
   - Add a SwiftLint/regex check for `Typeface.*(size)` off-scale, `IconOrb(`, and `Capsule()` buttons outside the chip component.
5. **Bespoke reward art.**
   - Render the 42 achievement medals in the same RealityKit studio light as the instruments: metal, embossed custom glyph, tier rim.
   - Design a results sequence (stars filling, a confetti burst in course colours, the medal drop) and 6 illustrated empty or permission states.

   These are the screenshot-worthy, share-worthy moments, and they are currently stock symbols.
6. **Reshape the iPad layouts rather than stretching the phone ones.** A horizontal stats bar, a horizontal fretboard path, a centred Preview card, and the instrument wall as a full-bleed gallery with a hover effect for the pointer. Then build the iPad store frames from those.
7. **Normalise the stage.** Every instrument's camera frames its head at the same size and position. The studio and photo stages get a matching key light, so switching instruments feels like one set.

---

## 5. What only the owner can do (my angle)

- **Hire an art director and illustrator for 2–3 weeks.** Deliverables: the store set and preview cut, 6 spot illustrations, the badge art direction and a cover-type system. Budget ≈ $8–15k.
- **Commission an icon designer** for a 24-glyph family plus 5 SF Symbol templates. ≈ $2–4k.
- **Get a hand for "Show me".** Either licence or commission a rigged hand model (CC-BY-compatible or work-for-hire), or film a guitarist's fretting hand (a 2 h shoot, green screen, E minor/C/G/D/A first). Owner sign-off is needed on likeness and usage rights.
- **Audio for the App Preview.** Approve using the app's own *Kite Weather* band mix (or license or produce a 30 s cue), and confirm rights for every sound in the preview.
- **Licence 4–6 display typefaces** for the sleeve system (desktop plus app embedding licences).
- **Photography:** one real-hands-on-guitar lifestyle shot for store frame #1 or #6 (model release required).
- **Pre-launch social proof** (a teacher endorsement, TestFlight quotes). Laurels or quotes on the store frames need consent.

---

## 6. Sources

Web (fetched October 2026):
- GuitarTuna App Store page (rating 4.8, ≈149K ratings, v7.104.0, IAPs): https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389
- GuitarTuna HK listing (features, 20,000+ tabs, weekly song drops): https://apps.apple.com/hk/app/id527588389
- GuitarTuna on AppGoblin (store update Oct 21 2026; screenshot asset names): https://appgoblin.info/apps/527588389
- GuitarTuna Play announcement (Guitar World): https://guitarworld.com/news/yousician-guitartuna-play
- Fender Tune report (4.8, ≈146K reviews, Auto/Manual, interactive headstock): https://marlvel.ai/apps/com-fenderdigital-tuneandtone
- Fender Play App Store DK (v8.0.2, 3,000+ video lessons, 1,000+ songs): https://apps.apple.com/dk/app/id1226057939
- Fender Play on Samsung TVs (Jan 13 2026): https://www.sammobile.com/news/learn-playing-guitar-samsung-tv-fender-play/
- Yousician profile (9,000+ lessons, 2,000+ songs, pricing, 137K+ ratings): https://tooldirectory.ai/tools/yousician
- Simply Guitar review (visual design "bold, graphic… bravely contemporary"): https://www.guitarworld.com/reviews/simply-guitar-review
- Simply Guitar App Store MX (4.8, 26K ratings, v10.31): https://apps.apple.com/MX/app/id1476695335
- JustinGuitar on AppsHunter (4.8, 27K ratings, v3.27.3 Oct 19 2026, release notes): https://appshunter.io/ios/app/1176125504
- Best guitar apps 2026 (iGeeksBlog): https://www.igeeksblog.com/best-iphone-ipad-apps-for-guitarists/
- Apple Design Awards 2026 winners (Tide Guide for Visuals & Graphics; Moonlitt for Interaction, "best-in-class Liquid Glass"): https://apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/

Blocked or unread (competitor screenshot pixels could not be inspected):
- `https://itunes.apple.com/lookup?id=527588389` and `…959883039`: proxy `connect_rejected`.
- `https://is1-ssl.mzstatic.com/…App_store_GT_9x16_1242x2208_1.png/392x696bb.png`: proxy 403 via curl; WebFetch permission not answered.
- `https://apps.appfollow.io/ios/fender-tune-guitar-tuner-app/1107017950?country=nl`: server error.
- `https://app.lazyweb.com/company/guitartuna`: redirect, not followed.

Local evidence produced for this review (scratch only):
- `/tmp/claude-0/-home-claude/8e09460e-cfac-5eb2-9c8f-db780efe8fda/scratchpad/j15v/`:
  - `store_sheet.png` and `ipadstore1-4.png`: store frames rendered with the repo's composer.
  - `preview_sheet.png`: the 14 App Preview frames.
  - Crops `combo.png`, `showme.png`, `barre.png`, `barre2.png`, `c05b.png`, `c06b.png`, `c19.png`, `c21.png`, `chrom.png`, `drone.png`, `lute.png`.
  - Rotated iPad landscapes (`*-rot.png`).
