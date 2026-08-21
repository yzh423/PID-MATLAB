"""Clean-checkout Phase 7B layout evidence derived from final PPTX OOXML."""

from __future__ import annotations

import json
from pathlib import Path
import re
from xml.etree import ElementTree
from zipfile import BadZipFile, ZipFile

from PIL import ImageFont

from scripts.phase7b.evidence import FIXED_GENERATED_AT, sha256_file
from scripts.phase7b.office import validate_pptx_relationship_graph


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
        if not 1 <= font_scale <= 100000:
            raise Phase7BLayoutError(f"PPTX OOXML has invalid {label} font scale")
    elif properties.find("a:spAutoFit", NS) is not None:
        raise Phase7BLayoutError(f"PPTX OOXML has unresolved {label} font scale for spAutoFit")
    elif properties.find("a:noAutofit", NS) is not None:
        auto_fit, font_scale = "noAutofit", 100000
    else:
        raise Phase7BLayoutError(f"PPTX OOXML has unresolved {label} font scale")
    return {
        "text": "\n".join(texts),
        "lineCount": sum(1 + len(p.findall(".//a:br", NS)) for p in paragraphs),
        "wrapMode": properties.get("wrap", "square"),
        "autoFit": auto_fit,
        "fontScale": font_scale,
        "overflowGuard": within_slide and auto_fit in {"normAutofit", "noAutofit"},
    }


