#!/usr/bin/env python3
"""Source-contract guard only; native audit execution is verified by the iOS Actions job.

Run: python3 tools/ci/test_accessibility_audit_contract.py
"""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()


def section(start: str, end: str) -> str:
    return SOURCE.split(start, 1)[1].split(end, 1)[0]


class AccessibilityAuditContractTests(unittest.TestCase):
    def test_all_seven_kinds_remain_required(self):
        kinds = section('private static let kinds:', '/// Tries')
        self.assertEqual(re.findall(r'type: \.(\w+), name:', kinds), [
            'contrast', 'sufficientElementDescription', 'hitRegion', 'dynamicType',
            'textClipped', 'trait', 'elementDetection',
        ])
        audit = section('private func audit(_', '/// An isolated kind')
        fresh = audit.split('if let replay {', 1)[1].split('} else if', 1)[0]
        self.assertIn('for kind in Self.kinds', fresh)
        self.assertIn('replay: replay', fresh)
        self.assertIn('unfinished.append', fresh)
        self.assertNotIn('types: .all', fresh)

    def test_tunecheck_diagnostic_is_single_additive_and_not_retry_to_green(self):
        audit = section('private func audit(_', '/// An isolated kind')
        diagnostic = audit.split('// Diagnostic only:', 1)[1].split('let header', 1)[0]
        self.assertIn('screen == "lesson-tunecheck"', diagnostic)
        self.assertIn('findings.opaqueContrastCallbacks > 0', diagnostic)
        self.assertIn('findings.isolatedContrastRequests == 0', diagnostic)
        self.assertEqual(diagnostic.count('run(screen, types: .contrast'), 1)
        self.assertIn('into: findings, captureAllCallbacks: true', diagnostic)
        self.assertIn('unfinished.append', diagnostic)
        self.assertEqual(diagnostic.count('attachAuditState('), 2)
        for prohibited in ['Findings()', 'findings.failing =', 'removeAll', 'settle(', 'auditKind(', 'for ', 'while ']:
            self.assertNotIn(prohibited, diagnostic)
        self.assertLess(audit.index('Completed all audit kinds.'), audit.index('// Diagnostic only:'))
        self.assertLess(audit.index('// Diagnostic only:'), audit.index('for line in findings.failing'))
        run = section('private func run(', '/// Before/after evidence')
        self.assertIn('if types == .contrast { findings.isolatedContrastRequests += 1 }', run)
        self.assertIn('if issue.auditType == .contrast { findings.opaqueContrastCallbacks += 1 }', run)
        self.assertIn('if captureAllCallbacks {', run)
        self.assertIn('ax-diagnostic-callback-', run)

    def test_tab_discovery_and_fresh_navigation_are_verified(self):
        tabs = section('func testEveryTab()', 'func testSettingsAndPaywall()')
        for guard in ['XCTAssertGreaterThan(count, 0)', 'for index in 0..<count',
                      'replay:', 'app.terminate()', 'launchOnboarded()',
                      'buttons.count == count', 'button.label == name', 'return button.isSelected']:
            self.assertIn(guard, tabs)
        self.assertLess(tabs.index('app.terminate()'), tabs.index('launchOnboarded()', tabs.index('app.terminate()')))

    def test_replay_happens_inside_every_attempt_before_audit(self):
        attempt = section('private func auditKind(', '/// One request')
        self.assertLess(attempt.index('for attempt in 1...Self.attempts'), attempt.index('guard replay()'))
        self.assertLess(attempt.index('guard replay()'), attempt.index('problem = run('))
        self.assertIn('return reason', attempt)
        self.assertIn('return problem', attempt)
        self.assertIn('private static let attempts = 3', SOURCE)

    def test_failures_and_unfinished_audits_are_not_discarded(self):
        audit = section('private func audit(_', '/// An isolated kind')
        self.assertIn('for problem in unfinished', audit)
        self.assertIn('for line in findings.failing', audit)
        self.assertEqual(audit.count('XCTFail('), 2)
        self.assertNotIn('removeAll', SOURCE)
        self.assertNotIn('XCTSkip', SOURCE)
        self.assertIn('findings.failing.append(line)', SOURCE)
        self.assertIn('enforced.contains(issue.auditType) && reason == nil', SOURCE)

    def test_opaque_callbacks_remain_distinct_and_explain_snapshot_failure(self):
        run = section('private func run(', '/// Before/after evidence')
        self.assertIn('findings.callbacks += 1', run)
        self.assertIn('element nil', run)
        self.assertIn('snapshot threw:', run)
        self.assertIn('snapshot = try element.snapshot()', run)
        self.assertNotIn('try? issue.element', run)
        self.assertIn('callback \\(findings.callbacks)', run)
        self.assertIn('snapshot?.identifier', run)
        self.assertIn('snapshot?.label', run)
        self.assertIn('$0.frame', run)
        self.assertIn('$0.elementType.rawValue', run)
        self.assertIn('issue.detailedDescription', run)

    def test_hierarchy_queries_stay_outside_the_handler(self):
        run = section('private func run(', '/// Before/after evidence')
        handler = run.split('try app.performAccessibilityAudit', 1)[1].split('return nil', 1)[0]
        self.assertNotIn('attachAuditState', handler)
        self.assertNotIn('debugDescription', handler)
        self.assertIn('defer {', run)
        self.assertIn('incomplete || findings.opaqueCallbacks > previousOpaque', run)
        self.assertIn('XCUIScreen.main.screenshot()', handler)
        self.assertIn('XCTAttachment(string: app.debugDescription)', SOURCE)

    def test_existing_screen_coverage_is_preserved(self):
        for screen in ['welcome', 'settings', 'paywall', 'lesson-explain', 'lesson-tunecheck',
                       'lesson-notes', 'lesson-along-ready', 'metronome']:
            self.assertIn(f'audit("{screen}")', SOURCE)

    def test_known_exclusions_and_enforcement_are_unchanged(self):
        known = section('private static let known:', 'private static let kinds:')
        self.assertEqual(hashlib.sha256(known.encode()).hexdigest(), '39ea29e7eccb4147f2649c3e6624a447cfc84e19463626b52496846b46127a7c')
        self.assertIn('private static let enforced: XCUIAccessibilityAuditType = [.contrast, .hitRegion, .sufficientElementDescription, .trait]', SOURCE)


if __name__ == '__main__':
    unittest.main()
