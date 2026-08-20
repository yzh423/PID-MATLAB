"""Deterministic helpers for final Phase 7B Open XML packages."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import hashlib
import os
from pathlib import Path
import re
import tempfile
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


FIXED_OFFICE_TIMESTAMP = "2026-08-21T00:00:00Z"
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)

_CORE_PROPERTIES_NAMESPACE = "http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
_DCTERMS_NAMESPACE = "http://purl.org/dc/terms/"
_VOLATILE_CORE_DATE_TAGS = {
    f"{{{_DCTERMS_NAMESPACE}}}created",
    f"{{{_DCTERMS_NAMESPACE}}}modified",
    f"{{{_CORE_PROPERTIES_NAMESPACE}}}lastPrinted",
}
_NAMESPACE_DECLARATION = re.compile(
    br"\s+xmlns:([A-Za-z_][A-Za-z0-9_.-]*)\s*=\s*['\"]([^'\"]+)['\"]"
)
_XML_ENCODING = re.compile(
    br"\A\s*<\?xml\b[^>]*\bencoding\s*=\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest of one file without loading it all into memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_core_properties(payload: bytes) -> bytes:
    """Freeze volatile core-property dates without rewriting other XML bytes."""
    encoding = _XML_ENCODING.search(payload)
    if encoding is not None and encoding.group(1).lower() not in {b"utf-8", b"utf8"}:
        raise ValueError("core properties must use UTF-8 for byte-preserving normalization")

    root = ElementTree.fromstring(payload)
    if root.tag != f"{{{_CORE_PROPERTIES_NAMESPACE}}}coreProperties":
        raise ValueError("core properties root is not an Open XML coreProperties element")
    volatile_count = sum(
        1 for element in root.iter() if element.tag in _VOLATILE_CORE_DATE_TAGS
    )
    if not volatile_count:
        return payload

    namespaces = {
        prefix: uri
        for prefix, uri in _NAMESPACE_DECLARATION.findall(payload)
    }
    names = [
        prefix + b":" + local.encode("ascii")
        for prefix, uri in namespaces.items()
        for namespace, local in (
            (_DCTERMS_NAMESPACE, "created"),
            (_DCTERMS_NAMESPACE, "modified"),
            (_CORE_PROPERTIES_NAMESPACE, "lastPrinted"),
        )
        if uri == namespace.encode("ascii")
    ]
    if not names:
        raise ValueError("unsupported core property date representation")
    alternation = b"|".join(re.escape(name) for name in sorted(names, key=len, reverse=True))
    element_pattern = re.compile(
        br"(?P<open><(?P<name>" + alternation + br")\b[^>]*>)"
        br"(?P<text>[^<]*)(?P<close></(?P=name)\s*>)"
    )
    normalized, substitutions = element_pattern.subn(
        lambda match: match.group("open") + FIXED_OFFICE_TIMESTAMP.encode("ascii") + match.group("close"),
        payload,
    )
    if substitutions != volatile_count:
        raise ValueError("unsupported core property date representation")
    return normalized


def _validate_opc_part_names(infos: Sequence[ZipInfo]) -> None:
    """Reject ambiguous or extractable-outside-package ZIP entries before writing."""
    seen: set[str] = set()
    for info in infos:
        name = info.filename
        original_name = info.orig_filename
        if name in seen:
            raise ValueError(f"duplicate OPC part name: {name}")
        seen.add(name)
        segments = name.split("/")
        if (
            original_name != name
            or not name
            or name.startswith("/")
            or "\\" in name
            or ":" in name
            or name.endswith("/")
            or any(not segment or segment in {".", ".."} for segment in segments)
        ):
            raise ValueError(f"invalid OPC part name: {name}")


def normalize_openxml_package(path: Path, suffix: str) -> None:
    """Rewrite one Open XML package with reproducible ZIP and core metadata."""
    path = path.resolve(strict=True)
    expected_suffix = suffix.lower()
    if path.suffix.lower() != expected_suffix:
        raise ValueError(f"expected {suffix} package")

    with ZipFile(path) as source:
        infos = source.infolist()
        _validate_opc_part_names(infos)
        entries = [
            (info.filename, info.compress_type, source.read(info))
            for info in infos
        ]
    for index, (name, compression, payload) in enumerate(entries):
        if name == "docProps/core.xml":
            entries[index] = (name, compression, normalize_core_properties(payload))

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.normalized.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        os.close(descriptor)
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
        os.replace(temporary, path)
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
