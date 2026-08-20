# Phase 7B Presentation and Research Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible, evidence-grounded 10-slide PowerPoint deck plus a one-page DOCX/PDF research summary from the verified Phase 7A evidence.

**Architecture:** A Python exporter validates the Phase 7A report evidence and resolves a controlled Phase 7B JSON template into one deterministic package. A JavaScript ES-module builder using `@oai/artifact-tool` creates the PPTX, while a `python-docx` builder creates the one-page summary; shared Office/PDF normalization and a PowerShell verifier enforce structure, visual QA inputs, and stable hashes.

**Tech Stack:** MATLAB R2026 verification, bundled Python 3 with `python-docx`, Pillow and `pypdf`, bundled Node.js with `@oai/artifact-tool`, Microsoft Word COM for PDF export, PowerShell, `unittest`, OOXML/ZIP inspection.

## Global Constraints

- Produce exactly 10 English slides for a 10- to 15-minute advisor/faculty discussion.
- Produce exactly one US Letter page in both DOCX and PDF summary formats.
- Use only `results/report/report_evidence.json`, `docs/report/build_manifest.json`, `docs/report/references.json`, and admitted Phase 7A figures for quantitative claims.
- Do not create new controller experiments or change accepted Phase 7A conclusions.
- Use `@oai/artifact-tool` from a JavaScript ES module for PPTX authoring; do not use `python-pptx`.
- Use at least 50 pt for the deck title, 35 pt for slide titles, 24 pt for callout headers, and 16 pt for body text.
- Add a `[Sources]` block to speaker notes on every slide.
- Preserve all failed cases and state the simulation-only boundary.
- Normalize source text to LF and final Office/PDF metadata for checkout-independent hashes.
- Render and inspect every final slide and the complete summary page before delivery.
- Do not modify `Daniel_MATLAB_Robotics_Project_Implementation_Guide.docx` or any remote Git state.

---

## File Map

| File | Responsibility |
|---|---|
| `docs/presentation/phase7b_template.json` | Controlled audience-facing slide and summary copy with evidence tokens |
| `scripts/phase7b/evidence.py` | Template validation, recursive token resolution, figure/hash admission, atomic JSON export |
| `scripts/export_phase7b_package.py` | CLI entry point producing `results/presentation/phase7b_package.json` |
| `scripts/phase7b/office.py` | Stable OOXML metadata, ZIP ordering/timestamps, SHA-256 helpers |
| `scripts/normalize_phase7b_office.py` | CLI normalizer for generated PPTX/DOCX packages |
| `scripts/build_presentation.mjs` | Artifact-tool PPTX builder, image embedding, notes, preview/layout exports |
| `scripts/phase7b/summary.py` | Exact one-page Word style and layout helpers |
| `scripts/build_research_summary.py` | DOCX/Markdown/manifest builder from the resolved package |
| `scripts/export_research_summary_pdf.ps1` | Owned hidden Word export plus deterministic PDF normalization |
| `scripts/verify_phase7b.ps1` | End-to-end package build, tests, hashes, render structure, page/slide gates |
| `tests/presentation/test_phase7b_evidence.py` | Evidence/token/admission tests |
| `tests/presentation/test_phase7b_outputs.py` | PPTX/DOCX/PDF/manifest structure and reproducibility tests |
| `presentation/final_presentation.pptx` | Final editable 10-slide presentation |
| `docs/summary/research_summary.docx` | Final editable one-page summary |
| `docs/summary/research_summary.pdf` | Final one-page distribution summary |
| `docs/presentation/phase7b_build_manifest.json` | Stable input/output hashes and structural counts |

### Task 0: Make the baseline verifier clean-checkout safe

**Files:**
- Create: `tests/report/test_verify_clean_checkout.py`
- Modify: `scripts/verify.ps1`

**Interfaces:**
- Consumes: the existing formal experiment entry points and full MATLAB test suite.
- Produces: a root verification order in which every formal artifact is generated before `runtests('tests', 'IncludeSubfolders', true)` executes report tests that consume those artifacts.

- [ ] **Step 1: Write the failing ordering regression test**

```python
from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
VERIFY = ROOT / "scripts/verify.ps1"


class CleanCheckoutVerificationTests(unittest.TestCase):
    def test_formal_experiments_run_before_artifact_dependent_tests(self) -> None:
        script = VERIFY.read_text(encoding="utf-8")
        test_index = script.index("results = runtests('tests', 'IncludeSubfolders', true);")
        experiments = (
            "run('experiments/run_nominal_pid.m');",
            "run('experiments/run_nominal_pid_vs_fuzzy.m');",
            "run('experiments/run_pid_optimization.m');",
            "run('experiments/run_deterministic_robustness.m');",
            "run('experiments/run_stochastic_robustness.m');",
            "run('experiments/run_cartesian_tasks.m');",
            "run('experiments/run_simulink_cross_validation.m');",
            "run('experiments/run_multibody_cross_validation.m');",
        )
        for experiment in experiments:
            with self.subTest(experiment=experiment):
                self.assertLess(script.index(experiment), test_index)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the regression test and verify RED**

```powershell
& $BundledPython -m unittest tests.report.test_verify_clean_checkout -v
```

Expected: FAIL because all formal experiment calls currently occur after `runtests`.

- [ ] **Step 3: Move only the full-suite test call after formal generation**

Keep the existing experiment order and variable clears unchanged. Move these three MATLAB statements:

```matlab
results = runtests('tests', 'IncludeSubfolders', true);
assertSuccess(results);
```

to immediately after `run('experiments/run_multibody_cross_validation.m');`. Do not split the single MATLAB batch or change an experiment mode.

- [ ] **Step 4: Run GREEN and the complete clean-checkout baseline**

```powershell
& $BundledPython -m unittest tests.report.test_verify_clean_checkout -v
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Expected: ordering test PASS; full verifier exits 0 after generating the missing ignored artifacts and then passing the complete MATLAB/report suites.

- [ ] **Step 5: Commit**

```powershell
git add tests/report/test_verify_clean_checkout.py scripts/verify.ps1 docs/skills/plans/2026-08-21-phase-7b-presentation-summary.md
git commit -m "fix: bootstrap formal evidence before verification"
```

