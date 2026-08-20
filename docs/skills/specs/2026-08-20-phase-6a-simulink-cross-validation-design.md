# Phase 6A Simulink and Robotics Cross-Validation Design

## Objective

Add an independently executed validation surface for the verified planar two-link study. Phase 6A must:

1. reconstruct the baseline robot in Robotics System Toolbox and compare its rigid-body dynamics with the project-owned analytical equations;
2. provide an organized, reproducible Simulink closed-loop model for the manual and optimization-tuned PID controllers;
3. compare Simulink histories against the Phase 1 MATLAB RK4 simulator under identical nominal conditions; and
4. publish quantitative evidence without retuning controllers or weakening any existing criterion.

The result supports the revised guide's requirement for an organized Simulink deliverable and validation with Robotics System Toolbox or Simscape Multibody. It is numerical cross-validation, not hardware validation.

## Approved Assumptions

The user previously authorized recommended implementation decisions without repeated questions. Phase 6A therefore proceeds with these explicit assumptions:

1. The required slice is one representative joint-space experiment, not a duplicate of every Phase 1–5 experiment.
2. Manual PID and optimization PID are included because both share the same fixed-gain controller structure and can use one transparent Simulink block diagram.
3. Mamdani Fuzzy-PID remains MATLAB-only in this phase. Reimplementing the fuzzy inference system in Simulink would create a second rule engine and is not required to validate the plant or fixed-gain loop.
4. Robotics System Toolbox supplies the independent rigid-body dynamics reference. Simscape Multibody is installed and licensed, but a complete three-dimensional physical assembly is deferred to Phase 6B.
5. Simulink uses native blocks and an independently written plant-equation block; it must not call `rrm.simulation.runController` or `rrm.dynamics.acceleration` during simulation.
6. Generated numerical and figure artifacts remain ignored. The model builder and generated `.slx` model are committed.

## Selected Architecture

Phase 6A uses two complementary checks:

### Layer 1 — Robotics System Toolbox Dynamics Check

`rrm.validation.makeRigidBodyTree(robot)` constructs a fixed-base two-revolute-joint `rigidBodyTree`:

- both joint axes are positive z;
- links extend along positive x;
- link centers of mass and z-axis inertias match `makeRobot`;
- a fixed point-mass payload is placed at the distal tip;
- gravity acts along negative y so zero joint angle represents a horizontal arm;
- viscous friction remains outside the tree because it is not a rigid-body term.

`rrm.validation.compareRigidBodyDynamics(robot, configurations)` compares:

- `rrm.dynamics.matrices` inertia matrix with `massMatrix`;
- the project velocity product `C*dq` with `velocityProduct`;
- the project gravity vector with `gravityTorque`.

The comparison spans a deterministic grid of valid joint angles and velocities, not only the nominal trajectory.

### Layer 2 — Native Simulink Closed Loop

`rrm.simulink.buildPidCrossValidationModel(modelPath)` creates an organized model with these top-level regions:

```text
q reference ----> [PID Controller] ----> tau ----> [2-Link Plant] ----> q, dq
dq reference --->        ^                              |
                         +------------------------------+
```

The controller is assembled from native Sum, Gain, Discrete Transfer Fcn, Discrete-Time Integrator, MinMax/Saturation, and signal-routing blocks. It preserves:

- independent joint gains;
- filtered velocity-error derivative;
- torque saturation;
- back-calculation anti-windup;
- one controller update per 1 ms sample.

The plant uses continuous Integrator blocks and a MATLAB Function block containing the two-link acceleration equations. The plant block receives scalar physical parameters and does not call project dynamics functions. The model uses fixed-step `ode4` at 1 ms; controller outputs are held between major steps.

The model contains labeled subsystems, units in annotations, signal names, and logged outputs. It must be loadable without running an experiment first.

### Execution Boundary

`rrm.simulink.runPidCrossValidation(robot, controller, reference, options, modelPath)`:

