from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import unittest
from zipfile import ZipFile

from docx import Document


PROJECT_ROOT = Path(__file__).resolve().parents[2]
REPORT_DIR = PROJECT_ROOT / "docs/report"
DOCX_PATH = REPORT_DIR / "technical_report.docx"
MANIFEST_PATH = REPORT_DIR / "build_manifest.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class BuiltDocumentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not DOCX_PATH.is_file():
            raise AssertionError("technical_report.docx not built")
        cls.document = Document(DOCX_PATH)
        cls.text = "\n".join(paragraph.text for paragraph in cls.document.paragraphs)

    def test_page_geometry_and_typography(self) -> None:
        self.assertGreaterEqual(len(self.document.sections), 1)
        for section in self.document.sections:
            self.assertAlmostEqual(section.page_width.inches, 8.27, places=2)
            self.assertAlmostEqual(section.page_height.inches, 11.69, places=2)
            for margin in (
                section.top_margin,
                section.bottom_margin,
                section.left_margin,
                section.right_margin,
            ):
                self.assertGreaterEqual(margin.inches, 0.65)
                self.assertLessEqual(margin.inches, 0.85)

        normal_size = self.document.styles["Normal"].font.size
        caption_size = self.document.styles["Caption"].font.size
        self.assertIsNotNone(normal_size)
        self.assertIsNotNone(caption_size)
        self.assertGreaterEqual(normal_size.pt, 9.5)
        self.assertGreaterEqual(caption_size.pt, 8.0)

    def test_required_structure_and_metadata(self) -> None:
        self.assertIn("Reliable Robotic Manipulation", self.text)
        self.assertIn("Technical report — Phase 7A", self.text)
        self.assertIn("PID vs Fuzzy PID for a two-link robotic manipulator", self.text)
        for heading in (
            "Abstract",
            "Introduction and Research Context",
            "Problem Formulation",
            "System Model",
            "Controller Design and Tuning",
            "Experimental Design",
            "Results",
            "Independent Model Validation",
            "Discussion",
            "Embodied-AI Execution Context",
            "Limitations and Future Work",
            "Conclusion",
            "References",
        ):
            self.assertIn(heading, self.text)
        self.assertNotIn("{{", self.text)
        self.assertNotIn("}}", self.text)

    def test_images_tables_and_captions_are_complete(self) -> None:
        self.assertGreaterEqual(len(self.document.inline_shapes), 6)
        self.assertGreaterEqual(len(self.document.tables), 7)

        figure_numbers = []
        table_numbers = []
        for paragraph in self.document.paragraphs:
            if match := re.match(r"Figure (\d+)\.", paragraph.text):
                figure_numbers.append(int(match.group(1)))
            if match := re.match(r"Table (\d+)\.", paragraph.text):
                table_numbers.append(int(match.group(1)))
        self.assertEqual(figure_numbers, list(range(1, len(figure_numbers) + 1)))
        self.assertEqual(table_numbers, list(range(1, len(table_numbers) + 1)))
        self.assertEqual(len(figure_numbers), 6)
        self.assertGreaterEqual(len(table_numbers), 7)

        with ZipFile(DOCX_PATH) as archive:
            relationships = archive.read("word/_rels/document.xml.rels").decode("utf-8")
        image_relationships = re.findall(r'<Relationship[^>]+Type="[^"]+/image"[^>]*/>', relationships)
        self.assertGreaterEqual(len(image_relationships), 6)
        self.assertTrue(all('TargetMode="External"' not in item for item in image_relationships))

    def test_references_are_numbered_and_complete(self) -> None:
        for citation_id in range(1, 9):
            self.assertRegex(self.text, rf"(?m)^\[{citation_id}\] ")

    def test_manifest_hashes_current_inputs_and_outputs(self) -> None:
        self.assertTrue(MANIFEST_PATH.is_file(), "build_manifest.json not built")
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(len(manifest["selectedFigures"]), 6)
        self.assertGreater(len(manifest["usedEvidenceTokens"]), 0)
        for group in ("sources", "outputs"):
            self.assertGreater(len(manifest[group]), 0)
            for record in manifest[group]:
                path = PROJECT_ROOT / record["path"]
                self.assertTrue(path.is_file(), record["path"])
                self.assertEqual(record["sha256"], sha256(path), record["path"])


if __name__ == "__main__":
    unittest.main()
