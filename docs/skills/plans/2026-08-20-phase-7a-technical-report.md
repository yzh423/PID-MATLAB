# Phase 7A Evidence Synthesis and Technical Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an evidence-grounded 8 to 12 page English technical report in Markdown, DOCX, and PDF from the verified Phase 1 through Phase 6B results.

**Architecture:** A MATLAB package boundary validates all formal MAT/CSV artifacts and exports one JSON evidence manifest. Small Python modules validate the manifest and citations, resolve a Markdown template, and assemble a styled DOCX; a PowerShell script uses an owned hidden Microsoft Word instance to export PDF. Automated content, provenance, DOCX, PDF, and visual gates prevent numeric drift, selective reporting, unresolved citations, and layout defects.

**Tech Stack:** MATLAB R2026a Update 4, bundled Python with `python-docx` 1.2.0, Pillow 12.3.0 and `pypdf` 6.10.0, Microsoft Word Office 16, PowerShell, Markdown, JSON, DOCX, PDF, MATLAB Unit Test, Python `unittest`, Git worktrees.

## Global Constraints

- The report language is English and the rendered PDF target is 8 to 12 pages including references.
- Existing formal MAT/CSV artifacts are the numeric source of truth; do not retune or rerun an experiment with changed parameters.
- Preserve every Phase 1 through Phase 6B robot, controller, trajectory, scenario, seed, metric, threshold, and acceptance definition.
- Include both successful and unsuccessful cases, including combined-stress failures and failed manual/Fuzzy-PID pick-transfer-place acceptance.
- Use numbered IEEE citations verified against original papers or official MathWorks pages.
- Use only the installed MATLAB, bundled Python libraries, and installed Microsoft Word; do not add a dependency.
- Never claim real-robot, hardware-safety, contact, grasping, or real-time validation.
- Keep Word hidden, close only the document and Word instance created by the exporter, and leave pre-existing Word processes untouched.
- Commit the report Markdown, DOCX, PDF, reference bank, and build manifest; ignore `results/report/report_evidence.json` and temporary renders.
- Preserve `Daniel_MATLAB_Robotics_Project_Implementation_Guide.docx` as unrelated, untracked user content.
- Do not push, publish, email, or open a pull request without explicit authorization.

---

## File Map

```text
+rrm/+report/exportEvidence.m
    Validates formal artifacts and returns/writes the evidence manifest.
experiments/export_report_evidence.m
    Thin reproducible entry point with optional reportOutputRoot override.
tests/report/TestExportReportEvidence.m
    MATLAB behavior, schema, count, source, value, and stable-error tests.
scripts/reporting/evidence.py
    JSON schema validation, path lookup, numeric formatting, and token resolution.
scripts/reporting/content.py
    Citation-bank validation and report completeness/claim checks.
scripts/reporting/document.py
    Narrow Markdown parser and deterministic python-docx assembly.
scripts/reporting/__init__.py
    Package marker with no side effects.
scripts/build_report.py
    Thin CLI orchestrator for Markdown, DOCX, and build manifest.
scripts/export_report_pdf.ps1
    Owned hidden Word lifecycle and PDF export.
scripts/verify_report.ps1
    Evidence export, tests, build, PDF export, and final validation gate.
docs/report/technical_report_template.md
    English report narrative, evidence tokens, citations, tables, and figure directives.
docs/report/references.json
    Verified eight-source citation bank with claim mappings.
docs/report/technical_report.md
    Resolved canonical report.
docs/report/technical_report.docx
    Styled editable report deliverable.
docs/report/technical_report.pdf
    Final rendered report deliverable.
docs/report/build_manifest.json
    SHA-256 provenance and output metadata.
tests/report/test_report_evidence.py
    Python evidence schema and token tests.
tests/report/test_report_content.py
    Citation, required-section, failure-case, and prohibited-claim tests.
tests/report/test_report_document.py
    DOCX/PDF structure, media, text, page-count, and unresolved-token tests.
README.md
    Report build, final report links, and Phase 7A status.
.gitignore
    Generated evidence and render exclusions.
scripts/verify.ps1
    Existing Phase 1 through Phase 6B verification plus the report gate.
```

## Task 1: Export a Validated Report Evidence Manifest

