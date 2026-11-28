"""Official App composition PLAN consistency only; no UI/source/crypto runtime qualification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOLDER = 'docs/implementation/evidence/signed-import-app-plan-v1/'
SPEC = 'docs/studio/spec/s8f-signed-import-app-v1.md'
ADR = 'docs/adr/0248-signed-import-app-composition-plan.md'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def plan_commit():
    commits = git('log', '--diff-filter=A', '--format=%H', '--', FOLDER + 'contract.json').decode().splitlines()
    return commits[-1] if commits else None


def at_plan(path):
    commit = plan_commit()
    return git('show', commit + ':' + path) if commit else (ROOT / path).read_bytes()


class SignedImportAppPlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((ROOT / FOLDER / 'contract.json').read_text())
        cls.sources = json.loads((ROOT / FOLDER / 'sources.json').read_text())
        cls.text = (ROOT / SPEC).read_text()

    def test_plan_only_boundary_and_sections(self):
        self.assertEqual(self.contract['kind'], 'appCompositionPlanOnly')
        for key in ['runtimeImplemented', 'uiQualified', 'filePickerQualified', 'cryptoRequalified']:
            self.assertFalse(self.contract[key])
        for section in self.contract['sections']:
            self.assertIn('## ' + section + ' —', self.text)
        for phrase in ['PLAN ONLY', 'NOT UI', 'No crypto protocol changes',
                       'No frozen', 'No plugin was installed', 'not folded into these plan checks']:
            self.assertIn(phrase, self.text)

    def test_scope_policy_and_existing_surface_bindings(self):
        for phrase in ['FoundationApp API', 'no new public editor-widget API',
                       'studio_demo/local/default', 'studio/local/web',
                       'BuildTimeSignaturePolicy.disabled', 'EMPTY publisher roots',
                       'all THREE sets to EMPTY', 'clockConfident remains false',
                       'identical installed policy', 'LIVE current-App callback',
                       'no token queue', 'never be stripped/retried as unsigned']:
            self.assertIn(phrase, self.text)

    def test_bounded_capture_lifetime_and_honest_path_semantics(self):
        for value in self.contract['limits'].values():
            self.assertIn(str(value), self.text)
        for phrase in ['FileSelectorLinux().openFile', 'XFile(paths.first)',
                       'NOT an atomic no-follow/inode-attestation API',
                       'SAME RandomAccessFile', 'read-only mode', 'close in finally',
                       'BEFORE the first arrayBuffer allocation', 'File.slice(start,end)',
                       'not OS cancellation', 'cancelling/quiescing',
                       'late completion', 'ONE pending preview', 'No secure-memory-erasure claim']:
            self.assertIn(phrase, self.text)

    def test_immutable_consent_privilege_and_license_binding(self):
        for phrase in ['immutable SkillVerificationReport', 'Acknowledge preview only',
                       'without an await', 'not an ID echo', 'userConfirmed',
                       'allow_with_warning', 'No clock override button',
                       'also for an unsigned preview', 'No state restoration',
                       'executionAuthority=false', 'documentWrites=0',
                       'not a license grant', 'No pack-provided title']:
            self.assertIn(phrase, self.text)

    def test_non_relaxing_actual_app_host_and_independent_acceptance(self):
        for phrase in ["base-uri 'none'", 'removes the base tag',
                       '--no-web-resources-cdn', "renderer='canvaskit'",
                       'response-specific', 'nonce', 'NOT a script-src bypass',
                       "worker-src 'none'", 'FAIL the App-host qualification',
                       'Actual Linux GTK', 'Actual compiled Web App',
                       'Fake source streams in TESTS ONLY', 'No skip, fake backend-success']:
            self.assertIn(phrase, self.text)
        self.assertNotIn("base-uri 'self';", self.text)
        self.assertIn('it was never', (ROOT / ADR).read_text().lower())

    def test_exact_compatible_source_candidates_and_no_execution(self):
        packages = {p['name']: p for p in self.sources['candidatePackages']}
        self.assertEqual(packages['file_selector_linux']['version'], '0.9.4+1')
        self.assertEqual(packages['file_selector_platform_interface']['version'], '2.7.0')
        self.assertEqual(packages['cross_file']['version'], '0.3.5+5')
        self.assertTrue(packages['cross_file']['version'].startswith('0.3.'))
        for item in packages.values():
            self.assertTrue(item['archiveHashVerified'])
            self.assertFalse(item['installedOrExecuted'])
            self.assertRegex(item['archiveSha256'], r'^[0-9a-f]{64}$')
            self.assertTrue(item['archiveUrl'].startswith('https://pub.dev/api/archives/'))
        self.assertFalse(self.sources['executed'])
        self.assertFalse(self.sources['selectorQualified'])
        self.assertFalse(self.sources['uiQualified'])
        self.assertEqual(self.sources['existingLockedDependencies']['web']['version'], '1.1.2')

    def test_no_runtime_dependency_or_frozen_contract_edits(self):
        base = self.contract['base']
        for path, digest in self.contract['unchangedFiles'].items():
            original = git('show', base + ':' + path)
            self.assertEqual(hashlib.sha256(original).hexdigest(), digest, path)
            self.assertEqual((ROOT / path).read_bytes(), original, path)
        # Assert this plan's historical tree, not a ban on scheduled future UI.
        commit = plan_commit()
        for tree in self.contract['preservedSourceTrees']:
            args = ['diff', '--name-only', base]
            if commit:
                args.append(commit)
            self.assertEqual(git(*args, '--', tree), b'', tree)

    def test_original_acceptance_scope_and_counts_preserved(self):
        old = json.loads(git('show', self.contract['base'] + ':docs/implementation/task-status.json'))
        new = json.loads(at_plan('docs/implementation/task-status.json'))
        self.assertEqual(new['counts'], self.contract['counts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
                continue
            for key in before:
                if key == 'implementedScope':
                    self.assertTrue(after[key].startswith(before[key]))
                    self.assertIn('PLAN', after[key][len(before[key]):])
                elif key == 'evidence':
                    self.assertEqual(after[key], before[key] + ['evidence/signed-import-app-plan-v1/'])
                else:
                    self.assertEqual(before[key], after[key], key)

    def test_local_links_and_append_only_original_s8f(self):
        for path in [SPEC, ADR]:
            for link in re.findall(r'\]\(([^)]+)\)', (ROOT / path).read_text()):
                if not link.startswith('https:'):
                    self.assertTrue((ROOT / path).parent.joinpath(link.split('#')[0]).exists(), link)
        original = git('show', self.contract['base'] + ':docs/studio/spec/s8f.md')
        current = (ROOT / 'docs/studio/spec/s8f.md').read_bytes()
        self.assertTrue(current.startswith(original))
        self.assertIn(b's8f-signed-import-app-v1.md', current[len(original):])


if __name__ == '__main__':
    unittest.main()
