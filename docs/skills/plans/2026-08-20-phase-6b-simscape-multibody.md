# Phase 6B Simscape Multibody Physical Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a torque-driven three-dimensional Simscape Multibody model of the baseline two-link arm, compare two frozen PID executions with MATLAB RK4, and publish reproducible numerical and animation evidence.

**Architecture:** A deterministic builder copies the Phase 6A Reference and PID Controller subsystems into a new standalone model and creates an independent Multibody plant from native bodies, transforms, revolute joints, physical-signal converters, and sensors. A runner injects parameters through `Simulink.SimulationInput`; a comparison module evaluates q, dq, torque, end-effector, saturation, and completion thresholds; an experiment owns MAT, CSV, PNG, and MP4 output.

**Tech Stack:** MATLAB R2026a Update 4, Simulink, Simscape, Simscape Multibody, MATLAB Unit Test, `VideoWriter`, PowerShell, Git worktrees.

## Global Constraints

- Preserve the Phase 1–6A baseline robot, controller gains, reference definitions, and performance criteria.
- Formal protocol: baseline robot, `[0;0]` to `[45;60] deg`, 3 s quintic move plus 2 s hold, 1 ms fixed-step `ode4`, zero disturbance and measurement noise.
- Physical network: two parallel positive-z Revolute Joints, gravity `[0 -g 0] m/s^2`, exact link mass/z-inertia, endpoint point mass, and joint damping equal to `robot.viscousFriction`.
- Frozen thresholds: q RMS `1e-3 rad`, q max `5e-3 rad`, dq RMS `2e-2 rad/s`, torque RMS `2e-1 N m`, end-effector RMS `1e-3 m`, end-effector max `5e-3 m`, saturation-time difference `5e-3 s`.
- The Multibody plant never calls project dynamics or simulation functions and never uses prescribed joint motion as validation evidence.
- No external CAD, meshes, third-party packages, Fuzzy-PID replication, contact, gripper, motor electrical model, hardware, push, or pull request.
- Generated MAT, CSV, PNG, and MP4 artifacts remain ignored; the builder and generated `.slx` are committed.
- Preserve `Daniel_MATLAB_Robotics_Project_Implementation_Guide.docx` unchanged and untracked.
- Use TDD for every logic increment, run focused tests before each commit, then full verification before integration.

## File Map

```text
+rrm/+multibody/buildCrossValidationModel.m  Deterministic standalone model builder
+rrm/+multibody/runCrossValidation.m         Input validation, SimulationInput, log normalization
+rrm/+multibody/compareRuns.m                Frozen quantitative equivalence checks
models/rrm_multibody_cross_validation.slx    Committed generated physical model
tests/multibody/TestBuildCrossValidationModel.m
tests/multibody/TestRunCrossValidation.m
tests/multibody/TestCompareRuns.m
tests/experiments/TestMultibodyCrossValidation.m
experiments/run_multibody_cross_validation.m Formal/smoke study and artifacts
scripts/verify.ps1                           Phase 1–6B one-command verification
README.md                                    Protocol, evidence, limitations, commands
```

---

### Task 1: Capability Guard and Deterministic Model Shell

**Files:**
- Create: `+rrm/+multibody/buildCrossValidationModel.m`
- Create: `tests/multibody/TestBuildCrossValidationModel.m`
- Create: `models/rrm_multibody_cross_validation.slx`

**Interfaces:**
- Consumes: Phase 6A model at `models/rrm_pid_cross_validation.slx`.
- Produces: `modelName = rrm.multibody.buildCrossValidationModel(modelPath)` where `modelPath` is a scalar string and `modelName` is the generated scalar model name.

- [ ] **Step 1: Write failing capability, path, and shell tests**