**Files:**
- Create: `+rrm/+report/exportEvidence.m`
- Create: `experiments/export_report_evidence.m`
- Create: `tests/report/TestExportReportEvidence.m`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `projectRoot (1,1) string`, `outputPath (1,1) string`, and formal artifacts under `results/data` and `results/figures`.
- Produces: `evidence = rrm.report.exportEvidence(projectRoot,outputPath)`, a scalar struct also written as UTF-8 JSON.
- Produces manifest keys: `schemaVersion`, `generatedAt`, `protocol`, `nominal`, `optimization`, `deterministic`, `stochastic`, `cartesian`, `simulink`, `multibody`, `artifacts`, and `sources`.
- Stable errors: `rrm:report:MissingArtifact`, `rrm:report:InvalidArtifact`, `rrm:report:UnexpectedStudyShape`, `rrm:report:NonFiniteEvidence`, `rrm:report:InvalidOutputPath`.

- [ ] **Step 1: Write failing MATLAB tests for the public contract**

Create `tests/report/TestExportReportEvidence.m` with these test methods:

```matlab
classdef TestExportReportEvidence < matlab.unittest.TestCase
    methods (Test)
        function exportsCompleteFormalEvidence(testCase)
            root = projectRoot();
            output = string(tempname)+".json";
            testCase.addTeardown(@() deleteIfPresent(output));

            evidence = rrm.report.exportEvidence(root,output);

            testCase.verifyTrue(isfile(output));
            testCase.verifyEqual(evidence.schemaVersion,1);
            testCase.verifyEqual(evidence.deterministic.runCount,39);
            testCase.verifyEqual(evidence.stochastic.trialCount,360);
            testCase.verifyEqual(evidence.cartesian.runCount,6);
            testCase.verifyEqual(evidence.simulink.runCount,2);
            testCase.verifyEqual(evidence.multibody.runCount,2);
            testCase.verifyTrue(all(evidence.multibody.agreementPass));
            testCase.verifyTrue(all(evidence.multibody.trackingSuccess));
            testCase.verifyEqual(evidence.multibody.maximumOutOfPlane,0);
        end

        function preservesKnownFormalValues(testCase)
            evidence = rrm.report.exportEvidence(projectRoot(), ...
                string(tempname)+".json");
            testCase.addTeardown(@() deleteIfPresent(evidence.outputPath));

            testCase.verifyEqual(evidence.nominal.manualPid.steadyRms, ...
                [0.00126841;0.0137622],"RelTol",5e-6);
            testCase.verifyEqual(evidence.optimization.objectiveReductionPercent, ...
                7.283,"AbsTol",5e-4);
            testCase.verifyEqual(evidence.deterministic.successCount, ...
                [8;9;10]);
            testCase.verifyEqual(evidence.stochastic.combinedSuccessCount, ...
                [0;0;0]);
        end

        function rejectsMissingFormalArtifact(testCase)
            fixture = makeFixtureWithout("nominal_pid.mat");
            testCase.addTeardown(@() rmdir(fixture,"s"));
            testCase.verifyError(@() rrm.report.exportEvidence( ...
                fixture,fullfile(fixture,"report.json")), ...
                "rrm:report:MissingArtifact");
        end
    end
end
```

The fixture helper copies only the small required directory structure and deliberately omits one named source. It must never delete or move a real result artifact.

- [ ] **Step 2: Run the MATLAB report test and verify red state**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); results=runtests('tests/report/TestExportReportEvidence.m'); assertSuccess(results);"
```

Expected: FAIL because `rrm.report.exportEvidence` is undefined.

- [ ] **Step 3: Implement the minimum validated exporter**

Implement this public boundary:

```matlab
function evidence = exportEvidence(projectRoot,outputPath)
%EXPORTEVIDENCE Validate formal results and export report evidence as JSON.
arguments
    projectRoot (1,1) string
    outputPath (1,1) string
end

projectRoot = canonicalProjectRoot(projectRoot);
sources = requiredSources(projectRoot);
requireFiles(sources);
evidence = collectEvidence(sources,projectRoot);
validateEvidence(evidence);
writeJson(outputPath,evidence);
evidence.outputPath = canonicalOutputPath(outputPath);
end
```

Use `load(...,variableNames...)` so large histories are not duplicated unnecessarily. Convert tables with stable row ordering. Store numeric arrays as JSON arrays and table-like records as struct arrays. Read these exact sources:

```text
nominal_pid_vs_fuzzy.mat
pid_optimization.mat
deterministic_robustness.mat
stochastic_robustness.mat
cartesian_tasks.mat
simulink_cross_validation.mat
multibody_cross_validation.mat
deterministic_robustness_runs.csv
deterministic_robustness_summary.csv
stochastic_robustness_trials.csv
stochastic_robustness_summary.csv
cartesian_tasks_runs.csv
simulink_cross_validation_runs.csv
multibody_cross_validation_runs.csv
```

Require formal modes equal to `"full"`, expected controller names in stable order, unique rows, finite required report values, and the frozen run counts. Permit `NaN` only for explicitly not-applicable waypoint/recovery fields and encode those values as JSON `null` through a named sanitizer.

The experiment entry point is deliberately thin:

```matlab
%EXPORT_REPORT_EVIDENCE Export verified results for the report builder.
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);
if ~exist("reportOutputRoot","var")
    reportOutputRoot = fullfile(projectRoot,"results","report");
