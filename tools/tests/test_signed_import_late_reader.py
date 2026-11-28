"""3.60 new controlled-reader evidence/preservation, no old suite execution."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/signed-import-app-late-reader/'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class LateReaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
        cls.results={x:json.loads((ROOT/FOLDER/(x+'.json')).read_text()) for x in cls.c['caseIds']}
    def test_ten_new_actual_app_profiles(self):
        expected={'L02-'+p+'-'+a for p in ['open','length','read'] for a in ['cancel','dispose','context']}|{'L03-null-close-context'}
        self.assertEqual(set(self.results),expected)
        for r in self.results.values():
            for k in ['passed','noAcknowledgmentAccepted','storageSnapshotUnchanged','noComponentWrites']:self.assertTrue(r[k])
            self.assertEqual(r['chooserCount'],0)
            self.assertEqual(r['exceptions'],[]);self.assertEqual(r['violations'],[])
            self.assertFalse(r['nativeTraceDataLoss'])
            self.assertIn(r['sri'],r['csp']);self.assertNotIn("'unsafe-inline'",r['csp']);self.assertNotIn("'unsafe-eval'",r['csp'])
            lock=json.loads(at_slice('packages/studio_assets/third_party/sodium_web/backend-lock.json'))
            self.assertEqual(r['servedAssetSha256'][lock['appAssetPath']],lock['sourceSha256'])
            self.assertTrue(any(t['event']=='key' and t['isTrusted'] for t in r['traces']))
    def test_resource_quiescence_and_natural_null(self):
        for name,r in self.results.items():
            d=r['details'];s=d['reader'];c=s['counts']
            self.assertTrue(d['controlledNotFile']);self.assertTrue(d['naturalNullOutcome']);self.assertTrue(d['noReplacementCapacity'])
            for k in ['selections','openStarted','openCompleted','lengthStarted','lengthCompleted','closeStarted','closeCompleted','outcomeNull','quiescent','manualReleases']:self.assertEqual(c[k],1,(name,k))
            self.assertEqual(c.get('outcomeBytes',0),0);self.assertEqual(c.get('outcomeErrors',0),0)
            self.assertEqual(c.get('disposeHooks',0),1 if d['action']=='dispose' else 0)
            self.assertFalse(s['busy']);self.assertFalse(s['watchdogFired']);self.assertEqual(s['observerFaults'],0);self.assertLess(s['elapsedSeconds'],15)
            self.assertTrue(r['observations'][0]['reader']['held'])
        r=self.results['L03-null-close-context'];s=r['details']['reader'];events=s['events']
        self.assertEqual(s['counts']['eof'],1)
        self.assertLess(events.index('outcomeNull'),events.index('closeCompleted'))
        self.assertLess(events.index('closeCompleted'),events.index('quiescent'))
        early=next(x['reader'] for x in r['observations'] if x['phase']=='early-null-close-pending')
        self.assertEqual(early['outcome'],'null');self.assertTrue(early['busy']);self.assertEqual(early['counts'].get('closeCompleted',0),0)
    def test_three_artifacts_and_frozen_input_identity(self):
        a=json.loads((ROOT/FOLDER/'artifacts.json').read_text())
        self.assertEqual(set(a['builds']),{'default','opt-in','late-phase'})
        for name,b in a['builds'].items():
            self.assertEqual(b['fixtureSentinelsPresent'],name=='late-phase')
            self.assertEqual(b['testEntrypointInSourceMap'],name=='late-phase')
        for mapping in [a['sourceSha256'],self.c['sourceSha256']]:
            for p,h in mapping.items():self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(),h,p)
        for r in self.results.values():self.assertEqual(r['servedAssetSha256']['/main.dart.js'],a['builds']['late-phase']['mainSha256'])
    def test_exact_delta_preserves_qualified_runtime_and_license(self):
        trees=['apps','packages','native','fixtures','pubspec.lock'];refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
        for p,h in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+p);self.assertEqual(hashlib.sha256(old).hexdigest(),h,p);self.assertEqual(at_slice(p),old,p)
        p='apps/studio_web/lib/main.dart';old=git('show',self.c['base']+':'+p).decode();new=at_slice(p).decode()
        def observer(s):return s[s.index('  void _recordFixtureRepository('):s.index('  BrowserProjectStore?')]
        self.assertEqual(observer(old),observer(new))
    def test_original_acceptance_and_task_counts_unchanged(self):
        p='docs/implementation/task-status.json';before=json.loads(git('show',self.c['base']+':'+p));after=json.loads(at_slice(p))
        self.assertEqual(after['counts'],before['counts']);self.assertEqual(after['fullTasksCompleted'],0);self.assertEqual(len(after['tasks']),87)
        for b,a in zip(before['tasks'],after['tasks']):
            if b['id']!='I-037':self.assertEqual(a,b);continue
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k],b[k]+['evidence/signed-import-app-late-reader/'])
                else:self.assertEqual(a[k],b[k],k)
        p='docs/studio/spec/s8f-signed-import-app-late-v1.md';self.assertTrue(at_slice(p).startswith(git('show',self.c['base']+':'+p)))
    def test_gate_witness_not_factory_or_result_override(self):
        s=at_slice('apps/studio_web/test/import_late_reader.dart').decode()
        for marker in ['currentAppStillValid: guard','selected();','return result;','watchdogFired','observerFaults']:self.assertIn(marker,s)
        self.assertNotIn('SkillReadToken',s);self.assertNotIn('FilmSkillRepository',s);self.assertNotIn('explicitPreviewConsent',s)
        app=at_slice('packages/studio_assets/lib/craft/signed_import/app_session.dart').decode()
        choose=app[app.index('Future<void> choose('):app.index('void acknowledge()')]
        self.assertLess(choose.index('await capture.quiescent'),choose.index('SkillReadToken.capture(bytes)'))
        self.assertIn('No issues found!',(ROOT/FOLDER/'analyzer.log').read_text());self.assertIn('0 changed',(ROOT/FOLDER/'format.log').read_text())
        self.assertIn('+6: All tests passed!',(ROOT/FOLDER/'reader-unit-tests.log').read_text())
    def test_scope_excludes_l01_requalification_and_full_a6(self):
        self.assertEqual(self.c['qualifiedMatrixRows'],['L02','L03'])
        self.assertEqual(self.c['deferredNativeRows'],['N01','N02'])
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['l01DependencyCommit'],'e499a223995bf067edbf506bb8e45d681a5b8ad6')
        self.assertFalse(any(x.startswith('L01') for x in self.results))

if __name__=='__main__':unittest.main()
