"""Songs: public-domain melodies to play start to finish on guitar, easiest first."""
from lib import course

UNITS = []
for part in ("songs_part1", "songs_part2"):
    try:
        UNITS += __import__(f"courses.{part}", fromlist=["UNITS"]).UNITS
    except ModuleNotFoundError:
        pass

COURSE = course("songs", "Songs", "Play real melodies, start to finish", "guitar.acoustic.6", "music.quarternote.3", "amber", UNITS) if UNITS else None