end
if ~isfolder(reportOutputRoot)
    mkdir(reportOutputRoot);
end
evidence = rrm.report.exportEvidence(projectRoot, ...
    fullfile(reportOutputRoot,"report_evidence.json"));
fprintf("Report evidence schema %d exported with %d stochastic trials.\n", ...
    evidence.schemaVersion,evidence.stochastic.trialCount);
```

Add to `.gitignore`:

```gitignore
results/report/report_evidence.json
results/report/rendered-pages/
```

- [ ] **Step 4: Run exporter tests and static analysis**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); results=runtests('tests/report/TestExportReportEvidence.m'); assertSuccess(results); files={'+rrm/+report/exportEvidence.m','experiments/export_report_evidence.m','tests/report/TestExportReportEvidence.m'}; issues=0; for k=1:numel(files), issues=issues+numel(checkcode(files{k},'-id')); end; assert(issues==0);"
```

Expected: all report exporter tests pass and `issues == 0`.

- [ ] **Step 5: Generate and inspect the formal manifest**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('experiments/export_report_evidence.m');"
```

Expected: `results/report/report_evidence.json` is nonempty, schema version is 1, deterministic count is 39, stochastic count is 360, Cartesian count is 6, and both validation studies contain two passing rows.

- [ ] **Step 6: Commit the evidence boundary**

```powershell
git add -- '+rrm/+report/exportEvidence.m' 'experiments/export_report_evidence.m' 'tests/report/TestExportReportEvidence.m' '.gitignore'
git commit -m "feat: export validated report evidence"
```

## Task 2: Validate Evidence and Resolve Report Tokens in Python

**Files:**
- Create: `scripts/reporting/__init__.py`
- Create: `scripts/reporting/evidence.py`
- Create: `tests/report/test_report_evidence.py`

**Interfaces:**
- Consumes: `Path` to `report_evidence.json` and Markdown text containing `{{path.to.value|format}}` tokens.
- Produces: `load_evidence(path: Path) -> dict[str, object]`.
- Produces: `resolve_tokens(template: str, evidence: Mapping[str, object]) -> tuple[str, set[str]]`.
- Raises: `EvidenceError` for schema/count/value/token failures.

- [ ] **Step 1: Write failing Python schema and token tests**

Create tests that load the generated formal manifest and assert:

```python
class EvidenceTests(unittest.TestCase):
    def test_formal_manifest_has_frozen_shape(self) -> None:
        evidence = load_evidence(EVIDENCE_PATH)
        self.assertEqual(evidence["schemaVersion"], 1)
        self.assertEqual(evidence["deterministic"]["runCount"], 39)
        self.assertEqual(evidence["stochastic"]["trialCount"], 360)
        self.assertEqual(evidence["cartesian"]["runCount"], 6)

    def test_resolves_named_numeric_token(self) -> None:
        text, used = resolve_tokens(
            "Worst EE difference: {{multibody.endEffectorMaxWorst|.4e}} m.",
            load_evidence(EVIDENCE_PATH),
        )
        self.assertIn("3.3422e-16", text)
        self.assertEqual(used, {"multibody.endEffectorMaxWorst"})

    def test_unknown_token_is_rejected(self) -> None:
        with self.assertRaisesRegex(EvidenceError, "unknown evidence token"):
            resolve_tokens("{{nominal.missing|.3f}}", load_evidence(EVIDENCE_PATH))
```

Also test an unsupported format string, non-finite numeric token, list used as a scalar, unresolved braces, and deterministic resolution order.

- [ ] **Step 2: Run Python tests and verify red state**

Run:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest '.\tests\report\test_report_evidence.py' -v
```

Expected: import failure because `scripts.reporting.evidence` does not exist.

- [ ] **Step 3: Implement schema validation and token resolution**

Use typed, side-effect-free functions:

