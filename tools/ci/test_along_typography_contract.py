"""Source guards only; native component and whole-step observations are required for approval."""
import hashlib
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

    def test_completed_ax_results_get_intrinsic_height_without_changing_the_runway(self):
        branch = self.source.split('@ViewBuilder private var stage:', 1)[1].split('private var runwayStage:', 1)[0]
        for token in ['typeSize.isAccessibilitySize && phase == .done',
                      'AlongResultSurface(tint: scoreTint) { summaryCard(compact: true) }',
                      '} else {\n            runwayStage']:
            self.assertIn(token, branch)
        normal = self.source.split('    private var runwayStage: some View {', 1)[1].split('    /// What VoiceOver reads', 1)[0]
        self.assertEqual(hashlib.sha256(normal.encode()).hexdigest(), '061424689d28a1f7de8f4561c5bba70664485f7efc26da04ef319cb50576dba2')
        panel = self.source.split('    private var resultsPanel: some View {', 1)[1].split("    /// The take's score", 1)[0]
        self.assertEqual(hashlib.sha256(panel.encode()).hexdigest(), 'cd25a4ee835075a1e8c611a5b45de6c691ac89fe458f1eb46ec1763630618364')
        self.assertEqual(self.source.count('ScrollView { stepContent }'), 1)
        self.assertIn('.accessibilityIdentifier("along.scroll")', self.source)

    def test_result_surface_measures_content_and_masks_only_its_background(self):
        surface = self.source.split('struct AlongResultSurface<', 1)[1].split('struct AlongResultStats:', 1)[0]
        for token in ['content.fixedSize(horizontal: false, vertical: true)', '.padding(12)',
                      '.frame(maxWidth: .infinity, minHeight: 420)', '.background {', '.clipShape(']:
            self.assertIn(token, surface)
        self.assertLess(surface.index('content.fixedSize'), surface.index('.background {'))
        self.assertLess(surface.index('.background {'), surface.index('.clipShape('))
        for forbidden in ['maxHeight:', '.frame(height:', 'ScrollView', 'minimumScaleFactor', 'lineLimit']:
            self.assertNotIn(forbidden, surface)
        summary = self.source.split('private func summaryCard', 1)[1].split('/// The ladder moved up', 1)[0]
        for token in ['.accessibilityFocused($resultsFocused)', '.accessibilityLabel(Text(verbatim: resultSpoken))',
                      '.minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.7)',
                      'Button { calibrating = true }', '.accessibilityActions {', 'if typeSize.isAccessibilitySize {',
                      'guard voiceOver else { return }', 'spokenChoice = !spoken',
                      'spoken ? Text("Turn spoken cues off") : Text("Turn spoken cues on")',
                      'if percent >= LessonRun.greatTake && loop == nil',
                      'takeShare.padding(.top, 2)', '.accessibilityIdentifier("along.slower")',
                      '.lessonControl(.slower) { ladder.select(0); reset() }']:
            self.assertIn(token, summary)

    def test_complete_result_labels_flow_only_at_accessibility_sizes(self):
        components = self.source.split('struct AlongResultStats:', 1)[1].split('struct AlongPlaceLabel:', 1)[0]
        for token in ['AnyLayout(ChordFlowLayout(spacing: 18, lineSpacing: 10))',
                      'AnyLayout(HStackLayout(spacing: 18))', '"Perfect"', '"Good"', '"Early/late"', '"Missed"',
                      '.fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)',
                      'ChordFlowLayout(spacing: 6, lineSpacing: 6)',
                      'Text("Tempo up").fixedSize(horizontal: false, vertical: true)',
                      '.accessibilityElement(children: .combine)', '.accessibilityIdentifier("along.result.tempo-up")']:
            self.assertIn(token, components)
        for forbidden in ['lineLimit', 'minimumScaleFactor', '.dynamicTypeSize(', '.clipped()', 'ScrollView']:
            self.assertNotIn(forbidden, components)

    def test_result_component_proof_keeps_original_ceiling_negative_and_normal_control(self):
        for token in ['testAXResultSurfaceUsesContentHeightInsteadOfTheFormerStageCeiling',
                      'AlongResultSurface(tint: Palette.mint)', 'max(420, natural.height + 24)',
                      'XCTAssertGreaterThan(actual.height, 420', 'Color.clear.frame(height: 420).overlay(content.padding(12))',
                      'testResultStatsAndTempoReserveFullLocalizedNativeText', 'AlongResultStat(label: label',
                      'XCTAssertEqual(actual.height, reference.height', 'AlongTempoUpLabel(percent: 110',
                      'testNormalResultStatsKeepTheirOriginalRowGeometry', 'originalResultStat("Early/late"',
                      'SharePill(preview: "Right on the beat", tint: Palette.mint, armed: false)',
                      'not a fabricated completed session or hosted screen']:
            self.assertIn(token, self.native)

    def test_real_completed_take_checks_each_label_and_share_in_its_own_viewport(self):
        along = self.ui.split('func testPlayAlongStartAndCompletedTakeAtAX5()', 1)[1]
        for token in ['let alongScroll = app.scrollViews["along.scroll"]',
                      'scrollClear(stat, in: alongScroll)', 'XCTAssertEqual(stat.label, label)',
                      'isClear(stat, within: contentViewport(alongScroll, above: nil))',
                      'scrollClear(tempoUp, in: alongScroll)', 'scrollClear(timing, in: alongScroll)',
                      'let share = app.buttons["along.share"]', 'scrollClear(share, in: alongScroll)',
                      'isClear(share, within: contentViewport(alongScroll, above: nil))',
                      'XCTAssertTrue(share.isEnabled)', 'capture("along-result-share-clear")',
                      'scrollClear(again)', 'capture("along-done-actions-clear")', 'element("lesson.results.level")']:
            self.assertIn(token, along)
        self.assertNotIn('XCTSkip', along)


if __name__ == '__main__':
    unittest.main()
