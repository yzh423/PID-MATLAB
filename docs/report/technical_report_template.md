# Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation

**Technical report — Phase 7A**
**Project:** PID vs Fuzzy PID for a two-link robotic manipulator
**Evidence scope:** deterministic MATLAB/Simulink/Simscape simulation artifacts generated from the frozen repository protocol

## Abstract

This report evaluates three low-level joint controllers for a two-link planar robotic manipulator: a manually tuned PID controller, a bounded Mamdani Fuzzy-PID controller, and a constrained-optimization PID controller. The objective is not to select a winner from one nominal trace. It is to determine which conclusions remain defensible when controller behavior is examined across nominal tracking, held-out payload validation, deterministic uncertainty, paired stochastic noise, Cartesian task execution, and two independent model implementations. All quantitative statements are resolved from a validated JSON evidence manifest whose sources are the formal MAT and CSV artifacts produced by the repository. The frozen evidence comprises 39 deterministic runs, 360 paired stochastic trials, six Cartesian task runs, two Simulink comparisons, and two Simscape Multibody comparisons. The frozen pre-report MATLAB suite contains 145 tests; report-specific tests are tracked separately.

Under nominal joint tracking, both manual PID and Fuzzy-PID satisfy the unchanged steady-state acceptance limits. Constrained optimization reduces its training objective by {{optimization.objectiveReductionPercent|.3f}}% and improves nominal and held-out tracking, while retaining the same actuator limits. Broader testing changes the interpretation. Manual PID, Fuzzy-PID, and optimized PID achieve 8/13, 9/13, and 10/13 deterministic successes, respectively. All controllers obtain 0/30 combined-stress successes for every controller in the stochastic matrix, and the manual and Fuzzy-PID pick-transfer-place runs were unsuccessful. Independent Simulink and Multibody trajectories agree with the MATLAB implementation to near floating-point roundoff under the fixed nominal protocol. These results support a reproducible controller comparison and an integration boundary for future embodied-AI planners, but they are simulation evidence and not hardware validation.

## Introduction and Research Context

PID control remains a practical baseline because its proportional, integral, and derivative terms expose an understandable relationship between tracking error, accumulated bias, damping, actuator demand, and tuning effort. Its continued relevance does not imply that one gain set is uniformly adequate: specifications, robustness, implementation details, and operating conditions remain coupled design concerns [1]. This project therefore treats PID as a transparent engineering baseline rather than as a trivial benchmark.

Fuzzy control offers a different adaptation mechanism. Zadeh's fuzzy-set formulation supplies graded membership rather than crisp set assignment [2], and the Mamdani approach converts linguistic rules into a nonlinear control mapping [3]. In this repository, fuzzy inference does not replace the dynamic controller. It produces bounded corrections to the same PID gain families. That architectural choice preserves torque saturation, derivative filtering, and anti-windup behavior while permitting state-dependent gain changes. It also makes comparison fairer: all controllers act on the same robot, reference, integration step, torque limits, and success criteria.

A central methodological decision is to separate nominal accuracy from robustness and task acceptance. A single successful sinusoidal trajectory can hide sensitivity to payload, geometric uncertainty, actuator derating, disturbances, or measurement noise. Conversely, a controller can exhibit good average tracking while failing a task-level waypoint criterion. The report therefore follows an evidence chain: verify nominal behavior, tune within explicit bounds, test frozen deterministic and stochastic matrices, evaluate Cartesian tasks, and then compare independent model implementations. Binomial success intervals in the stochastic summary use Wilson-style inference, which is appropriate for reporting finite-trial uncertainty without treating an observed rate as an exact population probability [4].

The work also has an embodied-AI motivation, but the boundary is deliberately narrow. PaLM-E illustrates how multimodal observations and language can support embodied reasoning and planning [7], while RT-2 demonstrates a vision-language-action approach that connects web-scale representations with robotic action [8]. Those systems do not remove the need for a stable low-level execution layer. The present repository supplies only that lower layer and its validation harness. It does not implement language understanding, perception, task planning, or a vision-language-action model.

## Problem Formulation

