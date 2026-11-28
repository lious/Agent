"""3.58 planning/source preflight ONLY, never runtime or browser qualification."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT=Path(__file__).resolve().parents[2]
FOLDER='docs/implementation/evidence/signed-import-app-late-plan/'
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def at_slice(path):
    return git('show', commit() + ':' + path) if commit() else (ROOT / path).read_bytes()

class AppLatePlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c=json.loads((ROOT/FOLDER/'contract.json').read_text())

    def source(self,path):return at_slice(path).decode()

    def test_no_runtime_changes_and_frozen_license_crypto_host_store(self):
        trees=['apps','packages','native','fixtures','pubspec.lock']
        refs=[self.c['base']]+([commit()] if commit() else [])
        changed=set(git('diff','--name-only',*refs,'--',*trees).decode().splitlines())
        if not commit():changed.update(git('ls-files','--others','--exclude-standard','--',*trees).decode().splitlines())
        self.assertEqual(sorted(changed),[])
        self.assertEqual(self.c['allowedRuntimeChanges'],[])
        for p,h in self.c['unchangedFiles'].items():
            old=git('show',self.c['base']+':'+p)
            self.assertEqual(hashlib.sha256(old).hexdigest(),h,p)
            self.assertEqual(at_slice(p),old,p)

    def test_g0_actual_factory_and_bridge_keep_live_callback(self):
        s=self.source('packages/studio_assets/lib/studio_signed_skill_import_web.dart')
        self.assertLess(s.index('await SodiumVerifier.initialize()'),s.index('return FilmSkillRepository(backend, currentApp, userActions)'))
        s=self.source('packages/studio_assets/lib/craft/signed_import/sodium_verifier_web.dart')
        self.assertLess(s.index('await bridge.initialize().toDart'),s.index('result._check();'))
        bootstrap=self.source('packages/studio_assets/web/signed_import_bootstrap.js')
        self.assertIn('deadline = performance.now() + 10000;',bootstrap)
        self.assertIn("addEventListener('pagehide', fail, {once: true});",bootstrap)
        lock=json.loads(self.source('packages/studio_assets/third_party/sodium_web/backend-lock.json'))
        self.assertIn(lock['appAssetPath'],bootstrap)
        self.assertIn(lock['sri'],bootstrap)

    def test_g0_real_initialization_fenced_before_ready(self):
        s=self.source('packages/studio_assets/lib/craft/signed_import/app_session.dart')
        start=s.index('Future<void> initialize(');end=s.index('bool get canChoose',start);s=s[start:end]
        self.assertLess(s.index('await create(currentApp, _actions)'),s.index('generation != _generation || !fence()'))
        self.assertLess(s.index('generation != _generation || !fence()'),s.index('_repository = repository;'))
        self.assertLess(s.index('_repository = repository;'),s.index("state = 'ready';"))
        panel=self.source('apps/studio_web/lib/skill_import_panel.dart')
        self.assertIn('_session.initialize(widget.createRepository)',panel)
        self.assertIn('_session.dispose();',panel)

    def test_g0_selected_deadline_lazy_open_read_close_success_order(self):
        s=self.source('packages/studio_assets/lib/craft/signed_import/source_capture.dart')
        self.assertIn('skillSourceDeadline = Duration(milliseconds: 30000)',s)
        s=s[s.index('Future<void> _capture('):]
        order=['reader = await selection.selected','watch = Stopwatch()..start()','final expected = await reader.length()','final chunk = await reader.read(','await reader?.close()','settled.complete()','result.complete(bytes)']
        positions=[s.index(x) for x in order]
        self.assertEqual(positions,sorted(positions))
        native=self.source('apps/studio_demo/lib/skill_source_linux.dart')
        self.assertIn('Future<int> length() async => (await _open()).length()',native)
        self.assertIn('_opening ??=',native)

    def test_g0_nullable_cancel_is_early_not_successful_bytes(self):
        s=self.source('packages/studio_assets/lib/craft/signed_import/source_capture.dart')
        cancel=s[s.index('void cancel()'):s.index('void dispose()')]
        self.assertIn('result.complete(null)',cancel)
        self.assertNotIn('settled.complete',cancel)
        self.assertNotIn('_busy = false',cancel)
        app=self.source('packages/studio_assets/lib/craft/signed_import/app_session.dart')
        choose=app[app.index('Future<void> choose('):app.index('void acknowledge()')]
        order=['final bytes = await select()','await capture.quiescent','generation != _generation || !fence()','if (bytes == null)','SkillReadToken.capture(bytes)']
        positions=[choose.index(x) for x in order]
        self.assertEqual(positions,sorted(positions))

    def test_plan_has_twelve_cases_and_all_runtime_gates_pending(self):
        plan=self.source('docs/studio/spec/s8f-signed-import-app-late-v1.md')
        self.assertEqual(len(self.c['caseIds']),12)
        self.assertEqual(len(set(self.c['caseIds'])),12)
        for case in self.c['caseIds']:self.assertIn('| '+case+' |',plan)
        self.assertEqual(self.c['qualifiedMatrixRows'],[])
        self.assertEqual(self.c['sourcePreflightGates'],['G0'])
        self.assertEqual(self.c['pendingRuntimeGates'],['G1','G2','G3','G4','G5'])
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        for marker in ['8000 ms','10000 ms','15000 ms','30000 ms','No production code imports a /test/ library','G1–G5 are NOT implemented','Successful','nullable']:
            self.assertIn(marker,plan)
        self.assertIn('ONE late-phase fixture binary',plan)
        self.assertIn('Arm open/length/read/close',plan)
        self.assertIn('default, ordinary opt-in and one isolated fixture target',plan)

    def test_original_acceptance_app_plan_and_task_counts_preserved(self):
        path='docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        self.assertTrue(at_slice(path).startswith(git('show',self.c['base']+':'+path)))
        path='docs/implementation/task-status.json'
        before=json.loads(git('show',self.c['base']+':'+path));after=json.loads(at_slice(path))
        self.assertEqual(after['counts'],before['counts'])
        self.assertEqual(after['fullTasksCompleted'],0)
        self.assertEqual(len(after['tasks']),87)
        for b,a in zip(before['tasks'],after['tasks']):
            if b['id']!='I-037':self.assertEqual(a,b);continue
            self.assertEqual(a['status'],'partial')
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k],b[k]+['evidence/signed-import-app-late-plan/'])
                else:self.assertEqual(a[k],b[k],k)

    def test_plan_does_not_claim_old_rows_or_native_or_full_a6(self):
        self.assertEqual(self.c['plannedMatrixRows'],['L01','L02','L03'])
        self.assertEqual(self.c['deferredNativeRows'],['N01','N02'])
        plan=self.source('docs/studio/spec/s8f-signed-import-app-late-v1.md')
        self.assertIn('not a new runtime timeout',plan)
        self.assertIn('NOT claimed as a dynamic browser permutation',plan)
        self.assertIn('source-contract preflight',plan)
        adr=self.source('docs/adr/0257-app-late-phase-acceptance-gates.md')
        self.assertIn('Status: accepted planning/preflight only',adr)
        self.assertIn('G1–G5',adr)

if __name__=='__main__':unittest.main()
