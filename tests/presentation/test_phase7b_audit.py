from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from scripts.phase7b import audit as audit_module
from scripts.phase7b.audit import Phase7BAuditError, validate_phase7b_audit
from scripts.phase7b.evidence import sha256_file


ROOT = Path(__file__).resolve().parents[2]
audited_commit_is_current_or_audit_only_parent = getattr(
    audit_module,
    "audited_commit_is_current_or_audit_only_parent",
    lambda root, commit: False,
)
VERIFY = ROOT / "scripts/verify_phase7b.ps1"
REQUIRED = (
    "docs/presentation/phase7b_template.json",
    "results/presentation/phase7b_package.json",
    "docs/presentation/phase7b_build_manifest.json",
    "docs/presentation/phase7b_layout_report.json",
    "docs/presentation/phase7b_raw_evidence.json",
    "docs/presentation/phase7b_toolchain.json",
    "presentation/final_presentation.pptx",
    "docs/summary/research_summary.docx",
    "docs/summary/research_summary.pdf",
)


def valid_audit() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "audit_skill": "paper-claim-audit",
        "verdict": "PASS",
        "reason_code": "all_numbers_match",
        "summary": "All eleven groups reconcile.",
        "audited_commit": "a" * 40,
        "audited_input_hashes": {
            path: f"sha256:{sha256_file(ROOT / path)}" for path in REQUIRED
        },
        "trace": {
            "retention": "ephemeral",
            "path": ".aris/traces/paper-claim-audit/fresh-run/",
        },
        "generated_at": "2026-08-21T00:00:00Z",
        "details": {
            "total_claims": 11,
            "exact_match": 6,
            "rounding_ok": 5,
            "ambiguous_mapping": 0,
            "missing_evidence": 0,
            "unsupported_claims": 0,
            "warn_count": 0,
            "fail_count": 0,
            "mismatches": [],
            "claim_groups": [
                {
                    "claim_id": index,
                    "status": "exact_match" if index <= 6 else "rounding_ok",
                    "atomic_claims": 1,
                    "location": f"presentation/final_presentation.pptx slide {index}",
                    "paper_text": f"Audited claim group {index}",
                    "evidence": f"Evidence mapping for claim group {index}",
                }
                for index in range(1, 12)
            ],
            "reproducibility_ledger": {
                "manifest_path": "docs/presentation/phase7b_build_manifest.json",
                "package_path": "results/presentation/phase7b_package.json",
                "raw_ledger_path": "docs/presentation/phase7b_raw_evidence.json",
                "claim_group_count": 11,
                "atomic_claim_checks": 11,
                "template_package_pptx": "recomputed",
                "package_docx_pdf": "recomputed",
                "source_blocks": "recomputed",
            },
            "atomic_claim_checks": 11,
            "test_summary": {"suite": "PASS"},
            "visual_summary": {"pptx_render": "PASS", "findings": []},
        },
    }