The plant is a planar two-revolute-joint manipulator carrying a fixed nominal payload. Let the joint coordinate, velocity, and acceleration vectors be `q`, `q_dot`, and `q_ddot`. The simulated rigid-body dynamics are represented by

```text
M(q) q_ddot + C(q, q_dot) q_dot + G(q) + B q_dot = tau + tau_disturbance,
```

where (M) is the inertia matrix, (Cq_dot) is the velocity-product term, (G) is gravity loading, (B) is viscous friction, and (tau) is the saturated actuator command. The controller receives the reference state and measured joint state, then returns one torque per joint. A run is meaningful only when the simulation completes and the unchanged acceptance gates are evaluated.

The comparison asks four linked questions. First, can each controller satisfy nominal joint-space tracking within the same final-window criteria? Second, does constrained tuning improve objective and held-out performance without changing the plant or acceptance rule? Third, how often do the controllers succeed under isolated and combined uncertainties, and what failure modes remain? Fourth, do independent Simulink and Multibody implementations reproduce the MATLAB result closely enough to support an implementation-consistency claim?

These questions impose a strict scope. Success denotes satisfaction of repository-defined simulation metrics. It does not establish collision avoidance, contact stability, grasp retention, perception accuracy, timing determinism, or safe operation on physical machinery. Likewise, near-zero cross-model differences demonstrate agreement under a shared mathematical protocol; they do not prove that the mathematical model captures every real mechanism.

## System Model

The baseline robot has link lengths of {{system.linkLengthsM.0|.2f}} m and {{system.linkLengthsM.1|.2f}} m, link masses of {{system.linkMassesKg.0|.2f}} kg and {{system.linkMassesKg.1|.2f}} kg, and a nominal payload of {{system.payloadKg|.2f}} kg. Gravity is {{system.gravityMPerS2|.2f}} m/s². Joint torque commands are limited to {{system.torqueLimitsNm.0|.1f}} N m and {{system.torqueLimitsNm.1|.1f}} N m. These limits are applied inside every controller path rather than imposed only during post-processing.

| Parameter | Joint/link 1 | Joint/link 2 | Unit |
|---|---:|---:|---|
| Link length | {{system.linkLengthsM.0|.3f}} | {{system.linkLengthsM.1|.3f}} | m |
| Link mass | {{system.linkMassesKg.0|.3f}} | {{system.linkMassesKg.1|.3f}} | kg |
| Center of mass | {{system.centerOfMassM.0|.4f}} | {{system.centerOfMassM.1|.4f}} | m |
| Rotational inertia | {{system.inertiaKgM2.0|.5f}} | {{system.inertiaKgM2.1|.5f}} | kg m² |
| Viscous friction | {{system.viscousFrictionNmSPerRad.0|.3f}} | {{system.viscousFrictionNmSPerRad.1|.3f}} | N m s/rad |
| Torque limit | {{system.torqueLimitsNm.0|.1f}} | {{system.torqueLimitsNm.1|.1f}} | N m |

The nominal reference lasts {{protocol.nominalDurationS|.1f}} s and contains {{protocol.nominalSampleCount|d}} samples at a {{protocol.sampleTimeS|.4f}} s step. The fixed-step protocol prevents solver-selection changes from becoming an unreported source of variation. The final {{protocol.steadyStateWindowS|.2f}} s is used for steady-state acceptance. Both joints must remain below the stored RMS and maximum-error thresholds; no controller receives a relaxed task-specific joint criterion.

The analytical MATLAB dynamics are the primary experimental plant. A generated Simulink model reproduces the same signal flow and integration contract. A separate Simscape Multibody model represents bodies and revolute joints using the physical-network formulation described by MathWorks [6]. Using three implementations helps expose wiring, sign, state-order, and unit errors, but all three still inherit the same parameter assumptions.

## Controller Design and Tuning

The manual PID law applies proportional action to joint error, integral action to accumulated error, and derivative action to the reference-minus-state velocity difference. Each joint uses derivative filtering, torque saturation, and back-calculation anti-windup. The Fuzzy-PID path begins with the same base gains. Its Mamdani engine evaluates scaled error and error rate, then produces bounded fractional corrections to (K_p), (K_i), and (K_d). This is gain scheduling within explicit limits, not an unconstrained replacement for the PID loop.

