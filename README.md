# Reliable Robotic Manipulation: PID vs Fuzzy-PID

This repository is a reproducible MATLAB experiment pipeline for a planar two-link manipulator. Choose a robot, one of three frozen controllers, and a joint- or Cartesian-space reference; execute it through the shared torque-limited nonlinear plant; then turn the logged histories into acceptance metrics and evidence artifacts. The experiment scripts are the normal entry points, while the `rrm.*` package exposes the same workflow as composable building blocks for custom studies.

Implemented evidence progresses from nominal PID tracking through a fair bounded Mamdani Fuzzy-PID comparison, optimization-assisted PID tuning, deterministic and paired seeded stochastic robustness studies, Cartesian tasks, and independent Robotics System Toolbox, Simulink, and torque-driven Simscape Multibody cross-validation. The MATLAB fixed-step RK4 path remains the shared reference implementation. Phase 7A admits the full formal results through `rrm.report.exportEvidence`; controlled Python validators resolve evidence and citations; deterministic Markdown, DOCX, and PDF artifacts are produced; and the verification pipeline checks the completed package. The project studies reliable low-level execution for a **given** robot and trajectory; morphology varies only as a controlled robustness condition, not as an optimization target. This remains simulation evidence, not hardware validation.

## Requirements

- Windows PowerShell
- MATLAB R2026a at `E:\MATLAB2026\bin\matlab.exe`
- Simulink, Simscape, and Simscape Multibody
- Microsoft Word Office 16 for hidden COM-based PDF export
- Bundled Codex Python at `C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe` for report assembly and PDF checks
- No third-party MATLAB packages

Installed toolboxes used by the verified stages include Control System Toolbox, Optimization Toolbox, Robotics System Toolbox, Simulink, Simscape, and Simscape Multibody. Fuzzy Logic Toolbox and Global Optimization Toolbox are not required and are not installed in the current environment.

## Quick Start

From the repository root, run the complete test and experiment pipeline. Use this full entry point rather than an individual experiment when reproducing the complete study, because it regenerates every formal result before the report package is checked.

```powershell
& '.\scripts\verify.ps1'
```

To run one experiment, set its script name and use the same repository-root invocation:

```powershell
$experiment = 'run_multibody_cross_validation.m'
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run(fullfile(pwd,'experiments','$experiment'));"
```

The verified evidence sequence and entry points are:

| Phase | Evidence | Experiment script |
|---|---|---|
| 1 | Nominal manual PID acceptance | `run_nominal_pid.m` |
| 2 | Fair PID/Fuzzy-PID comparison | `run_nominal_pid_vs_fuzzy.m` |
| 3 | Bounded PID tuning and held-out payload validation | `run_pid_optimization.m` |
| 4A | Deterministic 13-scenario robustness matrix | `run_deterministic_robustness.m` |
| 4B | Paired seeded stochastic robustness study | `run_stochastic_robustness.m` |
| 5 | Cartesian line and pick-transfer-place tasks | `run_cartesian_tasks.m` |
| 6A | Rigid-body and native Simulink cross-validation | `run_simulink_cross_validation.m` |
| 6B | Torque-driven Simscape Multibody cross-validation and animation | `run_multibody_cross_validation.m` |
| 7A | Evidence-grounded Markdown, DOCX, and PDF technical report | `export_report_evidence.m`, `scripts/build_report.py`, `scripts/export_report_pdf.ps1` |

## Output Contract

- `results/data/` contains MAT evidence and, where applicable, per-run and summary CSV tables.
- `results/figures/` contains the tracking, error, effort, robustness, task, validation, and model views emitted by each experiment.
- `results/videos/` contains full-mode animation evidence.
- `results/report/report_evidence.json` is a regenerated, ignored evidence manifest used only as the report build input.
- `docs/report/technical_report.md`, `docs/report/technical_report.docx`, and `docs/report/technical_report.pdf` are the committed Phase 7A report deliverables.
- `docs/report/build_manifest.json` records source, figure, DOCX, PDF, and report hashes for provenance.

Earlier-stage artifact names use the stable study stem established by their experiment script. Phase 6B writes these exact files:

```text
results/data/multibody_cross_validation.mat
results/data/multibody_cross_validation_runs.csv
results/figures/multibody_cross_validation_tracking.png
results/figures/multibody_cross_validation_path.png
results/figures/multibody_cross_validation_torque.png
results/figures/multibody_cross_validation_summary.png
results/figures/multibody_cross_validation_model.png
results/videos/multibody_cross_validation_manual_pid.mp4
```

Generated MAT, CSV, PNG, MP4, report-evidence JSON, and render-page outputs are excluded from Git. The report Markdown, DOCX, PDF, references, audit report, and build manifest are committed because they are the reviewed Phase 7A package.

