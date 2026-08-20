from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from scripts.phase7b.evidence import (
    Phase7BEvidenceError,
    build_phase7b_package,
    load_phase7b_template,
)


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/presentation/phase7b_template.json"


class Phase7BEvidenceTests(unittest.TestCase):
    def test_template_has_frozen_shape(self) -> None:
        template = load_phase7b_template(TEMPLATE)
        self.assertEqual(template["schemaVersion"], 1)
        self.assertEqual(len(template["deck"]["slides"]), 10)
        self.assertEqual(template["deck"]["slides"][0]["id"], "opening")
        self.assertEqual(template["deck"]["slides"][-1]["id"], "next-steps")
        self.assertIn("summary", template)

    def test_package_resolves_required_claims_and_failures(self) -> None:
        package = build_phase7b_package(ROOT)
        text = json.dumps(package, ensure_ascii=False)
        for claim in ("8/13", "9/13", "10/13", "30/30", "0/30", "7.283%"):
            self.assertIn(claim, text)
        self.assertIn("simulation", text.lower())
        self.assertNotIn("{{", text)
        self.assertNotIn("}}", text)

    def test_missing_figure_is_rejected(self) -> None:
        package = build_phase7b_package(ROOT)
        figure = ROOT / package["selectedFigures"][0]["path"]
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            (fake_root / "docs/presentation").mkdir(parents=True)
            (fake_root / "docs/presentation/phase7b_template.json").write_text(
                TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            with self.assertRaisesRegex(Phase7BEvidenceError, "Phase 7A"):
                build_phase7b_package(fake_root)

    def test_sources_and_notes_are_complete(self) -> None:
        package = build_phase7b_package(ROOT)
        for slide in package["deck"]["slides"]:
            self.assertGreaterEqual(len(slide["sources"]), 1, slide["id"])
            self.assertTrue(all(source.startswith(("docs/", "results/")) for source in slide["sources"]))
        self.assertEqual(package["generatedAt"], "2026-08-21T00:00:00Z")


if __name__ == "__main__":
    unittest.main()
