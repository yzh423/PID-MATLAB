# Phase 4B Stochastic Measurement-Noise Robustness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add reproducible measurement-noise feedback, 360 paired stochastic trials, Wilson reliability intervals, chattering metrics, and complete Phase 4B evidence for the three frozen controllers.

**Architecture:** Extend the shared simulator with an optional measurement boundary while preserving the true plant state and all no-noise results. Generate histories from local seeded streams, run paired trials through one stochastic orchestrator, retain every trial metric plus representative traces, and aggregate descriptive statistics without requiring Statistics and Machine Learning Toolbox.

**Tech Stack:** MATLAB R2026a, MATLAB Unit Test, local `RandStream`, existing `+rrm` simulation and robustness packages, CSV/MAT export, Git.

## Global Constraints

- Noise affects controller feedback only; true state remains the plant and metric ground truth.
- Controllers, success criteria, reference, and Phase 4A deterministic scenarios remain frozen.
- Full mode contains exactly 4 scenarios, 30 seeds, 3 controllers, and 360 stochastic trials.
- Full seeds are exactly `42001:42030`; controllers share bitwise-identical noise within each scenario-seed pair.
- Full noise levels are exactly `0.05/0.5`, `0.20/2.0`, and `0.50/5.0` degrees and degrees per second.
- Package code uses only local random streams and performs no file I/O.
- Every production change follows a witnessed RED-to-GREEN cycle and an atomic commit.
- Failed, saturated, and unrecovered trials remain in saved data and statistics.
- Generated MAT, CSV, and PNG artifacts remain ignored by Git.

---

### Task 1: Optional Measurement-Noise Boundary in the Shared Simulator

**Files:**
- Modify: `+rrm/+simulation/runController.m`
- Modify: `tests/simulation/TestRunController.m`

**Interfaces:**
- Consumes optional `options.measurementNoise.position` in rad and `.velocity` in rad/s, both finite real `2 x N`.
- Produces `result.qMeasured`, `result.dqMeasured`, and `result.measurementNoise` for every run.

- [ ] **Step 1: Write failing no-noise compatibility and recording tests.**

```matlab
withoutNoise = rrm.simulation.runController(robot,controller,reference,options);
options.measurementNoise = struct( ...
    "position",zeros(2,numel(reference.time)), ...
    "velocity",zeros(2,numel(reference.time)));
withZeros = rrm.simulation.runController(robot,controller,reference,options);
testCase.verifyEqual(withoutNoise,withZeros);
testCase.verifyEqual(withZeros.qMeasured,withZeros.q);
testCase.verifyEqual(withZeros.dqMeasured,withZeros.dq);
```

Add a prescribed nonzero first-sample measurement test using a PID controller with `Ki=0`, `Kd=0`, and large torque limits. Require the recorded measurement and first unsaturated torque to use the noisy error while `result.q(:,1)` remains the reference initial state.