## Technical Report Package

When formal experiment results are already current and need a reviewable deliverable, use Phase 7A to package the Phase 1 through Phase 6B simulation evidence into an English technical report:

- [Markdown report](docs/report/technical_report.md)
- [Editable DOCX report](docs/report/technical_report.docx)
- [Final PDF report](docs/report/technical_report.pdf)
- [Build manifest](docs/report/build_manifest.json)
- [Claim audit](docs/report/PAPER_CLAIM_AUDIT.md)

The canonical workflow is `experiments/export_report_evidence.m`, then `scripts/build_report.py`, then `scripts/export_report_pdf.ps1`; choose `scripts/verify_report.ps1` only when the formal experiments are already current, and choose `scripts/verify.ps1` for a clean end-to-end reproduction. This separation avoids producing a polished report from stale evidence while keeping PDF creation in its required Windows Word COM boundary.

**Admit evidence and claims.** Start with `rrm.report.exportEvidence`, which validates the formal MAT/CSV artifacts, checks frozen run counts and selected figures, then writes `results/report/report_evidence.json`. Use `scripts.reporting.evidence.load_evidence` and `scripts.reporting.evidence.validate_evidence` only when a custom report-side tool must independently inspect that manifest; use `scripts.reporting.evidence.lookup` and `scripts.reporting.evidence.resolve_tokens` when resolving constrained template values rather than manually traversing evidence. When bibliography or report prose changes, use `scripts.reporting.content.load_references` to load the reference set and `scripts.reporting.content.validate_report` to gate citations and scope before artifacts are assembled.

> `rrm.report.exportEvidence` is a strict admission gate, not a best-effort summary: all 14 named MAT/CSV sources, six selected PNGs, full modes, exact study counts of 39/360/6/2/2, unique keys, finite headline values, and passing independent-model rows are mandatory.

> Each report CSV must mirror its MAT table within tolerance, and controller summaries must retain the frozen order `manual-pid`, `mamdani-fuzzy-pid`, `optimization-pid`; equivalent rows in a different order are rejected.

> Direct callers of `rrm.report.exportEvidence` must provide an existing parent directory and a `.json` destination; the exporter writes through a same-directory temporary file and atomically replaces the destination.

> The evidence boundary is exposed by `scripts.reporting.evidence.EvidenceError`, `scripts.reporting.evidence.load_evidence`, `scripts.reporting.evidence.validate_evidence`, `scripts.reporting.evidence.lookup`, and `scripts.reporting.evidence.resolve_tokens`. Tokens may select mapping fields or zero-based list indices only; containers, `null`, non-finite values, unknown paths, and formats outside `d` or `.[digits][feg]` are rejected.

> Citation and scope admission is owned by `scripts.reporting.content.ContentError`, `scripts.reporting.content.Reference`, `scripts.reporting.content.load_references`, and `scripts.reporting.content.validate_report`. The gate requires explicit combined-stress and pick-transfer-place failure disclosures plus the phrase "not hardware validation," and rejects hardware-validation, safety-guarantee, validated-real-time, or universal Fuzzy-PID superiority claims.

**Build and verify artifacts.** Run the `scripts/build_report.py` command for ordinary report assembly. `scripts.build_report.main` coordinates its helpers, while `scripts.reporting.document.DocumentBuildError`, `scripts.reporting.document.DocumentMetadata`, and `scripts.reporting.document.build_docx` are the lower-level controlled DOCX surface for direct assembly, extension work, or builder tests; they are not a replacement for the normal pipeline. This boundary keeps the document contract, figure/table checks, and final Word PDF export coupled to the admitted report content.

> `scripts.reporting.document.DocumentBuildError`, `scripts.reporting.document.DocumentMetadata`, and `scripts.reporting.document.build_docx` define the controlled Markdown-to-DOCX boundary: only `text` fences are supported, HTML is rejected, images must be project-contained PNGs, and the document must contain exactly six figures and nine mapped tables.

Run the report-only gate when the experiments are already current:

```powershell
& '.\scripts\verify_report.ps1'
```

> `scripts/verify_report.ps1` assumes the formal experiment artifacts are already current; use `scripts/verify.ps1` for a clean end-to-end reproduction because it regenerates every experiment before entering the report gate.

