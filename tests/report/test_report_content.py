from __future__ import annotations

from pathlib import Path
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
    @classmethod
    def setUpClass(cls) -> None:
        if not REPORT_PATH.is_file():
            raise unittest.SkipTest("technical_report.md not built")

    def test_resolved_report_passes_content_gate(self) -> None:
        validate_report(
            REPORT_PATH.read_text(encoding="utf-8"),
            load_references(REFERENCES_PATH),
        )


if __name__ == "__main__":
    unittest.main()
