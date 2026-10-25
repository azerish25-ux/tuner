"""Mandolin Songbook: the folk songs, carols and classical themes of Songs and Standards & Classics in mandolin keys,
in first position, with the chart in mandolin shapes (editions.py). Tunes the Mandolin course teaches stay there."""
from lib import course
import editions
from courses import songbook_sources

UNITS = editions.songbook(editions.MANDOLIN, songbook_sources.path(originals=False),
                          songbook_sources.instrument_course("mandolin"), editions.SUMMARIES, songbook_sources.REPORT)

COURSE = course("mandolin-songbook", "Mandolin Songbook", "Folk songs, carols and classical themes in mandolin keys",
                "mandolin.standard.8", "music.note.list", "sky", UNITS)
