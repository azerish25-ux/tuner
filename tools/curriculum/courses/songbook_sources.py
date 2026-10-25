"""The song collections an instrument songbook draws on (editions.py), in the order its path takes them: first songs
and folk favorites, then the Originals and Standards in step with each other, classical themes and carols later.
Not a course itself (no COURSE): the songbook courses import it."""
import importlib

# Unit ids in path order. Originals (today's styles, sung and strummed) belong to the chord instruments' books.
WITH_ORIGINALS = ["songs-1", "songs-2", "orig-1", "std-1", "orig-5", "std-5", "song-u4", "orig-6", "std-2", "songs-3",
                  "orig-2", "std-6", "std-3", "orig-7", "song-u5", "std-7", "orig-3", "std-4", "orig-8", "song-u6",
                  "std-8", "orig-9", "std-9", "orig-4", "orig-10"]
TRADITIONAL = [u for u in WITH_ORIGINALS if not u.startswith("orig-")]

# What each edition did with each song (key, octave moves), for `build.py --editions`.
REPORT: list[str] = []


def _units():
    found = {}
    for module in ("songs", "songs_part3", "originals"):
        course = importlib.import_module(f"courses.{module}").COURSE
        for unit in course["units"]:
            found[unit["id"]] = unit
    return found


def path(originals):
    units = _units()
    return [units[uid] for uid in (WITH_ORIGINALS if originals else TRADITIONAL) if uid in units]


def instrument_course(module):
    return importlib.import_module(f"courses.{module}").COURSE
