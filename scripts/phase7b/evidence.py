"""Build a deterministic Phase 7B package from admitted Phase 7A evidence."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import hashlib
import json
from pathlib import Path
import tempfile

from scripts.reporting.evidence import EvidenceError, load_evidence, resolve_tokens


FIXED_GENERATED_AT = "2026-08-21T00:00:00Z"
SUMMARY_FIELDS = (
    "title", "takeaway", "problem", "method", "results", "figure",
    "figureCaption", "significance", "limitations", "nextSteps", "sources",
)


class Phase7BEvidenceError(ValueError):
    """Raised when Phase 7A cannot support the Phase 7B package."""


def sha256_file(path: Path) -> str:
    """Return the SHA-256 digest for one source file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_phase7b_template(path: Path) -> dict[str, object]:
    """Load the controlled Phase 7B template as UTF-8 JSON."""
    if not path.is_file():
        raise Phase7BEvidenceError(f"Phase 7B template does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BEvidenceError(
            f"Phase 7B template is not valid UTF-8 JSON: {path}"
        ) from exception
    if not isinstance(value, dict):
        raise Phase7BEvidenceError("Phase 7B template root must be a JSON object")
    return value


def _resolve_value(
    value: object, evidence: Mapping[str, object], used: set[str]
) -> object:
    if isinstance(value, str):
        rendered, paths = resolve_tokens(value, evidence)
        used.update(paths)
        return rendered
    if isinstance(value, list):
        return [_resolve_value(item, evidence, used) for item in value]
    if isinstance(value, dict):
        return {key: _resolve_value(item, evidence, used) for key, item in value.items()}
    return value


def _load_phase7a_manifest(path: Path) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BEvidenceError(
            "Phase 7A build manifest is not valid UTF-8 JSON"
        ) from exception
    if not isinstance(value, dict) or not isinstance(value.get("sources"), list):
        raise Phase7BEvidenceError("Phase 7A build manifest requires a sources list")
    return value


def _safe_source_path(root: Path, relative_path: str) -> Path:
    candidate = root / relative_path
    try:
        candidate.resolve().relative_to(root)
    except ValueError as exception:
        raise Phase7BEvidenceError(
            f"Phase 7A source path is outside the project root: {relative_path}"
        ) from exception
    return candidate


def _admit_phase7a_sources(
    root: Path, manifest: Mapping[str, object]
) -> list[dict[str, str]]:
    """Verify every frozen source record before resolving any claim."""
    records = manifest["sources"]
    if not isinstance(records, Sequence):
        raise Phase7BEvidenceError("Phase 7A build manifest requires a sources list")
    admitted: list[dict[str, str]] = []
    for record in records:
        if not isinstance(record, Mapping):
            raise Phase7BEvidenceError("Phase 7A source record must be an object")
        relative_path = record.get("path")
        expected_digest = record.get("sha256")
        if not isinstance(relative_path, str) or not isinstance(expected_digest, str):
            raise Phase7BEvidenceError(
                "Phase 7A source record requires path and sha256 strings"
            )
        source_path = _safe_source_path(root, relative_path)
        if not source_path.is_file():
            raise Phase7BEvidenceError(
                f"Phase 7A source does not exist: {relative_path}"
            )
        actual_digest = sha256_file(source_path)
        if actual_digest != expected_digest:
            kind = (
                "evidence" if relative_path == "results/report/report_evidence.json"
                else "figure" if relative_path.startswith("results/figures/")
                else "source"
            )
            raise Phase7BEvidenceError(
                f"Phase 7A {kind} hash mismatch: {relative_path}"
            )
        admitted.append({"path": relative_path, "sha256": actual_digest})
    return admitted


def _require_mapping(value: object, label: str) -> Mapping[str, object]:
    if not isinstance(value, Mapping):
        raise Phase7BEvidenceError(f"Phase 7A evidence requires {label} object")
    return value


def _require_rows(value: object, label: str) -> list[Mapping[str, object]]:
    if not isinstance(value, list) or not all(isinstance(row, Mapping) for row in value):
        raise Phase7BEvidenceError(f"Phase 7A evidence requires {label} rows")
    return value


