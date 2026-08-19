# Phase 4A Deterministic Robustness Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run three frozen controllers through a reproducible 13-scenario deterministic robustness matrix and export complete raw, tabular, and visual evidence.

**Architecture:** Extend robot/disturbance configuration without changing existing nominal behavior, represent each prescribed stress case as a validated structure, and execute all controller-scenario pairs through the shared simulator. Separate per-run metrics from aggregate analysis and keep experiment file I/O outside package functions.

**Tech Stack:** MATLAB R2026a, MATLAB Unit Test, existing `+rrm` analytical plant/controllers, CSV/MAT export, Git.

## Global Constraints

- Phase 4A contains exactly 13 deterministic scenarios and 39 full-mode runs.
- Controllers are frozen baseline definitions; no per-scenario tuning or optimization is permitted.
- Every controller receives the same reference, sample step, initial state, plant, disturbance, and actuator limits within a scenario.
- Link geometry changes must recompute COM and uniform-link inertia.
- Failed or saturated runs remain in saved data and tables.
- Measurement noise and repeated stochastic trials are Phase 4B scope.
- Every production change follows focused RED→GREEN verification and an atomic commit.

---

### Task 1: Prescribed Robot Configurations and Frozen Optimized PID

**Files:**
- Modify: `+rrm/+config/makeRobot.m`
- Create: `+rrm/+config/makeOptimizedPidController.m`
- Modify: `tests/config/TestMakeRobot.m`
- Create: `tests/config/TestMakeOptimizedPidController.m`

**Interfaces:**
- `robot = rrm.config.makeRobot(name)` accepts `"compact"`, `"baseline"`, or `"extended"`.
- `controller = rrm.config.makeOptimizedPidController(robot)` returns the frozen Phase 3 gains with `type="pid"`.

- [ ] **Step 1: Add failing physical-consistency tests**:

```matlab
compact = rrm.config.makeRobot("compact");
extended = rrm.config.makeRobot("extended");
testCase.verifyEqual([compact.L1 compact.L2],[0.35 0.25]);
testCase.verifyEqual([extended.L1 extended.L2],[0.55 0.45]);
testCase.verifyEqual(extended.com,[extended.L1;extended.L2]/2);
testCase.verifyEqual(extended.inertia, ...
    [extended.m1*extended.L1^2/12;extended.m2*extended.L2^2/12]);
```

Add a frozen-controller test requiring exact gains `[240;200]`, `[79.9554;30.2026]`, `[29.3133;18.3972]`, baseline torque limits, and `type="pid"`.

- [ ] **Step 2: Verify RED** on both configuration test files.
- [ ] **Step 3: Implement the three-name factory and frozen optimized controller** without changing baseline values.
- [ ] **Step 4: Run focused and full tests; require GREEN.**
- [ ] **Step 5: Commit** as `feat: add prescribed robot configurations`.

### Task 2: Time-Varying Disturbance History

**Files:**
- Modify: `+rrm/+simulation/runController.m`
- Modify: `tests/simulation/TestRunController.m`

**Interfaces:**
- `options.disturbanceTorque` accepts finite real `2 x 1` or `2 x N` values.
- `result.disturbanceTorque` is always the expanded `2 x N` applied history.

- [ ] **Step 1: Add failing tests** for constant-history expansion, numerical equality of all old fields between `2 x 1` and repeated `2 x N`, exact pulse recording, and named rejection of `2 x (N-1)` and `NaN` histories.

```matlab
pulse = zeros(2,numel(reference.time));
pulse(:,reference.time>=0.08 & reference.time<=0.10) = [4;-3];
options.disturbanceTorque = pulse;
result = rrm.simulation.runPid(robot,controller,reference,options);
testCase.verifyEqual(result.disturbanceTorque,pulse);
```

