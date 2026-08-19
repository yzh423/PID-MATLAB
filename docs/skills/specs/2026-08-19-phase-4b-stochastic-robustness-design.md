# Phase 4B Stochastic Measurement-Noise Robustness Design

## Objective

Extend the verified Phase 4A framework with a physically distinct measurement-noise model, repeated seeded trials, and uncertainty-aware controller comparisons. The study must quantify sensitivity to joint-angle and joint-velocity noise, control chattering, stochastic task success, and a final noise-inclusive combined stress case without retuning any controller.

Phase 4B is a simulation study. It does not claim hardware sensor fidelity, safety certification, or stochastic robustness outside the prescribed distributions and trajectory.

## Approved Assumptions

1. Noise corrupts controller feedback only. True plant state, reference state, joint-limit checks, and tracking metrics remain noise-free ground truth.
2. Joint-angle and joint-velocity measurement errors are independent, zero-mean, white Gaussian samples. Correlated, biased, quantized, delayed, and band-limited sensors are deferred to hardware or Simulink validation.
3. The three controllers remain frozen at their Phase 4A definitions. No noise-specific filtering, gain changes, or scenario-specific retuning is permitted.
4. All controllers receive the exact same noise realization for a given scenario and trial.
5. Local MATLAB `RandStream` objects generate noise without reading or modifying the global random-number state.
6. Thirty trials per stochastic scenario are sufficient for a first Wilson-interval reliability study, but not for rare-event certification.

## Considered Approaches

### Selected: Independent Gaussian Measurement Histories

Generate complete `2 x N` position and velocity noise histories from a local seeded stream before simulation. This gives transparent units, exact reproducibility, controller-paired trials, simple validation, and no dependency on additional toolboxes.

### Deferred: Band-Limited or Correlated Encoder Model

A filtered-noise, quantization, bias, and latency model would be more representative of a named physical encoder. It requires defensible sensor bandwidth, sampling, quantization, and calibration data that the project does not yet have. Adding arbitrary spectral parameters would create false realism.

### Rejected: Add Noise to the True Plant State

Perturbing the integrated state models process disturbance, not measurement error. It would contaminate ground-truth metrics and make controller sensitivity impossible to separate from plant excitation.

## Architecture

```text
seed + noise specification
          |
          v
makeMeasurementNoise ----> q/dq measurement histories
          |                         |
          |                         v
          +---------------> runController
                                  |
                    true state ---+---> ground-truth metrics
                    measured state+---> frozen controller feedback
                                  |
                                  v
                         per-trial record
                                  |
                                  v
                    Wilson/statistical summary
```

The simulator remains the only plant integration path. Phase 4B adds a measurement boundary before `pidStep` or `fuzzyPidStep`; it does not duplicate controller or dynamics code. Stochastic orchestration remains in `+rrm/+robustness`, while file output and figures remain in an experiment script.

## Measurement Interface

`options.measurementNoise` is optional. When absent, `runController` expands zero histories and preserves every pre-existing numeric result exactly.

When present it must contain:

```matlab
options.measurementNoise = struct( ...
    "position", positionNoise, ... % rad, 2 x N
    "velocity", velocityNoise);    % rad/s, 2 x N
```

At sample `k`:

```matlab
qMeasured(:,k) = q(:,k) + positionNoise(:,k);
dqMeasured(:,k) = dq(:,k) + velocityNoise(:,k);
```

The measured values go only to the controller update. Plant integration starts from the true state and uses the applied torque and existing disturbance history. The result records `qMeasured`, `dqMeasured`, and the expanded measurement-noise structure.

Malformed, complex, non-finite, or non-`2 x N` histories raise `rrm:simulation:InvalidMeasurementNoise` before the first integration step.

## Local Noise Generation

`rrm.robustness.makeMeasurementNoise(spec,sampleCount,seed)` constructs a local MT19937 stream and returns position and velocity histories. It validates nonnegative finite `2 x 1` standard deviations, positive integer sample count, and a nonnegative integer seed.

```matlab
stream = RandStream("mt19937ar","Seed",seed);
position = spec.positionStd .* randn(stream,2,sampleCount);
velocity = spec.velocityStd .* randn(stream,2,sampleCount);
```

The function must not call `rng`, `randn` without the local stream, or otherwise change global state. Repeated calls with the same inputs are bitwise identical. Different seeds must produce different histories.

## Frozen Controllers

1. Manual PID: `Kp=[120;100]`, `Ki=[40;30]`, `Kd=[25;18]`.
2. Mamdani Fuzzy-PID: unchanged Phase 2 rules, scaling, gain bounds, derivative filtering, saturation, and anti-windup.
3. Optimization PID: `Kp=[240;200]`, `Ki=[79.9554;30.2026]`, `Kd=[29.3133;18.3972]`.

