"""Deterministic helpers for final Phase 7B Open XML packages."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from datetime import date
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
_XML_ENCODING = re.compile(
    br"\A\s*<\?xml\b[^>]*\bencoding\s*=\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)
_W3CDTF = re.compile(
    r"(?P<year>\d{4})(?:-(?P<month>\d{2})(?:-(?P<day>\d{2})(?:T"
    r"(?P<hour>\d{2}):(?P<minute>\d{2})(?::(?P<second>\d{2})"
    r"(?P<fraction>\.\d+)?)?(?P<timezone>Z|[+-]\d{2}:\d{2}))?)?)?\Z"
)
_XML_SCHEMA_DATETIME = re.compile(
    r"(?P<year>\d{4})-(?P<month>\d{2})-(?P<day>\d{2})T"
    r"(?P<hour>\d{2}):(?P<minute>\d{2}):(?P<second>\d{2})"
    r"(?P<fraction>\.\d+)?(?P<timezone>Z|[+-]\d{2}:\d{2})?\Z"
)
_XML_ATTRIBUTE = re.compile(
    rb"(?P<name>[A-Za-z_][A-Za-z0-9_.-]*(?::[A-Za-z_][A-Za-z0-9_.-]*)?)\s*=\s*"
    rb"(?P<quote>['\"])(?P<value>.*?)(?P=quote)"
)
_RELATIONSHIP_NAMESPACE = b"http://schemas.openxmlformats.org/officeDocument/2006/relationships"
_PACKAGE_RELATIONSHIPS_NAMESPACE = b"http://schemas.openxmlformats.org/package/2006/relationships"
_A16_NAMESPACE = b"http://schemas.microsoft.com/office/drawing/2014/main"
_P14_NAMESPACE = b"http://schemas.microsoft.com/office/powerpoint/2010/main"
_XSI_TYPE = "{http://www.w3.org/2001/XMLSchema-instance}type"


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
    fields = [
        (element.tag, "".join(element.itertext()), element.attrib.get(_XSI_TYPE))
        for element in root.iter()
        if element.tag in _VOLATILE_CORE_DATE_TAGS
    ]
    if len(ranges) != volatile_count or len(fields) != volatile_count:
        raise Phase7BOfficeError("unsupported core property date representation")

    fixed = FIXED_OFFICE_TIMESTAMP.encode("ascii")
    replacements: list[tuple[int, int, bytes]] = []
    for (expanded_name, scope, text_ranges), (tag, value, declared_type) in zip(
        ranges, fields, strict=True
    ):
        if _expanded_tag(expanded_name) != tag or not text_ranges:
            raise Phase7BOfficeError("unsupported core property date representation")
        _validate_field_date(tag, value, declared_type, scope)
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


def _expanded_attribute_name(
    name: bytes, scope: Mapping[bytes, bytes]
) -> tuple[bytes | None, bytes]:
    """Expand an attribute name; XML default namespaces never apply to attributes."""
    prefix, separator, local = name.partition(b":")
    if separator:
        return scope.get(prefix), local
    return None, prefix


def _expanded_tag(name: tuple[bytes | None, bytes]) -> str:
    """Convert one lexical-scope expansion into ElementTree's tag representation."""
    namespace, local = name
    if namespace is None:
        return local.decode("utf-8")
    return f"{{{namespace.decode('utf-8')}}}{local.decode('utf-8')}"


def _lexical_attributes(
    body: bytes, label: str
) -> list[tuple[bytes, bytes, int, int]]:
    """Tokenize only real attributes, never namespace-looking quoted text."""
    name_end = len(body.split(None, 1)[0])
    cursor = name_end
    attributes: list[tuple[bytes, bytes, int, int]] = []
    while cursor < len(body):
        while cursor < len(body) and body[cursor:cursor + 1].isspace():
            cursor += 1
        if cursor == len(body):
            break
        attribute = _XML_ATTRIBUTE.match(body, cursor)
        if attribute is None:
            raise Phase7BOfficeError(f"invalid lexical XML attribute in {label}")
        attributes.append((
            attribute.group("name"),
            attribute.group("value"),
            attribute.start("value"),
            attribute.end("value"),
        ))
        cursor = attribute.end()
    return attributes


