# Simulation, Adaptive Control, and Optimization Framework for Reliable Robotic Manipulation

## Implementation Guide for Daniel

**面向可靠机器人执行的仿真、自适应控制与优化研究**

Project advisor: Tom Tan, Ph.D.  
Primary platform: MATLAB and Simulink  
Recommended project duration: 8–10 weeks

> **Project note:** Revision focus: Adds optimization-assisted controller tuning in response to Daniel's feedback while preserving the original low-level-control scope. Robot morphology remains a robustness/generalization variable, not an optimization target.

> Project purpose

Build a credible, manageable research project that connects task-driven robot design with reliable low-level execution. The final work should demonstrate modeling, controller design, robustness testing, quantitative comparison, engineering judgment, and research communication.

## 1. Project Overview

This project investigates how a robotic manipulator can execute desired motions accurately and reliably when its physical configuration, payload, actuator limits, and operating conditions vary. The core remains a low-level control and execution project: model the robot, establish a conventional PID baseline, develop an adaptive Fuzzy-PID controller, add a lightweight optimization-assisted controller-tuning layer, and evaluate reliability under realistic uncertainties. The project intentionally does not attempt to reproduce the high-level robot-design or embodied-AI work already covered by Daniel's other research.

The project is designed to complement your current internship. Your internship focuses on task-driven robot design and higher-level intelligence, including morphology/hardware choices and possible learning or evolutionary methods. This MATLAB project focuses on the complementary question: once a robot configuration and desired task trajectory are given, how can the low-level controller execute the motion accurately, efficiently, and robustly? Optimization is introduced only to tune controller parameters; robot morphology is varied for robustness testing, not optimized as a design objective.

| Stanford / existing research | MATLAB project |
| --- | --- |
| Task-driven robot design, morphology/hardware optimization, embodied-AI or high-level intelligence | Reliable low-level trajectory execution, adaptive control, and controller-parameter optimization |
| DOF, link length, motor parameters, task data, possible RL/evolutionary optimization | Robot dynamics, PID/Fuzzy-PID, optimized gain tuning, disturbances, payload changes, actuator limits, robustness across configurations |

Together, the two projects create a coherent research pipeline:

High-level task / planner → Desired trajectory → Given robot configuration → PID / Fuzzy-PID → Optimization-assisted controller tuning → Reliable physical execution

## 2. Central Research Question

> Can adaptive and optimization-assisted low-level control maintain accurate and reliable trajectory execution across robotic manipulators with different physical configurations and operating conditions?

### 2.1 Supporting questions

- How well does a fixed-gain PID controller perform when payload, link length, inertia, or motor limits change?

- Can Fuzzy-PID reduce tracking error and improve disturbance rejection without excessive control effort?

- Which controller generalizes more reliably across multiple arm configurations?

- What tradeoffs exist among accuracy, smoothness, robustness, and actuator effort?

- How can the low-level controller serve as a reliable execution layer beneath an embodied-AI or VLA planner?

- Can a numerical optimization method automatically tune controller gains to improve tracking performance and control effort compared with manual tuning?

## 3. Required Scope and Optional Extensions

### 3.1 Required core project

- [ ] A configurable 2-DOF planar robotic manipulator.

- [ ] At least three representative robot configurations.

- [ ] Forward and inverse kinematics.

- [ ] A dynamic model or a clearly documented simplified plant model.

- [ ] Point-to-point and trajectory-tracking tasks.

- [ ] Baseline PID control.

- [ ] Fuzzy-PID or another adaptive gain-scheduling method.

- [ ] Robustness tests involving payload variation, disturbance, sensor noise, parameter uncertainty, and actuator saturation.

- [ ] Quantitative comparison using consistent metrics.

- [ ] A technical report, MATLAB/Simulink files, figures, GitHub repository, and presentation.

- [ ] Optimization-assisted tuning of PID or Fuzzy-PID controller parameters using one practical MATLAB optimization method.

### 3.2 Optional extensions

- Extend the arm from 2 DOF to 3 DOF.

- Add a neural-network-assisted tuner only as future work or a late optional extension.

- Add model predictive control.

- Generate trajectories from a simple pick-and-place task command.

- Compare a second controller-tuning optimizer only if the core optimization study is already complete.

