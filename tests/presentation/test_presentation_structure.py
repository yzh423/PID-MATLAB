from __future__ import annotations

from pathlib import Path
import json
import re
import unittest
from xml.etree import ElementTree
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
PPTX = ROOT / "presentation" / "final_presentation.pptx"
PACKAGE = ROOT / "results" / "presentation" / "phase7b_package.json"
LAYOUT_REPORT = ROOT / "docs" / "presentation" / "phase7b_layout_report.json"


def xml_text(payload: bytes) -> str:
    return " ".join(ElementTree.fromstring(payload).itertext())


def pptx_text(pptx: Path) -> str:
    with ZipFile(pptx) as archive:
        return "\n".join(
            xml_text(archive.read(name))
            for name in archive.namelist()
            if name.endswith(".xml")
        )


def layout_element(slide_number: int, name: str) -> dict[str, object]:
    with LAYOUT_REPORT.open(encoding="utf-8") as layout_file:
        layout = json.load(layout_file)
    slide = next(slide for slide in layout["slides"] if slide["number"] == slide_number)
    return next(element for element in slide["elements"] if element.get("name") == name)


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

    def test_stress_slides_note_their_row_level_csv_evidence(self) -> None:
        with ZipFile(PPTX) as archive:
            deterministic_notes = xml_text(archive.read("ppt/notesSlides/notesSlide5.xml"))
            stochastic_notes = xml_text(archive.read("ppt/notesSlides/notesSlide6.xml"))
        self.assertIn("results/data/deterministic_robustness_runs.csv", deterministic_notes)
        self.assertIn("results/data/stochastic_robustness_trials.csv", stochastic_notes)

    def test_deck_contains_contract_claims_and_no_placeholders(self) -> None:
        self.assertTrue(PPTX.is_file())
        text = pptx_text(PPTX)
        for value in ("7.283%", "8/13", "9/13", "10/13", "30/30", "0/30"):
            self.assertIn(value, text)
        for forbidden in ("{{", "}}", "Lorem ipsum", "Title here", "placeholder"):
            self.assertNotIn(forbidden, text)

    def test_deck_names_every_deterministic_stress_category(self) -> None:
        text = pptx_text(PPTX)
        self.assertIn(
            "39 controller-scenario runs across nominal, payload, configuration, uncertainty, disturbance, actuator, and combined conditions.",
            text,
        )

    def test_deck_describes_nominal_metrics_as_mixed(self) -> None:
        text = pptx_text(PPTX)
        self.assertIn(
            "Nominal metrics are mixed across manual PID and Fuzzy-PID; "
            "optimized PID provides the best aggregate deterministic and Cartesian reliability, "
            "with a torque-slew trade-off under noise.",
            text,
        )

    def test_powerpoint_qa_copy_avoids_observed_clipping_and_title_collision(self) -> None:
        text = pptx_text(PPTX)
        self.assertIn(
            "Study: 360 trials (4 scenarios x 3 controllers x 30 fixed seeds).",
            text,
        )
        self.assertNotIn("The full study contains 360 trials:", text)
        self.assertIn(
            "Validated layer supports the next research step",
            text,
        )

        closing_title = layout_element(10, "slide-10-title")
        self.assertGreaterEqual(closing_title["resolvedFontSize"], 35)

    def test_resolved_title_and_claims_meet_layout_thresholds(self) -> None:
        title = layout_element(9, "slide-9-title")
        self.assertGreaterEqual(title["resolvedFontSize"], 35)
        self.assertLessEqual(title["textLayout"]["lineCount"], 2)

        for slide_number, name in (
            (2, "problem-claim"),
            (4, "optimization-claim"),
            (7, "cartesian-claim"),
        ):
            claim = layout_element(slide_number, name)
            self.assertGreaterEqual(claim["resolvedFontSize"], 24, name)

            title = layout_element(slide_number, f"slide-{slide_number}-title")
            title_bottom = title["bbox"][1] + title["bbox"][3]
            self.assertGreaterEqual(claim["bbox"][1] - title_bottom, 72, name)

    def test_canonical_layout_report_is_bound_to_current_pptx_and_package(self) -> None:
        from scripts.phase7b.evidence import sha256_file

        report = json.loads(LAYOUT_REPORT.read_text(encoding="utf-8"))
        self.assertEqual(report["schemaVersion"], 1)
        self.assertEqual(report["generatedAt"], "2026-08-21T00:00:00Z")
        self.assertEqual(report["sources"], {
            "package": {
                "path": "results/presentation/phase7b_package.json",
                "sha256": sha256_file(PACKAGE),
            },
            "pptx": {
                "path": "presentation/final_presentation.pptx",
                "sha256": sha256_file(PPTX),
            },
        })
        self.assertEqual(len(report["slides"]), 10)
        self.assertTrue(report["checks"]["allWithinSlide"])
        self.assertTrue(report["checks"]["minimumFontSizesPass"])
        self.assertIn("OOXML", report["method"])
        self.assertGreaterEqual(
            sum(len(slide["elements"]) for slide in report["slides"]),
            40,
            "the report must inventory actual slide elements rather than a hand-picked ledger",
        )
        for slide in report["slides"]:
            for element in slide["elements"]:
                self.assertIn("geometryEmu", element)
                self.assertIn("withinSlide", element)
                if "textLayout" in element:
                    self.assertIn("wrapMode", element["textLayout"])
                    self.assertIn("overflowGuard", element["textLayout"])


if __name__ == "__main__":
    unittest.main()
