# Timbre for iOS: development history

This is the record of how Timbre for iOS got from the Android port to where it is today, in order, with the reason for each decision. It is written for a new team that has to pick the project up without re-reading about a megabyte of review files and 303 commit messages.

**Period covered.** 2026-10-22 19:33 to 2026-10-25 16:25 (all times are −03:00, as the commits record them). That is 303 commits on `v2/foundations`, from `328b7d3` (PR #1, the port) to `0bbf273` (the last merge of wave 19).

**Sources.**
- The git history: `git log --reverse --format='--- %h %ad%n%B' --date=iso`. Every hash below can be opened with `git show <hash>`.
- The review, audit and brief files the reviewers, the jury and the orchestrator wrote after each round. They live in the orchestrator's scratchpad (`…/scratchpad/polish/`), **not in this repository**, so this document is their durable summary:
  - single-reviewer rounds: `REVIEW3.md` … `REVIEW14.md`;
  - code and design audits: `QA10.md`, `DESIGN11.md`;
  - jury rounds: `JURY15-<role>.md` and `REVIEW15.md` (foreman), `JURY16-<role>.md` and `REVIEW16.md` (foreman);
  - briefs: `PREAMBLE.md`, `JURY_BRIEF.md`, `JURY16_BRIEF.md`, `JURY17_BRIEF.md`, `TEAM19.md`, `CONTRACTS19.md`, `INTEGRATION19_BRIEF.md`;
  - the wave-19 record of cross-team requests and leftovers: `INTEGRATION19.md`.
- The owner's goals, as summarised for the project (section 1).
- The repository's own docs where they record a decision: `docs/content/SONG-LICENSING-PLAYBOOK.md`, `docs/content/PUBLIC-DOMAIN-CLEARANCE.md`, `docs/content/AUDIO-SOURCES.md`, `docs/ios/APPLE-DELIVERY.md`, `docs/ios/APP-STORE-LISTING.md`, `docs/l10n/HANDOFF.md`.

**What is not recorded.** Review rounds 1 and 2 left no file. Their scores (6.2 and 6.6) come from the project summary, and what they asked for is inferred from the commits that answered them (`2acfbbd`, `35fc427`).

---

## Contents

1. [The brief](#1-the-brief)
2. [How the work was run](#2-how-the-work-was-run)
3. [Phase map](#3-phase-map)
4. [Review score trajectory](#4-review-score-trajectory)
5. [Timeline, phase by phase and round by round](#5-timeline-phase-by-phase-and-round-by-round)
   - [5.1 Phase 0: the Android → iOS port (PR #1)](#51-phase-0-the-android--ios-port-pr-1)
   - [5.2 Phase 1: "Still Point" foundations](#52-phase-1-still-point-foundations)
   - [5.3 Phase 2: the "Studio Noir" redesign and the game layer](#53-phase-2-the-studio-noir-redesign-and-the-game-layer)
   - [5.4 Phase 3: the Learn engine and the first curriculum](#54-phase-3-the-learn-engine-and-the-first-curriculum)
   - [5.5 Round 1 (6.2) → wave 1](#55-round-1-62--wave-1)
   - [5.6 Round 2 (6.6) → wave 2](#56-round-2-66--wave-2)
   - [5.7 Round 3 (6.9) → wave 3](#57-round-3-69--wave-3)
   - [5.8 Wave 4: Songs tab and Originals](#58-wave-4-songs-tab-and-originals)
   - [5.9 Round 4 (7.8) → wave 5](#59-round-4-78--wave-5)
   - [5.10 Round 5 (7.5) → wave 6](#510-round-5-75--wave-6)
   - [5.11 Round 6 (7.7) → wave 7](#511-round-6-77--wave-7)
   - [5.12 Round 7 (7.9) → wave 8](#512-round-7-79--wave-8)
   - [5.13 Round 8 (8.1) → wave 9](#513-round-8-81--wave-9)
   - [5.14 Round 9 (8.6) → wave 10](#514-round-9-86--wave-10)
   - [5.15 Round 10 (8.1) and QA10 → waves 11 and 12](#515-round-10-81-and-qa10--waves-11-and-12)
   - [5.16 Round 11 (8.4) → wave 13](#516-round-11-84--wave-13)
   - [5.17 DESIGN11 audit → wave 14](#517-design11-audit--wave-14)
   - [5.18 Interlude: owner decisions on free tuning, licensing and repertoire](#518-interlude-owner-decisions-on-free-tuning-licensing-and-repertoire)
   - [5.19 Round 12 (8.4) → wave 15](#519-round-12-84--wave-15)
   - [5.20 Round 13 (8.7) → wave 16](#520-round-13-87--wave-16)
   - [5.21 Round 14 (8.9) → wave 17](#521-round-14-89--wave-17)
   - [5.22 Jury round 15 (7.7) → wave 18](#522-jury-round-15-77--wave-18)
   - [5.23 Jury round 16 (8.3) → wave 19](#523-jury-round-16-83--wave-19)
   - [5.24 Round 17 (convened)](#524-round-17-convened)
6. [Major product decisions and why](#6-major-product-decisions-and-why)
7. [Wave 19 in detail](#7-wave-19-in-detail)
8. [What each round said was still missing for #1](#8-what-each-round-said-was-still-missing-for-1)
9. [Where things stand at `0bbf273`](#9-where-things-stand-at-0bbf273)
10. [Appendix A: every commit, in order](#appendix-a-every-commit-in-order)
11. [Appendix B: the review and brief files](#appendix-b-the-review-and-brief-files)
12. [Appendix C: glossary](#appendix-c-glossary)

---

## 1. The brief

The owner set these goals for the iOS version of Timbre, an Android tuner app:

- **Run development like an app agency**, with departments of sub-agents working in parallel, each owning a part of the product.
- **Quality "as if $800k was spent"** on design, content and features. Nothing may look or read "vibe-coded", templated or AI-generated.
- **Take the #1 spot on every angle** against GuitarTuna, Fender Tune and Fender Play, Yousician, Simply Guitar and JustinGuitar (Ultimate Guitar where relevant).
- **Be judged by extremely harsh jurors**, in the style of the Apple Design Awards jury plus App Store editorial and a category expert.
- **Earn $10k a month** on the App Store.
- **All macOS work through GitHub Actions.** Nobody on the team has a Mac or a Swift compiler; CI compiles, tests, captures screenshots and records the App Preview.
- **Translations are done by other people.** Agents write English only.
- **Violin and cello tuning are free.**
- **Find a workaround for song licensing**: public-domain songs plus house-written Originals, until real licences can be bought.

---

## 2. How the work was run

**An orchestrator and teams of sub-agents.** One orchestrating agent planned each wave, split it into teams with disjoint files and merged the result. The commit history shows the shape of each period:
- Phases 0–3 and waves 1–7 (2026-10-22 to 10-23): one stream of commits, each a self-contained change.
- Waves 8–17 (2026-10-24 to 10-25 early morning): parallel teams named by letter (9A–9F, 10A–10H, 11A–11G, 13A–13H, 14A–14F, 15A–15E). While teams worked, the orchestrator snapshotted the tree as "WIP wave N (teams working)" commits, many with `[skip ci]`.
- Waves 18–19: ten **work packages** (WP1–WP10) with one owner per file, written up by the jury foreman. In wave 19 each package ran in its own git worktree and landed as one commit plus a merge (section 7).

**Rules for every agent** (`PREAMBLE.md`, written 2026-10-24 05:05, at the start of wave 9):
- There is no Swift compiler in the agents' environment; CI compiles later. Read every type, token and helper before using it, and never invent an API.
- Keep SwiftUI expressions simple (the compiler's type-checker times out on long chains; several commits fix exactly that, e.g. `96c7a18`, `455efe4`, `2506a24`).
- iOS 18 APIs only, Swift 5 language mode.
- Keep accessibility identifiers (UI tests depend on them), VoiceOver labels, Dynamic Type and Reduce Motion.
- Design language "Studio Noir": dark stage, mint accent, amber/gold for rewards, Sora display type.
- `Text("…")` literals are English localization keys; **don't edit any `.lproj` or `tools/l10n` files**.
- Edit only the files your task names.

**Independent review after each wave.**
- Rounds 3–14: one independent reviewer per round, working from CI screenshots (an iPhone 17 Pro simulator, with iPad 13" frames as well from round 10) and the code. Each file ends with "items for the next wave". Round 10's reviewer took the role of "design director and App Store growth lead".
- Two audits ran beside the reviews: `QA10.md` (a code audit of the last ~40 commits at `55f87c1`) and `DESIGN11.md` (a design-system and accessibility audit of the 70 wave-11 screenshots and the code).
- Rounds 15–16: a **jury of six** plus a **foreman**. The jurors were: visual (a principal product designer with ADA jury experience), delight and innovation (a creative director), inclusivity (an accessibility lead), technical (an ADA technical-achievement juror who is also the acquirer's principal iOS engineer), growth (an App Store editor and subscription-growth lead) and category (a guitar, ukulele and violin teacher and music-tech analyst). The brief (`JURY_BRIEF.md`) fixed the calibration: 10 = better than every competitor with nothing left to fix; 9.5 = ADA winner or finalist; 9.0 = excellent but losing to a named competitor for named reasons; 8.0 = a good app with visible seams; below 7 = amateur or "vibe-coded". Every point given or taken needs a screen or a `file:line`. Jurors also had to look up current competitor facts on the web.
- The foreman combined the six angles in two steps: a weighted mean (Growth and Category ×1.5, Visual, Delight and Technical ×1.0, Inclusivity ×0.75), then a **weakest-link gate** that averages the weighted mean with the lowest angle, because "you are only #1 everywhere when your worst angle is #1" (`REVIEW15.md` §1).

**All macOS work on GitHub Actions.** From the first hours, CI published its evidence (logs, screenshots, archives, rendered cards) to `ci-results/*` branches so agents could read the results without a Mac (`be17ba8`, `5de53b3`). UI tests capture the store screenshots and the App Preview; deterministic demo scenes (`TIMBRE_SCENE`, the debug demo pitch) make them repeatable (section 6.14).

**Strings.** Up to wave 8 the agents translated every new string into all 48 non-English locales themselves (e.g. `9283a33`, `8f2ece8`, `c0b86ef`), and the lessons into 9 languages (`57f108f`, `1f07b0d`, `aeb35cb`, `bc4055f`, `b140b73`). From wave 9 on (`PREAMBLE.md`) agents write English only, and the translator handoff (`c0ae634`) tells human translators what is missing (section 6.12).

---

## 3. Phase map

| Phase | Dates (−03:00) | Commits | What it was | Review that followed |
|---|---|---:|---|---|
| Port | 10-22 19:33 | 1 | Android → native Swift/SwiftUI (`328b7d3`, PR #1) | — |
| Still Point foundations | 10-22 20:33 – 10-23 00:04 | 52 | Subscriptions, 3D stage, practice loop, widgets, Siri, first redesign | — |
| Studio Noir | 10-23 00:55 – 03:08 | 12 | The current design language, XP, quests, badges, Pitch Sniper, photo stages | — |
| Learn engine | 10-23 03:15 – 04:33 | 14 | Curriculum model, lesson player, play-along highway, chord recognizer, 401 lessons | Round 1: 6.2 |
| Wave 1 | 10-23 04:55 – 07:16 | 14 | Review-1 fixes, songs course, store listing, lessons in 5 languages | Round 2: 6.6 |
| Wave 2 | 10-23 07:35 – 09:28 | 11 | Polish pass, backing band, analytics plumbing | Round 3: 6.9 (`REVIEW3.md`) |
| Wave 3 | 10-23 09:58 – 10:10 | 2 | Polish pass 3: steady readout, precision, contextual paywall | — |
| Wave 4 | 10-23 11:02 – 12:04 | 4 | Songs tab, Originals course, guitar to 96 lessons | Round 4: 7.8 (`REVIEW4.md`) |
| Wave 5 | 10-23 12:21 – 14:25 | 6 | Island pill, Today card, 42 achievements, German note names | Round 5: 7.5 (`REVIEW5.md`) |
| Wave 6 | 10-23 15:06 – 16:38 | 6 | First session counts, tempo ladder, share cards, VoiceOver tuner, App Preview pipeline | Round 6: 7.7 (`REVIEW6.md`) |
| Wave 7 | 10-23 17:08 – 18:41 | 5 | Placement pass, Karplus–Strong voices, highway art, Live Activity, plurals | Round 7: 7.9 (`REVIEW7.md`) |
| Wave 8 | 10-24 03:11 – 04:48 | 8 | First parallel teams; Siri/Shortcuts/Control Center | Round 8: 8.1 (`REVIEW8.md`) |
| Wave 9 | 10-24 05:05 – 12:38 | 11 | Strum to tune, deterministic store scenes, placement check | Round 9: 8.6 (`REVIEW9.md`) |
| Wave 10 | 10-24 13:18 – 13:24 | 3 | Live Play hub, tanpura, coach notes, feature paywalls, song sheet | Round 10: 8.1 (`REVIEW10.md`) + `QA10.md` |
| Wave 11 | 10-24 14:43 – 15:57 | 13 | Metal shaders, iPad layouts, Game Center, full-length songs, QA fixes | — |
| Wave 12 | 10-24 16:06 – 16:45 | 5 | Song sheet on real arrangements; 53 instrument-course songs | Round 11: 8.4 (`REVIEW11.md`) |
| Wave 13 | 10-24 17:50 – 18:25 | 8 | Notation and TAB, player's-view neck, strobe disc, Watch app | `DESIGN11.md` |
| Wave 14 | 10-24 18:36 – 19:08 | 2 | Design-system foundation applied app-wide | — |
| Interlude | 10-24 19:51 – 21:55 | 8 | Violin and cello free, licensing playbook, 30 Originals, Standards & Classics | Round 12: 8.4 (`REVIEW12.md`) |
| Wave 15 | 10-24 22:07 – 23:01 | 10 | CC0 sampled instruments, spaced review, Game Center challenges, 4+ content | Round 13: 8.7 (`REVIEW13.md`) |
| Wave 16 | 10-25 00:18 – 03:27 | 21 | Show me in 3D, adult-first shelves, sampled guitar, guitar units 17–22 | Round 14: 8.9 (`REVIEW14.md`) |
| Wave 17 | 10-25 04:32 – 07:13 | 17 | Paywall rail, one guitar look, song spotlights, translator handoff, bowed pegs | Jury round 15: 7.7 (`REVIEW15.md`) |
| Wave 18 | 10-25 07:56 – 12:53 | 27 | First WP1–WP10 wave: trust, funnel, listening, left-handed, free tier | Jury round 16: 8.3 (`REVIEW16.md`) |
| Wave 19 | 10-25 13:05 – 16:25 | 43 | Ten packages in worktrees, 4-group integration, audio and QA follow-ups | Round 17: convened (`JURY17_BRIEF.md`) |

The full list of commits, with the phase each belongs to, is in [Appendix A](#appendix-a-every-commit-in-order).

---

## 4. Review score trajectory

### 4.1 Overall score by round

| Round | File (written, −03:00) | Reviewer | Overall | Change | Wave that answered it |
|---:|---|---|---:|---:|---|
| 1 | none | not recorded | 6.2 | — | Wave 1 (`2acfbbd` "Review 1 fixes") |
| 2 | none | not recorded | 6.6 | +0.4 | Wave 2 (`35fc427`) |
| 3 | `REVIEW3.md` (10-23 09:25) | independent reviewer | 6.9 | +0.3 | Wave 3 (`356daa3`) |
| 4 | `REVIEW4.md` (10-23 11:52) | independent reviewer | 7.8 | +0.9 | Wave 5 (`2ab038b`) |
| 5 | `REVIEW5.md` (10-23 14:35) | independent reviewer | 7.5 | −0.3 | Wave 6 (`ae77d65`) |
| 6 | `REVIEW6.md` (10-23 16:36) | independent reviewer | 7.7 | +0.2 | Wave 7 (`9a46c7a`) |
| 7 | `REVIEW7.md` (10-23 18:49) | independent reviewer | 7.9 | +0.2 | Wave 8 |
| 8 | `REVIEW8.md` (10-24 04:57) | independent reviewer | 8.1 | +0.2 | Wave 9 |
| 9 | `REVIEW9.md` (10-24 12:47) | independent reviewer | 8.6 | +0.5 | Wave 10 |
| 10 | `REVIEW10.md` (10-24 14:23) | design director and App Store growth lead | 8.1 | −0.5 | Waves 11–12 (with `QA10.md`) |
| 11 | `REVIEW11.md` (10-24 17:35) | independent reviewer | 8.4 | +0.3 | Wave 13 (and `DESIGN11.md` → wave 14) |
| 12 | `REVIEW12.md` (10-24 22:05) | independent reviewer ("strict") | 8.4 | 0.0 | Wave 15 |
| 13 | `REVIEW13.md` (10-25 00:12) | independent "jury pass" | 8.7 | +0.3 | Wave 16 |
| 14 | `REVIEW14.md` (10-25 04:18) | independent "jury pass" | 8.9 | +0.2 | Wave 17 |
| 15 | `REVIEW15.md` + six `JURY15-*.md` (10-25 07:26–07:53) | jury of six + foreman | **7.7** | −1.2 | Wave 18 |
| 16 | `REVIEW16.md` + six `JURY16-*.md` (10-25 12:26–12:52) | jury of six + foreman | **8.3** | +0.6 | Wave 19 |
| 17 | `JURY17_BRIEF.md` (10-25 15:37) | jury of six + foreman | pending | — | — |

I checked every score against its file. Rounds 3–16 match the trajectory in the project summary exactly (6.9, 7.8, 7.5, 7.7, 7.9, 8.1, 8.6, 8.1, 8.4, 8.4, 8.7, 8.9; jury 7.7 and 8.3). Rounds 1 and 2 (6.2, 6.6) have no file to check against.

Each `#` is 0.1 point above 5.0:

```
   round  score
       1  6.2  ############
       2  6.6  ################
       3  6.9  ###################
       4  7.8  ############################
       5  7.5  #########################
       6  7.7  ###########################
       7  7.9  #############################
       8  8.1  ###############################
       9  8.6  ####################################
      10  8.1  ###############################
      11  8.4  ##################################
      12  8.4  ##################################
      13  8.7  #####################################
      14  8.9  #######################################
 15 jury  7.7  ###########################
 16 jury  8.3  #################################
```

### 4.2 Why the score fell three times

- **Round 5 (7.8 → 7.5).** The reviewer judged the first session as a new user meets it ("each UI test launches fresh with seeded data") and found it untrue: the onboarding tune was thrown away (streak 0 right after tuning), "Flawless" showed at 90 %, and the listing promised a tempo ladder the play-along didn't have (`REVIEW5.md` items 1, 2, 5).
- **Round 10 (8.6 → 8.1).** A reviewer with a growth brief judged content value against the lesson apps. The 52 "songs" were 8-bar loops of 10–108 s (median about 28 s) with no lyrics, so Lessons fell to 7.4, and the iPad layouts were stretched phone layouts (`REVIEW10.md` §1).
- **Round 15 (8.9 → 7.7).** The jury audited what happens off the screenshot, which no single reviewer had done, and verified six latent blockers: every fresh install ran in English; one bad state file locked the user out for good; strum steps graded timing only; tuner haptics were very likely muted while the microphone listened; nothing was measured; the App Preview was silent and never showed a lock. The weakest-link gate also pulled the overall toward Growth (7.4) (`REVIEW15.md` §1).

### 4.3 Per-area scores, single-reviewer rounds 7–14

Rounds 3–6 gave an overall score only. Round 7 introduced area scores, and round 8 added Platform integration.

| Area | R7 | R8 | R9 | R10 | R11 | R12 | R13 | R14 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Visual design and polish | 8.3 | 8.4 | 8.5 | 8.2 | 8.5 | 8.6 | 8.7 | 8.9 |
| Motion and delight | 7.4 | 7.8 | 8.5 | 8.0 | 8.5 | 8.6 | 8.8 | 9.0 |
| Tuner | 8.6 | 8.5 | 9.2 | 9.1 | 9.2 | 9.3 | 9.4 | 9.4 |
| Lessons and curriculum | 7.7 | 8.0 | 8.3 | 7.4 | 7.8 | 7.6 | 8.3 | 8.6 |
| Retention and habit loop | 8.0 | 8.4 | 8.6 | 8.3 | 8.7 | 8.6 | 9.0 | 9.1 |
| Monetization and paywall | 7.6 | 8.0 | 8.4 | 8.2 | 8.4 | 8.0 | 8.6 | 8.8 |
| Platform integration | — | 8.3 | 8.0 | 8.6 | 8.2 | 9.2 | 9.3 | 9.3 |
| Store readiness | 7.2 | 6.8 | 8.6 | 7.6 | 7.4 | 8.0 | 8.2 | 8.2 |
| **Overall** | **7.9** | **8.1** | **8.6** | **8.1** | **8.4** | **8.4** | **8.7** | **8.9** |

The pattern: the tuner reached 9+ by round 9 and stayed the strongest area. Lessons (content value: songs people know, a visible teacher) and store readiness (the screenshots, the App Preview, the privacy URL) were the weakest areas in every round.

### 4.4 Per-angle scores, jury rounds 15–16

| Angle | Juror | R15 | R16 | Change |
|---|---|---:|---:|---:|
| Visual and interaction | principal product designer | 8.6 | 8.8 | +0.2 |
| Delight and innovation | creative director | 8.3 | 8.7 | +0.4 |
| Inclusivity | accessibility lead | 8.3 | 8.7 | +0.4 |
| Technical and acquirer due diligence | ADA technical juror / acquirer's iOS engineer | 8.1 | 8.5 | +0.4 |
| Growth and App Store editorial | App Store editor, subscription-growth lead | 7.4 | 8.1 | +0.7 |
| Category expert | guitar, ukulele and violin teacher | 7.8 | 8.3 | +0.5 |
| Weighted mean | | 8.00 | 8.46 | +0.46 |
| Weakest angle | | 7.4 | 8.1 | +0.7 |
| **Overall** (weighted mean and weakest angle, averaged) | foreman | **7.7** | **8.3** | **+0.6** |
| Plain mean (reference only) | | 8.08 | 8.52 | +0.44 |

**Who is #1 on each angle** (the foreman's count, unchanged between rounds 15 and 16, "every margin narrowed"):
- a clean #1 on 1 of 6 angles: **Inclusivity**;
- split on 3: Visual (in-app craft yes; Simply Guitar on art direction, GuitarTuna on brand), Delight (Innovation yes; Yousician and Simply on fun), Category (tuner, breadth, price and free tier yes; songs and a visible teacher no);
- lost on 2: Technical (narrowly, to Yousician: recognition proven at scale, sync, live operations) and Growth (Timbre last on the storefront: 0 ratings, against tens to hundreds of thousands for each competitor).

**The foreman's projections** (`REVIEW15.md` §3, `REVIEW16.md` §3): code alone reaches about 8.6–8.8 (round 15 estimate) or 8.7 (round 16). With the owner's levers (licensed songs, teacher clips and a hand, the icon and art direction, translations, a real-audio corpus, early ratings), the overall reaches about 9.0–9.1. "#1 on all angles is not reachable with code alone."

---

## 5. Timeline, phase by phase and round by round

Each subsection gives the review (score, main findings with blockers first) and then what the following wave changed, grouped by team or work package, with commit hashes.

### 5.1 Phase 0: the Android → iOS port (PR #1)

**`328b7d3`, 2026-10-22 19:33, "Port Timbre to native Swift and SwiftUI for iOS (#1)".** It is the only commit authored under the owner's GitHub account (`azerish25-ux`); the other 302 are authored "Claude". It squashes 20 port commits: Swift project and macOS verification workflow; the musical core, catalogue, vocal scoring and durable history in Swift; the SwiftUI app with audio and StoreKit; parity fixes against the Android source; SDK and drawing compile fixes; Xcode 26.3 in CI; a launch crash from an unconfigured ad SDK; real permission and keyboard flows; StoreKit refreshes; iPad layouts; the elapsed-timer privacy reason; delivery docs.

What the port contained (409 files, 52,301 lines; `docs/ios/final-review.md` and `docs/ios/parity-audit.md` as of `328b7d3`):
- the Android app's 60 instruments in 8 families, 102 preset tunings, 71 photographic instrument variants (142 image sets), reference tones, 8 vocal exercises, a metronome ("Studio"), measured practice history, 49 language tables, the original fonts and palette;
- a one-time unlock through StoreKit 2, and the Android ad policy (interstitials after free tuning sessions) as an **optional** Google Mobile Ads overlay (`project-ads.yml`); the baseline build linked no ad SDK;
- iOS 17 minimum at that point;
- 90 automated tests green on the verified revision (64 core, 18 app integration and StoreKit, 7 iPhone UI flows, 1 iPad flow), an unsigned Release archive, resource checks (CI run 39862780625).

The port also brought planning files to the repository root (`findings.md`, `progress.md`, `task_plan.md`). They stayed until wave 18 removed them, because `findings.md` leaked a personal Windows path and authentication notes (`0785642`; `REVIEW15.md` §2b).

### 5.2 Phase 1: "Still Point" foundations

**2026-10-22 20:33 to 10-23 00:04, 52 commits.** The port was a faithful copy of a simple tuner. This phase turned it into a subscription product.

**3D instruments built from code in Blender.**
- `be17ba8`: a procedural 3D pipeline. Headless Blender in CI builds parametric guitar, bass and ukulele models from code, exports USDZ with rig anchors named after the catalogue's anchor ids, renders studio previews and publishes the results to `ci-results/*` branches.
- A side branch of model work, merged at `939dae3`: offset-waist P and J basses (`81c45fc`, `d22d621`), the violin family on a friction-peg rig with arched plates, f-holes, purfling and scrolls (`ab07472`, `3c74c7d`, `acf0ff4`), strings to the correct posts (`ff18bea`).
- Installs: `0816c7c` (basses, uke and guitar post order, violin family), `2c32f66` (14 more: guitars, ukes, mandolin family, bouzouki, balalaika, domra), `66f7945` (mandolin, mandola, mandocello), `c0ea646` (banjo, kalimba), `1fdf96c` (9 winds and brass, with slide rigs that move the main slide, head joint, barrel or mouthpiece with the pitch). By the end of the phase 35 procedural USDZ models were in the app (`464cb4a`).
- Stage behaviour: per-string pegs for paired courses (`2b4f29d`), slide motion for winds (`88f4d59`, `9516c8a`), a close-up that aims at the peg being tuned (`ca02ce5`), a studio render that holds the stage while the model loads and cross-fades (`68d91aa`, `dd47c75`).

**Core engines** (`3e8baa2`):
- `AccessPolicy` and product ids for annual and monthly subscriptions plus lifetime; every preset tuning of a free instrument free;
- a One Euro display filter and a strobe phase integrator; streaks and a daily practice set; ear training; a chord voicing finder and scale maps; a tanpura drone; metronome levels and sounds;
- Accelerate-backed autocorrelation with the pure-Swift FFT as a fallback, and a plucked-string accuracy bench;
- **advertising code removed**; platforms iOS 18 and macOS 15.

The bench was made honest in `bfcf72a`: harmonic plucks within 0.75 cent, and stiff strings allowed to read the slightly sharp periodicity listeners hear, bounded at 5.5 cents.

**The app** (`b66f0a6`, "Still Point redesign"):
- a design system with tokens, Liquid Glass panels, brass controls and haptics;
- the tune screen: a RealityKit 3D instrument whose peg follows the measured cents, a vibrating string whose strobe drift freezes in tune, a 2D studio fallback, a chromatic strobe disc, auto-listen, turn hints, a full-tune celebration with a share card and a review prompt;
- onboarding (instrument, level, goal, microphone priming) and a subscription paywall;
- a practice hub with a daily set and streaks; metronome (accents, odd meters, speed trainer), ear training, chord finder, scale maps, drone, voice;
- Journey: streaks, a 12-week heat map, accuracy trend, milestones;
- tests for StoreKit subscriptions, app integration and a UI screenshot tour.

**Platform and delivery:**
- Siri and Shortcuts entry points (`d9ddf76`); widgets for quick tune and the practice streak (Home and Lock Screen), a Control Center tuner and `timbre://` deep links (`3137106`);
- automatic signing with an App Store Connect API key for the app, widgets and App Group, plus docs for **subscriptions and no ads** (`d7df85f`);
- Pro features: custom tunings with per-string semitone steps (`6b44986`) and an intonation check at the 12th fret with saddle advice (`6ed77fe`); a two-column tuner for landscape and iPad (`dc11fed`);
- a debug demo pitch that drives the tuner for screenshots and an App Store screenshot composer (`55e8b1c`); a paywall where the instrument sways in a 3D spotlight (`b76425b`).

**Localization tooling:** xliff export of every source string (`8a96e58`), a list of untranslated strings (`f3d99a1`), a merge tool with format-specifier checks (`ec3c7d3`, `eb49087`), English plural rules (`7340ffd`). 381 new strings were translated into 48 languages in one commit, 0 specifier mismatches (`9283a33`).

**Presentation bugs** found by UI tests and fixed: the paywall never appeared from a clear background anchor (`8083727`), so it became an overlay (`f943c61`); a UI-test probe for presentation flags (`80e0740`, `448c664`); and dead taps on card buttons on iOS 26, because the glass background was not hit-testable (`464cb4a`, "this was why the paywall never opened in test06").

The port audits were marked historical (`daaac99`).

### 5.3 Phase 2: the "Studio Noir" redesign and the game layer

**2026-10-23 00:55 to 03:08, 12 commits.** "Still Point" was replaced by the design language the app still uses.

- `de06563` "Studio Noir redesign, part 1": a near-black stage, amber for the cue, mint for in tune; Sora display type (OFL, bundled); the tune screen with the instrument and A4 in the header beside streak and level, side controls on the stage, a big note readout, a ribbon meter with strobe shimmer, round string chips; **XP and levels, three daily quests, 12 achievements and per-string drift between sessions ("string health")** in TimbreCore; Pitch Sniper game logic; a reward toast; tabs Tune, Play, Instruments, Progress; dark appearance only.
- `5767850`: the Play hub (level, quests, ear games, tools) and the Pitch Sniper game.
- `75945df`: Progress, Instruments, Paywall and Welcome in the new design (three floating instruments on the paywall, side-by-side plans with a trial tag).
- `20cab25`: a 2D photo stage with per-string points, artist model credits, the celebration in the new look.
- `fc8c508`: Pro copy says "stage", not "3D", for every instrument.
- `8f2ece8`: 103 new strings in 48 languages.

**The procedural 3D models were retired** (`b414a5d`, `463b9f2`): the app went from 35 USDZ models to 2. The acoustic and electric guitars moved to artist models in 3D; every other instrument went onto its photograph with per-string tuning anchors in `photo-rigs.json` for all 60 photos; the resource check began to require a Creative Commons credit on every artist model. CI evidence from side branches got its own results branch (`5de53b3`).

### 5.4 Phase 3: the Learn engine and the first curriculum

**2026-10-23 03:15 to 04:33, 14 commits.**

- `3327fb4` Learn engine: courses → units → lessons → steps (explain, notes, play-along, chord, strum, tap, listen, quiz) decoded from `curriculum.json`; `PlayAlongJudge` (timing and intonation windows, combo, a repeated note needs a new attack), `NoteSequenceJudge`, `LessonRun` (stars, XP) and `LearnProgress` (unlocks, best). **`tools/curriculum`**, a Python builder that checks every fret against its pitch and every chord shape against its chord, and hashes lesson text into `Learn.strings` keys. Guitar unit 1 as the style reference.
- `56dd37f` Learn tab: course carousel, continue card, a winding lesson path, the lesson player (drawn fretboards, chord boxes, staff, keyboard and rhythm pictures; note steps with a hold ring; chord steps that check each string; tap and strum rhythm steps; listen and quiz steps) and the **play-along highway** (count-in, tempo choice, string or pitch lanes, gems that burst on hits, combo, a live pitch trail for singing). Synthesized interface sounds that never interrupt the microphone.
- `2c51bca`: a tune check before the day's first playing step; a trial timeline on the paywall.
- Courses: rhythm steps with meters (`61677c6`, `ac083c6`); ear training 40, theory 44, rhythm 29, singing 29 lessons (`4fa98f0`); guitar 60 lessons, a daily reminder, a rating ask after flawless lessons (`b34f787`); progression steps with timed chord changes (`de962ed`).
- **DSP** on a side branch (`43b1849`, merged at `214bdc6`): `ChordRecognizer` (spectral peaks, tuning offset, overtone removal, 12-bin chroma, cosine matching against eight chord qualities on 12 roots) and a SuperFlux-style `OnsetDetector` with `RhythmJudge` (perfect ≤ 40 ms, good ≤ 90 ms). `619e6c9` wired them in: chord steps pass on a recognised strum, strum steps use real onsets.
- `b0f5ee2`: **seven artist 3D instruments** (acoustic, classical and electric guitar, bass, mandolin, violin, cello; CC-BY models of 3–7.5 MB each, credited in Acknowledgements) and **11 courses / 401 lessons** (guitar 60, ukulele 36, bass 31, violin 38, cello 31, mandolin 33, banjo 30, ear 40, theory 44, rhythm 29, singing 29). Each lesson step owns the microphone, so a step leaving can't stop the next one.

### 5.5 Round 1 (6.2) → wave 1

**Round 1.** No file survives; score from the project summary. The answering commit's message lists what it fixed.

**Wave 1 (2026-10-23 04:55 to 07:16).**
- `2acfbbd` "Review 1 fixes": a perspective play-along runway with string colours, timing feedback in ms and a slower retry, strum arrows, tap-or-play, an "I played it" override, answer tiles, a fingerboard lesson path, a pinned paywall button with three plans, tools hide the tab bar, one smoothed value in the tuner status, US spelling, badge fixes; the songs course split in two.
- `ca358cf`: the celebration and share card show the tune-up time.
- **Songs:** `5fe65c5` songs course part 1 (21 public-domain songs and medleys) and the screenshot composer in the new design; `79dbba2` part 2 (hymns and Americana, holiday songs, classical themes), 439 lessons in all.
- **Store:** `dde709a` App Store listing (name, subtitle, keywords, description, review notes, IAP names, pricing note); `df90f0b` dark and tinted icon variants.
- **Retention:** `83d4cb8` lesson results with level bar, level-up fanfare and badges; `6c2e289` a Next lesson widget; `6ac9539` streak freezes (one banked every seventh day, up to two) and reminders planned day by day.
- **Lessons translated by agents:** Spanish, all 4,121 lesson strings, with `apply_learn.py` rejecting translations that change numbers or accidentals (`57f108f`); German, Brazilian Portuguese, Japanese (`1f07b0d`); French (`aeb35cb`).
- CI: evidence leaves out files over 45 MB and falls back to logs (`1f07b0d`); tab taps retry (`14631ab`).

### 5.6 Round 2 (6.6) → wave 2

**Round 2.** No file survives; score from the project summary.

**Wave 2 (2026-10-23 07:35 to 09:28).**
- `35fc427` "Polish pass from review round 2":
  - paywall: plans above the fold with a compact hero, a save-% tag, a pinned bar nothing hides under; the trial reminder is promised only when notifications can deliver it;
  - tuner: one colour rule tied to the lock band; digits and status from the same rounded value; the 3D stage marks the peg to turn with its direction; a blank-stage race fixed;
  - practice tools: edge-to-edge chip rails, metronome and drone docks, chord play buttons and finger numbers;
  - Progress and Play: aligned achievements with progress rings, string-health bars; ear training rebuilt;
  - onboarding: no pre-selected answers, placement from experience, a "Your plan" screen before the paywall; visuals on every explain step, Hear it on chords;
  - CI app job timeout 45 min.
- Lessons in Italian, Russian, Korean (`bc4055f`) and Simplified Chinese (`b140b73`).
- `b77dfbe`: the store name carries "guitar tuner" (**Timbre: Guitar Tuner & Lessons**); CI skips docs-only pushes.
- `974b79e`: a **backing band** for play-along, strum and progression steps (synthesized drums, bass and pad in sample sync with the metronome), only through headphones (the speaker keeps the click), with a toggle.
- `660de99`: **analytics ready to switch on** (TelemetryDeck ingest, anonymous, batched, off until `TELEMETRYDECK_APP_ID` is set); privacy manifests declare the UserDefaults reasons and product-interaction analytics.

### 5.7 Round 3 (6.9) → wave 3

**Round 3, `REVIEW3.md`, 6.9.** Screenshots on an iPhone 17 Pro simulator.
1. Overlays and safe areas: the XP/quest/badge toast covers the tune header; scrolled content runs under the clock; floating CTAs hide content.
2. Paywall: the timeline captions are hidden at first view; the headline doesn't follow the reason it opened.
3. Live readout: `.numericText` on a 60 Hz value leaves half-rolled digits ("−1½ cents"), and the width changes.
4. Rhythm steps can be passed by tapping the glass.
5. No precision mode (the tracker is a fixed ±5¢).
6. No "aha" before the paywall: the welcome says "Start tuning" but leads to questions.
7. Lesson visuals: no fretboard on note steps, strings drawn equal, empty lower halves.
8. Quests show one action three ways.
9. Algorithmic chord voicings (875050), scale tones as 1–5.
10. Motion and sound: cross-fades, sine cues.
- Bugs: "Bar 2 of 2" in the ready state; "cents" hard-coded English and unpluralised; the selected chip label vanishes at lock; truncations; ear training says "Listening…" while the app plays; low-contrast disabled buttons.

**Wave 3 (`356daa3`, 09:58; strings `0c42eec`).**
- Tuner: a steady readout (10 Hz updates, hysteresis, a fixed-width ¢ column); a precision setting (±5/±3/±1¢, Pro for ±1¢ and the strobe band); a lock bell at the string's pitch with detection paused while it rings; a camera dolly instead of a cross-fade; the string drawn along its real anchors.
- Rewards: a Dynamic-Island pill that queues one banner at a time instead of covering the header; a new plucked/bell sound palette.
- Paywall: plans, trial timeline and CTA fit a 6.1-inch screen; the headline follows the reason.
- Onboarding: a first-tune moment before the plan.
- Lessons: tap-to-pass only without a microphone ("Practice mode", one star at most), a neck strip on note steps, a strum sweep, strings thicker toward the bass, a zoom into lessons.
- Practice: curated guitar chord shapes, intervals on scales with a scrolling neck.
- The App Store listing localized for 9 locales.

### 5.8 Wave 4: Songs tab and Originals

**2026-10-23 11:02 to 12:04, between rounds 3 and 4.**
- `1983645`: a **Songs tab replaces the Instruments tab** (song of the day, shelves by course with generated covers, an instrument filter; the full instrument browser stays in the tuner's picker). The guitar course grows to 16 units / 96 lessons (fingerpicking, blues, lead technique, moving barres, rhythm styles, capo and arranging). A new **Originals course: 20 original songs in contemporary styles plus 4 challenges**. 499 lessons in all.
- `5d68c3b`: the new units and Originals in all 9 lesson languages.
- `56703ad`, `fced833`: listings (English and localized) with "499 lessons in 13 courses", an accurate free tier and the Songs tab.

### 5.9 Round 4 (7.8) → wave 5

**Round 4, `REVIEW4.md`, 7.8.**
1. The reward toast sits on the status bar: the safe-area inset is read inside `.ignoresSafeArea()` and comes back 0.
2. A free user who picks violin or cello (Pro), tunes it in onboarding and declines the paywall silently lands on the acoustic guitar.
3. The "Tune every string" quest disagrees between screens (2/6 vs 0/6).
4. Drone rings clipped; the quick tune check's subtitle truncates and its labels overlap.
5. Copy and layout: "In tune" three times on one screen; the results header jumps; a stock Form for Settings; the level ring "5" has no label.
6. Onboarding promises "Your daily set is built around it", but the daily set is never shown.
7. String orientation flips between diagrams; barre chords drawn as separate dots.
8. SF-Symbol iconography (every course card a music note); a giant leaf as a song cover.
9. All 16 badges are the same teal disc.
10. German lessons use "B" for B natural in some places and "H" in others.
11. Practice tools lack hero moments; audio lacks reverb and humanization.

**Wave 5 (`2ab038b`, 12:21; follow-ups to 14:25).**
- The pill really grows from the Dynamic Island (the safe area measured outside `ignoresSafeArea`); the level ring labelled.
- A **Today card**: the daily set as a ring of tools that completes with a celebration and counts for the streak.
- Quest progress persists all day; **42 tiered achievements** with category art and a shine on unlock.
- Free players who choose a Pro instrument land in Chromatic with that instrument's strings as targets, and Pro badges show on the welcome chips.
- Course and paywall art from the app's own renders; typographic song covers.
- **German note names** (H for B natural, B for B flat) across the tuner, tools, lessons and diagrams; card-style Settings.
- Strings numbered on every diagram; real barre bars; drone rings inside their frame; metronome glow; a 12th-fret intonation diagram; custom-tuning headstock badges.
- Room reverb on sounds and band, a humanized band, a resolving chord when every string is in tune.
- `29427cd`: achievements, level names and wave-5 labels in all 48 languages ("they were never localized before"); `bb09492`: CI app job to 60 min (the UI flow suite ran about 41 min).

### 5.10 Round 5 (7.5) → wave 6

**Round 5, `REVIEW5.md`, 7.5.** Blockers first:
1. **The first session doesn't count.** `OnboardingView` discards the first-tune result, so a new user lands on the tuner with streak 0, level 1, quest 0/6. Record it as practice, award "First in tune", open the placed first lesson after the paywall, and ask for daily minutes and a reminder time on the plan screen.
2. **Results tell untruths and overlap.** "Flawless" shows at 90 % accuracy; content slides under the buttons.
3. Collisions and copy: a double number in the quest line; mandolin shown as 8 chips; bursts over text.
4. String orientation differs between note/quiz/song diagrams and strum/intonation views.
5. **The listing promises a play-along that "slows down for you, then speeds back up"**, but only a one-time 75 % drop exists; no Bluetooth latency calibration.
6. Learn's "Today", Play's daily set, quests and the lesson path compete.
7. The `review` lesson kind exists but nothing uses it.
8. Explain steps should demonstrate, then let the learner play back.
9. Motion: matched transitions, full-screen unit and level moments.
10. No share cards.
11. Accessibility: a VoiceOver tuner that speaks note and cents, adjustable actions, Increase Contrast and Differentiate Without Color.
12. Store assets: an App Preview, outcome captions, a Live Activity, the privacy URL.
- Logic bugs: "Restring soon" fires on new strings still stretching; combos count late and early notes.

**Wave 6 (`ae77d65`, 15:06; follow-ups to 16:38).**
- First session counts: the onboarding tune saves practice, earns XP and "First in tune" (streak 1); after the paywall the placed first lesson opens; daily minutes and a reminder time on the plan screen.
- **One Today:** next lesson plus tool reps plus a review when due, in one ring across Play, Learn and the streak chip.
- **Weak-spot reviews** generated from low-accuracy notes and chords.
- **Play-along tempo ladder** (75 → 90 → 100 → 110 %, stepping up at ≥ 90 %), per-route tap-along latency calibration, combos only from Perfect and Good.
- Show-then-play chord demos; thinnest/thickest labels on every string view.
- "Flawless" only at ≥ 98 %; **share cards** for 3-star lessons, songs and streak milestones (7/30/100).
- Tuner: paired courses as ×2 chips; **VoiceOver announcements with an in-tune haptic; Increase Contrast and Differentiate Without Color**; restring advice ignores new-string stretch.
- `3635859`: the **App Preview pipeline**: a scripted UI tour and a workflow that records the simulator and cuts an App Store preview (886×1920, 30 fps, silent AAC) with a poster frame; outcome-led screenshot captions. Follow-ups made the tour robust (`eae6c4a`, `125dd2b`).

### 5.11 Round 6 (7.7) → wave 7

**Round 6, `REVIEW6.md`, 7.7.**
1. **The plan's promise breaks.** The plan card says "First lesson: … Unit 2", but after "Continue with the free tuner" Unit 1 opens, because the placed lesson is Pro.
2. "Hear it" and the reference tones sound like an organ (additive synthesis).
3. String orientation still flips.
4. Paywall bullets are inventory counts, not outcomes; no live preview.
5. The highway and strum views look thin; this is the App Preview's hero shot.
6. No Live Activity or Dynamic Island.
- Bugs: content cut at the fold; "Acoustic / electric guitar" in Recent; achievements reserve an empty line; a song monogram cropped; **plurals exist only in English**; a capture shows the wrong step.

**Wave 7 (`9a46c7a`, 17:08; follow-ups to 18:41).**
- **Placement pass:** the first lesson of the placed unit is free, so the plan and the lesson that opens agree (`AccessPolicy`, tested).
- **Instrument voices:** Karplus–Strong plucks with strum spread and body resonance; bowed, wind and sung voices with vibrato; per-instrument Hear it, chord play buttons, listen steps and reference tones.
- Play-along: a rosewood runway, glossy gems with sustain tails, hit beams and bursts, a combo multiplier, a next-notes rail; a strum view on a wooden soundboard; lanes follow a new String order setting.
- Paywall: outcome bullets for the user's goal, a live mini play-along, the user's first milestones above the trial track.
- **Live Activity and Dynamic Island** for metronome, drone and practice sessions.
- **Plural rules (stringsdict) for all 48 locales.**
- App Preview: clips placed by matching sync screenshots, hands-off tuner locks, a recorder handshake and up to 3 retakes, because the recorder started 3 s late and lost frames mid-tour (`04ca81a`); the demo pitch plays a play-along on time so footage shows Perfect hits instead of a 42 % take, DEBUG only (`ec3df9a`).

### 5.12 Round 7 (7.9) → wave 8

**Round 7, `REVIEW7.md`, 7.9.** Per-area scores in section 4.3. Ranked:
1. The tuner hero (store shot #1) doesn't show which peg to turn: the default 3D view sits on a small whole instrument.
2. The highway is not worth an App Preview: a 2.8 s look-ahead shows one small gem at 60 BPM.
3. Two paywall timelines stacked; a cramped hero; the drone paywall's bullets talk about songs.
4. The reminder opt-in is hidden under "Next lesson".
5. No share moments beyond the tuner.
6. Explain and chord steps are static (741 of 3,478 steps are explain steps).
7. The strum pattern is drawn three ways.
8. Songs don't sell: a level-5 player on a 7-day streak gets "Mary Had a Little Lamb" as Song of the Day; covers are two-letter monograms.
9. The screenshot set disagrees with the listing (400+ vs 499 lessons) and isn't locked.
10. The metronome doesn't move.
11. Progress readability ("5 / Sweet Spot" reads as a count).
12. String rail states.
- Bugs: **the debug probe shows in the review screenshots**; store shot 10b isn't locked; the reminder CTA is clipped; a lesson that calls G on string 1 "open" (it is fret 3); the privacy URL is a placeholder.
- Outside assets: licensed songs, real ratings, the privacy URL, prices and offers, Game Center, the final App Preview cut.

**Wave 8 (2026-10-24 03:11 to 04:48).** The first wave run as parallel teams. The snapshots are named after them: `85eb0ea` (WIP), `11ef24a` (lesson steps team done), `f0fb9ba` (paywall team done), `116a29d` (songs and metronome team done). Also:
- `4ac0fe8`: Siri, Shortcuts and Control Center intents (tune, metronome, drone, lesson, streak), metronome control, one deep-link router.
- `c0b86ef`: wave-8 strings in 48 languages with a stricter token check. **This was the last time agents translated strings.**
- `413e5cc`: six corrected lesson lines in 9 languages.

What the wave fixed, as round 8 verified it (`REVIEW8.md`, "Fixed since round 7"): the peg cue holds in steady state; the selected string is raised and finished strings get a ✓; the paywall has one track and its bullets match its reason; the reminder row is on results; the play-along has a timing strip, an amber "Keep going" and "Try it at 45 BPM"; the strum step says "120 ms late"; the chord step ticks each string; Progress shows "Lv" and "±¢", a heatmap with weekday initials and a week recap with Share; the pendulum swings; the drone tonics sit in a grid; new song covers and Song of the Day; the debug probe is gone.

### 5.13 Round 8 (8.1) → wave 9

**Round 8, `REVIEW8.md`, 8.1.**
- Regression: **the violin tuner renders a mandolin headstock**. A late model load lands after the wanted one, because `load` never checks after the `await` that the model is still wanted.
- **Half the store frames are wrong**: frames #7 and #8 capture the paywall because a press-and-drag lands as a tap on a Pro card; #1 shows "Hold it…" with no ✓; #3 lights 2 of 6 strings. Recommendation: a `TIMBRE_SCENE` launch argument that renders each hero state directly.
- A player with "a few years" is placed at Unit 2 and promised "Three notes on string 2" right before the $34.99 ask.
- The paywall hero is a collage with reversed lane colours; jargon copy.
- "Your instruments" shows one card in a row that sells 60.
- The metronome's beat row should be the hero; lesson steps leave large empty bands; explain steps still static; idle bowed stages sit on a wide shot.
- The share poster arrives below the fold; Song of the Day duplicated; welcome chips cut through "Violin PRO".
- A wrong answer key in the curriculum (Kite Weather "climbs or falls").
- Outside: the privacy URL, ratings, licensed songs, Game Center, a Watch decision, **lesson text in only 10 of 49 languages** ("fund translation, or say 'tuner' only in the other 39 store descriptions"), prices and trial length.

**Wave 9 (2026-10-24 05:05 to 12:38).** `PREAMBLE.md` was written at the start of this wave.
- `99b1c9f`, `936b4d2`: **Strum to tune**, a polyphonic tuner engine (one strum, every string) with synthetic-chord tests, and its screen with per-string meters and a fine-tune hand-off.
- 9A/9B (`aae487c`): **deterministic store scenes (`TIMBRE_SCENE`)**, checked store frames, the shelf drag fixed; one model load per instrument with stale loads dropped (the violin fix), peg close-ups for every stage, 3D shots wait for the model.
- 9C (`9040c17`): a per-course placement table with a **45-second placement check**; the plan names skipped units.
- 9D (`f734280`): the paywall hero is one scene of the player's instrument feeding the real highway lanes; plain headline; the track shows the next distinct outcome.
- 9E (`cfbb108`): lesson steps fill the screen (an action bar, 60 % diagrams, fret numbers); explain steps auto-play their demo; quizzes anchored low.
- 9F (`d8fdcae`): a fuller instrument shelf, the metronome beat row as hero, a share pill on results and play-along, song progress on covers.
- `8e280f8`: UI tests reach the guitar grid by the family chip and trust the hands-off picture.

### 5.14 Round 9 (8.6) → wave 10

**Round 9, `REVIEW9.md`, 8.6.** "Nothing else in the category has a tuner this good" (Tuner 9.2). Ranked:
1. **Funnel defects** on the last two screens before purchase: "Your plan" overlaps its subtitle; the trial timeline breaks "Greensleeve / s".
2. Song lessons need a song-specific opener (a song sheet with key, BPM, chord strip and section map) and a finale (a Perform take with a story-sized share card).
3. One string orientation through a lesson.
4. Play hub tiles as live previews.
5. Feature-specific paywall heroes and a price anchor (~~$83.88~~ $34.99), with a "What's in Pro" table.
6. The drone as a real tanpura.
7. Deeper chords and scales.
8. On-device coach notes (Foundation Models on iOS 26 with a template fallback).
9. Platform: configurable widgets, Spotlight entities, TipKit, StandBy, a Watch metronome.
10. Strum to tune: neutral lanes with colour only for status; "≈ estimate" badge.
11. Finish the highway; 12. merchandise the Songs tab; 13. an 11 pt type floor in diagrams.
- Outside: licensed songs ("the biggest perceived-value gap"), filmed instructor demos, an illustrator, real ratings, the privacy URL, a pricing and trial test.

**Wave 10 (2026-10-24 13:18 to 13:24).**
- `afd4349` (teams C, D, F, G, H): one string orientation, the highway finish and a type floor; a live Play hub and the tanpura drone; **on-device coach notes**; configurable widgets, Spotlight, TipKit and StandBy; a clearer Strum to tune; consistent note spelling.
- `55f87c1` (teams A, B): feature-specific paywall heroes, an honest price anchor, the "What's in Pro" table, funnel fixes, listing notes; the song sheet opener, the **Perform finale with a 9:16 share card**, a merchandised Songs tab, a lesson entrance fix.

### 5.15 Round 10 (8.1) and QA10 → waves 11 and 12

**Round 10, `REVIEW10.md`, 8.1** (design director and App Store growth lead).
1. **Make songs full songs.** The 52 songs are 8-bar loops of 10–108 s (median about 28 s), with no lyrics and no video; "Play songs, start to finish" is used for 22-second songs.
2. Real iPad layouts, not stretched phone layouts.
3. A finished song sheet (lead sheet under the song map) and Songs tab (locked tiles say why).
4. The results screen contradicts itself: "Flawless · 98 %" beside a coach note that a change was 200 ms late.
5. **No signature shader moment** (0 Metal effects): add a lock shimmer, a strobe ripple, heat-glow stars.
6. Lesson screens: compact header, bigger diagrams, down and up strokes with a travelling pick.
7. Covers look generated (4 of 7 share one motif).
8. Clean captures (the iPad tuner shows the grey 2D fallback).
9. **A competitive loop**: Game Center leaderboards, a weekly league, a Sunday recap notification.
10. Paywall revenue features: offer codes, a win-back offer, the weekly price.
11. Fade every chip row's edges; 12. a drone dial.
- Outside: licensed songs or commissioned originals with band stems; instructor clips; a 3D soprano ukulele; re-render the grey acoustic card; the privacy URL; pricing; review quotes.

**`QA10.md`**, a code audit at `55f87c1` (1 critical, 4 high, 16 medium):
- **C1:** the screen auto-locks during tuning, play-alongs and song finales (`isIdleTimerDisabled` is never set), and locking stops the microphone; with Low Power Mode 340 timed takes run 25 s or longer.
- **H1:** a listen or quiz step's tone sequence keeps playing into the next step and switches off that step's microphone.
- **H2:** a lesson's click keeps playing in the background indefinitely.
- **H3:** the Next song widget marks a paying user's songs "PRO" after every cold launch (entitlements resolve after the widget is published).
- **H4:** `SparkBurst` redraws at display rate forever on the Play hub and most lesson screens.
- Mediums included: stale tasks reopening the lesson microphone after close; lessons taking over the Metronome tool; every settings change rewriting the whole state file on the main thread (up to ~270 round trips per slider drag); a streak widget that says "Practised today" after midnight; an expired subscription staying Pro until relaunch; a declined Ask to Buy leaving the button disabled; strum minutes counted twice; the paywall not modal for VoiceOver; terms truncated at large text; VoiceOver string numbers on the strum screen differing from the chips; share cards rendered on the main thread during celebrations; the tune tab redrawing at full rate while idle; deep links dropped while a lesson is open; a 30 vs 29 BPM loop mismatch; quadratic lesson-access work; per-frame text layout on the runway.

**Wave 11 (2026-10-24 14:43 to 15:57).**
- 11A (`bad004f`): **all 52 songs became full 1:35–2:58 arrangements** (intro, verses, choruses, bridges, outro) with public-domain or original lyrics; a karaoke lyric line on the highway and Perform; an arrangement API with sections, chords and section practice loops.
- 11B (`78ab844`): **real iPad layouts** (a three-column tuner in landscape; Play, Progress and Learn grids); the stage survives rotation; idle redraws pause.
- 11C (`3a28c13`): a lead sheet with sections, chords, melody and tab; tap a section to loop it slower; locked songs say why and offer a 20 s preview; 16 cover motifs and mesh-gradient backdrops.
- 11D (`9e92165`): **Metal shader moments** (lock shimmer, strobe ripple, heat stars); results and coach agree on flawless runs; status text no longer garbles; CI installs the Metal toolchain.
- 11E (`bdbe8d3`): a compact lesson header, a strum lane with down and up strokes and a travelling pick; stale tone and listen tasks cancelled (QA H1); the burst stops redrawing (H4).
- 11F (`cb9debe`): one shared edge fade for every chip row; a rotary drone dial with detents; equal-height Today rows; settings values on the right.
- 11G (`4d32295`): **Game Center** (quiet sign-in, Sniper boards with a weekly league, ear level, achievements), Beat-my-score links, a Sunday week notification; paywall offer codes, the weekly price, an honest win-back offer; entitlements refresh on foreground and at expiry, Ask to Buy unstuck, a modal paywall, untruncated terms (QA M5, M6, M8, M9).
- QA services (`69d99dc`, `2ec9ffb`): the screen stays awake while playing (C1); lesson clicks restart in phase and stop in the background (H2); widgets wait for entitlements (H3); batched settings writes and a history roll-up (M3); a midnight-correct streak widget (M4); no double-counted strum minutes (M7); VoiceOver string numbers (M10); cached curriculum lookups (M15).

**Wave 12 (16:06 to 16:45), the rest of round 10's item 1.**
- 12A (`4d07cc2`): the song sheet, previews and "Practice this part" run on the real arrangements; `fab7889` the Next song widget reads chords and tempo from them.
- 12B (`d045eda`): **all 53 instrument-course songs end on the whole song** (1:35–2:55: bass root lines, fiddle AABB tunes with kick-offs, banjo roll breaks, violin, cello and mandolin variations, ukulele picked interludes, full sung verses), with shared public-domain tunes and words and stricter build checks.

### 5.16 Round 11 (8.4) → wave 13

**Round 11, `REVIEW11.md`, 8.4.** "A premium, cohesive tuner … As a lessons app it is still a tier below Yousician and Simply Guitar on repertoire, notation and teaching media."
1. **Engraved notation and TAB**: the lead sheet is a strip of letter-labelled bars; every top competitor shows real tab.
2. An animated player's-view neck for chord and explain steps.
3. Real iPad compositions (Learn: path plus a lesson inspector).
4. Songs shelf credibility: "3 chords or fewer" shows Ode to Joy three times.
5. Store-frame pipeline: iPad landscape PNGs come out sideways (EXIF orientation ignored); no 9:41 status bar; frame #8 says "0 lessons" next to a 7-day streak.
6. Labelled tuner controls (an "AUTO | MANUAL" pill, a "Reference" button).
7. A chromatic stage worthy of the 3D ones (a Peterson-style strobe disc).
8. Strum cues that agree with the arrow.
9. Ship the Apple Intelligence coach; stop printing the same insight twice.
10. A Liquid Glass pass (it was used once).
11. A readable song map; 12. a paywall hero that sells the plan; 13. an Apple Watch companion.
- Bugs: **the cents and Hz readouts disagree** (hysteresis holds the cents while Hz tracks the filter); accidentals spelled three ways; the drone wheel runs the wrong way.
- Outside: licensed pop repertoire ("the single biggest gap"), recorded multisampled instruments and backing stems, instructor clips, **"Make violin and cello tuning free"** (people searching "violin tuner" will 1-star a paywalled tuner), a layered Icon Composer icon, the privacy URL, real quotes.

**Wave 13 (2026-10-24 17:50 to 18:25).**
- 13A (`0ee5ff2`): **engraved staff notation and TAB** on song sheets (key-correct spelling, beams, ties, rests, lyrics, chord symbols, Staff/Tab/Both), staffs in bowed and mandolin note steps, a readable song map; notation layout tested over every play-along.
- 13B (`d2ff4d3`): a player's-view perspective neck for chords (fingers land in order, muted and open strings, shimmer with Hear it) with a "Chart \| Player view" flip; the strum stage reads down as down.
- 13C/F/G (`90dce7d`): the iPad Learn path with a lesson inspector and a Play dashboard; a Liquid Glass toolkit on rails, the lesson bar, the paywall plans and CTA; a paywall plan hero with the first song's sleeve; **one ♯/♭ formatter app-wide**; the drone wheel rises clockwise; **an on-device Apple Intelligence coach** (weak-linked, template fallback).
- 13D (`85fa83c`): songs grouped by tune with version badges; store frames upright with checked sizes and 9:41 status bars; demo lessons consistent with the streak.
- 13E (`2d288e0`): a labelled "AUTO \| MANUAL" glass pill and Reference button; the Peterson-style strobe disc with note wheel and needle arc; **cents and Hz always agree**.
- 13H (`6737442`): an **Apple Watch companion** (a haptic metronome on the Digital Crown, a Today ring with streak and set, Start on iPhone through Handoff, complications) over WatchConnectivity.

### 5.17 DESIGN11 audit → wave 14

**`DESIGN11.md`** (design-system and accessibility audit, written 10-24 18:34, 37 ranked findings in batches A–F with an API contract so six teams could work in parallel).
- **Drift by count:** 158 `.font(.system(size:))`; 91 `Typeface.display()` calls of which only 11 pass `relativeTo:`; 21 display sizes; 120 `Color(hex:)` outside Design; card radii 14–30; screen gutters 20–30; 30 ad-hoc springs and ~70 ad-hoc eases; `ScreenTitle` never used; 7 close-button builds and 3 primary-button builds.
- **P1 findings:**
  1. the type tokens scale against the wrong text style, so at accessibility sizes headings end up smaller than body text;
  2. hubs and results keep phone layouts at accessibility sizes and clip;
  3. header controls are 36 pt targets and the "LV" caption is 6.8 pt;
  4. Increase Contrast is ignored outside the tuner, and control boundaries measure 1.24:1;
  5. disabled buttons look tappable;
  6. two primary-button systems with different shape, font and height;
  7. "Listen" means opposite things (the app plays vs. the microphone listens).
- P2/P3: tab headers disagree; section headers come in 4 sizes; step titles jump; seven close buttons; chips at 38 pt with three selected looks; the radius scale ignored; eyebrows hand-built; one-off colours; Pro and progress locks look the same; fractions written three ways; "Ear trainer" vs "Ear training"; Pro naming drift; one feature with four names (Today / daily set / daily quest / Today's quests).

**Wave 14 (2026-10-24 18:36 to 19:08).**
- 14A (`b7a9ef5`): the design foundation: Dynamic Type roles that keep headings above body; Increase Contrast tokens; **one primary/secondary button system with real disabled states**; 44 pt targets; a shared Kit (close button, section heading, eyebrow, stat tiles, empty and loading states, a scalable Pro badge); radius, spacing, hairline and motion tokens.
- 14B–F (`d8ca0e9`): the system applied app-wide: tab headers, section headings, step titles, buttons, close and back buttons, chips and segmented pills at 44 pt, stat tiles, eyebrows, hairlines, tokens, Increase Contrast and Reduce Motion handling, accessibility-size layouts, consistent fractions and copy.

### 5.18 Interlude: owner decisions on free tuning, licensing and repertoire

**2026-10-24 19:51 to 21:55, 8 commits.**
- `7e32f2f`: **violin and cello tuning are free** (5 of 60 instruments), as the owner asked and round 11 advised; the **song licensing playbook** for the owner (`docs/content/SONG-LICENSING-PLAYBOOK.md`; section 6.4); work in progress on "Your Songs" (import your own chord charts) and new repertoire.
- `ae5cc56`: explain steps stop their demo the moment Continue is tapped, so a late demo note can't stop the next step's microphone (a UI-test regression).
- `337aed9`: **30 new contemporary Originals** (pop anthems, folk, country, reggae, funk, punk and rock riffs, ballads, barre-chord songs) in six new Originals units, all full arrangements with lyrics. That made 50 Originals.
- `bc275e3`: **Standards & Classics**: 18 worldwide-public-domain songs (Joplin, Sousa, Strauss, Bizet, Grieg, Scottish, Irish and Welsh traditionals, carols) as full arrangements, with a per-song rights table (`docs/content/PUBLIC-DOMAIN-CLEARANCE.md`). `40c7c5a`: the listing no longer says every song has words.
- `27ce76f`: the sound department's sampled instruments, in progress.

### 5.19 Round 12 (8.4) → wave 15

**Round 12, `REVIEW12.md`, 8.4** ("independent, strict"). It loses the 9.5 bar "on content and sound (unknown songs, a synthesized band) and on a few visible rough edges, one of them on the money screen".
1. **Ship the recorded band and instruments.** The sample manifest lists only guitar; 70 piano and 26 bass files ship unreferenced; there is no drum kit, so "Preview with band" is a sine-drop kick, a noise snare and a detuned pad.
2. **The paywall's yearly card is broken**: "Year-/ly" wraps and the "14 DAYS FREE" tag is cut in half by the glass group.
3. **One string orientation**, with Chart as the default: one lesson showed four neck layouts.
4. The Songs tab's catalogue starts below the fold.
5. Store set: Strum to tune, the feature GuitarTuna can't match, isn't in it; streaks of 7 and 8 and two flame colours across captures; captures mid-animation.
6. The voice rail clips its first card.
7. **A false onboarding promise**: "You skip Units 1–6. They stay open for a refresher" is untrue on the free plan.
8. 10–11 pt captions below 4.5:1; the header ring is a bare "5".
9. Text reads through the floating tab bar.
10. Spaced review is still a TODO.
11. No social layer beyond leaderboards; 12. the iPad tuner's right half empty; 13. ear training plain; 14. cover grid inconsistent.
- Outside: license recognisable songs (playbook stage 1); human teaching; **pricing: $34.99 a year and $89.99 lifetime are well under the $90–180 lesson apps charge; test $49.99–59.99 with a 7-day trial, lifetime at $149 or drop it**; host privacy on a custom domain; social proof.

**Wave 15 (2026-10-24 22:07 to 23:01).**
- 15A (`890ece3`): plan names never break; the free-trial tag drawn above the glass; a quieter lifetime card; accessibility-size paywall and win-back layouts.
- 15B (`497effa`): **one neck-view setting** (Chart default, Player view opt-in) drives every chord picture, neck, strum stage and Settings.
- 15D (`345909a`): Strum to tune joins the store set; **one consistent seed for every capture** (7-day streak, lit flame, level 5); captures wait for the screen to settle; the listing's age-rating answers; a privacy-URL TODO.
- 15E (`485180a`): no clipped rail selections; honest onboarding skip copy per plan; 12–13 pt informative captions; an "LV" label; a soft scroll edge under the tab bar.
- `e32dbf9` "Wave 15 complete": **real sampled instruments** (piano, bass, drums, guitar, violin, cello, harp, winds; about 10 MB of CC0 recordings, lazy-loaded) for Hear it and the band; **spaced review (SM-2)** in Today; **Game Center challenges, song leaderboards and friend streaks**; the Songs tab above the fold with a consistent cover grid; an iPad tuner side pane; richer ear training; runway lanes agree with the chord pictures.
- `820edf8` **keep the 4+ age rating**: "Drunken Sailor" replaced by "Bobby Shafto"; "Good King Wenceslas" sung without the wine verse; the peace verse of "Down by the Riverside"; six original lyric tweaks; the pitch game renamed from Pitch Sniper to **Bullseye** (badges "High Scorer", "Round Winner") so nothing borrows shooting words; the listing's age-rating answers.

### 5.20 Round 13 (8.7) → wave 16

**Round 13, `REVIEW13.md`, 8.7.** "An Apple Design Award juror would shortlist it, and an editor would hesitate over the frames below." Three things for 9.5: clean hero frames, teaching that is *shown*, an adult-first catalogue.
1. **A clean store set**: store #1 (10b) shows a "✓ In tune · 0¢" badge and an "In tune" status line together; #6 (results) has its ring cut flat; #2 sells "0 0 0" open strings; iPad #2 is a sheet over the live tuner.
2. **Adult-first Songs shelves**: "3 chords or fewer" opens on Mary Had a Little Lamb, Twinkle, Old MacDonald and Yankee Doodle.
3. The onboarding paywall sells with one outcome line and a ~90 pt sleeve; it needs a drifting rail of the plan's sleeves and a proof line.
4. Placement framed as a gain, not a lock one screen before the paywall.
5. **"Show me" demonstrations** using the shipped USDZ neck rigs: fingertips landing on the 3D fretboard, a pick sweeping. "The closest code-only answer to the teacher video in Fender Play and Simply Guitar."
6. The down-strum pick travels up the screen in Chart view.
7. iPad tuner composition; 8. iPad Play tools as live previews; 9. drone and ear training look alive.
10. **Stars that mean something**: a 50 % "Keep going" play-along still ends in three stars.
11. One sunset motif on three heroes; 12. "— · 196.00 Hz" reads as a glitch; 13. copy; 14. Today's plan reshuffles when the instrument changes.
- Outside: multi-velocity recordings (flat-top guitar with strums, ukulele, mandolin, banjo); produced stems for the 50 Originals; hand art or teacher video for Unit 1; a hosted privacy URL; a pricing test (lifetime at 2.6× yearly risks cannibalising it); pre-launch social proof.

**Wave 16 (2026-10-25 00:18 to 03:27).** Most commits were WIP snapshots of teams; the visible results:
- `6e1b0d7`: the strum stage always in Player view; the tune check reads "Tune up" without borrowing a step number.
- `7fe1e18`: the Today plan pinned for the day.
- `a07a279`: **adult-first Songs shelves** with a "Campfire & kids" shelf; 24 sleeve motifs split between Originals and the rest; a "Timbre Originals" credit.
- `f5b6406`: the final play-along gates the stars (the coach agrees); the results burst never clipped; a *Kite Weather* Perform scene for store #2; a full-page iPad instrument browser.
- `2ca73a6`: the onboarding paywall with a drifting rail of the plan's songs, a live catalogue proof line and three outcomes; placement reads as a skip ahead.
- `4c94e78`: live mini previews on Play tool tiles; the drone breathes and auto-listens; ear-training notes rise behind a veil.
- `51e9381` **Show me**: chords, notes and strums demonstrated on the 3D neck (equal-temperament frets computed from the rig, fingertips in order, strings ring, the pick sweeps), a shared model cache, a 2D fallback; `dbd59b0`: Show me on strum steps before the take; the Chords tool remembers the last chord.
- `3d7e0ce`: a **sampled Martin flat-top guitar** with strum feel; ukulele and mandolin stand-ins; a band electric guitar and fuller kit; genre-aware grooves for the Originals.
- `1e924f4`: **song collections are a library**: every free Originals, Standards and Songs track opens without finishing the one before.
- Store-capture reliability: `21f719c`, `3b0e47c` (test10 timing), `80e88f9` (start the clock a bar early), `5d2a9f8` (judge demo notes at their due time, not when a stalled simulator frame reaches them).
- `987fa50`: **guitar units 17–22** (CAGED, triads, seventh and jazz voicings, the major scale in position, expressive lead, song form and arranging) and **ukulele units 7–10**: 617 lessons, 159 songs; `12f93c1`: pro ukulele players start at Unit 7.

### 5.21 Round 14 (8.9) → wave 17

**Round 14, `REVIEW14.md`, 8.9**, the highest single-reviewer score. "The team closed every item from review 13, and I checked each one." Four things keep it short of "Apps We Love":
1. **New defects in the two highest-value store frames**: #2 catches the score mid-roll ("27,?00"), a 40 pt sleeve prints "ORIGI…", the playhead cuts through "Cho|rus"; #6 has a half-hidden Share pill; iPad #2 ends mid-row and doesn't match its caption; every iPad frame shows the iPadOS window-resize arc. And "Show me", the most cinematic feature, is never captured.
2. **Localization drift**: 989 of 5,610 lesson strings and about 390 UI strings missing in every language; the new welcome subtitle and "Cancel in 2 taps" missing.
3. The paywall rail's sleeve titles collide with the headline, and it leads with Clementine.
4. **One guitar**: the rendered cards show a grey, untextured headstock; the live stage shows dark wood.
5. **Ukulele parity**: no turn arrow (photo stages carry no turn sign), no Show me, no real audio.
6. Make Show me auto-play the first time a chord appears.
7. Bowed instruments: the control says "Strum"; **the violin and cello peg mapping looks inverted** (outer strings should take the pegs nearest the nut).
8. Lesson titles disagree between outline and player; 9. iPad finish; 10. small polish; 11. guitar depth: song-led units, not more theory.
- Outside: song licensing (20–30 tracks through a partner), recordings, teaching media, ukulele and banjo 3D models, a hosted privacy policy, **the analytics ID** ("without funnel data nobody can tune the paywall"), human review of the 9 lesson languages, a pricing test, a violinist to confirm the pegs.

**Wave 17 (2026-10-25 04:32 to 04:57, plus CI follow-ups to 07:13).**
- `ea6c80e`: the Play hub shows each task once; app-style segmented controls on ear training, drone, scales and metronome.
- `a249514`: **Show me plays by itself** the first time a chord or strum appears in a course; one step title in outline and player.
- `544c576`: the paywall rail leads with three Originals; untitled sleeves never meet the headline; one icon language; reason paywalls sell their reason on day 2.
- `d6e012c`: iPad full-screen captures (no resize arc); the browser frame on the folk-strings shelf; Learn rail fade; a Play level tile with the week and the next badge.
- `44e699b`: **instrument cards re-rendered under the live stage's lights and image-based lighting** ("one guitar everywhere"); a Show me store frame; results above the fold; a still score in the store scene; motif-only small sleeves.
- `66243fa`: a **Song spotlight in every guitar unit 2–22**, each a different Timbre Original practising the unit's skill: 638 lessons, guitar 153.
- `c0ae634`: the **translator handoff**: per-locale TODO files with context and length hints, stale-key tracking, report and import tooling, a warning-only CI summary (`docs/l10n/HANDOFF.md`).
- `6545599` "Wave 17 complete": violin, viola and cello pegs wound as on a real pegbox (outer strings nearest the nut); **turn signs for 37 photographed instruments**; "Pluck all" on bowed instruments; "Tighten"/"Loosen" alone; chromatic and iPad landscape framing; `69a0341` violin and cello cards re-rendered.
- CI follow-ups: the iPad job proves an app launches in Full Screen Apps mode first (`8292c76`) and gets a 45-minute budget (`5111d1f`); Show me warms up behind the picture (`98c208f`); lute and glockenspiel photos cut out of black backdrops (`5f9b699`); the iPad browser frame scrolls in the interface's orientation (`7c8d46c`).

### 5.22 Jury round 15 (7.7) → wave 18

**Jury round 15** (`JURY15-*.md`, foreman `REVIEW15.md`, at HEAD `7c8d46c`). Visual 8.6, Delight 8.3, Inclusivity 8.3, Technical 8.1, Growth 7.4, Category 7.8; overall **7.7**. "An excellent engine wearing a component-library suit and sold by a silent ad."

**Blockers (verified by the foreman):**

| # | Blocker | Evidence |
|---|---|---|
| B1 | Fresh installs ignore the device language: all 49 locales invisible until Settings › Language | `LocalStore.swift:10` sets `language = "en"`; UI tests pin `-AppleLanguages (en)`, so CI was blind to it |
| B2 | One decode or validation failure bricks the app and the streak is lost | strict validation throws; the launch Retry fails forever |
| B3 | Tuner haptics very likely muted while the microphone listens | no `setAllowHapticsAndSystemSoundsDuringRecording` anywhere |
| B4 | Strum and progression steps grade timing only; open strings or a wrong chord earn "Flawless" | `LessonSteps.swift:1509` (`chords: false`) |
| B5 | Nothing measured: no analytics ID; the onboarding paywall's impression never logged | `Analytics.swift:32-35` |
| B6 | The App Preview is silent, never shows a lock, its poster is a double exposure, it ends on 9.6 s of a still Songs tab | `preview.py:509` (`anullsrc`) |
| B7 | Store #2 shows a ghosted combo digit ("74") | `HighwayHUD.swift:37`, `:67` |
| B8 | A blind learner can tune but cannot learn: the play-along is one opaque element; focus never moves | `Highway.swift:145-146` |
| B9 | Pro revoked during Billing Grace Period | `Access.swift:28-29` requires `expiresAt > now` |
| B10 | The paywall's renewal terms are English in 48 storefronts | 474 UI keys missing in all locales |
| B11 | The iPad CI is red; iPad store frame #2 has no valid capture | `TabletScreenshotsUITests.swift:110` |

**Consensus majors:** no songs the buyer knows and an inflated count ("159 songs" counted song lessons; 124 distinct titles); a store screenshot set that is one template applied nine times; "Show me" with dots and no hand; a cosmetic left-handed setting; localization broken end to end; rewards as category templates (`star.fill` stars, a Duolingo-style flame, one burst everywhere, "Great work" at six peaks); "template/AI" visual tells (20 `IconOrb(`, 236 `Capsule()`, 53 eyebrows, 31 Sora sizes, a mint glow on every primary button); **"vibe-coded" engineering tells** (14 "review N / bug N" comments, scratch files at the root, 232 of 233 commits by one author, 50 WIP or `[skip ci]` commits, 0 `#Preview`, no lint, Swift 5 mode, 16 app unit tests); the free tier cut in the wrong places; no real-audio evidence; a thin band; no accessibility verification; string order flips; pricing; idle battery cost.

**Roadmap:** ten file-disjoint work packages (`REVIEW15.md` §3), ranked: WP1 trust foundation and core hardening; WP2 funnel, first session, paywall and measurement; WP3 store creative and listing; WP4 listening that tells the truth; WP5 catalogue, content and free tier; WP6 play-along, band and an accessible highway; WP7 tuner feel, rewards and sound identity; WP8 design system and app shell; WP9 necks, hands and the 3D stage, left-handed everywhere; WP10 vibe-coded cleanup and engineering hygiene.

**Wave 18 (2026-10-25 07:56 to 09:45, follow-ups to 12:53).** Teams worked in the shared tree; the orchestrator snapshotted their edits as "WIP wave 18: in-progress team edits [skip ci]" and then landed one commit per package:
- WP1b (`f091a6a`): one audio-session owner; **haptics allowed while recording** (B3); recovery from route and configuration changes and interruptions; `CurriculumStore` decoded off the main thread; a cached streak; a side-effect-free `dailySet`; a per-frame tuner hook.
- WP10 day 1 (`0785642`): agent scratch files and stale self-audits removed; a CI gate against review/bug/WIP references in code (its baseline may only shrink); SwiftLint and SwiftFormat config; a **critical-string localization check that blocks delivery**; String Catalog groundwork; Info.plist keys for links and remote config; accessibility audit UI tests.
- WP1a (`a55e2e6`): lenient settings decoding with the new shared fields; **crash-proof state** (backup, quarantine, clamped repair, a recovery notice) (B2); **the phone's language by default** with one cached localization bundle (B1); **Pro kept in Billing Grace with a billing-issue banner** (B9); **every instrument's standard tuning free**; StoreKit and localization launch tests.
- WP8 (`a4f5d0e`): a design-system pass: an 8-step type scale, Bold Text in Sora, status colours only for status, mint flat primary buttons, bare and custom glyphs instead of tinted-circle icons, section-level capitals, matched tab symbols ("Play" renamed "Practice"), the billing banner mounted, Settings rows for handedness and feel, Large Content Viewer and Smart Invert exemptions.
- WP2 and WP7 (`391778f`): the **analytics funnel and remote config**; the **first chord before the paywall**; a two-plan onboarding paywall with an honest song count and share links; **Tune by feel**; the instrument's own strings at the finale; stars ringing in key; harmonic bursts; spoken note names.
- WP6 (`989f493`): a shared play-along session with chord-aware grading; a band that follows the song's chart and the player; **a VoiceOver play-along with spoken next notes and cues** (B8); a "Chords & words" mode; colour-blind-safe lanes; still HUD digits in the store scene (B7).
- WP9 (`d47eff0`): **left-handed everywhere** (mirrored chord boxes, necks, lanes, Show me and the 3D stage, with words unmirrored) and an **upside-down mode**; the capo drawn; a clean Show me string glow; 3D rest and Low Power fallbacks; the celebration roll lights the 3D strings.
- WP4 (`ea9f65b`): **strum and progression steps check each stroke's chord** (B4); the chord step names the string that isn't ringing; banjo D7 fixed; a spoken tune check; VoiceOver focus on each step; pedal and keyboard control; a lesson Siri shortcut; a real-recording test harness.
- Integration (`2d8f726`): a usage-sharing switch applied before analytics starts (an opt-out also stops the Apple Ads attribution request); friend offers and share links; a sound motif on welcome and Pro unlock; hygiene baseline 272 → 155.
- WP3 (`85968e5`): the App Preview cut on the beat with the app's own sound, captions and an end card (B6, in part); **art-directed store screenshots** (one composition per frame, a violin page, localized rendering); new store scenes; listing copy, Custom Product Page tables and delivery docs; a robust iPad browser frame (B11).
- WP5 (`9c749fe`, "Wave 18 complete"): catalogue and free tier: **songbooks for ukulele, mandolin and violin**, 20 more public-domain standards, **132 tunings**, **free open chords, capo, eighths and triplets, one custom tuning and ten charts**, Bullseye without shooting language; **honest counts everywhere** (518 teaching lessons in 11 courses, "140+ songs" by title); chord practice free in Today.
- Follow-ups: `7b80620` (a compile fix), `543192c` (lesson buttons carry their own identifiers), `e74c390` (CI app job to 90 minutes: "the UI flows passed and the archive ran out at 60"), `eb6ee5c` (**note names keep their octave on the right in right-to-left languages; Arabic showed "₂E"**), `536b9c2` (ignore local agent worktrees, ahead of wave 19).

Process debt the jury recorded: since `7c8d46c`, 26 commits, all authored "Claude", 22 `[skip ci]`, 12 "WIP wave 18"; PR #2 had 0 reviews (`REVIEW16.md` §2b).

### 5.23 Jury round 16 (8.3) → wave 19

**Jury round 16** (`JURY16-*.md`, foreman `REVIEW16.md`, at HEAD `eb6ee5c`). Visual 8.8, Delight 8.7, Inclusivity 8.7, Technical 8.5, Growth 8.1, Category 8.3; overall **8.3**. Of round 15's 11 blockers, 8 were fixed or fixed in code, 1 mostly fixed (B8), 1 not fixed in substance (B6, the preview) and 1 worse (B10, renewal terms untranslated). Repo hygiene items were done: no scratch files, 0 review/bug comments, 0 `IconOrb(`.

**Why it was not higher** (`REVIEW16.md` §1): the wave raised every score but moved no angle to a clean #1, and opened new seams:
- a fake Dynamic Island drew "+5 XP" under the system clock on the first tuner screen and on the ukulele page's lead frame;
- the lock flickered off after about 130 ms, so store #1 and the preview poster read "Hold it…";
- correct ukulele chunks and mandolin chops graded as misses; songs dropped half-bar chord changes in 216 of 419 arrangements; the ukulele songbook played Mozart in C minor; the violin play-along taught guitar fret numbers;
- the paywall's Free/Pro table contradicted the free tier; the price test and the free-tier test couldn't run; a monthly trial the docs asked for would go undisclosed; the beginner's paywall could never promise the first song;
- it couldn't ship: the legal, permission and VoiceOver gate failed in all 48 non-English locales, and no green end-to-end run existed for the wave.

**The new blockers (B1–B11)** are listed with their wave-19 outcome in section 7.7. The full wave is in [section 7](#7-wave-19-in-detail).

### 5.24 Round 17 (convened)

`JURY17_BRIEF.md` (10-25 15:37) convenes round 17 on the same six angles and calibration. It points the jurors at `REVIEW16.md`, the six `JURY16-*.md` verdicts and `INTEGRATION19.md`, and for the first time at the CI result branches (`ci-results/gate`, `ci-results/accessibility`, `ci-results/app`) so they can check the gate themselves. "Do not trust them or the team: verify every claim yourself (what was fixed, what wasn't, what got worse, what is half-wired)." No round-17 verdict existed when this history was written.

---

## 6. Major product decisions and why

### 6.1 Subscriptions, no ads, no account

- **What.** The Android app was a free tuner with interstitial ads and a one-time unlock ("Plus"). The port kept the ad policy only as an optional overlay with no SDK linked by default (`328b7d3`). About an hour later the iOS version removed advertising code (`3e8baa2`) and moved to a **Timbre Pro subscription** (yearly with a 14-day free trial, monthly) plus a **lifetime** purchase that keeps the old `timbre_plus_lifetime` identifier so earlier buyers keep Pro (`d7df85f`; `docs/ios/APPLE-DELIVERY.md` §2). There is no account: progress is stored on the device; Game Center is optional.
- **Why.** The $10k-a-month goal needs recurring revenue, and a lessons product sells on subscriptions. "No ads, no account" became the listing's lead ("Free tuner, no ads, no account", `docs/ios/APP-STORE-LISTING.md`) because it is the one trust claim no funded competitor can make. Both juries made it an explicit rule: "Don't add ads or mandatory accounts … Use iCloud sync instead of accounts" (`REVIEW15.md` §5). iCloud sync was proposed in rounds 15–16 and is not done yet (section 9).

### 6.2 The free tier

How the free plan grew, and why at each step:

| When | Commit | What became free | Why |
|---|---|---|---|
| Port | `328b7d3` | Guitar, bass and ukulele (the Android catalogue's `isFree` instruments) | Inherited |
| Phase 1 | `3e8baa2` | Every preset tuning of a free instrument | Not stated in the commit; the later juries argued the same point ("best free tuner") |
| Wave 5 | `2ab038b` | A free user who picks a Pro instrument tunes it in Chromatic with that instrument's targets | Round 4: free users silently landed on the guitar |
| Wave 7 | `9a46c7a` | The **placement pass**: the first lesson of the unit onboarding places you in | Round 6: the plan named a lesson the free plan couldn't open |
| Interlude | `7e32f2f` | **Violin and cello tuning** (5 of 60 instruments free) | The owner's instruction; round 11: violin searchers "will 1-star a paywalled tuner" |
| Wave 16 | `1e924f4` | Free Originals, Standards and Songs tracks open in any order | Song collections are a library, not a course |
| Wave 18 | `a55e2e6` | **Every instrument's standard tuning** | Jury 15 (growth, category): the instrument pages bring installs; they must turn into 5★ ratings |
| Wave 18 | `9c749fe` | Open-position chords with Check, capo and transpose, eighths and triplets, the click and wood sounds, one custom tuning, ten "Your songs" charts | Jury 15 (category): "the free tier gives away less than the free tuners" (Fender Tune is free with 26 tunings, chords and scales) |
| Wave 19 | `c46c452` | A **free arranged song at the end of every instrument course's unit 1** | Jury 16 (growth): the beginner's paywall could never promise "Play your first song this week" |
| Wave 19 | `0d0f4b0` | Remote levers: `freeSongs` (a seasonal shelf's first week) and `unit2Free` (an A/B test of a longer runway) | Jury 16: both levers were documented but dead |

What stays Pro (`FreeTier.swift`): the drone, scales, intonation, the strobe at Pro precision, temperaments, naming intervals and chords by ear, sixteenths, accents and the speed trainer, alternate and custom tunings beyond the free instruments and the one free custom tuning, and every lesson past a course's first unit (plus the placement pass and the first song). The paywall's Free/Pro table is generated from these rules (`PlanComparison`, `0d0f4b0`) so it can't promise more or less than the app gives.

### 6.3 Pricing and the $10k-a-month model

- **The build's test prices** (`Timbre.storekit`): $34.99 a year with a 14-day trial, $6.99 a month, $89.99 lifetime.
- **The recommendation** (now in `docs/ios/APPLE-DELIVERY.md` §2). Round 12 first suggested testing $49.99–59.99 a year with a 7-day trial and lifetime at $149 or none; the round-15 growth juror argued, with conversion data, for keeping the 14-day trial, and both foremen adopted that: **$49.99 a year with the 14-day trial**, **$9.99 a month with no introductory offer** (until the paywall discloses a monthly trial, which wave 19 made possible), **$149.99 lifetime kept off the onboarding paywall**, Family Sharing on the yearly plan and lifetime, the Small Business Program, Billing Grace Period on (only after the entitlement fix, which shipped in wave 18). Then test $49.99 against $59.99 with the `timbre_pro_annual_b`/`_c` arms (wired in wave 19, `0d0f4b0`).
- **Why these numbers** (`JURY15-growth.md` §4, `JURY16-growth.md` §4): about $0.80 of each list dollar reaches the developer, so $10k net is about $12.5k gross. At today's prices a buyer is worth about $31.55 in year 1, needing about 317 new buyers and 12,200 installs a month at a 2.6 % install-to-paid rate; at the recommended prices a buyer is worth about $43.67, needing about 229 buyers and 8,800 installs a month (about 295 a day). Education's median yearly price is $44.99, and Yousician, Simply Guitar and Fender Play charge $119.99–$199.99 a year, so $49.99 is still about a third of them. **Keep the 14-day trial**: yearly trials of 10–16 days convert at about 43 % against 33 % for 5–9 days. Lifetime at 2.6× the yearly price cannibalises the yearly plan.
- **The growth juror's odds** (round 16): as shipped with the owner's levers unpulled, about 10–15 % chance of $10k net a month within 12 months; with the prices, analytics, the violin, cello and ukulele Custom Product Pages and the team's fixes, about 35–45 % in 12–18 months; with a licensed starter pack of 20–30 songs, above 50 %.
- **Ethics that stay**: an honest trial timeline (the day of the reminder, the day of the charge), an exit offer that uses only real App Store offers, "Continue with the free tuner", no fake social proof (a rating line only at ≥ 4.6★ from ≥ 200 ratings), no struck-through "was" price in the EU and UK (wave 19 shows "12 × $6.99" instead).

### 6.4 Songs: public domain, Originals and songbooks instead of licensed hits

- **The problem.** From round 7 on, nearly every review named "songs people know" as the largest gap against Yousician, Simply Guitar, Fender Play, JustinGuitar and GuitarTuna (GuitarTuna lists 20,000+ songs; Timbre has 0 licensed).
- **Why not license now** (`docs/content/SONG-LICENSING-PLAYBOOK.md`, `7e32f2f`): an interactive highway, chord lane or timed lyric needs direct publisher grants per song and per co-owner share (print, arrangement, lyric display and sync rights; *Leadsinger v. BMG* treated karaoke as audiovisual), not a collective licence; Apple Music content can't be synced to a highway or analysed (MusicKit gives no buffers and forbids synchronisation and paywalling); majors want advances of about $10k–$50k+ per publisher with MFN and audits. The playbook stages it: Stage 0 now (public domain, Originals, user import), Stage 1 emerging artists who own their songs, Stage 2 independent publishers, Stage 3 majors and aggregators at about $50k MRR or after funding. Budget rule: content cost at or below about 15 % of net revenue until licensed songs prove they lift conversion. The jurors' recommendation for the owner is a starter pack of 20–30 recognisable songs (about $15–60k in advances plus revenue share), starting with the songs teachers use in month one.
- **The workaround that shipped:**
  - **Public-domain songs** cleared worldwide: first published before 1931 (US public domain as of 2026) **and** every creator dead before 1956 (life + 70), or traditional; only the original melody and original public-domain words, with every arrangement Timbre's own (`docs/content/PUBLIC-DOMAIN-CLEARANCE.md`). Songs part 1 and 2 (`5fe65c5`, `79dbba2`), Standards & Classics (`bc275e3`), 20 more standards (`9c749fe`). Doubtful songs were declined (Swing Low, Home on the Range, Wayfaring Stranger, Hava Nagila, per the round-16 category juror's reading of the clearance doc). "Happy Birthday" was proposed for 1 January 2027 at the earliest (`JURY15-category.md`), and only after the clearance doc and a legal check agree (`REVIEW15.md` §5).
  - **Timbre Originals**, house-written songs in contemporary styles: 20 (`1983645`), then 30 more (`337aed9`), 50 in all; a Song spotlight in every guitar unit 2–22 uses one (`66243fa`). The playbook asks for signed work-for-hire paperwork and dated records of human edits.
  - **Full arrangements**, not loops: 1:35–2:58 with intro, verses, choruses and outro, lyrics, notation and TAB (`bad004f`, `d045eda`, `0ee5ff2`).
  - **Songbooks per instrument**: every chord song re-keyed and re-fretted for ukulele, mandolin and violin (`9c749fe`), then cello and bass (`c46c452`), with key and spelling rules fixed after the round-16 category juror found the ukulele *Rondo alla Turca* in C minor (`c46c452`, `editions.py`).
  - **"Songs you know" first**: Ode to Joy, Amazing Grace, Silent Night lead the Songs tab and Song of the Day until three are played; a December carol shelf; a "Request a song" button that logs demand for future publisher talks (`c46c452`).
  - **Your songs**: players paste or import their own chord charts, which stay on the device (no bundled charts, no scraping, no public gallery, per the playbook), and play them as a "Chords & words" take (`f824a90`).
- **Content rules:** the **4+ age rating** (`820edf8`): no alcohol, weapon or violence references in titles or lyrics ("Drunken Sailor" replaced by "Bobby Shafto", Wenceslas without wine, "sword and shield" left out of Down by the Riverside), and the pitch game renamed from "Pitch Sniper" to "Bullseye". The *Kite Weather* sleeve, which the jury found imitated Joy Division's *Unknown Pleasures*, lost its ridge-line motif in wave 19 (`c46c452`); a new commissioned cover is the owner's.

### 6.5 The 3D stage and the Blender pipeline

- **What.** The tuner's hero is a studio-lit 3D headstock whose peg turns with the measured error and whose string stands still at the lock (`b66f0a6`; a Metal comet on lock from `9e92165`).
- **How it evolved.**
  1. Procedural models built from code in headless Blender on CI (`be17ba8`); 35 were installed in phase 1 (section 5.2).
  2. Replaced about six hours later (`463b9f2`) by artist models for the guitars and the 2D photo stage for everything else; the commit records the swap, not a reason. About an hour later **seven CC-BY artist models** (acoustic, classical and electric guitar, P-bass, mandolin, violin, cello) arrived, rigged, relit and rendered for Timbre (`b0f5ee2`) and credited in Settings › Acknowledgements. Every other instrument stands on its photograph with per-string anchors (`photo-rigs.json`) and, since wave 17, turn signs (`photo-turns.json`, 37 instruments).
  3. The studio cards are re-rendered on a macOS runner under the live stage's own lights and image-based lighting, so the guitar looks the same on every screen (`44e699b`; the "Render instrument cards" workflow, `cards.yml`). The Blender LTS pipeline still runs in `assets.yml`.
  4. Correctness passes: the violin-as-mandolin load race (`aae487c`); violin, viola and cello pegs wound as on a real pegbox (`6545599`, `69a0341`); whole heads in every close-up (`4d826e2`).
  5. The same rigs drive **Show me**, which demonstrates chords, notes and strums on the 3D neck (`51e9381`). A hand rig hook exists with no rig yet; ukulele and banjo have no 3D model (owner items).
- **Why.** Every review scored the tuner stage as the app's strongest asset ("Tuner 9.4"; "two screens that would get onto an ADA longlist", `JURY15-visual.md`). Rest and Low Power modes hand the stage to a still picture to save battery (`d47eff0`).

### 6.6 Recorded sound: CC0 samples

- **What** (`docs/content/AUDIO-SOURCES.md`): 11.4 MB in 300 files (budget 35 MB) from CC0 libraries pinned to commits: VCSL (piano, harp, marimba), a Martin HD-28 steel-string guitar, FreePats classical guitar, Growlybass, Karoryfer's Gretsch electric guitar, Virtuosity Drums and VSCO 2 CE (violin, cello, winds). Lazy-loaded, pitch-shifted to the exact frequency, and tested so a sampled A4 reads 440 Hz on the app's own tuner.
- **Why.** Round 6 said "Hear it" sounded like an organ (wave 7 answered with Karplus–Strong voices); round 12 said the band was synthesized and that real recordings were "the" sound gap (`REVIEW12.md` item 1). Only CC0 (preferred) or CC-BY material may ship; anything share-alike, non-commercial, GPL or of unclear provenance is rejected, and `verify-ios-resources.py` checks the manifest on every run. Shipped in `e32dbf9` (wave 15) and `3d7e0ce` (the Martin flat-top with strum feel).
- **Known stand-ins** (owner items): no usable CC0 ukulele, mandolin or banjo was found, so the ukulele plays classical-guitar notes, the mandolin plays the Martin thinned and doubled, the banjo and the sung voice stay synthesized, and the cello is a section rather than a soloist.

### 6.7 Design language: "Still Point" → "Studio Noir" → a design system

- **"Still Point"** (`b66f0a6`): Liquid Glass panels and brass controls. Replaced about four hours later.
- **"Studio Noir"** (`de06563`): a near-black stage, mint for in tune and primary actions, amber/gold for cues and rewards, Sora display type. The look is an instrument on a dark stage under a warm spotlight. Every agent works to it (`PREAMBLE.md`).
- **The design system** (`DESIGN11.md` → wave 14 `b7a9ef5`/`d8ca0e9`; jury 15 → WP8 `a4f5d0e`; jury 16 → WP9 `b2af55a`): one type scale (8 steps), adaptive contrast tokens, one primary/secondary button system, 44 pt targets, one icon language of bare custom glyphs instead of SF symbols in tinted circles, status colours (mint, amber, coral) reserved for status and named roles for everything else (`accentNeutral`, `starGold`), a docked reward toast that never enters the status bar, one streak metaphor (a stage lamp instead of a flame), and lint rules that hold the code to them.
- **Why.** The owner's "never vibe-coded" bar; the jury's visual juror counted the template tells (`IconOrb`, capsules, eyebrows, glows) and every visual deduction in round 16 was "for too many of them, or for the wrong colour" (`REVIEW16.md` §5).

### 6.8 Calm mode and Simple tuner

- **What.** Calm mode hides the game layer: the header's streak chip and level ring, XP, level, quest and streak toasts, the results' XP and streak tiles, Today's bonus, quest XP, Progress's streak and level, the coach's streak nudge and the milestone celebration (`b2af55a`). Simple tuner hides the quest line, XP and header chips on the tuner (wave 18).
- **Why.** The inclusivity juror named cognitive load for kids, anxious learners and older beginners as an under-served group (`JURY15-inclusivity.md` item 10). The setting arrived in wave 18 (`a55e2e6`, rows in `a4f5d0e`); round 16 found it "shallow" (it hid XP pills in three places and its footer overpromised), so wave 19 made it real.

### 6.9 Left-handed mode

- **What.** A handedness setting existed from the Android port but only reordered the tuner's chips and strum meters. Wave 18 (`d47eff0`, WP9) mirrored chord boxes, necks, lanes, the strum stage, the Scales and Intonation necks, Show me, the 3D and studio stages and the peg turns, with words never mirrored; added **"left, strung upside-down"** (no competitor has it) and a "Charts as printed" option; onboarding asks the question (`391778f`).
- **Why.** About 10 % of players are left-handed; Yousician, JustinGuitar and GuitarTuna already mirrored, so it was the one inclusivity axis Timbre was losing (`JURY15-inclusivity.md` item 2, `JURY15-category.md` item 6). The jury's rule: keep text unmirrored, and keep string labels (1 = thinnest) for upside-down players.

### 6.10 Accessibility as a differentiator

Accessibility is the only angle where both juries called Timbre a clean #1. The path:
- **Wave 6** (`ae77d65`): a VoiceOver tuner that speaks note and cents with an in-tune haptic; Increase Contrast; Differentiate Without Color.
- **Wave 14**: Dynamic Type roles, accessibility-size layouts, 44 pt targets, adaptive contrast tokens (from `DESIGN11.md`).
- **Wave 18**: haptics during recording (`f091a6a`); a VoiceOver play-along with spoken cues, earcons, a haptic count-in and a spoken result (`989f493`); focus on every new step and pedal/keyboard control (`ea9f65b`); spoken note names ("E flat 3") and "tighten/loosen" (`391778f`); Bold Text, Smart Invert, the Large Content Viewer (`a4f5d0e`); **Tune by feel**, where the phone pulses at the beat frequency between the string and its target and goes still at the lock (`391778f`; "a world first", `JURY16-delight.md`).
- **Wave 19**: Tune by feel on the tuner and on by default under VoiceOver (`4d826e2`); the notes step speaks the next note and which way to go (`face00c`); an accessibility audit that enforces contrast, hit regions, descriptions and traits, and a nightly AX5 / Bold Text / Increase Contrast / left-handed / upside-down / Arabic matrix (`4fe4432`).
- **The rule** (both foremen): don't claim VoiceOver in the listing or the Accessibility Nutrition Labels until blind testers have finished Unit 1 on a device; the other labels (Larger Text, Dark Interface, Differentiate Without Colour, Sufficient Contrast, Reduced Motion) can be declared now. Every competitor's label is empty.

### 6.11 Analytics and privacy

- TelemetryDeck, anonymous and batched, **off until the owner sets the app ID** (`660de99`). Wave 18 added the whole funnel (`app_open`, onboarding steps, the microphone answer, `paywall_view`/`paywall_close` with the test arm, `purchase` with trial, price and currency, cancel and fail), remote config, MetricKit and Apple Ads attribution; a usage-sharing switch that also stops the attribution request (`2d8f726`). Wave 19 added on-device subscription outcomes (`subscription_state`, `renewal`, `refund`) until App Store Server Notifications exist (`0d0f4b0`).
- Why: "Nothing is measured, so nothing can be tuned toward $10k" (round 15, B5). Microphone audio is analysed on the device and never stored or uploaded (`docs/ios/PRIVACY.md`).

### 6.12 Localization strategy

1. **Inherited:** 49 language tables from Android.
2. **Up to wave 8:** agents translated every new string into 48 locales and the lessons into 9 languages (de, es, fr, it, ja, ko, pt, ru, zh-CN), with tools that refuse a translation that changes a number, accidental or format specifier (`ec3c7d3`, `57f108f`).
3. **From wave 9** (`PREAMBLE.md`), per the owner: **agents write English only; people translate.** `docs/l10n/HANDOFF.md` says it plainly: "Translations are done by people, never by a machine."
4. **The translator handoff** (`c0ae634`, wave 17): per-locale TODO files with context and length hints, the old English and old translation for changed strings, stale-key tracking, report and import tooling.
5. **The release gate** (`0785642`, `4fe4432`): a shipped locale may not lack a purchase term, a permission prompt or a VoiceOver string (`critical.py --strict`). The delivery workflow's escape hatch `internal_testflight_untranslated` exports a build that can only go to internal TestFlight testers, never to App Review. `ship_min_coverage` can ship only the locales above a bar.
6. **Device language by default** (`a55e2e6`): before wave 18 every install ran in English (round 15, B1).
7. **The open decision** (owner, `REVIEW16.md` §4): ship English plus the 9 lesson languages and fund the launch-critical strings now, adding the other 39 locales as each reaches 95 %. At `0bbf273` the handoff lists 151 launch-critical strings (11 purchase terms, 1 permission prompt, 93 VoiceOver, 46 onboarding), 639 interface strings missing in all 48 locales, and 1,467 lesson strings missing in each of the 9 lesson languages. The listing makes no language count until the locales are complete.

### 6.13 CI and the release gate

- **All macOS work on GitHub Actions** because no one on the team has a Mac. Results go to `ci-results/*` branches.
- **Growing pains:** the app job's budget went 45 → 60 → 90 minutes as the UI suite grew (`35fc427`, `bb09492`, `e74c390`); the iPad job needed retries and a Full Screen Apps check (`8da5020`, `8292c76`, `5111d1f`); docs-only pushes skip CI (`b77dfbe`). By round 16 the gating job was "a 60–90 minute screenshot pipeline" and no green end-to-end run existed for wave 18 (`JURY16-technical.md` item 2).
- **The redesign** (wave 19, `4fe4432`):
  - `ios.yml` is the pull-request gate. The required `gate` check passes only when **core** (engine tests with a TimbreCore coverage floor, resources, translation handoff, critical-string gate, comment hygiene, SwiftLint against a committed baseline), **app** (TimbreAppTests plus three smoke UI flows: fresh launch, a string locked, Pro bought) and a **Release device build** are green; they run side by side, each in under 15 minutes. An `accessibility` job runs the audit and the localization launches beside them.
  - Compiler warnings fail core, app and release; concurrency diagnostics are counted per file while complete checking runs as warnings.
  - Pull requests may not carry `ios/` commits that skip CI or are WIP snapshots (`skip_ci_guard.py`; history before the day-1 contracts grandfathered).
  - Write access only for one small publish job per workflow.
  - `nightly.yml` (nightly, on dispatch or with the `captures` label): the full UI tour and App Store captures, the launch metric, the unsigned archive, the iPad shelf, the accessibility matrix and the thread sanitizer.
- **The hygiene lint** (`tools/ci/comment_hygiene.py`, formerly `lint_tells.py`): no review-panel references, WIP markers or test-coupled comments in code; a baseline that only shrinks (272 → 155 in wave 18, 450 → 96 after wave 19's integration, `2d8f726`, `62a7508`).

### 6.14 Store creative pipeline

- **Screenshots** are captured by UI tests from deterministic demo scenes (`TIMBRE_SCENE`, `aae487c`) with one seeded state (a 7-day streak, lit lamp, level 5; `345909a`), then composed by `tools/marketing/screenshots.py`, which checks every count against the build and every length against Apple's limits. Wave 18 art-directed the set (nine distinct compositions with a colour story; `85968e5`).
- **The App Preview** is recorded from the simulator by a scripted tour and cut automatically (`3635859`, `04ca81a`). It was silent until wave 18 and mostly silent in round 16; wave 19 added gates that fail a cut with more than 0.5 s of silence, a clip without sound, or no band energy under a "band" caption, and anchors the lock clip on the app's own lock event (`99a553c`).
- **The rule:** footage comes from the app. Demo scenes may make a capture deterministic, but marketing never shows a mock-up (`REVIEW15.md` §5).

### 6.15 "Never vibe-coded": engineering hygiene

- The jury's technical juror reads the code as an acquirer would. Round 15 found the tells: "review 14" and "bug 64" comments, test hooks in production files, scratch files, "WIP wave 17: in-progress team edits" commits, one author, no reviews (`JURY15-technical.md` item 12).
- The response: scratch files removed and the hygiene lint (`0785642`); `TestSupport` so release builds read no test environment (`2319909`); feature-scoped state (`TunerSession`) carved out of a 1,205-line `AppStore` that 89 `@EnvironmentObject` declarations observed (`2319909`); background persistence with a torn-file fuzz test (`2319909`); strict concurrency as warnings (`4fe4432`); and from wave 19, one clean commit per package with no `[skip ci]`, no WIP and no review references (`TEAM19.md`).
- What the jury said is still needed and only the owner can provide: **an independent senior human iOS reviewer**, branch protection on `main` that requires the gate, squash merges and ADRs. "Turns 'never vibe-coded' from a grep into a review trail an acquirer will price in" (`REVIEW16.md` §4). Round 16 also asked to drop the lint rule that banned the tool's name in comments while git names it as the author (`4fe4432` did).

---

## 7. Wave 19 in detail

### 7.1 Inputs

`REVIEW16.md` §2a listed eleven blockers to fix before submission:

| # | Blocker | Package |
|---|---|---|
| B1 | The wave can't pass its own App Store delivery gate: renewal terms, "Start free trial", the billing banner and the Apple Music permission are English in all 48 non-English locales | WP1 + owner |
| B2 | A fake Dynamic Island draws reward banners inside the system status bar | WP9 (day 1) → WP2 recapture |
| B3 | The lock doesn't hold: "In tune" drops after ~130 ms | WP3 (+ WP10 hook) → WP2 |
| B4 | The App Preview is mostly silence (17.7 of 23.17 s below −60 dB), the band is a bare click and the lock is never on camera | WP2 |
| B5 | Correct muted strokes (uke chunk, mandolin chop, reggae chop) are scored as misses | WP6 + WP5 |
| B6 | The violin and cello play-along shows guitar fret numbers | WP7 (day 1) → WP2 |
| B7 | The paywall's Free/Pro table contradicts the free tier | WP4 |
| B8 | A monthly intro trial would go undisclosed | WP4 |
| B9 | The paywall from Settings can render the "14 DAYS FREE" tag with no plan cards | WP4 |
| B10 | The *Kite Weather* cover imitates *Unknown Pleasures* | WP5 + owner |
| B11 | No green end-to-end run for the wave; HEAD is `[skip ci]` | WP1 |

The ten packages, ranked by impact on (a) a user choosing Timbre, (b) revenue, (c) ADA craft: WP1 release gate, languages and CI; WP2 store creative, preview and listing; WP3 the tuner's signature (a lock that holds, a feel you can find); WP4 paywall, price levers and first session; WP5 content (songs people know, correct songbooks, a free first song); WP6 listening that's right on every technique; WP7 songs, play-along and Show me; WP8 audio engine and the band; WP9 design system, app shell and rewards; WP10 platform and architecture. (The numbers differ from wave 18's: in wave 18 WP3 was store creative and WP2 the funnel.)

### 7.2 How the wave was run

1. **Day-1 contracts** (`bb6a22e`, 13:05; `CONTRACTS19.md`). Before the teams branched, one commit landed the shared APIs every package would build against:
   - WP6: `muted: [Double]` and `accents: [Double]` on strum and progression steps (written to JSON only when non-empty), and the builder's `strum(..., muted=, accents=)`;
   - WP8: `BandArrangement.Segment` and `Bar.segments`, `BandFeel.shared.kitOnly(_:)`, `SpokenCues.schedule(_:fretted:lead:brief:)`;
   - WP10: `AppStore.planCourse(forGoal:instrumentId:)`, `updateSettingsSoon(_:)` (coalesced about 300 ms) and `flushSettings()`, `TestSupport.isAutomated`;
   - WP9: `Palette.accentNeutral` (0xB4BECB), `Palette.starGold`, `RewardToast(placement: .docked)`;
   - WP4: `ReferralPill`, `ReviewPrompt.afterSong`, `RemoteConfig.shared.freeSongs` and `unit2Free`;
   - WP5: `Curriculum.distinctTuneCount`.
2. **Ten teams in isolated git worktrees** (`TEAM19.md`), each a branch of `v2/foundations` at the contracts commit. Each team read `PREAMBLE.md`, `REVIEW16.md` §1–2, the rules, its own package, §5 ("what not to do") and the juror files. One owner per file (an unlisted Swift file defaults to WP10, unlisted infrastructure to WP1); a change needed in another package's file is described in the report, not made. Each team migrated off-scale type and status-colour misuse in its own files, stripped review comments, ran the hygiene lint, the resource check and (for curriculum) `build.py --check`, and committed **once**, with a technical message and no "WIP", no `[skip ci]` and no review references. Teams never pushed; the orchestrator merged.
3. **Merges** (13:37–13:57), in this order, each a `--no-ff` merge of the team's single commit.
4. **Integration pass** in four parallel groups with disjoint files (`INTEGRATION19_BRIEF.md`), carrying out the cross-team requests (`INTEGRATION19.md`).
5. **Gate fixes, an audio follow-up and a QA follow-up**, each from CI evidence.

### 7.3 The ten packages

#### WP9: design system, app shell and rewards: `b2af55a`, merged `e1c2520` (13:37)
- **Docked reward toast (B2).** Island mode deleted; every announcement drops in as a capsule of the app's glass at `safeAreaInsets.top + 8`, at the leading gutter on a phone and centred on wide screens, so nothing is drawn inside the status bar.
- **Colour roles.** `Palette.adjust` names the status amber for non-pitch uses; every owned file asks for a role instead of `Palette.amber`/`coral` (zero direct uses outside `Theme.swift`). Today's activities in `accentNeutral` (the lesson in learning violet) as bare glyphs; rewards in `starGold`; `controlLine` raised to 0x646A74 (3.23:1 on surface); off-scale type literals moved onto the scale; opaque dock backdrops.
- **Calm mode, for real** (the list in section 6.8), and the Settings footer says so.
- **One streak metaphor:** a hanging stage lamp (`TimbreGlyph.lamp`) replaces the flame everywhere except the play-along combo. Results draw the level as the header's ring. After a clean take the coach gives the next lesson. The first three-star song asks for a rating (`ReviewPrompt.afterSong`); peaks offer `ReferralPill`.
- **Settings and instruments:** Tune by feel leads the Tuning section; the Pro row reads "Every lesson and song, every tuning and tool"; the picker opens on its search; a `TuningMenu` gives the tuner header a tunings menu; Learn's PRO pills become a corner lock.
- **Brand:** `TimbreMark` and `TimbreLogotype` replace tracked amber capitals; medal artwork hooks; an **interim mint "Still Point" app icon** with real Default, Dark and Tinted appearances, readable at 40 px, until the designer's Icon Composer file lands; `#Preview`s for the design components (debug only).

#### WP3: a lock that holds and a feel you can find: `4d826e2`, merged `12bb53d` (13:38)
- **The lock (B3).** `TuningTracker` keeps a confirmed lock across a gap of up to 500 ms when the readings either side are in the band (the band and the 650 ms hold are unchanged; "don't fix the flickering lock by loosening the band", `REVIEW16.md` §5). `LockLatch` holds the lock on screen (badge, quiet status, solid chip, peg tick, aura, VoiceOver) for at least 1.5 s and then while the pitch stays in the band. `TuningReading.status` becomes a `Codable` `TuningStatus` enum.
- **Tune by feel** gets a toggle among the tuner's side controls, on by default only while VoiceOver runs until the player chooses, and a one-time tip after the third full tune. Each beat is scheduled as one `CHHapticParameterCurve` on the engine clock.
- **Stage:** the 3D close-ups keep the head's whole crown (every mesh vertex above the top peg) under the feathered top edge, so violin and cello scrolls and the mandolin head stay whole; stages pin left-to-right; peg labels clear the side controls.
- **Readout:** Hertz formatted for the locale ("82,41 Hz"); the note letter cross-fades instead of rolling; Auto/Manual/Reference in sentence case at 15 pt; "≈ estimate" at 12 pt.

#### WP10: platform and architecture: `2319909`, merged `f83c27d` (13:41)
- Tuner state moves out of `AppStore` into an `@Observable` **`TunerSession`**. `AppStore` forwards its existing API so every screen compiles unchanged, but a string change, a chromatic note change or a lock no longer redraws every view that observes the store.
- The lock path saves nothing on the frame that locks: progress, the full-tune count and the string-health sample go to the next `updateSettingsSoon` batch.
- `LocalStore` gains **background durability**: writes on a serial utility queue, coalesced to the newest state, retried on failure, with `flush()` waiting for the disk; saves validate only what changed. Writer and state file are `Sendable` through `Synchronization.Mutex`.
- Dead settings removed (`theme`, `skin`, `reducedMotion`, `telemetryEnabled`, `bandOnSpeaker`); one `Preferences` type for UserDefaults keys; `TestSupport` launch keys so nothing reads the process environment in a release build; the catalogue decoded off the main thread; `curriculum_failed` logged.
- Tests: `TunerSession` unit tests, a store test that a string change publishes nothing on the store, background-durability tests, and a **seeded fuzz test that a state file cut off or torn at any byte still opens**.
- **Merge conflict** with WP3 in the lock path, resolved to WP10's deferred path (WP3's `recordLock` removed; `announceProgress` kept).
- Not done (left in `INTEGRATION19.md`): iCloud sync (needs an entitlement the owner must enable), curriculum sharding, the `Router`/`ProgressStore` split.

#### WP7: songs, play-along and Show me: `f824a90`, merged `5dca1c3` (13:42)
- **Fingerboards (B6).** A new `FingerPlace` reads a note's place as violin, viola, cello and double-bass players do (finger, 0 for open, low/high, or a shifted position). Gems, the up-next rail, the Next row and VoiceOver say "String 1, finger 1"; cello diagrams put the tapes on first-position places.
- **Chords per change.** `SongArrangement.played(inBar:)` gives each bar's chords as played (the downbeat's, then every change inside the bar); the band is built from them through `Bar.segments`; `ChordAlongJudge` judges every change on its own first stroke; "Chords & words" shows split bars ("C · G"). Tests: every song's played bars reproduce its chart's changes.
- **Lanes and RTL:** string 6 moves to ice (0xB8F0FF) and every gem carries its string number; music rails stay left-to-right in RTL languages; spoken cues start two beats ahead under a 1.5 s beat and go brief under a 1.6 s gap.
- **Results:** section tiles never go blank; "Strongest" skips sections under eight notes.
- **Show me:** one stable "Chart · Player view · 3D" picker; lesson clips show a photo stepper until a video is bundled.
- **Your songs:** a pasted chart plays start to finish as a "Chords & words" take.

#### WP8: audio engine and the band: `94da7e9`, merged `ce77ff0` (13:46)
- **A band on the speaker.** `BandTrack` renders the kit, the pitched rhythm section and the comping as separate layers. On the speaker while the microphone listens, the band plays **its kit only**, high-passed at 200 Hz, so nothing pitched reaches the pitch detector; thin and fill stay audible. In headphones, or with nothing listening, the full band plays.
- The band follows every chord change inside a bar (`BandGroove.changing(at:)`), tested in every style.
- **A good audio citizen.** `AudioSessionOwner` runs every session change on its serial queue, waits a one-second grace before deactivating, and leaves the session ambient afterwards; UI sounds ask it for the ambient category, so the welcome motif mixes with a podcast and chimes respect the silent switch. Route and configuration changes share one debounced rebuild; interruptions for a suspended app are ignored; 20 ms I/O buffers when only listening, 5 ms when timing matters.
- **Spoken cues** through the app's own `AVSpeechSynthesizer` in the app's language, choosing the full phrase, a brief one or none so the cue ends before its note; `SpeechGate` keeps the microphone from hearing the voice.
- `docs/ios/AUDIO-DEVICE-TESTS.md`: the device test sheet (results pending a device run).
- Not done: the speaker band's step 2 (an echo canceller or voice processing behind a self-test), metronome voices and grooves.

#### WP4: paywall and first session: `0d0f4b0`, merged `077b5c0` (13:46)
- **First song.** The plan's days follow the minutes a day the person chose (`PaywallPlan.Pace`). For the "songs" goal, when the course's own first song is Pro or more than a week off, the plan names a song the free plan plays (the first free song ahead, else the instrument's songbook song on day 2). "Play your first song this week" is said only for such a song.
- **The Free/Pro table (B7)** is built in TimbreCore (`PlanComparison`) from `AccessPolicy`, `FreeTier` and `YourSongsPolicy`.
- **Price levers.** `timbre_pro_annual_b`/`_c` join the product lists, so a remote arm sells them and they grant Pro; `FreeOpenings` carries `freeSongs` and `unit2Free` into `AccessPolicy.canPlay`.
- **Any plan's free trial is disclosed and handled (B8):** trial label, CTA, terms, `trial=1` and the trial reminder per product.
- **Paywall seams (B9):** the plan tag is part of its card and the chosen plan's glass is a layer behind it; one `TrackLayout` keeps timeline words on their nodes; "12 × $6.99" instead of a struck-through price; "Cancel anytime in Settings"; the rating fetched per storefront, in ink.
- **Onboarding:** a **"Just tune"** door on the welcome (the tuner listening after one tap; the questions deferred to Learn); restore as a footnote; the reminder card after the first chord; a Tune by feel offer with a three-second feel after the first lock; the played chord credited to its lesson.
- Subscription outcomes logged on device. Tests: the table against the policy, remote openings, yearly arms granting Pro, per-plan trials, a beginner's free first song on guitar, ukulele, violin and mandolin; UI tests for the plan cards and "Just tune".

#### WP6: listening correctness: `face00c`, merged `e10e4b3` (13:48)
- **Muted and accented strokes (B5).** `StrumTake` in TimbreCore judges strummed takes stroke by stroke. A muted beat passes when no chord rings or the stroke has stopped 150 ms on (ring under 30 % of the attack); a chop left ringing is held to OK with "Let it stop". A correct man-4-4 take now earns three stars and a correct uke-8-1 scores 100 % (it scored 60 %). Accented beats must come in 4 dB over the median; the badge names the beat to push ("Push the and of 2").
- `StrokeChords` reads a stroke only up to just before the next one, so close strokes no longer blend.
- `ChordTarget` checks every quality the curriculum names: a 9 as its 7, add9 and m6 as their triads, 6 as the minor seventh it equals, with templates for diminished, diminished seventh and augmented.
- `LessonListening` is the analysis the live lesson runs, and `AudioClip` feeds recordings through it in the microphone's 512-frame buffers, so tests and the real-world corpus use the live path.
- VoiceOver in the notes step names the next note after each hit and which way to go while a wrong pitch is held; cues never overlap each other or their note.
- Page-turner pedals in every mode; a wrong listening answer shows its notes on a staff; after two wrong answers, "I can't hear this" leaves the question unscored.

#### WP2: store creative and preview: `99a553c`, merged `01a23dd` (13:55)
- **Preview gates (B4).** The pipeline used to check only mean loudness, so a cut that was 77 % silent printed "Meets the App Preview spec". `tools/marketing/gates.py` measures the delivered file: no silence over 0.5 s anywhere, every clip sounding, the band's low end under a "band" caption; it finds the "In tune" badge's first frame and re-finds a sync screenshot to 1/60 s.
- Clips anchor on the app's own lock event; the lock bell must land within 80 ms of the badge; the poster is verified on the badge or moved to the first frame that shows it; the app's motif plays under the end card; exit 4 marks a take worth recording again; `preview.yml` records both cuts and publishes the violin cut separately.
- Demo scenes: the preview's string drifts into tune in its own reference voice.
- Store frames: #1 (iPhone and iPad) requires the badge as well as the tick; violin results and the cello and ukulele pages' lead frames captured; crops refuse any frame whose top edge cuts text; `--check` enforces Apple's Custom Product Page keyword rule.
- Docs: the keyword field rebuilt as the pages' inventory; Custom Product Page and deep-link wording matched to Apple's help; "hears every strum" and Tune by feel in the listing; an Accessibility Nutrition Labels section; no monthly introductory offer until the paywall discloses it.

#### WP1: release gate and CI: `4fe4432`, merged `6b38b27` (13:55)
- The **15-minute required gate**, the nightly workflow, warnings as errors and the `[skip ci]` guard described in section 6.13 (B11).
- **The translation gate (B1):** `critical.py` checks the shipped locales from `CFBundleLocalizations`; pull requests fail on a legal, permission or VoiceOver gap not in the committed baseline. The untranslated escape hatch is now `internal_testflight_untranslated` (internal TestFlight only, stamped `TimbreBuildChannel=internal`). `tools/l10n/shipping.py` can trim the shipped locales to those above a bar; nothing was cut. `report.py` lists launch-critical strings first.
- **Tests:** the play-along test was starved, not stuck (each accessibility snapshot stalls the app's main thread); commerce tests retry a purchase StoreKit didn't record; `AccessibilityAuditUITests` enforces contrast, hit regions, element descriptions and traits with known issues listed per screen, retries an audit that times out and fails if none completes, and runs with the stage resting; `LocalizationLaunchUITests` checks the German headline (an expected failure until the funnel strings are translated), the Arabic octave placement and a bounded pseudo-language.
- Lint: `lint_tells.py` became `comment_hygiene.py`; tool names are no longer policed, review-panel references are; new status-colour and inline-orb rules.

#### WP5: content correctness: `c46c452`, merged `b2aafe7` (13:57)
- **A free first song in every instrument course's unit 1:** *Mary Had a Little Lamb* in three notes on guitar, mandolin, violin, cello, bass, banjo and voice; *Row, Row, Row Your Boat* on one chord for ukulele.
- **Songbook editions fixed:** the key from the opening and closing chords; chord roots spelled for the key (E♭, never D♯); ukulele keys pay for hard shapes (Cm, Fm, E♭, B♭7, F♯m, D♭), so *Rondo alla Turca* sits in A minor and *Carmen* in A; octave folds move whole phrases and never turn a step into a leap.
- **New songbooks:** cello (C-G-D-A shapes, first position, 65 songs) and bass (roots and fifths on the beat, 120 songs).
- **Muted and accented beats** emitted for reggae skanks, mandolin chops, ukulele chunks and island accents.
- **App:** "Songs you know" first; a Carols shelf in season ("free this week" when `freeSongs` opens it); a gold Pro lock on Pro sleeves; a "Request a song" footer; the pulse sleeve motif replaced by a tuner-dial motif (B10, code side); new chord formulas (maj9, m9, 6/9, 7sus4, 11, 13, dim7, m7♭5).
- `63f73bd`: counts after the first songs (526 lessons, cello and bass songbooks).

### 7.4 Integration pass (four groups, 14:31–14:53)

`3be9da4` first fixed the gate on the merged tree (a module cache key without `hashFiles`, a Release-only analytics ID path, wrapped step coding, a chord bar line by `reduce`, a band style test that skips cues two songs share).

| Group | Files | Commit / merge | What it did |
|---|---|---|---|
| A | tuner, settings, onboarding, commerce, Learn shell | `2b78d1e` / `0170b42` | `TuningStatus` cases replace status strings; Settings binds Tune by feel through `TuneByFeel`, lists only languages with a `.lproj`, gates strobe and temperaments through `FreeTier.opens`; the tuner header's tuning line is the `TuningMenu`; share cards and the welcome carry `TimbreLogotype`; streak chips draw the lamp; Calm mode on the tune celebration; Learn asks the questions "Just tune" deferred; a verified purchase not yet in the entitlements is checked again a second later; `canPlay` passes the remote openings explicitly; `PRIVACY.md` covers `song_request`; `APPLE-DELIVERY.md` covers the `_b`/`_c` products and the new delivery inputs |
| D | platform, stage, watch, widgets, UI tests, lint | `8580079` / `8f11ae9` | `TIMBRE_STAGE_REST` makes the stage, Kit and shaders treat audits as Low Power so the screen holds still; launch keys through `TestSupport`; the Watch receives neutral and violet Today arcs, never a status colour; the Live Activity's accents in white; `distinctTuneCount` counts tunes; UI tests wait out the reward toast before captures, check the lock stays 1.5 s, and check the mandolin, violin and cello heads clear the stage edge |
| B | lessons, songs, play-along | `e7dcdfd` / `60fe2b1` | one "Chart · Player view · 3D" switch wherever a model exists; violin and cello never say "fret"; attack-graded takes play the band with `onSpeaker: false`; one cue path (`CuePlan` timing, `SpokenCues.schedule` speech, a fingerboard's string and finger) with the old scheduler deleted; the band chip says what headphones add; previews no longer require headphones; Spaced review keeps muted and accented beats; `RhythmStep` and `HighwayRunway` moved to their own files so no source file passes 2,200 lines |
| C | audio, practice, demo scenes | `3fa41ca` / `ee12f4d` | an interruption no longer swaps a running demo pitch for a silent microphone; DEBUG `TIMBRE_DEMO_CLIP` plays a recording into the analysis path; an ambient-session check for interface sounds; `playWelcome()` and a miss "wobble" at the target's pitch; Practice locks from `FreeTier`; Calm mode in the Practice hub and ear training; an interval legend read as full names; a dead-string demo scene; band parameter structs |

`9628967` made the smoke purchase test start from a clean StoreKit session (a transaction left by the unit tests had made the app Pro at launch). `0e4f24f` refreshed the localization handoff and fixed SwiftLint `empty_count`. `62a7508` finished the follow-ups: the welcome motif through the ambient session, the dead-string capture hook, the demo clip and preview motif as `TestSupport` keys, the unused per-note cue API removed, neutral watch tints, **hygiene baseline 450 → 96**.

### 7.5 Gate, audio and QA follow-ups (15:36–16:25)

- `d031914`: gate fixes (the localization handoff, `empty_count` and shorthand lint, the "Just tune" link clear of the mint button's glow).
- `0bb161f`: a UI-only nightly run has no unit test to load the scheme's StoreKit configuration, so the UI tour now loads and empties it itself; the onboarding capture picks the violin chip.
- **Audio** (`f87f052`, merged `0da2ed9`): two tuner starts overlap at launch (`onAppear` and the scene-phase change both call auto-listen); the first, called off after its activation, released the session the second had just taken, and a second later the session went ambient under the running microphone, so the restart failed. Now a superseded start never releases a newer start's session, and a transient failure retries once 300 ms later on a fresh engine before the alert (`MicStartRetryTests`); debug builds log which step failed.
- `5e4a3c1`: the translation handoff check ignores moved line numbers (it had failed the gate on unrelated edits).
- **QA** (`9c3d22f`, merged `0bbf273`): on the CI runner the audio output start held the main thread 9.4 s inside the store scene, so *Kite Weather*'s one-bar lead was gone and the first ten notes were missed; the click (and the audio output) now starts before the take's clock, which also helps real takes. The store scene's HUD holds its combo still. The AX5 tuner gets two shorter side-control fallbacks so "Strum" no longer covers Settings. The Arabic octave test runs on the demo pitch. The accessibility job gets a warm-up launch and one retry for tests that failed only because the app never launched (`tools/ci/launch_retry.py`).

### 7.6 Wave 19 by the numbers

- 43 commits (`bb6a22e` … `0bbf273`): 27 changes and 16 merges; **0 `[skip ci]`, 0 WIP** (wave 18 had 22 and 12).
- 298 files changed, +48,477 / −24,482 lines (`git diff --shortstat eb6ee5c 0bbf273`).

### 7.7 Round-16 blockers after wave 19 (the team's claims, pending round 17's verification)

| # | Blocker | What wave 19 did | Still open |
|---|---|---|---|
| B1 | Delivery gate fails in 48 locales | Strict critical-string gate on PRs; submit blocked for untranslated builds (`4fe4432`) | The translations themselves, or the owner's locale cut |
| B2 | Fake island in the status bar | Island mode deleted; docked toast (`b2af55a`); captures wait the toast out (`8580079`) | Recaptures |
| B3 | Lock flickers | 500 ms gap tolerance and a 1.5 s latch (`4d826e2`); UI tests check it (`8580079`) | Device check |
| B4 | Silent preview, no lock | Gates that fail a silent or unsynced cut; event-anchored lock; motif on the end card (`99a553c`) | A cut that passes the gates, reviewed |
| B5 | Muted strokes graded as misses | `StrumTake` (`face00c`); data (`c46c452`, `e7dcdfd`) | Real chunks and chops in the corpus |
| B6 | Violin fret numbers | `FingerPlace` (`f824a90`, `e7dcdfd`) | Recapture of violin #2 |
| B7 | Table contradicts free tier | `PlanComparison` from the policy (`0d0f4b0`) | — |
| B8 | Undisclosed monthly trial | Per-product trial disclosure (`0d0f4b0`) | The owner still should not add one before testing |
| B9 | Tag without card | Tag inside its card (`0d0f4b0`) | — |
| B10 | *Unknown Pleasures* pastiche | Pulse motif retired (`c46c452`) | A commissioned *Kite Weather* cover |
| B11 | No green run | Required 15-minute gate; gate fixes (`3be9da4`, `9628967`, `d031914`, `0bb161f`) | Branch protection (owner) and a green gate on HEAD |

The consensus majors were also worked: the first-song promise (WP4 + WP5), half-bar chord changes (WP7 + WP8), the speaker band (WP8, kit only), the ukulele songbook (WP5), dead remote levers (WP4), the audit that enforced nothing (WP1), Swift 6 (strict concurrency as warnings; `.v6` once TimbreCore has no warnings), `AppStore` split (WP10, `TunerSession` first), commit hygiene (section 7.6), Tune by feel discoverability (WP3, WP4, WP9), Custom Product Page keywords (WP2), the colour rule (WP9, lint), the paywall timeline (WP4), the silent notes step (WP6), UI sounds through the session owner (WP8), store crops (WP2) and cropped scrolls (WP3).

### 7.8 What wave 19 left (from `INTEGRATION19.md`)

- **Team items:**
  - the AX5 tuner header is still cramped (text clipped, overlaps);
  - `TuningMenu` sits on the tuning line only (making the whole header a menu would break tests that tap `tune.instrument`);
  - RemoteConfig has no carol-week key, so the owner removes `freeSongs` by hand after the week;
  - a Watch widget's sample tint, a `WatchSnapshot` doc comment, a paywall comment and the Watch Today and Metronome screens' status amber (baselined in the lint);
  - iCloud sync, curriculum sharding and the `Router`/`ProgressStore` split (WP10);
  - the speaker band's step 2 and metronome voices and grooves (WP8);
  - a lint baseline update once all rules settle.
- **Device checks** (no simulator can do them): Tune by feel and haptics with the microphone open, including vibration bleeding into the input; cold launch onto the tuner repeatedly, a restart within 1 s, drone plus microphone, AirPods in and out, a phone-call alert, permission denied; time from Perform to the first click (any freeze over 300 ms is a bug); `docs/ios/AUDIO-DEVICE-TESTS.md`.
- **Recaptures** for WP2: 07, 14, 17, 18 (toast), 20, 62, 12/30, Learn, the tuner #1 frames on iPhone and iPad, 49/49b/49c, Arabic, 59, 60, 65b, 51/51b, the song sheet, results, 53–55, the *Kite Weather* sleeve, the new Songs shelves.
- **Owner:** make `gate` (and optionally `accessibility`) a required check; refresh the published `privacy.html` from `PRIVACY.md`; Associated Domains; the hand rig and the ukulele and banjo models; the device test sheet.

---

## 8. What each round said was still missing for #1

This section collects, round by round, what the reviewer or jury said stood between Timbre and the top score, so nobody has to re-read the files. Items marked **(owner)** need money, accounts, licences or people.

**Rounds 1–2.** Not recorded.

**Round 3 (6.9).** Honest grading (no passing a strum by tapping the glass); a moment of magic before the paywall (tune a real string first); overlays that respect the safe area; lesson visuals that fill the screen; curated chord shapes; real motion and a designed sound palette.

**Round 4 (7.8).** A Today card that keeps onboarding's promise; an honest path for free users who choose a Pro instrument; one string orientation; real art instead of SF Symbols; tiered achievement art; correct German note names; hero moments for each practice tool; reverb and a humanized band.

**Round 5 (7.5).** A first session that counts; results that tell the truth; the promised tempo ladder; one daily session instead of four; weak-spot review; show-then-play demos; share cards; a VoiceOver tuner; store assets (App Preview, Live Activity, privacy URL).

**Round 6 (7.7).** The plan's promised lesson must open; real instrument voices; outcome-led paywall bullets with a live preview; a highway worth the App Preview; plurals in every language.

**Round 7 (7.9).** A tuner hero that shows which peg to turn; a highway with 3–4 visible gems; one paywall timeline; visible reminder opt-in; share moments; explain steps that move; songs that sell; a store set that matches the listing. **(owner)** licensed songs; real ratings; the privacy URL; prices, trial and offers; Game Center; the final App Preview and its music.

**Round 8 (8.1).** Deterministic store shots; correct placement for experienced players; one paywall hero with clear copy; a full instrument shelf; a metronome hero; lesson steps that fill the screen; explain steps that play. **(owner)** the privacy URL; ratings; the App Preview music; licensed songs; a Watch decision; translation of the lessons beyond 10 of 49 languages, or saying "tuner" only in the other 39 listings; prices and trial length.

**Round 9 (8.6).** Clean funnel screens; songs with an opener and a finale; feature-specific paywalls and a price anchor; a real tanpura; deeper chords and scales; coach notes; Watch and widget depth. **(owner)** licensed songs ("the biggest perceived-value gap"); filmed instructor demos; an illustrator; real ratings and press quotes; a pricing and trial test.

**Round 10 (8.1).** Full-length songs with lyrics; real iPad layouts; a finished song sheet; signature shader moments; a competitive loop (Game Center, leagues); offer codes and win-back. **(owner)** licensed songs or commissioned originals with real band stems; instructor or hand-cam clips; a 3D soprano ukulele; the privacy URL; pricing; review quotes.

**Round 11 (8.4).** Engraved notation and TAB; a player's-view neck; real iPad compositions; labelled tuner controls; a chromatic stage worthy of the 3D ones; the Apple Intelligence coach; Liquid Glass; a Watch app. **(owner)** licensed pop repertoire ("the single biggest gap"); multisampled instruments and backing stems; instructor clips; free violin and cello tuning; an Icon Composer icon; the privacy URL; quotes.

**Round 12 (8.4).** The recorded band and instruments; the paywall's yearly card; one string orientation; Songs above the fold; Strum to tune in the store set; true onboarding copy; legible captions; spaced review; Game Center challenges. **(owner)** recognisable songs; human teaching; prices of $49.99–59.99 a year and lifetime at $149 or none; the privacy policy on a custom domain; social proof.

**Round 13 (8.7).** Clean hero frames; adult-first shelves; an onboarding paywall that shows the catalogue; "Show me" demonstrations on the 3D rigs; strum arrows that match the pick; stars that mean something; a stable Today. **(owner)** multi-velocity recordings (flat-top guitar, ukulele, mandolin, banjo); produced stems for the Originals; hand art or teacher video; the privacy URL; a pricing test; social proof.

**Round 14 (8.9).** Four things short of "Apps We Love": store-frame defects (and Show me never captured), localization drift, the paywall hero's collisions, and content credibility (public domain plus Originals; stand-in timbres; Show me without a hand). Also ukulele parity and correct bowed-instrument pegs. **(owner)** 20–30 licensed tracks through a partner; recordings; teaching media; ukulele and banjo 3D models; the privacy policy; the analytics ID; human review of the lesson languages; a pricing test; a violinist's check of the pegs.

**Round 15 (jury, 7.7).** A clean #1 on 1 of 6 angles (Inclusivity). The code roadmap (WP1–WP10) would reach about 8.6–8.8; "#1 on all angles is not reachable with code alone". Each juror's top moves:
- **Visual:** art-direct the store listing like an ad and give the preview sound; kill the tinted-circle icon and own a glyph family; give Show me a hand; a design-system pass with CI lint; bespoke reward art; real iPad layouts; one normalised stage.
- **Delight:** "Feel it stand still" (haptic beating, then Tune by feel); rebuild the App Preview around three signatures with sound; make the band the fun (chord-aware, on the speaker, reacting to the player); a music-native reward language; give Bullseye a hidden melody; hero-scale the 3D effects; a hand and ukulele for Show me; a weekly song.
- **Inclusivity:** "a blind guitarist finishes Unit 1 with VoiceOver" as a tested claim; real left-handed and upside-down modes; close the language gap or stop claiming it; a hands-free kit; prove it in CI and fill the Accessibility Nutrition Labels; Calm and Simple modes; spoken music vocabulary.
- **Technical:** remove the two latent blockers (language, persistence); correct and measurable revenue (grace, StoreKit tests, analytics, server notifications); prove the DSP on real audio and publish the numbers; re-architect for a team (feature models, modules, Swift 6, previews, review); harden audio and battery on hardware; account-free iCloud sync; Mac and visionOS availability.
- **Growth:** measure first; win the instruments GuitarTuna ignores (Custom Product Pages for violin, cello, ukulele…); lessons before the paywall; $49.99 with the 14-day trial; songs people know or "paste any song"; a store page that converts; social proof; reminders; virality.
- **Category:** the best strumming feedback (chord and timing per stroke, name the dead string); songs people know on every instrument (ukulele songbooks, requested public-domain songs, band recordings, a licensed pack, "Your songs"); a teacher you can see; "Chords & words"; win "best free tuner" outright; left-handed and capo diagrams; honest store copy; publish accuracy.
- **(owner)** song licensing ($15–60k); recordings; a stylised hand and teacher video ($8–15k for about 40 clips); prices ($49.99 / $9.99 / $149.99, Family Sharing, grace after the fix); a TelemetryDeck ID, a server-notifications endpoint and remote config on a custom domain; translators or a locale cut; an art director, icon designer and sound designer; the free-tier table; paid blind and left-handed testers, a TestFlight cohort, teacher quotes, a device lab and **an independent senior iOS reviewer**; the App Store Connect programme (Custom Product Pages, In-App Events, Product Page Optimization, a featuring nomination, Accessibility Nutrition Labels, Apple Ads only after revenue per install is measured).

**Round 16 (jury, 8.3).** Still a clean #1 on 1 of 6; every margin narrowed. Code alone reaches about 8.7 (Visual 9.0, Delight 9.1, Inclusivity 9.1, Technical 9.0, Growth 8.5, Category 8.7); with the owner's levers, 9.0–9.1. Each juror's top moves:
- **Visual:** build a brand, not just a UI (one mark, an Icon Composer icon with real variants, a logotype, a sonic and motion signature); fix the island, the paywall timeline and the docks; re-cut the ad around the lock; a hand for Show me and real art on the emotional screens; a self-enforcing design system; one art direction for every instrument picture (68 photos of unknown provenance); iPad as its own composition.
- **Delight:** a band everyone can hear, then one that follows them; a sound-first preview with a shot of Tune by feel; "Feel it stand still" as the headline, on the Watch too; latch the lock and recapture #1; Bullseye as "Mystery Song" with a weekly league; one streak metaphor; weekly fresh Originals; a teacher's hands.
- **Inclusivity:** finish the languages you ship, or ship fewer; make the VoiceOver Unit 1 claim true and tested; claim the Nutrition Labels now (except VoiceOver); prove it with AX5, Bold Text, Increase Contrast, left-handed and Arabic frames; fix RTL at the glyph level; complete the hands-free kit; make Calm mode real and offer it in onboarding; finish the contrast and lane colours.
- **Technical:** make it shippable and provably green (strict critical-strings gate, a fast required gate, no `[skip ci]`); prove the DSP on 100–300 real clips and publish the numbers; re-architect for a team; make every gate real; finish audio on hardware; iCloud sync; a process a buyer can trust (a human reviewer, squash merges, ADRs).
- **Growth:** make the first-song promise true for every beginner; turn the instrument pages on for real (keyword field as inventory); fix the money paths (price arms, `unit2Free`, monthly disclosure, subscription events); a preview you'd unmute; lead with the public-domain songs people know and a December carol event; translate the funnel first; honest social proof; a "Just tune" door; a referral that rewards the referrer.
- **Category:** songs people know (a licence; until then "Songs you know" first and "Your songs" as the answer to "can I play my song?"); make the new feedback flawless (muted strokes, half-bar changes) and then show it in the store; a teacher you can see (bow hold first); own ukulele and violin outright (correct songbooks, finger labels, real samples, a cello songbook); "best free practice app"; prove accuracy; a price anchor against the lesson apps.
- **(owner)** the locale set for v2.0 (English plus the 9 lesson languages, the 96 critical strings funded now); prices ($49.99 / $9.99 / $149.99, Billing Grace on now, no monthly intro, the `_b` arm at $59.99 only after the wiring shipped); accounts and addresses (TelemetryDeck ID, App Store ID, share page, remote-config and privacy URLs on a custom domain, server notifications, an EU consent posture); a starter licensing pack (*Knockin' on Heaven's Door*, *Riptide*, *Let It Be*, *Stand by Me*, *Three Little Birds*, *Somewhere Over the Rainbow* for ukulele); teacher video (8 planned clips, bow hold first) and a stylised hand; a brand designer and an art director (a new *Kite Weather* cover, a pastiche audit of the Originals' sleeves); the provenance of the 68 "provided" instrument photos; recordings (ukulele, mandolin, banjo, Originals stems, a 1,000-clip corpus); an independent reviewer with branch protection; the App Store Connect programme (keyword field, violin, cello and ukulele pages, a "Holiday carols" In-App Event submitted by about 10 November, a January featuring nomination); a free song in every unit 1 and free basic scales.

---

## 9. Where things stand at `0bbf273`

### 9.1 The product

- **Instruments and tuning:** 60 instruments, 132 tunings (`catalog.json`). Guitar, bass, ukulele, violin and cello are free in every preset; every other instrument is free in its standard tuning. A 3D stage for 7 artist models (CC-BY), photo stages with turn signs for the rest, a chromatic strobe disc, Strum to tune (polyphonic), precision levels, temperaments, custom tunings, intonation check, string health, Tune by feel.
- **Lessons** (`curriculum.json`): **19 courses, 1,100 lessons.**
  - 11 teaching courses, 526 lessons: guitar 154 (22 units), ukulele 61, bass 32, violin 39, cello 32, mandolin 34, banjo 31, ear training 40, theory 44, rhythm 29, voice 30.
  - 3 song collections, 145 lessons: Songs 38, Originals 60, Standards & Classics 47.
  - 5 songbooks, 429 lessons: ukulele 110, mandolin 68, violin 66, cello 65, bass 120.
  - The listing says "140+ songs" (146 distinct titles) and 50 Originals.
- **Practice:** Today plan with spaced review, metronome (and a haptic beat), drone (tanpura), chords with Check, scales, ear training, Bullseye, voice, Your songs.
- **Habit and social:** streaks with freezes, quests, XP and levels, 42 achievements, coach notes (on-device Apple Intelligence where available), reminders, share cards, Game Center (leaderboards, challenges, friend streaks), Calm mode, Simple tuner.
- **Platform:** iPhone and iPad layouts; widgets (Home, Lock Screen, StandBy, configurable) and a Control Center control; a Live Activity and Dynamic Island; App Intents, Siri, Shortcuts and Spotlight; TipKit; an Apple Watch app with complications and a wrist metronome.
- **Sound:** 11.4 MB of CC0 samples in 300 files; a band that plays its kit on the speaker and the full band in headphones.
- **Languages:** 49 tables (English plus 48), lessons in English plus 9; see 6.12 for what is missing.
- **Code** (counted at `0bbf273`): the app target `ios/Timbre` 159 Swift files, 71,260 lines; the engine `ios/Sources/TimbreCore` 57 files, 15,366 lines; `func test…` declarations: 463 in the core tests, 47 in the app unit tests, 41 in the UI tests. Swift 5 language mode with complete concurrency checking as warnings.
- **CI workflows:** `ios.yml` (PR gate), `nightly.yml`, `apple-delivery.yml`, `preview.yml`, `l10n.yml`, `cards.yml`, `assets.yml`.

### 9.2 Nothing has shipped yet

No App Store product, signing or upload exists; `docs/ios/APPLE-DELIVERY.md` lists what the owner sets up first (agreements, the Small Business Program, products and prices, API key secrets, the privacy URL).

### 9.3 Open items

**Team (code):** the leftovers in section 7.8; recaptures of every store frame changed by wave 19; Swift 6 language mode once the warnings reach zero; the `AppStore` split beyond `TunerSession`; iCloud sync; the speaker band's echo canceller; metronome voices and grooves; arming the type-scale and status-colour lints at error once their counts reach zero.

**Owner (only the owner can do these):**
- languages: fund the launch-critical strings (151 at HEAD) or cut the shipped locales;
- prices, offers, Family Sharing, Billing Grace Period, the Small Business Program in App Store Connect;
- the TelemetryDeck app ID, the App Store ID, the privacy, share and remote-config URLs on a custom domain, App Store Server Notifications v2;
- song licensing (a starter pack), teacher video, a stylised hand rig, ukulele and banjo 3D models;
- recordings (ukulele, mandolin, banjo, band stems for the Originals, the real-audio corpus);
- an icon designer, an art director, a sound designer, a new *Kite Weather* cover, the provenance of the instrument photographs;
- people: an independent senior iOS reviewer with branch protection, blind and left-handed testers, a device lab, a TestFlight cohort, teacher quotes;
- the App Store Connect programme: keyword field, Custom Product Pages, the carol In-App Event, featuring nomination, Accessibility Nutrition Labels.

### 9.4 What not to do (the juries' standing rules)

**Business** (`REVIEW15.md` §5, `REVIEW16.md` §5):
1. Don't submit with `internal_testflight_untranslated`; the renewal terms would be English in 48 storefronts.
2. Don't add a monthly introductory offer before testing the disclosure; prefer win-back offers and offer codes.
3. Don't announce price or free-tier tests until their wiring is verified.
4. Don't plan Custom Product Page keywords that aren't in the app's keyword field.
5. Don't claim VoiceOver before blind testers have finished Unit 1.
6. Don't caption "Play songs with the band" over a click track.
7. Don't show a hand-typed or global rating, and don't fake social proof.
8. Don't strike through a computed "was" price in EU or UK storefronts.
9. Don't buy installs before revenue per install is measured.
10. Don't shorten the yearly trial to 7 days.
11. Don't add ads or mandatory accounts.
12. Don't ship sleeves that imitate famous covers, songs that are "almost" a hit, or photos whose provenance you can't show.

**Product and engineering:**
1. Don't move the reward toast back near the status bar; the status bar belongs to the system.
2. Don't fix the lock by loosening the band or the hold; latch the display.
3. Don't turn on voice processing for the tuner; lessons only, behind a self-test.
4. Don't make Tune by feel the default for sighted users before the device bleed test.
5. Don't add courses, units or tools; the next content work is correctness and recognisable songs.
6. Don't arm a lint before the file owners have migrated, and don't edit a file you don't own.
7. Don't big-bang the `AppStore` split.
8. Don't commit `[skip ci]` or "WIP wave N" to `ios/`, and don't merge without a green gate.
9. Don't add chips, pills, glows or amber "for polish"; subtract.
10. Don't mirror text for left-handers; keep string labels.
11. Don't make the Show me hand realistic; stylised avoids the uncanny valley.
12. Don't let marketing captures diverge from the product.
13. Don't remove the honest trial timeline, the real-offers-only exit offer or "Continue with the free tuner".

---

## Appendix A: every commit, in order

Phases as in section 3. "Interlude" is the owner-decision period between waves 14 and 15. Times are −03:00.

| Phase | Commits | First | Last |
|---|---:|---|---|
| Port | 1 | `328b7d3` | `328b7d3` |
| Still Point foundations | 52 | `be17ba8` | `464cb4a` |
| Studio Noir | 12 | `de06563` | `5de53b3` |
| Learn engine | 14 | `3327fb4` | `121d9ea` |
| Wave 1 | 14 | `2acfbbd` | `6ac9539` |
| Wave 2 | 11 | `35fc427` | `660de99` |
| Wave 3 | 2 | `356daa3` | `0c42eec` |
| Wave 4 | 4 | `1983645` | `fced833` |
| Wave 5 | 6 | `2ab038b` | `5031616` |
| Wave 6 | 6 | `ae77d65` | `125dd2b` |
| Wave 7 | 5 | `9a46c7a` | `ec3df9a` |
| Wave 8 | 8 | `85eb0ea` | `964f3a1` |
| Wave 9 | 11 | `99b1c9f` | `8e280f8` |
| Wave 10 | 3 | `afd4349` | `55f87c1` |
| Wave 11 | 13 | `9e92165` | `bad004f` |
| Wave 12 | 5 | `55d2369` | `d045eda` |
| Wave 13 | 8 | `85fa83c` | `0ee5ff2` |
| Wave 14 | 2 | `b7a9ef5` | `d8ca0e9` |
| Interlude | 8 | `7e32f2f` | `27ce76f` |
| Wave 15 | 10 | `d9fc9a5` | `820edf8` |
| Wave 16 | 21 | `6e1b0d7` | `3b0e47c` |
| Wave 17 | 17 | `ea6c80e` | `7c8d46c` |
| Wave 18 | 27 | `da3ae69` | `536b9c2` |
| Wave 19 | 43 | `bb6a22e` | `0bbf273` |
| **All** | **303** | `328b7d3` | `0bbf273` |

| # | Commit | Date (−03:00) | Phase | Subject |
|---:|---|---|---|---|
| 1 | `328b7d3` | 2026-10-22 19:33 | Port | Port Timbre to native Swift and SwiftUI for iOS (#1) |
| 2 | `be17ba8` | 2026-10-22 20:33 | Still Point foundations | Add procedural 3D instrument pipeline and CI result publishing |
| 3 | `bb51c46` | 2026-10-22 20:42 | Still Point foundations | Tune studio exposure, P-bass outline and neck joint |
| 4 | `3e8baa2` | 2026-10-22 20:42 | Still Point foundations | Core: Pro access policy, practice engines, vDSP autocorrelation |
| 5 | `48f11a1` | 2026-10-22 20:47 | Still Point foundations | Assets: warmer spruce, real head veneer, projected 2D anchors; new icon and display font |
| 6 | `4c25880` | 2026-10-22 20:48 | Still Point foundations | Package: tools 6.0 for iOS 18 platform, Swift 5 language mode |
| 7 | `b66f0a6` | 2026-10-22 21:12 | Still Point foundations | App: Still Point redesign, live 3D tuning stage, subscriptions and practice loop |
| 8 | `b0902a8` | 2026-10-22 21:16 | Still Point foundations | Core: avoid capturing mutating self in ear question builder; list unique Swift errors in CI summaries |
| 9 | `bfcf72a` | 2026-10-22 21:23 | Still Point foundations | Fix first app compile errors; image-based stage light via component; honest accuracy bench |
| 10 | `81c45fc` | 2026-10-22 21:24 | Still Point foundations | Models: proper offset-waist P and J bass bodies, contour pickguards, control plates, J pickups; ebony head faces |
| 11 | `ab07472` | 2026-10-22 21:31 | Still Point foundations | Models: violin family on the friction-peg rig (violin, viola, cello, double bass) |
| 12 | `d22d621` | 2026-10-22 21:34 | Still Point foundations | Models: rounder bass horns, plain maple necks, satin ebony head faces, black J guard |
| 13 | `d9ddf76` | 2026-10-22 21:38 | Still Point foundations | Siri and Shortcuts entry points, centred string rail, 3D stage diagnostics, UI test fixes |
| 14 | `ff18bea` | 2026-10-22 21:40 | Still Point foundations | Models: strings run to the correct posts (no crossing at the head) |
| 15 | `b11a0e0` | 2026-10-22 21:41 | Still Point foundations | Fix stage diagnostics name clash; 2D string lights only while ringing; short chromatic header |
| 16 | `3c74c7d` | 2026-10-22 21:43 | Still Point foundations | Models: violin corners, open pegbox, slimmer pegs, deeper varnish |
| 17 | `8a96e58` | 2026-10-22 21:43 | Still Point foundations | CI: localization export workflow (xliff of every source string) |
| 18 | `6b44986` | 2026-10-22 21:46 | Still Point foundations | Custom tunings (Pro): editor with per-string semitone steps and reference tones; paywall presents from the top-most surface |
| 19 | `3137106` | 2026-10-22 21:49 | Still Point foundations | Widgets: quick tune, practice streak (home and lock screen), Control Center tuner; timbre:// deep links |
| 20 | `d7df85f` | 2026-10-22 21:50 | Still Point foundations | Delivery: automatic signing with an App Store Connect API key (app, widgets, App Group); docs for subscriptions, no ads |
| 21 | `acf0ff4` | 2026-10-22 21:52 | Still Point foundations | Models: shaded violin-family tops, finer pegs and pegbox walls |
| 22 | `f3d99a1` | 2026-10-22 21:53 | Still Point foundations | Tools: list untranslated source strings from the exported xliff |
| 23 | `dc11fed` | 2026-10-22 21:54 | Still Point foundations | Tuner: two-column layout for landscape and wide iPad windows |
| 24 | `68d91aa` | 2026-10-22 21:54 | Still Point foundations | 3D stage falls back to the studio render when a model cannot load |
| 25 | `dd47c75` | 2026-10-22 21:56 | Still Point foundations | 3D stage: studio render holds the stage while the model loads, then cross-fades |
| 26 | `761eb0b` | 2026-10-22 21:58 | Still Point foundations | Paywall and settings sheets each get their own anchor; UI test covers the paywall over settings |
| 27 | `ca02ce5` | 2026-10-22 21:59 | Still Point foundations | 3D close-up aims at the peg being tuned and glides between strings |
| 28 | `939dae3` | 2026-10-22 22:00 | Still Point foundations | Merge 3D asset work: P/J basses, violin family, post order fix |
| 29 | `0816c7c` | 2026-10-22 22:00 | Still Point foundations | Install 3D models: reworked P/J basses, uke and guitar post order, violin family (3D only, photo cards) |
| 30 | `2b4f29d` | 2026-10-22 22:01 | Still Point foundations | Stage: pegs and strings keyed per string so paired courses (12-string, mandolin) animate both pegs |
| 31 | `ec3c7d3` | 2026-10-22 22:06 | Still Point foundations | Tools: merge translations into the strings tables with format-specifier checks |
| 32 | `6ed77fe` | 2026-10-22 22:09 | Still Point foundations | Intonation check (Pro): 12th-fret harmonic against the fretted note for every string, with saddle advice |
| 33 | `55e8b1c` | 2026-10-22 22:11 | Still Point foundations | Debug demo pitch drives the tuner for screenshots; App Store screenshot composer |
| 34 | `6df97ed` | 2026-10-22 22:11 | Still Point foundations | CI: 3D asset builds run on assets/** pushes only |
| 35 | `b76425b` | 2026-10-22 22:13 | Still Point foundations | Paywall: the instrument sways in a 3D spotlight, the studio render holds the spot while it loads |
| 36 | `daaac99` | 2026-10-22 22:14 | Still Point foundations | Docs: mark the v1 port audits as historical |
| 37 | `e515ac5` | 2026-10-22 22:14 | Still Point foundations | UI tour: intonation check and custom tuning editor |
| 38 | `2c32f66` | 2026-10-22 22:15 | Still Point foundations | Install 14 more 3D instruments (guitars and ukes with studio cards; mandolin family, bouzouki, balalaika, domra 3D only) |
| 39 | `2479acd` | 2026-10-22 22:16 | Still Point foundations | UI tests: let scrolling settle before tapping |
| 40 | `88f4d59` | 2026-10-22 22:18 | Still Point foundations | Stage: slide motion for wind joints, brass slides and tines; push/pull hint; strings optional |
| 41 | `66f7945` | 2026-10-22 22:20 | Still Point foundations | Install mandolin, mandola and mandocello with sunburst tops and studio cards |
| 42 | `9516c8a` | 2026-10-22 22:25 | Still Point foundations | Studio stage draws no string for slide instruments |
| 43 | `c0ea646` | 2026-10-22 22:26 | Still Point foundations | Install banjo and kalimba 3D models with studio cards |
| 44 | `f9728a5` | 2026-10-22 22:31 | Still Point foundations | Practice subtitle keeps the instrument's capital in German |
| 45 | `7340ffd` | 2026-10-22 22:31 | Still Point foundations | English plural rules for counts (1 minute, 1 cent flat, every bar) |
| 46 | `1fdf96c` | 2026-10-22 22:38 | Still Point foundations | Install 9 wind and brass 3D models: trumpet, trombone, horn, flute, clarinet, saxophone, recorder, whistle, shakuhachi |
| 47 | `8083727` | 2026-10-22 22:38 | Still Point foundations | Root paywall presents from the tab view; stage keeps child accessibility ids |
| 48 | `9283a33` | 2026-10-22 22:38 | Still Point foundations | Translate the 381 new strings into 48 languages; widgets ship the string tables |
| 49 | `a5b7a53` | 2026-10-22 22:38 | Still Point foundations | Fix two older strings: Kannada quarter note, Catalan capo |
| 50 | `f943c61` | 2026-10-22 23:04 | Still Point foundations | Root paywall slides up as an overlay instead of a root-anchored sheet |
| 51 | `80e0740` | 2026-10-22 23:27 | Still Point foundations | UI test probe for presentation flags (debug builds only) |
| 52 | `448c664` | 2026-10-22 23:44 | Still Point foundations | UI test probe: try another point and another pro tile |
| 53 | `464cb4a` | 2026-10-23 00:04 | Still Point foundations | Fix dead taps on card buttons: the glass background is not hit-testable |
| 54 | `de06563` | 2026-10-23 00:55 | Studio Noir | Studio Noir redesign, part 1: tokens, Sora, Tune screen, XP, quests, badges, string health, Pitch Sniper core |
| 55 | `5767850` | 2026-10-23 00:58 | Studio Noir | Play hub (level, quests, ear games, tools) and Pitch Sniper game; fix core closure |
| 56 | `75945df` | 2026-10-23 01:05 | Studio Noir | Progress, Instruments, Paywall and Welcome in the Studio Noir design; fix quest test |
| 57 | `20cab25` | 2026-10-23 01:12 | Studio Noir | 2D photo stage with per-string points, artist model credits, celebration in the new look |
| 58 | `fc8c508` | 2026-10-23 01:13 | Studio Noir | Pro copy: stage, not 3D, for every instrument |
| 59 | `eb49087` | 2026-10-23 01:18 | Studio Noir | l10n apply: accept positional arguments when types and order match |
| 60 | `5ffe206` | 2026-10-23 01:27 | Studio Noir | Intonation: equal-width string chips that fit any instrument; wider recent cards |
| 61 | `8f2ece8` | 2026-10-23 01:36 | Studio Noir | Localize the redesign: 103 new strings in 48 languages |
| 62 | `b414a5d` | 2026-10-23 02:23 | Studio Noir | Artist model installer: render-based library photos for classical and electric guitar |
| 63 | `463b9f2` | 2026-10-23 02:57 | Studio Noir | Retire the procedural 3D models: artist acoustic and electric guitar in 3D, every other instrument on its photograph |
| 64 | `a7e40a4` | 2026-10-23 02:58 | Studio Noir | UI test: photo stage on the ukulele, with a string selected |
| 65 | `5de53b3` | 2026-10-23 03:08 | Studio Noir | CI evidence: side branches publish to their own ci-results branch |
| 66 | `3327fb4` | 2026-10-23 03:15 | Learn engine | Learn engine: curriculum model, play-along and note judges, lesson runs, progress; curriculum builder |
| 67 | `56dd37f` | 2026-10-23 03:28 | Learn engine | Learn tab: course carousel, continue card, winding lesson path, lesson player |
| 68 | `2c51bca` | 2026-10-23 03:29 | Learn engine | Tune check before the day's first playing step; trial timeline on the paywall |
| 69 | `86e38ae` | 2026-10-23 03:33 | Learn engine | One chord diagram for lessons and the Chords tool; ChordSpec public init; curriculum drafts in progress |
| 70 | `61677c6` | 2026-10-23 03:35 | Learn engine | Rhythm steps carry their meter (3/4, 2/4, 6/8); rhythm and singing courses drafted |
| 71 | `ac083c6` | 2026-10-23 03:36 | Learn engine | Rhythm course: meters on every non-4/4 tap step |
| 72 | `4fa98f0` | 2026-10-23 03:39 | Learn engine | Curriculum: ear training (40), music theory (44), rhythm (29), singing (29) in the app |
| 73 | `b34f787` | 2026-10-23 03:43 | Learn engine | Guitar course (60 lessons); daily practice reminder and post-lesson offer; rating ask after flawless lessons; Learn follows the onboarding choice; paywall promises match the product; staff spells flats |
| 74 | `de962ed` | 2026-10-23 03:46 | Learn engine | Learn: progression steps (timed chord changes), fret-position diagrams, position fingering in the builder; fix two compile errors |
| 75 | `43b1849` | 2026-10-23 04:05 | Learn engine | DSP: chord recognizer and onset detector for chord and rhythm lessons |
| 76 | `b0f5ee2` | 2026-10-23 04:10 | Learn engine | Seven artist 3D instruments (acoustic, classical and electric guitar, bass, mandolin, violin, cello), 11 courses / 401 lessons, lesson microphone ownership |
| 77 | `214bdc6` | 2026-10-23 04:27 | Learn engine | Merge chord recognizer and onset detector (dsp/chords) |
| 78 | `619e6c9` | 2026-10-23 04:28 | Learn engine | Lessons hear chords and strums: chord steps pass on a recognised strum (string-by-string stays as the fallback), strum steps use real onsets, play-along re-attacks use the onset detector |
| 79 | `121d9ea` | 2026-10-23 04:33 | Learn engine | Fix lesson save (stars as stable count of three), cleaner next-note callout and finished highway |
| 80 | `2acfbbd` | 2026-10-23 04:55 | Wave 1 | Review 1 fixes: perspective play-along runway with string colours, timing feedback in ms and a slower retry, strum arrows, tap-or-play, I-played-it override, answer tiles, fingerboard lesson path, pinned paywall button with three plans, tools hide the tab bar, one smoothed value in tuner status, US spelling, badge fixes; songs course split in two parts |
| 81 | `ca358cf` | 2026-10-23 05:01 | Wave 1 | Celebration and share card show the tune-up time; chromatic strobe clears the side buttons without a second note name; reminder button stays on one line |
| 82 | `5fe65c5` | 2026-10-23 05:21 | Wave 1 | Songs course part 1 (21 public-domain songs and medleys); App Store screenshot composer in the new design |
| 83 | `3f35215` | 2026-10-23 05:22 | Wave 1 | UI tests: bass, mandolin, violin and cello on the 3D stage |
| 84 | `79dbba2` | 2026-10-23 05:50 | Wave 1 | Songs course part 2: hymns and Americana, holiday songs, classical themes II (439 lessons in all); new lesson and paywall strings translated into all 48 languages |
| 85 | `dde709a` | 2026-10-23 06:00 | Wave 1 | App Store listing: name, subtitle, keywords, description, review notes, IAP names and a pricing note |
| 86 | `83d4cb8` | 2026-10-23 06:02 | Wave 1 | Lesson results show the level bar filling with the lesson's XP, a level-up fanfare, and badges and quests earned (the toast was hidden behind the lesson) |
| 87 | `df90f0b` | 2026-10-23 06:02 | Wave 1 | Dark and tinted app icon variants for iOS 18 Home Screen customisation |
| 88 | `57f108f` | 2026-10-23 06:25 | Wave 1 | Lessons in Spanish: all 4,121 lesson strings; apply_learn.py writes each locale's Learn.strings from tools/l10n/learn and rejects translations that change numbers or accidentals |
| 89 | `6c2e289` | 2026-10-23 06:26 | Wave 1 | Next lesson widget (small, medium, Lock Screen): the next lesson in the learner's course and course progress; taps open Learn (timbre://learn) |
| 90 | `1f07b0d` | 2026-10-23 06:34 | Wave 1 | Lessons in German, Brazilian Portuguese and Japanese (4,121 strings each); UI tests search back up the instrument list; CI evidence leaves out files over 45 MB and falls back to logs only, so a failing run still reports |
| 91 | `aeb35cb` | 2026-10-23 06:45 | Wave 1 | Lessons in French (4,121 strings) |
| 92 | `14631ab` | 2026-10-23 07:02 | Wave 1 | UI tests: tab taps retry until the tab is selected (a dismissing sheet swallowed the tap) |
| 93 | `6ac9539` | 2026-10-23 07:16 | Wave 1 | Streak freezes (one banked on every seventh day, up to two, spent automatically on missed days) and reminders planned day by day: none once you've practised, each naming the next lesson and the streak at stake |
| 94 | `35fc427` | 2026-10-23 07:35 | Wave 2 | Polish pass from review round 2 |
| 95 | `8da5020` | 2026-10-23 07:45 | Wave 2 | CI: retry the iPad screenshots once when the simulator's test runner fails to start |
| 96 | `bc4055f` | 2026-10-23 07:59 | Wave 2 | Lessons in Italian, Russian and Korean; 15 new UI strings (paywall, plan, streak freeze, reminders) in all 48 languages |
| 97 | `b140b73` | 2026-10-23 08:02 | Wave 2 | Lessons in Simplified Chinese; Custom tuning button moves to the tunings header so it's always in reach |
| 98 | `b77dfbe` | 2026-10-23 08:03 | Wave 2 | Listing: name carries "guitar tuner" (Timbre: Guitar Tuner & Lessons), subtitle and keywords rebalanced; CI skips docs-only pushes |
| 99 | `2ca51b4` | 2026-10-23 08:04 | Wave 2 | Achievements whose goals are already met unlock at launch and when the app comes forward |
| 100 | `974b79e` | 2026-10-23 08:33 | Wave 2 | Backing band for play-along, strum and progression steps: synthesized drums, bass and pad in sample sync with the metronome, only through headphones (speaker keeps the click), with a toggle; step clocks follow the click as it's heard |
| 101 | `9682d17` | 2026-10-23 08:34 | Wave 2 | UI tests: onboarding Continue waits until enabled and retries until the next screen shows |
| 102 | `194309c` | 2026-10-23 08:35 | Wave 2 | Backing-band labels in all 48 languages |
| 103 | `96c7a18` | 2026-10-23 08:37 | Wave 2 | Band: split a bass-line expression the compiler couldn't type-check |
| 104 | `660de99` | 2026-10-23 09:28 | Wave 2 | Analytics ready to switch on (TelemetryDeck ingest, anonymous, batched; off until the TELEMETRYDECK_APP_ID variable is set); privacy manifests declare UserDefaults reasons (app and widget) and product-interaction analytics |
| 105 | `356daa3` | 2026-10-23 09:58 | Wave 3 | Polish pass 3 from review round 3 |
| 106 | `0c42eec` | 2026-10-23 10:10 | Wave 3 | Wave 3 strings in all 48 languages (first tune, contextual paywall, precision, practice mode) |
| 107 | `1983645` | 2026-10-23 11:02 | Wave 4 | Songs tab replaces the Instruments tab (song of the day, shelves by course with generated covers, instrument filter; the full instrument browser stays in the tuner's picker); guitar course grows to 16 units / 96 lessons (fingerpicking, blues, lead technique, moving barres, rhythm styles, capo and arranging); new Originals course: 20 original songs in contemporary styles + 4 challenges (499 lessons in all) |
| 108 | `5d68c3b` | 2026-10-23 11:32 | Wave 4 | New guitar units and Originals in all 9 lesson languages; "Song of the day" in 48 |
| 109 | `56703ad` | 2026-10-23 11:54 | Wave 4 | Listing: 499 lessons in 13 courses, accurate free-tier and stage claims, Songs tab |
| 110 | `fced833` | 2026-10-23 12:04 | Wave 4 | Localized listings: 499 lessons in 13 courses, accurate free tier, Songs tab, stage caption |
| 111 | `2ab038b` | 2026-10-23 12:21 | Wave 5 | Wave 5 from review round 4 |
| 112 | `29427cd` | 2026-10-23 12:55 | Wave 5 | Achievements (42), level names and wave-5 labels in all 48 languages; they were never localized before |
| 113 | `1a4774d` | 2026-10-23 13:06 | Wave 5 | UI tests: chord lesson retries the first Continue through the zoom transition and skips the rest of the tune check |
| 114 | `98e221c` | 2026-10-23 13:07 | Wave 5 | Today card: ring and glow pinned to their 112 pt frame; spark burst as an overlay so it can't resize the ring |
| 115 | `bb09492` | 2026-10-23 13:47 | Wave 5 | CI: app job timeout 60 min (the UI flow suite now runs ~41 min) |
| 116 | `5031616` | 2026-10-23 14:25 | Wave 5 | iPad UI test: wait for the picker's Done button, swipe the sheet away if it never shows |
| 117 | `ae77d65` | 2026-10-23 15:06 | Wave 6 | Wave 6 from review round 5 |
| 118 | `3635859` | 2026-10-23 15:17 | Wave 6 | App Preview pipeline: a scripted UI tour, a manual/preview-branch workflow that records the simulator and cuts an App Store preview (886x1920, 30 fps, silent AAC) with a poster frame; outcome-led screenshot captions; the main suite skips the tour |
| 119 | `61942d5` | 2026-10-23 15:23 | Wave 6 | Wave 6 strings in all 48 languages |
| 120 | `eae6c4a` | 2026-10-23 16:23 | Wave 6 | App Preview tour: resume listening until the tuner is really listening again |
| 121 | `9d175fc` | 2026-10-23 16:24 | Wave 6 | Lesson results: content fades out above the buttons instead of being cut at their edge |
| 122 | `125dd2b` | 2026-10-23 16:38 | Wave 6 | App Preview tour keeps filming when a moment is missed (marks what it got; the cut uses those) |
| 123 | `9a46c7a` | 2026-10-23 17:08 | Wave 7 | Wave 7 from review round 6 |
| 124 | `247f2e4` | 2026-10-23 17:09 | Wave 7 | Wave 7 strings in all 48 languages |
| 125 | `04ca81a` | 2026-10-23 17:41 | Wave 7 | App Preview: place clips by matching sync screenshots, hands-off tuner locks, recorder handshake, retakes |
| 126 | `89c089c` | 2026-10-23 17:46 | Wave 7 | UI tests: wait for the StoreKit sheet to close; tap the tune-check skip only if it is still there |
| 127 | `ec3df9a` | 2026-10-23 18:41 | Wave 7 | Demo pitch plays a play-along on time (screenshots, App Preview); results clip starts once the screen draws |
| 128 | `85eb0ea` | 2026-10-24 03:11 | Wave 8 | WIP wave 8 (teams still working; not expected to build yet) |
| 129 | `11ef24a` | 2026-10-24 03:12 | Wave 8 | WIP wave 8: lesson steps team done |
| 130 | `f0fb9ba` | 2026-10-24 03:16 | Wave 8 | WIP wave 8: paywall team done |
| 131 | `116a29d` | 2026-10-24 03:20 | Wave 8 | WIP wave 8: songs/metronome team done |
| 132 | `413e5cc` | 2026-10-24 03:21 | Wave 8 | Translate the six corrected lesson lines into 9 lesson languages |
| 133 | `4ac0fe8` | 2026-10-24 03:36 | Wave 8 | Siri, Shortcuts and Control Center: tune/metronome/drone/lesson/streak intents, metronome control, one deep-link router |
| 134 | `c0b86ef` | 2026-10-24 03:58 | Wave 8 | Wave 8 strings in 48 languages (Siri phrases, highway verdicts, week recap, paywall), stricter token check; picker drag no longer dismisses the sheet |
| 135 | `964f3a1` | 2026-10-24 04:48 | Wave 8 | UI tests: find picker cards through the search field instead of scrolling the sheet |
| 136 | `99b1c9f` | 2026-10-24 05:05 | Wave 9 | Strum to tune: polyphonic tuner engine (one strum, every string) with synthetic-chord tests |
| 137 | `a9476aa` | 2026-10-24 05:06 | Wave 9 | WIP wave 9 (teams working) |
| 138 | `936b4d2` | 2026-10-24 05:29 | Wave 9 | Strum to tune screen: per-string meters from one strum, fine-tune hand-off, demo reading for screenshots |
| 139 | `d8fdcae` | 2026-10-24 11:44 | Wave 9 | Wave 9F: fuller instrument shelf, metronome beat row hero, share pill on results and play-along, song progress on covers |
| 140 | `989d418` | 2026-10-24 11:47 | Wave 9 | WIP wave 9 (teams working) |
| 141 | `9040c17` | 2026-10-24 11:48 | Wave 9 | Wave 9C: per-course placement table with a 45-second placement check, plan names skipped units, first-tune header fixed, welcome chips fade |
| 142 | `361a29a` | 2026-10-24 11:52 | Wave 9 | WIP wave 9 (teams working) |
| 143 | `aae487c` | 2026-10-24 11:52 | Wave 9 | Wave 9A/9B: deterministic store scenes (TIMBRE_SCENE), checked store frames, shelf drag fix; one model load per instrument with stale loads dropped, peg close-ups for every stage, 3D shots wait for the model |
| 144 | `cfbb108` | 2026-10-24 11:57 | Wave 9 | Wave 9E: lesson steps fill the screen (action bar, 60% diagrams, fret numbers), explain steps auto-play their demo, quizzes anchored low |
| 145 | `f734280` | 2026-10-24 12:03 | Wave 9 | Wave 9D: paywall hero is one scene of your instrument feeding the real highway lanes, plain headline, track shows the next distinct outcome |
| 146 | `8e280f8` | 2026-10-24 12:38 | Wave 9 | UI tests: guitar grid via the family chip (no sheet scrolling), lock check trusts the hands-off picture over the stalled badge; drop unused drag helpers |
| 147 | `afd4349` | 2026-10-24 13:18 | Wave 10 | Wave 10 (C, D, F, G, H): one string orientation, highway finish and type floor; live Play hub and tanpura drone; on-device coach notes; configurable widgets, Spotlight, TipKit, StandBy; clearer Strum to tune and consistent note spelling (paywall, songs, chords teams still working) |
| 148 | `80d8d27` | 2026-10-24 13:20 | Wave 10 | WIP wave 10 (paywall, songs, chords teams working) |
| 149 | `55f87c1` | 2026-10-24 13:24 | Wave 10 | Wave 10A/10B: feature-specific paywall heroes, honest price anchor, What's in Pro table, funnel fixes, listing notes; song sheet opener, Perform finale with 9:16 share card, merchandised Songs tab, lesson entrance fix |
| 150 | `9e92165` | 2026-10-24 14:43 | Wave 11 | Wave 11D: Metal shader moments (lock shimmer, strobe ripple, heat stars), results and coach agree on flawless runs, status text no longer garbles, share cards render after the entrance; CI installs the Metal toolchain when missing |
| 151 | `c98e715` | 2026-10-24 14:47 | Wave 11 | WIP wave 11 (teams working) |
| 152 | `69d99dc` | 2026-10-24 14:47 | Wave 11 | QA fixes (services): screen stays awake while playing, lesson clicks restart in phase and stop on background, widgets wait for entitlements, batched settings writes and history roll-up, midnight-correct streak widget, no double-counted strum minutes, VoiceOver string numbers, cached curriculum lookups |
| 153 | `2ec9ffb` | 2026-10-24 14:47 | Wave 11 | Tuner string rail: VoiceOver numbers strings the way players and lessons do (1 = thinnest) |
| 154 | `78ab844` | 2026-10-24 14:48 | Wave 11 | Wave 11B: real iPad layouts (tuner three-column landscape, Play/Progress/Learn grids), stage survives rotation, picker page sizing, idle redraws pause, iPad captures wait for 3D |
| 155 | `e3e725c` | 2026-10-24 14:48 | Wave 11 | WIP wave 11 (teams working) |
| 156 | `bdbe8d3` | 2026-10-24 14:50 | Wave 11 | Wave 11E: compact lesson header, strum lane with down/up strokes and a travelling pick, steps fill the screen, chord-box clipping fixed, tune-check orb follows one state; QA: cancel stale tone/listen tasks, burst stops redrawing, lesson clicks respect the Metronome tool |
| 157 | `2a52eed` | 2026-10-24 14:50 | Wave 11 | WIP wave 11 (teams working) |
| 158 | `cb9debe` | 2026-10-24 14:51 | Wave 11 | Wave 11F: one shared edge fade for every chip row (fades only where content overflows), rotary drone dial with detents and ticks, equal-height Today rows, settings values on the right, non-breaking hyphen |
| 159 | `4d32295` | 2026-10-24 14:55 | Wave 11 | Wave 11G: Game Center (quiet sign-in, Sniper boards incl. weekly league, ear level, achievements), Beat-my-score challenge links, Sunday week notification; paywall: offer codes, weekly price, honest win-back offer, roomier hero; QA: entitlements refresh on foreground and expiry, Ask to Buy unstick, modal paywall, untruncated terms, links wait for covers |
| 160 | `3a28c13` | 2026-10-24 14:56 | Wave 11 | Wave 11C: lead sheet with sections, chords, melody and tab; tap a section to loop it slower; locked songs say why and offer a 20 s preview; 16 cover motifs and varied type, mesh-gradient backdrops; QA: songs catalog computed once, story poster renders after the reveal |
| 161 | `31763dd` | 2026-10-24 15:50 | Wave 11 | WIP wave 11 (songs content team working) |
| 162 | `bad004f` | 2026-10-24 15:57 | Wave 11 | Wave 11A: all 52 songs are full 1:35–2:58 arrangements (intro, verses, choruses, bridges, outro) with public-domain or original lyrics; karaoke lyric line on the highway and Perform; arrangement API with sections, chords and section practice loops; QA: loop tempo floor, cached gem labels, click ownership, background abandons a take |
| 163 | `55d2369` | 2026-10-24 16:06 | Wave 12 | WIP wave 12 (song integration and instrument-course songs in progress) |
| 164 | `4d07cc2` | 2026-10-24 16:15 | Wave 12 | Wave 12A: song sheet, previews and Practice this part run on the real arrangements (sections, chords on the beat, lyrics under the melody, verse-first previews) |
| 165 | `fab7889` | 2026-10-24 16:15 | Wave 12 | Next song widget: chords and tempo from the full arrangement |
| 166 | `09a8d96` | 2026-10-24 16:18 | Wave 12 | WIP wave 12B (instrument-course songs in progress) |
| 167 | `d045eda` | 2026-10-24 16:45 | Wave 12 | Wave 12B: all 53 instrument-course songs end on the whole song (1:35–2:55; bass root lines, fiddle AABB with kick-offs, banjo roll breaks, violin/cello/mandolin variations, uke picked interludes, full sung verses), shared public-domain tunes and words, melody fixes, stricter build checks |
| 168 | `85fa83c` | 2026-10-24 17:50 | Wave 13 | Wave 13D: songs grouped by tune with version badges (no duplicate shelves), one preview affordance on every cover; store frames upright with checked sizes, 9:41 status bars, demo lessons consistent with the streak |
| 169 | `2d288e0` | 2026-10-24 17:57 | Wave 13 | Wave 13E: labelled AUTO \| MANUAL glass pill and Reference button under the stage, Peterson-style strobe disc with note wheel and needle arc, cents and Hz always agree |
| 170 | `d0ff002` | 2026-10-24 17:58 | Wave 13 | WIP wave 13 (teams working) |
| 171 | `d2ff4d3` | 2026-10-24 18:02 | Wave 13 | Wave 13B: player's-view perspective neck for chords (fingers land in order, muted/open strings, shimmer with Hear it) with a Chart \| Player view flip; strum stage always reads down as down |
| 172 | `90dce7d` | 2026-10-24 18:06 | Wave 13 | Wave 13C/F/G: iPad Learn path + lesson inspector, Play dashboard, START beside its node; Liquid Glass toolkit on rails, lesson bar, paywall plans and CTA; paywall plan hero with first-song sleeve and real plan road; one ♯/♭ formatter app-wide, drone wheel rises clockwise, welcome chips never clip, coach dedupe, on-device Apple Intelligence coach (weak-linked, template fallback) |
| 173 | `53f79c4` | 2026-10-24 18:15 | Wave 13 | WIP wave 13/14 (notation, watch, design tokens in progress) |
| 174 | `6737442` | 2026-10-24 18:17 | Wave 13 | Wave 13H: Apple Watch companion (haptic metronome on the Crown, Today ring with streak and set, Start on iPhone via Handoff, complications) over WatchConnectivity; bundles take the delivery version and build numbers |
| 175 | `0ee5ff2` | 2026-10-24 18:25 | Wave 13 | Wave 13A: engraved staff notation and TAB on song sheets (key-correct spelling, beams, ties, rests, lyrics, chord symbols, Staff/Tab/Both), staffs in bowed and mandolin note steps, readable song map; notation layout tested over every play-along |
| 176 | `b7a9ef5` | 2026-10-24 18:36 | Wave 14 | Wave 14A: design foundation — Dynamic Type roles that keep headings above body, Increase Contrast tokens, one primary/secondary button system with real disabled states, 44 pt targets, shared Kit (close button, section heading, eyebrow, stat tiles, empty/loading states, scalable Pro badge), radius/spacing/hairline and motion tokens |
| 177 | `d8ca0e9` | 2026-10-24 19:08 | Wave 14 | Wave 14B–F: design system applied app-wide — tab headers, section headings, step titles, one button system, close/back buttons, chips and segmented pills at 44 pt, stat tiles, eyebrows, hairlines, radius/spacing/motion tokens, Increase Contrast and Reduce Motion handling, accessibility-size layouts, consistent fractions and copy |
| 178 | `7e32f2f` | 2026-10-24 19:51 | Interlude | Violin and cello tuning are free (5 of 60 instruments); song licensing playbook for the owner; WIP Your Songs and new repertoire |
| 179 | `ae5cc56` | 2026-10-24 19:55 | Interlude | Explain steps stop their demo the moment Continue is tapped, so a late demo note can't stop the next step's microphone (test10 regression) |
| 180 | `c241175` | 2026-10-24 19:55 | Interlude | WIP: Your Songs and repertoire (teams working) |
| 181 | `337aed9` | 2026-10-24 20:19 | Interlude | 30 new contemporary originals (pop anthems, folk, country, reggae, funk, punk/rock riffs, ballads, barre-chord songs) in six new Originals units, all full arrangements with lyrics |
| 182 | `455efe4` | 2026-10-24 20:23 | Interlude | Your Songs shelf: split the modifier chain so it type-checks in time |
| 183 | `bc275e3` | 2026-10-24 21:14 | Interlude | Standards & Classics: 18 worldwide-public-domain songs (Joplin, Sousa, Strauss, Bizet, Grieg, Scottish/Irish/Welsh traditionals, carols) as full arrangements with a per-song rights table; listing counts updated |
| 184 | `40c7c5a` | 2026-10-24 21:14 | Interlude | Listing: not every song has words |
| 185 | `27ce76f` | 2026-10-24 21:55 | Interlude | WIP sound department (sampled instruments in progress) |
| 186 | `d9fc9a5` | 2026-10-24 22:07 | Wave 15 | WIP wave 15 (teams working) |
| 187 | `485180a` | 2026-10-24 22:19 | Wave 15 | Wave 15E: no clipped rail selections, honest onboarding skip copy per plan, 12–13 pt informative captions in inkSoft, LV label on the level ring, soft scroll edge under the tab bar, untruncated tuning chips |
| 188 | `3cf7f59` | 2026-10-24 22:19 | Wave 15 | WIP wave 15 (teams working) |
| 189 | `890ece3` | 2026-10-24 22:24 | Wave 15 | Wave 15A: plan names never break, free-trial tag drawn above the glass, quieter lifetime card, accessibility-size paywall and win-back layouts, hero light fades inside its bounds |
| 190 | `027414c` | 2026-10-24 22:24 | Wave 15 | WIP wave 15 (teams working) |
| 191 | `345909a` | 2026-10-24 22:24 | Wave 15 | Wave 15D: Strum to tune joins the store set, one consistent seed (7-day streak, lit flame, level 5) for every capture, captures wait for the screen to settle, listing age-rating answers and privacy URL TODO |
| 192 | `2fc4124` | 2026-10-24 22:25 | Wave 15 | WIP wave 15 (teams working) |
| 193 | `497effa` | 2026-10-24 22:25 | Wave 15 | Wave 15B: one neck-view setting (Chart default, Player view opt-in) drives every chord picture, neck, strum stage and Settings; no mirrored chords between screens |
| 194 | `e32dbf9` | 2026-10-24 22:32 | Wave 15 | Wave 15 complete: real sampled instruments (piano, bass, drums, guitar, violin, cello, harp, winds; 10 MB CC0, lazy-loaded) for Hear it and the band; spaced review (SM-2) in Today; Game Center challenges, song leaderboards and friend streaks; Songs tab above the fold with a consistent cover grid; iPad tuner side pane and richer ear training; runway lanes agree with chord pictures |
| 195 | `820edf8` | 2026-10-24 23:01 | Wave 15 | Keep Timbre 4+: Drunken Sailor replaced by Bobby Shafto, Wenceslas sings verses without wine, Riverside's peace verse, six original lyric tweaks; the pitch game is now Bullseye (badges High Scorer, Round Winner) so nothing borrows shooting words; listing age-rating answers |
| 196 | `6e1b0d7` | 2026-10-25 00:18 | Wave 16 | WIP wave 16: strum stage always Player view, tune check reads "Tune up" without borrowing a step number (lessons and chart practice) |
| 197 | `7fe1e18` | 2026-10-25 00:23 | Wave 16 | WIP wave 16: Today plan pinned for the day, clearer Progress and Today labels |
| 198 | `a07a279` | 2026-10-25 00:32 | Wave 16 | WIP wave 16: adult-first Songs shelves with a Campfire & kids shelf, 24 sleeve motifs split Originals/other, seamless song-sheet backdrop, Timbre Originals credit |
| 199 | `6442cf0` | 2026-10-25 00:32 | Wave 16 | WIP wave 16: in-progress team edits |
| 200 | `f5b6406` | 2026-10-25 00:33 | Wave 16 | WIP wave 16: final play-along gates the stars (coach agrees), results burst never clipped, Kite Weather perform scene for store #2, iPad instrument browser full page; Highway uses the shared take thresholds |
| 201 | `2ca73a6` | 2026-10-25 00:35 | Wave 16 | WIP wave 16: onboarding paywall with a drifting rail of the plan's songs, live catalog proof line and three outcomes; placement reads as a skip ahead |
| 202 | `4c94e78` | 2026-10-25 00:37 | Wave 16 | WIP wave 16: live mini previews on Play tool tiles, drone breathes and auto-listens with permission, ear-training notes rise behind a veil |
| 203 | `6721699` | 2026-10-25 00:38 | Wave 16 | WIP wave 16: in-progress Show me and audio edits |
| 204 | `73e7ac5` | 2026-10-25 00:39 | Wave 16 | WIP wave 16: in-progress Show me and audio edits [skip ci] |
| 205 | `51e9381` | 2026-10-25 00:48 | Wave 16 | WIP wave 16: Show me — chords, notes and strums demonstrated on the 3D neck (equal-temperament frets from the rig, fingertips in order, strings ring, pick sweeps), shared model cache, 2D fallback [skip ci] |
| 206 | `3d7e0ce` | 2026-10-25 01:11 | Wave 16 | Wave 16: sampled Martin flat-top guitar with strum feel, ukulele and mandolin stand-ins, band electric guitar and fuller kit, genre-aware grooves for the Originals |
| 207 | `1e924f4` | 2026-10-25 01:13 | Wave 16 | Song collections are a library: every free Originals, Standards and Songs track opens without finishing the one before (challenges keep their order); iPad browser frame checks the tuner is covered, not gone |
| 208 | `2506a24` | 2026-10-25 01:17 | Wave 16 | BandGroove: explicit types in the compound-meter closures (type-check timeout) |
| 209 | `21f719c` | 2026-10-25 02:01 | Wave 16 | test10: hands off until the play-along's last note has landed (the first query fell on it and cost frame #6 its third star) |
| 210 | `80e88f9` | 2026-10-25 02:03 | Wave 16 | song-perform scene: start the clock a bar before the take's first live note, so the jump's first heavy frames never cost misses (store #2 showed combo 6 with 4 misses) |
| 211 | `dbd59b0` | 2026-10-25 02:29 | Wave 16 | Show me on strum steps before the take (3D pick sweeps the pattern), Chords tool remembers the last chord and the Play tile strums it [skip ci] |
| 212 | `5d2a9f8` | 2026-10-25 02:45 | Wave 16 | Demo play-alongs are judged when each note was due to sound, not when a stalled simulator frame reached it (store #2 kept losing its combo to late frames) |
| 213 | `430e833` | 2026-10-25 02:45 | Wave 16 | WIP: guitar units 17+ in progress [skip ci] |
| 214 | `987fa50` | 2026-10-25 02:53 | Wave 16 | Curriculum: guitar units 17–22 (CAGED, triads, seventh and jazz voicings, the major scale in position, expressive lead, song form and arranging) and ukulele units 7–10 (new keys, strum styles, fingerpicking and chord melody, campfire to stage): 617 lessons, 159 songs [skip ci] |
| 215 | `12f93c1` | 2026-10-25 02:54 | Wave 16 | Placement: pro ukulele players start at the new Unit 7 [skip ci] |
| 216 | `3b0e47c` | 2026-10-25 03:27 | Wave 16 | test10: let the quiz finish sliding in before answering it (a mid-slide tap picked D, costing frame #6 its third star) |
| 217 | `ea6c80e` | 2026-10-25 04:32 | Wave 17 | WIP wave 17: Play hub shows each task once, onboarding Great work without a gap, drone label clear of the strings, app-style segmented controls on ear training, drone, scales and the metronome sound [skip ci] |
| 218 | `a249514` | 2026-10-25 04:41 | Wave 17 | WIP wave 17: Show me plays by itself the first time a chord or strum appears in a course (caption says what to watch), one step title in outline and player, notes burst clear of the labels; timed demo runs keep their pacing [skip ci] |
| 219 | `09ba527` | 2026-10-25 04:41 | Wave 17 | WIP wave 17: in-progress team edits [skip ci] |
| 220 | `544c576` | 2026-10-25 04:43 | Wave 17 | WIP wave 17: paywall rail leads with three Originals, untitled sleeves never meet the headline, one icon language, reason paywalls sell their reason on day 2 [skip ci] |
| 221 | `0ab44fc` | 2026-10-25 04:43 | Wave 17 | WIP wave 17: in-progress team edits [skip ci] |
| 222 | `d6e012c` | 2026-10-25 04:44 | Wave 17 | WIP wave 17: iPad full-screen captures (no resize arc), browser frame on the folk-strings shelf, Learn rail fades at its column edge, Play level tile with your week and next badge, Up next fills four rows, Originals numbered without a gap [skip ci] |
| 223 | `44e699b` | 2026-10-25 04:45 | Wave 17 | WIP wave 17: instrument cards re-rendered under the live stage's lights and IBL (one guitar everywhere), Show me store frame and probe, results fit above the fold, still score in the store scene, motif-only small sleeves, chip progress as a fill [skip ci] |
| 224 | `66243fa` | 2026-10-25 04:54 | Wave 17 | Curriculum: a Song spotlight in every guitar unit 2–22, each a different Timbre Original practising the unit's skill (riff, strum, lead part, play-along): 638 lessons, guitar 153 [skip ci] |
| 225 | `8a15362` | 2026-10-25 04:54 | Wave 17 | WIP wave 17: in-progress team edits [skip ci] |
| 226 | `c0ae634` | 2026-10-25 04:55 | Wave 17 | Translator handoff: per-locale TODO files with context and length hints, stale-key tracking, report/import tooling and a warning-only CI summary (docs/l10n/HANDOFF.md) [skip ci] |
| 227 | `6545599` | 2026-10-25 04:56 | Wave 17 | Wave 17 complete: violin/viola/cello pegs wound as on a real pegbox (outer strings nearest the nut), turn signs for 37 photographed instruments, Pluck all on bowed instruments, Tighten/Loosen alone, chromatic and iPad landscape framing clear of the controls |
| 228 | `69a0341` | 2026-10-25 04:57 | Wave 17 | Violin and cello cards re-rendered with the corrected peg routing [skip ci] |
| 229 | `8292c76` | 2026-10-25 05:48 | Wave 17 | iPad CI: prove an app launches in Full Screen Apps before the run, else return to the default mode (the UI test's launch hung after the switch) |
| 230 | `98c208f` | 2026-10-25 06:09 | Wave 17 | Show me: the stage warms up drawing behind the picture and reveals with it in one move (no frozen first frame), names fade with the scene, probes report what the card shows; chord step box bottom-aligned [skip ci] |
| 231 | `5111d1f` | 2026-10-25 06:34 | Wave 17 | iPad CI: 45-minute budget (the run finished its captures and ran out at 25 with the Full Screen Apps reboot) |
| 232 | `5f9b699` | 2026-10-25 07:12 | Wave 17 | Renaissance lute and glockenspiel photos cut out of their black backdrops (they showed as black squares on the instrument cards) [skip ci] |
| 233 | `7c8d46c` | 2026-10-25 07:13 | Wave 17 | iPad browser frame: scroll against the screen in the interface's orientation (a portrait app.frame put the target line off screen), with a diagnostic when the shelf isn't whole |
| 234 | `da3ae69` | 2026-10-25 07:56 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 235 | `076c589` | 2026-10-25 08:04 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 236 | `f091a6a` | 2026-10-25 08:14 | Wave 18 | WP1b: one audio-session owner, haptics while recording, recovery from route/config changes and interruptions, CurriculumStore decoded off the main thread, cached streak, side-effect-free dailySet, tuner frame hook [skip ci] |
| 237 | `4fa977a` | 2026-10-25 08:15 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 238 | `0785642` | 2026-10-25 08:23 | Wave 18 | WP10 day 1: agent scratch files and stale self-audits removed, a CI gate against review/bug/WIP references in code (baseline only shrinks), SwiftLint/SwiftFormat config reporting, critical-string localisation check (blocks delivery), string-catalog groundwork, Info.plist keys for links and remote config, accessibility audit UI tests [skip ci] |
| 239 | `0f95982` | 2026-10-25 08:23 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 240 | `a55e2e6` | 2026-10-25 08:27 | Wave 18 | WP1a: lenient settings decoding with new shared fields, crash-proof state (backup, quarantine, clamped repair, recovery notice), phone language by default with one cached localization bundle, Pro kept in billing grace with a billing-issue banner, every instrument's standard tuning free, StoreKit and localization launch tests [skip ci] |
| 241 | `c78f576` | 2026-10-25 08:27 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 242 | `a4f5d0e` | 2026-10-25 08:28 | Wave 18 | WP8: design system pass — 8-step type scale, Bold Text in Sora, status colours only for status, mint flat primary buttons, bare and custom glyphs instead of tinted-circle icons, section-level capitals, matched tab symbols (Play → Practice), billing banner mounted, Settings handedness and feel rows, Large Content Viewer and Smart Invert exemptions [skip ci] |
| 243 | `98281ec` | 2026-10-25 08:28 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 244 | `391778f` | 2026-10-25 08:31 | Wave 18 | WP2 and WP7: analytics funnel and remote config, first chord before the paywall, two-plan onboarding paywall with honest song count and share links; tune by feel, the instrument's own strings at the finale, stars ringing in key, harmonic bursts, spoken note names, lenient progress decoding [skip ci] |
| 245 | `5b1ed03` | 2026-10-25 08:31 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 246 | `989f493` | 2026-10-25 08:32 | Wave 18 | WP6: shared play-along session with chord-aware grading, a band that follows the song's chart and the player, VoiceOver play-along with spoken next notes and cues, Chords & words mode, colour-blind-safe lanes, still HUD digits in the store scene [skip ci] |
| 247 | `8084596` | 2026-10-25 08:32 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 248 | `d47eff0` | 2026-10-25 08:36 | Wave 18 | WP9: left-handed everywhere (mirrored chord boxes, necks, lanes, Show me and the 3D stage, with words unmirrored; upside-down mode), capo drawn, clean Show me string glow, 3D rest and Low Power fallbacks, celebrate roll lights the 3D strings, scales view with one View menu [skip ci] |
| 249 | `12c41a7` | 2026-10-25 08:36 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 250 | `ea9f65b` | 2026-10-25 08:37 | Wave 18 | WP4: strum and progression steps check each stroke's chord, the chord step names the string that isn't ringing, banjo D7 fixed, spoken tune check, VoiceOver focus on each step, pedal and keyboard control, lesson Siri shortcut, real-recording test harness [skip ci] |
| 251 | `2164b69` | 2026-10-25 08:37 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 252 | `2d8f726` | 2026-10-25 08:39 | Wave 18 | Integration: usage-sharing switch (on until the player chooses) applied before analytics starts, so an opt-out also stops the Ads attribution request; friend offer and share links with routes; chromatic stand-in removed; sound motif on welcome and Pro unlock; Feel test plays tune-by-feel; hygiene baseline 272 → 155 [skip ci] |
| 253 | `19fbb91` | 2026-10-25 08:39 | Wave 18 | WIP wave 18: in-progress team edits [skip ci] |
| 254 | `85968e5` | 2026-10-25 08:51 | Wave 18 | WP3: App Preview cut on the beat with the app's own sound, captions and an end card; art-directed store screenshots (one composition per frame, violin page, localized rendering); new store scenes; listing copy, Custom Product Page tables and delivery docs; robust iPad browser frame [skip ci] |
| 255 | `9c749fe` | 2026-10-25 09:45 | Wave 18 | Wave 18 complete: catalogue and free tier (songbooks for ukulele, mandolin and violin, 20 more public-domain standards, 132 tunings, free open chords, capo, eighths and triplets, one custom tuning, ten charts), Bullseye without shooting language; honest counts everywhere (518 teaching lessons in 11 courses, 140+ songs by title); chord practice free in Today |
| 256 | `7b80620` | 2026-10-25 09:49 | Wave 18 | Bullseye: explicit CGFloat for the marker's position (ambiguous cos) |
| 257 | `543192c` | 2026-10-25 10:49 | Wave 18 | Lesson buttons carry their identifier on the button itself, so the hidden key buttons behind them (space, arrows, pedal) never share it; the instrument-wall test finds the folk chip from a snapshot; the settings round trip covers the usage-sharing choice |
| 258 | `e74c390` | 2026-10-25 11:51 | Wave 18 | CI: 90-minute budget for the app job (the UI flows passed and the archive ran out at 60) |
| 259 | `eb6ee5c` | 2026-10-25 11:52 | Wave 18 | Note names keep their octave on the right in right-to-left languages (Arabic showed ₂E) [skip ci] |
| 260 | `536b9c2` | 2026-10-25 12:53 | Wave 18 | Ignore local agent worktrees |
| 261 | `bb6a22e` | 2026-10-25 13:05 | Wave 19 | Day-1 contracts for wave 19: muted and accented beats on strum and progression steps, band bar segments and a kit-only switch, scheduled spoken cues, planCourse(forGoal:) and debounced settings writes, TestSupport.isAutomated, accentNeutral, a docked reward toast, ReferralPill and the after-song review prompt, freeSongs and unit2Free remote keys, Curriculum.distinctTuneCount |
| 262 | `b2af55a` | 2026-10-25 13:37 | Wave 19 | Design system, app shell and rewards: docked reward toast, colour roles, a real Calm mode, one streak lamp |
| 263 | `4d826e2` | 2026-10-25 13:37 | Wave 19 | Tuner: a lock that holds on screen, Tune by feel on the tuner, whole heads in every close-up |
| 264 | `e1c2520` | 2026-10-25 13:37 | Wave 19 | Merge WP9: design system, app shell and rewards |
| 265 | `12bb53d` | 2026-10-25 13:38 | Wave 19 | Merge WP3: a lock that holds and a feel you can find |
| 266 | `2319909` | 2026-10-25 13:39 | Wave 19 | Feature-scoped tuner state, background persistence and test hooks out of release paths |
| 267 | `f83c27d` | 2026-10-25 13:41 | Wave 19 | Merge WP10: platform and architecture |
| 268 | `f824a90` | 2026-10-25 13:42 | Wave 19 | Play-along reads fingers on fingerboards, songs play and judge every chord change |
| 269 | `5dca1c3` | 2026-10-25 13:42 | Wave 19 | Merge WP7: songs, play-along, Show me |
| 270 | `94da7e9` | 2026-10-25 13:45 | Wave 19 | Audio: a speaker kit band, chord changes inside a bar, ambient UI sounds, timed spoken cues |
| 271 | `ce77ff0` | 2026-10-25 13:46 | Wave 19 | Merge WP8: audio engine and band |
| 272 | `0d0f4b0` | 2026-10-25 13:46 | Wave 19 | Paywall and first session tell the truth: a free first song, a Free/Pro table built from the policy, working price levers |
| 273 | `077b5c0` | 2026-10-25 13:46 | Wave 19 | Merge WP4: paywall and first session |
| 274 | `face00c` | 2026-10-25 13:47 | Wave 19 | Grade muted, accented and ninth-chord strokes correctly; speak the next note in the notes step; feed recordings through the live analysis path |
| 275 | `e10e4b3` | 2026-10-25 13:48 | Wave 19 | Merge WP6: listening correctness |
| 276 | `7a09206` | 2026-10-25 13:52 | Wave 19 | Lesson gets a public init, so app tests can build a lesson |
| 277 | `99a553c` | 2026-10-25 13:54 | Wave 19 | App Preview gates, event-anchored lock sync, store-frame crops and a keyword plan App Store Connect accepts |
| 278 | `4fe4432` | 2026-10-25 13:55 | Wave 19 | Release gate, localization gate and CI: a 15-minute required gate, nightly captures, strict App Store translation gate |
| 279 | `01a23dd` | 2026-10-25 13:55 | Wave 19 | Merge WP2: store creative and preview |
| 280 | `6b38b27` | 2026-10-25 13:55 | Wave 19 | Merge WP1: release gate and CI |
| 281 | `de4875e` | 2026-10-25 13:56 | Wave 19 | Localization report and critical-string baseline after the wave-19 merges |
| 282 | `c46c452` | 2026-10-25 13:56 | Wave 19 | Songbooks and first songs: free unit-1 songs, corrected ukulele keys, cello and bass songbooks, Songs you know shelf |
| 283 | `b2aafe7` | 2026-10-25 13:57 | Wave 19 | Merge WP5: content correctness |
| 284 | `63f73bd` | 2026-10-25 13:58 | Wave 19 | Counts after the first songs (526 lessons, cello and bass songbooks), localization report and baseline |
| 285 | `3be9da4` | 2026-10-25 14:31 | Wave 19 | Gate fixes: module cache key without hashFiles, Release-only analytics ID path, wrapped step coding, chord bar line by reduce, band style test skips cues two songs share |
| 286 | `2b78d1e` | 2026-10-25 14:42 | Wave 19 | Tuner, settings, onboarding, commerce and Learn shell take the wave-19 shared pieces |
| 287 | `0170b42` | 2026-10-25 14:43 | Wave 19 | Merge integration A: tuner, settings, onboarding, commerce |
| 288 | `8580079` | 2026-10-25 14:45 | Wave 19 | Platform integration: resting stage for audits, neutral Today arcs on the watch, tune count by tune, capture waits |
| 289 | `8f11ae9` | 2026-10-25 14:45 | Wave 19 | Merge integration D: platform, stage, watch, widgets, UI tests |
| 290 | `9628967` | 2026-10-25 14:47 | Wave 19 | Smoke purchase test starts from a clean StoreKit test session |
| 291 | `e7dcdfd` | 2026-10-25 14:50 | Wave 19 | Lessons, songs and play-along integration: one cue path, fingers on fingerboards, a truthful band chip |
| 292 | `60fe2b1` | 2026-10-25 14:51 | Wave 19 | Merge integration B: lessons, songs, play-along |
| 293 | `3fa41ca` | 2026-10-25 14:51 | Wave 19 | Audio, practice and demo scenes: demo pitch survives interruptions, recordings into lesson analysers, welcome and wobble sounds, Calm practice hub, interval legend, Band parameter structs |
| 294 | `0e4f24f` | 2026-10-25 14:52 | Wave 19 | Localization handoff for the band chip string; SwiftLint empty_count fixes |
| 295 | `ee12f4d` | 2026-10-25 14:52 | Wave 19 | Merge integration C: audio, practice, demo scenes |
| 296 | `62a7508` | 2026-10-25 14:53 | Wave 19 | Integration follow-ups: welcome motif through the ambient session, dead-string capture hook, demo clip and preview motif as TestSupport keys, unused per-note cue API removed, neutral watch tints, hygiene baseline 450 → 96 |
| 297 | `d031914` | 2026-10-25 15:36 | Wave 19 | Gate fixes: localization handoff, empty_count and shorthand lint, Just tune link clear of the mint button's glow |
| 298 | `0bb161f` | 2026-10-25 15:53 | Wave 19 | UI tour loads and empties the StoreKit test configuration itself; onboarding capture picks the violin chip |
| 299 | `f87f052` | 2026-10-25 15:55 | Wave 19 | Audio: a superseded microphone start no longer lets the session go under the next one; one quiet retry before the alert |
| 300 | `0da2ed9` | 2026-10-25 15:55 | Wave 19 | Merge audio: a called-off tuner start no longer gives up the session a newer start holds; one quiet retry before the alert |
| 301 | `5e4a3c1` | 2026-10-25 15:57 | Wave 19 | Translation handoff check ignores moved line numbers; handoff refreshed |
| 302 | `9c3d22f` | 2026-10-25 16:25 | Wave 19 | Song take clock after the click starts, a still HUD in the store scene, the AX5 tuner's Settings reachable, launch-proof accessibility job |
| 303 | `0bbf273` | 2026-10-25 16:25 | Wave 19 | Merge QA: scene takes start the click before the clock, still HUD in store scenes, accessibility job warm-up and launch retry, AX5 tuner column fits, Arabic octave test on the demo pitch |

---

## Appendix B: the review and brief files

All in the orchestrator's scratchpad (`…/scratchpad/polish/`), not in the repository. Times are −03:00.

| File | Written | What it is | Score |
|---|---|---|---:|
| `REVIEW3.md` | 10-23 09:25 | Round 3, independent review, items for wave 3 | 6.9 |
| `REVIEW4.md` | 10-23 11:52 | Round 4, items for wave 5 | 7.8 |
| `REVIEW5.md` | 10-23 14:35 | Round 5, items for wave 6 | 7.5 |
| `REVIEW6.md` | 10-23 16:36 | Round 6, items for wave 7 | 7.7 |
| `REVIEW7.md` | 10-23 18:49 | Round 7, area scores, ranked changes, bugs | 7.9 |
| `REVIEW8.md` | 10-24 04:57 | Round 8, "fixed since round 7", ranked, bugs | 8.1 |
| `PREAMBLE.md` | 10-24 05:05 | Rules every agent reads first | — |
| `REVIEW9.md` | 10-24 12:47 | Round 9 | 8.6 |
| `REVIEW10.md` | 10-24 14:23 | Round 10, design director and App Store growth lead | 8.1 |
| `QA10.md` | 10-24 14:27 | Pre-release code audit at `55f87c1` (1 critical, 4 high, 16 medium) | — |
| `REVIEW11.md` | 10-24 17:35 | Round 11, 71 screenshots plus code | 8.4 |
| `DESIGN11.md` | 10-24 18:34 | Design-system and accessibility audit, batches A–F, API contract | — |
| `REVIEW12.md` | 10-24 22:05 | Round 12 ("independent, strict") | 8.4 |
| `REVIEW13.md` | 10-25 00:12 | Round 13 ("jury pass") | 8.7 |
| `REVIEW14.md` | 10-25 04:18 | Round 14 ("jury pass") | 8.9 |
| `JURY_BRIEF.md` | 10-25 05:50 | Jury brief, round 15 | — |
| `JURY15-delight.md`, `-inclusivity`, `-growth`, `-category`, `-technical`, `-visual` | 10-25 07:26–07:36 | Six juror verdicts, round 15 | 8.3, 8.3, 7.4, 7.8, 8.1, 8.6 |
| `REVIEW15.md` | 10-25 07:53 | Foreman, round 15: scoreboard, blockers, WP1–WP10, owner decisions, what not to do, verification log | 7.7 |
| `JURY16_BRIEF.md` | 10-25 11:53 | Jury brief, round 16 | — |
| `JURY16-technical.md`, `-growth`, `-inclusivity`, `-visual`, `-category`, `-delight` | 10-25 12:26–12:33 | Six juror verdicts, round 16 | 8.5, 8.1, 8.7, 8.8, 8.3, 8.7 |
| `REVIEW16.md` | 10-25 12:52 | Foreman, round 16: blockers B1–B11, WP1–WP10 for wave 19 | 8.3 |
| `TEAM19.md` | 10-25 13:05 | Wave-19 team brief (worktrees, one commit, no WIP) | — |
| `CONTRACTS19.md` | 10-25 13:05 | Wave-19 day-1 contracts | — |
| `INTEGRATION19_BRIEF.md` | 10-25 14:31 | Integration groups A–D | — |
| `JURY17_BRIEF.md` | 10-25 15:37 | Jury brief, round 17 (adds the CI result branches) | — |
| `INTEGRATION19.md` | 10-25 16:26 | Cross-team requests per package, integration leftovers, post-integration notes | — |

---

## Appendix C: glossary

- **Round N:** a review of the build after a wave; rounds 3–14 by one independent reviewer (rounds 1–2 left no file), rounds 15–17 by a jury of six plus a foreman.
- **Wave N:** the work that answered a round. Rounds 1–3 were answered by waves 1–3; wave 4 was a content wave of its own; rounds 4–9 by waves 5–10; round 10 (with `QA10.md`) by waves 11–12; round 11 by wave 13 and the `DESIGN11.md` audit by wave 14; rounds 12–16 by waves 15–19.
- **WP1–WP10:** the jury foreman's file-disjoint work packages (waves 18 and 19). Numbers mean different things in the two waves.
- **Day-1 contracts:** shared APIs landed before parallel teams branch, so they can build against each other without seeing each other's code (`bb6a22e`).
- **Store frame #1–#9:** the App Store screenshot slots (iPhone; iPad #1–#4). **Capture numbers** (07, 10b, 52b, 62, 65 …) are UI-test screenshot names (10b = the tuner locked, 52b = the chord step, 62 = lesson results, 65 = the *Kite Weather* performance).
- **`TIMBRE_SCENE`, demo pitch, `TestSupport`:** DEBUG-only launch keys that render a store scene deterministically or feed the tuner a synthetic pitch; release builds read none of them.
- **Studio Noir:** the design language (dark stage, mint, amber/gold, Sora).
- **Show me:** 3D demonstrations of chords, notes and strums on the instrument's own neck.
- **Tune by feel:** haptic pulses at the beat frequency between a string and its target, still at the lock.
- **Strum to tune:** the polyphonic tuner that reads every string from one strum.
- **Placement pass:** the first lesson of the unit onboarding places a player in, free on the free plan.
- **Originals:** songs written for Timbre; **Standards & Classics:** worldwide-public-domain songs with a rights table; **songbooks:** per-instrument editions of the chord songs.
- **Weakest-link gate:** the foreman's rule that averages the weighted mean of the six angles with the lowest one.
