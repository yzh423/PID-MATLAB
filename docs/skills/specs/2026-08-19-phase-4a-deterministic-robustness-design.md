# Phase 4A Deterministic Robustness Matrix Design

## Objective

Build a data-driven deterministic robustness framework that runs the manual PID, Mamdani Fuzzy-PID, and optimization-tuned PID under identical prescribed plant and actuator variations. The phase must automate the matrix, save raw results and tables, expose unsuccessful cases, and support defensible controller comparisons without claiming morphology optimization or statistical noise robustness.

Phase 4A deliberately excludes stochastic sensor noise and repeated trials. Those require a separate measurement model and statistical protocol and are assigned to Phase 4B.

## Approved Approach

Use plain scenario structures plus one shared matrix runner.

```text
controller definitions ─┐
                        ├─> runDeterministicMatrix -> per-run records -> tables
scenario definitions ───┘              |                    |
                                       v                    v
                              shared runController     aggregate summaries
```

Alternatives rejected:

- a monolithic experiment script, because it duplicates parameter mutation and makes fairness difficult to audit;
- an object-oriented experiment hierarchy, because thirteen deterministic scenarios do not justify lifecycle classes or inheritance.

## Scope Decomposition

### Phase 4A — This Specification

- prescribed payload, link-length, mass/inertia, disturbance, and actuator-limit changes;
- one deterministic combined-stress case without measurement noise;
- all three verified controllers with frozen settings;
- joint, Cartesian, effort, saturation, recovery, and success metrics;
- raw MAT data, CSV tables, and comparison figures.

### Phase 4B — Deferred

- measured joint position and velocity noise;
- local seeded random streams that do not alter MATLAB global RNG state;
- repeated stochastic trials and task-success rates with uncertainty estimates;
- the final payload + noise + disturbance + saturation combined stress test.

## Controllers

All controllers are frozen before the matrix:

1. Manual PID: `Kp=[120;100]`, `Ki=[40;30]`, `Kd=[25;18]`.
2. Mamdani Fuzzy-PID: Phase 2 rules, scaling, base gains, and gain bounds unchanged.
3. Optimization-tuned PID: `Kp=[240;200]`, `Ki=[79.9554;30.2026]`, `Kd=[29.3133;18.3972]` from the verified Phase 3 run.

`makeOptimizedPidController(robot)` becomes the reproducible factory for the third controller. It stores the Phase 3 multiplier vector and identifies the controller as `optimization-pid` while retaining `type="pid"` so it uses the shared PID step. No optimizer is rerun during robustness evaluation.

Controllers are created from the baseline robot and then held fixed. Changed plant parameters therefore test controller transfer rather than per-scenario retuning. The simulator already applies the minimum of controller and plant torque limits, so actuator-derating scenarios remain physically enforced.

## Robot Configurations

`makeRobot` gains three prescribed names:

| Name | L1 (m) | L2 (m) | m1 (kg) | m2 (kg) | Payload (kg) |
|---|---:|---:|---:|---:|---:|
| `compact` | 0.35 | 0.25 | 2.0 | 1.5 | 0.5 |
| `baseline` | 0.45 | 0.35 | 2.0 | 1.5 | 0.5 |
| `extended` | 0.55 | 0.45 | 2.0 | 1.5 | 0.5 |

Each configuration recomputes `com=[L1;L2]/2` and uniform-link inertias `[m1*L1^2/12;m2*L2^2/12]`. Link configurations are prescribed test cases, never optimization variables.

## Scenario Matrix

Every scenario uses the `[0;0]` to `[45;60] deg` quintic reference, 3 second motion, 2 second hold, 1 ms step, identical initial velocity, and no gravity feedforward.

