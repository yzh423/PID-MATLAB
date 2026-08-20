# Paper Claim Audit Report — run05

**Date:** 2026-08-21 (Asia/Shanghai)

**Auditor:** GPT-5.6-sol, high reasoning, fresh zero-context reviewer

**Paper:** *Reliable Robotic Manipulation Through Evidence-Grounded PID and Fuzzy-PID Evaluation*

**Trace:** `.aris/traces/paper-claim-audit/2026-08-21_run05/`

## Overall Verdict: PASS

All 15 required claim groups reconcile with the current admitted evidence and repository scope. There are **0 findings**, **0 WARN**, **0 FAIL**, **0 unsupported claims**, and **0 ambiguous mappings**.

## Counts

| Measure | Count |
|---|---:|
| Required claim groups reviewed | 15 |
| Exact matches | 7 |
| Standard-rounding matches | 8 |
| Findings | 0 |
| WARN | 0 |
| FAIL | 0 |
| Unsupported claims | 0 |
| Ambiguous mappings | 0 |

The eight `rounding_ok` groups contain displayed decimal/scientific-notation values that reproduce the raw evidence under the template's declared formatting. No non-standard rounding, cherry-picking, aggregation mismatch, configuration mismatch, or scope inflation was found.

## Evidence chain verified

- A fresh MATLAB export read the **14 admitted MAT/CSV sources**, enforced the MAT-to-CSV mirror checks, full-mode study shapes, uniqueness gates, and required failure disclosures, and produced a JSON file byte-for-byte identical to `results/report/report_evidence.json` (`sha256:9495b9193b484f0622a3513779bcd2ed4b75d24e9710f4412b89a68da8237678`).
- `generatedAt = 2026-08-21T00:00:00Z` is explicitly implemented by `formalEvidenceTimestamp()` as the **version timestamp for the frozen Phase 7A evidence snapshot**. It is not presented or used as a wall-clock export-time claim. The repeat-export test overwrites a prior timestamp and verifies restoration of this frozen version.
- The template resolves in memory to the checked-in Markdown exactly. It has 151 token occurrences resolving to 126 unique evidence identities; the manifest records the same 126-token set and the rendered report contains no unresolved braces.
- MATLAB: **150/150 passed**, comprising **5 report tests** and **145 pre-report tests**, with 0 failed and 0 incomplete. Python report suite: **24/24 passed**.
- All six selected PNGs are metadata-free and byte-idempotent under the normalizer. Decoded mode, dimensions, and every pixel byte are preserved; volatile metadata is removed.
- The controlled report sources `technical_report_template.md` and `references.json` are LF-only. The build normalizes both before hashing, and `.gitattributes` pins Phase 7A report source/tool/test text to `eol=lf`. Source/tool hashes in the JSON sibling are SHA-256 over canonical Git-text bytes, so they are checkout-EOL independent. Generated/raw evidence and final-artifact hashes are SHA-256 over raw bytes.
- Every one of the 9 manifest source hashes and 3 manifest output hashes matches the current file. Final outputs are Markdown `b3a7…4674`, DOCX `a534…6ce0`, and PDF `231c…c71e`; the PDF is 8 pages and the DOCX contains 6 numbered figures and 9 numbered tables.

## The 15 required claim groups

