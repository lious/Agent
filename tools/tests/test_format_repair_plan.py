"""Plan lint only: no harness/model execution or product qualification."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "docs/studio/spec"
EVIDENCE = ROOT / "docs/implementation/evidence/format-repair-plan-v1"


class FormatRepairPlanConsistencyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = json.loads((EVIDENCE / "contract.json").read_text())
        cls.text = (SPEC / "s10e-format-repair-v1.md").read_text()

    def test_five_bindings_and_explicit_plan_only_status(self):
        self.assertEqual(set(self.contract["bindings"]), {"B1", "B2", "B3", "B4", "B5"})
        for binding in self.contract["bindings"]:
            self.assertIn("## " + binding + " —", self.text)
        self.assertFalse(self.contract["runtimeImplemented"])
        self.assertEqual(self.contract["kind"], "planConsistencyOnly")
        self.assertEqual(self.contract["maxPlanRepairs"], 1)
        self.assertEqual(self.contract["attempts"], [1, 2])
        self.assertIn("Implementation is deferred to Increment 3.44", self.text)

    def test_existing_specification_text_is_preserved_and_linked(self):
        for name in ["s10b.md", "s10c.md", "s10d.md", "s10e.md", "s12a.md"]:
            path = "docs/studio/spec/" + name
            original = subprocess.check_output(["git", "show", self.contract["preservedBase"] + ":" + path], cwd=ROOT)
            current = (ROOT / path).read_bytes()
            self.assertTrue(current.startswith(original), name)
            self.assertIn(b"s10e-format-repair-v1.md", current[len(original):])

    def test_recorded_plan_snapshot_and_still_frozen_artifacts(self):
        # The plan-only evidence records its historical snapshot, not a ban on
        # the runtime implementation explicitly scheduled for Increment 3.44.
        for path, expected in self.contract["unchangedFiles"].items():
            original = subprocess.check_output(["git", "show", self.contract["preservedBase"] + ":" + path], cwd=ROOT)
            self.assertEqual(hashlib.sha256(original).hexdigest(), expected, path)
            if path.endswith(("capability_table.dart", "llm_runtime_stream_test.dart")):
                self.assertEqual((ROOT / path).read_bytes(), original, path)

    def test_prompt_suffix_has_one_unambiguous_json_encoding(self):
        line = next(line.strip() for line in self.text.splitlines() if line.startswith('    "\\n[portable-format-repair-v1]'))
        self.assertEqual(json.loads(line), self.contract["suffix"])
        self.assertTrue(self.contract["suffix"].endswith("\n"))
        self.assertNotIn("\r", self.contract["suffix"])

    def test_acceptance_checklist_is_distinct_from_runtime_results(self):
        cases = self.contract["plannedAcceptanceCases"]
        self.assertEqual(len(cases), len(set(cases)))
        for required in ["failed-and-repair-input-charge", "tool-json-not-free", "transport-no-retry", "fresh-approval-required", "no-third-attempt"]:
            self.assertIn(required, cases)
        for term in ["TOOL_SCHEMA_INVALID/truncated", "PLAN_INVALID/truncated-stream", "tokenizerEstimate", "CONTEXT_BUDGET_EXCEEDED", "approvalCommandId"]:
            self.assertIn(term, self.text)
        for link in re.findall(r"\]\(([^)]+)\)", self.text):
            if not link.startswith("https:"):
                self.assertTrue((SPEC / link.split("#")[0]).exists())


if __name__ == "__main__":
    unittest.main()
