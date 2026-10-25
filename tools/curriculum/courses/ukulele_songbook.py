"""Ukulele Songbook: every whole song of Songs, Standards & Classics and Originals in a ukulele key, the melody on
strings 1 to 3 and the chart in ukulele shapes (editions.py). Tunes the Ukulele course teaches stay there."""
from lib import course
import editions
from courses import songbook_sources

UNITS = editions.songbook(editions.UKULELE, songbook_sources.path(originals=True),
                          songbook_sources.instrument_course("ukulele"), editions.SUMMARIES, songbook_sources.REPORT)

COURSE = course("ukulele-songbook", "Ukulele Songbook", "The whole songbook in ukulele keys, start to finish",
                "ukulele.soprano.4", "music.note.list", "coral", UNITS)
