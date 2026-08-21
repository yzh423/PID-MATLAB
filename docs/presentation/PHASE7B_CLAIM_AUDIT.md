# Phase 7B Claim Audit

**Verdict**: PASS
**Audited commit**: `38ccca8b74b5a6537479fa4f2e4fffb3876f2e34`
**Generated**: 2026-08-21T05:24:01Z
**Claim groups**: 11
**Atomic checks**: 132
**Status counts**: exact_match=6, rounding_ok=5, findings=0

All 11 current Phase 7B groups reconcile to the admitted raw MAT/CSV/PNG evidence and current package/template/PPTX/DOCX/PDF artifacts. Standard display rounding is used only where noted.

## Reproducibility Records

- `manifest_path`: docs/presentation/phase7b_build_manifest.json
- `package_path`: results/presentation/phase7b_package.json
- `raw_ledger_path`: docs/presentation/phase7b_raw_evidence.json
- `claim_group_count`: 11
- `atomic_claim_checks`: 132
- `template_package_pptx`: PASS: template tokens resolve into phase7b_package.json; PPTX visible text, notes [Sources], media hashes, relationships, and effective fonts match package/layout contract
- `package_docx_pdf`: PASS: DOCX paragraphs/table/image and PDF extracted text/page render match package summary; summary image hash equals admitted deterministic PNG
- `source_blocks`: PASS: all 10 PPTX notes [Sources] blocks and summary source line match package declarations and admitted source records
- `hash_records`: PASS: audited_input_hashes include current package/template/manifest/layout/toolchain/raw-ledger, final PPTX, summary DOCX/PDF, Phase7A indices, all admitted raw MAT/CSV, and six PNGs
- `boolean_status_records`: PASS: Success fields are exact 0/1 strings in CSVs, not booleans; Status categories are completed where claimed
- `toolchain_records`: PASS: manifest schemaVersion=2 with artifactTool BLOCKED/official_runtime_empty and verified Arial font hashes
- `tracked_package_provenance`: PASS: results/presentation/phase7b_package.json is tracked at audited HEAD and current sha256 37d2d202d469e1f38857e92948bdf4896aaf8a88b38c13aab6191d3b8be42ef7

## Test And Visual Records

- `bundled_python_presentation_suite`: PASS: 88 tests in 35.150s, OK, skipped=1 official Artifact Tool runtime unavailable
- `bundled_node_atomic_suite`: PASS: node --test atomic_publish.test.mjs, 8 passed, 0 failed
- `deep_pptx_validator`: PASS: PHASE7B_PPTX_DEEP_VALIDATED slides=10 notes=10 layout=PASS
- `official_artifact_tool_rebuild`: SKIPPED: prescribed runtime node_modules entryCount=0 and @oai/artifact-tool absent; no install/search/substitute performed
- `hash_verification`: PASS: current output/input/raw/figure/font hashes match Phase 7B manifest/toolchain/raw ledger
- `office_process_cleanup`: PASS: no pre-existing Office processes; owned POWERPNT/WINWORD instances exited; no lingering POWERPNT/WINWORD processes after render
- `pptx_render`: PASS: real PowerPoint read-only COM export produced 10 slide PNGs at 1600x900
- `docx_render`: PASS: real Word read-only COM export produced one-page PDF and one rendered PNG
- `pdf_render`: PASS: checked-in PDF rendered to one PNG
- `pixel_checks`: PASS: 12 rendered pages nonblank with expected dimensions and RGB extrema
- `manual_visual_inspection`: PASS: contact sheet plus individual slide 6/DOCX/PDF summary inspection found no clipping, collisions, wraps, missing glyphs, distortion, or readability issues
- `effective_font_gates`: PASS: cover title 51 pt; all slide titles >=35 pt including slide 6 effective 35.46 pt; slide 2/4/7 claim text 24 pt

## Claim Groups

### 1. presentation/final_presentation.pptx slide 1 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 7
- **Claim text**: Cover title/subtitle claim evidence-grounded PID and Fuzzy-PID evaluation for a 2-link manipulator, with multibody tracking figure and [Sources].
- **Evidence**: 2-link confirmed from nominal MAT robot L1/L2 and two-row reference; cover embedded image hash 3bd780e3dfddb099659271c277ec1c133040178d54b69d1c9a43a48cb50da4f9 equals admitted multibody PNG; notes sources match package.
- **Sources verified**: docs/report/technical_report.md, results/figures/multibody_cross_validation_tracking.png

