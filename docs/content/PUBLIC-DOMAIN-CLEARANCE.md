# Public-domain clearance: Standards & Classics

The Standards & Classics course (`tools/curriculum/courses/songs_part3.py`, course id `standards`) ships in every App Store territory, so a song is in only if it clears **both** tests:

1. **First published before 1931.** It is in the US public domain as of 1 January 2026.
2. **Every creator whose work we use died before 1956, or the work is traditional or anonymous.** That covers life + 70 countries.

We use only the traditional or original melody and the original public-domain words. We never use a later arrangement, a later lyric or a translation still in copyright. Every key, chord chart, intro, solo, variation and song structure in the course is our own.

Anything doubtful is out. This is research for the product team, not legal advice. Have counsel review it before release.

## Margins beyond the two tests

- **Death years.** The latest death among creators of the material we use is 1935 (Harold Boulton). The next latest is 1932 (Sousa). Everyone else died in 1924 or earlier.
- **Spain and Colombia (life + 80).** Spain applies life + 80 to authors who died before 1987, and Colombia applies life + 80 too. Both are cleared, since every creator died before 1946.
- **US-origin works.** Most countries compare their own term with the term in the country of origin, and apply the shorter one. The US term on works first published there before 1931 (Foster's era through Joplin and Sousa) has already run out.
- **Mexico (life + 100).** Mexico's term is life + 100, but the 2003 extension did not bring expired works back into copyright.

## Sources and how melodies were checked

**Rights facts.** Each song's publication year and its creators' death years come from the sources linked in its row of the table. These are Wikipedia articles, plus the Kansas Historical Society and Mutopia composer records where Wikipedia gives no dates.

**Melodies.** Where a "Melody checked against" link is given, the arrangement's pitches and rhythms were checked against that public-domain edition or transcription. The editions come from four places:

- the Mutopia Project (public-domain scores reset in LilyPond)
- the Traditional Tune Archive
- folkinfo, which uses BBC "Singing Together" transcriptions
- German Wikibooks' Liederbuch

We took only the melody, which is the public-domain work itself. We copied no engraving, chord chart or arrangement.

**Melodies from memory.** Four tunes were written from the standard tune without an online cross-check: Korobeiniki, Can-can, Morning Mood and O Christmas Tree. A musician should play them through once before release.

## Shipped: 18 songs

| # | Song | First published | Creators and their death years | What we use | Rights source | Melody checked against | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | She'll Be Coming 'Round the Mountain | Spiritual "When the Chariot Comes", 1899; secular words printed in Sandburg's *American Songbag*, 1927 | Traditional (Sandburg compiled it; he didn't write it) | Tune and three traditional verses (coming / driving six white horses / we'll all go out to meet her) | [Wikipedia](https://en.wikipedia.org/wiki/She%27ll_Be_Coming_%27Round_the_Mountain) | [Traditional Tune Archive](https://tunearch.org/wiki/Coming_%27Round_the_Mountain) | Cleared |
| 2 | Down by the Riverside | *Plantation Melodies*, Rodeheaver, Chicago, 1918 | Traditional spiritual, before the Civil War | Tune and traditional verses ("burden", "walk with the Prince of Peace") and chorus. The "sword and shield" verse is left out for the 4+ age rating (see below) | [Wikipedia](https://en.wikipedia.org/wiki/Down_by_the_Riverside) | [Wikibooks Liederbuch](https://de.wikibooks.org/wiki/Liederbuch/_Down_by_the_riverside) | Cleared |
| 3 | Loch Lomond | *Vocal Melodies of Scotland*, 1841 | Traditional (authorship only attributed) | Tune, first verse and chorus | [Loch Lomond & Trossachs NP](https://lochlomondtrossachs.org.uk/loch-lomond-song), [Univ. of Otago](https://www.otago.ac.nz/library/exhibitions/insearchofscotland/cabinet8-2.html) | [Traditional Tune Archive](https://tunearch.org/wiki/Bonnie_Banks_o%27_Loch_Lomond_(The)) | Cleared |
| 4 | Molly Malone | Boston, *Carmina Collegensia*, 1876; London, 1884 | James Yorkston, 1839–1906 (the 1884 arranger, Edmund Forman, is not used) | Tune and three verses with chorus | [Wikipedia](https://en.wikipedia.org/wiki/Molly_Malone), [Yorkston's dates](https://threadinburgh.scot/2022/10/24/the-thread-about-what-links-a-victorian-gas-meter-collector-from-abbeyhill-a-german-sheet-music-publisher-and-an-irish-cultural-anthem/) | [folkinfo 618](https://folkinfo.mainlynorfolk.info/songs/618.html) | Cleared |
| 5 | The Water Is Wide | Cecil Sharp, *Folk Songs from Somerset*, 1906 (verses from 1724 onward) | Traditional; Cecil Sharp, 1859–1924 | Sharp's tune and two of his verses (Britten's 1948 and Rutter's 1973 arrangements are not used) | [Wikipedia](https://en.wikipedia.org/wiki/The_Water_Is_Wide_(song)) | [Traditional Tune Archive](https://ttadev.org/wiki/Annotation:Water_is_Wide_(The)) | Cleared |
| 6 | All Through the Night (Ar Hyd y Nos) | Edward Jones, *Musical and Poetical Relicks of the Welsh Bards*, 1784; English words 1884 | Tune traditional (Edward Jones, 1752–1824, printed it); words Harold Boulton, 1859–1935 | Tune and Boulton's two verses (the 1970 Pratt Green hymn text is not used) | [Wikipedia](https://en.wikipedia.org/wiki/Ar_Hyd_y_Nos) | [Traditional Tune Archive](https://tunearch.org/wiki/Ar_H%C5%B7d_y_N%C3%B4s) | Cleared |
| 7 | The Skye Boat Song | *Songs of the North*, London, 1884 | Words Harold Boulton, 1859–1935; tune collected by Anne Campbell MacLeod, 1855–1921 | Boulton's chorus and two verses (Stevenson's 1892 words and the 2014 Outlander adaptation are not used) | [Wikipedia](https://en.wikipedia.org/wiki/The_Skye_Boat_Song), [Boulton's dates](https://timothyades.com/sir-harold-boulton-bt-1859-1935-skye-boat-song/) | [Wikibooks Liederbuch](https://de.wikibooks.org/wiki/Liederbuch/_The_Skye_Boat_Song) | Cleared |
| 8 | O Christmas Tree (O Tannenbaum) | Ernst Anschütz, *Musikalisches Schulgesangbuch*, Leipzig, 1824 | Words Ernst Anschütz, 1780–1861; folk tune, quoted in 1605 | Tune and Anschütz's three German verses (no English translation used) | [Wikipedia](https://en.wikipedia.org/wiki/O_Tannenbaum) | Standard folk tune, not cross-checked online | Cleared |
| 9 | O Come, All Ye Faithful (Adeste Fideles) | J. F. Wade, *Cantus Diversi*, 1751; English 1841 | J. F. Wade, 1711–1786; Frederick Oakeley, 1802–1880 | Tune, Oakeley's first verse and the Latin first verse | [Wikipedia](https://en.wikipedia.org/wiki/O_Come,_All_Ye_Faithful) | [Mutopia 367](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=367) | Cleared |
| 10 | The First Noel | Sandys, *Christmas Carols Ancient and Modern*, 1823 | Traditional (Cornish carol) | Tune only (instrumental) | [Wikipedia](https://en.wikipedia.org/wiki/The_First_Noel) | [Mutopia 1243](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=1243) | Cleared |
| 11 | Scotland the Brave | *Utah Musical Bouquet*, 1878; Scottish printing 1891 | Traditional | Tune only. The usual words (Cliff Hanley, about 1950) are excluded | [Wikipedia](https://en.wikipedia.org/wiki/Scotland_the_Brave) | [Traditional Tune Archive](https://ttadev.org/wiki/Scotland_the_Brave) | Cleared (tune only) |
| 12 | Korobeiniki | Nekrasov's poem, 1861; song published 1898 | Folk melody; words Nikolay Nekrasov, 1821–1878 (Prigozhy's 1898 arrangement is not used) | Folk melody only (instrumental). Not the 1989 video-game arrangement or its added slow bridge | [Wikipedia](https://en.wikipedia.org/wiki/Korobeiniki) | Standard folk tune, not cross-checked online | Cleared (folk melody only) |
| 13 | The Blue Danube | First performed 1867 | Johann Strauss II, 1825–1899 | Main waltz theme (instrumental) | [Wikipedia](https://en.wikipedia.org/wiki/The_Blue_Danube), [Strauss's dates](https://nli.org.il/en/authorities/987007581250405171) | [Mutopia 519](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=519) | Cleared |
| 14 | Can-can (Galop infernal) | *Orpheus in the Underworld*, 1858 | Jacques Offenbach, 1819–1880 | Main galop theme (instrumental) | [Wikipedia](https://en.wikipedia.org/wiki/Orpheus_in_the_Underworld) | Standard theme, not cross-checked online | Cleared |
| 15 | The Entertainer | 1902 (copyright 29 December 1902) | Scott Joplin, 1868–1917 | First strain (instrumental). Not Hamlisch's 1973 film adaptation | [Wikipedia](https://en.wikipedia.org/wiki/The_Entertainer_(rag)), [Joplin's dates](https://en.wikipedia.org/wiki/Maple_Leaf_Rag) | [Mutopia 263](https://www.ibiblio.org/mutopia/cgibin/piece-info.cgi?id=263) | Cleared |
| 16 | The Liberty Bell | 1893 | John Philip Sousa, 1854–1932 | First strain and trio (instrumental) | [Wikipedia](https://en.wikipedia.org/wiki/The_Liberty_Bell_(march)), [Sousa's dates](https://en.wikipedia.org/wiki/John_Philip_Sousa) | [Mutopia 625](https://www.ibiblio.org/mutopia/cgibin/piece-info.cgi?id=625) | Cleared |
| 17 | Carmen: Prelude (with the Toreador Song tune) | *Carmen*, 1875; Schirmer piano edition, 1895 | Georges Bizet, 1838–1875 (no libretto words used) | Opening march and Toreador tune (instrumental) | [Habanera article](https://en.wikipedia.org/wiki/Habanera_(aria)), [Toreador Song](https://en.wikipedia.org/wiki/Toreador_Song) | [Mutopia 635](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=635) | Cleared |
| 18 | Morning Mood (Peer Gynt) | Written 1875; suite published 1888 | Edvard Grieg, 1843–1907 | Main theme (instrumental) | [Wikipedia](https://en.wikipedia.org/wiki/Morning_Mood), [Grieg's dates](https://www.ibiblio.org/mutopia/cgibin/piece-info.cgi?id=246) | Standard theme, not cross-checked online | Cleared |

Nine of the 18 carry words: songs 1–9.

## Cleared but not shipped yet

The rights on these check out. What's missing is a trustworthy melody reference, or the piece doesn't fit a one-line guitar take. Each could be added once a public-domain edition is checked note by note.

| Song | First published | Creators and their death years | Why it's held back | Rights source |
|---|---|---|---|---|
| Home on the Range | Poem 1873; Lomax text 1910; sheet music 1925 | Brewster Higley, 1823–1909; Daniel Kelley, 1843–1905 | No checkable melody transcription found. Guion's 1925 arrangement must not be used | [Wikipedia](https://en.wikipedia.org/wiki/Home_on_the_Range), [Kansas Historical Society](https://www.kansashistory.gov/kansapedia/brewster-higley/18138) |
| My Bonnie Lies Over the Ocean | 1881 | Charles E. Pratt, 1841–1902 | Chorus melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Charles_E._Pratt) |
| Swing Low, Sweet Chariot | Fisk Jubilee Singers' songbooks, 1872–1873 | Wallace Willis, about 1820–1880 | Melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Wallace_Willis) |
| Battle Hymn of the Republic | *Atlantic Monthly*, February 1862 | Julia Ward Howe, 1819–1910; tune "Say, Brothers", camp-meeting, about 1856 (credited to William Steffe) | Melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Battle_Hymn_of_the_Republic) |
| When Johnny Comes Marching Home | September 1863 | Patrick Gilmore, 1829–1892 | Tune Archive version is a fiddle setting that doesn't fit the words | [Wikipedia](https://en.wikipedia.org/wiki/Patrick_Gilmore) |
| Go Tell It on the Mountain | 1907–1909 | John Wesley Work Jr., 1871–1925 | Melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Go_Tell_It_on_the_Mountain_(song)) |
| Beautiful Dreamer | 1864 | Stephen Foster, 1826–1864 | Melody (9/8) not verified | [Wikipedia](https://en.wikipedia.org/wiki/Beautiful_Dreamer) |
| Hard Times Come Again No More | 1854 | Stephen Foster | Melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Hard_Times_Come_Again_No_More) |
| Daisy Bell | 1892 | Harry Dacre, 1857–1922 | Verse melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Harry_Dacre) |
| Let Me Call You Sweetheart | 1910 | Leo Friedman, 1869–1927; Beth Slater Whitson, 1879–1930 | Melody not verified | [Friedman](https://en.wikipedia.org/wiki/Leo_Friedman), [Whitson](https://en.wikipedia.org/wiki/Beth_Slater_Whitson) |
| Funiculì, Funiculà | 1880 (Ricordi) | Luigi Denza, 1846–1922; Peppino Turco (death year not confirmed in our sources) | Verse melody not verified; Turco's death year still to confirm | [Wikipedia](https://en.wikipedia.org/wiki/Funicul%C3%AC,_Funicul%C3%A0) |
| The Stars and Stripes Forever | 1897 | J. P. Sousa, 1854–1932 | No edition found to check against. The 1942 Tidmarsh lyrics and the "web-footed friends" parody must not be used | [Wikipedia](https://en.wikipedia.org/wiki/The_Stars_and_Stripes_Forever) |
| Pomp and Circumstance March No. 1 | 1901 | Edward Elgar, 1857–1934 | No edition found to check against | [Elgar](https://en.wikipedia.org/wiki/Edward_Elgar) |
| William Tell Overture (finale) | 1829 | Gioachino Rossini, 1792–1868 | No edition found to check against | [Wikipedia](https://en.wikipedia.org/wiki/William_Tell_Overture) |
| Habanera (Carmen) | 1875; based on Yradier's "El Arreglito", 1863 | Bizet, 1838–1875; Sebastián Iradier, died about 1865 | No edition found to check against | [Wikipedia](https://en.wikipedia.org/wiki/Habanera_(aria)) |
| Swan Lake (theme) | Premiered 1877 | Tchaikovsky, 1840–1893 | Only the first phrase is certain | [Wikipedia](https://en.wikipedia.org/wiki/Swan_Lake) |
| Maple Leaf Rag | 1899 | Scott Joplin | Checked ([Mutopia 23](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=23)), but the tune is broken piano chords with rests and doesn't make a playable single line | [Wikipedia](https://en.wikipedia.org/wiki/Maple_Leaf_Rag) |
| The Washington Post | 1889 | J. P. Sousa | Checked ([Mutopia 1321](https://sca.uwaterloo.ca/Mutopia/cgibin/piece-info.cgi?id=1321)); held for a later round (The Liberty Bell covers Sousa) | as above |
| Gymnopédie No. 1 | 1888 | Erik Satie, 1866–1925 | The Mutopia extraction's octaves were unreliable after bar 21 | [Mutopia 37](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=37) |
| Aloha ʻOe | Written about 1878; recorded 1898 | Liliʻuokalani, 1838–1917 | Melody not verified; Hawaiian text needs a native-speaker check | [Wikipedia](https://en.wikipedia.org/wiki/Aloha_%CA%BBOe) |
| Early One Morning | Chappell, *National English Airs*, about 1855–1859 | Traditional | Melody not verified | [Wikipedia](https://en.wikipedia.org/wiki/Early_One_Morning) |

## Excluded

These fail a test, or are doubtful enough to leave out. Where no link is given, the facts come from general knowledge and were not looked up again. In each of those cases the doubt alone is enough to exclude the song.

| Song | Problem | Verdict |
|---|---|---|
| Wellerman | Text first published in the 1970s (a New Zealand folk-song collection), so it was not published before 1931 | Excluded |
| The House of the Rising Sun | The familiar melody and arrangement come from The Animals (1964), and the earliest recordings date from the 1930s. No pre-1931 printing of the tune people know | Excluded |
| Scarborough Fair | Older printed tunes differ from the one everyone knows, which comes from mid-20th-century folk-revival singers. We found no pre-1931 printing of it | Excluded as doubtful |
| Happy Birthday to You | The melody ("Good Morning to All", 1893; Mildred Hill, died 1916, and Patty Hill, died 1946) is clear. The "Happy Birthday" words' authorship and first publication were litigated (US, 2015). Patty Hill's death in 1946 also leaves life + 80 countries protected through 2026 | Excluded as doubtful |
| This Little Light of Mine | Often credited to Harry Dixon Loes (about 1920; died 1965) | Excluded as doubtful |
| Kumbaya | Authorship claimed by Marvin Frey (1936; died 1992). The 1920s field recordings were unpublished | Excluded as doubtful |
| The Wild Rover | The words are old ([Wikipedia](https://en.wikipedia.org/wiki/The_Wild_Rover)), but we found no pre-1931 printing of the "no, nay, never" tune now sung | Excluded as doubtful |
| Whiskey in the Jar | The words now sung follow Colm Ó Lochlainn's *Irish Street Ballads* (1939). It is unclear whether Joyce's 1909 tune is the familiar one ([Wikipedia](https://en.wikipedia.org/wiki/Whiskey_in_the_Jar)) | Excluded as doubtful |
| The Wayfaring Stranger | Words printed 1858, but we found no pre-1931 printing of the melody ([Wikipedia](https://en.wikipedia.org/wiki/The_Wayfaring_Stranger_(song))) | Excluded as doubtful |
| Waltzing Matilda | The creators died by 1941 (Paterson, 1941; Macpherson, 1936; Cowan, 1919), and the 1903 version is public domain in most places. But royalties were collected on it as late as 1996, and US arrangement claims remain ([Wikipedia](https://en.wikipedia.org/wiki/Waltzing_Matilda)) | Excluded as doubtful |
| La Cucaracha | Traditional, but we found no pre-1931 printing of the familiar melody ([Wikipedia](https://en.wikipedia.org/wiki/La_Cucaracha)) | Excluded as doubtful |
| Take Me Out to the Ball Game (1908) | Jack Norworth died 1959 and Albert Von Tilzer died 1956: fails life + 70 | Excluded |
| St. Louis Blues (1914); "Careless Love" in Handy's 1921 "Loveless Love" form | W. C. Handy died 1958: fails life + 70 | Excluded |
| I'll Fly Away (1929/1932) | Albert E. Brumley died 1977 | Excluded |
| Kookaburra Sits in the Old Gum Tree (1932) | Marion Sinclair died 1988; published after 1930 | Excluded |
| Cielito Lindo (1882) | Quirino Mendoza y Cortés died 1957: fails life + 70 until 2028 | Excluded |
| 'O Sole Mio (1898) | An Italian court (2002) named Alfredo Mazzucchi, who died 1972, as co-composer | Excluded |
| Hava Nagila | Lyric authorship disputed (Idelsohn, died 1938, against Nathanson, died 1981) | Excluded as doubtful |
| Boléro (Ravel, 1928) | Ravel died 1937, but his heirs claimed co-authorship for Alexandre Benois, who died 1960. A French court rejected the claim in 2024 | Excluded as doubtful |
| O Fortuna (Orff, 1937); Sabre Dance (Khachaturian, 1942) | Published after 1930; composers died 1982 and 1978 | Excluded |
| Midnight Special, Frankie and Johnny, John Henry, Down in the Valley, Michael Row the Boat Ashore, He's Got the Whole World in His Hands, Will the Circle Be Unbroken | The well-known versions trace to 1920s–1950s recordings or arrangements whose creators or first printing we couldn't pin down | Excluded as doubtful |
| Red River Valley, Shenandoah, Danny Boy, Silent Night, Jingle Bells, Deck the Halls, Auld Lang Syne, In the Hall of the Mountain King, Ode to Joy | Already in the curriculum | Skipped as duplicates |

## The 4+ age rating: content changes in every course

Timbre answers Apple's age-rating questionnaire for 4+ (`docs/ios/APP-STORE-LISTING.md`, Age rating). Apple's 4+ allows no reference to alcohol, tobacco or drugs, and no reference to guns or other weapons. It also allows no profanity, horror, suggestive theme, violence or gambling. In October 2026 every title, lyric and lesson text in every course was checked against those rules. That covered the Songs, Originals and Standards courses and each instrument course's songs. These are the changes, and the songs that replace or fill in what was taken out. The rights tests are the same two as above.

### Replaced or changed

| Course | Song | Problem | Change |
|---|---|---|---|
| Songs, unit 2 | Drunken Sailor | Alcohol in the title and in every chorus line. "Shave his belly with a rusty razor" names a blade | Removed. Bobby Shafto takes its place (cleared below) |
| Songs, unit 5 | Good King Wenceslas | Neale's verse 3: "Bring me flesh, and bring me wine" | Sings Neale's verses 1, 2, 4 and 5 instead of 1, 2 and 3 (tempo 96 → 100 to stay under three minutes) |
| Standards, unit 1 | Down by the Riverside | "Gonna lay down my sword and shield" names a weapon | That verse is replaced by the traditional "Gonna walk with the Prince of Peace" (one of the verses in the Wikibooks Liederbuch edition the melody was checked against) |
| Originals | Jukebox Moon, Slow Motion Strobe, Roller Rink, Late Checkout, Cold Lake, Spray Paint Sunrise | Timbre's own words: "last call", "smoke in the air", "cherry pop", a "Do not disturb" sign, "somebody new in your bedroom", tagging names on a wall | Same syllables, cleaner words: "it's late", "hands in the air", "soda pop", "Postcards and maps by the door", "in your window", "painting a sun" |

### Songs added

| # | Song | First published | Creators and their death years | What we use | Rights source | Melody checked against | Verdict |
|---|---|---|---|---|---|---|---|
| A1 | Bobby Shafto (Songs, unit 2) | Words in print by 1805. The tune is in William Vickers' manuscript (Northumberland, 1770) and, as "Brave Willy Forster", in Henry Atkinson's manuscript (1694/95). Words and tune together in Bruce & Stokoe, *Northumbrian Minstrelsy*, Newcastle, 1882 | Traditional (Northumberland and Durham). Bruce and Stokoe only compiled it | Both strains of the tune. The second strain carries the words, and the first is played as the interlude. Words: the two Northumbrian verses ("gone to sea", "bright and fair"), with the spelling made standard ("gaen" → "gone", "siller" → "silver", "me awn" → "my own"; "for ever mair" kept for the rhyme). Not used: the Scottish set's "bairn" verse and the undated "tall and slim" verse | [Wikipedia](https://en.wikipedia.org/wiki/Bobby_Shafto%27s_Gone_to_Sea), [Traditional Tune Archive annotation](https://tunearch.org/wiki/Annotation:Bobby_Shaftoe_(1)) | [Traditional Tune Archive, Bobby Shaftoe (1)](https://tunearch.org/wiki/Bobby_Shaftoe_(1)): Bruce & Stokoe's 1882 setting, note for note. It is moved from B flat to G, and each 2/4 eighth note becomes a 4/4 quarter. The chords are our own | Cleared |
| A2 | Good King Wenceslas, verses 4 and 5 (Songs, unit 5) | Tune "Tempus adest floridum", *Piae Cantiones*, 1582. Words: Neale and Helmore, *Carols for Christmas-tide*, London, 1853 | Words John Mason Neale, 1818–1866 | Neale's verses 4 ("Sire, the night is darker now") and 5 ("In his master's steps he trod") on the existing arrangement | [Wikipedia](https://en.wikipedia.org/wiki/Good_King_Wenceslas), [Hymnology Archive](https://www.hymnologyarchive.com/good-king-wenceslas) | Melody unchanged. All 16 lines checked word for word against the five stanzas Wikipedia gives | Cleared |
| A3 | Down by the Riverside, "Prince of Peace" verse (Standards, unit 1) | As song 2 above | Traditional | The verse line, sung in the existing verse | As song 2 | [Wikibooks Liederbuch](https://de.wikibooks.org/wiki/Liederbuch/_Down_by_the_riverside) has this verse | Cleared |

### Kept after review

These were checked and left as they are. Under Apple's definitions, none of them raises the rating.

- "A cup o' kindness" (Auld Lang Syne) and "a cup of good cheer" (We Wish You a Merry Christmas) name no drink. Neither song uses Burns's "pint-stowp" verse.
- "Feuertrunken" in the German Ode to Joy is a figure of speech, "drunk with fire".
- Camptown Races sings "I'll bet my money on the bobtail nag". Apple's Gambling and Simulated Gambling questions are about betting in the app, and Timbre has none.
- Clementine, Molly Malone and Danny Boy mention a death, but none tells a frightening story.
- Amazing Grace's "he will my shield and portion be" (voice course) uses the shield as a figure of speech, not a weapon.
- Soldier's Joy is a fiddle tune with no words. One theory links its title to morphine, through a 1920s sung version that Timbre doesn't use. The Traditional Tune Archive lists "The King's Hornpipe" as a clean alternative title, if the owner wants one.
- Yankee Doodle, Loch Lomond and The Skye Boat Song give history (the Revolution, the Jacobites) only in their lesson notes. They have no fighting.

### Turned down as replacements

| Song | Problem |
|---|---|
| Spanish Ladies | Its last verse: "We'll drink and be jolly and drown melancholy" |
| Haul Away Joe | "Then he got his head cut off" (King Louis verse) |
| Blow the Man Down | To "blow a man down" is to knock him down, and the verses tell of a fight |
| Sailing, Sailing (Godfrey Marks, 1880) | The verse is a toast: "Then here's to the sailor" |
| Old King Cole | "He called for his pipe, and he called for his bowl" |
| Pop Goes the Weasel | "In and out the Eagle", a London pub |
| Oranges and Lemons | Ends with "a chopper to chop off your head" |

## Rules for anyone adding songs here

- Both tests, every creator. Check the composer, lyricist, translator and arranger of whatever you actually use.
- Use the original or traditional melody and words. A famous recording is not the song: it may carry its own copyright in the arrangement, the changed melody or new verses.
- Check the melody against a public-domain edition (Mutopia, IMSLP scans of pre-1931 printings, the Traditional Tune Archive). Copy no engraving or chord chart.
- Don't name trademarks in lesson text. Write "a video game", not the game's name, and "a British TV comedy", not the show's name.
- Keep the app 4+. A title or a single line can raise the rating, so no song may reference drink, smoke, drugs or weapons. It may have no innuendo, horror, gambling or swearing either. Leave out the verse rather than the song when only one verse has the problem, and add it to the 4+ tables above.
- Add a row here with its sources before the song ships.