| Scenario | Category | Exact change |
|---|---|---|
| `nominal` | nominal | baseline robot, 0.5 kg payload |
| `payload-0.0kg` | payload | payload `0.0 kg` |
| `payload-1.0kg` | payload | payload `1.0 kg` |
| `payload-1.5kg` | payload | payload `1.5 kg` |
| `configuration-compact` | configuration | compact robot |
| `configuration-extended` | configuration | extended robot |
| `mass-inertia-minus-20pct` | uncertainty | multiply `m1`, `m2`, and both link inertias by `0.80` |
| `mass-inertia-minus-10pct` | uncertainty | multiply them by `0.90` |
| `mass-inertia-plus-10pct` | uncertainty | multiply them by `1.10` |
| `mass-inertia-plus-20pct` | uncertainty | multiply them by `1.20` |
| `disturbance-pulse` | disturbance | `[4;-3] N m` from `2.00 s` through `2.10 s` |
| `actuator-derated` | actuator | torque limits `[18;10] N m` |
| `combined-deterministic` | combined | extended links, `1.0 kg` payload, `+20%` link mass/inertia, `[18;10] N m` limits, and the same pulse |

There are exactly 13 scenarios and 39 controller-scenario runs. The nominal row is not duplicated in the payload/configuration categories.

## Time-Varying Disturbance Support

`runController` accepts either:

- a constant `2 x 1` `options.disturbanceTorque`, preserving all Phase 1–3 behavior exactly; or
- a `2 x N` history aligned with `reference.time`.

The selected disturbance sample is held constant during all four RK4 sub-evaluations for that integration step. The applied disturbance history is saved in `result.disturbanceTorque`. Invalid shapes or non-finite values raise `rrm:simulation:InvalidDisturbance`.

## Metrics

Each run retains the existing common metrics and adds:

- end-effector RMS Euclidean tracking error in metres;
- maximum end-effector Euclidean tracking error in metres;
- total saturation time across both joints;
- disturbance recovery time, defined only for disturbance scenarios;
- a robustness success flag.

Cartesian errors use analytical forward kinematics for both true and reference joint positions with the scenario plant geometry.

For disturbance recovery, search after the pulse ends for the first continuous `0.10 s` interval during which both joint errors remain within `2 deg`. Recovery time is measured from pulse end. It is `NaN` for scenarios without a pulse and `Inf` if no qualifying interval exists before the experiment ends.

Robustness success requires:

- simulator status `completed`;
- existing Phase 1 steady-state joint criteria;
- maximum end-effector error no greater than `0.15 m`;
- no joint-limit violation.

Saturation is reported but is not itself an automatic failure: the actuator-derating test is intended to reveal whether task success can coexist with temporary saturation.

## New Modules

- `+rrm/+config/makeOptimizedPidController.m`: frozen Phase 3 controller factory.
- `+rrm/+robustness/makeDeterministicScenarios.m`: build and validate the 13 scenarios.
- `+rrm/+robustness/evaluateRun.m`: calculate common, Cartesian, recovery, and robustness-success metrics.
- `+rrm/+robustness/runDeterministicMatrix.m`: fair controller-scenario execution and tabular records.
- `+rrm/+robustness/summarizeMatrix.m`: aggregate controller success, accuracy, effort, saturation, and worst-case values.
- `experiments/run_deterministic_robustness.m`: full matrix, persistence, CSV export, figures, and evidence checks.

## Experiment Outputs

Data:

- `results/data/deterministic_robustness.mat`: controllers, reference, scenarios, all raw results, per-run records, and aggregate records.
- `results/data/deterministic_robustness_runs.csv`: one row per controller-scenario run.
- `results/data/deterministic_robustness_summary.csv`: one row per controller.

Figures:

- `deterministic_robustness_payload.png`: error and effort versus payload;
- `deterministic_robustness_configuration.png`: compact/baseline/extended comparison;
- `deterministic_robustness_uncertainty.png`: error versus mass/inertia scale;
- `deterministic_robustness_disturbance.png`: joint-error norm around the pulse and recovery markers;
- `deterministic_robustness_heatmap.png`: scenario-by-controller normalized RMS error;
- `deterministic_robustness_summary.png`: success count, worst error, and saturation summary.

