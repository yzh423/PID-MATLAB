"""Build the canonical evidence-grounded technical report."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
import hashlib
import json
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
from scripts.reporting.document import DocumentBuildError, build_docx


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
        markdown, used = resolve_tokens(template, evidence)
        validate_report(markdown, references)
        markdown_path = root / "docs/report/technical_report.md"
        atomic_write(markdown_path, markdown)
        if not args.markdown_only:
            build_docx_outputs(root, markdown, evidence, used)
    except (
        ContentError,
        DocumentBuildError,
        EvidenceError,
        OSError,
        UnicodeError,
    ) as exception:
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


def build_docx_outputs(
    root: Path,
    markdown: str,
    evidence: dict[str, object],
    used_tokens: set[str],
) -> None:
    report_dir = root / "docs/report"
    docx_path = report_dir / "technical_report.docx"
    metadata = build_docx(markdown, root, docx_path)

    source_paths = [
        root / "docs/report/technical_report_template.md",
        root / "docs/report/references.json",
        root / "results/report/report_evidence.json",
    ]
    artifact_records = evidence.get("artifacts")
    if not isinstance(artifact_records, list):
        raise EvidenceError("evidence artifacts must be a list")
    figure_paths: list[Path] = []
    for record in artifact_records:
        if not isinstance(record, dict) or not isinstance(record.get("relativePath"), str):
            raise EvidenceError("each evidence artifact requires relativePath")
        figure_paths.append(root / record["relativePath"])
    source_paths.extend(figure_paths)

    if tuple(path.relative_to(root).as_posix() for path in figure_paths) != metadata.figure_paths:
        raise DocumentBuildError("DOCX figures do not match the selected evidence figures")

    generated_at = evidence.get("generatedAt")
    if not isinstance(generated_at, str):
        raise EvidenceError("evidence generatedAt must be a string")
    manifest = {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "stylePreset": "technical_report_a4_compact (compact_reference_guide basis)",
        "sources": [_hash_record(path, root) for path in source_paths],
        "outputs": [
            _hash_record(report_dir / "technical_report.md", root),
            _hash_record(docx_path, root),
        ],
        "usedEvidenceTokens": sorted(used_tokens),
        "selectedFigures": list(metadata.figure_paths),
        "document": {
            "figureCount": metadata.figure_count,
            "tableCount": metadata.table_count,
        },
    }
    atomic_write(
        report_dir / "build_manifest.json",
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
    )


def _hash_record(path: Path, root: Path) -> dict[str, str]:
    if not path.is_file():
        raise OSError(f"manifest input does not exist: {path}")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "path": path.resolve().relative_to(root.resolve()).as_posix(),
        "sha256": digest.hexdigest(),
    }


if __name__ == "__main__":
    raise SystemExit(main())
