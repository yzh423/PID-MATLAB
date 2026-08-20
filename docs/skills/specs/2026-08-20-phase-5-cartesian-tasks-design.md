# Phase 5 Cartesian Tasks Design

## Objective

Extend the verified planar two-link study from joint-space commands to high-level Cartesian commands without changing the low-level controller architectures. Phase 5 must generate a smooth straight-line end-effector path and a simplified pick-transfer-place waypoint sequence, convert both to continuous joint references, run the frozen manual PID, Mamdani Fuzzy-PID, and optimization-tuned PID fairly, and report joint, Cartesian, effort, waypoint, and success evidence.

This phase answers: given reachable Cartesian task commands from a hypothetical high-level planner, can the existing low-level controllers execute them accurately and without actuator saturation? It does not add perception, grasp planning, collision avoidance, or operational-space control.

## Verified Input Baseline

Phase 5 starts only from the freshly revalidated Phase 1-4B baseline:

- the full verification script completes successfully;
- Phase 3 `fmincon` tuning is deterministic and uses only the nominal 0.5 kg training condition;
- the held-out 0.8 kg condition is evaluated only after tuning;
- the nominal objective is `0.20242679946 -> 0.187683756347` (7.283148% reduction);
- the held-out objective is `0.214503632164 -> 0.197284004916` (8.027662% reduction);
- both optimized runs have zero saturation;
- Phase 4A and 4B reuse frozen controller gains and never rerun the optimizer.

The result remains a local, single-start tuning result rather than evidence of a global optimum.

## Technology and Dependencies

- MATLAB R2026a at `E:\MATLAB2026\bin\matlab.exe`.
- Existing project-owned `+rrm` dynamics, simulation, controller, and metrics packages.
- MATLAB Unit Test.
- No new third-party packages or toolbox requirements.
- Fixed-step simulation at `0.001 s` for formal experiments.

## Commands

Run all tests:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); results=runtests('tests','IncludeSubfolders',true); assertSuccess(results);"
```

Run the Phase 5 experiment:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); run('experiments/run_cartesian_tasks.m');"
```

Run the complete project verification:

```powershell
& '.\scripts\verify.ps1'
```

Run static analysis:

```powershell
& 'E:\MATLAB2026\bin\matlab.exe' -batch "addpath(pwd); files=[dir(fullfile('+rrm','**','*.m')); dir(fullfile('experiments','*.m'))]; issues=0; for k=1:numel(files), issues=issues+numel(checkcode(fullfile(files(k).folder,files(k).name),'-id')); end; assert(issues==0);"
```

## Selected Approach

Three implementation approaches were considered:

1. Solve position IK at every sample and numerically differentiate joint angles. This is small but creates derivative noise and endpoint artifacts.
2. Generate analytically smooth Cartesian position, velocity, and acceleration; select a continuous analytical IK branch; then map differential motion with the manipulator Jacobian. This is selected because it preserves reference smoothness and the existing controller comparison.
3. Add direct operational-space control. This changes the controller architecture and research question, so it is deferred.

## Architecture and Data Flow

```text
Cartesian task command
  -> Cartesian quintic segment(s)
  -> position / velocity / acceleration path
  -> continuous analytical IK branch selection
  -> Jacobian and Jacobian-rate differential mapping
  -> q / dq / ddq reference
  -> existing shared runController simulator
  -> true joint and end-effector histories
  -> common + Cartesian task metrics
  -> MAT / CSV / PNG evidence
```

The path is generated once per task. All controllers receive the exact same reference arrays and robot model. No controller is tuned or adapted offline for either task.

## Components and Interfaces

### Differential kinematics

`rrm.kinematics.jacobian(robot,q)` returns the planar `2 x 2` geometric Jacobian.

`rrm.kinematics.jacobianDot(robot,q,dq)` returns its time derivative. Both functions accept finite real `2 x 1` joint vectors.

### Cartesian segment generation

`rrm.trajectory.cartesianQuintic(p0,pf,moveDuration,sampleTime,totalDuration)` returns:

```matlab
path = struct( ...
    "time", time, ...                 % N-by-1 seconds
    "position", position, ...         % 2-by-N metres
    "velocity", velocity, ...         % 2-by-N metres/second
    "acceleration", acceleration);    % 2-by-N metres/second^2
```

