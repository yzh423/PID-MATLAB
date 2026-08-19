# Phase 3 Optimization-Assisted PID Tuning Design

## Objective

Add a reproducible `fmincon` study that tunes the six independent-joint PID gains on the nominal robot, compares the optimized controller with the manual Phase 1 PID under identical conditions, and validates the frozen optimized gains on an unseen payload. This phase evaluates controller-parameter optimization only; it does not optimize robot morphology or Fuzzy-PID parameters.

## Approved Approach

Optimize six dimensionless multipliers relative to the verified manual PID gains. This gives `fmincon` similarly scaled decision variables while retaining directly interpretable physical gains.

```text
x = [Kp1 multiplier; Kp2 multiplier;
     Ki1 multiplier; Ki2 multiplier;
     Kd1 multiplier; Kd2 multiplier]
```

The initial point is `ones(6,1)`. Lower bounds are `[0.5;0.5;0.25;0.25;0.5;0.5]`; upper bounds are `2*ones(6,1)`. The corresponding physical gain bounds and final gains are saved explicitly.

Alternatives rejected for this phase:

- direct physical-gain optimization, because `Kp`, `Ki`, and `Kd` have dissimilar numerical scales;
- three shared multipliers, because they prevent joint-specific tuning;
- Fuzzy-PID scale optimization, because the revised guide recommends starting with PID and the basic fuzzy controller is already a separate verified baseline.

## Tooling and Commands

- MATLAB R2026a at `E:\MATLAB2026\bin\matlab.exe`.
- Optimization Toolbox `fmincon`; no Global Optimization Toolbox or third-party solver.
- Full verification: `powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1`.
- Optimization experiment: run `experiments/run_pid_optimization.m` from the repository root in MATLAB.

## Architecture

```text
makePidOptimization
        |
        v
applyPidMultipliers --> runPid --> scorePidResult --> scalar J + components
        ^                                               |
        |                                               v
        +------------------- fmincon <------------- objective history
                                                        |
                                                        v
                                      frozen gains + held-out validation
```

### New Modules

- `+rrm/+config/makePidOptimization.m`: decision order, multiplier bounds, objective weights, normalization constants, settling band, and solver settings.
- `+rrm/+optimization/applyPidMultipliers.m`: map a finite bounded six-vector to a PID controller without changing unrelated controller settings.
- `+rrm/+optimization/scorePidResult.m`: pure scalar-objective calculation from one completed or failed result.
- `+rrm/+optimization/tunePid.m`: deterministic `fmincon` orchestration, evaluation logging, and final report assembly.
- `experiments/run_pid_optimization.m`: nominal tuning, manual-versus-optimized comparison, unseen-payload validation, persistence, figures, and console tables.

### Modified Modules

- `scripts/verify.ps1` runs the Phase 3 experiment after all tests and earlier experiments.
- `README.md` documents the objective, bounds, solver, commands, final gains, and measured tradeoffs.

## Objective Function

The scalar objective is dimensionless:

```text
J = 0.50 E_rms + 0.10 O + 0.15 U_rms + 0.25 T_settle
    + 100 S + P_failure
```

Components are defined as follows:

- `E_rms`: mean across joints of RMS tracking error divided by that joint's commanded travel.
- `O`: mean positive overshoot beyond the final target, divided by commanded travel. Motion direction is included so the definition also works for decreasing trajectories.
- `U_rms`: mean across joints of RMS applied torque divided by that joint's torque limit.
- `T_settle`: mean joint settling time divided by total experiment duration. Settling is the first sample after the last violation of a `2 deg` final-target band; a joint that never settles receives the full duration.
- `S`: fraction of joint-samples at the actuator limit, using the simulator's saturation record.
- `P_failure`: `100` for a non-completed status plus a proportional penalty for missing/non-finite samples.

All raw components, weighted components, and the total are retained. Zero commanded travel is rejected rather than silently normalized.

## Optimization Protocol

Training uses only the Phase 1 nominal condition:

- baseline geometry and masses;
- `0.5 kg` endpoint payload;
- `[0;0]` to `[45;60] deg` quintic motion over 3 seconds and hold until 5 seconds;
- `1 ms` controller/integration step;
- no disturbance, noise, or gravity feedforward;
- the same torque and joint limits as all previous phases.

`fmincon` uses the SQP algorithm, forward finite differences, no parallel execution, `20` maximum iterations, `150` maximum function evaluations, `1e-4` step tolerance, and `1e-3` optimality tolerance. There is no random initialization or random seed. The initial objective is evaluated separately and the solver's exit flag, output structure, evaluation trace, initial point, bounds, and final point are saved.

