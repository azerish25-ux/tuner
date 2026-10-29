# Release evidence applicability

`python3 tools/l10n/store.py --release` uses `release-applicability.json` in
addition to each listing's content-bound verification evidence. This policy is
not an Apple approval, signed build report, upload authorization or release pass.
No listing or manifest `release_ready` flag is promoted by this mechanism.

The policy has an exact schema, evidence inventory and SHA-256 inventory of the
project configuration, Game Center implementation, authoritative English listing
and physical-device checklist, plus the normalized English listing payload hash.
Missing, malformed or stale policy is an error and restores **all** evidence
requirements. Source updates require deliberate policy re-review and hash refresh;
never refresh hashes merely to silence a failure. Localized text still needs its
own current-content review/evidence and all draft fields remain validated.

## Current scope

- **App Preview: not_applicable.** The owner delegated the explicit choice
  between videos and screenshots-only: “what ever you think would be best”. The
  assistant selected polished screenshots for the first submission, with no app
  feature removal. Existing failed video evidence remains failed; the untested
  preview preparation patch stays unapplied. A screenshots-only release uses `status: not_applicable`, `selected_by: owner`,
  `submission_scope: screenshots_only_no_preview_upload`, and a nonempty
  `authorization` containing the actual owner's recorded decision. Review that
  decision against the conversation, listing claims and upload plan before
  committing it. The parser validates structure, not the identity/authenticity of
  a person. No preview files may be uploaded under that scope. Caption drafts may
  remain for a future release; omitting video does not omit screenshots.
- **Game Center account: not_applicable**, solely because release source already
  disables it. The fixed reason is `disabled_in_release_source`. Project must
  have exactly one `TIMBRE_GAME_CENTER_ENABLED: "NO"` setting and retain the
  exactly one active, canonical Info.plist binding; commented-out, duplicate,
  quoted/indirect/flow-style or unsupported bindings/settings fail closed. A
  trailing comment cannot supply the binding. No Game Center entitlement is allowed. An enabled
  or ambiguous environment override fails. Changed source hashes fail even if
  a new implementation would still appear disabled. Enabling requires restoring
  `status: required` and real account evidence. Delivery must also inspect the
  effective build settings and final signed entitlements: repository policy
  cannot certify signing-time overrides or portal state.
- **Device: owner_waived / unverified**, not `not_applicable` or `verified`. The
  exact bounded owner statement is recorded in JSON: “real device test is not
  possible depsite what the readme says , regardless you should start doing what
  it needs to be fully ready for app store submission”. This waives only the
  repository's physical-device QA gate while proceeding with cloud/GitHub Actions
  development. Microphone start/stop, interruptions, speaker leakage/grading,
  latency, wired/Bluetooth routes, haptics, Watch hardware, and physical
  VoiceOver/Dynamic Type remain untested. Simulator evidence cannot establish
  those outcomes. This does not waive simulator/accessibility tests, screenshots,
  privacy, IAP/account evidence, Apple requirements or signing/upload approval.

`release_applicability(source)` exposes `(dispositions, errors)` for reporting.
`validate(..., applicability_policy=...)` accepts an in-memory policy for tests;
normal CLI execution always loads the committed policy. `required` records contain
only their status. Excluded/waived records use only the documented exact keys.
No per-listing `verified` flag is synthesized. Other incomplete evidence still
blocks release, regardless of an optional exclusion or physical-device waiver.
