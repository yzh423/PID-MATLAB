from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

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

    def _stage_root(self, directory: str) -> Path:
        root = Path(directory)
        pptx = root / "presentation/final_presentation.pptx"
        package = root / "results/presentation/phase7b_package.json"
        pptx.parent.mkdir(parents=True)
        package.parent.mkdir(parents=True)
        shutil.copy2(ROOT / "presentation/final_presentation.pptx", pptx)
        shutil.copy2(ROOT / "results/presentation/phase7b_package.json", package)
        return root

    def _rewrite_slide(self, pptx: Path, slide_name: str, mutate) -> None:
        with ZipFile(pptx) as archive:
            entries = [(info, archive.read(info.filename)) for info in archive.infolist()]
        temporary = pptx.with_suffix(".tmp.pptx")
        with ZipFile(temporary, "w", compression=ZIP_DEFLATED) as archive:
            for info, payload in entries:
                if info.filename == slide_name:
                    payload = mutate(payload)
                clone = ZipInfo(info.filename, info.date_time)
                clone.compress_type = info.compress_type
                clone.external_attr = info.external_attr
                archive.writestr(clone, payload)
        temporary.replace(pptx)

    def test_lowered_real_title_font_fails_the_report_gate(self) -> None:
        namespaces = {
            "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
            "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
        }

        def lower_title(payload: bytes) -> bytes:
            root = ElementTree.fromstring(payload)
            title = next(
                shape for shape in root.findall(".//p:sp", namespaces)
                if shape.find("p:nvSpPr/p:cNvPr", namespaces).get("name") == "slide-9-title"
            )
            for properties in title.findall(".//a:rPr", namespaces) + title.findall(".//a:defRPr", namespaces):
                properties.set("sz", "2000")
            return ElementTree.tostring(root, encoding="utf-8", xml_declaration=True)

        with tempfile.TemporaryDirectory() as directory:
            root = self._stage_root(directory)
            self._rewrite_slide(
                root / "presentation/final_presentation.pptx",
                "ppt/slides/slide9.xml",
                lower_title,
            )
            report = build_layout_report(root)
            title = next(
                element for element in report["slides"][8]["elements"]
                if element["name"] == "slide-9-title"
            )
            self.assertEqual(title["resolvedFontSize"], 20)
            self.assertFalse(title["minimumFontSizePass"])
            self.assertFalse(report["checks"]["minimumFontSizesPass"])

    def test_corrupt_slide_xml_fails_closed_instead_of_reporting_pass(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self._stage_root(directory)
            self._rewrite_slide(
                root / "presentation/final_presentation.pptx",
                "ppt/slides/slide1.xml",
                lambda _: b"<not-a-presentation-slide/>",
            )
            with self.assertRaisesRegex(Phase7BLayoutError, "slide1|slide XML"):
                build_layout_report(root)


if __name__ == "__main__":
    unittest.main()
