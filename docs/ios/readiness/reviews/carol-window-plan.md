# Carol configuration design and focused plan

The confirmed defect truncates the 102 promised Carol lesson IDs to 64. Raise the bounded validated list to 256 while retaining the 64-character identifier and 64,000-byte payload limits.

Add optional `freeSongsWindow: {startDate: "2026-12-01", endDate: "2026-12-08"}`. Dates are strict Gregorian local calendar dates in each player's current time zone; start is inclusive, end exclusive. This covers December 1–7. A missing window preserves deliberately permanent legacy `freeSongs`. A present null, wrong shape, partial, malformed, impossible or reversed window grants no campaign lessons. The window does not change `unit2Free`.

Core `FreeSongWindow` owns parsing, current eligibility and next boundary. `FreeOpenings` carries the policy rather than a prefiltered snapshot; effective lesson reads and `opens` reevaluate current time. Explicit date/time-zone arguments allow deterministic tests without a mutable process clock. `AccessPolicy.canPlay` forwards that clock context, preserving all existing defaults and callers.

RemoteConfig retains raw values/cache, derives a window-bearing policy, and publishes effective-access changes at boundary timers, foreground, significant-time changes, calendar-day changes and time-zone changes. A minimal AppStore subscription forwards the dedicated effective-access signal to its observers, refreshing visible locks and paywall counts. Started takes are not canceled. Access checks remain authoritative if the process suspends or misses a timer.

Implementation order: (1) author Core and app config regression tests; (2) implement Core policy and canonical access reads; (3) wire config decoding, list bounds, notifications and timer; (4) update schema examples and K4; (5) inspect diff and run available static checks. Native RED and GREEN are UNRUN on Windows; macOS XCTest/concurrency build and independent review remain mandatory. No remote grants, deployment, accounts, event scheduling, commit or push.

Timer-only expiration was rejected because offline/cached/default Core consumers could retain stale access. Filtering at fetch time was rejected because it discards future grants and never expires a cached grant. A typed per-read policy with UI notifications keeps one canonical rule.