For targeted report work:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(genpath(pwd)); run('experiments/export_report_evidence.m');"
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' '.\scripts\build_report.py' --project-root '.' --markdown-only
& 'C:\Users\14228\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' '.\scripts\build_report.py' --project-root '.'
& '.\scripts\export_report_pdf.ps1'
```

> `scripts.build_report.main` orchestrates `scripts.build_report.insert_references`, `scripts.build_report.format_reference`, `scripts.build_report.atomic_write`, and `scripts.build_report.build_docx_outputs`, but stops after Markdown, DOCX, and manifest output. PDF creation remains the separate Windows Word COM step in `scripts/export_report_pdf.ps1`, followed by `scripts.normalize_report_pdf.normalize_pdf` through `scripts.normalize_report_pdf.main`.

The current verified PDF is 8 pages with 6 figures, 9 tables, and 8 references. The report evidence path records 39 deterministic runs, 360 paired stochastic trials, 6 Cartesian task runs, 2 Simulink comparisons, 2 Multibody comparisons, 145 pre-report MATLAB tests, and 5 report-specific MATLAB tests at export time. This package communicates simulation evidence; it is not new hardware validation.

## Phase 7B Presentation and Research Summary

Use the full technical report when a reader needs methods, acceptance criteria, and the complete evidence record. Use the editable 10-slide deck for an advisor or faculty discussion, and the one-page summary for a concise distribution copy. The final deliverables are [the deck](presentation/final_presentation.pptx), [the editable summary](docs/summary/research_summary.docx), and [the distribution PDF](docs/summary/research_summary.pdf).

From the repository root, verify the already-current Phase 7A evidence and all Phase 7B deliverables with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify_phase7b.ps1
```

Every visible Phase 7B value resolves from the same admitted Phase 7A evidence package. Each deck slide also carries a `[Sources]` block in its speaker notes, so its claims remain traceable during presentation use. These deliverables communicate simulation-only evidence and do not extend the study to hardware validation.

## Compose a Custom Study

When a study needs a different robot, command, controller, or evidence slice than the verified default, use the package APIs while preserving the same lifecycle. The eight scripts listed in Quick Start remain the default reproducible entry points, and `scripts/verify.ps1` runs them as one verification gate so that custom composition does not silently replace the study's common protocol:

1. **Freeze the protocol.** Create the plant and numerical rules with `rrm.config.makeRobot` and `makeSimulationOptions`, then select `makePidController`, `makeFuzzyPidController`, or `makeOptimizedPidController`. `makePidOptimization` separately defines the bounded tuning problem.
2. **Build the motion command.** Use `rrm.trajectory.quintic` for joint motion, or compose Cartesian motion with `cartesianQuintic`, `cartesianWaypoints`, `cartesianToJoint`, and `makePickAndPlaceTask`. The supporting `rrm.kinematics.forward`, `inverse`, `jacobian`, and `jacobianDot` functions expose reachability and differential mappings.
3. **Execute the closed loop.** Call `rrm.simulation.runController` when code selects the controller type at runtime. Use `runPid` or `runFuzzyPid` when the study is intentionally controller-specific and should reject the wrong definition early. These runners coordinate the `rrm.control.pidStep` or `fuzzyPidStep` logic with the shared `rrm.dynamics.matrices` and `acceleration` plant; fuzzy inference remains isolated in `rrm.fuzzy.membershipFive` and `mamdani`.

> `rrm.simulation.runPid` and `rrm.simulation.runFuzzyPid` both delegate to `rrm.simulation.runController`, so the MATLAB controller comparison shares one integration and plant path; independence comes from the narrower fixed-gain PID, zero-disturbance, zero-noise validation layers.
4. **Evaluate the result.** Use `rrm.metrics.evaluate` for common joint tracking, effort, saturation, and success metrics. Use `evaluateCartesianTask` when end-effector and waypoint accuracy must be added to that same common result.
5. **Tune without changing the test.** `rrm.optimization.applyPidMultipliers` maps bounded variables to gains, `scorePidResult` grades each candidate, and `tunePid` owns the deterministic optimizer and its history. Freeze the resulting controller before held-out evaluation.

> `rrm.config.makeOptimizedPidController` reproduces the already-verified Phase 3 gains without rerunning optimization; `rrm.optimization.tunePid` is the separate `fmincon` path and requires Optimization Toolbox.
6. **Stress-test frozen controllers.** In `rrm.robustness`, the deterministic lifecycle uses `makeDeterministicScenarios`, `runDeterministicMatrix`, `evaluateRun`, and `summarizeMatrix` for prescribed physical variations and pulses. The stochastic lifecycle uses `makeStochasticScenarios`, `makeMeasurementNoise`, `runStochasticStudy`, `evaluateStochasticRun`, and `summarizeStochasticStudy` when reproducible reliability intervals under paired sensor noise are required.
7. **Cross-check independent models.** Use `rrm.validation.makeRigidBodyTree` and `compareRigidBodyDynamics` to check analytical dynamics. In `rrm.simulink`, `buildPidCrossValidationModel`, `runPidCrossValidation`, and `comparePidRuns` check an independently encoded block-diagram execution. In `rrm.multibody`, `buildCrossValidationModel` creates the physical mechanism, `runCrossValidation` injects and executes the fixed protocol, `compareRuns` grades agreement, and `writeVideo` renders an already completed Multibody history. Build only when the committed model must be regenerated; run and compare for numerical evidence; render only when a full-mode visual artifact is needed.
8. **Package the report.** Use `rrm.report.exportEvidence` through `experiments/export_report_evidence.m` when the formal artifacts need to be re-exported for the report builder. The report workflow is a packaging and provenance layer over existing evidence, not a new experiment stage.

