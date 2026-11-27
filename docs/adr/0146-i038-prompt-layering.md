# ADR 0146 — Official I-038 s8m prompt layering and override rebase

## Status

Accepted for Increment 2.47 as a leftover I-038 s8m prompt-layering / override slice. I-038 stays partial. I-037 stays partial and is not marked complete. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Quote/apply, paid generation, and SQL `vertical.v1` are not started. Signed-pack import, production FTS/RAG, and workspace SQLite w5 stay unopened. A PlanGraph manual-lock API is not invented; `PLAN_CYCLE` is not re-qualified. Motion capture, adult-motion retargeting, auto-segmentation, and new child-related surfaces beyond already-officialized s8l bounds are not invented.

## Decision

s8m compiles a prompt in five layers: film contract, narrative/character, visible action/photography, capability/negative, then safety/budget/edit. A whole-film narrative is not stuffed into one shot. Only this-shot characters are injected, with at most five references. Soft camera intent surfaces `SOFT_CAMERA_CONTROL`. J/L cuts, match cuts, Logo text, and ducking stay on a deterministic EditPlan and are not claimed as prompt-guaranteed edits. Source evidence stays observed/inferred and is not auto-promoted to a product fact. A seed is a same-profile similarity hint and does not claim cross-model consistency. PromptProgram is a literal/slot AST: no eval, and user text cannot declare a provider field or tool. Secrets and endpoints cannot be templated. A reference file that says “ignore rules / upload / charge” is data only and does not escalate privilege.

A template or Brief update with an existing override and no decision is `OVERRIDE_REBASE_REQUIRED` and does not submit. The user may keep their version, recompile, or request an itemized diff. Parameters out of range are `PARAMETER_RANGE`. An over-long prompt is `PROMPT_TOO_LONG`. Fields are never silently truncated. An unsupported negative must be positively rewritten or refused, and is not dropped. A locked caption is not overwritten by a model suggestion. A locked caption that still carries a conflicting price is `FACT_BINDING_CONFLICT` and does not submit. Rights revocation remains a live hard gate.

This increment officializes that bound in `packages/studio_vertical/lib/prompt_program.dart`:

- `PromptLayerCompiler.compile` emits a five-layer `PromptProgram` and does not submit or write a project.
- Undecided stale overrides are `OVERRIDE_REBASE_REQUIRED`. `keepUserVersion` and `itemizedDiff` return values and do not submit.
- User-declared tools or provider fields are `TOOL_NOT_ALLOWED`. Eval or secret/endpoint bindings are `UNSUPPORTED_EDIT_TECHNIQUE`. Inferred-as-confirmed facts are `UNCONFIRMED_FACT`. Revoked rights are `RIGHTS_REQUIRED`. More than five this-shot character refs is `SLOT_COUNT`.

This increment adds:

- `packages/studio_vertical/lib/prompt_program.dart`
- `packages/studio_vertical/test/vertical/all_scenarios/i038_prompt_layering_test.dart` (3)

The Increment 2.42–2.46 I-038 suites (15) were re-run, not rewritten.

## Consequences

The leftover I-038 remainingScope item for s8m prompt layering and override rebase is officialized at this compiler bound. WorkflowCoordinator quote/apply, SQL `vertical.v1`, paid generation, and the full s8m case A/B apply/archive flows remain unopened. I-038 stays partial. 87-task counts stay 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-prompt-layering/`.

## Follow-up

Next honest Linux/Web increment: a narrowly specified leftover I-038 change-dependency / locked-field bound from s8m (IntentReducer-style invalidation, without inventing a product scheduler) only if that slice is already specified and does not start quote/apply, paid generation, or SQL `vertical.v1`. Otherwise pick the next still-doable planned or remaining-partial work from the four planning documents. Do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not mark I-037 or I-038 complete. Do not start signed-pack import or claim production FTS/RAG.