```python
TOKEN = re.compile(r"\{\{([a-zA-Z][a-zA-Z0-9_.]*)(?:\|([^{}]+))?\}\}")

class EvidenceError(ValueError):
    """Raised when report evidence cannot support a reproducible claim."""

def load_evidence(path: Path) -> dict[str, object]:
    if not path.is_file():
        raise EvidenceError(f"evidence file does not exist: {path}")
    evidence = json.loads(path.read_text(encoding="utf-8"))
    validate_evidence(evidence)
    return evidence

def lookup(evidence: Mapping[str, object], dotted_path: str) -> object:
    value: object = evidence
    for part in dotted_path.split("."):
        if not isinstance(value, Mapping) or part not in value:
            raise EvidenceError(f"unknown evidence token: {dotted_path}")
        value = value[part]
    return value
```

Restrict formatting to explicit numeric formats matching `.[0-9]+[feg]`, integer `d`, or no format. Reject arbitrary Python format expressions. After substitution, reject any remaining `{{` or `}}` sequence.

- [ ] **Step 4: Run Python evidence tests**

Run the command from Step 2.

Expected: all evidence and token tests pass.

- [ ] **Step 5: Commit the Python evidence layer**

```powershell
git add -- 'scripts/reporting/__init__.py' 'scripts/reporting/evidence.py' 'tests/report/test_report_evidence.py'
git commit -m "feat: validate report evidence tokens"
```

## Task 3: Build and Verify the Citation and Content Gate

**Files:**
- Create: `docs/report/references.json`
- Create: `scripts/reporting/content.py`
- Create: `tests/report/test_report_content.py`

**Interfaces:**
- Consumes: citation JSON and resolved report Markdown.
- Produces: `load_references(path: Path) -> list[Reference]` and `validate_report(markdown: str,references: Sequence[Reference]) -> None`.
- Raises: `ContentError` for citation gaps, missing sections, omitted failure cases, or prohibited claims.

- [ ] **Step 1: Verify and record the eight-source citation bank**

Create `docs/report/references.json` with stable IDs 1 through 8 and these verified sources:

1. K. J. Åström and T. Hägglund, “The future of PID control,” *Control Engineering Practice*, 9(11), 1163–1175, 2001, DOI `10.1016/S0967-0661(01)00062-4`.
2. L. A. Zadeh, “Fuzzy sets,” *Information and Control*, 8(3), 338–353, 1965, DOI `10.1016/S0019-9958(65)90241-X`.
3. E. H. Mamdani and S. Assilian, “An experiment in linguistic synthesis with a fuzzy logic controller,” *International Journal of Man-Machine Studies*, 7(1), 1–13, 1975, DOI `10.1016/S0020-7373(75)80002-2`.
4. E. B. Wilson, “Probable inference, the law of succession, and statistical inference,” *Journal of the American Statistical Association*, 22(158), 209–212, 1927, DOI `10.1080/01621459.1927.10502953`.
5. MathWorks, “fmincon: Solve constrained nonlinear multivariable minimization problem,” official documentation, `https://www.mathworks.com/help/optim/ug/fmincon.html`.
6. MathWorks, “Simscape Multibody: Model and simulate multibody mechanical systems,” official documentation, `https://www.mathworks.com/help/sm/`.
7. D. Driess et al., “PaLM-E: An Embodied Multimodal Language Model,” arXiv:`2303.03378`, 2023, `https://arxiv.org/abs/2303.03378`.
8. A. Brohan et al., “RT-2: Vision-Language-Action Models Transfer Web Knowledge to Robotic Control,” CoRL/PMLR 229, 2165–2183, 2023, `https://proceedings.mlr.press/v229/zitkovich23a.html`.

Each record includes `id`, `authors`, `title`, `container`, `year`, `pages`, `doi`, `url`, `sourceType`, and at least one `supports` claim label. DOI records use `https://doi.org/<doi>` as the URL.

- [ ] **Step 2: Write failing citation and content tests**

Tests must require:

```python
REQUIRED_HEADINGS = {
    "Abstract",
    "Introduction and Research Context",
    "Problem Formulation",
    "System Model",
    "Controller Design and Tuning",
    "Experimental Design",
    "Results",
    "Independent Model Validation",
    "Discussion",
    "Embodied-AI Execution Context",
    "Limitations and Future Work",
    "Conclusion",
    "References",
}

PROHIBITED_PATTERNS = (
    r"validated (?:on|with) real hardware",
    r"guarantees? safety",
    r"real-time performance (?:was|is) validated",
    r"Fuzzy-PID (?:is|was) universally superior",
)
```

Verify unique contiguous IDs, complete bibliographic fields, DOI syntax, official HTTPS domains for documentation, every reference cited at least once, no unknown citation ID, required headings, explicit strings `combined stress`, `0/30`, `pick-transfer-place`, `unsuccessful`, `simulation`, and `not hardware validation`.