def _validate_field_date(
    tag: str,
    value: str,
    declared_type: str | None,
    scope: Mapping[bytes, bytes],
) -> None:
    """Validate the Open XML field-specific semantic date contract."""
    if tag == f"{{{_CORE_PROPERTIES_NAMESPACE}}}lastPrinted":
        match = _XML_SCHEMA_DATETIME.fullmatch(value)
        if match is None:
            raise Phase7BOfficeError("unsupported core property date representation")
        _validate_date_components(match)
        return

    if declared_type is not None:
        try:
            declared = _expanded_name(declared_type.encode("ascii"), scope)
        except UnicodeEncodeError as exception:
            raise Phase7BOfficeError(
                "unsupported core property date representation"
            ) from exception
        if declared != (_DCTERMS_NAMESPACE.encode("ascii"), b"W3CDTF"):
            raise Phase7BOfficeError("unsupported core property date representation")
    match = _W3CDTF.fullmatch(value)
    if match is None:
        raise Phase7BOfficeError("unsupported core property date representation")
    _validate_date_components(match)


def _validate_date_components(match: re.Match[str]) -> None:
    """Validate calendar, clock, and XML timezone bounds for one lexical match."""
    year = int(match["year"])
    month = match["month"]
    day = match["day"]
    if year == 0:
        raise Phase7BOfficeError("unsupported core property date representation")
    if month is not None:
        if day is None:
            if not 1 <= int(month) <= 12:
                raise Phase7BOfficeError("unsupported core property date representation")
        else:
            try:
                date(year, int(month), int(day))
            except ValueError as exception:
                raise Phase7BOfficeError(
                    "unsupported core property date representation"
                ) from exception
    hour = match["hour"]
    if hour is not None and (
        int(hour) > 23
        or int(match["minute"]) > 59
        or (match["second"] is not None and int(match["second"]) > 59)
    ):
        raise Phase7BOfficeError("unsupported core property date representation")
    timezone = match["timezone"]
    if timezone is not None and timezone != "Z":
        offset_hour = int(timezone[1:3])
        offset_minute = int(timezone[4:6])
        if (
            offset_hour > 14
            or offset_minute > 59
            or (offset_hour == 14 and offset_minute != 0)
        ):
            raise Phase7BOfficeError("unsupported core property date representation")


def _volatile_date_text_ranges(
    payload: bytes,
) -> list[tuple[tuple[bytes | None, bytes], dict[bytes, bytes], list[tuple[int, int]]]]:
    """Locate volatile date text nodes with lexical namespace-scope tracking."""
    volatile_names = {
        (_DCTERMS_NAMESPACE.encode("ascii"), b"created"),
        (_DCTERMS_NAMESPACE.encode("ascii"), b"modified"),
        (_CORE_PROPERTIES_NAMESPACE.encode("ascii"), b"lastPrinted"),
    }
    frames: list[dict[str, object]] = []
    ranges: list[tuple[tuple[bytes | None, bytes], dict[bytes, bytes], list[tuple[int, int]]]] = []
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
                scope = frame["scope"]
                assert isinstance(scope, dict)
                ranges.append((_expanded_name(name, scope), scope, text_ranges))
            continue

        self_closing = content.endswith(b"/")
        body = content[:-1].rstrip() if self_closing else content
        name = body.split(None, 1)[0]
        if frames and frames[-1]["volatile"]:
            frames[-1]["has_element_child"] = True
        parent_scope = frames[-1]["scope"] if frames else {}
        assert isinstance(parent_scope, dict)
        scope = parent_scope.copy()
        for attribute_name, uri, _, _ in _lexical_attributes(body, "core properties"):
            if attribute_name == b"xmlns":
                scope[b""] = uri
            elif attribute_name.startswith(b"xmlns:"):
                scope[attribute_name.removeprefix(b"xmlns:")] = uri
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