### 2. presentation/final_presentation.pptx slide 2 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 9
- **Claim text**: Nominal success does not prove reliability; controller choice must survive payload, configuration, noise, disturbance, actuator authority; failed completed runs retained; simulation-only scope.
- **Evidence**: Stress categories from raw rows: ['actuator', 'combined', 'configuration', 'disturbance', 'nominal', 'payload', 'uncertainty'] plus stochastic noise scenarios; deterministic has completed=39 with failed Success=0 rows, Cartesian completed=6 with 2 failed rows; no hardware/fidelity claim appears in slide/summary.
- **Sources verified**: docs/report/technical_report.md, results/figures/nominal_pid_vs_fuzzy_tracking.png

### 3. presentation/final_presentation.pptx slide 3 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 12
- **Claim text**: Protocol metrics 0.001 s, 5.0 s, 5001 samples; manual PID, Mamdani Fuzzy-PID, optimized PID use identical robot parameters, torque limits, trajectories, thresholds, and random seeds.
- **Evidence**: nominal_pid_vs_fuzzy.mat gives sampleTime=0.001, time 0..5.0 and 5001 samples; raw rows show 3 controllers; torque limits [25,15], fixed thresholds, shared reference trajectory, and 30 fixed seeds per stochastic cell.
- **Sources verified**: docs/report/technical_report.md, results/report/report_evidence.json

### 4. presentation/final_presentation.pptx slide 4 visible content and notes

- **Status**: `rounding_ok`
- **Atomic checks**: 12
- **Claim text**: Optimization lowers nominal objective 7.283% and held-out payload objective from 0.214504 to 0.197284; exit flag 1 after 12 iterations and 96 evaluations; only PID gains change.
- **Evidence**: pid_optimization.mat gives 0.202426799460455 to 0.18768375634655526, reduction 7.283147860458988%; held-out 0.21450363216387297 to 0.19728400491642561; exitFlag=1, iterations=12, funcCount=96; training payload 0.5 kg and held-out payload 0.8 kg; torque limits remain [25,15].
- **Sources verified**: docs/report/technical_report.md, results/figures/pid_optimization_objective.png, results/data/pid_optimization.mat

### 5. presentation/final_presentation.pptx slide 5 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 17
- **Claim text**: Deterministic success rises from 8/13 manual PID to 9/13 Fuzzy-PID and 10/13 optimized PID; matrix has 39 runs across nominal, payload, configuration, uncertainty, disturbance, actuator, combined conditions; all 3 fail combined deterministic case.
- **Evidence**: deterministic_robustness_runs.csv row count=39, scenarioCount=13, successCounts={'mamdani-fuzzy-pid': 9, 'manual-pid': 8, 'optimization-pid': 10}, totals={'mamdani-fuzzy-pid': 13, 'manual-pid': 13, 'optimization-pid': 13}; categories=['actuator', 'combined', 'configuration', 'disturbance', 'nominal', 'payload', 'uncertainty']; combined rows=[{'Scenario': 'combined-deterministic', 'Controller': 'manual-pid', 'Status': 'completed', 'Success': '0'}, {'Scenario': 'combined-deterministic', 'Controller': 'mamdani-fuzzy-pid', 'Status': 'completed', 'Success': '0'}, {'Scenario': 'combined-deterministic', 'Controller': 'optimization-pid', 'Status': 'completed', 'Success': '0'}]; all statuses completed.
- **Sources verified**: docs/report/technical_report.md, results/figures/deterministic_robustness_summary.png, results/data/deterministic_robustness_summary.csv, results/data/deterministic_robustness_runs.csv

### 6. presentation/final_presentation.pptx slide 6 visible content and notes

- **Status**: `rounding_ok`
- **Atomic checks**: 15
- **Claim text**: Each isolated-noise cell passes 30/30; every combined-stress cell passes 0/30; study has 360 trials; high-noise optimized PID has lowest tracking error and highest mean torque slew 2888.34 N m/s.
- **Evidence**: stochastic summary/trial CSV and MATLAB v7.3 MAT load give trialCount=360, scenarios=4, controllers=3, nine isolated noise cells all 30/30, three combined cells all 0/30; high-noise MeanJointRms={'manual-pid': 0.0456057388059666, 'mamdani-fuzzy-pid': 0.0451110001403517, 'optimization-pid': 0.0228076739107534}; MeanTorqueSlew={'manual-pid': 1520.28248773485, 'mamdani-fuzzy-pid': 1631.15757003056, 'optimization-pid': 2888.34441441764}, optimized raw slew=2888.34441441764 rounds to 2888.34.
- **Sources verified**: docs/report/technical_report.md, results/figures/stochastic_robustness_chattering.png, results/data/stochastic_robustness_summary.csv, results/data/stochastic_robustness_trials.csv

