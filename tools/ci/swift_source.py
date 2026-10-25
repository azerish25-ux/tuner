"""Splits Swift source into code, string literals and comments.

The hygiene lint (lint_tells.py) and the comment sweep (sweep_comments.py) read comments as comments and code as
code: a review reference inside a string literal is copy, not a comment, and `IconOrb(` inside a comment is prose.

    code, comments = scan(source)

`code` is the source with every comment and every string literal's text replaced by spaces (newlines are kept, so
offsets and line numbers match the source). Interpolated expressions inside strings stay as code. `comments` lists
each comment as a `Comment` with its offsets and first line.

Handles `//` and `///` line comments, nested `/* … */` block comments, plain, multi-line (`\"\"\"`) and raw
(`#"…"#`) strings, and interpolations (`\\( … )`, `\\#( … )`) that contain strings or comments of their own.
"""
from __future__ import annotations

import bisect
import re
from dataclasses import dataclass

_RAW_OPEN = re.compile(r'#+"')


@dataclass(frozen=True)
class Comment:
    start: int  # offset of the first character of the comment marker
    end: int    # offset just past the comment (a line comment stops before its newline)
    line: int   # 1-based line of `start`
    text: str   # the comment, markers included

    @property
    def is_line(self) -> bool:
        return self.text.startswith("//")


class _Scanner:
    def __init__(self, source: str):
        self.s = source
        self.n = len(source)
        self.mask = list(source)
        self.spans: list[tuple[int, int]] = []

    def blank(self, a: int, b: int) -> None:
        mask = self.mask
        for k in range(a, b):
            if mask[k] != "\n":
                mask[k] = " "

    def code(self, i: int, in_interpolation: bool) -> int:
        """Scans code from i. Inside an interpolation, returns the offset of the `)` that closes it."""
        s, n = self.s, self.n
        depth = 0
        while i < n:
            c = s[i]
            if c == "/" and s.startswith("//", i):
                j = s.find("\n", i)
                j = n if j < 0 else j
                self.spans.append((i, j))
                self.blank(i, j)
                i = j
            elif c == "/" and s.startswith("/*", i):
                j, level = i + 2, 1
                while j < n and level:
                    if s.startswith("/*", j):
                        level, j = level + 1, j + 2
                    elif s.startswith("*/", j):
                        level, j = level - 1, j + 2
                    else:
                        j += 1
                self.spans.append((i, j))
                self.blank(i, j)
                i = j
            elif c == '"' or (c == "#" and _RAW_OPEN.match(s, i)):
                i = self.string(i)
            elif in_interpolation and c == "(":
                depth += 1
                i += 1
            elif in_interpolation and c == ")":
                if depth == 0:
                    return i
                depth -= 1
                i += 1
            else:
                i += 1
        return i

    def string(self, i: int) -> int:
        """Scans a string literal that starts at i (at its first `#` or quote); returns the offset just past it."""
        s, n = self.s, self.n
        hashes = 0
        while s[i] == "#":
            hashes += 1
            i += 1
        multiline = s.startswith('"""', i)
        quote = '"""' if multiline else '"'
        i += len(quote)
        close = quote + "#" * hashes
        escape = "\\" + "#" * hashes
        start = i
        while i < n:
            if s.startswith(close, i):
                self.blank(start, i)
                return i + len(close)
            if s.startswith(escape, i):
                j = i + len(escape)
                if j < n and s[j] == "(":
                    self.blank(start, i)
                    end = self.code(j + 1, True)
                    i = min(end + 1, n)
                    start = i
                    continue
                i = j + 1
                continue
            if not multiline and s[i] == "\n":
                break  # unterminated: resynchronise on the next line
            i += 1
        self.blank(start, i)
        return i


def scan(source: str) -> tuple[str, list[Comment]]:
    scanner = _Scanner(source)
    scanner.code(0, False)
    starts = line_starts(source)
    comments = [Comment(a, b, line_of(starts, a), source[a:b]) for a, b in sorted(scanner.spans)]
    return "".join(scanner.mask), comments


def line_starts(source: str) -> list[int]:
    starts = [0]
    for match in re.finditer("\n", source):
        starts.append(match.end())
    return starts


def line_of(starts: list[int], offset: int) -> int:
    """1-based line number of `offset`, given `line_starts(source)`."""
    return bisect.bisect_right(starts, offset)
