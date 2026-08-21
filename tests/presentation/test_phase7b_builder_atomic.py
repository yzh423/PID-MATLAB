from __future__ import annotations

from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "scripts/build_presentation.mjs"
HELPER = ROOT / "scripts/phase7b/atomic_publish.mjs"
NODE = Path("C:/Users/14228/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe")


class Phase7BBuilderAtomicTests(unittest.TestCase):
    def test_builtin_only_atomic_helper_fault_injection_suite(self) -> None:
        completed = subprocess.run(
            [str(NODE), "--test", str(ROOT / "tests/presentation/atomic_publish.test.mjs")],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    def test_builder_publishes_only_after_structure_and_normalization(self) -> None:
        source = BUILDER.read_text(encoding="utf-8")
        self.assertIn('from "./phase7b/atomic_publish.mjs";', source)
        self.assertIn("publishArtifactSetAtomically", source)
        self.assertIn("validatePptxStructure", source)
        self.assertIn("validate_phase7b_pptx.py", source)
        self.assertIn("normalizePptx", source)
        self.assertIn("phase7b_layout_report.json", source)
        direct_save = re.search(r"exportPptx\([^)]*\)\)\.save\(output\)", source)
        self.assertIsNone(direct_save, "builder must never save Artifact Tool output directly over the reviewed final")
        helper = HELPER.read_text(encoding="utf-8")
        for builtin in ('node:crypto', 'node:fs/promises', 'node:path'):
            self.assertIn(builtin, helper)
        self.assertNotIn("@oai/artifact-tool", helper)


if __name__ == "__main__":
    unittest.main()