- [ ] **Step 2: Verify RED** because history input and output recording are absent.
- [ ] **Step 3: Implement one validation/expansion helper**, pass `history(:,sample)` into every RK4 step, and add the result field after all existing fields.
- [ ] **Step 4: Run focused and full tests; prove old-field equality with zero tolerance.**
- [ ] **Step 5: Commit** as `feat: support time-varying disturbance torque`.

### Task 3: Deterministic Scenario Factory

**Files:**
- Create: `+rrm/+robustness/makeDeterministicScenarios.m`
- Create: `tests/robustness/TestMakeDeterministicScenarios.m`

**Interfaces:**
- `scenarios = rrm.robustness.makeDeterministicScenarios(reference,baseOptions,mode)` where `mode` is `"full"` or `"smoke"`.
- Each scenario contains `name`, `category`, `robot`, `options`, `disturbanceWindow`, and numeric sweep metadata (`payload`, `lengthScale`, `uncertaintyScale`, `torqueScale`).

- [ ] **Step 1: Write failing full-mode tests** requiring the exact ordered 13 names, unique names, categories, and documented field mutations.
- [ ] **Step 2: Add exact pulse and combined-case assertions**:

```matlab
active = reference.time>=2.00 & reference.time<=2.10;
testCase.verifyEqual(disturbance.options.disturbanceTorque(:,active), ...
    repmat([4;-3],1,nnz(active)));
testCase.verifyEqual(combined.robot.torqueLimits,[18;10]);
testCase.verifyEqual(combined.robot.payload,1.0);
```

- [ ] **Step 3: Verify RED**, then implement finite physical validation, robot mutation helpers that recompute dependent inertia, and a smoke subset containing nominal/disturbance/actuator/combined cases.
- [ ] **Step 4: Run focused and full tests; require GREEN.**
- [ ] **Step 5: Commit** as `feat: define deterministic robustness scenarios`.

### Task 4: Cartesian and Recovery Metrics

**Files:**
- Create: `+rrm/+robustness/evaluateRun.m`
- Create: `tests/robustness/TestEvaluateRun.m`

**Interfaces:**
- `metrics = rrm.robustness.evaluateRun(result,robot,criteria,scenario)` includes `common`, `endEffectorRmsError`, `endEffectorMaxError`, `totalSaturationTime`, `recoveryTime`, and `success`.

- [ ] **Step 1: Write failing hand-calculated Cartesian tests** using two known joint poses and analytical forward kinematics.
- [ ] **Step 2: Write failing recovery tests** with 0.01 s samples, pulse end at 0.10 s, a 0.03 s dwell override for test brevity, recovery at 0.14 s, and a never-recovered trace returning `Inf`.
- [ ] **Step 3: Verify RED**, then implement vectorized Cartesian positions, exact dwell-window recovery detection, common metric delegation, and the 0.15 m robustness-success threshold.
- [ ] **Step 4: Run focused and full tests; require GREEN.**
- [ ] **Step 5: Commit** as `feat: add robustness and recovery metrics`.

### Task 5: Fair Matrix Runner and Aggregation

**Files:**
- Create: `+rrm/+robustness/runDeterministicMatrix.m`
- Create: `+rrm/+robustness/summarizeMatrix.m`
- Create: `tests/robustness/TestRunDeterministicMatrix.m`
- Create: `tests/robustness/TestSummarizeMatrix.m`

**Interfaces:**
- `matrix = rrm.robustness.runDeterministicMatrix(controllerDefinitions,scenarios,reference,criteria)` returns raw `runs` and a one-row-per-run MATLAB table.
- `summary = rrm.robustness.summarizeMatrix(matrix.table)` returns a one-row-per-controller table.

- [ ] **Step 1: Write a short failing 2-controller x 2-scenario runner test** requiring four unique pairs, shared reference arrays, raw results, scenario metadata, and no dropped status.
- [ ] **Step 2: Verify RED**, then implement validation and nested fair execution with controller definitions stored as nested structs so PID and Fuzzy-PID field differences are supported.
- [ ] **Step 3: Write a failing synthetic aggregation test**:

