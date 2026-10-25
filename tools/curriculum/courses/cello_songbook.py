"""Cello Songbook: the folk songs, carols and classical themes of Songs and Standards & Classics in cello keys, a twelfth
below the violin's, in first position (editions.py). Tunes the Cello course teaches stay there."""
from lib import course
import editions
from courses import songbook_sources

UNITS = editions.songbook(editions.CELLO, songbook_sources.path(originals=False),
                          songbook_sources.instrument_course("cello"), editions.SUMMARIES, songbook_sources.REPORT)

COURSE = course("cello-songbook", "Cello Songbook", "Folk songs, carols and classical themes in first position",
                "cello.standard.4", "music.note.list", "orchid", UNITS)
