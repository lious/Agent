"""Actual App-host evidence/preservation lint only; no previous runtime requalification."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-host/'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def host_commit():
    commits = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return commits[-1] if commits else None


def at_host(path):
    commit = host_commit()
    return git('show', commit + ':' + path) if commit else (ROOT / path).read_bytes()


class SignedImportAppHostTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((ROOT / FOLDER / 'contract.json').read_text())
        cls.result = json.loads((ROOT / FOLDER / 'browser-results.json').read_text())

    def test_actual_app_profile_and_source_asset_identity(self):
        self.assertTrue(self.result['passed'])
        self.assertEqual(len(self.result['reports']), 6)
        self.assertEqual(self.result['uniqueStyleNonces'], 6)
        self.assertIn('Dart-to-JS', self.result['mode'])
        source = at_host('apps/studio_web/web/flutter_bootstrap.js')
        self.assertEqual(hashlib.sha256(source).hexdigest(), self.result['sourceBootstrapSha256'])
        self.assertNotIn(b'serviceWorkerSettings', source)
        self.assertNotIn(b'<base', at_host('apps/studio_web/web/index.html'))
        for field in ['sourceAdaptersQualified', 'selectionPreviewConsentImplemented', 'productionHostImplemented']:
            self.assertFalse(self.contract[field])

    def test_normal_host_checks_more_than_first_frame(self):
        normal = self.result['reports'][0]
        self.assertEqual(normal['mode'], 'normal')
        self.assertTrue(normal['passed'])
        self.assertTrue(normal['firstFrame'])
        self.assertEqual(normal['views'], 1)
        self.assertEqual(normal['backendState'], 'ready')
        self.assertTrue(normal['nonceStyles'])
        self.assertTrue(all(normal['nonceStyles']))
        for field in ['violations', 'errors', 'failures', 'exceptions', 'remoteRequests', 'registrations']:
            self.assertEqual(normal[field], [], field)
        self.assertIn('/main.dart.js', normal['servedAssetSha256'])
        self.assertEqual(normal['servedAssetSha256']['/main.dart.js'], self.result['compiledMainSha256'])
        self.assertIn('/canvaskit/chromium/canvaskit.wasm', normal['servedAssetSha256'])
        self.assertEqual((ROOT / FOLDER / 'actual-app.png').read_bytes()[:8], b'\x89PNG\r\n\x1a\n')

    def test_negative_profiles_fail_the_intended_gate(self):
        by_mode = {r['mode']: r for r in self.result['reports']}
        for mode in ['sri-tamper', 'csp-vendor-block', 'missing-vendor']:
            self.assertTrue(by_mode[mode]['passed'])
            self.assertTrue(by_mode[mode]['firstFrame'])
            self.assertEqual(by_mode[mode]['backendState'], 'failed')
        self.assertTrue(by_mode['csp-vendor-block']['violations'])
        for mode in ['wrong-style-nonce', 'missing-style-nonce']:
            self.assertTrue(by_mode[mode]['passed'])
            self.assertTrue(any('style-src' in v['directive'] for v in by_mode[mode]['violations']))

    def test_real_csp_and_no_off_origin_or_sw_escape(self):
        for report in self.result['reports']:
            self.assertTrue(report['secureContext'])
            self.assertIn('HeadlessChrome/', report['userAgent'])
            self.assertEqual(report['remoteRequests'], [])
            self.assertEqual(report['registrations'], [])
            self.assertFalse(report['vendorTamperExecuted'])
            self.assertEqual(report['baseElements'], 0)
            for phrase in ["default-src 'none'", "base-uri 'none'", "object-src 'none'",
                           "connect-src 'self'", "worker-src 'none'", "form-action 'none'",
                           "frame-ancestors 'none'", self.result['sri']]:
                self.assertIn(phrase, report['csp'])
            for phrase in ["'unsafe-inline'", "'unsafe-eval'", 'blob:', 'data:']:
                self.assertNotIn(phrase, report['csp'])

    def test_existing_backend_acceptance_plan_and_lock_files_preserved(self):
        for path, digest in self.contract['unchangedFiles'].items():
            original = git('show', self.contract['base'] + ':' + path)
            self.assertEqual(hashlib.sha256(original).hexdigest(), digest, path)
            self.assertEqual(at_host(path), original, path)
            if path == 'tools/tests/test_acceptance.py':
                self.assertEqual((ROOT / path).read_bytes(), original, path)
        commit = host_commit()
        paths = ['apps', 'packages', 'native', 'pubspec.lock']
        refs = [self.contract['base']] + ([commit] if commit else [])
        changed = set(git('diff', '--name-only', *refs, '--', *paths).decode().splitlines())
        if commit is None:
            changed.update(git('ls-files', '--others', '--exclude-standard', '--', *paths).decode().splitlines())
        self.assertEqual(sorted(changed), sorted(self.contract['allowedRuntimeChanges']))

    def test_status_is_only_an_implementation_scope_append(self):
        old = json.loads(git('show', self.contract['base'] + ':docs/implementation/task-status.json'))
        new = json.loads(at_host('docs/implementation/task-status.json'))
        self.assertEqual(new['counts'], self.contract['statusCounts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
                continue
            for key in before:
                if key == 'implementedScope':
                    self.assertTrue(after[key].startswith(before[key]))
                elif key == 'evidence':
                    self.assertEqual(after[key], before[key] + ['evidence/signed-import-app-host/'])
                else:
                    self.assertEqual(after[key], before[key], key)


if __name__ == '__main__':
    unittest.main()
