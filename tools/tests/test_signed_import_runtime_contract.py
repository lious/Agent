"""Runtime evidence/preservation lint; no old runtime qualification is rerun."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/implementation/evidence/i037-signed-import-preview'


class SignedImportRuntimeContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EVIDENCE / 'contract.json').read_text())

    def test_authoritative_film_schema_reference_closure(self):
        blocks = re.findall(r'```[^\n]*\n(.*?)```', (ROOT / 'docs/studio/spec/s8g.md').read_text(), re.S)
        source = next(json.loads(b) for b in blocks if b.lstrip().startswith('{')
                      and '"$id": "urn:studio:FilmSkill:1.0.0"' in b)
        used, todo = {}, ['FilmSkill']
        while todo:
            name = todo.pop()
            if name in used:
                continue
            used[name] = source['$defs'][name]
            todo.extend(re.findall(r'"\$ref":\s*"#/\$defs/([^\"]+)"', json.dumps(used[name])))
        source['$defs'] = used
        dart = (ROOT / 'packages/studio_assets/lib/craft/signed_import/film_schema.dart').read_text()
        embedded = json.loads(re.search(r"r'''\n(.*?)\n'''", dart, re.S).group(1))
        self.assertEqual(source, embedded)

    def test_preserved_privilege_frozen_and_preexisting_failure_files(self):
        base = self.contract['preservedBase']
        for path, digest in self.contract['unchangedFiles'].items():
            original = subprocess.check_output(['git', 'show', base + ':' + path], cwd=ROOT)
            self.assertEqual(hashlib.sha256(original).hexdigest(), digest, path)
            self.assertEqual((ROOT / path).read_bytes(), original, path)

    def test_honest_status_and_original_wording(self):
        base = self.contract['preservedBase']
        old = json.loads(subprocess.check_output(['git', 'show', base + ':docs/implementation/task-status.json'], cwd=ROOT))
        new = json.loads((ROOT / 'docs/implementation/task-status.json').read_text())
        self.assertEqual(new['counts'], self.contract['statusCounts'])
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            self.assertEqual(before['id'], after['id'])
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
                continue
            for key in ['status', 'implementationStatus', 'verificationStatus',
                        'fullTaskComplete', 'remainingAcceptance', 'hardDeps', 'blockers']:
                self.assertEqual(before[key], after[key], key)
            for key in ['implementedScope', 'remainingScope']:
                self.assertTrue(after[key].startswith(before[key]), key)
            self.assertEqual(after['evidence'][:-1], before['evidence'])

    def test_locked_backend_corpus_and_native_only_entrypoint(self):
        lock = json.loads((ROOT / self.contract['backendLock']).read_text())
        self.assertEqual(lock['version'], '1.0.22')
        self.assertEqual(lock['sourceSha256'], 'adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349')
        self.assertEqual(lock['license'], 'ISC')
        vector = (ROOT / 'packages/studio_assets/test/skills/signed_import/vectors/ed25519_test.json').read_bytes()
        self.assertEqual(hashlib.sha256(vector).hexdigest(), 'ea80ffebac085e21cb9d3e903e7fa2b448d96702da5b31f061d0b83b430b74b3')
        self.assertEqual(json.loads(vector)['numberOfTests'], 210)
        self.assertEqual(self.contract['dartTests'], self.contract['backendFrameworkCases'] + self.contract['importerFrameworkCases'])
        shared = (ROOT / 'packages/studio_assets/lib/studio_assets.dart').read_text()
        self.assertNotIn('signed_import', shared)
        pubspec = json.loads((ROOT / 'packages/studio_assets/pubspec.yaml').read_text())
        self.assertEqual(pubspec['dependencies']['ffi'], '2.2.0')


if __name__ == '__main__':
    unittest.main()
