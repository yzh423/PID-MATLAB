# Phase 3 Optimization-Assisted PID Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver reproducible six-gain `fmincon` tuning on the nominal robot and fair frozen-gain validation on an unseen payload.

**Architecture:** Represent decision variables as six bounded multipliers around the manual PID, score every shared-simulator result with one dimensionless objective, and isolate solver orchestration from scoring. The experiment owns training/validation scenarios, persistence, tables, and figures.

**Tech Stack:** MATLAB R2026a, Optimization Toolbox `fmincon`, MATLAB Unit Test, existing `+rrm` simulator and metrics, Git.

## Global Constraints

- Optimize PID gains only; never include robot morphology or held-out data in the objective.
- Decision order is `[Kp1;Kp2;Ki1;Ki2;Kd1;Kd2]` multipliers.
- Use bounds `[0.5;0.5;0.25;0.25;0.5;0.5]` to `2*ones(6,1)` and initial point `ones(6,1)`.
- Use the documented dimensionless objective weights `[0.50,0.10,0.15,0.25]`, saturation multiplier `100`, and failure penalty `100`.
- Training payload is exactly `0.5 kg`; validation payload is exactly `0.8 kg` and uses frozen gains.
- Add no third-party or Global Optimization Toolbox dependency.
- Every production change follows a focused RED→GREEN cycle and an atomic commit.

---

### Task 1: Optimization Configuration and Gain Mapping

**Files:**
- Create: `+rrm/+config/makePidOptimization.m`
- Create: `+rrm/+optimization/applyPidMultipliers.m`
- Create: `tests/config/TestMakePidOptimization.m`
- Create: `tests/optimization/TestApplyPidMultipliers.m`

**Interfaces:**
- Produces: `configuration = rrm.config.makePidOptimization(baseController)`.
- Produces: `controller = rrm.optimization.applyPidMultipliers(baseController,multipliers,configuration)`.

- [ ] **Step 1: Write configuration and mapping tests** asserting exact variable order, initial point, lower/upper bounds, objective weights, solver settings, gain mapping, and preservation of `type`, torque limits, filtering, and anti-windup.

```matlab
configuration = rrm.config.makePidOptimization(baseController);
testCase.verifyEqual(configuration.initialMultipliers,ones(6,1));
testCase.verifyEqual(configuration.lowerBounds,[.5;.5;.25;.25;.5;.5]);
tuned = rrm.optimization.applyPidMultipliers( ...
    baseController,[2;.5;1.5;.25;1;2],configuration);
testCase.verifyEqual(tuned.Kp,baseController.Kp.*[2;.5]);
testCase.verifyEqual(tuned.Ki,baseController.Ki.*[1.5;.25]);
testCase.verifyEqual(tuned.Kd,baseController.Kd.*[1;2]);
```

- [ ] **Step 2: Verify RED**

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); r=runtests({'tests/config/TestMakePidOptimization.m','tests/optimization/TestApplyPidMultipliers.m'}); assertSuccess(r);"
```

Expected: missing-function failures for both new public functions.

- [ ] **Step 3: Implement exact configuration and mapping** with named errors `rrm:optimization:InvalidMultipliers`, `rrm:optimization:MultiplierOutOfBounds`, and `rrm:optimization:InvalidConfiguration`. Store solver settings as plain serializable fields rather than an `optimoptions` object.
- [ ] **Step 4: Run focused tests and the full suite; require GREEN.**
- [ ] **Step 5: Commit** as `feat: add bounded PID optimization configuration`.

### Task 2: Pure Objective Scoring

**Files:**
- Create: `+rrm/+optimization/scorePidResult.m`
- Create: `tests/optimization/TestScorePidResult.m`

**Interfaces:**
- Produces: `[objective,components] = rrm.optimization.scorePidResult(result,robot,reference,configuration)`.
- `components` contains `trackingRms`, `overshoot`, `torqueRms`, `settlingTime`, `saturationFraction`, `failurePenalty`, `weighted`, and `total`.

- [ ] **Step 1: Write hand-calculated tests** using short synthetic time series for increasing and decreasing motion, including this no-error/no-torque case:

```matlab
reference = struct("time",(0:4).',"q",[zeros(1,5);zeros(1,5)], ...
    "dq",zeros(2,5),"ddq",zeros(2,5));
reference.q(:,end) = [1;-2];
result = struct("time",reference.time,"q",reference.q, ...
    "qReference",reference.q,"tau",zeros(2,5), ...
    "saturated",false(2,5),"status","completed", ...
    "completedSamples",5);
