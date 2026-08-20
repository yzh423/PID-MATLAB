# Phase 7A Evidence Synthesis and Technical Report Design

## Objective

Complete the next required milestone in the revised implementation guide: turn the verified Phase 1 through Phase 6B software and experiment evidence into a reproducible, application-ready technical report package.

Phase 7A must:

1. audit every required core deliverable against an existing implementation, test, figure, table, or explicit limitation;
2. extract report numbers from generated MAT and CSV evidence instead of manually copying values;
3. produce an English technical report with the guide's required methods, experiments, results, discussion, limitations, and future-work sections;
4. export the same report as Markdown, DOCX, and PDF;
5. verify citations, quantitative claims, artifact provenance, pagination, and rendered layout; and
6. preserve the verified controller, robot, trajectory, experiment, and acceptance definitions without retuning or adding a new controller.

The target reader is an advisor, graduate-admissions reviewer, or robotics researcher who needs to understand the engineering question, reproduce the study, inspect both successful and unsuccessful cases, and distinguish simulation evidence from hardware claims.

## Prior-Phase Audit

The revised guide's required implementation scope is already represented by verified repository evidence:

| Required area | Existing evidence |
|---|---|
| Three robot configurations | `rrm.config.makeRobot` and the deterministic robustness configuration cases |
| Forward/inverse and differential kinematics | `rrm.kinematics.*`, trajectory tests, and Cartesian task figures |
| Nonlinear plant | `rrm.dynamics.*`, Robotics System Toolbox agreement, native Simulink plant, and Multibody plant |
| Joint and Cartesian tasks | nominal joint trajectory, straight line, and pick-transfer-place experiments |
| Manual PID and adaptive Fuzzy-PID | common MATLAB simulator and nominal/robustness comparisons |
| Optimization-assisted tuning | deterministic `fmincon` study and held-out 0.8 kg payload |
| Required uncertainties | payload, geometry, mass/inertia, disturbance, noise, saturation, and combined cases |
| Quantitative comparison | common metrics, 39 deterministic runs, 360 paired stochastic runs, and CSV tables |
| Independent validation | rigid-body, native Simulink, and torque-driven Simscape Multibody evidence |
| Organized repository and reproducibility | 145 tests, zero static-analysis issues, and one-command verification |

The missing required deliverable is the guide's Step 11 writing and packaging work. The guide explicitly prohibits optional advanced extensions until required experiments, plots, and written explanations are complete. Phase 7A therefore precedes neural tuning, MPC, 3-DOF expansion, or a second Simulink Fuzzy-PID engine.

## Approved Assumptions

The user has instructed the project to continue with recommended choices without repeated questions. Phase 7A therefore proceeds with these explicit assumptions:

1. The report language is English because the deliverable is intended for graduate applications, advisor review, and a public technical portfolio.
2. The report target is 8 to 12 rendered PDF pages including the title, main text, figures, tables, and references.
3. The citation style is numbered IEEE style, using primary research papers and official MathWorks documentation where technical background or tool behavior requires support.
4. The report reports existing evidence only. No controller gain, threshold, scenario, seed, robot parameter, or conclusion is changed to improve the narrative.
5. Generated report prose may round displayed values for readability, but every displayed number must trace to the structured evidence manifest and retain enough precision to support the stated comparison.
6. The canonical editable report is Markdown. DOCX and PDF are reproducible exports and are committed as final deliverables.
7. Existing experiment figures are reused when they answer the report question clearly. New figures may only consolidate already verified results; they may not alter or selectively hide outcomes.
8. Phase 7B will package the completed report into an 8 to 12 slide presentation and one-page research summary. Those artifacts are intentionally outside this design so that the report can be reviewed as an independent deliverable.
9. The user's unrelated root DOCX remains untracked and untouched.
10. No remote push, publication, or pull request is performed without explicit authorization.

## Alternatives Considered

### Approach A: Evidence manifest plus reproducible report build

