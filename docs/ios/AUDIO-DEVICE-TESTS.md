# Audio on a real device: the test sheet

The simulator has no microphone bleed, no silent switch, no calls and no AirPods, so these checks run on a phone before each release that touches `ios/Timbre/Audio`, `PlayAlongCues.swift` or `RecordingPlayer.swift`. Record every run below: the date, the device and iOS version, the build, pass or fail, and what was heard. A fail blocks the release until it is fixed or the owner signs it off.

Run each case on an iPhone with the built-in speaker, and the route cases with AirPods (or other Bluetooth headphones) and wired headphones too.

## Cases

| # | Case | Steps | Expected |
|---|---|---|---|
| 1 | A podcast at first launch | Start a podcast in Apple Podcasts. Delete and reinstall Timbre, open it and go through the welcome (the motif plays). | The podcast keeps playing under the motif. Nothing stops it. |
| 2 | The silent switch after tuning | Tune a string to its lock, leave the tuner for Practice, flip the Ring/Silent switch to silent, then open a lesson's results or trigger a star. | No chime is heard. With the switch on ring, it is. While the tuner listens, the lock bell may still sound (the microphone's session ignores the switch by design). |
| 3 | The speaker band | On the speaker, with the band switch on, start a play-along (Twinkle, guitar) and play it. Miss a note, then play four in a row, then reach ×4. | Drums under the runway, no bass and no chords. Missing thins nothing you can hear on the speaker; ×4 crashes; a broken run chokes. The take grades as it does with the band off (play the same take both ways). |
| 4 | The speaker band on strummed steps | On the speaker, strum a unit-1 strum step with the band on, then with it off. | The same stars both ways, within one stroke. If drum hits are counted as strokes, the strum step passes `onSpeaker: false` to `playBand`. |
| 5 | Chords that change mid-bar | In headphones, play "Chords & words" on a song whose chart reads `C G \| D G`. | The bass and the chords change on beat 3 of each bar; nothing of the old chord rings into the new one. |
| 6 | AirPods in and out mid-lesson | During a play-along take, connect AirPods, then take them out. | One short gap each time, not two. The band goes full in the AirPods and back to its kit on the speaker; the click never stops; the microphone keeps judging. |
| 7 | A call during the drone | Start the drone (Practice), take a call from another phone, hang up. | The drone stops for the call and comes back by itself after it. |
| 8 | Siri during the tuner | While the tuner listens, hold the side button for Siri, ask something, dismiss Siri. | The tuner listens again on its own, with no restart from the screen. |
| 9 | CarPlay | Connect CarPlay (or a car's Bluetooth) and open the tuner and the metronome. | Both work; the metronome's click is heard in the car; nothing crashes. |
| 10 | Spoken cues at 60 BPM | With VoiceOver on, open a play-along at its slowest rung (60 BPM) and play it. | Each note is named before it is due and the voice is over before the note starts. No note is judged a miss because the voice was speaking. |
| 11 | The tuner's battery | With Instruments' Energy Log, leave the tuner listening for 5 minutes, then run a play-along for 5 minutes. | The tuner wakes less often than the play-along (longer I/O buffers when it only listens). |
| 12 | Background and back | Start the Metronome tool, lock the phone for a minute, unlock. Then start the tuner, switch apps, come back. | The click plays on through the lock. The tuner is listening again when you come back. |

## Results

| Date | Device, iOS | Build | Cases run | Result | Notes |
|---|---|---|---|---|---|
| | | | | | Not yet run on a device. |
