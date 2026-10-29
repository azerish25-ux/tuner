#!/usr/bin/env python3
"""Synthetic API/evidence tests: no credentials, network, signing or uploading."""
import copy
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError

spec = importlib.util.spec_from_file_location('preflight', Path(__file__).with_name('apple_delivery_preflight.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
SHA = 'a' * 40


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.env = {'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': SHA,
                    'GITHUB_REPOSITORY': 'owner/repo'}
        self.branch = {'commit': {'sha': SHA}}
        self.workflow = {'id': 7, 'path': p.WORKFLOW}
        self.run = {'id': 42, 'head_sha': SHA, 'head_branch': 'main', 'event': 'push',
                    'workflow_id': 7, 'path': p.WORKFLOW, 'repository': {'full_name': 'owner/repo'},
                    'status': 'completed', 'conclusion': 'success'}
        self.runs = [self.run]
        self.jobs = [{'name': name, 'head_sha': SHA, 'run_id': 42,
                      'status': 'completed', 'conclusion': 'success'} for name in p.REQUIRED_JOBS]

    def get(self, path):
        if path.endswith('/branches/main'):
            return self.branch
        if path.endswith('/workflows/ios.yml'):
            return self.workflow
        if '/ios.yml/runs?' in path:
            self.assertIn('head_sha=' + SHA, path)
            self.assertNotIn('status=success', path)
            return {'workflow_runs': self.runs}
        self.assertIn('/runs/42/jobs?filter=latest', path)
        return {'jobs': self.jobs, 'total_count': len(self.jobs)}

    def verify(self):
        return p.verify_native_gate(self.env, SHA, self.get)

    def test_exact_source_passes(self):
        self.assertEqual(self.verify(), 42)

    def test_non_main_rejected(self):
        for ref in ('refs/heads/feature', 'refs/tags/main', ''):
            self.env['GITHUB_REF'] = ref
            with self.assertRaises(p.PreflightError): self.verify()

    def test_checkout_and_stale_remote_main_rejected(self):
        with self.assertRaises(p.PreflightError): p.verify_native_gate(self.env, 'b'*40, self.get)
        self.branch['commit']['sha'] = 'b'*40
        with self.assertRaises(p.PreflightError): self.verify()

    def test_wrong_source_workflow_event_or_repo_rejected(self):
        for field, value in [('head_sha', 'b'*40), ('head_branch', 'feature'),
                             ('workflow_id', 8), ('path', '.github/workflows/fake.yml'),
                             ('event', 'pull_request'), ('repository', {'full_name': 'other/repo'})]:
            with self.subTest(field=field):
                old = self.run[field]
                self.run[field] = value
                with self.assertRaises(p.PreflightError): self.verify()
                self.run[field] = old

    def test_workflow_identity_and_missing_run_rejected(self):
        self.workflow['path'] = '.github/workflows/fake.yml'
        with self.assertRaises(p.PreflightError): self.verify()
        self.workflow['path'] = p.WORKFLOW
        self.runs = []
        with self.assertRaises(p.PreflightError): self.verify()

    def test_skipped_failed_pending_runs_rejected(self):
        for conclusion in ('failure', 'skipped', 'cancelled', 'neutral', 'timed_out', None):
            self.run['conclusion'] = conclusion
            with self.assertRaises(p.PreflightError): self.verify()
        self.run['conclusion'] = 'success'
        self.run['status'] = 'in_progress'
        with self.assertRaises(p.PreflightError): self.verify()

    def test_latest_failure_does_not_reuse_older_success(self):
        old = copy.deepcopy(self.run)
        old['id'] = 41
        self.runs.append(old)
        self.run['conclusion'] = 'failure'
        with self.assertRaises(p.PreflightError): self.verify()

    def test_failed_sdk_report_is_advisory_only_with_exact_source_successful_required_gate(self):
        self.run['conclusion'] = 'failure'
        audit = next(job for job in self.jobs if job['name'] == 'accessibility')
        audit['conclusion'] = 'failure'
        self.assertEqual(self.verify(), 42)
        gate = next(job for job in self.jobs if job['name'] == 'gate')
        gate['conclusion'] = 'failure'
        with self.assertRaises(p.PreflightError): self.verify()
        gate['conclusion'] = 'success'
        self.jobs.append({'name': 'publish results', 'head_sha': SHA, 'run_id': 42,
                          'status': 'completed', 'conclusion': 'failure'})
        with self.assertRaises(p.PreflightError): self.verify()

    def test_delivery_version_requires_explicit_account_matched_input(self):
        workflow = (p.ROOT / '.github/workflows/apple-delivery.yml').read_text()
        field = workflow.split('      marketing_version:\n', 1)[1].split('      build_number:', 1)[0]
        self.assertIn('required: true', field)
        self.assertNotIn('default:', field)

    def test_every_required_job_is_mandatory(self):
        for name in p.REQUIRED_JOBS:
            saved = self.jobs
            self.jobs = [j for j in saved if j['name'] != name]
            with self.subTest(name=name), self.assertRaises(p.PreflightError): self.verify()
            self.jobs = saved

    def test_skipped_failed_stale_ambiguous_jobs_rejected(self):
        for field, value in [('conclusion', 'skipped'), ('conclusion', 'failure'),
                             ('conclusion', None), ('status', 'queued'),
                             ('head_sha', 'b'*40), ('run_id', 41)]:
            old = self.jobs[-1][field]
            self.jobs[-1][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(p.PreflightError): self.verify()
            self.jobs[-1][field] = old
        self.jobs.append(copy.deepcopy(self.jobs[-1]))
        with self.assertRaises(p.PreflightError): self.verify()

    def credentials(self):
        return {'APPLE_TEAM_ID': 'A'*10, 'APP_STORE_CONNECT_KEY_ID': 'B'*10,
                'APP_STORE_CONNECT_ISSUER_ID': '12345678-1234-1234-1234-123456789012',
                'APP_STORE_CONNECT_API_KEY_P8': '-----BEGIN PRIVATE KEY-----\nSYNTHETIC-NOT-A-KEY\n-----END PRIVATE KEY-----',
                'MARKETING_VERSION': '2.0.0', 'BUILD_NUMBER': '1', 'SHIP_MIN_COVERAGE': ''}

    def test_valid_input_formats(self):
        p.validate_inputs(self.credentials())

    def test_language_subset_selection_is_rejected(self):
        env = self.credentials()
        env['SHIP_MIN_COVERAGE'] = '95'
        with self.assertRaises(p.PreflightError): p.validate_inputs(env)
        workflow = (p.ROOT / '.github/workflows/apple-delivery.yml').read_text()
        self.assertNotIn('ship_min_coverage', workflow)
        self.assertNotIn('--apply', workflow)
        self.assertNotIn('SHIP_MIN_COVERAGE', workflow)
        self.assertIn('shipping.py --xliff ci-out/en.xliff --require-complete', workflow)

    def test_missing_credentials_dont_expose_values(self):
        for name in p.CREDENTIALS:
            env = self.credentials()
            del env[name]
            with self.assertRaises(p.PreflightError) as caught: p.validate_inputs(env)
            self.assertIn(name, str(caught.exception))
            self.assertNotIn('SYNTHETIC-NOT-A-KEY', str(caught.exception))

    def test_invalid_credentials_dont_expose_values(self):
        for name in p.CREDENTIALS:
            env = self.credentials()
            env[name] = 'SENSITIVE-INVALID-VALUE'
            with self.assertRaises(p.PreflightError) as caught: p.validate_inputs(env)
            self.assertNotIn('SENSITIVE-INVALID-VALUE', str(caught.exception))

    def test_release_failure_blocks(self):
        runner = Mock(return_value=SimpleNamespace(returncode=1))
        with self.assertRaises(p.PreflightError): p.verify_release_evidence(runner)
        self.assertEqual(runner.call_args.args[0][-2:], ['tools/l10n/store.py', '--release'])
        runner.return_value.returncode = 0
        p.verify_release_evidence(runner)

    def test_api_failure_is_sanitized_and_fails_closed(self):
        error = HTTPError('https://api.github.com/example', 403, 'SENSITIVE-RESPONSE', {}, None)
        with patch.object(p, 'urlopen', side_effect=error):
            with self.assertRaises(p.PreflightError) as caught:
                p.github_get('repos/owner/repo/branches/main', 'SENSITIVE-TOKEN')
        self.assertNotIn('SENSITIVE', str(caught.exception))

    def test_internal_channel_has_no_release_evidence_bypass(self):
        source = Path(p.__file__).read_text()
        self.assertIn('verify_release_evidence()', source)
        # The workflow retains internal-only export semantics; the shared preflight is unconditional.
        workflow = (p.ROOT / '.github/workflows/apple-delivery.yml').read_text()
        section = workflow.split('- name: Verify exact main source', 1)[1].split('- name:', 1)[0]
        self.assertNotIn('if:', section)

    def test_workflow_guards_and_order(self):
        workflow = (p.ROOT / '.github/workflows/apple-delivery.yml').read_text()
        self.assertIn('if: ${{ inputs.confirm_delivery }}', workflow)
        self.assertIn('environment: apple-delivery', workflow)
        self.assertIn('actions: read', workflow)
        self.assertLess(workflow.index('tools/ci/apple_delivery_preflight.py'),
                        workflow.index('Install the API key'))
        self.assertIn("options['testFlightInternalTestingOnly'] = True", workflow)


if __name__ == '__main__':
    unittest.main()
