"""Plan lint and DSSE reference encoding only; no signature or loader qualification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / 'docs/studio/spec'
EVIDENCE = ROOT / 'docs/implementation/evidence/signed-import-plan-v1'


def historical(base, path):
    return subprocess.check_output(['git', 'show', base + ':' + path], cwd=ROOT)


class SignedImportPlanTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EVIDENCE / 'contract.json').read_text())
        cls.text = (SPEC / 's8f-signed-import-v1.md').read_text()
        cls.base = cls.contract['preservedBase']

    def test_explicit_plan_only_boundary(self):
        self.assertEqual(self.contract['kind'], 'planConsistencyOnly')
        self.assertFalse(self.contract['runtimeImplemented'])
        self.assertFalse(self.contract['cryptoVerificationQualified'])
        for section in self.contract['sections']:
            self.assertIn('## ' + section + ' —', self.text)
        self.assertIn('PLANNED tests', self.text)
        self.assertIn('not an implemented verifier', self.text)

    def test_preserved_source_contracts(self):
        for path, digest in self.contract['unchangedFiles'].items():
            original = historical(self.base, path)
            self.assertEqual(hashlib.sha256(original).hexdigest(), digest)
            self.assertEqual((ROOT / path).read_bytes(), original, path)
        original = historical(self.base, 'docs/studio/spec/s8f.md')
        current = (SPEC / 's8f.md').read_bytes()
        self.assertTrue(current.startswith(original))
        self.assertIn(b's8f-signed-import-v1.md', current[len(original):])

    def test_status_is_not_new_acceptance(self):
        old = json.loads(historical(self.base, 'docs/implementation/task-status.json'))
        new = json.loads((ROOT / 'docs/implementation/task-status.json').read_text())
        self.assertEqual(new['counts'], {'complete': 0, 'partial': 62, 'planned': 12, 'blocked': 13})
        self.assertEqual(new['fullTasksCompleted'], 0)
        self.assertEqual(len(new['tasks']), 87)
        for before, after in zip(old['tasks'], new['tasks']):
            self.assertEqual(before['id'], after['id'])
            for key in ['status', 'implementationStatus', 'verificationStatus',
                        'fullTaskComplete', 'remainingAcceptance', 'remainingScope']:
                self.assertEqual(before.get(key), after.get(key), (before['id'], key))
            if before['id'] != 'I-037':
                self.assertEqual(before, after)
            else:
                self.assertTrue(after['implementedScope'].startswith(before['implementedScope']))
                self.assertEqual(after['evidence'][:-1], before['evidence'])

    def test_authentication_and_no_downgrade_bindings(self):
        for phrase in [self.contract['payloadType'], 'Pure Ed25519', 'COMPLETE PAE',
                       'NO JSON canonicalization', 'same immutable body',
                       'UNAUTHENTICATED routing hint', 'PUBLIC KEY BYTES',
                       'Default shipped trusted signer set is empty',
                       'ONE direct edge', 'No runtime key-enrollment',
                       'cannot fall back to unsigned', 'not a recursive self-hash',
                       'signatureRef must be null',
                       'rather than retroactively certifying its booleans',
                       'namespace.appId', 'tenantId,workspaceId']:
            self.assertIn(phrase, self.text)

    def test_resource_and_manifest_bindings(self):
        self.assertEqual(self.contract['algorithm'], 'Ed25519')
        self.assertEqual(self.contract['limits'], {'envelopeBytes': 4194304,
                         'payloadBytes': 2097152, 'fileBytes': 1048576,
                         'depth': 32, 'signatures': 8})
        for word in ['manifestHash', 'inputSchema', 'outputSchema', 'testFixtures',
                     'permissionDiff', 'policyEpoch', 'SKILL_IMPORT_PREVIEW_STALE',
                     'Ed25519ph', 'unrecognized ENVELOPE', 'sha256:',
                     'no files on disk', 'existing warning behavior']:
            self.assertIn(word, self.text)
        self.assertEqual(len(self.contract['plannedAcceptanceCases']), 6)

    def test_local_document_links_resolve(self):
        for path in [SPEC / 's8f-signed-import-v1.md',
                     ROOT / 'docs/adr/0244-s8f-signed-import-plan.md']:
            for link in re.findall(r'\]\(([^)]+)\)', path.read_text()):
                if not link.startswith('https:'):
                    self.assertTrue((path.parent / link.split('#')[0]).exists(), link)

    def test_dsse_reference_pae_not_a_signature_test(self):
        # DSSE protocol 1.0.2's published PAE vector, not a production verifier.
        def reference_pae(payload_type, body):
            type_bytes = payload_type.encode('utf-8')
            return (b'DSSEv1 ' + str(len(type_bytes)).encode('ascii') + b' ' +
                    type_bytes + b' ' + str(len(body)).encode('ascii') + b' ' + body)
        self.assertEqual(reference_pae('http://example.com/HelloWorld', b'hello world'),
                         b'DSSEv1 29 http://example.com/HelloWorld 11 hello world')
        self.assertEqual(reference_pae('片', '镜头'.encode()),
                         b'DSSEv1 3 \xe7\x89\x87 6 \xe9\x95\x9c\xe5\xa4\xb4')
        self.assertNotEqual(reference_pae('x', b'{"a":1}'),
                            reference_pae('x', b'{ "a": 1 }'))


if __name__ == '__main__':
    unittest.main()
