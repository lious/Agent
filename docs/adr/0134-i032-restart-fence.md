# ADR 0134 — Official I-032 expired fence does not commit, and 100 restarts have no duplicate side effects

## Status

Accepted for Increment 2.35 as a leftover I-032 remainingAcceptance slice of “过期fence不提交” and “100重启无重复副作用”. I-032 remains partial. `fullTaskComplete` stays false. `fullTasksCompleted` stays 0. InversePatch kind stays `restoreSnapshot`. Project `user_version` stays 9. Workspace SQLite w5 is not merged. A new restart product surface is not invented. A PlanGraph manual-lock API is not invented. Dynamic replan, model-loop execution, mapreduce expansion, and unpaid model/API work are not opened.

## Decision

I-032 remainingAcceptance after Increment 2.00 is “图环；过期fence不提交；100重启无重复副作用；手动锁始终有效.” ADRs 0106 and 0107 recorded that “过期fence不提交” was already covered by in-memory lease-fence suites and was not re-qualified there, and that “100重启无重复副作用” still had no complete 100-restart proof on an already-admitted path. This increment officializes both leftover clauses at the already-admitted durable `finishHarnessTask` / `DocumentRepository` reopen bound, without rewriting those earlier suites and without inventing a scheduler or restart product surface.

The already-admitted bound implements the chosen clauses:

- After a running lease is persisted and the repository is reopened, `finishHarnessTask` at `nowMs >= lease.untilMs` is `LEASE_FENCED`. The step stays `running`, no `candidate.ready` outbox row is inserted, and the project revision is unchanged.
- After a step has committed once, one hundred repository close/reopen cycles with the same token and payload return the same result hash. The `candidate.ready` outbox count stays 1. A conflicting payload is `IDEMPOTENCY_CONFLICT` and does not add a side effect.

This file does not rewrite `device_scheduler_test.dart`, `harness_transactions_test.dart`, `harness_takeover_test.dart`, Increment 1.99 `i032_fanout_iteration_limits_test.dart`, or Increment 2.00 `i032_namespace_refusal_test.dart`. Those files are re-run, not reused as this official wording.

The leftover “图环” remains listed (already official as `PLAN_CYCLE` in `device_scheduler_test.dart` and not re-qualified). “手动锁始终有效” remains listed: there is still no admitted PlanGraph manual-lock API, and one is not invented. That wording is not I-006 track lock and is not I-010 caption manual lock.

This increment adds:

- `packages/studio_store/test/i032_restart_fence_test.dart`: an expired lease after reopen is `LEASE_FENCED` and does not commit a receipt; one hundred repository restarts of a committed finish return the same hash and do not duplicate the outbox side effect.

No production algebra or schema is changed. Official InversePatch kind stays `restoreSnapshot`.

## Consequences

The I-032 remainingAcceptance items “过期fence不提交” and “100重启无重复副作用” are cleared at this already-admitted durable finish/reopen bound. “图环” and “手动锁始终有效” remain listed rather than being silently reduced. I-032 stays partial. 87-task counts stay 0 complete / 37 partial / 37 planned / 13 blocked.

## Evidence

`docs/implementation/evidence/i032-restart-fence/`.

## Follow-up

Do not invent a PlanGraph manual-lock API, and do not re-qualify “图环”. Next honest Linux/Web increment: another still-doable planned or remaining-partial slice from the four planning documents, such as leftover I-012 remainingAcceptance (virtual clock / concurrent save merge / durable receipt) if that bound is already specified. Do not start bus Effect, limiter, or I-007 PCM remapping unless a narrowly specified interface already exists; do not invent a TrimPlanner, open video muted/solo, invent PatchGroup cherry-pick or a chat workbench UI, or merge workspace SQLite w5.