### 7. presentation/final_presentation.pptx slide 7 visible content and notes

- **Status**: `rounding_ok`
- **Atomic checks**: 12
- **Claim text**: All 3 controllers pass straight-line; only optimized PID passes pick-transfer-place; 4 of 6 task runs pass; manual and Fuzzy-PID complete but fail quantitative pickup/place criteria; optimized PID records 0.01422 m RMS and 0.02970 m max Cartesian error.
- **Evidence**: cartesian_tasks_runs.csv has runCount=6, successCount=4, failureCount=2, statusCounts={'completed': 6}; straight-line rows all Success=1; pick-transfer-place pattern manual=0, fuzzy=0, optimized=1; optimized raw RMS=0.0142210111046117 and max=0.029698222399069 round as displayed.
- **Sources verified**: docs/report/technical_report.md, results/figures/cartesian_tasks_paths.png, results/data/cartesian_tasks_runs.csv

### 8. presentation/final_presentation.pptx slide 8 visible content and notes

- **Status**: `rounding_ok`
- **Atomic checks**: 10
- **Claim text**: Simulink agreement and tracking pass 2/2; Multibody agreement and tracking pass 2/2; worst end-effector difference 3.34e-16 m; model consistency is not hardware fidelity.
- **Evidence**: simulink rows=2, agreement+tracking pass=2; multibody rows=2, agreement+tracking pass=2; raw worst EndEffectorMax=3.34221388864417e-16 rounds to 3.34e-16; MATs expose shared robot/reference/options.
- **Sources verified**: docs/report/technical_report.md, results/data/simulink_cross_validation.mat, results/data/multibody_cross_validation.mat

### 9. presentation/final_presentation.pptx slide 9 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 9
- **Claim text**: Optimized PID is the strongest reliability baseline; metrics 8/13, 9/13, 10/13; nominal manual/Fuzzy metrics are mixed; optimized gives best aggregate deterministic and Cartesian reliability with torque-slew trade-off under noise.
- **Evidence**: Deterministic successCounts={'mamdani-fuzzy-pid': 9, 'manual-pid': 8, 'optimization-pid': 10}; optimized count 10 exceeds 9 and 8; Cartesian pick-transfer-place only optimized succeeds; nominal MAT has mixed manual-vs-fuzzy metrics; high-noise optimized has lowest tracking error and highest torque slew.
- **Sources verified**: docs/report/technical_report.md, results/report/report_evidence.json

### 10. presentation/final_presentation.pptx slide 10 visible content and notes

- **Status**: `exact_match`
- **Atomic checks**: 8
- **Claim text**: Next milestone is sensing, hardware uncertainty, online safety constraints; next steps are hardware-in-loop/physical arm validation, perception/task-planning integration, online monitoring/collision avoidance/safety supervision.
- **Evidence**: Slide language is explicitly future work and is consistent with summary limitations: simulation only, no hardware fidelity, collision avoidance, perception, online safety supervisor, or end-to-end embodied-AI implementation claimed.
- **Sources verified**: docs/report/technical_report.md, docs/report/references.json

### 11. docs/summary/research_summary.docx and docs/summary/research_summary.pdf one-page summary

- **Status**: `rounding_ok`
- **Atomic checks**: 21
- **Claim text**: One-page summary title/takeaway/problem/method/results/figure/significance/limitations/next steps/sources, including 2-link, 0.001 s, 7.283%, 10/13, 30/30 vs 0/30, deterministic figure caption, simulation-only limitations.
- **Evidence**: DOCX text extraction and pypdf PDF extraction match package summary; Word read-only render pageCount=1 and checked-in PDF pages=1; summary image hash 92a0c6889e6171d1b4f5811d20cc28a272aca7990a45a6483fa6bf74718d2759 equals admitted deterministic PNG; raw values confirm 2-link/0.001s, reduction 7.283147860458988%, optimized deterministic 10/13, isolated noise 30/30, combined stress 0/30; source line contains technical_report.md, report_evidence.json, build_manifest.json.
- **Sources verified**: docs/report/technical_report.md, results/report/report_evidence.json, docs/report/build_manifest.json

## Findings

None.