```matlab
classdef TestBuildCrossValidationModel < matlab.unittest.TestCase
    methods (Test)
        function buildsStandalonePhysicalShell(testCase)
            directory = tempname;
            mkdir(directory);
            testCase.addTeardown(@() removeDirectory(directory));
            modelPath = fullfile(directory,"rrm_mb_test.slx");

            modelName = rrm.multibody.buildCrossValidationModel(modelPath);
            cleanup = onCleanup(@() closeLoadedModel(modelName)); %#ok<NASGU>

            testCase.verifyTrue(isfile(modelPath));
            testCase.verifyEqual(get_param(modelName,"Solver"),"ode4");
            testCase.verifyEqual(get_param(modelName,"SolverType"),"Fixed-step");
            testCase.verifyEqual(get_param(modelName,"FixedStep"),"0.001");
            required = ["Reference","PID Controller","Multibody Plant","Logging"];
            for name = required
                testCase.verifyNotEmpty(find_system(modelName, ...
                    "SearchDepth",1,"Name",name));
            end
        end

        function rejectsNonSlxPath(testCase)
            testCase.verifyError(@() ...
                rrm.multibody.buildCrossValidationModel("invalid.mat"), ...
                "rrm:multibody:InvalidModelPath");
        end

        function relativePathResolvesUnderProjectRoot(testCase)
            relative = fullfile("models","rrm_mb_relative_test.slx");
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            expected = fullfile(projectRoot,relative);
            cleanup = onCleanup(@() deleteIfPresent(expected)); %#ok<NASGU>
            temporary = tempname;
            mkdir(temporary);
            original = cd(temporary);
            folderCleanup = onCleanup(@() restoreAndRemove(original,temporary)); %#ok<NASGU>

            modelName = rrm.multibody.buildCrossValidationModel(relative);
            closeLoadedModel(modelName);

            testCase.verifyTrue(isfile(expected));
            testCase.verifyFalse(isfile(fullfile(temporary,relative)));
        end
    end
end
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests('tests/multibody/TestBuildCrossValidationModel.m'); assertSuccess(results);"
```

Expected: FAIL because `rrm.multibody.buildCrossValidationModel` does not exist.

- [ ] **Step 3: Implement the model shell and capability guard**

Implement these behaviors in `buildCrossValidationModel.m`:

```matlab
function modelName = buildCrossValidationModel(modelPath)
arguments
    modelPath (1,1) string
end
if isempty(which("smnew")) || isempty(which("sm_lib")) || ...
        ~license("test","SimMechanics")
    error("rrm:multibody:MissingMultibody", ...
        "Simscape Multibody must be installed and licensed.");
end
modelPath = resolveModelPath(modelPath);
[~,name] = fileparts(modelPath);
modelName = string(name);
sourceModelPath = fullfile(projectRoot(),"models", ...
    "rrm_pid_cross_validation.slx");
if ~isfile(sourceModelPath)
    error("rrm:multibody:MissingSourceModel", ...
        "The verified Phase 6A source model is required.");
end
% Create with smnew, clear template contents, add four top-level subsystems,
% copy Reference/PID contents, assign defaults, annotate, and save.
end
```

Use `java.io.File(...).getCanonicalPath()` as in the Phase 6A builder, delete only the exact validated target model, and use `onCleanup` to close loaded models.

- [ ] **Step 4: Generate the committed shell and verify GREEN**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); rrm.multibody.buildCrossValidationModel(fullfile('models','rrm_multibody_cross_validation.slx')); results=runtests('tests/multibody/TestBuildCrossValidationModel.m'); assertSuccess(results);"
```

Expected: all shell tests pass and the model loads from a fresh MATLAB process.

- [ ] **Step 5: Commit the shell**

```powershell
git add -- '+rrm/+multibody/buildCrossValidationModel.m' 'tests/multibody/TestBuildCrossValidationModel.m' 'models/rrm_multibody_cross_validation.slx'
git commit -m "feat: scaffold Multibody validation model"
```

---

### Task 2: Auditable Physical Assembly

**Files:**
- Modify: `+rrm/+multibody/buildCrossValidationModel.m`
- Modify: `tests/multibody/TestBuildCrossValidationModel.m`
- Modify: `models/rrm_multibody_cross_validation.slx`

**Interfaces:**
- Consumes: builder shell and baseline `rrm.config.makeRobot("baseline")`.
- Produces: a Multibody Plant containing exact named blocks and model-workspace variables `rrmMbGravity`, `rrmMbLinkMass`, `rrmMbLinkInertia`, `rrmMbLinkLength`, `rrmMbPayload`, `rrmMbDamping`, and `rrmInitialQ`.

- [ ] **Step 1: Add failing physical-structure tests**

Add assertions after loading the temporary model:

```matlab
plant = modelName + "/Multibody Plant";
testCase.verifyEqual(numel(find_system(plant, ...
    "LookUnderMasks","all","Name","Revolute Joint 1")),1);
