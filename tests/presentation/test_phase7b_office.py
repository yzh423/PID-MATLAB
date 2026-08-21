from __future__ import annotations

from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock
import warnings
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile, ZipInfo

from scripts.normalize_phase7b_office import main as normalize_main
from scripts.phase7b.office import (
    FIXED_OFFICE_TIMESTAMP,
    FIXED_ZIP_TIME,
    canonical_manifest,
    normalize_openxml_package,
    sha256_file,
)


CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<!-- Pre-root comment retained byte-for-byte. -->
<?phase7b preserve-this?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
  <!-- Retained to prove normalization does not remove valid XML content. -->
  <dc:creator>Fixture Author</dc:creator>
  <cp:lastModifiedBy>Fixture Editor</cp:lastModifiedBy>
  <cp:revision>7</cp:revision>
  <cp:lastPrinted>{last_printed}</cp:lastPrinted>
  <dcterms:created xsi:type=\"dcterms:W3CDTF\">{timestamp}</dcterms:created>
  <dcterms:modified xsi:type=\"dcterms:W3CDTF\">{timestamp}</dcterms:modified>
</cp:coreProperties>
"""

DEFAULT_NAMESPACE_CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<!-- Default-core namespace comment retained byte-for-byte. -->
<?phase7b preserve-default?>
<coreProperties xmlns=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\">
  <lastPrinted>{last_printed}</lastPrinted>
  <dcterms:created>{timestamp}</dcterms:created>
  <dcterms:modified>{timestamp}</dcterms:modified>
</coreProperties>
<?phase7b preserve-after-default?>
<!-- Post-root default-core namespace comment retained byte-for-byte. -->
"""

TOKEN_AWARE_CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\">
  <cp:lastPrinted><![CDATA[{last_printed}]]></cp:lastPrinted>
  <dcterms:created><?keep date-pi?>{timestamp}<!-- keep date-comment --></dcterms:created>
  <dcterms:modified>2025-01-<![CDATA[01T00:]]>00:00Z</dcterms:modified>
</cp:coreProperties>
"""

INVALID_TOKEN_AWARE_CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\">
  <cp:lastPrinted>{last_printed}</cp:lastPrinted>
  <dcterms:created><?keep date-pi?>not-a-date<!-- keep date-comment --></dcterms:created>
  <dcterms:modified>{timestamp}</dcterms:modified>
</cp:coreProperties>
"""

MALFORMED_CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\">
  <cp:lastPrinted>{last_printed}</cp:lastPrinted>
  <dcterms:created>{timestamp}</dcterms:created>
  <dcterms:modified>{timestamp}</dcterms:modified>
"""

SEMANTIC_CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">
  <cp:lastPrinted>{last_printed}</cp:lastPrinted>
  <dcterms:created xsi:type=\"{created_type}\">{created}</dcterms:created>
  <dcterms:modified xsi:type=\"{modified_type}\">{modified}</dcterms:modified>
</cp:coreProperties>
"""


def create_fixture_package(
    path: Path,
    timestamp: str,
    zip_time: tuple[int, int, int, int, int, int],
    *,
    last_printed: str | None = None,
    compression_by_name: dict[str, int] | None = None,
    core_properties_template: str = CORE_PROPERTIES,
    core_properties: bytes | None = None,
) -> None:
    """Create a valid minimal Open XML-like package with volatile ZIP metadata."""
    entries = {
        "[Content_Types].xml": b"<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
        "docProps/core.xml": core_properties or core_properties_template.format(
            timestamp=timestamp,
            last_printed=last_printed or timestamp,
        ).encode("utf-8"),
        "ppt/presentation.xml": b"<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"/>",
    }
    compression_by_name = compression_by_name or {}
    with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
        archive.comment = b"volatile package comment"
        for name in reversed(sorted(entries)):
            info = ZipInfo(name, zip_time)
            info.compress_type = compression_by_name.get(name, ZIP_DEFLATED)
            info.extra = b"\xfe\xca\x04\x00meta"
            info.comment = b"volatile entry comment"
            archive.writestr(info, entries[name])


