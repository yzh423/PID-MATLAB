"""Build a deterministic Phase 7B package from admitted Phase 7A evidence."""

from __future__ import annotations

from collections.abc import Mapping
import hashlib
import json
from pathlib import Path
import tempfile

from scripts.reporting.evidence import EvidenceError, load_evidence, resolve_tokens


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


def build_phase7b_package(root: Path) -> dict[str, object]:
    """Resolve the frozen template and admit each selected Phase 7A figure."""
    root = root.resolve(strict=True)
    try:
        evidence = load_evidence(root / "results/report/report_evidence.json")
    except EvidenceError as exception:
        raise Phase7BEvidenceError(f"Phase 7A evidence is invalid: {exception}") from exception
    template = load_phase7b_template(root / "docs/presentation/phase7b_template.json")
    try:
        manifest = json.loads(
            (root / "docs/report/build_manifest.json").read_text(encoding="utf-8")
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exception:
        raise Phase7BEvidenceError("Phase 7A build manifest is not valid UTF-8 JSON") from exception
    if not isinstance(manifest, dict) or not isinstance(manifest.get("sources"), list):
        raise Phase7BEvidenceError("Phase 7A build manifest requires a sources list")

    used: set[str] = set()
    try:
        resolved = _resolve_value(template, evidence, used)
    except EvidenceError as exception:
        raise Phase7BEvidenceError(f"Phase 7B token resolution failed: {exception}") from exception
    if not isinstance(resolved, dict):
        raise Phase7BEvidenceError("Phase 7B template root must resolve to an object")
    deck = resolved.get("deck")
    if not isinstance(deck, dict) or not isinstance(deck.get("slides"), list):
        raise Phase7BEvidenceError("Phase 7B template requires a deck slides list")
    slides = deck["slides"]
    if (
        len(slides) != 10
        or not all(isinstance(slide, dict) and isinstance(slide.get("id"), str) for slide in slides)
        or len({slide["id"] for slide in slides}) != 10
    ):
        raise Phase7BEvidenceError("Phase 7B requires exactly 10 unique slides")

    admitted: dict[str, str] = {}
    for record in manifest["sources"]:
        if not isinstance(record, dict):
            continue
        path = record.get("path")
        digest = record.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            admitted[path] = digest

    selected: list[dict[str, str]] = []
    figure_paths = dict.fromkeys(
        slide.get("figure") for slide in slides if isinstance(slide.get("figure"), str)
    )
    for path in figure_paths:
        if not isinstance(path, str):
            continue
        file_path = root / path
        if path not in admitted or not file_path.is_file():
            raise Phase7BEvidenceError(f"figure is not admitted by Phase 7A: {path}")
        digest = sha256_file(file_path)
        if digest != admitted[path]:
            raise Phase7BEvidenceError(f"Phase 7A figure hash mismatch: {path}")
        selected.append({"path": path, "sha256": digest})

    generated_at = resolved.get("generatedAt")
    if generated_at != "2026-08-21T00:00:00Z":
        raise Phase7BEvidenceError("Phase 7B generatedAt must be frozen")
    summary = resolved.get("summary")
    if not isinstance(summary, dict):
        raise Phase7BEvidenceError("Phase 7B requires one summary object")
    return {
        "schemaVersion": 1,
        "generatedAt": generated_at,
        "deck": deck,
        "summary": summary,
        "selectedFigures": selected,
        "usedEvidenceTokens": sorted(used),
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
