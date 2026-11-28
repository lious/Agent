"""Documentation consistency only; NOT product/device/model qualification."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MilestoneDocumentationTest(unittest.TestCase):
    def setUp(self):
        self.mapping = json.loads((ROOT / "docs/implementation/evidence/ios-milestone-crosswalk/mapping.json").read_text())

    def test_frozen_table_is_unchanged_and_internal_labels_exist(self):
        table = (ROOT / self.mapping["repositoryTable"]).read_bytes()
        self.assertEqual(hashlib.sha256(table).hexdigest(), self.mapping["repositoryTableSha256"])
        ids = re.findall(r"id: '([^']+)'", table.decode())
        for row in self.mapping["rows"]:
            self.assertIn(row["internalPortableSlice"], ids)

    def test_same_numbers_are_not_equivalent_or_completion_evidence(self):
        self.assertFalse(self.mapping["productQualification"])
        self.assertEqual(self.mapping["kind"], "documentationCrosswalk")
        expected = [
            ("N1-interfaces", "N1", "Real local editing loop"),
            ("N2-llamacpp-binding", "N2", "Reliability and model lifecycle"),
            ("N3-harness-tools", "N3", "Release foundations and image enhancement"),
            ("N4-on-device-inference", "N4", "Video C1"),
            ("N5-ios-packaging", "N5", "ASR and advanced C2"),
            ("N6-device-qualification", "N6", "Independent research"),
        ]
        actual = [(r["internalPortableSlice"], r["originalPageMilestone"], r["originalPageTitle"]) for r in self.mapping["rows"]]
        self.assertEqual(actual, expected)
        for row in self.mapping["rows"]:
            self.assertFalse(row["equivalent"])
            self.assertFalse(row["originalPageCompletionEstablished"])

    def test_crosswalk_is_linked_and_clearly_bounded(self):
        adr = (ROOT / "docs/adr/0241-ios-milestone-label-crosswalk.md").read_text()
        self.assertIn("mapping.json", adr)
        self.assertIn("NOT new product tests", adr)
        self.assertIn("does not establish original-Page N1/N3 completion", adr)
        self.assertEqual(self.mapping["originalSection"], "native-milestones")


if __name__ == "__main__":
    unittest.main()