def _conservative_text_fit(shape, geometry: dict[str, int], layout: dict[str, object], effective_size: float) -> dict[str, object]:
    body = shape.find("p:txBody", NS)
    properties = body.find("a:bodyPr", NS)
    margins = {
        "left": int(properties.get("lIns", "91440")), "right": int(properties.get("rIns", "91440")),
        "top": int(properties.get("tIns", "45720")), "bottom": int(properties.get("bIns", "45720")),
    }
    inner_width = geometry["width"] - margins["left"] - margins["right"]
    inner_height = geometry["height"] - margins["top"] - margins["bottom"]
    if inner_width <= 0 or inner_height <= 0:
        return {"clippingFree": False, "estimatedRenderedLines": 0, "requiredHeightEmu": None}
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", max(1, round(effective_size * 96 / 72)))
    pixel_width = inner_width * 96 / 914400
    rendered_lines = 0
    longest = 0.0
    for explicit in str(layout["text"]).split("\n"):
        words = explicit.split()
        if not words:
            rendered_lines += 1
            continue
        line = words[0]
        for word in words[1:]:
            candidate = f"{line} {word}"
            if font.getlength(candidate) <= pixel_width:
                line = candidate
            else:
                longest = max(longest, font.getlength(line))
                rendered_lines += 1
                line = word
        longest = max(longest, font.getlength(line))
        rendered_lines += 1
    # Arial's nominal line box plus a conservative 15% leading/safety allowance.
    required_height = rendered_lines * effective_size * 12700 * 1.15
    return {
        "clippingFree": longest <= pixel_width and required_height <= inner_height,
        "estimatedRenderedLines": rendered_lines,
        "estimatedMaximumLineWidthPx": round(longest, 3),
        "availableWidthPx": round(pixel_width, 3),
        "requiredHeightEmu": round(required_height),
        "availableHeightEmu": inner_height,
        "fontMetric": {"path": "C:/Windows/Fonts/arial.ttf", "dpi": 96, "lineSafetyFactor": 1.15},
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
    effective_sizes = [round(size / 100 * layout["fontScale"] / 100000, 4) for size in sizes]
    resolved = min(effective_sizes) if effective_sizes else None
    minimum = _minimum_font_size(name) if sizes else None
    if resolved is not None:
        layout.update(_conservative_text_fit(shape, geometry, layout, resolved))
    return {
        "type": "text", "name": name, "geometryEmu": geometry, "bbox": bbox,
        "withinSlide": within, "resolvedFontSize": resolved,
        "rawRunFontSizes": [size / 100 for size in sizes],
        "resolvedRunFontSizes": effective_sizes,
        "effectiveRunFontSizes": effective_sizes,
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


def _collision_pairs(elements: list[dict[str, object]]) -> list[list[str]]:
    collisions: list[list[str]] = []
    for index, left in enumerate(elements):
        lx, ly, lw, lh = left["bbox"]
        for right in elements[index + 1:]:
            rx, ry, rw, rh = right["bbox"]
            if max(lx, rx) < min(lx + lw, rx + rw) and max(ly, ry) < min(ly + lh, ry + rh):
                collisions.append(sorted([left["name"], right["name"]]))
    return sorted(collisions)


def build_layout_report(root: Path, pptx_path: Path | None = None, package_path: Path | None = None) -> dict[str, object]:
    """Derive a hash-bound geometry/font/wrapping ledger from the final PPTX."""
    root = root.resolve(strict=True)
    pptx = (pptx_path or root / "presentation/final_presentation.pptx").resolve(strict=True)
    package_path = (package_path or root / "results/presentation/phase7b_package.json").resolve(strict=True)
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
            entries = {name: archive.read(name) for name in names}
            validate_pptx_relationship_graph([(name, 0, payload) for name, payload in entries.items()])
            expected_names = [f"ppt/slides/slide{n}.xml" for n in range(1, EXPECTED_SLIDES + 1)]
            actual_names = sorted(
                (name for name in names if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)),
                key=lambda name: int(re.search(r"\d+", name).group()),
            )
            notes = sorted(
                (name for name in names if re.fullmatch(r"ppt/notesSlides/notesSlide\d+\.xml", name)),
                key=lambda name: int(re.search(r"\d+", name).group()),
            )
            expected_notes = [f"ppt/notesSlides/notesSlide{n}.xml" for n in range(1, EXPECTED_SLIDES + 1)]
            if actual_names != expected_names or notes != expected_notes:
                raise Phase7BLayoutError("reviewed PPTX must contain 10 contiguous slides and 10 notes")
            for number, note_name in enumerate(notes, start=1):
                try:
                    note_root = ElementTree.fromstring(entries[note_name])
                except ElementTree.ParseError as exception:
                    raise Phase7BLayoutError(f"PPTX notes XML is invalid: notesSlide{number}") from exception
                note_text = "\n".join(note_root.itertext())
                if "[Sources]" not in note_text:
                    raise Phase7BLayoutError(f"PPTX notes lack required [Sources]: notesSlide{number}")
                slide_spec = slides[number - 1]
                expected_note_parts = [slide_spec.get("presenterNote"), *slide_spec.get("sources", [])]
                if any(not isinstance(part, str) or not part or part not in note_text for part in expected_note_parts):
                    raise Phase7BLayoutError(f"PPTX notes do not match required package content: notesSlide{number}")
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
                    elif child.tag not in {
                        f"{{{PRESENTATION_NS}}}nvGrpSpPr", f"{{{PRESENTATION_NS}}}grpSpPr",
                        f"{{{PRESENTATION_NS}}}extLst",
                    }:
                        local = child.tag.rsplit("}", 1)[-1]
                        raise Phase7BLayoutError(f"PPTX slide contains unhandled content-bearing OOXML: {local}")
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
                collisions = _collision_pairs(elements)
                report_slides.append({
                    "number": number, "id": slide_spec.get("id"),
                    "title": slide_spec.get("title"), "elements": elements, "collisions": collisions,
                })
    except (OSError, BadZipFile) as exception:
        raise Phase7BLayoutError("reviewed PPTX is not a valid ZIP package") from exception
    all_elements = [element for slide in report_slides for element in slide["elements"]]
    text_elements = [element for element in all_elements if element["type"] == "text"]
    return {
        "schemaVersion": 1,
        "generatedAt": FIXED_GENERATED_AT,
        "method": "tracked layout report derived from final PPTX OOXML geometry, effective autofit-scaled fonts, exact Arial metrics, conservative wrapping/clipping, and collision checks",
        "slideSizeEmu": {"width": slide_width, "height": slide_height},
        "sources": {
            "package": {"path": "results/presentation/phase7b_package.json", "sha256": sha256_file(package_path)},
            "pptx": {"path": "presentation/final_presentation.pptx", "sha256": sha256_file(pptx)},
        },
        "slides": report_slides,
        "checks": {
            "allWithinSlide": all(element["withinSlide"] for element in all_elements),
            "allTextOverflowGuarded": all(element["textLayout"]["overflowGuard"] for element in text_elements),
            "allTextClippingFree": all(element["textLayout"]["clippingFree"] for element in text_elements),
            "noCollisions": all(not slide["collisions"] for slide in report_slides),
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
