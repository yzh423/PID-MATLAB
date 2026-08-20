"""Build the canonical evidence-grounded technical report."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from pathlib import Path
import sys
import tempfile

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from scripts.reporting.content import (
    ContentError,
    Reference,
    load_references,
    validate_report,
)
from scripts.reporting.evidence import EvidenceError, load_evidence, resolve_tokens


REFERENCE_MARKER = "<!-- REFERENCE_LIST -->"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--markdown-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        root = args.project_root.resolve(strict=True)
        evidence = load_evidence(root / "results/report/report_evidence.json")
        references = load_references(root / "docs/report/references.json")
        template_path = root / "docs/report/technical_report_template.md"
        template = template_path.read_text(encoding="utf-8")
        template = insert_references(template, references)
        markdown, _used = resolve_tokens(template, evidence)
        validate_report(markdown, references)
        atomic_write(root / "docs/report/technical_report.md", markdown)
        if not args.markdown_only:
            raise ContentError("use --markdown-only until the DOCX builder is installed")
    except (ContentError, EvidenceError, OSError, UnicodeError) as exception:
        print(f"report build failed: {exception}", file=sys.stderr)
        return 2
    return 0


def insert_references(template: str, references: Sequence[Reference]) -> str:
    if template.count(REFERENCE_MARKER) != 1:
        raise ContentError("report template must contain one reference-list marker")
    entries = "\n\n".join(format_reference(reference) for reference in references)
    return template.replace(REFERENCE_MARKER, entries)


def format_reference(reference: Reference) -> str:
    locator = f"https://doi.org/{reference.doi}" if reference.doi else reference.url
    return (
        f"[{reference.id}] {reference.authors}, “{reference.title},” "
        f"*{reference.container}*, pp. {reference.pages}, {reference.year}. "
        f"{locator}"
    )


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", newline="\n", dir=path.parent, delete=False
    ) as temporary:
        temporary.write(text)
        temporary_path = Path(temporary.name)
    try:
        temporary_path.replace(path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
