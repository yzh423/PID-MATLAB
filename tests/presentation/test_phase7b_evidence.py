from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.phase7b.evidence import (
    Phase7BEvidenceError,
    build_phase7b_package,
    load_phase7b_template,
    sha256_file,
    write_phase7b_package,
)


ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/presentation/phase7b_template.json"
MANIFEST = ROOT / "docs/report/build_manifest.json"
EVIDENCE = ROOT / "results/report/report_evidence.json"
PACKAGE = ROOT / "results/presentation/phase7b_package.json"


def stage_phase7a_fixture(root: Path) -> None:
    """Create a valid, independently mutable Phase 7A package fixture."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for record in [*manifest["sources"], *manifest.get("outputs", [])]:
        source = ROOT / record["path"]
        destination = root / record["path"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    template = root / "docs/presentation/phase7b_template.json"
    template.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(TEMPLATE, template)
    manifest_path = root / "docs/report/build_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(MANIFEST, manifest_path)


def leaf_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in leaf_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in leaf_strings(item)]
    return []


class Phase7BEvidenceTests(unittest.TestCase):
    def test_template_has_frozen_shape(self) -> None:
        template = load_phase7b_template(TEMPLATE)
        self.assertEqual(template["schemaVersion"], 1)
        self.assertEqual(len(template["deck"]["slides"]), 10)
        self.assertEqual(template["deck"]["slides"][0]["id"], "opening")
        self.assertEqual(template["deck"]["slides"][-1]["id"], "next-steps")
        self.assertIn("summary", template)

    def test_template_makes_claim_boundaries_explicit(self) -> None:
        template = load_phase7b_template(TEMPLATE)
        deterministic = template["deck"]["slides"][4]
        self.assertIn(
            "nominal, payload, configuration, uncertainty, disturbance, actuator, and combined",
            deterministic["body"][0],
        )
        self.assertIn(
            "results/data/deterministic_robustness_runs.csv",
            deterministic["sources"],
        )
        stochastic = template["deck"]["slides"][5]
        self.assertIn(
            "results/data/stochastic_robustness_trials.csv",
            stochastic["sources"],
        )
        conclusion = template["deck"]["slides"][8]
        self.assertEqual(
            conclusion["interpretation"],
            "Nominal metrics are mixed across manual PID and Fuzzy-PID; "
            "optimized PID provides the best aggregate deterministic and Cartesian reliability, "
            "with a torque-slew trade-off under noise.",
        )
        summary = template["summary"]
        self.assertEqual(
            summary["sources"],
            [
                "docs/report/technical_report.md",
                "results/report/report_evidence.json",
                "docs/report/build_manifest.json",
            ],
        )
        self.assertEqual(summary["results"][1]["label"], "optimized PID deterministic scenarios passed")
        self.assertEqual(
            summary["results"][2]["label"],
            "per controller-scenario cell: isolated-noise cell vs full-combined-stress cell",
        )

    def test_package_has_exact_schema_resolved_tokens_and_source_hashes(self) -> None:
        package = build_phase7b_package(ROOT)
        self.assertEqual(
            set(package),
            {
                "schemaVersion",
                "generatedAt",
                "deck",
                "summary",
                "selectedFigures",
                "usedEvidenceTokens",
                "phase7aSourceHashes",
            },
        )
        self.assertEqual(package["schemaVersion"], 1)
        self.assertEqual(package["generatedAt"], "2026-08-21T00:00:00Z")
        self.assertEqual(len(package["deck"]["slides"]), 10)
        self.assertEqual(
            set(package["summary"]),
            {
                "title", "takeaway", "problem", "method", "results", "figure",
                "figureCaption", "significance", "limitations", "nextSteps", "sources",
            },
        )
        text = json.dumps(package, ensure_ascii=False)
        for claim in ("8/13", "9/13", "10/13", "30/30", "0/30", "4 of 6", "0.001 s", "7.283%"):
            self.assertIn(claim, text)
        self.assertIn("simulation", text.lower())
        self.assertTrue(
            all("{{" not in item and "}}" not in item for item in leaf_strings(package))
        )
        source_hashes = package["phase7aSourceHashes"]
        self.assertEqual(set(source_hashes), {"manifest", "evidence", "sources"})
        self.assertEqual(source_hashes["manifest"], {
            "path": "docs/report/build_manifest.json", "sha256": sha256_file(MANIFEST),
        })
        self.assertEqual(source_hashes["evidence"], {
            "path": "results/report/report_evidence.json", "sha256": sha256_file(EVIDENCE),
        })
        self.assertEqual(len(source_hashes["sources"]), 9)
        self.assertEqual(len(package["selectedFigures"]), 6)
        self.assertEqual(package["summary"]["figure"], "results/figures/deterministic_robustness_summary.png")
        self.assertEqual(
            package["summary"]["sources"][-1],
            source_hashes["manifest"]["path"],
        )

    def test_current_exported_package_matches_current_template_resolution(self) -> None:
        self.assertEqual(
            json.loads(PACKAGE.read_text(encoding="utf-8")),
            build_phase7b_package(ROOT),
        )

    def test_changed_evidence_hash_is_rejected_before_claim_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            stage_phase7a_fixture(fake_root)
            evidence_path = fake_root / "results/report/report_evidence.json"
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            evidence["optimization"]["objectiveReductionPercent"] = 999.0
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "evidence hash mismatch"):
                build_phase7b_package(fake_root)

    def test_missing_or_changed_slide_figure_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            stage_phase7a_fixture(fake_root)
            figure = fake_root / "results/figures/nominal_pid_vs_fuzzy_tracking.png"
            figure.write_bytes(figure.read_bytes() + b"tampered")
            with self.assertRaisesRegex(Phase7BEvidenceError, "figure hash mismatch"):
                build_phase7b_package(fake_root)

            stage_phase7a_fixture(fake_root)
            figure.unlink()
            with self.assertRaisesRegex(Phase7BEvidenceError, "Phase 7A source"):
                build_phase7b_package(fake_root)

    def test_unadmitted_summary_figure_is_rejected_and_figures_are_deduplicated(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            stage_phase7a_fixture(fake_root)
            template_path = fake_root / "docs/presentation/phase7b_template.json"
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["summary"]["figure"] = "results/data/unadmitted.mat"
            template_path.write_text(json.dumps(template), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "not admitted"):
                build_phase7b_package(fake_root)

        package = build_phase7b_package(ROOT)
        paths = [record["path"] for record in package["selectedFigures"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertIn(package["summary"]["figure"], paths)

    def test_invalid_template_schema_or_summary_shape_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            stage_phase7a_fixture(fake_root)
            template_path = fake_root / "docs/presentation/phase7b_template.json"
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["schemaVersion"] = 2
            template_path.write_text(json.dumps(template), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "schemaVersion"):
                build_phase7b_package(fake_root)

            template["schemaVersion"] = 1
            del template["summary"]["figure"]
            template_path.write_text(json.dumps(template), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "summary"):
                build_phase7b_package(fake_root)

            template = json.loads(TEMPLATE.read_text(encoding="utf-8"))
            template["summary"]["results"] = "not a result list"
            template_path.write_text(json.dumps(template), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "summary"):
                build_phase7b_package(fake_root)

    def test_summary_source_must_be_phase7a_admitted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            stage_phase7a_fixture(fake_root)
            template_path = fake_root / "docs/presentation/phase7b_template.json"
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["summary"]["sources"][-1] = "docs/report/PAPER_CLAIM_AUDIT.md"
            template_path.write_text(json.dumps(template), encoding="utf-8")
            with self.assertRaisesRegex(Phase7BEvidenceError, "summary source is not admitted"):
                build_phase7b_package(fake_root)

    def test_write_is_deterministic_and_atomically_replaces_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "nested/phase7b_package.json"
            output.parent.mkdir(parents=True)
            output.write_text("previous output", encoding="utf-8")
            first = write_phase7b_package(ROOT, output)
            first_hash = sha256_file(output)
            second = write_phase7b_package(ROOT, output)
            self.assertEqual(first, second)
            self.assertEqual(first_hash, sha256_file(output))
            self.assertEqual(json.loads(output.read_text(encoding="utf-8")), second)
            self.assertEqual(list(output.parent.glob("*.tmp")), [])

    def test_sources_and_notes_are_complete(self) -> None:
        package = build_phase7b_package(ROOT)
        for slide in package["deck"]["slides"]:
            self.assertGreaterEqual(len(slide["sources"]), 1, slide["id"])
            self.assertTrue(all(source.startswith(("docs/", "results/")) for source in slide["sources"]))
        self.assertEqual(package["generatedAt"], "2026-08-21T00:00:00Z")


if __name__ == "__main__":
    unittest.main()