The two committed generated models are `models/rrm_pid_cross_validation.slx` and `models/rrm_multibody_cross_validation.slx`. Requirements, designs, tests, and generated evidence live under `docs/`, `tests/`, and the `results/data`, `results/figures`, and `results/videos` directories respectively.

## Shared Analytical Plant and Fixed Protocol

Use the shared plant and fixed protocol when a controller comparison must isolate control behavior instead of silently changing physics, timing, limits, or acceptance rules. Every analytical experiment therefore starts from the same manipulator equation:

```text
M(q) ddq + C(q,dq) dq + G(q) + Fv dq = tau + disturbance.
```

The model includes the two link masses and inertias, link centres of mass, endpoint payload, gravity, viscous friction, joint limits, and actuator torque limits. Angles are in radians and torque is in newton-metres throughout the package.

The default reference moves from `[0; 0]` degrees to `[45; 60]` degrees in 3 seconds and holds the target until 5 seconds. Simulation and control use a deterministic 1 ms fixed step. Neither controller uses gravity feedforward in the nominal comparison.

> The true joint position always starts at the first reference sample; prescribed measurement noise changes controller feedback from that point onward, not the plant's initial state.

> Disturbance torque may be one `2 x 1` vector replicated across the run or an explicit `2 x N` history; other shapes are rejected.

## Bounded Mamdani Gain Adaptation

Each joint uses normalized position error and error rate as Mamdani inputs. Both inputs use five triangular/shoulder labels on `[-1,1]`: negative big, negative small, zero, positive small, and positive big. The implementation evaluates three symmetric `5 x 5` rule tables with min implication, max aggregation, and a 101-point discrete centroid. It does not call Fuzzy Logic Toolbox.

The normalized outputs adjust the Phase 1 gains within fixed relative ranges:

```text
Kp: +/-35%    Ki: +/-50%    Kd: +/-30%
```

Large tracking error increases proportional action and suppresses integration. Near-zero stationary error increases integration, while large error rate increases damping. Explicit lower and upper gain bounds are enforced after inference, and the shared PID calculation still owns derivative filtering, torque saturation, and anti-windup.

> Fuzzy inputs are clamped to `[-1,1]`, gain corrections remain inside configured bounds, and the ordinary PID step still owns final saturation and anti-windup.

> The active actuator limit is the elementwise minimum of controller and robot limits.

## Baseline PID/Fuzzy-PID Evidence

The checked Phase 2 reference run produced:

| Controller | Joint | Steady RMS error (rad) | Steady max error (rad) | Torque RMS (N m) | Saturation (s) |
|---|---:|---:|---:|---:|---:|
| PID | 1 | 0.0012684 | 0.0014577 | 12.503 | 0 |
| PID | 2 | 0.013762 | 0.014935 | 2.6202 | 0 |
| Fuzzy-PID | 1 | 0.0097924 | 0.010887 | 12.432 | 0 |
| Fuzzy-PID | 2 | 0.013174 | 0.014896 | 2.6316 | 0 |

Both controllers met the common acceptance thresholds. In this one nominal case, Fuzzy-PID slightly improved joint 2 steady RMS error and joint 1 torque RMS, but worsened joint 1 steady tracking error. These data show bounded, successful online adaptation under the baseline condition; they do not establish general superiority or robustness.

## Optimization-Assisted PID Tuning

Use Phase 3 tuning when the question is whether fixed PID gains can improve under the existing plant, simulator, and evaluation rules. The optimizer changes only six dimensionless multipliers in the order `[Kp1,Kp2,Ki1,Ki2,Kd1,Kd2]`; robot dimensions and payload are not decision variables. The manual gains correspond to an all-ones initial point, with multiplier bounds from `[0.5,0.5,0.25,0.25,0.5,0.5]` to `[2,2,2,2,2,2]`.

The dimensionless objective is:

```text
J = 0.50 E_rms + 0.10 O + 0.15 U_rms + 0.25 T_settle
    + 100 S + P_failure
```

`E_rms` is travel-normalized tracking RMS, `O` is directional normalized overshoot, `U_rms` is torque-limit-normalized RMS effort, `T_settle` uses a 2 degree final-target band, and `S` is actuator saturation fraction. Non-completed and missing-sample results receive explicit finite penalties.

