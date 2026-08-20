# Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation

**Technical report — Phase 7A**
**Project:** PID vs Fuzzy PID for a two-link robotic manipulator
**Evidence scope:** deterministic MATLAB/Simulink/Simscape simulation artifacts generated from the frozen repository protocol

## Abstract

This report evaluates three low-level joint controllers for a two-link planar robotic manipulator: a manually tuned PID controller, a bounded Mamdani Fuzzy-PID controller, and a constrained-optimization PID controller. The objective is not to select a winner from one nominal trace. It is to determine which conclusions remain defensible when controller behavior is examined across nominal tracking, held-out payload validation, deterministic uncertainty, paired stochastic noise, Cartesian task execution, and two independent model implementations. Designated result fields are resolved from a validated JSON evidence manifest whose sources are the formal MAT and CSV artifacts produced by the repository; the admission gate separately enforces frozen study counts and required failure disclosures. The frozen evidence comprises 39 deterministic runs, 360 paired stochastic trials, six Cartesian task runs, two Simulink comparisons, and two Simscape Multibody comparisons. The frozen pre-report MATLAB suite contains 145 tests; report-specific tests are tracked separately.

Under nominal joint tracking, both manual PID and Fuzzy-PID satisfy the unchanged steady-state acceptance limits. Constrained optimization reduces its training objective by 7.283% and improves nominal and held-out tracking, while retaining the same actuator limits. Broader testing changes the interpretation. Manual PID, Fuzzy-PID, and optimized PID achieve 8/13, 9/13, and 10/13 deterministic successes, respectively. All controllers obtain 0/30 combined-stress successes for every controller in the stochastic matrix, and the manual and Fuzzy-PID pick-transfer-place runs were unsuccessful. Independent Simulink and Multibody trajectories agree with the MATLAB implementation to near floating-point roundoff under the fixed nominal protocol. These results support a reproducible controller comparison and an integration boundary for future embodied-AI planners, but they are simulation evidence and not hardware validation.

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

The baseline robot has link lengths of 0.45 m and 0.35 m, link masses of 2.00 kg and 1.50 kg, and a nominal payload of 0.50 kg. Gravity is 9.81 m/s². Joint torque commands are limited to 25.0 N m and 15.0 N m. These limits are applied inside every controller path rather than imposed only during post-processing.

| Parameter | Joint/link 1 | Joint/link 2 | Unit |
|---|---:|---:|---|
| Link length | 0.450 | 0.350 | m |
| Link mass | 2.000 | 1.500 | kg |
| Center of mass | 0.2250 | 0.1750 | m |
| Rotational inertia | 0.03375 | 0.01531 | kg m² |
| Viscous friction | 0.050 | 0.040 | N m s/rad |
| Torque limit | 25.0 | 15.0 | N m |

The nominal reference lasts 5.0 s and contains 5001 samples at a 0.0010 s step. The fixed-step protocol prevents solver-selection changes from becoming an unreported source of variation. The final 0.50 s is used for steady-state acceptance. Both joints must remain below the stored RMS and maximum-error thresholds; no controller receives a relaxed task-specific joint criterion.

The analytical MATLAB dynamics are the primary experimental plant. A generated Simulink model reproduces the same signal flow and integration contract. A separate Simscape Multibody model represents bodies and revolute joints using the physical-network formulation described by MathWorks [6]. Using three implementations helps expose wiring, sign, state-order, and unit errors, but all three still inherit the same parameter assumptions.

## Controller Design and Tuning

The manual PID law applies proportional action to joint error, integral action to accumulated error, and derivative action to the reference-minus-state velocity difference. Each joint uses derivative filtering, torque saturation, and back-calculation anti-windup. The Fuzzy-PID path begins with the same base gains. Its Mamdani engine evaluates scaled error and error rate, then produces bounded fractional corrections to (K_p), (K_i), and (K_d). This is gain scheduling within explicit limits, not an unconstrained replacement for the PID loop.

| Controller | (K_p) J1/J2 | (K_i) J1/J2 | (K_d) J1/J2 | Design role |
|---|---|---|---|---|
| Manual PID | 120.000 / 100.000 | 40.000 / 30.000 | 25.000 / 18.000 | Transparent baseline |
| Mamdani Fuzzy-PID | 120.000 / 100.000 | 40.000 / 30.000 | 25.000 / 18.000 | Bounded online correction |
| Optimized PID | 240.000 / 200.000 | 79.955 / 30.203 | 29.313 / 18.397 | Constrained offline tuning |

The Fuzzy-PID correction fractions are capped at 0.35 for proportional gain, 0.50 for integral gain, and 0.30 for derivative gain. Error and error-rate scaling are also frozen in the artifact. These bounds matter to interpretation: nominal Fuzzy-PID behavior reflects a deliberately conservative nonlinear schedule, not an unrestricted search for the smallest error.

