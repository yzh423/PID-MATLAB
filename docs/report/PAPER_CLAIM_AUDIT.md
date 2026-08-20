# Paper Claim Audit Report

**Date:** 2026-08-21

**Auditor:** GPT-5.6-sol, high reasoning (fresh independent zero-context reviewer)

**Paper:** *Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation*
**Inputs:** current `technical_report.md`, `technical_report_template.md`, `report_evidence.json`, 14 frozen MAT/CSV sources, six selected figures, `references.json`, `build_manifest.json`, report tooling/tests, and a 121-file source-scope inventory. Prior paper-claim audit outputs and traces were excluded.

## Overall Verdict: PASS

All 15 independent claim groups reconcile to current raw evidence and source scope.

- exact_match: 15
- rounding_ok: 0
- WARN: 0
- FAIL: 0
- unsupported_claim: 0
- ambiguous_mapping: 0
- findings: 0

## Claim Groups

| # | Group | Status | Independent check |
|---:|---|---|---|
| 1 | protocol | PASS | Recomputed 5.0 s, 5001 samples, 0.001 s step, 0.50 s final window, 0.020/0.050 rad gates, full-study dimensions, and 145 pre-report plus 5 report MATLAB tests. |
| 2 | nominal | PASS | MAT values reproduce both success flags, zero saturation, steady RMS 0.001268/0.013762 and 0.009792/0.013174 rad, and torque RMS 12.5025/2.6202 and 12.4321/2.6316 N m. |
| 3 | optimization | PASS | Recomputed 0.202427 to 0.187684, 7.283147860% reduction, held-out 0.214504 to 0.197284, exit flag 1, 12 iterations, 96 evaluations, bounded six-gain mapping, and unchanged torque limits. |
| 4 | deterministic | PASS | Independently aggregated 39 unique rows: 13 scenarios per controller, success 8/9/10, failure 5/4/3, rates 0.6154/0.6923/0.7692, all table metrics, and three completed combined-condition failures. |
| 5 | stochastic | PASS | Independently aggregated 360 unique rows: 4 scenarios × 3 controllers × 30 trials; controller seed lists match within every scenario; all isolated trials pass; combined is 0/30 each; high-noise RMS, slew, saturation, and all 12 Wilson intervals recompute. |
| 6 | Cartesian | PASS | Six unique completed runs reproduce the table; straight-line passes 3/3; manual and Fuzzy-PID pick-transfer-place runs fail the unchanged gate; optimized PID passes. |
| 7 | rigid-body | PASS | Dynamics source matches the displayed equation; independent MAT audit gives M/Cq_dot/G maxima 2.2204e-16, 4.3021e-15, and 3.5527e-15. |
| 8 | Simulink | PASS | Two unique comparisons, two agreement passes, two tracking passes; manual QRmsJ1 5.3425e-17 and highlighted QMaxJ2 2.2204e-16 rad reconcile. |
| 9 | Multibody | PASS | Two unique comparisons, two agreement passes, two tracking passes; worst EE difference 3.3422e-16 m and out-of-plane maximum 0.0 m reconcile. |
| 10 | report structure | PASS | In-memory render is byte-equivalent to the current Markdown: 13 required headings, 3105 body words, 9 tables, 6 figures, 8 references, and no unresolved tokens. |
| 11 | figure captions | PASS | Visual inspection of all six PNGs confirms each caption describes its plotted controllers, metric, task, or cross-validation path. |
| 12 | citations | PASS | IDs 1–8 are contiguous, cited, and supported; bibliographic metadata and claim roles were checked against the four publisher records, official MathWorks pages, arXiv, and PMLR. |
| 13 | evidence admission | PASS | Corrected abstract wording is precise: 126 designated evidence paths are token-resolved; `load_evidence` enforces frozen dimensions/modes/source and figure counts, while `validate_report` separately enforces required failure and scope disclosures. Tests exercise both gates. |
| 14 | reproducibility/build | PASS | Evidence re-export from the 14 raw artifacts is byte-exact when preserving `generatedAt`; all manifest input/output hashes are current; Python report tests pass 21/21 and MATLAB report tests pass 5/5. |
| 15 | scope/absence | PASS | Claims remain simulation-only and explicitly exclude hardware validity. Search across the hashed 121-file implementation/test scope finds no camera, detector, language/VLA model, task-and-motion/grasp planner, collision system, or online safety supervisor implementation. |

