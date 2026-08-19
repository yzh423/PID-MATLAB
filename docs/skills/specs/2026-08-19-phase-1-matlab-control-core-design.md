# Phase 1 MATLAB Control Core Design

## Objective

Build the first verified research slice of the revised robotic-manipulation plan: a pure-MATLAB, modular, deterministic simulation of a planar two-link manipulator controlled by a torque-limited PID controller. The slice must establish trustworthy kinematics, dynamics, trajectory generation, simulation, metrics, tests, and one reproducible nominal experiment before Fuzzy-PID, optimization, Simulink, or robustness sweeps are introduced.

The primary user is Daniel, who must be able to run one command in MATLAB R2026a to reproduce the nominal result and use the same interfaces for later controller and scenario comparisons.

## Assumptions and Decisions

- Project root: `E:\YZH123123\PID vs Fuzzy PID`.
- MATLAB R2026a is the authoritative runtime.
- Phase 1 uses analytical rigid-body equations and pure MATLAB functions.
- Simulink and Simscape Multibody are Phase 2 cross-validation surfaces, not Phase 1 dependencies.
- Fuzzy Logic Toolbox and Global Optimization Toolbox are unavailable.
- A later Fuzzy-PID will use a project-owned Mamdani inference implementation.
- A later optimized PID will use `fmincon` from Optimization Toolbox.
- Robot morphology is a prescribed robustness variable, never an optimization variable in the core project.
- SI units are mandatory: metres, kilograms, seconds, radians, newton-metres.
- Phase 1 uses fixed-step RK4 integration for deterministic behavior and explicit control over sampling.

## Architecture

The core is a MATLAB package named `+rrm` (reliable robotic manipulation). Public functions operate on validated structures and return immutable-by-convention result structures.

```text
Configuration
  robot / trajectory / controller / simulation options
       |
       v
Mathematics
  forward kinematics / inverse kinematics / inertia / Coriolis / gravity
       |
       v
Trajectory
  quintic point-to-point joint reference
       |
       v
Control and Simulation
  PID + anti-windup + torque saturation / RK4 plant propagation
       |
       v
Evaluation
  error, RMS, maximum error, control effort, saturation time, success flag
       |
       v
Experiment
  saved MAT data + deterministic PNG figures + printed summary
```

### Module Boundaries

- `+rrm/+config`: creates and validates robot, controller, and simulation configuration.
- `+rrm/+kinematics`: forward and analytical inverse kinematics for the planar arm.
- `+rrm/+dynamics`: computes `M(q)`, `C(q,dq)`, `G(q)`, and state derivatives.
- `+rrm/+trajectory`: generates position, velocity, and acceleration references.
- `+rrm/+control`: computes saturated PID torque and integral-state update.
- `+rrm/+simulation`: runs deterministic closed-loop RK4 integration.
- `+rrm/+metrics`: evaluates raw and aggregate performance measures.
- `experiments`: orchestration only; no duplicate model or metric formulas.
- `tests`: MATLAB Unit Test files exercising public behavior and physical invariants.

No module may read base-workspace variables or depend on `clear`, `close all`, global state, or current-folder-relative data.

## Mathematical Model

For joint state `q = [q1; q2]`, the plant is

```text
M(q) * ddq + C(q,dq) * dq + G(q) + Fv * dq = tau + disturbance.
```

The implementation uses link length, centre-of-mass distance, mass, planar moment of inertia, gravity, viscous friction, joint limits, and torque limits from one robot configuration structure.

Phase 1 nominal parameters are:

| Parameter | Joint/link 1 | Joint/link 2 |
| --- | ---: | ---: |
| Link length | 0.45 m | 0.35 m |
| Mass | 2.0 kg | 1.5 kg |
| Centre of mass | 0.225 m | 0.175 m |
| Slender-rod inertia | `m1*L1^2/12` | `m2*L2^2/12` |
| Viscous friction | 0.05 N·m·s/rad | 0.04 N·m·s/rad |
| Torque limit | 25 N·m | 15 N·m |

The default payload is 0.5 kg at the second-link endpoint. Its mass contribution is included in inertia and gravity consistently. Joint limits default to `[-170, 170]` degrees for joint 1 and `[-150, 150]` degrees for joint 2.

## Phase 1 Public Interfaces

```matlab
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
simOptions = rrm.config.makeSimulationOptions();

p = rrm.kinematics.forward(robot, q);
[qSolutions, reachable] = rrm.kinematics.inverse(robot, p);

[M, C, G] = rrm.dynamics.matrices(robot, q, dq);
reference = rrm.trajectory.quintic(q0, qf, duration, sampleTime);

result = rrm.simulation.runPid(robot, controller, reference, simOptions);
metrics = rrm.metrics.evaluate(result, robot, simOptions.successCriteria);
```

Angles passed into package functions are radians. Vectors are two-element real finite column vectors. Invalid dimensions, non-finite values, unreachable targets, non-positive timing, and inconsistent reference arrays produce named MATLAB errors.

## Nominal Experiment

The first experiment moves from `[0; 0]` degrees to `[45; 60]` degrees in 3 seconds and holds the terminal target until 5 seconds. The controller is computed at 1 kHz and the plant is propagated with fixed-step RK4 at the same interval.

The experiment must:

