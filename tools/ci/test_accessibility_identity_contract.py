#!/usr/bin/env python3
"""Identifier source contracts, not evidence that XCTest exposes a hidden text node.

Run: python3 tools/ci/test_accessibility_identity_contract.py
Native hierarchy/callback inspection remains required before same-target filtering or scrolling.
"""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'ios/Timbre'
SEMANTIC_HASHES = {'Songs/SongsView.swift': '97c8d0b2e7f67059ba46de76cc3242f95aa4316d70b3daf8c2b5da627530a7d0',
 'YourSongs/YourSongsShelf.swift': '8f47e18e41ab5599c2b05c99e04e74fbf46cde7b066e27d7a463361cb628a993',
 'Journey/JourneyView.swift': 'ebfb16a206d83e6198c0074844446fd4192da63b23e7a12139bc4030313f3fcc',
 'Paywall/PaywallView.swift': '38d816bdbd86ae60b377e30e614633e815cd5742df6a85a1668a6b7faaffb98d',
 'Design/GameUI.swift': '77e11cf4b56f6c52fd96f254871244aa91f5e9bfb3bdf958fbc9ca22337ddb33',
 'Practice/PracticeView.swift': '1f8cfa4c5adfa47ee82c84c44c83ec07d5d3bf7b470a021b2730665219c6fcc2',
 'Design/Kit.swift': 'ffc543d3079b3c3ca9f324e0429ab8f4427e7ecbb4db14d7fc13bbd3f913addf',
 'Design/Components.swift': '86b9b3ad0288871603788d3a608bf6e9e7f1e713b3db67d0db0c96e6856a6f5a',
 'Journey/CoachCard.swift': '0d012a63fe9b9c35d6674781a9d1e03c8335965565845cc1f5f7d4a0d62130d9'}


def source(path):
    return (APP / path).read_text()


def semantics(text):
    names = r'accessibility(?:Label|Value|Hint|Element|Hidden|AddTraits|RemoveTraits|SortPriority)\('
    return '\n'.join(line.strip() for line in text.splitlines() if re.search(names, line))


class AccessibilityIdentityContractTests(unittest.TestCase):
    def test_accessible_labels_traits_grouping_and_hidden_states_are_preserved(self):
        for path, expected in SEMANTIC_HASHES.items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256(semantics(source(path)).encode()).hexdigest(), expected)

    def test_tile_identity_contains_shelf_and_song_not_rendered_title(self):
        songs = source('Songs/SongsView.swift')
        self.assertIn('"songs.tile.\\($0).\\(lesson.id)"', songs)
        self.assertIn('others: others, identity: source)', songs)
        self.assertIn('identity: source + ".versions"', songs)
        for role in ['.duration', '.xp', '.more', '.chord.']:
            self.assertIn('identity + "' + role + '"', songs)
        self.assertIn('chip(chord.name, symbol: chord.symbol)', songs)
        self.assertNotIn('identity + ".chord." + name', songs)

    def test_hidden_chords_and_placeholder_stay_hidden(self):
        songs = source('Songs/SongsView.swift')
        chords = songs.split('private struct ChordChips:', 1)[1].split('private struct DifficultyDots:', 1)[0]
        self.assertIn('.accessibilityHidden(true)', chords)
        self.assertIn('identity: identity + ".versions.placeholder").hidden()', songs)
        self.assertNotIn('.accessibilityHidden(false)', chords)

    def test_hero_and_filter_text_have_semantic_leaf_roles(self):
        songs = source('Songs/SongsView.swift')
        for role in ['title', 'course', 'metadata', 'eyebrow', 'play.title', 'chords']:
            self.assertIn('songs.hero.\\(song.id).' + role, songs)
        self.assertIn('songs.filter.\\(chip.id).title', songs)
        self.assertIn('.accessibilityIdentifier("songs.filter.all")', songs)

    def test_calendar_weekdays_use_calendar_identity_not_localized_initial(self):
        journey = source('Journey/JourneyView.swift')
        self.assertIn('journey.calendar.weekday.\\(Calendar.current.component(.weekday, from: date))', journey)
        self.assertIn('journey.calendar.active-days', journey)
        self.assertIn('JourneyCardHeading("Last five weeks", identity: "journey.calendar")', journey)
        self.assertIn('.accessibilityIdentifier(identity + ".title")', journey)

    def test_practice_level_mark_is_distinct_from_header(self):
        practice = source('Practice/PracticeView.swift')
        game = source('Design/GameUI.swift')
        self.assertIn('LevelRing(size: 84, identity: "practice.level.tile")', practice)
        self.assertIn('LevelRing(size: 62, identity: "practice.level.card")', practice)
        self.assertIn('identity: identity + ".mark"', game)
        self.assertIn('.accessibilityIdentifier(identity + ".count")', game)
        self.assertIn('.accessibilityIdentifier("level.ring")', game)
        self.assertIn('.accessibilityIdentifier("streak.chip")', game)

    def test_paywall_saving_uses_plan_role_not_price_or_percentage(self):
        paywall = source('Paywall/PaywallView.swift')
        self.assertIn('identity: "paywall.plan.\\(role)"', paywall)
        self.assertIn('identity: identity + ".saving"', paywall)
        self.assertIn('identity: face.identity + ".trial"', paywall)
        self.assertIn('Text(verbatim: text)\n            .accessibilityIdentifier(identity)', paywall)
        self.assertNotIn('PlanPlate(selected: isSelected, quiet: quiet, identity:', paywall)

    def test_shared_header_scope_reaches_leaf_text(self):
        kit = source('Design/Kit.swift')
        components = source('Design/Components.swift')
        self.assertEqual(kit.count('ScreenTitle(title: title, subtitle: subtitle, identity: identity)'), 2)
        self.assertIn('identity: "songs.header"', source('Songs/SongsView.swift'))
        self.assertIn('identity: identity + ".streak"', kit)
        self.assertIn('identity: identity + ".level"', kit)
        for role in ['.title', '.subtitle']:
            self.assertIn('.accessibilityIdentifier(identity + "' + role + '")', components)

    def test_coach_leaf_combines_action_scope_and_stable_note_identity(self):
        coach = source('Journey/CoachCard.swift')
        self.assertIn('.accessibilityIdentifier(actionId + "." + note.id + ".title")', coach)
        self.assertIn('.accessibilityIdentifier(actionId)', coach)

    def test_library_empty_title_is_unambiguous(self):
        self.assertIn('songs.library.empty.title', source('YourSongs/YourSongsShelf.swift'))


if __name__ == '__main__':
    unittest.main()
