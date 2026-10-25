# Independent review round 6 (overall 7.7/10) — items for wave 7
Screenshots: /tmp/claude-0/-home-claude/8e09460e-cfac-5eb2-9c8f-db780efe8fda/scratchpad/review6/*.png

1. Plan promise (S): plan card (05b) says "First lesson: Three notes on string 2 · Unit 2" but after "Continue with the free tuner" the Unit 1 lesson opens (06b) because of the fallback in AppStore.swift ~316–319 (placed lesson is Pro). Make the placed first lesson free as a "placement pass" (the first lesson of the placed unit is playable on the free plan), so the plan and what opens agree.
2. "Hear it" and reference tones sound like an organ (ReferenceToneRenderer, Sources/TimbreCore/Audio/OutputAudio.swift ~50, additive). Reuse the Karplus–Strong pluck (Timbre/Audio/SoundFX.swift ~227) with a 20–30 ms strum spread and a body resonance; bowed instruments get their own (bowed) voice.
3. String orientation still flips: string 1 on top in tune check/notes/quiz/songs (52, 56, 57, 64); string 6 on top in strum/highway/intonation (53, 55, 59, 46).
4. Paywall: bullets are inventory counts; make them outcomes for the user's goal/plan, add a looping live preview at the top (e.g. a mini highway or animated stage), show the user's plan milestones next to the trial track.
5. Highway and strum views look thin (54 empty y≈800–1080, 60 below "Next"): larger string-coloured notes with sustain tails, a burst on the hit line, combo multiplier, "perfect" flash, textured fretboard — it's the App Preview hero shot.
9. Live Activity / Dynamic Island: metronome or drone BPM, practice-session timer, "streak at risk" on the Lock Screen (widget target exists).
Bugs:
B1. Content cut at the fold: Intonation footnote cut under "Listen" (46); Play "Today" card wraps "Ear training" to two lines while truncating "Your first chord:…" (20); "Daily practice" wraps on the plan card (05b). (Results 62 already got a fade — verify.)
B2. Recent sessions say "Acoustic / electric guitar" (33) from catalog.json:96 / en.lproj Localizable.strings:142 while everywhere else says "Acoustic guitar".
B3. Achievements: each title reserves an empty second line before "Earned" (JourneyView.swift ~281 lineLimit(2, reservesSpace: true)); earned badges fill the first rows so the closest locked goals hide behind "Show all".
B4. Song cover monogram "ML" cropped at the card edge so it reads "MI" (63, SongCover.swift); the lock on "Porchlight" sits on the letters.
B5. Plurals: only en.lproj has Localizable.stringsdict; the other 48 locales fall back to one form ("%lld sessions", "%lld minutes", "Every %lld bars") — wrong grammar in ru/pl/uk/cs/ar….
B6. "52b-lesson-chord" shows the strum explainer: the test's settle(8) lets the synthetic pitch pass the chord step before the shot (TimbreUITests.swift ~254).