```matlab
runTable = table(["A";"A";"B";"B"],logical([1;0;1;1]), ...
    [0.1;0.3;0.2;0.4],[0;0.2;0;0.1], ...
    VariableNames=["Controller","Success","JointRmsMean", ...
    "TotalSaturationTime"]);
```

Require success rates `[0.5;1.0]`, mean/worst error, total saturation, and exact controller order.
- [ ] **Step 4: Verify RED**, implement aggregation, then run focused and full tests; require GREEN.
- [ ] **Step 5: Commit** as `feat: run and summarize robustness matrix`.

### Task 6: Full Robustness Experiment and Artifacts

**Files:**
- Create: `experiments/run_deterministic_robustness.m`
- Create: `tests/experiments/TestDeterministicRobustness.m`

**Interfaces:**
- Public default `robustnessMode="full"`; test may predefine `robustnessMode="smoke"` and a short reference override.
- Produces one MAT file, two CSV files, and six PNG figures named by the design specification.

- [ ] **Step 1: Write the failing smoke artifact test** requiring every file, `4 scenarios x 3 controllers = 12` unique rows, three summary rows, and successful nominal rows.
- [ ] **Step 2: Verify RED**, then implement controller definitions, scenario construction, runner, aggregation, persistence, console tables, category plots, heatmap, and disturbance/recovery plot.
- [ ] **Step 3: Implement full-mode evidence assertions** for 13 scenarios, 39 unique pairs, exact labels, retained failures, and finite reportable metrics. Do not assert that every stress case succeeds.
- [ ] **Step 4: Run smoke test and full experiment separately.** Record all controller failures and saturation rather than changing scenario severity after seeing results.
- [ ] **Step 5: Run the full test suite; require GREEN.**
- [ ] **Step 6: Commit** as `feat: add deterministic robustness study`.

### Task 7: Verification, Analysis, and Documentation

**Files:**
- Modify: `scripts/verify.ps1`
- Modify: `README.md`

- [ ] **Step 1: Extend verification** with `clear robustnessMode; run('experiments/run_deterministic_robustness.m');` after Phase 3.
- [ ] **Step 2: Document** all 13 scenarios, frozen controller policy, metric definitions, full summary, notable failures/regressions, commands, artifacts, and Phase 4B boundary.
- [ ] **Step 3: Run MATLAB `checkcode`** over `+rrm/**/*.m` and `experiments/*.m`; require zero issues.
- [ ] **Step 4: Run `scripts/verify.ps1`** and require exit zero.
- [ ] **Step 5: Inspect six figures** for labels, units, common scales, complete scenarios, and visible unfavorable cases.
- [ ] **Step 6: Run `git diff --check`, inspect staged scope, and commit** as `docs: document deterministic robustness evidence`.

### Task 8: Integration

- [ ] **Step 1: Confirm a clean feature branch** and all Task 1–7 commits.
- [ ] **Step 2: Fast-forward merge** `feature/phase-4a-deterministic-robustness` into local `main`.
- [ ] **Step 3: Run merged-main full verification and zero-issue `checkcode`.**
- [ ] **Step 4: Remove only the owned Phase 4A worktree and merged local branch; preserve the unrelated DOCX.**
- [ ] **Step 5: Report** test count, 39-run summary, per-controller success rate, worst cases, saturation, recovery, artifacts, merge state, and explicit Phase 4B deferrals. Do not push or open a PR.

## Plan Self-Review

- The plan implements every Phase 4A scenario, controller, metric, error path, artifact, and success criterion.
- Interfaces are consistent from scenario factory through per-run evaluation, matrix table, aggregation, experiment, and README.
- Existing zero/constant disturbance behavior is protected before history support is used by scenarios.
- Full scientific execution is separate from smoke artifact testing.
- Sensor noise, seeded repeated trials, statistical inference, and noise-inclusive combined stress remain exclusively Phase 4B.
