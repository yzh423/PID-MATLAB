"""Deterministic helpers for final Phase 7B Open XML packages."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import hashlib
from pathlib import Path
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


FIXED_OFFICE_TIMESTAMP = "2026-08-21T00:00:00Z"
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)

_CORE_PROPERTIES_NAMESPACE = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
_DC_NAMESPACE = "http://purl.org/dc/elements/1.1/"
_DCTERMS_NAMESPACE = "http://purl.org/dc/terms/"
_XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"
_CORE_DATE_TAGS = {
    f"{{{_DCTERMS_NAMESPACE}}}created",
    f"{{{_DCTERMS_NAMESPACE}}}modified",
}

ElementTree.register_namespace("cp", _CORE_PROPERTIES_NAMESPACE)
ElementTree.register_namespace("dc", _DC_NAMESPACE)
ElementTree.register_namespace("dcterms", _DCTERMS_NAMESPACE)
ElementTree.register_namespace("xsi", _XSI_NAMESPACE)


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest of one file without loading it all into memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_core_properties(payload: bytes) -> bytes:
    """Freeze only created and modified timestamps in core-properties XML."""
    parser = ElementTree.XMLParser(
        target=ElementTree.TreeBuilder(insert_comments=True, insert_pis=True)
    )
    root = ElementTree.fromstring(payload, parser=parser)
    for element in root.iter():
        if element.tag in _CORE_DATE_TAGS:
            element.text = FIXED_OFFICE_TIMESTAMP
    return ElementTree.tostring(root, encoding="utf-8", xml_declaration=True)


def normalize_openxml_package(path: Path, suffix: str) -> None:
    """Rewrite one Open XML package with reproducible ZIP and core metadata."""
    path = path.resolve(strict=True)
    expected_suffix = suffix.lower()
    if path.suffix.lower() != expected_suffix:
        raise ValueError(f"expected {suffix} package")

    with ZipFile(path) as source:
        entries = [
            (info.filename, info.compress_type, source.read(info))
            for info in source.infolist()
        ]
    for index, (name, compression, payload) in enumerate(entries):
        if name == "docProps/core.xml":
            entries[index] = (name, compression, normalize_core_properties(payload))

    temporary = path.with_name(f".{path.name}.normalized.tmp")
    try:
        with ZipFile(temporary, "w", compression=ZIP_DEFLATED, compresslevel=9) as target:
            target.comment = b""
            for name, compression, payload in sorted(entries, key=lambda entry: entry[0]):
                info = ZipInfo(name, FIXED_ZIP_TIME)
                info.compress_type = compression
                info.create_system = 0
                info.external_attr = 0
                info.extra = b""
                info.comment = b""
                target.writestr(info, payload)
        temporary.replace(path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def _relative_record(root: Path, path: Path) -> dict[str, str]:
    resolved = path.resolve(strict=True)
    try:
        relative = resolved.relative_to(root)
    except ValueError as exception:
        raise ValueError(f"manifest path is outside project root: {path}") from exception
    if not resolved.is_file():
        raise ValueError(f"manifest path is not a file: {path}")
    return {"path": relative.as_posix(), "sha256": sha256_file(resolved)}


def canonical_manifest(
    root: Path,
    sources: Sequence[Path],
    outputs: Sequence[Path],
    counts: Mapping[str, int],
) -> dict[str, object]:
    """Return a stable Phase 7B manifest for final artifact verification."""
    root = root.resolve(strict=True)
    return {
        "schemaVersion": 1,
        "generatedAt": FIXED_OFFICE_TIMESTAMP,
        "sources": sorted((_relative_record(root, path) for path in sources), key=lambda record: record["path"]),
        "outputs": sorted((_relative_record(root, path) for path in outputs), key=lambda record: record["path"]),
        "document": dict(sorted(counts.items())),
    }
