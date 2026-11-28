"""3.64 combined-acceptance binding checks ONLY; never re-executes historical runtimes."""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EV = ROOT / 'docs/implementation/evidence/signed-import-app-combined-plan'
L01 = 'afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29'
L023 = '935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb'
C6 = [
    'L01-widget-dispose', 'L01-context',
    'L02-open-cancel', 'L02-open-dispose', 'L02-open-context',
    'L02-length-cancel', 'L02-length-dispose', 'L02-length-context',
    'L02-read-cancel', 'L02-read-dispose', 'L02-read-context',
    'L03-null-close-context',
]


class CombinedPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EV / 'contract.json').read_text())
        cls.conditions = json.loads((EV / 'conditions.json').read_text())
        cls.artifacts_359 = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-pending-factory/artifacts.json').read_text()
        )
        cls.artifacts_360 = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-late-reader/artifacts.json').read_text()
        )
        cls.audit = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-native-plan/audit.json').read_text()
        )
        cls.plan = (ROOT / 'docs/studio/spec/s8f-signed-import-app-late-v1.md').read_text()
        cls.adr = (ROOT / 'docs/adr/0263-app-combined-late-acceptance.md').read_text()

    def test_binding_does_not_claim_combined_or_full_a6(self):
        for doc in (self.contract, self.conditions):
            self.assertEqual(doc['increment'], '3.64')
            self.assertFalse(doc['fullA6AcceptanceComplete'])
            self.assertFalse(doc['sameBinaryConditionMet'])
            self.assertFalse(doc['combinedG1G5Complete'])
        self.assertFalse(self.contract['combinedAcceptanceClaimed'])
        self.assertFalse(self.contract['runtimeImplemented'])
        self.assertEqual(self.contract['newRuntimeExecutions'], 0)
        self.assertFalse(self.contract['l01Rerun'])
        self.assertEqual(self.contract['base'], '79109119861569d1b32093f8ba2f0ad67f7ba58d')

    def test_late_c2_hashes_remain_distinct_and_authoritative(self):
        self.assertEqual(self.artifacts_359['builds']['late-phase']['mainSha256'], L01)
        self.assertEqual(self.artifacts_360['builds']['late-phase']['mainSha256'], L023)
        self.assertNotEqual(L01, L023)
        self.assertEqual(set(self.audit['lateFixtureBinarySha256']), {L01, L023})
        self.assertEqual(set(self.conditions['lateFixtureBinarySha256']), {L01, L023})
        self.assertEqual(self.conditions['l01LateMainSha256'], L01)
        self.assertEqual(self.conditions['l02L03LateMainSha256'], L023)
        self.assertFalse(self.conditions['l01Rerun'])
        self.assertFalse(self.conditions['frozenEvidenceConflictFound'])

    def test_plan_requires_one_fresh_binary_and_twelve_c6_rows(self):
        self.assertIn('one late-phase fixture binary', self.plan)
        self.assertIn(L01, self.plan)
        self.assertIn(L023, self.plan)
        self.assertIn(L01, self.adr)
        self.assertIn(L023, self.adr)
        self.assertEqual(self.contract['combinedCaseIds'], C6)
        self.assertEqual(self.conditions['combinedCaseIds'], C6)
        self.assertIn('fullA6AcceptanceComplete', self.plan)
        self.assertIn('still does not, by itself, set', self.plan)
        self.assertIn('PLAN/EVIDENCE ONLY', self.plan)

    def test_studio_web_unchanged_since_late_reader_qualification(self):
        log = subprocess.check_output(
            ['git', 'log', '--oneline', '7c616a4aab245505f3fdd9fac15095fd640f5e3b..HEAD', '--', 'apps/studio_web'],
            cwd=ROOT, text=True,
        ).strip()
        self.assertEqual(log, '')
        self.assertEqual(self.conditions['studioWebChangesSince360'], [])

    def test_no_runtime_tree_edits_in_this_binding(self):
        changed = subprocess.check_output(
            ['git', 'diff', '--name-only', '79109119861569d1b32093f8ba2f0ad67f7ba58d'],
            cwd=ROOT, text=True,
        )
        runtime_prefixes = ('apps/', 'packages/', 'native/', 'fixtures/', 'pubspec.lock')
        runtime = [line for line in changed.splitlines() if line.startswith(runtime_prefixes)]
        self.assertEqual(runtime, [], runtime)