- [ ] Check which optimization tools are available (Optimization Toolbox, Global Optimization Toolbox, or Statistics and Machine Learning Toolbox for bayesopt). Use only what is available; do not make multiple toolboxes a project requirement.

- Validate one experiment using Robotics System Toolbox or Simscape Multibody.

> **Project note:** Do not begin optional extensions until all required experiments, plots, and written explanations are complete.

## 4. Learning Objectives

- Translate a robotics problem into a mathematical and simulation model.

- Implement and tune a conventional feedback controller.

- Design an intelligent or adaptive controller using engineering logic.

- Evaluate reliability under uncertainty rather than only under ideal conditions.

- Interpret results using quantitative metrics instead of visual impressions alone.

- Write reproducible code and organize a professional GitHub repository.

- Explain how low-level control connects to embodied AI and robotic manipulation research.

- Use numerical optimization to tune controller parameters from a defined performance objective without turning the project into a robot-morphology optimization study.

## 5. Robotic Manipulator Model

### 5.1 Initial model

Begin with a planar 2-link revolute-joint arm. This model is complex enough to demonstrate robotics, kinematics, nonlinear dynamics, coupled joints, trajectory tracking, and actuator constraints, but simple enough to complete within the application timeline.

| Parameter | Symbol | Initial value | Variation for experiments |
| --- | --- | --- | --- |
| Link 1 length | L1 | 0.45 m | 0.35–0.55 m |
| Link 2 length | L2 | 0.35 m | 0.25–0.45 m |
| Link 1 mass | m1 | 2.0 kg | ±20% |
| Link 2 mass | m2 | 1.5 kg | ±20% |
| Payload | mp | 0.5 kg | 0–1.5 kg |
| Joint torque limit | τmax | Defined per motor | Low / medium / high |
| Sensor noise | n | 0 initially | Several noise levels |
| External disturbance | d | 0 initially | Impulse or bounded force |

### 5.2 Representative robot configurations

| Configuration | L1 | L2 | Relative inertia | Purpose |
| --- | --- | --- | --- | --- |
| A: Compact arm | Short | Short | Low | Fast motion, limited reach |
| B: Baseline arm | Medium | Medium | Medium | Reference configuration |
| C: Extended arm | Long | Long | High | Greater reach, stronger coupling and torque demand |

### 5.3 Modeling level

Use the most rigorous model that can be completed reliably. The preferred order is:

1. First choice: nonlinear rigid-body dynamics for a 2-link manipulator.

1. Second choice: Simscape Multibody model with clearly defined physical parameters.

1. Fallback: simplified second-order joint models, provided that all assumptions and limitations are clearly stated.

> **Project note:** The final report must clearly separate physical parameters, controller parameters, and test conditions.

## 6. Motion Tasks

### 6.1 Task 1: Joint-space point-to-point motion

Move both joints from an initial angle vector to a final angle vector using a smooth reference trajectory. This is the easiest task for controller tuning and debugging.

### 6.2 Task 2: End-effector path tracking

Track a simple Cartesian path such as a straight line, arc, or ellipse. Use inverse kinematics to convert the desired end-effector path into joint references.

### 6.3 Task 3: Simplified pick-and-place sequence

Define a start point, pickup point, intermediate safe point, and placement point. The project does not need vision or grasp planning. Assume that a high-level planner has already produced the desired waypoints.

## 7. Controller Development

### 7.1 Baseline PID controller

Implement independent joint PID control first. Tune gains using a repeatable method and document the final values. The PID controller establishes the baseline against which all advanced methods will be compared.

- [ ] Plot desired and actual joint angles.

- [ ] Plot joint tracking errors.

- [ ] Plot control torque or command.

- [ ] Check overshoot, settling time, steady-state error, and oscillation.

- [ ] Verify performance before adding disturbances.

### 7.2 Fuzzy-PID controller

The recommended intelligent controller is Fuzzy-PID because it is achievable within the schedule and connects well with the advisor's background in neural-network-based fuzzy control.

Suggested fuzzy inputs:

- Tracking error e.

- Rate of change of error de/dt.

- Optional normalized operating condition such as payload estimate or torque utilization.

Suggested fuzzy outputs:

- Adjustment to proportional gain ΔKp.

- Adjustment to derivative gain ΔKd.

- Optional adjustment to integral gain ΔKi.

