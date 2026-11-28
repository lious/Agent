"""3.57 evidence and exact preservation checks; no older qualification reruns."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/signed-import-app-late-state/'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class AppLateStateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
        cls.results={x:json.loads((ROOT/FOLDER/(x+'.json')).read_text()) for x in cls.c['variants']}

    def test_twelve_new_combined_profiles(self):
        self.assertEqual(len(self.results),12)
        for name,r in self.results.items():
            self.assertEqual(r['caseId'],name)
            for k in ['passed','noAcknowledgmentAccepted','storageSnapshotUnchanged','noComponentWrites']:
                self.assertTrue(r[k],(name,k))
            self.assertFalse(r['nativeTraceDataLoss'])
            self.assertEqual(r['exceptions'],[])
            self.assertEqual(r['violations'],[])
            self.assertIn(r['sri'],r['csp'])
            for directive in ["'unsafe-eval'","'unsafe-inline'"]:
                self.assertNotIn(directive,r['csp'])
            self.assertEqual(r['chooserCount'],2 if name=='B10' else 1)

    def test_each_late_state_alternative_is_observed(self):
        self.assertEqual(len([x for x in self.results if x.startswith('B09-')]),8)
        self.assertEqual(len([x for x in self.results if x.startswith('B11-')]),3)
        for name,r in self.results.items():
            if name=='B10':continue
            d=r['details']
            self.assertTrue(d['terminalRetirement'])
            self.assertTrue(d['rebuildDidNotRevive'])
            self.assertTrue(d['actualOwnerAndRepository'])
            self.assertTrue(d['observedFact'])

    def test_forward_time_uses_real_ack_refusal_not_retirement(self):
        d=self.results['B10']['details']
        self.assertEqual(d['forwardValid'],1001)
        self.assertEqual(d['exclusiveSignerExpiry'],10000)
        for k in ['actualRepositoryRefused','freshSelectionRequired','freshFileSelectionObserved']:
            self.assertTrue(d[k])
        main=at_slice('apps/studio_web/lib/main.dart').decode()
        start=main.index('void _applyFixtureTransition(');end=main.index('void _injectFixtureLifecycle',start)
        apply=main[start:end]
        self.assertLess(apply.index('_importLifetime.invalidateBeforePublication();'),apply.index('_fixtureProfile ='))
        self.assertIn('change.nowSeconds! < oldTime',apply)
        self.assertNotIn('explicitPreviewConsent',apply)
        self.assertNotIn('_store',apply)

    def test_three_release_artifacts_exclude_fixture(self):
        a=json.loads((ROOT/FOLDER/'artifacts.json').read_text())
        self.assertEqual(set(a['builds']),{'default','opt-in','late-state'})
        for name,b in a['builds'].items():
            self.assertEqual(b['fixtureSentinelsPresent'],name=='late-state')
            self.assertEqual(b['testEntrypointInSourceMap'],name=='late-state')
            self.assertFalse(b['heldReaderSentinelPresent'])
        for mapping in [a['sourceSha256'],self.c['sourceSha256']]:
            for p,h in mapping.items():
                self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(),h,p)
        for r in self.results.values():
            self.assertEqual(r['servedAssetSha256']['/main.dart.js'],a['builds']['late-state']['mainSha256'])

    def test_exact_runtime_delta_and_frozen_files(self):
        trees=['apps','packages','native','fixtures','pubspec.lock']
        refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
        for p,h in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+p)
            self.assertEqual(hashlib.sha256(old).hexdigest(),h,p)
            self.assertEqual(at_slice(p),old,p)

    def test_status_counts_and_original_remaining_acceptance(self):
        path='docs/implementation/task-status.json'
        old=json.loads(git('show',self.c['base']+':'+path));new=json.loads(at_slice(path))
        self.assertEqual(len(new['tasks']),87)
        self.assertEqual(new['counts'],old['counts'])
        self.assertEqual(new['fullTasksCompleted'],0)
        for b,a in zip(old['tasks'],new['tasks']):
            if b['id']!='I-037':self.assertEqual(a,b);continue
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k],b[k]+['evidence/signed-import-app-late-state/'])
                else:self.assertEqual(a[k],b[k],k)
        path='docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        self.assertTrue(at_slice(path).startswith(git('show',self.c['base']+':'+path)))
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['completedMatrixRows'],['B09','B10','B11'])
        self.assertEqual(self.c['deferredMatrixRows'],['L01','L02','L03','N01','N02'])

    def test_static_checks_and_actual_factory(self):
        self.assertIn('No issues found!',(ROOT/FOLDER/'analyzer.log').read_text())
        self.assertIn('0 changed',(ROOT/FOLDER/'format.log').read_text())
        s=at_slice('apps/studio_web/lib/main.dart').decode()
        self.assertIn('createRepository: createWebSignedSkillRepository',s)
        self.assertIn('importFixture = null',s)
        fixture=at_slice('apps/studio_web/test/import_late_state_entrypoint.dart').decode()
        self.assertIn('transitions: List.unmodifiable([',fixture)
        f=at_slice('apps/studio_web/lib/import_fixture_composition.dart').decode()
        for p in ['ImportUserActionPort','explicitPreviewConsent','localStorage','window']:
            self.assertNotIn(p,f)

if __name__=='__main__':unittest.main()
