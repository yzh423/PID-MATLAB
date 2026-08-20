"""Validate the technical report reference bank and evidence claims."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
from urllib.parse import urlparse


REQUIRED_HEADINGS = (
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
)
REQUIRED_PHRASES = (
    "combined stress",
    "0/30",
    "pick-transfer-place",
    "unsuccessful",
    "simulation",
    "not hardware validation",
)
PROHIBITED_PATTERNS = (
    r"validated (?:on|with) real hardware",
    r"guarantees? safety",
    r"real-time performance (?:was|is) validated",
    r"Fuzzy-PID (?:is|was) universally superior",
)
REQUIRED_REFERENCE_FIELDS = (
    "id",
    "authors",
    "title",
    "container",
    "year",
    "pages",
    "doi",
    "url",
    "sourceType",
    "supports",
)
DOI = re.compile(r"10\.\d{4,9}/\S+", re.IGNORECASE)
CITATION = re.compile(r"(?<!\w)\[([1-9][0-9]*)\](?!\w)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)


class ContentError(ValueError):
    """Raised when report content violates the evidence contract."""


@dataclass(frozen=True)
class Reference:
    id: int
    authors: str
    title: str
    container: str
    year: int
    pages: str
    doi: str
    url: str
    source_type: str
    supports: tuple[str, ...]


def load_references(path: Path) -> list[Reference]:
    """Load the verified citation bank and reject incomplete metadata."""
    if not path.is_file():
        raise ContentError(f"reference bank does not exist: {path}")
    try:
        records = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise ContentError(f"reference bank is not valid UTF-8 JSON: {path}") from exception
    if not isinstance(records, list):
        raise ContentError("reference bank root must be a JSON array")

    references: list[Reference] = []
    errors: list[str] = []
    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            errors.append(f"reference record {index} must be an object")
            continue
        missing = [field for field in REQUIRED_REFERENCE_FIELDS if field not in record]
        if missing:
            errors.append(f"reference record {index} missing fields: {', '.join(missing)}")
            continue
        try:
            reference = _make_reference(record)
        except (TypeError, ValueError) as exception:
            errors.append(f"reference record {index}: {exception}")
            continue
        errors.extend(_reference_errors(reference))
        references.append(reference)

    ids = [reference.id for reference in references]
    if ids != list(range(1, len(references) + 1)):
        errors.append("reference IDs must be unique and contiguous from 1")
    if errors:
        raise ContentError("; ".join(errors))
    return references


def validate_report(markdown: str, references: list[Reference]) -> None:
    """Report all structural, citation, and scope failures in stable order."""
    errors: list[str] = []
    headings = {heading.strip() for heading in HEADING.findall(markdown)}
    missing_headings = [heading for heading in REQUIRED_HEADINGS if heading not in headings]
    if missing_headings:
        errors.append("missing required headings: " + ", ".join(missing_headings))

    known_ids = {reference.id for reference in references}
    cited_ids = {int(value) for value in CITATION.findall(markdown)}
    unknown_ids = sorted(cited_ids - known_ids)
    if unknown_ids:
        errors.append("unknown citation IDs: " + ", ".join(map(str, unknown_ids)))
    uncited_ids = sorted(known_ids - cited_ids)
    if uncited_ids:
        errors.append("uncited reference IDs: " + ", ".join(map(str, uncited_ids)))

    lowered = markdown.casefold()
    missing_phrases = [phrase for phrase in REQUIRED_PHRASES if phrase not in lowered]
    if missing_phrases:
        errors.append("missing required evidence phrases: " + ", ".join(missing_phrases))

    prohibited = [
        pattern
        for pattern in PROHIBITED_PATTERNS
        if re.search(pattern, markdown, flags=re.IGNORECASE)
    ]
    if prohibited:
        errors.append("prohibited scope claim: " + ", ".join(prohibited))
    if errors:
        raise ContentError("; ".join(errors))


def _make_reference(record: dict[str, object]) -> Reference:
    supports = record["supports"]
    if not isinstance(supports, list) or not all(
        isinstance(value, str) and value.strip() for value in supports
    ):
        raise ValueError("supports must be a nonempty string array")
    if not supports:
        raise ValueError("supports must be a nonempty string array")
    if isinstance(record["id"], bool) or not isinstance(record["id"], int):
        raise TypeError("id must be an integer")
    if isinstance(record["year"], bool) or not isinstance(record["year"], int):
        raise TypeError("year must be an integer")
    string_fields = ("authors", "title", "container", "pages", "doi", "url", "sourceType")
    if not all(isinstance(record[field], str) for field in string_fields):
        raise TypeError("bibliographic text fields must be strings")
    return Reference(
        id=record["id"],
        authors=record["authors"],
        title=record["title"],
        container=record["container"],
        year=record["year"],
        pages=record["pages"],
        doi=record["doi"],
        url=record["url"],
        source_type=record["sourceType"],
        supports=tuple(supports),
    )


def _reference_errors(reference: Reference) -> list[str]:
    errors: list[str] = []
    for field in ("authors", "title", "container", "pages", "url", "source_type"):
        if not getattr(reference, field).strip():
            errors.append(f"reference {reference.id} has empty {field}")
    parsed_url = urlparse(reference.url)
    if parsed_url.scheme != "https" or not parsed_url.netloc:
        errors.append(f"reference {reference.id} URL must be absolute HTTPS")
    if reference.doi:
        if not DOI.fullmatch(reference.doi):
            errors.append(f"reference {reference.id} has invalid DOI syntax")
        if reference.url != f"https://doi.org/{reference.doi}":
            errors.append(f"reference {reference.id} DOI URL does not match its DOI")
    if reference.source_type == "documentation" and parsed_url.netloc != "www.mathworks.com":
        errors.append(f"reference {reference.id} documentation URL is not official MathWorks")
    return errors