testCase.verifyEqual(numel(find_system(plant, ...
    "LookUnderMasks","all","Name","Revolute Joint 2")),1);
testCase.verifyEqual(get_param(plant+"/Mechanism Configuration", ...
    "GravityVector"),"[0 -rrmGravity 0]");
testCase.verifyEqual(get_param(plant+"/Revolute Joint 1", ...
    "TorqueActuationMode"),"Provided by Input");
testCase.verifyEqual(get_param(plant+"/Revolute Joint 1", ...
    "SensePosition"),"on");
testCase.verifyEqual(get_param(plant+"/Revolute Joint 1", ...
    "SenseVelocity"),"on");
testCase.verifyEqual(get_param(plant+"/Torque 1", ...
    "Unit"),"N*m");
testCase.verifyEqual(get_param(plant+"/Position 1", ...
    "Unit"),"rad");
testCase.verifyEqual(get_param(plant+"/Velocity 1", ...
    "Unit"),"rad/s");
testCase.verifyNotEmpty(find_system(plant, ...
    "LookUnderMasks","all","Name","End Effector Sensor"));
set_param(modelName,"SimulationCommand","update");
```

Read the model workspace and verify the baseline values:

```matlab
workspace = get_param(modelName,"ModelWorkspace");
testCase.verifyEqual(getVariable(workspace,"rrmMbLinkLength"),[0.45;0.35]);
testCase.verifyEqual(getVariable(workspace,"rrmMbLinkMass"),[2.0;1.5]);
testCase.verifyEqual(getVariable(workspace,"rrmMbPayload"),0.5);
testCase.verifyEqual(getVariable(workspace,"rrmMbDamping"),[0.08;0.05]);
```

- [ ] **Step 2: Run structure tests and verify RED**

Expected: FAIL on the first missing joint or physical block.

- [ ] **Step 3: Build the exact physical network**

Inside the Multibody Plant, create:

```text
World Frame
Mechanism Configuration
Solver Configuration
Base Solid
Revolute Joint 1
Link 1 Center Transform
Link 1 Solid
Link 1 Distal Transform
Revolute Joint 2
Link 2 Center Transform
Link 2 Solid
Link 2 Distal Transform
Payload Inertia
End Effector Sensor
Torque 1, Torque 2
Position 1, Position 2
Velocity 1, Velocity 2
```

Configure both joints with:

```matlab
set_param(jointPath, ...
    "TorqueActuationMode","Provided by Input", ...
    "MotionActuationMode","Automatically Computed", ...
    "SensePosition","on", ...
    "SenseVelocity","on", ...
    "PositionTargetSpecify","on", ...
    "PositionTargetValue",sprintf("rrmInitialQ(%d)",joint), ...
    "PositionTargetValueUnits","rad", ...
    "DampingCoefficient",sprintf("rrmMbDamping(%d)",joint), ...
    "DampingCoefficientUnits","N*m/(rad/s)");
```

Configure each link solid with custom mass properties centered at its reference frame:

```matlab
set_param(solidPath, ...
    "BrickDimensions",sprintf("[rrmMbLinkLength(%d) rrmMbWidth rrmMbWidth]",joint), ...
    "BrickDimensionsUnits","m", ...
    "InertiaType","Custom", ...
    "Mass",sprintf("rrmMbLinkMass(%d)",joint), ...
    "MassUnits","kg", ...
    "CenterOfMass","[0 0 0]", ...
    "CenterOfMassUnits","m", ...
    "MomentsOfInertia",sprintf("rrmMbMoments(%d,:)",joint), ...
    "MomentsOfInertiaUnits","kg*m^2", ...
    "ProductsOfInertia","[0 0 0]", ...
    "ProductsOfInertiaUnits","kg*m^2");
