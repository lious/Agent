"""3.67 residual I-037 / program leftover inventory checks ONLY."""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EV = ROOT / 'docs/implementation/evidence/i037-residual-inventory'
A6 = ROOT / 'docs/implementation/evidence/signed-import-app-a6-audit'
COMBINED = ROOT / 'docs/implementation/evidence/signed-import-app-combined'
FORBIDDEN = ['I-035', 'I-055', 'I-059', 'I-061', 'I-016', 'I-017', 'I-018', 'I-019']


class ResidualInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EV / 'contract.json').read_text())
        cls.inventory = json.loads((EV / 'inventory.json').read_text())
        cls.a6 = json.loads((A6 / 'contract.json').read_text())
        cls.combined = json.loads((COMBINED / 'contract.json').read_text())
        cls.status = json.loads((ROOT / 'docs/implementation/task-status.json').read_text())
        cls.i037 = next(item for item in cls.status['tasks'] if item['id'] == 'I-037')
        cls.adr = (ROOT / 'docs/adr/0266-i037-residual-inventory.md').read_text()
        cls.acceptance = (ROOT / 'docs/studio/spec/s8f-signed-import-app-acceptance-v1.md').read_text()

    def test_inventory_does_not_complete_i037_or_the_program(self):
        self.assertEqual(self.contract['increment'], '3.67')
        self.assertEqual(self.contract['base'], '4f8f0996ab9c228585f3878c638276662d3f12fe')
        self.assertEqual(self.contract['kind'], 'residual-i037-program-leftover-inventory-only')
        self.assertEqual(self.contract['newRuntimeExecutions'], 0)
        self.assertFalse(self.contract['implementationSliceLanded'])
        self.assertFalse(self.contract['advanceableImplementationSliceFound'])
        self.assertTrue(self.contract['i037RemainsPartial'])
        self.assertTrue(self.contract['doesNotCompleteI037'])
        self.assertTrue(self.contract['doesNotCompleteProgramOrT4'])
        self.assertTrue(self.contract['i037RemainingAcceptanceUnchanged'])
        self.assertEqual(self.i037['remainingAcceptance'], '')
        self.assertFalse(self.i037['fullTaskComplete'])
        self.assertEqual(self.i037['status'], 'partial')
        self.assertIn('签名包导入与 FTS 召回仍未打开', self.i037['remainingScope'])
        self.assertIn('Increment 3.67', self.i037['remainingScope'])
        self.assertEqual(self.status['fullTasksCompleted'], 0)
        self.assertEqual(self.status['counts'], {
            'complete': 0, 'partial': 62, 'planned': 12, 'blocked': 13,
        })

    def test_full_a6_stays_true_only_in_the_366_contract(self):
        self.assertTrue(self.a6['fullA6AcceptanceComplete'])
        self.assertEqual(self.a6['increment'], '3.66')
        self.assertFalse(self.combined['fullA6AcceptanceComplete'])
        self.assertTrue(self.contract['fullA6AcceptanceCompleteIn366Only'])
        self.assertTrue(self.contract['frozen365FullA6RemainsFalse'])
        self.assertTrue(self.contract['doesNotReopenOrUnsetFullA6Audit'])
        self.assertNotEqual(self.contract.get('fullA6AcceptanceComplete', 'absent'), True)
        self.assertIn('does not complete', self.adr)
        self.assertIn('I-037 remains partial', self.adr)
        self.assertIn('still does not close I-037', self.acceptance)

    def test_forbidden_surfaces_and_excluded_tasks_were_not_started(self):
        for item in (
            'durable installation',
            'production publisher roots',
            'cross-namespace import',
            'production FTS/RAG',
        ):
            self.assertTrue(any(item in row for row in self.contract['doNotOpen']))
        self.assertEqual(self.contract['doNotStart'], FORBIDDEN)
        by_id = {item['id']: item for item in self.status['tasks']}
        for task_id in FORBIDDEN:
            self.assertEqual(by_id[task_id]['status'], 'planned', task_id)
            self.assertFalse(by_id[task_id]['fullTaskComplete'])
        self.assertEqual(self.contract['plannedIdsNotStarted'], [
            item['id'] for item in self.status['tasks'] if item['status'] == 'planned'
        ])
        self.assertEqual(self.contract['blockedIdsNotStarted'], [
            item['id'] for item in self.status['tasks'] if item['status'] == 'blocked'
        ])
        self.assertIn('art-page widget APIs', ' '.join(self.contract['standingNonClaims']))
        self.assertIn('OS assistive-device', ' '.join(self.contract['standingNonClaims']))

    def test_no_runtime_tree_edits_and_license_untouched(self):
        self.assertEqual(
            self.contract['unchangedFiles']['packages/studio_assets/third_party/sodium_web/LICENSE.core'],
            '508a76d186356c0dd807a670ef510964f8724557024796a2c426c6c0e19ab683',
        )
        changed = subprocess.check_output(
            ['git', 'diff', '--name-only', '4f8f0996ab9c228585f3878c638276662d3f12fe'],
            cwd=ROOT, text=True,
        )
        names = changed.splitlines()
        self.assertNotIn('packages/studio_assets/third_party/sodium_web/LICENSE.core', names)
        self.assertNotIn('docs/implementation/evidence/signed-import-app-a6-audit/contract.json', names)
        runtime_prefixes = ('apps/', 'packages/', 'native/', 'fixtures/', 'pubspec.lock')
        runtime = [line for line in names if line.startswith(runtime_prefixes)]
        self.assertEqual(runtime, [], runtime)