class Phase7BAuditGateTests(unittest.TestCase):
    def _validate(self, audit: dict[str, object]) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            path.write_text(json.dumps(audit), encoding="utf-8")
            validate_phase7b_audit(
                ROOT,
                path,
                is_ancestor=lambda commit: commit == "a" * 40,
            )

    def test_valid_pass_audit_with_exact_eleven_groups_is_accepted(self) -> None:
        self._validate(valid_audit())

    def test_warn_missing_tampered_and_stale_audits_fail_closed(self) -> None:
        cases = {}
        warn = valid_audit()
        warn["verdict"] = "WARN"
        cases["WARN"] = warn
        missing = valid_audit()
        del missing["audited_input_hashes"]["presentation/final_presentation.pptx"]
        cases["missing"] = missing
        tampered = valid_audit()
        tampered["details"]["warn_count"] = 1
        cases["finding"] = tampered
        stale = valid_audit()
        stale["audited_input_hashes"]["docs/summary/research_summary.pdf"] = "sha256:" + "0" * 64
        cases["stale"] = stale
        absolute = valid_audit()
        absolute["audited_input_hashes"][str(ROOT / "docs/summary/research_summary.pdf")] = absolute["audited_input_hashes"].pop(
            "docs/summary/research_summary.pdf"
        )
        cases["absolute"] = absolute
        wrong_commit = valid_audit()
        wrong_commit["audited_commit"] = "b" * 40
        cases["commit"] = wrong_commit

        for label, audit in cases.items():
            with self.subTest(label=label), self.assertRaises(Phase7BAuditError):
                self._validate(audit)

    def test_intended_pass_audit_for_current_head_is_accepted(self) -> None:
        current = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
            capture_output=True, text=True,
        ).stdout.strip()
        audit = valid_audit()
        audit["audited_commit"] = current
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "audit.json"
            path.write_text(json.dumps(audit), encoding="utf-8")
            validate_phase7b_audit(
                ROOT,
                path,
                is_ancestor=lambda commit: audited_commit_is_current_or_audit_only_parent(ROOT, commit),
            )

    def test_claim_group_counters_content_and_atomic_totals_are_derived_not_trusted(self) -> None:
        cases = {}
        swapped = valid_audit()
        swapped["details"]["exact_match"] = 5
        swapped["details"]["rounding_ok"] = 6
        cases["counter swap"] = swapped
        hollow = valid_audit()
        del hollow["details"]["claim_groups"][0]["evidence"]
        cases["hollow group"] = hollow
        zero_atomic = valid_audit()
        zero_atomic["details"]["claim_groups"][0]["atomic_claims"] = 0
        cases["zero atomic group"] = zero_atomic
        wrong_atomic_total = valid_audit()
        wrong_atomic_total["details"]["atomic_claim_checks"] = 12
        cases["wrong atomic total"] = wrong_atomic_total
        wrong_ledger_total = valid_audit()
        wrong_ledger_total["details"]["reproducibility_ledger"]["atomic_claim_checks"] = 12
        cases["wrong ledger total"] = wrong_ledger_total
        missing_reproducibility = valid_audit()
        del missing_reproducibility["details"]["reproducibility_ledger"]["raw_ledger_path"]
        cases["missing reproducibility record"] = missing_reproducibility
        inconsistent_findings = valid_audit()
        inconsistent_findings["details"]["mismatches"] = [{"claim_id": 1}]
        cases["inconsistent findings"] = inconsistent_findings

        for label, audit in cases.items():
            with self.subTest(label=label), self.assertRaisesRegex(
                Phase7BAuditError,
                "claim|atomic|ledger|finding|reproduc",
            ):
                self._validate(audit)

    def test_commit_policy_accepts_only_current_or_audit_only_immediate_parent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "phase7b@example.invalid"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Phase 7B Test"], cwd=root, check=True)
            product = root / "product.txt"
            product.write_text("reviewed\n", encoding="utf-8")
            subprocess.run(["git", "add", "product.txt"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "product"], cwd=root, check=True)
            product_commit = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, check=True,
                capture_output=True, text=True,
            ).stdout.strip()
            audit_dir = root / "docs/presentation"
            audit_dir.mkdir(parents=True)
            (audit_dir / "PHASE7B_CLAIM_AUDIT.json").write_text("{}\n", encoding="utf-8")
            (audit_dir / "PHASE7B_CLAIM_AUDIT.md").write_text("audit\n", encoding="utf-8")
            subprocess.run(["git", "add", "docs/presentation"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "audit"], cwd=root, check=True)
            audit_commit = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, check=True,
                capture_output=True, text=True,
            ).stdout.strip()

            self.assertTrue(audited_commit_is_current_or_audit_only_parent(root, audit_commit))
            self.assertTrue(audited_commit_is_current_or_audit_only_parent(root, product_commit))

            product.write_text("changed\n", encoding="utf-8")
            subprocess.run(["git", "add", "product.txt"], cwd=root, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "product change"], cwd=root, check=True)
            current = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=root, check=True,
                capture_output=True, text=True,
            ).stdout.strip()
            self.assertTrue(audited_commit_is_current_or_audit_only_parent(root, current))
            self.assertFalse(audited_commit_is_current_or_audit_only_parent(root, audit_commit))
            self.assertFalse(audited_commit_is_current_or_audit_only_parent(root, product_commit))

    def test_verifier_invokes_canonical_audit_gate_after_manifest_write(self) -> None:
        source = VERIFY.read_text(encoding="utf-8")
        manifest_index = source.index("Write-Phase7BManifest")
        audit_index = source.rindex("verify_phase7b_audit.py")
        self.assertGreater(audit_index, manifest_index)
        self.assertIn("PHASE7B_CLAIM_AUDIT.json", source)


if __name__ == "__main__":
    unittest.main()
