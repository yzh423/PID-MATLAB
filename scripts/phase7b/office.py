"""Deterministic helpers for final Phase 7B Open XML packages."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import hashlib
import lzma
import os
from pathlib import Path
import re
import tempfile
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo
import zlib


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
    br"\s+xmlns(?::([A-Za-z_][A-Za-z0-9_.-]*))?\s*=\s*(['\"])([^'\"]*)\2"
)
_XML_ENCODING = re.compile(
    br"\A\s*<\?xml\b[^>]*\bencoding\s*=\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)
_W3CDTF = re.compile(
    r"\d{4}(?:-\d{2}(?:-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2}))?)?)?\Z"
)


class Phase7BOfficeError(ValueError):
    """Raised when an Office package is invalid for deterministic normalization."""


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
        raise Phase7BOfficeError(
            "core properties must use UTF-8 for byte-preserving normalization"
        )

    root = ElementTree.fromstring(payload)
    if root.tag != f"{{{_CORE_PROPERTIES_NAMESPACE}}}coreProperties":
        raise Phase7BOfficeError(
            "core properties root is not an Open XML coreProperties element"
        )
    volatile_count = sum(
        1 for element in root.iter() if element.tag in _VOLATILE_CORE_DATE_TAGS
    )
    if not volatile_count:
        return payload
    ranges = _volatile_date_text_ranges(payload)
    values = ["".join(element.itertext()) for element in root.iter()
              if element.tag in _VOLATILE_CORE_DATE_TAGS]
    if len(ranges) != volatile_count or len(values) != volatile_count:
        raise Phase7BOfficeError("unsupported core property date representation")

    fixed = FIXED_OFFICE_TIMESTAMP.encode("ascii")
    replacements: list[tuple[int, int, bytes]] = []
    for text_ranges, value in zip(ranges, values, strict=True):
        if not text_ranges or not _W3CDTF.fullmatch(value):
            raise Phase7BOfficeError("unsupported core property date representation")
        raw_value = b"".join(payload[start:end] for start, end in text_ranges)
        if raw_value != value.encode("utf-8"):
            raise Phase7BOfficeError("unsupported core property date representation")
        first_start, first_end = text_ranges[0]
        replacements.append((first_start, first_end, fixed))
        replacements.extend((start, end, b"") for start, end in text_ranges[1:])

    normalized = bytearray()
    previous = 0
    for start, end, replacement in sorted(replacements):
        normalized.extend(payload[previous:start])
        normalized.extend(replacement)
        previous = end
    normalized.extend(payload[previous:])
    return bytes(normalized)


def _tag_end(payload: bytes, start: int) -> int:
    """Return the closing `>` index without treating quoted attributes as markup."""
    quote: int | None = None
    for index in range(start + 1, len(payload)):
        character = payload[index]
        if quote is not None:
            if character == quote:
                quote = None
        elif character in (ord("'"), ord('"')):
            quote = character
        elif character == ord(">"):
            return index
    raise Phase7BOfficeError("unterminated XML markup in core properties")


def _expanded_name(name: bytes, scope: Mapping[bytes, bytes]) -> tuple[bytes | None, bytes]:
    """Resolve a lexical XML name against its in-scope namespace bindings."""
    prefix, separator, local = name.partition(b":")
    if separator:
        return scope.get(prefix), local
    return scope.get(b""), prefix


def _volatile_date_text_ranges(payload: bytes) -> list[list[tuple[int, int]]]:
    """Locate volatile date text nodes with lexical namespace-scope tracking."""
    volatile_names = {
        (_DCTERMS_NAMESPACE.encode("ascii"), b"created"),
        (_DCTERMS_NAMESPACE.encode("ascii"), b"modified"),
        (_CORE_PROPERTIES_NAMESPACE.encode("ascii"), b"lastPrinted"),
    }
    frames: list[dict[str, object]] = []
    ranges: list[list[tuple[int, int]]] = []
    cursor = 0

    def record_plain_text(end: int) -> None:
        if frames and frames[-1]["volatile"] and cursor < end:
            text_ranges = frames[-1]["text_ranges"]
            assert isinstance(text_ranges, list)
            text_ranges.append((cursor, end))

    while True:
        start = payload.find(b"<", cursor)
        if start < 0:
            break
        record_plain_text(start)
        if payload.startswith(b"<!--", start):
            end = payload.find(b"-->", start + 4)
            if end < 0:
                raise Phase7BOfficeError("unterminated XML comment in core properties")
            cursor = end + 3
            continue
        if payload.startswith(b"<?", start):
            end = payload.find(b"?>", start + 2)
            if end < 0:
                raise Phase7BOfficeError("unterminated XML processing instruction")
            cursor = end + 2
            continue
        if payload.startswith(b"<![CDATA[", start):
            end = payload.find(b"]]>", start + 9)
            if end < 0:
                raise Phase7BOfficeError("unterminated XML CDATA section")
            if frames and frames[-1]["volatile"]:
                text_ranges = frames[-1]["text_ranges"]
                assert isinstance(text_ranges, list)
                text_ranges.append((start + 9, end))
            cursor = end + 3
            continue

        end = _tag_end(payload, start)
        content = payload[start + 1:end].strip()
        cursor = end + 1
        if not content or content.startswith(b"!"):
            continue
        if content.startswith(b"/"):
            name = content[1:].strip()
            if not frames or frames[-1]["name"] != name:
                raise Phase7BOfficeError("unsupported core property date representation")
            frame = frames.pop()
            if frame["volatile"]:
                if frame["has_element_child"]:
                    raise Phase7BOfficeError("unsupported core property date representation")
                text_ranges = frame["text_ranges"]
                assert isinstance(text_ranges, list)
                ranges.append(text_ranges)
            continue

        self_closing = content.endswith(b"/")
        body = content[:-1].rstrip() if self_closing else content
        name = body.split(None, 1)[0]
        if frames and frames[-1]["volatile"]:
            frames[-1]["has_element_child"] = True
        parent_scope = frames[-1]["scope"] if frames else {}
        assert isinstance(parent_scope, dict)
        scope = parent_scope.copy()
        for prefix, _, uri in _NAMESPACE_DECLARATION.findall(body):
            scope[prefix] = uri
        is_volatile = _expanded_name(name, scope) in volatile_names
        if self_closing:
            if is_volatile:
                raise Phase7BOfficeError("unsupported core property date representation")
            continue
        frames.append({
            "name": name,
            "scope": scope,
            "volatile": is_volatile,
            "text_ranges": [],
            "has_element_child": False,
        })

    if frames:
        raise Phase7BOfficeError("unterminated XML element in core properties")
    return ranges


def _validate_opc_part_names(infos: Sequence[ZipInfo]) -> None:
    """Reject ambiguous or extractable-outside-package ZIP entries before writing."""
    seen: set[str] = set()
    for info in infos:
        name = info.filename
        original_name = info.orig_filename
        if name in seen:
            raise Phase7BOfficeError(f"duplicate OPC part name: {name}")
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
            raise Phase7BOfficeError(f"invalid OPC part name: {name}")


def normalize_openxml_package(path: Path, suffix: str) -> None:
    """Rewrite one Open XML package with reproducible ZIP and core metadata."""
    path = path.resolve(strict=True)
    expected_suffix = suffix.lower()
    if path.suffix.lower() != expected_suffix:
        raise Phase7BOfficeError(f"expected {suffix} package")

    with ZipFile(path) as source:
        infos = source.infolist()
        _validate_opc_part_names(infos)
        try:
            entries = [
                (info.filename, info.compress_type, source.read(info))
                for info in infos
            ]
        except (
            EOFError,
            NotImplementedError,
            RuntimeError,
            lzma.LZMAError,
            zlib.error,
        ) as exception:
            raise Phase7BOfficeError(
                "unable to decompress an Open XML package entry"
            ) from exception
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