Example rule logic:

- If error is large, increase proportional action.

- If error changes rapidly, increase damping.

- If error is small and persistent, increase integral action carefully.

- If actuator command approaches saturation, reduce aggressive gain increases.

### 7.3 Optimization-assisted controller tuning

After the baseline PID and Fuzzy-PID controllers are working, add one lightweight numerical optimization layer to tune selected controller parameters automatically. The purpose is not to optimize robot morphology; link lengths and other physical configurations remain prescribed test cases. This extension responds to the interest in optimization while preserving the project's low-level-control focus and its complementarity with Daniel's other research.

Recommended optimization variables:

- PID gains Kp, Ki, and Kd for each joint.

- Optionally, a small number of Fuzzy-PID scaling factors or gain-adjustment limits after the basic fuzzy controller is stable.

Define a scalar objective function that combines the quantities we care about. A simple form is:

> **Project note:** J = w1(RMS tracking error) + w2(overshoot) + w3(control effort) + w4(settling time) + penalty terms for actuator saturation or constraint violations.

Use one practical MATLAB method first. Suitable choices include fmincon for bounded continuous tuning, patternsearch or ga when the objective is non-smooth or has many local minima, or bayesopt if Bayesian optimization is specifically desired and the required toolbox is available. The project does not need to compare all methods. One well-documented optimizer is enough.

Required evidence:

- [ ] Compare manually tuned PID against optimization-tuned PID under identical trajectories and nominal conditions.

- [ ] Verify that optimization does not simply reduce tracking error by creating excessive torque or saturation.

- [ ] Test the optimized controller on at least one condition not used during tuning, such as a different payload or robot configuration.

- [ ] Record the objective definition, parameter bounds, solver settings, initial guesses or random seeds, and final gains so the process is reproducible.

### 7.4 Optional neural-assisted or MPC controller

Only add one optional advanced method after PID, Fuzzy-PID, and the optimization-assisted tuning study are fully working. A neural network may estimate gain corrections from state and operating conditions, and MPC may be used to handle constraints explicitly. Neither is required for a strong project, and neither should displace the core reliability experiments.

## 8. Reliability and Robustness Test Matrix

| Test | What changes | Why it matters | Expected evidence |
| --- | --- | --- | --- |
| Nominal | No disturbance; baseline parameters | Confirms correct implementation | Clean tracking and stable response |
| Payload variation | Change end-effector payload | Tests model mismatch and torque demand | Error and control effort vs payload |
| Link-length variation | Use configurations A, B, C | Tests controller transfer across prescribed morphology variation; this is not morphology optimization | Generalization across arm designs |
| Mass/inertia uncertainty | ±10% and ±20% | Represents imperfect modeling | Robustness to parameter uncertainty |
| External disturbance | Impulse or bounded force/torque | Tests disturbance rejection | Recovery time and peak deviation |
| Sensor noise | Add angle/velocity noise | Tests sensitivity | Error variance and control chattering |
| Actuator saturation | Apply torque limits | Represents real motors | Constraint violations and task completion |
| Combined stress test | Payload + noise + disturbance + saturation | Tests realistic reliability | Success rate and worst-case metrics |

## 9. Evaluation Metrics

| Metric | Meaning | How to use it |
| --- | --- | --- |
| RMS tracking error | Average magnitude of trajectory error | Primary accuracy metric |
| Maximum absolute error | Worst deviation during the task | Safety and reliability indicator |
| Settling time | Time needed to remain near the target | Speed of recovery |
| Overshoot | Amount beyond the desired value | Transient quality |
| Steady-state error | Residual error after settling | Final precision |
| Control effort | Integral or RMS of torque/command | Energy and actuator burden |
| Torque saturation time | Time spent at actuator limit | Feasibility with real motors |
| Recovery time | Time to recover after disturbance | Disturbance rejection |
| Task success rate | Percentage of trials meeting criteria | High-level reliability measure |
| Optimization objective J | Weighted performance score used for automatic tuning | Compare manual versus optimized tuning and document tradeoffs |

> **Project note:** Define success criteria before running the final experiments. For example: maximum end-effector error below a specified threshold, no joint-limit violation, and task completion within the allowed time.

## 10. Step-by-Step Implementation Workflow

### Step 1. Set up project structure

