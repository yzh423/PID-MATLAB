# Phase 6A Simulink and Robotics Cross-Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independently checked rigid-body dynamics model and an organized native Simulink closed loop that quantitatively reproduces the nominal MATLAB results for the frozen manual and optimized PID controllers.

**Architecture:** Robotics System Toolbox independently reconstructs the two-link robot and validates `M`, `C*dq`, and `G` over a deterministic state grid. A programmatically generated Simulink model uses native controller blocks and an equation-local plant block, while package functions prepare `SimulationInput`, normalize logged results, compare them with the existing MATLAB runner, and leave artifact writing to one experiment script.

**Tech Stack:** MATLAB R2026a Update 4, MATLAB Unit Test, Simulink 26.1, Robotics System Toolbox, Stateflow MATLAB Function block API, Git worktrees.

## Global Constraints

- Preserve all Phase 1–5 public interfaces, controller gains, robot parameters, thresholds, and results.
- Use the baseline robot, `[0;0]` to `[45;60] deg` 3 s quintic plus 2 s hold, 1 ms step, zero noise, and zero disturbance for formal comparison.
- The Simulink plant must not call `rrm.simulation.runController`, `rrm.dynamics.acceleration`, or `rrm.dynamics.matrices`.
- Include frozen manual PID and frozen optimization PID; do not duplicate Mamdani Fuzzy-PID in this phase.
- Rigid-body maximum differences must be `M <= 1e-10`, `C*dq <= 1e-10`, and `G <= 1e-10` in SI units.
- Closed-loop limits are joint-angle RMS `<=1e-5 rad`, joint-angle max `<=5e-5 rad`, joint-velocity RMS `<=1e-4 rad/s`, torque RMS `<=5e-3 N m`, and saturation-time disagreement `<=1 ms` per joint.
- Generated MAT/CSV/PNG files remain ignored; the builder and `models/rrm_pid_cross_validation.slx` are committed.
- Do not push, publish, or open a PR. Preserve `Daniel_MATLAB_Robotics_Project_Implementation_Guide.docx`.
- Follow RED→GREEN for every logic increment and commit only after focused tests pass.

## File Map

```text
+rrm/+validation/makeRigidBodyTree.m        Build independent rigidBodyTree
+rrm/+validation/compareRigidBodyDynamics.m Compare analytical and toolbox terms
+rrm/+simulink/buildPidCrossValidationModel.m Build deterministic .slx
+rrm/+simulink/runPidCrossValidation.m      Validate inputs, run, normalize logs
+rrm/+simulink/comparePidRuns.m             Compute numerical agreement table/flags
models/rrm_pid_cross_validation.slx          Committed visual model
experiments/run_simulink_cross_validation.m Formal two-controller study and artifacts
tests/validation/TestRigidBodyValidation.m  Dynamics RED/GREEN tests
tests/simulink/TestBuildPidCrossValidationModel.m Builder/model contract tests
tests/simulink/TestRunPidCrossValidation.m  Short-run integration tests
tests/simulink/TestComparePidRuns.m          Metric and error-path tests
tests/experiments/TestSimulinkCrossValidation.m Experiment smoke test
scripts/verify.ps1                           Phase 1–6A verification entry point
README.md                                    Phase 6A method, evidence, limitations
```

---

### Task 1: Independent Rigid-Body Dynamics Validation

**Files:**
- Create: `+rrm/+validation/makeRigidBodyTree.m`
- Create: `+rrm/+validation/compareRigidBodyDynamics.m`
- Create: `tests/validation/TestRigidBodyValidation.m`

**Interfaces:**
- Consumes: `robot = rrm.config.makeRobot("baseline")`; optional `states` struct with `q` and `dq` as finite real `2 x N` matrices.
- Produces: `tree = rrm.validation.makeRigidBodyTree(robot)` and `report = rrm.validation.compareRigidBodyDynamics(robot, states)` with maxima and per-sample histories.

- [ ] **Step 1: Write builder and comparison tests**

