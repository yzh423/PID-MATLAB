"""Clean-checkout Phase 7B layout evidence derived from final PPTX OOXML."""

from __future__ import annotations

import json
from pathlib import Path
import re
from xml.etree import ElementTree
from zipfile import BadZipFile, ZipFile

from scripts.phase7b.evidence import FIXED_GENERATED_AT, sha256_file


PRESENTATION_NS = "http://schemas.openxmlformats.org/presentationml/2006/main"
DRAWING_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS = {"p": PRESENTATION_NS, "a": DRAWING_NS}
EXPECTED_SLIDES = 10
OUTPUT_WIDTH = 1280
OUTPUT_HEIGHT = 720


class Phase7BLayoutError(ValueError):
    """Raised when canonical layout evidence is missing, stale, or malformed."""


def _integer(element: ElementTree.Element | None, attribute: str, label: str) -> int:
    if element is None:
        raise Phase7BLayoutError(f"PPTX OOXML is missing {label}")
    try:
        return int(element.attrib[attribute])
    except (KeyError, TypeError, ValueError) as exception:
        raise Phase7BLayoutError(f"PPTX OOXML has invalid {label}") from exception


def _geometry(transform, slide_width: int, slide_height: int, label: str):
    if transform is None:
        raise Phase7BLayoutError(f"PPTX OOXML is missing {label} geometry")
    offset, extent = transform.find("a:off", NS), transform.find("a:ext", NS)
    x, y = _integer(offset, "x", f"{label} x"), _integer(offset, "y", f"{label} y")
    width = _integer(extent, "cx", f"{label} width")
    height = _integer(extent, "cy", f"{label} height")
    if width < 0 or height < 0:
        raise Phase7BLayoutError(f"PPTX OOXML has negative {label} extent")
    geometry = {"x": x, "y": y, "width": width, "height": height}
    scaled = (
        x * OUTPUT_WIDTH / slide_width, y * OUTPUT_HEIGHT / slide_height,
        width * OUTPUT_WIDTH / slide_width, height * OUTPUT_HEIGHT / slide_height,
    )
    bbox = [int(round(v)) if abs(v - round(v)) < 1e-9 else round(v, 4) for v in scaled]
    within = x >= 0 and y >= 0 and x + width <= slide_width and y + height <= slide_height
    return geometry, bbox, within


def _minimum_font_size(name: str) -> int:
    if name == "cover-title":
        return 50
    if re.fullmatch(r"slide-\d+-title", name):
        return 35
    if name.endswith(("-claim", "-lead")) or re.search(r"-metric-\d+$", name):
        return 24
    return 16


def _text_layout(shape, within_slide: bool, label: str) -> dict[str, object]:
    body = shape.find("p:txBody", NS)
    if body is None:
        raise Phase7BLayoutError(f"PPTX OOXML text shape is missing text body: {label}")
    paragraphs = body.findall("a:p", NS)
    texts = ["".join(node.text or "" for node in paragraph.findall(".//a:t", NS)) for paragraph in paragraphs]
    properties = body.find("a:bodyPr", NS)
    if properties is None:
        raise Phase7BLayoutError(f"PPTX OOXML text shape is missing body properties: {label}")
    normal = properties.find("a:normAutofit", NS)
    if normal is not None:
        auto_fit, font_scale = "normAutofit", _integer(normal, "fontScale", f"{label} font scale")
    elif properties.find("a:spAutoFit", NS) is not None:
        auto_fit, font_scale = "spAutoFit", None
    elif properties.find("a:noAutofit", NS) is not None:
        auto_fit, font_scale = "noAutofit", None
    else:
        auto_fit, font_scale = "unspecified", None
    return {
        "text": "\n".join(texts),
        "lineCount": sum(1 + len(p.findall(".//a:br", NS)) for p in paragraphs),
        "wrapMode": properties.get("wrap", "square"),
        "autoFit": auto_fit,
        "fontScale": font_scale,
        "overflowGuard": within_slide and auto_fit in {"normAutofit", "spAutoFit"},
    }


def _shape_element(shape, slide_width: int, slide_height: int, slide_number: int):
    properties = shape.find("p:nvSpPr/p:cNvPr", NS)
    name = properties.get("name") if properties is not None else None
    if not name:
        raise Phase7BLayoutError(f"slide{slide_number} text shape is missing a name")
    geometry, bbox, within = _geometry(
        shape.find("p:spPr/a:xfrm", NS), slide_width, slide_height, f"slide{slide_number}/{name}"
    )
    layout = _text_layout(shape, within, f"slide{slide_number}/{name}")
    sizes = []
    for tag in (".//a:rPr", ".//a:defRPr", ".//a:endParaRPr"):
        for run in shape.findall(tag, NS):
            if run.get("sz") is not None:
                sizes.append(_integer(run, "sz", f"slide{slide_number}/{name} font size"))
    if layout["text"] and not sizes:
        raise Phase7BLayoutError(f"PPTX OOXML text has no resolved font size: slide{slide_number}/{name}")
    resolved = min(sizes) / 100 if sizes else None
    minimum = _minimum_font_size(name) if sizes else None
    return {
        "type": "text", "name": name, "geometryEmu": geometry, "bbox": bbox,
        "withinSlide": within, "resolvedFontSize": resolved,
        "resolvedRunFontSizes": [size / 100 for size in sizes],
        "minimumFontSize": minimum,
        "minimumFontSizePass": resolved is not None and minimum is not None and resolved >= minimum,
        "textLayout": layout,
    }


