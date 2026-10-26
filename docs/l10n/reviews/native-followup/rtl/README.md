# Bounded RTL direction follow-up

Independent source-aware AI review of all **12** Persian non-identity
Latin-starting warnings, their current shared musical/quiz roles and exact text.
No live resource or registry was changed.

`corrections.json` proposes **11** source/old/new/hash-guarded formatting repairs:

- Eight root-plus-major/minor labels isolate only their Latin note token,
  including the whole `B♭` token. The Persian mode word remains outside.
- `G، B و D` isolates the three note tokens separately; the Persian conjunction
  remains outside. The list still serves both chord-family and melodic-note uses.
- Two creator credits isolate each complete Latin creator-name/date span. Persian
  credit connectors and the separate printed-in year remain unchanged outside.

These are **14 new balanced FSI/PDI pairs**, with **no RLM prefixes**, legacy
embeddings or overrides. Removing the new controls reproduces the old text
exactly. Every number, note, accidental, placeholder and line-break contract passes.

The original logical label order is preserved. No shared key is narrowed by adding
`آکورد` (chord) or `گام` (scale), which would be incorrect in some of its contexts.
The Persian suffix/conjunction/connector supplies the first outer strong character
after the Latin isolate is skipped, so additional U+200F is unnecessary.

The twelfth case, `G، C، D، G`, is intentionally LTR musical notation with localized
comma separators and no Persian prose. Its exact ordered sequence serves both a
play-along label and a progression distractor. It is accepted without forcing an
artificial RTL paragraph or adding an inappropriate noun.

## Hebrew helper false positives

All **22** mixed Latin-starting non-identity Hebrew values already isolate the
initial work/brand name. The first strong character outside those spans is Hebrew
R in every case. Representative source-aware cross-checks included the Soldier's
Joy card, brand-led Timbre prose and the multi-title Last Rose/Jupiter explanation.
`hebrew-direction-assessment.json` records every current target/hash and its result;
this is directional assessment, not a new full semantic certification.

[Unicode UAX #9 P2/P3](https://www.unicode.org/reports/tr9/#P2) excludes isolated
content from paragraph first-strong detection and derives RTL from outer R/AL.
The helper currently scans into isolates, so its starts-with-Latin warnings on
these strings are heuristic false positives. The new Persian strings will likewise
retain raw helper starts/marks advisories even though their isolate-aware base
direction is corrected. The evidence records that distinction instead of adding
redundant invisible prefixes merely to silence a scanner.

The code-point and paragraph-rule checks do not establish actual iOS glyph
shaping, text alignment, wrapping, VoiceOver behavior or native-human fluency.
Those require the parent's real device/simulator checks. This review does not
restate the parent's separate whole-table span audit as independently performed.