- [ ] Create a local project folder and GitHub repository.

- [ ] Add folders for models, controllers, experiments, results, figures, and report.

- [ ] Create a README with project purpose and software requirements.

### Step 2. Verify MATLAB environment

- [ ] Confirm access to MATLAB and Simulink.

- [ ] Check availability of Control System Toolbox and Fuzzy Logic Toolbox.

- [ ] Use Robotics System Toolbox or Simscape Multibody only if available and useful.

### Step 3. Build kinematics

- [ ] Define link parameters and joint limits.

- [ ] Implement forward kinematics.

- [ ] Implement or verify inverse kinematics for reachable targets.

- [ ] Plot the arm and end-effector path.

### Step 4. Build plant model

- [ ] Implement the nonlinear dynamic model or selected physical model.

- [ ] Test free response and simple commanded motion.

- [ ] Confirm units, signs, and initial conditions.

### Step 5. Generate reference trajectories

- [ ] Create smooth joint-space trajectories.

- [ ] Create one Cartesian path and convert it to joint references.

- [ ] Save the trajectories so all controllers use identical commands.

### Step 6. Implement and tune PID

- [ ] Start with one joint, then both joints.

- [ ] Tune under nominal conditions.

- [ ] Save final gains and tuning notes.

- [ ] Generate baseline plots and metrics.

### Step 7. Implement Fuzzy-PID

- [ ] Normalize fuzzy inputs and outputs.

- [ ] Create membership functions and rule base.

- [ ] Test gain changes under simple scenarios.

- [ ] Compare against PID under identical conditions.

### Step 8. Add optimization-assisted tuning

- [ ] Choose one controller to tune automatically (start with PID).

- [ ] Define parameter bounds and a scalar objective function using tracking error plus control-effort / constraint penalties.

- [ ] Select one MATLAB optimizer and document solver settings.

- [ ] Compare optimized gains with manual gains under identical nominal conditions.

- [ ] Validate the optimized controller on at least one unseen payload, disturbance, or configuration case.

### Step 9. Add robustness scenarios

- [ ] Implement one disturbance type at a time.

- [ ] Automate parameter sweeps.

- [ ] Store results in tables rather than manually copying numbers.

### Step 10. Run final comparison

- [ ] Use fixed random seeds where noise is involved.

- [ ] Run all controllers on the same test matrix.

- [ ] Export publication-quality plots and summary tables.

### Step 11. Write and package

- [ ] Complete the report while results are fresh.

- [ ] Clean code and add comments.

- [ ] Finalize README, figures, presentation, and one-page summary.

## 11. Recommended Repository Structure

```text
reliable-robotic-manipulation/
├── README.md
├── LICENSE
├── docs/
│   ├── project_plan.pdf
│   ├── technical_report.pdf
│   └── research_summary.pdf
├── models/
│   ├── arm_parameters.m
│   ├── forward_kinematics.m
│   ├── inverse_kinematics.m
│   └── robot_dynamics.m
├── controllers/
│   ├── pid_controller.m
│   ├── fuzzy_pid_controller.m
│   ├── optimization_objective.m
│   ├── optimize_pid_gains.m
│   └── optional_advanced_controller.m
├── trajectories/
│   ├── joint_trajectory.m
│   ├── cartesian_path.m
│   └── pick_and_place_waypoints.m
├── experiments/
│   ├── run_nominal_test.m
│   ├── run_payload_sweep.m
│   ├── run_configuration_sweep.m
│   ├── run_optimization_tuning.m
│   ├── run_disturbance_test.m
│   └── run_combined_stress_test.m
├── simulink/
│   └── robot_control_model.slx
├── results/
│   ├── data/
│   ├── tables/
│   └── figures/
└── presentation/
    └── final_presentation.pptx
```

## 12. Recommended 8-Week Schedule