The implementation may cache an exactly repeated decision vector within one tuning run, but it must not reuse results across changed robot, reference, or simulation settings.

## Held-Out Validation

After optimization, gains are frozen. Validation changes only endpoint payload from `0.5 kg` to `0.8 kg`; this condition is never included in the training objective. Manual and optimized PID use the same heavier plant, reference, sample time, actuator limits, and metrics. Both nominal and held-out results are reported, including cases where an individual metric becomes worse.

## Experiment Outputs

The experiment saves `results/data/pid_optimization.mat` containing:

- training and validation robots;
- reference and simulation options;
- optimization configuration;
- manual and optimized controllers;
- initial/final multipliers and physical gains;
- `fmincon` exit flag and output;
- full objective-evaluation history;
- nominal manual/optimized results, objective components, and common metrics;
- held-out manual/optimized results, objective components, and common metrics.

Figures written under `results/figures/`:

- `pid_optimization_objective.png`: evaluated objective and best-so-far value;
- `pid_optimization_nominal_tracking.png`: common-reference manual/optimized tracking errors;
- `pid_optimization_nominal_torque.png`: manual/optimized torque with common limits;
- `pid_optimization_validation_tracking.png`: unseen-payload tracking errors;
- `pid_optimization_gains.png`: manual versus optimized physical gains.

## Error Handling

- Invalid multiplier size, non-finite values, or bound violations raise named optimization errors.
- Invalid weights, bounds, travel normalization, solver limits, or settling band are rejected by configuration/scoring validation.
- A dynamically failed candidate returns a finite penalized objective so `fmincon` can continue; the failed status is retained in the evaluation record.
- Missing Optimization Toolbox or `fmincon` produces an explicit dependency error before any tuning starts.
- The final selected controller must be re-simulated independently; an optimizer callback result is not treated as final evidence.

## Testing Strategy

### Unit Tests

- Multiplier mapping follows the documented order and preserves non-gain PID fields.
- Invalid vectors and out-of-bound multipliers are rejected.
- Objective components match hand-calculated synthetic results.
- Saturation and failed-status penalties increase the score by the documented amount.
- Settling-time and overshoot definitions cover both increasing and decreasing motion.

### Optimization Tests

- A bounded short-horizon smoke problem invokes real `fmincon`, returns finite in-bound gains, records evaluations, and re-simulates successfully.
- Repeated runs with identical inputs are deterministic within `1e-10` for multipliers and objective.

### Experiment Tests

- The MAT file and five figures are generated.
- Manual and optimized runs use identical references and limits.
- The nominal optimized objective is at least `2%` below the manual objective.
- The optimized nominal run satisfies common Phase 1 success criteria with zero saturation.
- The held-out optimized run completes, satisfies common success criteria with zero saturation, and its mean whole-trajectory RMS error is no more than `10%` above the held-out manual PID.
- Saved gains and multipliers remain within declared bounds.

## Success Criteria

- All Phase 1 and Phase 2 tests remain unchanged and pass.
- New unit, optimization, and experiment tests pass.
- Production and experiment MATLAB files produce zero `checkcode` issues.
- The optimizer uses only nominal `0.5 kg` data; validation uses frozen gains at `0.8 kg`.
- Nominal optimized objective improves by at least `2%`, without torque saturation or loss of task success.
- Held-out validation meets the documented completion, success, saturation, and relative-error limits.
- Solver settings, bounds, initial values, termination information, final values, and all objective terms are reproducible from the saved MAT file.
- `scripts/verify.ps1` exits zero and all five Phase 3 figures pass visual inspection.

## Boundaries

### Always

- Optimize controller gains only and retain the common simulation/metrics path.
- Separate nominal training from unseen-payload validation.
- Report every objective component and common metric, including regressions.
- Preserve deterministic solver and experiment settings.

### Ask First

- Change Phase 1 success thresholds or manual PID gains.
- Add training scenarios, random restarts, another optimizer, or Fuzzy-PID variables.
- Change robot morphology as part of the decision vector.

### Never

- Tune on the held-out payload.
- Hide saturation/failure penalties or unsuccessful candidates.
- Claim general robustness from one held-out payload.
- require an unavailable optimization toolbox.

## Deferred Scope

- Full payload/configuration/disturbance/noise robustness matrix.
- Fuzzy-PID parameter optimization.
- Multiple optimizers, random restarts, Bayesian optimization, or genetic algorithms.
- Morphology optimization, Simulink cross-validation, Cartesian tasks, and hardware tests.
