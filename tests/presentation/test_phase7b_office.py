from __future__ import annotations

from pathlib import Path
from contextlib import redirect_stderr
from io import StringIO
import tempfile
import unittest
from xml.etree import ElementTree
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from scripts.phase7b.office import (
    FIXED_OFFICE_TIMESTAMP,
    FIXED_ZIP_TIME,
    canonical_manifest,
    normalize_openxml_package,
    sha256_file,
)
from scripts.normalize_phase7b_office import main as normalize_main


CORE_PROPERTIES = """<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">
  <!-- Retained to prove normalization does not remove valid XML content. -->
  <dc:creator>Fixture Author</dc:creator>
  <cp:lastModifiedBy>Fixture Editor</cp:lastModifiedBy>
  <cp:revision>7</cp:revision>
  <dcterms:created xsi:type=\"dcterms:W3CDTF\">{timestamp}</dcterms:created>
  <dcterms:modified xsi:type=\"dcterms:W3CDTF\">{timestamp}</dcterms:modified>
</cp:coreProperties>
"""


def create_fixture_package(path: Path, timestamp: str, zip_time: tuple[int, int, int, int, int, int]) -> None:
    """Create a valid minimal Open XML-like package with volatile ZIP metadata."""
    entries = {
        "[Content_Types].xml": b"<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
        "docProps/core.xml": CORE_PROPERTIES.format(timestamp=timestamp).encode("utf-8"),
        "ppt/presentation.xml": b"<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"/>"
    }
    with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
        archive.comment = b"volatile package comment"
        for name in reversed(sorted(entries)):
            info = ZipInfo(name, zip_time)
            info.compress_type = ZIP_DEFLATED
            info.extra = b"\xfe\xca\x04\x00meta"
            info.comment = b"volatile entry comment"
            archive.writestr(info, entries[name])


class Phase7BOfficeTests(unittest.TestCase):
    def test_openxml_normalization_is_binary_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            first = Path(directory) / "first.pptx"
            second = Path(directory) / "second.pptx"
            create_fixture_package(first, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            create_fixture_package(second, "2026-08-21T05:06:07Z", (2026, 8, 21, 5, 6, 8))

            normalize_openxml_package(first, ".pptx")
            normalize_openxml_package(second, ".pptx")

            self.assertEqual(sha256_file(first), sha256_file(second))
            with ZipFile(first) as archive:
                self.assertEqual(archive.namelist(), sorted(archive.namelist()))
                self.assertEqual(archive.comment, b"")
                self.assertTrue(all(info.date_time == FIXED_ZIP_TIME for info in archive.infolist()))
                self.assertTrue(all(info.extra == b"" and info.comment == b"" for info in archive.infolist()))
                self.assertTrue(all(info.compress_type == ZIP_DEFLATED for info in archive.infolist()))
                core = archive.read("docProps/core.xml")
                root = ElementTree.fromstring(core)
                dates = [
                    element.text
                    for element in root
                    if element.tag in {
                        "{http://purl.org/dc/terms/}created",
                        "{http://purl.org/dc/terms/}modified",
                    }
                ]
                self.assertEqual(dates, [FIXED_OFFICE_TIMESTAMP, FIXED_OFFICE_TIMESTAMP])
                self.assertIn(b"Retained to prove normalization", core)
                self.assertIn(b"xmlns:dcterms=", core)

    def test_normalization_preserves_all_parts_and_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.docx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
            with ZipFile(package) as archive:
                expected_names = set(archive.namelist())
                expected_presentation = archive.read("ppt/presentation.xml")
                expected_content_types = archive.read("[Content_Types].xml")

            normalize_openxml_package(package, ".docx")
            first_digest = sha256_file(package)
            normalize_openxml_package(package, ".docx")

            self.assertEqual(sha256_file(package), first_digest)
            with ZipFile(package) as archive:
                self.assertEqual(set(archive.namelist()), expected_names)
                self.assertEqual(archive.read("ppt/presentation.xml"), expected_presentation)
                self.assertEqual(archive.read("[Content_Types].xml"), expected_content_types)

    def test_normalization_rejects_the_wrong_package_suffix(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.docx"
            create_fixture_package(package, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))

            with self.assertRaisesRegex(ValueError, r"expected \.pptx package"):
                normalize_openxml_package(package, ".pptx")

    def test_command_reports_invalid_package_input(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "missing.pptx"
            stderr = StringIO()
            with redirect_stderr(stderr):
                result = normalize_main(["--path", str(missing), "--suffix", ".pptx"])

            self.assertEqual(result, 2)
            self.assertIn("Office normalization failed", stderr.getvalue())

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
