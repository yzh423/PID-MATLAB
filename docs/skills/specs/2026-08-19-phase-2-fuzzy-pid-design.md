# Phase 2 Mamdani Fuzzy-PID Design

## Objective

Extend the verified Phase 1 control core with a project-owned Mamdani Fuzzy-PID controller and a fair nominal comparison against the existing manual PID. Both controllers must use exactly the same reference, robot, actuator limits, RK4 plant propagation, safety checks, metrics, and output conventions.

Phase 2 isolates the value of online fuzzy gain adaptation. It does not include offline `fmincon` tuning, morphology optimization, Simulink, or robustness sweeps.

## Approved Approach

Refactor the controller-specific call out of `runPid` into a generic simulation path. Controller factories identify their type, and the shared simulator dispatches one controller step per sample. `runPid` remains as a compatibility wrapper so existing tests and experiment entry points continue to work.

The Fuzzy-PID controller uses:

- two normalized inputs per joint: position error and error-rate estimate;
- five linguistic values: `NB`, `NS`, `Z`, `PS`, `PB`;
- triangular interior and shoulder boundary membership functions;
- 25 rules for each of `ΔKp`, `ΔKi`, and `ΔKd`;
- min implication, max aggregation, and discrete centroid defuzzification;
- bounded relative gain corrections applied to the Phase 1 manual PID gains.

This implementation does not depend on Fuzzy Logic Toolbox.

## Architecture

```text
makePidController ────────────────┐
                                  ├─> runController -> RK4 plant -> common result
makeFuzzyPidController -> Mamdani ┘
                                  |
                                  v
                       effective gain history
                                  |
                                  v
                    common metrics and comparison
```

### New Modules

- `+rrm/+fuzzy/membershipFive.m`: evaluate the five normalized input memberships.
- `+rrm/+fuzzy/mamdani.m`: evaluate three rule bases and return normalized corrections.
- `+rrm/+config/makeFuzzyPidController.m`: define scales, correction limits, rule tables, output universe, and gain bounds.
- `+rrm/+control/fuzzyPidStep.m`: compute online gains and delegate the actual PID update to the shared PID calculation.
- `+rrm/+simulation/runController.m`: own the common controller/plant loop.
- `+rrm/+simulation/runFuzzyPid.m`: compatibility/convenience wrapper.
- `experiments/run_nominal_pid_vs_fuzzy.m`: run and report the fair nominal comparison.

### Modified Modules

- `makePidController` gains an explicit `type="pid"` field.
- `pidStep` accepts optional effective gains and reports the gains used in diagnostics.
- `runPid` delegates to `runController` without changing its public signature or result semantics.
- `scripts/verify.ps1` runs both Phase 1 and Phase 2 experiments.
- `README.md` documents Fuzzy-PID design and comparison commands.

## Fuzzy Sets

All fuzzy universes are normalized to `[-1, 1]` with centres:

```text
NB=-1, NS=-0.5, Z=0, PS=0.5, PB=1.
```

The input vector is:

```matlab
normalizedError = clamp(error ./ controller.errorScale, -1, 1);
normalizedRate  = clamp(errorRate ./ controller.errorRateScale, -1, 1);
```

Default scales are `20 deg` for error and `60 deg/s` for error rate, independently applied to both joints.

The output universe contains 101 uniformly spaced points in `[-1,1]`. Output corrections are mapped to gains as:

```matlab
KpEffective = KpBase .* (1 + 0.35 * fuzzyKp);
KiEffective = KiBase .* (1 + 0.50 * fuzzyKi);
KdEffective = KdBase .* (1 + 0.30 * fuzzyKd);
```

The effective gains are then clamped to explicit bounds derived from those same maximum correction fractions. No rule or defuzzification result can escape these bounds.

## Rule Intent

Rows represent error `NB..PB`; columns represent error rate `NB..PB`.

### Proportional Correction

Large absolute error receives strong positive proportional correction; medium error receives moderate positive correction; very small error reduces proportional action unless error rate is large.

```text
PB PB PB PB PB
PS PS PS PS PS
PS  Z NS  Z PS
PS PS PS PS PS
PB PB PB PB PB
```

### Integral Correction

Large error suppresses integral action to limit windup. Small persistent error increases integral action, while large error rate prevents aggressive integration.

```text
NB NB NB NB NB
NS NS  Z NS NS
NS PS PB PS NS
NS NS  Z NS NS
NB NB NB NB NB
```

### Derivative Correction

Large absolute error rate increases damping independently of error sign.

```text
PB PS  Z PS PB
PB PS  Z PS PB
PB PS  Z PS PB
PB PS  Z PS PB
PB PS  Z PS PB
```

Rule tables store indices `1..5` corresponding to `NB..PB`. The tables are deliberately symmetric so mirrored joint errors produce mirrored linguistic membership strengths and equal gain corrections.

