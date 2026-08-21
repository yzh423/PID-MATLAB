# Phase 7B Claim Audit

Date: 2026-08-21
Auditor: fresh zero-context `paper-claim-audit` child task
Audited commit: `8ef0947c237432097028bb0c194808dc686cc81c`

## Overall Verdict: PASS

All 11 required claim groups reconcile to the admitted evidence set. I found no unsupported claims, stale hashes, ambiguous mappings, visual failures, or source-block defects.

The skill's separate reviewer-agent helper was not exposed inside this child-task context. Fallback used: this task itself was launched as a fresh zero-context auditor, and a forensic trace was written to `.aris/traces/paper-claim-audit/2026-08-21_run12/`.

## Counts

- Claim groups audited: 11
- Atomic claim checks recorded: 72
- exact_match groups: 6
- rounding_ok groups: 5
- ambiguous_mapping: 0
- missing_evidence: 0
- unsupported_claims: 0
- warn_count: 0
- fail_count: 0

## Evidence And Provenance

- Core artifacts matched the current manifest: `presentation/final_presentation.pptx`, `docs/summary/research_summary.docx`, and `docs/summary/research_summary.pdf`.
- Every PPTX note `[Sources]` entry and the summary source line is repo-relative, exists, and has a matching admitted hash through the Phase 7B manifest/package or the Phase 7A report manifest chain.
- The raw ledger admits 14 MAT/CSV evidence files and 6 figure PNGs; all current hashes match.
- `results/report/report_evidence.json` was used only as an index/cross-check, not as substitute numeric evidence.
- `docs/presentation/phase7b_layout_report.json` was used only for layout/hash provenance; title size was independently checked from PPTX OOXML.

## Visual Check

Fresh renders were inspected for all 11 outputs:

- 10 PPTX slides rendered through an owned, read-only PowerPoint COM session at 1280 x 720.
- DOCX summary opened read-only through an owned Word COM session, exported to a one-page PDF, and rasterized.
- Reviewed summary PDF rasterized directly to a one-page PNG.
- All rendered outputs were nonblank, had clean edge bands, showed no clipping or obvious overlap, and had readable titles/body text.
- Slide 9 title run sizes are 36.0 pt in PPTX OOXML, satisfying the >=35 pt requirement.

The official Artifact Tool render path was not used because the official runtime `node_modules` directory is genuinely empty; no alternate runtime was installed or substituted.

## Test Summary

- Canonical audit CLI before commit: PASS, `PHASE7B_AUDIT_VERIFIED claims=11 findings=0`.
- Node atomic tests: PASS, 6/6.
- Full presentation Python suite with bundled Python: PASS, 77 tests run, 76 passed, 1 skipped because the official Artifact Tool runtime is unavailable and the official `node_modules` directory is genuinely empty.

## Claim Groups

| # | Location | Status | Atomic checks | Evidence summary |
|---|---|---:|---:|---|
| 1 | Slide 1 | exact_match | 5 | Nominal MAT verifies a 2-link manipulator; admitted multibody figure and source hashes match. |
| 2 | Slide 2 | exact_match | 6 | Raw stress CSVs support the payload/configuration/noise/disturbance/actuator scope, retained failed completed runs, and simulation-only limitation. |
| 3 | Slide 3 | exact_match | 7 | Nominal MAT recomputes 0.001 s, 5.0 s, and 5001 samples; paired-seed and shared-protocol checks pass. |
| 4 | Slide 4 | rounding_ok | 8 | `pid_optimization.mat` recomputes 7.283147860458988%, 0.21450363216387297 to 0.19728400491642561, exit flag 1, 12 iterations, and 96 evaluations. |
| 5 | Slide 5 | exact_match | 6 | Deterministic CSVs recompute 39 runs, 13 scenarios, success counts 8/9/10, seven categories, and shared combined-case failure. |
| 6 | Slide 6 | rounding_ok | 7 | Stochastic CSVs recompute 360 paired-seed trials, isolated cells at 30/30, combined cells at 0/30, and high-noise optimized torque slew 2888.34441441764. |
| 7 | Slide 7 | rounding_ok | 6 | Cartesian CSV recomputes six completed runs, four successes, only optimized pick-transfer-place success, RMS 0.0142210111046117 m, max 0.029698222399069 m. |
| 8 | Slide 8 | rounding_ok | 6 | Simulink and Multibody CSVs recompute 2/2 agreement/tracking passes; worst end-effector difference is 3.34221388864417e-16 m. |
| 9 | Slide 9 | exact_match | 6 | Deterministic, Cartesian, stochastic, and nominal raw evidence support the conditional strongest-baseline conclusion and torque-slew trade-off. |
| 10 | Slide 10 | exact_match | 4 | Next-step claims are prospective and correctly scoped as not-yet-claimed validation/safety/perception work. |
| 11 | DOCX/PDF summary | rounding_ok | 11 | DOCX equals package text; PDF is semantically equivalent with line wrapping only; one-page renders are clean. |

## Findings

None.