| # | Group | Status | Verification result |
|---:|---|---|---|
| 1 | protocol | exact_match | The evidence fixes 0.001 s sampling, 5.0 s duration, 5001 samples, a 0.50 s final window, 0.020 rad RMS and 0.050 rad maximum gates, and full study sizes 39/360/6/2/2. The stochastic design is 4 scenarios × 3 controllers × 30 paired trials. |
| 2 | nominal | rounding_ok | Manual/Fuzzy steady RMS values 0.001268/0.013762 and 0.009792/0.013174 rad, torque RMS values, zero saturation, two passes, and the mixed joint-specific direction all reproduce the admitted nominal MAT evidence. |
| 3 | optimization | rounding_ok | 0.202427→0.187684 gives 7.28314786% (reported 7.283%); held-out 0.214504→0.197284, exit flag 1, 12 iterations, 96 evaluations, bounded gains, unchanged torque limits, and one frozen objective/search budget all match MAT evidence and scoring/configuration source. |
| 4 | deterministic | rounding_ok | 39 rows/13 scenarios yield 8/13, 9/13, and 10/13 successes, rates 0.6154/0.6923/0.7692, the displayed mean/worst values, and three combined-condition failures exactly as reported. |
| 5 | stochastic | rounding_ok | 360 paired trials comprise 4 scenarios × 3 controllers × 30 seeds. Every isolated-noise cell is 30/30; each combined-stress cell is 0/30. High-noise RMS, torque slew 1520.28/1631.16/2888.34 N m/s, and saturation values match the trial/summary artifacts. |
| 6 | Cartesian | rounding_ok | Six completed runs give three straight-line passes and pick-transfer-place outcomes fail/fail/pass. Every RMS, maximum, pickup, and place value rounds from the admitted row; failures are retained rather than suppressed. |
| 7 | rigid-body | rounding_ok | The independent rigid-body audit reports maxima 2.2204e-16, 4.3021e-15, and 3.5527e-15 for inertia, velocity product, and gravity, respectively. |
| 8 | Simulink | rounding_ok | Two rows pass agreement and tracking. The manual first-row joint-position RMS is 5.3425e-17 rad and the highlighted maximum is 2.2204e-16 rad; all values remain at floating-point scale under the fixed nominal protocol. |
| 9 | Multibody | rounding_ok | Two rows pass agreement and tracking; worst end-effector difference is 3.3422e-16 m and maximum out-of-plane motion is 0.0 m. The claim is model consistency, not hardware fidelity. |
| 10 | report structure | exact_match | The generated Markdown has 13 required level-2 sections, 9 tables, 6 figures, 8 references, 126 unique used evidence tokens, and no unresolved tokens. The DOCX/PDF checks pass and numbering is contiguous. |
| 11 | figure captions | exact_match | Visual inspection of all six normalized PNGs confirms that each caption names the plotted content: nominal tracking, objective history, deterministic summary, stochastic chattering, Cartesian paths, and Multibody tracking. No caption-content mismatch was found. |
| 12 | citations | exact_match | IDs [1]–[8] are contiguous and used in supported contexts. DOI metadata for [1]–[4] matches authors/title/journal/year/volume/issue/pages; [5]–[6] use official MathWorks documentation; [7] matches arXiv 2303.03378; [8] matches the PMLR 229 proceedings record. |
| 13 | evidence admission | exact_match | The exporter requires exactly 14 formal sources, verifies CSV mirrors against their MAT tables, requires every mode to be `full`, enforces frozen dimensions and unique row keys, and preserves failed completed runs. A fresh re-export is byte-identical to the admitted JSON. |
| 14 | reproducibility/build | exact_match | Frozen evidence-version semantics, 150 MATLAB and 24 Python test counts, LF source normalization, canonical source/tool hashes, metadata-normalized PNGs, deterministic DOCX/PDF packaging tests, and all manifest/output hashes were verified. |
| 15 | scope/absence | exact_match | The report consistently limits conclusions to simulation and explicitly denies hardware validation/safety. A zero-hit search over the hashed 120-file implementation/test/model scope finds no camera or perception pipeline, object detector, language/VLA implementation, task-and-motion or grasp planner, collision-avoidance system, or online safety supervisor. |

## Findings

None.

## Hash conventions

The machine-readable sibling contains the complete declared-input hash ledger. Entries labeled `sha256-canonical-git-text` hash current text after Git-equivalent CRLF/CR→LF normalization. Entries labeled `sha256` hash the raw bytes of generated evidence, raw MAT/CSV inputs, PNGs, the manifest, and final report artifacts. The 120-file source-scope aggregate is bound by path-set hash `66bb5aed27d67e4ed79fb8a1f3fdd9840af30c650d7ff108cf3910f3f6946bb0` and canonical/raw content aggregate `ac3e1fb3876cc231ded421b196a1247eea13fb9edf193ce653042100bf5676b1`.
