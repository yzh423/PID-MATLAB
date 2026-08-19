# Reliable Robotic Manipulation: PID vs Fuzzy-PID

This repository implements the revised MATLAB robotics research plan in verified stages. Phases 1–4A provide a payload-aware planar two-link manipulator, analytical kinematics, nonlinear rigid-body dynamics, torque-limited PID and Mamdani Fuzzy-PID controllers, one shared deterministic simulator, optimization-assisted PID tuning, and a reproducible deterministic robustness matrix.

The project studies reliable low-level execution for a **given** robot and trajectory. Robot morphology is a controlled robustness variable in later phases; it is not an optimization target.

## Current Status

Implemented through Phase 4A:

- baseline 2-DOF planar robot configuration;
- analytical forward and two-branch inverse kinematics;
- payload-aware inertia, Coriolis, gravity, and viscous-friction dynamics;
- rest-to-rest quintic joint trajectory with terminal hold;
- independent-joint PID with derivative filtering, torque saturation, and back-calculation anti-windup;
- project-owned five-label Mamdani Fuzzy-PID with online bounded gain adaptation;
- one fixed-step RK4 simulation path shared by both controllers;
- common tracking, control-effort, saturation, and success metrics;
- effective-gain and fuzzy-inference histories;
- bounded six-gain PID tuning using deterministic `fmincon` SQP;
- a dimensionless objective covering tracking, overshoot, effort, settling, saturation, and failure;
- frozen-gain validation on an unseen 0.8 kg endpoint payload;
- three prescribed link configurations and time-varying disturbance torque;
- a 13-scenario, 39-run deterministic robustness matrix with frozen controllers;
- Cartesian tracking, actuator saturation, recovery, and robustness metrics;
- raw MAT evidence, per-run and summary CSV tables, and six robustness figures;
- MATLAB Unit Tests and reproducible controller and optimization experiments.

Deferred to later verified phases:

- seeded measurement-noise trials and statistical success intervals (Phase 4B);
- Cartesian path tracking and simplified pick-and-place;
- Simulink and Simscape Multibody cross-validation.

## Requirements

- Windows PowerShell
- MATLAB R2026a at `E:\MATLAB2026\bin\matlab.exe`
- No third-party MATLAB packages

Installed toolboxes relevant to later phases include Control System Toolbox, Optimization Toolbox, Robotics System Toolbox, Simulink, Simscape, and Simscape Multibody. Fuzzy Logic Toolbox and Global Optimization Toolbox are not required and are not installed in the current environment.

## Quick Start

From the repository root, run the complete verification:

```powershell
& '.\scripts\verify.ps1'
```

Run only the tests:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); results=runtests('tests','IncludeSubfolders',true); assertSuccess(results);"
```

Run the nominal PID experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_nominal_pid.m');"
```

Run the fair PID-versus-Fuzzy comparison:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_nominal_pid_vs_fuzzy.m');"
```

Run optimization-assisted PID tuning and held-out validation:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_pid_optimization.m');"
```

Run the full deterministic robustness matrix:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_deterministic_robustness.m');"
```

The experiment writes:

```text
results/data/nominal_pid.mat
results/figures/nominal_pid_tracking.png
results/figures/nominal_pid_torque.png
results/data/nominal_pid_vs_fuzzy.mat
results/figures/nominal_pid_vs_fuzzy_tracking.png
results/figures/nominal_pid_vs_fuzzy_error.png
results/figures/nominal_pid_vs_fuzzy_torque.png
results/figures/nominal_pid_vs_fuzzy_gains.png
results/data/pid_optimization.mat
results/figures/pid_optimization_objective.png
results/figures/pid_optimization_nominal_tracking.png
results/figures/pid_optimization_nominal_torque.png
results/figures/pid_optimization_validation_tracking.png
results/figures/pid_optimization_gains.png
results/data/deterministic_robustness.mat
results/data/deterministic_robustness_runs.csv
results/data/deterministic_robustness_summary.csv
results/figures/deterministic_robustness_payload.png
results/figures/deterministic_robustness_configuration.png
results/figures/deterministic_robustness_uncertainty.png
results/figures/deterministic_robustness_disturbance.png
results/figures/deterministic_robustness_heatmap.png
results/figures/deterministic_robustness_summary.png
```

Generated MAT, CSV, and PNG outputs are excluded from Git.

## Repository Structure

```text
+rrm/
  +config/       Robot, controller, and simulation configuration factories
  +control/      PID and Fuzzy-PID update functions
  +dynamics/     Rigid-body matrices and forward dynamics
  +fuzzy/        Five-set memberships and Mamdani inference
  +kinematics/   Forward and analytical inverse kinematics
  +metrics/      Common experiment metrics and success decision
  +optimization/ PID multiplier mapping, objective scoring, and fmincon tuning
  +robustness/   Deterministic scenarios, metrics, matrix execution, and summaries
  +simulation/   Deterministic closed-loop simulation
  +trajectory/   Reference generation
docs/
  requirements/  Revised source plan in DOCX and Markdown
  skills/specs/  Approved engineering design
  skills/plans/  Executable implementation plan
