# Phase 5 Cartesian Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate smooth Cartesian paths and a simplified pick-transfer-place sequence, convert them to continuous joint references, and compare the three frozen controllers with reproducible task-space evidence.

**Architecture:** Project-owned Cartesian trajectory functions produce analytic position, velocity, and acceleration. Analytical IK selects a continuous joint-limit-valid branch, while Jacobian differential kinematics produces physically consistent joint velocity and acceleration. Existing controllers and the shared simulator remain unchanged; a new task metric and experiment layer owns evaluation and artifacts.

**Tech Stack:** MATLAB R2026a, MATLAB Unit Test, existing `+rrm` packages, PowerShell, Git.

## Global Constraints

- Formal experiments use the baseline robot and `0.001 s` fixed step.
- Manual PID, Mamdani Fuzzy-PID, and optimization PID gains remain frozen.
- Add no toolbox or third-party dependency.
- Use the exact Cartesian points, durations, thresholds, errors, and artifacts frozen in the Phase 5 design.
- Package functions perform no file I/O or base-workspace access.
- Preserve the unrelated untracked source DOCX.
- Use test-first RED/GREEN cycles and one atomic commit per task.
- Do not push or open a remote pull request.

---

## File Map

```text
+rrm/+kinematics/jacobian.m              Planar geometric Jacobian
+rrm/+kinematics/jacobianDot.m           Jacobian time derivative
+rrm/+trajectory/cartesianQuintic.m      One rest-to-rest Cartesian segment
+rrm/+trajectory/cartesianWaypoints.m    Piecewise Cartesian path and metadata
+rrm/+trajectory/cartesianToJoint.m      Continuous IK and differential mapping
+rrm/+trajectory/makePickAndPlaceTask.m  Frozen task command and reference
+rrm/+metrics/evaluateCartesianTask.m    Task-space metrics and success decision
experiments/run_cartesian_tasks.m         Six-run study and artifacts
tests/kinematics/TestDifferentialKinematics.m
tests/trajectory/TestCartesianQuintic.m
tests/trajectory/TestCartesianWaypoints.m
tests/trajectory/TestCartesianToJoint.m
tests/trajectory/TestMakePickAndPlaceTask.m
tests/metrics/TestEvaluateCartesianTask.m
tests/experiments/TestCartesianTasks.m
README.md
scripts/verify.ps1
```

### Task 1: Differential Kinematics

**Files:**
- Create: `+rrm/+kinematics/jacobian.m`
- Create: `+rrm/+kinematics/jacobianDot.m`
- Create: `tests/kinematics/TestDifferentialKinematics.m`

**Interfaces:**
- Consumes: `robot = rrm.config.makeRobot("baseline")`, finite real `q` and `dq` as `2 x 1` vectors.
- Produces: `J = rrm.kinematics.jacobian(robot,q)` and `Jdot = rrm.kinematics.jacobianDot(robot,q,dq)`, both finite real `2 x 2` matrices.

- [ ] **Step 1: Write the failing finite-difference tests.** Create the test class with two tests. The first central-differences `rrm.kinematics.forward`; the second central-differences the new Jacobian along `q +/- h*dq`.

```matlab
classdef TestDifferentialKinematics < matlab.unittest.TestCase
    methods (Test)
        function jacobianMatchesForwardDifference(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = deg2rad([28;-47]);
            h = 1e-6;
            numerical = zeros(2,2);
            for joint = 1:2
                step = zeros(2,1);
                step(joint) = h;
                numerical(:,joint) = ( ...
                    rrm.kinematics.forward(robot,q+step)- ...
                    rrm.kinematics.forward(robot,q-step))/(2*h);
            end
            testCase.verifyEqual(rrm.kinematics.jacobian(robot,q), ...
                numerical,AbsTol=1e-9);
        end

        function jacobianDotMatchesDirectionalDifference(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = deg2rad([28;-47]);
            dq = [0.4;-0.2];
            h = 1e-6;
            numerical = (rrm.kinematics.jacobian(robot,q+h*dq)- ...
                rrm.kinematics.jacobian(robot,q-h*dq))/(2*h);
            actual = rrm.kinematics.jacobianDot(robot,q,dq);
            testCase.verifyEqual(actual,numerical,AbsTol=1e-9);
        end
    end
end
```

