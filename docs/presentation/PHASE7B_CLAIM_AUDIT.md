# Phase 7B Claim Audit — Fresh Run 11

**Verdict:** PASS

**Audited commit:** `64dfdc297ab45539a5a4194b68aca8eced584c20`

**Claim groups:** 11 (`exact_match`: 7; `rounding_ok`: 4)
**Findings:** 0 ambiguous, 0 missing, 0 unsupported, 0 WARN, 0 FAIL

## Input and provenance gate

- The seven canonical audit inputs were hashed at the audited HEAD using repository-relative paths.
- The raw evidence ledger admits exactly 14 MAT/CSV files; all 14 exist and match their SHA-256 values.
- The admitted visual set contains exactly six PNG files; all six exist and match the Phase 7A/7B manifests.
- The Phase 7B manifest covers all 14 raw files and all six figures. The current package matches the Phase 7A manifest, report-evidence, and raw-ledger hashes.
- No prior audit, run06–10 trace, or SDD report/review was used as evidence.

## Claim groups

| # | Location | Category | Raw recomputation | Status |
|---:|---|---|---|---|
| 1 | Slide 1 | System scope | Raw robot arrays contain two links; admitted Multibody figure is present. | exact_match |
| 2 | Slide 2 | Problem/scope | Deterministic/stochastic/Cartesian raw rows cover the named stressors and retain completed failures; scope is simulation-only. | exact_match |
| 3 | Slide 3 | Protocol | `dt=0.001 s`, duration `5.0 s`, `5001` samples; references, limits, thresholds, scenario parameters and stochastic seeds are shared as claimed. | exact_match |
| 4 | Slide 4 | Optimization | `(0.202426799460455 - 0.18768375634655526) / 0.202426799460455 = 7.283147860458988%`; held-out `0.21450363216387297 → 0.19728400491642561`; flag `1`, `12` iterations, `96` evaluations. | rounding_ok |
| 5 | Slide 5 | Deterministic | Grouping 39 raw rows gives manual `8/13`, Fuzzy `9/13`, optimized `10/13`; all three combined rows fail. | exact_match |
| 6 | Slide 6 | Stochastic | `360 = 4 × 3 × 30`; all nine isolated-noise cells are `30/30`, all three combined cells are `0/30`; optimized high-noise torque slew is `2888.3444144176433 N m/s` and its tracking error is lowest. | rounding_ok |
| 7 | Slide 7 | Cartesian | Six completed rows give four passes and two failures; all straight-line rows pass and only optimized pick-transfer-place passes; optimized errors are `0.0142210111046117 m` RMS and `0.029698222399069 m` max. | rounding_ok |
| 8 | Slide 8 | Cross-validation | Simulink and Multibody each pass `2/2`; worst Multibody end-effector difference is `3.34221388864417e-16 m`; out-of-plane maximum is zero. | rounding_ok |
| 9 | Slide 9 | Conclusion | Optimized PID leads deterministic and Cartesian success, nominal manual/Fuzzy metrics are mixed, and optimized PID has the high-noise torque-slew trade-off. | exact_match |
| 10 | Slide 10 | Future scope | Hardware, perception, collision avoidance, monitoring, and safety are explicitly future milestones, consistent with the simulation-only admitted evidence. | exact_match |
| 11 | DOCX/PDF summary | Summary consistency | The one-page DOCX/PDF repeats the recomputed two-link, `0.001 s`, `7.283%`, `10/13`, and `30/30 vs 0/30` claims plus the bounded conclusion and limitations. | rounding_ok |

## Category mapping

- Deterministic: nominal (1 scenario), payload (3), configuration (2), uncertainty (4), disturbance (1), actuator (1), combined (1).
- Stochastic: isolated noise = `noise-low`, `noise-medium`, `noise-high`; combined stress = `combined-stochastic`.
- Cartesian: `straight-line` and `pick-transfer-place`, each evaluated for all three controllers.

## Visual and structural audit

- PowerPoint COM fresh render: 10/10 slides inspected individually; no clipping, overlap, broken glyphs, unreadable chart, or margin defect.
- Current summary PDF fresh PDFium render: 1/1 page inspected; no layout defect.
- Presenter notes: 10/10 present and 10/10 contain `[Sources]` blocks.

## Verification gate

- Nonruntime suite: 66 tests passed with one allowed conditional skip because the official Artifact Tool runtime is unavailable.
- The JSON sibling is authoritative and contains the exact seven current hashes, 11 claim groups, zero findings, repository-relative sources, and a minimal reproducibility ledger independent of the ephemeral metadata trace.
