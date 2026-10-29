# Reviewable listing evidence (future captures only)

The localized listing workflow keeps its complete `listing-assets-<shard>`
forensic artifact, including every failed attempt, xcresult, automatic attachment
and video, with the existing seven-day retention. This change does not retrieve,
repackage, delete, or bypass restrictions on historical artifacts.

Before that large upload, each worker publishes:

1. `listing-manifests-<shard>`: the original compact locale manifests (unchanged
   names and schema; the existing aggregate gate still consumes them).
2. `listing-diagnostics-<shard>`: a compressed inner ZIP and evidence index with
   full nonempty test/renderer/recorder logs, xcresult summary and test-tree JSON,
   export status, original attachment manifests, and their explicitly named text
   attachments, including any available hierarchies. No console-tail truncation.
3. `listing-failure-images-<shard>`: the source-emitted `zz-failure` native PNG for
   each matching failed phone test, explicitly diagnostic-only, not listing
   assets. It is independently bounded so media overflow cannot hide full logs.
4. `listing-review-<shard>`: an uncompressed inner ZIP and evidence index containing
   every manifest-verified final screenshot JPG/contact sheet and the exact
   requested **original native PNG captures**, plus source manifests, the native
   export manifest, device identity and build provenance. Names, original paths,
   byte counts and SHA-256 are recorded; capture names, pixel hashes and native
   dimensions are preserved. No resizing, re-encoding, fabricated screenshots,
   or blanket collection of automatic XCTest screenshots/video.

The review selector revalidates the current locale payload/lesson provenance,
source commit, unsigned shared-build digest, worker device, passing-language
records, capture-name/order coverage, native export mapping, file/pixel hashes,
image dimensions and every rendered frame. Missing files, traversal, symlinks,
duplicate package paths or changed hashes fail packaging. It never falls back
to loose filename selection. Optional preview review keeps the final movie and
manifest-selected supporting files; its raw recording remains in full forensics.

A failed/running locale is included with its original status and error and with
its requested captures marked unavailable as verified review assets. Such a
locale is **not** silently dropped, approved, or replaced by automatic test
attachments. Its raw failed-attempt screenshots remain in full forensics. The
review index is explicitly incomplete. A passing locale can still be reviewed
beside that failure; the capture step and unchanged aggregate gate remain failed.

Summary export uses Apple's `xcresulttool get test-results summary` and `tests`
commands before attachment export, including failed test attempts. Export errors
are retained without overriding the native test exit status. Missing or malformed
summary/attachment exports cannot prevent otherwise safe full logs from being
packaged: the diagnostics index records the gap and its command fails. Hierarchy
files are preserved only when actually exported; none are synthesized. Failure
PNG selection requires the exact teardown name, failed full-log test line,
matching export-manifest test identifier/URL and device, original PNG format and
native dimensions, and matching locale/source/build provenance. Missing,
duplicate, mismatched or unexported failure screenshots are explicit diagnostic
gaps; automatic screenshots are never guessed as replacements.

## Bounds and failure behavior

- At most the existing three-locale worker bound; no plan/device/scene changes.
- 5,000 selected files, 128 MiB per selected file, 16 MiB per parsed JSON.
- Each review/failure-images inner ZIP plus its separate index: strictly below
  384 MiB. Full text diagnostics is written before failure-image packaging.
- Diagnostics expanded inputs: at most 256 MiB; inner ZIP plus index: strictly
  below 64 MiB. Both leave ample room below the observed 512 MiB connector cap
  for the outer two-file Actions artifact.
- Archive sizes are checked after ZIP finalization; original byte hashes are
  checked before packaging and again inside the resulting ZIP.
- Exceeding bounds fails rather than truncating logs, silently dropping requested
  images, or overwriting an earlier package. Full raw upload still runs under
  `always()`. Packaging/upload failure does not become a native pass.

`release_ready` stays false and visual/native review stays pending. This layout
fix does not repair or reinterpret the old English `test10PlayAlongLesson`
failure. Native Xcode export compatibility, real bundle sizes, screenshot pixel
review and the original failing assertion still require a future authorized run.

## Local checks

```
python3 -m unittest discover -s tools/marketing/tests -p 'test_listing_evidence.py'
python3 -m unittest discover -s tools/marketing/tests -p 'test_listing_assets.py'
python3 -m unittest discover -s tools/marketing/tests -p 'test_screenshot_roles.py'
python3 -m unittest discover -s tools/marketing/tests -p 'test_artifact_qa_triggers.py'
```

The evidence tests use synthetic tiny images strictly as test fixtures; they are
not listing screenshots or evidence of native execution.

References: [Apple xcresulttool release notes](https://developer.apple.com/documentation/Xcode-Release-Notes/xcode-16_3-release-notes)
and [official upload-artifact documentation](https://github.com/actions/upload-artifact).