| Controller | (K_p) J1/J2 | (K_i) J1/J2 | (K_d) J1/J2 | Design role |
|---|---|---|---|---|
| Manual PID | {{controllers.manualPid.Kp.0|.3f}} / {{controllers.manualPid.Kp.1|.3f}} | {{controllers.manualPid.Ki.0|.3f}} / {{controllers.manualPid.Ki.1|.3f}} | {{controllers.manualPid.Kd.0|.3f}} / {{controllers.manualPid.Kd.1|.3f}} | Transparent baseline |
| Mamdani Fuzzy-PID | {{controllers.fuzzyPid.Kp.0|.3f}} / {{controllers.fuzzyPid.Kp.1|.3f}} | {{controllers.fuzzyPid.Ki.0|.3f}} / {{controllers.fuzzyPid.Ki.1|.3f}} | {{controllers.fuzzyPid.Kd.0|.3f}} / {{controllers.fuzzyPid.Kd.1|.3f}} | Bounded online correction |
| Optimized PID | {{controllers.optimizedPid.Kp.0|.3f}} / {{controllers.optimizedPid.Kp.1|.3f}} | {{controllers.optimizedPid.Ki.0|.3f}} / {{controllers.optimizedPid.Ki.1|.3f}} | {{controllers.optimizedPid.Kd.0|.3f}} / {{controllers.optimizedPid.Kd.1|.3f}} | Constrained offline tuning |

The Fuzzy-PID correction fractions are capped at {{controllers.fuzzyPid.correctionFraction.Kp|.2f}} for proportional gain, {{controllers.fuzzyPid.correctionFraction.Ki|.2f}} for integral gain, and {{controllers.fuzzyPid.correctionFraction.Kd|.2f}} for derivative gain. Error and error-rate scaling are also frozen in the artifact. These bounds matter to interpretation: nominal Fuzzy-PID behavior reflects a deliberately conservative nonlinear schedule, not an unrestricted search for the smallest error.

Offline PID tuning uses `fmincon`, a constrained nonlinear optimizer [5]. Six gain multipliers are bounded and scored by a composite objective containing tracking RMS, overshoot, torque RMS, settling behavior, saturation penalty, and failure penalty. The SQP run completed with exit flag {{optimization.exitFlag|d}} after {{optimization.iterations|d}} iterations and {{optimization.functionEvaluations|d}} objective evaluations. The optimizer changes controller gains only; it does not change robot parameters, reference motion, actuator limits, or evaluation thresholds.

## Experimental Design

The experimental design contains complementary layers rather than one aggregated benchmark. Nominal joint tracking establishes basic correctness. A held-out payload evaluates whether optimized gains retain their advantage away from the training plant. The deterministic matrix varies payload, geometry/configuration, model uncertainty, actuator authority, and disturbance conditions, including a combined stress case. The stochastic matrix uses paired seeds so that all controllers see equivalent noise realizations within each scenario. Cartesian experiments test a straight-line path and a pick-transfer-place sequence. Finally, two independent models reproduce nominal manual and optimized PID trajectories.

| Evidence layer | Frozen size | Primary decision |
|---|---:|---|
| Nominal comparison | {{protocol.nominalDurationS|.1f}} s per controller | Final-window tracking acceptance |
| Deterministic robustness | {{deterministic.runCount|d}} runs | Scenario-level success and failure |
| Stochastic robustness | {{stochastic.trialCount|d}} paired trials | Rate, interval, chattering, recovery |
| Cartesian tasks | {{cartesian.runCount|d}} runs | Path and waypoint acceptance |
| Simulink validation | {{simulink.runCount|d}} runs | Signal-model agreement |
| Multibody validation | {{multibody.runCount|d}} runs | Physical-network agreement |

The nominal success gate uses a steady-state RMS limit of {{protocol.steadyRmsThresholdRad.0|.3f}} rad per joint and a steady-state maximum-error limit of {{protocol.steadyMaxThresholdRad.0|.3f}} rad per joint. The same gate remains active for task-level evaluation. This prevents a Cartesian path from being labeled successful when its endpoint looks acceptable but a joint fails the established steady-state condition.

