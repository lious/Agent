# ADR 0135 — Official I-034 DEV-PURE AgentMailbox protocol, exclusive conflicts, and debate pause

## Status

Accepted for Increment 2.36 as the first I-034 slice. I-034 moves from planned to partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. This is a DEV-PURE in-memory protocol fake in `packages/studio_harness`. It does not merge workspace SQLite w5, does not change Project `user_version` (stays 9), does not call a paid API, and does not claim two real modelId / weight-pack records. Explicit PatchGroup cherry-pick and a chat workbench UI stay unopened. InversePatch kind stays `restoreSnapshot`.

Increment 2.36 first surveyed leftover I-012 remainingAcceptance (“虚拟时钟验证全部触发；并发save合并；保存完成只在durable receipt之后”). ADR 0098 already records that those three clauses are official in `save_test.dart` and are not re-qualified. There was no unfinished already-admitted bound left to officialize without rewriting that frozen suite, so I-012 was left listed and was not the increment.

## Decision

I-034 acceptance is “两个不同modelId/权重包在同案例有真实记录（仅同底模改温度/量化不算）；fake仅测协议；冲突不直接写DB；争论超界暂停.” The work item profile is “DEV先fake”, and the decision says that without a second-model qualification the handoff is not verified and must not be claimed as a real multi-Agent run. This increment officializes only the three protocol clauses at the already-specified s10e / s10i bound:

- `RoleProfile` — Director / Writer / Visual / Editor / Sound / Critic. Editor `scopePolicy` is `editCommandProposal`; Critic is `readOnlyQa`.
- `AgentMailbox.send` / `publish` / `ack` / `replay(afterSeq)` — an `AgentMail` is a s10i 1.0.0 record. Send checks parent-graph delegation adjacency, mailbox namespace, privacy/rights epoch, and TTL. `kind` is not a system role (`task` / `artifact` / `critique` / `decision` / `cancel` only). Identical `id`+fingerprint is idempotent; a conflicting fingerprint is `IDEMPOTENCY_CONFLICT`. Replay after a referenced artifact is deleted returns a tombstone and does not restore a live body.
- `ConflictResolution` — a Critique must name a concrete field and evidence. Director and Editor proposals on the same field become mutually exclusive PatchGroup values; `applied` stays false and `documentWrites` stays 0. A locked `caption.text` is `MANUAL_LOCKED`. A third critique, a repeated input/output hash with no new evidence, or an exhausted parent `BudgetLedger` pauses the debate (`NO_PROGRESS` / `BUDGET_EXHAUSTED`).

This is an in-memory protocol ledger, not a durable harness inbox in the project store, and not I-003 outbox persistence. MemoryIndex, ContextCompiler, ModelRouter capability routing, and real local/cloud model runs are not invented. A shared cross-app session is not stolen (`NAMESPACE_MISMATCH`).

This increment adds:

- `packages/studio_harness/lib/roles.dart`
- `packages/studio_harness/lib/mailbox.dart`
- `packages/studio_harness/test/agents/handoff/i034_agent_mailbox_test.dart` (4)

Existing I-027, I-032, I-033, and device-scheduler suites are not rewritten.

## Consequences

I-034 is partial. The leftover remainingAcceptance item is “两个不同modelId/权重包在同案例有真实记录（仅同底模改温度/量化不算）.” That clause is not claimed. 87-task counts become 0 complete / 38 partial / 36 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i034-agent-mailbox/`.

## Follow-up

Do not claim a real two-model handoff without a V-profile qualification. Do not invent PatchGroup cherry-pick, a workbench UI, or a durable mailbox schema (no w5, `user_version` stays 9). Next honest Linux/Web increment: leftover I-025 remainingAcceptance (restore last durable edit / export through I-024) if that bound is already specified; otherwise another still-doable planned or remaining-partial slice from the four planning documents. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner or open video muted/solo.
