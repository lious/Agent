"""3.55 new-fixture acceptance and exact preservation, no old runtime suites."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-fixture/'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class AppFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = json.loads((ROOT / FOLDER / 'contract.json').read_text())

    def test_four_new_actual_compiled_browser_cases(self):
        for case in ['B01', 'B02', 'B03', 'B04']:
            r = json.loads((ROOT / FOLDER / (case + '.json')).read_text())
            self.assertEqual(r['caseId'], case)
            for flag in ['passed', 'verifiedReportObserved', 'noAutoAcknowledgment', 'noImportWrites', 'storageSnapshotUnchanged']:
                self.assertTrue(r[flag])
            self.assertEqual(r['oneUseAcknowledgment'], case != 'B04')
            self.assertEqual(r['chooserCount'], 1)
            self.assertEqual(r['violations'], [])
            self.assertEqual(r['exceptions'], [])
            self.assertIn('WebStudioApp.testImport', r['actualApp'])
            self.assertEqual(r['fixtureExpected']['nowSeconds'], 1000)
            self.assertEqual(r['fixtureExpected']['signer']['keyFingerprint'], self.c['publicFingerprint'])
            self.assertIn(r['sri'], r['csp'])
            self.assertIn("base-uri 'none'", r['csp'])
            self.assertNotIn("'unsafe-eval'", r['csp'])
            self.assertNotIn("'unsafe-inline'", r['csp'])
            self.assertIn('/main.dart.js', r['servedAssetSha256'])

    def test_three_artifact_exclusion_proofs(self):
        a = json.loads((ROOT / FOLDER / 'artifacts.json').read_text())
        self.assertTrue(a['passed'])
        for name in ['default', 'opt-in', 'fixture']:
            self.assertEqual(a['builds'][name]['fixtureSentinelsPresent'], name == 'fixture')
            self.assertEqual(a['builds'][name]['testEntrypointInSourceMap'], name == 'fixture')
        self.assertFalse(a['builds']['default']['optIn'])
        self.assertTrue(a['defaultSourceUsesNullFixture'])
        for path, digest in a['sourceSha256'].items():
            self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(), digest, path)
        for case in ['B01', 'B02', 'B03', 'B04']:
            r = json.loads((ROOT / FOLDER / (case + '.json')).read_text())
            self.assertEqual(r['servedAssetSha256']['/main.dart.js'], a['builds']['fixture']['mainSha256'])
        for path in a['sourceSha256']:
            if path.startswith('apps/studio_web/lib/'):
                source = at_slice(path).decode()
                self.assertNotIn('clockConfident: true', source)
                self.assertNotIn('nowSeconds: 1000', source)

    def test_final_source_digests_and_exact_runtime_delta(self):
        for path, digest in self.c['sourceSha256'].items():
            self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(), digest, path)
        trees = ['apps', 'packages', 'native', 'fixtures', 'pubspec.lock']
        refs = [self.c['base']] + ([commit()] if commit() else [])
        changed = set(git('diff', '--name-only', *refs, '--', *trees).decode().splitlines())
        if not commit():
            changed.update(git('ls-files', '--others', '--exclude-standard', '--', *trees).decode().splitlines())
        self.assertEqual(sorted(changed), self.c['allowedRuntimeChanges'])

    def test_unchanged_crypto_host_license_store_and_lock(self):
        for path, digest in self.c['unchangedFiles'].items():
            old = git('show', self.c['base'] + ':' + path)
            self.assertEqual(hashlib.sha256(old).hexdigest(), digest, path)
            self.assertEqual(at_slice(path), old, path)

    def test_status_and_remaining_acceptance_preserved(self):
        path = 'docs/implementation/task-status.json'
        old = json.loads(git('show', self.c['base'] + ':' + path))
        new = json.loads(at_slice(path))
        self.assertEqual(new['counts'], old['counts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
                continue
            self.assertEqual(after['status'], 'partial')
            for key in before:
                if key == 'implementedScope':
                    self.assertTrue(after[key].startswith(before[key]))
                elif key == 'evidence':
                    self.assertEqual(after[key], before[key] + ['evidence/signed-import-app-fixture/'])
                else:
                    self.assertEqual(before[key], after[key], key)

    def test_only_browser_boundary_clarification_appended_to_plan(self):
        path = 'docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        old = git('show', self.c['base'] + ':' + path)
        self.assertTrue(at_slice(path).startswith(old))
        self.assertIn(b'NOT an OS screen-reader/assistive-device claim', at_slice(path))
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['completedMatrixRows'], ['B01', 'B02', 'B03', 'B04'])
        self.assertEqual(len(self.c['deferredMatrixRows']), 12)

    def test_real_factory_and_no_consent_or_skip_endpoint(self):
        main = at_slice('apps/studio_web/lib/main.dart').decode()
        self.assertIn('importFixture = null', main)
        self.assertIn('createRepository: createWebSignedSkillRepository', main)
        self.assertIn('_importLifetime.invalidateBeforePublication();', main)
        self.assertLess(main.index('_importLifetime.invalidateBeforePublication();'), main.index('_fixture = widget.importFixture;', main.index('void didUpdateWidget')))
        fixture = at_slice('apps/studio_web/lib/import_fixture_composition.dart').decode()
        for forbidden in ['ImportUserActionPort', 'explicitPreviewConsent', 'window', 'localStorage']:
            self.assertNotIn(forbidden, fixture)
        runner = at_slice('tools/acceptance/run_skill_import_app_fixture.py').decode()
        self.assertNotIn('--browser-only', runner)
        self.assertIn("assert hashlib.sha256(vendor)", runner)

    def test_new_lifetime_cases_and_clean_analysis(self):
        self.assertIn('+4: All tests passed!', (ROOT / FOLDER / 'lifetime.log').read_text())
        self.assertIn('No issues found!', (ROOT / FOLDER / 'analyzer.log').read_text())
        self.assertIn('0 changed', (ROOT / FOLDER / 'format.log').read_text())

if __name__ == '__main__':
    unittest.main()