The deterministic matrix has {{deterministic.scenarioCount|d}} scenarios per controller. The stochastic design contains {{stochastic.scenarioCount|d}} scenario families and {{protocol.stochasticTrialsPerScenario|d}} fixed-seed trials for each controller-scenario pair. Paired evaluation reduces comparison noise, while the Wilson interval communicates the uncertainty that remains in a finite observed success rate [4]. No failed run is deleted from the summary.

## Results

Both nominal controllers complete the trajectory without saturation and pass the stored gate. Manual PID steady-state RMS errors are {{nominal.manualPid.steadyRms.0|.6f}} rad and {{nominal.manualPid.steadyRms.1|.6f}} rad. Fuzzy-PID errors are {{nominal.fuzzyPid.steadyRms.0|.6f}} rad and {{nominal.fuzzyPid.steadyRms.1|.6f}} rad. The result is mixed rather than uniformly directional: Fuzzy-PID is worse on joint 1 but slightly better on joint 2 under this nominal reference.

| Controller | Steady RMS J1 (rad) | Steady RMS J2 (rad) | Torque RMS J1 (N m) | Torque RMS J2 (N m) | Success |
|---|---:|---:|---:|---:|---|
| Manual PID | {{nominal.manualPid.steadyRms.0|.6f}} | {{nominal.manualPid.steadyRms.1|.6f}} | {{nominal.manualPid.torqueRms.0|.4f}} | {{nominal.manualPid.torqueRms.1|.4f}} | Pass |
| Fuzzy-PID | {{nominal.fuzzyPid.steadyRms.0|.6f}} | {{nominal.fuzzyPid.steadyRms.1|.6f}} | {{nominal.fuzzyPid.torqueRms.0|.4f}} | {{nominal.fuzzyPid.torqueRms.1|.4f}} | Pass |

![Nominal joint tracking for manual PID and bounded Mamdani Fuzzy-PID.](../../results/figures/nominal_pid_vs_fuzzy_tracking.png)

The optimization objective decreases from {{optimization.initialObjective|.6f}} to {{optimization.finalObjective|.6f}}, a {{optimization.objectiveReductionPercent|.3f}}% reduction. The held-out objective changes from {{optimization.heldOutInitialObjective|.6f}} to {{optimization.heldOutFinalObjective|.6f}}. This supports an accuracy improvement under both training and payload-shift conditions, but it is a local constrained result from one frozen objective and search budget.

| Optimization quantity | Initial/manual | Final/optimized | Interpretation |
|---|---:|---:|---|
| Nominal composite objective | {{optimization.initialObjective|.6f}} | {{optimization.finalObjective|.6f}} | Training condition improved |
| Held-out composite objective | {{optimization.heldOutInitialObjective|.6f}} | {{optimization.heldOutFinalObjective|.6f}} | Payload-shift condition improved |
| Solver iterations | — | {{optimization.iterations|d}} | SQP termination record |
| Function evaluations | — | {{optimization.functionEvaluations|d}} | Frozen search cost |

![Constrained PID objective history and final solution.](../../results/figures/pid_optimization_objective.png)

The broader deterministic result is 8/13, 9/13, and 10/13 deterministic successes for manual PID, Fuzzy-PID, and optimized PID. Their success rates are {{deterministic.successRate.manualPid|.4f}}, {{deterministic.successRate.fuzzyPid|.4f}}, and {{deterministic.successRate.optimizedPid|.4f}}. Mean joint RMS decreases for the optimized controller, yet all three fail the combined deterministic condition. A higher aggregate rate therefore does not remove the common high-stress weakness.

