"""3.59 L01 evidence/preservation and bounded harness-gate unit checks only."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from tools.acceptance.late_host_gate import VendorResponseGate
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/signed-import-app-pending-factory/'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class HostGateTests(unittest.TestCase):
    def run_gate(self,signal=None,seconds=0.01):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)
            if signal is not None:(path/'release.json').write_text(json.dumps(signal))
            return VendorResponseGate(path,'test',seconds).wait_for_release()
    def test_accepts_only_matching_retirement(self):
        r=self.run_gate({'caseId':'test','retired':True})
        self.assertTrue(r['released']);self.assertFalse(r['watchdogFired'])
    def test_bad_signal_cannot_pass(self):
        r=self.run_gate({'caseId':'test','retired':False})
        self.assertFalse(r['released']);self.assertTrue(r['invalidSignal'])
    def test_missing_signal_watchdog_is_failure(self):
        r=self.run_gate()
        self.assertFalse(r['released']);self.assertTrue(r['watchdogFired'])
    def test_late_signal_cannot_revive_gate(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder);(path/'release.json').write_text(json.dumps({'caseId':'test','retired':True}))
            with patch('tools.acceptance.late_host_gate.time.monotonic',side_effect=[0.0,8.0]):
                r=VendorResponseGate(path,'test').wait_for_release()
            self.assertFalse(r['released']);self.assertTrue(r['watchdogFired'])

class PendingFactoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
        cls.results={x:json.loads((ROOT/FOLDER/(x+'.json')).read_text()) for x in cls.c['caseIds']}
    def test_two_new_real_pending_profiles(self):
        self.assertEqual(set(self.results),{'L01-widget-dispose','L01-context'})
        for r in self.results.values():
            for k in ['passed','noAcknowledgmentAccepted','storageSnapshotUnchanged','noComponentWrites']:self.assertTrue(r[k],k)
            self.assertEqual(r['chooserCount'],0)
            self.assertEqual(r['exceptions'],[]);self.assertEqual(r['violations'],[])
            self.assertIn(r['sri'],r['csp'])
            lock=json.loads(at_slice('packages/studio_assets/third_party/sodium_web/backend-lock.json'))
            self.assertEqual(r['servedAssetSha256'][lock['appAssetPath']],lock['sourceSha256'])
            self.assertEqual(r['sri'],lock['sri'])
            self.assertIn('Tab/Enter',r['inputMethod'])
            self.assertTrue(any(t['event']=='key' and t['key']=='Enter' and t['isTrusted'] for t in r['traces']))
            self.assertNotIn("'unsafe-inline'",r['csp']);self.assertNotIn("'unsafe-eval'",r['csp'])
            self.assertTrue(r['vendorBodyGate']['released'])
            self.assertFalse(r['vendorBodyGate']['watchdogFired'])
            self.assertLess(r['vendorBodyGate']['elapsedSeconds'],8)
    def test_real_success_is_observed_after_retirement(self):
        for name,r in self.results.items():
            d=r['details']
            self.assertEqual([x['phase'] for x in r['observations']],['pending','retired','completed','settled-no-revival'])
            self.assertEqual([x['repository']['completed'] for x in r['observations']],[0,0,1,1])
            times=[x['browserMonotonic'] for x in r['observations']]
            self.assertEqual(times,sorted(times))
            for k in ['realFactoryPendingBeforeRetirement','verifiedVendorHeld','actualFactoryCompletedAfterRetirement','ordinaryRebuildDidNotRevive']:self.assertTrue(d[k])
            self.assertEqual(d['repositoryObserver'],dict(phase='completed',started=1,completed=1,failed=0,observerFaults=0))
            self.assertEqual(d['actualWidgetDisposed'],name=='L01-widget-dispose')
            self.assertEqual(d['contextRetired'],name=='L01-context')
    def test_three_artifacts_and_source_identity(self):
        a=json.loads((ROOT/FOLDER/'artifacts.json').read_text())
        self.assertEqual(set(a['builds']),{'default','opt-in','late-phase'})
        for name,b in a['builds'].items():
            self.assertEqual(b['fixtureSentinelsPresent'],name=='late-phase')
            self.assertEqual(b['testEntrypointInSourceMap'],name=='late-phase')
        for mapping in [a['sourceSha256'],self.c['sourceSha256']]:
            for p,h in mapping.items():self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(),h,p)
        for r in self.results.values():self.assertEqual(r['servedAssetSha256']['/main.dart.js'],a['builds']['late-phase']['mainSha256'])
    def test_exact_runtime_delta_and_unchanged_core_contracts(self):
        trees=['apps','packages','native','fixtures','pubspec.lock'];refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
        for p,h in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+p)
            self.assertEqual(hashlib.sha256(old).hexdigest(),h,p);self.assertEqual(at_slice(p),old,p)
    def test_observer_is_passive_actual_factory_only(self):
        main=at_slice('apps/studio_web/lib/main.dart').decode()
        start=main.index('Future<FilmSkillRepository> _observeRealFixtureRepository(');end=main.index('BrowserProjectStore?',start)
        observer=main[start:end]
        self.assertRegex(observer,r'await createWebSignedSkillRepository\(\s*currentApp,\s*actions,\s*\)')
        self.assertEqual(observer.count('createWebSignedSkillRepository('),1)
        self.assertIn('return repository;',observer);self.assertIn('rethrow;',observer)
        self.assertNotIn('FilmSkillRepository(',observer)
        self.assertIn('importFixture = null',main)
        config=at_slice('apps/studio_web/lib/import_fixture_composition.dart').decode()
        self.assertIn('this.observeRepositoryForTest = false',config)
        self.assertNotIn('ImportUserActionPort',config)
        self.assertIn('No issues found!',(ROOT/FOLDER/'analyzer.log').read_text())
        self.assertIn('0 changed',(ROOT/FOLDER/'format.log').read_text())
    def test_partial_status_original_acceptance_preserved(self):
        p='docs/implementation/task-status.json';old=json.loads(git('show',self.c['base']+':'+p));new=json.loads(at_slice(p))
        self.assertEqual(new['counts'],old['counts']);self.assertEqual(new['fullTasksCompleted'],0)
        self.assertEqual(len(new['tasks']),87)
        for b,a in zip(old['tasks'],new['tasks']):
            if b['id']!='I-037':self.assertEqual(a,b);continue
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k],b[k]+['evidence/signed-import-app-pending-factory/'])
                else:self.assertEqual(a[k],b[k],k)
    def test_no_full_gate_or_a6_native_claim(self):
        self.assertEqual(self.c['qualifiedMatrixRows'],['L01'])
        self.assertEqual(self.c['deferredMatrixRows'],['L02','L03','N01','N02'])
        self.assertFalse(self.c['allLateRuntimeGatesComplete'])
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['pendingCaseCount'],10)

if __name__=='__main__':unittest.main()
