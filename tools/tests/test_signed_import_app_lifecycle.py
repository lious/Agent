"""3.56 lifecycle evidence/preservation only; never reruns old qualification."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-lifecycle/'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class AppLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = json.loads((ROOT / FOLDER / 'contract.json').read_text())
        cls.results = {x: json.loads((ROOT / FOLDER / (x + '.json')).read_text()) for x in cls.c['variants']}

    def test_eleven_new_independent_browser_variants(self):
        self.assertEqual(len(self.results), 11)
        for name, r in self.results.items():
            self.assertEqual(r['caseId'], name)
            for flag in ['passed','noAcknowledgment','storageSnapshotUnchanged','noComponentWrites']:
                self.assertTrue(r[flag], (name, flag))
            self.assertFalse(r['nativeTraceDataLoss'])
            self.assertEqual(r['exceptions'], [])
            self.assertEqual(r['violations'], [])
            self.assertIn(r['sri'], r['csp'])
            self.assertNotIn("'unsafe-inline'", r['csp'])
            self.assertNotIn("'unsafe-eval'", r['csp'])
            self.assertEqual(len({d['nonce'] for d in r['documentResponses']}), len(r['documentResponses']))

    def test_real_cancel_navigation_and_late_reader(self):
        self.assertTrue(self.results['B05']['details']['trustedNativeCancel'])
        self.assertEqual(self.results['B05']['details']['sameFileSelections'], 3)
        for name in ['B06-reload','B06-away-back','B07-reading-navigation']:
            r = self.results[name]; d = r['details']
            self.assertTrue(d['actualNavigation'])
            self.assertTrue(any(t['event']=='pagehide' and t['isTrusted'] and t['realm']==d['oldRealm'] for t in r['traces']))
            self.assertEqual(d['bfcacheRestored'], d['oldRealm']==d['newRealm'])
        self.assertTrue(self.results['B07-reading-navigation']['details']['lateOldFutureObserved'])
        for name in ['B07-reading-navigation','B07-reading-handler-only']:
            d = self.results[name]['details']
            self.assertEqual(d.get('lateReader', d.get('reader')), dict(opens=1, reads=1, completions=1, closes=1))
        self.assertTrue(self.results['B07-reading-handler-only']['details']['syntheticHandlerOnly'])
        self.assertTrue(self.results['B06-dispose']['details']['actualWidgetUnmount'])

    def test_visibility_and_framework_are_not_conflated(self):
        self.assertTrue(self.results['B08-real-hidden']['details']['actualVisibilityHideShow'])
        for state in ['inactive','hidden','paused','detached']:
            d = self.results['B08-framework-'+state]['details']
            self.assertTrue(d['injectedNotOS'])
            self.assertEqual(d['resumingDidNotReviveRetiredReport'], state!='inactive')

    def test_four_artifacts_and_final_source_identity(self):
        a = json.loads((ROOT / FOLDER / 'artifacts.json').read_text())
        self.assertEqual(set(a['builds']), {'default','opt-in','lifecycle','held'})
        for name,b in a['builds'].items():
            self.assertEqual(b['fixtureSentinelsPresent'], name in ['lifecycle','held'])
            self.assertEqual(b['testEntrypointInSourceMap'], name in ['lifecycle','held'])
            self.assertEqual(b['heldReaderSentinelPresent'], name=='held')
        for path,h in {**a['sourceSha256'], **self.c['sourceSha256']}.items():
            self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(), h, path)
        for name,r in self.results.items():
            target = 'held' if name.startswith('B07-reading') else 'lifecycle'
            self.assertEqual(r['servedAssetSha256']['/main.dart.js'], a['builds'][target]['mainSha256'])

    def test_exact_runtime_delta_and_unchanged_frozen_contracts(self):
        trees=['apps','packages','native','fixtures','pubspec.lock']
        refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():
            changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed), self.c['allowedRuntimeChanges'])
        for path,h in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+path)
            self.assertEqual(hashlib.sha256(old).hexdigest(),h,path)
            self.assertEqual(at_slice(path),old,path)

    def test_status_and_original_acceptance_not_rewritten(self):
        path='docs/implementation/task-status.json'
        before=json.loads(git('show',self.c['base']+':'+path));after=json.loads(at_slice(path))
        self.assertEqual(after['counts'],before['counts'])
        self.assertEqual(after['fullTasksCompleted'],0)
        for b,a in zip(before['tasks'],after['tasks']):
            if b['id']!='I-037':self.assertEqual(b,a);continue
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k], b[k]+['evidence/signed-import-app-lifecycle/'])
                else:self.assertEqual(a[k],b[k],k)
        path='docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        self.assertTrue(at_slice(path).startswith(git('show',self.c['base']+':'+path)))
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['completedMatrixRows'],['B05','B06','B07','B08'])
        self.assertEqual(len(self.c['deferredMatrixRows']),8)

    def test_checks_and_no_consent_or_backend_stub_seam(self):
        self.assertIn('No issues found!', (ROOT/FOLDER/'analyzer.log').read_text())
        self.assertIn('0 changed', (ROOT/FOLDER/'format.log').read_text())
        fixture=at_slice('apps/studio_web/lib/import_fixture_composition.dart').decode()
        for prohibited in ['ImportUserActionPort','explicitPreviewConsent','localStorage','window']:
            self.assertNotIn(prohibited,fixture)
        main=at_slice('apps/studio_web/lib/main.dart').decode()
        self.assertIn('createRepository: createWebSignedSkillRepository',main)
        self.assertIn('importFixture = null',main)
        self.assertIn('_importLifetime.invalidateBeforePublication();',main)

if __name__=='__main__':unittest.main()