def _relationship_source_part(name: str) -> str | None:
    """Return the OPC source part addressed by one relationship part name."""
    if name == "_rels/.rels":
        return None
    parent, marker, leaf = name.rpartition("/_rels/")
    if not marker or not leaf.endswith(".rels"):
        return None
    return f"{parent}/{leaf[:-5]}"


def _replace_byte_ranges(
    payload: bytes,
    replacements: Sequence[tuple[int, int, bytes]],
) -> bytes:
    """Apply non-overlapping byte replacements while preserving every other byte."""
    rewritten = bytearray()
    cursor = 0
    for start, end, replacement in sorted(replacements):
        rewritten.extend(payload[cursor:start])
        rewritten.extend(replacement)
        cursor = end
    rewritten.extend(payload[cursor:])
    return bytes(rewritten)


def _xml_start_tags(
    payload: bytes, label: str
) -> list[
    tuple[
        tuple[bytes | None, bytes],
        list[tuple[tuple[bytes | None, bytes], bytes, int, int]],
    ]
]:
    """Tokenize start tags with lexical namespace scope and byte offsets."""
    frames: list[tuple[bytes, dict[bytes, bytes]]] = []
    tags: list[
        tuple[
            tuple[bytes | None, bytes],
            list[tuple[tuple[bytes | None, bytes], bytes, int, int]],
        ]
    ] = []
    cursor = 0
    while True:
        start = payload.find(b"<", cursor)
        if start < 0:
            break
        if payload.startswith(b"<!--", start):
            end = payload.find(b"-->", start + 4)
            if end < 0:
                raise Phase7BOfficeError(f"unterminated XML comment in {label}")
            cursor = end + 3
            continue
        if payload.startswith(b"<?", start):
            end = payload.find(b"?>", start + 2)
            if end < 0:
                raise Phase7BOfficeError(f"unterminated XML processing instruction in {label}")
            cursor = end + 2
            continue
        if payload.startswith(b"<![CDATA[", start):
            end = payload.find(b"]]>", start + 9)
            if end < 0:
                raise Phase7BOfficeError(f"unterminated XML CDATA section in {label}")
            cursor = end + 3
            continue
        end = _tag_end(payload, start)
        raw = payload[start + 1:end]
        content = raw.strip()
        cursor = end + 1
        if not content or content.startswith(b"!"):
            continue
        if content.startswith(b"/"):
            lexical_name = content[1:].strip()
            if not frames or frames[-1][0] != lexical_name:
                raise Phase7BOfficeError(f"unbalanced XML element in {label}")
            frames.pop()
            continue
        self_closing = content.endswith(b"/")
        body = content[:-1].rstrip() if self_closing else content
        lexical_name = body.split(None, 1)[0]
        parent_scope = frames[-1][1] if frames else {}
        scope = parent_scope.copy()
        lexical_attributes = _lexical_attributes(body, label)
        for attribute_name, uri, _, _ in lexical_attributes:
            if attribute_name == b"xmlns":
                scope[b""] = uri
            elif attribute_name.startswith(b"xmlns:"):
                scope[attribute_name.removeprefix(b"xmlns:")] = uri
        body_start = start + 1 + len(raw) - len(raw.lstrip())
        attributes = []
        for attribute_name, value, value_start, value_end in lexical_attributes:
            if attribute_name == b"xmlns" or attribute_name.startswith(b"xmlns:"):
                continue
            attributes.append((
                _expanded_attribute_name(attribute_name, scope),
                value,
                body_start + value_start,
                body_start + value_end,
            ))
        tags.append((_expanded_name(lexical_name, scope), attributes))
        if not self_closing:
            frames.append((lexical_name, scope))
    if frames:
        raise Phase7BOfficeError(f"unterminated XML element in {label}")
    return tags


