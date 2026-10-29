#!/usr/bin/env python3
"""Read-only, fail-closed delivery checks; never signs, uploads or prints credentials.

API contracts: https://docs.github.com/en/rest/actions/workflow-runs
https://docs.github.com/en/rest/actions/workflow-jobs
Main must still have the environment's owner approval and branch protection.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = '.github/workflows/ios.yml'
REQUIRED_JOBS = ('core', 'app', 'release', 'accessibility', 'gate')
CREDENTIALS = ('APPLE_TEAM_ID', 'APP_STORE_CONNECT_KEY_ID',
               'APP_STORE_CONNECT_ISSUER_ID', 'APP_STORE_CONNECT_API_KEY_P8')


class PreflightError(Exception):
    """Safe diagnostic, containing no credential values or API response bodies."""


def validate_inputs(env):
    missing = [name for name in CREDENTIALS if not env.get(name)]
    if missing:
        raise PreflightError('Missing apple-delivery environment secrets: ' + ', '.join(missing))
    patterns = {
        'APPLE_TEAM_ID': r'[A-Z0-9]{10}',
        'APP_STORE_CONNECT_KEY_ID': r'[A-Z0-9]{10}',
        'APP_STORE_CONNECT_ISSUER_ID': r'[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}',
        'MARKETING_VERSION': r'[0-9]+\.[0-9]+(?:\.[0-9]+)?',
        'BUILD_NUMBER': r'[1-9][0-9]{0,8}',
    }
    for name, pattern in patterns.items():
        if not re.fullmatch(pattern, env.get(name, '')):
            raise PreflightError('Invalid format for ' + name)
    if env.get('SHIP_MIN_COVERAGE'):
        raise PreflightError('Language subset selection is unsupported for this release')
    key = env['APP_STORE_CONNECT_API_KEY_P8'].strip()
    if not (key.startswith('-----BEGIN PRIVATE KEY-----\n')
            and key.endswith('\n-----END PRIVATE KEY-----')):
        raise PreflightError('APP_STORE_CONNECT_API_KEY_P8 must contain raw PEM private key contents')
    if env.get('BUILD_CHANNEL', '') not in ('', 'internal'):
        raise PreflightError('Invalid BUILD_CHANNEL')


def github_get(path, token):
    request = Request('https://api.github.com/' + path, headers={
        'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
    })
    try:
        with urlopen(request, timeout=30) as response:
            return json.load(response)
    except (HTTPError, URLError, TimeoutError, ValueError):
        raise PreflightError('GitHub evidence request failed; delivery remains blocked') from None


def verify_native_gate(env, checkout_sha, get):
    if env.get('GITHUB_REF') != 'refs/heads/main':
        raise PreflightError('Apple delivery requires refs/heads/main')
    sha = env.get('GITHUB_SHA', '')
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or checkout_sha != sha:
        raise PreflightError('Checkout does not match the exact delivery SHA')
    repo = env.get('GITHUB_REPOSITORY', '')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo):
        raise PreflightError('Invalid GITHUB_REPOSITORY')
    prefix = f'repos/{repo}'
    branch = get(prefix + '/branches/main')
    if branch.get('commit', {}).get('sha') != sha:
        raise PreflightError('Delivery SHA is not the current main revision')
    workflow = get(prefix + '/actions/workflows/ios.yml')
    if workflow.get('path') != WORKFLOW or not isinstance(workflow.get('id'), int):
        raise PreflightError('Required iOS workflow identity is missing or incorrect')
    query = urlencode({'head_sha': sha, 'branch': 'main', 'event': 'push', 'per_page': 100})
    runs = get(prefix + '/actions/workflows/ios.yml/runs?' + query).get('workflow_runs', [])
    if not runs:
        raise PreflightError('No exact-source main iOS run exists')
    # Do not filter for success: a newer failed/pending run must not revive an older green run.
    run = max(runs, key=lambda item: item.get('id', 0))
    if (run.get('head_sha') != sha or run.get('head_branch') != 'main'
            or run.get('event') != 'push' or run.get('workflow_id') != workflow['id']
            or run.get('path', '').split('@')[0] != WORKFLOW
            or run.get('repository', {}).get('full_name') != repo):
        raise PreflightError('iOS run does not belong to this exact main source/workflow')
    if run.get('status') != 'completed' or run.get('conclusion') not in ('success', 'failure'):
        raise PreflightError('Latest exact-source iOS run has not completed with an assessable result')
    jobs = []
    page = 1
    while True:
        result = get(prefix + f"/actions/runs/{run['id']}/jobs?filter=latest&per_page=100&page={page}")
        rows = result.get('jobs', [])
        jobs.extend(rows)
        if len(jobs) >= result.get('total_count', 0):
            break
        if not rows or page >= 100:
            raise PreflightError('Incomplete iOS job evidence')
        page += 1
    for name in REQUIRED_JOBS:
        matches = [job for job in jobs if job.get('name') == name]
        if len(matches) != 1:
            raise PreflightError('Missing or ambiguous required iOS job: ' + name)
        job = matches[0]
        if (job.get('head_sha') != sha or job.get('run_id') != run['id']
                or job.get('status') != 'completed'
                or job.get('conclusion') not in (('success', 'failure') if name == 'accessibility' else ('success',))):
            raise PreflightError('Required iOS job lacks exact-source success: ' + name)
    # The exact-source required gate already checks every SDK step outcome and original partition log.
    # Preserve its explicit advisory policy; do not resurrect a blanket strict-SDK-success requirement.
    unsuccessful = [job for job in jobs if job.get('conclusion') != 'success']
    sdk_only = (len(unsuccessful) == 1 and unsuccessful[0].get('name') == 'accessibility'
                and unsuccessful[0].get('conclusion') == 'failure')
    if ((run.get('conclusion') == 'failure' and not sdk_only)
            or (run.get('conclusion') == 'success' and unsuccessful)):
        raise PreflightError('iOS workflow failure is not exclusively the gate-assessed advisory SDK report')
    return run['id']


def verify_release_evidence(run=subprocess.run):
    result = run([sys.executable, 'tools/l10n/store.py', '--release'], cwd=ROOT,
                 check=False)
    if result.returncode:
        raise PreflightError('Release listing/applicability evidence validation failed')


def main():
    try:
        validate_inputs(os.environ)
        if not os.environ.get('GH_TOKEN'):
            raise PreflightError('Missing read-only GitHub evidence token')
        sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        run_id = verify_native_gate(os.environ, sha,
                                   lambda path: github_get(path, os.environ['GH_TOKEN']))
        verify_release_evidence()
        print(f'Exact-source iOS run {run_id} and release evidence passed preflight.')
        print('Owner approval, signing, Apple processing and submission remain separate gates.')
        return 0
    except (PreflightError, KeyError, TypeError, AttributeError, ValueError, OSError, subprocess.SubprocessError) as error:
        message = str(error) if isinstance(error, PreflightError) else 'Malformed or unavailable delivery evidence'
        print('Apple delivery blocked: ' + message, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