All controllers are created from the baseline robot once and reused. The optimization routine is never rerun.

## Stochastic Scenario Matrix

All cases use the Phase 4A reference: `[0;0]` to `[45;60] deg`, 3 s motion, 2 s hold, and 1 ms sample time.

| Scenario | Position standard deviation | Velocity standard deviation | Other stress |
|---|---:|---:|---|
| `noise-low` | `0.05 deg` per joint | `0.5 deg/s` per joint | baseline plant |
| `noise-medium` | `0.20 deg` per joint | `2.0 deg/s` per joint | baseline plant |
| `noise-high` | `0.50 deg` per joint | `5.0 deg/s` per joint | baseline plant |
| `combined-stochastic` | `0.20 deg` per joint | `2.0 deg/s` per joint | extended links, 1.0 kg payload, +20% link mass/inertia, `[18;10] N m` limits, `[4;-3] N m` pulse from 2.00 through 2.10 s |

Full mode uses seeds `42001:42030` for every scenario. Reusing the same seed set makes controller comparisons paired and makes the three noise levels scaled versions of the same underlying standard-normal draws. The combined scenario shares the medium-noise realization for each trial.

There are exactly `4 scenarios x 30 trials x 3 controllers = 360` stochastic runs. A separate three-run noise-free nominal reference is generated for plots and validation but is not counted as a stochastic trial.

Smoke mode uses `noise-medium` and `combined-stochastic`, seeds `42001:42002`, and all controllers, giving 12 stochastic runs. It verifies orchestration and artifacts but is not scientific evidence.

## Per-Trial Metrics

Every trial retains the Phase 4A metrics and adds:

- joint tracking-error variance in `rad^2`, computed from true reference minus true plant state;
- applied-torque slew RMS in `N m/s`, computed per joint from `diff(tau)/sampleTime`;
- position and velocity noise standard deviations;
- scenario name, controller name, trial number, and seed.

Success uses the unchanged Phase 4A definition: completed status, existing steady-state joint thresholds, maximum true end-effector error no greater than `0.15 m`, and no joint-limit violation. Noisy measurements are never used to decide tracking success directly.

## Statistical Summary

One row per scenario-controller pair reports:

- trial count, success count, and success rate;
- two-sided 95% Wilson score interval using `z=1.95996398454005`;
- mean and standard deviation of joint RMS error;
- mean and 95th-percentile end-effector maximum error;
- mean tracking-error variance;
- mean torque-slew RMS;
- mean and worst total saturation time;
- worst finite recovery time and non-recovery count for the combined case.

Percentiles use a documented nearest-rank implementation so Statistics and Machine Learning Toolbox is not required. `NaN` recovery remains valid for no-pulse scenarios and `Inf` denotes non-recovery.

No hypothesis-test p-values or universal ranking claims are added. Thirty trials support descriptive uncertainty estimates, not broad population inference.

## Data Retention

Saving all diagnostic histories for 360 runs would create an unnecessarily large MAT file. Phase 4B therefore stores:

- every trial's complete scalar/vector metrics, seed, status, and success in a table;
- all scenario and controller definitions;
- one complete representative run per scenario-controller pair, using trial 1;
- the noise-free nominal reference runs;
- the aggregate summary table.

Any non-representative history is exactly reconstructible from its saved scenario, controller, seed, and reference.

## New Modules

- `+rrm/+robustness/makeMeasurementNoise.m`: local deterministic noise generation.
- `+rrm/+robustness/makeStochasticScenarios.m`: four prescribed stochastic scenarios and smoke subset.
- `+rrm/+robustness/evaluateStochasticRun.m`: Phase 4A metrics plus variance and torque slew.
- `+rrm/+robustness/runStochasticStudy.m`: paired trial execution and representative-history retention.
- `+rrm/+robustness/summarizeStochasticStudy.m`: Wilson intervals and descriptive statistics.
- `experiments/run_stochastic_robustness.m`: full orchestration, persistence, assertions, console output, and figures.

## Experiment Outputs

Data:

- `results/data/stochastic_robustness.mat`
- `results/data/stochastic_robustness_trials.csv`
- `results/data/stochastic_robustness_summary.csv`

Figures:

- `stochastic_robustness_success.png`: success rates with Wilson intervals;
- `stochastic_robustness_accuracy.png`: tracking error versus noise level with nominal reference;
- `stochastic_robustness_chattering.png`: torque slew versus noise level;
- `stochastic_robustness_saturation.png`: mean and worst saturation by scenario;
- `stochastic_robustness_combined.png`: combined-stress success and worst error;
- `stochastic_robustness_representative.png`: trial-1 measured/true error and torque histories.