Offline PID tuning uses `fmincon`, a constrained nonlinear optimizer [5]. Six gain multipliers are bounded and scored by a composite objective containing tracking RMS, overshoot, torque RMS, settling behavior, saturation penalty, and failure penalty. The SQP run completed with exit flag 1 after 12 iterations and 96 objective evaluations. The optimizer changes controller gains only; it does not change robot parameters, reference motion, actuator limits, or evaluation thresholds.

## Experimental Design

The experimental design contains complementary layers rather than one aggregated benchmark. Nominal joint tracking establishes basic correctness. A held-out payload evaluates whether optimized gains retain their advantage away from the training plant. The deterministic matrix varies payload, geometry/configuration, model uncertainty, actuator authority, and disturbance conditions, including a combined stress case. The stochastic matrix uses paired seeds so that all controllers see equivalent noise realizations within each scenario. Cartesian experiments test a straight-line path and a pick-transfer-place sequence. Finally, two independent models reproduce nominal manual and optimized PID trajectories.

| Evidence layer | Frozen size | Primary decision |
|---|---:|---|
| Nominal comparison | 5.0 s per controller | Final-window tracking acceptance |
| Deterministic robustness | 39 runs | Scenario-level success and failure |
| Stochastic robustness | 360 paired trials | Rate, interval, chattering, recovery |
| Cartesian tasks | 6 runs | Path and waypoint acceptance |
| Simulink validation | 2 runs | Signal-model agreement |
| Multibody validation | 2 runs | Physical-network agreement |

The nominal success gate uses a steady-state RMS limit of 0.020 rad per joint and a steady-state maximum-error limit of 0.050 rad per joint. The same gate remains active for task-level evaluation. This prevents a Cartesian path from being labeled successful when its endpoint looks acceptable but a joint fails the established steady-state condition.

The deterministic matrix has 13 scenarios per controller. The stochastic design contains 4 scenario families and 30 fixed-seed trials for each controller-scenario pair. Paired evaluation reduces comparison noise, while the Wilson interval communicates the uncertainty that remains in a finite observed success rate [4]. No failed run is deleted from the summary.

## Results

Both nominal controllers complete the trajectory without saturation and pass the stored gate. Manual PID steady-state RMS errors are 0.001268 rad and 0.013762 rad. Fuzzy-PID errors are 0.009792 rad and 0.013174 rad. The result is mixed rather than uniformly directional: Fuzzy-PID is worse on joint 1 but slightly better on joint 2 under this nominal reference.

| Controller | Steady RMS J1 (rad) | Steady RMS J2 (rad) | Torque RMS J1 (N m) | Torque RMS J2 (N m) | Success |
|---|---:|---:|---:|---:|---|
| Manual PID | 0.001268 | 0.013762 | 12.5025 | 2.6202 | Pass |
| Fuzzy-PID | 0.009792 | 0.013174 | 12.4321 | 2.6316 | Pass |

![Nominal joint tracking for manual PID and bounded Mamdani Fuzzy-PID.](../../results/figures/nominal_pid_vs_fuzzy_tracking.png)

The optimization objective decreases from 0.202427 to 0.187684, a 7.283% reduction. The held-out objective changes from 0.214504 to 0.197284. This supports an accuracy improvement under both training and payload-shift conditions, but it is a local constrained result from one frozen objective and search budget.

| Optimization quantity | Initial/manual | Final/optimized | Interpretation |
|---|---:|---:|---|
| Nominal composite objective | 0.202427 | 0.187684 | Training condition improved |
| Held-out composite objective | 0.214504 | 0.197284 | Payload-shift condition improved |
| Solver iterations | — | 12 | SQP termination record |
| Function evaluations | — | 96 | Frozen search cost |

![Constrained PID objective history and final solution.](../../results/figures/pid_optimization_objective.png)

The broader deterministic result is 8/13, 9/13, and 10/13 deterministic successes for manual PID, Fuzzy-PID, and optimized PID. Their success rates are 0.6154, 0.6923, and 0.7692. Mean joint RMS decreases for the optimized controller, yet all three fail the combined deterministic condition. A higher aggregate rate therefore does not remove the common high-stress weakness.

| Controller | Successes | Failures | Mean joint RMS (rad) | Worst joint RMS (rad) | Worst EE maximum (m) |
|---|---:|---:|---:|---:|---:|
| Manual PID | 8 | 5 | 0.13109 | 0.83476 | 1.80462 |
| Fuzzy-PID | 9 | 4 | 0.13042 | 0.83604 | 1.80380 |
| Optimized PID | 10 | 3 | 0.11074 | 0.83037 | 1.80704 |

![Deterministic robustness success and error summary.](../../results/figures/deterministic_robustness_summary.png)

The stochastic matrix contains 360 paired stochastic trials. Every controller succeeds in all isolated low-, medium-, and high-noise trials, but every controller records 0/30 in the combined stochastic condition. In other words, the study has 0/30 combined-stress successes for every controller. This combined stress result is the strongest counterweight to a simple ranking based on nominal RMS.

