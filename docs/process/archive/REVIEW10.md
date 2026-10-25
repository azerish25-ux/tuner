# Timbre review 10: design director and App Store growth lead

## 1. Scores
**Overall: 8.1 / 10.** The tuner is better than any competitor's. The look is consistent, premium and dark. The value of the songs and lessons is below Yousician, Simply Guitar and Fender Play, and several frames still look unfinished, which is what stops this reaching 9.5.

| Area | Score | One line |
|---|---|---|
| Visual design & polish | 8.2 | "Studio Noir" is consistent and the 3D headstocks and highway look premium. Let down by templated song covers, empty lesson screens, chip rows cut off hard at the edge, iPad layouts that are just stretched phone layouts, and a grey "studio" picture of the guitar. |
| Motion / delight | 8.0 | The motion system is deep (TimelineView/Canvas in about 30 files, finger dots that land on a spring, spark bursts, phase/keyframe animators, zoom transitions). It has no signature shader moment (0 Metal effects), the microphone and plan screens don't move, and two crossfades show glitches (07, 52). |
| Tuner | 9.1 | Better than GuitarTuna: 3D pegs for 7 instruments, polyphonic Strum to tune with an honest "≈ estimate" label, strobe, 60 instruments and 102 tunings, custom tunings, and string-drift health. The free ukulele is a photo, not 3D, and the iPad shows the flat 2D fallback. |
| Lessons & curriculum | 7.4 | 499 lessons, a coach and a play-along highway. But the 52 "songs" are 8-bar loops of 10 to 108 s (median about 28 s) with no lyrics and no video. Songs are locked by progress, and the lesson screens are mostly text and a diagram with a lot of empty space. |
| Retention / habit loop | 8.3 | Daily set, quests, streak with freeze, levels, 42 badges, coach, string health, smart reminders, widgets and Live Activity. There is no competitive or social layer (no Game Center, leagues or friend challenges). |
| Monetization / paywall | 8.2 | Paywalls change with where they open (Tanpura, plan), the trial timeline is honest, and there are 3 plans. Missing: offer codes, a win-back or exit offer, and social proof. The hero art on the onboarding paywall is cramped. |
| Platform integration | 8.6 | Widgets, Controls, Live Activity, App Intents, Spotlight IndexedEntity, TipKit and Liquid Glass are all there. No Watch app and no Game Center. Only SongsView reads `horizontalSizeClass`. |
| Store readiness | 7.6 | The listing is tight and its numbers match the build. But 3 of the 12 planned screenshots show flaws (62, iPad instruments, iPad tune), "Play songs, start to finish" is used for 22-second songs, and the privacy URL is still a placeholder. |

## 2. What stands between this and 9.5 (ranked)
1. **(L) Make songs full songs.** Screenshots 63, 64, ipad-landscape-songs; `Sources/TimbreCore/Resources/curriculum.json` (songs/originals), `Learn/Highway.swift`, `Learn/SongSheet.swift`. Each song becomes a 1.5–3 min arrangement: intro, verse and chorus twice, then outro. A lyric line scrolls under the highway (public-domain lyrics). Players can loop and slow down any section from the song map. The sheet shows a real length ("2:40", not "0:22").
2. **(M) Real iPad layouts.** Screenshots ipad-landscape-practice, ipad-landscape-tune, ipad-landscape-instruments; `Practice/PracticeView.swift`, `Journey/JourneyView.swift`, `Learn/LearnView.swift`, `TuneView.swift:94`. At regular width:
   - Play and Progress use 2–3 column card grids, with ear games side by side instead of 1,400 pt-wide progress bars.
   - The tuner's middle gap holds the readout and the string rail.
   - The instrument picker gets `.presentationSizing(.page)`, so its cards aren't cut off mid-card.
3. **(M) The song sheet and Songs tab feel finished.** Screenshots 63, 64; `Learn/SongOpener.swift:230`, `SongsView.swift:553,670`.
   - Fill the empty band under the song map with a lead sheet: bars, chord symbols and the melody line, with the hook highlighted.
   - Locked tiles say why ("Finish Kite Weather") and offer a 20-second "Hear it".
   - Fix "Preview with band", which wraps onto 2 lines.