1. validates the controller is a fixed-gain PID;
2. validates the reference and sample grid;
3. builds the model if absent or explicitly requested;
4. passes all inputs through `Simulink.SimulationInput` rather than mutating the base workspace;
5. runs the model; and
6. returns the same core histories as the MATLAB runner: `time`, `q`, `dq`, `qReference`, `dqReference`, `tau`, and `status`.

## Fixed Experiment Protocol

The formal experiment uses:

- robot: baseline, `L1=0.45 m`, `L2=0.35 m`, `m1=2.0 kg`, `m2=1.5 kg`, payload `0.5 kg`;
- reference: `[0;0]` to `[45;60] deg`;
- motion: 3 s quintic plus 2 s hold;
- sample time: 1 ms;
- initial velocity: `[0;0]`;
- disturbance and measurement noise: zero;
- controllers: frozen manual PID and frozen optimization PID;
- actuator limits: `[25;15] N m`;
- MATLAB reference: unchanged `rrm.simulation.runController`.

No parameter may be fitted to reduce MATLAB–Simulink disagreement.

## Comparison Metrics

For each controller, compute over aligned finite samples:

- joint-angle difference RMS and maximum absolute value per joint;
- joint-velocity difference RMS and maximum absolute value per joint;
- torque difference RMS and maximum absolute value per joint;
- Simulink steady-state tracking metrics through the existing metric definitions;
- MATLAB and Simulink saturation times;
- completion and common success status.

The report must show both absolute values and pass/fail flags. A single aggregate boolean is insufficient evidence.

## Acceptance Criteria

### Rigid-Body Dynamics

Across the frozen validation grid:

- maximum absolute inertia-matrix difference: `<= 1e-10 kg m^2`;
- maximum absolute velocity-product difference: `<= 1e-10 N m`;
- maximum absolute gravity-torque difference: `<= 1e-10 N m`.

If Robotics System Toolbox uses a different sign convention, the model construction must be corrected. Post-hoc sign flipping in the comparison is prohibited.

### Closed-Loop Cross-Validation

For both controllers:

- Simulink status is `completed`;
- time grids are identical;
- joint-angle difference RMS per joint is `<= 1e-5 rad`;
- joint-angle maximum absolute difference per joint is `<= 5e-5 rad`;
- joint-velocity difference RMS per joint is `<= 1e-4 rad/s`;
- torque difference RMS per joint is `<= 5e-3 N m`;
- MATLAB and Simulink saturation-time difference per joint is `<= 1 ms`;
- Simulink satisfies the unchanged Phase 1 steady-state criteria.

These are numerical-equivalence thresholds, not new controller-performance thresholds. They may be tightened after observed evidence, but not loosened merely to make a failing implementation pass.

## Commands

Build the model:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); rrm.simulink.buildPidCrossValidationModel(fullfile('models','rrm_pid_cross_validation.slx'));"
```

Run the formal experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_simulink_cross_validation.m');"
```

Run Phase 6A tests:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests({'tests/validation','tests/simulink','tests/experiments/TestSimulinkCrossValidation.m'}); assertSuccess(results);"
```

Run complete verification:

```powershell
& '.\scripts\verify.ps1'
```

Run static analysis:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); files=[dir(fullfile('+rrm','**','*.m')); dir(fullfile('experiments','*.m'))]; n=0; for k=1:numel(files), n=n+numel(checkcode(fullfile(files(k).folder,files(k).name),'-id')); end; fprintf('CHECKCODE_ISSUES=%d\n',n); assert(n==0);"
```

## Project Structure

```text
+rrm/+validation/   Robotics System Toolbox model and dynamics comparison
+rrm/+simulink/     Deterministic model builder, runner, and comparison helpers
models/             Committed generated Simulink model
experiments/        Reproducible Phase 6A experiment
tests/validation/   Independent rigid-body dynamics tests
tests/simulink/     Builder, model, runner, and numerical-alignment tests
tests/experiments/  Formal experiment smoke test
results/data/       Ignored MAT and CSV evidence
results/figures/    Ignored comparison figures
docs/skills/        Design and implementation plans
```

## Code Style and Interfaces

Public functions use package-qualified names, scalar structs, string status values, and explicit validation consistent with Phases 1–5:

```matlab
comparison = rrm.simulink.comparePidRuns(matlabRun, simulinkRun);
assert(comparison.pass, comparison.failureSummary);
```

The builder must be idempotent: rebuilding replaces only the exact target model after validating that the target is beneath the caller-provided model directory. Experiment scripts own file output and figures; package functions do not write results.

## Error Handling

Use stable identifiers for:

- missing Simulink or Robotics System Toolbox capability;
- unsupported controller type;
- invalid sample grid or initial condition;
- unsafe model path;
- missing or incompatible logged signals;
- incomplete/non-finite Simulink output;
- comparison time-grid mismatch.

Tests must exercise the principal invalid-input paths. Capability failures must be explicit, not silently converted into skipped evidence in the formal verification script.

## Testing Strategy

1. **Rigid-body unit tests:** validate topology, physical parameters, and grid-wide `M`, `C*dq`, and `G` agreement.
2. **Builder tests:** build into a temporary directory, load the model, inspect solver and required subsystem/block names, close it, and delete only the owned temporary directory.
3. **Runner RED/GREEN tests:** start with a short trajectory, require aligned dimensions and finite outputs, then compare against MATLAB.
4. **Comparison tests:** synthetic exact, threshold-boundary, time-grid mismatch, and non-finite cases.
5. **Experiment smoke test:** run both controllers on a shortened reference without producing repository artifacts.
6. **Formal experiment:** run the fixed 5 s protocol, save MAT/CSV, and generate tracking, difference, torque, and summary figures.
7. **Regression:** all existing tests and all Phase 1–5 experiments remain green.
8. **Visual QA:** inspect the committed model layout and every Phase 6A figure for units, legends, readable axes, and non-misleading scales.

## Artifacts

Formal execution produces:

- `models/rrm_pid_cross_validation.slx`;
- `results/data/simulink_cross_validation.mat`;
- `results/data/simulink_cross_validation_runs.csv`;
- `results/figures/simulink_cross_validation_tracking.png`;
- `results/figures/simulink_cross_validation_differences.png`;
- `results/figures/simulink_cross_validation_torque.png`;
- `results/figures/simulink_cross_validation_summary.png`.

The README records the exact protocol, numerical agreement, limitations, command, and artifact paths.

## Boundaries

### Always

- Keep all Phase 1–5 controllers, thresholds, robot parameters, and experiment outputs backward compatible.
- Use the same reference and initial state within each MATLAB–Simulink pair.
- Preserve the unrelated root DOCX.
- Run tests before each implementation commit and full verification before integration.
- Report any mismatch that exceeds its frozen threshold.

### Requires New Direction

- Retune gains or alter acceptance thresholds.
- Add a dependency outside installed MathWorks products.
- Expand the phase to Fuzzy-PID block-diagram replication.
- Change the baseline robot's physical convention.

### Never

- Call the pure-MATLAB simulator from inside the Simulink model.
- Present same-code-path agreement as independent validation.
- Suppress saturation, non-finite states, or failed comparisons.
- Claim hardware, real-time, or safety validation.
- Push, publish, or open a pull request without explicit authorization.

## Deferred Work

- Phase 6B Simscape Multibody three-dimensional physical assembly and animation;
- Simulink reproduction of the Mamdani Fuzzy-PID rule engine;
- actuator electrical dynamics, encoder models, delays, quantization, and real-time execution;
- hardware-in-the-loop or real-robot testing;
- perception, collision avoidance, grasp physics, and replanning.

## Completion Criteria

Phase 6A is complete only when:

1. the committed Simulink model is reproducibly generated and loadable;
2. Robotics System Toolbox dynamics pass the grid-wide tolerances;
3. both PID controllers pass every MATLAB–Simulink numerical threshold;
4. Simulink runs satisfy unchanged controller success criteria;
5. all Phase 1–6A tests, static analysis, and public experiments pass from merged `main`;
6. MAT, CSV, figures, README evidence, and the model exist in the main checkout; and
7. the temporary worktree and merged local feature branch are removed without touching the user's DOCX.