```

Set `rrmMbMoments(j,:) = [max(1e-6,0.01*I(j)), I(j), I(j)]`. Offset each solid center by `L/2` and the distal frame by `L` along +x. Configure payload Inertia as point mass and attach it at the second distal frame. Connect the Transform Sensor between World and the payload frame and expose Cartesian x/y/z.

- [ ] **Step 4: Compile and inspect block parameters**

Run the focused builder tests and a fresh-process model update. Expected: no assembly, unit, or unconnected-port error.

- [ ] **Step 5: Commit the physical assembly**

```powershell
git add -- '+rrm/+multibody/buildCrossValidationModel.m' 'tests/multibody/TestBuildCrossValidationModel.m' 'models/rrm_multibody_cross_validation.slx'
git commit -m "feat: assemble physical two-link Multibody plant"
```

---

### Task 3: Simulation Runner and Log Normalization

**Files:**
- Create: `+rrm/+multibody/runCrossValidation.m`
- Create: `tests/multibody/TestRunCrossValidation.m`
- Modify: `+rrm/+multibody/buildCrossValidationModel.m`
- Modify: `models/rrm_multibody_cross_validation.slx`

**Interfaces:**
- Consumes: `robot`, fixed-gain PID `controller`, quintic `reference`, simulation `options`, and model path.
- Produces: `result = rrm.multibody.runCrossValidation(robot,controller,reference,options,modelPath)` with `time`, `q`, `dq`, `qReference`, `dqReference`, `tau`, `tauUnsaturated`, `saturated`, `endEffectorPosition`, `status`, `completedSamples`, and `modelName`.

- [ ] **Step 1: Write failing runner tests**

```matlab
classdef TestRunCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function shortRunIsFiniteAndAligned(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            before = evalin("base","who");

            result = rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath);

            testCase.verifyEqual(result.time,reference.time,"AbsTol",0);
            testCase.verifySize(result.q,size(reference.q));
            testCase.verifySize(result.dq,size(reference.dq));
            testCase.verifySize(result.tau,size(reference.q));
            testCase.verifySize(result.endEffectorPosition,[3 numel(reference.time)]);
            testCase.verifyTrue(all(isfinite([result.q;result.dq; ...
                result.tau;result.endEffectorPosition]),"all"));
            testCase.verifyEqual(result.status,"completed");
            testCase.verifyEqual(evalin("base","who"),before);
        end

        function rejectsFuzzyController(testCase)
            [robot,~,reference,options,modelPath] = inputs();
            fuzzy = rrm.config.makeFuzzyPidController(robot);
            testCase.verifyError(@() rrm.multibody.runCrossValidation( ...
                robot,fuzzy,reference,options,modelPath), ...
                "rrm:multibody:UnsupportedController");
        end

        function rejectsDisturbanceEnvironment(testCase)
            [robot,controller,reference,options,modelPath] = inputs();
            options.disturbanceTorque = [1;0];
            testCase.verifyError(@() rrm.multibody.runCrossValidation( ...
                robot,controller,reference,options,modelPath), ...
                "rrm:multibody:UnsupportedEnvironment");
        end
    end