def _require_nonnegative_int(value: object, label: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise Phase7BEvidenceError(f"Phase 7A evidence requires {label} non-negative integer")
    return value


def _derive_phase7b_values(evidence: Mapping[str, object]) -> dict[str, object]:
    """Derive presentation counts only after validating their Phase 7A rows."""
    system = _require_mapping(evidence.get("system"), "system")
    link_lengths = system.get("linkLengthsM")
    if not isinstance(link_lengths, list) or not link_lengths:
        raise Phase7BEvidenceError("Phase 7A evidence requires system link lengths")

    deterministic = _require_mapping(evidence.get("deterministic"), "deterministic")
    controller_rows = _require_rows(deterministic.get("summaryRows"), "deterministic summary")
    controllers = {
        row.get("Controller") for row in controller_rows if isinstance(row.get("Controller"), str)
    }
    if len(controllers) != len(controller_rows) or not controllers:
        raise Phase7BEvidenceError("Phase 7A evidence requires unique controller summary rows")

    stochastic = _require_mapping(evidence.get("stochastic"), "stochastic")
    stochastic_rows = _require_rows(stochastic.get("summaryRows"), "stochastic summary")
    isolated_rows = [
        row for row in stochastic_rows
        if isinstance(row.get("Scenario"), str) and row["Scenario"].startswith("noise-")
    ]
    combined_rows = [
        row for row in stochastic_rows if row.get("Scenario") == "combined-stochastic"
    ]
    if not isolated_rows or len(combined_rows) != len(controllers):
        raise Phase7BEvidenceError("Phase 7A evidence cannot derive stochastic presentation counts")

    def derive_cell(rows: list[Mapping[str, object]], name: str, expected_success: str) -> dict[str, int]:
        trial_counts = {
            _require_nonnegative_int(row.get("TrialCount"), f"{name} trial count")
            for row in rows
        }
        success_counts = {
            _require_nonnegative_int(row.get("SuccessCount"), f"{name} success count")
            for row in rows
        }
        if len(trial_counts) != 1 or len(success_counts) != 1:
            raise Phase7BEvidenceError(
                f"Phase 7A evidence has inconsistent {name} stochastic counts"
            )
        trial_count = trial_counts.pop()
        success_count = success_counts.pop()
        if expected_success == "all" and success_count != trial_count:
            raise Phase7BEvidenceError(
                "Phase 7A evidence does not support isolated-noise success claim"
            )
        if expected_success == "none" and success_count != 0:
            raise Phase7BEvidenceError(
                "Phase 7A evidence does not support combined-stress failure claim"
            )
        return {"successCount": success_count, "trialCount": trial_count}

    cartesian = _require_mapping(evidence.get("cartesian"), "cartesian")
    cartesian_rows = _require_rows(cartesian.get("runRows"), "cartesian run")
    completed_rows = [row for row in cartesian_rows if row.get("Status") == "completed"]
    successful_rows = [row for row in completed_rows if row.get("Success") is True]
    run_count = _require_nonnegative_int(cartesian.get("runCount"), "cartesian run count")
    if len(cartesian_rows) != run_count:
        raise Phase7BEvidenceError("Phase 7A evidence cartesian row count does not match runCount")

    return {
        "linkCount": len(link_lengths),
        "controllerCount": len(controllers),
        "stochastic": {
            "isolatedNoise": derive_cell(isolated_rows, "isolated-noise", "all"),
            "combinedStress": derive_cell(combined_rows, "combined-stress", "none"),
        },
        "cartesian": {
            "successCount": len(successful_rows),
            "completedRunCount": len(completed_rows),
            "failureCount": len(completed_rows) - len(successful_rows),
        },
    }


def _validate_template_shape(resolved: Mapping[str, object]) -> tuple[dict[str, object], list[dict[str, object]], dict[str, object]]:
    if resolved.get("schemaVersion") != 1:
        raise Phase7BEvidenceError("Phase 7B template schemaVersion must equal 1")
    if resolved.get("generatedAt") != FIXED_GENERATED_AT:
        raise Phase7BEvidenceError("Phase 7B generatedAt must be frozen")
    deck_value = resolved.get("deck")
    if not isinstance(deck_value, dict) or not isinstance(deck_value.get("title"), str):
        raise Phase7BEvidenceError("Phase 7B template requires a deck title")
    slide_values = deck_value.get("slides")
    if not isinstance(slide_values, list) or not all(isinstance(slide, dict) for slide in slide_values):
        raise Phase7BEvidenceError("Phase 7B template requires a deck slides list")
    slides: list[dict[str, object]] = slide_values
    if len(slides) != 10 or len({slide.get("id") for slide in slides}) != 10:
        raise Phase7BEvidenceError("Phase 7B requires exactly 10 unique slides")
    for slide in slides:
        if not isinstance(slide.get("id"), str) or not isinstance(slide.get("title"), str):
            raise Phase7BEvidenceError("Phase 7B slide requires id and title")
        if not isinstance(slide.get("presenterNote"), str):
            raise Phase7BEvidenceError("Phase 7B slide requires presenterNote")
        sources = slide.get("sources")
        if not isinstance(sources, list) or not sources or not all(isinstance(source, str) for source in sources):
            raise Phase7BEvidenceError("Phase 7B slide requires non-empty sources")

    summary_value = resolved.get("summary")
    if not isinstance(summary_value, dict) or set(summary_value) != set(SUMMARY_FIELDS):
        raise Phase7BEvidenceError("Phase 7B summary has an invalid shape")
    required_text_fields = set(SUMMARY_FIELDS) - {"results", "sources"}
    if not all(isinstance(summary_value[field], str) for field in required_text_fields):
        raise Phase7BEvidenceError("Phase 7B summary requires text fields")
    if not isinstance(summary_value["results"], list) or not all(
        isinstance(result, dict)
        and isinstance(result.get("value"), str)
        and isinstance(result.get("label"), str)
        for result in summary_value["results"]
    ):
        raise Phase7BEvidenceError("Phase 7B summary requires result records")
    if not isinstance(summary_value["sources"], list) or not summary_value["sources"] or not all(
        isinstance(source, str) for source in summary_value["sources"]
    ):
        raise Phase7BEvidenceError("Phase 7B summary requires non-empty sources")
    return deck_value, slides, summary_value


def _admit_selected_figures(
    root: Path,
    slides: Sequence[Mapping[str, object]],
    summary: Mapping[str, object],
    admitted_sources: Sequence[Mapping[str, str]],
) -> list[dict[str, str]]:
    admitted = {record["path"]: record["sha256"] for record in admitted_sources}
    figure_paths = [
        slide.get("figure") for slide in slides if isinstance(slide.get("figure"), str)
    ]
    figure_paths.append(summary["figure"])
    selected: list[dict[str, str]] = []
    for path in dict.fromkeys(figure_paths):
        if not isinstance(path, str):
            raise Phase7BEvidenceError("Phase 7B figure path must be a string")
        file_path = _safe_source_path(root, path)
        if path not in admitted or not file_path.is_file():
            raise Phase7BEvidenceError(f"figure is not admitted by Phase 7A: {path}")
        digest = sha256_file(file_path)
        if digest != admitted[path]:
            raise Phase7BEvidenceError(f"Phase 7A figure hash mismatch: {path}")
        selected.append({"path": path, "sha256": digest})
    return selected


def build_phase7b_package(root: Path) -> dict[str, object]:
    """Resolve the frozen template and admit all Phase 7A source boundaries."""
    root = root.resolve(strict=True)
    manifest_path = root / "docs/report/build_manifest.json"
    manifest = _load_phase7a_manifest(manifest_path)
    admitted_sources = _admit_phase7a_sources(root, manifest)
    evidence_path = root / "results/report/report_evidence.json"
    evidence_record = next(
        (record for record in admitted_sources if record["path"] == "results/report/report_evidence.json"),
        None,
    )
    if evidence_record is None:
        raise Phase7BEvidenceError("Phase 7A build manifest does not admit report evidence")
    try:
        evidence = load_evidence(evidence_path)
    except EvidenceError as exception:
        raise Phase7BEvidenceError(f"Phase 7A evidence is invalid: {exception}") from exception
    resolved_evidence = dict(evidence)
    resolved_evidence["phase7b"] = _derive_phase7b_values(evidence)
    template = load_phase7b_template(root / "docs/presentation/phase7b_template.json")
    used: set[str] = set()
    try:
        resolved = _resolve_value(template, resolved_evidence, used)
    except EvidenceError as exception:
        raise Phase7BEvidenceError(f"Phase 7B token resolution failed: {exception}") from exception
    if not isinstance(resolved, dict):
        raise Phase7BEvidenceError("Phase 7B template root must resolve to an object")
    deck, slides, summary = _validate_template_shape(resolved)
    selected = _admit_selected_figures(root, slides, summary, admitted_sources)
    return {
        "schemaVersion": 1,
        "generatedAt": FIXED_GENERATED_AT,
        "deck": deck,
        "summary": summary,
        "selectedFigures": selected,
        "usedEvidenceTokens": sorted(used),
        "phase7aSourceHashes": {
            "manifest": {
                "path": "docs/report/build_manifest.json",
                "sha256": sha256_file(manifest_path),
            },
            "evidence": evidence_record,
            "sources": admitted_sources,
        },
    }


def write_phase7b_package(root: Path, output: Path) -> dict[str, object]:
    """Build and atomically write one LF-normalized UTF-8 package JSON file."""
    package = build_phase7b_package(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", newline="\n", dir=output.parent, delete=False
    ) as temporary:
        json.dump(package, temporary, ensure_ascii=False, indent=2, sort_keys=False)
        temporary.write("\n")
        temporary_path = Path(temporary.name)
    try:
        temporary_path.replace(output)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise
    return package