- [ ] **Step 3: Run content tests and verify red state**

Run:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest '.\tests\report\test_report_content.py' -v
```

Expected: import or missing-content failure before implementation/template creation.

- [ ] **Step 4: Implement citation and claim validation**

Use frozen dataclasses and deterministic validation:

```python
@dataclass(frozen=True)
class Reference:
    id: int
    authors: str
    title: str
    container: str
    year: int
    pages: str
    doi: str
    url: str
    source_type: str
    supports: tuple[str, ...]

class ContentError(ValueError):
    """Raised when report content violates the evidence contract."""
```

Treat `[n]` as a citation only when `n` maps to a reference ID. Do not interpret table row indices or units as citations. Report all validation failures in one deterministic message so authors can fix the entire gate in one pass.

- [ ] **Step 5: Run citation tests and commit**

Run the Step 3 command. Expected: citation-bank tests pass; template-dependent tests remain skipped with the explicit `technical_report.md not built` reason until Task 4.

```powershell
git add -- 'docs/report/references.json' 'scripts/reporting/content.py' 'tests/report/test_report_content.py'
git commit -m "feat: verify report citations and claims"
```

## Task 4: Draft and Resolve the Canonical Markdown Report

**Files:**
- Create: `docs/report/technical_report_template.md`
- Create: `scripts/build_report.py`
- Modify: `tests/report/test_report_content.py`
- Create: `docs/report/technical_report.md` (generated and committed)

**Interfaces:**
- Consumes: template, evidence manifest, references, and selected figure paths.
- Produces: resolved UTF-8 `docs/report/technical_report.md`.
- CLI: `python scripts/build_report.py --project-root . --markdown-only`.

- [ ] **Step 1: Extend tests for the complete resolved Markdown**

Require the built report to contain all headings from Task 3, citation IDs `[1]` through `[8]`, no unresolved `{{...}}`, 2,800 to 5,500 English words excluding references, at least six Markdown figure directives, at least seven tables, SI units, and these evidence-backed statements:

```text
39 deterministic runs
360 paired stochastic trials
8/13, 9/13, and 10/13 deterministic successes
0/30 combined-stress successes for every controller
manual and Fuzzy-PID pick-transfer-place runs were unsuccessful
145 tests
not hardware validation
```

Require selected figures to be exactly:

```text
results/figures/nominal_pid_vs_fuzzy_tracking.png
results/figures/pid_optimization_objective.png
results/figures/deterministic_robustness_summary.png
results/figures/stochastic_robustness_chattering.png
results/figures/cartesian_tasks_paths.png
results/figures/multibody_cross_validation_tracking.png
```

- [ ] **Step 2: Run content tests and observe missing report failure**

Run the Task 3 test command.

Expected: FAIL because the template and resolved Markdown do not exist.

- [ ] **Step 3: Write the evidence-tokenized English report template**

Draft every section listed in the design. Use tokens only for quantitative evidence, for example:

```markdown
The deterministic matrix contained {{deterministic.runCount|d}} runs. Manual PID,
Mamdani Fuzzy-PID, and optimized PID succeeded in
{{deterministic.successCount.manualPid|d}}/13,
{{deterministic.successCount.fuzzyPid|d}}/13, and
{{deterministic.successCount.optimizedPid|d}}/13 cases, respectively.
```

The report must make these interpretations explicit:

- Fuzzy-PID is bounded and successful under nominal and isolated-noise conditions but not universally superior.
- Optimized PID improves nominal/held-out accuracy but has the largest high-noise torque slew and does not solve the combined stress case.
- Task-level Cartesian acceptance still includes the unchanged joint steady-state criterion.
- Simulink and Multibody near-roundoff agreement validates implementation consistency only under the fixed nominal protocol.
- The low-level controller can consume trajectories from a high-level embodied-AI planner, but the repository does not implement PaLM-E, RT-2, a VLA, perception, or planning.

Every figure has a descriptive caption, every table names units in headers, and every cited background statement has a citation immediately adjacent to it.

- [ ] **Step 4: Implement the Markdown-only CLI path**

The CLI resolves paths from `--project-root`, loads/validates evidence and references, resolves the template, validates the result, and writes atomically:

```python
def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    root = args.project_root.resolve()
    evidence = load_evidence(root / "results/report/report_evidence.json")
    references = load_references(root / "docs/report/references.json")
    template = (root / "docs/report/technical_report_template.md").read_text(
        encoding="utf-8"
    )
    markdown, used = resolve_tokens(template, evidence)
    validate_report(markdown, references)
    atomic_write(root / "docs/report/technical_report.md", markdown)
    if not args.markdown_only:
        build_docx_outputs(root, markdown, evidence, references, used)
    return 0
