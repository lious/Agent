"""Official independent Web-runtime evidence and preservation checks, not old runtime reruns."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]
EVIDENCE='docs/implementation/evidence/web-signed-import-preview/'

def at_runtime(path):
    commits=subprocess.check_output(['git','log','--diff-filter=A','--format=%H','--',EVIDENCE+'contract.json'],cwd=ROOT,text=True).splitlines()
    return subprocess.check_output(['git','show',commits[-1]+':'+path],cwd=ROOT) if commits else (ROOT/path).read_bytes()

class WebSignedImportRuntimeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract=json.loads((ROOT/EVIDENCE/'contract.json').read_text())
        cls.results=json.loads((ROOT/EVIDENCE/'browser-results.json').read_text())

    def test_exact_vendor_both_hashes_and_retained_isc(self):
        lock=json.loads((ROOT/'packages/studio_assets/third_party/sodium_web/backend-lock.json').read_text())
        original=json.loads((ROOT/'docs/implementation/evidence/web-signed-import-plan-v1/backend-candidate.json').read_text())
        for key in ['sourceBytes','sourceSha256','sri','tag','appAssetPath','expectedCoreVersion']:
            self.assertEqual(lock[key],original[key])
        data=(ROOT/'packages/studio_assets/web'/lock['appAssetPath'].lstrip('/')).read_bytes()
        self.assertEqual(len(data),lock['sourceBytes'])
        self.assertEqual(hashlib.sha256(data).hexdigest(),lock['sourceSha256'])
        self.assertEqual('sha384-'+base64.b64encode(hashlib.sha384(data).digest()).decode(),lock['sri'])
        for name in lock['licenseFiles']:
            self.assertIn('Permission to use',(ROOT/'packages/studio_assets/third_party/sodium_web'/name).read_text())

    def test_ordered_real_browser_evidence_complete_and_no_fallback(self):
        self.assertTrue(self.results['ok'])
        modes=self.results['modes'];self.assertEqual(len(modes),self.contract['browserModes'])
        self.assertEqual([m['mode'] for m in modes[:2]],['crypto','aliasing'])
        self.assertEqual(sum(len(m['cases']) for m in modes),self.contract['browserAssertionCases'])
        self.assertEqual(next(m for m in modes if m['mode']=='crypto')['wycheproofSubcases'],210)
        self.assertEqual(next(m for m in modes if m['mode']=='aliasing')['wycheproofSubcases'],210)
        self.assertEqual(len(next(m for m in modes if m['mode']=='importer')['cases']),40)
        for mode in modes:
            self.assertTrue(mode['ok'],mode['mode'])
            self.assertTrue(mode['secureContext'])
            self.assertIn('HeadlessChrome/',mode['userAgent'])
            self.assertEqual(mode['unexpectedRequests'],[])
            self.assertEqual(mode['persistenceCalls'],[])
            self.assertFalse(mode['vendorTamperExecuted'])
            if mode['mode']=='fail-csp':self.assertTrue(mode['violations'])
            else:self.assertEqual(mode['violations'],[])
            self.assertNotIn("'unsafe-eval'",mode['csp'])
            self.assertNotIn("'unsafe-inline'",mode['csp'])
        for name in ['fail-deadline','fail-late']:
            self.assertGreaterEqual(next(m for m in modes if m['mode']==name)['elapsedMs'],10000)
        self.assertEqual(hashlib.sha256((ROOT/'packages/studio_assets/web/signed_import_bootstrap.js').read_bytes()).hexdigest(),self.results['bootstrapSha256'])

    def test_preserved_contract_sources_and_old_acceptance_suite(self):
        for path,digest in self.contract['unchangedFiles'].items():
            original=subprocess.check_output(['git','show',self.contract['base']+':'+path],cwd=ROOT)
            self.assertEqual(hashlib.sha256(original).hexdigest(),digest,path)
            self.assertEqual((ROOT/path).read_bytes(),original,path)

    def test_only_justified_status_appends_and_no_task_completion(self):
        before=json.loads(subprocess.check_output(['git','show',self.contract['base']+':docs/implementation/task-status.json'],cwd=ROOT))
        after=json.loads(at_runtime('docs/implementation/task-status.json'))
        self.assertEqual(after['counts'],self.contract['statusCounts'])
        self.assertEqual(after['fullTasksCompleted'],0)
        self.assertEqual(len(after['tasks']),87)
        for old,new in zip(before['tasks'],after['tasks']):
            if old['id']!='I-037':self.assertEqual(old,new);continue
            for key in old:
                if key in ['implementedScope','remainingScope']:self.assertTrue(new[key].startswith(old[key]))
                elif key=='evidence':self.assertEqual(new[key],old[key]+['evidence/web-signed-import-preview/'])
                else:self.assertEqual(old[key],new[key],key)

    def test_native_assertions_untouched_only_backend_import_seam(self):
        path='packages/studio_assets/test/skills/signed_import/backend_test.dart'
        before=subprocess.check_output(['git','show',self.contract['base']+':'+path],cwd=ROOT,text=True)
        self.assertEqual((ROOT/path).read_text(),before.replace('craft/signed_import/sodium_verifier.dart','craft/signed_import/backend.dart'))
        self.assertNotIn('signed_import',(ROOT/'packages/studio_assets/lib/studio_assets.dart').read_text())
        backend=(ROOT/'packages/studio_assets/lib/craft/signed_import/backend.dart').read_text()
        self.assertIn('dart.library.io',backend);self.assertIn('dart.library.js_interop',backend)
        self.assertIn('backend_unavailable.dart',backend)

    def test_public_fixtures_reproducible_and_browser_has_no_native_signer(self):
        subprocess.run(['python3','packages/studio_assets/test/skills/signed_import_web/make_fixtures.py','--check'],cwd=ROOT,check=True)
        source=(ROOT/'packages/studio_assets/test/skills/signed_import_web/browser_test.dart').read_text()
        for forbidden in ["import 'fixture.dart'",'dart:ffi','dart:io']:
            self.assertNotIn(forbidden,source)
        self.assertIn('createWebSignedSkillRepository',source)
        self.assertIn('9007199254740993',(ROOT/'packages/studio_assets/test/skills/signed_import_web/make_fixtures.py').read_text())

    def test_bootstrap_and_typed_adapter_fail_closed(self):
        source=(ROOT/'packages/studio_assets/web/signed_import_bootstrap.js').read_text()
        self.assertIn('script.integrity =',source)
        self.assertIn('performance.now() + 10000',source)
        self.assertIn("state !== 'loading'",source)
        self.assertIn('Object.freeze',source)
        self.assertIn("typeof value !== 'boolean'",source)
        adapter=(ROOT/'packages/studio_assets/lib/craft/signed_import/sodium_verifier_web.dart').read_text()
        self.assertIn('dart:js_interop',adapter)
        self.assertIn('Uint8List.fromList(bytes).toJS',adapter)
        self.assertNotIn('js_interop_unsafe',adapter)
        self.assertNotIn('dart:ffi',adapter)

if __name__=='__main__':unittest.main()
