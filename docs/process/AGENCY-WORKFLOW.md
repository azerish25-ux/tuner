# How Timbre was developed: the agency workflow

This is the operating manual for continuing Timbre the way it has been built so far: one **orchestrator** running
departments of AI agents (or people) in waves, a **gate** on GitHub Actions as the compiler and test bench, and a
**jury** that scores each round as harshly as an Apple Design Awards panel and says what it would take to be #1.
Everything below is what was actually done, including the mistakes worth not repeating.

- Start-here for the whole project: [docs/HANDOVER.md](../HANDOVER.md)
- History of every round and wave: [docs/history/DEVELOPMENT-HISTORY.md](../history/DEVELOPMENT-HISTORY.md)
- Every commit with its message: [docs/history/COMMIT-LOG.md](../history/COMMIT-LOG.md)
- Archived reviews, jury verdicts and briefs: [docs/process/archive/](archive/) and [docs/process/templates/](templates/)

## Contents

1. [The goal and the bar](#1-the-goal-and-the-bar)
2. [Roles](#2-roles)
3. [House rules (non-negotiable)](#3-house-rules-non-negotiable)
4. [Branches and what each one is for](#4-branches-and-what-each-one-is-for)
5. [The round loop, step by step](#5-the-round-loop-step-by-step)
6. [Writing a work package and a team brief](#6-writing-a-work-package-and-a-team-brief)
7. [Merging, conflicts and the integration pass](#7-merging-conflicts-and-the-integration-pass)
8. [Reading CI from a machine without a Mac](#8-reading-ci-from-a-machine-without-a-mac)
9. [The jury](#9-the-jury)
10. [Tools made for the orchestrator](#10-tools-made-for-the-orchestrator)
11. [Lessons learned (gotchas)](#11-lessons-learned-gotchas)
12. [Running round 17 from here](#12-running-round-17-from-here)
13. [Timings](#13-timings)

---

## 1. The goal and the bar

The owner's standing brief, in his words and in substance:

- Run development "like an app development agency with different departments of sub workers and sub agents".
- Quality "as if $800k was spent" on design, content and features; it must look like a company's team built it and
  stay as far as possible from anything that reads as vibe-coded, templated or AI-generated.
- Take the **#1 spot on all angles** against GuitarTuna, Fender Tune and Fender Play, Yousician, Simply Guitar and
  JustinGuitar (Ultimate Guitar where relevant): be clearly more appealing and more viable for an ordinary user.
- Be judged by "extremely harsh and judgy and realistic jurors of Apple Design Awards", who also give the tips to reach
  #1. Target score: **9.5/10**.
- Earn **$10k a month** on the App Store.
- All macOS work runs on GitHub Actions (no local Mac is assumed).
- Translations are done by other people (see [docs/l10n/](../l10n/)); agents write English only.
- Violin and cello tuning are free; song licensing is worked around with public-domain songs and the app's own
  Originals until licences are bought.

Where it stands on 2026-10-25: jury round 16 scored **8.3** overall (visual 8.8, delight 8.7, inclusivity 8.7,
technical 8.5, growth 8.1, category 8.3); wave 19 and its integration pass shipped against that review afterwards.
The foreman's estimate was that code alone tops out around 8.7 and that 9.0–9.1 needs the owner items in
[docs/OWNER-ACTIONS.md](../OWNER-ACTIONS.md). #1 on every angle needs licensed songs, real recordings and human design
work, not more code.

## 2. Roles

| Role | Who | Does | Never does |
|---|---|---|---|
| **Owner** | the human | sets goals, approves money and accounts, adds secrets in GitHub, authorizes App Store delivery, reviews before `main` | pastes secrets into chat |
| **Orchestrator** | the main session | turns reviews into work packages, writes briefs and contracts, launches teams, merges, resolves conflicts, runs CI and reads results, fixes what falls between teams, reports to the owner | writes large features itself while teams are working on the same files |
| **Work-package team** | one agent per package, in its own git worktree | changes only the files its package owns; one commit; a report with compile doubts and requests for other packages | pushes, touches other packages' files, edits translations |
| **Integration agent** | one per file group after a wave | carries out the cross-package requests the teams left, file-disjoint from each other | starts new features |
| **Specialist** | an agent with one problem (audio engineer, QA engineer, release manager, technical writer) | root-causes and fixes one class of failure with evidence | widens scope |
| **Juror** (×6) | one agent per angle: visual, delight, inclusivity, technical, growth, category | scores its angle 0–10 from screenshots, the App Preview and the code, head-to-head against competitors, with ranked defects and "how to take #1" tips | edits code |
| **Foreman** | one agent after the jurors | verifies every blocker the jurors claim, writes the round's consolidated review (overall score, blockers, file-disjoint work packages with acceptance criteria, rules for teams, owner list) | trusts a juror's claim it didn't verify |

## 3. House rules (non-negotiable)

These came from the owner or from things that went wrong. Keep them.

1. **Secrets.** Never paste passwords, certificates, API keys or tokens into chat or commits. The owner adds them to
   GitHub (the protected `apple-delivery` environment, repository secrets). Third-party tokens (e.g. Sketchfab) are
   never pasted either.
2. **Apple delivery.** Never dispatch `.github/workflows/apple-delivery.yml` without the owner's explicit
   authorization for that run.
3. **`main`.** Nothing reaches `main` without the owner's review/instruction. Work happens on the working branch
   (`v2/foundations`, PR #2) and side branches.
4. **Force-push** only side branches (`preview/*`, `cards/*`, `l10n/*`, `stage/*`, `docs/*`, `convert/*`), never the
   working branch or `main`.
5. **Commit attribution.** Commits made by agents end with:
   ```
   Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
   Claude-Session: <session URL>
   ```
   Pull request descriptions end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)` and the session URL.
6. **No `[skip ci]` commits that touch `ios/`.** `tools/ci/skip_ci_guard.py` fails the core job on new ones
   (earlier ones are grandfathered in `tools/ci/skip-ci-grandfathered.txt`). Side-branch triggers that need a skip use
   `git commit-tree` on the side branch only.
7. **English only from agents.** Text literals are localization keys; agents never edit `.lproj` files or
   `tools/l10n/translations`. They run `python3 tools/l10n/report.py` after adding strings so the translators' handoff
   stays current (the gate checks it).
8. **No local Swift compiler** in the agent environment: CI is the compiler. Every agent verifies each API it uses
   against the code and Apple's docs and lists its "compile doubts" in its report.
9. **The owner's working preferences** (applied to every session): answer first, concise, no filler, keep technical
   facts ("Caveman"); for code: understand the root cause first, reuse existing code and platform features, build only
   what is asked with the smallest correct change, keep validation, error handling, security and accessibility
   ("Ponytail").
10. **Leave the tree pushed.** A stop hook in the agent environment refuses to end a turn with uncommitted or unpushed
    work on the current branch. When a push to the working branch would cancel a CI run you are waiting on, commit to
    a side branch (`stage/…`) and push that instead; fast-forward the working branch later.

The agent preamble every team reads first is in [templates/AGENT-PREAMBLE.md](templates/AGENT-PREAMBLE.md).

## 4. Branches and what each one is for

| Branch | Purpose | Triggers |
|---|---|---|
| `main` | released code; owner-reviewed | `iOS` workflow on push |
| `v2/foundations` | the working branch (PR #2 → `main`) | `iOS` gate and, with the `captures` label on PR #2, the nightly tour on every push |
| `stage/*` | orchestrator's holding branch while a CI run on the working branch must not be cancelled | nothing |
| `docs/*` | documentation work | nothing |
| `preview/run1` | force-push any commit here to render the App Preview (`preview.yml`) | `App Preview` |
| `cards/*` | RealityKit studio card renders (`cards.yml`) | `cards` |
| `convert/*` | Blender 3D asset builds and conversions (`assets.yml`) | `3D assets` |
| `l10n/*` | translation runs (`l10n.yml`) | `l10n` |
| `ci-results/*` | **published results** of every workflow (logs, screenshots, manifests) | written by CI only |
| `worktree-agent-*` | local branches of agent worktrees (never pushed) | — |

Results branches you will read most: `ci-results/core`, `ci-results/gate` (app unit tests and smoke flows),
`ci-results/release`, `ci-results/accessibility`, `ci-results/app` (nightly tour + App Store captures),
`ci-results/ipad`, `ci-results/a11y-matrix`, `ci-results/preview` and `ci-results/preview-violin`.

## 5. The round loop, step by step

One **round** = capture → jury → foreman → wave → integration → green CI → capture again.

### 5.1 Capture

1. Make sure PR #2 has the `captures` label, push the commit to judge to `v2/foundations`, and wait for the
   `Nightly and captures` run (tour ≈ 60–80 min, iPad ≈ 20 min). Don't push again meanwhile: every push cancels it.
2. Render the App Preview: `git push -f origin <sha>:refs/heads/preview/run1` (≈ 40 min, guitar and violin cuts).
3. Collect everything under readable names for the jury:
   ```sh
   REPO=$PWD python3 tools/agency/collect_review.py "$WORK/review17" app ipad
   git fetch -q origin ci-results/preview && git archive origin/ci-results/preview | tar -x -C "$WORK/review17/preview"
   ```
   Frames ending `-wrong` were rejected by their own test (a capture check failed); `zz-failure-*` are teardown
   pictures of failing tests.

### 5.2 Jury (six parallel agents)

Fill [templates/JURY-BRIEF-round17-READY.md](templates/JURY-BRIEF-round17-READY.md) (replace `$WORK` and `$REPO`) and
launch six agents, one per role, each told its role name and to write `JURY<n>-<role>.md`. Each must open the
screenshots that matter to its angle, read code to verify behaviour it can't see, web-search competitors, and return a
score, a head-to-head per competitor, ranked defects (severity, size, screen/`file:line`, fix), "how to take #1" tips,
owner-only items and sources. Calibration is in the brief: 9.5 = ADA finalist on that angle; 9.0 = excellent but loses
to a named competitor somewhere; 8.0 = good with visible seams; below 7 = amateur. **Do not round up.**

### 5.3 Foreman

One agent reads the six verdicts, **verifies every blocker** in the code or screenshots (jurors are sometimes wrong),
and writes `REVIEW<n>.md`: the overall score, verified blockers, a ranked list, and **8–10 file-disjoint work
packages** (each: owner files, acceptance criteria, what not to touch), rules for all teams, a "what not to do"
section, and the owner-only list with costs. See [archive/REVIEW16.md](archive/REVIEW16.md) for the shape.

### 5.4 Day-1 contracts

Before launching teams, the orchestrator commits the **shared interfaces** every team builds against (new model
fields, enum cases, function signatures, test hooks, design tokens) with stub implementations, so ten teams working
blind can compile against the same API. Record them in a `CONTRACTS<n>.md` ([archive/CONTRACTS19.md](archive/CONTRACTS19.md))
and push that commit first. Each team's worktree must start from this commit.

### 5.5 Teams

Launch one agent per work package **with worktree isolation** and the team brief
([templates/TEAM-BRIEF-wave19.md](templates/TEAM-BRIEF-wave19.md)): read the preamble, the foreman's review (context,
rules, its own package in full, what not to do), the contracts; own only its files (unlisted Swift belongs to the
platform package, unlisted infra to the CI package); migrate off-scale type and status-colour misuse in its own files;
run `lint_tells.py`, `verify-ios-resources.py` and `curriculum/build.py --check`; finish with **one commit**, never
push; report branch, hash, per-file changes, acceptance checks, compile doubts and **requests for other packages**.

### 5.6 Merge, integrate, gate — see §7 and §8.

### 5.7 Report to the owner

After each merge batch and each CI result: one short status (what merged, what's red, what's next, any owner action).
The owner reads on a phone; no walls of text.

## 6. Writing a work package and a team brief

A good package:

- names its **files** (and only those), so ten packages never touch the same file;
- states **acceptance criteria** that someone can check from a screenshot, a test or code (e.g. "Twinkle shows and
  judges `C · G | D · G`", "a correct uke-8-1 take scores 100%");
- lists **requests it may make** instead of editing others' files (file, line, exact code);
- says what **not** to do (no new abstractions, no renamed identifiers the UI tests use, no new strings unless needed,
  no `.lproj` edits, no review/bug-number comments in code);
- assumes **no compiler**: keep SwiftUI expressions simple, split long bodies, mark main-actor helpers, avoid long
  mixed-type ternaries (type-checker timeouts), check every API's declaration.

Wave 19's ten packages, for reference: WP1 release gate and CI; WP2 store creative and App Preview; WP3 tuner lock and
feel; WP4 paywall and first session; WP5 content correctness; WP6 listening correctness; WP7 songs, play-along and Show
me; WP8 audio engine and band; WP9 design system, app shell and rewards; WP10 platform and architecture.

## 7. Merging, conflicts and the integration pass

1. **Merge as reports arrive**, one `git merge --no-ff worktree-agent-<id>` per team, with a clear merge message.
   After each: `python3 tools/ci/lint_tells.py`, `python3 tools/verify-ios-resources.py`, (curriculum touched)
   `python3 tools/curriculum/build.py --check`, (strings touched) `python3 tools/l10n/report.py`, (listing or counts
   touched) `python3 tools/marketing/screenshots.py --check`.
2. **Conflicts:** read both sides; keep the package that owns the file and port the other side's intent (wave 19:
   WP10's `TunerSession` lock path won over WP3's `recordLock`, keeping WP3's reward-after-save behaviour).
3. **Log every team's requests** in an `INTEGRATION<n>.md` ([archive/INTEGRATION19.md](archive/INTEGRATION19.md)).
4. **Integration pass:** group the requests by file ownership into 3–4 **disjoint** groups and launch one agent per
   group with [templates/INTEGRATION-BRIEF-wave19.md](templates/INTEGRATION-BRIEF-wave19.md). Each resets its
   worktree to the current working branch first. The orchestrator then does the leftovers that need two groups' files
   (e.g. wiring a new API into another group's view), shrinks the hygiene baseline
   (`lint_tells.py --update-baseline`) and refreshes the l10n handoff and critical baseline.
5. Update counts that marketing quotes (lessons, courses, songs) when content changes; `screenshots.py --check` fails
   on stale numbers in the listing.

## 8. Reading CI from a machine without a Mac

- Use `gh` with the **REST API** (GraphQL is blocked in the agent environment):
  `gh run list -b v2/foundations`, `gh run view <id> --json jobs`, and failure messages via
  `gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations`.
- **Job logs and artifacts are not downloadable** through the agent proxy (blob storage is blocked). Every workflow
  therefore publishes its results to a `ci-results/*` branch: `git fetch origin ci-results/<name>` then
  `git show FETCH_HEAD:<path>` (logs are gzipped: `| gunzip`). `screenshots/manifest.json` maps each exported file to
  its attachment name; `tools/agency/collect_review.py` does that mapping for you.
- `tools/agency/ciwait.sh <sha> [workflow]` waits for a run on a commit and prints job states plus the failure
  annotations (it exits early when the app build fails).
- Each push to the PR branch **cancels** in-flight runs of the same workflow (concurrency, cancel-in-progress). Batch
  your pushes; hold a side branch while you wait.
- Pull-request runs build the PR's merge commit, so `RUN.txt` in a results branch shows a merge SHA, not your commit.

## 9. The jury

- Six roles: **visual** (craft, type, colour, layout, motion stills, iPad), **delight** (moments, sound, haptics,
  rewards, innovation), **inclusivity** (VoiceOver, Dynamic Type, colour, left-handed, localization, cognitive load),
  **technical** (architecture, correctness, performance, tests, CI), **growth** (store page, onboarding, paywall,
  pricing, retention, analytics), **category** (tuner accuracy, lessons, songs, breadth vs competitors).
- Everything a juror claims must cite a screen or `file:line`. The foreman verifies blockers.
- The jurors' "how to take #1" lists from rounds 15 and 16 are summarised in the history; the full verdicts are in
  [archive/](archive/).
- The next round's brief is ready: [templates/JURY-BRIEF-round17-READY.md](templates/JURY-BRIEF-round17-READY.md).

## 10. Tools made for the orchestrator

| Tool | What it does |
|---|---|
| `tools/agency/ciwait.sh <sha> [workflow]` | waits for a workflow run on a commit; prints jobs and failure annotations |
| `tools/agency/collect_review.py <out> <results-branch>…` | copies a results branch's screenshots under readable names (`app`, `ipad`, `accessibility`, `gate`) |
| `tools/agency/commit-log.sh > docs/history/COMMIT-LOG.md` | regenerates the full commit log |
| `tools/ci/*` | the gate's own checks (see [docs/TESTING-AND-CI.md](../TESTING-AND-CI.md)) |
| `tools/marketing/screenshots.py --check` | listing counts, keyword rules and caption tables |
| `tools/l10n/report.py`, `critical.py` | translators' handoff and the legal/permission/VoiceOver gate |

## 11. Lessons learned (gotchas)

- **Worktrees start from `main`**, not from the working branch. Every brief must tell the agent to
  `git fetch origin <branch> && git reset --hard FETCH_HEAD` (or fast-forward to the contracts commit) first, and to
  confirm the head commit.
- **StoreKit in UI tests:** a UI-only run has no unit test to load the scheme's StoreKit configuration (the paywall finds
  no products), and a run after the unit tests inherits their purchases (the app is Pro at launch). UI tests that touch
  the paywall create an `SKTestSession(configurationFileNamed: "Timbre")`, reset it and clear transactions in `setUp`.
- **Simulator start-up flakiness:** the first launches in the minutes after a simulator boots can fail ("does not have a
  process ID", launch time-outs). The accessibility job warms the app up and retries a test once only when a launch was
  its sole failure (`tools/ci/launch_retry.py`).
- **`hashFiles()`** in workflow expressions walks the whole workspace (samples, photos, models) and can time out after
  120 s; compute cache keys in a shell step.
- **Line numbers in the translators' handoff** moved with every edit and failed the gate; the check now ignores them.
- **SwiftLint error thresholds** (file > 2200 lines, > 8 parameters, line > 250, `count == 0`, `a = a + b`) fail the
  gate; split files by moving whole types, group parameters into small structs.
- **Type-checker time-outs** on long closures/expressions (e.g. band grooves): give closures explicit types.
- **Identifiers on buttons with `.lessonControl`** must be applied before that modifier, or hidden duplicates appear.
- **Capture stability:** store frames take pairs of screenshots 120 ms apart and need a HUD that stands still; demo
  scenes (`TIMBRE_SCENE`) hold counters still and pre-judge a clean run.
- **Audio on CI simulators** is slow and fragile: session activation can stall the main thread for seconds. Start the
  click before the take's clock; never let a stale start release a session a newer start holds; retry a transient
  failure once before alerting. Real devices must be checked (docs/ios/AUDIO-DEVICE-TESTS.md).
- **A new warn-level lint rule** must not run with an old baseline; update the hygiene baseline once, after all merges.
- **Counts in marketing** (lessons, courses, songs) are checked against the build; update the listing docs whenever
  content changes.

## 12. Running round 17 from here

1. Confirm the gate is green on the working branch (or `main` after the merge) and the nightly tour and App Preview
   have run on the commit you want judged.
2. `collect_review.py` into a fresh folder; extract the preview.
3. Launch the six jurors with the round-17 brief, then the foreman.
4. Turn the foreman's packages into contracts + teams as in §5. Expect the owner items to dominate the remaining
   distance to 9.5.

## 13. Timings

| Step | Typical time |
|---|---|
| A wave of ten teams (parallel) | 35–50 min |
| Integration pass (four groups, parallel) | 10–20 min |
| PR gate (core, app, release, accessibility in parallel) | 15–25 min |
| Nightly tour + iPad + matrix | 60–80 min |
| App Preview (two cuts) | 35–45 min |
| Jury (six parallel) + foreman | 30–45 min + 15–25 min |
