# Proposed same-run Nightly tour products

This is a source-reviewed proposal, not native execution evidence. No existing failed run is reclassified, no test is removed, and no readiness flag is changed.

## Scope

One `tour-build` job builds the exact existing Debug scheme once. Five unchanged tour class shards download its products and run `test-without-building -xctestrun`. The independent Release archive, iPad, accessibility matrix and Thread Sanitizer remain separate. The launch-performance shard still never primes the app; the other four retain their existing diagnostic priming policy. No simulator state, installation or runtime cache is transferred.

`l10n.yml` and `localization-matrix.yml` are untouched. The latter covers 51 translated languages with English checked elsewhere; each current shard compiles a different fixture and sharing those products needs a separate design.

## Evidence and expected benefit

Measured 9e1 tour launch job 122527145700: compilation 202 seconds, simulator boot 70 seconds, status-bar readiness 67 seconds, selected UI-class step 272 seconds, whole job 694 seconds. Earlier 4f8 tour compilation took 264 seconds and tests ran over 23 minutes before cancellation; that is not a completed benchmark. Earlier listing shared products occupied approximately 215 MB, uploaded in 7 seconds and a comparable archive downloaded in 2.47 seconds. Its compile-and-package step took 407 seconds. These are different runs, not a controlled comparison.

Sharing removes four duplicate tour compilations, potentially avoiding roughly 13–18 runner-minutes at the observed tour compilation times, before packaging, transfer, verification and scheduling overhead. It does not guarantee wall-clock savings: jobs may already compile concurrently, the producer introduces a dependency, queue time is material, and simulator/test execution remains unchanged. First native execution must record actual timings and verify all five class outcomes.

## Fail-closed identity

Products are tied to exact checkout/GitHub SHA, run ID and run attempt; tracked source modifications are rejected. The manifest also binds Xcode build output, simulator SDK version/build, host architecture and macOS version, selected runtime identifier/version/build, and device type. Consumer UDIDs may differ, but runtime/device type cannot silently fall back to latest. Executable architecture slices must match the producer and include the consumer architecture.

The archived Products tree includes its xctestrun and retains executable permissions. Archive hash, every file hash/mode and contained symlink target are verified. Unsafe archive paths, special files, external symlinks, missing products, missing or multiple xctestrun files, unresolved `__TESTROOT__` references and producer-home absolute paths fail. There is no broad path rewriting. Source JSON/StoreKit fixture inventories, including explicit absence, and the xctestrun hash are retained in each class's receipt. Aggregation requires all five receipts to agree except for worker-local UDID, and the producer plus every class must succeed.

Important native compatibility risk: Xcode may emit a legitimate absolute StoreKit or other source path. The guard intentionally fails rather than accidentally reading a producer-home path. Inspect the actual generated file before adding any narrowly scoped, independently tested relocation rule. Do not disable the check to obtain a green run. Strict SDK/macOS/runtime matching can also reject mixed hosted-runner images; that is visible failure, not automatic fallback.

## Recovery without old-attempt reuse

GitHub documents that [re-running a job also re-runs its dependent jobs](https://docs.github.com/en/rest/actions/workflow-runs#re-run-a-job-from-a-workflow-run). The supported scoped recovery is to re-run **tour-build**, which refreshes the producer, all five dependent tour shards and the publisher. The new attempt receives new producer and per-class artifact names; prior artifacts remain intact. Verify all six jobs and aggregation actually execute with the new attempt before treating recovery as established. This route is documented, not yet exercised by this proposal.

Re-running only a failed consumer after a successful producer cannot use an old-attempt product archive and fails closed. Re-running the whole workflow is another supported route. A successful prior independent archive may remain an independent same-source result when only the producer dependency subtree is rerun; it is not described as a new archive execution. No artifacts are overwritten or deleted. Existing published screenshot destination `results/results-tour/screenshots` remains unchanged, while per-shard downloads are attempt-qualified.

Apple's [command-line testing guidance](https://developer.apple.com/library/archive/technotes/tn2339/_index.html) supports generating test products with build-for-testing and consuming an xctestrun with test-without-building. That capability alone does not establish this proposal's native compatibility or performance.

## Local validation

The Python suite covers exact identity mutations, runtime/device mismatch, executable architecture mismatch, archive traversal/symlinks, xctestrun relocation failures, file/mode mutations, archive tampering, a real tar pack/restore fixture round-trip, full class coverage, unchanged launch warmup exclusion, attempt-qualified artifacts, and fail-closed aggregate evidence. These synthetic fixtures are not native app or screenshot evidence. Native build, all five class runs, source-bound artifacts and independent review are still required before adoption.

## Independent inspection of real Xcode products

Artifact `12776617030` from source `4f8b69e3efad4e405714d031462a25167cc06799` was downloaded and its 214,770,396-byte ZIP verified against SHA-256 `5c8734aae8737b1c65cae8918813e3889d45e2d1a0d4991825398bcf4c23529c`. Only metadata and the xctestrun were materialized; application binaries were not executed. The Xcode26.3/17C529 xctestrun has no producer-home/StoreKit absolute path and every `__TESTROOT__` reference exists in the archive. A path-only probe created those tar-proven references as empty stubs and the verifier accepted the actual native spec. This is path-shape evidence, not a restored native execution.

The real macOS archive also exposed an issue absent from synthetic Linux tests: a top-level AppleDouble `._Products` entry. It correctly fails the strict Products-only extraction guard. The producer now uses Darwin bsdtar's `--no-mac-metadata` and validates its archive member list before publishing, rather than allowing arbitrary siblings. Apple's [libarchive source](https://github.com/apple-oss-distributions/libarchive/blob/main/libarchive/tar/bsdtar.c) implements this flag by disabling copyfile metadata handling. File contents, executable modes and contained symlink targets remain inventoried; xattrs/ACLs are not claimed as transferred. A regression requires the flag and proves a producer still emitting `._Products` fails before build-info publication. The new Darwin packaging behavior still requires its first actual GitHub Actions verification; no old artifact is reclassified or rewritten.