Optimization uses `fmincon` SQP with forward finite differences, no parallel evaluation, 20 maximum iterations, 150 maximum function evaluations, `1e-4` step tolerance, and `1e-3` optimality tolerance. The training condition is the nominal 0.5 kg payload only. The checked run converged with exit flag 1 after 12 iterations and 96 evaluations:

```text
Manual gains:    Kp=[120,100], Ki=[40,30],       Kd=[25,18]
Optimized gains: Kp=[240,200], Ki=[79.9554,30.2026], Kd=[29.3133,18.3972]
Objective:       0.2024268 -> 0.18768376  (-7.283%)
```

The final gains were then frozen and evaluated on a 0.8 kg payload not used during tuning:

| Scenario | Controller | Joint | Whole RMS error (rad) | Steady RMS error (rad) | Torque RMS (N m) |
|---|---|---:|---:|---:|---:|
| Nominal 0.5 kg | Manual | 1 | 0.066966 | 0.0012684 | 12.503 |
| Nominal 0.5 kg | Manual | 2 | 0.024231 | 0.013762 | 2.6202 |
| Nominal 0.5 kg | Optimized | 1 | 0.033284 | 0.00003322 | 12.415 |
| Nominal 0.5 kg | Optimized | 2 | 0.012274 | 0.0071288 | 2.5605 |
| Held-out 0.8 kg | Manual | 1 | 0.076221 | 0.0030897 | 14.000 |
| Held-out 0.8 kg | Manual | 2 | 0.030378 | 0.017196 | 3.2795 |
| Held-out 0.8 kg | Optimized | 1 | 0.037824 | 0.00070723 | 13.901 |
| Held-out 0.8 kg | Optimized | 2 | 0.015317 | 0.0088871 | 3.1929 |

Both controllers completed both scenarios without torque saturation. The held-out result is evidence of transfer to one heavier payload, not proof of broad robustness.

## Stress-Testing Frozen Controllers

Use deterministic cases to diagnose named physical stresses and seeded stochastic trials to quantify repeatability under sensor noise. Both Phase 4 studies freeze the controller definitions before varying the operating conditions, so their results extend the common nominal comparison without turning each stress case into a new tuning problem.

### Phase 4A: Deterministic Robustness Matrix

Phase 4A freezes the manual PID, Phase 2 Mamdani Fuzzy-PID, and Phase 3 optimized PID before testing. No controller is retuned for a stress case. Every controller receives the same 5 s reference and 1 ms step within each scenario.

The 13 prescribed scenarios are: nominal; payloads 0.0, 1.0, and 1.5 kg; compact and extended link configurations; mass/inertia scales 0.8, 0.9, 1.1, and 1.2; a `[4;-3] N m` pulse from 2.00 through 2.10 s; actuator limits reduced to `[18;10] N m`; and an extended-link combined case with 1.0 kg payload, 1.2 mass/inertia scale, reduced limits, and the pulse. Link changes recompute centres of mass and uniform-link inertias. These are prescribed evaluation cases, not morphology optimization variables.

Robustness success requires a completed simulation, the existing steady-state joint thresholds, and maximum end-effector tracking error at most 0.15 m. Recovery is the first 0.10 s continuous interval after the pulse during which both joint errors remain within 2 degrees. Saturation is reported rather than automatically treated as failure.

> Recovery time is `NaN` when no disturbance window exists, finite after the required continuous dwell, and `Inf` when recovery never occurs.

The verified full matrix produced:

| Frozen controller | Successful runs | Success rate | Mean joint RMS (rad) | Worst joint RMS (rad) | Worst EE error (m) | Total saturation (s) |
|---|---:|---:|---:|---:|---:|---:|
| Manual PID | 8/13 | 61.54% | 0.13109 | 0.83476 | 1.8046 | 10.797 |
| Mamdani Fuzzy-PID | 9/13 | 69.23% | 0.13042 | 0.83604 | 1.8038 | 10.528 |
| Optimized PID | 10/13 | 76.92% | 0.11074 | 0.83037 | 1.8070 | 11.279 |

All three controllers passed nominal and disturbance-pulse cases with no saturation. Their pulse recovery time was 0 s because both errors were already inside the 2 degree recovery band when the pulse ended. The manual PID additionally failed the 1.0 kg payload and extended configuration thresholds. All controllers failed the 1.5 kg payload, actuator-derated, and combined cases; the combined case caused approximately 6 s of joint-summed saturation per controller and no qualifying recovery before the run ended.