| Week | Primary work | Required output | Advisor review |
| --- | --- | --- | --- |
| 1 | Project setup, literature orientation, parameter definition, kinematics | Repository, arm animation, parameter table | Confirm scope and model |
| 2 | Dynamics/plant model and trajectory generation | Working nominal plant and saved trajectories | Model verification |
| 3 | PID implementation and manual tuning | Baseline controller, plots, metrics | PID review |
| 4 | Fuzzy-PID design and nominal comparison | Membership functions, rules, PID vs Fuzzy-PID comparison | Controller logic review |
| 5 | Optimization-assisted controller tuning + initial robustness tests | Objective function, optimized gains, manual-vs-optimized comparison | Optimization method and fairness review |
| 6 | Payload, noise, disturbance, actuator limits, and robot-configuration sweep | Automated robustness scripts and A/B/C configuration comparison | Test design and interpretation review |
| 7 | Final experiments, unseen-condition validation, summary tables | Complete result set and selected figures | Confirm conclusions and application story |
| 8 | Technical report, GitHub cleanup, slides, research summary | Final project package | Final presentation |

> **Project note:** If the Stanford internship workload becomes heavy, extend the schedule to 10 weeks rather than reducing the quality of the core experiments. The minimum strong project is PID versus Fuzzy-PID across multiple reliability conditions. Optimization-assisted tuning is the preferred enhancement; it should be implemented with one practical method and should not expand into robot-morphology co-optimization during the main schedule.

## 13. Working Method and Meeting Cadence

- Meet with the advisor once each week for approximately 45–60 minutes.

- Send code, plots, and a short progress note at least one day before the meeting.

- Begin each meeting with: what was completed, what failed, what was learned, and the next milestone.

- Keep a research log with dated entries, parameter changes, failed attempts, and conclusions.

- Do not wait until the end to write. Draft the Methods section while building the model and the Results section while running experiments.

### 13.1 Weekly progress note template

| Completed this week |  |
| --- | --- |
| Main result |  |
| Problem or uncertainty |  |
| Files/figures for review |  |
| Plan for next week |  |

## 14. Final Deliverables

| Deliverable | Minimum standard | Application use |
| --- | --- | --- |
| Technical report | 8–12 pages with methods, experiments, results, limitations, and future work | CV, SOP, faculty outreach |
| MATLAB code | Readable, modular, commented, reproducible | Evidence of technical capability |
| Simulink model | Organized blocks and documented parameters | Visual demonstration |
| Figures and tables | Clear labels, units, legends, and consistent tests | Report and presentation |
| GitHub repository | Professional README and logical structure | Portfolio link |
| Presentation | 8–12 slides | Advisor and faculty discussion |
| One-page research summary | Problem, method, key results, significance | Faculty outreach and recommendations |
| Research log | Dated notes and decisions | Supports report writing and credibility |

## 15. Technical Report Structure

1. Abstract: 150–250 words summarizing the problem, methods, principal results, and significance.

2. Introduction: Explain why embodied-AI systems require reliable physical execution and why morphology variation creates control challenges.

3. Related Research Context: Briefly discuss robotic manipulation, adaptive control, controller tuning/optimization, and reliable execution. Keep robot morphology optimization as context from related research rather than the focus of this project.

4. Problem Formulation: Define the arm, tasks, assumptions, constraints, uncertainties, and research questions.

5. System Model: Present kinematics, dynamics, parameters, configurations, and trajectory generation.

6. Controller Design and Tuning: Describe PID tuning, Fuzzy-PID membership functions and rules, and the optimization-assisted tuning method, including objective function, parameter bounds, and solver settings.

7. Experimental Design: Define all tests, controller settings, optimization protocol, held-out validation conditions, success criteria, and metrics.

8. Results: Present nominal controller comparisons, manual-versus-optimized tuning results, robustness tests, morphology-variation tests, and combined stress-test results.

9. Discussion: Explain why each controller performed as observed, including tradeoffs and failure modes.

10. Connection to Embodied AI: Describe the controller as a reliable execution layer beneath a high-level task planner or VLA system. This is an architectural connection; a full planner/VLA implementation is not required.

11. Limitations and Future Work: Discuss simulation limitations, real-hardware validation, RL, higher-level AI integration, and morphology-control co-design as future work rather than required implementation.

12. Conclusion: State the main findings without exaggeration.

## 16. Quality Standards

### 16.1 Technical credibility

- [ ] Use SI units consistently.

- [ ] Document all assumptions.

- [ ] Use the same trajectories and test conditions for controller comparisons.

- [ ] Do not claim real-robot performance from simulation alone.

- [ ] Do not claim that the project implements a full VLA model if it only receives trajectories from a hypothetical planner.

- [ ] Report both successful and unsuccessful cases.

