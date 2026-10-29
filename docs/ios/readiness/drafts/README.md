# Unfinished preview band-preparation draft

Preserved at the owner's development wind-down on 27 October 2026. **This patch is not applied to the handoff branch and has never been compiled or executed natively.** It is not release approval.

Base: `0bab4ed55d08d0972dfd9f436b4222c683adff15`. Patch SHA-256: `bd83e1d89a4a0e974c604ac111e7e44d498c0598596cc98261898fafb3626c4d`. [The manifest](preview-band-preparation.json) records all four draft source hashes. Its reverse check passed before archiving and its forward check passed after restoring committed source.

## Recover on a development branch

From a clean checkout of `codex/app-store-readiness-gates`:

```sh
git switch -c finish-preview-preparation
git apply --check docs/ios/readiness/drafts/preview-band-preparation.patch
git apply docs/ios/readiness/drafts/preview-band-preparation.patch
git diff --check
```

If later edits conflict, port the patch deliberately rather than forcing it. The three review receipts preserve the initial findings and corrected draft:

- [Initial review](../reviews/preview-band-preparation-independent-review.json).
- [Follow-up cancellation finding](../reviews/preview-band-preparation-followup-independent-review.json).
- [Final source review](../reviews/preview-band-preparation-resolution-independent-review.json).

## What the patch changes

1. `AudioService.swift`: a debug-only exact arrangement/current-renderer-rate cache probe; optional final preparation predicate and one-shot rejection cleanup in shared `AudioStartGate`.
2. `SongPerform.swift`: recorded scenes reserve actual output, await readiness, prepare the exact band, poll its cache for up to 45 seconds after activation, retain the lease through the asynchronous startup handoff, and recheck lease/revision, stage phase, arrangement and cache before starting the take. Non-recorded store scenes retain their original path.
3. `AppPreviewUITests.swift`: require an actual take-clock acknowledgment, allowing the explicit preparation phase up to 60 seconds; remove the invented fallback clock.
4. `AudioStartupTests.swift`: four controlled regressions for preparation invalidation, cancellation, ready-but-unconsumed cleanup and replacement preserving a newer click.

The gate cancellation order is intentional: invalidate generation, capture/clear old handles, perform ownership-qualified rejection while the old request's identity can still be checked, then cancel captured readiness/task. Cancelling readiness before rejection previously made `request.isCurrent` always false and could leave a click running. Conversely, unconditional cleanup could stop a newer request. Preserve both protections.

## Required verification before integration

- Compile with the CI Xcode/SDK and inspect new warnings.
- Run `AudioStartupTests`, `RecordingStartupTests`, all app tests and smoke flows. None of the four new regression methods has executed.
- Exercise exact arrangement/sample-rate readiness and output-revision changes natively; there is no direct completed native cache/rate test yet.
- Confirm cancellation/replacement releases ownership once and never starts an obsolete take or stops a newer click.
- Record real guitar and violin previews. Validate `band` events throughout the selected clip and actual low-frequency/audio continuity, lock/poster synchronization, scene coverage and all original gates.

The 45-second poll budget does not bound underlying hardware activation. Do not describe it as a total startup deadline. This patch does not repair Songs/Show Me/results anchors, tuned/end-card continuity or all missed 3D moments. Read [the frozen failed-run triage](../reviews/preview-c887-timing-triage.json) and the repository README before resuming.