- [ ] **Step 2: Run RED.**

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); r=runtests('tests/kinematics/TestDifferentialKinematics.m'); assertSuccess(r);"
```

Expected: both tests fail because `jacobian` and `jacobianDot` are undefined.

- [ ] **Step 3: Implement the analytical matrices.** Use the exact two-link formulas from the design, argument blocks with `(2,1)` vector shapes, and no numerical differencing in production.
- [ ] **Step 4: Run the focused tests, then the entire suite.** Expected: focused tests pass; the full pre-existing suite remains green.
- [ ] **Step 5: Run `checkcode` for both new files and commit.**

```powershell
git add -- '+rrm/+kinematics/jacobian.m' '+rrm/+kinematics/jacobianDot.m' 'tests/kinematics/TestDifferentialKinematics.m'
git commit -m "feat: add planar differential kinematics"
```

### Task 2: Smooth Cartesian Quintic Segment

**Files:**
- Create: `+rrm/+trajectory/cartesianQuintic.m`
- Create: `tests/trajectory/TestCartesianQuintic.m`

**Interfaces:**
- Consumes: `p0`, `pf` as `2 x 1` metres; positive scalar move/sample/total durations.
- Produces: path fields `time`, `position`, `velocity`, and `acceleration` with a common `N`-sample grid.

- [ ] **Step 1: Write failing endpoint, geometry, hold, and invalid-grid tests.** The test class must assert the following exact behavior:

```matlab
path = rrm.trajectory.cartesianQuintic( ...
    [0.55;0.12],[0.22;0.48],3,0.001,4);
testCase.verifyEqual(path.position(:,1),[0.55;0.12],AbsTol=1e-12);
testCase.verifyEqual(path.position(:,end),[0.22;0.48],AbsTol=1e-12);
testCase.verifyEqual(path.velocity(:,[1 end]),zeros(2,2),AbsTol=1e-10);
testCase.verifyEqual(path.acceleration(:,[1 end]),zeros(2,2),AbsTol=1e-9);
delta = [0.22;0.48]-[0.55;0.12];
offset = path.position-[0.55;0.12];
crossProduct = delta(1)*offset(2,:)-delta(2)*offset(1,:);
testCase.verifyLessThan(max(abs(crossProduct)),1e-12);
hold = path.time >= 3;
testCase.verifyEqual(path.position(:,hold), ...
    repmat([0.22;0.48],1,nnz(hold)),AbsTol=1e-12);
testCase.verifyError(@() rrm.trajectory.cartesianQuintic( ...
    [0;0],[0.2;0.3],1,0.3,1),"rrm:trajectory:InvalidCartesianPath");
```

- [ ] **Step 2: Run RED** and confirm the missing-function failure.
- [ ] **Step 3: Implement the segment generator.** Reuse the scalar law `10*s^3-15*s^4+6*s^5` and its analytic derivatives; do not call joint-space `quintic` and rename its fields afterward.
- [ ] **Step 4: Run focused and full tests.**
- [ ] **Step 5: Run static analysis and commit.**

```powershell
git add -- '+rrm/+trajectory/cartesianQuintic.m' 'tests/trajectory/TestCartesianQuintic.m'
git commit -m "feat: generate smooth Cartesian segments"
```

### Task 3: Piecewise Cartesian Waypoints

**Files:**
- Create: `+rrm/+trajectory/cartesianWaypoints.m`
- Create: `tests/trajectory/TestCartesianWaypoints.m`

**Interfaces:**
- Consumes: `points (2 x M)`, `moveDurations ((M-1) x 1)`, `dwellDurations ((M-1) x 1)`, and scalar `sampleTime`.
- Produces: standard Cartesian path plus `arrivalIndices` and `dwellEndIndices`, both `(M-1) x 1` integer arrays.

- [ ] **Step 1: Write the failing prescribed-waypoint test.**

```matlab
points = [0.55 0.45 0.45 0.22; 0.12 -0.02 0.32 0.48];
path = rrm.trajectory.cartesianWaypoints( ...
    points,[1.4;1.2;1.5],[0.4;0;0.8],0.001);