The optimized PID achieved the highest success count and lowest matrix-average joint RMS, while accumulating the most total saturation and a slightly larger worst end-effector error. Fuzzy-PID gained one successful case over manual PID and slightly reduced total saturation. These trade-offs and the shared failures do not establish universal superiority.

### Phase 4B: Stochastic Measurement-Noise Robustness

Use Phase 4B after named deterministic cases when a single pass/fail outcome cannot show trial-to-trial reliability or actuator sensitivity to sensing noise. The plant state and all performance metrics remain physically truthful: independent zero-mean Gaussian noise is added only to the joint position and velocity feedback seen by the controller. Within a scenario and seed, all three frozen controllers receive exactly the same noise realization. A local MT19937 stream makes the study reproducible without reading or changing MATLAB's global random state.

The three pure-noise levels use jointwise position/velocity standard deviations of `0.05 deg / 0.5 deg/s`, `0.20 deg / 2.0 deg/s`, and `0.50 deg / 5.0 deg/s`. The final combined case applies medium noise together with the Phase 4A extended geometry, 1.0 kg payload, 20% mass/inertia increase, `[18;10] N m` limits, and `[4;-3] N m` pulse. Seeds 42001 through 42030 give 30 paired trials per scenario, controller, and noise condition: 360 stochastic runs in total, plus three separate no-noise nominal references.

The verified full study produced:

| Scenario | Controller | Successes | Wilson 95% interval | Mean joint RMS (rad) | Mean torque slew (N m/s) | Non-recoveries |
|---|---|---:|---:|---:|---:|---:|
| Low noise | Manual PID | 30/30 | [0.8865, 1.0000] | 0.045598 | 153.57 | 0 |
| Low noise | Mamdani Fuzzy-PID | 30/30 | [0.8865, 1.0000] | 0.045261 | 173.20 | 0 |
| Low noise | Optimized PID | 30/30 | [0.8865, 1.0000] | 0.022779 | 290.07 | 0 |
| Medium noise | Manual PID | 30/30 | [0.8865, 1.0000] | 0.045598 | 608.44 | 0 |
| Medium noise | Mamdani Fuzzy-PID | 30/30 | [0.8865, 1.0000] | 0.045195 | 675.52 | 0 |
| Medium noise | Optimized PID | 30/30 | [0.8865, 1.0000] | 0.022783 | 1156.40 | 0 |
| High noise | Manual PID | 30/30 | [0.8865, 1.0000] | 0.045606 | 1520.30 | 0 |
| High noise | Mamdani Fuzzy-PID | 30/30 | [0.8865, 1.0000] | 0.045111 | 1631.20 | 0 |
| High noise | Optimized PID | 30/30 | [0.8865, 1.0000] | 0.022808 | 2888.30 | 0 |
| Combined stochastic | Manual PID | 0/30 | [0.0000, 0.1135] | 0.83500 | 284.15 | 30 |
| Combined stochastic | Mamdani Fuzzy-PID | 0/30 | [0.0000, 0.1135] | 0.83630 | 305.72 | 30 |
| Combined stochastic | Optimized PID | 0/30 | [0.0000, 0.1135] | 0.83079 | 521.09 | 30 |

All controllers preserve the Phase 4A success criteria under isolated white measurement noise, and true-state tracking RMS remains nearly flat as noise increases. That success rate alone conceals a major actuator-side cost: torque slew rises steeply with noise, especially for the optimized PID. In the combined case all controllers fail, saturate for about 6 joint-summed seconds in the worst trial, and never meet the recovery criterion. The optimized PID retains the lowest tracking RMS but is also the most noise-sensitive by torque slew; no controller is universally superior.

## Cartesian Path and Pick-and-Place Tasks

When a hypothetical high-level planner supplies Cartesian goals instead of a fixed joint reference, use Phase 5 to retain the same low-level controllers while converting those commands into joint motion. Each straight segment uses analytic rest-to-rest quintic position, velocity, and acceleration. Both analytical IK branches are considered at every sample; the joint-limit-valid solution nearest the previous state is selected. Joint velocities and accelerations are then calculated from `dq = J\v` and `ddq = J\(a-Jdot*dq)`. Unreachable, joint-limit-invalid, and singular paths fail explicitly instead of being clipped, so that planning failures are not hidden as modified trajectories.

> Analytical IK returns two `NaN` solutions with `reachable=false` for an unreachable target; Cartesian conversion also considers each branch shifted by plus or minus one revolution before selecting the nearest valid continuation and rejecting singular paths.

The straight-line task moves from `[0.55;0.12] m` to `[0.22;0.48] m` in 3 s and holds for 1 s. The pick-transfer-place task follows start `[0.55;0.12]`, pickup `[0.45;-0.02]`, safe `[0.45;0.32]`, and place `[0.22;0.48] m`, with movement durations `[1.4;1.2;1.5] s` and post-arrival dwells `[0.4;0;0.8] s`. The gripper and object are semantic only; no grasp force or object dynamics are simulated.

