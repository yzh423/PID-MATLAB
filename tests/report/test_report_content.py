from __future__ import annotations

from pathlib import Path
import re
import unittest

from scripts.reporting.content import ContentError, load_references, validate_report


PROJECT_ROOT = Path(__file__).resolve().parents[2]
REFERENCES_PATH = PROJECT_ROOT / "docs/report/references.json"
REPORT_PATH = PROJECT_ROOT / "docs/report/technical_report.md"


class ReferenceTests(unittest.TestCase):
    def test_reference_bank_has_verified_contiguous_records(self) -> None:
        references = load_references(REFERENCES_PATH)

        self.assertEqual([reference.id for reference in references], list(range(1, 9)))
        self.assertEqual(references[0].doi, "10.1016/S0967-0661(01)00062-4")
        self.assertEqual(references[7].authors, "B. Zitkovich et al.")
        self.assertTrue(all(reference.supports for reference in references))

    def test_documentation_uses_official_https_urls(self) -> None:
        references = load_references(REFERENCES_PATH)
        documentation = [
            reference for reference in references if reference.source_type == "documentation"
        ]

        self.assertEqual(len(documentation), 2)
        self.assertTrue(
            all(
                reference.url.startswith("https://www.mathworks.com/")
                for reference in documentation
            )
        )

    def test_content_errors_are_reported_together(self) -> None:
        references = load_references(REFERENCES_PATH)

        with self.assertRaises(ContentError) as raised:
            validate_report(
                "# Abstract\n\nFuzzy-PID is universally superior and guarantees safety. [99]",
                references,
            )

        message = str(raised.exception)
        self.assertIn("missing required headings", message)
        self.assertIn("unknown citation IDs: 99", message)
        self.assertIn("prohibited scope claim", message)


class BuiltReportTests(unittest.TestCase):
    def test_resolved_report_passes_content_gate(self) -> None:
        self.assertTrue(REPORT_PATH.is_file(), "technical_report.md not built")
        validate_report(
            REPORT_PATH.read_text(encoding="utf-8"),
            load_references(REFERENCES_PATH),
        )

    def test_resolved_report_has_required_evidence_density(self) -> None:
        self.assertTrue(REPORT_PATH.is_file(), "technical_report.md not built")
        markdown = REPORT_PATH.read_text(encoding="utf-8")
        body = markdown.split("## References", maxsplit=1)[0]
        words = re.findall(r"[A-Za-z]+(?:[-'][A-Za-z]+)*", body)
        figures = re.findall(r"!\[[^\]]+\]\(([^)]+)\)", markdown)
        tables = re.findall(
            r"^\|(?:\s*:?-{3,}:?\s*\|)+$", markdown, flags=re.MULTILINE
        )

        self.assertGreaterEqual(len(words), 2800)
        self.assertLessEqual(len(words), 5500)
        self.assertEqual(
            figures,
            [
                "../../results/figures/nominal_pid_vs_fuzzy_tracking.png",
                "../../results/figures/pid_optimization_objective.png",
                "../../results/figures/deterministic_robustness_summary.png",
                "../../results/figures/stochastic_robustness_chattering.png",
                "../../results/figures/cartesian_tasks_paths.png",
                "../../results/figures/multibody_cross_validation_tracking.png",
            ],
        )
        self.assertGreaterEqual(len(tables), 7)
        self.assertNotIn("{{", markdown)
        self.assertNotIn("}}", markdown)
        for citation_id in range(1, 9):
            self.assertIn(f"[{citation_id}]", markdown)
        for statement in (
            "39 deterministic runs",
            "360 paired stochastic trials",
            "8/13, 9/13, and 10/13 deterministic successes",
            "0/30 combined-stress successes for every controller",
            "manual and Fuzzy-PID pick-transfer-place runs were unsuccessful",
            "145 tests",
            "not hardware validation",
        ):
            self.assertIn(statement, markdown)
        for unit in (" rad", " N m", " m", " s"):
            self.assertIn(unit, markdown)


if __name__ == "__main__":
    unittest.main()
