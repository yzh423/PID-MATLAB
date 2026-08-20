"""Normalize a Word-exported report PDF for reproducible hashing."""

from __future__ import annotations

import argparse
from collections.abc import Sequence
from hashlib import sha256
from pathlib import Path
import tempfile

from pypdf import PdfReader, PdfWriter
from pypdf.generic import ArrayObject, ByteStringObject, NameObject


FIXED_PDF_DATE = "D:20260820000000+08'00'"
DOCUMENT_ID = sha256(b"PID-vs-Fuzzy-PID-Phase-7A-technical-report").digest()[:16]


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, required=True)
    return parser.parse_args(argv)


def normalize_pdf(input_path: Path, output_path: Path, project_root: Path) -> None:
    project_root = project_root.resolve(strict=True)
    report_root = (project_root / "docs/report").resolve(strict=True)
    input_path = input_path.resolve(strict=True)
    output_path = output_path.resolve()
    if input_path.suffix.lower() != ".pdf" or output_path.suffix.lower() != ".pdf":
        raise ValueError("PDF normalizer requires .pdf input and output paths")
    if input_path == output_path:
        raise ValueError("PDF normalizer input and output paths must differ")
    for path in (input_path, output_path):
        try:
            path.relative_to(report_root)
        except ValueError as exception:
            raise ValueError("PDF normalizer paths must stay inside docs/report") from exception

    reader = PdfReader(input_path)
    writer = PdfWriter(clone_from=reader)
    writer.root_object.pop(NameObject("/Metadata"), None)
    writer.metadata = None
    writer.add_metadata(
        {
            "/Title": "Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation",
            "/Author": "PID vs Fuzzy PID project",
            "/Subject": "Phase 7A technical report",
            "/Creator": "Deterministic Phase 7A report pipeline",
            "/Producer": "pypdf reproducible packaging",
            "/CreationDate": FIXED_PDF_DATE,
            "/ModDate": FIXED_PDF_DATE,
        }
    )
    writer._ID = ArrayObject(
        [ByteStringObject(DOCUMENT_ID), ByteStringObject(DOCUMENT_ID)]
    )
    writer.compress_identical_objects(remove_duplicates=True, remove_unreferenced=True)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        suffix=".pdf", dir=output_path.parent, delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with temporary_path.open("wb") as stream:
            writer.write(stream)
        reopened = PdfReader(temporary_path)
        if len(reopened.pages) != len(reader.pages):
            raise ValueError("normalized PDF page count changed")
        temporary_path.replace(output_path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    normalize_pdf(args.input, args.output, args.project_root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
