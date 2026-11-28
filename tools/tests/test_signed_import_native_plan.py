"""3.61 evidence audit/plan checks ONLY; never re-executes historical runtimes."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
from unittest import mock
from tools.audit.signed_import_app_evidence import audit, BASE, GROUPS, git_bytes, inspect_group

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-native-plan/'
PLAN = 'docs/studio/spec/s8f-signed-import-app-native-v1.md'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def slice_commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None


def at_slice(path):
    ref = slice_commit()
    return git_bytes(ref, path) if ref else (ROOT / path).read_bytes()


class NativePlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = json.loads(at_slice(FOLDER + 'contract.json'))
        cls.a = json.loads(at_slice(FOLDER + 'audit.json'))
        cls.plan = at_slice(PLAN).decode()

    def test_reproducible_frozen_audit_without_new_runtime(self):
        self.assertEqual(audit(), self.a)
        self.assertTrue(self.a['auditChecksPassed'])
        self.assertEqual(self.a['newRuntimeExecutions'], 0)
        self.assertFalse(self.a['currentRuntimeRequalified'])
        self.assertFalse(self.a['l01Rerun'])
        self.assertFalse(self.a['frozenEvidenceConflictFound'])

    def test_source_provenance_mismatch_fails_closed(self):
        def tampered(ref, path):
            if path == 'apps/studio_web/lib/main.dart':
                return b'not the originally compiled source'
            return git_bytes(ref, path)
        with mock.patch('tools.audit.signed_import_app_evidence.git_bytes', side_effect=tampered):
            with self.assertRaisesRegex(ValueError, 'source provenance'):
                inspect_group(*GROUPS[0])

    def test_exact_historical_profiles_and_original_commits(self):
        expected = [
            {'B01', 'B02', 'B03', 'B04'},
            {'B05','B06-reload','B06-away-back','B06-dispose','B07-reading-navigation',
             'B07-reading-handler-only','B08-real-hidden','B08-framework-inactive',
             'B08-framework-hidden','B08-framework-paused','B08-framework-detached'},
            {'B09-' + x for x in ['profile','epoch','key-removal','installed','session','branch','owner','aba']} |
            {'B10','B11-backward','B11-confidence','B11-rollback'},
            {'L01-context','L01-widget-dispose'},
            {'L02-' + p + '-' + a for p in ['open','length','read'] for a in ['cancel','dispose','context']} |
            {'L03-null-close-context'},
        ]
        for group, (name, ref, count), cases in zip(self.a['groups'], GROUPS, expected):
            self.assertEqual(group['name'], name)
            self.assertEqual(group['qualificationCommit'], ref)
            self.assertEqual(group['recordedCaseCount'], count)
            self.assertEqual({c['caseId'] for c in group['cases']}, cases)
        self.assertEqual(self.a['historicalBrowserProfileCount'], 39)
        self.assertEqual(self.a['historicalLateProfileCount'], 12)
        self.assertEqual(self.a['historicalBuildRecordCount'], 16)

    def test_distinct_binaries_do_not_establish_combined_acceptance(self):
        self.assertEqual(len(self.a['lateFixtureBinarySha256']), 2)
        for record in [self.a, self.c]:
            self.assertFalse(record['allLateRuntimeGatesComplete'])
            self.assertFalse(record['fullA6AcceptanceComplete'])
            self.assertEqual(record['qualifiedNativeRows'], [])
        self.assertEqual(len(self.a['unchangedL01ObserverSha256']), 64)
        self.assertIn('C2 one-binary/C7', self.a['combinedConditionStatus'])
        self.assertIn('Do not relax C2', self.plan)
        self.assertIn('automatically rerun L01', self.plan)

    def test_adr_dependency_and_provenance_scope(self):
        self.assertEqual({int(Path(p).name[:4]) for p in self.a['adrSha256']}, set(range(248,260)))
        for p, sha in self.a['adrSha256'].items():
            self.assertEqual(hashlib.sha256(git_bytes(BASE,p)).hexdigest(),sha)
        for group in self.a['groups']:
            for p, sha in group['frozenFilesSha256'].items():
                self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(),sha)
        self.assertFalse(self.c['runtimeImplemented'])

    def test_seven_native_profiles_and_pending_gates(self):
        expected = ['N01-enter','N01-space','N01-semantics','N02-preview-navigation',
                    'N02-preview-dispose','N02-read-navigation','N02-read-dispose']
        self.assertEqual(self.c['plannedNativeCaseIds'], expected)
        for case in expected:
            self.assertIn('| ' + case + ' |', self.plan)
        self.assertEqual(self.c['pendingNativeGates'], ['NG'+str(x) for x in range(6)])
        for gate in self.c['pendingNativeGates']:
            self.assertIn('- ' + gate + ' ', self.plan)
        self.assertIn('All NG gates are PENDING in 3.61', self.plan)

    def test_trusted_composition_and_observation_bindings(self):
        for text in ['SkillImportHost.testImport', 'After its first frame',
                     'SodiumVerifier.loadTrusted', 'EMPTY installed/session/branch',
                     'nowSeconds=1000', 'clock', 'original capture.quiescent',
                     'synchronously', 'SemanticsAction.tap', 'xdotool',
                     'ORIGINAL capture future', '30000ms', '15-second',
                     'Directory.watch', 'create/write/restore/rename/delete',
                     'strace -ff -ttt -yy', 'not\ncurrently installed',
                     'Overflow/drop/observer errors', 'DB/WAL/journal/CAS/shelf',
                     'debug integration', 'default and ordinary opt-in Linux',
                     'No cross-App Web test', 'No new FoundationApp']:
            self.assertIn(text, self.plan)
        self.assertIn('pointer selection and needsReview', self.plan)
        self.assertIn('NOT an OS assistive-device', self.plan)

    def test_all_runtime_trees_license_and_original_tests_preserved(self):
        for path, oid in self.c['preservedGitObjects'].items():
            self.assertEqual(git('rev-parse',BASE+':'+path).decode().strip(),oid)
            if slice_commit():
                self.assertEqual(git('rev-parse',slice_commit()+':'+path).decode().strip(),oid)
            else:
                self.assertEqual(git('diff','--name-only',BASE,'--',path),b'')
                self.assertEqual(git('ls-files','--others','--exclude-standard','--',path),b'')
        p='packages/studio_assets/third_party/sodium_web/LICENSE.core'
        self.assertEqual(at_slice(p),git_bytes(BASE,p))
        self.assertEqual(at_slice('tools/tests/test_acceptance.py'),git_bytes(BASE,'tools/tests/test_acceptance.py'))

    def test_original_task_wording_counts_and_program_preserved(self):
        p='docs/implementation/task-status.json'
        before=json.loads(git_bytes(BASE,p));after=json.loads(at_slice(p))
        self.assertEqual(after['counts'],dict(complete=0,partial=62,planned=12,blocked=13))
        self.assertEqual(after['fullTasksCompleted'],0)
        self.assertEqual(len(after['tasks']),87)
        for b,a in zip(before['tasks'],after['tasks']):
            if b['id']!='I-037':
                self.assertEqual(a,b)
                continue
            for k in b:
                if k=='implementedScope':self.assertTrue(a[k].startswith(b[k]))
                elif k=='evidence':self.assertEqual(a[k],b[k]+['evidence/signed-import-app-native-plan/'])
                else:self.assertEqual(a[k],b[k],k)

    def test_append_only_parent_and_document_hashes(self):
        p='docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'
        self.assertTrue(at_slice(p).startswith(git_bytes(BASE,p)))
        for p,sha in self.c['documentSha256'].items():
            self.assertEqual(hashlib.sha256(at_slice(p)).hexdigest(),sha,p)
        self.assertIn('3.61 lands audit plus completed native fixture/observation bindings ONLY',self.plan)


if __name__ == '__main__':
    unittest.main()
