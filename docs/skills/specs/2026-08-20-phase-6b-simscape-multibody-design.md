# Phase 6B Simscape Multibody Physical Validation Design

## Objective

Add a reproducible three-dimensional Simscape Multibody realization of the verified planar two-link manipulator. Phase 6B must:

1. assemble the baseline arm from physical Multibody bodies, frames, joints, gravity, damping, and endpoint payload;
2. drive the physical mechanism with the frozen manual PID and optimization PID controllers through torque actuation;
3. sense joint position, joint velocity, applied torque, and end-effector position through physical-signal interfaces;
4. compare the Multibody histories against the existing MATLAB RK4 implementation under one fixed nominal protocol; and
5. provide an organized committed model, quantitative evidence, a readable three-dimensional visualization, and a representative animation.

This is a physical-model and visualization cross-validation layer. It is not hardware, real-time, contact, actuator-electronics, or safety validation.

## Approved Assumptions

The user has already authorized recommended implementation choices without repeated questions. Phase 6B therefore proceeds with these explicit assumptions:

1. The baseline remains the planar 2-DOF arm; three-dimensional solids visualize a mechanism whose two joint axes remain parallel to world z.
2. Manual PID and optimization PID are included because they share the verified fixed-gain Simulink controller structure.
3. The Phase 6A reference and PID controller subsystems are copied into the generated Phase 6B model. The saved Phase 6B model is standalone after generation.
4. The Multibody plant must not call `rrm.dynamics`, `rrm.simulation.runController`, or the Phase 6A equation-based plant during simulation.
5. Link z-axis moments of inertia exactly match the analytical model. Positive transverse moments are supplied to form a physically valid three-dimensional inertia tensor; they do not affect the constrained planar motion.
6. The endpoint payload is a point mass at the distal tip and has no rotational inertia, matching the analytical model.
7. Multibody Explorer supplies interactive three-dimensional visualization. The formal experiment exports one representative MP4 from the validated Multibody joint logs through a deterministic `VideoWriter` renderer. R2026a Update 4 `smwritevideo` was rejected for automated use after both MPEG-4 and AVI created locked zero-byte files and crashed `physmod_sm_gui_app_video.dll` under `matlab -batch`.
8. Generated MAT, CSV, PNG, and MP4 evidence remains ignored. The deterministic builder and generated `.slx` model are committed.

## Alternatives Considered

### Selected: Torque-Actuated Closed Loop

Use two Revolute Joint blocks with torque actuation and position/velocity sensing. Simulink PID torque passes through Simulink-PS Converter blocks. Joint physical signals pass back through PS-Simulink Converter blocks. This validates assembly, gravity, inertia, damping, sensing, actuation, and closed-loop execution together.

### Rejected: Motion-Prescribed Animation

Prescribing `q(t)` produces a reliable animation but bypasses the mechanism dynamics and controller. It cannot validate physical execution and therefore does not justify a separate phase.

### Rejected: CAD or External Geometry Import

CAD import would add external assets and make mass-property consistency harder to audit. Simple solids with explicit custom inertias are more transparent and reproduce the project parameters exactly.

## Selected Architecture

### Model Builder

`rrm.multibody.buildCrossValidationModel(modelPath)` creates `models/rrm_multibody_cross_validation.slx` with four top-level regions:

```text
q reference ----> [Verified PID Controller] ----> tau ----> [Multibody Plant] ----> q, dq, xyz
dq reference --->            ^                              |
                              +------------------------------+
```

The builder:

- validates that Simscape Multibody is installed and licensed;
- validates that the exact output path is beneath the caller-provided model directory;
- creates a fixed-step `ode4` model at 1 ms;
- copies the verified Phase 6A Reference and PID Controller subsystems;
- builds a native Multibody Plant subsystem and a labeled Logging subsystem;
- configures deterministic signal logging; and
- is idempotent for the exact target model.

### Physical Assembly

The Multibody Plant contains:

- World Frame and Mechanism Configuration with gravity `[0 -g 0] m/s^2`;
- one visual fixed base body;
- two torque-actuated Revolute Joint blocks with axes along local z;
- joint state targets for the supplied initial angles and zero velocity;
- one Brick Solid per link, offset so each joint is at the proximal link endpoint;
- explicit link masses, centers, colors, opacity, and custom inertia tensors;
- rigid transforms from each joint to its link center and distal frame;
- an endpoint Inertia block in point-mass mode for the payload;
- joint damping coefficients equal to `robot.viscousFriction`;
- Simulink-PS converters with `N*m` input units;
- PS-Simulink converters with `rad` and `rad/s` output units; and
- a Transform Sensor that measures the distal point relative to World in metres.

The model remains planar dynamically, while solid width, thickness, base geometry, colors, lighting, and camera provide a clear three-dimensional presentation.

### Execution Boundary

`rrm.multibody.runCrossValidation(robot, controller, reference, options, modelPath)`:

1. validates the baseline-compatible robot, fixed-gain PID, reference grid, and initial state;
2. builds the model when absent or explicitly requested;
3. passes physical, controller, trajectory, and initial-state parameters through `Simulink.SimulationInput` and the model workspace;
4. runs the Multibody model without changing the base workspace;
5. returns `time`, `q`, `dq`, `qReference`, `dqReference`, `tau`, `endEffectorPosition`, `status`, and model metadata; and
6. rejects missing, misaligned, non-finite, or incomplete logged signals with stable error identifiers.

### Numerical Comparison

`rrm.multibody.compareRuns(matlabRun, multibodyRun, robot)` aligns the identical time grids and computes:

- joint-angle difference RMS and maximum per joint;
- joint-velocity difference RMS and maximum per joint;
- applied-torque difference RMS and maximum per joint;
- end-effector position difference RMS and maximum;
- MATLAB and Multibody saturation times; and
- completion and aggregate pass status with individual flags.

The MATLAB end-effector history is recomputed from the MATLAB joint history with `rrm.kinematics.forward`. The comparison does not reuse Multibody measurements to construct the reference.

## Fixed Formal Protocol

- robot: baseline, `L1=0.45 m`, `L2=0.35 m`, `m1=2.0 kg`, `m2=1.5 kg`, payload `0.5 kg`;
- reference: `[0;0]` to `[45;60] deg`;
- motion: 3 s quintic plus 2 s hold;
- sample time and fixed solver step: 1 ms;
- initial joint position and velocity: zero;
- disturbance and measurement noise: zero;
- controllers: frozen manual PID and frozen optimization PID;
- actuator limits: `[25;15] N m`;
- MATLAB reference: unchanged `rrm.simulation.runController`;
- Multibody visualization: enabled for interactive use, suppressed during automated tests;
- exported animation: manual PID Multibody-log representative run at 30 frames/s, 1280-by-720 MPEG-4.

No gain, inertia, geometry, damping, or acceptance parameter may be fitted after observing cross-validation disagreement.

## Acceptance Criteria

For both controllers:

- MATLAB and Multibody statuses are `completed`;
- time and reference grids are identical;
- joint-angle difference RMS per joint is `<= 1e-3 rad`;
- joint-angle maximum absolute difference per joint is `<= 5e-3 rad`;
- joint-velocity difference RMS per joint is `<= 2e-2 rad/s`;
- applied-torque difference RMS per joint is `<= 2e-1 N m`;
- end-effector position difference RMS is `<= 1e-3 m`;
- end-effector position maximum is `<= 5e-3 m`;
- MATLAB and Multibody saturation-time difference per joint is `<= 5 ms`;
- Multibody satisfies the unchanged Phase 1 steady-state criteria; and
- every recorded history is finite and contains the full requested time grid.

Model-structure acceptance additionally requires:

- two Revolute Joint blocks;
- two link solids and one endpoint payload inertia;
- explicit gravity and joint damping;
- torque actuation and q/w sensing on both joints;
- an end-effector Transform Sensor;
- a loadable and compilable committed `.slx`; and
- a nonempty visual or video artifact from the formal run.

These tolerances are frozen before implementation. They are physical-model equivalence thresholds, not replacement controller-performance criteria.

## Commands

Build the model:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); rrm.multibody.buildCrossValidationModel(fullfile('models','rrm_multibody_cross_validation.slx'));"
```

Run Phase 6B tests:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests({'tests/multibody','tests/experiments/TestMultibodyCrossValidation.m'}); assertSuccess(results);"
```

Run the formal experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_multibody_cross_validation.m');"
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
+rrm/+multibody/   Model builder, runner, comparison, and log animation
models/             Committed generated Multibody model
experiments/        Reproducible Phase 6B experiment
tests/multibody/    Builder, runner, and comparison tests
tests/experiments/  Formal experiment smoke test
results/data/       Ignored MAT and CSV evidence
results/figures/    Ignored tracking, path, torque, and summary figures
results/videos/     Ignored representative Multibody MP4
docs/skills/        Design and implementation plans
```

## Code Style and Interfaces

Public functions use package-qualified names, scalar structs, string status values, column-per-joint histories, explicit SI units, and stable named errors:

```matlab
multibodyRun = rrm.multibody.runCrossValidation( ...
    robot,controller,reference,simulationOptions,modelPath);
comparison = rrm.multibody.compareRuns( ...
    matlabRun,multibodyRun,robot);
