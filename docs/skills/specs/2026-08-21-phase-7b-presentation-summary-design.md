# Phase 7B Presentation and Research Summary Design

## Objective

Phase 7B packages the verified Phase 7A report into two audience-facing deliverables:

1. an English 10-slide PowerPoint deck for an advisor or faculty discussion; and
2. an English one-page research summary in DOCX and PDF for faculty outreach, recommendation material, and project attachments.

By the end of the presentation, an advisor or faculty reader should understand that the repository provides a rigorously tested low-level robotic execution layer, that controller conclusions depend on the operating condition rather than a universal winner, and that the optimized PID produced the strongest aggregate reliability in the admitted simulation studies.

Success means the package is scientifically faithful to the Phase 7A evidence, visually legible without presenter explanation, explicit about failed cases and simulation-only scope, and reproducible across clean Windows checkouts.

## Assumptions

- The audience is technically literate in robotics or controls but has not read the full report.
- The presentation is intended for a 10- to 15-minute discussion, so 10 slides is the preferred midpoint of the required 8- to 12-slide range.
- Visible deliverable content is English because the existing report, repository, and intended faculty-facing use are English.
- The Phase 7A evidence manifest, selected figures, report, and claim audit are the only quantitative source of truth. Phase 7B does not create new controller experiments.
- No institution logo, personal portrait, or unverified affiliation is added.
- The project title is reused from the verified technical report. No author name is inferred.
- The current environment has no artifact-template picker, so the default Codex Grid visual route is used.

## Communication Approach

Three packaging approaches were considered:

1. **Evidence-driven defense deck (selected).** Each slide advances one claim and pairs it with admitted evidence. It preserves failures and scope boundaries while remaining presentation-friendly.
2. **Data-dense technical appendix deck.** This could expose more tables and parameters but would repeat the report and exceed comfortable presentation density.
3. **Application-first portfolio deck.** This would foreground embodied-AI relevance and career value, but it risks making the existing simulation evidence secondary.

The selected approach uses a restrained white canvas, black typography, pale-gray structure, and blue evidence accents. Existing experiment figures are the primary visuals; decorative stock imagery is unnecessary.

## Narrative and Slide Contract

The deck contains exactly 10 slides:

1. **Reliable execution is the missing layer between plans and physical action.** Minimal title slide with one validated Multibody visual.
2. **Nominal success is not enough to claim reliable manipulation.** Problem statement, evaluation question, and simulation-only boundary.
3. **Every controller faces the same plant, trajectory, limits, and metrics.** Two-link system, three controllers, 0.001 s sample time, 5 s duration, and fixed success thresholds.
4. **Optimization improves the baseline without changing the evaluation protocol.** Nominal tracking and optimization-objective evidence; 7.283% objective reduction and held-out improvement.
5. **Reliability separates the controllers under deterministic stress.** The deterministic summary figure and success counts 8/13, 9/13, and 10/13.
6. **Noise alone is manageable; combined stress is not.** The stochastic chattering figure, isolated-noise 30/30 results, combined-stress 0/30 disclosure, and torque-slew trade-off.
7. **Task-space evaluation exposes failures hidden by joint metrics.** Cartesian path figure and the four-of-six task result, including the two failed pick-transfer-place cases.
8. **Independent formulations agree at numerical precision.** Simulink and Multibody agreement, rigid-body audit maxima, and explicit distinction between model consistency and hardware fidelity.
9. **There is no universal winner, but optimized PID is the strongest reliability baseline.** Joint-specific nominal result, stress-test aggregate, and honest trade-offs.
10. **The validated layer is ready to support the next research step.** Hardware validation, perception/planning integration, and online safety monitoring as bounded future work.

Every slide must:

- have one takeaway-style title;
- keep titles on one line;
- use at least 35 pt slide titles, 24 pt callout headers, and 16 pt body text;
- include a `[Sources]` block in speaker notes with repository-relative source paths and, where relevant, report reference IDs;
- contain no unresolved token, placeholder copy, production instruction, or unsupported numerical claim; and
- use a unique evidence visual unless a repeated background element is intentional.

## One-Page Research Summary Contract