end
```

- [ ] **Step 2: Run tests and verify RED**

Expected: FAIL because `runCrossValidation` is undefined.

- [ ] **Step 3: Implement input validation and SimulationInput setup**

Mirror the Phase 6A validation rules with `rrm:multibody:*` identifiers. Set model variables through the model workspace only:

```matlab
simulationInput = setVariable(simulationInput,"rrmSampleTime",sampleTime, ...
    Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmQReferenceSignal", ...
    timeseries(reference.q.',reference.time),Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmDqReferenceSignal", ...
    timeseries(reference.dq.',reference.time),Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmKp",controller.Kp, ...
    Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmMbLinkLength", ...
    [robot.L1;robot.L2],Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmMbLinkMass", ...
    [robot.m1;robot.m2],Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmMbLinkInertia", ...
    robot.inertia,Workspace=modelName);
simulationInput = setVariable(simulationInput,"rrmMbPayload", ...
    robot.payload,Workspace=modelName);
```

Disable Multibody Explorer opening only around automated `sim`, restore the previous preference with `onCleanup`, and suppress only the known toolchain warning already handled by Phase 6A.

- [ ] **Step 4: Normalize and validate logs**

Read named logs `q`, `dq`, `tau`, `tauUnsaturated`, and `endEffectorPosition`. Convert every history to row-per-channel form, require exact time-grid equality, derive saturation from unsaturated/applied torque, and raise `rrm:multibody:NonFiniteOutput` for any non-finite sample.

- [ ] **Step 5: Run runner tests and verify GREEN**

Expected: all runner tests pass twice from a clean MATLAB process with no base-workspace changes or leaked warning preferences.

- [ ] **Step 6: Commit the runner**

```powershell
git add -- '+rrm/+multibody/runCrossValidation.m' '+rrm/+multibody/buildCrossValidationModel.m' 'tests/multibody/TestRunCrossValidation.m' 'models/rrm_multibody_cross_validation.slx'
git commit -m "feat: execute torque-driven Multibody validation"
```

---

### Task 4: Frozen Numerical Comparison

**Files:**
- Create: `+rrm/+multibody/compareRuns.m`
- Create: `tests/multibody/TestCompareRuns.m`

**Interfaces:**
- Consumes: MATLAB run, Multibody run, and robot struct.
- Produces: comparison struct with raw differences, RMS/max metrics, saturation times, thresholds, per-metric flags, aggregate `pass`, and `failureSummary`.

- [ ] **Step 1: Write synthetic comparison tests**

```matlab
classdef TestCompareRuns < matlab.unittest.TestCase
    methods (Test)
        function exactCopiesPass(testCase)
            robot = rrm.config.makeRobot("baseline");
            matlabRun = syntheticRun(robot);
            multibodyRun = matlabRun;
            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);
            testCase.verifyTrue(comparison.pass);
            testCase.verifyEqual(comparison.endEffectorRmsDifference,0);
            testCase.verifyEqual(comparison.failureSummary,"");
        end

        function endEffectorSpikeFailsFrozenLimit(testCase)
            robot = rrm.config.makeRobot("baseline");
            matlabRun = syntheticRun(robot);
            multibodyRun = matlabRun;
            multibodyRun.endEffectorPosition(1,3) = 6e-3;
            comparison = rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot);
            testCase.verifyFalse(comparison.flags.endEffectorMax);
            testCase.verifyTrue(contains(comparison.failureSummary,"ee-max"));
        end

        function shiftedTimeRaisesStableError(testCase)
            robot = rrm.config.makeRobot("baseline");
            matlabRun = syntheticRun(robot);
            multibodyRun = matlabRun;
            multibodyRun.time = multibodyRun.time + 0.001;
            testCase.verifyError(@() rrm.multibody.compareRuns( ...
                matlabRun,multibodyRun,robot), ...
                "rrm:multibody:TimeGridMismatch");
        end
    end
end
```

- [ ] **Step 2: Run tests and verify RED**

Expected: FAIL because `compareRuns` is undefined.

- [ ] **Step 3: Implement frozen thresholds and metrics**

Use:

```matlab
thresholds = struct( ...
    "qRms",1e-3,"qMax",5e-3, ...
    "dqRms",2e-2,"tauRms",2e-1, ...
    "endEffectorRms",1e-3,"endEffectorMax",5e-3, ...
    "saturationTime",5e-3);
```

Compute the MATLAB end-effector position independently from every MATLAB q sample with `rrm.kinematics.forward`. Require Multibody z to remain within `1e-9 m` of zero and include a `planar` flag. Build `failureSummary` from stable tokens such as `q-rms-j1`, `dq-rms-j2`, `tau-rms-j1`, `ee-rms`, `ee-max`, `planar`, `saturation-j2`, and `completed`.

- [ ] **Step 4: Run synthetic and real short comparisons**

Run all comparison tests, then a 0.12 s manual PID MATLAB/Multibody pair. Print every metric before asserting `comparison.pass` so a physical mismatch remains diagnosable.

- [ ] **Step 5: Commit the comparison layer**

```powershell
git add -- '+rrm/+multibody/compareRuns.m' 'tests/multibody/TestCompareRuns.m'
git commit -m "feat: quantify Multibody execution agreement"
```

---

### Task 5: Reproducible Study, Figures, and Animation

**Files:**
- Create: `experiments/run_multibody_cross_validation.m`
- Create: `tests/experiments/TestMultibodyCrossValidation.m`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: builder, runner, comparison, existing metrics, manual PID, optimized PID.
- Produces: two-row run table, MAT/CSV evidence, five PNG artifacts, and one manual-PID MP4 in full mode.

- [ ] **Step 1: Write failing smoke-experiment test**

```matlab
classdef TestMultibodyCrossValidation < matlab.unittest.TestCase
    methods (Test)
        function smokeModeCreatesCompleteEvidence(testCase)
            projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
            outputRoot = tempname;
            mkdir(outputRoot);
            testCase.addTeardown(@() rmdir(outputRoot,"s"));
            multibodyValidationMode = "smoke";

            run(fullfile(projectRoot,"experiments", ...
                "run_multibody_cross_validation.m"));

            saved = load(fullfile(outputRoot,"data", ...
                "multibody_cross_validation.mat"));
            testCase.verifyEqual(height(saved.runTable),2);
            testCase.verifyEqual(saved.runTable.Controller, ...
                ["manual-pid";"optimization-pid"]);
            testCase.verifyTrue(all(saved.runTable.AgreementPass));
            for suffix = ["tracking","path","torque","summary","model"]
                file = dir(fullfile(outputRoot,"figures", ...
                    "multibody_cross_validation_"+suffix+".png"));
                testCase.verifyEqual(numel(file),1);
                testCase.verifyGreaterThan(file.bytes,0);
            end
            testCase.verifyFalse(isfolder(fullfile(outputRoot,"videos")));
        end
    end