### Task 1: Deterministic Phase 7B evidence package

**Files:**
- Create: `docs/presentation/phase7b_template.json`
- Create: `scripts/phase7b/__init__.py`
- Create: `scripts/phase7b/evidence.py`
- Create: `scripts/export_phase7b_package.py`
- Create: `tests/presentation/__init__.py`
- Create: `tests/presentation/test_phase7b_evidence.py`
- Modify: `.gitattributes`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `scripts.reporting.evidence.load_evidence(path)` and `resolve_tokens(text, evidence)`.
- Produces: `load_phase7b_template(path: Path) -> dict[str, object]`, `build_phase7b_package(root: Path) -> dict[str, object]`, and `write_phase7b_package(root: Path, output: Path) -> dict[str, object]`.
- Output contract: schema version 1, frozen `generatedAt`, 10 resolved slides, one resolved summary, selected figure hashes, used evidence tokens, and Phase 7A source hashes.

- [ ] **Step 1: Write failing evidence-package tests**

```python
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from scripts.phase7b.evidence import (
    Phase7BEvidenceError,
    build_phase7b_package,
    load_phase7b_template,
)

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "docs/presentation/phase7b_template.json"


class Phase7BEvidenceTests(unittest.TestCase):
    def test_template_has_frozen_shape(self) -> None:
        template = load_phase7b_template(TEMPLATE)
        self.assertEqual(template["schemaVersion"], 1)
        self.assertEqual(len(template["deck"]["slides"]), 10)
        self.assertEqual(template["deck"]["slides"][0]["id"], "opening")
        self.assertEqual(template["deck"]["slides"][-1]["id"], "next-steps")
        self.assertIn("summary", template)

    def test_package_resolves_required_claims_and_failures(self) -> None:
        package = build_phase7b_package(ROOT)
        text = json.dumps(package, ensure_ascii=False)
        for claim in ("8/13", "9/13", "10/13", "30/30", "0/30", "7.283%"):
            self.assertIn(claim, text)
        self.assertIn("simulation", text.lower())
        self.assertNotIn("{{", text)
        self.assertNotIn("}}", text)

    def test_missing_figure_is_rejected(self) -> None:
        package = build_phase7b_package(ROOT)
        figure = ROOT / package["selectedFigures"][0]["path"]
        with tempfile.TemporaryDirectory() as directory:
            fake_root = Path(directory)
            (fake_root / "docs/presentation").mkdir(parents=True)
            (fake_root / "docs/presentation/phase7b_template.json").write_text(
                TEMPLATE.read_text(encoding="utf-8"), encoding="utf-8"
            )
            with self.assertRaisesRegex(Phase7BEvidenceError, "Phase 7A"):
                build_phase7b_package(fake_root)

    def test_sources_and_notes_are_complete(self) -> None:
        package = build_phase7b_package(ROOT)
        for slide in package["deck"]["slides"]:
            self.assertGreaterEqual(len(slide["sources"]), 1, slide["id"])
            self.assertTrue(all(source.startswith(("docs/", "results/")) for source in slide["sources"]))
        self.assertEqual(package["generatedAt"], "2026-08-21T00:00:00Z")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
& $BundledPython -m unittest tests.presentation.test_phase7b_evidence -v
```

Expected: import failure for `scripts.phase7b.evidence`.

- [ ] **Step 3: Add the controlled template**

