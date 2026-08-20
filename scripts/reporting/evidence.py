"""Validate formal report evidence and resolve controlled template tokens."""

from __future__ import annotations

from collections.abc import Mapping
import json
import math
from pathlib import Path
import re
from typing import Any


TOKEN = re.compile(r"\{\{([a-zA-Z][a-zA-Z0-9_.]*)(?:\|([^{}]+))?\}\}")
NUMERIC_FORMAT = re.compile(r"\.[0-9]+[feg]")
REQUIRED_TOP_LEVEL = (
    "schemaVersion",
    "generatedAt",
    "protocol",
    "nominal",
    "optimization",
    "deterministic",
    "stochastic",
    "cartesian",
    "simulink",
    "multibody",
    "artifacts",
    "sources",
)


class EvidenceError(ValueError):
    """Raised when report evidence cannot support a reproducible claim."""


def load_evidence(path: Path) -> dict[str, object]:
    """Load and validate one Phase 7A evidence manifest."""
    if not path.is_file():
        raise EvidenceError(f"evidence file does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise EvidenceError(f"evidence file is not valid UTF-8 JSON: {path}") from exception
    if not isinstance(value, dict):
        raise EvidenceError("evidence root must be a JSON object")
    evidence: dict[str, object] = value
    validate_evidence(evidence)
    return evidence


def validate_evidence(evidence: Mapping[str, object]) -> None:
    """Enforce the frozen formal-study shape used by the report."""
    missing = [key for key in REQUIRED_TOP_LEVEL if key not in evidence]
    errors: list[str] = []
    if missing:
        errors.append("missing top-level keys: " + ", ".join(missing))
    if evidence.get("schemaVersion") != 1:
        errors.append("schemaVersion must equal 1")
    if errors:
        raise EvidenceError("; ".join(errors))

    expected_counts = {
        "deterministic.runCount": 39,
        "stochastic.trialCount": 360,
        "cartesian.runCount": 6,
        "simulink.runCount": 2,
        "multibody.runCount": 2,
    }
    for dotted_path, expected in expected_counts.items():
        actual = lookup(evidence, dotted_path)
        if actual != expected:
            errors.append(f"{dotted_path} must equal {expected}, got {actual!r}")

    for section in ("deterministic", "stochastic", "cartesian", "simulink", "multibody"):
        mode = lookup(evidence, f"{section}.mode")
        if mode != "full":
            errors.append(f"{section}.mode must equal 'full', got {mode!r}")

    for section in ("simulink", "multibody"):
        for field in ("agreementPass", "trackingSuccess"):
            values = lookup(evidence, f"{section}.{field}")
            if values != [True, True]:
                errors.append(f"{section}.{field} must contain two passing rows")

    for dotted_path in (
        "optimization.objectiveReductionPercent",
        "multibody.endEffectorMaxWorst",
        "multibody.maximumOutOfPlane",
    ):
        value = lookup(evidence, dotted_path)
        if not _is_finite_number(value):
            errors.append(f"{dotted_path} must be a finite numeric value")

    if not isinstance(evidence["sources"], list) or len(evidence["sources"]) != 14:
        errors.append("sources must contain the 14 frozen formal artifacts")
    if not isinstance(evidence["artifacts"], list) or len(evidence["artifacts"]) != 6:
        errors.append("artifacts must contain the six selected report figures")
    if errors:
        raise EvidenceError("; ".join(errors))


def lookup(evidence: Mapping[str, object], dotted_path: str) -> object:
    """Resolve a dotted path without attribute access or expression evaluation."""
    value: object = evidence
    for part in dotted_path.split("."):
        if not isinstance(value, Mapping) or part not in value:
            raise EvidenceError(f"unknown evidence token: {dotted_path}")
        value = value[part]
    return value


def resolve_tokens(
    template: str, evidence: Mapping[str, object]
) -> tuple[str, set[str]]:
    """Resolve controlled evidence tokens and return the used dotted paths."""
    used: set[str] = set()

    def replace(match: re.Match[str]) -> str:
        dotted_path, format_spec = match.groups()
        value = lookup(evidence, dotted_path)
        rendered = _render_scalar(dotted_path, value, format_spec)
        used.add(dotted_path)
        return rendered

    resolved = TOKEN.sub(replace, template)
    if "{{" in resolved or "}}" in resolved:
        raise EvidenceError("unresolved evidence token remains after substitution")
    return resolved, used


def _render_scalar(dotted_path: str, value: object, format_spec: str | None) -> str:
    if isinstance(value, (Mapping, list, tuple)) or value is None:
        raise EvidenceError(f"token {dotted_path} must resolve to a scalar evidence value")
    if isinstance(value, float) and not math.isfinite(value):
        raise EvidenceError(f"token {dotted_path} must resolve to a finite numeric value")
    if format_spec is None:
        if isinstance(value, bool):
            return "true" if value else "false"
        return str(value)
    if format_spec == "d":
        if isinstance(value, bool) or not isinstance(value, int):
            raise EvidenceError(f"token {dotted_path} requires an integer for format d")
        return format(value, format_spec)
    if not NUMERIC_FORMAT.fullmatch(format_spec):
        raise EvidenceError(f"unsupported token format: {format_spec}")
    if not _is_finite_number(value):
        raise EvidenceError(f"token {dotted_path} must resolve to a finite numeric value")
    return format(value, format_spec)


def _is_finite_number(value: Any) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(value)
    )
