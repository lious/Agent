"""New App composition evidence/preservation checks, not old runtime qualification."""
import hashlib,json,subprocess,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];FOLDER='docs/implementation/evidence/signed-import-app-composition/'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def commit():
    refs=git('log','--diff-filter=A','--format=%H','--',FOLDER+'contract.json').decode().splitlines();return refs[-1] if refs else None
def at_slice(path):return git('show',commit()+':'+path) if commit() else (ROOT/path).read_bytes()
class AppCompositionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())
    def test_recorded_owner_widgets_and_default_native_flow(self):
        self.assertIn('+18: All tests passed!',(ROOT/FOLDER/'widgets.log').read_text())
        native=json.loads((ROOT/FOLDER/'linux.json').read_text());self.assertTrue(native['passed']);self.assertTrue(native['projectUnchanged']);self.assertTrue(native['databaseCasShelfFilesUnchanged']);self.assertEqual(native['excludedTransientFiles'],['*-shm']);self.assertTrue(native['ackDisabled']);self.assertEqual(native['trustState'],'needsReview');self.assertEqual(native['namespace'],{'appId':'studio_demo','tenantId':'local','workspaceId':'default'})
    def test_four_actual_web_app_profiles_not_old_host_results(self):
        for mode in ['normal','missing-backend','csp-backend-block','sri-backend-tamper']:
            r=json.loads((ROOT/FOLDER/('web-'+mode+'.json')).read_text());self.assertTrue(r['passed']);self.assertEqual(r['exceptions'],[])
            self.assertIn('WebStudioApp',r['actualApp']);self.assertIn('main.dart.js',' '.join(r['requests']))
            for phrase in ["default-src 'none'","base-uri 'none'","object-src 'none'","connect-src 'self'","'wasm-unsafe-eval'",r['sri']]:self.assertIn(phrase,r['csp'])
            for forbidden in ["'unsafe-inline'","'unsafe-eval'",'blob:','data:']:self.assertNotIn(forbidden,r['csp'])
            if mode=='normal':
                self.assertEqual(r['chooserCount'],1);self.assertTrue(r['noImportIdbWrites']);self.assertTrue(r['idbAndLocalSessionSnapshotUnchanged']);self.assertEqual(r['violations'],[])
            else:self.assertEqual(r['chooseDisabled'],'true');self.assertEqual(r['chooserCount'],0)
    def test_full_program_and_full_matrix_are_not_marked_done(self):
        self.assertTrue(self.c['selectionPreviewConsentImplemented']);self.assertFalse(self.c['defaultOptIn']);self.assertFalse(self.c['defaultClockConfident']);self.assertFalse(self.c['productionRootsProvisioned']);self.assertFalse(self.c['fullA6AcceptanceComplete']);self.assertFalse(self.c['oldRuntimeQualificationsRerun']);self.assertEqual(self.c['defaultPublisherRoots'],[])
        old=json.loads(git('show',self.c['base']+':docs/implementation/task-status.json'));new=json.loads(at_slice('docs/implementation/task-status.json'));self.assertEqual(new['counts'],old['counts']);self.assertEqual(new['fullTasksCompleted'],0);self.assertEqual(len(new['tasks']),87)
        for before,after in zip(old['tasks'],new['tasks']):
            if before['id']!='I-037':self.assertEqual(before,after);continue
            self.assertEqual(after['status'],'partial')
            for k in before:
                if k=='implementedScope':self.assertTrue(after[k].startswith(before[k]))
                elif k=='evidence':self.assertEqual(after[k],before[k]+['evidence/signed-import-app-composition/'])
                else:self.assertEqual(after[k],before[k],k)
    def test_exact_source_delta_and_hashes(self):
        for path,digest in self.c['sourceSha256'].items():self.assertEqual(hashlib.sha256(at_slice(path)).hexdigest(),digest,path)
        trees=['apps','packages','native','pubspec.lock'];refs=[self.c['base']]+([commit()] if commit() else []);changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),self.c['allowedRuntimeChanges'])
    def test_previous_backends_host_store_schema_lock_and_acceptance_untouched(self):
        for path,digest in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+path);self.assertEqual(hashlib.sha256(old).hexdigest(),digest,path);self.assertEqual(at_slice(path),old,path)
        self.assertEqual((ROOT/'tools/tests/test_acceptance.py').read_bytes(),git('show',self.c['base']+':tools/tests/test_acceptance.py'))
    def test_plan_additions_and_trusted_existing_app_wiring(self):
        path='docs/studio/spec/s8f-signed-import-app-v1.md';new=at_slice(path).decode();a=new.index('### Increment 3.53 composition phase observation');b=new.index('## A4',a);self.assertEqual(new[:a]+new[b:],git('show',self.c['base']+':'+path).decode())
        host=at_slice('apps/studio_demo/lib/skill_import_host.dart').decode();self.assertIn('addPostFrameCallback',host);self.assertIn('if (_projectMounted)',host);self.assertIn('ownerIdentity: widget.workspace',host)
        for main in ['apps/studio_demo/lib/main.dart','apps/studio_web/lib/main.dart']:self.assertIn("bool.fromEnvironment('STUDIO_SIGNED_IMPORT_PREVIEW')",at_slice(main).decode())
        for panel in ['apps/studio_demo/lib/skill_import_panel.dart','apps/studio_web/lib/skill_import_panel.dart']:
            s=at_slice(panel).decode();self.assertIn('chars.take(256)',s);self.assertIn('.take(32)',s);self.assertIn("Text('Acknowledge preview only')",s);self.assertIn('_session.fence',s);self.assertIn('_session.reading',s);self.assertNotIn('SelectableText(',s);self.assertNotIn('Markdown(',s)
        session=at_slice('packages/studio_assets/lib/craft/signed_import/app_session.dart').decode();self.assertEqual(session.count('explicitPreviewConsent('),1);self.assertIn('identical(now.profile, _initial.profile)',session);self.assertIn('identical(now.policy, _initial.policy)',session);self.assertNotIn("import 'dart:io'",session)
if __name__=='__main__':unittest.main()
