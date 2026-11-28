"""3.65 official combined G1-G5 checks ONLY; never re-executes historical runtimes."""
import json
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EV = ROOT / 'docs/implementation/evidence/signed-import-app-combined'
PLAN = ROOT / 'docs/implementation/evidence/signed-import-app-combined-plan'
L01 = 'afba0ef81607dd4986381f04bd1e38369c76c22f5d3179843189fa7fda03ef29'
L023 = '935288c577714cac1ae695479edac7c16957d97284aa40de92941391c29312bb'
C6 = [
    'L01-widget-dispose', 'L01-context',
    'L02-open-cancel', 'L02-open-dispose', 'L02-open-context',
    'L02-length-cancel', 'L02-length-dispose', 'L02-length-context',
    'L02-read-cancel', 'L02-read-dispose', 'L02-read-context',
    'L03-null-close-context',
]


class CombinedRunTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EV / 'contract.json').read_text())
        cls.artifacts = json.loads((EV / 'artifacts.json').read_text())
        cls.combined = json.loads((EV / 'combined.json').read_text())
        cls.plan_contract = json.loads((PLAN / 'contract.json').read_text())
        cls.artifacts_359 = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-pending-factory/artifacts.json').read_text()
        )
        cls.artifacts_360 = json.loads(
            (ROOT / 'docs/implementation/evidence/signed-import-app-late-reader/artifacts.json').read_text()
        )
        cls.plan = (ROOT / 'docs/studio/spec/s8f-signed-import-app-late-v1.md').read_text()
        cls.adr = (ROOT / 'docs/adr/0264-app-combined-late-run.md').read_text()
        cls.runner = (ROOT / 'tools/acceptance/run_skill_import_app_combined.py').read_text()

    def test_combined_g1_g5_is_claimed_and_full_a6_is_not(self):
        self.assertEqual(self.contract['increment'], '3.65')
        self.assertEqual(self.contract['base'], '113ea94fd84106d5d624f9885fe3dc530a2c8d15')
        self.assertTrue(self.contract['combinedG1G5Complete'])
        self.assertTrue(self.contract['combinedAcceptanceClaimed'])
        self.assertTrue(self.contract['sameBinaryConditionMet'])
        self.assertTrue(self.contract['allLateRuntimeGatesComplete'])
        self.assertFalse(self.contract['fullA6AcceptanceComplete'])
        self.assertFalse(self.combined['fullA6AcceptanceComplete'])
        self.assertTrue(self.combined['combinedG1G5Complete'])
        self.assertTrue(self.combined['passed'])
        self.assertIn('still does not, by itself, set', self.plan)
        self.assertIn('fullA6AcceptanceComplete remains false', self.adr)

    def test_fresh_c2_binary_covers_all_twelve_rows(self):
        late = self.contract['lateMainSha256']
        self.assertEqual(late, L023)
        self.assertNotEqual(late, L01)
        self.assertTrue(self.contract['c2BinaryIsFreshBuild'])
        self.assertFalse(self.contract['historicalArtifactReusedAsC2'])
        self.assertTrue(self.contract['lateMainEqualsHistoricalL023'])
        self.assertFalse(self.contract['lateMainEqualsHistoricalL01'])
        self.assertEqual(self.contract['c2OutputDirectory'], '/workspace/skill-import-app-365')
        self.assertIn('/workspace/skill-import-app-365', self.runner)
        self.assertNotIn("/workspace/skill-import-app-359'", self.runner)
        self.assertNotIn('/workspace/skill-import-app-360', self.runner)
        self.assertTrue(self.artifacts['freshDisposableCache'])
        self.assertFalse(self.artifacts['verifiedArtifactReuse'])
        self.assertEqual(self.contract['caseIds'], C6)
        self.assertEqual(len(self.combined['summaries']), 12)
        for case_id in C6:
            result = json.loads((EV / 'results' / f'{case_id}.json').read_text())
            self.assertTrue(result['passed'], case_id)
            self.assertEqual(result['c2LateMainSha256'], late)
            self.assertEqual(result['servedAssetSha256']['/main.dart.js'], late)
            self.assertTrue(result['storageSnapshotUnchanged'])
            self.assertTrue(result['noComponentWrites'])
            self.assertTrue(result['noAcknowledgmentAccepted'])
            self.assertEqual(result['exceptions'], [])
            self.assertEqual(result['violations'], [])
            self.assertEqual(result['chooserCount'], 0)
            self.assertTrue(result['csp'].startswith("default-src 'none'; script-src 'self'"))
            self.assertTrue(result['sri'].startswith('sha384-'))
            self.assertEqual(result['combinedIncrement'], '3.65')
            self.assertTrue(result['inputMethod'])
            self.assertTrue(result['actualApp'])

    def test_historical_contracts_and_suites_were_not_rewritten_or_requalified(self):
        self.assertEqual(self.artifacts_359['builds']['late-phase']['mainSha256'], L01)
        self.assertEqual(self.artifacts_360['builds']['late-phase']['mainSha256'], L023)
        self.assertEqual(self.plan_contract['increment'], '3.64')
        self.assertFalse(self.plan_contract['combinedG1G5Complete'])
        self.assertFalse(self.plan_contract['fullA6AcceptanceComplete'])
        self.assertFalse(self.contract['historicalL01RerunAs359Qualification'])
        self.assertTrue(self.contract['combinedG4IncludesL01Rows'])
        self.assertFalse(self.contract['n01N02Requalified'])
        self.assertFalse(self.contract['ng0Ng5Requalified'])
        self.assertTrue(self.contract['g2G3TransportsReusedNotRequalified'])
        self.assertFalse(self.contract['g3SuiteRerun'])
        self.assertFalse(self.contract['b01B11Rerun'])
        self.assertFalse(self.contract['frozenEvidenceConflictFound'])
        self.assertTrue(self.contract['historicalL01ContractUnchanged'])
        self.assertTrue(self.contract['historicalL02L03ContractUnchanged'])
        self.assertTrue(self.contract['driverScopeLabelsAreHistorical'])

    def test_studio_web_unchanged_and_production_exclusions_hold(self):
        log = subprocess.check_output(
            ['git', 'log', '--oneline', '7c616a4aab245505f3fdd9fac15095fd640f5e3b..HEAD', '--', 'apps/studio_web'],
            cwd=ROOT, text=True,
        ).strip()
        self.assertEqual(log, '')
        self.assertFalse(self.contract['studioWebSourceChanged'])
        self.assertTrue(self.contract['defaultMainMatches360'])
        self.assertTrue(self.contract['optInMainMatches360'])
        self.assertEqual(
            self.artifacts['builds']['default']['mainSha256'],
            '87fc12eb3a69447ffd4ed5b20b8437909fcbd87d0a1ab176352335961d7774f8',
        )
        self.assertEqual(
            self.artifacts['builds']['opt-in']['mainSha256'],
            'b44f2d205403d4b58440db3ed1cc0723408c7f6a89c52fce96dd87ffb6c9aa3c',
        )
        for name in ('default', 'opt-in'):
            build = self.artifacts['builds'][name]
            self.assertFalse(build['fixtureSentinelsPresent'])
            self.assertFalse(build['testEntrypointInSourceMap'])
        late = self.artifacts['builds']['late-phase']
        self.assertTrue(late['fixtureSentinelsPresent'])
        self.assertTrue(late['testEntrypointInSourceMap'])
        self.assertEqual(
            self.contract['unchangedFiles']['packages/studio_assets/third_party/sodium_web/LICENSE.core'],
            '508a76d186356c0dd807a670ef510964f8724557024796a2c426c6c0e19ab683',
        )

    def test_no_runtime_tree_edits_in_this_combined_run(self):
        changed = subprocess.check_output(
            ['git', 'diff', '--name-only', '113ea94fd84106d5d624f9885fe3dc530a2c8d15'],
            cwd=ROOT, text=True,
        )
        runtime_prefixes = ('apps/', 'packages/', 'native/', 'fixtures/', 'pubspec.lock')
        runtime = [line for line in changed.splitlines() if line.startswith(runtime_prefixes)]
        self.assertEqual(runtime, [], runtime)