MATLAB exports a compact JSON evidence manifest from the formal MAT/CSV artifacts. A Python builder validates the manifest, resolves report tokens, and creates Markdown and DOCX. PowerShell uses the installed Microsoft Word application to export PDF. Automated checks compare report claims with the manifest and inspect the final PDF.

This is the approved approach. It makes every number traceable, separates scientific evidence from document layout, and allows later presentation work to reuse the same source of truth.

### Approach B: Manually write DOCX from the README and figures

This is faster initially, but numeric drift, missing failure cases, inconsistent captions, and unrepeatable formatting would be difficult to detect. It is rejected because the project already has machine-readable evidence and emphasizes reproducibility.

### Approach C: Implement another advanced controller before writing

A second Simulink Fuzzy engine, neural tuner, or MPC controller could add technical breadth. It is rejected for this phase because the revised guide classifies these as optional and explicitly requires the report and explanations first.

## Architecture

```text
formal MAT/CSV + figure inventory
              |
              v
[MATLAB evidence exporter]
              |
              v
results/report/report_evidence.json
              |
              +-------------------+
              |                   |
              v                   v
[claim validator]       [Markdown report template]
              |                   |
              +---------+---------+
                        v
              technical_report.md
                        |
                        v
              [python-docx builder]
                        |
                        v
              technical_report.docx
                        |
                        v
              [Word PDF exporter]
                        |
                        v
              technical_report.pdf
                        |
                        v
              [content + visual QA]
```

### Evidence Export Boundary

`experiments/export_report_evidence.m` reads the existing formal artifacts under `results/data` and writes `results/report/report_evidence.json`. It does not rerun or mutate any controller experiment.

The manifest contains:

- environment and protocol metadata;
- manual PID and Fuzzy-PID nominal metrics;
- optimization objective, gains, and held-out payload metrics;
- deterministic scenario and controller summaries plus named failures;
- stochastic scenario summaries, confidence intervals, torque slew, saturation, and non-recovery counts;
- Cartesian task results including failed task acceptance states;
- rigid-body, Simulink, and Multibody agreement metrics;
- selected figure paths, dimensions, and nonempty-file checks; and
- source artifact paths and timestamps.

Stable error identifiers cover missing source artifacts, incompatible schemas, non-finite required values, duplicate controller/scenario rows, unexpected run counts, and unavailable figures.

### Report Build Boundary

`scripts/build_report.py` consumes the template, evidence manifest, bibliography metadata, and selected figures. It:

1. validates the evidence schema and frozen study counts;
2. resolves named evidence tokens in prose and tables;
3. rejects unused or unresolved tokens;
4. writes the canonical `docs/report/technical_report.md`;
5. builds `docs/report/technical_report.docx` with consistent page, heading, caption, table, and reference styles; and
6. writes a build manifest containing source hashes and output metadata.

The builder uses the bundled Python runtime with `python-docx`, Pillow, and the standard library. It does not install a new dependency.

`scripts/export_report_pdf.ps1` opens the generated DOCX through the installed Microsoft Word COM interface, exports `docs/report/technical_report.pdf`, closes the document, and always terminates the hidden Word application it created. It never edits an already open user document.

### Report Structure

The report follows the revised guide while remaining concise enough for 8 to 12 pages:

1. Title and abstract
2. Introduction and related research context
3. Problem formulation and fixed comparison rules
4. Manipulator model, kinematics, and dynamics
5. PID, bounded Mamdani Fuzzy-PID, and optimization-assisted tuning
6. Experimental design and acceptance metrics
7. Nominal, optimization, robustness, and Cartesian results
8. Independent Simulink and Multibody validation
9. Discussion of trade-offs and failure modes
10. Connection to an embodied-AI execution stack
11. Limitations, future work, and conclusion
12. Numbered references

At least one table or figure must explicitly show an unsuccessful case. The combined stress failures and the manual/Fuzzy-PID pick-transfer-place acceptance failures may not be omitted.

### Citation Boundary

Background claims use a small verified citation bank stored in `docs/report/references.json`. Each entry contains authors, title, venue or publisher, year, DOI or official URL, source type, and the report claims it supports.