Create `phase7b_template.json` with this complete controlled content:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-21T00:00:00Z",
  "deck": {
    "title": "Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation",
    "slides": [
      {
        "id": "opening",
        "title": "Reliable execution connects plans to physical action",
        "subtitle": "Evidence-grounded PID and Fuzzy-PID evaluation for a two-link manipulator",
        "figure": "results/figures/multibody_cross_validation_tracking.png",
        "figureAlt": "MATLAB and Simscape Multibody end-effector tracking comparison",
        "figureFrame": {"left": 680, "top": 92, "width": 540, "height": 500},
        "presenterNote": "Frame the project as a validated execution layer rather than an end-to-end robot intelligence stack.",
        "sources": ["docs/report/technical_report.md", "results/figures/multibody_cross_validation_tracking.png"]
      },
      {
        "id": "problem",
        "title": "Nominal success is not enough to claim reliable manipulation",
        "claim": "The central question is how controller choices survive controlled changes in payload, configuration, noise, disturbance, and actuator authority.",
        "body": [
          "A controller can pass one nominal trajectory and still fail when uncertainties interact.",
          "This study therefore reports failed completed runs instead of filtering them from averages.",
          "All conclusions are simulation-only; no hardware safety or fidelity claim is made."
        ],
        "figure": "results/figures/nominal_pid_vs_fuzzy_tracking.png",
        "figureAlt": "Nominal PID and Fuzzy-PID joint tracking comparison",
        "figureFrame": {"left": 620, "top": 138, "width": 600, "height": 470},
        "presenterNote": "Use the nominal plot to motivate why the later stress matrix is necessary.",
        "sources": ["docs/report/technical_report.md", "results/figures/nominal_pid_vs_fuzzy_tracking.png"]
      },
      {
        "id": "protocol",
        "title": "Every controller faces the same plant, trajectory, limits, and metrics",
        "layout": "metrics",
        "metrics": [
          {"value": "{{protocol.sampleTimeS|.3f}} s", "label": "fixed sample time"},
          {"value": "{{protocol.nominalDurationS|.1f}} s", "label": "nominal duration"},
          {"value": "{{protocol.nominalSampleCount}}", "label": "samples per nominal run"}
        ],
        "interpretation": "Manual PID, Mamdani Fuzzy-PID, and optimized PID use identical robot parameters, torque limits, trajectories, thresholds, and random seeds.",
        "presenterNote": "Emphasize fairness before discussing controller rankings.",
        "sources": ["docs/report/technical_report.md", "results/report/report_evidence.json"]
      },
      {
        "id": "optimization",
        "title": "Optimization improves the baseline without changing the protocol",
        "claim": "The bounded search reduces the nominal objective by {{optimization.objectiveReductionPercent|.3f}}% and improves the held-out payload objective from {{optimization.heldOutInitialObjective|.6f}} to {{optimization.heldOutFinalObjective|.6f}}.",
        "body": [
          "The search converges with exit flag {{optimization.exitFlag}} after {{optimization.iterations}} iterations and {{optimization.functionEvaluations}} evaluations.",
          "Only PID gains change; the plant, torque limits, trajectory, objective, and evaluation thresholds remain fixed."
        ],
        "figure": "results/figures/pid_optimization_objective.png",
        "figureAlt": "PID optimization objective history",
        "figureFrame": {"left": 620, "top": 138, "width": 600, "height": 470},
        "presenterNote": "Separate tuning evidence from reliability evidence: a lower objective does not prove universal robustness.",
        "sources": ["docs/report/technical_report.md", "results/figures/pid_optimization_objective.png", "results/data/pid_optimization.mat"]
      },
      {
        "id": "deterministic",
        "title": "Reliability separates the controllers under deterministic stress",
        "claim": "Success rises from {{deterministic.successCount.manualPid}}/{{deterministic.scenarioCount}} for manual PID to {{deterministic.successCount.fuzzyPid}}/{{deterministic.scenarioCount}} for Fuzzy-PID and {{deterministic.successCount.optimizedPid}}/{{deterministic.scenarioCount}} for optimized PID.",
        "body": [
          "The matrix contains {{deterministic.runCount}} controller-scenario runs across payload, configuration, disturbance, actuator, and combined conditions.",
          "All three controllers fail the combined deterministic case, so the ranking is comparative rather than a safety guarantee."
        ],
        "figure": "results/figures/deterministic_robustness_summary.png",
        "figureAlt": "Deterministic robustness success counts and error summary",
        "figureFrame": {"left": 620, "top": 138, "width": 600, "height": 470},
        "presenterNote": "State both the aggregate ranking and the shared combined-condition failure.",
        "sources": ["docs/report/technical_report.md", "results/figures/deterministic_robustness_summary.png", "results/data/deterministic_robustness_summary.csv"]
      },
      {
        "id": "stochastic",
        "title": "Noise alone is manageable; combined stress is not",
        "claim": "Each isolated-noise cell passes 30/30 paired trials, while every combined-stress cell passes 0/30.",
        "body": [
          "The full study contains {{stochastic.trialCount}} trials: {{stochastic.scenarioCount}} scenarios x 3 controllers x {{protocol.stochasticTrialsPerScenario}} fixed seeds.",
          "At high noise, optimized PID has the lowest tracking error but the highest mean torque slew ({{stochastic.highNoiseMeanTorqueSlew.optimizedPid|.2f}} N m/s)."
        ],
        "figure": "results/figures/stochastic_robustness_chattering.png",
        "figureAlt": "Stochastic robustness torque-slew comparison",
        "figureFrame": {"left": 620, "top": 138, "width": 600, "height": 470},
        "presenterNote": "Use the paired-seed design to explain why the controller comparison is fair.",
        "sources": ["docs/report/technical_report.md", "results/figures/stochastic_robustness_chattering.png", "results/data/stochastic_robustness_summary.csv"]
      },
      {
        "id": "cartesian",
        "title": "Task-space evaluation exposes failures hidden by joint metrics",
        "claim": "All three controllers pass the straight-line task; only optimized PID passes pick-transfer-place, so 4 of 6 completed task runs meet every gate.",
        "body": [
          "Manual and Fuzzy-PID complete the pick-transfer-place simulation but fail its quantitative pickup/place criteria.",
          "Optimized PID records {{cartesian.runRows.5.CartesianRms|.5f}} m RMS and {{cartesian.runRows.5.CartesianMax|.5f}} m maximum Cartesian error."
        ],
        "figure": "results/figures/cartesian_tasks_paths.png",
        "figureAlt": "Straight-line and pick-transfer-place Cartesian paths",
        "figureFrame": {"left": 620, "top": 138, "width": 600, "height": 470},
        "presenterNote": "Completed does not mean successful; retain the two failed completed runs.",
        "sources": ["docs/report/technical_report.md", "results/figures/cartesian_tasks_paths.png", "results/data/cartesian_tasks_runs.csv"]
      },
      {
        "id": "cross-validation",
        "title": "Independent formulations agree at numerical precision",
        "layout": "metrics",
        "metrics": [
          {"value": "{{simulink.runCount}}/{{simulink.runCount}}", "label": "Simulink agreement and tracking passes"},
          {"value": "{{multibody.runCount}}/{{multibody.runCount}}", "label": "Multibody agreement and tracking passes"},
          {"value": "{{multibody.endEffectorMaxWorst|.2e}} m", "label": "worst end-effector difference"}
        ],
        "interpretation": "The result supports model consistency under one fixed protocol. Shared parameters and target trajectories mean it is not evidence of hardware fidelity.",
        "presenterNote": "Distinguish independent formulation from independent physical validation.",
        "sources": ["docs/report/technical_report.md", "results/data/simulink_cross_validation.mat", "results/data/multibody_cross_validation.mat"]
      },
      {
        "id": "conclusion",
        "title": "There is no universal winner, but optimized PID is the strongest reliability baseline",
        "layout": "metrics",
        "metrics": [
          {"value": "{{deterministic.successCount.manualPid}}/{{deterministic.scenarioCount}}", "label": "manual PID deterministic success"},
          {"value": "{{deterministic.successCount.fuzzyPid}}/{{deterministic.scenarioCount}}", "label": "Fuzzy-PID deterministic success"},
          {"value": "{{deterministic.successCount.optimizedPid}}/{{deterministic.scenarioCount}}", "label": "optimized PID deterministic success"}
        ],
        "interpretation": "Fuzzy adaptation gives a small nominal joint-2 benefit; optimized PID provides the best aggregate deterministic and Cartesian reliability, with a torque-slew trade-off under noise.",
        "presenterNote": "Deliver a conditional conclusion, not a universal-controller claim.",
        "sources": ["docs/report/technical_report.md", "results/report/report_evidence.json"]
      },
      {
        "id": "next-steps",
        "title": "The validated layer is ready to support the next research step",
        "claim": "The next milestone is to test whether the same evidence discipline survives contact with sensing, hardware uncertainty, and online safety constraints.",
        "body": [
          "1. Hardware-in-the-loop and physical-arm validation with calibrated uncertainty.",
          "2. Perception and task-planning integration above the existing inner-loop controller layer.",
          "3. Online monitoring, collision avoidance, and explicit safety supervision before deployment."
        ],
        "presenterNote": "Close by resolving the opening: the low-level layer is validated for simulation and bounded next research is clear.",
        "sources": ["docs/report/technical_report.md", "docs/report/references.json"]
      }
    ]
  },
  "summary": {
    "title": "Reliable Robotic Manipulation Through Evidence-Grounded Control",
    "takeaway": "Across identical simulation protocols, optimized PID produced the strongest aggregate reliability while no controller dominated every condition.",
    "problem": "Reliable manipulation requires more than nominal trajectory tracking: controllers must remain interpretable under payload, configuration, disturbance, noise, and actuator changes.",
    "method": "A two-link arm compares manual PID, Mamdani Fuzzy-PID, and bounded optimization-assisted PID under identical 0.001 s simulation, trajectory, torque-limit, threshold, and paired-seed protocols.",
    "results": [
      {"value": "{{optimization.objectiveReductionPercent|.3f}}%", "label": "nominal objective reduction"},
      {"value": "{{deterministic.successCount.optimizedPid}}/{{deterministic.scenarioCount}}", "label": "deterministic scenarios passed"},
      {"value": "30/30 vs 0/30", "label": "isolated-noise vs combined-stress trials"}
    ],
    "figure": "results/figures/deterministic_robustness_summary.png",
    "figureCaption": "Deterministic stress testing separates aggregate controller reliability while preserving failed cases.",
    "significance": "The project supplies a transparent low-level execution layer that can sit beneath future perception, language, and task-planning systems.",
    "limitations": "Simulation only; no hardware fidelity, collision avoidance, perception, online safety supervisor, or end-to-end embodied-AI implementation is claimed.",
    "nextSteps": "Validate on hardware, add calibrated sensing uncertainty, and introduce runtime safety monitoring before deployment claims.",
    "sources": ["docs/report/technical_report.md", "results/report/report_evidence.json", "docs/report/PAPER_CLAIM_AUDIT.md"]
  }
}
```

- [ ] **Step 4: Implement strict package construction**

```python
class Phase7BEvidenceError(ValueError):
    """Raised when Phase 7A cannot support the Phase 7B package."""


