"""Contract checks for Increment 3.63 official N01-N02 qualification."""
import json, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = json.loads(
    (ROOT / 'docs/implementation/evidence/signed-import-app-native-profiles/contract.json').read_text()
)
EXPECTED = [
    'N01-enter', 'N01-space', 'N01-semantics',
    'N02-preview-navigation', 'N02-preview-dispose',
    'N02-read-navigation', 'N02-read-dispose',
]

class NativeProfileContractTests(unittest.TestCase):
    def test_seven_profiles_qualified_without_combined_acceptance(self):
        self.assertEqual(CONTRACT['increment'], '3.63')
        self.assertEqual(CONTRACT['base'], '91439223878707181e3dadd01786e9d9a60ca892')
        self.assertEqual(CONTRACT['qualifiedNativeRows'], EXPECTED)
        self.assertEqual(CONTRACT['qualifiedNativeGates'], ['NG4', 'NG5'])
        self.assertEqual(CONTRACT['reusedNativeGates'], ['NG0', 'NG1', 'NG2', 'NG3'])
        self.assertEqual(CONTRACT['pendingNativeProfiles'], [])
        self.assertFalse(CONTRACT['fullA6AcceptanceComplete'])
        self.assertFalse(CONTRACT['combinedAcceptanceClaimed'])
        self.assertFalse(CONTRACT['l01Rerun'])
        self.assertFalse(CONTRACT['osAssistiveDeviceClaimed'])

    def test_profiles_report_matches_contract(self):
        report = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-native-profiles/profiles.json').read_text()
        )
        self.assertTrue(report['passed'])
        self.assertEqual(report['qualifiedNativeRows'], EXPECTED)
        self.assertFalse(report['combinedAcceptanceClaimed'])
        self.assertFalse(report['fullA6AcceptanceComplete'])
        self.assertEqual([s['case'] for s in report['summaries'] if s['passed']], EXPECTED)

if __name__ == '__main__':
    unittest.main()