Task success requires completion, the existing joint steady-state criteria, Cartesian RMS at most 0.05 m, Cartesian maximum at most 0.15 m, requested waypoint errors at most 0.05 m, and zero saturation. The verified 1 ms study produced:

| Task | Controller | Success | Cartesian RMS (m) | Cartesian max (m) | Pickup error (m) | Place error (m) | Mean joint RMS (rad) | Saturation (s) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Straight line | Manual PID | yes | 0.032545 | 0.060228 | not applicable | not applicable | 0.038524 | 0 |
| Straight line | Mamdani Fuzzy-PID | yes | 0.031459 | 0.059513 | not applicable | not applicable | 0.037754 | 0 |
| Straight line | Optimized PID | yes | 0.016456 | 0.031895 | not applicable | not applicable | 0.019430 | 0 |
| Pick-transfer-place | Manual PID | no | 0.027739 | 0.054032 | 0.024388 | 0.007008 | 0.034577 | 0 |
| Pick-transfer-place | Mamdani Fuzzy-PID | no | 0.026850 | 0.053590 | 0.022960 | 0.011902 | 0.033902 | 0 |
| Pick-transfer-place | Optimized PID | yes | 0.014221 | 0.029698 | 0.011926 | 0.003641 | 0.017432 | 0 |

All six simulations completed without saturation, and every controller stayed inside the Cartesian and waypoint thresholds. The manual and Fuzzy-PID pick-transfer-place runs are nevertheless unsuccessful because joint 2 final-window RMS errors were `0.02378 rad` and `0.02410 rad`, above the existing `0.02 rad` joint threshold. The optimized PID passed both tasks and roughly halved Cartesian RMS relative to manual PID. Fuzzy-PID slightly improved path-level accuracy over manual PID but had a larger placement error; the six nominal runs do not establish universal superiority.

## Cross-Checking Independent Models

Use the Phase 6A checks when the doubt is whether the analytical dynamics and native block-diagram execution agree with independent implementations. Use Phase 6B when the stronger question is whether those same torques drive an independently assembled physical mechanism with consistent geometry, mass properties, sensing, and coordinate conventions.

### Phase 6A: Toolbox and Native Simulink Cross-Validation

Within Phase 6A, use the Robotics System Toolbox surface when the doubt concerns the analytical inertia, velocity-product, or gravity terms themselves. Its `rigidBodyTree` is assembled from the baseline dimensions, masses, centres of mass, inertias, endpoint payload, and gravity direction, then compared with the project equations over 225 deterministic state points. Viscous friction is excluded from both sides of this rigid-body-only comparison.

Second, `models/rrm_pid_cross_validation.slx` implements the reference, fixed-gain PID controller, actuator saturation and anti-windup, nonlinear two-link plant, and logging as a native Simulink block diagram. The plant equations are local to the model and do not call the project dynamics or MATLAB closed-loop runner. Both implementations use the baseline robot, the `[0;0]` to `[45;60] deg` reference, a 3 s quintic move plus 2 s hold, 1 ms fixed-step RK4, zero disturbance, and zero measurement noise. Gains remain frozen.

> Both independent validation runners accept only fixed-gain PID under the exact 1 ms, zero-disturbance, zero-noise protocol; Fuzzy-PID is rejected rather than silently approximated.

The independent rigid-body comparison produced:

| Quantity | Maximum absolute difference | Acceptance limit |
|---|---:|---:|
| Inertia matrix | `2.2204e-16 kg m^2` | `1e-10 kg m^2` |
| Velocity product | `4.3021e-15 N m` | `1e-10 N m` |
| Gravity torque | `3.5527e-15 N m` | `1e-10 N m` |

The formal MATLAB–Simulink comparison produced the following worst-joint values:

| Frozen controller | q RMS (rad) | q max (rad) | dq RMS (rad/s) | tau RMS (N m) | Saturation difference (s) | Pass |
|---|---:|---:|---:|---:|---:|---:|
| Manual PID | `5.3425e-17` | `2.2204e-16` | `2.2568e-16` | `3.9128e-15` | `0` | yes |
| Optimized PID | `1.4438e-17` | `5.5511e-17` | `1.2625e-16` | `3.6824e-15` | `0` | yes |

Both Simulink runs completed without saturation and retained the unchanged Phase 1 steady-state success criteria. The observed differences are at floating-point roundoff scale and far below the frozen acceptance limits; this validates numerical consistency under the one fixed nominal protocol, not real-time execution, hardware safety, every stress scenario, or the Fuzzy-PID rule engine.

### Phase 6B: Simscape Multibody Physical Cross-Validation