testCase.verifyEqual(diff(path.time), ...
    0.001*ones(numel(path.time)-1,1),AbsTol=1e-14);
for k = 1:3
    testCase.verifyEqual(path.position(:,path.arrivalIndices(k)), ...
        points(:,k+1),AbsTol=1e-12);
    testCase.verifyEqual(path.position(:,path.dwellEndIndices(k)), ...
        points(:,k+1),AbsTol=1e-12);
    testCase.verifyEqual(path.velocity(:,path.arrivalIndices(k)), ...
        [0;0],AbsTol=1e-10);
    testCase.verifyEqual(path.acceleration(:,path.arrivalIndices(k)), ...
        [0;0],AbsTol=1e-9);
end
testCase.verifyEqual(path.time(end),5.3,AbsTol=1e-14);
```

Also test invalid point shape, duration count, negative dwell, non-grid duration, and fewer than two waypoints; all use `rrm:trajectory:InvalidWaypointPath`.

- [ ] **Step 2: Run RED.**
- [ ] **Step 3: Implement joining.** Build every movement with `cartesianQuintic`, exclude each later segment's duplicate first sample, append dwell samples after the arrival sample, and compute metadata indices as samples are appended.
- [ ] **Step 4: Run focused and full tests.**
- [ ] **Step 5: Run static analysis and commit.**

```powershell
git add -- '+rrm/+trajectory/cartesianWaypoints.m' 'tests/trajectory/TestCartesianWaypoints.m'
git commit -m "feat: compose Cartesian waypoint paths"
```

### Task 4: Continuous Cartesian-to-Joint Reference

**Files:**
- Create: `+rrm/+trajectory/cartesianToJoint.m`
- Create: `tests/trajectory/TestCartesianToJoint.m`

**Interfaces:**
- Consumes: robot, standard Cartesian path, and finite real `initialJoint (2 x 1)`.
- Produces: simulator reference `time`, `q`, `dq`, `ddq`, and `cartesian`.

- [ ] **Step 1: Write failing reconstruction and branch tests.** Generate the frozen straight path, choose the positive-`q2` first solution, convert it, and assert:

```matlab
[solutions,reachable] = rrm.kinematics.inverse(robot,path.position(:,1));
testCase.verifyTrue(reachable);
reference = rrm.trajectory.cartesianToJoint(robot,path,solutions(:,1));
sampleCount = numel(path.time);
positionError = zeros(1,sampleCount);
velocityError = zeros(1,sampleCount);
accelerationError = zeros(1,sampleCount);
for k = 1:sampleCount
    positionError(k) = norm(rrm.kinematics.forward( ...
        robot,reference.q(:,k))-path.position(:,k));
    J = rrm.kinematics.jacobian(robot,reference.q(:,k));
    Jdot = rrm.kinematics.jacobianDot( ...
        robot,reference.q(:,k),reference.dq(:,k));
    velocityError(k) = norm(J*reference.dq(:,k)-path.velocity(:,k));
    accelerationError(k) = norm(J*reference.ddq(:,k)+ ...
        Jdot*reference.dq(:,k)-path.acceleration(:,k));