Citation rules:

- prefer original research papers for control and robotics methods;
- use official MathWorks documentation for MATLAB, Simulink, and Simscape tool behavior;
- do not cite search-result pages, tertiary summaries, or unverifiable references;
- verify title, author, year, and DOI or URL before inclusion; and
- do not use a citation to support a stronger claim than its source establishes.

## Tech Stack

- MATLAB R2026a Update 4 for evidence export and source validation
- Bundled Python runtime with Python 3, `python-docx` 1.2.0, Pillow 12.3.0, and `pypdf` 6.10.0
- Microsoft Word Office 16 for deterministic DOCX-to-PDF export
- PowerShell for orchestration and Word lifecycle control
- Markdown, JSON, DOCX, and PDF report artifacts
- Existing verified PNG figures and CSV/MAT evidence
- Git feature branch and project-local ignored worktree

No Pandoc, LaTeX installation, LibreOffice, Fuzzy Logic Toolbox, Global Optimization Toolbox, or new Python package is required.

## Commands

Export report evidence:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('experiments/export_report_evidence.m');"
```

Build Markdown and DOCX:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' '.\scripts\build_report.py' --project-root '.'
```

Export PDF:

```powershell
& '.\scripts\export_report_pdf.ps1'
```

Run report tests:

```powershell
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest discover -s '.\tests\report' -p 'test_*.py'
```

Run the complete report verification gate:

```powershell
& '.\scripts\verify_report.ps1'
```

Run existing project verification:

```powershell
& '.\scripts\verify.ps1'
```

## Project Structure

```text
docs/report/
  technical_report_template.md   Canonical narrative template with named evidence tokens
  technical_report.md            Resolved canonical report
  technical_report.docx          Application-ready editable export
  technical_report.pdf           Final rendered report
  references.json                Verified citation bank
  build_manifest.json            Source hashes and output metadata
experiments/
  export_report_evidence.m       MAT/CSV to report evidence exporter
results/report/
  report_evidence.json           Generated structured evidence source
scripts/
  build_report.py                Token validation, Markdown resolution, and DOCX build
  export_report_pdf.ps1          Hidden Word PDF export with guaranteed cleanup
  verify_report.ps1              Evidence, tests, build, PDF, and content gate
tests/report/
  test_report_evidence.py        Manifest schema and frozen-count tests
  test_report_build.py           Token, citation, DOCX, PDF, and claim tests
docs/skills/specs/
  2026-08-20-phase-7a-technical-report-design.md
docs/skills/plans/
  2026-08-20-phase-7a-technical-report.md
```

Generated `results/report/report_evidence.json` is ignored. The report source, references, build manifest, DOCX, and PDF are committed because they are final required deliverables.

## Code and Writing Style

MATLAB evidence extraction follows existing package conventions: explicit paths, scalar structs, stable error identifiers, no base-workspace dependencies, and finite-value checks.

Python uses small typed functions, `pathlib.Path`, explicit exceptions, deterministic ordering, and no implicit current-directory assumptions:

```python
def load_evidence(path: Path) -> dict[str, object]:
    evidence = json.loads(path.read_text(encoding="utf-8"))
    validate_evidence(evidence)
    return evidence
```

Report prose must:

- distinguish observed results from interpretation;
- use SI units and define every metric before reporting it;
- report trade-offs and unsuccessful cases;
- avoid universal superiority claims;
- avoid implying real-time, hardware, contact, grasp, or safety validation; and
- use direct, technical English without marketing language.

## Testing Strategy

