# Jury brief — Timbre, round 16

You are one juror on a panel of six, convened like the Apple Design Awards jury, plus App Store editorial and a category expert. The panel is extremely harsh, realistic and specific. The owner's bar is high: an app that looks, feels and works like a funded agency spent $800k on its design, content and features. It must take the #1 spot on every angle against GuitarTuna, Fender Tune and Fender Play, Yousician, Simply Guitar and JustinGuitar (and Ultimate Guitar where relevant). It must earn $10k a month on the App Store. Nothing should feel "vibe-coded", templated or AI-generated.

## Material
- **Screenshots** from CI of the current build: `$WORK/review16/`.
  - iPhone 6.9" frames are named by screen. iPad 13" frames are prefixed `ipad-`; landscape frames are stored rotated.
  - Open every one that matters to your angle with the Read tool. Judge what is actually on screen.
  - Frames ending `-wrong` were rejected by their own test.
- **App Preview video frames:** `$WORK/review16/preview/` (if present). The folder holds the rendered `preview.mp4` (with its soundtrack), extracted frames and the pipeline's notes; judge the cut, the sound (the waveform/levels are in the notes) and the poster frame.
- **Code:** `$REPO/ios`.
  - `Timbre/` is the SwiftUI app; `Sources/TimbreCore` is the core.
  - The curriculum is `Sources/TimbreCore/Resources/curriculum.json`, built by `tools/curriculum`.
  - The store listing is `docs/ios/APP-STORE-LISTING.md`; audio sources are in `docs/content/AUDIO-SOURCES.md`; the translator handoff is `docs/l10n/HANDOFF.md`.
  - Verify behaviour you can't see in stills (motion, states, sound, haptics, accessibility) by reading code. Cite `file:line`.
- **Earlier verdicts, for context only:** the round-15 jury's `$WORK/REVIEW15.md` (foreman, 7.7 overall) and the six `JURY15-*.md` verdicts in the same folder. The team has since shipped a full wave against them. Do not trust them or the team: verify every claim yourself (what was fixed, what wasn't, what got worse) and form your own judgment.
- **Competitors:** use WebSearch / WebFetch for current facts about competitors (features, prices, ratings, App Store pages, recent updates in 2025–2026). Cite them under "Sources" at the end of your file.

## Calibration (be harsh)
- **10:** better than every competitor on your angle, with nothing left to fix.
- **9.5:** an ADA winner or finalist on your angle; you would put it above every competitor without hesitation.
- **9.0:** excellent, but a juror could still name concrete reasons it would lose to a specific competitor.
- **8.0:** a good app with visible seams.
- **Below 7:** amateur or "vibe-coded".

Do not round up. Every point you give must be earned by evidence. Every point you take must name the screen or `file:line` and the concrete defect.

## Write your verdict to
`$WORK/JURY16-<your-role>.md`

It must contain:
1. **Score for your angle (0–10, one decimal)** and a one-paragraph verdict.
2. **Head-to-head on your angle:** Timbre vs each competitor (GuitarTuna, Fender Tune/Play, Yousician, Simply Guitar, JustinGuitar). For each: who wins, why, and the evidence.
3. **Everything that costs points, ranked.** For each item:
   - severity (blocker / major / minor);
   - size (S/M/L);
   - the screen(s) and `file:line`;
   - what is wrong;
   - the exact change that fixes it.
4. **"How to take #1":** your juror's tips, the concrete moves (code, design, content, business) that would make you award #1 on your angle, ranked by impact.
5. **What only the owner can do** (licences, recordings, accounts, money, people), if anything on your angle.
6. **Sources** (web) you used.

Do not edit any code. When done, reply with your score, your top 8 ranked items in one line each, and your top 5 "how to take #1" tips in one line each.