- [ ] Explain why a method works, not only that one curve looks better.

- [ ] Document optimization bounds, objective weights, solver settings, and random seeds or initial guesses.

- [ ] Treat A/B/C robot configurations as robustness test cases; do not claim morphology optimization unless such optimization is actually implemented.

### 16.2 Figures

- [ ] Every axis must have a label and unit.

- [ ] Every figure must have a descriptive caption.

- [ ] Avoid overcrowded plots; separate plots when interpretation becomes difficult.

- [ ] Use consistent time windows and scales when comparing controllers.

- [ ] Include at least one arm-path visualization and one summary comparison table.

### 16.3 Code

- [ ] Use meaningful function and variable names.

- [ ] Separate parameters from algorithms.

- [ ] Avoid hard-coded values inside multiple scripts.

- [ ] Add comments describing purpose and assumptions, not obvious syntax.

- [ ] Make the main experiments reproducible from one or a small number of scripts.

## 17. How This Project Supports Your Graduate Applications

The strongest way to describe this project is not as a generic MATLAB class exercise. It should be presented as an independent research project addressing the reliable execution problem in embodied robotics.

Suggested CV entry title: Independent Research Project — Optimization-Assisted Adaptive Control for Reliable Robotic Manipulation

Suggested one-sentence description: Developed a configurable MATLAB/Simulink framework to compare PID and adaptive Fuzzy-PID control, apply numerical optimization to controller tuning, and evaluate manipulator trajectory tracking under morphology variation, payload changes, disturbances, noise, and actuator constraints.

Suggested SOP narrative: My other robotics research explored how task requirements and data can guide robot design and higher-level intelligence, while my independent MATLAB research examined the complementary problem of reliable physical execution. I modeled manipulator dynamics, compared fixed and adaptive low-level control, used numerical optimization to tune controller parameters, and tested robustness under changing payloads, configurations, disturbances, noise, and actuator limits.

> **Project note:** The final application language must reflect the actual work completed. Do not list optional methods or results that have not been implemented.

## 18. Preparation for the First Project Meeting

- [ ] Confirm MATLAB/Simulink access and available toolboxes.

- [ ] Install Git and create a GitHub account if needed.

- [ ] Review basic PID control and 2-link robot kinematics.

- [ ] Bring a brief description of the internship project, including current tasks, expected methods, and confidentiality limits.

- [ ] Decide how many hours per week can realistically be committed.

- [ ] Prepare a list of questions about modeling, control, MATLAB, and report expectations.

### 18.1 Decisions to make during the first meeting

- [ ] Exact 2-link parameter values.

- [ ] Modeling approach: equations, Simscape Multibody, or hybrid.

- [ ] Required toolboxes and any licensing limitations.

- [ ] Final choice of intelligent controller.

- [ ] Choose one optimization method for controller tuning and confirm the required MATLAB toolbox is available.

- [ ] Weekly meeting day and progress-report format.

- [ ] Target completion date and whether a public GitHub repository is permitted.

## 19. Project Completion Checklist

- [ ] The manipulator model is validated and documented.

- [ ] All required trajectories are reproducible.

- [ ] PID and Fuzzy-PID use identical test conditions.

- [ ] Three robot configurations have been evaluated.

- [ ] One optimization-assisted controller-tuning method has been implemented and compared fairly with manual tuning.

- [ ] All required reliability tests have been run.

- [ ] Metrics are automatically calculated and stored.

- [ ] The main conclusions are supported by data.

- [ ] Code is organized and commented.

- [ ] The GitHub README explains how to reproduce results.

- [ ] The report states limitations honestly.

- [ ] The one-page research summary and presentation are complete.

- [ ] The final CV/SOP wording matches the work actually completed.

## 20. Final Guidance

A strong project is not the project with the largest number of algorithms. It is the project with a clear question, a correct implementation, fair experiments, quantitative evidence, and thoughtful interpretation. Complete the PID-versus-Fuzzy-PID comparison first, then add one optimization-assisted tuning method. Keep robot morphology as a controlled robustness variable rather than turning the project into a second morphology-optimization study.

**Core objective: Build a reliable low-level execution layer for robotic manipulation, strengthened by adaptive control and practical controller-parameter optimization, while remaining complementary to Daniel's higher-level AI and robot-design research.**
