from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import unittest

from scripts.phase7b.evidence import sha256_file


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs" / "presentation" / "phase7b_build_manifest.json"
VERIFY = ROOT / "scripts" / "verify_phase7b.ps1"
FINAL_OUTPUTS = (
    "presentation/final_presentation.pptx",
    "docs/summary/research_summary.docx",
    "docs/summary/research_summary.pdf",
)
REBUILD_DIR = ROOT / "tmp" / "phase7b" / "rebuild"


def run_phase7b_build(root: Path) -> None:
    completed = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(root / "scripts" / "verify_phase7b.ps1"),
            "-SkipTests",
        ],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode:
        raise AssertionError(
            "Phase 7B reproducibility build failed:\n"
            f"stdout:\n{completed.stdout}\n"
            f"stderr:\n{completed.stderr}"
        )


class Phase7BOutputTests(unittest.TestCase):
    def test_verifier_counts_the_rebuilt_docx_with_owned_word_and_cleans_up(self) -> None:
        source = VERIFY.read_text(encoding="utf-8")
        self.assertIn("OpenNoRepairDialog", source)
        self.assertIn("Repaginate()", source)
        self.assertIn("ComputeStatistics(2)", source)
        self.assertNotIn("'docxPages': 1", source)
        self.assertIn("Remove-Item -LiteralPath $rebuildRoot -Force -Recurse", source)

    def test_verifier_orders_manifest_paths_with_ordinal_comparison(self) -> None:
        source = VERIFY.read_text(encoding="utf-8")
        self.assertIn("Get-OrdinalSortedRecords", source)
        self.assertIn("[System.StringComparer]::Ordinal.Compare", source)
        self.assertNotIn("Sort-Object path", source)
        function_match = re.search(
            r"(function Get-OrdinalSortedRecords\s*\{.*?\n\}\r?\n\r?\n)(?=function Write-Phase7BManifest)",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(function_match)
        assert function_match is not None
        paths = [
            "scripts/build_research_summary_pdf.py",
            "scripts/build_research_summary.py",
            "scripts/a_b.py",
            "scripts/a.b.py",
            "scripts/A.py",
            "scripts/a.py",
        ]
        command = (
            function_match.group(1)
            + "$records = @(" + ",".join(
                f"[PSCustomObject]@{{path='{path}';sha256='x'}}" for path in paths
            ) + ")\n"
            + "Get-OrdinalSortedRecords -Records $records | ForEach-Object { $_.path }\n"
        )
        completed = subprocess.run(
            ["powershell", "-NoProfile", "-Command", command],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.splitlines(), sorted(paths))

    def test_manifest_hashes_all_inputs_and_outputs(self) -> None:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["generatedAt"], "2026-08-21T00:00:00Z")
        self.assertEqual(
            manifest["document"],
            {"notesCount": 10, "slideCount": 10, "summaryPageCount": 1},
        )
        for group in ("sources", "outputs"):
            records = manifest[group]
            self.assertEqual([record["path"] for record in records], sorted(record["path"] for record in records))
            self.assertEqual(len(records), len({record["path"] for record in records}))
            for record in records:
                with self.subTest(group=group, path=record["path"]):
                    self.assertNotIn("\\", record["path"])
                    self.assertFalse(Path(record["path"]).is_absolute())
                    self.assertNotIn("tmp/", record["path"])
                    path = ROOT / record["path"]
                    self.assertTrue(path.is_file(), record["path"])
                    self.assertEqual(record["sha256"], sha256_file(path), record["path"])
        self.assertEqual(
            [record["path"] for record in manifest["outputs"]],
            sorted(FINAL_OUTPUTS),
        )

    def test_two_phase7b_builds_are_hash_identical(self) -> None:
        expected = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
        try:
            run_phase7b_build(ROOT)
            first = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
            run_phase7b_build(ROOT)
            second = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
        finally:
            self.assertFalse(REBUILD_DIR.exists(), "task-owned DOCX rebuild directory must be removed")
        self.assertEqual(first, expected)
        self.assertEqual(second, first)


if __name__ == "__main__":
    unittest.main()
