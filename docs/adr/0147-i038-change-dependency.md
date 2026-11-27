# ADR 0147 — Official I-038 s8m change-dependency and locked-field invalidation

## Status

Accepted for Increment 2.48 as a leftover I-038 s8m change-dependency / locked-field invalidation slice. I-038 stays partial. I-037 stays partial and is not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Quote/apply, paid generation, and SQL `vertical.v1` are not started. IntentReducer and DependencyIndex are not invented as a product surface or scheduler. Signed-pack import, production FTS/RAG, and workspace SQLite w5 stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified. Motion capture, adult-motion retargeting, auto-segmentation, and new child-related surfaces beyond already-officialized s8l bounds are not invented.

## Decision

s8m change dependency distinguishes candidate invalidation from accepted handmade work that remains available for redo. Manual fields are never automatically deleted because a workpiece is stale. Title, caption, source range, music keyframes, and overlay facts each have a field lock. A mid-workflow SKU and duration change invalidates the product-appearance prompt and candidate, and the price/spec overlay, but does not invalidate a same-hash desktop analysis on an unchanged shot. A confirmed duration proposal keeps the handmade source range and the same clip object, and may delete an old gap; an unconfirmed proposal does not rewrite durations or submit. A locked caption that still carries a conflicting price is `FACT_BINDING_CONFLICT` and does not submit the batch. A locked music tail that would outlive a shortened sequence is `FIELD_LOCKED` unless the user explicitly trims the music or selects a shorter delivery range. A replacement source shorter than a locked out-point is `PARAMETER_RANGE`; stretching locked audio is `FIELD_LOCKED`. A CAS read-set mismatch is `REVISION_CONFLICT`. A compressed snapshot or analysis cache must not resurrect a deleted SKU (`FACT_SKU_MISMATCH`). Unplacing a shot is not delete source; the source stays recoverable. A local performance redo invalidates only that shot's prompt and candidate. Deleting a causal shot reports a missing causal shot and must not rewrite dialogue to pretend the action happened (`UNSUPPORTED_EDIT_TECHNIQUE`). A later published character revision does not upgrade a pinned character. Compile does not submit, start quote/apply, or launch paid generation or TTS.

This increment officializes that bound in `packages/studio_vertical/lib/change_dependency.dart`:

- `ChangeDependencyCompiler.compile` emits a `ChangeDependencyProgram` and does not submit or write a project.
- Declared shot hashes are walked only inside this compiler; this is not an IntentReducer or DependencyIndex product API.

This increment adds:

- `packages/studio_vertical/lib/change_dependency.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_change_dependency_test.dart` (3)

The Increment 2.42–2.47 I-038 suites (18) were re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for s8m change dependency and locked-field invalidation is officialized at this compiler bound. WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and the full s8m case A/B apply/archive flows remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-change-dependency/`.

## Follow-up

Next honest Linux/Web increment: pick the next still-doable planned or remaining-partial work from the four planning documents. Do not start quote/apply, paid generation, or SQL `vertical.v1` unless a narrowly specified protocol slice is already written and does not invent a coordinator or persistence schema. Do not invent IntentReducer or DependencyIndex as a product surface. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 or I-038 complete. Do not start signed-pack import or claim production FTS/RAG. Do not start I-039 unless a narrowly specified leftover bound is already written and I-038 hardDeps allow it.