end
testCase.verifyLessThan(max(positionError),1e-10);
testCase.verifyLessThan(max(velocityError),1e-10);
testCase.verifyLessThan(max(accelerationError),1e-9);
testCase.verifyLessThan(max(abs(diff(reference.q,1,2)),[],"all"),deg2rad(1));
testCase.verifyGreaterThanOrEqual(reference.q,robot.jointLimits(:,1)-1e-12);
testCase.verifyLessThanOrEqual(reference.q,robot.jointLimits(:,2)+1e-12);
```

Add named-error tests for an unreachable point, a path whose only solutions violate narrowed test joint limits, a fully extended singular path, and malformed arrays.

- [ ] **Step 2: Run RED.**
- [ ] **Step 3: Implement branch selection and differential mapping.** At each sample enumerate both IK branches and `-2*pi`, `0`, `2*pi` equivalents per joint; reject out-of-limit candidates; select the minimum Euclidean difference from the previous joint vector; enforce `rcond(J) > 1e-8`; compute the exact velocity and acceleration formulas.
- [ ] **Step 4: Run focused and full tests.**
- [ ] **Step 5: Run static analysis and commit.**

```powershell
git add -- '+rrm/+trajectory/cartesianToJoint.m' 'tests/trajectory/TestCartesianToJoint.m'
git commit -m "feat: convert Cartesian paths to continuous joint references"
```

### Task 5: Frozen Pick-and-Place Task Factory

**Files:**
- Create: `+rrm/+trajectory/makePickAndPlaceTask.m`
- Create: `tests/trajectory/TestMakePickAndPlaceTask.m`

**Interfaces:**
- Consumes: robot and positive scalar sample time.
- Produces: task fields `name`, `waypointNames`, `waypoints`, `moveDurations`, `dwellDurations`, `path`, `reference`, `pickupEvaluationIndex`, and `placeEvaluationIndex`.

- [ ] **Step 1: Write the failing factory test.** Assert the exact values frozen in the design, `pickupEvaluationIndex == path.dwellEndIndices(1)`, `placeEvaluationIndex == path.dwellEndIndices(3)`, positive `q2` across the path, and forward reconstruction below `1e-10 m`.
- [ ] **Step 2: Run RED.**
- [ ] **Step 3: Implement the factory.** Obtain `initialJoint` from column 1 of the first-point analytical IK solution and delegate path/conversion work to Tasks 3 and 4.
- [ ] **Step 4: Run focused and full tests.**
- [ ] **Step 5: Run static analysis and commit.**

```powershell
git add -- '+rrm/+trajectory/makePickAndPlaceTask.m' 'tests/trajectory/TestMakePickAndPlaceTask.m'
git commit -m "feat: define simplified Cartesian pick-and-place task"
```

### Task 6: Cartesian Task Metrics

**Files:**
- Create: `+rrm/+metrics/evaluateCartesianTask.m`
- Create: `tests/metrics/TestEvaluateCartesianTask.m`

**Interfaces:**
- Consumes: completed or failed simulator result, robot, Cartesian-backed reference, and an evaluation-index struct with optional `pickup` and `place` scalar indices.
- Produces: common metrics plus `desiredPosition`, `actualPosition`, `cartesianError`, `cartesianRms`, `cartesianMax`, `pickupError`, `placeError`, `totalSaturationTime`, and `taskSuccess`.

- [ ] **Step 1: Write failing hand-calculated metric tests.** Build a three-sample result from known joint poses, calculate expected positions with `rrm.kinematics.forward`, and independently assert Euclidean RMS/max and indexed errors. Add one success case, then separately violate the RMS, max, waypoint, saturation, common success, and status conditions.

The success assertion must use exactly:

```matlab
expectedSuccess = result.status == "completed" && common.success && ...
    cartesianRms <= 0.05 && cartesianMax <= 0.15 && ...
    all(requestedWaypointErrors <= 0.05) && totalSaturationTime == 0;