The summary is a one-page US Letter portrait document using the `standard_business_brief` preset with a restrained `memo_masthead` opening. It contains:

- title and one-sentence research takeaway;
- problem and research question;
- method: two-link arm, three controllers, identical protocol, deterministic/stochastic/Cartesian/cross-model validation;
- three quantified key results;
- one compact deterministic-reliability figure;
- significance for a future embodied-AI stack;
- limitations and next steps; and
- a compact source footer tied to the technical report and admitted evidence.

The page must not use tables as prose containers. A three-result strip is allowed as a named visual override, while the remaining content uses headings, short paragraphs, and one figure. The final DOCX and PDF must both render as exactly one page.

The DOCX and PDF are **two independent canonical renderers** of the same deterministic Phase 7B package. The DOCX renderer uses `python-docx`; the PDF renderer uses ReportLab directly. Semantic equality, source coverage, figure aspect/layout equivalence, and the one-page contract are verified across both outputs. Word export is an optional, non-canonical diagnostic only and is never the canonical PDF gate.

## Evidence and Data Flow

```text
results/report/report_evidence.json
docs/report/build_manifest.json
docs/report/references.json
docs/presentation/phase7b_template.json
results/figures/*.png
                |
                v
scripts/export_phase7b_package.py
                |
                v
results/presentation/phase7b_package.json
          |                         |
          v                         v
scripts/build_presentation.mjs  scripts/build_research_summary.py
          |                         |
          v                         v
presentation/final_presentation.pptx  docs/summary/research_summary.docx
                                      docs/summary/research_summary.pdf
```

`phase7b_template.json` owns audience-facing copy and evidence tokens. The exporter resolves every token against the admitted Phase 7A evidence, validates selected figure hashes against the report manifest, and emits one deterministic package consumed by both builders. Builders do not hard-code experiment numbers.

## Project Structure

```text
docs/presentation/
  phase7b_template.json          # Slide and summary copy with evidence tokens
  phase7b_build_manifest.json    # Input/output hashes and structural counts
docs/summary/
  research_summary.docx          # Final editable one-page summary
  research_summary.pdf           # Final one-page distribution copy
presentation/
  final_presentation.pptx        # Final editable 10-slide deck
scripts/
  export_phase7b_package.py      # Evidence admission and token resolution
  build_presentation.mjs         # Artifact-tool presentation builder
  build_research_summary.py      # python-docx summary builder
  export_research_summary_pdf.ps1 # Canonical ReportLab PDF; optional PID-scoped Word diagnostic
  verify_phase7b.ps1             # End-to-end Phase 7B gate
scripts/phase7b/
  evidence.py                    # Package schema and deterministic hashing
  office.py                      # PPTX/DOCX package normalization helpers
  summary.py                     # Summary style and layout helpers
tests/presentation/
  test_phase7b_evidence.py       # Source admission and token tests
  test_phase7b_outputs.py        # PPTX/DOCX/PDF structure and claims
docs/skills/plans/
  2026-08-21-phase-7b-presentation-summary.md
```

Intermediate renders, layouts, source notes, package JSON, and Office automation caches remain ignored build outputs.

## Technology and Style

- Presentation authoring: bundled Node.js and `@oai/artifact-tool` from a JavaScript ES module.
- Presentation composition: Codex Grid principles, adapted rather than copied mechanically; selected reference families are cover-image, two-column, metric-led, and chart/evidence.
- Summary authoring: bundled Python with `python-docx` and deterministic OOXML helpers.
- PDF rendering: ReportLab independently renders the same deterministic Phase 7B package used by the DOCX renderer, followed by deterministic PDF normalization.
- Optional Word export: non-canonical diagnostic only; it is PID-scoped, fail-closed, and excluded from the canonical gate.
- Visual evidence: the six normalized Phase 7A PNG figures. No Python-drawn graphics and no decorative generated images.
- Source text: UTF-8 with LF checkout endings.
- Numeric formatting: standard report formatting and declared rounding only.

Example evidence resolution style:

```python
title = resolve_text(
    "Optimized PID succeeds in {{deterministic.successCount.optimizedPid}}/"
    "{{deterministic.scenarioCount}} deterministic scenarios",
    evidence,
)
```

## Commands