def _resolve_value(value: object, evidence: Mapping[str, object], used: set[str]) -> object:
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
    root = root.resolve(strict=True)
    evidence = load_evidence(root / "results/report/report_evidence.json")
    template = load_phase7b_template(root / "docs/presentation/phase7b_template.json")
    manifest = json.loads((root / "docs/report/build_manifest.json").read_text(encoding="utf-8"))
    used: set[str] = set()
    resolved = _resolve_value(template, evidence, used)
    slides = resolved["deck"]["slides"]
    if len(slides) != 10 or len({slide["id"] for slide in slides}) != 10:
        raise Phase7BEvidenceError("Phase 7B requires exactly 10 unique slides")
    selected = []
    admitted = {record["path"]: record["sha256"] for record in manifest["sources"]}
    for path in dict.fromkeys(slide.get("figure") for slide in slides if slide.get("figure")):
        file_path = root / path
        if path not in admitted or not file_path.is_file():
            raise Phase7BEvidenceError(f"figure is not admitted by Phase 7A: {path}")
        digest = sha256_file(file_path)
        if digest != admitted[path]:
            raise Phase7BEvidenceError(f"Phase 7A figure hash mismatch: {path}")
        selected.append({"path": path, "sha256": digest})
    return {
        "schemaVersion": 1,
        "generatedAt": "2026-08-21T00:00:00Z",
        "deck": resolved["deck"],
        "summary": resolved["summary"],
        "selectedFigures": selected,
        "usedEvidenceTokens": sorted(used),
    }