- [ ] **Step 2: Write failing invalid-input tests.** Require `rrm:simulation:InvalidMeasurementNoise` for `2 x (N-1)`, `NaN`, complex, missing-position, and missing-velocity inputs.
- [ ] **Step 3: Run the focused test and verify RED.**

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests('tests/simulation/TestRunController.m'); assertSuccess(results);"
```

- [ ] **Step 4: Implement validation, zero expansion, and measured feedback.** Before allocation, create zero histories when the field is absent. At every sample, calculate measured state before `controllerStep`; continue integrating the true state.
- [ ] **Step 5: Run focused and full tests; require GREEN and exact no-noise equality.**
- [ ] **Step 6: Commit** as `feat: add measurement-noise simulation boundary`.

### Task 2: Local Seeded Noise Generator

**Files:**
- Create: `+rrm/+robustness/makeMeasurementNoise.m`
- Create: `tests/robustness/TestMakeMeasurementNoise.m`

**Interfaces:**
- `noise = rrm.robustness.makeMeasurementNoise(spec,sampleCount,seed)`.
- `spec.positionStd` and `spec.velocityStd` are finite nonnegative `2 x 1` values.
- Output fields are `position`, `velocity`, and `seed`.

- [ ] **Step 1: Write failing reproducibility tests.** Require exact same-seed equality, inequality for different seeds, `2 x N` sizes, zero standard deviation producing exact zeros, and correct joint scaling when the same seed is regenerated with doubled standard deviations.
- [ ] **Step 2: Write a failing global-state preservation test.**

```matlab
rng(173,"twister");
stateBefore = rng;
rrm.robustness.makeMeasurementNoise(spec,25,42001);
stateAfter = rng;
testCase.verifyEqual(stateAfter,stateBefore);
```

- [ ] **Step 3: Add failing validation tests** for negative/`NaN` deviations, noninteger or zero sample count, and negative/noninteger seed. Require `rrm:robustness:InvalidNoiseSpecification` or `rrm:robustness:InvalidSeed`.
- [ ] **Step 4: Verify RED**, then implement with `RandStream("mt19937ar","Seed",seed)` and stream-qualified `randn` calls only.
- [ ] **Step 5: Run focused and full tests; require GREEN.**
- [ ] **Step 6: Commit** as `feat: generate local seeded measurement noise`.

### Task 3: Prescribed Stochastic Scenarios

**Files:**
- Create: `+rrm/+robustness/makeStochasticScenarios.m`
- Create: `tests/robustness/TestMakeStochasticScenarios.m`

**Interfaces:**
- `scenarios = rrm.robustness.makeStochasticScenarios(reference,baseOptions,mode)` where mode is `"full"` or `"smoke"`.
- Each scenario has `name`, `category`, `robot`, `options`, `noise`, `seeds`, `disturbanceWindow`, `recoveryBand`, and `recoveryDwell`.

- [ ] **Step 1: Write failing full-mode tests** requiring ordered names `noise-low`, `noise-medium`, `noise-high`, `combined-stochastic`; 30 seeds equal to `42001:42030`; and exact radian noise deviations.
- [ ] **Step 2: Write failing combined-case tests.** Require extended geometry, payload `1.0`, mass/inertia scale `1.2`, limits `[18;10]`, inclusive `[4;-3]` pulse at 2.00–2.10 s, and medium noise.
- [ ] **Step 3: Write a failing smoke test** requiring names `noise-medium`, `combined-stochastic` and seeds `42001:42002`.
- [ ] **Step 4: Verify RED**, then implement a plain validated struct factory. Reuse the Phase 4A physical values; do not call the deterministic factory and mutate private internals.
- [ ] **Step 5: Run focused and full tests; require GREEN.**
- [ ] **Step 6: Commit** as `feat: define stochastic robustness scenarios`.

### Task 4: Stochastic Per-Trial Metrics

**Files:**
- Create: `+rrm/+robustness/evaluateStochasticRun.m`
- Create: `tests/robustness/TestEvaluateStochasticRun.m`

**Interfaces:**
- `metrics = rrm.robustness.evaluateStochasticRun(result,robot,criteria,scenario)`.
- Output contains `robustness`, `trackingErrorVariance`, `torqueSlewRms`, and `torqueSlewMean`.

- [ ] **Step 1: Write a failing hand-calculated variance test.** Use a four-sample true tracking-error history and compare `var(reference-result.q,0,2)` exactly.
- [ ] **Step 2: Write a failing torque-slew test.** For `time=[0;0.1;0.2]` and known torque steps, require:

```matlab
expected = sqrt(mean((diff(result.tau,1,2)/0.1).^2,2));
testCase.verifyEqual(metrics.torqueSlewRms,expected,"AbsTol",1e-12);
testCase.verifyEqual(metrics.torqueSlewMean,mean(expected),"AbsTol",1e-12);
```

- [ ] **Step 3: Verify RED**, implement by delegating all Phase 4A fields and success to `evaluateRun`, and calculate stochastic additions only over finite completed samples.
- [ ] **Step 4: Test malformed time grids and fewer than two finite samples**, requiring `rrm:robustness:InvalidStochasticResult`.
- [ ] **Step 5: Run focused and full tests; require GREEN.**
- [ ] **Step 6: Commit** as `feat: add stochastic noise and chattering metrics`.

### Task 5: Paired Repeated-Trial Runner

**Files:**
- Create: `+rrm/+robustness/runStochasticStudy.m`
- Create: `tests/robustness/TestRunStochasticStudy.m`

**Interfaces:**
- `study = rrm.robustness.runStochasticStudy(controllerDefinitions,scenarios,reference,criteria)`.
- Produces `study.table` with one row per trial and `study.representativeRuns` with trial-1 full histories.

- [ ] **Step 1: Write a failing 2-controller x 2-scenario x 2-seed test** requiring eight unique `Scenario|Controller|Trial|Seed` rows, four representative histories, exact controller labels, and retained status/success.
- [ ] **Step 2: Add a failing fairness test.** For every scenario-seed pair, compare `representative` or reconstructed `measurementNoise` histories across controllers with zero tolerance.
- [ ] **Step 3: Add failing validation tests** for duplicate controller labels, duplicate scenario names, duplicate seeds, empty seeds, and missing controller type.
- [ ] **Step 4: Verify RED**, then implement scenario-first, seed-second, controller-third execution so the noise history is generated once and shared by all controllers.
- [ ] **Step 5: Build the trial table** with scenario/controller/trial/seed/status/success, Phase 4A metrics, error variance, torque slew, noise levels, payload, uncertainty scale, and torque scale.
- [ ] **Step 6: Run focused and full tests; require GREEN.**
- [ ] **Step 7: Commit** as `feat: run paired stochastic robustness trials`.

### Task 6: Wilson and Descriptive Aggregation

**Files:**
- Create: `+rrm/+robustness/summarizeStochasticStudy.m`
- Create: `tests/robustness/TestSummarizeStochasticStudy.m`

**Interfaces:**
- `summary = rrm.robustness.summarizeStochasticStudy(trialTable)`.
- Stable output order follows first scenario occurrence and first controller occurrence.

- [ ] **Step 1: Write a failing synthetic aggregation test** with known successes, RMS values, saturation, and recovery values. Require exact counts, rates, mean/std, worst values, and non-recovery count.
- [ ] **Step 2: Write a failing Wilson test.** For `5/10`, require the interval calculated from:

```matlab
z = 1.95996398454005;
center = (0.5 + z^2/(2*10))/(1 + z^2/10);
half = z*sqrt(0.5*0.5/10 + z^2/(4*10^2))/(1 + z^2/10);
```

- [ ] **Step 3: Write a failing nearest-rank 95th-percentile test** requiring sorted index `ceil(0.95*n)` with a lower bound of one.
- [ ] **Step 4: Verify RED**, implement grouping, Wilson bounds clamped to `[0,1]`, and documented recovery handling.
- [ ] **Step 5: Reject missing/duplicate trial combinations and invalid required metrics** with `rrm:robustness:InvalidStochasticTrialTable`.
- [ ] **Step 6: Run focused and full tests; require GREEN.**
- [ ] **Step 7: Commit** as `feat: summarize stochastic reliability statistics`.

### Task 7: Full Stochastic Experiment and Artifacts

**Files:**
- Create: `experiments/run_stochastic_robustness.m`
- Create: `tests/experiments/TestStochasticRobustness.m`

**Interfaces:**
- Public default `stochasticMode="full"`; automated artifact test sets `stochasticMode="smoke"`.
- Writes one MAT, two CSV, and six PNG files named in the design specification.

- [ ] **Step 1: Write the failing smoke artifact test.** Require all nine files, 12 unique trial rows, six summary rows, four representative histories, three successful noise-free nominal reference runs, and saved mode `"smoke"`.
- [ ] **Step 2: Verify RED**, then implement baseline controller definitions, noise-free nominal reference runs, stochastic scenarios, runner, summary, and persistence.
- [ ] **Step 3: Add six figures** for Wilson success, accuracy, torque slew, saturation, combined stress, and representative measured/true/torque histories. Every axis must include units and unfavorable results.
- [ ] **Step 4: Add full-mode assertions** for 360 unique trials, 12 summary rows, exact seeds and labels, representative count 12, global RNG preservation around orchestration, and finite reportable metrics.
- [ ] **Step 5: Run the smoke experiment test; require GREEN.**
- [ ] **Step 6: Run the full experiment separately** and record exact success intervals, failures, chattering, saturation, and combined non-recovery without changing severities after seeing results.
- [ ] **Step 7: Run the full test suite; require GREEN.**
- [ ] **Step 8: Commit** as `feat: add stochastic robustness study`.

### Task 8: Verification and Evidence Documentation

**Files:**
- Modify: `scripts/verify.ps1`
- Modify: `README.md`

**Interfaces:**
- One verification command runs all tests and Phase 1-4B public experiments.

- [ ] **Step 1: Extend verification** after Phase 4A with:

```matlab
clear outputRoot stochasticMode stochasticReference;
run('experiments/run_stochastic_robustness.m');
```

- [ ] **Step 2: Document** the measurement boundary, exact noise levels/seeds/trial counts, statistical definitions, full result table, controller tradeoffs, combined failures, artifact paths, reproduction command, and deferred sensor realism.
- [ ] **Step 3: Run `checkcode`** over `+rrm/**/*.m` and `experiments/*.m`; require zero issues.
- [ ] **Step 4: Run `scripts/verify.ps1`** and require exit zero.
- [ ] **Step 5: Inspect all six Phase 4B figures** for legible labels, common scales, Wilson bars, visible failed cases, and representative noisy measurements.
- [ ] **Step 6: Run `git diff --check`, inspect staged scope, and commit** as `docs: document stochastic robustness evidence`.

### Task 9: Integration

- [ ] **Step 1: Confirm the feature branch is clean** and contains atomic Task 1-8 commits.
- [ ] **Step 2: Fast-forward merge** `feature/phase-4b-stochastic-robustness` into local `main` under the user's standing local-merge authorization. Do not pull, push, or open a PR.
- [ ] **Step 3: Run merged-main full verification and zero-issue `checkcode`.**
- [ ] **Step 4: Remove only the owned `.worktrees/phase-4b-stochastic-robustness` worktree and merged local branch; preserve the unrelated root DOCX.
- [ ] **Step 5: Report** test count, 360-run success/Wilson summary, noise sensitivity, chattering, combined failures, artifacts, merge commit, and deferred hardware-sensor work.

## Plan Self-Review

- Every design requirement maps to Tasks 1-8, including local RNG isolation, paired noise, metrics, 360 trials, representative retention, Wilson intervals, artifacts, and documentation.
- Interfaces use consistent field names: `position`, `velocity`, `qMeasured`, `dqMeasured`, `trackingErrorVariance`, `torqueSlewRms`, and `representativeRuns`.
- Full and smoke row counts are consistent across factory, runner, experiment, tests, and acceptance criteria.
- No task adds filtering, controller retuning, toolbox dependencies, hypothesis testing, or hardware claims.
