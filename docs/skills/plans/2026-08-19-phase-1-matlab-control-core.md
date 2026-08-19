# Phase 1 MATLAB Control Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a tested pure-MATLAB two-link manipulator model, quintic reference, torque-limited PID simulation, metrics, and reproducible nominal experiment.

**Architecture:** Use the `+rrm` MATLAB package to keep configuration, mathematics, control, simulation, and evaluation independent. Build each physical invariant test-first, then connect the verified units through one experiment script.

**Tech Stack:** MATLAB R2026a, MATLAB Unit Test, analytical planar rigid-body dynamics, fixed-step RK4, Git.

## Global Constraints

- Use SI units and two-element finite real column vectors.
- Use only installed MathWorks products; add no third-party dependencies.
- Keep physical, controller, trajectory, and scenario parameters separate.
- Use one simulator and one metrics path for every controller.
- Write every production function only after its focused test fails for the expected missing-function reason.
- Run the full suite and nominal experiment before the final commit.

---

### Task 1: Repository Scaffold and Robot Configuration

**Files:**
- Create: `.gitignore`
- Create: `+rrm/+config/makeRobot.m`
- Create: `tests/config/TestMakeRobot.m`
- Create: `results/data/.gitkeep`
- Create: `results/figures/.gitkeep`

**Interfaces:**
- Produces: `robot = rrm.config.makeRobot(name)` with baseline physical parameters, joint limits, and torque limits.

- [ ] **Step 1: Write the failing robot-configuration test**

```matlab
classdef TestMakeRobot < matlab.unittest.TestCase
    methods (Test)
        function baselineHasConsistentPhysicalParameters(testCase)
            robot = rrm.config.makeRobot("baseline");
            testCase.verifyEqual(robot.name, "baseline");
            testCase.verifyGreaterThan([robot.L1 robot.L2 robot.m1 robot.m2], 0);
            testCase.verifyEqual(robot.com, [robot.L1; robot.L2] / 2, AbsTol=1e-14);
            testCase.verifySize(robot.jointLimits, [2 2]);
            testCase.verifySize(robot.torqueLimits, [2 1]);
        end
    end
end
```

- [ ] **Step 2: Verify RED**

Run:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "cd('E:/YZH123123/PID vs Fuzzy PID'); results=runtests('tests/config/TestMakeRobot.m'); assertSuccess(results);"
```

Expected: FAIL because `rrm.config.makeRobot` is undefined.

- [ ] **Step 3: Implement the baseline factory**

```matlab
function robot = makeRobot(name)
arguments
    name (1,1) string {mustBeMember(name,"baseline")} = "baseline"
end
robot = struct("name",name,"L1",0.45,"L2",0.35,"m1",2.0,"m2",1.5, ...
    "payload",0.5,"gravity",9.81,"com",[0.225;0.175], ...
    "inertia",[2.0*0.45^2/12;1.5*0.35^2/12], ...
    "viscousFriction",[0.05;0.04], ...
    "jointLimits",deg2rad([-170 170;-150 150]),"torqueLimits",[25;15]);
end
```

- [ ] **Step 4: Verify GREEN and commit**

Run the focused test, then commit:

```powershell
git add .gitignore +rrm tests results
git commit -m "feat: add baseline robot configuration"
```

### Task 2: Planar Forward and Inverse Kinematics

**Files:**
- Create: `+rrm/+kinematics/forward.m`
- Create: `+rrm/+kinematics/inverse.m`
- Create: `tests/kinematics/TestKinematics.m`

**Interfaces:**
- Consumes: baseline `robot` structure.
- Produces: `position = forward(robot,q)` and `[solutions,reachable] = inverse(robot,position)`.

- [ ] **Step 1: Write failing known-pose and round-trip tests**

```matlab
classdef TestKinematics < matlab.unittest.TestCase
    methods (Test)
        function forwardAtZeroIsFullyExtended(testCase)
            robot = rrm.config.makeRobot("baseline");
            p = rrm.kinematics.forward(robot,[0;0]);
            testCase.verifyEqual(p,[robot.L1+robot.L2;0],AbsTol=1e-12);
        end
        function inverseRoundTripReturnsBothBranches(testCase)
            robot = rrm.config.makeRobot("baseline");
            p = rrm.kinematics.forward(robot,deg2rad([35;-50]));
            [q,reachable] = rrm.kinematics.inverse(robot,p);
            testCase.verifyTrue(reachable);
            testCase.verifySize(q,[2 2]);
            for k = 1:2
                testCase.verifyEqual(rrm.kinematics.forward(robot,q(:,k)),p,AbsTol=1e-10);
            end
        end
        function unreachableTargetIsReported(testCase)
            robot = rrm.config.makeRobot("baseline");
            [q,reachable] = rrm.kinematics.inverse(robot,[2;0]);
            testCase.verifyFalse(reachable);
            testCase.verifyTrue(all(isnan(q),"all"));
        end
    end