| Controller | Successes | Failures | Mean joint RMS (rad) | Worst joint RMS (rad) | Worst EE maximum (m) |
|---|---:|---:|---:|---:|---:|
| Manual PID | {{deterministic.successCount.manualPid|d}} | {{deterministic.failureCount.manualPid|d}} | {{deterministic.summaryRows.0.MeanJointRms|.5f}} | {{deterministic.summaryRows.0.WorstJointRms|.5f}} | {{deterministic.summaryRows.0.WorstEndEffectorMax|.5f}} |
| Fuzzy-PID | {{deterministic.successCount.fuzzyPid|d}} | {{deterministic.failureCount.fuzzyPid|d}} | {{deterministic.summaryRows.1.MeanJointRms|.5f}} | {{deterministic.summaryRows.1.WorstJointRms|.5f}} | {{deterministic.summaryRows.1.WorstEndEffectorMax|.5f}} |
| Optimized PID | {{deterministic.successCount.optimizedPid|d}} | {{deterministic.failureCount.optimizedPid|d}} | {{deterministic.summaryRows.2.MeanJointRms|.5f}} | {{deterministic.summaryRows.2.WorstJointRms|.5f}} | {{deterministic.summaryRows.2.WorstEndEffectorMax|.5f}} |

![Deterministic robustness success and error summary.](../../results/figures/deterministic_robustness_summary.png)

The stochastic matrix contains 360 paired stochastic trials. Every controller succeeds in all isolated low-, medium-, and high-noise trials, but every controller records 0/30 in the combined stochastic condition. In other words, the study has 0/30 combined-stress successes for every controller. This combined stress result is the strongest counterweight to a simple ranking based on nominal RMS.

Noise also exposes a control-effort trade-off. At high noise, mean torque slew is {{stochastic.highNoiseMeanTorqueSlew.manualPid|.2f}}, {{stochastic.highNoiseMeanTorqueSlew.fuzzyPid|.2f}}, and {{stochastic.highNoiseMeanTorqueSlew.optimizedPid|.2f}} N m/s for manual PID, Fuzzy-PID, and optimized PID. The optimized controller tracks more accurately but produces the largest chattering proxy. This behavior is visible despite all isolated-noise trials passing the binary gate.

| High-noise controller | Successes/trials | Mean joint RMS (rad) | Mean torque slew (N m/s) | Worst saturation (s) |
|---|---:|---:|---:|---:|
| Manual PID | {{stochastic.summaryRows.6.SuccessCount|d}}/{{stochastic.summaryRows.6.TrialCount|d}} | {{stochastic.summaryRows.6.MeanJointRms|.5f}} | {{stochastic.summaryRows.6.MeanTorqueSlew|.2f}} | {{stochastic.summaryRows.6.WorstSaturationTime|.3f}} |
| Fuzzy-PID | {{stochastic.summaryRows.7.SuccessCount|d}}/{{stochastic.summaryRows.7.TrialCount|d}} | {{stochastic.summaryRows.7.MeanJointRms|.5f}} | {{stochastic.summaryRows.7.MeanTorqueSlew|.2f}} | {{stochastic.summaryRows.7.WorstSaturationTime|.3f}} |
| Optimized PID | {{stochastic.summaryRows.8.SuccessCount|d}}/{{stochastic.summaryRows.8.TrialCount|d}} | {{stochastic.summaryRows.8.MeanJointRms|.5f}} | {{stochastic.summaryRows.8.MeanTorqueSlew|.2f}} | {{stochastic.summaryRows.8.WorstSaturationTime|.3f}} |

![Stochastic robustness chattering and torque-slew comparison.](../../results/figures/stochastic_robustness_chattering.png)

Cartesian results further distinguish joint accuracy from task completion. All three controllers pass the straight-line task. In the more demanding sequence, the manual and Fuzzy-PID pick-transfer-place runs were unsuccessful, while optimized PID passes. The failed runs are completed simulations, not crashes; they fail the unchanged quantitative acceptance logic. This distinction matters because suppressing completed-but-unsuccessful cases would bias the task narrative.