```

Return nonzero with a concise error message for expected evidence/content errors; preserve a traceback for unexpected programming faults.

- [ ] **Step 5: Build and validate canonical Markdown**

Run:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' '.\scripts\build_report.py' --project-root '.' --markdown-only
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest '.\tests\report\test_report_content.py' -v
```

Expected: `technical_report.md` is generated, every content test passes, and no token remains.

- [ ] **Step 6: Commit the canonical report source**

```powershell
git add -- 'docs/report/technical_report_template.md' 'docs/report/technical_report.md' 'scripts/build_report.py' 'tests/report/test_report_content.py'
git commit -m "docs: draft evidence-grounded technical report"
```

## Task 5: Build a Deterministic Styled DOCX

**Files:**
- Create: `scripts/reporting/document.py`
- Create: `tests/report/test_report_document.py`
- Create: `docs/report/technical_report.docx` (generated and committed)
- Create: `docs/report/build_manifest.json` (generated and committed)
- Modify: `scripts/build_report.py`

**Interfaces:**
- Consumes: resolved Markdown, project root, evidence, references, and used-token set.
- Produces: `build_docx(markdown: str,project_root: Path,output_path: Path) -> DocumentMetadata`.
- Produces build manifest fields: `schemaVersion`, `generatedAt`, `sources`, `outputs`, `usedEvidenceTokens`, `selectedFigures`, and SHA-256 hashes.

- [ ] **Step 1: Write failing DOCX structure tests**

Use `python-docx` to require:

- A4 page size and margins between 0.65 and 0.85 inches;
- title, subtitle, author/project metadata, and all required headings;
- body font at least 9.5 pt and figure/table captions at least 8 pt;
- at least six embedded images and seven tables;
- sequential `Figure 1` and `Table 1` captions with no gaps;
- a references heading with eight numbered entries;
- no unresolved token text;
- all image relationships embedded rather than externally linked; and
- a build manifest whose source and output hashes match current files.

- [ ] **Step 2: Run document tests and verify red state**

Run:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest '.\tests\report\test_report_document.py' -v
```

Expected: FAIL because `document.py`, DOCX, and manifest are absent.

- [ ] **Step 3: Implement the narrow Markdown-to-DOCX assembler**

Support only syntax present in the controlled template:

- `#`, `##`, and `###` headings;
- plain paragraphs;
- bullet and numbered lists;
- pipe tables;
- `![caption](relative/path.png)` images;
- `>` callout paragraphs;
- fenced `text` equations or protocols; and
- `[n]` numeric citations.

Reject unsupported fences, HTML, nested tables, missing images, and malformed table widths. Use deterministic styles:

```python
PAGE_WIDTH = Inches(8.27)
PAGE_HEIGHT = Inches(11.69)
MARGIN = Inches(0.72)
BODY_FONT = "Aptos"
BODY_SIZE = Pt(9.5)
CAPTION_SIZE = Pt(8.0)
```

Use `keep_with_next` for headings/captions, repeat table header rows, prevent row splitting where Word supports it, set figure width from available page width while preserving aspect ratio, and insert page breaks only before References when required to prevent a stranded heading.

- [ ] **Step 4: Implement full CLI output and provenance manifest**

Remove `--markdown-only` short-circuit for the default path. Build DOCX to a temporary sibling, validate it can be reopened by `python-docx`, then replace the destination. Hash these inputs:

```text
technical_report_template.md
references.json
report_evidence.json
all six selected PNG files
```

Hash these outputs after creation:

```text
technical_report.md
technical_report.docx
```

- [ ] **Step 5: Build and test DOCX**