## Controller State and Data Flow

Fuzzy-PID retains the Phase 1 integral and filtered derivative state. At each sample:

1. calculate position and velocity errors;
2. normalize and clamp both inputs;
3. evaluate Mamdani corrections for each joint;
4. map corrections to bounded effective gains;
5. execute the same derivative filtering, torque saturation, and back-calculation anti-windup used by PID;
6. record applied torque, saturation state, normalized fuzzy outputs, and effective gains.

The common simulator stores `effectiveKp`, `effectiveKi`, and `effectiveKd` as `2 x N` arrays for every controller. PID therefore records constant arrays and Fuzzy-PID records time-varying arrays.

## Fair Comparison Protocol

The nominal comparison uses:

- baseline robot and 0.5 kg endpoint payload;
- `[0;0]` to `[45;60]` degree quintic reference;
- 3 second motion and 2 second terminal hold;
- 1 ms control and integration step;
- identical torque limits, initial state, disturbance, success criteria, and metrics;
- no gravity feedforward for either controller.

The experiment saves one MAT file containing both controllers and generates:

- joint tracking comparison;
- tracking error comparison;
- torque comparison with actuator limits;
- Fuzzy-PID effective gain history;
- a printed metric table with raw component metrics.

The comprehensive objective is not used in Phase 2, avoiding premature mixing with the optimization study.

## Testing Strategy

### Fuzzy Unit Tests

- Five memberships are non-negative and sum to one at representative normalized inputs.
- `NB`, `Z`, and `PB` peaks occur at `-1`, `0`, and `1`.
- Membership evaluation clamps out-of-range inputs.
- Mamdani outputs are finite and bounded by `[-1,1]`.
- Mirrored error/rate pairs produce the same gain corrections for symmetric rule tables.
- Large absolute error increases `Kp` and suppresses `Ki`.
- Small stationary error increases `Ki`.

### Controller Tests

- Effective gains never leave their configured bounds.
- Fuzzy-PID preserves torque saturation and anti-windup behavior.
- PID with explicit base gains produces the same output as the Phase 1 call.

### Simulation Tests

- `runPid` and generic `runController` produce identical PID results.
- Fuzzy-PID nominal simulation completes with finite results and no joint-limit violation.
- Both controllers use equal time and reference arrays.
- Effective-gain history dimensions match the simulation result.

### Experiment Tests

- Comparison MAT file and all four figures are created.
- Both controllers meet Phase 1 steady-state success criteria.
- Applied torque stays within the same limits.

## Error Handling

- Fuzzy configuration validation rejects malformed rule-table dimensions, invalid label indices, non-positive input scales, non-monotonic universes, and invalid gain bounds.
- Mamdani evaluation rejects non-scalar/non-finite inputs and returns zero correction only if aggregation has zero area.
- Unknown controller types raise `rrm:simulation:UnknownControllerType`.
- The shared simulator retains Phase 1 non-finite-state and joint-limit termination behavior.

## Success Criteria

- All pre-existing Phase 1 tests still pass unchanged except for additive assertions on newly recorded gain fields.
- Every new unit and integration test passes with zero failures.
- MATLAB `checkcode` reports zero issues for production and experiment files.
- PID results before and after simulator refactoring match within `1e-12` for all numeric arrays.
- Fuzzy normalized outputs remain in `[-1,1]` and effective gains remain within configured bounds at every sample.
- Fuzzy-PID nominal simulation finishes with `status="completed"` and zero torque-saturation time.
- Fuzzy-PID final 0.5 second RMS error is below `0.02 rad` per joint and maximum absolute error below `0.05 rad` per joint.
- `scripts/verify.ps1` exits 0 after running the full test suite and both nominal experiments.
- Comparison figures are legible, consistently scaled, correctly labelled, and visually inspected.

## Boundaries

### Always

- Preserve one shared plant simulator and one shared metrics path.
- Record all gain changes and raw component metrics.
- Keep rules, scales, and gain bounds in the controller factory.
- Keep controller comparisons deterministic.

### Ask First

- Change the baseline PID gains or Phase 1 acceptance thresholds.
- Add a new fuzzy input, membership count, or controller state.
- Add third-party dependencies.

### Never

- Use unavailable Fuzzy Logic Toolbox functions.
- Retune the PID reference case only to make Fuzzy-PID look better.
- Compare controllers with different torque limits, trajectories, or simulation steps.
- Claim robustness improvement from the nominal experiment alone.

## Deferred Scope

- `fmincon` optimization of PID gains.
- Held-out payload/configuration validation.
- Complete robustness matrix and repeated stochastic trials.
- Cartesian trajectories, pick-and-place, Simulink, and hardware validation.
