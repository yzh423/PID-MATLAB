# Reliable Robotic Manipulation: PID vs Fuzzy-PID

This repository implements the revised MATLAB robotics research plan in verified stages. Phases 1 and 2 provide a payload-aware planar two-link manipulator, analytical kinematics, nonlinear rigid-body dynamics, a smooth joint reference, torque-limited PID and Mamdani Fuzzy-PID controllers, one shared deterministic simulator, common metrics, tests, and reproducible nominal experiments.

The project studies reliable low-level execution for a **given** robot and trajectory. Robot morphology is a controlled robustness variable in later phases; it is not an optimization target.

## Current Status

Implemented through Phase 2:

- baseline 2-DOF planar robot configuration;
- analytical forward and two-branch inverse kinematics;
- payload-aware inertia, Coriolis, gravity, and viscous-friction dynamics;
- rest-to-rest quintic joint trajectory with terminal hold;
- independent-joint PID with derivative filtering, torque saturation, and back-calculation anti-windup;
- project-owned five-label Mamdani Fuzzy-PID with online bounded gain adaptation;
- one fixed-step RK4 simulation path shared by both controllers;
- common tracking, control-effort, saturation, and success metrics;
- effective-gain and fuzzy-inference histories;
- MATLAB Unit Tests and reproducible PID and PID-versus-Fuzzy nominal experiments.

Deferred to later verified phases:

- `fmincon` PID tuning and held-out validation;
- payload, morphology, uncertainty, disturbance, noise, saturation, and combined stress sweeps;
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
```

Generated MAT and PNG outputs are excluded from Git.

## Repository Structure

```text
+rrm/
  +config/       Robot, controller, and simulation configuration factories
  +control/      PID and Fuzzy-PID update functions
  +dynamics/     Rigid-body matrices and forward dynamics
  +fuzzy/        Five-set memberships and Mamdani inference
  +kinematics/   Forward and analytical inverse kinematics
  +metrics/      Common experiment metrics and success decision
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

## Design Rules

- Package functions do not read base-workspace variables or perform file I/O.
- Experiment scripts orchestrate verified public functions and own output generation.
- Every controller uses the same simulator, reference format, actuator limits, and metrics.
- Physical, controller, trajectory, and scenario parameters remain separate.
- Tests assert physical invariants and tolerances rather than brittle exact trajectories.

## Limitations

This is a nominal simulation result, not evidence of real-robot performance or broad robustness. The project has not yet validated actuator dynamics, sensor sampling, dry friction, backlash, flexible links, communication delay, collision constraints, or hardware safety. Later phases must preserve identical test conditions and add held-out stress cases before drawing controller-ranking conclusions.

## Research Baseline

The authoritative revised plan is stored at:

```text
docs/requirements/Daniel_MATLAB_Robotics_Project_Implementation_Guide_Revised.md
```

The Phase 1 and Phase 2 design and implementation plans are stored under `docs/skills/`.
