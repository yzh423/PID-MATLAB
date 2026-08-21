# Phase 7B Claim Audit Report — run10

**Date:** 2026-08-21  
**Audited commit:** `1d7be155f760f21b73f071389cfafde59f6fdbe4`  
**Method:** fresh zero-context audit using only the current Phase 7B PPTX/DOCX/PDF/package/template/manifest and Phase 7A manifest, report evidence, raw MAT/CSV, and admitted PNG files.

## Overall verdict: PASS

Completion status is **DONE_WITH_CONCERNS** solely because the bundled `@oai/artifact-tool` dependency is absent. No installation, substitution, or runtime modification was attempted. This is an environment concern, not a claim finding.

- Claim groups: **exactly 11**
- `exact_match`: **6**
- `rounding_ok`: **5**
- ambiguous / missing / unsupported: **0 / 0 / 0**
- WARN / FAIL: **0 / 0**
- evidence tokens mapped: **32/32**

## Claims

| # | Surface | Raw reconciliation | Status |
|---:|---|---|---|
| 1 | Slide 1 | Raw model has two links; execution and Multibody evidence exist; opening remains simulation-scoped. | exact_match |
| 2 | Slide 2 | All named stress categories occur in raw rows. Completed failures remain present. | exact_match |
| 3 | Slide 3 | `0.001 s`, `5.0 s`, `5001`; every stochastic cell has the same 30 paired seeds. | exact_match |
| 4 | Slide 4 | Raw objective reduction is `7.283147860458988%`; held-out is `0.21450363216387297 → 0.19728400491642561`; exit/iterations/evaluations are `1/12/96`. | rounding_ok |
| 5 | Slide 5 | 13 scenarios × 3 controllers = 39; success is `8/9/10`; combined success sum is 0. | exact_match |
| 6 | Slide 6 | 360 = 4×3×30; isolated cells are all `30/30`; combined cells all `0/30`; raw optimized high-noise slew is `2888.34441441764`. | rounding_ok |
| 7 | Slide 7 | Six completed runs, four successes; all straight-line pass; optimized-only pick pass; raw RMS/max `0.0142210111046117/0.029698222399069 m`. | rounding_ok |
| 8 | Slide 8 | Simulink `2/2`, Multibody `2/2`; raw worst end-effector difference `3.34221388864417e-16 m`. | rounding_ok |
| 9 | Slide 9 | Nominal manual/Fuzzy metrics are mixed; optimized leads deterministic and Cartesian aggregate success with the largest high-noise slew. | exact_match |
| 10 | Slide 10 | Hardware, sensing, planning, monitoring, collision avoidance, and safety are future work, not achieved results. | exact_match |
| 11 | Summary page | `7.283%`, `10/13`, `30/30 vs 0/30`, conditional conclusion, and limitations repeat the same raw evidence. | rounding_ok |

## Completeness and consistency

- Phase 7A raw evidence: **14/14** files present (`7 MAT + 7 CSV`); figures **6/6 PNG**.
- Phase 7A manifest, Phase 7B manifest, and package-embedded hashes: **all match**.
- Template → package deep equality: **PASS**.
- Package → current PPTX: **PASS**; PowerPoint COM reports **10 slides** and **10/10** complete `[Sources]` notes.
- Package → current DOCX: **PASS**; Word COM reports **1 page**; current PDF is **1 page**.
- Fresh individual visual QA: **11/11 PASS** (10 slides + 1 summary), with no clipping, overlap, broken glyphs, unreadable charts, or placeholders.
- PPTX/DOCX/PDF hashes stayed unchanged during rendering and match the manifest.

## Tests

The fixed bundled Python suite collected 46 tests. The one artifact-tool rebuild test was excluded because its bundled dependency is absent. The remaining **45/45 passed**, with zero failures.

Trace: `.aris/traces/paper-claim-audit/2026-08-21_run10/`