end
```

- [ ] **Step 2: Run smoke test and verify RED**

Expected: FAIL because the experiment script does not exist.

- [ ] **Step 3: Implement exact formal/smoke orchestration**

Use exact controller construction that replaces any caller-workspace array:

```matlab
controllerDefinitions = struct( ...
    "name",{"manual-pid","optimization-pid"}, ...
    "controller",{rrm.config.makePidController(robot), ...
    rrm.config.makeOptimizedPidController(robot)});
```

Smoke protocol is `[0;0]` to `[45;60] deg`, 0.08 s move, 0.12 s total, 1 ms, and no video. Full protocol uses 3 s/5 s and requires video. Save a table with statuses, agreement/tracking flags, per-joint q/dq/tau metrics, end-effector RMS/max, saturation times, and Multibody steady-state metrics.

- [ ] **Step 4: Implement evidence figures**

Create:

- tracking: 2-by-2 q reference/MATLAB/Multibody overlays;
- path: two 3-D end-effector path comparisons with start/end markers and equal axes;
- torque: 2-by-2 torque overlays and actuator limits;
- summary: normalized q RMS, q max, dq RMS, tau RMS, EE RMS, and EE max with an acceptance boundary at one;
- model: exported top-level Simulink block diagram.

Every axis must include units, every curve a legend, every title a controller name, and logarithmic axes must clamp zero at `eps` without changing saved numeric data.

- [ ] **Step 5: Add formal animation export**

In full mode, create `results/videos` and export the manual-PID Multibody joint log as a deterministic 1280-by-720, 30 fps MPEG-4. The originally planned call was:

```matlab
smwritevideo(char(modelName),char(videoPath), ...
    "PlaybackSpeedRatio",1, ...
    "FrameRate",30, ...
    "VideoFormat","mpeg-4", ...
    "FrameSize",[1280 720]);
```

During execution on R2026a Update 4, the new Multibody Explorer backend created locked zero-byte output and crashed `physmod_sm_gui_app_video.dll` during batch shutdown for both MPEG-4 and AVI. Per the systematic-debugging stop rule, automated export was changed to `rrm.multibody.writeVideo`, which uses the completed Multibody joint log and tested MATLAB `VideoWriter` codec instead of invoking the unstable Explorer video DLL. Interactive Multibody Explorer visualization remains available.

Require a nonempty MP4 afterward; otherwise throw `rrm:experiment:MultibodyVideoExportFailed`. Add `*.avi`, `*.mp4`, and generated Multibody cache files to `.gitignore` without ignoring `.slx`.

- [ ] **Step 6: Run smoke test and static analysis**

Expected: smoke evidence passes without video or open viewers; `checkcode` reports zero issues for all `+rrm` and experiment `.m` files.

- [ ] **Step 7: Commit the experiment**

```powershell
git add -- 'experiments/run_multibody_cross_validation.m' 'tests/experiments/TestMultibodyCrossValidation.m' '.gitignore'
git commit -m "feat: add Multibody cross-validation study"
```

---

### Task 6: Formal Evidence, Documentation, and One-Command Verification

**Files:**
- Modify: `README.md`
- Modify: `scripts/verify.ps1`
- Modify when visual QA requires deterministic layout correction: `+rrm/+multibody/buildCrossValidationModel.m`
- Modify when visual QA requires figure layout correction: `experiments/run_multibody_cross_validation.m`
- Regenerate: `models/rrm_multibody_cross_validation.slx`

**Interfaces:**
- Consumes: complete Phase 6B implementation.
- Produces: documented results and Phase 1–6B verification from one PowerShell command.

- [ ] **Step 1: Run formal Phase 6B experiment**

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_multibody_cross_validation.m');"
```

