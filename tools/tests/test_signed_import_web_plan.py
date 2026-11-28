"""Official plan consistency only: never executes the candidate or prior runtimes."""
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/web-signed-import-plan-v1/'
SPEC = 'docs/studio/spec/s8f-signed-import-web-v1.md'


def git_bytes(rev, path):
    return subprocess.check_output(['git', 'show', rev + ':' + path], cwd=ROOT)


def at_plan(path):
    # Once landed, the original evidence commit defines the plan-only snapshot.
    # This must not prohibit the future implementation explicitly scheduled here.
    history = subprocess.check_output(['git', 'log', '--reverse', '--format=%H',
                                      '--', FOLDER + 'contract.json'], cwd=ROOT, text=True).splitlines()
    return git_bytes(history[0], path) if history else (ROOT / path).read_bytes()


class WebSignedImportPlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads(at_plan(FOLDER + 'contract.json'))
        cls.candidate = json.loads(at_plan(FOLDER + 'backend-candidate.json'))
        cls.text = at_plan(SPEC).decode()
        cls.base = cls.contract['preservedBase']

    def test_seven_bindings_are_explicitly_plan_only(self):
        self.assertEqual(self.contract['kind'], 'webCompositionPlanOnly')
        for flag in ['runtimeImplemented', 'webQualified', 'candidateExecuted']:
            self.assertFalse(self.contract[flag])
        for section in self.contract['sections']:
            self.assertIn('## ' + section + ' —', self.text)
        self.assertIn('NOT RUN in 3.47', self.text)
        self.assertIn('PLAN ONLY', self.text)

    def test_candidate_pin_is_not_crypto_qualification(self):
        c = self.candidate
        self.assertFalse(c['executed'])
        self.assertFalse(c['webQualified'])
        self.assertEqual(c['tag'], '0.8.4')
        self.assertEqual(c['expectedCoreVersion'], '1.0.22')
        self.assertEqual(c['license'], 'ISC')
        self.assertEqual(c['sourceBytes'], 1319027)
        self.assertEqual(c['sourceSha256'], '5d6f10ef3e530b45536ee0aa40fa54a46220cc78984df6992a9d48e9a741e8f7')
        self.assertEqual(len(base64.b64decode(c['sri'].split('-', 1)[1])), 48)
        for value in [c['sourceSha256'], c['sri'], c['coreSubmoduleCommit']]:
            self.assertIn(value, self.text)

    def test_preexecution_readiness_and_no_crypto_fallback(self):
        self.assertEqual(self.contract['readinessDeadlineMs'], 10000)
        for phrase in ['SRI MUST succeed before', '10000 ms', 'terminally',
                       'late callbacks cannot', 'unsafe-eval', 'private readiness Promise',
                       'crypto.getRandomValues', 'never Math.random', 'no repository']:
            self.assertIn(phrase, self.text)

    def test_typed_adapter_preserves_security_boundaries(self):
        for phrase in ['dart.library.js_interop', 'final Web SodiumVerifier',
                       'freshly copied Uint8Array', 'signature argument comes FIRST',
                       'strict boolean true', 'COMPLETE_PAE', 'source-preservation',
                       'EMPTY', 'AFTER asynchronous', 'signed=true', 'needsReview',
                       'documentWrites=0', 'executionAuthority=false', '9007199254740993']:
            self.assertIn(phrase, self.text)

    def test_runtime_and_frozen_files_were_unchanged_at_plan_snapshot(self):
        for path, expected in self.contract['unchangedFiles'].items():
            original = git_bytes(self.base, path)
            self.assertEqual(hashlib.sha256(original).hexdigest(), expected)
            self.assertEqual(at_plan(path), original, path)
        for path in ['docs/studio/spec/s8f.md', 'docs/studio/spec/s8f-signed-import-v1.md']:
            self.assertTrue(at_plan(path).startswith(git_bytes(self.base, path)))

    def test_status_preserves_acceptance_and_remaining_scope(self):
        old = json.loads(git_bytes(self.base, 'docs/implementation/task-status.json'))
        new = json.loads(at_plan('docs/implementation/task-status.json'))
        self.assertEqual(new['counts'], self.contract['statusCounts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            self.assertEqual(before['id'], after['id'])
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
            else:
                for key in ['status', 'implementationStatus', 'verificationStatus',
                            'fullTaskComplete', 'remainingAcceptance', 'remainingScope']:
                    self.assertEqual(before[key], after[key])
                self.assertTrue(after['implementedScope'].startswith(before['implementedScope']))
                self.assertEqual(after['evidence'][:-1], before['evidence'])

    def test_required_browser_evidence_and_local_links(self):
        for phrase in ['REAL browser', '210', 'not only standalone JS crypto',
                       'SRI tampering', 'CSP failure', 'never-resolving', 'no skip',
                       'No Flutter widget/file-picker']:
            self.assertIn(phrase, self.text)
        for path in [SPEC, 'docs/adr/0246-web-signed-import-composition-plan.md']:
            for link in re.findall(r'\]\(([^)]+)\)', at_plan(path).decode()):
                if not link.startswith('https:'):
                    self.assertTrue((ROOT / path).parent.joinpath(link.split('#')[0]).exists(), link)


if __name__ == '__main__':
    unittest.main()
