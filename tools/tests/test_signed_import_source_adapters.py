"""Increment 3.51 evidence/preservation lint; no old runtime requalification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/signed-import-source-adapters/'
def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)
def slice_commit():
    commits=git('log','--diff-filter=A','--format=%H','--',FOLDER+'contract.json').decode().splitlines()
    return commits[-1] if commits else None
def at_slice(path):
    commit=slice_commit()
    return git('show',commit+':'+path) if commit else (ROOT/path).read_bytes()
def lock_records(raw):
    body=raw.decode().split('packages:\n',1)[1].split('\nsdks:',1)[0]
    starts=list(re.finditer(r'^  (\w+):\n',body,re.M))
    return {m[1]:body[m.start():starts[i+1].start() if i+1<len(starts) else len(body)].rstrip() for i,m in enumerate(starts)}
class SourceAdapterTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
    def test_independent_profiles_and_counts_not_ui_acceptance(self):
        native=json.loads((ROOT/FOLDER/'linux-results.json').read_text());web=json.loads((ROOT/FOLDER/'web-results.json').read_text())
        self.assertTrue(native['passed']);self.assertTrue(web['passed'])
        self.assertEqual(len(native['cases']),5);self.assertEqual(len(web['cases']),13)
        self.assertEqual(native['gtkVersion'],'3.24.49');self.assertIn('Chrome/156.',web['browser']['product'])
        self.assertEqual(web['exceptions'],[]);self.assertEqual(web['violations'],[])
        self.assertEqual(len(web['requests']),2)
        self.assertFalse(self.c['selectionPreviewConsentImplemented']);self.assertFalse(self.c['productionRootsProvisioned'])
        self.assertEqual(self.c['documentWrites'],0);self.assertFalse(self.c['executionAuthority'])
    def test_old_runtime_and_acceptance_files_unchanged(self):
        for path,digest in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+path)
            self.assertEqual(hashlib.sha256(old).hexdigest(),digest,path);self.assertEqual(at_slice(path),old,path)
        self.assertEqual((ROOT/'tools/tests/test_acceptance.py').read_bytes(),git('show',self.c['base']+':tools/tests/test_acceptance.py'))
        commit=slice_commit();refs=[self.c['base']]+([commit] if commit else []);trees=['apps','packages','native','pubspec.lock']
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if commit is None:changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
    def test_only_exact_planned_dependencies_added(self):
        old=lock_records(git('show',self.c['base']+':pubspec.lock'));new=lock_records(at_slice('pubspec.lock'))
        self.assertEqual(sorted(set(new)-set(old)),self.c['newLockedPackages'])
        for key,record in old.items():self.assertEqual(new[key],record,key)
        pins=json.loads((ROOT/'docs/implementation/evidence/signed-import-app-plan-v1/sources.json').read_text())
        for p in pins['candidatePackages']:
            self.assertIn('version: "'+p['version']+'"',new[p['name']]);self.assertIn(p['archiveSha256'],new[p['name']])
    def test_status_only_appends_honest_i037_evidence(self):
        old=json.loads(git('show',self.c['base']+':docs/implementation/task-status.json'));new=json.loads(at_slice('docs/implementation/task-status.json'))
        self.assertEqual(new['counts'],old['counts']);self.assertEqual(new['counts'],self.c['statusCounts']);self.assertEqual(new['fullTasksCompleted'],0)
        self.assertEqual(len(new['tasks']),87)
        for before,after in zip(old['tasks'],new['tasks']):
            if before['id']!='I-037':self.assertEqual(before,after);continue
            self.assertEqual(after['status'],'partial')
            for key in before:
                if key=='implementedScope':self.assertTrue(after[key].startswith(before[key]))
                elif key=='evidence':self.assertEqual(after[key],before[key]+['evidence/signed-import-source-adapters/'])
                else:self.assertEqual(after[key],before[key],key)
    def test_plan_gap_is_only_a_cited_ownership_append(self):
        path='docs/studio/spec/s8f-signed-import-app-v1.md';old=git('show',self.c['base']+':'+path).decode();new=at_slice(path).decode()
        a=new.index('### Increment 3.51 implementation-exposed ownership binding');b=new.index('## A4',a)
        self.assertEqual(new[:a]+new[b:],old)
        self.assertIn('HTMLInputElement has no abort/settled',new[a:b])
        adr=at_slice('docs/adr/0250-bounded-signed-import-source-adapters.md').decode();self.assertIn('t155u',adr);self.assertIn('before code',adr)
    def test_recorded_sources_and_tools_match_qualified_slice(self):
        for path,digest in json.loads((ROOT/FOLDER/'source-sha256.json').read_text()).items():
            self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(),digest,path)
    def test_no_shared_export_or_product_wiring(self):
        common=at_slice('packages/studio_assets/lib/craft/signed_import/source_capture.dart').decode()
        for text in ['skillSourceMaxBytes = 4194304','skillSourceChunkBytes = 65536','milliseconds: 30000','Stopwatch()','asUnmodifiableView','_outcome = null']:
            self.assertIn(text,common)
        self.assertNotIn('source_capture',at_slice('packages/studio_assets/lib/studio_assets.dart').decode())
        for path in ['apps/studio_demo/lib/main.dart','apps/studio_web/lib/main.dart']:
            self.assertNotIn('chooseWebSkillSource',at_slice(path).decode());self.assertNotIn('chooseLinuxSkillSource',at_slice(path).decode())
    def test_qualification_logs_and_explicit_browser_driver_limit(self):
        self.assertIn('+24: All tests passed!',(ROOT/FOLDER/'unit-tests.log').read_text())
        self.assertIn('All tests passed!',(ROOT/FOLDER/'linux-tests.log').read_text())
        probe=at_slice('tools/acceptance/skill_source/browser_probe.cjs').decode()
        self.assertIn('DOM.setFileInputFiles',probe);self.assertIn('Input.dispatchMouseEvent',probe);self.assertIn('actual Chrome GTK chooser Escape emits trusted cancel',probe)
        self.assertIn('empty CDP injection remains pending',probe)
if __name__=='__main__':unittest.main()