Run:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' '.\scripts\build_report.py' --project-root '.'
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest discover -s '.\tests\report' -p 'test_*.py'
```

Expected: all Python report tests pass; DOCX and build manifest are nonempty and internally consistent.

- [ ] **Step 6: Open-render visual QA before commit**

Use Microsoft Word to open the generated DOCX read-only and inspect title page, equations/protocol blocks, all tables, all figures, captions, page breaks, and references. Do not save from the interactive viewer. Fix the generator rather than manually editing the DOCX.

- [ ] **Step 7: Commit the DOCX builder and artifact**

```powershell
git add -- 'scripts/reporting/document.py' 'scripts/build_report.py' 'tests/report/test_report_document.py' 'docs/report/technical_report.docx' 'docs/report/build_manifest.json'
git commit -m "feat: build styled technical report DOCX"
```

## Task 6: Export and Verify the Final PDF

**Files:**
- Create: `scripts/export_report_pdf.ps1`
- Create: `scripts/verify_report.ps1`
- Create: `docs/report/technical_report.pdf` (generated and committed)
- Modify: `tests/report/test_report_document.py`
- Modify: `docs/report/build_manifest.json` (generated)

**Interfaces:**
- Consumes: `docs/report/technical_report.docx`.
- Produces: `docs/report/technical_report.pdf` through one owned hidden Word instance.
- Verification output: one exit code and summary containing page count, text-bearing page count, selected figure count, citation count, and unresolved-token count.

- [ ] **Step 1: Extend tests for the final PDF**

Using `pypdf.PdfReader`, require:

```python
reader = PdfReader(PDF_PATH)
self.assertGreaterEqual(len(reader.pages), 8)
self.assertLessEqual(len(reader.pages), 12)
self.assertTrue(all(len((page.extract_text() or "").strip()) > 40
                    for page in reader.pages))
text = "\n".join(page.extract_text() or "" for page in reader.pages)
self.assertIn("Reliable Robotic Manipulation", text)
self.assertIn("Limitations and Future Work", text)
self.assertIn("References", text)
self.assertNotIn("{{", text)
```

Allow the title page to use a lower 40-character threshold only if it contains the exact title, author/project label, and date.

- [ ] **Step 2: Run the PDF tests and verify red state**

Run the document test command from Task 5.

Expected: FAIL because the PDF is absent.

- [ ] **Step 3: Implement safe hidden Word export**

Use PowerShell COM with exact ownership and cleanup:

```powershell
$word = $null
$document = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $document = $word.Documents.Open($docxPath, $false, $true)
    $document.ExportAsFixedFormat($pdfPath, 17)
}
finally {
    if ($null -ne $document) { $document.Close(0) }
    if ($null -ne $word) { $word.Quit() }
    if ($null -ne $document) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)
    }
    if ($null -ne $word) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
```

Resolve both paths before starting Word. Refuse identical paths, missing DOCX, non-`.docx`/`.pdf` extensions, and output outside `docs/report`. Delete only a zero-byte PDF created by the current failed invocation; never delete a pre-existing nonempty output on failure.

- [ ] **Step 4: Implement the report verification orchestrator**

`scripts/verify_report.ps1` performs, in order:

1. MATLAB evidence export;
2. MATLAB report tests;
3. MATLAB `checkcode` for report MATLAB files;
4. Python report tests excluding PDF expectations before build;
5. full Markdown/DOCX build;
6. Word PDF export;
7. full Python report tests including PDF;
8. `git diff --check`; and
9. one summary line with verified counts.

Use `$ErrorActionPreference = 'Stop'` and propagate every subprocess exit code.

- [ ] **Step 5: Export PDF and run automated verification**

Run:

```powershell
& '.\scripts\export_report_pdf.ps1'
& '.\scripts\verify_report.ps1'
```

Expected: PDF page count is 8 to 12, every expected content section is extractable, all report tests pass, and Word exits cleanly.

- [ ] **Step 6: Render and visually inspect every PDF page**

Render pages to `results/report/rendered-pages/` at readable resolution. Inspect every page for:

- clipped text or tables;
- figures below readable size;
- captions detached from figures/tables;
- headings stranded at page bottoms;
- blank or nearly blank pages;
- references crossing margins;
- inconsistent fonts or line spacing; and
- misleading scales or missing units.

If any issue appears, modify the template or generator, rebuild DOCX/PDF, rerun tests, and re-inspect every page.

- [ ] **Step 7: Commit the verified PDF pipeline and artifact**

```powershell
git add -- 'scripts/export_report_pdf.ps1' 'scripts/verify_report.ps1' 'tests/report/test_report_document.py' 'docs/report/technical_report.pdf' 'docs/report/build_manifest.json'
git commit -m "feat: export verified technical report PDF"
```

## Task 7: Document, Regress, Review, and Integrate Phase 7A

**Files:**
- Modify: `README.md`
- Modify: `scripts/verify.ps1`
- Modify: `docs/skills/specs/2026-08-20-phase-7a-technical-report-design.md` only if implementation decisions changed
- Modify: `docs/skills/plans/2026-08-20-phase-7a-technical-report.md` only to record an evidence-backed deviation

**Interfaces:**
- Consumes: completed report pipeline and deliverables.
- Produces: one-command project/report verification, documented report links, merged local `main`, generated main-checkout artifacts, and no owned Phase 7A worktree/branch.

- [ ] **Step 1: Update README with Phase 7A**

Add:

- Phase 7A to the evidence progression;
- report tool requirements and the installed-Word dependency;
- `scripts/verify_report.ps1` and report-only build commands;
- links to Markdown, DOCX, and PDF;
- report architecture and evidence-provenance explanation;
- final page count, figure/table/reference counts, and test evidence; and
- an explicit statement that the report packages simulation evidence and is not new hardware validation.

Keep the existing use-case-first structure and public API map. Add `rrm.report.exportEvidence` to the report workflow without turning the README into an API catalog.

- [ ] **Step 2: Add the report gate to complete verification**

After the existing MATLAB batch command succeeds, call:

```powershell
& (Join-Path $projectRoot 'scripts\verify_report.ps1')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
```

Avoid rerunning the eight controller experiments inside `verify_report.ps1`; it consumes the formal evidence generated earlier in `verify.ps1`.

- [ ] **Step 3: Run full static analysis and all tests**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); results=runtests('tests','IncludeSubfolders',true); fprintf('TOTAL=%d PASSED=%d FAILED=%d INCOMPLETE=%d\n',numel(results),nnz([results.Passed]),nnz([results.Failed]),nnz([results.Incomplete])); assertSuccess(results); roots={'+rrm','experiments','tests'}; files=[]; for r=1:numel(roots), files=[files;dir(fullfile(roots{r},'**','*.m'))]; end; issues=0; for k=1:numel(files), issues=issues+numel(checkcode(fullfile(files(k).folder,files(k).name),'-id')); end; fprintf('CHECKCODE_FILES=%d ISSUES=%d\n',numel(files),issues); assert(issues==0);"
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest discover -s '.\tests\report' -p 'test_*.py'
```

