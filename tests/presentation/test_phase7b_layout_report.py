from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from scripts.phase7b.layout import Phase7BLayoutError, build_layout_report, validate_layout_report


ROOT = Path(__file__).resolve().parents[2]
CANONICAL = ROOT / "docs/presentation/phase7b_layout_report.json"


class Phase7BLayoutReportTests(unittest.TestCase):
    def test_canonical_report_matches_clean_checkout_ooxml_derivation(self) -> None:
        expected = build_layout_report(ROOT)
        actual = validate_layout_report(ROOT, CANONICAL)
        self.assertEqual(actual, expected)

    def test_missing_and_stale_source_hashes_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.json"
            with self.assertRaisesRegex(Phase7BLayoutError, "does not exist"):
                validate_layout_report(ROOT, missing)

            stale = json.loads(CANONICAL.read_text(encoding="utf-8"))
            stale["sources"]["pptx"]["sha256"] = "0" * 64
            stale_path = Path(directory) / "stale.json"
            stale_path.write_text(json.dumps(stale), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BLayoutError, "stale"):
                validate_layout_report(ROOT, stale_path)


if __name__ == "__main__":
    unittest.main()
