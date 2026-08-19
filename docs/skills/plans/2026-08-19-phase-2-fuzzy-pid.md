# Phase 2 Mamdani Fuzzy-PID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans and complete every task test-first in the listed order.

**Goal:** Add a toolbox-independent Mamdani Fuzzy-PID controller, run it through the same plant and safety path as PID, and produce a reproducible nominal comparison.

**Architecture:** Extract the Phase 1 loop into `runController`, keep `runPid` as a compatibility wrapper, and dispatch controller-specific steps by an explicit `type`. Fuzzy-PID computes bounded online gains and delegates filtering, saturation, and anti-windup to the existing PID calculation.

**Tech Stack:** MATLAB R2026a, MATLAB Unit Test, analytical RK4 plant, project-owned Mamdani inference, Git.

## Global Constraints

- Work in an isolated feature worktree and preserve the untracked source document in the main worktree.
- Run a focused test in RED before each production increment, then GREEN before committing.
- Add no Fuzzy Logic Toolbox or third-party dependency.
- Use identical robot, reference, integration, torque limits, and metrics for both controllers.
- Preserve Phase 1 PID arrays within `1e-12` after the simulator refactor.
- Keep all effective gains, fuzzy outputs, torques, states, and metrics observable in saved results.

---

### Task 1: Five-Set Membership Evaluation

**Files:**
- Create: `tests/fuzzy/TestMembershipFive.m`
- Create: `+rrm/+fuzzy/membershipFive.m`

- [ ] Write tests for label peaks, partition of unity at representative values, non-negativity, output shape, and clamping outside `[-1,1]`.
- [ ] Run `TestMembershipFive` and confirm RED because the function is missing.
- [ ] Implement five triangular/shoulder memberships centred at `[-1,-0.5,0,0.5,1]` with finite-scalar validation.
- [ ] Run the focused test and the full suite; confirm GREEN.
- [ ] Commit as `feat: add normalized fuzzy membership sets`.

### Task 2: Fuzzy Controller Configuration and Mamdani Inference

**Files:**
- Create: `tests/config/TestMakeFuzzyPidController.m`
- Create: `tests/fuzzy/TestMamdani.m`
- Create: `+rrm/+config/makeFuzzyPidController.m`
- Create: `+rrm/+fuzzy/mamdani.m`

- [ ] Write configuration tests for controller type, positive input scales, `5 x 5` rule tables, label indices, monotonic 101-point output universe, and valid gain bounds.
- [ ] Run the configuration test and confirm RED.
- [ ] Implement the factory with Phase 1 gains as bases, documented normalization scales, correction fractions, rule tables, output memberships, and derived lower/upper gain bounds.
- [ ] Run the configuration test and confirm GREEN.
- [ ] Write Mamdani tests for finite bounded outputs, symmetric mirrored inputs, large-error `Kp` increase/`Ki` suppression, and near-zero stationary-error `Ki` increase.
- [ ] Run `TestMamdani` and confirm RED because inference is missing.
- [ ] Implement min implication, max aggregation, and discrete-centroid defuzzification, including zero-area fallback and configuration/input validation.
- [ ] Run both focused tests and the full suite; confirm GREEN.
- [ ] Commit as `feat: add Mamdani gain adaptation`.

### Task 3: Shared PID Calculation with Effective Gains

**Files:**
- Modify: `+rrm/+config/makePidController.m`
- Modify: `+rrm/+control/pidStep.m`
- Modify: `tests/control/TestPidStep.m`

- [ ] Add tests that PID exposes `type="pid"`, explicit base gains reproduce the legacy call exactly, and diagnostics report the gains used.
- [ ] Run `TestPidStep` and confirm RED on the missing type/effective-gain interface.
- [ ] Add the controller type and an optional effective-gains argument while leaving the original call valid and numerically unchanged.
- [ ] Validate gain dimensions, finiteness, and non-negativity; include `effectiveKp`, `effectiveKi`, and `effectiveKd` in diagnostics.
- [ ] Run the focused test and full suite; confirm GREEN.
- [ ] Commit as `refactor: expose effective PID gains`.

### Task 4: Fuzzy-PID Controller Step

**Files:**
- Create: `tests/control/TestFuzzyPidStep.m`
- Create: `+rrm/+control/fuzzyPidStep.m`