Noise also exposes a control-effort trade-off. At high noise, mean torque slew is 1520.28, 1631.16, and 2888.34 N m/s for manual PID, Fuzzy-PID, and optimized PID. The optimized controller tracks more accurately but produces the largest chattering proxy. This behavior is visible despite all isolated-noise trials passing the binary gate.

| High-noise controller | Successes/trials | Mean joint RMS (rad) | Mean torque slew (N m/s) | Worst saturation (s) |
|---|---:|---:|---:|---:|
| Manual PID | 30/30 | 0.04561 | 1520.28 | 0.001 |
| Fuzzy-PID | 30/30 | 0.04511 | 1631.16 | 0.003 |
| Optimized PID | 30/30 | 0.02281 | 2888.34 | 0.015 |

![Stochastic robustness chattering and torque-slew comparison.](../../results/figures/stochastic_robustness_chattering.png)

Cartesian results further distinguish joint accuracy from task completion. All three controllers pass the straight-line task. In the more demanding sequence, the manual and Fuzzy-PID pick-transfer-place runs were unsuccessful, while optimized PID passes. The failed runs are completed simulations, not crashes; they fail the unchanged quantitative acceptance logic. This distinction matters because suppressing completed-but-unsuccessful cases would bias the task narrative.

| Task/controller | Cartesian RMS (m) | Cartesian maximum (m) | Pickup error (m) | Place error (m) | Acceptance |
|---|---:|---:|---:|---:|---|
| Straight/manual | 0.03254 | 0.06023 | — | — | Pass |
| Straight/Fuzzy-PID | 0.03146 | 0.05951 | — | — | Pass |
| Straight/optimized | 0.01646 | 0.03190 | — | — | Pass |
| Pick-transfer-place/manual | 0.02774 | 0.05403 | 0.02439 | 0.00701 | Unsuccessful |
| Pick-transfer-place/Fuzzy-PID | 0.02685 | 0.05359 | 0.02296 | 0.01190 | Unsuccessful |
| Pick-transfer-place/optimized | 0.01422 | 0.02970 | 0.01193 | 0.00364 | Pass |

![Cartesian straight-line and pick-transfer-place paths.](../../results/figures/cartesian_tasks_paths.png)

## Independent Model Validation

The Simulink study compares manual and optimized PID runs against the MATLAB simulator. Both agreement flags and both tracking-success flags pass. The largest reported joint-position RMS difference is 5.3425e-17 rad for the first manual row and remains at floating-point scale across the table. The rigid-body term audit reports maximum discrepancies of 2.2204e-16, 4.3021e-15, and 3.5527e-15 for inertia, velocity-product, and gravity calculations.

The Multibody study also passes both agreement and tracking gates. Its worst end-effector difference is 3.3422e-16 m, and maximum out-of-plane motion is 0.0 m. These values support implementation consistency between the analytical and physical-network paths for the fixed nominal experiment.

| Validation path | Rows | Agreement passes | Tracking passes | Largest highlighted difference |
|---|---:|---:|---:|---:|
| MATLAB vs Simulink | 2 | 2 | 2 | 2.2204e-16 rad |
| MATLAB vs Multibody | 2 | 2 | 2 | 3.3422e-16 m |

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

[1] K. J. Åström and T. Hägglund, “The future of PID control,” *Control Engineering Practice, vol. 9, no. 11*, pp. 1163–1175, 2001. https://doi.org/10.1016/S0967-0661(01)00062-4

[2] L. A. Zadeh, “Fuzzy sets,” *Information and Control, vol. 8, no. 3*, pp. 338–353, 1965. https://doi.org/10.1016/S0019-9958(65)90241-X

[3] E. H. Mamdani and S. Assilian, “An experiment in linguistic synthesis with a fuzzy logic controller,” *International Journal of Man-Machine Studies, vol. 7, no. 1*, pp. 1–13, 1975. https://doi.org/10.1016/S0020-7373(75)80002-2

[4] E. B. Wilson, “Probable inference, the law of succession, and statistical inference,” *Journal of the American Statistical Association, vol. 22, no. 158*, pp. 209–212, 1927. https://doi.org/10.1080/01621459.1927.10502953

[5] MathWorks, “fmincon: Solve constrained nonlinear multivariable minimization problem,” *Optimization Toolbox documentation*, pp. online, 2026. https://www.mathworks.com/help/optim/ug/fmincon.html

[6] MathWorks, “Simscape Multibody: Model and simulate multibody mechanical systems,” *Simscape Multibody documentation*, pp. online, 2026. https://www.mathworks.com/help/sm/

[7] D. Driess et al., “PaLM-E: An Embodied Multimodal Language Model,” *arXiv preprint arXiv:2303.03378*, pp. online, 2023. https://arxiv.org/abs/2303.03378

[8] B. Zitkovich et al., “RT-2: Vision-Language-Action Models Transfer Web Knowledge to Robotic Control,” *Proceedings of the 7th Conference on Robot Learning, PMLR 229*, pp. 2165–2183, 2023. https://proceedings.mlr.press/v229/zitkovich23a.html
