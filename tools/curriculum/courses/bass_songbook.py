"""Bass Songbook: a root-and-fifth line under every chord chart of Songs, Standards & Classics and Originals, in the
band's key (editions.bass_edition). Tunes the Bass course teaches stay there."""
from lib import course
import editions
from courses import songbook_sources

UNITS = editions.songbook("bass", songbook_sources.path(originals=True),
                          songbook_sources.instrument_course("bass"), editions.SUMMARIES, songbook_sources.REPORT)

COURSE = course("bass-songbook", "Bass Songbook", "Roots and fifths under every song in the book",
                "bass.electric.4", "music.note.list", "lime", UNITS)
