from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from scripts.phase7b.audit import Phase7BAuditError, validate_phase7b_audit
from scripts.phase7b.evidence import sha256_file


ROOT = Path(__file__).resolve().parents[2]
CANONICAL_AUDIT = ROOT / "docs/presentation/PHASE7B_CLAIM_AUDIT.json"
VERIFY = ROOT / "scripts/verify_phase7b.ps1"
REQUIRED = (
    "docs/presentation/phase7b_template.json",
    "results/presentation/phase7b_package.json",
    "docs/presentation/phase7b_build_manifest.json",
    "docs/presentation/phase7b_layout_report.json",
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
                {"claim_id": index, "status": "exact_match"}
                for index in range(1, 12)
            ],
            "reproducibility_ledger": {
                "manifest_path": "docs/presentation/phase7b_build_manifest.json",
                "package_path": "results/presentation/phase7b_package.json",
                "claim_group_count": 11,
            },
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

    def test_canonical_audit_is_intentionally_blocked_until_fresh_review(self) -> None:
        with self.assertRaisesRegex(Phase7BAuditError, "fresh|BLOCKED"):
            validate_phase7b_audit(ROOT, CANONICAL_AUDIT, is_ancestor=lambda commit: True)

    def test_verifier_invokes_canonical_audit_gate_after_manifest_write(self) -> None:
        source = VERIFY.read_text(encoding="utf-8")
        manifest_index = source.index("Write-Phase7BManifest")
        audit_index = source.rindex("verify_phase7b_audit.py")
        self.assertGreater(audit_index, manifest_index)
        self.assertIn("PHASE7B_CLAIM_AUDIT.json", source)


if __name__ == "__main__":
    unittest.main()