## Findings

None.

## Exact Hash Ledger

Canonical inputs:

```text
technical_report.md sha256:b3a7da4d611c7e8ced71285309b4a9960c38155bf9670fe9fee46114361b4674
technical_report_template.md sha256:e7e88982b4ca1ab31dc82e6c4138022fffc32674eff221065283b15fa6ef0d7d
references.json sha256:5f4397716d25e3235003064a863b4154132c05ef9283b0777eb6db680c4eb019
build_manifest.json sha256:8d332308b5614d9413b595e17f3c2e379cfec135ba45bd74fcee3781a4b6b787
report_evidence.json sha256:1ae79caf7bf58fb71b77c4f58f18358ea4b7cdb540885f8fec55305cc2e8205d
```

Fourteen formal sources:

```text
nominal_pid_vs_fuzzy.mat sha256:b5beae1aea41673ce3ee781c8f5d0f51351e8a645c943a24004f4964d347b2d6
pid_optimization.mat sha256:260fb7ef05b2efcb3924013b8d5d9d2b5245d92acffe6d2235b7fa77c3d6b1a5
deterministic_robustness.mat sha256:2a3d0d810226cfb6e7da3494a4d10a6d40975ade57fc19ed0b1986119a1130d4
stochastic_robustness.mat sha256:6fa9320669bd241ccebafff5dc65e5164028e29d3e7b78ac3ca86e155c2a7912
cartesian_tasks.mat sha256:fc1a531af0f1f5b79c70294f03d91f2467038cf5c762494c9ba9d915666200d4
simulink_cross_validation.mat sha256:49e7603e2e24dab3151d753d0a969cf9fda1c0815f99f80e75c7c39ae98eab50
multibody_cross_validation.mat sha256:ea7de093220bddba82bbb22f6cb3c8403f9dc232b5a61db89c3e9c21ad64c436
deterministic_robustness_runs.csv sha256:9d0ddfd0c297fa43df351695d54c8a3ad427845ece588eaee79f4635c99dc8e0
deterministic_robustness_summary.csv sha256:1041f7b8a57b382bdd4ce7dc152f029cebac40b428f05f03b1de7085dd8c702c
stochastic_robustness_trials.csv sha256:5beaa1a23eb26b83f810ecae9f1937c8c1926870627d00bd590edf1ffde8b3e6
stochastic_robustness_summary.csv sha256:083188735f2e5636f3f7272825188f6f02a45185a19936e4e603021663c257cd
cartesian_tasks_runs.csv sha256:51d038f74682f3f371d13a95f883cff731517389b29425aae14255ba1535faa9
simulink_cross_validation_runs.csv sha256:6427d4d6f85c75dc0b7f4cc836a3360b0ba963d1eea513f9289a179d1ded2e43
multibody_cross_validation_runs.csv sha256:c69a5daa5552f2ed79ba176c3935b3dfe3157e3e9334e4dcee21f8b3fda112d0
```

Six figures:

```text
nominal_pid_vs_fuzzy_tracking.png sha256:cac5f9ec719e270142d9c5b7c98e840ad87e4343d443509d949dcc8d61fab900
pid_optimization_objective.png sha256:d05113ac3c02ca3aa54c3558ebe741d13f36f127ee93e851c312258407758ed5
deterministic_robustness_summary.png sha256:144d52b65285e37cf7e1cb7d6cba4237e223ea8399be79ff350edd59bb1ca300
stochastic_robustness_chattering.png sha256:abe9cc2c5451e5650c12b3ed68b5ce6f7af05a510c25bd4d28366b3b6fba3ae7
cartesian_tasks_paths.png sha256:2dcaa14c41b63c087c871fb7e2f3cf2699d92e47a865476e50e5d3b64ff6a2ac
multibody_cross_validation_tracking.png sha256:598b4f89069ca9198255c5db98736ef43476db1763f02e1d388353304db0a22d
```

The complete machine-readable input and tooling hashes are in `PAPER_CLAIM_AUDIT.json`. The 121-file source-scope aggregate is `sha256:8957108c6142a036dd82bf1f5cf02da312dad36f7b50f04dcb23aaffea1e2bcd`, computed over sorted UTF-8 lines `<repo-relative-path>=<lowercase-sha256>\n`.

**Trace:** `.aris/traces/paper-claim-audit/2026-08-21_run04/`