```

- [ ] **Step 2: Run RED.**
- [ ] **Step 3: Implement metrics.** Delegate joint metrics to `rrm.metrics.evaluate`, calculate true Cartesian positions from `result.q`, and never use noisy measured positions.
- [ ] **Step 4: Run focused and full tests.**
- [ ] **Step 5: Run static analysis and commit.**

```powershell
git add -- '+rrm/+metrics/evaluateCartesianTask.m' 'tests/metrics/TestEvaluateCartesianTask.m'
git commit -m "feat: evaluate Cartesian task execution"
```

### Task 7: Six-Run Cartesian Experiment and Artifacts

**Files:**
- Create: `experiments/run_cartesian_tasks.m`
- Create: `tests/experiments/TestCartesianTasks.m`

**Interfaces:**
- Consumes: frozen baseline robot/controllers, straight path definition, pick-and-place task factory, and optional base-workspace `outputRoot` and `cartesianMode` (`"full"` default, `"smoke"` only for artifact tests).
- Produces: one MAT, one CSV, five PNG files, a six-row full run table, task definitions, references, results, and metrics.

- [ ] **Step 1: Write the failing artifact test.** Run the experiment into `tempname` with `cartesianMode="smoke"`, then require nonempty artifacts and six rows. For each task, assert all three result `qReference` and `dqReference` arrays are exactly equal. Assert controller gain arrays equal their factories and all reported numeric metrics are finite.
- [ ] **Step 2: Run RED.**
- [ ] **Step 3: Implement orchestration.** Generate the straight task and pick-and-place task once, run the three controllers through `rrm.simulation.runController`, evaluate metrics, and store every run. Do not rerun optimization.
- [ ] **Step 4: Implement the CSV.** Include task, controller, status, success, Cartesian RMS/max, pickup/place error, mean joint RMS, mean torque RMS, and total saturation time.
- [ ] **Step 5: Implement figures.** Produce desired/actual XY paths, Cartesian error histories, joint reference histories, torque histories with limits, and a grouped summary. Every figure must have units, legends, and task/controller labels.
- [ ] **Step 6: Run the smoke artifact test, all tests, and static analysis.**
- [ ] **Step 7: Commit.**

```powershell
git add -- 'experiments/run_cartesian_tasks.m' 'tests/experiments/TestCartesianTasks.m'
git commit -m "feat: add Cartesian task comparison study"
```

### Task 8: Full Evidence, Documentation, and Verification Entry

**Files:**
- Modify: `README.md`
- Modify: `scripts/verify.ps1`

**Interfaces:**
- Consumes: the verified full Phase 5 artifacts and exact printed results.
- Produces: documented interpretation and a complete one-command verification chain.

- [ ] **Step 1: Run the full Phase 5 experiment.**

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); clear outputRoot cartesianMode; run('experiments/run_cartesian_tasks.m');"
```

- [ ] **Step 2: Inspect both CSV and MAT consistency.** Require six rows, two tasks, three controllers per task, identical references inside a task, and metrics that match recalculation from saved histories.
- [ ] **Step 3: Visually inspect all five PNG files.** Check line visibility, units, legends, path orientation, waypoint positions, and absence of clipped labels.
- [ ] **Step 4: Update README.** Document the fixed tasks, continuous IK/differential method, exact results, scientific interpretation, limitations, commands, and artifacts. Do not claim universal controller superiority.
- [ ] **Step 5: Append `run('experiments/run_cartesian_tasks.m');` to `scripts/verify.ps1` after the stochastic study with `clear outputRoot cartesianMode;`.
- [ ] **Step 6: Run `git diff --check`, all tests, `checkcode`, and the full verification script from the feature worktree.**
- [ ] **Step 7: Commit documentation.**

```powershell
git add -- README.md scripts/verify.ps1
git commit -m "docs: document Cartesian task evidence"
```

### Task 9: Integration and Cleanup

**Files:** No source changes expected.

**Interfaces:**
- Consumes: a clean, fully verified Phase 5 feature branch.
- Produces: local `main` fast-forwarded to the Phase 5 tip, retained ignored artifacts, and no owned temporary worktree/branch.

- [ ] **Step 1: Confirm the feature worktree has no tracked or untracked task changes and review the complete commit range.**
- [ ] **Step 2: Fast-forward local `main` only; do not push.**
- [ ] **Step 3: Run all tests, `checkcode`, and `scripts/verify.ps1` again from merged `main`.**
- [ ] **Step 4: Confirm the unrelated root DOCX remains untouched and the Phase 5 MAT/CSV/PNG files exist under the main checkout.**
- [ ] **Step 5: Resolve and validate the exact owned worktree path under `.worktrees`, remove it, then delete the merged local feature branch.**

## Plan Self-Review

- Every Phase 5 design component maps to exactly one implementation task.
- Function names, field names, path points, durations, thresholds, errors, commands, and artifact names match the design.
- No task adds perception, collision handling, object physics, operational-space control, retuning, or new dependencies.
- Every production-code task has a required observed RED run before implementation and focused/full GREEN runs afterward.
- Full evidence is generated before documentation, and merged-main verification precedes completion claims.
