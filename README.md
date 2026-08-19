# Reliable Robotic Manipulation: PID vs Fuzzy-PID

This repository implements the revised MATLAB robotics research plan in verified stages. Phase 1 provides the common mathematical and experimental foundation: a payload-aware planar two-link manipulator, analytical kinematics, nonlinear rigid-body dynamics, a smooth joint reference, a torque-limited PID controller, deterministic simulation, common metrics, tests, and one reproducible nominal experiment.

The project studies reliable low-level execution for a **given** robot and trajectory. Robot morphology is a controlled robustness variable in later phases; it is not an optimization target.

## Current Status

Implemented in Phase 1:

- baseline 2-DOF planar robot configuration;
- analytical forward and two-branch inverse kinematics;
- payload-aware inertia, Coriolis, gravity, and viscous-friction dynamics;
- rest-to-rest quintic joint trajectory with terminal hold;
- independent-joint PID with derivative filtering, torque saturation, and back-calculation anti-windup;
- fixed-step RK4 closed-loop simulation;
- common tracking, control-effort, saturation, and success metrics;
- MATLAB Unit Tests and a reproducible nominal experiment.

Deferred to later verified phases:

- project-owned Mamdani Fuzzy-PID;
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

Run only the nominal experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_nominal_pid.m');"
```

The experiment writes:

```text
results/data/nominal_pid.mat
results/figures/nominal_pid_tracking.png
results/figures/nominal_pid_torque.png
```

Generated MAT and PNG outputs are excluded from Git.

## Repository Structure

```text
+rrm/
  +config/       Robot, PID, and simulation configuration factories
  +control/      Controller update functions
  +dynamics/     Rigid-body matrices and forward dynamics
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

The default reference moves from `[0; 0]` degrees to `[45; 60]` degrees in 3 seconds and holds the target until 5 seconds. Simulation and control use a deterministic 1 ms fixed step.

## Design Rules

- Package functions do not read base-workspace variables or perform file I/O.
- Experiment scripts orchestrate verified public functions and own output generation.
- Every controller will use the same simulator, reference format, actuator limits, and metrics.
- Physical, controller, trajectory, and scenario parameters remain separate.
- Tests assert physical invariants and tolerances rather than brittle exact trajectories.

## Limitations

This is a simulation result, not evidence of real-robot performance. Phase 1 has not yet validated actuator dynamics, sensor sampling, dry friction, backlash, flexible links, communication delay, collision constraints, or hardware safety. The independent-joint PID is a baseline controller; later phases must preserve identical test conditions when comparing Fuzzy-PID and optimization-tuned PID.

## Research Baseline

The authoritative revised plan is stored at:

```text
docs/requirements/Daniel_MATLAB_Robotics_Project_Implementation_Guide_Revised.md
```

The Phase 1 design and implementation plan are stored under `docs/skills/`.
