# Archive: reviews, jury verdicts and wave records

The working files of every review round, kept verbatim as they were written during development (2026-10-22 → 25).
Paths inside them that start with a temporary folder (`/tmp/claude-0/…/scratchpad/…`) pointed at the session's
scratch space: `polish/` is this folder, `review<n>/` were the screenshots the reviewers looked at (re-create them
from the `ci-results/app` and `ci-results/ipad` branches with `tools/agency/collect_review.py`).

| File | What it is |
|---|---|
| `REVIEW3.md` … `REVIEW14.md` | single-reviewer rounds 3–14: score, ranked defects, the next wave's work packages |
| `QA10.md`, `DESIGN11.md` | a QA sweep (round 10) and a design-language review (round 11) |
| `JURY15-<role>.md`, `REVIEW15.md` | round 15: six jurors (visual, delight, inclusivity, technical, growth, category) and the foreman's consolidated review (7.7) |
| `JURY16-<role>.md`, `REVIEW16.md` | round 16: the same panel (8.3) and the ten wave-19 work packages |
| `CONTRACTS19.md` | the day-1 shared interfaces the ten wave-19 teams built against |
| `INTEGRATION19.md` | every cross-team request the wave-19 teams left, what the integration pass did, and the leftovers |

The briefs used to run these steps are in [../templates/](../templates/); the process is in
[../AGENCY-WORKFLOW.md](../AGENCY-WORKFLOW.md).
