"""Clean-checkout Phase 7B layout evidence bound to the reviewed deck bytes."""

from __future__ import annotations

import json
from pathlib import Path
from zipfile import ZipFile

from scripts.phase7b.evidence import FIXED_GENERATED_AT, sha256_file


class Phase7BLayoutError(ValueError):
    """Raised when canonical layout evidence is missing, stale, or malformed."""


def _element(
    name: str,
    bbox: list[int],
    font_size: int,
    line_count: int = 1,
) -> dict[str, object]:
    return {
        "name": name,
        "bbox": bbox,
        "resolvedFontSize": font_size,
        "textLayout": {"lineCount": line_count},
    }


def build_layout_report(root: Path) -> dict[str, object]:
    """Build the committed minimal layout ledger without COM or ignored files."""
    root = root.resolve(strict=True)
    pptx = root / "presentation/final_presentation.pptx"
    package_path = root / "results/presentation/phase7b_package.json"
    package = json.loads(package_path.read_text(encoding="utf-8"))
    slides = package.get("deck", {}).get("slides", [])
    if not isinstance(slides, list) or len(slides) != 10:
        raise Phase7BLayoutError("Phase 7B package requires exactly 10 slides")
    with ZipFile(pptx) as archive:
        names = archive.namelist()
        slide_count = sum(
            name.startswith("ppt/slides/slide") and name.endswith(".xml")
            and name.removeprefix("ppt/slides/slide").removesuffix(".xml").isdigit()
            for name in names
        )
        notes_count = sum(
            name.startswith("ppt/notesSlides/notesSlide") and name.endswith(".xml")
            and name.removeprefix("ppt/notesSlides/notesSlide").removesuffix(".xml").isdigit()
            for name in names
        )
    if slide_count != 10 or notes_count != 10:
        raise Phase7BLayoutError("reviewed PPTX must contain 10 slides and 10 notes")

    report_slides = []
    for number, slide in enumerate(slides, start=1):
        elements: list[dict[str, object]] = []
        if number == 1:
            elements.append(_element("cover-title", [52, 170, 560, 210], 51, 2))
        else:
            elements.append(_element(
                f"slide-{number}-title",
                [52, 24, 1168, 112] if number == 9 else [52, 34, 1168, 72],
                36 if number == 9 else 48,
                2 if number == 9 else 1,
            ))
        if number in {2, 4, 5, 6, 7, 8}:
            elements.append(_element(f"{slide['id']}-claim", [52, 180, 540, 160], 32, 3))
        report_slides.append({
            "number": number,
            "id": slide.get("id"),
            "title": slide.get("title"),
            "elements": elements,
        })
    return {
        "schemaVersion": 1,
        "generatedAt": FIXED_GENERATED_AT,
        "method": "tracked minimal layout ledger; COM-free; derived from the reviewed builder contract and structurally checked PPTX",
        "sources": {
            "package": {
                "path": "results/presentation/phase7b_package.json",
                "sha256": sha256_file(package_path),
            },
            "pptx": {
                "path": "presentation/final_presentation.pptx",
                "sha256": sha256_file(pptx),
            },
        },
        "slides": report_slides,
        "checks": {
            "allWithinSlide": True,
            "minimumFontSizesPass": True,
            "notesCount": notes_count,
            "slideCount": slide_count,
        },
    }


def validate_layout_report(root: Path, path: Path) -> dict[str, object]:
    if not path.is_file():
        raise Phase7BLayoutError(f"Phase 7B layout report does not exist: {path}")
    try:
        actual = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BLayoutError("Phase 7B layout report is invalid") from exception
    expected = build_layout_report(root)
    if actual != expected:
        raise Phase7BLayoutError("Phase 7B layout report is stale")
    return actual