Phase 6B replaces the equation-coded Phase 6A plant with a physical Simscape Multibody mechanism while retaining the same verified Reference and PID Controller subsystems. `models/rrm_multibody_cross_validation.slx` contains two torque-actuated Revolute Joint blocks, two three-dimensional Brick Solid links with explicit masses and inertia tensors, a distal point-mass payload, gravity, viscous joint damping, a Transform Sensor, physical-signal converters, and named logging. The Multibody plant never calls the project dynamics or MATLAB closed-loop runner.

> The Multibody builder requires the verified Phase 6A model because it copies the Reference and PID Controller subsystems, while assembling the physical plant independently.

The formal protocol remains the baseline robot, `[0;0]` to `[45;60] deg`, a 3 s quintic move plus 2 s hold, 1 ms fixed-step `ode4`, zero disturbance, zero measurement noise, and frozen manual and optimized PID gains. Acceptance limits are `1e-3 rad` q RMS, `5e-3 rad` q maximum, `2e-2 rad/s` dq RMS, `0.2 N m` torque RMS, `1e-3 m` end-effector RMS, `5e-3 m` end-effector maximum, `1e-9 m` out-of-plane motion, and `5 ms` saturation-time difference.

The formal MATLAB–Multibody comparison produced:

| Frozen controller | q RMS worst (rad) | q max worst (rad) | dq RMS worst (rad/s) | tau RMS worst (N m) | EE RMS (m) | EE max (m) | Out of plane (m) | Pass |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Manual PID | `6.5761e-17` | `2.2204e-16` | `2.5930e-16` | `3.4636e-15` | `1.0866e-16` | `3.3422e-16` | `0` | yes |
| Optimized PID | `9.6416e-18` | `5.5511e-17` | `9.0136e-17` | `2.7761e-15` | `9.6973e-17` | `2.9505e-16` | `0` | yes |

Both physical runs completed without saturation and passed the unchanged tracking criteria. Manual-PID steady RMS errors were `[0.0012684;0.013762] rad`; optimized-PID errors were `[3.3225e-5;0.0071288] rad`, matching the nominal MATLAB study. The near-roundoff agreement confirms that joint axes, gravity direction, mass distribution, inertia, payload, damping, coordinate signs, sensing, and torque actuation are consistent under this protocol.

Multibody Explorer remains enabled for interactive three-dimensional inspection. The formal animation is a 5.033 s, 1280-by-720, 30 fps MPEG-4 rendered deterministically from the manual-PID Multibody joint logs. MATLAB R2026a Update 4's new Multibody Explorer `smwritevideo` backend created locked zero-byte files and crashed `physmod_sm_gui_app_video.dll` under `matlab -batch` in this environment for both MPEG-4 and AVI. The automated study therefore uses MATLAB `VideoWriter`, whose codec and clean batch shutdown were separately tested, while the physical state still comes exclusively from the Multibody run.

> Smoke mode still writes comparison data and figures but intentionally skips MP4 export; video is a full-mode artifact.

## Design Rules

- Core numerical package functions do not read base-workspace variables or perform implicit file I/O; the explicitly named model builder and video exporter own their requested artifacts.
- Experiment scripts orchestrate verified public functions and own output generation.
- Every controller uses the same simulator, reference format, actuator limits, and metrics.
- Physical, controller, trajectory, and scenario parameters remain separate.
- Tests assert physical invariants and tolerances rather than brittle exact trajectories.

## Limitations

These remain simulation results, not evidence of real-robot performance or hardware safety. Optimization used one initial point and one training trajectory. Phase 4B models independent white Gaussian measurement noise only; it does not represent quantization, bias, drift, coloured noise, sensor filtering, sample-rate mismatch, or delay. Phase 5 assumes perfectly known reachable waypoints and omits perception, collision avoidance, gripper forces, object dynamics, and path replanning. Phase 6A and Phase 6B cover one nominal fixed-gain PID protocol; the Multibody assembly remains a planar two-joint mechanism represented by three-dimensional solids and does not validate contact, grasping, actuator electronics, real-time execution, or the Fuzzy-PID rule engine. The plant still omits actuator dynamics, dry friction, backlash, flexible links, and communication effects. Thirty noise seeds, two nominal Cartesian tasks, and one cross-validation protocol support reproducible within-study comparisons, not universal probability claims.

## Research Baseline

When you need the controlling requirements or a phase-specific implementation decision behind the verified workflow, start with the authoritative revised plan because it anchors the repository evidence to the agreed study scope:

```text
docs/requirements/Daniel_MATLAB_Robotics_Project_Implementation_Guide_Revised.md
```

The Phase 1 through Phase 7A design and implementation plans are stored under `docs/skills/`.
