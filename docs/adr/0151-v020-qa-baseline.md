# ADR 0151 — Official V-020 QA baseline fixtures and repair oracle

## Status

Accepted for Increment 2.52 as the first V-020 slice. V-020 moves planned → partial and is not marked complete. I-035 stays planned (gate `V-020=qa` is not met; precision/recall is not measured). I-013 stays partial (job archival remains unopened). I-014 stays partial (the product RestoreService store commit path remains unopened). I-037, I-038, and V-007 stay partial and are not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Schema v10 is not merged. This increment does not invent a product QAService, a DependencyIndex, paid generation, or a measured precision/recall score.

## Decision

s10f and s10i define `QAEvaluator.evaluate` → `QAFinding[]` with `status=pass|fail|unknown`, `mode=deterministic|model|human`, and nullable `score` / `confidence` / `calibrationHash`. A model score without `calibrationHash` cannot automatically be treated as a reliable release signal. `unknown` is not `pass`. Hard publish items that stay `unknown` require human confirmation or a block. `RepairPlanner.propose` targets the minimal producer closure, preserves already-accepted outputs, returns `NeedsReview` when the closure intersects the manual locked write set, does not regenerate already-passed shots, does not overwrite hand-edited captions, and does not treat an "automatic repair budget" as a blank check: only an approved exact prompt/resource/quote may be paid. The official dimensions are `semantic`, `story`, `identity`, `sku`, `motion`, `av`, `caption`, `instruction`, `emotion`, and `rights`. Picture correctness cannot be judged from OCR or captions alone. Missing video understanding must not forge a motion score. Unconnected lip-sync stays `unknown`. Unregistered effects stay `UNSUPPORTED_EDIT_TECHNIQUE`. A single LLM judge is not the source of truth. Any numeric target, including precision/recall ≥0.8, is a product acceptance goal and is not written as an achieved rate before a real model / production-load test.

This increment officializes that bound as a DEV-PURE compiler in `packages/studio_quality/lib/qa_baseline.dart`:

- `QaBaselineCompiler.evaluate` lists human labels and model scores in separate maps, never auto-promotes `unknown` to `pass`, and keeps an uncalibrated hard-item model score as `unknown`. Treating a single LLM judge as sole truth is `UNSUPPORTED_EDIT_TECHNIQUE`. An unregistered effect is `UNSUPPORTED_EDIT_TECHNIQUE`. An OCR-only picture claim, missing video understanding, or unconnected lip-sync stays `unknown` with no forged score. Compile does not submit or start paid generation. Precision/recall is not claimed.
- `QaBaselineCompiler.propose` is a repair oracle, not a product QAService and not a DependencyIndex. Already-passed shots are preserved (`passedShotsRegenerated=0`). A lock intersection returns `needsReview` with `lockedSegmentCoverage=0` and does not rewrite a locked caption. An unapproved paid repair is `APPROVAL_REQUIRED`. Default repair rounds are capped at 2; a third round is `UNSUPPORTED_EDIT_TECHNIQUE`. The plan does not submit.

The I-035 product loop, paid model evaluation, and a measured held-out precision/recall run remain unopened.

## Consequences

The first V-020 deliverable (threshold ADR, fixture labels, and a repair oracle) is officialized at this compiler/fixture bound. Known-violation precision/recall ≥0.8 remains unmeasured, so V-020 stays partial and is not marked complete. 87-task counts become 0 complete / 43 partial / 31 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/v020-qa-baseline/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not claim a V-020 precision/recall achievement or start I-035 as a product QAService unless a narrowly specified leftover bound is already written and does not invent paid generation. Do not invent I-013 job archival or an I-014 product RestoreService commit path. Do not claim a 60s WebCodecs/OPFS roundtrip or pin a V-007 production lock. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037, I-038, or V-007 complete.
