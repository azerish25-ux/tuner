"""Source guards only; native component and whole-step observations are required for approval."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AlongTypographyContract(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'ios/Timbre/Learn/Highway.swift').read_text()
        self.native = (ROOT / 'ios/TimbreAppTests/AlongTypographyLayoutTests.swift').read_text()
        self.ui = (ROOT / 'ios/TimbreUITests/LessonAccessibilityLayoutUITests.swift').read_text()

    def test_new_contract_is_executed_in_ci(self):
        self.assertIn("python3 tools/ci/test_along_typography_contract.py",
                      (ROOT / ".github/workflows/ios.yml").read_text())

    def test_current_place_wraps_without_discarding_or_scaling_words(self):
        upcoming = self.source.split('@ViewBuilder private var upcoming:', 1)[1].split('private func fingerTag', 1)[0]
        for token in ['ChordFlowLayout(spacing: 10, lineSpacing: 8)', 'HStack(alignment: .firstTextBaseline',
                      'NotePlace.spoken(note, fretted: fretted, board: board)',
                      'AlongPlaceLabel(words: NotePlace.words(at, board: board)',
                      '.accessibilityIdentifier("along.next")']:
            self.assertIn(token, upcoming)
        badge = self.source.split('struct AlongPlaceLabel:', 1)[1].split('struct AlongActionLayout:', 1)[0]
        for token in ['Text(verbatim: words)', '.font(Typeface.label(.body))',
                      '.fixedSize(horizontal: false, vertical: true)']:
            self.assertIn(token, badge)
        for forbidden in ['lineLimit', 'minimumScaleFactor', 'dynamicTypeSize', '.clipped()']:
            self.assertNotIn(forbidden, upcoming + badge)

    def test_action_fit_uses_native_intrinsic_sizes_not_locale_or_type_thresholds(self):
        layout = self.source.split('struct AlongActionLayout:', 1)[1].split('struct AlongDoneButton:', 1)[0]
        for token in ['sizeThatFits(.unspecified).width', 'Self.fitsRow(', '(widths.max() ?? 0)',
                      'ProposedViewSize(width: cellWidth, height: nil)', 'row ? rowHeight : height',
                      'anchor: .topLeading', 'proposal: ProposedViewSize(rect.size)']:
            self.assertIn(token, layout)
        for forbidden in ['dynamicTypeSize', 'Locale', 'rightToLeft', 'ViewThatFits', 'minimumScaleFactor']:
            self.assertNotIn(forbidden, layout)
        buttons = self.source.split('struct AlongDoneButton:', 1)[1].split('struct UpNextRail:', 1)[0]
        for token in ['Text(title).fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)',
                      'PrimaryButtonStyle()', 'SecondaryButtonStyle()']:
            self.assertIn(token, buttons)
        for forbidden in ['lineLimit', 'minimumScaleFactor', 'dynamicTypeSize', '.clipped()']:
            self.assertNotIn(forbidden, buttons)

    def test_same_actions_roles_localization_and_loop_semantics_remain(self):
        controls = self.source.split('@ViewBuilder private var controls:', 1)[1].split('private var ladderPicker:', 1)[0]
        for token in ['AlongActionLayout(spacing: 10)', 'if loop != nil',
                      'doneButton("Try again", primary: !clean) { reset() }',
                      'doneButton("Done", primary: clean) { exitLoop() }',
                      'doneButton("Try again", primary: retryFirst) { reset() }',
                      'doneButton("Continue", primary: !retryFirst) { complete() }',
                      '.accessibilityIdentifier("along.again")', '.accessibilityIdentifier("along.loop.exit")',
                      '.accessibilityIdentifier("lesson.continue")', '.lessonControl(.again) { reset() }',
                      '.lessonControl(.primary) { complete() }', '.lessonControl(.primary) { exitLoop() }']:
            self.assertIn(token, controls)
        self.assertEqual(controls.count('doneButton("Continue"'), 1)
        self.assertNotIn('ViewThatFits', controls)

    def test_queue_uses_existing_flow_and_intrinsic_minimum_tile_sizes(self):
        rail = self.source.split('struct UpNextRail:', 1)[1].split('/// The take so far,', 1)[0]
        for token in ['ChordFlowLayout(spacing: 8, lineSpacing: 8)', 'ForEach(shown, id: \\.self)',
                      'static let length = 6', '.environment(\\.layoutDirection, .leftToRight)',
                      '.accessibilityHidden(true)', 'FingerPlace(at, on: fingerboard).shortLabel',
                      'Text(NoteName.pitchClass(note.midi))', '.fixedSize(horizontal: false, vertical: true)',
                      '.padding(.horizontal, 8).padding(.vertical, 6)', '.frame(minWidth: 42, minHeight: 42)',
                      '.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)']:
            self.assertIn(token, rail)
        for forbidden in ['.frame(width: 42, height: 42)', '.frame(height: 44)', 'minimumScaleFactor',
                          'lineLimit', 'dynamicTypeSize', 'ScrollView']:
            self.assertNotIn(forbidden, rail)

    def test_native_cases_cover_actual_components_and_previous_badge_negative(self):
        for token in ['["en", "de", "ar"]', 'DynamicTypeSize.large, .accessibility5',
                      '[CGFloat(280), 362]', 'AlongDoneButton(title:', 'ActionFitProbe(available: width)',
                      'AlongPlaceLabel(words: words', 'NotePlace.words(Fretting(string: 6, fret: 0)',
                      'XCTAssertEqual(measured.height, reference.height', 'let former = Text(verbatim: words)',
                      'XCTAssertLessThan(measure(former', 'UpNextRail(notes: notes',
                      'XCTAssertGreaterThan(large.height, normal.height', 'XCTAttachment(image: image)']:
            self.assertIn(token, self.native)
        self.assertNotIn('XCTSkip', self.native)

    def test_whole_step_keeps_reachability_checks_and_adds_ax5_column_evidence(self):
        along = self.ui.split('func testPlayAlongStartAndCompletedTakeAtAX5()', 1)[1]
        for token in ['element("along.next")', 'scrollClear(cue)',
                      'XCTAssertEqual(cue.label, "Next: E, String 6, open")', 'capture("along-ready-cue-clear")',
                      'scrollClear(start)', 'scrollClear(again)', 'XCTAssertTrue(isClear(again))',
                      'XCTAssertLessThanOrEqual(again.frame.maxY, start.frame.minY)',
                      'XCTAssertGreaterThan(start.frame.width, app.frame.width * 0.75)',
                      'capture("along-done-actions-clear")', 'start.tap()', 'element("lesson.results.level")']:
            self.assertIn(token, along)
        self.assertNotIn('XCTSkip', along)


if __name__ == '__main__':
    unittest.main()