1. **Evidence schema tests:** require all report sections, stable controller/scenario names, 39 deterministic runs, 360 stochastic trials, six Cartesian runs, two Simulink runs, and two Multibody runs.
2. **Frozen-value tests:** compare key manifest values against the source CSV/MAT fields with explicit numeric tolerances.
3. **Artifact tests:** require every selected figure, both committed SLX models, and the Multibody video to exist and be nonempty before building.
4. **Token tests:** fail for unresolved, duplicate, unknown, or unused evidence tokens.
5. **Citation tests:** require unique numeric IDs, complete bibliographic fields, valid DOI or HTTPS official URLs, and at least one claim mapping per reference.
6. **Claim tests:** scan for prohibited hardware/safety claims and require explicit failure, limitation, and reproducibility language.
7. **DOCX tests:** inspect headings, figure captions, table captions, references, page setup, embedded media, and absence of unresolved tokens.
8. **PDF tests:** require 8 to 12 pages, nonempty extracted text on every content page, expected title and section headings, and no unresolved tokens.
9. **Visual QA:** render every PDF page to images and inspect text clipping, table overflow, figure legibility, caption placement, page breaks, and blank pages.
10. **Regression:** rerun the existing 145 MATLAB tests and all Phase 1 through Phase 6B formal experiments before final integration.

## Boundaries

### Always

- Treat formal MAT/CSV artifacts as the numeric source of truth.
- Preserve Phase 1 through Phase 6B robot, controller, scenario, seed, metric, and threshold definitions.
- Verify every citation field and every quantitative claim.
- Include both successful and unsuccessful cases.
- Use SI units, descriptive captions, readable legends, and consistent controller names.
- Keep Word automation hidden and close only the Word instance created by the export script.
- Run report tests before every implementation commit and complete verification before integration.
- Preserve the unrelated root DOCX.

### Requires New Direction

- Rerun an experiment with changed gains, scenarios, thresholds, seeds, or robot parameters.
- Add an advanced controller, morphology optimization, new task, or new physical model.
- Change the report language or target length.
- Install Pandoc, LaTeX, LibreOffice, or another document dependency.
- Publish, push, or send the report externally.

### Never

- Hand-edit a generated number to make a result look better.
- Hide the combined-stress failures or failed pick-transfer-place acceptance results.
- Claim real-robot, hardware-safety, contact, grasping, or real-time validation.
- cite an unverified or nonexistent source.
- edit a user's open Word document or terminate a pre-existing Word process.
- commit generated temporary render directories or the report evidence JSON.

## Risks and Mitigations

- **Numeric drift:** resolve all report values from named evidence tokens and test key values against source artifacts.
- **Selective reporting:** require failure-case sections and manifest checks for complete controller/scenario coverage.
- **Citation hallucination:** use a structured citation bank and independently verify bibliographic fields before drafting dependent claims.
- **Page-count pressure:** constrain figure selection and table density before reducing font size; maintain readable body text and captions.
- **DOCX/PDF mismatch:** make DOCX the single export input, verify the resulting PDF, and visually inspect every rendered page.
- **Word automation leakage:** create one hidden application instance, use `try/finally`, close the owned document, quit the owned instance, and release COM objects.
- **Large report scope:** keep Phase 7A limited to the report. Presentation and one-page summary start only after this report passes its own gate.
- **Overclaiming:** include explicit scope sentences beside Simulink, Multibody, stochastic, and embodied-AI discussions.

## Success Criteria

Phase 7A is complete only when:

1. the evidence manifest is reproducibly exported from the formal results without rerunning an experiment;
2. every quantitative report token resolves from the manifest and no unresolved token remains;
3. the English report contains the guide's required technical sections and numbered verified references;
4. the report includes nominal, optimization, deterministic, stochastic, Cartesian, Simulink, and Multibody results, including failure cases;
5. Markdown, DOCX, and PDF outputs are generated from one command and committed;
6. the PDF contains 8 to 12 readable pages and passes complete visual QA;
7. evidence, citation, token, claim, DOCX, and PDF automated tests pass;
8. the existing 145 MATLAB tests, static analysis, and Phase 1 through Phase 6B formal experiments remain unchanged and pass from merged `main`;
9. README documents the report build and links the final artifacts;
10. the local feature branch is merged and its owned worktree is safely removed; and
11. the user's unrelated DOCX remains untouched and untracked.

## Open Questions

None. The approved recommended defaults above resolve report language, format, length, citation style, evidence source, and scope. Any later request to change those decisions updates this design before implementation.