4. **(S) Make the results screen agree with itself.** Screenshot 62 (App Store shot #6); `Sources/TimbreCore/Coach/CoachNotes.swift:185-207`, `Journey/CoachVoice.swift:84`. The headline says "Flawless · 98%" while the coach says "D3 → G3 was 200 ms late… practice the change at 45 BPM". On a 3-star run of 98% or more, drop late-change notes or reword them as a next-level tip. Say "move" for single notes; "change" is for chords.
5. **(M) Signature shader moments.** Screenshots 10b, 15, 62, 05a2; `Tune/Celebration.swift`, `Design/`. Add 2–3 `.layerEffect`/`.colorEffect` shaders:
   - A lock shimmer that sweeps the headstock and string.
   - Strobe ripple on Chromatic.
   - Heat-glow stars on results.

   This is the "how did they do that" moment a $800k build has.
6. **(M) Better use of space on lesson screens.** Screenshots 06b, 51, 54, 55, 52; `Learn/LessonPlayer.swift`, `LessonSteps.swift`, `LessonBeatRow.swift`.
   - Add a compact header with the lesson title and step x/y.
   - Scale diagrams to fill the screen.
   - Strum steps show down and up strokes with a pick that travels the beat lane. Today they show 4 down arrows on a bare line, with about 30% of the screen empty above the guitar.
7. **(M) Song covers that don't look generated.** Screenshots 63, ipad-landscape-songs; `Songs/SongCover.swift:127-188`, `SongsView.swift:461-466`. 4 of the 7 covers in one shelf share the same ridge-and-dot motif. Add more motif families for each genre and vary the type layout. Replace the hero's 22-pt blur, which reads as a smudge at iPad width, with a mesh gradient taken from the cover's colours.
8. **(S) Clean App Store captures.** Screenshots ipad-portrait-tune, ipad-landscape-tune, 07, 52; `TimbreUITests`, `TuneView.swift:215-232`.
   - Wait for the stage probe to report "3d" before the iPad tuner shot.
   - Capture after transitions settle.
   - Don't ship the grey studio card as hero #1.
9. **(M) A competitive loop.** Screenshots 20, 32; `Practice/PlayHubGames.swift`, `Services/PracticeReminder.swift`. Add Game Center leaderboards for Pitch Sniper and Ear trainer, a weekly league or "beat your friend" link built on the existing Share cards, and a Sunday "your week" recap notification.
10. **(S/M) Paywall revenue features.** Screenshots 06, 16, 40; `Paywall/PaywallView.swift`, `Services/AppStore.swift`.
    - Add `offerCodeRedemption`.
    - Make a one-time win-back offer the second time an onboarding paywall is dismissed.
    - Show the weekly price on the annual plan.
    - Make the onboarding paywall's highway hero larger and clear of the close button.
11. **(S) Fade the edges of every horizontal chip row and add a top scroll edge.** Screenshots 01, 12, 21, 30, 44, 48, ipad-landscape-instruments, 33. Today "Violin PRO", "Open G", "7/4", "al minor", "DADGA" and "Folk & wor" are cut off hard. Add one shared fade-mask modifier in `Design/Components.swift`. Progress (33) needs a top shade so "Last five weeks" doesn't run under the clock (`JourneyView.swift`).
12. **(S) Drone: make the tonic a dial.** Screenshots 41, 42; `Practice/DroneView.swift:26-40`, `DroneTanpura.swift`. At rest, the tonic picker sits under the Start drone button. Let the note ring rotate on a drag, with detents, haptics and a tick per note, and move the picker above the sing-along card.

**Needs outside assets or an owner decision:**
- Licensed popular songs, or more commissioned originals with real band stems for "Preview with band".
- Instructor or hand-cam clips and hand-position photos for chord and strum lessons.
- A 3D soprano ukulele (a free core instrument, now a photo).
- Re-render the acoustic studio card: the headstock is grey and the fretboard lilac (14, iPad).
- Privacy policy URL, the pricing tier, and real review quotes for the paywall's social proof.

## 3. Bugs
- **06b** (`Learn/Diagrams.swift:500`): finger 1 on the small F is cut off at the right edge of the grid. `right = size.width - 22 + labelColumn/4` leaves less room than `r + halo`, so any string-1 dot on a large diagram is clipped.
- **07** (`Tune/TuneView.swift:263-267`): "Hold it…" and "In tune" crossfade into a garbled "Holtdute.". The text changes inside the `badgeSaysIt` opacity animation. Freeze the string, or use `.contentTransition(.identity)`.
- **62** (`CoachNotes.swift:200-207`): the "Flawless" headline contradicts the coach's 200 ms late note, which also says "change" for single open strings.
- **52** (`Learn/LessonSteps.swift:1013-1040`): the orb shows an amber ✓ while the hint says "Tune up a little", and a faded "B3" is still visible after the G chip has become current. The ring's symbol lags behind the hint.
- **ipad-landscape-instruments** (`TuneView.swift:94`): the form sheet cuts the instrument cards in half and hides their names.
- **ipad-portrait-tune, ipad-landscape-tune**: the 2D studio fallback stays on screen (grey headstock, strings barely visible), and in landscape the controls float in an empty middle column.
- **41** (`DroneView.swift`): at default scroll on the 6.9" phone, the Start drone button covers the tonic picker.
- **33** (`JourneyView.swift:155`): scrolled content shows under the status bar with no shade.
- **20** (`Practice/DailySetCard.swift`): "+20 XP" floats on its own line under "Tune up" (its empty progress bar), so the row is taller than the others.
- **05b** (`Onboarding/OnboardingView.swift:473`): "45-second" breaks at the hyphen ("45-" / "second"). Use a non-breaking hyphen (U+2011).
- **63** (`SongsView.swift:553,670`): one shelf mixes PRO badges and padlocks, and the padlocks give no reason. The locked titles drop below a readable contrast.
- **64**: "Length 0:22" sits next to a "6 min" lesson, which is confusing. Label it "Song 0:22 · lesson 6 min", or make the songs longer (item 1).
- **13** (`Settings/SettingsView.swift:151`): "Capo: 0" and "Transpose: 0" put the value inside the label. Every other row has the label on the left and the value on the right.
