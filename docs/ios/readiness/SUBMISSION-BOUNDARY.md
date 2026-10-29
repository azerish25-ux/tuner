# Submission work boundary — 28 October 2026

The owner's latest instruction closes work on the completed 50 listings, translations, lessons and tuner. Do not regenerate listing packages, redo translations or reopen content review. Reopen completed work only for a demonstrated submission defect.

Remaining engineering acceptance concerns actual behavior: successful native builds, launch and navigation, usable controls, complete visible instructions/results, scrolling and rotation, and the existing release/sanitizer checks. Account configuration, signing/upload, live StoreKit verification, Apple processing and submission remain a later owner-authorized phase.

## SDK audit reports

The strict XCTest accessibility audit is retained unchanged. Its tests, failed outcomes, original logs and screenshots are preserved. A failed SDK report must never be described as a passed strict audit or proof of complete accessibility compliance.

Under the owner's narrowed scope, uncorroborated SDK contrast callbacks and the exact Dynamic Type/clipped-text “Audit failed to complete in time” reports are advisory to the submission gate. They are evidence to assess, not by themselves demonstrated application defects. The c800 report contains 33 contrast callbacks and one clipped-text SDK timeout; independent current screenshot review found, for example, the flagged Practice countdown above 8:1 contrast. Separate native functional checks and actual visible defects remain decisive.

The gate accepts this advisory disposition only with complete current-run evidence: every expected native case starts and terminates exactly once; no missing, skipped, duplicate, foreign, retried or crashed cases; normal XCTest exits; complete partition receipts; and successful required setup/evidence steps. Only the three SDK partition steps and their strict aggregate may fail. Any other accessibility assertion, failed setup, missing evidence, unsupported error or failed core/app/Release check still blocks.

Demonstrated unreadable text, clipping, inaccessible controls, broken VoiceOver/navigation or other user-visible defects remain blockers regardless of SDK classification. Advisory reports may contain issues outside functional coverage; no claim of complete WCAG or accessibility-feature compliance follows from this policy.

The experimental raster-reference work remains separate and is not part of the shipping candidate. Do not add screenshot classifiers, visual exceptions, color changes or further audit frameworks merely to make uncorroborated callbacks disappear.

## Evidence preserved

- Source c800bb4feaa906cb0d1d33d80bfa6b408c37c8d4, native run 40784550829.
- Tab report artifact 12862420242, SHA-256 `30e38fec221bc746600d911c7401b358fbe65a9e43f729e583d3fb333e482672`: strict audit failed with 34 findings.
- Screen report artifact 12859768824, SHA-256 `774bf1a8a67236896a6af5e10d61f406bdd1bac0f910a52f00bb44c19e77d34c`: four native screen methods passed.
- Localization report artifact 12859232860, SHA-256 `b47db71e1e37deb452b1c12d8e859ac3585deffdfef34fe174e9d85d031cfbaf`: six native launch methods passed.

These historical outcomes are unchanged. The prospective gate policy has regression coverage for advisory classification and for hard failures that must remain blocking; its workflow must also execute on the consolidated candidate.