1. build all configurations through package factories;
2. run the common simulator;
3. calculate common metrics;
4. save `results/data/nominal_pid.mat`;
5. save joint tracking and torque figures under `results/figures/`;
6. print a compact metric summary;
7. never overwrite source configuration files.

## Commands

Run all tests from PowerShell:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); results=runtests('tests','IncludeSubfolders',true); assertSuccess(results);"
```

Run the nominal experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); addpath(pwd); run('experiments/run_nominal_pid.m');"
```

Run both verification commands:

```powershell
& '.\scripts\verify.ps1'
```

## Project Structure

```text
+rrm/
  +config/
  +control/
  +dynamics/
  +kinematics/
  +metrics/
  +simulation/
  +trajectory/
docs/
  requirements/
  skills/specs/
  skills/plans/
experiments/
results/
  data/
  figures/
scripts/
tests/
```

Generated `results/data/*.mat` and `results/figures/*.png` are ignored by Git except for `.gitkeep` placeholders. Research code, fixed configuration, tests, documentation, and scripts are version controlled.

## Code Style

Functions use lower camel case, structures use descriptive lower camel case fields, constants stay inside configuration factories, and package-qualified calls are preferred over path mutation.

```matlab
function position = forward(robot, q)
arguments
    robot (1,1) struct
    q (2,1) double {mustBeFinite, mustBeReal}
end

position = [
    robot.L1*cos(q(1)) + robot.L2*cos(q(1) + q(2));
    robot.L1*sin(q(1)) + robot.L2*sin(q(1) + q(2))
];
end
```

Each production function has one responsibility, a short help block, argument validation, and no hidden I/O. Experiment scripts may perform file output and plotting.

## Testing Strategy

MATLAB Unit Test is used with test-first red-green-refactor cycles.

### Unit Tests

- Forward kinematics at known configurations.
- Inverse/forward round trip for both elbow branches.
- Unreachable target rejection.
- Inertia matrix symmetry and positive definiteness over representative states.
- Zero-velocity Coriolis matrix behavior.
- Static gravity compensation acceleration near zero.
- Quintic trajectory endpoint position, velocity, and acceleration constraints.
- PID saturation and anti-windup behavior.
- Metric calculations on hand-constructed results.

### Integration Tests

- Nominal simulation produces finite state and torque arrays with consistent dimensions.
- Applied torques never exceed configured limits.
- Joint positions remain within configured limits.
- Terminal tracking meets the Phase 1 success criteria.
- The experiment creates the expected MAT and PNG outputs.

Tests use tolerances derived from numerical scale. They do not assert exact floating-point trajectories when a physical invariant or bounded tolerance is the meaningful requirement.

## Error Handling

- Configuration factories validate physical positivity and vector sizes.
- Inverse kinematics returns `reachable=false` and `NaN(2,2)` for geometrically unreachable points; malformed input still raises an error.
- The simulator raises an error on non-finite state, non-monotonic reference time, inconsistent array dimensions, or initial joint-limit violation.
- A runtime joint-limit violation terminates the trial and records failure rather than silently clipping joint position.
- Torque is explicitly saturated and saturation is recorded for metrics.

## Boundaries

### Always

- Preserve SI units and column-vector conventions.
- Use the same simulation and metric paths for every controller.
- Run focused tests after every increment and the full suite before every commit.
- Record deterministic random seeds when stochastic scenarios are introduced.
- Keep physical, controller, trajectory, and scenario parameters separate.

### Ask First

- Add third-party MATLAB dependencies.
- Change the authoritative dynamic model.
- Change public function signatures after later modules consume them.
- Add hardware communication or external data uploads.

### Never

- Optimize robot morphology in the core project.
- Claim real-robot performance from simulation.
- hide actuator saturation, failed trials, or unstable cases.
- Duplicate formulas across experiment scripts.
- Commit secrets, machine-specific license files, or generated bulk results.

## Phase 1 Success Criteria

- All MATLAB Unit Tests pass with zero failures.
- Forward/inverse kinematics round-trip Cartesian error is at most `1e-10 m` for representative reachable points.
- `M(q)` is symmetric within `1e-12` and has strictly positive eigenvalues for every tested configuration.
- Gravity compensation from rest produces acceleration norm below `1e-10 rad/s^2`.
- Quintic endpoint position error is below `1e-12 rad`; endpoint velocity and acceleration magnitudes are below `1e-10`.
- Nominal simulation contains no non-finite values or joint-limit violations.
- Applied torque stays within configured limits to numerical tolerance.
- Over the final 0.5 seconds, each joint RMS error is below `0.02 rad` and maximum absolute error is below `0.05 rad`.
- `scripts/verify.ps1` runs the full test suite and nominal experiment with exit code 0.
- README documents environment, commands, model scope, repository structure, and honest limitations.

## Deferred Scope

- Custom Mamdani Fuzzy-PID.
- `fmincon` PID tuning and held-out validation.
- Payload, configuration, uncertainty, disturbance, noise, saturation, and combined stress sweeps.
- Cartesian path tracking and simplified pick-and-place.
- Simulink and Simscape Multibody cross-validation.
- Statistical repeated trials, publication figures, report, slides, and application materials.

Each deferred item will receive its own implementation plan after Phase 1 verification.
