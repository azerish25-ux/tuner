#!/usr/bin/env python3
"""Diagnostic identity contracts; native callback delivery remains a separate gate."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
COVER = (ROOT / "ios/Timbre/Songs/SongCover.swift").read_text()
SONGS = (ROOT / "ios/Timbre/Songs/SongsView.swift").read_text()


class SongCoverAuditIdentityTests(unittest.TestCase):
    def test_each_unmodified_title_line_has_a_stable_index(self):
        block = COVER.split("private func typeBlock(", 1)[1].split("private func catalogue(", 1)[0]
        self.assertIn('ForEach(Array(layout.fit.lines.enumerated()), id: \\.offset) { index, line in', block)
        self.assertIn('Text(verbatim: line)', block)
        self.assertIn('.accessibilityIdentifier(textIdentity + ".title.\\(index)")', block)
        self.assertIn('.foregroundStyle(art.ink)', block)
        self.assertNotIn('accessibilityHidden', block)
        self.assertNotIn('accessibilityLabel', block)
        self.assertNotIn('.prefix(', block)

    def test_catalogue_retains_its_text_and_role_ink(self):
        block = COVER.split("private func catalogue(", 1)[1].split("switch art.imprint", 1)[0]
        self.assertIn('Text(verbatim: String(format: "%02d", art.number))', block)
        self.assertIn('.accessibilityIdentifier(textIdentity + ".catalogue")', block)
        self.assertIn('art.field ? Palette.stage : Palette.ink', block)
        self.assertIn('.foregroundStyle(ink)', block)
        self.assertNotIn('accessibilityHidden', block)

    def test_same_song_in_different_shelves_has_different_context(self):
        self.assertIn('var identity: String? = nil', COVER)
        self.assertIn('identity ?? "song.cover.\\(art.seed)"', COVER)
        self.assertIn('identity: "songs.hero.\\(song.id).cover"', SONGS)
        self.assertIn('identity: "songs.upnext.\\(song.id).cover"', SONGS)
        self.assertIn('let source = Self.tileSource(song.lesson, shelf: shelf)', SONGS)
        self.assertIn('tileCover(song, art: art, access: access, identity: source + ".cover")', SONGS)
        self.assertIn('"songs.tile.\\($0).\\(lesson.id)"', SONGS)

    def test_identity_propagates_without_new_visibility_or_audit_rules(self):
        sleeve = SONGS.split('private func sleeve(', 1)[1].split('private func heroBackdrop(', 1)[0]
        tile = SONGS.split('private func tileCover(', 1)[1].split('private func progressBar(', 1)[0]
        self.assertIn('SongCover(art: art, corner: 8, identity: identity)', sleeve)
        self.assertIn('SongCover(art: art, locked: access != .play, identity: identity)', tile)
        for block in (sleeve, tile):
            self.assertNotIn('accessibilityHidden', block)
            self.assertNotIn('accessibilityLabel', block)
        audit = (ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()
        self.assertIsNone(re.search(r'case.*songs\.(?:hero|tile).*cover', audit))


if __name__ == '__main__':
    unittest.main()
