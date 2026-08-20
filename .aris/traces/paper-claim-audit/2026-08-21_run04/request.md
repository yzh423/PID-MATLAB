# Fresh Paper-to-Evidence Audit Request

You are a fresh independent paper-to-evidence auditor with zero prior context. Do not read or rely on any previous `PAPER_CLAIM_AUDIT` artifact or paper-claim-audit trace.

Audit the current `docs/report/technical_report.md` and `docs/report/technical_report_template.md` against:

- `results/report/report_evidence.json`;
- the exact 14 MAT/CSV source paths declared in that evidence manifest;
- the exact six PNG artifact paths declared in that evidence manifest;
- `docs/report/references.json` and `docs/report/build_manifest.json`;
- current report exporter, resolver, admission/content gate, builder, verifier, and report tests;
- implementation/test source scope needed to test controller, dynamics, cross-model, and absence claims.

Audit exactly these 15 independent groups: protocol; nominal; optimization; deterministic; stochastic; Cartesian; rigid-body; Simulink; Multibody; report structure; figure captions; citations; evidence admission; reproducibility/build; scope/absence.

Recompute all reported values and hashes. Specifically test the abstract statement that designated result fields are token-resolved while the admission gate separately enforces frozen study counts and required failure disclosures. PASS requires zero WARN, FAIL, unsupported, or ambiguous findings. Reviewer metadata must be GPT-5.6-sol with high reasoning.
