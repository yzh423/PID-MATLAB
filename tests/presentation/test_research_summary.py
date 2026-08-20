from __future__ import annotations

from pathlib import Path
import unittest

from docx import Document
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[2]
DOCX = ROOT / "docs" / "summary" / "research_summary.docx"
PDF = ROOT / "docs" / "summary" / "research_summary.pdf"


class ResearchSummaryTests(unittest.TestCase):
    def test_docx_is_one_page_ready_and_contains_required_claims(self) -> None:
        document = Document(DOCX)
        self.assertEqual(len(document.sections), 1)
        section = document.sections[0]
        self.assertAlmostEqual(section.page_width.inches, 8.5, places=2)
        self.assertAlmostEqual(section.page_height.inches, 11.0, places=2)
        self.assertEqual(len(document.inline_shapes), 1)
        text = "\n".join(paragraph.text for paragraph in document.paragraphs)
        for value in ("7.283%", "10/13", "30/30", "0/30"):
            self.assertIn(value, text)
        self.assertIn("Simulation scope", text)
        self.assertNotIn("{{", text)

    def test_pdf_is_exactly_one_page(self) -> None:
        reader = PdfReader(PDF)
        self.assertEqual(len(reader.pages), 1)
        text = reader.pages[0].extract_text() or ""
        self.assertIn("Reliable Robotic Manipulation", text)
        self.assertIn("Limitations and next steps", text)


if __name__ == "__main__":
    unittest.main()
