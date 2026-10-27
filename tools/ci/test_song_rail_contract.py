#!/usr/bin/env python3
"""Source/data guards for the production lazy rail; native sizing and scrolling remain mandatory."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SONGS = (ROOT / 'ios/Timbre/Songs/SongsView.swift').read_text()
RAIL = (ROOT / 'ios/Timbre/Songs/SongShelfRail.swift').read_text()
MEASURE = (ROOT / 'ios/Timbre/Songs/SongRailMeasurement.swift').read_text()


class SongRailContractTests(unittest.TestCase):
    def test_native_oracle_uses_explicit_cgfloat_limit(self):
        oracle = (ROOT / "ios/TimbreAppTests/SongRailMeasurementTests.swift").read_text()
        self.assertIn("CGSize(width: 2000, height: CGFloat.greatestFiniteMagnitude)", oracle)
        self.assertNotIn("height: .greatestFiniteMagnitude", oracle)

    def test_only_song_shelves_switch_to_complete_lazy_collections(self):
        self.assertIn('SongShelfRail(items: rail, selection: next?.id', SONGS)
        self.assertIn('SongShelfRail(items: pick.songs, selection: nil', SONGS)
        self.assertIn('LazyHStack(alignment: .top', RAIL)
        self.assertIn('ForEach(items)', RAIL)
        self.assertIn('.id(item.id)', RAIL)
        for forbidden in ['items.prefix', 'items.filter', 'accessibilityHidden', 'XCTSkip', 'TestSupport']:
            self.assertNotIn(forbidden, RAIL)
        self.assertIn('EdgeRail', SONGS.split('private func filterRail', 1)[1].split('private func featured', 1)[0])
        self.assertIn('EdgeRail', (ROOT / 'ios/Timbre/YourSongs/YourSongsShelf.swift').read_text())

    def test_static_caption_receives_compact_or_regular_version_limit(self):
        self.assertIn('let versionLimit: Int', SONGS)
        self.assertEqual(SONGS.count('calm: store.settings.calmMode, versionLimit: versionLimit'), 2)
        self.assertIn('private var versionLimit: Int { sizeClass == .regular ? 3 : 2 }', SONGS)

    def test_caption_component_preserves_all_nine_immutable_inputs(self):
        component = SONGS.split('struct TileCaption: View {', 1)[1].split('var body: some View', 1)[0]
        inputs = re.findall(r'let (\w+): ([^\n]+)', component)
        self.assertEqual(inputs, [
            ('song', 'Song'), ('sheet', 'SongSheet'), ('accent', 'Color'),
            ('standing', 'SongsCatalog.Standing'), ('stars', 'Int'), ('calm', 'Bool'),
            ('versionLimit', 'Int'), ('others', '[LearnCourse]'), ('identity', 'String'),
        ])
        self.assertNotIn('init(', component)
        self.assertNotIn('func tileCaption', SONGS)
        self.assertEqual(SONGS.count('Self.TileCaption(song: song,'), 2)
        oracle = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text()
        self.assertIn('SongsView.TileCaption(song: song,', oracle)
        self.assertIn('calm: false, versionLimit: versionLimit, others: versions', oracle)
        self.assertIn('[(CGFloat(148), 2), (CGFloat(176), 3)]', oracle)

    def test_actual_caption_measurement_not_guessed_font_caps(self):
        height = SONGS.split('private func railHeight', 1)[1].split('/// `shelf` names', 1)[0]
        self.assertIn('TileCaption(song: song,', height)
        self.assertIn('.environmentObject(store)', height)
        self.assertIn('tileWidth + Self.captionGap + captionHeight', height)
        for forbidden in ['SongCover(', 'PreviewDisc(', 'versionsMenu(', 'minimumScaleFactor', 'lineLimit(']:
            self.assertNotIn(forbidden, height)
        self.assertIn('@MainActor', MEASURE)
        self.assertIn('UIHostingController(rootView: caption', MEASURE)
        self.assertIn('host.sizeThatFits', MEASURE)
        self.assertNotIn('UIWindow(', MEASURE)
        self.assertNotIn('makeKeyAndVisible', MEASURE)
        self.assertIn('static let capacity = 24', MEASURE)
        self.assertIn('entries.removeFirst()', MEASURE)

    def test_cache_signature_covers_geometry_and_environment(self):
        height = SONGS.split('private func railHeight', 1)[1].split('/// `shelf` names', 1)[0]
        for dependency in ['song.lesson.title.localized', 'standing.access', 'standing.gate?.title.localized',
                           'store.learn.stars', 'song.lesson.xp', 'sheet.length', 'sheet.keyName',
                           'versionLimit', 'store.settings.calmMode', 'for chord in sheet.chords', 'for version in versions',
                           'locale.identifier', 'TimbreLocalization.language', 'typeSize', 'direction',
                           'legibility', 'Typeface.boldText', 'displayScale']:
            self.assertIn(dependency, height)

    def test_imperative_signature_preserves_every_field_and_order(self):
        signature = SONGS.split('var content: [String] = []', 1)[1].split('let key = SongRailMeasurement.Key', 1)[0]
        self.assertIn('for song in songs {', signature)
        self.assertNotIn('flatMap', signature)
        fields = [
            'song.id', 'song.lesson.title.localized', 'String(describing: standing.access)',
            'standing.gate?.id ?? ""', 'standing.gate?.title.localized ?? ""',
            'String(store.learn.stars[song.id] ?? 0)', 'String(song.lesson.xp)', 'sheet.length',
            'sheet.keyName ?? ""', 'String(versionLimit)', 'String(store.settings.calmMode)',
            'String(sheet.chords.count)', 'String(versions.count)', 'chord.name', 'version.id',
        ]
        # One append per line makes the native compiler constraint system small; compare the exact
        # sequence, including counts delimiting the trailing variable-length chord/version arrays.
        actual = re.findall(r'content\.append\((.*)\)', signature)
        self.assertEqual(actual, fields)
        self.assertIn('for chord in sheet.chords { content.append(chord.name) }', signature)
        self.assertIn('for version in versions { content.append(version.id) }', signature)

    def test_selection_browsing_fades_and_unclipped_height_remain(self):
        self.assertIn('.railBleed(leading: Metrics.gutter, trailing: Metrics.gutter)', RAIL)
        self.assertIn('if phase == .interacting { browsed = true }', RAIL)
        self.assertIn('if resized && !browsed { revealed = false }', RAIL)
        self.assertIn('scroller.scrollTo(selection, anchor: .center)', RAIL)
        self.assertNotIn('.clipped()', RAIL)
        self.assertNotIn('.dynamicTypeSize(', RAIL)

    def test_120_record_native_regression_uses_real_first_middle_last(self):
        curriculum = json.loads((ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json').read_text())
        course = next(c for c in curriculum['courses'] if c['id'] == 'bass-songbook')
        songs = [l for u in course['units'] for l in u['lessons'] if l['kind'] == 'song']
        self.assertEqual(len(songs), 120)
        test = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        for index in [0, 59, 119]:
            self.assertIn(songs[index]['id'], test)
        self.assertIn('UICTContentSizeCategoryAccessibilityXXXL', test)
        self.assertIn('testFullCatalogueRemainsReachableRightToLeft', test)
        self.assertIn('verifyActions', test)
        self.assertIn('rail.frame.height, height, accuracy: 1', test)
        self.assertIn('-only-testing:TimbreUITests/SongShelfRailUITests',
                      (ROOT / '.github/workflows/nightly.yml').read_text())

    def test_reveal_checks_stable_geometry_before_actual_hittability(self):
        test = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        reveal = test.split('private func reveal(', 1)[1].split('private func verifyActions(', 1)[0]
        self.assertLess(reveal.index('guard let frame = stableFrame(target)'), reveal.index('target.isHittable'))
        self.assertLess(reveal.index('if fullyClear {'), reveal.index('target.isHittable'))
        for token in ['for attempt in 0..<85', 'viewport.width * 0.6', 'viewport.midX - frame.midX',
                      '(forward != rtl) ? -limit : limit', '(rtl ? atLast : atFirst) ? 19 : 52',
                      '(rtl ? atFirst : atLast) ? 19 : 52', 'frame.minY >= viewport.minY - 1',
                      'frame.maxY <= viewport.maxY + 1', 'guard let frame = stableFrame(target) else { continue }',
                      'frame.minX.isFinite', 'frame.height > 0', 'for _ in 0..<3',
                      'withVelocity: .slow, thenHoldForDuration: 0.3', 'XCTAssertTrue(target.isHittable']:
            self.assertIn(token, reveal)
        for forbidden in ['try?', 'catch', 'XCTSkip', 'target.exists && target.isHittable']:
            self.assertNotIn(forbidden, reveal)

    def test_adaptive_physical_drag_centers_both_failure_geometries(self):
        # Independent geometry model using the two native failure frames. Physical centering must not
        # invert again for RTL; both source endpoints stay in the viewport and reverse after overshoot.
        width = 402.0
        limit = width * 0.6
        for x, card_width in [(511.3, 136.2), (-279.4, 136.2), (-20, 148), (260, 148)]:
            origin = x
            for _ in range(3):
                distance = max(-limit, min(limit, width / 2 - (x + card_width / 2)))
                start = width / 2 - distance / 2
                end = width / 2 + distance / 2
                self.assertGreaterEqual(start, width * 0.2)
                self.assertLessEqual(start, width * 0.8)
                self.assertGreaterEqual(end, width * 0.2)
                self.assertLessEqual(end, width * 0.8)
                x += end - start
            self.assertGreaterEqual(x, 52, origin)
            self.assertLessEqual(x + card_width, width - 52, origin)

    def test_eager_oracle_escaping_caption_builder_uses_explicit_self(self):
        source = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text()
        eager = source.split('let eagerHeight = autoreleasepool {', 1)[1].split('}.fixedSize()', 1)[0]
        self.assertIn('ForEach(shelf.songs) { song in', eager)
        self.assertIn('self.productionCaption(song, catalog: catalog, store: store).frame(width: 148)', eager)
        self.assertNotRegex(eager, r'(?m)^\s+productionCaption\(')

    def test_full_catalogue_oracle_has_no_sample_or_timing_exemption(self):
        test = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text()
        full = test.split('func testFullProductionCatalogueCaptionSizingAcrossDynamicType()', 1)[1]
        full = full.split('func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard()', 1)[0]
        for token in ['DemoData.seed(store)', 'filter: SongsView.all', 'store.curriculum.courses.flatMap',
                      'Set(layout.rails.flatMap', 'for shelf in shelves', 'DynamicTypeSize.large, .accessibility5',
                      'catalog.versions(of: song)', 'catalog.standing(song)', 'ForEach(shelf.songs)',
                      'XCTAssertEqual(height, eagerHeight', 'XCTAssertEqual(cache.hostCount, captionCount)',
                      'eagerOracleSeconds=', 'sizingSeconds=', 'song-rail-full-production-catalogue-sizing']:
            self.assertIn(token, full)
        for token in ['.prefix(', 'XCTSkip', 'XCTAssertLessThan(sizingSeconds', 'measure(metrics:']:
            self.assertNotIn(token, full)

    def test_initial_reveal_fixture_uses_live_scene_and_observes_completion(self):
        test = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text().split('func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard()', 1)[1]
        for token in ['UIWindow(windowScene: scene)', 'window.makeKeyAndVisible()',
                      'host.view.window === window', '.onAppear { appeared = true }',
                      'XCTNSPredicateExpectation', 'await fulfillment(of: [revealed], timeout: 3)',
                      'XCTAssertEqual(center, itemCenter, accuracy: 24)', 'XCTAssertLessThan(constructed.count, 120']:
            self.assertIn(token, test)
        self.assertNotIn('Task.sleep', test)

    def test_caption_subtree_has_no_lifecycle_or_playback_work(self):
        caption = SONGS.split('struct TileCaption: View {', 1)[1].split('/// The part of a title', 1)[0]
        pieces = SONGS.split('private struct LockReason:', 1)[1]
        course_art = (ROOT / 'ios/Timbre/Learn/CourseArt.swift').read_text()
        for block in [caption, pieces, course_art]:
            for forbidden in ['.onAppear', '.task', 'AVAudio', 'togglePreview(']:
                self.assertNotIn(forbidden, block)


if __name__ == '__main__':
    unittest.main()
