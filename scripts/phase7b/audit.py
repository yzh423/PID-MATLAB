"""Fail-closed validation for the canonical fresh Phase 7B claim audit."""

from __future__ import annotations

from collections.abc import Callable, Mapping
import json
from pathlib import Path, PurePosixPath

from scripts.phase7b.evidence import sha256_file


REQUIRED_AUDITED_INPUTS = {
    "docs/presentation/phase7b_template.json",
    "results/presentation/phase7b_package.json",
    "docs/presentation/phase7b_build_manifest.json",
    "docs/presentation/phase7b_layout_report.json",
    "presentation/final_presentation.pptx",
    "docs/summary/research_summary.docx",
    "docs/summary/research_summary.pdf",
}


class Phase7BAuditError(ValueError):
    """Raised when the canonical audit cannot authorize Phase 7B delivery."""


def _repo_path(root: Path, value: str) -> Path:
    pure = PurePosixPath(value)
    if (
        not value
        or "\\" in value
        or pure.is_absolute()
        or Path(value).is_absolute()
        or ":" in pure.parts[0]
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        raise Phase7BAuditError(f"audit input path must be repository-relative: {value}")
    path = root / Path(*pure.parts)
    try:
        path.resolve(strict=True).relative_to(root)
    except (OSError, ValueError) as exception:
        raise Phase7BAuditError(f"audit input escapes the repository: {value}") from exception
    return path


def validate_phase7b_audit(
    root: Path,
    audit_path: Path,
    *,
    is_ancestor: Callable[[str], bool],
) -> dict[str, object]:
    root = root.resolve(strict=True)
    try:
        audit = json.loads(audit_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BAuditError("canonical Phase 7B audit is missing or invalid") from exception
    if not isinstance(audit, dict) or audit.get("schemaVersion") != 1:
        raise Phase7BAuditError("canonical Phase 7B audit schema is unsupported")
    if audit.get("audit_skill") != "paper-claim-audit":
        raise Phase7BAuditError("canonical Phase 7B audit skill is invalid")
    if audit.get("verdict") != "PASS":
        raise Phase7BAuditError(
            f"canonical Phase 7B audit requires a fresh PASS; got {audit.get('verdict')}"
        )
    audited_commit = audit.get("audited_commit")
    if (
        not isinstance(audited_commit, str)
        or len(audited_commit) != 40
        or any(character not in "0123456789abcdef" for character in audited_commit.lower())
        or not is_ancestor(audited_commit)
    ):
        raise Phase7BAuditError("canonical Phase 7B audited commit violates ancestry policy")

    hashes = audit.get("audited_input_hashes")
    if not isinstance(hashes, Mapping):
        raise Phase7BAuditError("canonical Phase 7B audit requires audited_input_hashes")
    if not REQUIRED_AUDITED_INPUTS.issubset(hashes):
        missing = sorted(REQUIRED_AUDITED_INPUTS - set(hashes))
        raise Phase7BAuditError(f"canonical Phase 7B audit is missing required hashes: {missing}")
    for relative, expected in hashes.items():
        if not isinstance(relative, str) or not isinstance(expected, str) or not expected.startswith("sha256:"):
            raise Phase7BAuditError("canonical Phase 7B audit hash records are malformed")
        path = _repo_path(root, relative)
        if sha256_file(path) != expected.removeprefix("sha256:"):
            raise Phase7BAuditError(f"canonical Phase 7B audit hash is stale: {relative}")

    details = audit.get("details")
    if not isinstance(details, Mapping):
        raise Phase7BAuditError("canonical Phase 7B audit details are missing")
    zero_fields = (
        "ambiguous_mapping", "missing_evidence", "unsupported_claims",
        "warn_count", "fail_count",
    )
    if details.get("total_claims") != 11 or any(details.get(field) != 0 for field in zero_fields):
        raise Phase7BAuditError("canonical Phase 7B audit must contain exactly 11 groups and zero findings")
    if details.get("exact_match", 0) + details.get("rounding_ok", 0) != 11:
        raise Phase7BAuditError("canonical Phase 7B audit claim status counts are inconsistent")
    if details.get("mismatches") != []:
        raise Phase7BAuditError("canonical Phase 7B audit contains mismatches")
    groups = details.get("claim_groups")
    if (
        not isinstance(groups, list)
        or len(groups) != 11
        or {group.get("claim_id") for group in groups if isinstance(group, Mapping)} != set(range(1, 12))
        or any(group.get("status") not in {"exact_match", "rounding_ok"} for group in groups if isinstance(group, Mapping))
    ):
        raise Phase7BAuditError("canonical Phase 7B audit claim groups are invalid")
    ledger = details.get("reproducibility_ledger")
    if not isinstance(ledger, Mapping) or ledger.get("claim_group_count") != 11:
        raise Phase7BAuditError("canonical Phase 7B audit lacks a reproducible minimal ledger")
    trace = audit.get("trace")
    if not isinstance(trace, Mapping) or trace.get("retention") != "ephemeral":
        raise Phase7BAuditError("canonical Phase 7B audit trace provenance is invalid")
    trace_path = trace.get("path")
    if not isinstance(trace_path, str) or Path(trace_path).is_absolute() or "\\" in trace_path:
        raise Phase7BAuditError("canonical Phase 7B audit trace path must be repository-relative")
    return audit