Generated MAT, CSV, and PNG files remain excluded from Git.

## Error Handling

- Scenario construction rejects duplicate names, invalid noise deviations, malformed physical fields, or a disturbance length inconsistent with the reference.
- Trial execution rejects duplicate controller labels, duplicate seeds, or empty seed lists.
- A simulator scientific failure remains a recorded trial and does not abort the study.
- Configuration or programming errors are rethrown with scenario, controller, trial, and seed context.
- Aggregation rejects missing or duplicate scenario-controller-trial combinations and non-finite metrics where finiteness is required.

## Code Style

Package functions are deterministic and do no file I/O:

```matlab
noise = rrm.robustness.makeMeasurementNoise( ...
    scenario.noise,numel(reference.time),seed);
options = scenario.options;
options.measurementNoise = noise;
result = rrm.simulation.runController( ...
    scenario.robot,definition.controller,reference,options);
```

Names use MATLAB string scalars, numeric histories use columns for joints and columns in time, and physical units appear in field comments, labels, and tables.

## Testing Strategy

### Simulator Tests

- absent noise and explicit zero noise produce identical complete results;
- a prescribed measurement history reaches the controller while the true initial state remains unchanged;
- result histories record measured values and noise exactly;
- invalid shape, complex values, and `NaN` are rejected before integration.

### Noise Generator Tests

- same seed gives exact equality;
- different seed changes the histories;
- requested per-joint scaling is exact relative to the underlying draws;
- global RNG state is unchanged;
- invalid standard deviations, sample counts, and seeds are rejected.

### Scenario and Metric Tests

- full and smoke modes contain the exact documented names, seed counts, noise levels, and combined physical mutations;
- hand-calculated tracking variance and torque-slew RMS match synthetic results.

### Runner and Summary Tests

- a short two-controller, two-scenario, two-seed study creates every pair exactly once;
- controllers share identical noise histories for each scenario-seed pair;
- only trial 1 retains representative full histories;
- Wilson intervals, nearest-rank percentiles, success rates, means, worst values, and non-recovery counts match synthetic tables.

### Experiment Tests

- smoke mode writes one MAT, two CSV, and six PNG files;
- saved smoke tables contain exactly 12 unique trials and six summary rows;
- full mode contains exactly 360 unique trial rows and 12 summary rows;
- all reportable metrics are finite except documented recovery `NaN`/`Inf` values;
- all noise-free nominal reference controllers pass.

## Commands

```powershell
# Full Phase 1-4B verification
& '.\scripts\verify.ps1'

# Full stochastic study only
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_stochastic_robustness.m');"

# All unit tests
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests('tests','IncludeSubfolders',true); assertSuccess(results);"
```

## Success Criteria

- All 66 Phase 1-4A tests continue to pass.
- New behavior is covered by witnessed RED-to-GREEN tests.
- No-noise simulation preserves all pre-existing numeric fields exactly.
- Local noise generation does not alter MATLAB global RNG state.
- Full output contains exactly 360 unique stochastic trials and 12 scenario-controller summaries.
- The same scenario-seed pair uses bitwise-identical noise for all three controllers.
- Trial and summary tables retain failures, saturation, and non-recovery.
- One complete representative history exists for every scenario-controller pair.
- MAT, CSV, and six legible figures are generated reproducibly.
- Production and experiment files have zero `checkcode` issues.
- `scripts/verify.ps1` exits zero after tests and all Phase 1-4B experiments.

## Boundaries

### Always

- Keep controller gains and success thresholds frozen.
- Use true state for dynamics, safety checks, and evaluation.
- Pair controllers on the same noise realization.
- Preserve seeds and unfavorable trials.
- Use local random streams only.

### Ask First

- Change noise distributions, amplitudes, trial count, seed schedule, or success thresholds.
- Add filtering or retune a controller for noise.
- Replace descriptive intervals with formal hypothesis testing.
- Save every full diagnostic history and substantially increase artifact size.

### Never

- Modify global RNG state from package code.
- Drop failed trials or seeds from statistics.
- Treat measurement noise as true plant motion.
- Claim the Gaussian white-noise model represents a specific physical sensor.
- Claim hardware safety, rare-event reliability, or universal controller superiority.

## Deferred Work

- encoder quantization, bias, drift, latency, packet loss, and colored spectra;
- sensor filtering or observer design;
- named-sensor calibration from hardware data;
- Simulink/Simscape cross-validation;
- Cartesian task execution and simplified pick-and-place;
- formal paired hypothesis tests or rare-event reliability studies.