It uses the same scalar rest-to-rest quintic law as the joint trajectory and holds the final point when `totalDuration > moveDuration`.

### Multi-waypoint Cartesian path

`rrm.trajectory.cartesianWaypoints(points,moveDurations,dwellDurations,sampleTime)` joins rest-to-rest Cartesian quintic segments without duplicated time samples. `points` is `2 x M`; `moveDurations` and `dwellDurations` are `(M-1) x 1`, where each dwell follows the corresponding arrival point. It returns the standard path fields plus exact arrival and dwell-end indices.

Because every segment starts and ends at rest, position, velocity, and acceleration are continuous at every join. All durations must be positive or nonnegative as appropriate and exact integer multiples of the sample time.

### Cartesian-to-joint conversion

`rrm.trajectory.cartesianToJoint(robot,path,initialJoint)` returns a simulator-compatible reference with `time`, `q`, `dq`, and `ddq`, and retains the source Cartesian path as `reference.cartesian`.

For every sample it:

1. obtains both analytical IK solutions;
2. considers angle-equivalent candidates and rejects candidates outside the robot joint limits;
3. selects the candidate with minimum wrapped distance from the previous joint state, using `initialJoint` at the first sample;
4. rejects Jacobians with reciprocal condition number at or below `1e-8`;
5. computes `dq = J \ velocity`;
6. computes `ddq = J \ (acceleration - Jdot*dq)`.

The function never silently clips an unreachable point, joint angle, or singular differential solution.

### Prescribed tasks

The straight-line task is frozen as:

```text
start = [0.55; 0.12] m
finish = [0.22; 0.48] m
move = 3.0 s
terminal hold = 1.0 s
```

The simplified pick-transfer-place task is frozen as:

| Waypoint | Position (m) | Meaning |
|---|---:|---|
| start | `[0.55; 0.12]` | initial tool position |
| pickup | `[0.45; -0.02]` | assumed object location |
| safe | `[0.45; 0.32]` | vertical clearance point |
| place | `[0.22; 0.48]` | assumed placement location |

Move durations are `[1.4; 1.2; 1.5] s`; post-arrival dwell durations are `[0.4; 0.0; 0.8] s`. The positive-`q2` analytical solution at the start is the initial branch. All four points are reachable and the selected branch remains within the prescribed joint limits.

`rrm.trajectory.makePickAndPlaceTask(robot,sampleTime)` owns these frozen values, creates the path and reference, and labels the pickup evaluation at the end of its dwell and the placement evaluation at the end of the terminal dwell. The gripper state is semantic metadata only; no grasp force or object dynamics are simulated.

### Metrics

`rrm.metrics.evaluateCartesianTask(result,robot,reference,evaluationIndices)` delegates existing joint metrics and adds:

- true desired and actual Cartesian histories;
- Cartesian RMS and maximum Euclidean tracking error;
- pickup and placement errors when corresponding evaluation indices exist;
- joint-summed saturation time;
- task success under the frozen thresholds below.

Task success requires all of:

- simulation status is `completed`;
- existing common joint success is true;
- Cartesian RMS error is at most `0.05 m`;
- Cartesian maximum error is at most `0.15 m`;
- every requested waypoint evaluation error is at most `0.05 m`;
- joint-summed saturation time is exactly `0 s`.

These thresholds are fixed before the experiment. A controller that misses them remains in the table as an unsuccessful result; the implementation must not retune gains or alter thresholds in response.

## Experiment and Artifacts

`experiments/run_cartesian_tasks.m` runs the straight-line and pick-transfer-place tasks with:

1. manual PID;
2. Mamdani Fuzzy-PID;
3. optimization-tuned PID.

It produces six formal simulations and saves:

```text
results/data/cartesian_tasks.mat
results/data/cartesian_tasks_runs.csv
results/figures/cartesian_tasks_paths.png
results/figures/cartesian_tasks_errors.png
results/figures/cartesian_tasks_joint_references.png
results/figures/cartesian_tasks_torque.png
results/figures/cartesian_tasks_summary.png
```

The MAT file includes task definitions, source Cartesian paths, joint references, all controller results, and metrics. The CSV has one row per task-controller pair with status, success, Cartesian RMS/max, waypoint errors, joint RMS, torque RMS, and saturation time.

## Error Handling

Named errors are required:

- `rrm:trajectory:InvalidCartesianPath` for malformed path arrays;
- `rrm:trajectory:InvalidWaypointPath` for invalid waypoint shapes, durations, or grids;
- `rrm:trajectory:UnreachableCartesianPoint` for any unreachable sample;
- `rrm:trajectory:JointLimitViolation` when no IK branch fits the limits;
- `rrm:trajectory:SingularCartesianPath` when differential kinematics are ill-conditioned;
- `rrm:metrics:InvalidCartesianTaskInput` for inconsistent result/reference/task metadata.

## Project Structure

```text
+rrm/+kinematics/   Jacobian and Jacobian-rate functions
+rrm/+trajectory/   Cartesian segment, waypoint, conversion, and task factories
+rrm/+metrics/      Cartesian-task evaluation
experiments/         Reproducible Phase 5 experiment
tests/kinematics/    Differential-kinematics tests
tests/trajectory/    Path, branch-continuity, and task tests
tests/metrics/       Cartesian-task metric tests
tests/experiments/   Artifact and fairness tests
```

## Code Style

Use existing MATLAB package functions, argument blocks, column-vector physical quantities, string scalars, named project errors, and serializable structs:

```matlab
function J = jacobian(robot,q)
arguments
    robot (1,1) struct
    q (2,1) double {mustBeFinite,mustBeReal}
end

q12 = q(1) + q(2);
J = [ ...
    -robot.L1*sin(q(1))-robot.L2*sin(q12), -robot.L2*sin(q12); ...
     robot.L1*cos(q(1))+robot.L2*cos(q12),  robot.L2*cos(q12)];
end
```

Package functions perform no file I/O and do not read base-workspace variables. Experiment scripts alone create result directories and artifacts.

## Testing Strategy

Every production function is developed test-first with observed RED and GREEN runs.

- Jacobian tests compare against central finite differences of forward kinematics.
- Jacobian-rate tests compare against central finite differences along a joint-velocity direction.
- Cartesian quintic tests cover endpoints, rest conditions, straight-line geometry, terminal hold, and invalid grids.
- Waypoint tests cover exact waypoint visits, dwell behavior, no duplicate samples, continuous derivatives, and invalid inputs.
- IK conversion tests require forward-kinematics reconstruction below `1e-10 m`, continuous branch selection, differential reconstruction, finite outputs, joint-limit compliance, and named errors.
- Metric tests use hand-calculated Cartesian positions and explicit success/failure cases.
- Experiment tests use a shorter smoke configuration, verify six fair controller/task runs, required MAT/CSV/PNG artifacts, identical references within each task, frozen controller gains, and finite metrics.
- The complete pre-existing suite runs after every atomic increment.

## Boundaries

### Always

- Use the same robot, path, sample time, simulator, and thresholds for all controllers.
- Keep optimized gains frozen.
- Store desired Cartesian paths independently from controller results.
- Preserve the unrelated untracked source DOCX.
- Run tests and static analysis before commits.

### Already Authorized

- Create a short-lived local feature branch/worktree.
- Commit atomic tested increments.
- Fast-forward the verified feature into local `main` and remove the owned worktree/branch.

### Never

- Retune a controller for a Cartesian task.
- Hide or delete an unsuccessful run.
- Optimize robot morphology.
- Add perception, collision avoidance, grasp physics, object dynamics, Simulink, or hardware claims in this phase.
- Push or open a remote pull request without explicit authorization.

## Acceptance Criteria

- The fresh Phase 1-4B baseline remains green.
- All four prescribed pick-and-place waypoints and every interpolated sample are reachable.
- Forward kinematics of every generated joint reference reconstructs its Cartesian path within `1e-10 m`.
- The selected joint branch is continuous and within joint limits.
- Differential kinematics reconstruct the desired velocity and acceleration within test tolerances.
- Both tasks run with all three frozen controllers through one shared simulator.
- Exactly six full result rows are produced with finite metrics and honest success values.
- All required MAT, CSV, and five PNG artifacts exist and are nonempty.
- All MATLAB tests pass and `checkcode` reports zero issues.
- README and the verification script document and reproduce Phase 5.

## Deferred Work

- Direct operational-space, computed-torque, MPC, impedance, or force control.
- Obstacle and self-collision avoidance.
- Vision, grasp planning, gripper forces, and object dynamics.
- Simulink/Simscape cross-validation.
- Hardware deployment and safety claims.
