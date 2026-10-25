# Timbre song licensing playbook

How Timbre gets from public-domain songs and originals to real, licensed popular songs without risking the App Store listing.
Researched October 2026. Bracketed numbers point to the sources at the end.

> **This is not legal advice.** It is a business playbook. Have a music-licensing attorney review the term sheet before you sign anything.

## Next 30 days

- [ ] **Keep the catalog clean.** Ship no copyrighted melodies, lyrics, charts or song titles until a signed license covers them. Keep the `tools/curriculum/STYLE.md` public-domain rule and tighten it as described in section 6.
- [ ] **Record where every song comes from.** Add these fields to each song in the curriculum build: composer, lyricist, translator and arranger with their death years, the edition you transcribed from and its year, and the legal basis for each territory (PD-US, PD-life+70, or Original with its contract ID). Make `build.py --check` fail when any field is missing.
- [ ] **Paper the 20 Originals.** Get a signed work-made-for-hire or assignment agreement from every person who contributed (composition, lyrics, arrangement, any recorded stems), including a warranty that nothing was copied. Where AI drafted a song, keep dated records of the human edits. US law protects only human authorship [39].
- [ ] **Keep Your Songs (ChordPro import) user-only.** Charts stay on the device. Bundle no charts, add no in-app search or URL import from tab or lyrics sites, and add no public gallery. Add a Terms clause saying users import only charts they have the right to use.
- [ ] **Don't sync a highway to Apple Music.** Shelve any plan that times the highway, chords or lyrics to Apple Music playback (section 2). If Apple Music matters to the roadmap, email Apple's MusicKit team and get its answer in writing.
- [ ] **Build the licensing plumbing before signing anything.** Each song needs a per-storefront territory allowlist (StoreKit `Storefront.current.countryCode`), a license start and end date, a remote kill switch, and a server-side usage ledger (song, territory, tier, plays, seconds). Publishers require all of it, and licensed songs do get pulled [36].
- [ ] **Book 1–2 hours with a music-licensing attorney.** Have them review this plan and draft a one-page term sheet you can send to indie rightsholders (section 4). Budget roughly $300–600 per hour; this is an estimate.
- [ ] **Build an outreach list.** List 15 emerging artists or self-published writers who control 100% of their songs, plus 10 independent publishers or administrators. Write a one-page pitch with your user numbers, territories and the exposure you offer.
- [ ] **Ask the aggregators and lyric providers for quotes.** Contact Hal Leonard (Muse Group) business development, Musicnotes "Official Licensing", LyricFind sales and Musixmatch business. Ask about licensing digital arrangements and lyrics into an interactive learning app, and ask for their minimums. Treat this as fact-finding only.
- [ ] **Add a "Request a song" button.** It collects demand data (song, country) that you can show publishers later.

## 1. Which rights each feature needs

A song has two copyrights. The **composition** (melody, harmony, lyrics) belongs to the songwriters and their publishers. The **master** (one specific recording) belongs to a label. Timbre synthesizes its own audio, so it needs composition rights only, unless it ever uses original recordings.

