from __future__ import annotations

from pathlib import Path
import re
import unittest
from xml.etree import ElementTree
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
PPTX = ROOT / "presentation" / "final_presentation.pptx"


def xml_text(payload: bytes) -> str:
    return " ".join(ElementTree.fromstring(payload).itertext())


def pptx_text(pptx: Path) -> str:
    with ZipFile(pptx) as archive:
        return "\n".join(
            xml_text(archive.read(name))
            for name in archive.namelist()
            if name.endswith(".xml")
        )


class PresentationStructureTests(unittest.TestCase):
    def test_final_deck_has_ten_slides_and_source_notes(self) -> None:
        self.assertTrue(PPTX.is_file())
        with ZipFile(PPTX) as archive:
            slides = sorted(
                name
                for name in archive.namelist()
                if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)
            )
            notes = sorted(
                name
                for name in archive.namelist()
                if re.fullmatch(r"ppt/notesSlides/notesSlide\d+\.xml", name)
            )
            self.assertEqual(len(slides), 10)
            self.assertEqual(len(notes), 10)
            for name in notes:
                self.assertIn("[Sources]", xml_text(archive.read(name)))

    def test_deck_contains_contract_claims_and_no_placeholders(self) -> None:
        self.assertTrue(PPTX.is_file())
        text = pptx_text(PPTX)
        for value in ("7.283%", "8/13", "9/13", "10/13", "30/30", "0/30"):
            self.assertIn(value, text)
        for forbidden in ("{{", "}}", "Lorem ipsum", "Title here", "placeholder"):
            self.assertNotIn(forbidden, text)


if __name__ == "__main__":
    unittest.main()
