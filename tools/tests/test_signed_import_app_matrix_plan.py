"""3.54 planning/preservation only; no runtime qualification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-matrix-plan/'
PLAN = 'docs/studio/spec/s8f-signed-import-app-acceptance-v1.md'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def slice_commit():
    refs = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return refs[-1] if refs else None

def content(path):
    ref = slice_commit()
    return git('show', ref + ':' + path) if ref else (ROOT / path).read_bytes()

class AppMatrixPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = json.loads((ROOT / FOLDER / 'contract.json').read_text())
        cls.plan = content(PLAN).decode()

    def test_plan_only_not_new_acceptance(self):
        self.assertFalse(self.c['runtimeImplemented'])
        self.assertFalse(self.c['fullA6AcceptanceComplete'])
        self.assertEqual(self.c['newRuntimeCases'], 0)
        self.assertFalse(self.c['productionRootsProvisioned'])
        self.assertEqual(self.c['recommendedNextIncrement'], '3.55')

    def test_no_runtime_or_license_changes(self):
        refs = [self.c['base']] + ([slice_commit()] if slice_commit() else [])
        self.assertEqual(git('diff', '--name-only', *refs, '--', 'apps', 'packages', 'native', 'fixtures', 'pubspec.lock'), b'')
        path = 'packages/studio_assets/third_party/sodium_web/LICENSE.core'
        self.assertEqual(content(path), git('show', self.c['base'] + ':' + path))
        self.assertEqual(hashlib.sha256(content(path)).hexdigest(), self.c['licenseCoreSha256'])

    def test_existing_plan_only_gains_supplement_binding(self):
        path = 'docs/studio/spec/s8f-signed-import-app-v1.md'
        new = content(path).decode()
        a = new.index('### Increment 3.54 — actual-App acceptance fixture binding')
        b = new.index('## A7', a)
        self.assertEqual((new[:a] + new[b:]).encode(), git('show', self.c['base'] + ':' + path))

    def test_task_counts_original_acceptance_and_every_other_row_unchanged(self):
        path = 'docs/implementation/task-status.json'
        old = json.loads(git('show', self.c['base'] + ':' + path))
        new = json.loads(content(path))
        self.assertEqual(new['counts'], old['counts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        for before, after in zip(old['tasks'], new['tasks']):
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
                continue
            self.assertEqual(after['status'], 'partial')
            for key in before:
                if key == 'implementedScope':
                    self.assertTrue(after[key].startswith(before[key]))
                elif key == 'evidence':
                    self.assertEqual(after[key], before[key] + ['evidence/signed-import-app-matrix-plan/'])
                else:
                    self.assertEqual(before[key], after[key], key)

    def test_test_artifact_isolation_and_real_owner_are_bound(self):
        for phrase in ['named test constructor', 'ACTUAL', 'createWebSignedSkillRepository',
                       'BEFORE publishing', 'No private callback invocation',
                       'No replacement backend/verifier/repository factory',
                       'Production `lib/main.dart` remains', 'roots/grants empty',
                       'record baseline startup requests separately']:
            self.assertIn(phrase.lower(), self.plan.lower())

    def test_remaining_matrix_is_explicit_not_marked_passed(self):
        ids = re.findall(r'^\| ([BLN]\d{2}) \|', self.plan, flags=re.MULTILINE)
        self.assertEqual(ids, self.c['plannedMatrixRows'])
        self.assertEqual(len(ids), 16)
        for phrase in ['synthetic dispatch', 'BFCache', 'one outstanding source',
                       'no gesture reuse', 'no clock override', 'old-realm destruction',
                       'No row is marked passed', 'standard button']:
            self.assertIn(phrase.lower(), self.plan.lower())

    def test_document_digests_and_unchanged_acceptance_test(self):
        for path, digest in self.c['documentSha256'].items():
            self.assertEqual(hashlib.sha256(content(path)).hexdigest(), digest, path)
        path = 'tools/tests/test_acceptance.py'
        self.assertEqual(content(path), git('show', self.c['base'] + ':' + path))

if __name__ == '__main__':
    unittest.main()