| Timbre feature | Rights needed | Who grants them | Do collective licenses cover it? |
|---|---|---|---|
| Melody, notation or tab on the highway or sheet | Print/display ("graphic") rights plus the arrangement (adaptation) right in the composition | The publishers, or their print licensee (for example, Hal Leonard holds the North American print rights for UMPG and Disney [16]) | No. HFA does not license print [6]. PROs license performance only. |
| Chord chart without lyrics | US courts treat common chord progressions as unprotectable building blocks [23]. Chordify relies on this and removes songs on request [22]. The title and the "song identity" still invite publisher objections. | — | Gray zone: acceptable for user imports, not as a bundled commercial catalog without counsel's sign-off |
| Lyrics (static, or timed karaoke-style) | Lyric display/reprint rights, plus timed "sync" display. You need 100% of the shares: one missing co-publisher blocks the song [11]. | The publishers directly, or LyricFind or Musixmatch sublicensing them [11][12] | No |
| Synthesized backing band playing in time with the highway and lyrics | Reproduction, arrangement and timed audiovisual use. In *Leadsinger v. BMG* (9th Cir. 2008), the court treated karaoke as an audiovisual work: a compulsory mechanical license was not enough, and both a reprint and a sync license were required [5]. | The publishers, in a direct "interactive education" grant | No. The MLC blanket license is US-only and covers audio, not audiovisual uses [7]. UK PRS LOML and Germany's GEMA exclude sync and adaptations [8][10]. HFA issues no sync licenses [6]. |
| Public performance of the audio | On-device playback for one user is arguably private, but streaming audio from a server can be a public performance (in the EU, a "communication to the public"). The law is unsettled. | PROs/CMOs (ASCAP, BMI, PRS, GEMA, SACEM), or the publisher if it grants "all-in" | Partly. Ask each publisher to confirm in writing that its grant is all-in, or to name the PRO carve-out. |
| Original recordings, stems or "play with the real band" | A master license from the label **and** the composition rights above | Labels. Usually out of reach: Fender Songs needed Warner Music Group for masters plus Sony/ATV, Warner Chappell, Kobalt and BMG for publishing [4]. | No |
| Artist name, photo or cover art, "learn Billie Eilish" marketing | Name and likeness, trademark, and label approval. Apple allows cover art only alongside playback [1]. | The artist, management or label | No |
| Lyrics translated into Timbre's 30+ languages | A translation is an adaptation and needs separate publisher approval | Publishers | No |

**The rule this table adds up to:** collective licenses (HFA, MLC, PROs, PRS, GEMA, ICE) are at most a complement for the audio. Every visual or interactive use is licensed **directly by the publishers**, one co-owner share at a time.

## 2. User-supplied content and Apple Music: what the "bring your own" apps rely on

- **OnSong / SongbookPro.** The app is a tool and the user supplies the files. Licensed content arrives only through the user's own license: OnSong's SongSelect (CCLI) integration requires the user's own SongSelect sign-in, caps downloads by subscription tier (typically 200 charts a year) and supports CCLI usage reporting [20].
- **Moises.** Users may upload only audio "you own or have legal permission to use". Moises refuses streaming links because streaming licenses allow playback only inside the streaming service [21].
- **Chordify.** It detects chords in hosted or uploaded audio and argues that chord progressions are not copyrightable. It removes songs on request and shows no lyrics [22]. This is a defensible position, but treat it as a risk posture, not a license.
- **Timbre "Your Songs".** This feature fits the OnSong model as long as charts stay private and on-device. If you ever add cloud sync **with sharing** or a public library, first register a DMCA agent ($6, renewed every three years [37]) and adopt a repeat-infringer policy. Add EU DSA notice-and-action before EU hosting.
- **Apple Music / MusicKit.** The App Review rules [1] and the developer agreement's MusicKit clause [2]:
  - Users must start playback, with standard play, pause and skip controls.
  - You may not charge for, or indirectly monetize, access to Apple Music, whether through IAP, ads or collecting user data. Never put Apple Music features behind the Timbre paywall.
  - You may not download, upload or **modify** MusicKit content. It "cannot be synchronized with any other content" unless Apple permits it [2].
  - Cover art and metadata may appear only alongside playback or playlists.
  - Guideline 4.5.2(ii): MusicKit "is not a replacement for securing the licenses" for deeper integration. To "play a specific song at a particular moment" you need sync or adaptation rights from the rightsholders [1].
  - Technically, MusicKit audio is DRM-protected and plays outside your audio graph. There are no buffers and no metering [3], so Timbre cannot detect pitch or chords from an Apple Music track.
  - **What is allowed:** a free "Listen on Apple Music" player or deep link on the song page, separate from lesson timing. **What is not allowed** without Apple's written permission plus publisher (and, for chords matched to the recording, label) licenses: a highway, chord lane, lyric scroll or score timed to the Apple Music track, or looping or slowing a section of it. Fender Songs is the precedent for what a sanctioned version took [4].

## 3. Who to contact

