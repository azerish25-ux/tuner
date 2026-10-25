"""Violin Songbook: the folk songs, carols and classical themes of Songs and Standards & Classics in violin keys, in
first position (editions.py). Tunes the Violin course teaches stay there."""
from lib import course
import editions
from courses import songbook_sources

UNITS = editions.songbook(editions.VIOLIN, songbook_sources.path(originals=False),
                          songbook_sources.instrument_course("violin"), editions.SUMMARIES, songbook_sources.REPORT)

COURSE = course("violin-songbook", "Violin Songbook", "Folk songs, carols and classical themes in first position",
                "violin.standard.4", "music.note.list", "amber", UNITS)
