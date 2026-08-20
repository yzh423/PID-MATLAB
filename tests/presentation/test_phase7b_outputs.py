from __future__ import annotations

import json
from pathlib import Path
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
        run_phase7b_build(ROOT)
        actual = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