def _picture_element(picture, slide_width: int, slide_height: int, slide_number: int):
    properties = picture.find("p:nvPicPr/p:cNvPr", NS)
    name = properties.get("name") if properties is not None else None
    if not name and properties is not None and properties.get("id"):
        name = f"picture-{properties.get('id')}"
    if not name:
        raise Phase7BLayoutError(f"slide{slide_number} picture is missing an identity")
    geometry, bbox, within = _geometry(
        picture.find("p:spPr/a:xfrm", NS), slide_width, slide_height, f"slide{slide_number}/{name}"
    )
    return {"type": "image", "name": name, "geometryEmu": geometry, "bbox": bbox, "withinSlide": within}


def build_layout_report(root: Path) -> dict[str, object]:
    """Derive a hash-bound geometry/font/wrapping ledger from the final PPTX."""
    root = root.resolve(strict=True)
    pptx = root / "presentation/final_presentation.pptx"
    package_path = root / "results/presentation/phase7b_package.json"
    try:
        package = json.loads(package_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BLayoutError("Phase 7B package is invalid") from exception
    slides = package.get("deck", {}).get("slides", [])
    if not isinstance(slides, list) or len(slides) != EXPECTED_SLIDES:
        raise Phase7BLayoutError("Phase 7B package requires exactly 10 slides")
    try:
        with ZipFile(pptx) as archive:
            names = archive.namelist()
            expected_names = [f"ppt/slides/slide{n}.xml" for n in range(1, EXPECTED_SLIDES + 1)]
            actual_names = sorted(
                (name for name in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)),
                key=lambda name: int(re.search(r"\d+", name).group()),
            )
            notes = [name for name in names if re.fullmatch(r"ppt/notesSlides/notesSlide\d+\.xml", name)]
            if actual_names != expected_names or len(notes) != EXPECTED_SLIDES:
                raise Phase7BLayoutError("reviewed PPTX must contain 10 contiguous slides and 10 notes")
            try:
                presentation = ElementTree.fromstring(archive.read("ppt/presentation.xml"))
            except (KeyError, ElementTree.ParseError) as exception:
                raise Phase7BLayoutError("PPTX presentation OOXML is invalid") from exception
            size = presentation.find("p:sldSz", NS)
            slide_width = _integer(size, "cx", "slide width")
            slide_height = _integer(size, "cy", "slide height")
            report_slides = []
            for number, (slide_spec, slide_name) in enumerate(zip(slides, expected_names, strict=True), start=1):
                try:
                    slide_root = ElementTree.fromstring(archive.read(slide_name))
                except (KeyError, ElementTree.ParseError) as exception:
                    raise Phase7BLayoutError(f"PPTX slide XML is invalid: slide{number}") from exception
                if slide_root.tag != f"{{{PRESENTATION_NS}}}sld":
                    raise Phase7BLayoutError(f"PPTX slide XML has the wrong root: slide{number}")
                tree = slide_root.find("p:cSld/p:spTree", NS)
                if tree is None:
                    raise Phase7BLayoutError(f"PPTX slide XML lacks a shape tree: slide{number}")
                elements = []
                for child in tree:
                    if child.tag == f"{{{PRESENTATION_NS}}}sp":
                        elements.append(_shape_element(child, slide_width, slide_height, number))
                    elif child.tag == f"{{{PRESENTATION_NS}}}pic":
                        elements.append(_picture_element(child, slide_width, slide_height, number))
                if not elements:
                    raise Phase7BLayoutError(f"PPTX slide XML contains no measurable elements: slide{number}")
                element_names = [element["name"] for element in elements]
                if len(element_names) != len(set(element_names)):
                    raise Phase7BLayoutError(f"PPTX slide XML contains duplicate element names: slide{number}")
                title_name = "cover-title" if number == 1 else f"slide-{number}-title"
                try:
                    title = next(element for element in elements if element["name"] == title_name)
                except StopIteration as exception:
                    raise Phase7BLayoutError(f"PPTX slide XML is missing title: slide{number}") from exception
                if title["textLayout"]["text"].replace("\n", " ") != slide_spec.get("title"):
                    raise Phase7BLayoutError(f"PPTX title does not match package: slide{number}")
                report_slides.append({
                    "number": number, "id": slide_spec.get("id"),
                    "title": slide_spec.get("title"), "elements": elements,
                })
    except (OSError, BadZipFile) as exception:
        raise Phase7BLayoutError("reviewed PPTX is not a valid ZIP package") from exception
    all_elements = [element for slide in report_slides for element in slide["elements"]]
    text_elements = [element for element in all_elements if element["type"] == "text"]
    return {
        "schemaVersion": 1,
        "generatedAt": FIXED_GENERATED_AT,
        "method": "tracked layout report derived from final PPTX OOXML-resolved geometry, text runs, fonts, wrapping, and autofit overflow guards",
        "slideSizeEmu": {"width": slide_width, "height": slide_height},
        "sources": {
            "package": {"path": "results/presentation/phase7b_package.json", "sha256": sha256_file(package_path)},
            "pptx": {"path": "presentation/final_presentation.pptx", "sha256": sha256_file(pptx)},
        },
        "slides": report_slides,
        "checks": {
            "allWithinSlide": all(element["withinSlide"] for element in all_elements),
            "allTextOverflowGuarded": all(element["textLayout"]["overflowGuard"] for element in text_elements),
            "minimumFontSizesPass": all(element["minimumFontSizePass"] for element in text_elements),
            "notesCount": len(notes), "slideCount": len(report_slides),
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