def _core_date_values(payload: bytes) -> list[str]:
    root = ElementTree.fromstring(payload)
    date_tags = {
        "{http://schemas.openxmlformats.org/package/2006/metadata/core-properties}lastPrinted",
        "{http://purl.org/dc/terms/}created",
        "{http://purl.org/dc/terms/}modified",
    }
    return ["".join(element.itertext()) for element in root if element.tag in date_tags]


def semantic_core_properties(
    *, last_printed: str = "2025-01-01T00:00:00Z",
    created: str = "2024-02-29T23:59:59+14:00",
    modified: str = "2024-02-29T23:59:59-14:00",
    created_type: str = "dcterms:W3CDTF",
    modified_type: str = "dcterms:W3CDTF",
) -> bytes:
    return SEMANTIC_CORE_PROPERTIES.format(
        last_printed=last_printed,
        created=created,
        modified=modified,
        created_type=created_type,
        modified_type=modified_type,
    ).encode("utf-8")


class Phase7BOfficeTests(unittest.TestCase):
    @staticmethod
    def _write_adversarial_pptx(
        path: Path,
        *,
        relationship_xml: bytes,
        slide_xml: bytes,
    ) -> None:
        entries = {
            "[Content_Types].xml": b"<Types/>",
            "ppt/slides/slide1.xml": slide_xml,
            "ppt/slides/_rels/slide1.xml.rels": relationship_xml,
            "ppt/media/image1.png": b"image",
        }
        with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
            for name, payload in entries.items():
                archive.writestr(name, payload)

    def test_pptx_normalization_canonicalizes_generated_relationship_and_creation_ids(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.pptx"
            second = Path(directory) / "second.pptx"

            def write_pptx(path: Path, relationship_id: str, creation_id: str, slide_id: str) -> None:
                entries = {
                    "[Content_Types].xml": b"<Types/>",
                    "docProps/core.xml": CORE_PROPERTIES.format(
                        timestamp="2026-08-21T00:00:00Z",
                        last_printed="2026-08-21T00:00:00Z",
                    ).encode("utf-8"),
                    "ppt/presentation.xml": (
                        f'<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                        f'xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main">'
                        f'<p:extLst><p:ext><p14:creationId val="{slide_id}"/></p:ext></p:extLst></p:presentation>'
                    ).encode("utf-8"),
                    "ppt/slides/slide1.xml": (
                        f'<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                        f'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
                        f'xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main">'
                        f'<p:pic r:embed="{relationship_id}"/><p:ext id="R-unrelated">R-unrelated</p:ext>'
                        f'<a16:creationId id="{{{creation_id}}}"/></p:sld>'
                    ).encode("utf-8"),
                    "ppt/slides/_rels/slide1.xml.rels": (
                        f'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                        f'<Relationship Id="{relationship_id}" Type="image" Target="../media/image1.png"/>'
                        f'</Relationships>'
                    ).encode("utf-8"),
                    "ppt/media/image1.png": b"admitted image",
                }
                with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
                    for name, payload in entries.items():
                        archive.writestr(name, payload)

            write_pptx(first, "R-unrelated", "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", "987654321")
            write_pptx(second, "R-unrelated", "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", "123456789")
            normalize_openxml_package(first, ".pptx")
            normalize_openxml_package(second, ".pptx")

            self.assertEqual(sha256_file(first), sha256_file(second))
            with ZipFile(first) as archive:
                self.assertIn(b'Id="rId1"', archive.read("ppt/slides/_rels/slide1.xml.rels"))
                slide = archive.read("ppt/slides/slide1.xml")
                self.assertIn(b'r:embed="rId1"', slide)
                self.assertIn(b'<p:ext id="R-unrelated">R-unrelated</p:ext>', slide)

    def test_semantically_invalid_dates_fail_before_replacing_target(self) -> None:
        invalid_values = (
            "2024-02-30T00:00:00Z",
            "2025-13-01T29:00:00Z",
            "2025-01-01T00:00:00+99:99",
            "2025-01-01T00:00:00+14:01",
            "2024-02-29T12:99Z",
            "2024-02-29T12:34+14:01",
        )
        with tempfile.TemporaryDirectory() as directory:
            for index, invalid in enumerate(invalid_values):
                package = Path(directory) / f"invalid-semantic-{index}.pptx"
                create_fixture_package(
                    package,
                    "2025-01-01T00:00:00Z",
                    (2026, 8, 21, 1, 2, 4),
                    core_properties=semantic_core_properties(created=invalid),
                )
                original_digest = sha256_file(package)

                with self.assertRaisesRegex(ValueError, "unsupported core property date representation"):
                    normalize_openxml_package(package, ".pptx")

                self.assertEqual(sha256_file(package), original_digest)

    def test_semantic_date_contract_accepts_leap_day_and_timezone_less_last_printed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "semantic-valid.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                core_properties=semantic_core_properties(
                    last_printed="2025-01-01T00:00:00",
                    created="2024-02-29T23:59:59+14:00",
                    modified="2024-02-29T23:59:59-14:00",
                ),
            )

            normalize_openxml_package(package, ".pptx")

            with ZipFile(package) as archive:
                self.assertEqual(_core_date_values(archive.read("docProps/core.xml")), [
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                ])

    def test_w3cdtf_minute_precision_dates_normalize_deterministically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "minute-precision.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                core_properties=semantic_core_properties(
                    created="2024-02-29T12:34Z",
                    modified="2024-02-29T12:34+05:30",
                ),
            )

            normalize_openxml_package(package, ".pptx")
            first_digest = sha256_file(package)
            normalize_openxml_package(package, ".pptx")

            self.assertEqual(sha256_file(package), first_digest)
            with ZipFile(package) as archive:
                self.assertEqual(_core_date_values(archive.read("docProps/core.xml")), [
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                ])

    def test_created_and_modified_require_the_declared_w3cdtf_type(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            for field in ("created_type", "modified_type"):
                package = Path(directory) / f"invalid-{field}.pptx"
                create_fixture_package(
                    package,
                    "2025-01-01T00:00:00Z",
                    (2026, 8, 21, 1, 2, 4),
                    core_properties=semantic_core_properties(**{field: "xsd:dateTime"}),
                )
                original_digest = sha256_file(package)

                with self.assertRaisesRegex(ValueError, "unsupported core property date representation"):
                    normalize_openxml_package(package, ".pptx")

                self.assertEqual(sha256_file(package), original_digest)

    def test_date_text_with_embedded_pi_and_comment_is_normalized_without_removal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "pi-comment.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2025-01-01T00:00:00Z",
                core_properties_template=TOKEN_AWARE_CORE_PROPERTIES,
            )

            normalize_openxml_package(package, ".pptx")

            with ZipFile(package) as archive:
                core = archive.read("docProps/core.xml")
            self.assertIn(b"<?keep date-pi?>", core)
            self.assertIn(b"<!-- keep date-comment -->", core)
            self.assertEqual(_core_date_values(core), [
                FIXED_OFFICE_TIMESTAMP,
                FIXED_OFFICE_TIMESTAMP,
                FIXED_OFFICE_TIMESTAMP,
            ])

    def test_cdata_date_text_is_normalized_without_removing_cdata_markup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "cdata.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2025-01-01T00:00:00Z",
                core_properties_template=TOKEN_AWARE_CORE_PROPERTIES,
            )

            normalize_openxml_package(package, ".pptx")

            with ZipFile(package) as archive:
                core = archive.read("docProps/core.xml")
            self.assertIn(b"<![CDATA[2026-08-21T00:00:00Z]]>", core)
            self.assertEqual(_core_date_values(core)[0], FIXED_OFFICE_TIMESTAMP)

    def test_split_plain_and_cdata_date_text_normalizes_schema_visible_value(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "split-text.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2025-01-01T00:00:00Z",
                core_properties_template=TOKEN_AWARE_CORE_PROPERTIES,
            )

            normalize_openxml_package(package, ".pptx")

            with ZipFile(package) as archive:
                core = archive.read("docProps/core.xml")
            self.assertIn(b"<![CDATA[]]>", core)
            self.assertEqual(_core_date_values(core)[2], FIXED_OFFICE_TIMESTAMP)

    def test_ambiguous_date_content_fails_without_replacing_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "invalid-date.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2025-01-01T00:00:00Z",
                core_properties_template=INVALID_TOKEN_AWARE_CORE_PROPERTIES,
            )
            original_digest = sha256_file(package)

            with self.assertRaisesRegex(ValueError, "unsupported core property date representation"):
                normalize_openxml_package(package, ".pptx")

            self.assertEqual(sha256_file(package), original_digest)

    def test_malformed_core_properties_fail_without_replacing_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "malformed-date.pptx"
            create_fixture_package(
                package,
                "2025-01-01T00:00:00Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2025-01-01T00:00:00Z",
                core_properties_template=MALFORMED_CORE_PROPERTIES,
            )
            original_digest = sha256_file(package)

            with self.assertRaises(ElementTree.ParseError):
                normalize_openxml_package(package, ".pptx")

            self.assertEqual(sha256_file(package), original_digest)

    def test_default_core_namespace_dates_are_normalized_byte_preservingly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "default-first.pptx"
            second = Path(directory) / "default-second.pptx"
            create_fixture_package(
                first,
                "2026-08-21T01:02:03Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2026-08-21T01:02:05Z",
                core_properties_template=DEFAULT_NAMESPACE_CORE_PROPERTIES,
            )
            create_fixture_package(
                second,
                "2026-08-21T05:06:07Z",
                (2026, 8, 21, 5, 6, 8),
                last_printed="2026-08-21T05:06:09Z",
                core_properties_template=DEFAULT_NAMESPACE_CORE_PROPERTIES,
            )

            normalize_openxml_package(first, ".pptx")
            normalize_openxml_package(second, ".pptx")

            self.assertEqual(sha256_file(first), sha256_file(second))
            with ZipFile(first) as archive:
                core = archive.read("docProps/core.xml")
            self.assertIn(b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>', core)
            self.assertIn(b"Default-core namespace comment retained byte-for-byte.", core)
            self.assertIn(b"<?phase7b preserve-default?>", core)
            self.assertIn(b"<?phase7b preserve-after-default?>", core)
            self.assertIn(b"Post-root default-core namespace comment retained byte-for-byte.", core)
            root = ElementTree.fromstring(core)
            dates = [
                element.text
                for element in root
                if element.tag in {
                    "{http://schemas.openxmlformats.org/package/2006/metadata/core-properties}lastPrinted",
                    "{http://purl.org/dc/terms/}created",
                    "{http://purl.org/dc/terms/}modified",
                }
            ]
            self.assertEqual(dates, [
                FIXED_OFFICE_TIMESTAMP,
                FIXED_OFFICE_TIMESTAMP,
                FIXED_OFFICE_TIMESTAMP,
            ])

    def test_openxml_normalization_is_binary_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.pptx"
            second = Path(directory) / "second.pptx"
            compressions = {
                "[Content_Types].xml": ZIP_STORED,
                "docProps/core.xml": ZIP_DEFLATED,
                "ppt/presentation.xml": ZIP_STORED,
            }
            create_fixture_package(
                first,
                "2026-08-21T01:02:03Z",
                (2026, 8, 21, 1, 2, 4),
                last_printed="2026-08-21T01:02:05Z",
                compression_by_name=compressions,
            )
            create_fixture_package(
                second,
                "2026-08-21T05:06:07Z",
                (2026, 8, 21, 5, 6, 8),
                last_printed="2026-08-21T05:06:09Z",
                compression_by_name=compressions,
            )

            normalize_openxml_package(first, ".pptx")
            normalize_openxml_package(second, ".pptx")

            self.assertEqual(sha256_file(first), sha256_file(second))
            with ZipFile(first) as archive:
                names = archive.namelist()
                self.assertEqual(names, sorted(names))
                self.assertEqual(len(names), len(set(names)))
                self.assertEqual(archive.comment, b"")
                self.assertTrue(all(info.date_time == FIXED_ZIP_TIME for info in archive.infolist()))
                self.assertTrue(all(info.extra == b"" and info.comment == b"" for info in archive.infolist()))
                self.assertEqual(
                    {info.filename: info.compress_type for info in archive.infolist()},
                    compressions,
                )
                core = archive.read("docProps/core.xml")
                root = ElementTree.fromstring(core)
                dates = [
                    element.text
                    for element in root
                    if element.tag in {
                        "{http://purl.org/dc/terms/}created",
                        "{http://purl.org/dc/terms/}modified",
                        "{http://schemas.openxmlformats.org/package/2006/metadata/core-properties}lastPrinted",
                    }
                ]
                self.assertEqual(dates, [
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                    FIXED_OFFICE_TIMESTAMP,
                ])
                self.assertIn(b"Retained to prove normalization", core)
                self.assertIn(b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>', core)
                self.assertIn(b"Pre-root comment retained byte-for-byte.", core)
                self.assertIn(b"<?phase7b preserve-this?>", core)
                self.assertIn(b"xmlns:dcterms=", core)

    def test_normalization_preserves_all_parts_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.docx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            with ZipFile(package) as archive:
                expected_names = archive.namelist()
                expected_presentation = archive.read("ppt/presentation.xml")
                expected_content_types = archive.read("[Content_Types].xml")

            normalize_openxml_package(package, ".docx")
            first_digest = sha256_file(package)
            normalize_openxml_package(package, ".docx")

            self.assertEqual(sha256_file(package), first_digest)
            with ZipFile(package) as archive:
                names = archive.namelist()
                self.assertEqual(names, sorted(expected_names))
                self.assertEqual(len(names), len(set(names)))
                self.assertEqual(archive.read("ppt/presentation.xml"), expected_presentation)
                self.assertEqual(archive.read("[Content_Types].xml"), expected_content_types)

    def test_normalization_rejects_the_wrong_package_suffix(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.docx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))

            with self.assertRaisesRegex(ValueError, r"expected \.pptx package"):
                normalize_openxml_package(package, ".pptx")

    def test_normalization_rejects_duplicate_or_unsafe_opc_part_names_before_writing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            duplicate = Path(directory) / "duplicate.pptx"
            create_fixture_package(duplicate, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            with ZipFile(duplicate, "a") as archive:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    archive.writestr("ppt/presentation.xml", b"duplicate")
            duplicate_digest = sha256_file(duplicate)
            with self.assertRaisesRegex(ValueError, "duplicate"):
                normalize_openxml_package(duplicate, ".pptx")
            self.assertEqual(sha256_file(duplicate), duplicate_digest)

            for unsafe_name in ("../outside.txt", "/absolute.txt", "ppt\\bad.xml", "ppt//empty.xml", "ppt/./bad.xml"):
                unsafe = Path(directory) / "unsafe.pptx"
                create_fixture_package(unsafe, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
                with ZipFile(unsafe, "a") as archive:
                    info = ZipInfo("placeholder")
                    info.filename = unsafe_name
                    archive.writestr(info, b"unsafe")
                unsafe_digest = sha256_file(unsafe)
                with self.assertRaisesRegex(ValueError, "invalid OPC part name"):
                    normalize_openxml_package(unsafe, ".pptx")
                self.assertEqual(sha256_file(unsafe), unsafe_digest)

    def test_write_and_replace_failures_preserve_target_and_unowned_sentinel(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.pptx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            original_digest = sha256_file(package)
            sentinel = package.with_name(f".{package.name}.normalized.tmp")
            sentinel.write_bytes(b"do not delete")

            with mock.patch("scripts.phase7b.office.ZipFile.writestr", side_effect=OSError("write failed")):
                with self.assertRaisesRegex(OSError, "write failed"):
                    normalize_openxml_package(package, ".pptx")
            self.assertEqual(sha256_file(package), original_digest)
            self.assertEqual(sentinel.read_bytes(), b"do not delete")

            with mock.patch("scripts.phase7b.office.os.replace", side_effect=OSError("replace failed")):
                with self.assertRaisesRegex(OSError, "replace failed"):
                    normalize_openxml_package(package, ".pptx")
            self.assertEqual(sha256_file(package), original_digest)
            self.assertEqual(sentinel.read_bytes(), b"do not delete")
            self.assertEqual(list(package.parent.glob(f".{package.name}.normalized.*.tmp")), [])

    def test_command_reports_invalid_package_input(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.pptx"
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = normalize_main(["--path", str(missing), "--suffix", ".pptx"])

            self.assertEqual(result, 2)
            self.assertIn("Office normalization failed", stderr.getvalue())

    def test_command_reports_unsupported_zip_compression(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "unsupported.pptx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            raw = bytearray(package.read_bytes())
            central = raw.index(b"PK\x01\x02")
            local = raw.index(b"PK\x03\x04")
            struct.pack_into("<H", raw, central + 10, 99)
            struct.pack_into("<H", raw, local + 8, 99)
            package.write_bytes(raw)
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = normalize_main(["--path", str(package), "--suffix", ".pptx"])

            self.assertEqual(result, 2)
            self.assertIn("Office normalization failed", stderr.getvalue())

    def test_command_does_not_hide_programming_runtime_errors(self) -> None:
        with mock.patch(
            "scripts.normalize_phase7b_office.normalize_openxml_package",
            side_effect=RuntimeError("programming defect"),
        ):
            with self.assertRaisesRegex(RuntimeError, "programming defect"):
                normalize_main(["--path", "fixture.pptx", "--suffix", ".pptx"])

    def test_canonical_manifest_hashes_relative_paths_in_stable_order(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_b = root / "sources/b.txt"
            source_a = root / "sources/a.txt"
            output = root / "outputs/result.bin"
            for path, payload in ((source_b, b"b"), (source_a, b"a"), (output, b"result")):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(payload)

            manifest = canonical_manifest(
                root,
                [source_b, source_a],
                [output],
                {"summaryPageCount": 1, "slideCount": 10, "notesCount": 10},
            )

            self.assertEqual(manifest["schemaVersion"], 1)
            self.assertEqual(manifest["generatedAt"], FIXED_OFFICE_TIMESTAMP)
            self.assertEqual(
                manifest["sources"],
                [
                    {"path": "sources/a.txt", "sha256": sha256_file(source_a)},
                    {"path": "sources/b.txt", "sha256": sha256_file(source_b)},
                ],
            )
            self.assertEqual(
                manifest["outputs"],
                [{"path": "outputs/result.bin", "sha256": sha256_file(output)}],
            )
            self.assertEqual(
                manifest["document"],
                {"notesCount": 10, "slideCount": 10, "summaryPageCount": 1},
            )

    def test_creation_ids_are_namespace_allowlisted_and_markup_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.pptx"
            second = Path(directory) / "second.pptx"

            def payload(a16_id: str, p14_id: str, rel_id: str) -> bytes:
                return (
                    '<?xml version="1.0" encoding="UTF-8"?>'
                    '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
                    'xmlns:a16="http://schemas.microsoft.com/office/drawing/2014/main" '
                    'xmlns:p14="http://schemas.microsoft.com/office/powerpoint/2010/main" '
                    'xmlns:x="urn:custom">'
                    f'<p:pic r:embed="{rel_id}"/>'
                    f'<a16:creationId id="{{{a16_id}}}"/>'
                    f'<p14:creationId val="{p14_id}"/>'
                    '<x:creationId id="business-id" val="business-value"/>'
                    '<!-- <a16:creationId id="comment-id"/> -->'
                    '<![CDATA[<p14:creationId val="cdata-value"/>]]>'
                    '</p:sld>'
                ).encode("utf-8")

            relationship = (
                b'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                b'<Relationship Id="R-one" Type="image" Target="../media/image1.png"/>'
                b'</Relationships>'
            )
            self._write_adversarial_pptx(
                first, relationship_xml=relationship, slide_xml=payload("A", "17", "R-one")
            )
            self._write_adversarial_pptx(
                second, relationship_xml=relationship, slide_xml=payload("B", "99", "R-one")
            )
            normalize_openxml_package(first, ".pptx")
            normalize_openxml_package(second, ".pptx")
            self.assertEqual(sha256_file(first), sha256_file(second))
            with ZipFile(first) as archive:
                normalized = archive.read("ppt/slides/slide1.xml")
            self.assertIn(b'<x:creationId id="business-id" val="business-value"/>', normalized)
            self.assertIn(b'<!-- <a16:creationId id="comment-id"/> -->', normalized)
            self.assertIn(b'<![CDATA[<p14:creationId val="cdata-value"/>]]>', normalized)

    def test_quoted_namespace_text_cannot_spoof_creation_or_relationship_scope(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "quoted-namespace.pptx"
            relationship = (
                b'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                b'<Relationship Id="R-one" Type="image" Target="../media/image1.png"/>'
                b'</Relationships>'
            )
            slide = (
                b'<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                b'xmlns:x="urn:custom" xmlns:o="urn:custom">'
                b'<x:creationId data=" xmlns:x=\'http://schemas.microsoft.com/office/drawing/2014/main\' '
                b'xmlns:o=\'http://schemas.openxmlformats.org/officeDocument/2006/relationships\'" '
                b'id="business-id" o:embed="R-one"/>'
                b'</p:sld>'
            )
            self._write_adversarial_pptx(
                package, relationship_xml=relationship, slide_xml=slide
            )
            normalize_openxml_package(package, ".pptx")
            with ZipFile(package) as archive:
                normalized = archive.read("ppt/slides/slide1.xml")
            self.assertIn(b'id="business-id"', normalized)
            self.assertIn(b'o:embed="R-one"', normalized)
            self.assertIn(b"xmlns:x='http://schemas.microsoft.com/office/drawing/2014/main'", normalized)
            self.assertIn(
                b"xmlns:o='http://schemas.openxmlformats.org/officeDocument/2006/relationships'",
                normalized,
            )

    def test_relationship_ids_canonicalize_for_default_and_prefixed_namespaces(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            default = Path(directory) / "default.pptx"
            prefixed = Path(directory) / "prefixed.pptx"
            default_rels = (
                b'<!--keep--><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                b'<Relationship Id="R-one" Type="image" Target="../media/image1.png"/>'
                b'</Relationships>'
            )
            prefixed_rels = (
                b'<!--keep--><r:Relationships xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships">'
                b'<r:Relationship Id="R-two" Type="image" Target="../media/image1.png"/>'
                b'</r:Relationships>'
            )
            default_slide = (
                b'<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
                b'xmlns:o="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                b'<p:pic o:embed="R-one"/><p:ext id="business">business</p:ext></p:sld>'
            )
            prefixed_slide = default_slide.replace(b'o:embed="R-one"', b'o:embed="R-two"')
            self._write_adversarial_pptx(default, relationship_xml=default_rels, slide_xml=default_slide)
            self._write_adversarial_pptx(prefixed, relationship_xml=prefixed_rels, slide_xml=prefixed_slide)
            normalize_openxml_package(default, ".pptx")
            normalize_openxml_package(prefixed, ".pptx")
            with ZipFile(default) as archive:
                default_rel = archive.read("ppt/slides/_rels/slide1.xml.rels")
                default_source = archive.read("ppt/slides/slide1.xml")
            with ZipFile(prefixed) as archive:
                prefixed_rel = archive.read("ppt/slides/_rels/slide1.xml.rels")
                prefixed_source = archive.read("ppt/slides/slide1.xml")
            self.assertIn(b'Id="rId1"', default_rel)
            self.assertIn(b'Id="rId1"', prefixed_rel)
            self.assertIn(b'o:embed="rId1"', default_source)
            self.assertIn(b'o:embed="rId1"', prefixed_source)
            self.assertIn(b'<p:ext id="business">business</p:ext>', default_source)
            self.assertIn(b'<p:ext id="business">business</p:ext>', prefixed_source)
            self.assertIn(b"<!--keep-->", default_rel)
            self.assertIn(b"<!--keep-->", prefixed_rel)

            prefixed_second = Path(directory) / "prefixed-second.pptx"
            self._write_adversarial_pptx(
                prefixed_second,
                relationship_xml=prefixed_rels.replace(b"R-two", b"R-three"),
                slide_xml=prefixed_slide.replace(b'o:embed="R-two"', b'o:embed="R-three"'),
            )
            normalize_openxml_package(prefixed_second, ".pptx")
            self.assertEqual(sha256_file(prefixed), sha256_file(prefixed_second))

    def test_duplicate_relationship_ids_are_rejected_without_replacement(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "duplicate-rels.pptx"
            relationships = (
                b'<r:Relationships xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships">'
                b'<r:Relationship Id="dup" Type="image" Target="../media/image1.png"/>'
                b'<r:Relationship Id="dup" Type="image" Target="../media/image2.png"/>'
                b'</r:Relationships>'
            )
            slide = b'<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>'
            self._write_adversarial_pptx(package, relationship_xml=relationships, slide_xml=slide)
            original = sha256_file(package)
            with self.assertRaisesRegex(ValueError, "duplicate relationship Id"):
                normalize_openxml_package(package, ".pptx")
            self.assertEqual(sha256_file(package), original)


if __name__ == "__main__":
    unittest.main()
