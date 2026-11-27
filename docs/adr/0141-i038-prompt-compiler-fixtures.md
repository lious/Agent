# ADR 0141 — Official I-038 VerticalWorkflowCompiler fixtures and compile refusals

## Status

Accepted for Increment 2.42 as the first I-038 DEV-PURE WorkflowCompiler / FactLedger slice. I-038 moves from planned to partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. I-037 is not marked complete. Signed-pack import and production FTS/RAG stay unopened. Workspace SQLite w5 and SQL `vertical.v1` are not merged. Paid generation, quote/apply, and the four PlayRecipe library entries are not invented.

I-032 leftover “图环；手动锁始终有效” was re-checked and is still not a clean already-specified slice: “图环” is already official as `PLAN_CYCLE` in `device_scheduler_test.dart` and is not re-qualified; there is still no admitted PlanGraph manual-lock API, and one is not invented. That wording is not I-006 track lock and is not I-010 caption manual lock.

## Decision

s8h says purpose, input modes, and play recipes are three axes, not a mutually exclusive enum; a compile error does not submit. s8n FactLedger is the only confirmation authority (an LLM `confirmed=true` is not authorization). Marketing/showcase require a product identity and confirmed unexpired same-SKU facts. Unauthorized subjects are `PORTRAIT_CONSENT_REQUIRED`. Unsupported `firstLast` is `CAPABILITY_UNSUPPORTED` and is not renamed to i2v. A stale override is `OVERRIDE_REBASE_REQUIRED`. Unsupported parameters are listed, not silently truncated. A seed is a same-profile similarity hint and does not claim cross-model consistency.

This increment officializes that bound in `packages/studio_vertical`:

- `VerticalWorkflowCompiler.compile` admits one legal fixture per purpose (`marketing`, `showcase`, `story`, `social`, `tutorial`, `musicVisual`). `story` + `script` + `i2v` is a valid combination.
- Unconfirmed or LLM-claimed product facts are `UNCONFIRMED_FACT`. Expired facts are `FACT_EXPIRED`. A SKU/product mismatch is `FACT_SKU_MISMATCH`.
- Unauthorized subjects, unsupported `firstLast`, stale overrides, and generation with `allowNewGeneration=false` do not submit.

This increment adds:

- `packages/studio_vertical` (`lib/workflow_compiler.dart`, `lib/fact_ledger.dart`, `lib/vertical_brief.dart`)
- `packages/studio_vertical/test/vertical/all_scenarios/i038_prompt_compiler_fixtures_test.dart` (3)

## Consequences

The I-038 remainingAcceptance items “所有垂类至少1合法+1非法fixture”, “商品事实只取确认来源”, “未授权人物/未支持首尾模式不提交”, and “override/template冲突不静默覆盖” are officialized at this compiler/fixture bound, together with the decision “不支持参数不截断；固定seed不冒称跨模型一致.” PlayRecipe library entries, WorkflowCoordinator quote/apply, SQL `vertical.v1`, and paid generation remain in remainingScope. I-038 stays partial. 87-task counts become 0 complete / 41 partial / 33 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i038-prompt-compiler-fixtures/`.

## Follow-up

Next honest Linux/Web increment: a further still-doable planned or remaining-partial slice from the four planning documents. Do not start signed-pack import or claim production FTS/RAG; do not mark I-037 complete; do not invent a PlanGraph manual-lock API or re-qualify `PLAN_CYCLE`. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5.