end
```

- [ ] **Step 2: Verify RED** using the Task 1 command with `tests/kinematics/TestKinematics.m`.

- [ ] **Step 3: Implement analytical kinematics**

```matlab
position = [robot.L1*cos(q(1))+robot.L2*cos(sum(q));
            robot.L1*sin(q(1))+robot.L2*sin(sum(q))];
```

For inverse kinematics, compute `c2`, reject `abs(c2)>1+1e-12`, clamp roundoff to `[-1,1]`, use both signs of `sqrt(1-c2^2)`, and calculate each `q1` with the two-argument arctangent.

- [ ] **Step 4: Verify GREEN and commit** with message `feat: add analytical planar kinematics`.

### Task 3: Two-Link Dynamics and Physical Invariants

**Files:**
- Create: `+rrm/+dynamics/matrices.m`
- Create: `+rrm/+dynamics/acceleration.m`
- Create: `tests/dynamics/TestDynamics.m`

**Interfaces:**
- Produces: `[M,C,G] = matrices(robot,q,dq)` and `ddq = acceleration(robot,q,dq,tau,disturbance)`.

- [ ] **Step 1: Write failing invariant tests**

```matlab
classdef TestDynamics < matlab.unittest.TestCase
    methods (Test)
        function inertiaIsSymmetricPositiveDefinite(testCase)
            robot = rrm.config.makeRobot("baseline");
            for q2 = linspace(-pi,pi,9)
                [M,~,~] = rrm.dynamics.matrices(robot,[0.4;q2],[0.2;-0.1]);
                testCase.verifyEqual(M,M.',AbsTol=1e-12);
                testCase.verifyGreaterThan(eig(M),0);
            end
        end
        function coriolisIsZeroAtRest(testCase)
            robot = rrm.config.makeRobot("baseline");
            [~,C,~] = rrm.dynamics.matrices(robot,[0.4;-0.2],[0;0]);
            testCase.verifyEqual(C,zeros(2),AbsTol=1e-14);
        end
        function gravityCompensationHoldsAtRest(testCase)
            robot = rrm.config.makeRobot("baseline");
            q = [0.5;-0.3];
            [~,~,G] = rrm.dynamics.matrices(robot,q,[0;0]);
            ddq = rrm.dynamics.acceleration(robot,q,[0;0],G,[0;0]);
            testCase.verifyLessThan(norm(ddq),1e-10);
        end
    end
end
```

- [ ] **Step 2: Verify RED** for `tests/dynamics/TestDynamics.m`.

- [ ] **Step 3: Implement rigid-body matrices**

Use payload-aware coefficients:

```matlab
a = I1 + I2 + m1*r1^2 + m2*(L1^2+r2^2) + mp*(L1^2+L2^2);
b = m2*L1*r2 + mp*L1*L2;
d = I2 + m2*r2^2 + mp*L2^2;
M = [a+2*b*cos(q2), d+b*cos(q2); d+b*cos(q2), d];
C = [-b*sin(q2)*dq2, -b*sin(q2)*(dq1+dq2); b*sin(q2)*dq1, 0];
```

Compute gravity consistently for link centres of mass and endpoint payload. In `acceleration`, solve with `M \ rhs`; never form `inv(M)`.

- [ ] **Step 4: Verify GREEN and commit** with message `feat: add payload-aware two-link dynamics`.

### Task 4: Quintic Joint Reference

**Files:**
- Create: `+rrm/+trajectory/quintic.m`
- Create: `tests/trajectory/TestQuintic.m`

**Interfaces:**
- Produces a structure with column time vector and `2 x N` arrays `q`, `dq`, `ddq`.

- [ ] **Step 1: Write the failing endpoint test**

```matlab
classdef TestQuintic < matlab.unittest.TestCase
    methods (Test)
        function satisfiesEndpointBoundaryConditions(testCase)
            q0 = deg2rad([0;0]); qf = deg2rad([45;60]);
            ref = rrm.trajectory.quintic(q0,qf,3,0.001,5);
            testCase.verifyEqual(ref.q(:,1),q0,AbsTol=1e-12);
            testCase.verifyEqual(ref.q(:,end),qf,AbsTol=1e-12);
            testCase.verifyLessThan(max(abs(ref.dq(:,[1 end])),[],"all"),1e-10);
            testCase.verifyLessThan(max(abs(ref.ddq(:,[1 end])),[],"all"),1e-10);
            testCase.verifyEqual(ref.time(end),5,AbsTol=1e-14);
        end
    end
end
```

- [ ] **Step 2: Verify RED** for `tests/trajectory/TestQuintic.m`.

- [ ] **Step 3: Implement normalized quintic timing**

Use `s = 10*r^3-15*r^4+6*r^5`, analytical first and second derivatives, and hold `qf` with zero derivatives after `moveDuration` until `totalDuration`.

- [ ] **Step 4: Verify GREEN and commit** with message `feat: add quintic joint trajectory generation`.

### Task 5: PID, RK4 Simulation, and Safety Recording

**Files:**
- Create: `+rrm/+config/makePidController.m`
- Create: `+rrm/+config/makeSimulationOptions.m`
- Create: `+rrm/+control/pidStep.m`
- Create: `+rrm/+simulation/runPid.m`
- Create: `tests/control/TestPidStep.m`
- Create: `tests/simulation/TestRunPid.m`

**Interfaces:**
- Produces controller fields `Kp`, `Ki`, `Kd`, `derivativeFilter`, `antiWindupGain`.
- Produces `result.time`, `q`, `dq`, `qReference`, `dqReference`, `tau`, `tauUnsaturated`, `saturated`, and `status`.

- [ ] **Step 1: Write failing PID saturation test**

```matlab
function saturationIsAppliedAndRecorded(testCase)
robot = rrm.config.makeRobot("baseline");
controller = rrm.config.makePidController(robot);
state = struct("integral",[0;0],"filteredDerivative",[0;0]);
[tau,next,diagnostic] = rrm.control.pidStep(controller,robot,[10;10],[0;0],[0;0],state,0.001);
testCase.verifyLessThanOrEqual(abs(tau),robot.torqueLimits);
testCase.verifyTrue(any(diagnostic.saturated));
testCase.verifySize(next.integral,[2 1]);
end
```

- [ ] **Step 2: Verify RED**, implement the minimal PID step with back-calculation anti-windup, and verify GREEN.

- [ ] **Step 3: Write failing integration test** asserting finite arrays, matching dimensions, torque bounds, and no joint-limit failure for the nominal reference.

- [ ] **Step 4: Verify RED**, then implement RK4 plant propagation while evaluating controller once per sample and recording saturation. Terminate with a named status on non-finite state or joint-limit violation.

- [ ] **Step 5: Tune only the default configuration values needed to satisfy the written success criteria; do not change test tolerances to fit poor behavior.**

- [ ] **Step 6: Verify all focused tests and commit** with message `feat: add torque-limited PID simulation`.

### Task 6: Metrics, Experiment, Verification Script, and README

**Files:**
- Create: `+rrm/+metrics/evaluate.m`
- Create: `tests/metrics/TestEvaluate.m`
- Create: `experiments/run_nominal_pid.m`
- Create: `tests/experiments/TestNominalExperiment.m`
- Create: `scripts/verify.ps1`
- Create: `README.md`

**Interfaces:**
- Produces metrics `rmsError`, `maxAbsError`, `steadyStateRmsError`, `controlRms`, `controlEnergy`, `saturationTime`, and `success`.

- [ ] **Step 1: Write a failing hand-calculated metric test**

```matlab
result.time = [0;1;2];
result.q = [0 1 2;0 0 0];
result.qReference = [0 2 2;0 1 0];
result.tau = [1 1 1;2 2 2];
result.saturated = false(2,3);
result.status = "completed";
metrics = rrm.metrics.evaluate(result,rrm.config.makeRobot("baseline"),criteria);
testCase.verifyEqual(metrics.rmsError,sqrt([1/3;1/3]),AbsTol=1e-12);
```

- [ ] **Step 2: Verify RED**, implement metrics with trapezoidal integration, and verify GREEN.

- [ ] **Step 3: Write a failing experiment-output test** that runs the script in a temporary output directory and expects one MAT file and two PNG figures.

- [ ] **Step 4: Verify RED**, implement the experiment script using only public package interfaces, and verify GREEN.

- [ ] **Step 5: Add `scripts/verify.ps1`** that runs the full test suite and nominal experiment using the exact MATLAB path.

- [ ] **Step 6: Write README** covering scope, prerequisites, commands, architecture, mathematical model, generated outputs, deferred scope, and simulation-only limitations.

- [ ] **Step 7: Run final verification**

```powershell
& '.\scripts\verify.ps1'
```

Expected: MATLAB exits 0, all tests pass, nominal metrics meet the specification, and expected artifacts exist.

- [ ] **Step 8: Inspect Git scope and commit**

```powershell
git diff --check
git status --short
git add +rrm tests experiments scripts README.md .gitignore results
git commit -m "feat: deliver verified nominal PID research baseline"
```

## Plan Self-Review

- Every Phase 1 specification requirement maps to Tasks 1–6.
- Public names are consistent across tasks: `makeRobot`, `forward`, `inverse`, `matrices`, `acceleration`, `quintic`, `makePidController`, `makeSimulationOptions`, `pidStep`, `runPid`, and `evaluate`.
- Deferred Fuzzy-PID, `fmincon`, robustness sweeps, Cartesian tracking, and Simulink work do not leak into Phase 1.
- No third-party dependencies, placeholders, or unspecified implementation steps are required for Phase 1.
