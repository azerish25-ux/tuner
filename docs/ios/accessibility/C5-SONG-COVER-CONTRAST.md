# c5 native accessibility: catalogue-number contrast

## Evidence and limited change

The iPhone 17 Pro run `40321755925`, job `121568951162`, reported **59 failures**:
57 enforced contrast findings (Songs 39, Practice 7, Progress 10, Paywall 1), plus
Songs' Dynamic Type and clipped-text audits each exhausting three isolated attempts.
An unfinished audit is not a pass.

Artifact `12651044308` SHA-256:
`eb8f1430a48ce752024c8f8cd029bac19e5ba213b65a6ab0f723d4bffb829c03`.
The original PNG is sRGB, 1206 × 2622 pixels, representing 402 × 874 points at 3×.
Exact image identity, coordinates and colours are in
[`c5-song-cover-contrast.json`](c5-song-cover-contrast.json).

Songs' visible **03** has frame `(44.02928, 699.1, 11, 10.33333)` points, well above
the dock. Its core pixel `(155, 2104)` is `#4E5868`; adjacent background `(145, 2104)`
is `#95ABD4`: **3.1009:1**. Even the darkest/brightest pixels anywhere in this full
frame yield only **3.3825:1**, below the 4.5:1 small-text threshold. This is not an
edge-fade or dock exception.

`SongCover.catalogue` previously used `ink.opacity(0.62)`, beneath the final
top-light overlay. The change uses **full existing role ink**: `Palette.stage` for
light fields, `Palette.ink` for dark sleeves. Font, size, position, number, artwork,
rule opacity, top-light overlay and accessibility semantics remain unchanged.
No audit type, exception, known-issue label or workflow changes.

## Reproducible regression and its limits

```sh
python3 tools/ci/test_song_cover_contrast.py
# With the original extracted artifact locally available:
python3 tools/ci/test_song_cover_contrast.py --screenshots /path/to/screenshots
```

The four tests guard the actual source's role-colour branch and full opacity,
reproduce the measured failure, and calculate sRGB/WCAG contrast for the new ink
over the recorded light and dark sleeve backgrounds. They read the current palette
tokens and top-light maxima from source rather than duplicating those constants.
The optional screenshot verification checks SHA-256 and all five exact pixels.

| Background already including its captured light | New source foreground | Foreground top-light range tested | Model's minimum |
|---|---|---|---:|
| Light number field `#95ABD4` | stage `#060708` | 0–18% white, 101 samples | 5.4051:1 |
| Dark sleeve `#311C30` | ink `#F5F3EF` | 0–12% white, 101 samples | 14.1477:1 |
| Brighter dark sleeve region `#6A4067` | ink `#F5F3EF` | 0–12% white, 101 samples | 7.4543:1 |

These are **source/compositing regression estimates, not new native screenshot
measurements**. The dark backgrounds come from the featured dark sleeve, not its
own numbered imprint. This receipt does not certify every generated cover,
locked/saturated variant, device, font rasterization or partly faded scroll state.
The correction still needs native rendering of light and dark numbered covers,
including locked covers and both numbered imprint positions, followed by the
unchanged enforced audit. No Swift/Xcode runtime is available in this Linux
workspace; native compilation, native tests and rerender were not run.

Local verification: all four scoped tests passed; the exact PNG SHA and five pixel
samples matched. The same tests against the pre-change `SongCover.swift` fail the
opacity/source guard. Hygiene's 25 tests and resource verification passed.
Hygiene lint reported no new error-level occurrences; its existing
`PaywallWinBack.swift:132` inline-orb warning is unrelated. `git diff --check` passed.
The new test is also wired into the existing iOS hygiene step. Its first CI execution and the native rerender remain pending.

## Other findings: do not broaden an exception

The original screenshots contradict many other baseline contrast readings:
Songs title 17.13:1, subtitle 8.00:1, Play 13.31:1, hero chord letters 14.32–14.54:1;
Practice streak 11.57:1, header level mint 13.32:1, large level mint 10.05:1,
Challenge 13.43:1; Progress Tune up 7.31:1; Paywall SAVE 58% 9.84:1 locally.
The saving badge's source foreground has at least 7.88:1 against its gold-gradient
endpoints. These representative samples are not permission for a label-wide waiver.