```matlab
classdef TestRigidBodyValidation < matlab.unittest.TestCase
    methods (Test)
        function treeMatchesTopology(testCase)
            robot = rrm.config.makeRobot("baseline");
            tree = rrm.validation.makeRigidBodyTree(robot);
            testCase.verifyEqual(tree.NumBodies, 3);
            testCase.verifyEqual(tree.DataFormat, "column");
            testCase.verifyEqual(tree.Gravity, [0 -robot.gravity 0], "AbsTol", 0);
        end

        function dynamicsAgreeOnGrid(testCase)
            robot = rrm.config.makeRobot("baseline");
            report = rrm.validation.compareRigidBodyDynamics(robot);
            testCase.verifyLessThanOrEqual(report.maxMassMatrixError, 1e-10);
            testCase.verifyLessThanOrEqual(report.maxVelocityProductError, 1e-10);
            testCase.verifyLessThanOrEqual(report.maxGravityError, 1e-10);
        end

        function rejectsMalformedStateGrid(testCase)
            robot = rrm.config.makeRobot("baseline");
            bad = struct("q",zeros(3,1),"dq",zeros(2,1));
            testCase.verifyError(@() rrm.validation.compareRigidBodyDynamics(robot,bad), ...
                "rrm:validation:InvalidStateGrid");
        end
    end
end
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); r=runtests('tests/validation/TestRigidBodyValidation.m'); assertSuccess(r);"
```

Expected: FAIL because `rrm.validation.makeRigidBodyTree` is undefined.

- [ ] **Step 3: Implement the rigid-body builder**

Create a `rigidBodyTree("DataFormat","column","MaxNumBodies",3)`, set gravity to `[0 -robot.gravity 0]`, then add:

```matlab
link1.Mass = robot.m1;
link1.CenterOfMass = [robot.com(1) 0 0];
link1.Inertia = [0 robot.inertia(1) robot.inertia(1) 0 0 0];
joint1.JointAxis = [0 0 1];

setFixedTransform(joint2, trvec2tform([robot.L1 0 0]));
link2.Mass = robot.m2;
link2.CenterOfMass = [robot.com(2) 0 0];
link2.Inertia = [0 robot.inertia(2) robot.inertia(2) 0 0 0];

payload.Mass = robot.payload;
payload.CenterOfMass = [0 0 0];
setFixedTransform(payloadJoint, trvec2tform([robot.L2 0 0]));
```

Use stable error `rrm:validation:MissingRoboticsToolbox` when `rigidBodyTree` is unavailable.

- [ ] **Step 4: Implement grid comparison**

Default states are the Cartesian product of:

```matlab
q1 = deg2rad([-120 -45 0 60 135]);
q2 = deg2rad([-100 -30 0 45 110]);
dq1 = [-1.5 0 1.25];
dq2 = [-1.0 0 1.75];
```

For each column, calculate `M`, `C*dq`, and `G`, compare with `massMatrix`, `velocityProduct`, and `gravityTorque`, store absolute-error histories, and expose their maxima. Do not sign-correct toolbox outputs after calculation.

- [ ] **Step 5: Run focused tests and static analysis**

Run the RED command again, then run `checkcode` on the two new package files. Expected: all three tests pass and zero issues.

- [ ] **Step 6: Commit**

```powershell
git add -- +rrm/+validation tests/validation
git commit -m "feat: cross-check analytical rigid-body dynamics"
```

---

### Task 2: Deterministic Native Simulink Model Builder

**Files:**
- Create: `+rrm/+simulink/buildPidCrossValidationModel.m`
- Create: `tests/simulink/TestBuildPidCrossValidationModel.m`
- Generate: `models/rrm_pid_cross_validation.slx`

**Interfaces:**
- Consumes: absolute or project-relative `.slx` target path.
- Produces: a saved loadable model and returns its model name as a scalar string.

- [ ] **Step 1: Write builder contract tests**

```matlab
classdef TestBuildPidCrossValidationModel < matlab.unittest.TestCase
    methods (Test)
        function buildsLoadableOrganizedModel(testCase)
            root = tempname; mkdir(root); cleanup = onCleanup(@() rmdir(root,"s"));
            path = fullfile(root,"cross_validation.slx");
            name = rrm.simulink.buildPidCrossValidationModel(path);
            testCase.verifyTrue(isfile(path));
            load_system(path); modelCleanup = onCleanup(@() close_system(name,0));
            testCase.verifyEqual(get_param(name,"Solver"),"ode4");
            testCase.verifyEqual(str2double(get_param(name,"FixedStep")),0.001);
            required = ["Reference","PID Controller","Two-Link Plant","Logging"];
            for block = required
                testCase.verifyNotEmpty(find_system(name,"SearchDepth",1,"Name",block));
            end
        end

        function rejectsNonSlxTarget(testCase)
            testCase.verifyError(@() rrm.simulink.buildPidCrossValidationModel("bad.txt"), ...
                "rrm:simulink:InvalidModelPath");
        end
    end
end
```

- [ ] **Step 2: Verify RED**

Run only `TestBuildPidCrossValidationModel`; expect undefined function failure.

- [ ] **Step 3: Implement safe model lifecycle and configuration**

Validate a `.slx` extension, create the parent directory if needed, derive a valid model name, close only that exact loaded model, and use `new_system`. Configure:

```matlab
set_param(modelName, ...
    "SolverType","Fixed-step", ...
    "Solver","ode4", ...
    "FixedStep","0.001", ...
    "StopTime","rrmStopTime", ...
    "SignalLogging","on", ...
    "ReturnWorkspaceOutputs","on");
```

Never recursively delete a caller directory.

- [ ] **Step 4: Add native controller and logging subsystems**

Create top-level labeled subsystems. The PID subsystem must implement:

```text
e = qRef - q
deFiltered[k] = alpha*deFiltered[k-1] + (1-alpha)*(dqRef-dq)
tauUnsat = Kp.*e + Ki.*integral + Kd.*deFiltered
tau = min(max(tauUnsat,-limit),limit)
integral[k+1] = integral[k] + Ts*(e + Kaw.*(tau-tauUnsat))
```

Use vector-width two blocks and workspace parameters `rrmKp`, `rrmKi`, `rrmKd`, `rrmDerivativeAlpha`, `rrmAntiWindupGain`, and `rrmTorqueLimits`. Log `q`, `dq`, and `tau` with signal logging.

- [ ] **Step 5: Add the independent plant equation block**

Add continuous `q` and `dq` Integrators and a MATLAB Function chart whose script expands the analytical formula locally:

```matlab
function ddq = plant(q,dq,tau,L1,L2,m1,m2,mp,r1,r2,I1,I2,g,b)
coupling = m2*L1*r2 + mp*L1*L2;
base = I1 + I2 + m1*r1^2 + m2*(L1^2+r2^2) + mp*(L1^2+L2^2);
distal = I2 + m2*r2^2 + mp*L2^2;
M = [base+2*coupling*cos(q(2)), distal+coupling*cos(q(2)); ...
     distal+coupling*cos(q(2)), distal];
C = [-coupling*sin(q(2))*dq(2), -coupling*sin(q(2))*(dq(1)+dq(2)); ...
      coupling*sin(q(2))*dq(1), 0];
G = [(m1*r1+(m2+mp)*L1)*g*cos(q(1)) + ...
     (m2*r2+mp*L2)*g*cos(q(1)+q(2)); ...
     (m2*r2+mp*L2)*g*cos(q(1)+q(2))];
ddq = M \ (tau-C*dq-G-b.*dq);
end
```

Use constants for physical scalars, reference From Workspace blocks, and rate transitions/zero-order holds where required to keep the controller discrete.

- [ ] **Step 6: Apply readable layout and model annotations**

Use `Simulink.BlockDiagram.arrangeSystem` within each subsystem, set top-level positions explicitly left-to-right, name every major signal, and add an annotation describing units and the independent plant equation path.

- [ ] **Step 7: Verify GREEN and generate the committed model**

Run builder tests, then execute the design build command for `models/rrm_pid_cross_validation.slx`. Load and compile the committed model with `set_param(model,"SimulationCommand","update")`; expect no diagnostics or algebraic loops.

- [ ] **Step 8: Commit**

```powershell
git add -- +rrm/+simulink/buildPidCrossValidationModel.m tests/simulink/TestBuildPidCrossValidationModel.m models/rrm_pid_cross_validation.slx
git commit -m "feat: build native Simulink PID validation model"
```

---

### Task 3: Simulink Runner and Output Normalization

**Files:**
- Create: `+rrm/+simulink/runPidCrossValidation.m`
- Create: `tests/simulink/TestRunPidCrossValidation.m`

**Interfaces:**
- Consumes: `(robot, controller, reference, options, modelPath)`.
- Produces: scalar result struct with aligned `time`, `q`, `dq`, `qReference`, `dqReference`, `tau`, `saturated`, `status`, and `completedSamples`.

- [ ] **Step 1: Write short-run and validation tests**

```matlab
function shortRunIsFiniteAndAligned(testCase)
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
reference = rrm.trajectory.quintic([0;0],deg2rad([5;8]),0.02,0.001,0.03);
options = rrm.config.makeSimulationOptions();
result = rrm.simulink.runPidCrossValidation(robot,controller,reference,options, ...
    fullfile("models","rrm_pid_cross_validation.slx"));
testCase.verifyEqual(result.time,reference.time,"AbsTol",0);
testCase.verifySize(result.q,size(reference.q));
testCase.verifyTrue(all(isfinite(result.q),"all"));
testCase.verifyEqual(result.status,"completed");
end

function rejectsFuzzyController(testCase)
robot = rrm.config.makeRobot("baseline");
fuzzy = rrm.config.makeFuzzyPidController(robot);
reference = rrm.trajectory.quintic([0;0],[0.1;0.1],0.01,0.001,0.02);
options = rrm.config.makeSimulationOptions();
testCase.verifyError(@() rrm.simulink.runPidCrossValidation( ...
    robot,fuzzy,reference,options,fullfile("models","rrm_pid_cross_validation.slx")), ...
    "rrm:simulink:UnsupportedController");
end
```