| Task/controller | Cartesian RMS (m) | Cartesian maximum (m) | Pickup error (m) | Place error (m) | Acceptance |
|---|---:|---:|---:|---:|---|
| Straight/manual | {{cartesian.runRows.0.CartesianRms|.5f}} | {{cartesian.runRows.0.CartesianMax|.5f}} | — | — | Pass |
| Straight/Fuzzy-PID | {{cartesian.runRows.1.CartesianRms|.5f}} | {{cartesian.runRows.1.CartesianMax|.5f}} | — | — | Pass |
| Straight/optimized | {{cartesian.runRows.2.CartesianRms|.5f}} | {{cartesian.runRows.2.CartesianMax|.5f}} | — | — | Pass |
| Pick-transfer-place/manual | {{cartesian.runRows.3.CartesianRms|.5f}} | {{cartesian.runRows.3.CartesianMax|.5f}} | {{cartesian.runRows.3.PickupError|.5f}} | {{cartesian.runRows.3.PlaceError|.5f}} | Unsuccessful |
| Pick-transfer-place/Fuzzy-PID | {{cartesian.runRows.4.CartesianRms|.5f}} | {{cartesian.runRows.4.CartesianMax|.5f}} | {{cartesian.runRows.4.PickupError|.5f}} | {{cartesian.runRows.4.PlaceError|.5f}} | Unsuccessful |
| Pick-transfer-place/optimized | {{cartesian.runRows.5.CartesianRms|.5f}} | {{cartesian.runRows.5.CartesianMax|.5f}} | {{cartesian.runRows.5.PickupError|.5f}} | {{cartesian.runRows.5.PlaceError|.5f}} | Pass |

![Cartesian straight-line and pick-transfer-place paths.](../../results/figures/cartesian_tasks_paths.png)

## Independent Model Validation

The Simulink study compares manual and optimized PID runs against the MATLAB simulator. Both agreement flags and both tracking-success flags pass. The largest reported joint-position RMS difference is {{simulink.runRows.0.QRmsJ1|.4e}} rad for the first manual row and remains at floating-point scale across the table. The rigid-body term audit reports maximum discrepancies of {{simulink.rigidBodyMaxMassMatrixError|.4e}}, {{simulink.rigidBodyMaxVelocityProductError|.4e}}, and {{simulink.rigidBodyMaxGravityError|.4e}} for inertia, velocity-product, and gravity calculations.

The Multibody study also passes both agreement and tracking gates. Its worst end-effector difference is {{multibody.endEffectorMaxWorst|.4e}} m, and maximum out-of-plane motion is {{multibody.maximumOutOfPlane|.1f}} m. These values support implementation consistency between the analytical and physical-network paths for the fixed nominal experiment.

| Validation path | Rows | Agreement passes | Tracking passes | Largest highlighted difference |
|---|---:|---:|---:|---:|
| MATLAB vs Simulink | {{simulink.runCount|d}} | {{simulink.runCount|d}} | {{simulink.runCount|d}} | {{simulink.runRows.0.QMaxJ2|.4e}} rad |
| MATLAB vs Multibody | {{multibody.runCount|d}} | {{multibody.runCount|d}} | {{multibody.runCount|d}} | {{multibody.endEffectorMaxWorst|.4e}} m |

![MATLAB and Simscape Multibody nominal tracking agreement.](../../results/figures/multibody_cross_validation_tracking.png)

Independent formulation is valuable because a duplicated implementation bug can otherwise survive ordinary unit tests. Simulink checks the block-diagram signal and solver interface; Simscape Multibody checks a physical-network representation with bodies and joints. Nevertheless, the tests reuse common parameters and target trajectories. The conclusion is therefore model agreement under a specified protocol, not empirical fidelity to hardware.

## Discussion

Three conclusions follow from the complete evidence chain. First, Fuzzy-PID is bounded and successful under nominal and isolated-noise conditions, but it is not uniformly better than manual PID. It trades joint-specific error and torque behavior rather than dominating every metric. Its modest deterministic success-rate improvement is meaningful within this matrix, yet both controllers share the combined-stress failure and both miss the pick-transfer-place acceptance gate.

Second, constrained optimization gives the strongest accuracy result. It reduces both training and held-out objectives, produces the lowest deterministic mean joint RMS, and is the only controller to pass the pick-transfer-place task. The same evidence also identifies its cost: the optimized gains produce the largest high-noise torque slew and still do not recover from combined stress. Optimization has therefore improved the objective it was given; it has not solved robustness in general.

Third, model agreement and task acceptance answer different questions. The near-roundoff Simulink and Multibody differences increase confidence that the nominal equations and implementation are wired consistently. They cannot overturn failed uncertainty scenarios. Conversely, failure under severe combined perturbations does not imply that the three implementations disagree. Keeping these axes separate prevents a validation success from being used to mask a robustness limitation.