All commands run from the repository root with paths resolved from the bundled workspace runtime.

```powershell
# Export the deterministic Phase 7B package
& $BundledPython scripts/export_phase7b_package.py --project-root .

# Build the PowerPoint deck
& $BundledNode scripts/build_presentation.mjs --project-root .

# Build and export the one-page summary
& $BundledPython scripts/build_research_summary.py --project-root .
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/export_research_summary_pdf.ps1 -ProjectRoot .

# Focused and end-to-end verification
& $BundledPython -m unittest discover -s tests/presentation -p 'test_*.py'
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify_phase7b.ps1
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
```

## Testing Strategy

### Evidence tests

- Reject missing or hash-mismatched Phase 7A evidence and figures.
- Require exactly 10 slides and exactly one summary specification.
- Require every evidence token to resolve and every selected number to match the admitted JSON.
- Require failed runs and simulation-only scope statements to remain present.

### Presentation tests

- Require 10 slides, contiguous slide numbering, and no unresolved placeholders.
- Require a `[Sources]` block in every slide's speaker notes.
- Require all selected figures to be embedded and all externally sourced claims to identify report references.
- Require title/body minimum font sizes and absence of slide-canvas overflow.
- Render every slide, inspect every slide PNG at full size, and run the presentation overflow checker.

### Summary tests

- Require the mandated content sections and exact admitted numbers.
- Require deterministic DOCX structure, one embedded figure, no unresolved tokens, and no hidden comments or tracked changes.
- Render DOCX and PDF to PNG, confirm exactly one page, and inspect the page at full size.

### Reproducibility tests

- Build the package, PPTX, DOCX, PDF, and manifest twice from unchanged inputs.
- Normalize ZIP entry ordering/timestamps and volatile Office/PDF metadata without altering visible content.
- Require identical SHA-256 hashes for all final artifacts and the build manifest.

### Regression gate

- Run the existing full `scripts/verify.ps1` suite after Phase 7B verification.
- Preserve 150/150 MATLAB tests, 24/24 Phase 7A Python report tests, existing report hashes, and all README gates.

## Error Handling

- Missing, malformed, stale, or hash-mismatched evidence fails before authoring.
- Unsupported content tokens report the exact JSON path and source field.
- Optional Word diagnostics own and close only the process they create, fail if an owned PID survives, and clean up in `finally` blocks.
- Rendering, overlap, clipping, page-count, placeholder, or source-note failures block delivery.
- Build scripts write through temporary files and replace final artifacts only after structural validation.

## Boundaries

### Always

- Use the Phase 7A evidence manifest as the quantitative source of truth.
- Preserve failed experiments and limitations beside positive results.
- Keep visible copy concise and audience-facing.
- Commit source, tests, manifests, and final deliverables.
- Render and visually inspect every slide and summary page before completion.

### Ask first

- Adding a personal name, institution logo, affiliation, portrait, or contact information.
- Publishing the deck or summary to a remote service.
- Changing report evidence, controller implementation, experiment thresholds, or accepted conclusions.

### Never

- Invent hardware validation, perception, planning, safety, or embodied-AI implementation.
- Re-run optimization with a new objective or select a different best run for presentation convenience.
- Hide failed task or combined-stress results.
- Use unverified external graphics, unsourced non-trivial claims, or decorative imagery that competes with evidence.
- Modify the user-owned root project-guide DOCX.

## Success Criteria

- The final deck is a visually inspected, editable 10-slide PPTX under `presentation/`.
- The final summary is a visually inspected one-page DOCX and one-page PDF under `docs/summary/`.
- Both deliverables use the same deterministic Phase 7B evidence package.
- All displayed quantitative claims reconcile with raw Phase 7A evidence under exact or standard-rounding rules.
- Every slide has traceable source notes; the summary has a human-readable source footer.
- No overflow, clipping, overlap, broken image crop, unexpected wrapping, placeholder, or missing glyph remains.
- Repeated builds produce identical final artifact and manifest hashes.
- Phase 7B and full repository verification pass from a clean checkout.
- Git history contains atomic design, implementation, verification, and integration commits; no remote state is changed.

## Open Questions

None. The user's standing instruction authorizes the recommended implementation choices without further clarification.