```

Also assert exact `+100` saturation contribution for `S=1`, exact failed-status penalty, rejection of zero travel, and finite scoring of partially non-finite failed runs.

- [ ] **Step 2: Verify RED** for `tests/optimization/TestScorePidResult.m`.
- [ ] **Step 3: Implement scoring** using valid samples only, directional overshoot, last-outside-band settling, normalized torque, weighted terms, saturation fraction, and finite failure penalties.
- [ ] **Step 4: Run focused tests and full suite; require GREEN.**
- [ ] **Step 5: Commit** as `feat: add reproducible PID optimization objective`.

### Task 3: Deterministic fmincon Orchestration

**Files:**
- Create: `+rrm/+optimization/tunePid.m`
- Create: `tests/optimization/TestTunePid.m`

**Interfaces:**
- Produces: `report = rrm.optimization.tunePid(robot,baseController,reference,simulationOptions,configuration)`.
- `report` contains `initialMultipliers`, `finalMultipliers`, `initialObjective`, `finalObjective`, `controller`, `exitFlag`, `solverOutput`, and a struct-array `history` with multipliers, objective, status, and components.

- [ ] **Step 1: Write a real-solver smoke test** with a 0.20 s trajectory, configuration overrides of 2 iterations and 12 evaluations, and assertions for finite bounded output, non-empty history, successful independent final simulation, and exact reproducibility across two runs within `1e-10`.

```matlab
configuration.solver.maxIterations = 2;
configuration.solver.maxFunctionEvaluations = 12;
report = rrm.optimization.tunePid( ...
    robot,baseController,reference,simulationOptions,configuration);
testCase.verifyGreaterThanOrEqual(report.finalMultipliers, ...
    configuration.lowerBounds);
testCase.verifyLessThanOrEqual(report.finalMultipliers, ...
    configuration.upperBounds);
```

- [ ] **Step 2: Verify RED** because `tunePid` is missing.
- [ ] **Step 3: Implement dependency/configuration validation**, construct `optimoptions` from serializable fields, run bounded SQP with no nonlinear constraints, log each evaluation, and independently resimulate/rescore the selected gains.
- [ ] **Step 4: Run focused test twice and full suite; require GREEN and deterministic results.**
- [ ] **Step 5: Commit** as `feat: add deterministic fmincon PID tuning`.

### Task 4: Nominal Training and Held-Out Payload Experiment

**Files:**
- Create: `experiments/run_pid_optimization.m`
- Create: `tests/experiments/TestPidOptimization.m`

**Interfaces:**
- Produces: `results/data/pid_optimization.mat` and five `pid_optimization_*.png` figures.

- [ ] **Step 1: Write the experiment test** using `outputRoot=tempname`; require the MAT file and objective/nominal-tracking/nominal-torque/validation-tracking/gains figures.
- [ ] **Step 2: Add saved-data assertions** for exact 0.5/0.8 kg separation, common references, in-bound gains, at least 2% nominal objective improvement, nominal success with zero saturation, and held-out success/zero saturation/mean RMS ratio at most 1.10.
- [ ] **Step 3: Verify RED** because the experiment script is missing.
- [ ] **Step 4: Implement the experiment** with manual initial scoring, `tunePid`, independent nominal comparison, frozen-gain 0.8 kg runs, common metrics, saved solver evidence, printed tables, and consistently scaled figures.
- [ ] **Step 5: Run the focused experiment test.** If a fixed acceptance criterion fails, improve objective normalization, solver budget, or multiplier bounds only through a design-spec update; never tune on the validation payload or relax the acceptance assertion after seeing it.
- [ ] **Step 6: Run the full suite; require GREEN.**
- [ ] **Step 7: Commit** as `feat: add PID optimization and held-out validation`.

### Task 5: Verification and Documentation

**Files:**
- Modify: `scripts/verify.ps1`
- Modify: `README.md`

**Interfaces:**
- Verification runs all tests and all Phase 1–3 experiments.

- [ ] **Step 1: Extend verification** with:

```matlab
clear outputRoot;
run('experiments/run_pid_optimization.m');
```

- [ ] **Step 2: Document** objective equations, multiplier and physical bounds, SQP settings, final gains, nominal/held-out metrics, reproduction commands, saved artifacts, tradeoffs, and the single-held-out-case limitation.
- [ ] **Step 3: Run `checkcode`** across every `+rrm/**/*.m` and `experiments/*.m`; require zero issues.
- [ ] **Step 4: Run `scripts/verify.ps1`** from the feature worktree and require exit code zero.
- [ ] **Step 5: Visually inspect all five Phase 3 figures** for labels, units, legends, common axes, complete objective history, and non-misleading scaling.
- [ ] **Step 6: Run `git diff --check` and inspect scope.**
- [ ] **Step 7: Commit** as `docs: document verified PID optimization study`.

### Task 6: Integration

- [ ] **Step 1: Confirm a clean feature branch** with all Task 1–5 commits.
- [ ] **Step 2: Fast-forward merge** `feature/phase-3-pid-optimization` into local `main` without rewriting history.
- [ ] **Step 3: Run full verification on merged `main`**, plus zero-issue `checkcode`.
- [ ] **Step 4: Remove only the owned `.worktrees/phase-3-pid-optimization` worktree and merged local branch; preserve the unrelated untracked DOCX.**
- [ ] **Step 5: Report** exact test count, solver termination, initial/final objective, final gains, nominal and held-out metrics, saturation, artifact paths, and merge state. Do not push or open a PR.

## Plan Self-Review

- Tasks cover every architecture, objective, protocol, error-handling, output, and acceptance item in the Phase 3 specification.
- Interfaces are consistent: configuration → multiplier mapping/scoring → solver report → experiment artifacts.
- The held-out payload appears only in Task 4 after tuning and never enters `tunePid`.
- Every behavior change has a focused expected failure, implementation step, verification command, and atomic commit.
- Deferred robustness matrices, Fuzzy-PID optimization, alternate solvers, morphology optimization, and Simulink work do not leak into this plan.
