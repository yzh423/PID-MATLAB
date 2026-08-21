"""Build a deterministic Phase 7B package from admitted Phase 7A evidence."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
import hashlib
import json
from pathlib import Path
from pathlib import PurePosixPath
import tempfile

from scripts.reporting.evidence import EvidenceError, load_evidence, resolve_tokens


FIXED_GENERATED_AT = "2026-08-21T00:00:00Z"
SUMMARY_FIELDS = (
    "title", "takeaway", "problem", "method", "results", "figure",
    "figureCaption", "significance", "limitations", "nextSteps", "sources",
)
CONTROLLERS = ("manual-pid", "mamdani-fuzzy-pid", "optimization-pid")
DETERMINISTIC_SCENARIOS = (
    "nominal", "payload-0.0kg", "payload-1.0kg", "payload-1.5kg",
    "configuration-compact", "configuration-extended",
    "mass-inertia-minus-20pct", "mass-inertia-minus-10pct",
    "mass-inertia-plus-10pct", "mass-inertia-plus-20pct",
    "disturbance-pulse", "actuator-derated", "combined-deterministic",
)
STOCHASTIC_SCENARIOS = (
    "noise-low", "noise-medium", "noise-high", "combined-stochastic",
)
CARTESIAN_TASKS = ("straight-line", "pick-transfer-place")


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
    if (
        not relative_path
        or "\\" in relative_path
        or PurePosixPath(relative_path).is_absolute()
        or Path(relative_path).is_absolute()
        or ":" in PurePosixPath(relative_path).parts[0]
        or any(part in {"", ".", ".."} for part in PurePosixPath(relative_path).parts)
    ):
        raise Phase7BEvidenceError(
            f"Phase 7A source path is outside the project root: {relative_path}"
        )
    candidate = root / Path(*PurePosixPath(relative_path).parts)
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(root)
    except FileNotFoundError:
        return candidate
    except (OSError, ValueError) as exception:
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


def _require_boolean_success(rows: Sequence[Mapping[str, object]], label: str) -> None:
    for index, row in enumerate(rows, start=1):
        if type(row.get("Success")) is not bool:
            raise Phase7BEvidenceError(
                f"Phase 7A evidence requires {label} row {index} Success Boolean"
            )


def _require_exact_keys(
    rows: Sequence[Mapping[str, object]],
    fields: tuple[str, ...],
    expected: set[tuple[object, ...]],
    label: str,
) -> dict[tuple[object, ...], Mapping[str, object]]:
    keyed: dict[tuple[object, ...], Mapping[str, object]] = {}
    for row in rows:
        key = tuple(row.get(field) for field in fields)
        if key in keyed:
            raise Phase7BEvidenceError(f"Phase 7A evidence has duplicate {label} identity: {key}")
        keyed[key] = row
    if set(keyed) != expected:
        raise Phase7BEvidenceError(
            f"Phase 7A evidence {label} identity set/cardinality mismatch"
        )
    return keyed


def _require_completed(rows: Sequence[Mapping[str, object]], label: str) -> None:
    if any(row.get("Status") != "completed" for row in rows):
        raise Phase7BEvidenceError(f"Phase 7A evidence {label} status must be completed")


def _load_raw_evidence_admission(root: Path, evidence: Mapping[str, object]) -> list[dict[str, str]]:
    ledger_path = root / "docs/presentation/phase7b_raw_evidence.json"
    try:
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BEvidenceError("Phase 7B raw evidence ledger is invalid") from exception
    records = ledger.get("sources") if isinstance(ledger, Mapping) else None
    if ledger.get("schemaVersion") != 1 or not isinstance(records, list):
        raise Phase7BEvidenceError("Phase 7B raw evidence ledger has an unsupported schema")
    declared = evidence.get("sources")
    if not isinstance(declared, list) or not all(isinstance(item, Mapping) for item in declared):
        raise Phase7BEvidenceError("Phase 7A evidence requires a raw sources list")
    evidence_paths = {
        str(item.get("relativePath", "")).replace("\\", "/") for item in declared
    }
    admitted: list[dict[str, str]] = []
    seen: set[str] = set()
    for record in records:
        if not isinstance(record, Mapping):
            raise Phase7BEvidenceError("Phase 7B raw evidence record must be an object")
        relative_path = record.get("path")
        expected_digest = record.get("sha256")
        if not isinstance(relative_path, str) or not isinstance(expected_digest, str):
            raise Phase7BEvidenceError("Phase 7B raw evidence record requires path and sha256")
        if relative_path in seen:
            raise Phase7BEvidenceError(f"duplicate raw evidence identity: {relative_path}")
        seen.add(relative_path)
        source_path = _safe_source_path(root, relative_path)
        if not source_path.is_file():
            raise Phase7BEvidenceError(f"raw evidence does not exist: {relative_path}")
        if sha256_file(source_path) != expected_digest:
            raise Phase7BEvidenceError(f"raw evidence hash mismatch: {relative_path}")
        admitted.append({"path": relative_path, "sha256": expected_digest})
    if seen != evidence_paths:
        raise Phase7BEvidenceError("raw evidence identity set/cardinality mismatch")
    return admitted


def _derive_phase7b_values(evidence: Mapping[str, object]) -> dict[str, object]:
    """Derive presentation counts only after validating their Phase 7A rows."""
    system = _require_mapping(evidence.get("system"), "system")
    link_lengths = system.get("linkLengthsM")
    if not isinstance(link_lengths, list) or not link_lengths:
        raise Phase7BEvidenceError("Phase 7A evidence requires system link lengths")

    deterministic = _require_mapping(evidence.get("deterministic"), "deterministic")
    controller_rows = _require_rows(deterministic.get("summaryRows"), "deterministic summary")
    controller_summary = _require_exact_keys(
        controller_rows,
        ("Controller",),
        {(controller,) for controller in CONTROLLERS},
        "deterministic controller summary",
    )
    deterministic_rows = _require_rows(deterministic.get("runRows"), "deterministic run")
    _require_completed(deterministic_rows, "deterministic run")
    _require_boolean_success(deterministic_rows, "deterministic")
    deterministic_keys = _require_exact_keys(
        deterministic_rows,
        ("Controller", "Scenario"),
        {(controller, scenario) for controller in CONTROLLERS for scenario in DETERMINISTIC_SCENARIOS},
        "deterministic controller/scenario",
    )
    for controller in CONTROLLERS:
        summary = controller_summary[(controller,)]
        summary_run_count = _require_nonnegative_int(
            summary.get("RunCount"), f"deterministic {controller} run count"
        )
        summary_success_count = _require_nonnegative_int(
            summary.get("SuccessCount"), f"deterministic {controller} success count"
        )
        summary_failed_count = _require_nonnegative_int(
            summary.get("FailedRunCount"), f"deterministic {controller} failed count"
        )
        success_count = sum(
            row.get("Success") is True
            for (row_controller, _), row in deterministic_keys.items()
            if row_controller == controller
        )
        if (
            summary_run_count != len(DETERMINISTIC_SCENARIOS)
            or summary_success_count != success_count
            or summary_failed_count != len(DETERMINISTIC_SCENARIOS) - success_count
        ):
            raise Phase7BEvidenceError("Phase 7A evidence deterministic summary cardinality mismatch")
        if deterministic_keys[(controller, "combined-deterministic")].get("Success") is not False:
            raise Phase7BEvidenceError(
                "Phase 7A evidence does not support the all-controller combined deterministic failure claim"
            )

    stochastic = _require_mapping(evidence.get("stochastic"), "stochastic")
    stochastic_rows = _require_rows(stochastic.get("summaryRows"), "stochastic summary")
    stochastic_summary = _require_exact_keys(
        stochastic_rows,
        ("Controller", "Scenario"),
        {(controller, scenario) for controller in CONTROLLERS for scenario in STOCHASTIC_SCENARIOS},
        "stochastic controller/scenario",
    )
    isolated_rows = [
        stochastic_summary[(controller, scenario)]
        for controller in CONTROLLERS for scenario in STOCHASTIC_SCENARIOS[:3]
    ]
    combined_rows = [
        stochastic_summary[(controller, "combined-stochastic")]
        for controller in CONTROLLERS
    ]
    stochastic_trials = _require_rows(stochastic.get("trialRows"), "stochastic trial")
    _require_completed(stochastic_trials, "stochastic trial")
    _require_boolean_success(stochastic_trials, "stochastic")
    trial_count = _require_nonnegative_int(
        _require_mapping(evidence.get("protocol"), "protocol").get("stochasticTrialsPerScenario"),
        "stochastic trials per scenario",
    )
    trial_keys = _require_exact_keys(
        stochastic_trials,
        ("Controller", "Scenario", "Trial"),
        {
            (controller, scenario, trial)
            for controller in CONTROLLERS
            for scenario in STOCHASTIC_SCENARIOS
            for trial in range(1, trial_count + 1)
        },
        "stochastic controller/scenario/trial",
    )
    for (controller, scenario), summary in stochastic_summary.items():
        summary_trial_count = _require_nonnegative_int(
            summary.get("TrialCount"), f"stochastic {controller}/{scenario} trial count"
        )
        summary_success_count = _require_nonnegative_int(
            summary.get("SuccessCount"), f"stochastic {controller}/{scenario} success count"
        )
        trials = [
            row for (row_controller, row_scenario, _), row in trial_keys.items()
            if row_controller == controller and row_scenario == scenario
        ]
        successes = sum(row.get("Success") is True for row in trials)
        if summary_trial_count != trial_count or summary_success_count != successes:
            raise Phase7BEvidenceError("Phase 7A evidence stochastic summary cardinality mismatch")

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
    _require_completed(cartesian_rows, "cartesian run")
    _require_boolean_success(cartesian_rows, "Cartesian")
    cartesian_keys = _require_exact_keys(
        cartesian_rows,
        ("Controller", "Task"),
        {(controller, task) for controller in CONTROLLERS for task in CARTESIAN_TASKS},
        "cartesian controller/task",
    )
    expected_cartesian_success = {
        (controller, task): task == "straight-line" or controller == "optimization-pid"
        for controller in CONTROLLERS
        for task in CARTESIAN_TASKS
    }
    if any(
        cartesian_keys[key].get("Success") is not expected
        for key, expected in expected_cartesian_success.items()
    ):
        raise Phase7BEvidenceError(
            "Phase 7A evidence does not support the exact Cartesian success pattern"
        )
    completed_rows = list(cartesian_keys.values())
    successful_rows = [row for row in completed_rows if row.get("Success") is True]
    run_count = _require_nonnegative_int(cartesian.get("runCount"), "cartesian run count")
    if len(cartesian_rows) != run_count:
        raise Phase7BEvidenceError("Phase 7A evidence cartesian row count does not match runCount")

    return {
        "linkCount": len(link_lengths),
        "controllerCount": len(CONTROLLERS),
        "stochastic": {
            "isolatedNoise": derive_cell(isolated_rows, "isolated-noise", "all"),
            "combinedStress": derive_cell(combined_rows, "combined-stress", "none"),
        },
        "cartesian": {
            "successCount": len(successful_rows),
            "completedRunCount": len(completed_rows),
            "failureCount": len(completed_rows) - len(successful_rows),
            "optimizedPickTransferPlace": dict(
                cartesian_keys[("optimization-pid", "pick-transfer-place")]
            ),
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


def _validate_declared_sources(
    root: Path,
    slides: Sequence[Mapping[str, object]],
    summary: Mapping[str, object],
    manifest: Mapping[str, object],
    admitted_sources: Sequence[Mapping[str, str]],
    raw_evidence: Sequence[Mapping[str, str]],
) -> None:
    """Require every audience-facing citation to be repo-bound and hash-admitted."""
    output_records = manifest.get("outputs")
    if not isinstance(output_records, Sequence):
        raise Phase7BEvidenceError("Phase 7A build manifest requires an outputs list")
    admitted = {
        record["path"]: record["sha256"]
        for record in [*admitted_sources, *raw_evidence]
    }
    for record in output_records:
        if not isinstance(record, Mapping):
            raise Phase7BEvidenceError("Phase 7A output record must be an object")
        path = record.get("path")
        digest = record.get("sha256")
        if not isinstance(path, str) or not isinstance(digest, str):
            raise Phase7BEvidenceError("Phase 7A output record requires path and sha256 strings")
        source_path = _safe_source_path(root, path)
        if not source_path.is_file() or sha256_file(source_path) != digest:
            raise Phase7BEvidenceError(f"Phase 7A output hash mismatch: {path}")
        admitted[path] = digest
    manifest_path = "docs/report/build_manifest.json"
    admitted[manifest_path] = sha256_file(root / manifest_path)
    raw_ledger_path = "docs/presentation/phase7b_raw_evidence.json"
    admitted[raw_ledger_path] = sha256_file(root / raw_ledger_path)

    declared: list[tuple[str, str]] = []
    for slide in slides:
        sources = slide["sources"]
        assert isinstance(sources, list)
        declared.extend((f"slide source ({slide['id']})", source) for source in sources)
    summary_sources = summary["sources"]
    assert isinstance(summary_sources, list)
    declared.extend(("summary source", source) for source in summary_sources)
    for label, source in declared:
        assert isinstance(source, str)
        try:
            source_path = _safe_source_path(root, source)
        except Phase7BEvidenceError as exception:
            raise Phase7BEvidenceError(f"{label} is outside the project root: {source}") from exception
        expected_digest = admitted.get(source)
        if expected_digest is None:
            raise Phase7BEvidenceError(f"{label} is not admitted by Phase 7A: {source}")
        if not source_path.is_file():
            raise Phase7BEvidenceError(f"{label} does not exist: {source}")
        if sha256_file(source_path) != expected_digest:
            raise Phase7BEvidenceError(f"{label} hash mismatch: {source}")


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
    raw_evidence = _load_raw_evidence_admission(root, evidence)
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
    _validate_declared_sources(
        root, slides, summary, manifest, admitted_sources, raw_evidence
    )
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
            "rawEvidence": raw_evidence,
            "rawEvidenceLedger": {
                "path": "docs/presentation/phase7b_raw_evidence.json",
                "sha256": sha256_file(
                    root / "docs/presentation/phase7b_raw_evidence.json"
                ),
            },
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