Expected: two completed agreement/tracking rows, MAT/CSV, five PNGs, and one nonempty MP4.

- [ ] **Step 2: Perform visual QA**

Inspect the committed model diagram, all PNGs, and representative frames at start, mid-motion, and final hold. Correct only deterministic layout, label, color, camera, frame, or plot presentation defects; rerun focused tests after any correction.

- [ ] **Step 3: Document exact evidence**

Update README status through Phase 6B, requirements, quick-start command, repository map, model architecture, fixed protocol, full numerical result table, animation path, interpretation, and limitations. Explicitly state that Fuzzy-PID, contact/grasp physics, electronics, and hardware remain unvalidated.

- [ ] **Step 4: Extend the verification script**

Append after Phase 6A:

```matlab
clear outputRoot multibodyValidationMode controllerDefinitions;
run('experiments/run_multibody_cross_validation.m');
```

- [ ] **Step 5: Verify evidence semantics**

Load MAT and CSV, require identical variable names, row counts, controller order, numeric values within CSV precision, and all formal agreement/tracking flags true. Load and update the committed model from a fresh MATLAB process.

- [ ] **Step 6: Run complete branch verification**

```powershell
& '.\scripts\verify.ps1'
```

Then run full static analysis and `git diff --check`. Expected: all tests and every Phase 1–6B formal experiment pass; checkcode issues are zero; worktree is clean after the documentation commit.

- [ ] **Step 7: Commit formal evidence documentation**

```powershell
git add -- 'README.md' 'scripts/verify.ps1' '+rrm/+multibody/buildCrossValidationModel.m' 'experiments/run_multibody_cross_validation.m' 'models/rrm_multibody_cross_validation.slx'
git commit -m "docs: document Multibody validation evidence"
```

---

### Task 7: Integration and Safe Cleanup

**Files:**
- No source edits expected.

**Interfaces:**
- Consumes: clean verified feature branch.
- Produces: local `main` at the Phase 6B tip, generated artifacts in the main checkout, and no owned temporary worktree/branch.

- [ ] **Step 1: Confirm integration preconditions**

Require feature status clean, main containing only the unrelated untracked DOCX, merge base equal to the Phase 6B design/plan tip, and no remote write requirement.

- [ ] **Step 2: Fast-forward main locally**

From `E:\YZH123123\PID vs Fuzzy PID`:

```powershell
git merge --ff-only feature/phase-6b-multibody-validation
```

- [ ] **Step 3: Verify merged main**

Run `scripts/verify.ps1`, full checkcode, model update, MAT/CSV semantic comparison, artifact size checks, `git diff --check`, and status inspection from merged main.

- [ ] **Step 4: Remove only the owned worktree and merged branch**

Resolve `E:\YZH123123\PID vs Fuzzy PID\.worktrees\phase-6b-multibody-validation` and require it to be an exact child of the resolved `.worktrees` parent. Inspect status, run `git worktree remove` from main, prune, then delete only `feature/phase-6b-multibody-validation` with `git branch -d`.

- [ ] **Step 5: Final handoff**

Report commit, test count, checkcode count, model compilation, exact worst metrics, artifact links, animation link, no remote push, DOCX preservation, and the next recommended project milestone.

## Plan Self-Review

- Spec coverage: every objective, physical component, signal, threshold, artifact, command, error boundary, visual requirement, and cleanup rule maps to Tasks 1–7.
- Placeholder scan: no deferred implementation wording, undefined helper contract, or unresolved threshold remains.
- Type consistency: builder, runner, comparison, experiment, test, and artifact names match the Phase 6B design exactly.
- Scope: the plan produces one independently testable physical validation subsystem; Fuzzy-PID, contact, electronics, and hardware remain explicitly out of scope.