assert(comparison.pass,comparison.failureSummary);
```

Core numerical package functions do not write experiment artifacts. The explicitly named model builder and video exporter write only their caller-requested model or MP4; the experiment script owns orchestration and all artifact paths.

## Error Handling

Stable errors cover:

- missing or unlicensed Simscape Multibody;
- missing Phase 6A source model during generation;
- unsafe model path;
- unsupported controller type or robot topology;
- invalid physical parameter, reference grid, or initial condition;
- missing or incompatible physical-signal logs;
- non-finite or incomplete simulation output;
- comparison time/reference mismatch; and
- video-export failure in formal mode.

Automated numerical tests do not depend on an open Explorer window. The MP4 exporter consumes completed Multibody logs and therefore does not start or control the Explorer video backend.

## Testing Strategy

1. **Capability tests:** verify installed/licensed Multibody blocks and MATLAB MPEG-4 writing capability explicitly.
2. **Builder tests:** build in a temporary owned directory, load the model, inspect required blocks and parameters, compile, close, and remove only the test directory.
3. **Physical-structure tests:** assert two joints, correct gravity, damping, mass, z inertia, link transforms, payload, converter units, and sensor configuration.
4. **Runner tests:** use a short reference and require aligned finite q, dq, torque, and end-effector histories without base-workspace mutation.
5. **Comparison tests:** exact synthetic runs, threshold boundaries, time/reference mismatch, and non-finite histories.
6. **Numerical smoke comparison:** short manual and optimized PID runs against MATLAB.
7. **Experiment smoke test:** create two unique rows, MAT/CSV, and expected PNG artifacts without exporting a video.
8. **Formal experiment:** execute the fixed 5 s protocol, export evidence and a deterministic Multibody-log animation, and require both controllers to pass.
9. **Regression:** all Phase 1–6A tests and public experiments remain green.
10. **Visual QA:** inspect the model layout, physical assembly rendering, every Phase 6B figure, and representative video frame.

## Formal Artifacts

- `models/rrm_multibody_cross_validation.slx`;
- `results/data/multibody_cross_validation.mat`;
- `results/data/multibody_cross_validation_runs.csv`;
- `results/figures/multibody_cross_validation_tracking.png`;
- `results/figures/multibody_cross_validation_path.png`;
- `results/figures/multibody_cross_validation_torque.png`;
- `results/figures/multibody_cross_validation_summary.png`;
- `results/figures/multibody_cross_validation_model.png`;
- `results/videos/multibody_cross_validation_manual_pid.mp4`.

## Boundaries

### Always

- Preserve all Phase 1–6A robot parameters, controller gains, reference definitions, and performance criteria.
- Keep physical, controller, reference, and test parameters separate.
- Use SI units at every Simulink/physical-signal boundary.
- Test structure and physics before relying on visual inspection.
- Preserve the unrelated root DOCX.
- Run tests before every implementation commit and complete verification before integration.

### Requires New Direction

- Retune a controller or loosen a frozen acceptance threshold.
- Change the baseline robot topology, mass convention, or gravity convention.
- Add external CAD, mesh, texture, or third-party dependencies.
- Add contact, grasping, actuator electrical dynamics, or Fuzzy-PID replication.

### Never

- Call the MATLAB dynamics or simulator from inside the Multibody plant.
- Use prescribed motion as evidence of torque-driven dynamics agreement.
- Hide assembly, unit, saturation, non-finite, or comparison failures.
- Claim real-time, hardware, safety, contact, or grasp validation.
- Push, publish, or open a pull request without explicit authorization.

## Risks and Mitigations

- **Inertia convention mismatch:** define custom inertia at each link center and test the exact z moment before simulation.
- **Joint sign or gravity mismatch:** use parallel positive-z axes and world gravity `[0 -g 0]`; test a short free/controlled response before formal runs.
- **Physical-signal unit mistakes:** set every converter unit explicitly and test block parameters.
- **Multibody solver drift:** retain the frozen 1 ms `ode4` protocol and compare full histories against predeclared tolerances.
- **Interactive visualization in automation:** disable viewer opening locally during tests and restore preferences; keep the model itself visualization-ready.
- **Video export instability:** isolate video export to the formal experiment, validate a nonempty output, and report a hard failure rather than silently omitting it.

## Deferred Work

- Simulink reproduction of the Mamdani Fuzzy-PID rule engine;
- collision/contact and grasp mechanics;
- motor electrical, gearbox, encoder, quantization, backlash, and delay models;
- hardware-in-the-loop, real-time execution, or real-robot tests;
- perception, collision avoidance, grasp planning, and replanning.

## Completion Criteria

Phase 6B is complete only when:

1. the model is reproducibly generated, loadable, compilable, and structurally verified;
2. both torque-driven Multibody PID runs pass every frozen numerical threshold and unchanged tracking criterion;
3. q, dq, torque, end-effector, saturation, and status evidence is stored in MAT and CSV form;
4. all required figures and the representative animation exist and pass visual QA;
5. all Phase 1–6B tests, static analysis, and public experiments pass from merged `main`;
6. README and verification commands document the exact protocol, results, interpretation, and limitations; and
7. the owned temporary worktree and merged local feature branch are removed without touching the user's DOCX.