- [ ] **Step 2: Verify RED**

Run `TestRunPidCrossValidation`; expect undefined runner failure.

- [ ] **Step 3: Implement input validation and SimulationInput preparation**

Require `controller.type == "pid"`, a finite increasing reference with the configured step, zero nominal disturbance/noise for this phase, and initial velocity size `2 x 1`. Set all reference signals, gains, controller state parameters, plant parameters, initial conditions, stop time, and model path using `Simulink.SimulationInput.setVariable`.

- [ ] **Step 4: Normalize logged output**

Read named `logsout` elements `q`, `dq`, and `tau`; reshape to `2 x N`; require exact time-grid agreement with the reference; derive saturation with the same floating-point rule as `pidStep`; return stable errors `rrm:simulink:MissingLoggedSignal`, `rrm:simulink:TimeGridMismatch`, and `rrm:simulink:NonFiniteOutput`.

- [ ] **Step 5: Verify GREEN and commit**

Run the focused runner and builder suites, `checkcode`, then:

```powershell
git add -- +rrm/+simulink/runPidCrossValidation.m tests/simulink/TestRunPidCrossValidation.m
git commit -m "feat: run and normalize Simulink PID validation"
```

---

### Task 4: Numerical Cross-Validation Metrics

**Files:**
- Create: `+rrm/+simulink/comparePidRuns.m`
- Create: `tests/simulink/TestComparePidRuns.m`

**Interfaces:**
- Consumes: MATLAB and Simulink result structs with aligned histories.
- Produces: comparison struct containing jointwise RMS/max differences, saturation times, booleans, `pass`, and `failureSummary`.

- [ ] **Step 1: Write exact, threshold, and error-path tests**

Build a five-sample synthetic run. Verify exact copies pass, a `6e-5 rad` angle spike fails the maximum-angle flag, shifted time raises `rrm:simulink:TimeGridMismatch`, and NaN raises `rrm:simulink:NonFiniteComparisonData`.

- [ ] **Step 2: Verify RED**

Run `TestComparePidRuns`; expect undefined function failure.

- [ ] **Step 3: Implement aligned metrics and flags**

For `delta = simulink - matlab`, calculate `sqrt(mean(delta.^2,2))` and `max(abs(delta),[],2)`. Use the exact frozen limits in Global Constraints. Calculate saturation time as `sum(saturated,2)*sampleTime`, require each difference `<=sampleTime`, and compose `failureSummary` from names of failed flags.

- [ ] **Step 4: Add real short-run equivalence test**

Extend `TestRunPidCrossValidation` to compare the short Simulink run with `rrm.simulation.runController` and require `comparison.pass`.

- [ ] **Step 5: Verify GREEN and commit**

```powershell
git add -- +rrm/+simulink/comparePidRuns.m tests/simulink
git commit -m "feat: quantify MATLAB Simulink agreement"
```

---

### Task 5: Formal Two-Controller Experiment and Evidence

**Files:**
- Create: `experiments/run_simulink_cross_validation.m`
- Create: `tests/experiments/TestSimulinkCrossValidation.m`

**Interfaces:**
- Consumes: committed model, frozen controllers, baseline configuration, optional `outputRoot` and `simulinkValidationMode` (`"smoke"` or `"full"`).
- Produces: `simulinkValidationResults`, `simulinkValidationRunTable`, MAT/CSV, and four figures in full mode.

- [ ] **Step 1: Write smoke experiment test**

The test sets a temporary `outputRoot`, `simulinkValidationMode="smoke"`, runs the script, and requires two rows, both controller names, completed statuses, `pass=true`, finite metrics, and all expected temporary artifacts.

- [ ] **Step 2: Verify RED**

Run the experiment test; expect missing-script failure.

- [ ] **Step 3: Implement the fixed protocol and result table**

Run manual and optimized PID through both simulation paths. Store controller, statuses, each joint's RMS/max angle, velocity and torque difference, both saturation times, steady-state metrics, and overall pass. Assert the formal full run passes; smoke mode shortens the reference but keeps 1 ms sampling and both controllers.

- [ ] **Step 4: Write reproducible artifacts**

Full mode writes the exact MAT/CSV names from the design and four figures:

1. overlaid MATLAB/Simulink joint tracking;
2. angle/velocity differences with threshold annotations;
3. overlaid torque histories and saturation limits;
4. log-scale summary of measured errors versus frozen thresholds.

Use consistent colors across controller and execution path, explicit SI units, legends, titles, and 300 dpi PNG export.

- [ ] **Step 5: Verify GREEN and commit**

Run the smoke test and `checkcode`, then:

```powershell
git add -- experiments/run_simulink_cross_validation.m tests/experiments/TestSimulinkCrossValidation.m
git commit -m "feat: add Simulink cross-validation study"
```

---

### Task 6: Full Evidence, Documentation, and Verification Entry Point

**Files:**
- Modify: `scripts/verify.ps1`
- Modify: `README.md`

**Interfaces:**
- Consumes: exact formal experiment output and test count.
- Produces: documented Phase 6A evidence and one-command Phase 1–6A verification.

- [ ] **Step 1: Run the formal experiment**

Run `experiments/run_simulink_cross_validation.m` in full mode. Record exact dynamics maxima, both controller comparison metrics, success flags, saturation differences, and artifact sizes.

- [ ] **Step 2: Inspect model and figures visually**

Open the `.slx` model screenshot or render preview and all four PNG files. Verify readable block labels, signal direction, units, legends, non-clipped text, visible differences, and honest threshold scales. Fix presentation defects without changing data.

- [ ] **Step 3: Extend complete verification**

Append after Phase 5 in `scripts/verify.ps1`:

```matlab
clear outputRoot simulinkValidationMode;
run('experiments/run_simulink_cross_validation.m');
```

- [ ] **Step 4: Update README**

Document Phase 6A status, installed/licensed tools, dual validation architecture, exact formal protocol, a full numerical result table, command, model/artifact paths, result interpretation, and limitations. State explicitly that Fuzzy-PID and Simscape Multibody are deferred and no hardware claim is made.

- [ ] **Step 5: Run branch-wide verification**

Run:

```powershell
git diff --check
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); r=runtests('tests','IncludeSubfolders',true); assertSuccess(r);"
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); files=[dir(fullfile('+rrm','**','*.m'));dir(fullfile('experiments','*.m'))]; n=0; for k=1:numel(files),n=n+numel(checkcode(fullfile(files(k).folder,files(k).name),'-id'));end; fprintf('CHECKCODE_ISSUES=%d\n',n); assert(n==0);"
& '.\scripts\verify.ps1'
```

Expected: all tests pass, `CHECKCODE_ISSUES=0`, all Phase 1–6A formal experiments exit zero.

- [ ] **Step 6: Commit**

```powershell
git add -- README.md scripts/verify.ps1 models/rrm_pid_cross_validation.slx
git commit -m "docs: document Simulink cross-validation evidence"
```

Generated result files remain ignored and unstaged.

---

### Task 7: Integrate the Verified Feature Locally

**Files:**
- No content changes expected.

**Interfaces:**
- Consumes: clean fully verified Phase 6A feature branch.
- Produces: local `main` fast-forwarded to the Phase 6A tip and no owned temporary worktree/branch.

- [ ] **Step 1: Verify feature branch state**

Require a clean tracked status, confirm the feature descends from `main`, record its tip, and confirm only ignored artifacts exist beyond tracked files.

- [ ] **Step 2: Fast-forward local main**

From the main checkout run `git merge --ff-only feature/phase-6a-simulink-validation`. Do not push.

- [ ] **Step 3: Verify merged main freshly**

Run all tests, zero-issue `checkcode`, and `scripts/verify.ps1` from merged `main`. Confirm the committed model loads and the formal artifacts exist.

- [ ] **Step 4: Clean up only owned isolation**

Resolve the repository, `.worktrees` parent, and exact Phase 6A target to absolute paths. Require the target to be a child of the owned parent, inspect status, remove that worktree, prune, and delete only the merged feature branch.

- [ ] **Step 5: Final audit**

Confirm `main` points to the verified tip, the only unrelated status entry remains the user's root DOCX, model/data/figures exist, and no remote was modified.

## Plan Self-Review

- Every objective, command, structure, error path, test level, artifact, boundary, and completion criterion in the design maps to Tasks 1–7.
- The independent dynamics layer precedes the Simulink builder; the runner precedes comparison; comparison precedes formal evidence.
- Function names, arguments, result fields, model name, variable names, thresholds, and artifact paths are consistent across tasks.
- No Fuzzy-PID replication, Simscape Multibody assembly, actuator electronics, hardware validation, perception, or collision work leaks into Phase 6A.
- The plan contains no unresolved placeholders and preserves the unrelated DOCX and no-push boundary.