Expected: all MATLAB and Python tests pass, with zero static-analysis issues.

- [ ] **Step 4: Run complete Phase 1 through Phase 7A verification**

Run:

```powershell
& '.\scripts\verify.ps1'
```

Expected: all existing formal experiments retain their frozen results, report evidence is regenerated, Markdown/DOCX/PDF rebuild successfully, all report tests pass, and the PDF remains 8 to 12 pages.

- [ ] **Step 5: Perform five-axis review and final claim audit**

Review correctness, readability, architecture, security, and performance. Then inspect every numeric statement in the resolved report against `report_evidence.json`, confirm every citation against `references.json`, and search for prohibited scope claims. Resolve every required finding before integration.

- [ ] **Step 6: Commit documentation and verification integration**

```powershell
git add -- 'README.md' 'scripts/verify.ps1' 'docs/skills/specs/2026-08-20-phase-7a-technical-report-design.md' 'docs/skills/plans/2026-08-20-phase-7a-technical-report.md'
git commit -m "docs: publish verified Phase 7A report package"
```

Stage only files that actually changed.

- [ ] **Step 7: Fast-forward merge to local main and reverify**

Require the feature worktree to be clean. In the main checkout, require status to contain only the unrelated untracked root DOCX and require `main` to be an ancestor of the Phase 7A branch. Then:

```powershell
git merge --ff-only feature/phase-7a-technical-report
& '.\scripts\verify.ps1'
```

Expected: local fast-forward succeeds, the complete verification passes from merged `main`, and final report artifacts exist in the main checkout.

- [ ] **Step 8: Safely remove the owned worktree and branch**

Resolve the exact worktree path and require it to be a direct child of the resolved project `.worktrees` directory. From the main checkout:

```powershell
git worktree remove -- 'E:\YZH123123\PID vs Fuzzy PID\.worktrees\phase-7a-technical-report'
git worktree prune
git branch -d feature/phase-7a-technical-report
```

Expected: only the main worktree remains; the unrelated root DOCX remains untracked and unchanged; no remote state is modified.

## Plan Self-Review

- **Spec coverage:** Tasks 1 through 7 cover evidence provenance, all report formats, citation verification, failure disclosure, 8 to 12 page PDF, content/layout tests, README, full regression, and safe local integration.
- **Placeholder scan:** The plan contains no deferred implementation wording, undefined helper contract, or unresolved threshold.
- **Type consistency:** `exportEvidence`, manifest section names, Python loader/resolver interfaces, report paths, citation fields, CLI commands, and test names are stable across all tasks.
- **Scope:** The plan produces one independently testable technical-report subsystem. Presentation, one-page summary, optional controllers, new experiments, and hardware work remain outside Phase 7A.