experiments/     Reproducible experiment entry points
results/         Generated data and figures
scripts/         Verification commands
tests/           MATLAB Unit Tests grouped by subsystem
```

## Mathematical Model

The simulated plant is

```text
M(q) ddq + C(q,dq) dq + G(q) + Fv dq = tau + disturbance.
```

The model includes the two link masses and inertias, link centres of mass, endpoint payload, gravity, viscous friction, joint limits, and actuator torque limits. Angles are in radians and torque is in newton-metres throughout the package.

The default reference moves from `[0; 0]` degrees to `[45; 60]` degrees in 3 seconds and holds the target until 5 seconds. Simulation and control use a deterministic 1 ms fixed step. Neither controller uses gravity feedforward in the nominal comparison.

## Fuzzy-PID Design

Each joint uses normalized position error and error rate as Mamdani inputs. Both inputs have five triangular/shoulder labels—negative big, negative small, zero, positive small, and positive big—on `[-1,1]`. The implementation evaluates three symmetric `5 x 5` rule tables with min implication, max aggregation, and a 101-point discrete centroid. It does not call Fuzzy Logic Toolbox.

The normalized outputs adjust the Phase 1 gains within fixed relative ranges:

```text
Kp: +/-35%    Ki: +/-50%    Kd: +/-30%
```

Large tracking error increases proportional action and suppresses integration. Near-zero stationary error increases integration, while large error rate increases damping. Explicit lower and upper gain bounds are enforced after inference, and the shared PID calculation still owns derivative filtering, torque saturation, and anti-windup.

## Nominal Comparison

The checked Phase 2 reference run produced:

| Controller | Joint | Steady RMS error (rad) | Steady max error (rad) | Torque RMS (N m) | Saturation (s) |
|---|---:|---:|---:|---:|---:|
| PID | 1 | 0.0012684 | 0.0014577 | 12.503 | 0 |
| PID | 2 | 0.013762 | 0.014935 | 2.6202 | 0 |
| Fuzzy-PID | 1 | 0.0097924 | 0.010887 | 12.432 | 0 |
| Fuzzy-PID | 2 | 0.013174 | 0.014896 | 2.6316 | 0 |

Both controllers met the common acceptance thresholds. In this one nominal case, Fuzzy-PID slightly improved joint 2 steady RMS error and joint 1 torque RMS, but worsened joint 1 steady tracking error. These data show bounded, successful online adaptation under the baseline condition; they do not establish general superiority or robustness.

## Optimization-Assisted PID Tuning

Phase 3 tunes six dimensionless multipliers in the order `[Kp1,Kp2,Ki1,Ki2,Kd1,Kd2]`. The manual gains correspond to an all-ones initial point. Multiplier bounds are `[0.5,0.5,0.25,0.25,0.5,0.5]` to `[2,2,2,2,2,2]`; robot dimensions and payload are not decision variables.

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

## Deterministic Robustness Matrix

Phase 4A freezes the manual PID, Phase 2 Mamdani Fuzzy-PID, and Phase 3 optimized PID before testing. No controller is retuned for a stress case. Every controller receives the same 5 s reference and 1 ms step within each scenario.

The 13 prescribed scenarios are: nominal; payloads 0.0, 1.0, and 1.5 kg; compact and extended link configurations; mass/inertia scales 0.8, 0.9, 1.1, and 1.2; a `[4;-3] N m` pulse from 2.00 through 2.10 s; actuator limits reduced to `[18;10] N m`; and an extended-link combined case with 1.0 kg payload, 1.2 mass/inertia scale, reduced limits, and the pulse. Link changes recompute centres of mass and uniform-link inertias. These are prescribed evaluation cases, not morphology optimization variables.

Robustness success requires a completed simulation, the existing steady-state joint thresholds, and maximum end-effector tracking error at most 0.15 m. Recovery is the first 0.10 s continuous interval after the pulse during which both joint errors remain within 2 degrees. Saturation is reported rather than automatically treated as failure.

The verified full matrix produced:

| Frozen controller | Successful runs | Success rate | Mean joint RMS (rad) | Worst joint RMS (rad) | Worst EE error (m) | Total saturation (s) |
|---|---:|---:|---:|---:|---:|---:|
| Manual PID | 8/13 | 61.54% | 0.13109 | 0.83476 | 1.8046 | 10.797 |
| Mamdani Fuzzy-PID | 9/13 | 69.23% | 0.13042 | 0.83604 | 1.8038 | 10.528 |
| Optimized PID | 10/13 | 76.92% | 0.11074 | 0.83037 | 1.8070 | 11.279 |

All three controllers passed nominal and disturbance-pulse cases with no saturation. Their pulse recovery time was 0 s because both errors were already inside the 2 degree recovery band when the pulse ended. The manual PID additionally failed the 1.0 kg payload and extended configuration thresholds. All controllers failed the 1.5 kg payload, actuator-derated, and combined cases; the combined case caused approximately 6 s of joint-summed saturation per controller and no qualifying recovery before the run ended.

The optimized PID achieved the highest success count and lowest matrix-average joint RMS, while accumulating the most total saturation and a slightly larger worst end-effector error. Fuzzy-PID gained one successful case over manual PID and slightly reduced total saturation. These trade-offs and the shared failures do not establish universal superiority.

## Design Rules

- Package functions do not read base-workspace variables or perform file I/O.
- Experiment scripts orchestrate verified public functions and own output generation.
- Every controller uses the same simulator, reference format, actuator limits, and metrics.
- Physical, controller, trajectory, and scenario parameters remain separate.
- Tests assert physical invariants and tolerances rather than brittle exact trajectories.

## Limitations

This is a deterministic simulation result, not evidence of real-robot performance, stochastic robustness, or hardware safety. Optimization used one initial point and one training trajectory. Phase 4A has no measurement-noise model, random trials, confidence intervals, actuator dynamics, sensor sampling, dry friction, backlash, flexible links, communication delay, or collision constraints. Phase 4B must add locally seeded repeated noise trials and statistical reporting without changing the global random state.

## Research Baseline

The authoritative revised plan is stored at:

```text
docs/requirements/Daniel_MATLAB_Robotics_Project_Implementation_Guide_Revised.md
```

The Phase 1–4A design and implementation plans are stored under `docs/skills/`.