def _canonicalize_relationship_part_ids(
    payload: bytes,
) -> tuple[bytes, dict[bytes, bytes]]:
    """Canonicalize only `Relationship/@Id` fields in a relationship part."""
    try:
        root = ElementTree.fromstring(payload)
    except ElementTree.ParseError as exception:
        raise Phase7BOfficeError("invalid package relationship XML") from exception
    if root.tag != f"{{{_PACKAGE_RELATIONSHIPS_NAMESPACE.decode('ascii')}}}Relationships":
        raise Phase7BOfficeError("relationship part root is not package Relationships")
    replacements: dict[bytes, bytes] = {}
    ranges: list[tuple[int, int, bytes]] = []
    relationship_name = (_PACKAGE_RELATIONSHIPS_NAMESPACE, b"Relationship")
    index = 0
    for expanded_name, attributes in _xml_start_tags(payload, "relationship part"):
        if expanded_name != relationship_name:
            continue
        ids = [attribute for attribute in attributes if attribute[0] == (None, b"Id")]
        if len(ids) != 1:
            raise Phase7BOfficeError("package Relationship requires exactly one Id")
        _, old, start, end = ids[0]
        if old in replacements:
            raise Phase7BOfficeError(f"duplicate relationship Id: {old.decode('utf-8', 'replace')}")
        index += 1
        new = f"rId{index}".encode("ascii")
        replacements[old] = new
        ranges.append((start, end, new))
    return _replace_byte_ranges(payload, ranges), replacements


def _canonicalize_relationship_reference_attributes(
    payload: bytes,
    replacements: Mapping[bytes, bytes],
) -> bytes:
    """Rewrite only attributes in the Office relationships namespace.

    Namespaces are resolved with the lexical scope in effect for each start tag,
    so unrelated attributes and text with coincidentally equal values are left
    byte-for-byte intact.
    """
    ranges: list[tuple[int, int, bytes]] = []
    for _, attributes in _xml_start_tags(payload, "relationship source"):
        for expanded_name, old, start, end in attributes:
            namespace, _ = expanded_name
            if namespace == _RELATIONSHIP_NAMESPACE and old in replacements:
                ranges.append((start, end, replacements[old]))
    return _replace_byte_ranges(payload, ranges)


def _canonicalize_creation_ids(payload: bytes, creation_index: int) -> tuple[bytes, int]:
    allowlist = {
        (_A16_NAMESPACE, b"creationId"): ((None, b"id"), "guid"),
        (_P14_NAMESPACE, b"creationId"): ((None, b"val"), "integer"),
    }
    ranges: list[tuple[int, int, bytes]] = []
    for expanded_name, attributes in _xml_start_tags(payload, "presentation XML"):
        contract = allowlist.get(expanded_name)
        if contract is None:
            continue
        attribute_name, value_kind = contract
        matches = [attribute for attribute in attributes if attribute[0] == attribute_name]
        if len(matches) != 1:
            raise Phase7BOfficeError("Office creationId requires its allowlisted identifier attribute")
        _, _, start, end = matches[0]
        if value_kind == "guid":
            value = f"{{00000000-0000-0000-0000-{creation_index:012d}}}".encode("ascii")
        else:
            value = str(creation_index).encode("ascii")
        ranges.append((start, end, value))
        creation_index += 1
    return _replace_byte_ranges(payload, ranges), creation_index


def _canonicalize_pptx_generated_ids(
    entries: Sequence[tuple[str, int, bytes]],
) -> list[tuple[str, int, bytes]]:
    """Remove artifact-tool-generated relationship and creation identifier entropy."""
    rewritten = {name: payload for name, _, payload in entries}
    relationship_maps: dict[str, dict[bytes, bytes]] = {}
    for name in sorted(rewritten):
        if not name.endswith(".rels"):
            continue
        source_part = _relationship_source_part(name)
        rewritten[name], replacements = _canonicalize_relationship_part_ids(rewritten[name])
        if source_part is not None:
            relationship_maps[source_part] = replacements

    for source_part, replacements in relationship_maps.items():
        if source_part in rewritten:
            rewritten[source_part] = _canonicalize_relationship_reference_attributes(
                rewritten[source_part], replacements
            )

    creation_index = 1

    for name in sorted(rewritten):
        if not name.endswith(".xml"):
            continue
        rewritten[name], creation_index = _canonicalize_creation_ids(
            rewritten[name], creation_index
        )
    return [(name, compression, rewritten[name]) for name, compression, _ in entries]


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
    if expected_suffix == ".pptx":
        entries = _canonicalize_pptx_generated_ids(entries)

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