| Target | What they control | How to approach |
|---|---|---|
| **Major publishers**: Sony Music Publishing, Universal Music Publishing Group (UMPG), Warner Chappell, plus Kobalt and BMG | Roughly 60% of world publishing between the three majors [11]. Each holds fractional shares of most hits. | Contact each one's "Digital / New Business" licensing team through the licensing page on its site. Lead with data: users, territories, retention. Kobalt and BMG are usually the most open to tech (both licensed Fender Songs [4]). |
| **Hal Leonard**, part of Muse Group since December 2023 [16] | North American print rights for UMPG and Disney; huge arrangement catalog | Its business development team. Note that Muse Group also owns Ultimate Guitar and MuseScore, which are competitors. MuseScore's "Official Scores" (46,000+) are "licensed directly from" print publishers [17]. |
| **Alfred Music** | A major educational print publisher; bought Warner Bros. Publications in 2005 [19] | Ask which Warner Chappell titles it controls for print |
| **Musicnotes** | Official digital sheet-music arrangements; publisher relationships | Its "Official Licensing" and publisher pages [18]. Ask about sublicensing arrangements into apps. |
| **LyricFind** | Lyrics from all majors since 2012. Since 2014 it is the sole third party licensing UMPG lyrics, including display and sync, to apps [12]. | Sales: lyrics only, quote-based, with territory limits |
| **Musixmatch** | Lyrics and synced lyrics. It holds an exclusive on Warner Chappell lyrics, according to LyricFind's 2025 antitrust suit [11]. | Business/API sales. The public API requires showing `lyrics_copyright`, adding a tracking script, honoring per-country restrictions and showing "powered by" attribution [13]. Never use "community key" wrappers. |
| **Chordal** (2026) | An API ("InstantClear") that issues masters-plus-publishing licenses directly from rightsholders. Its partners include Kobalt, Reservoir, Primary Wave, Wixen, Nettwerk, PIAS and Believe [29]. | It is built for sync in content. Ask whether it covers interactive learning; a fit is uncertain. |
| **Emerging and self-published artists** | 100% of their composition, and often the master | Deal with the writers directly. Admin services such as Songtrust don't hold sync rights; they forward requests to the writer [30]. |
| **Collectives (complement only)** | US: HFA (no print or sync) [6], the MLC (US audio-only blanket license) [7], and the PROs (ASCAP, BMI, SESAC, GMR: performance only). UK: PRS LOML, for services under £12.5k a year, from £193 + VAT, excluding sync and adaptations, and being replaced [8]. EU: ICE Licensr (PRS, STIM, GEMA repertoire; services under €250k) [9]; GEMA excludes adaptations and audiovisual production [10]. | Use these only if you stream audio and the publisher grants carve out performance |
| **Finding owners** | Song splits and publishers | ASCAP/BMI repertory searches, the MLC public search and HFA's lookup [6]. Confirm 100% of shares before you announce a song. |

## 4. Deal structures and realistic costs

**Public reference points** (there are no public rate cards for interactive education):
- Print royalties run about **20% of retail** for single sheets and **10–12%** for folios [25].
- In 2015, the publishers' deal with SoundCloud included about **$350k in recoupable advances plus MFN** clauses [26].
- In streaming, publishing gets about **25%** of royalties against about 75% for recordings. Newer deals, such as Kobalt's 2025 AI deal, push for "parity" backed by MFN [27].
- Subscription learning platforms such as MusicGurus split net revenue **pro rata by usage** across licensors [28].