```

- [ ] **Step 5: Add CLI, LF rules, and ignore rules**

The CLI must parse `--project-root` and optional `--output`, write UTF-8 JSON with `indent=2`, `sort_keys=False`, `newline="\n"`, and atomically replace the output. Add:

```gitattributes
/docs/presentation/** text eol=lf
/scripts/phase7b/** text eol=lf
/scripts/export_phase7b_package.py text eol=lf
/tests/presentation/** text eol=lf
/presentation/*.pptx binary
/docs/summary/*.docx binary
/docs/summary/*.pdf binary
```

Add ignored build paths:

```gitignore
/results/presentation/
/tmp/phase7b/
```

- [ ] **Step 6: Run tests and commit**

Run:

```powershell
& $BundledPython -m unittest tests.presentation.test_phase7b_evidence -v
git diff --check
```

Expected: all evidence tests PASS and no whitespace errors.

Commit:

```powershell
git add .gitattributes .gitignore docs/presentation/phase7b_template.json scripts/phase7b scripts/export_phase7b_package.py tests/presentation
git commit -m "feat: export Phase 7B evidence package"
```

### Task 2: Deterministic Office package normalization

**Files:**
- Create: `scripts/phase7b/office.py`
- Create: `scripts/normalize_phase7b_office.py`
- Create: `tests/presentation/test_phase7b_office.py`

**Interfaces:**
- Produces: `sha256_file(path: Path) -> str`, `normalize_openxml_package(path: Path, suffix: str) -> None`, and `canonical_manifest(root: Path, sources: Sequence[Path], outputs: Sequence[Path], counts: Mapping[str, int]) -> dict[str, object]`.
- Normalization contract: fixed ZIP timestamp `(1980, 1, 1, 0, 0, 0)`, sorted entry order, cleared extra/comment fields, fixed `docProps/core.xml` dates, no content removal.

- [ ] **Step 1: Write failing normalization tests**

```python
def test_openxml_normalization_is_binary_deterministic(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
        first = Path(directory) / "first.pptx"
        second = Path(directory) / "second.pptx"
        create_fixture_package(first, "2026-08-21T01:02:03Z", (2026, 8, 21, 1, 2, 4))
        create_fixture_package(second, "2026-08-21T05:06:07Z", (2026, 8, 21, 5, 6, 8))
        normalize_openxml_package(first, ".pptx")
        normalize_openxml_package(second, ".pptx")
        self.assertEqual(sha256_file(first), sha256_file(second))
        with ZipFile(first) as archive:
            self.assertTrue(all(info.date_time == (1980, 1, 1, 0, 0, 0) for info in archive.infolist()))
            core = archive.read("docProps/core.xml").decode("utf-8")
            self.assertIn("2026-08-21T00:00:00Z", core)
```

- [ ] **Step 2: Run RED, implement, and rerun GREEN**

Implement XML date normalization with `xml.etree.ElementTree`, preserve compression method, and write through a sibling temporary file:

```python
FIXED_OFFICE_TIMESTAMP = "2026-08-21T00:00:00Z"
FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def normalize_openxml_package(path: Path, suffix: str) -> None:
    path = path.resolve(strict=True)
    if path.suffix.lower() != suffix:
        raise ValueError(f"expected {suffix} package")
    with ZipFile(path) as source:
        payloads = {info.filename: source.read(info.filename) for info in source.infolist()}
    if "docProps/core.xml" in payloads:
        payloads["docProps/core.xml"] = normalize_core_properties(payloads["docProps/core.xml"])
    temporary = path.with_name(f".{path.name}.normalized.tmp")
    try:
        with ZipFile(temporary, "w", compression=ZIP_DEFLATED, compresslevel=9) as target:
            for name in sorted(payloads):
                info = ZipInfo(name, FIXED_ZIP_TIME)
                info.compress_type = ZIP_DEFLATED
                info.create_system = 0
                info.external_attr = 0
                target.writestr(info, payloads[name])
        temporary.replace(path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
```

Run:

```powershell
& $BundledPython -m unittest tests.presentation.test_phase7b_office -v
```

Expected: PASS.

- [ ] **Step 3: Commit**

```powershell
git add scripts/phase7b/office.py scripts/normalize_phase7b_office.py tests/presentation/test_phase7b_office.py
git commit -m "feat: normalize Phase 7B Office packages"
```

### Task 3: Build the 10-slide presentation with Artifact Tool

**Files:**
- Create: `scripts/build_presentation.mjs`
- Create: `tests/presentation/test_presentation_structure.py`
- Create: `presentation/final_presentation.pptx`

**Interfaces:**
- Consumes: `results/presentation/phase7b_package.json`, embedded PNG paths, `RUNTIME_NODE`, `RUNTIME_NODE_MODULES`, and `RUNTIME_BIN_DIR`.
- Produces: `presentation/final_presentation.pptx` plus ignored `tmp/phase7b/slides/slide-01.png` through `slide-10.png`, layout JSON files, montage, and `source-notes.txt`.

- [ ] **Step 1: Write failing PPTX structure tests**

```python
class PresentationStructureTests(unittest.TestCase):
    def test_final_deck_has_ten_slides_and_source_notes(self) -> None:
        self.assertTrue(PPTX.is_file())
        with ZipFile(PPTX) as archive:
            slides = sorted(name for name in archive.namelist() if re.fullmatch(r"ppt/slides/slide\d+\.xml", name))
            notes = sorted(name for name in archive.namelist() if re.fullmatch(r"ppt/notesSlides/notesSlide\d+\.xml", name))
            self.assertEqual(len(slides), 10)
            self.assertEqual(len(notes), 10)
            for name in notes:
                text = xml_text(archive.read(name))
                self.assertIn("[Sources]", text)

    def test_deck_contains_contract_claims_and_no_placeholders(self) -> None:
        text = pptx_text(PPTX)
        for value in ("7.283%", "8/13", "9/13", "10/13", "30/30", "0/30"):
            self.assertIn(value, text)
        for forbidden in ("{{", "}}", "Lorem ipsum", "Title here", "placeholder"):
            self.assertNotIn(forbidden, text)
```

- [ ] **Step 2: Run RED**

```powershell
& $BundledPython -m unittest tests.presentation.test_presentation_structure -v
```

Expected: FAIL because `final_presentation.pptx` does not exist.

- [ ] **Step 3: Mark the presentation artifact operation exactly once**

Immediately before the first authoring run:

```powershell
& $env:RUNTIME_NODE "$env:SKILL_DIR\container_tools\mark_artifact_operation_started.mjs" --operation-kind create --expected-output-count 1 --output-format pptx
```

Expected: marker exits 0. Do not rerun this marker during later revisions.

- [ ] **Step 4: Implement the ES-module builder**

The builder must use only the bundled Artifact Tool and byte-backed images:

```javascript
import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const SIZE = { width: 1280, height: 720 };
const COLORS = { ink: "#000000", panel: "#EDEDED", rule: "#B8BCC4", accent: "#3D8DFF", pale: "#D0EDFA" };

async function imageBytes(filePath) {
  const bytes = await fs.readFile(filePath);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

function setNotes(slide, slideSpec) {
  const lines = [slideSpec.presenterNote ?? "", "", "[Sources]", ...slideSpec.sources.map((source) => `- ${source}`)];
  slide.speakerNotes.textFrame.setText(lines.filter((line, index) => line || index > 0).join("\n"));
  slide.speakerNotes.setVisible(true);
}

function addTitle(slide, title, number) {
  const box = slide.shapes.add({
    geometry: "textbox",
    name: `slide-${number}-title`,
    position: { left: 52, top: 34, width: 1168, height: 72 },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  box.text = title;
  box.text.style = { fontSize: 48, bold: true, color: COLORS.ink, typeface: "Arial", autoFit: "shrinkText" };
}

function addText(slide, name, text, position, fontSize = 24, options = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    name,
    position,
    fill: options.fill ?? "none",
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
  });
  box.text = text;
  box.text.style = {
    fontSize,
    bold: options.bold ?? false,
    color: options.color ?? COLORS.ink,
    typeface: "Arial",
    alignment: options.alignment ?? "left",
    verticalAlignment: options.verticalAlignment ?? "top",
    autoFit: "shrinkText",
  };
  return box;
}

function buildCover(slide, spec) {
  addText(slide, "cover-title", spec.title, { left: 52, top: 170, width: 560, height: 210 }, 68, { bold: true });
  addText(slide, "cover-subtitle", spec.subtitle, { left: 52, top: 410, width: 560, height: 110 }, 28);
}

function buildEvidenceSplit(slide, spec) {
  addText(slide, `${spec.id}-claim`, spec.claim, { left: 52, top: 132, width: 520, height: 120 }, 32, { bold: true });
  addText(slide, `${spec.id}-body`, spec.body.join("\n\n"), { left: 52, top: 278, width: 520, height: 330 }, 24);
}

function buildMetricSlide(slide, spec) {
  const lefts = [52, 454, 856];
  for (const [index, metric] of spec.metrics.entries()) {
    addText(slide, `${spec.id}-metric-${index + 1}`, metric.value, { left: lefts[index], top: 250, width: 350, height: 120 }, 54, { bold: true, color: COLORS.accent });
    addText(slide, `${spec.id}-metric-label-${index + 1}`, metric.label, { left: lefts[index], top: 392, width: 350, height: 100 }, 24);
  }
  addText(slide, `${spec.id}-interpretation`, spec.interpretation, { left: 52, top: 540, width: 1150, height: 80 }, 24);
}

function buildConclusion(slide, spec) {
  addText(slide, `${spec.id}-lead`, spec.claim, { left: 52, top: 160, width: 1120, height: 140 }, 42, { bold: true });
  addText(slide, `${spec.id}-steps`, spec.body.join("\n\n"), { left: 52, top: 340, width: 1120, height: 270 }, 28);
}

function addSlideContent(slide, spec, number) {
  if (number === 1) return buildCover(slide, spec);
  if (spec.layout === "metrics") return buildMetricSlide(slide, spec);
  if (number >= 9) return buildConclusion(slide, spec);
  return buildEvidenceSplit(slide, spec);
}

async function writePreviews(presentation, outputDirectory) {
  await fs.mkdir(outputDirectory, { recursive: true });
  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 1 });
    await fs.writeFile(path.join(outputDirectory, `${stem}.png`), new Uint8Array(await png.arrayBuffer()));
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(outputDirectory, `${stem}.layout.json`), await layout.text(), "utf8");
  }
  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await fs.writeFile(path.join(outputDirectory, "montage.webp"), new Uint8Array(await montage.arrayBuffer()));
}

async function main() {
  const root = path.resolve(process.argv[process.argv.indexOf("--project-root") + 1]);
  const packageData = JSON.parse(await fs.readFile(path.join(root, "results/presentation/phase7b_package.json"), "utf8"));
  const presentation = Presentation.create({ slideSize: SIZE });
  for (const [index, spec] of packageData.deck.slides.entries()) {
    const slide = presentation.slides.add();
    slide.background.fill = "#FFFFFF";
    if (index > 0) addTitle(slide, spec.title, index + 1);
    if (spec.figure) {
      slide.images.add({
        blob: await imageBytes(path.join(root, spec.figure)),
        contentType: "image/png",
        alt: spec.figureAlt,
        fit: "contain",
        position: spec.figureFrame,
      });
    }
    addSlideContent(slide, spec, index + 1);
    setNotes(slide, spec);
  }
  await writePreviews(presentation, path.join(root, "tmp/phase7b/slides"));
  const output = path.join(root, "presentation/final_presentation.pptx");
  await fs.mkdir(path.dirname(output), { recursive: true });
  await (await PresentationFile.exportPptx(presentation)).save(output);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
```

The template assigns `layout: "metrics"` to slides 3 and 9; all other non-cover evidence slides use the split composition except slide 10, which uses the conclusion composition through its sequence number. If visual QA shows adjacent silhouettes repeating more than twice, change only the relevant `layout` value and dispatch branch while preserving the four named composition functions.

- [ ] **Step 5: Build, normalize, and run tests**

```powershell
& $BundledPython scripts/export_phase7b_package.py --project-root .
& $BundledNode scripts/build_presentation.mjs --project-root .
& $BundledPython scripts/normalize_phase7b_office.py --path presentation/final_presentation.pptx --suffix .pptx
& $BundledPython -m unittest tests.presentation.test_presentation_structure -v
```

Expected: 10 slides, 10 source-note blocks, all claims present, no placeholders.

- [ ] **Step 6: Render and inspect the first complete deck**

```powershell
& $BundledPython "$env:SKILL_DIR\container_tools\render_slides.py" presentation/final_presentation.pptx
& $BundledPython "$env:SKILL_DIR\container_tools\slides_test.py" presentation/final_presentation.pptx
```

Expected: 10 PNGs and zero overflow failures. Inspect all 10 PNGs individually and the montage; record every issue in `tmp/phase7b/qa-ledger.txt` before editing.

- [ ] **Step 7: Commit**

```powershell
git add scripts/build_presentation.mjs tests/presentation/test_presentation_structure.py presentation/final_presentation.pptx
git commit -m "feat: build evidence-grounded Phase 7B deck"
```

### Task 4: Build the one-page research summary and PDF

**Files:**
- Create: `scripts/phase7b/summary.py`
- Create: `scripts/build_research_summary.py`
- Create: `scripts/export_research_summary_pdf.ps1`
- Create: `tests/presentation/test_research_summary.py`
- Create: `docs/summary/research_summary.docx`
- Create: `docs/summary/research_summary.pdf`

**Interfaces:**
- Consumes: resolved `package["summary"]`, one deterministic reliability PNG, and `normalize_openxml_package`.
- Produces: a one-page Letter DOCX and one-page normalized PDF with a fixed Phase 7B document ID.

- [ ] **Step 1: Write failing summary tests**

```python
class ResearchSummaryTests(unittest.TestCase):
    def test_docx_is_one_page_ready_and_contains_required_claims(self) -> None:
        document = Document(DOCX)
        self.assertEqual(len(document.sections), 1)
        section = document.sections[0]
        self.assertAlmostEqual(section.page_width.inches, 8.5, places=2)
        self.assertAlmostEqual(section.page_height.inches, 11.0, places=2)
        self.assertEqual(len(document.inline_shapes), 1)
        text = "\n".join(paragraph.text for paragraph in document.paragraphs)
        for value in ("7.283%", "10/13", "30/30", "0/30"):
            self.assertIn(value, text)
        self.assertIn("Simulation scope", text)
        self.assertNotIn("{{", text)

    def test_pdf_is_exactly_one_page(self) -> None:
        reader = PdfReader(PDF)
        self.assertEqual(len(reader.pages), 1)
        text = reader.pages[0].extract_text() or ""
        self.assertIn("Reliable Robotic Manipulation", text)
        self.assertIn("Limitations and next steps", text)
```

- [ ] **Step 2: Run RED**

```powershell
& $BundledPython -m unittest tests.presentation.test_research_summary -v
```

Expected: missing DOCX/PDF failures.

- [ ] **Step 3: Mark the DOCX artifact operation exactly once**

```powershell
& $BundledNode "$env:DOCS_SKILL_DIR\container_tools\mark_artifact_operation_started.mjs" --operation-kind create --expected-output-count 1 --output-format docx
```

Expected: exit 0. Do not rerun during revisions.

- [ ] **Step 4: Implement exact one-page Word styles and content**

Use explicit Letter geometry, 0.55-inch margins as the named one-page override, Arial 10.25 pt body, 1.05 line spacing, black headings, pale-gray/blue result strip, and no running header/footer. The title block follows `memo_masthead` without a bottom border.

```python
def configure_document(document: Document) -> None:
    section = document.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.55)
    section.bottom_margin = Inches(0.55)
    section.left_margin = Inches(0.6)
    section.right_margin = Inches(0.6)
    normal = document.styles["Normal"]
    normal.font.name = "Arial"
    normal.font.size = Pt(10.25)
    normal.paragraph_format.space_after = Pt(4)
    normal.paragraph_format.line_spacing = 1.05


def build_summary(root: Path, output: Path) -> None:
    package = json.loads((root / "results/presentation/phase7b_package.json").read_text(encoding="utf-8"))
    summary = package["summary"]
    document = Document()
    configure_document(document)
    add_masthead(document, summary)
    add_takeaway(document, summary["takeaway"])
    add_problem_method_columns(document, summary)
    add_result_strip(document, summary["results"])
    add_figure(document, root / summary["figure"], summary["figureCaption"])
    add_significance_limitations(document, summary)
    add_sources(document, summary["sources"])
    output.parent.mkdir(parents=True, exist_ok=True)
    document.save(output)
    normalize_openxml_package(output, ".docx")
```

The result strip must use real table geometry with column widths summing to the usable page width, explicit cell margins, no fixed row height, and centered short values. Remaining prose must not use tables.

- [ ] **Step 5: Export and normalize PDF**

Adapt the owned Word COM pattern from `scripts/export_report_pdf.ps1`. Restrict the DOCX and PDF paths to `docs/summary`, use hidden Word, close only the owned document/process in `finally`, and invoke a generalized PDF normalizer with:

```python
FIXED_PDF_DATE = "D:20260821000000+08'00'"
DOCUMENT_ID = sha256(b"PID-vs-Fuzzy-PID-Phase-7B-research-summary").digest()[:16]
```

- [ ] **Step 6: Render, inspect, test, and commit**

```powershell
& $BundledPython scripts/build_research_summary.py --project-root .
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export_research_summary_pdf.ps1 -ProjectRoot .
& $BundledPython "$env:DOCS_SKILL_DIR\render_docx.py" docs/summary/research_summary.docx --output_dir tmp/phase7b/summary-docx --emit_pdf
& $BundledPython -m unittest tests.presentation.test_research_summary -v
```

Expected: exactly one DOCX render PNG, one PDF page, all tests PASS. Inspect the page at full size for clipping, cramped cells, image quality, and balanced whitespace.

Commit:

```powershell
git add scripts/phase7b/summary.py scripts/build_research_summary.py scripts/export_research_summary_pdf.ps1 tests/presentation/test_research_summary.py docs/summary/research_summary.docx docs/summary/research_summary.pdf
git commit -m "feat: publish one-page Phase 7B research summary"
```

### Task 5: End-to-end verifier, manifest, and README integration

**Files:**
- Create: `scripts/verify_phase7b.ps1`
- Create: `docs/presentation/phase7b_build_manifest.json`
- Modify: `scripts/verify.ps1`
- Modify: `README.md`
- Modify: `tests/presentation/test_phase7b_outputs.py`

**Interfaces:**
- Produces one final line: `PHASE7B_VERIFIED slides=10 notes=10 summary_docx_pages=1 summary_pdf_pages=1 placeholders=0`.
- Adds Phase 7B verification after Phase 7A report verification without rerunning controller experiments a second time.

- [ ] **Step 1: Write failing manifest and reproducibility tests**

```python
def test_manifest_hashes_all_inputs_and_outputs(self) -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    self.assertEqual(manifest["schemaVersion"], 1)
    self.assertEqual(manifest["document"], {"slideCount": 10, "notesCount": 10, "summaryPageCount": 1})
    for group in ("sources", "outputs"):
        for record in manifest[group]:
            path = ROOT / record["path"]
            self.assertTrue(path.is_file(), record["path"])
            self.assertEqual(record["sha256"], sha256_file(path), record["path"])


def test_two_phase7b_builds_are_hash_identical(self) -> None:
    expected = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
    run_phase7b_build(ROOT)
    actual = {path: sha256_file(ROOT / path) for path in FINAL_OUTPUTS}
    self.assertEqual(actual, expected)
```

- [ ] **Step 2: Run RED and implement the verifier**

`verify_phase7b.ps1` must:

1. validate bundled Node/Python and Word availability;
2. export the evidence package;
3. run pre-build Python tests;
4. build and normalize the PPTX;
5. build DOCX, export PDF, and normalize both;
6. write the manifest atomically with LF JSON;
7. run all presentation tests;
8. render PPTX/DOCX/PDF to ignored directories;
9. run `slides_test.py`;
10. confirm 10 slides, 10 notes, one DOCX page, one PDF page, zero placeholders, and no owned WINWORD process.

Use command-scoped variables copied exactly from `load_workspace_dependencies`; do not discover or install alternate runtimes.

- [ ] **Step 3: Update the root verification chain**

Append only this checked call after `verify_report.ps1` succeeds:

```powershell
& (Join-Path $PSScriptRoot 'verify_phase7b.ps1')
if ($LASTEXITCODE -ne 0) {
    throw "Phase 7B verification failed with exit code $LASTEXITCODE"
}
```

- [ ] **Step 4: Add focused README guidance**

Add one Phase 7B section that explains:

- when to use the full report versus the deck versus the one-page summary;
- the exact build/verify command;
- the three final paths;
- that all visible values resolve from the same Phase 7A evidence package; and
- that slide notes contain source blocks.

Do not duplicate the report's numerical narrative or expand the public `+rrm` API inventory.

- [ ] **Step 5: Run verification and commit**

```powershell
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_phase7b.ps1
git diff --check
```

Expected: the exact `PHASE7B_VERIFIED` summary and zero failures.

Commit:

```powershell
git add scripts/verify_phase7b.ps1 scripts/verify.ps1 README.md docs/presentation/phase7b_build_manifest.json tests/presentation/test_phase7b_outputs.py
git commit -m "test: verify reproducible Phase 7B deliverables"
```

### Task 6: Visual refinement and independent claim audit

**Files:**
- Modify: `docs/presentation/phase7b_template.json`
- Modify: `scripts/build_presentation.mjs`
- Modify: `scripts/phase7b/summary.py`
- Modify: `presentation/final_presentation.pptx`
- Modify: `docs/summary/research_summary.docx`
- Modify: `docs/summary/research_summary.pdf`
- Modify: `docs/presentation/phase7b_build_manifest.json`
- Create: `docs/presentation/PHASE7B_CLAIM_AUDIT.md`
- Create: `docs/presentation/PHASE7B_CLAIM_AUDIT.json`

**Interfaces:**
- Consumes: final render PNGs, raw evidence, source notes, and build manifest.
- Produces: a zero-context audit with exactly 10 slide groups plus one summary group.

- [ ] **Step 1: Inspect every rendered artifact**

For all 10 slide PNGs and the summary PNG, record PASS/REWORK for:

- title wrapping;
- minimum text size;
- image crop and sharpness;
- overlap and clipping;
- balanced whitespace;
- visual-to-caption agreement;
- source-note presence;
- claim prominence versus caveat prominence; and
- narrative continuity.

Fix every REWORK item, rebuild, rerender, and reinspect the complete affected artifact.

- [ ] **Step 2: Run an independent zero-context claim audit**

Audit each displayed number, comparison, scope statement, slide note source block, and summary result against raw MAT/CSV evidence through the Phase 7A evidence manifest. Classify each of the 11 groups as `exact_match`, `rounding_ok`, `unsupported_claim`, or `ambiguous_mapping`. Overall PASS requires zero unsupported, ambiguous, WARN, or FAIL findings.

- [ ] **Step 3: Re-run all Phase 7B checks and commit**

```powershell
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_phase7b.ps1
git diff --check
```

Expected: PASS, stable artifact hashes, 11/11 claim groups supported.

Commit:

```powershell
git add docs/presentation scripts/build_presentation.mjs scripts/phase7b/summary.py presentation/final_presentation.pptx docs/summary/research_summary.docx docs/summary/research_summary.pdf
git commit -m "docs: finalize audited Phase 7B package"
```

### Task 7: Full regression, integration, and cleanup

**Files:**
- Modify only if verification reveals a Phase 7B defect.

**Interfaces:**
- Consumes: the completed feature branch.
- Produces: fast-forward integration to local `main`, one clean worktree, no stale stash, and no remote mutation.

- [ ] **Step 1: Run full Phase 1 through Phase 7B verification**

```powershell
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Expected:

- MATLAB 150/150 PASS;
- Phase 7A Python report tests 24/24 PASS;
- Phase 7A report remains 8 pages, 6 figures, 9 tables, and 8 references;
- Phase 7B deck is 10 slides with 10 source-note blocks;
- summary DOCX/PDF are one page each; and
- no placeholder, overflow, or claim-audit failure.

- [ ] **Step 2: Verify clean feature state and hashes**

```powershell
git diff --check
git status --short
Get-FileHash presentation/final_presentation.pptx,docs/summary/research_summary.docx,docs/summary/research_summary.pdf -Algorithm SHA256
Get-FileHash Daniel_MATLAB_Robotics_Project_Implementation_Guide.docx -Algorithm SHA256
```

Expected: only the user-owned root guide is untracked in main; its hash remains `6786B8FD7C34A47EDC1823E5804EA34A935980425DE8013161D1DDDD99E72C77`.

- [ ] **Step 3: Fast-forward merge locally and rerun the full gate from main**

```powershell
git merge --ff-only feature/phase-7b-presentation-summary
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
```

Expected: exit 0 and identical Phase 7B hashes to the feature worktree.

- [ ] **Step 4: Remove only the validated temporary worktree and branch**

Resolve the exact worktree path, verify it is a direct child of `.worktrees`, require a clean feature status, then:

```powershell
git worktree remove --force -- 'E:\YZH123123\PID vs Fuzzy PID\.worktrees\phase-7b-presentation-summary'
git worktree prune
git branch -d feature/phase-7b-presentation-summary
```

Expected: one main worktree, no Phase 7B feature branch, no stash, no WINWORD process, no remote change.

## Plan Self-Review

- **Spec coverage:** Tasks 1-7 cover the evidence chain, all 10 slide jobs, one-page summary, source notes, visual inspection, reproducibility, README guidance, independent claim audit, regression, and cleanup.
- **Placeholder scan:** Angle-bracket text appears only in the safety-validated cleanup command, where the exact path must be resolved immediately before execution; no implementation content is deferred.
- **Interface consistency:** `build_phase7b_package`, `normalize_openxml_package`, `sha256_file`, and the resolved package schema are named consistently across tasks.
- **Scope:** No experiment, controller, threshold, institutional identity, remote publishing, or unrelated refactor is included.