- [ ] Write tests proving effective gains remain within bounds, normalized inputs and outputs are bounded, torque saturation is preserved, state shapes remain valid, and nominal zero-error behavior is finite.
- [ ] Run `TestFuzzyPidStep` and confirm RED because the function is missing.
- [ ] Implement per-joint normalization and Mamdani evaluation, map relative corrections to clamped gains, and delegate the common control law to `pidStep`.
- [ ] Record normalized inputs, fuzzy corrections, and effective gains in diagnostics.
- [ ] Run the focused test and full suite; confirm GREEN.
- [ ] Commit as `feat: add bounded fuzzy PID step`.

### Task 5: One Shared Controller Simulation Path

**Files:**
- Create: `tests/simulation/TestRunController.m`
- Create: `+rrm/+simulation/runController.m`
- Create: `+rrm/+simulation/runFuzzyPid.m`
- Modify: `+rrm/+simulation/runPid.m`
- Modify: `tests/simulation/TestRunPid.m`

- [ ] Capture the current Phase 1 nominal PID result as the behavioral reference in a test, then add assertions that wrapper and generic PID outputs agree array-by-array within `1e-12`.
- [ ] Add tests for unknown controller type, gain-history dimensions, common time/reference arrays, and a finite completed Fuzzy-PID nominal run.
- [ ] Run the simulation tests and confirm RED because `runController` and `runFuzzyPid` are missing.
- [ ] Move the existing RK4 loop and safety termination unchanged into `runController`; dispatch only the controller step by `controller.type`.
- [ ] Record effective gains for all controllers and fuzzy diagnostics when present; make `runPid` and `runFuzzyPid` thin wrappers.
- [ ] Run all simulation tests and the full suite; confirm GREEN and verify legacy PID equality.
- [ ] Commit as `refactor: share controller simulation path`.

### Task 6: Nominal PID-versus-Fuzzy Comparison

**Files:**
- Create: `tests/experiments/TestNominalPidVsFuzzy.m`
- Create: `experiments/run_nominal_pid_vs_fuzzy.m`

- [ ] Write an experiment test using a temporary `outputRoot`; require one MAT file and four PNG figures and validate both saved runs, common references, torque limits, success flags, Fuzzy-PID error thresholds, and zero saturation time.
- [ ] Run the focused test and confirm RED because the experiment is missing.
- [ ] Implement the deterministic comparison using public package interfaces, common metrics, a printed metric table, and tracking/error/torque/gain figures.
- [ ] Save raw results, metrics, controller definitions, robot, reference, and options to `nominal_pid_vs_fuzzy.mat`.
- [ ] Run the focused test; if a written performance criterion fails, tune only documented Fuzzy-PID scales/rules/correction ranges and retain the failure evidence.
- [ ] Run the full suite and confirm GREEN.
- [ ] Commit as `feat: add nominal PID fuzzy comparison`.

### Task 7: Verification and Documentation

**Files:**
- Modify: `scripts/verify.ps1`
- Modify: `README.md`

- [ ] Extend verification to run all tests plus both nominal experiments.
- [ ] Document the shared architecture, Mamdani rule semantics, exact reproduction commands, artifacts, comparison interpretation, and the boundary that nominal results do not prove robustness.
- [ ] Run MATLAB `checkcode` across `+rrm` and `experiments` and fix every reported issue.
- [ ] Run `scripts/verify.ps1` from a clean feature worktree and require exit code 0.
- [ ] Inspect all four generated comparison figures for labels, units, legibility, bounds, and honest common scaling.
- [ ] Run `git diff --check` and inspect `git status --short` to ensure only Phase 2 scope is staged.
- [ ] Commit as `docs: document verified fuzzy PID comparison`.

### Task 8: Integration

- [ ] Confirm the feature branch is clean and every Task 1–7 commit is present.
- [ ] Merge `feature/phase-2-fuzzy-pid` into local `main` without rewriting history.
- [ ] Run `scripts/verify.ps1` again on merged `main` and confirm all artifacts and metrics.
- [ ] Remove only the verified Phase 2 worktree and its merged local branch; preserve the unrelated untracked DOCX.
- [ ] Report exact test count, checkcode result, PID and Fuzzy-PID nominal metrics, saturation times, artifacts, and merge state. Do not push or open a PR.

## Plan Self-Review

- Every design requirement maps to a task and an executable verification.
- The dependency order is valid: memberships → configuration/inference → common PID gains → fuzzy step → shared simulator → experiment.
- The compatibility gate is quantitative (`1e-12`), not a visual or status-only assertion.
- No deferred `fmincon`, robustness sweep, Simulink, Cartesian, or hardware work is included.
- Every behavior-changing increment has a preceding expected failure and a focused commit.