## Experiment Modes

The public default is `robustnessMode="full"`, which runs all 39 cases and enforces all acceptance criteria. Automated artifact tests use `robustnessMode="smoke"`, containing nominal, disturbance, actuator-derated, and combined scenarios on a shorter trajectory. Smoke mode verifies orchestration and outputs but cannot satisfy or substitute for the full scientific matrix.

## Error Handling

- Scenario validation rejects duplicate names, unknown categories, malformed robots/options, inconsistent disturbance length, or any non-finite physical value.
- Controller definitions reject duplicate labels or missing controller types.
- Every run is retained even when the simulator returns a failure status; the matrix does not abort merely because one scenario is unsuccessful.
- MATLAB execution errors caused by malformed configuration are rethrown with scenario/controller context rather than converted into scientific failure data.
- Aggregation rejects missing controller-scenario pairs and non-finite finite-valued metrics, while permitting documented `NaN` recovery times and `Inf` non-recovery.

## Testing Strategy

### Configuration and Simulation Tests

- Compact and extended link geometry, COM, and inertia are internally consistent.
- Frozen optimized gains exactly match the Phase 3 result.
- Constant disturbance produces results numerically identical to the pre-change simulator.
- A `2 x N` pulse is applied only at selected samples and recorded exactly.
- Invalid disturbance shapes and values are rejected.

### Scenario Tests

- Full mode returns exactly the named 13 scenarios in documented order.
- Every scenario has a finite valid robot and options structure.
- Payload, geometry, uncertainty, torque, and combined changes affect only documented fields.
- The disturbance pulse has exact amplitude and inclusive time window.

### Metric and Runner Tests

- Cartesian errors match hand-calculated forward-kinematics examples.
- Recovery time matches a synthetic error trace and returns `Inf` when recovery never occurs.
- A short matrix creates every controller-scenario pair exactly once and shares references.
- Aggregates match hand-calculated run records.

### Experiment Tests

- Smoke mode produces MAT, two CSV files, and all six figures.
- Saved rows match `scenario count x controller count` and contain no missing pair.
- Full mode checks all 39 rows, all nominal successes, exact controller/scenario labels, and finite reportable metrics.

## Success Criteria

- All 49 Phase 1–3 tests continue to pass.
- New tests pass and production/experiment files produce zero `checkcode` issues.
- Constant-disturbance simulation remains numerically unchanged in all pre-existing result fields.
- The full experiment contains exactly 13 scenarios, 3 frozen controllers, and 39 unique runs.
- All nominal controller runs reproduce Phase 1–3 steady RMS metrics within `1e-10 rad`.
- Every full-matrix run either completes with finite metrics or records a named simulator failure; no row is lost.
- Full outputs contain raw results, reproducible parameters, run/summary CSV tables, and six legible figures.
- Conclusions explicitly report failures, saturation, and metric regressions and do not claim one controller is universally superior.
- `scripts/verify.ps1` exits zero after tests, earlier experiments, and the full deterministic matrix.

## Boundaries

### Always

- Use the same reference, step, initial state, and scenario plant for all three controllers.
- Recompute physical inertia when prescribed link dimensions change.
- Freeze controller settings before robustness runs.
- Store every run and every raw metric.

### Ask First

- Retune any controller for a scenario.
- Change the Phase 1 common success thresholds.
- Add new robot morphologies or decision variables.
- Treat temporary saturation as an automatic task failure.

### Never

- Optimize morphology or controller parameters on the robustness matrix.
- Drop failed or unfavorable cases from tables or plots.
- Present Phase 4A as sensor-noise or stochastic validation.
- Infer hardware safety or universal robustness from simulation.

## Commands

```powershell
# Full test suite and all experiments
& '.\scripts\verify.ps1'

# Full deterministic matrix only
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_deterministic_robustness.m');"
```
