"""Create a one-page PDF counterpart of the admitted Phase 7B summary."""

from __future__ import annotations

import argparse
import json
from collections.abc import Mapping, Sequence
from pathlib import Path
import sys

from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab import rl_config
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.phase7b.summary import SummaryBuildError, _require_summary


ARIAL_REGULAR = Path("C:/Windows/Fonts/arial.ttf")
ARIAL_BOLD = Path("C:/Windows/Fonts/arialbd.ttf")
BUNDLED_DEPENDENCIES = Path(sys.executable).resolve().parents[1]
LIBERATION_REGULAR = BUNDLED_DEPENDENCIES / "node/node_modules/pdfjs-dist/standard_fonts/LiberationSans-Regular.ttf"
LIBERATION_BOLD = BUNDLED_DEPENDENCIES / "node/node_modules/pdfjs-dist/standard_fonts/LiberationSans-Bold.ttf"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def _style(name: str, *, size: float, leading: float, color: str = "#000000", bold: bool = False, alignment: int = 0, before: float = 0, after: float = 0) -> ParagraphStyle:
    return ParagraphStyle(
        name,
        fontName="ResearchSummaryArial-Bold" if bold else "ResearchSummaryArial",
        fontSize=size,
        leading=leading,
        textColor=HexColor(color),
        alignment=alignment,
        spaceBefore=before,
        spaceAfter=after,
    )


def _register_embedded_fonts() -> None:
    """Embed Arial when available, with an Arial-compatible bundled fallback."""
    regular, bold = (ARIAL_REGULAR, ARIAL_BOLD)
    if not regular.is_file() or not bold.is_file():
        regular, bold = (LIBERATION_REGULAR, LIBERATION_BOLD)
    if not regular.is_file() or not bold.is_file():
        raise SummaryBuildError("an embeddable Arial-compatible font is required for the PDF fallback")
    if "ResearchSummaryArial" not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont("ResearchSummaryArial", str(regular)))
        pdfmetrics.registerFont(TTFont("ResearchSummaryArial-Bold", str(bold)))


def build_pdf(root: Path, output: Path) -> None:
    root = root.resolve(strict=True)
    package = json.loads((root / "results/presentation/phase7b_package.json").read_text(encoding="utf-8"))
    if not isinstance(package, Mapping):
        raise SummaryBuildError("Phase 7B package root must be an object")
    summary = _require_summary(package)
    if "{{" in "\n".join(str(value) for value in summary.values()):
        raise SummaryBuildError("Phase 7B package must resolve all content tokens")
    figure = root / str(summary["figure"])
    if not figure.is_file():
        raise SummaryBuildError(f"admitted summary figure does not exist: {figure}")

    rl_config.invariant = 1
    _register_embedded_fonts()

    label = _style("label", size=8.5, leading=10, color="#1F4E79", bold=True, after=1)
    title = _style("title", size=17.5, leading=20.5, bold=True, after=2)
    takeaway = _style("takeaway", size=10.5, leading=12.5, color="#525960", after=4)
    heading = _style("heading", size=10.5, leading=12, color="#1F4E79", bold=True, before=3, after=1)
    body = _style("body", size=10.25, leading=11.8, after=3)
    snapshot = _style("snapshot", size=7.7, leading=9, color="#525960", after=2)
    result_value = _style("result_value", size=13.5, leading=15.5, color="#1F4E79", bold=True, alignment=TA_CENTER)
    result_label = _style("result_label", size=7.5, leading=8.7, color="#525960", alignment=TA_CENTER)
    caption = _style("caption", size=7.8, leading=9, color="#525960", alignment=TA_CENTER, after=2)
    source = _style("source", size=7.0, leading=8.1, color="#525960", before=2)

    document = SimpleDocTemplate(
        str(output), pagesize=letter,
        leftMargin=0.6 * inch, rightMargin=0.6 * inch,
        topMargin=0.55 * inch, bottomMargin=0.55 * inch,
        title=str(summary["title"]), author="PID vs Fuzzy PID project",
    )
    story: list[object] = [
        Paragraph("RESEARCH SUMMARY | PHASE 7B", label),
        Paragraph(str(summary["title"]), title),
        Paragraph(str(summary["takeaway"]), takeaway),
        Paragraph("Problem and research question", heading),
        Paragraph(str(summary["problem"]), body),
        Paragraph("Method", heading),
        Paragraph(str(summary["method"]), body),
        Paragraph("Key results", heading),
    ]
    results = summary["results"]
    if not isinstance(results, list) or len(results) != 3 or not all(isinstance(result, Mapping) for result in results):
        raise SummaryBuildError("summary requires exactly three result records")
    story.append(Paragraph("Evidence snapshot: " + "; ".join(f"{result['value']} {result['label']}" for result in results), snapshot))
    table = Table(
        [[
            [Paragraph(str(result["value"]), result_value), Paragraph(str(result["label"]), result_label)]
            for result in results
        ]],
        colWidths=[(7.3 * inch) / 3] * 3,
        hAlign="LEFT",
    )
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#E8EEF5")),
        ("BOX", (0, 0), (-1, -1), 0.25, HexColor("#D4DDE8")),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, HexColor("#D4DDE8")),
        ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.extend([
        table,
        Spacer(1, 18),
        Image(str(figure), width=5.0 * inch, height=(5.0 * inch) / (1825 / 1171), hAlign="CENTER"),
        Paragraph(f"Figure. {summary['figureCaption']}", caption),
        Paragraph("Why this matters", heading),
        Paragraph(str(summary["significance"]), body),
        Paragraph("Simulation scope", heading),
        Paragraph(str(summary["limitations"]), body),
        Paragraph("Limitations and next steps", heading),
        Paragraph(str(summary["nextSteps"]), body),
        Paragraph("Sources: " + " | ".join(str(source_path) for source_path in summary["sources"]), source),
    ])
    document.build(story)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        root = args.project_root.resolve(strict=True)
        output = args.output if args.output.is_absolute() else root / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        build_pdf(root, output)
    except (OSError, UnicodeError, ValueError, SummaryBuildError) as exception:
        print(f"Research summary PDF build failed: {exception}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
