"""3.52 new fence evidence and historical preservation; no runtime requalification."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/import-composition-live-fence/'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def commit():
    refs=git('log','--diff-filter=A','--format=%H','--',FOLDER+'contract.json').decode().splitlines()
    return refs[-1] if refs else None
def at_slice(path):return git('show',commit()+':'+path) if commit() else (ROOT/path).read_bytes()
class LiveAppFenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
    def test_new_scope_and_results_do_not_claim_full_composition(self):
        self.assertEqual(self.c['newDartCases'],17)
        self.assertIn('+17: All tests passed!',(ROOT/FOLDER/'tests.log').read_text())
        self.assertIn('No issues found!',(ROOT/FOLDER/'analyzer.log').read_text())
        for flag in ['fullCompositionImplemented','combinedCspReadinessWidgetAccessibilityNoWriteQualified','productionRootsProvisioned','oldRuntimeSuitesRerun']:
            self.assertFalse(self.c[flag],flag)
    def test_source_hashes_and_exact_runtime_delta(self):
        for path,digest in self.c['sourceSha256'].items():self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(),digest,path)
        trees=['apps','packages','native','pubspec.lock'];refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
    def test_old_app_crypto_host_store_acceptance_and_dependencies_preserved(self):
        for path,digest in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+path);self.assertEqual(hashlib.sha256(old).hexdigest(),digest,path);self.assertEqual(at_slice(path),old,path)
        self.assertEqual((ROOT/'tools/tests/test_acceptance.py').read_bytes(),git('show',self.c['base']+':tools/tests/test_acceptance.py'))
    def test_status_only_appends_i037_implementation_scope(self):
        old=json.loads(git('show',self.c['base']+':docs/implementation/task-status.json'));new=json.loads(at_slice('docs/implementation/task-status.json'))
        self.assertEqual(new['counts'],old['counts']);self.assertEqual(new['fullTasksCompleted'],0);self.assertEqual(len(new['tasks']),87)
        for before,after in zip(old['tasks'],new['tasks']):
            if before['id']!='I-037':self.assertEqual(before,after);continue
            self.assertEqual(after['status'],'partial')
            for k in before:
                if k=='implementedScope':self.assertTrue(after[k].startswith(before[k]))
                elif k=='evidence':self.assertEqual(after[k],before[k]+['evidence/import-composition-live-fence/'])
                else:self.assertEqual(before[k],after[k],k)
    def test_plan_only_adds_concrete_gap_binding(self):
        path='docs/studio/spec/s8f-signed-import-app-v1.md';new=at_slice(path).decode();a=new.index('### Increment 3.52 implementation-exposed live-App fence');b=new.index('## A4',a)
        self.assertEqual(new[:a]+new[b:],git('show',self.c['base']+':'+path).decode())
        for term in ['ABA','MUST supply','scopeChanged','synchronous','after eventual close','separate coherent slice']:
            self.assertIn(term,new[a:b])
    def test_platforms_forward_only_the_new_guard_seam(self):
        for path,private_marker in [('apps/studio_demo/lib/skill_source_linux.dart','Future<SkillSourceReader?> _pick()'),('apps/studio_web/lib/skill_source_web.dart','SkillSourceSelection _pick()')]:
            new=at_slice(path).decode();old=git('show',self.c['base']+':'+path).decode()
            self.assertIn('currentAppStillValid: currentAppStillValid',new);self.assertEqual(new.split(private_marker)[1],old.split(private_marker)[1])
        helper=at_slice('packages/studio_assets/lib/craft/signed_import/source_capture.dart').decode()
        self.assertIn('if (!current) return false',helper);self.assertIn("SkillSourceException('scopeChanged')",helper)
if __name__=='__main__':unittest.main()