**What an education-app deal usually contains:**
1. **Revenue-share pool.** A percentage of *net* subscription revenue (after Apple's 15% and taxes) is allocated pro rata by plays or minutes per song. It often carries a **per-song or per-subscriber minimum**.
2. **Advance or minimum guarantee.** A recoupable advance, often paid annually. Majors expect one; indie rightsholders often waive it.
3. **MFN.** If any rightsholder gets a better rate, everyone gets it. Set one standard rate card from day one so MFN never cascades.
4. **Reporting and audit.** Monthly or quarterly statements per song and territory (plays, subscribers, revenue), with audit rights typically reaching back 2–3 years. This is why you need the usage ledger.
5. **Scope.** The deal sets the term (1–3 years), territories, platforms (iOS, Android), formats (notation, tab, chords, lyrics, synthesized audio), approval of arrangements and lyric accuracy, credits, the takedown period after termination, and whether translation or user sharing is allowed.

**Planning estimates for Timbre at about $10k MRR (about $8.5k net).** These are our estimates, not quotes.

| Source | Likely terms | Realistic at $10k MRR? |
|---|---|---|
| Commissioned originals (work for hire) | $200–$1,000 per song, one-off, all rights owned | Yes. Keep doing this. |
| Production-music libraries | Standard licenses are sync licenses for one project. They usually bar remixing, adding lyrics and standalone use [31]. | Only with a custom "transcribe and arrange in-app" grant; otherwise skip |
| Emerging artist who owns 100% | $0–$1,000 per song, or 10–20% of the revenue the song earns, in exchange for in-app promotion | Yes. This is the best new lever. |
| Independent publishers or administrators | A rev-share pool plus a small minimum, perhaps $50–$200 per song per year | Yes, for 10–50 well-chosen songs |
| Hal Leonard, Musicnotes, LyricFind or Musixmatch (aggregators) | Annual minimums, likely in the four to five figures, plus rev-share | Marginal. Ask now, sign later. |
| Majors, publishing only | Advances, likely $10k–$50k+ per publisher, plus MFN and catalog-wide reporting | No, not before about $50k MRR or funding |
| Labels (masters) | Large advances, plus label approval of the product | No |

**Budget rule:** keep total content cost at or below about 15% of net revenue until licensed songs show they lift conversion. Track trial-to-paid conversion and retention for each song.

## 5. Staged plan

1. **Stage 0 (now): public domain, originals and user import.**
   - Harden provenance (section 6) and build the territory, kill-switch and ledger plumbing.
   - Grow Originals in today's styles, with human authorship and signed paperwork.
2. **Stage 1 (months 1–4): emerging artists.**
   - Sign 10–20 songs with artists who own the composition outright (and ideally the stems), using one all-rights agreement: notation, tab, chords, lyrics (including translations), synthesized playback, worldwide, 3 years, non-exclusive.
   - In return, offer an in-app artist page, "learn it from the artist" content and co-marketing. This mirrors how Yousician uses artist partnerships (Metallica in 2022, Billie Eilish in 2024 [35]), at indie scale.
3. **Stage 2 (months 3–9): independent publishers.**
   - Pitch the songs that teach well (I–IV–V rock, campfire pop, worship, folk) to independents. Use the standard rate card and the Stage 1 data.
   - Avoid songs co-owned by a major until you have that major.
4. **Stage 3 (at about $50k MRR or after funding): majors and aggregators.**
   - Approach the majors through their digital teams, or through Hal Leonard, Alfred or Musicnotes for arrangements and LyricFind or Musixmatch for lyrics.
   - Expect advances, MFN and audits. Launch a song only in territories where 100% is cleared.
5. **Stage 4 (optional): masters.**
   - Seek label deals only as a funded strategic move, or through artist partnerships that bring stems.

## 6. Guardrails for what Timbre ships now

**Public domain for worldwide distribution.** Clear every contributor: composer, lyricist, translator, arranger and editor.

| Region | Rule | Check |
|---|---|---|
| US | Published 1930 or earlier is PD as of 2026 [32] | Use a pre-1931 printed source, not a modern arrangement or recording |
| EU, UK and other life+70 countries | Every author died in 1955 or earlier. For songs with words, the term runs from the death of whichever of the lyricist and composer survived longer [33]. | Look up both death years |
| Longer terms | Mexico life+100, Côte d'Ivoire life+99, Colombia life+80 [34] | — |

- **The current STYLE.md bar holds.** "Composer died before 1930; words before 1929" is a sound conservative worldwide bar. Extend it to the lyricist, translator and arranger.
- **"Traditional" ≠ free.** Tunes such as "House of the Rising Sun" and "Scarborough Fair" are public domain, but their famous arrangements and modern lyric versions are not. Transcribe from the old source.
- **US-only public domain is a trap.** "Georgia on My Mind", "I Got Rhythm" and "Embraceable You" entered the US public domain in 2026 [32], but stay protected in the EU and UK for decades (Hoagy Carmichael died in 1981, Ira Gershwin in 1983). Skip them, or geo-gate them to the US storefront.
- **Translations.** Translate public-domain lyrics yourself. Never reuse a modern translation.

**Originals and sound-alikes**
- Write to the style, never to a song. Never brief a writer, or an AI, with "like [hit song]".
- Chord progressions and common rhythms are free [23]. Melody, lyrics, distinctive hooks and riffs are not.
- Before release, compare each Original's melody and title against the hits in its genre, and keep the comparison on file.
- Never imitate a famous singer's voice in demos or marketing (right of publicity [40]). Keep artist names out of App Store keywords and screenshots (guideline 5.2.1 [1]).

**User imports and sharing**
- Keep Your Songs private. Share posters and story cards for PD songs and Originals only. For licensed songs, share no lyrics, notation or cover art unless the license explicitly allows sharing.

**Red flags (don't)**
- **Scraping charts or lyrics.** Never scrape or bundle Ultimate Guitar, Songsterr or lyrics-site content. Publishers forced tab sites offline in 2005–06 [15], and Ultimate Guitar had to license from thousands of publishers and HFA [14]. Scraping also breaks guideline 5.2.2 [1].
- **Licensing shortcuts.** Never use unofficial lyric-API keys. Never ship "just one line" of copyrighted lyrics.
- **AI transcription.** AI transcriptions of copyrighted recordings still need print licenses; Songscription signed publisher deals in 2026 [38].
- **Partial clearance.** Never launch on fractional clearance or without territory gating. Peloton's unlicensed music led to a $150M+ publisher suit and the loss of thousands of classes [24].
- **Apple Music.** Never time anything to Apple Music playback, and never gate it behind the paywall [1][2].

## Sources

1. Apple, App Review Guidelines 4.5.2, 5.2.1–5.2.3 — https://developer.apple.com/app-store/review/guidelines/
2. Apple Developer Program License Agreement (MusicKit definitions; §3.3.6(D)) — https://developer.apple.com/support/terms/apple-developer-program-license-agreement/ ; clause summary — https://www.lawinsider.com/clause/musickit ; quoted §3.3.6(D) — https://developer.apple.com/forums/thread/838157
3. Apple Developer Forums: no MusicKit metering or buffers (2026) — https://developer.apple.com/forums/thread/852190 ; DRM, no raw audio — https://developer.apple.com/forums/thread/94329
4. Fender Songs and Apple Music (2019) — https://www.musicbusinessworldwide.com/fender-partners-with-apple-music-on-subscription-app-fender-songs/
5. *Leadsinger v. BMG*, 9th Cir. 2008 — https://www.loeb.com/en/insights/publications/2008/01/leadsinger-inc-v-bmg-music-publishing-et-al-usca__ ; https://www.copyright.gov/fair-use/summaries/leadsinger-bmgmusic-9thcir2008.pdf
6. HFA: no print licenses — https://help.harryfox.com/how-do-i-get-a-license-for-print-use ; no sync licenses — https://help.harryfox.com/how-do-i-get-a-license-for-print-sampling-public-domain-and-synchronization-use
7. Scope of the MLC blanket license — https://www.audiblemagic.com/2021/04/20/is-the-mlc-part-of-your-overall-licensing-strategy/
8. PRS LOML guide — https://www.prsformusic.com/-/media/files/prs-for-music/licensing/online-licensing/loml-guide
9. ICE Licensr — https://routenote.com/blog/this-new-simple-tool-from-ice-lets-small-companies-license-music-in-minutes/
10. GEMA general guide (exclusions) — https://www.gema.de/fileadmin/user_upload/dokumente/musiknutzer/information/Allgemeiner_Leitfaden_e.pdf
11. LyricFind v. Musixmatch (2025): fractional licensing, Warner Chappell exclusive — https://rightstech.substack.com/p/lyricfind-sues-rival-musixmatch-over
12. LyricFind and UMPG (2014) — https://www.hypebot.com/lyricfind-becomes-sole-3rd-party-representing-universal-music-publishing-groups-lyrics
13. Musixmatch API display requirements — https://www.jentic.com/apis/musixmatch
14. Ultimate Guitar licensing history — https://en.wikipedia.org/wiki/Ultimate_Guitar
15. The 2006 MPA crackdown — https://cdm.link/tab-and-lyric-sites-close-in-face-of-crackdown-by-publishers/ ; MXTabs (HFA deal 2007, became Songsterr 2011) — https://en.wikipedia.org/wiki/MXTabs
16. Hal Leonard joins Muse Group (Dec 2023) — https://www.halleonard.com/bin/CatMusegrouppr2023.pdf ; print rights — https://en.wikipedia.org/wiki/Hal_Leonard
17. MuseScore Official Scores — https://intercom.help/musescore/en/articles/8535898
18. Musicnotes licensing pages — https://www.musicnotes.com/content/
19. Alfred Music — https://en.wikipedia.org/wiki/Alfred_Music
20. OnSong and SongSelect — https://www.onsongapp.com/docs/interface/menubar/songs-menu/all-songs/add/songselectv2/
21. Moises on user content — https://help.moises.ai/hc/en-us/articles/18322457396508-How-do-streaming-services-work-and-why-can-t-we-accept-their-URL-links-on-Moises
22. Chordify's position — https://www.digitalmusicnews.com/2014/03/10/chordify/
23. Sheeran, 2nd Cir. Nov 2024 — https://copyrightlately.com/ed-sheeran-wins-copyright-appeal-5-things-to-know/
24. Peloton and the NMPA — https://www.venable.com/insights/publications/2020/07/legal-implications-of-syncing-copyrighted-music
25. Print royalty rates — https://trolley.com/learning-center/understanding-print-music-royalties-a-guide-for-music-business-professionals/
26. SoundCloud publisher deal (2015) — https://www.digitalmusicnews.com/2015/06/01/this-is-the-contract-soundcloud-is-about-to-sign-with-major-music-publishers/
27. Kobalt MFN and the publishing share (2025) — https://www.musicbusinessworldwide.com/kobalts-ai-suno-most-favored-nation-clause/
28. MusicGurus pro-rata royalties — https://musicgurus.com/blog/subscription-royalties
29. Chordal (2026) — https://shorefire.com/releases/entry/chordal-expands-global-partner-network-with-21-new-music-companies ; https://chordal.com/faq/index.html
30. Songtrust sync forwarding — https://help.songtrust.com/knowledge/what-is-sync-license-forwarding
31. Library licenses usually bar remixing or adding lyrics (Jamendo) — https://support-licensing.jamendo.com/individual-licenses ; CC elements — https://support-artist.jamendo.com/creative-commons-explained
32. US Public Domain Day 2026 — https://blog.archive.org/2026/01/01/welcome-to-the-public-domain-in-2026/
33. Directive 2011/77/EU, art. 1 — https://www.legislation.gov.uk/eudr/2011/77/article/1
34. Longest copyright terms — https://www.plagiarismtoday.com/2015/09/23/which-country-has-the-longest-copyright-term/
35. Yousician and Billie Eilish (2024) — https://www.billboard.com/pro/billie-eilish-hit-me-hard-yousician-music-deals
36. JustinGuitar app songs removed (2023) — https://community.justinguitar.com/t/app-songs-removed-again/224827/17
37. DMCA agent: $6, renewed every 3 years — https://www.jw.com/news/last-call-your-q4-dmca-agent-designation-reminder
38. Songscription publisher deals (2026) — https://www.aimusicpreneur.com/ai-tools-news/songscription-publisher-licensing-deals-play-anything-rebrand/
39. US Copyright Office AI report, Part 2 (Jan 2025) — https://ipwatchdog.com/2025/01/29/part-two-copyright-office-ai-report-says-creative-prompting-doesnt-constitute-authorship/
40. Voice and right of publicity — https://www.wardandsmith.com/article/the-voice-behind-the-brand-who-owns-what-you-hear

*Could not be read during research; verify directly:* sonymusicpub.com, warnerchappell.com/licensing, umusicpub.com, developer.musixmatch.com, lyricfind.com, and the full text of DPLA §3.3.6(D).
