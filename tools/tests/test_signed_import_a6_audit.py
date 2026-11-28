"""3.66 official P5/A6 audit checks ONLY; never re-executes historical runtimes."""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EV = ROOT / 'docs/implementation/evidence/signed-import-app-a6-audit'
COMBINED = ROOT / 'docs/implementation/evidence/signed-import-app-combined'
L01 = 'afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29'
L023 = '935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb'


class FullA6AuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EV / 'contract.json').read_text())
        cls.audit = json.loads((EV / 'audit.json').read_text())
        cls.combined = json.loads((COMBINED / 'contract.json').read_text())
        cls.plan365 = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-combined-plan/contract.json').read_text()
        )
        cls.native = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-native-profiles/contract.json').read_text()
        )
        cls.acceptance = (ROOT / 'docs/studio/spec/s8f-signed-import-app-acceptance-v1.md').read_text()
        cls.late = (ROOT / 'docs/studio/spec/s8f-signed-import-app-late-v1.md').read_text()
        cls.adr = (ROOT / 'docs/adr/0265-app-full-a6-audit.md').read_text()

    def test_full_a6_is_set_only_after_this_audit(self):
        self.assertEqual(self.contract['increment'], '3.66')
        self.assertEqual(self.contract['base'], '0d1c66a8dacafc085681f47bdecb56fce7b206c2')
        self.assertTrue(self.contract['fullA6AcceptanceComplete'])
        self.assertTrue(self.audit['fullA6AcceptanceComplete'])
        self.assertTrue(self.contract['p5RowCoverageComplete'])
        self.assertEqual(self.contract['outstandingA61ToA67Obligations'], [])
        self.assertTrue(self.contract['combinedG1G5Complete'])
        self.assertTrue(self.contract['combinedG1G5DoesNotByItselfSetFullA6'])
        self.assertEqual(self.contract['newRuntimeExecutions'], 0)
        self.assertFalse(self.combined['fullA6AcceptanceComplete'])
        self.assertFalse(self.plan365['fullA6AcceptanceComplete'])
        self.assertFalse(self.native['fullA6AcceptanceComplete'])
        self.assertIn('still does not, by itself, set', self.late)
        self.assertIn('this audit is the additional official check', self.acceptance)
        self.assertIn('I-037 remains partial', self.adr)
        self.assertTrue(self.contract['i037RemainsPartial'])

    def test_official_row_counts_and_c2_hash_are_recorded(self):
        self.assertEqual(self.contract['p5BrowserCaseCount'], 27)
        self.assertEqual(self.contract['combinedC6CaseCount'], 12)
        self.assertEqual(self.contract['nativeCaseCount'], 7)
        self.assertEqual(len(self.audit['p5BrowserCases']), 27)
        self.assertEqual(len(self.audit['combinedC6Rows']), 12)
        self.assertEqual(len(self.audit['nativeRows']), 7)
        self.assertTrue(all(row['passed'] for row in self.audit['p5BrowserCases']))
        self.assertTrue(all(row['passed'] for row in self.audit['combinedC6Rows']))
        self.assertTrue(all(row['passed'] for row in self.audit['nativeRows']))
        self.assertEqual(self.contract['lateC2MainSha256'], L023)
        self.assertEqual(self.contract['historicalL01LateMainSha256'], L01)
        self.assertNotEqual(L01, L023)
        self.assertFalse(self.contract['l01Rerun'])
        self.assertFalse(self.contract['b01B11Rerun'])
        self.assertFalse(self.contract['combinedG1G5Rerun'])
        self.assertFalse(self.contract['n01N02Requalified'])
        self.assertFalse(self.contract['ng0Ng5Requalified'])
        self.assertFalse(self.contract['frozenEvidenceConflictFound'])
        self.assertFalse(self.native['osAssistiveDeviceClaimed'])

    def test_auditor_reproduces_the_committed_audit(self):
        out = Path('/tmp/signed-import-a6-audit-repro.json')
        subprocess.check_call(
            ['python3', str(ROOT / 'tools/audit/signed_import_app_a6_audit.py'), '--output', str(out)],
            cwd=ROOT,
        )
        reproduced = json.loads(out.read_text())
        self.assertEqual(reproduced, self.audit)

    def test_historical_contracts_and_license_were_not_rewritten(self):
        self.assertEqual(
            self.contract['unchangedFiles']['packages/studio_assets/third_party/sodium_web/LICENSE.core'],
            '508a76d186356c0dd807a670ef510964f8724557024796a2c426c6c0e19ab683',
        )
        changed = subprocess.check_output(
            ['git', 'diff', '--name-only', '0d1c66a8dacafc085681f47bdecb56fce7b206c2'],
            cwd=ROOT, text=True,
        )
        forbidden = (
            'docs/implementation/evidence/signed-import-app-combined/contract.json',
            'docs/implementation/evidence/signed-import-app-combined-plan/contract.json',
            'docs/implementation/evidence/signed-import-app-native-profiles/contract.json',
            'packages/studio_assets/third_party/sodium_web/LICENSE.core',
        )
        names = changed.splitlines()
        for path in forbidden:
            self.assertNotIn(path, names)
        runtime_prefixes = ('apps/', 'packages/', 'native/', 'fixtures/', 'pubspec.lock')
        runtime = [line for line in names if line.startswith(runtime_prefixes)]
        self.assertEqual(runtime, [], runtime)

    def test_non_claims_and_counts_remain_limited(self):
        blob = ' '.join(self.contract['recordedNonClaims'])
        for needle in (
            'OS assistive-device',
            'durable installation',
            'production publisher roots',
            'cross-namespace import',
            'production FTS/RAG',
            'I-037 remaining product acceptance',
        ):
            self.assertIn(needle, blob)
        self.assertEqual(self.contract['fullTasksCompletedUnchanged'], 0)
        self.assertEqual(self.contract['countsUnchanged'], {
            'complete': 0, 'partial': 62, 'planned': 12, 'blocked': 13,
        })
        status = json.loads((ROOT / 'docs/implementation/task-status.json').read_text())
        self.assertEqual(status['fullTasksCompleted'], 0)
        self.assertEqual(status['counts'], {'complete': 0, 'partial': 62, 'planned': 12, 'blocked': 13})
        task = next(item for item in status['tasks'] if item['id'] == 'I-037')
        self.assertEqual(task['status'], 'partial')
        self.assertFalse(task['fullTaskComplete'])
        self.assertEqual(task['remainingAcceptance'], '')