Other frames intersect scroll fades or the dock. Examples: Songs' Violin filter
extends from x377.67 to x466.67 on a 402-point display; its trailing SONGS label
extends from x401.09 to x434.91. Practice Ear training spans y850.67–872.33 beneath
the dock. The seven Progress calendar initials span y783–798.33 at the dock edge.
Measure these **same elements scrolled clear**, rather than increasing the entire
palette or hiding text.

The original screenshot is taken before the audit and is not an attachment from
each callback. Its pixels establish that captured state, not every state during
the later audit. Audit timeouts' root cause remains unproven; existing mesh and
game preview clocks already respect stage-rest through `animatesWhileSeen`.

Baseline readability does not dismiss clipped-text findings: Apple's
[audit documentation](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)
states that this check examines possible clipping at larger Dynamic Type sizes.
For example, Progress' `best tune-up` is readable at baseline but `WeekStat` still
uses one line with a 0.75 minimum scale. Practice's clipping report has no available
snapshot, so it cannot be assigned to a particular label from this evidence.

## Proposed native coverage additions — not implemented

Keep the existing at-rest screenshots, all audit kinds, failure policy and known
exceptions unchanged. Add the following complementary tests; do not substitute
them for the at-rest run.

1. **Songs, scrolled-clear shelf and filter.** Fresh launch with existing demo and
   stage-rest flags. Discover the actual `songs.known.<lesson-id>` buttons and save
   their IDs. The c5 shelf shows Ode to Joy (Songs), Amazing Grace (Guitar) and
   Silent Night (Songs); source candidates are `songs.known.song-ode-to-joy`,
   `songs.known.gtr-6-5`, and `songs.known.song-silent-night`. Assert the actual IDs
   and labels, never silently substitute another version. Vertically position
   the full sleeve/caption above the dock; horizontally bring each target clear
   of the 52-point rail fades, retaining its title, catalogue number, chords,
   duration and versions controls. Independently bring the existing
   `songs.filter.<instrument-id>` Violin filter into the clear rail viewport.
   Capture geometry and a screenshot immediately before each complete audit.
2. **Practice, separate game-card positions.** Use existing `practice.sniper`,
   `practice.sniper.challenge`, and `practice.ear` identifiers. Position the
   Bullseye daily challenge and the Ear training heading/body wholly above the
   dock, in separate captures if necessary. A future leaf/container identifier
   such as `practice.sniper.daily-challenge` should identify its title and XP
   together; do not exempt every `+25 XP` or every `Ear training` label.
3. **Progress, week and calendar separately.** Add stable identifiers to the
   existing week and calendar containers (`journey.week`, `journey.calendar`)
   without changing their accessible children/labels. Scroll the full calendar
   heading, day count and weekday row above the dock; capture/audit there.
   Capture the complete week-stat row separately, including `best tune-up`.
4. **Repeat all three at larger Dynamic Type.** Independent fresh launches at
   `.accessibility1`, `.accessibility3` and `.accessibility5` using
   `-UIPreferredContentSizeCategoryName` (AX5 is
   `UICTContentSizeCategoryAccessibilityXXXL`). Capture upper content and the
   scrolled-clear positions above. Assert meaningful text bounds and collect
   complete clipped-text and Dynamic Type audits, preserving every finding.
   The current `AccessibilityMatrixUITests.testMatrixScreens` visits tuner,
   Settings and lesson steps, **not these hubs**; its screenshots cannot close
   this gap. Its informational audit catch must not turn new incomplete audits
   into passes: retain the strict completion behavior of `AccessibilityAuditUITests`.

For each target, `.isHittable` alone is insufficient. Save its frame, the containing
scroll-view frame and the actual tab-bar frame; require its meaningful content to
be fully in the readable viewport. Leave a measured safety margin above the soft
bottom edge and center horizontally away from both active rail fades. If a card
cannot fit at AX5, use overlapping captures of its constituent meaningful text
instead of shrinking it. Recheck that the scrolled-clear target has the same ID.
Failures to reach, fit or audit are explicit failures, not exclusions.

Diagnose Songs' remaining timeouts with fresh-process isolated Dynamic Type and
clipped-text audits, preserving the complete UI and reports. Do not claim that
longer sleeps, opacity changes or palette changes explain or resolve those timeouts.
