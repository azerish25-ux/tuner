"""Passive debug trace must not alter Songs scroll state, layout, assertions, or release code."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SongPageTraceContractTests(unittest.TestCase):
    def setUp(self):
        self.page = (ROOT / 'ios/Timbre/Songs/SongShelfPage.swift').read_text()
        self.trace = (ROOT / 'ios/Timbre/Songs/SongPageTrace.swift').read_text()
        self.ui = (ROOT / 'ios/TimbreUITests/SongShelfRailUITests.swift').read_text()

    def test_trace_is_compiled_out_of_release_and_requires_explicit_opt_in(self):
        self.assertTrue(self.trace.startswith('#if DEBUG\n'))
        self.assertTrue(self.trace.endswith('#endif\n'))
        self.assertEqual(self.page.count('#if DEBUG'), 1)
        debug = self.page.split('#if DEBUG', 1)[1].split('#endif', 1)[0]
        for token in ['SongPageTrace.record("position-observed"', '.onScrollGeometryChange(',
                      '.onScrollPhaseChange', 'SongPageTrace.enabled']:
            self.assertIn(token, debug)
        self.assertIn('TestSupport.isOn(.songPageTrace) && TestSupport.storageRoot != nil', self.trace)
        self.assertIn('private static let recorder: Recorder? = enabled ? Recorder() : nil', self.trace)
        support = (ROOT / 'ios/Timbre/Support/TestSupport.swift').read_text()
        self.assertIn('case songPageTrace = "TIMBRE_SONG_PAGE_TRACE"', support)

    def test_passive_callbacks_do_not_replace_binding_or_publish_geometry_state(self):
        self.assertIn('.scrollPosition(id: $position, anchor: .center)', self.page)
        debug = self.page.split('#if DEBUG', 1)[1].split('#endif', 1)[0]
        for source in [debug, self.trace]:
            for forbidden in ['@State', '@Published', 'ObservableObject', 'accessibilityValue',
                              'scrollTo(', 'setContentOffset(', 'position =', 'withAnimation(',
                              'DispatchQueue', 'Task {', '.id(', 'defaultScrollAnchor']:
                self.assertNotIn(forbidden, source)
        self.assertIn('onChange can coalesce; not exhaustive binding setters', self.trace)

    def test_actual_native_geometry_and_binding_are_observed_together(self):
        for token in ['value.containerSize.width', 'value.containerSize.height',
                      'value.contentSize.width', 'value.contentSize.height',
                      'value.contentOffset.x', 'value.contentOffset.y',
                      'value.contentInsets.top', 'value.contentInsets.leading',
                      'value.contentInsets.bottom', 'value.contentInsets.trailing', 'value.visibleRect']:
            self.assertIn(token, self.trace)
        for token in ['"appear"', '"disappear"', '"position-observed"', '"geometry"', '"phase"',
                      'position: String(describing: position)', 'oldPosition: String(describing: old)',
                      'SongPageTrace.Geometry(context.geometry)']:
            self.assertIn(token, self.page)

    def test_file_writer_is_local_namespaced_bounded_and_explicitly_diagnostic(self):
        for token in ['let schema = 1', 'let diagnosticOnly = true', 'let sessionID: String',
                      'Date().timeIntervalSince1970', 'ProcessInfo.processInfo.systemUptime',
                      'UUID(uuidString: sessionID) != nil', 'TestSupport.storageRoot',
                      '"song-page-trace.ndjson"', '"song-page-trace.previous.ndjson"',
                      'maximumBytes = 4 * 1024 * 1024', 'bytes + data.count > Self.maximumBytes',
                      'data.count <= Self.maximumBytes', 'data.append(10)',
                      'lock.lock()', 'defer { lock.unlock() }', 'trace is incomplete']:
            self.assertIn(token, self.trace)
        for forbidden in ['URLSession', 'UserDefaults', 'Analytics', 'accessibility', 'FileHandle.standardOutput']:
            # Only the opening nonbehavioral comment mentions accessibility.
            self.assertNotIn(forbidden, '\n'.join(self.trace.splitlines()[6:]))

    def test_ui_capture_correlates_existing_originals_without_mutating_user_state(self):
        capture = self.ui.split('private func capture(', 1)[1].split('private func showRail', 1)[0]
        for token in ['TIMBRE_TEST_STORAGE_ID', 'Date().timeIntervalSince1970',
                      'ProcessInfo.processInfo.systemUptime', 'appFrame=', 'observationOnly=true',
                      'XCUIScreen.main.screenshot()', 'app.debugDescription', 'marker.lifetime = .keepAlways']:
            self.assertIn(token, capture)
        self.assertEqual(self.ui.count('app.launchEnvironment["TIMBRE_SONG_PAGE_TRACE"] = "1"'), 1)
        resize = self.ui.split('for cycle in 0..<2', 1)[1]
        self.assertLess(resize.index('capture("portrait-before-rotation-'),
                        resize.index('XCUIDevice.shared.orientation = .landscapeLeft'))
        for forbidden in ['swipe', '.tap()', 'orientation =', 'scrollTo(']:
            self.assertNotIn(forbidden, capture)
        rotation = self.ui.split('private func assertRotationVisible(', 1)[1].split('private func usable', 1)[0]
        for token in ['XCTAssertLessThan(frame.minY, contentBottom',
                      'XCTAssertGreaterThan(frame.maxY, screen.minY', 'XCTAssertTrue(card.isHittable']:
            self.assertIn(token, rotation)

    def test_trace_checks_are_selected_by_core_ci(self):
        workflow = (ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn('python3 tools/ci/test_song_page_trace_contract.py', workflow)
        self.assertIn('python3 tools/ci/test_song_page_trace.py', workflow)

    def test_collection_follows_tests_and_precedes_existing_compact_upload(self):
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        names = ['- name: Selected UI class', '- name: Collect bounded opt-in Songs page trace',
                 '- name: Finalize compact shard diagnostics immediately',
                 '- name: Upload compact shard diagnostics before attachments']
        offsets = [workflow.index(name) for name in names]
        self.assertEqual(offsets, sorted(offsets))
        step = workflow.split(names[1], 1)[1].split(names[2], 1)[0]
        for token in ["if: always() && matrix.shard == 'song-rails'", 'timeout-minutes: 2',
                      'collect_song_page_trace.py --device "$DEVICE_ID" --output ci-out/song-page-trace']:
            self.assertIn(token, step)
        self.assertNotIn('continue-on-error', step)
        self.assertIn('            ci-out/song-page-trace/', workflow)


if __name__ == '__main__':
    unittest.main()
