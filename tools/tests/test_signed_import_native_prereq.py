"""3.62 native prerequisite preservation; does not re-execute old runtimes or N01-N02."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-native-prereq/'
BASE = '0b7ef6650b05c9897e48ec97f409bf2eb8f0f6d1'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def slice_commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None


def at_slice(path):
    ref = slice_commit()
    return git('show', ref + ':' + path) if ref else (ROOT / path).read_bytes()


class NativePrereqTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = json.loads(at_slice(FOLDER + 'contract.json'))
        cls.a = json.loads(at_slice(FOLDER + 'artifacts.json'))

    def test_three_linux_artifacts_and_compiled_sentinels(self):
        self.assertTrue(self.a['passed'])
        self.assertEqual(set(self.a['builds']), {'default', 'opt-in', 'fixture'})
        apps = {name: build['appSha256'] for name, build in self.a['builds'].items()}
        self.assertEqual(len(set(apps.values())), 3)
        for name, build in self.a['builds'].items():
            want = name == 'fixture'
            self.assertEqual(build['fixtureSentinelsPresent'], want, name)
            self.assertEqual(all(build['sentinelsPresent'].values()), want, name)
            for hits in build['sentinelHits'].values():
                if want:
                    self.assertEqual(hits, ['lib/libapp.so'])
                else:
                    self.assertEqual(hits, [])
        for p, h in self.a['sourceSha256'].items():
            self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(), h, p)
            self.assertEqual(h, self.c.get('sourceSha256', self.a['sourceSha256'])[p] if p in self.a['sourceSha256'] else h)

    def test_qualified_gates_do_not_claim_profiles_or_combined_acceptance(self):
        self.assertEqual(self.c['qualifiedNativeGates'], ['NG0', 'NG1', 'NG2', 'NG3'])
        self.assertEqual(self.c['qualifiedNativeRows'], [])
        self.assertEqual(self.c['nativeProfilesQualified'], [])
        self.assertEqual(self.c['pendingNativeProfiles'], ['N01', 'N02'])
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertFalse(self.c['allLateRuntimeGatesComplete'])
        self.assertFalse(self.c['l01Rerun'])
        self.assertFalse(self.c['combinedAcceptanceClaimed'])

    def test_canaries_and_startup_allowlists_have_no_remote_network(self):
        watch = json.loads(at_slice(FOLDER + 'watch-canary.json'))
        strace = json.loads(at_slice(FOLDER + 'strace-canary.json'))
        keyboard = json.loads(at_slice(FOLDER + 'keyboard-canary.json'))
        allow = json.loads(at_slice(FOLDER + 'startup-allowlist.json'))
        self.assertTrue(watch['passed'])
        self.assertEqual(sorted(watch['observedTypes']), ['create', 'delete', 'modify', 'move'])
        self.assertTrue(strace['passed'])
        self.assertFalse(strace['traceDataLoss'])
        self.assertTrue(strace['sawOpenCreate'] and strace['sawLoopbackConnect'])
        self.assertTrue(keyboard['passed'])
        self.assertIn('not N01', keyboard['scope'])
        for name, row in allow.items():
            self.assertTrue(row['smokeOk'], name)
            self.assertFalse(row['traceDataLoss'], name)
            for endpoint in row['endpoints']:
                self.assertIn('AF_UNIX', endpoint)
                self.assertNotIn('AF_INET', endpoint)

    def test_exact_runtime_delta_and_license_preserved(self):
        trees = ['apps', 'packages', 'native', 'fixtures', 'pubspec.lock']
        refs = [self.c['base']] + ([slice_commit()] if slice_commit() else [])
        changed = set(git('diff', '--name-only', *refs, '--', *trees).decode().splitlines())
        if not slice_commit():
            changed.update(git('ls-files', '--others', '--exclude-standard', '--', *trees).decode().splitlines())
        self.assertEqual(sorted(changed), self.c['allowedRuntimeChanges'])
        main = git('show', self.c['base'] + ':apps/studio_demo/lib/main.dart')
        self.assertEqual(at_slice('apps/studio_demo/lib/main.dart'), main)
        license_p = 'packages/studio_assets/third_party/sodium_web/LICENSE.core'
        self.assertEqual(at_slice(license_p), git('show', self.c['base'] + ':' + license_p))
        self.assertEqual(hashlib.sha256(at_slice(license_p)).hexdigest(), self.a['licenseCoreSha256'])

    def test_host_seam_is_actual_app_and_not_web_import(self):
        host = at_slice('apps/studio_demo/lib/skill_import_host.dart').decode()
        panel = at_slice('apps/studio_demo/lib/skill_import_panel.dart').decode()
        entry = at_slice('apps/studio_demo/test/import_native_fixture_entrypoint.dart').decode()
        reader = at_slice('apps/studio_demo/test/import_native_reader.dart').decode()
        self.assertIn('const SkillImportHost.testImport(', host)
        self.assertIn('importFixture = null', host)
        self.assertIn('FoundationApp(workspace: widget.workspace)', host)
        self.assertIn('_projectMounted', host)
        self.assertIn('SodiumVerifier.loadTrusted', host)
        self.assertNotIn('openDemo', host)
        self.assertIn('ownerLifetime', panel)
        self.assertIn('invalidateBeforePublication', at_slice('apps/studio_demo/lib/import_fixture_composition.dart').decode())
        self.assertIn('nowSeconds: 1000', entry)
        self.assertIn('ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=', entry)
        self.assertNotIn('ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=', host)
        self.assertIn('currentAppStillValid: guard', reader)
        self.assertIn('return result;', reader)
        self.assertNotIn('package:studio_web/', reader)
        self.assertNotIn('SkillReadToken', reader)
        self.assertIn('No issues found!', (ROOT / FOLDER / 'analyzer.log').read_text())
        self.assertIn('0 changed', (ROOT / FOLDER / 'format.log').read_text())
        self.assertIn('+9: All tests passed!', (ROOT / FOLDER / 'unit-tests.log').read_text())

    def test_original_task_counts_and_wording_preserved(self):
        p = 'docs/implementation/task-status.json'
        before = json.loads(git('show', self.c['base'] + ':' + p))
        after = json.loads(at_slice(p))
        self.assertEqual(after['counts'], dict(complete=0, partial=62, planned=12, blocked=13))
        self.assertEqual(after['fullTasksCompleted'], 0)
        self.assertEqual(len(after['tasks']), 87)
        for b, a in zip(before['tasks'], after['tasks']):
            if b['id'] != 'I-037':
                self.assertEqual(a, b)
                continue
            for k in b:
                if k == 'implementedScope':
                    self.assertTrue(a[k].startswith(b[k]))
                elif k == 'evidence':
                    self.assertEqual(a[k], b[k] + ['evidence/signed-import-app-native-prereq/'])
                else:
                    self.assertEqual(a[k], b[k], k)
        late = 'docs/studio/spec/s8f-signed-import-app-native-v1.md'
        self.assertTrue(at_slice(late).startswith(git('show', self.c['base'] + ':' + late)))
        acc = 'docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        self.assertTrue(at_slice(acc).startswith(git('show', self.c['base'] + ':' + acc)))


if __name__ == '__main__':
    unittest.main()