The project also demonstrates the value of reporting failures as first-class results. A summary that retained only nominal traces would suggest that all methods are adequate and that differences are small. Adding deterministic rates favors optimized PID. Adding stochastic chattering reveals a trade-off. Adding combined stress establishes a common limitation. Adding Cartesian acceptance shows that low aggregate error is not automatically task success. The resulting conclusion is more constrained, but more useful for engineering decisions.

## Embodied-AI Execution Context

A future embodied-AI stack could place this controller layer beneath perception and planning. A multimodal planner might convert images, language, and state estimates into a sequence of task-space goals, as explored by PaLM-E [7]. A vision-language-action system might instead generate actions through an end-to-end representation, as explored by RT-2 [8]. In either case, a conventional execution layer can remain useful for enforcing joint commands, torque limits, interpolation, and monitoring at a faster inner-loop timescale.

The repository's existing boundary is trajectory-centric. A high-level component could supply timestamped joint references or Cartesian waypoints. The trajectory module would convert feasible Cartesian paths to joint-space references, and one of the evaluated controllers would track them. Status, saturation, error, and task metrics could return to a supervisory layer. Such an interface is preferable to letting an unverified semantic model write actuator torques directly.

This is an architectural interpretation, not an implemented feature. The project contains no camera pipeline, object detector, language model, PaLM-E, RT-2, VLA policy, task-and-motion planner, grasp planner, or online safety supervisor. The reported protocol contains no metrics for network delay, compute latency, perception error, human interaction, or semantic recovery. The evidence only shows how the tested low-level controllers behave when supplied with deterministic reference trajectories.

## Limitations and Future Work

The largest limitation is the simulation-to-reality gap. Link flexibility, gearbox backlash, Coulomb friction, sensor quantization, calibration error, communication delay, thermal limits, and contact dynamics are absent or simplified. Simscape Multibody adds an independent mechanical formulation, but it shares the frozen dimensions and nominal assumptions. Consequently, the cross-validation result is not hardware validation and cannot establish physical-system safety.

The study is also limited to a planar two-joint mechanism and a fixed family of references. The deterministic and stochastic matrices are broader than a nominal experiment, yet they are finite samples from designed scenarios. The observed success rates and Wilson intervals describe this protocol. They should not be extrapolated to arbitrary payloads, configurations, collision environments, or disturbances. Combined-stress failure indicates where the present design stops working; it does not identify one universal replacement controller.

Future work should proceed in evidence-preserving stages. The first stage is hardware-in-the-loop or real-time target execution with logged timing, saturation, and fault behavior. The second is low-speed physical commissioning with independent emergency stopping, conservative workspace limits, and parameter identification. Only after the model discrepancy is quantified should gains be retuned for the physical plant. A later research branch could evaluate impedance control, disturbance observers, model-predictive control, or adaptive methods against the same frozen baselines. Those additions should be justified by a specific failure mechanism rather than by novelty alone.

For embodied-AI integration, future work should define a typed planner-to-controller contract, validate reference feasibility, enforce rate and workspace limits, and provide a monitored rejection path. Perception and planning uncertainty should enter the robustness matrix as measured distributions. Task success should then include collision, contact, grasp, and recovery metrics instead of relying only on joint and waypoint error.

## Conclusion

This project establishes a reproducible comparison rather than a universal controller ranking. Manual PID is a transparent and effective nominal baseline. Bounded Mamdani Fuzzy-PID preserves nominal success and slightly improves the deterministic success count, but does not dominate joint-level metrics or difficult tasks. Constrained optimized PID provides the best nominal, held-out, deterministic-average, and pick-transfer-place results, while showing the largest high-noise torque slew and the same combined-stress failure as the other controllers.

The evidential strength comes from the workflow: frozen plant and acceptance rules, paired stochastic seeds, explicit failed cases, task-level checks, independent model agreement, a validated source manifest, and automated content gates. The appropriate next step is controlled packaging and communication of these results, followed by carefully bounded hardware-oriented validation—not additional claims based on the current simulation alone.

## References

<!-- REFERENCE_LIST -->
