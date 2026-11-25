import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('run_task', ROOT / 'tools/acceptance/run_task.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AcceptanceTests(unittest.TestCase):
    def test_unknown_task_exits_two(self):
        result = subprocess.run([sys.executable, 'tools/acceptance/run_task.py', 'NOT-A-TASK',
                                 '--profile', 'linux-dev', '--report', '/tmp/unused-report.json'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_schema_copy_and_embedded_constant_match_authoritative_document(self):
        blocks = re.findall(r'```[^\n]*\n(.*?)```', (ROOT / 'docs/studio/spec/s5.md').read_text(), re.S)
        schemas = []
        for block in blocks:
            try:
                value = json.loads(block)
            except ValueError:
                continue
            if isinstance(value, dict) and value.get('$id') == 'urn:studio:project:2.0.0':
                schemas.append(value)
        self.assertEqual(len(schemas), 1)
        self.assertEqual(schemas[0], json.loads((ROOT / 'schemas/project.schema.json').read_text()))
        dart = (ROOT / 'packages/studio_document/lib/src/project_schema.dart').read_text()
        embedded = re.search(r"r'''\n(.*?)\n'''", dart, re.S).group(1)
        self.assertEqual(schemas[0], json.loads(embedded))

    def test_hidden_loader_and_skipped_tests_are_not_counted(self):
        output = '\n'.join(json.dumps(x) for x in [
            {'type': 'testDone', 'hidden': True, 'skipped': False},
            {'type': 'testDone', 'hidden': False, 'skipped': True},
            {'type': 'testDone', 'hidden': False, 'skipped': False},
        ])
        self.assertEqual(module.test_count(output), 1)

    def test_timeout_becomes_failed_evidence(self):
        record = module.run([sys.executable, '-c', 'import time; time.sleep(10)'], timeout=0.02)
        self.assertEqual(record['exitCode'], 124)
        self.assertIn('TIMEOUT', record['output'])


if __name__ == '__main__':
    unittest.main()
