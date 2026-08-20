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
"""


def create_fixture_package(
    path: Path,
    timestamp: str,
    zip_time: tuple[int, int, int, int, int, int],
    *,
    last_printed: str | None = None,
    compression_by_name: dict[str, int] | None = None,
    core_properties_template: str = CORE_PROPERTIES,
) -> None:
    """Create a valid minimal Open XML-like package with volatile ZIP metadata."""
    entries = {
        "[Content_Types].xml": b"<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
        "docProps/core.xml": core_properties_template.format(
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


class Phase7BOfficeTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
