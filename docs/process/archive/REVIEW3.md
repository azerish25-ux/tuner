# Independent review round 3 (overall 6.9/10) — items relevant to the next wave

Screenshots: /tmp/claude-0/-home-claude/8e09460e-cfac-5eb2-9c8f-db780efe8fda/scratchpad/review3/*.png (iPhone 17 Pro sim, 402×874 pt).

1. Overlays/safe areas (S): the +XP/quest/badge toast covers the Tune header (11 hides the chevron, 18 ghosts over "Soprano ukulele", 19 shows "4 / St" peeking). Scrolled content under the clock (31, 33). Floating CTAs hide content: 21 hides "Speed trainer", 41/42 cut the drone hint, 40 hides the paywall timeline captions. Fix: toast as a compact pill from the Dynamic Island area (one banner at a time, queued) or push the header; top scroll-edge scrim on tab roots; CTAs via safeAreaInset so content stops above them.
2. Paywall (S): timeline captions hidden at first view (06 bare icons; 40 captions behind CTA). Make the plans + full Today/Day 12/Day 14 timeline + CTA fit on 6.1". Contextual headline per paywallReason (drone → "Unlock the Tanpura drone + every practice tool"; lesson → "Keep going: Unit 2 · First melodies" with that lesson's card).
3. Live readout (S): .numericText on a 60 Hz value leaves half-rolled digits ("−1½ cents", 10, 19); width changes so "cents·" collides (11, 14). Readout.swift:202–215, TuneView.swift:145: no rolling transition on the live cents, update displayed value ~10 Hz with ±0.5¢ hysteresis, fixed monospaced width.
5. Rhythm steps (S): "Play or tap on the dots" (54) lets a guitarist pass strumming by tapping the glass. Tap only when the mic is denied/unavailable, cap at 1 star, label it "Practice mode".
6. Precision mode (S): tolerance picker Beginner ±5¢ / Standard ±3¢ / Pro ±1¢ (TuningTracker.swift:4 is a fixed ±5¢); offer the existing StrobeBand as a full strobe view.
7. Aha before paywall (M): after the mic step, "Pluck your thickest string": the stage reacts live ("E2 · 8¢ flat, turn ↻"), locks with burst + haptic, then plan → paywall. Welcome CTA reads "Start tuning" but leads to questions.
9. Lesson visuals (M): note steps (56) need a fretboard/tab strip with the target string lit; strings drawn thicker toward the bass (57 quiz diagram draws all strings equal); strum card (53) ~70% empty — animated strum sweep synced to the click; fill dead lower half of 51–56.
10. Quests (M): "Tune every string 0/1" (20), "tune all 6 1/6" (10), "Lock 3 strings… Quest complete" (18) — one action shown three ways.
11. Chords/scales (M): algorithmic voicings like 875050, 875080 (43) → curated shapes (x32010, x35553 A-shape barre, 8-10-10-9-8-8 E-shape); scale tones as intervals (R ♭3 4 5 ♭7) not 1–5 (44); 12-fret scrollable neck; light each note as "Hear the scale" plays; mandolin courses grouped as 4 chips, not 8 clipped (49).
12. Motion (M): zoom transition Learn hero card → lesson; camera dolly between full-body and headstock framing instead of cross-fade (10b ghost); studio-mode vibrating string drawn along the rig's real string anchors, not a centred squiggle (14, 17, 19); play-along score colour by result (33% shows success mint, Highway.swift:138).
13. Sound (M): sine cues (SoundFX.swift:29–40) → designed palette (plucked/harmonic, e.g. Karplus–Strong), lock "ding" pitched to the string just tuned.

Bugs:
B1. "Bar 2 of 2" shown in the ready state (54): LessonSteps.swift:365–373 computes elapsed from a stale startTime while phase is .ready.
B2. "cents" hard-coded English and unpluralised: Text(verbatim: "\(n) cents") (Readout.swift:202, 215) → "−1 cents" (11).
B3. Selected string chip label vanishes at lock (18, "C4" unreadable): StringRail.swift:87–91 switches text to dark onAccent before the fill turns solid.
B4. Truncations: "voice, piano, winds or anythin…" (12, 30), "7-string electric guit…" (31), "60 instruments · 102 tunings · your own" (30), "Make it / a habit" wrap (62); chip rows clip mid-word ("Bowe", "C") with no edge fade.
B5. Ear training shows "Listening…" while the app plays tones (EarTrainingView.swift:183) — elsewhere it means the mic.
B6. Low contrast: disabled Continue (03, 04) dark-green on green; unselected string chips on the tune-check step (52) nearly invisible; Settings footer in body-size primary text with "Display" header jammed under it (13).
