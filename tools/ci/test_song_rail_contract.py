#!/usr/bin/env python3
"""Source/data guards for the production lazy rail; native sizing and scrolling remain mandatory."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SONGS = (ROOT / 'ios/Timbre/Songs/SongsView.swift').read_text()
RAIL = (ROOT / 'ios/Timbre/Songs/SongShelfRail.swift').read_text()
PAGE = (ROOT / 'ios/Timbre/Songs/SongShelfPage.swift').read_text()
MEASURE = (ROOT / 'ios/Timbre/Songs/SongRailMeasurement.swift').read_text()


class SongRailContractTests(unittest.TestCase):
    def test_hero_metadata_isolates_whole_fields_not_the_surrounding_line(self):
        helper = SONGS.split('struct HeroMetadata: View {', 1)[1].split('/// What the song asks', 1)[0]
        visual = helper.split('var visual: Text {', 1)[1].split('var body:', 1)[0]
        self.assertIn(r'Text(verbatim: "· \u{2066}\(length)\u{2069}")', visual)
        self.assertIn(r'Text(verbatim: " · \u{2068}") + Text("+\(xp) XP") + Text(verbatim: "\u{2069}")', visual)
        for forbidden in ['layoutDirection', 'String(format:', 'minimumScaleFactor', 'accessibilityHidden', 'TestSupport']:
            self.assertNotIn(forbidden, helper)

    def test_hero_metadata_preserves_original_single_spoken_text_and_identity(self):
        helper = SONGS.split('struct HeroMetadata: View {', 1)[1].split('/// What the song asks', 1)[0]
        spoken = helper.split('var spoken: Text {', 1)[1].split('var visual:', 1)[0]
        self.assertIn(r'Text(verbatim: "· \(length) · ") + Text("+\(xp) XP")', spoken)
        self.assertIn(r'Text(verbatim: "· \(length)")', spoken)
        self.assertNotIn(r'\u{', spoken)
        self.assertIn('visual.accessibilityLabel(spoken)', helper)
        self.assertEqual(helper.count('.accessibilityLabel('), 1)
        call = SONGS.split('private func heroText(', 1)[1].split('struct HeroMetadata:', 1)[0]
        self.assertIn('HeroMetadata(length: sheet.length, xp: store.settings.calmMode ? nil : song.lesson.xp)', call)
        self.assertEqual(call.count(r'.accessibilityIdentifier("songs.hero.\(song.id).metadata")'), 1)

    def test_native_hero_metadata_render_and_negative_order_controls_are_strict(self):
        native = (ROOT / 'ios/TimbreAppTests/SongHeroMetadataTests.swift').read_text()
        for token in ['testExistingSingleSpokenTextPreservesValuesTranslationAndCalmMode',
                      'testArabicAndEnglishWholeFieldRenderingRejectsRegroupedOrChangedValues',
                      'testDefaultEnglishPixelsAndCalmModeDoNotChange',
                      'testCalmArabicKeepsOnlyTheOriginalDuration',
                      'testIndependentGlyphPositionsKeepRewardTogetherAndRejectOldArabicOrder',
                      'locale: "ar_SA"', 'locale: "en_US"', '"٢:٣٦"', '"+٣٠ XP"',
                      'DynamicTypeSize.large, .accessibility5', 'LayoutDirection.leftToRight, .rightToLeft',
                      'XCTAssertEqual(actual, expected', 'XCTAssertEqual(actual, old',
                      'XCTAssertNotEqual(actual, negative', 'CTRunGetPositions', 'CTRunGetStringIndices',
                      'XCTAssertLessThan(sign, digits)', 'XCTAssertLessThan(digits, unit',
                      'XCTAssertLessThan(duration, sign)', 'XCTAssertGreaterThan(duration, unit)',
                      'CGColorSpace.sRGB', 'CGImageAlphaInfo.premultipliedLast',
                      'CGBitmapInfo.byteOrder32Big', 'XCTAttachment(image: image)']:
            self.assertIn(token, native)
        for forbidden in ['XCTSkip', 'pngData()', 'accuracy:', 'minimumScaleFactor']:
            self.assertNotIn(forbidden, native)

    def test_native_hero_metadata_tests_are_included_and_selected(self):
        project = (ROOT / 'ios/project.yml').read_text()
        app_tests = project.split('  TimbreAppTests:', 1)[1].split('\nschemes:', 1)[0]
        self.assertIn('- path: TimbreAppTests', app_tests)
        workflow = (ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn('-only-testing:TimbreAppTests -only-testing:TimbreUITests/SmokeUITests', workflow)
        self.assertIn('python3 tools/ci/test_song_rail_contract.py', workflow)

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

    def test_host_reuse_preserves_per_caption_identity_and_full_coverage(self):
        for token in ['if count > 0', 'host.rootView = Self.root(caption(index), key: key, identity: index)',
                      '.id(identity)', 'measurementCount += 1', 'height = autoreleasepool {']:
            self.assertIn(token, MEASURE)
        test = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text()
        for token in ['testReusedHostingRootResetsStateAndMeasuresEveryCaptionOnce',
                      'testEmptyShelfDoesNotCreateAHostOrEvaluateContent', '@State private var height',
                      'testBatchDoesNotRetainCaptionTreesInTheHeightCache', 'weak var token:',
                      'XCTAssertEqual(cache.hostCount, shelves.count)',
                      'XCTAssertEqual(cache.measurementCount, captionCount)']:
            self.assertIn(token, test)

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
        self.assertIn('@State private var position: Item.ID?', RAIL)
        self.assertIn('.scrollPosition(id: $position, anchor: .trailing)', RAIL)
        self.assertIn('if let selection { reveal(selection) }', RAIL)
        self.assertIn('reveal(value)', RAIL)
        self.assertIn(r'withTransaction(\.scrollTargetAnchor, .center) { position = value }', RAIL)
        self.assertIn('guard !initialized else { return }', RAIL)
        self.assertNotIn('DispatchQueue.main.async', RAIL)
        self.assertNotIn('onGeometryChange', RAIL)
        self.assertNotIn('onScrollTargetVisibilityChange', RAIL)
        self.assertNotIn('.clipped()', RAIL)
        self.assertNotIn('.dynamicTypeSize(', RAIL)

    def test_parent_page_tracks_shelf_identity_separately_from_horizontal_song(self):
        # Native 2013834 evidence retained the terminal song inside its horizontal rail,
        # but the enclosing page reset to the top (rail y=1324.7 LTR / 1298.7 RTL).
        page = SONGS.split('var body: some View {', 1)[1].split('.onChange(of: filter)', 1)[0]
        self.assertIn('@State private var shelfPosition: SongShelfPageTarget<String>?', SONGS)
        for token in ['SongShelfPage(items: shelves, position: $shelfPosition)', 'shelfItem(item)',
                      '.accessibilityIdentifier("songs.page")']:
            self.assertIn(token, page)
        for token in ['enum SongShelfPageTarget<ID: Hashable & Sendable>: Hashable, Sendable',
                      '@Binding var position: SongShelfPageTarget<Item.ID>?',
                      'private enum Row: Identifiable', 'var id: SongShelfPageTarget<Item.ID>',
                      'case introduction', 'case shelf(Item)', 'case request',
                      'case .shelf(let item): return .shelf(item.id)', 'ForEach(rows)',
                      '.scrollTargetLayout()', '.scrollPosition(id: $position, anchor: .center)']:
            self.assertIn(token, PAGE)
        # Explicit geometry target and collection identity use the exact same typed row key.
        row = PAGE.split('ForEach(rows)', 1)[1].split('.scrollTargetLayout()', 1)[0]
        self.assertIn('VStack(alignment: .leading, spacing: 0)', row)
        self.assertEqual(row.count('.id(row.id)'), 1)
        self.assertEqual(row.count('.id('), 1)
        for forbidden in ['DispatchQueue', 'scrollTo(', '.id(pageWidth)', '.id(typeSize)']:
            self.assertNotIn(forbidden, page)
            self.assertNotIn(forbidden, PAGE)
        self.assertIn('.scrollPosition(id: $position, anchor: .trailing)', RAIL)

    def test_parent_identity_repair_keeps_constant_center_without_geometry_feedback(self):
        self.assertIn('.scrollPosition(id: $position, anchor: .center)', PAGE)
        for forbidden in ['scrollTo(', 'DispatchQueue', 'Task {', '.onAppear', 'position =',
                          'rowHeights', 'scrollAnchor', 'onScrollGeometryChange',
                          '.id(pageWidth)', 'accessibilityHidden', 'minimumScaleFactor']:
            self.assertNotIn(forbidden, PAGE)

    def test_additive_command_controls_keep_full_normal_card_and_oversized_primary_geometry(self):
        native = (ROOT / 'ios/TimbreAppTests/SongShelfPageTests.swift').read_text()
        for token in ['testBindingCommandPlacesShelfAndTerminalAndPreservesResizeGeometry()',
                      'testBindingCommandPlacesShelfAndTerminalAndPreservesResizeGeometryRightToLeft()',
                      'testOversizedShelfKeepsPrimarySleeveAcrossRepeatedResize()',
                      'testOversizedShelfKeepsPrimarySleeveAcrossRepeatedResizeRightToLeft()',
                      'driver: .bindingCommand, oversized: true',
                      'state.oversized ? .accessibility5 : .large',
                      'height: state.oversized ? 640 : 240', 'height: state.oversized ? 480 : 80',
                      'frames.page.insetBy(dx: -1, dy: -1).contains(sleeve(frames.card))',
                      'frames.rail.insetBy(dx: -1, dy: -1).contains(frames.card)',
                      'XCTAssertGreaterThan(frames.card.height, frames.page.height',
                      'await assertTerminal(state, target: target, window: window, stage: stage)']:
            self.assertIn(token, native)
        original = native.split('private func assertTerminal(', 1)[1]
        self.assertIn('page.insetBy(dx: -1, dy: -1).contains(frame)', original)
        self.assertNotIn('oversized', original)

    def test_native_parent_regression_observes_supported_programmatic_tracking_before_any_resize(self):
        native = (ROOT / 'ios/TimbreAppTests/SongShelfPageTests.swift').read_text()
        for token in ['SongShelfPage(items: shelves, position: $state.position)',
                      'SongShelfRail(items: songs,', 'state.requestedTerminalShelf == shelf.id ? 119 : 59', '(0..<120)',
                      'UIWindow(windowScene: scene)', 'window.makeKeyAndVisible()',
                      'proxy.scrollTo(value, anchor: .center)', 'proxy.scrollTo(119, anchor: .trailing)',
                      'state.position == .shelf(target)', 'await fulfillment(of: [tracked], timeout: 3)',
                      'XCTAssertEqual(state.position, .shelf(target)', 'for cycle in 0..<2',
                      'CGSize(width: 874, height: 402)', 'CGSize(width: 402, height: 874)',
                      'page.insetBy(dx: -1, dy: -1).contains(frame)',
                      'rail.insetBy(dx: -1, dy: -1).contains(frame)',
                      'testProgrammaticScrollTracksShelfAndSurvivesRepeatedResizeRightToLeft']:
            self.assertIn(token, native)
        self.assertLess(native.index('await fulfillment(of: [tracked]'), native.index('state.size = size'))
        # Only the separately named command control can set the ID; the original observation
        # driver's branch must still use its proxy and never manufacture the expected readback.
        self.assertEqual(native.count('state.position = value'), 1)
        self.assertIn('if state.driver == .bindingCommand {', native)
        self.assertIn('} else {\n                        proxy.scrollTo(value, anchor: .center)', native)
        for name in ['testProgrammaticScrollTracksShelfAndSurvivesRepeatedResize()',
                     'testProgrammaticScrollTracksShelfAndSurvivesRepeatedResizeRightToLeft()']:
            method = native.split('func ' + name, 1)[1].split('\n    }', 1)[0]
            self.assertNotIn('bindingCommand', method)
            self.assertNotIn('oversized:', method)
        self.assertNotIn('setContentOffset(', native)
        self.assertEqual(native.count('proxy.scrollTo('), 2)
        fixture = native.split('private struct Fixture:', 1)[1].split('func testProgrammaticScroll', 1)[0]
        self.assertIn('.onChange(of: state.requestedShelf)', fixture)
        self.assertIn('.onChange(of: state.requestedTerminalShelf)', fixture)
        self.assertNotIn('.onAppear', fixture)
        resize = native.split('for cycle in 0..<2', 1)[1].split('private func assertCurrentGeometry', 1)[0]
        for forbidden in ['scrollTo(', 'requestedShelf =', 'requestedTerminalShelf =', 'position =']:
            self.assertNotIn(forbidden, resize)
        self.assertNotIn('XCTSkip', native)

    def test_native_parent_traversal_keeps_nested_scroll_views(self):
        native = (ROOT / 'ios/TimbreAppTests/SongShelfPageTests.swift').read_text()
        traversal = native.split('private func scrolls(', 1)[1].split('func testScrollTraversal', 1)[0]
        self.assertIn('return current + view.subviews.flatMap { scrolls($0) }', traversal)
        self.assertNotIn('?? view.subviews', traversal)
        for token in ['testScrollTraversalIncludesNestedRailsAndTheirPage', 'content.addSubview(rail)',
                      'XCTAssertEqual(found.count, 2)', 'XCTAssertTrue(found.first === page)',
                      'XCTAssertTrue(found.last === rail)']:
            self.assertIn(token, native)

    def test_native_parent_diagnostics_precede_early_unwraps_and_retain_true_driver(self):
        native = (ROOT / 'ios/TimbreAppTests/SongShelfPageTests.swift').read_text()
        verify = native.split('private func verify(', 1)[1].split('private func assertTerminal(', 1)[0]
        self.assertLess(verify.index('stage: "loaded-'), verify.index('let vertical = try XCTUnwrap'))
        self.assertLess(verify.index('stage: "programmatic-tracking-'), verify.index('let horizontal = try XCTUnwrap'))
        terminal = native.split('private func assertTerminal(', 1)[1]
        self.assertLess(terminal.index('record(state, window: window, stage: stage)'),
                        terminal.index('guard let current = currentScrolls() else'))
        for token in ['not a touch gesture', 'positionHistory', 'scroll.isDragging', 'scroll.isDecelerating',
                      'scroll.contentOffset', 'scroll.adjustedContentInset', 'XCTAttachment(image: image)',
                      'diagnostic.lifetime = .keepAlways', 'rendered.lifetime = .keepAlways']:
            self.assertIn(token, native)

    def test_primary_action_taps_real_sleeve_clear_of_independent_controls(self):
        native = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        primary = native.split('private func tapPrimarySleeve(', 1)[1].split('private func dismissDestination', 1)[0]
        for token in ['stableFrame(tile)', 'min(frame.width, frame.height) / 2',
                      'XCTAssertTrue(tile.isHittable)', 'frame.contains(point)',
                      'rail.frame.contains(point)', 'app.frame.contains(point)',
                      'XCTAssertFalse(preview.frame.contains(point)', 'XCTAssertFalse(versions.frame.contains(point)',
                      'tile.coordinate(withNormalizedOffset: .zero).withOffset(offset).tap()']:
            self.assertIn(token, primary)
        actions = native.split('private func verifyActions(', 1)[1].split('private func tapPrimarySleeve', 1)[0]
        self.assertIn('tapPrimarySleeve(tile, preview: preview, versions: versions, rail: rail)', actions)
        self.assertNotIn('tile.tap()', actions)
        self.assertIn('capture("destination-missing-" + stage)', native)

    def test_ax5_synthesized_center_tap_hits_versions_but_sleeve_tap_does_not(self):
        # Exact 705 XCTest event: (94, 298.5). Post-failure hierarchy contains Versions.
        card = (20.0, 106.7, 148.0, 383.7)
        versions = (92.3, 264.7, 75.7, 44.0)
        preview = (120.0, 206.7, 44.0, 44.0)
        def contains(rect, point):
            x, y, width, height = rect
            return x <= point[0] < x + width and y <= point[1] < y + height
        self.assertTrue(contains(versions, (94.0, 298.5)))
        point = (card[0] + card[2] / 2, card[1] + min(card[2], card[3]) / 2)
        self.assertTrue(contains(card, point))
        self.assertFalse(contains(versions, point))
        self.assertFalse(contains(preview, point))

    def test_vertical_reveal_corrects_measured_overshoot_without_weakening_viewport(self):
        test = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        show = test.split('private func showRail()', 1)[1].split('private func reveal(', 1)[0]
        for token in ['matching(identifier: "songs.page")', 'for attempt in 0..<24',
                      'stableFrame(rail)', 'let top = app.frame.minY + 70',
                      'app.tabBars.firstMatch.frame.minY - 24',
                      'bounds.minY >= top && bounds.maxY <= bottom',
                      'bounds.height <= bottom - top', 'capture("vertical-too-tall")',
                      'band.height * 0.6', 'band.midY - bounds.midY',
                      'band.midY - distance / 2', 'band.midY + distance / 2',
                      'withVelocity: .slow, thenHoldForDuration: 0.3',
                      'SONG-RAIL vertical:', 'XCTFail(']:
            self.assertIn(token, show)
        self.assertNotIn('vertical.swipeDown', show)
        self.assertNotIn('XCTSkip', show)

    def test_measured_ax5_rail_fits_and_bounded_physical_correction_converges(self):
        # Values from the actual AX5 failure hierarchy: 402x874 window, tab y=791,
        # rail y=-173.7/height=643.7. The unchanged 70...767 band has only 53.3pt slack.
        top, bottom, height = 70.0, 791.0 - 24, 643.7
        self.assertGreater(bottom - top, height)
        self.assertAlmostEqual(bottom - top - height, 53.3)
        for original in [-173.7, 400.0, 1298.7, -1800.0]:
            y = original
            for _ in range(24):
                if y >= top and y + height <= bottom:
                    break
                mid = (top + bottom) / 2
                limit = (bottom - top) * 0.6
                delta = max(-limit, min(limit, mid - (y + height / 2)))
                start, end = mid - delta / 2, mid + delta / 2
                self.assertGreaterEqual(min(start, end), top)
                self.assertLessEqual(max(start, end), bottom)
                y += end - start
            self.assertGreaterEqual(y, top, original)
            self.assertLessEqual(y + height, bottom, original)

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
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        self.assertIn('test_class: SongShelfRailUITests', workflow)
        self.assertIn('-only-testing:TimbreUITests/${{ matrix.test_class }}', workflow)

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

    def test_rotation_and_unrealized_target_preserve_diagnostics_and_containment(self):
        test = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        rotation = test.split('private func assertRotationVisible(', 1)[1].split('private func usable(', 1)[0]
        self.assertLess(rotation.index('capture(stage)'), rotation.index('card.isHittable'))
        for token in ['stableFrame(card)', 'frame.minX, viewport.minX - 1',
                      'frame.maxX, viewport.maxX + 1', 'frame.minY, viewport.minY - 1',
                      'frame.maxY, viewport.maxY + 1', 'XCTAssertTrue(card.isHittable']:
            self.assertIn(token, rotation)
        self.assertIn('SONG-RAIL progress:', test)
        self.assertIn('if attempt % 10 == 0 { logProgress', test)
        self.assertIn('for attempt in 0..<85', test)

    def test_rotation_cannot_pass_with_entire_parent_shelf_below_screen(self):
        test = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()
        rotation = test.split('private func assertRotationVisible(', 1)[1].split('private func usable(', 1)[0]
        for token in ['let screen = app.frame', 'app.tabBars.firstMatch.frame.minY',
                      'XCTAssertLessThan(frame.minY, contentBottom',
                      'XCTAssertGreaterThan(frame.maxY, screen.minY']:
            self.assertIn(token, rotation)
        cycle = test.split('for cycle in 0..<2 {', 1)[1].split('_ = reveal(samples[0]', 1)[0]
        for token in ['.landscapeLeft', '.portrait', 'assertRotationVisible(landscapeLast',
                      'assertRotationVisible(last', 'verifyActions(samples[2], tile: rotatedLast']:
            self.assertIn(token, cycle)
        # A test-side vertical recenter would hide the production regression.
        for forbidden in ['showRail()', 'swipeUp', 'swipeDown', 'scrollTo']:
            self.assertNotIn(forbidden, cycle)

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

    def test_caption_chords_wrap_and_versions_keep_separate_full_target(self):
        layout = (ROOT / 'ios/Timbre/Songs/SongCaptionLayout.swift').read_text()
        for token in ['ViewThatFits(in: .horizontal)', '.fixedSize(horizontal: true, vertical: false)',
                      'VStack(alignment: .leading, spacing: 6)', 'minWidth: Metrics.minTarget, minHeight: Metrics.minTarget',
                      'direction == .rightToLeft', 'width - x - size.width']:
            self.assertIn(token, layout)
        caption = SONGS.split('struct TileCaption: View {', 1)[1].split('struct TileMetadata:', 1)[0]
        for token in ['SongCaptionHeader(hasVersions: !others.isEmpty)', 'wrapsAll: true', '.versions.placeholder']:
            self.assertIn(token, caption)
        self.assertNotIn('minimumScaleFactor', caption)
        self.assertIn('.padding(.top, tileWidth + Self.captionGap)', SONGS)
        self.assertIn('ForEach(chords, id:', SONGS)
        test = (ROOT / 'ios/TimbreAppTests/SongCaptionLayoutTests.swift').read_text()
        for token in ['import TimbreCore', '["en", "de", "ar"]', '[CGFloat(148), CGFloat(176)]',
                      'XCTAssertEqual(pixels, expected', 'rect.intersects(versionRect)',
                      'testEveryProductionChordFitsWithoutReducingGlyphSize', 'store.curriculum.courses.flatMap',
                      'XCTAssertEqual(right[index].minX, width - left[index].maxX)']:
            self.assertIn(token, test)

    def test_chord_oracle_escaping_builder_uses_explicit_self(self):
        source = (ROOT / 'ios/TimbreAppTests/SongCaptionLayoutTests.swift').read_text()
        closure = source.split(r'ForEach(chords.indices, id: \.self) { index in', 1)[1].split('Color.orange', 1)[0]
        self.assertIn('self.oracleChip(self.chords[index].name)', closure)
        self.assertNotRegex(closure, r'(?m)^\s+oracleChip\(')
        header = source.split('let actual = SongCaptionHeader(hasVersions: true) {', 1)[1].split('} versions:', 1)[0]
        self.assertIn('ChordChips(chords: self.chords,', header)
        self.assertNotIn('ChordChips(chords: chords,', header)

    def test_chord_oracle_keeps_fractional_layout_and_single_rtl_transform(self):
        production = (ROOT / 'ios/Timbre/Songs/SongCaptionLayout.swift').read_text()
        native = (ROOT / 'ios/TimbreAppTests/SongCaptionLayoutTests.swift').read_text()
        self.assertIn('let logicalX = direction == .rightToLeft ? bounds.width - frame.maxX : frame.minX', production)
        self.assertIn('bounds.minX + logicalX', production)
        oracle = native.split('private struct IndependentHeaderLayout: Layout {', 1)[1].split('private func oracleChip', 1)[0]
        for forbidden in ['SongCaptionFlow.pack', 'UIHostingController', '.position(', 'rounded()', 'ceil(']:
            self.assertNotIn(forbidden, oracle)
        for token in ['view.sizeThatFits(.unspecified)', 'row.prefix(column)',
                      'XCTAssertFalse(rect.intersects(versionRect)', 'CHORD-ORACLE width=']:
            self.assertIn(token, oracle)
        self.assertIn('XCTAssertEqual(pixels, expected', native)
        self.assertIn('XCTAssertNotEqual(pixels, wrongOrder', native)
        self.assertIn('XCTAssertNotEqual(pixels, oldPixels', native)

    def test_metadata_adapts_without_truncating_or_shrinking_values(self):
        metadata = SONGS.split('struct TileMetadata: View {', 1)[1].split('/// The part of a title', 1)[0]
        for token in ['ViewThatFits(in: .horizontal)', 'HStack(spacing: 7) { fields }',
                      '.fixedSize(horizontal: true, vertical: false)',
                      'VStack(alignment: .leading, spacing: 7) { fields }',
                      '.fixedSize(horizontal: false, vertical: true)', 'if stars > 0', 'else if !calm',
                      'identity + ".duration"', 'identity + ".xp"']:
            self.assertIn(token, metadata)
        for forbidden in ['lineLimit', 'minimumScaleFactor', '.hidden()', '.accessibilityHidden']:
            self.assertNotIn(forbidden, metadata)
        caption = SONGS.split('struct TileCaption: View {', 1)[1].split('struct TileMetadata:', 1)[0]
        self.assertIn('TileMetadata(difficulty:', caption)
        native = (ROOT / 'ios/TimbreAppTests/SongCaptionMetadataTests.swift').read_text()
        for token in ['import TimbreCore', '["en", "de", "ar"]', '[CGFloat(148), CGFloat(176)]', '.accessibility5',
                      'XCTAssertEqual(pixels, oracle', 'XCTAssertNotEqual(pixels, truncated',
                      'let old = HStack(spacing: 7) { oracleFields }.lineLimit(1)',
                      'Text(verbatim: "2:29")', 'Text("+\\(30) XP")', 'XCTAttachment(image: image)']:
            self.assertIn(token, native)

    def test_full_catalogue_oracle_has_no_sample_or_timing_exemption(self):
        test = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text()
        full = test.split('func testFullProductionCatalogueCaptionSizingAcrossDynamicType()', 1)[1]
        full = full.split('func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard()', 1)[0]
        for token in ['DemoData.seed(store)', 'filter: SongsView.all', 'store.curriculum.courses.flatMap',
                      'Set(layout.rails.flatMap', 'for shelf in shelves', 'DynamicTypeSize.large, .accessibility5',
                      'catalog.versions(of: song)', 'catalog.standing(song)', 'ForEach(shelf.songs)',
                      'XCTAssertEqual(height, eagerHeight', 'XCTAssertEqual(cache.measurementCount, captionCount)',
                      'eagerOracleSeconds=', 'sizingSeconds=', 'song-rail-full-production-catalogue-sizing']:
            self.assertIn(token, full)
        for token in ['.prefix(', 'XCTSkip', 'XCTAssertLessThan(sizingSeconds', 'measure(metrics:']:
            self.assertNotIn(token, full)

    def test_native_selection_miss_is_trailing_alignment_not_center_tolerance(self):
        # Actual app-unit attachment: frame 442, offset 9284, selected card width 148.
        observed_center = 9284 + 442 / 2
        expected_center = 59 * (148 + 14) + 20 + 74
        self.assertEqual(observed_center, 9505)
        self.assertEqual(expected_center, 9652)
        self.assertEqual(expected_center - observed_center, (442 - 148) / 2)
        self.assertGreater(abs(expected_center - observed_center), 24)

    def test_initial_reveal_fixture_uses_live_scene_and_observes_completion(self):
        test = (ROOT / 'ios/TimbreAppTests/SongRailMeasurementTests.swift').read_text().split('func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard()', 1)[1]
        for token in ['UIWindow(windowScene: scene)', 'window.makeKeyAndVisible()',
                      'host.view.window === window', '.onAppear { appeared = true }',
                      'XCTNSPredicateExpectation', 'await fulfillment(of: [revealed], timeout: 3)',
                      'XCTAssertEqual(center, itemCenter, accuracy: 24)', 'XCTAssertLessThan(constructed.count, 120',
                      'XCTAssertEqual(frame.midX, viewport.midX, accuracy: 24)',
                      'XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX + 52',
                      'XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX - 52']:
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
